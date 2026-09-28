"""Stylized head (lib v1 addition, 2026-09-26): the `style` shape of body.glb.

The character creator's default Face style is Stylized: the same anatomical head (lib/face.py,
every face feature and preset of lib/body/peoples.py), made bolder and simpler the way a
hand-sculpted game head is: clear planes where the brow, the cheekbones, the side of the face
and the jaw turn, a crisp jaw line over a clean neck, a firm chin, a clear brow ridge, and
slightly larger eyes (the whole eye region scaled about the eye centre, lids and eyeball
together, so the shape of each person's eyes is kept).

One rule for everybody. The `style` shape is a single fixed delta, computed once on the base
head and added on top of the face features; the features (face_*) keep the weights of the
realistic face. It never scales, amplifies or reduces a face feature, so what differs between
two people, and between two peoples, is exactly what differs in the realistic set: no feature
of any people is exaggerated or smoothed away (tests/customizer/test_stylized.gd checks that
the stylized look of every preset has the same feature weights and the same `style` weight).

The delta is made of "brushes" on the base (female) vertices, as a sculptor would work:

    planarize   pull the skin in a region toward a plane (both sides: bumps cut, dents filled)
    inflate     push the skin out along its normal
    grab        move a region by a vector
    smooth      Taubin smoothing of a region (removes the lumps of the blended SDF masses)

each with a smooth falloff, mirrored for the right side. The whole field fades out toward the
hairline (the hair caps and hats fit the realistic head, and the cranium is unchanged), behind
the jaw angle and down the neck, so no hair, hat or garment needs a new shape. The eye scale is
a separate warp (eye_scale_delta) because the eyeball (Face mesh), the lashes and the blink
(the `blink_style` corrective) follow it exactly.

All positions are Blender armature space (z up, the character faces -y); K = the rig's joints at
null-add (lib/rig.Skel or a plain dict of the same names).
"""

import numpy as np

from . import face as FC
from .sdf import smoothstep, v3

SMOOTH_ITERS = 160         # Taubin iterations of the smooth brushes
FAIR_ITERS = 300           # relaxation steps of the fair brushes
FAIR_IN, FAIR_OUT = 0.0050, 0.0065     # their largest move in / out along the normal (m)
EYE_SCALE = 1.15            # eye region scale (eyeball, lids, lashes) about the eye centre, across the view ...
EYE_SCALE_DEPTH = 1.04      # ... and in depth (less: the cheek below the eye is not pushed forward)
EYE_R_IN = FC.EYE_R + 0.0060     # pure scale inside this radius (the eyeball and the lids) ...
EYE_R_OUT = FC.EYE_R + 0.0300    # ... fading to none here (past the orbit rim: a gentle falloff)
UNDER_EYE_R = (0.021, 0.015, 0.012)    # the under-eye fairing region (below the lower lid) ...
UNDER_EYE_MOVE = 0.0030                # ... and its largest move along the normal (m)
EAR_SCALE = 0.88            # the ears a little smaller (about the ear root) ...
EAR_TUCK = 0.30             # ... and closer to the head (this share of the ear's protrusion)


def _v(K, n):
    return np.asarray(K[n], float)


def vertex_normals(V, F):
    N = np.zeros_like(V)
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    for k in range(3):
        np.add.at(N, F[:, k], fn)
    return N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)


def _falloff(V, c, r):
    """1 at the centre of the ellipsoid (c, radii r, axis aligned), 0 at its surface, smooth."""
    q = np.sqrt((((V - c) / np.asarray(r, float)) ** 2).sum(1))
    return smoothstep(1.0, 0.25, q)


def _mirror(p):
    p = np.array(p, float)
    p[..., 0] *= -1.0
    return p


