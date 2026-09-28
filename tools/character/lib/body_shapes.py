"""Body shape: SDF parts of the torso, neck, head, arms, hands, legs and feet around the
Actor_B joints at the bind pose null-add, parameterized by BodyParams.

Split out of tools/character/build_body.py (lib v1). BodyParams() (the default) is the
original female body of actor_b_body.glb: every expression below is the one of
build_body.py with its constants taken from the params, so the default reproduces the
old shapes exactly. BodyParams.male() is the male fit of the `sex` shape key (design
§3.2): same skeleton, proportions changed in the mesh only (broader deltoids, chest and
waist, narrower hips, thicker neck, hands +8 % girth, heavier jaw and brow). Face
features (FACE_FEATURES) are small per-feature changes of the head used for the face_*
shape keys; the cranium never changes, so hats and hair caps fit every face.

All positions are Blender armature space (z up, the character faces -y).
"""

import math

import numpy as np

from .sdf import (Ellipsoid, Inter, Plane, RoundBox, RoundCone, Sphere, Sub, SymUnion, Union, frame_from, lerp,
                  mirror_x, nrm, sdf_normal, smoothstep, surface_point, v3)


class BodyParams:
    """Shape constants. Defaults = the original (female) body."""
    DEFAULTS = {
        # arms
        "deltoid_out": 0.007, "deltoid_r": 0.042, "upper_arm_r0": 0.040, "upper_arm_r1": 0.031,
        "biceps_r": 0.034, "biceps_r2": 0.033, "elbow_r": 0.031, "forearm_r0": 0.033, "forearm_r1": 0.022,
        "forearm_m0": 0.036, "forearm_m1": 0.030, "wrist_scale": 1.0,
        # hands
        "hand_w": 1.0, "hand_t": 1.0, "finger_r": 1.0,
        # legs
        "thigh_r0": 0.079, "thigh_r1": 0.050, "thigh_in": 0.0, "thigh_mass_out": 0.004, "thigh_mass_r": 0.074,
        "knee_r": 0.047, "shin_r0": 0.046, "calf_r": 0.042, "calf_r2": 0.043,
        # torso
        "hip_w": 0.062, "hip_d": 0.100, "waist_w": 0.117, "waist_d": 0.084, "waist_h": 0.10, "torso_k": 0.0, "rib_w": 0.127, "rib_d": 0.092,
        "girdle_w": 0.017, "girdle_d": 0.077, "butt_in": 0.032, "butt_r": 0.070, "trap_r0": 0.041, "trap_r1": 0.036,
        "breast_r": 0.046, "pec": (0.0, 0.0, 0.0), "pec_c": (0.060, -0.040, -0.028),
        # neck
        "neck_r0": 0.049, "neck_r1": 0.041,
        # head (the cranium is fixed)
        "jaw_w": 0.058, "jaw_d": 0.062, "jaw_h": 0.058, "jaw_c": (0.0, -0.052, -0.014),
        "jaw_bar_r": 0.0, "jaw_bar": ((0.046, -0.030, -0.040), (0.018, -0.094, -0.056)),
        "chin_r": 0.018, "chin_off": (0.0, 0.007, 0.008),
        "nose_r0": 0.0075, "nose_r1": 0.0105, "nose_len": 0.0, "nose_bridge": 0.0, "nostril_w": 0.0155,
        "mouth": (0.020, 0.009, 0.011), "brow": (0.050, 0.012, 0.010), "brow_off": (0.0, 0.010, 0.004),
        "cheek_x": 0.046, "cheek_r": 0.022, "cheek_off": (0.0, 0.009, -0.004), "ear_scale": 1.0,
        # head model: 1 = the v1 head above (legacy actor_b_body.glb, exactly), 2 = lib/face.py
        # (the customizer's anatomical head) with the face params `face` (face.FACE_BASE keys)
        "head_model": 1, "face": None,
    }

    def __init__(self, **kw):
        self.__dict__.update(self.DEFAULTS)
        for k, v in kw.items():
            if k not in self.DEFAULTS:
                raise KeyError("unknown body param %s" % k)
            self.__dict__[k] = v

    def copy(self, **kw):
        d = {k: getattr(self, k) for k in self.DEFAULTS}
        if isinstance(d.get("face"), dict):
            d["face"] = dict(d["face"])
        d.update(kw)
        return BodyParams(**d)

    def to_dict(self):
        return {k: getattr(self, k) for k in self.DEFAULTS}

    @staticmethod
    def female():
        """The customizer's female base: the legacy body with the v2 head (lib/face.py)."""
        from . import face as FC
        return BodyParams(head_model=2, face=FC.params())

    @staticmethod
    def male():
        """Male fit (design §3.2 targets, skeleton space): bideltoid +2 cm per side, hips
        -1.5 cm per side, waist 0.25 m, chest 0.33 x 0.21 m with a flat pectoral plate and no
        bust, neck 0.115 m wide, hands +8 % girth, jaw +6 mm per side, brow ridge +3 mm,
        chin and nose a little larger. The joints do not move."""
        return BodyParams(
            deltoid_out=0.013, deltoid_r=0.049, upper_arm_r0=0.045, upper_arm_r1=0.034, biceps_r=0.039,
            biceps_r2=0.037, elbow_r=0.033, forearm_r0=0.036, forearm_r1=0.024, forearm_m0=0.040, forearm_m1=0.033,
            wrist_scale=1.08, hand_w=1.05, hand_t=1.08, finger_r=1.08,
            thigh_r0=0.072, thigh_in=0.006, thigh_mass_out=0.0, thigh_mass_r=0.071, knee_r=0.049, shin_r0=0.048,
            calf_r=0.044, calf_r2=0.045,
            hip_w=0.050, hip_d=0.097, waist_w=0.124, waist_d=0.092, waist_h=0.125, torso_k=0.065, rib_w=0.141,
            rib_d=0.100, girdle_w=0.030,
            girdle_d=0.083, butt_in=0.036, butt_r=0.063, trap_r0=0.048, trap_r1=0.043,
            breast_r=0.0, pec=(0.062, 0.024, 0.044),
            neck_r0=0.059, neck_r1=0.050,
            jaw_w=0.060, jaw_bar_r=0.008, chin_r=0.020, chin_off=(0.0, 0.006, 0.006),
            nose_r0=0.0081, nose_r1=0.0113, nose_len=0.002, nostril_w=0.0167,
            mouth=(0.020, 0.008, 0.010), brow=(0.052, 0.014, 0.011), brow_off=(0.0, 0.007, 0.004),
            cheek_x=0.047, ear_scale=1.05, head_model=2, face=_male_face(),
        )


