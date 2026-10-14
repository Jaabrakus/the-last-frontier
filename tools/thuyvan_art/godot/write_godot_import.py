"""Thủy Vân kits into Godot 4.7: the import settings and the shared materials (plain python3; deterministic).

    python3 tools/thuyvan_art/godot/write_godot_import.py [--check]

Writes, from the kits' own notes (docs/thuyvan/look_paint.md, rock_kit.md, village_kit.md):

  .import files beside every texture and GLB under assets/thuyvan (an existing file's uid is kept, so a rerun never
  breaks a reference); Godot fills in the rest on its next --import:
    textures on 3D surfaces    VRAM compressed (BPTC/S3TC on desktop), mipmaps, as the frontier's 3D textures
    grass and herb atlases     as assets/environment/grass/*_atlas.png (high quality, no alpha-border fix)
    the karst normal           compressed as a normal map
    the terrain array          2d_array_texture, slices 3 x 4, BPTC, mipmaps (terrain_slices.json)
    the grade LUTs             3d_texture, slices 8 x 8, lossless, no mipmaps (as assets/environment/lut)
    the river ramp             lossless, no mipmaps (a lookup, read by depth)
    *_check.png                skipped: the painters' 3 x 3 / squint review sheets, not game textures
    GLBs                       scenes: name suffixes on (the rope bridge's "-colonly" decks become static trimesh
                               bodies), LODs generated (not on the hand-made *_lod1 files), light baking off, every
                               surface's material name pointed at its shared .tres (Use External)
  assets/thuyvan/village/materials/tvv_<key>.tres   from manifest.json "materials": StandardMaterial3D (painted texture
                               x vertex colour, Lambert wrap, the key's roughness and specular; lantern paper's
                               emission ready for dusk at energy 0); cloth keys a ShaderMaterial on
                               shaders/thuyvan/tv_cloth.gdshader (waves by the vertex colour's pin weight)
  assets/thuyvan/vegetation/materials/<species>.tres   from vegetation.json: shaders/thuyvan/tv_foliage.gdshader with
                               the leaf atlas and the species' bark
The rock kit's materials come from tools/thuyvan_art/rock/write_godot_materials.py (run it first).
--check: write nothing, exit 1 if any file would change.
"""

import argparse
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TV = os.path.join(REPO, "assets", "thuyvan")

TEX_PARAMS = [
    ("compress/mode", 2), ("compress/high_quality", False), ("compress/lossy_quality", 0.7),
    ("compress/uastc_level", 0), ("compress/rdo_quality_loss", 0.0), ("compress/hdr_compression", 1),
    ("compress/normal_map", 0), ("compress/channel_pack", 0), ("mipmaps/generate", True), ("mipmaps/limit", -1),
    ("roughness/mode", 0), ("roughness/src_normal", '""'), ("process/channel_remap/red", 0),
    ("process/channel_remap/green", 1), ("process/channel_remap/blue", 2), ("process/channel_remap/alpha", 3),
    ("process/fix_alpha_border", True), ("process/premult_alpha", False), ("process/normal_map_invert_y", False),
    ("process/hdr_as_srgb", False), ("process/hdr_clamp_exposure", False), ("process/size_limit", 0),
    ("detect_3d/compress_to", 0),
]
ARRAY_PARAMS = [
    ("compress/mode", 2), ("compress/high_quality", True), ("compress/lossy_quality", 0.7),
    ("compress/uastc_level", 0), ("compress/rdo_quality_loss", 0.0), ("compress/hdr_compression", 1),
    ("compress/channel_pack", 0), ("mipmaps/generate", True), ("mipmaps/limit", -1),
]
SCENE_PARAMS = [
    ("nodes/root_type", '""'), ("nodes/root_name", '""'), ("nodes/root_script", "null"),
    ("mesh_library/use_node_names_as_mesh_names", False), ("array_mesh/deduplicate_surfaces", True),
    ("nodes/apply_root_scale", True), ("nodes/root_scale", 1.0), ("nodes/import_as_skeleton_bones", False),
    ("nodes/use_name_suffixes", True), ("nodes/use_node_type_suffixes", True), ("meshes/ensure_tangents", True),
    ("meshes/generate_lods", True), ("meshes/create_shadow_meshes", True), ("meshes/light_baking", 0),
    ("meshes/lightmap_texel_size", 0.2), ("meshes/force_disable_compression", False), ("skins/use_named_skins", True),
    ("animation/import", False), ("animation/fps", 30), ("animation/trimming", False),
    ("animation/remove_immutable_tracks", True), ("animation/import_rest_as_RESET", False),
    ("import_script/path", '""'), ("materials/extract", 0), ("materials/extract_format", 0),
    ("materials/extract_path", '""'),
]


