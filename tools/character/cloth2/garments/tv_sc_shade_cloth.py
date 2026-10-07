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
    description="A pale cloth across the back and over one shoulder, down the front to the thigh, a rolled edge.",
    history="Design note: the pale diagonal across the mason's dark tunic on the lineup sheet. It breaks the Stone "
            "Children's block silhouette with one light stroke and keeps the sun off hot stone skin.",
    zones=[Zone(0, "shade cloth", "cloth", "LIN", TV.STONE, "tv_dust_buff"),
           Zone(1, "unused", "trim", "LIN", TV.STONE, "tv_dust_buff")],
    sources=[], evidence="C", tags=["men", "women", "tv_stone", "stone_children", "everyday"], budget=5000,
    over=UNDER,
    extra=TV.extra({0: "weave", 1: "weave"}, presets={"dust": {"0": "tv_dust_buff"}, "quarry": {"0": "tv_quarry_white"},
                                                      "hemp": {"0": "tv_hemp"}},
                   note="cloth2.dress.drape one_shoulder: over the right shoulder, the left arm bare; the outline's "
                        "foot raised to 0.80-0.86 (a shorter cloth than the West African mantle), a rolled top edge."))

STYLE = dress._style(dress.DRAPE, {"over": tuple(UNDER), "arm_z": 1.17, "ease": 0.014,
                                   "bottom": [(-180.0, 0.82), (-90.0, 0.86), (0.0, 0.78), (90.0, 0.86)]})


def build(g, st=STYLE):
    recipes.drape(g, st)


build_and_export = G.runner(SPEC, build)
