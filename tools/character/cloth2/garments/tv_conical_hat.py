"""The conical hat (cloth2 rigid_hat profile CONE: cloth2.dress.lathe_hat): a straw cone of split leaf on an inner head
band, a lacquer-red chin ribbon. Shared by every set (tv_common): the dock workers of Vạn Thủy, the porters of Trường
Sơn, the field hands of the delta."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_conical_hat", name="Conical hat", set="tv_common", slot="head", layer={"default": 80},
    description="A conical straw hat on an inner head band with a red chin ribbon.",
    history="Design note: on every place sheet (the Vạn Thủy piers, the Trường Sơn bridge, the Thạch Uyên quarry) the "
            "cone is the commoner's silhouette; a little larger than real (R 0.235 m) so it reads at distance.",
    zones=[Zone(0, "straw", "cloth", "HES", TV.DELTA, "tv_straw"),
           Zone(1, "head band", "trim", "HES", TV.DELTA, "tv_straw"),
           Zone(2, "unused", "trim", "FLAT", ["tv_lacquer_red"], "tv_lacquer_red"),
           Zone(3, "chin ribbon", "ribbon", "FLAT", TV.DELTA + ["tv_madder"], "tv_lacquer_red")],
    hides_hair_zones=["crown"], sources=[], evidence="C",
    tags=["men", "women", "tv_common", "dragon_sea", "mountain_folk", "stone_children", "everyday"], budget=2600,
    extra=TV.extra({0: "straw", 1: "straw", 2: "cord", 3: "cord"},
                   presets={"straw": {"0": "tv_straw", "3": "tv_lacquer_red"}, "reed": {"0": "tv_reed_straw", "3": "tv_pearl"}},
                   note="cloth2.dress.lathe_hat CONE R 0.235 H 0.165, 6 mm, rigid on headb, chin ribbon 7 mm.",
                   brim_variant={"A": "R 0.235 H 0.165", "B": "R 0.27 H 0.14", "C": "R 0.31 H 0.12"}))

STYLE = dress._style(dress.CONE, {"R": 0.235, "H": 0.165, "thick": 0.006})


def build(g, st=STYLE):
    recipes.lathe_hat(g, st)


build_and_export = G.runner(SPEC, build)