# ---------------------------------------------------------------------------
# Brushes (left side values; mirrored for the right side)
# ---------------------------------------------------------------------------
def brushes(K):
    """The brush list: (kind, params). Positions from the rig's facial joints (they sit a few mm
    under the skin; the brushes only need them as anchors)."""
    eb = _v(K, "l_brow_mid")
    cheek = _v(K, "l_upper_cheek")
    jaw_mid = _v(K, "l_jawline_mid")
    G, C = v3(0.058, -0.040, 1.397), v3(0.017, -0.113, 1.379)       # gonion, chin side (skin)
    return [
        # the lumps of the blended SDF masses levelled over the cheeks, the side of the face, the
        # jaw and under it (not the eyes, nose, lips or ears: see detail_mask)
        ("fair", dict(c=v3(0.047, -0.078, 1.425), r=(0.036, 0.055, 0.050), amount=1.0)),
        ("fair", dict(c=v3(0.0, -0.090, 1.378), r=(0.055, 0.045, 0.026), amount=0.8)),
        # the side of the face: one smooth plane from the cheekbone to the jaw and the ear
        ("fair", dict(c=v3(0.052, -0.058, 1.446), r=(0.028, 0.042, 0.042), amount=1.0)),
        # the lower side of the face, from below the cheekbone to the jaw angle: one clean plane
        ("fair", dict(c=v3(0.050, -0.050, 1.430), r=(0.030, 0.050, 0.045), amount=1.0)),
        # the small creases of the blended masses smoothed away (volume kept) over the cheek and the
        # side of the face, and along the jaw line and under the chin
        ("smooth", dict(c=v3(0.045, -0.070, 1.425), r=(0.035, 0.060, 0.050), amount=1.0)),
        ("smooth", dict(c=v3(0.0, -0.095, 1.385), r=(0.050, 0.050, 0.030), amount=1.0)),
    ]


def _apply_brush(kind, prm, V, N, D, s):
    c = prm["c"] if s > 0 else _mirror(prm["c"])
    w = _falloff(V, c, prm["r"])
    idx = np.nonzero(w > 1e-4)[0]
    if not len(idx):
        return
    w = w[idx]
    if kind == "planarize":
        p = prm["p"] if s > 0 else _mirror(prm["p"])
        n = np.asarray(prm["n"], float)
        n = n / np.linalg.norm(n)
        if s < 0:
            n = _mirror(n)
        X = V[idx] + D[idx]
        d = (X - p) @ n
        D[idx] -= (d * w * prm["amount"])[:, None] * n
    elif kind == "inflate":
        D[idx] += N[idx] * (w * prm["amount"])[:, None]
    elif kind == "smooth":
        pass                      # applied in style_delta (needs the edges)
    elif kind == "line":
        # a ridge along the segment a -> b: out by `ridge` on the line, in by `below` at `gap` under
        # it and by `above` at `gap` over it (a crisp edge between two planes), along the normal
        a = prm["a"] if s > 0 else _mirror(prm["a"])
        b = prm["b"] if s > 0 else _mirror(prm["b"])
        ab = b - a
        L = np.linalg.norm(ab)
        t = np.clip((V[idx] - a) @ ab / (L * L), -0.2, 1.2)
        q = V[idx] - (a + t[:, None] * ab)
        up = np.asarray(prm.get("up", v3(0, 0, 1)), float)
        h = q @ up                            # signed height over the line
        g = prm["gap"]
        prof = prm["ridge"] * np.exp(-(h / (0.35 * g)) ** 2) \
            - prm["below"] * np.exp(-((h + g) / (0.5 * g)) ** 2) - prm["above"] * np.exp(-((h - g) / (0.6 * g)) ** 2)
        along = smoothstep(-0.2, 0.08, t) * smoothstep(1.2, 0.92, t)
        D[idx] += N[idx] * (prof * along * w)[:, None]
    elif kind == "grab":
        d = np.asarray(prm["d"], float)
        if s < 0:
            d = _mirror(d)
        D[idx] += w[:, None] * d


