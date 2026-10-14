"""Review renders of the Thủy Vân village kit (VILLAGE): lineups, silhouettes, roof A/B/C and a small diorama, for the
owner to judge by eye (style guide section 11). Opens the kit .blend that village_kit.py saved (--blend there):

    zsh blender_run.sh -b <kit.blend> -P tools/thuyvan_art/village/render_village.py -- --out DIR \
        [--pages buildings,props,small,bridge,roofs,diorama] [--dirs noon,morning,dusk] [--fast]

Writes DIR/raw/<page>.png (Eevee, 1920 x 1080, bright game light on the painted grass), DIR/raw/<page>_sil/<piece>.png
(flat black silhouettes) and DIR/raw/<page>.json (each piece's screen position, triangles, material keys);
compose_village.py turns those into the labelled lineup sheets. The diorama (render-only ground, water, trees, mist,
far karst and sky; only the kit pieces are assets) renders once per light direction of palettes.json.
Deterministic: fixed seeds, fixed cameras.
"""

import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvkit  # noqa: E402
import village_kit as vk  # noqa: E402

PALJ = json.load(open(tvkit.PALETTES))
PAL = PALJ["albedo"]["r1"]
DIRS = {"noon": "bright_saturated_noon", "morning": "jade_mist_morning", "dusk": "golden_lantern_dusk"}
lin = tvkit.hex_lin


# ------------------------------------------------------------------------------------------------ scene basics
def kit_objects():
    """The kit's pieces in the .blend: top-level mesh objects named in the manifest (children are anchors/colliders)."""
    return {ob.name: ob for ob in bpy.data.objects if ob.type == "MESH" and ob.parent is None
            and not ob.get("render_only") and not ob.get("render_only_copy")}


def hide_all():
    for ob in bpy.data.objects:
        ob.hide_render = True
        ob.hide_viewport = False


def show(ob, loc=None, yaw=None):
    ob.hide_render = False
    for ch in ob.children:
        ch.hide_render = True          # anchors and colliders never render
    if loc is not None:
        ob.location = loc
    if yaw is not None:
        ob.rotation_euler = (0, 0, yaw)


def copy_of(ob, loc, yaw=0.0):
    c = ob.copy()                      # linked data: same mesh, own transform
    bpy.context.scene.collection.objects.link(c)
    c.location = loc
    c.rotation_euler = (0, 0, yaw)
    c.hide_render = False
    c["render_only_copy"] = True
    return c


def setup_render(fast=False, w=1920, h=1080):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 50 if fast else 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    ee = sc.eevee
    for k, v in (("taa_render_samples", 16 if fast else 48), ("use_shadows", True), ("shadow_ray_count", 2),
                 ("shadow_step_count", 8), ("use_raytracing", False), ("fast_gi_method", "GLOBAL_ILLUMINATION")):
        try:
            setattr(ee, k, v)
        except (AttributeError, TypeError):
            pass
    try:
        ee.use_fast_gi = True
    except AttributeError:
        pass
    vs = sc.view_settings
    vs.view_transform = "AgX"
    for look in ("AgX - Punchy", "AgX - Base Contrast", "None"):
        try:
            vs.look = look
            break
        except TypeError:
            continue
    print("VIEW", vs.view_transform, vs.look)
    vs.exposure = 0.0
    vs.gamma = 1.0


def sun(direction, az_deg=None, el_deg=None, strength=None, color=None, angle_deg=None):
    """A sun from compass azimuth (0 north = Blender +Y, 90 east = +X) and elevation, light colour and softness."""
    for ob in [o for o in bpy.data.objects if o.type == "LIGHT" and o.get("tv_sun")]:
        bpy.data.objects.remove(ob)
    d = DIR_DATA(direction)
    az = math.radians(az_deg if az_deg is not None else d["sun"]["azimuth_deg"])
    el = math.radians(el_deg if el_deg is not None else d["sun"]["elevation_deg"])
    v = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    li = bpy.data.lights.new("tv_sun", "SUN")
    li.energy = strength if strength is not None else d["sun"]["energy"] * 2.1
    li.color = lin(color or d["sun"]["color"])
    li.angle = math.radians(angle_deg if angle_deg is not None else d["sun"]["angular_deg"])
    try:
        li.shadow_soft_size = li.angle
    except AttributeError:
        pass
    ob = bpy.data.objects.new("tv_sun", li)
    ob["tv_sun"] = True
    ob.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(ob)
    return ob


def DIR_DATA(direction):
    return PALJ["directions"][DIRS[direction]]


def world(direction, clouds=True, amb_scale=1.0):
    """Painted sky for camera rays (zenith -> mid -> horizon gradient, soft noise cumulus in a band above the horizon)
    and a flat coloured ambient for everything else (sky contribution folded into the ambient's energy)."""
    d = DIR_DATA(direction)
    w = bpy.data.worlds.get("tv_world") or bpy.data.worlds.new("tv_world")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    sky = d["sky"]
    stops = [(0.0, sky["horizon"]), (0.1, sky["mid"]), (0.5, sky["zenith"]), (1.0, sky["zenith"])]
    if "low" in sky:
        stops = [(0.0, sky["horizon"]), (0.08, sky["low"]), (0.3, sky["mid"]), (0.8, sky["zenith"])]
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = stops[0][0], lin(stops[0][1]) + (1,)
    el[1].position, el[1].color = stops[-1][0], lin(stops[-1][1]) + (1,)
    for p, c in stops[1:-1]:
        e = el.new(p)
        e.color = lin(c) + (1,)
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -0.02
    mr.inputs["From Max"].default_value = 0.9
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs[0], ramp.inputs[0])
    skycol = ramp.outputs[0]
    if clouds:
        # big soft heaps: low-frequency noise on the view direction, squashed vertically, cut by a soft threshold,
        # lit on top (cloud_lit) and cool underneath (cloud_shade); only in a band above the horizon
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (2.2, 2.2, 6.0)
        nt.links.new(tc.outputs["Generated"], mp.inputs[0])
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 1.6
        nz.inputs["Detail"].default_value = 3.0
        nz.inputs["Roughness"].default_value = 0.45
        nt.links.new(mp.outputs[0], nz.inputs["Vector"])
        cut = nt.nodes.new("ShaderNodeMapRange")
        cut.inputs["From Min"].default_value = 0.5
        cut.inputs["From Max"].default_value = 0.56
        nt.links.new(nz.outputs["Fac"], cut.inputs["Value"])
        band = nt.nodes.new("ShaderNodeMapRange")    # 1 between 3 and 30 degrees, fading out above
        band.interpolation_type = "SMOOTHSTEP"
        band.inputs["From Min"].default_value = 0.55
        band.inputs["From Max"].default_value = 0.08
        nt.links.new(sep.outputs["Z"], band.inputs["Value"])
        band0 = nt.nodes.new("ShaderNodeMapRange")
        band0.interpolation_type = "SMOOTHSTEP"
        band0.inputs["From Min"].default_value = 0.0
        band0.inputs["From Max"].default_value = 0.06
        nt.links.new(sep.outputs["Z"], band0.inputs["Value"])
        m1 = nt.nodes.new("ShaderNodeMath")
        m1.operation = "MULTIPLY"
        nt.links.new(cut.outputs[0], m1.inputs[0])
        nt.links.new(band.outputs[0], m1.inputs[1])
        m2 = nt.nodes.new("ShaderNodeMath")
        m2.operation = "MULTIPLY"
        nt.links.new(m1.outputs[0], m2.inputs[0])
        nt.links.new(band0.outputs[0], m2.inputs[1])
        shade = nt.nodes.new("ShaderNodeMapRange")    # lit tops: the noise value above the cut
        shade.inputs["From Min"].default_value = 0.56
        shade.inputs["From Max"].default_value = 0.7
        nt.links.new(nz.outputs["Fac"], shade.inputs["Value"])
        cc = nt.nodes.new("ShaderNodeMix")
        cc.data_type = "RGBA"
        cc.inputs[6].default_value = lin(sky["cloud_shade"]) + (1,)
        cc.inputs[7].default_value = lin(sky["cloud_lit"]) + (1,)
        nt.links.new(shade.outputs[0], cc.inputs[0])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(m2.outputs[0], mix.inputs[0])
        nt.links.new(ramp.outputs[0], mix.inputs[6])
        nt.links.new(cc.outputs[2], mix.inputs[7])
        skycol = mix.outputs[2]
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(skycol, bg_cam.inputs["Color"])
    bg_cam.inputs["Strength"].default_value = 1.35
    bg_amb = nt.nodes.new("ShaderNodeBackground")
    a = d["ambient"]
    bg_amb.inputs["Color"].default_value = lin(a["color"]) + (1,)
    bg_amb.inputs["Strength"].default_value = a["energy"] * 0.75 * amb_scale
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
    nt.links.new(bg_amb.outputs[0], mx.inputs[1])
    nt.links.new(bg_cam.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])
    return w


