"""Common machinery of the military garments: spec, pieces -> one zoned surface, UVs,
edge distances, weights, occupied regions.

A garment is built from Pieces (Blender objects in the bind pose, Blender armature space:
z up, the character faces -y). assemble() joins them into the single opaque surface the
design asks for (one draw call; up to 4 material zones: 0 cloth, 1 facing / lining,
2 lace / tape / second leather, 3 metal) and returns the lib.pipeline.Surface that
finish_part() exports:

    ob     joined object (piece id kept in the int attributes "mil_piece")
    zones  per polygon (zone_fn(C, N) of each piece, or its fixed zone)
    uv     per loop, metres along the grain (cylinders around the body segments; trims:
           their own u across / v along, stored in the "mil_uv" point attribute)
    edge   per vertex (d_hem, d_open) in metres, for the shader's bands (lace, binding)
    colors per vertex (rgb baked shading multiplier, a = 1)
    W      per vertex (n, bones): cloth from the body (nearest body point, torso-from-
           torso above the waist, the lib's rule) or the piece's own function, smoothed;
           trims rigid per island with the mean weights of the cloth under them.
"""

import json
import math
import os

import bmesh
import bpy
import numpy as np

from lib import regions as RG
from lib import uv as UV
from lib.body_shapes import arm_shapes, torso_shapes
from lib.catalog import GarmentSpec
from lib.pipeline import TORSO_Z, Surface, body_weights_at
from lib.remesh import join, material, mesh_arrays
from lib.sdf import Offset, Onion, log, nrm, peval, smoothstep, v3
from lib.weights import (limit_normalize, mesh_adjacency, rigid_islands, skirt_weights, smooth_weights,
                         transfer_from_tris)
from lib.wrap import Surface as WrapSurface
from lib.wrap import vertex_normals

# check_body_deform.gd limits per surface: [collapse share, flip share, stretch share, max
# edge ratio]. Each garment's entry carries its own ("deform_limits", keyed by the surface
# name = the garment id, as the other garment sets do), set 25 % above its measured scan on
# both fits (the method of the legacy and body limits) and never above the legacy class
# limit of the same kind of garment (LEGACY_CLASS: coat, breeches, leggings, ...).
DEFAULT_LIMIT = [0.01, 0.01, 0.01, 4.0]
LEGACY_CLASS = {
    "coat": [0.072, 0.125, 0.23, 27.0], "breeches": [0.080, 0.092, 0.10, 15.0], "leggings": [0.022, 0.031, 0.006, 2.8],
    "linen": [0.005, 0.005, 0.04, 3.8], "waistcoat": [0.005, 0.005, 0.005, 2.4], "shoe": [0.0063, 0.0045, 0.005, 2.2],
    "belt": [0.005, 0.005, 0.0, 1.3], "strap": [0.005, 0.005, 0.0, 2.0], "rigid": [0.005, 0.005, 0.0, 1.3],
}
CONE_DEG = 25.0          # hides_regions: the skin's normal ray and 4 rays tilted this much must hit
OCCUPY_SHARE = 0.30      # occupies_regions: share of a region's skin under the garment

SET = "regulars"                      # catalog set "British & French regulars" (lib.catalog.SETS)
GLB_DIR = "garments/military"         # assets/character/garments/military/<id>.glb (+ .json fragment)
CLOTH, FACING, LACE, METAL = 0, 1, 2, 3
PROVENANCE_EXTRA = (" Fabric: the approved CC0 Poly Haven scans (assets/polyhaven/textures/clothing), tinted at "
                    "runtime. Cut, colours and trims follow the costume bible §5 (Set D) and its sources.")

# Evidence / sources shared by most items (costume bible §9 keys)
SRC_BRITISH = ["P5", "P6", "M1", "M5", "M20", "R12"]
SRC_FRENCH = ["M4", "M5", "M6", "R25"]


class MilSpec(GarmentSpec):
    """GarmentSpec whose glb and catalog fragment live in assets/character/garments/military/
    (the set stays the catalog's "regulars")."""

    def __init__(self, *a, limits=None, deform_class=None, cov_dist=0.12, **kw):
        """limits: this garment's check_body_deform limits (25 % above its scan), or None
        (the check's default); deform_class: the legacy LEGACY_CLASS key it is compared with."""
        kw.setdefault("set", SET)
        super().__init__(*a, **kw)
        if limits is None:
            limits = measured_limits().get(self.id)
        self.limits, self.deform_class, self.cov_dist = limits, deform_class, cov_dist

    def glb_rel(self):
        return "%s/%s.glb" % (GLB_DIR, self.id)

    def entry(self, stats=None, checks=None, generator=""):
        e = super().entry(stats, checks, generator)
        e["provenance"] = e["provenance"] + PROVENANCE_EXTRA
        return e


LIMITS_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_limits.json")


def measured_limits():
    """{garment id: [collapse, flip, stretch, max edge]} written by _scan_limits.py (25 %
    above the check_body_deform scan of the garment on both fits)."""
    if not os.path.exists(LIMITS_JSON):
        return {}
    with open(LIMITS_JSON) as f:
        return json.load(f).get("limits", {})


