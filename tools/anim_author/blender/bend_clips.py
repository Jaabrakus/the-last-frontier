"""Our own ring-sport casts and reactions (Tidebreak, the elemental ring sport; the owner, 2026-10-04: "switch to a elemental
avatar the last airbender type of game", then: the throw-style moves on NEW OWN throw clips only, and the clips our own:
docs/animation_provenance.md, animations/SOURCE.md). Derived from tools/anim_author/blender/form_clips.py (the Form casts' route)
and from nothing else: key poses typed into the CLIPS table below, solved with two-bone IK (rigkit.ik2) on the skeleton of
Actor_B's own rig (assets/character/actor_b_body.glb, read from this checkout) in Blender, and baked to the bones' local
rotations as Godot has them, with the root's position, for tools/anim_author/install_bend.gd. This tool never reads a library
clip, a dumped move (dump_move.gd / dump_pose.gd output) or rigkit.Native / MirrorNative: the base it starts every clip from is
the rig's own rest (bind) pose, which our STAND below then keys into a ready stand (the arms down by the sides, the feet set, the
knees soft, the fingers half closed). The real martial forms (Hung Gar's stomps and heavy pushes for earth; a spear's, a
tomahawk's and an atlatl's throws) were the owner's visual reference only, as the owner's account in animations/SOURCE.md says.

The first set (the owner judges these by eye before more are authored; he rejected and deleted a stiff solver-authored gait
library on 2026-10-01, so these are key poses, each with its anticipation, its strike, its follow-through and the weight going
from foot to foot):
  earth_stomp        Hung Gar's stomp: the weight onto the left leg, the right knee drawn high with the fists gathered at the chest,
                     a hang; then the foot driven down into a wide horse stance, the root dropping with it, both fists driven down
                     beside the thighs; the shock taken in the knees; the foot brought back in to the stand.  strike_s: the foot down
  earth_push         the two-hand heavy push: the weight rocks back onto the right leg as both palms are drawn back to the ribs
                     and the left foot lifts; the foot steps out into a bow stance and both palms are driven out from the chest,
                     the back leg straightening behind them; held; stepped back.  strike_s: the arms straight
  earth_rise         the uppercut raise (a rock or a column lifted): a deep crouch coiled to the right, the right fist low by the
                     knee; the legs drive up, the hips turn through, the fist rises past the face to above the head as the left
                     hand is pulled back to the hip, up onto the toes of the back foot.  strike_s: the fist at the face's height
  throw_overhand     like a spear: the left foot steps out, the body turned side-on, the right hand cocked high behind the shoulder
                     and the left arm pointed at the mark; the hips then the chest turn through, the hand comes over the top and
                     lets go out in front above the head; follow-through down across the body onto the front leg, the back heel up
  throw_sidearm      like a tomahawk (a locked wrist): a lower stance coiled hard to the right, the hand out to the side at the
                     chest's height; the body unwinds and the arm sweeps round flat, letting go in front; follow-through across
                     to the left with the back foot pivoting on its ball
  throw_underhand    a flick like an atlatl's: a short step, the body low and forward, the right hand swung back low past the hip;
                     it swings through low and flicks up, letting go at the waist's height, and rises on with the body
  knock_slide        a braced backward slide (the knock that does not lift): the hit snaps the chest back and the hands forward;
                     the feet slide apart into a low staggered brace (they never lift: the game slides the body), the body
                     leaned into the push, the forearms up in a guard (held: hold_s, while the knock lasts); then up and in
  knock_air          launched: the hit arches the body back and throws the arms out; the knees come up and the arms flail wide
                     (held: hold_s, while in the air); the legs reach down for the ground, the landing taken low (up_s),
                     and back up to the stand
Metas (seconds): strike_s the moment the cast lets go / the foot or the fist lands / the hit (SwayPose's `struck`), hold_s
where the game may hold the pose (the lock's wind-up, or the knock while it lasts; at or before strike_s on a cast), back_s
where the recovery to the stand begins, up_s (knock_air) the landing; and strings: hand (the striking limb: r, l, both,
foot_r, foot_l; SwayPose.strike_point), mask (ToolPose's: full), root ("place": the root's position is keyed and comes back to
the start but for a moved stance).

Channels of a clip (each a list of (frame, value) keys, interpolated by a monotone cubic through them, so the motion carries
through a key instead of stopping on it; a value repeated is a hold): every place is in the character's frame (+X the
character's left, +Y up, +Z forward, metres), every angle in degrees.
  root        the root's offset from the stand's (x, y, z)
  yaw         the whole body turned about the vertical (+ to the left; the feet stay where their own keys put them)
  hips        the whole body's bow from the root (+ forward); roll: its tilt (+ the left hip up)
  chest       the spine's pitch over the hips (+ forward); side: its bend (+ toward the left); twist: its turn (+ the left
              shoulder back), each spread over the spine
  head        the neck's and head's pitch (+ down), look: their turn (+ to the left); the head keeps on the mark through the
              body's yaw and twist unless look turns it
  clav_r/l    the clavicle forward and down (deg, (fwd, down))
  hand_r/l    the palm's place, or "stand" (hanging by the thigh); face_r/l the hand's facing: a name of FACING (the right
              hand's, mirrored for the left) or ((fingers' way), (palm's way)); pole_r/l the elbow's way from the shoulder
  grip_r/l    the fingers' close from the rest's relaxed hand: 1 a fist (the thumb over it), below 0 opened out flat
  foot_r/l    the ankle's place with the foot flat, or "stand"; fyaw_r/l its toe-out (+ out); heel_r/l the heel's lift about
              the ball (+ up onto the toes, - the toes up onto the heel); knee_r/l the knee's way from the hip (or the toes')
A clip with "mirror": True also bakes its twin, <name>_l, the same keys mirrored across the body's middle (left for right).

  Blender -b --factory-startup --python tools/anim_author/blender/bend_clips.py -- --out <bend.json> --blend <bend.blend>
      [--clips earth_stomp,throw_overhand] [--glb <actor_b_body.glb>]
  (in this project through the one-heavy-process lock: zsh <scratchpad>/blender_run.sh -b --factory-startup --python ...)
--blend keeps an Actor_B rig keyed with every clip baked (an action each) for the owner to open and refine in Blender; --clips
bakes only those (the installer merges them into the library, the others kept); --glb the rig (default: this checkout's).
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)


def _glb_arg():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--glb" in argv and argv.index("--glb") + 1 < len(argv):
        return os.path.abspath(argv[argv.index("--glb") + 1])
    return os.path.join(PROJECT, "assets", "character", "actor_b_body.glb")


import bpy  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

import rigmap  # noqa: E402
# The rig of this checkout (rigmap's default path points at the main checkout, which other sessions edit): set before rigkit
# builds its skeleton from it.
GLB = _glb_arg()
rigmap.GLB = GLB
rigmap.read_glb_json.__defaults__ = (GLB,)
import rigkit  # noqa: E402

SK = rigkit.SK
FPS = 30

SPINE = [("spinea", 0.3), ("spineb", 0.3), ("spinec", 0.22), ("spined", 0.18)]
NECK = [("neck", 0.45), ("heada", 0.35), ("headb", 0.2)]
ARM = ["clavicle", "shoulder", "elbow", "wrist"]
LEG = ["upper_leg", "knee", "ankle", "heel", "ball"]
## The fingers' joints and their close at a fist (deg about the knuckles' line; the thumb across the palm).
CURL = {"index": {"a": 78, "b": 95, "c": 60}, "middle": {"a": 82, "b": 98, "c": 60}, "ring": {"a": 85, "b": 98, "c": 58},
        "pinky": {"b": 88, "c": 95, "d": 55}, "thumb": {"b": 22, "c": 40}}
## Keyed at the rest's rotation unless a channel moves them (so the game's own pose never shows through the full mask).
STILL = ["lower_base", "upper_base", "pelvis", "palm", "index_metacarpal", "middle_metacarpal", "ring_metacarpal", "pinkya",
         "thumba"]

## The hand's facings (the right hand's; the left's mirrored): the fingers' way (the wrist to the knuckles) and the palm's.
FACING = {
    "stand": ((0.05, -1.0, 0.08), (1.0, 0.0, 0.15)),          # hanging, the palm in on the thigh
    "push": ((-0.12, 0.97, 0.2), (0.0, 0.08, 1.0)),            # a palm pushed out: the fingers up, the heel of the hand leading
    "chamber": ((0.1, 0.0, 1.0), (0.0, 1.0, 0.0)),             # drawn back at the ribs, the palm up
    "fist_down": ((0.0, -0.75, 0.66), (1.0, 0.0, 0.0)),        # a fist driven down and out, the knuckles leading
    "fist_gather": ((0.55, 0.3, 0.78), (0.0, -1.0, 0.0)),      # the fists gathered at the chest, the palms down
    "fist_low": ((0.0, -0.7, 0.7), (1.0, 0.0, 0.0)),           # the uppercut's start, low by the knee
    "fist_up": ((0.0, 0.92, 0.38), (0.0, -0.35, -0.94)),       # the uppercut's fist, the palm to the face
    "guard": ((0.45, 0.85, 0.25), (0.25, 0.0, -1.0)),          # a forearm guard: the fingers up and in, the palm to the face
    "point": ((-0.05, 0.25, 1.0), (1.0, 0.0, 0.0)),            # the leading arm pointed at the mark, the palm in
    "spear_back": ((0.0, 0.85, -0.5), (0.0, 0.55, 0.85)),      # the spear's cock: the hand high behind the shoulder, the palm up-forward
    "spear_go": ((0.0, 0.55, 0.85), (0.0, -0.85, 0.55)),       # its letting go, the palm forward and down
    "spear_after": ((0.35, -0.75, 0.55), (-0.2, -0.55, -0.8)), # its follow-through down across, the palm back
    "hatchet_back": ((-0.1, 0.9, -0.4), (0.0, 0.4, 0.92)),     # the tomahawk's cock out to the side, the palm forward, the wrist locked
    "hatchet_go": ((0.25, 0.55, 0.8), (0.97, 0.0, -0.25)),     # let go flat in front, the palm in
    "hatchet_after": ((0.95, 0.1, 0.25), (0.25, -0.2, -0.95)), # its follow-through across to the left, the palm back
    "flick_back": ((0.0, -0.9, -0.4), (0.0, -0.4, 0.92)),      # the atlatl flick's back swing, the palm forward
    "flick_go": ((0.0, 0.25, 1.0), (0.0, 1.0, -0.25)),         # let go at the waist, the palm up
    "flick_after": ((0.0, 0.85, 0.5), (0.0, 0.5, -0.85)),      # rising on, the palm up and back
    "flail": ((-0.9, 0.35, 0.1), (0.0, -0.2, 1.0)),            # an arm thrown out wide, the palm forward
    "brace": ((-0.15, 0.25, 0.95), (0.0, -1.0, 0.25)),         # the hands out for the landing, the palms down
}

## The stand every clip starts and ends on (the rest pose keyed: the root a little down, the feet set a little wide and turned
## out, the arms hanging, the fingers half closed). Every channel a clip leaves out is the stand's.
STAND_FOOT_R = (-0.13, 0.077, -0.04)
STAND_PALM_R = (-0.19, 0.795, 0.06)
STAND = {
    "root": (0.0, -0.015, 0.0), "yaw": 0.0, "hips": 0.0, "roll": 0.0, "chest": 0.0, "side": 0.0, "twist": 0.0,
    "head": 0.0, "look": 0.0, "clav_r": (0.0, 0.0), "clav_l": (0.0, 0.0),
    "hand_r": STAND_PALM_R, "hand_l": (-STAND_PALM_R[0], STAND_PALM_R[1], STAND_PALM_R[2]),
    "face_r": "stand", "face_l": "stand", "pole_r": (-0.35, -0.1, -1.0), "pole_l": (0.35, -0.1, -1.0),
    "grip_r": 0.4, "grip_l": 0.4,
    "foot_r": STAND_FOOT_R, "foot_l": (-STAND_FOOT_R[0], STAND_FOOT_R[1], STAND_FOOT_R[2]),
    "fyaw_r": 7.0, "fyaw_l": 7.0, "heel_r": 0.0, "heel_l": 0.0, "knee_r": "auto", "knee_l": "auto",
}
FR, FL = STAND["foot_r"], STAND["foot_l"]
HR, HL = STAND["hand_r"], STAND["hand_l"]

CLIPS = {
    # ---------------------------------------------------------------- earth
    "earth_stomp": {
        "length": 42, "meta": {"hold_s": 10 / FPS, "strike_s": 14 / FPS, "back_s": 27 / FPS, "hand": "foot_r", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (9, (0.07, -0.05, -0.01)), (11, (0.075, -0.045, -0.01)), (14, (-0.075, -0.17, 0.0)),
                 (17, (-0.075, -0.205, 0.0)), (27, (-0.075, -0.19, 0.0)), (33, (-0.01, -0.06, 0.0)), (42, (0, -0.015, 0))],
        "roll": [(0, 0), (9, -5), (11, -5), (14, 0), (42, 0)],
        "hips": [(0, 0), (9, -3), (11, -3), (14, 3), (17, 5), (27, 4), (42, 0)],
        "chest": [(0, 0), (9, -6), (11, -6), (14, 2), (17, 4), (27, 3), (42, 0)],
        "side": [(0, 0), (9, 4), (11, 4), (14, 0), (42, 0)],
        "head": [(0, 0), (9, 4), (11, 4), (14, -2), (17, 2), (27, 0), (42, 0)],
        "clav_r": [(0, (0, 0)), (9, (6, -8)), (14, (2, 8)), (27, (2, 6)), (42, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (6, -8)), (14, (2, 8)), (27, (2, 6)), (42, (0, 0))],
        "hand_r": [(0, HR), (9, (-0.06, 1.22, 0.24)), (11, (-0.06, 1.24, 0.24)), (14, (-0.4, 0.76, 0.24)),
                   (17, (-0.43, 0.71, 0.24)), (27, (-0.42, 0.72, 0.24)), (42, HR)],
        "hand_l": [(0, HL), (9, (0.06, 1.22, 0.24)), (11, (0.06, 1.24, 0.24)), (14, (0.4, 0.76, 0.24)),
                   (17, (0.43, 0.71, 0.24)), (27, (0.42, 0.72, 0.24)), (42, HL)],
        "face_r": [(0, "stand"), (6, "fist_gather"), (11, "fist_gather"), (14, "fist_down"), (30, "fist_down"), (42, "stand")],
        "face_l": [(0, "stand"), (6, "fist_gather"), (11, "fist_gather"), (14, "fist_down"), (30, "fist_down"), (42, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (9, (-1.0, -0.2, -0.2)), (14, (-1.0, 0.1, -0.5)), (42, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (9, (1.0, -0.2, -0.2)), (14, (1.0, 0.1, -0.5)), (42, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, 1.0), (32, 1.0), (42, 0.4)],
        "grip_l": [(0, 0.4), (6, 1.0), (32, 1.0), (42, 0.4)],
        # the right knee drawn up high, the foot hanging under it, then driven down out wide; brought back in at the end
        "foot_r": [(0, FR), (4, (-0.14, 0.12, 0.0)), (9, (-0.12, 0.48, 0.3)), (11, (-0.12, 0.5, 0.31)), (14, (-0.31, 0.077, 0.03)),
                   (30, (-0.31, 0.077, 0.03)), (34, (-0.22, 0.14, -0.01)), (38, FR), (42, FR)],
        "fyaw_r": [(0, 7), (9, 0), (14, 22), (30, 22), (38, 7)],
        "heel_r": [(0, 0), (4, 15), (9, -10), (11, -10), (13, -4), (14, 0), (42, 0)],
        "knee_r": [(0, "auto"), (4, (-0.2, 0.0, 1.0)), (34, (-0.2, 0.0, 1.0)), (38, "auto")],
        "foot_l": [(0, FL), (42, FL)],
        "fyaw_l": [(0, 7), (9, 10), (14, 22), (30, 22), (40, 7)],
        "knee_l": [(0, "auto"), (14, (0.45, 0.0, 1.0)), (30, (0.45, 0.0, 1.0)), (40, "auto")],
    },
    "earth_push": {
        "length": 40, "meta": {"hold_s": 9 / FPS, "strike_s": 13 / FPS, "back_s": 24 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (8, (-0.03, -0.07, -0.07)), (9, (-0.03, -0.075, -0.065)), (13, (0.0, -0.13, 0.15)),
                 (16, (0.0, -0.14, 0.17)), (24, (0.0, -0.13, 0.15)), (32, (0.0, -0.05, 0.03)), (40, (0, -0.015, 0))],
        "yaw": [(0, 0), (8, -8), (13, 6), (24, 4), (40, 0)],
        "hips": [(0, 0), (8, -4), (13, 7), (16, 9), (24, 7), (40, 0)],
        "chest": [(0, 0), (8, -6), (13, 9), (16, 12), (24, 8), (40, 0)],
        "twist": [(0, 0), (8, -6), (13, 4), (24, 3), (40, 0)],
        "head": [(0, 0), (8, -3), (13, -2), (16, 0), (40, 0)],
        "clav_r": [(0, (0, 0)), (8, (-8, 4)), (13, (14, -2)), (16, (16, -2)), (24, (13, -2)), (40, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (-8, 4)), (13, (14, -2)), (16, (16, -2)), (24, (13, -2)), (40, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.2, 0.95, 0.0)), (8, (-0.18, 1.02, -0.06)), (9, (-0.18, 1.03, -0.05)), (11, (-0.15, 1.1, 0.3)),
                   (13, (-0.13, 1.15, 0.66)), (16, (-0.13, 1.14, 0.71)), (24, (-0.13, 1.13, 0.67)), (31, (-0.2, 0.95, 0.25)), (40, HR)],
        "hand_l": [(0, HL), (5, (0.2, 0.95, 0.0)), (8, (0.18, 1.02, -0.06)), (9, (0.18, 1.03, -0.05)), (11, (0.15, 1.1, 0.3)),
                   (13, (0.13, 1.15, 0.66)), (16, (0.13, 1.14, 0.71)), (24, (0.13, 1.13, 0.67)), (31, (0.2, 0.95, 0.25)), (40, HL)],
        "face_r": [(0, "stand"), (5, "chamber"), (9, "chamber"), (12, "push"), (27, "push"), (40, "stand")],
        "face_l": [(0, "stand"), (5, "chamber"), (9, "chamber"), (12, "push"), (27, "push"), (40, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (9, (-0.3, -0.4, -1.0)), (13, (-0.8, -0.6, -0.1)), (40, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (9, (0.3, -0.4, -1.0)), (13, (0.8, -0.6, -0.1)), (40, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, 0.15), (11, -0.45), (28, -0.45), (40, 0.4)],
        "grip_l": [(0, 0.4), (6, 0.15), (11, -0.45), (28, -0.45), (40, 0.4)],
        # the left foot lifts on the rock back and steps out into the bow stance; the back foot turns out and stays
        "foot_l": [(0, FL), (6, (0.14, 0.16, 0.02)), (9, (0.14, 0.17, 0.1)), (12, (0.15, 0.077, 0.36)), (27, (0.15, 0.077, 0.36)),
                   (30, (0.14, 0.15, 0.2)), (34, FL), (40, FL)],
        "heel_l": [(0, 0), (4, 12), (7, -6), (11, -6), (12, 0), (27, 0), (29, 10), (33, 0), (40, 0)],
        "fyaw_l": [(0, 7), (12, 4), (30, 4), (34, 7)],
        "knee_l": [(0, "auto"), (5, (0.15, 0.2, 1.0)), (32, (0.15, 0.2, 1.0)), (36, "auto")],
        "foot_r": [(0, FR), (12, (-0.15, 0.077, -0.08)), (30, (-0.15, 0.077, -0.08)), (36, FR)],
        "fyaw_r": [(0, 7), (12, 32), (30, 32), (36, 7)],
        "heel_r": [(0, 0), (40, 0)],
    },
    "earth_rise": {
        "length": 40, "meta": {"hold_s": 10 / FPS, "strike_s": 14 / FPS, "back_s": 25 / FPS, "hand": "r", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (9, (-0.02, -0.2, -0.03)), (10, (-0.02, -0.205, -0.03)), (14, (0.0, 0.02, 0.06)),
                 (17, (0.0, 0.045, 0.07)), (25, (0.0, 0.035, 0.06)), (33, (0.0, -0.03, 0.02)), (40, (0, -0.015, 0))],
        "yaw": [(0, 0), (9, -10), (14, 10), (17, 14), (25, 12), (40, 0)],
        "hips": [(0, 0), (9, 16), (14, 0), (17, -4), (25, -3), (40, 0)],
        "chest": [(0, 0), (9, 18), (14, -4), (17, -9), (25, -7), (40, 0)],
        "twist": [(0, 0), (9, -16), (14, 14), (17, 18), (25, 15), (40, 0)],
        "side": [(0, 0), (9, -6), (14, 4), (17, 6), (25, 5), (40, 0)],
        "head": [(0, 0), (9, -14), (14, -6), (17, -16), (25, -12), (40, 0)],
        "clav_r": [(0, (0, 0)), (9, (-6, 8)), (14, (6, -18)), (17, (8, -24)), (25, (6, -20)), (40, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (6, 0)), (14, (-8, 4)), (25, (-6, 4)), (40, (0, 0))],
        "hand_r": [(0, HR), (6, (-0.2, 0.6, 0.12)), (9, (-0.21, 0.5, 0.1)), (10, (-0.21, 0.5, 0.11)), (12, (-0.14, 0.95, 0.34)),
                   (14, (-0.08, 1.45, 0.38)), (17, (-0.06, 1.86, 0.3)), (25, (-0.06, 1.82, 0.29)), (32, (-0.2, 1.2, 0.2)), (40, HR)],
        "hand_l": [(0, HL), (6, (0.12, 1.05, 0.3)), (9, (0.11, 1.0, 0.36)), (10, (0.11, 1.0, 0.36)), (14, (0.19, 0.98, -0.02)),
                   (25, (0.19, 0.98, -0.02)), (40, HL)],
        "face_r": [(0, "stand"), (6, "fist_low"), (10, "fist_low"), (14, "fist_up"), (27, "fist_up"), (40, "stand")],
        "face_l": [(0, "stand"), (6, "guard"), (10, "guard"), (14, "chamber"), (27, "chamber"), (40, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (9, (-0.6, 0.0, -0.8)), (14, (-1.0, -0.2, 0.0)), (17, (-1.0, 0.2, 0.0)),
                   (40, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (9, (1.0, -0.5, 0.0)), (14, (0.3, -0.3, -1.0)), (40, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, 1.0), (30, 1.0), (40, 0.4)],
        "grip_l": [(0, 0.4), (6, 0.1), (11, 0.1), (14, 1.0), (30, 1.0), (40, 0.4)],
        # the right foot steps back a little for the coil, and in again at the end
        "foot_r": [(0, FR), (3, (-0.16, 0.12, -0.07)), (5, (-0.19, 0.077, -0.1)), (31, (-0.19, 0.077, -0.1)),
                   (34, (-0.16, 0.12, -0.07)), (37, FR), (40, FR)],
        "fyaw_r": [(0, 7), (9, 20), (14, 2), (17, -6), (25, -4), (31, 10), (37, 7)],
        "heel_r": [(0, 0), (2, 10), (5, 0), (11, 0), (14, 35), (17, 42), (25, 38), (30, 0), (33, 10), (36, 0)],
        "foot_l": [(0, FL), (40, FL)],
        "fyaw_l": [(0, 7), (9, 18), (14, 10), (40, 7)],
        "knee_l": [(0, "auto"), (9, (0.45, 0.0, 1.0)), (14, "auto")],
        "knee_r": [(0, "auto"), (9, (-0.45, 0.0, 1.0)), (14, "auto")],
    },
    # ---------------------------------------------------------------- the throws (new, our own: a spear's, a tomahawk's, an atlatl's)
    "throw_overhand": {
        "length": 36, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 10 / FPS, "back_s": 21 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.06, -0.06)), (10, (0.0, -0.08, 0.13)), (14, (0.0, -0.1, 0.18)),
                 (21, (0.0, -0.09, 0.16)), (29, (0.0, -0.04, 0.05)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -28), (10, 10), (14, 18), (21, 14), (36, 0)],
        "twist": [(0, 0), (6, -22), (10, 16), (14, 24), (21, 18), (36, 0)],
        "hips": [(0, 0), (6, -4), (10, 8), (14, 10), (21, 8), (36, 0)],
        "chest": [(0, 0), (6, -10), (10, 12), (14, 17), (21, 12), (36, 0)],
        "side": [(0, 0), (6, 8), (10, -4), (14, -6), (21, -4), (36, 0)],
        "head": [(0, 0), (6, -4), (10, -6), (14, -8), (21, -6), (36, 0)],
        "clav_r": [(0, (0, 0)), (6, (-8, -18)), (10, (10, -10)), (14, (14, 6)), (21, (10, 4)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (10, -6)), (10, (-4, 4)), (21, (-2, 2)), (36, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.3, 1.2, -0.12)), (6, (-0.2, 1.5, -0.48)), (8, (-0.2, 1.62, -0.12)), (10, (-0.1, 1.62, 0.5)),
                   (12, (0.0, 1.3, 0.62)), (14, (0.12, 0.98, 0.5)), (21, (0.12, 0.95, 0.45)), (29, (-0.12, 0.9, 0.2)), (36, HR)],
        "hand_l": [(0, HL), (3, (0.2, 1.1, 0.25)), (6, (0.15, 1.3, 0.5)), (8, (0.18, 1.22, 0.4)), (10, (0.24, 1.05, 0.1)),
                   (14, (0.24, 0.98, -0.02)), (21, (0.23, 0.98, 0.0)), (36, HL)],
        "face_r": [(0, "stand"), (4, "spear_back"), (7, "spear_back"), (10, "spear_go"), (14, "spear_after"), (24, "spear_after"),
                   (36, "stand")],
        "face_l": [(0, "stand"), (4, "point"), (7, "point"), (11, "chamber"), (24, "chamber"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.9, 0.2, -0.5)), (8, (-0.7, 0.2, 0.6)), (10, (-0.7, 0.4, 0.4)),
                   (14, (-0.9, 0.0, 0.2)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, -0.8, 0.0)), (10, (0.5, -0.3, -1.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.75), (9, 0.75), (10, 0.15), (14, 0.25), (28, 0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.35), (8, -0.35), (12, 0.8), (28, 0.8), (36, 0.4)],
        "foot_l": [(0, FL), (3, (0.13, 0.13, 0.02)), (5, (0.15, 0.1, 0.22)), (7, (0.16, 0.077, 0.34)), (24, (0.16, 0.077, 0.34)),
                   (28, (0.15, 0.13, 0.15)), (32, FL), (36, FL)],
        "heel_l": [(0, 0), (3, 10), (5, -8), (7, 0), (24, 0), (27, 12), (31, 0)],
        "fyaw_l": [(0, 7), (6, 14), (10, 4), (24, 4), (32, 7)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.3, 1.0)), (30, (0.2, 0.3, 1.0)), (33, "auto")],
        "foot_r": [(0, FR), (6, (-0.14, 0.077, -0.07)), (27, (-0.14, 0.077, -0.07)), (32, FR)],
        "fyaw_r": [(0, 7), (4, 45), (10, 30), (14, 8), (24, 8), (32, 7)],
        "heel_r": [(0, 0), (6, 0), (10, 25), (14, 45), (24, 40), (30, 0)],
    },
    "throw_sidearm": {
        "length": 36, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 21 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (-0.03, -0.11, -0.05)), (9, (0.0, -0.12, 0.1)), (14, (0.02, -0.12, 0.15)),
                 (21, (0.02, -0.11, 0.13)), (29, (0.0, -0.04, 0.04)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -38), (9, 8), (14, 30), (21, 26), (36, 0)],
        "twist": [(0, 0), (6, -26), (9, 12), (14, 28), (21, 22), (36, 0)],
        "hips": [(0, 0), (6, 6), (9, 9), (14, 9), (21, 7), (36, 0)],
        "chest": [(0, 0), (6, 4), (9, 8), (14, 10), (21, 8), (36, 0)],
        "side": [(0, 0), (6, 6), (9, -6), (14, -2), (21, -2), (36, 0)],
        "head": [(0, 0), (6, -6), (9, -8), (14, -6), (36, 0)],
        "clav_r": [(0, (0, 0)), (6, (-14, -4)), (9, (12, -4)), (14, (18, 2)), (21, (14, 2)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (12, 0)), (9, (-6, 2)), (21, (-4, 2)), (36, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.35, 1.0, 0.0)), (6, (-0.55, 1.22, -0.28)), (8, (-0.48, 1.2, 0.2)), (9, (-0.3, 1.18, 0.5)),
                   (11, (-0.02, 1.12, 0.6)), (14, (0.35, 1.05, 0.38)), (21, (0.34, 1.04, 0.34)), (29, (0.0, 0.92, 0.2)), (36, HR)],
        "hand_l": [(0, HL), (3, (0.2, 1.0, 0.2)), (6, (0.1, 1.2, 0.42)), (9, (0.24, 1.1, 0.15)), (14, (0.3, 0.98, -0.06)),
                   (21, (0.29, 0.98, -0.05)), (36, HL)],
        "face_r": [(0, "stand"), (4, "hatchet_back"), (7, "hatchet_back"), (9, "hatchet_go"), (14, "hatchet_after"),
                   (24, "hatchet_after"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "point"), (7, "point"), (11, "chamber"), (24, "chamber"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.4, -1.0, -0.6)), (9, (-0.3, -1.0, 0.0)), (14, (0.2, -1.0, 0.3)),
                   (24, (0.2, -1.0, 0.3)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, -0.8, 0.0)), (10, (0.5, -0.3, -1.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.85), (8, 0.85), (9, 0.2), (14, 0.3), (28, 0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.35), (8, -0.35), (12, 0.8), (28, 0.8), (36, 0.4)],
        "foot_l": [(0, FL), (3, (0.15, 0.12, 0.02)), (6, (0.2, 0.077, 0.24)), (24, (0.2, 0.077, 0.24)), (28, (0.17, 0.13, 0.1)),
                   (32, FL), (36, FL)],
        "heel_l": [(0, 0), (3, 10), (5, -6), (6, 0), (24, 0), (27, 12), (31, 0)],
        "fyaw_l": [(0, 7), (6, 20), (9, 10), (14, -6), (24, -6), (32, 7)],
        "knee_l": [(0, "auto"), (3, (0.3, 0.2, 1.0)), (30, (0.3, 0.2, 1.0)), (33, "auto")],
        "foot_r": [(0, FR), (6, (-0.15, 0.077, -0.07)), (27, (-0.15, 0.077, -0.07)), (32, FR)],
        "fyaw_r": [(0, 7), (6, 50), (9, 25), (14, -10), (24, -10), (32, 7)],
        "heel_r": [(0, 0), (6, 0), (9, 20), (14, 45), (24, 40), (30, 0)],
    },
    "throw_underhand": {
        "length": 34,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 19 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.13, -0.03)), (9, (0.0, -0.09, 0.1)), (13, (0.0, -0.02, 0.14)),
                 (19, (0.0, -0.025, 0.13)), (27, (0.0, -0.02, 0.04)), (34, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -14), (9, 4), (13, 8), (19, 6), (34, 0)],
        "twist": [(0, 0), (6, -16), (9, 6), (13, 10), (19, 8), (34, 0)],
        "hips": [(0, 0), (6, 16), (9, 8), (13, 0), (19, 0), (34, 0)],
        "chest": [(0, 0), (6, 16), (9, 6), (13, -4), (19, -3), (34, 0)],
        "side": [(0, 0), (6, -8), (9, -4), (13, 2), (34, 0)],
        "head": [(0, 0), (6, -14), (9, -6), (13, 0), (34, 0)],
        "clav_r": [(0, (0, 0)), (6, (-10, 4)), (9, (8, 2)), (13, (12, -10)), (19, (8, -8)), (34, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (8, 0)), (13, (-4, 0)), (34, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.24, 0.75, 0.05)), (6, (-0.26, 0.62, -0.32)), (8, (-0.2, 0.6, 0.2)), (9, (-0.15, 0.78, 0.48)),
                   (11, (-0.12, 1.15, 0.58)), (13, (-0.1, 1.28, 0.62)), (19, (-0.11, 1.25, 0.59)), (27, (-0.2, 1.0, 0.25)), (34, HR)],
        "hand_l": [(0, HL), (3, (0.2, 0.95, 0.2)), (6, (0.13, 1.08, 0.4)), (9, (0.2, 1.02, 0.25)), (13, (0.23, 1.0, 0.05)),
                   (19, (0.22, 1.0, 0.05)), (34, HL)],
        "face_r": [(0, "stand"), (4, "flick_back"), (7, "flick_back"), (9, "flick_go"), (13, "flick_after"), (22, "flick_after"),
                   (34, "stand")],
        "face_l": [(0, "stand"), (4, "point"), (7, "point"), (12, "chamber"), (22, "chamber"), (34, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.5, 0.2, -1.0)), (9, (-0.6, -1.0, -0.2)), (13, (-0.8, -0.6, 0.2)),
                   (34, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.7, -0.7, 0.0)), (12, (0.5, -0.3, -1.0)), (34, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.7), (8, 0.7), (9, 0.1), (13, 0.05), (26, 0.1), (34, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.3), (8, -0.3), (12, 0.7), (26, 0.7), (34, 0.4)],
        "foot_l": [(0, FL), (3, (0.13, 0.12, 0.04)), (5, (0.14, 0.077, 0.26)), (22, (0.14, 0.077, 0.26)), (26, (0.14, 0.13, 0.1)),
                   (30, FL), (34, FL)],
        "heel_l": [(0, 0), (3, 10), (4, -6), (5, 0), (22, 0), (25, 12), (29, 0)],
        "fyaw_l": [(0, 7), (5, 8), (30, 7)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.2, 1.0)), (28, (0.2, 0.2, 1.0)), (31, "auto")],
        "foot_r": [(0, FR), (5, (-0.14, 0.077, -0.06)), (25, (-0.14, 0.077, -0.06)), (30, FR)],
        "fyaw_r": [(0, 7), (5, 25), (9, 15), (13, 8), (30, 7)],
        "heel_r": [(0, 0), (6, 0), (9, 20), (13, 40), (20, 35), (28, 0)],
    },
    # ---------------------------------------------------------------- the knocks
    "knock_slide": {
        "length": 36, "meta": {"strike_s": 1 / FPS, "hold_s": 9 / FPS, "back_s": 21 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, -0.03, -0.08)), (9, (0.0, -0.17, -0.03)), (15, (0.0, -0.18, -0.03)),
                 (21, (0.0, -0.17, -0.03)), (29, (0.0, -0.05, 0.0)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (9, 12), (21, 12), (36, 0)],
        "hips": [(0, 0), (3, -6), (9, 14), (15, 16), (21, 14), (36, 0)],
        "chest": [(0, 0), (3, -18), (9, 10), (15, 12), (21, 10), (36, 0)],
        "twist": [(0, 0), (9, 8), (21, 8), (36, 0)],
        "head": [(0, 0), (3, 14), (6, -6), (9, 2), (15, 4), (21, 2), (36, 0)],
        "clav_r": [(0, (0, 0)), (3, (10, -6)), (9, (10, 0)), (21, (10, 0)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (3, (10, -6)), (9, (10, 0)), (21, (10, 0)), (36, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.26, 1.12, 0.32)), (9, (-0.08, 1.22, 0.36)), (15, (-0.08, 1.2, 0.36)), (21, (-0.08, 1.2, 0.35)),
                   (29, (-0.2, 0.95, 0.18)), (36, HR)],
        "hand_l": [(0, HL), (3, (0.26, 1.12, 0.32)), (9, (0.1, 1.3, 0.3)), (15, (0.1, 1.28, 0.3)), (21, (0.1, 1.28, 0.29)),
                   (29, (0.2, 0.95, 0.18)), (36, HL)],
        "face_r": [(0, "stand"), (3, "push"), (8, "guard"), (24, "guard"), (36, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (8, "guard"), (24, "guard"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (3, (-0.6, -0.5, -0.4)), (9, (-0.6, -1.0, 0.1)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (3, (0.6, -0.5, -0.4)), (9, (0.6, -1.0, 0.1)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 0.05), (8, 0.9), (26, 0.9), (36, 0.4)],
        "grip_l": [(0, 0.4), (3, 0.05), (8, 0.9), (26, 0.9), (36, 0.4)],
        # the feet slide apart on the ground (never lifted), the left ahead, the right behind turned out
        "foot_l": [(0, FL), (9, (0.17, 0.077, 0.2)), (24, (0.17, 0.077, 0.2)), (28, (0.15, 0.12, 0.08)), (32, FL), (36, FL)],
        "fyaw_l": [(0, 7), (9, 12), (24, 12), (32, 7)],
        "heel_l": [(0, 0), (3, -12), (8, 0), (24, 0), (27, 10), (31, 0)],
        "foot_r": [(0, FR), (9, (-0.19, 0.077, -0.24)), (24, (-0.19, 0.077, -0.24)), (31, (-0.16, 0.12, -0.12)), (34, FR), (36, FR)],
        "fyaw_r": [(0, 7), (9, 38), (24, 38), (34, 7)],
        "heel_r": [(0, 0), (3, -10), (8, 0), (28, 0), (30, 10), (33, 0)],
        "knee_l": [(0, "auto"), (9, (0.35, 0.0, 1.0)), (26, (0.35, 0.0, 1.0)), (32, "auto")],
        "knee_r": [(0, "auto"), (9, (-0.6, 0.0, 1.0)), (26, (-0.6, 0.0, 1.0)), (32, "auto")],
    },
    "knock_air": {
        "length": 44, "meta": {"strike_s": 1 / FPS, "hold_s": 10 / FPS, "up_s": 26 / FPS, "back_s": 30 / FPS, "hand": "both",
                               "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, 0.04, -0.05)), (10, (0.0, 0.03, -0.04)), (20, (0.0, 0.02, -0.03)),
                 (24, (0.0, 0.0, 0.0)), (26, (0.0, -0.1, 0.02)), (29, (0.0, -0.21, 0.04)), (30, (0.0, -0.21, 0.04)),
                 (38, (0.0, -0.05, 0.01)), (44, (0, -0.015, 0))],
        "hips": [(0, 0), (3, -14), (10, -26), (16, -24), (20, -20), (24, -2), (26, 8), (29, 20), (30, 20), (44, 0)],
        "chest": [(0, 0), (3, -22), (10, -6), (16, -2), (20, -4), (24, 4), (26, 12), (29, 22), (30, 22), (44, 0)],
        "roll": [(0, 0), (10, 6), (16, -4), (20, 0), (44, 0)],
        "twist": [(0, 0), (10, -8), (16, 6), (20, 0), (44, 0)],
        "head": [(0, 0), (3, 22), (10, 18), (16, 16), (24, 10), (26, 2), (29, -4), (44, 0)],
        "clav_r": [(0, (0, 0)), (3, (-8, -14)), (10, (-4, -20)), (16, (0, -12)), (24, (8, 0)), (30, (10, 4)), (44, (0, 0))],
        "clav_l": [(0, (0, 0)), (3, (-8, -14)), (10, (2, -12)), (16, (-6, -20)), (24, (8, 0)), (30, (10, 4)), (44, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.45, 1.42, -0.02)), (10, (-0.55, 1.4, 0.12)), (16, (-0.5, 1.5, -0.08)), (20, (-0.48, 1.3, 0.12)),
                   (24, (-0.38, 1.0, 0.3)), (29, (-0.3, 0.75, 0.42)), (30, (-0.3, 0.75, 0.42)), (37, (-0.22, 0.9, 0.2)), (44, HR)],
        "hand_l": [(0, HL), (3, (0.45, 1.42, -0.02)), (10, (0.5, 1.5, -0.06)), (16, (0.55, 1.38, 0.14)), (20, (0.48, 1.3, 0.12)),
                   (24, (0.38, 1.0, 0.3)), (29, (0.3, 0.75, 0.42)), (30, (0.3, 0.75, 0.42)), (37, (0.22, 0.9, 0.2)), (44, HL)],
        "face_r": [(0, "stand"), (3, "flail"), (20, "flail"), (25, "brace"), (32, "brace"), (44, "stand")],
        "face_l": [(0, "stand"), (3, "flail"), (20, "flail"), (25, "brace"), (32, "brace"), (44, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (3, (-0.2, -0.6, -1.0)), (20, (-0.2, -0.6, -1.0)), (26, (-0.8, -0.4, -0.3)),
                   (44, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (3, (0.2, -0.6, -1.0)), (20, (0.2, -0.6, -1.0)), (26, (0.8, -0.4, -0.3)),
                   (44, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.4), (20, -0.3), (26, -0.2), (34, 0.2), (44, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.4), (20, -0.3), (26, -0.2), (34, 0.2), (44, 0.4)],
        # off the ground: the knees come up and forward (left and right a little out of step), then reach down for the landing
        "foot_r": [(0, FR), (3, (-0.14, 0.2, 0.05)), (10, (-0.17, 0.42, 0.3)), (16, (-0.16, 0.36, 0.22)), (20, (-0.16, 0.34, 0.18)),
                   (24, (-0.17, 0.15, 0.06)), (26, (-0.18, 0.077, 0.02)), (36, (-0.18, 0.077, 0.02)), (40, FR), (44, FR)],
        "foot_l": [(0, FL), (3, (0.14, 0.14, 0.0)), (10, (0.16, 0.34, 0.2)), (16, (0.17, 0.42, 0.3)), (20, (0.16, 0.34, 0.18)),
                   (24, (0.17, 0.15, 0.06)), (26, (0.18, 0.077, 0.02)), (36, (0.18, 0.077, 0.02)), (40, FL), (44, FL)],
        "heel_r": [(0, 0), (3, 25), (10, 30), (20, 30), (24, 15), (26, 0), (44, 0)],
        "heel_l": [(0, 0), (3, 25), (10, 30), (20, 30), (24, 15), (26, 0), (44, 0)],
        "fyaw_r": [(0, 7), (10, 12), (26, 18), (36, 18), (40, 7)],
        "fyaw_l": [(0, 7), (10, 12), (26, 18), (36, 18), (40, 7)],
        "knee_r": [(0, "auto"), (3, (-0.25, 0.3, 1.0)), (36, (-0.35, 0.0, 1.0)), (40, "auto")],
        "knee_l": [(0, "auto"), (3, (0.25, 0.3, 1.0)), (36, (0.35, 0.0, 1.0)), (40, "auto")],
    },
}

## The installed names (install_bend.gd reads them from the json): own-bend-<element | throw | knock>-<name>, the mirrored twin
## with -l.
def game_name(key):
    if key.endswith("_l"):
        return "own-bend-" + key[:-2].replace("_", "-") + "-l"
    return "own-bend-" + key.replace("_", "-")


# ---------------------------------------------------------------- interpolation
def _cubic(xs, ys, x):
    """A monotone cubic (Fritsch-Carlson) through the keys: no overshoot, and the motion carries through a key unless the
    neighbours hold it (a value repeated)."""
    n = len(xs)
    if n == 1 or x <= xs[0]:
        return ys[0]
    if x >= xs[-1]:
        return ys[-1]
    d = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
    m = [d[0]] + [0.0 if d[i - 1] * d[i] <= 0 else (d[i - 1] + d[i]) / 2 for i in range(1, n - 1)] + [d[-1]]
    m[0] = 0.0
    m[-1] = 0.0
    for i in range(n - 1):
        if d[i] == 0:
            m[i] = 0.0
            m[i + 1] = 0.0
        else:
            a, b = m[i] / d[i], m[i + 1] / d[i]
            s = a * a + b * b
            if s > 9:
                t = 3 / math.sqrt(s)
                m[i], m[i + 1] = t * a * d[i], t * b * d[i]
    for i in range(n - 1):
        if xs[i] <= x <= xs[i + 1]:
            h = xs[i + 1] - xs[i]
            t = (x - xs[i]) / h
            h00, h10 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t
            h01, h11 = -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
            return h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]
    return ys[-1]


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


def chan(clip, key):
    return clip.get(key) or [(0, STAND[key])]


def num(clip, key, f):
    keys = chan(clip, key)
    xs = [k[0] for k in keys]
    v0 = keys[0][1]
    if isinstance(v0, (tuple, list)):
        return Vector([_cubic(xs, [k[1][i] for k in keys], f) for i in range(len(v0))])
    return _cubic(xs, [float(k[1]) for k in keys], f)


def q_axis(axis, deg):
    return Quaternion(Vector(axis), math.radians(deg))


def mirror_v(v):
    return Vector((-v[0], v[1], v[2]))


# ---------------------------------------------------------------- the rig
REST = {nm: SK.rest_q[nm].copy() for nm in SK.names}
ROOT_REST = SK.rest_t["root"].copy()
P_REST, G_REST = SK.fk(REST, ROOT_REST)


def gq(rots, nm):
    """A bone's global rotation (its chain's product; no positions)."""
    q = Quaternion()
    chain = []
    while nm is not None:
        chain.append(nm)
        nm = SK.parent.get(nm)
    for c in reversed(chain):
        q = q @ rots[c]
    return q


def turn(rots, bone, q):
    """Bone `bone` turned by the global rotation `q` (its children with it)."""
    par = SK.parent[bone]
    gp = gq(rots, par)
    rots[bone] = gp.inverted() @ (q @ gp @ rots[bone])


def set_global(rots, bone, q):
    rots[bone] = gq(rots, SK.parent[bone]).inverted() @ q


def hand_frame(side):
    """The hand's own axes in its wrist's frame at the rest: the fingers' way (to the middle knuckle) and the palm's (the side the
    fingers close toward)."""
    w = side + "_wrist"
    inv = G_REST[w].inverted()
    fing = (P_REST[side + "_middlea"] - P_REST[w]).normalized()
    across = (P_REST[side + "_indexa"] - P_REST[side + "_pinkyb"]).normalized()
    n = fing.cross(across).normalized()
    tip = P_REST[side + "_middlec"] - P_REST[side + "_middlea"]
    bend = tip - fing * tip.dot(fing)
    if bend.length > 0.004:
        if n.dot(bend) < 0:
            n = -n
    else:
        medial = Vector((-1.0 if P_REST[w].x > 0 else 1.0, 0.0, 0.0))
        if n.dot(medial) < 0:
            n = -n
    return inv @ fing, inv @ n


HAND_LOCAL = {s: hand_frame(s) for s in "lr"}
## A joint's child along its finger (the thumb's line is from a joint to the next).
CHILD = {SK.parent[n]: n for n in SK.names if SK.parent.get(n) and "thumb" in n and "thumb" in SK.parent[n]}


def basis(f, n):
    f = Vector(f).normalized()
    n = (Vector(n) - f * Vector(n).dot(f)).normalized()
    return Matrix((f, n, f.cross(n))).transposed()


def facing_q(side, v):
    """The wrist's global rotation for a facing: a name (the right hand's, mirrored for the left) or ((fingers), (palm))."""
    f, n = FACING[v] if isinstance(v, str) else v
    if side == "l" and isinstance(v, str):
        f, n = mirror_v(f), mirror_v(n)
    fl, nl = HAND_LOCAL[side]
    return (basis(f, n) @ basis(fl, nl).inverted()).to_quaternion().normalized()


def facing_at(clip, side, f):
    a, b, u = seg(chan(clip, "face_" + side), f)
    qa, qb = facing_q(side, a), facing_q(side, b)
    if qa.dot(qb) < 0:
        qb = -qb
    return qa.slerp(qb, u)


def finger_axes(rots, side):
    """The knuckles' line (the fingers close about it) and the palm's way, global, from the wrist's rotation now."""
    gw = gq(rots, side + "_wrist")
    fl, nl = HAND_LOCAL[side]
    f, n = gw @ fl, gw @ nl
    return f.cross(n).normalized(), n


