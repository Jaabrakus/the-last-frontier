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
The second set (2026-10-05, after the owner approved the first ten: "looks good but you can always perfect them"; the CLIPS
table's SET2 part, authored the same way; the first ten polished: the keys the IK had clamped straight pulled into reach, a
few settle keys, their hold_s and strike_s kept):
  stance_<element>   each element's idle loop while casting (meta loop: installed looping; no gait): earth Hung Gar's low wide
                     horse, the left forearm forward, breathing; fire up on the balls of the feet side-on, the fists up, a
                     bounce; water the weight flowing forward and back with the soft hands; air light, turning about the waist
  earth_boulder      the owner's "left kick to stomp and then push": the left foot kicks the rock up, the knee high, the foot
                     stamped down out ahead, the palms drawn back (held), the two-hand push.  strike_s: the push
  earth_raise        the stomp-rise (a wall or a column): the right foot stamped, sunk (held), the palms driven up
  earth_burrow       the side burrow-step: dropped low to the right, the palm by the ground, the dive
  earth_catch        the hands up and open (held), the rock caught and drawn in to the chest, held
  earth_shove        a heavy single palm from a bow stance (and its twin)
  fire_punch         the straight punch from the ribs (and its twin); fire_double the jab and the cross 0.15 s behind it;
  fire_kick          the chambered front snap kick set down ahead; fire_sweep the knife hand round flat (and its twin);
  fire_breath        the breath drawn in and driven out between the palms; fire_lightning the hands circling the charge
                     (a long hold) and both thrust out
  water_whip         drawn down behind the hip, over the shoulder, lashed out (and its twin); water_wave the palms sunk,
                     risen and pushed out wide; water_draw the circle out over the pool and up; water_shield crossed low,
                     risen apart before the face
  air_palm           the palm strike (and its twin); air_sweep both arms round flat in a circle; air_spin a whole turn on
                     the balls of the feet, the arms out (the spin channel); air_leap the crouch and spring; air_shield the
                     palms round a circle and pushed out
