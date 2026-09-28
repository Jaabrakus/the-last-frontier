#!/usr/bin/env python3
"""Writes the Godot import settings for package C's assets (run before `Godot --import`).

    python3 tools/environment/vegetation/import_settings.py

Godot's defaults are wrong for these files when they are imported headless (nothing detects 3D
use): textures would be imported lossless without mipmaps and normal maps would not be marked.
This sets, for every file under assets/environment/vegetation and assets/environment/props:
  *_albedo*.png / foliage_albedo / impostor albedo   VRAM compressed, high quality (BPTC), mipmaps
  *_normal*.png                                         VRAM compressed as a normal map (RGTC), mipmaps
  *_arm*.png                                            VRAM compressed (S3TC), mipmaps
  *.glb                                                 no auto LODs (the LODs are authored), no
                                                        shadow meshes, no lightmap UV2, tangents on
Existing [remap]/[deps] sections are kept; only [params] is replaced.
"""
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ROOTS = [os.path.join(FRONTIER, 'assets', 'environment', 'vegetation'),
         os.path.join(FRONTIER, 'assets', 'environment', 'props')]

TEX = """compress/mode=2
compress/high_quality={hq}
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={nm}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

SCENE = """nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=false
meshes/create_shadow_meshes=false
meshes/light_baking=0
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={}
gltf/naming_version=2
gltf/embedded_image_handling=1
gltf/texture_map_mode=1
"""


def write(path, importer, typ, params):
    imp = path + '.import'
    head = '[remap]\n\nimporter="%s"\ntype="%s"\n' % (importer, typ)
    if os.path.exists(imp):
        txt = open(imp).read()
        if '[params]' in txt:
            head = txt.split('[params]')[0]
    new = head.rstrip() + '\n\n[params]\n\n' + params
    old = open(imp).read() if os.path.exists(imp) else ''
    if old != new:
        with open(imp, 'w') as f:
            f.write(new)
        print('import settings:', os.path.relpath(path, FRONTIER))


def main():
    for root in ROOTS:
        for dp, dn, fn in os.walk(root):
            for f in sorted(fn):
                p = os.path.join(dp, f)
                low = f.lower()
                if low.endswith('.png'):
                    if 'normal' in low:
                        write(p, 'texture', 'CompressedTexture2D', TEX.format(hq='false', nm=1))
                    elif 'albedo' in low:
                        write(p, 'texture', 'CompressedTexture2D', TEX.format(hq='true', nm=2))
                    else:
                        write(p, 'texture', 'CompressedTexture2D', TEX.format(hq='false', nm=2))
                elif low.endswith('.glb'):
                    write(p, 'scene', 'PackedScene', SCENE)


if __name__ == '__main__':
    main()
