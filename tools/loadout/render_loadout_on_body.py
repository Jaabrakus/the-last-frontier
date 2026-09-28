"""Loadout carry gear on the body: bind-pose turnarounds and the strap routes.

Places the weapons (assets/weapons) and the carry gear (assets/loadout, built by
build_loadout_assets.py) on the legacy Actor_B body (assets/character/actor_b_body.glb, bind
pose, the old right-hip horn removed) at the stow transforms of data/loadout/carry_gear.json,
routes the straps over the body surface, renders one turnaround sheet per preset and writes
assets/loadout/strap_routes_bind.json (the anchors a StrapRibbon needs, in bind space).

Everything here is read-only except the sheets and the routes file. Run headless:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      --python tools/loadout/render_loadout_on_body.py -- --renders DIR \
      [--presets musket_bow,two_braces] [--routes assets/loadout/strap_routes_bind.json]

Provenance: the rig and bind pose are Actor_B.
"""

import argparse
import json
import math
import os
import re
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_loadout_assets as A  # noqa: E402  (helpers: MB, band, catmull, G, B2G, materials, render)

PROJECT = A.PROJECT
BODY = os.path.join(PROJECT, "assets", "character", "actor_b_body.glb")
LOADOUT = os.path.join(PROJECT, "assets", "loadout")
V = A.V
OLD_HORN = {"horn", "wood", "horn_tip"}


def parse_xf(text):
    nums = [float(x) for x in re.findall(r"[-+0-9.eE]+", text.replace("Transform3D", ""))]
    b = Matrix.Identity(3)
    for r in range(3):
        for c in range(3):
            b[r][c] = nums[r * 3 + c]
    return b, Vector(nums[9:12])


def imp(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def attach(objs, basis, pos, name):
    """Parent the imported roots to an empty at the Godot transform (basis, pos)."""
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.matrix_world = A.to_bmat(basis, pos)
    for o in objs:
        if o.parent is None:
            mb = o.matrix_world.copy()
            o.parent = e
            o.matrix_parent_inverse = Matrix.Identity(4)
            o.matrix_basis = mb
    return e


def marker(objs, name):
    for o in objs:
        if o.type == "EMPTY" and o.name.split(".")[0] == name:
            return A.B2G(o.matrix_world.translation)
    raise KeyError(name)


class Body:
    def __init__(self):
        objs = imp(BODY)
        self.objs = objs
        self.meshes = [o for o in objs if o.type == "MESH" and o.name in ("Body", "Clothes", "Gear", "Face", "Hair", "Hat")]
        for o in objs:
            if o.type == "MESH" and o.name not in ("Body", "Clothes", "Gear", "Face", "Hair", "Hat"):
                o.hide_render = True
        gear = next(o for o in objs if o.name == "Gear")
        idx = [i for i, m in enumerate(gear.data.materials) if m and m.name.split(".")[0] in OLD_HORN]
        bm = bmesh.new()
        bm.from_mesh(gear.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in idx], context="FACES")
        bm.to_mesh(gear.data)
        bm.free()
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        verts, polys, off = [], [], 0
        self.belt_pts = []
        for o in self.meshes:
            if o.name in ("Face", "Hair", "Hat"):
                continue
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            mw = o.matrix_world
            verts += [mw @ v.co for v in me.vertices]
            polys += [[i + off for i in p.vertices] for p in me.polygons]
            if o.name == "Gear":
                bidx = [i for i, m in enumerate(o.data.materials) if m and m.name.split(".")[0] == "belt"]
                for p in me.polygons:
                    if p.material_index in bidx:
                        self.belt_pts.append(A.B2G(mw @ p.center))
            off += len(me.vertices)
            ev.to_mesh_clear()
        self.bvh = BVHTree.FromPolygons(verts, polys)

    def outer(self, origin, direction, max_dist):
        """Last surface hit along a ray from inside the body (the outermost layer)."""
        d = direction.normalized()
        o = A.G(origin)
        db = A.G(d) - A.G(V(0, 0, 0))
        last = None
        travelled = 0.0
        for _ in range(12):
            loc, nrm, _i, dist = self.bvh.ray_cast(o, db, max_dist - travelled)
            if loc is None:
                break
            travelled += dist + 1e-4
            last = (A.B2G(loc), A.B2G(nrm))
            o = loc + db * 1e-4
        if last is None:
            raise RuntimeError("no surface from %s along %s" % (tuple(origin), tuple(direction)))
        p, n = last
        if n.dot(d) < 0:
            n = -n
        return p, n

    def nearest(self, p):
        loc, nrm, _i, dist = self.bvh.find_nearest(A.G(p))
        return A.B2G(loc), A.B2G(nrm), dist

    def belt_distance(self, p):
        return min((p - q).length for q in self.belt_pts) if self.belt_pts else None


