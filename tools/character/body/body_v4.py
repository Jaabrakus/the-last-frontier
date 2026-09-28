"""Full-skin player body v4 (2026-09-28): the MakeHuman body, assets/character/body/body.glb (+ body.json).

Built by tools/character/build_character.sh --body. The user found the body (v2's SDF mannequin below
the v3 head) did not look human, and wants clothes as equippable items, so the body shows bare: the
whole figure is now the MakeHuman base mesh (CC0, tools/character/makehuman), the head exactly the v3
head (body/mh.py head_piece: the same MakeHuman vertices), the rest fitted to the Actor_B skeleton.

  fit      MakeHuman's body (young, the build BODY_BUILD: a little leaner, the men more muscular than
           MakeHuman's average; half way to its ideal proportions, the women's breasts firmer:
           BODY_EXTRA) put on the Actor_B bind pose: the trunk as one piece (a similarity from its
           trunk joints to ours: MakeHuman's own posture kept), then the limbs re-posed with MPFB's
           game-engine rig (its bones on MakeHuman's joint helpers) and its CC0 skin weights
           (tools/character/makehuman/rigs), each limb bone moved onto ours (joint_targets) and
           stretched along itself only (linear blend skinning); the fingers curl with ours
  head     the v3 head's vertices (its fit, scalp and shapes) in place of MakeHuman's; the neck below
           the seam takes the difference over NECK_BLEND
  sex      the male fit on the same skeleton (the skeleton is shared; stature scales the instance)
  anatomy  the male genitals of MakeHuman's base mesh (helper-genital), on the pelvis; in the female
           base they are folded into the body (the `sex` shape brings them out) and the vulva is our
           own shape on the female base (VULVA; the `sex` shape takes it back out). Pubic hair of our
           own strands per body type (body/body_hair.py). The user asked for the bare body and the
           anatomy of a period history game (frontier-nudity).
  UVs      MakeHuman's UVs on every vertex (TEXCOORD_2 -> CUSTOM0): the skin textures' detail over
           the whole body (tools/character/mh_skin_detail.py)

The rest is body_v3's: regions, weights (body_weights on the body's part SDFs), helpers, metre UVs,
colours, the Face mesh (eyes, brows, lashes) and the export.
"""

import json
import os
import time

import bmesh
import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

from body import body as B
from body import body_v3 as V3
from body import mh as MH
from lib import LIB_VERSION
from lib import regions as RG
from lib import uv as UV
from lib.body_shapes import body_groups, body_node
from lib.context import BodyData
from lib.helpers import driver_reference, helpers_json
from lib.remesh import check_manifold, mesh_arrays, mesh_object, tri_count
from lib.rig import PROVENANCE_RIG, export_glb, godot_xf, xf12
from lib.sdf import log, smoothstep, v3
from lib.shapes import add_shape_keys, shape_stats
from lib.weights import body_weights, helper_weights, limit_normalize, mesh_adjacency, smooth_weights, write_groups
from lib.wrap import Surface

GLB = B.GLB
RIG_DIR = os.path.join(MH.MH_DIR, "rigs")
# MakeHuman's builds (young): the female a little leaner than average, the male muscular and lean
BODY_BUILD = {0: [("averagemuscle-averageweight", 0.7), ("averagemuscle-minweight", 0.3)],
              1: [("averagemuscle-averageweight", 0.25), ("maxmuscle-averageweight", 0.45), ("maxmuscle-minweight", 0.3)]}
# MakeHuman's ideal proportions (half way); for women firmer breasts (the average build's targets); for
# men the genitals smaller than MakeHuman's (the user, 2026-09-28). One range for every people: size
# is not set by ancestry; GENITAL_SHAPES gives each man his own size within it
BODY_EXTRA = {0: [("macrodetails/proportions/female-young-averagemuscle-averageweight-idealproportions", 0.5),
                  ("breast/female-young-averagemuscle-averageweight-averagecup-maxfirmness", 0.5)],
              1: [("macrodetails/proportions/male-young-averagemuscle-averageweight-idealproportions", 0.4),
                  ("genitals/penis-length-decr", 0.45), ("genitals/penis-circ-decr", 0.35),
                  ("genitals/penis-testicles-decr", 0.25)]}
# The bust gauge (look "bust", -1..1; BodyMaterials): MakeHuman's cup targets at the female build's
# weight mix, half way to max firmness as the base is; `breast_large` at 1 = MakeHuman's max cup,
# `breast_small` at 1 = its min cup (the base's firmness term taken back out)
_BUST_W = [("averageweight", 0.7), ("minweight", 0.3)]
_FIRM = ("breast/female-young-averagemuscle-averageweight-averagecup-maxfirmness", -0.5)
BUST_SHAPES = {cup: [("breast/female-young-averagemuscle-%s-%s-%s" % (w, cup_t, f), ww * 0.5)
                     for w, ww in _BUST_W for f in ("averagefirmness", "maxfirmness")] + [_FIRM]
               for cup, cup_t in (("breast_large", "maxcup"), ("breast_small", "mincup"))}
# Each man's own size (look "genital", -1..1): `genital_small` at 1 = MakeHuman's full decrease,
# `genital_large` at 1 = back to MakeHuman's own size (relative to the smaller default above)
GENITAL_SHAPES = {"genital_small": [("genitals/penis-length-decr", 0.55), ("genitals/penis-circ-decr", 0.45),
                                    ("genitals/penis-testicles-decr", 0.35)],
                  "genital_large": [("genitals/penis-length-decr", -0.45), ("genitals/penis-circ-decr", -0.35),
                                    ("genitals/penis-testicles-decr", -0.25)]}
GENITAL_WEIGHT = (0.002, 0.02)   # m from the body surface: the genitals' share on GENITAL_HELPER ramps 0 -> 1
# The vulva (the user, 2026-09-28: the women anatomically complete too): our own shape on the female base
# (the `sex` shape takes it back out for the men). Along the body's midline between the legs, from the
# foot of the mons (front_z, on the front) to the perineum (back_y, underneath): the labia majora, two
# rounded folds either side (labia_*) meeting in a closed crease (cleft_*: narrow and shallow, a line
# rather than a groove), a soft mons pubis above (mons_*), the crease lightly shaded (cavity) and the
# folds a little flushed. The base mesh is coarse there (1-3 cm): the patch within `band` of the midline
# is subdivided (smoothly, `cuts`), the strip within `fine` of it once more; the folds and the mons are
# relaxed over the mesh (`relax` passes) so they shade without facets.
VULVA = {"front_z": 0.782, "back_y": -0.012, "band": 0.03, "cuts": 3, "fine": 0.007, "fade": 0.02,
         "cleft_depth": 0.003, "cleft_w": 0.0012, "labia_h": 0.0025, "labia_u": 0.009, "labia_w": 0.009,
         "mons_h": 0.0035, "mons_s": -0.03, "mons_len": 0.028, "mons_w": 0.045, "relax": 4,
         "cavity": 0.35, "flush": 0.18}
TRUNK = ["joint-pelvis", "joint-neck", "joint-l-upper-leg", "joint-r-upper-leg", "joint-l-shoulder", "joint-r-shoulder",
         "joint-l-clavicle", "joint-r-clavicle"]
