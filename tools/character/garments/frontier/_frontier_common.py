"""Shared code of the Frontiersman / trapper set (costume bible §2): coat bodies (torso,
sleeves, skirt, cape, collar), grain UVs in metres, coat and card weights, fur (shells and
guard-hair cards in one surface), fringe cards, shoulder-strap envelopes and the region
coverage analysis that picks `hides_regions`.

Blender armature space at null-add (z up, the character faces -y; +x is the character's
left). Garment modules import this file and tools/character/lib; nothing here edits the lib.

Surfaces written by the set (glb material names, see the catalog entries):
    <id>          opaque cloth / leather / fur base (cloth shader; zones per the entry)
    <id>_fur      fur: zone 0 = shells (h = shell / n), zone 1 = guard-hair cards (h = root 0 .. tip 1)
                  (assets/character/shaders/fur_shell.gdshader)
    <id>_fringe   fringe cards (assets/character/shaders/fringe.gdshader)
Fur surface attributes: COLOR.a = static length factor (edges, contact with the body or
the arm), CUSTOM0.x = distance to the waist-belt line, CUSTOM0.y = distance to the shoulder
strap lines (the shader flattens the pile there when `belt_flatten` / `strap_flatten` is set).
"""

import math

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import bands as BD
from lib import fur as FURLIB
from lib.body_shapes import arm_shapes, forearm_t, neck_shape, torso_shapes
from lib.cards import Card, cards_object
from lib.pipeline import garment_body_weights
from lib.regions import REGION_LIST, REGIONS, region_group
from lib.remesh import decimate, join, material, mesh_arrays, sdf_object, tri_count
from lib.sdf import (Ellipsoid, Fn, Inter, Offset, Onion, Plane, RoundCone, Sphere, Sub, SymUnion, Union, cut_plane,
                     frame_from, log, lerp, nrm, peval, smoothstep, surface_point, v3, zslab)
from lib.weights import (limit_normalize, mesh_adjacency, skirt_weights, sleeve_factor, smooth_weights,
                         transfer_from_tris)
from lib.wrap import Surface as WrapSurface
from lib.wrap import vertex_normals

PROVENANCE_NOTE = ("Frontier set generator (tools/character/garments/frontier); fabric kits derive from the "
                   "approved CC0 Poly Haven scans (luminance detail only).")

SKIRT_HELPERS = ["upper_leg_front_helper", "upper_leg_thigh_helper", "upper_leg_rear_helper"]
WAIST_Z = 0.942           # centre line of the standard waist belt (design §9.4: belt band 0.92-0.96)


# ===========================================================================
# small geometry helpers
# ===========================================================================
def poly_arrays(ob):
    """(centres (n, 3), unit normals (n, 3), areas (n,)) of the polygons."""
    me = ob.data
    n = len(me.polygons)
    C = np.empty(n * 3)
    N = np.empty(n * 3)
    A = np.empty(n)
    me.polygons.foreach_get("center", C)
    me.polygons.foreach_get("normal", N)
    me.polygons.foreach_get("area", A)
    return C.reshape(-1, 3), N.reshape(-1, 3), A


def sdf_grad(node, P, h=6e-4):
    g = np.zeros_like(P)
    for d in range(3):
        e = np.zeros(3)
        e[d] = h
        g[:, d] = (peval(node, P + e) - peval(node, P - e)) / (2 * h)
    return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)


def triangles(ob):
    me = ob.data
    me.calc_loop_triangles()
    T = np.empty(len(me.loop_triangles) * 3, int)
    me.loop_triangles.foreach_get("vertices", T)
    P = np.empty(len(me.loop_triangles), int)
    me.loop_triangles.foreach_get("polygon_index", P)
    return T.reshape(-1, 3), P


def loop_vertex(ob):
    me = ob.data
    lv = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    return lv


def loop_polygon(ob):
    me = ob.data
    lp = np.empty(len(me.loops), int)
    for p in me.polygons:
        lp[p.loop_start:p.loop_start + p.loop_total] = p.index
    return lp


def hidden_sizing(L_vis, L_hid, occluders, margin=0.0015):
    """Target edge length: L_vis (float or fn(P)) where the surface can be seen, L_hid
    inside the occluders (the body, an inner solid)."""
    def fn(P):
        vis = L_vis(P) if callable(L_vis) else np.full(len(P), L_vis)
        occ = np.min([peval(o, P) for o in occluders], axis=0)
        return np.where(occ < -margin, L_hid, vis)
    return fn


