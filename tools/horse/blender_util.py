"""Blender helpers for the horse generator: meshes from arrays, materials, decimation,
colour attributes and preview renders."""

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = 30
    sc.unit_settings.system = "METRIC"
    return sc


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def mesh_object(name, V, F, mat=None, smooth=True):
    me = bpy.data.meshes.new(name)
    V = np.asarray(V, float)
    F = [list(map(int, f)) for f in F]
    me.from_pydata(V.tolist(), [], F)
    me.validate(clean_customdata=False)
    me.update()
    ob = link(bpy.data.objects.new(name, me))
    if mat is not None:
        me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = smooth
    return ob


def fix_normals(ob, recalc=True):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def apply_modifiers(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = ob.data
    name = old.name
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)
    me.name = name
    me.validate(clean_customdata=False)


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def decimate(ob, target_tris, symmetric=True):
    n = tri_count(ob)
    if n <= target_tris:
        return
    mod = ob.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = target_tris / n
    mod.use_collapse_triangulate = True
    mod.use_symmetry = symmetric
    mod.symmetry_axis = "X"
    apply_modifiers(ob)


def smooth_mesh(ob, factor=0.5, iterations=2):
    mod = ob.modifiers.new("Smooth", "SMOOTH")
    mod.factor = factor
    mod.iterations = iterations
    apply_modifiers(ob)


def verts(ob):
    n = len(ob.data.vertices)
    a = np.zeros(n * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(n, 3)


def set_verts(ob, V):
    ob.data.vertices.foreach_set("co", np.asarray(V, float).ravel())
    ob.data.update()


def set_point_colors(ob, rgb_srgb, name="Color"):
    """Per-vertex colour attribute (FLOAT_COLOR, linear values from sRGB input)."""
    me = ob.data
    lin = np.where(rgb_srgb <= 0.04045, rgb_srgb / 12.92, ((rgb_srgb + 0.055) / 1.055) ** 2.4)
    if name in me.color_attributes:
        me.color_attributes.remove(me.color_attributes[name])
    ca = me.color_attributes.new(name, "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([lin, np.ones((len(lin), 1))], 1)
    ca.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = ca
    try:
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    except Exception:
        pass


def srgb(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def material(name, hexcol, rough=0.7, metal=0.0, vertex_color=False, sheen=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    rgb = srgb(hexcol)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF") if nt else None
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if vertex_color:
            # glTF exporter: base colour factor x COLOR_0 when a Color Attribute node feeds it
            attr = nt.nodes.new("ShaderNodeVertexColor")
            attr.layer_name = "Color"
            nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    m.diffuse_color = (*rgb, 1.0)
    m.roughness = rough
    m.metallic = metal
    return m


# ---------------------------------------------------------------------------
# Previews
# ---------------------------------------------------------------------------
def _look_at(cam, target):
    d = Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render_views(out_dir, prefix, center=(0, -0.3, 0.9), dist=4.2, views=None, res=(900, 640), lens=50):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    w = sc.world
    try:
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.58, 0.62, 1)
        w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    except Exception:
        w.color = (0.55, 0.58, 0.62)
    if "PreviewSun" not in bpy.data.objects:
        sun = bpy.data.lights.new("PreviewSun", "SUN")
        sun.energy = 3.5
        so = link(bpy.data.objects.new("PreviewSun", sun))
        so.rotation_euler = (math.radians(50), 0, math.radians(35))
        fill = bpy.data.lights.new("PreviewFill", "SUN")
        fill.energy = 1.0
        fo = link(bpy.data.objects.new("PreviewFill", fill))
        fo.rotation_euler = (math.radians(70), 0, math.radians(210))
        gm = bpy.data.meshes.new("PreviewGround")
        s = 6.0
        gm.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
        g = link(bpy.data.objects.new("PreviewGround", gm))
        g.data.materials.append(material("preview_ground", "#6f7466", 0.9))
    cam_data = bpy.data.cameras.get("PreviewCam") or bpy.data.cameras.new("PreviewCam")
    cam_data.lens = lens
    cam = bpy.data.objects.get("PreviewCam") or link(bpy.data.objects.new("PreviewCam", cam_data))
    sc.camera = cam
    views = views or {"side": (1, 0, 0.12), "front34": (0.75, -0.75, 0.25), "back34": (-0.7, 0.7, 0.3),
                      "front": (0, -1, 0.1), "top": (0.15, 0.1, 1.0)}
    paths = []
    for name, d in views.items():
        dv = Vector(d).normalized()
        cam.location = Vector(center) + dv * dist
        _look_at(cam, center)
        p = os.path.join(out_dir, "%s_%s.png" % (prefix, name))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    return paths
