"""Review renders of the Reed Marches stilt kit (Đồng Lau, dl_*): piece lineups with silhouettes, the open choices side by
side (fort roofs A/B/C, watch-tower caps A/B/C, heron marks A/B/C), and the diorama (a stilt fort and its floating
settlement in a reed sea) from three cameras in three light directions, for the owner to judge by eye (style guide
section 11). Opens the kit .blend that dong_lau_kit.py saved (--blend there):

    zsh blender_run.sh -b <kit.blend> -P tools/thuyvan_art/dong_lau/render_dong_lau.py -- --review DIR \
        [--pages landmarks,houses,moorings,racks,boats,fort_abc,tower_abc] [--diorama] \
        [--dirs silver_overcast,smoke_and_lantern,heron_morning] [--cams arrival,tower,yard] [--sky-dir DIR] [--fast]

Writes DIR/raw/<page>.png + .json + <page>_sil/ (lineups) and DIR/raw/diorama_<cam>_<dir>.png; compose_dong_lau.py
captions them. Everything but the kit pieces is a render-only stand-in: the water, the reed sea (built from the kit's
own reed cards), mud banks, herons, smoke, mist, the far hills (in the painted sky, paint_dong_lau.py --sky-dir) and the
1.75 m figures. The old stone lintel is Book II look-dev (Khar-Ul), shown only because the review brief asked for it.
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
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dlkit  # noqa: E402  (rebinds the village tvkit to this kit before render_village imports it)
sys.path.insert(0, os.path.join(HERE, "..", "village"))
import render_village as rv  # noqa: E402

DIRS = {k: v for k, v in json.load(open(os.path.join(HERE, "directions.json"))).items() if not k.startswith("_")}
PAL = dlkit.PAL
lin = dlkit.hex_lin
SKY_STRENGTH = 1.25


# ------------------------------------------------------------------------------------------------ scene basics
def kit_objects():
    return {ob.name: ob for ob in bpy.data.objects if ob.type == "MESH" and ob.parent is None
            and not ob.get("render_only") and not ob.get("render_only_copy") and not ob.name.endswith("_lod1")}


def clear_render_only():
    for o in [o for o in bpy.data.objects if o.get("render_only") or o.get("render_only_copy")]:
        bpy.data.objects.remove(o)
    for o in [o for o in bpy.data.objects if o.type == "LIGHT" or o.type == "LIGHT_PROBE"]:
        bpy.data.objects.remove(o)


def hide_all():
    for ob in bpy.data.objects:
        ob.hide_render = True


def copy_of(ob, loc, yaw=0.0, scale=1.0):
    c = ob.copy()
    bpy.context.scene.collection.objects.link(c)
    c.location = loc
    c.rotation_euler = (0, 0, yaw)
    c.scale = (scale, scale, scale)
    c.hide_render = False
    c["render_only_copy"] = True
    c["src"] = ob.name
    return c


def anchors_of(copy, prefix):
    """World positions of the source piece's anchor empties for a placed copy."""
    src = bpy.data.objects[copy["src"]]
    M = Matrix.Translation(copy.location) @ copy.rotation_euler.to_matrix().to_4x4() @ Matrix.Scale(copy.scale[0], 4)
    return [M @ ch.location for ch in src.children if ch.type == "EMPTY" and ch.name.startswith(prefix)]


def setup_render(fast=False, samples=64):
    rv.setup_render(fast)
    sc = bpy.context.scene
    ee = sc.eevee
    ee.taa_render_samples = 16 if fast else samples
    for k, v in (("use_raytracing", True), ("ray_tracing_method", "SCREEN"), ("use_shadows", True),
                 ("shadow_ray_count", 2), ("shadow_step_count", 8)):
        try:
            setattr(ee, k, v)
        except (AttributeError, TypeError):
            pass
    try:
        ee.ray_tracing_options.resolution_scale = "1"
    except (AttributeError, TypeError):
        pass
    try:
        sc.world.probe_resolution = "1024"
    except (AttributeError, TypeError):
        pass


def world(dname, sky_dir):
    """The painted panorama for camera rays and reflections (rotated so its painted sun glow sits at the sun's
    azimuth: the panorama has north at u = 0.5, east at 0.75), tinted toward the direction's ambient colour for the
    light it sheds."""
    d = DIRS[dname]
    w = bpy.data.worlds.get("dl_world") or bpy.data.worlds.new("dl_world")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0.0, 0.0, -math.pi / 2)
    nt.links.new(tc.outputs["Generated"], mp.inputs[0])
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(os.path.join(sky_dir, "dl_sky_%s.png" % dname), check_existing=True)
    nt.links.new(mp.outputs[0], env.inputs[0])
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(env.outputs["Color"], bg_cam.inputs["Color"])
    bg_cam.inputs["Strength"].default_value = SKY_STRENGTH
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.inputs[0].default_value = 0.55
    nt.links.new(env.outputs["Color"], tint.inputs[6])
    tint.inputs[7].default_value = lin(d["ambient"]["color"]) + (1,)
    bg_amb = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(tint.outputs[2], bg_amb.inputs["Color"])
    bg_amb.inputs["Strength"].default_value = d["ambient"]["energy"] * (1.5 if dname == "smoke_and_lantern" else 0.95)
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
    nt.links.new(bg_amb.outputs[0], mx.inputs[1])
    nt.links.new(bg_cam.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])


