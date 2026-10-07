"""The Stone Children heavy sandals (cloth2 recipe type sandals, heavy: cloth2.tv_dress.HEAVY_SANDALS): a thick leather
sole, two broad straps over the foot, a heel strap and short ankle thongs; the quarry's footwear."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_sc_sandals", name="Heavy sandals", set="tv_stone", slot="feet", layer={"default": 40},
    description="Thick-soled leather sandals with two broad straps over the foot, a heel strap and ankle thongs.",
    history="Design note: the mason's feet on the lineup: a thick sole for stone ground, broad straps; chunky so they "
            "read under wide trousers.",
    zones=[Zone(0, "sole", "leather", "LEA", TV.STONE, "tv_leather"),
           Zone(1, "straps", "leather", "LEA", TV.STONE, "tv_leather")],
    sources=[], evidence="C", tags=["men", "women", "tv_stone", "tv_common", "stone_children", "everyday"],
    budget=2500,
    extra=TV.extra({0: "leather", 1: "leather"}, presets={"leather": {"0": "tv_leather", "1": "tv_leather"},
                                                          "dark": {"0": "tv_walnut", "1": "tv_charcoal"}},
                   note="cloth2.tv_dress.sandals heavy: a 24 mm sole to z -22 mm, an 8 mm welt; straps 26 and 30 mm; "
                        "a heel strap 30-58 mm; thongs half a turn 0.06-0.12 m."))

STYLE = TVD.HEAVY_SANDALS


def build(g, st=STYLE):
    recipes.sandals(g, st)


build_and_export = G.runner(SPEC, build)
