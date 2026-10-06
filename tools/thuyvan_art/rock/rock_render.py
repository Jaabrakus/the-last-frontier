"""Thủy Vân ROCK kit: build + export the kit (rock_kit.py) and render the owner-facing lineups and an internal diorama
in Blender Eevee (bright game light on painted ground, style_guide.md section 11). Through the shared lock:

    zsh <plan>/bin/blender_run.sh -b -P tools/thuyvan_art/rock/rock_render.py -- \
        --out assets/thuyvan/rock --look <plan>/look/ROCK [--only R01,R06,...] [--no-export] [--samples 32]

Writes <look>/raw/<scene>.png (+ <scene>_sil.png silhouettes, <scene>.json labels); rock_compose.py (plain python3)
then writes the captioned lineups <look>/<scene>.png. Textures come from assets/thuyvan/rock/textures (rock_paint.py).
The pines, banners, mist and fall cards in these renders are simple stand-ins for PAINT's and VILLAGE's pieces (they
are not exported); every surface is painted, none is grey.
"""

import argparse
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rock_kit as K  # noqa: E402

TEX = os.path.join(HERE, "..", "..", "..", "assets", "thuyvan", "rock", "textures")
NOON = K._PAL["directions"]["bright_saturated_noon"]


def lin(hexstr, a=1.0):
    r, g, b = K.srgb_to_linear(K._hex(hexstr))
    return (r, g, b, a)


def lin3(rgb):
    return tuple(K.srgb_to_linear(rgb))


# ------------------------------------------------------------------------------------------------ render setup
def setup_render(res=(1920, 1080), samples=32):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except Exception:
            continue
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    try:
        sc.eevee.taa_render_samples = samples
    except Exception:
        pass
    for attr, val in (("use_gtao", False), ("use_bloom", False), ("use_raytracing", False),
                      ("use_shadows", True), ("shadow_ray_count", 2), ("shadow_step_count", 8)):
        if hasattr(sc.eevee, attr):
            try:
                setattr(sc.eevee, attr, val)
            except Exception:
                pass
    sc.view_settings.view_transform = "AgX"
    looks = [i.identifier for i in sc.view_settings.bl_rna.properties["look"].enum_items]
    for want in ("AgX - Medium High Contrast", "AgX - Base Contrast", "None"):
        if want in looks:
            sc.view_settings.look = want
            break
    sc.view_settings.exposure = 0.0
    sc.render.use_compositing = False
    return sc


def world_sky(strength=0.6, clouds=False):
    w = bpy.data.worlds.get("TV_Sky") or bpy.data.worlds.new("TV_Sky")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    cr = nt.nodes.new("ShaderNodeValToRGB")
    sky = NOON["sky"]
    cr.color_ramp.elements[0].position = 0.0
    cr.color_ramp.elements[0].color = lin(sky["horizon"])
    cr.color_ramp.elements[1].position = 0.55
    cr.color_ramp.elements[1].color = lin(sky["zenith"])
    e = cr.color_ramp.elements.new(0.16)
    e.color = lin(sky["mid"])
    nt.links.new(sep.outputs["Z"], cr.inputs[0])
    col = cr.outputs[0]
    if clouds:
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 2.2
        nz.inputs["Detail"].default_value = 3.0
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1.0, 1.0, 3.2)
        nt.links.new(tc.outputs["Generated"], mp.inputs[0])
        nt.links.new(mp.outputs[0], nz.inputs["Vector"])
        cl = nt.nodes.new("ShaderNodeValToRGB")
        cl.color_ramp.elements[0].position = 0.52
        cl.color_ramp.elements[0].color = (0, 0, 0, 1)
        cl.color_ramp.elements[1].position = 0.66
        cl.color_ramp.elements[1].color = (1, 1, 1, 1)
        nt.links.new(nz.outputs["Fac"], cl.inputs[0])
        band = nt.nodes.new("ShaderNodeMapRange")
        band.inputs["From Min"].default_value = 0.02
        band.inputs["From Max"].default_value = 0.12
        nt.links.new(sep.outputs["Z"], band.inputs[0])
        m1 = nt.nodes.new("ShaderNodeMath")
        m1.operation = "MULTIPLY"
        nt.links.new(cl.outputs[0], m1.inputs[0])
        nt.links.new(band.outputs[0], m1.inputs[1])
        # cloud colour: lit top / cool base by the noise value
        cc = nt.nodes.new("ShaderNodeValToRGB")
        cc.color_ramp.elements[0].position = 0.55
        cc.color_ramp.elements[0].color = lin(sky["cloud_shade"])
        cc.color_ramp.elements[1].position = 0.8
        cc.color_ramp.elements[1].color = lin(sky["cloud_lit"])
        nt.links.new(nz.outputs["Fac"], cc.inputs[0])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(m1.outputs[0], mix.inputs["Factor"])
        nt.links.new(col, mix.inputs[6])
        nt.links.new(cc.outputs[0], mix.inputs[7])
        col = mix.outputs[2]
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(col, bg_cam.inputs["Color"])
    bg_cam.inputs["Strength"].default_value = 1.0
    bg_light = nt.nodes.new("ShaderNodeBackground")
    bg_light.inputs["Color"].default_value = lin(NOON["ambient"]["color"])
    bg_light.inputs["Strength"].default_value = strength
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
    nt.links.new(bg_light.outputs[0], mx.inputs[1])
    nt.links.new(bg_cam.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])


def sun(az_deg, el_deg, energy=None, color=None, angle=1.5):
    s = NOON["sun"]
    for o in [o for o in bpy.data.objects if o.type == "LIGHT"]:
        bpy.data.objects.remove(o)
    ld = bpy.data.lights.new("TV_Sun", "SUN")
    ld.energy = energy if energy is not None else 3.2
    ld.color = lin3(K._hex(color or s["color"]))
    ld.angle = math.radians(angle)
    ob = bpy.data.objects.new("TV_Sun", ld)
    bpy.context.scene.collection.objects.link(ob)
    az, el = math.radians(az_deg), math.radians(el_deg)
    d = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return ob


def camera(loc, look_at=None, rot_deg=None, fov_v=35.0, res=(1920, 1080)):
    for o in [o for o in bpy.data.objects if o.type == "CAMERA"]:
        bpy.data.objects.remove(o)
    cd = bpy.data.cameras.new("TV_Cam")
    cd.sensor_fit = "VERTICAL"
    cd.angle_y = math.radians(fov_v)
    cd.clip_start = 0.5
    cd.clip_end = 20000
    ob = bpy.data.objects.new("TV_Cam", cd)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    if look_at is not None:
        d = Vector(look_at) - Vector(loc)
        ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    else:
        ob.rotation_euler = Euler([math.radians(a) for a in rot_deg])
    bpy.context.scene.camera = ob
    return ob


# ------------------------------------------------------------------------------------------------ materials
FOG = {"density": 0.0, "color": NOON["fog"]["color"]}