def camera(loc, target, lens=35.0, ortho=None):
    cam = bpy.data.objects.get("tv_cam")
    if cam is None:
        cd = bpy.data.cameras.new("tv_cam")
        cam = bpy.data.objects.new("tv_cam", cd)
        bpy.context.scene.collection.objects.link(cam)
    cam.data.type = "ORTHO" if ortho else "PERSP"
    if ortho:
        cam.data.ortho_scale = ortho
    cam.data.lens = lens
    cam.data.clip_start = 0.1
    cam.data.clip_end = 6000
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


# ------------------------------------------------------------------------------------------------ render-only materials
def mat_textured(name, key_png, tile_m, tint=(1, 1, 1), extra_png=None, extra_tile=None, steep=(0.62, 0.8),
                 tint_attr=None, tint2=(1, 1, 1)):
    """Box-projected painted texture in object space (tile_m metres); `extra_png` on steep faces (normal z below
    steep); `tint_attr`: a colour attribute mixing between tint and tint2."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.95
    bsdf.inputs["Specular IOR Level"].default_value = 0.1
    tc = nt.nodes.new("ShaderNodeTexCoord")

    def img(png, tile):
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / tile,) * 3
        nt.links.new(tc.outputs["Object"], mp.inputs[0])
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(os.path.join(tvkit.TEX_DIR, png), check_existing=True)
        t.projection = "BOX"
        t.projection_blend = 0.25
        nt.links.new(mp.outputs[0], t.inputs[0])
        return t.outputs["Color"]

    c = img(key_png, tile_m)
    tn = nt.nodes.new("ShaderNodeMix")
    tn.data_type = "RGBA"
    tn.blend_type = "MULTIPLY"
    tn.inputs[0].default_value = 1.0
    nt.links.new(c, tn.inputs[6])
    if tint_attr:
        at = nt.nodes.new("ShaderNodeVertexColor")
        at.layer_name = tint_attr
        tm = nt.nodes.new("ShaderNodeMix")
        tm.data_type = "RGBA"
        tm.inputs[6].default_value = tuple(tint) + (1,)
        tm.inputs[7].default_value = tuple(tint2) + (1,)
        sp = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(at.outputs["Color"], sp.inputs[0])
        nt.links.new(sp.outputs[0], tm.inputs[0])
        nt.links.new(tm.outputs[2], tn.inputs[7])
    else:
        tn.inputs[7].default_value = tuple(tint) + (1,)
    col = tn.outputs[2]
    if extra_png:
        e = img(extra_png, extra_tile)
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        sp = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Normal"], sp.inputs[0])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = steep[1]
        mr.inputs["From Max"].default_value = steep[0]
        nt.links.new(sp.outputs["Z"], mr.inputs["Value"])
        mx = nt.nodes.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        nt.links.new(mr.outputs[0], mx.inputs[0])
        nt.links.new(col, mx.inputs[6])
        nt.links.new(e, mx.inputs[7])
        col = mx.outputs[2]
    nt.links.new(col, bsdf.inputs["Base Color"])
    return m


def mat_terrain(name):
    """Render-only ground: painted grass on the flats (terrace tops tinted yellow-green by the 'terr' attribute), painted
    limestone on steep faces at a 12 m tile, darkened and cooled toward the river (painted depth), cut by 7 m strata."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.95
    bsdf.inputs["Specular IOR Level"].default_value = 0.1
    tc = nt.nodes.new("ShaderNodeTexCoord")
    L = nt.links.new

    def img(png, tile):
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / tile,) * 3
        L(tc.outputs["Object"], mp.inputs[0])
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(os.path.join(tvkit.TEX_DIR, png), check_existing=True)
        t.projection = "BOX"
        t.projection_blend = 0.3
        L(mp.outputs[0], t.inputs[0])
        return t.outputs["Color"]

    def mix(fac, a, b_, mode="MIX"):
        n = nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.blend_type = mode
        if isinstance(fac, float):
            n.inputs[0].default_value = fac
        else:
            L(fac, n.inputs[0])
        for k, v in ((6, a), (7, b_)):
            if isinstance(v, tuple):
                n.inputs[k].default_value = v
            else:
                L(v, n.inputs[k])
        return n.outputs[2]

    def rng_(val, a0, a1, b0, b1, smooth=False):
        n = nt.nodes.new("ShaderNodeMapRange")
        if smooth:
            n.interpolation_type = "SMOOTHSTEP"
        n.inputs["From Min"].default_value, n.inputs["From Max"].default_value = a0, a1
        n.inputs["To Min"].default_value, n.inputs["To Max"].default_value = b0, b1
        L(val, n.inputs["Value"])
        return n.outputs[0]

    grass = img("grass.png", 4.0)
    at = nt.nodes.new("ShaderNodeVertexColor")
    at.layer_name = "terr"
    sp = nt.nodes.new("ShaderNodeSeparateColor")
    L(at.outputs["Color"], sp.inputs[0])
    grass = mix(sp.outputs[0], (1, 1, 1, 1), (1.55, 1.42, 0.5, 1), "MIX")
    grass = mix(1.0, img("grass.png", 4.0), grass, "MULTIPLY")
    rock = img("limestone.png", 12.0)
    sxyz = nt.nodes.new("ShaderNodeSeparateXYZ")
    L(tc.outputs["Object"], sxyz.inputs[0])
    depth = rng_(sxyz.outputs["Z"], FLOOR, 20.0, 0.0, 1.0)
    shade = mix(depth, lin(PAL["karst_limestone"][0]) + (1,), (1, 1, 1, 1))
    rock = mix(1.0, rock, shade, "MULTIPLY")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 0.045     # Blender's bands: period 2 pi / 20 / scale = 7 m
    wave.inputs["Distortion"].default_value = 2.0
    wave.inputs["Detail"].default_value = 0.0
    mp = nt.nodes.new("ShaderNodeMapping")
    L(tc.outputs["Object"], mp.inputs[0])
    L(mp.outputs[0], wave.inputs["Vector"])
    band = rng_(wave.outputs["Fac"], 0.0, 0.18, 0.62, 1.0)
    bandc = nt.nodes.new("ShaderNodeCombineColor")
    for k in range(3):
        L(band, bandc.inputs[k])
    rock = mix(1.0, rock, bandc.outputs[0], "MULTIPLY")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sn = nt.nodes.new("ShaderNodeSeparateXYZ")
    L(geo.outputs["Normal"], sn.inputs[0])
    steep = rng_(sn.outputs["Z"], 0.78, 0.55, 0.0, 1.0, smooth=True)
    L(mix(steep, grass, rock), bsdf.inputs["Base Color"])
    return m


