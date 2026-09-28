"""Shared code of the colonial militia & provincials garments (costume bible §4, set B).

Garment modules (tools/character/garments/militia/<id>.py) define SPEC and build(ctx);
tools/character/build_character.sh --garments militia runs them through
lib.pipeline.finish_part. This module is the set's own toolbox (the lib is not edited):

  * specs      spec() / MZone: catalog entries of the set (zones with fabric choices,
               palette tokens of the bible, deform limits, skirt hems, presets).
  * shapes     the legacy outfit of build_body.py (hunting frock, waistcoat, shirt,
               breeches, leggings, garters, shoes, tricorn) as parameterized SDFs, so the
               ported garments keep today's cut, plus the new variants' pieces.
  * meshes     sdf_part() (polygonize + remesh with visible sizing everywhere: in the
               customizer any layer can be seen) and strip_interior(): garments are
               solids offset from the body, so the walls of their openings (front, neck,
               sleeve ends, hems) run into the body; faces deeper than INTERIOR_DEPTH
               inside the skin are deleted (they can never be seen: the skin, or a layer
               that fully covers the region, is always drawn over them).
  * UVs        grain-aligned cylindrical UVs in metres with u = angle x the vertex's own
               radius (metric around a flared skirt too), seams where real garments have
               them (centre back, underarm, inseam); planar parts for soles and brims.
  * weights    lib.pipeline.garment_body_weights (nearest body point, torso-from-torso
               above the waist; every layer gets the same field, so layers keep their
               order under skinning), coat skirts blended to the skirt panel helpers
               (lib.weights.skirt_weights, as the legacy coat), rigid buttons / buckles /
               garters / hats.
  * coverage   hides_regions are VERIFIED, not assumed: a body region may be hidden by a
               garment only if a cone of rays (normal + 4 rays tilted CONE_DEG) from every
               sample of the region hits the garment, on the female base and on the male
               fit (`sex` = 1). occupies_regions = regions whose skin the garment covers
               for at least OCCUPY_SHARE (normal rays).
  * fit        clearance of the garment over the skin at bind for both fits.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

from lib import regions as RG
from lib.body_shapes import arm_shapes, body_groups, body_node, foot_shapes, neck_shape, torso_shapes
from lib.catalog import GarmentSpec, Zone
from lib.materials import METALS, token_hex
from lib.pipeline import Surface, garment_body_weights
from lib.remesh import material, mesh_arrays, sdf_object, tri_count
from lib.sdf import (Ellipsoid, Fn, Inter, Offset, Onion, RoundBox, Sphere, Sub, SymUnion, Union, frame_from, log,
                     mirror_x, nrm, peval, smoothstep, v3, zslab)
from lib.weights import mesh_adjacency, rigid_islands, skirt_weights, smooth_weights
from lib.wrap import Surface as WrapSurface
from lib.wrap import vertex_normals

SET = "militia"
INTERIOR_DEPTH = 0.006        # m: garment faces entirely deeper than this inside the skin are deleted
CONE_DEG = 28.0               # hides_regions: rays tilted this much must hit the garment too
OCCUPY_SHARE = 0.30           # occupies_regions: share of the region's skin under the garment
HIDE_CONE_SHARE = 0.995       # hides_regions: every normal ray and 99.5 % of the cone rays hit
LICENCE_FEMALE = None         # (no gender locks: every item fits both bodies, bible §5.1)

FABRIC_NOTE = ("Fabric: approved Poly Haven CC0 kit (assets/polyhaven/textures/clothing), luminance detail tinted "
               "to the palette colour at runtime; UVs in metres along the grain.")

# Deform limits per garment surface (check_body_deform.gd reads them from the catalog
# fragment: [collapse share, flip share, stretch share, max edge ratio]). Set 25 % above the
# scan of the built asset on both fits (the method of the legacy limits), rounded up.
RIGID_LIMIT = [0.005, 0.005, 0.0, 1.3]
DEFORM_LIMITS = {
    # 44 clips x 8 samples, female and male fit, 2026-09-24 (worst of the two) x 1.25,
    # rounded up (build of 13:55; check_body_deform.gd parts=body + a hair style + the set).
    # For comparison, the legacy outfit's limits: coat [0.072, 0.125, 0.23, 27], breeches
    # [0.08, 0.092, 0.10, 15], leggings [0.022, 0.031, 0.006, 2.8], shoe [0.0063, 0.0045,
    # 0.005, 2.2]. The shirt and waistcoats are now visible everywhere (the legacy ones
    # were cut away under the coat), so they show the skin's own faults: the armpit in the
    # ledge hang, the lower back in crouches (skin torso_lower: 17 % stretch).
    "hunting_frock": [0.089, 0.139, 0.239, 27.0],
    "frock_coat": [0.063, 0.103, 0.234, 24.1],
    "provincial_coat_ma": [0.057, 0.101, 0.230, 27.9],
    "breeches_fall": [0.106, 0.071, 0.094, 13.2],
    "leggings_wool": [0.037, 0.039, 0.007, 2.85],
    "stockings": [0.022, 0.026, 0.011, 3.2],
    "shirt_linen": [0.027, 0.039, 0.054, 25.1],
    "waistcoat_sb": [0.039, 0.047, 0.086, 4.45],
    "waistcoat_db": [0.037, 0.030, 0.082, 4.0],
    "shoes_buckled": [0.006, 0.006, 0.005, 2.6],
    "stock_linen": [0.005, 0.005, 0.033, 3.6],
    "neckerchief": [0.005, 0.005, 0.005, 2.1],
    "tricorn": RIGID_LIMIT, "round_hat_cut": RIGID_LIMIT, "monmouth_cap": RIGID_LIMIT,
}


# ---------------------------------------------------------------------------
# catalog specs
# ---------------------------------------------------------------------------
class MZone(Zone):
    """Zone with the fabric codes the UI may swap between (`fabrics`, first = default)
    and optional pattern options (procedural in the cloth shader)."""

    def __init__(self, zone, role, fabric="FLAT", palette=None, default=None, pattern=None, bands=None, name=None,
                 fabrics=None):
        super().__init__(zone, role, fabric, palette, default, pattern, bands, name)
        self.fabrics = list(fabrics or [fabric])

    def to_dict(self):
        d = super().to_dict()
        d["fabrics"] = self.fabrics
        d["metal"] = self.fabric == "MET"
        return d


def spec(id, name, slot, layer, zones, description, history, evidence="A", sources=(), budget=1500, tags=(),
         extra=None, **kw):
    ex = {"fabric_note": FABRIC_NOTE, "deform_limits": {}}
    ex.update(extra or {})
    return GarmentSpec(id=id, name=name, slot=slot, set=SET, layer=layer, zones=zones, description=description,
                       history=history, evidence=evidence, sources=list(sources), budget={"tris_max": budget},
                       tags=["militia"] + list(tags), extra=ex, surfaces={"main": id}, **kw)


def zone_mats(spec_):
    """Preview material per zone (index = zone id): the zone's default colour."""
    out = []
    zs = sorted(spec_.zones, key=lambda z: z.zone)
    for z in zs:
        tok = z.default or "#888888"
        metal = tok in METALS or z.fabric == "MET"
        out.append(material("%s_z%d" % (spec_.id, z.zone), token_hex(tok), 0.35 if metal else 0.85, 0.9 if metal else 0.0))
    return out


