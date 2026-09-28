"""Head v3 (2026-09-27): the MakeHuman head for the customizer body.

The user asked for a polished realistic head (Red Dead / Assassin's Creed style) in place of the
v2 anatomical head (lib/face.py, an SDF). This builds it from the MakeHuman base mesh and targets
(CC0, tools/character/makehuman/README.md); body_v3.py joins it to the SDF body below the jaw.

  shapes   the female base = MakeHuman's young female at average build, the three ethnic macros
           at MakeHuman's neutral 1/3 each; `sex` = the young male (the same macros) with our male
           fit on top (lib/face.FACE_MALE in feature units: MakeHuman's men are much softer than
           ours), each fitted on its own (below); `face_<feature>` = the creator's 30 face features
           mapped onto MakeHuman's face targets (MAP), linear (the increase and the decrease target
           averaged), scaled so weight 1 moves the face about as far as the v2 feature did
           (CALIB, measured on the v2 shapes); `blink` = the lids rotated about the eye centre
           until the margins meet (lid_blink)
  fit      each sex's head scaled to the v2 head's height (crown to menton, OUR_HEAD), MakeHuman's
           own proportions kept, the eyes at the v2 face plane; one Catmull-Clark level
  seam     the faces above the body's neck seam plane (body._cut(+CUT_GAP)), the lowest row slid
           onto the plane (the same edge fraction in every shape)
  scalp    under the hair: pulled inside the v2 cranium (the body SDF), so the hair styles and hats
           fitted to it still cover it; the face is left alone
"""

import gzip
import math
import os

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import face as FC
from lib.sdf import log, peval, smoothstep, v3

