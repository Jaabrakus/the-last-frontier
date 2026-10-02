"""Build the procedural Frontier horse: mesh, rig, tack, gait clips -> assets/horse/horse.glb.

Run (about 100 s):
  tools/horse/build_horse.sh                 # glb + coat textures + meta + manifest
  tools/horse/build_horse.sh --previews DIR  # also Eevee stills of the rest pose and gait frames
  tools/horse/build_horse.sh --gaits-only    # skip the glb, print gait diagnostics

Everything here is generated; the tack uses the project's Poly Haven CC0 leather, wool and
hessian textures (1k copies in assets/horse/textures/tack). The gait timing and the saddle bob
come from tools/horse/rider_curves.json, a timing extract of the Actor_B riding clips. No rider
animation data is copied.
"""

import hashlib
import json
import math
import os
import sys
import time

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
# Another animal on the horse's rig (FRONTIER_SPECIES=bison: tools/bison/anatomy.py in place of this folder's, its
# assets in assets/<species>/; no tack, mane or feathers; its horns)
SPECIES = os.environ.get("FRONTIER_SPECIES", "horse")
HORSE = SPECIES == "horse"
if not HORSE:
    sys.path.insert(0, os.path.join(HERE, "..", SPECIES))
sys.dont_write_bytecode = True      # keep tools/horse free of __pycache__

import anatomy as A           # noqa: E402
import blender_util as U      # noqa: E402
import coat                   # noqa: E402
import gait_check as GC       # noqa: E402
import gaits as G             # noqa: E402
import hair as H              # noqa: E402
import sdf                    # noqa: E402
import skinning as SK         # noqa: E402

PROJECT = os.environ.get("FRONTIER_PROJECT") or os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_GLB = os.path.join(PROJECT, "assets", SPECIES, SPECIES + ".glb")
OUT_META = os.path.join(PROJECT, "assets", SPECIES, SPECIES + "_meta.json")
OUT_MANIFEST = os.path.join(PROJECT, "assets", SPECIES, "MANIFEST.json")
TEX_DIR = os.path.join(PROJECT, "assets", SPECIES, "textures")
POLYHAVEN = os.path.join(PROJECT, "assets", "polyhaven", "textures", "clothing")
T0 = time.time()
CLIPS = list(G.CLIP_ORDER)
BODY_H = 0.005             # surface-nets cell of the skin (m)
BODY_TRIS = 26000          # skin triangles after decimation
COAT_RES = 2048            # coat texture size
# Poly Haven CC0 textures used on the tack (1k copies with mipmaps in assets/horse/textures/tack):
# id -> (maps, world size of one texture tile in m)
TACK_TEX = {"brown_leather": 0.28, "poly_wool_herringbone": 0.30, "hessian_230": 0.18}
DUMP_SKIN = None           # --dump-skin PATH: save the skin and its heat weights, then stop


def log(*a):
    print("[%s %6.1fs]" % (SPECIES, time.time() - T0), *a, flush=True)


def args():
    global TEX_DIR, DUMP_SKIN
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"previews": None, "gaits_only": False, "out": OUT_GLB}
    i = 0
    while i < len(a):
        if a[i] == "--previews":
            out["previews"] = a[i + 1]
            i += 1
        elif a[i] == "--gaits-only":
            out["gaits_only"] = True
        elif a[i] == "--out":
            out["out"] = a[i + 1]
            i += 1
        elif a[i] == "--dump-skin":
            DUMP_SKIN = os.path.abspath(a[i + 1])
            out["dump_only"] = True
            i += 1
        i += 1
    if os.path.abspath(out["out"]) != OUT_GLB:
        # a trial build elsewhere writes its coat textures next to it, not into the project
        TEX_DIR = os.path.join(os.path.dirname(os.path.abspath(out["out"])), "textures")
    return out


# ---------------------------------------------------------------------------
# Armature
# ---------------------------------------------------------------------------
def build_armature():
    table = A.bone_table()
    arm = bpy.data.armatures.new("HorseRig")
    ob = U.link(bpy.data.objects.new("Horse", arm))
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent, deform) in table.items():
        eb = arm.edit_bones.new(name)
        eb.head, eb.tail = head, tail
        y = np.subtract(tail, head)
        y = y / np.linalg.norm(y)
        x = np.array([1.0, 0, 0]) - y[0] * y
        if np.linalg.norm(x) < 1e-3:
            x = np.array([0, 1.0, 0]) - y[1] * y
        x /= np.linalg.norm(x)
        eb.align_roll(tuple(np.cross(x, y)))
        eb.use_deform = deform
        eb.use_connect = False
    for name, (head, tail, parent, deform) in table.items():
        if parent:
            arm.edit_bones[name].parent = arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    rest = {b.name: np.array(b.matrix_local) for b in arm.bones}
    return ob, rest


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
def poly(name, node, h, mat, target, symmetric=True):
    V, Q = sdf.polygonize(node, h, symmetric_x=symmetric)
    Q = orient_outward(node, V, Q, name)
    ob = U.mesh_object(name, V, Q, mat)
    U.fix_normals(ob, recalc=False)
    U.decimate(ob, target, symmetric)
    return ob


def orient_outward(node, V, Q, name=""):
    """Flip every quad whose normal disagrees with the SDF gradient (outward). Surface
    nets on thin parts give non-manifold spots where a topological normal fix fails."""
    a, b, c, d = (V[Q[:, i]] for i in range(4))
    n = np.cross(c - a, d - b)
    ctr = (a + b + c + d) * 0.25
    g = sdf.gradient(node, ctr)
    flip = (n * g).sum(1) < 0
    Q = Q.copy()
    Q[flip] = Q[flip][:, ::-1]
    log("  %-14s %6d quads, %5d flipped to the SDF gradient" % (name, len(Q), int(flip.sum())))
    return Q


