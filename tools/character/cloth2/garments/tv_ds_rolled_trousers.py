"""The Dragon-Sea rolled trousers (cloth2 recipe type trousers, wide: cloth2.dress.TROUSERS): salt-white wide trousers
rolled up to mid-shin (the cuff falls over a rolled band), for wading at the piers and the locks."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_ds_rolled_trousers", name="Rolled trousers", set="tv_delta", slot="legs.lower", layer={"default": 30},
    description="Wide salt-white trousers rolled up to mid-shin.",
    history="Design note: the pale legs of the Vạn Thủy dock workers, rolled for the water's edge; the roll is a "
            "fat band so it reads.",
    zones=[Zone(0, "cloth", "cloth", "LIN", TV.DELTA, "tv_salt_white"),
           Zone(1, "drawstring band and roll", "trim", "LIN", TV.DELTA, "tv_salt_white")],
    hides_force=["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_upper_r"],
    sources=[], evidence="C", tags=["men", "women", "pants", "tv_delta", "dragon_sea", "everyday", "npc"], budget=6000,
    extra=TV.extra({0: "weave", 1: "weave"},
                   presets={"salt": {"0": "tv_salt_white", "1": "tv_salt_white"},
                            "indigo": {"0": "tv_dock_indigo", "1": "tv_dock_indigo"}},
                   note="cloth2.dress.trousers wide: to 0.72, cuff fall (a 5 cm roll raised 7 mm), flare to 4 cm."))

STYLE = dress._style(dress.TROUSERS, {"end": 0.72, "cuff": {"kind": "band", "len": 0.05, "h": 0.007},
                                      "crotch": {"drop": 0.030, "width": 0.075},
                                      "flare": [(0.18, 0.0), (0.28, 0.035), (0.40, 0.040), (0.56, 0.030), (0.72, 0.02)],
                                      "folds": {"amp": 0.007, "count": 7.0}})


def build(g, st=STYLE):
    recipes.trousers(g, st)


build_and_export = G.runner(SPEC, build)