HERE = os.path.dirname(os.path.abspath(__file__))
MH_DIR = os.path.normpath(os.path.join(HERE, "..", "makehuman"))
SIDES = ("l", "r")
# our feature -> [(target for +w, target for -w (None: the + target negated), share)]; "{s}" = both sides
MAP = {
    "breadth": [("cheek/{s}-cheek-bones-incr", "cheek/{s}-cheek-bones-decr", 1.0)],
    "length": [("chin/chin-height-incr", "chin/chin-height-decr", 0.7), ("mouth/mouth-trans-down", "mouth/mouth-trans-up", 0.3)],
    "jaw_width": [("chin/chin-bones-incr", "chin/chin-bones-decr", 1.0)],
    "jaw_angle": [("head/head-square", None, 1.0)],
    "chin_projection": [("chin/chin-prominent-incr", "chin/chin-prominent-decr", 1.0)],
    "chin_width": [("chin/chin-width-incr", "chin/chin-width-decr", 1.0)],
    "chin_height": [("chin/chin-jaw-drop-incr", "chin/chin-jaw-drop-decr", 1.0)],
    "cheekbones": [("cheek/{s}-cheek-inner-incr", "cheek/{s}-cheek-inner-decr", 1.0),
                   ("cheek/{s}-cheek-trans-up", "cheek/{s}-cheek-trans-down", 0.3)],
    "midface": [("nose/nose-trans-forward", "nose/nose-trans-backward", 0.6),
                ("cheek/{s}-cheek-inner-incr", "cheek/{s}-cheek-inner-decr", 0.4)],
    "cheek_fullness": [("cheek/{s}-cheek-volume-incr", "cheek/{s}-cheek-volume-decr", 1.0)],
    "prognathism": [("mouth/mouth-trans-forward", "mouth/mouth-trans-backward", 1.0)],
    "brow_ridge": [("eyebrows/eyebrows-trans-forward", "eyebrows/eyebrows-trans-backward", 1.0)],
    "eye_depth": [("eyebrows/eyebrows-trans-forward", "eyebrows/eyebrows-trans-backward", 1.0)],
    "eye_tilt": [("eyes/{s}-eye-corner1-up", "eyes/{s}-eye-corner1-down", 1.0),
                 ("eyes/{s}-eye-corner2-down", "eyes/{s}-eye-corner2-up", 0.5)],
    "eye_height": [("eyes/{s}-eye-height2-incr", "eyes/{s}-eye-height2-decr", 1.0),
                   ("eyes/{s}-eye-height1-incr", "eyes/{s}-eye-height1-decr", 0.5),
                   ("eyes/{s}-eye-height3-incr", "eyes/{s}-eye-height3-decr", 0.5)],
    "lid_crease": [("eyes/{s}-eye-eyefold-up", "eyes/{s}-eye-eyefold-down", 1.0)],
    "lid_fold": [("eyes/{s}-eye-eyefold-convex", "eyes/{s}-eye-eyefold-concave", 1.0)],
    "epicanthus": [("eyes/{s}-eye-epicanthus-out", "eyes/{s}-eye-epicanthus-in", 1.0)],
    "under_eye": [("eyes/{s}-eye-bag-incr", "eyes/{s}-eye-bag-decr", 1.0)],
    "nasal_root": [("nose/nose-greek-incr", "nose/nose-greek-decr", 1.0)],
    "nose_bridge": [("nose/nose-curve-convex", "nose/nose-curve-concave", 0.5),
                    ("nose/nose-scale-depth-incr", "nose/nose-scale-depth-decr", 0.5)],
    "nose_hump": [("nose/nose-hump-incr", "nose/nose-hump-decr", 1.0)],
    "nose_width": [("nose/nose-flaring-incr", "nose/nose-flaring-decr", 0.5),
                   ("nose/nose-width3-incr", "nose/nose-width3-decr", 0.5),
                   ("nose/nose-scale-horiz-incr", "nose/nose-scale-horiz-decr", 0.3)],
    "nose_length": [("nose/nose-scale-vert-incr", "nose/nose-scale-vert-decr", 1.0)],
    "nose_tip": [("nose/nose-volume-incr", "nose/nose-volume-decr", 0.6),
                 ("nose/nose-scale-depth-incr", "nose/nose-scale-depth-decr", 0.4)],
    "nose_upturn": [("nose/nose-point-up", "nose/nose-point-down", 1.0)],
    "lips_upper": [("mouth/mouth-upperlip-volume-incr", "mouth/mouth-upperlip-volume-decr", 1.0),
                   ("mouth/mouth-upperlip-height-incr", "mouth/mouth-upperlip-height-decr", 0.3)],
    "lips_lower": [("mouth/mouth-lowerlip-volume-incr", "mouth/mouth-lowerlip-volume-decr", 1.0),
                   ("mouth/mouth-lowerlip-height-incr", "mouth/mouth-lowerlip-height-decr", 0.3)],
    "mouth_width": [("mouth/mouth-scale-horiz-incr", "mouth/mouth-scale-horiz-decr", 1.0)],
    "ears": [("ears/{s}-ear-scale-incr", "ears/{s}-ear-scale-decr", 0.6), ("ears/{s}-ear-flap-incr", "ears/{s}-ear-flap-decr", 0.4)],
}
# MakeHuman weight per unit of our feature weight: the largest vertex move of the v2 face_<feature>
# shape over that of the mapped targets at weight 1 (at the head test's scale), measured once on
# the v2 body (2026-09-27, tools/character/head_test/mh_head.py calibrate()); frozen because the
# body now carries these shapes itself.
CALIB = {"breadth": 0.586, "length": 0.474, "jaw_width": 0.537, "jaw_angle": 0.376, "chin_projection": 0.384,
         "chin_width": 0.319, "chin_height": 0.524, "cheekbones": 0.408, "midface": 1.063, "cheek_fullness": 0.46,
         "prognathism": 0.323, "brow_ridge": 0.102, "eye_depth": 0.089, "eye_tilt": 1.259, "eye_height": 0.427,
         "lid_crease": 0.524, "lid_fold": 1.587, "epicanthus": 0.866, "under_eye": 0.303, "nasal_root": 0.765,
         "nose_bridge": 0.5, "nose_hump": 0.481, "nose_width": 0.836, "nose_length": 0.972, "nose_tip": 0.579,
         "nose_upturn": 0.518, "lips_upper": 0.948, "lips_lower": 0.742, "mouth_width": 0.525, "ears": 0.727}
# The v2 head's height per body type (crown, menton; m), measured on the v2 body: the hair styles and
# hats are fitted to that head, so the new one keeps its size.
OUR_HEAD = {0: (1.5971, 1.3733), 1: (1.5971, 1.3685)}
EYE_Y = -0.0988            # the v2 eyes' depth (the face plane)
CUT_KEEP = 0.045           # cage faces kept this far below the seam before the subdivision
SHAPE_SEAM = 0.02          # the face shapes fade out over this height above the seam
EYE_R_MAX = 0.0135
# Catmull-Clark levels over the MakeHuman cage: 0 (the cage as it is: about 8k head triangles, game
# topology; the facial hair shells copy the head's triangles and must stay within the fur budget)
SUBDIV_LEVELS = 0