# ---------------------------------------------------------------------------
# pieces
# ---------------------------------------------------------------------------
class Piece:
    """A part of the garment surface.

    kind:    "cloth" (weights from `weights`, default body weights), "trim" (rigid per
             connected island, weights of the cloth pieces under it) or "rigid" (every
             vertex gets the row `weights`, a {bone: w} dict)
    zone:    fixed zone, or zone_fn(C (n, 3) polygon centres, N normals, L layer: 0 outer
             sheet, 1 inner copy (lining), 2 rim) -> zones
    uv:      "body" (cylinders around the body segments), "skirt" (vertical, r = 0.2),
             "attr" (the piece's "mil_uv" point attribute), or fn(P (loops, 3)) -> (loops, 2)
    weights: fn(ctx, V) -> W for cloth; {bone: w} for rigid
    shade:   fn(V, inner) -> per-vertex albedo multiplier (COLOR.rgb); inner = vertex of
             the inner copy (lining)
    """

    def __init__(self, ob, kind="cloth", zone=CLOTH, zone_fn=None, uv="body", weights=None, shade=None,
                 support=True):
        self.ob, self.kind, self.zone, self.zone_fn = ob, kind, zone, zone_fn
        self.uv, self.weights, self.shade, self.support = uv, weights, shade, support


def _tag(ob, i):
    me = ob.data
    if me.attributes.get("mil_layer") is None:
        a = me.attributes.new("mil_layer", "INT", "FACE")
        a.data.foreach_set("value", np.zeros(len(me.polygons), np.int32))
    for dom, n in (("POINT", len(me.vertices)), ("FACE", len(me.polygons))):
        a = me.attributes.get("mil_piece_" + dom) or me.attributes.new("mil_piece_" + dom, "INT", dom)
        a.data.foreach_set("value", np.full(n, i, np.int32))
    if me.attributes.get("mil_wshift") is None:
        a = me.attributes.new("mil_wshift", "FLOAT_VECTOR", "POINT")
        a.data.foreach_set("vector", np.zeros(3 * len(me.vertices), np.float32))
    if me.attributes.get("mil_src") is None:
        a = me.attributes.new("mil_src", "INT", "POINT")
        a.data.foreach_set("value", np.full(len(me.vertices), -1, np.int32))
    if me.attributes.get("mil_uv") is None:
        a = me.attributes.new("mil_uv", "FLOAT2", "POINT")
        a.data.foreach_set("vector", np.zeros(2 * len(me.vertices), np.float32))
    if not me.materials:
        me.materials.append(material("mil_piece", "#808080", 0.8))


def set_point_uv(ob, uv):
    me = ob.data
    a = me.attributes.get("mil_uv") or me.attributes.new("mil_uv", "FLOAT2", "POINT")
    a.data.foreach_set("vector", np.asarray(uv, np.float32).ravel())


def _read_int(me, name, n):
    out = np.empty(n, np.int32)
    me.attributes[name].data.foreach_get("value", out)
    return out


def poly_arrays(ob):
    me = ob.data
    C = np.array([p.center for p in me.polygons], float)
    N = np.array([p.normal for p in me.polygons], float)
    return C, N


def loop_topology(ob):
    return UV.loop_topology(ob)


# ---------------------------------------------------------------------------
# UVs (metres along the grain, design §8.4)
# ---------------------------------------------------------------------------
def body_uv_parts(K):
    yc = K["spineb"][1]
    parts = {"torso": UV.Segment("torso", (0, yc, 0.0), (0, yc, 1.0), (0, -1, 0), 0.14),
             "skirt": UV.Segment("skirt", (0, yc, 0.0), (0, yc, 1.0), (0, -1, 0), 0.20),
             "neck": UV.Segment("neck", (0, K["neck"][1], 0.0), (0, K["neck"][1], 1.0), (0, -1, 0), 0.06)}
    for s, sd in ((1, "l"), (-1, "r")):
        S, E, W = K.side("shoulder", s), K.side("elbow", s), K.side("wrist", s)
        H, Kn, A = K.side("upper_leg", s), K.side("knee", s), K.side("ankle", s)
        out = np.array([s, 0.0, 0.0])
        parts["upper_arm_" + sd] = UV.Segment("upper_arm_" + sd, S, E, out, 0.05)
        parts["forearm_" + sd] = UV.Segment("forearm_" + sd, E, W, out, 0.045, v0=float(np.linalg.norm(E - S)))
        parts["thigh_" + sd] = UV.Segment("thigh_" + sd, H, Kn, out, 0.08)
        parts["shin_" + sd] = UV.Segment("shin_" + sd, Kn, A, out, 0.055, v0=float(np.linalg.norm(Kn - H)))
        parts["shin_out_" + sd] = UV.Segment("shin_out_" + sd, Kn, A, -out, 0.055, v0=float(np.linalg.norm(Kn - H)))
        parts["foot_" + sd] = UV.Planar("foot_" + sd, A * np.array([1, 1, 0]), (0, -1, 0), (s, 0, 0))
    return parts


