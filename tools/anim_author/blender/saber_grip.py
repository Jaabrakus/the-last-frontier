"""Our own hammer grip on the saber (user 2026-10-01: "we will need to blend our own pose"; the reference: a sword held in a fist,
the four fingers round the grip in a row, the thumb over the index and middle fingers, the index finger against the guard, the
grip slanting across the palm from the base of the index finger to the heel of the hand, the wrist straight).

Built on Actor_B's own rig (assets/character/actor_b_body.glb) with the saber (assets/weapons/saber.glb):
  1. the saber's grip laid across the right palm on that slant (its blade out past the thumb, its edge and knuckle bow
     toward the backs of the fingers), the index finger at the guard
  2. every finger curled joint by joint until it closes on the grip (each joint turned about its own bend axis until the
     next joint lies on the grip's surface: the finger's own thickness off it)
  3. the thumb closed over the index and middle fingers
  4. close renders (--renders DIR), and the pose written as a one-frame action with the saber on the wrist bone
     (--out GLB): Godot reads the hand's bones and the saber's place from it.

Run headless:
  Blender -b --factory-startup --python tools/anim_author/blender/saber_grip.py -- \
      [--out assets/character/grip_saber.glb] [--renders DIR]
"""

import argparse
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BODY = os.path.join(PROJECT, "assets", "character", "body", "body.glb")     # the game's body v4 (fingers of its own)
SABER = os.path.join(PROJECT, "assets", "weapons", "saber.glb")

GRIP_R = 0.0135          # the saber's grip (saber.py: the fluted brass grip)
FINGER_HALF = 0.0085     # half a finger's thickness: how far a phalanx's middle stays off the grip's surface
SLANT_DEG = 32.0         # the grip's slant from the knuckles' line toward the heel of the hand
FINGERS = {"index": ["a", "b", "c"], "middle": ["a", "b", "c"], "ring": ["a", "b", "c"], "pinky": ["b", "c", "d"]}


def world(arm, pb, tail=False):
    return arm.matrix_world @ (pb.tail if tail else pb.head)


def dist_to_axis(p, c, a):
    v = p - c
    return (v - a * v.dot(a)).length


def bend(arm, pb, axis_local, angle):
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = Quaternion(axis_local, angle)
    bpy.context.view_layer.update()


def bend_world(arm, pb, axis_w, angle):
    """The joint turned by `angle` about the world axis `axis_w` (through the joint), from its rest turn: the axis taken into the
    frame its rotation acts in (the bone's own frame with no turn of its own)."""
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = Quaternion()
    bpy.context.view_layer.update()
    m = (arm.matrix_world @ pb.matrix).to_3x3().normalized()
    ax = (m.inverted() @ axis_w).normalized()
    pb.rotation_quaternion = Quaternion(ax, angle)
    bpy.context.view_layer.update()


def curl_finger(arm, names, c, a, n, across):
    """A finger closed the way a fist closes: each joint from the knuckle out turned about the knuckles' line (the hinge every
    finger joint shares), the way that takes its tip toward the palm, in small steps until the joint after it (or the tip)
    lies on the grip's surface, a finger's half-thickness off it. (The bones' own X is not the hinge on this rig: turning
    about it bent the fingers sideways and they never closed.)"""
    s = None
    for i, nm in enumerate(names):
        pb = arm.pose.bones[nm]
        nxt = names[i + 1] if i + 1 < len(names) else None
        def tip():
            return world(arm, arm.pose.bones[nxt]) if nxt else world(arm, pb, tail=True)
        bend_world(arm, pb, across, 0.0)
        t0 = tip()
        if s is None:
            # (the way a finger folds, taken at its knuckle: every joint of it folds the same way about the same line)
            bend_world(arm, pb, across, math.radians(10))
            s = 1.0 if (tip() - t0).dot(n) > 0.0 else -1.0
        want = GRIP_R + FINGER_HALF
        ang = 0.0
        last = dist_to_axis(t0, c, a)
        while ang < math.radians(110):
            ang += math.radians(2.0)
            bend_world(arm, pb, across, s * ang)
            d = dist_to_axis(tip(), c, a)
            if d <= want:
                break
            last = d
        print("GRIP %-10s %5.1f deg  tip %.4f m off the axis" % (nm, s * math.degrees(ang), dist_to_axis(tip(), c, a)))