class MakeHuman:
    def __init__(self, root=MH_DIR):
        self.root = root
        V, VT, F, FT, G = [], [], [], [], []
        cur = None
        for line in open(os.path.join(root, "base.obj")):
            if line.startswith("v "):
                V.append([float(x) for x in line.split()[1:4]])
            elif line.startswith("vt "):
                VT.append([float(x) for x in line.split()[1:3]])
            elif line.startswith("g "):
                cur = line.split()[1]
            elif line.startswith("f "):
                F.append([int(t.split("/")[0]) - 1 for t in line.split()[1:]])
                FT.append([int(t.split("/")[1]) - 1 for t in line.split()[1:]])
                G.append(cur)
        self.V0 = np.array(V)
        self.VT = np.array(VT)          # the base mesh's UVs (the MakeHuman skin textures' layout)
        self.FT = FT
        self.F = F
        self.G = G
        self.group_verts = {}
        for f, g in zip(F, G):
            self.group_verts.setdefault(g, set()).update(f)
        self._t = {}

    def target(self, name):
        if name not in self._t:
            D = np.zeros_like(self.V0)
            for line in gzip.open(os.path.join(self.root, "targets", name + ".target.gz"), "rt"):
                t = line.split()
                if len(t) == 4 and not line.startswith("#"):
                    D[int(t[0])] = (float(t[1]), float(t[2]), float(t[3]))
            self._t[name] = D
        return self._t[name]

    def sided(self, name):
        if "{s}" not in name:
            return self.target(name)
        return sum(self.target(name.format(s=s)) for s in SIDES)

    def macro(self, g, build=None):
        """The young female (g 0) / male (g 1) macro, the three ethnic macros at 1/3 each; `build`
        {0: [(muscle-weight, share)], 1: [...]} blends MakeHuman's muscle and weight builds (the body,
        BODY_BUILD); by default the average build (the head's fit and features were tuned on it)."""
        m = "macrodetails/"
        if build is None:
            build = {0: [("averagemuscle-averageweight", 1.0)], 1: [("averagemuscle-averageweight", 1.0)]}
        uf = sum(w * self.target(m + "universal-female-young-" + k) for k, w in build[0])
        um = sum(w * self.target(m + "universal-male-young-" + k) for k, w in build[1])
        d = (1 - g) * uf + g * um
        for race in ("african", "asian", "caucasian"):
            d = d + (1.0 / 3.0) * ((1 - g) * self.target(m + "%s-female-young" % race) + g * self.target(m + "%s-male-young" % race))
        return d

    def feature(self, f, sign):
        out = np.zeros_like(self.V0)
        for pos, neg, share in MAP[f]:
            if sign > 0:
                out += share * self.sided(pos)
            elif neg is None:
                out -= share * self.sided(pos)
            else:
                out += share * self.sided(neg)
        return out

    def feature_linear(self, f):
        """The feature as one linear shape: the increase and the decrease target averaged."""
        return 0.5 * (self.feature(f, +1) - self.feature(f, -1))

    def centroid(self, group, V):
        return V[sorted(self.group_verts[group])].mean(0)


def male_features():
    """Our male fit (lib/face.FACE_MALE) in feature units: per feature, the mean ratio of the male
    parameter change to the feature's own parameter change at weight 1."""
    out = {}
    for f, dp in FC.FACE_FEATURES.items():
        r = [FC.FACE_MALE[p] / v for p, v in dp.items() if p in FC.FACE_MALE and abs(v) > 1e-12]
        if r:
            out[f] = float(np.mean(r))
    out["eye_height"] = FC.FACE_MALE.get("fissure_up", 0.0) / FC.FACE_WARPS["eye_height"]["fissure_up"]
    out["mouth_width"] = FC.FACE_MALE.get("mouth_w", 0.0) / FC.MOUTH_WARP["mouth_width"]
    return out


def to_ours(P, scale, off):
    """MakeHuman (x, y up, z forward; dm) -> Blender armature space (x, -z, y; m)."""
    P = np.asarray(P)
    return np.stack([P[..., 0], -P[..., 2], P[..., 1]], -1) * scale + off


def _crown_menton(mh, V):
    b = np.array(sorted(mh.group_verts["body"]))
    B = V[b]
    eye = mh.centroid("helper-l-eye", V)
    crown = float(B[B[:, 1] > eye[1] - 2.0][:, 1].max())
    chin = B[(np.abs(B[:, 0]) < 0.05) & (B[:, 1] > eye[1] - 2.0) & (B[:, 1] < eye[1] - 0.5) & (B[:, 2] > eye[2] - 0.2)]
    return crown, float(chin[:, 1].min())


def fit(mh, V, sex):
    """(scale, offset) placing a MakeHuman shape at the v2 head's height and face plane."""
    crown_m, menton_m = _crown_menton(mh, V)
    crown_o, menton_o = OUR_HEAD[sex]
    scale = (crown_o - menton_o) / (crown_m - menton_m)
    le, re = mh.centroid("helper-l-eye", V), mh.centroid("helper-r-eye", V)
    eye = to_ours((le + re) / 2, scale, 0.0)
    off = v3(0.0, EYE_Y - eye[1], (crown_o + menton_o) / 2 - scale * (crown_m + menton_m) / 2)
    return scale, off