def mat_puff(name, ramp, wrap=0.35):
    """Painted crown: the ramp by world normal z (dark under, mid body, light top), soft noise patches; render-only."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.05
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sp = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sp.inputs[0])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.9
    nz.inputs["Detail"].default_value = 1.0
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "MULTIPLY_ADD"
    nt.links.new(nz.outputs["Fac"], add.inputs[0])
    add.inputs[1].default_value = 0.5
    nt.links.new(sp.outputs["Z"], add.inputs[2])
    cr = nt.nodes.new("ShaderNodeValToRGB")
    e = cr.color_ramp.elements
    e[0].position, e[0].color = 0.05, lin(ramp[0]) + (1,)
    e[1].position, e[1].color = 1.15, lin(ramp[3]) + (1,)
    e.new(0.45).color = lin(ramp[1]) + (1,)
    e.new(0.85).color = lin(ramp[2]) + (1,)
    cr.color_ramp.interpolation = "CONSTANT"
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -0.5
    mr.inputs["From Max"].default_value = 1.6
    nt.links.new(add.outputs[0], mr.inputs["Value"])
    nt.links.new(mr.outputs[0], cr.inputs[0])
    nt.links.new(cr.outputs[0], bsdf.inputs["Base Color"])
    return m


def mat_flat(name, hexcol, rough=0.9, alpha=None, emit=0.0, fog=None):
    """Flat colour; `fog` = (hex, start_m, end_m) mixes toward the fog colour by camera distance (backdrop only)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(hexcol) + (1,)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Specular IOR Level"].default_value = 0.1
    if emit:
        b.inputs["Emission Color"].default_value = lin(hexcol) + (1,)
        b.inputs["Emission Strength"].default_value = emit
    if alpha is not None:
        b.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    if fog:
        cd = nt.nodes.new("ShaderNodeCameraData")
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = fog[1]
        mr.inputs["From Max"].default_value = fog[2]
        mr.inputs["To Max"].default_value = fog[3] if len(fog) > 3 else 0.85
        nt.links.new(cd.outputs["View Distance"], mr.inputs["Value"])
        ms = nt.nodes.new("ShaderNodeMixShader")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = lin(fog[0]) + (1,)
        em.inputs["Strength"].default_value = 1.0
        out = nt.nodes["Material Output"]
        nt.links.new(mr.outputs[0], ms.inputs[0])
        nt.links.new(b.outputs[0], ms.inputs[1])
        nt.links.new(em.outputs[0], ms.inputs[2])
        nt.links.new(ms.outputs[0], out.inputs["Surface"])
    return m


def mat_cardfx(name, hexcol, alpha=0.6, stretch=(1.0, 1.0), streak=False, strength=1.0, edge=True):
    """Unshaded soft card (mist, falls, spray): emission colour, alpha from low-frequency noise x edge falloff."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.surface_render_method = "BLENDED"
    try:
        m.use_transparency_overlap = True
    except AttributeError:
        pass
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (stretch[0], stretch[1], 1)
    nt.links.new(tc.outputs["UV"], mp.inputs[0])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 3.0
    nz.inputs["Detail"].default_value = 2.0
    nt.links.new(mp.outputs[0], nz.inputs["Vector"])
    a = nt.nodes.new("ShaderNodeMapRange")
    a.inputs["From Min"].default_value = 0.35 if not streak else 0.25
    a.inputs["From Max"].default_value = 0.65
    a.inputs["To Max"].default_value = alpha
    nt.links.new(nz.outputs["Fac"], a.inputs["Value"])
    fac = a.outputs[0]
    if edge:
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["UV"], sep.inputs[0])
        prod = None
        for comp, lo in (("X", 0.18), ("Y", 0.3)):
            for inv in (False, True):
                r = nt.nodes.new("ShaderNodeMapRange")
                r.interpolation_type = "SMOOTHSTEP"
                r.inputs["From Min"].default_value = 1.0 if inv else 0.0
                r.inputs["From Max"].default_value = 1.0 - lo if inv else lo
                nt.links.new(sep.outputs[comp], r.inputs["Value"])
                if prod is None:
                    prod = r.outputs[0]
                else:
                    mm = nt.nodes.new("ShaderNodeMath")
                    mm.operation = "MULTIPLY"
                    nt.links.new(prod, mm.inputs[0])
                    nt.links.new(r.outputs[0], mm.inputs[1])
                    prod = mm.outputs[0]
        mm = nt.nodes.new("ShaderNodeMath")
        mm.operation = "MULTIPLY"
        nt.links.new(fac, mm.inputs[0])
        nt.links.new(prod, mm.inputs[1])
        fac = mm.outputs[0]
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = lin(hexcol) + (1,)
    em.inputs["Strength"].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(fac, mx.inputs[0])
    nt.links.new(tr.outputs[0], mx.inputs[1])
    nt.links.new(em.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs["Surface"])
    return m


def mesh_from(name, verts, faces, mat=None, uvs=None, smooth=True, attrs=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(map(float, v)) for v in verts], [], faces)
    me.update()
    if smooth:
        me.shade_smooth()
    if uvs is not None:
        uvl = me.uv_layers.new(name="UVMap")
        k = 0
        for p in me.polygons:
            for li in p.loop_indices:
                uvl.data[li].uv = uvs[me.loops[li].vertex_index]
                k += 1
    for an, vals in (attrs or {}).items():
        ca = me.color_attributes.new(an, "FLOAT_COLOR", "POINT")
        data = np.zeros((len(verts), 4), np.float32)
        data[:, :3] = np.asarray(vals)[:, None]
        data[:, 3] = 1
        ca.data.foreach_set("color", data.ravel())
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        me.materials.append(mat)
    ob["render_only"] = True
    return ob


def ground_plane(size=400.0, z=0.0):
    m = mat_textured("tv_ground_grass", "grass.png", 4.0)
    s = size / 2
    return mesh_from("tv_ground", [(-s, -s, z), (s, -s, z), (s, s, z), (-s, s, z)], [(0, 1, 2, 3)], m, smooth=False)


def puff_tree(name, base, height, crown_r, n_puffs, ramp, rng, pine=False, trunk_r=None):
    """Render-only stand-in tree (PAINT builds the real ones): a trunk and 3-7 round puffs (pine: flat tiers)."""
    bm = bmesh.new()
    base = np.asarray(base, float)
    tr = trunk_r or height * 0.035
    top = base + [rng.normal(0, 0.06) * height, rng.normal(0, 0.06) * height, height * (0.72 if not pine else 0.9)]
    bmesh.ops.create_cone(bm, segments=7, radius1=tr * 1.3, radius2=tr * 0.7, depth=float(np.linalg.norm(top - base)),
                          cap_ends=False)
    d = (top - base)
    q = Vector(tuple(d)).to_track_quat("Z", "Y")
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=q.to_matrix())
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(tuple((base + top) / 2)))
    trunk_faces = len(bm.faces)
    for k in range(n_puffs):
        if pine:
            t = k / max(n_puffs - 1, 1)
            c = base + (top - base) * (0.55 + 0.45 * t) + [rng.normal(0, crown_r * 0.25), rng.normal(0, crown_r * 0.25), 0]
            r = crown_r * (1.0 - 0.45 * t)
            sc = (1.0, 1.0, 0.42)
        else:
            a = rng.uniform(0, 2 * math.pi)
            rr = crown_r * (0.0 if k == 0 else rng.uniform(0.45, 0.75))
            c = top + [rr * math.cos(a), rr * math.sin(a), (crown_r * 0.35 if k == 0 else rng.uniform(-0.35, 0.2) * crown_r)]
            r = crown_r * (0.85 if k == 0 else rng.uniform(0.5, 0.7))
            sc = (1.0, 1.0, 0.85)
        res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
        for v in res["verts"]:
            v.co = Vector((v.co.x * sc[0], v.co.y * sc[1], v.co.z * sc[2])) + Vector(tuple(c))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.materials.append(mat_flat("tv_bark", PAL["bark"][1]))
    me.materials.append(mat_puff("tv_puff_" + ("pine" if pine else "broadleaf"), ramp))
    for i, p in enumerate(me.polygons):
        p.material_index = 0 if i < trunk_faces else 1
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["render_only"] = True
    return ob


def figure_marker(loc, yaw=0.0):
    """The 1.75 m scale figure beside every asset: the kit's own standing porter."""
    ob = bpy.data.objects.get("porter_standing")
    return copy_of(ob, loc, yaw)