def fog_group():
    g = bpy.data.node_groups.get("TV_Fog")
    if g:
        return g
    g = bpy.data.node_groups.new("TV_Fog", "ShaderNodeTree")
    g.interface.new_socket("Shader", in_out="INPUT", socket_type="NodeSocketShader")
    g.interface.new_socket("Shader", in_out="OUTPUT", socket_type="NodeSocketShader")
    gi = g.nodes.new("NodeGroupInput")
    go = g.nodes.new("NodeGroupOutput")
    cam = g.nodes.new("ShaderNodeCameraData")
    dens = g.nodes.new("ShaderNodeValue")
    dens.name = "density"
    dens.outputs[0].default_value = 0.0
    m = g.nodes.new("ShaderNodeMath")
    m.operation = "MULTIPLY"
    g.links.new(cam.outputs["View Distance"], m.inputs[0])
    g.links.new(dens.outputs[0], m.inputs[1])
    ex = g.nodes.new("ShaderNodeMath")
    ex.operation = "EXPONENT"
    neg = g.nodes.new("ShaderNodeMath")
    neg.operation = "MULTIPLY"
    neg.inputs[1].default_value = -1.0
    g.links.new(m.outputs[0], neg.inputs[0])
    g.links.new(neg.outputs[0], ex.inputs[0])
    one = g.nodes.new("ShaderNodeMath")
    one.operation = "SUBTRACT"
    one.inputs[0].default_value = 1.0
    g.links.new(ex.outputs[0], one.inputs[1])
    col = g.nodes.new("ShaderNodeRGB")
    col.name = "fogcol"
    col.outputs[0].default_value = lin(FOG["color"])
    em = g.nodes.new("ShaderNodeEmission")
    g.links.new(col.outputs[0], em.inputs["Color"])
    em.inputs["Strength"].default_value = 1.0
    mx = g.nodes.new("ShaderNodeMixShader")
    g.links.new(one.outputs[0], mx.inputs[0])
    g.links.new(gi.outputs[0], mx.inputs[1])
    g.links.new(em.outputs[0], mx.inputs[2])
    g.links.new(mx.outputs[0], go.inputs[0])
    return g


def set_fog(density, color=None):
    g = fog_group()
    g.nodes["density"].outputs[0].default_value = density
    if color:
        g.nodes["fogcol"].outputs[0].default_value = lin(color)


def _out_with_fog(nt, shader_socket):
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    grp = nt.nodes.new("ShaderNodeGroup")
    grp.node_tree = fog_group()
    nt.links.new(shader_socket, grp.inputs[0])
    nt.links.new(grp.outputs[0], out.inputs["Surface"])


def _img(path):
    name = os.path.basename(path)
    im = bpy.data.images.get(name)
    if im is None:
        im = bpy.data.images.load(path)
    return im


def _boxtex(nt, path, tile, coord):
    mp = nt.nodes.new("ShaderNodeMapping")
    s = 1.0 / tile
    mp.inputs["Scale"].default_value = (s, s, s)
    nt.links.new(coord, mp.inputs[0])
    it = nt.nodes.new("ShaderNodeTexImage")
    it.image = _img(path)
    it.projection = "BOX"
    it.projection_blend = 0.25
    nt.links.new(mp.outputs[0], it.inputs[0])
    return it


def rock_material(key):
    """The render twin of the Godot painted-rock material: box-projected paint x vertex colour RGB, moss blended by
    vertex A x up-facing normal; rough, low specular; fog."""
    name = "R_" + key
    m = bpy.data.materials.get(name)
    if m:
        return m
    texf, tile, tint = K.MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    nt = m.node_tree
    nt.nodes.clear()
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.inputs["Roughness"].default_value = 0.92
    for nm in ("Specular IOR Level", "Specular"):
        if nm in bs.inputs:
            bs.inputs[nm].default_value = 0.3
    at = nt.nodes.new("ShaderNodeVertexColor")
    at.layer_name = "Col"
    tc = nt.nodes.new("ShaderNodeTexCoord")
    if texf:
        it = _boxtex(nt, os.path.join(TEX, texf), tile, tc.outputs["Object"])
        base = it.outputs["Color"]
    else:
        rgb = nt.nodes.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = lin3(tint) + (1.0,)
        base = rgb.outputs[0]
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(base, mul.inputs[6])
    nt.links.new(at.outputs["Color"], mul.inputs[7])
    col = mul.outputs[2]
    if key in ("rock_karst", "rock_boulder", "rock_pale", "ashlar"):
        mt = _boxtex(nt, os.path.join(TEX, "moss_cap.png"), 4.0, tc.outputs["Object"])
        mm = nt.nodes.new("ShaderNodeMix")
        mm.data_type = "RGBA"
        mm.blend_type = "MULTIPLY"
        mm.inputs["Factor"].default_value = 1.0
        nt.links.new(mt.outputs["Color"], mm.inputs[6])
        nt.links.new(at.outputs["Color"], mm.inputs[7])
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Normal"], sep.inputs[0])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.interpolation_type = "SMOOTHSTEP"
        mr.inputs["From Min"].default_value = 0.5
        mr.inputs["From Max"].default_value = 0.8
        nt.links.new(sep.outputs["Z"], mr.inputs[0])
        f = nt.nodes.new("ShaderNodeMath")
        f.operation = "MULTIPLY"
        nt.links.new(mr.outputs[0], f.inputs[0])
        nt.links.new(at.outputs["Alpha"], f.inputs[1])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(f.outputs[0], mix.inputs["Factor"])
        nt.links.new(col, mix.inputs[6])
        nt.links.new(mm.outputs[2], mix.inputs[7])
        col = mix.outputs[2]
    nt.links.new(col, bs.inputs["Base Color"])
    _out_with_fog(nt, bs.outputs[0])
    return m


