"""The seaman's neckerchief (cloth2: recipes.neckwear "neckerchief", the Drift crews' set): a check, black or red
handkerchief folded into a narrow band, worn low and loose round the neck and knotted at the throat, the short ends
hanging. A new id beside the old v1 `neckerchief` (militia set), which it does not replace."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="neckerchief_sea", name="Neckerchief, sea", set="drift", slot="accessories.neck", layer={"default": 30},
    description="A check, black or red handkerchief folded into a narrow band, worn low and loose and knotted at the "
                "throat, the short ends hanging.",
    history="Seamen wore neckerchiefs for use, not show; black seems to have been favoured, though checks and colours "
            "were common before anything like a uniform [D1].",
    zones=[Zone(0, "kerchief", "cloth", "LIN", ["logwood_black", "check_blue", "madder_red", "linen_white"], "logwood_black",
                pattern={"options": ["none", "check"], "default": "none",
                         "check": {"colors": ["check_blue", "linen_white"], "scale_m": 0.010}})],
    sources=["D1"], evidence="B", tags=["drift", "sailor"], budget=1000, over=["shirt_check", "shirt_linen"],
    extra={"references": ["[D1] HMS Richmond, Sailor's Dress of 1775: https://hmsrichmond.org/sailordress.htm"],
           "id_note": "Kept apart from the old v1 'neckerchief' (militia set, factions.json): whether one id should "
                      "replace the other is the owner's call."})

STYLE = {"t": (-0.024, 0.008), "ease": 0.014, "knot": (0.018, 0.014, 0.011), "ends": {"len": 0.095, "w": 0.028},
         "buckle": False}


def build(g):
    recipes.neckwear(g, "neckerchief", STYLE)
    g.over(SPEC.over, 0.004)


build_and_export = G.runner(SPEC, build)