def delete_polys(ob, mask):
    """Deletes the polygons in `mask` (and loose vertices)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    dead = [bm.faces[i] for i in np.nonzero(mask)[0]]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def delete_inside(ctx, ob, depth=0.003, keep=None):
    """Deletes polygons lying entirely inside the body of both fits by more than `depth`
    (never visible: cut faces of the solid coat forms at openings, sleeve-end discs).
    Returns the number of polygons deleted."""
    V = mesh_arrays(ob)
    inside = (peval(ctx.body_sdf(), V) < -depth) & (peval(ctx.body_sdf(ctx.P_male), V) < -depth)
    me = ob.data
    mask = np.zeros(len(me.polygons), bool)
    for p in me.polygons:
        vs = list(p.vertices)
        mask[p.index] = inside[vs].all()
    if keep is not None:
        mask &= ~np.asarray(keep, bool)
    if mask.any():
        delete_polys(ob, mask)
    return int(mask.sum())


def weld(ob, dist=0.0004):
    """Merges vertices closer than `dist` and dissolves degenerate edges / faces (surface
    nets and the region cuts leave a few sub-millimetre edges, whose stretch ratio would
    dominate the deformation check's max edge), then triangulates."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bmesh.ops.dissolve_degenerate(bm, dist=dist, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return ob


def sdf_obj(*args, **kw):
    """lib.remesh.sdf_object followed by weld()."""
    return weld(sdf_object(*args, **kw))


def copy_object(ob, name):
    import bpy
    c = ob.copy()
    c.data = ob.data.copy()
    c.name = c.data.name = name
    bpy.context.scene.collection.objects.link(c)
    return c


# ===========================================================================
# coat bodies (after the legacy hunting frock of build_body.py, parameterized)
# ===========================================================================
class CoatParams:
    """Parameters of a coat-like garment (all heights in Blender z, metres)."""

    def __init__(self, **kw):
        self.off = 0.015                  # torso offset over coat_torso_shapes (outer band 13-18 mm)
        self.sleeve_off = 0.012           # sleeve offset over the arm (arms outer 11-14 mm)
        self.sleeve_off_lower = None      # forearm offset (default = sleeve_off)
        self.sleeve_end = 0.82            # sleeve end, fraction elbow -> wrist
        self.cuff = None                  # (t0, extra offset): turned-back cuff from t0 to the sleeve end
        self.hem = 0.525                  # back hem height
        self.front_rise = 0.06            # the front hem sits this much higher
        self.skirt_scale = (1.0, 1.0)     # skirt half width / depth scale (A-line tables of the legacy coat)
        self.skirt_flare = 0.0            # extra half width per metre below z 0.51
        self.skirt_half = 0.0045          # half the skirt wall thickness
        self.skirt_top = 0.975
        self.pleats = None                # (a0 deg, a1 deg, count, depth)
        self.open_z = [0.40, 0.50, 0.62, 0.72, 0.82, 0.88, 0.95]    # front opening half width by height
        self.open_w = [0.09, 0.075, 0.05, 0.03, 0.012, -0.01, -0.01]  # (< 0: closed)
        self.vent_top = 0.72              # the back vent splits the skirt below this height
        self.vent_w = 0.004
        self.cape = None                  # (lower edge z, offset over the torso + deltoids)
        self.collar = None                # dict(off, z0, z1, w0, slope): stand collar with a front V
        self.v_neck = None                # (z bottom, half width at the bottom, widening per metre)
        self.neck_r = 0.008
        self.torso_top = 1.40
        for k, v in kw.items():
            if not hasattr(self, k):
                raise KeyError(k)
            setattr(self, k, v)


SKIRT_Z = [0.40, 0.51, 0.60, 0.75, 0.85, 0.93, 0.99]
SKIRT_A = [0.262, 0.246, 0.236, 0.212, 0.190, 0.162, 0.150]
SKIRT_B = [0.192, 0.182, 0.174, 0.155, 0.142, 0.118, 0.110]
SKIRT_C = [0.008, 0.008, 0.009, 0.010, 0.012, 0.006, 0.004]
SKIRT_BACK_N = 3.2


def coat_torso_shapes(K):
    """The torso a coat is cut around: the smooth torso with the anatomy bridged (fuller
    chest and back plates, less waist taper), so cloth hangs instead of shrink-wrapping."""
    sb, sd = K["spineb"], K["spined"]
    chest = Ellipsoid(v3(0, sd[1] - 0.030, sd[2] - 0.035), (0.134, 0.062, 0.125))
    back = Ellipsoid(v3(0, sd[1] + 0.028, sd[2] - 0.015), (0.142, 0.080, 0.175))
    waist = Ellipsoid(v3(0, sb[1] + 0.027, sb[2] - 0.005), (0.128, 0.090, 0.125))
    return Union([torso_shapes(K, smooth=True), Union([chest, back, waist], k=0.06)], k=0.05)


def skirt_ab(p, Z):
    a = np.interp(Z, SKIRT_Z, SKIRT_A) * p.skirt_scale[0] + p.skirt_flare * np.maximum(0.51 - Z, 0.0)
    b = np.interp(Z, SKIRT_Z, SKIRT_B) * p.skirt_scale[1] + 0.7 * p.skirt_flare * np.maximum(0.51 - Z, 0.0)
    return a, b, np.interp(Z, SKIRT_Z, SKIRT_C)


def skirt_pleat(p, X, Y, Z):
    if p.pleats is None:
        return 0.0
    a0, a1, count, depth = p.pleats
    c = np.interp(Z, SKIRT_Z, SKIRT_C)
    ang = np.degrees(np.arctan2(np.abs(X), -(Y - c)))
    w = smoothstep(a0 - 8.0, a0 + 2.0, ang) * (1 - smoothstep(a1 - 2.0, a1 + 8.0, ang)) * smoothstep(0.83, 0.70, Z)
    return depth * w * np.cos((ang - a0) / (a1 - a0) * count * 2.0 * np.pi)


def skirt_form(p):
    """Solid skirt cross-section by height: an ellipse in front flattening toward a
    superellipse across the back (the back reads as one panel with square hem corners)."""
    def f(X, Y, Z):
        a, b, c = skirt_ab(p, Z)
        n = 2.0 + (SKIRT_BACK_N - 2.0) * smoothstep(0.86, 0.62, Z) * (Y > c)
        r = (np.abs(X / a) ** n + np.abs((Y - c) / b) ** n) ** (1.0 / n)
        return (r - 1.0) * np.minimum(a, b) - skirt_pleat(p, X, Y, Z)
    return Fn(f, (-0.33, -0.26, p.hem - 0.06), (0.33, 0.26, p.skirt_top + 0.05))


def hem_z(p, X, Y):
    ang = np.degrees(np.arctan2(np.abs(X), -Y))
    return p.hem + p.front_rise * (1 - smoothstep(50.0, 130.0, ang))


def skirt_slab(p):
    def f(X, Y, Z):
        return np.maximum(hem_z(p, X, Y) - Z, Z - 0.92)
    return Fn(f, (-2, -2, p.hem - 0.01), (2, 2, 0.92))


def front_opening(p):
    def f(X, Y, Z):
        w = np.interp(Z, p.open_z, p.open_w)
        return np.maximum(np.abs(X) - w, Y + 0.02)
    return Fn(f, (-0.3, -0.4, 0.3), (0.3, -0.02, 1.6))


def back_vent(p):
    def f(X, Y, Z):
        w = p.vent_w + 0.002 * smoothstep(p.hem + 0.10, p.hem, Z)
        return np.maximum(np.maximum(np.abs(X) - w, 0.02 - Y), Z - p.vent_top)
    return Fn(f, (-0.1, 0.02, 0.3), (0.1, 0.4, p.vent_top))


def neck_hole(K, r):
    nk, ha = K["neck"], K["heada"]
    return RoundCone(v3(0, nk[1] + 0.012, nk[2] - 0.07), v3(0, ha[1] + 0.012, ha[2] + 0.12), 0.049 + r, 0.049 + r)


def coat_torso_form(K, p, off=None):
    off = p.off if off is None else off
    torso = Inter(Offset(coat_torso_shapes(K), off), zslab(0.88, p.torso_top), k=0.01)
    # the filler is flush with the skirt wall's outside, so the skirt runs into the torso
    # without a step (the legacy coat hid that join under its belt)
    filler = Inter(Offset(skirt_form(p), p.skirt_half), zslab(0.86, p.skirt_top), k=0.01)
    return Union([torso, filler], k=0.012)


def _deltoid(K, s):
    S = K.side("shoulder", s)
    return Sphere(S + v3(s * 0.007, 0.002, 0.004), 0.042)


def arm_box(K, s):
    pts = np.array([K.side(n, s) for n in ("shoulder", "elbow", "wrist", "palm")])
    return pts.min(0) - 0.08, pts.max(0) + 0.08


def sleeve_node(K, p, s):
    t, E, fa, L = forearm_t(K, s)
    arm = arm_shapes(K, s)
    lo = p.sleeve_off if p.sleeve_off_lower is None else p.sleeve_off_lower
    if lo != p.sleeve_off:
        up = p.sleeve_off

        def r(X, Y, Z, t=t):
            return up + (lo - up) * smoothstep(-0.25, 0.35, t(X, Y, Z))
        base = Offset(arm, r, r_max=max(up, lo))
    else:
        base = Offset(arm, p.sleeve_off)
    sleeve = Inter(base, cut_plane(E + fa * p.sleeve_end * L, -fa))
    if p.cuff is None:
        return sleeve
    t0, extra = p.cuff
    cuff = Inter(Offset(arm, lo + extra),
                 Fn(lambda X, Y, Z, t=t: np.maximum(t0 - t(X, Y, Z), t(X, Y, Z) - p.sleeve_end - 0.012) * L,
                    *arm_box(K, s)))
    return Union([sleeve, cuff], k=0.004)


def cape_base(K, off, arm=0.0):
    """Torso + deltoids (+ the upper arms down to `arm` of shoulder -> elbow) offset."""
    def side(s):
        parts = [_deltoid(K, s)]
        if arm > 0:
            S, E = K.side("shoulder", s), K.side("elbow", s)
            parts.append(RoundCone(S, lerp(S, E, arm), 0.046, 0.041))
        return Union(parts, k=0.02)
    return Offset(SymUnion(coat_torso_shapes(K), side(1), side(-1), k=0.04), off)


def cape_node(K, p):
    z_edge, off = p.cape[0], p.cape[1]
    arm = p.cape[2] if len(p.cape) > 2 else 0.0
    return Inter(Inter(cape_base(K, off, arm), Fn(lambda X, Y, Z: z_edge - Z, (-0.5, -0.3, z_edge - 0.03), (0.5, 0.3, 1.5)),
                       k=0.006), zslab(z_edge - 0.06, 1.40))


def collar_node(K, c, body=None):
    """Stand collar over the neck (over the real body surface when `body` is given, so it
    keeps its clearance where the neck blends into the shoulders): a shell c["thick"] thick
    whose inside lies c["off"] - thick off the skin, with a front V."""
    if body is None:
        base = Offset(neck_shape(K), c["off"] - 0.5 * c.get("thick", 0.008))
    else:
        base = Offset(body, c["off"] - 0.5 * c.get("thick", 0.008))
    nk = K["neck"]
    tube = Fn(lambda X, Y, Z: np.sqrt(X ** 2 + (Y - nk[1] - 0.008) ** 2) - c.get("r_max", 0.095),
              (-0.2, -0.2, c["z0"] - 0.05), (0.2, 0.2, c["z1"] + 0.05))
    col = Inter(Inter(Onion(base, 0.5 * c.get("thick", 0.008)), zslab(c["z0"], c["z1"]), k=0.003), tube, k=0.006)

    def vcut(X, Y, Z):
        return np.maximum(np.abs(X) - (c["w0"] + (Z - c["z0"]) * c["slope"]), Y + 0.0)
    return Sub(col, Fn(vcut, (-0.2, -0.3, c["z0"] - 0.02), (0.2, 0.0, c["z1"] + 0.05)), k=0.002)


def v_neck_cut(p):
    zb, w0, slope = p.v_neck

    def f(X, Y, Z):
        w = w0 + np.maximum(Z - zb, 0.0) * slope
        return np.maximum(np.maximum(np.abs(X) - w, zb - Z), Y + 0.01)
    return Fn(f, (-0.2, -0.3, zb - 0.02), (0.2, -0.01, 1.5))


def coat_node(K, p, extra=(), body=None):
    """The coat solid: torso form + sleeves (+ cuffs), skirt shell, optional cape and
    collar and extra parts, minus the front opening, the back vent and the neck hole."""
    torso = coat_torso_form(K, p)
    body = SymUnion(torso, sleeve_node(K, p, 1), sleeve_node(K, p, -1), k=0.03)
    skirt = Inter(Onion(skirt_form(p), p.skirt_half), skirt_slab(p))
    parts = [body]
    if p.cape is not None:
        parts = [Union([body, cape_node(K, p)], k=0.008)]
    parts.append(skirt)
    if p.collar is not None:
        parts.append(collar_node(K, p.collar, body))
    parts += list(extra)
    coat = Union(parts, k=0.0)
    coat = Sub(coat, front_opening(p))
    coat = Sub(coat, back_vent(p))
    if p.v_neck is not None:
        coat = Sub(coat, v_neck_cut(p), k=0.003)
    return Sub(coat, neck_hole(K, p.neck_r))


def coat_face_class(ob, K, p, tol=0.0018, body=None):
    """Per polygon: 0 outside of the garment, 1 inside (skirt lining, collar inside),
    2 rim (cut faces at the front opening, the vent, the neck hole, the sleeve ends,
    the hem and collar edges)."""
    C, N, _ = poly_arrays(ob)
    cls = np.zeros(len(C), int)
    sf = peval(skirt_form(p), C)
    skirt = (C[:, 2] < 0.92) & (np.abs(sf) < p.skirt_half + 0.006) & (sleeve_factor(C, K) < 0.5)
    cls[skirt & (sf < -0.4 * p.skirt_half)] = 1
    cls[skirt & (np.abs(sf) <= 0.4 * p.skirt_half)] = 2
    rim = np.abs(peval(front_opening(p), C)) < tol
    rim |= np.abs(peval(back_vent(p), C)) < tol
    rim |= np.abs(peval(neck_hole(K, p.neck_r), C)) < tol
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        end = np.abs(t(C[:, 0], C[:, 1], C[:, 2]) - p.sleeve_end) * L < tol
        near = np.abs((C - E) @ fa) < 2 * L
        rim |= end & near & (np.abs(N @ fa) > 0.6)
    if p.cape is not None:
        rim |= (np.abs(C[:, 2] - p.cape[0]) < 0.004) & (np.abs(N[:, 2]) > 0.6)
    if p.collar is not None:
        c = p.collar
        colz = (C[:, 2] > c["z0"] - 0.005)
        rim |= colz & (np.abs(C[:, 2] - c["z1"]) < 0.004) & (N[:, 2] > 0.6)
        vc = np.abs(C[:, 0]) - (c["w0"] + (C[:, 2] - c["z0"]) * c["slope"])
        rad = np.stack([C[:, 0], C[:, 1] - K["neck"][1] - 0.008], 1)
        rn = np.linalg.norm(rad, axis=1)
        on_col = np.ones(len(C), bool) if body is None else peval(collar_node(K, c, body), C) < 0.0025
        rim |= colz & on_col & (np.abs(vc) < tol) & (C[:, 1] < 0)
        inward = (N[:, :2] * rad).sum(1) / np.maximum(rn, 1e-6) < -0.3
        cls[colz & on_col & inward & (rn < c.get("r_max", 0.095)) & (C[:, 2] > c["z0"] + 0.004) & ~rim] = 1
    hz = hem_z(p, C[:, 0], C[:, 1])
    rim |= skirt & (np.abs(C[:, 2] - hz) < 0.003) & (N[:, 2] < -0.6)
    cls[rim] = 2
    return cls


def coat_openings(ob, K, p, body=None, tol=0.0018):
    """Polygons at real openings (front opening, vent, neck hole, sleeve ends, hem, collar V)
    but not the cape's lower ledge or the collar top: the coverage margin is measured from
    these."""
    cls = coat_face_class(ob, K, p, tol, body)
    C, N, _ = poly_arrays(ob)
    if p.cape is not None:
        cls[(np.abs(C[:, 2] - p.cape[0]) < 0.006)] = 0
    return cls == 2


def coat_solid(K, p):
    """Solid of the torso and sleeves (for sizing / occlusion of inner parts)."""
    return SymUnion(coat_torso_form(K, p), *[Offset(arm_shapes(K, s), p.sleeve_off) for s in (1, -1)], k=0.03)


# ===========================================================================
# UVs in metres (grain aligned): cylinders around the body axis and the arm segments
# ===========================================================================
class Cyl:
    """u = angle * distance from the axis (metres around), v = v0 + distance along the
    axis. ref: direction of u = 0 (the seam is opposite)."""

    def __init__(self, a, b, ref, v0=0.0, r_min=0.02):
        self.a = np.asarray(a, float)
        self.d = nrm(np.asarray(b, float) - self.a)
        r = np.asarray(ref, float) - self.d * (np.asarray(ref, float) @ self.d)
        self.x = nrm(r)
        self.y = np.cross(self.d, self.x)
        self.v0, self.r_min = float(v0), r_min

    def map(self, P):
        q = P - self.a
        along = q @ self.d
        rad = q - np.outer(along, self.d)
        ang = np.arctan2(rad @ self.y, rad @ self.x)
        r = np.maximum(np.linalg.norm(rad, axis=1), self.r_min)
        return ang, r, self.v0 + along


class Flat:
    """Planar mapping (origin o, axes ex, ey), metres."""

    def __init__(self, o, ex, ey):
        self.o = np.asarray(o, float)
        self.ex = nrm(ex)
        ey = np.asarray(ey, float)
        self.ey = nrm(ey - self.ex * (ey @ self.ex))

    def map(self, P):
        q = P - self.o
        return None, None, np.stack([q @ self.ex, q @ self.ey], 1)


def part_uvs(ob, parts, part_of_poly):
    """Per-loop UVs: parts[k].map for the polygons of part k. Cylinder polygons that
    straddle the seam are unwrapped (their negative angles lifted by 2 pi); u = angle x the
    vertex's distance from the axis, so the fabric keeps its size around the cylinder."""
    V = mesh_arrays(ob)
    lv = loop_vertex(ob)
    lp = loop_polygon(ob)
    npoly = len(ob.data.polygons)
    part_of_poly = np.asarray(part_of_poly, int)
    uv = np.zeros((len(lv), 2))
    pl = part_of_poly[lp]
    for k, part in enumerate(parts):
        m = pl == k
        if not m.any():
            continue
        ang, r, v = part.map(V[lv[m]])
        if ang is None:
            uv[m] = v
            continue
        polys = lp[m]
        amin = np.full(npoly, np.inf)
        amax = np.full(npoly, -np.inf)
        np.minimum.at(amin, polys, ang)
        np.maximum.at(amax, polys, ang)
        wrap = (amax[polys] - amin[polys]) > math.pi
        ang = np.where(wrap & (ang < 0), ang + 2 * math.pi, ang)
        uv[m, 0] = ang * r              # per vertex: continuous across polygons
        uv[m, 1] = v
    return uv


def body_axis_cyl(K, ref=(0, -1, 0)):
    yc = K["spineb"][1]
    return Cyl((0, yc, 0.0), (0, yc, 1.0), ref)


def coat_uv_fn(K):
    """UVs of a coat: torso, skirt, collar and cape around the body axis (seam at the back
    centre); sleeves around the upper-arm and forearm axes (seam on the underside)."""
    def fn(ob):
        C, _, _ = poly_arrays(ob)
        parts = [body_axis_cyl(K)]
        part = np.zeros(len(C), int)
        sl = sleeve_factor(C, K) > 0.5
        for s in (1, -1):
            S, E, W = K.side("shoulder", s), K.side("elbow", s), K.side("wrist", s)
            down = v3(0, 0, -1)
            parts.append(Cyl(S, E, down))
            parts.append(Cyl(E, W, down, v0=float(np.linalg.norm(E - S))))
            side = sl & (np.sign(C[:, 0]) == s)
            t = ((C - E) @ (W - E)) / ((W - E) @ (W - E))
            up = (C - S) @ nrm(E - S) < np.linalg.norm(E - S)
            part[side & up & (t < 0.0)] = len(parts) - 2
            part[side & ~(up & (t < 0.0))] = len(parts) - 1
        return part_uvs(ob, parts, part)
    return fn


# ===========================================================================
# weights
# ===========================================================================
def coat_weights(ctx, ob, p, skirt_band=0.025, smooth=1):
    """Body weights (nearest point, torso from torso above the waist); the skirt below the
    waist blends from the pelvis into the skirt panel helpers (design §5.4)."""
    V = mesh_arrays(ob)
    W = garment_body_weights(ctx, ob)
    d = peval(skirt_form(p), V)
    sl = sleeve_factor(V, ctx.K)
    skirt = (np.abs(d) < skirt_band) & (V[:, 2] < 0.93) & (sl < 0.5)
    t = smoothstep(0.93, 0.87, V[:, 2])
    Ws = skirt_weights(V, ctx.bones, hem=p.hem, vent_top=p.vent_top)
    W[skirt] = W[skirt] * (1 - t[skirt, None]) + Ws[skirt] * t[skirt, None]
    if smooth:
        W = smooth_weights(W, mesh_adjacency(ob), smooth, 0.3)
    return limit_normalize(W)


def transfer_weights_from(src_ob, W_src, P):
    """Weights at points P from the nearest point of src_ob's triangles."""
    T, _ = triangles(src_ob)
    W, _ = transfer_from_tris(mesh_arrays(src_ob), T, W_src, P)
    return W


def rigid_card_weights(src_ob, W_src, roots, card_of_vertex):
    """Every card moves rigidly with the weights of the source surface at its root."""
    Wr = limit_normalize(transfer_weights_from(src_ob, W_src, roots))
    return Wr[card_of_vertex]


def rigid(bones, n, bone):
    W = np.zeros((n, len(bones)))
    W[:, bones.index(bone)] = 1.0
    return W


def islands(ob):
    """Connected component id per vertex."""
    E = mesh_adjacency(ob)
    n = len(ob.data.vertices)
    parent = np.arange(n)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for a, b in E:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)
    return np.array([find(i) for i in range(n)])