def classify_body_parts(ctx, C, skirt_mask=None, leg_seam_out=False):
    """Name of the UV part of each polygon centre (nearest body group; below the waist and
    `skirt_mask` -> the skirt cylinder)."""
    K = ctx.K
    lab = RG.group_labels(C, ctx.body_groups())
    out = np.empty(len(C), dtype=object)
    for i, (l, c) in enumerate(zip(lab, C)):
        if l in ("torso", "head"):
            out[i] = "torso"
        elif l == "neck":
            out[i] = "neck" if c[2] > 1.27 else "torso"
        elif l.startswith(("arm", "hand")):
            sd = l[-1]
            s = 1 if sd == "l" else -1
            E, S = K.side("elbow", s), K.side("shoulder", s)
            t = (c - S) @ (E - S) / ((E - S) @ (E - S))
            out[i] = ("upper_arm_" if t < 1.0 else "forearm_") + sd
        elif l.startswith(("leg", "foot")):
            sd = l[-1]
            s = 1 if sd == "l" else -1
            Kn = K.side("knee", s)
            if l.startswith("foot") and c[2] < 0.06:
                out[i] = "foot_" + sd
            elif c[2] > Kn[2]:
                out[i] = "thigh_" + sd
            else:
                out[i] = ("shin_out_" if leg_seam_out else "shin_") + sd
        else:
            out[i] = "torso"
    if skirt_mask is not None:
        out[np.asarray(skirt_mask, bool)] = "skirt"
    return out


def segment_loop_uvs(ob, parts, names_per_poly, poly_mask):
    keys = list(parts)
    idx = {k: i for i, k in enumerate(keys)}
    part = np.array([idx[n] if m else -1 for n, m in zip(names_per_poly, poly_mask)], int)
    return UV.segment_uvs(ob, [parts[k] for k in keys], part)


# ---------------------------------------------------------------------------
# weights
# ---------------------------------------------------------------------------
def body_W(ctx, V):
    """lib.pipeline.garment_body_weights on points: nearest body point; above the waist the
    torso part (not the sleeves) binds to the body's torso / neck only."""
    from lib.weights import sleeve_factor
    V = np.asarray(V, float)
    W = body_weights_at(ctx, V)
    sel = V[:, 2] > TORSO_Z[0]
    if sel.any():
        idx = np.nonzero(sel)[0]
        t = (1.0 - sleeve_factor(V[idx], ctx.K)) * smoothstep(TORSO_Z[0], TORSO_Z[1], V[idx, 2])
        Wt = body_weights_at(ctx, V[idx], torso_only=np.ones(len(idx), bool))
        W[idx] = W[idx] * (1 - t[:, None]) + Wt * t[:, None]
    return W


def labels_W(ctx, V, labels):
    """Weights of the nearest body point on the body triangles of the given group labels
    (e.g. ["torso"]: a collarless neckline follows the shoulders, not the neck)."""
    body = ctx.body()
    allowed = np.isin(body.vlab[body.F[:, 0]], labels)
    surf = WrapSurface(body.V, body.F, allowed=allowed)
    tri, bary, _, _ = surf.nearest(np.asarray(V, float))
    return surf.interpolate(body.W, tri, bary)


def torso_only_W(ctx, V):
    return body_weights_at(ctx, np.asarray(V, float), torso_only=np.ones(len(V), bool))


def skirt_W(ctx, V, W, mask, hem, vent_top, top=(0.93, 0.87)):
    """Coat skirt: the body weights blend into lib.weights.skirt_weights (pelvis at the
    waist, then the driven front / side / back panel helpers) from top[0] down to top[1]."""
    V = np.asarray(V, float)
    Ws = skirt_weights(V, ctx.bones, hem=hem, vent_top=vent_top)
    t = smoothstep(top[0], top[1], V[:, 2]) * np.asarray(mask, float)
    return W * (1 - t[:, None]) + Ws * t[:, None]


def rigid_row(ctx, bones_w):
    row = np.zeros(len(ctx.bones))
    for b, w in bones_w.items():
        row[ctx.bones.index(b)] = w
    return row / row.sum()


def strip_bones(ctx, W, names, to="pelvis"):
    """Moves the weight of `names` to `to` (e.g. leg bones of a belt -> pelvis)."""
    bi = {b: i for i, b in enumerate(ctx.bones)}
    cols = [bi[n] for n in names if n in bi]
    W = W.copy()
    gone = W[:, cols].sum(1)
    W[:, cols] = 0.0
    W[:, bi[to]] += gone
    return W / np.maximum(W.sum(1, keepdims=True), 1e-12)


LEG_BONES = [sd + "_" + n for sd in "lr" for n in ("upper_leg", "knee", "ankle", "upper_leg_front_helper",
                                                   "upper_leg_thigh_helper", "upper_leg_rear_helper")]