def lift_arm(arm):
    """For the renders only: the right arm out from the side and the forearm forward, so the hand is clear of the thigh (the
    exported pose is the hand's alone: the fingers and the saber on the wrist). Each joint turned about the axis of its own that
    does what is wanted, found by trying the three."""
    pb = arm.pose.bones
    hip = world(arm, pb["pelvis"]) if "pelvis" in pb else Vector((0, 0, 1.0))
    def try_turn(bone, deg, score):
        best = None
        for ax in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
            for s in (1, -1):
                bend(arm, pb[bone], ax, s * math.radians(deg))
                v = score()
                if best is None or v > best[0]:
                    best = (v, ax, s)
        bend(arm, pb[bone], best[1], best[2] * math.radians(deg))
    try_turn("r_shoulder", 35, lambda: abs(world(arm, pb["r_wrist"]).x - hip.x))
    try_turn("r_elbow", 70, lambda: -world(arm, pb["r_wrist"]).y)


def close_thumb(arm, n):
    """The thumb over the index and middle fingers (the reference's hammer grip): its base turned about two of its axes and its
    two joints bent, searched together for the tip nearest the outside of the middle finger's middle joint."""
    pb = arm.pose.bones
    target = world(arm, pb["r_middleb"]).lerp(world(arm, pb["r_indexb"]), 0.5) - n * 0.012
    def tip():
        return world(arm, pb["r_thumbc"], tail=True)
    best = (1e9, Quaternion(), 0.0, 0.0)
    for ax in range(-60, 61, 10):
        for az in range(-60, 61, 10):
            q = Quaternion(Vector((1, 0, 0)), math.radians(ax)) @ Quaternion(Vector((0, 0, 1)), math.radians(az))
            pb["r_thumba"].rotation_mode = "QUATERNION"
            pb["r_thumba"].rotation_quaternion = q
            for b_deg in range(-60, 61, 15):
                bend(arm, pb["r_thumbb"], Vector((1, 0, 0)), math.radians(b_deg))
                d = (tip() - target).length
                if d < best[0]:
                    best = (d, q, b_deg, 0.0)
    pb["r_thumba"].rotation_quaternion = best[1]
    bend(arm, pb["r_thumbb"], Vector((1, 0, 0)), math.radians(best[2]))
    bc = (1e9, 0)
    for c_deg in range(-70, 71, 5):
        bend(arm, pb["r_thumbc"], Vector((1, 0, 0)), math.radians(c_deg))
        d = (tip() - target).length
        if d < bc[0]:
            bc = (d, c_deg)
    bend(arm, pb["r_thumbc"], Vector((1, 0, 0)), math.radians(bc[1]))
    print("GRIP thumb   tip %.3f m from its place over the fingers" % bc[0])


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(PROJECT, "assets", "character", "grip_saber.glb"))
    ap.add_argument("--renders", default=None)
    args = ap.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=BODY)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name in ("Gear", "Hat", "Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=SABER)
    saber = bpy.data.objects.get("Saber")
    for o in list(bpy.data.objects):
        if o.name.startswith("Scabbard") or o.name in ("Throat", "FrogStud", "ChapeEnd"):
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    pb = arm.pose.bones
    lift_arm(arm)
    # the palm's frame from the hand's own joints
    wrist = world(arm, pb["r_wrist"])
    k_index = world(arm, pb["r_indexa"])
    k_pinky = world(arm, pb["r_pinkyb"])
    k_mid = world(arm, pb["r_middlea"])
    across = (k_index - k_pinky).normalized()                  # the knuckles' line, toward the thumb
    out = (k_mid - wrist).normalized()                         # along the hand, toward the fingers
    n = across.cross(out).normalized()                         # the palm's normal (one of the two ways)
    # the palm is the side the fingers already curl toward at rest (the middle finger's tip off the plane of its knuckles)
    if n.dot(world(arm, pb["r_middlec"], tail=True) - k_mid) < 0.0:
        n = -n
    # the grip: slanting across the palm from the index's base toward the heel, its middle a grip's radius and the palm's
    # flesh off the palm, between the knuckles and the wrist; the blade out past the thumb
    a = (across * math.cos(math.radians(SLANT_DEG)) + out * math.sin(math.radians(SLANT_DEG))).normalized()
    a = (a - n * a.dot(n)).normalized()
    knuckles = (k_index + k_pinky) * 0.5
    c = knuckles.lerp(wrist, 0.32) + n * (GRIP_R + 0.012)
    # the saber: model -Z (blade) along a, model +Y (edge, knuckle bow) away from the palm (round over the fingers' backs)
    zb = -a
    yb = (-n - zb * (-n).dot(zb)).normalized()   # (the knuckle bow round the outside of the fingers, away from the palm)
    xb = yb.cross(zb).normalized()
    # (Blender holds the model Z-up: the glTF import turned it; its own axes in Blender are the model's (x, -z, y))
    m_godot = Matrix((xb, yb, zb)).transposed()                 # columns: the model's x, y, z in world
    conv = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))           # Blender object axes -> the model's Godot axes
    rot = (m_godot @ conv).to_4x4()
    # the guard against the index finger: slide the grip so its front (model z -0.040) is just past the index knuckle
    along_idx = (k_index - c).dot(a)
    c = c + a * (along_idx - 0.018)
    saber.matrix_world = Matrix.Translation(c) @ rot
    bpy.context.view_layer.update()
    for f, js in FINGERS.items():
        curl_finger(arm, ["r_%s%s" % (f, j) for j in js], c, a, n, across)
    close_thumb(arm, n)
    # the saber rides on the wrist bone (its place relative to the hand: what the game needs)
    mw = saber.matrix_world.copy()
    saber.parent = arm
    saber.parent_type = "BONE"
    saber.parent_bone = "r_wrist"
    bpy.context.view_layer.update()
    saber.matrix_world = mw
    if args.renders:
        render(args.renders, arm, c, a, n)
    export(args.out, arm, saber)


