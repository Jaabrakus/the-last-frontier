"""Review renders of the Vạn Thủy kit (VANTHUY) for the owner to judge by eye (style guide section 11): piece lineups
with the 1.75 m figure and flat-black silhouettes, A/B/C variants where a choice is open (the Court Tower's height,
the court mark), and a diorama of a corner of the capital (the central lock with its floodgates and gate towers, the
court terraces and the Court Tower stepping up the court island, a lacquer tower, quay houses on the Lantern Ward,
a high bridge, the grain piers with a crane, sacks and granaries, junks, sampans, the Rain Market barge, banners and
lantern nets) from three cameras in four lights. Opens the .blend vt_kit.py saved (--blend there):

    zsh blender_run.sh -b <kit.blend> -P tools/thuyvan_art/vanthuy/render_vanthuy.py -- --out DIR \
        [--pages landmarks,tower_abc,court,marks_abc,lock,quay,piers,boats,bridge,archive_night,diorama] \
        [--dirs morning,noon,dusk,night] [--cams steps,overview,gate] [--fast]

Writes DIR/raw/<page>.png + .json (screen positions, triangles, material keys) and <page>_sil/ (silhouettes), and
DIR/raw/diorama_<cam>_<dir>.png; compose_vanthuy.py turns them into the captioned sheets. The diorama's water, islands,
trees, far karst islands (the ROCK kit's own meshes), mist, smoke, birds, figures (the VILLAGE porters) and sampans (the
VILLAGE sampan) are render-only stand-ins; the vt_* and lock_* pieces in it are the assets. The sky is PAINT's painted
panorama for morning, noon and dusk; the night sky is a gradient. Deterministic: fixed seeds and cameras.
"""

import argparse
import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "village"))
import render_village as rv  # noqa: E402  (setup_render, sun, camera, the render-only materials, puff trees, silhouettes)
import village_kit as vk  # noqa: E402
import vtkit  # noqa: E402

REPO = vtkit.REPO
PALJ = json.load(open(os.path.join(REPO, "docs", "thuyvan", "plan", "look", "palettes.json")))
VT = PALJ["albedo"]["van_thuy"]
R1 = PALJ["albedo"]["r1"]
lin = vtkit.hex_lin
S = 1.6                                     # Vạn Thủy's scale for the shared lock pieces
SKY = os.path.join(REPO, "assets", "thuyvan", "paint", "sky")
VT_TEX = vtkit.TEX_DIR
ROCK_DIR = os.path.join(REPO, "assets", "thuyvan", "rock")
# The four lights. Morning, noon and dusk are the art director's three directions (palettes.json); night is
# places_se.md 9.4's Blue Oil Night (PROPOSAL; the Seventh Tide).
DIRS = {"morning": "jade_mist_morning", "noon": "bright_saturated_noon", "dusk": "golden_lantern_dusk"}
NIGHT = {"sun": {"azimuth_deg": 120, "elevation_deg": 30, "color": "#dfe8f8", "energy": 0.35, "angular_deg": 1.0},
         "sky": {"zenith": "#121a3a", "horizon": "#2e3e6e"}, "ambient": {"color": "#2b3a6a", "energy": 0.6},
         "fog": {"color": "#26304e"}}
TITLE = {"morning": "Jade Mist Morning", "noon": "Bright Saturated Noon", "dusk": "Golden Lantern Dusk",
         "night": "Blue Oil Night (the Seventh Tide)"}


# ------------------------------------------------------------------------------------------------ scene basics
def kit():
    return {ob.name: ob for ob in bpy.data.objects if ob.type == "MESH" and ob.parent is None
            and not ob.get("render_only") and not ob.get("render_only_copy") and not ob.get("lod1")}


def clear_render_only():
    for o in [o for o in bpy.data.objects if o.get("render_only") or o.get("render_only_copy")]:
        bpy.data.objects.remove(o)
    for ob in bpy.data.objects:
        ob.hide_render = True


def place(ob, loc, yaw=0.0, scale=1.0, copy=True):
    """A linked copy (same mesh) of a kit piece, with its child meshes (junk sails) copied along."""
    c = ob.copy()
    bpy.context.scene.collection.objects.link(c)
    c.location = loc
    c.rotation_euler = (0, 0, yaw)
    c.scale = (scale, scale, scale)
    c.hide_render = False
    c["render_only_copy"] = True
    for ch in ob.children:
        if ch.type == "MESH" and "-colonly" not in ch.name:
            cc = ch.copy()
            bpy.context.scene.collection.objects.link(cc)
            cc.parent = c
            cc.matrix_parent_inverse = ch.matrix_parent_inverse.copy()
            cc.hide_render = False
            cc["render_only_copy"] = True
    return c


def village_piece(fn, *a, **kw):
    """A VILLAGE kit piece (sampan, porter) built fresh in this scene: render-only (it is that kit's asset)."""
    name = a[0] if a else kw.get("name")
    ob = bpy.data.objects.get(name)
    if ob is not None:
        return ob
    res = fn(*a, **kw)
    b = res[0]
    ob = b.obj()
    vk.tvkit.bake_vertex_ao(ob, dist=1.0)
    ob["render_only_src"] = True
    ob.hide_render = True
    for ch in ob.children:
        ch.hide_render = True
    return ob


def tex_img(nt, path, tile, tc, proj="BOX", blend=0.25):
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / tile,) * 3
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(path, check_existing=True)
    t.projection = proj
    t.projection_blend = blend
    nt.links.new(mp.outputs[0], t.inputs[0])
    return t.outputs["Color"]


