"""Thủy Vân Blender helpers (look builder PAINT): mesh accumulation in the frontier tree format, painted materials,
and the style guide's lineup lighting (section 11: Eevee, a bright game scene, sun 40 deg from the front-left, a
sky-coloured world light, soft shadows, AgX). Run inside Blender 5.2 (background), only through the shared lock:

    zsh <plan>/bin/blender_run.sh -b --factory-startup -P tools/thuyvan_art/blender/<script>.py -- <args>

Coordinates: Blender Z-up; the glTF export writes Godot's Y-up (Blender -Y = Godot +Z).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PAINT = os.path.join(ROOT, "assets", "thuyvan", "paint")
LOOK = os.environ.get(
    "TV_LOOK_DIR",
    "/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/d8726f05-a14a-44ac-97c9-351a2e11c5c5/scratchpad/"
    "thuyvan_plan/look/PAINT")
PAL = json.load(open(os.path.join(ROOT, "docs", "thuyvan", "plan", "look", "palettes.json")))
UP = Vector((0, 0, 1))


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {}
    for s in a:
        if "=" in s:
            k, v = s.split("=", 1)
            out[k.lstrip("-")] = v
        else:
            out[s.lstrip("-")] = "1"
    return out


def hex_lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


class MeshData:
    """Vertices with normal, UV, UV2 and COLOR (the frontier tree format: COLOR r = AO, g = outer-crown factor,
    b = per-card random, a = 1 foliage / 0 bark; UV2 x = metres from the limb's attachment, y = phase)."""

    def __init__(self):
        self.co, self.n, self.uv, self.uv2, self.col, self.tris = [], [], [], [], [], []

    def add(self, co, n, uv, uv2, col):
        self.co.append(Vector(co))
        self.n.append(Vector(n).normalized())
        self.uv.append(uv)
        self.uv2.append(uv2)
        self.col.append(col)
        return len(self.co) - 1

    def ntris(self):
        return len(self.tris)

    def to_object(self, name, mat=None, custom_normals=True):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in self.co], [], [tuple(t) for t in self.tris])
        uv = me.uv_layers.new(name="UVMap")
        uv2 = me.uv_layers.new(name="UV2")
        ca = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
        for poly in me.polygons:
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                uv.data[li].uv = self.uv[vi]
                uv2.data[li].uv = self.uv2[vi]
                ca.data[li].color = self.col[vi]
        me.color_attributes.active_color = ca
        me.update()
        if custom_normals:
            me.normals_split_custom_set_from_vertices([tuple(n) for n in self.n])
        else:
            me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        if mat is not None:
            me.materials.append(mat)
        return ob


def tube(md, pts, radii, sides, bark_tile_m=2.0, around_m=1.0, ao=(0.55, 0.95), attach0=0.0, phase=0.0, rand=0.5,
         wind=True):
    """A swept bark tube along pts with radii; bark UVs tile around (around_m per U) and along (bark_tile_m per V)."""
    rows = []
    length = 0.0
    prev = None
    for i, p in enumerate(pts):
        p = Vector(p)
        if i < len(pts) - 1:
            d = (Vector(pts[i + 1]) - p).normalized()
        else:
            d = (p - Vector(pts[i - 1])).normalized()
        if prev is not None:
            length += (p - prev).length
        prev = p
        side = d.cross(Vector((0.31, 0.27, 0.91)) if abs(d.z) > 0.9 else UP).normalized()
        if side.length < 1e-6:
            side = Vector((1, 0, 0))
        bi = d.cross(side).normalized()
        r = radii[i]
        reps = max(1, round(2 * math.pi * r / around_m))
        row = []
        t = i / (len(pts) - 1)
        for k in range(sides + 1):
            a = 2 * math.pi * k / sides
            nrm = side * math.cos(a) + bi * math.sin(a)
            v = p + nrm * r
            aoc = ao[0] + (ao[1] - ao[0]) * t
            row.append(md.add(v, nrm, (reps * k / sides, length / bark_tile_m),
                              ((attach0 + length) if wind else 0.0, phase), (aoc, 0.0, rand, 0.0)))
        rows.append(row)
    for a_, b_ in zip(rows[:-1], rows[1:]):
        for k in range(sides):
            md.tris.append((a_[k], a_[k + 1], b_[k + 1]))
            md.tris.append((a_[k], b_[k + 1], b_[k]))


