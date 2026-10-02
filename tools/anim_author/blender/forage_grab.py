"""Our own foraging grab (user 2026-10-02: "i just want it to be arms, where they press the button and there arm reaches out and
gets something", "it keeps the idea of being mobile"; then the look of a quick one-handed side pickup the user pointed to as a
visual reference, a YouTube clip at 0:20: the torso leaning and bending toward the reaching side, the arm out and down beside
the body nearly straight, the head on the hand, then straight again): the torso leans and bends to the reaching side, the arm
goes out and down beside the body, the fingers close on a handful, the hand comes back to the hip (into the pack) as the body
straightens. Our own keys: nothing taken from the reference but the idea of the move. The legs and the other arm stay the
game's (walking, standing, aiming); the clip goes over the spine, the head and the one arm (ToolPose "reach_r" / "reach_l").
Authored here in Blender on Actor_B's own rig (assets/character/actor_b_body.glb), from the game's relaxed stand
(actor_b-p-relax-idle at 0: data/anim_author/forage_idle_pose.json, dumped by tools/anim_author/blender/dump_pose.gd), for
each arm: the forearm reaches an empty keyed on the path (Blender's IK, the elbow toward a pole), the fingers keyed curls.
The keyed rig is baked to the arm's bone rotations (visual pose) as Godot's (rigmap.RigMap.to_godot) for
tools/anim_author/install_forage.gd.

  Blender -b --factory-startup --python tools/anim_author/blender/forage_grab.py -- --out <forage.json> [--blend <scene.blend>]
--blend keeps the authored scene (both arms' IK rigs and keys) to open in Blender.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import rigmap  # noqa: E402

IDLE = os.path.join(PROJECT, "data", "anim_author", "forage_idle_pose.json")
FPS = 30
LENGTH = 26                         # frames: 0.87 s
GRAB_F = 12                         # the fingers closed on it (ForagePick counts the grab here)

## The right arm's wrist path in the body's frame as the game has it (+X the character's left, +Y up, +Z forward, m; the stand's
## pelvis at 0.89, the shoulder at 1.28): out and down beside the body a little ahead (in reach of the shoulder the lean and the
## bend carry out there), back up to the hip. The left arm's is its mirror.
PATH_R = [(0, None), (9, (-0.47, 0.84, 0.24)), (12, (-0.46, 0.86, 0.22)), (17, (-0.32, 0.93, 0.12)), (20, (-0.25, 0.93, 0.07)),
          (LENGTH, None)]
## The torso toward the reach (deg; spread over the spine as SPINE): the lean forward, the bend toward the reaching side, the turn
## toward it; the head's nod down onto the hand and turn to it (over NECK). Keyed with the reach, back to the stand at the end.
BODY = [(0, 0.0), (9, 1.0), (12, 1.0), (18, 0.45), (LENGTH, 0.0)]
LEAN, BEND, TURN = 16.0, 17.0, 14.0
NOD, LOOK = 22.0, 18.0
SPINE = [("spinea", 0.30), ("spineb", 0.30), ("spinec", 0.25), ("spined", 0.15)]
NECK = [("neck", 0.5), ("heada", 0.3), ("headb", 0.2)]
POLE_R = (-0.70, 0.95, -0.35)
## The fingers: open as the hand reaches (a little spread back), closed on the handful, open into the pack (deg per joint).
CLOSE = {"thumbb": 25.0, "thumbc": 20.0, "indexa": 45.0, "indexb": 50.0, "indexc": 30.0, "middlea": 45.0, "middleb": 50.0,
         "middlec": 30.0, "ringa": 45.0, "ringb": 50.0, "ringc": 30.0, "pinkyb": 45.0, "pinkyc": 45.0, "pinkyd": 25.0}
FINGERS = [(0, 0.0), (7, -0.2), (12, 1.0), (18, 1.0), (21, -0.1), (LENGTH, 0.0)]
## The influence of the IK: none on the stand at both ends (the clip starts and ends exactly on it).
REACH = [(0, 0.0), (5, 1.0), (20, 1.0), (LENGTH, 0.0)]
ARM = ["clavicle", "shoulder", "elbow", "wrist"]
TORSO = [n for n, _ in SPINE] + [n for n, _ in NECK]
DIGITS = [("thumb", "abc"), ("index", "abc"), ("middle", "abc"), ("ring", "abc"), ("pinky", "abcd")]

C = Matrix.Rotation(math.pi / 2, 4, "X")


def go(p):
    """A point in the game's body frame -> Blender world."""
    return (C @ Vector(p).to_4d()).to_3d()


def back(p):
    return tuple((C.inverted() @ Vector(p).to_4d()).to_3d())


def mirror(p):
    return (-p[0], p[1], p[2])


def keyed(side):
    return TORSO + ["%s_%s" % (side, b) for b in ARM] + ["%s_%s%s" % (side, f, j) for f, js in DIGITS for j in js]


def world_turn(arm, pb, axis, deg):
    """Turns pose bone `pb` by `deg` about a world `axis` through its head (its children go with it)."""
    bpy.context.view_layer.update()
    m = arm.matrix_world @ pb.matrix
    head = m.to_translation()
    pb.matrix = arm.matrix_world.inverted() @ Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) \
        @ Matrix.Translation(-head) @ m


