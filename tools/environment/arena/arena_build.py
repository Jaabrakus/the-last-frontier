"""The arena for the game (the owner's pick of 2026-10-16: "ruin and crater"): arena_board.py's build of a look, its
procedural materials BAKED to our own texture tiles (Cycles: colour, normal, roughness, glow; TILE_M metres a tile, the
meshes' box-projected UVs), and the scene written as glTF for Godot (assets/arena/<look>/arena_<w>x<l>.gltf with its
textures beside it, shared by every size of the look). The water, the curtain's sheet and the lanterns are left out: the
game draws its own (RingWater, RingDressing). Blender 5.2, headless.

  Blender -b --factory-startup --python tools/environment/arena/arena_build.py -- --out assets/arena --looks ruin,crater
      [--sizes 14x34:5,12x28:4] [--px 1024] [--samples 16] [--no-bake]
  (through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
A size is "<w>x<l>:<zone_m>" (the neutral strip stays 4 m): the stock 1v1 deck 14x34:5, the zones' 12x28:4, 2v2 20x40:6,
4v4 28x52:8 (data/ring/ring.json). --no-bake keeps the procedural materials (a quick look at the geometry in Blender).
"""
import argparse
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import arena_board as ab  # noqa: E402


def argv():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    p.add_argument("--looks", default="ruin,crater")
    p.add_argument("--sizes", default="14x34:5,12x28:4")
    p.add_argument("--px", type=int, default=1024)
    p.add_argument("--samples", type=int, default=16)
    p.add_argument("--no-bake", action="store_true")
    return p.parse_args(a)


# ---------------------------------------------------------------- baking a procedural material to a tile
def _bake_plane(scene):
    me = bpy.data.meshes.new("bake_tile")
    me.from_pydata([(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)], [], [(0, 1, 2, 3)])
    me.update()
    uv = me.uv_layers.new(name="UVMap")
    for li, co in zip(range(4), [(0, 0), (1, 0), (1, 1), (0, 1)]):
        uv.data[li].uv = co
    ob = bpy.data.objects.new("bake_tile", me)
    scene.collection.objects.link(ob)
    return ob


def _bake_copy(mat):
    """The material driven by the tile's UV (TILE_M metres across it) instead of the object's place, its tint white."""
    m = mat.copy()
    m.name = mat.name + "_bake"
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sc = nt.nodes.new("ShaderNodeVectorMath")
    sc.operation = "SCALE"
    sc.inputs["Scale"].default_value = ab.TILE_M
    nt.links.new(tc.outputs["UV"], sc.inputs[0])
    mp = nt.nodes.get("coords_map")
    if mp is not None:
        for lk in list(mp.outputs["Vector"].links):
            nt.links.new(sc.outputs["Vector"], lk.to_socket)
    for n in list(nt.nodes):
        if n.bl_idname == "ShaderNodeAttribute":
            white = nt.nodes.new("ShaderNodeRGB")
            white.outputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
            for lk in list(n.outputs["Color"].links):
                nt.links.new(white.outputs[0], lk.to_socket)
    return m


