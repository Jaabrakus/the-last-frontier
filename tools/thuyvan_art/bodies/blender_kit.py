"""Blender helpers of the body-kit grey-box build: armatures with extension bones, posing from numpy globals, mesh
objects, weights to vertex groups, painted AO into COLOR_0, materials. Imported by build_greybox.py and
render_bodies.py (inside Blender only)."""

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

from lib.remesh import decimate, link, mesh_arrays, srgb, tri_count
from lib.weights import write_groups
from skeleton import Joints


# ===========================================================================
# Armature
# ===========================================================================
def make_armature(name, Jk, kit=()):
    """Armature whose rest IS the given globals (null-add for Actor_B bones, the table positions for the kit's),
    every Actor_B bone in rig order followed by the kit bones in table order."""
    arm = bpy.data.armatures.new(name + "_arm")
    rig = link(bpy.data.objects.new(name, arm))
    bpy.context.view_layer.update()
    for o in bpy.context.view_layer.objects:
        if o is not None:
            o.select_set(o is rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    kids = {}
    for n in Jk.order:
        kids.setdefault(Jk.parent.get(n), []).append(n)
    ebs = {}
    tails = getattr(Jk, "tails", {})
    for n in Jk.order:
        eb = arm.edit_bones.new(n)
        if n in tails:
            L = max(float(np.linalg.norm(tails[n] - Jk.G[n][:3, 3])), 0.01)
        else:
            L = 0.03
            if kids.get(n):
                L = float(np.clip(np.linalg.norm(Jk.G[kids[n][0]][:3, 3] - Jk.G[n][:3, 3]), 0.01, 0.15))
        eb.head, eb.tail = (0, 0, 0), (0, L, 0)
        eb.matrix = Matrix(Jk.G[n].tolist())
        eb.use_connect = False
        eb.use_deform = True
        p = Jk.parent.get(n)
        if p is not None:
            eb.parent = ebs[p]
        ebs[n] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["kit_bones"] = list(kit)
    return rig


def joints_from_armature(rig):
    G, parents, order = {}, {}, []
    tails = {}
    for b in rig.data.bones:
        G[b.name] = np.array(b.matrix_local, float)
        parents[b.name] = b.parent.name if b.parent else None
        order.append(b.name)
        tails[b.name] = np.array(b.tail_local, float)
    J = Joints(G, parents, order)
    kit = list(rig.get("kit_bones", []))
    J.tails = {n: tails[n] for n in kit}
    J.kit = kit
    return J


def apply_pose(rig, Jk, Gp, helpers=True):
    """Pose bones from posed globals (numpy 4x4, armature space); the driven helpers as the game drives them."""
    Gp = dict(Gp)
    if helpers:
        try:
            from lib.helpers import drive_helpers
            Gpm = {n: Matrix(m.tolist()) for n, m in Gp.items()}
            Gbm = {n: Matrix(Jk.G[n].tolist()) for n in Jk.order}
            for n, m in drive_helpers(Gpm, Gbm).items():
                Gp[n] = np.array(m, float)
        except Exception as e:      # noqa: BLE001
            print("helper drive skipped:", e)
    inv = {}
    for n in Jk.order:
        pb = rig.pose.bones[n]
        p = Jk.parent.get(n)
        if p is None:
            B = np.linalg.inv(Jk.G[n]) @ Gp[n]
        else:
            if p not in inv:
                inv[p] = np.linalg.inv(Gp[p])
            rel = np.linalg.inv(Jk.G[p]) @ Jk.G[n]
            B = np.linalg.inv(rel) @ inv[p] @ Gp[n]
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = Matrix(B.tolist())
    bpy.context.view_layer.update()


def rest_pose(rig):
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


# ===========================================================================
# Meshes
# ===========================================================================
def mesh(name, V, F, mat=None, smooth=True):
    me = bpy.data.meshes.new(name)
    V = np.asarray(V, float)
    F = np.asarray(F, np.int64)
    me.vertices.add(len(V))
    me.vertices.foreach_set("co", V.astype(np.float32).ravel())
    me.loops.add(len(F) * 3)
    me.loops.foreach_set("vertex_index", F.astype(np.int32).ravel())
    me.polygons.add(len(F))
    me.polygons.foreach_set("loop_start", (np.arange(len(F)) * 3).astype(np.int32))
    me.polygons.foreach_set("loop_total", np.full(len(F), 3, np.int32))
    me.update(calc_edges=True)
    me.validate(clean_customdata=False)
    if smooth:
        me.polygons.foreach_set("use_smooth", np.ones(len(me.polygons), bool))
    ob = link(bpy.data.objects.new(name, me))
    if mat is not None:
        me.materials.append(mat)
    return ob


def tris_of(ob):
    me = ob.data
    me.calc_loop_triangles()
    T = np.empty(len(me.loop_triangles) * 3, np.int32)
    me.loop_triangles.foreach_get("vertices", T)
    return T.reshape(-1, 3).astype(np.int64)


def reduce(ob, target):
    """QEM decimation to the budget, then a clean-up: degenerate slivers dissolved, faces re-triangulated, normals
    made consistent (outward), so the baked AO and the shading have no flecks."""
    if tri_count(ob) > target:
        decimate(ob, target, None, 0, False)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.validate(clean_customdata=False)
    ob.data.update()
    ob.data.polygons.foreach_set("use_smooth", np.ones(len(ob.data.polygons), bool))
    return ob


def set_weights(ob, W, bones):
    return write_groups(ob, np.asarray(W, float), list(bones))


def read_groups(ob, bones):
    W = np.zeros((len(ob.data.vertices), len(bones)))
    bi = {b: i for i, b in enumerate(bones)}
    gi = {g.index: bi.get(g.name) for g in ob.vertex_groups}
    for v in ob.data.vertices:
        for g in v.groups:
            j = gi.get(g.group)
            if j is not None:
                W[v.index, j] = g.weight
    return W


def bind(ob, rig):
    ob.parent = rig
    m = ob.modifiers.new("Armature", "ARMATURE")
    m.object = rig
    m.use_vertex_groups = True
    return ob


def set_attr(ob, name, values, kind="FLOAT"):
    me = ob.data
    if name in me.attributes:
        me.attributes.remove(me.attributes[name])
    a = me.attributes.new(name, kind, "POINT")
    v = np.asarray(values, np.float32)
    key = {"FLOAT": "value", "FLOAT_VECTOR": "vector", "FLOAT_COLOR": "color"}[kind]
    a.data.foreach_set(key, v.ravel())
    return a


def vertex_normals(ob):
    me = ob.data
    N = np.empty(len(me.vertices) * 3, np.float32)
    try:
        me.vertex_normals.foreach_get("vector", N)
    except AttributeError:
        me.vertices.foreach_get("normal", N)
    return N.reshape(-1, 3).astype(float)


def paint_ao(objs, rays=14, dist=0.22, seed=1):
    """COLOR_0 shading multiplier (lib README): rgb = baked occlusion x top-light gradient, clamped to 0.5-1.0 (style
    guide 5.3), a = 1. Rest pose, all the figure's parts occluding each other. Also stores rest_co / rest_n."""
    Vs, Fs, base = [], [], 0
    for ob in objs:
        V = mesh_arrays(ob)
        F = tris_of(ob)
        Vs.append(V)
        Fs.append(F + base)
        base += len(V)
    Vall = np.concatenate(Vs)
    bvh = BVHTree.FromPolygons([tuple(v) for v in Vall], [tuple(f) for f in np.concatenate(Fs)], epsilon=0.0)
    rng = np.random.RandomState(seed)
    D = rng.randn(rays, 3)
    D /= np.linalg.norm(D, axis=1, keepdims=True)
    for ob in objs:
        V = mesh_arrays(ob)
        N = vertex_normals(ob)
        occ = np.zeros(len(V))
        for i in range(len(V)):
            best = 1.0
            for sgn in (1.0, -1.0):          # two-sided: a vertex whose normal points in still gets its real AO
                n = N[i] * sgn
                p = Vector(V[i] + n * 0.004)
                hit = 0.0
                for d in D:
                    if d @ n < 0:
                        d = -d
                    d = d * 0.7 + n * 0.3
                    loc, _, _, t = bvh.ray_cast(p, Vector(d), dist)
                    if loc is not None and t > 0.006:
                        hit += 1.0 - t / dist * 0.6
                best = min(best, hit / rays)
                if best < 0.35:
                    break
            occ[i] = best
        ao = 1.0 - occ * 1.15
        # smooth over the mesh (painted AO is soft)
        F = tris_of(ob)
        E = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
        for _ in range(3):
            acc = np.zeros(len(V))
            cnt = np.zeros(len(V))
            np.add.at(acc, E[:, 0], ao[E[:, 1]])
            np.add.at(cnt, E[:, 0], 1)
            ao = 0.4 * ao + 0.6 * acc / np.maximum(cnt, 1)
        top = 0.9 + 0.1 * np.clip(N[:, 2], -1, 1)
        rgb = np.clip((0.42 + 0.58 * np.clip(ao, 0, 1)) * top, 0.5, 1.0)
        set_attr(ob, "Color", np.c_[rgb, rgb, rgb, np.ones(len(V))], "FLOAT_COLOR")
        set_attr(ob, "rest_co", V, "FLOAT_VECTOR")
        set_attr(ob, "rest_n", N, "FLOAT_VECTOR")


# ===========================================================================
# Materials
# ===========================================================================
def _nodes(m):
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return nt, bsdf


def _set(bsdf, key, val):
    for k in ([key] if isinstance(key, str) else key):
        if k in bsdf.inputs:
            bsdf.inputs[k].default_value = val
            return


def clay(name, hexcol, rough=0.8, ao=True, mask_attr=None, hex2=None):
    """Grey clay x the painted AO (COLOR_0). With mask_attr/hex2: a second clay where the mask is 1 (extension
    parts in mid grey on the same mesh, the review sheets' convention)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nt, bsdf = _nodes(m)
    col = nt.nodes.new("ShaderNodeRGB")
    col.outputs[0].default_value = (*srgb(hexcol), 1)
    last = col.outputs[0]
    if mask_attr:
        at = nt.nodes.new("ShaderNodeAttribute")
        at.attribute_name = mask_attr
        c2 = nt.nodes.new("ShaderNodeRGB")
        c2.outputs[0].default_value = (*srgb(hex2), 1)
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(at.outputs["Fac"], mix.inputs[0])
        nt.links.new(last, mix.inputs[6])
        nt.links.new(c2.outputs[0], mix.inputs[7])
        last = mix.outputs[2]
    if ao:
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_name = "Color"
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        nt.links.new(last, mul.inputs[6])
        nt.links.new(a.outputs["Color"], mul.inputs[7])
        last = mul.outputs[2]
    nt.links.new(last, bsdf.inputs["Base Color"])
    _set(bsdf, "Roughness", rough)
    _set(bsdf, ["Specular IOR Level", "Specular"], 0.25)
    return m


def image(path, noncolor=False):
    im = bpy.data.images.load(path, check_existing=True)
    if noncolor:
        im.colorspace_settings.name = "Non-Color"
    return im


def triplanar_value(nt, img, tile, sharp=4.0, attr_co="rest_co", attr_n="rest_n", offset=(0, 0, 0)):
    """Value of a tiling map projected on the rest positions from three axes (no seams on SDF meshes without UVs,
    stable under the skin deformation)."""
    co = nt.nodes.new("ShaderNodeAttribute")
    co.attribute_name = attr_co
    no = nt.nodes.new("ShaderNodeAttribute")
    no.attribute_name = attr_n
    sc = nt.nodes.new("ShaderNodeVectorMath")
    sc.operation = "MULTIPLY_ADD"
    nt.links.new(co.outputs["Vector"], sc.inputs[0])
    sc.inputs[1].default_value = (1 / tile, 1 / tile, 1 / tile)
    sc.inputs[2].default_value = offset
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(sc.outputs[0], sep.inputs[0])
    nsep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(no.outputs["Vector"], nsep.inputs[0])
    vals, wts = [], []
    for a, b, wn in (("Y", "Z", "X"), ("X", "Z", "Y"), ("X", "Y", "Z")):
        comb = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(sep.outputs[a], comb.inputs["X"])
        nt.links.new(sep.outputs[b], comb.inputs["Y"])
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Linear"
        nt.links.new(comb.outputs[0], tex.inputs["Vector"])
        ab = nt.nodes.new("ShaderNodeMath")
        ab.operation = "ABSOLUTE"
        nt.links.new(nsep.outputs[wn], ab.inputs[0])
        pw = nt.nodes.new("ShaderNodeMath")
        pw.operation = "POWER"
        nt.links.new(ab.outputs[0], pw.inputs[0])
        pw.inputs[1].default_value = sharp
        vals.append(tex.outputs["Color"])
        wts.append(pw.outputs[0])
    # weighted sum / total
    s01 = nt.nodes.new("ShaderNodeMath")
    s01.operation = "ADD"
    nt.links.new(wts[0], s01.inputs[0])
    nt.links.new(wts[1], s01.inputs[1])
    tot = nt.nodes.new("ShaderNodeMath")
    tot.operation = "ADD"
    nt.links.new(s01.outputs[0], tot.inputs[0])
    nt.links.new(wts[2], tot.inputs[1])
    acc = None
    for v, w in zip(vals, wts):
        bw = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(v, bw.inputs[0])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        nt.links.new(bw.outputs[0], mul.inputs[0])
        nt.links.new(w, mul.inputs[1])
        if acc is None:
            acc = mul.outputs[0]
        else:
            ad = nt.nodes.new("ShaderNodeMath")
            ad.operation = "ADD"
            nt.links.new(acc, ad.inputs[0])
            nt.links.new(mul.outputs[0], ad.inputs[1])
            acc = ad.outputs[0]
    dv = nt.nodes.new("ShaderNodeMath")
    dv.operation = "DIVIDE"
    nt.links.new(acc, dv.inputs[0])
    nt.links.new(tot.outputs[0], dv.inputs[1])
    return dv.outputs[0]


def ramp_node(nt, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    els = r.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    for i, (pos, hx) in enumerate(stops):
        e = els[0] if i == 0 else els.new(pos)
        e.position = pos
        e.color = (*srgb(hx), 1)
    return r


def attr_fac(nt, name):
    a = nt.nodes.new("ShaderNodeAttribute")
    a.attribute_name = name
    return a.outputs["Fac"]


def mix_rgb(nt, fac, a, b, blend="MIX"):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    if isinstance(fac, float):
        m.inputs[0].default_value = fac
    else:
        nt.links.new(fac, m.inputs[0])
    for idx, src in ((6, a), (7, b)):
        if isinstance(src, tuple):
            m.inputs[idx].default_value = src
        else:
            nt.links.new(src, m.inputs[idx])
    return m.outputs[2]


def ao_multiply(nt, col):
    a = nt.nodes.new("ShaderNodeAttribute")
    a.attribute_name = "Color"
    return mix_rgb(nt, 1.0, col, a.outputs["Color"], "MULTIPLY")


def flat_material(name, hexcol, rough=0.8, emission=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nt, bsdf = _nodes(m)
    _set(bsdf, "Base Color", (*srgb(hexcol), 1))
    _set(bsdf, "Roughness", rough)
    _set(bsdf, ["Specular IOR Level", "Specular"], 0.2)
    if emission:
        _set(bsdf, ["Emission Color", "Emission"], (*srgb(hexcol), 1))
        _set(bsdf, "Emission Strength", emission)
    return m


def card_material(name, img_path, rough=0.85, translucent=0.25, tint=None):
    """Alpha-scissor card (style guide 5.2: threshold 0.5), painted colour x AO."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nt, bsdf = _nodes(m)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image(img_path)
    uv = nt.nodes.new("ShaderNodeUVMap")
    nt.links.new(uv.outputs[0], tex.inputs["Vector"])
    col = tex.outputs["Color"]
    if tint:
        col = mix_rgb(nt, 1.0, col, (*srgb(tint), 1), "MULTIPLY")
    nt.links.new(ao_multiply(nt, col), bsdf.inputs["Base Color"])
    gt = nt.nodes.new("ShaderNodeMath")
    gt.operation = "GREATER_THAN"
    nt.links.new(tex.outputs["Alpha"], gt.inputs[0])
    gt.inputs[1].default_value = 0.5
    nt.links.new(gt.outputs[0], bsdf.inputs["Alpha"])
    _set(bsdf, "Roughness", rough)
    _set(bsdf, ["Specular IOR Level", "Specular"], 0.15)
    try:
        m.surface_render_method = "DITHERED"
    except AttributeError:
        m.blend_method = "CLIP"
    try:
        m.use_backface_culling = False
    except AttributeError:
        pass
    return m


def cards(name, centers, normals, size, mat, rng, jitter=0.0, ups=None):
    """Quads (two triangles) facing their normals, with UVs 0..1; normals bent outward by the caller's centre."""
    V, F, UV = [], [], []
    for i, (c, n) in enumerate(zip(centers, normals)):
        n = np.asarray(n, float)
        n = n / np.linalg.norm(n)
        up = np.asarray(ups[i] if ups is not None else (0, 0, 1), float)
        x = np.cross(up, n)
        if np.linalg.norm(x) < 1e-6:
            x = np.cross((0, 1, 0), n)
        x /= np.linalg.norm(x)
        y = np.cross(n, x)
        a = rng.rand() * 2 * math.pi
        x, y = x * math.cos(a) + y * math.sin(a), -x * math.sin(a) + y * math.cos(a)
        s = size * (1 + jitter * (rng.rand() - 0.5))
        b = len(V)
        for du, dv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            V.append(np.asarray(c) + (x * du + y * dv) * s * 0.5)
            UV.append(((du + 1) / 2, (dv + 1) / 2))
        F += [(b, b + 1, b + 2), (b, b + 2, b + 3)]
    ob = mesh(name, np.array(V), np.array(F), mat, smooth=False)
    uvl = ob.data.uv_layers.new(name="UVMap")
    loops = np.array(F).ravel()
    uvl.data.foreach_set("uv", np.array(UV, np.float32)[loops].ravel())
    return ob
