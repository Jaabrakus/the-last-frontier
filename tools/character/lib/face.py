"""Head v2 (lib v2): an anatomical head for the customizer body.

The v1 head (body_shapes.head_shapes, kept for the legacy actor_b_body.glb) was a few
blended ellipsoids with the eyes, lids and lips as separate caps on top. This head is
one skin surface with:

  - eyelids: a shell over the eyeball, cut by the palpebral fissure (an almond opening
    whose margins, canthi and canthal tilt are parameters) and hollowed into a pocket
    the eyeball sits in, so the lids have real margins, an upper-lid crease and fold,
    and a wet inner rim;
  - a nose with a bony and cartilage dorsum, a tip lobule, alae with an alar crease,
    a columella and nostrils;
  - lips with a vermilion (upper tubercle, fuller lower lip), philtral columns, a
    mouth seam and commissures, on a dental arch (the muzzle);
  - brow ridge, zygoma and arch, malar fat pad, buccal fullness, mandible (ramus,
    angle, body) and chin;
  - ears with a helix rim, scapha, concha, tragus and lobe.

It is built on the Actor_B facial joints at null-add (the rig's eyeball, lid, brow,
nose, lip and chin joints give the landmarks), so it keeps the rig's proportions. The
cranium is the v1 cranium exactly: hair caps and hats fit every face.

Parameters (FACE_BASE, metres or unitless, the female neutral face) are anthropometric:
face breadth (bizygomatic), jaw breadth (bigonial) and angle, lower face height, chin,
alveolar prognathism, brow ridge, nasal root height, dorsum, nasal breadth (alar),
nasal length and tip, lip fullness, mouth width, and the eye region (fissure height,
canthal tilt, lid crease height and depth, upper lid fullness, epicanthic fold).
FACE_MALE holds the male differences (design 3.2: heavier brow, jaw and chin, larger
nose, thinner lips).

Face features (shape keys `face_*`): most are the base head projected onto the head
with one parameter changed (lib/shapes.project_shape). Changes of the lid opening
(canthal tilt, fissure height, epicanthic fold, the blink) are *warps* instead: every
vertex near an eye is rotated about the eye centre in eye-local (azimuth, elevation),
the margin curve mapping onto the new margin curve, so the lids slide over the eyeball
(never through it) and a margin never splits (FACE_WARPS, eye_warp()).

All positions are Blender armature space (z up, the character faces -y).
"""

import math

import numpy as np

from .sdf import (Ellipsoid, Fn, Inter, Offset, Plane, RoundCone, Sphere, Sub, SymUnion, Union, frame_from, lerp,
                  mirror_x, nrm, smoothstep, surface_point, v3)

# ---------------------------------------------------------------------------
# Eyes
# ---------------------------------------------------------------------------
EYE_R = 0.0121          # sclera radius
CORNEA_R = 0.0078       # anterior corneal curvature
CORNEA_D = 0.00547      # corneal sphere centre in front of the eye centre (limbus radius 5.9 mm)
LID_GAP = 0.0003        # eyeball -> inner lid surface
LID_T = 0.0021          # lid thickness at the margin


def eye_center(K, s):
    """Eye centre: the rig's eyeball joint, 3.5 mm forward (the corneal apex then sits
    about 12 mm behind the nasion and 10 mm behind the brow)."""
    e = K["l_eyeball"]
    return v3(s * e[0], e[1] - 0.0035, e[2])


def eye_shape(c, grow=0.0):
    """Sclera sphere + corneal bulge, offset by `grow`."""
    return Union([Sphere(c, EYE_R + grow), Sphere(c + v3(0, -CORNEA_D, 0), CORNEA_R + grow)], k=0.0012)


# Palpebral fissure in eye-local angles (degrees): azimuth az (0 = straight ahead, + lateral),
# elevation el (+ up). t = (az - AZ_C) / AZ_H runs -1 (medial canthus) .. +1 (lateral canthus).
AZ_MED, AZ_LAT = -66.0, 74.0
AZ_C, AZ_H = (AZ_MED + AZ_LAT) * 0.5, (AZ_LAT - AZ_MED) * 0.5


def eye_local(P, c, s):
    """(t, el in degrees, r, az in degrees) of points P (..., 3) around the eye centre c of side s."""
    d = P - c
    lat = d[..., 0] * s
    fwd = -d[..., 1]
    up = d[..., 2]
    hor = np.sqrt(lat * lat + fwd * fwd)
    az = np.degrees(np.arctan2(lat, fwd))
    el = np.degrees(np.arctan2(up, np.maximum(hor, 1e-9)))
    r = np.sqrt(hor * hor + up * up)
    return (az - AZ_C) / AZ_H, el, r, az


def _skew_bump(t, peak, p):
    """(1 - t'^2)^p with t' the parameter remapped so the maximum sits at `peak`."""
    tp = np.where(t > peak, (t - peak) / (1.0 - peak), (t - peak) / (1.0 + peak))
    return np.power(np.clip(1.0 - tp * tp, 0.0, 1.0), p)


def margins(t, F):
    """Upper and lower lid margin elevations (degrees) along t for face params F."""
    el_med = F["canthus_med"]
    el_lat = F["canthus_med"] + F["canthal_tilt"]
    line = el_med + (el_lat - el_med) * (np.clip(t, -1, 1) + 1.0) * 0.5
    up = line + F["fissure_up"] * _skew_bump(t, -0.10, 0.62)
    lo = line - F["fissure_lo"] * _skew_bump(t, 0.16, 0.85)
    return up, lo


def crease_el(t, F):
    """Upper-lid crease elevation (degrees): a flatter curve above the margin."""
    up, _ = margins(t, F)
    return up + F["crease_h"] * (0.55 + 0.45 * _skew_bump(t, -0.05, 0.5))


