"""The short waistcoat (cloth2 recipe: recipes.waistcoat): sleeveless, a V at the neck from 1.16 m, eleven buttons to
the waist, the fronts parting below into two points at the hip, pocket flaps, a linen back. The cut-down waistcoat of
the summer 1758 orders and after (2026-10-03: this was waistcoat_sb, which is the 1750s length now)."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["drab", "walnut_brown", "butternut", "stroud_blue", "madder_red", "buff", "indigo_mid", "ranger_green",
       "linen_unbleached", "logwood_black"]

SPEC = Spec(
    id="waistcoat_short", name="Waistcoat, short", set="colonial", slot="vest",
    layer={"default": 20, "hips": 25, "thighs": 25},
    description="A short sleeveless waistcoat buttoned from a V at the breast to the waist, the fronts parting into "
                "points at the hip, with pocket flaps; wool fronts on a linen back.",
    history="The summer 1758 orders cut the regulars' coats and waistcoats short for the woods; the short waistcoat "
            "with points at the hip is otherwise the fashion of the 1770s and 80s [S4][M3]. For 1757 the long "
            "waistcoat (waistcoat_sb) is the period's.",
    zones=[Zone(0, "fronts", "cloth", "WOOL", PAL, "drab"),
           Zone(1, "back", "lining", "LIN", ["linen_unbleached", "linen_white", "tow", "drab"], "linen_unbleached"),
           Zone(2, "buttons", "button", "MET", ["brass", "pewter", "silver", "logwood_black"], "brass")],
    sources=["S4", "M3"], evidence="B", tags=["men", "colonial"], budget=3600,
    over=["shirt_linen", "breeches"],
    extra={"period_note": "After summer 1758 (the cut-down dress); 1770s-80s civilian fashion.",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-British-Regulars-Guidelines.pdf"]})


def build(g):
    recipes.waistcoat(g, recipes.style(recipes.WAISTCOAT, over=tuple(SPEC.over)))


build_and_export = G.runner(SPEC, build)
