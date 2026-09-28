"""Horse anatomy for the procedural Frontier horse: joints, bones, body and tack shapes.

Blender armature space: metres, z up, the horse faces -y, +x is the horse's (and the
rider's) left. The origin is on the ground directly under the saddle attach point.

Size. A stocky colonial saddle horse of about 14.1 hands (1.45 m at the withers), the
Canadian / Chickasaw / Narragansett type of the 1750s frontier (user decision; see
graph_analysis/melee_horse_prone/horse.md section 2.2). The shapes below are authored on
a 13-hand base (BASE_WITHERS) and stretched by K = (KX, KY, KZ) about the origin: height
x KZ, length x KY (a compact body, shorter than the height scale), width x KX (the barrel
stays about 0.55 m wide so the rider's legs still close round it). Legs, neck, hooves
and quarters are thickened on the base for the stocky type.

Rider fit. The riding clips are expressed relative to a saddle attach point (the clip
origin). Actor_B's seat (breeches underside) sits SEAT_DROP below that point, so the
attach point is put SEAT_DROP above the saddle seat, which sits SADDLE_T above the back.
The clips were authored for a ground 1.37 m under the attach point (mount-clip fit); on
this horse the ground is ATTACH_Z below it, so ground-relative rider clips (mount) need
MOUNT_GROUND_OFFSET. Her inner thighs and calves set the saddle flap envelope (FLAP_W,
attach-relative) and the stirrups hang where her feet are (stirrup_points).
"""

import math

import numpy as np

from sdf import (Bounded, Ellipsoid, Fn, Inter, LoftPath, LoftY, LoftZ, Node, Offset, Onion, RoundCone, Scaled, Sub, Union,
                 smax, smin, smoothstep)

BASE_WITHERS = 1.31        # withers height of the base shapes
WITHERS = 1.45             # 14.1 hands (14 hh = 1.422 m, 14.2 hh = 1.473 m)
KZ = WITHERS / BASE_WITHERS
KY = 1.05
KX = 1.02
K = np.array([KX, KY, KZ])
LEG_THICK = 1.12           # stocky: leg, cannon and joint radii on the base
HOOF_K = 1.12              # larger, sound hooves

# ---------------------------------------------------------------------------
# Proportions (revision 4). A Canadian / Chickasaw / Narragansett horse is short-coupled:
# body length (point of shoulder to point of buttock) about 1.05-1.1 x the height and a
# short head (about 0.4 x the height). The base shapes were authored longer; a smooth warp
# along the body axis (base space, applied before K) moves everything in front of the
# saddle back by WARP_DF and everything behind the loin forward by WARP_DR, compressing the
# region between the chest and the saddle (WARP_F) and the loin (WARP_R). The saddle region
# itself (base y -0.30 .. 0.20: seat, flaps, cloth, girth) does not move, so the tack and the
# rider fit are unchanged. The legs move rigidly with their girdles (LEG_DY). The face is
# shortened about the poll by HEAD_K (hp()).
# ---------------------------------------------------------------------------
WARP_DF = 0.050            # base m: neck, head, shoulder and fore legs moved back
WARP_DR = 0.048            # base m: hindquarters moved forward (short loin)
WARP_F = (-0.72, -0.30)    # base y: compression zone between the chest and the saddle
WARP_R = (0.20, 0.42)      # base y: compression zone of the loin
HEAD_K = 0.84              # face length about the poll (mouth corner about 0.47 m from the poll)


