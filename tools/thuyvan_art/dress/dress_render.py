"""Thủy Vân dress: lineup renders of the peoples' garments for the owner (Blender Eevee; style guide section 11).

    zsh tools/thuyvan/bin/blender_run.sh -b --factory-startup --python tools/thuyvan_art/dress/dress_render.py -- \
        --plan <plan.json>

Reads the garments cached by dress_session.py (<cache>/<id>.npz: both fits, faces, corner UVs, zones), the game body
(assets/character/body/body.glb: the body, its eyes and brows, the sex and face shape keys) and hair
(assets/character/hair/<style>.glb). Each figure is the body in its bind pose dressed in a people's set, every zone
painted: the zone's painted value map (assets/thuyvan/dress/paint/<kit>.png, tiled in metres along the garment's own
UV) laid over its dye's 4-stop ramp (data/thuyvan_art/peoples_dyes.json), woven motifs on top
(assets/thuyvan/dress/motifs), a soft painted occlusion. Light as every builder's lineup: sun at 40 degrees from the
front-left, a sky-coloured world light at 0.6, soft shadows, AgX; a painted grass ground (#84b546 with painted-noise
variation); a flat black silhouette pass for the inset.

plan.json: {"cache": dir, "out": dir, "res": [w, h], "samples": n, "shots": [{"name", "figures": [{"body": "f"|"m",
"items": [ids], "dyes": {id: {zone: dye}}, "hair": style, "hair_color": "#hex", "skin": tone 1-12, "face": preset,
"x": m, "rot": deg}], "camera": {"height": m, "target_z": m, "lens": mm}, "silhouette": bool}]}. Writes <out>/<name>.png,
<name>_sil.png and <name>.json (what each figure wears, its triangles and zone dyes).
"""

import argparse
import colorsys
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
ASSETS = os.path.join(ROOT, "assets")
PAINT = os.path.join(ASSETS, "thuyvan", "dress")
DYES = json.load(open(os.path.join(ROOT, "data", "thuyvan_art", "peoples_dyes.json")))["dyes"]
PAINT_META = json.load(open(os.path.join(PAINT, "dress_paint.json")))
BODY_JSON = json.load(open(os.path.join(ASSETS, "character", "body", "body.json")))
PALETTE = json.load(open(os.path.join(ROOT, "tools", "character", "cloth2", "palette.json")))


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def ramp_of(dye):
    """[(position, linear rgb)] of a dye's ramp, its `mid` placed at 0.40 (the value maps' mid); an accent far from the
    ramp's hue (a gold on a navy) is replaced by the light stop brightened (cloth is not two-toned by accident)."""
    if dye in DYES:
        r = [hx(c) for c in DYES[dye]["ramp"]]
        mid = hx(DYES[dye]["mid"])
        k = int(np.argmin([sum((a - b) ** 2 for a, b in zip(c, mid)) for c in r]))
    else:
        c = hx(PALETTE.get(dye, dye if dye.startswith("#") else "#808080"))
        h, l, s = colorsys.rgb_to_hls(*c)
        r = [colorsys.hls_to_rgb(h, max(l * 0.6, 0.0), s), c, colorsys.hls_to_rgb(h, min(l * 1.25 + 0.05, 1.0), s),
             colorsys.hls_to_rgb(h, min(l * 1.45 + 0.08, 1.0), s * 0.9)]
        k = 1
    h3 = colorsys.rgb_to_hls(*r[-1])
    h2 = colorsys.rgb_to_hls(*r[-2])
    dh = abs(h3[0] - h2[0]) * 360.0
    dh = min(dh, 360.0 - dh)
    if dh > 40.0 or h3[1] < h2[1]:
        r[-1] = colorsys.hls_to_rgb(h2[0], min(h2[1] * 1.12 + 0.03, 1.0), h2[2])
    pos = []
    n = len(r)
    for i in range(n):
        if i < k:
            pos.append(0.40 * i / max(k, 1))
        elif i == k:
            pos.append(0.40)
        else:
            pos.append(0.40 + 0.60 * (i - k) / max(n - 1 - k, 1) * (0.58 if i < n - 1 else 1.0))
    return [(p, lin(c)) for p, c in zip(pos, r)]