# Body anchors: (label, origin inside the body, direction, max distance); Godot bind space,
# front +Z, character right -X.
def body_anchor(body, key):
    table = {
        "shoulder_top_L": (V(0.11, 1.25, -0.02), V(0, 1, 0), 0.22),
        "shoulder_top_R": (V(-0.11, 1.25, -0.02), V(0, 1, 0), 0.22),
        "chest_L": (V(0.09, 1.22, 0.0), V(0, 0, 1), 0.3),
        "chest_R": (V(-0.09, 1.22, 0.0), V(0, 0, 1), 0.3),
        "chest_mid_L": (V(0.03, 1.10, 0.0), V(0, 0, 1), 0.3),
        "sternum": (V(0.0, 1.10, 0.0), V(0, 0, 1), 0.3),
        "ribs_R": (V(-0.10, 1.00, 0.0), V(0, 0, 1), 0.3),
        "ribs_L": (V(0.10, 1.00, 0.0), V(0, 0, 1), 0.3),
        "hip_R": (V(0.0, 0.97, 0.0), V(-1, 0, 0), 0.27),
        "hip_L": (V(0.0, 0.97, 0.0), V(1, 0, 0), 0.27),
        "underarm_L": (V(0.0, 1.06, -0.02), V(1, 0, 0), 0.19),
        "underarm_R": (V(0.0, 1.06, -0.02), V(-1, 0, 0), 0.19),
        "back_L_low": (V(0.12, 1.02, 0.0), V(0, 0, -1), 0.3),
        "back_L_high": (V(0.08, 1.28, 0.0), V(0, 0, -1), 0.3),
        "back_R_high": (V(-0.07, 1.24, 0.0), V(0, 0, -1), 0.3),
        "belly_R": (V(-0.10, 1.07, 0.0), V(0, 0, 1), 0.3),
    }
    o, d, m = table[key]
    return body.outer(o, d, m)