def fair(V, F, E, w, iters, step=0.5):
    """Normal-projected Laplacian relaxation of V with per-vertex weights w (0 = fixed)."""
    X = np.asarray(V, float).copy()
    E = np.asarray(E, int)
    deg = np.maximum(np.bincount(E.ravel(), minlength=len(X)).astype(float), 1.0)
    idx = np.nonzero(w > 1e-4)[0]
    ww = (w[idx] * step)[:, None]
    for i in range(iters):
        if i % 20 == 0:
            N = vertex_normals(X, F)[idx]
        acc = np.zeros_like(X)
        np.add.at(acc, E[:, 0], X[E[:, 1]])
        np.add.at(acc, E[:, 1], X[E[:, 0]])
        L = acc[idx] / deg[idx, None] - X[idx]
        X[idx] += ww * (L * N).sum(1, keepdims=True) * N
    return X


def detail_mask(V, K):
    """0 on the details the smoothing must keep (eyes and lids, nose, lips, ears), 1 elsewhere."""
    V = np.asarray(V, float)
    m = np.ones(len(V))
    for s in (1, -1):
        c = FC.eye_center(K, s)
        m = np.minimum(m, smoothstep(FC.EYE_R + 0.006, FC.EYE_R + 0.014, np.linalg.norm(V - c, axis=1)))
        e = v3(s * 0.072, _v(K, "headb")[1] + 0.004, _v(K, "headb")[2] + 0.018)
        m = np.minimum(m, smoothstep(0.024, 0.034, np.linalg.norm(V - e, axis=1)))
    tip = _v(K, "nose_tip") + v3(0, 0.004, 0.004)
    m = np.minimum(m, smoothstep(0.016, 0.024, np.linalg.norm((V - tip) * v3(1.0, 1.0, 0.7), axis=1)))
    sto = FC.mouth_landmarks(K)["stomion"]
    m = np.minimum(m, smoothstep(0.009, 0.016, np.linalg.norm((V - sto) * v3(0.72, 1.0, 1.0), axis=1)))
    return m


def region_mask(V, K):
    """1 over the face; 0 above the hairline (1.2 cm below the hair caps' hairline plane), behind
    the jaw angle and the ears, and down the neck."""
    p0, n = v3(0, -0.108, 1.528), v3(0, 0.13, 0.18) / np.linalg.norm([0.13, 0.18])
    below_hairline = smoothstep(-0.004, -0.014, (V - p0) @ n)
    front = smoothstep(0.015, -0.030, V[:, 1])
    neck = smoothstep(1.352, 1.372, V[:, 2])
    # the ears stay (the hair caps are carved round them)
    hb = _v(K, "headb")
    ears = np.ones(len(V))
    for s in (1, -1):
        e = v3(s * 0.0705, hb[1] + 0.0045, hb[2] + 0.0185)
        ears = np.minimum(ears, smoothstep(0.022, 0.034, np.linalg.norm((V - e) * v3(1.0, 1.0, 0.7), axis=1)))
    return below_hairline * front * neck * ears


# ---------------------------------------------------------------------------
# The stylized target head: the same SDF head (lib/face.py) with one fixed set of parameter
# changes for everybody (STYLE_PARAMS, added to the female base), projected like a face feature
# ---------------------------------------------------------------------------
STYLE_PARAMS = {
    # a shorter, cleaner lower face: the chin up and forward (a clear profile from the nose tip to
    # the chin), the muzzle a little back, a defined jaw angle, less soft tissue, a tapering jaw
    # on a slimmer mandible (no lumps at the jaw corners)
    "face_len": -0.0060, "chin_fwd": +0.0035, "prog": -0.0015, "jaw_angle": +0.10, "cheek_soft": -0.0010,
    "buccal": 0.0, "jaw_x": -0.0065, "jaw_r": -0.0020, "chin_w": -0.0015,
    # clear cheekbones and brow; shallower orbits (open, clear eyes rather than sunken ones)
    "zyg_fwd": +0.0015, "zyg_r": +0.0008, "brow": +0.0006, "socket": -0.25,
    # a slightly fuller mouth; small, tidy nostrils (seen from the front)
    "lip_up": +0.0004, "lip_lo": +0.0005, "nostril": -0.30,
}
# lid margins: a more open eye for everybody (eye warp, degrees)
STYLE_WARP = {"fissure_up": +1.0, "fissure_lo": +0.3}
# the mouth a little wider (mouth warp, metres per side)
STYLE_MOUTH = 0.0012