# ---------------------------------------------------------------------------
# assembly
# ---------------------------------------------------------------------------
def assemble(ctx, spec, pieces, edge_fn=None, smooth=(1, 0.3), uv_skirt=None, leg_seam_out=False,
             name=None, weight_post=None, local_smooth=()):
    """Joins the pieces into one object and returns lib.pipeline.Surface for finish_part.
    Also fills spec.occupies_regions from the polygons' nearest body regions."""
    obs = []
    for i, pc in enumerate(pieces):
        _tag(pc.ob, i)
        obs.append(pc.ob)
    ob = join(obs, name or spec.id) if len(obs) > 1 else obs[0]
    me = ob.data
    V = mesh_arrays(ob)
    vpiece = _read_int(me, "mil_piece_POINT", len(me.vertices))
    fpiece = _read_int(me, "mil_piece_FACE", len(me.polygons))
    flayer = _read_int(me, "mil_layer", len(me.polygons))
    C, N = poly_arrays(ob)
    # zones
    zones = np.zeros(len(me.polygons), int)
    for i, pc in enumerate(pieces):
        m = fpiece == i
        if not m.any():
            continue
        zones[m] = pc.zone_fn(C[m], N[m], flayer[m]) if pc.zone_fn is not None else pc.zone
    # UVs
    lv, lp = loop_topology(ob)
    uv = np.zeros((len(lv), 2))
    parts = body_uv_parts(ctx.K)
    body_polys = np.array([pieces[p].uv in ("body", "skirt") for p in fpiece])
    if body_polys.any():
        skirt = np.array([pieces[p].uv == "skirt" for p in fpiece])
        if uv_skirt is not None:
            skirt |= uv_skirt(C) & body_polys
        names = classify_body_parts(ctx, C, skirt_mask=skirt, leg_seam_out=leg_seam_out)
        uvb = segment_loop_uvs(ob, parts, names, body_polys)
        lm = body_polys[lp]
        uv[lm] = uvb[lm]
    a = me.attributes.get("mil_uv")
    if a is not None:
        pu = np.empty(2 * len(me.vertices), np.float32)
        a.data.foreach_get("vector", pu)
        pu = pu.reshape(-1, 2)
        lm = np.array([pieces[p].uv == "attr" for p in fpiece])[lp]
        uv[lm] = pu[lv[lm]]
    for i, pc in enumerate(pieces):
        if callable(pc.uv):
            lm = fpiece[lp] == i
            uv[lm] = pc.uv(V[lv[lm]])
    # colours (the inner copy / lining a little darker: it is in the cloth's shade)
    vinner = np.zeros(len(V), bool)
    for p in me.polygons:
        if flayer[p.index] == 1:
            vinner[list(p.vertices)] = True
    col = np.ones((len(V), 4))
    for i, pc in enumerate(pieces):
        if pc.shade is not None:
            m = vpiece == i
            col[m, :3] = np.asarray(pc.shade(V[m], vinner[m]), float)[:, None]
    # weights
    W = np.zeros((len(V), len(ctx.bones)))
    E = mesh_adjacency(ob)
    # weights are evaluated at V + mil_wshift: the two edges of a split seam (a vent) sit
    # on the seam line and are evaluated a little to their own side
    ws = np.empty(3 * len(V), np.float32)
    me.attributes["mil_wshift"].data.foreach_get("vector", ws)
    Vw = V + ws.reshape(-1, 3)
    for i, pc in enumerate(pieces):
        m = vpiece == i
        if not m.any():
            continue
        if pc.kind == "cloth":
            W[m] = pc.weights(ctx, Vw[m]) if pc.weights is not None else body_W(ctx, Vw[m])
        elif pc.kind == "rigid":
            W[m] = rigid_row(ctx, pc.weights)
    cloth_v = np.array([pieces[p].kind == "cloth" for p in vpiece])
    if smooth and smooth[0] > 0:
        W = smooth_weights(W, E, smooth[0], smooth[1], lock=~cloth_v)
    for mask_fn, iters, alpha in local_smooth:
        # extra smoothing where nearest-point weights jump (the crotch bridge of breeches:
        # its middle is nearest to one thigh or the other, and a leg spreading tore that line)
        m = np.asarray(mask_fn(V), bool) & cloth_v
        if m.any():
            W = smooth_weights(W, E, iters, alpha, lock=~m)
    # the lining (inner copy) and the rim lips move with the outer sheet: each of their
    # vertices takes the weights of the nearest outer-sheet vertex of its piece, so the cloth's
    # thickness never stretches or lets the lining drift through the outer layer
    vouter = np.zeros(len(V), bool)
    vnon = np.zeros(len(V), bool)
    for p_ in me.polygons:
        (vouter if flayer[p_.index] == 0 else vnon)[list(p_.vertices)] = True
    follow = vnon & ~vouter & cloth_v
    if follow.any():
        # solidify copies the "mil_src" index of the vertex each offset vertex came from
        vsrc = _read_int(me, "mil_src", len(me.vertices)) if me.attributes.get("mil_src") else np.full(len(V), -1)
        twin = {}
        for j in np.nonzero(vouter)[0]:
            if vsrc[j] >= 0:
                twin[(int(vpiece[j]), int(vsrc[j]))] = j
        missing = 0
        for j in np.nonzero(follow)[0]:
            k = twin.get((int(vpiece[j]), int(vsrc[j])))
            if k is None:
                missing += 1
                continue
            W[j] = W[k]
        if missing:
            log("  %s: %d lining / rim vertices without an outer twin keep their own weights" % (spec.id, missing))
    trims = np.array([pieces[p].kind == "trim" for p in vpiece])
    if trims.any():
        me.calc_loop_triangles()
        T = np.array([t.vertices[:] for t in me.loop_triangles], int)
        tp = np.array([t.polygon_index for t in me.loop_triangles], int)
        sup = np.array([pieces[p].kind == "cloth" and pieces[p].support for p in fpiece])[tp]
        Wt, _ = transfer_from_tris(V, T[sup], W, V[trims])
        W[trims] = Wt
        W = rigid_islands(W, E, trims)
    if weight_post is not None:
        W = weight_post(ctx, V, W, vpiece)
    W = limit_normalize(W)
    edge = edge_fn(V) if edge_fn is not None else None
    counts = np.bincount(fpiece, minlength=len(pieces))
    tri_counts = [0] * len(pieces)
    for p_ in me.polygons:
        tri_counts[fpiece[p_.index]] += len(p_.vertices) - 2
    spec.extra["pieces_tris"] = {"%d_%s" % (i, pieces[i].kind): int(tri_counts[i]) for i in range(len(pieces))}
    log("  %s triangles per piece: %s" % (spec.id, spec.extra["pieces_tris"]))
    settle(ctx, spec, ob)
    log("  %s: %d pieces, %d polys, zones %s, hides %s" % (spec.id, len(pieces), len(me.polygons),
                                                          sorted(set(zones.tolist())), spec.hides_regions))
    return Surface(ob, zones=zones, uv=uv, weights=W, colors=col, edge=edge)


