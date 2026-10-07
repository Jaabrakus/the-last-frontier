"""The Dragon-Sea two-layer wrap skirt (cloth2 recipe type wrap_skirt: cloth2.dress.WRAP_SKIRT): a deep-navy cloth
wound to the ankle, its overlap open at the front, over a pale sea-glass under-layer that shows as a stepped band below
the knee. The dock woman's skirt (lineup)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_ds_long_skirt", name="Two-layer wrap skirt", set="tv_delta", slot="legs.lower",
    layer={"default": 30, "hips": 35}, alt_slots=["accessories.waist"],
    description="A deep-navy wrap skirt to the ankle, its overlap open at the front, a pale under-layer showing as a "
                "stepped band below the knee.",
    history="Design note: the lineup's dock woman reads as a long dark column under a teal robe, a pale band at the "
            "knee breaking it; the open overlap lets her stride.",
    zones=[Zone(0, "navy cloth", "cloth", "LIN", TV.DELTA, "tv_deep_navy"),
           Zone(1, "under-layer band", "trim", "LIN", TV.DELTA, "tv_sea_glass")],
    sources=[], evidence="C", tags=["women", "men", "tv_delta", "dragon_sea", "everyday"], budget=6000,
    extra=TV.extra({0: "weave", 1: "weave"},
                   presets={"navy": {"0": "tv_deep_navy", "1": "tv_sea_glass"},
                            "teal": {"0": "tv_estuary_teal", "1": "tv_pearl"}},
                   note="cloth2.dress.wrap_skirt from 1.035 to the hem 0.10, a rim at 0.40 raised 6 mm, the band "
                        "below 0.40 the under-layer (zone 1), the overlap at -30 deg open to the band."))

STYLE = dress._style(dress.WRAP_SKIRT, {"hem": 0.10, "flare": 0.10, "folds": 0.012, "steps": 14, "tail_gap": 0.03,
                                        "rims": [(0.40, 0.006)]})


def build(g, st=STYLE):
    recipes.wrap_skirt(g, st)
    g.zone(1, below=0.40)


build_and_export = G.runner(SPEC, build)
