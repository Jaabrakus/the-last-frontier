"""Blender side of the Thủy Vân trait renders (run inside Blender through the shared lock wrapper only):
the lit scene of the style guide section 11, today's body from body.glb with a person's baked painted skin, the face's
eyes, brows and lashes, a hair style, garments, and the Hồ Tinh fox ears and tails.

    zsh tools/thuyvan/bin/blender_run.sh -b --python-exit-code 1 --python tools/thuyvan_art/traits/render_traits.py -- <job.json>

Nothing here writes into the repository except build_fox_parts.py's glbs. Godot space (+Y up, faces +Z) maps to
Blender as (x, y, z) -> (x, -z, y): the figures face -Y, toward a camera on the -Y side.
"""
import math
import os

import bpy
import bmesh
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
CHAR = os.path.join(ROOT, "assets", "character")


def g2b(p):
    return Vector((p[0], -p[2], p[1]))


def hex_lin(h, a=1.0):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (c[0], c[1], c[2], a)


# ------------------------------------------------------------------------------------------------------------ scene
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_scene(res=(1920, 1080), samples=48, ground_png=None, sky=("#7fb3e6", "#d9e8ef"), sun_energy=4.2,
                sun_az_deg=-50.0, night=False):
    """Eevee, AgX near contrast 1.05, a sun 40 deg up from the front-left, a sky light of 0.6, soft shadows, a painted
    ground and a painted gradient sky behind (style guide 11 and 5.4)."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    ee = sc.eevee
    for attr, val in (("taa_render_samples", samples), ("use_shadows", True), ("shadow_ray_count", 2),
                      ("shadow_step_count", 8), ("use_raytracing", True), ("use_gtao", True), ("gtao_distance", 0.6)):
        if hasattr(ee, attr):
            try:
                setattr(ee, attr, val)
            except Exception:
                pass
    vs = sc.view_settings
    try:
        vs.view_transform = "AgX"
        looks = [i.identifier for i in vs.bl_rna.properties["look"].enum_items]
        for want in ("AgX - Base Contrast", "AgX - Medium High Contrast", "None"):
            if want in looks:
                vs.look = want
                break
    except Exception:
        pass
    vs.exposure = 0.0 if not night else -0.6
    # world: what the camera sees is the painted sky gradient; what lights is the sky colour at 0.6
    w = bpy.data.worlds.new("Sky")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    lp = nt.nodes.new("ShaderNodeLightPath")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Window"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = hex_lin(sky[1])
    ramp.color_ramp.elements[1].color = hex_lin(sky[0])
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[1].position = 1.0
    nt.links.new(sep.outputs["Y"], ramp.inputs[0])
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(ramp.outputs[0], bg_cam.inputs[0])
    bg_cam.inputs[1].default_value = 1.0 if not night else 0.25
    bg_light = nt.nodes.new("ShaderNodeBackground")
    bg_light.inputs[0].default_value = hex_lin("#a9c7e6" if not night else "#2a3550")
    bg_light.inputs[1].default_value = 0.6 if not night else 0.18
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(bg_light.outputs[0], mix.inputs[1])
    nt.links.new(bg_cam.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    # the sun: 40 deg up, from the front-left (the camera is on -Y; front-left of the figures = -X, -Y)
    sd = bpy.data.lights.new("Sun", "SUN")
    sd.energy = sun_energy if not night else 0.25
    sd.color = hex_lin("#fff1dc")[:3] if not night else hex_lin("#9fb4e6")[:3]
    sd.angle = math.radians(2.5)
    so = bpy.data.objects.new("Sun", sd)
    sc.collection.objects.link(so)
    el = math.radians(40.0)
    az = math.radians(sun_az_deg)
    d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))  # toward the sun
    so.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    # a soft cool fill from the right back, so shadows keep hue (WoW-flat ratio about 2.2:1)
    fd = bpy.data.lights.new("Fill", "SUN")
    fd.energy = 0.6 if not night else 0.05
    fd.color = hex_lin("#b9c9ff")[:3]
    fd.angle = math.radians(20.0)
    fo = bpy.data.objects.new("Fill", fd)
    sc.collection.objects.link(fo)
    fo.rotation_euler = Vector((0.7, 0.6, 0.35)).to_track_quat("Z", "Y").to_euler()
    if ground_png:
        add_ground(ground_png)
    return sc


def add_ground(png, size=40.0, tile=8.0):
    me = bpy.data.meshes.new("Ground")
    s = size / 2
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new(name="UVMap")
    for li, (x, y) in zip(range(4), ((-s, -s), (s, -s), (s, s), (-s, s))):
        uv.data[li].uv = (x / tile, y / tile)
    ob = bpy.data.objects.new("Ground", me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new("Ground")
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    im = nt.nodes.new("ShaderNodeTexImage")
    im.image = bpy.data.images.load(png)
    nt.links.new(im.outputs[0], bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = 0.95
    _spec(bs, 0.2)
    me.materials.append(m)
    return ob


def _spec(bs, v):
    for nm in ("Specular IOR Level", "Specular"):
        if nm in bs.inputs:
            bs.inputs[nm].default_value = v
            return


def add_camera(loc, look_at, lens=85.0, name="Cam", ortho=None):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    cam.clip_start = 0.05
    cam.clip_end = 200
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    co = bpy.data.objects.new(name, cam)
    bpy.context.scene.collection.objects.link(co)
    co.location = Vector(loc)
    co.rotation_euler = (Vector(look_at) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    return co


def render(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------------------------------------------- importing
def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    return new


def retarget(objs, arm):
    """Meshes of a garment/hair glb onto the body's armature (the same Actor_B bones, the same null-add rest); the
    glb's own armature is deleted."""
    meshes = [o for o in objs if o.type == "MESH"]
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = arm
        o.matrix_world = mw
        for md in o.modifiers:
            if md.type == "ARMATURE":
                md.object = arm
        if not any(md.type == "ARMATURE" for md in o.modifiers):
            md = o.modifiers.new("Armature", "ARMATURE")
            md.object = arm
    for o in objs:
        if o.type in ("ARMATURE", "EMPTY") and o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    return meshes