def ramp_material(name, stops, by="normal", rough=0.95, emission=0.0):
    """Painted stand-in material: a colour ramp by the world normal's Z (dark below, light on top) or by height."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.inputs["Roughness"].default_value = rough
    for nm in ("Specular IOR Level", "Specular"):
        if nm in bs.inputs:
            bs.inputs[nm].default_value = 0.2
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -0.4
    mr.inputs["From Max"].default_value = 0.95
    nt.links.new(sep.outputs["Z"], mr.inputs[0])
    cr = nt.nodes.new("ShaderNodeValToRGB")
    els = cr.color_ramp.elements
    els[0].position, els[0].color = 0.0, lin(stops[0])
    els[1].position, els[1].color = 1.0, lin(stops[-1])
    for i, s in enumerate(stops[1:-1], start=1):
        e = els.new(i / (len(stops) - 1))
        e.color = lin(s)
    nt.links.new(mr.outputs[0], cr.inputs[0])
    nt.links.new(cr.outputs[0], bs.inputs["Base Color"])
    if emission:
        nt.links.new(cr.outputs[0], bs.inputs["Emission Color"])
        bs.inputs["Emission Strength"].default_value = emission
    _out_with_fog(nt, bs.outputs[0])
    return m


def ground_material(tile=8.0, mix_rock=False):
    name = "R_ground_%g_%d" % (tile, mix_rock)
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.inputs["Roughness"].default_value = 0.95
    for nm in ("Specular IOR Level", "Specular"):
        if nm in bs.inputs:
            bs.inputs[nm].default_value = 0.2
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    g = _boxtex(nt, os.path.join(TEX, "lineup_grass.png"), tile, geo.outputs["Position"])
    col = g.outputs["Color"]
    if mix_rock:
        r = _boxtex(nt, os.path.join(TEX, "karst_face.png"), 16.0, geo.outputs["Position"])
        w = _boxtex(nt, os.path.join(TEX, "white_stone.png"), 4.0, geo.outputs["Position"])
        mo = _boxtex(nt, os.path.join(TEX, "moss_cap.png"), 6.0, geo.outputs["Position"])
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Normal"], sep.inputs[0])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.interpolation_type = "SMOOTHSTEP"
        mr.inputs["From Min"].default_value = 0.78
        mr.inputs["From Max"].default_value = 0.62
        nt.links.new(sep.outputs["Z"], mr.inputs[0])
        sp = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Position"], sp.inputs[0])
        hz = nt.nodes.new("ShaderNodeMapRange")
        hz.interpolation_type = "SMOOTHSTEP"
        hz.inputs["From Min"].default_value = 3.5
        hz.inputs["From Max"].default_value = 1.5
        nt.links.new(sp.outputs["Z"], hz.inputs[0])
        hm = nt.nodes.new("ShaderNodeMapRange")
        hm.interpolation_type = "SMOOTHSTEP"
        hm.inputs["From Min"].default_value = 8.0
        hm.inputs["From Max"].default_value = 14.0
        nt.links.new(sp.outputs["Z"], hm.inputs[0])
        m0 = nt.nodes.new("ShaderNodeMix")
        m0.data_type = "RGBA"
        nt.links.new(hm.outputs[0], m0.inputs["Factor"])
        nt.links.new(mo.outputs["Color"], m0.inputs[6])
        nt.links.new(col, m0.inputs[7])
        m1 = nt.nodes.new("ShaderNodeMix")
        m1.data_type = "RGBA"
        nt.links.new(mr.outputs[0], m1.inputs["Factor"])
        nt.links.new(m0.outputs[2], m1.inputs[6])
        nt.links.new(r.outputs["Color"], m1.inputs[7])
        m2 = nt.nodes.new("ShaderNodeMix")
        m2.data_type = "RGBA"
        nt.links.new(hz.outputs[0], m2.inputs["Factor"])
        nt.links.new(m1.outputs[2], m2.inputs[6])
        nt.links.new(w.outputs["Color"], m2.inputs[7])
        col = m2.outputs[2]
    nt.links.new(col, bs.inputs["Base Color"])
    _out_with_fog(nt, bs.outputs[0])
    return m


def water_material():
    m = bpy.data.materials.get("R_water")
    if m:
        return m
    m = bpy.data.materials.new("R_water")
    m.use_nodes = True
    try:
        m.surface_render_method = "BLENDED"
    except Exception:
        pass
    nt = m.node_tree
    nt.nodes.clear()
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    wd = K.ramp("water_depth")
    bs.inputs["Base Color"].default_value = lin3(wd[2]) + (1,)
    bs.inputs["Roughness"].default_value = 0.12
    bs.inputs["Alpha"].default_value = 0.62
    _out_with_fog(nt, bs.outputs[0])
    return m


def card_material(name, img, tint=(1, 1, 1), strength=1.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    try:
        m.surface_render_method = "BLENDED"
    except Exception:
        pass
    nt = m.node_tree
    nt.nodes.clear()
    it = nt.nodes.new("ShaderNodeTexImage")
    it.image = _img(img)
    it.extension = "CLIP"
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = strength
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    mul.inputs[7].default_value = tint + (1,)
    nt.links.new(it.outputs["Color"], mul.inputs[6])
    nt.links.new(mul.outputs[2], em.inputs["Color"])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(it.outputs["Alpha"], mx.inputs[0])
    nt.links.new(tr.outputs[0], mx.inputs[1])
    nt.links.new(em.outputs[0], mx.inputs[2])
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(mx.outputs[0], out.inputs["Surface"])
    return m


def flat_material(name, hexcol, emission=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = lin(hexcol)
    bs.inputs["Roughness"].default_value = 0.9
    if emission:
        bs.inputs["Emission Color"].default_value = lin(hexcol)
        bs.inputs["Emission Strength"].default_value = emission
    out = nt.nodes.get("Material Output")
    nt.links.remove(out.inputs["Surface"].links[0])
    _out_with_fog(nt, bs.outputs[0])
    nt.nodes.remove(out)
    return m


def to_render_materials(ob):
    me = ob.data
    for i, m in enumerate(list(me.materials)):
        if m and m.name in K.MATS:
            me.materials[i] = rock_material(m.name)


# ------------------------------------------------------------------------------------------------ stand-in props
TEMP = []


def temp(ob):
    TEMP.append(ob)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def clear_temp():
    for ob in TEMP:
        try:
            bpy.data.objects.remove(ob)
        except Exception:
            pass
    TEMP.clear()


def _mesh_from(name, verts, faces, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    return me


def _ico(r=1.0, sub=2):
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    v = [tuple(x.co) for x in bm.verts]
    f = [tuple(x.index for x in fc.verts) for fc in bm.faces]
    bm.free()
    return v, f


_PROTO = {}


def proto_pine():
    """An umbrella pine stand-in (karst pine, style guide 4): a leaning trunk and 3 flattened puff tiers, 10 m."""
    if "pine" in _PROTO:
        return _PROTO["pine"]
    pr = K.ramp("pine")
    mat = ramp_material("S_pine", ["#" + "".join("%02x" % int(c * 255) for c in pr[0]),
                                   "#" + "".join("%02x" % int(c * 255) for c in pr[1]),
                                   "#" + "".join("%02x" % int(c * 255) for c in pr[2])])
    bk = K.ramp("bark")
    tmat = flat_material("S_bark", "#" + "".join("%02x" % int(c * 255) for c in bk[1]))
    V, F = [], []
    rng = np.random.default_rng(3)
    iv, ifc = _ico(1.0, 2)
    tiers = [(0.0, 0.0, 6.2, 3.6, 1.4), (1.2, 0.4, 7.6, 2.8, 1.2), (-0.8, -0.3, 8.8, 2.0, 1.0), (0.6, 0.9, 5.4, 2.4, 1.0)]
    for (x, y, z, r, h) in tiers:
        o = len(V)
        for p in iv:
            k = 1 + 0.08 * math.sin(3 * p[0] + 2 * p[1])
            V.append((x + p[0] * r * k, y + p[1] * r * k, z + p[2] * h * k))
        F += [tuple(i + o for i in f) for f in ifc]
    me = _mesh_from("pine_puffs", V, F, mat)
    # trunk
    tv, tf = [], []
    n = 6
    path = [(0, 0, -0.5), (0.3, 0.1, 2.5), (0.0, 0.2, 5.0), (-0.4, 0.0, 7.0)]
    for i, (x, y, z) in enumerate(path):
        r = 0.45 * (1 - i / len(path)) + 0.15
        for k in range(n):
            a = 2 * math.pi * k / n
            tv.append((x + r * math.cos(a), y + r * math.sin(a), z))
    for i in range(len(path) - 1):
        for k in range(n):
            tf.append((i * n + k, i * n + (k + 1) % n, (i + 1) * n + (k + 1) % n, (i + 1) * n + k))
    tm = _mesh_from("pine_trunk", tv, tf, tmat)
    _PROTO["pine"] = (me, tm)
    return _PROTO["pine"]


def proto_broadleaf():
    if "broad" in _PROTO:
        return _PROTO["broad"]
    br = K.ramp("broadleaf")
    hx = ["#" + "".join("%02x" % int(c * 255) for c in br[i]) for i in range(4)]
    mat = ramp_material("S_broadleaf", [hx[0], hx[1], hx[2], hx[3]])
    V, F = [], []
    iv, ifc = _ico(1.0, 2)
    rng = np.random.default_rng(5)
    puffs = [(0, 0, 9, 4.2), (3, 1, 7.5, 3.4), (-3, -0.5, 7.8, 3.4), (0.5, 2.5, 7, 3.0), (-0.5, -2.6, 7.2, 3.0),
             (0, 0, 12, 3.0)]
    for (x, y, z, r) in puffs:
        o = len(V)
        for p in iv:
            V.append((x + p[0] * r, y + p[1] * r, z + p[2] * r * 0.85))
        F += [tuple(i + o for i in f) for f in ifc]
    me = _mesh_from("broadleaf_puffs", V, F, mat)
    tv, tf = [], []
    n = 6
    for i, z in enumerate((-0.5, 3, 6.5)):
        r = 0.6 - 0.15 * i
        for k in range(n):
            a = 2 * math.pi * k / n
            tv.append((r * math.cos(a), r * math.sin(a), z))
    for i in range(2):
        for k in range(n):
            tf.append((i * n + k, i * n + (k + 1) % n, (i + 1) * n + (k + 1) % n, (i + 1) * n + k))
    tm = _mesh_from("broad_trunk", tv, tf, flat_material("S_bark", "#5e4636"))
    _PROTO["broad"] = (me, tm)
    return _PROTO["broad"]


def place_proto(proto, loc, scale, yaw):
    for me in proto:
        ob = temp(bpy.data.objects.new(me.name, me))
        ob.location = loc
        ob.scale = (scale, scale, scale)
        ob.rotation_euler = (0, 0, yaw)


def figure(loc):
    """The 1.75 m human-height marker: a painted indigo porter silhouette with a conical hat."""
    mat = flat_material("S_figure", "#2d3d6e")
    hat = flat_material("S_hat", "#bc9c5c")
    V, F = [], []
    n = 8
    prof = [(0.0, 0.0), (0.2, 0.0), (0.22, 0.9), (0.26, 1.35), (0.12, 1.45), (0.0, 1.45)]
    for i, (r, z) in enumerate(prof):
        for k in range(n):
            a = 2 * math.pi * k / n
            V.append((r * math.cos(a), r * math.sin(a), z))
    for i in range(len(prof) - 1):
        for k in range(n):
            F.append((i * n + k, i * n + (k + 1) % n, (i + 1) * n + (k + 1) % n, (i + 1) * n + k))
    me = _mesh_from("figure_body", V, F, mat)
    hv, hf = _ico(0.12, 1)
    hv = [(x, y, z + 1.55) for x, y, z in hv]
    hm = _mesh_from("figure_head", hv, hf, mat)
    cv = [(0.36 * math.cos(2 * math.pi * k / 10), 0.36 * math.sin(2 * math.pi * k / 10), 1.6) for k in range(10)]
    cv.append((0, 0, 1.82))
    cf = [(k, (k + 1) % 10, 10) for k in range(10)]
    cm = _mesh_from("figure_hat", cv, cf, hat)
    for me_ in (me, hm, cm):
        ob = temp(bpy.data.objects.new(me_.name, me_))
        ob.location = loc


def ground_plane(size, z=0.0, tile=8.0, loc=(0, 0)):
    me = _mesh_from("ground", [(-size + loc[0], -size + loc[1], z), (size + loc[0], -size + loc[1], z),
                               (size + loc[0], size + loc[1], z), (-size + loc[0], size + loc[1], z)],
                    [(0, 1, 2, 3)], ground_material(tile))
    return temp(bpy.data.objects.new("ground", me))


def card(name, img, w, h, loc, yaw, tint=(1, 1, 1), strength=1.0, pitch=90.0):
    mat = card_material(name + "_mat_%d" % int(strength * 100), img, tint, strength)
    me = bpy.data.meshes.new(name)
    me.from_pydata([(-w / 2, 0, -h / 2), (w / 2, 0, -h / 2), (w / 2, 0, h / 2), (-w / 2, 0, h / 2)], [],
                   [(0, 1, 2, 3)])
    me.uv_layers.new(name="UVMap")
    for i, uv in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
        me.uv_layers[0].data[i].uv = uv
    me.materials.append(mat)
    ob = temp(bpy.data.objects.new(name, me))
    ob.location = loc
    ob.rotation_euler = (0, 0, yaw)
    return ob


def pines_on_seats(ob, rng, scale=1.0, kinds=("pine",), max_n=40, crown_scale=1.0):
    seats = json.loads(ob["seats"])
    mw = ob.matrix_world
    n = 0
    for s in seats:
        if s["kind"] not in kinds or n >= max_n:
            continue
        x, y, z = s["pos"]
        p = mw @ Vector((x, -z, y))
        sc = scale * (crown_scale if s.get("crown") else 1.0) * rng.uniform(0.75, 1.25)
        place_proto(proto_pine(), p - Vector((0, 0, 0.8 * sc)), sc, rng.uniform(0, 6.28))
        n += 1


# ------------------------------------------------------------------------------------------------ helpers
ALL = []


def hide_all():
    for ob in ALL:
        ob.hide_render = True


def show(ob, loc=(0, 0, 0), yaw=0.0, scale=1.0):
    ob.hide_render = False
    ob.location = loc
    ob.rotation_euler = (0, 0, yaw)
    ob.scale = (scale, scale, scale)


def label_at(cam, world_pt, lines):
    sc = bpy.context.scene
    co = world_to_camera_view(sc, cam, Vector(world_pt))
    return {"x": round(co.x * sc.render.resolution_x), "y": round((1 - co.y) * sc.render.resolution_y),
            "lines": lines}


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def silhouette(path, obs, cam_loc, look_at, fov=35, res=(512, 512)):
    """A flat black silhouette on white (the 64 px test), Workbench."""
    sc = bpy.context.scene
    keep = (sc.render.engine, sc.render.resolution_x, sc.render.resolution_y, sc.view_settings.view_transform)
    vis = {o.name: o.hide_render for o in bpy.data.objects}
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o not in obs
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "FLAT"
    sh.color_type = "SINGLE"
    sh.single_color = (0, 0, 0)
    sh.background_type = "VIEWPORT"
    sh.background_color = (1, 1, 1)
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = res
    cam = camera(cam_loc, look_at, fov_v=fov, res=res)
    render(path)
    sc.render.engine, sc.render.resolution_x, sc.render.resolution_y, sc.view_settings.view_transform = keep
    for o in bpy.data.objects:
        if o.name in vis:
            o.hide_render = vis[o.name]


def info(name, meta):
    e = meta["pieces"].get(name, {})
    t = e.get("tris")
    t1 = e.get("tris_lod1")
    mats = ", ".join(e.get("materials", []))
    h = e.get("size", {}).get("y", [0, 0])
    return [name, "%.0f m tall  ·  %s tris%s" % (h[1], t, (" / LOD1 %s" % t1) if t1 else ""), mats]


# ------------------------------------------------------------------------------------------------ scenes
def scene_towers(kit, meta, look, names, tag, title, spacing=30.0, fov=30.0, pines=True, el=8.0, figure_on=True):
    hide_all()
    clear_temp()
    set_fog(0.00012)
    world_sky(1.2)
    rng = np.random.default_rng(1)
    obs = [kit[n][0] for n in names]
    widths = [o.dimensions.x + 10 for o in obs]
    total = sum(widths) + spacing * (len(obs) - 1)
    x = -total / 2
    labels = []
    hmax = max(o.dimensions.z for o in obs)
    for o, w in zip(obs, widths):
        x += w / 2
        show(o, (x, 0, 0), yaw=0.0)
        if pines:
            pines_on_seats(o, rng, scale=1.5, crown_scale=1.2)
        if figure_on:
            figure((x + w / 2 - 4, -o.dimensions.y / 2 - 6, 0))
        x += w / 2 + spacing
    ground_plane(6000, 0.0, tile=24.0)
    dist = max(total / (2 * math.tan(math.radians(fov) * 16 / 18)), hmax * 1.6) * 1.05
    cam_loc = (0, -dist, hmax * 0.32 + dist * math.tan(math.radians(el)))
    look_at = (0, 0, hmax * 0.42)
    cam = camera(cam_loc, look_at, fov_v=fov)
    sun(215, 40, energy=2.4)
    x = -total / 2
    for n, o, w in zip(names, obs, widths):
        x += w / 2
        labels.append(label_at(cam, (x, -o.dimensions.y / 2, 0), info(n, meta)))
        x += w / 2 + spacing
    render(os.path.join(look, "raw", tag + ".png"))
    hero = obs[min(2, len(obs) - 1)]
    c = hero.location
    silhouette(os.path.join(look, "raw", tag + "_sil.png"), [hero],
               (c.x + hero.dimensions.z * 1.4, c.y - hero.dimensions.z * 1.4, hero.dimensions.z * 0.7),
               (c.x, c.y, hero.dimensions.z * 0.45), fov=40)
    json.dump({"title": title, "labels": labels, "sil": tag + "_sil.png", "sil_name": names[min(2, len(names) - 1)]},
              open(os.path.join(look, "raw", tag + ".json"), "w"), indent=1, ensure_ascii=False)


def wall_chain(kit, names, start=(0.0, 0.0), heading=0.0, top_z=0.0):
    """Place cliff modules edge to edge (each module's left edge on the previous one's right edge, sharing its
    tangent). heading: the first module's local +X direction (radians). Returns the placed objects and the end."""
    placed = []
    px, py, hd = start[0], start[1], heading
    for nm in names:
        ob = kit[nm][0]
        kind = nm.split("_")[1]
        Rc = {"convex": 70.0, "concave": -70.0}.get(kind, 0.0)
        hw = K.WALL_W / 2
        if Rc:
            a = hw / Rc
            left = (-Rc * math.sin(a), Rc * (1 - math.cos(a)))
            right = (Rc * math.sin(a), Rc * (1 - math.cos(a)))
            al, ar = -a, a
        else:
            left, right, al, ar = (-hw, 0.0), (hw, 0.0), 0.0, 0.0
        rot = hd - al
        c, s = math.cos(rot), math.sin(rot)
        ox = px - (c * left[0] - s * left[1])
        oy = py - (s * left[0] + c * left[1])
        if ob in [p for p in placed]:
            ob = ob.copy()
            temp_link(ob)
        show(ob, (ox, oy, top_z), yaw=rot)
        placed.append(ob)
        px = ox + c * right[0] - s * right[1]
        py = oy + s * right[0] + c * right[1]
        hd = rot + ar
    return placed, (px, py, hd)