STRAPS = {
    # name: (width, thickness, material, [anchors]); anchors: ("item", item_key, marker) or ("body", key)
    "musket_sling@long_A": (0.023, 0.0035, "LoadoutLeather", [("item", "long_A.musket", "StrapFront"), ("body", "shoulder_top_L"), ("body", "chest_L"), ("body", "sternum"), ("body", "ribs_R"), ("body", "underarm_R"), ("item", "long_A.musket", "StrapRear")]),
    "musket_sling@long_B": (0.023, 0.0035, "LoadoutLeather", [("item", "long_B.musket", "StrapFront"), ("body", "shoulder_top_R"), ("body", "chest_R"), ("body", "sternum"), ("body", "ribs_L"), ("body", "underarm_L"), ("item", "long_B.musket", "StrapRear")]),
    "spear_thong@long_A": (0.015, 0.002, "LoadoutBuckskin", [("item", "long_A.spear_pair", "ThongUpper"), ("body", "shoulder_top_L"), ("body", "chest_L"), ("body", "sternum"), ("body", "ribs_R"), ("body", "hip_R"), ("item", "long_A.spear_pair", "ThongLower")]),
    "spear_thong@long_B": (0.015, 0.002, "LoadoutBuckskin", [("item", "long_B.spear_pair", "ThongUpper"), ("body", "shoulder_top_R"), ("body", "chest_R"), ("body", "sternum"), ("body", "ribs_L"), ("body", "hip_L"), ("item", "long_B.spear_pair", "ThongLower")]),
    "dart_thong@long_A": (0.015, 0.002, "LoadoutBuckskin", [("item", "long_A.dart_bundle", "ThongUpper"), ("body", "shoulder_top_L"), ("body", "chest_L"), ("body", "sternum"), ("body", "ribs_R"), ("body", "underarm_R"), ("item", "long_A.dart_bundle", "ThongLower")]),
    "dart_thong@long_B": (0.015, 0.002, "LoadoutBuckskin", [("item", "long_B.dart_bundle", "ThongUpper"), ("body", "shoulder_top_R"), ("body", "chest_R"), ("body", "sternum"), ("body", "ribs_L"), ("body", "underarm_L"), ("item", "long_B.dart_bundle", "ThongLower")]),
    "quiver_strap": (0.030, 0.003, "LoadoutLeather", [("item", "quiver.quiver", "StrapTop"), ("body", "shoulder_top_R"), ("body", "chest_R"), ("body", "chest_mid_L"), ("body", "underarm_L"), ("body", "back_L_low"), ("item", "quiver.quiver", "StrapBottom")]),
    "horn_strap": (0.018, 0.0028, "LoadoutLeather", [("item", "horn.powder_horn", "StrapBase"), ("body", "back_L_high"), ("body", "shoulder_top_L"), ("body", "chest_L"), ("body", "belly_R"), ("body", "underarm_R"), ("item", "horn.powder_horn", "StrapSpout")]),
    "pistol_sling": (0.050, 0.003, "LoadoutLeather", [("body", "shoulder_top_R"), ("item", "chest_R.pistol", "BandSeat"), ("item", "chest_L.pistol", "BandSeat"), ("body", "hip_L"), ("body", "back_L_low"), ("body", "back_R_high")]),
}
STRAP_ORDER = ["horn_strap", "quiver_strap", "pistol_sling", "spear_thong@long_B", "dart_thong@long_B", "musket_sling@long_B",
               "spear_thong@long_A", "dart_thong@long_A", "musket_sling@long_A"]   # inner -> outer (design 4)


def route(body, anchors, closed, layer):
    """Catmull-Rom through the anchors, pushed out of the body by 4 mm + 3 mm per strap below."""
    off = 0.004 + 0.003 * layer
    pts = A.catmull(anchors, 8, closed)
    fixed = set(range(0, len(pts), 8))
    for _ in range(4):
        for i, p in enumerate(pts):
            q, n, _d = body.nearest(p)
            d = (p - q).dot(n)
            if d < off:
                pts[i] = p + n * (off - d)
        sm = [p.copy() for p in pts]
        for i in range(len(pts)):
            if i in fixed or (not closed and (i == 0 or i == len(pts) - 1)):
                continue
            a, b = pts[(i - 1) % len(pts)], pts[(i + 1) % len(pts)]
            sm[i] = pts[i] * 0.5 + (a + b) * 0.25
        pts = sm
    nrms = []
    for p in pts:
        q, n, _d = body.nearest(p)
        nrms.append(n)
    return pts, nrms


def length(pts, closed):
    s = sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1))
    return s + ((pts[0] - pts[-1]).length if closed else 0.0)


def load_json(rel):
    return json.load(open(os.path.join(PROJECT, rel)))


QUIVER_AT_NOCKS = False     # --quiver-nocks: stow * Transform3D(Basis(), -Nocks) (integration hook)