# ---------------------------------------------------------------------------
# Parameters
# ---------------------------------------------------------------------------
FACE_BASE = {
    # eye region (angles in degrees, lengths in metres)
    "fissure_up": 23.5,        # upper margin above the canthal line (fissure height, upper part)
    "fissure_lo": 16.5,        # lower margin below it
    "canthus_med": -8.0,       # medial canthus elevation
    "canthal_tilt": 5.0,       # lateral canthus above the medial one
    "crease_h": 21.0,          # upper-lid crease above the margin
    "crease_depth": 0.0011,    # crease groove depth (0 = no crease)
    "lid_fold": 0.0,           # preseptal fullness of the upper lid (hooding / monolid), metres
    "epicanthus": 0.0,         # epicanthic fold 0..1 (warp)
    "socket": 1.0,             # orbital hollow scale (deep-set > 1)
    "under_eye": 0.0,          # lower-lid / tear-trough fullness
    # brow and forehead
    "brow": 0.0012,            # supraorbital ridge prominence beyond the cranium
    "brow_h": 0.0,             # brow ridge height offset
    "glabella": 0.0,
    # midface and cheeks
    "zyg_x": 0.0495,           # zygoma centre half-breadth (face breadth)
    "zyg_fwd": 0.0,            # zygoma forward projection
    "zyg_z": 0.0,              # zygoma height offset
    "zyg_r": 0.0125,           # zygoma size
    "malar": 0.0105,           # malar fat pad (apple of the cheek)
    "midface": 0.0,            # midface forward projection (flat < 0 < projecting)
    "buccal": 0.0,             # lower cheek fullness
    # nose
    "nasion": 0.0,             # nasal root height (forward), relative to the landmark
    "dorsum": 0.0,             # dorsum projection along its length
    "hump": 0.0,               # dorsal convexity
    "bridge_w": 0.0048,        # bony bridge half-width at the root
    "nose_w": 0.0157,          # alar half-breadth (to the alar surface)
    "nose_len": 0.0,           # nasion -> tip length change
    "tip_proj": 0.0,           # tip forward projection
    "tip_up": 0.0,             # tip rotation up (nasolabial angle)
    "tip_r": 0.0068,           # tip lobule radius
    "ala_r": 0.0058,           # ala size (half-length about 6.8 mm)
    "nostril": 1.0,            # nostril size
    # mouth
    "mouth_w": 0.0235,         # half mouth width (cheilion)
    "lip_up": 0.0,             # upper vermilion fullness
    "lip_lo": 0.0,             # lower vermilion fullness
    "philtrum": 1.0,           # philtral column definition
    "prog": 0.0,               # alveolar prognathism (the muzzle forward)
    # lower face
    "jaw_x": 0.0455,           # gonion half-breadth (jaw breadth)
    "jaw_angle": 0.0,          # gonial prominence / squareness
    "jaw_r": 0.0105,           # mandible body thickness
    "face_len": 0.0,           # lower face height (chin down)
    "chin_fwd": 0.0,           # chin projection
    "chin_w": 0.0125,          # chin half-breadth
    "chin_h": 0.0,             # chin height
    "cheek_soft": 0.0,         # overall soft-tissue fullness of the lower face
    # ears
    "ear": 1.0,                # ear size
    "ear_out": 0.0,            # ear protrusion
}

# Male differences (design 3.2): heavier brow ridge, jaw and chin, larger nose, thinner lips,
# less soft tissue. The male base is FACE_BASE + FACE_MALE.
FACE_MALE = {
    "brow": +0.0026, "brow_h": -0.0005, "glabella": +0.0020, "zyg_x": +0.0018, "zyg_r": +0.0008,
    "malar": -0.0015, "jaw_x": +0.0045, "jaw_angle": +0.5, "jaw_r": +0.0015, "face_len": +0.0035,
    "chin_w": +0.0022, "chin_h": +0.002, "chin_fwd": +0.0012, "nose_w": +0.0012, "nose_len": +0.003,
    "nasion": +0.0010, "dorsum": +0.0008, "tip_r": +0.0006, "ala_r": +0.0004, "bridge_w": +0.0006,
    "mouth_w": +0.0012, "lip_up": -0.0006, "lip_lo": -0.0004, "crease_h": +1.0, "fissure_up": -1.0,
    "cheek_soft": -0.001, "ear": 0.05,
}


def params(**kw):
    F = dict(FACE_BASE)
    for k, v in kw.items():
        if k not in F:
            raise KeyError("unknown face param %s" % k)
        F[k] = v
    return F


def add(F, delta, amount=1.0):
    out = dict(F)
    for k, dv in delta.items():
        out[k] = out[k] + dv * amount
    return out


def male(F=None):
    return add(F or FACE_BASE, FACE_MALE)


# Structural constants of the head's masses and blends (not face features: every face shares
# them). STRUCT is the realistic head; lib/stylize.py builds the stylized head's target with its
# own values (STYLE_STRUCT): leaner lower-face masses, crisper blends, a bolder brow.
STRUCT = {
    "k_center": 0.012,          # blend of cranium, midface, lower face, muzzle and chin
    "k_side": 0.016,            # blend of zygoma, malar pad, cheek and masseter
    "k_side_all": 0.014,        # ... with the mandible and the brow ridge
    "k_face": 0.016,            # centre with both sides
    "low_c": (0.0, -0.0590, 1.4230),    # lower face (soft tissue over the maxilla and mandible)
    "low_r": (0.0520, 0.0525, 0.0470),
    "mass_x": 0.0500,           # masseter centre half-breadth
    "mass_r": (0.0120, 0.0230, 0.0280),
    "cheek_r": (0.0205, 0.0180, 0.0260),
    "mand_k": 0.008,            # blend of the mandible's ramus and body
    "mand_front": 0.95,         # radius of the mandible's body at the chin (x its radius at the angle)
    "chin_r": (0.0100, 0.0120),  # chin (depth, height) radii
    "brow_r": 0.0058,           # brow ridge radius
    "zyg_scale": (1.15, 1.25, 1.10),
    "malar_scale": 1.0,
    "submental": 0.0,           # depth of the plane under the chin and jaw (0: none) ...
    "submental_x": 0.032,       # ... its half-breadth and blend
    "submental_k": 0.008,
    "k_lids": 0.0060, "k_nose": 0.0032, "k_mouth": 0.0020,
    "lid_roll": 1.0,            # the lower lid's roll (pretarsal) under the margin, x its depth
    "under_bag": 1.0,           # the under-eye fullness below it, x its depth
    "tmj_fill": 0.0,            # fills the hollow in front of the ear (0: none)
    "zyg_arch": 0.0,            # the cheekbone continued as a ridge along the arch (0: none)
}