NECK_BLEND = 0.15         # the head's seam ring's offset fades out over this far down the neck (m)
# ... and out from the neck's axis (2026-09-28): the ring's offset (2-5 cm up) applied to the whole shoulder line made
# a flat shelf up to the neck; over this radius (fade from, to; m) the shoulders keep their own shape and the
# trapezius slopes up into the neck
NECK_RADIUS = (0.07, 0.17)
# Better: the offset fades with the distance over the surface from the seam ring (a graph distance along the mesh), so it
# runs down the neck and out over the trapezius and chest as one slope; NECK_GEO is the distance it fades over (m).
# (A straight-line fade from the neck's axis left a stiff collar at the neck base.) NECK_GEO 0 = the old separable fade.
NECK_GEO = 0.09
# the geodesic blend also fades out from the neck's axis (from, to; m): the neck's root rises into the neck, the shoulders
# themselves are not lifted with it (a shrug: the shoulder line rose 2-6 cm)
NECK_GEO_RADIUS = (0.06, 0.13)
# The neck below the seam is smoothed after that (2026-09-28: the ring's offset lifts the base's wider vertices up
# under the head, 2-5 cm, and leaves a bulb just below the seam): Taubin passes on the vertices from `top` to
# `bottom` metres below the seam plane (fading in and out), within `radius` of the neck's axis (fading out); the
# head's own vertices stay. Positions only: topology, weights and UVs are as they were.
NECK_SMOOTH = {"iters": 40, "top": (-0.02, 0.0), "bottom": (0.075, 0.115), "radius": (0.10, 0.15), "axis_y": 0.0,
               "tube": 0.025, "tube_r": (0.060, 0.075),
               "seat_depth": 0.03, "seat_gap": 0.0015, "seat_slope": 0.25}
# Broader, rounder male shoulders (the user, 2026-09-28: "too pointy, not broad enough", then "too weird": raised
# shoulders read as a shrug, so `up` is 0 and the neck's lift does not reach them, NECK_GEO_RADIUS): the male fit's
# outline was the female's, a steep slope from the neck to a point. Push each shoulder joint's (joint: the skeleton's,
# m) deltoid cap out (`out`) and up (`up`), full within `inner` of the joint, none beyond `outer` (all m), then
# smooth the region (`iters` Taubin passes) so it stays one surface. Positions only (skin weights stay).
SHOULDER_M = {"joint": (0.133, 0.029, 1.28), "out": 0.016, "up": 0.0, "inner": 0.055, "outer": 0.17, "iters": 12,
              # smaller trapezius (the user: "we can make the traps smaller"): the mound between the neck and the shoulder
              # goes down by `trap` m, across |x| from trap_x[0] (fading in) to trap_x[3] (fading out), above z 1.27..1.32
              "trap": 0.016, "trap_x": (0.045, 0.075, 0.11, 0.19)}
# A thinner male neck (the user, 2026-09-28: "make the men's necks thinner, like the women's"): the male fit's neck
# column (about the neck's tilted axis: through `axis`, leaning `tilt` degrees forward) is scaled in across the axis by
# `scale`, from the base up to the seam plus `tube` (fades in over `t` along the axis, out beyond `rho` across it, so
# the trapezius and the jaw keep their shape). The seam ring moves with it (head vertices of the tube included).
THIN_NECK = {"scale": 0.85, "axis": (0.0, 0.0, 1.325), "tilt": 17.0, "t": (-0.01, 0.03), "rho": (0.065, 0.085), "tube": 0.02}
GENITAL_SINK = 0.02       # the folded genitals (female base): shrunk to a point this far inside the pubic surface (below the vulva)
FINGERS = {1: ["thumba", "thumbb", "thumbc"], 2: ["indexa", "indexb", "indexc"], 3: ["middlea", "middleb", "middlec"],
           4: ["ringa", "ringb", "ringc"], 5: ["pinkyb", "pinkyc", "pinkyd"]}


def _rot_between(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(a @ b)
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3) if c > 0 else -np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1 / (1 + c))


def joint_targets(K, J):
    """Our position for each MakeHuman joint the rig uses (J: MakeHuman's joints in our axes, metres)."""
    T = {}
    hips = (K["l_upper_leg"] + K["r_upper_leg"]) / 2
    T["joint-pelvis"] = hips
    # the spine joints at their share of MakeHuman's pelvis -> neck height, along our spine
    chain = np.array([hips, K["pelvis"], K["spinea"], K["spineb"], K["spinec"], K["spined"], K["neck"]])
    seg = np.linalg.norm(np.diff(chain, axis=0), axis=1)
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    z0, z1 = J["joint-pelvis"][2], J["joint-neck"][2]
    for k in ("joint-spine-4", "joint-spine-3", "joint-spine-2", "joint-spine-1"):
        t = (J[k][2] - z0) / (z1 - z0) * cum[-1]
        i = int(np.clip(np.searchsorted(cum, t) - 1, 0, len(seg) - 1))
        T[k] = chain[i] + (chain[i + 1] - chain[i]) * ((t - cum[i]) / seg[i])
    T["joint-neck"] = K["neck"]
    T["joint-head"] = K["heada"]
    T["joint-head-2"] = K["heada"] + (J["joint-head-2"] - J["joint-head"])
    for s in ("l", "r"):
        T["joint-%s-clavicle" % s] = K[s + "_clavicle"]
        T["joint-%s-shoulder" % s] = K[s + "_shoulder"]
        T["joint-%s-elbow" % s] = K[s + "_elbow"]
        T["joint-%s-hand" % s] = K[s + "_wrist"]
        # MakeHuman's hand bone is short (to hand-3): its length kept, along our hand
        dh = K[s + "_middlea"] - K[s + "_wrist"]
        T["joint-%s-hand-3" % s] = K[s + "_wrist"] + dh / np.linalg.norm(dh) * np.linalg.norm(
            J["joint-%s-hand-3" % s] - J["joint-%s-hand" % s])
        for n, bs in FINGERS.items():
            P = [K[s + "_" + b] for b in bs]
            for i, p in enumerate(P):
                T["joint-%s-finger-%d-%d" % (s, n, i + 1)] = p
            T["joint-%s-finger-%d-4" % (s, n)] = P[2] + (P[2] - P[1]) * 0.9
        T["joint-%s-upper-leg" % s] = K[s + "_upper_leg"]
        T["joint-%s-knee" % s] = K[s + "_knee"]
        T["joint-%s-ankle" % s] = K[s + "_ankle"]
        T["joint-%s-foot-1" % s] = K[s + "_ball"]
        T["joint-%s-toe-2-4" % s] = K[s + "_ball"] + (J["joint-%s-toe-2-4" % s] - J["joint-%s-foot-1" % s])
    return T