# ---------------------------------------------------------------------------
# body
# ---------------------------------------------------------------------------
_NODES = {}


def body_f(ctx):
    if "f" not in _NODES:
        _NODES["f"] = ctx.body_sdf(ctx.P_female)
    return _NODES["f"]


def body_m(ctx):
    if "m" not in _NODES:
        _NODES["m"] = ctx.body_sdf(ctx.P_male)
    return _NODES["m"]


def groups_f(ctx):
    if "gf" not in _NODES:
        _NODES["gf"] = body_groups(ctx.K, ctx.P_female)
    return _NODES["gf"]


# ---------------------------------------------------------------------------
# meshes
# ---------------------------------------------------------------------------
def sdf_part(ctx, name, node, h, tris, mat, visible, hidden=0.040, symmetric=True, hidden_below=-0.003, **kw):
    """sdf_object with a sizing field: `visible` (float or fn(P)) everywhere outside the
    skin, `hidden` closer to the skin than `hidden_below` (inside the body, or below the
    layer's band: those faces are stripped)."""
    body = body_f(ctx)

    def sizing(P):
        vis = visible(P) if callable(visible) else np.full(len(P), float(visible))
        return np.where(peval(body, P) < hidden_below, hidden, vis)
    return sdf_object(name, node, h, tris, mat, sizing=sizing, symmetric=symmetric, **kw)


def strip_interior(ob, node, depth=INTERIOR_DEPTH):
    """Deletes faces whose vertices all lie deeper than `depth` inside `node` (the body)."""
    V = mesh_arrays(ob)
    inside = peval(node, V) < -depth
    return _delete_faces(ob, lambda f: all(inside[v.index] for v in f.verts))