def _bake(scene, plane, mat, name, px, samples, out_dir):
    """One material's tiles: albedo (jpg), normal (png), roughness (jpg) and, when it glows, emission (jpg)."""
    bake = _bake_copy(mat)
    plane.data.materials.clear()
    plane.data.materials.append(bake)
    nt = bake.node_tree
    bsdf = None
    for n in nt.nodes:
        if n.bl_idname == "ShaderNodeBsdfPrincipled":
            bsdf = n
    glows = bsdf is not None and (bsdf.inputs["Emission Strength"].links or bsdf.inputs["Emission Strength"].default_value > 0.0)
    passes = [("albedo", "DIFFUSE", "jpg", px, False), ("normal", "NORMAL", "png", px // 2, True), ("rough", "ROUGHNESS", "jpg", px // 2, True)]
    if glows:
        passes.append(("emit", "EMIT", "jpg", px // 2, False))
    out = {}
    for key, kind, ext, size, linear in passes:
        img = bpy.data.images.new("%s_%s" % (name, key), size, size, alpha=False, float_buffer=False)
        if linear:
            img.colorspace_settings.name = "Non-Color"
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.nodes.active = node
        node.select = True
        bpy.context.view_layer.objects.active = plane
        plane.select_set(True)
        kw = {"type": kind, "margin": 8, "use_clear": True}
        if kind == "DIFFUSE":
            kw["pass_filter"] = {"COLOR"}
        if kind == "NORMAL":
            scene.render.bake.normal_space = "TANGENT"
        bpy.ops.object.bake(**kw)
        path = os.path.join(out_dir, "%s_%s.%s" % (name, key, ext))
        img.filepath_raw = path
        img.file_format = "JPEG" if ext == "jpg" else "PNG"
        if ext == "jpg":
            scene.render.image_settings.quality = 88
        img.save()
        nt.nodes.remove(node)
        out[key] = path
        print("BAKED", name, key, size)
    bpy.data.materials.remove(bake)
    return out, glows


def _image_material(name, tiles, glows, src):
    """The material Godot gets: the baked tiles on a Principled shader by UV, the tint attribute kept over the colour."""
    m = bpy.data.materials.new(name + "_tex")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    tc = nt.nodes.new("ShaderNodeTexCoord")

    def tex(key, colour):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(tiles[key])
        n.image.colorspace_settings.name = "sRGB" if colour else "Non-Color"
        n.extension = "REPEAT"
        nt.links.new(tc.outputs["UV"], n.inputs["Vector"])
        return n

    alb = tex("albedo", True)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "tint"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(alb.outputs["Color"], mix.inputs[6])
    nt.links.new(at.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    rg = tex("rough", False)
    nt.links.new(rg.outputs["Color"], bsdf.inputs["Roughness"])
    nm = tex("normal", False)
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 1.0
    nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    if glows:
        em = tex("emit", True)
        nt.links.new(em.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    for n in src.node_tree.nodes:
        if n.bl_idname == "ShaderNodeBsdfPrincipled":
            bsdf.inputs["Metallic"].default_value = n.inputs["Metallic"].default_value
            if n.inputs["Alpha"].default_value < 1.0:
                bsdf.inputs["Alpha"].default_value = n.inputs["Alpha"].default_value
    m.use_backface_culling = src.use_backface_culling
    return m


def bake_all(scene, px, samples, out_dir, cache):
    """Every exported object's material baked once (a tile a material, kept in `cache` across sizes) and swapped for its
    image material."""
    os.makedirs(out_dir, exist_ok=True)
    keep_engine = scene.render.engine
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.device = "CPU"
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    plane = _bake_plane(scene)
    for ob in list(bpy.data.objects):
        if ob.type != "MESH" or not ob.get("export", True) or ob == plane or not ob.data.materials:
            continue
        src = ob.data.materials[0]
        if src.name not in cache:
            tiles, glows = _bake(scene, plane, src, src.name, px, samples, out_dir)
            m = _image_material(src.name, tiles, glows, src)
            m.use_fake_user = True             # (kept across the sizes' rebuilds: clear() takes what has no user)
            for n in m.node_tree.nodes:
                if n.bl_idname == "ShaderNodeTexImage" and n.image is not None:
                    n.image.use_fake_user = True
            cache[src.name] = m
        ob.data.materials[0] = cache[src.name]
    bpy.data.objects.remove(plane, do_unlink=True)
    scene.render.engine = keep_engine


def export(scene, path):
    """The look's meshes (the export flag) as glTF with its textures beside it; the water, the curtain and the lanterns left to
    the game. The vertex tints go as COLOR_0 (Godot multiplies the colour by them)."""
    for ob in bpy.data.objects:
        ob.select_set(bool(ob.get("export", True)) and ob.type == "MESH")
    kw = dict(filepath=path, export_format="GLTF_SEPARATE", export_texture_dir="tex", export_image_format="AUTO",
              export_apply=True, export_yup=True, use_selection=True, export_cameras=False, export_lights=False,
              export_materials="EXPORT", export_normals=True, export_tangents=False, export_animations=False, export_skins=False)
    for extra in ({"export_vertex_color": "ACTIVE"}, {"export_colors": True}, {}):
        try:
            bpy.ops.export_scene.gltf(**kw, **extra)
            break
        except TypeError as e:
            print("export arg:", e)
            continue
    print("WROTE", path)


def main():
    a = argv()
    looks = [s.strip() for s in a.looks.split(",") if s.strip() in ab.LOOKS]
    sizes = []
    for item in a.sizes.split(","):
        wl, zone = item.split(":")
        w, l = wl.split("x")
        sizes.append((float(w), float(l), float(zone)))
    for lk in looks:
        cache = {}
        for w, l, zone in sizes:
            ab.R.seed(1778)
            ab.clear()
            ab.SHAPE = "oval"
            ab.configure(w=w, l=l, zone=zone)
            scene = bpy.context.scene
            ab.setup_render(scene, "1600x900", 16)
            ab.LOOKS[lk](scene)
            print("BUILT", lk, "%gx%g" % (w, l), len(bpy.data.objects), "objects")
            out_dir = os.path.join(a.out, lk)
            os.makedirs(out_dir, exist_ok=True)
            if not a.no_bake:
                bake_all(scene, a.px, a.samples, os.path.join(out_dir, "tex"), cache)
            export(scene, os.path.join(out_dir, "arena_%gx%g.gltf" % (w, l)))
        _tidy(os.path.join(a.out, lk))


def _tidy(look_dir):
    """The textures no glTF of the look refers to taken away (the exporter writes roughness as its own png: the baked jpg
    is then spare)."""
    import json
    used = set()
    for f in os.listdir(look_dir):
        if f.endswith(".gltf"):
            d = json.load(open(os.path.join(look_dir, f)))
            for im in d.get("images", []):
                used.add(os.path.normpath(os.path.join(look_dir, im.get("uri", ""))))
    tex = os.path.join(look_dir, "tex")
    if not os.path.isdir(tex):
        return
    for f in os.listdir(tex):
        p = os.path.normpath(os.path.join(tex, f))
        if p not in used:
            os.remove(p)
    print("TIDY", look_dir, len(used), "textures kept")


main()
