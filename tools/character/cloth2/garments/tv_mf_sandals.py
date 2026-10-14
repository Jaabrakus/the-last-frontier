"""The rope-soled sandals of the high places (cloth2 recipe type sandals, rope: cloth2.tv_dress.ROPE_SANDALS): a
plaited sole under each foot, two straps over it, and ankle cords crossing twice round the foot of the leg wraps.
Shared cut (tv_common), in highland dyes."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_mf_sandals", name="Rope-soled sandals", set="tv_highland", slot="feet", layer={"default": 40},
    description="Plaited rope-soled sandals with two straps over the foot and cords crossing round the ankle.",
    history="Design note: the hunter's and the porter's feet on the sheets: bare toes, a thick sole, cords at the "
            "ankle running up into the leg wraps.",
    zones=[Zone(0, "sole", "leather", "LEA", TV.HIGHLAND, "tv_walnut"),
           Zone(1, "straps and cords", "ribbon", "HES", TV.HIGHLAND, "tv_hemp")],
    sources=[], evidence="C", tags=["men", "women", "tv_highland", "tv_common", "mountain_folk", "everyday"],
    budget=2500,
    extra=TV.extra({0: "leather", 1: "cord"},
                   presets={"rope": {"0": "tv_walnut", "1": "tv_hemp"}, "dark": {"0": "tv_walnut", "1": "tv_madder"}},
                   note="cloth2.tv_dress.sandals rope: feet.SockTube 3.2 mm off the skin; its downward faces flattened "
                        "onto z -10 mm, a 6 mm welt, 12 mm thick; straps 18-20 mm kept from the tube over the ball and "
                        "the instep; two cords on opposite helices 0.055-0.155 m."))

STYLE = TVD.ROPE_SANDALS


def build(g, st=STYLE):
    recipes.sandals(g, st)


build_and_export = G.runner(SPEC, build)