def knee_pole(clip, side, f, hip, yaw_deg):
    a, b, u = seg(chan(clip, "knee_" + side), f)
    sg = 1.0 if side == "l" else -1.0
    auto = q_axis((0, 1, 0), sg * yaw_deg) @ Vector((sg * 0.18, 0.0, 1.0))

    def val(v):
        return auto.normalized() if isinstance(v, str) else Vector(v).normalized()
    return hip + val(a).lerp(val(b), u).normalized()


# ---------------------------------------------------------------- one frame
def pose(clip, f):
    rots = {k: v.copy() for k, v in REST.items()}
    root = ROOT_REST + num(clip, "root", f)
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    yaw, twist = num(clip, "yaw", f), num(clip, "twist", f)
    qyaw = q_axis(Y, yaw)
    # the whole body: the yaw, the hips' bow and tilt (the legs are planted again below)
    rots["root"] = qyaw @ q_axis(X, num(clip, "hips", f)) @ q_axis(Z, num(clip, "roll", f)) @ rots["root"]
    # the spine: its turn, then its pitch and side bend about the turned body's own axes, a share a vertebra
    for nm, share in SPINE:
        turn(rots, nm, q_axis(Y, twist * share))
    qbody = q_axis(Y, yaw + twist)
    for nm, share in SPINE:
        turn(rots, nm, q_axis(qbody @ X, num(clip, "chest", f) * share) @ q_axis(qbody @ Z, num(clip, "side", f) * share))
    # the head: kept on the mark through the body's turn (look turns it), its pitch about its own facing
    look = num(clip, "look", f)
    for nm, share in NECK:
        turn(rots, nm, q_axis(Y, (-(yaw + twist) * 0.8 + look) * share))
    qhead = q_axis(Y, (yaw + twist) * 0.2 + look)
    for nm, share in NECK:
        turn(rots, nm, q_axis(qhead @ X, num(clip, "head", f) * share))
    for s, sg in (("l", -1.0), ("r", 1.0)):
        cl = num(clip, "clav_" + s, f)
        turn(rots, s + "_clavicle", q_axis(qbody @ Y, sg * cl.x) @ q_axis(qbody @ Z, sg * cl.y))
    # the legs: each ankle to its place, the foot turned out and its heel lifted about the ball (the toes kept on the ground
    # when it is down), the knee toward its pole
    P, G = SK.fk(rots, root)
    for s in "lr":
        sg = 1.0 if s == "l" else -1.0
        fa, fb, fu = seg(chan(clip, "foot_" + s), f)
        place = num(clip, "foot_" + s, f)
        fyaw = num(clip, "fyaw_" + s, f)
        heel = num(clip, "heel_" + s, f)
        qy = q_axis(Y, sg * fyaw)
        lat = qy @ X
        ball0 = P_REST[s + "_ball"] - P_REST[s + "_ankle"]           # the ball from the ankle, the foot flat (world)
        ball = place + qy @ ball0
        qh = q_axis(lat, heel)
        pivot = ball if heel >= 0 else place + qy @ (P_REST[s + "_heel"] - P_REST[s + "_ankle"])
        ankle = pivot + qh @ (place - pivot)
        ga = qh @ qy @ G_REST[s + "_ankle"]
        P, G = SK.fk(rots, root)
        hip = P[s + "_upper_leg"]
        for _ in range(2):
            rigkit.ik2(rots, root, s + "_upper_leg", s + "_knee", s + "_ankle", ankle, knee_pole(clip, s, f, hip, fyaw))
        set_global(rots, s + "_ankle", ga)
        # the toes flat on the ground while the ball is on it, else with the foot
        on = 1.0 - smooth((ball.y - 0.04) / 0.08)
        gb = (qy @ G_REST[s + "_ball"]).slerp(qh @ qy @ G_REST[s + "_ball"], 1.0 - on) if heel > 0 else qh @ qy @ G_REST[s + "_ball"]
        set_global(rots, s + "_ball", gb)
    # the arms: each palm to its place, facing its way, the elbow toward its pole
    for s in "lr":
        gw = facing_at(clip, s, f)
        a, b, u = seg(chan(clip, "hand_" + s), f)
        palm_t = num(clip, "hand_" + s, f)
        wrist_t = palm_t - gw @ SK.rest_t[s + "_palm"]
        pole_v = num(clip, "pole_" + s, f)
        for _ in range(2):
            P, G = SK.fk(rots, root)
            rigkit.ik2(rots, root, s + "_shoulder", s + "_elbow", s + "_wrist", wrist_t, P[s + "_shoulder"] + pole_v)
        set_global(rots, s + "_wrist", gw)
        # the fingers: closed about the knuckles' line toward the palm by the grip (a share of a fist's), each joint after its
        # parent (the thumb about its own line)
        g = max(-0.6, min(1.0, num(clip, "grip_" + s, f)))
        k, n = finger_axes(rots, s)
        for dg, joints in CURL.items():
            for j, deg in joints.items():
                nm = "%s_%s%s" % (s, dg, j)
                if nm not in rots:
                    continue
                if dg == "thumb":
                    tdir = (gq(rots, nm) @ SK.rest_t[CHILD.get(nm, nm)]).normalized() if nm in CHILD else \
                        (gq(rots, SK.parent[nm]) @ SK.rest_t[nm]).normalized()
                    axis = tdir.cross(n)
                    if axis.length < 1e-4:
                        continue
                    turn(rots, nm, q_axis(axis.normalized(), deg * g))
                else:
                    turn(rots, nm, q_axis(k, deg * g))
    return rots, root


