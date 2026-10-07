"""The Mountain Folk leg wraps with cross-cords (cloth2 recipe type leg_wraps: cloth2.tv_dress.LEG_WRAPS): a 7 cm strip
of undyed hemp wound eight times down each shin from the knee to the ankle over the trousers' ends, each turn lying
over the one below, a madder cord crossing over the wraps four times and tied under the knee with hanging ends. Shared
(tv_common's cut, in highland dyes): porters, hunters, soldiers of the clans."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_mf_trousers"]

SPEC = Spec(
    id="tv_mf_leg_wraps", name="Leg wraps with cross-cords", set="tv_highland", slot="legs.over",
    layer={"default": 35},
    description="Undyed hemp strips wound down each shin from the knee to the ankle over the trousers, a madder cord "
                "crossing over them, tied under the knee.",
    history="Design note: the bound white shins of every Mountain Folk figure (the hunter, the porter, the Trường Sơn "
            "bridge). Chunky on purpose: each turn stands proud of the one below, so the wrap reads at walking "
            "distance as rings of light and shade.",
    zones=[Zone(0, "hemp strip", "cloth", "HES", TV.HIGHLAND, "tv_hemp"),
           Zone(1, "cord", "ribbon", "HES", TV.HIGHLAND, "tv_madder")],
    sources=[], evidence="C", tags=["men", "women", "tv_highland", "tv_common", "mountain_folk", "everyday"],
    budget=3500, over=UNDER,
    extra=TV.extra({0: "hemp", 1: "cord"},
                   presets={"hemp_madder": {"0": "tv_hemp", "1": "tv_madder"},
                            "hemp_indigo": {"0": "tv_hemp", "1": "tv_indigo_black"},
                            "indigo_hemp": {"0": "tv_indigo_black", "1": "tv_hemp"}},
                   note="cloth2.tv_dress.leg_wraps: a 6.8 cm strip on a helix from 0.46 to 0.105 (30% overlap, ~7.6 "
                        "turns), each turn's lower edge 3.5 mm prouder, fitted over tv_mf_trousers; two 4.5 mm cords "
                        "on opposite helices crossing 4 times; a knot under the knee with two 8.5 cm ends."))

STYLE = dict(TVD.LEG_WRAPS, over=tuple(UNDER))


def build(g, st=STYLE):
    recipes.leg_wraps(g, st)


build_and_export = G.runner(SPEC, build)
