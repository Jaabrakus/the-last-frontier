"""PAINT's look-test diorama: every painted surface of R1 together, in the three directions, so the owner judges the
paint in context (not a bare height-field: painted ground, rock, water, falls, mist, trees and sky).

A small gorge in the spirit of the Đá Trắng reach (a stand-in landform, not the T4 bake; the vista builder places
the real layout): a near plateau with a worn path to the gorge lip, a white-stone river under a jade surface, a
far cliff wall with a waterfall, terraced rice on a rounded hill, a white limestone needle in the river, leaning karst
towers with pine crowns behind, karst ranks fading into the painted sky, mist bands at fixed heights.

    zsh <plan>/bin/blender_run.sh -b --factory-startup -P tools/thuyvan_art/blender/render_diorama.py -- \
        [dirs=jade_mist_morning,bright_saturated_noon,golden_lantern_dusk] [res=1920x1080] [samples=64]

Writes look/PAINT/diorama/diorama_<direction>.png (raw Eevee, AgX) and, after the Python grade step
(tools/thuyvan_art/paint/grade_renders.py), diorama_<direction>_graded.png through that direction's LUT.
Every texture is ours (assets/thuyvan/paint, look/PAINT/slices); the karst towers here are simple painted stand-ins
for the ROCK builder's meshes.
"""
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvb  # noqa: E402
import build_foliage as bf  # noqa: E402

A = tvb.args()
SL = os.path.join(tvb.LOOK, "slices")
P = tvb.PAINT
SLICES = ["00_grass", "01_terrace_rice", "02_forest_floor", "03_dirt_path", "04_laterite", "05_paddy_mud",
          "06_karst_rock", "07_white_stone", "08_moss_fern", "09_river_bank", "10_cliff_face", "11_meadow"]
WATER_Z = 100.0
FOG = {}  # filled per direction: colour, density, height fog


# ---------------------------------------------------------------- the landform

def fbm(x, y, seed, octaves=4, scale=60.0):
    rng = np.random.default_rng(seed)
    out = np.zeros_like(x)
    amp, s = 1.0, scale
    for o in range(octaves):
        ph = rng.uniform(0, 100, 4)
        out += amp * (np.sin(x / s + ph[0]) * np.cos(y / s * 1.3 + ph[1]) +
                      0.5 * np.sin((x + y) / (s * 0.7) + ph[2]) * np.cos((x - y) / (s * 1.1) + ph[3]))
        amp *= 0.5
        s *= 0.5
    return out


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def river_y(x):
    return 42.0 + 9.0 * np.sin(x / 70.0) + 4.0 * np.sin(x / 23.0 + 1.0)


def height(x, y):
    x = np.asarray(x, np.float64)
    y = np.asarray(y, np.float64)
    ry = river_y(x)
    d = y - ry  # metres north of the river's middle
    n1 = fbm(x, y, 3, 4, 50.0)
    # near (south) plateau and its cliff down to the river
    south = 158.0 + 3.0 * n1 + 0.02 * (-y)
    s_cliff = smoothstep(-34.0, -14.0, d)  # 0 on the plateau, 1 at the water's edge
    h = south * (1 - s_cliff) + (WATER_Z + 1.5) * s_cliff
    # the river bed
    bed = WATER_Z - 2.6 * np.exp(-(d / 9.0) ** 2) + 0.6 * fbm(x, y, 5, 2, 8.0)
    h = np.where(np.abs(d) < 15, np.minimum(h, bed + smoothstep(9.0, 15.0, np.abs(d)) * 3.0), h)
    # far (north) wall up to the terrace foot, then the terraced hill
    n_wall = smoothstep(14.0, 34.0, d)
    foot = 148.0 + 4.0 * n1
    hill_c = Vector((40.0, 190.0))
    rr = np.sqrt(((x - hill_c.x) / 1.3) ** 2 + (y - hill_c.y) ** 2)
    hill = 150.0 + 52.0 * np.clip(1.0 - rr / 160.0, 0, 1) ** 1.15 + 1.5 * n1
    steps = 3.0
    terr = np.floor(hill / steps) * steps + steps * smoothstep(0.8, 1.0, (hill / steps) % 1.0)
    in_terr = smoothstep(150.0, 130.0, rr) * smoothstep(60.0, 85.0, d)
    upper = np.maximum(foot, hill * (1 - in_terr) + terr * in_terr)
    beyond = 150.0 + np.clip(y - 80.0, 0, None) * 0.18 + 6.0 * fbm(x, y, 7, 3, 70.0)
    upper = np.maximum(upper, beyond * smoothstep(250.0, 120.0, rr) * 0 + np.where(rr > 150, beyond, upper))
    h = np.where(d > 14.0, h * (1 - n_wall) + upper * n_wall, h)
    return h, d, in_terr, rr