# ------------------------------------------------------------------------------------------------ silhouettes
def silhouettes(objs, folder, cam_loc, cam_target, lens):
    """Each object alone as a flat black shape (Workbench, transparent film); compose_village.py scales it to 64 px."""
    sc = bpy.context.scene
    keep = (sc.render.engine, sc.render.film_transparent, sc.view_settings.view_transform)
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sh = sc.display.shading
    sh.light = "FLAT"
    sh.color_type = "SINGLE"
    sh.single_color = (0, 0, 0)
    sh.show_shadows = False
    sh.show_cavity = False
    sh.show_object_outline = False
    vis = {o.name: o.hide_render for o in bpy.data.objects}
    os.makedirs(folder, exist_ok=True)
    for nm, ob in objs.items():
        for o in bpy.data.objects:
            o.hide_render = True
        ob.hide_render = False
        # frame it: camera at the same 3/4 direction, distance fit to its size
        bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        ctr = sum(bb, Vector()) / 8
        rad = max((b - ctr).length for b in bb)
        dirv = (Vector(cam_loc) - Vector(cam_target)).normalized()
        camera(ctr + dirv * rad * 3.2, ctr, lens=lens)
        sc.render.filepath = os.path.join(folder, nm + ".png")
        bpy.ops.render.render(write_still=True)
    for o in bpy.data.objects:
        o.hide_render = vis.get(o.name, True)
    sc.render.engine, sc.render.film_transparent, sc.view_settings.view_transform = keep


# ------------------------------------------------------------------------------------------------ lineup pages
def screen_xy(cam, p):
    from bpy_extras.object_utils import world_to_camera_view
    v = world_to_camera_view(bpy.context.scene, cam, Vector(p))
    return [round(v.x, 4), round(1 - v.y, 4)]


def info_of(ob):
    return {"tris": tvkit.tri_count(ob), "materials": [m.name[4:] for m in ob.data.materials if m],
            "size_m": [round(v, 2) for v in ob.dimensions]}


def lineup(page, names, spacing, cam_dist, cam_h, lens, out, fast, figure_gap=1.2, target_z=None, row_y=0.0,
           extra=None, sil=True):
    """Pieces in a row along X on the painted grass, each with the scale figure on its left; 3/4 view from the
    front-left, sun from the front-left at 40 degrees."""
    hide_all()
    for o in [o for o in bpy.data.objects if o.get("render_only") or o.get("render_only_copy")]:
        bpy.data.objects.remove(o)
    objs = kit_objects()
    ground_plane()
    x = 0.0
    placed = {}
    widths = []
    for nm in names:
        ob = objs[nm]
        w = ob.dimensions.x
        widths.append(w)
    total = sum(widths) + spacing * (len(names) - 1) + figure_gap
    x = -total / 2 + figure_gap
    tops = []
    for nm, w in zip(names, widths):
        ob = objs[nm]
        bb = [Vector(c) for c in ob.bound_box]
        minx = min(b.x for b in bb)
        miny = min(b.y for b in bb)
        maxy = max(b.y for b in bb)
        minz = min(b.z for b in bb)
        loc = (x - minx, row_y - (miny + maxy) / 2, -minz if minz > 0.0 or nm.startswith(("lantern_round", "lantern_b", "prayer")) else 0.0)
        show(ob, loc, 0.0)
        figure_marker((x - figure_gap, row_y - (maxy - miny) / 2 - 0.6, 0.0))
        placed[nm] = ob
        tops.append(max(b.z for b in bb) + loc[2])
        x += w + spacing
    if extra:
        extra(placed)
    hmax = max(tops)
    tz = target_z if target_z is not None else hmax * 0.42
    half_fov = math.atan(18.0 / lens)
    fit = (total / 2 + 0.6) / math.tan(half_fov)                # the whole row in frame
    if fit > cam_dist:
        cam_h *= fit / cam_dist
        cam_dist = fit
    cam_loc = (0.0, row_y - cam_dist, cam_h)
    cam = camera(cam_loc, (0, row_y, tz), lens=lens)
    world("noon")
    sun("noon", az_deg=215, el_deg=40, strength=4.6, color="#fff3d9", angle_deg=1.5)
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(out, page + ".png")
    bpy.ops.render.render(write_still=True)
    meta = {"page": page, "pieces": {}}
    for nm, ob in placed.items():
        bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        foot = Vector((sum(b.x for b in bb) / 8, min(b.y for b in bb), 0.0))
        meta["pieces"][nm] = dict(info_of(ob), screen=screen_xy(cam, foot))
    with open(os.path.join(out, page + ".json"), "w") as f:
        json.dump(meta, f, indent=1)
    if sil:
        silhouettes(placed, os.path.join(out, page + "_sil"), cam_loc, (0, row_y, tz), lens)
    return meta