def torso_keys(arm, rest, side, action):
    """The spine's and the head's keys toward the reaching `side` (BODY's share at each key). Blender: the body faces -Y, +X its
    left; a turn about +X brings the top forward, about +Y bends it to the left, about +Z turns it to the left."""
    s = 1.0 if side == "l" else -1.0
    pbs = arm.pose.bones
    for f, u in BODY:
        for n in TORSO:
            pbs[n].rotation_quaternion = rest[n]
        for n, share in SPINE:
            world_turn(arm, pbs[n], Vector((1, 0, 0)), LEAN * share * u)
            world_turn(arm, pbs[n], Vector((0, 1, 0)), s * BEND * share * u)
            world_turn(arm, pbs[n], Vector((0, 0, 1)), s * TURN * share * u)
        for n, share in NECK:
            world_turn(arm, pbs[n], Vector((1, 0, 0)), NOD * share * u)
            world_turn(arm, pbs[n], Vector((0, 0, 1)), s * LOOK * share * u)
        for n in TORSO:
            pbs[n].keyframe_insert("rotation_quaternion", frame=f, group=side)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=rigmap.GLB, bone_heuristic="FORTUNE")   # bone tails on the next joint: Blender's IK
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name == "Icosphere":
            bpy.data.objects.remove(o, do_unlink=True)
    rm = rigmap.RigMap(arm)
    scn = bpy.context.scene
    scn.render.fps = FPS
    scn.frame_start, scn.frame_end = 0, LENGTH
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for name, q in json.load(open(IDLE))["frames"][0]["rot"].items():
        if name in arm.pose.bones and name in rm.B:
            arm.pose.bones[name].rotation_quaternion = rm.to_basis(name, q)
    bpy.context.view_layer.update()
    rest = {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}
    arm.animation_data_create()
    return arm, rm, rest


def rig_side(arm, rest, side):
    """The IK rig and keys for one arm (its own empties; the other arm's IK muted while this one is baked)."""
    pb = arm.pose.bones
    stand = back(arm.matrix_world @ pb[side + "_wrist"].head)
    tgt = bpy.data.objects.new("IK_%s_hand" % side, None)
    pole = bpy.data.objects.new("Pole_%s_elbow" % side, None)
    for e in (tgt, pole):
        e.empty_display_size = 0.04
        bpy.context.scene.collection.objects.link(e)
    pole.location = go(POLE_R if side == "r" else mirror(POLE_R))
    for f, p in PATH_R:
        at = stand if p is None else (p if side == "r" else mirror(p))
        tgt.location = go(at)
        tgt.keyframe_insert("location", frame=f)
    c = pb[side + "_elbow"].constraints.new("IK")
    c.name = "IK_" + side
    c.target, c.pole_target, c.pole_angle = tgt, pole, math.radians(-90)
    c.chain_count, c.use_tail = 2, True
    for f, v in REACH:
        c.influence = v
        c.keyframe_insert("influence", frame=f)
    for f, u in FINGERS:
        for d, deg in CLOSE.items():
            n = "%s_%s" % (side, d)
            if n in pb:
                pb[n].rotation_quaternion = rest[n] @ Quaternion((1, 0, 0), math.radians(deg * u))
                pb[n].keyframe_insert("rotation_quaternion", frame=f)
    return c


def bake(arm, rm, side, others):
    for c in others:
        c.mute = True
    scn = bpy.context.scene
    frames = []
    for f in range(0, LENGTH + 1):
        scn.frame_set(f)
        bpy.context.view_layer.update()
        rots = {}
        for name in keyed(side):
            pb = arm.pose.bones.get(name)
            if pb is None or name not in rm.B:
                continue
            m = pb.matrix if pb.parent is None else pb.parent.matrix.inverted() @ pb.matrix
            lr = pb.bone.matrix_local if pb.parent is None else pb.parent.bone.matrix_local.inverted() @ pb.bone.matrix_local
            rots[name] = rm.to_godot(name, (lr.inverted() @ m).to_quaternion())
        frames.append(rots)
    for c in others:
        c.mute = False
    return frames


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default=None)
    a = ap.parse_args(argv)
    arm, rm, rest = build()
    # each arm's grab its own action (they key the same spine): forage_grab_r, forage_grab_l
    acts, ik = {}, {}
    for s in "rl":
        acts[s] = bpy.data.actions.new("forage_grab_" + s)
        acts[s].use_fake_user = True
        arm.animation_data.action = acts[s]
        ik[s] = rig_side(arm, rest, s)
        torso_keys(arm, rest, s, acts[s])
        for n in TORSO:
            arm.pose.bones[n].rotation_quaternion = rest[n]
    clips = {}
    for s in "rl":
        arm.animation_data.action = acts[s]
        clips[s] = bake(arm, rm, s, [ik[o] for o in "rl" if o != s])
    arm.animation_data.action = acts["r"]
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a.blend))
    json.dump({"fps": FPS, "grab_s": GRAB_F / FPS, "clips": clips,
               "about": "tools/anim_author/blender/forage_grab.py: our own reach and grab to one side, keyed and IK-solved in Blender"},
              open(a.out, "w"))
    print("FORAGE baked %d frames a side -> %s" % (LENGTH + 1, a.out))


if __name__ == "__main__":
    main()
