"""Our own sprint vault (move vault_sprint, 0 - 1.3 s over a 0.95 m obstacle): left foot plants, both hands on the top, the legs
sweep over to the character's right, the right foot lands. The contacts keep the native's limbs (left foot support, hands top,
right foot landing), which is what the traversal table's warper maps onto the obstacle. See rigkit.py for the spec."""
import math, rigkit
from mathutils import Vector
NATIVE = "vault_sprint"
SPEC = {
    "t_a": 0.0, "dur": 1.3, "blend": 0.25,
    "obstacles": [("obstacle", (-1.0, 0.0, 0.82), (1.0, 0.95, 1.25), (0.72, 0.68, 0.6))],
    "keys": {
        "pelvis": [(0.00, (0.00, 0.79, -0.14)), (0.20, (0.03, 0.90, 0.28)), (0.30, (0.04, 1.00, 0.44)), (0.42, (0.02, 1.13, 0.64)),
                   (0.60, (-0.04, 1.27, 0.90)), (0.80, (-0.10, 1.12, 1.18)), (1.00, (-0.03, 1.05, 1.55)), (1.30, (0.03, 1.03, 2.17))],
        "pelvis_rot": [(0.0, "native"), (0.4, (32, 0, -8)), (0.6, (50, -8, -22)), (0.85, (28, 0, -5)), (1.1, (8, 0, 0)), (1.3, "native")],
        "chest_rot": [(0.0, "native"), (0.3, (52, 0, 0)), (0.55, (80, 0, -18)), (0.85, (42, 0, 0)), (1.1, (14, 0, 0)), (1.3, "native")],
        "head_rot": [(0.0, "native"), (0.3, (-35, 0, 0)), (0.55, (-62, 0, 0)), (0.9, (-28, 0, 0)), (1.3, "native")],
        "l_hand": [(0.00, "native"), (0.22, (0.30, 0.96, 0.92)), (0.56, (0.30, 0.96, 0.92)), (0.72, (0.40, 1.05, 1.20)), (0.90, (0.42, 1.00, 1.50)), (1.05, "native@1.05"), (1.30, "native")],
        "r_hand": [(0.00, "native"), (0.25, (0.05, 0.97, 0.96)), (0.52, (0.05, 0.97, 0.96)), (0.68, (-0.10, 1.02, 1.12)),
                   (0.90, (-0.25, 1.02, 1.45)), (1.05, (-0.30, 0.92, 1.85)), (1.30, "native")],
        "l_ankle": [(0.00, None), (0.20, (-0.02, 0.14, 0.42)), (0.30, (-0.02, 0.26, 0.47)), (0.46, (-0.12, 0.85, 0.66)),
                    (0.60, (-0.26, 1.16, 0.88)), (0.75, (-0.22, 1.08, 1.26)), (0.80, (-0.15, 0.80, 1.42)), (1.05, (-0.02, 0.25, 1.78)), (1.30, None)],
        "r_ankle": [(0.00, None), (0.25, (-0.26, 0.78, 0.45)), (0.50, (-0.32, 1.16, 0.92)), (0.64, (-0.34, 1.12, 1.30)),
                    (0.78, (-0.25, 0.80, 1.52)), (1.00, "native"), (1.30, None)],
        "l_knee_pole": [(0.0, (0.3, 0.2, 0.8)), (0.4, (0.1, 0.7, 0.8)), (0.65, (0.0, 0.7, 0.8)), (1.0, (0.3, 0.3, 0.8))],
        "r_knee_pole": [(0.0, (-0.3, 0.2, 0.8)), (0.5, (-0.1, 0.7, 0.8)), (1.0, (-0.3, 0.3, 0.8))],
        "l_elbow_pole": [(0.0, (0.7, -0.4, -0.5)), (0.5, (0.9, 0.0, -0.3)), (1.3, (0.7, -0.4, -0.5))],
        "r_elbow_pole": [(0.0, (-0.7, -0.4, -0.5)), (0.5, (-0.9, 0.0, -0.3)), (1.3, (-0.7, -0.4, -0.5))],
    },
}


SPEC["ties"] = [("l_hand", 1, 2), ("r_hand", 1, 2)]
rigkit.load_keys(SPEC, __file__)


def shape(spec, frames):
    """What a tucked swing-over looks like: the torso folded over the hands at the apex, the legs compact and together, the head low."""
    c = 0.0
    over = [f for f in frames if 0.42 <= f["t"] <= 0.75]
    apex = max((f for f in frames if 0.45 <= f["t"] <= 0.7), key=lambda f: f["P"]["pelvis"].y)
    P = apex["P"]
    pitch = math.degrees((P["spined"] - P["pelvis"]).angle(Vector((0, 1, 0))))
    c += max(0.0, 68.0 - pitch) ** 2 * 0.05
    c += max(0.0, P["headb"].y - 1.55) ** 2 * 60.0
    for f in over:
        P = f["P"]
        for s in ("l", "r"):
            c += max(0.0, (P[s + "_ankle"] - P["pelvis"]).length - 0.62) ** 2 * 40.0
        c += max(0.0, (P["l_ankle"] - P["r_ankle"]).length - 0.35) ** 2 * 30.0
    return c


def params(spec):
    return rigkit.param_list(spec, [
        ("pelvis", [0.20, 0.30, 0.42, 0.60, 0.80, 1.00], [1, 2], 0.04, 0.3),
        ("pelvis", [0.60, 0.80], [0], 0.04, 0.3),
        ("pelvis_rot", [0.4, 0.6, 0.85], [0, 1, 2], 6.0, 35.0),
        ("chest_rot", [0.3, 0.55, 0.85], [0, 1, 2], 6.0, 35.0),
        ("head_rot", [0.3, 0.55, 0.9], [0], 6.0, 35.0),
        ("l_ankle", [0.46, 0.60, 0.75], [0, 1, 2], 0.04, 0.3),
        ("r_ankle", [0.25, 0.50, 0.64, 0.78], [0, 1, 2], 0.04, 0.3),
        # (both hands get every time either hand has a key: the mirrored move's hands swap roles)
        ("l_hand", [0.22, 0.25], [0, 2], 0.03, 0.12),
        ("r_hand", [0.22, 0.25], [0, 2], 0.03, 0.12),
        ("l_hand", [0.68, 0.72, 0.90, 1.05], [0, 1, 2], 0.04, 0.25),
        ("r_hand", [0.68, 0.72, 0.90, 1.05], [0, 1, 2], 0.04, 0.25),
        ("l_knee_pole", [0.4, 0.65], [0, 1, 2], 0.2, 0.6),
        ("r_knee_pole", [0.5], [0, 1, 2], 0.2, 0.6),
        ("l_elbow_pole", [0.0, 0.5], [0, 1, 2], 0.2, 0.6),
        ("r_elbow_pole", [0.0, 0.5], [0, 1, 2], 0.2, 0.6),
    ])