# ---------------------------------------------------------------------------
# The head
# ---------------------------------------------------------------------------
def cranium(K):
    """The v1 cranium, unchanged (hair caps and hats are built on it)."""
    return Ellipsoid(K["headb"] + v3(0, -0.027, 0.061), (0.074, 0.098, 0.092))


def _fissure_node(K, s, F):
    """Negative inside the palpebral fissure (a cone from the eye centre), only near the lids."""
    c = eye_center(K, s)
    r_cut = EYE_R + LID_GAP + LID_T + 0.0055

    def f(X, Y, Z):
        P = np.stack(np.broadcast_arrays(X, Y, Z), -1)
        t, el, r, az = eye_local(P, c, s)
        up, lo = margins(t, F)
        d = np.maximum(el - up, lo - el)
        d = np.maximum(d, (np.abs(t) - 1.0) * AZ_H)
        ang = np.radians(d) * np.maximum(r, 0.004)
        out = np.maximum(ang, r - r_cut)
        fwd = -(P[..., 1] - c[1])
        return np.where(fwd > 0.0, out, np.maximum(out, 0.004 - fwd))
    return Fn(f, c - r_cut - 0.002, c + r_cut + 0.002)


def _crease_node(K, s, F):
    """Upper-lid crease: a soft groove along crease_el over the lid shell."""
    c = eye_center(K, s)
    r0 = EYE_R + LID_GAP + LID_T + 0.0010
    tube = 0.0011
    depth = F["crease_depth"]

    def f(X, Y, Z):
        P = np.stack(np.broadcast_arrays(X, Y, Z), -1)
        t, el, r, az = eye_local(P, c, s)
        ce = crease_el(t, F)
        fade = smoothstep(1.02, 0.55, np.abs(t + 0.05))
        dd = np.sqrt((np.radians(el - ce) * r) ** 2 + (r - (r0 + tube - depth)) ** 2)
        return np.where(fade > 0.01, dd - tube * fade, 0.01)
    return Fn(f, c - 0.022, c + 0.022)


def _eye_region(K, s, F, S=None):
    """Lid shell pieces for side s (to be unioned into the face), and the cut / pocket nodes."""
    S = S or STRUCT
    c = eye_center(K, s)
    shell = Offset(eye_shape(c), LID_GAP + LID_T)
    # upper-lid fold: preseptal fullness above the crease, hanging a little over it
    fold = Ellipsoid(c + v3(s * 0.0010, -0.0098, 0.0098 - 0.6 * F["lid_fold"]),
                     (0.0150, 0.0036 + F["lid_fold"], 0.0058 + 0.5 * F["lid_fold"]),
                     frame_from(v3(0, -0.35, 1), v3(s, 0, 0)))
    # lower-lid roll (pretarsal orbicularis) and the under-eye fullness
    rl = S["lid_roll"]
    roll = Ellipsoid(c + v3(s * 0.0015, -0.0109 + 0.0019 * (1.0 - rl), -0.0068), (0.0120, 0.0019 * rl, 0.0022),
                     frame_from(v3(0, 0.30, 1), v3(s, 0, 0)))
    under = Ellipsoid(c + v3(s * 0.002, -0.0088, -0.0128), (0.0150, 0.0030 * S["under_bag"] + F["under_eye"], 0.0060),
                      frame_from(v3(0, 0.5, 1), v3(s, 0, 0)))
    lids = Union([shell, fold, roll, under], k=0.0045)
    pocket = Inter(eye_shape(c, LID_GAP), Plane(v3(0, 1, 0), c + v3(0, 0.004, 0)))
    return lids, None, _fissure_node(K, s, F), _crease_node(K, s, F), pocket


ARCH_K = 22.0            # dental arch curvature: the lips and the mouth line recede by ARCH_K * x^2


def _bent_ellipsoid(c, r, k=ARCH_K, tilt=0.0):
    """Ellipsoid (axis aligned radii r) bent back along the dental arch: y -> y - k x^2, and
    tilted about x by `tilt` radians (+ = the front face turns down)."""
    c = np.asarray(c, float)
    ca, sa = math.cos(tilt), math.sin(tilt)

    def f(X, Y, Z):
        dx = X - c[0]
        dy = Y - c[1] - k * dx * dx
        dz = Z - c[2]
        qy = ca * dy + sa * dz
        qz = -sa * dy + ca * dz
        k0 = np.sqrt((dx / r[0]) ** 2 + (qy / r[1]) ** 2 + (qz / r[2]) ** 2)
        k1 = np.sqrt((dx / r[0] ** 2) ** 2 + (qy / r[1] ** 2) ** 2 + (qz / r[2] ** 2) ** 2)
        g = np.sqrt(1.0 + (2.0 * k * dx) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6) / g
    ext = np.array([r[0], max(r[1], r[2]) + k * r[0] ** 2, max(r[1], r[2])]) + 0.002
    return Fn(f, c - ext, c + ext + v3(0, k * r[0] ** 2, 0))


def front_y(node, x, z, y0=-0.2):
    """y of the first surface crossing seen from the front at (x, z)."""
    return float(surface_point(node, v3(x, y0, z), v3(0, 1, 0), 0.0, 0.2)[1])


def _on_cranium(K, x, z, inset):
    """Point on the cranium's front surface at (x, z), moved `inset` into it (+y)."""
    c = K["headb"] + v3(0, -0.027, 0.061)
    q = 1.0 - (x / 0.074) ** 2 - ((z - c[2]) / 0.092) ** 2
    return v3(x, c[1] - 0.098 * math.sqrt(max(q, 0.0)) + inset, z)