def fit_body(mh, K, sex, extra=()):
    """Every MakeHuman vertex of the young body at the build of `sex` (0 female, 1 male), plus the
    targets `extra` [(name, weight)], re-posed onto our skeleton's bind pose (blender space, metres)."""
    rig = json.load(open(os.path.join(RIG_DIR, "rig.game_engine.json")))
    wts = json.load(open(os.path.join(RIG_DIR, "weights.game_engine.json")))["weights"]
    Vs = mh.V0 + mh.macro(sex, BODY_BUILD)
    for g, sh in ((0, 1.0 - sex), (1, sex)):
        for name, w in BODY_EXTRA[g]:
            if sh * w:
                Vs = Vs + sh * w * mh.target(name)
    for name, w in extra:
        Vs = Vs + w * mh.target(name)
    P = MH.to_ours(Vs, 0.1, v3(0, 0, 0))
    J = {k: P[sorted(v)].mean(0) for k, v in mh.group_verts.items() if k.startswith("joint-")}
    T = joint_targets(K, J)
    # the trunk as one piece: a similarity (uniform scale, rotation, offset) from MakeHuman's trunk joints
    # to ours, so MakeHuman's own posture and proportions stay (bending its spine onto ours pushed the
    # belly out and spread the hips); the spine bones then stay where MakeHuman has them
    A = np.array([J[k] for k in TRUNK])
    Bt = np.array([T[k] for k in TRUNK])
    ca, cb = A.mean(0), Bt.mean(0)
    U, Sg, Vt = np.linalg.svd((A - ca).T @ (Bt - cb))
    Dg = np.eye(3)
    Dg[2, 2] = np.sign(np.linalg.det(Vt.T @ U.T))
    R = Vt.T @ Dg @ U.T
    sc = float((Sg * np.diag(Dg)).sum() / ((A - ca) ** 2).sum())
    P = (P - ca) @ R.T * sc + cb
    J = {k: (v - ca) @ R.T * sc + cb for k, v in J.items()}
    for k in ("joint-pelvis", "joint-spine-4", "joint-spine-3", "joint-spine-2", "joint-spine-1"):
        T[k] = J[k]
    gen = np.array(sorted(mh.group_verts.get("helper-genital", ())), int)
    out = np.zeros_like(P)
    wsum = np.zeros(len(P))
    for b, d in rig.items():
        vw = wts.get(b, [])
        if not vw:
            continue
        hn, tn = d["head"]["cube_name"], d["tail"]["cube_name"]
        h, t = J[hn], J[tn]
        H, Tt = T[hn], T[tn]
        a = t - h
        an = a / np.linalg.norm(a)
        M = _rot_between(a, Tt - H) @ (np.eye(3) + (np.linalg.norm(Tt - H) / np.linalg.norm(a) - 1.0) * np.outer(an, an))
        idx = np.array([i for i, _ in vw], int)
        w = np.array([x for _, x in vw])
        if b != "pelvis" and len(gen):
            w = np.where(np.isin(idx, gen), 0.0, w)       # the genitals ride on the pelvis alone
        elif len(gen):
            w = np.where(np.isin(idx, gen), 1.0, w)
        out[idx] += w[:, None] * ((P[idx] - h) @ M.T + H)
        wsum[idx] += w
    ok = wsum > 1e-6
    out[ok] /= wsum[ok, None]
    out[~ok] = P[~ok]
    return out


def _geodesic(V, E, sources, limit):
    """Graph distance over the mesh edges `E` (pairs of vertex indices) from `sources`, up to `limit` (else inf)."""
    import heapq
    n = len(V)
    adj = [[] for _ in range(n)]
    for a, b in E:
        adj[a].append(b)
        adj[b].append(a)
    dist = np.full(n, np.inf)
    h = []
    for s0 in sources:
        dist[s0] = 0.0
        heapq.heappush(h, (0.0, int(s0)))
    while h:
        d, u = heapq.heappop(h)
        if d > dist[u] or d > limit:
            continue
        for v in adj[u]:
            nd = d + float(np.linalg.norm(V[u] - V[v]))
            if nd < dist[v]:
                dist[v] = nd
                heapq.heappush(h, (nd, v))
    return dist


def _neck_blend(V, head, ring, piece_ring, p, n, E=None):
    """The head's vertices at the v3 head's positions; the neck below the seam takes the ring's offset, fading with
    the distance over the surface from the seam ring (NECK_GEO; NECK_BLEND and NECK_RADIUS when NECK_GEO is 0)."""
    D_ring = piece_ring - V[ring]
    c = V[ring].mean(0)
    below = np.ones(len(V), bool)
    below[head] = False
    dist = -((V - p) @ n)
    if NECK_GEO > 0.0 and E is not None:
        g = _geodesic(V, E, ring, NECK_GEO)
        sel = below & np.isfinite(g) & (g < NECK_GEO) & (V[:, 2] > 1.1)
        w = 1.0 - smoothstep(0.0, NECK_GEO, g[sel])
        w = w * (1.0 - smoothstep(NECK_GEO_RADIUS[0], NECK_GEO_RADIUS[1], np.hypot(V[sel, 0] - c[0], V[sel, 1] - c[1])))
    else:
        sel = below & (dist > -0.02) & (dist < NECK_BLEND) & (V[:, 2] > 1.2)
        w = 1.0 - smoothstep(0.0, NECK_BLEND, np.maximum(dist[sel], 0.0))
        w = w * (1.0 - smoothstep(NECK_RADIUS[0], NECK_RADIUS[1], np.hypot(V[sel, 0] - c[0], V[sel, 1] - c[1])))
    D = V3._interp_ring(V3._angle(V[ring], c), D_ring, V3._angle(V[sel], c))
    V = V.copy()
    V[sel] += D * w[:, None]
    return V


def _smooth_neck(V, quads, is_head, p, n):
    """`V` with the neck below the head seam smoothed (NECK_SMOOTH), and the head piece's neck tube just above the seam
    (its own narrow tube ends in a lip over the body's neck: within `tube` of the seam, inside `tube_r` of the axis)."""
    c = NECK_SMOOTH
    pairs = []
    for q in quads:
        for i in range(len(q)):
            pairs.append((q[i], q[(i + 1) % len(q)]))
    E = np.array(pairs, int)
    E = np.concatenate([E, E[:, ::-1]])
    below = -((V - p) @ n)
    r = np.hypot(V[:, 0], V[:, 1] - c["axis_y"])
    w = (smoothstep(c["top"][0], c["top"][1], below) * (1.0 - smoothstep(c["bottom"][0], c["bottom"][1], below))
         * (1.0 - smoothstep(c["radius"][0], c["radius"][1], r)) * (~is_head))
    above = np.maximum(-below, 0.0)
    wh = (1.0 - smoothstep(0.0, c["tube"], above)) * (1.0 - smoothstep(c["tube_r"][0], c["tube_r"][1], r)) * is_head * (below > -c["tube"])
    w = np.maximum(w, wh)
    out = V.copy()
    for _ in range(c["iters"]):
        for f in (0.5, -0.53):
            acc = np.zeros_like(out)
            cnt = np.zeros(len(out))
            np.add.at(acc, E[:, 0], out[E[:, 1]])
            np.add.at(cnt, E[:, 0], 1.0)
            out = out + (f * w)[:, None] * (acc / np.maximum(cnt, 1.0)[:, None] - out)
    # seat the body on the seam: the body's vertices next to the head's seam ring lie a little below the seam plane
    # (1-2 mm of the body's first row stood above it and showed through the head's neck tube as a serrated lip)
    hv = is_head[E[:, 0]] & ~is_head[E[:, 1]]
    ring = np.unique(E[hv, 0])
    g = _geodesic(out, E, ring, c["seat_depth"])
    body = ~is_head & np.isfinite(g)
    d = (out - p) @ n
    lim = -(c["seat_gap"] + c["seat_slope"] * g)
    over = body & (d > lim)
    out[over] -= n * (d[over] - lim[over])[:, None]
    log("  neck smoothing: %d vertices, moved up to %.1f mm; seam seat: %d body vertices lowered" % (
        int((w > 0.01).sum()), float(np.linalg.norm(out - V, axis=1).max()) * 1000, int(over.sum())))
    return out