# ===========================================================================
# fur: shells + guard-hair cards (one surface, design §9)
# ===========================================================================
class FurParams:
    def __init__(self, **kw):
        self.shells = 10
        self.base_tris = 2000         # decimated outer surface the shells copy
        self.nominal = 0.035          # the longest pile of the palette (m): contact shortening scale
        self.cards = 500
        self.card_len = 0.05
        self.card_w = 0.0045
        self.card_lean = 0.8
        self.edge_taper = (0.0, 0.03, 0.55)   # (d0, d1, factor at the edge)
        self.seed = 7
        for k, v in kw.items():
            if not hasattr(self, k):
                raise KeyError(k)
            setattr(self, k, v)


def outer_mask(ob, node_out, thresh=0.3):
    """Polygons of `ob` facing away from `node_out` (a solid the garment surrounds: the
    body, or the skirt form): their normal agrees with the solid's outward gradient."""
    C, N, _ = poly_arrays(ob)
    g = sdf_grad(node_out, C)
    return (N * g).sum(1) > thresh


def contact_factor(P, N, blockers, nominal, min_f=0.25, start=0.008):
    """Length factor from free space along the normal: rays from P + N * start along N
    against the blocker meshes [(V, T)] (start clears the garment's own surface, which the
    decimated fur base only approximates); pile longer than 0.7 x the free distance is
    shortened."""
    f = np.ones(len(P))
    for Vb, Tb in blockers:
        bvh = BVHTree.FromPolygons([tuple(v) for v in Vb], [tuple(t) for t in Tb], all_triangles=True)
        for i in range(len(P)):
            hit = bvh.ray_cast(Vector(P[i] + N[i] * start), Vector(N[i]), nominal * 1.6)
            if hit[0] is not None:
                f[i] = min(f[i], max(min_f, (hit[3] + start) * 0.7 / nominal))
    return f