The third set (2026-10-05, round 2 of the skills; the CLIPS table's SET3 part, authored the same way; fire_kick, now the High
Kick, gains its twin with its keys unchanged; earth_catch re-keyed so the guard reads at a glance, its moments kept):
  fire_kick_low      the Kick's floor wave: sunk low on the left leg, the right foot drawn back off the deck (the low chamber, the
                     tell), swept round and in at the shin's height (and its twin); fire_fireball the Punch held to grow: a
                     deeper chamber, the hand far back by the hip, the palm driven out (and its twin); fire_parry the guard:
                     the knife hand stood up before the face, cut out ahead along the aim
  earth_kickup       Shove's kick-and-push: the boulder's kick mirrored and short, the toes up under the stone early (and its
                     twin); earth_uproot Column: the stamp ahead, the palms by the deck, swept up and out far ahead
  water_turn         the guard: both hands low by the right hip, swung round the body and flung out ahead; water_turn_hold its
                     loop (a ball of water rolled before the waist); water_surf the riding crouch (a loop, legs_always);
                     water_skate the skater's push-off (legs_always)
  air_pull           the palms out, dragged back to the hips with a step back; air_slip the circle walker's pivot step out to
                     the side (and its twin), air_slip_back stepping back round; air_wall the palms out flat and swept apart;
                     air_guard the guard: the arms round a circle (one palm high, one low), the palms bounced out together;
                     air_shield_hold its loop (the palms circling before the chest); air_slice the flat chop (and its twin)
  --fit lists the frames where a limb is within SLACK of straight (and its place pulled in) and the striking limb's slack
  at strike_s (and its place carried out to STRIKE_SLACK).
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
  spin        the whole figure turned about the vertical through the stand's middle, the feet's and the hands' places
              with it (a turn on the spot; + to the left)
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
A clip with "loop": True is a stance: its keys' last frame is its length and its first's values, interpolated across the seam
(meta loop "linear"). A clip with "mirror": True also bakes its twin, <name>_l, the same keys mirrored across the body's middle (left for right).

  Blender -b --factory-startup --python tools/anim_author/blender/bend_clips.py -- --out <bend.json> --blend <bend.blend>
      [--clips earth_stomp,throw_overhand] [--glb <actor_b_body.glb>] [--fit] [--quiet]
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
                 (17, (-0.075, -0.21, 0.0)), (20, (-0.075, -0.198, 0.0)), (27, (-0.075, -0.19, 0.0)), (33, (-0.01, -0.06, 0.0)),
                 (42, (0, -0.015, 0))],
        "roll": [(0, 0), (9, -5), (11, -5), (14, 1.5), (17, 0), (42, 0)],
        "hips": [(0, 0), (9, -3), (11, -3), (14, 3), (17, 6), (20, 4.5), (27, 4), (42, 0)],
        "chest": [(0, 0), (9, -6), (11, -6), (14, 2), (17, 6), (20, 3.5), (27, 3), (36, -1), (42, 0)],
        "side": [(0, 0), (9, 4), (11, 4), (14, 0), (42, 0)],
        "head": [(0, 0), (9, 4), (11, 4), (14, -2), (17, 2), (27, 0), (42, 0)],
        "clav_r": [(0, (0, 0)), (9, (6, -8)), (14, (2, 8)), (27, (2, 6)), (42, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (6, -8)), (14, (2, 8)), (27, (2, 6)), (42, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.12, 1.02, 0.18)), (9, (-0.06, 1.22, 0.24)), (11, (-0.06, 1.24, 0.24)), (14, (-0.4, 0.76, 0.24)),
                   (17, (-0.42, 0.715, 0.235)), (22, (-0.415, 0.72, 0.232)), (27, (-0.4, 0.73, 0.225)), (33, (-0.31, 0.78, 0.155)),
                   (42, HR)],
        "hand_l": [(0, HL), (5, (0.12, 1.02, 0.18)), (9, (0.06, 1.22, 0.24)), (11, (0.06, 1.24, 0.24)), (14, (0.375, 0.78, 0.225)),
                   (17, (0.388, 0.748, 0.22)), (22, (0.386, 0.75, 0.219)), (27, (0.378, 0.758, 0.215)), (33, (0.31, 0.78, 0.155)),
                   (42, HL)],
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
                   (13, (-0.13, 1.15, 0.66)), (16, (-0.13, 1.14, 0.7)), (24, (-0.13, 1.13, 0.66)), (31, (-0.2, 0.95, 0.25)), (40, HR)],
        "hand_l": [(0, HL), (5, (0.2, 0.95, 0.0)), (8, (0.18, 1.02, -0.06)), (9, (0.18, 1.03, -0.05)), (11, (0.15, 1.1, 0.3)),
                   (13, (0.13, 1.15, 0.66)), (16, (0.13, 1.14, 0.69)), (24, (0.13, 1.13, 0.655)), (31, (0.2, 0.95, 0.25)), (40, HL)],
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
        "root": [(0, (0, -0.015, 0)), (9, (-0.02, -0.2, -0.03)), (10, (-0.02, -0.205, -0.03)), (14, (0.0, -0.015, 0.055)),
                 (17, (0.0, -0.002, 0.065)), (25, (0.0, -0.01, 0.055)), (33, (0.0, -0.04, 0.02)), (40, (0, -0.015, 0))],
        "yaw": [(0, 0), (9, -10), (14, 10), (17, 14), (25, 12), (40, 0)],
        "hips": [(0, 0), (9, 16), (14, 0), (17, -4), (25, -3), (40, 0)],
        "chest": [(0, 0), (9, 18), (14, -4), (17, -9), (25, -7), (40, 0)],
        "twist": [(0, 0), (9, -16), (14, 14), (17, 18), (25, 15), (40, 0)],
        "side": [(0, 0), (9, -6), (14, 4), (17, 6), (25, 5), (40, 0)],
        "head": [(0, 0), (9, -14), (14, -6), (17, -16), (25, -12), (40, 0)],
        "clav_r": [(0, (0, 0)), (9, (-6, 8)), (14, (6, -18)), (17, (8, -24)), (25, (6, -20)), (40, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (6, 0)), (14, (-8, 4)), (25, (-6, 4)), (40, (0, 0))],
        "hand_r": [(0, HR), (6, (-0.195, 0.66, 0.115)), (9, (-0.205, 0.575, 0.1)), (10, (-0.205, 0.575, 0.107)),
                   (12, (-0.14, 0.95, 0.34)), (14, (-0.08, 1.42, 0.37)), (17, (-0.075, 1.77, 0.29)), (21, (-0.072, 1.76, 0.285)),
                   (25, (-0.07, 1.74, 0.28)), (32, (-0.2, 1.2, 0.2)), (40, HR)],
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
        "heel_l": [(0, 0), (12, 0), (16, 6), (25, 5), (30, 0), (40, 0)],
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
        "hand_l": [(0, HL), (3, (0.2, 1.1, 0.25)), (6, (0.15, 1.285, 0.465)), (8, (0.18, 1.22, 0.4)), (10, (0.24, 1.05, 0.1)),
                   (14, (0.24, 0.98, -0.02)), (21, (0.23, 0.98, 0.0)), (36, HL)],
        "face_r": [(0, "stand"), (4, "spear_back"), (7, "spear_back"), (10, "spear_go"), (14, "spear_after"), (24, "spear_after"),
                   (36, "stand")],
        "face_l": [(0, "stand"), (4, "point"), (7, "point"), (11, "chamber"), (24, "chamber"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.9, 0.2, -0.5)), (8, (-0.7, 0.2, 0.6)), (10, (-0.7, 0.4, 0.4)),
                   (14, (-0.9, 0.0, 0.2)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, -0.8, 0.0)), (10, (0.5, -0.3, -1.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.75), (9, 0.75), (10, 0.15), (14, 0.25), (28, 0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.35), (8, -0.35), (12, 0.8), (28, 0.8), (36, 0.4)],
        "foot_l": [(0, FL), (3, (0.13, 0.13, 0.02)), (5, (0.15, 0.1, 0.21)), (7, (0.16, 0.077, 0.32)), (24, (0.16, 0.077, 0.33)),
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
        "hand_r": [(0, HR), (3, (-0.35, 1.0, 0.0)), (6, (-0.525, 1.22, -0.27)), (8, (-0.48, 1.2, 0.2)), (9, (-0.3, 1.18, 0.5)),
                   (11, (-0.02, 1.12, 0.6)), (14, (0.35, 1.05, 0.38)), (21, (0.36, 1.0, 0.3)), (29, (0.0, 0.92, 0.2)), (36, HR)],
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
        "hips": [(0, 0), (6, 14), (9, 8), (13, 0), (19, 0), (34, 0)],
        "chest": [(0, 0), (6, 14), (9, 6), (13, -4), (19, -3), (34, 0)],
        "side": [(0, 0), (6, -8), (9, -4), (13, 2), (34, 0)],
        "head": [(0, 0), (6, -14), (9, -6), (13, 0), (34, 0)],
        "clav_r": [(0, (0, 0)), (6, (-10, 4)), (9, (8, 2)), (13, (12, -10)), (19, (8, -8)), (34, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (8, 0)), (13, (-4, 0)), (34, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.24, 0.76, 0.04)), (6, (-0.235, 0.71, -0.23)), (8, (-0.195, 0.68, 0.17)), (9, (-0.15, 0.8, 0.45)),
                   (11, (-0.12, 1.15, 0.57)), (13, (-0.1, 1.28, 0.6)), (19, (-0.11, 1.24, 0.57)), (27, (-0.2, 1.0, 0.25)), (34, HR)],
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
        "foot_l": [(0, FL), (3, (0.13, 0.12, 0.04)), (5, (0.14, 0.077, 0.25)), (22, (0.14, 0.077, 0.25)), (26, (0.14, 0.13, 0.1)),
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
        "hand_r": [(0, HR), (3, (-0.235, 1.14, 0.22)), (9, (-0.08, 1.22, 0.36)), (15, (-0.08, 1.2, 0.36)), (21, (-0.08, 1.2, 0.35)),
                   (29, (-0.2, 0.95, 0.18)), (36, HR)],
        "hand_l": [(0, HL), (3, (0.235, 1.14, 0.215)), (9, (0.1, 1.3, 0.3)), (15, (0.1, 1.28, 0.3)), (21, (0.1, 1.28, 0.29)),
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
        "hand_r": [(0, HR), (3, (-0.45, 1.42, -0.02)), (10, (-0.49, 1.38, 0.05)), (16, (-0.5, 1.5, -0.08)), (20, (-0.48, 1.3, 0.12)),
                   (24, (-0.38, 1.0, 0.3)), (29, (-0.3, 0.75, 0.42)), (30, (-0.3, 0.75, 0.42)), (37, (-0.22, 0.9, 0.2)), (44, HR)],
        "hand_l": [(0, HL), (3, (0.45, 1.42, -0.02)), (10, (0.5, 1.5, -0.06)), (16, (0.49, 1.36, 0.075)), (20, (0.48, 1.3, 0.12)),
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

## ---------------------------------------------------------------- the second set (2026-10-05, after the owner approved the
## first ten: "looks good but you can always perfect them"; authored the same way, key poses typed here, nothing read)
FACING.update({
    "fist_fwd": ((0.0, 0.05, 1.0), (0.0, -1.0, 0.05)),         # a punch out, the knuckles leading, the palm down
    "fist_guard": ((0.25, 0.92, 0.3), (1.0, -0.1, -0.2)),      # a fist up in guard, the knuckles up, the palm in
    "palm_down": ((0.05, -0.05, 1.0), (0.0, -1.0, -0.05)),     # the fingers forward, the palm down
    "knife": ((0.0, 0.05, 1.0), (1.0, 0.0, 0.0)),              # the fingers forward, the palm in (a knife hand, two fingers)
    "sweep_out": ((-0.9, 0.1, 0.42), (0.4, 0.0, 0.92)),        # the arc's end out to the side, the palm forward
    "sweep_in": ((0.75, 0.15, 0.65), (0.65, 0.0, -0.75)),      # the arc's start across the body, the palm back
    "whip_back": ((-0.1, -0.8, -0.6), (0.0, 0.6, -0.8)),       # the whip drawn down behind the hip, the palm back
    "whip_up": ((0.0, 0.85, 0.5), (0.0, 0.5, -0.85)),          # the whip over the shoulder, the palm up and back
    "whip_go": ((0.0, -0.25, 1.0), (0.0, -1.0, -0.25)),        # the lash out and down, the palm down
    "float": ((0.1, 0.25, 0.96), (0.0, -0.96, 0.25)),          # the soft hand of the water stance, the palm down and forward
    "hold": ((0.15, 0.5, 0.85), (1.0, 0.0, -0.18)),            # a rock held between the palms, the palm in
    "arms_out": ((-1.0, 0.0, 0.1), (0.0, -1.0, 0.0)),          # an arm out wide, the palm down
    "palm_up_wide": ((-0.5, 0.0, 0.86), (0.0, 1.0, 0.0)),      # the hand out to the side and forward, the palm up
    "press_down": ((0.4, 0.0, 0.92), (0.0, -1.0, 0.0)),        # pressed down in front, the palm down
    "claw": ((0.05, 0.6, 0.8), (0.2, -0.8, 0.55)),             # the stance's forward hand, the fingers up and out, the palm forward-down
})

## A stance's own stand under the loop (the feet and the hands where the stance keeps them): every stance channel keys its own.
SET2 = {
    # ---------------------------------------------------------------- the stances (idle loops while casting as an element)
    # earth: Hung Gar's low wide horse: the feet well apart and turned out, the knees pushed out, the root low; the left forearm
    # forward in guard, the right fist chambered at the ribs; slow breathing, the weight sunk and rocking a little side to side
    "stance_earth": {
        "length": 84, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.115, 0.0)), (21, (0.012, -0.122, 0.0)), (42, (0.0, -0.112, 0.0)), (63, (-0.012, -0.122, 0.0)),
                 (84, (0.0, -0.115, 0.0))],
        "hips": [(0, 5), (42, 6), (84, 5)],
        "chest": [(0, 1), (21, 2.5), (42, 0), (63, 2.5), (84, 1)],
        "roll": [(0, 0), (21, 1.2), (42, 0), (63, -1.2), (84, 0)],
        "yaw": [(0, -8), (84, -8)],
        "twist": [(0, -6), (42, -4), (84, -6)],
        "head": [(0, 2), (42, 0), (84, 2)],
        "clav_r": [(0, (0, 4)), (42, (2, 3)), (84, (0, 4))],
        "clav_l": [(0, (2, 2)), (42, (3, 1)), (84, (2, 2))],
        "hand_r": [(0, (-0.19, 0.98, 0.04)), (42, (-0.19, 0.975, 0.05)), (84, (-0.19, 0.98, 0.04))],
        "hand_l": [(0, (0.08, 1.12, 0.33)), (21, (0.075, 1.11, 0.335)), (42, (0.08, 1.1, 0.33)), (63, (0.085, 1.11, 0.325)),
                   (84, (0.08, 1.12, 0.33))],
        "face_r": [(0, "chamber"), (84, "chamber")],
        "face_l": [(0, "claw"), (84, "claw")],
        "pole_r": [(0, (-0.6, -0.4, -1.0)), (84, (-0.6, -0.4, -1.0))],
        "pole_l": [(0, (0.8, -0.8, 0.0)), (84, (0.8, -0.8, 0.0))],
        "grip_r": [(0, 1.0), (84, 1.0)],
        "grip_l": [(0, 0.2), (42, 0.3), (84, 0.2)],
        "foot_r": [(0, (-0.25, 0.077, -0.03)), (84, (-0.25, 0.077, -0.03))],
        "foot_l": [(0, (0.25, 0.077, 0.03)), (84, (0.25, 0.077, 0.03))],
        "fyaw_r": [(0, 24), (84, 24)], "fyaw_l": [(0, 18), (84, 18)],
        "knee_r": [(0, (-0.5, 0.0, 1.0)), (84, (-0.5, 0.0, 1.0))], "knee_l": [(0, (0.5, 0.0, 1.0)), (84, (0.5, 0.0, 1.0))],
    },
    # fire: Northern Shaolin's ready: side-on, the left foot ahead, up on the balls of the feet, the fists up in guard; a quick
    # bounce on the toes (two a loop) and the lead fist working
    "stance_fire": {
        "length": 40, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.05, 0.01)), (10, (0.0, -0.068, 0.012)), (20, (0.0, -0.05, 0.01)), (30, (0.0, -0.068, 0.012)),
                 (40, (0.0, -0.05, 0.01))],
        "yaw": [(0, -22), (20, -20), (40, -22)],
        "twist": [(0, -6), (20, -8), (40, -6)],
        "hips": [(0, 4), (10, 6), (20, 4), (30, 6), (40, 4)],
        "chest": [(0, 5), (10, 6.5), (20, 5), (30, 6.5), (40, 5)],
        "head": [(0, 3), (40, 3)],
        "clav_r": [(0, (6, -2)), (40, (6, -2))], "clav_l": [(0, (8, -2)), (40, (8, -2))],
        "hand_l": [(0, (0.06, 1.3, 0.32)), (10, (0.05, 1.28, 0.33)), (20, (0.06, 1.31, 0.31)), (30, (0.05, 1.28, 0.33)),
                   (40, (0.06, 1.3, 0.32))],
        "hand_r": [(0, (-0.13, 1.18, 0.16)), (10, (-0.13, 1.17, 0.165)), (20, (-0.13, 1.18, 0.16)), (30, (-0.13, 1.17, 0.165)),
                   (40, (-0.13, 1.18, 0.16))],
        "face_r": [(0, "fist_guard"), (40, "fist_guard")], "face_l": [(0, "fist_guard"), (40, "fist_guard")],
        "pole_r": [(0, (-0.5, -1.0, -0.2)), (40, (-0.5, -1.0, -0.2))], "pole_l": [(0, (0.4, -1.0, -0.2)), (40, (0.4, -1.0, -0.2))],
        "grip_r": [(0, 1.0), (40, 1.0)], "grip_l": [(0, 1.0), (40, 1.0)],
        "foot_l": [(0, (0.13, 0.077, 0.17)), (40, (0.13, 0.077, 0.17))],
        "foot_r": [(0, (-0.15, 0.077, -0.15)), (40, (-0.15, 0.077, -0.15))],
        "fyaw_l": [(0, -4), (40, -4)], "fyaw_r": [(0, 34), (40, 34)],
        "heel_l": [(0, 10), (10, 14), (20, 10), (30, 14), (40, 10)],
        "heel_r": [(0, 20), (10, 24), (20, 20), (30, 24), (40, 20)],
        "knee_l": [(0, (0.15, 0.0, 1.0)), (40, (0.15, 0.0, 1.0))], "knee_r": [(0, (-0.5, 0.0, 1.0)), (40, (-0.5, 0.0, 1.0))],
    },
    # water: tai chi: a short bow stance, the weight flowing forward onto the front leg as the soft hands push out and down,
    # back onto the rear leg as they draw in and rise; the turn following the weight; slow
    "stance_water": {
        "length": 108, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.075, -0.02)), (27, (0.008, -0.088, 0.01)), (54, (0.0, -0.08, 0.035)), (81, (-0.008, -0.088, 0.005)),
                 (108, (0.0, -0.075, -0.02))],
        "yaw": [(0, -10), (54, -4), (108, -10)],
        "twist": [(0, -6), (27, -2), (54, 2), (81, -2), (108, -6)],
        "hips": [(0, 1), (54, 4), (108, 1)],
        "chest": [(0, -1), (54, 3), (108, -1)],
        "side": [(0, 0), (27, 1.5), (54, 0), (81, -1.5), (108, 0)],
        "head": [(0, 1), (54, 0), (108, 1)],
        "clav_r": [(0, (0, 0)), (54, (6, 2)), (108, (0, 0))], "clav_l": [(0, (0, 0)), (54, (6, 2)), (108, (0, 0))],
        "hand_r": [(0, (-0.2, 1.14, 0.15)), (27, (-0.21, 1.08, 0.26)), (54, (-0.19, 1.0, 0.36)), (81, (-0.2, 1.04, 0.24)),
                   (108, (-0.2, 1.14, 0.15))],
        "hand_l": [(0, (0.18, 1.18, 0.2)), (27, (0.19, 1.12, 0.31)), (54, (0.17, 1.05, 0.41)), (81, (0.18, 1.09, 0.29)),
                   (108, (0.18, 1.18, 0.2))],
        "face_r": [(0, "float"), (108, "float")], "face_l": [(0, "float"), (108, "float")],
        "pole_r": [(0, (-0.8, -0.7, -0.3)), (108, (-0.8, -0.7, -0.3))], "pole_l": [(0, (0.8, -0.7, -0.3)), (108, (0.8, -0.7, -0.3))],
        "grip_r": [(0, -0.05), (54, 0.1), (108, -0.05)], "grip_l": [(0, -0.05), (54, 0.1), (108, -0.05)],
        "foot_l": [(0, (0.14, 0.077, 0.15)), (108, (0.14, 0.077, 0.15))],
        "foot_r": [(0, (-0.15, 0.077, -0.12)), (108, (-0.15, 0.077, -0.12))],
        "fyaw_l": [(0, 4), (108, 4)], "fyaw_r": [(0, 30), (108, 30)],
        "knee_l": [(0, (0.25, 0.0, 1.0)), (108, (0.25, 0.0, 1.0))], "knee_r": [(0, (-0.45, 0.0, 1.0)), (108, (-0.45, 0.0, 1.0))],
    },
    # air: Baguazhang's circle walker standing: light on the feet, the heels just up, the body turning a little one way and the
    # other about the waist, the lead palm out at the shoulder's height facing in, the rear palm by the elbow; the palms
    # trading their height as it turns
    "stance_air": {
        "length": 96, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.045, 0.0)), (24, (0.015, -0.05, 0.005)), (48, (0.0, -0.04, 0.0)), (72, (-0.015, -0.05, -0.005)),
                 (96, (0.0, -0.045, 0.0))],
        "yaw": [(0, 0), (24, 10), (48, 0), (72, -10), (96, 0)],
        "twist": [(0, 0), (24, 8), (48, 0), (72, -8), (96, 0)],
        "hips": [(0, 2), (96, 2)],
        "chest": [(0, 1), (48, 2), (96, 1)],
        "side": [(0, 0), (24, -2), (48, 0), (72, 2), (96, 0)],
        "head": [(0, 0), (96, 0)],
        "look": [(0, 0), (24, 6), (48, 0), (72, -6), (96, 0)],
        "clav_r": [(0, (2, 0)), (96, (2, 0))], "clav_l": [(0, (2, 0)), (96, (2, 0))],
        "hand_l": [(0, (0.2, 1.28, 0.34)), (24, (0.24, 1.3, 0.3)), (48, (0.2, 1.24, 0.34)), (72, (0.12, 1.18, 0.32)),
                   (96, (0.2, 1.28, 0.34))],
        "hand_r": [(0, (-0.1, 1.08, 0.24)), (24, (-0.06, 1.12, 0.26)), (48, (-0.12, 1.16, 0.3)), (72, (-0.22, 1.24, 0.32)),
                   (96, (-0.1, 1.08, 0.24))],
        "face_r": [(0, "push"), (96, "push")], "face_l": [(0, "push"), (96, "push")],
        "pole_r": [(0, (-0.7, -0.8, 0.0)), (96, (-0.7, -0.8, 0.0))], "pole_l": [(0, (0.7, -0.8, 0.0)), (96, (0.7, -0.8, 0.0))],
        "grip_r": [(0, -0.3), (96, -0.3)], "grip_l": [(0, -0.3), (96, -0.3)],
        "foot_l": [(0, (0.12, 0.077, 0.08)), (96, (0.12, 0.077, 0.08))],
        "foot_r": [(0, (-0.14, 0.077, -0.06)), (96, (-0.14, 0.077, -0.06))],
        "fyaw_l": [(0, 2), (24, 6), (48, 2), (72, -2), (96, 2)], "fyaw_r": [(0, 14), (24, 10), (48, 14), (72, 18), (96, 14)],
        "heel_l": [(0, 6), (24, 4), (48, 6), (72, 9), (96, 6)], "heel_r": [(0, 8), (24, 11), (48, 8), (72, 5), (96, 8)],
    },
    # ---------------------------------------------------------------- earth
    # the boulder (the owner, 2026-10-05: "I expect the ball to have a left kick to stomp and then push"): the weight onto the
    # right leg, the left foot kicks up under the rock (it comes up out of the ground), the palms rising with it; the left knee
    # high, then the foot stamped down out ahead in a wide stance (the rock planted before him) with the palms pressed down;
    # the palms drawn back to the ribs (held); the two-hand push from the chest, the back leg straightening.  strike_s: the push
    "earth_boulder": {
        "length": 50, "meta": {"hold_s": 19 / FPS, "strike_s": 23 / FPS, "back_s": 33 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (-0.06, -0.04, -0.01)), (9, (-0.075, -0.02, -0.02)), (12, (-0.07, -0.03, -0.02)),
                 (15, (0.0, -0.16, 0.06)), (17, (0.0, -0.18, 0.05)), (19, (0.0, -0.17, 0.0)), (23, (0.0, -0.14, 0.15)),
                 (26, (0.0, -0.15, 0.17)), (33, (0.0, -0.14, 0.15)), (42, (0.0, -0.05, 0.03)), (50, (0, -0.015, 0))],
        "yaw": [(0, 0), (9, 4), (15, -6), (19, -8), (23, 6), (33, 4), (50, 0)],
        "twist": [(0, 0), (9, 4), (15, -4), (19, -6), (23, 4), (33, 3), (50, 0)],
        "roll": [(0, 0), (4, 3), (9, 5), (12, 4), (15, 0), (50, 0)],
        "hips": [(0, 0), (9, -4), (12, -2), (15, 6), (19, -3), (23, 7), (26, 9), (33, 7), (50, 0)],
        "chest": [(0, 0), (9, -6), (12, -3), (15, 8), (19, -5), (23, 9), (26, 12), (33, 8), (50, 0)],
        "side": [(0, 0), (9, -4), (12, -3), (15, 0), (50, 0)],
        "head": [(0, 0), (9, 8), (12, 6), (15, 4), (19, -2), (23, -2), (50, 0)],
        "clav_r": [(0, (0, 0)), (9, (4, -6)), (15, (4, 6)), (19, (-8, 4)), (23, (14, -2)), (26, (16, -2)), (33, (13, -2)),
                   (50, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (4, -6)), (15, (4, 6)), (19, (-8, 4)), (23, (14, -2)), (26, (16, -2)), (33, (13, -2)),
                   (50, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.2, 0.9, 0.18)), (9, (-0.17, 1.08, 0.3)), (12, (-0.15, 1.24, 0.28)), (15, (-0.22, 0.95, 0.32)),
                   (17, (-0.22, 0.92, 0.3)), (19, (-0.18, 1.02, -0.04)), (21, (-0.15, 1.1, 0.32)), (23, (-0.13, 1.13, 0.68)),
                   (26, (-0.13, 1.13, 0.69)), (33, (-0.13, 1.12, 0.65)), (41, (-0.2, 0.95, 0.25)), (50, HR)],
        "hand_l": [(0, HL), (5, (0.2, 0.9, 0.18)), (9, (0.17, 1.08, 0.3)), (12, (0.15, 1.24, 0.28)), (15, (0.22, 0.95, 0.32)),
                   (17, (0.22, 0.92, 0.3)), (19, (0.18, 1.02, -0.04)), (21, (0.15, 1.1, 0.32)), (23, (0.13, 1.14, 0.655)),
                   (26, (0.13, 1.13, 0.665)), (33, (0.13, 1.12, 0.635)), (41, (0.2, 0.95, 0.25)), (50, HL)],
        "face_r": [(0, "stand"), (6, "chamber"), (12, "chamber"), (15, "press_down"), (17, "press_down"), (19, "chamber"),
                   (22, "push"), (36, "push"), (50, "stand")],
        "face_l": [(0, "stand"), (6, "chamber"), (12, "chamber"), (15, "press_down"), (17, "press_down"), (19, "chamber"),
                   (22, "push"), (36, "push"), (50, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (9, (-0.8, -0.6, -0.4)), (15, (-1.0, 0.2, -0.3)), (19, (-0.3, -0.4, -1.0)),
                   (23, (-0.8, -0.6, -0.1)), (50, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (9, (0.8, -0.6, -0.4)), (15, (1.0, 0.2, -0.3)), (19, (0.3, -0.4, -1.0)),
                   (23, (0.8, -0.6, -0.1)), (50, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, -0.2), (14, -0.2), (16, -0.45), (19, 0.15), (22, -0.45), (38, -0.45), (50, 0.4)],
        "grip_l": [(0, 0.4), (6, -0.2), (14, -0.2), (16, -0.45), (19, 0.15), (22, -0.45), (38, -0.45), (50, 0.4)],
        # the left foot: the kick up under the rock (the toes up), the knee high, the stamp out ahead; back in at the end
        "foot_l": [(0, FL), (4, (0.14, 0.12, 0.03)), (7, (0.15, 0.24, 0.32)), (9, (0.15, 0.4, 0.5)), (12, (0.17, 0.46, 0.2)),
                   (15, (0.22, 0.077, 0.3)), (36, (0.22, 0.077, 0.3)), (40, (0.18, 0.15, 0.15)), (44, FL), (50, FL)],
        "heel_l": [(0, 0), (3, 14), (7, -18), (9, -26), (12, -6), (14, -2), (15, 0), (36, 0), (39, 10), (43, 0), (50, 0)],
        "fyaw_l": [(0, 7), (9, 0), (15, 10), (36, 10), (44, 7)],
        "knee_l": [(0, "auto"), (4, (0.15, 0.3, 1.0)), (40, (0.3, 0.1, 1.0)), (44, "auto")],
        "foot_r": [(0, FR), (15, (-0.16, 0.077, -0.06)), (36, (-0.16, 0.077, -0.06)), (44, FR)],
        "fyaw_r": [(0, 7), (9, 12), (15, 24), (23, 34), (36, 34), (44, 7)],
        "heel_r": [(0, 0), (50, 0)],
        "knee_r": [(0, "auto"), (4, (-0.3, 0.0, 1.0)), (15, (-0.45, 0.0, 1.0)), (40, (-0.45, 0.0, 1.0)), (44, "auto")],
    },
    # the stomp-rise (a wall or a column raised): the right knee up, the palms low and turned up; the foot stamped down out wide
    # and the body sunk (held); then the palms driven up to the chest's height as the legs rise, the wall coming up with them
    "earth_raise": {
        "length": 40, "meta": {"hold_s": 10 / FPS, "strike_s": 14 / FPS, "back_s": 25 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (0.06, -0.03, -0.01)), (8, (-0.06, -0.15, 0.0)), (10, (-0.065, -0.17, 0.0)),
                 (14, (-0.06, -0.08, 0.02)), (17, (-0.06, -0.075, 0.02)), (25, (-0.06, -0.085, 0.015)), (33, (-0.01, -0.03, 0.0)),
                 (40, (0, -0.015, 0))],
        "roll": [(0, 0), (5, -4), (8, 1), (10, 0), (40, 0)],
        "hips": [(0, 0), (5, -2), (8, 8), (10, 9), (14, 0), (17, -2), (25, -1), (40, 0)],
        "chest": [(0, 0), (5, -4), (8, 10), (10, 12), (14, -4), (17, -7), (25, -5), (40, 0)],
        "head": [(0, 0), (5, 6), (10, 8), (14, -4), (17, -8), (25, -5), (40, 0)],
        "clav_r": [(0, (0, 0)), (10, (4, 6)), (14, (6, -12)), (17, (6, -14)), (25, (5, -10)), (40, (0, 0))],
        "clav_l": [(0, (0, 0)), (10, (4, 6)), (14, (6, -12)), (17, (6, -14)), (25, (5, -10)), (40, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.17, 0.92, 0.18)), (8, (-0.24, 0.78, 0.3)), (10, (-0.24, 0.76, 0.31)), (12, (-0.22, 1.0, 0.36)),
                   (14, (-0.2, 1.3, 0.38)), (17, (-0.2, 1.36, 0.36)), (25, (-0.2, 1.33, 0.34)), (32, (-0.2, 1.05, 0.22)), (40, HR)],
        "hand_l": [(0, HL), (5, (0.17, 0.92, 0.18)), (8, (0.22, 0.8, 0.31)), (10, (0.22, 0.78, 0.32)), (12, (0.2, 1.02, 0.37)),
                   (14, (0.18, 1.31, 0.39)), (17, (0.18, 1.37, 0.37)), (25, (0.18, 1.34, 0.35)), (32, (0.2, 1.05, 0.22)), (40, HL)],
        "face_r": [(0, "stand"), (5, "chamber"), (13, "chamber"), (16, "push"), (28, "push"), (40, "stand")],
        "face_l": [(0, "stand"), (5, "chamber"), (13, "chamber"), (16, "push"), (28, "push"), (40, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (8, (-1.0, -0.3, -0.3)), (14, (-1.0, -0.6, 0.0)), (40, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (8, (1.0, -0.3, -0.3)), (14, (1.0, -0.6, 0.0)), (40, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.1), (13, -0.1), (15, -0.5), (30, -0.5), (40, 0.4)],
        "grip_l": [(0, 0.4), (5, -0.1), (13, -0.1), (15, -0.5), (30, -0.5), (40, 0.4)],
        "foot_r": [(0, FR), (3, (-0.14, 0.14, 0.03)), (5, (-0.17, 0.32, 0.13)), (6, (-0.19, 0.3, 0.12)), (8, (-0.28, 0.077, 0.03)),
                   (30, (-0.28, 0.077, 0.03)), (34, (-0.2, 0.14, -0.01)), (37, FR), (40, FR)],
        "heel_r": [(0, 0), (3, 14), (5, -6), (7, -2), (8, 0), (30, 0), (33, 10), (36, 0), (40, 0)],
        "fyaw_r": [(0, 7), (5, 2), (8, 22), (30, 22), (37, 7)],
        "knee_r": [(0, "auto"), (3, (-0.2, 0.0, 1.0)), (34, (-0.3, 0.0, 1.0)), (37, "auto")],
        "foot_l": [(0, FL), (40, FL)],
        "fyaw_l": [(0, 7), (8, 20), (30, 20), (38, 7)],
        "knee_l": [(0, "auto"), (8, (0.45, 0.0, 1.0)), (30, (0.45, 0.0, 1.0)), (38, "auto")],
    },
    # the side burrow-step (Earth Skate's slide and burrow): the body dropped low and leaned to the right, the right foot
    # stepped out wide, the right palm down by the ground and the left guarding the face; the dive along it.  The feet stay
    # planted (the game carries the body: a ground-surfer's glide)
    "earth_burrow": {
        "length": 34, "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 20 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (-0.06, -0.15, 0.0)), (6, (-0.09, -0.24, 0.0)), (9, (-0.12, -0.28, 0.03)),
                 (14, (-0.12, -0.27, 0.03)), (20, (-0.1, -0.24, 0.02)), (28, (-0.02, -0.06, 0.0)), (34, (0, -0.015, 0))],
        "roll": [(0, 0), (6, -8), (9, -12), (20, -10), (34, 0)],
        "hips": [(0, 0), (6, 18), (9, 24), (20, 20), (34, 0)],
        "chest": [(0, 0), (6, 10), (9, 14), (20, 12), (34, 0)],
        "side": [(0, 0), (6, -6), (9, -10), (20, -8), (34, 0)],
        "yaw": [(0, 0), (6, -10), (20, -10), (34, 0)],
        "head": [(0, 0), (6, -12), (9, -16), (20, -14), (34, 0)],
        "clav_r": [(0, (0, 0)), (9, (8, 12)), (20, (8, 10)), (34, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (4, -4)), (34, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.29, 0.71, 0.17)), (6, (-0.31, 0.62, 0.24)), (9, (-0.315, 0.565, 0.305)),
                   (20, (-0.3, 0.615, 0.28)), (28, (-0.225, 0.77, 0.13)), (34, HR)],
        "hand_l": [(0, HL), (4, (0.12, 1.0, 0.25)), (6, (0.05, 1.05, 0.33)), (9, (0.02, 1.0, 0.36)), (20, (0.03, 1.0, 0.35)),
                   (28, (0.15, 0.9, 0.15)), (34, HL)],
        "face_r": [(0, "stand"), (5, "press_down"), (24, "press_down"), (34, "stand")],
        "face_l": [(0, "stand"), (5, "guard"), (24, "guard"), (34, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-1.0, 0.3, -0.2)), (24, (-1.0, 0.3, -0.2)), (34, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, -1.0, 0.0)), (24, (0.6, -1.0, 0.0)), (34, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.4), (24, -0.4), (34, 0.4)],
        "grip_l": [(0, 0.4), (5, 0.6), (24, 0.6), (34, 0.4)],
        "foot_r": [(0, FR), (2, (-0.16, 0.13, 0.0)), (5, (-0.34, 0.077, 0.02)), (24, (-0.34, 0.077, 0.02)), (28, (-0.22, 0.13, 0.0)),
                   (31, FR), (34, FR)],
        "heel_r": [(0, 0), (2, 12), (4, -4), (5, 0), (24, 0), (27, 10), (30, 0)],
        "fyaw_r": [(0, 7), (5, 35), (24, 35), (31, 7)],
        "knee_r": [(0, "auto"), (4, (-0.6, 0.0, 1.0)), (26, (-0.6, 0.0, 1.0)), (31, "auto")],
        "foot_l": [(0, FL), (34, FL)],
        "heel_l": [(0, 0), (6, 0), (9, 14), (20, 12), (28, 0)],
        "fyaw_l": [(0, 7), (9, 12), (28, 7)],
        "knee_l": [(0, "auto"), (6, (0.2, 0.0, 1.0)), (26, (0.2, 0.0, 1.0)), (31, "auto")],
    },
    # the catch (Catch: catch, Earth Shove: pull): the hands thrown up and wide before the face, the fingers spread, the weight
    # back to meet it (held); the rock taken: the hands clap round it, the right on top and the left under, and draw it in
    # before the chest, the body giving with it, held there.  Round 2's polish (the owner: every guard a pose that reads at a
    # glance; its moments kept): the hold wider and higher, and the rock held as a rock between the palms (it read as two fists
    # in a guard)
    "earth_catch": {
        "length": 38, "meta": {"hold_s": 7 / FPS, "strike_s": 10 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.08, 0.01)), (7, (0.0, -0.09, 0.02)), (10, (0.0, -0.14, -0.05)),
                 (13, (0.0, -0.165, -0.08)), (26, (0.0, -0.155, -0.075)), (33, (0.0, -0.045, -0.01)), (38, (0, -0.015, 0))],
        "hips": [(0, 0), (7, 4), (10, -2), (13, -4), (26, -3), (38, 0)],
        "chest": [(0, 0), (7, 4), (10, -4), (13, -9), (26, -7), (38, 0)],
        "head": [(0, 0), (7, -6), (10, 1), (13, 4), (26, 3), (38, 0)],
        "clav_r": [(0, (0, 0)), (7, (10, -16)), (10, (8, -6)), (13, (4, -2)), (26, (4, -2)), (38, (0, 0))],
        "clav_l": [(0, (0, 0)), (7, (10, -16)), (10, (8, -6)), (13, (4, -2)), (26, (4, -2)), (38, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.27, 1.26, 0.3)), (7, (-0.33, 1.46, 0.4)), (10, (-0.1, 1.32, 0.35)), (13, (-0.08, 1.28, 0.27)),
                   (26, (-0.08, 1.275, 0.27)), (32, (-0.2, 0.98, 0.18)), (38, HR)],
        "hand_l": [(0, HL), (4, (0.27, 1.26, 0.3)), (7, (0.33, 1.46, 0.4)), (10, (0.08, 1.04, 0.38)), (13, (0.07, 1.0, 0.32)),
                   (26, (0.07, 0.995, 0.315)), (32, (0.2, 0.96, 0.18)), (38, HL)],
        "face_r": [(0, "stand"), (4, "push"), (8, "push"), (10, "palm_down"), (28, "palm_down"), (38, "stand")],
        "face_l": [(0, "stand"), (4, "push"), (8, "push"), (10, "chamber"), (28, "chamber"), (38, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (7, (-1.0, -0.5, 0.0)), (10, (-1.0, 0.1, -0.2)), (26, (-1.0, 0.1, -0.2)),
                   (38, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (7, (1.0, -0.5, 0.0)), (10, (1.0, -0.6, -0.3)), (26, (1.0, -0.6, -0.3)),
                   (38, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.6), (8, -0.6), (10, 0.05), (28, 0.05), (38, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.6), (8, -0.6), (10, 0.05), (28, 0.05), (38, 0.4)],
        "foot_r": [(0, FR), (3, (-0.15, 0.13, -0.04)), (5, (-0.18, 0.077, -0.14)), (30, (-0.18, 0.077, -0.14)),
                   (33, (-0.16, 0.13, -0.08)), (36, FR), (38, FR)],
        "heel_r": [(0, 0), (3, 12), (5, 0), (30, 0), (32, 10), (35, 0)],
        "fyaw_r": [(0, 7), (5, 24), (30, 24), (36, 7)],
        "knee_r": [(0, "auto"), (3, (-0.3, 0.0, 1.0)), (34, (-0.3, 0.0, 1.0)), (36, "auto")],
        "foot_l": [(0, FL), (38, FL)],
        "fyaw_l": [(0, 7), (10, 12), (30, 12), (36, 7)],
    },
    # the shove (Earth Shove: push): a heavy single palm: the left foot steps out, the right palm drawn back to the ribs with the
    # body coiled to the right (held); the hips turn through and the palm is driven out from the shoulder into a deep bow
    # stance, the left fist pulled back to the hip.  strike_s: the palm out
    "earth_shove": {
        "length": 34, "mirror": True,
        "meta": {"hold_s": 7 / FPS, "strike_s": 11 / FPS, "back_s": 22 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.06, -0.03)), (7, (0.0, -0.07, -0.03)), (11, (0.0, -0.15, 0.15)),
                 (14, (0.0, -0.16, 0.17)), (22, (0.0, -0.15, 0.15)), (29, (0.0, -0.05, 0.04)), (34, (0, -0.015, 0))],
        "yaw": [(0, 0), (7, -16), (11, 14), (14, 18), (22, 15), (34, 0)],
        "twist": [(0, 0), (7, -12), (11, 10), (14, 14), (22, 11), (34, 0)],
        "hips": [(0, 0), (7, -2), (11, 8), (14, 10), (22, 8), (34, 0)],
        "chest": [(0, 0), (7, -4), (11, 9), (14, 12), (22, 9), (34, 0)],
        "head": [(0, 0), (7, -2), (11, -4), (34, 0)],
        "clav_r": [(0, (0, 0)), (7, (-10, 4)), (11, (16, -2)), (14, (18, -2)), (22, (14, -2)), (34, (0, 0))],
        "clav_l": [(0, (0, 0)), (7, (8, -2)), (11, (-6, 2)), (22, (-4, 2)), (34, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.2, 0.98, 0.04)), (7, (-0.2, 1.06, -0.06)), (9, (-0.13, 1.13, 0.3)), (11, (-0.02, 1.15, 0.71)),
                   (14, (-0.015, 1.145, 0.71)), (22, (-0.025, 1.13, 0.67)), (29, (-0.18, 0.95, 0.2)), (34, HR)],
        "hand_l": [(0, HL), (4, (0.18, 1.1, 0.25)), (7, (0.12, 1.2, 0.36)), (10, (0.2, 1.02, 0.1)), (14, (0.2, 0.98, -0.02)),
                   (22, (0.2, 0.98, -0.01)), (34, HL)],
        "face_r": [(0, "stand"), (4, "chamber"), (8, "chamber"), (11, "push"), (24, "push"), (34, "stand")],
        "face_l": [(0, "stand"), (4, "point"), (8, "point"), (11, "chamber"), (24, "chamber"), (34, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (7, (-0.3, -0.5, -1.0)), (11, (-0.8, -0.6, -0.1)), (34, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (7, (0.6, -0.8, 0.0)), (11, (0.4, -0.3, -1.0)), (34, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.2), (9, -0.45), (26, -0.45), (34, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.2), (9, 0.9), (26, 0.9), (34, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.13, 0.04)), (6, (0.17, 0.077, 0.285)), (25, (0.17, 0.077, 0.29)), (28, (0.15, 0.13, 0.12)),
                   (31, FL), (34, FL)],
        "heel_l": [(0, 0), (3, 10), (5, -6), (6, 0), (25, 0), (27, 10), (30, 0)],
        "fyaw_l": [(0, 7), (6, 4), (28, 4), (31, 7)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.2, 1.0)), (29, (0.2, 0.2, 1.0)), (32, "auto")],
        "foot_r": [(0, FR), (6, (-0.15, 0.077, -0.08)), (27, (-0.15, 0.077, -0.08)), (32, FR)],
        "fyaw_r": [(0, 7), (7, 20), (11, 36), (27, 36), (32, 7)],
        "heel_r": [(0, 0), (34, 0)],
    },
    # ---------------------------------------------------------------- fire (Northern Shaolin: long punches, kicks)
    # the straight punch (Fire Blast: punch, stream; Fire Jab: jab): a short step in, the fists up; the right fist chambered at
    # the ribs, the body coiled (held); the hips snap through and the fist drives straight out, the left pulled back to the
    # ribs.  strike_s: the fist out
    "fire_punch": {
        "length": 26, "mirror": True,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 15 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.06, 0.03)), (5, (0.0, -0.065, 0.03)), (8, (0.0, -0.09, 0.11)),
                 (10, (0.0, -0.095, 0.12)), (15, (0.0, -0.09, 0.11)), (21, (0.0, -0.04, 0.03)), (26, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -18), (8, 16), (10, 20), (15, 16), (26, 0)],
        "twist": [(0, 0), (5, -10), (8, 12), (10, 14), (15, 12), (26, 0)],
        "hips": [(0, 0), (5, 3), (8, 7), (10, 8), (15, 6), (26, 0)],
        "chest": [(0, 0), (5, 4), (8, 8), (10, 9), (15, 7), (26, 0)],
        "head": [(0, 0), (5, 2), (8, -2), (26, 0)],
        "clav_r": [(0, (0, 0)), (5, (-8, 2)), (8, (16, -4)), (10, (18, -4)), (15, (14, -3)), (26, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, -2)), (8, (-6, 2)), (15, (-4, 2)), (26, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.18, 1.02, 0.08)), (5, (-0.18, 1.04, -0.02)), (7, (-0.1, 1.28, 0.4)), (8, (-0.02, 1.34, 0.69)),
                   (10, (-0.02, 1.33, 0.68)), (15, (-0.035, 1.3, 0.63)), (21, (-0.17, 1.0, 0.2)), (26, HR)],
        "hand_l": [(0, HL), (3, (0.1, 1.24, 0.3)), (5, (0.07, 1.28, 0.36)), (8, (0.19, 1.05, 0.04)), (10, (0.19, 1.03, -0.01)),
                   (15, (0.19, 1.03, 0.0)), (21, (0.18, 0.92, 0.1)), (26, HL)],
        "face_r": [(0, "stand"), (3, "chamber"), (5, "chamber"), (8, "fist_fwd"), (17, "fist_fwd"), (26, "stand")],
        "face_l": [(0, "stand"), (3, "fist_guard"), (5, "fist_guard"), (8, "chamber"), (17, "chamber"), (26, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.3, -0.5, -1.0)), (8, (-0.6, -1.0, 0.0)), (26, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.4, -1.0, -0.2)), (8, (0.3, -0.5, -1.0)), (26, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 1.0), (22, 1.0), (26, 0.4)],
        "grip_l": [(0, 0.4), (3, 1.0), (22, 1.0), (26, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.14, 0.077, 0.2)), (18, (0.14, 0.077, 0.2)), (21, (0.13, 0.12, 0.08)),
                   (24, FL), (26, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 0), (18, 0), (20, 8), (23, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (22, (0.2, 0.2, 1.0)), (24, "auto")],
        "foot_r": [(0, FR), (4, (-0.14, 0.077, -0.06)), (20, (-0.14, 0.077, -0.06)), (24, FR)],
        "fyaw_r": [(0, 7), (5, 30), (8, 40), (18, 40), (24, 7)],
        "heel_r": [(0, 0), (5, 6), (8, 22), (15, 18), (21, 0)],
    },
    # the double jab (Fire Jab: double jab, embers): the fists up in guard (held); the left jab snaps out and back, then the
    # right cross behind it (Fire Jab's second bolt, 0.15 s after the first).  strike_s: the left jab
    "fire_double": {
        "length": 30,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 18 / FPS, "hand": "l", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.06, 0.03)), (5, (0.0, -0.065, 0.03)), (8, (0.0, -0.07, 0.08)),
                 (10, (0.0, -0.07, 0.06)), (13, (0.0, -0.09, 0.12)), (18, (0.0, -0.085, 0.11)), (25, (0.0, -0.035, 0.03)),
                 (30, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -16), (8, -24), (10, -14), (13, 16), (18, 12), (30, 0)],
        "twist": [(0, 0), (5, -8), (8, -14), (10, -6), (13, 12), (18, 9), (30, 0)],
        "hips": [(0, 0), (5, 4), (8, 5), (13, 8), (18, 6), (30, 0)],
        "chest": [(0, 0), (5, 5), (8, 6), (13, 9), (18, 7), (30, 0)],
        "head": [(0, 0), (5, 3), (13, -1), (30, 0)],
        "clav_r": [(0, (0, 0)), (5, (4, -2)), (10, (0, 0)), (13, (16, -4)), (18, (12, -3)), (30, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (6, -2)), (8, (16, -4)), (10, (6, -2)), (13, (-4, 2)), (30, (0, 0))],
        "hand_l": [(0, HL), (3, (0.08, 1.26, 0.3)), (5, (0.06, 1.3, 0.3)), (7, (0.05, 1.34, 0.52)), (8, (0.03, 1.35, 0.67)),
                   (10, (0.07, 1.28, 0.34)), (13, (0.17, 1.12, 0.12)), (18, (0.17, 1.12, 0.14)), (25, (0.17, 0.95, 0.12)), (30, HL)],
        "hand_r": [(0, HR), (3, (-0.13, 1.18, 0.16)), (5, (-0.13, 1.2, 0.16)), (8, (-0.14, 1.2, 0.14)), (10, (-0.12, 1.24, 0.25)),
                   (12, (-0.04, 1.32, 0.56)), (13, (-0.02, 1.33, 0.68)), (18, (-0.035, 1.3, 0.62)), (25, (-0.17, 1.0, 0.18)), (30, HR)],
        "face_l": [(0, "stand"), (3, "fist_guard"), (6, "fist_guard"), (8, "fist_fwd"), (9, "fist_fwd"), (11, "fist_guard"),
                   (20, "fist_guard"), (30, "stand")],
        "face_r": [(0, "stand"), (3, "fist_guard"), (10, "fist_guard"), (13, "fist_fwd"), (20, "fist_fwd"), (30, "stand")],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.4, -1.0, -0.2)), (8, (0.6, -1.0, 0.0)), (11, (0.4, -1.0, -0.2)),
                   (30, (0.35, -0.1, -1.0))],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.5, -1.0, -0.2)), (13, (-0.6, -1.0, 0.0)), (30, (-0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 1.0), (26, 1.0), (30, 0.4)],
        "grip_l": [(0, 0.4), (3, 1.0), (26, 1.0), (30, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.13, 0.077, 0.18)), (22, (0.13, 0.077, 0.18)), (25, (0.13, 0.12, 0.08)),
                   (28, FL), (30, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 6), (22, 6), (24, 8), (27, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (26, (0.2, 0.2, 1.0)), (28, "auto")],
        "foot_r": [(0, FR), (4, (-0.15, 0.077, -0.12)), (22, (-0.15, 0.077, -0.12)), (28, FR)],
        "fyaw_r": [(0, 7), (5, 32), (13, 42), (22, 40), (28, 7)],
        "heel_r": [(0, 0), (4, 16), (10, 14), (13, 26), (20, 20), (26, 0)],
    },
    # the kick (round 2: the High Kick, the crescent over walls and into jumpers; its keys as the second set had them, now with
    # its twin for the chain): the fists up, the weight onto the left leg and the right knee chambered high (held); the leg
    # snaps out, the foot driving forward at the waist's height, the toes pointed; recoiled and set down ahead in a bow stance
    # with the right fist following out; back.  strike_s: the foot out
    "fire_kick": {
        "length": 36, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 22 / FPS, "hand": "foot_r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.05, -0.03, -0.01)), (6, (0.06, -0.035, -0.02)), (9, (0.05, -0.02, -0.04)),
                 (12, (0.05, -0.04, -0.01)), (16, (0.0, -0.1, 0.12)), (22, (0.0, -0.095, 0.11)), (30, (0.0, -0.03, 0.03)),
                 (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -6), (9, -2), (16, 10), (22, 8), (36, 0)],
        "hips": [(0, 0), (6, -6), (9, -14), (12, -6), (16, 6), (22, 5), (36, 0)],
        "chest": [(0, 0), (6, 4), (9, 2), (12, 4), (16, 7), (22, 5), (36, 0)],
        "roll": [(0, 0), (6, 4), (9, 3), (14, 0), (36, 0)],
        "head": [(0, 0), (6, 2), (9, 6), (12, 2), (36, 0)],
        "clav_r": [(0, (0, 0)), (6, (4, -2)), (16, (14, -2)), (22, (10, -2)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (6, -2)), (16, (-2, 0)), (36, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.14, 1.2, 0.18)), (6, (-0.14, 1.22, 0.16)), (9, (-0.22, 1.05, -0.06)), (12, (-0.16, 1.15, 0.12)),
                   (16, (-0.06, 1.25, 0.5)), (22, (-0.06, 1.24, 0.47)), (29, (-0.18, 0.98, 0.18)), (36, HR)],
        "hand_l": [(0, HL), (4, (0.1, 1.26, 0.28)), (6, (0.08, 1.28, 0.3)), (9, (0.12, 1.3, 0.34)), (12, (0.12, 1.24, 0.28)),
                   (16, (0.19, 1.04, 0.02)), (22, (0.19, 1.04, 0.03)), (36, HL)],
        "face_r": [(0, "stand"), (4, "fist_guard"), (12, "fist_guard"), (16, "fist_fwd"), (24, "fist_fwd"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "fist_guard"), (13, "fist_guard"), (16, "chamber"), (24, "chamber"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.5, -1.0, -0.2)), (16, (-0.6, -1.0, 0.0)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.4, -1.0, -0.2)), (16, (0.3, -0.5, -1.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 1.0), (30, 1.0), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, 1.0), (30, 1.0), (36, 0.4)],
        # the right leg: chambered, snapped out, recoiled, set down ahead
        "foot_r": [(0, FR), (3, (-0.13, 0.2, 0.08)), (6, (-0.12, 0.46, 0.2)), (8, (-0.11, 0.56, 0.48)), (9, (-0.1, 0.58, 0.58)),
                   (11, (-0.11, 0.5, 0.36)), (13, (-0.12, 0.3, 0.3)), (16, (-0.13, 0.077, 0.24)), (25, (-0.13, 0.077, 0.24)),
                   (29, (-0.13, 0.13, 0.1)), (33, FR), (36, FR)],
        "heel_r": [(0, 0), (3, 20), (6, 30), (9, 52), (11, 30), (14, 4), (16, 0), (25, 0), (28, 10), (32, 0)],
        "fyaw_r": [(0, 7), (6, 2), (16, 4), (25, 4), (33, 7)],
        "knee_r": [(0, "auto"), (3, (-0.1, 0.4, 1.0)), (13, (-0.1, 0.4, 1.0)), (16, (-0.15, 0.2, 1.0)), (29, (-0.15, 0.2, 1.0)),
                   (33, "auto")],
        "foot_l": [(0, FL), (16, (0.15, 0.077, -0.1)), (25, (0.15, 0.077, -0.1)), (33, FL)],
        "fyaw_l": [(0, 7), (6, 14), (16, 32), (25, 32), (33, 7)],
        "heel_l": [(0, 0), (9, 0), (16, 14), (22, 12), (30, 0)],
        "knee_l": [(0, "auto"), (6, (0.3, 0.0, 1.0)), (28, (0.3, 0.0, 1.0)), (32, "auto")],
    },
    # the sweep (Fire Arc: sweep; Fire Wall: wall, ring): the right hand wound across to the left shoulder, the body turned to
    # the left (held); the arm sweeps round flat at the shoulder's height, a knife hand, the body unwinding to the right; on
    # out to the side.  strike_s: the hand across the front
    "fire_sweep": {
        "length": 30, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 18 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.02, -0.08, 0.0)), (9, (0.0, -0.11, 0.05)), (12, (-0.03, -0.11, 0.05)),
                 (18, (-0.03, -0.1, 0.04)), (25, (0.0, -0.04, 0.01)), (30, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, 26), (9, 0), (12, -26), (18, -22), (30, 0)],
        "twist": [(0, 0), (6, 18), (9, 0), (12, -18), (18, -14), (30, 0)],
        "hips": [(0, 0), (6, 3), (9, 6), (12, 5), (18, 4), (30, 0)],
        "chest": [(0, 0), (6, 4), (9, 7), (12, 5), (18, 4), (30, 0)],
        "side": [(0, 0), (6, 3), (9, 0), (12, -4), (30, 0)],
        "clav_r": [(0, (0, 0)), (6, (14, -6)), (9, (12, -8)), (12, (-6, -6)), (18, (-4, -4)), (30, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (-4, 2)), (12, (4, -2)), (30, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.05, 1.08, 0.22)), (6, (0.14, 1.24, 0.24)), (8, (0.02, 1.28, 0.5)), (9, (-0.15, 1.29, 0.57)),
                   (10, (-0.32, 1.27, 0.47)), (12, (-0.45, 1.23, 0.18)), (18, (-0.45, 1.2, 0.15)), (25, (-0.28, 0.95, 0.1)), (30, HR)],
        "hand_l": [(0, HL), (3, (0.2, 0.98, 0.1)), (6, (0.19, 1.02, 0.05)), (12, (0.17, 1.06, 0.18)), (18, (0.17, 1.04, 0.16)),
                   (30, HL)],
        "face_r": [(0, "stand"), (4, "sweep_in"), (7, "sweep_in"), (9, "knife"), (12, "sweep_out"), (20, "sweep_out"), (30, "stand")],
        "face_l": [(0, "stand"), (4, "chamber"), (20, "chamber"), (30, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.2, -1.0, 0.0)), (9, (-0.4, -1.0, 0.0)), (12, (-0.3, -1.0, -0.5)),
                   (30, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.3, -0.5, -1.0)), (30, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.3), (22, -0.3), (30, 0.4)],
        "grip_l": [(0, 0.4), (4, 1.0), (22, 1.0), (30, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.12, 0.04)), (5, (0.17, 0.077, 0.18)), (21, (0.17, 0.077, 0.18)), (24, (0.15, 0.12, 0.08)),
                   (27, FL), (30, FL)],
        "heel_l": [(0, 0), (3, 8), (4, -4), (5, 0), (21, 0), (23, 8), (26, 0)],
        "fyaw_l": [(0, 7), (6, 24), (9, 10), (12, -10), (21, -10), (27, 7)],
        "foot_r": [(0, FR), (5, (-0.16, 0.077, -0.08)), (21, (-0.16, 0.077, -0.08)), (27, FR)],
        "fyaw_r": [(0, 7), (6, 0), (9, 20), (12, 36), (21, 34), (27, 7)],
        "heel_r": [(0, 0), (6, 0), (9, 12), (12, 20), (18, 16), (24, 0)],
    },
    # the breath (Breath: breath, smoke, heat): the hands rise to the chest and the chest lifts back with the breath drawn in
    # (held); then the body drives forward, the palms framing the mouth and pushing out with the breath, the head forward.
    # strike_s: the breath out
    "fire_breath": {
        "length": 40,
        "meta": {"hold_s": 10 / FPS, "strike_s": 13 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (8, (0.0, -0.02, -0.04)), (10, (0.0, -0.025, -0.045)), (13, (0.0, -0.09, 0.1)),
                 (20, (0.0, -0.1, 0.12)), (26, (0.0, -0.09, 0.1)), (34, (0.0, -0.035, 0.02)), (40, (0, -0.015, 0))],
        "hips": [(0, 0), (8, -4), (10, -5), (13, 8), (20, 10), (26, 8), (40, 0)],
        "chest": [(0, 0), (8, -9), (10, -10), (13, 10), (20, 13), (26, 10), (40, 0)],
        "head": [(0, 0), (8, -10), (10, -12), (13, -6), (20, -4), (26, -4), (40, 0)],
        "clav_r": [(0, (0, 0)), (8, (-4, -6)), (13, (10, -6)), (26, (8, -5)), (40, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (-4, -6)), (13, (10, -6)), (26, (8, -5)), (40, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.16, 1.05, 0.15)), (8, (-0.13, 1.25, 0.12)), (10, (-0.12, 1.3, 0.1)), (13, (-0.13, 1.45, 0.42)),
                   (20, (-0.14, 1.43, 0.45)), (26, (-0.14, 1.4, 0.42)), (33, (-0.2, 1.05, 0.2)), (40, HR)],
        "hand_l": [(0, HL), (5, (0.16, 1.05, 0.15)), (8, (0.13, 1.25, 0.12)), (10, (0.12, 1.3, 0.1)), (13, (0.13, 1.45, 0.42)),
                   (20, (0.14, 1.43, 0.45)), (26, (0.14, 1.4, 0.42)), (33, (0.2, 1.05, 0.2)), (40, HL)],
        "face_r": [(0, "stand"), (5, "chamber"), (10, "chamber"), (13, "push"), (28, "push"), (40, "stand")],
        "face_l": [(0, "stand"), (5, "chamber"), (10, "chamber"), (13, "push"), (28, "push"), (40, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (8, (-0.8, -1.0, -0.4)), (13, (-1.0, -0.6, 0.0)), (40, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (8, (0.8, -1.0, -0.4)), (13, (1.0, -0.6, 0.0)), (40, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, 0.0), (11, 0.0), (13, -0.5), (28, -0.5), (40, 0.4)],
        "grip_l": [(0, 0.4), (5, 0.0), (11, 0.0), (13, -0.5), (28, -0.5), (40, 0.4)],
        "foot_l": [(0, FL), (10, FL), (11, (0.14, 0.12, 0.08)), (13, (0.15, 0.077, 0.24)), (29, (0.15, 0.077, 0.24)),
                   (32, (0.14, 0.12, 0.1)), (35, FL), (40, FL)],
        "heel_l": [(0, 0), (10, 0), (11, 10), (12, -4), (13, 0), (29, 0), (31, 10), (34, 0)],
        "foot_r": [(0, FR), (13, (-0.15, 0.077, -0.06)), (29, (-0.15, 0.077, -0.06)), (35, FR)],
        "fyaw_r": [(0, 7), (13, 30), (29, 30), (35, 7)],
        "heel_r": [(0, 0), (13, 8), (26, 6), (34, 0)],
    },
    # the lightning (Fire Arc: lightning; the longest lock): a wide low stance; both hands circle - together at the belly,
    # apart and up wide, round and down - drawing the charge; the right hand drawn back by the chest with the two fingers out,
    # the left reaching ahead (held, the charge); both hands thrust out together.  strike_s: the hands out
    "fire_lightning": {
        "length": 64,
        "meta": {"hold_s": 32 / FPS, "strike_s": 36 / FPS, "back_s": 47 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.08, 0.02)), (12, (0.0, -0.11, 0.0)), (20, (0.0, -0.08, -0.02)),
                 (28, (0.0, -0.12, 0.0)), (32, (0.0, -0.12, -0.03)), (36, (0.0, -0.13, 0.1)), (40, (0.0, -0.135, 0.12)),
                 (47, (0.0, -0.13, 0.1)), (56, (0.0, -0.04, 0.02)), (64, (0, -0.015, 0))],
        "yaw": [(0, 0), (12, 0), (20, 0), (28, -10), (32, -16), (36, 8), (40, 10), (47, 8), (64, 0)],
        "twist": [(0, 0), (20, 0), (28, -8), (32, -12), (36, 6), (47, 5), (64, 0)],
        "hips": [(0, 0), (12, 4), (20, -2), (28, 3), (32, 0), (36, 8), (40, 9), (47, 7), (64, 0)],
        "chest": [(0, 0), (12, 6), (20, -5), (28, 3), (32, -2), (36, 9), (40, 10), (47, 8), (64, 0)],
        "head": [(0, 0), (12, 6), (20, -6), (28, 0), (32, -2), (36, -3), (64, 0)],
        "clav_r": [(0, (0, 0)), (12, (6, 4)), (20, (-4, -16)), (28, (4, 2)), (32, (-8, -2)), (36, (16, -4)), (47, (12, -3)),
                   (64, (0, 0))],
        "clav_l": [(0, (0, 0)), (12, (6, 4)), (20, (-4, -16)), (28, (4, 2)), (32, (10, -4)), (36, (14, -4)), (47, (12, -3)),
                   (64, (0, 0))],
        "hand_r": [(0, HR), (6, (-0.15, 0.95, 0.2)), (12, (-0.05, 1.02, 0.25)), (16, (-0.3, 1.25, 0.25)), (20, (-0.45, 1.42, 0.02)),
                   (24, (-0.42, 1.1, 0.05)), (28, (-0.22, 0.98, 0.2)), (32, (-0.2, 1.22, -0.03)), (34, (-0.12, 1.3, 0.3)),
                   (36, (-0.02, 1.36, 0.63)), (40, (-0.02, 1.35, 0.64)), (47, (-0.035, 1.32, 0.59)), (56, (-0.2, 0.98, 0.18)), (64, HR)],
        "hand_l": [(0, HL), (6, (0.15, 0.95, 0.2)), (12, (0.05, 1.02, 0.26)), (16, (0.3, 1.25, 0.25)), (20, (0.45, 1.42, 0.02)),
                   (24, (0.42, 1.1, 0.05)), (28, (0.22, 0.98, 0.2)), (32, (0.12, 1.25, 0.42)), (34, (0.06, 1.32, 0.52)),
                   (36, (0.03, 1.35, 0.61)), (40, (0.03, 1.34, 0.62)), (47, (0.04, 1.31, 0.57)), (56, (0.2, 0.98, 0.18)), (64, HL)],
        "face_r": [(0, "stand"), (6, "chamber"), (12, "chamber"), (16, "palm_up_wide"), (24, "palm_up_wide"), (28, "press_down"),
                   (31, "knife"), (48, "knife"), (64, "stand")],
        "face_l": [(0, "stand"), (6, "chamber"), (12, "chamber"), (16, "palm_up_wide"), (24, "palm_up_wide"), (28, "press_down"),
                   (31, "knife"), (48, "knife"), (64, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (12, (-1.0, -0.5, 0.0)), (20, (-0.6, -1.0, -0.4)), (28, (-1.0, -0.4, -0.2)),
                   (32, (-0.3, -0.5, -1.0)), (36, (-0.6, -1.0, 0.0)), (64, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (12, (1.0, -0.5, 0.0)), (20, (0.6, -1.0, -0.4)), (28, (1.0, -0.4, -0.2)),
                   (32, (0.6, -1.0, 0.0)), (64, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, -0.2), (28, -0.2), (31, 0.55), (50, 0.55), (64, 0.4)],
        "grip_l": [(0, 0.4), (6, -0.2), (28, -0.2), (31, 0.55), (50, 0.55), (64, 0.4)],
        "foot_l": [(0, FL), (3, (0.15, 0.12, 0.04)), (6, (0.2, 0.077, 0.18)), (52, (0.2, 0.077, 0.18)), (56, (0.16, 0.12, 0.08)),
                   (60, FL), (64, FL)],
        "heel_l": [(0, 0), (3, 8), (5, -4), (6, 0), (52, 0), (55, 8), (59, 0)],
        "fyaw_l": [(0, 7), (6, 10), (52, 10), (60, 7)],
        "knee_l": [(0, "auto"), (4, (0.35, 0.1, 1.0)), (54, (0.35, 0.1, 1.0)), (58, "auto")],
        "foot_r": [(0, FR), (6, (-0.2, 0.077, -0.1)), (52, (-0.2, 0.077, -0.1)), (60, FR)],
        "fyaw_r": [(0, 7), (6, 26), (32, 30), (36, 36), (52, 34), (60, 7)],
        "knee_r": [(0, "auto"), (6, (-0.45, 0.0, 1.0)), (54, (-0.45, 0.0, 1.0)), (58, "auto")],
        "heel_r": [(0, 0), (32, 0), (36, 10), (47, 8), (56, 0)],
    },
    # ---------------------------------------------------------------- water (tai chi: flowing arcs)
    # the whip (Water Whip: whip, lash; Water Jet: splash, jet): the right hand sweeps down and back past the hip drawing the
    # water, the weight back (held); it rises over the shoulder in an arc and lashes out and down, the wrist snapping, the
    # weight onto the front leg; on down across the body.  strike_s: the lash
    "water_whip": {
        "length": 32, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 10 / FPS, "back_s": 20 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.07, -0.05)), (8, (0.0, -0.06, 0.0)), (10, (0.0, -0.09, 0.1)),
                 (13, (0.0, -0.1, 0.12)), (20, (0.0, -0.09, 0.1)), (27, (0.0, -0.035, 0.02)), (32, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -24), (8, -10), (10, 10), (13, 16), (20, 12), (32, 0)],
        "twist": [(0, 0), (6, -16), (8, -6), (10, 8), (13, 12), (20, 9), (32, 0)],
        "hips": [(0, 0), (6, 4), (8, -2), (10, 6), (13, 9), (20, 7), (32, 0)],
        "chest": [(0, 0), (6, 6), (8, -5), (10, 7), (13, 11), (20, 8), (32, 0)],
        "side": [(0, 0), (6, -5), (8, 4), (10, 0), (32, 0)],
        "head": [(0, 0), (6, -2), (8, -4), (10, 0), (32, 0)],
        "clav_r": [(0, (0, 0)), (6, (-12, 6)), (8, (2, -16)), (10, (14, -4)), (13, (12, 2)), (20, (8, 2)), (32, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (6, 0)), (10, (-4, 2)), (32, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.25, 0.8, 0.12)), (6, (-0.3, 0.84, -0.2)), (7, (-0.36, 1.12, -0.16)), (8, (-0.34, 1.44, 0.04)),
                   (9, (-0.16, 1.4, 0.42)), (10, (-0.09, 1.26, 0.68)), (12, (0.0, 1.08, 0.6)), (14, (0.08, 0.98, 0.47)),
                   (20, (0.07, 0.98, 0.44)), (27, (-0.15, 0.9, 0.18)), (32, HR)],
        "hand_l": [(0, HL), (3, (0.2, 1.0, 0.2)), (6, (0.14, 1.15, 0.34)), (10, (0.2, 1.05, 0.15)), (14, (0.21, 1.0, 0.06)),
                   (20, (0.21, 1.0, 0.07)), (32, HL)],
        "face_r": [(0, "stand"), (4, "whip_back"), (6, "whip_back"), (8, "whip_up"), (10, "whip_go"), (13, "palm_down"),
                   (22, "palm_down"), (32, "stand")],
        "face_l": [(0, "stand"), (4, "float"), (8, "float"), (12, "chamber"), (22, "chamber"), (32, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.6, 0.3, -0.8)), (8, (-1.0, 0.3, 0.0)), (10, (-0.8, -0.4, 0.2)),
                   (14, (-0.6, -1.0, 0.0)), (32, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.7, -0.7, 0.0)), (12, (0.5, -0.3, -1.0)), (32, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.1), (9, 0.1), (10, -0.35), (24, -0.2), (32, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.1), (10, 0.3), (24, 0.3), (32, 0.4)],
        "foot_l": [(0, FL), (3, (0.13, 0.12, 0.04)), (5, (0.15, 0.077, 0.22)), (23, (0.15, 0.077, 0.22)), (26, (0.14, 0.12, 0.09)),
                   (29, FL), (32, FL)],
        "heel_l": [(0, 0), (3, 8), (4, -6), (5, -10), (8, 0), (23, 0), (25, 8), (28, 0)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.2, 1.0)), (26, (0.2, 0.2, 1.0)), (29, "auto")],
        "foot_r": [(0, FR), (5, (-0.15, 0.077, -0.08)), (23, (-0.15, 0.077, -0.08)), (29, FR)],
        "fyaw_r": [(0, 7), (6, 36), (10, 30), (23, 28), (29, 7)],
        "heel_r": [(0, 0), (8, 0), (10, 14), (13, 22), (20, 18), (27, 0)],
    },
    # the wave (Wave: push, tide, surf): the palms sink to the hips as the body sinks back (the water gathered), then rise in
    # arcs to the chest with the palms turning forward (held, the wave stood up); both palms push out wide as the weight goes
    # onto the front leg.  strike_s: the push
    "water_wave": {
        "length": 42,
        "meta": {"hold_s": 11 / FPS, "strike_s": 15 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.12, -0.05)), (11, (0.0, -0.09, -0.06)), (15, (0.0, -0.11, 0.13)),
                 (19, (0.0, -0.12, 0.15)), (26, (0.0, -0.11, 0.13)), (35, (0.0, -0.04, 0.03)), (42, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -6), (11, -8), (15, 4), (26, 3), (42, 0)],
        "hips": [(0, 0), (6, 6), (11, -2), (15, 6), (19, 8), (26, 6), (42, 0)],
        "chest": [(0, 0), (6, 8), (11, -5), (15, 6), (19, 10), (26, 7), (42, 0)],
        "head": [(0, 0), (6, 6), (11, -4), (15, -2), (42, 0)],
        "clav_r": [(0, (0, 0)), (6, (6, 6)), (11, (-6, -6)), (15, (14, -6)), (19, (16, -4)), (26, (12, -3)), (42, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (6, 6)), (11, (-6, -6)), (15, (14, -6)), (19, (16, -4)), (26, (12, -3)), (42, (0, 0))],
        "hand_r": [(0, HR), (6, (-0.22, 0.86, 0.2)), (9, (-0.3, 1.08, 0.12)), (11, (-0.24, 1.25, 0.04)), (13, (-0.25, 1.26, 0.3)),
                   (15, (-0.28, 1.22, 0.615)), (19, (-0.285, 1.16, 0.63)), (26, (-0.27, 1.12, 0.57)), (34, (-0.22, 0.95, 0.22)),
                   (42, HR)],
        "hand_l": [(0, HL), (6, (0.22, 0.86, 0.2)), (9, (0.3, 1.08, 0.12)), (11, (0.24, 1.25, 0.04)), (13, (0.25, 1.26, 0.3)),
                   (15, (0.28, 1.22, 0.605)), (19, (0.285, 1.16, 0.62)), (26, (0.27, 1.12, 0.57)), (34, (0.22, 0.95, 0.22)),
                   (42, HL)],
        "face_r": [(0, "stand"), (5, "palm_down"), (8, "palm_down"), (11, "chamber"), (14, "push"), (28, "push"), (42, "stand")],
        "face_l": [(0, "stand"), (5, "palm_down"), (8, "palm_down"), (11, "chamber"), (14, "push"), (28, "push"), (42, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-1.0, 0.0, -0.3)), (11, (-0.6, -0.8, -0.6)), (15, (-0.9, -0.6, 0.0)),
                   (42, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (1.0, 0.0, -0.3)), (11, (0.6, -0.8, -0.6)), (15, (0.9, -0.6, 0.0)),
                   (42, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.1), (11, 0.05), (14, -0.45), (30, -0.45), (42, 0.4)],
        "grip_l": [(0, 0.4), (5, -0.1), (11, 0.05), (14, -0.45), (30, -0.45), (42, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.12, 0.05)), (6, (0.16, 0.077, 0.26)), (29, (0.16, 0.077, 0.26)), (32, (0.15, 0.12, 0.1)),
                   (36, FL), (42, FL)],
        "heel_l": [(0, 0), (3, 8), (5, -6), (6, -12), (11, -10), (14, 0), (29, 0), (31, 8), (35, 0)],
        "knee_l": [(0, "auto"), (3, (0.25, 0.1, 1.0)), (32, (0.25, 0.1, 1.0)), (36, "auto")],
        "fyaw_l": [(0, 7), (6, 4), (32, 4), (36, 7)],
        "foot_r": [(0, FR), (6, (-0.16, 0.077, -0.08)), (29, (-0.16, 0.077, -0.08)), (36, FR)],
        "fyaw_r": [(0, 7), (6, 30), (29, 30), (36, 7)],
        "knee_r": [(0, "auto"), (6, (-0.4, 0.0, 1.0)), (32, (-0.4, 0.0, 1.0)), (36, "auto")],
    },
    # the draw (Flow: draw, geyser; Frost): from a pool: the palms reach out low and down over the water, the body sinking;
    # they part and circle out wide (held); then sweep in and up before the body, the palms turning up, drawing the water up
    # with them as the legs rise; on up over the head.  strike_s: the palms up before the chest
    "water_draw": {
        "length": 44,
        "meta": {"hold_s": 11 / FPS, "strike_s": 15 / FPS, "back_s": 27 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.13, 0.03)), (11, (0.0, -0.16, 0.02)), (15, (0.0, -0.07, 0.03)),
                 (19, (0.0, -0.035, 0.02)), (27, (0.0, -0.045, 0.02)), (36, (0.0, -0.03, 0.01)), (44, (0, -0.015, 0))],
        "hips": [(0, 0), (6, 14), (11, 12), (15, 2), (19, -2), (27, -1), (44, 0)],
        "chest": [(0, 0), (6, 14), (11, 10), (15, -2), (19, -6), (27, -4), (44, 0)],
        "head": [(0, 0), (6, 10), (11, 8), (15, -6), (19, -12), (27, -8), (44, 0)],
        "clav_r": [(0, (0, 0)), (6, (10, 6)), (11, (4, 2)), (15, (6, -10)), (19, (4, -16)), (27, (3, -12)), (44, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (10, 6)), (11, (4, 2)), (15, (6, -10)), (19, (4, -16)), (27, (3, -12)), (44, (0, 0))],
        "hand_r": [(0, HR), (6, (-0.16, 0.72, 0.42)), (9, (-0.34, 0.76, 0.32)), (11, (-0.42, 0.84, 0.16)), (13, (-0.3, 0.98, 0.32)),
                   (15, (-0.14, 1.15, 0.36)), (17, (-0.16, 1.35, 0.3)), (19, (-0.2, 1.5, 0.24)), (27, (-0.21, 1.46, 0.22)),
                   (35, (-0.22, 1.05, 0.2)), (44, HR)],
        "hand_l": [(0, HL), (6, (0.16, 0.72, 0.42)), (9, (0.34, 0.76, 0.32)), (11, (0.42, 0.84, 0.16)), (13, (0.3, 0.98, 0.32)),
                   (15, (0.14, 1.15, 0.36)), (17, (0.16, 1.35, 0.3)), (19, (0.2, 1.5, 0.24)), (27, (0.21, 1.46, 0.22)),
                   (35, (0.22, 1.05, 0.2)), (44, HL)],
        "face_r": [(0, "stand"), (5, "palm_down"), (11, "palm_down"), (14, "palm_up_wide"), (16, "chamber"), (19, "push"),
                   (29, "push"), (44, "stand")],
        "face_l": [(0, "stand"), (5, "palm_down"), (11, "palm_down"), (14, "palm_up_wide"), (16, "chamber"), (19, "push"),
                   (29, "push"), (44, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.6, 0.6, -0.4)), (11, (-0.8, -0.4, -0.6)), (15, (-1.0, -0.6, 0.0)),
                   (19, (-1.0, -0.2, 0.0)), (44, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, 0.6, -0.4)), (11, (0.8, -0.4, -0.6)), (15, (1.0, -0.6, 0.0)),
                   (19, (1.0, -0.2, 0.0)), (44, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.2), (14, -0.1), (17, 0.1), (19, -0.4), (30, -0.4), (44, 0.4)],
        "grip_l": [(0, 0.4), (5, -0.2), (14, -0.1), (17, 0.1), (19, -0.4), (30, -0.4), (44, 0.4)],
        "foot_l": [(0, FL), (3, (0.15, 0.12, 0.04)), (6, (0.19, 0.077, 0.14)), (30, (0.19, 0.077, 0.14)), (34, (0.16, 0.12, 0.07)),
                   (38, FL), (44, FL)],
        "heel_l": [(0, 0), (3, 8), (5, -4), (6, 0), (30, 0), (33, 8), (37, 0)],
        "fyaw_l": [(0, 7), (6, 14), (30, 14), (38, 7)],
        "knee_l": [(0, "auto"), (4, (0.35, 0.1, 1.0)), (34, (0.35, 0.1, 1.0)), (38, "auto")],
        "foot_r": [(0, FR), (6, (-0.19, 0.077, -0.06)), (30, (-0.19, 0.077, -0.06)), (38, FR)],
        "fyaw_r": [(0, 7), (6, 18), (30, 18), (38, 7)],
        "knee_r": [(0, "auto"), (4, (-0.35, 0.1, 1.0)), (34, (-0.35, 0.1, 1.0)), (38, "auto")],
        "heel_r": [(0, 0), (15, 0), (19, 10), (27, 8), (34, 0)],
    },
    # the shield (Water Shield: ice wall, bubble, heal; Frost: ice patch, freeze water): the hands cross low before the belly,
    # the body sinking (held); they rise apart before the face, the forearms upright and the palms out, the stance widening.
    # strike_s: the palms up
    "water_shield": {
        "length": 36,
        "meta": {"hold_s": 6 / FPS, "strike_s": 10 / FPS, "back_s": 22 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.11, 0.0)), (10, (0.0, -0.08, 0.03)), (13, (0.0, -0.085, 0.035)),
                 (22, (0.0, -0.09, 0.03)), (30, (0.0, -0.035, 0.01)), (36, (0, -0.015, 0))],
        "hips": [(0, 0), (6, 8), (10, 2), (22, 3), (36, 0)],
        "chest": [(0, 0), (6, 10), (10, -2), (13, -3), (22, -1), (36, 0)],
        "head": [(0, 0), (6, 10), (10, 0), (36, 0)],
        "clav_r": [(0, (0, 0)), (6, (8, 6)), (10, (6, -10)), (13, (6, -12)), (22, (5, -10)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (8, 6)), (10, (6, -10)), (13, (6, -12)), (22, (5, -10)), (36, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.1, 0.92, 0.22)), (6, (0.04, 0.96, 0.28)), (8, (-0.02, 1.2, 0.36)), (10, (-0.22, 1.42, 0.36)),
                   (13, (-0.24, 1.45, 0.37)), (22, (-0.23, 1.43, 0.35)), (30, (-0.2, 1.05, 0.2)), (36, HR)],
        "hand_l": [(0, HL), (4, (0.1, 0.92, 0.24)), (6, (-0.04, 0.98, 0.31)), (8, (0.02, 1.22, 0.38)), (10, (0.22, 1.42, 0.36)),
                   (13, (0.24, 1.45, 0.37)), (22, (0.23, 1.43, 0.35)), (30, (0.2, 1.05, 0.2)), (36, HL)],
        "face_r": [(0, "stand"), (4, "palm_down"), (7, "guard"), (10, "push"), (24, "push"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "palm_down"), (7, "guard"), (10, "push"), (24, "push"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-1.0, -0.2, -0.2)), (10, (-0.8, -1.0, 0.0)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (1.0, -0.2, -0.2)), (10, (0.8, -1.0, 0.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.0), (9, -0.5), (26, -0.5), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, 0.0), (9, -0.5), (26, -0.5), (36, 0.4)],
        "foot_r": [(0, FR), (3, (-0.15, 0.12, -0.02)), (6, (-0.22, 0.077, -0.05)), (26, (-0.22, 0.077, -0.05)),
                   (30, (-0.18, 0.12, -0.04)), (33, FR), (36, FR)],
        "heel_r": [(0, 0), (3, 10), (6, 0), (26, 0), (29, 10), (32, 0)],
        "fyaw_r": [(0, 7), (6, 16), (26, 16), (33, 7)],
        "foot_l": [(0, FL), (6, (0.17, 0.077, 0.04)), (26, (0.17, 0.077, 0.04)), (33, FL)],
        "fyaw_l": [(0, 7), (6, 14), (26, 14), (33, 7)],
        "knee_r": [(0, "auto"), (6, (-0.4, 0.0, 1.0)), (28, (-0.4, 0.0, 1.0)), (32, "auto")],
        "knee_l": [(0, "auto"), (6, (0.4, 0.0, 1.0)), (28, (0.4, 0.0, 1.0)), (32, "auto")],
    },
    # ---------------------------------------------------------------- air (Baguazhang: circles, spins)
    # the palm strike (Air Palm: palm, trip, cushion): a short step in, the right palm drawn back by the shoulder, the left
    # hand out ahead (held); the palm driven out, the heel of the hand leading, the left drawn back.  strike_s: the palm out
    "air_palm": {
        "length": 28, "mirror": True,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.05, 0.02)), (5, (0.0, -0.055, 0.02)), (8, (0.0, -0.07, 0.12)),
                 (11, (0.0, -0.075, 0.13)), (16, (0.0, -0.07, 0.12)), (23, (0.0, -0.03, 0.03)), (28, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -16), (8, 12), (11, 16), (16, 12), (28, 0)],
        "twist": [(0, 0), (5, -10), (8, 8), (11, 10), (16, 8), (28, 0)],
        "hips": [(0, 0), (5, 2), (8, 5), (11, 6), (16, 4), (28, 0)],
        "chest": [(0, 0), (5, 2), (8, 6), (11, 7), (16, 5), (28, 0)],
        "clav_r": [(0, (0, 0)), (5, (-8, -2)), (8, (14, -4)), (11, (16, -4)), (16, (12, -3)), (28, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, -4)), (8, (-4, 2)), (28, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.22, 1.1, 0.08)), (5, (-0.22, 1.24, 0.0)), (7, (-0.1, 1.26, 0.4)), (8, (-0.03, 1.24, 0.64)),
                   (11, (-0.025, 1.235, 0.64)), (16, (-0.04, 1.22, 0.6)), (23, (-0.18, 1.0, 0.2)), (28, HR)],
        "hand_l": [(0, HL), (3, (0.14, 1.18, 0.28)), (5, (0.1, 1.24, 0.36)), (8, (0.18, 1.08, 0.12)), (11, (0.19, 1.05, 0.06)),
                   (16, (0.19, 1.05, 0.07)), (28, HL)],
        "face_r": [(0, "stand"), (3, "push"), (16, "push"), (28, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (6, "push"), (9, "palm_down"), (18, "palm_down"), (28, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.6, -0.8, -0.6)), (8, (-0.8, -0.6, 0.0)), (28, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.6, -0.8, 0.0)), (9, (0.6, -0.6, -0.6)), (28, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.4), (20, -0.4), (28, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.4), (20, -0.2), (28, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.14, 0.077, 0.22)), (20, (0.14, 0.077, 0.22)), (23, (0.13, 0.12, 0.09)),
                   (26, FL), (28, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 0), (20, 0), (22, 8), (25, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (24, (0.2, 0.2, 1.0)), (26, "auto")],
        "foot_r": [(0, FR), (4, (-0.14, 0.077, -0.06)), (20, (-0.14, 0.077, -0.06)), (26, FR)],
        "fyaw_r": [(0, 7), (5, 28), (8, 36), (20, 34), (26, 7)],
        "heel_r": [(0, 0), (5, 4), (8, 16), (16, 14), (23, 0)],
    },
    # the circular sweep (Air Blast: ball, vacuum): both arms wound out to the right, the body turned with them (held); they
    # sweep round flat before the body in a big circle to the left, the palms pushing the air round, the body turning through.
    # strike_s: the palms across the front
    "air_sweep": {
        "length": 36,
        "meta": {"hold_s": 7 / FPS, "strike_s": 11 / FPS, "back_s": 22 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (7, (-0.03, -0.08, 0.0)), (11, (0.0, -0.1, 0.06)), (15, (0.03, -0.1, 0.05)),
                 (22, (0.03, -0.09, 0.04)), (30, (0.0, -0.035, 0.01)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (7, -30), (11, 0), (15, 28), (22, 24), (36, 0)],
        "twist": [(0, 0), (7, -20), (11, 0), (15, 18), (22, 14), (36, 0)],
        "hips": [(0, 0), (7, 4), (11, 6), (15, 4), (36, 0)],
        "chest": [(0, 0), (7, 4), (11, 7), (15, 4), (36, 0)],
        "side": [(0, 0), (7, -4), (11, 0), (15, 4), (36, 0)],
        "clav_r": [(0, (0, 0)), (7, (-8, -6)), (11, (10, -8)), (15, (14, -4)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (7, (12, -6)), (11, (10, -8)), (15, (-6, -6)), (36, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.32, 1.1, 0.1)), (7, (-0.46, 1.22, 0.05)), (9, (-0.38, 1.25, 0.4)), (11, (-0.09, 1.25, 0.55)),
                   (13, (0.14, 1.22, 0.5)), (15, (0.2, 1.2, 0.3)), (22, (0.2, 1.18, 0.28)), (30, (-0.18, 0.98, 0.18)), (36, HR)],
        "hand_l": [(0, HL), (4, (0.02, 1.12, 0.3)), (7, (-0.14, 1.22, 0.38)), (9, (0.06, 1.25, 0.52)), (11, (0.3, 1.25, 0.52)),
                   (13, (0.45, 1.22, 0.3)), (15, (0.46, 1.2, 0.08)), (22, (0.45, 1.18, 0.07)), (30, (0.2, 0.98, 0.18)), (36, HL)],
        "face_r": [(0, "stand"), (4, "sweep_out"), (8, "sweep_out"), (11, "push"), (14, "sweep_in"), (24, "sweep_in"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "sweep_in"), (8, "sweep_in"), (11, "push"), (14, "sweep_out"), (24, "sweep_out"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (7, (-0.3, -1.0, -0.5)), (11, (-0.6, -1.0, 0.0)), (15, (-0.2, -1.0, 0.0)),
                   (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (7, (0.2, -1.0, 0.0)), (11, (0.6, -1.0, 0.0)), (15, (0.3, -1.0, -0.5)),
                   (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.4), (26, -0.4), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.4), (26, -0.4), (36, 0.4)],
        "foot_r": [(0, FR), (7, (-0.18, 0.077, -0.04)), (28, (-0.18, 0.077, -0.04)), (33, FR)],
        "fyaw_r": [(0, 7), (7, 30), (11, 14), (15, 0), (28, 0), (33, 7)],
        "heel_r": [(0, 0), (11, 0), (15, 12), (22, 10), (28, 0)],
        "foot_l": [(0, FL), (7, (0.18, 0.077, 0.04)), (28, (0.18, 0.077, 0.04)), (33, FL)],
        "fyaw_l": [(0, 7), (7, 0), (11, 12), (15, 28), (28, 26), (33, 7)],
        "heel_l": [(0, 0), (4, 6), (7, 10), (11, 0), (36, 0)],
    },
    # the spin (Evade: spin; Air Shield: cyclone, tornado): a little sink, the arms gathered and the body wound the other way
    # (held); a whole turn to the left on the balls of the feet, the arms flung out wide; settled facing the mark again.
    # strike_s: the turn under way
    "air_spin": {
        "length": 36,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 20 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "spin": [(0, 0), (5, -20), (8, 70), (11, 190), (14, 300), (17, 360), (36, 360)],
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.09, 0.0)), (8, (0.0, -0.05, 0.0)), (12, (0.0, -0.03, 0.0)), (17, (0.0, -0.08, 0.0)),
                 (20, (0.0, -0.09, 0.0)), (28, (0.0, -0.035, 0.0)), (36, (0, -0.015, 0))],
        "hips": [(0, 0), (5, 6), (8, 2), (14, 2), (17, 5), (36, 0)],
        "chest": [(0, 0), (5, 8), (8, -2), (14, -2), (17, 4), (36, 0)],
        "twist": [(0, 0), (5, 14), (8, -10), (11, -14), (14, -8), (17, 4), (22, 0), (36, 0)],
        "head": [(0, 0), (5, 4), (8, -2), (36, 0)],
        "clav_r": [(0, (0, 0)), (5, (8, 4)), (8, (0, -8)), (14, (0, -8)), (18, (2, 0)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, 4)), (8, (0, -8)), (14, (0, -8)), (18, (2, 0)), (36, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.08, 1.05, 0.25)), (8, (-0.44, 1.28, 0.08)), (11, (-0.48, 1.3, 0.02)), (14, (-0.47, 1.28, 0.02)),
                   (17, (-0.32, 1.12, 0.2)), (20, (-0.3, 1.08, 0.22)), (28, (-0.2, 0.92, 0.12)), (36, HR)],
        "hand_l": [(0, HL), (5, (0.08, 1.08, 0.28)), (8, (0.44, 1.28, 0.08)), (11, (0.48, 1.3, 0.02)), (14, (0.47, 1.28, 0.02)),
                   (17, (0.32, 1.12, 0.2)), (20, (0.3, 1.08, 0.22)), (28, (0.2, 0.92, 0.12)), (36, HL)],
        "face_r": [(0, "stand"), (4, "palm_down"), (7, "arms_out"), (15, "arms_out"), (18, "push"), (24, "push"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "palm_down"), (7, "arms_out"), (15, "arms_out"), (18, "push"), (24, "push"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-1.0, -0.4, -0.2)), (8, (0.0, -0.4, -1.0)), (16, (0.0, -0.4, -1.0)),
                   (18, (-0.8, -0.6, 0.0)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (1.0, -0.4, -0.2)), (8, (0.0, -0.4, -1.0)), (16, (0.0, -0.4, -1.0)),
                   (18, (0.8, -0.6, 0.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.3), (24, -0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.3), (24, -0.3), (36, 0.4)],
        "foot_r": [(0, FR), (36, FR)], "foot_l": [(0, FL), (36, FL)],
        "heel_r": [(0, 0), (5, 0), (7, 22), (15, 22), (18, 0), (36, 0)],
        "heel_l": [(0, 0), (5, 0), (7, 22), (15, 22), (18, 0), (36, 0)],
        "knee_r": [(0, "auto"), (5, (-0.3, 0.0, 1.0)), (20, (-0.3, 0.0, 1.0)), (28, "auto")],
        "knee_l": [(0, "auto"), (5, (0.3, 0.0, 1.0)), (20, (0.3, 0.0, 1.0)), (28, "auto")],
    },
    # the leap (Air Jump: leap, dash; Fire Jets; Footwork; Wind Run: updraft): a deep crouch, the arms swung back low (held);
    # the spring: the legs drive straight up onto the toes and the arms swing up overhead; off the ground the knees draw up a
    # little, the toes pointed; down to the stand.  strike_s: the spring
    "air_leap": {
        "length": 32,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 20 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.18, 0.02)), (6, (0.0, -0.26, 0.03)), (9, (0.0, 0.0, 0.04)),
                 (11, (0.0, 0.04, 0.04)), (14, (0.0, 0.05, 0.03)), (20, (0.0, -0.02, 0.02)), (24, (0.0, -0.1, 0.02)),
                 (32, (0, -0.015, 0))],
        "hips": [(0, 0), (4, 16), (6, 24), (9, 2), (11, -4), (14, 4), (20, 6), (24, 10), (32, 0)],
        "chest": [(0, 0), (4, 14), (6, 20), (9, -2), (11, -6), (14, 0), (20, 2), (24, 6), (32, 0)],
        "head": [(0, 0), (6, -16), (9, -10), (11, -8), (20, 0), (32, 0)],
        "clav_r": [(0, (0, 0)), (6, (-8, 6)), (9, (6, -20)), (11, (6, -24)), (16, (4, -10)), (24, (4, 0)), (32, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (-8, 6)), (9, (6, -20)), (11, (6, -24)), (16, (4, -10)), (24, (4, 0)), (32, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.24, 0.73, -0.02)), (6, (-0.235, 0.66, -0.155)), (8, (-0.22, 1.0, 0.26)), (9, (-0.2, 1.42, 0.28)),
                   (11, (-0.2, 1.74, 0.16)), (14, (-0.24, 1.6, 0.16)), (20, (-0.3, 1.25, 0.2)), (24, (-0.25, 0.95, 0.25)), (32, HR)],
        "hand_l": [(0, HL), (4, (0.24, 0.73, -0.02)), (6, (0.235, 0.66, -0.155)), (8, (0.22, 1.0, 0.26)), (9, (0.2, 1.42, 0.28)),
                   (11, (0.2, 1.74, 0.16)), (14, (0.24, 1.6, 0.16)), (20, (0.3, 1.25, 0.2)), (24, (0.25, 0.95, 0.25)), (32, HL)],
        "face_r": [(0, "stand"), (4, "flick_back"), (7, "flick_back"), (9, "fist_up"), (13, "fist_up"), (18, "brace"), (24, "brace"),
                   (32, "stand")],
        "face_l": [(0, "stand"), (4, "flick_back"), (7, "flick_back"), (9, "fist_up"), (13, "fist_up"), (18, "brace"), (24, "brace"),
                   (32, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.4, 0.4, -1.0)), (9, (-1.0, -0.2, 0.0)), (20, (-0.8, -0.4, -0.3)),
                   (32, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.4, 0.4, -1.0)), (9, (1.0, -0.2, 0.0)), (20, (0.8, -0.4, -0.3)),
                   (32, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.3), (20, -0.3), (32, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.3), (20, -0.3), (32, 0.4)],
        # the feet: down through the crouch and onto the toes at the spring; off the ground the toes pointed and the knees
        # drawn up a little; reaching down for the stand
        "foot_r": [(0, FR), (9, FR), (12, (-0.13, 0.16, 0.03)), (15, (-0.13, 0.2, 0.06)), (19, (-0.13, 0.12, 0.02)), (21, FR),
                   (32, FR)],
        "foot_l": [(0, FL), (9, FL), (12, (0.13, 0.14, 0.01)), (15, (0.13, 0.22, 0.08)), (19, (0.13, 0.13, 0.03)), (21, FL),
                   (32, FL)],
        "heel_r": [(0, 0), (6, 0), (9, 40), (12, 45), (17, 35), (21, 0), (32, 0)],
        "heel_l": [(0, 0), (6, 0), (9, 40), (12, 45), (17, 35), (21, 0), (32, 0)],
        "knee_r": [(0, "auto"), (4, (-0.35, 0.0, 1.0)), (26, (-0.35, 0.0, 1.0)), (30, "auto")],
        "knee_l": [(0, "auto"), (4, (0.35, 0.0, 1.0)), (26, (0.35, 0.0, 1.0)), (30, "auto")],
        "fyaw_r": [(0, 7), (6, 14), (12, 7), (32, 7)], "fyaw_l": [(0, 7), (6, 14), (12, 7), (32, 7)],
    },
    # the shield circle (Air Shield: shield): the palms circle up and round before the body - down and in, out wide, up over
    # the head - meeting at the top (held); then pushed out forward and apart, the air standing as a wall.  strike_s: the
    # palms out
    "air_shield": {
        "length": 38,
        "meta": {"hold_s": 9 / FPS, "strike_s": 13 / FPS, "back_s": 24 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.07, 0.0)), (9, (0.0, -0.04, -0.02)), (13, (0.0, -0.09, 0.08)),
                 (16, (0.0, -0.1, 0.09)), (24, (0.0, -0.09, 0.08)), (31, (0.0, -0.035, 0.02)), (38, (0, -0.015, 0))],
        "hips": [(0, 0), (4, 6), (9, -2), (13, 5), (16, 6), (24, 5), (38, 0)],
        "chest": [(0, 0), (4, 7), (9, -6), (13, 6), (16, 8), (24, 6), (38, 0)],
        "head": [(0, 0), (4, 4), (9, -8), (13, -2), (38, 0)],
        "clav_r": [(0, (0, 0)), (4, (6, 4)), (7, (0, -14)), (9, (2, -22)), (13, (14, -6)), (24, (11, -5)), (38, (0, 0))],
        "clav_l": [(0, (0, 0)), (4, (6, 4)), (7, (0, -14)), (9, (2, -22)), (13, (14, -6)), (24, (11, -5)), (38, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.08, 0.95, 0.24)), (5, (-0.4, 1.1, 0.2)), (7, (-0.36, 1.48, 0.18)), (9, (-0.085, 1.665, 0.23)),
                   (11, (-0.16, 1.48, 0.42)), (13, (-0.222, 1.322, 0.57)), (16, (-0.225, 1.31, 0.58)), (24, (-0.22, 1.28, 0.55)),
                   (31, (-0.2, 1.0, 0.2)), (38, HR)],
        "hand_l": [(0, HL), (3, (0.08, 0.95, 0.24)), (5, (0.4, 1.1, 0.2)), (7, (0.36, 1.48, 0.18)), (9, (0.085, 1.665, 0.23)),
                   (11, (0.16, 1.48, 0.42)), (13, (0.222, 1.322, 0.57)), (16, (0.225, 1.31, 0.58)), (24, (0.22, 1.28, 0.55)),
                   (31, (0.2, 1.0, 0.2)), (38, HL)],
        "face_r": [(0, "stand"), (3, "palm_down"), (5, "arms_out"), (7, "palm_up_wide"), (9, "fist_up"), (12, "push"), (26, "push"),
                   (38, "stand")],
        "face_l": [(0, "stand"), (3, "palm_down"), (5, "arms_out"), (7, "palm_up_wide"), (9, "fist_up"), (12, "push"), (26, "push"),
                   (38, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.2, -1.0, -0.6)), (9, (-1.0, 0.0, 0.0)), (13, (-0.9, -0.6, 0.0)),
                   (38, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.2, -1.0, -0.6)), (9, (1.0, 0.0, 0.0)), (13, (0.9, -0.6, 0.0)),
                   (38, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.3), (28, -0.4), (38, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (28, -0.4), (38, 0.4)],
        "foot_l": [(0, FL), (10, FL), (11, (0.14, 0.12, 0.08)), (13, (0.15, 0.077, 0.2)), (28, (0.15, 0.077, 0.2)),
                   (31, (0.14, 0.12, 0.08)), (34, FL), (38, FL)],
        "heel_l": [(0, 0), (10, 0), (11, 8), (12, -4), (13, 0), (28, 0), (30, 8), (33, 0)],
        "foot_r": [(0, FR), (13, (-0.15, 0.077, -0.06)), (28, (-0.15, 0.077, -0.06)), (34, FR)],
        "fyaw_r": [(0, 7), (13, 28), (28, 28), (34, 7)],
        "heel_r": [(0, 0), (13, 8), (24, 6), (32, 0)],
    },
}
CLIPS.update(SET2)

