"""Boxing for fire: the first fighting style (Tidebreak's fighting-style layer, docs/fighting_styles_design.md; the owner,
2026-10-08: each element keeps the same moves and a style makes variations of them; "okay lets do it spin up a task for
boxing fire"; "we need to watch videos on martial art styles and create animations for them"). Every move keeps what it DOES;
only how the body performs it changes: the stance, the rhythm, the footwork, the arcs, the strings, the guard.

Derived from tools/anim_author/blender/bend_clips.py and from nothing else: key poses typed into the CLIPS table below, posed
by bend_clips.py's own solver (pose(): two-bone IK, rigkit.ik2, on the skeleton of Actor_B's own rig,
assets/character/actor_b_body.glb, read from this checkout) in Blender and baked by its bake() to the bones' local rotations
as Godot has them, with the root's position, for tools/anim_author/install_style.gd. Like bend_clips.py this tool never reads
a library clip, a dumped move (dump_move.gd / dump_pose.gd output) or rigkit.Native / MirrorNative: every clip starts from
the rig's own rest (bind) pose, keyed into the boxing guard below (BOX), and returns to it.

Visual references, watched by Claude in the built-in browser for this task (visual reference only: paused and looked at;
nothing was downloaded, traced, motion-captured or pose-estimated; nothing taken but the idea of each move; the timestamps
used and what each showed are in docs/fighting_styles/boxing_reference.md):
  V1 FightCamp, "Boxing Stance | Beginner Step-By-Step Tutorial" https://www.youtube.com/watch?v=SjLXzCpRS8U
  V2 FightCamp, "How to Punch: Jab & Cross Beginner Boxing Tutorial" https://www.youtube.com/watch?v=YsFK1MMDQgk
  V3 FightCamp, "LEARN BEGINNER BOXING FOOTWORK IN 5 MINUTES | Beginner Boxing" https://www.youtube.com/watch?v=dg2Jp3F30Lw
  V4 Tony Jeffries, "Basics of Boxing - Training for Beginners at Home" https://www.youtube.com/watch?v=kKDHdsVN0b8
The slip, the steps, the uppercut, the overhand and the ground punch's level change were not checked against a video (the
owner: skip it, 2026-10-09); they are keyed from standard boxing mechanics.

The clips (own-style-boxing-<name> in animations_extra/Frontier_Style_Boxing.res; orthodox: the left foot and the left fist
lead; no mirrored twins, since a boxer's stance is not symmetric and a mirror would make him a southpaw). Each keeps what
its fire move does (data/sway/moves.json); the meta `move` and `mode` name it:
  stance             the guard's idle loop: side-on, the left foot ahead, the rear heel up, the knees soft, the fists at the
                     chin and the cheekbone, the elbows on the ribs, the chin down behind the lead shoulder; two bounces a
                     loop on the balls of the feet and a rock front to back (V1, V3)
  jab, cross, hook   the jab string (jab, jab, Pop): the jab with no wind-up, the weight onto the rear leg; the cross off
                     the loaded rear leg, the rear heel pivoting; the lead hook as the Pop, the lead heel pivoting (V2, V4)
  punch              Punch: a straight right stepped in, the lead foot back out after it (V2)
  fireball           the grown Fireball: an overhand right from a deep level change
  lightning          Lightning: the charged straight: wound deep with the cocked fist trembling (the long lock), then a
                     lunging straight right (V2)
  ground_punch       the Kick (the owner's choice, 2026-10-09): dropped into a deep lunge, the right fist driven into the
                     deck, the wave running along the floor from it
  uppercut           the High Kick (the owner's choice): a rising uppercut carried up over the head onto the toes
  flurry             a 1-2 flurry: four short punches, left, right, left, right (V2, V4; no key reaches it yet:
                     Embers alternates the jab and the cross)
  slip               the Parry: the head slipped a head's width off the line, then the counter jab
  step_in, step_back, step_left, step_right   Step: the leading foot first and the other drawn after (never crossed)
The owner's first look (2026-10-09) asked for "Bolder": deeper loads, bigger turns, longer steps and follow-throughs; the
second: "these are okay make sure the hand ik is closed": the fists (BOX_CURL, the thumb's fold below).

Metas (seconds): strike_s the fist lands / the bolt leaves (SwayPose's `struck`), hold_s where the game may hold the pose (the
lock's wind-up; at or before strike_s), back_s where the recovery to the guard begins, antic_s and follow_s the anticipation's
and the follow-through's frames the stills show (tools/anim_author/style_preview.gd); words: hand (the striking limb: r, l,
both), mask, root ("place"), style "boxing", element "fire", move and mode (the fire move and its mode the clip is a
variation of: data/sway/moves.json, data/bending/poses.json), order (the stills' order). Channels as bend_clips.py's (its
docstring): every place in the character's frame (+X the character's left, +Y up, +Z forward, metres), every angle in
degrees; a clip's channels not keyed hold BOX's (the clip's "base").

  Blender -b --factory-startup --python tools/anim_author/blender/style_boxing.py -- --out <boxing.json> [--blend <boxing.blend>]
      [--clips stance,jab] [--glb <actor_b_body.glb>] [--fit] [--angles] [--points] [--quiet]
  (in this project through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bend_clips as bc  # noqa: E402  (the solver and the bake: pose(), bake(), keep_blend(); reads only the rig)
from bend_clips import FACING, FPS, STAND, SK  # noqa: E402

## A boxer's fist (the owner, 2026-10-09: "make sure the hand ik is closed"): the fingers' close at grip 1 (deg about the
## knuckles' line, as bend_clips.CURL) a little past bend_clips' own, tucked into the palm; the thumb left to its fold below.
## Set on bend_clips' table for this bake only (bend_clips.py itself is unchanged).
BOX_CURL = {"index": {"a": 86, "b": 100, "c": 66}, "middle": {"a": 88, "b": 102, "c": 66},
            "ring": {"a": 90, "b": 102, "c": 64}, "pinky": {"b": 94, "c": 100, "d": 60},
            "thumb": {"b": 0, "c": 0}}
bc.CURL.clear()
bc.CURL.update(BOX_CURL)

## The thumb (bend_clips curls it toward the palm's face, which in a boxer's fist points it at the floor): wrapped across the
## outside of the curled index finger instead, by two-bone IK on its own joints (thumba, thumbb, thumbc): its last joint
## carried THUMB_OUT m outside the index finger's middle (between its b and c joints), its knuckle bent out to the thumb's
## side, by the grip (0 as the rig has it, 1 a fist), its tip left lying across the fingers.
THUMB_OUT = 0.01
_bend_pose = bc.pose


def _thumb_fold(rots, root, s, g):
    if g <= 0.0:
        return
    P, _ = SK.fk(rots, root)
    _, n = bc.finger_axes(rots, s)
    across = (P[s + "_indexa"] - P[s + "_middlea"]).normalized()
    base = P[s + "_thumba"]
    closed = (P[s + "_indexb"] + P[s + "_indexc"]) * 0.5 + n * THUMB_OUT
    tgt = P[s + "_thumbc"].lerp(closed, g)
    reach = (P[s + "_thumbb"] - base).length + (P[s + "_thumbc"] - P[s + "_thumbb"]).length - 0.001
    if (tgt - base).length > reach:
        tgt = base + (tgt - base).normalized() * reach
    pole = P[s + "_thumbb"] + across * 0.05 - n * 0.02
    for _ in range(2):
        bc.rigkit.ik2(rots, root, s + "_thumba", s + "_thumbb", s + "_thumbc", tgt, pole)


def _box_pose(clip, f):
    """bend_clips' pose, then each thumb wrapped round its fist by the hand's grip (this bake only; bend_clips.py itself
    is unchanged)."""
    rots, root = _bend_pose(clip, f)
    for s in "lr":
        _thumb_fold(rots, root, s, max(0.0, min(1.0, bc.num(clip, "grip_" + s, f))))
    return rots, root


bc.pose = _box_pose

STYLE = "boxing"
ELEMENT = "fire"
LIBRARY = "res://animations_extra/Frontier_Style_Boxing.res"
GENERATOR = "tools/anim_author/blender/style_boxing.py"

## The boxer's hands (the right hand's; the left's mirrored): the fingers' way (the wrist to the knuckles) and the palm's.
FACING.update({
    "box_guard": ((0.2, 0.9, 0.38), (0.95, -0.05, -0.3)),     # a fist up at the cheek, the knuckles up, the palm in to the face
    "box_hook": ((0.85, 0.05, 0.52), (0.0, -1.0, 0.1)),       # the hook's fist swung across (the left's: to the right), palm down
    "box_cock": ((0.05, 0.95, 0.3), (0.95, 0.0, -0.3)),       # the overhand's fist cocked by the ear, the knuckles up
    "box_over": ((0.2, -0.35, 0.91), (-0.35, -0.9, -0.27)),   # the overhand landing over the top, the knuckles forward and down
})

## The boxing guard (orthodox): side-on (the hips turned 24 to the right, the shoulders 8 more), the left foot ahead pointing
## at the mark and the right foot back and out, turned out 40 with its heel up; the knees soft and the root a little down;
## the chin down behind the raised lead shoulder; the rear fist at the right cheekbone and the lead fist a hand's width in
## front of the face, the elbows down on the ribs (V1: SjLXzCpRS8U 0:40-2:15). BOX, every clip's base and its first and last
## pose, is the stance loop's own first frame (stance_at(0)), so a cast leaves the idle and comes back to it without a jump.
BOX_FOOT_L = (0.13, 0.077, 0.2)
BOX_FOOT_R = (-0.19, 0.077, -0.215)
BOX_FIST_L = (0.05, 1.305, 0.37)
BOX_FIST_R = (-0.115, 1.295, 0.195)
GUARD = {
    "root": (0.0, -0.03, 0.0), "yaw": -24.0, "twist": -8.0, "hips": 5.0, "roll": 0.0, "chest": 7.0, "side": 0.0,
    "head": 8.0, "look": 0.0, "clav_r": (6.0, -4.0), "clav_l": (10.0, -6.0),
    "hand_r": BOX_FIST_R, "hand_l": BOX_FIST_L, "face_r": "box_guard", "face_l": "box_guard",
    "pole_r": (-0.3, -1.0, -0.15), "pole_l": (0.25, -1.0, -0.1), "grip_r": 1.0, "grip_l": 1.0,
    "foot_r": BOX_FOOT_R, "foot_l": BOX_FOOT_L, "fyaw_r": 40.0, "fyaw_l": -4.0, "heel_r": 17.0, "heel_l": 6.0,
    "knee_r": (-0.45, 0.0, 1.0), "knee_l": (0.2, 0.0, 1.0),
}

META = {"mask": "full", "root": "place", "style": STYLE, "element": ELEMENT}


def _s(a, ph=0.0):
    return math.sin(a + ph)


def _c(a, ph=0.0):
    return math.cos(a + ph)


def _add(v, d):
    return tuple(round(x + y, 4) for x, y in zip(v, d))


def _r(v):
    return tuple(round(x, 4) for x in v) if isinstance(v, (tuple, list)) else round(float(v), 3)


## The stance (own-style-boxing-stance, a loop of STANCE_LEN frames) as a function of its phase: two bounces a loop on the
## balls of the feet (sharp at the bottom, soft at the top), the weight rocking forward onto the lead foot and back once a
## loop, the shoulders and the fists riding the bounce a beat late, the lead fist pawing a small circle.
STANCE_LEN = 36


def stance_at(a):
    up = abs(_s(a))                        # 1 up on the balls of the feet, 0 down (two a loop)
    late = 0.5 - 0.5 * _c(2 * a, -0.8)     # the shoulders and the fists a beat after the body
    rock = _s(a)                           # + the weight forward onto the lead foot
    return {k: _r(v) for k, v in {
        "root": (0.0, -0.057 + 0.03 * up, 0.022 * rock),
        "hips": 5.0 - 1.5 * up + 1.5 * rock, "chest": 7.0 + 2.0 * late, "head": 8.0 - 1.2 * late,
        "yaw": -24.0 + 2.0 * rock, "twist": -8.0 - 2.0 * rock,
        "clav_r": (6.0, -4.0 - 2.5 * late), "clav_l": (10.0, -6.0 - 2.5 * late),
        "hand_r": _add(BOX_FIST_R, (0.0, -0.02 * late, 0.0)),
        "hand_l": _add(BOX_FIST_L, (0.022 * _c(a), -0.025 * late + 0.015 * _s(a), 0.025 * _s(a, 0.6))),
        "heel_r": 12.0 + 16.0 * up - 5.0 * rock, "heel_l": 2.0 + 15.0 * up + 4.0 * rock,
    }.items()}


BOX = dict(STAND)
BOX.update(GUARD)
BOX.update(stance_at(0.0))
FR, FL = BOX["foot_r"], BOX["foot_l"]
HR, HL = BOX["hand_r"], BOX["hand_l"]


def clip(length, meta, **ch):
    """A clip on BOX: each keyed channel starts on BOX's value at f0 and ends on it at the last frame unless its keys say
    otherwise; the channels not keyed hold BOX's."""
    c = {"length": length, "meta": dict(META, **meta), "base": BOX}
    for k, keys in ch.items():
        keys = list(keys)
        if keys[0][0] != 0:
            keys.insert(0, (0, BOX[k]))
        if keys[-1][0] != length:
            keys.append((length, BOX[k]))
        c[k] = keys
    return c


