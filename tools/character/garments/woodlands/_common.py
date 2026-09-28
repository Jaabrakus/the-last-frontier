"""Shared code of the Eastern Woodlands (1750s) garments (costume bible §3, Set C).

Garment modules (tools/character/garments/woodlands/ew_<id>.py) define SPEC and
build(ctx); `tools/character/build_character.sh --garments woodlands` runs them through
lib.pipeline.finish_part. The lib is imported and never edited; everything the set needs
beyond it lives here:

  spec()       catalog entry of the set: bible names (§3.6 "Naming in the UI"), palette
               tokens (§0.4), evidence and sources, fabric codes, deform limits, the
               consultation note (§3.7).
  Hull         radial hull of the body's torso and legs per height (no arms), and forms
               that hang straight down from it with a clearance: skirts, shirt tails,
               breechcloth flaps and the blanket's lower wrap bridge the thighs instead of
               shrink-wrapping them.
  Builder      one mesh from SDF pieces (lib.remesh.sdf_object), parametric sheets
               (solid, rims filled) and primitives, with the zone and piece of every
               polygon and per-vertex attributes in a known order (no join ordering).
  UVs          metres along the grain: cylinders around the torso, limb and leg axes
               (u = angle x the vertex's own radius), flat maps, or the sheet's own (u, v).
  weights      nearest body point (torso-from-torso above the waist, helpers included),
               skirt panels with a wide left / right blend (flaps and tails in front of both
               thighs), rigid pieces, band-averaged belts.
  checks       hides_regions verified by rays from the skin (normal and a tilted cone) on
               both fits; clearance over the skin at bind for both fits (the `sex` wrap
               transfer as lib.pipeline does it).
"""

import math
import os

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import regions as RG
from lib.bands import edge_distance
from lib.body_shapes import body_groups
from lib.catalog import GarmentSpec, Zone
from lib.materials import METALS, token_hex
from lib.pipeline import Surface, body_weights_at
from lib.remesh import decimate, material, mesh_arrays, mesh_object, sdf_object, set_sharp, tri_count
from lib.sdf import Fn, log, nrm, peval, smoothstep, v3
from lib.weights import (_hat_split, band_smooth, chain_weights, limit_normalize, mesh_adjacency, rigid_islands,
                         sleeve_factor, smooth_weights)
from lib.wrap import Surface as WrapSurface
from lib.wrap import vertex_normals

SET = "woodlands"
REVIEW = ("Eastern Woodlands dress of living nations: needs paid review by the nations concerned (their cultural "
          "or historic-preservation offices) before public release; costume bible 3.7. No consultation has "
          "happened yet.")
FABRIC_NOTE = ("Fabric: approved Poly Haven CC0 kit (assets/polyhaven/textures/clothing), luminance detail tinted to the "
               "palette colour at runtime; UVs in metres along the grain.")
CONE_DEG = 25.0               # hides_regions: tilted rays must hit the garment too
OCCUPY_SHARE = 0.30           # occupies_regions: share of the region's skin under the garment
TORSO_Z = (0.98, 1.04)        # lib.pipeline: torso-from-torso blend above the waist

# Deform limits per surface ([collapse share, flip share, stretch share, max edge ratio]),
# the check_body_deform.gd format; the catalog entry carries them as "deform_limits".
# Filled per garment from the scan (both fits), 25 % above it (the method of the legacy
# and body limits); the default is check_body_deform's DEFAULT_LIMIT.
DEFAULT_LIMIT = [0.01, 0.01, 0.01, 4.0]


# ---------------------------------------------------------------------------
# catalog
# ---------------------------------------------------------------------------
class WZone(Zone):
    """Zone with the fabric codes the UI may offer (first = default) and a metal flag."""

    def __init__(self, zone, role, fabric="FLAT", palette=None, default=None, pattern=None, bands=None, name=None,
                 fabrics=None):
        super().__init__(zone, role, fabric, palette, default, pattern, bands, name)
        self.fabrics = list(fabrics or [fabric])

    def to_dict(self):
        d = super().to_dict()
        d["fabrics"] = self.fabrics
        d["metal"] = self.fabric == "MET"
        return d


def spec(id, name, slot, layer, zones, description, history, evidence="A", sources=(), budget=2000, tags=(),
         limits=None, extra=None, **kw):
    from garments.woodlands._limits import limits_for
    ex = {"fabric_note": FABRIC_NOTE, "review": REVIEW,
          "deform_limits": {id: list(limits or limits_for(id))}}
    ex.update(extra or {})
    return GarmentSpec(id=id, name=name, slot=slot, set=SET, layer=layer, zones=zones, description=description,
                       history=history, evidence=evidence, sources=list(sources), budget={"tris_max": budget},
                       tags=["woodlands"] + list(tags), extra=ex, surfaces={"main": id}, **kw)


def zone_mats(sp):
    """Preview material per zone id (the zone's default colour)."""
    out = []
    for z in sorted(sp.zones, key=lambda z: z.zone):
        tok = z.default or "#888888"
        metal = tok in METALS or z.fabric == "MET"
        out.append(material("%s_z%d" % (sp.id, z.zone), token_hex(tok), 0.35 if metal else 0.85, 0.9 if metal else 0.0))
    return out


# ---------------------------------------------------------------------------
# body
# ---------------------------------------------------------------------------
_CACHE = {}


def body_f(ctx):
    if "f" not in _CACHE:
        _CACHE["f"] = ctx.body_sdf(ctx.P_female)
    return _CACHE["f"]