def _base(K, F, S=None):
    """Skull and soft-tissue masses: cranium, brow, midface, zygoma, malar pad, lower face,
    muzzle (dental arch), mandible and chin; the orbits and the nasal root carved (no nose,
    lips, lids or ears). Surface targets (female, midline): glabella y -0.129, nasion -0.1245,
    subnasale -0.122, lips -0.127, mentolabial sulcus -0.118, pogonion -0.1215. S: structural
    constants (STRUCT)."""
    S = S or STRUCT
    hb = K["headb"]
    L = F["face_len"]
    sto = mouth_landmarks(K, F)["stomion"]
    pg = F["prog"]
    cr = cranium(K)
    mid = Ellipsoid(v3(0, -0.0800 - F["midface"], 1.4540), (0.0420, 0.0430, 0.0330))
    lc, lr = S["low_c"], S["low_r"]
    low = Ellipsoid(v3(lc[0], lc[1], lc[2] - 0.5 * L), (lr[0] + F["cheek_soft"] + F["buccal"], lr[1], lr[2] + 0.5 * L))
    muzzle = Ellipsoid(sto + v3(0, 0.0230 - pg, 0.0025), (0.0270, 0.0240, 0.0265))
    cw = F["chin_w"]
    chin_c = v3(0, -0.1115 - F["chin_fwd"] - 0.4 * pg, 1.3890 - L - 0.4 * F["chin_h"])
    chin = Ellipsoid(chin_c, (cw, S["chin_r"][0], S["chin_r"][1] + 0.5 * F["chin_h"]))
    center = Union([cr, mid, low, muzzle, chin], k=S["k_center"])
    ang = F["jaw_angle"]
    jx, jr = F["jaw_x"], F["jaw_r"]
    sides = []
    for s in (1, -1):
        zc = v3(s * F["zyg_x"], -0.0837 - F["zyg_fwd"] - 0.4 * F["midface"], 1.4633 + F["zyg_z"])
        zr = F["zyg_r"]
        zs = S["zyg_scale"]
        zyg = Ellipsoid(zc, (zr * zs[0], zr * zs[1], zr * zs[2]), frame_from(v3(0, 0.15, 1), v3(s, -0.45, 0)))
        if S["zyg_arch"] > 0:
            # the cheekbone as a ridge running back along the zygomatic arch toward the ear (a plane
            # change rather than a round bump casting a round shadow)
            arch = RoundCone(zc + v3(-s * 0.004, -0.004, 0.0), zc + v3(s * 0.016, 0.040, -0.002),
                             zr * 0.85 * S["zyg_arch"], zr * 0.55 * S["zyg_arch"])
            zyg = Union([zyg, arch], k=0.010)
        mal = F["malar"] * S["malar_scale"]
        malar = Ellipsoid(v3(s * 0.0310, -0.1015 - F["midface"], 1.4560), (mal * 1.35, mal * 0.72, mal * 1.05),
                          frame_from(v3(s * 0.35, 0.2, 1), v3(s, 0, 0)))
        g = v3(s * jx, hb[1] - 0.029 - 0.003 * ang, hb[2] - 0.047 - 0.6 * L - 0.002 * ang)
        cond = v3(s * (jx + 0.009), hb[1] - 0.008, hb[2] + 0.004)
        front = v3(s * (cw - 0.0015), chin_c[1] + 0.0075, chin_c[2] - 0.002)
        mand = Union([RoundCone(g, cond, jr * (1.0 + 0.10 * ang), jr * 0.70),
                      RoundCone(g, front, jr * (1.0 + 0.10 * ang), jr * S["mand_front"])], k=S["mand_k"])
        # brow ridge on the supraorbital margin (prominence = F["brow"] beyond the cranium)
        br = S["brow_r"]
        a = _on_cranium(K, s * 0.0150, 1.4995 + F["brow_h"], br - F["brow"])
        b = _on_cranium(K, s * 0.0440, 1.4985 + F["brow_h"], br * 0.8 - 0.6 * F["brow"])
        brow = RoundCone(a, b, br, br * 0.8)
        # cheek: the soft tissue from the malar pad down to the jaw (no step below the zygoma)
        cf = F["buccal"] + 0.5 * F["cheek_soft"]
        chr_ = S["cheek_r"]
        cheek = Ellipsoid(v3(s * 0.0360, -0.0880 - 0.5 * F["midface"], 1.4390), (chr_[0] + cf, chr_[1] + cf, chr_[2]),
                          frame_from(v3(s * 0.25, 0.1, 1), v3(s, 0, 0)))
        # masseter: the side of the face between the zygomatic arch and the jaw angle
        mr = S["mass_r"]
        mass = Ellipsoid(v3(s * (S["mass_x"] + 0.4 * (F["jaw_x"] - 0.0455)), -0.0500, 1.4330),
                         (mr[0] + 0.5 * cf, mr[1], mr[2]), frame_from(v3(0, 0.25, 1), v3(s, 0, 0)))
        side = [zyg, malar, cheek, mass]
        if S["tmj_fill"] > 0:
            # the hollow in front of the ear below the zygomatic arch, filled (a smooth side plane)
            side.append(Ellipsoid(v3(s * 0.0575, -0.0300, 1.4500), (0.0090 * S["tmj_fill"], 0.0140, 0.0130)))
        sides.append(Union([Union(side, k=S["k_side"]), mand, brow], k=S["k_side_all"]))
    face = SymUnion(center, sides[0], sides[1], k=S["k_face"])
    # glabella fullness (male brow)
    if F["glabella"] > 0:
        face = Union([face, Sphere(_on_cranium(K, 0.0, 1.4990, 0.0080 - F["glabella"]), 0.0080)], k=0.008)
    # orbits and the nasal root saddle
    sc = F["socket"]
    orbits = [Ellipsoid(v3(s * 0.0305, -0.1140 + 0.004 * (sc - 1.0), 1.4832),
                        (0.0182 * sc, 0.0160, 0.0142 * sc)) for s in (1, -1)]
    saddle = Ellipsoid(v3(0, -0.1318 + F["nasion"], 1.4865), (0.0115, 0.0072, 0.0100))
    face = Sub(face, Union(orbits + [saddle], k=0.004), k=0.013)
    if S["submental"] > 0:
        # a clean plane under the chin and the jaw (from the menton back to the throat), cutting the
        # soft tissue that rounds the jaw into the neck; the neck's own blend rounds the junction
        mz = chin_c[2] - S["chin_r"][1] - 0.5 * F["chin_h"]
        p0 = v3(0, chin_c[1], mz + S["submental"])
        # (Plane: n.p <= d inside) below the plane, in front of the jaw angle
        # and between the two halves of the mandible (its lower border stays the jaw line)
        n = v3(0, 0.22, 1.0)
        xw = S["submental_x"]
        cut = Inter(Inter(Plane(n, p0), Plane(v3(0, 1.0, 0), v3(0, hb[1] - 0.030, 0)), k=0.01),
                    Inter(Plane(v3(1.0, 0, 0), v3(xw, 0, 0)), Plane(v3(-1.0, 0, 0), v3(-xw, 0, 0)), k=0.0), k=0.012)
        face = Sub(face, cut, k=S["submental_k"])
    return face