def render(out_dir, arm, c, a, n):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1200, 800
    world_ = bpy.data.worlds.new("w")
    world_.use_nodes = True
    world_.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.40, 0.45, 1)
    sc.world = world_
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    sc.collection.objects.link(cam)
    sc.camera = cam
    skin = bpy.data.materials.new("Skin")
    skin.use_nodes = True
    bsdf = skin.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.80, 0.56, 0.44, 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name in ("Body", "Face"):
            o.data.materials.clear()
            o.data.materials.append(skin)
    back = -n
    side = a.cross(n).normalized()
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name == "Face":
            o.hide_render = True                                   # (the head is beside the raised hand: out of the shots)
    for name, d in (("back", back * 0.9 + side * 0.25), ("palm", n * 0.9 - side * 0.3 + a * 0.2), ("pinky", -a * 0.7 + back * 0.5 + side * 0.2),
                    ("thumb_side", a * 0.35 + side * 0.8 + back * 0.3)):
        cam.location = c + d.normalized() * 0.5
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "grip_%s.png" % name)
        bpy.ops.render.render(write_still=True)
    print("GRIP renders in", out_dir)


def export(path, arm, saber):
    bpy.ops.object.mode_set(mode="POSE")
    act = bpy.data.actions.new("own-saber-hammer-grip")
    arm.animation_data_create()
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        if pb.name.startswith("r_") and any(k in pb.name for k in ("index", "middle", "ring", "pinky", "thumb")):
            pb.keyframe_insert("rotation_quaternion", frame=1)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    saber.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=True,
                              export_yup=True, export_skins=False)
    print("GRIP exported", path)


if __name__ == "__main__":
    main()
