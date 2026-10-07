"""The Dragon-Sea knotted sash with shell strings (cloth2: cloth2.dress.wound_sash with a flat knot, tv_dress.dangles):
a pearl-white sash wound one and a half times round the waist, knotted in front, its two ends hanging, and three
strings of scallop shells, pearls and a lacquer-red tassel. The dock woman's waist (lineup)."""

import numpy as np

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_ds_long_skirt", "tv_ds_short_robe"]

SPEC = Spec(
    id="tv_ds_sash_strings", name="Knotted sash with shell strings", set="tv_delta", slot="accessories.waist",
    layer={"default": 60},
    description="A pearl-white sash knotted in front with two hanging ends, hung with strings of shells, pearls and a "
                "red tassel.",
    history="Design note: the lineup's dock woman knots a white sash over her teal robe and hangs shells from it; the "
            "one warm note is the lacquer-red tassel.",
    zones=[Zone(0, "sash", "cloth", "LIN", TV.DELTA, "tv_pearl"),
           Zone(1, "shells", "trim", "FLAT", TV.DELTA, "tv_pearl"),
           Zone(2, "pearls", "metal", "FLAT", TV.DELTA + TV.METALS, "tv_pearl"),
           Zone(3, "tassel", "fringe", "HES", TV.DELTA + ["tv_madder"], "tv_lacquer_red")],
    sources=[], evidence="C", tags=["women", "men", "tv_delta", "dragon_sea", "everyday"], budget=4000, over=UNDER,
    extra=TV.extra({0: "weave", 1: "bone", 2: "bone", 3: "cord"},
                   presets={"pearl": {"0": "tv_pearl", "3": "tv_lacquer_red"},
                            "salt": {"0": "tv_salt_white", "3": "tv_estuary_teal"}},
                   note="cloth2.dress.wound_sash (2 turns 6 cm, 0.96-1.05) with a flat knot at 4 deg and two ends "
                        "0.30 / 0.24 m; tv_dress.dangles: shells, pearls, a red tassel."))

STYLE = {"turns": 2, "z": (0.96, 1.05), "height": 0.058, "lift": 0.030, "step": 0.0035, "start": 4.0,
         "end": {"len": 0.30, "w": 0.07}, "over": tuple(UNDER), "over_gap": 0.006}
STRINGS = [(-14.0, [("bead", {"r": 0.007}, 2), ("shell", {"r": 0.018}, 1), ("bead", {"r": 0.006}, 2),
                    ("shell", {"r": 0.015}, 1)]),
           (22.0, [("bead", {"r": 0.007}, 2), ("bead", {"r": 0.007}, 2), ("tassel", {"length": 0.09, "r": 0.014}, 3)]),
           (-36.0, [("shell", {"r": 0.016}, 1), ("bead", {"r": 0.006}, 2), ("shell", {"r": 0.014}, 1)])]


def build(g, st=STYLE):
    recipes.sash(g, st)
    zc = 0.5 * (st["z"][0] + st["z"][1]) + 0.02
    P = g.around_points(zc, np.array([st["start"]]))
    if len(P):
        g.hardware(P[:1], HW.ellipsoid(0.042, 0.03, 0.012, segs=10, rings=4), 0, lift=-0.002, up=(0.0, 0.0, 1.0))
    strings = []
    for th, pieces in STRINGS:
        Q = g.around_points(st["z"][0] + 0.005, np.array([th]))
        if len(Q):
            strings.append({"at": Q[0], "pieces": pieces, "gap": 0.003, "sway": th * 0.2})
    if strings:
        TVD.dangles(g, strings, obstacles=G.built(g.fits, "tv_ds_short_robe")[:1], lift=0.008)
    g.uv(axis_top=1.1, axis_bottom=0.6, limbs=())
    dress.arc_uv(g)


build_and_export = G.runner(SPEC, build)