def _delete_faces(ob, pred):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    dead = [f for f in bm.faces if pred(f)]
    bmesh.ops.delete(bm, geom=dead, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return len(dead)


def vertex_groups_of(ctx, P):
    """Region group (lib.regions.region_group) of the nearest body triangle of each point."""
    body = ctx.body()
    if "wrap" not in _NODES:
        _NODES["wrap"] = WrapSurface(body.V, body.F)
    tri, _, _, _ = _NODES["wrap"].nearest(P)
    names = [RG.REGION_NAMES[int(r)] for r in body.freg[tri]]
    return np.array([RG.region_group(n) for n in names], dtype=object)


def strip_to_envelope(ctx, ob, layer, extra_level=None, wall_dot=0.55):
    """Trims the solid's walls to the garment's layer band: deletes faces deeper than
    INTERIOR_DEPTH inside the skin, and wall faces (normal across the skin normal,
    |cos| < wall_dot) with a vertex below the level of their region group: the layer's
    inner clearance minus 1.4 mm, but at least 0.5 mm above the outer bound of the layers
    below it there (INTERIOR_DEPTH inside the skin where no band is defined).
    Faces of the garment's own surface that dip below the band are kept (the pipeline's
    envelope check reports them). extra_level: {group: level} overrides (m)."""
    from lib.layers import ENVELOPES, clearance
    V = mesh_arrays(ob)
    body = body_f(ctx)
    d = peval(body, V)
    grp = vertex_groups_of(ctx, V)
    level = np.full(len(V), -INTERIOR_DEPTH)
    order = ["base", "mid", "legwear", "outer", "wrap"]
    for g in set(grp):
        lo = clearance(g, layer, 0)
        lv = (lo - 0.0014) if lo is not None else -INTERIOR_DEPTH
        # walls end just above the band of the layer below (the shirt under a waistcoat,
        # the waistcoat under a coat), so a cut edge never intersects the layer under it
        below_layers = order[:order.index(layer)] if layer in order else []
        outs = [ENVELOPES.get(g, {}).get(b, (None, None))[1] for b in below_layers]
        outs = [o for o in outs if o is not None]
        if outs:
            lv = max(lv, max(outs) + 0.0005)
        if extra_level and g in extra_level:
            lv = extra_level[g]
        level[grp == g] = lv
    below = d < level
    # skin normal at each vertex (SDF gradient)
    h = 5e-4
    G = np.zeros_like(V)
    for k in range(3):
        e = np.zeros(3)
        e[k] = h
        G[:, k] = peval(body, V + e) - peval(body, V - e)
    G /= np.maximum(np.linalg.norm(G, axis=1, keepdims=True), 1e-12)

    deep = d < -INTERIOR_DEPTH

    def pred(f):
        idx = [v.index for v in f.verts]
        if all(deep[i] for i in idx):
            return True
        if any(below[i] for i in idx):
            # a wall (the cut through the solid: opening, hem, neck hole, sleeve end) runs
            # across the skin normal; the garment's own surface lying close to the skin is
            # kept (the pipeline's envelope check reports it)
            n = np.array(f.normal)
            gn = G[idx].mean(0)
            gn /= max(np.linalg.norm(gn), 1e-12)
            return abs(float(n @ gn)) < wall_dot
        return False
    n = _delete_faces(ob, pred)
    return n


def drop_small_islands(ob, min_faces=12, keep_mask=None):
    """Removes connected pieces with fewer than min_faces faces (slivers left by the
    interior strip)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    seen = set()
    dead = []
    for f in bm.faces:
        if f.index in seen:
            continue
        comp, stack = [], [f]
        seen.add(f.index)
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        if len(comp) < min_faces:
            dead += comp
    if dead:
        bmesh.ops.delete(bm, geom=dead, context="FACES_ONLY")
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return len(dead)


def set_zone(ob, zone_of_poly):
    """Material index per polygon = zone (the object's material list must be the zone list)."""
    for p, z in zip(ob.data.polygons, zone_of_poly):
        p.material_index = int(z)


def zones_of(ob):
    """Zone per polygon from the material names (<id>_z<k>)."""
    names = [m.name for m in ob.data.materials]
    zk = [int(n.rsplit("_z", 1)[1]) if "_z" in n else 0 for n in names]
    return np.array([zk[p.material_index] for p in ob.data.polygons], int)


def poly_centers(ob):
    return np.array([p.center for p in ob.data.polygons], float)


def poly_normals(ob):
    return np.array([p.normal for p in ob.data.polygons], float)


def triangles(ob):
    me = ob.data
    me.calc_loop_triangles()
    return np.array([t.vertices[:] for t in me.loop_triangles], int)


def with_mats(ob, mats):
    """Replaces the object's material slots by `mats` (zone list), keeping indices."""
    me = ob.data
    idx = [p.material_index for p in me.polygons]
    while len(me.materials):
        me.materials.pop()
    for m in mats:
        me.materials.append(m)
    for p, i in zip(me.polygons, idx):
        p.material_index = i


def join_parts(objs, name):
    from lib.remesh import join
    return join(objs, name)


def vert_zone(ob, zones):
    """Per-vertex zone (the largest zone id of the polygons around it: metal and trims win)."""
    vz = np.zeros(len(ob.data.vertices), int)
    for p, z in zip(ob.data.polygons, zones):
        for v in p.vertices:
            vz[v] = max(vz[v], int(z))
    return vz


def vert_mask_of_zone(ob, zones, zone_ids):
    m = np.zeros(len(ob.data.vertices), bool)
    for p, z in zip(ob.data.polygons, zones):
        if int(z) in zone_ids:
            m[list(p.vertices)] = True
    return m


# ---------------------------------------------------------------------------
# UVs (metres, grain-aligned)
# ---------------------------------------------------------------------------
class Cyl:
    """u = angle x the vertex's distance from the axis a -> b (metric around a flare),
    v = v0 + distance along the axis. The seam (angle +-pi) is opposite `ref`."""

    def __init__(self, a, b, ref, v0=0.0, rmin=0.01):
        self.a = np.asarray(a, float)
        self.d = nrm(np.asarray(b, float) - self.a)
        r = np.asarray(ref, float)
        r = r - self.d * (r @ self.d)
        self.x = nrm(r)
        self.y = np.cross(self.d, self.x)
        self.v0, self.rmin = float(v0), float(rmin)

    def map(self, P):
        q = P - self.a
        along = q @ self.d
        perp = q - along[:, None] * self.d[None, :]
        r = np.maximum(np.linalg.norm(perp, axis=1), self.rmin)
        ang = np.arctan2(perp @ self.y, perp @ self.x)
        return ang, r, self.v0 + along


class Flat:
    def __init__(self, o, ex, ey):
        self.o = np.asarray(o, float)
        self.ex = nrm(ex)
        ey = np.asarray(ey, float)
        self.ey = nrm(ey - self.ex * (ey @ self.ex))

    def map(self, P):
        q = P - self.o
        return q @ self.ex, q @ self.ey


def loop_topology(ob):
    me = ob.data
    nl = len(me.loops)
    lv = np.empty(nl, int)
    me.loops.foreach_get("vertex_index", lv)
    lp = np.empty(nl, int)
    for p in me.polygons:
        lp[p.loop_start:p.loop_start + p.loop_total] = p.index
    return lv, lp


def loop_uvs(ob, maps, part_of_poly):
    """Per-loop (u, v) in metres: polygon p is mapped by maps[part_of_poly[p]]."""
    V = mesh_arrays(ob)
    lv, lp = loop_topology(ob)
    part = np.asarray(part_of_poly, int)[lp]
    uv = np.zeros((len(lv), 2))
    npoly = len(ob.data.polygons)
    for k, m in enumerate(maps):
        sel = np.nonzero(part == k)[0]
        if not len(sel):
            continue
        P = V[lv[sel]]
        if isinstance(m, Flat):
            u, v = m.map(P)
        else:
            ang, r, v = m.map(P)
            polys = lp[sel]
            amin = np.full(npoly, np.inf)
            amax = np.full(npoly, -np.inf)
            np.minimum.at(amin, polys, ang)
            np.maximum.at(amax, polys, ang)
            wrap = (amax[polys] - amin[polys]) > math.pi
            ang = np.where(wrap & (ang < 0), ang + 2 * math.pi, ang)
            u = ang * r
        uv[sel, 0] = u
        uv[sel, 1] = v
    return uv


def torso_axis(ctx):
    yc = ctx.K["spineb"][1]
    return Cyl((0, yc, 0.0), (0, yc, 1.0), (0, -1, 0))


def arm_axis(ctx, s):
    K = ctx.K
    S, W = K.side("shoulder", s), K.side("wrist", s)
    return Cyl(S, W, v3(s, 0, 0.6), v0=0.0)


def leg_axis(ctx, s, seam_outside=False):
    K = ctx.K
    H, A = K.side("upper_leg", s), K.side("ankle", s)
    return Cyl(H, A, v3(-s if seam_outside else s, 0, 0))


def garment_uvs(ctx, ob, kind="torso", extra_maps=(), extra_part=None):
    """Standard maps: 'torso' (torso cylinder + two sleeves by the sleeve factor),
    'legs' (one cylinder per leg; the seam at the inseam), 'legs_out' (seam outside)."""
    from lib.weights import sleeve_factor
    C = poly_centers(ob)
    if kind == "torso":
        maps = [torso_axis(ctx), arm_axis(ctx, 1), arm_axis(ctx, -1)]
        sl = sleeve_factor(C, ctx.K) > 0.5
        part = np.where(sl, np.where(C[:, 0] > 0, 1, 2), 0)
    elif kind in ("legs", "legs_out"):
        out = kind == "legs_out"
        maps = [leg_axis(ctx, 1, out), leg_axis(ctx, -1, out)]
        part = np.where(C[:, 0] > 0, 0, 1)
    else:
        raise ValueError(kind)
    maps = list(maps) + list(extra_maps)
    if extra_part is not None:
        ep = np.asarray(extra_part)
        part = np.where(ep >= 0, len(maps) - len(extra_maps) + ep, part)
    return loop_uvs(ob, maps, part)


# ---------------------------------------------------------------------------
# weights
# ---------------------------------------------------------------------------
def body_weights(ctx, ob, smooth=1, alpha=0.3):
    """Nearest body point (torso-from-torso above the waist, helpers included), smoothed."""
    W = garment_body_weights(ctx, ob)
    if smooth:
        W = smooth_weights(W, mesh_adjacency(ob), smooth, alpha)
    return W


def blend_skirt(ctx, ob, W, mask, hem, vent_top, z0=0.93, z1=0.87):
    """Coat skirt (as the legacy coat): pelvis at the waist, the skirt panel helpers below."""
    V = mesh_arrays(ob)
    t = smoothstep(z0, z1, V[:, 2]) * mask
    Ws = skirt_weights(V, ctx.bones, hem=hem, vent_top=vent_top)
    return W * (1 - t[:, None]) + Ws * t[:, None]


def rigid_pieces(ob, W, mask):
    """Every connected piece of the masked vertices moves rigidly (mean weights)."""
    return rigid_islands(W, mesh_adjacency(ob), mask)


def rigid_bone(ctx, W, mask, bone):
    W = W.copy()
    W[mask] = 0.0
    W[mask, ctx.bones.index(bone)] = 1.0
    return W


def one_weight_per_piece(ob, W, mask, source_mask=None):
    """Like rigid_pieces, but the piece takes the mean weights of the nearest
    `source_mask` vertices (e.g. a button takes the cloth under it)."""
    if source_mask is None:
        return rigid_pieces(ob, W, mask)
    V = mesh_arrays(ob)
    E = mesh_adjacency(ob)
    idx = np.nonzero(mask)[0]
    adj = {int(i): [] for i in idx}
    for a, b in E[mask[E[:, 0]] & mask[E[:, 1]]]:
        adj[int(a)].append(int(b))
        adj[int(b)].append(int(a))
    src = np.nonzero(source_mask & ~mask)[0]
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
        c = V[comp].mean(0)
        d = np.linalg.norm(V[src] - c, axis=1)
        near = src[np.argsort(d)[:6]]
        w = W[near].mean(0)
        W[comp] = w / max(w.sum(), 1e-12)
    return W


# ---------------------------------------------------------------------------
# sex shape (the same wrap transfer as lib.pipeline, for the checks here)
# ---------------------------------------------------------------------------
def sex_delta(ctx, ob):
    body = ctx.body()
    V = mesh_arrays(ob)
    surf = WrapSurface(body.V, body.F, shapes=body.shapes)
    b = surf.bind(V)
    return surf.shape_delta(b, "sex", smooth_E=mesh_adjacency(ob), smooth_iters=3)


# ---------------------------------------------------------------------------
# coverage (hides_regions / occupies_regions) and fit
# ---------------------------------------------------------------------------
def _tangents(N):
    a = np.where(np.abs(N[:, 0:1]) < 0.9, np.array([[1.0, 0, 0]]), np.array([[0, 1.0, 0]]))
    t1 = a - N * (a * N).sum(1, keepdims=True)
    t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-12)
    t2 = np.cross(N, t1)
    return t1, t2


def coverage(ctx, ob, D, regions=None, max_dist=0.6, cone_deg=CONE_DEG, candidates=()):
    """{region: {"normal": share, "cone": share}} over both fits (the minimum). Samples:
    the region's body vertices and triangle centroids. Rays pass through the body where it
    may be hidden (the candidate regions: a ray from an inner thigh crosses the other thigh
    and must still meet the breeches beyond it) and stop at the skin of every other region,
    which stays drawn and blocks the view: only rays that leave through an opening count as
    uncovered."""
    body = ctx.body()
    F = triangles(ob)
    Vg0 = mesh_arrays(ob)
    regions = list(RG.REGION_LIST) if regions is None else list(regions)
    res = {r: {"normal": 1.0, "normal_b": 1.0, "cone": 1.0} for r in regions}
    ca, sa = math.cos(math.radians(cone_deg)), math.sin(math.radians(cone_deg))
    cand = set(RG.REGIONS[r] for r in candidates)
    blockers = body.F[~np.isin(body.freg, list(cand))]
    for Vb, Vg in ((body.V, Vg0), (body.V + body.shapes["sex"], Vg0 + D)):
        # garment only (occupancy), garment + the skin that stays drawn (hiding)
        bvh_g = BVHTree.FromPolygons([tuple(p) for p in Vg], [tuple(t) for t in F], all_triangles=True)
        allV = np.concatenate([Vg, Vb])
        allF = np.concatenate([F, blockers + len(Vg)])
        bvh = BVHTree.FromPolygons([tuple(p) for p in allV], [tuple(t) for t in allF], all_triangles=True)
        Nb = vertex_normals(Vb, body.F)
        for r in regions:
            rid = RG.REGIONS[r]
            tri = np.nonzero(body.freg == rid)[0]
            if not len(tri):
                continue
            vid = np.unique(body.F[tri])
            P = np.concatenate([Vb[vid], Vb[body.F[tri]].mean(1)])
            N = np.concatenate([Nb[vid], Nb[body.F[tri]].mean(1)])
            N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
            t1, t2 = _tangents(N)
            g_hit = 0
            n_hit = 0
            c_hit = 0
            fails = []
            test = rid in cand
            for i in range(len(P)):
                o = Vector(P[i] + N[i] * 0.0005)
                if bvh_g.ray_cast(o, Vector(N[i]), max_dist)[0] is not None:
                    g_hit += 1
                if not test:
                    continue
                if bvh.ray_cast(o, Vector(N[i]), max_dist)[0] is None:
                    fails.append(P[i])
                    continue
                n_hit += 1
                ok = True
                for t in (t1[i], -t1[i], t2[i], -t2[i]):
                    d = N[i] * ca + t * sa
                    if bvh.ray_cast(o, Vector(d), max_dist)[0] is None:
                        ok = False
                        break
                c_hit += ok
                if not ok:
                    fails.append(P[i])
            if fails and "fails" not in res[r]:
                res[r]["fails"] = [[round(float(c), 3) for c in f] for f in fails[:8]]
            res[r]["normal"] = min(res[r]["normal"], g_hit / len(P))
            if test:
                res[r]["normal_b"] = min(res[r]["normal_b"], n_hit / len(P))
                res[r]["cone"] = min(res[r]["cone"], c_hit / len(P))
            else:
                res[r]["normal_b"] = res[r]["cone"] = 0.0
    return res


def fit_report(ctx, ob, D):
    """Clearance of the garment over the rendered skin at bind, female base and male fit:
    signed distance of each garment vertex to the body MESH (nearest triangle, along its
    interpolated normal), for the vertices that lie outside the skin on the female base
    (the stripped walls end inside it)."""
    body = ctx.body()
    V = mesh_arrays(ob)
    rep = {}
    outside = None
    for name, Vb, P in (("female", body.V, V), ("male", body.V + body.shapes["sex"], V + D)):
        surf = WrapSurface(Vb, body.F)
        tri, bary, Q, _ = surf.nearest(P)
        n = surf.interpolate(surf.N, tri, bary)
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
        d = ((P - Q) * n).sum(1)
        if outside is None:
            outside = d > 0.001
        dd = d[outside]
        rep[name] = {"min_mm": round(float(dd.min()) * 1000, 2) if len(dd) else None,
                     "p05_mm": round(float(np.percentile(dd, 5)) * 1000, 2) if len(dd) else None,
                     "inside_skin": int((dd < 0.0).sum())}
    return rep


def settle_regions(ctx, spec_, ob, D, hide_candidates, log_all=False):
    """Sets spec_.hides_regions (the candidates that pass the cone test on both fits) and
    spec_.occupies_regions; stores the numbers in the catalog entry ("coverage")."""
    cov = coverage(ctx, ob, D, candidates=hide_candidates)
    hides = [r for r in hide_candidates if cov[r]["normal_b"] >= 0.9995 and cov[r]["cone"] >= HIDE_CONE_SHARE]
    dropped = [(r, round(cov[r]["cone"], 3)) for r in hide_candidates if r not in hides]
    occ = [r for r in RG.REGION_LIST if cov[r]["normal"] >= OCCUPY_SHARE]
    full = []
    spec_.hides_regions = hides
    spec_.occupies_regions = occ
    spec_.extra["coverage"] = {"method": ("rays from the skin (the region's vertices and triangle centres), female "
                                          "and male fit: hidden when every normal ray and %.1f %% of the rays tilted "
                                          "%.0f deg hit the garment" % (HIDE_CONE_SHARE * 100, CONE_DEG)),
                               "hidden": hides, "not_hidden_candidates": dict(dropped),
                               "share": {r: {"normal": round(cov[r]["normal"], 3), "cone": round(cov[r]["cone"], 3)}
                                         for r in RG.REGION_LIST if cov[r]["normal"] > 0.0}}
    log("  %s hides %s" % (spec_.id, hides))
    if dropped:
        log("  %s NOT hidden (cone share): %s" % (spec_.id, dropped))
        for r, _ in dropped:
            log("     %s fails at %s" % (r, cov[r].get("fails")))
    if full and log_all:
        log("  %s also fully covers (not declared): %s" % (spec_.id, full))
    return cov


def finish(ctx, spec_, ob, zones, W, uv, hide_candidates=(), edge=None, colors=None, regions=None):
    """Checks (coverage, fit) and the pipeline surface."""
    D = sex_delta(ctx, ob)
    settle_regions(ctx, spec_, ob, D, hide_candidates)
    fit = fit_report(ctx, ob, D)
    spec_.extra["fit_check"] = fit
    spec_.extra["deform_limits"] = {spec_.id: DEFORM_LIMITS.get(spec_.id, [0.01, 0.01, 0.01, 4.0])}
    log("  %s fit at bind: %s" % (spec_.id, fit))
    return {"main": Surface(ob, zones=np.asarray(zones, int), weights=W, uv=uv, edge=edge, colors=colors,
                            regions=regions)}


# ---------------------------------------------------------------------------
# colours (COLOR_0.rgb = baked shading multiplier)
# ---------------------------------------------------------------------------
def rgba(c):
    out = np.ones((len(c), 4))
    out[:, :3] = np.asarray(c)[:, None]
    return out


def edge_sources(ob, select):
    """Vertices (indices) selected by select(P) -> bool."""
    return np.nonzero(select(mesh_arrays(ob)))[0]


def geodesic(ob, sources, max_d=1.0):
    from lib.bands import edge_distance
    if len(sources) == 0:
        return np.full(len(ob.data.vertices), max_d)
    return edge_distance(ob, sources, max_d)


# ===========================================================================
# Legacy outfit shapes (tools/character/build_body.py), parameterized
# ===========================================================================
class Skirt:
    """Coat skirt: cross-section by height (an ellipse in front flattening to a
    superellipse across the back), side pleats, a sloped hem (front higher), a back vent."""

    def __init__(self, Z, A, B, C, back_n=3.2, pleats=(96.0, 134.0, 3, 0.0042), hem=0.525, top=0.975,
                 front_rise=0.06, vent_top=0.80, shell=0.0045):
        self.Z, self.A, self.B, self.C = Z, A, B, C
        self.back_n, self.pleats, self.hem, self.top = back_n, pleats, hem, top
        self.front_rise, self.vent_top, self.shell = front_rise, vent_top, shell

    def pleat(self, X, Y, Z):
        a0, a1, count, depth = self.pleats
        c = np.interp(Z, self.Z, self.C)
        ang = np.degrees(np.arctan2(np.abs(X), -(Y - c)))
        w = smoothstep(a0 - 8.0, a0 + 2.0, ang) * (1 - smoothstep(a1 - 2.0, a1 + 8.0, ang)) * smoothstep(0.83, 0.70, Z)
        return depth * w * np.cos((ang - a0) / (a1 - a0) * count * 2.0 * np.pi)

    def form(self):
        def f(X, Y, Z):
            a = np.interp(Z, self.Z, self.A)
            b = np.interp(Z, self.Z, self.B)
            c = np.interp(Z, self.Z, self.C)
            n = 2.0 + (self.back_n - 2.0) * smoothstep(0.86, 0.62, Z) * (Y > c)
            r = (np.abs(X / a) ** n + np.abs((Y - c) / b) ** n) ** (1.0 / n)
            return (r - 1.0) * np.minimum(a, b) - self.pleat(X, Y, Z)
        amax, bmax = max(self.A) + 0.03, max(self.B) + 0.03
        return Fn(f, (-amax, -bmax, self.hem - 0.05), (amax, bmax, self.top + 0.05))

    def hem_z(self, X, Y):
        ang = np.degrees(np.arctan2(np.abs(X), -Y))
        return self.hem + self.front_rise * (1 - smoothstep(50.0, 130.0, ang))

    def slab(self, top=0.90):
        def f(X, Y, Z):
            return np.maximum(self.hem_z(X, Y) - Z, Z - top)
        return Fn(f, (-2, -2, self.hem), (2, 2, top))

    def back_split(self, width=0.004):
        hem, vt = self.hem, self.vent_top

        def f(X, Y, Z):
            w = width + 0.002 * smoothstep(hem + 0.10, hem, Z)
            return np.maximum(np.maximum(np.abs(X) - w, 0.02 - Y), Z - vt)
        return Fn(f, (-0.1, 0.02, 0.3), (0.1, 0.4, vt))

    def shell_node(self):
        return Inter(Onion(self.form(), self.shell), self.slab())

    def hems_godot(self):
        """Hem points of the front / side / back panels of the left leg (Godot skeleton
        space), as CharacterBodyMesh.SKIRT_HEMS."""
        out = []
        for ang in (25.0, 90.0, 155.0):
            a = math.radians(ang)
            z = float(self.hem_z(np.array([math.sin(a)]), np.array([-math.cos(a)]))[0])
            A = float(np.interp(z, self.Z, self.A))
            B = float(np.interp(z, self.Z, self.B))
            C = float(np.interp(z, self.Z, self.C))
            x, y = A * math.sin(a), C - B * math.cos(a)
            out.append([round(x, 3), round(z, 3), round(-y, 3)])
        return out


# the legacy hunting frock (mid-thigh)
LEGACY_SKIRT = Skirt(Z=[0.51, 0.60, 0.75, 0.85, 0.93, 0.99], A=[0.246, 0.236, 0.212, 0.190, 0.162, 0.150],
                     B=[0.182, 0.174, 0.155, 0.142, 0.118, 0.110], C=[0.008, 0.009, 0.010, 0.012, 0.006, 0.004])
LEGACY_OPEN = ([0.40, 0.47, 0.62, 0.80, 0.90, 0.95, 1.05, 1.18, 1.26, 1.34, 1.50],
               [0.135, 0.125, 0.10, 0.065, 0.040, 0.028, 0.030, 0.042, 0.050, 0.060, 0.07])


def front_opening(profile, y0=-0.02):
    Zs, Ws = profile

    def f(X, Y, Z):
        w = np.interp(Z, Zs, Ws)
        return np.maximum(np.abs(X) - w, Y - y0)
    return Fn(f, (-0.35, -0.4, 0.3), (0.35, y0, 1.6))


def neck_hole(K, r):
    from lib.sdf import RoundCone
    nk, ha = K["neck"], K["heada"]
    return RoundCone(v3(0, nk[1] + 0.012, nk[2] - 0.07), v3(0, ha[1] + 0.012, ha[2] + 0.12), 0.049 + r, 0.049 + r)


def coat_torso_shapes(K):
    """The torso a coat is cut around: the anatomy bridged by a fuller chest plate, back
    plate and waist (the wool hangs over the pectorals and shoulder blades)."""
    sb, sd = K["spineb"], K["spined"]
    chest = Ellipsoid(v3(0, sd[1] - 0.030, sd[2] - 0.035), (0.134, 0.062, 0.125))
    back = Ellipsoid(v3(0, sd[1] + 0.028, sd[2] - 0.015), (0.142, 0.080, 0.175))
    waist = Ellipsoid(v3(0, sb[1] + 0.027, sb[2] - 0.005), (0.128, 0.090, 0.125))
    return Union([torso_shapes(K, smooth=True), Union([chest, back, waist], k=0.06)], k=0.05)


def coat_torso_form(K, off, skirt, z0=0.88):
    torso = Inter(Offset(coat_torso_shapes(K), off), zslab(z0, 1.40))
    filler = Inter(Offset(skirt.form(), 0.0033), zslab(z0, skirt.top))
    return Union([torso, filler], k=0.012)


def deltoid(K, s):
    S = K.side("shoulder", s)
    return Sphere(S + v3(s * 0.007, 0.002, 0.004), 0.042)


def arm_box(K, s):
    pts = np.array([K.side(n, s) for n in ("shoulder", "elbow", "wrist", "palm")])
    return pts.min(0) - 0.08, pts.max(0) + 0.08


def cape_base(K, off=0.023):
    return Offset(SymUnion(coat_torso_shapes(K), deltoid(K, 1), deltoid(K, -1), k=0.04), off)


def forearm_t(K, s):
    E, W = K.side("elbow", s), K.side("wrist", s)
    L = float(np.linalg.norm(W - E))
    fa = (W - E) / L

    def t(X, Y, Z):
        return ((X - E[0]) * fa[0] + (Y - E[1]) * fa[1] + (Z - E[2]) * fa[2]) / L
    return t, E, fa, L


def sleeves(K, off, end, cuff=None):
    """Coat sleeves (arm offset `off`, cut at `end` of elbow -> wrist) with an optional
    turned-back cuff (t0, extra offset): returns ([sleeve nodes], [cuff nodes])."""
    from lib.sdf import cut_plane
    out, cuffs = [], []
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        arm = arm_shapes(K, s)
        sl = Inter(Offset(arm, off), cut_plane(E + fa * end * L, -fa))
        if cuff is not None:
            t0, extra = cuff
            c = Inter(Offset(arm, off + extra),
                      Fn(lambda X, Y, Z, t=t, t0=t0: np.maximum(t0 - t(X, Y, Z), t(X, Y, Z) - end - 0.012) * L,
                         *arm_box(K, s)))
            cuffs.append(c)
            sl = Union([sl, c], k=0.004)
        out.append(sl)
    return out, cuffs


def neck_clip(K, r0, r1=None, k=0.006):
    """Solid round the neck axis (the neck shape's cone) of radius r0 (bottom) .. r1 (top):
    keeps neckwear on the neck instead of spreading over the shoulders."""
    from lib.sdf import RoundCone
    nk, ha = K["neck"], K["heada"]
    a = v3(0, nk[1] + 0.010, nk[2] - 0.075)
    b = v3(0, ha[1] + 0.008, ha[2] + 0.040)
    return RoundCone(a, b, r0, r1 if r1 is not None else r0)


def neck_column(K, radius_at):
    """Solid within radius_at(z) of the neck axis (the neck shape's cone axis): neckwear is
    clipped to it, so a stock or kerchief wraps the neck where it emerges from the
    shoulders (on this body the trapezius reaches 1.35 m beside the neck) instead of
    spreading over them."""
    nk, ha = K["neck"], K["heada"]
    a = v3(0, nk[1] + 0.010, nk[2] - 0.035)
    b = v3(0, ha[1] + 0.008, ha[2] + 0.040)
    d = nrm(b - a)

    def f(X, Y, Z):
        X, Y, Z = np.broadcast_arrays(X, Y, Z)
        qx, qy, qz = X - a[0], Y - a[1], Z - a[2]
        t = qx * d[0] + qy * d[1] + qz * d[2]
        rx, ry, rz = qx - t * d[0], qy - t * d[1], qz - t * d[2]
        return np.sqrt(rx * rx + ry * ry + rz * rz) - radius_at(Z)
    return Fn(f, (-0.2, -0.25, 1.15), (0.2, 0.25, 1.55))


def fit_budget(ob, tris_max):
    """QEM-decimates a remeshed part that came out above its triangle budget (the
    isotropic remesh does not always converge to its sizing)."""
    from lib.remesh import decimate
    n = tri_count(ob)
    if n > tris_max:
        decimate(ob, int(tris_max), None, 0, symmetric=False)
        log("  %-14s decimated %d -> %d tris (budget)" % (ob.name, n, tri_count(ob)))


def wrist_cut(K, end):
    """Keeps each arm up to `end` of elbow -> wrist (both sides; the torso is kept)."""
    tl, _, _, Ll = forearm_t(K, 1)
    tr, _, _, Lr = forearm_t(K, -1)

    def f(X, Y, Z):
        return np.where(X >= 0, (tl(X, Y, Z) - end) * Ll, (tr(X, Y, Z) - end) * Lr)
    return Fn(f, (-1, -1, -1), (1, 1, 3))


def cloth_torso(K):
    """Torso + neck (the shirt's base shape)."""
    return Union([torso_shapes(K, smooth=True), neck_shape(K)], k=0.05)


def buttons_on(prims, node, points, radius=0.0055, thick=0.0028, mi=0, lift=0.0015):
    """Round buttons pressed onto the surface of `node` at the points found from
    `points` along -normal_hint (each: (start, direction))."""
    from lib.sdf import sdf_normal, surface_point
    out = []
    for p0, d in points:
        p = surface_point(node, p0, d, 0.0, 0.35)
        n = sdf_normal(node, p)
        prims.sphere(p + n * lift, (radius, radius, thick), frame_from(n, v3(1, 0, 0)), mi=mi, segs=7, rings=3)
        out.append((p, n))
    return out


def prims_part(prims, name, mats):
    return prims.to_object(name, mats)


def flat_uv_frame(center, normal):
    n = nrm(normal)
    ex = nrm(np.cross(v3(0, 0, 1), n)) if abs(n[2]) < 0.9 else v3(1, 0, 0)
    ey = np.cross(n, ex)
    return Flat(center, ex, ey)


def log_part(name, ob):
    log("  %-14s %d tris, %d verts" % (name, tri_count(ob), len(ob.data.vertices)))


def set_sharp_hat(ob, deg=60):
    from lib.remesh import set_sharp
    set_sharp(ob, deg)


def forearm_param_v(V, K, s):
    """(t along elbow -> wrist, distance to that axis) per vertex."""
    from lib.body_shapes import forearm_param
    return forearm_param(V, K, s)


def skin_copy(ctx, name, region_names, offset, cuts=(), keep_below=None, mat=None, planes=()):
    """A skin-tight layer made from the body mesh itself: the body cache's triangles of
    `region_names`, pushed out along the skin normal by offset(P) (m), then bisected by
    horizontal planes at `cuts` (z), trimmed above `keep_below` (z) and by `planes`
    ((point, normal, clear): clear removes the side the normal points to). Same topology as
    the skin under it, so the layer covers its regions exactly and (with the nearest-point
    weights, which are then the skin's own) moves exactly with it."""
    import bmesh as _bm
    from lib.remesh import mesh_object
    body = ctx.body()
    ids = [RG.REGIONS[r] for r in region_names]
    tri = np.nonzero(np.isin(body.freg, ids))[0]
    F = body.F[tri]
    used, inv = np.unique(F.ravel(), return_inverse=True)
    N = vertex_normals(body.V, body.F)[used]
    P = body.V[used]
    P = P + N * np.asarray(offset(P) if callable(offset) else offset, float).reshape(-1, 1)
    ob = mesh_object(name, P, inv.reshape(-1, 3), mat)
    bm = _bm.new()
    bm.from_mesh(ob.data)
    todo = [((0, 0, z), (0, 0, 1), False) for z in cuts]
    if keep_below is not None:
        todo.append(((0, 0, keep_below), (0, 0, 1), True))
    todo += [(tuple(co), tuple(no), bool(clear)) for co, no, clear in planes]
    for co, no, clear in todo:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        _bm.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=no, clear_inner=False,
                             clear_outer=clear)
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            _bm.ops.delete(bm, geom=loose, context="VERTS")
    _bm.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    for p in ob.data.polygons:
        p.use_smooth = True
    log("  %-14s skin copy of %d body triangles -> %d tris" % (name, len(tri), tri_count(ob)))
    return ob


def button_tris(prims_ob):
    return tri_count(prims_ob) if prims_ob is not None else 0


def rim_sizing(dists, fine, coarse, width=0.022):
    """Edge length `fine` within a few mm of a cut (dists: list of |distance| arrays to the
    cut surfaces), easing to `coarse` over `width`: cut edges stay smooth instead of
    zig-zagging along coarse triangles."""
    d = np.minimum.reduce([np.abs(x) for x in dists])
    return fine + (coarse - fine) * smoothstep(0.003, width, d)
