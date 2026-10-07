"""The Mountain Folk wide trousers (cloth2 recipe type trousers, wide: cloth2.dress.TROUSERS): full at the thigh and
the knee, narrowing below it to an open end at mid-calf where the leg wraps bind them; a drawstring band at the
waist. The everyday legwear of the high places under the vest or robe, the hip panels and the wraps."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_mf_trousers", name="Wide trousers to the calf", set="tv_highland", slot="legs.lower",
    layer={"default": 30},
    description="Wide trousers of indigo-black homespun on a drawstring, full at the thigh and knee and narrowing to an "
                "open end at mid-calf, made to be bound by leg wraps.",
    history="Design note: the sheets' figures read as a full dark mass from the hips to the knee and a bound white "
            "shin below it; the trousers give the mass and stop where the wraps begin (peoples_design.md 3.1).",
    zones=[Zone(0, "homespun", "cloth", "LIN", TV.HIGHLAND, "tv_indigo_black"),
           Zone(1, "drawstring band", "trim", "HES", TV.HIGHLAND, "tv_hemp")],
    hides_force=["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_upper_r"],
    sources=[], evidence="C", tags=["men", "women", "pants", "tv_highland", "mountain_folk", "everyday"], budget=6000,
    extra=TV.extra({0: "weave", 1: "hemp"}, presets={"stone_ridge": {"0": "tv_indigo_black", "1": "tv_hemp"},
                                                       "high_pine": {"0": "tv_pine_black", "1": "tv_hemp"},
                                                       "undyed": {"0": "tv_hemp", "1": "tv_hemp"}},
                   note="cloth2.dress.trousers wide: the legs to 0.80 (mid-calf), cuff open; flare to 6.5 cm at the "
                        "thigh, falling to nothing below the knee (the wraps go over it); crotch drop 3 cm."))

STYLE = dress._style(dress.TROUSERS, {"end": 0.80, "cuff": {"kind": "open"}, "crotch": {"drop": 0.030, "width": 0.075},
                                      "flare": [(0.18, 0.0), (0.32, 0.040), (0.48, 0.065), (0.60, 0.040),
                                                (0.70, 0.012), (0.80, 0.004)],
                                      "folds": {"amp": 0.008, "count": 7.0}, "leg_ease": (0.016, 0.014)})


def build(g, st=STYLE):
    recipes.trousers(g, st)


build_and_export = G.runner(SPEC, build)