def sun(dname, az=None, el=None, energy=None, color=None, angle=None):
    for ob in [o for o in bpy.data.objects if o.type == "LIGHT" and o.get("dl_sun")]:
        bpy.data.objects.remove(ob)
    d = DIRS[dname]["sun"]
    a = math.radians(d["azimuth_deg"] if az is None else az)
    e = math.radians(d["elevation_deg"] if el is None else el)
    v = Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)))
    li = bpy.data.lights.new("dl_sun", "SUN")
    li.energy = d["energy"] * 2.7 if energy is None else energy
    li.color = lin(color or d["color"])
    li.angle = math.radians(d.get("angular_deg", 2.0) if angle is None else angle)
    ob = bpy.data.objects.new("dl_sun", li)
    ob["dl_sun"] = True
    ob.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ------------------------------------------------------------------------------------------------ fog in the paint
def fogify(dname, enable=True):
    """Depth fog folded into every surface material (aerial perspective in steps, as the game's fog will do): the
    surface mixes toward the direction's fog colour by 1 - exp(-density * distance), capped at 0.97; cut-out cards keep
    their holes. Idempotent; re-run per direction."""
    d = DIRS[dname]["fog"]
    for m in bpy.data.materials:
        if not m.use_nodes or m.name.startswith("fx_") or m.get("no_fog"):
            continue
        nt = m.node_tree
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out is None:
            continue
        mixn = nt.nodes.get("fog_mix")
        if mixn is None:
            link = next((lk for lk in nt.links if lk.to_node == out and lk.to_socket.name == "Surface"), None)
            if link is None:
                continue
            surf = link.from_socket
            nt.links.remove(link)
            cd = nt.nodes.new("ShaderNodeCameraData")
            m1 = nt.nodes.new("ShaderNodeMath")
            m1.operation = "MULTIPLY"
            m1.name = "fog_density"
            nt.links.new(cd.outputs["View Distance"], m1.inputs[0])
            m2 = nt.nodes.new("ShaderNodeMath")
            m2.operation = "EXPONENT"
            nt.links.new(m1.outputs[0], m2.inputs[0])
            m3 = nt.nodes.new("ShaderNodeMath")
            m3.operation = "SUBTRACT"
            m3.inputs[0].default_value = 1.0
            nt.links.new(m2.outputs[0], m3.inputs[1])
            m4 = nt.nodes.new("ShaderNodeMath")
            m4.operation = "MULTIPLY"
            m4.name = "fog_amount"
            nt.links.new(m3.outputs[0], m4.inputs[0])
            fac = m4.outputs[0]
            gt = next((n for n in nt.nodes if n.type == "MATH" and n.operation == "GREATER_THAN"), None)
            if gt is not None:
                m5 = nt.nodes.new("ShaderNodeMath")
                m5.operation = "MULTIPLY"
                nt.links.new(fac, m5.inputs[0])
                nt.links.new(gt.outputs[0], m5.inputs[1])
                fac = m5.outputs[0]
            em = nt.nodes.new("ShaderNodeEmission")
            em.name = "fog_emit"
            mixn = nt.nodes.new("ShaderNodeMixShader")
            mixn.name = "fog_mix"
            nt.links.new(fac, mixn.inputs[0])
            nt.links.new(surf, mixn.inputs[1])
            if gt is not None:
                tr = nt.nodes.new("ShaderNodeBsdfTransparent")
                hold = nt.nodes.new("ShaderNodeMixShader")
                nt.links.new(gt.outputs[0], hold.inputs[0])
                nt.links.new(tr.outputs[0], hold.inputs[1])
                nt.links.new(em.outputs[0], hold.inputs[2])
                nt.links.new(hold.outputs[0], mixn.inputs[2])
            else:
                nt.links.new(em.outputs[0], mixn.inputs[2])
            nt.links.new(mixn.outputs[0], out.inputs["Surface"])
        nt.nodes["fog_density"].inputs[1].default_value = -d["density"] if enable else 0.0
        nt.nodes["fog_amount"].inputs[1].default_value = 0.35 + 0.6 * d.get("aerial_perspective", 0.7)
        nt.nodes["fog_emit"].inputs["Color"].default_value = lin(d["color"]) + (1,)
        nt.nodes["fog_emit"].inputs["Strength"].default_value = SKY_STRENGTH * 0.92


def lanterns_on(strength):
    m = bpy.data.materials.get("tvd_paper")
    if m:
        m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = strength


