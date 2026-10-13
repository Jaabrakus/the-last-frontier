"""The quarry hat (cloth2 rigid_hat profile CONE: cloth2.dress.lathe_hat): a broad straw cone over the head band, a
leather chin strap; the Thạch Uyên workers' sun hat."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_sc_quarry_hat", name="Quarry hat", set="tv_stone", slot="head", layer={"default": 80},
    description="A broad straw cone hat over an inner head band, with a leather chin strap.",
    history="Design note: the quarry hands at the blocks on the Thạch Uyên sheet wear broad cones against the white "
            "stone's glare; slightly flatter and wider than the delta's conical hat.",
    zones=[Zone(0, "straw", "cloth", "HES", TV.STONE + ["tv_straw"], "tv_straw"),
           Zone(1, "head band", "trim", "HES", TV.STONE + ["tv_straw"], "tv_straw"),
           Zone(2, "unused", "trim", "FLAT", ["tv_leather"], "tv_leather"),
           Zone(3, "chin strap", "ribbon", "LEA", TV.STONE, "tv_leather")],
    hides_hair_zones=["crown"], sources=[], evidence="C",
    tags=["men", "women", "tv_stone", "tv_common", "stone_children", "everyday"], budget=2600,
    extra=TV.extra({0: "straw", 1: "straw", 2: "leather", 3: "leather"},
                   note="cloth2.dress.lathe_hat CONE: R 0.25, H 0.15, rigid on headb, chin strap 7 mm.",
                   brim_variant={"A": "R 0.25 H 0.15", "B": "R 0.28 H 0.14", "C": "R 0.21 H 0.17"}))

STYLE = dress._style(dress.CONE, {"R": 0.25, "H": 0.15, "thick": 0.007})


def build(g, st=STYLE):
    recipes.lathe_hat(g, st)


build_and_export = G.runner(SPEC, build)