## ---------------------------------------------------------------- the third set (2026-10-05, round 2 of the skills: the moves
## the new kits need; authored the same way, key poses typed here, nothing read). Northern Shaolin (fire), Hung Gar (earth), tai
## chi (water) and Baguazhang (air) are style labels for the typed poses, as above.
FACING.update({
    "lift_out": ((-0.35, 0.45, 0.82), (-0.15, 0.85, -0.5)),    # the uproot's palms flung up and out, the palms up and back
    "knife_up": ((0.0, 0.97, 0.22), (0.97, 0.0, -0.2)),        # the parry's knife hand stood up before the face, the palm in
    "bagua": ((-0.2, 0.95, 0.2), (0.92, 0.1, 0.38)),           # a circle walker's lead palm out at the side, turned in to the centre
    "slice_back": ((0.55, 0.25, -0.8), (0.0, -0.95, -0.3)),    # the slice's hand cocked back by the ear, the palm down
    "slice": ((0.45, 0.0, 0.89), (0.0, -1.0, 0.0)),            # the slice out flat, the palm down, the fingers ahead and across
})


def _ring(frames, fn):
    """A loop's keys round a circle: fn(angle in radians) at each of `frames` (the first's again at the last, the seam)."""
    n = len(frames) - 1
    return [(fr, fn(2 * math.pi * (i % n) / n)) for i, fr in enumerate(frames)]