def temp_link(ob):
    TEMP.append(ob)
    bpy.context.scene.collection.objects.link(ob)


def scene_walls(kit, meta, look):
    hide_all()
    clear_temp()
    set_fog(0.0)
    world_sky(1.2)
    rng = np.random.default_rng(2)
    names = [w[0] for w in K.WALLS]
    labels = []
    x = -170.0
    cam = None
    pos = []
    for nm in names:
        ob = kit[nm][0]
        h = float(nm.split("_")[-1])
        show(ob, (x + 20, 0, h), yaw=0.0)
        pos.append((nm, x + 20, h))
        pines_on_seats(ob, rng, scale=1.3)
        x += 40 + 9
    # the needle at the end
    nd = kit["bridge_needle"][0]
    show(nd, (x + 10, -4, 0))
    pines_on_seats(nd, rng, scale=1.0)
    figure((x + 18, -14, 0))
    figure((-170 + 22, -14, 0))
    ground_plane(3000, 0.0, tile=16.0)
    cam = camera((20, -330, 70), (20, 0, 32), fov_v=30)
    sun(200, 40, energy=2.4)
    for nm, cx, h in pos:
        labels.append(label_at(cam, (cx, -10, 0), info(nm, meta)))
    labels.append(label_at(cam, (x + 10, -12, 0), info("bridge_needle", meta)))
    render(os.path.join(look, "raw", "R03_R07_walls_needle.png"))
    ob = kit["cliff_notch_75"][0]
    silhouette(os.path.join(look, "raw", "R03_R07_walls_needle_sil.png"), [ob],
               (ob.location.x + 60, -90, 50), (ob.location.x, 0, 35), fov=45)
    json.dump({"title": "R03 gorge-wall modules (40 m wide; strata 7 m; edges chain) and R07 the bridge needle (62 m)",
               "labels": labels, "sil": "R03_R07_walls_needle_sil.png", "sil_name": "cliff_notch_75"},
              open(os.path.join(look, "raw", "R03_R07_walls_needle.json"), "w"), indent=1, ensure_ascii=False)
    # the chain: modules edge to edge round a bend, seen from the river
    hide_all()
    clear_temp()
    placed, end = wall_chain(kit, ["cliff_straight_60", "cliff_convex_60", "cliff_notch_75", "cliff_concave_75",
                                   "cliff_straight_60"], start=(-100, 0), heading=0.0, top_z=60.0)
    for ob in placed:
        pines_on_seats(ob, rng, scale=1.3)
    ground_plane(3000, 0.0, tile=16.0)
    cam = camera((-10, -170, 38), (-10, 20, 30), fov_v=42)
    sun(200, 38, energy=2.4)
    render(os.path.join(look, "raw", "R03_chain.png"))
    json.dump({"title": "R03 five modules chained edge to edge (straight, convex, notch, concave, straight)",
               "labels": [], "sil": None},
              open(os.path.join(look, "raw", "R03_chain.json"), "w"), indent=1, ensure_ascii=False)


