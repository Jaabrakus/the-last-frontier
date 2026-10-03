"""The sleeved veste (cloth2 recipe: recipes.waistcoat with the VESTE cut): the long sleeved waistcoat of the French
regulars and of Canadians, buttoned from the neck to the waist, skirts to the top of the thigh with pocket flaps,
narrow sleeves stopping short of a coat's cuff. Worn under the justaucorps or the capot, or on its own as the outer
garment (alt slot outer)."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tailor as TL
from cloth2.spec import Spec, Zone

PAL = ["royal_blue", "stroud_blue", "madder_red", "grey_white", "walnut_brown", "drab", "slate_grey", "ranger_green",
       "butternut"]

SPEC = Spec(
    id="veste_sleeved", name="Veste (sleeved waistcoat)", set="colonial", slot="vest", alt_slots=["outer"],
    layer={"default": 20, "hips": 25, "thighs": 25},
    description="A long wool waistcoat with narrow sleeves, buttoned from the neck to the waist, the skirts to the "
                "top of the thigh with pocket flaps.",
    history="The colonial regulars of New France wore a blue veste with blue breeches and stockings under the "
            "grey-white justaucorps, and on campaign the veste was the coat under the capot; Canadians wore vestes "
            "of red, grey, brown or drab, and sleeved waistcoats were worn as the outer garment in the woods [M6]"
            "[M4][M5][S2][S5].",
    zones=[Zone(0, "cloth", "cloth", "WOOL", PAL, "royal_blue"),
           Zone(1, "lining", "lining", "LIN", ["linen_unbleached"], "linen_unbleached"),
           Zone(2, "buttons", "button", "MET", ["brass", "pewter", "logwood_black"], "brass")],
    sources=["M6", "M4", "M5", "S2", "S5"], evidence="A", tags=["men", "colonial", "regulars", "canada"], budget=5300,
    over=["shirt_linen", "breeches"],
    extra={"presets": {"marine": {"0": "royal_blue", "2": "brass"}, "canadian_red": {"0": "madder_red", "2": "pewter"},
                       "canadian_grey": {"0": "grey_white", "2": "pewter"}, "ranger_1758": {"0": "ranger_green", "2": "pewter"}},
           "zone_note": "Zone 1 (a linen back) is not used by this cut: the veste is wool all round.",
           "female_body_note": "Built for every fit; on a woman it is artistic licence (vestes were men's).",
           "references": ["https://militaryheritage.com/c_franch.htm",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-French-Army-Colonial-Regulars-Guidelines-1.pdf",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-Canadian-Milice-Guidelines.pdf"]})


def build(g):
    recipes.waistcoat(g, recipes.style(recipes.VESTE, over=tuple(SPEC.over)))
    TL.clean(g)


build_and_export = G.runner(SPEC, build)
