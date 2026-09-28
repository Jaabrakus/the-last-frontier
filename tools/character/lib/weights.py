"""Skin weights: deform segments (joint -> child joint, never Blender bone tails),
body weights by region, knee / elbow plane splits, nearest-point transfer, the
twist-helper spread, skirt / queue fields, rigid islands, leather bands.

Split out of tools/character/build_body.py (lib v1); skirt_weights() takes the hem and
vent top as arguments (defaults = the legacy coat).
"""

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from .body_shapes import FINGERS, THUMB, arm_shapes, torso_shapes
from .remesh import mesh_arrays
from .sdf import nrm, peval, smoothstep, v3

# ===========================================================================
# Skin weights
# ===========================================================================
FINGER_BONES = [b for _, ch in FINGERS for b in ch] + THUMB


def deform_segments(K):
    """bone -> (list of (a, b) segments in Blender space, radius scale).
    Segments run joint -> child joint, never along Blender bone tails."""
    P = K.P
    seg = {}
    hc = (P["l_upper_leg"] + P["r_upper_leg"]) * 0.5
    seg["pelvis"] = ([(P["pelvis"], hc + v3(0, 0, -0.03)), (P["pelvis"], P["l_upper_leg"]),
                      (P["pelvis"], P["r_upper_leg"])], 0.11)
    seg["spinea"] = ([(P["spinea"], P["spineb"])], 0.10)
    seg["spineb"] = ([(P["spineb"], P["spinec"])], 0.10)
    seg["spinec"] = ([(P["spinec"], P["spined"])], 0.11)
    seg["spined"] = ([(P["spined"], P["neck"]), (P["spined"], P["l_clavicle"]), (P["spined"], P["r_clavicle"])], 0.12)
    seg["neck"] = ([(P["neck"], P["heada"])], 0.045)
    seg["heada"] = ([(P["heada"], P["headb"])], 0.045)
    seg["headb"] = ([(P["headb"], P["headb"] + v3(0, -0.02, 0.12))], 0.08)
    for sd in "lr":
        q = lambda n: P[sd + "_" + n]
        seg[sd + "_upper_leg"] = ([(q("upper_leg"), q("knee"))], 0.075)
        seg[sd + "_knee"] = ([(q("knee"), q("ankle"))], 0.045)
        seg[sd + "_ankle"] = ([(q("ankle"), q("ankle") + v3(0, 0.0, -0.03))], 0.035)
        heel_c = v3(q("ankle")[0], q("heel")[1] - 0.03, 0.035)
        seg[sd + "_heel"] = ([(heel_c, q("ball"))], 0.035)
        seg[sd + "_ball"] = ([(q("ball"), q("ball") + v3(0, -0.055, 0))], 0.025)
        seg[sd + "_clavicle"] = ([(q("clavicle"), q("shoulder"))], 0.05)
        seg[sd + "_shoulder"] = ([(q("shoulder"), q("elbow"))], 0.042)
        seg[sd + "_elbow"] = ([(q("elbow"), q("wrist"))], 0.032)
        seg[sd + "_wrist"] = ([(q("wrist"), q("palm"))], 0.028)
        seg[sd + "_palm"] = ([(q("palm"), q("middlea")), (q("palm"), q("indexa")), (q("palm"), q("pinkyb"))], 0.028)
        tips = {"index": 0.019, "middle": 0.020, "ring": 0.019, "pinky": 0.016}
        for fname, ch in FINGERS:
            pts = [q(n) for n in ch]
            pts.append(pts[-1] + nrm(pts[-1] - pts[-2]) * tips[fname])
            for i, n in enumerate(ch):
                seg[sd + "_" + n] = ([(pts[i], pts[i + 1])], 0.009 if i else 0.012)
        tp = [q(n) for n in THUMB]
        tp.append(tp[-1] + nrm(tp[-1] - tp[-2]) * 0.021)
        for i, n in enumerate(THUMB):
            seg[sd + "_" + n] = ([(tp[i], tp[i + 1])], 0.013 - 0.0015 * i)
    return seg