def _thin_neck(V, is_head, p, n):
    """`V` (the male fit) with a thinner neck (THIN_NECK)."""
    c = THIN_NECK
    if abs(c["scale"] - 1.0) < 1e-6:
        return V
    th = np.radians(c["tilt"])
    d = np.array([0.0, -np.sin(th), np.cos(th)])
    A0 = np.array(c["axis"])
    q = V - A0
    t = q @ d
    perp = q - t[:, None] * d
    rho = np.linalg.norm(perp, axis=1)
    above = np.maximum(((V - p) @ n), 0.0)
    w = (smoothstep(c["t"][0], c["t"][1], t) * (1.0 - smoothstep(c["rho"][0], c["rho"][1], rho))
         * (1.0 - smoothstep(0.0, c["tube"], above)))
    out = V + (perp * (c["scale"] - 1.0)) * w[:, None]
    log("  thin neck (x%.2f): %d vertices, moved up to %.1f mm" % (c["scale"], int((w > 0.01).sum()), float(np.linalg.norm(out - V, axis=1).max()) * 1000))
    return out


def _male_shoulders(V, quads):
    """`V` (the male fit) with broader, rounder shoulders (SHOULDER_M)."""
    c = SHOULDER_M
    J = np.array(c["joint"])
    side = np.where(V[:, 0] >= 0.0, 1.0, -1.0)
    q = np.stack([np.abs(V[:, 0]) - J[0], V[:, 1] - J[1], V[:, 2] - J[2]], 1)
    bump = 1.0 - smoothstep(c["inner"], c["outer"], np.linalg.norm(q, axis=1))
    out = V.copy()
    out[:, 0] += side * c["out"] * bump
    out[:, 2] += c["up"] * bump
    ax = np.abs(V[:, 0])
    tw = (smoothstep(c["trap_x"][0], c["trap_x"][1], ax) * (1.0 - smoothstep(c["trap_x"][2], c["trap_x"][3], ax))
          * smoothstep(1.27, 1.32, V[:, 2]))
    out[:, 2] -= c["trap"] * tw
    pairs = []
    for qd in quads:
        for i in range(len(qd)):
            pairs.append((qd[i], qd[(i + 1) % len(qd)]))
    E = np.array(pairs, int)
    E = np.concatenate([E, E[:, ::-1]])
    w = np.maximum(np.clip(bump * 1.5, 0.0, 1.0), tw)
    P = out
    for _ in range(c["iters"]):
        for f in (0.5, -0.53):
            acc = np.zeros_like(P)
            cnt = np.zeros(len(P))
            np.add.at(acc, E[:, 0], P[E[:, 1]])
            np.add.at(cnt, E[:, 0], 1.0)
            P = P + (f * w)[:, None] * (acc / np.maximum(cnt, 1.0)[:, None] - P)
    log("  male shoulders: %d vertices moved, up to %.1f mm" % (int((bump > 0.01).sum()), float(np.linalg.norm(P - V, axis=1).max()) * 1000))
    return P


def build_mesh(ctx, mh, piece):
    """(female base positions, male positions, triangles, triangle UVs, MakeHuman index per vertex,
    head mask, genital mask, shapes of the head piece per vertex)."""
    K = ctx.K
    Vf = fit_body(mh, K, 0.0)
    Vm = fit_body(mh, K, 1.0)
    # the bust gauge (on the female base) and each man's size (on the male fit): the fits' differences
    body_shapes = {nm: fit_body(mh, K, 0.0, ts) - Vf for nm, ts in BUST_SHAPES.items()}
    body_shapes.update({nm: fit_body(mh, K, 1.0, ts) - Vm for nm, ts in GENITAL_SHAPES.items()})
    head = piece["mh_idx"]
    ring = head[piece["slid"]]
    p, n = MH.seam_plane(B.CUT_GAP)
    # the neck takes the seam ring's offset from the fit, fading down (female and male each); the head's
    # vertices are the v3 head's
    male_head = piece["V"] + piece["shapes"]["sex"]
    E = np.array(sorted({(min(f[i], f[(i + 1) % len(f)]), max(f[i], f[(i + 1) % len(f)]))
                         for f, g in zip(mh.F, mh.G) if g == "body" for i in range(len(f))}), int)
    Vf = _neck_blend(Vf, head, ring, piece["V"][piece["slid"]], p, n, E)
    Vm = _neck_blend(Vm, head, ring, male_head[piece["slid"]], p, n, E)
    Vf[head] = piece["V"]
    Vm[head] = male_head
    # the faces: the body and the genitals
    gen_v = np.array(sorted(mh.group_verts.get("helper-genital", ())), int)
    faces, fuv = [], []
    for fi, (f, g) in enumerate(zip(mh.F, mh.G)):
        if g in ("body", "helper-genital"):
            faces.append(f)
            fuv.append([mh.VT[t] for t in mh.FT[fi]])
    used = np.array(sorted({i for f in faces for i in f}), int)
    remap = -np.ones(len(mh.V0), int)
    remap[used] = np.arange(len(used))
    quads = [[int(remap[i]) for i in f] for f in faces]
    Vf, Vm = Vf[used], Vm[used]
    is_head = np.isin(used, head)
    is_gen = np.isin(used, gen_v)
    Vf = _smooth_neck(Vf, quads, is_head, p, n)
    Vm = _thin_neck(Vm, is_head, p, n)
    Vm = _smooth_neck(Vm, quads, is_head, p, n)
    Vm = _male_shoulders(Vm, quads)
    # the female base: the genitals folded just inside the body (the nearest body surface)
    if is_gen.any():
        tri_b = [q for q, f in zip(quads, faces) if not all(is_gen[remap[i]] for i in f)]
        tris = []
        for q in tri_b:
            for k in range(1, len(q) - 1):
                tris.append((q[0], q[k], q[k + 1]))
        bvh = BVHTree.FromPolygons([tuple(v) for v in Vf], tris, all_triangles=True)
        # shrunk as a whole to a point just inside the pubic surface at their root (each vertex to its
        # own nearest surface tore them across the gap between the thighs)
        gi = np.nonzero(is_gen)[0]
        d = np.array([bvh.find_nearest(tuple(Vf[i]))[3] for i in gi])
        root = Vf[gi[d <= np.percentile(d, 25)]].mean(0)
        loc, nrm, _, _ = bvh.find_nearest(tuple(root))
        c = np.array(loc) - np.array(nrm) * GENITAL_SINK
        Vf[gi] = c + (Vf[gi] - root) * 0.02
    # head piece shapes (blink, face_*) per vertex
    pos = {int(m): i for i, m in enumerate(head)}
    shapes = {}
    for nm, d in piece["shapes"].items():
        if nm == "sex":
            continue
        S = np.zeros_like(Vf)
        for vi in np.nonzero(is_head)[0]:
            S[vi] = d[pos[int(used[vi])]]
        shapes[nm] = S
    for nm, d in body_shapes.items():
        S = d[used].copy()
        S[is_head] = 0.0
        if nm.startswith("breast"):
            S[is_gen] = 0.0
        else:
            S[~is_gen] = 0.0
        log("  shape %s: max %.1f mm" % (nm, float(np.linalg.norm(S, axis=1).max()) * 1000))
        shapes[nm] = S
    F, F_uv = MH._triangulate(Vf, quads, fuv)
    log("  body v4: %d verts, %d tris (MakeHuman body + genitals), head %d verts, genitals %d verts" % (
        len(Vf), len(F), int(is_head.sum()), int(is_gen.sum())))
    return Vf, Vm, np.array(F, int), np.array(F_uv), used, is_head, is_gen, shapes