def _tremor(keys, f0, f1, amp, step=2, axis=(1.0, 1.0, 0.0)):
    """A held place shaken: keys every `step` frames from f0 to f1 about the place the keys give there, alternating +/- amp
    (the charge's tremble)."""
    out = [k for k in keys if k[0] <= f0]
    base = dict(keys)
    lo = max(fr for fr in base if fr <= f0)
    hi = min(fr for fr in base if fr >= f1)
    for i, fr in enumerate(range(f0 + step, f1, step)):
        u = (fr - lo) / float(hi - lo)
        v = tuple(a + (b - a) * u for a, b in zip(base[lo], base[hi]))
        sg = 1.0 if i % 2 == 0 else -1.0
        out.append((fr, _r(tuple(x + sg * amp * w for x, w in zip(v, axis)))))
    return out + [k for k in keys if k[0] >= f1]


S = 1.0 / FPS

FACING.update({
    "box_ground": ((0.05, -0.95, 0.3), (0.95, 0.05, 0.0)),     # a fist driven down into the deck, the knuckles down, palm in
    "box_upper_low": ((0.0, 0.25, 0.97), (0.0, 0.97, -0.25)),  # the uppercut's start low by the belly, the palm up
})

CLIPS = {
    # ---------------------------------------------------------------- the stance (fire's stance while boxing)
    "stance": dict(bc._loop(STANCE_LEN, stance_at), length=STANCE_LEN, loop=True, base=BOX,
                   meta=dict(META, hand="both", move="stance", mode="stance", order=0)),

    # ---------------------------------------------------------------- the jab string: jab, cross, lead hook (the Pop)
    # the jab (the string's first hit; fire_jab "embers", its first hand): no wind-up but the weight settling onto the rear leg and the lead
    # hand relaxing a touch; the lead fist snapped straight out from the guard, turned over at the end (palm down) with the
    # lead shoulder raised to the chin and the shoulders turned hard on; the rear fist kept at the cheek; the weight onto the
    # rear leg ("ammunition for the cross", V2 5:20); the fist snapped back along its own line past the guard and settled.
    # strike_s: the arm out
    "jab": clip(16, dict(hold_s=2 * S, strike_s=5 * S, back_s=8 * S, antic_s=2 * S, follow_s=8 * S, hand="l",
                         move="fire_jab", mode="embers", order=1, stills="ready (no wind-up):2;strike:5;recoil:8"),
        root=[(2, (0.0, -0.06, -0.012)), (5, (-0.01, -0.064, -0.032)), (7, (-0.01, -0.064, -0.032)), (11, (0.0, -0.055, -0.01))],
        yaw=[(2, -22.0), (5, -31.0), (7, -31.0), (11, -25.0)],
        twist=[(2, -5.0), (5, -24.0), (7, -23.0), (11, -10.0)],
        chest=[(2, 8.0), (5, 10.0), (8, 10.0), (12, 7.5)],
        head=[(2, 8.5), (5, 11.0), (8, 11.0), (12, 8.0)],
        clav_l=[(2, (7.0, -5.0)), (5, (27.0, -16.0)), (7, (26.0, -15.0)), (11, (11.0, -7.0))],
        clav_r=[(5, (4.0, -8.0)), (9, (5.0, -6.0))],
        hand_l=[(2, (0.06, 1.28, 0.35)), (3, (0.045, 1.305, 0.46)), (5, (0.012, 1.333, 0.645)), (6, (0.013, 1.333, 0.644)),
                (8, (0.035, 1.31, 0.45)), (10, (0.05, 1.29, 0.33)), (12, (0.055, 1.295, 0.36))],
        face_l=[(3, "box_guard"), (5, "fist_fwd"), (7, "fist_fwd"), (9, "box_guard")],
        pole_l=[(3, (0.3, -1.0, -0.1)), (5, (0.65, -0.75, 0.0)), (8, (0.4, -1.0, -0.1))],
        hand_r=[(5, (-0.11, 1.302, 0.203)), (9, (-0.113, 1.298, 0.198))],
        heel_r=[(2, 10.0), (5, 4.0), (8, 6.0), (12, 11.0)],
        heel_l=[(2, 4.0), (5, 14.0), (8, 10.0), (12, 4.0)],
    ),
    # the cross (the string's second hit; fire_jab "embers", its alt): loaded deep on the rear leg, then the hips turn first and
    # the shoulders after them, the rear heel pivots right out ("squash the bug"), the weight drives onto the lead leg and
    # the rear fist goes straight out turning over, the lead fist pulled back to the chin; the head forward over the lead
    # knee; the shoulder rolled through a beat; back along the line.  strike_s: the arm out
    "cross": clip(20, dict(hold_s=3 * S, strike_s=6 * S, back_s=10 * S, antic_s=3 * S, follow_s=8 * S, hand="r",
                           move="fire_jab", mode="embers_alt", order=2,
                           stills="loaded on the rear leg:3;strike:6;follow-through:8"),
        root=[(3, (-0.01, -0.068, -0.035)), (6, (0.012, -0.078, 0.08)), (8, (0.012, -0.078, 0.085)), (12, (0.006, -0.062, 0.03)),
              (16, (0.0, -0.054, 0.0))],
        yaw=[(3, -34.0), (4, -24.0), (6, 16.0), (8, 18.0), (11, -6.0), (15, -25.0)],
        twist=[(3, -14.0), (4, -8.0), (6, 22.0), (8, 24.0), (11, 2.0), (15, -9.0)],
        hips=[(3, 5.0), (6, 9.0), (9, 9.0), (14, 5.0)],
        chest=[(3, 7.0), (6, 15.0), (9, 14.0), (14, 7.5)],
        head=[(3, 8.0), (6, 9.0), (10, 9.0)],
        clav_r=[(3, (2.0, -5.0)), (6, (25.0, -10.0)), (8, (26.0, -10.0)), (11, (8.0, -6.0))],
        clav_l=[(6, (0.0, -8.0)), (10, (6.0, -7.0))],
        hand_r=[(3, (-0.12, 1.285, 0.18)), (4, (-0.106, 1.29, 0.288)), (6, (-0.005, 1.333, 0.75)), (7, (-0.005, 1.333, 0.754)),
                (9, (-0.04, 1.326, 0.52)), (12, (-0.11, 1.295, 0.238)), (14, (-0.116, 1.294, 0.193))],
        face_r=[(4, "box_guard"), (6, "fist_fwd"), (8, "fist_fwd"), (12, "box_guard")],
        pole_r=[(4, (-0.35, -1.0, -0.1)), (6, (-0.65, -0.75, 0.0)), (10, (-0.4, -1.0, -0.1))],
        hand_l=[(4, (0.06, 1.295, 0.3)), (6, (0.08, 1.29, 0.21)), (10, (0.08, 1.29, 0.21)), (14, (0.055, 1.3, 0.34))],
        fyaw_r=[(3, 42.0), (6, 0.0), (9, 4.0), (14, 36.0)],
        heel_r=[(3, 8.0), (6, 50.0), (9, 46.0), (14, 15.0)],
        heel_l=[(3, 4.0), (6, 0.0), (10, 0.0), (14, 3.0)],
        knee_r=[(6, (-0.1, 0.0, 1.0)), (10, (-0.2, 0.0, 1.0))],
    ),
    # the lead hook (the Pop; fire_jab "pop"): the weight onto the lead leg, the lead shoulder dipped and a touch open (the
    # load); then the lead heel pivots right out, the hips and the shoulders whip hard to the right and the weight goes back
    # onto the rear leg, the elbow up level with the fist, the forearm flat, the fist swung across the line in front of the
    # face (palm down); the turn carries on well past; back to the guard.  strike_s: the fist on the line
    "hook": clip(24, dict(hold_s=3 * S, strike_s=7 * S, back_s=12 * S, antic_s=3 * S, follow_s=10 * S, hand="l",
                          move="fire_jab", mode="pop", order=3),
        root=[(3, (0.045, -0.075, 0.035)), (5, (0.015, -0.072, 0.015)), (7, (-0.03, -0.068, -0.015)), (10, (-0.035, -0.064, -0.02)),
              (15, (-0.012, -0.055, -0.006))],
        yaw=[(3, -12.0), (5, -32.0), (7, -58.0), (8, -61.0), (10, -64.0), (14, -40.0), (19, -26.0)],
        twist=[(3, 2.0), (5, -14.0), (7, -34.0), (8, -36.0), (10, -37.0), (14, -18.0), (19, -9.0)],
        side=[(3, -10.0), (7, 5.0), (10, 5.0), (15, 0.0)],
        chest=[(3, 8.0), (7, 9.0), (12, 7.2)],
        head=[(3, 9.0), (7, 10.0), (12, 8.0)],
        clav_l=[(3, (2.0, 5.0)), (7, (16.0, -14.0)), (10, (15.0, -13.0)), (14, (9.0, -7.0))],
        hand_l=[(3, (0.15, 1.25, 0.33)), (5, (0.17, 1.285, 0.42)), (7, (-0.05, 1.312, 0.47)), (8, (-0.09, 1.306, 0.46)),
                (10, (-0.16, 1.29, 0.4)), (13, (0.0, 1.28, 0.38)), (16, (0.05, 1.3, 0.36))],
        face_l=[(3, "box_guard"), (5, "box_hook"), (10, "box_hook"), (14, "box_guard")],
        pole_l=[(3, (0.8, -0.5, -0.3)), (5, (1.0, 0.25, -0.2)), (10, (1.0, 0.35, -0.1)), (14, (0.4, -1.0, -0.1))],
        hand_r=[(5, (-0.105, 1.305, 0.203)), (12, (-0.11, 1.3, 0.198))],
        fyaw_l=[(3, -4.0), (5, -22.0), (7, -55.0), (10, -58.0), (15, -14.0)],
        heel_l=[(3, 3.0), (5, 14.0), (7, 30.0), (10, 28.0), (15, 6.0)],
        heel_r=[(3, 18.0), (7, 4.0), (10, 4.0), (15, 12.0)],
        fyaw_r=[(7, 48.0), (12, 44.0)],
    ),

    # ---------------------------------------------------------------- key 1: Punch, the grown Fireball, Lightning
    # Punch (fire_blast "punch"): the straight right that throws fire, stepped in: sunk deep on the rear leg with the lead
    # hand reaching out to measure (held while the lock fills); the lead foot steps a long way in as the hips and the
    # shoulders turn through and the rear fist drives out at full length, the rear heel pivoting; held on the hit, the
    # shoulder rolled through; the fist back along its line and the lead foot stepped back out to the guard.
    # strike_s: the arm out
    "punch": clip(28, dict(hold_s=4 * S, strike_s=8 * S, back_s=15 * S, antic_s=4 * S, follow_s=12 * S, hand="r",
                           move="fire_blast", mode="punch", order=4),
        root=[(4, (-0.015, -0.09, -0.05)), (6, (0.0, -0.08, 0.05)), (8, (0.012, -0.09, 0.17)), (11, (0.012, -0.092, 0.175)),
              (14, (0.012, -0.088, 0.16)), (17, (0.008, -0.075, 0.09)), (21, (0.004, -0.058, 0.02))],
        yaw=[(4, -40.0), (6, -16.0), (8, 18.0), (11, 20.0), (14, 16.0), (19, -14.0), (23, -24.0)],
        twist=[(4, -18.0), (6, -4.0), (8, 22.0), (11, 24.0), (14, 25.0), (19, -2.0)],
        hips=[(4, 6.0), (8, 10.0), (14, 10.0), (19, 6.0)],
        chest=[(4, 8.0), (8, 16.0), (14, 15.0), (19, 8.0)],
        head=[(4, 9.0), (8, 9.0)],
        clav_r=[(4, (0.0, -4.0)), (8, (26.0, -10.0)), (11, (27.0, -10.0)), (14, (22.0, -8.0)), (18, (8.0, -6.0))],
        clav_l=[(4, (16.0, -8.0)), (8, (0.0, -8.0)), (14, (2.0, -8.0))],
        hand_r=[(4, (-0.13, 1.28, 0.16)), (6, (-0.09, 1.265, 0.4)), (8, (-0.008, 1.334, 0.86)), (11, (-0.008, 1.334, 0.864)),
                (14, (-0.02, 1.335, 0.8)), (17, (-0.07, 1.297, 0.42)), (20, (-0.117, 1.295, 0.188))],
        face_r=[(5, "box_guard"), (8, "fist_fwd"), (14, "fist_fwd"), (18, "box_guard")],
        pole_r=[(5, (-0.4, -1.0, -0.1)), (8, (-0.65, -0.75, 0.0)), (15, (-0.6, -0.8, 0.0)), (18, (-0.35, -1.0, -0.1))],
        hand_l=[(4, (0.05, 1.33, 0.52)), (6, (0.07, 1.295, 0.32)), (8, (0.085, 1.29, 0.24)), (15, (0.085, 1.29, 0.24)),
                (19, (0.06, 1.3, 0.33))],
        foot_l=[(5, FL), (6, (0.13, 0.11, 0.28)), (7, (0.13, 0.077, 0.4)), (14, (0.13, 0.077, 0.4)), (16, (0.13, 0.11, 0.3)),
                (18, FL)],
        heel_l=[(5, 3.0), (6, -6.0), (7, 0.0), (14, 0.0), (16, 8.0), (18, 3.0)],
        fyaw_r=[(4, 44.0), (8, 2.0), (14, 4.0), (20, 36.0)],
        heel_r=[(4, 6.0), (8, 50.0), (14, 46.0), (20, 14.0)],
        knee_r=[(8, (-0.1, 0.0, 1.0)), (15, (-0.2, 0.0, 1.0))],
    ),
    # the Fireball (fire_blast's Punch held to grow): an overhand right: a deep level change, dipped low and off the line to
    # the right with the right fist cocked by the ear (held while it grows); the fist loops high up and over the top and comes
    # down onto the mark as the body turns through and drops forward over the lead knee, the rear heel up; carried on down
    # and across to the left hip; up to the guard.  strike_s: the fist on the mark
    "fireball": clip(36, dict(hold_s=8 * S, strike_s=12 * S, back_s=19 * S, antic_s=8 * S, follow_s=16 * S, hand="r",
                              move="fire_blast", mode="punch_grow", order=5),
        root=[(4, (-0.03, -0.09, -0.015)), (8, (-0.06, -0.14, -0.03)), (10, (-0.02, -0.11, 0.04)), (12, (0.04, -0.14, 0.13)),
              (14, (0.045, -0.145, 0.14)), (17, (0.045, -0.15, 0.13)), (24, (0.012, -0.08, 0.04))],
        yaw=[(4, -32.0), (8, -40.0), (10, -18.0), (12, 22.0), (14, 24.0), (17, 26.0), (24, -10.0), (29, -24.0)],
        twist=[(4, -16.0), (8, -24.0), (10, -6.0), (12, 22.0), (14, 24.0), (17, 27.0), (24, 0.0)],
        side=[(4, 9.0), (8, 18.0), (10, 9.0), (12, -11.0), (14, -12.0), (17, -8.0), (24, 0.0)],
        hips=[(8, 6.0), (12, 12.0), (17, 14.0), (24, 7.0)],
        chest=[(4, 9.0), (8, 12.0), (10, 9.0), (12, 16.0), (14, 17.0), (17, 20.0), (24, 10.0)],
        head=[(8, 8.0), (12, 10.0), (17, 12.0), (24, 8.0)],
        clav_r=[(4, (0.0, -6.0)), (8, (-10.0, 4.0)), (10, (6.0, -18.0)), (12, (25.0, -8.0)), (14, (25.0, -7.0)), (17, (20.0, 0.0)),
                (24, (8.0, -4.0))],
        clav_l=[(8, (12.0, -7.0)), (12, (0.0, -6.0)), (17, (0.0, -4.0))],
        hand_r=[(4, (-0.15, 1.3, 0.14)), (8, (-0.24, 1.27, 0.04)), (9, (-0.33, 1.43, 0.13)), (10, (-0.2, 1.56, 0.32)), (12, (-0.005, 1.31, 0.75)),
                (13, (0.005, 1.29, 0.75)), (14, (0.015, 1.27, 0.74)), (17, (0.16, 1.05, 0.5)), (22, (0.0, 1.2, 0.35)),
                (26, (-0.11, 1.29, 0.21))],
        face_r=[(4, "box_guard"), (8, "box_cock"), (10, "box_cock"), (12, "box_over"), (17, "box_over"), (23, "box_guard")],
        pole_r=[(4, (-0.4, -1.0, -0.2)), (8, (-0.8, 0.3, -0.6)), (10, (-0.9, 0.5, -0.2)), (12, (-0.8, 0.5, 0.1)),
                (17, (-0.6, -0.3, 0.3)), (23, (-0.4, -1.0, -0.1))],
        hand_l=[(4, (0.04, 1.26, 0.33)), (8, (0.0, 1.22, 0.34)), (12, (0.085, 1.26, 0.24)), (17, (0.09, 1.23, 0.24)),
                (24, (0.06, 1.29, 0.32))],
        fyaw_r=[(8, 46.0), (12, 0.0), (17, -2.0), (25, 34.0)],
        heel_r=[(4, 6.0), (8, 2.0), (12, 52.0), (17, 56.0), (25, 15.0)],
        heel_l=[(8, 2.0), (12, 0.0), (17, 0.0), (25, 4.0)],
        knee_l=[(12, (0.3, 0.0, 1.0)), (20, (0.3, 0.0, 1.0))],
        knee_r=[(8, (-0.6, 0.0, 1.0)), (12, (-0.2, 0.0, 1.0)), (18, (-0.2, 0.0, 1.0))],
    ),
    # Lightning (fire_blast "lightning", the longest lock): the charged straight: sunk deep and wound hard to the right on the
    # rear leg, the right fist cocked back by the ear with the elbow up, the lead fist reaching out ahead along the aim (the
    # range finder); the charge trembles through the cocked fist and the body while the lock fills (held); then a lunge: the lead
    # foot steps a long way in, the hips and the shoulders turn through and the straight right is driven out at full length,
    # the lead hand snapped back to the chin; held on the strike; the lead foot stepped back out to the guard.
    # strike_s: the arm out
    "lightning": clip(62, dict(hold_s=30 * S, strike_s=34 * S, back_s=43 * S, antic_s=30 * S, follow_s=39 * S, hand="r",
                               move="fire_arc", mode="lightning", order=6),
        root=_tremor([(6, (-0.035, -0.12, -0.06)), (14, (-0.04, -0.14, -0.07)), (22, (-0.045, -0.15, -0.075)),
                      (30, (-0.045, -0.155, -0.078)), (32, (-0.03, -0.13, 0.0)), (34, (0.0, -0.11, 0.24)),
                      (37, (0.0, -0.115, 0.25)), (43, (0.0, -0.11, 0.22)), (51, (0.0, -0.065, 0.05))], 8, 30, 0.004, step=2,
                     axis=(0.0, 1.0, 0.0)),
        yaw=[(6, -46.0), (30, -55.0), (32, -26.0), (34, 18.0), (37, 20.0), (43, 16.0), (51, -14.0), (56, -24.0)],
        twist=[(6, -22.0), (30, -30.0), (32, -8.0), (34, 22.0), (37, 24.0), (43, 20.0), (51, -2.0)],
        hips=[(6, 8.0), (30, 10.0), (34, 10.0), (43, 10.0), (51, 6.0)],
        chest=[(6, 11.0), (30, 13.0), (34, 15.0), (43, 14.0), (51, 8.0)],
        head=[(6, 9.0), (30, 10.0), (34, 9.0), (51, 8.0)],
        clav_r=[(6, (-12.0, -16.0)), (30, (-15.0, -17.0)), (34, (27.0, -10.0)), (43, (22.0, -8.0)), (51, (6.0, -5.0))],
        clav_l=[(6, (20.0, -9.0)), (30, (20.0, -9.0)), (34, (0.0, -8.0)), (45, (4.0, -8.0))],
        hand_r=_tremor([(6, (-0.21, 1.33, -0.04)), (30, (-0.22, 1.33, -0.07)), (32, (-0.12, 1.32, 0.3)),
                        (34, (-0.015, 1.33, 0.93)), (37, (-0.015, 1.33, 0.935)), (43, (-0.03, 1.33, 0.88)),
                        (48, (-0.08, 1.307, 0.45)), (53, (-0.116, 1.294, 0.193))], 8, 30, 0.01, step=2),
        face_r=[(6, "box_cock"), (31, "box_cock"), (34, "fist_fwd"), (43, "fist_fwd"), (51, "box_guard")],
        pole_r=[(6, (-0.7, 0.35, -0.7)), (30, (-0.7, 0.45, -0.7)), (32, (-0.5, -0.6, -0.4)), (34, (-0.65, -0.75, 0.0)),
                (45, (-0.6, -0.8, 0.0)), (51, (-0.35, -1.0, -0.1))],
        hand_l=[(6, (0.02, 1.32, 0.56)), (30, (0.02, 1.31, 0.53)), (32, (0.06, 1.31, 0.45)), (34, (0.085, 1.29, 0.32)),
                (45, (0.085, 1.29, 0.33)), (53, (0.055, 1.3, 0.35))],
        face_l=[(6, "fist_fwd"), (31, "fist_fwd"), (33, "box_guard")],
        pole_l=[(6, (0.5, -0.8, -0.2)), (31, (0.5, -0.8, -0.2)), (34, (0.25, -1.0, -0.1))],
        foot_l=[(31, FL), (33, (0.13, 0.12, 0.34)), (34, (0.13, 0.077, 0.46)), (45, (0.13, 0.077, 0.46)), (49, (0.13, 0.11, 0.32)),
                (52, FL)],
        heel_l=[(31, 3.0), (33, -8.0), (34, 0.0), (45, 0.0), (48, 8.0), (52, 3.0)],
        heel_r=[(6, 8.0), (30, 6.0), (32, 30.0), (34, 54.0), (43, 50.0), (53, 14.0)],
        fyaw_r=[(6, 46.0), (30, 48.0), (34, 0.0), (43, 2.0), (53, 36.0)],
        knee_l=[(6, (0.3, 0.0, 1.0)), (30, (0.3, 0.0, 1.0)), (34, (0.2, 0.0, 1.0))],
        knee_r=[(6, (-0.55, 0.0, 1.0)), (30, (-0.55, 0.0, 1.0)), (34, (-0.1, 0.0, 1.0)), (45, (-0.2, 0.0, 1.0))],
    ),

    # ---------------------------------------------------------------- key 2: the Kick as a ground punch, the High Kick as an uppercut
    # the owner's answer (2026-10-09): the boxer's Kick is a ground punch: a hop-step in with the right fist cocked high by the
    # ear (held while the wave grows); then dropped deep into a long lunge, the trunk folded over the lead knee and the right
    # fist driven down into the deck ahead of the lead foot (the wave runs along the floor from it, toward the aim), the head
    # up along the aim and the left fist guarding the face; held on the deck a beat; pushed back up to the guard.
    # strike_s: the fist on the deck
    "ground_punch": clip(36, dict(hold_s=6 * S, strike_s=10 * S, back_s=17 * S, antic_s=6 * S, follow_s=13 * S, hand="r",
                                  move="fire_kick", mode="kick", order=7),
        root=[(3, (-0.01, -0.045, 0.03)), (6, (-0.02, -0.075, 0.08)), (8, (0.0, -0.28, 0.12)), (10, (0.0, -0.48, 0.13)),
              (12, (0.0, -0.5, 0.13)), (14, (0.0, -0.495, 0.13)), (18, (0.0, -0.3, 0.1)), (23, (0.0, -0.12, 0.04)),
              (28, (0.0, -0.06, 0.0))],
        yaw=[(3, -34.0), (6, -38.0), (8, -12.0), (10, 6.0), (14, 6.0), (20, -14.0), (27, -24.0)],
        twist=[(3, -16.0), (6, -20.0), (8, -4.0), (10, 12.0), (14, 12.0), (20, -4.0)],
        hips=[(3, 3.0), (6, 2.0), (8, 22.0), (10, 40.0), (12, 42.0), (14, 41.0), (18, 28.0), (24, 10.0)],
        chest=[(3, 5.0), (6, 3.0), (8, 20.0), (10, 32.0), (12, 33.0), (14, 32.0), (18, 20.0), (24, 9.0)],
        head=[(3, 6.0), (6, 4.0), (8, -8.0), (10, -30.0), (14, -30.0), (18, -14.0), (24, 6.0)],
        clav_r=[(3, (-6.0, -12.0)), (6, (-10.0, -16.0)), (8, (10.0, -2.0)), (10, (24.0, 14.0)), (14, (22.0, 14.0)), (20, (8.0, -4.0))],
        clav_l=[(6, (14.0, -8.0)), (10, (4.0, -6.0)), (18, (6.0, -6.0))],
        hand_r=[(3, (-0.21, 1.33, 0.06)), (6, (-0.25, 1.39, 0.03)), (8, (-0.12, 0.95, 0.42)), (10, (0.0, 0.12, 0.6)),
                (12, (0.0, 0.11, 0.6)), (14, (0.0, 0.12, 0.595)), (18, (-0.06, 0.55, 0.45)), (24, (-0.11, 1.15, 0.24)),
                (29, (-0.116, 1.294, 0.193))],
        face_r=[(3, "box_cock"), (7, "box_cock"), (10, "box_ground"), (15, "box_ground"), (22, "box_guard")],
        pole_r=[(3, (-0.8, 0.3, -0.6)), (7, (-0.8, 0.4, -0.5)), (10, (-0.8, 0.2, -0.3)), (15, (-0.8, 0.2, -0.3)),
                (22, (-0.4, -1.0, -0.1))],
        hand_l=[(3, (0.06, 1.3, 0.38)), (6, (0.07, 1.3, 0.4)), (8, (0.13, 1.0, 0.55)), (10, (0.17, 0.73, 0.66)),
                (14, (0.17, 0.72, 0.66)), (20, (0.11, 1.0, 0.5)), (26, (0.055, 1.3, 0.35))],
        foot_l=[(2, FL), (3, (0.13, 0.12, 0.27)), (5, (0.13, 0.077, 0.35)), (16, (0.13, 0.077, 0.35)), (20, (0.13, 0.11, 0.29)),
                (24, FL)],
        heel_l=[(2, 3.0), (3, -6.0), (5, 0.0), (16, 0.0), (19, 8.0), (24, 3.0)],
        foot_r=[(6, FR), (9, (-0.17, 0.077, -0.3)), (17, (-0.17, 0.077, -0.3)), (22, FR)],
        fyaw_r=[(6, 40.0), (10, 20.0), (17, 20.0), (23, 40.0)],
        heel_r=[(3, 14.0), (6, 8.0), (10, 62.0), (16, 60.0), (22, 16.0)],
        knee_l=[(8, (0.35, 0.0, 1.0)), (18, (0.35, 0.0, 1.0))],
        knee_r=[(8, (-0.3, -0.3, 1.0)), (18, (-0.3, -0.3, 1.0))],
    ),
    # the High Kick as a rising uppercut (the owner's answer, 2026-10-09; fire_kick "high_kick": the flame crescent thrown up
    # over walls and into jumpers): dipped low to the right with the right fist dropped by the belly, palm up (held); the legs
    # drive the body up onto the toes as the hips turn through and the fist rises past the chin and on up over the head, the
    # head and the eyes following it up; held high a beat; settled down to the guard.  strike_s: the fist past the chin
    "uppercut": clip(32, dict(hold_s=6 * S, strike_s=10 * S, back_s=16 * S, antic_s=6 * S, follow_s=13 * S, hand="r",
                              move="fire_kick", mode="high_kick", order=8),
        root=[(3, (-0.02, -0.08, -0.01)), (6, (-0.045, -0.14, -0.02)), (8, (-0.02, -0.08, 0.02)), (10, (0.01, -0.03, 0.05)),
              (13, (0.015, -0.012, 0.06)), (15, (0.015, -0.016, 0.06)), (20, (0.005, -0.05, 0.03)), (25, (0.0, -0.055, 0.0))],
        yaw=[(3, -30.0), (6, -38.0), (8, -14.0), (10, 16.0), (13, 22.0), (15, 22.0), (21, -10.0), (26, -24.0)],
        twist=[(3, -14.0), (6, -20.0), (8, -4.0), (10, 20.0), (13, 26.0), (15, 26.0), (21, 0.0)],
        side=[(3, 8.0), (6, 16.0), (8, 6.0), (10, -6.0), (13, -10.0), (15, -9.0), (21, 0.0)],
        hips=[(6, 9.0), (10, 2.0), (13, -2.0), (15, -2.0), (21, 5.0)],
        chest=[(3, 10.0), (6, 13.0), (8, 6.0), (10, 0.0), (13, -6.0), (15, -6.0), (21, 6.0)],
        head=[(6, 8.0), (10, 0.0), (13, -14.0), (15, -14.0), (21, 6.0)],
        clav_r=[(3, (0.0, 6.0)), (6, (2.0, 10.0)), (10, (14.0, -14.0)), (13, (10.0, -22.0)), (15, (10.0, -22.0)), (21, (6.0, -4.0))],
        clav_l=[(6, (10.0, -6.0)), (13, (4.0, -6.0))],
        hand_r=[(3, (-0.16, 1.15, 0.16)), (6, (-0.17, 1.0, 0.18)), (8, (-0.1, 1.08, 0.36)), (10, (-0.03, 1.42, 0.42)),
                (13, (-0.02, 1.8, 0.24)), (15, (-0.02, 1.79, 0.23)), (19, (-0.07, 1.48, 0.25)), (24, (-0.116, 1.294, 0.193))],
        face_r=[(3, "box_upper_low"), (8, "box_upper_low"), (10, "fist_up"), (15, "fist_up"), (21, "box_guard")],
        pole_r=[(3, (-0.5, -1.0, 0.0)), (8, (-0.4, -1.0, 0.3)), (10, (-0.3, -0.6, 0.8)), (13, (-0.4, 0.2, 1.0)),
                (15, (-0.4, 0.2, 1.0)), (21, (-0.35, -1.0, -0.1))],
        hand_l=[(3, (0.02, 1.26, 0.34)), (6, (-0.02, 1.2, 0.33)), (10, (0.07, 1.3, 0.25)), (15, (0.07, 1.32, 0.24)),
                (22, (0.055, 1.3, 0.35))],
        fyaw_r=[(6, 42.0), (10, 6.0), (15, 4.0), (22, 36.0)],
        heel_r=[(6, 4.0), (10, 50.0), (13, 56.0), (15, 56.0), (22, 14.0)],
        heel_l=[(6, 2.0), (10, 20.0), (13, 30.0), (15, 30.0), (22, 4.0)],
        knee_r=[(6, (-0.6, 0.0, 1.0)), (10, (-0.2, 0.0, 1.0)), (16, (-0.2, 0.0, 1.0))],
    ),

    # ---------------------------------------------------------------- the 1-2 flurry (Embers itself: the jab and the cross)
    # the 1-2 flurry (fire_jab "double_jab"; no key reaches it yet): tucked in behind the guard and leaning in, four short punches in a row, left, right, left,
    # right (the arms never quite straight: a flurry, not a power shot), the shoulders rocking hard side to side behind them
    # and the head bobbing off the line with each, the rear heel pumping with each right; back to the guard.
    # strike_s: the first ember
    "flurry": clip(28, dict(hold_s=2 * S, strike_s=4 * S, back_s=18 * S, hand="both", move="fire_jab", mode="double_jab", order=9,
                            stills="tuck:2;1 left:4;2 right:8;3 left:12;4 right:16;back:21"),
        root=[(2, (0.0, -0.065, 0.03)), (4, (-0.005, -0.068, 0.035)), (8, (0.008, -0.072, 0.055)), (12, (-0.005, -0.068, 0.04)),
              (16, (0.008, -0.072, 0.06)), (21, (0.0, -0.058, 0.02))],
        yaw=[(2, -24.0), (4, -31.0), (8, -6.0), (12, -30.0), (16, -4.0), (21, -22.0)],
        twist=[(2, -8.0), (4, -20.0), (8, 10.0), (12, -19.0), (16, 12.0), (21, -6.0)],
        side=[(4, -3.0), (8, 3.0), (12, -3.0), (16, 3.0), (21, 0.0)],
        chest=[(2, 10.0), (16, 11.0), (21, 8.0)],
        head=[(2, 11.0), (16, 11.0), (21, 8.0)],
        hand_l=[(2, (0.045, 1.28, 0.33)), (4, (0.012, 1.335, 0.65)), (6, (0.05, 1.3, 0.36)), (8, (0.075, 1.29, 0.26)),
                (10, (0.05, 1.3, 0.36)), (12, (0.012, 1.33, 0.65)), (14, (0.05, 1.3, 0.36)), (16, (0.08, 1.29, 0.25)),
                (20, (0.06, 1.3, 0.34))],
        face_l=[(3, "box_guard"), (4, "fist_fwd"), (6, "box_guard"), (11, "box_guard"), (12, "fist_fwd"), (14, "box_guard")],
        pole_l=[(3, (0.3, -1.0, -0.1)), (4, (0.6, -0.8, 0.0)), (6, (0.3, -1.0, -0.1)), (11, (0.3, -1.0, -0.1)),
                (12, (0.6, -0.8, 0.0)), (14, (0.3, -1.0, -0.1))],
        hand_r=[(2, (-0.12, 1.28, 0.188)), (4, (-0.12, 1.29, 0.19)), (6, (-0.07, 1.292, 0.36)), (8, (-0.012, 1.33, 0.645)),
                (10, (-0.07, 1.29, 0.33)), (12, (-0.12, 1.295, 0.19)), (14, (-0.07, 1.292, 0.36)), (16, (-0.01, 1.33, 0.67)),
                (19, (-0.08, 1.295, 0.3)), (22, (-0.116, 1.294, 0.193))],
        face_r=[(6, "box_guard"), (8, "fist_fwd"), (10, "box_guard"), (15, "box_guard"), (16, "fist_fwd"), (19, "box_guard")],
        pole_r=[(6, (-0.35, -1.0, -0.1)), (8, (-0.6, -0.8, 0.0)), (10, (-0.35, -1.0, -0.1)), (15, (-0.35, -1.0, -0.1)),
                (16, (-0.6, -0.8, 0.0)), (19, (-0.35, -1.0, -0.1))],
        clav_l=[(4, (22.0, -13.0)), (8, (2.0, -7.0)), (12, (22.0, -13.0)), (16, (2.0, -7.0)), (21, (10.0, -7.0))],
        clav_r=[(4, (0.0, -6.0)), (8, (20.0, -9.0)), (12, (0.0, -6.0)), (16, (21.0, -9.0)), (21, (6.0, -5.0))],
        heel_r=[(4, 10.0), (8, 38.0), (12, 14.0), (16, 40.0), (21, 16.0)],
        fyaw_r=[(8, 16.0), (12, 36.0), (16, 14.0), (22, 40.0)],
    ),

    # ---------------------------------------------------------------- E: the slip (fire's Parry)
    # the Parry as a slip (fire_parry "parry"): the eyes on the shot, then the head slipped a head's width off the line to the
    # right (the knees bent deep, the shoulders turned and the waist bent to the right, the weight onto the rear leg, the
    # guard kept up at the face; held: the window); out of the slip the counter jab snaps straight back along the line (the
    # fire sent back; a perfect readies the jab at once); back up to the guard.  strike_s: the counter out
    "slip": clip(30, dict(hold_s=5 * S, strike_s=12 * S, back_s=16 * S, hand="l", move="fire_parry", mode="parry", order=10,
                          stills="ready:2;slip (the window):6;counter jab:12;follow-through:15"),
        root=[(2, (0.0, -0.06, 0.0)), (5, (-0.065, -0.13, 0.0)), (9, (-0.065, -0.132, 0.0)), (12, (-0.055, -0.12, 0.025)),
              (15, (-0.05, -0.115, 0.02)), (20, (-0.018, -0.07, 0.0))],
        yaw=[(2, -24.0), (5, -34.0), (9, -34.0), (12, -32.0), (15, -32.0), (20, -26.0)],
        twist=[(2, -8.0), (5, -22.0), (9, -22.0), (12, -27.0), (14, -27.0), (20, -11.0)],
        side=[(2, 0.0), (5, 20.0), (9, 20.0), (12, 16.0), (15, 15.0), (20, 5.0)],
        chest=[(5, 12.0), (9, 12.0), (12, 11.0), (20, 8.0)],
        head=[(5, 9.0), (9, 9.0), (12, 10.0)],
        clav_r=[(5, (4.0, 3.0)), (9, (4.0, 3.0)), (14, (4.0, -2.0)), (20, (6.0, -5.0))],
        clav_l=[(5, (12.0, -10.0)), (9, (12.0, -10.0)), (12, (26.0, -15.0)), (14, (25.0, -14.0)), (18, (12.0, -7.0))],
        hand_l=[(2, (0.045, 1.3, 0.35)), (5, (-0.12, 1.22, 0.32)), (9, (-0.12, 1.22, 0.32)), (10, (-0.1, 1.24, 0.42)),
                (12, (-0.06, 1.288, 0.628)), (13, (-0.06, 1.288, 0.63)), (15, (-0.04, 1.27, 0.5)), (18, (0.0, 1.27, 0.38)),
                (22, (0.05, 1.3, 0.36))],
        face_l=[(10, "box_guard"), (12, "fist_fwd"), (14, "fist_fwd"), (17, "box_guard")],
        pole_l=[(10, (0.3, -1.0, -0.1)), (12, (0.65, -0.75, 0.0)), (15, (0.4, -1.0, -0.1))],
        hand_r=[(5, (-0.22, 1.19, 0.15)), (9, (-0.22, 1.19, 0.15)), (14, (-0.21, 1.2, 0.16)), (20, (-0.14, 1.27, 0.19))],
        heel_r=[(5, 6.0), (9, 6.0), (14, 8.0), (20, 13.0)],
        heel_l=[(5, 12.0), (9, 12.0), (13, 10.0), (20, 4.0)],
        knee_r=[(5, (-0.6, 0.0, 1.0)), (14, (-0.5, 0.0, 1.0))],
    ),

    # ---------------------------------------------------------------- key 3: Step (the game carries the body)
    # step in (footwork "step", W held): the rear foot pushes, the lead foot reaches in low and lands, the rear foot drags up
    # after it to the stance's length; the guard kept up and the head level.  strike_s: the lead foot down
    "step_in": clip(18, dict(hold_s=2 * S, strike_s=7 * S, back_s=11 * S, hand="both", move="footwork", mode="step", order=11,
                             stills="push:3;lead foot down:7;rear foot drags up:10"),
        root=[(2, (0.0, -0.065, -0.03)), (5, (0.0, -0.07, 0.1)), (7, (0.0, -0.09, 0.17)), (9, (0.0, -0.08, 0.14)),
              (12, (0.0, -0.06, 0.05))],
        hips=[(5, 8.0), (9, 6.0)], chest=[(5, 10.0), (9, 8.0)],
        foot_l=[(2, FL), (4, (0.13, 0.11, 0.34)), (6, (0.13, 0.095, 0.48)), (7, (0.13, 0.077, 0.49)), (9, (0.13, 0.077, 0.47)),
                (13, FL)],
        heel_l=[(2, 3.0), (4, 2.0), (6, -8.0), (7, 0.0), (9, 2.0), (13, 3.0)],
        foot_r=[(7, FR), (9, (-0.19, 0.1, -0.1)), (11, (-0.19, 0.085, -0.02)), (12, (-0.19, 0.077, -0.02)), (15, FR)],
        heel_r=[(2, 26.0), (5, 38.0), (7, 34.0), (9, 34.0), (11, 18.0), (15, 12.0)],
        hand_l=[(5, (0.05, 1.3, 0.4)), (9, (0.05, 1.302, 0.37))],
    ),
    # step back (footwork "back_flip": nothing held): the lead foot pushes off its ball, the rear foot reaches back and lands,
    # the lead foot drags back after it; the guard kept up.  strike_s: the rear foot down
    "step_back": clip(18, dict(hold_s=2 * S, strike_s=7 * S, back_s=11 * S, hand="both", move="footwork", mode="back_flip",
                               order=12, stills="push:3;rear foot down:7;lead foot drags back:10"),
        root=[(2, (0.0, -0.065, 0.03)), (5, (0.0, -0.075, -0.1)), (7, (0.0, -0.09, -0.17)), (9, (0.0, -0.08, -0.14)),
              (12, (0.0, -0.06, -0.05))],
        foot_r=[(2, FR), (4, (-0.19, 0.11, -0.36)), (6, (-0.19, 0.095, -0.5)), (7, (-0.19, 0.077, -0.51)), (9, (-0.19, 0.077, -0.49)),
                (13, FR)],
        heel_r=[(2, 12.0), (4, 8.0), (6, 2.0), (7, 14.0), (9, 20.0), (13, 12.0)],
        foot_l=[(7, FL), (9, (0.13, 0.1, 0.08)), (11, (0.13, 0.085, -0.02)), (12, (0.13, 0.077, -0.02)), (15, FL)],
        heel_l=[(2, 12.0), (5, 24.0), (7, 12.0), (11, 4.0), (15, 3.0)],
    ),
    # step left (footwork "hop", A held): the lead foot first, out to the left, the rear foot drawn after it (a boxer never
    # crosses his feet).  strike_s: the lead foot down
    "step_left": clip(18, dict(hold_s=2 * S, strike_s=7 * S, back_s=11 * S, hand="both", move="footwork", mode="hop",
                               order=13, stills="push:3;lead foot down:7;rear foot drawn after:10"),
        root=[(2, (-0.02, -0.065, 0.0)), (5, (0.08, -0.07, 0.0)), (7, (0.15, -0.09, 0.0)), (9, (0.13, -0.08, 0.0)),
              (12, (0.05, -0.06, 0.0))],
        roll=[(2, 2.5), (5, -2.5), (9, 0.0)],
        foot_l=[(2, FL), (4, (0.27, 0.11, 0.2)), (6, (0.43, 0.095, 0.2)), (7, (0.44, 0.077, 0.2)), (9, (0.42, 0.077, 0.2)), (13, FL)],
        heel_l=[(2, 3.0), (4, 2.0), (6, -6.0), (7, 0.0), (9, 2.0), (13, 3.0)],
        foot_r=[(7, FR), (9, (-0.05, 0.1, -0.215)), (11, (0.03, 0.085, -0.215)), (12, (0.03, 0.077, -0.215)), (15, FR)],
        heel_r=[(2, 26.0), (5, 34.0), (7, 28.0), (11, 16.0), (15, 12.0)],
    ),
    # step right (footwork "hop", D held): the rear foot first, out to the right, the lead foot drawn after it.
    # strike_s: the rear foot down
    "step_right": clip(18, dict(hold_s=2 * S, strike_s=7 * S, back_s=11 * S, hand="both", move="footwork", mode="hop",
                                order=14, stills="push:3;rear foot down:7;lead foot drawn after:10"),
        root=[(2, (0.02, -0.065, 0.0)), (5, (-0.08, -0.07, 0.0)), (7, (-0.15, -0.09, 0.0)), (9, (-0.13, -0.08, 0.0)),
              (12, (-0.05, -0.06, 0.0))],
        roll=[(2, -2.5), (5, 2.5), (9, 0.0)],
        foot_r=[(2, FR), (4, (-0.33, 0.11, -0.215)), (6, (-0.49, 0.095, -0.215)), (7, (-0.5, 0.077, -0.215)), (9, (-0.48, 0.077, -0.215)),
                (13, FR)],
        heel_r=[(2, 12.0), (4, 8.0), (6, 2.0), (7, 14.0), (9, 20.0), (13, 12.0)],
        foot_l=[(7, FL), (9, (0.0, 0.1, 0.2)), (11, (-0.08, 0.085, 0.2)), (12, (-0.08, 0.077, 0.2)), (15, FL)],
        heel_l=[(2, 8.0), (5, 22.0), (7, 12.0), (11, 4.0), (15, 3.0)],
    ),
}