# ------------------------------------------------------------------------------------------------ roof A/B/C
def roof_variants(out, fast):
    """Open choice: the roof's curve. A restrained, B the kit's default, C bold. Same house otherwise."""
    specs = (("roofA_restrained", 0.12, 0.05, 0.9, 0.8), ("roofB_default", 0.55, 0.3, 1.25, 0.92),
             ("roofC_bold", 1.35, 0.85, 1.6, 1.3))
    objs = kit_objects()
    for nm, up, fl, over, pp in specs:
        if nm in objs:
            continue
        b, h = vk.stilt_house(nm, 5.4, 4.2, 2.0, 2.3, "thatch", 4.2, over, 1.3, 11, upturn=up, flare=fl,
                              roof_p=pp)
        ob = b.obj()
        tvkit.bake_vertex_ao(ob, dist=2.0)
    return [s[0] for s in specs]


# ------------------------------------------------------------------------------------------------ the diorama
def H_ground(x, y):
    """Diorama ground (Blender metres, Z up): a gorge 22 m wide along Y with sheer walls, the west upland at 20 m,
    the east bank at 20 m rising in terraces round a hill to the east; house pads flattened."""
    gx = abs(x)
    wall = WALL(y)
    t = min(max((gx - wall) / 1.6, 0.0), 1.0)
    bank = 20.0 + (0.6 * math.sin(x * 0.07 + y * 0.05))
    z = FLOOR + (bank - FLOOR) * (t * t * (3 - 2 * t))
    # a ledge two thirds down the west wall (every third band a ledge with green)
    if x < 0 and wall - 0.2 < gx < wall + 1.2:
        z = max(z, 6.0 if (gx - wall) > 0.3 else z)
    # east terraces round a hill centred (52, 12)
    if x > wall + 4:
        r = math.hypot(x - 52.0, (y - 12.0) * 0.85)
        hill = max(0.0, 16.0 * (1.0 - r / 42.0))
        step = STEP
        hz = math.floor(hill / step) * step
        ramp = min(max((x - wall - 12) / 10.0, 0.0), 1.0)     # a level bridge head, then the steps
        z += hz * ramp
    # west upland: a gentle rise behind the lip
    if x < -wall - 6:
        z += min((-x - wall - 6) * 0.12, 4.0)
    # beyond the diorama's core: rolling forested upland (keeps the frame free of an island edge)
    out = max(-80 - x, x - 100, -70 - y, y - 90, 0.0)
    if out > 0 and gx > wall:
        z += min(out / 40.0, 1.0) * (9.0 * math.sin(x * 0.021 + 1.3) * math.cos(y * 0.017) + 6.0)
    for (px, py, pr, pz) in PADS:
        d = math.hypot(x - px, y - py)
        if d < pr + 4.0:
            k = min(max((d - pr) / 4.0, 0.0), 1.0)
            k = k * k * (3 - 2 * k)
            z = pz * (1 - k) + z * k
    # the gorge floor: river bed with a shingle bar
    if gx < wall:
        z = FLOOR + 1.2 * (gx / wall) ** 2 + (1.4 if (1.5 < x < 9 and -34 < y < -10) else 0.0)
    return z


PADS = []      # (x, y, radius, z) filled in diorama()
FLOOR = -12.0  # the river bed; the water at WATER
WATER = -10.4
STEP = 1.2     # terrace step = the wall module's height


def WALL(y):
    """Half-width of the gorge at y: a meander plus vertical fluting of the walls."""
    return 11.0 + 0.9 * math.sin(y * 0.11) + 0.6 * math.sin(y * 0.29 + 1.0) + 0.45 * math.sin(y * 0.9) + 0.25 * math.sin(y * 2.3)


def terrain_mesh():
    xs = sorted(set(list(np.arange(-320, -80, 5.0)) + list(np.arange(-80, -16, 1.5)) + list(np.arange(-16, 16, 0.4)) +
                    list(np.arange(16, 100, 0.6)) + list(np.arange(100, 320, 5.0))))
    ys = sorted(set(list(np.arange(-160, -70, 5.0)) + list(np.arange(-70, 90, 0.6)) + list(np.arange(90, 460, 5.0))))
    verts, faces, terr = [], [], []
    nx = len(xs)
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            z = H_ground(x, y)
            verts.append((x, y, z))
            gx = abs(x)
            terr.append(1.0 if (x > 15 and z > 20.8 and not any(math.hypot(x - p[0], y - p[1]) < p[2] + 1 for p in PADS)) else 0.0)
    for j in range(len(ys) - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + 1 + nx, a + nx))
    m = mat_terrain("tv_ground_terrain")
    ob = mesh_from("tv_terrain", verts, faces, m, smooth=True, attrs={"terr": terr})
    return ob


def ground_z(x, y):
    return H_ground(x, y)