def build(ctx, previews=None, export=True):
    t0 = time.time()
    K = ctx.K
    M = B._mats()
    Pf, Pm = ctx.P_female, ctx.P_male
    Ff = Pf.face
    groups = body_groups(K, Pf)
    node = body_node(groups)
    node_m = body_node(body_groups(K, Pm))
    mh = MH.MakeHuman()
    piece = MH.head_piece(mh, K, node, node_m)
    Vf, Vm, Ft, Ft_uv, used, head_v, gen_v, head_shapes = build_mesh(ctx, mh, piece)

    # ---- geometry: the MakeHuman body, clean region borders
    ob = mesh_object("Body", Vf, [tuple(f) for f in Ft], M["skin"])
    RG.cut_borders(ob, K, groups)
    vulva_subdivide(ob, gen_v)
    for pp in ob.data.polygons:
        pp.use_smooth = True
    preg, plab = RG.face_regions(ob, K, groups)
    V0 = mesh_arrays(ob)
    Fc = np.array([tuple(pp.vertices) for pp in ob.data.polygons], int)
    assert Fc.shape[1] == 3
    E = mesh_adjacency(ob)
    nm_edges = check_manifold(ob)
    log("body: %d tris %d verts, %d regions, non-manifold edges %d" % (len(Fc), len(V0), len(set(preg)), nm_edges))

    # ---- every vertex bound to the fitted MakeHuman surface (the region cuts added vertices)
    shapes_src = dict(head_shapes)
    shapes_src["sex"] = Vm - Vf
    surf = Surface(Vf, Ft, shapes=shapes_src)
    bind = surf.bind(V0)
    tri_head = head_v[Ft].all(1)
    tri_gen = gen_v[Ft].all(1)
    p, n = MH.seam_plane(B.CUT_GAP)
    is_head = tri_head[bind.tri] & ((V0 - p) @ n > -1e-4)
    is_gen = tri_gen[bind.tri]
    if float(np.abs(V0[:len(Vf)] - Vf).max()) < 1e-5:
        is_gen[:len(Vf)] = gen_v
        is_head[:len(Vf)] = head_v
    log("  head vertices %d, genital vertices %d" % (int(is_head.sum()), int(is_gen.sum())))

    # ---- weights, as v3; the genitals rigid on the pelvis
    Wb, lab, labels = body_weights(ob, K, groups, ctx.bones)
    vlab = np.array(labels, dtype=object)[lab]
    trunk = np.isin(vlab, ["torso", "neck"]) | (np.char.startswith(vlab.astype(str), "leg") & (V0[:, 2] > 0.60))
    trunk &= ~((vlab == "neck") & (V0[:, 2] > 1.40))
    Wb = limit_normalize(smooth_weights(Wb, E, B.TRUNK_SMOOTH, 0.5, lock=~trunk))
    hb = K["headb"]
    rigid = (vlab == "head") & ((V0[:, 2] > 1.415) | (V0[:, 1] < hb[1] - 0.05))
    nape = np.isin(vlab, ["head", "neck"]) & (V0[:, 2] > 1.36) & ~rigid
    Wb = limit_normalize(smooth_weights(Wb, E, B.NAPE_SMOOTH, 0.5, lock=~nape))
    if is_gen.any():
        Wb[is_gen] = 0.0
        Wb[is_gen, ctx.bones.index("pelvis")] = 1.0
    W = limit_normalize(helper_weights(V0, Wb, ctx.bones, K))
    W = breast_weights(ctx, W, used, surf, bind, len(Vf))
    Vs = V0

    # ---- shape keys
    t1 = time.time()
    headish = np.isin(vlab, ["head", "neck"]) & (V0[:, 2] > 1.30)
    head_fade = np.where(vlab == "head", 1.0, smoothstep(1.345, 1.372, V0[:, 2])) * headish
    # the fitted vertices keep their index through the region cuts (the cuts append theirs): their
    # shapes directly; the cut vertices from the surface they lie on (the folded genitals overlap, so
    # a nearest-triangle lookup could take a neighbour's shape)
    n0 = len(Vf)
    direct = float(np.abs(V0[:n0] - Vf).max()) < 1e-5
    log("  shapes: %s" % ("fitted vertices by index" if direct else "every vertex from the surface"))

    def shape_of(nm):
        d = surf.shape_delta(bind, nm)
        if direct:
            d[:n0] = shapes_src[nm]
        return d
    deltas = {"sex": shape_of("sex")}
    deltas["sex_head"] = deltas["sex"] * head_fade[:, None]
    for nm in ["blink"] + ["face_" + f for f in MH.MAP]:
        d = shape_of(nm)
        d[~is_head] = 0.0
        deltas[nm] = d
    for nm in list(BUST_SHAPES) + list(GENITAL_SHAPES):
        d = shape_of(nm)
        d[is_head] = 0.0
        if nm.startswith("genital"):
            d[~is_gen] = 0.0
        deltas[nm] = d
    log("shapes %s (%.1fs)" % (shape_stats(deltas), time.time() - t1))
    W = genital_weights(ctx, W, V0 + deltas["sex"], Fc, is_gen)

    # ---- attributes: UVMap (metres), Region, MHUV (every loop), COLOR_0
    UV.ensure_layers(ob, ("UVMap", "Region", "MHUV"))
    parts, part = UV.body_parts(K, plab, preg)
    UV.write(ob, "UVMap", UV.segment_uvs(ob, parts, part))
    codes = np.array([RG.encode(r) for r in preg])
    RG.write_region_uv(ob, codes, "Region")
    UV.write(ob, "MHUV", mh_uvs_all(ob, Vf, Ft, Ft_uv))
    # the vulva on the female base (after the UV lookups, which read the undisplaced surface); the men keep
    # MakeHuman's surface (the `sex` shape takes the offsets back out)
    Dv, v_cavity, v_flush = vulva_offsets(V0, Fc, is_gen)
    V0 += Dv
    ob.data.vertices.foreach_set("co", V0.astype(np.float32).ravel())
    ob.data.update()
    deltas["sex"] -= Dv
    Nv = B._vertex_normals(Vs, Fc)
    cols = B._body_colors(Vs, Nv, K, Ff, node, vlab)
    cols[:, 2] = np.minimum(cols[:, 2], v_cavity)
    cols[:, 0] = np.maximum(cols[:, 0], v_flush)
    bvh = BVHTree.FromPolygons([tuple(v) for v in Vs], [tuple(t) for t in Fc], all_triangles=True)
    cols[is_head] = MH.head_colors(Vs[is_head], Nv[is_head], piece, K, bvh)
    B._set_colors(ob, cols)
    fwarp, flm = V3.face_landmarks(Vs[is_head], cols[is_head, 1], piece, K)
    log("face warp h %s, u %s; landmarks %s" % (fwarp["h"], fwarp["u"], sorted(flm)))

    # ---- Face mesh (eyes, brows, lashes), as v3
    face, fzone, fkind, fside, lash_roots, lash_lower = V3.build_face(K, piece, bvh, M)
    Vfc = mesh_arrays(face)
    head_tris = np.isin(np.array([vlab[Fc[i, 0]] for i in range(len(Fc))]), ["head"])
    fsurf = Surface(Vs, Fc, shapes=deltas, allowed=head_tris)
    brow = fkind == 1
    lash = fkind == 2
    eye = fkind == 0
    fdeltas = {nm: np.zeros_like(Vfc) for nm in deltas}
    bb = fsurf.bind(Vfc[brow])
    br = fsurf.bind(lash_roots[lash])
    for nm in deltas:
        fdeltas[nm][brow] = fsurf.shape_delta(bb, nm)
        fdeltas[nm][lash] = fsurf.shape_delta(br, nm)
        key = "sex" if nm == "sex_head" else nm
        for s in (1, -1):
            if key in piece["eye_shapes"]:
                sel = eye & (fside == s)
                fdeltas[nm][sel] = piece["eye_shapes"][key][s]
                k = piece["eye_scale"].get(key, 1.0)
                fdeltas[nm][sel] += (Vfc[sel] - piece["eyes"][s]) * (k - 1.0)
    for s in (1, -1):
        sel = lash & (fside == s)
        _, dphi = MH.lid_blink(lash_roots[sel], piece["eyes"][s], s, piece["rows"][s], piece["eye_r"][s])
        cc = piece["eyes"][s]
        P = Vfc[sel]
        Fw = -(P[:, 1] - cc[1])
        U = P[:, 2] - cc[2]
        rho = np.sqrt(Fw * Fw + U * U)
        ang = np.arctan2(U, Fw) + dphi
        Q = P.copy()
        Q[:, 1] = cc[1] - rho * np.cos(ang)
        Q[:, 2] = cc[2] + rho * np.sin(ang)
        fdeltas["blink"][sel] = Q - P
    fcol = np.concatenate([np.ones((len(Vfc), 3)), np.zeros((len(Vfc), 1))], 1)
    fcol[lash_lower, 1] = 0.0
    B._set_colors(face, fcol)
    Wf = np.zeros((len(Vfc), len(ctx.bones)))
    Wf[:, ctx.bones.index("headb")] = 1.0

    add_shape_keys(ob, deltas)
    add_shape_keys(face, fdeltas)

    # ---- skin, export
    rig = ctx.bind_rig()
    stats = {}
    used_all = set()
    for o, Wo in ((ob, W), (face, Wf)):
        ub = write_groups(o, Wo, ctx.bones)
        used_all.update(ub)
        o.parent = rig
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
        stats[o.name] = {"tris": tri_count(o), "verts": len(o.data.vertices), "materials": [m.name for m in o.data.materials],
                         "bones": ub, "max_influences": int((Wo > 0).sum(1).max())}
    stats["Body"]["head_tris"] = int(np.array([r == "head" for r in preg]).sum())
    for bo in rig.data.bones:
        bo.use_deform = bo.name in used_all or bo.use_deform
    reg_tris = {}
    for r in preg:
        reg_tris[r] = reg_tris.get(r, 0) + 1
    from body import peoples as PEOPLES
    if export:
        export_glb(rig, [ob, face], GLB, texcoords=True, morph=True)
        info = {
            "generator": "tools/character/body/body_v4.py (build_character.sh --body)", "lib_version": LIB_VERSION,
            "blender": bpy.app.version_string, "glb": os.path.basename(GLB),
            "bind_clip": "actor_b/null-add",
            "bind_note": ("Armature rest in the glb == null-add pose evaluated on the Actor_B rig (unkeyed channels at rig "
                          "rest); glTF inverse binds are inverse(null-add global)."),
            "space": "Godot skeleton space: +Y up, character faces +Z (Blender (x, y, z) -> (x, z, -y)).",
            "objects": stats, "total_tris": sum(s["tris"] for s in stats.values() if isinstance(s, dict) and "tris" in s),
            "regions": RG.regions_json(), "region_tris": {r: reg_tris[r] for r in RG.REGION_LIST if r in reg_tris},
            "shapes": {"names": list(deltas), "max_delta_m": shape_stats(deltas),
                       "sex": "0 = female base, 1 = male fit (mesh only; the skeleton is unchanged)",
                       "sex_head": "the head part of `sex` only (for outfits built on the female body)",
                       "blink": "both eyes closed (lids rotated about the eye centres); driven at runtime",
                       "breast_large": "the bust gauge up (look bust > 0; MakeHuman's max cup at 1), female base",
                       "breast_small": "the bust gauge down (look bust < 0; MakeHuman's min cup at 1), female base",
                       "genital_small": "each man's size down (look genital < 0), at the look's sex weight",
                       "genital_large": "each man's size up (look genital > 0: MakeHuman's own at 1), at the sex weight",
                       "stature": {"female": 1.00, "male": 1.07, "min": 0.95, "max": 1.10,
                                   "note": "uniform scale of the Actor_B instance at runtime (design 3.3)"}},
            "body": {"model": "body v4: the MakeHuman base mesh (CC0) re-posed onto the Actor_B bind pose with MPFB's "
                              "game-engine rig and CC0 weights (tools/character/body/body_v4.py)",
                     "build": BODY_BUILD, "anatomy": "adult; the male genitals of the base mesh (helper-genital), "
                                                     "folded into the female base"},
            "face_presets": {k: PEOPLES.preset_face(v) for k, v in PEOPLES.LEGACY_PRESETS.items()},
            "face": {"model": "head v3: the MakeHuman base head (CC0, tools/character/makehuman) with the 30 creator "
                              "features mapped onto its targets (body/mh.py)", "features": PEOPLES.feature_table(),
                     "calibration": MH.CALIB, "male_features": MH.male_features(), "fit": piece["fit"],
                     "detail_rect": V3._detail_rect(),
                     "warp": dict(fwarp, note=("face coordinates (u = arc length about the head's axis at 0.08 m, h = "
                                               "height) of the v3 head's landmarks and the v2 head's: the facial hair "
                                               "regions, marks and paint (face_detail.gdshaderinc, FaceExtras) were "
                                               "drawn on the v2 head and are warped piecewise-linearly onto this one")),
                     "landmarks": dict(flm, note="Godot space: the jewellery places (FaceExtras.landmark_data)")},
            "skin": {"tones": B.SKIN_TONES, "undertones": B.UNDERTONES, "labels": ["Tone %d" % (i + 1) for i in range(12)],
                     "note": ("melanin 0..1 maps linearly onto the 12 anchors (linear light); undertone = Oklab a/b "
                              "offset; haemoglobin 0..1 (0.5 average) = blood seen through the epidermis")},
            "eyes": B.EYE_IRIS,
            "surfaces": {"Body": [{"name": "skin", "shader": "skin", "zones": ["skin"]}],
                         "Face": [{"name": "eye", "shader": "eye", "zones": ["eye"]},
                                  {"name": "face_hair", "shader": "face_hair", "zones": ["brows", "lashes"]}]},
            "params": {"female": {k: v for k, v in Pf.to_dict().items() if k != "face"},
                       "male": {k: v for k, v in Pm.to_dict().items() if k != "face"}},
            "deform_bones": [b for b in ctx.order if b in used_all],
            "helpers": helpers_json(),
            "driver_reference": driver_reference(ctx.rig, ctx.base, ctx.G),
            "inverse_bind_godot": {b: xf12(np.linalg.inv(godot_xf(ctx.G[b]))) for b in ctx.order if b in used_all},
            "transform_format": "12 floats: basis x, y, z columns, then origin",
            "provenance": PROVENANCE_RIG + " Body geometry: the MakeHuman base mesh, targets and MPFB's game-engine rig "
                                           "weights (CC0, MakeHuman Community; MPFB 2.0.17 data, "
                                           "tools/character/makehuman/README.md), fitted by tools/character/body/body_v4.py.",
        }
        with open(os.path.splitext(GLB)[0] + ".json", "w") as f:
            json.dump(info, f, indent=1)
        PEOPLES.write()
        log("exported %s (%.0f KB)" % (GLB, os.path.getsize(GLB) / 1024))
    freg = np.array([RG.REGIONS[r] for r in preg])
    body = BodyData(Vs, Fc, W, ctx.bones, vlab, freg, deltas)
    body.save()
    ctx.set_body(body)
    if export:
        # pubic hair (body/body_hair.py): grown on each type's own fit
        from body import body_hair as BH
        from lib.helpers import GENITAL_ROOT
        mid = _vulva_mid(V0, ~is_gen)
        BH.build(ctx, V0, V0 + deltas["sex"], Fc, W, is_gen, lambda X: _vulva_frame(V0, mid, X),
                 v3(GENITAL_ROOT[0], -GENITAL_ROOT[2], GENITAL_ROOT[1]), Vf, Vm, Ft, Ft_uv)
    log("body built in %.1fs: %s" % (time.time() - t0, {k: v["tris"] for k, v in stats.items()}))
    return {"Body": ob, "Face": face}