def mat_box(name, path, tile, tint=(1, 1, 1), fog=None):
    """Box-projected painted texture in object space (render-only islands, far karst); fog = (hex, d0, d1, max)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.95
    b.inputs["Specular IOR Level"].default_value = 0.1
    tc = nt.nodes.new("ShaderNodeTexCoord")
    c = tex_img(nt, path, tile, tc)
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.blend_type = "MULTIPLY"
    mx.inputs[0].default_value = 1.0
    nt.links.new(c, mx.inputs[6])
    mx.inputs[7].default_value = tuple(tint) + (1,)
    nt.links.new(mx.outputs[2], b.inputs["Base Color"])
    if fog:
        fog_mix(m, fog)
    return m


def fog_mix(m, fog):
    """Aerial perspective for far render-only things: mix the surface toward an emissive fog colour by view distance."""
    nt = m.node_tree
    out = nt.nodes["Material Output"]
    src = out.inputs["Surface"].links[0].from_socket
    cd = nt.nodes.new("ShaderNodeCameraData")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = fog[1]
    mr.inputs["From Max"].default_value = fog[2]
    mr.inputs["To Max"].default_value = fog[3]
    nt.links.new(cd.outputs["View Distance"], mr.inputs["Value"])
    em = nt.nodes.new("ShaderNodeEmission")
    em.name = "fog_emit"
    em.inputs["Color"].default_value = lin(fog[0]) + (1,)
    ms = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(mr.outputs[0], ms.inputs[0])
    nt.links.new(src, ms.inputs[1])
    nt.links.new(em.outputs[0], ms.inputs[2])
    nt.links.new(ms.outputs[0], out.inputs["Surface"])


def set_fog_colour(hexcol, strength=1.0):
    for m in bpy.data.materials:
        if m.node_tree and "fog_emit" in m.node_tree.nodes:
            n = m.node_tree.nodes["fog_emit"]
            n.inputs["Color"].default_value = lin(hexcol) + (1,)
            n.inputs["Strength"].default_value = strength


def mat_water(name="vt_water"):
    """Render-only canal water (Glitter Noon): the van_thuy river ramp, painted light streaks, a soft ripple bump and
    a low roughness so the sky, sails and roofs glitter in it (the game's river shader does this its own way)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.1
    b.inputs["Specular IOR Level"].default_value = 0.55
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.012, 0.05, 1.0)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 3.0
    nz.inputs["Detail"].default_value = 2.0
    nt.links.new(mp.outputs[0], nz.inputs["Vector"])
    cr = nt.nodes.new("ShaderNodeValToRGB")
    e = cr.color_ramp.elements
    e[0].position, e[0].color = 0.35, lin(VT["river"][0]) + (1,)
    e[1].position, e[1].color = 0.75, lin(VT["river"][2]) + (1,)
    e.new(0.55).color = lin(VT["river"][1]) + (1,)
    cr.color_ramp.interpolation = "CONSTANT"
    nt.links.new(nz.outputs["Fac"], cr.inputs[0])
    nt.links.new(cr.outputs[0], b.inputs["Base Color"])
    mp2 = nt.nodes.new("ShaderNodeMapping")
    mp2.inputs["Scale"].default_value = (0.25, 0.6, 1.0)
    nt.links.new(tc.outputs["Object"], mp2.inputs[0])
    wv = nt.nodes.new("ShaderNodeTexNoise")
    wv.inputs["Scale"].default_value = 1.5
    wv.inputs["Detail"].default_value = 3.0
    nt.links.new(mp2.outputs[0], wv.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.22
    nt.links.new(wv.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def emissions(paper=0.0, oil=0.0):
    for key, s in (("paper", paper), ("oil_glass", oil)):
        m = bpy.data.materials.get(vtkit.PREFIX + key)
        if m:
            m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = s
    m = bpy.data.materials.get("tvv_paper")          # the village lanterns on the sampans
    if m:
        m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = paper


def world_painted(direction):
    """PAINT's painted panorama for camera rays (north = Blender +Y at u 0.5, sky.json's convention) and the direction's
    flat coloured ambient for lighting (rv.world's trick); night: a gradient with a few stars."""
    w = bpy.data.worlds.get("vt_world") or bpy.data.worlds.new("vt_world")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    if direction == "night":
        d = NIGHT
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Generated"], sep.inputs[0])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        el = ramp.color_ramp.elements
        el[0].position, el[0].color = 0.0, lin(d["sky"]["horizon"]) + (1,)
        el[1].position, el[1].color = 0.45, lin(d["sky"]["zenith"]) + (1,)
        nt.links.new(sep.outputs["Z"], ramp.inputs[0])
        vor = nt.nodes.new("ShaderNodeTexVoronoi")
        vor.inputs["Scale"].default_value = 120.0
        nt.links.new(tc.outputs["Generated"], vor.inputs["Vector"])
        st = nt.nodes.new("ShaderNodeMapRange")
        st.inputs["From Min"].default_value = 0.035
        st.inputs["From Max"].default_value = 0.0
        nt.links.new(vor.outputs["Distance"], st.inputs["Value"])
        add = nt.nodes.new("ShaderNodeMix")
        add.data_type = "RGBA"
        add.blend_type = "ADD"
        nt.links.new(st.outputs[0], add.inputs[0])
        nt.links.new(ramp.outputs[0], add.inputs[6])
        add.inputs[7].default_value = (0.8, 0.85, 1.0, 1)
        skycol = add.outputs[2]
        amb = d["ambient"]
        strength = 1.0
    else:
        d = PALJ["directions"][DIRS[direction]]
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.vector_type = "VECTOR"
        mp.inputs["Rotation"].default_value = (0, 0, math.pi / 2)
        nt.links.new(tc.outputs["Generated"], mp.inputs[0])
        env = nt.nodes.new("ShaderNodeTexEnvironment")
        env.image = bpy.data.images.load(os.path.join(SKY, "tv_sky_%s.png" % DIRS[direction]), check_existing=True)
        nt.links.new(mp.outputs[0], env.inputs["Vector"])
        skycol = env.outputs["Color"]
        amb = d["ambient"]
        strength = 1.0
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(skycol, bg_cam.inputs["Color"])
    bg_cam.inputs["Strength"].default_value = strength
    bg_amb = nt.nodes.new("ShaderNodeBackground")
    bg_amb.inputs["Color"].default_value = lin(amb["color"]) + (1,)
    bg_amb.inputs["Strength"].default_value = amb["energy"] * 0.75
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
    nt.links.new(bg_amb.outputs[0], mx.inputs[1])
    nt.links.new(bg_cam.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])
    return d


def sun_for(direction, scale=2.1):
    if direction == "night":
        d = NIGHT["sun"]
        return rv.sun("noon", az_deg=d["azimuth_deg"], el_deg=d["elevation_deg"], strength=d["energy"] * 3.0,
                      color=d["color"], angle_deg=1.0)
    return rv.sun(direction if direction != "noon" else "noon", strength=None)


def eevee_reflections(on=True):
    ee = bpy.context.scene.eevee
    for k, v in (("use_raytracing", on), ("ray_tracing_method", "SCREEN")):
        try:
            setattr(ee, k, v)
        except (AttributeError, TypeError):
            pass


# ------------------------------------------------------------------------------------------------ lineups
def figure():
    return village_piece(vk.porter, "porter_standing", "stand")


LIFT = ("court_banner", "lantern_net", "door_lamp")      # hanging pieces: lifted so their lowest point is on the grass


def lineup(page, names, out, spacing=4.0, lens=40.0, cam_el=0.12, extra=None, scales=None, labels=None, sil=True,
           yaws=None, target_frac=0.48):
    """Pieces in a row along X on the painted grass, the 1.75 m figure at each one's left foot; a 3/4 view from the
    front-left under the lineup sun (elevation 40, front-left), Bright Saturated Noon's sky."""
    clear_render_only()
    objs = kit()
    rv.ground_plane(size=2000.0)
    fig = figure()
    scales = scales or {}
    yaws = yaws or {}
    placed, tops, widths = {}, [], []
    for nm in names:
        s = scales.get(nm, 1.0)
        widths.append(objs[nm].dimensions.x * s)
    total = sum(widths) + spacing * (len(names) - 1)
    x = -total / 2
    for nm, w in zip(names, widths):
        ob = objs[nm]
        s = scales.get(nm, 1.0)
        bb = [Vector(c) * s for c in ob.bound_box]
        minx, miny, maxy = min(b.x for b in bb), min(b.y for b in bb), max(b.y for b in bb)
        zoff = -min(b.z for b in bb) if any(t in nm for t in LIFT) else 0.0
        c = place(ob, (x - minx, -(miny + maxy) / 2, zoff), yaws.get(nm, 0.0), s)
        c.name = "show_" + nm
        place(fig, (x - 1.0, -(maxy - miny) / 2 - 1.2, 0.0), 0.0)
        placed[nm] = c
        tops.append(max(b.z for b in bb) + zoff)
        x += w + spacing
    if extra:
        extra(placed)
    hmax = max(tops)
    tz = hmax * target_frac
    dist = max((total / 2 + 1.5) / (18.0 / lens), hmax * 0.62 / (10.125 / lens)) * 1.03
    cam_loc = (-dist * 0.16, -dist, tz + dist * cam_el)
    cam = rv.camera(cam_loc, (0, 0, tz), lens=lens)
    world_painted("noon")
    rv.sun("noon", az_deg=215, el_deg=40, strength=4.6, color="#fff3d9", angle_deg=1.5)
    emissions(0.0, 0.0)
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(out, page + ".png")
    bpy.ops.render.render(write_still=True)
    meta = {"page": page, "pieces": {}}
    man = json.load(open(os.path.join(REPO, "assets", "thuyvan", "vanthuy", "manifest.json")))["pieces"]
    for nm, ob in placed.items():
        bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        foot = Vector((sum(b.x for b in bb) / 8, min(b.y for b in bb), 0.0))
        mi = man.get(nm, {})
        meta["pieces"][nm] = {"tris": mi.get("tris", vtkit.tri_count(ob)), "tris_lod1": mi.get("tris_lod1"),
                              "sails_tris": mi.get("sails_tris"), "budget": mi.get("budget"),
                              "materials": [m.name[len(vtkit.PREFIX):] if m.name.startswith(vtkit.PREFIX) else m.name
                                            for m in ob.data.materials if m],
                              "size_m": [round(v * scales.get(nm, 1.0), 1) for v in objs[nm].dimensions],
                              "scale": scales.get(nm, 1.0), "label": (labels or {}).get(nm),
                              "screen": rv.screen_xy(cam, foot)}
    with open(os.path.join(out, page + ".json"), "w") as f:
        json.dump(meta, f, indent=1)
    if sil:
        rv.silhouettes(placed, os.path.join(out, page + "_sil"), cam_loc, (0, 0, tz), lens)
    return meta


def on_barge(placed):
    b = placed.get("vt_market_barge")
    if b is not None:
        a = kit()["vt_awning_madder"]
        place(a, b.location + Vector((0, 0, 0.9)), 0.0)


PAGES = {
    "landmarks": dict(names=["vt_court_tower", "lock_gate_tower", "vt_lacquer_tower", "vt_granary_hall",
                             "vt_treadwheel_crane"], spacing=10.0, lens=50.0,
                      scales={"lock_gate_tower": S},
                      labels={"lock_gate_tower": "lock_gate_tower at Vạn Thủy scale (x1.6 = 46 m)"}),
    "tower_abc": dict(names=["vt_court_tower", "vt_court_tower_B", "vt_court_tower_C"], spacing=14.0, lens=45.0,
                      labels={"vt_court_tower": "A  95 m above the water (the design)",
                              "vt_court_tower_B": "B  lower and wider",
                              "vt_court_tower_C": "C  bold: six roofs, taller"}),
    "court": dict(names=["vt_court_terrace_1", "vt_court_terrace_2", "vt_court_terrace_3", "vt_court_banner"],
                  spacing=10.0, lens=40.0),
    "marks_abc": dict(names=["vt_court_banner", "vt_court_banner_b", "vt_court_banner_c"], spacing=3.0, lens=55.0,
                      cam_el=0.03, target_frac=0.5,
                      labels={"vt_court_banner": "A  stamp frame", "vt_court_banner_b": "B  towers through the ring",
                              "vt_court_banner_c": "C  bold, falling water"}),
    "lock": dict(names=["lock_chamber_wall", "lock_gate_tower", "lock_gate_leaf_pair", "lock_winch_wheel",
                        "lock_sluice_port", "lock_gate_gallery"], spacing=6.0, lens=40.0),
    "quay": dict(names=["vt_quay_house_a", "vt_quay_house_b", "vt_quay_house_c", "vt_quay_steps",
                        "vt_quay_steps_patched", "vt_drain_mouth", "vt_notice_board", "vt_door_lamp"],
                 spacing=3.0, lens=40.0),
    "piers": dict(names=["vt_pier_finger", "vt_pier_finger_end", "vt_treadwheel_crane", "vt_sacks_heap",
                         "vt_crates_stack", "vt_jars_cluster"], spacing=4.0, lens=40.0),
    "boats": dict(names=["vt_junk_river", "vt_junk_sea", "vt_market_barge", "vt_awning_ochre"], spacing=6.0, lens=40.0,
                  extra=on_barge),
    "bridge": dict(names=["vt_high_bridge", "vt_high_bridge_closed"], spacing=10.0, lens=40.0),
    "archive_night": dict(names=["vt_archive_wall", "vt_archive_wall_gauge", "vt_lantern_net",
                                 "vt_district_banner_lantern_ward", "vt_district_banner_grain_piers",
                                 "vt_district_banner_naval_basin", "vt_district_banner_archive",
                                 "vt_district_banner_rain_market"], spacing=2.5, lens=40.0),
}


# ------------------------------------------------------------------------------------------------ the diorama
def island(name, x0, x1, y0, y1, top=3.0, key="paving"):
    """A render-only island: ashlar sides from the canal bed, a paved top."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z)) for z in (-4.0, top) for (x, y) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((vs[i], vs[j], vs[4 + j], vs[4 + i]))
    bm.faces.new(vs[4:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat_box("vt_isl_side", os.path.join(VT_TEX, "ashlar.png"), 6.0))
    me.materials.append(mat_box("vt_isl_top", os.path.join(VT_TEX, key + ".png"), 4.0, tint=(0.8, 0.8, 0.78)))
    for p in me.polygons:
        p.material_index = 1 if p.normal.z > 0.5 else 0
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["render_only"] = True
    return ob


def quay_edge(objs, x0, y0, x1, y1, face, skip=()):
    """vt_quay_wall_20m modules along an island edge (their face toward `face`: 'S', 'N', 'E', 'W'); `skip`: (a, b)
    spans along the edge (in the varying coordinate) left open for steps."""
    yaw = {"S": 0.0, "N": math.pi, "E": math.pi / 2, "W": -math.pi / 2}[face]
    L = math.hypot(x1 - x0, y1 - y0)
    n = max(1, int(round(L / 20.0)))
    for k in range(n):
        t = (k + 0.5) / n
        v = (y0 + (y1 - y0) * t) if x0 == x1 else (x0 + (x1 - x0) * t)
        if any(a - 10.0 < v < b_ + 10.0 for (a, b_) in skip):
            continue
        place(objs["vt_quay_wall_20m"], (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0.0), yaw)


def fill_block(objs, rng, x0, x1, y0, y1, z=3.0, step=17.0, p=0.8, avoid=(), trees=0.12):
    """Pack an island block with the kit's quay houses (random quarter turns, a street every fourth row and column)
    and a few trees, so the city reads dense with no animated people (places_se.md 0: busyness from goods, boats,
    washing, smoke and birds)."""
    names = ["vt_quay_house_a", "vt_quay_house_b", "vt_quay_house_a", "vt_quay_house_b", "vt_granary_hall"]
    nx = int((x1 - x0) // step)
    ny = int((y1 - y0) // step)
    for i in range(nx):
        for j in range(ny):
            if i % 4 == 3 or j % 4 == 3:
                continue
            x = x0 + (i + 0.5) * step + rng.uniform(-1.5, 1.5)
            y = y0 + (j + 0.5) * step + rng.uniform(-1.5, 1.5)
            if any(a <= x <= b_ and c <= y <= d for (a, b_, c, d) in avoid):
                continue
            r = rng.random()
            if r < trees:
                rv.puff_tree("ftree%d_%d" % (int(x), int(y)), (x, y, z), rng.uniform(10, 16), 4.5, 5, R1["broadleaf"], rng)
                continue
            if r > p + trees:
                continue
            nm = names[int(rng.integers(0, 4))] if rng.random() > 0.04 else names[4]
            if nm == "vt_granary_hall" and (i % 4 == 2 or j % 4 == 2):
                nm = "vt_quay_house_b"
            place(objs[nm], (x, y, z), float(rng.integers(0, 4)) * math.pi / 2)


def card(name, mat, c, w, h, face_to=None, yaw=0.0, horiz=False):
    me = bpy.data.meshes.new(name)
    if horiz:
        vs = [(-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0)]
    else:
        vs = [(-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, h), (-w / 2, 0, h)]
    me.from_pydata(vs, [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new(name="UVMap")
    for li, (u, v) in zip(range(4), ((0, 0), (1, 0), (1, 1), (0, 1))):
        uv.data[li].uv = (u, v)
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = c
    ob.rotation_euler = (0, 0, yaw)
    ob["render_only"] = True
    ob["face_cam"] = face_to is not None
    return ob


def face_camera(cam):
    for ob in bpy.data.objects:
        if ob.get("face_cam"):
            d = cam.location - ob.location
            ob.rotation_euler = (0, 0, math.atan2(d.y, d.x) - math.pi / 2)


def jet(name, mat, p0, out, drop, width, n=8):
    """A sluice jet: a curved white ribbon from the port arcing out and down to the water."""
    p0 = np.asarray(p0, float)
    vs, fs, uvs = [], [], []
    for i in range(n + 1):
        t = i / n
        c = p0 + np.array([0, -out * t, -drop * t * t])
        wv = width * (1 + 0.6 * t)
        for s in (-0.5, 0.5):
            vs.append(tuple(c + [s * wv, 0, 0]))
            uvs.append((s + 0.5, t))
    for i in range(n):
        fs.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    me = bpy.data.meshes.new(name)
    me.from_pydata(vs, [], fs)
    uv = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            uv.data[li].uv = uvs[me.loops[li].vertex_index]
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["render_only"] = True
    return ob


def birds(rng, n, center, spread, z0, z1):
    m = rv.mat_flat("vt_bird", "#2a2f3a")
    for k in range(n):
        c = np.asarray(center) + [rng.uniform(-spread, spread), rng.uniform(-spread, spread) * 0.5, 0]
        c[2] = rng.uniform(z0, z1)
        s = rng.uniform(0.9, 1.5)
        vs = [(-1.0 * s, 0, 0.35 * s), (0, 0, 0), (1.0 * s, 0, 0.35 * s), (0, 0, 0.12 * s)]
        me = bpy.data.meshes.new("bird%d" % k)
        me.from_pydata(vs, [], [(0, 1, 3), (1, 2, 3)])
        me.materials.append(m)
        ob = bpy.data.objects.new("bird%d" % k, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = tuple(c)
        ob.rotation_euler = (0, 0, rng.uniform(-0.4, 0.4))
        ob["render_only"] = True
        ob["face_cam"] = True


def far_karst(rng):
    """The rim (VT11): the ROCK kit's far and hero karst meshes as islands standing in sea haze 0.7-2.2 km out, with
    the painted karst rock and a strong fog mix (render-only use of that kit's assets)."""
    srcs = []
    for nm in ("karst_far_a", "karst_far_b", "karst_far_c", "karst_far_d", "karst_hero_a", "karst_hero_c",
               "karst_hero_e"):
        p = os.path.join(ROCK_DIR, nm + ".glb")
        if not os.path.exists(p):
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=p)
        new = [o for o in bpy.data.objects if o not in before]
        for o in new:
            o.hide_render = True
            o["render_only_src"] = True
        srcs += [o for o in new if o.type == "MESH"]
    mat = mat_box("vt_karst_far", os.path.join(ROCK_DIR, "textures", "karst_face.png"), 16.0,
                  tint=lin(R1["karst_limestone"][1]), fog=("#c4d8e0", 400.0, 2600.0, 0.62))
    for o in srcs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    ring = [(-25, 900), (-8, 1300), (5, 760), (18, 1600), (30, 1100), (42, 1900), (55, 820), (68, 1400), (-40, 1250),
            (-55, 980), (-70, 1700), (80, 1000), (-15, 2100), (12, 2300), (35, 2000), (95, 1500), (-85, 1300),
            (110, 1900), (-100, 1800), (125, 1200)]
    for k, (az, r) in enumerate(ring):
        o = srcs[k % len(srcs)]
        a = math.radians(az)
        s = rng.uniform(0.8, 1.5) * (0.85 if "hero" in o.name else 1.0)
        c = place(o, (r * math.sin(a), 120 + r * math.cos(a), -8.0), rng.uniform(0, 6.28), s)
        c.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1], rng.uniform(0, 6.28))
        c.scale = (1.8 * s, 1.8 * s, 0.9 * s)          # the sea islands: broader and lower than R1's towers
        bpy.context.view_layer.update()
        # pine puffs on the near ones' crowns
        if r < 1500:
            vs = [c.matrix_world @ v.co for v in o.data.vertices]
            top = max(v.z for v in vs)
            crown = [v for v in vs if v.z > top * 0.45]
            for j in range(14 if r < 1100 else 8):
                v = crown[int(rng.integers(0, len(crown)))]
                t = rv.puff_tree("kpine%d_%d" % (k, j), (v.x, v.y, v.z - 5.0), 14.0, 11.0, 4, R1["pine"], rng,
                                 pine=True)
                pm = t.data.materials[1]
                if "fog_emit" not in pm.node_tree.nodes:
                    fog_mix(pm, ("#c4d8e0", 400.0, 2600.0, 0.6))