def diorama(out, directions, fast):
    rng = np.random.default_rng(7)
    hide_all()
    for o in [o for o in bpy.data.objects if o.get("render_only") or o.get("render_only_copy")]:
        bpy.data.objects.remove(o)
    objs = kit_objects()
    PADS.clear()
    PADS.extend([(-21.0, 2.0, 6.5, 20.0), (34.0, 16.0, 6.0, 0.0), (44.0, -6.0, 6.0, 0.0), (52.0, 26.0, 7.5, 0.0),
                 (-36.0, 26.0, 10.0, 0.0)])
    # pads on the hill take the terraced height there (computed before they flatten)
    for k, (px, py, pr, pz) in enumerate(list(PADS)):
        if pz == 0.0:
            saved = PADS[:]
            PADS.clear()
            z = H_ground(px, py)
            PADS.extend(saved)
            PADS[k] = (px, py, pr, z)
    terrain_mesh()
    place = []

    def put(nm, x, y, yaw, z=None, copy=False):
        ob = objs[nm]
        zz = ground_z(x, y) if z is None else z
        if copy or ob.get("_used"):
            c = copy_of(ob, (x, y, zz), yaw)
            place.append(c)
            return c
        ob["_used"] = True
        show(ob, (x, y, zz), yaw)
        place.append(ob)
        return ob
    for ob in objs.values():
        if "_used" in ob:
            del ob["_used"]
    # the rope bridge across the gorge: 30 m span between two anchors on the 20 m lips
    put("rope_bridge_span_30m", -15.0, -2.0, 0.0, z=20.0)
    put("rope_bridge_anchor", -15.0, -2.0, 0.0, z=20.0)
    put("rope_bridge_anchor", 15.0, -2.0, math.pi, z=20.0, copy=True)
    put("gate_pavilion", -20.5, -2.0, math.pi / 2, z=20.0)
    # cliff houses hung on the west lip (drop toward +X), the clan house on the upland behind
    wall_at = WALL
    # the lip is where the wall's 1.6 m shoulder meets the bank; the braces' sockets then land in the rock face
    lip = lambda y: max(wall_at(y + dy) for dy in np.linspace(-3.6, 3.6, 13)) + 1.25
    put("cliff_house", -lip(-16), -16.0, math.pi / 2, z=20.0)
    put("cliff_house", -lip(13), 13.0, math.pi / 2, z=20.0, copy=True)
    put("clan_house", -36.0, 26.0, -0.25)
    for (x, y) in ((-29.5, 18.5), (-26.0, 14.0)):
        put("lantern_post", x, y, 0.4, copy=True)
    put("banner_indigo", -31.0, 17.5, 0.0)
    put("banner_jade", -41.0, 17.0, 0.0)
    # east head: the waystone and its flags, banners, a bridge lamp
    put("clan_waystone", 21.5, -9.5, 0.35)
    put("banner_ochre", 18.5, 3.0, 0.0)
    put("bridge_lamp", 17.5, -4.2, 0.0)
    # the village on the terraces
    put("stilt_house_small", 34.0, 16.0, -0.35)
    put("stilt_house_small", 44.0, -6.0, 0.25, copy=True)
    put("stilt_house_large", 52.0, 26.0, -0.15)
    put("drying_rack", 38.5, 9.5, -0.35)
    put("firewood_pile", 31.0, 22.0, 0.4)
    put("water_jars", 40.0, -1.0, 0.2)
    put("basket_set", 36.5, 11.0, 0.0)
    for k in range(5):
        put("fence_bamboo_3m", 26.5 + k * 2.9, 3.0 + k * 0.6, 0.2, copy=True)
    put("fence_wattle_2m", 47.5, 0.5, 1.2)
    put("lantern_post", 29.0, 6.0, 0.0, copy=True)
    put("prayer_flags_12m", 26.0, -1.0, 0.25, z=ground_z(26.0, -1.0) + 3.4)
    # terrace walls along the steps (straight modules set tangent to the step circles)
    hill = (52.0, 12.0)
    count = 0
    for ring in range(1, 12):
        r = 42.0 * (1 - ring * STEP / 16.0) + 0.35
        for a in np.arange(math.radians(150), math.radians(250), 4.0 / max(r, 4)):
            x = hill[0] + r * math.cos(a)
            y = hill[1] + r * math.sin(a) / 0.85
            if x < WALL(y) + 23 or any(math.hypot(x - p[0], y - p[1]) < p[2] + 2.5 for p in PADS):
                continue
            yaw = a + math.pi / 2          # the module's front (-Y) faces out, down the hill
            zlo = H_ground(x + 0.8 * math.cos(a), y + 0.8 * math.sin(a))
            put("terrace_wall_curve_out_4m" if r < 14 else "terrace_wall_straight_4m", x, y, yaw, z=zlo, copy=True)
            count += 1
    # the river: pale jade water over white stones, the sampan beached on the shingle bar
    wat = mat_flat("tv_water", PAL["water_depth"][2], rough=0.12, alpha=0.78)
    mesh_from("tv_river", [(-14, -160, WATER), (14, -160, WATER), (14, 460, WATER), (-14, 460, WATER)], [(0, 1, 2, 3)],
              wat, smooth=False)
    deep = mat_flat("tv_riverbed", PAL["water_depth"][1], rough=0.9)
    bed = bpy.data.objects["tv_terrain"].data
    stone = mat_flat("tv_whitestone", PAL["white_stone"][2], rough=0.8)
    bm = bmesh.new()
    for k in range(260):
        y = rng.uniform(-60, 80)
        x = rng.uniform(-9, 9)
        if abs(x) > wall_at(y) - 1.0:
            continue
        s = rng.uniform(0.3, 1.6) * (1.6 if rng.random() < 0.15 else 1.0)
        res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        R = tvkit.rot_z(rng.uniform(0, 3))
        for v in res["verts"]:
            p = np.array([v.co.x * s, v.co.y * s * rng.uniform(0.7, 1.0), v.co.z * s * 0.45])
            p = R @ p + [x, y, H_ground(x, y) + s * 0.12]
            v.co = Vector(tuple(p))
    me = bpy.data.meshes.new("tv_stones")
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.materials.append(stone)
    so = bpy.data.objects.new("tv_stones", me)
    so["render_only"] = True
    bpy.context.scene.collection.objects.link(so)
    put("sampan", 5.5, -22.0, 0.3, z=H_ground(5.5, -22.0) + 0.05)
    # porters: one on the bridge, one with a pole on the east path, one by the clan house
    zt = vk.deck_z(0.38, 30.0, 0.0, 30.0 / 14.0)
    put("porter_walking", -15.0 + 0.38 * 30.0, -2.0, math.pi / 2, z=20.0 + zt)
    put("porter_pole", 24.0, 1.0, math.pi / 2)
    put("porter_standing", -31.5, 21.0, 0.6)
    # a waterfall off the west wall into the river, with spray at its foot (render-only cards)
    fall = mat_cardfx("tv_fall", PAL["foam_fall"][2], alpha=0.92, stretch=(1.0, 0.12), streak=True, strength=1.0)
    fy = 24.0
    fx = -wall_at(fy) + 0.3
    v, f, uv = [], [], []
    n = 12
    for i in range(n + 1):
        t = i / n
        z = 20.6 - t * (20.6 - WATER)
        out_ = 0.3 + 3.2 * t ** 0.6
        for s_ in (-1, 1):
            v.append((fx + out_, fy + s_ * (3.0 + 2.2 * t), z))
            uv.append((0.5 + 0.5 * s_, 1 - t))
    for i in range(n):
        a = 2 * i
        f.append((a, a + 1, a + 3, a + 2))
    mesh_from("tv_fall", v, f, fall, uvs=uv, smooth=True)
    spray = mat_cardfx("tv_spray", PAL["mist"][3], alpha=0.75, strength=1.0)
    for k in range(5):
        c = (fx + 4.0 + rng.normal(0, 1.2), fy + rng.normal(0, 2.5), WATER + 1.2 + k * 0.9)
        sz = rng.uniform(4.0, 6.5)
        cam_face = [(c[0] - sz, c[1], c[2] - sz * 0.6), (c[0] + sz, c[1], c[2] - sz * 0.6),
                    (c[0] + sz, c[1], c[2] + sz * 0.6), (c[0] - sz, c[1], c[2] + sz * 0.6)]
        o = mesh_from("tv_spray%d" % k, cam_face, [(0, 1, 2, 3)], spray, uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
        o.rotation_euler = (0, 0, -0.55)
    # trees: broadleaf puffs on the banks and hill, umbrella pines on the cliff lips and ledge (render-only stand-ins)
    spots = []
    cands = []
    for c in range(16):                      # groves in the core, then a forest over the upland skirt
        cx, cy = rng.uniform(-80, 98), rng.uniform(-60, 88)
        for t in range(int(rng.integers(3, 8))):
            cands.append((cx + rng.normal(0, 5), cy + rng.normal(0, 5)))
    for c in range(45):
        cx, cy = rng.uniform(-300, 300), rng.uniform(-150, 440)
        if -90 < cx < 110 and -80 < cy < 100:
            continue
        for t in range(int(rng.integers(4, 10))):
            cands.append((cx + rng.normal(0, 9), cy + rng.normal(0, 9)))
    for (x, y) in cands:
        if abs(x) < wall_at(y) + 2.0 or any(math.hypot(x - p[0], y - p[1]) < p[2] + 3 for p in PADS):
            continue
        if -26 < x < -12 and -8 < y < 4:
            continue
        if any(math.hypot(x - cx_, y - cy_) < 16 for (cx_, cy_) in ((34, -60), (20, -62), (6, -58), (24, -26))):
            continue
        if 0 < x < 34 and -50 < y < -6:          # the bridge view's foreground
            continue
        if 12 < x < 30 and -14 < y < 6:
            continue
        spots.append((x, y))
    for k, (x, y) in enumerate(spots):
        pine = abs(x) < wall_at(y) + 7 or rng.random() < 0.35
        h = rng.uniform(6, 11) if pine else rng.uniform(8, 15)
        puff_tree("tv_tree%d" % k, (x, y, ground_z(x, y) - 0.3), h, h * (0.32 if pine else 0.3),
                  3 if pine else int(rng.integers(3, 7)), PAL["pine"] if pine else PAL["broadleaf"], rng, pine=pine)
    # far karst ranks behind, on arcs round the hero camera's view (ROCK builds the real towers): stacked leaning slab
    # tiers stepping in, a rounded crown with dark pine puffs, fog-stepped flat colour per rank
    HERO = ((22.0, -62.0, 50.0), (0.0, 10.0, 8.0), 26.0)

    def tower(name, base, h, w, lean, tiers, col, pinecol, fog, seed):
        r_ = np.random.default_rng(seed)
        bm = bmesh.new()
        z0 = 0.0
        ox = oy = 0.0
        ledges = []
        for t in range(tiers):
            hh = h / tiers * (1.2 if t == 0 else r_.uniform(0.85, 1.05))
            r0 = w / 2 * (1 - 0.15 * t)
            r1 = r0 * r_.uniform(0.74, 0.86)
            res = bmesh.ops.create_cone(bm, segments=8, radius1=r0, radius2=r1, depth=hh, cap_ends=True)
            for vv in res["verts"]:
                vv.co.x *= r_.uniform(0.85, 1.15)
                vv.co.z += z0 + hh / 2
                vv.co.x += ox + math.tan(lean) * vv.co.z
                vv.co.y += oy
            z0 += hh * 0.96
            ledges.append((ox + math.tan(lean) * z0, oy, z0, r1))
            ox += r_.normal(0, w * 0.05)
            oy += r_.normal(0, w * 0.05)
        cx_, cy_, cz_, cr_ = ledges[-1]
        res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=cr_ * 0.85)
        for vv in res["verts"]:
            vv.co = Vector((vv.co.x + cx_, vv.co.y + cy_, vv.co.z * 0.5 + cz_))
        nrock = len(bm.faces)
        for (lx, ly, lz, lr) in ledges:       # pine puffs on every ledge rim and the crown (the sheets' green tops)
            for k in range(int(r_.integers(3, 7))):
                a = r_.uniform(0, 2 * math.pi)
                rr = lr * r_.uniform(0.55, 0.95)
                res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=w * r_.uniform(0.12, 0.2))
                for vv in res["verts"]:
                    vv.co = Vector((vv.co.x + lx + rr * math.cos(a), vv.co.y + ly + rr * math.sin(a),
                                    vv.co.z * 0.7 + lz + w * 0.04))
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat_flat("tv_far_%s" % col, col, fog=fog))
        me.materials.append(mat_flat("tv_far_%s" % pinecol, pinecol, fog=fog))
        for i_, pp in enumerate(me.polygons):
            pp.material_index = 0 if i_ < nrock else 1
        ob = bpy.data.objects.new(name, me)
        ob.location = base
        ob["render_only"] = True
        bpy.context.scene.collection.objects.link(ob)
    results = {}
    for dname in directions:
        d = DIR_DATA(dname)
        # backdrop colours per direction: far karst in its fog colour (rebuilt per direction)
        for o in [o for o in bpy.data.objects if o.name.startswith("tv_karst")]:
            bpy.data.objects.remove(o)
        for m in [m for m in bpy.data.materials if m.name.startswith("tv_far_")]:
            bpy.data.materials.remove(m)
        trng = np.random.default_rng(11)
        fogc = d["fog"]["color"]
        cam, tgt = Vector(HERO[0]), Vector(HERO[1])
        fwd = Vector((tgt.x - cam.x, tgt.y - cam.y, 0)).normalized()
        ranks = ((230.0, 34.0, 0.0, d["targets"]["mid_karst_lit"], PAL["pine"][1], 0.08),
                 (420.0, 70.0, 0.0, d["targets"]["mid_karst_lit"], PAL["pine"][1], 0.3),
                 (700.0, 120.0, 0.0, d["targets"]["far_karst"], d["targets"]["karst_shade"], 0.6),
                 (1100.0, 190.0, 0.0, d["targets"]["far_karst"], d["targets"]["far_karst"], 0.8))
        k = 0
        for (dist, hgt, _, col, pc, fogk) in ranks:
            n = 9 if dist < 500 else 12
            for i_ in range(n):
                ang = math.radians(-42 + 84 * (i_ + trng.uniform(0.1, 0.9)) / n)
                dd = dist * trng.uniform(0.85, 1.15)
                dirv = Vector((fwd.x * math.cos(ang) - fwd.y * math.sin(ang), fwd.x * math.sin(ang) + fwd.y * math.cos(ang), 0))
                p = cam + dirv * dd
                h = hgt * trng.uniform(0.75, 1.3)
                tower("tv_karst%d" % k, (p.x, p.y, -20.0), h, h / trng.uniform(2.4, 3.6),
                      math.radians(trng.choice([-1, 1]) * trng.uniform(5, 15)), int(trng.integers(3, 6)), col, pc,
                      (fogc, dd * 0.6, dd * 1.4, fogk), 100 + k)
                k += 1
        # mist bands: in the gorge and round the far towers
        for o in [o for o in bpy.data.objects if o.name.startswith("tv_mist")]:
            bpy.data.objects.remove(o)
        for m in [m for m in bpy.data.materials if m.name.startswith("tv_mist")]:
            bpy.data.materials.remove(m)
        mcol = d["targets"]["mist"]
        mm = mat_cardfx("tv_mist_" + dname, mcol, alpha=0.7 if dname != "noon" else 0.5, stretch=(0.6, 1.2))
        bands = [((-13, -70), (13, 90), WATER + 5.0), ((-700, 120), (500, 700), 30.0), ((-900, 500), (700, 1100), 70.0)]
        if dname == "noon":
            bands = [((-12, -10), (12, 80), WATER + 3.0), ((-900, 500), (700, 1100), 55.0)]
        for k, ((x0, y0), (x1, y1), z) in enumerate(bands):
            mesh_from("tv_mist%d" % k, [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], [(0, 1, 2, 3)], mm,
                      uvs=[(0, 0), (1, 0), (1, 1), (0, 1)], smooth=False)
        for mn, base in (("tv_fall", PAL["foam_fall"][2]), ("tv_spray", PAL["mist"][3])):
            mt = bpy.data.materials.get(mn)
            if mt:
                em = [n for n in mt.node_tree.nodes if n.type == "EMISSION"][0]
                c_ = np.array(lin(base)) * 0.55 + np.array(lin(d["targets"]["mist"])) * 0.45
                em.inputs["Color"].default_value = tuple(c_) + (1,)
                em.inputs["Strength"].default_value = {"noon": 1.0, "morning": 0.95, "dusk": 0.6}[dname]
        world(dname, amb_scale=2.4 if dname == "dusk" else 1.0)
        sun(dname, strength=DIR_DATA(dname)["sun"]["energy"] * (3.6 if dname == "dusk" else 2.1))
        lights_on = dname == "dusk"
        pm = bpy.data.materials.get("tvv_paper")
        if pm:
            b = pm.node_tree.nodes["Principled BSDF"]
            b.inputs["Emission Strength"].default_value = 2.5 if lights_on else 0.0
        for o in [o for o in bpy.data.objects if o.get("tv_lamp")]:
            bpy.data.objects.remove(o)
        if lights_on:
            k = 0
            for ob in place:
                src = ob if ob.children else bpy.data.objects.get(ob.name.split(".")[0])
                for ch in (src.children if src else []):
                    if ch.type == "EMPTY" and ("lantern" in ch.name or "lamp" in ch.name or "light" in ch.name):
                        p = ob.matrix_world @ ch.location
                        li = bpy.data.lights.new("tv_lamp%d" % k, "POINT")
                        li.energy = 400.0 if "lamp" in ch.name else 220.0
                        li.color = lin("#ffb45a")
                        li.shadow_soft_size = 0.3
                        lo = bpy.data.objects.new("tv_lamp%d" % k, li)
                        lo.location = p
                        lo["tv_lamp"] = True
                        bpy.context.scene.collection.objects.link(lo)
                        k += 1
        for cname, cl, ct, lens in (("hero",) + HERO,
                                    ("reach", (6.0, -58.0, 22.0), (-3.0, 12.0, 4.0), 28.0),
                                    ("bridge", (24.0, -26.0, 24.5), (-4.0, 2.0, 17.0), 30.0)):
            if cname != "hero" and dname != "noon":
                continue
            camera(cl, ct, lens=lens)
            bpy.context.scene.render.filepath = os.path.join(out, "diorama_%s_%s.png" % (cname, dname))
            bpy.ops.render.render(write_still=True)
            results["%s_%s" % (cname, dname)] = bpy.context.scene.render.filepath
    tris = sum(tvkit.tri_count(o) for o in place)
    with open(os.path.join(out, "diorama.json"), "w") as f:
        json.dump({"renders": results, "kit_pieces_placed": len(place), "kit_tris": tris}, f, indent=1)