def val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


def res(path):
    return "res://" + os.path.relpath(path, REPO).replace(os.sep, "/")


def old_uid(path):
    try:
        m = re.search(r'^uid="([^"]+)"', open(path, encoding="utf-8").read(), re.M)
        return m.group(1) if m else None
    except OSError:
        return None


def import_file(src, importer, typ, params, subresources=None):
    imp = src + ".import"
    head = ["[remap]", "", 'importer="%s"' % importer]
    if typ:
        head.append('type="%s"' % typ)
    uid = old_uid(imp)
    if uid:
        head.append('uid="%s"' % uid)
    lines = head + ["", "[deps]", "", 'source_file="%s"' % res(src), "", "[params]", ""]
    lines += ["%s=%s" % (k, val(v)) for k, v in params]
    if subresources is not None:
        lines.append("_subresources=" + subresources)
    if importer == "scene":
        lines += ["gltf/naming_version=2", "gltf/embedded_image_handling=1", "gltf/texture_map_mode=1"]
    return imp, "\n".join(lines) + "\n"


def with_params(base, **over):
    over = {k.replace("__", "/"): v for k, v in over.items()}
    return [(k, over.get(k, v)) for k, v in base]


def texture_import(src):
    name = os.path.basename(src)
    rel = os.path.relpath(src, TV).replace(os.sep, "/")
    if name.endswith("_check.png"):
        return import_file(src, "skip", None, [])
    if rel.startswith("paint/terrain/") and name.endswith(".webp"):
        meta = json.load(open(os.path.join(os.path.dirname(src), "terrain_slices.json")))
        gx, gy = meta["grid"]
        return import_file(src, "2d_array_texture", "CompressedTexture2DArray",
                           ARRAY_PARAMS + [("slices/horizontal", gx), ("slices/vertical", gy)])
    if rel.startswith("paint/grade/"):
        return import_file(src, "3d_texture", "CompressedTexture3D",
                           with_params(ARRAY_PARAMS, compress__mode=0, compress__high_quality=False,
                                       mipmaps__generate=False) + [("slices/horizontal", 8), ("slices/vertical", 8)])
    if name == "tv_river_ramp.png":
        return import_file(src, "texture", "CompressedTexture2D",
                           with_params(TEX_PARAMS, compress__mode=0, mipmaps__generate=False))
    if name in ("tv_grass_atlas.png", "tv_herb_atlas.png"):
        return import_file(src, "texture", "CompressedTexture2D",
                           with_params(TEX_PARAMS, compress__high_quality=True, compress__normal_map=2,
                                       process__fix_alpha_border=False))
    if name.endswith("_normal.png"):
        return import_file(src, "texture", "CompressedTexture2D", with_params(TEX_PARAMS, compress__normal_map=1))
    return import_file(src, "texture", "CompressedTexture2D", TEX_PARAMS)


def glb_materials(src):
    import struct
    b = open(src, "rb").read()
    n = struct.unpack_from("<I", b, 12)[0]
    return [m.get("name") for m in json.loads(b[20:20 + n]).get("materials", []) if m.get("name")]