def build_preset(pname, preset, carry, manifest, body):
    """Instantiates the preset's items (all stowed). Returns ({item_key: objects}, [mesh objects])."""
    pts = carry["points"]
    items = {}
    meshes = []

    def place_file(path, key, basis, pos, extra=()):
        objs = imp(path)
        for e in extra:
            objs += imp(e)
        attach(objs, basis, pos, "Item_" + key)
        items.setdefault(key, []).extend(objs)
        meshes.extend(o for o in objs if o.type == "MESH")
        return objs

    W = A.WEAPONS
    for slot, spec in preset["items"].items():
        kind = spec if isinstance(spec, str) else spec["kind"]
        key = "%s.%s" % (slot, kind)
        if key not in pts:
            print("  skip", key, "(no stow)")
            continue
        basis, pos = parse_xf(pts[key]["stow"]["bind"])
        if kind == "musket":
            place_file(os.path.join(W, "musket.glb"), key, basis, pos, [os.path.join(LOADOUT, "musket_sling.glb")])
        elif kind == "bow":
            place_file(os.path.join(W, "bow.glb"), key, basis, pos, [os.path.join(LOADOUT, "bow_cord.glb")])
        elif kind == "quiver":
            if QUIVER_AT_NOCKS:
                q = next(a for a in manifest["assets"] if a["kind"] == "quiver")
                pos = pos - basis @ Vector(q["markers"]["Nocks"]["pos"])
            place_file(os.path.join(LOADOUT, "quiver.glb"), key, basis, pos)
        elif kind == "pistol":
            extra = [os.path.join(LOADOUT, "pistol_sling_loop.glb")] if slot.startswith("chest") else [os.path.join(LOADOUT, "pistol_belt_hook.glb")]
            objs = place_file(os.path.join(W, "pistol.glb"), key, basis, pos, extra)
            if slot in ("L_hip", "back_right"):         # thrust through the belt / sash: no hook
                for o in objs:
                    if o.name.split(".")[0] == "BeltHook":
                        o.hide_render = True
        elif kind == "tomahawk":
            objs = place_file(os.path.join(W, "tomahawk.glb"), key, basis, pos, [os.path.join(LOADOUT, "tomahawk_frog.glb")])
            for o in objs:
                if o.name.split(".")[0] == "TomahawkPipe":
                    o.hide_render = True
        elif kind == "atlatl":
            place_file(os.path.join(W, "atlatl.glb"), key, basis, pos)
        elif kind in ("spear_pair", "dart_bundle"):
            tie = place_file(os.path.join(LOADOUT, "spear_pair_tie.glb" if kind == "spear_pair" else "dart_bundle.glb"), key, basis, pos)
            prefix, rel, n = ("Spear_", "spear.glb", 2) if kind == "spear_pair" else ("Dart_", "atlatl_dart.glb", 5)
            m = next(a for a in manifest["assets"] if a["kind"] == ("spear_pair_tie" if kind == "spear_pair" else "dart_bundle"))
            for i in range(n):
                mk = m["markers"]["%s%d" % (prefix, i + 1)]
                lb, lp = parse_xf(mk["xform"])
                objs = imp(os.path.join(W, rel))
                attach(objs, basis @ lb, pos + basis @ lp, "Item_%s_%d" % (key, i))
                meshes.extend(o for o in objs if o.type == "MESH")
    for o in meshes:
        if o.name.split(".")[0] in ("SlingTaut", "ThongPreview", "StrapPreview"):
            o.hide_render = True
    if "horn_strap" in preset.get("gear", []):
        ref = next(a for a in manifest["assets"] if a["kind"] == "powder_horn")["reference_bind_placement"]
        basis, pos = parse_xf(ref["bind"])
        objs = imp(os.path.join(LOADOUT, "powder_horn.glb"))
        attach(objs, basis, pos, "Item_horn")
        items["horn.powder_horn"] = objs
        for o in objs:
            if o.type == "MESH":
                if o.name.split(".")[0] == "StrapPreview":
                    o.hide_render = True
                meshes.append(o)
    bpy.context.view_layer.update()
    return items, meshes