def set_keys(o, keys):
    if o.type != "MESH" or not o.data.shape_keys:
        return
    kb = o.data.shape_keys.key_blocks
    for k, v in keys.items():
        if k in kb:
            kb[k].value = v


def uv_name(o, i):
    return o.data.uv_layers[i].name if len(o.data.uv_layers) > i else o.data.uv_layers[0].name


def color_attr_name(o):
    if hasattr(o.data, "color_attributes") and len(o.data.color_attributes):
        return o.data.color_attributes[0].name
    return "Col"


def delete_faces(o, pred):
    """Delete the faces whose every vertex satisfies pred(bm_vert, loop_uv2) (e.g. a garment zone, a tail slit)."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    uvl = bm.loops.layers.uv[1] if len(bm.loops.layers.uv) > 1 else None
    kill = []
    for f in bm.faces:
        if all(pred(l.vert, l[uvl].uv if uvl else None) for l in f.loops):
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    return len(kill)


# ------------------------------------------------------------------------------------------------------- materials
def _img(path, colorspace="sRGB"):
    im = bpy.data.images.load(path, check_existing=True)
    try:
        im.colorspace_settings.name = colorspace
    except Exception:
        im.colorspace_settings.name = "Non-Color"
    return im


def skin_material(o, prefix, name="Skin"):
    """The baked painted skin (skin_bake.py) through the MakeHuman UVs: albedo, roughness, a bump from the plates' and
    scales' height, thin-film iridescence on the scales (teal -> violet -> gold with the view), a wet coat on the
    river sheen, and a little subsurface."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = uv_name(o, 2)
    def tex(sfx, cs):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = _img(prefix + sfx, cs)
        t.interpolation = "Cubic" if sfx == "_height.png" else "Linear"
        nt.links.new(uv.outputs[0], t.inputs[0])
        return t
    a = tex("_albedo.png", "sRGB")
    r = tex("_rough.png", "Non-Color")
    s = tex("_sheen.png", "Non-Color")
    h = tex("_height.png", "Non-Color")
    nt.links.new(a.outputs[0], bs.inputs["Base Color"])
    nt.links.new(r.outputs[0], bs.inputs["Roughness"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.55
    bump.inputs["Distance"].default_value = 0.0025
    nt.links.new(h.outputs[0], bump.inputs["Height"])
    nt.links.new(bump.outputs[0], bs.inputs["Normal"])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(s.outputs[0], sep.inputs[0])
    if "Thin Film Thickness" in bs.inputs:
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = 520.0
        nt.links.new(sep.outputs[0], mul.inputs[0])
        nt.links.new(mul.outputs[0], bs.inputs["Thin Film Thickness"])
        bs.inputs["Thin Film IOR"].default_value = 1.75
    if "Coat Weight" in bs.inputs:
        cw = nt.nodes.new("ShaderNodeMath")
        cw.operation = "MULTIPLY"
        cw.inputs[1].default_value = 0.7
        nt.links.new(sep.outputs[1], cw.inputs[0])
        nt.links.new(cw.outputs[0], bs.inputs["Coat Weight"])
        bs.inputs["Coat Roughness"].default_value = 0.12
    if "Subsurface Weight" in bs.inputs:
        bs.inputs["Subsurface Weight"].default_value = 0.12
        bs.inputs["Subsurface Radius"].default_value = (1.0, 0.45, 0.3)
        bs.inputs["Subsurface Scale"].default_value = 0.006
    _spec(bs, 0.38)
    o.data.materials.clear()
    o.data.materials.append(m)
    return m


def eye_material(o, iris_hex, reflect=0.0, tapetum_hex="#9fd08a"):
    """The painted eye (eye.gdshader's stylized branch, simplified): UV = metres from the eye's centre; pupil, iris
    lighter in its lower half, a dark limbal ring, a warm grey sclera; `reflect` glows the pupil and iris (night)."""
    m = bpy.data.materials.new("Eye")
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = uv_name(o, 0)
    ln = nt.nodes.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    nt.links.new(uv.outputs[0], ln.inputs[0])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs[0], sep.inputs[0])

    def step(edge, soft=0.00035):
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = edge - soft
        mr.inputs["From Max"].default_value = edge + soft
        nt.links.new(ln.outputs["Value"], mr.inputs["Value"])
        return mr.outputs[0]
    pupil_s = step(0.0021 * 1.1)
    iris_s = step(0.0058 * 1.12)
    ring_s = step(0.0052 * 1.12, 0.0006)
    lower = nt.nodes.new("ShaderNodeMapRange")
    lower.inputs["From Min"].default_value = 0.003
    lower.inputs["From Max"].default_value = -0.003
    nt.links.new(sep.outputs["Y"], lower.inputs["Value"])
    ic = hex_lin(iris_hex)
    hi = tuple(min(1.0, c * 1.9 + 0.02) for c in ic[:3]) + (1.0,)
    m_iris = nt.nodes.new("ShaderNodeMix")
    m_iris.data_type = "RGBA"
    m_iris.inputs[6].default_value = ic
    m_iris.inputs[7].default_value = hi
    nt.links.new(lower.outputs[0], m_iris.inputs[0])
    m_ring = nt.nodes.new("ShaderNodeMix")
    m_ring.data_type = "RGBA"
    nt.links.new(ring_s, m_ring.inputs[0])
    nt.links.new(m_iris.outputs[2], m_ring.inputs[6])
    m_ring.inputs[7].default_value = tuple(c * 0.25 for c in ic[:3]) + (1.0,)
    m_pup = nt.nodes.new("ShaderNodeMix")
    m_pup.data_type = "RGBA"
    nt.links.new(pupil_s, m_pup.inputs[0])
    m_pup.inputs[6].default_value = (0.01, 0.01, 0.012, 1.0)
    nt.links.new(m_ring.outputs[2], m_pup.inputs[7])
    m_scl = nt.nodes.new("ShaderNodeMix")
    m_scl.data_type = "RGBA"
    nt.links.new(iris_s, m_scl.inputs[0])
    nt.links.new(m_pup.outputs[2], m_scl.inputs[6])
    m_scl.inputs[7].default_value = (0.62, 0.58, 0.53, 1.0)
    nt.links.new(m_scl.outputs[2], bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = 0.08
    if "Coat Weight" in bs.inputs:
        bs.inputs["Coat Weight"].default_value = 1.0
        bs.inputs["Coat Roughness"].default_value = 0.03
    if reflect > 0.0:
        inv = nt.nodes.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        nt.links.new(iris_s, inv.inputs[1])
        em_col = nt.nodes.new("ShaderNodeMix")
        em_col.data_type = "RGBA"
        nt.links.new(pupil_s, em_col.inputs[0])
        em_col.inputs[6].default_value = hex_lin(tapetum_hex)
        em_col.inputs[7].default_value = tuple(c * 0.5 for c in hex_lin(tapetum_hex)[:3]) + (1.0,)
        nt.links.new(em_col.outputs[2], bs.inputs["Emission Color"])
        st = nt.nodes.new("ShaderNodeMath")
        st.operation = "MULTIPLY"
        st.inputs[1].default_value = 6.0 * reflect
        nt.links.new(inv.outputs[0], st.inputs[0])
        nt.links.new(st.outputs[0], bs.inputs["Emission Strength"])
    return m


def face_hair_material(o, brow_png, hair_hex):
    """Brows (zone 0: the painted brow shape baked by render_traits.bake_brow) and the upper lashes (zone 1, COLOR_0.g
    = 1) as a short dark band; the lower lashes are not drawn (the stylized face's rule)."""
    m = bpy.data.materials.new("FaceHair")
    m.use_nodes = True
    try:
        m.surface_render_method = "BLENDED"
    except Exception:
        m.blend_method = "BLEND"
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    uv0 = nt.nodes.new("ShaderNodeUVMap")
    uv0.uv_map = uv_name(o, 0)
    uv1 = nt.nodes.new("ShaderNodeUVMap")
    uv1.uv_map = uv_name(o, 1)
    s1 = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv1.outputs[0], s1.inputs[0])
    zone = nt.nodes.new("ShaderNodeMath")
    zone.operation = "GREATER_THAN"
    zone.inputs[1].default_value = 40.0
    nt.links.new(s1.outputs["X"], zone.inputs[0])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = _img(brow_png, "Non-Color")
    t.extension = "EXTEND"
    nt.links.new(uv0.outputs[0], t.inputs[0])
    s0 = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv0.outputs[0], s0.inputs[0])
    lash = nt.nodes.new("ShaderNodeMath")
    lash.operation = "SUBTRACT"
    lash.inputs[0].default_value = 0.95
    nt.links.new(s0.outputs["Y"], lash.inputs[1])
    ca = nt.nodes.new("ShaderNodeVertexColor")
    ca.layer_name = color_attr_name(o)
    sepc = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(ca.outputs[0], sepc.inputs[0])
    lash_up = nt.nodes.new("ShaderNodeMath")
    lash_up.operation = "MULTIPLY"
    nt.links.new(lash.outputs[0], lash_up.inputs[0])
    nt.links.new(sepc.outputs[1], lash_up.inputs[1])
    sel = nt.nodes.new("ShaderNodeMix")
    sel.data_type = "FLOAT"
    nt.links.new(zone.outputs[0], sel.inputs[0])
    nt.links.new(t.outputs[0], sel.inputs[2])
    nt.links.new(lash_up.outputs[0], sel.inputs[3])
    nt.links.new(sel.outputs[0], bs.inputs["Alpha"])
    hc = hex_lin(hair_hex)
    bs.inputs["Base Color"].default_value = tuple(c * 0.8 for c in hc[:3]) + (1.0,)
    bs.inputs["Roughness"].default_value = 0.7
    return m