# ------------------------------------------------------------------------------------------------ main
PAGES = {
    "houses": dict(names=["stilt_house_small", "stilt_house_large", "cliff_house"], spacing=4.0, cam_dist=40.0,
                   cam_h=11.0, lens=40.0),
    "halls": dict(names=["clan_house", "gate_pavilion", "gate_tower"], spacing=4.0, cam_dist=40.0, cam_h=11.0,
                  lens=40.0),
    "waystone": dict(names=["clan_waystone", "banner_indigo", "banner_ochre", "banner_jade", "bridge_lamp",
                            "lantern_post"], spacing=1.6, cam_dist=14.0, cam_h=4.5, lens=40.0, figure_gap=0.8),
    "terrace": dict(names=["terrace_wall_straight_4m", "terrace_wall_curve_in_4m", "terrace_wall_curve_out_4m",
                           "paddy_bund_4m", "sampan", "survey_camp"], spacing=1.6, cam_dist=14.0, cam_h=5.5, lens=40.0,
                    figure_gap=0.8),
    "clutter": dict(names=["lantern_round", "lantern_barrel", "fence_bamboo_3m", "fence_wattle_2m", "drying_rack",
                           "basket_set", "firewood_pile", "water_jars"], spacing=0.9, cam_dist=8.0, cam_h=2.6,
                    lens=40.0, figure_gap=0.6),
    "people": dict(names=["porter_standing", "porter_walking", "porter_pole", "prayer_flags_4m", "prayer_flags_8m"],
                   spacing=1.2, cam_dist=8.0, cam_h=2.4, lens=40.0, figure_gap=0.6),
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--pages", default="houses,halls,waystone,terrace,clutter,people,bridge,roofs,diorama")
    ap.add_argument("--dirs", default="noon,morning,dusk")
    ap.add_argument("--fast", action="store_true")
    a = ap.parse_args(argv)
    out = os.path.join(a.out, "raw")
    os.makedirs(out, exist_ok=True)
    setup_render(a.fast)
    pages = a.pages.split(",")
    for p in pages:
        if p in PAGES:
            lineup(p, out=out, fast=a.fast, **PAGES[p])
        elif p == "bridge":
            bridge_page(out, a.fast)
        elif p == "roofs":
            names = roof_variants(out, a.fast)
            lineup("roofs", names, 4.0, 34.0, 9.0, 40.0, out, a.fast, target_z=4.5)
        elif p == "diorama":
            diorama(out, a.dirs.split(","), a.fast)
    print("RENDER DONE")


def bridge_page(out, fast):
    """The R1 rope bridge assembled (D1-D4: 63 + 73 m on the needle platform), side-on, plus a close view of the east
    head with a figure on the planks (the texel check)."""
    hide_all()
    for o in [o for o in bpy.data.objects if o.get("render_only") or o.get("render_only_copy")]:
        bpy.data.objects.remove(o)
    objs = kit_objects()
    ground_plane(size=600.0, z=-40.0)
    ob = objs["rope_bridge_r1"]
    show(ob, (-68.0, 0.0, 0.0), 0.0)
    # stand-ins under it so it does not float: the needle (R07) and two cliff blocks (ROCK builds the real ones)
    lime = mat_terrain("tv_ground_terrain")
    for (x0, x1) in ((-110.0, -68.5), (68.5, 110.0)):
        mesh_box("tv_cliff%d" % int(x0), (x0, -12, -40.0), (x1, 12, -0.02), lime)
    mesh_box("tv_needle", (-7.4, -3.0, -40.0), (-0.6, 3.0, -4.05), lime)
    figure_marker((-68.0 + 63.0 * 0.4, 0.0, vk.deck_z(0.4, 63.0, -3.0, 4.5)), math.pi / 2)
    world("noon")
    sun("noon", az_deg=200, el_deg=40, strength=4.6, color="#fff3d9", angle_deg=1.5)
    cam = camera((-30.0, -120.0, 14.0), (0.0, 0.0, -6.0), lens=38.0)
    bpy.context.scene.render.filepath = os.path.join(out, "bridge.png")
    bpy.ops.render.render(write_still=True)
    camera((52.0, -9.5, 4.8), (63.0, 1.0, 2.0), lens=30.0)
    figure_marker((63.5, -0.2, 0.0), -math.pi / 2)
    bpy.context.scene.render.filepath = os.path.join(out, "bridge_close.png")
    bpy.ops.render.render(write_still=True)
    with open(os.path.join(out, "bridge.json"), "w") as f:
        json.dump({"page": "bridge", "pieces": {"rope_bridge_r1": dict(info_of(ob), screen=[0.5, 0.9])}}, f, indent=1)
    silhouettes({"rope_bridge_r1": ob}, os.path.join(out, "bridge_sil"), (-30.0, -120.0, 14.0), (0, 0, -6), 38.0)


def mesh_box(name, lo, hi, mat):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh_from(name, v, f, mat, smooth=False)


if __name__ == "__main__":
    main()