def scene_stones(kit, meta, look):
    hide_all()
    clear_temp()
    set_fog(0.0)
    world_sky(1.2)
    labels = []
    cam = None
    rows = []
    x = -16.0
    for nm, size, seed, cuts in K.BOULDERS:
        ob = kit[nm][0]
        w = ob.dimensions.x
        x += w / 2
        show(ob, (x, 6, 0))
        rows.append((nm, (x, 6 - ob.dimensions.y / 2, 0)))
        x += w / 2 + 1.6
    stones = kit["white_stones"][0]
    x = -12.0
    for ob in stones:
        w = ob.dimensions.x
        x += w / 2
        show(ob, (x, -3.5, 0), yaw=0.3)
        x += w / 2 + 0.7
    x = -8.0
    for nm, seed, h in K.CAIRNS:
        ob = kit[nm][0]
        show(ob, (x, -10, 0))
        rows.append((nm, (x, -10 - ob.dimensions.y / 2 - 0.3, 0)))
        x += 4.2
    figure((x + 0.5, -10, 0))
    figure((-17.5, 3, 0))
    ground_plane(400, 0.0, tile=8.0)
    cam = camera((0, -32, 15), (0, 0, 0.8), fov_v=40)
    sun(215, 40, energy=2.4)
    for nm, p in rows:
        labels.append(label_at(cam, p, info(nm, meta)))
    labels.append(label_at(cam, (0, -3.5 - 1.6, 0), ["white_stones (R05): 12 variants 0.3-3 m",
                                                      "%s tris (all 12) / LOD1 %s" % (
                                                          meta["pieces"]["white_stones"]["tris"],
                                                          meta["pieces"]["white_stones"]["tris_lod1"]),
                                                      "stone_white"]))
    render(os.path.join(look, "raw", "R04_R05_R08_stones.png"))
    ob = kit["boulder_f"][0]
    silhouette(os.path.join(look, "raw", "R04_R05_R08_stones_sil.png"), [ob],
               (ob.location.x + 7, ob.location.y - 7, 4), (ob.location.x, ob.location.y, 1.2), fov=40)
    json.dump({"title": "R04 boulders (1-6 m), R05 the white stones of Đá Trắng (0.3-3 m), R08 burial cairns",
               "labels": labels, "sil": "R04_R05_R08_stones_sil.png", "sil_name": "boulder_f"},
              open(os.path.join(look, "raw", "R04_R05_R08_stones.json"), "w"), indent=1, ensure_ascii=False)