def card(md, tiles, tile, origin, right, up, size_w, size_h, normal_fn, ao, outer, rand, attach, phase,
         anchor="center", hull=True):
    """A cutout card (hexagonal hull from the tile json: 4 triangles) in the plane (right, up)."""
    t = tiles[tile]
    ux, uy, uw, uh = t["uv"]
    inset = 1.5 / 2048.0
    corners = t.get("hull") if hull else [[0, 0], [1, 0], [1, 1], [0, 1]]
    ids = []
    for cu, cv in corners:
        dy = (0.5 - cv) if anchor == "center" else (1.0 - cv)
        p = Vector(origin) + right * ((cu - 0.5) * size_w) + up * (dy * size_h)
        n = normal_fn(p)
        u = ux + inset + (uw - 2 * inset) * cu
        v = 1.0 - (uy + inset + (uh - 2 * inset) * cv)
        a_ = ao(p) if callable(ao) else ao
        ids.append(md.add(p, n, (u, v), (attach, phase), (a_, outer, rand, 1.0)))
    for i in range(1, len(ids) - 1):
        md.tris.append((ids[0], ids[i], ids[i + 1]))


def grid_card(md, tiles, tile, pos_fn, nu, nv, normal_fn, ao, rand, phase, attach_fn, uv_map=None):
    """A bent card: a (nu x nv) vertex grid over the tile, positions from pos_fn(cu, cv) (cv 0 top of the tile)."""
    t = tiles[tile]
    ux, uy, uw, uh = t["uv"]
    inset = 1.5 / 2048.0
    ids = []
    for j in range(nv):
        row = []
        for i in range(nu):
            cu, cv = i / (nu - 1), j / (nv - 1)
            p = pos_fn(cu, cv)
            u = ux + inset + (uw - 2 * inset) * cu
            v = 1.0 - (uy + inset + (uh - 2 * inset) * cv)
            a_ = ao(p) if callable(ao) else ao
            row.append(md.add(p, normal_fn(p, cu, cv), (u, v), (attach_fn(cu, cv), phase), (a_, 0.5, rand, 1.0)))
        ids.append(row)
    for j in range(nv - 1):
        for i in range(nu - 1):
            a, b, c, d = ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]
            md.tris.append((a, b, c))
            md.tris.append((a, c, d))


# ---------------------------------------------------------------- materials

def image(path, non_color=False):
    name = os.path.basename(path)
    im = bpy.data.images.get(name)
    if im is None:
        im = bpy.data.images.load(path)
        if non_color:
            im.colorspace_settings.name = "Non-Color"
    return im