def seam_plane(dz):
    from body.body import _cut
    return _cut(dz)


def _subdivide(cage_V, cage_F, shapes):
    """SUBDIV_LEVELS Catmull-Clark levels of the cage for the base and each shape: (V, faces, {name: delta})."""
    if SUBDIV_LEVELS == 0:
        return np.asarray(cage_V, float), [tuple(f) for f in cage_F], {n: np.asarray(d, float) for n, d in shapes.items()}
    me = bpy.data.meshes.new("mh_cage")
    me.from_pydata([tuple(p) for p in cage_V], [], [tuple(f) for f in cage_F])
    me.update()
    ob = bpy.data.objects.new("mh_cage", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = SUBDIV_LEVELS
    mod.render_levels = SUBDIV_LEVELS

    def evaluate(P):
        me.vertices.foreach_set("co", np.asarray(P, np.float32).ravel())
        me.update()
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        m = ev.to_mesh()
        out = np.empty(len(m.vertices) * 3, np.float32)
        m.vertices.foreach_get("co", out)
        faces = [tuple(p.vertices) for p in m.polygons]
        ev.to_mesh_clear()
        return out.reshape(-1, 3).astype(float), faces
    base, faces = evaluate(cage_V)
    out = {}
    for n, d in shapes.items():
        P, f2 = evaluate(cage_V + d)
        assert len(P) == len(base) and len(f2) == len(faces)
        out[n] = P - base
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    return base, faces, out


def _edges(faces, n):
    nb = [set() for _ in range(n)]
    for f in faces:
        for i in range(len(f)):
            a, b = f[i], f[(i + 1) % len(f)]
            nb[a].add(b)
            nb[b].add(a)
    return [sorted(s) for s in nb]


def _triangulate(V, faces, face_uv=None):
    """Triangles of quads (the shorter diagonal); with face_uv (per face corner), the triangles'
    corner UVs too."""
    T, TU = [], []
    for i, f in enumerate(faces):
        if len(f) == 3:
            cs = [(0, 1, 2)]
        else:
            a, b, c, d = f
            cs = [(0, 1, 2), (0, 2, 3)] if np.linalg.norm(V[a] - V[c]) <= np.linalg.norm(V[b] - V[d]) else [(0, 1, 3), (1, 2, 3)]
        for k in cs:
            T.append(tuple(f[j] for j in k))
            if face_uv is not None:
                TU.append([face_uv[i][j] for j in k])
    return (np.array(T, int), np.array(TU, float)) if face_uv is not None else np.array(T, int)


def _smooth_field(D, nb, mask, iters):
    for _ in range(iters):
        Dn = np.array([D[n].mean(0) if n else D[i] for i, n in enumerate(nb)])
        D = np.where(mask[:, None], 0.5 * (D + Dn), D)
    return D


def _sdf_grad(node, Q, h=5e-4):
    g = np.stack([peval(node, Q + e * h) - peval(node, Q - e * h) for e in np.eye(3)], 1)
    return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-12)


def conform_scalp(P, nb, node, K, eye_z, ears):
    """Pulls the scalp inside the SDF `node` (1 mm under it) where it stands out, faded in above
    the brow and the ears; the pull is smoothed so the skull keeps its shape. Returns (delta, weight)."""
    hb = K["headb"]
    Y, Z = P[:, 1], P[:, 2]
    front = Y < hb[1] - 0.045
    w = np.where(front, smoothstep(eye_z + 0.030, eye_z + 0.042, Z), smoothstep(eye_z - 0.010, eye_z + 0.012, Z))
    for e in ears:
        w *= smoothstep(0.020, 0.032, np.linalg.norm(P - e, axis=1))
    D = np.zeros_like(P)
    for _ in range(3):
        sel = np.nonzero(w > 0)[0]
        Q = P[sel] + D[sel]
        d = peval(node, Q)
        n = _sdf_grad(node, Q)
        out = d > 0.001
        corr = np.zeros_like(Q)
        corr[out] = -(d[out] - 0.001)[:, None] * n[out]
        C = np.zeros_like(P)
        C[sel] = corr * w[sel, None]
        D = D + _smooth_field(C, nb, w > 0, 8)
    return D, w