# structural constants of the stylized head (lib/face.py STRUCT): leaner lower-face masses (the
# face widest at the cheekbones, tapering to the jaw), crisper blends (clear planes where the forms
# turn), a bolder brow ridge and cheekbone, a clean plane under the chin and jaw
STYLE_STRUCT = dict(FC.STRUCT, **{
    "k_center": 0.011, "k_side": 0.016, "k_side_all": 0.013, "k_face": 0.016,
    "low_c": (0.0, -0.0600, 1.4245), "low_r": (0.0495, 0.0515, 0.0450),
    "mass_x": 0.0460, "mass_r": (0.0100, 0.0220, 0.0260), "cheek_r": (0.0200, 0.0178, 0.0258),
    "mand_k": 0.006, "mand_front": 0.78, "chin_r": (0.0100, 0.0115), "brow_r": 0.0062, "zyg_scale": (1.10, 1.25, 1.12),
    "malar_scale": 0.9, "submental": 0.007, "submental_x": 0.042, "submental_k": 0.012,
    "k_lids": 0.0055, "k_nose": 0.0028, "k_mouth": 0.0016, "lid_roll": 0.5, "under_bag": 0.55,
    "tmj_fill": 1.0, "zyg_arch": 0.0,
})


# the male fit's stylized head on top (the `style_male` shape, at the look's sex weight): a squarer,
# heroic jaw (a clean angle rather than a flared one) and a strong chin and brow (the male base
# already has the realistic differences, lib/face.py FACE_MALE)
STYLE_MALE_PARAMS = {"jaw_x": +0.0015, "jaw_angle": 0.0, "chin_w": +0.0015, "chin_fwd": +0.0006, "brow": +0.0004,
                     "zyg_fwd": +0.0005, "cheek_soft": +0.0012}


def target_node(K, P, extra=None):
    """Body SDF of the stylized target of the base P (BodyParams): the head built with
    P.face + STYLE_PARAMS (+ extra) and STYLE_STRUCT, the rest of the body unchanged."""
    from .body_shapes import body_groups, body_node
    g = body_groups(K, P)
    F = FC.add(P.face, STYLE_PARAMS)
    if extra:
        F = FC.add(F, extra)
    g["head"] = FC.head_node(K, F, STYLE_STRUCT)
    return body_node(g)


def projected_delta(V, K, P, sel, step=0.006, iters=8, extra=None):
    """Surface displacement from the base SDF of P to its stylized target at the vertices `sel` of V:
    both projected from the same points, so the head's smoothing offsets cancel."""
    from .body_shapes import body_groups, body_node
    from .sdf import project_to_surface
    base = body_node(body_groups(K, P))
    sty = target_node(K, P, extra)
    D = np.zeros_like(V)
    idx = np.nonzero(sel)[0]
    X = V[idx]
    D[idx] = project_to_surface(sty, X.copy(), step_max=step, iters=iters) \
        - project_to_surface(base, X.copy(), step_max=step, iters=iters)
    return D