# ------------------------------------------------------------------------------------------------ render-only materials
def mat_water(name="dl_water", rough=0.03, ripple=0.025):
    """Silver marsh water: the marsh_water ramp in long soft streaks, nearly a mirror, a fine ripple along X."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.004, 0.03, 1.0)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 3.0
    nz.inputs["Detail"].default_value = 2.0
    nt.links.new(mp.outputs[0], nz.inputs["Vector"])
    cr = nt.nodes.new("ShaderNodeValToRGB")
    W = PAL["marsh_water"]
    e = cr.color_ramp.elements
    e[0].position, e[0].color = 0.3, lin(W[0]) + (1,)
    e[1].position, e[1].color = 0.8, lin(W[1]) + (1,)
    nt.links.new(nz.outputs["Fac"], cr.inputs[0])
    nt.links.new(cr.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["IOR"].default_value = 1.33
    b.inputs["Specular IOR Level"].default_value = 0.65
    mp2 = nt.nodes.new("ShaderNodeMapping")
    mp2.inputs["Scale"].default_value = (0.05, 0.9, 1.0)
    nt.links.new(tc.outputs["Object"], mp2.inputs[0])
    wv = nt.nodes.new("ShaderNodeTexNoise")
    wv.inputs["Scale"].default_value = 2.5
    wv.inputs["Detail"].default_value = 1.0
    nt.links.new(mp2.outputs[0], wv.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = ripple
    bump.inputs["Distance"].default_value = 0.05
    nt.links.new(wv.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_tex(name, key, tile):
    """Box-projected kit texture (object space) for render-only ground (the mud banks)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.95
    b.inputs["Specular IOR Level"].default_value = 0.15
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / tile,) * 3
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(dlkit.TEX_DIR, key + ".png"), check_existing=True)
    t.projection = "BOX"
    t.projection_blend = 0.3
    nt.links.new(mp.outputs[0], t.inputs[0])
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    return m


def mat_fx(name, hexcol, alpha=0.5):
    m = rv.mat_cardfx("fx_" + name, hexcol, alpha=alpha)
    return m


def plane(name, size, z, mat, cx=0.0, cy=0.0):
    s = size / 2
    return rv.mesh_from(name, [(cx - s, cy - s, z), (cx + s, cy - s, z), (cx + s, cy + s, z), (cx - s, cy + s, z)],
                        [(0, 1, 2, 3)], mat, smooth=False)


def planar_probe(size=3000.0):
    try:
        lp = bpy.data.lightprobes.new("dl_mirror", "PLANE")
    except Exception as ex:   # noqa: BLE001
        print("PLANAR PROBE unavailable:", ex)
        return None
    po = bpy.data.objects.new("dl_mirror", lp)
    po.scale = (size / 2, size / 2, 1.0)
    po.location = (0, 0, 0.0)
    po["render_only"] = True
    bpy.context.scene.collection.objects.link(po)
    return po


# ------------------------------------------------------------------------------------------------ the reed sea
def reed_field(name, region, mask, spacing, rng, gold_of, h=(3.0, 4.2), w=(2.2, 3.2), cards=2):
    """Render-only reed banks from the kit's reed atlas: crossed cards on a jittered grid inside `region`
    (x0, x1, y0, y1) where mask(x, y) is true; gold_of(x, y) picks the gold or green atlas cells. One mesh."""
    x0, x1, y0, y1 = region
    verts, faces, uvs, wind = [], [], [], []
    xs = np.arange(x0, x1, spacing)
    ys = np.arange(y0, y1, spacing)
    for y in ys:
        for x in xs:
            px, py = x + rng.uniform(-0.45, 0.45) * spacing, y + rng.uniform(-0.45, 0.45) * spacing
            if not mask(px, py):
                continue
            g = gold_of(px, py)
            cell_choices = (0, 2) if g else (1, 3)
            hh = rng.uniform(*h) * (1.0 + 0.4 * max(0.0, (py - 250) / 600))
            ww = rng.uniform(*w) * (1.0 + 0.6 * max(0.0, (py - 250) / 600))
            yaw0 = rng.uniform(0, math.pi)
            for c in range(cards):
                yaw = yaw0 + c * math.pi / cards
                cell = cell_choices[rng.integers(0, 2)] if rng.random() < 0.35 else cell_choices[0]
                dx, dy = math.cos(yaw) * ww / 2, math.sin(yaw) * ww / 2
                lean = rng.normal(0, 0.15)
                k = len(verts)
                verts += [(px - dx, py - dy, -0.2), (px + dx, py + dy, -0.2),
                          (px + dx + lean, py + dy, hh), (px - dx + lean, py - dy, hh)]
                faces.append((k, k + 1, k + 2, k + 3))
                u0, u1 = (cell + 0.01) / 4.0, (cell + 0.99) / 4.0
                uvs += [(u0, 0.0), (u1, 0.0), (u1, 0.995), (u0, 0.995)]
                wind += [0.0, 0.0, 1.0, 1.0]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    uvl.data.foreach_set("uv", np.array(uvs, np.float32).ravel())      # one loop per vertex, in order
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    data = np.zeros((len(verts), 4), np.float32)
    # painted AO for the cards: darker at the root, a gentle top light; alpha = wind weight
    wv = np.array(wind, np.float32)
    data[:, 0] = data[:, 1] = data[:, 2] = 0.62 + 0.38 * wv
    data[:, 3] = wv
    ca.data.foreach_set("color", data.ravel())
    me.materials.append(dlkit.material("reedcard"))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["render_only"] = True
    print("REEDS", name, len(faces), "cards")
    return ob