def build_terrain():
    n = 420
    ext = 360.0
    xs = np.linspace(-ext, ext, n)
    ys = np.linspace(-ext * 0.35, ext * 1.4, n)
    X, Y = np.meshgrid(xs, ys)
    H, D, T, RR = height(X, Y)
    # normals from the grid
    gy, gx = np.gradient(H, ys, xs)
    nz = 1.0 / np.sqrt(1 + gx * gx + gy * gy)
    slope = np.degrees(np.arccos(np.clip(nz, 0, 1)))
    nzz = fbm(X, Y, 11, 3, 30.0)
    w = np.zeros((n, n, 12), np.float32)
    steep = smoothstep(36.0, 46.0, slope) * (1 - T * 0.9)
    mid = smoothstep(20.0, 30.0, slope) * (1 - steep)
    flat = 1 - steep - mid
    near_w = np.abs(D) < 22
    bank = smoothstep(WATER_Z + 3.5, WATER_Z + 0.6, H) * (1 - steep)
    bed = smoothstep(WATER_Z + 0.4, WATER_Z - 0.6, H)
    grassy = flat * (1 - bank) * (1 - bed)
    meadow = smoothstep(-0.2, 0.4, nzz)
    # the worn path from the near plateau to the gorge lip
    path_y = river_y(X) - 52.0 + 6.0 * np.sin(X / 25.0)  # the rim path along the gorge
    path = smoothstep(2.6, 1.2, np.abs(Y - path_y)) * (Y < river_y(X) - 30)
    # terraces: flats are rice, risers laterite
    tf = T * smoothstep(22.0, 12.0, slope)
    tr = T * smoothstep(18.0, 28.0, slope) * (1 - steep)
    # forest patches beyond the terraces and at the gorge rim
    forest = smoothstep(0.35, 0.6, fbm(X, Y, 13, 2, 40.0)) * (RR > 150)
    # moss under the fall
    fall_m = sum(np.exp(-(((X - fx) / (w_ * 1.5)) ** 2 + ((Y - (river_y(fx) + 20)) / 16.0) ** 2))
                 for fx, w_ in FALLS)
    w[..., 0] = grassy * (1 - meadow) * (1 - T) * (1 - path) * (1 - forest)
    w[..., 11] = grassy * meadow * (1 - T) * (1 - path) * (1 - forest)
    w[..., 1] = tf * (1 - path)
    w[..., 4] = tr * 0.45 + mid * 0.2 * (Y > river_y(X)) * (1 - T)
    w[..., 0] += tr * 0.6
    w[..., 3] = path * (1 - steep) * 1.4
    w[..., 2] = grassy * forest * (1 - T)
    w[..., 6] = mid * (1 - T) * 0.9 + flat * 0.25 * smoothstep(0.55, 0.75, nzz) * (1 - T) * (1 - bank)
    w[..., 10] = steep * 1.3
    w[..., 9] = bank * (1 - bed) * 1.2
    w[..., 7] = bed * 1.5 + bank * 0.3 * smoothstep(0.0, 0.5, nzz)
    w[..., 8] = fall_m * (1 - steep * 0.5) * 1.6
    # every third 7 m stratum of the walls is a ledge with green on it (style guide 4: gorge walls)
    band = (H / 7.0) % 3.0
    ledge = smoothstep(0.0, 0.2, band) * smoothstep(1.3, 0.9, band) * smoothstep(-0.35, 0.2, nzz)
    w[..., 8] += steep * ledge * 2.6
    w = w ** 2.2
    w /= np.maximum(w.sum(-1, keepdims=True), 1e-4)
    if A.get("debug_splat"):  # a top view of the dominant slice (look/PAINT/diorama/splat_debug.png)
        pal = np.array([[0.3, 0.7, 0.2], [0.8, 0.9, 0.2], [0.2, 0.3, 0.1], [0.7, 0.5, 0.3], [0.8, 0.3, 0.1],
                        [0.4, 0.35, 0.2], [0.6, 0.6, 0.6], [1, 1, 1], [0.1, 0.5, 0.2], [0.5, 0.4, 0.3],
                        [0.4, 0.4, 0.5], [0.6, 0.85, 0.3]], np.float32)
        img = pal[w.argmax(-1)]
        im = bpy.data.images.new("splat", n, n)
        im.pixels.foreach_set(np.concatenate([img, np.ones((n, n, 1), np.float32)], -1).ravel())
        im.filepath_raw = os.path.join(tvb.LOOK, "diorama", "splat_debug.png")
        im.file_format = "PNG"
        im.save()
    # the mesh
    verts = np.stack([X, Y, H], -1).reshape(-1, 3)
    faces = []
    idx = np.arange(n * n).reshape(n, n)
    a = idx[:-1, :-1].ravel()
    b = idx[:-1, 1:].ravel()
    c = idx[1:, 1:].ravel()
    d = idx[1:, :-1].ravel()
    quads = np.stack([a, b, c, d], -1)
    me = bpy.data.meshes.new("terrain")
    me.vertices.add(len(verts))
    me.vertices.foreach_set("co", verts.astype(np.float32).ravel())
    nq = len(quads)
    me.loops.add(nq * 4)
    me.loops.foreach_set("vertex_index", quads.astype(np.int32).ravel())
    me.polygons.add(nq)
    me.polygons.foreach_set("loop_start", (np.arange(nq) * 4).astype(np.int32))
    me.polygons.foreach_set("loop_total", np.full(nq, 4, np.int32))
    me.update(calc_edges=True)
    me.validate()
    for k in range(3):
        at = me.attributes.new("w%d" % k, "FLOAT_COLOR", "POINT")
        at.data.foreach_set("color", w[..., k * 4:(k + 1) * 4].reshape(-1).astype(np.float32))
    # painted vertex AO: the gorge darkens and cools toward the water; the walls a little
    deep = smoothstep(152.0, 101.0, H) * (np.abs(D) < 40)
    ao = np.clip(1.0 - 0.45 * deep - 0.2 * smoothstep(36.0, 50.0, slope), 0.45, 1.0)
    aoc = np.stack([ao * 0.97, ao, ao * (1.0 + 0.06 * deep), np.ones_like(ao)], -1)
    at = me.attributes.new("ao", "FLOAT_COLOR", "POINT")
    at.data.foreach_set("color", np.clip(aoc, 0, 1).reshape(-1).astype(np.float32))
    me.polygons.foreach_set("use_smooth", np.ones(nq, bool))
    ob = bpy.data.objects.new("terrain", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(terrain_material())
    return ob, (X, Y, H, w, slope, D)


def tex_node(N, path, scale, box=False):
    tc = N.new("ShaderNodeTexCoord")
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / scale,) * 3
    tex = N.new("ShaderNodeTexImage")
    tex.image = tvb.image(path)
    N.id_data.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    N.id_data.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
    if box:
        tex.projection = "BOX"
        tex.projection_blend = 0.3
    return tex