def lid_rows(mh, V, scale, off):
    """Per eye (1 = MakeHuman's l side): {"up": roots, "lo": roots} of MakeHuman's eyelash helper
    strips (the half of each strip nearest the eye centre), each row from the inner corner out."""
    out = {}
    for s, side in ((1, "l"), (-1, "r")):
        c = mh.centroid("helper-%s-eye" % side, V)
        rows = []
        for k in (1, 2):
            idx = np.array(sorted(mh.group_verts["helper-%s-eyelashes-%d" % (side, k)]))
            d = np.linalg.norm(V[idx] - c, axis=1)
            R = to_ours(V[idx[d <= np.median(d)]], scale, off)
            rows.append(R)
        co = to_ours(c, scale, off)
        up, lo = sorted(rows, key=lambda R: -R[:, 2].mean())
        res = {}
        for n, R in (("up", up), ("lo", lo)):
            res[n] = R[np.argsort(np.abs(R[:, 0] - co[0]) * np.sign(R[:, 0] - co[0]) * s)]
        out[s] = res
    return out


def _elev(P, c):
    return np.arctan2(P[:, 2] - c[2], -(P[:, 1] - c[1]))


def _azim(P, c, s):
    return np.arctan2((P[:, 0] - c[0]) * s, -(P[:, 1] - c[1]))


def lid_blink(P, c, s, rows, r_eye):
    """The blink: skin around the eye rotated about the eye's lateral axis (x) so the upper margin
    comes down to the closing line a quarter of the way up the opening and the lower margin rises
    to it; nothing moves at the corners, above 40 degrees over the upper margin, below 30 under the
    lower one, or more than 14 mm off the eye. Returns (delta, rotation per point)."""
    phi_u = float(np.median(_elev(rows["up"], c)))
    phi_l = float(np.median(_elev(rows["lo"], c)))
    phi_c = phi_l + 0.3 * (phi_u - phi_l)
    allr = np.vstack([rows["up"], rows["lo"]])
    a_in, a_out = float(_azim(allr, c, s).min()), float(_azim(allr, c, s).max())
    phi = _elev(P, c)
    az = _azim(P, c, s)
    t = np.clip((az - a_in) / max(a_out - a_in, 1e-6), 0.0, 1.0)
    amt = np.sin(np.pi * t) ** 0.5
    r = np.linalg.norm(P - c, axis=1)
    fwd = -(P[:, 1] - c[1]) / np.maximum(r, 1e-9)
    amt *= (1.0 - smoothstep(r_eye + 0.006, r_eye + 0.014, r)) * smoothstep(0.05, 0.3, fwd)
    top = phi_u + math.radians(40.0)
    bot = phi_l - math.radians(30.0)
    new = phi.copy()
    up = (phi >= phi_u) & (phi <= top)
    new[up] = phi_c + (phi[up] - phi_u) * (top - phi_c) / (top - phi_u)
    lo = (phi <= phi_l) & (phi >= bot)
    new[lo] = bot + (phi[lo] - bot) * ((phi_c - 0.02) - bot) / (phi_l - bot)
    dphi = amt * (new - phi)
    F = -(P[:, 1] - c[1])
    U = P[:, 2] - c[2]
    rho = np.sqrt(F * F + U * U)
    ang = np.arctan2(U, F) + dphi
    Q = P.copy()
    Q[:, 1] = c[1] - rho * np.cos(ang)
    Q[:, 2] = c[2] + rho * np.sin(ang)
    return Q - P, dphi


