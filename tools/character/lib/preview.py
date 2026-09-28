"""Workbench preview renders and contact sheets (Blender), and posed previews of game
clips with the helper bones driven like the game.

Split out of tools/character/build_body.py (lib v1).
"""

import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

from .helpers import drive_helpers, helper_bones
from .remesh import link
from .rig import LIBS, clear_action, load_actions, set_action
from .sdf import log

# Clips used for the posed previews: (label, action, library, frame or None=middle)
PREVIEW_CLIPS = [
    ("run", "actor_b-p-run-fw", "Actor_B_016.blend", 6),
    ("sprint", "actor_b-p-sprint-fw", "Actor_B_016.blend", 12),
    ("rifle aim", "actor_b-p-rifle-idle-aim", "Actor_B_016.blend", 1),
    ("crouch", "actor_b-p-crouch-idle", "Actor_B_012.blend", 1),
    ("bow aim", "actor_b-p-bow-aim-idle", "Actor_B_011.blend", 1),
    ("idle", "actor_b-p-stealth-idle", "Actor_B_017.blend", 1),
]


# ===========================================================================
# Preview rendering
# ===========================================================================
def setup_preview_scene():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_object_outline = False
    sh.show_specular_highlight = True
    sc.display.render_aa = "8"
    sc.render.film_transparent = False
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.color = (0.55, 0.57, 0.6)
    sc.render.image_settings.file_format = "PNG"
    cam = bpy.data.cameras.new("PreviewCam")
    cam.type = "ORTHO"
    co = link(bpy.data.objects.new("PreviewCam", cam))
    sc.camera = co
    return co


def render_view(co, path, view, center=(0, 0, 0.82), scale=1.8, res=(700, 1100)):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res
    co.data.ortho_scale = scale
    c = Vector(center)
    d = 6.0
    rot = {"front": (math.pi / 2, 0, 0), "side": (math.pi / 2, 0, math.pi / 2),
           "back": (math.pi / 2, 0, math.pi), "rside": (math.pi / 2, 0, -math.pi / 2),
           "front34": (math.radians(80), 0, math.radians(35))}[view]
    co.rotation_euler = rot
    fwd = co.rotation_euler.to_matrix() @ Vector((0, 0, -1))
    co.location = c - fwd * d
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def contact_sheet(paths, out, cols, labels=None):
    imgs = []
    for p in paths:
        im = bpy.data.images.load(p)
        a = np.empty(im.size[0] * im.size[1] * 4, np.float32)
        im.pixels.foreach_get(a)
        imgs.append(a.reshape(im.size[1], im.size[0], 4))
        bpy.data.images.remove(im)
    h = max(i.shape[0] for i in imgs)
    w = max(i.shape[1] for i in imgs)
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.ones((rows * h, cols * w, 4), np.float32)
    for n, im in enumerate(imgs):
        r, c = divmod(n, cols)
        y0 = (rows - 1 - r) * h      # blender images are bottom-up
        sheet[y0:y0 + im.shape[0], c * w:c * w + im.shape[1]] = im
    img = bpy.data.images.new("sheet", cols * w, rows * h, alpha=True)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return out


def posed_previews(src_rig, bind_rig, base, outdir, co, G, prefix="pose", clips=None):
    """Render game clips: the bind rig copies the source rig bone by bone in
    world space, so the mesh deforms by G_pose * G_nulladd^-1 (as in Godot).
    Unkeyed channels start from their null-add values (the planned rest).
    The helper bones are driven like the game does (drive_helpers)."""
    helpers = set(helper_bones())
    for pb in bind_rig.pose.bones:
        if pb.name in helpers:
            continue
        c = pb.constraints.new("COPY_TRANSFORMS")
        c.target, c.subtarget = src_rig, pb.name
        c.owner_space = c.target_space = "WORLD"
    libs = {}
    clips = PREVIEW_CLIPS if clips is None else clips
    for _, act, lib, _ in clips:
        libs.setdefault(lib, []).append(act)
    for lib, names in libs.items():
        load_actions(os.path.join(LIBS, lib), names)
    shots = []
    for label, act, lib, frame in clips:
        if act not in bpy.data.actions:
            log("preview clip missing: %s" % act)
            continue
        set_action(src_rig, act, frame, base)
        Gp = {}
        for pb in src_rig.pose.bones:
            loc, rot, _ = (src_rig.matrix_world @ pb.matrix).decompose()
            Gp[pb.name] = Matrix.LocRotScale(loc, rot, None)
        for n, m in drive_helpers(Gp, G).items():
            bind_rig.pose.bones[n].matrix = m
        bpy.context.view_layer.update()
        pel = (src_rig.matrix_world @ src_rig.pose.bones["pelvis"].matrix).translation
        c = (pel.x, pel.y, 0.80 + (pel.z - 0.896) * 0.5)
        tag = label.replace(" ", "_")
        shots.append(render_view(co, os.path.join(outdir, "%s_%s_34.png" % (prefix, tag)), "front34", center=c, scale=1.9, res=(560, 900)))
        shots.append(render_view(co, os.path.join(outdir, "%s_%s_side.png" % (prefix, tag)), "side", center=c, scale=1.9, res=(560, 900)))
    clear_action(src_rig)
    for pb in bind_rig.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return shots
