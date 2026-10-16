"""Muay Thai for fire: the style's own clips (the owner, 2026-10-16: "we need to create all these bending styles"; Muay Thai
after Taekwondo). The strikes come from the Motifect pack's Muay Thai clips (tools/anim_author/blender/motifect_clips.py
mt_*: the elbow cut, the clinch knee, the body kick, the teep, the high roundhouse, the shin check); this file keys what the
pack has no clip for: the stance the strikes leave and come back to, the cross (key 1's Punch), and the steps of the Shift
movement. Every fire move keeps what it DOES; the style only changes how the body shows it, timed as fire's own
(BendPoses._timed_as).

Derived from tools/anim_author/blender/bend_clips.py through style_kit.py and from nothing else: key poses typed into
CLIPS, posed by bend_clips' solver (two-bone IK on Actor_B's own rig, assets/character/actor_b_body.glb) in Blender and
baked to the bones' local rotations as Godot has them, for tools/anim_author/install_style.gd. No library clip, no dumped
move and nothing from the Motifect pack is read here. Keyed from standard Muay Thai mechanics (the upright, square guard
with the fists by the temples and the elbows forward, the lead foot's tap, the step-and-slide); no video looked at: a
stance, a straight punch and a step are plain standing motions.

The clips (own-style-muay-thai-<name> in animations_extra/Frontier_Style_Muay_thai.res; the left side leads, as the pack's
strikes do):
  stance       fire's idle while in the style: upright and nearly square, the feet a shoulder's width apart and the lead
               foot ahead, the rear heel up, the fists high by the temples with the elbows forward and down over the ribs,
               the chin tucked; the Muay Thai rhythm: a rock front to back with the lead foot lifting and tapping down
               twice a loop, the hands riding it
  cross        the Punch (key 1): the rear fist driven straight out at chin height off the rear heel's pivot, the hips
               and shoulders turned through it, the lead fist kept at the temple; back to the guard
  step_in, step_back, step_side   the Shift movement (fire's Step): the step-and-slide: the foot nearest the way steps,
               the other slides up after it, the feet never crossed, the guard kept high (the pose is picked by the mode,
               not the direction held, as Boxing's steps are)

Metas as style_boxing.py's. Channels as bend_clips.py's (+X the character's left, +Y up, +Z forward, metres; angles in
degrees); a channel a clip leaves out holds the stance's.

  Blender -b --factory-startup --python tools/anim_author/blender/style_muay_thai.py -- --out <muay_thai.json>
      [--clips stance,cross] [--fit] [--angles] [--points] [--quiet]
  (through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import style_kit as kit  # noqa: E402
import bend_clips as bc  # noqa: E402
from bend_clips import FACING, FPS, STAND  # noqa: E402

STYLE = "muay_thai"
ELEMENT = "fire"

kit.hands()

FACING.update({
    "mt_guard": ((0.15, 0.85, 0.5), (0.95, -0.1, -0.3)),      # a fist up by the temple, the knuckles up and forward, the palm in
    "mt_cross": ((-0.1, 0.1, 0.99), (0.0, -1.0, 0.1)),        # the cross landing: the knuckles forward, the fist turned palm down
})

## The guard: nearly square (the hips turned 18 to the right, the shoulders 4 more), the feet a shoulder's width apart with the
## left foot ahead, the rear foot turned out 30 with its heel up; upright, the root barely down; the fists high by the
## temples, the elbows forward and down over the ribs, the chin tucked.
MT_FOOT_L = (0.15, 0.077, 0.2)
MT_FOOT_R = (-0.18, 0.077, -0.19)
MT_FIST_L = (0.1, 1.43, 0.3)
MT_FIST_R = (-0.11, 1.41, 0.2)
GUARD = {
    "root": (0.0, -0.058, 0.0), "yaw": -18.0, "twist": -4.0, "hips": 3.0, "roll": 0.0, "chest": 6.0, "side": 0.0,
    "head": 10.0, "look": 0.0, "clav_r": (10.0, -6.0), "clav_l": (12.0, -7.0),
    "hand_r": MT_FIST_R, "hand_l": MT_FIST_L, "face_r": "mt_guard", "face_l": "mt_guard",
    "pole_r": (-0.25, -1.0, 0.3), "pole_l": (0.25, -1.0, 0.3), "grip_r": 1.0, "grip_l": 1.0,
    "foot_r": MT_FOOT_R, "foot_l": MT_FOOT_L, "fyaw_r": 30.0, "fyaw_l": -2.0, "heel_r": 14.0, "heel_l": 2.0,
    "knee_r": (-0.4, 0.0, 1.0), "knee_l": (0.25, 0.0, 1.0),
}

META = {"mask": "full", "root": "place", "style": STYLE, "element": ELEMENT}
S = 1.0 / FPS

## The rhythm: a rock front to back once a loop, the lead foot lifted and tapped down twice a loop (the Muay Thai march),
## the rear heel riding the rock, the hands and shoulders a beat late with the body.
STANCE_LEN = 36


def stance_at(a):
    rock = kit.s_(a)                           # + the weight forward
    tap = max(0.0, kit.s_(2 * a))              # the lead foot up (two taps a loop)
    late = 0.5 - 0.5 * kit.c_(2 * a, -0.8)
    root = (0.0, -0.058 - 0.008 * tap, 0.02 * rock)
    return {k: kit.r_(v) for k, v in {
        "root": root,
        "hips": 3.0 + 1.0 * rock, "chest": 6.0 + 1.5 * late, "head": 10.0 - 1.0 * late,
        "yaw": -18.0 + 1.5 * rock, "twist": -4.0 - 1.0 * rock,
        "clav_r": (10.0, -6.0 - 1.5 * late), "clav_l": (12.0, -7.0 - 1.5 * late),
        "hand_r": kit.add(MT_FIST_R, (0.0, root[1] + 0.058 - 0.01 * late, root[2])),
        "hand_l": kit.add(MT_FIST_L, (0.012 * kit.c_(a), root[1] + 0.058 - 0.012 * late, root[2] + 0.01 * kit.s_(a, 0.6))),
        "foot_l": kit.add(MT_FOOT_L, (0.0, 0.035 * tap, 0.02 * tap)),
        "heel_l": 2.0 + 20.0 * tap, "heel_r": 12.0 + 8.0 * rock,
    }.items()}


BASE = dict(STAND)
BASE.update(GUARD)
BASE.update(stance_at(0.0))
clip = kit.clip_on(BASE, META)

CLIPS = {
    # ---------------------------------------------------------------- the stance (fire's stance while in Muay Thai)
    "stance": dict(bc._loop(STANCE_LEN, stance_at), length=STANCE_LEN, loop=True, base=BASE,
                   meta=dict(META, hand="both", move="stance", mode="stance", order=0)),

    # ---------------------------------------------------------------- key 1: the cross (the Punch)
    # the load onto the rear leg (the root back a touch), then the rear fist driven straight out at chin height as the rear
    # heel pivots and the hips and shoulders turn through, the lead fist kept at the temple; the fist snapped back along its
    # line.  strike_s: the arm out
    "cross": clip(26, dict(hold_s=4 * S, strike_s=9 * S, back_s=14 * S, antic_s=4 * S, follow_s=12 * S, hand="r",
                           move="fire_blast", mode="punch", order=1, stills="load:4;strike:9;snap back:12;guard:18"),
        root=[(4, (0.01, -0.065, -0.025)), (9, (-0.02, -0.07, 0.06)), (12, (-0.015, -0.07, 0.05)), (18, (0.0, -0.058, 0.0))],
        yaw=[(4, -14.0), (9, -46.0), (12, -42.0), (18, -18.0)],
        twist=[(4, -2.0), (9, -24.0), (12, -20.0), (18, -4.0)],
        hips=[(4, 3.0), (9, 6.0), (18, 3.0)],
        chest=[(4, 5.0), (9, 9.0), (18, 6.0)],
        head=[(4, 10.0), (9, 12.0), (18, 10.0)],
        clav_r=[(4, (10.0, -6.0)), (9, (26.0, -14.0)), (12, (24.0, -12.0)), (18, (10.0, -6.0))],
        hand_r=[(4, (-0.1, 1.345, 0.17)), (8, (-0.05, 1.355, 0.4)), (9, (-0.04, 1.355, 0.48)), (10, (-0.04, 1.355, 0.48)),
                (12, (-0.05, 1.36, 0.42)), (18, MT_FIST_R)],
        face_r=[(4, "mt_guard"), (9, "mt_cross"), (10, "mt_cross"), (14, "mt_guard")],
        pole_r=[(4, (-0.25, -1.0, 0.3)), (9, (-0.65, -0.7, 0.2)), (12, (-0.5, -0.85, 0.25)), (18, (-0.25, -1.0, 0.3))],
        hand_l=[(4, (0.1, 1.365, 0.275)), (9, (0.07, 1.360, 0.36)), (18, MT_FIST_L)],
        heel_r=[(4, 10.0), (9, 34.0), (12, 30.0), (18, 14.0)],
        fyaw_r=[(4, 30.0), (9, 62.0), (12, 58.0), (18, 30.0)],
        knee_r=[(4, (-0.4, 0.0, 1.0)), (9, (-0.75, 0.0, 0.8)), (18, (-0.4, 0.0, 1.0))],
        heel_l=[(4, 2.0), (9, 0.0), (18, 2.0)],
    ),

    # ---------------------------------------------------------------- Shift + a direction: the step-and-slide (the game carries the body)
    # step in (footwork "step" and "ignite_step"): the lead foot steps ahead, the rear foot slides up after it; the guard
    # high, the hands with the body.  strike_s: the lead foot down
    "step_in": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                             move="footwork", mode="step", order=2, stills="push:3;lead foot down:7;rear foot slides up:11"),
        root=[(2, (0.0, -0.065, -0.02)), (5, (0.0, -0.065, 0.08)), (7, (0.0, -0.075, 0.16)), (11, (0.0, -0.07, 0.14)),
              (16, (0.0, -0.058, 0.04))],
        hips=[(5, 5.0), (11, 4.0)], chest=[(5, 7.0), (11, 6.0)],
        foot_l=[(2, MT_FOOT_L), (4, (0.15, 0.1, 0.31)), (6, (0.15, 0.09, 0.42)), (7, (0.15, 0.077, 0.44)),
                (11, (0.15, 0.077, 0.43)), (16, MT_FOOT_L)],
        heel_l=[(2, 2.0), (4, 0.0), (6, -6.0), (7, 0.0), (11, 2.0), (16, 2.0)],
        foot_r=[(7, MT_FOOT_R), (9, (-0.18, 0.09, -0.08)), (11, (-0.18, 0.08, 0.0)), (12, (-0.18, 0.077, 0.0)), (16, MT_FOOT_R)],
        heel_r=[(2, 20.0), (5, 32.0), (7, 28.0), (9, 26.0), (11, 16.0), (16, 14.0)],
        hand_l=[(2, (0.1, 1.395, 0.28)), (5, (0.1, 1.395, 0.38)), (7, (0.1, 1.385, 0.46)), (11, (0.1, 1.390, 0.44)), (16, (0.1, 1.405, 0.34))],
        hand_r=[(2, (-0.11, 1.375, 0.18)), (5, (-0.11, 1.375, 0.28)), (7, (-0.11, 1.365, 0.36)), (11, (-0.11, 1.370, 0.34)), (16, (-0.11, 1.385, 0.24))],
    ),
    # step back (footwork "back_flip"): the rear foot steps back, the lead foot slides back after it.  strike_s: the rear foot down
    "step_back": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                               move="footwork", mode="back_flip", order=3, stills="push:3;rear foot down:7;lead foot slides back:11"),
        root=[(2, (0.0, -0.065, 0.02)), (5, (0.0, -0.07, -0.08)), (7, (0.0, -0.095, -0.15)), (11, (0.0, -0.085, -0.13)),
              (16, (0.0, -0.058, -0.04))],
        foot_r=[(2, MT_FOOT_R), (4, (-0.18, 0.1, -0.3)), (6, (-0.18, 0.09, -0.41)), (7, (-0.18, 0.077, -0.43)),
                (11, (-0.18, 0.077, -0.42)), (16, MT_FOOT_R)],
        heel_r=[(2, 14.0), (4, 6.0), (6, 2.0), (7, 12.0), (11, 16.0), (16, 14.0)],
        foot_l=[(7, MT_FOOT_L), (9, (0.15, 0.09, 0.1)), (11, (0.15, 0.08, 0.0)), (12, (0.15, 0.077, 0.0)), (16, MT_FOOT_L)],
        heel_l=[(2, 10.0), (5, 20.0), (7, 10.0), (11, 3.0), (16, 2.0)],
        hand_l=[(2, (0.1, 1.395, 0.32)), (5, (0.1, 1.395, 0.22)), (7, (0.1, 1.385, 0.14)), (11, (0.1, 1.390, 0.16)), (16, (0.1, 1.405, 0.26))],
        hand_r=[(2, (-0.11, 1.375, 0.22)), (5, (-0.11, 1.375, 0.12)), (7, (-0.11, 1.365, 0.04)), (11, (-0.11, 1.370, 0.06)), (16, (-0.11, 1.385, 0.16))],
    ),
    # to the side (footwork "hop"): the lead foot first, out to the left, the rear foot slid after it.  strike_s: the lead foot down
    "step_side": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                               move="footwork", mode="hop", order=4, stills="push:3;lead foot down:7;rear foot slid after:11"),
        root=[(2, (-0.02, -0.065, 0.0)), (5, (0.07, -0.065, 0.0)), (7, (0.15, -0.075, 0.0)), (11, (0.13, -0.07, 0.0)),
              (16, (0.04, -0.058, 0.0))],
        roll=[(2, 2.0), (5, -2.0), (11, 0.0)],
        foot_l=[(2, MT_FOOT_L), (4, (0.26, 0.1, 0.2)), (6, (0.37, 0.09, 0.2)), (7, (0.4, 0.077, 0.2)), (11, (0.39, 0.077, 0.2)),
                (16, MT_FOOT_L)],
        heel_l=[(2, 2.0), (4, 0.0), (6, -6.0), (7, 0.0), (11, 2.0), (16, 2.0)],
        foot_r=[(7, MT_FOOT_R), (9, (-0.1, 0.09, -0.19)), (11, (-0.02, 0.08, -0.19)), (12, (-0.02, 0.077, -0.19)), (16, MT_FOOT_R)],
        heel_r=[(2, 20.0), (5, 30.0), (7, 26.0), (11, 16.0), (16, 14.0)],
        hand_l=[(2, (0.08, 1.395, 0.3)), (5, (0.17, 1.395, 0.3)), (7, (0.25, 1.385, 0.3)), (11, (0.23, 1.390, 0.3)), (16, (0.14, 1.405, 0.3))],
        hand_r=[(2, (-0.13, 1.375, 0.2)), (5, (-0.04, 1.375, 0.2)), (7, (0.04, 1.365, 0.2)), (11, (0.02, 1.370, 0.2)), (16, (-0.07, 1.385, 0.2))],
    ),
}

kit.main(STYLE, ELEMENT, CLIPS)