def foliage_material(name, atlas_path, bark_path, alpha_clip=0.5, bark_scale=(1.0, 1.0)):
    """Preview material in the Godot tree shader's logic: COLOR.a picks foliage (atlas, alpha-scissor) or bark;
    albedo x COLOR.r (painted AO). Specular low, rough (style guide 5.2)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    bsdf = N["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.92
    try:
        bsdf.inputs["Specular IOR Level"].default_value = 0.15
    except KeyError:
        pass
    attr = N.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    sep = N.new("ShaderNodeSeparateColor")
    L.new(attr.outputs["Color"], sep.inputs["Color"])
    uvn = N.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    leaf = N.new("ShaderNodeTexImage")
    leaf.image = image(atlas_path)
    L.new(uvn.outputs["UV"], leaf.inputs["Vector"])
    bark = N.new("ShaderNodeTexImage")
    bark.image = image(bark_path)
    L.new(uvn.outputs["UV"], bark.inputs["Vector"])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L.new(attr.outputs["Alpha"], mix.inputs["Factor"])
    L.new(bark.outputs["Color"], mix.inputs["A"])
    L.new(leaf.outputs["Color"], mix.inputs["B"])
    ao = N.new("ShaderNodeMix")
    ao.data_type = "RGBA"
    ao.blend_type = "MULTIPLY"
    ao.inputs["Factor"].default_value = 1.0
    L.new(mix.outputs["Result"], ao.inputs["A"])
    gray = N.new("ShaderNodeCombineColor")
    L.new(sep.outputs["Red"], gray.inputs["Red"])
    L.new(sep.outputs["Red"], gray.inputs["Green"])
    L.new(sep.outputs["Red"], gray.inputs["Blue"])
    L.new(gray.outputs["Color"], ao.inputs["B"])
    L.new(ao.outputs["Result"], bsdf.inputs["Base Color"])
    # alpha: foliage -> step(atlas alpha, 0.5); bark -> 1
    step = N.new("ShaderNodeMath")
    step.operation = "GREATER_THAN"
    step.inputs[1].default_value = alpha_clip
    L.new(leaf.outputs["Alpha"], step.inputs[0])
    am = N.new("ShaderNodeMix")
    am.data_type = "FLOAT"
    L.new(attr.outputs["Alpha"], am.inputs["Factor"])
    am.inputs["A"].default_value = 1.0
    L.new(step.outputs["Value"], am.inputs["B"])
    L.new(am.outputs["Result"], bsdf.inputs["Alpha"])
    try:
        m.surface_render_method = "DITHERED"
    except AttributeError:
        m.blend_method = "CLIP"
    m.use_backface_culling = False
    return m


def image_material(name, path, scale=1.0, box=False, roughness=0.92, tint=None, alpha=False, emission=0.0,
                   uv=False, macro=0.0, anti_tile=False):
    """A painted-texture material: object-space box projection (triplanar-like) at `scale` metres per tile, or the
    mesh's UVs."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    bsdf = N["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    try:
        bsdf.inputs["Specular IOR Level"].default_value = 0.15
    except KeyError:
        pass
    tex = N.new("ShaderNodeTexImage")
    tex.image = image(path)
    if not uv:
        tc = N.new("ShaderNodeTexCoord")
        mp = N.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1.0 / scale, 1.0 / scale, 1.0 / scale)
        L.new(tc.outputs["Generated" if False else "Object"], mp.inputs["Vector"])
        L.new(mp.outputs["Vector"], tex.inputs["Vector"])
        if box:
            tex.projection = "BOX"
            tex.projection_blend = 0.25
    col = tex.outputs["Color"]
    if anti_tile and not uv:
        # the terrain shader's anti-tiling: a second fetch at 2.7 x the tile, rotated 37 deg, chosen by macro noise
        tc2 = N.new("ShaderNodeTexCoord")
        mp2 = N.new("ShaderNodeMapping")
        mp2.inputs["Scale"].default_value = (1.0 / (scale * 2.7),) * 3
        mp2.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(37.0))
        mp2.inputs["Location"].default_value = (0.31, 0.17, 0.0)
        L.new(tc2.outputs["Object"], mp2.inputs["Vector"])
        tex2 = N.new("ShaderNodeTexImage")
        tex2.image = tex.image
        L.new(mp2.outputs["Vector"], tex2.inputs["Vector"])
        nz = N.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 0.035
        nz.inputs["Detail"].default_value = 1.0
        L.new(tc2.outputs["Object"], nz.inputs["Vector"])
        mr = N.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.44
        mr.inputs["From Max"].default_value = 0.56
        L.new(nz.outputs["Fac"], mr.inputs["Value"])
        mx0 = N.new("ShaderNodeMix")
        mx0.data_type = "RGBA"
        L.new(mr.outputs["Result"], mx0.inputs["Factor"])
        L.new(col, mx0.inputs["A"])
        L.new(tex2.outputs["Color"], mx0.inputs["B"])
        col = mx0.outputs["Result"]
    if macro:
        # macro value variation (the terrain shader's +-12 % over 60-250 m)
        tc3 = N.new("ShaderNodeTexCoord")
        nz2 = N.new("ShaderNodeTexNoise")
        nz2.inputs["Scale"].default_value = 0.012
        nz2.inputs["Detail"].default_value = 2.0
        L.new(tc3.outputs["Object"], nz2.inputs["Vector"])
        mr2 = N.new("ShaderNodeMapRange")
        mr2.inputs["To Min"].default_value = 1.0 - macro * 2
        mr2.inputs["To Max"].default_value = 1.0 + macro * 2
        mr2.inputs["From Min"].default_value = 0.25
        mr2.inputs["From Max"].default_value = 0.75
        L.new(nz2.outputs["Fac"], mr2.inputs["Value"])
        mm = N.new("ShaderNodeVectorMath")
        mm.operation = "SCALE"
        L.new(col, mm.inputs[0])
        L.new(mr2.outputs["Result"], mm.inputs["Scale"])
        col = mm.outputs["Vector"]
    if tint is not None:
        mx = N.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        mx.blend_type = "MULTIPLY"
        mx.inputs["Factor"].default_value = 1.0
        L.new(col, mx.inputs["A"])
        mx.inputs["B"].default_value = tuple(tint) + (1.0,)
        col = mx.outputs["Result"]
    L.new(col, bsdf.inputs["Base Color"])
    if alpha:
        L.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            m.blend_method = "BLEND"
    if emission:
        L.new(col, bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    return m


def flat_material(name, rgb_lin, roughness=0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = tuple(rgb_lin) + (1.0,)
    b.inputs["Roughness"].default_value = roughness
    return m


# ---------------------------------------------------------------- scene, light, camera, render

def lineup_scene(res=(1920, 1080), samples=48):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    try:
        sc.eevee.taa_render_samples = samples
    except AttributeError:
        pass
    for attr, val in (("use_shadows", True), ("use_raytracing", False)):
        try:
            setattr(sc.eevee, attr, val)
        except AttributeError:
            pass
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Base Contrast"
    except TypeError:
        pass
    sc.view_settings.exposure = 0.0
    return sc


def world_color(rgb_lin, strength=0.6):
    w = bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = tuple(rgb_lin) + (1.0,)
    bg.inputs["Strength"].default_value = strength
    return w


def world_panorama(path, strength=1.0, light_strength=None, light_rgb=None):
    """The painted sky as the world: shown to the camera as painted; lighting the scene with a flat colour
    (`light_rgb`, the direction's ambient) so the painted clouds do not mottle the light."""
    w = bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    N, L = w.node_tree.nodes, w.node_tree.links
    bg = N["Background"]
    tc = N.new("ShaderNodeTexCoord")
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(90.0))  # north (+Y) at u = 0.5
    env = N.new("ShaderNodeTexEnvironment")
    env.image = image(path)
    L.new(tc.outputs["Generated"], mp.inputs["Vector"])
    L.new(mp.outputs["Vector"], env.inputs["Vector"])
    L.new(env.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    if light_rgb is not None:
        lp = N.new("ShaderNodeLightPath")
        bg2 = N.new("ShaderNodeBackground")
        bg2.inputs["Color"].default_value = tuple(light_rgb) + (1.0,)
        bg2.inputs["Strength"].default_value = light_strength if light_strength is not None else strength
        mx = N.new("ShaderNodeMixShader")
        out = N["World Output"]
        L.new(lp.outputs["Is Camera Ray"], mx.inputs["Fac"])
        L.new(bg2.outputs["Background"], mx.inputs[1])
        L.new(bg.outputs["Background"], mx.inputs[2])
        L.new(mx.outputs["Shader"], out.inputs["Surface"])
    return w


def sun(azimuth_deg, elevation_deg, rgb_lin=(1.0, 0.95, 0.88), strength=4.0, angle_deg=2.0):
    """A sun from compass azimuth (clockwise from north = +Y) and elevation."""
    ld = bpy.data.lights.new("Sun", "SUN")
    ld.energy = strength
    ld.color = rgb_lin
    ld.angle = math.radians(angle_deg)
    ob = bpy.data.objects.new("Sun", ld)
    bpy.context.scene.collection.objects.link(ob)
    a, e = math.radians(azimuth_deg), math.radians(elevation_deg)
    to_sun = Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)))
    ob.rotation_euler = (-to_sun).to_track_quat("-Z", "Y").to_euler()
    return ob