def scene_import(src, mat_dir, planned):
    subs = []
    for name in sorted(set(glb_materials(src))) if mat_dir else []:
        tres = os.path.join(mat_dir, name + ".tres")
        if not (os.path.exists(tres) or tres in planned):
            raise SystemExit("no material %s for %s" % (name, src))
        subs.append('"%s": {\n"use_external/enabled": true,\n"use_external/fallback_path": "%s",\n'
                    '"use_external/path": "%s"\n}' % (name, res(tres), res(tres)))
    body = "{}" if not subs else "{\n\"materials\": {\n" + ",\n".join(subs) + "\n}\n}"
    lod1 = os.path.basename(src).endswith("_lod1.glb")
    return import_file(src, "scene", "PackedScene", with_params(SCENE_PARAMS, meshes__generate_lods=not lod1), body)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def village_material(key, m):
    tex = m["texture"]
    if m.get("cloth"):
        return "\n".join([
            '[gd_resource type="ShaderMaterial" load_steps=3 format=3]', "",
            '[ext_resource type="Shader" path="res://shaders/thuyvan/tv_cloth.gdshader" id="1_sh"]',
            '[ext_resource type="Texture2D" path="%s" id="2_tex"]' % tex, "",
            "[resource]", 'resource_name = "%s"' % key, 'shader = ExtResource("1_sh")',
            'shader_parameter/albedo_tex = ExtResource("2_tex")',
            "shader_parameter/rough = %s" % val(float(m["roughness"])),
            "shader_parameter/spec = %s" % val(float(m["specular"])),
            # the long rope flags and banners billow less than a loose rag
            "shader_parameter/wave_amp = %s" % ("0.08" if key in ("tvv_flags",) else "0.12"),
        ]) + "\n"
    lines = ['[gd_resource type="StandardMaterial3D" load_steps=2 format=3]', "",
             '[ext_resource type="Texture2D" path="%s" id="1_tex"]' % tex, "",
             "[resource]", 'resource_name = "%s"' % key,
             "diffuse_mode = 2",                      # DIFFUSE_LAMBERT_WRAP
             "vertex_color_use_as_albedo = true",     # COLOR_0 RGB: baked AO x top light, linear (not sRGB)
             'albedo_texture = ExtResource("1_tex")',
             "metallic_specular = %s" % val(float(m["specular"])),
             "roughness = %s" % val(float(m["roughness"])),
             "texture_filter = 5"]                    # linear, mipmaps, anisotropic
    if m.get("double_sided"):
        lines.append("cull_mode = 2")
    if m.get("emission"):
        r, g, b = hexrgb(m["emission"])
        # lantern paper: off by day; a direction's dusk lighting raises the energy (style guide 5.2)
        lines += ["emission_enabled = true", "emission = Color(%.4f, %.4f, %.4f, 1)" % (r, g, b),
                  "emission_energy_multiplier = 0.0", 'emission_texture = ExtResource("1_tex")',
                  "emission_operator = 1"]   # multiply: the paper's own strokes glow
    return "\n".join(lines) + "\n"


def foliage_material(species, info, atlas):
    return "\n".join([
        '[gd_resource type="ShaderMaterial" load_steps=4 format=3]', "",
        '[ext_resource type="Shader" path="res://shaders/thuyvan/tv_foliage.gdshader" id="1_sh"]',
        '[ext_resource type="Texture2D" path="%s" id="2_atlas"]' % atlas,
        '[ext_resource type="Texture2D" path="%s" id="3_bark"]' % info["bark"], "",
        "[resource]", 'resource_name = "%s"' % species, 'shader = ExtResource("1_sh")',
        'shader_parameter/leaf_atlas = ExtResource("2_atlas")',
        'shader_parameter/bark_tex = ExtResource("3_bark")',
        # ferns and shrubs bend more for their size than trees
        "shader_parameter/sway = %s" % ("0.05" if species in ("tv_fern", "tv_shrub", "tv_banana") else "0.012"),
    ]) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    out = {}
    man = json.load(open(os.path.join(TV, "village", "manifest.json")))
    for key, m in sorted(man["materials"].items()):
        out[os.path.join(TV, "village", "materials", key + ".tres")] = village_material(key, m)
    veg = json.load(open(os.path.join(TV, "vegetation", "vegetation.json")))
    for sp, info in sorted(veg["species"].items()):
        out[os.path.join(TV, "vegetation", "materials", sp + ".tres")] = foliage_material(sp, info, veg["atlas"])
    for src in sorted(glob.glob(os.path.join(TV, "**", "*"), recursive=True)):
        if src.endswith((".png", ".webp")):
            p, txt = texture_import(src)
            out[p] = txt
    for src in sorted(glob.glob(os.path.join(TV, "**", "*.glb"), recursive=True)):
        kit = os.path.relpath(src, TV).split(os.sep)[0]
        mat_dir = os.path.join(TV, kit, "materials") if kit in ("rock", "village") else None
        p, txt = scene_import(src, mat_dir, out)
        out[p] = txt
    changed = []
    for p, txt in sorted(out.items()):
        old = open(p, encoding="utf-8").read() if os.path.exists(p) else None
        if old == txt or (old is not None and p.endswith(".import") and _same_params(old, txt)):
            continue
        changed.append(p)
        if not a.check:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, "w", encoding="utf-8").write(txt)
    for p in changed:
        print(("WOULD WRITE " if a.check else "WROTE ") + os.path.relpath(p, REPO))
    print("TV_IMPORT %d files, %d %s" % (len(out), len(changed), "differ" if a.check else "written"))
    sys.exit(1 if a.check and changed else 0)


def _same_params(old, new):
    """An imported file keeps Godot's [remap]/[deps] lines; it matches when importer, uid and params agree."""
    def key(s):
        imp = re.search(r'^importer="([^"]+)"', s, re.M)
        params = s.split("[params]", 1)[1].strip() if "[params]" in s else ""
        return (imp.group(1) if imp else None, params)
    return key(old) == key(new)


if __name__ == "__main__":
    main()