def EIGHTHS(length):
    """A loop's nine key frames: its eighths, the seam's frame last."""
    return [length * i // 8 for i in range(9)]


def _r3(v):
    return tuple(round(x, 4) for x in v)


SET3 = {
    # the low kick (the Kick: the floor wave; the tell the opponent reads, so the chamber is LOW): sunk deep onto the bent left
    # leg, the body bowed forward and coiled to the right, the right foot drawn far back behind just off the deck, the fists
    # up (held); the foot sweeps out wide round and in, forward and across, the leg long and the sole skimming the deck at the
    # shin's height (a crescent along the floor), the body turning through low over the standing knee; set down ahead into a
    # low bow stance.  strike_s: the foot across the front
    "fire_kick_low": {
        "length": 32, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 20 / FPS, "hand": "foot_r", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, (0, -0.015, 0)), (3, (0.05, -0.12, -0.03)), (6, (0.08, -0.25, -0.06)), (9, (0.05, -0.26, 0.0)),
                 (12, (0.02, -0.25, 0.08)), (15, (0.0, -0.22, 0.16)), (20, (0.0, -0.215, 0.155)), (27, (0.0, -0.07, 0.04)),
                 (32, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -18), (9, 12), (12, 20), (15, 10), (20, 8), (32, 0)],
        "twist": [(0, 0), (6, -12), (9, 10), (12, 14), (20, 6), (32, 0)],
        "hips": [(0, 0), (6, 20), (9, 2), (12, 6), (15, 12), (20, 11), (32, 0)],
        "chest": [(0, 0), (6, 12), (9, 8), (15, 8), (20, 6), (32, 0)],
        "roll": [(0, 0), (6, -5), (9, 4), (15, 0), (32, 0)],
        "side": [(0, 0), (6, 8), (9, 4), (15, 0), (32, 0)],
        "head": [(0, 0), (6, -14), (9, -10), (15, -8), (20, -7), (32, 0)],
        "clav_r": [(0, (0, 0)), (6, (6, -2)), (9, (-10, 6)), (15, (10, -2)), (20, (8, -2)), (32, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (10, -2)), (9, (14, -3)), (15, (8, -2)), (20, (6, -2)), (32, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.15, 1.04, 0.16)), (6, (-0.16, 0.98, 0.22)), (9, (-0.34, 0.8, -0.08)), (12, (-0.28, 0.84, 0.0)),
                   (15, (-0.17, 0.94, 0.14)), (20, (-0.17, 0.94, 0.14)), (27, (-0.18, 0.9, 0.12)), (32, HR)],
        "hand_l": [(0, HL), (3, (0.1, 1.1, 0.3)), (6, (0.05, 1.04, 0.4)), (9, (0.03, 1.02, 0.44)), (12, (0.05, 1.03, 0.44)),
                   (15, (0.07, 1.05, 0.44)), (20, (0.07, 1.05, 0.43)), (27, (0.16, 0.94, 0.16)), (32, HL)],
        "face_r": [(0, "stand"), (3, "fist_guard"), (7, "fist_guard"), (9, "fist_low"), (13, "chamber"), (22, "chamber"),
                   (32, "stand")],
        "face_l": [(0, "stand"), (3, "fist_guard"), (22, "fist_guard"), (32, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.5, -1.0, -0.2)), (9, (-1.0, -0.2, 0.2)), (15, (-0.3, -0.5, -1.0)),
                   (32, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.4, -1.0, -0.2)), (32, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 1.0), (26, 1.0), (32, 0.4)],
        "grip_l": [(0, 0.4), (3, 1.0), (26, 1.0), (32, 0.4)],
        # the right foot: drawn far back off the deck behind, round out wide to the side, forward and in across the front at
        # the shin's height, its sole just over the deck; set down ahead in the bow stance; back in at the end
        "foot_r": [(0, FR), (3, (-0.16, 0.1, -0.16)), (6, (-0.2, 0.13, -0.36)), (7, (-0.4, 0.13, -0.12)),
                   (8, (-0.38, 0.13, 0.26)), (9, (-0.105, 0.1, 0.57)), (10, (0.03, 0.12, 0.53)), (12, (0.01, 0.125, 0.44)),
                   (14, (-0.09, 0.1, 0.42)), (15, (-0.12, 0.077, 0.41)), (24, (-0.12, 0.077, 0.41)), (27, (-0.13, 0.13, 0.19)),
                   (30, FR), (32, FR)],
        "heel_r": [(0, 0), (3, 18), (6, 34), (8, 4), (9, -12), (12, -6), (15, 0), (24, 0), (26, 12), (29, 0), (32, 0)],
        "fyaw_r": [(0, 7), (6, 20), (8, 0), (9, -30), (12, -22), (15, 8), (24, 8), (30, 7)],
        "knee_r": [(0, "auto"), (3, (-0.2, -0.3, 1.0)), (6, (-0.3, -0.8, 0.5)), (7, (-0.7, 0.2, 1.0)), (10, (-0.3, 0.4, 1.0)),
                   (15, (-0.15, 0.1, 1.0)), (27, (-0.15, 0.1, 1.0)), (30, "auto")],
        "foot_l": [(0, FL), (32, FL)],
        "fyaw_l": [(0, 7), (6, 16), (9, 26), (15, 32), (24, 32), (30, 7)],
        "heel_l": [(0, 0), (9, 4), (15, 16), (22, 14), (28, 0), (32, 0)],
        "knee_l": [(0, "auto"), (3, (0.35, 0.0, 1.0)), (26, (0.35, 0.0, 1.0)), (30, "auto")],
    },
    # the Fireball (Punch held to grow it): a deeper chamber than the punch's: the body coiled hard to the right and sunk back on
    # the rear leg, the right hand drawn far back by the hip cupping the fire, the left palm out ahead aiming (held while it
    # grows); the hips snap through, a long step's bow stance and the palm driven out at the shoulder's height, the left
    # pulled back to the ribs.  strike_s: the palm out
    "fire_fireball": {
        "length": 36, "mirror": True,
        "meta": {"hold_s": 8 / FPS, "strike_s": 11 / FPS, "back_s": 22 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.08, -0.02)), (8, (0.02, -0.15, -0.08)), (11, (0.0, -0.13, 0.15)),
                 (14, (0.0, -0.14, 0.17)), (22, (0.0, -0.13, 0.15)), (29, (0.0, -0.05, 0.04)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (4, -16), (8, -34), (11, 18), (14, 22), (22, 18), (36, 0)],
        "twist": [(0, 0), (4, -10), (8, -20), (11, 14), (14, 16), (22, 12), (36, 0)],
        "hips": [(0, 0), (8, 2), (11, 9), (14, 10), (22, 8), (36, 0)],
        "chest": [(0, 0), (8, 0), (11, 10), (14, 12), (22, 9), (36, 0)],
        "side": [(0, 0), (8, 4), (11, -2), (22, -1), (36, 0)],
        "head": [(0, 0), (8, 1), (11, -3), (36, 0)],
        "clav_r": [(0, (0, 0)), (8, (-14, 4)), (11, (18, -4)), (14, (20, -4)), (22, (16, -3)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (10, -2)), (11, (-6, 2)), (22, (-4, 2)), (36, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.2, 1.0, 0.0)), (8, (-0.26, 0.98, -0.24)), (10, (-0.12, 1.22, 0.33)), (11, (-0.025, 1.32, 0.74)),
                   (14, (-0.025, 1.32, 0.745)), (22, (-0.035, 1.3, 0.71)), (29, (-0.18, 1.0, 0.2)), (36, HR)],
        "hand_l": [(0, HL), (4, (0.12, 1.18, 0.3)), (8, (0.08, 1.3, 0.47)), (11, (0.19, 1.05, 0.04)), (14, (0.19, 1.03, 0.0)),
                   (22, (0.19, 1.03, 0.01)), (29, (0.18, 0.92, 0.1)), (36, HL)],
        "face_r": [(0, "stand"), (3, "chamber"), (9, "chamber"), (11, "push"), (24, "push"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "fist_guard"), (7, "push"), (9, "push"), (11, "chamber"), (24, "chamber"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (8, (-0.6, -0.6, -0.6)), (11, (-0.8, -0.6, -0.1)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (8, (0.5, -0.8, -0.3)), (11, (0.3, -0.5, -1.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 0.3), (9, 0.3), (11, -0.3), (26, -0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, 0.6), (7, -0.3), (10, 1.0), (26, 1.0), (36, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.04)), (5, (0.15, 0.077, 0.28)), (27, (0.15, 0.077, 0.28)), (30, (0.14, 0.12, 0.1)),
                   (34, FL), (36, FL)],
        "heel_l": [(0, 0), (2, 8), (4, -4), (5, 0), (27, 0), (29, 8), (33, 0)],
        "knee_l": [(0, "auto"), (2, (0.25, 0.2, 1.0)), (31, (0.25, 0.2, 1.0)), (34, "auto")],
        "foot_r": [(0, FR), (5, (-0.16, 0.077, -0.12)), (28, (-0.16, 0.077, -0.12)), (34, FR)],
        "fyaw_r": [(0, 7), (5, 30), (8, 50), (11, 40), (28, 40), (34, 7)],
        "heel_r": [(0, 0), (8, 0), (11, 26), (14, 30), (22, 24), (30, 0)],
        "knee_r": [(0, "auto"), (5, (-0.5, 0.0, 1.0)), (28, (-0.5, 0.0, 1.0)), (32, "auto")],
    },
    # the Parry (fire's guard): side-on, the left fist chambered at the ribs, the right forearm stood up before the face with
    # the knife hand's edge to the shot (held: the window); the knife hand cuts down and out straight ahead along the aim, the
    # arm long, the body snapping round behind it (the shot sent back).  strike_s: the knife hand out ahead
    "fire_parry": {
        "length": 30,
        "meta": {"hold_s": 4 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (2, (0.0, -0.06, 0.0)), (4, (0.0, -0.09, -0.04)), (8, (0.0, -0.12, 0.12)),
                 (11, (0.0, -0.125, 0.13)), (16, (0.0, -0.12, 0.12)), (24, (0.0, -0.04, 0.02)), (30, (0, -0.015, 0))],
        "yaw": [(0, 0), (4, -24), (8, 16), (11, 20), (16, 16), (30, 0)],
        "twist": [(0, 0), (4, -14), (8, 12), (11, 14), (16, 11), (30, 0)],
        "hips": [(0, 0), (4, -2), (8, 8), (16, 6), (30, 0)],
        "chest": [(0, 0), (4, -4), (8, 10), (11, 11), (16, 8), (30, 0)],
        "side": [(0, 0), (4, 4), (8, -3), (16, -2), (30, 0)],
        "head": [(0, 0), (4, -2), (8, -3), (30, 0)],
        "clav_r": [(0, (0, 0)), (4, (2, -8)), (8, (16, -4)), (11, (18, -4)), (16, (14, -3)), (30, (0, 0))],
        "clav_l": [(0, (0, 0)), (4, (-6, 2)), (8, (-6, 2)), (16, (-4, 2)), (30, (0, 0))],
        "hand_r": [(0, HR), (2, (-0.16, 1.28, 0.24)), (4, (-0.06, 1.45, 0.22)), (6, (-0.07, 1.38, 0.42)), (8, (-0.035, 1.31, 0.72)),
                   (11, (-0.03, 1.31, 0.72)), (16, (-0.04, 1.29, 0.68)), (24, (-0.18, 1.0, 0.2)), (30, HR)],
        "hand_l": [(0, HL), (2, (0.17, 1.06, 0.08)), (4, (0.19, 1.04, 0.03)), (8, (0.19, 1.04, 0.03)), (16, (0.19, 1.04, 0.04)),
                   (24, (0.18, 0.92, 0.1)), (30, HL)],
        "face_r": [(0, "stand"), (2, "knife_up"), (5, "knife_up"), (8, "knife"), (18, "knife"), (30, "stand")],
        "face_l": [(0, "stand"), (2, "chamber"), (18, "chamber"), (30, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (4, (-0.3, -1.0, 0.3)), (8, (-0.5, -1.0, 0.0)), (30, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (4, (0.3, -0.5, -1.0)), (30, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (2, -0.5), (22, -0.5), (30, 0.4)],
        "grip_l": [(0, 0.4), (2, 1.0), (24, 1.0), (30, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.14, 0.077, 0.22)), (20, (0.14, 0.077, 0.22)), (23, (0.13, 0.12, 0.08)),
                   (27, FL), (30, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 0), (20, 0), (22, 8), (26, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (24, (0.2, 0.2, 1.0)), (27, "auto")],
        "foot_r": [(0, FR), (4, (-0.15, 0.077, -0.1)), (22, (-0.15, 0.077, -0.1)), (27, FR)],
        "fyaw_r": [(0, 7), (4, 40), (8, 36), (22, 36), (27, 7)],
        "heel_r": [(0, 0), (4, 4), (8, 24), (16, 18), (24, 0)],
    },
    # ---------------------------------------------------------------- earth
    # the kick-up (Shove's kick-and-push: the stone kicked up off the deck, the push after it): the boulder's kick mirrored and
    # short: the weight onto the left leg, the right foot lifts (held), and kicks up and forward, the toes up under the stone,
    # the palms rising to the ribs ready to push; set down a little ahead.  strike_s: the toes at the top
    "earth_kickup": {
        "length": 18, "mirror": True,
        "meta": {"hold_s": 3 / FPS, "strike_s": 6 / FPS, "back_s": 10 / FPS, "hand": "foot_r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.05, -0.04, -0.01)), (6, (0.065, -0.03, -0.03)), (9, (0.05, -0.05, 0.0)),
                 (11, (0.02, -0.09, 0.05)), (14, (0.01, -0.06, 0.02)), (18, (0, -0.015, 0))],
        "yaw": [(0, 0), (3, -3), (6, -5), (11, 3), (18, 0)],
        "roll": [(0, 0), (3, -4), (6, -5), (9, -3), (11, 0), (18, 0)],
        "hips": [(0, 0), (3, -3), (6, -7), (9, -2), (11, 5), (14, 3), (18, 0)],
        "chest": [(0, 0), (3, -4), (6, -6), (9, -2), (11, 5), (14, 3), (18, 0)],
        "side": [(0, 0), (3, 3), (6, 4), (11, 0), (18, 0)],
        "head": [(0, 0), (3, 6), (6, 8), (9, 4), (11, 0), (18, 0)],
        "clav_r": [(0, (0, 0)), (6, (2, -6)), (10, (-6, 4)), (18, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (2, -6)), (10, (-6, 4)), (18, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.2, 0.9, 0.16)), (6, (-0.17, 1.06, 0.28)), (10, (-0.18, 1.03, -0.02)), (14, (-0.19, 0.92, 0.04)),
                   (18, HR)],
        "hand_l": [(0, HL), (3, (0.2, 0.9, 0.16)), (6, (0.17, 1.06, 0.28)), (10, (0.18, 1.03, -0.02)), (14, (0.19, 0.92, 0.04)),
                   (18, HL)],
        "face_r": [(0, "stand"), (3, "chamber"), (14, "chamber"), (18, "stand")],
        "face_l": [(0, "stand"), (3, "chamber"), (14, "chamber"), (18, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.8, -0.6, -0.4)), (10, (-0.3, -0.4, -1.0)), (18, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.8, -0.6, -0.4)), (10, (0.3, -0.4, -1.0)), (18, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.2), (12, -0.2), (18, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.2), (12, -0.2), (18, 0.4)],
        "foot_r": [(0, FR), (2, (-0.14, 0.11, 0.0)), (3, (-0.14, 0.15, 0.07)), (5, (-0.155, 0.3, 0.42)), (6, (-0.16, 0.37, 0.53)),
                   (8, (-0.15, 0.3, 0.38)), (10, (-0.145, 0.15, 0.2)), (11, (-0.14, 0.077, 0.12)), (13, (-0.14, 0.077, 0.12)),
                   (15, (-0.135, 0.11, 0.03)), (17, FR), (18, FR)],
        "heel_r": [(0, 0), (2, 14), (3, 4), (5, -18), (6, -26), (8, -14), (10, -4), (11, 0), (13, 0), (14, 10), (16, 0), (18, 0)],
        "fyaw_r": [(0, 7), (6, 0), (11, 7), (18, 7)],
        "knee_r": [(0, "auto"), (2, (-0.15, 0.3, 1.0)), (13, (-0.15, 0.3, 1.0)), (16, "auto")],
        "foot_l": [(0, FL), (18, FL)],
        "fyaw_l": [(0, 7), (6, 12), (12, 9), (18, 7)],
        "knee_l": [(0, "auto"), (3, (0.3, 0.0, 1.0)), (12, (0.3, 0.0, 1.0)), (16, "auto")],
    },
    # the uproot (Column): the left knee up and the foot stamped down ahead into a deep bow stance, the body bowed down over it
    # with both palms pressed flat by the deck (held: the stone gripped under it); then the palms sweep up and out, wide apart
    # and far ahead, the fingers at the mark, the body rising behind them (the column torn up out at range); held up there.
    # Unlike the raise (the wall: the right foot stamped out wide, the palms rising close before the chest), it reaches out.
    # strike_s: the palms up and out
    "earth_uproot": {
        "length": 42, "meta": {"hold_s": 10 / FPS, "strike_s": 14 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (-0.04, -0.03, -0.02)), (8, (0.0, -0.2, 0.12)), (10, (0.0, -0.235, 0.12)),
                 (14, (0.0, -0.11, 0.19)), (17, (0.0, -0.09, 0.21)), (26, (0.0, -0.1, 0.19)), (34, (0.0, -0.04, 0.05)),
                 (42, (0, -0.015, 0))],
        "roll": [(0, 0), (4, -4), (8, 0), (42, 0)],
        "hips": [(0, 0), (4, -4), (8, 20), (10, 24), (14, 6), (17, 4), (26, 4), (42, 0)],
        "chest": [(0, 0), (4, -6), (8, 16), (10, 20), (14, -3), (17, -7), (26, -5), (42, 0)],
        "head": [(0, 0), (4, 4), (8, -10), (10, -16), (14, -6), (17, -9), (26, -7), (42, 0)],
        "clav_r": [(0, (0, 0)), (4, (-4, 4)), (8, (10, 10)), (10, (10, 12)), (14, (8, -12)), (17, (8, -18)), (26, (6, -14)),
                   (42, (0, 0))],
        "clav_l": [(0, (0, 0)), (4, (-4, 4)), (8, (10, 10)), (10, (10, 12)), (14, (8, -12)), (17, (8, -18)), (26, (6, -14)),
                   (42, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.2, 1.04, 0.06)), (8, (-0.24, 0.6, 0.38)), (10, (-0.24, 0.56, 0.42)), (12, (-0.3, 0.88, 0.58)),
                   (14, (-0.355, 1.31, 0.63)), (17, (-0.36, 1.42, 0.555)), (26, (-0.345, 1.39, 0.535)), (34, (-0.22, 1.0, 0.22)), (42, HR)],
        "hand_l": [(0, HL), (4, (0.2, 1.04, 0.06)), (8, (0.24, 0.6, 0.38)), (10, (0.24, 0.56, 0.42)), (12, (0.3, 0.88, 0.58)),
                   (14, (0.355, 1.31, 0.63)), (17, (0.36, 1.42, 0.555)), (26, (0.345, 1.39, 0.535)), (34, (0.22, 1.0, 0.22)), (42, HL)],
        "face_r": [(0, "stand"), (4, "chamber"), (7, "press_down"), (11, "press_down"), (14, "lift_out"), (28, "lift_out"),
                   (42, "stand")],
        "face_l": [(0, "stand"), (4, "chamber"), (7, "press_down"), (11, "press_down"), (14, "lift_out"), (28, "lift_out"),
                   (42, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (8, (-1.0, 0.3, -0.2)), (14, (-0.8, -0.6, 0.0)), (42, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (8, (1.0, 0.3, -0.2)), (14, (0.8, -0.6, 0.0)), (42, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.0), (7, -0.4), (11, -0.2), (14, -0.5), (30, -0.5), (42, 0.4)],
        "grip_l": [(0, 0.4), (4, 0.0), (7, -0.4), (11, -0.2), (14, -0.5), (30, -0.5), (42, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.2, 0.06)), (5, (0.15, 0.3, 0.16)), (8, (0.17, 0.077, 0.38)), (30, (0.17, 0.077, 0.38)),
                   (34, (0.15, 0.14, 0.16)), (38, FL), (42, FL)],
        "heel_l": [(0, 0), (3, 12), (5, -8), (7, -3), (8, 0), (30, 0), (33, 10), (37, 0), (42, 0)],
        "fyaw_l": [(0, 7), (8, 6), (30, 6), (38, 7)],
        "knee_l": [(0, "auto"), (2, (0.15, 0.3, 1.0)), (34, (0.15, 0.3, 1.0)), (38, "auto")],
        "foot_r": [(0, FR), (8, (-0.15, 0.077, -0.1)), (30, (-0.15, 0.077, -0.1)), (38, FR)],
        "fyaw_r": [(0, 7), (8, 30), (30, 30), (38, 7)],
        "heel_r": [(0, 0), (10, 0), (14, 10), (26, 8), (34, 0), (42, 0)],
        "knee_r": [(0, "auto"), (8, (-0.4, 0.0, 1.0)), (30, (-0.4, 0.0, 1.0)), (36, "auto")],
    },
    # the Turn (water's guard): turned hard to the right, both hands low out by the right hip with the palms out to meet the
    # shot (held: the window); the arms swing it round the body in a wide circle, across the front at the waist and up round to
    # the left, the body winding with them; then both hands fling it out ahead from the chest (sent back along the aim).
    # strike_s: the fling
    "water_turn": {
        "length": 36,
        "meta": {"hold_s": 5 / FPS, "strike_s": 14 / FPS, "back_s": 24 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (-0.03, -0.13, 0.0)), (9, (0.02, -0.15, 0.02)), (12, (0.05, -0.14, 0.0)),
                 (14, (0.0, -0.13, 0.14)), (18, (0.0, -0.135, 0.15)), (24, (0.0, -0.125, 0.13)), (30, (0.0, -0.04, 0.03)),
                 (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -34), (9, 0), (12, 40), (14, 2), (18, -4), (24, -3), (36, 0)],
        "twist": [(0, 0), (5, -18), (9, 6), (12, 26), (14, -4), (18, -4), (36, 0)],
        "hips": [(0, 0), (5, 10), (9, 8), (12, 4), (14, 8), (18, 9), (24, 7), (36, 0)],
        "chest": [(0, 0), (5, 6), (9, 4), (12, 0), (14, 10), (18, 12), (24, 9), (36, 0)],
        "side": [(0, 0), (5, -6), (9, 2), (12, 8), (14, 0), (36, 0)],
        "head": [(0, 0), (5, 2), (14, -2), (36, 0)],
        "clav_r": [(0, (0, 0)), (5, (8, 4)), (9, (10, 0)), (12, (8, -8)), (14, (14, -6)), (24, (12, -5)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, 4)), (9, (6, 0)), (12, (-4, -8)), (14, (14, -6)), (24, (12, -5)), (36, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.26, 0.98, 0.18)), (5, (-0.36, 0.94, 0.12)), (9, (-0.12, 0.98, 0.48)), (12, (0.14, 1.18, 0.26)),
                   (14, (-0.14, 1.24, 0.66)), (18, (-0.16, 1.22, 0.63)), (24, (-0.16, 1.18, 0.58)), (30, (-0.2, 0.98, 0.22)), (36, HR)],
        "hand_l": [(0, HL), (3, (0.0, 0.98, 0.3)), (5, (-0.1, 0.94, 0.32)), (9, (0.24, 0.98, 0.4)), (12, (0.38, 1.24, 0.02)),
                   (14, (0.14, 1.24, 0.66)), (18, (0.16, 1.22, 0.63)), (24, (0.16, 1.18, 0.58)), (30, (0.2, 0.98, 0.22)), (36, HL)],
        "face_r": [(0, "stand"), (3, "push"), (6, "push"), (9, "float"), (12, "palm_down"), (14, "push"), (26, "push"),
                   (36, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (6, "push"), (9, "float"), (12, "palm_down"), (14, "push"), (26, "push"),
                   (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.8, -0.7, -0.3)), (12, (-0.6, -0.8, 0.2)), (14, (-0.8, -0.6, -0.1)),
                   (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.8, -0.7, -0.3)), (12, (0.9, -0.6, -0.3)), (14, (0.8, -0.6, -0.1)),
                   (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.3), (28, -0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (28, -0.3), (36, 0.4)],
        "foot_l": [(0, FL), (2, (0.14, 0.12, 0.04)), (4, (0.16, 0.077, 0.2)), (30, (0.16, 0.077, 0.2)), (33, (0.14, 0.12, 0.08)),
                   (35, FL), (36, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 0), (9, 0), (12, 10), (14, 0), (30, 0), (32, 8), (35, 0)],
        "fyaw_l": [(0, 7), (5, -12), (12, 26), (14, 6), (30, 6), (35, 7)],
        "knee_l": [(0, "auto"), (2, (0.25, 0.0, 1.0)), (32, (0.25, 0.0, 1.0)), (35, "auto")],
        "foot_r": [(0, FR), (4, (-0.17, 0.077, -0.11)), (30, (-0.17, 0.077, -0.11)), (35, FR)],
        "fyaw_r": [(0, 7), (4, 30), (5, 34), (12, 50), (14, 30), (30, 30), (35, 7)],
        "heel_r": [(0, 0), (5, 0), (9, 6), (12, 18), (14, 8), (26, 6), (32, 0)],
        "knee_r": [(0, "auto"), (4, (-0.45, 0.0, 1.0)), (30, (-0.45, 0.0, 1.0)), (34, "auto")],
    },
    # the Turn's hold (a loop while the guard stands): the short tai chi bow stance, both hands rolling a ball of water round a
    # level circle before the waist, the body turning a little with it
    "water_turn_hold": {
        "length": 48, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": _ring(EIGHTHS(48), lambda a: _r3((0.01 * math.sin(a), -0.1, 0.01 * math.cos(a)))),
        "yaw": _ring(EIGHTHS(48), lambda a: round(-10 + 8 * math.sin(a), 3)),
        "twist": _ring(EIGHTHS(48), lambda a: round(-4 + 6 * math.sin(a), 3)),
        "hips": [(0, 3), (48, 3)], "chest": [(0, 2), (48, 2)], "head": [(0, 1), (48, 1)],
        "clav_r": [(0, (4, 0)), (48, (4, 0))], "clav_l": [(0, (4, 0)), (48, (4, 0))],
        "hand_r": _ring(EIGHTHS(48), lambda a: _r3((-0.13 + 0.12 * math.sin(a), 1.0 + 0.03 * math.cos(a), 0.34 + 0.1 * math.cos(a)))),
        "hand_l": _ring(EIGHTHS(48), lambda a: _r3((0.13 + 0.12 * math.sin(a), 1.0 + 0.03 * math.cos(a), 0.34 + 0.1 * math.cos(a)))),
        "face_r": [(0, "float"), (48, "float")], "face_l": [(0, "float"), (48, "float")],
        "pole_r": [(0, (-0.8, -0.7, -0.3)), (48, (-0.8, -0.7, -0.3))], "pole_l": [(0, (0.8, -0.7, -0.3)), (48, (0.8, -0.7, -0.3))],
        "grip_r": [(0, -0.15), (48, -0.15)], "grip_l": [(0, -0.15), (48, -0.15)],
        "foot_l": [(0, (0.14, 0.077, 0.15)), (48, (0.14, 0.077, 0.15))],
        "foot_r": [(0, (-0.15, 0.077, -0.12)), (48, (-0.15, 0.077, -0.12))],
        "fyaw_l": [(0, 4), (48, 4)], "fyaw_r": [(0, 30), (48, 30)],
        "knee_l": [(0, (0.25, 0.0, 1.0)), (48, (0.25, 0.0, 1.0))], "knee_r": [(0, (-0.45, 0.0, 1.0)), (48, (-0.45, 0.0, 1.0))],
    },
    # ---------------------------------------------------------------- air
    # the Pull: a step in and both palms out ahead at the shoulders' height, open (held: the wind caught); the fingers close on
    # it and the hands are dragged back to the hips as the right foot steps back and the body leans away.  strike_s: the hands
    # at the hips
    "air_pull": {
        "length": 34,
        "meta": {"hold_s": 6 / FPS, "strike_s": 11 / FPS, "back_s": 22 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.06, 0.08)), (8, (0.0, -0.07, 0.04)), (11, (0.0, -0.12, -0.13)),
                 (14, (0.0, -0.13, -0.15)), (22, (0.0, -0.12, -0.14)), (28, (0.0, -0.05, -0.03)), (34, (0, -0.015, 0))],
        "hips": [(0, 0), (6, 8), (8, 6), (11, -4), (14, -6), (22, -5), (34, 0)],
        "chest": [(0, 0), (6, 10), (8, 6), (11, -6), (14, -8), (22, -6), (34, 0)],
        "head": [(0, 0), (6, -4), (11, 4), (14, 5), (22, 4), (34, 0)],
        "clav_r": [(0, (0, 0)), (6, (16, -6)), (11, (-10, 2)), (14, (-12, 2)), (22, (-10, 2)), (34, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (16, -6)), (11, (-10, 2)), (14, (-12, 2)), (22, (-10, 2)), (34, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.2, 1.15, 0.3)), (6, (-0.2, 1.3, 0.6)), (8, (-0.21, 1.24, 0.48)), (11, (-0.24, 0.98, -0.02)),
                   (14, (-0.25, 0.96, -0.06)), (22, (-0.25, 0.96, -0.05)), (28, (-0.21, 0.88, 0.04)), (34, HR)],
        "hand_l": [(0, HL), (3, (0.2, 1.15, 0.3)), (6, (0.2, 1.3, 0.6)), (8, (0.21, 1.24, 0.48)), (11, (0.24, 0.98, -0.02)),
                   (14, (0.25, 0.96, -0.06)), (22, (0.25, 0.96, -0.05)), (28, (0.21, 0.88, 0.04)), (34, HL)],
        "face_r": [(0, "stand"), (3, "push"), (7, "push"), (9, "claw"), (11, "chamber"), (24, "chamber"), (34, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (7, "push"), (9, "claw"), (11, "chamber"), (24, "chamber"), (34, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.8, -0.6, -0.1)), (11, (-0.5, -0.2, -1.0)), (34, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.8, -0.6, -0.1)), (11, (0.5, -0.2, -1.0)), (34, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.4), (7, -0.4), (9, 0.7), (11, 0.85), (24, 0.85), (34, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.4), (7, -0.4), (9, 0.7), (11, 0.85), (24, 0.85), (34, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.12, 0.04)), (5, (0.15, 0.077, 0.16)), (26, (0.15, 0.077, 0.16)), (30, (0.14, 0.11, 0.06)),
                   (33, FL), (34, FL)],
        "heel_l": [(0, 0), (3, 8), (4, -4), (5, 0), (11, 0), (13, -8), (22, -6), (26, 0), (29, 8), (32, 0)],
        "knee_l": [(0, "auto"), (3, (0.25, 0.2, 1.0)), (30, (0.25, 0.2, 1.0)), (33, "auto")],
        "foot_r": [(0, FR), (7, FR), (9, (-0.15, 0.13, -0.14)), (11, (-0.16, 0.077, -0.32)), (26, (-0.16, 0.077, -0.32)),
                   (30, (-0.14, 0.12, -0.15)), (33, FR), (34, FR)],
        "heel_r": [(0, 0), (7, 0), (9, 15), (11, 0), (26, 0), (29, 10), (32, 0)],
        "fyaw_r": [(0, 7), (11, 30), (26, 30), (33, 7)],
        "knee_r": [(0, "auto"), (8, (-0.4, 0.0, 1.0)), (30, (-0.4, 0.0, 1.0)), (33, "auto")],
    },
    # the Slip (the dodge, a circle walker's pivot step; the game carries the body): sunk and gathered (held); a long step out
    # to the right with the toes turned out, the body lunging low after it and leaning into the circle, the right palm thrown
    # out wide at the shoulder's height turned in to the circle's centre and the left by the right elbow; the left foot hooks
    # in after it, toes in.  strike_s: the step set down (its twin to the left)
    "air_slip": {
        "length": 26, "mirror": True,
        "meta": {"hold_s": 3 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "r", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, (0, -0.015, 0)), (3, (0.05, -0.1, 0.0)), (6, (-0.1, -0.17, 0.02)), (8, (-0.2, -0.2, 0.03)),
                 (11, (-0.19, -0.19, 0.02)), (16, (-0.17, -0.17, 0.02)), (22, (-0.03, -0.04, 0.0)), (26, (0, -0.015, 0))],
        "yaw": [(0, 0), (3, 8), (8, -26), (11, -30), (16, -26), (26, 0)],
        "twist": [(0, 0), (3, 6), (8, -10), (16, -8), (26, 0)],
        "side": [(0, 0), (3, 4), (8, -12), (11, -12), (16, -10), (26, 0)],
        "roll": [(0, 0), (3, 3), (8, -4), (16, -3), (26, 0)],
        "hips": [(0, 0), (3, 8), (8, 6), (16, 5), (26, 0)],
        "chest": [(0, 0), (3, 4), (8, 2), (26, 0)],
        "clav_r": [(0, (0, 0)), (8, (2, -12)), (16, (2, -10)), (26, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (14, -4)), (16, (12, -3)), (26, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.12, 1.08, 0.26)), (6, (-0.42, 1.18, 0.24)), (8, (-0.64, 1.18, 0.18)), (16, (-0.63, 1.17, 0.17)),
                   (22, (-0.3, 0.98, 0.14)), (26, HR)],
        "hand_l": [(0, HL), (3, (0.1, 1.06, 0.28)), (8, (-0.26, 1.04, 0.22)), (16, (-0.25, 1.03, 0.21)), (22, (0.1, 0.94, 0.14)),
                   (26, HL)],
        "face_r": [(0, "stand"), (3, "push"), (6, "bagua"), (19, "bagua"), (26, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (19, "push"), (26, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.4, -1.0, -0.2)), (19, (-0.4, -1.0, -0.2)), (26, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, -1.0, -0.2)), (19, (0.6, -1.0, -0.2)), (26, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.3), (20, -0.3), (26, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (20, -0.3), (26, 0.4)],
        "foot_r": [(0, FR), (3, FR), (5, (-0.28, 0.13, 0.06)), (7, (-0.52, 0.077, 0.06)), (18, (-0.52, 0.077, 0.06)),
                   (21, (-0.32, 0.12, 0.02)), (24, FR), (26, FR)],
        "fyaw_r": [(0, 7), (5, 30), (7, 50), (18, 50), (24, 7)],
        "heel_r": [(0, 0), (4, 12), (6, -6), (7, 0), (18, 0), (20, 10), (23, 0)],
        "knee_r": [(0, "auto"), (4, (-0.6, 0.1, 1.0)), (20, (-0.6, 0.1, 1.0)), (24, "auto")],
        "foot_l": [(0, FL), (8, FL), (10, (0.04, 0.11, 0.03)), (12, (-0.1, 0.077, 0.05)), (17, (-0.1, 0.077, 0.05)),
                   (20, (0.03, 0.11, 0.0)), (23, FL), (26, FL)],
        "fyaw_l": [(0, 7), (8, 4), (10, -10), (12, -30), (17, -30), (23, 7)],
        "heel_l": [(0, 0), (6, 6), (8, 14), (11, -4), (12, 0), (17, 0), (19, 10), (22, 0)],
        "knee_l": [(0, "auto"), (6, (0.1, 0.0, 1.0)), (20, (0.0, 0.1, 1.0)), (23, "auto")],
    },
    # the Slip back: sunk (held), the right foot steps back and out round behind with its toes turned out, the body turning
    # side-on after it, the left palm leading out ahead and the right by the chest; the left foot turned in on its ball
    "air_slip_back": {
        "length": 26,
        "meta": {"hold_s": 3 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "l", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, -0.08, 0.02)), (6, (-0.02, -0.1, -0.06)), (8, (-0.03, -0.12, -0.14)),
                 (11, (-0.03, -0.115, -0.13)), (16, (-0.03, -0.11, -0.12)), (22, (0.0, -0.04, -0.02)), (26, (0, -0.015, 0))],
        "yaw": [(0, 0), (3, 4), (8, -30), (11, -32), (16, -28), (26, 0)],
        "twist": [(0, 0), (8, -8), (16, -6), (26, 0)],
        "hips": [(0, 0), (3, 6), (8, 2), (16, 2), (26, 0)],
        "chest": [(0, 0), (3, 4), (8, -2), (16, -1), (26, 0)],
        "clav_r": [(0, (0, 0)), (8, (6, -4)), (16, (5, -3)), (26, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (14, -8)), (16, (12, -6)), (26, (0, 0))],
        "hand_l": [(0, HL), (3, (0.12, 1.15, 0.3)), (8, (0.135, 1.3, 0.39)), (16, (0.135, 1.295, 0.385)), (22, (0.18, 1.0, 0.15)),
                   (26, HL)],
        "hand_r": [(0, HR), (3, (-0.12, 1.1, 0.25)), (8, (-0.06, 1.13, 0.21)), (16, (-0.06, 1.12, 0.21)), (22, (-0.18, 0.95, 0.15)),
                   (26, HR)],
        "face_r": [(0, "stand"), (3, "push"), (19, "push"), (26, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (19, "push"), (26, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.6, -1.0, -0.2)), (19, (-0.6, -1.0, -0.2)), (26, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.7, -0.8, 0.0)), (19, (0.7, -0.8, 0.0)), (26, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.3), (20, -0.3), (26, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (20, -0.3), (26, 0.4)],
        "foot_r": [(0, FR), (3, FR), (5, (-0.18, 0.13, -0.14)), (7, (-0.25, 0.077, -0.34)), (18, (-0.25, 0.077, -0.34)),
                   (21, (-0.18, 0.12, -0.15)), (24, FR), (26, FR)],
        "fyaw_r": [(0, 7), (5, 30), (7, 50), (18, 50), (24, 7)],
        "heel_r": [(0, 0), (4, 12), (6, 8), (7, 0), (18, 0), (20, 10), (23, 0)],
        "knee_r": [(0, "auto"), (4, (-0.5, 0.0, 1.0)), (20, (-0.5, 0.0, 1.0)), (24, "auto")],
        "foot_l": [(0, FL), (26, FL)],
        "fyaw_l": [(0, 7), (8, -12), (18, -12), (24, 7)],
        "heel_l": [(0, 0), (6, 0), (8, 10), (18, 8), (23, 0)],
    },
    # the Wind Wall: a step in, both palms drawn in before the chest turned out (held); driven out flat together ahead, then
    # swept apart wide to the sides (the wall spread across the line); held.  strike_s: the palms out
    "air_wall": {
        "length": 38,
        "meta": {"hold_s": 7 / FPS, "strike_s": 11 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.07, -0.02)), (7, (0.0, -0.08, -0.03)), (11, (0.0, -0.13, 0.12)),
                 (15, (0.0, -0.14, 0.13)), (18, (0.0, -0.145, 0.13)), (26, (0.0, -0.13, 0.12)), (32, (0.0, -0.04, 0.02)),
                 (38, (0, -0.015, 0))],
        "hips": [(0, 0), (7, -2), (11, 6), (18, 6), (26, 5), (38, 0)],
        "chest": [(0, 0), (7, -4), (11, 8), (15, 6), (18, 5), (26, 4), (38, 0)],
        "head": [(0, 0), (7, -2), (11, -2), (38, 0)],
        "clav_r": [(0, (0, 0)), (7, (-6, -4)), (11, (16, -4)), (15, (6, -6)), (18, (0, -6)), (26, (0, -5)), (38, (0, 0))],
        "clav_l": [(0, (0, 0)), (7, (-6, -4)), (11, (16, -4)), (15, (6, -6)), (18, (0, -6)), (26, (0, -5)), (38, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.15, 1.2, 0.12)), (7, (-0.1, 1.28, 0.12)), (11, (-0.07, 1.31, 0.62)), (15, (-0.36, 1.3, 0.46)),
                   (18, (-0.48, 1.28, 0.32)), (26, (-0.47, 1.26, 0.3)), (32, (-0.25, 0.95, 0.15)), (38, HR)],
        "hand_l": [(0, HL), (4, (0.15, 1.2, 0.12)), (7, (0.1, 1.28, 0.12)), (11, (0.07, 1.31, 0.62)), (15, (0.36, 1.3, 0.46)),
                   (18, (0.48, 1.28, 0.32)), (26, (0.47, 1.26, 0.3)), (32, (0.25, 0.95, 0.15)), (38, HL)],
        "face_r": [(0, "stand"), (4, "push"), (12, "push"), (16, "sweep_out"), (28, "sweep_out"), (38, "stand")],
        "face_l": [(0, "stand"), (4, "push"), (12, "push"), (16, "sweep_out"), (28, "sweep_out"), (38, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (7, (-0.8, -0.8, -0.3)), (11, (-0.8, -0.6, -0.1)), (18, (-0.3, -1.0, -0.2)),
                   (38, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (7, (0.8, -0.8, -0.3)), (11, (0.8, -0.6, -0.1)), (18, (0.3, -1.0, -0.2)),
                   (38, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.5), (30, -0.5), (38, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.5), (30, -0.5), (38, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.12, 0.04)), (6, (0.15, 0.077, 0.22)), (28, (0.15, 0.077, 0.22)), (31, (0.14, 0.12, 0.08)),
                   (35, FL), (38, FL)],
        "heel_l": [(0, 0), (3, 8), (5, -4), (6, 0), (28, 0), (30, 8), (34, 0)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.2, 1.0)), (32, (0.2, 0.2, 1.0)), (35, "auto")],
        "foot_r": [(0, FR), (6, (-0.15, 0.077, -0.08)), (28, (-0.15, 0.077, -0.08)), (35, FR)],
        "fyaw_r": [(0, 7), (6, 30), (28, 30), (35, 7)],
        "heel_r": [(0, 0), (8, 0), (11, 12), (26, 10), (34, 0)],
    },
    # the Wind Guard (air's guard): the arms drawn round into a circle before the body, the right palm high by the brow and
    # the left low by the belly, both turned out (held: the window); the palms roll round the circle, the high one down and
    # the low one up, meet before the chest and bounce out ahead together (the shot sent back), light on the feet
    "air_guard": {
        "length": 32,
        "meta": {"hold_s": 5 / FPS, "strike_s": 10 / FPS, "back_s": 18 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, -0.05, 0.0)), (5, (0.0, -0.07, -0.03)), (8, (0.0, -0.09, 0.0)),
                 (10, (0.0, -0.1, 0.1)), (14, (0.0, -0.1, 0.11)), (18, (0.0, -0.095, 0.1)), (25, (0.0, -0.04, 0.02)),
                 (32, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -12), (8, -4), (10, 4), (18, 3), (32, 0)],
        "hips": [(0, 0), (5, -2), (8, 2), (10, 6), (18, 5), (32, 0)],
        "chest": [(0, 0), (5, -4), (8, 2), (10, 8), (14, 9), (18, 7), (32, 0)],
        "side": [(0, 0), (5, 3), (8, -2), (10, 0), (32, 0)],
        "head": [(0, 0), (5, -2), (10, -2), (32, 0)],
        "clav_r": [(0, (0, 0)), (5, (4, -16)), (8, (4, -2)), (10, (14, -2)), (18, (12, -2)), (32, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, 4)), (8, (4, -6)), (10, (14, -2)), (18, (12, -2)), (32, (0, 0))],
        "hand_r": [(0, HR), (2, (-0.15, 1.2, 0.28)), (5, (-0.17, 1.46, 0.29)), (7, (-0.33, 1.26, 0.34)), (8, (-0.15, 1.12, 0.3)),
                   (10, (-0.1, 1.28, 0.6)), (14, (-0.1, 1.27, 0.6)), (18, (-0.11, 1.26, 0.57)), (25, (-0.2, 1.0, 0.2)), (32, HR)],
        "hand_l": [(0, HL), (2, (0.15, 1.0, 0.26)), (5, (0.12, 0.96, 0.36)), (7, (0.32, 1.22, 0.34)), (8, (0.15, 1.2, 0.3)),
                   (10, (0.1, 1.28, 0.6)), (14, (0.1, 1.27, 0.6)), (18, (0.11, 1.26, 0.57)), (25, (0.2, 1.0, 0.2)), (32, HL)],
        "face_r": [(0, "stand"), (2, "push"), (22, "push"), (32, "stand")],
        "face_l": [(0, "stand"), (2, "float"), (5, "float"), (7, "push"), (22, "push"), (32, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-1.0, -0.2, -0.2)), (8, (-0.8, -0.8, -0.2)), (10, (-0.8, -0.6, -0.1)),
                   (32, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (1.0, -0.6, 0.0)), (8, (0.8, -0.8, -0.2)), (10, (0.8, -0.6, -0.1)),
                   (32, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (2, -0.4), (24, -0.4), (32, 0.4)],
        "grip_l": [(0, 0.4), (2, -0.4), (24, -0.4), (32, 0.4)],
        "foot_l": [(0, FL), (3, (0.13, 0.11, 0.05)), (5, (0.13, 0.077, 0.15)), (24, (0.13, 0.077, 0.15)), (27, (0.13, 0.11, 0.06)),
                   (30, FL), (32, FL)],
        "heel_l": [(0, 0), (3, 8), (4, -2), (5, 4), (24, 4), (26, 8), (29, 0)],
        "foot_r": [(0, FR), (5, (-0.14, 0.077, -0.08)), (27, (-0.14, 0.077, -0.08)), (31, FR)],
        "fyaw_r": [(0, 7), (5, 20), (27, 20), (31, 7)],
        "heel_r": [(0, 0), (5, 8), (10, 14), (18, 12), (26, 0)],
    },
    # the Wind Guard's hold (a loop while the guard stands, the spec's air-shield hold): the circle walker standing light, both
    # palms turning round a circle each before the chest (the right one way, the left the other)
    "air_shield_hold": {
        "length": 40, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": _ring(EIGHTHS(40), lambda a: _r3((0.0, -0.045 + 0.008 * math.sin(a), 0.0))),
        "yaw": [(0, 0), (40, 0)], "hips": [(0, 2), (40, 2)], "chest": [(0, 1), (40, 1)],
        "clav_r": [(0, (4, -4)), (40, (4, -4))], "clav_l": [(0, (4, -4)), (40, (4, -4))],
        "hand_r": _ring(EIGHTHS(40), lambda a: _r3((-0.17 + 0.09 * math.cos(a), 1.24 + 0.09 * math.sin(a), 0.34 + 0.02 * math.sin(a)))),
        "hand_l": _ring(EIGHTHS(40), lambda a: _r3((0.17 - 0.09 * math.cos(a), 1.24 + 0.09 * math.sin(a), 0.34 + 0.02 * math.sin(a)))),
        "face_r": [(0, "push"), (40, "push")], "face_l": [(0, "push"), (40, "push")],
        "pole_r": [(0, (-0.7, -0.8, 0.0)), (40, (-0.7, -0.8, 0.0))], "pole_l": [(0, (0.7, -0.8, 0.0)), (40, (0.7, -0.8, 0.0))],
        "grip_r": [(0, -0.35), (40, -0.35)], "grip_l": [(0, -0.35), (40, -0.35)],
        "foot_l": [(0, (0.12, 0.077, 0.08)), (40, (0.12, 0.077, 0.08))],
        "foot_r": [(0, (-0.14, 0.077, -0.06)), (40, (-0.14, 0.077, -0.06))],
        "fyaw_l": [(0, 2), (40, 2)], "fyaw_r": [(0, 14), (40, 14)],
        "heel_l": [(0, 6), (40, 6)], "heel_r": [(0, 8), (40, 8)],
    },
    # the Slice: light on the feet, the right hand cocked back by the ear with the palm down (held); it slices out flat ahead
    # and across at the chest's height, the edge of the hand leading, the left palm by the right elbow.  strike_s: the hand
    # out ahead (its twin to the left)
    "air_slice": {
        "length": 28, "mirror": True,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, -0.05, -0.01)), (5, (0.0, -0.06, -0.03)), (8, (0.0, -0.08, 0.1)),
                 (11, (0.0, -0.085, 0.12)), (16, (0.0, -0.08, 0.1)), (23, (0.0, -0.03, 0.02)), (28, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -24), (8, 10), (11, 18), (16, 15), (28, 0)],
        "twist": [(0, 0), (5, -16), (8, 8), (11, 14), (16, 12), (28, 0)],
        "hips": [(0, 0), (5, 2), (8, 6), (16, 5), (28, 0)],
        "chest": [(0, 0), (5, 2), (8, 7), (16, 6), (28, 0)],
        "side": [(0, 0), (5, 5), (8, -3), (16, -2), (28, 0)],
        "head": [(0, 0), (5, -2), (8, -3), (28, 0)],
        "clav_r": [(0, (0, 0)), (5, (-6, -12)), (8, (14, -4)), (11, (16, -3)), (16, (12, -3)), (28, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, -2)), (8, (10, -2)), (16, (8, -2)), (28, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.25, 1.25, 0.05)), (5, (-0.3, 1.44, -0.02)), (7, (-0.15, 1.36, 0.42)), (8, (0.04, 1.29, 0.66)),
                   (11, (0.17, 1.25, 0.54)), (16, (0.16, 1.23, 0.48)), (23, (-0.15, 0.98, 0.18)), (28, HR)],
        "hand_l": [(0, HL), (3, (0.12, 1.12, 0.3)), (5, (0.1, 1.2, 0.36)), (8, (0.04, 1.12, 0.3)), (16, (0.05, 1.12, 0.3)),
                   (23, (0.18, 0.95, 0.12)), (28, HL)],
        "face_r": [(0, "stand"), (3, "slice_back"), (6, "slice_back"), (8, "slice"), (18, "slice"), (28, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (18, "push"), (28, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-1.0, 0.0, -0.4)), (8, (-0.6, -0.6, 0.0)), (28, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.6, -1.0, -0.2)), (28, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.5), (22, -0.5), (28, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (22, -0.3), (28, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.14, 0.077, 0.18)), (19, (0.14, 0.077, 0.18)), (22, (0.13, 0.12, 0.07)),
                   (25, FL), (28, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 4), (19, 4), (21, 8), (24, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (22, (0.2, 0.2, 1.0)), (25, "auto")],
        "foot_r": [(0, FR), (4, (-0.14, 0.077, -0.08)), (20, (-0.14, 0.077, -0.08)), (25, FR)],
        "fyaw_r": [(0, 7), (4, 30), (8, 36), (20, 36), (25, 7)],
        "heel_r": [(0, 0), (4, 10), (8, 22), (16, 18), (24, 0)],
    },
    # ---------------------------------------------------------------- water (the ride and the glide; the game carries the body)
    # the Surf (a loop while riding the wave, legs_always): side-on and crouched low on a wide staggered stance, the left arm
    # out ahead and the right back for the balance, the body riding the wave's bob
    "water_surf": {
        "length": 48, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place", "legs_always": 1.0},
        "root": [(0, (0.0, -0.24, 0.0)), (12, (0.01, -0.265, 0.01)), (24, (0.0, -0.245, 0.0)), (36, (-0.01, -0.265, -0.01)),
                 (48, (0.0, -0.24, 0.0))],
        "yaw": [(0, -32), (24, -28), (48, -32)],
        "twist": [(0, 6), (24, 3), (48, 6)],
        "hips": [(0, 14), (12, 17), (24, 14), (36, 17), (48, 14)],
        "chest": [(0, 6), (12, 4), (24, 6), (36, 4), (48, 6)],
        "roll": [(0, 0), (12, 2), (24, 0), (36, -2), (48, 0)],
        "head": [(0, -10), (12, -12), (24, -10), (36, -12), (48, -10)],
        "clav_r": [(0, (-4, -6)), (48, (-4, -6))], "clav_l": [(0, (8, -6)), (48, (8, -6))],
        "hand_l": [(0, (0.24, 1.02, 0.42)), (12, (0.25, 0.97, 0.43)), (24, (0.24, 1.02, 0.42)), (36, (0.23, 1.05, 0.41)),
                   (48, (0.24, 1.02, 0.42))],
        "hand_r": [(0, (-0.38, 0.92, -0.08)), (12, (-0.38, 0.97, -0.08)), (24, (-0.38, 0.92, -0.08)), (36, (-0.37, 0.88, -0.08)),
                   (48, (-0.38, 0.92, -0.08))],
        "face_r": [(0, "arms_out"), (48, "arms_out")], "face_l": [(0, "palm_down"), (48, "palm_down")],
        "pole_r": [(0, (-0.5, -1.0, -0.4)), (48, (-0.5, -1.0, -0.4))], "pole_l": [(0, (0.5, -1.0, -0.2)), (48, (0.5, -1.0, -0.2))],
        "grip_r": [(0, -0.3), (48, -0.3)], "grip_l": [(0, -0.3), (48, -0.3)],
        "foot_l": [(0, (0.16, 0.077, 0.22)), (48, (0.16, 0.077, 0.22))],
        "foot_r": [(0, (-0.18, 0.077, -0.2)), (48, (-0.18, 0.077, -0.2))],
        "fyaw_l": [(0, -6), (48, -6)], "fyaw_r": [(0, 50), (48, 50)],
        "knee_l": [(0, (0.35, 0.0, 1.0)), (48, (0.35, 0.0, 1.0))], "knee_r": [(0, (-0.6, 0.0, 1.0)), (48, (-0.6, 0.0, 1.0))],
    },
    # the Skate (a skater's push-off on the water's ice; legs_always): crouched and gathered (held); the right leg drives out
    # to the side and back off the deck, the body low and leaning ahead over the bent left leg, the left arm swinging out ahead
    # and the right back (the glide, held); gathered in again.  strike_s: the push out
    "water_skate": {
        "length": 30,
        "meta": {"hold_s": 5 / FPS, "strike_s": 9 / FPS, "back_s": 20 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.16, 0.02)), (9, (0.06, -0.2, 0.06)), (16, (0.06, -0.2, 0.06)),
                 (20, (0.05, -0.18, 0.05)), (25, (0.01, -0.05, 0.01)), (30, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, 4), (9, -10), (16, -10), (20, -8), (30, 0)],
        "hips": [(0, 0), (5, 14), (9, 22), (16, 21), (20, 18), (30, 0)],
        "chest": [(0, 0), (5, 8), (9, 10), (16, 10), (20, 8), (30, 0)],
        "side": [(0, 0), (9, 4), (16, 4), (30, 0)],
        "head": [(0, 0), (5, -10), (9, -14), (16, -13), (20, -11), (30, 0)],
        "clav_r": [(0, (0, 0)), (5, (6, 4)), (9, (-10, 4)), (16, (-10, 4)), (30, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (6, 4)), (9, (16, -4)), (16, (16, -4)), (30, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.2, 0.92, 0.26)), (9, (-0.28, 0.86, -0.12)), (16, (-0.28, 0.86, -0.11)), (20, (-0.24, 0.88, 0.0)),
                   (25, (-0.2, 0.84, 0.08)), (30, HR)],
        "hand_l": [(0, HL), (5, (0.15, 0.92, 0.26)), (9, (0.03, 1.11, 0.66)), (16, (0.03, 1.1, 0.65)), (20, (0.1, 1.0, 0.4)),
                   (25, (0.19, 0.86, 0.12)), (30, HL)],
        "face_r": [(0, "stand"), (5, "palm_down"), (9, "arms_out"), (20, "arms_out"), (30, "stand")],
        "face_l": [(0, "stand"), (5, "palm_down"), (20, "palm_down"), (30, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.8, -0.6, -0.2)), (9, (-0.6, -1.0, 0.0)), (30, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.8, -0.6, -0.2)), (9, (0.6, -0.8, 0.0)), (30, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.3), (24, -0.3), (30, 0.4)],
        "grip_l": [(0, 0.4), (5, -0.3), (24, -0.3), (30, 0.4)],
        "foot_r": [(0, FR), (5, (-0.14, 0.077, -0.04)), (7, (-0.24, 0.095, -0.12)), (9, (-0.42, 0.1, -0.22)),
                   (16, (-0.41, 0.1, -0.21)), (20, (-0.26, 0.13, -0.1)), (24, FR), (30, FR)],
        "fyaw_r": [(0, 7), (5, 20), (9, 45), (16, 45), (24, 7)],
        "heel_r": [(0, 0), (5, 6), (9, -4), (16, -4), (20, 6), (23, 0)],
        "knee_r": [(0, "auto"), (5, (-0.6, 0.0, 1.0)), (20, (-0.6, 0.0, 1.0)), (24, "auto")],
        "foot_l": [(0, FL), (30, FL)],
        "fyaw_l": [(0, 7), (5, 10), (9, 16), (20, 16), (26, 7)],
        "knee_l": [(0, "auto"), (4, (0.3, 0.0, 1.0)), (24, (0.3, 0.0, 1.0)), (27, "auto")],
    },
}
CLIPS.update(SET3)

