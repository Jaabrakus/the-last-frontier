"""Floodborn (P04) grey-box body: SDF parts on the Actor_B joints at null-add, in the style of lib/body_shapes.py.

Design: peoples_places/bodies_design.md section 3 and the build brief (variant A "Mooring Guard" is the base; B "Reed
Runner" and C "Old River Bull" are the bold alternatives the owner judges, later creator ranges on one mesh).

- Upright at null-add (the forward lean is the runtime posture overlay, never modelled).
- Plantigrade feet on the human ankle / heel / ball: the heel sits where the human heel is; 4 splayed clawed toes.
- Own crocodilian head: skull with eye bosses (6 cm above, 3 cm wider than the human eyes), broad snout (upper rigid on
  headb, lower jaw on Actor_B's `jaw`), teeth row, nostril bosses.
- Tail on the extension chain tail_01..08 (skeleton.FLOODBORN_TAIL).
- Silhouette scutes as geometry: a two-row dorsal ridge from the nape to the tail tip, shoulder and forearm
  osteoderms, a serrated tail crest. Everything finer is paint.

All positions are Blender armature space (z up, the character faces -y), metres, female base at stature 1.0.
`groups(J, P)` returns the region nodes (weights are by region, as lib.weights.body_weights) plus the separate parts
(eyes, teeth, crest) as their own nodes.
"""

import math

import numpy as np

from lib.body_shapes import BodyParams, FINGERS, THUMB, hand_frame, hand_shapes
from lib.sdf import (Ellipsoid, Inter, Plane, RoundCone, Sphere, Sub, SymUnion, Union, frame_from, lerp, mirror_x,
                     nrm, v3)

from sdf_extra import ECapsule, Warp
from skeleton import floodborn_bones


class FBParams:
    DEFAULTS = {
        "name": "A", "sex": 0.0,
        "bulk": 1.2, "shoulder_half": 0.26, "chest_depth": 1.2, "hip_w": 1.0, "belly": 1.0, "neck": 1.0,
        "hand_scale": 1.12, "arm": 1.0, "leg": 1.0,
        "snout_len": 0.30, "snout_w": 0.070, "snout_tip_w": 0.042, "snout_h": 0.040, "snout_tip_h": 0.024,
        "jaw_h": 0.022, "nasal_boss": 0.0, "brow_boss": 0.35, "jowl": 1.0, "eye_r": 0.0165, "teeth": 1.0,
        "tail_scale": 1.0, "tail_root_r": 0.145, "tail_tip_r": 0.0175, "tail_flat": 1.25,
        "ridge_h": 0.040, "scute": 1.0, "tail_crest_h": 0.070,
        "foot_len": 0.34, "toe_len": 1.0,
        "crest": "mane", "shoulder_plates": 0.0,
    }

    def __init__(self, **kw):
        self.__dict__.update(self.DEFAULTS)
        for k, v in kw.items():
            if k not in self.DEFAULTS:
                raise KeyError(k)
            self.__dict__[k] = v

    def copy(self, **kw):
        d = {k: getattr(self, k) for k in self.DEFAULTS}
        d.update(kw)
        return FBParams(**d)