# ---- scene --------------------------------------------------------------------------------------------------------
def setup(res, samples):
    sc = bpy.context.scene
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    ee = sc.eevee
    for k, v in (("taa_render_samples", samples), ("use_shadows", True), ("shadow_ray_count", 3),
                 ("shadow_step_count", 10), ("use_raytracing", True), ("fast_gi_method", "GLOBAL_ILLUMINATION"),
                 ("use_gtao", True), ("gtao_distance", 0.25)):
        try:
            setattr(ee, k, v)
        except (AttributeError, TypeError):
            pass
    vs = sc.view_settings
    vs.view_transform = "AgX"
    for look in ("AgX - Medium High Contrast", "AgX - Base Contrast", "None"):
        try:
            vs.look = look
            break
        except TypeError:
            continue
    vs.exposure = 0.0
    # world: a painted sky gradient for the camera, the sky colour at 0.6 for the light
    w = bpy.data.worlds.new("tv_sky")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    rp = nt.nodes.new("ShaderNodeValToRGB")
    el = rp.color_ramp.elements
    el[0].position, el[0].color = 0.0, lin(hx("#e3eee9")) + (1,)
    el[1].position, el[1].color = 0.6, lin(hx("#5f9fd8")) + (1,)
    e = el.new(0.12)
    e.color = lin(hx("#bcd9ea")) + (1,)
    nt.links.new(sep.outputs["Z"], rp.inputs[0])
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(rp.outputs[0], bg_cam.inputs["Color"])
    bg_cam.inputs["Strength"].default_value = 1.0
    bg_amb = nt.nodes.new("ShaderNodeBackground")
    bg_amb.inputs["Color"].default_value = lin(hx("#a9c8e6")) + (1,)
    bg_amb.inputs["Strength"].default_value = 0.6
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
    nt.links.new(bg_amb.outputs[0], mx.inputs[1])
    nt.links.new(bg_cam.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])
    # the sun: elevation 40 deg from the front-left (the figures face -y, the camera looks +y)
    li = bpy.data.lights.new("tv_sun", "SUN")
    li.energy = 4.2
    li.color = lin(hx("#fff3df"))
    li.angle = math.radians(2.0)
    ob = bpy.data.objects.new("tv_sun", li)
    el_, az = math.radians(40.0), math.radians(40.0)
    v = Vector((-math.sin(az) * math.cos(el_), -math.cos(az) * math.cos(el_), math.sin(el_)))
    ob.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(ob)
    ground()


