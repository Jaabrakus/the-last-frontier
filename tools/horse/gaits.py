"""Procedural gait generator for the Frontier horse (numpy only).

Each clip is solved frame by frame into armature-space bone matrices:

  body     bob from the rider clip (saddle curve), pitch from fore/hind loading, roll
  spine    lumbosacral / back flexion (canter, gallop), neck and head nod and carriage,
           tail and ears
  legs     hooves planted on the ground in stance, a swing path between lift-off and
           touchdown, analytic two-bone IK for shoulder->elbow->(carpus)->fetlock and
           hip->stifle->(hock)->fetlock with a prescribed carpus / hock bend (opened
           when a stance leg would over-reach), pastern and hoof angles in the sagittal
           plane

Ground frame. Every clip has a ground frame, the frame in which planted hooves do not
move: a straight line at the clip's ground speed for the cycles (stride length / stride
time), a circle of radius turn_radius for the curved variants (<clip>_tl / _tr; the body
leans into the turn), a rotation about the origin for the turns in place, the jump's
approach speed plus the ballistic root lift for the jump (root_lift), and the root itself
for idle and rear. Stance hooves are fixed in it. Near lift-off and touchdown the swing
runs in it too, so the hoof leaves the ground and arrives on it with zero ground speed and
the ground speed grows only quadratically away from either end (swing retraction before
touchdown); mid-swing the path follows the body. The lift and the carpus / hock flexion
follow smooth profiles. In the jump the airborne legs blend into a body-frame tuck.

Timing. Every horse clip has exactly the length and frame count of the Actor_B rider
clip it carries (rider phase = horse phase, as in the source graph). The footfalls per
gait are the ones derived in horse.md section 1.5 (aligned to the Actor_B clip phase, so
the saddle lows sit at mid-stance) and the saddle bob is the rider-derived curve
`saddle_z_norm` times a per-gait amplitude.

Stride. The gait speeds come from the stride lengths (horse.md 0.1): a clip's no-slip
speed is stride / stride time. Every gait except the sprint has a short-stride variant
(`<gait>_s`) with the same timing and duty, so the runtime can shorten the stride at
low speed (stride blend) instead of slowing the clip down. Every moving gait clip has
curved variants for turning (see TURN_R_MIN).

Space: Blender armature space (z up, the horse faces -y, +x = left).
"""

import json
import math
import os

import numpy as np

import anatomy as A

FPS = 30.0
HERE = os.path.dirname(os.path.abspath(__file__))
LEGS = ("LF", "RF", "LH", "RH")
FWD = np.array([0.0, -1.0, 0.0])
UP = np.array([0.0, 0.0, 1.0])
LAT = np.array([1.0, 0.0, 0.0])
GRAVITY = 9.81


# ---------------------------------------------------------------------------
# Small math
# ---------------------------------------------------------------------------
def rot(axis, ang):
    a = np.asarray(axis, float)
    a = a / np.linalg.norm(a)
    c, s = math.cos(ang), math.sin(ang)
    x, y, z = a
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def T4(R=None, t=None):
    M = np.eye(4)
    if R is not None:
        M[:3, :3] = R
    if t is not None:
        M[:3, 3] = t
    return M


def about(p, R):
    """4x4 rotation R about point p."""
    p = np.asarray(p, float)
    return T4(None, p) @ T4(R) @ T4(None, -p)


def xf(M, p):
    return (M @ np.append(p, 1.0))[:3]


def smoothstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def minjerk(s):
    s = min(max(s, 0.0), 1.0)
    return s * s * s * (10 - 15 * s + 6 * s * s)


def bump(s, peak=0.5, power=1.0):
    """0 at s=0 and 1, 1 at `peak` (skewed sine)."""
    s = min(max(s, 0.0), 1.0)
    if s <= 0 or s >= 1:
        return 0.0
    k = math.log(0.5) / math.log(peak)
    return math.sin(math.pi * s ** k) ** power


def profile(s, peak=0.4, a=1.5):
    """s^a (1-s)^b scaled to 1 at `peak`: zero value and slope at both ends (a, b > 1),
    so a lift or flexion starts from rest at lift-off and settles at touchdown."""
    s = min(max(s, 0.0), 1.0)
    if s <= 0.0 or s >= 1.0:
        return 0.0
    b = a * (1.0 - peak) / peak
    return (s / peak) ** a * ((1.0 - s) / (1.0 - peak)) ** b


def _yaw_of(R):
    """Yaw (rad, about +z) of a rotation that is a yaw only."""
    return math.atan2(R[1, 0], R[0, 0])


def sag_angle(v):
    """Angle of a vector in the sagittal plane: 0 = forward (-y), +90 deg = up."""
    return math.atan2(v[2], -v[1])


def sag_dir(a):
    return np.array([0.0, -math.cos(a), math.sin(a)])


def _interior(a, b, c):
    """Interior angle (rad) at b between b->a and b->c."""
    u = np.asarray(a, float) - b
    v = np.asarray(c, float) - b
    return math.acos(max(-1.0, min(1.0, float(u @ v) / (np.linalg.norm(u) * np.linalg.norm(v)))))


def mat_quat(R):
    """3x3 rotation -> quaternion (w, x, y, z)."""
    t = R[0, 0] + R[1, 1] + R[2, 2]
    if t > 0:
        s = 0.5 / math.sqrt(t + 1.0)
        q = np.array([0.25 / s, (R[2, 1] - R[1, 2]) * s, (R[0, 2] - R[2, 0]) * s, (R[1, 0] - R[0, 1]) * s])
    else:
        i = int(np.argmax([R[0, 0], R[1, 1], R[2, 2]]))
        j, k = (i + 1) % 3, (i + 2) % 3
        s = 2.0 * math.sqrt(max(1.0 + R[i, i] - R[j, j] - R[k, k], 1e-12))
        q = np.zeros(4)
        q[0] = (R[k, j] - R[j, k]) / s
        q[1 + i] = 0.25 * s
        q[1 + j] = (R[j, i] + R[i, j]) / s
        q[1 + k] = (R[k, i] + R[i, k]) / s
    return q / np.linalg.norm(q)


def quat_mat(q):
    w, x, y, z = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def rot_fraction(R, f):
    """The rotation R scaled to the fraction f of its angle (same axis)."""
    q = mat_quat(R)
    if q[0] < 0:
        q = -q
    ang = 2.0 * math.acos(min(1.0, q[0]))
    if ang < 1e-9:
        return np.eye(3)
    axis = q[1:] / math.sin(ang / 2)
    return rot(axis, ang * f)


def soft_limit(x, knee=0.6):
    """Identity for |x| <= knee, saturating smoothly (C1) to +-1."""
    ax = abs(x)
    if ax <= knee:
        return x
    return math.copysign(knee + (1.0 - knee) * math.tanh((ax - knee) / (1.0 - knee)), x)


def interp_curve(vals, phase):
    """Cyclic linear interpolation of an evenly sampled loop at phase 0..1."""
    n = len(vals)
    x = (phase % 1.0) * n
    i = int(math.floor(x)) % n
    f = x - math.floor(x)
    return vals[i] * (1 - f) + vals[(i + 1) % n] * f