def banner_card(loc, yaw, w, h, field_hex, tail_hex):
    """A stand-in banner (VILLAGE makes the real ones): a cloth plane, field colour, red tail strip."""
    m1 = flat_material("S_banner_" + field_hex, field_hex)
    m2 = flat_material("S_tail_" + tail_hex, tail_hex)
    for (z0, z1, m, ww) in ((0, -h * 0.8, m1, w), (-h * 0.8, -h, m2, w * 0.45)):
        me = bpy.data.meshes.new("banner")
        me.from_pydata([(-ww / 2, 0, z0), (ww / 2, 0, z0), (ww / 2, 0, z1), (-ww / 2, 0, z1)], [], [(0, 1, 2, 3)])
        me.materials.append(m)
        ob = temp(bpy.data.objects.new("banner", me))
        ob.location = loc
        ob.rotation_euler = (0, 0, yaw)


def gorge_for_bridge(kit, rng):
    """A stand-in gorge for the Two Heights: chained cliff modules on both rims running east-west (the torrent),
    rim ground, a floor and the torrent."""
    n_names = ["cliff_straight_75", "cliff_concave_75", "cliff_straight_75", "cliff_notch_75", "cliff_straight_75"]
    s_names = ["cliff_straight_75", "cliff_notch_75", "cliff_straight_75", "cliff_concave_75", "cliff_straight_75"]
    # north rim faces south (-Y): heading +X; south rim faces north: heading -X, built from the east
    a, _ = wall_chain_copy(kit, n_names, (-100, 36), 0.0, -4.0)
    b, _ = wall_chain_copy(kit, s_names, (100, -36), math.pi, -8.0)
    # rims, banks and floor: flat to x 100 (where the modules stand), then falling east as the torrent does
    xs = [-600.0, 100.0, 650.0]
    prof = [(-700.0, "s"), (-36.0, "s"), (-20.0, "f"), (20.0, "f"), (36.0, "n"), (700.0, "n")]

    def zz(kind, x):
        drop = max(0.0, x - 100.0)
        return {"s": -8.0 - 0.08 * drop, "n": -4.0 - 0.08 * drop, "f": -86.0 - 0.09 * drop}[kind]

    V = [(x, y, zz(k, x)) for x in xs for (y, k) in prof]
    n = len(prof)
    F = [(i * n + j, (i + 1) * n + j, (i + 1) * n + j + 1, i * n + j + 1) for i in range(len(xs) - 1)
         for j in range(n - 1)]
    temp(bpy.data.objects.new("gorge_ground", _mesh_from("gorge_ground", V, F, ground_material(12.0, mix_rock=True))))
    V = [(x, y, zz("f", x) + 0.8) for x in xs for y in (-10.0, 10.0)]
    F = [(2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1) for i in range(len(xs) - 1)]
    temp(bpy.data.objects.new("torrent", _mesh_from("torrent", V, F, water_material())))
    for ob in a + b:
        pines_on_seats(ob, rng, scale=1.4)
    return a + b