def ground():
    me = bpy.data.meshes.new("ground")
    s = 40.0
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("ground", me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new("painted_grass")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.95
    b.inputs["Specular IOR Level"].default_value = 0.1
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n1 = nt.nodes.new("ShaderNodeTexNoise")
    n1.inputs["Scale"].default_value = 0.35
    n1.inputs["Detail"].default_value = 2.0
    n2 = nt.nodes.new("ShaderNodeTexVoronoi")
    n2.inputs["Scale"].default_value = 3.0
    nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
    mix = nt.nodes.new("ShaderNodeMath")
    mix.operation = "MULTIPLY_ADD"
    mix.inputs[1].default_value = 0.65
    nt.links.new(n1.outputs["Fac"], mix.inputs[0])
    nt.links.new(n2.outputs["Distance"], mix.inputs[2])
    r = nt.nodes.new("ShaderNodeValToRGB")
    el = r.color_ramp.elements
    el[0].position, el[0].color = 0.30, lin(hx("#5e8f33")) + (1,)
    el[1].position, el[1].color = 0.85, lin(hx("#a6c95e")) + (1,)
    e = el.new(0.55)
    e.color = lin(hx("#84b546")) + (1,)
    r.color_ramp.interpolation = "CONSTANT"
    nt.links.new(mix.outputs[0], r.inputs[0])
    nt.links.new(r.outputs[0], b.inputs["Base Color"])
    ob.data.materials.append(m)
    return ob


# ---- materials ----------------------------------------------------------------------------------------------------
_IMG = {}


def image(path):
    if path not in _IMG:
        im = bpy.data.images.load(path, check_existing=True)
        im.colorspace_settings.name = "Non-Color"
        _IMG[path] = im
    return _IMG[path]


KIT_ALIAS = {"feather": "felt"}


def _ramp_node(nt, dye, value_out):
    r = nt.nodes.new("ShaderNodeValToRGB")
    stops = ramp_of(dye)
    el = r.color_ramp.elements
    el[0].position, el[0].color = stops[0][0], stops[0][1] + (1,)
    el[1].position, el[1].color = stops[-1][0], stops[-1][1] + (1,)
    for p, c in stops[1:-1]:
        e = el.new(p)
        e.color = c + (1,)
    nt.links.new(value_out, r.inputs[0])
    return r.outputs[0]


def cloth_material(name, kit, dye, motif=None, role="cloth"):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = False
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    kit = KIT_ALIAS.get(kit, kit)
    info = PAINT_META["kits"].get(kit, PAINT_META["kits"]["weave"])
    tile = max(info["tile_m"], 0.05)
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0 / tile, 1.0 / tile, 1.0)
    nt.links.new(uvn.outputs["UV"], mp.inputs["Vector"])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = image(os.path.join(PAINT, "paint", kit + ".png"))
    nt.links.new(mp.outputs[0], t.inputs["Vector"])
    col = _ramp_node(nt, dye, t.outputs["Color"])
    if motif:
        mi = PAINT_META["motifs"][motif["motif"]]
        su, sv = motif.get("scale_m", mi["tile_m"])
        mp2 = nt.nodes.new("ShaderNodeMapping")
        mp2.inputs["Scale"].default_value = (1.0 / su, 1.0 / sv, 1.0)
        nt.links.new(uvn.outputs["UV"], mp2.inputs["Vector"])
        t2 = nt.nodes.new("ShaderNodeTexImage")
        t2.image = image(os.path.join(PAINT, "motifs", motif["motif"] + ".png"))
        nt.links.new(mp2.outputs[0], t2.inputs["Vector"])
        sp = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(t2.outputs["Color"], sp.inputs[0])
        for ch, thread in zip(("Red", "Green", "Blue"), motif["threads"]):
            tc_ = _ramp_node(nt, thread, t.outputs["Color"])
            mx = nt.nodes.new("ShaderNodeMix")
            mx.data_type = "RGBA"
            nt.links.new(sp.outputs[ch], mx.inputs[0])
            nt.links.new(col, mx.inputs[6])
            nt.links.new(tc_, mx.inputs[7])
            col = mx.outputs[2]
    # painted occlusion: the folds and the undersides a little darker and cooler
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.08
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = 0.55
    nt.links.new(ao.outputs["AO"], mr.inputs["Value"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(col, mul.inputs[6])
    nt.links.new(mr.outputs[0], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    metal = kit == "metal"
    b.inputs["Roughness"].default_value = 0.38 if metal else (0.55 if kit in ("bone", "leather") else 0.88)
    b.inputs["Metallic"].default_value = 0.75 if metal else 0.0
    b.inputs["Specular IOR Level"].default_value = 0.5 if metal else 0.18
    if kit in ("weave", "felt", "fur", "hemp"):
        try:
            b.inputs["Sheen Weight"].default_value = 0.35
            b.inputs["Sheen Roughness"].default_value = 0.6
        except KeyError:
            pass
    return m


def skin_material(tone):
    tones = BODY_JSON["skin"]["tones"]
    c = hx(tones[max(1, min(12, int(tone))) - 1])
    name = "skin_%d" % tone
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(c) + (1,)
    b.inputs["Roughness"].default_value = 0.55
    b.inputs["Specular IOR Level"].default_value = 0.25
    try:
        b.inputs["Subsurface Weight"].default_value = 0.12
        b.inputs["Subsurface Radius"].default_value = (0.9, 0.35, 0.2)
        b.inputs["Subsurface Scale"].default_value = 0.01
    except KeyError:
        pass
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.06
    ao.inputs["Color"].default_value = lin(c) + (1,)
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = 0.6
    nt.links.new(ao.outputs["AO"], mr.inputs["Value"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    mul.inputs[6].default_value = lin(c) + (1,)
    nt.links.new(mr.outputs[0], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    return m


def flat_material(name, color, rough=0.5, alpha=1.0, emit=False):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(hx(color)) + (1,)
    b.inputs["Roughness"].default_value = rough
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            pass
    return m


def hair_material(color):
    name = "hair_" + color
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = False
    try:
        m.surface_render_method = "DITHERED"
    except AttributeError:
        pass
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    im = bpy.data.images.load(os.path.join(ASSETS, "character", "hair", "tex", "hair_atlas.png"), check_existing=True)
    t.image = im
    sp = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(t.outputs["Color"], sp.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Max"].default_value = 0.5
    mr.inputs["To Min"].default_value = 0.68
    mr.inputs["To Max"].default_value = 1.0
    nt.links.new(sp.outputs["Red"], mr.inputs["Value"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    mul.inputs[6].default_value = lin(hx(color)) + (1,)
    nt.links.new(mr.outputs[0], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    al = nt.nodes.new("ShaderNodeMapRange")
    al.inputs["From Min"].default_value = 0.05
    al.inputs["From Max"].default_value = 0.6
    nt.links.new(t.outputs["Alpha"], al.inputs["Value"])
    nt.links.new(al.outputs[0], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = 0.5
    b.inputs["Specular IOR Level"].default_value = 0.3
    return m


# ---- bodies, hair and garments ------------------------------------------------------------------------------------
_TEMPLATES = {}


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = []
    for o in new:
        if o.type == "MESH":
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
            for md in list(o.modifiers):
                o.modifiers.remove(md)
            meshes.append(o)
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    for o in meshes:
        o.hide_render = True
        o.hide_set(True)
    return meshes


def template(path):
    if path not in _TEMPLATES:
        _TEMPLATES[path] = import_glb(path)
    return _TEMPLATES[path]


def copy_obj(o, root):
    c = o.copy()
    c.data = o.data.copy()
    bpy.context.scene.collection.objects.link(c)
    c.hide_render = False
    c.hide_set(False)
    c.parent = root
    return c


def set_keys(o, values):
    sk = o.data.shape_keys
    if not sk:
        return
    for kb in sk.key_blocks:
        if kb.name in values:
            kb.value = values[kb.name]


def figure(fd, cache, info):
    root = bpy.data.objects.new("fig", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = (fd.get("x", 0.0), fd.get("y", 0.0), 0.0)
    root.rotation_euler = (0.0, 0.0, math.radians(fd.get("rot", 0.0)))
    male = fd.get("body", "f") == "m"
    keys = {"sex": 1.0 if male else 0.0, "sex_head": 1.0 if male else 0.0}
    face = BODY_JSON["face_presets"].get(fd.get("face", "m_face_1" if male else "f_face_1"), {})
    keys.update(face)
    skin = skin_material(fd.get("skin", 6))
    for t in template(os.path.join(ASSETS, "character", "body", "body.glb")):
        o = copy_obj(t, root)
        set_keys(o, keys)
        mats = list(o.data.materials)
        for i, mt in enumerate(mats):
            nm = (mt.name if mt else "").lower()
            if "eye" in nm:
                o.data.materials[i] = flat_material("eye", "#2b1d14", 0.15)
            elif "hair" in nm or "brow" in nm or "lash" in nm:
                o.data.materials[i] = flat_material("brows", fd.get("hair_color", "#1d1714"), 0.7, alpha=0.85)
            else:
                o.data.materials[i] = skin
        if not mats:
            o.data.materials.append(skin)
    if fd.get("hair"):
        hp = os.path.join(ASSETS, "character", "hair", fd["hair"] + ".glb")
        if os.path.exists(hp):
            hm = hair_material(fd.get("hair_color", "#1d1714"))
            for t in template(hp):
                o = copy_obj(t, root)
                set_keys(o, {"sex": 1.0 if male else 0.0})
                for i in range(len(o.data.materials)):
                    o.data.materials[i] = hm
                if not o.data.materials:
                    o.data.materials.append(hm)
    worn = []
    for gid in fd.get("items", []):
        p = os.path.join(cache, gid + ".npz")
        if not os.path.exists(p):
            print("DRESS_RENDER missing", gid)
            continue
        z = np.load(p, allow_pickle=False)
        meta = json.loads(str(z["meta"]))
        V = z["Vm"] if male else z["Vf"]
        F = z["F"]
        me = bpy.data.meshes.new(gid)
        me.from_pydata(V.tolist(), [], F.tolist())
        me.update()
        lay = me.uv_layers.new(name="UVMap")
        lay.data.foreach_set("uv", z["uv"].reshape(-1).astype(np.float32))
        zone = z["zone"].astype(int)
        dyes = {}
        own = (fd.get("dyes") or {}).get(gid.split("@")[0], {})
        paint = meta["extra"].get("tv_paint", {})
        motifs = meta["extra"].get("tv_motif", {})
        zmap = {}
        for zi in sorted(set(zone.tolist())):
            zs = str(zi)
            zinfo = meta["zones"].get(zs, {"default": "tv_bone", "role": "cloth"})
            dye = own.get(zs, zinfo["default"])
            kit = paint.get(zs, "weave")
            mot = motifs.get(zs) if own.get("motif." + zs, "on") != "none" else None
            mname = "%s_z%s_%s_%s" % (gid, zs, dye, kit) + ("_m" if mot else "")
            mat = cloth_material(mname, kit, dye, mot, zinfo.get("role", "cloth"))
            zmap[zi] = len(me.materials)
            me.materials.append(mat)
            dyes[zs] = dye
        me.polygons.foreach_set("material_index", np.array([zmap[int(v)] for v in zone], np.int32))
        me.polygons.foreach_set("use_smooth", np.ones(len(F), bool))
        o = bpy.data.objects.new(gid, me)
        bpy.context.scene.collection.objects.link(o)
        o.parent = root
        worn.append({"id": gid, "tris": int(len(F)), "budget": meta.get("budget"), "dyes": dyes,
                     "zones": {k: v["name"] for k, v in meta["zones"].items()}, "slot": meta.get("slot")})
    info.append({"body": "male" if male else "female", "x": fd.get("x", 0.0), "rot": fd.get("rot", 0.0),
                 "label": fd.get("label", ""), "worn": worn})
    return root


def camera(cam_d, xs):
    cd = bpy.data.cameras.new("cam")
    cd.lens = cam_d.get("lens", 85.0)
    cd.sensor_fit = "AUTO"
    cam = bpy.data.objects.new("cam", cd)
    bpy.context.scene.collection.objects.link(cam)
    sc = bpy.context.scene
    h = cam_d.get("height", 2.3)
    aspect = sc.render.resolution_x / sc.render.resolution_y
    fov_h = 2 * math.atan(18.0 / cd.lens)
    fov_v = 2 * math.atan(math.tan(fov_h / 2) / aspect)
    span = (max(xs) - min(xs)) + cam_d.get("margin", 0.9)
    dist = max((h / 2) / math.tan(fov_v / 2), (span / 2) / math.tan(fov_h / 2))
    cx = 0.5 * (max(xs) + min(xs))
    tz = cam_d.get("target_z", 0.92)
    up = cam_d.get("up", 0.35)
    loc = Vector((cx, -dist, tz + up))
    cam.location = loc
    cam.rotation_euler = (Vector((cx, 0.0, tz)) - loc).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    return cam


def silhouette(path, roots):
    """The flat black silhouette pass (the style guide's lineup inset): every figure black on white, small."""
    sc = bpy.context.scene
    blk = bpy.data.materials.get("sil_black") or bpy.data.materials.new("sil_black")
    blk.use_nodes = True
    nt = blk.node_tree
    nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (0, 0, 0, 1)
    nt.links.new(e.outputs[0], o.inputs[0])
    vl = sc.view_layers[0]
    g = bpy.data.objects.get("ground")
    g.hide_render = True
    old_world = sc.world
    w = bpy.data.worlds.new("white")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    sc.world = w
    vl.material_override = blk
    vt = sc.view_settings.view_transform
    sc.view_settings.view_transform = "Standard"
    rx, ry = sc.render.resolution_percentage, sc.eevee.taa_render_samples
    sc.render.resolution_percentage = 25
    sc.eevee.taa_render_samples = 8
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    sc.render.resolution_percentage, sc.eevee.taa_render_samples = rx, ry
    vl.material_override = None
    sc.view_settings.view_transform = vt
    sc.world = old_world
    g.hide_render = False


def clear_figures():
    roots = [o for o in bpy.data.objects if o.name.startswith("fig")]
    for o in list(bpy.data.objects):
        if o.parent in roots:
            bpy.data.objects.remove(o)
    for o in roots + [o for o in bpy.data.objects if o.name.startswith("cam")]:
        bpy.data.objects.remove(o)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", required=True)
    args = ap.parse_args(argv)
    plan = json.load(open(args.plan))
    os.makedirs(plan["out"], exist_ok=True)
    setup(tuple(plan.get("res", (1920, 1080))), plan.get("samples", 48))
    sc = bpy.context.scene
    for shot in plan["shots"]:
        try:
            info = []
            roots = [figure(fd, plan["cache"], info) for fd in shot["figures"]]
            cam = camera(shot.get("camera", {}), [fd.get("x", 0.0) for fd in shot["figures"]])
            from bpy_extras.object_utils import world_to_camera_view
            bpy.context.view_layer.update()
            for fi, r in zip(info, roots):
                v = world_to_camera_view(sc, cam, r.matrix_world.translation + Vector((0.0, 0.0, 0.02)))
                fi["u"], fi["v"] = round(float(v.x), 4), round(float(v.y), 4)
            sc.render.filepath = os.path.join(plan["out"], shot["name"] + ".png")
            bpy.ops.render.render(write_still=True)
            if shot.get("silhouette", True):
                silhouette(os.path.join(plan["out"], shot["name"] + "_sil.png"), roots)
            with open(os.path.join(plan["out"], shot["name"] + ".json"), "w") as f:
                json.dump({"shot": shot["name"], "caption": shot.get("caption", ""), "figures": info}, f, indent=1,
                          ensure_ascii=False)
            print("DRESS_SHOT", shot["name"])
        except Exception:
            import traceback
            traceback.print_exc()
            print("DRESS_SHOT_FAIL", shot["name"])
        clear_figures()
        sys.stdout.flush()


if __name__ == "__main__":
    main()
