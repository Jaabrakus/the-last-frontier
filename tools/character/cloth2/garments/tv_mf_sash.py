"""The Mountain Folk wound sash (cloth2 recipe type sash, wound: cloth2.dress.wound_sash, with tv_dress.dangles): a
madder sash wound twice round the waist over the hip panels, its end hanging at the left front with a fringe, a cast
bronze disc with our own mark on the right hip, and strings of teeth, bone beads and tassels hanging from it. The red
waist of the Mountain Folk silhouette."""

import numpy as np

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_mf_trousers", "tv_mf_wrap_vest", "tv_mf_short_robe", "tv_mf_hip_panels"]

SPEC = Spec(
    id="tv_mf_sash", name="Wound sash with bronze disc", set="tv_highland", slot="accessories.waist",
    layer={"default": 60},
    description="A madder sash wound twice round the waist, its fringed end hanging at the left front, a bronze disc "
                "on the right hip and strings of teeth, bone beads and tassels.",
    history="Design note: the narrow red waist of every Mountain Folk figure on the sheets, hung with the hunter's "
            "teeth and tassels. The disc carries our own mark (one ring and three straight cuts), never a copy of a "
            "sheet emblem.",
    zones=[Zone(0, "sash", "cloth", "WOOL", TV.HIGHLAND, "tv_madder"),
           Zone(1, "bone and teeth", "trim", "FLAT", TV.METALS + ["tv_bone"], "tv_bone"),
           Zone(2, "bronze", "metal", "MET", TV.METALS, "tv_bronze"),
           Zone(3, "fringe and tassels", "fringe", "HES", TV.HIGHLAND, "tv_madder")],
    sources=[], evidence="C", tags=["men", "women", "tv_highland", "mountain_folk", "everyday"], budget=3000,
    over=UNDER,
    extra=TV.extra({0: "weave", 1: "bone", 2: "metal", 3: "cord"},
                   presets={"madder": {"0": "tv_madder", "3": "tv_madder"},
                            "ochre": {"0": "tv_ochre", "3": "tv_madder"},
                            "jade": {"0": "tv_jade_cloth", "3": "tv_bone"}},
                   note="cloth2.dress.wound_sash: 2 turns 6.5 cm tall on a helix from 0.95 to 1.05, the tuck at 30 deg "
                        "(left front), a 0.25 m end with a 5 cm fringe (zone 3); a 9 cm cast disc (tv_dress.mark_disc) "
                        "at -62 deg; tv_dress.dangles: two strings of teeth and bone beads, a tassel, below the "
                        "waist on the skirt panels' weights."))

STYLE = {"turns": 2, "z": (0.95, 1.05), "height": 0.066, "lift": 0.030, "step": 0.0040, "start": 30.0,
         "end": {"len": 0.25, "w": 0.075}, "over": tuple(UNDER), "over_gap": 0.005}
FRINGE = 0.05
DISC = {"theta": -62.0, "r": 0.045}
STRINGS = [(18.0, [("bead", {"r": 0.007}, 1), ("tooth", {"length": 0.05}, 1), ("bead", {"r": 0.006}, 1),
                   ("tooth", {"length": 0.045}, 1)]),
           (-22.0, [("disc_bead", {"r": 0.009}, 2), ("tassel", {"length": 0.085, "r": 0.014}, 3)]),
           (-40.0, [("bead", {"r": 0.007}, 1), ("tooth", {"length": 0.055}, 1)])]


def build(g, st=STYLE):
    recipes.sash(g, st)
    m = g.m
    # the hanging end's last 5 cm a fringe
    c = m.face_centres()
    end = m.fa["part"] == 8
    if end.any():
        zmin = c[end, 2].min()
        m.fa["zone"][end & (c[:, 2] < zmin + FRINGE)] = 3
    zc = 0.5 * (st["z"][0] + st["z"][1])
    P = g.around_points(zc, np.array([DISC["theta"]]))
    if len(P):
        g.hardware(P[:1], TVD.mark_disc(DISC["r"], 0.006), 2, up=(0.0, 0.0, 1.0), lift=0.002)
    strings = []
    for th, pieces in STRINGS:
        Q = g.around_points(st["z"][0] + 0.005, np.array([th]))
        if len(Q):
            strings.append({"at": Q[0], "pieces": pieces, "gap": 0.003, "sway": th * 0.2})
    if strings:
        TVD.dangles(g, strings, obstacles=G.built(g.fits, "tv_mf_hip_panels")[:1], lift=0.008)
    g.uv(axis_top=1.1, axis_bottom=0.6, limbs=())
    dress.arc_uv(g)


build_and_export = G.runner(SPEC, build)