def style_delta(V, F, E, K, vlab=None, P=None, smooth_iters=40, fair_on=True, final_smooth=30, extra=None):
    """The `style` delta (n, 3) of the body's vertices V (triangles F, edges E): the stylized target
    (projected, with the base params P: BodyParams of the female base), the fair brushes, the region
    mask and a final smoothing of the field (details excluded), then the eye and mouth warps and the
    eye scale. vlab (group label per vertex) limits it to the head and neck."""
    V = np.asarray(V, float)
    F = np.asarray(F, int)
    N = vertex_normals(V, F)
    D = np.zeros_like(V)
    head = V[:, 2] > 1.30
    if vlab is not None:
        head &= np.isin(np.asarray(vlab).astype(str), ["head", "neck"])
    Ff = P.face if P is not None else FC.FACE_BASE
    # the head's soft-tissue smoothing weights (body.py S): 0 on the details (lids, lips, nostrils, ears)
    sw = FC.smooth_weights(V, K, Ff) * head * smoothstep(1.35, 1.38, V[:, 2])
    if P is not None:
        Dp = projected_delta(V, K, P, head, extra=extra) * FC.lid_mask(V, K, Ff)[:, None]
        D += FC.taubin(Dp, E, sw, smooth_iters)
    # fairing: the skin in a region relaxed along its normal toward a minimal surface spanning the
    # region's rim (mean curvature flow with the rim fixed): bumps and hollows go, a plane stays
    fw = np.zeros(len(V))
    for kind, prm in brushes(K):
        if kind == "fair" and fair_on:
            for s in (1, -1):
                c = prm["c"] if s > 0 else _mirror(prm["c"])
                fw = np.maximum(fw, _falloff(V, c, prm["r"]) * prm["amount"])
    if fw.max() > 0:
        Df = fair(V + D, F, E, fw * detail_mask(V, K), FAIR_ITERS) - (V + D)
        # at most FAIR_IN in and FAIR_OUT out along the normal: level the lumps, keep the masses
        dn = (Df * N).sum(1)
        Df = N * np.clip(dn, -FAIR_IN, FAIR_OUT)[:, None]
        D += FC.taubin(Df, E, (fw > 1e-4) * 1.0, 20)
    # the under-eye: the lower lid's roll, the tear trough and the lid-cheek junction relaxed into one
    # smooth plane from just below the lid margin down to the cheek (the margins themselves kept):
    # no puffy ring round the (larger) eye
    uw = np.zeros(len(V))
    for s in (1, -1):
        c = FC.eye_center(K, s)
        uw = np.maximum(uw, _falloff(V, c + v3(s * 0.002, -0.004, -0.016), UNDER_EYE_R))
    uw *= FC.lid_mask(V, K, Ff, 5.0, 12.0) * head
    if fair_on and uw.max() > 0:
        Du = fair(V + D, F, E, uw, FAIR_ITERS) - (V + D)
        dn = (Du * N).sum(1)
        Du = N * np.clip(dn, -UNDER_EYE_MOVE, UNDER_EYE_MOVE)[:, None]
        D += FC.taubin(Du, E, (uw > 1e-4) * 1.0, 20)
    # smoothing: the lumps of the blended masses on the side of the face (between the cheekbone, the
    # ear and the jaw) levelled into one plane: Taubin smoothing of the positions (volume kept)
    sw2 = np.zeros(len(V))
    for kind, prm in brushes(K):
        if kind == "smooth":
            for s in (1, -1):
                c = prm["c"] if s > 0 else _mirror(prm["c"])
                sw2 = np.maximum(sw2, _falloff(V, c, prm["r"]) * prm["amount"])
    if sw2.max() > 0:
        X = V + D
        D += FC.taubin(X, E, sw2 * detail_mask(V, K), SMOOTH_ITERS) - X
    for kind, prm in brushes(K):
        for s in (1, -1):
            if kind in ("fair", "smooth") or (abs(prm["c"][0]) < 1e-6 and s < 0):
                continue          # centred brushes once
            _apply_brush(kind, prm, V, N, D, s)
    m = region_mask(V, K) * head
    D *= m[:, None]
    if final_smooth:
        # no creases where the masks and the masses meet
        D = FC.taubin(D, E, sw * smoothstep(1.34, 1.36, V[:, 2]), final_smooth)
    if P is not None:
        D += FC.eye_warp(V, K, Ff, STYLE_WARP)
        D += FC.mouth_warp(V, K, Ff, STYLE_MOUTH)
    D += eye_scale_delta(V + D, K) * m[:, None]
    D += ear_delta(V + D, K) * head[:, None]
    return D


