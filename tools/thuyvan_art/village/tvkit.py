"""Shared Blender helpers for the Thủy Vân village kit (VILLAGE): the ring kit's Builder idiom
(tools/asset_author/blender/ring_kit.py, which is never edited) grown for painted materials:

* every face carries UVs in tile units (1 UV = the material's tile_m metres, from materials.json), laid along the grain:
  boxes along their longest axis, tubes along their length, roofs along the eave with v up the slope;
* materials are named tvv_<key> (the kit's material keys) and sample textures/<key>.png multiplied by the colour
  attribute "Col";
* bake_vertex_ao() writes "Col" per face corner: RGB = baked occlusion x a top-light gradient (mean about 0.85, clamped
  0.5-1.0, style guide 5.3), A = the mask (cloth pin weight; 1 elsewhere).

Blender coordinates: Z up, a piece's front faces -Y (glTF +Y up: Blender -Y = Godot +Z).
"""

import json
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TEX_DIR = os.path.join(REPO, "assets", "thuyvan", "village", "textures")
MATS = json.load(open(os.path.join(HERE, "materials.json")))["keys"]
PAL = json.load(open(os.path.join(HERE, "palettes.json")))["albedo"]["r1"]
DOUBLE_SIDED = {"flags", "banner_indigo", "banner_ochre", "banner_jade", "cloth_madder", "cloth_bone", "cloth_indigo",
                "cloth_ochre", "cloth_jade", "weave", "paper"}


def hex_lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def tile_of(key):
    m = MATS.get(key, {})
    return 1.0 if m.get("unit_uv") else m.get("tile_m", 2.0)


# ------------------------------------------------------------------------------------------------ materials
def material(key):
    name = "tvv_" + key
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    spec = MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = key not in DOUBLE_SIDED
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    p = os.path.join(TEX_DIR, key + ".png")
    img = bpy.data.images.get(key + ".png") or bpy.data.images.load(p, check_existing=True)
    tex.image = img
    tex.interpolation = "Linear"
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mix.inputs[6])
    nt.links.new(col.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.95)
    bsdf.inputs["Specular IOR Level"].default_value = spec.get("spec", 0.12)
    if "emission" in spec:
        bsdf.inputs["Emission Color"].default_value = hex_lin(spec["emission"]) + (1.0,)
        bsdf.inputs["Emission Strength"].default_value = 0.0
    if key in ("flags", "banner_indigo", "banner_ochre", "banner_jade", "cloth_madder", "paper"):
        bsdf.inputs["Subsurface Weight"].default_value = 0.0
    return m


def flat_material(name, hexcol, rough=0.9):
    """Stand-in materials used only by the render scenes (ground cover, river, foliage puffs), never exported."""
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes.get("Principled BSDF")
        b.inputs["Base Color"].default_value = hex_lin(hexcol) + (1.0,)
        b.inputs["Roughness"].default_value = rough
    return m


# ------------------------------------------------------------------------------------------------ geometry
def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1.0]])


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def frame_from(d, up=(0, 0, 1)):
    """Rotation whose X axis is along d (columns = local axes in world)."""
    d = np.asarray(d, float)
    d = d / max(np.linalg.norm(d), 1e-9)
    up = np.asarray(up, float)
    if abs(np.dot(d, up)) > 0.95:
        up = np.array([0, 1.0, 0]) if abs(d[1]) < 0.9 else np.array([1.0, 0, 0])
    y = np.cross(up, d)
    y /= np.linalg.norm(y)
    z = np.cross(d, y)
    return np.stack([d, y, z], 1)