def mud_bank(name, pts, z=0.25, rng=None):
    """A low mud bank (render-only): a flat polygon raised z, edges sloping into the water."""
    pts = np.asarray(pts, float)
    c = pts.mean(0)
    verts = [(c[0], c[1], z)]
    for p in pts:
        verts.append((c[0] + (p[0] - c[0]) * 0.82, c[1] + (p[1] - c[1]) * 0.82, z))
    for p in pts:
        verts.append((p[0], p[1], -0.4))
    n = len(pts)
    faces = [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)]
    faces += [(1 + i, 1 + n + i, 1 + n + (i + 1) % n, 1 + (i + 1) % n) for i in range(n)]
    return rv.mesh_from(name, verts, faces, mat_tex("dl_mud_ground", "mud", 4.0), smooth=True)


# ------------------------------------------------------------------------------------------------ herons, smoke, mist
def heron_mesh(name, flying=False):
    """Render-only white heron: body, S-neck, beak, legs (standing) or wide wings (flying); about 1.4 m tall."""
    b = dlkit.Builder(name, 7)
    if not flying:
        b.pebble((0, 0, 1.0), (0.38, 0.16, 0.2), "cloth_bone", rot=dlkit.rot_y(-0.5), segs=7, rings=5)
        b.tube([(-0.25, 0, 1.12), (-0.3, 0, 1.4), (-0.15, 0, 1.55), (-0.28, 0, 1.68)], [0.07, 0.05, 0.05, 0.06], 5,
               "cloth_bone")
        b.tube([(-0.3, 0, 1.69), (-0.62, 0, 1.64)], [0.035, 0.005], 4, "clay")
        for s in (-1, 1):
            b.tube([(0.02, s * 0.06, 0.9), (0.04, s * 0.07, 0.0)], 0.018, 4, "iron")
    else:
        b.pebble((0, 0, 0), (0.42, 0.13, 0.13), "cloth_bone", segs=7, rings=5)
        b.tube([(-0.38, 0, 0.02), (-0.5, 0, 0.12), (-0.62, 0, 0.08)], [0.06, 0.05, 0.05], 5, "cloth_bone")
        for s in (-1, 1):
            b.face([(-0.15, 0, 0.03), (0.2, 0, 0.03), (0.35, s * 1.0, 0.35), (-0.1, s * 1.05, 0.42)], "cloth_bone")
            b.face([(0.35, s * 1.0, 0.35), (-0.1, s * 1.05, 0.42), (0.05, s * 1.5, 0.2), (0.3, s * 1.45, 0.15)],
                   "cloth_bone")
        for s in (-1, 1):
            b.tube([(0.35, s * 0.05, 0.0), (0.85, s * 0.05, -0.05)], 0.015, 4, "iron")
    ob = b.obj()
    dlkit.bake_vertex_ao(ob, dist=0.3, ground=False)
    ob["render_only"] = True
    return ob


def _card(name, c, L, H, m):
    """A soft card centred at c (local X across, Z up), turned to face each camera in face_cards()."""
    verts = [(-L / 2, 0, -H / 2), (L / 2, 0, -H / 2), (L / 2, 0, H / 2), (-L / 2, 0, H / 2)]
    ob = rv.mesh_from(name, verts, [(0, 1, 2, 3)], m, uvs=[(0, 0), (1, 0), (1, 1), (0, 1)], smooth=False)
    ob.location = c
    ob["dl_card"] = True
    return ob


def face_cards(cam_loc):
    for ob in bpy.data.objects:
        if ob.get("dl_card"):
            dx, dy = cam_loc[0] - ob.location.x, cam_loc[1] - ob.location.y
            ob.rotation_euler = (0.0, 0.0, math.atan2(dx, -dy))


def smoke_at(p, rng, colour, n=4, drift=(1.0, 0.25)):
    """Kitchen smoke lying on the water (the bible's sensory anchor): soft camera-facing cards rising a little, then
    drifting low downwind."""
    m = mat_fx("smoke_" + colour.lstrip("#"), colour, alpha=0.6)
    obs = []
    for k in range(n):
        t = k / max(n - 1, 1)
        L = 3.0 + 7.0 * t
        H = 1.8 + 1.6 * t
        c = Vector(p) + Vector((drift[0] * (2 + 9 * t), drift[1] * (1 + 4 * t), 1.0 + 1.8 * t - 1.2 * t * t))
        obs.append(_card("smoke", c, L, H, m))
    return obs


def mist_band(name, c, length, height, yaw, colour, alpha=0.55):
    m = mat_fx("mist_" + colour.lstrip("#") + "_%d" % int(alpha * 100), colour, alpha=alpha)
    x, y, z = c
    return _card(name, (x, y, z + height / 2), length, height, m)


def lantern_lights(points, colour="#ffb060", power=70.0, radius=0.25):
    for k, p in enumerate(points):
        li = bpy.data.lights.new("dl_lamp%d" % k, "POINT")
        li.energy = power
        li.color = lin(colour)
        li.shadow_soft_size = radius
        try:
            li.use_shadow = False
        except AttributeError:
            pass
        ob = bpy.data.objects.new("dl_lamp%d" % k, li)
        ob.location = p
        ob["render_only"] = True
        bpy.context.scene.collection.objects.link(ob)


