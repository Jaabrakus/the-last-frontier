"""The Dragon-Sea tide short robe (cloth2 recipe type robe, mode crossed: cloth2.dress.ROBE): an estuary-teal robe to
the knee, wide sleeves to the elbow, our own tide-scroll weave (stacked arcs) in the cloth, a pearl collar band. The
dock woman of the Common Folk lineup, over the two-layer skirt."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_ds_long_skirt"]

SPEC = Spec(
    id="tv_ds_short_robe", name="Tide short robe", set="tv_delta", slot="vest", layer={"default": 36},
    description="An estuary-teal crossed robe to the knee, wide sleeves to the elbow, a tide-scroll weave, a pearl "
                "collar band.",
    history="Design note: the lineup's dock woman: a teal robe over a long navy skirt, knotted white at the waist. "
            "The tide scroll is our own stacked-arc weave (one ring form; no swirl, nothing from any show's emblem).",
    zones=[Zone(0, "tide cloth", "cloth", "LIN", TV.DELTA, "tv_estuary_teal"),
           Zone(1, "collar band", "band", "LIN", TV.DELTA, "tv_pearl"),
           Zone(2, "unused", "metal", "MET", TV.METALS, "tv_gold"),
           Zone(3, "ties", "ribbon", "FLAT", TV.DELTA, "tv_pearl")],
    sources=[], evidence="C", tags=["men", "women", "tv_delta", "dragon_sea", "everyday"], budget=8000, over=UNDER,
    extra=TV.extra({0: "weave", 1: "weave", 2: "metal", 3: "cord"}, {0: TV.TIDE},
                   presets={"teal": {"0": "tv_estuary_teal", "1": "tv_pearl"},
                            "sea_glass": {"0": "tv_sea_glass", "1": "tv_deep_navy"},
                            "faded": {"0": "tv_dock_indigo", "1": "tv_salt_white"}},
                   note="cloth2.dress.robe mode crossed, hem 0.55, sleeves to 0.55 eased to 3.2 cm (wide, "
                        "open), a 3.6 cm collar band, side slits to 0.80; tide_scroll motif on zone 0."))

STYLE = recipes.style(dress.ROBE, mode="crossed", hem=(0.55, 0.55, 0.555), flare=0.10, folds=0.007, steps=10,
                      sleeve_end=0.55, sleeve_ease=(0.008, 0.032), over=tuple(UNDER), over_gap=0.007,
                      over_relax=1, skirt_gap=0.04, slits=[(82.0, 98.0, 0.80)], cuffs=None,
                      collar_band={"w": 0.036, "h": 0.0035}, ties=[(-50.0, 1.05), (-50.0, 0.98)])


def build(g, st=STYLE):
    recipes.robe(g, st)


build_and_export = G.runner(SPEC, build)