def body_m(ctx):
    if "m" not in _CACHE:
        _CACHE["m"] = ctx.body_sdf(ctx.P_male)
    return _CACHE["m"]


def groups_f(ctx):
    if "gf" not in _CACHE:
        _CACHE["gf"] = body_groups(ctx.K, ctx.P_female)
    return _CACHE["gf"]


# ---------------------------------------------------------------------------
# hull forms (radial, per height)
# ---------------------------------------------------------------------------
class Hull:
    """Radial hull r(theta, z) of the body's torso and legs (the female base body of the
    cache; no arms, hands or head) around the vertical axis through `center` (x, y).
    theta = atan2(y - cy, x - cx): 0 = the character's left (+x), -90 deg = the front (-y).
    Slices every `dz` metres; each is the convex hull of the body points within the slice
    (support function in `n` directions -> radial function)."""

    def __init__(self, ctx, z0=0.05, z1=1.14, dz=0.01, n=144, center=(0.0, 0.005),
                 labels=("torso", "leg_l", "leg_r", "foot_l", "foot_r", "neck")):
        key = ("hull", z0, z1, dz, n, center, labels)
        body = ctx.body()
        self.c = np.asarray(center, float)
        self.zs = np.arange(z0, z1 + 1e-9, dz)
        self.dz = dz
        self.th = np.linspace(-math.pi, math.pi, n, endpoint=False)
        if key in _CACHE:
            self.R = _CACHE[key]
            return
        m = np.isin(body.vlab, list(labels))
        P = body.V[m]
        U = np.stack([np.cos(self.th), np.sin(self.th)], 1)
        C = np.cos(self.th[:, None] - self.th[None, :])
        R = np.zeros((len(self.zs), n))
        for i, z in enumerate(self.zs):
            sel = np.abs(P[:, 2] - z) < dz * 0.75
            if sel.sum() < 8:
                sel = np.abs(P[:, 2] - z) < dz * 2.0
            Q = P[sel, :2] - self.c
            h = (Q @ U.T).max(0)
            ratio = np.where(C > 0.2, h[None, :] / np.maximum(C, 1e-6), np.inf)
            R[i] = ratio.min(1)
        self.R = R
        _CACHE[key] = R

    def form(self, clear, hang_top=None, folds=None, smooth_th=2, smooth_z=1, z_range=None):
        """RadialForm: r(theta, z) = the hull (hanging straight down below `hang_top`: the
        widest slice above wins) + clear(z) (+ folds(theta, z))."""
        R = self.R.copy()
        if hang_top is not None:
            top = int(np.searchsorted(self.zs, hang_top))
            top = min(top, len(self.zs) - 1)
            for i in range(top - 1, -1, -1):
                R[i] = np.maximum(R[i], R[i + 1])
        for _ in range(smooth_th):
            R = 0.25 * np.roll(R, 1, 1) + 0.5 * R + 0.25 * np.roll(R, -1, 1)
        for _ in range(smooth_z):
            R[1:-1] = 0.25 * R[:-2] + 0.5 * R[1:-1] + 0.25 * R[2:]
        cl = np.array([clear(z) for z in self.zs]) if callable(clear) else np.full(len(self.zs), float(clear))
        R = R + cl[:, None]
        if folds is not None:
            TH, ZZ = np.meshgrid(self.th, self.zs)
            R = R + folds(TH, ZZ)
        return RadialForm(self.c, self.zs, self.th, R, z_range)


class RadialForm:
    def __init__(self, c, zs, th, R, z_range=None):
        self.c, self.zs, self.th, self.R = c, zs, th, R
        self.n = len(th)
        self.z_range = z_range or (float(zs[0]), float(zs[-1]))

    def radius(self, TH, Z):
        TH = np.asarray(TH, float)
        Z = np.asarray(Z, float)
        fz = np.clip((Z - self.zs[0]) / (self.zs[1] - self.zs[0]), 0.0, len(self.zs) - 1.000001)
        i0 = np.floor(fz).astype(int)
        tz = fz - i0
        ft = (TH + math.pi) / (2 * math.pi) * self.n
        j0 = np.floor(ft).astype(int)
        tt = ft - j0
        j0 %= self.n
        j1 = (j0 + 1) % self.n
        R = self.R
        a = R[i0, j0] * (1 - tt) + R[i0, j1] * tt
        b = R[i0 + 1, j0] * (1 - tt) + R[i0 + 1, j1] * tt
        return a * (1 - tz) + b * tz

    def f(self, X, Y, Z):
        dx, dy = X - self.c[0], Y - self.c[1]
        rho = np.sqrt(dx * dx + dy * dy)
        th = np.arctan2(dy, dx)
        return rho - self.radius(th, Z)

    def node(self, pad=0.02):
        rmax = float(self.R.max()) + pad
        lo = (self.c[0] - rmax, self.c[1] - rmax, self.z_range[0] - pad)
        hi = (self.c[0] + rmax, self.c[1] + rmax, self.z_range[1] + pad)
        return Fn(self.f, lo, hi)

    def point(self, TH, Z, extra=0.0):
        r = self.radius(TH, Z) + extra
        TH = np.asarray(TH, float)
        return np.stack([self.c[0] + r * np.cos(TH), self.c[1] + r * np.sin(TH), np.broadcast_to(Z, np.shape(TH))], -1)


FRONT = -math.pi / 2          # theta of the front centre (-y)
BACK = math.pi / 2