def _vulva_frame(V, mid, X=None):
    """Each point of X (default V) placed along the crotch midline: s (arc length from the anterior
    commissure; the posterior at s_end), u (sideways, x) and h (off the midline profile). `mid`: the
    body's midline vertices of V (x = 0) around the crotch, ordered front -> under -> back by their angle
    about the hips."""
    X = V if X is None else X
    c = np.array([-0.015, 0.82])
    P = V[mid][:, 1:3]
    ang = np.mod(np.arctan2(P[:, 1] - c[1], P[:, 0] - c[0]), 2 * np.pi)
    P = P[np.argsort(ang)]
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    cum = np.concatenate([[0.0], np.cumsum(seg)])

    def at(i, t):
        return cum[i] + t * seg[i]
    # the anterior commissure: where the front crosses front_z; the posterior: where the underside crosses back_y
    s_a = s_p = None
    for i in range(len(seg)):
        (y0, z0), (y1, z1) = P[i], P[i + 1]
        if s_a is None and y0 < -0.05 and (z0 - VULVA["front_z"]) * (z1 - VULVA["front_z"]) <= 0 and z0 != z1:
            s_a = at(i, (VULVA["front_z"] - z0) / (z1 - z0))
        if s_a is not None and s_p is None and z0 < 0.77 and (y0 - VULVA["back_y"]) * (y1 - VULVA["back_y"]) <= 0 and y0 != y1:
            s_p = at(i, (VULVA["back_y"] - y0) / (y1 - y0))
    assert s_a is not None and s_p is not None, "vulva: midline profile not found"
    # nearest point of the profile (y, z) for every point
    Q = X[:, 1:3]
    best = np.full(len(X), np.inf)
    s = np.zeros(len(X))
    for i in range(len(seg)):
        a, d = P[i], P[i + 1] - P[i]
        t = np.clip(((Q - a) @ d) / max(d @ d, 1e-12), 0.0, 1.0)
        dist = np.linalg.norm(Q - (a + t[:, None] * d), axis=1)
        m = dist < best
        best[m] = dist[m]
        s[m] = at(i, t[m])
    return s - s_a, X[:, 0], best, s_p - s_a


