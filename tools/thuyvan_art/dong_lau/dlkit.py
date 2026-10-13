"""The Reed Marches kit's Blender context: the village kit's Builder, bake and export (tools/thuyvan_art/village/tvkit.py,
imported and never edited) pointed at this kit's textures and material table.

Importing dlkit rebinds tvkit's module globals (TEX_DIR, MATS, DOUBLE_SIDED, material) so that every Builder made here,
and every village_kit helper it is handed (roof, post, plank_deck, wall, ladder, lantern_round, cloth_sheet), lays UVs
in this kit's tile sizes and names its materials tvd_<key> on this kit's painted textures. Alpha keys (net, reed cards)
get an alpha-scissor material (threshold 0.5), as Godot will draw them.

Blender coordinates: Z up, a piece's front faces -Y (glTF +Y up: Blender -Y = Godot +Z). Over-water pieces have their
origin on the water line (z 0) under the piece; piles run down to the bed at about -1.8 m.
"""

import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "village"))
import tvkit  # noqa: E402

REPO = tvkit.REPO
KIT = "dong_lau"
PREFIX = "tvd_"
TEX_DIR = os.path.join(REPO, "assets", "thuyvan", KIT, "textures")
MATS = json.load(open(os.path.join(HERE, "materials.json")))["keys"]
PALJ = json.load(open(tvkit.PALETTES))
PAL = PALJ["albedo"]["dong_lau"]
DOUBLE_SIDED = {"banner_heron", "banner_heron_b", "banner_heron_c", "cloth_madder", "cloth_bone", "cloth_indigo",
                "weave", "screen", "paper", "net", "reedcard", "fish"}
ALPHA = {k for k, v in MATS.items() if v.get("alpha")}


def ramp(name):
    zone = "dong_lau"
    if "." in name:
        zone, name = name.split(".", 1)
    return PALJ["albedo"][zone][name]


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
    if key in ALPHA:
        gt = nt.nodes.new("ShaderNodeMath")
        gt.operation = "GREATER_THAN"
        gt.inputs[1].default_value = 0.5
        nt.links.new(tex.outputs["Alpha"], gt.inputs[0])
        nt.links.new(gt.outputs[0], bsdf.inputs["Alpha"])
        m.surface_render_method = "DITHERED"
        try:
            m.blend_method = "CLIP"
            m.alpha_threshold = 0.5
        except (AttributeError, TypeError):
            pass
    if "emission" in spec:
        bsdf.inputs["Emission Color"].default_value = tvkit.hex_lin(spec["emission"]) + (1.0,)
        bsdf.inputs["Emission Strength"].default_value = 0.0
    return m


# the rebinding: tvkit's Builder.obj() and tile_of() look these names up in tvkit's module globals
tvkit.TEX_DIR = TEX_DIR
tvkit.MATS = MATS
tvkit.DOUBLE_SIDED = DOUBLE_SIDED
tvkit.material = material

Builder = tvkit.Builder
bake_vertex_ao = tvkit.bake_vertex_ao
tri_count = tvkit.tri_count
export_glb = tvkit.export_glb
hex_lin = tvkit.hex_lin
frame_from, rot_x, rot_y, rot_z = tvkit.frame_from, tvkit.rot_x, tvkit.rot_y, tvkit.rot_z
