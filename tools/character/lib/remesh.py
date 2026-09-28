"""Blender mesh helpers: objects from arrays, QEM decimation, isotropic remeshing
toward a sizing field (re-projected onto the SDF), manifold checks, primitive
accumulators (Prims), materials.

Split out of tools/character/build_body.py (lib v1). One change: untangle() smooths in
vertex-index order, so builds are deterministic (build_body.py's coat differed run to
run through set iteration order).
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

from .sdf import frame_from, log, nrm, peval, polygonize, project_to_surface, v3

# ===========================================================================
# Blender mesh helpers
# ===========================================================================
def srgb(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def material(name, hexcol, rough=0.85, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    rgb = srgb(hexcol)
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*rgb, 1.0)
    m.roughness = rough
    m.metallic = metal
    return m


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def mesh_object(name, V, F, mat=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in np.asarray(V, float)], [], [tuple(int(i) for i in f) for f in F])
    me.validate(clean_customdata=False)
    me.update()
    ob = link(bpy.data.objects.new(name, me))
    if mat is not None:
        me.materials.append(mat)
    return ob


def apply_modifiers(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    me.name = old.name
    bpy.data.meshes.remove(old)


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def mesh_arrays(ob):
    me = ob.data
    V = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", V)
    return V.reshape(-1, 3)


def set_vertex_group(ob, name, weights):
    vg = ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
    for i, w in enumerate(weights):
        if w > 0:
            vg.add([i], float(w), "REPLACE")
    return vg


def decimate(ob, target_tris, keep=None, keep_factor=4.0, symmetric=True):
    """Collapse-decimate to ~target_tris. `keep` = per-vertex weights (0..1);
    heavier vertices are preserved more."""
    n = tri_count(ob)
    if n <= target_tris:
        return
    mod = ob.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = target_tris / n
    mod.use_collapse_triangulate = True
    mod.use_symmetry = symmetric
    mod.symmetry_axis = "X"
    if keep is not None:
        # Blender scales an edge's collapse cost by 1 + (2 - w1 - w2) * factor:
        # weight 1 decimates normally, low weights are preserved.
        set_vertex_group(ob, "_keep", 1.0 - 0.85 * np.clip(keep, 0.0, 1.0))
        mod.vertex_group = "_keep"
        mod.vertex_group_factor = keep_factor
    apply_modifiers(ob)
    if "_keep" in ob.vertex_groups:
        ob.vertex_groups.remove(ob.vertex_groups["_keep"])


def _bm_arrays(bm):
    bm.verts.index_update()
    V = np.array([v.co for v in bm.verts], float)
    E = np.array([(e.verts[0].index, e.verts[1].index) for e in bm.edges], int)
    return V, E


def _project_verts(node, verts, step_max):
    if not verts:
        return
    P = np.array([v.co for v in verts], float)
    P = project_to_surface(node, P, step_max, iters=2)
    for v, p in zip(verts, P):
        v.co = p


DEBUG_REMESH = False


def _nonman(bm):
    return sum(1 for e in bm.edges if len(e.link_faces) != 2)


def isotropic_remesh(ob, node, sizing, iters=6, feature_deg=50.0, step_max=0.002):
    """Botsch-Kobbelt style remesh toward edge length sizing(P): split long
    edges, collapse short ones, flip toward valence 6, relax tangentially and
    re-project onto the exact SDF surface. Sharp creases are kept."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    cos_feat = math.cos(math.radians(feature_deg))

    def is_feature(e):
        if len(e.link_faces) != 2:
            return True
        return e.link_faces[0].normal.dot(e.link_faces[1].normal) < cos_feat

    for it in range(iters):
        bm.normal_update()
        # --- split long edges
        mids = np.array([(e.verts[0].co + e.verts[1].co) * 0.5 for e in bm.edges], float)
        Lm = sizing(mids)
        lens = np.array([e.calc_length() for e in bm.edges])
        order = np.argsort(-(lens / Lm))
        elist = bm.edges[:]
        long_e = [elist[i] for i in order if lens[i] > 1.333 * Lm[i]]
        newv = []
        for e in long_e:
            # split the edge at its middle and each adjacent triangle toward its
            # opposite corner (all faces stay triangles)
            if not e.is_valid or any(len(f.verts) != 3 for f in e.link_faces):
                continue
            faces = list(e.link_faces)
            opp = [next(v for v in f.verts if v not in e.verts) for f in faces]
            ne, nv = bmesh.utils.edge_split(e, e.verts[0], 0.5)
            for f, o in zip(faces, opp):
                bmesh.utils.face_split(f, nv, o)
            newv.append(nv)
        if DEBUG_REMESH:
            log("    it%d split %d nonmanifold %d" % (it, len(newv), _nonman(bm)))
        _project_verts(node, newv, step_max * 2)
        bm.normal_update()
        # --- collapse short edges
        feat_v = set()
        for e in bm.edges:
            if is_feature(e):
                feat_v.update(e.verts)
        elist = bm.edges[:]
        Le = sizing(np.array([(e.verts[0].co + e.verts[1].co) * 0.5 for e in elist], float))
        ratio = np.array([e.calc_length() for e in elist]) / Le
        batch, locked = [], set()
        for idx in np.argsort(ratio):
            if ratio[idx] >= 0.8:
                break
            e = elist[idx]
            if not e.is_valid:
                continue
            a, b = e.verts
            if a in locked or b in locked:
                continue
            mid = (a.co + b.co) * 0.5
            L = float(Le[idx])
            fa, fb = a in feat_v, b in feat_v
            if fa and fb and not is_feature(e):
                continue
            p = a.co.copy() if (fa and not fb) else (b.co.copy() if (fb and not fa) else mid)
            na = {x.other_vert(a) for x in a.link_edges}
            nb = {x.other_vert(b) for x in b.link_edges}
            common = na & nb
            if len(common) != 2 or len(e.link_faces) != 2:
                continue
            if any(len(c.link_edges) <= 3 for c in common) or len(na) + len(nb) - 4 < 3:
                continue
            if any((n.co - p).length > 1.333 * L for n in (na | nb) - {a, b}):
                continue
            # exact topology check: after merging a, b -> p every edge (p, n) must
            # have exactly two faces and no face may be duplicated
            newf, cnt = set(), {}
            ok = True
            for f in set(a.link_faces) | set(b.link_faces):
                if a in f.verts and b in f.verts:
                    continue
                key = frozenset("p" if (x is a or x is b) else x for x in f.verts)
                if key in newf:
                    ok = False
                    break
                newf.add(key)
                for x in key:
                    if x != "p":
                        cnt[x] = cnt.get(x, 0) + 1
            if not ok or any(c != 2 for c in cnt.values()):
                continue
            for v in (a, b):
                for f in v.link_faces:
                    if a in f.verts and b in f.verts:
                        continue
                    pts = [p if (x is a or x is b) else x.co for x in f.verts]
                    nn = (pts[1] - pts[0]).cross(pts[2] - pts[0])
                    if nn.length < 1e-12 or nn.normalized().dot(f.normal) < 0.3:
                        ok = False
                        break
                if not ok:
                    break
            if not ok:
                continue
            batch.append((e, p))
            locked |= na | nb          # independent set: no two collapses share a one-ring
            if DEBUG_REMESH:
                a.co = p
                b.co = p
                nm0 = sum(1 for x in (na | nb) for ee in x.link_edges if len(ee.link_faces) != 2)
                bmesh.ops.collapse(bm, edges=[e], uvs=False)
                nm1 = sum(1 for x in (na | nb) if x.is_valid for ee in x.link_edges if len(ee.link_faces) != 2)
                if nm1 > nm0:
                    log("    bad collapse: |na|=%d |nb|=%d common=%s vals=%s" % (
                        len(na), len(nb), len(common), [len(c.link_edges) for c in common if c.is_valid]))
        if not DEBUG_REMESH:
            for e, p in batch:
                e.verts[0].co = p
                e.verts[1].co = p
            if batch:
                bmesh.ops.collapse(bm, edges=[e for e, _ in batch], uvs=False)
        if DEBUG_REMESH:
            log("    it%d collapse %d nonmanifold %d" % (it, len(batch), _nonman(bm)))
        bm.normal_update()
        # --- flips toward valence 6 (4 on... closed meshes have no boundary)
        val = {v: len(v.link_edges) for v in bm.verts}
        for e in bm.edges[:]:
            if not e.is_valid or len(e.link_faces) != 2 or is_feature(e):
                continue
            f1, f2 = e.link_faces
            l1 = next(lp for lp in f1.loops if lp.edge == e)
            a, b = l1.vert, l1.link_loop_next.vert          # f1 = (a, b, c) in winding order
            c = l1.link_loop_prev.vert
            d = next(v for v in f2.verts if v is not a and v is not b)
            if c is d or d in {x.other_vert(c) for x in c.link_edges}:
                continue
            before = abs(val[a] - 6) + abs(val[b] - 6) + abs(val[c] - 6) + abs(val[d] - 6)
            after = abs(val[a] - 7) + abs(val[b] - 7) + abs(val[c] - 5) + abs(val[d] - 5)
            if after >= before or val[a] <= 3 or val[b] <= 3:
                continue
            nav = (f1.normal + f2.normal).normalized()
            t1 = (d.co - a.co).cross(c.co - a.co)           # new faces (a, d, c), (d, b, c)
            t2 = (b.co - d.co).cross(c.co - d.co)
            if t1.length < 1e-12 or t2.length < 1e-12:
                continue
            if t1.normalized().dot(nav) < 0.5 or t2.normalized().dot(nav) < 0.5:
                continue
            ne = bmesh.utils.edge_rotate(e, False)
            if ne is not None:
                val[a] -= 1
                val[b] -= 1
                val[c] += 1
                val[d] += 1
        bm.normal_update()
        if DEBUG_REMESH:
            log("    it%d split %d flips done nonmanifold %d  faces %d" % (it, len(long_e), _nonman(bm), len(bm.faces)))
        # --- tangential relaxation + projection
        feat_v = set()
        for e in bm.edges:
            if is_feature(e):
                feat_v.update(e.verts)
        V, E = _bm_arrays(bm)
        N = np.array([v.normal for v in bm.verts], float)
        acc = np.zeros_like(V)
        cnt = np.zeros(len(V))
        np.add.at(acc, E[:, 0], V[E[:, 1]])
        np.add.at(acc, E[:, 1], V[E[:, 0]])
        np.add.at(cnt, E[:, 0], 1)
        np.add.at(cnt, E[:, 1], 1)
        d = acc / np.maximum(cnt, 1)[:, None] - V
        d -= N * (d * N).sum(1)[:, None]
        movable = np.array([v not in feat_v for v in bm.verts])
        V2 = V + 0.6 * d * movable[:, None]
        V2[movable] = project_to_surface(node, V2[movable], step_max, iters=2)
        for v, p in zip(bm.verts, V2):
            v.co = p
    untangle(bm, node, step_max)
    bm.normal_update()
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def _inverted_faces(bm, node):
    bm.normal_update()
    faces = [f for f in bm.faces]
    C = np.array([f.calc_center_median() for f in faces], float)
    Nf = np.array([f.normal for f in faces], float)
    h = 4e-4
    g = np.stack([(peval(node, C + e * h) - peval(node, C - e * h)) / (2 * h) for e in np.eye(3)], 1)
    g /= np.maximum(np.linalg.norm(g, axis=1), 1e-9)[:, None]
    return [f for f, ok in zip(faces, (Nf * g).sum(1) > 0.0) if not ok]