def region_bones():
    both = lambda names: [s + "_" + n for s in "lr" for n in names]
    r = {"torso": ["pelvis", "spinea", "spineb", "spinec", "spined", "neck"] + both(["clavicle", "shoulder", "upper_leg"]),
         "neck": ["spined", "neck", "heada"] + both(["clavicle"]),
         "head": ["headb"]}
    for s in "lr":
        r["arm_" + s] = ["spined"] + [s + "_" + n for n in ("clavicle", "shoulder", "elbow", "wrist")]
        r["hand_" + s] = [s + "_" + n for n in ["elbow", "wrist", "palm"] + FINGER_BONES]
        r["leg_" + s] = ["pelvis"] + [s + "_" + n for n in ("upper_leg", "knee", "ankle")]
        r["foot_" + s] = [s + "_" + n for n in ("knee", "ankle", "heel", "ball")]
    return r


def seg_dist(V, a, b):
    ab = b - a
    t = np.clip(((V - a) @ ab) / max(ab @ ab, 1e-12), 0, 1)
    return np.linalg.norm(V - (a + t[:, None] * ab), axis=1)


def mesh_adjacency(ob):
    E = np.empty(len(ob.data.edges) * 2, int)
    ob.data.edges.foreach_get("vertices", E)
    return E.reshape(-1, 2)


def smooth_weights(W, E, iters, alpha=0.5, lock=None):
    n = len(W)
    deg = np.bincount(E.ravel(), minlength=n).astype(float)
    for _ in range(iters):
        acc = np.zeros_like(W)
        np.add.at(acc, E[:, 0], W[E[:, 1]])
        np.add.at(acc, E[:, 1], W[E[:, 0]])
        Wn = (1 - alpha) * W + alpha * acc / np.maximum(deg, 1)[:, None]
        if lock is not None:
            Wn[lock] = W[lock]
        W = Wn
    return W


def limit_normalize(W, n=4, floor=0.01):
    W = W.copy()
    if W.shape[1] > n:
        idx = np.argsort(-W, axis=1)[:, n:]
        np.put_along_axis(W, idx, 0.0, axis=1)
    W[W < floor] = 0.0
    s = W.sum(1, keepdims=True)
    return W / np.maximum(s, 1e-12)


def body_weights(ob, K, groups, bones, power=4.0):
    V = mesh_arrays(ob)
    segs = deform_segments(K)
    bi = {b: i for i, b in enumerate(bones)}
    labels = list(groups)
    D = np.stack([peval(groups[g], V) for g in labels], 1)
    lab = np.argmin(D, 1)
    allowed = region_bones()
    W = np.zeros((len(V), len(bones)))
    for li, g in enumerate(labels):
        m = lab == li
        if not m.any():
            continue
        Vm = V[m]
        cols = []
        for b in allowed[g]:
            ss, rad = segs[b]
            d = np.min([seg_dist(Vm, a, c) for a, c in ss], axis=0)
            cols.append((bi[b], (rad / np.maximum(d, 1e-4)) ** power))
        Wm = np.zeros((len(Vm), len(bones)))
        for j, w in cols:
            Wm[:, j] = w
        W[m] = Wm / Wm.sum(1, keepdims=True)
    W = joint_plane_splits(V, W, bi, K)
    E = mesh_adjacency(ob)
    # rigid face/skull on headb (the jaw-line and nape are left to blend)
    hb = K["headb"]
    rigid_head = (lab == labels.index("head")) & ((V[:, 2] > 1.415) | (V[:, 1] < hb[1] - 0.05))
    W = smooth_weights(W, E, 4, 0.5)
    W[rigid_head] = 0.0
    W[rigid_head, bi["headb"]] = 1.0
    W = smooth_weights(W, E, 1, 0.3, lock=rigid_head)
    return limit_normalize(W), lab, labels


# Knee and elbow: the weight of the (upper, lower) bone pair is re-split by a plane
# through the joint (normal = bisector of the two limb directions), blended over
# +-width. The segment-distance weights let the thicker upper segment reach 5-7 cm down
# the shin (garters were 75 % thigh) and the forearm.
JOINT_SPLITS = [("upper_leg", "knee", "upper_leg", "knee", "ankle", 0.035),
                ("shoulder", "elbow", "shoulder", "elbow", "wrist", 0.03)]


def joint_plane_splits(V, W, bi, K):
    W = W.copy()
    for s, sd in ((1, "l"), (-1, "r")):
        for up, lo, a0, j, a1, width in JOINT_SPLITS:
            J = K.side(j, s)
            n = nrm(nrm(J - K.side(a0, s)) + nrm(K.side(a1, s) - J))
            f = smoothstep(-width, width, (V - J) @ n)
            iu, il = bi[sd + "_" + up], bi[sd + "_" + lo]
            P = W[:, iu] + W[:, il]
            W[:, iu], W[:, il] = P * (1 - f), P * f
    return W