def diorama_scene(rng):
    """Lay out the corner of the capital (north = +Y; water z 0; quays +3): returns the cameras."""
    clear_render_only()
    objs = kit()
    wat = rv.mesh_from("vt_water", [(-4000, -4000, 0), (4000, -4000, 0), (4000, 4000, 0), (-4000, 4000, 0)],
                       [(0, 1, 2, 3)], mat_water(), smooth=False)
    wat.hide_render = False
    # islands: the Lantern Ward (W), the lock quays, the court island (N), the grain island (E), the archive (NE)
    for (nm, a) in (("isl_lantern", (-300, -115, -320, 220)), ("isl_lockw", (-75, -46, -70, 54)),
                    ("isl_locke", (46, 92, -70, 54)), ("isl_court", (-92, 92, 54, 260)),
                    ("isl_grain", (92, 300, -140, 104)), ("isl_archive", (130, 260, 150, 300)),
                    ("isl_far_w", (-520, -360, -200, 260)), ("isl_south", (-60, 300, -620, -420)),
                    ("isl_point", (-115, -10, -380, -280))):
        island(nm, *a).hide_render = False
    quay_edge(objs, -115, -320, -115, 220, "E", skip=((-176.0, -160.0),))
    quay_edge(objs, -75, -70, -75, 54, "W", skip=((14.0, 26.0),))
    quay_edge(objs, -75, -70, -46, -70, "S")
    quay_edge(objs, -115, -280, -10, -280, "N", skip=((-68.0, -52.0),))
    quay_edge(objs, -10, -380, -10, -280, "E")
    quay_edge(objs, 46, -70, 92, -70, "S")
    quay_edge(objs, 92, -140, 300, -140, "S")
    quay_edge(objs, -92, 54, -46, 54, "S")
    quay_edge(objs, 46, 54, 92, 54, "S")
    # ---- the central lock (the shared lock kit x1.6): chamber x -30..30, gates at y -40 and +50 (drawn 90 m long; the
    # design's 140 m is shortened here so the Court Tower stands close behind the gates, as on the sheet)
    for y in np.arange(-40 + 16, 50, 32.0):
        place(objs["lock_chamber_wall"], (-30.0, y, 0.0), math.pi / 2, S)
        place(objs["lock_chamber_wall"], (30.0, y, 0.0), -math.pi / 2, S)
    for gy in (-40.0, 50.0):
        place(objs["lock_gate_leaf_pair"], (0.0, gy, 0.0), 0.0, S)
        for sx in (-1, 1):
            place(objs["lock_gate_tower"], (sx * 37.5, gy, 0.0), 0.0, S)
        place(objs["lock_gate_gallery"], (0.0, gy, 19.0 * S + 0.3 * S), 0.0, S)
    for sx in (-1, 1):                                    # winch wheels on the downstream towers' fronts
        place(objs["lock_winch_wheel"], (sx * 37.5 - sx * 3.6, -40.0 - 7.3, 8.0), -math.pi / 2, S)
    for sx in (-1, 1):                                    # court banners on the downstream towers' outer fronts
        place(objs["vt_court_banner"], (sx * 42.5, -40.0 - 7.7, 31.5), 0.0, 1.0)
    # sluice jets and foam at the downstream gate's foot
    foam = rv.mat_cardfx("vt_foam", "#f2f6f4", alpha=0.95, stretch=(2.0, 6.0), streak=True, strength=1.0)
    spray = rv.mat_cardfx("vt_spray", "#eef3f0", alpha=0.75, stretch=(1.0, 1.0), strength=1.0)
    for k, x in enumerate((-21.6, -10.8, 0.0, 10.8, 21.6)):
        jet("jet%d" % k, foam, (x, -41.3, 3.6), 11.0, 3.6, 3.6).hide_render = False
        for j in range(2):
            card("spray%d_%d" % (k, j), spray, (x + rng.normal(0, 1.5), -52.0 - j * 2.5, -0.6), 7.0 + j * 2, 4.0 + j,
                 face_to=True).hide_render = False
        card("foamring%d" % k, spray, (x, -55.0, 0.05), 13.0, 12.0, horiz=True).hide_render = False
    # ---- the court island: three terraces and the Court Tower (95 m above the water), court banners on masts
    t1 = place(objs["vt_court_terrace_1"], (0.0, 60.0, 3.0))
    place(objs["vt_court_terrace_2"], (0.0, 69.0, 3.0 + 11.0))
    place(objs["vt_court_terrace_3"], (0.0, 78.0, 3.0 + 21.0))
    place(objs["vt_court_tower"], (0.0, 100.0, 3.0 + 30.0))
    for x in (-21.0, -9.0, 9.0, 21.0):                  # four court banners, 16 m, on lacquered masts at T3's lip
        place(objs["vt_court_banner"], (x, 79.5, 33.0 + 18.0), 0.0)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, segments=8, radius1=0.28, radius2=0.2, depth=19.0, cap_ends=True)
        me = bpy.data.meshes.new("mast%d" % int(x))
        bm.to_mesh(me)
        bm.free()
        me.materials.append(vtkit.material("lacquer"))
        o = bpy.data.objects.new("mast%d" % int(x), me)
        bpy.context.scene.collection.objects.link(o)
        o.location = (x, 79.9, 33.0 + 9.5)
        o["render_only"] = True
    # ---- the Lantern Ward (W quay): houses facing the basin (+X), the jade lacquer tower, steps, lamps
    houses = ["vt_quay_house_b", "vt_quay_house_a", "vt_quay_house_a", "vt_quay_house_b", "vt_quay_house_a",
              "vt_quay_house_b", "vt_quay_house_a", "vt_quay_house_b", "vt_quay_house_a"]
    y = -300.0
    hi = 0
    while y < 200:
        nm = houses[hi % len(houses)]
        if -185 < y < -150:                       # the steps' gap
            y = -150
            continue
        if -45 < y < 35:                          # the jade tower and the high bridge's landing
            y = 35
            continue
        d = objs[nm].dimensions
        place(objs[nm], (-115.0 - 6.0 - d.y / 2, y + d.x / 2, 3.0), math.pi / 2)
        place(objs["vt_door_lamp"], (-115.0 - 6.0 + 0.2, y + d.x * 0.85, 5.4), math.pi / 2)
        y += d.x + 1.6
        hi += 1
    place(objs["vt_quay_steps_patched"], (-113.3, -168.0, 0.0), math.pi / 2)
    place(objs["vt_quay_steps"], (-76.7, 20.0, 0.0), -math.pi / 2)
    place(objs["vt_lacquer_tower"], (-135.0, -10.0, 3.0), math.pi / 2)
    place(objs["vt_district_banner_lantern_ward"], (-126.0, -22.0, 3.0), math.pi / 2)
    place(objs["vt_district_banner_lantern_ward"], (-126.0, 2.0, 3.0), math.pi / 2)
    place(objs["vt_notice_board"], (-122.0, -190.0, 3.0), math.pi / 2)
    place(objs["vt_drain_mouth"], (-114.6, -235.0, 0.0), math.pi / 2)
    # the high bridge across the west canal (x -115..-75) at y 70; deck along X
    place(objs["vt_high_bridge"], (-95.0, 70.0, 0.0), 0.0)
    # lantern nets over the west canal and the steps' basin (lit at dusk and night)
    for (x0, y0, x1, y1, z) in ((-121, 42, -95, 70, 20.0), (-95, 70, -121, 98, 20.0), (-95, 70, -75, 44, 20.0),
                                (-121, -136, -121, -150, 9.5), (-121, -186, -121, -214, 9.5),
                                (-121, -120, -104, -95, 9.5)):
        L = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(L / 10))
        for k in range(n):
            t0, t1_ = k / n, (k + 1) / n
            c = place(objs["vt_lantern_net"], (x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0, z),
                      math.atan2(y1 - y0, x1 - x0), 1.0)
            c.scale = (L / n / 10.0, 1.0, 1.0)
    # ---- the grain piers (E): granaries, pier fingers south into the basin, cranes, sacks, junks
    for k, x in enumerate((130.0, 185.0, 240.0)):
        place(objs["vt_granary_hall"], (x, -90.0, 3.0), 0.0)
        place(objs["vt_district_banner_grain_piers"], (x - 21.0, -112.0, 3.0), 0.0)
        for j in range(5):
            nm = "vt_pier_finger_end" if j == 4 else "vt_pier_finger"
            place(objs[nm], (x - 14.0, -150.0 - 20.0 * j, 0.0), -math.pi / 2)
        place(objs["vt_treadwheel_crane"], (x - 14.0, -175.0 - 30.0 * (k % 2), 7.0), math.pi / 2)
        place(objs["vt_sacks_heap"], (x - 14.0, -160.0, 7.0), 0.3)
        place(objs["vt_crates_stack"], (x - 13.0, -200.0, 7.0), 1.0)
        place(objs["vt_jars_cluster"], (x - 15.5, -220.0, 7.0), 0.0)
    place(objs["vt_sacks_heap"], (115.0, -125.0, 3.0), 0.0)
    place(objs["vt_sacks_heap"], (150.0, -125.0, 3.0), 0.6)
    place(objs["vt_notice_board"], (100.0, -118.0, 3.0), 0.2)
    place(objs["vt_lacquer_tower"], (100.0, -55.0, 3.0), 0.0)
    place(objs["vt_district_banner_grain_piers"], (95.0, -64.0, 3.0), 0.0)
    place(objs["vt_junk_sea"], (148.0, -205.0, 0.0), math.pi / 2)
    place(objs["vt_junk_sea"], (202.0, -215.0, 0.0), math.pi / 2 + 0.03)
    place(objs["vt_junk_river"], (-30.0, -160.0, 0.0), 0.35)
    place(objs["vt_junk_river"], (60.0, -300.0, 0.0), -0.2)
    place(objs["vt_junk_river"], (62.0, -175.0, 0.0), 2.75)
    # ---- the Lantern Ward's south point: the steps the vista stands on, a row of houses facing the basin
    place(objs["vt_quay_steps_patched"], (-60.0, -281.7, 0.0), math.pi)
    for k, x in enumerate((-108.0, -95.0, -82.0, -40.0, -27.0)):
        nm = ("vt_quay_house_a", "vt_quay_house_b")[k % 2]
        d = objs[nm].dimensions
        place(objs[nm], (x, -280.0 - 6.0 - d.y / 2, 3.0), math.pi)
        place(objs["vt_door_lamp"], (x + d.x * 0.3, -286.2, 5.4), math.pi)
    place(objs["vt_district_banner_lantern_ward"], (-74.0, -289.0, 3.0), math.pi)
    place(objs["vt_district_banner_lantern_ward"], (-46.0, -289.0, 3.0), math.pi)
    place(objs["vt_notice_board"], (-36.0, -284.5, 3.0), math.pi)
    place(objs["vt_lacquer_tower"], (-16.0, -300.0, 3.0), math.pi)
    for (x0, y0, x1, y1, z) in ((-108, -287, -72, -284, 9.5), (-48, -284, -27, -287, 9.5)):
        L = math.hypot(x1 - x0, y1 - y0)
        c = place(objs["vt_lantern_net"], (x0, y0, z), math.atan2(y1 - y0, x1 - x0), 1.0)
        c.scale = (L / 10.0, 1.0, 1.0)
    for (x, y, yaw) in ((-88.0, -270.0, 0.1), (-30.0, -268.0, -0.1), (-47.0, -236.0, 0.35)):
        place(objs["vt_market_barge"], (x, y, 0.0), yaw)
        place(objs["vt_awning_madder" if x < -50 else "vt_awning_ochre"], (x, y, 0.9), yaw)
    # ---- the city behind the quays
    fill_block(objs, rng, -300, -140, -320, 220, avoid=((-160, -110, -40, 25), (-150, -110, 55, 90)))
    fill_block(objs, rng, -515, -365, -195, 255)
    fill_block(objs, rng, -112, -12, -378, -306)
    fill_block(objs, rng, -55, 295, -615, -425)
    fill_block(objs, rng, 108, 296, -45, 100, avoid=((90, 112, -70, -40),))
    fill_block(objs, rng, 136, 256, 162, 298, avoid=((238, 262, 158, 182),))
    fill_block(objs, rng, -90, -54, 64, 258, trees=0.35, avoid=((-90, -54, 62, 80),))
    fill_block(objs, rng, 54, 90, 58, 258, trees=0.35)
    fill_block(objs, rng, -46, 46, 140, 258, trees=0.4)
    # ---- the archive island (NE): two-age walls on its basin face
    for x in np.arange(135.0, 260.0, 10.0):
        nm = "vt_archive_wall_gauge" if abs(x - 185.0) < 1 else "vt_archive_wall"
        place(objs[nm], (x + 5.0, 150.0, 0.0), 0.0)
    place(objs["vt_district_banner_archive"], (140.0, 158.0, 3.0), 0.0)
    place(objs["vt_lacquer_tower"], (250.0, 170.0, 3.0), 0.0)
    # ---- the Rain Market barge moored off the Lantern Ward, sampans, porters (12 people or fewer)
    barge = place(objs["vt_market_barge"], (-104.0, -95.0, 0.0), math.pi / 2)
    place(objs["vt_awning_madder"], (-104.0, -95.0, 0.9), math.pi / 2)
    place(objs["vt_market_barge"], (-104.0, -118.0, 0.0), math.pi / 2 + 0.05)
    place(objs["vt_awning_ochre"], (-104.0, -118.0, 0.9), math.pi / 2 + 0.05)
    samp = village_piece(vk.sampan, "sampan")
    for (x, y, yaw) in ((-105.0, -150.0, 1.2), (-100.0, -185.0, 2.0), (-60.0, -120.0, 0.4), (10.0, -95.0, -0.3),
                        (-70.0, -248.0, 0.9), (-36.0, -214.0, 2.3), (-58.0, -196.0, 1.4),
                        (70.0, -140.0, 2.6), (-20.0, -230.0, 1.0), (95.0, -190.0, 1.6)):
        place(samp, (x, y, -0.25), yaw)
    por = village_piece(vk.porter, "porter_standing", "stand")
    walk = village_piece(vk.porter, "porter_walking", "walk")
    pole = village_piece(vk.porter, "porter_pole", "walk", pole=True)
    for (src, x, y, z, yaw) in ((por, -64.0, -278.8, 2.4, 0.3), (walk, -45.0, -283.0, 3.0, -1.4),
                                (pole, -123.0, -130.0, 3.0, 3.1), (por, -118.0, -200.0, 3.0, -1.9),
                                (walk, 117.0, -165.0, 7.0, 1.6), (pole, 172.0, -150.0, 7.0, 1.5),
                                (por, 172.0, -185.0, 7.0, 2.4), (walk, -60.0, -40.0, 3.0, 0.4),
                                (por, -88.0, 70.0, 17.6, 1.57), (walk, 100.0, -120.0, 3.0, 0.8)):
        place(src, (x, y, z), yaw)
    # ---- trees, smoke, birds, the rim
    for (x, y, h) in ((-140, -260, 14), (-150, -200, 16), (-145, -120, 13), (-150, 120, 15), (-140, 180, 13),
                      (-70, 250, 15), (70, 250, 16), (-80, 180, 12), (80, 170, 13), (160, 260, 14), (220, 280, 15),
                      (280, -40, 14), (270, 60, 16), (-60, -60, 10), (70, 80, 11)):
        rv.puff_tree("tree%d_%d" % (x, y), (x, y, 3.0), h, h * 0.36, 5, R1["broadleaf"], rng)
    smoke = rv.mat_cardfx("vt_smoke", "#c8c4bc", alpha=0.45, stretch=(1.0, 3.0), streak=True, strength=1.0)
    for (x, y) in ((-128.0, -240.0), (-128.0, 120.0), (240.0, -60.0)):
        card("smoke%d" % x, smoke, (x, y, 10.0), 8.0, 34.0, face_to=True).hide_render = False
    birds(rng, 14, (-30.0, -40.0, 0.0), 120.0, 40.0, 85.0)
    far_karst(rng)
    mist = rv.mat_cardfx("vt_mist", "#e2ecee", alpha=0.6, stretch=(0.6, 1.6), strength=1.0)
    for k, (az, r) in enumerate(((-30, 650), (0, 700), (25, 650), (50, 620), (-55, 640), (75, 700))):
        a = math.radians(az)
        card("mist%d" % k, mist, (r * math.sin(a), 120 + r * math.cos(a), 8.0), 520.0, 70.0, face_to=True).hide_render = False
    for o in bpy.data.objects:
        if o.get("render_only") and not o.get("render_only_src"):
            o.hide_render = False
    cams = {
        "steps": ((-58.0, -286.6, 4.8), (-10.0, 30.0, 40.0), 35.0),
        "overview": ((330.0, -460.0, 190.0), (-20.0, 30.0, 18.0), 32.0),
        "gate": ((52.0, -150.0, 6.0), (-6.0, -40.0, 24.0), 24.0),
    }
    return cams