def envelope(keys, t):
    """Piecewise smooth (smoothstep) interpolation of [(t, v), ...]."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys[:-1], keys[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * smoothstep(t0, t1, t)
    return keys[-1][1]


# ---------------------------------------------------------------------------
# Rig
# ---------------------------------------------------------------------------
class Rig:
    def __init__(self, rest):
        """rest: name -> 4x4 armature-space rest matrix (Blender bone.matrix_local)."""
        self.table = A.bone_table()
        self.rest = {n: np.asarray(m, float) for n, m in rest.items()}
        self.parent = {n: v[2] for n, v in self.table.items()}
        self.order = []
        seen = set()

        def visit(n):
            if n in seen:
                return
            p = self.parent[n]
            if p:
                visit(p)
            seen.add(n)
            self.order.append(n)
        for n in self.table:
            visit(n)
        self.rel = {}
        for n in self.order:
            p = self.parent[n]
            self.rel[n] = np.linalg.inv(self.rest[p]) @ self.rest[n] if p else self.rest[n].copy()
        self.head = {n: np.array(self.table[n][0]) for n in self.table}
        self.tail = {n: np.array(self.table[n][1]) for n in self.table}
        self.len = {n: float(np.linalg.norm(self.tail[n] - self.head[n])) for n in self.table}

    def aim(self, name, head, tail, ref_rot):
        """Bone matrix with y along head->tail and x as close as possible to the rest x
        axis rotated by ref_rot (3x3)."""
        y = np.asarray(tail, float) - np.asarray(head, float)
        y /= np.linalg.norm(y)
        xr = ref_rot @ self.rest[name][:3, 0]
        x = xr - (xr @ y) * y
        x /= np.linalg.norm(x)
        z = np.cross(x, y)
        M = np.eye(4)
        M[:3, 0], M[:3, 1], M[:3, 2], M[:3, 3] = x, y, z, head
        return M

    def to_local(self, pose):
        """Armature-space matrices -> pose-bone basis matrices (Blender matrix_basis)."""
        out = {}
        for n in self.order:
            p = self.parent[n]
            if p:
                out[n] = np.linalg.inv(self.rel[n]) @ np.linalg.inv(pose[p]) @ pose[n]
            else:
                out[n] = np.linalg.inv(self.rest[n]) @ pose[n]
        return out


def seg2_len(L2a, L2b, gamma):
    return math.sqrt(L2a * L2a + L2b * L2b + 2 * L2a * L2b * math.cos(gamma))


def solve_two_bone(S, F, L1, L2a, L2b, gamma, pole):
    """Planar two-bone IK with a bent second segment.
    S root, F target, L1 upper length, second segment = L2a then L2b bent by `gamma`
    (radians, positive towards the pole side). Returns (E, C, stretch)."""
    a = F - S
    d = float(np.linalg.norm(a))
    a /= d
    q = pole - (pole @ a) * a
    q /= np.linalg.norm(q)
    L2 = seg2_len(L2a, L2b, gamma)
    beta = math.atan2(L2b * math.sin(gamma), L2a + L2b * math.cos(gamma))
    stretch = d / (L1 + L2)
    d = min(max(d, abs(L1 - L2) + 1e-4), (L1 + L2) * 0.9995)
    Fc = S + a * d
    ca = (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d)
    al = math.acos(min(max(ca, -1.0), 1.0))
    E = S + L1 * (math.cos(al) * a + math.sin(al) * q)
    w = Fc - E
    psi = math.atan2(w @ q, w @ a)
    phr = psi - beta
    dr = math.cos(phr) * a + math.sin(phr) * q
    C = E + L2a * dr
    return E, C, stretch


def planar_bend(S, E, C, F, pole):
    """Signed bend angle at C between E->C and C->F, positive towards the pole side,
    measured in the plane of (F - S, pole)."""
    a = F - S
    a /= np.linalg.norm(a)
    q = pole - (pole @ a) * a
    q /= np.linalg.norm(q)
    u = C - E
    v = F - C
    au = math.atan2(u @ q, u @ a)
    av = math.atan2(v @ q, v @ a)
    g = av - au
    return (g + math.pi) % (2 * math.pi) - math.pi


# ---------------------------------------------------------------------------
# Gait table
# ---------------------------------------------------------------------------
# Per-leg touchdown phase (fraction of one stride), aligned to the Actor_B clip phase.
# walk / trot / canter / gallop / sprint from horse.md section 1.5 (right lead).
#
#   stride      ground distance per stride (m); speed = stride / stride time
#   duty        stance fraction (fore, hind)
#   lift        swing lift of the hoof above the ground (fore, hind), m, peaking at lift_peak;
#               lift_pow < 1 makes the lift rise and fall more steeply at the swing ends
#   carpus/hock swing flexion (deg) peaking at flex_peak (fore, hind)
#   fetlock     swing fetlock flexion (fore, hind)
#   load        stance fetlock sink (deg), breakover heel rise (deg)
#   amp_z       saddle bob (m) times the rider curve; pitch / roll (deg); roll_diag (trot)
#   dz0         constant body (saddle) height offset of the gait, m: the back sits a little
#               lower in the long-striding walk and trot than at a stand, which gives the
#               legs the reach for the stride
#   nod         (amplitude deg, nods per stride, phase of the lowest point)
#   carriage    neck pitch offset, deg, POSITIVE = nose down / neck lowered and stretched
#   stance_shift  mid-stance hoof ahead of its rest position (fore, hind), m
#   scap        shoulder blade turn (rad) per metre the fetlock is ahead of its rest place in the
#               chest frame (as a blade turning about its upper border; revision 5 turns it about a
#               point in its upper part, anatomy.SCAP_PIVOT, with the same travel of the shoulder joint)
#   ramp        (lift-off, touchdown) time constants (s) of the swing ends: the hoof leaves
#               the ground and lands with zero ground speed, and the ground speed rises
#               only quadratically within about `ramp` of either end (swing retraction)
#   open        how far (deg) the carpus / hock may open when a stance leg over-reaches
#   back        lumbosacral / back flexion amplitude (deg) and phase of the peak flexion
#
# Size and speed. The horse is a stocky 14.1-hand colonial horse (anatomy.py). Its gait
# speeds at playback rate 1 are stride / stride time at the rider clips' cycle times:
# walk 1.65 m / 1.2 s = 1.38 m/s, trot 2.8 m / 0.933 s = 3.0, canter 2.8 m / 0.467 s = 6.0,
# gallop 6.0 m / 0.6 s = 10.0 and sprint 6.1 m / 0.467 s = 13.1 m/s (horse.md 0.3: with a
# real hind leg and a hip swing of about 40 deg the stance reaches about 1.0-1.05 m, so the
# walk and trot strides are shorter than in revision 2).
#
#   hip_rom     largest swing of the femur against the pelvis (deg); the hock, fetlock and
#               pelvis take the rest of the reach (Solver.solve_hind)
#   pelvis      pelvis motion with the hind legs: (tuck, roll, yaw) amplitude (deg)
#   bo_from     stance fraction (fore, hind) where the heel starts to rise (breakover)
#   ramp_h      swing-end time constants of the hind legs, if they differ from `ramp`
GAITS = {
    "idle": dict(rider="actor_b-horse-idle", strides=1, kind="idle", amp_z=0.004),
    "walk": dict(rider="actor_b-horse-walk-fw", strides=2, kind="cycle", stride=1.65, hip_rom=34.0, pelvis=(2.8, 5.0, 3.0),
                 td=dict(LH=0.815, LF=0.065, RH=0.315, RF=0.565), duty=(0.60, 0.60),
                 lift=(0.13, 0.14), lift_peak=(0.42, 0.34), lift_pow=1.0, carpus=65, hock=48, flex_peak=(0.40, 0.33),
                 fetlock=(45, 55), load=(9, 13), breakover=(18, 50), bo_from=(0.70, 0.50),
                 amp_z=0.03, dz0=-0.02, pitch=1.2, roll=1.0, nod=(4.0, 2, 0.065), carriage=8.0, tail=(4, 3.0),
                 stance_shift=(-0.02, -0.05), scap=0.40, ramp=(0.08, 0.10), open=(4, 30)),
    "trot": dict(rider="actor_b-horse-trot-fw", strides=1, kind="cycle", stride=2.80, hip_rom=29.0, pelvis=(2.5, 2.5, 1.5),
                 td=dict(LH=0.50, LF=0.00, RH=0.00, RF=0.50), duty=(0.36, 0.36),
                 lift=(0.15, 0.13), lift_peak=(0.42, 0.40), lift_pow=0.85, carpus=68, hock=52, flex_peak=(0.40, 0.38),
                 fetlock=(60, 65), load=(15, 20), breakover=(22, 50), bo_from=(0.70, 0.50),
                 amp_z=0.06, dz0=-0.035, pitch=1.0, roll=0.6, roll_diag=1.5, nod=(1.0, 2, 0.0), carriage=5.0,
                 tail=(10, 1.0), stance_shift=(-0.09, -0.07), scap=0.45, ramp=(0.04, 0.08), open=(4, 30)),
    "canter": dict(rider="actor_b-horse-canter-fw", strides=2, kind="cycle", stride=2.80, hip_rom=48.0,
                   pelvis=(0.0, 1.5, 1.5),
                   td=dict(LH=0.02, LF=0.22, RH=0.22, RF=0.42), duty=(0.40, 0.37),
                   lift=(0.19, 0.15), lift_peak=(0.40, 0.40), lift_pow=0.7, carpus=100, hock=58, flex_peak=(0.38, 0.40),
                   fetlock=(80, 72), load=(17, 21), breakover=(24, 45),
                   amp_z=0.08, dz0=-0.03, pitch=5.0, roll=1.5, nod=(5.0, 1, 0.58), carriage=20.0, tail=(18, 2.0),
                   stance_shift=(-0.11, -0.07), scap=0.50, ramp=(0.045, 0.06), open=(4, 30), back=(7.0, 0.62)),
    "gallop": dict(rider="actor_b-horse-gallop-fw", strides=1, kind="cycle", stride=6.00, hip_rom=52.0,
                   pelvis=(0.0, 1.0, 1.5),
                   td=dict(LH=0.76, LF=0.10, RH=0.86, RF=0.20), duty=(0.19, 0.175),
                   lift=(0.26, 0.17), lift_peak=(0.40, 0.42), lift_pow=0.65, carpus=112, hock=58, flex_peak=(0.38, 0.42),
                   fetlock=(95, 82), load=(20, 22), breakover=(26, 50),
                   amp_z=0.12, dz0=-0.04, pitch=7.0, roll=1.5, nod=(8.0, 1, 0.17), carriage=22.0, tail=(28, 1.0),
                   stance_shift=(-0.09, -0.10), scap=1.0, ramp=(0.035, 0.045), open=(5, 34), back=(12.0, 0.66), ramp_h=(0.02, 0.038)),
    "sprint": dict(rider="actor_b-horse-gallop-sprint", strides=10, kind="cycle", stride=6.10, hip_rom=54.0,
                   pelvis=(0.0, 1.0, 1.5),
                   td=dict(LH=0.86, LF=0.14, RH=0.93, RF=0.22), duty=(0.175, 0.16),
                   lift=(0.28, 0.17), lift_peak=(0.40, 0.42), lift_pow=0.65, carpus=118, hock=60, flex_peak=(0.38, 0.42),
                   fetlock=(100, 85), load=(22, 24), breakover=(28, 50),
                   amp_z=0.14, dz0=-0.04, pitch=8.0, roll=1.5, nod=(9.0, 1, 0.17), carriage=27.0, tail=(35, 1.0),
                   stance_shift=(-0.09, -0.06), scap=1.0, ramp=(0.035, 0.042), open=(5, 34), back=(12.0, 0.62), ramp_h=(0.022, 0.038)),
    "turn_l": dict(rider=None, length=2.0, strides=1, kind="cycle", stride=0.0, yaw_rate=math.radians(22.5), hip_rom=30.0,
                   pelvis=(2.0, 2.0, 1.0),
                   td=dict(LH=0.75, LF=0.00, RH=0.25, RF=0.50), duty=(0.72, 0.72),
                   lift=(0.115, 0.105), lift_peak=(0.42, 0.38), carpus=55, hock=34, flex_peak=(0.40, 0.36),
                   fetlock=(35, 25), load=(6, 5), breakover=(12, 10),
                   amp_z=0.012, pitch=0.8, roll=0.8, nod=(3.0, 2, 0.0), carriage=3.0, tail=(3, 1.0),
                   stance_shift=(-0.07, 0.00), scap=0.30, look=10.0, ramp=(0.06, 0.06), open=(0, 0)),
    "jump": dict(rider="actor_b-horse-gallop^jump-over", length=1.2667, kind="jump", speed=8.5, open=(5, 32), hip_rom=70.0),
    "rear": dict(rider="actor_a-horse-rear", length=4.0, kind="rear", speed=0.0, open=(0, 12), hip_rom=60.0),
}
GAITS["turn_r"] = dict(GAITS["turn_l"], yaw_rate=-GAITS["turn_l"]["yaw_rate"], look=-10.0)
# Another animal on the horse's rig (tools/bison/anatomy.py) changes the gaits it needs (strides, carriage, the back's
# flexion) before the variants are made from them.
for _g, _o in getattr(A, "GAIT_OVERRIDES", {}).items():
    GAITS[_g] = dict(GAITS[_g], **_o)

# Short-stride variants (same rider clip, timing and duty; the runtime blends them with
# the full stride by speed). Stride ratio and the scale of the swing lift and flexion.
SHORT = {"walk": (0.35, 0.8), "trot": (0.56, 0.85), "canter": (0.62, 0.9), "gallop": (0.70, 0.92)}
for _g, (_k, _f) in SHORT.items():
    _b = GAITS[_g]
    GAITS[_g + "_s"] = dict(_b, stride=round(_b["stride"] * _k, 4), variant_of=_g,
                            lift=tuple(v * _f for v in _b["lift"]), carpus=_b["carpus"] * _f, hock=_b["hock"] * _f,
                            carriage=_b["carriage"] * 0.8)

# Turning. A moving horse turns on a circle: its hooves are planted along the arc and it
# leans into the turn. Every moving gait clip (and its short stride) has two curved
# variants, `<clip>_tl` (turning left) and `<clip>_tr`, baked on a circle of radius
# turn_radius: the ground frame turns about a centre turn_radius to the side, so the
# planted hooves follow the arc (no sideways skid), and the body leans in by
# LEAN_K x atan(v^2 / (g R)) (at most LEAN_MAX), with the legs parallel to the leaning body
# (hooves out to the side, the body lowered to keep the legs' reach). The runtime blends
# straight and curved by curvature: weight = yaw rate x turn_radius / speed.
# The radius is the gait's minimum turn radius or v^2 / A_LAT at the full stride's speed,
# whichever is larger (the Horse controller uses the same limits).
TURN_R_MIN = {"walk": 2.0, "trot": 3.5, "canter": 5.0, "gallop": 10.0, "sprint": 20.0}
A_LAT = 6.0              # m/s^2, lateral acceleration limit (about 0.6 g)
LEAN_K = 0.5
LEAN_MAX = 14.0          # deg
CURVE_GAITS = ["walk", "walk_s", "trot", "trot_s", "canter", "canter_s", "gallop", "gallop_s", "sprint"]


for _c in CURVE_GAITS:
    _b = GAITS[_c]
    _full = GAITS[_b.get("variant_of", _c)]
    for _side, _sg in (("_tl", 1.0), ("_tr", -1.0)):
        GAITS[_c + _side] = dict(_b, curve=_sg, curve_of=_c, full_gait=_b.get("variant_of", _c))
CLIP_ORDER = (["idle", "walk", "walk_s", "trot", "trot_s", "canter", "canter_s", "gallop", "gallop_s", "sprint"]
              + [c + s for c in CURVE_GAITS for s in ("_tl", "_tr")]
              + ["turn_l", "turn_r", "jump", "rear"])


def load_rider_curves():
    return json.load(open(os.path.join(HERE, "rider_curves.json")))


_RC = None


def _rc():
    global _RC
    if _RC is None:
        _RC = load_rider_curves()
    return _RC


def clip_frames(name, rc=None):
    rc = rc or _rc()
    g = GAITS[name]
    if g.get("rider") in rc["gaits"]:
        r = rc["gaits"][g["rider"]]
        return int(r["frames"]), float(r["clip_s"])
    L = g["length"]
    return int(round(L * FPS)) + 1, L


# Exported key rate (keys per second). The fast gaits and the jump are keyed at 120 Hz: the
# engine interpolates bone rotations linearly between keys, and at 30 Hz a galloping hoof
# sank 1.5-3.7 cm into the ground and slid half-way between keys (review, revision 4). The
# trot is short and gets 120 Hz too; the walk, idle, turns and rear keep 30 Hz.
EXPORT_FPS = 120
FAST_GAITS = ("trot", "canter", "gallop", "sprint", "jump")


def key_rate(name):
    g = GAITS[name]
    base = g.get("full_gait") or g.get("variant_of") or name
    base = GAITS.get(base, {}).get("variant_of") or base
    return 120 if base in FAST_GAITS else 30


def key_times(name, rc=None):
    """Clip times of the exported keys (the clip length at key_rate)."""
    nf, L = clip_frames(name, rc)
    n = int(round((nf - 1) * key_rate(name) / FPS)) + 1
    return [L * i / (n - 1) for i in range(n)]


def stride_time(name, rc=None):
    g = GAITS[name]
    return clip_frames(name, rc)[1] / g.get("strides", 1)


def ground_speed(name, rc=None):
    """Speed at which the planted hooves do not move at playback rate 1 (m/s)."""
    g = GAITS[name]
    if g["kind"] == "cycle":
        return g["stride"] / stride_time(name, rc) if g["stride"] else 0.0
    if g["kind"] == "jump":
        return g["speed"]
    return 0.0


def turn_radius(name, rc=None):
    """Radius (m) of the circle a curved variant is baked on: the gait's minimum turn
    radius or v^2 / A_LAT at its full stride's speed, whichever is larger (0 = straight)."""
    g = GAITS[name]
    if not g.get("curve"):
        return 0.0
    full = g["full_gait"]
    v = ground_speed(full, rc)
    return max(TURN_R_MIN[full], v * v / A_LAT)