def build_meshes():
    mats = {
        "coat": U.material("horse_coat", "#7a4527", 0.62),
        "hoof": U.material("horse_hoof", "#2b2520", 0.45),
        "hair": U.material("horse_hair", "#1a1411", 0.75),
        "eye": U.material("horse_eye", "#120c0a", 0.05),
        "leather": U.material("tack_leather", "#5a3520", 0.55),
        "bridle": U.material("tack_bridle", "#3a2416", 0.55),
        "cloth": U.material("tack_cloth", "#7a2320", 0.92),
        "girth": U.material("tack_girth", "#8a7650", 0.9),
        "iron": U.material("tack_iron", "#454545", 0.38, 0.85),
    }
    parts = {}
    body_node = A.horse_body()
    ob = poly("HorseBody", body_node, BODY_H, mats["coat"], BODY_TRIS)
    uv_unwrap(ob, margin=0.002)
    parts["HorseBody"] = ob
    log("body", U.tri_count(ob), "tris")
    # hooves
    Vs, Fs, UVs, off = [], [], [], 0
    for s in ("l", "r"):
        for hind in (False, True):
            V, F, UV = A.hoof_mesh_detail(s, hind)
            if hasattr(A, "cloven"):
                V, F, UV = A.cloven(V, F, UV, s, hind)
            if s == "r" and hind:
                UV = UV + np.array([2.0, 0.0])      # the hoof under the white sock (horse_hoof.gdshader)
            Vs.append(V)
            UVs.append(UV)
            Fs += [[i + off for i in f] for f in F]
            off += len(V)
    ob = U.mesh_object("Hooves", np.concatenate(Vs), Fs, mats["hoof"])
    set_vertex_uv(ob, np.concatenate(UVs))
    # anatomy.hoof_mesh_detail winds every face outward (the frog is a separate open patch,
    # which a normal recalculation could flip)
    U.fix_normals(ob, recalc=False)
    parts["Hooves"] = ob
    # eyes
    V, F = A.eye_mesh()
    parts["Eyes"] = U.mesh_object("Eyes", V, F, mats["eye"])
    if not HORSE:
        parts["Horns"] = poly("Horns", A.horns(), 0.004, mats["hoof"], 3000)
        for n, o in parts.items():
            log("  %-12s %6d tris" % (n, U.tri_count(o)))
        return parts, mats, body_node
    # hair cards
    for name, cards in (("Mane", H.mane(body_node)), ("Forelock", H.forelock(body_node)), ("Tail", H.tail(body_node))):
        V, F, UV = cards.arrays()
        ob = U.mesh_object(name, V, F, mats["hair"])
        set_vertex_uv(ob, UV)
        parts[name] = ob
    Vs, Fs, UVs, off, groups = [], [], [], 0, {}
    for bone, cards in H.feathers(body_node).items():
        V, F, UV = cards.arrays()
        Vs.append(V)
        UVs.append(UV)
        Fs += [[i + off for i in f] for f in F]
        groups[bone] = list(range(off, off + len(V)))
        off += len(V)
    ob = U.mesh_object("Feathers", np.concatenate(Vs), Fs, mats["hair"])
    set_vertex_uv(ob, np.concatenate(UVs))
    ob["bone_groups"] = json.dumps(groups)
    parts["Feathers"] = ob
    # tack
    tors = A.torso_only()
    parts["Saddle"] = poly("Saddle", A.saddle(tors), 0.006, mats["leather"], 5000)
    parts["SaddleCloth"] = poly("SaddleCloth", A.saddle_cloth(tors), 0.006, mats["cloth"], 1800)
    parts["Girth"] = poly("Girth", A.girth(tors), 0.006, mats["girth"], 600)
    parts["Bridle"] = poly("Bridle", A.bridle(A.head()), 0.004, mats["bridle"], 2200)
    drop_fragments(parts["Bridle"], 40)
    parts["Bit"] = poly("Bit", A.bit(), 0.003, mats["iron"], 500)
    for s in ("l", "r"):
        parts["StirrupLeather_" + s] = poly("StirrupLeather_" + s, A.stirrup_leather(s), 0.004, mats["bridle"], 500,
                                            symmetric=False)
        parts["StirrupIron_" + s] = poly("StirrupIron_" + s, A.stirrup_iron(s), 0.003, mats["iron"], 700,
                                         symmetric=False)
    tile = {"Saddle": TACK_TEX["brown_leather"], "SaddleCloth": TACK_TEX["poly_wool_herringbone"],
            "Girth": TACK_TEX["hessian_230"], "Bridle": TACK_TEX["brown_leather"]}
    for n, o in parts.items():
        if n in tile or n.startswith("Stirrup") or n == "Bit":
            uv_unwrap(o, margin=0.004, world_tile=tile.get(n, TACK_TEX["brown_leather"]))
    for n, o in parts.items():
        log("  %-12s %6d tris" % (n, U.tri_count(o)))
    return parts, mats, body_node