def _ss(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _dss(t):
    t = np.clip(t, 0.0, 1.0)
    return 6.0 * t * (1.0 - t)


def warp_y(y):
    """Body-axis warp of base-space y (monotonic)."""
    y = np.asarray(y, float)
    f = WARP_DF * (1.0 - _ss((y - WARP_F[0]) / (WARP_F[1] - WARP_F[0])))
    r = WARP_DR * _ss((y - WARP_R[0]) / (WARP_R[1] - WARP_R[0]))
    return y + f - r


def _dwarp_y(y):
    y = np.asarray(y, float)
    lf, lr = WARP_F[1] - WARP_F[0], WARP_R[1] - WARP_R[0]
    return 1.0 - WARP_DF * _dss((y - WARP_F[0]) / lf) / lf - WARP_DR * _dss((y - WARP_R[0]) / lr) / lr


def unwarp_y(yw):
    """Inverse of warp_y (Newton, vectorised)."""
    yw = np.asarray(yw, float)
    y = np.array(yw, float, copy=True)
    for _ in range(8):
        y = y - (warp_y(y) - yw) / _dwarp_y(y)
    return y


WARP_MIN_SLOPE = float(np.min(_dwarp_y(np.linspace(-2.0, 2.0, 4001))))


def S(p):
    """Base shape coordinates -> horse space (body warp, then K)."""
    p = np.asarray(p, float)
    return tuple(float(v) for v in np.array([p[0], warp_y(p[1]), p[2]]) * K)


def SL(p):
    """Leg base coordinates (already moved with their girdle, LEG_DY) -> horse space."""
    return tuple(float(v) for v in np.asarray(p, float) * K)


def to_base(P):
    """Horse-space points (..., 3) -> unwarped base shape space (inverse of S)."""
    Bp = np.array(P, float) / K
    Bp[..., 1] = unwarp_y(Bp[..., 1])
    return Bp


BACK_TOP_BASE = 1.18       # top of the back at the saddle (base, y = 0)
SADDLE_T = 0.065           # saddle seat above the back (panel, tree, seat)
SEAT_DROP = 0.125          # Actor_B breeches underside below the clip origin (-0.11..-0.14)
SEAT_Z = BACK_TOP_BASE * KZ + SADDLE_T
ATTACH_Z = SEAT_Z + SEAT_DROP           # saddle attach point above the ground (rider clip origin)
CLIP_GROUND = 1.37                      # ground under the clip origin in the mount-clip fit
MOUNT_GROUND_OFFSET = CLIP_GROUND - ATTACH_Z   # add to ground-relative rider clip heights

# ---------------------------------------------------------------------------
# Joints (left side; the right side mirrors x), base space before the leg shift.
# Hind limb (revision 4), real proportions for a 14.1-hand horse: hip joint 1.06 m, the
# stifle low and forward under the point of hip (0.76 m), the hock 0.49 m and well behind
# the stifle, so that standing square the point of hock and the back of the cannon are
# close to a plumb line from the point of buttock (not camped under); the femur about 22 deg
# from vertical; femur / tibia / cannon 0.32 / 0.40 / 0.34 m.
# ---------------------------------------------------------------------------
J_BASE0 = {
    # fore leg
    "scap_top": (0.10, -0.44, 1.25),
    "shoulder": (0.15, -0.745, 0.94),     # point of shoulder low and forward: long reach
    # the fore leg stands under the front of the chest (revision 4: it stood 0.3 m behind
    # the point of shoulder, with a nearly horizontal upper arm)
    "elbow": (0.16, -0.556, 0.75),
    "carpus": (0.14, -0.586, 0.42),
    "f_fetlock": (0.135, -0.596, 0.135),
    "f_coronet": (0.135, -0.634, 0.052),
    "f_toe": (0.135, -0.696, 0.0),
    # hind leg
    "hip": (0.17, 0.42, 0.9575),
    "stifle": (0.20, 0.306, 0.6865),
    "hock": (0.13, 0.582, 0.4426),
    "h_fetlock": (0.12, 0.553, 0.14),
    "h_coronet": (0.12, 0.525, 0.052),
    "h_toe": (0.12, 0.467, 0.0),
}
FORE_KEYS = ("shoulder", "elbow", "carpus", "f_fetlock", "f_coronet", "f_toe")
HIND_KEYS = ("hip", "stifle", "hock", "h_fetlock", "h_coronet", "h_toe")
# the legs move rigidly with their girdle: the fore leg with the shoulder joint, the hind
# leg with the hip joint
LEG_DY = {"f": float(warp_y(J_BASE0["shoulder"][1]) - J_BASE0["shoulder"][1]),
          "h": float(warp_y(J_BASE0["hip"][1]) - J_BASE0["hip"][1])}


def leg_shift(p, fore):
    """A leg point (base, before the shift) moved with its girdle (base)."""
    return (p[0], p[1] + LEG_DY["f" if fore else "h"], p[2])


# leg joints moved with their girdles (base space; the legs are not warped)
J_BASE = {k: (leg_shift(v, k in FORE_KEYS) if (k in FORE_KEYS or k in HIND_KEYS) else v) for k, v in J_BASE0.items()}
J = {k: (S(v) if k == "scap_top" else SL(J_BASE[k])) for k, v in J_BASE0.items()}


def _hoof_dims(hind):
    kx, ky = KX * HOOF_K, KY * HOOF_K
    toe_fwd = (0.06 if hind else 0.065) * ky
    rt = (0.031 * kx, 0.034 * ky)       # (lateral, fore-aft) radii at the coronet
    rb = (0.041 * kx, 0.047 * ky) if hind else (0.044 * kx, 0.05 * ky)
    return toe_fwd, rt, rb


# the toe joint (hoof bone tail) is the front of the sole, so breakover rolls over it
for _k, _h in (("f", False), ("h", True)):
    _tf, _rt, _rb = _hoof_dims(_h)
    _c = J[_k + "_coronet"]
    J[_k + "_toe"] = (_c[0], _c[1] - 0.5 * _tf - 0.96 * _rb[1], 0.0)

# lumbosacral joint (base): the pelvis turns about it, in front of and above the hip joints
LUMBOSACRAL = (0.0, 0.28, 1.08)
# ---------------------------------------------------------------------------
# Vertebral column (revision 5). The trunk is a chain of vertebral segments on the `body`
# control (the gait's pitch, roll and bob): `chest` (T1-T9, the withers and the front of the
# ribcage, which carries the shoulder blades and the neck), `back` (T10-T18, the saddle),
# `loin` (L1-L3), `loin_2` (L4-L6) and `hips` (sacrum and pelvis, turning about the lumbosacral
# joint), then the tail. Base-space points on the column (the vertebral bodies, about
# 0.2 m under the topline): the thoracic joint behind the withers, the thoracolumbar joint
# (last rib), the middle of the loin and the lumbosacral joint.
# ---------------------------------------------------------------------------
SPINE_T = (0.0, -0.20, 1.00)      # T9/T10: chest | back
SPINE_TL = (0.0, 0.08, 1.012)     # T18/L1: back | loin (under the cantle)
SPINE_L = (0.0, 0.18, 1.035)      # L3/L4: loin | loin_2
# Share of a sagittal flexion of the back (canter, gallop, jump) taken by each joint of the
# column: most of it at the lumbosacral joint, the rest over the back of the loin, so the
# topline bends in a curve instead of kinking at one point. L1-L3 (`loin`) stay stiff: they
# only bend sideways in turns. (A share at the front of the loin swings the pelvis on a long
# lever: between the 120 Hz keys the jump's landing hind hoof drifted 2 mm more, and the
# engine's import key optimizer dropped the keys of so small a rotation, which let the planted
# hind hooves of the canter drift up to 8 mm in the engine; horse.glb.import now turns that
# optimizer off, see README.)
SPINE_FLEX = {"loin": 0.0, "loin_2": 0.4, "hips": 0.6}
# Share of a lateral bend (turning): the chest turns into the turn, the loin and the pelvis
# the other way, so the trunk follows the arc.
SPINE_BEND = {"chest": 1.0, "loin": -0.3, "loin_2": -0.3, "hips": -0.4}
# The shoulder blade is not jointed to the trunk: it is slung from the ribcage by muscle and
# rotates about a point in its upper part (the upper border goes back as the leg reaches
# forward, and rises less than the lower end travels) and glides up the ribcage as the leg
# takes weight (the trunk sinks between the shoulder blades, the thoracic sling).
SCAP_PIVOT = 0.22
SCAP_SLING = 0.015                # m, at full stance load

# Skinning helpers (revision 5): at the big limb joints a helper bone on the proximal bone
# turns `fraction` as far as the distal bone does (against the proximal one). The skin of the
# joint is weighted proximal -> helper -> distal (tools/horse/skinning.py), so it bends in two
# half-steps and linear blend skinning does not collapse it (shoulder, elbow, knee, hip, hock
# and fetlocks). The stifle has none: a stifle helper creased the stifle more than the heat
# weights' own blend (tools/horse/skin_check.py). name -> (proximal bone, distal bone,
# fraction, joint key in J). Posed by gaits.Solver (the clips) and by HorseTerrain (the hills,
# from horse_meta.json "helpers").
def helpers():
    H = {}
    for s in ("l", "r"):
        H["shoulder_" + s] = ("scapula_" + s, "humerus_" + s, 0.5, "shoulder")
        H["elbow_" + s] = ("humerus_" + s, "radius_" + s, 0.5, "elbow")
        H["knee_" + s] = ("radius_" + s, "cannon_" + s, 0.5, "carpus")
        H["fetlock_" + s] = ("cannon_" + s, "pastern_" + s, 0.5, "f_fetlock")
        H["thigh_" + s] = ("hips", "femur_" + s, 0.5, "hip")
        H["hock_" + s] = ("tibia_" + s, "hcannon_" + s, 0.5, "hock")
        H["hfetlock_" + s] = ("hcannon_" + s, "hpastern_" + s, 0.5, "h_fetlock")
    return H


# tail bones (base): the dock leaves the croup at the tail head, above the point of buttock
TAIL_BONES = [(0, 0.675, 1.195), (0, 0.765, 1.105), (0, 0.805, 0.93), (0, 0.815, 0.74), (0, 0.815, 0.52)]


def mirror(p):
    return (-p[0], p[1], p[2])


def side(p, s):
    return p if s == "l" else mirror(p)


# ---------------------------------------------------------------------------
# Bones: name -> (head, tail, parent, deform)
# ---------------------------------------------------------------------------
def bone_table():
    B = {}

    def add(name, head, tail, parent, deform=True):
        B[name] = (tuple(float(v) for v in head), tuple(float(v) for v in tail), parent, deform)

    def addb(name, head, tail, parent, deform=True):
        add(name, S(head), S(tail), parent, deform)

    add("root", (0, 0, 0), (0, -0.30, 0), None, False)
    addb("body", (0, -0.20, 0.95), (0, -0.45, 0.95), "root", False)
    # the vertebral column (see SPINE_T ...): chest forward from T9, back, loin, loin_2 and the
    # pelvis backwards
    addb("chest", SPINE_T, (0, -0.56, 1.03), "body")
    addb("back", SPINE_T, SPINE_TL, "body")
    addb("loin", SPINE_TL, SPINE_L, "back")
    addb("loin_2", SPINE_L, LUMBOSACRAL, "loin")
    # the pelvis (hips) turns about the lumbosacral joint, in front of and above the hip joints
    addb("hips", LUMBOSACRAL, (0, 0.66, 1.16), "loin_2")
    add("saddle", (0, 0, ATTACH_Z), (0, -0.20, ATTACH_Z), "back")
    add("passenger", PASSENGER, (0, 0.19, PASSENGER[2]), "back", False)
    addb("neck_1", (0, -0.56, 1.03), (0, -0.81, 1.22), "chest")
    addb("neck_2", (0, -0.81, 1.22), (0, -0.98, 1.38), "neck_1")
    addb("neck_3", (0, -0.98, 1.38), (0, -1.11, 1.50), "neck_2")
    addb("head", (0, -1.11, 1.50), hs((0, -1.45, 1.06)), "neck_3")
    addb("bit", (0, BIT_Y_BASE, BIT_Z_BASE), (0, BIT_Y_BASE, BIT_Z_BASE + 0.10), "head", False)
    for i, (a, b) in enumerate(zip(TAIL_BONES[:-1], TAIL_BONES[1:])):
        addb("tail_%d" % (i + 1), a, b, "hips" if i == 0 else "tail_%d" % i)
    for s in ("l", "r"):
        m = (lambda p: p) if s == "l" else mirror
        add("ear_" + s, m(S((0.052, -1.105, 1.555))), m(S((0.075, -1.09, 1.695))), "head")
        bar, tread = stirrup_points(s)
        eye = tread + np.array([0, 0, STIRRUP_IRON_H])
        add("stirrup_" + s, bar, eye, "saddle")                    # leather: bar -> iron eye
        add("stirrup_iron_" + s, eye, tread, "stirrup_" + s)       # iron: eye -> tread
        add("scapula_" + s, m(J["scap_top"]), m(J["shoulder"]), "chest")
        add("humerus_" + s, m(J["shoulder"]), m(J["elbow"]), "scapula_" + s)
        add("radius_" + s, m(J["elbow"]), m(J["carpus"]), "humerus_" + s)
        add("cannon_" + s, m(J["carpus"]), m(J["f_fetlock"]), "radius_" + s)
        add("pastern_" + s, m(J["f_fetlock"]), m(J["f_coronet"]), "cannon_" + s)
        add("hoof_" + s, m(J["f_coronet"]), m(J["f_toe"]), "pastern_" + s)
        add("femur_" + s, m(J["hip"]), m(J["stifle"]), "hips")
        add("tibia_" + s, m(J["stifle"]), m(J["hock"]), "femur_" + s)
        add("hcannon_" + s, m(J["hock"]), m(J["h_fetlock"]), "tibia_" + s)
        add("hpastern_" + s, m(J["h_fetlock"]), m(J["h_coronet"]), "hcannon_" + s)
        add("hhoof_" + s, m(J["h_coronet"]), m(J["h_toe"]), "hpastern_" + s)
    # skinning helpers (helpers()): at the joint, on the proximal bone, pointing half way
    # between the proximal and the distal bone (their rest frame does not matter to the pose)
    for name, (prox, dist, _f, key) in helpers().items():
        s = name[-1]
        m = (lambda p: np.asarray(p, float)) if s == "l" else (lambda p: np.asarray(mirror(p), float))
        jt = m(J[key])
        dp = jt - np.asarray(B[prox][0])
        dd = np.asarray(B[dist][1]) - jt
        d = dp / np.linalg.norm(dp) + dd / np.linalg.norm(dd)
        L = 0.35 * min(np.linalg.norm(dp), np.linalg.norm(dd))
        add(name, jt, jt + L * d / np.linalg.norm(d), prox)
    return B




# ---------------------------------------------------------------------------
# Body SDF
# ---------------------------------------------------------------------------
TORSO_ROWS = [
    # y      z_top  z_bot  half_w  widest p_top p_bot     (base shape; deeper, broader chest)
    (-0.80, 1.06, 0.95, 0.075, 0.50, 2.0, 2.0),
    (-0.745, 1.14, 0.865, 0.16, 0.45, 2.0, 2.0),
    (-0.65, 1.21, 0.785, 0.205, 0.44, 1.9, 2.0),
    (-0.52, 1.27, 0.72, 0.23, 0.42, 1.45, 2.1),
    (-0.40, 1.31, 0.685, 0.242, 0.40, 1.30, 2.2),      # withers narrower on top (revision 4: the rider's knees)
    (-0.27, 1.25, 0.675, 0.254, 0.41, 1.85, 2.2),     # a little narrower on top in front of the saddle (the knees)
    (-0.12, 1.195, 0.68, 0.262, 0.42, 2.4, 2.2),
    (0.00, 1.18, 0.69, 0.268, 0.43, 2.5, 2.2),
    (0.14, 1.185, 0.705, 0.27, 0.45, 2.5, 2.2),
    (0.27, 1.21, 0.745, 0.265, 0.48, 2.4, 2.2),
    (0.38, 1.25, 0.81, 0.255, 0.52, 2.3, 2.2),
    # croup and quarters (revision 4): the croup slopes from its highest point behind the
    # point of hip down to the tail head; the point of buttock sits under the tail head,
    # about 0.28 m behind the hip joint
    (0.47, 1.29, 0.87, 0.243, 0.53, 2.3, 2.2),
    (0.55, 1.285, 0.905, 0.225, 0.55, 2.3, 2.2),
    (0.62, 1.245, 0.925, 0.188, 0.56, 2.2, 2.2),
    (0.665, 1.20, 0.94, 0.13, 0.56, 2.1, 2.0),
    (0.695, 1.16, 0.985, 0.07, 0.56, 2.0, 2.0),
    (0.712, 1.135, 1.03, 0.03, 0.56, 2.0, 2.0),
]
TORSO_CAP = 0.02

# the neck root runs back into the withers and tapers there (revision 4: its end cap used to
# stand out as a step behind the shoulder, the "ridge from the withers to the elbow")
NECK_PTS = [(0, -0.34, 0.912), (0, -0.48, 1.00), (0, -0.67, 1.12), (0, -0.84, 1.265), (0, -0.975, 1.385),
            (0, -1.085, 1.475)]
# thick, well-set neck of the stocky type (base: widths x1.15, crest and throat x1.08)
NECK_SEC = [(0.150, 0.185, 0.215, 2.2), (0.215, 0.235, 0.275, 2.2), (0.192, 0.160, 0.225, 2.2),
            (0.152, 0.126, 0.162, 2.1), (0.108, 0.095, 0.122, 2.1), (0.074, 0.078, 0.095, 2.0)]
HEAD_PTS = [(0, -1.095, 1.525), (0, -1.165, 1.44), (0, -1.25, 1.33), (0, -1.34, 1.21), (0, -1.41, 1.115),
            (0, -1.445, 1.07)]
HEAD_UP = (0, -0.62, 0.78)
HEAD_SEC = [(0.07, 0.055, 0.075, 2.2), (0.09, 0.065, 0.115, 2.2), (0.098, 0.068, 0.105, 2.3),
            (0.074, 0.058, 0.074, 2.3), (0.06, 0.052, 0.06, 2.2), (0.057, 0.048, 0.054, 2.0)]


def _rot_to(v):
    """3x3 whose columns are an orthonormal frame with local y along v."""
    y = np.asarray(v, float)
    y = y / np.linalg.norm(y)
    x = np.array([1.0, 0, 0]) if abs(y[0]) < 0.9 else np.array([0, 0, 1.0])
    x = x - (x @ y) * y
    x /= np.linalg.norm(x)
    z = np.cross(x, y)
    return np.stack([x, y, z], 1)


def _ell_along(c, a, b, r):
    """Ellipsoid centred c with its local y along a->b, radii r (x, along, z)."""
    return Ellipsoid(c, r, _rot_to(np.subtract(b, a)))


def _lerp(a, b, t, off=(0, 0, 0)):
    return tuple(np.asarray(a, float) * (1 - t) + np.asarray(b, float) * t + np.asarray(off, float))


def _torso_base():
    # rows resampled with a Catmull-Rom spline (revision 4): a piecewise-linear table puts
    # creases into the topline and flanks at every row, which the baked normal map shows
    # as bands and ridges
    return LoftY(_densify(TORSO_ROWS, 10), cap=TORSO_CAP)


def _torso_top(y):
    """Top of the torso rows (base z) at base y."""
    R = np.asarray(TORSO_ROWS, float)
    return float(np.interp(y, R[:, 0], R[:, 1]))


# passenger seat (Actor_B passenger clips) on the croup, 0.39 m behind the attach point
PASSENGER_Y = 0.39
CROUP_TOP_P = _torso_top(float(unwarp_y(PASSENGER_Y / KY))) * KZ
PASSENGER = (0.0, PASSENGER_Y, CROUP_TOP_P + SEAT_DROP + 0.005)


def _neck_base():
    return LoftPath(NECK_PTS, [(0, 0.35, 1)] * len(NECK_PTS), NECK_SEC, caps=(0.05, 0.06))


# ---------------------------------------------------------------------------
# Head (base space). A local frame along the face: s from the poll down the face
# (HEAD_AX), h towards the front of the face (HEAD_FR, nasal bone side, negative = jaw and
# throat), x lateral. Bony and muscular landmarks: flat forehead and orbits, the facial
# crest, round jowls with a sharp lower jaw edge, eyelids round an eye opening, flared
# nostrils, upper and lower lip with a mouth line ending at the bit, chin, cupped ears.
# ---------------------------------------------------------------------------
HEAD_P0 = np.array(HEAD_PTS[0], float)
HEAD_AX = np.subtract(HEAD_PTS[-1], HEAD_PTS[0]) / np.linalg.norm(np.subtract(HEAD_PTS[-1], HEAD_PTS[0]))
HEAD_FR = np.array([0.0, HEAD_AX[2], -HEAD_AX[1]])       # forward and up: the nasal bone side
EX = np.array([1.0, 0.0, 0.0])
HEAD_R = np.stack([EX, HEAD_AX, HEAD_FR], 1)      # ellipsoid axes: lateral, along the face, front


def hp(s, h, x=0.0):
    """Head-local (s along the face, h to the front of the face, x lateral) -> base space.
    The face is shortened about the poll: s is scaled by HEAD_K."""
    return tuple(HEAD_P0 + HEAD_K * s * HEAD_AX + h * HEAD_FR + x * EX)


def head_coords(p):
    """Base-space point(s) -> authored head coordinates (s, h, x) (inverse of hp)."""
    rel = np.asarray(p, float) - HEAD_P0
    return rel @ HEAD_AX / HEAD_K, rel @ HEAD_FR, rel[..., 0]


def hs(p):
    """A head point authored for the long face -> the shortened face (base space)."""
    rel = np.asarray(p, float) - HEAD_P0
    return hp(float(rel @ HEAD_AX), float(rel @ HEAD_FR), float(rel[0]))


def _hell(s, h, x, r, tilt=0.0):
    """Ellipsoid in the head frame, radii (lateral, along the face, front), tilted in the
    s-h plane by `tilt` radians."""
    R = HEAD_R
    r = (r[0], r[1] * HEAD_K, r[2])
    if tilt:
        c, sn = math.cos(tilt), math.sin(tilt)
        R = np.stack([EX, c * HEAD_AX + sn * HEAD_FR, -sn * HEAD_AX + c * HEAD_FR], 1)
    return Ellipsoid(hp(s, h, x), r, R)


# face profile: s, top (h), bottom (h), half width, exponent
HEAD_PROFILE = [(-0.02, 0.046, -0.080, 0.060, 2.2, 2.0), (0.05, 0.063, -0.150, 0.088, 2.4, 2.0),
                (0.14, 0.072, -0.192, 0.104, 2.7, 2.1), (0.24, 0.069, -0.168, 0.091, 2.6, 1.9),
                (0.34, 0.062, -0.122, 0.068, 2.4, 1.8), (0.43, 0.056, -0.088, 0.057, 2.3, 1.9),
                (0.50, 0.054, -0.070, 0.056, 2.2, 2.0), (0.55, 0.047, -0.058, 0.053, 2.0, 2.0)]
EYE = hp(0.213, 0.026, 0.093)
EYE_POS = S(EYE)            # horse space
EYE_R = 0.027               # eyeball radius (base)
EYE_SET = 0.006             # eyeball centre inside the eye point (base): a prominent eye that fills the lids


def _eye_c(sg):
    """Eyeball centre (base) of the left (sg 1) or right (sg -1) eye."""
    e = np.array(EYE) if sg > 0 else np.array(mirror(EYE))
    return e - sg * EYE_SET * EX


def _densify(rows, n=4):
    """Catmull-Rom resampling of table rows (first column the parameter): n rows per
    interval, so a loft's sections change smoothly (no creases between segments)."""
    R = np.asarray(rows, float)
    P = np.vstack([2 * R[0] - R[1], R, 2 * R[-1] - R[-2]])
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(R[-1])
    return [tuple(r) for r in out]


def _face_loft():
    pts, sec = [], []
    for s, top, bot, hw, p, pd in _densify(HEAD_PROFILE):
        pts.append(hp(s, 0.5 * (top + bot)))
        sec.append((hw, 0.5 * (top - bot), 0.5 * (top - bot), p, pd))
    return LoftPath(pts, [tuple(HEAD_FR)] * len(pts), sec, caps=(0.04, 0.034))


def _nostril_frame(sg):
    """Nostril centre on the muzzle surface, its outward axis and its long axis."""
    d = 0.80 * HEAD_AX + 0.32 * HEAD_FR + sg * 0.50 * EX
    d = d / np.linalg.norm(d)
    loft = _face_loft()
    p = np.array(hp(0.50, 0.026, sg * 0.016), float)
    for _ in range(60):
        if loft.f(*p[:, None]) > 0:
            break
        p = p + d * 0.002
    long_ax = HEAD_FR * 0.85 - sg * EX * 0.35 - HEAD_AX * 0.2
    long_ax = long_ax / np.linalg.norm(long_ax)
    return p, d, long_ax


def _frame(y, z):
    """Orthonormal columns (x, y, z) with local y along `y` and local z close to `z`."""
    y = np.asarray(y, float) / np.linalg.norm(y)
    z = np.asarray(z, float) - (np.asarray(z, float) @ y) * y
    z = z / np.linalg.norm(z)
    return np.stack([np.cross(y, z), y, z], 1)


EAR_BASE = (0.052, -1.103, 1.548)     # base shape; the ear bones are unchanged
EAR_TIP = (0.078, -1.106, 1.676)
HOOF_RENDER_K = (1.10, 1.06)          # render hoof (ground outline) against hoof_mesh


def _ear(sg):
    m = (lambda p: p) if sg > 0 else mirror
    base = np.array(m(EAR_BASE))
    tip = np.array(m(EAR_TIP))
    e = (tip - base) / np.linalg.norm(tip - base)
    L = float(np.linalg.norm(tip - base))
    fr = np.array([sg * 0.45, -1.0, 0.0])            # the opening faces forward and a little out
    R = _frame(e, fr)
    fr = R[:, 2]
    body = Ellipsoid(base + 0.42 * L * e, (0.028, 0.52 * L, 0.017), R)
    tipc = RoundCone(base + 0.50 * L * e, tip, 0.018, 0.003)
    root = RoundCone(base - 0.02 * e, base + 0.25 * L * e, 0.027, 0.025)
    ear = Union([root, body, tipc], k=0.022)
    hollow = Union([Ellipsoid(base + 0.50 * L * e + 0.011 * fr, (0.021, 0.42 * L, 0.012), R),
                    RoundCone(base + 0.55 * L * e + 0.011 * fr, tip - 0.02 * e + 0.006 * fr, 0.013, 0.003)], k=0.01)
    return Sub(ear, hollow, k=0.004)


def _head_base():
    parts = [_face_loft()]
    add, ridges = [], []
    for sg in (1.0, -1.0):
        add += [
            _hell(0.15, -0.115, sg * 0.052, (0.042, 0.105, 0.080)),                        # jowl (round cheek)
            _hell(0.215, -0.060, sg * 0.070, (0.022, 0.080, 0.055)),                       # masseter
            Ellipsoid(tuple(_eye_c(sg) + sg * 0.002 * EX), (0.023, 0.035, 0.028), HEAD_R),     # eyelids
        ]
        ridges.append(RoundCone(hp(0.19, -0.004, sg * 0.084), hp(0.335, -0.028, sg * 0.064), 0.007, 0.005))  # facial crest
        ridges.append(RoundCone(hp(0.172, 0.058, sg * 0.074), hp(0.25, 0.052, sg * 0.074), 0.009, 0.006))    # orbit rim
    parts += add
    parts.append(_hell(0.570, -0.028, 0.0, (0.050, 0.040, 0.031)))                     # upper lip
    parts.append(_hell(0.552, -0.069, 0.0, (0.032, 0.032, 0.018)))                     # lower lip
    parts.append(_hell(0.505, -0.072, 0.0, (0.030, 0.050, 0.026)))                     # chin
    for sg in (1.0, -1.0):
        p, d, la = _nostril_frame(sg)
        parts.append(Ellipsoid(tuple(p - d * 0.013), (0.013, 0.026, 0.024), _frame(la, d)))   # nostril wing
    h = Union([Union(parts, k=0.024), Union(ridges)], k=0.03)
    ears = Union([_ear(1.0), _ear(-1.0)])
    h = Union([h, ears], k=0.018)
    cuts = []
    for sg in (1.0, -1.0):
        eye = np.array(EYE) if sg > 0 else np.array(mirror(EYE))
        eye[0] += sg * 0.001
        c, sn = math.cos(-0.18), math.sin(-0.18)
        R = np.stack([EX, c * HEAD_AX + sn * HEAD_FR, -sn * HEAD_AX + c * HEAD_FR], 1)
        cuts.append(Ellipsoid(tuple(eye + sg * 0.014 * EX), (0.022, 0.029, 0.0165), R))     # eye opening
        p, d, la = _nostril_frame(sg)
        F = _frame(la, d)
        cuts.append(Ellipsoid(tuple(p + d * 0.004 + la * 0.006), (0.011, 0.026, 0.030), F))   # nostril
        cuts.append(Ellipsoid(tuple(p + d * 0.002 - la * 0.020 - sg * EX * 0.005), (0.007, 0.015, 0.022), F))
    mouth = _hell(0.606, -0.043, 0.0, (0.062, 0.068, 0.005))                            # mouth line
    return Sub(Sub(h, Union(cuts), k=0.004), mouth, k=0.003)


def head():
    return Scaled(Warped(_head_base()), K)


def eye_mesh(n_u=18, n_v=12):
    """Eyeballs (horse space): vertices and quads/tris, both sides."""
    V, F = [], []
    for sg in (1.0, -1.0):
        c = _eye_c(sg)
        off = len(V)
        for i in range(n_v + 1):
            th = math.pi * i / n_v
            for j in range(n_u):
                ph = 2 * math.pi * j / n_u
                # poles up and down (not on the visible front of the eye)
                p = c + EYE_R * np.array([sg * math.sin(th) * math.sin(ph), math.sin(th) * math.cos(ph), math.cos(th)])
                V.append(S(p))
        for i in range(n_v):
            for j in range(n_u):
                a = off + i * n_u + j
                b = off + i * n_u + (j + 1) % n_u
                q = (a, b, b + n_u, a + n_u) if sg > 0 else (a, a + n_u, b + n_u, b)
                F.append(q)
    return np.array(V), F


# Thigh and gaskin (base, before the leg shift): horizontal sections down the hind leg. z,
# centre x, centre y, half width, half depth to the front (-y) and to the back (+y). The
# front line runs from the flank to the stifle and on to the front of the hock, the back
# line from the point of buttock down the hamstrings to the point of hock.
THIGH_ROWS = [
    (1.08, 0.125, 0.455, 0.045, 0.110, 0.140),
    (1.02, 0.148, 0.455, 0.068, 0.150, 0.180),
    (0.94, 0.162, 0.452, 0.080, 0.172, 0.200),
    (0.86, 0.170, 0.450, 0.082, 0.182, 0.192),
    (0.78, 0.174, 0.448, 0.078, 0.182, 0.172),
    (0.71, 0.174, 0.450, 0.068, 0.178, 0.145),
    (0.665, 0.170, 0.470, 0.062, 0.158, 0.128),
    (0.62, 0.164, 0.500, 0.055, 0.125, 0.112),
    (0.56, 0.152, 0.537, 0.047, 0.086, 0.090),
    (0.49, 0.140, 0.574, 0.040, 0.058, 0.066),
]


def leg_parts(s, T=LEG_THICK):
    """Base-space leg shapes: muscular forearm and gaskin tapering into clean, flat lower
    legs; boxy knees with the accessory carpal bone behind, angular hocks with the point
    of hock and the gaskin cord, flat cannons with the flexor tendons standing off the
    bone, round fetlocks with ergots, pasterns flaring into the coronet; chestnuts."""
    up, lo = leg_groups(s, T)
    return up + lo


def leg_groups(s, T=LEG_THICK):
    """(upper, lower): the muscular upper leg parts and the bony lower leg (blended tighter)."""
    m = (lambda p: np.asarray(p, float)) if s == "l" else (lambda p: np.asarray(mirror(p), float))
    j = {k: np.asarray(v, float) for k, v in J_BASE.items()}
    t = T / LEG_THICK

    def P(p, off=(0, 0, 0)):
        return tuple(m(np.asarray(p, float) + np.asarray(off, float)))

    def rc(a, b, ra, rb):
        return RoundCone(P(a), P(b), ra * t, rb * t)

    def el(c, r, off=(0, 0, 0), R=None):
        return Ellipsoid(P(c, off), tuple(v * t for v in r), R)

    def ea(c, a, b, r):
        return _ell_along(P(c), m(a), m(b), tuple(v * t for v in r))

    def loft(pts, secs, up, caps=(0.02, 0.02)):
        return LoftPath([P(p) for p in pts], [up] * len(pts), [(q[0] * t, q[1] * t, q[2] * t) + tuple(q[3:]) for q in secs],
                        caps=caps)
    E, C, Ft, Co = j["elbow"], j["carpus"], j["f_fetlock"], j["f_coronet"]
    Sh = j["shoulder"]
    Hi, St, Hk, hF, hC = j["hip"], j["stifle"], j["hock"], j["h_fetlock"], j["h_coronet"]
    Pt, Lo = [], []
    # ---- fore: upper arm (in the body), point of shoulder, elbow
    Pt.append(rc(Sh, E, 0.074, 0.066))
    Pt.append(ea(_lerp(Sh, E, 0.55, (0.0, 0.030, 0.0)), Sh, E, (0.064, 0.11, 0.080)))          # triceps
    Pt.append(el(Sh, (0.040, 0.042, 0.050), (0.0, -0.022, 0.0)))                          # point of shoulder
    Pt.append(el(E, (0.038, 0.038, 0.046), (0.0, 0.048, 0.030)))                           # point of elbow
    # forearm (heavy bone, revision 4): deep and broad under the elbow, the front edge nearly
    # vertical, the muscle tapering into a broad, flat knee
    # (the loft starts inside the arm, so its end cap does not stand out as a lip at the elbow)
    Pt.append(loft([E + (0, -0.010, 0.13), E + (0, -0.006, 0.035), _lerp(E, C, 0.38, (0, 0.0, 0)), C + (0, 0.0, 0.04)],
                   [(0.050, 0.055, 0.065, 2.0, 2.0), (0.078, 0.080, 0.094, 2.0, 2.0), (0.064, 0.063, 0.063, 2.1, 2.0),
                    (0.048, 0.043, 0.040, 2.2, 2.1)],
                   (0, -1.0, 0)))
    Lo.append(el(C, (0.050, 0.039, 0.054), (0.0, -0.002, 0.0)))                            # knee
    Lo.append(el(C, (0.045, 0.030, 0.042), (0.0, -0.012, -0.010)))                         # knee front (flat)
    Lo.append(el(C, (0.020, 0.022, 0.032), (0.0, 0.040, 0.012)))                           # accessory carpal bone
    # cannon: flat and broad (about 6 cm across), the flexor tendons standing off behind
    Lo.append(rc(C + (0, -0.006, -0.02), Ft + (0, -0.006, 0.02), 0.0235, 0.0225))            # cannon bone
    Lo.append(el(_lerp(C, Ft, 0.5, (0, -0.002, 0)), (0.0285, 0.020, 0.12)))                 # cannon breadth
    Lo.append(rc(C + (0, 0.025, -0.035), Ft + (0, 0.027, 0.03), 0.0175, 0.0185))             # flexor tendons
    Lo.append(el(Ft, (0.040, 0.046, 0.042), (0.0, 0.012, 0.0)))                            # fetlock
    Lo.append(el(Ft, (0.012, 0.014, 0.012), (0.0, 0.054, -0.022)))                         # ergot
    Lo.append(rc(Ft + (0, -0.004, -0.012), Co + (0, 0.0, 0.012), 0.027, 0.029))              # pastern
    Lo.append(rc(Co + (0, 0, 0.012), Co + (0, -0.002, -0.004), 0.030, 0.031))                # coronet
    Lo.append(el(C, (0.007, 0.015, 0.021), (-0.045, 0.004, 0.105)))                        # chestnut (inside)
    # ---- hind (revision 4): thigh and gaskin as one loft down the leg (its front line runs
    # from the flank to the stifle and on to the front of the hock, its back line from the
    # point of buttock down the hamstrings to the point of hock, concave above the hock); the
    # stifle is its lower front corner, not a separate knob
    hy = Hi[1] - J_BASE0["hip"][1]            # the hind leg's shift (the rows are authored unshifted)
    sg = 1.0 if s == "l" else -1.0
    rows = []
    for z, cx, cy, hx, hf, hb in sorted(THIGH_ROWS):
        rows.append((z, sg * cx, cy + hy, hx * t, hf * t, hb * t, 2.15))
    Pt.append(LoftZ(_densify(rows, 8), caps=(0.03, 0.04)))
    Pt.append(el(St, (0.030, 0.030, 0.040), (-0.008, -0.012, 0.006)))                      # stifle (patella)
    Lo.append(el(Hk, (0.022, 0.024, 0.030), (0.0, 0.054, 0.034)))                          # point of hock
    Lo.append(el(Hk, (0.041, 0.049, 0.052), (0.0, 0.004, 0.0)))                            # hock
    Lo.append(el(Hk, (0.034, 0.028, 0.032), (0.0, -0.030, -0.018)))                        # hock front
    Lo.append(rc(Hk + (0, -0.006, -0.03), hF + (0, -0.006, 0.02), 0.025, 0.0235))            # hind cannon bone
    Lo.append(el(_lerp(Hk, hF, 0.5, (0, -0.002, 0)), (0.0285, 0.021, 0.12)))                # cannon breadth
    Lo.append(rc(Hk + (0, 0.027, -0.055), hF + (0, 0.027, 0.03), 0.0175, 0.0185))            # hind tendons
    Lo.append(el(hF, (0.040, 0.046, 0.042), (0.0, 0.012, 0.0)))                            # hind fetlock
    Lo.append(el(hF, (0.012, 0.014, 0.012), (0.0, 0.054, -0.022)))                         # ergot
    Lo.append(rc(hF + (0, -0.004, -0.012), hC + (0, 0.0, 0.012), 0.027, 0.029))              # hind pastern
    Lo.append(rc(hC + (0, 0, 0.012), hC + (0, -0.002, -0.004), 0.030, 0.031))                # coronet
    Lo.append(el(Hk, (0.006, 0.014, 0.018), (-0.040, 0.002, -0.05)))                       # chestnut (inside)
    return Pt, Lo


def landmarks(s):
    """Surface landmarks on the torso and neck that the saddle fit does not see: point of
    buttock, scapular spine, neck crest, brachiocephalic muscle, jugular groove."""
    m = (lambda p: p) if s == "l" else mirror
    add = [
        RoundCone(m((0.125, -0.47, 1.19)), m((0.165, -0.66, 0.99)), 0.020, 0.016),                # scapular spine
        RoundCone(m((0.072, -1.035, 1.365)), m((0.135, -0.77, 1.00)), 0.046, 0.066),              # brachiocephalic
        _ell_along((0.0, -0.80, 1.335), (0, -0.62, 1.27), (0, -1.02, 1.52), (0.085, 0.20, 0.055)),  # crest
        # behind the triceps, below the saddle cloth: fills the groove the shoulder muscle
        # leaves against the barrel (the tack fit keeps the unfilled torso)
        _ell_along(m((0.205, -0.395, 0.865)), (0, -0.33, 0.97), (0, -0.46, 0.74), (0.05, 0.13, 0.075)),
    ]
    # the flank fold: the skin web from the belly to the stifle (revision 4)
    add.append(_ell_along(m((0.172, 0.255, 0.78)), (0, 0.16, 0.835), (0, 0.33, 0.715), (0.048, 0.125, 0.042)))
    cut = []
    return add, cut


def muscles(s):
    m = (lambda p: p) if s == "l" else mirror
    return [
        _ell_along(m((0.155, -0.57, 1.06)), J_BASE0["scap_top"], J_BASE0["shoulder"], (0.062, 0.235, 0.145)),  # shoulder
        Ellipsoid(m((0.075, -0.745, 0.915)), (0.078, 0.075, 0.095)),                            # pectoral (broad chest)
        # quarters (revision 4): the gluteal mass over the hip joint from the point of hip to
        # the tail head, the point of hip (tuber coxae) ahead of the hip joint, the point of
        # buttock (tuber ischii) under the tail head
        _ell_along(m((0.148, 0.49, 1.08)), (0, 0.33, 1.15), (0, 0.66, 1.06), (0.088, 0.19, 0.115)),  # gluteal mass
        # (revision 5: flatter, it stood out of the topline as a knob)
        Ellipsoid(m((0.182, 0.315, 1.152)), (0.032, 0.040, 0.034)),                              # point of hip
        Ellipsoid(m((0.115, 0.635, 0.945)), (0.068, 0.058, 0.078)),                              # point of buttock
        # inner thigh (semimembranosus): fills the quarters between the hind legs down to the
        # gaskins, so that from behind the two thighs meet under the tail
        _ell_along(m((0.062, 0.600, 0.80)), (0, 0.645, 0.97), (0, 0.58, 0.60), (0.058, 0.19, 0.062)),
    ]


class Warped(Node):
    """`a` (authored in unwarped base space) seen through the body-axis warp: evaluated at
    (x, unwarp_y(y), z). The distance is scaled by the local slope of the warp (a lower
    bound where the warp compresses y)."""

    def __init__(self, a):
        self.a = a
        self.lo = None if a.lo is None else np.array([a.lo[0], float(warp_y(a.lo[1])), a.lo[2]])
        self.hi = None if a.hi is None else np.array([a.hi[0], float(warp_y(a.hi[1])), a.hi[2]])

    def f(self, X, Y, Z):
        X, Y, Z = np.broadcast_arrays(X, Y, Z)
        yu = unwarp_y(Y)
        return self.a.f(X, yu, Z) * _dwarp_y(yu)


def _torso_only_base():
    return Union([_torso_base()] + muscles("l") + muscles("r"), k=0.07)


def torso_only():
    """Torso and girdle muscles in horse space (the tack is fitted to it)."""
    return Scaled(Warped(_torso_only_base()), K)


def horse_body():
    """Whole skin (torso, neck, head, legs) as one smooth SDF in horse space: the torso and
    girdle muscles, the neck and head, surface landmarks (warped body), the muscular upper
    legs blended softly and the bony lower legs blended tightly (legs moved rigidly with
    their girdles)."""
    nh = Union([_neck_base(), _head_base()], k=0.035)
    # the skin blends the shoulder muscles into the barrel more softly than the torso the
    # tack is fitted to (revision 4: no hard edge behind the shoulder; the difference is
    # ahead of the saddle cloth)
    ml, mr = muscles("l"), muscles("r")
    tors = Union([_torso_base()] + ml[2:] + mr[2:], k=0.07)
    tors = Union([tors, ml[0], mr[0]], k=0.09)         # shoulder
    tors = Union([tors, ml[1], mr[1]], k=0.07)         # pectoral
    body = Union([tors, nh], k=0.10)
    add, cut = [], []
    for s in ("l", "r"):
        a, c = landmarks(s)
        add += a
        cut += c
    body = Union([body] + add, k=0.045)
    if cut:
        body = Sub(body, Union(cut), k=0.03)
    body = Warped(body)
    up, lo = [], []
    for s in ("l", "r"):
        u, l_ = leg_groups(s)
        up += u
        lo += l_
    body = Union([body, Union(up, k=0.03)], k=0.08)
    node = Scaled(Union([body, Union(lo, k=0.014)], k=0.022), K)
    return Bounded(node, np.array([-0.40, -1.66, -0.01]) * K, np.array([0.40, 0.95, 1.76]) * K)


# ---------------------------------------------------------------------------
# Hooves (lofted rings, horn material)
# ---------------------------------------------------------------------------
def hoof_mesh(s, hind):
    """Vertices and faces of one hoof: a truncated cone with a sloped front wall.
    Top ring at the coronet, bottom ring on the ground."""
    c = np.asarray(J["h_coronet" if hind else "f_coronet"], float)
    toe_fwd, rt, rb = _hoof_dims(hind)
    n = 20
    rings = []
    for z, (rx, ry), dy in ((c[2] + 0.004, rt, 0.0), (c[2] * 0.55, ((rt[0] + rb[0]) / 2, (rt[1] + rb[1]) / 2), -0.014),
                            (0.004, rb, -toe_fwd * 0.5), (0.0, (rb[0] * 0.96, rb[1] * 0.96), -toe_fwd * 0.5)):
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            x = c[0] + rx * math.cos(a)
            y = c[1] + dy - ry * math.sin(a) * (1.0 if math.sin(a) > 0 else 0.8)   # blunter heel
            ring.append((x, y, z))
        rings.append(ring)
    V = [p for r in rings for p in r]
    F = []
    for k in range(len(rings) - 1):
        for i in range(n):
            a, b = k * n + i, k * n + (i + 1) % n
            F.append((a, b, b + n, a + n))
    top = len(V)
    V.append((c[0], c[1], c[2] + 0.004))
    for i in range(n):
        F.append((top, (i + 1) % n, i))
    bot = len(V)
    V.append((c[0], c[1] - toe_fwd * 0.5, 0.0))
    base = (len(rings) - 1) * n
    for i in range(n):
        F.append((bot, base + i, base + (i + 1) % n))
    V = np.array(V)
    if s == "r":
        V[:, 0] *= -1
        F = [f[::-1] for f in F]
    return V, F


def hoof_mesh_detail(s, hind, n=28):
    """Render hoof (vertices, quads/tris, uv): a coronary band, a hoof wall sloping to the
    toe and flaring to the ground (same ground outline as hoof_mesh, which the gait
    diagnostics use), rounded heel bulbs, and the underside with a concave sole, the frog
    and the white line. uv: u round the wall (0 at the toe), v up the wall (0 ground,
    1 coronet); the underside has v < 0."""
    c = np.asarray(J["h_coronet" if hind else "f_coronet"], float)
    toe_fwd, rt, rb = _hoof_dims(hind)
    # a little fuller than the diagnostic sole outline (hoof_mesh): sound, well-grown feet
    rt = (rt[0] * 1.06, rt[1] * 1.04)
    rb = (rb[0] * HOOF_RENDER_K[0], rb[1] * HOOF_RENDER_K[1])
    zc = c[2]

    def ring(z, rx, ry, dy, heel=0.8, bulb=0.0):
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n
            ca, sa = math.cos(a), math.sin(a)
            front = sa > 0
            y = c[1] + dy - ry * sa * (1.0 if front else heel)
            x = c[0] + rx * ca
            if bulb and not front:
                # heel bulbs: two rounded lobes either side of the back
                x += bulb * 0.35 * ca * (-sa)
                y += bulb * (-sa) ** 3
            pts.append((x, y, z))
        return pts
    mid = ((rt[0] + rb[0]) / 2, (rt[1] + rb[1]) / 2)
    rings = [
        ring(zc + 0.012, rt[0] * 0.90, rt[1] * 0.88, 0.004, 0.85),                 # hair line (under the skin)
        ring(zc + 0.004, rt[0] * 1.02, rt[1] * 1.00, 0.0, 0.85, 0.004),           # coronary band
        ring(zc - 0.004, rt[0] * 1.00, rt[1] * 0.99, -0.002, 0.82, 0.006),
        ring(zc * 0.72, (rt[0] * 0.55 + rb[0] * 0.45), (rt[1] * 0.55 + rb[1] * 0.45), -0.008, 0.80, 0.007),
        ring(zc * 0.40, mid[0] * 0.25 + rb[0] * 0.75, mid[1] * 0.25 + rb[1] * 0.75, -0.012 - toe_fwd * 0.25, 0.80, 0.006),
        ring(0.004, rb[0], rb[1], -toe_fwd * 0.5, 0.8, 0.004),
        ring(0.0, rb[0] * 0.96, rb[1] * 0.96, -toe_fwd * 0.5, 0.8, 0.003),       # ground bearing edge
        ring(0.001, rb[0] * 0.87, rb[1] * 0.87, -toe_fwd * 0.5, 0.8, 0.0),       # white line
        # sole (revision 4): only slightly concave (about 5 mm), not a cup
        ring(0.0035, rb[0] * 0.70, rb[1] * 0.70, -toe_fwd * 0.5, 0.8, 0.0),
        ring(0.0048, rb[0] * 0.42, rb[1] * 0.42, -toe_fwd * 0.5, 0.8, 0.0),
    ]
    vs = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -0.3, -0.55, -0.7]
    wall_v = [1.08, 1.0, 0.9, 0.6, 0.32, 0.03, 0.0]
    V, UV, F = [], [], []
    for k, r in enumerate(rings):
        for i, p in enumerate(r):
            V.append(p)
            u = i / n
            if k < len(wall_v):
                UV.append((u, wall_v[k]))
            else:
                UV.append((0.5 + 0.2 * (p[0] - c[0]) / rb[0], vs[k] + 0.05 * (p[1] - c[1]) / rb[1]))
    for k in range(len(rings) - 1):
        for i in range(n):
            a, b = k * n + i, k * n + (i + 1) % n
            F.append((a, b, b + n, a + n))
    # sole centre: a fan to the centre point
    ctr = len(V)
    sc = np.array([c[0], c[1] - toe_fwd * 0.5, 0.0052])
    V.append(tuple(sc))
    UV.append((0.5, -0.75))
    base = (len(rings) - 1) * n
    for i in range(n):
        F.append((ctr, base + i, base + (i + 1) % n))
    # frog: a V-shaped wedge from between the heel bulbs to about a third of the way to
    # the toe, standing nearly down to the ground, with a central groove
    tri = np.array([[0.0, -0.40 * rb[1]], [0.34 * rb[0], 0.82 * rb[1]], [-0.34 * rb[0], 0.82 * rb[1]]]) + sc[:2]
    per = []
    for a_, b_ in ((0, 1), (1, 2), (2, 0)):
        for t_ in np.linspace(0.0, 1.0, 6, endpoint=False):
            per.append(tri[a_] * (1 - t_) + tri[b_] * t_)
    per = np.array(per)
    fc = per.mean(0)
    ang = np.arctan2(-(per[:, 1] - fc[1]), per[:, 0] - fc[0])
    per = per[np.argsort(ang)]
    nf = len(per)
    f0 = len(V)
    for scale, z in ((1.0, 0.0042), (0.55, 0.0015)):
        for q in per:
            pq = fc + (q - fc) * scale
            V.append((pq[0], pq[1], z))
            UV.append((0.5 + 0.2 * (pq[0] - c[0]) / rb[0], -0.95))
    for i in range(nf):
        a, b = f0 + i, f0 + (i + 1) % nf
        F.append((a, b, b + nf, a + nf))
    fctr = len(V)
    V.append((fc[0], fc[1], 0.0032))
    UV.append((0.5, -0.97))
    for i in range(nf):
        F.append((fctr, f0 + nf + i, f0 + nf + (i + 1) % nf))
    top = len(V)
    V.append((c[0], c[1] + 0.004, zc + 0.014))
    UV.append((0.5, 1.1))
    for i in range(n):
        F.append((top, (i + 1) % n, i))
    V = np.array(V)
    if s == "r":
        V[:, 0] = -V[:, 0]
        F = [f[::-1] for f in F]
    return V, F, np.array(UV)