def lean_angle(name, rc=None):
    """Signed lean of a curved variant into its turn (rad, + = to the left)."""
    g = GAITS[name]
    if not g.get("curve"):
        return 0.0
    v = ground_speed(name, rc)
    a = v * v / turn_radius(name, rc)
    return g["curve"] * math.radians(min(LEAN_MAX, LEAN_K * math.degrees(math.atan(a / GRAVITY))))


def ground_frame(name, t, rc=None):
    """4x4 root space -> ground frame at clip time t: the frame in which planted hooves do
    not move. Straight cycles move forward at the ground speed; curved variants and turns
    in place turn about a centre to the side (or the origin); the jump adds the ballistic
    root lift."""
    g = GAITS[name]
    M = np.eye(4)
    if g.get("curve"):
        R = turn_radius(name, rc)
        w = g["curve"] * ground_speed(name, rc) / R
        c = np.array([g["curve"] * R, 0.0, 0.0])        # +x = the horse's left
        return about(c, rot(UP, w * t))
    yr = g.get("yaw_rate", 0.0) if g["kind"] == "cycle" else 0.0
    if yr:
        M[:3, :3] = rot(UP, yr * t)
        return M
    M[:3, 3] = FWD * ground_speed(name, rc) * t
    M[2, 3] += root_lift(name, t)
    return M


# ---------------------------------------------------------------------------
# Jump: root lift and timeline (actor_b-horse-gallop^jump-over, 1.267 s)
# ---------------------------------------------------------------------------
# Hind push-off to 0.37 s, flight 0.37-0.84 s (the root and collider leave the ground on
# a ballistic arc), fore landing 0.84 / 0.90, hind 0.99 / 1.05, back into the gallop.
JUMP_TAKEOFF = 0.37
JUMP_LAND = 0.84
# Body height above the ground (ground frame, m); the root carries the ballistic part.
JUMP_DZ = [(0.0, 0.0), (0.18, -0.03), (0.30, -0.01), (0.38, 0.10), (0.61, 0.60), (0.84, 0.15), (0.94, -0.05),
           (1.06, 0.0), (1.2667, 0.0)]
JUMP_PITCH = [(0.0, 0.0), (0.16, -4.0), (0.30, 16.0), (0.38, 18.0), (0.62, 0.0), (0.80, -14.0), (0.90, -12.0),
              (1.02, -2.0), (1.15, 2.0), (1.2667, 0.0)]
# Stance windows (s). Every leg alternates stance and a swing of at least 0.2 s; the
# windows before the clip start are the approach gallop's (for the first swing).
JUMP_STANCE = {"LF": [(-0.56, -0.43), (0.00, 0.13), (0.84, 0.97), (1.22, 1.35)],
               "RF": [(-0.49, -0.36), (0.07, 0.20), (0.90, 1.03)],
               "LH": [(-0.14, -0.02), (0.20, 0.34), (0.99, 1.12)],
               "RH": [(-0.10, 0.02), (0.23, 0.355), (1.05, 1.18)]}
# Neck: gallop carriage on the approach, raised a little at take-off, stretched forward
# and down over the fence (bascule) and kept forward and down through the landing.
JUMP_NECK = [(0.0, 22.0), (0.20, 14.0), (0.30, 18.0), (0.40, 22.0), (0.55, 30.0), (0.75, 30.0), (0.92, 28.0),
             (1.05, 26.0), (1.15, 24.0), (1.2667, 22.0)]


def stance_windows(name, rc=None):
    """Stance intervals (clip seconds) per leg: {leg: [(t0, t1), ...]}, for cycles over two
    loops starting one loop early (events at the loop seam included), for the jump its
    table, for the rear the fore legs' pawing (lift-off 0.5 s, landing 2.8 s)."""
    g = GAITS[name]
    nf, L = clip_frames(name, rc)
    out = {}
    if g["kind"] == "cycle":
        n = g.get("strides", 1)
        T = L / n
        for leg in LEGS:
            k = 0 if leg[1] == "F" else 1
            out[leg] = [((j + g["td"][leg]) * T, (j + g["td"][leg] + g["duty"][k]) * T) for j in range(-n - 1, 2 * n + 1)]
    elif g["kind"] == "jump":
        out = {leg: list(v) for leg, v in JUMP_STANCE.items()}
    elif g["kind"] == "rear":
        for leg in LEGS:
            out[leg] = [(-1.0, 0.5), (2.8, L + 1.0)] if leg[1] == "F" else [(-1.0, L + 1.0)]
    return out