def drop_fragments(ob, min_faces):
    """Delete loose pieces with fewer than min_faces faces (slivers where a thin shell is
    cut by the strap regions)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    seen, kill = set(), []
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
            kill += comp
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    log("  %s: removed %d faces in loose fragments" % (ob.name, len(kill)))


def set_vertex_uv(ob, UV):
    me = ob.data
    uvl = me.uv_layers.new(name="UVMap")
    vi = np.zeros(len(me.loops), int)
    me.loops.foreach_get("vertex_index", vi)
    uvl.data.foreach_set("uv", np.asarray(UV, float)[vi].ravel())


def uv_unwrap(ob, margin=0.003, world_tile=None):
    """Smart UV projection. With world_tile, the UVs are scaled so one texture tile covers
    world_tile metres (tiling tack materials); otherwise they fill 0..1 (baked coat)."""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62), island_margin=margin, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    if not world_tile:
        try:
            bpy.ops.uv.pack_islands(udim_source="CLOSEST_UDIM", rotate=True, rotate_method="ANY", scale=True,
                                    merge_overlap=False, margin_method="FRACTION", margin=margin, pin=False,
                                    shape_method="CONCAVE")
        except TypeError:
            bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    if world_tile:
        me = ob.data
        uv = np.zeros(len(me.loops) * 2)
        me.uv_layers.active.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
        V = U.verts(ob)
        a3 = auv = 0.0
        for p in me.polygons:
            li = list(p.loop_indices)
            vi = [me.loops[i].vertex_index for i in li]
            for k in range(1, len(li) - 1):
                a3 += 0.5 * np.linalg.norm(np.cross(V[vi[k]] - V[vi[0]], V[vi[k + 1]] - V[vi[0]]))
                e1, e2 = uv[li[k]] - uv[li[0]], uv[li[k + 1]] - uv[li[0]]
                auv += 0.5 * abs(e1[0] * e2[1] - e1[1] * e2[0])
        uv *= math.sqrt(a3 / max(auv, 1e-12)) / world_tile
        me.uv_layers.active.data.foreach_set("uv", uv.ravel())


def bake_coat(ob, node):
    """Coat textures (tools/horse/coat.py) for the exported skin mesh, and the samples the
    Godot test uses to check the tangent-space conventions."""
    me = ob.data
    me.calc_loop_triangles()
    me.calc_tangents(uvmap=me.uv_layers.active.name)
    L = len(me.loops)
    tan = np.zeros(L * 3)
    nor = np.zeros(L * 3)
    bs = np.zeros(L)
    uv = np.zeros(L * 2)
    vi = np.zeros(L, int)
    me.loops.foreach_get("tangent", tan)
    me.loops.foreach_get("normal", nor)
    me.loops.foreach_get("bitangent_sign", bs)
    me.loops.foreach_get("vertex_index", vi)
    me.uv_layers.active.data.foreach_get("uv", uv)
    tl = np.zeros(len(me.loop_triangles) * 3, int)
    me.loop_triangles.foreach_get("loops", tl)
    tl = tl.reshape(-1, 3)
    V = U.verts(ob)
    imgs, samples = coat.bake(uv.reshape(-1, 2)[tl], V[vi][tl], nor.reshape(-1, 3)[tl], tan.reshape(-1, 3)[tl],
                              bs[tl], node, COAT_RES)
    me.free_tangents()
    os.makedirs(TEX_DIR, exist_ok=True)
    for k, im in imgs.items():
        save_png(os.path.join(TEX_DIR, "horse_coat_%s.png" % k), im)
    atlas = H.strand_atlas()
    save_png(os.path.join(TEX_DIR, "horse_hair_strands.png"), atlas)
    return samples


IMPORT_PARAMS = [
    ("compress/mode", "2"), ("compress/high_quality", "true"), ("compress/lossy_quality", "0.7"),
    ("compress/uastc_level", "0"), ("compress/rdo_quality_loss", "0.0"), ("compress/hdr_compression", "1"),
    ("compress/normal_map", "2"), ("compress/channel_pack", "0"), ("mipmaps/generate", "true"),
    ("mipmaps/limit", "-1"), ("roughness/mode", "0"), ("roughness/src_normal", '""'),
    ("process/channel_remap/red", "0"), ("process/channel_remap/green", "1"), ("process/channel_remap/blue", "2"),
    ("process/channel_remap/alpha", "3"), ("process/fix_alpha_border", "true"), ("process/premult_alpha", "false"),
    ("process/normal_map_invert_y", "false"), ("process/hdr_as_srgb", "false"),
    ("process/hdr_clamp_exposure", "false"), ("process/size_limit", "0"), ("detect_3d/compress_to", "0"),
]


def write_import(path, normal=False, high_quality=True, alpha_is_coverage=False):
    """Godot import settings for a texture: VRAM compressed (BPTC for packed data maps,
    RGTC for normal maps) with mipmaps. An existing .import with other settings is
    replaced and the cached import removed, so the next Godot run re-imports it."""
    want = dict(IMPORT_PARAMS)
    want["compress/normal_map"] = "1" if normal else "2"
    want["compress/high_quality"] = "true" if high_quality and not normal else "false"
    # the alpha of the coat maps is data (white markings, bare skin), not coverage
    want["process/fix_alpha_border"] = "true" if alpha_is_coverage else "false"
    imp = path + ".import"
    uid = None
    if os.path.exists(imp):
        txt = open(imp).read()
        have = dict(l.split("=", 1) for l in txt.splitlines() if "=" in l and not l.startswith(("[", ";")))
        if all(have.get(k) == v for k, v in want.items()):
            return
        uid = have.get("uid")
    lines = ["[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"']
    if uid:
        lines.append("uid=%s" % uid)
    lines += ["", "[params]", ""] + ["%s=%s" % kv for kv in want.items()]
    open(imp, "w").write("\n".join(lines) + "\n")
    cache = os.path.join(PROJECT, ".godot", "imported")
    # only a texture inside the project has a cached import to drop (a trial build writes
    # its textures elsewhere and must not touch the project's cache)
    if os.path.isdir(cache) and os.path.abspath(path).startswith(os.path.join(PROJECT, "assets") + os.sep):
        for f in os.listdir(cache):
            if f.startswith(os.path.basename(path) + "-"):
                os.remove(os.path.join(cache, f))


def save_png(path, img):
    """float RGBA (rows bottom-up, 0..1) -> 8-bit PNG without colour transform."""
    h, w = img.shape[:2]
    write_import(path, normal="normal" in os.path.basename(path), alpha_is_coverage="hair" in os.path.basename(path))
    im = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    im.colorspace_settings.name = "Non-Color"
    im.pixels.foreach_set(np.clip(img, 0, 1).astype(np.float32).ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    log("wrote", os.path.relpath(path, PROJECT))


def tack_textures():
    """1k copies (with Godot mipmaps) of the Poly Haven CC0 tack textures."""
    out = []
    d = os.path.join(PROJECT, "assets", "horse", "textures", "tack")
    os.makedirs(d, exist_ok=True)
    for tid in TACK_TEX:
        for m in ("diffuse", "nor_gl", "arm"):
            src = os.path.join(POLYHAVEN, tid, "%s_%s_2k.jpg" % (tid, m))
            dst = os.path.join(d, "%s_%s_1k.jpg" % (tid, m))
            out.append((src, dst))
            if os.path.exists(dst):
                write_import(dst, normal=(m == "nor_gl"), high_quality=False)
            if os.path.exists(dst) and os.path.getmtime(dst) >= os.path.getmtime(src):
                continue
            im = bpy.data.images.load(src)
            im.colorspace_settings.name = "Non-Color"
            im.scale(1024, 1024)
            im.filepath_raw = dst
            im.file_format = "JPEG"
            bpy.context.scene.render.image_settings.quality = 92
            im.save()
            bpy.data.images.remove(im)
            write_import(dst, normal=(m == "nor_gl"), high_quality=False)
            log("wrote", os.path.relpath(dst, PROJECT))
    return out


# ---------------------------------------------------------------------------
# Weights
# ---------------------------------------------------------------------------
def rigid(ob, bone):
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")


def by_segments(ob, bones, rest, falloff=0.06):
    """Blend weights to the nearest of a chain of bone segments (smooth falloff)."""
    V = U.verts(ob)
    W = []
    for b in bones:
        M = rest[b]
        h = M[:3, 3]
        y = M[:3, 1]
        L = np.linalg.norm(np.array(A.bone_table()[b][1]) - np.array(A.bone_table()[b][0]))
        t = np.clip(((V - h) * y).sum(1), 0, L)
        d = np.linalg.norm(V - (h + t[:, None] * y), axis=1)
        W.append(np.exp(-(d / falloff) ** 2))
    W = np.array(W)
    W /= np.maximum(W.sum(0), 1e-9)
    for i, b in enumerate(bones):
        vg = ob.vertex_groups.new(name=b)
        for vi in np.nonzero(W[i] > 0.01)[0]:
            vg.add([int(vi)], float(W[i, vi]), "REPLACE")


def copy_skin_weights(src, dst):
    from mathutils.kdtree import KDTree
    SV = U.verts(src)
    kd = KDTree(len(SV))
    for i, p in enumerate(SV):
        kd.insert(p, i)
    kd.balance()
    names = {g.index: g.name for g in src.vertex_groups}
    groups = {}
    for i, p in enumerate(U.verts(dst)):
        _, j, _ = kd.find(p)
        for g in src.data.vertices[j].groups:
            n = names[g.group]
            if n not in groups:
                groups[n] = dst.vertex_groups.new(name=n)
            groups[n].add([i], g.weight, "REPLACE")


def limit_normalize(ob, max_influences=4):
    n = len(ob.data.vertices)
    for v in ob.data.vertices:
        gs = sorted([(g.weight, g.group) for g in v.groups], reverse=True)
        keep = gs[:max_influences]
        tot = sum(w for w, _ in keep) or 1.0
        for w, gi in gs[max_influences:]:
            ob.vertex_groups[gi].remove([v.index])
        for w, gi in keep:
            ob.vertex_groups[gi].add([v.index], w / tot, "REPLACE")
    return n


def _mesh_arrays(ob):
    V = U.verts(ob)
    ev = np.zeros(len(ob.data.edges) * 2, int)
    ob.data.edges.foreach_get("vertices", ev)
    tris = []
    for p in ob.data.polygons:
        vs = list(p.vertices)
        tris += [[vs[0], vs[k], vs[k + 1]] for k in range(1, len(vs) - 1)]
    N = np.zeros(len(V) * 3)
    ob.data.vertices.foreach_get("normal", N)
    return V, ev.reshape(-1, 2), np.array(tris, int), N.reshape(-1, 3)


def revision5_weights(body):
    """Replace the heat weights by tools/horse/skinning.py's (the column, both limbs with the
    joint helpers, smoothed junctions; at most 4 influences). With --dump-skin, the mesh and
    its heat weights are saved first for tools/horse/skin_check.py --mesh."""
    V, E, T, N = _mesh_arrays(body)
    names = {g.index: g.name for g in body.vertex_groups}
    heat = [{names[g.group]: g.weight for g in v.groups} for v in body.data.vertices]
    if DUMP_SKIN:
        bones = sorted({b for w in heat for b in w})
        H = np.zeros((len(V), len(bones)), np.float32)
        for i, w in enumerate(heat):
            for b, x in w.items():
                H[i, bones.index(b)] = x
        np.savez_compressed(DUMP_SKIN, V=V, E=E, T=T, N=N, H=H, bones=np.array(bones))
        log("wrote", DUMP_SKIN)
    W = SK.compute(V, E, heat)
    for g in list(body.vertex_groups):
        body.vertex_groups.remove(g)
    groups = {}
    for vi, wd in enumerate(W):
        for k, val in wd.items():
            if k not in groups:
                groups[k] = body.vertex_groups.new(name=k)
            groups[k].add([vi], val, "REPLACE")
    log("skin weights: %d bones on the skin" % len(groups))


def skin(parts, arm_ob, rest):
    body = parts["HorseBody"]
    # automatic (heat) weights on the skin, with only the anatomical bones deforming (the joint
    # helpers are weighted by skinning.py)
    arm = arm_ob.data
    heat_bones = {b.name for b in arm.bones if b.use_deform} - {"saddle", "stirrup_l", "stirrup_r", "stirrup_iron_l",
                                                                 "stirrup_iron_r", "body"} - set(A.helpers())
    saved = {}
    for b in arm.bones:
        saved[b.name] = b.use_deform
        b.use_deform = b.name in heat_bones
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm_ob.select_set(True)
    bpy.context.view_layer.objects.active = arm_ob
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for b in arm.bones:
        b.use_deform = saved[b.name]
    missing = sum(1 for v in body.data.vertices if not v.groups)
    log("heat weights: %d vertices without weights" % missing)
    if missing:
        # fall back to nearest-bone segments for any vertex heat weighting missed
        V = U.verts(body)
        names = sorted(heat_bones)
        for v in body.data.vertices:
            if v.groups:
                continue
            p = V[v.index]
            best, bn = 1e9, None
            for b in names:
                h = np.array(A.bone_table()[b][0])
                t_ = np.array(A.bone_table()[b][1])
                ab = t_ - h
                tt = np.clip((p - h) @ ab / (ab @ ab), 0, 1)
                d = np.linalg.norm(p - (h + tt * ab))
                if d < best:
                    best, bn = d, b
            body.vertex_groups[bn].add([v.index], 1.0, "REPLACE") if bn in body.vertex_groups else \
                body.vertex_groups.new(name=bn).add([v.index], 1.0, "REPLACE")
    revision5_weights(body)
    rigid(parts["Eyes"], "head")
    if not HORSE:
        rigid(parts["Horns"], "head")
        _hooves_and_parent(parts, arm_ob)
        return
    rigid(parts["Forelock"], "head")
    rigid(parts["Bridle"], "head")
    rigid(parts["Bit"], "head")
    for n in ("Saddle", "SaddleCloth", "Girth"):
        rigid(parts[n], "saddle")
    for s in ("l", "r"):
        rigid(parts["StirrupLeather_" + s], "stirrup_" + s)
        rigid(parts["StirrupIron_" + s], "stirrup_iron_" + s)
    _hooves_and_parent(parts, arm_ob, ("Mane", "Feathers", "Tail"), rest)


def _hooves_and_parent(parts, arm_ob, hair=(), rest=None):
    # hooves: by side / fore-hind
    hv = parts["Hooves"]
    V = U.verts(hv)
    groups = {}
    for i, p in enumerate(V):
        s = "l" if p[0] > 0 else "r"
        b = ("hoof_" if p[1] < 0 else "hhoof_") + s
        groups.setdefault(b, []).append(i)
    for b, idx in groups.items():
        hv.vertex_groups.new(name=b).add(idx, 1.0, "REPLACE")
    # the mane follows the skin it lies on: each card vertex takes the weights of the
    # nearest skin vertex, so the neck never swallows the locks when it bends
    body = parts["HorseBody"]
    if "Mane" in hair:
        copy_skin_weights(body, parts["Mane"])
        # (so do the fetlock feathers, which bend with the fetlock's helper)
        copy_skin_weights(body, parts["Feathers"])
        by_segments(parts["Tail"], ["hips", "tail_1", "tail_2", "tail_3", "tail_4"], rest, 0.07)
        limit_normalize(parts["Tail"])
    for n, o in parts.items():
        if n == "HorseBody":
            continue
        o.parent = arm_ob
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = arm_ob


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------
def write_action(arm_ob, rig, name, frames):
    """frames: list of pose dicts (armature-space 4x4)."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if arm_ob.animation_data is None:
        arm_ob.animation_data_create()
    arm_ob.animation_data.action = act
    n = len(frames)
    locs = {b: np.zeros((n, 3)) for b in rig.order}
    quats = {b: np.zeros((n, 4)) for b in rig.order}
    from mathutils import Matrix
    for i, pose in enumerate(frames):
        local = rig.to_local(pose)
        for b in rig.order:
            M = Matrix(local[b].tolist())
            q = M.to_quaternion()
            v = np.array([q.w, q.x, q.y, q.z])
            if i and v @ quats[b][i - 1] < 0:
                v = -v
            quats[b][i] = v
            locs[b][i] = local[b][:3, 3]
    # scene frames at EXPORT_FPS: a clip keyed at 30 Hz has a key every 4th frame
    fr = np.arange(n, dtype=float) * (G.EXPORT_FPS / G.key_rate(name))
    for b in rig.order:
        for path, arr, cnt in (("location", locs[b], 3), ("rotation_quaternion", quats[b], 4)):
            for k in range(cnt):
                fc = act.fcurve_ensure_for_datablock(arm_ob, 'pose.bones["%s"].%s' % (b, path), index=k,
                                                     group_name=b)
                fc.keyframe_points.add(n)
                co = np.stack([fr, arr[:, k]], 1).ravel()
                fc.keyframe_points.foreach_set("co", co)
                fc.keyframe_points.foreach_set("interpolation", [1] * n)   # LINEAR
                fc.update()
    act.use_frame_range = True
    act.frame_start, act.frame_end = 0, float(fr[-1])
    act.use_cyclic = GAIT_LOOP.get(name, False)
    return act