def angle_from_front(X, Y, cy=0.005):
    """0 at the front centre, 180 deg at the back (both sides)."""
    return np.degrees(np.arctan2(np.abs(X), -(Y - cy)))


# ---------------------------------------------------------------------------
# mesh building
# ---------------------------------------------------------------------------
class Builder:
    """Accumulates pieces into one mesh: vertices, polygons, zone and piece per polygon,
    per-vertex attributes (e.g. sheet u, v and edge distances; NaN where unset)."""

    def __init__(self, sp):
        self.sp = sp
        self.V, self.F, self.zone, self.piece, self.names = [], [], [], [], []
        self.attrs = {}
        self.n = 0

    def _add(self, name, V, F, zone, attrs=None):
        V = np.asarray(V, float)
        good = []
        for f in F:
            if len(set(f)) != len(f):
                continue
            P = V[list(f)]
            a = np.linalg.norm(np.cross(P[1] - P[0], P[2] - P[0]))
            if len(f) == 3 and a < 1e-12:
                continue
            good.append(f)
        if len(good) < len(F):
            log("  %s: dropped %d degenerate polygons" % (name, len(F) - len(good)))
        F = good
        k = len(self.names)
        self.names.append(name)
        self.V.append(V)
        self.F += [tuple(int(i) + self.n for i in f) for f in F]
        z = np.broadcast_to(np.asarray(zone, int), (len(F),))
        self.zone += list(z)
        self.piece += [k] * len(F)
        for key, val in (attrs or {}).items():
            self.attrs.setdefault(key, []).append((self.n, np.asarray(val, float)))
        self.n += len(V)
        return k

    def sdf(self, name, node, h, tris, zone, sizing=None, symmetric=True, max_tris=None, **kw):
        """A piece from an SDF (lib.remesh.sdf_object; the isotropic remesh overshoots its
        sizing estimate, so `max_tris` QEM-decimates the result); the temporary object is
        removed."""
        ob = sdf_object("%s_%s" % (self.sp.id, name), node, h, tris, material("_tmp_piece", "#888888"),
                        sizing=sizing, symmetric=symmetric, **kw)
        if max_tris is not None and tri_count(ob) > max_tris:
            decimate(ob, max_tris, symmetric=symmetric)
            log("  %-12s decimated to %d tris" % (name, tri_count(ob)))
        V = mesh_arrays(ob)
        F = [tuple(p.vertices) for p in ob.data.polygons]
        me = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(me)
        return self._add(name, V, F, zone)

    def mesh(self, name, V, F, zone, attrs=None):
        return self._add(name, V, F, zone, attrs)

    def object(self, name, ob, zone):
        """A piece from a Blender mesh object (removed afterwards)."""
        V = mesh_arrays(ob)
        F = [tuple(p.vertices) for p in ob.data.polygons]
        me = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(me)
        return self._add(name, V, F, zone)

    def cloth(self, name, node, h, cuts, keep, tris, thick, zone, symmetric=True, max_edge=0.065):
        """Thin cloth from a SOLID form: polygonize the form (its surface is the cloth's outer
        surface), bisect it along the planar cuts [(point, normal, select(C) -> face mask)],
        delete the faces keep(C) rejects (hems, openings, slits: clean straight edges),
        QEM-decimate to `tris` and give it `thick` thickness inward (rims filled). The thin
        Onion shells of lib.sdf need a grid finer than the cloth is thick; this does not."""
        ob = cloth_object("%s_%s" % (self.sp.id, name), node, h, cuts, keep, tris, thick, symmetric, max_edge)
        return self.object(name, ob, zone)

    def prims(self, name, prims, zone):
        """A lib.remesh.Prims accumulator (its material indices are ignored)."""
        ob = prims.to_object("_tmp_prims", [])
        V = mesh_arrays(ob)
        F = [tuple(p.vertices) for p in ob.data.polygons]
        me = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(me)
        return self._add(name, V, F, zone)

    def build(self, sharp_deg=None):
        V = np.concatenate(self.V)
        # (no Mesh.validate: it may drop polygons and break the zone / piece bookkeeping;
        # degenerate polygons are removed per piece before they are added)
        me = bpy.data.meshes.new(self.sp.id)
        me.from_pydata([tuple(v) for v in V], [], [tuple(f) for f in self.F])
        me.update()
        ob = bpy.data.objects.new(self.sp.id, me)
        bpy.context.scene.collection.objects.link(ob)
        for m in zone_mats(self.sp):
            ob.data.materials.append(m)
        zones = np.array(self.zone, int)
        zid = [z.zone for z in sorted(self.sp.zones, key=lambda z: z.zone)]
        for p, z in zip(ob.data.polygons, zones):
            p.material_index = zid.index(int(z)) if int(z) in zid else 0
            p.use_smooth = True
        if sharp_deg is not None:
            set_sharp(ob, sharp_deg)
        attrs = {}
        for key, lst in self.attrs.items():
            arr = np.full((self.n,) + lst[0][1].shape[1:], np.nan)
            for start, val in lst:
                arr[start:start + len(val)] = val
            attrs[key] = arr
        piece_v = np.zeros(len(V), int)
        start = 0
        for k, Vk in enumerate(self.V):
            piece_v[start:start + len(Vk)] = k
            start += len(Vk)
        assert len(ob.data.vertices) == len(V), "mesh_object changed the vertex count"
        assert len(ob.data.polygons) == len(zones), "mesh_object changed the polygon count"
        bt = Built(ob, zones, np.array(self.piece, int), piece_v, self.names, attrs)
        bt.sp = self.sp
        return bt


