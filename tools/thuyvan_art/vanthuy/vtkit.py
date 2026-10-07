"""Blender helpers for the Vạn Thủy kit (VANTHUY): the VILLAGE kit's tvkit (Builder, the baked vertex occlusion, the
GLB export), loaded as a second, private module instance and pointed at this kit's material table and textures, so the
two kits share one geometry idiom without touching each other's materials:

* materials are named tvvt_<key> (materials.json here) and sample assets/thuyvan/vanthuy/textures/<key>.png x the
  colour attribute "Col";
* UVs are in tile units of this kit's tile_m;
* silt_line() darkens the vertex colour under a water line (green-black, the archive walls' and lock walls' silt line,
  places_se.md VT6), never below the 0.5 floor of style guide 5.3.

Blender coordinates: Z up, a piece's front faces -Y (glTF +Y up: Blender -Y = Godot +Z).
"""

import importlib.util
import json
import os

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
_VILLAGE_TVKIT = os.path.join(REPO, "tools", "thuyvan_art", "village", "tvkit.py")
_spec = importlib.util.spec_from_file_location("tvkit_vanthuy", _VILLAGE_TVKIT)
K = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(K)

PREFIX = "tvvt_"
TEX_DIR = os.path.join(REPO, "assets", "thuyvan", "vanthuy", "textures")
MATJ = json.load(open(os.path.join(HERE, "materials.json")))
MATS = MATJ["keys"]
DOUBLE_SIDED = {k for k in MATS if k.startswith(("banner_", "cloth_"))} | {"sail", "notice", "paper", "oil_glass",
                                                                          "weave"}
K.TEX_DIR = TEX_DIR
K.MATS = MATS
K.DOUBLE_SIDED = DOUBLE_SIDED
hex_lin = K.hex_lin


def material(key):
    name = PREFIX + key
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    spec = MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = key not in DOUBLE_SIDED
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(TEX_DIR, key + ".png"), check_existing=True)
    tex.interpolation = "Linear"
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mix.inputs[6])
    nt.links.new(col.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.95)
    bsdf.inputs["Specular IOR Level"].default_value = spec.get("spec", 0.12)
    if "emission" in spec:
        # emission strength is 0 in the asset (off by day); render_vanthuy.py lights it per direction
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 0.0
    return m


K.material = material          # Builder.obj() resolves material() in this module instance: tvvt_<key>
Builder = K.Builder
bake_vertex_ao = K.bake_vertex_ao
tri_count = K.tri_count
export_glb = K.export_glb
frame_from, rot_x, rot_y, rot_z = K.frame_from, K.rot_x, K.rot_y, K.rot_z


def silt_line(ob, z_line, keys=("ashlar", "ashlar_old", "paving"), band=0.6, below=(0.66, 0.72, 0.64), xr=None):
    """Darken Col under z_line (object space) on the stone keys: a darker band at the line, a green-black wash below;
    xr = (x0, x1) limits it to a streak (a drain mouth's green run)."""
    me = ob.data
    ca = me.color_attributes.get("Col")
    if ca is None:
        return
    data = np.zeros(len(me.loops) * 4, np.float32)
    ca.data.foreach_get("color", data)
    data = data.reshape(-1, 4)
    co = np.zeros(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    kidx = {i for i, m in enumerate(me.materials) if m and m.name[len(PREFIX):] in keys}
    below = np.asarray(below)
    for p in me.polygons:
        if p.material_index not in kidx:
            continue
        for li in p.loop_indices:
            x, z = co[me.loops[li].vertex_index][0], co[me.loops[li].vertex_index][2]
            if xr is not None and not (xr[0] <= x <= xr[1]):
                continue
            if z < z_line:
                f = below * (0.92 if z > z_line - band else 1.0)
                data[li, :3] = np.maximum(data[li, :3] * f, 0.5)
    ca.data.foreach_set("color", data.ravel())


def decimated(ob, target, name):
    """LOD1: a copy collapsed to about `target` triangles (UVs and the corner colours interpolate)."""
    c = ob.copy()
    c.data = ob.data.copy()
    c.name = name
    c.data.name = name
    bpy.context.scene.collection.objects.link(c)
    t = tri_count(ob)
    if t > target:
        md = c.modifiers.new("lod", "DECIMATE")
        md.ratio = max(0.02, target / t)
        md.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = c
        bpy.ops.object.select_all(action="DESELECT")
        c.select_set(True)
        bpy.ops.object.modifier_apply(modifier="lod")
    for ch in ob.children:          # anchors and colliders follow the LOD
        cc = ch.copy()
        if ch.data:
            cc.data = ch.data.copy()
        cc.parent = c
        bpy.context.scene.collection.objects.link(cc)
    c["lod1"] = True
    return c
