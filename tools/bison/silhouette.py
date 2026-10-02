"""The generated bison's side and front silhouettes against the low-poly bison it is fitted to
(assets/wildlife/bison/bison.glb, Poly by Google's bison on the stag rig: user 2026-10-02, "keep the dimensions of the
low poly one and add the generator to it"), in an orthographic camera at the same scale, one PNG per model and view:

  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/bison/silhouette.py -- OUT_DIR [h]

OUT_DIR/{old,new}_{side,front}.png: black on white, 1 px = 4 mm, the ground at the bottom edge, the animal's middle
(its bounding box) in the middle. tools/bison/fit_report.py compares them.
"""

import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "horse"))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True

import anatomy as A           # noqa: E402  (the bison's)
import blender_util as U      # noqa: E402
import sdf                    # noqa: E402

OLD = os.path.join(HERE, "..", "..", "assets", "wildlife", "bison", "bison.glb")
PX = 0.004                    # m per pixel
W, H = 1000, 560              # 4.0 m x 2.24 m


def black():
    m = bpy.data.materials.new("sil")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (0, 0, 0, 1)
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs[0])
    return m


def setup():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.view_settings.view_transform = "Standard"
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = W * PX
    sc.camera = cam
    return cam


def shoot(cam, objs, out, name, mid_y):
    sc = bpy.context.scene
    for ob in sc.objects:
        if ob.type == "MESH":
            ob.hide_render = ob not in objs
    # side: from +x looking at -x; the bottom edge on the ground
    cam.location = (10.0, mid_y, H * PX / 2)
    cam.rotation_euler = (np.pi / 2, 0, np.pi / 2)
    sc.render.filepath = os.path.join(out, name + "_side.png")
    bpy.ops.render.render(write_still=True)
    # front: from -y (the animal faces -y)
    cam.location = (0.0, -10.0, H * PX / 2)
    cam.rotation_euler = (np.pi / 2, 0, 0)
    sc.render.filepath = os.path.join(out, name + "_front.png")
    bpy.ops.render.render(write_still=True)


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    out = a[0]
    h = float(a[1]) if len(a) > 1 else 0.012
    U.reset_scene()
    cam = setup()
    mat = black()
    bpy.ops.import_scene.gltf(filepath=OLD)
    old = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("BisonPlains")]
    for o in bpy.context.scene.objects:
        if o.type == "ARMATURE":
            o.data.pose_position = "REST"
    for o in old:
        o.data.materials.clear()
        o.data.materials.append(mat)
    new = []
    for nm, node, hh in (("Bison", A.horse_body(), h), ("Horns", A.horns(), 0.006)):
        V, Q = sdf.polygonize(node, hh)
        new.append(U.mesh_object(nm, V, Q, mat))
    bpy.context.view_layer.update()

    def mid(objs):
        ys = [(o.matrix_world @ v.co).y for o in objs for v in o.data.vertices]
        return 0.5 * (min(ys) + max(ys))
    shoot(cam, old, out, "old", mid(old))
    shoot(cam, new, out, "new", mid(new))


main()