def untangle(bm, node, step_max, rounds=6):
    """Smooth the neighbourhood of faces whose normal opposes the SDF gradient."""
    for _ in range(rounds):
        bad = _inverted_faces(bm, node)
        if not bad:
            return 0
        verts = {v for f in bad for v in f.verts}
        verts |= {x.other_vert(v) for v in list(verts) for x in v.link_edges}
        # in index order: the smoothing is in place (Gauss-Seidel), so iterating the set
        # (ordered by memory address) made builds differ run to run
        bm.verts.index_update()
        verts = sorted(verts, key=lambda v: v.index)
        for v in verts:
            nb = [x.other_vert(v).co for x in v.link_edges]
            v.co = sum(nb, Vector()) / len(nb)
        _project_verts(node, list(verts), step_max)
    return len(_inverted_faces(bm, node))


def set_sharp(ob, deg):
    """Hard shading across creases sharper than `deg` (exported as split normals)."""
    try:
        ob.data.set_sharp_from_angle(angle=math.radians(deg))
    except AttributeError:
        pass


def sdf_object(name, node, h, target_tris, mat, sizing=None, symmetric=True, pre_ratio=2.0, iters=14,
               feature_deg=50.0, sharp_deg=None):
    """Polygonise `node`, reduce with QEM to ~pre_ratio*target, then (if a
    sizing field is given) isotropically remesh."""
    V, Q = polygonize(node, h, name)
    ob = mesh_object(name, V, Q, mat)
    nonman = check_manifold(ob)
    if nonman:
        # surface nets can fuse two sheets at thin gaps / concave CSG corners:
        # rebuild those meshes through OpenVDB (always manifold) and re-project
        mod = ob.modifiers.new("Voxel", "REMESH")
        mod.mode = "VOXEL"
        mod.voxel_size = h * 0.9
        mod.adaptivity = 0.0
        apply_modifiers(ob)
        V2 = project_to_surface(node, mesh_arrays(ob), h * 0.75, iters=3)
        ob.data.vertices.foreach_set("co", V2.ravel())
        ob.data.update()
    decimate(ob, int(target_tris * (pre_ratio if sizing is not None else 1.0)), None, 0, symmetric)
    if sizing is not None:
        isotropic_remesh(ob, node, sizing, iters=iters, feature_deg=feature_deg)
    for p in ob.data.polygons:
        p.use_smooth = True
    if sharp_deg is not None:
        set_sharp(ob, sharp_deg)
    expect = ""
    if sizing is not None:
        A = np.array([p.area for p in ob.data.polygons])
        C = np.array([p.center for p in ob.data.polygons])
        expect = " ~%d at convergence" % int((A / (0.433 * sizing(C) ** 2)).sum())
    log("  %-12s -> %d tris%s (non-manifold edges from surface nets: %d, after: %d)"
        % (name, tri_count(ob), expect, nonman, check_manifold(ob)))
    return ob