def variant(name, sex=0.0):
    """The three bold silhouettes (design 3.2), female base (sex 0) or the male fit (sex 1)."""
    if name == "A":       # Mooring Guard (the sheet)
        P = FBParams(name="A")
    elif name == "B":     # Reed Runner
        P = FBParams(name="B", bulk=1.0, shoulder_half=0.225, chest_depth=1.05, belly=0.85, hand_scale=1.06,
                     snout_len=0.42, snout_w=0.050, snout_tip_w=0.028, snout_h=0.032, snout_tip_h=0.018, jaw_h=0.018,
                     brow_boss=0.15, jowl=0.6, tail_scale=1.35 / 1.45, tail_root_r=0.125, ridge_h=0.032,
                     foot_len=0.36, toe_len=1.18, crest="row", tail_crest_h=0.050)
    elif name == "C":     # Old River Bull
        P = FBParams(name="C", bulk=1.38, shoulder_half=0.30, chest_depth=1.32, belly=1.25, neck=1.2, hand_scale=1.16,
                     snout_len=0.24, snout_w=0.085, snout_tip_w=0.060, snout_h=0.050, snout_tip_h=0.032, jaw_h=0.030,
                     brow_boss=1.0, jowl=1.7, eye_r=0.015, tail_scale=1.10 / 1.45, tail_root_r=0.18, tail_flat=1.1,
                     ridge_h=0.045, scute=1.35, foot_len=0.32, toe_len=0.85, crest="none", shoulder_plates=1.0,
                     tail_crest_h=0.060)
    else:
        raise KeyError(name)
    if sex:
        # male fit: broader snout and shoulders, a nasal boss, heavier jowls, bigger scutes; narrower hips
        P = P.copy(sex=sex, shoulder_half=P.shoulder_half + 0.04 * sex, snout_w=P.snout_w * (1 + 0.12 * sex),
                   snout_tip_w=P.snout_tip_w * (1 + 0.12 * sex), nasal_boss=1.0 * sex, jowl=P.jowl * (1 + 0.3 * sex),
                   scute=P.scute * (1 + 0.25 * sex), hip_w=P.hip_w * (1 - 0.08 * sex), neck=P.neck * (1 + 0.1 * sex),
                   tail_root_r=P.tail_root_r * (1 + 0.06 * sex), bulk=P.bulk * (1 + 0.05 * sex),
                   ridge_h=P.ridge_h * (1 + 0.25 * sex))
    return P


# ===========================================================================
# Anchors
# ===========================================================================
def eye_center(J, s):
    """Floodborn eye: about 6 cm above and 3 cm wider than the human eye bone."""
    e = J["l_eyeball"]
    return v3(s * (abs(e[0]) + 0.030), e[1] + 0.010, e[2] + 0.060)


def snout_tip(J, P):
    e = eye_center(J, 1)
    return v3(0, e[1] - P.snout_len, 1.488)


def jaw_tip(J, P):
    t = snout_tip(J, P)
    return v3(0, t[1] + 0.02, 1.445)


def tail_points(P):
    """Bind chain heads + tip (Blender) for the variant's tail."""
    bones = [b for b in floodborn_bones(P.tail_scale) if b[0].startswith("tail_")]
    pts = [b[2] for b in bones] + [bones[-1][3]]
    return np.array(pts)


def _resample(pts, n):
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    u = np.linspace(0, s[-1], n)
    return np.stack([np.interp(u, s, pts[:, k]) for k in range(3)], 1), u / s[-1]


def _smooth_curve(pts, n):
    """Catmull-Rom through the chain heads, resampled evenly."""
    P = np.vstack([2 * pts[0] - pts[1], pts, 2 * pts[-1] - pts[-2]])
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for t in np.linspace(0, 1, 12, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2])
    return _resample(np.array(out), n)


# ===========================================================================
# Parts
# ===========================================================================
def torso(J, P):
    b = P.bulk
    bw = 1 + (b - 1) * 0.8
    cd = P.chest_depth
    hc = (J["l_upper_leg"] + mirror_x(J["l_upper_leg"])) * 0.5
    S = J["l_shoulder"]
    nk = J["neck"]
    center = Union([
        Ellipsoid(hc + v3(0, 0.012, 0.060), (0.148 * bw * P.hip_w, 0.108, 0.115)),               # hips
        Ellipsoid(v3(0, -0.020 - 0.015 * (P.belly - 1), 1.00), (0.128 * b * P.belly ** 0.3, 0.112 * cd * P.belly ** 0.5, 0.12)),  # belly
        Ellipsoid(v3(0, -0.012, 1.160), (0.168 * b, 0.128 * cd, 0.150)),                          # ribcage
        Ellipsoid(v3(0, -0.058 * cd, 1.175), (0.140 * b, 0.086 * cd, 0.120)),                    # plastron
        Ellipsoid(v3(0, 0.004, S[2] - 0.030), (P.shoulder_half - 0.050, 0.112 * cd ** 0.5, 0.090)),  # girdle
    ], k=0.06)

    def side(s):
        return Union([
            Sphere(v3(s * (P.shoulder_half - 0.080), 0.012, S[2] - 0.012), 0.082 * bw),          # deltoid mass
            RoundCone(v3(s * 0.04, nk[1] + 0.03, nk[2] + 0.02), v3(s * (P.shoulder_half - 0.09), S[1] + 0.01, S[2] + 0.02),
                      0.075 * P.neck, 0.06),                                                    # trapezius
            Sphere(v3(s * (hc[0] + 0.080 * P.hip_w * bw), hc[1] + 0.045, hc[2] + 0.03), 0.072 * bw),  # hip / glute
        ], k=0.04)
    return SymUnion(center, side(1), side(-1), 0.06)