# ---------------------------------------------------------------------------
# Hair: mane, forelock, tail
# ---------------------------------------------------------------------------
CREST = [(0, -0.60, 1.262), (0, -0.72, 1.315), (0, -0.84, 1.384), (0, -0.94, 1.442), (0, -1.02, 1.50),
         (0, -1.08, 1.545)]


def _mane_base():
    """Full mane lying to the horse's right (-x) along the crest, with a ragged lower edge."""
    parts = []
    crest = np.array(CREST)
    rng = np.random.default_rng(7)
    for i in range(len(crest) - 1):
        for t in np.linspace(0, 1, 6, endpoint=False):
            c = crest[i] * (1 - t) + crest[i + 1] * t
            ln = 0.13 + 0.06 * rng.random() + 0.04 * (i / len(crest))
            top = c + np.array([-0.010, 0.0, 0.014])
            bot = c + np.array([-0.085 - 0.02 * rng.random(), 0.025, -ln])
            parts.append(RoundCone(top, bot, 0.030, 0.012))
    return Union(parts, k=0.022)


def mane():
    return Scaled(_mane_base(), K)


def forelock():
    return Scaled(RoundCone((0, -1.13, 1.552), (0, -1.21, 1.42), 0.034, 0.015), K)


TAIL_PTS = [(0, 0.70, 1.23), (0, 0.80, 1.14), (0, 0.845, 0.96), (0, 0.865, 0.76), (0, 0.872, 0.56), (0, 0.868, 0.40),
            (0, 0.862, 0.33)]