def hair_material(o, hair_hex, sheen_hex=None):
    m = bpy.data.materials.new("Hair")
    m.use_nodes = True
    try:
        m.surface_render_method = "DITHERED"
    except Exception:
        m.blend_method = "HASHED"
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = _img(os.path.join(CHAR, "hair", "tex", "hair_atlas.png"), "Non-Color")
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = uv_name(o, 0)
    nt.links.new(uv.outputs[0], t.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(t.outputs[0], mul.inputs[6])
    hc = hex_lin(hair_hex)
    mul.inputs[7].default_value = tuple(min(1.0, c * 2.0) for c in hc[:3]) + (1.0,)
    nt.links.new(mul.outputs[2], bs.inputs["Base Color"])
    nt.links.new(t.outputs[1], bs.inputs["Alpha"])
    bs.inputs["Roughness"].default_value = 0.42
    _spec(bs, 0.45)
    if sheen_hex and "Coat Weight" in bs.inputs:
        bs.inputs["Coat Weight"].default_value = 0.35
        bs.inputs["Coat Tint"].default_value = hex_lin(sheen_hex)
    for p in o.data.polygons:
        p.use_smooth = True
    return m


def painted_noise(nt, scale=2.5, detail=3.0):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = detail
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    return nz


def cloth_material(o, zone_ramps, name="Cloth", rough=0.85):
    """A painted cloth: per zone (UV2.x // 64), the dye's 4-stop ramp [dark, mid, light, accent] laid by a soft
    painted noise and the garment's own vertex colour (its baked fold and hem shading)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    uv1 = nt.nodes.new("ShaderNodeUVMap")
    uv1.uv_map = uv_name(o, 1)
    s1 = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv1.outputs[0], s1.inputs[0])
    zdiv = nt.nodes.new("ShaderNodeMath")
    zdiv.operation = "DIVIDE"
    zdiv.inputs[1].default_value = 64.0
    nt.links.new(s1.outputs["X"], zdiv.inputs[0])
    zf = nt.nodes.new("ShaderNodeMath")
    zf.operation = "FLOOR"
    nt.links.new(zdiv.outputs[0], zf.inputs[0])
    nz = painted_noise(nt, 3.0, 4.0)
    nz2 = painted_noise(nt, 14.0, 2.0)
    mixn = nt.nodes.new("ShaderNodeMath")
    mixn.operation = "MULTIPLY_ADD"
    mixn.inputs[1].default_value = 0.35
    nt.links.new(nz2.outputs["Fac"], mixn.inputs[0])
    nt.links.new(nz.outputs["Fac"], mixn.inputs[2])
    prev = None
    for z in sorted(zone_ramps):
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        cr = ramp.color_ramp
        dark, mid, light = zone_ramps[z][:3]
        cr.elements[0].position = 0.25
        cr.elements[0].color = hex_lin(dark)
        cr.elements[1].position = 0.85
        cr.elements[1].color = hex_lin(light)
        e = cr.elements.new(0.55)
        e.color = hex_lin(mid)
        nt.links.new(mixn.outputs[0], ramp.inputs[0])
        if prev is None:
            prev = ramp.outputs[0]
            continue
        cmp = nt.nodes.new("ShaderNodeMath")
        cmp.operation = "COMPARE"
        cmp.inputs[1].default_value = float(z)
        cmp.inputs[2].default_value = 0.5
        nt.links.new(zf.outputs[0], cmp.inputs[0])
        mx = nt.nodes.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        nt.links.new(cmp.outputs[0], mx.inputs[0])
        nt.links.new(prev, mx.inputs[6])
        nt.links.new(ramp.outputs[0], mx.inputs[7])
        prev = mx.outputs[2]
    if len(getattr(o.data, "color_attributes", [])):
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = color_attr_name(o)
        mm = nt.nodes.new("ShaderNodeMix")
        mm.data_type = "RGBA"
        mm.blend_type = "MULTIPLY"
        mm.inputs[0].default_value = 1.0
        nt.links.new(prev, mm.inputs[6])
        nt.links.new(vc.outputs[0], mm.inputs[7])
        prev = mm.outputs[2]
    nt.links.new(prev, bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = rough
    if "Sheen Weight" in bs.inputs:
        bs.inputs["Sheen Weight"].default_value = 0.25
    _spec(bs, 0.25)
    o.data.materials.clear()
    o.data.materials.append(m)
    return m


def vcol_material(o, name, rough=0.8, sheen=0.6):
    """Painted vertex colours (the fox ears and tails, built with their paint in COLOR_0)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = color_attr_name(o)
    nt.links.new(vc.outputs[0], bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = rough
    if "Sheen Weight" in bs.inputs:
        bs.inputs["Sheen Weight"].default_value = sheen
        bs.inputs["Sheen Roughness"].default_value = 0.4
    if "Subsurface Weight" in bs.inputs:
        bs.inputs["Subsurface Weight"].default_value = 0.05
    _spec(bs, 0.2)
    return m


# -------------------------------------------------------------------------------------------------------------- pose
def pose_relaxed(arm, arm_down_deg=22.0, elbow_deg=14.0, spread=None, extra=None):
    """The bind pose (Actor_B null-add: arms 33 deg out) relaxed for a lineup: the upper arms swung toward the body
    about the forward axis, the elbows bent a little forward; the twist helpers follow as the game's driver would with
    no twist (the forearm helpers ride the elbow, shoulder_twist_a half the swing)."""
    bpy.context.view_layer.update()
    pbs = arm.pose.bones
    for side, sgn in (("l", 1.0), ("r", -1.0)):
        sh = pbs.get(side + "_shoulder")
        el = pbs.get(side + "_elbow")
        if not sh or not el:
            continue
        a = math.radians(arm_down_deg) * sgn
        Rsh = Matrix.Rotation(a, 4, "Y")
        h = sh.head.copy()
        T = Matrix.Translation(h) @ Rsh @ Matrix.Translation(-h)
        sh.matrix = T @ sh.matrix
        bpy.context.view_layer.update()
        he = el.head.copy()
        Rel = Matrix.Rotation(-math.radians(elbow_deg), 4, "X")
        Te = Matrix.Translation(he) @ Rel @ Matrix.Translation(-he)
        el.matrix = Te @ el.matrix
        bpy.context.view_layer.update()
        # helpers: delta of their driver bone, applied to their rest
        def follow(hname, driver, frac=1.0):
            hb = pbs.get(side + "_" + hname)
            db = pbs.get(driver)
            if not hb or not db:
                return
            D = db.matrix @ db.bone.matrix_local.inverted()
            if frac < 1.0:
                loc, rot, _ = D.decompose()
                q = Quaternion().slerp(rot, frac)
                piv = db.head
                D = Matrix.Translation(piv) @ q.to_matrix().to_4x4() @ Matrix.Translation(-piv)
            hb.matrix = D @ hb.bone.matrix_local
            bpy.context.view_layer.update()
        follow("shoulder_twist_a", side + "_shoulder", 0.5)
        for n in ("shoulder_twist_b", "shoulder_twist_c", "shoulder_twist_d"):
            follow(n, side + "_shoulder")
        for n in ("forarm_twist_a", "forarm_twist_b", "forarm_twist_c"):
            follow(n, side + "_elbow")
    if extra:
        extra(arm)
    bpy.context.view_layer.update()