class Builder:
    """Accumulates faces (with UVs and a per-corner mask) per material key into one bmesh: one kit piece."""

    def __init__(self, name, seed=1):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mask = self.bm.loops.layers.float.new("mask")
        self.mats = []
        self.rng = np.random.default_rng(seed)
        self.empties = []          # (name, location)
        self.colliders = []        # (name, Builder-like list of quads)
        self.T = np.eye(3)         # the placement stack (see at())
        self.t = np.zeros(3)

    def at(self, offset=(0, 0, 0), yaw=0.0, rot=None):
        """Context manager: geometry added inside is placed at `offset`, turned `yaw` radians about Z (UVs unchanged)."""
        bld = self

        class _Ctx:
            def __enter__(self_):
                self_.saved = (bld.T.copy(), bld.t.copy())
                R = rot_z(yaw) if rot is None else np.asarray(rot, float)
                bld.t = bld.T @ np.asarray(offset, float) + bld.t
                bld.T = bld.T @ R
                return bld

            def __exit__(self_, *a):
                bld.T, bld.t = self_.saved
        return _Ctx()

    def X(self, p):
        return self.T @ np.asarray(p, float) + self.t

    def mi(self, key):
        if key not in self.mats:
            self.mats.append(key)
        return self.mats.index(key)

    def _auto_uv(self, pts, key, off):
        P = np.asarray(pts, float)
        n = np.cross(P[1] - P[0], P[2] - P[0])
        if np.linalg.norm(n) < 1e-12 and len(P) > 3:
            n = np.cross(P[2] - P[0], P[3] - P[0])
        a = np.argmax(np.abs(n))
        t = tile_of(key)
        if a == 2:
            uv = P[:, [0, 1]]
        elif a == 0:
            uv = P[:, [1, 2]]
        else:
            uv = P[:, [0, 2]]
        return (uv + off) / t

    def face(self, pts, key, uvs=None, smooth=False, mask=None, off=(0.0, 0.0)):
        vs = [self.bm.verts.new(Vector(tuple(self.X(p)))) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self.mi(key)
        f.smooth = smooth
        if uvs is None:
            uvs = self._auto_uv(pts, key, np.asarray(off))
        for k, lp in enumerate(f.loops):
            lp[self.uv].uv = (float(uvs[k][0]), float(uvs[k][1]))
            lp[self.mask] = 1.0 if mask is None else float(mask[k])
        return f

    def grid(self, P, key, U=None, V=None, smooth=True, flip=False, unit=False, M=None):
        """P: (rows, cols, 3) quad grid; U, V: (rows, cols) in metres (or UV units if `unit`); M: mask per vertex."""
        rows, cols = P.shape[0], P.shape[1]
        t = 1.0 if unit else tile_of(key)
        V_ = [[self.bm.verts.new(Vector(tuple(self.X(P[i, j])))) for j in range(cols)] for i in range(rows)]
        k = self.mi(key)
        for i in range(rows - 1):
            for j in range(cols - 1):
                ij = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
                if flip:
                    ij = ij[::-1]
                f = self.bm.faces.new([V_[a][b] for a, b in ij])
                f.material_index = k
                f.smooth = smooth
                auto = self._auto_uv([P[a, b] for a, b in ij], key, np.zeros(2)) if U is None else None
                for n_, (lp, (a, b)) in enumerate(zip(f.loops, ij)):
                    if U is not None:
                        lp[self.uv].uv = (U[a, b] / t, V[a, b] / t)
                    else:
                        lp[self.uv].uv = tuple(auto[n_])
                    lp[self.mask] = 1.0 if M is None else float(M[a, b])
        return V_

    def box(self, c, s, key, rot=None, grain=None, uv_off=None):
        """A box centred c, size s, rotated by `rot` (3x3); UVs along the `grain` axis (default: the longest)."""
        c, s = np.asarray(c, float), np.asarray(s, float)
        R = np.eye(3) if rot is None else np.asarray(rot, float)
        h = s / 2.0
        g = int(np.argmax(s)) if grain is None else grain
        off = self.rng.uniform(0, 4.0, 2) if uv_off is None else np.asarray(uv_off)
        t = tile_of(key)
        for ax in range(3):
            for sg in (-1, 1):
                o = [i for i in range(3) if i != ax]
                if g in o:
                    ua, va = g, [i for i in o if i != g][0]
                else:
                    ua, va = (o[0], o[1]) if s[o[0]] >= s[o[1]] else (o[1], o[0])
                corners = []
                for (a, b) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    p = np.zeros(3)
                    p[ax] = sg * h[ax]
                    p[o[0]] = a * h[o[0]]
                    p[o[1]] = b * h[o[1]]
                    corners.append(p)
                if sg < 0:
                    corners = corners[::-1]
                # make the winding outward: normal along +ax*sg
                n = np.cross(corners[1] - corners[0], corners[2] - corners[0])
                if n[ax] * sg < 0:
                    corners = corners[::-1]
                uvs = [((p[ua] + h[ua]) / t + off[0], (p[va] + h[va]) / t + off[1]) for p in corners]
                self.face([R @ p + c for p in corners], key, uvs=uvs)

    def beam(self, p0, p1, w, h, key, roll=0.0):
        """A rectangular timber from p0 to p1 (w across, h up), grain along its length."""
        p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
        d = p1 - p0
        R = frame_from(d) @ rot_x(roll)
        self.box((p0 + p1) / 2, (np.linalg.norm(d), w, h), key, rot=R, grain=0)

    def lathe(self, prof, segs, key, base=(0, 0, 0), smooth=True, cap_top=True, cap_bottom=True, ribs=0.0,
              scale_xy=(1.0, 1.0), rot=None):
        """prof: [(r, z)] bottom to top. U around (metres at the mean radius), V along the profile (metres)."""
        b = np.asarray(base, float)
        R = np.eye(3) if rot is None else rot
        rmean = max(np.mean([p[0] for p in prof]), 1e-3)
        circ = 2 * math.pi * rmean
        rows, U, V = [], [], []
        acc = 0.0
        for i, (r, z) in enumerate(prof):
            if i:
                acc += math.hypot(r - prof[i - 1][0], z - prof[i - 1][1])
            ring, ur, vr = [], [], []
            for k in range(segs + 1):
                a = 2.0 * math.pi * k / segs
                rr = r * (1.0 - ribs * (k % 2))
                ring.append(b + R @ np.array([rr * math.cos(a) * scale_xy[0], rr * math.sin(a) * scale_xy[1], z]))
                ur.append(circ * k / segs)
                vr.append(acc)
            rows.append(ring)
            U.append(ur)
            V.append(vr)
        P, U, V = np.array(rows), np.array(U), np.array(V)
        Vv = self.grid(P, key, U, V, smooth=smooth, flip=True)
        k = self.mi(key)
        if cap_bottom and prof[0][0] > 1e-4:
            self.face([P[0, j] for j in range(segs)], key, smooth=False)
        if cap_top and prof[-1][0] > 1e-4:
            self.face([P[-1, j] for j in range(segs)][::-1], key, smooth=False)
        return Vv

    def tube(self, path, radii, segs, key, smooth=True, caps=True, mask=None):
        """A tube along `path` (radius per point). U along the length (m), V around: rope/bamboo map their
        circumference to 1/4 tile (their textures are painted for it); other keys use metres."""
        path = [np.asarray(p, float) for p in path]
        if np.isscalar(radii):
            radii = [radii] * len(path)
        rows, U, V, M = [], [], [], []
        prev_n = None
        acc = 0.0
        t_ = tile_of(key)
        quarter = key in ("rope", "bamboo")
        for i, p in enumerate(path):
            if i:
                acc += float(np.linalg.norm(p - path[i - 1]))
            t = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
            t = t / max(np.linalg.norm(t), 1e-9)
            if prev_n is None:
                n = np.cross(t, [0, 0, 1]) if abs(t[2]) < 0.9 else np.cross(t, [1, 0, 0])
            else:
                n = prev_n - np.dot(prev_n, t) * t     # parallel transport: no twisting
            n = n / max(np.linalg.norm(n), 1e-9)
            prev_n = n
            bn = np.cross(t, n)
            ring, ur, vr, mr = [], [], [], []
            for k in range(segs + 1):
                a = 2 * math.pi * k / segs
                ring.append(p + radii[i] * (math.cos(a) * n + math.sin(a) * bn))
                ur.append(acc)
                vr.append((0.25 * t_ * k / segs) if quarter else (2 * math.pi * radii[i] * k / segs))
                mr.append(1.0 if mask is None else mask[i])
            rows.append(ring)
            U.append(ur)
            V.append(vr)
            M.append(mr)
        P = np.array(rows)
        self.grid(P, key, np.array(U), np.array(V), smooth=smooth, M=np.array(M))
        if caps:
            self.face([P[0, j] for j in range(segs)][::-1], key)
            self.face([P[-1, j] for j in range(segs)], key)

    def cylinder(self, c, r, h, segs, key, smooth=True):
        c = np.asarray(c, float)
        self.tube([c, c + [0, 0, h]], [r, r], segs, key, smooth=smooth)

    def pebble(self, c, size, key, rot=None, segs=6, rings=4, squash=1.0):
        """A rounded stone: a low UV sphere scaled to `size` (sx, sy, sz)."""
        c = np.asarray(c, float)
        R = np.eye(3) if rot is None else rot
        sx, sy, sz = size
        rows, U, V = [], [], []
        for i in range(rings + 1):
            th = math.pi * i / rings
            ring, ur, vr = [], [], []
            for k in range(segs + 1):
                a = 2 * math.pi * k / segs
                p = np.array([math.sin(th) * math.cos(a) * sx, math.sin(th) * math.sin(a) * sy,
                              -math.cos(th) * sz * (squash if i < rings / 2 else 1.0)])
                ring.append(c + R @ p)
                ur.append(a * (sx + sy) / 2)
                vr.append(th * sz)
            rows.append(ring)
            U.append(ur)
            V.append(vr)
        self.grid(np.array(rows), key, np.array(U) + self.rng.uniform(0, 3), np.array(V) + self.rng.uniform(0, 3),
                  smooth=True, flip=True)

    def empty(self, name, loc):
        self.empties.append((name, tuple(self.X(loc))))

    def collider(self, name, quads):
        """quads: list of 4-point faces; exported as a child mesh `<name>-colonly` (Godot: static trimesh)."""
        self.colliders.append((name, [[self.X(p) for p in q] for q in quads]))

    def obj(self, collection=None):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(material(m))
        ob = bpy.data.objects.new(self.name, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        for nm, loc in self.empties:
            e = bpy.data.objects.new(nm, None)
            e.empty_display_size = 0.3
            e.location = loc
            e.parent = ob
            (collection or bpy.context.scene.collection).objects.link(e)
        for nm, quads in self.colliders:
            bm = bmesh.new()
            for q in quads:
                bm.faces.new([bm.verts.new(Vector(tuple(p))) for p in q])   # already placed (see collider)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
            cm = bpy.data.meshes.new(nm + "-colonly")
            bm.to_mesh(cm)
            bm.free()
            co = bpy.data.objects.new(nm + "-colonly", cm)
            co.parent = ob
            co.display_type = "WIRE"
            co.hide_render = True
            (collection or bpy.context.scene.collection).objects.link(co)
        return ob


# ------------------------------------------------------------------------------------------------ baked vertex AO
def _hemi_dirs(n=24):
    """Fixed cosine-weighted hemisphere directions about +Z (Fibonacci spiral): deterministic AO."""
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        u = (i + 0.5) / n
        r = math.sqrt(u)
        a = i * ga
        out.append((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1 - u))))
    return np.array(out)