def head_piece(mh, K, node_f, node_m):
    """The head above the seam: dict with V (female base), F (triangles), shapes {sex, face_*,
    blink}, eyes {s: centre}, eye_shapes {name: {s: delta}}, eye_r, rows (lid margins), and
    landmarks for the skin colours."""
    k = CALIB
    male = male_features()
    base_f = mh.V0 + mh.macro(0.0)
    base_m = mh.V0 + mh.macro(1.0)
    for f, w in male.items():
        if f in MAP:
            base_m = base_m + w * k[f] * mh.feature_linear(f)
    sf, of = fit(mh, base_f, 0)
    sm, om = fit(mh, base_m, 1)
    P_f = to_ours(base_f, sf, of)
    P_m = to_ours(base_m, sm, om)
    cage_shapes = {"sex": P_m - P_f}
    for f in MAP:
        cage_shapes["face_" + f] = to_ours(k[f] * mh.feature_linear(f), sf, 0.0)
    # the head faces of the body group above the seam (with a margin for the subdivision)
    p, n = seam_plane(0.0)
    keep, keep_idx = [], []
    for fi, (f, g) in enumerate(zip(mh.F, mh.G)):
        if g == "body" and ((P_f[f] - p) @ n > -CUT_KEEP).all() and (np.abs(P_f[f][:, 0]) < 0.11).all():
            keep.append(f)
            keep_idx.append(fi)
    used = sorted({i for f in keep for i in f})
    remap = {v: i for i, v in enumerate(used)}
    cage_F = [[remap[i] for i in f] for f in keep]
    cage_V = P_f[used]
    Vs, Fs, S = _subdivide(cage_V, cage_F, {nm: d[used] for nm, d in cage_shapes.items()})
    nb_all = _edges(Fs, len(Vs))
    # cut at the seam (+CUT_GAP): faces wholly above; the lowest row slides onto the plane
    from body.body import CUT_GAP
    p, n = seam_plane(CUT_GAP)
    sd = (Vs - p) @ n
    kf_idx = [i for i, f in enumerate(Fs) if (sd[list(f)] > 0).all()]
    kf = [Fs[i] for i in kf_idx]
    # the MakeHuman UV of each kept face's corners (the cage's own faces: SUBDIV_LEVELS 0)
    assert SUBDIV_LEVELS == 0, "the MakeHuman UVs follow the cage faces only"
    kf_uv = [[mh.VT[t] for t in mh.FT[keep_idx[i]]] for i in kf_idx]
    kv = sorted({i for f in kf for i in f})
    slide = {}
    for v in kv:
        below = [u for u in nb_all[v] if sd[u] <= 0]
        if below:
            u = min(below, key=lambda u: sd[u])
            slide[v] = (u, sd[v] / (sd[v] - sd[u]))
    V = Vs.copy()
    shapes = {nm: d.copy() for nm, d in S.items()}
    for v, (u, t) in slide.items():
        V[v] = Vs[v] + t * (Vs[u] - Vs[v])
        for nm in shapes:
            shapes[nm][v] = S[nm][v] + t * (S[nm][u] - S[nm][v])
    rm = {v: i for i, v in enumerate(kv)}
    V = V[kv]
    shapes = {nm: d[kv] for nm, d in shapes.items()}
    faces = [tuple(rm[i] for i in f) for f in kf]
    nb = _edges(faces, len(V))
    # landmarks (female base)
    le, re = mh.centroid("helper-l-eye", base_f), mh.centroid("helper-r-eye", base_f)
    eyes = {1: to_ours(le, sf, of), -1: to_ours(re, sf, of)}

    def tgt_centroid(name):
        D = mh.target(name)
        m = np.linalg.norm(D, axis=1)
        sel = m > 0.25 * m.max()
        return (P_f[sel] * m[sel, None]).sum(0) / m[sel].sum()
    ears = [tgt_centroid("ears/%s-ear-scale-incr" % s) for s in SIDES]
    marks = {"cheeks": [tgt_centroid("cheek/%s-cheek-volume-incr" % s) for s in SIDES], "ears": ears,
             "nose_base": tgt_centroid("nose/nose-base-up"),
             "stomion": (tgt_centroid("mouth/mouth-upperlip-volume-incr") + tgt_centroid("mouth/mouth-lowerlip-volume-incr")) / 2}
    lipD = np.linalg.norm(mh.target("mouth/mouth-upperlip-volume-incr"), axis=1) \
        + np.linalg.norm(mh.target("mouth/mouth-lowerlip-volume-incr"), axis=1)
    marks["lips"] = P_f[lipD > 0.45 * lipD.max()]
    # where MakeHuman's mouth-corner and ear targets act (the face-coordinate knots)
    ang = np.linalg.norm(mh.target("mouth/mouth-angles-up"), axis=1)
    marks["mouth_corners"] = P_f[ang > 0.5 * ang.max()]
    ear = sum(np.linalg.norm(mh.target("ears/%s-ear-scale-incr" % s), axis=1) for s in SIDES)
    marks["ear_pts"] = P_f[ear > 0.2 * ear.max()]
    # the scalp under the v2 cranium, for both fits; the face shapes kept off the scalp
    eye_z = float(eyes[1][2])
    Df, w = conform_scalp(V, nb, node_f, K, eye_z, ears)
    Dm, _ = conform_scalp(V + shapes["sex"], nb, node_m, K, eye_z, ears)
    shapes["sex"] = shapes["sex"] + Dm - Df
    V_pre = V.copy()
    V = V + Df
    for nm in shapes:
        if nm.startswith("face_"):
            shapes[nm] *= (1.0 - w)[:, None]
    log("  head v3: scalp pulled in by up to %.1f mm (female) / %.1f mm (male)" % (
        1000 * float(np.linalg.norm(Df, axis=1).max()), 1000 * float(np.linalg.norm(Dm, axis=1).max())))
    # the face shapes fade out toward the seam (the neck belongs to the body)
    h = (V - p) @ n
    fade = smoothstep(0.0, SHAPE_SEAM, h)
    for nm in shapes:
        if nm.startswith("face_"):
            shapes[nm] *= fade[:, None]
    # the eyes: each shape moves the eye centres as it moves MakeHuman's eye helpers
    eye_shapes = {"sex": {1: to_ours(mh.centroid("helper-l-eye", base_m), sm, om) - eyes[1],
                          -1: to_ours(mh.centroid("helper-r-eye", base_m), sm, om) - eyes[-1]}}
    for f in MAP:
        d = to_ours(k[f] * mh.feature_linear(f), sf, 0.0)
        eye_shapes["face_" + f] = {1: d[sorted(mh.group_verts["helper-l-eye"])].mean(0),
                                   -1: d[sorted(mh.group_verts["helper-r-eye"])].mean(0)}
    rows = lid_rows(mh, base_f, sf, of)
    eye_r = {}
    for s in (1, -1):
        allr = np.vstack([rows[s]["up"], rows[s]["lo"]])
        r_fit = float(np.median(np.linalg.norm(allr - eyes[s], axis=1)))
        eye_r[s] = min(r_fit - FC.LID_GAP - 0.0006, EYE_R_MAX)
    blink = np.zeros_like(V)
    for s in (1, -1):
        d, _ = lid_blink(V, eyes[s], s, rows[s], eye_r[s])
        blink += d
    shapes["blink"] = blink
    F, F_uv = _triangulate(V, faces, kf_uv)
    log("  head v3: %d verts, %d tris, fit scale female %.4f male %.4f, eye radius %s mm" % (
        len(V), len(F), sf, sm, {s: round(r * 1000, 2) for s, r in eye_r.items()}))
    # each piece vertex's MakeHuman vertex (no subdivision: the cage's vertices are MakeHuman's)
    mh_idx = np.array(used)[np.array(kv)]
    return {"V": V, "F": F, "F_uv": F_uv, "quads": faces, "shapes": shapes, "eyes": eyes, "eye_shapes": eye_shapes,
            "mh_idx": mh_idx, "slid": np.array([rm[v] for v in slide]),
            "eye_scale": {"sex": sm / sf}, "V_pre": V_pre, "conform": Df, "base_f": base_f,
            "eye_r": eye_r, "rows": rows, "marks": marks, "scalp_w": w,
            "fit": {"female": [sf, list(of)], "male": [sm, list(om)]}}