def neck(J, P):
    nb = P.neck
    return Union([
        RoundCone(v3(0, 0.025, 1.24), v3(0, 0.030, 1.465), 0.112 * nb * P.bulk ** 0.5, 0.075 * nb),
        Ellipsoid(v3(0, -0.045, 1.405), (0.068 * nb, 0.078, 0.052)),                          # throat (gular)
    ], k=0.04)


def skull(J, P):
    """Cranium, eye bosses, brow bosses, jowls and the upper snout (rigid on headb)."""
    tip = snout_tip(J, P)
    e = eye_center(J, 1)
    base_y = e[1] + 0.025
    center = Union([
        Ellipsoid(v3(0, 0.000, 1.505), (0.076, 0.085, 0.058)),                                  # cranium (flat)
        Ellipsoid(v3(0, 0.055, 1.485), (0.068, 0.055, 0.060)),                                  # occiput
        ECapsule(v3(0, base_y, 1.505), tip + v3(0, 0.030, 0.0), (P.snout_w, P.snout_tip_w),
                 (P.snout_h, P.snout_tip_h), n=2.6),                                            # upper snout
        Ellipsoid(tip + v3(0, 0.040, 0.000), (P.snout_tip_w * 1.18, 0.052, P.snout_tip_h * 1.05)),  # premaxilla bulb
        Sphere(tip + v3(0, 0.038, P.snout_tip_h + 0.004), 0.016),                                # nostril boss
    ], k=0.025)
    if P.nasal_boss > 0:
        center = Union([center, Ellipsoid(tip + v3(0, 0.075, P.snout_tip_h + 0.006),
                                          (0.028, 0.038, 0.012 + 0.008 * P.nasal_boss))], k=0.02)

    def side(s):
        es = eye_center(J, s)
        parts = [Sphere(es, 0.031),                                                             # eye boss
                 Ellipsoid(es + v3(-s * 0.004, 0.012, 0.020), (0.026, 0.030, 0.010 + 0.006 * P.brow_boss)),  # brow
                 Ellipsoid(v3(s * 0.062, -0.010, 1.468), (0.040 * P.jowl ** 0.5, 0.060, 0.042))]   # jowl / jaw muscle
        return Union(parts, k=0.018)
    head = SymUnion(center, side(1), side(-1), 0.02)
    sockets = Union([Sphere(eyeball_center(J, s), P.eye_r + 0.0015) for s in (1, -1)], 0)
    return Sub(head, sockets, k=0.004)


def eyeball_center(J, s):
    return eye_center(J, s) + v3(s * 0.016, -0.012, 0.010)


def lower_jaw(J, P):
    tip = jaw_tip(J, P)
    hinge = v3(0, 0.005, 1.452)
    return Union([
        ECapsule(hinge, tip, (P.snout_w * 0.98, P.snout_tip_w * 0.9), (P.jaw_h * 1.15, P.jaw_h * 0.65), n=2.4),
        Ellipsoid(tip + v3(0, 0.025, 0.0), (P.snout_tip_w * 0.95, 0.04, P.jaw_h * 0.75)),
    ], k=0.02)


def mouth_slit(J, P):
    """The closed mouth line between the upper snout and the lower jaw (a thin cut, open at the front and sides)."""
    tip = snout_tip(J, P)
    z0 = 1.4655
    return ECapsule(v3(0, 0.03, z0), tip + v3(0, -0.05, z0 - tip[2]), (P.snout_w * 1.6, P.snout_tip_w * 1.8),
                    (0.0035, 0.0030), n=2.0)