def _nose(K, F, base):
    rot = math.radians(F["tip_up"])
    tip = v3(0, -0.1395 - F["tip_proj"], 1.4519) + v3(0, -0.35 * F["nose_len"], -0.9 * F["nose_len"])
    tip = tip + v3(0, 0.0, 0.010 * math.sin(rot))
    bw = F["bridge_w"]
    tr = F["tip_r"]
    root = v3(0, -0.1245 - F["nasion"] + bw * 0.95, 1.4860)
    supra = v3(0, tip[1] + 0.0045 + bw * 1.1 - 0.6 * F["dorsum"], tip[2] + 0.0068)
    mid = lerp(root, supra, 0.52) + v3(0, -F["dorsum"] - F["hump"], 0)
    dorsum = Union([RoundCone(root, mid, bw * 0.95, bw * 1.05),
                    RoundCone(mid, supra, bw * 1.05, bw * 1.12)], k=0.004)
    nw = F["nose_w"]
    walls = Ellipsoid(lerp(root, tip, 0.60) + v3(0, 0.0125, -0.0010),
                      (0.0085 + 0.35 * (nw - 0.0152), 0.0100, 0.0190), frame_from(tip - root, v3(1, 0, 0)))
    # the nasal root between the eyes, sloping into the medial orbits
    radix = Ellipsoid(v3(0, -0.1150 - 0.6 * F["nasion"], 1.4825), (0.0118 + bw * 0.4, 0.0080, 0.0125))
    lobule = Ellipsoid(tip + v3(0, tr, 0.0003), (tr * 1.32, tr * 1.05, tr * 1.0))
    ar = F["ala_r"]
    # alae: wings along the nostrils, long axis forward (local z), lateral x, vertical y
    # alae: wings along the nostrils (local z forward and in, x lateral, y up), set back at
    # the side of the nasal base and blended into the lobule
    alae = [Ellipsoid(v3(s * (nw - ar * 0.62), tip[1] + 0.0135, tip[2] - 0.0045),
                      (ar * 0.62, ar * 0.95, ar * 1.30), frame_from(v3(-s * 0.55, -1, 0.35), v3(s, 0, 0)))
            for s in (1, -1)]
    sn = v3(0, -0.1220 + 0.0025, 1.4428)
    colum = RoundCone(tip + v3(0, tr * 0.9, -tr * 0.72), sn, 0.0021, 0.0025)
    nose = SymUnion(Union([Union([dorsum, radix], k=0.006), walls, lobule, colum], k=0.0045), alae[0], alae[1], k=0.0065)
    ns = F["nostril"]
    nostrils = [Ellipsoid(v3(s * (0.0046 + 0.25 * (nw - 0.0152)), tip[1] + 0.0098, tip[2] - 0.0077),
                          (0.0026 * ns, 0.0015 * ns, 0.0048 * ns),
                          frame_from(v3(s * 0.20, -1, 0.25), v3(s, 0, 0))) for s in (1, -1)]
    return nose, Union(nostrils, k=0), tip


def lips_node(K, F):
    """The vermilion (upper lip with a tubercle, lower lip), bent along the dental arch."""
    sto = mouth_landmarks(K, F)["stomion"]
    mw = F["mouth_w"]
    up_f, lo_f = F["lip_up"], F["lip_lo"]
    pg = F["prog"]
    ul = _bent_ellipsoid(v3(0, sto[1] + 0.0002 - pg - 0.6 * up_f, sto[2] + 0.0034 + 0.3 * up_f),
                         (mw * 0.95, 0.0050 + 0.8 * up_f, 0.0040 + 0.7 * up_f), tilt=0.35)
    tub = Ellipsoid(v3(0, sto[1] - 0.0023 - pg - 0.8 * up_f, sto[2] + 0.0011), (0.0055, 0.0022 + 0.4 * up_f, 0.0020))
    ll = _bent_ellipsoid(v3(0, sto[1] + 0.0017 - pg - 0.6 * lo_f, sto[2] - 0.0056 - 0.35 * lo_f),
                         (mw * 0.88, 0.0055 + 0.8 * lo_f, 0.0048 + 0.8 * lo_f), tilt=-0.30)
    return Union([ul, tub, ll], k=0.0025)


def _mouth(K, F, base):
    """Lips and philtral columns; the seam and commissure cuts."""
    sto = mouth_landmarks(K, F)["stomion"]
    mw = F["mouth_w"]
    pg = F["prog"]
    lips = lips_node(K, F)
    ph = F["philtrum"]
    cols = []
    for s in (1, -1):
        za, zb = 1.4405, sto[2] + 0.0074 + 0.3 * F["lip_up"]
        xa, xb = s * 0.0040, s * 0.0054
        ya, yb = front_y(base, xa, za), front_y(base, xb, zb)
        r = 0.0014 * ph
        cols.append(RoundCone(v3(xa, ya + r - 0.0006 * ph, za), v3(xb, yb + r - 0.0008 * ph, zb), r, r * 1.1))
    mouth = SymUnion(lips, cols[0], cols[1], k=0.0022)

    def seam(X, Y, Z):
        ax = np.abs(X)
        yc = sto[1] - pg + ARCH_K * ax * ax
        zc = sto[2] - 0.04 * ax
        dy = Y - yc
        d_sheet = np.abs(Z - zc) - 0.00028
        d_w = ax - (mw + 0.0003)
        d_depth = np.maximum(-dy - 0.005, dy - 0.008)
        return np.maximum(np.maximum(d_sheet, d_w), d_depth)
    seam_n = Fn(seam, sto + v3(-mw - 0.003, -0.012, -0.004), sto + v3(mw + 0.003, 0.02, 0.004))
    corners = Union([Sphere(v3(s * (mw + 0.0003), sto[1] - pg + ARCH_K * mw * mw + 0.0010, sto[2] - 0.0010), 0.0013)
                     for s in (1, -1)], k=0)
    return mouth, seam_n, corners, sto


