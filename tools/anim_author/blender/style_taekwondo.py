"""Taekwondo for air: the style's own standing clips (the owner, 2026-10-16: "we need to create all these bending styles",
Taekwondo picked for air). The kicks themselves are the Motifect pack's Taekwondo clips (tools/anim_author/blender/
motifect_clips.py tkd_*: the snap kick, the jumping front kick, the side kick, the spinning heel kick, the axe kick); this
file keys only what the pack has no clip for: the fighting stance the kicks leave and come back to, and the lifted-knee
guard (docs/fighting_styles_design.md: "a lifted-knee wind guard"). Every air move keeps what it DOES; the style only
changes how the body shows it, timed as air's own (BendPoses._timed_as).

Derived from tools/anim_author/blender/bend_clips.py through style_kit.py and from nothing else: key poses typed into
CLIPS, posed by bend_clips' solver (two-bone IK on Actor_B's own rig, assets/character/actor_b_body.glb) in Blender and
baked to the bones' local rotations as Godot has them, for tools/anim_author/install_style.gd. No library clip, no dumped
move and nothing from the Motifect pack is read here. Keyed from standard Taekwondo sparring mechanics (the kyorugi stance),
no video looked at: a stance and a guard are plain standing poses, not the acrobatics that read badly without reference
(the Capoeira lesson, 2026-10-09).

The clips (own-style-taekwondo-<name> in animations_extra/Frontier_Style_Taekwondo.res; the left side leads, as the pack's
kicks lead; the kicks come as mirrored twins, the stance is one-sided like Boxing's):
  stance       air's idle while in the style: side-on, the left foot ahead and the rear foot turned out with its heel up,
               a long light stance on the balls of the feet, the knees soft, the fists loose (not a boxer's tight guard)
               with the lead hand out ahead at chest height and the rear hand by the solar plexus; the Taekwondo bounce,
               two a loop, the hands and shoulders riding it a beat late
  knee_guard   the Wind Guard (E tapped): the weight onto the rear leg, the lead knee snapped up to the hip (the foot
               hanging under it, the toes down) with the lead forearm raised across, then set down to the stance
  knee_hold    the guard held (E held): the knee up, a small settle and bob on the standing leg
  skip, skip_back, skip_side   the Shift movement (air's Slip, Shift + a direction; the game carries the body): the
               Taekwondo skip step: a low hop off the rear foot with both feet off the deck for a beat, the lead foot
               landing first and the rear foot closing up, the guard kept up; forward, back (the rear foot leads) and to
               the lead side (the pose is picked by the mode, not the direction held, as Boxing's steps are)

Metas as style_boxing.py's: hold_s, strike_s, back_s (seconds), antic_s and follow_s for the stills, hand, mask, root
("place"), style, element, move and mode. Channels as bend_clips.py's (+X the character's left, +Y up, +Z forward, metres;
angles in degrees); a channel a clip leaves out holds the stance's.

  Blender -b --factory-startup --python tools/anim_author/blender/style_taekwondo.py -- --out <taekwondo.json>
      [--clips stance,knee_guard] [--fit] [--angles] [--points] [--quiet]
  (through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import style_kit as kit  # noqa: E402
import bend_clips as bc  # noqa: E402
from bend_clips import FACING, FPS, STAND  # noqa: E402

STYLE = "taekwondo"
ELEMENT = "air"

kit.hands()

FACING.update({
    "tkd_guard": ((0.2, 0.9, 0.38), (0.95, -0.05, -0.3)),     # a loose fist up, the knuckles up, the palm in
    "tkd_lead": ((0.1, 0.55, 0.83), (0.95, 0.0, -0.3)),       # the lead fist carried out ahead, the knuckles forward and up
    "tkd_block": ((0.55, 0.8, 0.25), (0.3, 0.0, -0.95)),      # the forearm raised across, the fist up by the far shoulder
})

## The sparring stance: the hips turned 34 to the right (the left side leads), the shoulders 6 more; the left foot ahead
## pointing near the mark, the right foot back and out, turned out 52 with its heel up; the stance long (0.5 m) and light,
## the root a little down; the lead fist out ahead at chest height, the rear fist by the solar plexus, the elbows loose.
TKD_FOOT_L = (0.12, 0.077, 0.24)
TKD_FOOT_R = (-0.2, 0.077, -0.24)
TKD_FIST_L = (0.11, 1.2, 0.37)
TKD_FIST_R = (-0.1, 1.1, 0.14)
GUARD = {
    "root": (0.0, -0.045, 0.0), "yaw": -34.0, "twist": -6.0, "hips": 4.0, "roll": 0.0, "chest": 5.0, "side": 0.0,
    "head": 6.0, "look": 0.0, "clav_r": (4.0, -3.0), "clav_l": (8.0, -5.0),
    "hand_r": TKD_FIST_R, "hand_l": TKD_FIST_L, "face_r": "tkd_guard", "face_l": "tkd_lead",
    "pole_r": (-0.3, -1.0, -0.2), "pole_l": (0.3, -1.0, -0.05), "grip_r": 0.85, "grip_l": 0.85,
    "foot_r": TKD_FOOT_R, "foot_l": TKD_FOOT_L, "fyaw_r": 52.0, "fyaw_l": -6.0, "heel_r": 22.0, "heel_l": 5.0,
    "knee_r": (-0.5, 0.0, 1.0), "knee_l": (0.2, 0.0, 1.0),
}

META = {"mask": "full", "root": "place", "style": STYLE, "element": ELEMENT}
S = 1.0 / FPS

## The bounce: two a loop on the balls of the feet (the Taekwondo bounce is higher and lighter than a boxer's: 4 cm), the
## heels riding up with it, the weight rocking onto the lead foot and back once a loop, the shoulders and the fists a beat
## late, the lead fist drifting a small circle.
STANCE_LEN = 32


def stance_at(a):
    up = abs(kit.s_(a))                       # 1 up on the balls of the feet, 0 down (two a loop)
    late = 0.5 - 0.5 * kit.c_(2 * a, -0.8)    # the shoulders and the fists a beat after the body
    rock = kit.s_(a)                          # + the weight forward onto the lead foot
    return {k: kit.r_(v) for k, v in {
        "root": (0.0, -0.066 + 0.034 * up, 0.018 * rock),
        "hips": 4.0 - 1.5 * up + 1.2 * rock, "chest": 5.0 + 1.5 * late, "head": 6.0 - 1.0 * late,
        "yaw": -34.0 + 1.5 * rock, "twist": -6.0 - 1.5 * rock,
        "clav_r": (4.0, -3.0 - 2.0 * late), "clav_l": (8.0, -5.0 - 2.0 * late),
        # (the fists ride the bounce and the rock with the body, a beat late, the lead fist drifting a small circle)
        "hand_r": kit.add(TKD_FIST_R, (0.0, 0.034 * up - 0.012 * late, 0.018 * rock)),
        "hand_l": kit.add(TKD_FIST_L, (0.02 * kit.c_(a), 0.034 * up - 0.014 * late + 0.01 * kit.s_(a), 0.018 * rock + 0.015 * kit.s_(a, 0.6))),
        "heel_r": 16.0 + 18.0 * up - 4.0 * rock, "heel_l": 2.0 + 16.0 * up + 3.0 * rock,
    }.items()}


BASE = dict(STAND)
BASE.update(GUARD)
BASE.update(stance_at(0.0))
clip = kit.clip_on(BASE, META)

## The lifted knee: the weight back onto the rear leg (the root back and down a touch, the rear knee softer), the lead
## foot drawn up under the hip to knee height, the toes pointed down, the knee out ahead; the lead forearm raised across the
## body, the rear fist up by the chin, the chin tucked.
KNEE_UP = {
    "root": (-0.015, -0.085, -0.035), "yaw": -38.0, "twist": -8.0, "hips": 3.0, "chest": 7.0, "side": 2.0, "head": 8.0,
    "foot_l": (0.1, 0.56, 0.2), "fyaw_l": -6.0, "heel_l": 28.0, "knee_l": (0.25, 0.3, 1.0),
    "heel_r": 8.0, "knee_r": (-0.6, 0.0, 1.0),
    "hand_l": (-0.015, 1.34, 0.265), "face_l": "tkd_block", "pole_l": (0.6, -0.7, -0.15),
    "hand_r": (-0.105, 1.22, 0.135), "face_r": "tkd_guard", "clav_l": (14.0, -8.0), "clav_r": (6.0, -2.0),
    "grip_l": 1.0, "grip_r": 1.0,
}
KNEE = dict(BASE)
KNEE.update(KNEE_UP)
KNEE_LEN = 30


def knee_hold_at(a):
    bob = 0.5 - 0.5 * kit.c_(2 * a)           # a small settle on the standing leg, twice a loop
    sway = kit.s_(a)
    return {k: kit.r_(v) for k, v in {
        "root": kit.add(KNEE_UP["root"], (0.004 * sway, -0.008 * bob, 0.0)),
        "foot_l": kit.add(KNEE_UP["foot_l"], (0.006 * sway, -0.012 * bob, 0.008 * sway)),
        "heel_l": 28.0 + 4.0 * bob, "chest": 7.0 + 1.0 * bob, "head": 8.0 - 0.8 * bob,
        "hand_l": kit.add(KNEE_UP["hand_l"], (0.004 * sway + 0.004 * sway, -0.008 * bob - 0.004 * bob, 0.0)),
        "hand_r": kit.add(KNEE_UP["hand_r"], (0.004 * sway, -0.008 * bob - 0.003 * bob, 0.004 * sway)),
    }.items()}


CLIPS = {
    # ---------------------------------------------------------------- the stance (air's stance while in Taekwondo)
    "stance": dict(bc._loop(STANCE_LEN, stance_at), length=STANCE_LEN, loop=True, base=BASE,
                   meta=dict(META, hand="both", move="stance", mode="stance", order=0)),

    # ---------------------------------------------------------------- the Wind Guard (E tapped): the lifted knee
    # strike_s: the knee up and the forearm across (the guard's window); back_s: the foot set down
    "knee_guard": clip(24, dict(hold_s=7 * S, strike_s=8 * S, back_s=15 * S, antic_s=4 * S, follow_s=15 * S, hand="both",
                                move="air_shield", mode="shield", order=1, stills="ready:4;knee up:8;held:13;set down:19"),
        root=[(4, (-0.01, -0.07, -0.02)), (8, KNEE_UP["root"]), (14, KNEE_UP["root"]), (19, (-0.005, -0.07, -0.01))],
        yaw=[(4, -36.0), (8, -38.0), (14, -38.0), (20, -35.0)],
        twist=[(8, -8.0), (14, -8.0)],
        hips=[(4, 2.0), (8, 3.0), (14, 3.0)],
        chest=[(8, 7.0), (14, 7.0)],
        side=[(8, 2.0), (14, 2.0)],
        head=[(8, 8.0), (14, 8.0)],
        foot_l=[(4, (0.11, 0.12, 0.24)), (8, KNEE_UP["foot_l"]), (14, KNEE_UP["foot_l"]), (18, (0.1, 0.14, 0.26)),
                (20, TKD_FOOT_L)],
        fyaw_l=[(8, -6.0), (14, -6.0)],
        heel_l=[(4, 18.0), (8, 28.0), (14, 28.0), (18, 10.0), (20, 5.0)],
        knee_l=[(4, (0.25, 0.3, 1.0)), (14, (0.25, 0.3, 1.0)), (18, (0.2, 0.1, 1.0)), (20, (0.2, 0.0, 1.0))],
        heel_r=[(4, 8.0), (14, 8.0), (20, 16.0)],
        knee_r=[(4, (-0.6, 0.0, 1.0)), (14, (-0.6, 0.0, 1.0)), (20, (-0.5, 0.0, 1.0))],
        hand_l=[(4, (0.05, 1.255, 0.3)), (8, KNEE_UP["hand_l"]), (14, KNEE_UP["hand_l"]), (20, TKD_FIST_L)],
        face_l=[(4, "tkd_lead"), (8, "tkd_block"), (14, "tkd_block"), (18, "tkd_lead")],
        pole_l=[(4, (0.4, -0.9, -0.1)), (8, (0.6, -0.7, -0.15)), (14, (0.6, -0.7, -0.15)), (20, (0.3, -1.0, -0.05))],
        hand_r=[(8, KNEE_UP["hand_r"]), (14, KNEE_UP["hand_r"])],
        clav_l=[(8, (14.0, -8.0)), (14, (14.0, -8.0))],
        clav_r=[(8, (6.0, -2.0)), (14, (6.0, -2.0))],
        grip_l=[(6, 1.0), (16, 1.0)],
        grip_r=[(6, 1.0), (16, 1.0)],
    ),

    # ---------------------------------------------------------------- the guard held (E held): the knee up, a settle
    "knee_hold": dict(bc._loop(KNEE_LEN, knee_hold_at), length=KNEE_LEN, loop=True, base=KNEE,
                      meta=dict(META, hand="both", move="air_shield", mode="hold", order=2)),

    # ---------------------------------------------------------------- Shift + a direction: the skip step (the game carries the body)
    # forward (evade "slip"): the load onto the rear leg, the push, both feet off the deck for a beat with the lead knee a
    # touch up, the lead foot down ahead, the rear foot closing up to the stance's length.  strike_s: the lead foot down
    "skip": clip(24, dict(hold_s=3 * S, strike_s=8 * S, back_s=14 * S, antic_s=3 * S, follow_s=12 * S, hand="both",
                          move="evade", mode="slip", order=3, stills="load:3;off the deck:6;lead foot down:8;closed up:12"),
        root=[(3, (0.0, -0.085, -0.03)), (6, (0.0, -0.045, 0.1)), (8, (0.0, -0.1, 0.21)), (12, (0.0, -0.085, 0.19)),
              (18, (0.0, -0.066, 0.05))],
        hips=[(3, 6.0), (8, 8.0), (12, 6.0)], chest=[(3, 7.0), (8, 9.0), (12, 7.0)],
        foot_l=[(3, TKD_FOOT_L), (5, (0.12, 0.13, 0.34)), (6, (0.12, 0.15, 0.41)), (8, (0.12, 0.077, 0.48)),
                (12, (0.12, 0.077, 0.47)), (18, TKD_FOOT_L)],
        heel_l=[(3, 10.0), (6, 2.0), (8, 0.0), (12, 4.0), (18, 5.0)],
        knee_l=[(3, (0.2, 0.0, 1.0)), (6, (0.2, 0.25, 1.0)), (8, (0.2, 0.0, 1.0))],
        foot_r=[(3, TKD_FOOT_R), (5, (-0.2, 0.1, -0.2)), (6, (-0.2, 0.13, -0.1)), (8, (-0.2, 0.11, -0.04)),
                (10, (-0.2, 0.077, 0.0)), (12, (-0.2, 0.077, 0.0)), (18, TKD_FOOT_R)],
        heel_r=[(3, 34.0), (6, 30.0), (10, 24.0), (12, 22.0), (18, 22.0)],
        hand_l=[(3, (0.11, 1.18, 0.34)), (6, (0.12, 1.23, 0.48)), (8, (0.11, 1.17, 0.59)), (12, (0.11, 1.185, 0.565)),
                (18, (0.11, 1.2, 0.42))],
        hand_r=[(3, (-0.1, 1.08, 0.11)), (6, (-0.1, 1.125, 0.25)), (8, (-0.1, 1.07, 0.35)), (12, (-0.1, 1.085, 0.33)),
                (18, (-0.1, 1.1, 0.19))],
    ),
    # back (evade "backstep", and the Slip with nothing held): the lead foot pushes off its ball, the rear foot reaches back
    # and lands, the lead foot drawn back after it.  strike_s: the rear foot down
    "skip_back": clip(24, dict(hold_s=3 * S, strike_s=8 * S, back_s=14 * S, antic_s=3 * S, follow_s=12 * S, hand="both",
                               move="evade", mode="backstep", order=4, stills="load:3;off the deck:6;rear foot down:8;closed up:12"),
        root=[(3, (0.0, -0.085, 0.03)), (6, (0.0, -0.04, -0.09)), (8, (0.0, -0.09, -0.17)), (12, (0.0, -0.075, -0.15)),
              (18, (0.0, -0.062, -0.05))],
        hips=[(3, 2.0), (8, 1.0), (12, 3.0)], chest=[(3, 3.0), (8, 2.0), (12, 4.0)],
        foot_r=[(3, TKD_FOOT_R), (5, (-0.2, 0.13, -0.34)), (6, (-0.2, 0.15, -0.42)), (8, (-0.2, 0.077, -0.52)),
                (12, (-0.2, 0.077, -0.51)), (18, TKD_FOOT_R)],
        heel_r=[(3, 30.0), (6, 12.0), (8, 20.0), (12, 24.0), (18, 22.0)],
        foot_l=[(3, TKD_FOOT_L), (5, (0.12, 0.1, 0.22)), (6, (0.12, 0.13, 0.12)), (8, (0.12, 0.11, 0.04)),
                (10, (0.12, 0.077, 0.0)), (12, (0.12, 0.077, 0.0)), (18, TKD_FOOT_L)],
        heel_l=[(3, 18.0), (6, 10.0), (10, 6.0), (12, 5.0)],
        hand_l=[(3, (0.11, 1.18, 0.4)), (6, (0.11, 1.225, 0.28)), (8, (0.11, 1.17, 0.2)), (12, (0.11, 1.185, 0.22)),
                (18, (0.11, 1.2, 0.32))],
        hand_r=[(3, (-0.1, 1.08, 0.17)), (6, (-0.1, 1.125, 0.05)), (8, (-0.1, 1.07, -0.03)), (12, (-0.1, 1.085, -0.01)),
                (18, (-0.1, 1.1, 0.09))],
    ),
    # to the side (evade "sidestep"): the lead foot first, out to the left, the rear foot drawn after it (the feet never
    # crossed).  strike_s: the lead foot down
    "skip_side": clip(24, dict(hold_s=3 * S, strike_s=8 * S, back_s=14 * S, antic_s=3 * S, follow_s=12 * S, hand="both",
                               move="evade", mode="sidestep", order=5, stills="load:3;off the deck:6;lead foot down:8;closed up:12"),
        root=[(3, (-0.02, -0.085, 0.0)), (6, (0.07, -0.04, 0.0)), (8, (0.15, -0.09, 0.0)), (12, (0.13, -0.075, 0.0)),
              (18, (0.05, -0.062, 0.0))],
        roll=[(3, 2.5), (6, -2.5), (12, 0.0)],
        foot_l=[(3, TKD_FOOT_L), (5, (0.24, 0.13, 0.26)), (6, (0.33, 0.15, 0.26)), (8, (0.44, 0.077, 0.26)),
                (12, (0.43, 0.077, 0.26)), (18, TKD_FOOT_L)],
        heel_l=[(3, 10.0), (6, 2.0), (8, 0.0), (12, 4.0), (18, 5.0)],
        foot_r=[(3, TKD_FOOT_R), (5, (-0.18, 0.1, -0.24)), (6, (-0.12, 0.13, -0.24)), (8, (-0.04, 0.11, -0.24)),
                (10, (0.02, 0.077, -0.24)), (12, (0.02, 0.077, -0.24)), (18, TKD_FOOT_R)],
        heel_r=[(3, 34.0), (6, 30.0), (10, 24.0), (12, 22.0)],
        hand_l=[(3, (0.09, 1.18, 0.37)), (6, (0.18, 1.225, 0.37)), (8, (0.26, 1.17, 0.37)), (12, (0.24, 1.185, 0.37)),
                (18, (0.16, 1.2, 0.37))],
        hand_r=[(3, (-0.12, 1.08, 0.14)), (6, (-0.03, 1.125, 0.14)), (8, (0.05, 1.07, 0.14)), (12, (0.03, 1.085, 0.14)),
                (18, (-0.05, 1.1, 0.14))],
    ),
}

kit.main(STYLE, ELEMENT, CLIPS)