## ---------------------------------------------------------------- the fourth set (round 3, P1's air and hit states: the %
## ring's tumble, flinch, double jump, fall, fast fall, helpless fall, air dodge, air legs and the two landings; authored the
## same way, key poses typed here, nothing read). The airborne clips start and end on AIR (the plain fall's own first frame),
## so they hand over to each other and to the fall loop without a jump; the landings start on the deck from it and end on
## the STAND. A loop's channels are written as functions of its phase (a radian round the loop) sampled at its eighths, each
## part a little behind the one that drives it (the hands behind the elbows behind the chest), so nothing stops dead.
FACING.update({
    "loose_up": ((-0.15, 0.95, -0.12), (0.1, 0.1, 1.0)),     # an arm trailing up limp, the fingers up, the palm forward
    "flung_up": ((-0.75, 0.6, -0.1), (0.0, 0.1, 1.0)),       # an arm flung up and out, the fingers out, the palm forward
    "tuck_shin": ((0.15, -0.6, 0.78), (0.95, 0.0, -0.2)),    # the hand on the shin in a tuck, the fingers down and forward
    "arrow": ((0.05, -1.0, -0.05), (0.98, 0.0, 0.15)),       # pressed to the thigh in the dive, the fingers down, the palm in
    "balance": ((-0.85, -0.15, 0.45), (0.0, -1.0, 0.1)),     # out to the side for the balance, the palm down
    "cross": ((0.85, 0.35, 0.3), (0.0, 0.1, -1.0)),          # crossed before the chest in the dodge, the palm in to the body
    "knee": ((0.1, -0.55, 0.83), (0.0, -1.0, 0.0)),          # braced on the knee, the fingers forward and down, the palm on it
    "jolt": ((-0.25, 0.4, 0.88), (0.0, -0.9, 0.4)),          # jolted up and out by a hit, the fingers forward, the palm down
})


