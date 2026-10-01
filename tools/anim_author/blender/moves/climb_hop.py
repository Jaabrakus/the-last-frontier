"""The jump up to the ledge (climb_hang_3m and climb_hang_3m_idle, parts idle-jump-up-3m^ledge-hang-begin / mid / end, 0 - 0.7 s) with the
legs kept together under the hips (user 2026-09-30: "the hop on the ledge does a Y shape when it should be a simple up down"). Everything
else is the source's: the timing, the arms reaching up, the body's path, the catch on the lip; only the legs are re-solved."""
import rigkit
NATIVE = "climb_hang_3m"
SPEC = {
    "t_a": 0.0, "dur": 0.7, "blend": 0.12, "native_body": True, "ankle_rel": True,
    "obstacles": [("wall", (-1.6, 0.0, 0.30), (1.6, 1.52, 1.7), (0.72, 0.68, 0.6)),
                  ("lip", (-0.5, 1.72, 0.22), (0.5, 1.80, 0.34), (0.55, 0.35, 0.2))],
    "keys": {
        # (x, y, z) from the pelvis: the feet together under the hips, the knees a little bent
        "l_ankle": [(0.00, None), (0.16, "native"), (0.30, (0.09, -0.76, -0.04)), (0.60, (0.09, -0.77, -0.05)), (0.70, None)],
        "r_ankle": [(0.00, None), (0.16, "native"), (0.30, (-0.09, -0.76, -0.04)), (0.60, (-0.09, -0.77, -0.05)), (0.70, None)],
        "l_knee_pole": [(0.0, (0.1, 0.0, 1.0)), (0.7, (0.1, 0.0, 1.0))],
        "r_knee_pole": [(0.0, (-0.1, 0.0, 1.0)), (0.7, (-0.1, 0.0, 1.0))],
    },
}
