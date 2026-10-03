"""Our own Form casts (user 2026-10-02: "if we equip full metal alchemist type spells and animations that would be great"; the
Sway's fifth art, Form, the stone-shapers' circle-work: SwayCaster, FormCast): three clips keyed here and IK-solved on Actor_B's
rig in Blender, from the game's relaxed stand (actor_b-p-relax-idle at 0: data/anim_author/forage_idle_pose.json, as the forage
grab), our own keys only (no reference motion):
  form_clap_press   the hands come up and clap together at the chest, then the body sinks into a deep squat and both palms are
                    pressed flat to the ground in front of the feet (held there in the game while the circle draws: its end)
  form_release      from that press: the palms push down (the shoulders shove over them), lift off, and the body stands
  form_press_wall   the clap, then both palms flat on an upright in front at chest height (held while the circle draws: hold_s),
                    a shove of the palms into it, and back to the stand (mend on a wall or a post)
  sway_push_two     (the Sway v2's practised cast, every move: docs/main_story.md 11.10) a short wind-up, both open palms drawn
                    back to the chest, the elbows down and back, the weight a little back (held there in the game while the
                    ring fills: hold_s); then the push: both palms driven forward from the chest, the arms straight, the chest
                    and the weight over them (push_s), a beat held, and back to the stand (back_s on)
  sway_push_one     (the expert's cast) the same with the LEFT palm alone, the chest coiling the left shoulder back for the
                    wind-up and turning it through into the push; the right arm is left the stand's (the game plays it with
                    ToolPose "reach_l": the right hand keeps a pistol, a tomahawk or a saber)
The keys are the body's (the root's drop, the hips', the chest's and the head's pitch, the clavicles' reach) and each palm's
place and facing (named hand facings: the clap's, the press's, the wall's); the arms reach them by two-bone IK (the elbow toward a
pole), the legs keep the feet planted where they stood (two-bone IK, the knees out over the toes, the feet level), the fingers
straighten. The rig's joints are solved as the traversal moves are (rigkit's forward kinematics and IK on the glb's skeleton in
the game's frame: +X the character's left, +Y up, +Z forward), and baked to the bones' local rotations as Godot has them, with
the root's position, for tools/anim_author/install_form.gd.

  Blender -b --factory-startup --python tools/anim_author/blender/form_clips.py -- --out <form.json> [--blend <scene.blend>]
      [--clips sway_push_two,sway_push_one]
--blend keeps an Actor_B rig keyed with the clips baked (an action each) to open in Blender; --clips bakes only those (the
installer merges them into the library, the others kept).
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
import rigkit  # noqa: E402
import rigmap  # noqa: E402

SK = rigkit.SK
IDLE = os.path.join(PROJECT, "data", "anim_author", "forage_idle_pose.json")
FPS = 30

SPINE = [("spinea", 0.35), ("spineb", 0.3), ("spinec", 0.2), ("spined", 0.15)]
NECK = [("neck", 0.5), ("heada", 0.3), ("headb", 0.2)]
ARM = ["clavicle", "shoulder", "elbow", "wrist"]
LEG = ["upper_leg", "knee", "ankle"]
DIGITS = [("thumb", "bc"), ("index", "abc"), ("middle", "abc"), ("ring", "abc"), ("pinky", "bcd")]

## The hands' facings (the right hand's; the left's mirrored): the fingers' way and the palm's (game frame). The clap: the
## fingers up and forward, a little in, the palms toward each other; the press: the fingers forward and a little out, the
## palms flat down; the wall: the fingers up, the palms forward onto it. "idle": the hand as the stand has it.
FACING_R = {
    "clap": ((0.22, 0.58, 0.78), (1.0, 0.0, 0.0)),
    "press": ((-0.32, 0.0, 0.95), (0.0, -1.0, 0.0)),
    "wall": ((-0.22, 0.95, 0.1), (0.0, 0.0, 1.0)),
    "push": ((-0.16, 0.96, 0.22), (0.0, 0.05, 1.0)),
}

CLAP_R = (-0.022, 1.16, 0.33)
PRESS_R = (-0.17, 0.032, 0.37)
WALL_R = (-0.19, 1.08, 0.42)
## The push (the Sway v2): the palms drawn back to the chest (the wind-up), then driven out in front of the shoulders.
WIND_R = (-0.17, 1.17, 0.17)
PUSH_R = (-0.15, 1.27, 0.56)
## The one-handed push: the left palm only (the game frame: +X the character's left).
WIND_L1 = (0.17, 1.18, 0.13)
PUSH_L1 = (0.09, 1.29, 0.6)

## Each clip's keys: (frame, value), eased between (smoothstep). root: the root's offset from the stand (m); hips, chest,
## head: pitch (deg, + forward; the hips' the whole body's bow from the root, the legs then planted again; the chest's spread
## over the spine, the head's over the neck, each on top of the one below);
## clav: the clavicles forward and down (deg); arm: the arms' IK and facing weight (0: the stand's arm); hand: the right palm's place
## ("idle": where the stand has it; the left mirrored); facing: the hands' facing; pole: the right elbow's way from the
## shoulder (the left mirrored); fingers: straightened (0..1); twist: the chest's yaw (deg, + turns the left shoulder back),
## spread over the spine like the chest's pitch. A side's own keys (arm_l, hand_l, facing_l, pole_l; or _r) replace the
## mirrored right's for that side (their places in the game frame as they are, not mirrored).
CLIPS = {
    "form_clap_press": {
        "length": 24, "meta": {"clap_s": 7 / FPS, "press_s": 20 / FPS},
        "root": [(0, (0, 0, 0)), (7, (0, -0.03, 0.0)), (10, (0, -0.045, 0.0)), (20, (0, -0.56, -0.04)), (24, (0, -0.57, -0.04))],
        "hips": [(0, 0), (7, 2), (10, 3), (20, 32), (24, 33)],
        "chest": [(0, 0), (7, 6), (10, 7), (20, 50), (24, 52)],
        "head": [(0, 0), (7, -2), (10, -3), (20, -64), (24, -68)],
        "clav": [(0, (0, 0)), (7, (0, 0)), (10, (0, 0)), (20, (14, 12)), (24, (15, 13))],
        "arm": [(0, 0.0), (5, 1.0), (24, 1.0)],
        "hand": [(0, "idle"), (5, (-0.06, 1.12, 0.30)), (7, CLAP_R), (9, (-0.024, 1.155, 0.33)), (11, (-0.03, 1.10, 0.34)),
                 (16, (-0.11, 0.52, 0.45)), (20, PRESS_R), (24, (PRESS_R[0], PRESS_R[1] - 0.004, PRESS_R[2]))],
        "facing": [(0, "idle"), (5, "clap"), (11, "clap"), (18, "press"), (24, "press")],
        "pole": [(0, (-0.7, -0.5, -0.3)), (11, (-0.7, -0.5, -0.3)), (20, (-0.8, 0.0, -0.5)), (24, (-0.8, 0.0, -0.5))],
        "fingers": [(0, 0.0), (6, 0.85), (24, 0.92)],
    },
    "form_release": {
        "length": 20, "meta": {"push_s": 3 / FPS, "up_s": 6 / FPS},
        "root": [(0, (0, -0.57, -0.04)), (3, (0, -0.595, -0.025)), (6, (0, -0.55, -0.04)), (20, (0, 0, 0))],
        "hips": [(0, 33), (3, 35), (6, 31), (20, 0)],
        "chest": [(0, 52), (3, 58), (6, 49), (20, 0)],
        "head": [(0, -68), (3, -72), (6, -62), (20, 0)],
        "clav": [(0, (15, 13)), (3, (19, 15)), (6, (12, 10)), (20, (0, 0))],
        "arm": [(0, 1.0), (8, 1.0), (18, 0.0), (20, 0.0)],
        "hand": [(0, (PRESS_R[0], PRESS_R[1] - 0.004, PRESS_R[2])), (3, (PRESS_R[0], PRESS_R[1] - 0.008, PRESS_R[2] + 0.01)),
                 (6, (-0.17, 0.11, 0.40)), (12, (-0.21, 0.48, 0.22)), (20, "idle")],
        "facing": [(0, "press"), (6, "press"), (14, "idle"), (20, "idle")],
        "pole": [(0, (-0.8, 0.0, -0.5)), (6, (-0.8, 0.0, -0.5)), (14, (-0.7, -0.6, -0.2)), (20, (-0.7, -0.6, -0.2))],
        "fingers": [(0, 0.92), (6, 0.9), (20, 0.0)],
    },
    "form_press_wall": {
        "length": 34, "meta": {"clap_s": 7 / FPS, "hold_s": 17 / FPS, "push_s": 20 / FPS},
        "root": [(0, (0, 0, 0)), (7, (0, -0.02, 0.0)), (17, (0, -0.05, 0.04)), (20, (0, -0.06, 0.07)), (24, (0, -0.05, 0.045)),
                 (34, (0, 0, 0))],
        "hips": [(0, 0), (7, 2), (17, 4), (20, 6), (24, 4), (34, 0)],
        "chest": [(0, 0), (7, 5), (17, 10), (20, 15), (24, 9), (34, 0)],
        "head": [(0, 0), (7, -2), (17, -6), (20, -9), (24, -5), (34, 0)],
        "clav": [(0, (0, 0)), (7, (0, 0)), (17, (9, 0)), (20, (13, 2)), (24, (8, 0)), (34, (0, 0))],
        "arm": [(0, 0.0), (5, 1.0), (28, 1.0), (34, 0.0)],
        "hand": [(0, "idle"), (5, (-0.06, 1.12, 0.30)), (7, CLAP_R), (9, (-0.026, 1.155, 0.33)), (17, WALL_R),
                 (20, (WALL_R[0], WALL_R[1] - 0.01, WALL_R[2] + 0.045)), (24, (WALL_R[0], WALL_R[1], WALL_R[2] + 0.01)),
                 (34, "idle")],
        "facing": [(0, "idle"), (5, "clap"), (10, "clap"), (15, "wall"), (26, "wall"), (34, "idle")],
        "pole": [(0, (-0.7, -0.5, -0.3)), (10, (-0.7, -0.5, -0.3)), (17, (-0.6, -0.75, -0.2)), (34, (-0.6, -0.75, -0.2))],
        "fingers": [(0, 0.0), (6, 0.85), (28, 0.9), (34, 0.0)],
    },
    "sway_push_two": {
        "length": 24, "meta": {"hold_s": 7 / FPS, "push_s": 9 / FPS, "back_s": 13 / FPS, "up_s": 13 / FPS},
        "root": [(0, (0, 0, 0)), (7, (0, -0.025, -0.03)), (10, (0, -0.04, 0.06)), (13, (0, -0.035, 0.05)), (24, (0, 0, 0))],
        "hips": [(0, 0), (7, -1), (10, 5), (13, 4), (24, 0)],
        "chest": [(0, 0), (7, -5), (10, 9), (13, 8), (24, 0)],
        "head": [(0, 0), (7, 3), (10, -5), (13, -4), (24, 0)],
        "clav": [(0, (0, 0)), (7, (-6, 4)), (10, (12, -2)), (13, (11, -2)), (24, (0, 0))],
        "arm": [(0, 0.0), (5, 1.0), (16, 1.0), (24, 0.0)],
        "hand": [(0, "idle"), (5, (-0.19, 1.08, 0.12)), (7, WIND_R), (8, (-0.165, 1.19, 0.25)), (10, PUSH_R),
                 (13, (PUSH_R[0], PUSH_R[1] - 0.01, PUSH_R[2] - 0.02)), (18, (-0.2, 1.05, 0.25)), (24, "idle")],
        "facing": [(0, "idle"), (5, "push"), (16, "push"), (24, "idle")],
        "pole": [(0, (-0.6, -0.75, -0.2)), (7, (-0.55, -0.6, -0.6)), (10, (-0.75, -0.65, 0.0)), (24, (-0.6, -0.75, -0.2))],
        "fingers": [(0, 0.0), (5, 0.9), (16, 0.9), (24, 0.0)],
    },
    "sway_push_one": {
        "length": 24, "meta": {"hold_s": 7 / FPS, "push_s": 9 / FPS, "back_s": 13 / FPS, "up_s": 13 / FPS, "side": 0.0},
        "root": [(0, (0, 0, 0)), (7, (0, -0.02, -0.025)), (10, (0, -0.035, 0.05)), (13, (0, -0.03, 0.04)), (24, (0, 0, 0))],
        "hips": [(0, 0), (7, -1), (10, 4), (13, 3), (24, 0)],
        "chest": [(0, 0), (7, -4), (10, 7), (13, 6), (24, 0)],
        "twist": [(0, 0), (7, 13), (10, -17), (13, -15), (24, 0)],
        "head": [(0, 0), (7, 2), (10, -4), (13, -3), (24, 0)],
        "clav": [(0, (0, 0)), (24, (0, 0))],
        "clav_l": [(0, (0, 0)), (7, (-8, 4)), (10, (14, -2)), (13, (13, -2)), (24, (0, 0))],
        "arm": [(0, 0.0), (24, 0.0)],
        "arm_l": [(0, 0.0), (5, 1.0), (16, 1.0), (24, 0.0)],
        "hand": [(0, "idle"), (24, "idle")],
        "hand_l": [(0, "idle"), (5, (0.2, 1.08, 0.08)), (7, WIND_L1), (8, (0.15, 1.2, 0.24)), (10, PUSH_L1),
                   (13, (PUSH_L1[0], PUSH_L1[1] - 0.01, PUSH_L1[2] - 0.02)), (18, (0.21, 1.05, 0.22)), (24, "idle")],
        "facing": [(0, "idle"), (24, "idle")],
        "facing_l": [(0, "idle"), (5, "push"), (16, "push"), (24, "idle")],
        "pole": [(0, (-0.6, -0.75, -0.2)), (24, (-0.6, -0.75, -0.2))],
        "pole_l": [(0, (0.6, -0.75, -0.2)), (7, (0.55, -0.6, -0.6)), (10, (0.75, -0.65, 0.0)), (24, (0.6, -0.75, -0.2))],
        "fingers": [(0, 0.0), (24, 0.0)],
        "fingers_l": [(0, 0.0), (5, 0.9), (16, 0.9), (24, 0.0)],
    },
}


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def seg(keys, f):
    if f <= keys[0][0]:
        return keys[0][1], keys[0][1], 0.0
    for a, b in zip(keys, keys[1:]):
        if f <= b[0]:
            return a[1], b[1], smooth((f - a[0]) / (b[0] - a[0]))
    return keys[-1][1], keys[-1][1], 0.0


def num(keys, f):
    a, b, u = seg(keys, f)
    if isinstance(a, tuple):
        return Vector(a).lerp(Vector(b), u)
    return a + (b - a) * u


def mirror(v):
    return Vector((-v[0], v[1], v[2]))


def q_of(v):
    return Quaternion((v[3], v[0], v[1], v[2]))


# ---------------------------------------------------------------- the stand
def load_stand():
    d = json.load(open(IDLE))["frames"][0]
    rots = {nm: q_of(d["rot"][nm]) if nm in d["rot"] else SK.rest_q[nm].copy() for nm in SK.names}
    root = Vector(d["loc"]["root"])
    return rots, root


ROT0, ROOT0 = load_stand()
P0, G0 = SK.fk(ROT0, ROOT0)


def hand_frame(side):
    """The hand's own axes in its wrist's frame: the fingers' way (to the palm joint) and the palm's (toward the body's middle in
    the stand: the hands hang palms in)."""
    w = side + "_wrist"
    inv = G0[w].inverted()
    fing = (P0[side + "_palm"] - P0[w]).normalized()
    across = (P0[side + "_indexa"] - P0[side + "_pinkyb"]).normalized()
    n = fing.cross(across).normalized()
    medial = Vector((-1.0 if P0[w].x > 0 else 1.0, 0.0, 0.0))
    if n.dot(medial) < 0:
        n = -n
    return inv @ fing, inv @ n


HAND_LOCAL = {s: hand_frame(s) for s in "lr"}


def basis(f, n):
    f = Vector(f).normalized()
    n = (Vector(n) - f * Vector(n).dot(f)).normalized()
    return Matrix((f, n, f.cross(n))).transposed()


def facing_q(side, name):
    """The wrist's global rotation for a named facing ("idle": the stand's)."""
    if name == "idle":
        return G0[side + "_wrist"].copy()
    f, n = FACING_R[name]
    if side == "l":
        f, n = mirror(f), mirror(n)
    fl, nl = HAND_LOCAL[side]
    m = basis(f, n) @ basis(fl, nl).inverted()
    return m.to_quaternion().normalized()


def facing_at(keys, side, f):
    a, b, u = seg(keys, f)
    qa, qb = facing_q(side, a), facing_q(side, b)
    if qa.dot(qb) < 0:
        qb = -qb
    return qa.slerp(qb, u)


# ---------------------------------------------------------------- one frame
def turn(rots, root, bone, axis, deg):
    """Bone `bone` turned by `deg` about a world `axis` (its children with it)."""
    P, G = SK.fk(rots, root)
    q = Quaternion(axis, math.radians(deg)) @ G[bone]
    par = SK.parent[bone]
    rots[bone] = G[par].inverted() @ q


def turn_root(rots, deg):
    """The whole body bowed forward from the root (the hips' hinge; the legs are planted again after)."""
    rots["root"] = Quaternion(Vector((1, 0, 0)), math.radians(deg)) @ rots["root"]


def set_global(rots, root, bone, q):
    P, G = SK.fk(rots, root)
    rots[bone] = G[SK.parent[bone]].inverted() @ q


def side_keys(clip, key, s):
    """A side's own keys (key_l / key_r), else the clip's (the right's, mirrored for the left), and whether they are its own."""
    own = clip.get(key + "_" + s)
    return (own, True) if own is not None else (clip[key], False)


def pose(clip, f):
    rots = {k: v.copy() for k, v in ROT0.items()}
    root = ROOT0 + num(clip["root"], f)
    X = Vector((1, 0, 0))
    Y = Vector((0, 1, 0))
    turn_root(rots, num(clip["hips"], f))
    for nm, share in SPINE:
        turn(rots, root, nm, X, num(clip["chest"], f) * share)
    if "twist" in clip:
        for nm, share in SPINE:
            turn(rots, root, nm, Y, num(clip["twist"], f) * share)
    for nm, share in NECK:
        turn(rots, root, nm, X, num(clip["head"], f) * share)
    if "twist" in clip:
        for nm, share in NECK:
            turn(rots, root, nm, Y, -num(clip["twist"], f) * share * 0.8)     # (the head kept on the aim)
    Z = Vector((0, 0, 1))
    for s, sg in (("l", -1.0), ("r", 1.0)):
        ck, _own = side_keys(clip, "clav", s)
        cl = num(ck, f)
        turn(rots, root, s + "_clavicle", Y, sg * cl.x)
        turn(rots, root, s + "_clavicle", Z, sg * cl.y)
    # the legs: the feet kept where the stand has them, level; the knees out over the toes as the body sinks
    drop = max(0.0, min(1.0, -num(clip["root"], f).y / 0.55))
    for s in "lr":
        P, G = SK.fk(rots, root)
        hip = P[s + "_upper_leg"]
        idle_dir = (P0[s + "_knee"] - P0[s + "_upper_leg"])
        out = Vector((0.45 if s == "l" else -0.45, 0.0, 1.0)).normalized()
        pole = hip + idle_dir.normalized().lerp(out, smooth(drop * 1.6)).normalized()
        rigkit.ik2(rots, root, s + "_upper_leg", s + "_knee", s + "_ankle", P0[s + "_ankle"], pole)
        set_global(rots, root, s + "_ankle", G0[s + "_ankle"])
    # the arms: each palm to its place, facing its way (IK weighted in from the stand's arm)
    for s in "lr":
        ak, _ = side_keys(clip, "arm", s)
        w = num(ak, f)
        hk, h_own = side_keys(clip, "hand", s)
        a, b, u = seg(hk, f)
        fk_, _ = side_keys(clip, "facing", s)
        pk, p_own = side_keys(clip, "pole", s)
        gk, _ = side_keys(clip, "fingers", s)
        before = {nm: rots[s + "_" + nm].copy() for nm in ARM}
        gw = facing_at(fk_, s, f)
        P, G = SK.fk(rots, root)
        idle_palm = P[s + "_palm"]

        def place(v):
            if isinstance(v, str):
                return idle_palm
            return Vector(v) if (s == "r" or h_own) else mirror(v)
        palm_t = place(a).lerp(place(b), u)
        wrist_t = palm_t - gw @ SK.rest_t[s + "_palm"]
        pole_v = num(pk, f)
        if s == "l" and not p_own:
            pole_v = mirror(pole_v)
        if w > 0.0:
            for _ in range(2):
                P, G = SK.fk(rots, root)
                rigkit.ik2(rots, root, s + "_shoulder", s + "_elbow", s + "_wrist", wrist_t, P[s + "_shoulder"] + pole_v)
            set_global(rots, root, s + "_wrist", gw)
            for nm in ARM:
                q0, q1 = before[nm], rots[s + "_" + nm]
                if q0.dot(q1) < 0:
                    q1 = -q1
                rots[s + "_" + nm] = q0.slerp(q1, w)
        st = num(gk, f)
        for dg, js in DIGITS:
            for j in js:
                nm = "%s_%s%s" % (s, dg, j)
                if nm in rots:
                    q0, q1 = rots[nm], SK.rest_q[nm]
                    if q0.dot(q1) < 0:
                        q1 = -q1
                    rots[nm] = q0.slerp(q1, st)
    return rots, root


def keyed():
    out = ["root", "pelvis"] + [n for n, _ in SPINE] + [n for n, _ in NECK]
    for s in "lr":
        out += ["%s_%s" % (s, b) for b in ARM] + ["%s_%s" % (s, b) for b in LEG]
        out += ["%s_%s%s" % (s, dg, j) for dg, js in DIGITS for j in js if "%s_%s%s" % (s, dg, j) in SK.rest_q]
    return out


def bake(clip):
    frames, roots, report = [], [], []
    names = keyed()
    for f in range(clip["length"] + 1):
        rigkit.MISS.clear()
        rots, root = pose(clip, f)
        frames.append({nm: [rots[nm].x, rots[nm].y, rots[nm].z, rots[nm].w] for nm in names})
        roots.append([root.x, root.y, root.z])
        P, G = SK.fk(rots, root)
        report.append((f, [round(x, 3) for x in P["r_palm"]], [round(x, 3) for x in P["l_palm"]],
                       round(P["pelvis"].y, 3), [round(x, 3) for x in P["r_ankle"]], round(max([d for _, d in rigkit.MISS] or [0.0]), 3)))
    return frames, roots, report


# ---------------------------------------------------------------- the .blend to open
def keep_blend(path, baked):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=rigmap.GLB, bone_heuristic="FORTUNE")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rm = rigmap.RigMap(arm)
    scn = bpy.context.scene
    scn.render.fps = FPS
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    arm.animation_data_create()
    C = Matrix.Rotation(math.pi / 2, 3, "X")
    for name, (frames, roots) in baked.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for fi, rots in enumerate(frames):
            for bn, q in rots.items():
                pb = arm.pose.bones.get(bn)
                if pb is None or bn not in rm.B:
                    continue
                pb.rotation_quaternion = rm.to_basis(bn, q)
                pb.keyframe_insert("rotation_quaternion", frame=fi)
            rb = arm.pose.bones.get("root")
            if rb is not None:
                h = C @ Vector(roots[fi])
                rb.location = rb.bone.matrix_local.to_3x3().inverted() @ (h - rb.bone.head_local)
                rb.keyframe_insert("location", frame=fi)
    arm.animation_data.action = bpy.data.actions[next(iter(baked))]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(path))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--clips", default="")
    a = ap.parse_args(argv)
    only = [c for c in a.clips.split(",") if c]
    out = {"fps": FPS, "clips": {}, "about": "tools/anim_author/blender/form_clips.py: our own Form casts (the clap, the press to the "
           "ground or an upright, the release), keyed and IK-solved on Actor_B's rig in Blender"}
    baked = {}
    for s_ in "lr":
        print("FORM stand %s_shoulder %s  %s_palm %s" % (s_, [round(x, 3) for x in P0[s_ + "_shoulder"]], s_,
                                                          [round(x, 3) for x in P0[s_ + "_palm"]]))
    for name, clip in CLIPS.items():
        if only and name not in only:
            continue
        frames, roots, report = bake(clip)
        out["clips"][name] = {"frames": frames, "root": roots, "meta": clip["meta"]}
        baked[name] = (frames, roots)
        print("FORM %s: %d frames" % (name, len(frames)))
        for r in report:
            print("   f%02d  r_palm %s  l_palm %s  pelvis %.3f  r_ankle %s  miss %.3f" % r)
    json.dump(out, open(a.out, "w"))
    print("FORM baked -> %s" % a.out)
    if a.blend:
        keep_blend(a.blend, baked)
        print("FORM blend -> %s" % a.blend)


if __name__ == "__main__":
    main()