def arm(J, s, P):
    b = P.bulk * P.arm
    S, E, W = J.side("shoulder", s), J.side("elbow", s), J.side("wrist", s)
    out = s * np.array([1.0, 0, 0])
    ua, fa = nrm(E - S), nrm(W - E)
    u, v, w = hand_frame(J, s)
    parts = [
        RoundCone(S + out * 0.02, E, 0.066 * b, 0.050 * b),                                      # upper arm
        Ellipsoid(lerp(S, E, 0.42) + out * 0.008, (0.060 * b, 0.056 * b, 0.10), frame_from(ua, out)),
        Sphere(E, 0.054 * b),                                                                   # elbow
        RoundCone(E, W - fa * 0.012, 0.062 * b, 0.048 * b),                                      # forearm
        Ellipsoid(lerp(E, W, 0.36), (0.076 * b, 0.066 * b, 0.11), frame_from(fa, v)),           # forearm mass
        Ellipsoid(W, (0.030 * b, 0.040 * b, 0.032), np.stack([w, v, u], 1)),                     # wrist
    ]
    return Union(parts, k=0.03)


HAND_P = BodyParams(hand_w=1.25, hand_t=1.45, finger_r=1.55, wrist_scale=1.3)


def hand(J, s, P):
    W = J.side("wrist", s)
    return Warp(hand_shapes(J, s, HAND_P), W, (P.hand_scale,) * 3)


def finger_tips(J, s, P):
    """(tip, direction) of the five fingers, scaled with the hand about the wrist."""
    W = J.side("wrist", s)
    out = []
    tips = {"index": 0.019, "middle": 0.020, "ring": 0.019, "pinky": 0.016}
    for name, ch in FINGERS:
        b, c = J.side(ch[-2], s), J.side(ch[-1], s)
        d = nrm(c - b)
        out.append((W + (c + d * tips[name] - W) * P.hand_scale, d))
    tb, tc = J.side(THUMB[-2], s), J.side(THUMB[-1], s)
    d = nrm(tc - tb)
    out.append((W + (tc + d * 0.021 - W) * P.hand_scale, d))
    return out


def claws_hand(J, s, P):
    u, v, w = hand_frame(J, s)
    cl = []
    for tip, d in finger_tips(J, s, P):
        a = tip - d * 0.004
        bpt = tip + d * 0.026 + w * 0.010
        cl.append(RoundCone(a, bpt, 0.0085, 0.0016))
    return Union(cl, k=0.004)


def leg(J, s, P):
    b = P.bulk * P.leg
    H, Kn, A = J.side("upper_leg", s), J.side("knee", s), J.side("ankle", s)
    out = s * np.array([1.0, 0, 0])
    th = nrm(Kn - H)
    return Union([
        RoundCone(H + v3(0, 0.005, -0.02), Kn, 0.088 * b, 0.058 * b),                          # thigh
        Ellipsoid(lerp(H, Kn, 0.36) + out * 0.008, (0.080 * b, 0.082 * b, 0.16), frame_from(th, out)),
        Sphere(Kn, 0.057 * b),                                                                 # knee
        RoundCone(Kn, A, 0.058 * b, 0.044 * b),                                                # shin
        Ellipsoid(lerp(Kn, A, 0.30) + v3(0, 0.022, 0), (0.056 * b, 0.058 * b, 0.11), frame_from(nrm(A - Kn), out)),
        Sphere(A, 0.050 * b ** 0.5),                                                           # ankle
    ], k=0.03)


SOLE_Z = 0.008


def toe_dirs(s, P):
    angs = [-30.0, -10.0, 8.0, 26.0]               # degrees from straight ahead; positive = outward
    offs = [-0.040, -0.014, 0.012, 0.038]
    lens = [0.088, 0.112, 0.118, 0.098]
    out = []
    for a, o, L in zip(angs, offs, lens):
        r = math.radians(a)
        d = v3(s * math.sin(r), -math.cos(r), -0.06)
        out.append((o * s, nrm(d), L * P.toe_len))
    return out


