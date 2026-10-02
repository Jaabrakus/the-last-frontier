"""The animals' low-poly models smoothed (user 2026-10-02, on the smoothed bison: "do that with all the animals that
looks better"). Each source glTF is copied with only its mesh data replaced: every mesh (all its material parts
together) is welded where its faces' corners meet (the UVs and colours stay per corner), given one Catmull-Clark step
in Blender with the UVs left linear (flat palette textures keep their colours) and the skin weights carried along, and
shaded smooth; then it is split back into its material parts and written over the old accessors. The nodes, the skin,
the bones and the clips are the source's own, untouched (a Blender import / export round trip baked the Quaternius
rigs' x100 armature scale into the skinned vertices a second time). The sources are left as they are (their SOURCE.md
records them unmodified); the smoothed copies go to assets/wildlife/smooth/.

    Blender -b --factory-startup --python tools/wildlife/smooth_models.py -- <project dir> [name ...]

The bison is smoothed where it is rigged (tools/wildlife/bison_rig.py smooth()).
"""

import json
import os
import struct
import sys

import bmesh
import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PROJECT = args[0] if args else "."
ONLY = set(args[1:])
OUT_DIR = os.path.join(PROJECT, "assets", "wildlife", "smooth")
SOURCES = {
    "deer": "assets/wildlife/quaternius/deer.glb",
    "stag": "assets/wildlife/quaternius/stag.glb",
    "wolf": "assets/wildlife/quaternius/wolf.glb",
    "fox": "assets/wildlife/quaternius/fox.glb",
    "great_horned_owl": "assets/wildlife/polypizza/great_horned_owl.glb",
    "mammoth": "assets/wildlife/ice_age/mammoth.glb",
}
SUBDIV = 1
WELD = 1e-5               # of the mesh's own size: coincident corners only

_CT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8, 5122: np.int16, 5120: np.int8}
_NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
_NORM = {5121: 255.0, 5123: 65535.0}


def read_glb(path):
    f = open(path, "rb").read()
    n = struct.unpack("<I", f[12:16])[0]
    j = json.loads(f[20:20 + n])
    o = 20 + n
    bl = struct.unpack("<I", f[o:o + 4])[0]
    return j, bytearray(f[o + 8:o + 8 + bl])