def light_scene(direction):
    """Sun, sky, ambient, lantern emission and a few lantern lights per direction."""
    world_painted(direction)
    for ob in [o for o in bpy.data.objects if o.type == "LIGHT" and o.get("vt_lamp")]:
        bpy.data.objects.remove(ob)
    if direction == "night":
        sun_for("night")
        emissions(3.5, 12.0)
        set_fog_colour(NIGHT["fog"]["color"], 0.3)
        fog = NIGHT["fog"]["color"]
    else:
        d = PALJ["directions"][DIRS[direction]]
        rv.sun(direction)
        emissions(2.2 if direction == "dusk" else 0.0, 0.0)
        fog = d["fog"]["color"]
        set_fog_colour(fog if direction != "dusk" else "#9a7fa4", {"morning": 1.0, "noon": 1.05, "dusk": 0.7}[direction])
    bpy.context.scene.view_settings.exposure = {"morning": 0.35, "noon": 0.0, "dusk": 0.15, "night": 0.3}[direction]
    fx = {"morning": 0.85, "noon": 1.0, "dusk": 0.5, "night": 0.22}[direction]
    for m in ("vt_foam", "vt_spray", "vt_smoke"):
        mm = bpy.data.materials.get(m)
        if mm:
            for n in mm.node_tree.nodes:
                if n.type == "EMISSION":
                    n.inputs["Strength"].default_value = fx
    for m in ("vt_mist",):
        mm = bpy.data.materials.get(m)
        if mm:
            em = [n for n in mm.node_tree.nodes if n.type == "EMISSION"][0]
            em.inputs["Color"].default_value = lin(fog) + (1,)
            em.inputs["Strength"].default_value = 0.35 if direction == "night" else 1.0
    if direction in ("dusk", "night"):
        warm = "#ffb45a"
        for (x, y, z) in ((-121.0, -160.0, 8.0), (-121.0, -130.0, 8.0), (-121.0, -200.0, 8.0), (-95.0, 70.0, 20.0),
                          (-37.5, -40.0, 33.0), (37.5, -40.0, 33.0), (0.0, 54.0, 18.0), (-104.0, -95.0, 4.0),
                          (-95.0, 20.0, 12.0), (-95.0, -10.0, 10.0)):
            li = bpy.data.lights.new("lamp", "POINT")
            li.energy = 9000.0 if direction == "night" else 4000.0
            li.color = lin(warm)
            li.shadow_soft_size = 1.0
            li.use_shadow = False
            ob = bpy.data.objects.new("lamp", li)
            ob.location = (x, y, z)
            ob["vt_lamp"] = True
            bpy.context.scene.collection.objects.link(ob)
    if direction == "night":
        for y in np.arange(-300.0, 200.0, 24.0):
            li = bpy.data.lights.new("oil", "POINT")
            li.energy = 1800.0
            li.color = lin("#5fa8e8")
            li.shadow_soft_size = 0.5
            li.use_shadow = False
            ob = bpy.data.objects.new("oil", li)
            ob.location = (-120.0, y, 5.6)
            ob["vt_lamp"] = True
            bpy.context.scene.collection.objects.link(ob)