def wall_chain_copy(kit, names, start, heading, top_z):
    """wall_chain with copies (the same module may appear several times)."""
    placed = []
    px, py, hd = start[0], start[1], heading
    for nm in names:
        src = kit[nm][0]
        ob = src.copy()
        temp_link(ob)
        ob.hide_render = False
        kind = nm.split("_")[1]
        Rc = {"convex": 70.0, "concave": -70.0}.get(kind, 0.0)
        hw = K.WALL_W / 2
        if Rc:
            a = hw / Rc
            left = (-Rc * math.sin(a), Rc * (1 - math.cos(a)))
            right = (Rc * math.sin(a), Rc * (1 - math.cos(a)))
            al, ar = -a, a
        else:
            left, right, al, ar = (-hw, 0.0), (hw, 0.0), 0.0, 0.0
        rot = hd - al
        c, s = math.cos(rot), math.sin(rot)
        ox = px - (c * left[0] - s * left[1])
        oy = py - (s * left[0] + c * left[1])
        ob.location = (ox, oy, top_z)
        ob.rotation_euler = (0, 0, rot)
        ob.scale = (1, 1, 1)
        placed.append(ob)
        px = ox + c * right[0] - s * right[1]
        py = oy + s * right[0] + c * right[1]
        hd = rot + ar
    return placed, (px, py, hd)


def scene_two_heights(kit, meta, look):
    hide_all()
    clear_temp()
    set_fog(0.00035)
    world_sky(1.2, clouds=True)
    rng = np.random.default_rng(3)
    br = kit["two_heights_bridge"][0]
    show(br, (0, 0, 0))
    hn, hs = kit["two_heights_head_n"][0], kit["two_heights_head_s"][0]
    # proposal: the heads stand BESIDE the deck's ends (D12 puts them on the deck's line)
    show(hn, (-40, 84, -4.0))
    show(hs, (42, -80, -8.0))
    pines_on_seats(hn, rng, scale=1.5, crown_scale=1.1)
    pines_on_seats(hs, rng, scale=1.5, crown_scale=1.1)
    gorge_for_bridge(kit, rng)
    # stand-in banners on the bridge's banner seats
    for s in json.loads(br["seats"]):
        if s["kind"] == "banner":
            x, y, z = s["pos"]
            if s.get("drop_m"):
                banner_card((x + 0.3 * s["face"][0], -z, y), math.radians(90), 3.0, 9.0, "#2d3d6e", "#a33a28")
            else:
                banner_card((x, -z, y + 4.5), math.radians(90), 1.2, 4.0, "#b07f2e", "#a33a28")
    # mist band 3 under the deck (stand-in card)
    mist = os.path.join(TEX, "mist_card.png")
    for k, (y, z, w) in enumerate(((0, -30, 260), (20, -55, 220), (-60, -20, 300))):
        card("mist%d" % k, mist, w, w * 0.22, (60 + 20 * k, y, z), math.radians(90 - 15 + 10 * k), strength=1.0)
    # V2's camera (vista_spec: (-380, 257, -600) looking yaw 107, pitch 0, vfov 34) relative to the bridge origin
    cam = camera((452.0, 137.5, -39.0), rot_deg=(90.0, 0.0, 107.0), fov_v=34.0)
    sun(200, 45, energy=2.4)
    labels = [label_at(cam, (12, 0, -100), ["two_heights_bridge", "%s tris / LOD1 %s" % (
        meta["pieces"]["two_heights_bridge"]["tris"], meta["pieces"]["two_heights_bridge"]["tris_lod1"]),
        ", ".join(meta["pieces"]["two_heights_bridge"]["materials"])])]
    render(os.path.join(look, "raw", "R06_two_heights_V2.png"))
    # the 3/4 overview from the south-east, higher
    cam = camera((260, -300, 120), (0, 0, -30), fov_v=40)
    render(os.path.join(look, "raw", "R06_two_heights_34.png"))
    # close-up: the maker signs on the north pier's east face, and the bolt plates with their offerings
    hx = K.pier_ring(-21.0)[1]
    cam = camera((hx + 16, K.PIER_Y - 3.0, -19.0), (hx, K.PIER_Y, -22.0), fov_v=38)
    sun(110, 30, energy=2.4)
    render(os.path.join(look, "raw", "R06_maker_signs.png"))
    silhouette(os.path.join(look, "raw", "R06_two_heights_V2_sil.png"), [br, hn, hs],
               (452.0, 137.5, -39.0), (0, 0, -20), fov=34)
    json.dump({"title": "R06 the Two Heights from V2's camera (telephoto 34°): the arched bridge on two piers, the "
                        "stone heads beside its ends, mist under the deck",
               "labels": labels, "sil": "R06_two_heights_V2_sil.png", "sil_name": "bridge + heads"},
              open(os.path.join(look, "raw", "R06_two_heights_V2.json"), "w"), indent=1, ensure_ascii=False)
    for t, ttl in (("R06_two_heights_34", "R06 the Two Heights from the south-east (stand-in gorge from R03 modules)"),
                   ("R06_maker_signs", "R06 the north pier's east face: two different maker signs (ours: the plumb "
                                       "and ring; the square and three steps), bolt plates with frayed offerings")):
        json.dump({"title": ttl, "labels": [], "sil": None}, open(os.path.join(look, "raw", t + ".json"), "w"),
                  ensure_ascii=False)