def ear_weight(V, K):
    """1 on the ears (the pinna standing off the head), fading to 0 at the root: how far a vertex
    lies outside the head built without ears (lib/face.head_node(ears=False)), near an ear."""
    from .sdf import peval
    V = np.asarray(V, float)
    hb = _v(K, "headb")
    w = np.zeros(len(V))
    near = np.zeros(len(V), bool)
    for s in (1, -1):
        e = v3(s * 0.0705, hb[1] + 0.0045, hb[2] + 0.0185)
        near |= np.linalg.norm((V - e) * v3(1.0, 1.0, 0.72), axis=1) < 0.040
    if near.any():
        d = peval(FC.head_node(K, FC.FACE_BASE, ears=False), V[near])
        w[near] = smoothstep(0.0004, 0.0035, d)
    return w


def ear_delta(V, K, scale=EAR_SCALE, tuck=EAR_TUCK):
    """The ears scaled by `scale` about their root (on the side of the head) and tucked toward the
    head by `tuck` of their protrusion. The hair caps are carved round the (larger) realistic ears,
    so a smaller ear only shows a little more of the skin round it."""
    V = np.asarray(V, float)
    hb = _v(K, "headb")
    w = ear_weight(V, K)
    D = np.zeros_like(V)
    for s in (1, -1):
        e = v3(s * 0.0705, hb[1] + 0.0045, hb[2] + 0.0185)
        root = e - v3(s * 0.0060, 0.0, 0.0)
        side = (V[:, 0] * s) > 0.03
        d = (V - root) * (scale - 1.0)
        d[:, 0] -= s * tuck * np.maximum(V[:, 0] * s - root[0] * s, 0.0)
        D += d * (w * side)[:, None]
    return D


def eye_scale_weight(V, K):
    """Share of the eye scale at V (1 inside EYE_R_IN of an eye centre, 0 beyond EYE_R_OUT)."""
    V = np.asarray(V, float)
    w = np.zeros(len(V))
    for s in (1, -1):
        w = np.maximum(w, smoothstep(EYE_R_OUT, EYE_R_IN, np.linalg.norm(V - FC.eye_center(K, s), axis=1)))
    return w


def eye_scale_vec(scale=EYE_SCALE, depth=EYE_SCALE_DEPTH):
    """Per-axis eye scale (Blender x lateral, y depth, z up)."""
    return np.array([scale, depth, scale])


def eye_scale_delta(V, K, scale=EYE_SCALE):
    """Scales the eye regions (eyeball, lid shell, lid margins and lashes, the skin up to the
    orbit rim) about the eye centres, by `scale` across the view and EYE_SCALE_DEPTH in depth,
    fading out between EYE_R_IN and EYE_R_OUT."""
    V = np.asarray(V, float)
    D = np.zeros_like(V)
    sv = eye_scale_vec(scale) - 1.0
    for s in (1, -1):
        c = FC.eye_center(K, s)
        r = np.linalg.norm(V - c, axis=1)
        w = smoothstep(EYE_R_OUT, EYE_R_IN, r)
        D += (V - c) * sv[None, :] * w[:, None]
    return D


def blink_corrective(blink, V, K):
    """The `blink_style` delta: the blink's lid motion scaled like the stylized eye (the lids of the
    larger eye close over the larger eyeball): blink x (eye scale - 1) x its weight."""
    return np.asarray(blink, float) * (eye_scale_vec() - 1.0)[None, :] * eye_scale_weight(V, K)[:, None]


def style_male_delta(V, F, E, K, vlab, Pm, dsex, style):
    """The `style_male` delta: the male fit's stylized head (Pm + STYLE_PARAMS + STYLE_MALE_PARAMS,
    measured on the male-fit vertices V + dsex) less the `style` delta, so style + style_male on the
    male fit gives it. Uses the female base's eye centres (the skeleton is the same)."""
    Vm = np.asarray(V, float) + dsex
    Dm = style_delta(Vm, F, E, K, vlab, P=Pm, extra=STYLE_MALE_PARAMS)
    return Dm - style
