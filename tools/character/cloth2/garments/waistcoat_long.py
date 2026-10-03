"""The seaman's long waistcoat (cloth2: recipes.waistcoat, the Drift crews' set): sleeveless, single-breasted, nine
buttons up to a V at the breast, the fronts parting into two points below the last, pocket flaps, a linen back. Cut
to sit over the slops (or breeches) and under a short sea jacket or a coat."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["madder_red", "snuff", "buff", "slate_grey", "kersey_blue", "walnut_brown", "tow", "logwood_plum"]

SPEC = Spec(
    id="waistcoat_long", name="Waistcoat, sea", set="drift", slot="vest", layer={"default": 20, "hips": 25, "thighs": 25},
    description="A sleeveless wool waistcoat, nine buttons to a V at the breast, the fronts parting into points over "
                "the hips, pocket flaps, a linen back.",
    history="Sailors wore waistcoats in many colours under their short jackets (period illustrations [D1]); cut "
            "like the landsman's waistcoat of the 1750s, single-breasted with a V at the breast and fronts of good "
            "cloth on a cheaper linen back. Ithel's is buff, Rook's an old snuff-brown one.",
    zones=[Zone(0, "fronts", "cloth", "WOOL", PAL, "madder_red"),
           Zone(1, "back", "lining", "LIN", ["linen_unbleached", "tow", "linen_white", "slate_grey"], "linen_unbleached"),
           Zone(2, "buttons", "button", "MET", ["brass", "pewter", "horn", "leather_black"], "brass")],
    sources=["D1"], evidence="B", tags=["drift", "sailor"], budget=3600,
    over=["shirt_check", "slops", "shirt_linen", "breeches"],
    extra={"presets": {"ithel": {"0": "buff", "1": "linen_unbleached", "2": "brass"},
                       "rook": {"0": "snuff", "1": "tow", "2": "horn"},
                       "deckhand": {"0": "madder_red", "1": "linen_unbleached", "2": "pewter"}},
           "references": ["[D1] HMS Richmond, Sailor's Dress of 1775: https://hmsrichmond.org/sailordress.htm"]})

STYLE = recipes.style(
    recipes.WAISTCOAT, neck={"a": 0.086, "b": 0.077, "z0": 1.330, "tilt": 17.0},
    hem=(0.835, 0.865, 0.88),
    opening=[(0.76, 0.075), (0.80, 0.055), (0.835, 0.038), (0.88, 0.016), (0.935, 0.0), (1.21, 0.0), (1.27, 0.034),
             (1.33, 0.060), (1.40, 0.10), (1.6, 0.12)],
    buttons={"n": 9, "z": (1.195, 0.945), "x": -0.0075, "r": 0.0068},
    pockets={"z": (0.918, 0.944), "x": (0.05, 0.13), "h": 0.0028},
    over=tuple(SPEC.over), over_gap=0.005)


def build(g):
    recipes.waistcoat(g, STYLE)


build_and_export = G.runner(SPEC, build)