def foot(J, s, P):
    """Plantigrade: the heel where the human heel is (back of the heel about y = +0.12), the ball under the human
    ball, four splayed toes; foot length heel to claw tips = P.foot_len."""
    A, Hl, B = J.side("ankle", s), J.side("heel", s), J.side("ball", s)
    x = A[0] + s * 0.004
    heel_back = 0.118
    front = heel_back - P.foot_len                  # claw tips
    ball_y = B[1] - 0.012
    parts = [
        Sphere(v3(x, heel_back - 0.048, 0.050), 0.050),                                        # heel
        Ellipsoid(v3(x, (heel_back + ball_y) * 0.5 - 0.01, 0.050), (0.060, 0.098, 0.048)),     # foot body
        Ellipsoid(v3(x, ball_y, 0.034), (0.070, 0.052, 0.034)),                               # ball pad
        RoundCone(A, v3(x, A[1] - 0.03, 0.06), 0.052, 0.056),
    ]
    claws = []
    for o, d, L in toe_dirs(s, P):
        base = v3(x + o, ball_y - 0.030, 0.030)
        tip = base + d * L
        parts.append(RoundCone(base, tip, 0.024, 0.0155))
        parts.append(Sphere(lerp(base, tip, 0.55) + v3(0, 0, 0.004), 0.019))                    # knuckle
        cb = tip + d * 0.010 + v3(0, 0, -0.001)
        ce = tip + d * 0.040 + v3(0, 0, -0.016)
        claws.append(RoundCone(cb, ce, 0.0105, 0.0018))
    body = Union(parts, k=0.022)
    # scale the toes so the claw tips reach `front`
    f = Union([body, Union(claws, k=0.004)], k=0.006)
    return Inter(f, Plane((0, 0, -1), (0, 0, SOLE_Z)), k=0.003)


def tail(J, P):
    pts = tail_points(P)
    C, t = _smooth_curve(pts, 34)
    segs = []
    for i in range(len(C) - 1):
        r0 = P.tail_root_r * (1 - t[i]) ** 1.05 + P.tail_tip_r * t[i]
        r1 = P.tail_root_r * (1 - t[i + 1]) ** 1.05 + P.tail_tip_r * t[i + 1]
        f0 = 1.0 + (P.tail_flat - 1.0) * min(1.0, t[i] * 2.0)
        f1 = 1.0 + (P.tail_flat - 1.0) * min(1.0, t[i + 1] * 2.0)
        segs.append(ECapsule(C[i], C[i + 1], (r0, r1), (r0 * f0, r1 * f1), side=(1, 0, 0), n=2.0))
    return Union(segs, k=0.02), (C, t)


# ===========================================================================
# Scutes (geometry that must survive the 64 px silhouette)
# ===========================================================================
def _spike(base, up, back, h, r, lean=0.55, flat=None):
    """A conical scute spike; `flat` (a direction) flattens it into a blade across that direction."""
    tip = base + nrm(up + back * lean) * h
    cone = RoundCone(base - up * 0.006, tip, r, r * 0.12)
    if flat is None:
        return cone
    return Warp(cone, base, (0.45, 1.0, 1.0), frame_from(np.cross(nrm(flat), v3(0, 0, 1)) if abs(nrm(flat)[2]) < 0.9
                                                          else v3(0, 1, 0), flat))


def tail_crest(P, curve):
    C, t = curve
    out = []
    n = 26
    for i in range(1, n):
        u = 0.06 + 0.92 * i / n
        k = int(u * (len(C) - 1))
        p = C[k]
        d = nrm(C[min(k + 1, len(C) - 1)] - C[max(k - 1, 0)])
        up = nrm(np.cross(d, v3(1, 0, 0)) * -1)
        if up[2] < 0:
            up = -up
        r = P.tail_root_r * (1 - u) ** 1.05 + P.tail_tip_r * u
        rn = r * (1.0 + (P.tail_flat - 1.0) * min(1.0, u * 2.0))
        h = P.tail_crest_h * P.scute * (1.15 - 0.55 * u)
        rows = (-1, 1) if u < 0.62 else (0,)
        for side in rows:
            base = p + up * (rn * 0.92) + v3(side * r * 0.42, 0, 0)
            out.append(_spike(base, up, d, h, 0.022 * P.scute ** 0.5 * (1.1 - 0.45 * u), lean=0.7, flat=v3(1, 0, 0)))
    return Union(out, k=0.004)


def dorsal_ridge(J, P, body_node):
    """Two rows of osteoderm spikes from the nape down the back to the tail root, on the surface of the body."""
    from lib.sdf import surface_point
    out = []
    for z in np.arange(1.40, 0.93, -0.046):
        for s in (1, -1):
            x = s * (0.030 + 0.010 * (1.40 - z))
            p = surface_point(body_node, v3(x, 0.45, z), v3(0, -1, 0), 0.0, 0.45)
            up = v3(0, 1, 0.55)
            out.append(_spike(p + v3(0, -0.008, 0), nrm(up), v3(0, 0, -1), P.ridge_h * P.scute * (0.85 + 0.25 * (z < 1.3)),
                              0.020 * P.scute ** 0.5, lean=0.15, flat=v3(1, 0, 0)))
    return Union(out, k=0.004)