def _loop(length, fn, keys=None):
    """A loop's channels from fn(phase) -> {channel: value}: each sampled at the loop's eighths (the seam's first again at
    the last). `keys` limits them."""
    frames = EIGHTHS(length)
    first = fn(0.0)
    out = {}
    for ch in (keys or first.keys()):
        out[ch] = _ring(frames, lambda a, c=ch: _rv(fn(a)[c]))
    return out


def _rv(v):
    return _r3(v) if isinstance(v, (tuple, list)) else round(float(v), 3)


def _add(v, d):
    return tuple(a + b for a, b in zip(v, d))


def _s(a, ph=0.0):
    return math.sin(a + ph)


def _c(a, ph=0.0):
    return math.cos(a + ph)


## The plain fall (own-bend-fall, a loop of 20 frames) as a function of its phase: the athlete in control in the air, a
## little bowed over the hips, the arms out wide at the shoulders' height for the balance (the elbows soft, the palms down),
## the legs ready under him (the right knee ahead, the left foot trailing back), the toes hanging; slowly paddling: the legs
## turn a slow bicycle, the chest breathes behind them, the arms answer behind the chest (opposite each other) and the head
## settles last.
def fall_at(a):
    return {
        "root": (0.0, 0.0 + 0.006 * _s(a), 0.0),
        "hips": 7.0 + 1.5 * _s(a), "chest": 5.0 + 2.0 * _s(a, -0.7), "roll": 1.5 * _s(a, -1.2), "twist": 2.5 * _s(a, -0.9),
        "head": 7.0 + 2.0 * _s(a, -1.5),
        "clav_r": (2.0 * _s(a, -1.4), -6.0 + 3.0 * _s(a, -1.4)), "clav_l": (-2.0 * _s(a, -1.4), -6.0 - 3.0 * _s(a, -1.4)),
        "hand_r": _add((-0.5, 1.2, 0.1), (0.02 * _c(a, -1.6), 0.04 * _s(a, -1.6), 0.03 * _c(a, -1.6))),
        "hand_l": _add((0.48, 1.25, 0.03), (-0.02 * _c(a, 1.5), -0.04 * _s(a, 1.5), -0.03 * _c(a, 1.5))),
        "face_r": "balance", "face_l": "balance",
        "pole_r": (-0.6, -0.7, -0.5), "pole_l": (0.6, -0.7, -0.5),
        "grip_r": -0.15, "grip_l": -0.15,
        "foot_r": _add((-0.14, 0.27, 0.1), (0.0, 0.035 * _s(a), 0.06 * _c(a))),
        "foot_l": _add((0.14, 0.33, -0.1), (0.0, -0.035 * _s(a), -0.06 * _c(a))),
        "heel_r": 26.0 + 5.0 * _s(a, -0.5), "heel_l": 30.0 - 5.0 * _s(a, -0.5),
        "fyaw_r": 6.0, "fyaw_l": 8.0,
        "knee_r": (-0.2, 0.15, 1.0), "knee_l": (0.2, 0.1, 1.0),
    }