def _male_face():
    from . import face as FC
    return FC.male(FC.params())


# v1 face features (legacy head, unused by the v2 body: see lib/face.py FACE_FEATURES).
# Face features for the face_* shape keys: param changes from the base (female) head.
# Each key is the base head projected onto the head with that one change (a few mm);
# face presets are weight vectors over them (weights may be negative, -1 .. 1).
FACE_FEATURES = {
    "face_jaw_wide": {"jaw_w": +0.004, "jaw_bar_r": 0.007},
    "face_chin": {"chin_r": +0.004, "chin_off": (0.0, -0.004, -0.004)},
    "face_long": {"jaw_h": +0.008, "chin_off": (0.0, 0.0, -0.007)},
    "face_cheekbones": {"cheek_r": +0.004, "cheek_x": +0.003, "cheek_off": (0.0, -0.002, 0.003)},
    "face_nose_wide": {"nose_r1": +0.0025, "nostril_w": +0.004},
    "face_nose_long": {"nose_len": +0.005},
    "face_nose_bridge": {"nose_bridge": +0.003, "nose_r0": +0.001},
    "face_lips_full": {"mouth": (0.001, 0.003, 0.003)},
    "face_brow": {"brow": (0.0, 0.003, 0.001), "brow_off": (0.0, -0.003, 0.0)},
    "face_round": {"jaw_d": +0.005, "cheek_r": +0.003, "jaw_w": +0.003},
}


def face_params(base, feature, amount=1.0):
    """`base` BodyParams with the face feature added (`amount` times): lib/face.py
    FACE_FEATURES for the v2 head, FACE_FEATURES above for the v1 head."""
    if base.head_model == 2:
        from . import face as FC
        return base.copy(face=FC.add(base.face, FC.FACE_FEATURES[feature], amount))
    kw = {}
    for k, dv in FACE_FEATURES[feature].items():
        v = getattr(base, k)
        if k == "jaw_bar_r":
            kw[k] = max(v, dv * amount)      # a feature that switches the jawline bar on
        elif isinstance(v, tuple):
            kw[k] = tuple(a + b * amount for a, b in zip(v, dv))
        else:
            kw[k] = v + dv * amount
    return base.copy(**kw)