TAIL_SEC = [(0.045, 0.045, 0.045, 2.0), (0.05, 0.045, 0.045, 2.0), (0.07, 0.052, 0.058, 2.0), (0.088, 0.058, 0.064, 2.0),
            (0.095, 0.058, 0.058, 2.0), (0.08, 0.045, 0.045, 2.0), (0.05, 0.03, 0.03, 2.0)]


def tail():
    return Scaled(LoftPath(TAIL_PTS, [(0, 1, 0.2)] * len(TAIL_PTS), TAIL_SEC, caps=(0.03, 0.05)), K)


# ---------------------------------------------------------------------------
# Tack
# ---------------------------------------------------------------------------
# Saddle flap half-width by height below the attach point (from Actor_B's inner-leg
# surface in the riding clips, minus about 1 cm).
FLAP_W = [(-0.07, 0.10), (-0.10, 0.125), (-0.15, 0.15), (-0.20, 0.195), (-0.25, 0.235), (-0.30, 0.255),
          (-0.35, 0.265), (-0.40, 0.275), (-0.45, 0.28), (-0.52, 0.285)]


FLAP_MIN = 0.045  # flap outer face at least this far outside the barrel


def _poly2(points):
    """Signed distance (half-plane max) to a convex polygon in (y, z), extruded along x."""
    P = np.asarray(points, float)
    area = 0.5 * sum(P[i, 0] * P[(i + 1) % len(P), 1] - P[(i + 1) % len(P), 0] * P[i, 1] for i in range(len(P)))
    if area < 0:
        P = P[::-1]

    def f(X, Y, Z):
        d = None
        for i in range(len(P)):
            a, b = P[i], P[(i + 1) % len(P)]
            e = b - a
            n = np.array([e[1], -e[0]]) / np.linalg.norm(e)
            di = (Y - a[0]) * n[0] + (Z - a[1]) * n[1]
            d = di if d is None else np.maximum(d, di)
        return d
    return f


