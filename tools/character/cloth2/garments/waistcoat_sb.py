"""The single-breasted waistcoat (cloth2 recipe: recipes.waistcoat): sleeveless, a V at the neck from 1.16 m, thirteen
buttons to below the waist, the skirts to the upper thigh with low pocket flaps, the fronts curving apart a little below
the last button; a linen back. The length of the 1750s (2026-10-03: it was the hip-length waistcoat with points of the
1770s-80s; that cut is waistcoat_short now, for the cut-down dress after the summer 1758 orders)."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["drab", "walnut_brown", "butternut", "stroud_blue", "madder_red", "buff", "indigo_mid", "ranger_green",
       "linen_unbleached", "logwood_black"]

SPEC = Spec(
    id="waistcoat_sb", name="Waistcoat, single-breasted", set="colonial", slot="vest",
    layer={"default": 20, "hips": 25, "thighs": 25},
    description="A sleeveless waistcoat buttoned from a V at the breast to below the waist, its skirts to the upper "
                "thigh with low pocket flaps, the fronts curving apart below the last button; wool fronts on a linen "
                "back.",
    history="Worn by men of every rank over the shirt and under the coat: red, blue, drab, brown or green wool, or "
            "linen in summer, the fronts of good cloth and the back of cheaper linen [M3][M2][R20]; settlers, "
            "militia and regulars alike (the 1759 Fort Ticonderoga guidelines). In the 1750s waistcoats reached the "
            "upper or middle thigh; the short waistcoat with points came in with the cut-down dress of the later "
            "1750s and is the fashion of the 1770s and 80s (waistcoat_short).",
    zones=[Zone(0, "fronts", "cloth", "WOOL", PAL, "drab"),
           Zone(1, "back", "lining", "LIN", ["linen_unbleached", "linen_white", "tow", "drab"], "linen_unbleached"),
           Zone(2, "buttons", "button", "MET", ["brass", "pewter", "silver", "logwood_black"], "brass")],
    sources=["M3", "M2", "R20"], evidence="A", tags=["men", "colonial"], budget=4400,
    over=["shirt_linen", "breeches"],
    extra={"length_note": "Hem 0.73 m in front, 0.76 m behind (the upper thigh; 2026-10-03). The hip-length cut is "
                          "waistcoat_short.",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-British-Regulars-Guidelines.pdf",
                          "https://goschenhoppen.org/colonial-clothing/"]})

# recipes.WAISTCOAT to the upper thigh: buttoned to 0.90, the fronts curving apart below, the pocket flaps low
STYLE = recipes.style(recipes.WAISTCOAT, over=tuple(SPEC.over), hem=(0.73, 0.75, 0.76), flare=0.03, steps=7,
                      skirt_gap=0.018,
                      opening=[(0.70, 0.050), (0.74, 0.040), (0.80, 0.022), (0.86, 0.007), (0.90, 0.0), (1.16, 0.0),
                               (1.24, 0.034), (1.30, 0.060), (1.40, 0.10), (1.6, 0.12)],
                      buttons={"n": 13, "z": (1.15, 0.905), "x": -0.0075, "r": 0.0065},
                      pockets={"z": (0.835, 0.865), "x": (0.05, 0.135), "h": 0.0028})


def build(g):
    recipes.waistcoat(g, STYLE)


build_and_export = G.runner(SPEC, build)