AIR = dict(STAND)
AIR.update({k: _rv(v) if not isinstance(v, str) else v for k, v in fall_at(0.0).items()})
AR, AL = AIR["hand_r"], AIR["hand_l"]
AFR, AFL = AIR["foot_r"], AIR["foot_l"]


## The helpless fall (own-bend-helpless, a loop of 24 frames): spent and limp, nothing like the fall: the arms trailing up over
## the head as the air drags them (above the shoulders the whole loop), the back arched and the head thrown back looking up,
## the legs dangling loose under him; the whole body wallowing slowly round a cone (a slow pitch and roll a quarter turn apart,
## and a lazy turn), the limbs lagging it one after another.
def helpless_at(a):
    return {
        "flip": 9.0 * _s(a), "cart": 13.0 * _c(a), "yaw": 12.0 * _s(a, 0.6),
        "root": (0.0, 0.03, 0.0),
        "hips": -8.0 + 3.0 * _s(a, -0.5), "chest": -15.0 + 4.0 * _s(a, -1.0), "side": 5.0 * _c(a, -0.9),
        "twist": 6.0 * _s(a, -1.0), "head": -24.0 + 6.0 * _s(a, -1.6), "look": 8.0 * _s(a, -1.4),
        "clav_r": (-4.0, -18.0 + 4.0 * _s(a, -1.8)), "clav_l": (-4.0, -18.0 - 4.0 * _s(a, -1.8)),
        "hand_r": _add((-0.34, 1.8, -0.08), (0.06 * _c(a, -2.0), 0.035 * _s(a, -2.0), 0.05 * _s(a, -2.0))),
        "hand_l": _add((0.3, 1.84, -0.02), (0.06 * _c(a, -2.4 + math.pi), 0.035 * _s(a, -2.4 + math.pi), 0.05 * _s(a, -2.4 + math.pi))),
        "face_r": "loose_up", "face_l": "loose_up",
        "pole_r": (-1.0, -0.2, -0.3), "pole_l": (1.0, -0.2, -0.3),
        "grip_r": 0.25, "grip_l": 0.25,
        "foot_r": _add((-0.17, 0.22, 0.04), (0.02 * _s(a, -0.6), 0.03 * _s(a, -0.6), 0.07 * _c(a, -0.6))),
        "foot_l": _add((0.19, 0.27, -0.1), (-0.02 * _s(a, 2.2), 0.03 * _s(a, 2.2), 0.07 * _c(a, 2.2))),
        "heel_r": 38.0 + 6.0 * _s(a, -1.2), "heel_l": 34.0 + 6.0 * _s(a, 1.9),
        "fyaw_r": 14.0, "fyaw_l": 18.0,
        "knee_r": (-0.35, 0.0, 1.0), "knee_l": (0.4, 0.0, 1.0),
    }


## The air legs (own-bend-air-legs, a loop of 24 frames on the legs' bones only): both knees drawn up under the body (the
## right higher and ahead, the left lower and back), the toes pointed, drifting a little; under any cast let go in the air.
def air_legs_at(a):
    return {
        "foot_r": _add((-0.13, 0.5, 0.17), (0.0, 0.02 * _s(a), 0.03 * _c(a))),
        "foot_l": _add((0.14, 0.38, -0.06), (0.0, -0.02 * _s(a, 0.8), -0.03 * _c(a, 0.8))),
        "heel_r": 34.0 + 3.0 * _s(a, -0.6), "heel_l": 30.0 + 3.0 * _s(a, 1.0),
        "fyaw_r": 4.0, "fyaw_l": 10.0,
        "knee_r": (-0.12, 0.3, 1.0), "knee_l": (0.18, 0.2, 1.0),
    }


## The fast fall (own-bend-fall-fast, a loop of 16 frames): the tucked arrow: the body straight and long over the legs, the
## legs pressed together pointing down, the toes pointed, the arms pinned to the sides with the hands at the thighs, the
## shoulders drawn in, the chin down watching the landing; only the wind's shiver moves him.
def fall_fast_at(a):
    return {
        "root": (0.0, 0.05, 0.0),
        "hips": 2.0, "chest": 6.0 + 0.8 * _s(a), "head": 16.0 + 1.0 * _s(a, -1.0), "roll": 0.6 * _s(a, 2.0),
        "clav_r": (6.0, 8.0), "clav_l": (6.0, 8.0),
        "hand_r": _add((-0.2, 0.9, 0.0), (0.006 * _s(a, 1.0), 0.008 * _s(a, -0.5), 0.0)),
        "hand_l": _add((0.2, 0.9, 0.0), (-0.006 * _s(a, 2.0), 0.008 * _s(a, 2.5), 0.0)),
        "face_r": "arrow", "face_l": "arrow",
        "pole_r": (-0.4, 0.0, -1.0), "pole_l": (0.4, 0.0, -1.0),
        "grip_r": 0.75, "grip_l": 0.75,
        "foot_r": _add((-0.06, 0.2, 0.03), (0.0, 0.006 * _s(a), 0.008 * _c(a))),
        "foot_l": _add((0.06, 0.22, -0.01), (0.0, 0.006 * _s(a, 2.0), 0.008 * _c(a, 2.0))),
        "heel_r": 55.0, "heel_l": 55.0, "fyaw_r": 0.0, "fyaw_l": 0.0,
        "knee_r": (-0.05, 0.0, 1.0), "knee_l": (0.05, 0.0, 1.0),
    }


