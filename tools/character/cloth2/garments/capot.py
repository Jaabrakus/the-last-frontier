"""The hooded capot (cloth2 recipe: recipes.capot's wrap-over coat, with cloth2.hood): a knee-length coat of wool
cloth wrapped over in front (the left front over the right) and held at the neck by one button and by the sash, a
standing collar, round cuffs, the hood lying on the back. Plain cloth by default; the 1750s blanket-end stripes are
an option (zone 0 bands, off by default)."""

import numpy as np

from cloth2 import garment as G
from cloth2 import hood as HD
from cloth2 import recipes
from cloth2 import tailor as TL
from cloth2.mesh import smoothstep
from cloth2.spec import Spec, Zone

PAL = ["grey_white", "slate_grey", "stroud_blue", "walnut_brown", "linen_white", "drab", "#E3DED0"]
CONTRAST = ["stroud_red", "stroud_blue", "madder_red", "grey_white", "slate_grey", "walnut_brown", "royal_blue"]
BANDS = {"axis": "x", "source": "CUSTOM0.x (height above the hem, or distance from the cuff end; metres)",
         "rows_max": 3, "default_rows": 0, "offset_m": 0.05, "width_m": 0.035, "gap_m": 0.025,
         "palette": ["stroud_blue", "madder_red", "stroud_red", "logwood_black"], "default": "stroud_blue"}

SPEC = Spec(
    id="capot", name="Hooded capot", set="colonial", slot="outer", layer={"default": 40},
    description="A knee-length wool coat wrapped over in front and closed by one button at the neck and the sash, "
                "with a standing collar, round cuffs and a hood lying on the back.",
    history="The capot was the Canadian winter coat, issued to the militia and to the colonial regulars for "
            "campaigns: cut to overlap in front, the hood and collar often of another colour (d'Aleyrac), and worn "
            "with a sash, mitasses and moccasins; settlers and rangers wore it in winter too. Striped blanket "
            "capots were discouraged for the 1750s; plain cloth is the default, stripes an option [S2][S1][S3][M5]"
            "[M7].",
    zones=[Zone(0, "cloth", "cloth", "WOOL", PAL, "grey_white", bands=BANDS),
           Zone(1, "hood and collar", "trim", "WOOL", CONTRAST, "stroud_red"),
           Zone(2, "button", "button", "MET", ["pewter", "brass", "logwood_black"], "pewter"),
           Zone(3, "cuffs", "trim", "WOOL", PAL + ["stroud_red", "royal_blue"], "grey_white")],
    sources=["S2", "S1", "S3", "M5", "M7"], evidence="A", tags=["men", "women", "colonial", "canada", "winter"],
    budget=8000, over=["shirt_linen", "breeches", "waistcoat_sb", "veste_sleeved"],
    extra={"presets": {"canadian": {"0": "grey_white", "1": "stroud_red", "2": "pewter", "3": "grey_white"},
                       "canadian_blue": {"0": "stroud_blue", "1": "stroud_red", "2": "pewter", "3": "stroud_blue"},
                       "marine_campaign": {"0": "grey_white", "1": "grey_white", "2": "pewter", "3": "grey_white"},
                       "settler_brown": {"0": "walnut_brown", "1": "walnut_brown", "2": "logwood_black", "3": "walnut_brown"}},
           "stripes_note": "Zone 0 bands: the 1770s white capot with blue bands, off by default for 1757 (Fort "
                           "Ticonderoga's 1759 guidelines discourage striped-blanket capots).",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-Canadian-Milice-Guidelines.pdf",
                          "https://www.fortticonderoga.org/wp-content/uploads/2019/06/Milice.pdf",
                          "https://thecanadianencyclopedia.ca/en/article/clothing-during-the-colonial-period"]})

ZONES = {"cloth": 0, "facing": 3, "button": 2, "trim": 1}
SKIRT_RELAX_Z = 0.95
VESTE_GAP = 0.011            # the skirts' room over the veste's skirts (m)
BUST = {"fits": ("f", "bl", "bs"), "z_min": 0.90, "bottom_z": 0.92, "reach": 0.07, "gap": 0.012}   # on the female fits the front hangs straight from the
                                                                  # bust's apex, no crease under it (2026-10-03)
# (2026-10-03) unbelted the capot was a straight tube (a lab coat, a nightshirt): taken in at the waist under the sash
# or the cartridge belt, its skirt flaring more; the hood fuller, its face opening rolled
WAIST = (0.94, 1.00, 0.045, 0.011)   # the tuck: full from WAIST[0] to [1] (m), fading over [2] above and below; depth
FLARE = 0.13                         # the skirt's flare (the recipe's 0.09)
HOOD = {"h_max": 0.040, "h_neck": 0.016, "h_edge": 0.006, "roll": 0.012}
COLLAR_TAPER = (-0.035, 0.005)   # the standing collar round the front dies away at the sides of the neck (y, m):
                                 # behind, the hood is sewn to the neckline


def build(g):
    recipes.capot(g, recipes.style(recipes.CAPOT, over=tuple(SPEC.over), hood=None, zones=ZONES, collar=None,
                                   bust=BUST, flare=FLARE))
    # the waist taken in (the layers under it are cleared again below)
    arm = np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"])
    z = g.P[:, 2]
    tuck = smoothstep(WAIST[0] - WAIST[2], WAIST[0], z) * (1.0 - smoothstep(WAIST[1], WAIST[1] + WAIST[2], z)) * \
        (1.0 - smoothstep(0.2, 0.5, arm))
    g.m.offset(-WAIST[3] * tuck, vertical=0.2)
    g.m.smooth(2, 0.5, weights=np.minimum(1.0, 2.0 * tuck))
    g.over(SPEC.over, 0.004, where=lambda P: (P[:, 2] > WAIST[0] - WAIST[2] - 0.01) & (P[:, 2] < WAIST[1] + WAIST[2] + 0.01))
    TL.clean(g)
    # a standing collar round the front and the hood sewn on behind, in the contrast zone (the recipe's facing zone
    # is the cuffs' here)
    TL.neck_collar(g, 0.026, lean=0.12, zone=1, taper=COLLAR_TAPER)
    # the hood drawn in to the neckline (its sides on the shoulder blades), full over the upper back, its back seam
    HD.hood_on_back(g, h_max=HOOD["h_max"], h_neck=HOOD["h_neck"], h_edge=HOOD["h_edge"], roll=HOOD["roll"],
                    neck=(0.30, 0.70), seam=0.004, zone=1)
    # the skirt in the small-bust fit hung onto the shirt's side flare and was pushed into a bump at the left hip:
    # spread each fit's offset over the skirt, then clear the layers under it again
    skirt = lambda P: (P[:, 2] < SKIRT_RELAX_Z) & (np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"]) < 0.5)
    TL.relax_fits(g, skirt)
    g.over(SPEC.over, 0.004, where=lambda P: P[:, 2] < SKIRT_RELAX_Z)
    # more room over the veste's skirts than the shipped layers need: in the idle stance and the walk the two skirts
    # swing a little apart and the veste came through at the hips
    g.over(["veste_sleeved"], VESTE_GAP, where=lambda P: P[:, 2] < 0.95)
    g.uv()


build_and_export = G.runner(SPEC, build)
