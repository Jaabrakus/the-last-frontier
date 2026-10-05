"""The earth side's arm wraps (ring_garments._arms): cloth strips bound round the forearm from below the elbow to the
wrist, the turns drawn as a stripe on the bias, a raised band at each end."""

from cloth2 import garment as G
from cloth2.spec import Spec, Zone

from ring_garments import _arms as A
from ring_garments import _common as C

PAL = ["ring_khaki", "ring_umber", "ring_moss", "ring_ochre", "ring_olive"]
WRAP = {"options": ["none", "stripe"], "default": "stripe",
        "stripe": {"colors": ["ring_khaki", "ring_umber"], "scale_m": 0.032, "angle": 30.0, "duty": 0.8},
        "note": "the wound strips: a dark line between the turns, on the bias"}

SPEC = Spec(
    id="ring_arm_wraps", name="Earth side arm wraps", set=C.SET, slot="accessories.arms", layer={"default": 32},
    description="Cloth strips bound round the forearms from below the elbow to the wrist.",
    history=C.HISTORY,
    zones=[Zone(0, "wraps", "cloth", "LIN", PAL, "ring_khaki", pattern=WRAP),
           Zone(1, "end bands", "trim", "LIN", PAL, "ring_umber")],
    evidence="C", tags=C.tags("earth"), budget=2600,
    extra={"presets": {"earth": {"0": "ring_khaki", "1": "ring_umber"}},
           "recipe_note": "the forearm regions off the skin (4 mm) from arm 0.56 to the wrist; rims 1.2 cm."})


def build(g):
    A.forearm(g, 0.56, 0.0040)
    A.rims(g, 1, 0.012, 0.0018)
    g.hem_below(0.0)
    g.uv(limbs=("arm_l", "arm_r"))


build_and_export = G.runner(SPEC, build)