def _ear(K, s, F):
    """Pinna: a plate with a helix rim, scapha and concha hollows, tragus and lobe."""
    hb = K["headb"]
    es = F["ear"]
    c = v3(s * (0.0705 + 0.0015 * F["ear_out"]), hb[1] + 0.0045, hb[2] + 0.0185)
    # plate normal points out and a little forward; the long axis tilts back
    R = frame_from(v3(0, 0.26, 1.0), v3(s, -0.28 - 0.25 * F["ear_out"], 0))   # columns: out, back, up
    ox, bk, up = R[:, 0], R[:, 1], R[:, 2]
    plate = Ellipsoid(c + ox * 0.0035, (0.0036 * es, 0.0168 * es, 0.0292 * es), R)
    root = Ellipsoid(c - ox * 0.004 - bk * 0.004, (0.0070, 0.0100 * es, 0.0200 * es), R)
    lobe = Ellipsoid(c + ox * 0.0028 - up * 0.0205 * es - bk * 0.0005, (0.0040, 0.0072 * es, 0.0068 * es), R)
    tragus = Ellipsoid(c + ox * 0.0040 - bk * 0.0078 * es - up * 0.0035, (0.0028, 0.0030, 0.0042), R)
    pinna = Union([Union([plate, lobe], k=0.004), root, tragus], k=0.005)
    scapha = Ellipsoid(c + ox * 0.0078 + bk * 0.0010 + up * 0.0045 * es, (0.0030, 0.0128 * es, 0.0222 * es), R)
    concha = Ellipsoid(c + ox * 0.0060 - bk * 0.0022 * es - up * 0.0020 * es, (0.0038, 0.0068 * es, 0.0092 * es), R)
    return Sub(Sub(pinna, scapha, k=0.0016), concha, k=0.0018)


def head_node(K, F=None, S=None, ears=True):
    """The v2 head SDF for face params F (default FACE_BASE) and structural constants S
    (default STRUCT, the realistic head); ears=False leaves the ears off (lib/stylize.py tells
    the ear's vertices from the head's by it)."""
    F = F or FACE_BASE
    S = S or STRUCT
    base = _base(K, F, S)
    nose, nostrils, tip = _nose(K, F, base)
    mouth, seam, corners, sto = _mouth(K, F, base)
    face = base
    # the lids in the orbits
    eyes = [_eye_region(K, s, F, S) for s in (1, -1)]
    face = SymUnion(face, eyes[0][0], eyes[1][0], k=S["k_lids"])
    # nose and mouth (tighter blends: an alar crease and a vermilion border)
    face = Union([face, nose], k=S["k_nose"])
    face = Union([face, mouth], k=S["k_mouth"])
    face = Sub(face, nostrils, k=0.0012)
    face = Sub(face, Union([corners, seam], k=0.0006), k=0.0005)
    # ears
    if ears:
        face = SymUnion(face, _ear(K, 1, F), _ear(K, -1, F), k=0.0045)
    # upper-lid creases, the fissures and the eye pockets
    face = Sub(face, Union([eyes[0][3], eyes[1][3]], k=0), k=0.0012)
    face = Sub(face, Union([eyes[0][2], eyes[1][2]], k=0), k=0.0007)
    face = Sub(face, Union([eyes[0][4], eyes[1][4]], k=0), k=0.0003)
    return face


# ---------------------------------------------------------------------------
# Landmarks for masks and cards
# ---------------------------------------------------------------------------
def mouth_landmarks(K, F=None):
    F = F or FACE_BASE
    uc, lc = K["lip_upper_center"], K["lip_lower_center"]
    sto = v3(0, (uc[1] + lc[1]) * 0.5 - 0.0005, (uc[2] + lc[2]) * 0.5 + 0.0003)
    return {"stomion": sto, "mouth_w": F["mouth_w"]}


def margin_points(K, s, F=None, which="up", n=24, grow=0.0):
    """Points along a lid margin (outer edge of the margin, radius EYE_R + LID_GAP + LID_T + grow)."""
    F = F or FACE_BASE
    c = eye_center(K, s)
    t = np.linspace(-0.97, 0.97, n)
    up, lo = margins(t, F)
    el = np.radians(up if which == "up" else lo)
    az = np.radians(AZ_C + t * AZ_H)
    r = EYE_R + LID_GAP + LID_T + grow
    d = np.stack([s * np.cos(el) * np.sin(az), -np.cos(el) * np.cos(az), np.sin(el)], 1)
    # follow the corneal bulge near the centre
    bulge = np.clip(np.cos(np.radians(np.hypot(np.degrees(az), np.degrees(el)))) - np.cos(np.radians(29)), 0, None)
    r = r + bulge * 0.0045
    return c + d * r[:, None], t


# ---------------------------------------------------------------------------
# Eye warps (lid features and the blink)
# ---------------------------------------------------------------------------
def eye_warp(V, K, F, dF, blink=0.0):
    """Displacements of vertices V that move the lid margins from the params F to F + dF
    (canthal tilt, fissure heights, medial canthus, epicanthic fold) and close the lids by
    `blink` (0..1). Each vertex near an eye rotates about the eye centre at a constant
    radius: margins map onto margins, the lid skin between them stretches smoothly."""
    V = np.asarray(V, float)
    D = np.zeros_like(V)
    G = dict(F)
    for k, v in dF.items():
        G[k] = G[k] + v if k != "epicanthus" else v
    for s in (1, -1):
        c = eye_center(K, s)
        t, el, r, az = eye_local(V, c, s)
        up0, lo0 = margins(t, F)
        up1, lo1 = margins(t, G)
        if blink > 0:
            meet = lo1 + 0.22 * (up1 - lo1)            # the lids meet a little below the middle
            up1 = up1 + (meet - up1) * blink
            lo1 = lo1 + (meet + 0.6 - lo1) * blink
        epi = G.get("epicanthus", 0.0) - F.get("epicanthus", 0.0)
        if epi:
            # the upper lid's medial part drapes over the medial canthus: the margin reaches the
            # lower margin further laterally, the skin passing in front of the canthus
            w = smoothstep(0.0, -0.9, t) * epi
            up1 = up1 - w * (up1 - lo1 + 2.0) * 1.05
        mid0 = 0.5 * (up0 + lo0)
        # elevation shift: interpolated between the margins, decaying above / below them
        span0 = np.maximum(up0 - lo0, 0.5)
        a = np.clip((el - lo0) / span0, 0.0, 1.0)
        inside = (up1 - up0) * a + (lo1 - lo0) * (1 - a)
        above = (up1 - up0) * smoothstep(34.0, 0.0, el - up0)
        below = (lo1 - lo0) * smoothstep(-26.0, 0.0, el - lo0)
        dEl = np.where(el > up0, above, np.where(el < lo0, below, inside))
        fade = smoothstep(1.45, 1.02, np.abs(t)) * smoothstep(EYE_R + 0.0115, EYE_R + 0.0045, r)
        fade = fade * ((-(V[:, 1] - c[1])) > -0.004)
        dEl = dEl * fade
        # the epicanthic fold also lifts off the canthus a little (in front of the lower lid)
        dR = np.zeros(len(V))
        if epi:
            wr = smoothstep(0.0, -0.9, t) * smoothstep(up0 + 16.0, up0 - 2.0, el) * (el > lo0 - 3.0) * epi
            dR = 0.0014 * wr * fade
        if not np.any(np.abs(dEl) > 1e-6) and not np.any(dR):
            continue
        idx = np.nonzero((np.abs(dEl) > 1e-6) | (dR > 0))[0]
        ez = np.radians(el[idx] + dEl[idx])
        azr = np.radians(az[idx])
        rr = r[idx] + dR[idx]
        d = np.stack([s * np.cos(ez) * np.sin(azr), -np.cos(ez) * np.cos(azr), np.sin(ez)], 1)
        D[idx] += c + d * rr[:, None] - V[idx]
    return D