def keyed():
    out = ["root", "spinea", "spineb", "spinec", "spined", "neck", "heada", "headb"]
    out += [n for n in STILL if n in SK.rest_q]
    for s in "lr":
        out += ["%s_%s" % (s, b) for b in ARM + LEG if "%s_%s" % (s, b) in SK.rest_q]
        out += ["%s_%s" % (s, n) for n in STILL if "%s_%s" % (s, n) in SK.rest_q]
        out += ["%s_%s%s" % (s, dg, j) for dg, js in CURL.items() for j in js if "%s_%s%s" % (s, dg, j) in SK.rest_q]
    seen, res = set(), []
    for n in out:
        if n not in seen:
            seen.add(n)
            res.append(n)
    return res


# ---------------------------------------------------------------- the mirrored twin
SIDED = ["clav", "hand", "face", "pole", "grip", "foot", "fyaw", "heel", "knee"]


def mirror_clip(clip):
    """The clip's twin for the other hand: the sides swapped, every place mirrored across the body's middle, every turn
    reversed (a named facing mirrors itself, being the right hand's for the right and mirrored for the left)."""
    out = {"length": clip["length"], "meta": dict(clip["meta"])}
    h = out["meta"].get("hand")
    if isinstance(h, str):
        out["meta"]["hand"] = {"r": "l", "l": "r", "foot_r": "foot_l", "foot_l": "foot_r"}.get(h, h)

    def mv(v):
        if isinstance(v, str):
            return v
        if isinstance(v, tuple) and len(v) == 2 and isinstance(v[0], tuple):
            return (tuple(mirror_v(v[0])), tuple(mirror_v(v[1])))
        if isinstance(v, tuple) and len(v) == 3:
            return (-v[0], v[1], v[2])
        return v
    for key, keys in clip.items():
        if key in ("length", "meta", "mirror"):
            continue
        if key in ("yaw", "twist", "roll", "side", "look"):
            out[key] = [(fr, -v) for fr, v in keys]
        elif key == "root":
            out[key] = [(fr, mv(v)) for fr, v in keys]
        elif "_" in key and key.split("_")[0] in SIDED:
            base, s = key.rsplit("_", 1)
            other = base + "_" + ("l" if s == "r" else "r")
            out[other] = [(fr, mv(v)) for fr, v in keys]
        else:
            out[key] = list(keys)
    return out