FINGERS = [("index", ["index_metacarpal", "indexa", "indexb", "indexc"]),
           ("middle", ["middle_metacarpal", "middlea", "middleb", "middlec"]),
           ("ring", ["ring_metacarpal", "ringa", "ringb", "ringc"]),
           ("pinky", ["pinkya", "pinkyb", "pinkyc", "pinkyd"])]
THUMB = ["thumba", "thumbb", "thumbc"]
_F = BodyParams()


def hand_frame(K, s):
    """Columns: u (wrist -> knuckles), v (across, toward index), w (palm normal, palm side)."""
    W = K.side("wrist", s)
    u = nrm(K.side("middlea", s) - W)
    across = K.side("indexa", s) - K.side("pinkyb", s)
    w = nrm(np.cross(u, across)) * (1 if s > 0 else -1)
    v = np.cross(w, u)
    return u, v, w


def arm_shapes(K, s, P=_F):
    S, E, W = K.side("shoulder", s), K.side("elbow", s), K.side("wrist", s)
    out = s * np.array([1.0, 0, 0])
    ua = nrm(E - S)
    fa = nrm(W - E)
    u, v, w = hand_frame(K, s)
    ws = P.wrist_scale
    parts = [
        Sphere(S + out * P.deltoid_out + v3(0, 0.002, 0.004), P.deltoid_r),                 # deltoid cap
        RoundCone(S, E, P.upper_arm_r0, P.upper_arm_r1),                                    # upper arm
        Ellipsoid(lerp(S, E, 0.48) + v3(0, -0.006, 0), (P.biceps_r, P.biceps_r2, 0.085),
                  frame_from(ua, out)),                                                     # biceps/triceps
        Sphere(E, P.elbow_r),                                                               # elbow
        RoundCone(E, W - fa * 0.01, P.forearm_r0, P.forearm_r1),                            # forearm
        Ellipsoid(lerp(E, W, 0.27), (P.forearm_m0, P.forearm_m1, 0.075), frame_from(fa, v)),  # forearm muscles
        Ellipsoid(W, (0.018 * ws, 0.026 * ws, 0.022 * ws), np.stack([w, v, u], 1)),        # wrist (flat)
    ]
    return Union(parts, k=0.02)


def hand_shapes(K, s, P=_F):
    W, Pm = K.side("wrist", s), K.side("palm", s)
    u, v, w = hand_frame(K, s)
    knuck = [K.side(ch[1], s) for _, ch in FINGERS]
    kmid = np.mean(knuck, 0)
    L = np.linalg.norm(kmid - W)
    R = np.stack([u, v, w], 1)
    palm = RoundBox(W + u * (0.52 * L) + w * 0.002, (0.52 * L, 0.035 * P.hand_w, 0.0125 * P.hand_t), 0.011 * P.hand_t, R)
    fingers = []
    fr = P.finger_r
    radii = {"index": (0.0088, 0.008, 0.0074), "middle": (0.009, 0.0082, 0.0076),
             "ring": (0.0086, 0.0079, 0.0073), "pinky": (0.0078, 0.0072, 0.0066)}
    tips = {"index": 0.019, "middle": 0.020, "ring": 0.019, "pinky": 0.016}
    for name, ch in FINGERS:
        a, b, c = [K.side(n, s) for n in ch[1:]]
        tip = c + nrm(c - b) * tips[name]
        r0, r1, r2 = radii[name]
        r0, r1, r2 = r0 * fr, r1 * fr, r2 * fr
        fingers += [RoundCone(a, b, r0, r1), RoundCone(b, c, r1, r2), RoundCone(c, tip, r2, r2 * 0.92)]
    mitten = Union(fingers, k=0.016)
    ta, tb, tc = [K.side(n, s) for n in THUMB]
    ttip = tc + nrm(tc - tb) * 0.021
    thumb = Union([Ellipsoid(lerp(ta, tb, 0.45) + w * 0.004, (0.016 * fr, 0.013 * fr, 0.024),
                             frame_from(tb - ta, w)),                           # thenar
                   RoundCone(ta, tb, 0.0125 * fr, 0.0105 * fr), RoundCone(tb, tc, 0.0105 * fr, 0.0092 * fr),
                   RoundCone(tc, ttip, 0.0092 * fr, 0.0082 * fr)], k=0.008)
    return Union([palm, mitten, thumb], k=0.012)