GAIT_LOOP = {c: G.GAITS[c]["kind"] in ("cycle", "idle") for c in CLIPS}


def solve_clips(rig, rc, rest):
    solver = G.Solver(rig, rc)
    out = {}
    diag = {}
    soles = GC.sole_points(A, rest)
    for c in CLIPS:
        nf, L = G.clip_frames(c, rc)
        solver.diag = {}
        solver.reach_err = 0.0
        frames = []
        # the exported keys: 120 per second for the fast gaits, 30 for the others
        for t in G.key_times(c, rc):
            frames.append(solver.pose_at(c, t, L, nf))
        # ground-frame diagnostics (tools/horse/gait_check.py): stance slip, teleports,
        # skating, touchdown / lift-off ground speed, swing clearance and toe drag, sinking,
        # leg reach, neck carriage; one-shots included
        m = GC.measure(A, G, rig, rest, rc, c, soles)
        sm = GC.summarize(m)
        pb = GC.playback_check(A, G, rig, rest, rc, c)
        jr = GC.joint_rom(A, G, rig, rc, c, span=min(L, 1.25))
        d = dict(frames=nf, length=L, loop_close=m["loop_close"], ground_speed=G.ground_speed(c, rc),
                 key_rate=G.key_rate(c), playback={k: (round(v, 4) if isinstance(v, float) else v) for k, v in pb.items()
                                                   if k != "legs"},
                 joint_rom={k: round(v, 2) for k, v in jr.items() if k != "legs"},
                 pelvis_pitch_range=round(m["pelvis_pitch_range"], 2), pelvis_roll_range=round(m["pelvis_roll_range"], 2),
                 pelvis_pitch_vs_back_range=round(m["pelvis_pitch_vs_back_range"], 2),
                 max_stretch={leg: round(v["stretch"], 4) for leg, v in m["legs"].items()},
                 reach_err=round(m["reach_err"], 5), saddle_z_p2p=round(m["saddle_z_range"][1] - m["saddle_z_range"][0], 4),
                 neck_elevation_deg=round(m["neck_elev_mean"], 2), poll_height=round(m["poll_height_mean"], 4))
        for k, v in sm.items():
            d[k] = round(v, 4) if isinstance(v, float) else v
        d["legs"] = {leg: {k: (round(x, 4) if isinstance(x, float) else x) for k, x in v.items()} for leg, v in m["legs"].items()}
        diag[c] = d
        out[c] = frames
        hr = [d["legs"][l].get("hip_rom", 0.0) for l in ("LH", "RH")]
        log("clip %-8s %3d keys %.3fs v %5.2f slip %.4f fjump %.3f skate %.2f td_v %s drag %.3f sink %.4f stretch %.3f "
            "neck %.1f hip %.0f/%.0f play: sink %.4f drift %.4f" % (
                c, len(frames), L, d["ground_speed"], sm["stance_slip"], sm["frame_jump"], sm["skate"] or 0.0,
                "%.2f" % sm["touchdown_speed"] if sm["touchdown_speed"] is not None else "-", sm["swing_drag_m"],
                sm["sink"], sm["stretch"], sm["neck_elev_mean"], hr[0], hr[1], pb.get("sink", 0), pb.get("drift", 0)))
    diag["_jump_clearance"] = {str(k): v for k, v in GC.jump_clearance(A, G, rig, rest, rc).items()}
    log("jump clearance", diag["_jump_clearance"])
    return out, diag