def transfer_weights(src_ob, Wsrc, dst_ob):
    """Weights of the nearest source surface point (barycentric)."""
    me = src_ob.data
    me.calc_loop_triangles()
    Vs = mesh_arrays(src_ob)
    tris = np.array([t.vertices[:] for t in me.loop_triangles], int)
    bvh = BVHTree.FromPolygons([tuple(v) for v in Vs], [tuple(t) for t in tris], all_triangles=True)
    Vd = mesh_arrays(dst_ob)
    Wd = np.zeros((len(Vd), Wsrc.shape[1]))
    for i, p in enumerate(Vd):
        loc, nor, fi, dist = bvh.find_nearest(Vector(p))
        a, b, c = Vs[tris[fi]]
        # barycentric coordinates of loc in triangle abc
        v0, v1, v2 = b - a, c - a, np.array(loc) - a
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        d20, d21 = v2 @ v0, v2 @ v1
        den = max(d00 * d11 - d01 * d01, 1e-18)
        v = (d11 * d20 - d01 * d21) / den
        w = (d00 * d21 - d01 * d20) / den
        u = 1 - v - w
        bc = np.clip([u, v, w], 0, 1)
        bc /= bc.sum()
        Wd[i] = bc @ Wsrc[tris[fi]]
    return Wd


def transfer_from_tris(Vs, tris, Wsrc, Vd):
    """Weights of the nearest point on the triangles `tris` (indices into Vs)
    for each point of Vd (barycentric), and the distance to that point."""
    bvh = BVHTree.FromPolygons([tuple(v) for v in Vs], [tuple(t) for t in tris], all_triangles=True)
    Wd = np.zeros((len(Vd), Wsrc.shape[1]))
    dist = np.zeros(len(Vd))
    for i, p in enumerate(Vd):
        loc, nor, fi, d = bvh.find_nearest(Vector(p))
        a, b, c = Vs[tris[fi]]
        v0, v1, v2 = b - a, c - a, np.array(loc) - a
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        d20, d21 = v2 @ v0, v2 @ v1
        den = max(d00 * d11 - d01 * d01, 1e-18)
        v = (d11 * d20 - d01 * d21) / den
        w = (d00 * d21 - d01 * d20) / den
        bc = np.clip([1 - v - w, v, w], 0, 1)
        bc /= bc.sum()
        Wd[i] = bc @ Wsrc[tris[fi]]
        dist[i] = d
    return Wd, dist


def material_masks(ob):
    """({material name: vertex mask}, triangles (n, 3), triangle material index, names)."""
    me = ob.data
    names = [m.name if m else "" for m in me.materials]
    me.calc_loop_triangles()
    tris = np.array([t.vertices[:] for t in me.loop_triangles], int)
    tmat = np.array([t.material_index for t in me.loop_triangles], int)
    masks = {}
    for mi, n in enumerate(names):
        m = np.zeros(len(me.vertices), bool)
        m[tris[tmat == mi].ravel()] = True
        masks[n] = masks.get(n, np.zeros(len(me.vertices), bool)) | m
    return masks, tris, tmat, names


def sleeve_factor(P, K):
    """0 on the torso part of a garment, 1 on a sleeve (closer to the arm shape than
    to the torso shape), blended over about 2.5 cm at the armhole."""
    d_torso = peval(torso_shapes(K, smooth=True), P)
    d_arm = np.minimum(peval(arm_shapes(K, 1), P), peval(arm_shapes(K, -1), P))
    return smoothstep(-0.01, 0.015, d_torso - d_arm)


def _hat_split(t, knots):
    """Piecewise-linear partition of unity over `knots` (clamped at both ends):
    (n, len(knots)) weights."""
    t = np.clip(t, knots[0], knots[-1])
    out = np.zeros((len(t), len(knots)))
    for i in range(len(knots) - 1):
        a, b = knots[i], knots[i + 1]
        m = (t >= a) & (t <= b)
        u = (t[m] - a) / (b - a)
        out[m, i] = np.maximum(out[m, i], 1 - u)
        out[m, i + 1] = np.maximum(out[m, i + 1], u)
    return out / out.sum(1, keepdims=True)


