"""The Stone Children shade cloth (cloth2 recipe type drape, one shoulder: cloth2.dress.DRAPE): a pale dust-buff cloth
laid across the back and over one shoulder, down the front to the thigh, a rolled edge; it keeps the sun off hot
mineral skin (the bible's sensory anchor)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_sc_work_tunic", "tv_sc_trousers"]

SPEC = Spec(
    id="tv_sc_shade_cloth", name="Shade cloth", set="tv_stone", slot="accessories.wrap", layer={"default": 50},
    description="A pale cloth across the back and over one shoulder, down the front to the waist, a rolled edge.",
    history="Design note: the pale diagonal across the mason's dark tunic on the lineup sheet. It breaks the Stone "
            "Children's block silhouette with one light stroke and keeps the sun off hot stone skin.",
    zones=[Zone(0, "shade cloth", "cloth", "LIN", TV.STONE, "tv_dust_buff"),
           Zone(1, "unused", "trim", "LIN", TV.STONE, "tv_dust_buff")],
    sources=[], evidence="C", tags=["men", "women", "tv_stone", "stone_children", "everyday"], budget=5000,
    over=UNDER,
    extra=TV.extra({0: "weave", 1: "weave"}, presets={"dust": {"0": "tv_dust_buff"}, "quarry": {"0": "tv_quarry_white"},
                                                      "hemp": {"0": "tv_hemp"}},
                   note="cloth2.dress.drape one_shoulder: over the right shoulder, the left arm bare; the outline's "
                        "outline a diagonal band 0.15-0.30 m wide from the right shoulder to the left hip, a rolled top edge."))

# a diagonal band: from over the right shoulder down across the breast and the back to the left hip
STYLE = dress._style(dress.DRAPE, {"over": tuple(UNDER), "arm_z": 1.24, "ease": 0.014,
                                   "top": [(-180.0, 1.42), (-150.0, 1.70), (-40.0, 1.70), (-20.0, 1.30), (20.0, 1.17),
                                           (60.0, 1.06), (110.0, 1.08), (150.0, 1.24)],
                                   "bottom": [(-180.0, 1.12), (-120.0, 1.26), (-80.0, 1.26), (-40.0, 1.10),
                                              (0.0, 0.99), (60.0, 0.90), (120.0, 0.93), (160.0, 1.04)]})


def build(g, st=STYLE):
    recipes.drape(g, st)


build_and_export = G.runner(SPEC, build)