def game_name(key):
    return "own-style-%s-%s" % (STYLE, key.replace("_", "-"))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--clips", default="")
    ap.add_argument("--glb", default=None)
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--fit", action="store_true", help="list the frames where a limb is (nearly) locked straight")
    ap.add_argument("--angles", action="store_true", help="print each frame's elbow and knee bends (deg, 0 straight)")
    ap.add_argument("--points", action="store_true", help="print each frame's key joints and the lowest surface (m)")
    a = ap.parse_args(argv)
    only = [c for c in a.clips.split(",") if c]
    out = {"fps": FPS, "clips": {}, "names": {}, "style": STYLE, "element": ELEMENT, "library": LIBRARY,
           "generator": GENERATOR,
           "about": GENERATOR + ": our own boxing clips for fire (a fighting style), key poses IK-solved on Actor_B's rig in "
                    "Blender by bend_clips.py's solver from the rig's rest pose (no library clip read)"}
    baked = {}
    for name, c in CLIPS.items():
        if only and name not in only:
            continue
        fit = [] if a.fit else None
        frames, roots, report = bc.bake(c, fit)
        meta = dict(c["meta"])
        meta["length_frames"] = c["length"]
        meta["ik_miss_m"] = round(max(r[-1] for r in report), 4)
        if c.get("loop"):
            meta["loop"] = "linear"
        out["clips"][name] = {"frames": frames, "root": roots, "meta": meta}
        out["names"][name] = game_name(name)
        baked[name] = (frames, roots)
        print("BOX %s -> %s: %d frames, worst IK miss %.3f m" % (name, game_name(name), len(frames), meta["ik_miss_m"]))
        for fr in fit or []:
            print("   FIT %s f%02d %s slack %.3f -> %s" % (name, fr[0], fr[1], fr[2], fr[3]))
        if a.angles:
            for fr, ang in bc.ANGLES:
                print("   ANG %s f%02d elbow r %3d l %3d  knee r %3d l %3d" % (name, fr, *ang))
        if a.points:
            for fr, pts, low, hat, far in bc.POINTS:
                print("   PTS %s f%02d low %.3f (%s) " % (name, fr, low[0], low[1]) +
                      " ".join("%s=%s" % (j, list(v)) for j, v in pts.items()) + " hat=%.3f hatz=%.3f palmhat=%.3f" % (hat, *far))
        if not a.quiet:
            for r in report:
                print("   f%02d  r_palm %s  l_palm %s  pelvis %.3f  r_ankle %s  l_ankle %s  miss %.3f" % r)
    json.dump(out, open(a.out, "w"))
    print("BOX baked %d clips -> %s" % (len(out["clips"]), a.out))
    if a.blend:
        bc.keep_blend(a.blend, baked)
        print("BOX blend -> %s" % a.blend)


if __name__ == "__main__":
    main()