def leg_shapes(K, s, P=_F):
    H, Kn, A = K.side("upper_leg", s), K.side("knee", s), K.side("ankle", s)
    out = s * np.array([1.0, 0, 0])
    th = nrm(Kn - H)
    parts = [
        RoundCone(H + v3(0, 0, -0.025) - out * P.thigh_in, Kn, P.thigh_r0, P.thigh_r1),        # thigh
        Ellipsoid(lerp(H, Kn, 0.38) + v3(0, -0.010, 0) + out * P.thigh_mass_out,
                  (P.thigh_mass_r, P.thigh_mass_r, 0.15), frame_from(th, out)),               # thigh mass
        Sphere(Kn + v3(0, -0.004, 0), P.knee_r),                                               # knee
        Sphere(Kn + v3(0, -0.036, 0.004), 0.021),                                              # kneecap
        RoundCone(Kn, A, P.shin_r0, 0.029),                                                    # shin
        Ellipsoid(lerp(Kn, A, 0.30) + v3(0, 0.018, 0), (P.calf_r, P.calf_r2, 0.09),
                  frame_from(nrm(A - Kn), out)),                                               # calf
        Sphere(A, 0.030),                                                                      # ankle
    ]
    return Union(parts, k=0.025)


SOLE_Z = 0.008   # bare sole height (the shoe sole reaches z = 0)


def foot_shapes(K, s, P=_F):
    A, Hl, B = K.side("ankle", s), K.side("heel", s), K.side("ball", s)
    x = A[0]
    ins = -s * 0.004        # big-toe side is toward the body
    parts = [
        Sphere(v3(x, Hl[1] - 0.030, 0.040), 0.035),                            # heel
        Ellipsoid(v3(x + ins * 0.5, (Hl[1] + B[1]) * 0.5 - 0.018, 0.036), (0.037, 0.068, 0.033)),
        Ellipsoid(v3(x + ins, B[1] - 0.006, 0.026), (0.043, 0.034, 0.024)),     # ball
        Ellipsoid(v3(x + ins, B[1] - 0.044, 0.020), (0.039, 0.028, 0.016)),     # toes
        RoundCone(A, v3(x, A[1] - 0.02, 0.05), 0.031, 0.034),
    ]
    foot = Union(parts, k=0.022)
    return Inter(foot, Plane((0, 0, -1), (0, 0, SOLE_Z)), k=0.004)


def torso_shapes(K, smooth=False, P=_F):
    hl, hr = K["l_upper_leg"], mirror_x(K["l_upper_leg"])
    hc = (hl + hr) * 0.5
    sa, sb, sc, sd = K["spinea"], K["spineb"], K["spinec"], K["spined"]
    nk = K["neck"]
    S = K["l_shoulder"]
    k = 0.07 if smooth else 0.05
    if P.torso_k > 0:
        k = max(k, P.torso_k)
    center = Union([
        Ellipsoid(hc + v3(0, 0.005, 0.025), (hl[0] + P.hip_w, P.hip_d, 0.100)),                     # hips
        Ellipsoid(v3(0, sb[1] + 0.025, sb[2] - 0.012), (P.waist_w, P.waist_d, P.waist_h)),               # waist
        Ellipsoid(v3(0, sc[1] + 0.024, (sc[2] + sd[2]) * 0.5 + 0.022), (P.rib_w, P.rib_d, 0.135)),  # ribcage
        Ellipsoid(v3(0, S[1] - 0.017, S[2] - 0.035), (S[0] + P.girdle_w, P.girdle_d, 0.065)),       # shoulder girdle
    ], k=k)

    def side(s):
        return Union([Sphere(v3(s * (hl[0] - P.butt_in), hc[1] + 0.047, hc[2] - 0.005), P.butt_r),   # buttocks
                      RoundCone(v3(s * 0.035, nk[1] + 0.02, nk[2] + 0.001),
                                v3(s * (S[0] - 0.025), S[1], S[2] + 0.010), P.trap_r0, P.trap_r1)], k=0)  # trapezius
    torso = SymUnion(center, side(1), side(-1), k)
    if P.breast_r > 0:
        br = [Sphere(v3(s * 0.073, sd[1] - 0.047, sd[2] - 0.026), P.breast_r) for s in (1, -1)]
        return SymUnion(torso, br[0], br[1], k=0.05 if smooth else 0.028)
    if P.pec[0] > 0:
        # flat pectoral plates over the ribcage (male fit)
        cx, cy, cz = P.pec_c
        pe = [Ellipsoid(v3(s * cx, sd[1] + cy, sd[2] + cz), P.pec, frame_from(v3(0, 0.25, 1), v3(s, 0, 0)))
              for s in (1, -1)]
        return SymUnion(torso, pe[0], pe[1], k=0.05 if smooth else 0.03)
    return torso