SET4 = {
    # the tumble (a long launch: hitstun past the knock's own hold): the knock-air's flung pose carried into a whole backward
    # somersault each loop, the limbs flung wide open (the turn slow) and then pulled into a tuck (the turn quick), as a body
    # thrown hard really turns; the legs lead, the arms follow two frames behind, a lazy roll and twist so it never reads
    # mechanical. Distinct from the knock-slide (on the feet) and the knock-air (one hop) at a glance: the whole body turns.
    "tumble": {
        "length": 24, "loop": True, "flip_turns": -1.0, "base": AIR,
        "meta": {"hand": "both", "mask": "full", "root": "place"},
        "flip": _ring(EIGHTHS(24), lambda a: round(30.0 * math.sin(a - 2 * math.pi * 3 / 24), 3)),
        "cart": _ring(EIGHTHS(24), lambda a: round(9.0 * math.sin(a + 0.8), 3)),
        "twist": _ring(EIGHTHS(24), lambda a: round(10.0 * math.sin(a + 1.6), 3)),
        "root": [(0, (0.0, 0.0, 0.0)), (24, (0.0, 0.0, 0.0))],
        "hips": [(0, -10), (6, -14), (12, 24), (18, 6), (24, -10)],
        "chest": [(0, -14), (6, -18), (12, 26), (18, 4), (24, -14)],
        "head": [(0, -18), (6, -20), (12, 20), (18, 0), (24, -18)],
        "side": [(0, 4), (6, 6), (12, -2), (18, -4), (24, 4)],
        "clav_r": [(0, (-6, -22)), (8, (-8, -26)), (14, (10, 6)), (20, (0, -10)), (24, (-6, -22))],
        "clav_l": [(0, (-4, -18)), (8, (-8, -24)), (14, (10, 6)), (20, (2, -8)), (24, (-4, -18))],
        "hand_r": [(0, (-0.6, 1.54, -0.02)), (8, (-0.64, 1.6, -0.1)), (14, (-0.2, 0.98, 0.4)), (20, (-0.52, 1.28, 0.2)),
                   (24, (-0.6, 1.54, -0.02))],
        "hand_l": [(0, (0.56, 1.46, 0.08)), (8, (0.64, 1.52, -0.02)), (14, (0.22, 1.02, 0.38)), (20, (0.48, 1.36, 0.24)),
                   (24, (0.56, 1.46, 0.08))],
        "face_r": [(0, "flung_up"), (9, "flung_up"), (14, "tuck_shin"), (19, "flail"), (24, "flung_up")],
        "face_l": [(0, "flung_up"), (9, "flung_up"), (14, "tuck_shin"), (19, "flail"), (24, "flung_up")],
        "pole_r": [(0, (-0.3, -0.8, -0.6)), (8, (-0.3, -0.8, -0.6)), (14, (-1.0, 0.0, 0.2)), (20, (-0.6, -0.6, -0.3)),
                   (24, (-0.3, -0.8, -0.6))],
        "pole_l": [(0, (0.3, -0.8, -0.6)), (8, (0.3, -0.8, -0.6)), (14, (1.0, 0.0, 0.2)), (20, (0.6, -0.6, -0.3)),
                   (24, (0.3, -0.8, -0.6))],
        "grip_r": [(0, -0.45), (8, -0.5), (14, 0.7), (20, 0.0), (24, -0.45)],
        "grip_l": [(0, -0.4), (8, -0.5), (14, 0.7), (20, 0.0), (24, -0.4)],
        "foot_r": [(0, (-0.2, 0.4, 0.24)), (6, (-0.27, 0.27, 0.16)), (12, (-0.13, 0.6, 0.3)), (18, (-0.19, 0.5, 0.3)),
                   (24, (-0.2, 0.4, 0.24))],
        "foot_l": [(0, (0.22, 0.31, 0.05)), (6, (0.29, 0.26, -0.08)), (12, (0.14, 0.56, 0.24)), (18, (0.2, 0.42, 0.17)),
                   (24, (0.22, 0.31, 0.05))],
        "heel_r": [(0, 30), (6, 40), (12, 34), (18, 24), (24, 30)],
        "heel_l": [(0, 34), (6, 44), (12, 30), (18, 26), (24, 34)],
        "fyaw_r": [(0, 16), (24, 16)], "fyaw_l": [(0, 20), (24, 20)],
        "knee_r": [(0, (-0.35, 0.3, 1.0)), (24, (-0.35, 0.3, 1.0))], "knee_l": [(0, (0.4, 0.3, 1.0)), (24, (0.4, 0.3, 1.0))],
    },
    # the flinch (a light hit that leaves him on his feet; upper mask, 0.27 s): the chest snapped back and turned, the shoulders
    # jumping up, the hands jolted up and open, the head thrown back a beat later; it settles back through the stand, the head
    # last.  strike_s: the hit; hold_s: the recoil's peak; back_s: the settle
    "flinch": {
        "length": 8,
        "meta": {"strike_s": 1 / FPS, "hold_s": 2 / FPS, "back_s": 4 / FPS, "hand": "both", "mask": "upper", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (2, (0.0, -0.03, -0.025)), (5, (0.0, -0.02, -0.008)), (8, (0, -0.015, 0))],
        "hips": [(0, 0), (1, -3), (2, -5), (5, -1), (8, 0)],
        "chest": [(0, 0), (1, -9), (2, -13), (4, -6), (6, -1), (8, 0)],
        "twist": [(0, 0), (1, 7), (2, 9), (5, 2), (8, 0)],
        "side": [(0, 0), (2, 4), (5, 1), (8, 0)],
        "head": [(0, 0), (1, 4), (2, -9), (3, -12), (5, -5), (7, -1), (8, 0)],
        "clav_r": [(0, (0, 0)), (1, (4, -10)), (2, (6, -14)), (5, (2, -4)), (8, (0, 0))],
        "clav_l": [(0, (0, 0)), (1, (4, -10)), (2, (6, -13)), (5, (2, -4)), (8, (0, 0))],
        "hand_r": [(0, HR), (1, (-0.22, 0.9, 0.14)), (2, (-0.24, 1.0, 0.22)), (4, (-0.23, 0.93, 0.15)), (6, (-0.2, 0.83, 0.08)),
                   (8, HR)],
        "hand_l": [(0, HL), (1, (0.22, 0.88, 0.12)), (2, (0.24, 0.98, 0.2)), (4, (0.23, 0.92, 0.14)), (6, (0.2, 0.83, 0.08)),
                   (8, HL)],
        "face_r": [(0, "stand"), (2, "jolt"), (4, "jolt"), (8, "stand")],
        "face_l": [(0, "stand"), (2, "jolt"), (4, "jolt"), (8, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (2, (-0.7, -0.4, -0.6)), (8, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (2, (0.7, -0.4, -0.6)), (8, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (1, -0.4), (4, -0.3), (8, 0.4)],
        "grip_l": [(0, 0.4), (1, -0.4), (4, -0.3), (8, 0.4)],
    },
    # the double jump (the tucked knees-up spring): from the fall, the legs kick down hard against the air and the arms sweep
    # down behind (the push); then both knees snap up to the chest as the arms swing up and out over the head (the spring at
    # its height, held a beat); opened out into the fall again, the arms last.  strike_s: the push; hold_s: the gather
    "jump_double": {
        "length": 12, "base": AIR,
        "meta": {"hold_s": 1 / FPS, "strike_s": 3 / FPS, "back_s": 7 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, AIR["root"]), (2, (0.0, -0.03, 0.0)), (5, (0.0, 0.05, 0.0)), (8, (0.0, 0.03, 0.0)), (12, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 2), (5, 18), (8, 14), (12, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 8), (5, 6), (8, 2), (12, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, 12), (4, -6), (6, -8), (9, 2), (12, AIR["head"])],
        "clav_r": [(0, AIR["clav_r"]), (2, (-8, 8)), (5, (2, -22)), (8, (2, -16)), (12, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (-8, 8)), (5, (2, -22)), (8, (2, -16)), (12, AIR["clav_l"])],
        "hand_r": [(0, AR), (2, (-0.36, 0.86, -0.18)), (4, (-0.5, 1.3, 0.06)), (6, (-0.42, 1.76, 0.08)), (8, (-0.44, 1.7, 0.08)),
                   (12, AR)],
        "hand_l": [(0, AL), (2, (0.36, 0.86, -0.18)), (4, (0.5, 1.32, 0.06)), (6, (0.42, 1.78, 0.06)), (8, (0.44, 1.72, 0.06)),
                   (12, AL)],
        "face_r": [(0, "balance"), (2, "stand"), (5, "flung_up"), (9, "flung_up"), (12, "balance")],
        "face_l": [(0, "balance"), (2, "stand"), (5, "flung_up"), (9, "flung_up"), (12, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (2, (-0.3, 0.0, -1.0)), (6, (-1.0, -0.3, -0.3)), (12, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (2, (0.3, 0.0, -1.0)), (6, (1.0, -0.3, -0.3)), (12, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, 0.6), (5, -0.5), (12, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, 0.6), (5, -0.5), (12, AIR["grip_l"])],
        "foot_r": [(0, AFR), (2, (-0.13, 0.18, -0.02)), (5, (-0.12, 0.58, 0.3)), (8, (-0.12, 0.54, 0.28)), (12, AFR)],
        "foot_l": [(0, AFL), (2, (0.13, 0.19, -0.05)), (5, (0.13, 0.55, 0.24)), (8, (0.13, 0.5, 0.22)), (12, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (2, 48), (5, 28), (12, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (2, 48), (5, 28), (12, AIR["heel_l"])],
        "knee_r": [(0, AIR["knee_r"]), (2, (-0.1, 0.0, 1.0)), (5, (-0.15, 0.4, 1.0)), (12, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (2, (0.1, 0.0, 1.0)), (5, (0.15, 0.4, 1.0)), (12, AIR["knee_l"])],
    },
    "fall": dict({"length": 20, "loop": True, "base": AIR, "meta": {"hand": "both", "mask": "full", "root": "place"}},
                 **_loop(20, fall_at, [k for k in fall_at(0.0) if not k.startswith("face_")]),
                 face_r=[(0, "balance"), (20, "balance")], face_l=[(0, "balance"), (20, "balance")]),
    "fall_fast": dict({"length": 16, "loop": True, "base": AIR, "meta": {"hand": "both", "mask": "full", "root": "place"}},
                      **_loop(16, fall_fast_at, [k for k in fall_fast_at(0.0) if not k.startswith("face_")]),
                      face_r=[(0, "arrow"), (16, "arrow")], face_l=[(0, "arrow"), (16, "arrow")]),
    "helpless": dict({"length": 24, "loop": True, "base": AIR, "meta": {"hand": "both", "mask": "full", "root": "place"}},
                     **_loop(24, helpless_at, [k for k in helpless_at(0.0) if not k.startswith("face_")]),
                     face_r=[(0, "loose_up"), (24, "loose_up")], face_l=[(0, "loose_up"), (24, "loose_up")]),
    # the air dodge (a sharp tucked twist; the code moves him): from the fall the knees snap up and the arms cross before the
    # chest, the chin down, and the whole tuck turns once round (quick in, eased out); then it opens back into the fall, the
    # legs first, the arms after.  hold_s: the snap in; strike_s: tucked (untouchable from here); back_s: opening
    "air_dodge": {
        "length": 15, "base": AIR,
        "meta": {"hold_s": 1 / FPS, "strike_s": 2 / FPS, "back_s": 9 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "spin": [(0, 0), (2, 30), (5, 200), (8, 330), (10, 360), (15, 360)],
        "root": [(0, AIR["root"]), (2, (0.0, 0.06, 0.0)), (9, (0.0, 0.06, 0.0)), (15, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 16), (9, 15), (12, 10), (15, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 20), (9, 18), (12, 9), (15, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, 18), (9, 16), (13, 9), (15, AIR["head"])],
        "twist": [(0, 0), (2, 8), (9, 6), (15, 0)],
        "clav_r": [(0, AIR["clav_r"]), (2, (14, 8)), (10, (12, 6)), (15, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (14, 8)), (10, (12, 6)), (15, AIR["clav_l"])],
        "hand_r": [(0, AR), (2, (0.1, 1.26, 0.24)), (9, (0.1, 1.25, 0.24)), (12, (-0.3, 1.18, 0.22)), (15, AR)],
        "hand_l": [(0, AL), (2, (-0.08, 1.3, 0.2)), (9, (-0.08, 1.29, 0.2)), (12, (0.28, 1.24, 0.18)), (15, AL)],
        "face_r": [(0, "balance"), (2, "cross"), (10, "cross"), (15, "balance")],
        "face_l": [(0, "balance"), (2, "cross"), (10, "cross"), (15, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (2, (-0.8, -0.6, 0.2)), (10, (-0.8, -0.6, 0.2)), (15, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (2, (0.8, -0.6, 0.2)), (10, (0.8, -0.6, 0.2)), (15, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, 0.9), (10, 0.9), (15, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, 0.9), (10, 0.9), (15, AIR["grip_l"])],
        "foot_r": [(0, AFR), (2, (-0.11, 0.6, 0.26)), (9, (-0.11, 0.59, 0.25)), (12, (-0.13, 0.4, 0.18)), (15, AFR)],
        "foot_l": [(0, AFL), (2, (0.11, 0.56, 0.2)), (9, (0.11, 0.55, 0.19)), (12, (0.13, 0.42, 0.04)), (15, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (2, 36), (12, 30), (15, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (2, 36), (12, 30), (15, AIR["heel_l"])],
        "knee_r": [(0, AIR["knee_r"]), (2, (-0.1, 0.5, 1.0)), (10, (-0.1, 0.5, 1.0)), (15, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (2, (0.1, 0.5, 1.0)), (10, (0.1, 0.5, 1.0)), (15, AIR["knee_l"])],
    },
    "air_legs": dict({"length": 24, "loop": True, "bones": "legs", "base": AIR,
                      "meta": {"hand": "both", "mask": "lower", "root": "place"}}, **_loop(24, air_legs_at)),
    # the light landing (from the fall: a plain landing, short lag): the toes take the deck, the heels roll down, the knees
    # give and the hips sink, the arms come down from the balance in front; up through the stand, the arms settling last.
    # strike_s: the heels down; hold_s: the lowest; back_s: rising
    "land_light": {
        "length": 10,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 5 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.01, 0.0)), (1, (0.0, -0.06, 0.01)), (3, (0.0, -0.15, 0.03)), (5, (0.0, -0.12, 0.025)),
                 (8, (0.0, -0.035, 0.005)), (10, (0, -0.015, 0))],
        "hips": [(0, 5), (1, 8), (3, 14), (5, 11), (8, 3), (10, 0)],
        "chest": [(0, 4), (1, 6), (3, 10), (5, 8), (8, 2), (10, 0)],
        "head": [(0, 6), (2, 10), (4, 6), (7, 1), (10, 0)],
        "clav_r": [(0, (2, -6)), (3, (6, 4)), (10, (0, 0))], "clav_l": [(0, (-2, -6)), (3, (6, 4)), (10, (0, 0))],
        "hand_r": [(0, (-0.5, 1.18, 0.12)), (2, (-0.4, 0.98, 0.2)), (4, (-0.3, 0.84, 0.22)), (7, (-0.23, 0.8, 0.13)), (10, HR)],
        "hand_l": [(0, (0.48, 1.22, 0.06)), (2, (0.4, 1.0, 0.18)), (4, (0.3, 0.86, 0.2)), (7, (0.23, 0.8, 0.12)), (10, HL)],
        "face_r": [(0, "balance"), (3, "palm_down"), (10, "stand")], "face_l": [(0, "balance"), (3, "palm_down"), (10, "stand")],
        "pole_r": [(0, (-0.6, -0.7, -0.5)), (4, (-0.6, -0.5, -0.6)), (10, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.6, -0.7, -0.5)), (4, (0.6, -0.5, -0.6)), (10, (0.35, -0.1, -1.0))],
        "grip_r": [(0, -0.15), (4, 0.1), (10, 0.4)], "grip_l": [(0, -0.15), (4, 0.1), (10, 0.4)],
        "foot_r": [(0, FR), (10, FR)], "foot_l": [(0, FL), (10, FL)],
        "heel_r": [(0, 14), (1, 0), (10, 0)], "heel_l": [(0, 16), (1, 0), (10, 0)],
        "knee_r": [(0, "auto"), (2, (-0.25, 0.0, 1.0)), (6, (-0.25, 0.0, 1.0)), (9, "auto")],
        "knee_l": [(0, "auto"), (2, (0.25, 0.0, 1.0)), (6, (0.25, 0.0, 1.0)), (9, "auto")],
    },
    # the heavy landing (the landing lag of a Slam, a missed air cast or the helpless fall: the punish window, and it must read
    # as one): the arms still up from the air, he slams down into a deep squat, the hips dropping hard, the body folding over the
    # knees with both hands slapped onto them and the head hanging; held there with a small sag (the window); then a heavy push
    # up through the thighs to the stand.  strike_s: the impact; hold_s: the bottom; back_s: the push up
    "land_heavy": {
        "length": 12,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 8 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.02, 0.0)), (1, (0.0, -0.14, 0.02)), (3, (0.0, -0.36, 0.06)), (5, (0.0, -0.33, 0.055)),
                 (8, (0.0, -0.34, 0.055)), (10, (0.0, -0.13, 0.02)), (12, (0, -0.015, 0))],
        "hips": [(0, 4), (1, 14), (3, 34), (5, 31), (8, 32), (10, 12), (12, 0)],
        "chest": [(0, -4), (1, 6), (3, 18), (5, 15), (8, 16), (10, 6), (12, 0)],
        "head": [(0, -10), (1, -2), (3, 16), (5, 22), (8, 20), (10, 6), (12, 0)],
        "side": [(0, 0), (3, -3), (8, -2), (12, 0)],
        "clav_r": [(0, (-4, -16)), (2, (6, 0)), (4, (10, 8)), (8, (8, 6)), (12, (0, 0))],
        "clav_l": [(0, (-4, -16)), (2, (6, 0)), (4, (10, 8)), (8, (8, 6)), (12, (0, 0))],
        "hand_r": [(0, (-0.38, 1.72, 0.0)), (1, (-0.38, 1.3, 0.2)), (3, (-0.2, 0.72, 0.36)), (5, (-0.2, 0.69, 0.35)),
                   (8, (-0.2, 0.7, 0.35)), (10, (-0.24, 0.8, 0.2)), (12, HR)],
        "hand_l": [(0, (0.34, 1.76, 0.02)), (1, (0.36, 1.34, 0.2)), (3, (0.2, 0.73, 0.35)), (5, (0.2, 0.7, 0.34)),
                   (8, (0.2, 0.71, 0.34)), (10, (0.23, 0.8, 0.19)), (12, HL)],
        "face_r": [(0, "loose_up"), (2, "knee"), (9, "knee"), (12, "stand")],
        "face_l": [(0, "loose_up"), (2, "knee"), (9, "knee"), (12, "stand")],
        "pole_r": [(0, (-1.0, -0.2, -0.3)), (3, (-1.0, 0.2, -0.2)), (9, (-1.0, 0.2, -0.2)), (12, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (1.0, -0.2, -0.3)), (3, (1.0, 0.2, -0.2)), (9, (1.0, 0.2, -0.2)), (12, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.25), (3, -0.1), (9, -0.1), (12, 0.4)], "grip_l": [(0, 0.25), (3, -0.1), (9, -0.1), (12, 0.4)],
        "foot_r": [(0, FR), (12, FR)], "foot_l": [(0, FL), (12, FL)],
        "fyaw_r": [(0, 7), (12, 7)], "fyaw_l": [(0, 7), (12, 7)],
        "heel_r": [(0, 12), (1, 0), (12, 0)], "heel_l": [(0, 14), (1, 0), (12, 0)],
        "knee_r": [(0, "auto"), (2, (-0.45, 0.0, 1.0)), (9, (-0.45, 0.0, 1.0)), (11, "auto")],
        "knee_l": [(0, "auto"), (2, (0.45, 0.0, 1.0)), (9, (0.45, 0.0, 1.0)), (11, "auto")],
    },
}
CLIPS.update(SET4)


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


def _periodic(xs, ys, x, period):
    """A loop's cubic through the keys (a stance): the tangents taken across the seam (the last key is the first's, at
    `period`), so the loop carries on through its start instead of easing to a stop there; flat where a key is a turn."""
    n = len(xs)
    if n < 3:
        return _cubic(xs, ys, x)
    x = x % period
    d = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
    m = [0.0] * n
    for i in range(n):
        a = d[i - 1] if i > 0 else d[-1]
        b = d[i] if i < n - 1 else d[0]
        m[i] = 0.0 if a * b <= 0 else (a + b) / 2
    for i in range(n - 1):
        if xs[i] <= x <= xs[i + 1]:
            h = xs[i + 1] - xs[i]
            t = (x - xs[i]) / h
            h00, h10 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t
            h01, h11 = -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
            return h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]
    return ys[-1]


def chan(clip, key):
    return clip.get(key) or [(0, clip.get("base", STAND)[key])]


def num(clip, key, f):
    keys = chan(clip, key)
    xs = [k[0] for k in keys]
    v0 = keys[0][1]
    loop = clip.get("loop") and len(keys) > 2 and xs[-1] == clip["length"]

    def one(ys):
        return _periodic(xs, ys, f, clip["length"]) if loop else _cubic(xs, ys, f)
    if isinstance(v0, (tuple, list)):
        return Vector([one([k[1][i] for k in keys]) for i in range(len(v0))])
    return one([float(k[1]) for k in keys])


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


def knee_pole(clip, side, f, hip, yaw_deg, qs=None):
    a, b, u = seg(chan(clip, "knee_" + side), f)
    sg = 1.0 if side == "l" else -1.0
    auto = q_axis((0, 1, 0), sg * yaw_deg) @ Vector((sg * 0.18, 0.0, 1.0))

    def val(v):
        return auto.normalized() if isinstance(v, str) else Vector(v).normalized()
    v = val(a).lerp(val(b), u).normalized()
    return hip + (qs @ v if qs is not None else v)


## The last pose's limbs, for the reach report (--fit): side+"_arm" / side+"_leg" -> (base joint, IK target, reach, the
## channel's place: the palm's or the ankle's).
DIAG = {}


## The height (m) of the point an airborne figure turns about (flip, cart): the hips' height on the stand, so a somersault
## turns about the body's middle.
PIVOT_Y = 0.98


def tumbling(clip):
    """An airborne clip that turns the whole figure (keys flip or cart, or flip_turns)."""
    return "flip" in clip or "cart" in clip or "flip_turns" in clip


def flip_at(clip, f):
    """The somersault's angle at f (deg): flip_turns whole turns spread evenly over the clip (a loop's steady tumble, the last
    frame's turn the first's) plus the flip channel's keys on top (the turn quickening as the body tucks, slowing as it opens)."""
    base = 360.0 * clip.get("flip_turns", 0.0) * f / clip["length"]
    return base + (num(clip, "flip", f) if "flip" in clip else 0.0)


# ---------------------------------------------------------------- one frame
def pose(clip, f):
    rots = {k: v.copy() for k, v in REST.items()}
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    # spin: the whole figure turned about the vertical through the stand's middle, the feet's and the hands' places with it
    # (a turn on the spot: Baguazhang's circles); 0 for every clip that does not key it
    spin = num(clip, "spin", f) if "spin" in clip else 0.0
    qs = q_axis(Y, spin)
    yaw, twist = num(clip, "yaw", f), num(clip, "twist", f)
    look = num(clip, "look", f)
    if tumbling(clip):
        # an airborne figure turned whole about the pivot (the hips' height over the stand's middle): flip its somersault
        # (+ the head forward and down, - backward), cart its cartwheel (+ the left side up), after the spin; every place and
        # way the keys give (the palms, the ankles, the poles, the facings) turns with it, so the keys stay the body's own pose
        Q = qs @ q_axis(X, flip_at(clip, f)) @ q_axis(Z, num(clip, "cart", f) if "cart" in clip else 0.0)
        piv = Vector((0.0, PIVOT_Y, 0.0))

        def xf(v):
            return piv + Q @ (Vector(v) - piv)
        up = Q @ Y
        root = xf(ROOT_REST + num(clip, "root", f))
        qbody = Q @ q_axis(Y, yaw + twist)
        qhead = Q @ q_axis(Y, (yaw + twist) * 0.2 + look)
    else:
        Q = qs

        def xf(v):
            return qs @ v
        up = Y
        root = ROOT_REST + qs @ num(clip, "root", f)
        qbody = q_axis(Y, spin + yaw + twist)
        qhead = q_axis(Y, spin + (yaw + twist) * 0.2 + look)
    qyaw = q_axis(Y, yaw)
    # the whole body: the yaw, the hips' bow and tilt (the legs are planted again below)
    rots["root"] = Q @ qyaw @ q_axis(X, num(clip, "hips", f)) @ q_axis(Z, num(clip, "roll", f)) @ rots["root"]
    # the spine: its turn, then its pitch and side bend about the turned body's own axes, a share a vertebra
    for nm, share in SPINE:
        turn(rots, nm, q_axis(up, twist * share))
    for nm, share in SPINE:
        turn(rots, nm, q_axis(qbody @ X, num(clip, "chest", f) * share) @ q_axis(qbody @ Z, num(clip, "side", f) * share))
    # the head: kept on the mark through the body's turn (look turns it), its pitch about its own facing
    for nm, share in NECK:
        turn(rots, nm, q_axis(up, (-(yaw + twist) * 0.8 + look) * share))
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
        place = xf(num(clip, "foot_" + s, f))
        fyaw = num(clip, "fyaw_" + s, f)
        heel = num(clip, "heel_" + s, f)
        qy = Q @ q_axis(Y, sg * fyaw)
        lat = qy @ X
        ball0 = P_REST[s + "_ball"] - P_REST[s + "_ankle"]           # the ball from the ankle, the foot flat (world)
        ball = place + qy @ ball0
        qh = q_axis(lat, heel)
        pivot = ball if heel >= 0 else place + qy @ (P_REST[s + "_heel"] - P_REST[s + "_ankle"])
        ankle = pivot + qh @ (place - pivot)
        ga = qh @ qy @ G_REST[s + "_ankle"]
        P, G = SK.fk(rots, root)
        hip = P[s + "_upper_leg"]
        DIAG[s + "_leg"] = (hip.copy(), ankle.copy(), (P_REST[s + "_knee"] - P_REST[s + "_upper_leg"]).length +
                            (P_REST[s + "_ankle"] - P_REST[s + "_knee"]).length, place.copy())
        for _ in range(2):
            rigkit.ik2(rots, root, s + "_upper_leg", s + "_knee", s + "_ankle", ankle, knee_pole(clip, s, f, hip, fyaw, Q))
        set_global(rots, s + "_ankle", ga)
        # the toes flat on the ground while the ball is on it, else with the foot
        on = 1.0 - smooth((ball.y - 0.04) / 0.08)
        gb = (qy @ G_REST[s + "_ball"]).slerp(qh @ qy @ G_REST[s + "_ball"], 1.0 - on) if heel > 0 else qh @ qy @ G_REST[s + "_ball"]
        set_global(rots, s + "_ball", gb)
    # the arms: each palm to its place, facing its way, the elbow toward its pole
    for s in "lr":
        gw = Q @ facing_at(clip, s, f)
        palm_t = xf(num(clip, "hand_" + s, f))
        wrist_t = palm_t - gw @ SK.rest_t[s + "_palm"]
        pole_v = Q @ num(clip, "pole_" + s, f)
        P, G = SK.fk(rots, root)
        DIAG[s + "_arm"] = (P[s + "_shoulder"].copy(), wrist_t.copy(), (P_REST[s + "_elbow"] - P_REST[s + "_shoulder"]).length +
                            (P_REST[s + "_wrist"] - P_REST[s + "_elbow"]).length, palm_t.copy())
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
    if clip.get("loop"):
        out["loop"] = True
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
        if key in ("length", "meta", "mirror", "loop", "base"):
            continue
        if key in ("flip_turns", "bones"):
            out[key] = keys
            continue
        if key in ("yaw", "twist", "roll", "side", "look", "spin", "cart"):
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


## The slack an arm or a leg keeps short of straight at its keys (m): less is flagged by --fit (a limb locked straight by the IK
## reads stiff; the polish pulls such keys in).
SLACK = 0.015
## The striking limb's slack at strike_s that --fit suggests (m): out nearly straight, not locked.
STRIKE_SLACK = 0.03


def bake(clip, fit=None):
    """The clip's frames; `fit` (a list) collects the frames where a limb is within SLACK of straight or past it: (frame, limb,
    slack, the channel's place pulled in to SLACK)."""
    frames, roots, report = [], [], []
    names = keyed()
    legs_only = clip.get("bones") == "legs"
    if legs_only:
        # a legs-only layer (the air-legs under a cast): only the legs' bones keyed, their rotations each in its parent's frame,
        # so the legs keep their tuck under whatever the hips and the upper body are doing; no root place
        names = [nm for nm in names if any(nm == s + "_" + b for s in "lr" for b in LEG)]
    for f in range(clip["length"] + 1):
        rigkit.MISS.clear()
        rots, root = pose(clip, f)
        frames.append({nm: [rots[nm].x, rots[nm].y, rots[nm].z, rots[nm].w] for nm in names})
        if not legs_only:
            roots.append([root.x, root.y, root.z])
        P, G = SK.fk(rots, root)
        report.append((f, [round(x, 3) for x in P["r_palm"]], [round(x, 3) for x in P["l_palm"]], round(P["pelvis"].y, 3),
                       [round(x, 3) for x in P["r_ankle"]], [round(x, 3) for x in P["l_ankle"]],
                       round(max([d for _, d in rigkit.MISS] or [0.0]), 3)))
        if fit is not None:
            for limb, (base, target, reach, place) in DIAG.items():
                d = (target - base).length
                slack = reach - d
                if slack < SLACK:
                    pulled = place - (target - base).normalized() * (SLACK - slack)
                    fit.append((f, limb, round(slack, 3), tuple(round(x, 3) for x in pulled)))
                elif f == round(clip["meta"].get("strike_s", -1.0) * FPS) and limb[0] in str(clip["meta"].get("hand", "")) \
                        .replace("both", "lr").replace("foot_", ""):
                    # the striking limb at the strike: how far short of straight (a punch or a palm reads weak bent), and
                    # its place carried out to STRIKE_SLACK along the same line
                    if (limb.endswith("arm") and "foot" not in str(clip["meta"].get("hand"))) or \
                            (limb.endswith("leg") and "foot" in str(clip["meta"].get("hand"))):
                        out = place + (target - base).normalized() * (slack - STRIKE_SLACK)
                        fit.append((f, limb + " STRIKE", round(slack, 3), tuple(round(x, 3) for x in out)))
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
    ap.add_argument("--fit", action="store_true", help="list the frames where a limb is (nearly) locked straight")
    a = ap.parse_args(argv)
    only = [c for c in a.clips.split(",") if c]
    out = {"fps": FPS, "clips": {}, "names": {},
           "about": "tools/anim_author/blender/bend_clips.py: our own ring-sport casts and knocks, key poses IK-solved on Actor_B's "
                    "rig in Blender from the rig's rest pose (no library clip read)"}
    baked = {}
    print("BEND rest r_shoulder %s r_palm %s  hand axes r %s" % ([round(x, 3) for x in P_REST["r_shoulder"]],
                                                                  [round(x, 3) for x in P_REST["r_palm"]],
                                                                  [[round(x, 3) for x in v] for v in HAND_LOCAL["r"]]))
    if a.fit:
        for j in ("r_shoulder", "r_elbow", "r_wrist", "r_palm", "r_upper_leg", "r_knee", "r_ankle", "r_ball", "pelvis", "neck",
                  "heada"):
            print("BEND rest %s %s" % (j, [round(x, 3) for x in P_REST[j]]))
        P0, _ = SK.fk(*pose({"length": 1}, 0))
        for j in ("r_shoulder", "r_palm", "r_upper_leg", "r_ankle", "pelvis", "heada"):
            print("BEND stand %s %s" % (j, [round(x, 3) for x in P0[j]]))
    for name, clip in all_clips().items():
        if only and name not in only and name.removesuffix("_l") not in only:
            continue
        fit = [] if a.fit else None
        frames, roots, report = bake(clip, fit)
        meta = dict(clip["meta"])
        meta["length_frames"] = clip["length"]
        # the worst miss of the two-bone IK over the frames (m: a target out of a limb's reach), kept with the clip so the
        # library can be checked against it (tests/bending/test_bend_clips.gd: at most 5 mm)
        meta["ik_miss_m"] = round(max(r[-1] for r in report), 4)
        if clip.get("loop"):
            meta["loop"] = "linear"
        out["clips"][name] = {"frames": frames, "root": roots, "meta": meta}
        out["names"][name] = game_name(name)
        baked[name] = (frames, roots)
        worst = max(r[-1] for r in report)
        print("BEND %s -> %s: %d frames, worst IK miss %.3f m" % (name, game_name(name), len(frames), worst))
        for fr in fit or []:
            print("   FIT %s f%02d %s slack %.3f -> %s" % (name, fr[0], fr[1], fr[2], fr[3]))
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
