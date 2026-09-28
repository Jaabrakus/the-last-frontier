"""Fort props from Poly Haven, reduced for the game (look-dev spec 8.1; package D).

Blender 5.2 background script, deterministic and re-runnable:

  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      -P tools/environment/structures/decimate_props.py

Reads assets/polyhaven/models/<id>/<id>_2k.gltf (read-only), decimates to the triangle budget
(collapse, keeping UVs), resizes the textures to 1K (diffuse JPEG q90, normal/ARM PNG) and writes
assets/environment/structures/props/<id>_lod0.glb with the textures embedded. The glTF material
keeps the Poly Haven maps (baseColor, normal, occlusion+roughness+metal packed).
"""
import os
import sys

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC = os.path.join(ROOT, "assets", "polyhaven", "models")
OUT = os.path.join(ROOT, "assets", "environment", "structures", "props")
PROPS = {                     # id: triangle budget
    "stone_fire_pit": 2800,
    "wooden_axe": 1800,
    "hatchet": 1500,
}
TEX_SIZE = 1024


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def process(pid, budget):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, pid, f"{pid}_2k.gltf"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    before = sum(tri_count(o) for o in meshes)
    for o in meshes:
        n = tri_count(o)
        ratio = min(1.0, budget * (n / max(before, 1)) / max(n, 1))
        if ratio < 1.0:
            m = o.modifiers.new("decimate", "DECIMATE")
            m.decimate_type = "COLLAPSE"
            m.ratio = ratio
            m.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = o
            o.select_set(True)
            bpy.ops.object.modifier_apply(modifier=m.name)
    after = sum(tri_count(o) for o in meshes)
    # 1K textures.
    for img in bpy.data.images:
        if img.size[0] > TEX_SIZE:
            img.scale(TEX_SIZE, TEX_SIZE)
        is_color = img.colorspace_settings.name.lower().startswith("srgb")
        img.file_format = "JPEG" if is_color else "PNG"
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{pid}_lod0.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_image_format="AUTO",
                              export_jpeg_quality=90, export_yup=True, export_apply=True)
    print(f"PROP {pid}: {before} -> {after} triangles, textures {TEX_SIZE}px, wrote {path}")


for pid, budget in PROPS.items():
    process(pid, budget)
print("PROPS DONE")