def osteoderms(J, P):
    """Shoulder and forearm osteoderm rows (and variant C's shoulder plates)."""
    out = []
    for s in (1, -1):
        S, E, W = J.side("shoulder", s), J.side("elbow", s), J.side("wrist", s)
        cap = v3(s * (P.shoulder_half - 0.080), 0.012, S[2] - 0.012)
        for k, (dx, dy, dz) in enumerate([(0.0, 0.0, 1.0), (0.45, 0.25, 0.85), (0.75, 0.0, 0.6), (0.4, -0.35, 0.85)]):
            n = nrm(v3(s * dx, dy, dz))
            base = cap + n * (0.082 * P.bulk ** 0.8 - 0.006)
            out.append(_spike(base, n, v3(0, 0.3, -0.5), 0.022 * P.scute * (1 + 0.8 * P.shoulder_plates),
                              0.016 * P.scute ** 0.5 * (1 + 0.6 * P.shoulder_plates), lean=0.25))
        out_dir = nrm(v3(s, 0.45, 0.15))
        fa = nrm(W - E)
        for k in range(4):
            c = lerp(E, W, 0.15 + 0.2 * k)
            base = c + out_dir * (0.060 * P.bulk - 0.004 * k)
            out.append(_spike(base, out_dir, fa, 0.018 * P.scute, 0.011 * P.scute ** 0.5, lean=0.4))
        if P.shoulder_plates:
            out.append(Ellipsoid(cap + v3(s * 0.03, 0.0, 0.055), (0.085, 0.075, 0.03),
                                 frame_from(v3(s * 0.4, 0, 1), v3(0, 1, 0))))
    return Union(out, k=0.006)


def shin_scutes(J, P):
    out = []
    for s in (1, -1):
        Kn, A = J.side("knee", s), J.side("ankle", s)
        for k in range(3):
            c = lerp(Kn, A, 0.25 + 0.22 * k)
            n = nrm(v3(s * 0.5, -1, 0))
            out.append(_spike(c + n * 0.055 * P.bulk, n, v3(0, 0, -1), 0.012 * P.scute, 0.012, lean=0.5))
    return Union(out, k=0.004)


# ===========================================================================
# Separate parts: eyes, teeth, crest
# ===========================================================================
def eyes(J, P):
    return Union([Sphere(eyeball_center(J, s), P.eye_r) for s in (1, -1)], 0)


def teeth(J, P):
    """One row mesh: upper teeth hang over the lower jaw outside the lips, lower teeth stand up outside the upper
    snout (the crocodile's closed-mouth grin)."""
    tip = snout_tip(J, P)
    out = []
    z0 = 1.4655
    n_up = 13
    for s in (1, -1):
        for i in range(n_up):
            u = (i + 0.5) / n_up
            y = lerp(-0.035, tip[1] + 0.035, u)
            w = lerp(P.snout_w * 0.93, P.snout_tip_w * 0.98, u)
            big = 1.6 if i in (3, 10) else 1.0
            L = (0.013 + 0.006 * math.sin(u * math.pi)) * big * P.teeth
            base = v3(s * w, y, z0 + 0.006)
            out.append(RoundCone(base, base + v3(s * 0.003, 0, -L), 0.0042 * big ** 0.5, 0.0009))
        for i in range(10):
            u = (i + 0.7) / 10.5
            y = lerp(-0.02, tip[1] + 0.045, u)
            w = lerp(P.snout_w * 0.9, P.snout_tip_w * 0.88, u)
            big = 1.7 if i in (2, 8) else 0.9
            L = 0.011 * big * P.teeth
            base = v3(s * w, y + 0.008, z0 - 0.006)
            out.append(RoundCone(base, base + v3(s * 0.002, 0, L), 0.0040 * big ** 0.5, 0.0009))
    return Union(out, k=0.0)