def neck_shape(K, P=_F):
    nk, ha = K["neck"], K["heada"]
    return RoundCone(v3(0, nk[1] + 0.010, nk[2] - 0.035), v3(0, ha[1] + 0.008, ha[2] + 0.040), P.neck_r0, P.neck_r1)


def head_shapes(K, P=_F):
    if P.head_model == 2:
        from . import face as FC
        return FC.head_node(K, P.face)
    return head_shapes_v1(K, P)


def head_shapes_v1(K, P=_F):
    hb = K["headb"]
    nose_b, nose_t = K["upper_nose_bridge"], K["nose_tip"]
    chin = K["lower_mid_chin"]
    lips = (K["lip_upper_center"] + K["lip_lower_center"]) * 0.5
    nd = nrm(nose_t - nose_b)
    tip = nose_t + nd * P.nose_len
    center = [
        Ellipsoid(hb + v3(0, -0.027, 0.061), (0.074, 0.098, 0.092)),                            # cranium
        Ellipsoid(hb + v3(*P.jaw_c), (P.jaw_w, P.jaw_d, P.jaw_h)),                               # lower face / jaw
        Sphere(chin + v3(*P.chin_off), P.chin_r),                                                # chin
        RoundCone(nose_b + v3(0, 0.001 - P.nose_bridge, 0.004), tip + v3(0, 0.002, 0.004), P.nose_r0, P.nose_r1),
        Ellipsoid(tip + v3(0, 0.008, -0.004), (P.nostril_w, 0.010, 0.009)),                      # nostril wings
        Ellipsoid(lips + v3(0, 0.004, 0), P.mouth),                                              # mouth
        Ellipsoid(K["brow_mid"] + v3(*P.brow_off), P.brow),                                      # brow ridge
    ]
    uc = K["l_upper_cheek"]
    co = P.cheek_off
    cheeks = [Sphere(v3(s * P.cheek_x, uc[1] + co[1], uc[2] + co[2]), P.cheek_r) for s in (1, -1)]  # cheekbones
    head = SymUnion(Union(center, k=0.018), cheeks[0], cheeks[1], k=0.018)
    if P.jaw_bar_r > 0:
        (ax, ay, az), (bx, by, bz) = P.jaw_bar
        jb = [RoundCone(v3(s * ax, hb[1] + ay, hb[2] + az), v3(s * bx, hb[1] + by, hb[2] + bz), P.jaw_bar_r,
                        P.jaw_bar_r * 0.8) for s in (1, -1)]                                  # jawline
        head = SymUnion(head, jb[0], jb[1], k=0.025)
    es = P.ear_scale
    ears = [Ellipsoid(v3(s * 0.0705, hb[1] + 0.004, hb[2] + 0.018), (0.0095 * es, 0.016 * es, 0.026 * es),
                      frame_from(v3(0, 0.15, 1), v3(s, 0, 0))) for s in (1, -1)]
    head = SymUnion(head, ears[0], ears[1], k=0.006)
    sockets = Union([Sphere(eye_center(K, s) + v3(0, -0.0145, 0), 0.0142) for s in (1, -1)], 0)
    return Sub(head, sockets, k=0.005)


def eye_center(K, s):
    """v1 eye centre (legacy body); the v2 head uses lib/face.eye_center."""
    e = K["l_eyeball"]
    return v3(s * e[0], e[1] - 0.002, e[2])


EYE_R = 0.0125


def body_groups(K, P=_F):
    """Region nodes (used for the shape and for weight regions)."""
    g = {"torso": torso_shapes(K, P=P), "neck": neck_shape(K, P), "head": head_shapes(K, P)}
    for s, sd in ((1, "l"), (-1, "r")):
        g["arm_" + sd] = arm_shapes(K, s, P)
        g["hand_" + sd] = hand_shapes(K, s, P)
        g["leg_" + sd] = leg_shapes(K, s, P)
        g["foot_" + sd] = foot_shapes(K, s, P)
    return g