def seat_top(Y, X):
    cantle = 0.095 * smoothstep(0.04, 0.20, Y)
    pommel = 0.075 * smoothstep(-0.12, -0.25, Y) * np.exp(-(X / 0.07) ** 2)
    return SEAT_Z + cantle + pommel - 0.9 * X * X


def saddle(torso_node):
    """Seat, pommel, cantle and flaps as one solid between the horse's back (plus the
    saddle cloth) and an envelope: the seat surface on top and, on the sides, the rider's
    inner-leg surface (FLAP_W) or at least FLAP_MIN beyond the barrel, so the flaps
    never thin out to a sliver where the barrel is wide."""
    fw = sorted(FLAP_W)                       # np.interp needs increasing heights
    zf = np.array([a for a, _ in fw]) + ATTACH_Z
    wf = np.array([w for _, w in fw])
    outline = _poly2([(-0.27, ATTACH_Z - 0.02), (-0.27, ATTACH_Z - 0.30), (-0.20, ATTACH_Z - 0.50),
                      (0.05, ATTACH_Z - 0.50), (0.12, ATTACH_Z - 0.32), (0.22, ATTACH_Z - 0.05),
                      (0.22, ATTACH_Z + 0.02)])

    def env(X, Y, Z):
        w = np.interp(Z, zf, wf)
        fm = FLAP_MIN * smoothstep(ATTACH_Z - 0.20, ATTACH_Z - 0.30, Z)   # only on the lower flap
        d_lat = np.minimum(np.abs(X) - w, torso_node.f(X, Y, Z) - fm)
        d_top = Z - seat_top(Y, X)
        return smax(smax(d_lat, d_top, 0.02), outline(X, Y, Z), 0.03)
    E = Fn(env, lo=(-0.34, -0.30, ATTACH_Z - 0.55), hi=(0.34, 0.25, ATTACH_Z + 0.12))
    return Sub(E, Offset(torso_node, 0.012), k=0.005)