def strap_list(preset, items):
    out = []
    long_A = preset["items"].get("long_A")
    long_B = preset["items"].get("long_B")
    for slot, spec in (("long_A", long_A), ("long_B", long_B)):
        if spec is None:
            continue
        kind = spec if isinstance(spec, str) else spec["kind"]
        name = {"musket": "musket_sling", "spear_pair": "spear_thong", "dart_bundle": "dart_thong"}.get(kind)
        if name:
            out.append("%s@%s" % (name, slot))
    if "quiver" in preset["items"]:
        out.append("quiver_strap")
    if "horn_strap" in preset.get("gear", []):
        out.append("horn_strap")
    if "pistol_sling" in preset.get("gear", []) and "chest_R.pistol" in items and "chest_L.pistol" in items:
        out.append("pistol_sling")
    return sorted(out, key=STRAP_ORDER.index)


def draw_straps(body, names, items, routes_out):
    objs = []
    for layer, name in enumerate(names):
        w, t, mat, anchors = STRAPS[name]
        pts, labels, kinds = [], [], []
        for a in anchors:
            if a[0] == "item":
                pts.append(marker(items[a[1]], a[2]))
                labels.append("%s:%s" % (a[1], a[2]))
                kinds.append({"kind": "item_marker", "item": a[1], "marker": a[2]})
            else:
                p, n = body_anchor(body, a[1])
                pts.append(p + n * 0.004)
                labels.append(a[1])
                kinds.append({"kind": "body", "label": a[1], "bind": A.rnd(p), "normal": A.rnd(n, 3)})
        closed = name == "pistol_sling"
        path, nrms = route(body, pts, closed, layer)
        mb = A.MB()
        A.band(mb, path, w, t, mat, normals=nrms, closed=closed)
        objs.append(mb.to_object("Strap_" + name))
        entry = routes_out.setdefault(name, {})
        entry.update({"width_m": w, "thickness_m": t, "closed": closed, "layer_inner_to_outer": STRAP_ORDER.index(name),
                      "anchors": kinds, "anchor_points_bind": [A.rnd(p) for p in pts],
                      "length_m": round(length(path, closed), 3),
                      "centreline_bind": [A.rnd(p, 4) for p in path[::2]]})
        print("  strap %-22s %.2f m through %s" % (name, length(path, closed), ", ".join(labels)))
    return objs


def checks(body, items, out):
    res = {}
    for key in items:
        objs = items[key]
        seats = ("BeltSeat",)
        if key == "R_hip.pistol":
            seats = ("Hook",)
        elif key in ("L_hip.pistol", "back_right.pistol"):
            seats = ("Tuck",)
        for mk in seats:
            try:
                p = marker(objs, mk)
            except KeyError:
                continue
            q, n, d = body.nearest(p)
            res["%s:%s" % (key, mk)] = {"bind": A.rnd(p), "to_belt_m": round(body.belt_distance(p), 4), "to_surface_m": round(d, 4)}
        for mk in ("StrapTop", "StrapBottom", "BandSeat", "StrapBase", "StrapSpout", "StrapFront", "StrapRear", "ThongUpper", "ThongLower"):
            try:
                p = marker(objs, mk)
            except KeyError:
                continue
            q, n, d = body.nearest(p)
            res["%s:%s" % (key, mk)] = {"bind": A.rnd(p), "to_surface_m": round(d, 4)}
    if "chest_R.pistol" in items and "chest_L.pistol" in items:
        a = marker(items["chest_R.pistol"], "BandSeat")
        b = marker(items["chest_L.pistol"], "BandSeat")
        res["pistol_sling_seats"] = {"chest_R": A.rnd(a), "chest_L": A.rnd(b), "separation_m": round((a - b).length, 3),
                                     "note": "the chest_L seat is higher than chest_R: a baldric from the right shoulder to the left hip cannot pass both (see integration hooks)"}
    out.update(res)
    for k, v in res.items():
        print("  check", k, v)