def limbs(g, s):
    return Union([Union([g["arm_" + s], g["hand_" + s]], k=0.012),
                  Union([g["leg_" + s], g["foot_" + s]], k=0.02)], k=0)


def body_node(g):
    center = Union([g["torso"], Union([g["neck"], g["head"]], k=0.03)], k=0.035)
    return SymUnion(center, limbs(g, "l"), limbs(g, "r"), k=0.035)


def forearm_t(K, s):
    E, W = K.side("elbow", s), K.side("wrist", s)
    L = np.linalg.norm(W - E)
    fa = (W - E) / L

    def t(X, Y, Z):
        return ((X - E[0]) * fa[0] + (Y - E[1]) * fa[1] + (Z - E[2]) * fa[2]) / L
    return t, E, fa, L


def forearm_param(V, K, s):
    """(t along elbow -> wrist, distance to that axis) for side s."""
    E, Wr = K.side("elbow", s), K.side("wrist", s)
    ab = Wr - E
    t = ((V - E) @ ab) / (ab @ ab)
    d = np.linalg.norm(V - (E + t[:, None] * ab), axis=1)
    return t, d


def segment_param(V, a, b):
    """(t along a -> b (0 at a, 1 at b), distance to the a-b line)."""
    ab = b - a
    t = ((V - a) @ ab) / (ab @ ab)
    d = np.linalg.norm(V - (a + t[:, None] * ab), axis=1)
    return t, d


def brows_node(K, head, thick=1.0):
    """Brow strips laid on the skin: points along the brow line are projected
    onto the head surface and joined with small round cones."""
    out = []
    for s in (1, -1):
        bi = K["l_brow_inner"] * v3(s, 1, 1) + v3(0, 0, 0.007)
        bo = K["l_brow_outer"] * v3(s, 1, 1) + v3(s * 0.006, 0, 0.001)
        pts, radii = [], []
        for t in np.linspace(0, 1, 5):
            q = lerp(bi, bo, t) + v3(0, 0, 0.004 * math.sin(math.pi * t))
            p = surface_point(head, q + v3(0, -0.06, 0), v3(0, 1, 0), 0.0, 0.1)
            n = sdf_normal(head, p)
            pts.append(p + n * 0.0012)
            radii.append((0.0034 - 0.0014 * t) * thick)
        segs = [RoundCone(pts[i], pts[i + 1], radii[i], radii[i + 1]) for i in range(4)]
        out.append(Union(segs, k=0.002))
    return Union(out, k=0)


def body_sizing(K, max_edge=None):
    """Target edge length over the body: fine on the face and hands (visible),
    medium on neck/joints, coarse under the clothes. `max_edge` caps it everywhere
    (0.020: the full-skin body, any region of which can be visible)."""
    hands = [K.side("palm", 1), K.side("palm", -1)]
    joints = [K.side(n, s) for n in ("elbow", "knee") for s in (1, -1)]
    hb = K["headb"]

    def fn(P):
        z = P[:, 2]
        head = smoothstep(1.29, 1.35, z)
        L = 0.034 * (1 - head) + 0.015 * head                                                 # body / neck+head
        face = (1 - smoothstep(-0.075, -0.04, P[:, 1] - hb[1])) * smoothstep(1.36, 1.39, z) \
            * (1 - smoothstep(1.52, 1.55, z)) * (1 - smoothstep(0.055, 0.07, np.abs(P[:, 0])))
        ears = (1 - smoothstep(0.02, 0.035, np.linalg.norm((P - v3(0, hb[1], hb[2] + 0.018)) * [0, 1, 1], axis=1))) \
            * smoothstep(0.058, 0.066, np.abs(P[:, 0])) * smoothstep(1.40, 1.42, z)
        m = np.maximum(face, ears)
        L = L + (0.0078 - L) * m                                                               # face ~7.8 mm
        for h in hands:
            L = np.minimum(L, 0.0072 + 0.02 * smoothstep(0.065, 0.11, np.linalg.norm(P - h, axis=1)))
        for j in joints:
            L = np.minimum(L, 0.019 + 0.01 * smoothstep(0.05, 0.10, np.linalg.norm(P - j, axis=1)))
        L = np.minimum(L, 0.017 + 0.012 * smoothstep(0.10, 0.16, z))                          # feet
        if max_edge is not None:
            L = np.minimum(L, max_edge)
        return L
    return fn