def fog_wrap(m, shader_out, alpha_out=None, emissive=False):
    """Aerial perspective and height fog inside the material: out = mix(surface, fog colour, f), f = 1 - exp(-d k)
    with k raised below the height-fog level; transparency kept outside the fog mix."""
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    out = N.get("Material Output")
    cam = N.new("ShaderNodeCameraData")
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Position"], sep.inputs["Vector"])
    # k = density * (1 + hf * smoothstep(h0, h0 - 30, z))
    hz = N.new("ShaderNodeMapRange")
    hz.inputs["From Min"].default_value = FOG["height"]
    hz.inputs["From Max"].default_value = FOG["height"] - 30.0
    hz.inputs["To Min"].default_value = 1.0
    hz.inputs["To Max"].default_value = 1.0 + FOG["height_boost"]
    L.new(sep.outputs["Z"], hz.inputs["Value"])
    k = N.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.inputs[1].default_value = FOG["density"]
    L.new(hz.outputs["Result"], k.inputs[0])
    dk = N.new("ShaderNodeMath")
    dk.operation = "MULTIPLY"
    L.new(cam.outputs["View Distance"], dk.inputs[0])
    L.new(k.outputs["Value"], dk.inputs[1])
    ex = N.new("ShaderNodeMath")
    ex.operation = "EXPONENT"
    neg = N.new("ShaderNodeMath")
    neg.operation = "MULTIPLY"
    neg.inputs[1].default_value = -1.0
    L.new(dk.outputs["Value"], neg.inputs[0])
    L.new(neg.outputs["Value"], ex.inputs[0])
    f = N.new("ShaderNodeMath")
    f.operation = "SUBTRACT"
    f.inputs[0].default_value = 1.0
    L.new(ex.outputs["Value"], f.inputs[1])
    fmax = N.new("ShaderNodeMath")
    fmax.operation = "MINIMUM"
    fmax.inputs[1].default_value = FOG["max"]
    L.new(f.outputs["Value"], fmax.inputs[0])
    em = N.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = tuple(FOG["color"]) + (1.0,)
    em.inputs["Strength"].default_value = FOG["strength"]
    mx = N.new("ShaderNodeMixShader")
    L.new(fmax.outputs["Value"], mx.inputs["Fac"])
    L.new(shader_out, mx.inputs[1])
    L.new(em.outputs["Emission"], mx.inputs[2])
    final = mx.outputs["Shader"]
    if alpha_out is not None:
        tr = N.new("ShaderNodeBsdfTransparent")
        mx2 = N.new("ShaderNodeMixShader")
        L.new(alpha_out, mx2.inputs["Fac"])
        L.new(tr.outputs["BSDF"], mx2.inputs[1])
        L.new(final, mx2.inputs[2])
        final = mx2.outputs["Shader"]
    L.new(final, out.inputs["Surface"])


def principled(m):
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.92
    try:
        b.inputs["Specular IOR Level"].default_value = 0.15
    except KeyError:
        pass
    return b


def terrain_material():
    m = bpy.data.materials.new("tv_terrain")
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    b = principled(m)
    weights = []
    for k in range(3):
        ca = N.new("ShaderNodeAttribute")
        ca.attribute_name = "w%d" % k
        sp = N.new("ShaderNodeSeparateColor")
        L.new(ca.outputs["Color"], sp.inputs["Color"])
        weights += [sp.outputs["Red"], sp.outputs["Green"], sp.outputs["Blue"], ca.outputs["Alpha"]]
    acc = None
    for i, name in enumerate(SLICES):
        scale = 16.0 if i == 10 else 8.0
        tex = tex_node(N, os.path.join(SL, name + ".png"), scale, box=(i in (10, 6, 4)))
        col = tex.outputs["Color"]
        if i in (0, 11, 1, 3):
            # the terrain shader's anti-tiling: a second fetch at 2.7 x, rotated 37 deg, chosen by macro noise
            tc2 = N.new("ShaderNodeTexCoord")
            mp2 = N.new("ShaderNodeMapping")
            mp2.inputs["Scale"].default_value = (1 / (scale * 2.7),) * 3
            mp2.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(37.0))
            L.new(tc2.outputs["Object"], mp2.inputs["Vector"])
            t2 = N.new("ShaderNodeTexImage")
            t2.image = tex.image
            L.new(mp2.outputs["Vector"], t2.inputs["Vector"])
            nz0 = N.new("ShaderNodeTexNoise")
            nz0.inputs["Scale"].default_value = 0.04
            L.new(tc2.outputs["Object"], nz0.inputs["Vector"])
            mr0 = N.new("ShaderNodeMapRange")
            mr0.inputs["From Min"].default_value = 0.45
            mr0.inputs["From Max"].default_value = 0.55
            L.new(nz0.outputs["Fac"], mr0.inputs["Value"])
            mx0 = N.new("ShaderNodeMix")
            mx0.data_type = "RGBA"
            L.new(mr0.outputs["Result"], mx0.inputs["Factor"])
            L.new(col, mx0.inputs["A"])
            L.new(t2.outputs["Color"], mx0.inputs["B"])
            col = mx0.outputs["Result"]
        sc = N.new("ShaderNodeVectorMath")
        sc.operation = "SCALE"
        L.new(col, sc.inputs[0])
        L.new(weights[i], sc.inputs["Scale"])
        if acc is None:
            acc = sc.outputs["Vector"]
        else:
            ad = N.new("ShaderNodeVectorMath")
            ad.operation = "ADD"
            L.new(acc, ad.inputs[0])
            L.new(sc.outputs["Vector"], ad.inputs[1])
            acc = ad.outputs["Vector"]
    # macro variation +-12 % over 60-250 m
    tc = N.new("ShaderNodeTexCoord")
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.012
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.3
    mr.inputs["From Max"].default_value = 0.7
    mr.inputs["To Min"].default_value = 0.88
    mr.inputs["To Max"].default_value = 1.12
    L.new(nz.outputs["Fac"], mr.inputs["Value"])
    mm = N.new("ShaderNodeVectorMath")
    mm.operation = "SCALE"
    L.new(acc, mm.inputs[0])
    L.new(mr.outputs["Result"], mm.inputs["Scale"])
    aon = N.new("ShaderNodeAttribute")
    aon.attribute_name = "ao"
    mo = N.new("ShaderNodeVectorMath")
    mo.operation = "MULTIPLY"
    L.new(mm.outputs["Vector"], mo.inputs[0])
    L.new(aon.outputs["Color"], mo.inputs[1])
    L.new(mo.outputs["Vector"], b.inputs["Base Color"])
    fog_wrap(m, b.outputs["BSDF"])
    return m