def root_lift(name, t, rate=1.0, g=GRAVITY):
    """Height of the root above the take-off ground at clip time t (jump only): a
    ballistic arc from JUMP_TAKEOFF to JUMP_LAND. At playback rate r the flight lasts
    (JUMP_LAND - JUMP_TAKEOFF) / r and the arc is lower by 1 / r^2."""
    if GAITS.get(name, {}).get("kind") != "jump" or t <= JUMP_TAKEOFF or t >= JUMP_LAND:
        return 0.0
    tau = t - JUMP_TAKEOFF
    return 0.5 * g * tau * (JUMP_LAND - JUMP_TAKEOFF - tau) / (rate * rate)


def jump_launch_speed(rate=1.0, g=GRAVITY):
    """Vertical root speed at take-off for playback rate `rate` (m/s)."""
    return 0.5 * g * (JUMP_LAND - JUMP_TAKEOFF) / rate


# ---------------------------------------------------------------------------
# Solver
# ---------------------------------------------------------------------------
# Extra body drop of each curved variant (Solver.fit_curve_drop), fitted once per process.
_CURVE_DROP = {}

class Solver:
    def __init__(self, rig, rider_curves):
        self.rig = rig
        self.rc = rider_curves
        r = rig
        self.leg = {}
        for leg in LEGS:
            s = "l" if leg[0] == "L" else "r"
            fore = leg[1] == "F"
            toe = np.array(A.side(A.J["f_toe" if fore else "h_toe"], s))
            info = dict(side=s, fore=fore, toe=toe, leg=leg)
            if fore:
                S0 = r.head["humerus_" + s]
                E0, C0, F0 = r.head["radius_" + s], r.head["cannon_" + s], r.head["pastern_" + s]
                info.update(L1=r.len["humerus_" + s], L2a=r.len["radius_" + s], L2b=r.len["cannon_" + s],
                            pole=np.array([0, 1.0, 0]))
            else:
                S0 = r.head["femur_" + s]
                E0, C0, F0 = r.head["tibia_" + s], r.head["hcannon_" + s], r.head["hpastern_" + s]
                info.update(L1=r.len["femur_" + s], L2a=r.len["tibia_" + s], L2b=r.len["hcannon_" + s],
                            pole=np.array([0, -1.0, 0]))
            info["gamma0"] = planar_bend(S0, E0, C0, F0, info["pole"])
            pname, hname = (("pastern_", "hoof_") if fore else ("hpastern_", "hhoof_"))
            P0, T0 = r.head[hname + s], r.tail[hname + s]
            info["Lp"] = r.len[pname + s]
            info["Lh"] = r.len[hname + s]
            info["a_c0"] = sag_angle(F0 - C0)
            info["a_p0"] = sag_angle(P0 - F0)
            info["a_h0"] = sag_angle(T0 - P0)
            info["F0"] = F0
            info["S0"] = S0
            if not fore:
                # hind limb rest angles: stifle (femur-tibia) and hock (tibia-cannon) interior
                # angles, and the femur's sagittal angle in the pelvis (hips) frame
                info["stifle0"] = _interior(S0, E0, C0)
                info["hock0"] = _interior(E0, C0, F0)
                info["fem0"] = sag_angle(E0 - S0)      # the solver measures against the pelvis's rotation from rest
                info["line0"] = sag_angle(F0 - S0)
            self.leg[leg] = info
        self.diag = {}
        self.hipdiag = {}
        self._hipwin = {}
        self._natural = False
        self.pivot = np.array(A.S((0.0, -0.10, 1.05)))
        self.rear_pivot = np.array(A.S((0.0, 0.38, 0.92)))

    # --- ground frame ----------------------------------------------------------
    def ground(self, name, t):
        """4x4 root space -> ground frame at clip time t."""
        return ground_frame(name, t, self.rc)

    # --- stance ------------------------------------------------------------------
    def _stance(self, name, g, info, t, t0, t1, loads=True):
        """Planted hoof for a stance from t0 to t1 (clip time) at time t: toe, fetlock,
        pastern / hoof angles and the rotation of the ground about the root (turns).
        The fetlock load and the breakover have zero rate at touchdown and lift-off."""
        k = 0 if info["fore"] else 1
        T_st = t1 - t0
        p = min(max((t - t0) / T_st, 0.0), 1.0)
        t_mid = 0.5 * (t0 + t1)
        sh = g.get("stance_shift", (0.0, 0.0))[k]
        base = self._lean_setup(name)[2].get(info["leg"], info["toe"]) + FWD * sh
        Gi = np.linalg.inv(self.ground(name, t)) @ self.ground(name, t_mid)
        toe = xf(Gi, base)
        R = Gi[:3, :3]
        load = math.radians(g.get("load", (0, 0))[k]) * math.sin(math.pi * p) ** 2 if loads else 0.0
        bo = math.radians(g.get("breakover", (0, 0))[k]) * smoothstep(g.get("bo_from", (0.70, 0.55))[k], 1.0, p) if loads else 0.0
        a_h = info["a_h0"] - bo
        a_p = info["a_p0"] + load - bo
        cor = toe - info["Lh"] * (R @ sag_dir(a_h))
        F = cor - info["Lp"] * (R @ sag_dir(a_p))
        return dict(stance=True, F=F, a_p=a_p, a_h=a_h, p=p, gamma_add=0.0, toe=toe, R=R)

    # --- swing ---------------------------------------------------------------------
    def _swing(self, name, g, info, t, lo, td, body_tuck=None):
        """Swing from the lift-off of stance `lo` (t0, t1) to the touchdown of stance `td`.

        Two paths for the fetlock, blended: near lift-off and touchdown a ROOT-frame path
        (a minimum-jerk blend of the lift-off and touchdown points plus two end terms that
        carry the stance velocity into and out of the swing: c_s and c_e have slope 1 at
        their end and decay over `ramp` s), so the hoof leaves the ground from rest and has
        slowed back towards zero ground speed when it lands (swing retraction); mid-swing a
        BODY-frame path, so the leg follows the body's bob and pitch (and, in the jump, the
        tuck from body_tuck(t, s) -> (weight, body-frame offset)). The lift rises and
        falls steeply (bump), so the hoof does not glide in along the ground."""
        k = 0 if info["fore"] else 1
        t_lo, t_td = lo[1], td[0]
        T = t_td - t_lo
        s = min(max((t - t_lo) / T, 0.0), 1.0)
        tau = s * T
        a = self._stance(name, g, info, t_lo, lo[0], lo[1])
        b = self._stance(name, g, info, t_td, td[0], td[1])
        eps = 1e-3
        Va = (a["F"] - self._stance(name, g, info, t_lo - eps, lo[0], lo[1])["F"]) / eps
        Vb = (self._stance(name, g, info, t_td + eps, td[0], td[1])["F"] - b["F"]) / eps
        ramp = g.get("ramp", 0.035)
        if not info["fore"] and g.get("ramp_h"):
            ramp = g["ramp_h"]
        r_lo, r_td = (ramp, ramp) if not isinstance(ramp, (tuple, list)) else ramp
        # c_s = tau exp(-(tau / r_lo)^2) and c_e = -(T - tau) exp(-((T - tau) / r_td)^2) have
        # slope 1 at their end and vanish at the other: the hoof leaves and meets the ground
        # with zero ground speed, and the ground speed grows only quadratically within about
        # r of either end. Near touchdown the hoof is carried a little ahead of its landing
        # point and swung back onto it (swing retraction).
        u_lo, u_td = tau / r_lo, (T - tau) / r_td
        c_s = tau * math.exp(-u_lo * u_lo) - T * math.exp(-(T / r_lo) ** 2) * s
        c_e = -(T - tau) * math.exp(-u_td * u_td) + T * math.exp(-(T / r_td) ** 2) * (1 - s)
        m = minjerk(s)
        lift = g["lift"][k] * bump(s, g["lift_peak"][k], g.get("lift_pow", 1.0))
        up_root = np.linalg.inv(self.ground(name, t))[:3, :3] @ UP
        P_root = a["F"] + (b["F"] - a["F"]) * m + Va * c_s + Vb * c_e + up_root * lift
        D_now, D_lo, D_td = self.Dfn(t), self.Dfn(t_lo), self.Dfn(t_td)
        Fl = xf(np.linalg.inv(D_lo), a["F"]) * (1 - m) + xf(np.linalg.inv(D_td), b["F"]) * m + UP * lift
        wb = smoothstep(0.08, 0.32, s) * (1 - smoothstep(0.68, 0.92, s))
        if body_tuck is not None:
            w2, off = body_tuck(t, s)
            Fl = Fl + off
            wb = max(wb, w2)
        P_body = xf(D_now, Fl)
        F = P_root * (1 - wb) + P_body * wb
        # never lower than the ground-referenced path (a body dip must not drag the hoof)
        F[2] = max(F[2], P_root[2])
        flex = math.radians(g["carpus"] if info["fore"] else g["hock"]) * profile(s, g["flex_peak"][k], 1.3)
        fl = math.radians(g["fetlock"][k]) * profile(s, 0.40, 1.3)
        # hoof yaw (turns): from the lift-off stance's yaw to the touchdown stance's, with the
        # stance yaw rates carried into and out of the swing (no twist at the swing ends)
        y_lo, y_td = _yaw_of(a["R"]), _yaw_of(b["R"])
        w_lo = (y_lo - _yaw_of(self._stance(name, g, info, t_lo - eps, lo[0], lo[1])["R"])) / eps
        w_td = (_yaw_of(self._stance(name, g, info, t_td + eps, td[0], td[1])["R"]) - y_td) / eps
        yaw = y_lo + (y_td - y_lo) * m + w_lo * c_s + w_td * c_e
        return dict(stance=False, F=F, s=s, gamma_add=flex, fet=fl, ap_lo=a["a_p"], ap_td=b["a_p"],
                    ah_lo=a["a_h"], ah_td=b["a_h"], R=rot(UP, yaw))

    def leg_state(self, g, name, leg, t, length):
        info = self.leg[leg]
        T_stride = length / g.get("strides", 1)
        k = 0 if info["fore"] else 1
        duty = g["duty"][k]
        T_st = duty * T_stride
        n = math.floor(t / T_stride - g["td"][leg])
        t0 = (n + g["td"][leg]) * T_stride            # latest touchdown at or before t
        if t - t0 < T_st:
            return self._stance(name, g, info, t, t0, t0 + T_st)
        lo = (t0, t0 + T_st)
        td = (t0 + T_stride, t0 + T_stride + T_st)
        return self._swing(name, g, info, t, lo, td)

    def _load(self, g, leg, t, T_stride):
        k = 0 if leg[1] == "F" else 1
        duty = g["duty"][k]
        ph = (t / T_stride - g["td"][leg]) % 1.0
        return math.sin(math.pi * ph / duty) if ph < duty else 0.0

    def _body_D(self, g, name, t, length):
        """Body transform of a cycle gait at time t (cached per clip and time)."""
        key = (name, round(t, 6), length)
        cache = getattr(self, "_dcache", None)
        if cache is None or len(cache) > 20000:
            cache = self._dcache = {}
        if key in cache:
            return cache[key]
        T_stride = length / g.get("strides", 1)
        phase = (t / length) % 1.0
        lean, dz_lean, _ = self._lean_setup(name)
        dz = g["amp_z"] * self._saddle_curve(g, phase) + g.get("dz0", 0.0) + dz_lean
        pitch = math.radians(g["pitch"]) * self._pitch_norm(g, name, t, length)
        ld = {leg: self._load(g, leg, t, T_stride) for leg in LEGS}
        roll = math.radians(g["roll"]) * 0.5 * ((ld["LF"] + ld["LH"]) - (ld["RF"] + ld["RH"]))
        roll += math.radians(g.get("roll_diag", 0.0)) * 0.5 * ((ld["LF"] + ld["RH"]) - (ld["RF"] + ld["LH"]))
        roll += lean
        D = self._compose_D(self.pivot, pitch, roll, dz, True)
        cache[key] = D
        return D

    def _lean_setup(self, name):
        """(lean, dz_lean, {leg: planted toe at rest}) of a curved variant: the body rolls
        into the turn about the pivot, the legs stay parallel to the leaning body (each
        hoof goes where its rest leg vector, rotated with the body, meets the ground) and
        the body is lowered so that the outside legs keep their standing length."""
        cache = getattr(self, "_lcache", None)
        if cache is None:
            cache = self._lcache = {}
        if name in cache:
            return cache[name]
        th = lean_angle(name, self.rc) if name in GAITS else 0.0
        if not th:
            cache[name] = (0.0, 0.0, {})
            return cache[name]
        dz = 0.0
        toes = {}
        bend = self._bend(name, GAITS[name]) if name in GAITS else 0.0
        for _ in range(3):
            D = self._compose_D(self.pivot, 0.0, th, dz, True)
            R = D[:3, :3]
            worst = -9.0
            for leg, info in self.leg.items():
                S1 = xf(D, self._bent_girdle(info, bend))
                h = S1 + R @ (info["toe"] - info["S0"])
                worst = max(worst, h[2])
                toes[leg] = np.array([h[0], info["toe"][1], 0.0])
            dz -= worst
        if getattr(self, "_fitting", False):
            dz += self._curve_drop.get(name, 0.0)
        else:
            if name not in _CURVE_DROP:
                _CURVE_DROP[name] = Solver(self.rig, self.rc).fit_curve_drop(name)
            dz += _CURVE_DROP[name]
        cache[name] = (th, dz, toes)
        return cache[name]

    def _bent_girdle(self, info, bend):
        """Rest position of a leg's girdle joint (shoulder / hip) with the trunk bent by
        `bend` (Solver._bend): the chest turned about T9, the loin, loin_2 and pelvis about
        their joints in turn."""
        p = np.asarray(info["S0"], float)
        if not bend:
            return p
        r = self.rig
        if info["fore"]:
            return xf(about(r.head["chest"], rot(UP, bend * A.SPINE_BEND["chest"])), p)
        for n in ("loin", "loin_2", "hips"):
            p = xf(about(r.head[n], rot(UP, bend * A.SPINE_BEND[n])), p)
        return p

    def fit_curve_drop(self, name, samples=24):
        """Extra body drop (m) of a curved variant so that its legs need no more reach than
        the straight clip's (at least 1.0): on the circle the outside legs sweep a longer arc
        and the lean shortens their reach, so the horse sinks a little into the turn."""
        g = GAITS[name]
        if not g.get("curve"):
            return 0.0
        self._fitting = True
        self._curve_drop = {}
        nf, L = clip_frames(name, self.rc)

        def reach(nm, drop=None):
            if drop is not None:
                self._curve_drop[nm] = drop
            self._lcache = {}
            self._dcache = {}
            self.diag = {}
            self.hipdiag = {}
            for i in range(samples):
                self.pose_at(nm, L * (i + 0.5) / samples, L, nf)
            fore = max(max(v) for k, v in self.diag.items() if k[1] == "F")
            # the hind chain stops at its limits; a target it cannot reach is a miss
            miss = max((x[4] for v in self.hipdiag.values() for x in v), default=0.0)
            return max(fore, 1.0 + miss)
        target = max(reach(g["curve_of"]), 1.0)
        lo, hi = 0.0, 0.0
        if reach(name, 0.0) <= target:
            self._curve_drop[name] = 0.0
            return 0.0
        hi = -0.02
        while reach(name, hi) > target and hi > -0.25:
            lo, hi = hi, hi * 2
        for _ in range(8):
            mid = 0.5 * (lo + hi)
            if reach(name, mid) > target:
                lo = mid
            else:
                hi = mid
        self._curve_drop[name] = hi
        self._lcache = {}
        self._dcache = {}
        self.diag = {}
        return hi

    def _compose_D(self, pivot, pitch, roll, dz, set_saddle):
        R = rot(LAT, -pitch) @ rot(np.array([0, 1.0, 0]), roll)
        D = about(pivot, R)
        if set_saddle:
            sad = self.rig.rest["saddle"][:3, 3]
            D[2, 3] += (A.ATTACH_Z + dz) - (D @ np.append(sad, 1.0))[2]
        else:
            D[2, 3] += dz
        return D

    # --- leg chain -------------------------------------------------------------
    def solve_leg(self, pose, leg, st, G, g):
        """Fill pose[] for one leg. G: 4x4 rest->now transform of its girdle (chest or
        hips). Returns the toe position."""
        r = self.rig
        info = self.leg[leg]
        s = info["side"]
        F = st["F"]
        Rg = G[:3, :3]
        if info["fore"]:
            scap = "scapula_" + s
            Ms = G @ r.rest[scap]
            # the shoulder blade (revision 5) turns with the leg's fore-aft reach (lower end
            # forward when the fetlock is ahead of its rest position in the chest frame) about
            # a point in its upper part (A.SCAP_PIVOT; its upper border goes back), and glides down the
            # ribcage while the leg carries no weight (the trunk sits in the thoracic sling
            # between the blades of the loaded legs; the rest pose is the standing, loaded one)
            pivot = Ms[:3, 3] + Ms[:3, 1] * (A.SCAP_PIVOT * r.len[scap])
            Fr = (np.linalg.inv(G) @ np.append(F, 1.0))[:3]
            fwd_off = -(Fr[1] - info["F0"][1])
            # (the shoulder joint travels as far as it did with the blade turning about its upper
            # border: the blade turns 1 / (1 - SCAP_PIVOT) as far, up to SCAP_MAX)
            ang = self.scap_k * fwd_off / (1.0 - A.SCAP_PIVOT)
            ang = max(-self.SCAP_MAX, min(self.SCAP_MAX, ang))
            Ms = about(pivot, rot(Rg @ LAT, -ang)) @ Ms
            # (the blade is up while the leg carries weight, from mid-stance through the push-off
            # to the lift-off; it sinks early in the swing and is still down at the touchdown,
            # rising as the leg takes the weight again; a one-shot can set it with "sling")
            if "sling" in st:
                down = st["sling"]
            elif st["stance"]:
                p_ = min(max(st.get("p", 0.5), 0.0), 1.0)
                down = 1.0 - math.sin(math.pi * p_) if p_ < 0.5 else 0.0
            else:
                down = smoothstep(0.1, 0.4, st.get("s", 1.0))
            Ms[:3, 3] += Ms[:3, 1] * (self.sling * down)
            pose[scap] = Ms
            S = Ms[:3, 3] + Ms[:3, 1] * r.len[scap]
            up_name, a_name, b_name = "humerus_" + s, "radius_" + s, "cannon_" + s
            p_name, h_name = "pastern_" + s, "hoof_" + s
            # the humerus pose follows the swung scapula
            ref_R = Ms[:3, :3] @ np.linalg.inv(r.rest[scap][:3, :3])
        else:
            up_name, a_name, b_name = "femur_" + s, "tibia_" + s, "hcannon_" + s
            p_name, h_name = "hpastern_" + s, "hhoof_" + s
            S = (G @ r.rest[up_name])[:3, 3]
            ref_R = Rg
            E, C, Fs = self.solve_hind(leg, S, F, Rg, st, g)
            pose[up_name] = r.aim(up_name, S, E, ref_R)
            pose[a_name] = r.aim(a_name, E, C, ref_R)
            pose[b_name] = r.aim(b_name, C, Fs, ref_R)
            return self._lower(pose, info, st, C, Fs, p_name, h_name)
        pole = Rg @ info["pole"]
        gamma = info["gamma0"] + st["gamma_add"]
        # a stance leg that would over-reach opens its carpus / hock (up to `open` deg)
        d = float(np.linalg.norm(F - S))
        L2a, L2b, L1 = info["L2a"], info["L2b"], info["L1"]
        k = 0 if info["fore"] else 1
        # (a swinging leg gives up its flexion first); never beyond gamma0 - open
        g0 = info["gamma0"]
        g_open = math.radians(g.get("open", (0, 0))[k])
        want = d / 0.975 - L1
        if seg2_len(L2a, L2b, gamma) < want:
            c = (want * want - L2a * L2a - L2b * L2b) / (2 * L2a * L2b)
            g_need = math.copysign(math.acos(min(max(c, -1.0), 1.0)), g0)
            lim = g0 - math.copysign(g_open, g0)
            gamma = max(g_need, lim) if g0 > 0 else min(g_need, lim)
        E, C, stretch = solve_two_bone(S, F, L1, L2a, L2b, gamma, pole)
        self.diag.setdefault(leg, []).append(stretch)
        a = F - S
        a /= np.linalg.norm(a)
        q = pole - (pole @ a) * a
        q /= np.linalg.norm(q)
        dr = (C - E) / np.linalg.norm(C - E)
        phr = math.atan2(dr @ q, dr @ a)
        dc = math.cos(phr + gamma) * a + math.sin(phr + gamma) * q
        Fs = C + info["L2b"] * dc
        self.reach_err = max(getattr(self, "reach_err", 0.0), float(np.linalg.norm(Fs - F)))
        pose[up_name] = r.aim(up_name, S, E, ref_R)
        pose[a_name] = r.aim(a_name, E, C, ref_R)
        pose[b_name] = r.aim(b_name, C, Fs, ref_R)
        return self._lower(pose, info, st, C, Fs, p_name, h_name)

    def _lower(self, pose, info, st, C, Fs, p_name, h_name):
        """Pastern and hoof: planted in stance, following the cannon in the swing."""
        r = self.rig
        if st["stance"]:
            toe = st["toe"]
            Rt = st.get("R", np.eye(3))
            cor = toe - info["Lh"] * (Rt @ sag_dir(st["a_h"]))
            ref_low = Rt
        else:
            a_c = sag_angle(Fs - C)
            # swing hoof angles follow the cannon mid-swing and are level again (landing
            # attitude) well before touchdown, so the toe does not hang down near the ground
            w = smoothstep(0.0, 0.22, st["s"]) * (1 - smoothstep(0.55, 0.88, st["s"]))
            a_p_sw = a_c + (info["a_p0"] - info["a_c0"]) - st["fet"]
            a_h_sw = a_p_sw + (info["a_h0"] - info["a_p0"]) - 0.3 * st["fet"]
            m = minjerk(st["s"])
            a_p_g = st["ap_lo"] + (st["ap_td"] - st["ap_lo"]) * m
            a_h_g = st["ah_lo"] + (st["ah_td"] - st["ah_lo"]) * m
            a_p = (1 - w) * a_p_g + w * a_p_sw
            a_h = (1 - w) * a_h_g + w * a_h_sw
            Rs = st.get("R", np.eye(3))
            cor = Fs + info["Lp"] * (Rs @ sag_dir(a_p))
            toe = cor + info["Lh"] * (Rs @ sag_dir(a_h))
            ref_low = Rs
        pose[p_name] = r.aim(p_name, Fs, cor, ref_low)
        pose[h_name] = r.aim(h_name, cor, toe, ref_low)
        return toe

    # --- hind limb ----------------------------------------------------------------
    # The hind limb (revision 4) is solved as a three-segment chain hip -> stifle -> hock ->
    # fetlock with the reciprocal apparatus of a real horse: the stifle and the hock flex and
    # extend together (hock flexion = HIND_COUPLING x stifle flexion, plus part of the gait's
    # swing flexion). The femur's swing against the pelvis is then limited to the gait's
    # hip_rom: per clip the natural swing is found in a first pass and compressed smoothly
    # into a window of hip_rom around its middle; the rest of the reach comes from the hock
    # and the fetlock (and the pelvis, which pitches, rolls and yaws with the hind legs).
    HIND_COUPLING = 1.25
    SWING_BIAS = 0.5          # share of the gait's prescribed swing hock flexion
    HOCK_OPEN_MAX = math.radians(172.0)
    HOCK_FLEX_MIN = math.radians(45.0)
    STIFLE_FLEX_MIN = math.radians(50.0)

    def solve_hind(self, leg, S, F, Rg, st, g):
        info = self.leg[leg]
        Lf, Lt, Lc = info["L1"], info["L2a"], info["L2b"]
        pole = Rg @ info["pole"]
        a = F - S
        a = a / np.linalg.norm(a)
        q = pole - (pole @ a) * a
        q /= np.linalg.norm(q)
        nrm = np.cross(a, q)
        Rmax = math.sqrt(Lt * Lt + Lc * Lc - 2 * Lt * Lc * math.cos(self.HOCK_OPEN_MAX))
        Rmin = math.sqrt(Lt * Lt + Lc * Lc - 2 * Lt * Lc * math.cos(self.HOCK_FLEX_MIN))
        al = np.radians(np.arange(-50.0, 140.0, 0.25))

        def chain(al):
            al = np.atleast_1d(al)
            U = np.cos(al)[:, None] * a + np.sin(al)[:, None] * q
            K = S + Lf * U
            W = F - K
            d2 = np.linalg.norm(W, axis=1)
            wn = W / np.maximum(d2, 1e-9)[:, None]
            # the hock bends away from the pole within the leg plane (normal nrm); defined by
            # the plane, so it stays on the same side when the lower leg points backwards
            qp = np.cross(nrm[None, :], wn)
            dc = np.clip(d2, Rmin, Rmax)
            cb = np.clip((Lt * Lt + dc * dc - Lc * Lc) / (2 * Lt * dc), -1.0, 1.0)
            sb = np.sqrt(1.0 - cb * cb)
            C = K + Lt * (cb[:, None] * wn - sb[:, None] * qp)
            Fr = K + wn * dc[:, None]
            Fr = C + (Fr - C) / np.linalg.norm(Fr - C, axis=1)[:, None] * Lc
            stif = np.arccos(np.clip(((-U) * (C - K)).sum(1) / Lt, -1, 1))
            v1, v2 = K - C, Fr - C
            hock = np.arccos(np.clip((v1 * v2).sum(1) / (np.linalg.norm(v1, axis=1) * np.linalg.norm(v2, axis=1)), -1, 1))
            Ul = U @ Rg                      # femur direction in the pelvis frame (Rg^T u)
            th = np.arctan2(Ul[:, 2], -Ul[:, 1]) - info["fem0"]
            th = (th + math.pi) % (2 * math.pi) - math.pi     # about the rest angle
            return K, C, Fr, d2, stif, hock, th
        K, C, Fr, d2, stif, hock, th = chain(al)
        # plausible femur directions only: within 75 deg of the rest angle (the leg plane is
        # close to sagittal, so th grows with al over this range)
        keep = np.abs(th) < math.radians(75.0)
        al, K, C, Fr, d2, stif, hock, th = al[keep], K[keep], C[keep], Fr[keep], d2[keep], stif[keep], hock[keep], th[keep]
        ok = (d2 <= Rmax) & (d2 >= Rmin) & (stif >= self.STIFLE_FLEX_MIN)
        fs = info["stifle0"] - stif
        fh = info["hock0"] - hock
        gf = fh - self.HIND_COUPLING * fs - self.SWING_BIAS * st.get("gamma_add", 0.0)
        roots = []
        for i in range(len(al) - 1):
            if ok[i] and ok[i + 1] and gf[i] * gf[i + 1] <= 0 and gf[i] != gf[i + 1]:
                t = gf[i] / (gf[i] - gf[i + 1])
                roots.append(al[i] + t * (al[i + 1] - al[i]))
        # of several solutions take the one whose femur follows the hip -> fetlock line (its
        # swing from rest): the natural limb shape
        fl = Rg.T @ (F - S)
        th_line = (math.atan2(fl[2], -fl[1]) - info["line0"] + math.pi) % (2 * math.pi) - math.pi
        ref = min(max(1.3 * th_line, -math.radians(45.0)), math.radians(45.0))
        if roots:
            thr = [float(np.interp(r_, al, th)) for r_ in roots]
            a_nat = roots[int(np.argmin(np.abs(np.array(thr) - ref)))]
        elif ok.any():
            # no exact coupling (deep tuck, full reach): the best compromise, kept near the line
            idx = np.nonzero(ok)[0]
            cost = np.abs(gf[idx]) + 0.35 * np.abs(th[idx] - ref)
            j = int(np.argmin(cost))
            a_nat = float(al[idx[j]])
            if 0 < j < len(idx) - 1 and idx[j + 1] - idx[j - 1] == 2:
                c0, c1, c2 = cost[j - 1], cost[j], cost[j + 1]
                den = c0 - 2 * c1 + c2
                if den > 1e-12:
                    a_nat += 0.5 * (c0 - c2) / den * (al[1] - al[0])
        else:
            # nothing within the joint limits: the least violation (reach, stifle flexion)
            viol = np.maximum.reduce([d2 - Rmax, Rmin - d2, 0.3 * (self.STIFLE_FLEX_MIN - stif)])
            a_nat = float(al[np.argmin(viol + 0.02 * np.abs(th - ref))])
        th_nat = float(np.interp(a_nat, al, th))
        a_fin = a_nat
        win = None if self._natural else self._hipwin.get(self._clip, {}).get(leg)
        if win is not None:
            mid, h = win
            th_c = mid + h * soft_limit((th_nat - mid) / h)
            a_c = float(np.interp(th_c, th, al))
            # the capped femur must still let the lower leg reach the fetlock: if it cannot,
            # move back towards the natural angle just as far as needed
            lo_, hi_ = sorted((a_c, a_nat))
            cand = [x for x in al if lo_ <= x <= hi_] + [a_nat]
            best = a_nat
            for x in sorted(cand, key=lambda x: abs(x - a_c)):
                dd = float(np.interp(x, al, d2))
                if Rmin <= dd <= Rmax and float(np.interp(x, al, stif)) >= self.STIFLE_FLEX_MIN:
                    best = x
                    break
            a_fin = best
        K, C, Fr, d2, stif, hock, th = chain(a_fin)
        rec = self.hipdiag.setdefault(leg, [])
        miss = float(np.linalg.norm(Fr[0] - F))
        rec.append((float(th[0]), th_nat, float(stif[0]), float(hock[0]), miss, bool(st["stance"])))
        # reach used by the lower leg (hock opened to HOCK_OPEN_MAX = the limit); a target the
        # chain cannot reach is a miss (recorded above: in the swing the hoof passes a few cm
        # short of the swing path, in stance it would slip)
        self.diag.setdefault(leg, []).append(min(float(d2[0]), Rmax) / (Lt + Lc))
        self.reach_err = max(getattr(self, "reach_err", 0.0), miss)
        return K[0], C[0], Fr[0]

    def _helpers(self, pose):
        """Skinning helpers (anatomy.helpers()): each turns `fraction` as far as its distal
        bone does against its proximal one, about the joint (the thigh half the femur's turn
        in the pelvis, the stifle helper half the stifle's bend, and so on)."""
        r = self.rig
        for name, (prox, dist, frac, _key) in A.helpers().items():
            if name not in r.rest or prox not in pose or dist not in pose:
                continue
            M0 = pose[prox] @ np.linalg.inv(r.rest[prox]) @ r.rest[name]
            Rc = pose[dist][:3, :3] @ r.rest[dist][:3, :3].T @ r.rest[name][:3, :3]
            Q = Rc @ M0[:3, :3].T
            M = np.eye(4)
            M[:3, :3] = rot_fraction(Q, frac) @ M0[:3, :3]
            M[:3, 3] = pose[dist][:3, 3]
            pose[name] = M

    def hip_window(self, name, length, nf):
        """(middle, half range) of the femur's swing against the pelvis per hind leg: the
        natural swing of the clip (first pass) compressed into the gait's hip_rom."""
        if name in self._hipwin:
            return self._hipwin[name]
        g = GAITS[name]
        rom = math.radians(g.get("hip_rom", 40.0))
        saved = (self.diag, self.hipdiag, self._natural, getattr(self, "reach_err", 0.0), getattr(self, "_clip", None))
        self._natural = True
        self.hipdiag = {}
        self.diag = {}
        n = 60
        loops = g["kind"] in ("cycle", "idle")
        for i in range(n):
            t = length * (i / n if loops else i / (n - 1))
            self.pose_at(name, t, length, nf)
        win = {}
        for leg, v in self.hipdiag.items():
            th = [x[1] for x in v]
            mid = 0.5 * (max(th) + min(th))
            win[leg] = (mid, 0.5 * rom)
        self.diag, self.hipdiag, self._natural, self.reach_err, self._clip = saved
        self._hipwin[name] = win
        return win

    # --- whole pose ------------------------------------------------------------
    def pose_at(self, name, t, length, frame_count):
        g = GAITS[name]
        r = self.rig
        self._clip = name
        if not self._natural and name not in self._hipwin:
            self.hip_window(name, length, frame_count)
            self._clip = name
        kind = g["kind"]
        phase = (t / length) % 1.0 if kind != "jump" and kind != "rear" else t / length
        pose = {"root": r.rest["root"].copy()}
        self.scap_k = g.get("scap", 0.35)
        self.sling = A.SCAP_SLING if kind != "idle" else 0.0
        # ---- body motion
        dz, pitch, roll = 0.0, 0.0, 0.0
        neck_pitch, head_pitch, neck_yaw = 0.0, 0.0, 0.0
        spine_flex = 0.0
        tail_lift, tail_yaw = 0.0, 0.0
        ear = 0.0
        legs_state = {}
        T_stride = length / g.get("strides", 1)
        if kind == "cycle":
            self.Dfn = lambda tt: self._body_D(g, name, tt, length)
            for leg in LEGS:
                legs_state[leg] = self.leg_state(g, name, leg, t, length)
            D_cycle = self._body_D(g, name, t, length)
            amp, k, low = g["nod"]
            # positive neck pitch = nose down; the nod is lowest at `low`
            neck_pitch = math.radians(amp) * math.cos(2 * math.pi * k * ((t / T_stride) - low))
            neck_pitch += math.radians(g.get("carriage", 0.0))
            bk = g.get("back")
            if bk:
                spine_flex = math.radians(bk[0]) * math.cos(2 * math.pi * ((t / T_stride) - bk[1]))
            ta, tk = g["tail"]
            tail_lift = math.radians(ta)
            tail_yaw = math.radians(4.0) * math.sin(2 * math.pi * (t / T_stride) * tk)
            neck_yaw = math.radians(g.get("look", 0.0))
        elif kind == "idle":
            dz = 0.004 * math.sin(2 * math.pi * 4 * phase)          # breathing
            neck_pitch = math.radians(4.0 + 6.0 * math.sin(2 * math.pi * phase) + 2.0 * math.sin(2 * math.pi * 3 * phase))
            neck_yaw = math.radians(9.0 * math.sin(2 * math.pi * 2 * phase + 0.6))
            head_pitch = math.radians(3.0 * math.sin(2 * math.pi * 5 * phase))
            sw = max(0.0, math.sin(2 * math.pi * 3 * phase)) ** 6
            tail_yaw = math.radians(28.0) * sw * math.sin(2 * math.pi * 18 * phase)
            ear = math.radians(18.0) * max(0.0, math.sin(2 * math.pi * 5 * phase + 1.0)) ** 8
            for leg in LEGS:
                legs_state[leg] = self._stance(name, g, self.leg[leg], 0.5, 0.0, 1.0, loads=False)
        elif kind == "jump":
            self.Dfn = lambda tt: self._oneshot_D("jump", tt)
            legs_state, dz, pitch, neck_pitch, tail_lift = self._jump(g, t, length)
            spine_flex = math.radians(envelope([(0.0, 0.0), (0.25, -5.0), (0.36, 6.0), (0.6, 2.0), (0.84, -5.0),
                                                (1.0, 3.0), (1.2667, 0.0)], t))
        elif kind == "rear":
            self.Dfn = lambda tt: self._oneshot_D("rear", tt)
            legs_state, dz, pitch, neck_pitch, tail_lift, ear = self._rear(g, t, length)
        # body transform: rotate about a pivot near the girth, then set the saddle height
        if kind == "cycle":
            D = D_cycle
        elif kind in ("jump", "rear"):
            D = self._oneshot_D(kind, t)
        else:
            D = self._compose_D(self.pivot, pitch, roll, dz, True)
        pose["body"] = D @ r.rest["body"]
        self.D = D
        Rb = D[:3, :3]
        # vertebral column (revision 5): positive flexion rounds the back (loin and croup tuck
        # under), shared by the lumbar joints and the lumbosacral joint (anatomy.SPINE_FLEX);
        # turning bends the trunk along the arc (anatomy.SPINE_BEND)
        lat = Rb @ LAT
        upv = Rb @ UP
        bend = self._bend(name, g)
        pose["chest"] = pose["body"] @ r.rel["chest"]
        if spine_flex and A.SPINE_FLEX.get("chest", 0.0):
            # the forehand tips down as the loin and croup tuck under (the bison's curl; the horse has no chest share)
            pose["chest"] = about(pose["chest"][:3, 3], rot(lat, -spine_flex * A.SPINE_FLEX["chest"])) @ pose["chest"]
        if bend:
            pose["chest"] = about(pose["chest"][:3, 3], rot(upv, bend * A.SPINE_BEND["chest"])) @ pose["chest"]
        pose["back"] = pose["body"] @ r.rel["back"]
        prev = "back"
        for n in ("loin", "loin_2", "hips"):
            M = pose[prev] @ r.rel[n]
            Rn = rot(upv, bend * A.SPINE_BEND[n]) @ rot(lat, spine_flex * A.SPINE_FLEX[n])
            pose[n] = about(M[:3, 3], Rn) @ M
            prev = n
        # pelvis motion with the hind legs (revision 4): it yaws towards the protracted hind
        # leg, rolls up on the side that carries weight and tucks (lumbosacral flexion) as a
        # hind leg reaches forward to its touchdown
        pp = g.get("pelvis")
        if pp and kind == "cycle":
            pr, ld = {}, {}
            for leg in ("LH", "RH"):
                st_ = legs_state[leg]
                pr[leg] = math.cos(math.pi * st_["p"]) if st_["stance"] else -math.cos(math.pi * st_["s"])
                ld[leg] = math.sin(math.pi * st_["p"]) if st_["stance"] else 0.0
            yaw_p = -math.radians(pp[2]) * 0.5 * (pr["LH"] - pr["RH"])
            roll_p = -math.radians(pp[1]) * 0.5 * (ld["LH"] - ld["RH"])
            tuck = math.radians(pp[0]) * (2.0 * max(0.0, pr["LH"], pr["RH"]) ** 2 - 1.0)
            hd = pose["hips"][:3, 3]
            Rp = rot(Rb @ UP, yaw_p) @ rot(Rb @ np.array([0.0, 1.0, 0.0]), roll_p) @ rot(lat, tuck)
            pose["hips"] = about(hd, Rp) @ pose["hips"]
        pose["saddle"] = pose["back"] @ r.rel["saddle"]
        pose["passenger"] = pose["back"] @ r.rel["passenger"]
        for s in ("l", "r"):
            pose["stirrup_" + s] = pose["saddle"] @ r.rel["stirrup_" + s]
            pose["stirrup_iron_" + s] = pose["stirrup_" + s] @ r.rel["stirrup_iron_" + s]
        # neck and head: positive neck_pitch lowers and stretches the neck (nose down)
        up = Rb @ UP
        prev = "chest"
        shares = {"neck_1": 0.45, "neck_2": 0.30, "neck_3": 0.25}
        for n in ("neck_1", "neck_2", "neck_3"):
            M = pose[prev] @ r.rel[n]
            hd = M[:3, 3]
            M = about(hd, rot(up, neck_yaw * shares[n]) @ rot(lat, neck_pitch * shares[n])) @ M
            pose[n] = M
            prev = n
        M = pose["neck_3"] @ r.rel["head"]
        pose["head"] = about(M[:3, 3], rot(lat, head_pitch - 0.35 * neck_pitch)) @ M
        pose["bit"] = pose["head"] @ r.rel["bit"]
        for s, sg in (("l", 1), ("r", -1)):
            M = pose["head"] @ r.rel["ear_" + s]
            hl = pose["head"][:3, :3] @ np.linalg.inv(r.rest["head"][:3, :3]) @ LAT
            pose["ear_" + s] = about(M[:3, 3], rot(hl, ear)) @ M
        # tail: lifted at speed, swinging, lagging a little
        prev = "hips"
        for i, n in enumerate(("tail_1", "tail_2", "tail_3", "tail_4")):
            M = pose[prev] @ r.rel[n]
            w = (0.55, 0.25, 0.12, 0.08)[i]
            M = about(M[:3, 3], rot(up, tail_yaw * (0.4 + 0.3 * i)) @ rot(lat, -tail_lift * w)) @ M
            pose[n] = M
            prev = n
        # legs
        Gc = pose["chest"] @ np.linalg.inv(r.rest["chest"])
        Gh = pose["hips"] @ np.linalg.inv(r.rest["hips"])
        self.toes = {}
        for leg in LEGS:
            st = legs_state[leg]
            self.toes[leg] = self.solve_leg(pose, leg, st, Gc if leg[1] == "F" else Gh, g)
        self._helpers(pose)
        self.legs_state = legs_state
        return pose

    SCAP_MAX = math.radians(28.0)

    # Lateral bend of the trunk (rad, + = the chest turned left): along the arc of the curved
    # variants (a sixth of the arc a half body length subtends, at most BEND_MAX) and into the
    # turn of the turns in place.
    BEND_K = 0.35
    BEND_MAX = math.radians(4.0)
    BEND_TURN = math.radians(3.0)

    def _bend(self, name, g):
        if g.get("curve"):
            R = turn_radius(name, self.rc)
            return g["curve"] * min(self.BEND_K * 0.55 / R, self.BEND_MAX)
        if g.get("yaw_rate"):
            return math.copysign(self.BEND_TURN, g["yaw_rate"])
        return 0.0

    # --- curves ------------------------------------------------------------------
    def _saddle_curve(self, g, phase):
        r = self.rc["gaits"].get(g.get("rider"))
        if r is None:
            # turn: two gentle dips per stride
            return 0.5 * math.cos(2 * math.pi * 2 * phase)
        return interp_curve(np.array(r["saddle_z_norm"]), phase)

    def _pitch_norm(self, g, name, t, length):
        """Nose-up pitch in -1..1 from hind minus fore loading, smoothed (first two
        harmonics per stride of a pre-sampled loading curve)."""
        key = (name, length)
        cache = getattr(self, "_pcache", {})
        self._pcache = cache
        if key not in cache:
            T_stride = length / g.get("strides", 1)
            n = 64
            vals = []
            for i in range(n):
                tt = T_stride * i / n
                v = 0.0
                for leg in LEGS:
                    k = 0 if leg[1] == "F" else 1
                    duty = g["duty"][k]
                    ph = (tt / T_stride - g["td"][leg]) % 1.0
                    if ph < duty:
                        v += (1 if leg[1] == "H" else -1) * math.sin(math.pi * ph / duty)
                vals.append(v)
            Fv = np.fft.rfft(np.array(vals))
            Fv[3:] = 0
            sm = np.fft.irfft(Fv, n)
            mx = np.abs(sm).max()
            # a gait with symmetric loading (trot) keeps a small pitch from the hind legs
            # landing a moment before the fore legs (advanced placement)
            sm = sm / mx if mx > 1e-3 else 0.25 * np.cos(2 * math.pi * 2 * (np.arange(n) / n - 0.12))
            cache[key] = sm
        sm = cache[key]
        T_stride = length / g.get("strides", 1)
        return interp_curve(sm, (t / T_stride) % 1.0)

    # --- one-shots ---------------------------------------------------------------
    REAR_PITCH = [(0.0, 0.0), (0.45, -2.0), (1.0, 22.0), (1.6, 34.0), (2.17, 40.0), (2.5, 16.0), (2.8, 0.0),
                  (2.95, -3.0), (3.4, 0.0), (4.0, 0.0)]
    REAR_DZ = [(0.0, 0.0), (0.45, -0.03), (1.0, -0.10), (2.17, -0.13), (2.6, -0.06), (2.85, -0.02), (3.0, -0.04),
               (3.4, 0.0), (4.0, 0.0)]

    def _oneshot_D(self, kind, t):
        if kind == "jump":
            dz = envelope(JUMP_DZ, t) - root_lift("jump", t)       # body above the (lifted) root
            return self._compose_D(self.pivot, math.radians(envelope(JUMP_PITCH, t)), 0.0, dz, True)
        return self._compose_D(self.rear_pivot, math.radians(envelope(self.REAR_PITCH, t)), 0.0,
                               envelope(self.REAR_DZ, t), False)

    def _jump(self, g, t, L):
        """Gallop jump timed to actor_b-horse-gallop^jump-over (1.267 s): last fore strides
        to 0.20 s, hind push-off 0.20-0.37, flight 0.37-0.84 (the root flies a ballistic
        arc, the body rises about 0.5 m in all), fore landing 0.84 / 0.90, hind 0.99 / 1.05,
        back into the gallop. The approach and landing run at the jump's ground speed."""
        dz = envelope(JUMP_DZ, t)
        pitch = math.radians(envelope(JUMP_PITCH, t))
        neck = math.radians(envelope(JUMP_NECK, t))
        tail = math.radians(envelope([(0.0, 28.0), (0.4, 40.0), (0.8, 10.0), (1.2667, 28.0)], t))
        gj = dict(GAITS["gallop"], load=(22, 20), breakover=(26, 50), bo_from=(0.70, 0.45), stance_shift=(-0.05, 0.03), open=(5, 34), ramp=(0.025, 0.045), ramp_h=(0.025, 0.04), lift_pow=0.65,
                  lift=(0.22, 0.14), lift_peak=(0.40, 0.55), flex_peak=(0.40, 0.40), carpus=115, hock=65,
                  fetlock=(95, 70))
        st = {}
        air = smoothstep(0.30, 0.44, t) * (1 - smoothstep(0.76, 0.88, t))
        for leg, ivs in JUMP_STANCE.items():
            info = self.leg[leg]
            cur = next(((a, b) for (a, b) in ivs if a <= t < b), None)
            if cur:
                st[leg] = self._stance("jump", gj, info, t, cur[0], cur[1])
                continue
            prev = max([iv for iv in ivs if iv[1] <= t], key=lambda iv: iv[1])
            nxt = min([iv for iv in ivs if iv[0] > t], default=(L + 0.12, L + 0.25), key=lambda iv: iv[0])
            fore = info["fore"]
            tuck = np.array([0.0, -0.08, 0.34]) if fore else np.array([0.0, -0.30, 0.0])

            def body_tuck(tt, s, tuck=tuck):
                w = air * smoothstep(0.0, 0.2, s) * (1 - smoothstep(0.8, 1.0, s))
                return w, tuck * air * smoothstep(0.0, 0.3, s) * (1 - smoothstep(0.7, 1.0, s))
            sw = self._swing("jump", gj, info, t, prev, nxt, body_tuck)
            sw["gamma_add"] = max(sw["gamma_add"], math.radians(115 if fore else 65) * 0.95 * air)
            sw["fet"] = max(sw["fet"], math.radians(95 if fore else 70) * 0.9 * air)
            st[leg] = sw
        return st, dz, pitch, neck, tail

    def _rear(self, g, t, L):
        """Rear timed to actor_a-horse-rear (4.0 s): gather 0-0.45, rise 0.6-1.0, peak
        about 40 deg nose-up at 2.0-2.2 s with the fore legs pawing, descend 2.5, fore
        landing 2.8 s, settle to 4.0 s. The hind hooves stay planted; the body pivots
        over the hind quarters, which sink as the hocks flex."""
        pitch = math.radians(envelope(self.REAR_PITCH, t))
        dz = envelope(self.REAR_DZ, t)
        # the rear raises the neck (negative = nose up)
        neck = math.radians(envelope([(0.0, 3.0), (0.5, 6.0), (1.0, -8.0), (2.17, -14.0), (2.6, -4.0),
                                      (2.85, 8.0), (3.4, 3.0), (4.0, 3.0)], t))
        tail = math.radians(envelope([(0.0, 3.0), (1.0, -8.0), (2.5, -10.0), (3.2, 3.0), (4.0, 3.0)], t))
        ear = math.radians(envelope([(0.0, 0.0), (0.6, 35.0), (2.8, 35.0), (3.4, 0.0), (4.0, 0.0)], t))
        t_lo, t_td = 0.50, 2.80
        st = {}
        for leg in LEGS:
            info = self.leg[leg]
            base = self._stance("rear", g, info, 0.5, 0.0, 1.0, loads=False)
            if not info["fore"] or t <= t_lo or t >= t_td:
                st[leg] = base
                if info["fore"] and t >= t_td:
                    # back on the ground: the shoulder blade, still down in the sling from the
                    # swing, rises as the leg takes the weight (the planted base stance is at
                    # mid-stance, where the blade is already up: it would jump 1.5 cm in a frame)
                    st[leg] = dict(base, sling=1.0 - smoothstep(t_td, t_td + 0.25, t))
                continue
            s_ = (t - t_lo) / (t_td - t_lo)
            paw = 0.5 + 0.5 * math.sin(2 * math.pi * 1.6 * (t - t_lo) + (0.0 if info["side"] == "l" else math.pi))
            env = smoothstep(0.0, 0.12, s_) * (1 - smoothstep(0.86, 1.0, s_))
            extra = np.array([0.0, -0.08, 0.20 + 0.14 * paw]) * env
            D_now, D_lo = self._oneshot_D("rear", t), self._oneshot_D("rear", t_lo)
            Fl = xf(np.linalg.inv(D_lo), base["F"])
            Fs = xf(D_now, Fl + UP * 0.06 * bump(s_) + extra)
            w = smoothstep(0.0, 0.10, s_) * (1 - smoothstep(0.90, 1.0, s_))
            Fs = base["F"] * (1 - w) + Fs * w
            flex = math.radians(35 + 85 * paw) * env
            fl = math.radians(30 + 50 * paw) * env
            st[leg] = dict(stance=False, F=Fs, s=s_, gamma_add=flex, fet=fl, ap_lo=base["a_p"], ap_td=base["a_p"],
                           ah_lo=base["a_h"], ah_td=base["a_h"])
        return st, dz, pitch, neck, tail, ear