# ---------------------------------------------------------------------------
# Export and metadata
# ---------------------------------------------------------------------------
def export(arm_ob, parts, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm_ob.select_set(True)
    for o in parts.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm_ob
    arm_ob.animation_data.action = None
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
              export_skins=True, export_influence_nb=4, export_all_influences=False, export_def_bones=False,
              export_animations=True, export_animation_mode="ACTIONS", export_bake_animation=False,
              export_optimize_animation_size=False, export_anim_single_armature=True, export_frame_range=False,
              export_anim_slide_to_zero=False, export_force_sampling=True, export_frame_step=1,
              export_morph=False, export_materials="EXPORT", export_normals=True, export_texcoords=True,
              export_tangents=True, export_image_format="NONE",
              export_extras=True, export_rest_position_armature=True, export_leaf_bone=False,
              export_cameras=False, export_lights=False, export_vertex_color="NONE",
              export_all_vertex_colors=False, export_active_vertex_color_when_no_material=False,
              export_nla_strips=False)
    props = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    sc = bpy.context.scene
    sc.render.fps, sc.render.fps_base = G.EXPORT_FPS, 1.0
    bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})
    log("exported", path, "%.2f MB" % (os.path.getsize(path) / 1e6))
    a, b = decimate_glb(path, {c: G.key_rate(c) for c in CLIPS}, G.EXPORT_FPS)
    log("30 Hz clips cut back to their own keys: %.2f -> %.2f MB" % (a / 1e6, b / 1e6))


_CT = {5126: ("<f4", 4), 5123: ("<u2", 2), 5125: ("<u4", 4), 5121: ("<u1", 1), 5122: ("<i2", 2), 5120: ("<i1", 1)}
_NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