# ------------------------------------------------------------------------------------------------ lineups
def lineup(page, names, out, fast, spacing=4.0, stage="water", lens=40.0, cam_h_frac=0.5, figure=True, sil=True,
           dname="heron_morning", sky_dir=None, labels=None):
    """Pieces in a row along X with the 1.75 m figure at each one's left; on the marsh water (or a mud bank for
    land pieces); 3/4 from the front-left; sun from the front-left at 40 degrees (style guide 11)."""
    hide_all()
    clear_render_only()
    objs = {ob.name: ob for ob in bpy.data.objects if ob.type == "MESH" and ob.parent is None
            and not ob.get("render_only") and not ob.get("render_only_copy") and not ob.name.endswith("_lod1")}
    fig = objs["scale_figure"]
    widths = [objs[n].dimensions.x for n in names]
    gap = 1.6 if figure else 0.0
    total = sum(widths) + spacing * (len(names) - 1) + gap * len(names)
    x = -total / 2
    placed = {}
    tops = []
    for nm, w in zip(names, widths):
        ob = objs[nm]
        bb = [Vector(c) for c in ob.bound_box]
        minx = min(v.x for v in bb)
        miny, maxy = min(v.y for v in bb), max(v.y for v in bb)
        if figure:
            copy_of(fig, (x + 0.5, -(maxy - miny) / 2 - 0.9, 0.05 if stage == "mud" else 0.0), 0.3)
            x += gap
        loc = (x - minx, -(miny + maxy) / 2, 0.0)
        c = copy_of(ob, loc)
        placed[nm] = c
        tops.append(max(v.z for v in bb))
        x += w + spacing
    if True:
        plane("dl_stage_water", 4000, 0.0, mat_water("dl_water_lineup", rough=0.18, ripple=0.03))
    if stage == "mud":
        mud_bank("dl_stage_mud", [(-total / 2 - 4, -7), (total / 2 + 4, -7), (total / 2 + 4, 7),
                                  (-total / 2 - 4, 7)], z=0.05)
    hmax = max(tops)
    lens_ = lens
    half_fov = math.atan(18.0 / lens_)
    vfit = (hmax * 0.62 + 1.0) / math.tan(math.atan(10.125 / lens_))
    dist = max((total / 2 + 1.5) / math.tan(half_fov) * 1.02, vfit)
    tz = hmax * 0.45
    cam_loc = (-dist * 0.16, -dist, tz + dist * math.tan(math.radians(9.0 + 6.0 * min(cam_h_frac, 1.6))))
    cam = rv.camera(cam_loc, (0, 0, tz), lens=lens_)
    world(dname, sky_dir)
    sun(dname, az=215, el=40, energy=4.4, color="#fff1dc", angle=1.5)
    fogify(dname, enable=False)
    lanterns_on(0.0)
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(out, page + ".png")
    bpy.ops.render.render(write_still=True)
    meta = {"page": page, "pieces": {}}
    for nm, ob in placed.items():
        bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        foot = Vector((sum(v.x for v in bb) / 8, min(v.y for v in bb), 0.0))
        src = bpy.data.objects[nm]
        meta["pieces"][nm] = {"tris": dlkit.tri_count(src), "label": (labels or {}).get(nm, nm),
                              "materials": [m.name[4:] for m in src.data.materials if m],
                              "size_m": [round(v, 1) for v in src.dimensions], "screen": rv.screen_xy(cam, foot)}
    with open(os.path.join(out, page + ".json"), "w") as f:
        json.dump(meta, f, indent=1, ensure_ascii=False)
    if sil:
        rv.silhouettes(placed, os.path.join(out, page + "_sil"), cam_loc, (0, 0, tz), lens_)
    return meta


PAGES = {
    "landmarks": dict(names=["dl_mooring_fort", "dl_watch_tower", "dl_heron_banner", "dl_mangrove_gallery"],
                      spacing=6.0, lens=38.0, cam_h_frac=0.45),
    "houses": dict(names=["dl_reed_house_a", "dl_reed_house_b", "dl_reed_house_c", "dl_raft_house"], spacing=4.0,
                   lens=40.0, cam_h_frac=0.75),
    "moorings": dict(names=["dl_pile_forest_4m", "dl_pile_forest_6m", "dl_platform_ramp", "dl_platform_steps",
                            "dl_causeway", "dl_tally_post"], spacing=1.6, lens=40.0, cam_h_frac=0.6),
    "racks": dict(names=["dl_screen_rack", "dl_fish_rack", "dl_net_rack", "dl_soak_trough", "dl_reed_boat_burial",
                         "dl_dip_net"], spacing=1.4, lens=40.0, cam_h_frac=0.3, stage="mud"),
    "boats": dict(names=["dl_dugout", "dl_ferry_flat", "dl_reed_clump_gold", "dl_reed_clump_green",
                         "dl_reed_clump_cattail"], spacing=1.2, lens=40.0, cam_h_frac=0.3),
    "fort_abc": dict(names=["review_fort_A", "dl_mooring_fort", "review_fort_C"], spacing=8.0, lens=40.0,
                     cam_h_frac=0.45, figure=False,
                     labels={"review_fort_A": "A restrained", "dl_mooring_fort": "B the kit's default",
                             "review_fort_C": "C bold"}),
    "tower_abc": dict(names=["review_tower_A", "dl_watch_tower", "review_tower_C", "dl_heron_banner",
                             "review_banner_heron_b", "review_banner_heron_c"], spacing=4.0, lens=40.0,
                      cam_h_frac=0.45, figure=False,
                      labels={"review_tower_A": "cap A plain", "dl_watch_tower": "cap B default",
                              "review_tower_C": "cap C two-tier", "dl_heron_banner": "heron A standing",
                              "review_banner_heron_b": "heron B in the ring",
                              "review_banner_heron_c": "heron C with reeds"}),
}


