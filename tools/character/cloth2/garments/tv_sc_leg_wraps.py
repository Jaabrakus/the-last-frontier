"""The Stone Children leg wraps (cloth2 recipe type leg_wraps: cloth2.tv_dress.LEG_WRAPS): charcoal strips wound down
the shins over the work trousers, a leather thong crossing them; the shared cut in quarry dyes."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_sc_trousers"]

SPEC = Spec(
    id="tv_sc_leg_wraps", name="Leg wraps", set="tv_stone", slot="legs.over", layer={"default": 35},
    description="Charcoal strips wound down the shins over the trousers, a leather thong crossing them.",
    history="Design note: the dark bound shins of the mason (lineup) over pale trousers: the reverse of the highland "
            "wraps' light-on-dark.",
    zones=[Zone(0, "strip", "cloth", "WOOL", TV.STONE, "tv_charcoal"),
           Zone(1, "thong", "leather", "LEA", TV.STONE, "tv_leather")],
    sources=[], evidence="C", tags=["men", "women", "tv_stone", "stone_children", "everyday"], budget=3500, over=UNDER,
    extra=TV.extra({0: "felt", 1: "leather"}, note="cloth2.tv_dress.leg_wraps, a 7.2 cm strip, 3 crossings."))

STYLE = dict(TVD.LEG_WRAPS, over=tuple(UNDER), width=0.072, cord={"w": 0.005, "crosses": 3, "lift": 0.003})


def build(g, st=STYLE):
    recipes.leg_wraps(g, st)


build_and_export = G.runner(SPEC, build)