def scene_diorama(kit, meta, look):
    """Internal: towers over a river bend, cliff modules lining the gorge, the needle in the river, white stones in
    the shallows, mist cards at the towers' waists and over the water, far ranks fading in fog."""
    hide_all()
    clear_temp()
    set_fog(0.00055, NOON["fog"]["color"])
    world_sky(1.2, clouds=True)
    rng = np.random.default_rng(11)

    def xc(y):
        return 70.0 * math.sin(y / 240.0) - 20.0

    def dxc(y):
        return 70.0 / 240.0 * math.cos(y / 240.0)

    half = 34.0
    # terrain: banks at ~42 m rising into hills; the gorge floor at 0, the river at 1.2
    N = 220
    xs = np.linspace(-900, 900, N)
    ys = np.linspace(-500, 1500, N)
    X, Y = np.meshgrid(xs, ys)
    cx = 70.0 * np.sin(Y / 240.0) - 20.0
    d = np.abs(X - cx)
    hills = 42 + 18 * np.clip((d - half) / 300, 0, 1) ** 1.3 * (1 + 0.6 * np.sin(X / 140) * np.cos(Y / 170))
    bed = -1.2 * np.clip(1 - d / 16.0, 0, 1)
    Z = np.where(d < half - 1.0, bed, hills)
    V = [(X[i, j], Y[i, j], Z[i, j]) for i in range(N) for j in range(N)]
    F = [(i * N + j, i * N + j + 1, (i + 1) * N + j + 1, (i + 1) * N + j) for i in range(N - 1) for j in range(N - 1)]
    me = _mesh_from("terrain", V, F, ground_material(10.0, mix_rock=True))
    temp(bpy.data.objects.new("terrain", me))
    # river surface
    rv = []
    rf = []
    yy = np.linspace(-500, 1500, 120)
    for i, y in enumerate(yy):
        rv += [(xc(y) - half, y, 1.2), (xc(y) + half, y, 1.2)]
        if i:
            rf.append((2 * i - 2, 2 * i - 1, 2 * i + 1, 2 * i))
    temp(bpy.data.objects.new("river", _mesh_from("river", rv, rf, water_material())))
    # walls along both banks: one module every 38 m (2 m overlap), turned to the bank's tangent
    kinds = ["cliff_straight_60", "cliff_convex_60", "cliff_straight_60", "cliff_notch_75", "cliff_concave_75",
             "cliff_straight_60", "cliff_convex_60", "cliff_straight_75"]
    k = 0
    for side in (-1, 1):
        y = -380.0
        while y < 1150:
            t = Vector((dxc(y), 1.0, 0)).normalized()
            nm = kinds[k % len(kinds)]
            k += 1
            ob = kit[nm][0].copy()
            temp_link(ob)
            ob.hide_render = False
            px = xc(y) + side * half
            if side < 0:
                yaw = math.atan2(t.y, t.x)
            else:
                yaw = math.atan2(-t.y, -t.x)
            ob.location = (px, y, 42.0)
            ob.rotation_euler = (0, 0, yaw)
            pines_on_seats(ob, rng, scale=1.3)
            y += 38.0
    # the needle in the river at the bend
    nd = kit["bridge_needle"][0]
    show(nd, (xc(300) + 6, 300, 0))
    pines_on_seats(nd, rng, scale=1.0)
    # white stones in the shallows and on bars
    stones = kit["white_stones"][0]
    for i in range(260):
        y = rng.uniform(-260, 700)
        off = rng.normal(0, 13)
        if abs(off) > half - 2:
            continue
        src = stones[int(rng.choice(12, p=np.array([12, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2]) / 89.0))]
        ob = src.copy()
        temp_link(ob)
        ob.hide_render = False
        z = 0.0 if rng.random() > 0.2 else -0.25
        ob.location = (xc(y) + off, y, z - 1.2 * max(0, 1 - abs(off) / 16) * 0.8)
        ob.rotation_euler = (0, 0, math.atan2(1, dxc(y)) + rng.normal(0, 0.3))
        ob.scale = [rng.uniform(0.9, 1.3)] * 3
    # boulders on the rims
    for i in range(30):
        y = rng.uniform(-200, 900)
        side = rng.choice([-1, 1])
        nm = K.BOULDERS[int(rng.integers(0, 6))][0]
        ob = kit[nm][0].copy()
        temp_link(ob)
        ob.hide_render = False
        ob.location = (xc(y) + side * (half + rng.uniform(6, 30)), y, 42.0)
        ob.rotation_euler = (0, 0, rng.uniform(0, 6.28))
    # hero towers behind the gorge and on the hills; far ranks in fog
    for nm, (x, y, s, yaw) in {"karst_hero_c": (-330, 760, 1.0, 0.4), "karst_hero_b": (260, 560, 1.0, 2.0),
                               "karst_hero_a": (-210, 330, 1.0, 1.0), "karst_hero_d": (330, 980, 1.0, 3.0),
                               "karst_hero_e": (60, 1250, 1.1, 0.2)}.items():
        ob = kit[nm][0]
        show(ob, (x, y, 40.0), yaw=yaw, scale=s)
        pines_on_seats(ob, rng, scale=1.6, crown_scale=1.2)
    far = list(K.FAR.keys())
    for i in range(16):
        nm = far[i % 6]
        ob = kit[nm][0].copy()
        temp_link(ob)
        ob.hide_render = False
        ang = rng.uniform(-1.0, 1.0)
        dist = rng.uniform(1700, 4200)
        ob.location = (dist * math.sin(ang), 300 + dist * math.cos(ang), 30.0)
        ob.rotation_euler = (0, 0, rng.uniform(0, 6.28))
        ob.scale = [rng.uniform(0.9, 1.7)] * 3
    # broadleaf puffs on the banks and hills
    for i in range(140):
        y = rng.uniform(-300, 1200)
        side = rng.choice([-1, 1])
        x = xc(y) + side * (half + rng.uniform(4, 260))
        z = 42 + 18 * np.clip((abs(x - xc(y)) - half) / 300, 0, 1) ** 1.3 * (
            1 + 0.6 * math.sin(x / 140) * math.cos(y / 170))
        place_proto(proto_broadleaf(), (x, y, z - 0.5), rng.uniform(0.9, 1.6), rng.uniform(0, 6.28))
    # mist: over the water and round the towers' waists
    mist = os.path.join(TEX, "mist_card.png")
    for i, (x, y, z, w) in enumerate(((xc(150), 150, 12, 220), (xc(420), 420, 14, 260), (-280, 700, 120, 420),
                                      (220, 600, 95, 380), (0, 1000, 140, 600), (-150, 1400, 170, 800))):
        card("mist_d%d" % i, mist, w, w * 0.22, (x, y, z), rng.uniform(-0.2, 0.2), strength=1.05)
    cam = camera((xc(-330) + 10, -330, 70), (xc(250), 250, 40), fov_v=46)
    sun(200, 42, energy=2.4)
    render(os.path.join(look, "raw", "diorama.png"))
    json.dump({"title": "Internal diorama: the ROCK kit over a river bend (stand-in pines, mist and fall cards; "
                        "PAINT's and VILLAGE's pieces replace them)", "labels": [], "sil": None},
              open(os.path.join(look, "raw", "diorama.json"), "w"), ensure_ascii=False)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--look", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--no-export", action="store_true")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--pct", type=int, default=100)
    a = ap.parse_args(argv)
    os.makedirs(os.path.join(a.look, "raw"), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    print("ROCK_RENDER gltf kwargs", K._gltf_kwargs())
    kit = K.build_all(lods=not a.no_export)
    if not a.no_export:
        meta = K.export_all(kit, a.out)
    else:
        meta = json.load(open(os.path.join(a.out, "rock_kit.json")))
    for name, (l0, l1, grp) in kit.items():
        for ob in (l0 if isinstance(l0, list) else [l0]):
            to_render_materials(ob)
            ALL.append(ob)
        if l1 is not None:
            for ob in (l1 if isinstance(l1, list) else [l1]):
                ob.hide_render = True
    sc = setup_render(samples=a.samples)
    sc.render.resolution_percentage = a.pct
    only = set(a.only.split(",")) if a.only else None

    def want(t):
        return only is None or t in only

    if want("R01"):
        scene_towers(kit, meta, a.look, list(K.HERO.keys()), "R01_karst_hero",
                     "R01 karst hero towers (110-240 m): leaning, stacked slab tiers, fluting, undercuts; "
                     "stand-in pines on the kit's seats")
    if want("R02"):
        scene_towers(kit, meta, a.look, list(K.FAR.keys()), "R02_karst_far",
                     "R02 karst backdrop towers (modelled 200 m; scaled to the K heights)", spacing=25.0,
                     pines=True)
    if want("R03"):
        scene_walls(kit, meta, a.look)
    if want("R04"):
        scene_stones(kit, meta, a.look)
    if want("R06"):
        scene_two_heights(kit, meta, a.look)
    if want("D"):
        scene_diorama(kit, meta, a.look)
    print("ROCK_RENDER DONE")


if __name__ == "__main__":
    main()