# Upper arm: the shoulder's weight is spread along the arm (t = 0 at the shoulder joint,
# 1 at the elbow) over swing-only -> 1/3 -> 2/3 -> full twist. Forearm: the elbow's
# weight over 0 -> 30 -> 60 -> 90 % of the wrist roll (t = 0 elbow, 1 wrist).
UA_KNOTS, UA_BONES = [0.15, 0.42, 0.68, 0.92], ["shoulder_twist_b", "shoulder_twist_c", "shoulder_twist_d", "shoulder"]
FA_KNOTS, FA_BONES = [0.12, 0.38, 0.64, 0.90], ["elbow", "forarm_twist_a", "forarm_twist_b", "forarm_twist_c"]
ARMPIT_RADIUS = 0.20


def helper_weights(V, W, bones, K):
    """Moves arm weights onto the driven twist helpers (in place on a copy):
    1. shoulder weight -> UA_BONES along the upper arm, elbow weight -> FA_BONES
       along the forearm (the twist is spread, no candy-wrap at the wrist);
    2. near the shoulder, the blend between the torso (clavicle, spined, spinec) and the
       upper arm is re-expressed with the half-swing armpit bone in the middle: a vertex
       at torso/arm u (0..1) gets torso (1-2u)+, armpit 1-|2u-1|, arm (2u-1)+. Adjacent
       bones then differ by half the swing, which halves the linear-blend collapse.
    The weights stay a function of position and of the incoming weights, so every
    layer (skin, shirt, coat) at the same place gets the same result."""
    bi = {b: i for i, b in enumerate(bones)}
    W = W.copy()
    for s, sd in ((1, "l"), (-1, "r")):
        S, E, Wr = K.side("shoulder", s), K.side("elbow", s), K.side("wrist", s)
        for (A, B), knots, names in (((S, E), UA_KNOTS, UA_BONES), ((E, Wr), FA_KNOTS, FA_BONES)):
            src = bi[sd + ("_shoulder" if names is UA_BONES else "_elbow")]
            m = W[:, src] > 0
            if not m.any():
                continue
            ab = B - A
            t = ((V[m] - A) @ ab) / (ab @ ab)
            parts = _hat_split(t, knots)
            w = W[m, src].copy()
            W[m, src] = 0.0
            for k, n in enumerate(names):
                W[m, bi[sd + "_" + n]] += w * parts[:, k]
        torso = [bi[sd + "_clavicle"], bi["spined"], bi["spinec"]]
        arm = [bi[sd + "_" + n] for n in UA_BONES]
        T = W[:, torso].sum(1)
        Aw = W[:, arm].sum(1)
        m = (np.linalg.norm(V - S, axis=1) < ARMPIT_RADIUS) & (T > 1e-4) & (Aw > 1e-4)
        tot = T[m] + Aw[m]
        u = Aw[m] / tot
        nt = tot * np.clip(1 - 2 * u, 0, 1)
        nh = tot * (1 - np.abs(2 * u - 1))
        na = tot * np.clip(2 * u - 1, 0, 1)
        sub = W[m]
        sub[:, torso] *= (nt / T[m])[:, None]
        sub[:, arm] *= (na / Aw[m])[:, None]
        sub[:, bi[sd + "_shoulder_twist_a"]] += nh
        W[m] = sub
    return W


def skirt_weights(V, bones, hem=0.525, vent_top=0.80):
    """Pelvis at the waist, then per leg the front / side / back skirt helper by angle
    around the body (hat functions at 50 / 90 / 130 degrees from the front). Across the
    back centre line the two back panels share the weight over +-4 cm, except in the
    lowest third of the vent: the back reads as one panel and the tails part only near
    the hem."""
    bi = {b: i for i, b in enumerate(bones)}
    X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
    wp = smoothstep(0.70, 0.86, Z)
    ang = np.degrees(np.arctan2(np.abs(X), -Y))
    parts = _hat_split(ang, [50.0, 90.0, 130.0])
    z_split = hem + (vent_top - hem) / 3.0
    width = np.where(Y > 0.0, 0.002 + 0.040 * smoothstep(z_split - 0.02, z_split + 0.06, Z), 0.002)
    wl = smoothstep(-width, width, X)
    Ws = np.zeros((len(V), len(bones)))
    Ws[:, bi["pelvis"]] = wp
    for sd, ws in (("l", wl), ("r", 1 - wl)):
        for k, n in enumerate(("upper_leg_front_helper", "upper_leg_thigh_helper", "upper_leg_rear_helper")):
            Ws[:, bi[sd + "_" + n]] += (1 - wp) * ws * parts[:, k]
    return Ws