def all_clips():
    out = {}
    for name, clip in CLIPS.items():
        out[name] = clip
        if clip.get("mirror"):
            out[name + "_l"] = mirror_clip(clip)
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
        report.append((f, [round(x, 3) for x in P["r_palm"]], [round(x, 3) for x in P["l_palm"]], round(P["pelvis"].y, 3),
                       [round(x, 3) for x in P["r_ankle"]], [round(x, 3) for x in P["l_ankle"]],
                       round(max([d for _, d in rigkit.MISS] or [0.0]), 3)))
    return frames, roots, report


# ---------------------------------------------------------------- the .blend to open and refine
def keep_blend(path, baked):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB, bone_heuristic="FORTUNE")
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
    ap.add_argument("--glb", default=None)
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args(argv)
    only = [c for c in a.clips.split(",") if c]
    out = {"fps": FPS, "clips": {}, "names": {},
           "about": "tools/anim_author/blender/bend_clips.py: our own ring-sport casts and knocks, key poses IK-solved on Actor_B's "
                    "rig in Blender from the rig's rest pose (no library clip read)"}
    baked = {}
    print("BEND rest r_shoulder %s r_palm %s  hand axes r %s" % ([round(x, 3) for x in P_REST["r_shoulder"]],
                                                                  [round(x, 3) for x in P_REST["r_palm"]],
                                                                  [[round(x, 3) for x in v] for v in HAND_LOCAL["r"]]))
    for name, clip in all_clips().items():
        if only and name not in only and name.removesuffix("_l") not in only:
            continue
        frames, roots, report = bake(clip)
        meta = dict(clip["meta"])
        meta["length_frames"] = clip["length"]
        out["clips"][name] = {"frames": frames, "root": roots, "meta": meta}
        out["names"][name] = game_name(name)
        baked[name] = (frames, roots)
        worst = max(r[-1] for r in report)
        print("BEND %s -> %s: %d frames, worst IK miss %.3f m" % (name, game_name(name), len(frames), worst))
        if not a.quiet:
            for r in report:
                print("   f%02d  r_palm %s  l_palm %s  pelvis %.3f  r_ankle %s  l_ankle %s  miss %.3f" % r)
    json.dump(out, open(a.out, "w"))
    print("BEND baked %d clips -> %s" % (len(out["clips"]), a.out))
    if a.blend:
        keep_blend(a.blend, baked)
        print("BEND blend -> %s" % a.blend)


if __name__ == "__main__":
    main()