def _vulva_mid(V, keep):
    return np.nonzero((np.abs(V[:, 0]) < 1e-4) & keep & (V[:, 2] < 0.87) & (V[:, 1] > -0.12) & (V[:, 1] < 0.06))[0]


def vulva_subdivide(ob, gen0):
    """Subdivides the body's faces within VULVA band of the crotch midline (the female base): the cleft
    needs a few millimetres, the base mesh has 1-3 cm there. gen0: the genital mask of the first vertices
    (the fitted ones; their faces are left alone)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    n0 = len(bm.faces)
    b = VULVA["band"]
    counts = []
    for cuts, width, lo, hi in ((VULVA["cuts"], b, -b, 0.6 * b), (1, VULVA["fine"], -0.01, 0.005)):
        bm.verts.ensure_lookup_table()
        V = np.array([tuple(v.co) for v in bm.verts])
        gen = np.zeros(len(V), bool)
        gen[:len(gen0)] = gen0
        s, u, h, s_end = _vulva_frame(V, _vulva_mid(V, ~gen))
        near = (s > lo) & (s < s_end + hi) & (np.abs(u) < width) & (h < 0.025) & ~gen
        faces = [f for f in bm.faces if all(near[v.index] for v in f.verts)]
        edges = list({e for f in faces for e in f.edges})
        Fb = np.array([[v.index for v in f.verts] for f in bm.faces])
        nb = len(V)
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=cuts, use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
        # the new vertices onto a smooth surface through the old ones (Phong tessellation: no ripples)
        bm.verts.ensure_lookup_table()
        new = [v for v in bm.verts[nb:]]
        if new:
            Nb = B._vertex_normals(V, Fb)
            P = np.array([tuple(v.co) for v in new])
            tri, bary, _, _ = Surface(V, Fb).nearest(P)
            Vt, Nt = V[Fb[tri]], Nb[Fb[tri]]
            proj = P[:, None, :] - ((P[:, None, :] - Vt) * Nt).sum(2, keepdims=True) * Nt
            Q = 0.25 * P + 0.75 * np.einsum("ij,ijk->ik", bary, proj)
            for v, q in zip(new, Q):
                v.co = tuple(q)
        counts.append(len(faces))
    bm.to_mesh(ob.data)
    log("  vulva: %s faces subdivided, body %d -> %d faces" % (counts, n0, len(bm.faces)))
    bm.free()


def vulva_offsets(V, Fc, is_gen):
    """The vulva on the female base: per vertex, the offset along its normal (the cleft in, the labia out)
    and its colour terms (cavity, flush)."""
    s, u, h, s_end = _vulva_frame(V, _vulva_mid(V, ~is_gen))
    f = VULVA["fade"]
    env = smoothstep(0.0, f, s) * (1.0 - smoothstep(s_end - f, s_end, s))
    env_l = smoothstep(-f, f, s) * (1.0 - smoothstep(s_end - 0.5 * f, s_end + f, s))
    near = (np.abs(u) < VULVA["band"]) & (h < 0.025) & ~is_gen
    cleft = np.exp(-(u / VULVA["cleft_w"]) ** 2) * env * near
    labia = np.exp(-((np.abs(u) - VULVA["labia_u"]) / VULVA["labia_w"]) ** 2) * env_l * near
    mons = (np.exp(-((s - VULVA["mons_s"]) / VULVA["mons_len"]) ** 2) * np.exp(-(u / VULVA["mons_w"]) ** 2)
            * ((h < 0.03) & ~is_gen))
    N = B._vertex_normals(V, Fc)
    # the broad forms (folds, mons) relaxed over the mesh; the crease on top, sharp
    amt = VULVA["labia_h"] * labia + VULVA["mons_h"] * mons
    E = np.concatenate([Fc[:, [0, 1]], Fc[:, [1, 2]], Fc[:, [2, 0]]])
    E = np.concatenate([E, E[:, ::-1]])
    deg = np.bincount(E[:, 0], minlength=len(V)).astype(float)
    free = (amt > 1e-6) | np.isin(np.arange(len(V)), E[amt[E[:, 1]] > 1e-6, 0])
    for _ in range(VULVA["relax"]):
        avg = np.bincount(E[:, 0], weights=amt[E[:, 1]], minlength=len(V)) / np.maximum(deg, 1.0)
        amt = np.where(free & ~is_gen, 0.5 * amt + 0.5 * avg, amt)
    D = N * (amt - VULVA["cleft_depth"] * cleft)[:, None]
    cavity = 1.0 - VULVA["cavity"] * np.exp(-(u / (1.3 * VULVA["cleft_w"])) ** 2) * env * near
    flush = VULVA["flush"] * np.maximum(labia, cleft)
    log("  vulva: length %.1f cm, %d vertices moved (max in %.1f mm, out %.1f mm)" % (
        s_end * 100, int((np.linalg.norm(D, axis=1) > 1e-5).sum()),
        VULVA["cleft_depth"] * float(cleft.max()) * 1000, VULVA["labia_h"] * float(labia.max()) * 1000))
    return D, cavity, flush


def genital_weights(ctx, W, Vm, Fc, is_gen):
    """The male genitals (Vm: the male positions) on GENITAL_HELPER (driven at runtime as a bounce and a
    pendulum, CharacterBodyMesh), ramping from the pelvis over GENITAL_WEIGHT from the body surface; the
    root (the part closest to the body) and the tip (the farthest from it) checked against the runtime's
    GENITAL_ROOT / GENITAL_TIP."""
    from lib.helpers import GENITAL_HELPER, GENITAL_ROOT, GENITAL_TIP
    gi = np.nonzero(is_gen)[0]
    if not len(gi) or GENITAL_HELPER not in ctx.bones:
        return W
    tris = Fc[~is_gen[Fc].all(1)]
    bvh = BVHTree.FromPolygons([tuple(v) for v in Vm], [tuple(t) for t in tris], all_triangles=True)
    d = np.array([bvh.find_nearest(tuple(Vm[i]))[3] for i in gi])
    w = smoothstep(GENITAL_WEIGHT[0], GENITAL_WEIGHT[1], d)
    root = Vm[gi[d <= np.percentile(d, 25)]].mean(0)
    tip = Vm[gi[np.argmax(np.linalg.norm(Vm[gi] - root, axis=1))]]
    for nm, p, c in (("root", root, GENITAL_ROOT), ("tip", tip, GENITAL_TIP)):
        g = np.array([p[0], p[2], -p[1]])
        off = float(np.linalg.norm(g - np.array(c)))
        log("  genital %s (godot) %s, helpers.GENITAL_%s %s%s" % (nm, np.round(g, 3).tolist(), nm.upper(), list(c),
                                                                  "" if off < 0.005 else "  <-- %.0f mm off: update" % (off * 1000)))
    out = W.copy()
    out[gi] = 0.0
    out[gi, ctx.bones.index("pelvis")] = 1.0 - w
    out[gi, ctx.bones.index(GENITAL_HELPER)] = w
    log("  genital weights: %d vertices on %s (mean %.2f)" % (len(gi), GENITAL_HELPER, float(w.mean())))
    return out


def breast_weights(ctx, W, used, surf, bind, n0):
    """Each breast on its rig bone (l_breast / r_breast, driven at runtime as a damped spring): MPFB's CC0
    breast weights (MakeHuman vertices) on the fitted vertices by index, on the region cuts' vertices
    from the surface; the other bones share the rest."""
    src = json.load(open(os.path.join(RIG_DIR, "breast_weights.json")))["weights"]
    n_mh = int(used.max()) + 1
    out = W.copy()
    total = np.zeros(len(W))
    cols = {}
    for bone, vw in src.items():
        if bone not in ctx.bones:
            continue
        per_mh = np.zeros(n_mh)
        for i, w in vw:
            if i < n_mh:
                per_mh[i] = w
        wv = surf.interpolate(per_mh[used][:, None], bind.tri, bind.bary)[:, 0]
        wv[:n0] = per_mh[used]
        cols[ctx.bones.index(bone)] = np.clip(wv, 0.0, 1.0)
        total += cols[ctx.bones.index(bone)]
    if not cols:
        return W
    total = np.clip(total, 0.0, 1.0)
    out *= (1.0 - total)[:, None]
    for j, wv in cols.items():
        out[:, j] += wv
    log("  breast weights: %d vertices (max %.2f)" % (int((total > 0.01).sum()), float(total.max())))
    return limit_normalize(out)


def mh_uvs_all(ob, Vf, Ft, Ft_uv):
    """Per loop: the MakeHuman UV of the fitted body surface (every loop; each looked up a little inside
    its polygon, so a loop on a UV seam takes its own side's UV)."""
    me = ob.data
    V = mesh_arrays(ob)
    surf = Surface(Vf, Ft)
    pts, loops = [], []
    for p in me.polygons:
        vs = list(p.vertices)
        c = V[vs].mean(0)
        for li, vi in zip(range(p.loop_start, p.loop_start + p.loop_total), vs):
            pts.append(V[vi] * 0.97 + c * 0.03)
            loops.append(li)
    out = np.tile(np.array([-1.0, 2.0]), (len(me.loops), 1))
    tri, bary, _, _ = surf.nearest(np.array(pts))
    out[np.array(loops)] = np.einsum("ij,ijk->ik", bary, Ft_uv[tri])
    log("  MakeHuman UVs on %d loops" % len(loops))
    return out
