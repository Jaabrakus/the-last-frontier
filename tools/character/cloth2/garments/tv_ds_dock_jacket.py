"""The Dragon-Sea dock jacket (cloth2 recipe type robe, mode crossed: cloth2.dress.ROBE): a short crossed jacket of
faded indigo to the hip, the sleeves to the forearm with a rolled salt-white cuff. The dock workers and boat folk of
Vạn Thủy and the Lock Road."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_ds_rolled_trousers"]

SPEC = Spec(
    id="tv_ds_dock_jacket", name="Dock jacket", set="tv_delta", slot="shirt", layer={"default": 20},
    description="A short crossed jacket of faded indigo to the hip, the sleeves rolled to the forearm.",
    history="Design note: the dock workers on the Vạn Thủy grain piers: faded indigo jackets over pale rolled "
            "trousers under conical hats. The rolled cuffs are the one light note at the arms.",
    zones=[Zone(0, "faded indigo", "cloth", "LIN", TV.DELTA, "tv_dock_indigo"),
           Zone(1, "rolled cuffs and collar", "trim", "LIN", TV.DELTA, "tv_salt_white"),
           Zone(2, "unused", "metal", "MET", TV.METALS, "tv_bronze"),
           Zone(3, "ties", "ribbon", "HES", TV.DELTA, "tv_rope")],
    sources=[], evidence="C", tags=["men", "women", "tv_delta", "dragon_sea", "everyday", "npc"], budget=6500,
    over=UNDER,
    extra=TV.extra({0: "weave", 1: "weave", 2: "metal", 3: "cord"},
                   presets={"faded": {"0": "tv_dock_indigo", "1": "tv_salt_white"},
                            "navy": {"0": "tv_deep_navy", "1": "tv_salt_white"},
                            "teal": {"0": "tv_estuary_teal", "1": "tv_pearl"}},
                   note="cloth2.dress.robe mode crossed, hem 0.86, sleeves to 0.62 (rolled: a 7 cm cuff raised 6 mm, "
                        "zone 1), a 3 cm collar band, ties at -50 deg."))

STYLE = recipes.style(dress.ROBE, mode="crossed", hem=(0.86, 0.865, 0.87), flare=0.05, folds=0.005, steps=5,
                      sleeve_end=0.62, sleeve_ease=(0.004, 0.014), over=tuple(UNDER), over_gap=0.006, skirt_gap=0.035,
                      slits=[(80.0, 100.0, 0.95)], cuffs={"t0": 0.53, "h": 0.006, "flare": 0.004},
                      collar_band={"w": 0.03, "h": 0.003}, ties=[(-50.0, 1.05), (-50.0, 0.98)],
                      overlap_line=dict(dress.ROBE["overlap_line"], split_below=0.93))


def build(g, st=STYLE):
    recipes.robe(g, st)


build_and_export = G.runner(SPEC, build)
