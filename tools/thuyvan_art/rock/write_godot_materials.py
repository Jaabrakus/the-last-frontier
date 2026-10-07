"""Thủy Vân ROCK kit: write the Godot 4.7 materials for the kit's material keys (plain python3; deterministic).

    python3 tools/thuyvan_art/rock/write_godot_materials.py [--kit assets/thuyvan/rock]

Reads <kit>/rock_kit.json ("materials": key -> texture, tile_m, tint) and writes <kit>/materials/<key>.tres:
    painted keys (a texture):  ShaderMaterial on shaders/thuyvan/tv_rock.gdshader (triplanar paint x vertex
                               colour, moss by vertex colour A on up faces); ashlar and the white stones in object space
    plain keys (no texture):   StandardMaterial3D, albedo = the key's palette tint x vertex colour, Lambert wrap,
                               roughness 0.9, specular 0.15 (cloth: both sides, for the bolt plates' rags)
The kit's GLB surfaces carry these keys as their material names, so Godot's import can point each name at its .tres
(Advanced Import Settings > Materials > Use External), or a dressing script can swap by resource_name.
"""

import argparse
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
RES = "res://assets/thuyvan/rock/"
SHADER = "res://shaders/thuyvan/tv_rock.gdshader"   # the Thủy Vân painted-rock shader (was the kit's painted_rock.gdshader)

# key -> shader overrides (keys not listed use the defaults: world space, moss on)
PAINTED = {
    "rock_karst": dict(moss_amount=1.0),
    "rock_boulder": dict(moss_amount=1.0, object_space=True),
    "rock_pale": dict(moss_amount=0.8),
    "stone_white": dict(moss_amount=0.0, object_space=True, macro_var=0.04),
    "ashlar": dict(moss_amount=0.35, object_space=True, blend_sharp=10.0),
    "moss": dict(moss_amount=0.0, rough=0.98, spec=0.1),
}


def hexrgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").rstrip(".") if v != int(v) else "%.1f" % v
    return str(v)


def shader_material(key, info):
    ov = dict(PAINTED.get(key, {}))
    tex = info["texture"]
    lines = ['[gd_resource type="ShaderMaterial" load_steps=4 format=3]', "",
             '[ext_resource type="Shader" path="%s" id="1_sh"]' % SHADER,
             '[ext_resource type="Texture2D" path="%stextures/%s" id="2_rock"]' % (RES, tex),
             '[ext_resource type="Texture2D" path="%stextures/moss_cap.png" id="3_moss"]' % RES, "",
             "[resource]", 'resource_name = "%s"' % key, 'shader = ExtResource("1_sh")',
             'shader_parameter/rock_tex = ExtResource("2_rock")',
             "shader_parameter/tile_m = %s" % fmt(float(info["tile_m"])),
             'shader_parameter/moss_tex = ExtResource("3_moss")',
             "shader_parameter/moss_tile_m = 4.0"]
    for k in ("moss_amount", "object_space", "blend_sharp", "macro_var", "rough", "spec"):
        if k in ov:
            lines.append("shader_parameter/%s = %s" % (k, fmt(ov[k])))
    return "\n".join(lines) + "\n"


def standard_material(key, info):
    r, g, b = hexrgb(info["tint"])          # albedo_color is sRGB in a .tres, as the palette
    cloth = key.startswith("cloth_")
    lines = ['[gd_resource type="StandardMaterial3D" format=3]', "", "[resource]", 'resource_name = "%s"' % key,
             "diffuse_mode = 2", "vertex_color_use_as_albedo = true",  # DIFFUSE_LAMBERT_WRAP (1 is plain Lambert)
             # the kit's vertex colour is linear occlusion; Godot multiplies it in as is (vertex_color_is_srgb false)
             "albedo_color = Color(%.4f, %.4f, %.4f, 1)" % (r, g, b),
             "roughness = %s" % ("0.95" if cloth else "0.9"), "metallic_specular = 0.15"]
    if cloth:
        lines.append("cull_mode = 2")
    if key == "iron":
        lines[-1] = "metallic_specular = 0.25"
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kit", default=os.path.join(REPO, "assets", "thuyvan", "rock"))
    a = ap.parse_args()
    meta = json.load(open(os.path.join(a.kit, "rock_kit.json")))
    out = os.path.join(a.kit, "materials")
    os.makedirs(out, exist_ok=True)
    for key, info in sorted(meta["materials"].items()):
        txt = shader_material(key, info) if info.get("texture") else standard_material(key, info)
        open(os.path.join(out, key + ".tres"), "w").write(txt)
        print("ROCK_MAT", key, "shader" if info.get("texture") else "standard")


if __name__ == "__main__":
    main()