def _centroids(bm):
    return np.array([f.calc_center_median() for f in bm.faces], float)


def bisect(ob, planes):
    """Cuts the mesh along planes [(point, normal, select(C) -> bool per face)]: only the
    selected faces (by centroid) are cut."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for co, no, sel in planes:
        bm.faces.ensure_lookup_table()
        pick = np.asarray(sel(_centroids(bm)), bool)
        faces = [f for f, k in zip(bm.faces, pick) if k]
        if not faces:
            continue
        geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=tuple(co), plane_no=tuple(nrm(no)),
                               clear_inner=False, clear_outer=False)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def delete_faces(ob, drop):
    """Deletes the faces whose centroid drop(C) marks (and loose vertices)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    kill = np.asarray(drop(_centroids(bm)), bool)
    bmesh.ops.delete(bm, geom=[f for f, k in zip(bm.faces, kill) if k], context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return int(kill.sum())


def drop_islands(ob, min_faces=40):
    """Removes small disconnected pieces (slivers left by the cuts)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    seen, dead = set(), []
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
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return len(dead)


def solidify(ob, thick, offset=-1.0):
    from lib.remesh import apply_modifiers
    mod = ob.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = thick
    mod.offset = offset
    mod.use_rim = True
    mod.use_even_offset = False          # (even offset shoots vertices out at sharp creases)
    mod.use_quality_normals = True
    mod.thickness_clamp = 1.0
    apply_modifiers(ob)


def split_long_edges(ob, node, max_edge, rounds=4):
    """Splits edges longer than max_edge (QEM leaves long slivers on flat cloth, which skin
    badly across a weight gradient), projecting the new vertices onto the form `node`."""
    import bmesh
    from lib.sdf import project_to_surface
    for _ in range(rounds):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        long_e = [e for e in bm.edges if e.calc_length() > max_edge]
        if not long_e:
            bm.free()
            break
        n0 = len(bm.verts)
        bmesh.ops.subdivide_edges(bm, edges=long_e, cuts=1, use_grid_fill=False)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.verts.ensure_lookup_table()
        new = [v for v in bm.verts[n0:]]
        if new and node is not None:
            P = project_to_surface(node, np.array([v.co for v in new], float), 0.004, iters=3)
            for v, p in zip(new, P):
                v.co = p
        bm.to_mesh(ob.data)
        bm.free()
    ob.data.update()


def fix_nonmanifold(ob):
    """Surface nets can fuse two sheets where a form nearly touches itself (the armpit):
    deletes the faces round edges with more than two faces and fills the small holes."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bad = [e for e in bm.edges if len(e.link_faces) > 2]
    n = len(bad)
    if bad:
        faces = list({f for e in bad for v in e.verts for f in v.link_faces})
        bmesh.ops.delete(bm, geom=faces, context="FACES_ONLY")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=12)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return n


def relax(ob, node, iters=3, alpha=0.5):
    """Tangential Laplacian relaxation of the interior vertices, re-projected onto the form
    (removes the little creases QEM leaves where two blended surfaces meet); boundary
    vertices (hems, slits) stay."""
    from lib.sdf import project_to_surface
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    fixed = np.array([v.is_boundary for v in bm.verts])
    bm.free()
    V = mesh_arrays(ob)
    E = mesh_adjacency(ob)
    deg = np.bincount(E.ravel(), minlength=len(V)).astype(float)
    for _ in range(iters):
        acc = np.zeros_like(V)
        np.add.at(acc, E[:, 0], V[E[:, 1]])
        np.add.at(acc, E[:, 1], V[E[:, 0]])
        Vn = V + alpha * (acc / np.maximum(deg, 1)[:, None] - V)
        Vn[fixed] = V[fixed]
        Vn[~fixed] = project_to_surface(node, Vn[~fixed], 0.003, iters=2)
        V = Vn
    ob.data.vertices.foreach_set("co", V.astype(np.float32).ravel())
    ob.data.update()


def cloth_object(name, node, h, cuts, keep, tris, thick, symmetric=True, max_edge=0.065):
    from lib.remesh import apply_modifiers, check_manifold
    from lib.sdf import polygonize, project_to_surface
    V, Q = polygonize(node, h, name)
    ob = mesh_object(name, V, Q, material("_tmp_piece", "#888888"))
    nonman = fix_nonmanifold(ob)
    bisect(ob, cuts)
    n = delete_faces(ob, lambda C: ~np.asarray(keep(C), bool))
    k = drop_islands(ob)
    decimate(ob, tris, symmetric=symmetric)
    split_long_edges(ob, node, max_edge)
    relax(ob, node)
    for p in ob.data.polygons:
        p.use_smooth = True
    solidify(ob, thick)
    log("  %-12s cloth: %d non-manifold edges fixed, %d faces cut away, %d in islands, %d tris after solidify"
        % (name, nonman, n, k, tri_count(ob)))
    return ob


class Built:
    def __init__(self, ob, zones, piece, piece_v, names, attrs):
        self.ob, self.zones, self.piece, self.piece_v, self.names, self.attrs = ob, zones, piece, piece_v, names, attrs
        self.V = mesh_arrays(ob)

    def set_zones(self, zones):
        """New zone per polygon (also the preview material slot)."""
        self.zones = np.asarray(zones, int)
        zid = sorted(z.zone for z in self.sp.zones) if hasattr(self, "sp") else None
        for p, z in zip(self.ob.data.polygons, self.zones):
            p.material_index = zid.index(int(z)) if zid and int(z) in zid else int(z)

    def vmask(self, *names):
        ids = [self.names.index(n) for n in names if n in self.names]
        return np.isin(self.piece_v, ids)

    def pmask(self, *names):
        ids = [self.names.index(n) for n in names if n in self.names]
        return np.isin(self.piece, ids)

    def zone_vmask(self, *zones):
        m = np.zeros(len(self.V), bool)
        for p, z in zip(self.ob.data.polygons, self.zones):
            if int(z) in zones:
                m[list(p.vertices)] = True
        return m