# ---------------------------------------------------------------------------
# checks at bind: coverage (hides / occupies), fit on both bodies, deform limits
# ---------------------------------------------------------------------------
def sex_delta(ctx, ob):
    """The `sex` shape the pipeline will add (same wrap transfer and smoothing)."""
    body = ctx.body()
    surf = WrapSurface(body.V, body.F, shapes=body.shapes)
    return surf.shape_delta(surf.bind(mesh_arrays(ob)), "sex", smooth_E=mesh_adjacency(ob), smooth_iters=3)


def _tri(ob):
    me = ob.data
    me.calc_loop_triangles()
    return np.array([t.vertices[:] for t in me.loop_triangles], int)


def coverage(ctx, ob, D, regions=None, max_dist=0.12, cone_deg=CONE_DEG):
    """{region: {"normal": share, "cone": share}}, the minimum over both fits: the share of
    the region's skin samples (vertices and triangle centres) whose normal ray (and, for
    "cone", also 4 rays tilted by cone_deg) hits the garment within max_dist."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    body = ctx.body()
    F = _tri(ob)
    Vg0 = mesh_arrays(ob)
    regions = list(RG.REGION_LIST) if regions is None else list(regions)
    res = {r: {"normal": 1.0, "cone": 1.0} for r in regions}
    ca, sa = math.cos(math.radians(cone_deg)), math.sin(math.radians(cone_deg))
    for Vb, Vg in ((body.V, Vg0), (body.V + body.shapes["sex"], Vg0 + D)):
        bvh = BVHTree.FromPolygons([tuple(p) for p in Vg], [tuple(t) for t in F], all_triangles=True)
        Nb = vertex_normals(Vb, body.F)
        for r in regions:
            tri = np.nonzero(body.freg == RG.REGIONS[r])[0]
            if not len(tri):
                continue
            vid = np.unique(body.F[tri])
            P = np.concatenate([Vb[vid], Vb[body.F[tri]].mean(1)])
            N = np.concatenate([Nb[vid], Nb[body.F[tri]].mean(1)])
            N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
            a = np.where(np.abs(N[:, 0:1]) < 0.9, np.array([[1.0, 0, 0]]), np.array([[0, 1.0, 0]]))
            t1 = a - N * (a * N).sum(1, keepdims=True)
            t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-12)
            t2 = np.cross(N, t1)
            n_hit = c_hit = 0
            for i in range(len(P)):
                o = Vector(P[i] + N[i] * 0.0005)
                if bvh.ray_cast(o, Vector(N[i]), max_dist)[0] is None:
                    continue
                n_hit += 1
                ok = True
                for t in (t1[i], -t1[i], t2[i], -t2[i]):
                    if bvh.ray_cast(o, Vector(N[i] * ca + t * sa), max_dist)[0] is None:
                        ok = False
                        break
                c_hit += ok
            res[r]["normal"] = min(res[r]["normal"], n_hit / len(P))
            res[r]["cone"] = min(res[r]["cone"], c_hit / len(P))
    return res


def fit_report(ctx, ob, D):
    """Clearance over the skin at bind of the garment (female) and of its `sex` shape over
    the male body: min and 5th percentile (mm), vertices inside the skin."""
    V = mesh_arrays(ob)
    df = peval(ctx.body_sdf(), V)
    dm = peval(ctx.body_sdf(ctx.P_male), V + D)
    rep = {}
    for name, d in (("female", df), ("male", dm)):
        rep[name] = {"min_mm": round(float(d.min()) * 1000, 2), "p05_mm": round(float(np.percentile(d, 5)) * 1000, 2),
                     "inside_skin": int((d < 0.0).sum())}
    return rep


def settle(ctx, spec, ob):
    """hides_regions = the declared candidates that pass the cone test on both fits;
    occupies_regions = regions with >= OCCUPY_SHARE of their skin under the garment. The
    numbers go into the catalog entry ("coverage", "fit_check"), with "deform_limits"."""
    D = sex_delta(ctx, ob)
    cand = list(spec.hides_regions)
    dist = getattr(spec, "cov_dist", 0.12)
    cov = coverage(ctx, ob, D, max_dist=dist)
    hides = [r for r in cand if cov[r]["cone"] >= 0.999]
    dropped = {r: round(cov[r]["cone"], 3) for r in cand if r not in hides}
    spec.hides_regions = hides
    spec.occupies_regions = [r for r in RG.REGION_LIST if cov[r]["normal"] >= OCCUPY_SHARE]
    spec.extra["coverage"] = {"method": "rays from the skin: normal + 4 tilted %.0f deg, female and male fit, "
                                        "within %.0f cm (military_lib._base.coverage)" % (CONE_DEG, dist * 100),
                              "hidden": hides, "not_hidden_candidates": dropped,
                              "share": {r: {"normal": round(cov[r]["normal"], 3), "cone": round(cov[r]["cone"], 3)}
                                        for r in RG.REGION_LIST if cov[r]["normal"] > 0.0}}
    spec.extra["fit_check"] = fit_report(ctx, ob, D)
    spec.extra["deform_limits"] = {spec.id: list(spec.limits) if getattr(spec, "limits", None) else list(DEFAULT_LIMIT)}
    if getattr(spec, "deform_class", None):
        spec.extra["deform_class"] = {"class": spec.deform_class, "legacy_limit": LEGACY_CLASS[spec.deform_class]}
    if dropped:
        log("  %s NOT hidden (cone share < 1): %s" % (spec.id, dropped))
    log("  %s fit at bind: %s" % (spec.id, spec.extra["fit_check"]))


# ---------------------------------------------------------------------------
# SDF helpers
# ---------------------------------------------------------------------------
def shell(form, inner, outer):
    """Cloth shell between `inner` and `outer` metres outside the solid `form`."""
    return Onion(Offset(form, 0.5 * (inner + outer)), 0.5 * (outer - inner))


def bumped(form, base, bumps, r_max=None):
    """`form` offset by base (metres or fn(X, Y, Z)) + the sum of bump fields."""
    def r(X, Y, Z):
        acc = base(X, Y, Z) if callable(base) else base
        for b in bumps:
            acc = acc + b(X, Y, Z)
        return acc
    if r_max is None:
        r_max = (0.03 if callable(base) else base + 0.01)
    return Offset(form, r, r_max=r_max)


def sheet(name, outer_form, region, h, target, mat, sizing=None, domain=None, **kw):
    """The OUTER surface of a garment as an open sheet. The smooth outer form (its zero set
    is the cloth's outer surface; `domain` optionally bounds it well outside the garment)
    is polygonised and remeshed without any cut (no sharp corner for the remesher to
    approximate), then cut exactly along the zero set of `region` (cut_levelset) and the
    outside (region > 0) dropped: the garment's edges follow the cut curves."""
    from lib.remesh import sdf_object
    from lib.sdf import Inter, project_to_surface
    solid = Inter(outer_form, domain) if domain is not None else outer_form

    def siz(P):
        L = sizing(P) if sizing is not None else np.full(len(P), 0.02)
        out = peval(region, P) > 0.012 if region is not None else np.zeros(len(P), bool)
        return np.where(out, np.maximum(L, 0.045), L)
    kw.setdefault("pre_ratio", 1.3)
    ob = sdf_object(name, solid, h, target, mat, sizing=siz, **kw)
    V = mesh_arrays(ob)
    keep = peval(outer_form, V) > -0.02
    V[keep] = project_to_surface(outer_form, V[keep], 0.004, iters=4)
    ob.data.vertices.foreach_set("co", V.ravel())
    ob.data.update()
    if region is not None:
        n0 = len(ob.data.polygons)
        cut_levelset(ob, lambda P: peval(region, P), name="garment edge", snap=0.25)
        drop_faces(ob, lambda C: peval(region, C) > 0.0)
        dissolve_slivers(ob, 0.002)
        log("  %-12s sheet: %d -> %d faces inside the cuts" % (name, n0, len(ob.data.polygons)))
    return ob


def split_seam(ob, fn, face_sel, gap=0.0012, name="seam", probe=0.006):
    """Cuts along the zero set of fn inside face_sel and splits the mesh there (a vent or a
    slit: both edges stay in place, now free to part), moving each side gap/2 off the cut."""
    cut_levelset(ob, fn, face_sel, name=name)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    V = np.array([v.co for v in bm.verts], float)
    fv = np.asarray(fn(V), float)
    bm.faces.ensure_lookup_table()
    C = np.array([f.calc_center_median() for f in bm.faces], float)
    sel = np.asarray(face_sel(C), bool)
    on = {v for v in bm.verts if abs(fv[v.index]) < 2e-4}
    edges = [e for e in bm.edges if e.verts[0] in on and e.verts[1] in on
             and any(sel[f.index] for f in e.link_faces) and len(e.link_faces) == 2]
    bmesh.ops.split_edges(bm, edges=edges)
    bm.faces.ensure_lookup_table()
    bm.verts.ensure_lookup_table()
    shift = np.zeros((len(bm.verts), 3))
    for v in bm.verts:
        if not v.link_faces:
            continue
        p = np.array(v.co, float)
        if abs(float(fn(p[None])[0])) >= 2e-4:
            continue
        c = np.mean([np.array(f.calc_center_median(), float) for f in v.link_faces], axis=0)
        side = float(np.sign(fn(c[None])[0]))
        if side == 0.0:
            continue
        g = np.array([(fn((p + e * 1e-3)[None])[0] - fn((p - e * 1e-3)[None])[0]) / 2e-3 for e in np.eye(3)])
        g /= max(np.linalg.norm(g), 1e-9)
        v.co = tuple(p + g * side * gap * 0.5)
        shift[v.index] = g * side * probe
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    me = ob.data
    a = me.attributes.get("mil_wshift") or me.attributes.new("mil_wshift", "FLOAT_VECTOR", "POINT")
    a.data.foreach_set("vector", shift.astype(np.float32).ravel())
    log("  %-12s %s: %d edges split" % (ob.name, name, len(edges)))


def dissolve_slivers(ob, dist):
    """Collapses edges shorter than `dist` (the slivers where cut curves meet each other or
    a boundary): their stretch ratio in a pose is huge for a tiny length."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    n0 = len(bm.verts)
    bmesh.ops.dissolve_degenerate(bm, dist=dist, edges=bm.edges[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    log("  %-12s slivers: %d vertices merged" % (ob.name, n0 - len(ob.data.vertices)))


def drop_faces(ob, fn):
    """Deletes the faces whose centre satisfies fn(C) (and loose vertices)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    C = np.array([f.calc_center_median() for f in bm.faces], float)
    m = np.asarray(fn(C), bool)
    dead = [f for f, k in zip(bm.faces, m) if k]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return len(dead)


def fix_rim(ob, outer_form, region, rounds=6, smooth=3, max_move=0.006):
    """Puts the open edge of a sheet exactly on the curve where the outer surface meets the
    cut (alternating projections onto both zero sets), smoothed along the edge: the remesher
    only approximates that sharp corner, and once the cap is gone its jags show."""
    from lib.sdf import project_to_surface
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    nb = {}
    for e in bm.edges:
        if len(e.link_faces) == 1:
            a, b = e.verts[0].index, e.verts[1].index
            nb.setdefault(a, []).append(b)
            nb.setdefault(b, []).append(a)
    idx = np.array(sorted(nb), int)
    if not len(idx):
        bm.free()
        return 0
    V = np.array([v.co for v in bm.verts], float)

    def settle(P):
        for _ in range(rounds):
            P = project_to_surface(outer_form, P, 0.006, iters=2)
            P = project_to_surface(region, P, 0.006, iters=2)
        return project_to_surface(outer_form, P, 0.003, iters=2)
    V0 = V[idx].copy()

    def clamp(P):
        # a vertex the projections carry off (another branch of the cut field) stays put
        d = np.linalg.norm(P - V0, axis=1)
        return np.where((d > max_move)[:, None], V0, P)
    V[idx] = clamp(settle(V[idx]))
    pos = {int(i): k for k, i in enumerate(idx)}
    for _ in range(smooth):
        P = V[idx].copy()
        for k, i in enumerate(idx):
            n = [j for j in nb[int(i)] if j in pos]
            if len(n) == 2:
                P[k] = 0.5 * V[i] + 0.25 * (V[n[0]] + V[n[1]])
        V[idx] = clamp(settle(P))
    for i in idx:
        bm.verts[int(i)].co = V[i]
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return len(idx)


def cut_levelset(ob, fn, face_sel=None, eps=2e-4, name="cut", snap=0.2):
    """Cuts the mesh along the zero set of fn (points (n, 3) -> values) inside the faces
    face_sel(C) picks: edges crossing zero are split at the linear crossing and the two
    crossing points of each face are joined, so a zone border (a lapel's edge, a cuff's
    top, a waist seam) follows the curve instead of the remeshed triangles."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    C = np.array([f.calc_center_median() for f in bm.faces], float)
    sel = np.asarray(face_sel(C), bool) if face_sel is not None else np.ones(len(C), bool)
    faces = [f for f, k in zip(bm.faces, sel) if k]
    bm.verts.ensure_lookup_table()
    V = np.array([v.co for v in bm.verts], float)
    fv = np.asarray(fn(V), float)
    val = {v: fv[v.index] for v in bm.verts}
    edges = {e for f in faces for e in f.edges}
    if snap > 0.0:
        # a crossing close to a vertex moves that vertex onto the curve instead of making a
        # sliver (only vertices whose every crossing edge agrees: the move is along one edge)
        moves = {}
        for e in edges:
            a, b = e.verts
            fa, fb = val[a], val[b]
            if fa * fb >= 0:
                continue
            t = fa / (fa - fb)
            if t < snap:
                moves.setdefault(a, []).append(a.co + (b.co - a.co) * t)
            elif t > 1.0 - snap:
                moves.setdefault(b, []).append(b.co + (a.co - b.co) * (1.0 - t))
        for v, ps in moves.items():
            if len(ps) == 1:
                v.co = ps[0]
                val[v] = 0.0
    zero = {v for v in {v for f in faces for v in f.verts} if abs(val[v]) <= eps}
    n_split = 0
    for e in list(edges):
        a, b = e.verts
        fa, fb = val[a], val[b]
        if abs(fa) <= eps or abs(fb) <= eps or fa * fb > 0:
            continue
        t = fa / (fa - fb)
        pa, pb = a.co.copy(), b.co.copy()
        _, nv = bmesh.utils.edge_split(e, a, t)
        nv.co = pa + (pb - pa) * t
        val[nv] = 0.0
        zero.add(nv)
        n_split += 1
    n_conn = 0
    cand = {f for v in zero for f in v.link_faces}
    for f in cand:
        zs = [v for v in f.verts if v in zero]
        if len(zs) != 2:
            continue
        a, b = zs
        if any(b in (e.other_vert(a),) for e in a.link_edges if e in f.edges):
            continue
        try:
            bmesh.ops.connect_verts(bm, verts=[a, b])
            n_conn += 1
        except Exception:
            pass
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    log("  %-12s %s: %d edges split, %d faces joined" % (ob.name, name, n_split, n_conn))
    return n_split


def solidify(ob, thickness, rim_only=False, even=False):
    """Adds the inner layer (a copy offset `thickness` inward: the lining) and a rim at the
    open edges, or only the rim (a lip that gives the edge its thickness). The FACE
    attribute "mil_layer" records 0 outer, 1 inner, 2 rim."""
    from lib.remesh import apply_modifiers
    me = ob.data
    while len(me.materials) < 3:
        me.materials.append(material("mil_layer_%d" % len(me.materials), "#808080", 0.8))
    for p in me.polygons:
        p.material_index = 0
    src = me.attributes.get("mil_src") or me.attributes.new("mil_src", "INT", "POINT")
    src.data.foreach_set("value", np.arange(len(me.vertices), dtype=np.int32))
    mod = ob.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = -1.0
    mod.use_rim = True
    mod.use_rim_only = rim_only
    mod.use_even_offset = even
    mod.use_quality_normals = True
    mod.material_offset = 1
    mod.material_offset_rim = 2
    apply_modifiers(ob)
    me = ob.data
    lay = np.array([p.material_index for p in me.polygons], np.int32)
    a = me.attributes.get("mil_layer") or me.attributes.new("mil_layer", "INT", "FACE")
    a.data.foreach_set("value", lay)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def shell_from_offset(mid_form, half):
    """Shell of thickness 2 * half around the mid surface (zero set) of `mid_form`."""
    return Onion(mid_form, half)


def OuterOf(mid_form, half):
    """SDF whose zero set is the shell's outer surface (trims are laid on it)."""
    return Offset(mid_form, half)


def is_inner(mid_form, P):
    """True for points on the shell's inner side (inside the mid surface)."""
    return peval(mid_form, np.atleast_2d(np.asarray(P, float))) < 0.0


def angle_front(X, Y, c=0.0):
    """Angle around the vertical axis through y = c, degrees: 0 front centre, 180 back."""
    return np.degrees(np.arctan2(np.abs(X), -(Y - c)))


def coat_torso_shapes(K):
    """The torso a coat or waistcoat hangs on: the body's torso with the anatomy bridged
    (build_body.coat_torso_shapes: fuller chest and back plates), so wool drapes over it
    instead of shrink-wrapping pectorals, shoulder blades and the spine groove."""
    from lib.sdf import Ellipsoid, Union
    sb, sd = K["spineb"], K["spined"]
    chest = Ellipsoid(v3(0, sd[1] - 0.030, sd[2] - 0.035), (0.134, 0.062, 0.125))
    back = Ellipsoid(v3(0, sd[1] + 0.028, sd[2] - 0.015), (0.142, 0.080, 0.175))
    waist = Ellipsoid(v3(0, sb[1] + 0.027, sb[2] - 0.005), (0.128, 0.090, 0.125))
    return Union([torso_shapes(K, smooth=True), Union([chest, back, waist], k=0.06)], k=0.05)


def hidden_sizing(vis, hid, occluders, margin=0.0015):
    """Target edge length: vis(P) (or a constant) where visible, `hid` inside any occluder."""
    def fn(P):
        v = vis(P) if callable(vis) else np.full(len(P), vis)
        if not occluders:
            return v
        occ = np.min([peval(o, P) for o in occluders], axis=0)
        return np.where(occ < -margin, hid, v)
    return fn


def smooth_band(x, a, b, w):
    """1 inside [a, b], smooth edges of width w."""
    return smoothstep(a - w, a + w, x) * (1 - smoothstep(b - w, b + w, x))


def segment_t(P, a, b):
    ab = b - a
    t = ((P - a) @ ab) / (ab @ ab)
    d = np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
    return t, d


def arm_t(K, P, s):
    """(t along elbow -> wrist, distance) for side s."""
    return segment_t(P, K.side("elbow", s), K.side("wrist", s))


def sleeve_mask(K, P):
    """Points closer to an arm than to the torso (the pipeline's sleeve factor > 0.5)."""
    from lib.weights import sleeve_factor
    return sleeve_factor(np.asarray(P, float), K) > 0.5


def arms_node(K, s):
    return arm_shapes(K, s)


def report_dims(name, ob):
    V = mesh_arrays(ob)
    log("  %s bbox %s .. %s" % (name, np.round(V.min(0), 3).tolist(), np.round(V.max(0), 3).tolist()))
