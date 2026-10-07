"""Step 3 (Blender, through the shared lock wrapper): the owner's review renders of a built kit .blend.

    zsh tools/thuyvan/bin/blender_run.sh -b <scratch>/fb.blend --python-exit-code 1 \
        -P tools/thuyvan_art/bodies/render_bodies.py -- --kit floodborn --tex DIR --out DIR [--paint]

Lit like style guide 11 (Eevee, a bright game scene: sun at 40 deg elevation from the front-left, a sky-coloured world
light at 0.6, soft shadows, AgX at a low contrast; the painted grass ground). Writes the raw tiles and a shots.json
(figure label positions, triangle counts) that compose.py (PIL) turns into the captioned 1920 x 1080 sheets.
"""

import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True
import libshim  # noqa: E402,F401

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

from lib.remesh import srgb  # noqa: E402
import blender_kit as BK  # noqa: E402
import kit_weights as KW  # noqa: E402
import pose as PO  # noqa: E402

SHOTS = {}


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--kit", required=True)
    ap.add_argument("--tex", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--paint", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--samples", type=int, default=32)
    return ap.parse_args(argv)


# ===========================================================================
# Scene
# ===========================================================================
def setup_scene(tex, samples):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    ee = sc.eevee
    for k, v in (("taa_render_samples", samples), ("use_shadows", True), ("use_raytracing", True),
                 ("shadow_ray_count", 2), ("shadow_step_count", 8), ("use_gtao", True), ("gtao_distance", 0.4)):
        try:
            setattr(ee, k, v)
        except (AttributeError, TypeError):
            pass
    try:
        ee.ray_tracing_options.trace_max_roughness = 0.6
        ee.fast_gi_method = "GLOBAL_ILLUMINATION"
    except AttributeError:
        pass
    vs = sc.view_settings
    vs.view_transform = "AgX"
    for look in ("AgX - Medium High Contrast", "AgX - Base Contrast", "None"):
        try:
            vs.look = look
            break
        except TypeError:
            continue
    vs.exposure = 0.15
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    # world: a painted-sky gradient, light at 0.6
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = 0.6
    bgc = nt.nodes.new("ShaderNodeBackground")
    bgc.inputs["Strength"].default_value = 1.15
    lp = nt.nodes.new("ShaderNodeLightPath")
    mixs = nt.nodes.new("ShaderNodeMixShader")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (*srgb("#e3e6d6"), 1)
    els[1].position, els[1].color = 0.22, (*srgb("#7fa9d6"), 1)
    e3 = els.new(0.6)
    e3.color = (*srgb("#4f80bd"), 1)
    nt.links.new(sep.outputs["Z"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bg.inputs["Color"])
    nt.links.new(ramp.outputs[0], bgc.inputs["Color"])
    nt.links.new(lp.outputs["Is Camera Ray"], mixs.inputs[0])
    nt.links.new(bg.outputs[0], mixs.inputs[1])
    nt.links.new(bgc.outputs[0], mixs.inputs[2])
    nt.links.new(mixs.outputs[0], out.inputs[0])
    # sun: 40 deg elevation from the front-left (the camera looks along +y)
    ld = bpy.data.lights.new("Sun", "SUN")
    ld.energy = 3.6
    ld.color = srgb("#fff1dc")
    ld.angle = math.radians(2.5)
    sun = BK.link(bpy.data.objects.new("Sun", ld))
    el, az = math.radians(40), math.radians(-40)
    frm = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    sun.rotation_euler = (-frm).to_track_quat("-Z", "Y").to_euler()
    # ground: the neutral painted grass, 8 m tile
    me = bpy.data.meshes.new("Ground")
    s = 40.0
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new(name="UVMap")
    for i, l in enumerate(me.loops):
        x, y, _ = me.vertices[l.vertex_index].co
        uv.data[i].uv = (x / 8.0, y / 8.0)
    g = BK.link(bpy.data.objects.new("Ground", me))
    m = bpy.data.materials.new("ground")
    nt2, bsdf = BK._nodes(m)
    t = nt2.nodes.new("ShaderNodeTexImage")
    t.image = BK.image(os.path.join(tex, "ground_grass.png"))
    nt2.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    BK._set(bsdf, "Roughness", 0.95)
    BK._set(bsdf, ["Specular IOR Level", "Specular"], 0.1)
    me.materials.append(m)
    cam = bpy.data.cameras.new("Cam")
    co = BK.link(bpy.data.objects.new("Cam", cam))
    sc.camera = co
    return g, co


def figures():
    return {o["figure"]: o for o in bpy.data.objects if o.type == "ARMATURE" and "figure" in o}


def fig_objects(rig):
    return [o for o in bpy.data.objects if o.parent is rig]


def show_only(names, figs, props=()):
    for n, rig in figs.items():
        vis = n in names
        rig.hide_render = True
        for o in fig_objects(rig):
            o.hide_render = not vis
    for o in bpy.data.objects:
        if o.get("prop"):
            o.hide_render = o.name not in props


def place(rig, x, y=0.0, rot_deg=0.0, scale=1.0):
    rig.location = (x, y, 0.0)
    rig.rotation_euler = (0, 0, math.radians(rot_deg))
    rig.scale = (scale,) * 3


# ===========================================================================
# Poses and props
# ===========================================================================
def pose_figure(rig, which):
    J = BK.joints_from_armature(rig)
    kit, var = rig.get("kit", "human"), rig.get("variant", "A")
    if which == "rest":
        pz = PO.floodborn_rest(var) if kit == "floodborn" else {"rot": {}, "dirs": {}}
        if kit == "moc_tinh":
            pz = {"rot": {}, "dirs": vine_down(J)}
    elif which == "action":
        if kit == "floodborn":
            pz = PO.floodborn_spear(var)
        elif kit == "moc_tinh":
            pz = PO.moc_staff(var)
            pz["dirs"] = vine_down(J)
        else:
            R = {}
            PO._arms_down(R, 24)
            pz = {"rot": R, "dirs": {}}
    Gp = PO.fk(J, pz["rot"], pz["dirs"])
    BK.apply_pose(rig, J, Gp)
    return Gp, pz


def vine_down(J):
    return {n: np.array([0.0, 0.08, -1.0]) for n in J.order if n.startswith("vine_")}


def _palm_world(rig, Gp, side):
    p = 0.5 * (Gp[side + "_palm"][:3, 3] + Gp[side + "_middleb"][:3, 3])
    return rig.matrix_world @ Vector(p)


def make_spear(name, hand, mats, h=2.05):
    """Spear upright through the fist, planted on the ground: shaft, bronze collar, leaf blade, two streamers."""
    objs = []
    x, y = hand.x, hand.y
    bpy.ops.mesh.primitive_cylinder_add(radius=0.018, depth=h, location=(x, y, h / 2), vertices=12)
    objs.append(bpy.context.active_object)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.026, depth=0.06, location=(x, y, h - 0.01), vertices=12)
    objs.append(bpy.context.active_object)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(x, y, h + 0.13), segments=16, ring_count=10)
    b = bpy.context.active_object
    b.scale = (0.045, 0.012, 0.15)
    objs.append(b)
    for k, dz in enumerate((0.0, -0.05)):
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(x - 0.03, y + 0.04 + 0.02 * k, h - 0.22 + dz))
        st = bpy.context.active_object
        st.scale = (0.035, 0.001, 0.18)
        st.rotation_euler = (0, math.radians(8 + 6 * k), 0)
        objs.append(st)
    for i, o in enumerate(objs):
        o.name = "%s_%d" % (name, i)
        o["prop"] = True
        o.data.materials.clear()
        o.data.materials.append(mats["streamer"] if i >= 3 else mats["blade"] if i == 2 else mats["collar"] if i == 1
                                else mats["shaft"])
        for p in o.data.polygons:
            p.use_smooth = True
    return [o.name for o in objs]