def camera(loc, look_at, lens=50.0, ortho=None):
    cd = bpy.data.cameras.new("Cam")
    cd.lens = lens
    cd.clip_end = 20000.0
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    ob = bpy.data.objects.new("Cam", cd)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(look_at) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob
    return ob


def render(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path, flush=True)


def figure(loc, name="Figure", mat=None):
    """A 1.75 m human-height marker: a porter in a conical hat (tapered body, legs, arms, head, hat) in one dark
    neutral, so it reads as scale, never as a character."""
    import bmesh
    bm = bmesh.new()
    x, y, z = loc

    def cone(cx, cy, z0, z1, r0, r1, seg=10):
        m = Matrix.Translation((cx, cy, (z0 + z1) / 2))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r0, radius2=r1, depth=z1 - z0, matrix=m)

    cone(x - 0.09, y, 0.0, 0.86, 0.06, 0.085)
    cone(x + 0.09, y, 0.0, 0.86, 0.06, 0.085)
    cone(x, y, 0.82, 1.42, 0.17, 0.2, 12)
    cone(x - 0.25, y, 0.88, 1.40, 0.04, 0.055)
    cone(x + 0.25, y, 0.88, 1.40, 0.04, 0.055)
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.11,
                              matrix=Matrix.Translation((x, y, 1.53)))
    cone(x, y, 1.58, 1.75, 0.3, 0.0, 16)  # the conical hat (non la), to 1.75 m
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat or flat_material("figure", hex_lin("#3a3a40")))
    return ob


def export_glb(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_materials="NONE",
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_normals=True,
                              export_texcoords=True, export_tangents=False, export_yup=True, export_apply=False)
    print("exported", os.path.relpath(path, ROOT), flush=True)


def screen_xy(cam_ob, p):
    from bpy_extras.object_utils import world_to_camera_view
    sc = bpy.context.scene
    c = world_to_camera_view(sc, cam_ob, Vector(p))
    return c.x * sc.render.resolution_x, (1 - c.y) * sc.render.resolution_y