# ------------------------------------------------------------------------------------------------ the diorama
CAMS = {
    # the barge's view: arriving up the channel, a mangrove arch framing the left, the fort ahead
    "arrival": dict(loc=(8.0, 52.0, 3.2), target=(-1.0, 170.0, 12.5), lens=32.0),
    # from a watch tower: the floating settlement, the reed bands and channels laid out
    "tower": dict(loc=(92.0, 62.0, 40.0), target=(-4.0, 158.0, 4.0), lens=30.0),
    # at Har-Kel's yard: the reed boat on its frame, fish and nets, the fort beyond
    "yard": dict(loc=(45.0, 75.0, 3.6), target=(-2.0, 170.0, 11.0), lens=28.0),
}

FORT = (0.0, 170.0)
POOL = ((0.0, 152.0), 84.0, 70.0)        # open water round the settlement (centre, rx, ry)
CHANNELS = [  # (polyline, half width)
    ([(0, -60), (2, 40), (-2, 100)], 16.0),
    ([(-6, 60), (-40, 50), (-120, 70), (-260, 60)], 9.0),
    ([(40, 60), (80, 50), (160, 70), (300, 40)], 9.0),
    ([(40, 210), (120, 260), (260, 300), (420, 330)], 10.0),
    ([(-40, 220), (-90, 300), (-120, 420), (-200, 620)], 8.0),
    ([(10, 230), (30, 330), (60, 520), (90, 800)], 12.0),
]


def _dist_poly(px, py, pts):
    best = 1e9
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        dx, dy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(px - ax - t * dx, py - ay - t * dy))
    return best


BANKS = [((35.0, 88.0), 21.0, 23.0), ((-61.0, 127.0), 16.0, 16.0)]   # mud banks: no reeds on them


def reed_mask(px, py):
    for (bx, by), brx, bry in BANKS:
        if ((px - bx) / brx) ** 2 + ((py - by) / bry) ** 2 < 1.0:
            return False
    (cx, cy), rx, ry = POOL
    if ((px - cx) / rx) ** 2 + ((py - cy) / ry) ** 2 < 1.0:
        return False
    for pts, hw in CHANNELS:
        if _dist_poly(px, py, pts) < hw + 3.0 * math.sin(px * 0.05 + py * 0.03):
            return False
    # long open lanes between the bands
    lane = math.sin((py + 26.0 * math.sin(px / 85.0)) / 38.0)
    if py > 120 and lane > 0.72:
        return False
    if py < -5:
        return False
    return True


def reed_gold(px, py):
    return math.sin((py + 18.0 * math.sin(px / 60.0)) / 21.0 + 0.4 * math.sin(px / 33.0)) > -0.15