def check_manifold(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bad = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    bm.free()
    return bad


# ===========================================================================
# Procedural (non-SDF) parts: eyes, lips, buttons, buckles, horn fittings, hat
# ===========================================================================
class Prims:
    """Accumulates primitive meshes into one bmesh with material indices."""

    def __init__(self):
        self.bm = bmesh.new()

    def _xf(self, verts, center, scale, R, mi):
        M = Matrix.Identity(4)
        R = np.eye(3) if R is None else np.asarray(R, float)
        S = np.diag(scale)
        A = R @ S
        for i in range(3):
            for j in range(3):
                M[i][j] = A[i, j]
            M[i][3] = center[i]
        bmesh.ops.transform(self.bm, matrix=M, verts=verts)
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            f.material_index = mi
            f.smooth = True

    def sphere(self, c, radii, R=None, mi=0, segs=16, rings=10):
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=segs, v_segments=rings, radius=1.0)
        self._xf(r["verts"], c, radii, R, mi)

    def cap(self, c, radius, axis, half_angle_deg, mi=0, segs=20, rings=5):
        """Spherical cap (outward normals) of `radius` around `axis`, up to
        `half_angle_deg` from it: iris discs and eyelids that hug the eyeball."""
        bm = self.bm
        R = frame_from(axis, _perp(axis))
        tip = bm.verts.new(tuple(c + R[:, 2] * radius))
        rows = []
        for i in range(1, rings + 1):
            th = math.radians(half_angle_deg) * i / rings
            row = []
            for j in range(segs):
                ph = 2 * math.pi * j / segs
                d = R @ v3(math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th))
                row.append(bm.verts.new(tuple(c + d * radius)))
            rows.append(row)
        faces = [bm.faces.new((tip, rows[0][j], rows[0][(j + 1) % segs])) for j in range(segs)]
        for i in range(rings - 1):
            for j in range(segs):
                a, b = rows[i][j], rows[i][(j + 1) % segs]
                faces.append(bm.faces.new((a, rows[i + 1][j], rows[i + 1][(j + 1) % segs], b)))
        for f in faces:
            f.material_index = mi
            f.smooth = True

    def cylinder(self, c, axis, radius, length, mi=0, segs=16, r2=None):
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs,
                                  radius1=1.0, radius2=(r2 / radius if r2 else 1.0), depth=1.0)
        self._xf(r["verts"], c, (radius, radius, length), frame_from(axis, _perp(axis)), mi)

    def box(self, c, half, R=None, mi=0):
        r = bmesh.ops.create_cube(self.bm, size=2.0)
        self._xf(r["verts"], c, half, R, mi)
        for f in {f for v in r["verts"] for f in v.link_faces}:
            f.smooth = False

    def frame(self, c, R, w, h, bar, t, mi=0):
        """Rectangular buckle frame in the local xy plane (R columns: x, y, normal)."""
        R = np.asarray(R, float)
        x, y = R[:, 0], R[:, 1]
        self.box(c + y * (h - bar) / 2, (w / 2, bar / 2, t / 2), R, mi)
        self.box(c - y * (h - bar) / 2, (w / 2, bar / 2, t / 2), R, mi)
        self.box(c + x * (w - bar) / 2, (bar / 2, h / 2 - bar, t / 2), R, mi)
        self.box(c - x * (w - bar) / 2, (bar / 2, h / 2 - bar, t / 2), R, mi)
        self.box(c, (bar * 0.35, h / 2 - bar, t * 0.7), R, mi)          # prong / chape

    def to_object(self, name, mats):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        ob = link(bpy.data.objects.new(name, me))
        for m in mats:
            me.materials.append(m)
        return ob


def _perp(a):
    a = nrm(a)
    h = v3(1, 0, 0) if abs(a[0]) < 0.9 else v3(0, 1, 0)
    return nrm(h - a * (h @ a))


def join(objs, name):
    objs = [o for o in objs if o is not None]
    target = objs[0]
    with bpy.context.temp_override(active_object=target, object=target, selected_objects=objs,
                                   selected_editable_objects=objs):
        bpy.ops.object.join()
    target.name = name
    target.data.name = name
    return target
