"""The skirted coat (cloth2 recipe: recipes.coat, the MARINE_JUSTAUCORPS cut): the collarless coat of the 1750s with
knee-length skirts, buttoned from the neck to the waist, deep round cuffs, low pocket flaps, side pleats and a back
vent. Its default colours are the justaucorps of the colonial regulars (troupes de la marine); the same cut in snuff,
brown or black is a civilian's coat (extra.presets)."""

import numpy as np

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tailor as TL
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="coat_skirted", name="Skirted coat (justaucorps)", set="colonial", slot="outer", layer={"default": 40},
    description="A collarless wool coat with knee-length pleated skirts, buttoned from the neck to the waist, with deep "
                "round cuffs, low pocket flaps with buttons, a back vent and lined skirts.",
    history="The colonial regulars of New France kept the grey-white justaucorps buttoned down the front after the "
            "army had left it: collarless in the colonies, deep blue cuffs, blue lining, brass buttons, pocket flaps "
            "with buttons [M6][M5][R25]. The same cut, collarless with a round neck, pleated skirts and gilt buttons, "
            "was a gentleman's coat in the 1750s (Chartrand 2014; V&A 1750s suit).",
    zones=[Zone(0, "coat", "cloth", "WOOL", ["grey_white", "snuff", "walnut_brown", "#B06A3B", "stroud_blue",
                                             "logwood_black", "madder_red"], "grey_white"),
           Zone(1, "cuffs and lining", "trim", "WOOL", ["royal_blue", "grey_white", "snuff", "walnut_brown",
                                                        "logwood_black", "madder_red", "buff"], "royal_blue"),
           Zone(2, "buttons", "button", "MET", ["brass", "pewter", "silver", "gold_lace", "logwood_black"], "brass")],
    sources=["M6", "M5", "R25", "M4"], evidence="A", tags=["men", "colonial", "regulars"], budget=8000,
    over=["shirt_linen", "breeches", "waistcoat_sb", "veste_sleeved", "waistcoat_skirted"],
    extra={"presets": {"marine_justaucorps": {"0": "grey_white", "1": "royal_blue", "2": "brass"},
                       "gentleman": {"0": "snuff", "1": "snuff", "2": "gold_lace"},
                       "minister": {"0": "logwood_black", "1": "logwood_black", "2": "logwood_black"}},
           "references": ["Chartrand 2014 via https://en.wikipedia.org/wiki/Compagnies_franches_de_la_marine",
                          "Summers and Chartrand 1981 via https://militaryheritage.com/c_franch.htm",
                          "https://collections.vam.ac.uk/item/O127143/suit-unknown"],
           "female_body_note": "Built for every fit; on a woman it is artistic licence (regulars' coats were men's)."})


VESTE_GAP = 0.011            # the skirts' room over the veste's skirts (m)
BUST = {"fits": ("f", "bl", "bs"), "z_min": 0.90, "bottom_z": 0.92, "reach": 0.07, "gap": 0.012}   # on the female fits the front hangs straight from the
                                                                  # bust's apex, no crease under it (2026-10-03)
# the pocket flaps stand 4.5 mm proud (2026-10-03: at 3.2 mm they read as a dotted outline and showed the lining at
# their back end, where they ran onto the side pleats: they end before them now), the buttons on the flap
POCKETS = {"z": (0.83, 0.88), "a": (54.0, 90.0), "h": 0.0045, "buttons": 5, "on_flap": True}
STYLE = recipes.style(recipes.MARINE_JUSTAUCORPS, over=tuple(SPEC.over), bust=BUST, pockets=POCKETS)
UNDER_SKIRTS = ["veste_sleeved", "waistcoat_skirted"]    # long-skirted layers the skirts get more room over


def build(g):
    recipes.coat(g, STYLE)
    # the buttons go on last (the pushes below would smooth them into the cloth): taken off, put back at the end
    g.m = g.m.faces_of(g.m.fa["part"] != 9)
    TL.clean(g)          # the sliver where the centre-back seam meets a cut shaded as a dark spot on the back
    # a push over the layers under it left a bump on the right hip in the large-bust fit only: spread each fit's
    # offset over the skirts, then clear the layers under them again
    arm = np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"])
    # the skirt lining (the facing zone below the waist, off the sleeves) moves with the cloth over it
    zf = np.zeros(g.m.n)
    np.maximum.at(zf, g.m.F.ravel(), np.repeat(g.m.fa["zone"] == 1, 3).astype(float))
    lining = (zf > 0) & (g.P[:, 2] < 0.95) & (arm < 0.5)
    before = {k: v.copy() for k, v in g.m.V.items()}
    TL.relax_fits(g, lambda P: (P[:, 2] < 0.95) & (arm < 0.5) & ~lining)
    g.over(SPEC.over, 0.004, where=lambda P: P[:, 2] < 0.95)
    # more room over the veste's and the long waistcoat's skirts than the shipped layers need: in the idle stance and
    # the walk the two skirts swing a little apart and the veste came through at the hips
    g.over(UNDER_SKIRTS, VESTE_GAP, where=lambda P: P[:, 2] < 0.95)
    TL.carry(g, before, lining)
    recipes._coat_buttons(g, STYLE, getattr(g, "_hung_z", STYLE["bottom"]))
    g.uv()


build_and_export = G.runner(SPEC, build)
