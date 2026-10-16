"""Karate for earth: the style's own clips (the owner, 2026-10-16, after parking Wrestling: Karate for earth). Karate has no
motion in the Motifect pack, so every clip here is keyed by hand, as Boxing's were: the stance, the snapping lead punch and
the reverse punch of the jab string, the stepping lunge punch that drives the Spike, the double palm-heel thrust of the Push,
the sharp block of the Catch, and the sliding steps of the Shift movement. Every earth move keeps what it DOES; the style
only changes how the body shows it, timed as earth's own (BendPoses._timed_as).

Derived from tools/anim_author/blender/bend_clips.py through style_kit.py and from nothing else: key poses typed into
CLIPS, posed by bend_clips' solver (two-bone IK on Actor_B's own rig, assets/character/actor_b_body.glb) in Blender and
baked to the bones' local rotations as Godot has them, for tools/anim_author/install_style.gd. No library clip and no
dumped move is read. Keyed from standard karate mechanics (the long front stance, hikite: the other fist chambered at the
hip, kime: the stop at the strike; kizami-zuki, gyaku-zuki, oi-zuki, teisho, gedan barai, yori-ashi); no video looked at:
straight strikes and steps are plain standing motions, not the acrobatics that read badly without reference.

The clips (own-style-karate-<name> in animations_extra/Frontier_Style_Karate.res; the left side leads; the lunge punch and
the palm thrust come as mirrored twins for the moves that have an alt):
  stance       earth's idle in the style: a long, deep front stance turned 30 from the mark, the feet flat, the lead fist
               out at chest height on the line, the rear fist chambered at the hip; a light settle, the hands with the body
  jab          the Pebbles: kizami-zuki, the lead fist snapped straight out and back, the hips barely moving
  reverse      the Pop: gyaku-zuki, the rear fist driven from the hip as the hips turn through, the lead fist pulled
               back to its hip (hikite), a stop at the strike (kime), flat and far
  lunge        the Spike: oi-zuki, a full step through with the rear foot and the same side's fist driven out as it lands;
               the step taken back after
  palm_thrust  the Push: a double teisho, both palm heels driven out from the chambers off a deep lunge
  block        the Catch: gedan barai, the lead arm whipped down and across from high, the hips turned with it
  step_in, step_back, step_side   the Shift movement (earth's Burrow / Skate / Slide): yori-ashi, the stance slid as one:
               the near foot first, the other drawn after, the depth kept

Metas as style_boxing.py's. Channels as bend_clips.py's (+X the character's left, +Y up, +Z forward, metres; angles in
degrees); a channel a clip leaves out holds the stance's.

  Blender -b --factory-startup --python tools/anim_author/blender/style_karate.py -- --out <karate.json>
      [--clips stance,jab] [--fit] [--angles] [--points] [--quiet]
  (through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import style_kit as kit  # noqa: E402
import bend_clips as bc  # noqa: E402
from bend_clips import FACING, FPS, STAND  # noqa: E402

STYLE = "karate"
ELEMENT = "earth"

kit.hands()

FACING.update({
    "kr_fist": ((0.0, 0.1, 0.99), (0.0, -1.0, 0.1)),           # a straight punch landing: the knuckles forward, the fist turned palm down
    "kr_lead": ((0.1, 0.3, 0.95), (0.0, -0.95, 0.3)),          # the lead fist held out on the line, the knuckles forward and a little up
    "kr_block_hi": ((0.5, 0.85, 0.15), (0.85, -0.5, 0.0)),     # the block's fist cocked high by the far shoulder, the palm in
    "kr_block_lo": ((0.3, -0.85, 0.45), (0.95, 0.3, 0.0)),     # the block's fist swept down and out, the knuckles down and forward
})

## The stance: turned 30 to the right (the left side leads), long and deep (0.58 m between the feet, the root well down),
## the feet flat, the lead foot pointing at the mark and the rear foot turned out 45; the lead fist out at chest height on
## the line, the rear fist chambered palm-up at the hip; the back straight, the chin level.
KR_FOOT_L = (0.14, 0.077, 0.3)
KR_FOOT_R = (-0.2, 0.077, -0.28)
KR_FIST_L = (0.08, 1.2, 0.44)
KR_FIST_R = (-0.2, 0.96, 0.02)
GUARD = {
    "root": (0.0, -0.105, 0.01), "yaw": -30.0, "twist": -5.0, "hips": 4.0, "roll": 0.0, "chest": 3.0, "side": 0.0,
    "head": 6.0, "look": 0.0, "clav_r": (2.0, 4.0), "clav_l": (10.0, -4.0),
    "hand_r": KR_FIST_R, "hand_l": KR_FIST_L, "face_r": "chamber", "face_l": "kr_lead",
    "pole_r": (-0.6, -0.8, -0.3), "pole_l": (0.35, -1.0, -0.1), "grip_r": 1.0, "grip_l": 1.0,
    "foot_r": KR_FOOT_R, "foot_l": KR_FOOT_L, "fyaw_r": 45.0, "fyaw_l": -2.0, "heel_r": 0.0, "heel_l": 0.0,
    "knee_r": (-0.5, 0.0, 1.0), "knee_l": (0.25, 0.0, 1.0),
}

META = {"mask": "full", "root": "place", "style": STYLE, "element": ELEMENT}
S = 1.0 / FPS

## The idle: a light settle (the root easing down and up once a loop), the weight easing onto the lead foot and back, the
## lead fist breathing out and in a finger's width, the hands riding the body.
STANCE_LEN = 44


def stance_at(a):
    settle = 0.5 - 0.5 * kit.c_(a)             # 1 settled down
    rock = kit.s_(a)                           # + the weight onto the lead foot
    root = (0.0, -0.105 - 0.012 * settle, 0.01 + 0.015 * rock)
    return {k: kit.r_(v) for k, v in {
        "root": root,
        "hips": 4.0 + 1.0 * settle, "chest": 3.0 + 0.8 * settle, "yaw": -30.0 + 1.5 * rock, "twist": -5.0 - 1.0 * rock,
        "hand_l": kit.add(KR_FIST_L, (0.0, root[1] + 0.105 - 0.006 * settle, root[2] - 0.01 + 0.018 * rock)),
        "hand_r": kit.add(KR_FIST_R, (0.0, root[1] + 0.105, root[2] - 0.01)),
        "heel_r": 2.0 * max(0.0, rock),
    }.items()}


BASE = dict(STAND)
BASE.update(GUARD)
BASE.update(stance_at(0.0))
clip = kit.clip_on(BASE, META)

CLIPS = {
    # ---------------------------------------------------------------- the stance (earth's stance while in karate)
    "stance": dict(bc._loop(STANCE_LEN, stance_at), length=STANCE_LEN, loop=True, base=BASE,
                   meta=dict(META, hand="both", move="stance", mode="stance", order=0)),

    # ---------------------------------------------------------------- the jab string: kizami-zuki, then gyaku-zuki as the Pop
    # the lead fist snapped straight out on the line, the lead shoulder driven in, the rear fist kept at the hip; snapped back
    "jab": clip(16, dict(hold_s=2 * S, strike_s=5 * S, back_s=8 * S, antic_s=2 * S, follow_s=8 * S, hand="l",
                         move="rock_jab", mode="pebbles", order=1, stills="ready:2;strike:5;snap back:8"),
        root=[(2, (0.0, -0.11, 0.0)), (5, (0.0, -0.11, 0.04)), (8, (0.0, -0.11, 0.03)), (12, (0.0, -0.105, 0.01))],
        yaw=[(2, -30.0), (5, -36.0), (8, -34.0), (12, -30.0)],
        twist=[(5, -12.0), (8, -10.0), (12, -5.0)],
        clav_l=[(2, (10.0, -4.0)), (5, (24.0, -12.0)), (8, (20.0, -10.0)), (12, (10.0, -4.0))],
        hand_l=[(2, (0.08, 1.2, 0.42)), (5, (0.03, 1.24, 0.6)), (6, (0.03, 1.24, 0.6)), (8, (0.05, 1.22, 0.5)), (12, KR_FIST_L)],
        face_l=[(2, "kr_lead"), (5, "kr_fist"), (6, "kr_fist"), (9, "kr_lead")],
        pole_l=[(2, (0.35, -1.0, -0.1)), (5, (0.6, -0.8, 0.0)), (9, (0.35, -1.0, -0.1))],
        hand_r=[(2, KR_FIST_R), (5, (-0.21, 0.96, 0.06)), (12, KR_FIST_R)],
    ),
    # the reverse punch: the hips driven round (the rear heel pivoting), the rear fist out from the hip to the line, the lead
    # fist pulled back to its hip; held a beat at the strike (kime), then the hands swapped back
    "reverse": clip(24, dict(hold_s=3 * S, strike_s=8 * S, back_s=14 * S, antic_s=3 * S, follow_s=12 * S, hand="r",
                             move="rock_jab", mode="pop", order=2, stills="load:3;strike:8;kime:10;guard:18"),
        root=[(3, (0.01, -0.11, -0.01)), (8, (-0.01, -0.115, 0.06)), (10, (-0.01, -0.115, 0.06)), (18, (0.0, -0.105, 0.01))],
        yaw=[(3, -26.0), (8, -64.0), (10, -64.0), (14, -58.0), (18, -30.0)],
        twist=[(3, -3.0), (8, -18.0), (10, -18.0), (18, -5.0)],
        hips=[(3, 4.0), (8, 7.0), (18, 4.0)],
        clav_r=[(3, (2.0, 4.0)), (8, (26.0, -12.0)), (10, (26.0, -12.0)), (18, (2.0, 4.0))],
        clav_l=[(3, (10.0, -4.0)), (8, (0.0, 6.0)), (10, (0.0, 6.0)), (18, (10.0, -4.0))],
        hand_r=[(3, (-0.2, 0.97, 0.0)), (6, (-0.1, 1.15, 0.3)), (8, (-0.03, 1.24, 0.48)), (10, (-0.03, 1.24, 0.48)),
                (14, (-0.08, 1.18, 0.36)), (18, KR_FIST_R)],
        face_r=[(3, "chamber"), (6, "kr_lead"), (8, "kr_fist"), (11, "kr_fist"), (14, "kr_lead"), (18, "chamber")],
        pole_r=[(3, (-0.6, -0.8, -0.3)), (8, (-0.55, -0.85, 0.0)), (14, (-0.6, -0.85, -0.1)), (18, (-0.6, -0.8, -0.3))],
        hand_l=[(3, (0.08, 1.2, 0.42)), (8, (0.19, 0.97, 0.03)), (10, (0.19, 0.97, 0.03)), (14, (0.14, 1.08, 0.22)), (18, KR_FIST_L)],
        face_l=[(3, "kr_lead"), (8, "chamber"), (11, "chamber"), (14, "kr_lead")],
        pole_l=[(3, (0.35, -1.0, -0.1)), (8, (0.6, -0.8, -0.3)), (14, (0.4, -1.0, -0.1))],
        heel_r=[(3, 0.0), (8, 26.0), (10, 26.0), (14, 14.0), (18, 0.0)],
        fyaw_r=[(3, 45.0), (8, 70.0), (10, 70.0), (18, 45.0)],
        knee_r=[(3, (-0.5, 0.0, 1.0)), (8, (-0.85, 0.0, 0.7)), (18, (-0.5, 0.0, 1.0))],
    ),

    # ---------------------------------------------------------------- key 1: the lunge punch (the Spike)
    # a full step through: the rear foot driven past the lead and planted ahead as the same side's fist lands straight out;
    # the lead fist pulled to the hip; then the step taken back.  strike_s: the foot down and the fist out
    "lunge": clip(32, dict(hold_s=4 * S, strike_s=10 * S, back_s=18 * S, antic_s=4 * S, follow_s=16 * S, hand="r",
                           move="stone_form", mode="spike", order=3, stills="load:4;step through:7;strike:10;back:24"),
        root=[(4, (0.0, -0.11, -0.02)), (7, (0.0, -0.1, 0.14)), (10, (0.0, -0.12, 0.26)), (14, (0.0, -0.12, 0.26)),
              (24, (0.0, -0.105, 0.01))],
        yaw=[(4, -30.0), (7, -10.0), (10, 8.0), (14, 8.0), (24, -30.0)],
        twist=[(4, -5.0), (10, 10.0), (14, 10.0), (24, -5.0)],
        hips=[(4, 4.0), (10, 6.0), (24, 4.0)],
        foot_r=[(4, KR_FOOT_R), (6, (-0.2, 0.12, 0.0)), (8, (-0.2, 0.1, 0.3)), (10, (-0.2, 0.077, 0.52)), (14, (-0.2, 0.077, 0.52)),
                (18, (-0.2, 0.1, 0.3)), (21, (-0.2, 0.1, -0.05)), (24, KR_FOOT_R)],
        fyaw_r=[(4, 45.0), (8, 10.0), (10, 2.0), (14, 2.0), (21, 30.0), (24, 45.0)],
        heel_r=[(4, 0.0), (6, 14.0), (10, 0.0), (18, 10.0), (24, 0.0)],
        knee_r=[(4, (-0.5, 0.0, 1.0)), (10, (-0.25, 0.0, 1.0)), (14, (-0.25, 0.0, 1.0)), (24, (-0.5, 0.0, 1.0))],
        foot_l=[(4, KR_FOOT_L), (10, KR_FOOT_L), (14, KR_FOOT_L), (24, KR_FOOT_L)],
        fyaw_l=[(4, -2.0), (10, 30.0), (14, 30.0), (24, -2.0)],
        heel_l=[(4, 0.0), (10, 6.0), (14, 6.0), (24, 0.0)],
        knee_l=[(4, (0.25, 0.0, 1.0)), (10, (0.55, 0.0, 0.9)), (14, (0.55, 0.0, 0.9)), (24, (0.25, 0.0, 1.0))],
        hand_r=[(4, (-0.2, 0.97, -0.01)), (7, (-0.12, 1.12, 0.3)), (10, (-0.08, 1.25, 0.76)), (14, (-0.08, 1.25, 0.76)),
                (18, (-0.12, 1.15, 0.5)), (24, KR_FIST_R)],
        face_r=[(4, "chamber"), (7, "kr_lead"), (10, "kr_fist"), (15, "kr_fist"), (18, "kr_lead"), (24, "chamber")],
        pole_r=[(4, (-0.6, -0.8, -0.3)), (10, (-0.5, -0.85, 0.1)), (18, (-0.6, -0.85, -0.1)), (24, (-0.6, -0.8, -0.3))],
        clav_r=[(4, (2.0, 4.0)), (10, (24.0, -12.0)), (14, (24.0, -12.0)), (24, (2.0, 4.0))],
        hand_l=[(4, (0.08, 1.2, 0.42)), (7, (0.14, 1.1, 0.3)), (10, (0.2, 0.98, 0.28)), (14, (0.2, 0.98, 0.28)), (18, (0.16, 1.1, 0.3)),
                (24, KR_FIST_L)],
        face_l=[(4, "kr_lead"), (10, "chamber"), (15, "chamber"), (18, "kr_lead")],
        pole_l=[(4, (0.35, -1.0, -0.1)), (10, (0.6, -0.8, -0.3)), (18, (0.4, -1.0, -0.1))],
        clav_l=[(4, (10.0, -4.0)), (10, (0.0, 6.0)), (14, (0.0, 6.0)), (24, (10.0, -4.0))],
        mirror=True,
    ),

    # ---------------------------------------------------------------- key 2: the double palm-heel thrust (the Push)
    # both fists drawn to the chambers at the hips (the body sunk), then both palm heels driven out together at chest height
    # off a deep lunge of the lead leg; drawn back.  strike_s: the palms out
    "palm_thrust": clip(26, dict(hold_s=4 * S, strike_s=9 * S, back_s=15 * S, antic_s=4 * S, follow_s=13 * S, hand="both",
                                 move="earth_shove", mode="push", order=4, stills="chamber:4;strike:9;hold:11;guard:20"),
        root=[(4, (0.0, -0.125, -0.03)), (9, (0.0, -0.13, 0.09)), (11, (0.0, -0.13, 0.09)), (20, (0.0, -0.105, 0.01))],
        yaw=[(4, -24.0), (9, -12.0), (11, -12.0), (20, -30.0)],
        twist=[(4, -3.0), (9, 0.0), (20, -5.0)],
        hips=[(4, 6.0), (9, 10.0), (11, 10.0), (20, 4.0)],
        chest=[(4, 2.0), (9, 6.0), (20, 3.0)],
        hand_l=[(4, (0.2, 0.92, 0.0)), (7, (0.16, 1.05, 0.26)), (9, (0.13, 1.14, 0.56)), (11, (0.13, 1.14, 0.56)), (15, (0.12, 1.12, 0.42)),
                (20, KR_FIST_L)],
        hand_r=[(4, (-0.2, 0.92, 0.0)), (7, (-0.16, 1.05, 0.26)), (9, (-0.13, 1.14, 0.56)), (11, (-0.13, 1.14, 0.56)), (15, (-0.14, 1.1, 0.36)),
                (20, KR_FIST_R)],
        face_l=[(4, "chamber"), (7, "chamber"), (9, "push"), (12, "push"), (16, "kr_lead")],
        face_r=[(4, "chamber"), (7, "chamber"), (9, "push"), (12, "push"), (16, "kr_lead"), (20, "chamber")],
        grip_l=[(4, 1.0), (7, 0.2), (13, 0.2), (18, 1.0)],
        grip_r=[(4, 1.0), (7, 0.2), (13, 0.2), (18, 1.0)],
        pole_l=[(4, (0.6, -0.8, -0.3)), (9, (0.4, -0.9, 0.0)), (20, (0.35, -1.0, -0.1))],
        pole_r=[(4, (-0.6, -0.8, -0.3)), (9, (-0.4, -0.9, 0.0)), (20, (-0.6, -0.8, -0.3))],
        foot_l=[(4, KR_FOOT_L), (9, (0.14, 0.077, 0.38)), (11, (0.14, 0.077, 0.38)), (20, KR_FOOT_L)],
        knee_l=[(4, (0.25, 0.0, 1.0)), (9, (0.4, 0.0, 1.0)), (20, (0.25, 0.0, 1.0))],
        heel_r=[(4, 0.0), (9, 8.0), (11, 8.0), (20, 0.0)],
        mirror=True,
    ),

    # ---------------------------------------------------------------- E: the block (the Catch)
    # the lead fist cocked high by the far shoulder (the rear fist at the hip), then whipped down and out across the lead
    # thigh as the hips turn to the mark; held a beat; back to the guard.  strike_s: the block down (the catch's window)
    "block": clip(24, dict(hold_s=4 * S, strike_s=8 * S, back_s=14 * S, antic_s=4 * S, follow_s=12 * S, hand="both",
                           move="stone_catch", mode="catch", order=5, stills="cock:4;block:8;held:11;guard:18"),
        root=[(4, (0.0, -0.11, -0.02)), (8, (0.0, -0.12, 0.02)), (11, (0.0, -0.12, 0.02)), (18, (0.0, -0.105, 0.01))],
        yaw=[(4, -20.0), (8, -40.0), (11, -40.0), (18, -30.0)],
        twist=[(4, 6.0), (8, -14.0), (11, -14.0), (18, -5.0)],
        hips=[(4, 4.0), (8, 6.0), (18, 4.0)],
        hand_l=[(4, (-0.12, 1.42, 0.2)), (6, (0.05, 1.2, 0.36)), (8, (0.3, 0.86, 0.36)), (11, (0.3, 0.86, 0.36)), (14, (0.22, 1.0, 0.4)),
                (18, KR_FIST_L)],
        face_l=[(4, "kr_block_hi"), (6, "kr_block_hi"), (8, "kr_block_lo"), (12, "kr_block_lo"), (16, "kr_lead")],
        pole_l=[(4, (0.3, -0.5, -0.8)), (8, (0.7, -0.6, 0.2)), (12, (0.7, -0.6, 0.2)), (18, (0.35, -1.0, -0.1))],
        clav_l=[(4, (8.0, -10.0)), (8, (14.0, 6.0)), (11, (14.0, 6.0)), (18, (10.0, -4.0))],
        hand_r=[(4, (-0.2, 0.97, 0.0)), (8, (-0.21, 0.96, 0.06)), (18, KR_FIST_R)],
        heel_r=[(4, 0.0), (8, 6.0), (11, 6.0), (18, 0.0)],
    ),

    # ---------------------------------------------------------------- Shift + a direction: yori-ashi (the game carries the body)
    # in (earth_skate "burrow" and "skate"): the lead foot slides ahead, the rear foot drawn after it, the depth kept
    "step_in": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                             move="earth_skate", mode="burrow", order=6, stills="push:3;lead foot down:7;rear foot drawn up:11"),
        root=[(2, (0.0, -0.11, -0.01)), (5, (0.0, -0.11, 0.08)), (7, (0.0, -0.125, 0.14)), (11, (0.0, -0.12, 0.13)),
              (16, (0.0, -0.105, 0.04))],
        foot_l=[(2, KR_FOOT_L), (4, (0.14, 0.09, 0.38)), (6, (0.14, 0.085, 0.45)), (7, (0.14, 0.077, 0.47)), (11, (0.14, 0.077, 0.46)),
                (16, KR_FOOT_L)],
        foot_r=[(7, KR_FOOT_R), (9, (-0.2, 0.085, -0.2)), (11, (-0.2, 0.08, -0.1)), (12, (-0.2, 0.077, -0.1)), (16, KR_FOOT_R)],
        heel_r=[(2, 0.0), (5, 10.0), (7, 8.0), (11, 4.0), (16, 0.0)],
        hand_l=[(2, (0.08, 1.2, 0.43)), (5, (0.08, 1.205, 0.53)), (7, (0.08, 1.195, 0.61)), (11, (0.08, 1.2, 0.59)), (16, (0.08, 1.2, 0.49))],
        hand_r=[(2, (-0.2, 0.96, 0.01)), (5, (-0.2, 0.965, 0.11)), (7, (-0.2, 0.955, 0.19)), (11, (-0.2, 0.96, 0.17)), (16, (-0.2, 0.96, 0.07))],
    ),
    # back (earth_skate "skate" when backing): the rear foot slides back, the lead foot drawn after it
    "step_back": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                               move="earth_skate", mode="skate", order=7, stills="push:3;rear foot down:7;lead foot drawn back:11"),
        root=[(2, (0.0, -0.11, 0.03)), (5, (0.0, -0.11, -0.06)), (7, (0.0, -0.125, -0.12)), (11, (0.0, -0.12, -0.11)),
              (16, (0.0, -0.105, -0.02))],
        foot_r=[(2, KR_FOOT_R), (4, (-0.2, 0.09, -0.36)), (6, (-0.2, 0.085, -0.43)), (7, (-0.2, 0.077, -0.45)), (11, (-0.2, 0.077, -0.44)),
                (16, KR_FOOT_R)],
        foot_l=[(7, KR_FOOT_L), (9, (0.14, 0.085, 0.2)), (11, (0.14, 0.08, 0.1)), (12, (0.14, 0.077, 0.1)), (16, KR_FOOT_L)],
        heel_l=[(2, 0.0), (5, 10.0), (7, 6.0), (11, 2.0), (16, 0.0)],
        hand_l=[(2, (0.08, 1.2, 0.47)), (5, (0.08, 1.205, 0.37)), (7, (0.08, 1.195, 0.29)), (11, (0.08, 1.2, 0.31)), (16, (0.08, 1.2, 0.41))],
        hand_r=[(2, (-0.2, 0.96, 0.05)), (5, (-0.2, 0.965, -0.05)), (7, (-0.2, 0.955, -0.13)), (11, (-0.2, 0.96, -0.11)), (16, (-0.2, 0.96, -0.01))],
    ),
    # to the side (earth_skate "slide"): the lead foot first, out to the left, the rear foot drawn after it
    "step_side": clip(22, dict(hold_s=2 * S, strike_s=7 * S, back_s=12 * S, antic_s=2 * S, follow_s=11 * S, hand="both",
                               move="earth_skate", mode="slide", order=8, stills="push:3;lead foot down:7;rear foot drawn after:11"),
        root=[(2, (-0.02, -0.11, 0.01)), (5, (0.07, -0.105, 0.01)), (7, (0.15, -0.115, 0.01)), (11, (0.13, -0.11, 0.01)),
              (16, (0.04, -0.105, 0.01))],
        roll=[(2, 2.0), (5, -2.0), (11, 0.0)],
        foot_l=[(2, KR_FOOT_L), (4, (0.26, 0.09, 0.3)), (6, (0.37, 0.085, 0.3)), (7, (0.4, 0.077, 0.3)), (11, (0.39, 0.077, 0.3)),
                (16, KR_FOOT_L)],
        foot_r=[(7, KR_FOOT_R), (9, (-0.12, 0.085, -0.28)), (11, (-0.04, 0.08, -0.28)), (12, (-0.04, 0.077, -0.28)), (16, KR_FOOT_R)],
        heel_r=[(2, 0.0), (5, 10.0), (7, 8.0), (11, 4.0), (16, 0.0)],
        hand_l=[(2, (0.06, 1.2, 0.44)), (5, (0.15, 1.205, 0.44)), (7, (0.23, 1.195, 0.44)), (11, (0.21, 1.2, 0.44)), (16, (0.12, 1.2, 0.44))],
        hand_r=[(2, (-0.22, 0.96, 0.02)), (5, (-0.13, 0.965, 0.02)), (7, (-0.05, 0.955, 0.02)), (11, (-0.07, 0.96, 0.02)), (16, (-0.16, 0.96, 0.02))],
    ),
}

kit.main(STYLE, ELEMENT, CLIPS)
