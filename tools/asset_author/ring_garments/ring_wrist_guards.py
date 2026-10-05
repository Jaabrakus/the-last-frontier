"""The fire side's wrist guards (ring_garments._arms): stiff leather guards on the lower forearm to the wrist, gold
rims at both ends and two raised ribs along the back of the arm."""

import numpy as np

from cloth2 import garment as G
from cloth2.spec import Spec, Zone

from ring_garments import _arms as A
from ring_garments import _common as C

PAL = ["ring_char", "ring_ember", "ring_flame", "leather_black"]

SPEC = Spec(
    id="ring_wrist_guards", name="Fire side wrist guards", set=C.SET, slot="accessories.arms", layer={"default": 32},
    description="Stiff leather guards on the lower forearms with gold rims and two ribs along the back of the arm.",
    history=C.HISTORY,
    zones=[Zone(0, "leather", "leather", "LEA", PAL, "ring_char"),
           Zone(1, "rims and ribs", "trim", "FLAT", ["ring_gold", "brass", "ring_flame"], "ring_gold")],
    evidence="C", tags=C.tags("fire"), budget=2600,
    extra={"presets": {"fire": {"0": "ring_char", "1": "ring_gold"}},
           "recipe_note": "the forearm regions off the skin (6.5 mm) from arm 0.70 to 0.985; gold rims and ribs."})


def build(g):
    A.forearm(g, 0.70, 0.0065, t1=0.985)
    A.rims(g, 1, 0.010, 0.0022)
    # two ribs along the back of the forearm (round the arm at +-0.35 rad from its top)
    rib = A.arm_axis_field(g, lambda u, phi: np.minimum(np.abs(phi - 0.35), np.abs(phi + 0.35)) - 0.07)
    g.raised(rib, 0.0018, 1)
    g.hem_below(0.0)
    g.uv(limbs=("arm_l", "arm_r"))


build_and_export = G.runner(SPEC, build)