HEMI = _hemi_dirs(24)


def bake_vertex_ao(ob, dist=2.0, ground=True, strength=0.9, extra=None):
    """Write the colour attribute "Col" (corner domain): RGB = AO x top light (style guide 5.3), A = the mask layer.
    `extra`: other objects whose geometry occludes too (e.g. the cliff a house hangs on)."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    trees = [BVHTree.FromBMesh(bm)]
    for e in extra or []:
        b2 = bmesh.new()
        b2.from_mesh(e.data)
        b2.transform(e.matrix_world)
        trees.append(BVHTree.FromBMesh(b2))
        b2.free()
    zs = [v.co.z for v in bm.verts]
    zmin, zmax = min(zs), max(zs)
    zr = max(min(zmax - zmin, 6.0), 0.5)
    mlay = bm.loops.layers.float.get("mask")
    cache = {}
    vals = []
    for f in bm.faces:
        for lp in f.loops:
            n = lp.vert.normal if f.smooth else f.normal
            key = (lp.vert.index, round(n.x, 2), round(n.y, 2), round(n.z, 2))
            if key not in cache:
                nn = np.array(n)
                if np.linalg.norm(nn) < 1e-6:
                    nn = np.array([0, 0, 1.0])
                R = frame_from(nn)        # columns: X along n
                R = R[:, [1, 2, 0]]       # local Z = n
                p = lp.vert.co + Vector(tuple(nn * 0.025))
                occ = 0.0
                for d in HEMI:
                    w = Vector(tuple(R @ d))
                    best = dist
                    for tr in trees:
                        hit = tr.ray_cast(p, w, dist)
                        if hit[0] is not None:
                            best = min(best, hit[3])
                    if ground and w.z < -1e-3 and p.z > -0.05:
                        tg = (p.z + 0.0) / -w.z
                        best = min(best, tg)
                    if best < dist:
                        occ += 1.0 - (best / dist) ** 0.7
                ao = 1.0 - strength * occ / len(HEMI)
                hz = (lp.vert.co.z - zmin) / zr
                top = 0.62 + 0.28 * min(hz, 1.0) + 0.10 * (0.5 + 0.5 * nn[2])
                cache[key] = 0.7 * ao + 0.3 * top
            vals.append(cache[key])
    vals = np.array(vals)
    vals = np.clip(vals + (0.86 - vals.mean()) * 0.6, 0.5, 1.0)
    if "Col" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["Col"])
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    data = np.zeros((len(vals), 4), np.float32)
    data[:, 0] = data[:, 1] = data[:, 2] = vals
    i = 0
    masks = []
    for f in bm.faces:
        for lp in f.loops:
            masks.append(lp[mlay] if mlay else 1.0)
    data[:, 3] = masks
    bm.free()
    ca.data.foreach_set("color", data.ravel())
    me.color_attributes.active_color = ca
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    return float(vals.mean())


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def export_glb(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    for ch in ob.children_recursive:
        ch.hide_set(False)
        ch.select_set(True)
    bpy.context.view_layer.objects.active = ob
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
              export_animations=False, export_skins=False, export_morph=False, export_image_format="JPEG",
              export_jpeg_quality=92, export_extras=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(export_colors=True, **kw)
