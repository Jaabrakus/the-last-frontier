"""Judo for water: the style's own clips (the owner, 2026-10-16: "add the wrestling and judo"). The hip throw and the ankle
sweep come from the Motifect pack's judo clips (tools/anim_author/blender/motifect_clips.py jd_*); this file keys the rest:
the natural posture the throws leave and come back to, the grips (the jab string: a reach, a grab and a pull that
off-balances), the grip-and-turn (the Turn, E) and its held form, and the shuffle steps of the Shift movement. Every water
move keeps what it DOES; the style only changes how the body shows it, timed as water's own (BendPoses._timed_as).

Derived from tools/anim_author/blender/bend_clips.py through style_kit.py and from nothing else: key poses typed into
CLIPS, posed by bend_clips' solver (two-bone IK on Actor_B's own rig, assets/character/actor_b_body.glb) in Blender and
baked to the bones' local rotations as Godot has them, for tools/anim_author/install_style.gd. No library clip, no dumped
move and nothing from the Motifect pack is read here. Keyed from standard judo mechanics (shizentai, the natural posture;
kumi-kata, the grips; tsugi-ashi, the following step); no video looked at: a posture, a grip and a shuffle are plain
standing motions.

The clips (own-style-judo-<name> in animations_extra/Frontier_Style_Judo.res; the left foot a little ahead, the right
hand the sleeve hand and the left the lapel hand as a right-handed judoka's; the grip comes as mirrored twins):
  stance       water's idle while in the style: upright, the feet a shoulder's width apart, the knees soft, the hands
               held out ahead at chest height as if holding a jacket (the left high at the lapel, the right lower at the
               sleeve), the fingers half closed; a slow weight shift foot to foot, the hands riding it
  grip         the jab string's hits (the Splash): both hands shot forward to seize the jacket, then pulled down and
               across to the hip to break the balance; its twin the other way
  grip_turn    the Turn (E tapped): the seize and a sharp turn of the body behind it, the hands pulling across; then back
  grip_hold    the Turn held (E held): the grip kept, the arms out, a small working sway
  step_in, step_back, step_side   the Shift movement (water's Skate): tsugi-ashi: the near foot slides, the other follows,
               the feet never crossed, the hands kept up

Metas as style_boxing.py's. Channels as bend_clips.py's (+X the character's left, +Y up, +Z forward, metres; angles in
degrees); a channel a clip leaves out holds the stance's.

  Blender -b --factory-startup --python tools/anim_author/blender/style_judo.py -- --out <judo.json>
      [--clips stance,grip] [--fit] [--angles] [--points] [--quiet]
  (through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import style_kit as kit  # noqa: E402
import bend_clips as bc  # noqa: E402
from bend_clips import FACING, FPS, STAND  # noqa: E402

STYLE = "judo"
ELEMENT = "water"

kit.hands()

FACING.update({
    "jd_grip": ((0.0, 0.2, 0.98), (0.0, -0.98, 0.2)),         # a hand holding a jacket ahead: the fingers forward, the palm down
    "jd_pull": ((0.3, -0.5, 0.81), (0.0, -0.85, -0.5)),       # the pull: the hand drawn down and across, the palm down and back
})

## The natural posture: the hips turned 12 to the right, the left foot a little ahead, a shoulder's width apart, the knees
## soft, the back straight with a slight lean in, the hands ahead at chest height as on a jacket (the left high, the right
## low), the elbows down.
JD_FOOT_L = (0.17, 0.077, 0.1)
JD_FOOT_R = (-0.15, 0.077, -0.08)
JD_HAND_L = (0.1, 1.3, 0.4)
JD_HAND_R = (-0.14, 1.12, 0.38)
GUARD = {
    "root": (0.0, -0.06, 0.0), "yaw": -12.0, "twist": -3.0, "hips": 8.0, "roll": 0.0, "chest": 4.0, "side": 0.0,
    "head": 2.0, "look": 0.0, "clav_r": (8.0, 0.0), "clav_l": (10.0, -2.0),
    "hand_r": JD_HAND_R, "hand_l": JD_HAND_L, "face_r": "jd_grip", "face_l": "jd_grip",
    "pole_r": (-0.3, -1.0, 0.0), "pole_l": (0.3, -1.0, 0.0), "grip_r": 0.6, "grip_l": 0.6,
    "foot_r": JD_FOOT_R, "foot_l": JD_FOOT_L, "fyaw_r": 14.0, "fyaw_l": 2.0, "heel_r": 0.0, "heel_l": 0.0,
    "knee_r": (-0.3, 0.0, 1.0), "knee_l": (0.3, 0.0, 1.0),
}

META = {"mask": "full", "root": "place", "style": STYLE, "element": ELEMENT}
S = 1.0 / FPS

## The idle: a slow weight shift foot to foot once a loop (the root swaying, the body rolling a touch), the hands riding
## the body and working a little (the lapel hand lifting as the weight comes forward).
STANCE_LEN = 44


def stance_at(a):
    sway = kit.s_(a)
    fwd = 0.5 - 0.5 * kit.c_(a)
    root = (0.025 * sway, -0.06 - 0.006 * fwd, 0.015 * fwd)
    return {k: kit.r_(v) for k, v in {
        "root": root,
        "roll": 1.5 * sway, "hips": 8.0 + 1.0 * fwd, "chest": 4.0 + 1.0 * fwd,
        "yaw": -12.0 - 2.0 * sway,
        "hand_l": kit.add(JD_HAND_L, (root[0], root[1] + 0.06 + 0.012 * fwd, root[2] + 0.01 * fwd)),
        "hand_r": kit.add(JD_HAND_R, (root[0], root[1] + 0.06 - 0.008 * fwd, root[2] + 0.012 * fwd)),
        "heel_l": 4.0 * max(0.0, -sway), "heel_r": 4.0 * max(0.0, sway),
    }.items()}


BASE = dict(STAND)
BASE.update(GUARD)
BASE.update(stance_at(0.0))
clip = kit.clip_on(BASE, META)

## The grip held: the arms out on the jacket, the body a little lower and more turned, the elbows in.
HOLD = {
    "root": (0.0, -0.085, 0.03), "yaw": -20.0, "twist": -6.0, "hips": 12.0, "chest": 6.0, "head": 4.0,
    "hand_l": (0.06, 1.33, 0.55), "hand_r": (-0.12, 1.1, 0.52), "face_l": "jd_grip", "face_r": "jd_grip",
    "clav_l": (18.0, -6.0), "clav_r": (14.0, -2.0), "grip_l": 1.0, "grip_r": 1.0,
    "pole_l": (0.45, -0.9, 0.0), "pole_r": (-0.4, -0.9, 0.0),
}
HOLD_BASE = dict(BASE)
HOLD_BASE.update(HOLD)
HOLD_LEN = 36


def hold_at(a):
    sway = kit.s_(a)
    work = 0.5 - 0.5 * kit.c_(2 * a)
    root = kit.add(HOLD["root"], (0.015 * sway, -0.006 * work, 0.0))
    return {k: kit.r_(v) for k, v in {
        "root": root,
        "roll": 1.0 * sway, "yaw": -20.0 - 2.5 * sway,
        "hand_l": kit.add(HOLD["hand_l"], (0.015 * sway, -0.006 * work + 0.01 * sway, -0.012 * work)),
        "hand_r": kit.add(HOLD["hand_r"], (0.015 * sway, -0.006 * work - 0.008 * sway, -0.012 * work)),
    }.items()}


CLIPS = {
    # ---------------------------------------------------------------- the stance (water's stance while in judo)
    "stance": dict(bc._loop(STANCE_LEN, stance_at), length=STANCE_LEN, loop=True, base=BASE,
                   meta=dict(META, hand="both", move="stance", mode="stance", order=0)),

    # ---------------------------------------------------------------- the jab string: the grip and the pull (the Splash)
    # the hands shot forward to seize (the lapel hand high, the sleeve hand low), a half step in with the lead foot, then
    # the pull: both hands drawn down and across to the right hip, the body turning with it (the off-balance); back to the
    # posture.  strike_s: the seize
    "grip": clip(26, dict(hold_s=3 * S, strike_s=8 * S, back_s=15 * S, antic_s=3 * S, follow_s=13 * S, hand="both",
                          move="water_jet", mode="splash", order=1, stills="ready:3;seize:8;pull:13;posture:20"),
        root=[(3, (0.0, -0.065, -0.01)), (8, (0.0, -0.08, 0.07)), (13, (-0.03, -0.095, 0.03)), (20, (0.0, -0.06, 0.0))],
        yaw=[(3, -10.0), (8, -14.0), (13, -34.0), (20, -12.0)],
        twist=[(8, -4.0), (13, -12.0), (20, -3.0)],
        hips=[(3, 8.0), (8, 12.0), (13, 16.0), (20, 8.0)],
        chest=[(8, 7.0), (13, 9.0), (20, 4.0)],
        hand_l=[(3, (0.1, 1.28, 0.36)), (7, (0.07, 1.34, 0.55)), (8, (0.06, 1.35, 0.58)), (10, (0.06, 1.35, 0.57)),
                (13, (-0.1, 1.05, 0.33)), (15, (-0.12, 1.02, 0.3)), (20, JD_HAND_L)],
        face_l=[(3, "jd_grip"), (8, "jd_grip"), (10, "jd_grip"), (13, "jd_pull"), (16, "jd_pull"), (20, "jd_grip")],
        pole_l=[(3, (0.3, -1.0, 0.0)), (8, (0.5, -0.85, 0.0)), (13, (0.6, -0.7, -0.3)), (20, (0.3, -1.0, 0.0))],
        hand_r=[(3, (-0.14, 1.1, 0.34)), (7, (-0.14, 1.14, 0.52)), (8, (-0.14, 1.15, 0.56)), (10, (-0.14, 1.15, 0.55)),
                (13, (-0.26, 0.95, 0.28)), (15, (-0.27, 0.92, 0.25)), (20, JD_HAND_R)],
        face_r=[(3, "jd_grip"), (8, "jd_grip"), (10, "jd_grip"), (13, "jd_pull"), (16, "jd_pull"), (20, "jd_grip")],
        pole_r=[(3, (-0.3, -1.0, 0.0)), (8, (-0.5, -0.85, 0.0)), (13, (-0.7, -0.6, -0.2)), (20, (-0.3, -1.0, 0.0))],
        grip_l=[(5, 0.6), (8, 1.0), (16, 1.0), (20, 0.6)],
        grip_r=[(5, 0.6), (8, 1.0), (16, 1.0), (20, 0.6)],
        clav_l=[(8, (18.0, -8.0)), (13, (6.0, 4.0)), (20, (10.0, -2.0))],
        clav_r=[(8, (14.0, -4.0)), (13, (4.0, 6.0)), (20, (8.0, 0.0))],
        foot_l=[(3, JD_FOOT_L), (6, (0.17, 0.09, 0.2)), (8, (0.17, 0.077, 0.26)), (13, (0.17, 0.077, 0.25)), (18, JD_FOOT_L)],
        heel_l=[(3, 0.0), (6, 4.0), (8, 0.0), (18, 0.0)],
        heel_r=[(3, 0.0), (8, 10.0), (13, 14.0), (18, 0.0)],
        mirror=True,
    ),

    # ---------------------------------------------------------------- the Turn (E tapped): the grip and the turn
    # the seize, then the body turned sharply to the right behind it with the hands drawn across (the shot carried round);
    # then back.  strike_s: the turn (the guard's window)
    "grip_turn": clip(26, dict(hold_s=5 * S, strike_s=9 * S, back_s=15 * S, antic_s=5 * S, follow_s=13 * S, hand="both",
                               move="water_redirect", mode="redirect", order=2, stills="ready:3;seize:6;turn:9;posture:20"),
        root=[(3, (0.0, -0.065, -0.01)), (6, (0.0, -0.08, 0.05)), (9, (-0.04, -0.1, 0.02)), (13, (-0.04, -0.1, 0.02)), (20, (0.0, -0.06, 0.0))],
        yaw=[(3, -10.0), (6, -14.0), (9, -62.0), (13, -62.0), (20, -12.0)],
        twist=[(6, -4.0), (9, -16.0), (13, -16.0), (20, -3.0)],
        hips=[(6, 12.0), (9, 14.0), (13, 14.0), (20, 8.0)],
        hand_l=[(3, (0.1, 1.28, 0.36)), (6, (0.06, 1.34, 0.56)), (9, (-0.22, 1.22, 0.36)), (13, (-0.24, 1.2, 0.34)), (20, JD_HAND_L)],
        hand_r=[(3, (-0.14, 1.1, 0.34)), (6, (-0.14, 1.15, 0.54)), (9, (-0.36, 1.0, 0.16)), (13, (-0.38, 0.98, 0.14)), (20, JD_HAND_R)],
        face_l=[(3, "jd_grip"), (6, "jd_grip"), (9, "jd_pull"), (14, "jd_pull"), (20, "jd_grip")],
        face_r=[(3, "jd_grip"), (6, "jd_grip"), (9, "jd_pull"), (14, "jd_pull"), (20, "jd_grip")],
        pole_l=[(3, (0.3, -1.0, 0.0)), (6, (0.5, -0.85, 0.0)), (9, (0.3, -0.8, -0.5)), (14, (0.3, -0.8, -0.5)), (20, (0.3, -1.0, 0.0))],
        pole_r=[(3, (-0.3, -1.0, 0.0)), (6, (-0.5, -0.85, 0.0)), (9, (-0.7, -0.6, -0.3)), (14, (-0.7, -0.6, -0.3)), (20, (-0.3, -1.0, 0.0))],
        grip_l=[(4, 0.6), (6, 1.0), (15, 1.0), (20, 0.6)],
        grip_r=[(4, 0.6), (6, 1.0), (15, 1.0), (20, 0.6)],
        foot_r=[(5, JD_FOOT_R), (7, (-0.15, 0.09, -0.16)), (9, (-0.2, 0.077, -0.26)), (13, (-0.2, 0.077, -0.26)), (18, JD_FOOT_R)],
        fyaw_r=[(5, 14.0), (9, 50.0), (13, 50.0), (18, 14.0)],
        heel_l=[(5, 0.0), (9, 16.0), (13, 16.0), (18, 0.0)],
        fyaw_l=[(5, 2.0), (9, 30.0), (13, 30.0), (18, 2.0)],
    ),

    # ---------------------------------------------------------------- the Turn held (E held): the grip kept
    "grip_hold": dict(bc._loop(HOLD_LEN, hold_at), length=HOLD_LEN, loop=True, base=HOLD_BASE,
                      meta=dict(META, hand="both", move="water_redirect", mode="hold", order=3)),

    # ---------------------------------------------------------------- Shift + a direction: tsugi-ashi (the game carries the body)
    # in (flow "skate"): the lead foot slides ahead, the rear foot follows; the hands with the body
    "step_in": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                             move="flow", mode="skate", order=4, stills="push:3;lead foot down:7;rear foot follows:11"),
        root=[(2, (0.0, -0.065, -0.01)), (5, (0.0, -0.065, 0.08)), (7, (0.0, -0.075, 0.16)), (11, (0.0, -0.07, 0.14)),
              (16, (0.0, -0.06, 0.04))],
        foot_l=[(2, JD_FOOT_L), (4, (0.17, 0.09, 0.2)), (6, (0.17, 0.085, 0.3)), (7, (0.17, 0.077, 0.33)),
                (11, (0.17, 0.077, 0.32)), (16, JD_FOOT_L)],
        foot_r=[(7, JD_FOOT_R), (9, (-0.15, 0.085, 0.02)), (11, (-0.15, 0.08, 0.1)), (12, (-0.15, 0.077, 0.1)), (16, JD_FOOT_R)],
        heel_r=[(2, 0.0), (5, 12.0), (7, 10.0), (11, 4.0), (16, 0.0)],
        hand_l=[(2, (0.1, 1.295, 0.39)), (5, (0.1, 1.3, 0.48)), (7, (0.1, 1.29, 0.56)), (11, (0.1, 1.295, 0.54)), (16, (0.1, 1.3, 0.44))],
        hand_r=[(2, (-0.14, 1.115, 0.37)), (5, (-0.14, 1.12, 0.46)), (7, (-0.14, 1.11, 0.54)), (11, (-0.14, 1.115, 0.52)), (16, (-0.14, 1.12, 0.42))],
    ),
    # back (flow "water_skate" when backing): the rear foot slides back, the lead foot follows
    "step_back": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                               move="flow", mode="water_skate", order=5, stills="push:3;rear foot down:7;lead foot follows:11"),
        root=[(2, (0.0, -0.065, 0.01)), (5, (0.0, -0.065, -0.08)), (7, (0.0, -0.075, -0.16)), (11, (0.0, -0.07, -0.14)),
              (16, (0.0, -0.06, -0.04))],
        foot_r=[(2, JD_FOOT_R), (4, (-0.15, 0.09, -0.18)), (6, (-0.15, 0.085, -0.28)), (7, (-0.15, 0.077, -0.31)),
                (11, (-0.15, 0.077, -0.3)), (16, JD_FOOT_R)],
        foot_l=[(7, JD_FOOT_L), (9, (0.17, 0.085, 0.0)), (11, (0.17, 0.08, -0.08)), (12, (0.17, 0.077, -0.08)), (16, JD_FOOT_L)],
        heel_l=[(2, 0.0), (5, 12.0), (7, 8.0), (11, 2.0), (16, 0.0)],
        hand_l=[(2, (0.1, 1.295, 0.41)), (5, (0.1, 1.3, 0.32)), (7, (0.1, 1.29, 0.24)), (11, (0.1, 1.295, 0.26)), (16, (0.1, 1.3, 0.36))],
        hand_r=[(2, (-0.14, 1.115, 0.39)), (5, (-0.14, 1.12, 0.3)), (7, (-0.14, 1.11, 0.22)), (11, (-0.14, 1.115, 0.24)), (16, (-0.14, 1.12, 0.34))],
    ),
    # to the side: the left foot first, out to the left, the right foot slid after it
    "step_side": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                               move="flow", mode="surf", order=6, stills="push:3;left foot down:7;right foot slid after:11"),
        root=[(2, (-0.02, -0.065, 0.0)), (5, (0.07, -0.065, 0.0)), (7, (0.15, -0.075, 0.0)), (11, (0.13, -0.07, 0.0)),
              (16, (0.04, -0.06, 0.0))],
        roll=[(2, 1.5), (5, -1.5), (11, 0.0)],
        foot_l=[(2, JD_FOOT_L), (4, (0.27, 0.09, 0.1)), (6, (0.37, 0.085, 0.1)), (7, (0.4, 0.077, 0.1)), (11, (0.39, 0.077, 0.1)),
                (16, JD_FOOT_L)],
        foot_r=[(7, JD_FOOT_R), (9, (-0.07, 0.085, -0.08)), (11, (0.01, 0.08, -0.08)), (12, (0.01, 0.077, -0.08)), (16, JD_FOOT_R)],
        heel_r=[(2, 0.0), (5, 10.0), (7, 8.0), (11, 4.0), (16, 0.0)],
        hand_l=[(2, (0.08, 1.295, 0.4)), (5, (0.17, 1.3, 0.4)), (7, (0.25, 1.29, 0.4)), (11, (0.23, 1.295, 0.4)), (16, (0.14, 1.3, 0.4))],
        hand_r=[(2, (-0.16, 1.115, 0.38)), (5, (-0.07, 1.12, 0.38)), (7, (0.01, 1.11, 0.38)), (11, (-0.01, 1.115, 0.38)), (16, (-0.1, 1.12, 0.38))],
    ),
}

kit.main(STYLE, ELEMENT, CLIPS)