def mouth_warp(V, K, F, dw):
    """Widens the mouth by `dw` metres per side: the lips and the skin around them spread
    along x, and follow the dental arch back (ARCH_K), fading out 1.2 cm beyond the corners.
    (A projected shape cannot move the corners sideways; this warp can.)"""
    V = np.asarray(V, float)
    sto = mouth_landmarks(K, F)["stomion"]
    mw = F["mouth_w"]
    d = V - sto
    r = np.sqrt((d[:, 0] / (mw + 0.012)) ** 2 + (d[:, 1] / 0.020) ** 2 + (d[:, 2] / 0.016) ** 2)
    w = smoothstep(1.0, 0.45, r) * (d[:, 1] < 0.012)
    s = dw / mw
    x1 = d[:, 0] * (1.0 + s * w)
    D = np.zeros_like(V)
    D[:, 0] = x1 - d[:, 0]
    D[:, 1] = ARCH_K * (x1 * x1 - d[:, 0] * d[:, 0]) * w * 0.8
    return D


def prognathism_warp(V, K, F, amount):
    """Alveolar prognathism as a warp: the lips, the mouth seam and the skin of the muzzle
    move forward by `amount` metres, fading out 3.6 cm to the side, over the nose base (3.6 cm
    above the stomion), toward the chin (about 0.3 of it at the chin, as the SDF moves its
    chin 0.4 of the muzzle) and 4 cm behind the lip front. A projected shape put the vertices
    by the mouth seam on the wrong lip and folded the vermilion; a smooth warp cannot fold."""
    V = np.asarray(V, float)
    sto = mouth_landmarks(K, F)["stomion"]
    d = V - sto
    fx = smoothstep(0.036, 0.008, np.abs(d[:, 0]))
    fz = np.where(d[:, 2] > 0, smoothstep(0.036, 0.004, d[:, 2]), smoothstep(0.060, 0.008, -d[:, 2]))
    fy = smoothstep(0.040, 0.018, d[:, 1])          # the front of the face (y grows backward)
    D = np.zeros_like(V)
    D[:, 1] = -amount * fx * fz * fy
    return D


def lid_mask(V, K, F, inner_deg=4.0, outer_deg=14.0):
    """0 on the lid margins, the fissure and the pocket; 1 away from them (projected shapes of
    the other features are faded out there, so a margin never slides)."""
    V = np.asarray(V, float)
    m = np.ones(len(V))
    for s in (1, -1):
        c = eye_center(K, s)
        t, el, r, az = eye_local(V, c, s)
        up, lo = margins(t, F)
        d = np.maximum(np.maximum(el - up, lo - el), (np.abs(t) - 1.0) * AZ_H)
        near = smoothstep(inner_deg, outer_deg, d)
        near = np.maximum(near, smoothstep(EYE_R + 0.0060, EYE_R + 0.0100, r))
        near = np.where((-(V[:, 1] - c[1])) < -0.006, 1.0, near)
        near = np.where(r < EYE_R + LID_GAP + 0.0010, 0.0, near)       # the pocket (hidden)
        m = np.minimum(m, near)
    return m


# ---------------------------------------------------------------------------
# Face features (shape keys): parameter deltas projected, or warps
# ---------------------------------------------------------------------------
FACE_FEATURES = {
    "breadth": {"zyg_x": +0.0045, "zyg_r": +0.001},
    "length": {"face_len": +0.0065, "chin_h": +0.002},
    "jaw_width": {"jaw_x": +0.0055, "jaw_r": +0.0012},
    "jaw_angle": {"jaw_angle": +1.0, "jaw_r": +0.001},
    "chin_projection": {"chin_fwd": +0.0045},
    "chin_width": {"chin_w": +0.0045},
    "chin_height": {"chin_h": +0.0045},
    "cheekbones": {"zyg_fwd": +0.0030, "zyg_r": +0.0015, "zyg_z": +0.0015},
    "midface": {"midface": +0.0035},
    "cheek_fullness": {"malar": +0.0025, "buccal": +0.0035, "cheek_soft": +0.0015},
    "prognathism": {"prog": +0.0045},
    "brow_ridge": {"brow": +0.0035, "glabella": +0.0025},
    "nasal_root": {"nasion": +0.0045, "bridge_w": +0.0006},
    "nose_bridge": {"dorsum": +0.0030},
    "nose_hump": {"hump": +0.0022},
    "nose_width": {"nose_w": +0.0048, "ala_r": +0.0010, "nostril": +0.20},
    "nose_length": {"nose_len": +0.0055},
    "nose_tip": {"tip_proj": +0.0035, "tip_r": +0.0006},
    "nose_upturn": {"tip_up": +12.0},
    "lips_upper": {"lip_up": +0.0022},
    "lips_lower": {"lip_lo": +0.0024},
    "lid_crease": {"crease_h": +9.0, "crease_depth": +0.0006},
    "lid_fold": {"lid_fold": +0.0034, "crease_depth": -0.0011},
    "eye_depth": {"socket": +0.12, "brow": +0.0012},
    "under_eye": {"under_eye": +0.0015},
    "ears": {"ear": +0.10, "ear_out": +1.0},
}