def decimate_glb(path, rates, base_fps):
    """The exporter samples every clip at the scene rate (base_fps). Clips keyed at a lower
    rate (rates: clip -> keys per second) keep only their own keys: their samplers are cut
    to the keys that fall on that rate, the orphaned data is dropped and the binary chunk is
    rebuilt. Returns (bytes before, bytes after)."""
    import struct
    raw = open(path, "rb").read()
    jl = struct.unpack("<I", raw[12:16])[0]
    js = json.loads(raw[20:20 + jl])
    bl = struct.unpack("<I", raw[20 + jl:24 + jl])[0]
    binc = raw[28 + jl:28 + jl + bl]
    acc, bvs = js["accessors"], js["bufferViews"]

    def read(i):
        a = acc[i]
        bv = bvs[a["bufferView"]]
        dt, sz = _CT[a["componentType"]]
        nc = _NC[a["type"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", sz * nc)
        if stride == sz * nc:
            return np.frombuffer(binc, dt, a["count"] * nc, off).reshape(a["count"], nc).copy()
        rows = [np.frombuffer(binc, dt, nc, off + k * stride) for k in range(a["count"])]
        return np.array(rows)
    new_data = []                       # (accessor index, array)
    remap_in = {}
    for an in js.get("animations", []):
        r = rates.get(an["name"], base_fps)
        if r >= base_fps:
            continue
        step = base_fps / r
        for smp in an["samplers"]:
            ti = smp["input"]
            if ti not in remap_in:
                t = read(ti)[:, 0]
                keep = np.nonzero(np.abs(t * r - np.round(t * r)) < 1e-3)[0]
                if keep[-1] != len(t) - 1:
                    keep = np.append(keep, len(t) - 1)
                remap_in[ti] = (keep, len(acc) + len(new_data))
                new_data.append((ti, t[keep].reshape(-1, 1)))
            keep, ni = remap_in[ti]
            vals = read(smp["output"])
            no = len(acc) + len(new_data)
            new_data.append((smp["output"], vals[keep]))
            smp["input"] = ni
            smp["output"] = no
        del step
    for src, arr in new_data:
        a = dict(acc[src])
        a.pop("byteOffset", None)
        a["count"] = int(len(arr))
        if "min" in a:
            a["min"] = [float(v) for v in arr.min(0)]
            a["max"] = [float(v) for v in arr.max(0)]
        a["_data"] = arr.astype(_CT[a["componentType"]][0])
        acc.append(a)
    # channels that hold their node's rest value all through (the helpers' and sockets'
    # translations, every scale, ...) are dropped: the node keeps its rest, which is what the
    # engine's importer does with such tracks anyway (remove_immutable_tracks)
    dropped = 0
    for an in js.get("animations", []):
        keep = []
        for ch in an["channels"]:
            smp = an["samplers"][ch["sampler"]]
            node = js["nodes"][ch["target"]["node"]]
            tpath = ch["target"]["path"]
            rest = np.array({"translation": node.get("translation", [0, 0, 0]), "rotation": node.get("rotation", [0, 0, 0, 1]),
                             "scale": node.get("scale", [1, 1, 1])}.get(tpath, []), float)
            a_ = acc[smp["output"]]
            vals = a_["_data"] if "_data" in a_ else read(smp["output"])
            vals = np.asarray(vals, float)
            if rest.size and vals.shape[1] == rest.size:
                dev = np.abs(vals - rest).max(1)
                if tpath == "rotation":
                    dev = np.minimum(dev, np.abs(vals + rest).max(1))
                if dev.max() < 1e-6:
                    dropped += 1
                    continue
            keep.append(ch)
        used_s = sorted({ch["sampler"] for ch in keep})
        remap = {o: k for k, o in enumerate(used_s)}
        an["samplers"] = [an["samplers"][o] for o in used_s]
        for ch in keep:
            ch["sampler"] = remap[ch["sampler"]]
        an["channels"] = keep
    log("  %d animation channels at their rest value dropped" % dropped)
    # rebuild the binary chunk from what is still referenced
    used = set()
    for m in js.get("meshes", []):
        for pr in m["primitives"]:
            used.update(pr["attributes"].values())
            if "indices" in pr:
                used.add(pr["indices"])
            for tg in pr.get("targets", []):
                used.update(tg.values())
    for sk in js.get("skins", []):
        if "inverseBindMatrices" in sk:
            used.add(sk["inverseBindMatrices"])
    for an in js.get("animations", []):
        for smp in an["samplers"]:
            used.update((smp["input"], smp["output"]))
    old_used = sorted(used)
    idx = {o: k for k, o in enumerate(old_used)}
    out = bytearray()
    new_bvs, new_acc, bv_map = [], [], {}
    for o in old_used:
        a = dict(acc[o])
        if "_data" in a:
            data = a.pop("_data").tobytes()
            while len(out) % 4:
                out.append(0)
            new_bvs.append({"buffer": 0, "byteOffset": len(out), "byteLength": len(data)})
            out += data
            a["bufferView"] = len(new_bvs) - 1
        else:
            ob = a["bufferView"]
            if ob not in bv_map:
                bv = dict(bvs[ob])
                seg = binc[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
                while len(out) % 4:
                    out.append(0)
                bv["byteOffset"] = len(out)
                out += seg
                new_bvs.append(bv)
                bv_map[ob] = len(new_bvs) - 1
            a["bufferView"] = bv_map[ob]
        new_acc.append(a)
    for m in js.get("meshes", []):
        for pr in m["primitives"]:
            pr["attributes"] = {k: idx[v] for k, v in pr["attributes"].items()}
            if "indices" in pr:
                pr["indices"] = idx[pr["indices"]]
            if pr.get("targets"):
                pr["targets"] = [{k: idx[v] for k, v in tg.items()} for tg in pr["targets"]]
    for sk in js.get("skins", []):
        if "inverseBindMatrices" in sk:
            sk["inverseBindMatrices"] = idx[sk["inverseBindMatrices"]]
    for an in js.get("animations", []):
        for smp in an["samplers"]:
            smp["input"], smp["output"] = idx[smp["input"]], idx[smp["output"]]
    js["accessors"], js["bufferViews"] = new_acc, new_bvs
    while len(out) % 4:
        out.append(0)
    js["buffers"] = [{"byteLength": len(out)}]
    jb = json.dumps(js, separators=(",", ":")).encode()
    while len(jb) % 4:
        jb += b" "
    total = 12 + 8 + len(jb) + 8 + len(out)
    blob = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(jb), 0x4E4F534A) + jb + \
        struct.pack("<II", len(out), 0x004E4942) + bytes(out)
    open(path, "wb").write(blob)
    return len(raw), len(blob)


def godot(p):
    """Blender (x, y, z) -> Godot (x, z, -y)."""
    return [round(float(p[0]), 4), round(float(p[2]), 4), round(float(-p[1]), 4)]


LOOK = {
    "coats": ["bay", "brown", "black", "chestnut", "grey", "dun"],
    "default_coat": "bay",
    "materials": {
        "horse_coat": "assets/horse/materials/horse_coat.gdshader: coat masks, normal, detail and flow textures "
                      "(assets/horse/textures/horse_coat_*.png, baked by tools/horse/coat.py)",
        "horse_hair": "assets/horse/materials/horse_hair.gdshader: hair cards (horse_hair_strands.png), alpha "
                      "scissor, two-sided, anisotropic highlight along the strands",
        "horse_hoof": "assets/horse/materials/horse_hoof.gdshader: horn with growth rings, light horn under the sock",
        "horse_eye": "wet dark eye",
        "tack_leather / tack_bridle": "Poly Haven brown_leather (CC0), tinted",
        "tack_cloth": "Poly Haven poly_wool_herringbone (CC0) dyed madder red: wool saddle cloth",
        "tack_girth": "Poly Haven hessian_230 (CC0): woven girth web",
        "tack_iron": "forged iron (bit, stirrup irons)",
    },
    "note": "scripts/horse/horse_look.gd assigns these materials by the glTF material names and applies a coat "
            "variant (Horse.coat) through per-instance shader parameters.",
}


def write_meta(rc, diag, parts, samples=None):
    gaits = {}
    for c in CLIPS:
        g = G.GAITS[c]
        nf, L = G.clip_frames(c, rc)
        e = dict(length=L, frames=nf, loop=GAIT_LOOP[c], kind=g["kind"], key_rate=G.key_rate(c),
                 keys=len(G.key_times(c, rc)))
        if g.get("rider"):
            e["rider_clip"] = g["rider"]
            src = rc["gaits"].get(g["rider"]) or rc["oneshots"].get(g["rider"])
            if src:
                e["rider_native_asset_id"] = src.get("native_asset_id")
        if g["kind"] == "cycle":
            T_stride = L / g["strides"]
            e.update(strides=g["strides"], stride_s=round(T_stride, 5), design_speed=round(G.ground_speed(c, rc), 4),
                     stride_length=g["stride"], duty=list(g["duty"]),
                     touchdown_phase={k: v for k, v in g["td"].items()},
                     lh_touchdown_clip_phase=round(g["td"]["LH"] / g["strides"], 5),
                     saddle_amp=g.get("amp_z", 0.0))
            if g.get("curve"):
                R = G.turn_radius(c, rc)
                e.update(curve=g["curve"], curve_of=g["curve_of"], turn_radius=round(R, 4),
                         yaw_rate_deg_s=round(math.degrees(g["curve"] * G.ground_speed(c, rc) / R), 3),
                         lean_deg=round(math.degrees(G.lean_angle(c, rc)), 3),
                         body_drop=round(G._CURVE_DROP.get(c, 0.0), 4))
            elif g.get("variant_of"):
                e["variant_of"] = g["variant_of"]
            if g.get("yaw_rate"):
                e["yaw_rate_deg_s"] = round(math.degrees(g["yaw_rate"]), 3)
        if g["kind"] == "jump":
            jc = diag.get("_jump_clearance", {})
            e.update(design_speed=g["speed"], takeoff_time=G.JUMP_TAKEOFF, landing_time=G.JUMP_LAND,
                     launch_speed_rate1=round(G.jump_launch_speed(1.0), 4), gravity=G.GRAVITY,
                     stance_windows={k: [list(w) for w in v if w[1] > 0.0] for k, v in G.JUMP_STANCE.items()},
                     clearance=jc,
                     note="The root (CharacterBody) flies a ballistic arc from takeoff_time to landing_time "
                          "(clip time); the clip's body height is relative to that lifted root. At playback rate r "
                          "the launch speed is launch_speed_rate1 / r. clearance: highest rail per rate and the "
                          "distance from the root at the jump start to the rail (best_x, and the window in which "
                          "a 0.6 m rail clears).")
        e["diagnostics"] = diag.get(c, {})
        gaits[c] = e
    # sockets at rest in Godot space (the horse faces +z)
    st = {s: A.stirrup_points(s) for s in ("l", "r")}
    meta = {
        "tool": "tools/horse/build_horse.py",
        "space": "Godot model space: +y up, the horse faces +z, +x is the horse's left; metres",
        "size": {"withers_height": A.WITHERS, "hands_decimal": round(A.WITHERS / 0.1016, 3),
                 "hands_notation": "%d.%d" % divmod(int(round(A.WITHERS / 0.0254)), 4),
                 "note": "Hands in the usual notation: 14.1 = 14 hands 1 inch (1 hand = 4 in = 0.1016 m).",
                 "type": "stocky 1750s colonial saddle horse (Canadian / Chickasaw / Narragansett type)",
                 "scale_from_base": [round(float(k), 4) for k in A.K]},
        "turning": {"a_lat": G.A_LAT, "turn_radius_min": dict(G.TURN_R_MIN), "lean_k": G.LEAN_K,
                    "lean_max_deg": G.LEAN_MAX,
                    "note": "Every moving gait clip X has curved variants X_tl / X_tr baked on a circle of radius "
                            "turn_radius (hooves planted along the arc, the body leaning in). Blend them with X by "
                            "curvature: weight = yaw rate x turn_radius / speed (-1..1, + = left). The runtime yaw "
                            "limit is speed / max(turn_radius_min[gait], speed^2 / a_lat)."},
        "attach_height": round(A.ATTACH_Z, 4),
        "seat_height": round(A.SEAT_Z, 4),
        "withers_height": A.WITHERS,
        "clip_ground": {"authored": A.CLIP_GROUND, "actual": round(A.ATTACH_Z, 4),
                        "mount_ground_offset": round(A.MOUNT_GROUND_OFFSET, 4),
                        "note": "The riding clips are saddle-relative and need no change. Ground-relative rider clips "
                                "(mount, dismount) were fitted to a ground 1.37 m under the clip origin; on this horse "
                                "the ground is attach_height under it, so shift their origin by mount_ground_offset (m, "
                                "along the saddle frame's up axis) while they blend between ground and saddle."},
        "sockets": {
            "saddle": godot((0, 0, A.ATTACH_Z)),
            "passenger": godot(A.PASSENGER),
            "stirrup_tread_l": godot(st["l"][1]),
            "stirrup_tread_r": godot(st["r"][1]),
            "stirrup_bar_l": godot(st["l"][0]),
            "stirrup_bar_r": godot(st["r"][0]),
            "stirrup_iron_height": A.STIRRUP_IRON_H,
            "bit": godot((0, A.BIT_Y, A.BIT_Z)),
            "rein_l": godot((A.BIT_RING_X, A.BIT_Y, A.BIT_Z)),
            "rein_r": godot((-A.BIT_RING_X, A.BIT_Y, A.BIT_Z)),
            # toe (front of the sole, the breakover pivot) of each hoof at rest, and its bone
            "hoof_toes": {"LF": ["hoof_l", godot(A.J["f_toe"])], "RF": ["hoof_r", godot(A.mirror(A.J["f_toe"]))],
                          "LH": ["hhoof_l", godot(A.J["h_toe"])], "RH": ["hhoof_r", godot(A.mirror(A.J["h_toe"]))]},
        },
        "mount": {
            "note": "Actor_A mount-left fit (horse.md 1.7): rider starts on the ground 0.69 m out, 0.18 m forward, "
                    "turned ~101 deg to face the flank. The dismount lands ~0.55 m out. The mount clip's origin must "
                    "rise by attach_height (not 1.37 m); see clip_ground.",
            "mount_left": {"pos": [0.69, 0.0, 0.18], "yaw_deg": -101.0},
            "mount_right": {"pos": [-0.69, 0.0, 0.18], "yaw_deg": 101.0},
            "dismount_left": {"pos": [0.55, 0.0, 0.0]},
            "dismount_right": {"pos": [-0.55, 0.0, 0.0]},
        },
        "collision": {"box_size": [0.62, 0.95, 1.8], "box_center": [0.0, 1.025, 0.07], "feet_radius": 0.36},
        "rig": {"revision": 5, "bones": len(A.bone_table()),
                "column": ["body", "chest", "back", "loin", "loin_2", "hips", "tail_1", "tail_2", "tail_3", "tail_4"],
                "neck": ["neck_1", "neck_2", "neck_3", "head"],
                "spine_flex_shares": A.SPINE_FLEX, "spine_bend_shares": A.SPINE_BEND,
                "scapula": {"pivot_from_top": A.SCAP_PIVOT, "sling_m": A.SCAP_SLING},
                "note": "body is the trunk control (not skinned). chest: T1-T9 (withers, the shoulder blades hang "
                        "from it), back: T10-T18 (saddle), loin: L1-L3, loin_2: L4-L6, hips: sacrum and pelvis "
                        "(turns about the lumbosacral joint). The shoulder blades turn about a point in their "
                        "upper part (pivot_from_top of their length) and glide down the ribcage while their leg carries "
                        "no weight."},
        # skinning helpers: helper -> [proximal bone, distal bone, fraction]; the helper's local rotation
        # is slerp(identity, distal local rotation x its rest rotation^-1, fraction) x its own rest rotation
        # (HorseTerrain poses them again after its leg IK)
        "helpers": {h: [p_, d_, f_] for h, (p_, d_, f_, _k) in A.helpers().items()},
        "clips": gaits,
        "triangles": {n: U.tri_count(o) for n, o in parts.items()},
        "triangles_total": int(sum(U.tri_count(o) for o in parts.values())),
        "look": dict(LOOK, texture_check=samples or [],
                     texture_check_note="Blender (horse) space samples of the baked flow texture: uv (Blender, v up), "
                                        "rest position p, normal n and the 3D hair direction the texel encodes. "
                                        "tests/horse/test_horse.gd decodes the texel with Godot's tangent frame and "
                                        "compares (normal-map and flow conventions)."),
        "source_note": "Procedural (generated). Gait timing from the Actor_B rider clips; no rider animation data is "
                       "stored in the horse asset.",
    }
    json.dump(meta, open(OUT_META, "w"), indent=1)
    log("wrote", OUT_META)


def write_manifest(path, tack=()):
    def sha(p):
        return hashlib.sha256(open(p, "rb").read()).hexdigest()

    def rel(p):
        return os.path.relpath(p, PROJECT)
    note = ("Procedural horse (mesh, rig, tack, gaits, hair cards): a stocky 14.1-hand colonial saddle horse (1.45 m "
            "at the withers). No third-party mesh." if HORSE else
            "Procedural %s on the horse's rig (tools/%s/anatomy.py through tools/horse/build_horse.py: mesh, rig, "
            "gaits, horns). No third-party mesh." % (SPECIES, SPECIES))
    files = [{"path": rel(path), "sha256": sha(path), "bytes": os.path.getsize(path),
              "source": "generated", "generator": "tools/horse/build_horse.py", "license": "project-generated",
              "notes": note},
             {"path": rel(OUT_META), "source": "generated", "generator": "tools/horse/build_horse.py"}]
    for f in sorted(os.listdir(TEX_DIR)):
        if f.endswith(".png"):
            p = os.path.join(TEX_DIR, f)
            files.append({"path": rel(p), "sha256": sha(p), "bytes": os.path.getsize(p), "source": "generated",
                          "generator": "tools/horse/coat.py" if f.startswith("horse_coat") else "tools/horse/hair.py",
                          "license": "project-generated"})
    for src, dst in tack:
        tid = os.path.basename(os.path.dirname(src))
        files.append({"path": rel(dst), "sha256": sha(dst), "bytes": os.path.getsize(dst),
                      "source": "Poly Haven (https://polyhaven.com), texture '%s'" % tid,
                      "derived_from": rel(src), "license": "CC0 1.0 (public domain); no attribution required",
                      "notes": "1024 px copy of the project's Poly Haven texture, made by tools/horse/build_horse.py"})
    for f in sorted(os.listdir(os.path.join(PROJECT, "assets", "horse", "materials"))) \
            if os.path.isdir(os.path.join(PROJECT, "assets", "horse", "materials")) else []:
        if f.endswith((".gdshader", ".tres")):
            files.append({"path": "assets/horse/materials/" + f, "source": "hand-written", "license": "project"})
    man = {"files": files}
    json.dump(man, open(OUT_MANIFEST, "w"), indent=1)


# ---------------------------------------------------------------------------
def previews(out_dir, arm_ob, clips_frames, rig):
    U.render_views(out_dir, "rest", center=(0, -0.3, 0.85), dist=4.4,
                   views={"side": (1, 0, 0.1), "front34": (0.75, -0.75, 0.25)})
    act_by = {a.name: a for a in bpy.data.actions}
    for c, frac in (("walk", 0.25), ("trot", 0.25), ("gallop", 0.3), ("gallop", 0.8), ("jump", 0.5), ("rear", 0.54)):
        arm_ob.animation_data.action = act_by[c]
        nf = len(clips_frames[c])
        bpy.context.scene.frame_set(int(frac * (nf - 1)))
        U.render_views(out_dir, "%s_%02d" % (c, int(frac * 100)), center=(0, -0.3, 0.9), dist=4.4,
                       views={"side": (1, 0, 0.1)})
    arm_ob.animation_data.action = None


def main():
    a = args()
    U.reset_scene()
    rc = G.load_rider_curves()
    arm_ob, rest = build_armature()
    rig = G.Rig(rest)
    log("armature", len(rest), "bones")
    if a.get("dump_only"):
        parts, mats, body_node = build_meshes()
        skin(parts, arm_ob, rest)
        return
    clips, diag = solve_clips(rig, rc, rest)
    if a["gaits_only"]:
        return
    parts, mats, body_node = build_meshes()
    samples = bake_coat(parts["HorseBody"], body_node)
    tack = tack_textures() if HORSE else ()
    skin(parts, arm_ob, rest)
    for c in CLIPS:
        write_action(arm_ob, rig, c, clips[c])
    log("actions", len(CLIPS))
    if a["previews"]:
        previews(a["previews"], arm_ob, clips, rig)
    export(arm_ob, parts, a["out"])
    if a["out"] == OUT_GLB:
        write_meta(rc, diag, parts, samples)
        write_manifest(OUT_GLB, tack)
    log("done")


if __name__ == "__main__":
    main()