def sheet(P, thick, closed_u=False, normals=None, offset=0.0):
    """Solid sheet from a grid of mid-surface points P (nv, nu, 3) (rows = v, down the
    garment; columns = u, across): two layers `thick` apart along the grid normal (the
    outer one on the side of `normals`, or of the grid's own normal), rims filled.
    Returns V, F, and per-vertex (i, j, side) indices for attributes."""
    P = np.asarray(P, float)
    nv, nu, _ = P.shape
    du = np.gradient(P, axis=1)
    if closed_u:
        du = np.roll(P, -1, 1) - np.roll(P, 1, 1)
    dv = np.gradient(P, axis=0)
    Ng = np.cross(dv, du)
    N = Ng if normals is None else np.broadcast_to(np.asarray(normals, float), P.shape)
    N = N / np.maximum(np.linalg.norm(N, axis=-1, keepdims=True), 1e-12)
    flip = float((N * Ng).sum()) < 0.0          # faces must wind toward N (outward)
    top = P + N * (thick * 0.5 + offset)
    bot = P - N * (thick * 0.5 - offset)
    V = np.concatenate([top.reshape(-1, 3), bot.reshape(-1, 3)])
    nb = nv * nu
    idx = lambda i, j, s: s * nb + i * nu + (j % nu)
    F = []
    ju = nu if closed_u else nu - 1
    for i in range(nv - 1):
        for j in range(ju):
            F.append((idx(i, j, 0), idx(i + 1, j, 0), idx(i + 1, j + 1, 0), idx(i, j + 1, 0)))
            F.append((idx(i, j, 1), idx(i, j + 1, 1), idx(i + 1, j + 1, 1), idx(i + 1, j, 1)))
    # rims
    for j in range(ju):
        F.append((idx(0, j, 0), idx(0, j + 1, 0), idx(0, j + 1, 1), idx(0, j, 1)))
        F.append((idx(nv - 1, j, 0), idx(nv - 1, j, 1), idx(nv - 1, j + 1, 1), idx(nv - 1, j + 1, 0)))
    if not closed_u:
        for i in range(nv - 1):
            F.append((idx(i, 0, 0), idx(i, 0, 1), idx(i + 1, 0, 1), idx(i + 1, 0, 0)))
            F.append((idx(i, nu - 1, 0), idx(i + 1, nu - 1, 0), idx(i + 1, nu - 1, 1), idx(i, nu - 1, 1)))
    if flip:
        F = [tuple(reversed(f)) for f in F]
    I, J = np.meshgrid(np.arange(nv), np.arange(nu), indexing="ij")
    ij = np.concatenate([np.stack([I.ravel(), J.ravel(), np.zeros(nb, int)], 1),
                         np.stack([I.ravel(), J.ravel(), np.ones(nb, int)], 1)])
    return V, F, ij