def accessor(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = np.dtype(_CT[a["componentType"]])
    nc = _NC[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0) or dt.itemsize * nc
    raw = np.frombuffer(bytes(b[start:start + stride * (a["count"] - 1) + dt.itemsize * nc]), np.uint8)
    out = np.lib.stride_tricks.as_strided(raw.view(np.uint8), (a["count"], dt.itemsize * nc), (stride, 1)).copy()
    arr = out.view(dt).reshape(a["count"], nc)
    if a.get("normalized") and a["componentType"] in _NORM:
        arr = arr.astype(np.float32) / _NORM[a["componentType"]]
    return arr


def add_accessor(j, b, arr, ctype, typ, target=None, minmax=False):
    while len(b) % 4:
        b.append(0)
    data = np.ascontiguousarray(arr.astype(_CT[ctype])).tobytes()
    bv = {"buffer": 0, "byteOffset": len(b), "byteLength": len(data)}
    if target:
        bv["target"] = target
    b.extend(data)
    j["bufferViews"].append(bv)
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ctype, "count": int(len(arr)), "type": typ}
    if minmax:
        a["min"] = [float(v) for v in arr.min(0)]
        a["max"] = [float(v) for v in arr.max(0)]
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def smooth_mesh(j, b, mesh):
    prims = mesh["primitives"]
    names = set(prims[0]["attributes"])
    V, F, FM, corner = [], [], [], {"uv": [], "col": []}
    jw = []
    off = 0
    for k, pr in enumerate(prims):
        at = pr["attributes"]
        P = accessor(j, b, at["POSITION"])
        idx = accessor(j, b, pr["indices"]).reshape(-1, 3)
        V.append(P)
        F += [tuple(int(i) + off for i in t) for t in idx]
        FM += [k] * len(idx)
        corner["uv"].append(accessor(j, b, at["TEXCOORD_0"]) if "TEXCOORD_0" in at else None)
        c = accessor(j, b, at["COLOR_0"]) if "COLOR_0" in at else None
        if c is not None and c.shape[1] == 3:
            c = np.hstack([c, np.ones((len(c), 1), np.float32)])
        corner["col"].append(c)
        if "JOINTS_0" in at:
            jw.append((accessor(j, b, at["JOINTS_0"]).astype(int), accessor(j, b, at["WEIGHTS_0"]).astype(np.float32)))
        off += len(P)
    V = np.concatenate(V).astype(np.float64)
    uv = np.concatenate(corner["uv"]) if corner["uv"][0] is not None else None
    col = np.concatenate(corner["col"]) if corner["col"][0] is not None else None
    me = bpy.data.meshes.new(mesh.get("name", "m"))
    me.from_pydata(V.tolist(), [], F)
    me.polygons.foreach_set("material_index", FM)
    for k in range(len(prims)):
        me.materials.append(bpy.data.materials.new("p%d" % k))
    lv = np.zeros(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    if uv is not None:
        ul = me.uv_layers.new(name="UV")
        ul.data.foreach_set("uv", uv[lv].ravel())
    if col is not None:
        ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
        ca.data.foreach_set("color", col[lv].ravel())
    ob = bpy.data.objects.new(me.name, me)
    bpy.context.scene.collection.objects.link(ob)
    if jw:
        J = np.concatenate([a for a, _ in jw])
        W = np.concatenate([w for _, w in jw])
        for jn in np.unique(J[W > 0]):
            ob.vertex_groups.new(name="j%d" % jn)
        for vi in range(len(V)):
            for jn, w in zip(J[vi], W[vi]):
                if w > 0:
                    ob.vertex_groups["j%d" % jn].add([vi], float(w), 'ADD')
    size = float(np.linalg.norm(V.max(0) - V.min(0)))
    bm = bmesh.new()
    bm.from_mesh(me)
    n0 = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD * size)
    n1 = len(bm.verts)
    bm.to_mesh(me)
    bm.free()
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    sub = ob.modifiers.new("Smooth", 'SUBSURF')
    sub.levels = sub.render_levels = SUBDIV
    sub.uv_smooth = 'NONE'
    sub.boundary_smooth = 'ALL'
    bpy.ops.object.modifier_apply(modifier=sub.name)
    me = ob.data
    me.shade_smooth()
    me.calc_loop_triangles()
    nl = len(me.loops)
    P = np.zeros((len(me.vertices), 3))
    me.vertices.foreach_get("co", P.ravel())
    lv = np.zeros(nl, int)
    me.loops.foreach_get("vertex_index", lv)
    N = np.zeros((nl, 3))
    me.corner_normals.foreach_get("vector", N.ravel())
    keys = [lv[:, None].astype(np.float64)]
    UVl = COl = None
    if uv is not None:
        UVl = np.zeros((nl, 2))
        me.uv_layers["UV"].data.foreach_get("uv", UVl.ravel())
        keys.append(UVl)
    if col is not None:
        COl = np.zeros((nl, 4))
        me.color_attributes["Col"].data.foreach_get("color", COl.ravel())
        keys.append(COl)
    keys.append(N)
    key = np.round(np.hstack(keys), 5)
    uniq, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    tris = np.zeros((len(me.loop_triangles), 3), int)
    me.loop_triangles.foreach_get("loops", tris.ravel())
    tmat = np.zeros(len(me.loop_triangles), int)
    me.loop_triangles.foreach_get("material_index", tmat)
    ov = lv[first]
    out = {"POSITION": P[ov].astype(np.float32), "NORMAL": N[first].astype(np.float32)}
    if UVl is not None:
        out["TEXCOORD_0"] = UVl[first].astype(np.float32)
    if COl is not None:
        out["COLOR_0"] = COl[first].astype(np.float32)
    if jw:
        gi = {g.index: int(g.name[1:]) for g in ob.vertex_groups}
        JJ = np.zeros((len(P), 4), np.uint16)
        WW = np.zeros((len(P), 4), np.float32)
        for v in me.vertices:
            gs = sorted(((g.weight, gi[g.group]) for g in v.groups if g.weight > 0), reverse=True)[:4]
            s = sum(w for w, _ in gs) or 1.0
            for k, (w, jn) in enumerate(gs):
                JJ[v.index, k] = jn
                WW[v.index, k] = w / s
        out["JOINTS_0"] = JJ[ov]
        out["WEIGHTS_0"] = WW[ov]
    # the vertices shared by all the parts, each part its own triangles (as the source)
    acc = {}
    for nm, arr in out.items():
        if nm not in names:
            continue
        if nm == "JOINTS_0":
            acc[nm] = add_accessor(j, b, arr, 5123, "VEC4", 34962)
        else:
            acc[nm] = add_accessor(j, b, arr, 5126, {2: "VEC2", 3: "VEC3", 4: "VEC4"}[arr.shape[1]], 34962,
                                   minmax=(nm == "POSITION"))
    for k, pr in enumerate(prims):
        t = inv[tris[tmat == k]].astype(np.uint32)
        pr["attributes"] = {nm: acc[nm] for nm in pr["attributes"] if nm in acc}
        pr["indices"] = add_accessor(j, b, t.reshape(-1, 1), 5125, "SCALAR", 34963)
    bpy.data.objects.remove(ob, do_unlink=True)
    return n0, n1, len(uniq), len(tris)


def compact(j, b):
    """The binary chunk rebuilt from the buffer views still referenced (the old mesh data dropped)."""
    used = set()
    for a in j["accessors"]:
        if "bufferView" in a:
            used.add(a["bufferView"])
    for im in j.get("images", []):
        if "bufferView" in im:
            used.add(im["bufferView"])
    order = sorted(used)
    remap, nb = {}, bytearray()
    views = []
    for i in order:
        bv = dict(j["bufferViews"][i])
        while len(nb) % 4:
            nb.append(0)
        s = bv.get("byteOffset", 0)
        data = b[s:s + bv["byteLength"]]
        bv["byteOffset"] = len(nb)
        nb.extend(data)
        remap[i] = len(views)
        views.append(bv)
    j["bufferViews"] = views
    for a in j["accessors"]:
        if "bufferView" in a:
            a["bufferView"] = remap[a["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = remap[im["bufferView"]]
    j["buffers"][0]["byteLength"] = len(nb)
    return nb


def write_glb(path, j, b):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(b) % 4:
        b.append(0)
    total = 12 + 8 + len(js) + 8 + len(b)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<I", len(js)) + b"JSON" + js)
        f.write(struct.pack("<I", len(b)) + b"BIN\x00" + bytes(b))


def one(name, src):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    j, b = read_glb(os.path.join(PROJECT, src))
    for m in j["meshes"]:
        n0, n1, nv, nt = smooth_mesh(j, b, m)
        print("SMOOTH %s %s: %d -> %d vertices welded; %d vertices, %d triangles" % (name, m.get("name"), n0, n1, nv, nt))
    nb = compact(j, b)
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, name + ".glb")
    write_glb(out, j, nb)
    print("SMOOTH WROTE", out, "%.2f MB" % (os.path.getsize(out) / 1e6))


def main():
    for name, src in SOURCES.items():
        if ONLY and name not in ONLY:
            continue
        one(name, src)


main()