def strap_distance(P, paths):
    """Distance of points P to the closest of the polylines `paths` (closed loops)."""
    best = np.full(len(P), 1.0)
    for Q in paths:
        for i in range(len(Q)):
            a, b = Q[i], Q[(i + 1) % len(Q)]
            ab = b - a
            t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
            best = np.minimum(best, np.linalg.norm(P - (a + t[:, None] * ab), axis=1))
    return best


def comb_dirs(P, N, K, sleeve):
    """Comb direction (the way the pile lies) per point: world-down on the body, down the
    arm on sleeves; projected onto the tangent plane."""
    d = np.tile(v3(0, 0, -1), (len(P), 1))
    for s in (1, -1):
        m = sleeve & (np.sign(P[:, 0]) == s)
        if m.any():
            S, W = K.side("shoulder", s), K.side("wrist", s)
            d[m] = nrm(W - S)
    d = d - N * (d * N).sum(1, keepdims=True)
    bad = np.linalg.norm(d, axis=1) < 1e-6
    d[bad] = np.cross(N[bad], v3(1, 0, 0))
    return d / np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-9)


def fur_surface(ctx, name, main_ob, W_main, outer, fp, uv_fn, blockers, sleeve_fn=None, strap_paths=()):
    """Builds the fur surface of a garment from the fur-bearing polygons of main_ob:
    fp.shells stacked copies of the decimated outer surface (zone 0, h = k / n) and fp.cards
    guard-hair cards (zone 1). Returns (object, zones per polygon, h per vertex, weights,
    colours (rgba), edge (x belt distance, y strap distance), stats)."""
    K = ctx.K
    base = copy_object(main_ob, name + "_base")
    delete_polys(base, ~outer)
    decimate(base, fp.base_tris, symmetric=True)
    weld(base, 0.0008)
    # static length factor on the base: contact with the body / other parts, edge taper
    Vb = mesh_arrays(base)
    nb = len(Vb)
    me = base.data
    Nb = np.empty(nb * 3)
    me.vertices.foreach_get("normal", Nb)
    Nb = Nb.reshape(-1, 3)
    f = contact_factor(Vb, Nb, blockers, fp.nominal)
    Eb = mesh_adjacency(base)
    f = smooth_weights(f[:, None], Eb, 4, 0.5)[:, 0]          # no per-triangle blotches
    bnd = BD.boundary_verts(base)
    if len(bnd):
        d_edge = BD.edge_distance(base, bnd, max_d=1.0)
        d0, d1, fe = fp.edge_taper
        f *= fe + (1 - fe) * smoothstep(d0, d1, d_edge)
    shells_ob, h = FURLIB.shells(base, fp.shells, max_tris=10 ** 9, name=name + "_shells")
    nshell = len(mesh_arrays(shells_ob))
    reps = nshell // nb
    assert reps * nb == nshell, "shells do not tile the base"
    f_sh = np.tile(f, reps)
    uv_sh = uv_fn(shells_ob)
    lay = shells_ob.data.uv_layers.get("UVMap") or shells_ob.data.uv_layers.new(name="UVMap")
    lay.data.foreach_set("uv", np.asarray(uv_sh, np.float32).ravel())
    # guard-hair cards
    rng = np.random.default_rng(fp.seed)
    P, N, poly = FURLIB.surface_samples(base, fp.cards, seed=fp.seed)
    sl = sleeve_fn(P) if sleeve_fn is not None else np.zeros(len(P), bool)
    comb = comb_dirs(P, N, K, sl)
    # guard hairs only where the pile is long enough (not at contacts / edges)
    fP = np.ones(len(P))
    Tb, _ = triangles(base)
    Wf, _ = transfer_from_tris(Vb, Tb, f[:, None], P)
    fP = Wf[:, 0]
    keep = fP > 0.5
    P, N, comb, fP = P[keep], N[keep], comb[keep], fP[keep]
    cards = []
    for p, n, c, ff in zip(P, N, comb, fP):
        L = fp.card_len * ff * (0.7 + 0.6 * rng.random())
        d = nrm(n * (1 - fp.card_lean) + c * fp.card_lean)
        pts = [p - n * 0.001 + d * L * (i / 2) + c * L * 0.18 * (i / 2) ** 2 for i in range(3)]
        side = np.cross(d, n)
        hint = nrm(np.cross(side, d)) if np.linalg.norm(side) > 1e-6 else n
        cards.append(Card(pts, [fp.card_w, fp.card_w * 0.8, fp.card_w * 0.45], hint))
    cob, hc, cidx = cards_object(name + "_guard", cards, material(name + "_tmp", "#555555"))
    lay = cob.data.uv_layers["UVMap"]
    uvc = np.empty(len(cob.data.loops) * 2, np.float32)
    lay.data.foreach_get("uv", uvc)
    uvc = uvc.reshape(-1, 2)
    lvc = loop_vertex(cob)
    uvc[:, 0] += (cidx[lvc] * 0.01373) % 1.0          # every card its own strand pattern
    lay.data.foreach_set("uv", uvc.ravel())
    roots = np.array([c.P[0] for c in cards]) if cards else np.zeros((0, 3))
    # weights: shells like the main surface under them, cards rigid with their root
    Vs = mesh_arrays(shells_ob)
    W_sh = limit_normalize(transfer_weights_from(main_ob, W_main, Vs))
    W_c = rigid_card_weights(main_ob, W_main, roots, cidx) if len(cards) else np.zeros((0, W_main.shape[1]))
    zones = np.concatenate([np.zeros(len(shells_ob.data.polygons), int), np.ones(len(cob.data.polygons), int)])
    h_all = np.concatenate([h, hc])
    f_all = np.concatenate([f_sh, fP[cidx] if len(cards) else np.zeros(0)])
    Vall = np.concatenate([Vs, mesh_arrays(cob)])
    W = np.concatenate([W_sh, W_c])
    root_pts = np.concatenate([Vs, roots[cidx]]) if len(cards) else Vs
    belt = np.abs(root_pts[:, 2] - WAIST_Z)
    strap = strap_distance(root_pts, strap_paths) if strap_paths else np.full(len(root_pts), 1.0)
    ob = join([shells_ob, cob], name)
    col = np.ones((len(Vall), 4))
    col[:, 3] = np.clip(f_all, 0.0, 1.0)
    import bpy
    bpy.data.objects.remove(base, do_unlink=True)
    ntri = tri_count(ob)
    card_tris = 4 * len(cards)
    stats = {"shells": fp.shells, "shell_tris": ntri - card_tris, "cards": len(cards), "card_tris": card_tris,
             "base_tris": (ntri - card_tris) // max(fp.shells, 1)}
    return ob, zones, h_all, W, col, (belt, strap), stats


# ===========================================================================
# fringe cards (hunting shirt cape and hem, legging seams)
# ===========================================================================
def fringe_cards(roots, normals, downs, width, length, droop=0.25, segs=3, seed=5, jitter=0.2, lift=0.0015):
    """Cards along an edge: each card's strands run from its root down `downs` (the
    fringe hangs), it is `width` wide along the edge and faces `normals`."""
    rng = np.random.default_rng(seed)
    cards = []
    for p, n, d in zip(roots, normals, downs):
        L = length * (1.0 - jitter + 2 * jitter * rng.random())
        g = v3(0, 0, -1)
        pts = []
        for i in range(segs + 1):
            s = i / segs
            q = p + n * lift + d * L * s + g * droop * L * s * s
            pts.append(q)
        cards.append(Card(pts, np.linspace(width, width * 0.92, segs + 1), n))
    return cards


def fringe_object(name, cards, seed=11):
    ob, h, cidx = cards_object(name, cards, material(name + "_tmp", "#8a7050"))
    rng = np.random.default_rng(seed)
    offs = rng.random(len(cards))
    lay = ob.data.uv_layers["UVMap"]
    uv = np.empty(len(ob.data.loops) * 2, np.float32)
    lay.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    lv = loop_vertex(ob)
    uv[:, 0] += offs[cidx[lv]]
    lay.data.foreach_set("uv", uv.ravel())
    return ob, h, cidx


def ray_hit(node, o, d, t_max, step=0.002):
    """First point where the ray o + t d (t in 0..t_max) enters `node` (marching, then
    bisection); None when it never does."""
    ts = np.arange(0.0, t_max + step, step)
    f = peval(node, o[None, :] + ts[:, None] * d[None, :])
    inside = np.nonzero(f < 0)[0]
    if len(inside) == 0:
        return None
    i = inside[0]
    if i == 0:
        return o
    a, b = ts[i - 1], ts[i]
    for _ in range(30):
        m = 0.5 * (a + b)
        if peval(node, (o + d * m)[None])[0] < 0:
            b = m
        else:
            a = m
    return o + d * a


def edge_roots(node, heights, angles, axis_xy=(0.0, -0.027), r_out=0.45, below=0.0):
    """Points on the outer surface of `node` at height z(angle), found from outside toward
    the body axis; returns (points, outward normals, down directions along the surface)."""
    P, N, D = [], [], []
    cx, cy = axis_xy
    for z, a in zip(heights, angles):
        d = v3(math.sin(a), -math.cos(a), 0.0)
        o = v3(cx, cy, z) + d * r_out
        p = ray_hit(node, o, -d, r_out)
        if p is None:
            continue
        e = 5e-4
        g = np.array([(peval(node, (p + ex * e)[None])[0] - peval(node, (p - ex * e)[None])[0]) for ex in np.eye(3)])
        n = nrm(g)
        dn = v3(0, 0, -1) - n * n[2]
        dn = nrm(dn) if np.linalg.norm(dn) > 1e-6 else v3(0, 0, -1)
        P.append(p + v3(0, 0, below))
        N.append(n)
        D.append(dn)
    return np.array(P), np.array(N), np.array(D)


# ===========================================================================
# shoulder straps (powder horn, shot pouch) and their envelopes
# ===========================================================================
# Envelope variants (design §5.5): the strap sits on the outermost torso layer.
STRAP_ENVS = {"env10": ("body", 0.0075), "env20": ("body", 0.0135), "env40": ("coat", 0.0195), "env50": ("coat", 0.034)}
STRAP_HALF_T = 0.0015
STRAP_WIDTH = 0.0125


def strap_form(K, env):
    kind, off = STRAP_ENVS[env]
    if kind == "body":
        return Offset(Union([torso_shapes(K, smooth=True), neck_shape(K)], k=0.05), off)
    p = CoatParams(hem=0.50, skirt_scale=(1.0, 1.0))
    return Offset(Union([coat_torso_form(K, p, off=0.015), Offset(neck_shape(K), 0.004)], k=0.03), off - 0.015)


def strap_plane(s):
    """(point on the strap's mid plane, unit normal): from the s-side shoulder across the
    chest and back to the opposite hip."""
    p0 = v3(s * 0.085, 0.02, 1.345)
    p1 = v3(-s * 0.20, 0.005, 0.915)
    return p0, p1, nrm(np.cross(p1 - p0, v3(0, 1, 0)))


_STRAP_PATHS = {}


def strap_path(K, s, env="env40", n=64):
    """Closed centre line of the s-side strap on the envelope `env`: where the strap's mid
    plane meets the envelope surface, as n points."""
    key = (s, env, n)
    if key not in _STRAP_PATHS:
        form = strap_form(K, env)
        p0, p1, n_ = strap_plane(s)
        a = nrm(np.cross(v3(0, 1, 0), n_))
        c0 = 0.5 * (p0 + p1) * v3(1, 0, 1)
        pts = []
        for th in np.linspace(0.0, 2 * np.pi, n, endpoint=False):
            d = a * math.cos(th) + v3(0, 1, 0) * math.sin(th)
            pts.append(surface_point(form, c0 + d * 0.5, -d, 0.0, 0.5))
        _STRAP_PATHS[key] = np.array(pts)
    return _STRAP_PATHS[key]


# ===========================================================================
# coverage analysis -> hides_regions
# ===========================================================================
def sex_delta(ctx, ob):
    body = ctx.body()
    surf = WrapSurface(body.V, body.F, shapes=body.shapes)
    b = surf.bind(mesh_arrays(ob))
    return surf.shape_delta(b, "sex", smooth_E=mesh_adjacency(ob), smooth_iters=3)


def coverage(ctx, ob, W=None, exclude_bones=(), exclude_max=0.15, min_edge=0.012, max_dist=0.10,
             candidates=None, edge_polys=None, debug=False):
    """Share of each body region's triangles that the garment covers at bind for both body
    fits: a triangle is covered when the ray from each of its vertices along the skin
    normal hits the garment within max_dist, at a garment triangle at least `min_edge`
    (geodesic) from the garment's open edges and not weighted more than exclude_max to
    `exclude_bones` (e.g. the skirt panels, which swing away from the body).
    Returns {region: (share female, share male)}."""
    body = ctx.body()
    Vg0 = mesh_arrays(ob)
    T, _ = triangles(ob)
    bnd = BD.boundary_verts(ob)
    if edge_polys is not None:
        ev = set(bnd.tolist())
        for p in ob.data.polygons:
            if edge_polys[p.index]:
                ev.update(p.vertices)
        bnd = np.array(sorted(ev), int)
    dist_edge = BD.edge_distance(ob, bnd, max_d=1.0) if len(bnd) else np.ones(len(Vg0))
    bad_v = np.zeros(len(Vg0), bool)
    if W is not None and exclude_bones:
        cols = [ctx.bones.index(b) for b in exclude_bones if b in ctx.bones]
        bad_v = W[:, cols].sum(1) > exclude_max
    tri_ok = (dist_edge[T].min(1) >= min_edge) & ~bad_v[T].any(1)
    D = sex_delta(ctx, ob)
    freg = body.freg
    names = candidates or REGION_LIST
    want = np.isin(freg, [REGIONS[n] for n in names])
    vsel = np.unique(body.F[want])
    out = {}
    cov = []
    for sex in (0.0, 1.0):
        Vb = body.V + sex * body.shapes["sex"]
        Nb = vertex_normals(Vb, body.F)
        Vg = Vg0 + sex * D
        bvh = BVHTree.FromPolygons([tuple(v) for v in Vg], [tuple(t) for t in T], all_triangles=True)
        ok = np.zeros(len(Vb), bool)
        for i in vsel:
            hit = bvh.ray_cast(Vector(Vb[i] + Nb[i] * 0.001), Vector(Nb[i]), max_dist)
            if hit[2] is not None and tri_ok[hit[2]]:
                ok[i] = True
        cov.append(ok[body.F].all(1))
        if debug:
            bad = want & ~cov[-1]
            Cb = Vb[body.F[bad]].mean(1)
            if len(Cb):
                log("  coverage debug sex %.0f: %d uncovered tris, z %s, y %s, |x| %s" % (
                    sex, len(Cb), np.percentile(Cb[:, 2], [0, 25, 50, 75, 100]).round(3),
                    np.percentile(Cb[:, 1], [0, 25, 50, 75, 100]).round(3),
                    np.percentile(np.abs(Cb[:, 0]), [0, 25, 50, 75, 100]).round(3)))
    for n in names:
        m = freg == REGIONS[n]
        if m.any():
            out[n] = (float(cov[0][m].mean()), float(cov[1][m].mean()))
    return out


def pick_hides(cov, need=0.995, exclude=()):
    """Regions covered in both fits; left / right pairs only together (the worse side
    decides, so a garment never hides one side only)."""
    def score(n):
        a, b = cov[n]
        m = min(a, b)
        if n.endswith(("_l", "_r")):
            o = n[:-1] + ("r" if n.endswith("_l") else "l")
            if o in cov:
                m = min(m, *cov[o])
        return m
    return [n for n in cov if score(n) >= need and n not in exclude]


def log_coverage(tag, cov):
    rows = ["%s %.2f/%.2f" % (n, a, b) for n, (a, b) in sorted(cov.items(), key=lambda kv: REGIONS[kv[0]])
            if max(a, b) > 0.2]
    log("  coverage %s: %s" % (tag, ", ".join(rows)))


# ===========================================================================
# misc
# ===========================================================================
def edge_uv_arrays(ob, sources_fn=None, open_fn=None):
    """(d_hem, d_open) geodesic distances (m) from the boundary vertices selected by
    sources_fn(P) and open_fn(P) (None: all boundary vertices / 1.0)."""
    b = BD.boundary_verts(ob)
    V = mesh_arrays(ob)
    if len(b) == 0:
        return np.ones(len(V)), np.ones(len(V))
    bh = b if sources_fn is None else b[np.asarray(sources_fn(V[b]), bool)]
    d_hem = BD.edge_distance(ob, bh, max_d=1.0) if len(bh) else np.ones(len(V))
    if open_fn is None:
        return d_hem, np.ones(len(V))
    bo = b[np.asarray(open_fn(V[b]), bool)]
    d_open = BD.edge_distance(ob, bo, max_d=1.0) if len(bo) else np.ones(len(V))
    return d_hem, d_open


def zone_colors(n, rgb=None, a=None):
    c = np.ones((n, 4))
    if rgb is not None:
        c[:, :3] = np.asarray(rgb).reshape(n, -1)[:, :3] if np.ndim(rgb) > 1 else rgb[:, None]
    if a is not None:
        c[:, 3] = a
    return c


def group_of_regions(names):
    return sorted(set(region_group(n) for n in names))


# ===========================================================================
# fur presets (fur_shell.gdshader parameters per palette token; bible §0.4, §2.4)
# ===========================================================================
# Colours sRGB. length: shell pile in metres (guard-hair cards add the long silhouette:
# guard = share of the baked card length). The bible's guard-hair lengths (bear 6-10 cm,
# wolf 5-8, beaver 2-3) are shortened for a worn, tailored garment: the shells carry the
# dense underfur and the cards the longer guard hairs.
FUR_PRESETS = {
    "fur_black_bear": {"root": "#15110e", "band": "#1f1a16", "tip": "#3a2e25", "band_pos": 0.5, "tip_pos": 0.75,
                       "length": 0.024, "guard": 1.0, "guard_amount": 1.0, "density": 1500, "clump": 0.6,
                       "clump_size": 0.014, "droop": 0.18, "comb": 0.39, "gloss": 0.55},
    "fur_brown_bear": {"root": "#2c1f16", "band": "#4b3526", "tip": "#6e5037", "band_pos": 0.5, "tip_pos": 0.78,
                       "length": 0.024, "guard": 1.0, "guard_amount": 1.0, "density": 1500, "clump": 0.6,
                       "clump_size": 0.014, "droop": 0.18, "comb": 0.39, "gloss": 0.4},
    "fur_beaver": {"root": "#7b5a40", "band": "#5a3b25", "tip": "#4a2f1d", "band_pos": 0.55, "tip_pos": 0.8,
                   "length": 0.013, "guard": 0.55, "guard_amount": 0.8, "density": 2400, "clump": 0.3,
                   "clump_size": 0.008, "droop": 0.10, "comb": 0.49, "gloss": 0.8},
    "fur_wolf": {"root": "#cfc3a8", "band": "#7f776b", "tip": "#3c3833", "band_pos": 0.45, "tip_pos": 0.78,
                 "length": 0.022, "guard": 0.9, "guard_amount": 1.0, "density": 1700, "clump": 0.55,
                 "clump_size": 0.012, "droop": 0.14, "comb": 0.42, "gloss": 0.3},
    "fur_raccoon": {"root": "#8a8177", "band": "#6a6259", "tip": "#2a2622", "band_pos": 0.5, "tip_pos": 0.72,
                    "length": 0.02, "guard": 0.85, "guard_amount": 1.0, "density": 1800, "clump": 0.5,
                    "clump_size": 0.011, "droop": 0.14, "comb": 0.39, "gloss": 0.3},
    "fur_red_fox": {"root": "#c99a70", "band": "#a5532b", "tip": "#8a3f1e", "band_pos": 0.45, "tip_pos": 0.8,
                    "length": 0.022, "guard": 0.9, "guard_amount": 1.0, "density": 1800, "clump": 0.5,
                    "clump_size": 0.011, "droop": 0.14, "comb": 0.42, "gloss": 0.35},
}


def fur_block(surface, tokens, strap_envelope="env50", length_scale=1.0):
    return {"surface": surface, "shader": "res://assets/character/shaders/fur_shell.gdshader", "length_scale": length_scale,
            "palette_zone": 0, "shell_zone": 0, "card_zone": 1, "strap_envelope": strap_envelope,
            "belt_line_z": WAIST_Z,
            "uniforms": {"fur_length": "length", "guard_length": "guard", "guard_amount": "guard_amount",
                         "root_color": "root", "band_color": "band", "tip_color": "tip", "band_pos": "band_pos",
                         "tip_pos": "tip_pos", "density": "density", "clump": "clump", "clump_size": "clump_size",
                         "droop": "droop", "comb": "comb", "gloss": "gloss"},
            "presets": {t: FUR_PRESETS[t] for t in tokens if t in FUR_PRESETS},
            "note": ("Shells + guard cards in one surface; fur_length = preset length x length_scale. The base "
                     "(main surface, zone role 'fur') takes the "
                     "preset's root colour. Set belt_flatten / strap_flatten to 1 when a belt / shoulder strap "
                     "is worn over this garment (use the strap_envelope variant).")}


def coat_edge_uv(ob, K, p):
    """(x, y) for CUSTOM0 on a coat: x = height above the hem line on the skirt, or the
    distance from the sleeve end on the sleeves (m); y = distance from the front edge."""
    V = mesh_arrays(ob)
    x = np.maximum(V[:, 2] - hem_z(p, V[:, 0], V[:, 1]), 0.0)
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        sl = (np.sign(V[:, 0]) == s) & (sleeve_factor(V, K) > 0.5)
        d = np.maximum((p.sleeve_end - t(V[:, 0], V[:, 1], V[:, 2])) * L, 0.0)
        x[sl] = np.minimum(x[sl], d[sl])
    w = np.interp(V[:, 2], p.open_z, p.open_w)
    y = np.where(w > 0, np.maximum(np.abs(V[:, 0]) - w, 0.0), 1.0)
    return np.minimum(x, 1.0), np.minimum(y, 1.0)


# ===========================================================================
# deformation limits (check_body_deform.gd reads "deform_limits" from the fragments)
# ===========================================================================
LIMITS_FILE = __import__("os").path.join(__import__("os").path.dirname(__file__), "deform_limits.json")


def deform_limits(spec):
    """{surface: [collapse, flip, stretch share, max edge]} of `spec` from deform_limits.json
    (written by scan_limits.py from the measured scan, 25 % above it, both fits)."""
    import json
    import os
    if not os.path.exists(LIMITS_FILE):
        return {}
    with open(LIMITS_FILE) as f:
        d = json.load(f)
    return {k: v for k, v in d.get("limits", {}).items() if k == spec.id or k.startswith(spec.id + "_")}
