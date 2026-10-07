"""The Stone Children wide work trousers (cloth2 recipe type trousers, wide: cloth2.dress.TROUSERS): dust-buff, full to
the knee and bound below it by leg wraps; the quarry's dust colour."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_sc_trousers", name="Wide work trousers", set="tv_stone", slot="legs.lower", layer={"default": 30},
    description="Wide dust-buff work trousers on a drawstring, full to the knee, the ends bound by leg wraps.",
    history="Design note: the pale legs under the mason's dark tunic and apron (lineup); the cut of the highland "
            "trousers, fuller (Stone Children read broad).",
    zones=[Zone(0, "work cloth", "cloth", "LIN", TV.STONE, "tv_dust_buff"),
           Zone(1, "drawstring band", "trim", "HES", TV.STONE, "tv_leather")],
    hides_force=["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_upper_r"],
    sources=[], evidence="C", tags=["men", "women", "pants", "tv_stone", "stone_children", "everyday"], budget=6000,
    extra=TV.extra({0: "weave", 1: "leather"}, presets={"dust": {"0": "tv_dust_buff"}, "charcoal": {"0": "tv_charcoal"}},
                   note="cloth2.dress.trousers wide: to 0.80, cuff open, flare to 4.5 cm at the thigh."))

STYLE = dress._style(dress.TROUSERS, {"end": 0.80, "cuff": {"kind": "open"}, "crotch": {"drop": 0.030, "width": 0.075},
                                      "flare": [(0.18, 0.0), (0.26, 0.038), (0.36, 0.045), (0.46, 0.018),
                                                (0.56, 0.0), (0.80, 0.0)],
                                      "folds": {"amp": 0.009, "count": 7.0}, "leg_ease": (0.018, 0.015)})


def build(g, st=STYLE):
    recipes.trousers(g, st)


build_and_export = G.runner(SPEC, build)
