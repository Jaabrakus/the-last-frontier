"""Wrestling for earth: the style's own clips (the owner, 2026-10-16: "add the wrestling and judo"). The shots, the lift and
the sprawl come from the Motifect pack's wrestling clips (tools/anim_author/blender/motifect_clips.py wr_*); this file keys
what the pack has no standing clip for (its "guard position" lies on the mat): the low stance the shots leave and come back
to, and the shuffle steps of the Shift movement. Every earth move keeps what it DOES; the style only changes how the body
shows it, timed as earth's own (BendPoses._timed_as).

Derived from tools/anim_author/blender/bend_clips.py through style_kit.py and from nothing else: key poses typed into
CLIPS, posed by bend_clips' solver (two-bone IK on Actor_B's own rig, assets/character/actor_b_body.glb) in Blender and
baked to the bones' local rotations as Godot has them, for tools/anim_author/install_style.gd. No library clip, no dumped
move and nothing from the Motifect pack is read here. Keyed from standard wrestling mechanics (the low square stance, the
hands out ahead, the penetration step); no video looked at: a stance and a shuffle are plain standing motions.

The clips (own-style-wrestling-<name> in animations_extra/Frontier_Style_Wrestling.res; nearly square, the left foot a
touch ahead):
  stance       earth's idle while in the style: a low wide crouch, the knees bent deep, the back flat and leaning in,
               the head up, the hands open and low out ahead (the elbows in), the weight shifting foot to foot with a
               small bob; the hands ride the body
  step_in, step_back, step_side   the Shift movement (earth's Burrow / Skate / Slide; the game carries the body): the
               penetration shuffle, low: the near foot steps, the other slides up after it, the level kept low

Metas as style_boxing.py's. Channels as bend_clips.py's (+X the character's left, +Y up, +Z forward, metres; angles in
degrees); a channel a clip leaves out holds the stance's.

  Blender -b --factory-startup --python tools/anim_author/blender/style_wrestling.py -- --out <wrestling.json>
      [--clips stance] [--fit] [--angles] [--points] [--quiet]
  (through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import style_kit as kit  # noqa: E402
import bend_clips as bc  # noqa: E402
from bend_clips import FACING, FPS, STAND  # noqa: E402

STYLE = "wrestling"
ELEMENT = "earth"

kit.hands()

FACING.update({
    "wr_open": ((-0.15, 0.35, 0.92), (0.0, -0.95, 0.3)),      # an open hand out ahead, the fingers forward and a little up, the palm down
})

## The stance: nearly square (the hips turned 10 to the right, the left foot a touch ahead), the feet wide and the knees
## bent deep (the root well down), the back flat and leaning in, the head up to look at the foe; the open hands low out
## ahead at hip height, the elbows in.
WR_FOOT_L = (0.24, 0.077, 0.12)
WR_FOOT_R = (-0.22, 0.077, -0.1)
WR_HAND_L = (0.2, 0.86, 0.5)
WR_HAND_R = (-0.17, 0.84, 0.46)
GUARD = {
    "root": (0.0, -0.21, 0.02), "yaw": -10.0, "twist": -3.0, "hips": 26.0, "roll": 0.0, "chest": 6.0, "side": 0.0,
    "head": -14.0, "look": 0.0, "clav_r": (10.0, 2.0), "clav_l": (10.0, 2.0),
    "hand_r": WR_HAND_R, "hand_l": WR_HAND_L, "face_r": "wr_open", "face_l": "wr_open",
    "pole_r": (-0.35, -0.9, -0.2), "pole_l": (0.35, -0.9, -0.2), "grip_r": 0.3, "grip_l": 0.3,
    "foot_r": WR_FOOT_R, "foot_l": WR_FOOT_L, "fyaw_r": 12.0, "fyaw_l": -2.0, "heel_r": 6.0, "heel_l": 4.0,
    "knee_r": (-0.45, 0.0, 1.0), "knee_l": (0.45, 0.0, 1.0),
}

META = {"mask": "full", "root": "place", "style": STYLE, "element": ELEMENT}
S = 1.0 / FPS

## The idle: the weight shifting foot to foot once a loop (the root swaying, the body rolling with it), a small bob
## twice a loop, the hands riding the body and reaching a touch with the shift.
STANCE_LEN = 40


def stance_at(a):
    sway = kit.s_(a)                           # + the weight onto the left foot
    bob = 0.5 - 0.5 * kit.c_(2 * a)
    root = (0.03 * sway, -0.21 - 0.012 * bob, 0.02 + 0.01 * bob)
    return {k: kit.r_(v) for k, v in {
        "root": root,
        "roll": 2.5 * sway, "hips": 26.0 + 1.5 * bob, "chest": 6.0 + 1.0 * bob, "head": -14.0 - 1.0 * bob,
        "yaw": -10.0 - 3.0 * sway,
        "hand_r": kit.add(WR_HAND_R, (root[0] - 0.01 * sway, root[1] + 0.21 + 0.015 * bob, root[2] - 0.02 + 0.015 * sway)),
        "hand_l": kit.add(WR_HAND_L, (root[0] + 0.01 * sway, root[1] + 0.21 + 0.012 * bob, root[2] - 0.02 - 0.015 * sway)),
        "heel_l": 4.0 + 6.0 * max(0.0, -sway), "heel_r": 6.0 + 6.0 * max(0.0, sway),
    }.items()}


BASE = dict(STAND)
BASE.update(GUARD)
BASE.update(stance_at(0.0))
clip = kit.clip_on(BASE, META)

CLIPS = {
    # ---------------------------------------------------------------- the stance (earth's stance while wrestling)
    "stance": dict(bc._loop(STANCE_LEN, stance_at), length=STANCE_LEN, loop=True, base=BASE,
                   meta=dict(META, hand="both", move="stance", mode="stance", order=0)),

    # ---------------------------------------------------------------- Shift + a direction: the shuffle, low (the game carries the body)
    # in (earth_skate "burrow" and "skate"): the lead foot steps ahead low, the rear foot slides up; the hands with the body
    "step_in": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                             move="earth_skate", mode="burrow", order=1, stills="push:3;lead foot down:7;rear foot slides up:11"),
        root=[(2, (0.0, -0.215, 0.0)), (5, (0.0, -0.21, 0.1)), (7, (0.0, -0.225, 0.18)), (11, (0.0, -0.22, 0.16)),
              (16, (0.0, -0.21, 0.06))],
        foot_l=[(2, WR_FOOT_L), (4, (0.24, 0.1, 0.24)), (6, (0.24, 0.09, 0.36)), (7, (0.24, 0.077, 0.38)),
                (11, (0.24, 0.077, 0.37)), (16, WR_FOOT_L)],
        heel_l=[(2, 4.0), (4, 0.0), (6, -4.0), (7, 0.0), (16, 4.0)],
        foot_r=[(7, WR_FOOT_R), (9, (-0.22, 0.09, 0.0)), (11, (-0.22, 0.08, 0.08)), (12, (-0.22, 0.077, 0.08)), (16, WR_FOOT_R)],
        heel_r=[(2, 6.0), (5, 18.0), (7, 16.0), (11, 8.0), (16, 6.0)],
        hand_l=[(2, (0.2, 0.855, 0.48)), (5, (0.2, 0.86, 0.6)), (7, (0.2, 0.845, 0.68)), (11, (0.2, 0.85, 0.66)), (16, (0.2, 0.86, 0.56))],
        hand_r=[(2, (-0.17, 0.835, 0.44)), (5, (-0.17, 0.84, 0.56)), (7, (-0.17, 0.825, 0.64)), (11, (-0.17, 0.83, 0.62)), (16, (-0.17, 0.84, 0.52))],
    ),
    # back (earth_skate "slide" when backing): the rear foot steps back low, the lead foot slides back after it
    "step_back": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                               move="earth_skate", mode="skate", order=2, stills="push:3;rear foot down:7;lead foot slides back:11"),
        root=[(2, (0.0, -0.215, 0.04)), (5, (0.0, -0.21, -0.06)), (7, (0.0, -0.225, -0.14)), (11, (0.0, -0.22, -0.12)),
              (16, (0.0, -0.21, -0.02))],
        foot_r=[(2, WR_FOOT_R), (4, (-0.22, 0.1, -0.22)), (6, (-0.22, 0.09, -0.32)), (7, (-0.22, 0.077, -0.34)),
                (11, (-0.22, 0.077, -0.33)), (16, WR_FOOT_R)],
        heel_r=[(2, 6.0), (4, 2.0), (6, 0.0), (7, 8.0), (11, 10.0), (16, 6.0)],
        foot_l=[(7, WR_FOOT_L), (9, (0.24, 0.09, 0.04)), (11, (0.24, 0.08, -0.06)), (12, (0.24, 0.077, -0.06)), (16, WR_FOOT_L)],
        heel_l=[(2, 8.0), (5, 16.0), (7, 8.0), (11, 4.0), (16, 4.0)],
        hand_l=[(2, (0.2, 0.855, 0.52)), (5, (0.2, 0.86, 0.44)), (7, (0.2, 0.845, 0.36)), (11, (0.2, 0.85, 0.38)), (16, (0.2, 0.86, 0.48))],
        hand_r=[(2, (-0.17, 0.835, 0.48)), (5, (-0.17, 0.84, 0.4)), (7, (-0.17, 0.825, 0.32)), (11, (-0.17, 0.83, 0.34)), (16, (-0.17, 0.84, 0.44))],
    ),
    # to the side (earth_skate "slide"): the left foot first, out to the left, the right foot slid after it
    "step_side": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                               move="earth_skate", mode="slide", order=3, stills="push:3;left foot down:7;right foot slid after:11"),
        root=[(2, (-0.02, -0.215, 0.02)), (5, (0.08, -0.21, 0.02)), (7, (0.17, -0.225, 0.02)), (11, (0.15, -0.22, 0.02)),
              (16, (0.05, -0.21, 0.02))],
        roll=[(2, 2.0), (5, -2.0), (11, 0.0)],
        foot_l=[(2, WR_FOOT_L), (4, (0.36, 0.1, 0.12)), (6, (0.47, 0.09, 0.12)), (7, (0.5, 0.077, 0.12)), (11, (0.49, 0.077, 0.12)),
                (16, WR_FOOT_L)],
        heel_l=[(2, 4.0), (4, 0.0), (6, -4.0), (7, 0.0), (16, 4.0)],
        foot_r=[(7, WR_FOOT_R), (9, (-0.12, 0.09, -0.1)), (11, (-0.02, 0.08, -0.1)), (12, (-0.02, 0.077, -0.1)), (16, WR_FOOT_R)],
        heel_r=[(2, 6.0), (5, 16.0), (7, 12.0), (11, 8.0), (16, 6.0)],
        hand_l=[(2, (0.18, 0.855, 0.5)), (5, (0.28, 0.86, 0.5)), (7, (0.37, 0.845, 0.5)), (11, (0.35, 0.85, 0.5)), (16, (0.25, 0.86, 0.5))],
        hand_r=[(2, (-0.19, 0.835, 0.46)), (5, (-0.09, 0.84, 0.46)), (7, (0.0, 0.825, 0.46)), (11, (-0.02, 0.83, 0.46)), (16, (-0.12, 0.84, 0.46))],
    ),
}

kit.main(STYLE, ELEMENT, CLIPS)