def saddle_cloth(torso_node):
    shell = Onion(Offset(torso_node, 0.011), 0.005)
    out = _poly2([(-0.31, ATTACH_Z - 0.05), (-0.31, ATTACH_Z - 0.42), (-0.25, ATTACH_Z - 0.53),
                  (0.24, ATTACH_Z - 0.53), (0.31, ATTACH_Z - 0.42), (0.31, ATTACH_Z - 0.05)])
    reg = Fn(lambda X, Y, Z: out(X, Y, Z), lo=(-0.34, -0.33, ATTACH_Z - 0.56), hi=(0.34, 0.33, ATTACH_Z - 0.02))
    return Inter(shell, reg, k=0.004)


def girth(torso_node):
    shell = Onion(Offset(torso_node, 0.016), 0.006)
    reg = Fn(lambda X, Y, Z: np.maximum(np.abs(Y + 0.28) - 0.03, Z - (ATTACH_Z - 0.46)),
             lo=(-0.32, -0.32, 0.5), hi=(0.32, -0.24, ATTACH_Z - 0.44))
    return Inter(shell, reg, k=0.003)


def _slab(n, p0, half):
    n = np.asarray(n, float)
    n = n / np.linalg.norm(n)
    d0 = float(n @ np.asarray(p0, float))
    return lambda X, Y, Z: np.abs(n[0] * X + n[1] * Y + n[2] * Z - d0) - half