def shoot_sheet(meshes, out, views, tile_w=540, tile_h=900):
    sc = A.setup_render(tile_w, tile_h)
    pts = A.world_points(meshes)
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) * 0.5
    ext_h = (hi.z - lo.z) * 1.04
    ext_w = max(hi.x - lo.x, hi.y - lo.y) * 1.04
    scale = max(ext_h, ext_w * tile_h / tile_w)
    paths = []
    tmp = os.path.join(os.path.dirname(out), "_tmp")
    os.makedirs(tmp, exist_ok=True)
    for i, (az, el) in enumerate(views):
        azr, elr = math.radians(az), math.radians(el)
        d = Vector((math.cos(elr) * math.sin(azr), -math.cos(elr) * math.cos(azr), math.sin(elr)))
        cd = bpy.data.cameras.new("SheetCam")
        cd.type = "ORTHO"
        cd.ortho_scale = scale
        cd.clip_start = 0.01
        cd.clip_end = 30.0
        cam = bpy.data.objects.new("SheetCam", cd)
        cam.location = c + d * 6.0
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(cam)
        sc.camera = cam
        p = os.path.join(tmp, "%s_%d.png" % (os.path.basename(out)[:-4], i))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam, do_unlink=True)
        bpy.data.cameras.remove(cd)
        paths.append(p)
    compose(paths, 3, out, tile_w, tile_h)


def shoot_closeups(meshes, out, shots, tile=600):
    sc = A.setup_render(tile, tile)
    paths = []
    tmp = os.path.join(os.path.dirname(out), "_tmp")
    for i, (centre, size, az, el) in enumerate(shots):
        azr, elr = math.radians(az), math.radians(el)
        d = Vector((math.cos(elr) * math.sin(azr), -math.cos(elr) * math.cos(azr), math.sin(elr)))
        cd = bpy.data.cameras.new("CloseCam")
        cd.type = "ORTHO"
        cd.ortho_scale = size
        cd.clip_start = 0.01
        cd.clip_end = 30.0
        cam = bpy.data.objects.new("CloseCam", cd)
        cb = A.G(centre)
        cam.location = cb + d * 6.0
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(cam)
        sc.camera = cam
        p = os.path.join(tmp, "%s_c%d.png" % (os.path.basename(out)[:-4], i))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam, do_unlink=True)
        bpy.data.cameras.remove(cd)
        paths.append(p)
    compose(paths, 3, out, tile, tile)


def compose(paths, cols, out, tw, th):
    rows = (len(paths) + cols - 1) // cols
    W, H = cols * tw, rows * th
    sheet = np.full((H, W, 4), 0.18, np.float32)
    sheet[..., 3] = 1.0
    for i, p in enumerate(paths):
        img = bpy.data.images.load(p, check_existing=False)
        w, h = img.size
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        bpy.data.images.remove(img)
        px = px.reshape(h, w, 4)
        r, c = i // cols, i % cols
        y0 = H - (r + 1) * th
        sheet[y0 + 2:y0 + th - 2, c * tw + 2:c * tw + tw - 2] = px[2:th - 2, 2:tw - 2]
        os.remove(p)
    im = bpy.data.images.new(os.path.basename(out), W, H, alpha=True)
    im.pixels.foreach_set(sheet.ravel())
    im.filepath_raw = out
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    print("SHEET", out)