DEADLINE = [0.0]


def late():
    return DEADLINE[0] and time.time() > DEADLINE[0]


def diorama(out, dirs, cams_sel, fast):
    rng = np.random.default_rng(11)
    cams = diorama_scene(rng)
    eevee_reflections(True)
    sc = bpy.context.scene
    for dn in dirs:
        light_scene(dn)
        for cn in cams_sel:
            if late():
                print("VT_RENDER skipped (deadline) diorama", cn, dn)
                continue
            loc, tgt, lens = cams[cn]
            cam = rv.camera(loc, tgt, lens=lens)
            face_camera(cam)
            bpy.context.view_layer.update()
            sc.render.filepath = os.path.join(out, "diorama_%s_%s.png" % (cn, dn))
            bpy.ops.render.render(write_still=True)
            print("VT_RENDER diorama", cn, dn)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--pages", default=",".join(list(PAGES) + ["diorama"]))
    ap.add_argument("--dirs", default="morning,noon,dusk,night")
    ap.add_argument("--cams", default="steps,overview,gate")
    ap.add_argument("--fast", action="store_true")
    ap.add_argument("--build", default="", help="first build the kit into this folder (vt_kit.run), in this session")
    ap.add_argument("--blend", default="", help="with --build: also save the built kit .blend here")
    ap.add_argument("--deadline", type=float, default=0.0, help="seconds: start no new render after this")
    a = ap.parse_args(argv)
    t0 = time.time()
    if a.build:
        import vt_kit
        vt_kit.run(a.build, a.blend)
    out = os.path.join(a.out, "raw")
    os.makedirs(out, exist_ok=True)
    rv.setup_render(a.fast)
    bpy.context.scene.render.film_transparent = False
    DEADLINE[0] = t0 + a.deadline if a.deadline else 0.0
    for p in a.pages.split(","):
        if late():
            print("VT_RENDER skipped (deadline)", p)
            continue
        if p in PAGES:
            eevee_reflections(False)
            lineup(p, out=out, **PAGES[p])
            print("VT_RENDER page", p, round(time.time() - t0))
        elif p == "diorama":
            diorama(out, a.dirs.split(","), a.cams.split(","), a.fast)
    print("VT_RENDER DONE", round(time.time() - t0))


if __name__ == "__main__":
    main()