def grid_metrics(P, closed_u=False):
    """Arc lengths of a grid: u (across, per row, centred) and v (down, per column) in metres."""
    P = np.asarray(P, float)
    du = np.linalg.norm(np.diff(P, axis=1), axis=-1)
    u = np.concatenate([np.zeros((P.shape[0], 1)), np.cumsum(du, 1)], 1)
    u = u - u[:, [u.shape[1] // 2]]
    dv = np.linalg.norm(np.diff(P, axis=0), axis=-1)
    v = np.concatenate([np.zeros((1, P.shape[1])), np.cumsum(dv, 0)], 0)
    return u, v


def sheet_piece(b, name, P, thick, zone, closed_u=False, normals=None, d_side=None, extra_attrs=None):
    """Adds a solid sheet (see sheet()) to the Builder `b` with attributes: uv (u across,
    v down, metres), edge = (distance from the lower edge (last row), distance from the
    side edges (first / last column; 1 m for a closed sheet)); per-vertex i, j."""
    P = np.asarray(P, float)
    V, F, ij = sheet(P, thick, closed_u=closed_u, normals=normals)
    u, v = grid_metrics(P, closed_u)
    uu = u[ij[:, 0], ij[:, 1]]
    vv = v[ij[:, 0], ij[:, 1]]
    d_low = v[-1][ij[:, 1]] - vv
    if closed_u:
        d_sd = np.ones(len(V))
    elif d_side is not None:
        d_sd = np.asarray(d_side)[ij[:, 0], ij[:, 1]]
    else:
        d_sd = np.minimum(uu - u[ij[:, 0], 0], u[ij[:, 0], -1] - uu)
    attrs = {"uv": np.stack([uu, vv], 1), "edge": np.stack([d_low, d_sd], 1),
             "ij": ij.astype(float), "sheet": np.ones(len(V))}
    if closed_u:
        per = np.linalg.norm(np.diff(np.concatenate([P, P[:, :1]], 1), axis=1), axis=-1).sum(1)
        attrs["uwrap"] = per[ij[:, 0]]
    for k, val in (extra_attrs or {}).items():
        attrs[k] = np.asarray(val)[ij[:, 0], ij[:, 1]]
    return b.mesh(name, V, F, zone, attrs)


# ---------------------------------------------------------------------------
# UVs (metres, grain-aligned)
# ---------------------------------------------------------------------------
class Cyl:
    """u = angle x the vertex's own distance from the a -> b axis, v = v0 + distance along
    it (down when `down` is set). The seam (angle +-pi) is opposite `ref`."""

    def __init__(self, a, b, ref, v0=0.0, down=False, rmin=0.01):
        self.a = np.asarray(a, float)
        self.d = nrm(np.asarray(b, float) - self.a)
        r = np.asarray(ref, float)
        r = r - self.d * (r @ self.d)
        self.x = nrm(r)
        self.y = np.cross(self.d, self.x)
        self.v0, self.rmin, self.down = float(v0), float(rmin), down

    def map(self, P):
        q = P - self.a
        along = q @ self.d
        perp = q - along[:, None] * self.d[None, :]
        r = np.maximum(np.linalg.norm(perp, axis=1), self.rmin)
        ang = np.arctan2(perp @ self.y, perp @ self.x)
        return ang, r, self.v0 + (-along if self.down else along)


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


def loop_uvs(ob, maps, part_of_poly, vertex_uv=None, vertex_uwrap=None):
    """Per-loop (u, v) in metres: polygon p mapped by maps[part_of_poly[p]]; part -1 takes
    `vertex_uv` (per-vertex, e.g. a sheet's own u, v)."""
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
    if vertex_uv is not None:
        sel = np.nonzero(part < 0)[0]
        uv[sel] = np.nan_to_num(np.asarray(vertex_uv)[lv[sel]])
        if vertex_uwrap is not None:
            # closed sheets: the polygons across the seam get u + the row's perimeter on
            # their low side, so no polygon spans the whole texture
            wrap = np.asarray(vertex_uwrap)[lv[sel]]
            polys = lp[sel]
            npoly = len(ob.data.polygons)
            umin = np.full(npoly, np.inf)
            umax = np.full(npoly, -np.inf)
            np.minimum.at(umin, polys, uv[sel, 0])
            np.maximum.at(umax, polys, uv[sel, 0])
            ok = ~np.isnan(wrap)
            span = (umax[polys] - umin[polys]) > 0.5 * np.nan_to_num(wrap, nan=np.inf)
            low = ok & span & (uv[sel, 0] < 0.5 * (umin[polys] + umax[polys]))
            uv[sel[low], 0] += wrap[low]
    return uv


def poly_centers(ob):
    return np.array([p.center for p in ob.data.polygons], float)


def torso_cyl(ctx, ref=(0, 1, 0)):
    """Torso cylinder: seam at the front centre by default (ref = back); u metres around."""
    yc = ctx.K["spineb"][1]
    return Cyl((0, yc, 1.2), (0, yc, 0.0), ref)


def arm_cyl(ctx, s, v0=0.0):
    K = ctx.K
    S, W = K.side("shoulder", s), K.side("wrist", s)
    return Cyl(S, W, v3(s, 0, 0.6), v0=v0)            # seam under the arm


def leg_cyl(ctx, s, seam_outside=False):
    K = ctx.K
    H, A = K.side("upper_leg", s), K.side("ankle", s)
    return Cyl(H, A, v3(-s if seam_outside else s, 0, 0))


# ---------------------------------------------------------------------------
# edge distances (CUSTOM0)
# ---------------------------------------------------------------------------
def dist_from(ob, mask, max_d=1.0):
    """Geodesic (edge path) distance of every vertex to the `mask` vertices (m)."""
    src = np.nonzero(np.asarray(mask, bool))[0]
    if not len(src):
        return np.full(len(ob.data.vertices), max_d)
    return edge_distance(ob, src, max_d)


# ---------------------------------------------------------------------------
# weights
# ---------------------------------------------------------------------------
_SURF = {}


def body_weights_masked(ctx, P, exclude=("hand_l", "hand_r", "head")):
    """Weights of the nearest body point, never on the `exclude` body parts (a sleeve's
    wrist band is closer to the thumb than to the forearm at bind; a collar to the jaw)."""
    body = ctx.body()
    key = ("surf", tuple(exclude))
    if key not in _SURF:
        lab = body.vlab[body.F]
        ok = ~np.isin(lab, list(exclude)).any(1)
        _SURF[key] = WrapSurface(body.V, body.F, allowed=ok)
    surf = _SURF[key]
    tri, bary, _, _ = surf.nearest(np.asarray(P, float))
    return surf.interpolate(body.W, tri, bary)


def body_W(ctx, V, torso=True, exclude=("hand_l", "hand_r", "head")):
    """lib.pipeline.garment_body_weights on points: nearest body point (not on the hands or
    the head); above the waist the torso part (closer to the torso than to an arm) binds
    to the torso only."""
    W = body_weights_masked(ctx, V, exclude) if exclude else body_weights_at(ctx, V)
    if torso:
        sel = V[:, 2] > TORSO_Z[0]
        if sel.any():
            idx = np.nonzero(sel)[0]
            t = (1.0 - sleeve_factor(V[idx], ctx.K)) * smoothstep(TORSO_Z[0], TORSO_Z[1], V[idx, 2])
            Wt = body_weights_at(ctx, V[idx], torso_only=np.ones(len(idx), bool))
            W[idx] = W[idx] * (1 - t[:, None]) + Wt * t[:, None]
    return W


def panel_W(ctx, V, lr_width=0.06, pelvis_z=(0.80, 0.93), angles=(50.0, 90.0, 130.0), cy=0.005, lr_gain=None):
    """Skirt panels: pelvis above pelvis_z[1], the per-leg front / side / back panel
    helpers below pelvis_z[0] by the angle around the body (hat functions at `angles` from
    the front centre), left / right blended over +-lr_width across the centre line (a flap
    in front of both thighs follows both); with lr_gain the blend is linear and never
    fully one-sided: left share 0.5 + lr_gain * clip(x / lr_width, -1, 1)."""
    bi = {b: i for i, b in enumerate(ctx.bones)}
    X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
    wp = smoothstep(pelvis_z[0], pelvis_z[1], Z)
    parts = _hat_split(angle_from_front(X, Y, cy), list(angles))
    if lr_gain is None:
        wl = smoothstep(-lr_width, lr_width, X)
    else:
        wl = 0.5 + lr_gain * np.clip(X / lr_width, -1.0, 1.0)
    W = np.zeros((len(V), len(ctx.bones)))
    W[:, bi["pelvis"]] = wp
    for sd, ws in (("l", wl), ("r", 1 - wl)):
        for k, n in enumerate(("upper_leg_front_helper", "upper_leg_thigh_helper", "upper_leg_rear_helper")):
            W[:, bi[sd + "_" + n]] += (1 - wp) * ws * parts[:, k]
    return W


HAND_BONES = ["wrist", "palm", "pinkya", "pinkyb", "pinkyc", "pinkyd", "thumba", "thumbb", "thumbc",
              "index_metacarpal", "indexa", "indexb", "indexc", "ring_metacarpal", "ringa", "ringb", "ringc",
              "middle_metacarpal", "middlea", "middleb", "middlec"]


def no_hands(ctx, W):
    """Sleeves live on the forearm: the wrist, palm and finger weights (the skin near the
    wrist blends them, so a wrist band would bend with the hand and tear) move to the
    forearm's last twist helper."""
    bi = {b: i for i, b in enumerate(ctx.bones)}
    W = W.copy()
    for sd in "lr":
        cols = [bi[sd + "_" + n] for n in HAND_BONES if sd + "_" + n in bi]
        moved = W[:, cols].sum(1)
        W[:, cols] = 0.0
        W[:, bi[sd + "_forarm_twist_c"]] += moved
    return W


def rigid_W(ctx, n, bone):
    W = np.zeros((n, len(ctx.bones)))
    W[:, ctx.bones.index(bone)] = 1.0
    return W


def set_rigid(ctx, W, mask, bone):
    W = W.copy()
    W[mask] = 0.0
    W[mask, ctx.bones.index(bone)] = 1.0
    return W


def pieces_rigid(ob, W, mask):
    """Every connected piece of the masked vertices moves rigidly (mean weights, 4 bones)."""
    return rigid_islands(W, mesh_adjacency(ob), np.asarray(mask, bool))


def belt_W(ctx, V, zc, keep_legs=False):
    """A belt or sash band: every vertex takes the torso weights of the band's centre line
    (its own x, y at height zc), leg and skirt bones folded into the pelvis, averaged
    along the band and the spine chain limited to two neighbouring bones (legacy belt)."""
    bi = {b: i for i, b in enumerate(ctx.bones)}
    C = V.copy()
    C[:, 2] = zc
    W = body_weights_at(ctx, C, torso_only=np.ones(len(C), bool))
    if not keep_legs:
        legs = [bi[sd + "_" + n] for sd in "lr" for n in
                ("upper_leg", "knee", "upper_leg_front_helper", "upper_leg_thigh_helper", "upper_leg_rear_helper")]
        gone = W[:, legs].sum(1)
        W[:, legs] = 0.0
        W[:, bi["pelvis"]] += gone
    W /= np.maximum(W.sum(1, keepdims=True), 1e-12)
    W = band_smooth(W, C, np.ones(len(C), int))
    return chain_weights(W, np.ones(len(C), bool), ctx.bones)


def smooth(ob, W, iters, alpha=0.5, lock=None):
    return smooth_weights(W, mesh_adjacency(ob), iters, alpha, lock=lock)


def normalize(W):
    return limit_normalize(W)


# ---------------------------------------------------------------------------
# checks: sex shape, coverage (hides_regions), clearance
# ---------------------------------------------------------------------------
def sex_delta(ctx, ob):
    """The `sex` delta the pipeline will write (lib.wrap transfer, 3 smoothing passes)."""
    body = ctx.body()
    V = mesh_arrays(ob)
    surf = WrapSurface(body.V, body.F, shapes=body.shapes)
    b = surf.bind(V)
    return surf.shape_delta(b, "sex", smooth_E=mesh_adjacency(ob), smooth_iters=3)


def _tangents(N):
    a = np.where(np.abs(N[:, 0:1]) < 0.9, np.array([[1.0, 0, 0]]), np.array([[0, 1.0, 0]]))
    t1 = a - N * (a * N).sum(1, keepdims=True)
    t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-12)
    return t1, np.cross(N, t1)


def coverage(ctx, ob, D, regions=None, max_dist=0.15, cone_deg=CONE_DEG):
    """{region: {"normal": share, "cone": share}}: the share of the region's skin samples
    (vertices and triangle centroids) whose normal ray, and whose normal ray plus four rays
    tilted cone_deg, hit the garment; the minimum over the female base and the male fit."""
    body = ctx.body()
    me = ob.data
    me.calc_loop_triangles()
    F = np.array([t.vertices[:] for t in me.loop_triangles], int)
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
            t1, t2 = _tangents(N)
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


def fit_report(ctx, ob, D, mask=None):
    """Clearance of the garment's vertices over the skin at bind (body SDF), female base and
    male fit (the male SDF at the `sex`-shaped garment): min, 5th percentile, and the count
    of vertices inside the skin."""
    V = mesh_arrays(ob)
    sel = np.ones(len(V), bool) if mask is None else np.asarray(mask, bool)
    rep = {}
    for name, d in (("female", peval(body_f(ctx), V[sel])), ("male", peval(body_m(ctx), V[sel] + D[sel]))):
        rep[name] = {"min_mm": round(float(d.min()) * 1000, 2), "p05_mm": round(float(np.percentile(d, 5)) * 1000, 2),
                     "inside_skin": int((d < 0.0).sum())}
    return rep


def settle_regions(ctx, sp, ob, D, hide_candidates, occupy=True):
    """Sets sp.hides_regions (the candidates that pass the cone test on both fits) and
    sp.occupies_regions; stores the numbers in the catalog entry ("coverage")."""
    cov = coverage(ctx, ob, D)
    hides = [r for r in hide_candidates if cov[r]["cone"] >= 0.995]
    dropped = {r: round(cov[r]["cone"], 3) for r in hide_candidates if r not in hides}
    sp.hides_regions = hides
    if occupy:
        sp.occupies_regions = [r for r in RG.REGION_LIST if cov[r]["normal"] >= OCCUPY_SHARE]
    sp.extra["coverage"] = {"method": "rays from the skin: the normal and 4 rays tilted %.0f deg must hit the garment "
                                      "(>= 99.5 %% of samples), on the female base and the male fit" % CONE_DEG,
                            "hidden": hides, "rejected_candidates": dropped,
                            "share": {r: {"normal": round(cov[r]["normal"], 3), "cone": round(cov[r]["cone"], 3)}
                                      for r in RG.REGION_LIST if cov[r]["normal"] > 0.0}}
    log("  %s hides %s" % (sp.id, hides))
    if dropped:
        log("  %s candidates NOT hidden (cone share): %s" % (sp.id, dropped))
    return cov


def finish(ctx, sp, bt, W, uv, hide_candidates=(), edge=None, colors=None, regions=None, fit_mask=None,
           focus=None):
    """Coverage and fit checks, close-up previews (env WOODLANDS_PREVIEW = output folder),
    then the pipeline surface (weights already final)."""
    D = sex_delta(ctx, bt.ob)
    settle_regions(ctx, sp, bt.ob, D, hide_candidates)
    fit = fit_report(ctx, bt.ob, D, fit_mask)
    sp.extra["fit_check"] = fit
    log("  %s clearance at bind: %s" % (sp.id, fit))
    out = os.environ.get("WOODLANDS_PREVIEW")
    if out and focus:
        closeups(ctx, sp, bt.ob, D, focus, out)
    return {"main": Surface(bt.ob, zones=bt.zones, weights=W, uv=uv, edge=edge, colors=colors, regions=regions)}


def closeups(ctx, sp, ob, D, focus, outdir, views=("front34", "side", "back", "front")):
    """Workbench close-ups of the garment (zone colours) on the plain body, female base and
    male fit: focus = (centre, ortho scale). One contact sheet <outdir>/<id>_close.png."""
    from lib import pipeline as PL
    from lib.preview import contact_sheet, render_view, setup_preview_scene
    os.makedirs(outdir, exist_ok=True)
    if "cam" not in PL._PREVIEW:
        ctx.rig.hide_render = True
        ctx.bind_rig().hide_render = True
        PL._PREVIEW["cam"] = setup_preview_scene()
    co = PL._PREVIEW["cam"]
    body = PL.preview_body(ctx)
    hidden = []
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o not in (body, ob) and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    body.hide_render = ob.hide_render = False
    V0 = mesh_arrays(ob)
    shots = []
    center, scale = focus
    for sex in (0.0, 1.0):
        body.data.shape_keys.key_blocks["sex"].value = sex
        ob.data.vertices.foreach_set("co", (V0 + sex * D).astype(np.float32).ravel())
        ob.data.update()
        for v in views:
            p = os.path.join(outdir, "%s_%s_%d.png" % (sp.id, v, int(sex)))
            shots.append(render_view(co, p, v, center=center, scale=scale, res=(520, 520)))
    ob.data.vertices.foreach_set("co", V0.astype(np.float32).ravel())
    ob.data.update()
    body.data.shape_keys.key_blocks["sex"].value = 0.0
    body.hide_render = True
    for o in hidden:
        o.hide_render = False
    contact_sheet(shots, os.path.join(outdir, "%s_close.png" % sp.id), len(views))
    for p in shots:
        os.remove(p)


# ---------------------------------------------------------------------------
# colours (COLOR_0.rgb = baked shading multiplier, a = mask)
# ---------------------------------------------------------------------------
def rgba(c, a=1.0):
    c = np.asarray(c, float)
    out = np.ones((len(c), 4))
    out[:, :3] = c[:, None]
    out[:, 3] = a
    return out


def inner_shade(V, form_node, dark=0.72, depth=0.0006):
    """Darker on the inner side of a shell (the lining side seen under a hem): 1 outside,
    `dark` where the vertex lies inside the shell's mid surface."""
    d = peval(form_node, V)
    return np.where(d < -depth, dark, 1.0)