def build_diorama(rng):
    clear_render_only()
    hide_all()
    K = kit_objects()
    R = {ob.name: ob for ob in bpy.data.objects if ob.get("review_only") and ob.parent is None}
    placed = []

    def put(nm, x, y, yaw=0.0, z=0.0, s=1.0):
        src = K.get(nm) or R.get(nm)
        c = copy_of(src, (x, y, z), yaw, s)
        placed.append(c)
        return c
    # water, the mirror probe, mud banks (Har-Kel's yard east of the channel; a bank west)
    plane("dl_water", 6000, 0.0, mat_water())     # reflections: Eevee's screen-space ray tracing (a planar
    # probe this size blanked the reflections in the test renders)
    mud_bank("bank_yard", [(18, 72), (40, 68), (54, 80), (52, 100), (32, 108), (16, 96)], z=0.3)
    mud_bank("bank_w", [(-70, 120), (-52, 112), (-46, 130), (-60, 142), (-76, 134)], z=0.25)
    # the fort and the mooring round it
    put("dl_mooring_fort", *FORT, 0.0)
    put("dl_heron_banner", -17.0, 118.0, 0.15)
    put("dl_heron_banner", 15.0, 116.0, -0.1)
    put("dl_reed_house_a", -38.0, 150.0, 0.35)
    put("dl_platform_ramp", -36.0, 132.0, 0.2)
    put("dl_reed_house_b", 33.0, 140.0, -0.3)
    put("dl_platform_steps", 27.0, 124.0, -0.15)
    put("dl_dip_net", 28.0, 123.0, -0.15 + math.pi, z=1.6)
    put("dl_reed_house_c", -22.0, 124.0, 0.1)
    put("dl_raft_house", 13.0, 130.0, 0.12)
    put("dl_raft_house", -54.0, 182.0, -0.5)
    put("dl_reed_house_a", 44.0, 178.0, -0.6)
    put("dl_reed_house_b", -30.0, 206.0, 0.4)
    put("dl_reed_house_c", 30.0, 205.0, -0.3)
    put("dl_platform_steps", -14.0, 152.0, 1.4)
    for (x, y, nm, yw) in ((-6.0, 130.0, "dl_pile_forest_4m", 0.3), (-48.0, 118.0, "dl_pile_forest_6m", 0.1),
                           (46.0, 156.0, "dl_pile_forest_4m", 1.0), (24.0, 196.0, "dl_pile_forest_6m", 0.5),
                           (-28.0, 108.0, "dl_pile_forest_4m", 0.8), (58.0, 128.0, "dl_pile_forest_4m", 0.2)):
        put(nm, x, y, yw)
    put("dl_screen_rack", -37.0, 131.0, 0.2, z=2.0)
    put("dl_fish_rack", -33.5, 135.0, 0.2, z=2.0)
    put("dl_net_rack", 26.0, 125.5, -0.15, z=1.6)
    put("dl_screen_rack", -14.0, 150.0, 1.4, z=1.6)
    # Har-Kel's yard on the east bank: the burial reed boat on its frame, racks, dugouts pulled up
    put("dl_reed_boat_burial", 34.0, 88.0, -0.45, z=0.3)
    put("dl_fish_rack", 48.0, 92.0, 0.5, z=0.3)
    put("dl_net_rack", 21.0, 97.0, 1.3, z=0.3)
    put("dl_screen_rack", 30.0, 101.0, -0.2, z=0.3)
    put("dl_soak_trough", 40.0, 78.0, 0.2, z=0.3)
    put("dl_dugout", 22.0, 82.0, 1.9, z=0.15)
    put("dl_dugout", 14.0, 74.0, 1.2)
    put("dl_tally_post", 17.0, 70.0, 0.3)
    # boats on the water (people in a few: 12 or fewer animated people in a scene)
    put("dl_ferry_flat", 3.0, 84.0, 1.5)
    put("dl_dugout", -6.0, 108.0, 1.3)
    put("dl_dugout", -4.0, 146.0, 0.3)
    put("dl_dugout", 6.0, 116.0, 2.2)
    # the hidden causeway with its tally posts (out across the open water to the east moorings)
    for k in range(4):
        put("dl_causeway", 56.0 + k * 0.4, 104.0 + k * 5.0, -0.08)
    put("dl_tally_post", 57.4, 103.0, 0.3)
    put("dl_tally_post", 59.2, 124.6, -0.5)
    # mangroves: the gallery framing the channel on the left (its root arches span the channel), more along the banks
    put("dl_mangrove_gallery", -13.0, 100.0, 0.0, s=1.25)
    put("dl_mangrove_gallery", 84.0, 196.0, 2.6, s=1.1)
    put("dl_mangrove_gallery", -66.0, 128.0, 0.9, s=1.2)
    put("dl_mangrove_gallery", 150.0, 120.0, 3.6, s=1.0)
    put("dl_mangrove_gallery", -120.0, 240.0, 1.9, s=1.15)
    # watch towers alone over the reed sea, 300-600 m out; far forts and towers in the fog
    for (x, y, yw) in ((-150.0, 330.0, 0.4), (138.0, 290.0, -0.3), (290.0, 520.0, 0.2), (-70.0, 560.0, 0.9),
                       (-330.0, 470.0, 0.5), (60.0, 760.0, 0.1)):
        put("dl_watch_tower", x, y, yw)
    put("dl_mooring_fort", 260.0, 820.0, 0.4, s=0.9)
    put("dl_mooring_fort", -420.0, 980.0, -0.3, s=0.8)
    put("dl_heron_banner", 236.0, 790.0, 0.4)
    # the Book II look-dev lintel, half under the water in the shallows north of the yard
    put("review_old_lintel", 40.0, 118.0, -0.5, z=-0.7)
    # reed clumps (kit pieces) standing in the water along the channel's edges
    for k in range(60):
        side = 1 if k % 2 else -1
        x = side * rng.uniform(17.0, 24.0)
        y = rng.uniform(55.0, 118.0)
        if side > 0 and 66 < y < 110:
            continue                    # the yard's bank
        put(["dl_reed_clump_gold", "dl_reed_clump_green", "dl_reed_clump_cattail"][k % 3], x, y,
            rng.uniform(0, 6.28), s=rng.uniform(0.9, 1.2))
    # the reed sea
    reed_field("reeds_near", (-260, 260, -10, 260), reed_mask, 2.6, rng, reed_gold)
    reed_field("reeds_mid", (-700, 700, 260, 700), reed_mask, 4.2, rng, reed_gold, h=(3.4, 4.4), w=(3.0, 4.2))
    reed_field("reeds_far", (-1400, 1400, 700, 1500), reed_mask, 9.0, rng, reed_gold, h=(4.0, 6.0), w=(6.0, 9.0),
               cards=1)
    # people: humans only until the Floodborn NPC body's grey box is approved (places_se.md §3); 10 in all
    fig = R["scale_figure"]
    for (x, y, z, yw) in ((-1.0, 156.6, 2.8, 0.2), (4.0, 154.0, 2.8, -0.4), (-36.0, 136.0, 2.0, 0.6),
                          (3.6, 86.0, 0.42, 1.5), (2.2, 80.6, 0.42, 1.5), (-6.0, 108.0, 0.15, 1.3),
                          (31.0, 84.0, 0.3, -0.8), (45.0, 90.0, 0.3, 0.4), (33.0, 134.0, 1.6, 0.0),
                          (13.0, 126.0, 0.42, 2.0)):
        f = copy_of(fig, (x, y, z), yw)
        placed.append(f)
    # herons: standing in the shallows, lifting out of the reeds
    hs = heron_mesh("heron_standing")
    hf = heron_mesh("heron_flying", flying=True)
    for (x, y, z, yw) in ((-15.0, 70.0, -0.25, 0.4), (16.0, 64.0, -0.25, 2.5), (-58.0, 104.0, -0.25, 1.0),
                          (55.0, 110.0, -0.25, 2.0)):
        c = hs.copy()
        bpy.context.scene.collection.objects.link(c)
        c.location, c.rotation_euler = (x, y, z), (0, 0, yw)
        c.scale = (1.4, 1.4, 1.4)
        c["render_only"] = True
    for k in range(11):
        c = hf.copy()
        bpy.context.scene.collection.objects.link(c)
        c.location = (rng.uniform(-50, 60), rng.uniform(90, 240), rng.uniform(9, 30))
        c.rotation_euler = (rng.normal(0, 0.1), rng.normal(0, 0.15), rng.uniform(-0.6, 0.6) + math.pi)
        c.scale = (2.0, 2.0, 2.0)
        c["render_only"] = True
    hs.hide_render = True
    hf.hide_render = True
    return placed