def crest(J, P, head_node):
    """Crest style for the variant: 'mane' (quill mane, the default), 'row' (short quill row), 'none'."""
    from lib.sdf import surface_point
    rng = np.random.RandomState(7)
    out = []
    if P.crest == "none":
        return None
    if P.crest == "row":
        for k, (y, z) in enumerate([(-0.04, 1.565), (0.0, 1.565), (0.04, 1.555), (0.075, 1.53), (0.10, 1.49),
                                    (0.11, 1.44), (0.11, 1.39)]):
            p = surface_point(head_node, v3(0, y, z + 0.2), v3(0, 0, -1), 0.0, 0.3)
            out.append(_spike(p, v3(0, 0.4, 1), v3(0, 1, 0), 0.028 - 0.002 * k, 0.010, lean=0.4))
        return Union(out, k=0.003)
    # quill mane: rows of long quills over the skull and down the nape, swept back
    for row, (z, y0, nq, L) in enumerate([(1.575, -0.03, 4, 0.14), (1.565, 0.02, 5, 0.19), (1.540, 0.065, 6, 0.23),
                                          (1.495, 0.095, 7, 0.24), (1.44, 0.11, 7, 0.23), (1.38, 0.12, 6, 0.20),
                                          (1.32, 0.13, 4, 0.17)]):
        for q in range(nq):
            xs = (q - (nq - 1) / 2) / max(1, (nq - 1) / 2)
            x = xs * (0.060 if row < 3 else 0.075)
            p = surface_point(head_node, v3(x, y0 + 0.25, z), v3(0, -1, 0), 0.0, 0.4) if row >= 2 else \
                surface_point(head_node, v3(x, y0, z + 0.25), v3(0, 0, -1), 0.0, 0.4)
            back = v3(xs * 0.55, 1.0, 0.25 - 0.18 * row)
            L2 = L * (0.85 + 0.3 * rng.rand()) * (1 - 0.25 * abs(xs))
            d = nrm(back + rng.randn(3) * 0.08)
            mid = p + d * L2 * 0.5 + v3(0, 0, 0.012 if row < 3 else -0.01)
            end = p + d * L2 + v3(0, 0, -0.03 * row / 6)
            r0 = 0.0150 if row < 5 else 0.0130
            out.append(RoundCone(p - d * 0.006, mid, r0, r0 * 0.6))
            out.append(RoundCone(mid, end, r0 * 0.6, 0.0020))
    # two beaded quill ropes down the back
    for s in (1, -1):
        a = v3(s * 0.05, 0.12, 1.43)
        pts = [a + v3(s * 0.01 * k, 0.02 + 0.006 * k, -0.045 * k) for k in range(7)]
        for i in range(6):
            out.append(RoundCone(pts[i], pts[i + 1], 0.007, 0.0065))
        for i in (2, 4, 6):
            out.append(Sphere(pts[i], 0.013))
    return Union(out, k=0.002)


# ===========================================================================
def groups(J, P):
    """Region nodes of the body (weights by region) and the separate parts."""
    g = {"torso": torso(J, P), "neck": neck(J, P), "head": skull(J, P), "jaw": lower_jaw(J, P)}
    for s, sd in ((1, "l"), (-1, "r")):
        g["arm_" + sd] = arm(J, s, P)
        g["hand_" + sd] = Union([hand(J, s, P), claws_hand(J, s, P)], k=0.004)
        g["leg_" + sd] = leg(J, s, P)
        g["foot_" + sd] = foot(J, s, P)
    g["tail"], curve = tail(J, P)
    return g, curve


def body_node(g, J, P, curve, with_scutes=True):
    head = Sub(Union([g["head"], g["jaw"]], k=0.012), mouth_slit(J, P), k=0.002)
    center = Union([g["torso"], Union([g["neck"], head], k=0.035), g["tail"]], k=0.05)
    limbs = {}
    for sd in "lr":
        limbs[sd] = Union([Union([g["arm_" + sd], g["hand_" + sd]], k=0.015),
                           Union([g["leg_" + sd], g["foot_" + sd]], k=0.025)], k=0)
    body = SymUnion(center, limbs["l"], limbs["r"], k=0.04)
    if not with_scutes:
        return body
    sc = Union([dorsal_ridge(J, P, body), osteoderms(J, P), tail_crest(P, curve)], k=0)
    return Union([body, sc], k=0.008)


def build_nodes(J, P):
    g, curve = groups(J, P)
    body = body_node(g, J, P, curve)
    head_only = Union([g["head"], g["neck"]], k=0.03)
    return {"groups": g, "body": body, "eyes": eyes(J, P), "teeth": teeth(J, P), "crest": crest(J, P, head_only),
            "curve": curve}