def rock_material(name="tv_rock", moss=True):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    b = principled(m)
    t1 = tex_node(N, os.path.join(SL, "10_cliff_face.png"), 16.0, box=True)
    col = t1.outputs["Color"]
    if moss:
        t2 = tex_node(N, os.path.join(SL, "08_moss_fern.png"), 6.0, box=True)
        geo = N.new("ShaderNodeNewGeometry")
        sp = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Normal"], sp.inputs["Vector"])
        mr = N.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.55
        mr.inputs["From Max"].default_value = 0.8
        L.new(sp.outputs["Z"], mr.inputs["Value"])
        mx = N.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        L.new(mr.outputs["Result"], mx.inputs["Factor"])
        L.new(col, mx.inputs["A"])
        L.new(t2.outputs["Color"], mx.inputs["B"])
        col = mx.outputs["Result"]
    # vertex AO (COLOR r)
    ca = N.new("ShaderNodeVertexColor")
    ca.layer_name = "Color"
    mul = N.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    L.new(col, mul.inputs["A"])
    L.new(ca.outputs["Color"], mul.inputs["B"])
    L.new(mul.outputs["Result"], b.inputs["Base Color"])
    fog_wrap(m, b.outputs["BSDF"])
    return m


def card_material(name, path, tint=(1, 1, 1), strength=1.0, uv=True, alpha_scale=1.0, shaded=False,
                  fade_ends=0.0):
    """Unshaded alpha card (falls, foam, mist), colour x tint (the direction's light_tint)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    N.remove(N["Principled BSDF"])
    tex = N.new("ShaderNodeTexImage")
    tex.image = tvb.image(path)
    if uv:
        uvn = N.new("ShaderNodeUVMap")
        uvn.uv_map = "UVMap"
        L.new(uvn.outputs["UV"], tex.inputs["Vector"])
    mx = N.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.blend_type = "MULTIPLY"
    mx.inputs["Factor"].default_value = 1.0
    L.new(tex.outputs["Color"], mx.inputs["A"])
    mx.inputs["B"].default_value = tuple(tint) + (1.0,)
    if shaded:
        sh = N.new("ShaderNodeBsdfPrincipled")
        L.new(mx.outputs["Result"], sh.inputs["Base Color"])
        sh.inputs["Roughness"].default_value = 0.95
        so = sh.outputs["BSDF"]
    else:
        sh = N.new("ShaderNodeEmission")
        L.new(mx.outputs["Result"], sh.inputs["Color"])
        sh.inputs["Strength"].default_value = strength
        so = sh.outputs["Emission"]
    am = N.new("ShaderNodeMath")
    am.operation = "MULTIPLY"
    am.inputs[1].default_value = alpha_scale
    L.new(tex.outputs["Alpha"], am.inputs[0])
    if fade_ends:
        # the card's two ends fade out (UV2.x 0..1 across the card), so no card edge is ever seen
        u2 = N.new("ShaderNodeUVMap")
        u2.uv_map = "UV2"
        sx = N.new("ShaderNodeSeparateXYZ")
        L.new(u2.outputs["UV"], sx.inputs["Vector"])
        e1 = N.new("ShaderNodeMapRange")
        e1.inputs["From Min"].default_value = 0.0
        e1.inputs["From Max"].default_value = fade_ends
        L.new(sx.outputs["X"], e1.inputs["Value"])
        e2 = N.new("ShaderNodeMapRange")
        e2.inputs["From Min"].default_value = 1.0
        e2.inputs["From Max"].default_value = 1.0 - fade_ends
        L.new(sx.outputs["X"], e2.inputs["Value"])
        m1 = N.new("ShaderNodeMath")
        m1.operation = "MULTIPLY"
        L.new(e1.outputs["Result"], m1.inputs[0])
        L.new(e2.outputs["Result"], m1.inputs[1])
        m2 = N.new("ShaderNodeMath")
        m2.operation = "MULTIPLY"
        L.new(am.outputs["Value"], m2.inputs[0])
        L.new(m1.outputs["Value"], m2.inputs[1])
        am = m2
    out = N.new("ShaderNodeOutputMaterial") if N.get("Material Output") is None else N["Material Output"]
    fog_wrap(m, so, am.outputs["Value"])
    try:
        m.surface_render_method = "BLENDED"
    except AttributeError:
        m.blend_method = "BLEND"
    m.use_backface_culling = False
    return m


def water_material():
    m = bpy.data.materials.new("tv_water")
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    b = principled(m)
    b.inputs["Roughness"].default_value = 0.12
    try:
        b.inputs["Specular IOR Level"].default_value = 0.5
    except KeyError:
        pass
    ca = N.new("ShaderNodeVertexColor")
    ca.layer_name = "Color"
    flow = N.new("ShaderNodeTexImage")
    flow.image = tvb.image(os.path.join(P, "water", "tv_river_flow.png"))
    uvn = N.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    L.new(uvn.outputs["UV"], flow.inputs["Vector"])
    mx = N.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    am = N.new("ShaderNodeMath")
    am.operation = "MULTIPLY"
    am.inputs[1].default_value = 0.55
    L.new(flow.outputs["Alpha"], am.inputs[0])
    L.new(am.outputs["Value"], mx.inputs["Factor"])
    L.new(ca.outputs["Color"], mx.inputs["A"])
    L.new(flow.outputs["Color"], mx.inputs["B"])
    L.new(mx.outputs["Result"], b.inputs["Base Color"])
    # alpha: by depth (vertex colour alpha) plus the streaks
    ad = N.new("ShaderNodeMath")
    ad.operation = "ADD"
    ad.use_clamp = True
    L.new(ca.outputs["Alpha"], ad.inputs[0])
    L.new(am.outputs["Value"], ad.inputs[1])
    fog_wrap(m, b.outputs["BSDF"], ad.outputs["Value"])
    try:
        m.surface_render_method = "BLENDED"
    except AttributeError:
        m.blend_method = "BLEND"
    return m


# ---------------------------------------------------------------- props: water, falls, mist, towers

FALL_X = -95.0
FALLS = [(-95.0, 18.0), (120.0, 11.0), (-260.0, 14.0)]  # (x, width m) off the far wall


def water(terrain_h_fn):
    ramp_img = tvb.image(os.path.join(P, "water", "tv_river_ramp.png"))
    rw, rh = ramp_img.size
    px = np.array(ramp_img.pixels[:], np.float32).reshape(rh, rw, 4)  # bottom row first, linear
    day = px[rh - 1 - 1].copy()  # image row 1 (day); the buffer is bottom-up
    day[:, :3] = np.where(day[:, :3] <= 0.04045, day[:, :3] / 12.92, ((day[:, :3] + 0.055) / 1.055) ** 2.4)
    md = tvb.MeshData()
    nx, ny = 240, 40
    rows = []
    for j in range(ny):
        row = []
        for i in range(nx):
            x = -380 + 760 * i / (nx - 1)
            y = river_y(x) - 22 + 44 * j / (ny - 1)
            h, *_ = height(np.array([[x]]), np.array([[y]]))
            dep = float(WATER_Z - h[0, 0])
            k = int(np.clip(dep / 4.0 * (rw - 1), 0, rw - 1))
            c = day[k]
            a = float(np.clip(0.45 + 0.47 * dep / 3.0, 0.35, 0.92))
            row.append(md.add((x, y, WATER_Z), (0, 0, 1), (x / 30.0, y / 30.0), (0, 0),
                              (float(c[0]), float(c[1]), float(c[2]), a)))
        rows.append(row)
    for j in range(ny - 1):
        for i in range(nx - 1):
            a, b, c, d = rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]
            md.tris += [(a, b, c), (a, c, d)]
    return md.to_object("water", water_material())


def plane(name, center, right, up, w, h, mat, uv_scale=(1, 1), nu=1, nv=1, bend=None):
    md = tvb.MeshData()
    ids = []
    for j in range(nv + 1):
        row = []
        for i in range(nu + 1):
            u, v = i / nu, j / nv
            p = Vector(center) + Vector(right) * (u - 0.5) * w + Vector(up) * (v - 0.5) * h
            if bend:
                p = bend(p, u, v)
            row.append(md.add(p, Vector(right).cross(Vector(up)), (u * uv_scale[0], v * uv_scale[1]), (u, v),
                              (1, 1, 1, 1)))
        ids.append(row)
    for j in range(nv):
        for i in range(nu):
            a, b, c, d = ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]
            md.tris += [(a, b, c), (a, c, d)]
    ob = md.to_object(name, mat)
    ob.visible_shadow = False
    return ob


def karst_tower(name, base, H, R, seed, mat, lean=0.1, tiers=4, sides=28, rings=34):
    """A stand-in karst tower (the ROCK builder makes the real ones): stacked slab tiers, each stepping in at a
    ledge, lumpy in plan (3-5 lobes that drift with height), vertical fluting, a lean, a domed crown, an undercut
    waist on some; vertex AO darker low and under each ledge. Returns the object, the crown centre and radius, and
    ledge points for shrubs and pines."""
    rng = random.Random(seed)
    md = tvb.MeshData()
    ldir = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * lean
    tier_t = sorted(rng.uniform(0.2, 0.8) for _ in range(tiers - 1))
    tier_k = [rng.uniform(0.1, 0.22) for _ in tier_t]
    flute_f = rng.randint(9, 15)
    ph = [rng.uniform(0, 6.28) for _ in range(6)]
    lobes = rng.randint(3, 5)
    undercut = rng.random() < 0.35
    rows = []
    ledges = []
    for j in range(rings + 1):
        t = j / rings
        r = R * (1.0 - 0.25 * t)
        for tt, kk in zip(tier_t, tier_k):
            r -= R * kk * smoothstep(tt - 0.004, tt + 0.012, t)
        if t > 0.84:
            q = (t - 0.84) / 0.16
            r *= math.sqrt(max(1 - q ** 1.6, 0.0)) * 0.92 + 0.08 * (1 - q)
        if undercut:
            r *= 1.0 - 0.14 * math.exp(-((t - 0.25) / 0.08) ** 2)
        z = base.z - 10.0 + (H + 10.0) * t
        c = Vector((base.x, base.y, z)) + ldir * H * t * t
        notch = min((t - tt for tt in tier_t if t >= tt), default=1.0)
        ao = 0.6 + 0.4 * t ** 0.5
        ao *= 0.78 + 0.22 * smoothstep(0.0, 0.06, notch)
        row = []
        for i in range(sides + 1):
            a = 2 * math.pi * i / sides
            fl = 1.0 + 0.045 * math.sin(a * flute_f + ph[0]) + 0.13 * math.sin(a * lobes + ph[1] + t * 3.0) \
                + 0.06 * math.sin(a * (lobes + 2) + ph[2] - t * 5.0) + 0.03 * math.sin(a * 23 + ph[3] + t * 40)
            rr = max(r * fl, 0.05)
            p = c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0))
            row.append(md.add(p, (math.cos(a), math.sin(a), 0), (i / sides, t), (0, 0), (ao, ao, ao, 1.0)))
        rows.append(row)
    for tt, kk in zip(tier_t, tier_k):
        z = base.z - 10.0 + (H + 10.0) * (tt + 0.012)
        c = Vector((base.x, base.y, z)) + ldir * H * tt * tt
        rr = R * (1.0 - 0.25 * tt) * (1 - kk * 0.5)
        for k in range(rng.randint(2, 4)):
            a = rng.uniform(0, 6.28)
            ledges.append(c + Vector((math.cos(a), math.sin(a), 0)) * rr * 0.92)
    top = md.add(Vector((base.x, base.y, base.z + H + 0.5)) + ldir * H, (0, 0, 1), (0.5, 1), (0, 0), (1, 1, 1, 1))
    for j in range(rings):
        for i in range(sides):
            a, b, c, d = rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]
            md.tris += [(a, b, c), (a, c, d)]
    for i in range(sides):
        md.tris.append((rows[-1][i], rows[-1][i + 1], top))
    ob = md.to_object(name, mat, custom_normals=False)
    crown = Vector((base.x, base.y, base.z + H * 0.96)) + ldir * H
    return ob, crown, R * 0.5, ledges


def instance(src, loc, scale=1.0, rot=0.0):
    ob = bpy.data.objects.new(src.name + "_i", src.data)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.scale = (scale, scale, scale)
    ob.rotation_euler = (0, 0, rot)
    return ob


def grass_cards(md, rng, tiles, x, y, z, s, kind_cells):
    cell = kind_cells[rng.randrange(len(kind_cells))]
    u0, v0, u1, v1 = cell["uv_rect"]
    asp = cell["aspect"]
    hgt = s
    wid = s * asp
    rot = rng.uniform(0, math.pi)
    for k in range(3):
        a = rot + k * math.pi / 3
        r = Vector((math.cos(a), math.sin(a), 0))
        n = Vector((0, 0, 1))
        ids = []
        for (cu, cv) in ((0, 0), (1, 0), (1, 1), (0, 1)):
            p = Vector((x, y, z - 0.05)) + r * (cu - 0.5) * wid + Vector((0, 0, cv * hgt))
            ids.append(md.add(p, (n + r.cross(n) * 0.0).normalized(), (u0 + (u1 - u0) * cu, 1 - (v1 - (v1 - v0) * cv)),
                              (cv, 0), (0.75 + 0.25 * cv, 0, 0, 1)))
        md.tris += [(ids[0], ids[1], ids[2]), (ids[0], ids[2], ids[3])]


# ---------------------------------------------------------------- scene

def build_scene(dname):
    d = tvb.PAL["directions"][dname]
    fog_c = d["fog"]["color"]
    if "valley_color" in d["fog"]:  # dusk: the warm fog toward the sun, violet in the valleys (a mix of both)
        a_, b_ = tvb.hex_lin(fog_c), tvb.hex_lin(d["fog"]["valley_color"])
        fog_lin = tuple(a_[i] * 0.45 + b_[i] * 0.55 for i in range(3))
    else:
        fog_lin = tvb.hex_lin(fog_c)
    FOG.update({"color": fog_lin, "density": d["fog"]["density"] * 1.15,
                "height": WATER_Z + 28.0, "height_boost": d["fog"]["height_density"] / max(d["fog"]["density"], 1e-6)
                * 0.12, "max": 0.97, "strength": 1.0})
    tvb.reset()
    sc = tvb.lineup_scene(res=tuple(int(v) for v in A.get("res", "1920x1080").split("x")),
                          samples=int(A.get("samples", 64)))
    try:
        sc.view_settings.look = "AgX - Medium High Contrast" if d["grade"]["contrast"] >= 1.15 else \
            "AgX - Base Contrast"
    except TypeError:
        pass
    amb = tvb.hex_lin(d["ambient"]["color"])
    tvb.world_panorama(os.path.join(P, "sky", "tv_sky_%s.png" % dname), strength=1.0,
                       light_strength=max(d["ambient"]["energy"], 0.95) * 0.9, light_rgb=amb)
    s = d["sun"]
    tvb.sun(s["azimuth_deg"], s["elevation_deg"], tvb.hex_lin(s["color"]), strength=s["energy"] * 2.4,
            angle_deg=s.get("angular_deg", 1.5))
    sun_c = Vector(tvb.hex_lin(s["color"]))
    light_tint = tuple(min(1.0, v) for v in (sun_c * 0.6 + Vector(amb) * 0.4 * d["ambient"]["energy"]) * 1.05)

    terrain, (X, Y, H, W, slope, D) = build_terrain()
    water(height)
    rock = rock_material()
    # the needle in the river, towers on the far side, ranks behind
    rng = random.Random(77)
    tops = []
    ob, crown, cr, led = karst_tower("needle", Vector((70.0, float(river_y(70.0)) + 2, WATER_Z - 2)), 64.0, 10.0, 5,
                                     rock, lean=0.05, tiers=3)
    tops.append((crown, cr))
    ledges = list(led)
    for i, (x, y, h, r) in enumerate([(-250, 260, 160, 22), (-150, 360, 230, 30), (190, 320, 190, 26),
                                       (290, 230, 130, 18), (-40, 470, 250, 34), (120, 520, 220, 30),
                                       (-330, 450, 200, 28), (340, 460, 240, 32)]):
        hb, *_ = height(np.array([[x]]), np.array([[y]]))
        ob, crown, cr, led = karst_tower("tower%d" % i, Vector((x, y, float(hb[0, 0]))), h, r, 100 + i, rock,
                                         lean=rng.uniform(0.08, 0.22), tiers=rng.randint(3, 6))
        tops.append((crown, cr))
        ledges += led
    for i in range(26):  # backdrop ranks at 0.8-2.6 km
        x = rng.uniform(-2200, 2200)
        y = rng.uniform(800, 2600)
        h = rng.uniform(180, 420) * (0.6 + y / 2600)
        karst_tower("rank%d" % i, Vector((x, y, 140.0)), h, h * rng.uniform(0.14, 0.22), 300 + i, rock,
                    lean=rng.uniform(0.04, 0.16), tiers=rng.randint(3, 5), sides=20, rings=20)
    # vegetation (built by build_foliage, LOD0)
    mats = {}
    srcs = {}
    for name, fn, heights, bark in bf.SPECIES:
        mats[name] = tvb.foliage_material(name, bf.ATLAS, os.path.join(bf.FOL, bark))
        for k, h in enumerate(heights):
            md = bf.build(name, fn, h, k, 0)
            ob = md.to_object("%s_v%d" % (name, k), mats[name])
            ob.location = (0, 0, -5000)
            srcs[(name, k)] = ob
    for (crown, cr) in tops:  # pines on every karst top
        for k in range(rng.randint(2, 4)):
            a = rng.uniform(0, 6.28)
            p = crown + Vector((math.cos(a), math.sin(a), 0)) * cr * rng.uniform(0.0, 0.7)
            instance(srcs[("tv_karst_pine", rng.randint(0, 2))], p - Vector((0, 0, 1.5)), rng.uniform(2.0, 3.2),
                     rng.uniform(0, 6.28))
    for p in ledges:  # shrubs and small pines on the tier ledges
        sp = ("tv_karst_pine", rng.randint(0, 1)) if rng.random() < 0.5 else ("tv_shrub", rng.randint(0, 2))
        instance(srcs[sp], p - Vector((0, 0, 0.5)), rng.uniform(1.6, 2.6), rng.uniform(0, 6.28))

    def ground(x, y):
        h, *_ = height(np.array([[x]]), np.array([[y]]))
        return float(h[0, 0])

    def slope_at(x, y):
        e = 1.5
        gx = (ground(x + e, y) - ground(x - e, y)) / (2 * e)
        gy = (ground(x, y + e) - ground(x, y - e)) / (2 * e)
        return math.degrees(math.atan(math.hypot(gx, gy)))

    placed = 0
    tries = 0
    grove_seed = 13
    while placed < 900 and tries < 20000:
        tries += 1
        x, y = rng.uniform(-340, 340), rng.uniform(-110, 480)
        dd = y - float(river_y(x))
        if abs(dd) < 18 or slope_at(x, y) > 24:
            continue
        hh = ground(x, y)
        if hh < WATER_Z + 2:
            continue
        if x > 240 and y < float(river_y(x)) - 30 and abs(y - (float(river_y(x)) - 46)) < 14:
            continue  # keep the rim in front of the camera open
        _, _, T, RR = height(np.array([[x]]), np.array([[y]]))
        if T[0, 0] > 0.5 and rng.random() < 0.9:
            continue  # terraces stay open
        g = float(fbm(np.array([[x]]), np.array([[y]]), grove_seed, 2, 40.0)[0, 0])
        if rng.random() > 0.08 + 0.92 * smoothstep(0.1, 0.5, g):
            continue  # trees gather in groves
        r = rng.random()
        if dd > 0 and dd < 60 and r < 0.35:
            sp = ("tv_bamboo", rng.randint(0, 1))
        elif r < 0.75:
            sp = ("tv_broadleaf", rng.randint(0, 2))
        elif r < 0.85:
            sp = ("tv_banana", 0)
        else:
            sp = ("tv_karst_pine", rng.randint(0, 2))
        instance(srcs[sp], (x, y, hh - 0.3), rng.uniform(0.85, 1.25), rng.uniform(0, 6.28))
        placed += 1
    for i in range(70):  # shrubs and ferns near the camera and at the fall's foot
        x, y = rng.uniform(150, 330), rng.uniform(-60, float(river_y(250)) - 36)
        if abs(x - 300) < 14 and y < -2:
            continue
        sp = ("tv_shrub", rng.randint(0, 2)) if rng.random() < 0.55 else ("tv_fern", rng.randint(0, 2))
        instance(srcs[sp], (x, y, ground(x, y) - 0.1), rng.uniform(0.9, 1.4), rng.uniform(0, 6.28))
    for i in range(1400):  # green on the wall ledges (every third stratum) and along the rims
        x = rng.uniform(-350, 330)
        dd = rng.choice([-1, 1]) * rng.uniform(14.0, 34.0)
        y = float(river_y(x)) + dd
        hh = ground(x, y)
        band = (hh / 7.0) % 3.0
        if not (0.1 < band < 1.1) or hh < WATER_Z + 6:
            continue
        if x > 200 and abs(dd) < 40 and dd < 0:
            continue  # nothing on the near wall right under the camera
        p = Vector((x, y - math.copysign(1.2, dd), hh - 0.3))
        r = rng.random()
        sp = ("tv_shrub", rng.randint(0, 2)) if r < 0.5 else (("tv_fern", rng.randint(0, 2)) if r < 0.8 else
                                                               ("tv_karst_pine", 0))
        instance(srcs[sp], p, rng.uniform(2.0, 3.4), rng.uniform(0, 6.28))
    for i in range(30):
        x = FALL_X + rng.uniform(-30, 30)
        y = float(river_y(FALL_X)) + rng.uniform(14, 26)
        if slope_at(x, y) > 35:
            continue
        instance(srcs[("tv_fern", rng.randint(0, 2))], (x, y, ground(x, y)), rng.uniform(1.0, 1.6), rng.uniform(0, 6.28))
    # grass cards near the camera
    import json
    gv = json.load(open(os.path.join(bf.FOL, "tv_grass_variants.json")))
    hv = json.load(open(os.path.join(bf.FOL, "tv_herb_variants.json")))
    gmd = tvb.MeshData()
    hmd = tvb.MeshData()
    for i in range(2600):
        x, y = rng.uniform(180, 330), rng.uniform(-60, float(river_y(250)) - 36)
        if abs(y - (float(river_y(x)) - 52.0 + 6.0 * math.sin(x / 25.0))) < 2.2:
            continue
        if slope_at(x, y) > 30:
            continue
        z = ground(x, y)
        if rng.random() < 0.85:
            grass_cards(gmd, rng, None, x, y, z, rng.uniform(0.35, 0.7),
                        [c for c in gv if c["kind"] in ("grass", "grass_short", "meadow")])
        else:
            grass_cards(hmd, rng, None, x, y, z, rng.uniform(0.3, 0.55), hv)
    gm = tvb.foliage_material("grass_cards", os.path.join(bf.FOL, "tv_grass_atlas.png"),
                              os.path.join(bf.FOL, "tv_bark_broadleaf.png"))
    hm = tvb.foliage_material("herb_cards", os.path.join(bf.FOL, "tv_herb_atlas.png"),
                              os.path.join(bf.FOL, "tv_bark_broadleaf.png"))
    gmd.to_object("grass", gm)
    hmd.to_object("herbs", hm)
    # the camera on the near rim, looking west-north-west along the gorge (as V1 looks west along C1)
    cx0 = 300.0
    cy0 = float(river_y(cx0)) - 30.0
    cam_p = Vector((cx0, cy0, ground(cx0, cy0) + 16.0))
    cam_t = Vector((-120.0, 70.0, 104.0))
    cam = tvb.camera(cam_p, cam_t, lens=24)
    cam.data.clip_end = 9000
    fwd = (cam_t - cam_p)
    fwd.z = 0
    fwd.normalize()
    side = Vector((fwd.y, -fwd.x, 0))  # camera right

    def facing(p):
        v = Vector((cam_p.x - p[0], cam_p.y - p[1], 0)).normalized()
        return Vector((-v.y, v.x, 0))

    wd = os.path.join(P, "water")
    stain = card_material("stain", os.path.join(wd, "tv_wet_stain.png"), shaded=True, alpha_scale=0.9)
    body = card_material("fall_body", os.path.join(wd, "tv_fall_body.png"), light_tint, 1.35, alpha_scale=1.3)
    streaks = card_material("fall_streaks", os.path.join(wd, "tv_fall_streaks.png"), light_tint, 1.2)
    edge = card_material("fall_edge", os.path.join(wd, "tv_fall_edge_foam.png"), light_tint, 1.1)
    foam = card_material("pool_foam", os.path.join(wd, "tv_pool_foam_ring.png"), light_tint, 1.0)
    spray = card_material("spray", os.path.join(wd, "tv_fall_spray.png"), light_tint, 1.0, alpha_scale=0.85)
    for (fx, W_) in FALLS:
        # each fall: a ribbon off the far (north) wall: wet stain behind, body, faster streaks, edge foam, pool
        # foam ring, spray puffs at the foot (flow drawn 2-3 x real)
        fy = float(river_y(fx)) + 17.0
        ztop = ground(fx, fy + 22)
        fall_h = ztop - WATER_Z + 2

        def fall_bend(p, u, v):
            return p + Vector((0, -2.5 * (v ** 2) - 1.0, 0))

        plane("stain", (fx, fy + 3.0, WATER_Z + fall_h / 2), (1, 0, 0), (0, 0, 1), W_ * 2.4, fall_h + 6, stain)
        fr = facing((fx, fy))
        plane("fall_body", (fx, fy, WATER_Z + fall_h / 2), fr, (0, 0, 1), W_, fall_h, body,
              uv_scale=(1, fall_h / (W_ * 4)), nu=2, nv=8, bend=fall_bend)
        plane("fall_streaks", (fx, fy - 0.4, WATER_Z + fall_h / 2), fr, (0, 0, 1), W_ * 0.9, fall_h,
              streaks, uv_scale=(1, fall_h / (W_ * 4) * 1.3), nu=2, nv=8, bend=fall_bend)
        for sgn in (-1, 1):
            plane("fall_edge", (fx + fr.x * sgn * W_ * 0.5, fy - 0.6 + fr.y * sgn * W_ * 0.5, WATER_Z + fall_h / 2),
                  fr, (0, 0, 1),
                  W_ * 0.22, fall_h, edge, uv_scale=(1, fall_h / (W_ * 0.9)), nu=1, nv=8, bend=fall_bend)
        plane("pool_foam", (fx, fy - 8, WATER_Z + 0.15), (1, 0, 0), (0, 1, 0), W_ * 2.8, W_ * 2.2, foam)
        for k in range(6):
            x = fx + rng.uniform(-W_ * 0.6, W_ * 0.6)
            s_ = rng.uniform(0.8, 1.3) * W_
            p = (x, fy - 6 - rng.uniform(0, 4), WATER_Z + s_ * 0.3)
            ob = plane("spray", p, facing(p), (0, 0, 1), s_, s_, spray, uv_scale=(0.5, 0.5))
            cu, cv = rng.randint(0, 1) * 0.5, rng.randint(0, 1) * 0.5
            for lp in ob.data.uv_layers["UVMap"].data:
                lp.uv = (lp.uv[0] + cu, lp.uv[1] + cv)
    # mist bands at the direction's heights: long cards across the view at several depths, facing the camera
    mist_c = tvb.hex_lin(d["targets"]["mist"])
    for bi, (z0, z1, note) in enumerate(d["mist_bands_m"]):
        low = z0 < 200
        zc = WATER_Z + 10.0 + (z0 - 145.0) * 1.2 if low else WATER_Z + 120.0 + (z0 - 255.0)
        hgt = max((z1 - z0) * 2.2, 22.0) if low else 70.0
        dists = (140.0, 260.0, 420.0, 650.0) if low else (520.0, 800.0, 1200.0)
        for k, dist in enumerate(dists):
            mtex = os.path.join(wd, "tv_mist_band_%s.png" % "abc"[(bi + k) % 3])
            mm = card_material("mist%d_%d" % (bi, k), mtex, mist_c, 1.0, alpha_scale=0.8 if low else 0.7,
                               fade_ends=0.3)
            p = cam_p + fwd * dist + side * rng.uniform(-60, 60)
            plane("mist", (p.x, p.y, zc + k * 3.0), side, (0, 0, 1), dist * 1.6, hgt, mm, uv_scale=(2.0, 1),
                  nu=4)
    return sc


def main():
    dirs = A.get("dirs", "jade_mist_morning,bright_saturated_noon,golden_lantern_dusk").split(",")
    for dn in dirs:
        build_scene(dn)
        tvb.render(os.path.join(tvb.LOOK, "diorama", "diorama_%s.png" % dn))


main()