def bridle(head_node=None):
    """Headstall, browband, noseband and cheekpieces round the head (built on the base head,
    stretched with it)."""
    return Scaled(Warped(_bridle_base(_head_base())), K)


def _bridle_base(head_node):
    shell = Onion(Offset(head_node, 0.007), 0.0045)
    ax = np.subtract(HEAD_PTS[-1], HEAD_PTS[0])
    ax = ax / np.linalg.norm(ax)
    crown = _slab((0, 0.35, -1.0), (0, -1.08, 1.50), 0.011)            # behind the ears, around the poll
    brow_p = hs((0, -1.155, 1.52))
    brow = _slab(ax, brow_p, 0.009)                                     # across the forehead
    nose = _slab(ax, hs(HEAD_PTS[3]), 0.013)                            # noseband
    # cheekpieces from the crownpiece down to the bit rings, passing well behind and below
    # the eye (revision 4: on the shortened head the old line crossed the eye)
    ch_a, ch_b = np.array(hp(0.53, -0.022)), np.array(hp(0.03, -0.050))
    cheek_n = np.cross(np.array([1.0, 0, 0]), ch_a - ch_b)
    cheek = _slab(cheek_n, tuple(0.5 * (ch_a + ch_b)), 0.011)

    def f(X, Y, Z):
        up_head = (Y - brow_p[1]) * ax[1] + (Z - brow_p[2]) * ax[2]   # along the head from the brow
        c = np.maximum(crown(X, Y, Z), -(Z - 1.30))                   # crownpiece only above the throat
        b = np.maximum(brow(X, Y, Z), -(Z - 1.47))
        n_ = nose(X, Y, Z)
        ch = np.maximum(cheek(X, Y, Z), 0.045 - np.abs(X))            # cheek pieces: sides only
        ch = np.maximum(ch, np.maximum(-up_head - 0.05, up_head - 0.40 * HEAD_K))
        return np.minimum(np.minimum(c, b), np.minimum(n_, ch))
    reg = Fn(f, lo=(-0.14, -1.50, 0.98), hi=(0.14, -1.02, 1.62))
    return Inter(shell, reg, k=0.002)