# the mouth width is a warp too (lib/face.mouth_warp), metres per side
MOUTH_WARP = {"mouth_width": 0.0038}
# prognathism is built as a warp (prognathism_warp), not projected: the lip front moves this
# far forward at weight 1 (about what the projected FACE_FEATURES["prognathism"] gave the
# lip bodies before it folded the vermilion by the mouth seam)
PROG_LIP_MOVE = 0.0032

# warp features: margin parameter deltas
FACE_WARPS = {
    "eye_tilt": {"canthal_tilt": +8.0},
    "eye_height": {"fissure_up": +6.0, "fissure_lo": +4.0},
    "epicanthus": {"epicanthus": 1.0},
}


# ---------------------------------------------------------------------------
# Soft tissue smoothing (mesh post-process)
# ---------------------------------------------------------------------------
def smooth_weights(V, K, F):
    """Per-vertex smoothing weight: 1 on the broad skin (forehead, temples, cheeks, jaw,
    neck), 0 on the details that must stay crisp (lid margins and pockets, the vermilion
    border and mouth seam, nostrils and alae, ears)."""
    from .sdf import peval
    V = np.asarray(V, float)
    w = np.ones(len(V))
    for s in (1, -1):
        c = eye_center(K, s)
        d = np.linalg.norm(V - c, axis=1)
        w = np.minimum(w, smoothstep(EYE_R + 0.0045, EYE_R + 0.0110, d))
        hb = K["headb"]
        e = v3(s * 0.072, hb[1] + 0.004, hb[2] + 0.018)
        w = np.minimum(w, smoothstep(0.022, 0.034, np.linalg.norm(V - e, axis=1)))
    near = np.linalg.norm(V - v3(0, -0.12, 1.44), axis=1) < 0.05
    if near.any():
        lips = peval(lips_node(K, F), V[near])
        wl = smoothstep(0.0015, 0.0055, lips)
        tip = v3(0, -0.1395 - F["tip_proj"], 1.4519)
        dn = np.linalg.norm((V[near] - (tip + v3(0, 0.010, -0.004))) * v3(1, 1, 1.3), axis=1)
        wn = 0.25 + 0.75 * smoothstep(0.012, 0.022, dn)
        w[near] = np.minimum(w[near], np.minimum(wl, wn))
    return w


def taubin(V, E, w, iters=24, lam=0.50, mu=-0.53):
    """Volume-preserving (Taubin) smoothing of V over edges E, per-vertex weights w (0 = fixed).
    Linear in V for fixed E and w, so smooth(V + D) - smooth(V) = smooth(D) - (see
    taubin_delta for shape deltas)."""
    V = np.asarray(V, float).copy()
    E = np.asarray(E, int)
    n = len(V)
    deg = np.bincount(E.ravel(), minlength=n).astype(float)
    deg = np.maximum(deg, 1.0)
    w = np.asarray(w, float)[:, None]
    for i in range(iters):
        for f in (lam, mu):
            acc = np.zeros_like(V)
            np.add.at(acc, E[:, 0], V[E[:, 1]])
            np.add.at(acc, E[:, 1], V[E[:, 0]])
            V = V + f * w * (acc / deg[:, None] - V)
    return V


def taubin_delta(D, E, w, iters=24, lam=0.50, mu=-0.53):
    """The smoothing operator applied to a displacement field (it is linear)."""
    return taubin(D, E, w, iters, lam, mu)


# ---------------------------------------------------------------------------
# Mesh sizing
# ---------------------------------------------------------------------------
def head_sizing(K, F=None, scale=1.0):
    """Target edge length on the head: fine at the lid margins (1.4 mm), lips (1.6 mm), nose
    (2.3 mm), ears (3 mm), 4.2 mm over the face and 8.5 mm over the cranium and nape (the hair
    covers them); the hidden part of the eye pockets is coarse."""
    F = F or FACE_BASE
    hb = K["headb"]
    sto = mouth_landmarks(K, F)["stomion"]
    ecs = [(s, eye_center(K, s)) for s in (1, -1)]

    def fn(P):
        P = np.asarray(P, float)
        L = np.full(len(P), 0.0085)
        face = smoothstep(hb[1] - 0.030, hb[1] - 0.045, P[:, 1]) * smoothstep(1.555, 1.535, P[:, 2]) \
            * smoothstep(1.350, 1.365, P[:, 2])
        L = L + (0.0042 - L) * face
        neck = smoothstep(1.37, 1.34, P[:, 2])
        L = L + (0.0065 - L) * neck
        for s, c in ecs:
            t, el, r, az = eye_local(P, c, s)
            up, lo = margins(t, F)
            dm = np.minimum(np.abs(el - up), np.abs(el - lo))
            fine = np.where(dm < 7.0, 0.0014, 0.0023)
            fine = np.where((r < EYE_R + LID_GAP + 0.0006) & (dm > 9.0), 0.0045, fine)
            near = np.linalg.norm(P - c, axis=1) < 0.019
            L = np.where(near, np.minimum(L, fine), L)
        dl = np.sqrt((P[:, 0] / 1.5) ** 2 + ((P[:, 1] - sto[1]) / 1.3) ** 2 + (P[:, 2] - sto[2]) ** 2)
        L = np.where(dl < 0.0135, np.minimum(L, 0.0016), L)
        tip = v3(0, -0.1395, 1.4519)
        dn = np.linalg.norm((P - (tip + v3(0, 0.010, -0.003))) * v3(1, 1, 0.8), axis=1)
        L = np.where(dn < 0.017, np.minimum(L, 0.0023), L)
        for s in (1, -1):
            e = v3(s * 0.073, hb[1] + 0.004, hb[2] + 0.018)
            L = np.where(np.linalg.norm((P - e) * v3(1.0, 1.0, 0.75), axis=1) < 0.026, np.minimum(L, 0.0030), L)
        return L * scale
    return fn