def make_staff(name, hand, mats, h=1.78):
    """Gnarled walking staff planted beside the foot, through the fist, a knob at the top."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.021
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    rng = np.random.RandomState(4)
    pts = []
    base = Vector((hand.x + 0.03, hand.y - 0.02, 0.0))
    for i in range(9):
        z = h * i / 8
        pts.append((base.x + 0.012 * math.sin(i * 1.7) + (hand.x - base.x) * z / max(hand.z, 0.1) * 0.0,
                    base.y + 0.010 * math.cos(i * 1.3), z))
    sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts):
        p.co = (*c, 1)
    sp.use_endpoint_u = True
    sp.order_u = 3
    ob = BK.link(bpy.data.objects.new(name, cu))
    ob.data.materials.append(mats["staff"])
    ob["prop"] = True
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(pts[-1][0], pts[-1][1], h + 0.01), segments=12,
                                         ring_count=8)
    k = bpy.context.active_object
    k.name = name + "_knob"
    k.scale = (1.0, 0.9, 1.25)
    k.data.materials.append(mats["staff"])
    k["prop"] = True
    del rng
    return [ob.name, k.name]


def prop_materials(paint):
    if paint:
        return {"shaft": BK.flat_material("p_shaft", "#5a3e2a", 0.8), "collar": BK.flat_material("p_collar", "#a8743a", 0.45),
                "blade": BK.flat_material("p_blade", "#8f8a7a", 0.4), "streamer": BK.flat_material("p_streamer", "#9a2f22", 0.9),
                "staff": BK.flat_material("p_staff", "#6a4c34", 0.85)}
    g = BK.flat_material("clay_prop", "#5d564f", 0.85)
    return {"shaft": g, "collar": g, "blade": g, "streamer": g, "staff": g}


# ===========================================================================
# Painted materials (the paint pass of variant A)
# ===========================================================================
def paint_floodborn(rig, tex):
    sc_img = BK.image(os.path.join(tex, "fb_scutes.png"), noncolor=True)
    os_img = BK.image(os.path.join(tex, "fb_osteoderms.png"), noncolor=True)
    m = bpy.data.materials.new("paint_fb_hide")
    nt, bsdf = BK._nodes(m)
    vd = BK.triplanar_value(nt, os_img, 0.36)
    vv = BK.triplanar_value(nt, sc_img, 0.30)
    dors = BK.ramp_node(nt, [(0.0, "#1e2620"), (0.3, "#2f3b2c"), (0.55, "#3e4f3a"), (0.8, "#5b6b4a"), (1.0, "#7d8c5c")])
    nt.links.new(vd, dors.inputs[0])
    ven = BK.ramp_node(nt, [(0.0, "#aaa082"), (0.35, "#b9ad8a"), (0.75, "#d9cfb0"), (1.0, "#e8e0c2")])
    nt.links.new(vv, ven.inputs[0])
    # the teal cast: low-frequency painted variation over the back
    co = nt.nodes.new("ShaderNodeAttribute")
    co.attribute_name = "rest_co"
    noi = nt.nodes.new("ShaderNodeTexNoise")
    noi.inputs["Scale"].default_value = 2.2
    nt.links.new(co.outputs["Vector"], noi.inputs["Vector"])
    cast = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(noi.outputs["Fac"], cast.inputs[0])
    cast.inputs[1].default_value, cast.inputs[2].default_value = 0.45, 0.7
    cast.inputs[3].default_value, cast.inputs[4].default_value = 0.0, 0.55
    dcol = BK.mix_rgb(nt, cast.outputs[0], dors.outputs[0], (*srgb("#3e5a52"), 1), "MIX")
    col = BK.mix_rgb(nt, BK.attr_fac(nt, "belly"), dcol, ven.outputs[0])
    col = BK.mix_rgb(nt, BK.attr_fac(nt, "claw"), col, (*srgb("#cfc4a6"), 1))
    nt.links.new(BK.ao_multiply(nt, col), bsdf.inputs["Base Color"])
    BK._set(bsdf, "Roughness", 0.62)
    BK._set(bsdf, ["Specular IOR Level", "Specular"], 0.3)
    eye = bpy.data.materials.new("paint_fb_eye")
    nt, bsdf = BK._nodes(eye)
    c = BK.mix_rgb(nt, BK.attr_fac(nt, "pupil"), (*srgb("#e0b030"), 1), (*srgb("#120f0a"), 1))
    nt.links.new(c, bsdf.inputs["Base Color"])
    BK._set(bsdf, "Roughness", 0.2)
    BK._set(bsdf, ["Emission Color", "Emission"], (*srgb("#e0b030"), 1))
    BK._set(bsdf, "Emission Strength", 0.25)
    quill = bpy.data.materials.new("paint_fb_crest")
    nt, bsdf = BK._nodes(quill)
    co = nt.nodes.new("ShaderNodeAttribute")
    co.attribute_name = "rest_co"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(co.outputs["Vector"], sep.inputs[0])
    rr = BK.ramp_node(nt, [(0.0, "#4a4f40"), (0.45, "#262a22"), (1.0, "#1e211d")])
    mr = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(sep.outputs["Y"], mr.inputs[0])
    mr.inputs[1].default_value, mr.inputs[2].default_value = 0.30, 0.0
    nt.links.new(mr.outputs[0], rr.inputs[0])
    nt.links.new(BK.ao_multiply(nt, rr.outputs[0]), bsdf.inputs["Base Color"])
    BK._set(bsdf, "Roughness", 0.55)
    teeth = BK.clay("paint_fb_teeth", "#cfc4a6", 0.5)
    for o in fig_objects(rig):
        o.data.materials.clear()
        nm = o.name
        o.data.materials.append(eye if nm.endswith("_eyes") else quill if nm.endswith("_crest") else teeth
                                if nm.endswith("_teeth") else m)


def paint_moc_tinh(rig, tex):
    bark_img = BK.image(os.path.join(tex, "mt_bark.png"), noncolor=True)

    def bark_mat(name, tile, face=False, moss=True):
        m = bpy.data.materials.new(name)
        nt, bsdf = BK._nodes(m)
        v = BK.triplanar_value(nt, bark_img, tile, sharp=6.0)
        r = BK.ramp_node(nt, [(0.0, "#2e2a20"), (0.3, "#5e5c48"), (0.6, "#8f8e76"), (0.85, "#b4b49a"), (1.0, "#d2d1b8")])
        nt.links.new(v, r.inputs[0])
        col = r.outputs[0]
        co = nt.nodes.new("ShaderNodeAttribute")
        co.attribute_name = "rest_co"
        noi = nt.nodes.new("ShaderNodeTexNoise")
        noi.inputs["Scale"].default_value = 3.0
        nt.links.new(co.outputs["Vector"], noi.inputs["Vector"])
        mr = nt.nodes.new("ShaderNodeMapRange")
        nt.links.new(noi.outputs["Fac"], mr.inputs[0])
        mr.inputs[1].default_value, mr.inputs[2].default_value = 0.4, 0.7
        mr.inputs[3].default_value, mr.inputs[4].default_value = 0.0, 0.45
        col = BK.mix_rgb(nt, mr.outputs[0], col, (*srgb("#7d8a5a"), 1))           # green cast (sheet)
        if face:
            fv = BK.triplanar_value(nt, bark_img, 0.11, sharp=6.0)
            fr = BK.ramp_node(nt, [(0.0, "#6f6d5a"), (0.5, "#a3a28a"), (1.0, "#c8c7ae")])
            nt.links.new(fv, fr.inputs[0])
            col = BK.mix_rgb(nt, BK.attr_fac(nt, "face"), col, fr.outputs[0])
        # moss in the cavities (from the painted AO) and the plate cracks
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_name = "Color"
        sepc = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(a.outputs["Color"], sepc.inputs[0])
        mm = nt.nodes.new("ShaderNodeMapRange")
        nt.links.new(sepc.outputs[0], mm.inputs[0])
        mm.inputs[1].default_value, mm.inputs[2].default_value = 0.78, 0.6
        mm.inputs[3].default_value, mm.inputs[4].default_value = 0.0, 0.85
        if not face:
            cr = nt.nodes.new("ShaderNodeAttribute")
            cr.attribute_name = "crack"
            inv = nt.nodes.new("ShaderNodeMapRange")
            nt.links.new(cr.outputs["Fac"], inv.inputs[0])
            inv.inputs[1].default_value, inv.inputs[2].default_value = 0.6, 0.0
            inv.inputs[3].default_value, inv.inputs[4].default_value = 0.0, 0.75
            mx = nt.nodes.new("ShaderNodeMath")
            mx.operation = "MAXIMUM"
            nt.links.new(mm.outputs[0], mx.inputs[0])
            nt.links.new(inv.outputs[0], mx.inputs[1])
            mfac = mx.outputs[0]
        else:
            mfac = mm.outputs[0]
        moss_on = moss
        moss = BK.ramp_node(nt, [(0.0, "#2a4a22"), (0.5, "#4f7a33"), (1.0, "#8db04a")])
        nt.links.new(v, moss.inputs[0])
        col = BK.mix_rgb(nt, mfac, col, moss.outputs[0]) if moss_on else col
        nt.links.new(BK.ao_multiply(nt, col), bsdf.inputs["Base Color"])
        BK._set(bsdf, "Roughness", 0.85)
        BK._set(bsdf, ["Specular IOR Level", "Specular"], 0.15)
        return m

    def leafy(name, stops):
        m = bpy.data.materials.new(name)
        nt, bsdf = BK._nodes(m)
        no = nt.nodes.new("ShaderNodeAttribute")
        no.attribute_name = "rest_n"
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(no.outputs["Vector"], sep.inputs[0])
        mr = nt.nodes.new("ShaderNodeMapRange")
        nt.links.new(sep.outputs["Z"], mr.inputs[0])
        mr.inputs[1].default_value, mr.inputs[2].default_value = -0.6, 1.0
        r = BK.ramp_node(nt, stops)
        nt.links.new(mr.outputs[0], r.inputs[0])
        nt.links.new(BK.ao_multiply(nt, r.outputs[0]), bsdf.inputs["Base Color"])
        BK._set(bsdf, "Roughness", 0.8)
        BK._set(bsdf, ["Specular IOR Level", "Specular"], 0.15)
        return m
    mats = {
        "_body": bark_mat("paint_mt_body", 0.30, face=True), "_bark": bark_mat("paint_mt_bark", 0.30),
        "_spurs": bark_mat("paint_mt_spurs", 0.30, moss=False),
        "_crown_leaves": leafy("paint_mt_leaves", [(0.0, "#123a24"), (0.4, "#1f4a2e"), (0.7, "#3e7a3c"), (1.0, "#77a84a")]),
        "_vine_leaves": leafy("paint_mt_vleaves", [(0.0, "#1f4a2e"), (0.5, "#3e7a3c"), (1.0, "#8db04a")]),
        "_moss": leafy("paint_mt_moss", [(0.0, "#2a4a22"), (0.5, "#4f7a33"), (1.0, "#8db04a")]),
        "_crown_branches": BK.clay("paint_mt_branch", "#5a4632", 0.85),
        "_vines": BK.clay("paint_mt_vine", "#4f5f2a", 0.8),
        "_roots": BK.clay("paint_mt_roots", "#6a5a42", 0.85),
        "eye": BK.flat_material("paint_mt_eye", "#b8c060", 0.3, emission=0.2),
        "face_hair": BK.clay("paint_mt_brow", "#3a3226", 0.9),
        "_flowers": BK.card_material("paint_mt_flower", os.path.join(tex, "mt_flower.png")),
    }
    leaves_ob = None
    for o in fig_objects(rig):
        for suf, mm in mats.items():
            if o.name.endswith(suf):
                o.data.materials.clear()
                o.data.materials.append(mm)
                break
        if o.name.endswith("_crown_leaves"):
            leaves_ob = o
    if leaves_ob is not None:
        leaf_cards(rig, leaves_ob, tex)


def leaf_cards(rig, leaves_ob, tex, every=9):
    """Alpha-scissor painted leaf-cluster cards over the crown puffs (style guide 6), weighted like the puffs."""
    rng = np.random.RandomState(12)
    V = np.array([v.co for v in leaves_ob.data.vertices])
    N = BK.vertex_normals(leaves_ob)
    idx = np.arange(0, len(V), every)
    rng.shuffle(idx)
    c = V[idx] + N[idx] * 0.012
    n = N[idx] + rng.randn(len(idx), 3) * 0.35
    mats = [BK.card_material("paint_mt_leafcard_a", os.path.join(tex, "mt_leaves_a.png")),
            BK.card_material("paint_mt_leafcard_b", os.path.join(tex, "mt_leaves_b.png"))]
    out = []
    for k in range(2):
        sel = slice(k, None, 2)
        ob = BK.cards(rig.name + "_leafcards_%d" % k, c[sel], n[sel], 0.075, mats[k], rng, jitter=0.4)
        bones = [g.name for g in leaves_ob.vertex_groups]
        Wsrc = BK.read_groups(leaves_ob, bones)
        Vc = np.array([v.co for v in ob.data.vertices])
        Wc = KW.nearest_transfer(V, Wsrc, Vc, k=1)
        BK.set_weights(ob, Wc, bones)
        BK.set_attr(ob, "Color", np.tile([1.0, 1.0, 1.0, 1.0], (len(Vc), 1)), "FLOAT_COLOR")
        # cards lighter on top, darker beneath (the atlas holds the crown's light; AO from the puffs below)
        dz = np.clip((Vc[:, 2] - Vc[:, 2].min()) / max(np.ptp(Vc[:, 2]), 1e-3), 0, 1)
        shade = 0.72 + 0.28 * dz
        BK.set_attr(ob, "Color", np.c_[shade, shade, shade, np.ones(len(Vc))], "FLOAT_COLOR")
        mats_ob = ob
        mats_ob.parent = rig
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
        for col in leaves_ob.users_collection:
            col.objects.link(ob)
        for col in list(ob.users_collection):
            if col not in leaves_ob.users_collection:
                col.objects.unlink(ob)
        out.append(ob)
    return out


# ===========================================================================
# Camera and rendering
# ===========================================================================
def evaluated_bounds(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    lo = np.full(3, 1e9)
    hi = np.full(3, -1e9)
    for o in objs:
        if o.hide_render or o.type not in ("MESH", "CURVE"):
            continue
        ev = o.evaluated_get(dg)
        try:
            me = ev.to_mesh()
        except RuntimeError:
            continue
        n = len(me.vertices)
        if n:
            P = np.empty(n * 3, np.float32)
            me.vertices.foreach_get("co", P)
            P = P.reshape(-1, 3)
            M = np.array(o.matrix_world)
            P = P @ M[:3, :3].T + M[:3, 3]
            lo = np.minimum(lo, P.min(0))
            hi = np.maximum(hi, P.max(0))
        ev.to_mesh_clear()
    return lo, hi


def frame_persp(co, lo, hi, res, lens=55.0, elev=11.0, margin=1.08):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res
    co.data.type = "PERSP"
    co.data.lens = lens
    co.data.sensor_fit = "HORIZONTAL"
    co.data.sensor_width = 36.0
    c = (lo + hi) / 2
    w, h = (hi[0] - lo[0]) * margin, (hi[2] - 0.0) * margin + 0.15
    aspect = res[0] / res[1]
    fov_h = 2 * math.atan(18.0 / lens)
    fov_v = 2 * math.atan(math.tan(fov_h / 2) / aspect)
    d = max((w / 2) / math.tan(fov_h / 2), (h / 2) / math.tan(fov_v / 2)) + (hi[1] - lo[1]) * 0.15
    hv = 2 * d * math.tan(fov_v / 2)
    target = Vector((c[0], c[1] * 0.5, max(h / 2 - 0.05, hv / 2 - 0.62)))
    e = math.radians(elev)
    pos = target + Vector((0, -math.cos(e) * d, math.sin(e) * d))
    co.location = pos
    co.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()


def frame_ortho(co, center_x, width_m, height_m, res, z0=-0.02):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res
    co.data.type = "ORTHO"
    co.data.ortho_scale = max(width_m, height_m)
    co.data.sensor_fit = "AUTO"
    tilt = math.radians(5.0)
    zc = z0 + height_m / 2
    co.location = (center_x, -12.0 * math.cos(tilt), zc + 12.0 * math.sin(tilt))
    co.rotation_euler = (math.radians(90) - tilt, 0, 0)


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def label_pos(co, pts):
    sc = bpy.context.scene
    out = []
    for p in pts:
        v = world_to_camera_view(sc, co, Vector(p))
        out.append((float(v.x), float(1 - v.y)))
    return out


def silhouette(co, ground, path):
    """Flat-black silhouette of what is visible (alpha of a transparent-film render without the ground)."""
    sc = bpy.context.scene
    ground.hide_render = True
    sc.render.film_transparent = True
    keep = sc.eevee.taa_render_samples
    sc.eevee.taa_render_samples = 4
    render(path)
    sc.eevee.taa_render_samples = keep
    sc.render.film_transparent = False
    ground.hide_render = False
    return path


# ===========================================================================
# Shots
# ===========================================================================
def lineup_shot(name, figs, order, which, co, ground, out, meta, rot=32.0, spacing=1.55, props=True, pmats=None,
                res=(1500, 930), scale_human=None):
    for f in figs.values():
        place(f, 100.0)
    xs = {}
    prop_names = []
    for i, n in enumerate(order):
        rig = figs[n]
        sc = rig.get("stature", 1.0)
        place(rig, i * spacing, 0.0, rot, sc)
        Gp, pz = pose_figure(rig, which)
        xs[n] = i * spacing
        if props and pz.get("prop"):
            kind, side = pz["prop"]
            bpy.context.view_layer.update()
            hand = _palm_world(rig, Gp, side)
            nm = "%s_%s_%s" % (name, n, kind)
            prop_names += make_spear(nm, hand, pmats) if kind == "spear" else make_staff(nm, hand, pmats)
    show_only(order, figs, prop_names)
    bpy.context.view_layer.update()
    lo, hi = evaluated_bounds([o for n in order for o in fig_objects(figs[n])])
    frame_persp(co, lo, hi, res)
    path = render(os.path.join(out, name + ".png"))
    meta[name] = {"path": path, "labels": dict(zip(order, label_pos(co, [(xs[n], -0.25, 0.0) for n in order]))),
                  "tops": dict(zip(order, label_pos(co, [(xs[n], 0.0, 2.1) for n in order]))),
                  "tris": {n: json.loads(figs[n].get("tris", "{}")) for n in order}}
    for nm in prop_names:
        o = bpy.data.objects.get(nm)
        if o is not None:
            bpy.data.objects.remove(o)
    return path


def turnaround_shot(name, figs, fig, human, co, ground, out, meta, px_per_m=290.0, height=640):
    """Front, 3/4, side, back of one figure (idle pose-layer target), plus the 1.75 m human marker tile; each tile
    rendered orthographic at the same scale, with its silhouette."""
    tiles = []
    for f in figs.values():
        place(f, 100.0)
    rig = figs[fig]
    st = rig.get("stature", 1.0)
    hm = figs[human]
    hs = 1.75 / (1.596 * hm.get("stature", 1.0)) * hm.get("stature", 1.0)
    # marker
    place(hm, 0.0, 0.0, 0.0, hs)
    rest_pose(hm)
    show_only([human], figs)
    bpy.context.view_layer.update()
    w_m = 0.98
    frame_ortho(co, 0.0, w_m, height / px_per_m, (int(w_m * px_per_m), height), z0=-0.12)
    tiles.append({"view": "1.75 m human", "path": render(os.path.join(out, name + "_marker.png"))})
    for view, rot, w_m in (("front", 0.0, 0.9), ("3/4", 35.0, 0.9), ("side", 90.0, 0.9), ("back", 180.0, 0.9)):
        place(rig, 0.0, 0.0, rot, st)
        pose_figure(rig, "rest")
        show_only([fig], figs)
        bpy.context.view_layer.update()
        lo, hi = evaluated_bounds(fig_objects(rig))
        cx = (lo[0] + hi[0]) / 2
        w_m = max(w_m, (hi[0] - lo[0]) * 1.12)
        res = (int(w_m * px_per_m), height)
        frame_ortho(co, cx, w_m, height / px_per_m, res, z0=-0.12)
        tag = view.replace("/", "")
        p = render(os.path.join(out, "%s_%s.png" % (name, tag)))
        s = silhouette(co, ground, os.path.join(out, "%s_%s_sil.png" % (name, tag)))
        tiles.append({"view": view, "path": p, "sil": s})
    meta[name] = {"tiles": tiles, "tris": json.loads(rig.get("tris", "{}")), "fig": fig}


def rest_pose(rig):
    BK.rest_pose(rig)


def main():
    a = parse()
    run(a.kit, a.tex, a.out, a.paint, a.only, a.samples)


def run(kit, tex, out, paint=False, only="", samples=32, scene=None):
    """Renders the kit's shots, skipping the ones already in the shots json (resumable across lock sessions);
    the json is rewritten after every shot."""
    os.makedirs(out, exist_ok=True)
    ground, co = scene or setup_scene(tex, samples)
    figs = figures()
    metapath = os.path.join(out, "shots_%s%s.json" % (kit, "_paint" if paint else ""))
    meta = json.load(open(metapath)) if os.path.exists(metapath) else {}
    pm = prop_materials(paint)
    A0, A1 = "%s_A_0" % kit, "%s_A_1" % kit
    only = set(only.split(",")) if only else None

    def todo(key, shot):
        return (only is None or key in only) and shot not in meta

    def done():
        json.dump(meta, open(metapath, "w"), indent=1)
    if not paint:
        trio = ["human_0", "%s_A_0" % kit, "%s_B_0" % kit, "%s_C_0" % kit]
        for key, shot, which in (("variants_rest", "%s_variants_rest" % kit, "rest"),
                                 ("variants_action", "%s_variants_action" % kit, "action")):
            if todo(key, shot):
                lineup_shot(shot, figs, trio, which, co, ground, out, meta, pmats=pm,
                            rot=40.0 if kit == "floodborn" else 28.0, spacing=1.6 if kit == "floodborn" else 1.25)
                done()
        if todo("turn_f", "%s_A_turnaround_f" % kit):
            turnaround_shot("%s_A_turnaround_f" % kit, figs, A0, "human_1", co, ground, out, meta)
            done()
        if A1 in figs and todo("turn_m", "%s_A_turnaround_m" % kit):
            turnaround_shot("%s_A_turnaround_m" % kit, figs, A1, "human_1", co, ground, out, meta)
            done()
        if todo("sexes", "%s_A_body_types" % kit):
            lineup_shot("%s_A_body_types" % kit, figs, ["human_0", A0, A1, "human_1"], "action", co, ground, out,
                        meta, pmats=pm, spacing=1.5 if kit == "floodborn" else 1.2, rot=35.0)
            done()
    else:
        for f in (A0, A1):
            if f in figs:
                (paint_floodborn if kit == "floodborn" else paint_moc_tinh)(figs[f], tex)
        if todo("paint_action", "%s_A_painted_action" % kit):
            lineup_shot("%s_A_painted_action" % kit, figs, ["human_0", A0, A1], "action", co, ground, out, meta,
                        pmats=pm, spacing=1.55 if kit == "floodborn" else 1.25, rot=35.0)
            done()
        if todo("paint_rest", "%s_A_painted_rest" % kit):
            lineup_shot("%s_A_painted_rest" % kit, figs, [A0], "rest", co, ground, out, meta, pmats=pm, rot=38.0,
                        res=(640, 930))
            done()
        if todo("paint_close", "%s_A_painted_close" % kit):
            close_shot("%s_A_painted_close" % kit, figs, A0, co, out, meta)
            done()
    done()
    print("wrote", metapath)
    return ground, co


def close_shot(name, figs, fig, co, out, meta):
    """Head and shoulders, 3/4: the hide or bark paint up close."""
    for f in figs.values():
        place(f, 100.0)
    rig = figs[fig]
    place(rig, 0.0, 0.0, 35.0, 1.0)
    pose_figure(rig, "rest")
    show_only([fig], figs)
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = 1000, 930
    co.data.type = "PERSP"
    co.data.lens = 60
    co.data.sensor_fit = "HORIZONTAL"
    target = Vector((0.0, -0.05, 1.30))
    pos = target + Vector((-0.35, -1.75, 0.22))
    co.location = pos
    co.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
    meta[name] = {"path": render(os.path.join(out, name + ".png"))}


if __name__ == "__main__":
    main()