def clear_items():
    doomed = set()
    for o in list(bpy.data.objects):
        if o.name.startswith("Item_") or o.name.startswith("Strap_"):
            doomed.add(o)
            doomed.update(o.children_recursive)
    for o in doomed:
        try:
            bpy.data.objects.remove(o, do_unlink=True)
        except ReferenceError:
            pass


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--renders", required=True)
    ap.add_argument("--presets", default="musket_bow,musket_spears,bow_darts,two_braces")
    ap.add_argument("--routes", default=os.path.join(LOADOUT, "strap_routes_bind.json"))
    ap.add_argument("--quiver-nocks", action="store_true", help="place the quiver with its nocks (not its mouth) at the stow origin")
    ap.add_argument("--suffix", default="")
    args = ap.parse_args(argv)
    global QUIVER_AT_NOCKS
    QUIVER_AT_NOCKS = args.quiver_nocks
    os.makedirs(args.renders, exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    carry = load_json("data/loadout/carry_gear.json")
    presets = load_json("data/loadout/loadout_presets.json")["presets"]
    manifest = json.load(open(os.path.join(LOADOUT, "MANIFEST.json")))
    body = Body()
    routes = {"format": "frontier-loadout-strap-routes", "version": 1,
              "generator": "tools/loadout/render_loadout_on_body.py",
              "space": "Actor_B bind pose (skeleton space, metres; front +Z, character right -X), legacy body assets/character/actor_b_body.glb",
              "provenance": "Measured on the Actor_B rig and legacy body.",
              "use": "StrapRibbon anchors: 'item_marker' anchors follow the stowed item's marker (assets/loadout MANIFEST.json); 'body' anchors are bind-space points to carry by the skin weights of the nearest body vertices, pushed out by the outfit bulk. centreline_bind is the smoothed band centreline in bind pose (every second sample) for previews and length checks.",
              "straps": {}, "checks": {}}
    views = [(0, 5), (45, 8), (90, 5), (180, 5), (225, 8), (270, 5)]
    for pname in args.presets.split(","):
        preset = presets[pname]
        print("PRESET", pname)
        items, meshes = build_preset(pname, preset, carry, manifest, body)
        straps = draw_straps(body, strap_list(preset, items), items, routes["straps"])
        checks(body, items, routes["checks"].setdefault(pname, {}))
        all_meshes = [o for o in body.meshes] + meshes + straps
        shoot_sheet(all_meshes, os.path.join(args.renders, "onbody_%s%s.png" % (pname, args.suffix)), views)
        if pname in ("musket_bow", "two_braces") and not args.suffix:
            hip = marker(items["R_hip.pistol"], "Hook") if "R_hip.pistol" in items else V(-0.2, 0.95, 0.0)
            shots = [(hip + V(0.0, 0.05, 0.0), 0.45, 270, 5), (hip + V(0.0, 0.08, -0.08), 0.5, 225, 10)]
            if "back.tomahawk" in items:
                seat = marker(items["back.tomahawk"], "BeltSeat")
                shots.append((seat + V(0.0, 0.02, 0.0), 0.55, 180, 8))
            if "quiver.quiver" in items:
                shots.append((marker(items["quiver.quiver"], "Mouth") + V(0.0, -0.1, 0.0), 0.6, 200, 20))
            if "chest_R.pistol" in items:
                shots.append((marker(items["chest_R.pistol"], "BandSeat"), 0.5, 0, 5))
                shots.append((marker(items["chest_L.pistol"], "BandSeat"), 0.5, 30, 10))
            if "horn.powder_horn" in items:
                shots.append((marker(items["horn.powder_horn"], "Bend"), 0.4, 225, 15))
            shoot_closeups(all_meshes, os.path.join(args.renders, "onbody_%s%s_closeups.png" % (pname, args.suffix)), shots)
        clear_items()
    if args.routes != "none":
        # Routes for the slot variants no rendered preset carries (no sheets).
        extra = {"_routes_long_B_musket": {"items": {"long_B": "musket"}, "gear": ["back_slings"]},
                 "_routes_long_A_spears": {"items": {"long_A": {"kind": "spear_pair", "count": 2}}, "gear": ["back_slings"]},
                 "_routes_long_B_darts": {"items": {"long_B": {"kind": "dart_bundle", "count": 5}}, "gear": ["back_slings"]}}
        for pname, preset in extra.items():
            print("ROUTES ONLY", pname)
            items, _meshes = build_preset(pname, preset, carry, manifest, body)
            draw_straps(body, strap_list(preset, items), items, routes["straps"])
            clear_items()
        routes["quiver_placement"] = "quiver at its Nocks marker" if QUIVER_AT_NOCKS else "quiver mouth at the carry_gear.json stow origin (as the data states)"
        with open(args.routes, "w") as fh:
            json.dump(routes, fh, indent=1)
        print("ROUTES", args.routes)
    try:
        os.rmdir(os.path.join(args.renders, "_tmp"))
    except OSError:
        pass


if __name__ == "__main__":
    main()