def ray_ao(V, N, bvh, dist=0.006, n=14):
    """Cavity occlusion: the share of short rays that hit the head, near hits counting more."""
    rng = np.random.default_rng(3)
    dirs = rng.normal(size=(n, 3))
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    occ = np.zeros(len(V))
    for i, (p, nn) in enumerate(zip(V, N)):
        o = Vector(p + nn * 0.0002)
        hits = 0.0
        for d in dirs:
            if d @ nn < 0.15:
                d = d - 2 * (d @ nn) * nn
            dd = d * 0.6 + nn * 0.4
            dd /= np.linalg.norm(dd)
            h = bvh.ray_cast(o, Vector(dd), dist)
            if h[0] is not None:
                hits += 1.0 - h[3] / dist
        occ[i] = hits / n
    return np.clip(1.0 - 1.1 * occ, 0.0, 1.0)


def head_colors(Vh, Nh, piece, K, bvh):
    """COLOR_0 of the head's skin (as the body's): r flush, g mucosa, b cavity, a beard."""
    mk = piece["marks"]
    flush = np.zeros(len(Vh))
    for cc in mk["cheeks"]:
        flush = np.maximum(flush, 0.85 * np.exp(-np.sum(((Vh - cc) / v3(1.2, 1, 1)) ** 2, 1) / (2 * 0.014 ** 2)))
    for ear in mk["ears"]:
        flush = np.maximum(flush, 0.75 * np.exp(-np.sum((Vh - ear) ** 2, 1) / (2 * 0.016 ** 2)))
    for s in (1, -1):
        flush = np.maximum(flush, 0.45 * np.exp(-np.sum((Vh - piece["eyes"][s]) ** 2, 1) / (2 * 0.013 ** 2)))
    mid = np.abs(Vh[:, 0]) < 0.004
    tip = Vh[mid][np.argmin(Vh[mid, 1])]
    flush = np.maximum(flush, 0.7 * np.exp(-np.sum((Vh - tip) ** 2, 1) / (2 * 0.011 ** 2)))
    from mathutils.kdtree import KDTree
    L = mk["lips"]
    kd = KDTree(len(L))
    for i, q in enumerate(L):
        kd.insert(Vector(q), i)
    kd.balance()
    dl = np.array([kd.find(Vector(p))[2] for p in Vh])
    muc = smoothstep(0.0022, 0.0006, dl)
    for s in (1, -1):
        R = np.vstack([piece["rows"][s]["up"], piece["rows"][s]["lo"]])
        de = np.min(np.linalg.norm(Vh[:, None, :] - R[None, :, :], axis=2), axis=1)
        muc = np.maximum(muc, smoothstep(0.0012, 0.0003, de))
    ao = ray_ao(Vh, Nh, bvh)
    sto, nb_ = mk["stomion"], mk["nose_base"]
    hb = K["headb"]
    X, Y, Z = Vh[:, 0], Vh[:, 1], Vh[:, 2]
    front = smoothstep(hb[1] + 0.015, hb[1] - 0.030, Y)
    below_cheek = smoothstep(nb_[2] + 0.004, nb_[2] - 0.012, Z)
    p, n = seam_plane(0.0)
    above_neck = smoothstep(-0.01, 0.02, (Vh - p) @ n)
    not_lips = (1.0 - muc) * (smoothstep(0.0100, 0.0140, np.sqrt(((X - sto[0]) / 1.4) ** 2 + (Z - sto[2]) ** 2)) * 0.6 + 0.4)
    not_nose = np.clip(smoothstep(nb_[2] - 0.001, nb_[2] - 0.007, Z) + (np.abs(X) > 0.026), 0, 1)
    beard = front * below_cheek * above_neck * not_lips * not_nose
    return np.stack([flush, muc, ao, beard], 1)