def queue_weights(V, bones):
    """Hair queue: rigid on the head at the top, then along the nape heada -> neck and a
    quarter spined at the tip (z-based, so it bends smoothly and never follows the back)."""
    bi = {b: i for i, b in enumerate(bones)}
    z = V[:, 2]
    knots = [1.300, 1.340, 1.370, 1.405]
    parts = _hat_split(z, knots)
    W = np.zeros((len(V), len(bones)))
    W[:, bi["spined"]] = 0.25 * parts[:, 0]
    W[:, bi["neck"]] = 0.75 * parts[:, 0] + parts[:, 1]
    W[:, bi["heada"]] = parts[:, 2]
    W[:, bi["headb"]] = parts[:, 3]
    return W


def rigid_islands(W, E, mask):
    """Gives every connected piece of the `mask` vertices the mean weights of the piece
    (limited to 4 influences), so small hard fittings move rigidly."""
    idx = np.nonzero(mask)[0]
    if len(idx) == 0:
        return W
    adj = {int(i): [] for i in idx}
    for a, b in E[mask[E[:, 0]] & mask[E[:, 1]]]:
        adj[int(a)].append(int(b))
        adj[int(b)].append(int(a))
    W = W.copy()
    seen = set()
    for start in adj:
        if start in seen:
            continue
        comp, stack = [], [start]
        seen.add(start)
        while stack:
            v = stack.pop()
            comp.append(v)
            for n in adj[v]:
                if n not in seen:
                    seen.add(n)
                    stack.append(n)
        W[comp] = limit_normalize(W[comp].mean(0, keepdims=True))[0]
    return W


BAND_SIGMA = 0.06      # m: leather band weights are averaged along the band over about this


def band_smooth(W, C, band):
    """Gaussian average of the weights of each leather band along its centre line (C), so
    the coat's fast pelvis -> spine change at the waist is spread along the band: a bend
    then lengthens every piece of the leather a little instead of one piece a lot."""
    W = W.copy()
    for b in (1, 2, 3):
        idx = np.nonzero(band == b)[0]
        if len(idx) == 0:
            continue
        P = C[idx]
        d2 = ((P[:, None, :] - P[None, :, :]) ** 2).sum(-1)
        G = np.exp(-d2 / (2 * BAND_SIGMA ** 2))
        W[idx] = (G @ W[idx]) / G.sum(1, keepdims=True)
    return W


SPINE_CHAIN = ["pelvis", "spinea", "spineb", "spinec", "spined"]


def chain_weights(W, mask, bones):
    """For the `mask` vertices: the weight on the spine chain (SPINE_CHAIN) is replaced by
    the same total on the two chain bones around its mean chain position. Limiting a
    spread-out chain weight to 4 bones otherwise lets neighbouring vertices keep different
    bone sets, and the leather tears between them when the spine bends (3x in a crouch).
    The mean position changes smoothly, so the band bends evenly."""
    bi = {b: i for i, b in enumerate(bones)}
    ch = [bi[b] for b in SPINE_CHAIN]
    W = W.copy()
    idx = np.nonzero(mask)[0]
    Wc = W[np.ix_(idx, ch)]
    tot = Wc.sum(1)
    u = (Wc * np.arange(len(ch))[None, :]).sum(1) / np.maximum(tot, 1e-12)
    lo = np.clip(np.floor(u).astype(int), 0, len(ch) - 2)
    f = np.clip(u - lo, 0.0, 1.0)
    new = np.zeros_like(Wc)
    new[np.arange(len(idx)), lo] = tot * (1 - f)
    new[np.arange(len(idx)), lo + 1] = tot * f
    W[np.ix_(idx, ch)] = new
    return W


def write_groups(ob, W, bones):
    ob.vertex_groups.clear()
    used = [j for j in range(len(bones)) if W[:, j].max() > 0]
    for j in used:
        vg = ob.vertex_groups.new(name=bones[j])
        nz = np.nonzero(W[:, j] > 0)[0]
        for i in nz:
            vg.add([int(i)], float(W[i, j]), "REPLACE")
    return [bones[j] for j in used]
