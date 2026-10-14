"""The levy hat (cloth2 rigid_hat profile CONE with a finial: cloth2.dress.lathe_hat): a black-lacquered cone with a red
knob and a spread red tuft at its apex, a chin strap. The imperial levy's soldiers (with tv_ds_levy_coat)."""

import numpy as np

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import hats as HT
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_ds_levy_hat", name="Levy hat", set="tv_delta", slot="head", layer={"default": 80},
    description="A black-lacquered cone hat with a red finial and a red tuft spread over its apex, and a chin strap.",
    history="Design note: a soldier's cone, lacquered black so a squad's heads read dark and alike, the red tuft "
            "matching the coat's binding (owner question 6).",
    zones=[Zone(0, "lacquered cone", "cloth", "FLAT", TV.DELTA + ["tv_lacquer_black"], "tv_lacquer_black"),
           Zone(1, "head band", "trim", "HES", TV.DELTA, "tv_straw"),
           Zone(2, "finial and tuft", "fringe", "FLAT", TV.DELTA, "tv_lacquer_red"),
           Zone(3, "chin strap", "ribbon", "LEA", TV.DELTA + ["tv_lacquer_black"], "tv_lacquer_black")],
    hides_hair_zones=["crown"], sources=[], evidence="C", tags=["men", "women", "tv_delta", "npc", "levy_soldier"],
    budget=2600,
    extra=TV.extra({0: "metal", 1: "straw", 2: "cord", 3: "leather"},
                   note="cloth2.dress.lathe_hat CONE R 0.22 H 0.17 with a 3 cm finial (zone 2) and a red tuft: a "
                        "lathe 0.06 m across spread over the apex, rigid on headb."))

STYLE = dress._style(dress.CONE, {"R": 0.22, "H": 0.17, "thick": 0.006, "finial": {"r": 0.011, "h": 0.03}})


def build(g, st=STYLE):
    recipes.lathe_hat(g, st)
    C, Rm = HT.hat_frame(g.fits, st)
    H = st["H"]
    # the tuft: a low cone of red horsehair spread over the apex, its fringe edge ragged by height
    prof = [(0.0, H + 0.022), (0.012, H + 0.016), (0.03, H - 0.004), (0.052, H - 0.03), (0.06, H - 0.042),
            (0.055, H - 0.044)]
    V, F = HW.lathe(prof[::-1], segs=18)
    ang = np.arctan2(V[:, 1], V[:, 0])
    rr = np.hypot(V[:, 0], V[:, 1])
    V = V.copy()
    V[:, 2] -= (rr > 0.045) * 0.006 * (1 + np.sin(ang * 9.0))
    g.add(HT.rigid_mesh(g.fits, g.m.A, C + V @ Rm.T, F, 2, 6))


build_and_export = G.runner(SPEC, build)