def brows(bvh, K, eyes):
    """The v2 brow cards (the brow line about the v2 eyes) moved with the new eyes (x scaled by the
    eye spacing, z shifted by the eye height), ray-cast onto the head, 0.35 mm off the skin."""
    from body.body import _grid_faces
    V, UVs, Fq = [], [], []
    nu, nv = 15, 5
    for s in (1, -1):
        co = FC.eye_center(K, s)
        cm = eyes[s]
        r = abs(cm[0]) / abs(co[0])
        base = len(V)
        for i in range(nu):
            u = i / (nu - 1)
            x = 0.0135 + 0.0370 * u
            zc = 1.5015 + 0.0045 * math.sin(math.pi * min(u / 0.72, 1.0) * 0.5) - 0.0070 * smoothstep(0.70, 1.0, u)
            hgt = 0.0120 - 0.0050 * u
            for j in range(nv):
                v = j / (nv - 1)
                z = zc + (v - 0.5) * hgt
                xm = cm[0] + (s * x - co[0]) * r
                zm = cm[2] + (z - co[2])
                hit = bvh.ray_cast(Vector((xm, -0.25, zm)), Vector((0, 1, 0)), 0.5)
                if hit[0] is None:
                    raise SystemExit("brow card: no skin at (%.3f, %.3f)" % (xm, zm))
                V.append(np.array(hit[0]) + np.array(hit[1]) * 0.00035)
                UVs.append((u, v))
        Fq += _grid_faces(nu, nv, base) if s > 0 else [tuple(reversed(f)) for f in _grid_faces(nu, nv, base)]
    return np.array(V), Fq, np.array(UVs)


def lashes(piece):
    """Lash cards along the lid rows: (V, quads, UV, root per vertex, lower flag per vertex, eye side
    per vertex)."""
    from body.body import _grid_faces
    V, Fq, UVs, R, LO, SD = [], [], [], [], [], []
    for s in (1, -1):
        c = piece["eyes"][s]
        for which, length, n_col, lift in (("up", 0.0085, 16, 1.0), ("lo", 0.0042, 12, -1.0)):
            P = piece["rows"][s][which]
            d = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
            ts = np.linspace(0, d[-1], n_col)
            Q = np.stack([np.interp(ts, d, P[:, j]) for j in range(3)], 1)
            base = len(V)
            for i, p in enumerate(Q):
                tt = 2.0 * i / (n_col - 1) - 1.0
                radial = (p - c) / np.linalg.norm(p - c)
                upv = v3(0, 0, 1) * lift
                taper = 0.55 + 0.45 * math.sin(math.pi * (tt + 1) / 2) ** 0.6
                L = length * taper * (1.0 if tt > -0.6 else 0.75)
                a = radial * 0.9 + upv * 0.35
                b = radial * 0.45 + upv * 0.9
                for j, q in enumerate([p, p + a / np.linalg.norm(a) * L * 0.5, p + b / np.linalg.norm(b) * L]):
                    V.append(q)
                    UVs.append(((tt + 1) * 0.5, j / 2.0))
                    R.append(p)
                    LO.append(which == "lo")
                    SD.append(s)
            fq = _grid_faces(n_col, 3, base)
            Fq += fq if s > 0 else [tuple(reversed(f)) for f in fq]
    return np.array(V), Fq, np.array(UVs), np.array(R), np.array(LO), np.array(SD)