def dress_direction(dname, placed, rng_seed=7):
    """Per-direction dressing: smoke colour, mist bands, lanterns and hearth lights at dusk."""
    for o in [o for o in bpy.data.objects if o.get("dl_dress")]:
        bpy.data.objects.remove(o)
    for o in [o for o in bpy.data.objects if o.type == "LIGHT" and not o.get("dl_sun")]:
        bpy.data.objects.remove(o)
    rng = np.random.default_rng(rng_seed)
    d = DIRS[dname]
    smoke_col = {"silver_overcast": "#c9d2d0", "smoke_and_lantern": "#a89aa6", "heron_morning": "#e6ece8"}[dname]
    new = []
    for c in placed:
        if c.get("src") in ("dl_reed_house_c", "dl_raft_house", "dl_mooring_fort") and c.location.y < 400:
            for p in anchors_of(c, "anchor_smoke")[:1]:
                new += smoke_at(p, rng, smoke_col, n=4, drift=(1.0, 0.3))
    mist = d["targets"]["mist"]
    al = {"silver_overcast": 0.62, "smoke_and_lantern": 0.5, "heron_morning": 0.35}[dname]
    for (x, y, L, H, yw) in ((-60, 260, 420, 7, 0.05), (90, 320, 500, 9, -0.04), (-200, 430, 700, 14, 0.02),
                             (150, 530, 800, 18, 0.0), (0, 690, 1600, 26, 0.0)):
        new.append(mist_band("mist", (x, y, -0.5), L, H, yw, mist, al))
    for o in new:
        o["dl_dress"] = True
    if d.get("lanterns", 0) > 0:
        lanterns_on(9.0)
        pts = []
        for c in placed:
            pts += anchors_of(c, "anchor_lantern")
        lantern_lights([p for p in pts if p.y < 400], power=110.0)
        hearths = []
        for c in placed:
            hearths += anchors_of(c, "anchor_hearth_light")
        lantern_lights(hearths, colour="#ff8a3a", power=220.0, radius=0.4)
        for o in bpy.data.objects:
            if o.name.startswith("dl_lamp"):
                o["dl_dress"] = True
    else:
        lanterns_on(0.6)


def render_diorama(out, dnames, cams, fast, sky_dir, samples):
    rng = np.random.default_rng(1765)
    placed = build_diorama(rng)
    for dname in dnames:
        world(dname, sky_dir)
        sun(dname)
        fogify(dname)
        dress_direction(dname, placed)
        for cn in cams:
            c = CAMS[cn]
            rv.camera(c["loc"], c["target"], lens=c["lens"])
            face_cards(c["loc"])
            bpy.context.scene.render.filepath = os.path.join(out, "diorama_%s_%s.png" % (cn, dname))
            bpy.ops.render.render(write_still=True)
            print("DIORAMA", cn, dname)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--review", required=True)
    ap.add_argument("--pages", default="")
    ap.add_argument("--diorama", action="store_true")
    ap.add_argument("--dirs", default="silver_overcast,smoke_and_lantern,heron_morning")
    ap.add_argument("--cams", default="arrival,tower,yard")
    ap.add_argument("--sky-dir", required=True)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--fast", action="store_true")
    a, _ = ap.parse_known_args(argv)        # may share the command line with dong_lau_kit.py
    raw = os.path.join(a.review, "raw")
    os.makedirs(raw, exist_ok=True)
    setup_render(a.fast, a.samples)
    for page in filter(None, a.pages.split(",")):
        spec = dict(PAGES[page])
        names = spec.pop("names")
        lineup(page, names, raw, a.fast, sky_dir=a.sky_dir, **spec)
        print("PAGE", page)
    if a.diorama:
        setup_render(a.fast, a.samples)
        render_diorama(raw, a.dirs.split(","), a.cams.split(","), a.fast, a.sky_dir, a.samples)
    print("RENDER DONE")


if __name__ == "__main__":
    main()