class Torus(Node):
    """Torus in the plane through c spanned by axes u, v (major R, minor r)."""

    def __init__(self, c, u, v, R, r):
        self.c = np.asarray(c, float)
        self.u = np.asarray(u, float) / np.linalg.norm(u)
        self.v = np.asarray(v, float) / np.linalg.norm(v)
        self.n = np.cross(self.u, self.v)
        self.R, self.r = R, r
        self.lo, self.hi = self.c - R - r, self.c + R + r

    def f(self, X, Y, Z):
        dx, dy, dz = X - self.c[0], Y - self.c[1], Z - self.c[2]
        a = dx * self.u[0] + dy * self.u[1] + dz * self.u[2]
        b = dx * self.v[0] + dy * self.v[1] + dz * self.v[2]
        c = dx * self.n[0] + dy * self.n[1] + dz * self.n[2]
        q = np.sqrt(a * a + b * b) - self.R
        return np.sqrt(q * q + c * c) - self.r


BIT_Y_BASE, BIT_Z_BASE = hs((0.0, -1.405, 1.075))[1:]     # at the corners of the (shortened) mouth
BIT_Y, BIT_Z = S((0.0, BIT_Y_BASE, BIT_Z_BASE))[1:]
BIT_RING_X = 0.068 * KX


def bit():
    parts = [RoundCone((0.06, BIT_Y_BASE, BIT_Z_BASE), (-0.06, BIT_Y_BASE, BIT_Z_BASE), 0.006, 0.006)]
    for s in (1, -1):
        parts.append(Torus((s * 0.068, BIT_Y_BASE, BIT_Z_BASE), (0, 1, 0), (0, 0, 1), 0.024, 0.0045))
    return Scaled(Warped(Union(parts)), K)


STIRRUP_IRON_H = 0.115    # tread to the eye of the iron


def stirrup_points(s):
    """Stirrup bar (leather top, under the saddle skirt) and tread centre, rest."""
    m = (lambda p: p) if s == "l" else mirror
    return np.array(m((0.145, -0.08, SEAT_Z - 0.03))), np.array(m((0.425, -0.16, ATTACH_Z - 0.665)))


def stirrup_leather(s):
    top, tread = stirrup_points(s)
    eye = tread + np.array([0, 0, STIRRUP_IRON_H])
    parts = [RoundCone(top + np.array([0, w, 0]), eye + np.array([0, w, 0]), 0.0055, 0.0055)
             for w in (-0.012, 0.0, 0.012)]
    return Union(parts, k=0.004)


def stirrup_iron(s):
    top, tread = stirrup_points(s)
    parts = [Torus(tread + np.array([0, 0, 0.055]), (0, 1, 0), (0, 0, 1), 0.058, 0.007)]
    tr = RoundCone(tread + np.array([0, -0.05, 0]), tread + np.array([0, 0.05, 0]), 0.012, 0.012)
    parts.append(Inter(tr, Fn(lambda X, Y, Z: np.abs(Z - tread[2]) - 0.006)))
    u = Union(parts, k=0.004)
    cut = Fn(lambda X, Y, Z: Z - (tread[2] - 0.004), lo=tread - 0.1, hi=tread + 0.1)
    return Sub(u, cut)
