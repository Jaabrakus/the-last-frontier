"""Wing Chun for water: the style's own clips (the owner, 2026-10-16, after parking Judo: Wing Chun for water). Wing Chun has
no motion in the Motifect pack, so every clip here is keyed by hand, as Boxing's were. Water's own idle already has Wing
Chun's hands on the fighting stagger the owner picked (bend_clips.py stance_water_wing_chun, 2026-10-12); this style keeps
that look for its stance and adds the strikes: the chain punch of the jab string and its palm Pop, the trap-and-punch of
the Whip and Lash, the double palm of the Wave, the wing-arm turn of the Turn and its held sticky-hands guard, and the
arrow steps of the Shift movement. Every water move keeps what it DOES; the style only changes how the body shows it, timed
as water's own (BendPoses._timed_as).

Derived from tools/anim_author/blender/bend_clips.py through style_kit.py and from nothing else: key poses typed into
CLIPS, posed by bend_clips' solver (two-bone IK on Actor_B's own rig, assets/character/actor_b_body.glb) in Blender and
baked to the bones' local rotations as Godot has them, for tools/anim_author/install_style.gd. No library clip and no
dumped move is read (the stance's numbers are typed again here, not read from the library). Keyed from standard Wing Chun
mechanics (the centreline; man sau and wu sau; the vertical-fist chain punch; lap sau, bong sau, po pai jeung; biu ma);
no video looked at: short straight strikes and sliding steps are plain standing motions.

The clips (own-style-wing-chun-<name> in animations_extra/Frontier_Style_Wing_chun.res; the left hand leads on the
centreline; the chain punch and the trap-and-punch come as mirrored twins for the moves that have an alt):
  stance       water's idle in the style: the lead Man Sau up and out on the centreline, the rear Wu Sau behind its
               elbow, on the fighting stagger; a slow breath, the hands with the body
  chain        the Splash: the rear hand driven straight down the centreline as a vertical fist, the lead hand drawn back
               to cover; snapped back (its twin: the other hand)
  palm         the Pop: the lead palm thrust up the centreline with a short step in, the hip behind it
  trap_punch   the Whip and the Lash: lap sau, the lead hand snapping down to trap, the rear fist punching over it
  double_palm  the Wave: po pai jeung, both palms driven out together, one high and one low, off a short step
  bong         the Turn (E tapped): bong sau, the lead forearm rolled up and out across the line as the stance turns
  guard        the Turn held (E held): the hands kept on the line, feeling (a small sticky circle)
  step_in, step_back, step_side   the Shift movement (water's Skate): biu ma, the arrow step: the lead foot driven
               ahead, the rear dragged after it, the hands kept on the line

Metas as style_boxing.py's. Channels as bend_clips.py's (+X the character's left, +Y up, +Z forward, metres; angles in
degrees); a channel a clip leaves out holds the stance's.

  Blender -b --factory-startup --python tools/anim_author/blender/style_wing_chun.py -- --out <wing_chun.json>
      [--clips stance,chain] [--fit] [--angles] [--points] [--quiet]
  (through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import style_kit as kit  # noqa: E402
import bend_clips as bc  # noqa: E402
from bend_clips import FACING, FPS, STAND  # noqa: E402

STYLE = "wing_chun"
ELEMENT = "water"

kit.hands()

FACING.update({
    "wc_man": ((0.0, 0.72, 0.7), (1.0, 0.0, 0.0)),             # Man Sau: the fingers up and out, the palm side-on to the centreline
    "wc_wu": ((0.0, 0.96, 0.28), (0.55, 0.0, 0.83)),           # Wu Sau: the fingers up, the palm forward and in
    "wc_fist_r": ((0.0, 0.12, 0.99), (1.0, 0.0, 0.0)),         # the right vertical fist landing: the knuckles forward, the thumb up (the palm to the left)
    "wc_lap": ((0.3, -0.6, 0.74), (0.0, -0.75, -0.65)),        # Lap Sau: the hand snapped down over the arm it traps, the palm down and back
    "wc_bong": ((-0.45, -0.35, 0.82), (0.3, -0.9, -0.3)),      # Bong Sau: the forearm rolled up and across, the hand hanging in and down, the elbow high
})

## The stance (water's own, typed again): the fighting stagger the owner picked, the lead Man Sau up and out on the
## centreline at the chin's height, the Wu Sau just behind its elbow, the elbows down and in.
WC_FOOT_L = (0.13, 0.077, 0.21)
WC_FOOT_R = (-0.17, 0.077, -0.19)
WC_MAN = (0.03, 1.22, 0.46)
WC_WU = (-0.03, 1.12, 0.26)
GUARD = {
    "root": (0.0, -0.075, 0.0), "yaw": -18.0, "twist": -6.0, "hips": 3.0, "roll": 0.0, "chest": 4.0, "side": 0.0,
    "head": 3.0, "look": 0.0, "clav_r": (2.0, -1.0), "clav_l": (4.0, -2.0),
    "hand_r": WC_WU, "hand_l": WC_MAN, "face_r": "wc_wu", "face_l": "wc_man",
    "pole_r": (-0.25, -1.0, -0.1), "pole_l": (-0.15, -1.0, 0.0), "grip_r": -0.12, "grip_l": -0.12,
    "foot_r": WC_FOOT_R, "foot_l": WC_FOOT_L, "fyaw_r": 34.0, "fyaw_l": -4.0, "heel_r": 12.0, "heel_l": 2.0,
    "knee_r": (-0.45, 0.0, 1.0), "knee_l": (0.15, 0.0, 1.0),
}

META = {"mask": "full", "root": "place", "style": STYLE, "element": ELEMENT}
S = 1.0 / FPS

## The idle: the slow breath (the root easing down a touch), the lead hand easing out and back a finger's width, the hands
## riding the body.
STANCE_LEN = 48


def stance_at(a):
    breath = 0.5 - 0.5 * kit.c_(a)
    root = (0.0, -0.075 - 0.006 * breath, -0.004 * breath)
    return {k: kit.r_(v) for k, v in {
        "root": root,
        "yaw": -18.0 + 1.5 * breath, "twist": -6.0 + 1.0 * breath, "chest": 4.0 + 1.2 * kit.s_(a),
        "clav_l": (4.0 + 1.0 * breath, -2.0 - 0.5 * breath), "clav_r": (2.0 + 1.0 * breath, -1.0 - 0.5 * breath),
        "hand_l": kit.add(WC_MAN, (0.0, root[1] + 0.075 - 0.005 * breath, root[2] + 0.022 * breath)),
        "hand_r": kit.add(WC_WU, (0.004 * breath, root[1] + 0.075 + 0.008 * breath, root[2] + 0.006 * breath)),
    }.items()}


BASE = dict(STAND)
BASE.update(GUARD)
BASE.update(stance_at(0.0))
clip = kit.clip_on(BASE, META)

## The guard held: the hands a little further out on the line, feeling.
HOLD_LEN = 36


def guard_at(a):
    c1, s1 = kit.c_(a), kit.s_(a)
    return {k: kit.r_(v) for k, v in {
        "root": (0.0, -0.078, 0.0),
        "hand_l": kit.add(WC_MAN, (0.012 * c1, 0.01 * s1 + 0.01, 0.03 + 0.01 * s1)),
        "hand_r": kit.add(WC_WU, (-0.008 * c1, -0.008 * s1, 0.02 - 0.008 * c1)),
        "yaw": -18.0 - 1.5 * s1,
    }.items()}


CLIPS = {
    # ---------------------------------------------------------------- the stance (water's stance while in Wing Chun)
    "stance": dict(bc._loop(STANCE_LEN, stance_at), length=STANCE_LEN, loop=True, base=BASE,
                   meta=dict(META, hand="both", move="stance", mode="stance", order=0)),

    # ---------------------------------------------------------------- the jab string: the chain punch (the Splash), the palm (the Pop)
    # the rear (Wu) hand closed and driven straight down the centreline as a vertical fist, the shoulders turned a touch
    # behind it, the lead hand drawn back to the Wu's place to cover; snapped back.  strike_s: the fist out
    "chain": clip(14, dict(hold_s=2 * S, strike_s=4 * S, back_s=7 * S, antic_s=2 * S, follow_s=7 * S, hand="r",
                           move="water_jet", mode="splash", order=1, stills="ready:2;strike:4;snap back:7"),
        root=[(2, (0.0, -0.077, 0.0)), (4, (0.0, -0.08, 0.025)), (7, (0.0, -0.078, 0.015)), (11, (0.0, -0.075, 0.0))],
        twist=[(2, -6.0), (4, -16.0), (7, -12.0), (11, -6.0)],
        yaw=[(4, -22.0), (11, -18.0)],
        clav_r=[(2, (2.0, -1.0)), (4, (18.0, -8.0)), (7, (12.0, -5.0)), (11, (2.0, -1.0))],
        hand_r=[(2, (-0.03, 1.12, 0.24)), (4, (0.0, 1.25, 0.46)), (5, (0.0, 1.25, 0.46)), (7, (-0.02, 1.18, 0.35)), (11, WC_WU)],
        face_r=[(2, "wc_wu"), (4, "wc_fist_r"), (5, "wc_fist_r"), (8, "wc_wu")],
        pole_r=[(2, (-0.25, -1.0, -0.1)), (4, (-0.3, -0.95, 0.1)), (8, (-0.25, -1.0, -0.1))],
        grip_r=[(2, -0.12), (3, 1.0), (6, 1.0), (9, -0.12)],
        hand_l=[(2, (0.03, 1.22, 0.44)), (4, (0.02, 1.14, 0.3)), (7, (0.02, 1.16, 0.34)), (11, WC_MAN)],
        face_l=[(2, "wc_man"), (4, "wc_wu"), (7, "wc_wu"), (11, "wc_man")],
        mirror=True,
    ),
    # the palm: a short step in with the lead foot and the lead palm thrust up the centreline, the hip behind it; back
    "palm": clip(18, dict(hold_s=2 * S, strike_s=6 * S, back_s=10 * S, antic_s=2 * S, follow_s=9 * S, hand="l",
                          move="water_jet", mode="pop", order=2, stills="ready:2;step and strike:6;snap back:10"),
        root=[(2, (0.0, -0.08, -0.01)), (6, (0.0, -0.085, 0.07)), (10, (0.0, -0.08, 0.05)), (14, (0.0, -0.075, 0.0))],
        yaw=[(2, -16.0), (6, -26.0), (10, -24.0), (14, -18.0)],
        twist=[(6, -14.0), (10, -10.0), (14, -6.0)],
        hips=[(2, 3.0), (6, 6.0), (14, 3.0)],
        clav_l=[(2, (4.0, -2.0)), (6, (20.0, -10.0)), (10, (14.0, -6.0)), (14, (4.0, -2.0))],
        hand_l=[(2, (0.03, 1.2, 0.4)), (6, (0.02, 1.28, 0.6)), (7, (0.02, 1.28, 0.6)), (10, (0.03, 1.24, 0.5)), (14, WC_MAN)],
        face_l=[(2, "wc_man"), (6, "push"), (8, "push"), (11, "wc_man")],
        pole_l=[(2, (-0.15, -1.0, 0.0)), (6, (0.25, -0.95, 0.0)), (11, (-0.15, -1.0, 0.0))],
        hand_r=[(2, (-0.03, 1.12, 0.25)), (6, (-0.03, 1.13, 0.33)), (14, WC_WU)],
        foot_l=[(2, WC_FOOT_L), (4, (0.13, 0.09, 0.27)), (6, (0.13, 0.077, 0.32)), (10, (0.13, 0.077, 0.31)), (14, WC_FOOT_L)],
        heel_r=[(2, 12.0), (6, 20.0), (10, 16.0), (14, 12.0)],
    ),

    # ---------------------------------------------------------------- key 1: the trap and punch (the Whip and the Lash)
    # lap sau: the lead hand snapped down and in to trap, the rear fist driven over it down the centreline as the shoulders
    # turn; the hands swapped back.  strike_s: the fist out
    "trap_punch": clip(20, dict(hold_s=3 * S, strike_s=7 * S, back_s=12 * S, antic_s=3 * S, follow_s=11 * S, hand="r",
                                move="water_whip", mode="whip", order=3, stills="ready:3;trap:5;strike:7;guard:16"),
        root=[(3, (0.0, -0.078, -0.01)), (5, (0.0, -0.082, 0.02)), (7, (0.0, -0.085, 0.04)), (12, (0.0, -0.08, 0.02)), (16, (0.0, -0.075, 0.0))],
        yaw=[(3, -16.0), (7, -26.0), (12, -22.0), (16, -18.0)],
        twist=[(3, -4.0), (5, -8.0), (7, -18.0), (12, -12.0), (16, -6.0)],
        hand_l=[(3, (0.03, 1.22, 0.45)), (5, (0.1, 1.0, 0.3)), (7, (0.12, 0.98, 0.26)), (10, (0.12, 0.98, 0.26)), (13, (0.06, 1.1, 0.36)),
                (16, WC_MAN)],
        face_l=[(3, "wc_man"), (5, "wc_lap"), (10, "wc_lap"), (14, "wc_man")],
        pole_l=[(3, (-0.15, -1.0, 0.0)), (5, (0.4, -0.85, -0.2)), (10, (0.4, -0.85, -0.2)), (16, (-0.15, -1.0, 0.0))],
        grip_l=[(3, -0.12), (5, 0.7), (10, 0.7), (14, -0.12)],
        hand_r=[(3, (-0.03, 1.12, 0.25)), (5, (-0.02, 1.16, 0.3)), (7, (0.0, 1.26, 0.46)), (9, (0.0, 1.26, 0.46)), (12, (-0.02, 1.18, 0.35)),
                (16, WC_WU)],
        face_r=[(3, "wc_wu"), (7, "wc_fist_r"), (9, "wc_fist_r"), (12, "wc_wu")],
        pole_r=[(3, (-0.25, -1.0, -0.1)), (7, (-0.3, -0.95, 0.1)), (12, (-0.25, -1.0, -0.1))],
        grip_r=[(3, -0.12), (5, 1.0), (10, 1.0), (14, -0.12)],
        clav_r=[(3, (2.0, -1.0)), (7, (18.0, -8.0)), (12, (8.0, -4.0)), (16, (2.0, -1.0))],
        mirror=True,
    ),

    # ---------------------------------------------------------------- key 2: the double palm (the Wave)
    # both hands drawn in to the chest, then both palms driven out together off a short step, the lead high at the chest
    # and the rear low at the belly; drawn back.  strike_s: the palms out
    "double_palm": clip(22, dict(hold_s=4 * S, strike_s=8 * S, back_s=14 * S, antic_s=4 * S, follow_s=12 * S, hand="both",
                                 move="wave", mode="push", order=4, stills="draw in:4;strike:8;hold:10;guard:18"),
        root=[(4, (0.0, -0.085, -0.02)), (8, (0.0, -0.09, 0.07)), (10, (0.0, -0.09, 0.07)), (18, (0.0, -0.075, 0.0))],
        yaw=[(4, -14.0), (8, -12.0), (18, -18.0)],
        twist=[(4, -3.0), (8, 0.0), (18, -6.0)],
        hips=[(4, 4.0), (8, 7.0), (18, 3.0)],
        chest=[(4, 2.0), (8, 7.0), (18, 4.0)],
        hand_l=[(4, (0.1, 1.2, 0.2)), (8, (0.08, 1.28, 0.52)), (10, (0.08, 1.28, 0.52)), (14, (0.06, 1.24, 0.44)), (18, WC_MAN)],
        hand_r=[(4, (-0.1, 1.0, 0.18)), (8, (-0.08, 1.04, 0.49)), (10, (-0.08, 1.04, 0.49)), (14, (-0.06, 1.08, 0.38)), (18, WC_WU)],
        face_l=[(4, "wc_wu"), (8, "push"), (11, "push"), (15, "wc_man")],
        face_r=[(4, "wc_wu"), (8, "push"), (11, "push"), (15, "wc_wu")],
        pole_l=[(4, (0.3, -0.95, -0.1)), (8, (0.3, -0.95, 0.0)), (18, (-0.15, -1.0, 0.0))],
        pole_r=[(4, (-0.3, -0.95, -0.1)), (8, (-0.3, -0.95, 0.0)), (18, (-0.25, -1.0, -0.1))],
        foot_l=[(4, WC_FOOT_L), (6, (0.13, 0.09, 0.27)), (8, (0.13, 0.077, 0.32)), (12, (0.13, 0.077, 0.31)), (18, WC_FOOT_L)],
        heel_r=[(4, 12.0), (8, 22.0), (12, 18.0), (18, 12.0)],
    ),

    # ---------------------------------------------------------------- E: bong sau (the Turn)
    # the lead forearm rolled up and out across the line, the elbow high, the hand hanging in, as the stance turns to the
    # right on the feet; held a beat; rolled back to Man Sau.  strike_s: the wing up (the guard's window)
    "bong": clip(22, dict(hold_s=4 * S, strike_s=8 * S, back_s=13 * S, antic_s=4 * S, follow_s=12 * S, hand="both",
                          move="water_redirect", mode="redirect", order=5, stills="ready:4;wing up:8;held:11;guard:18"),
        root=[(4, (0.0, -0.078, 0.0)), (8, (-0.02, -0.085, 0.01)), (11, (-0.02, -0.085, 0.01)), (18, (0.0, -0.075, 0.0))],
        yaw=[(4, -16.0), (8, -44.0), (11, -44.0), (18, -18.0)],
        twist=[(4, -4.0), (8, -14.0), (11, -14.0), (18, -6.0)],
        hand_l=[(4, (0.03, 1.2, 0.44)), (8, (0.22, 1.28, 0.4)), (11, (0.22, 1.28, 0.4)), (15, (0.12, 1.24, 0.44)), (18, WC_MAN)],
        face_l=[(4, "wc_man"), (8, "wc_bong"), (12, "wc_bong"), (16, "wc_man")],
        pole_l=[(4, (-0.15, -1.0, 0.0)), (8, (0.3, 0.9, 0.2)), (12, (0.3, 0.9, 0.2)), (16, (-0.15, -1.0, 0.0))],
        clav_l=[(4, (4.0, -2.0)), (8, (12.0, 8.0)), (12, (12.0, 8.0)), (18, (4.0, -2.0))],
        hand_r=[(4, (-0.03, 1.12, 0.25)), (8, (-0.1, 1.14, 0.3)), (11, (-0.1, 1.14, 0.3)), (18, WC_WU)],
        fyaw_l=[(4, -4.0), (8, 16.0), (11, 16.0), (18, -4.0)],
        heel_l=[(4, 2.0), (8, 10.0), (11, 10.0), (18, 2.0)],
        fyaw_r=[(4, 34.0), (8, 48.0), (11, 48.0), (18, 34.0)],
    ),

    # ---------------------------------------------------------------- E held: the guard kept, feeling
    "guard": dict(bc._loop(HOLD_LEN, guard_at), length=HOLD_LEN, loop=True, base=BASE,
                  meta=dict(META, hand="both", move="water_redirect", mode="hold", order=6)),

    # ---------------------------------------------------------------- Shift + a direction: biu ma (the game carries the body)
    # in (flow "skate"): the lead foot driven ahead, the rear foot dragged after it; the hands kept on the line with the body
    "step_in": clip(20, dict(hold_s=2 * S, strike_s=6 * S, back_s=11 * S, antic_s=2 * S, follow_s=10 * S, hand="both",
                             move="flow", mode="skate", order=7, stills="push:2;lead foot down:6;rear foot dragged up:10"),
        root=[(2, (0.0, -0.08, -0.01)), (4, (0.0, -0.078, 0.08)), (6, (0.0, -0.088, 0.16)), (10, (0.0, -0.085, 0.14)),
              (15, (0.0, -0.075, 0.04))],
        foot_l=[(2, WC_FOOT_L), (4, (0.13, 0.085, 0.33)), (6, (0.13, 0.077, 0.44)), (10, (0.13, 0.077, 0.43)), (15, WC_FOOT_L)],
        foot_r=[(6, WC_FOOT_R), (8, (-0.17, 0.085, -0.08)), (10, (-0.17, 0.08, 0.01)), (11, (-0.17, 0.077, 0.01)), (15, WC_FOOT_R)],
        heel_r=[(2, 12.0), (4, 24.0), (6, 20.0), (10, 14.0), (15, 12.0)],
        hand_l=[(2, (0.03, 1.215, 0.45)), (4, (0.03, 1.217, 0.54)), (6, (0.03, 1.207, 0.62)), (10, (0.03, 1.21, 0.6)), (15, (0.03, 1.22, 0.5))],
        hand_r=[(2, (-0.03, 1.115, 0.25)), (4, (-0.03, 1.117, 0.34)), (6, (-0.03, 1.107, 0.42)), (10, (-0.03, 1.11, 0.4)), (15, (-0.03, 1.12, 0.3))],
    ),
    # back (flow "water_skate" when backing): the rear foot driven back, the lead foot dragged after it
    "step_back": clip(20, dict(hold_s=2 * S, strike_s=6 * S, back_s=11 * S, antic_s=2 * S, follow_s=10 * S, hand="both",
                               move="flow", mode="water_skate", order=8, stills="push:2;rear foot down:6;lead foot dragged back:10"),
        root=[(2, (0.0, -0.08, 0.01)), (4, (0.0, -0.078, -0.08)), (6, (0.0, -0.088, -0.16)), (10, (0.0, -0.085, -0.14)),
              (15, (0.0, -0.075, -0.04))],
        foot_r=[(2, WC_FOOT_R), (4, (-0.17, 0.085, -0.31)), (6, (-0.17, 0.077, -0.42)), (10, (-0.17, 0.077, -0.41)), (15, WC_FOOT_R)],
        foot_l=[(6, WC_FOOT_L), (8, (0.13, 0.085, 0.1)), (10, (0.13, 0.08, 0.01)), (11, (0.13, 0.077, 0.01)), (15, WC_FOOT_L)],
        heel_l=[(2, 2.0), (4, 12.0), (6, 8.0), (10, 4.0), (15, 2.0)],
        hand_l=[(2, (0.03, 1.215, 0.47)), (4, (0.03, 1.217, 0.38)), (6, (0.03, 1.207, 0.3)), (10, (0.03, 1.21, 0.32)), (15, (0.03, 1.22, 0.42))],
        hand_r=[(2, (-0.03, 1.115, 0.27)), (4, (-0.03, 1.117, 0.18)), (6, (-0.03, 1.107, 0.1)), (10, (-0.03, 1.11, 0.12)), (15, (-0.03, 1.12, 0.22))],
    ),
    # to the side: the lead foot first, out to the left, the rear foot dragged after it
    "step_side": clip(20, dict(hold_s=2 * S, strike_s=6 * S, back_s=11 * S, antic_s=2 * S, follow_s=10 * S, hand="both",
                               move="flow", mode="surf", order=9, stills="push:2;lead foot down:6;rear foot dragged after:10"),
        root=[(2, (-0.02, -0.08, 0.0)), (4, (0.07, -0.078, 0.0)), (6, (0.15, -0.088, 0.0)), (10, (0.13, -0.085, 0.0)),
              (15, (0.04, -0.075, 0.0))],
        roll=[(2, 1.5), (4, -1.5), (10, 0.0)],
        foot_l=[(2, WC_FOOT_L), (4, (0.25, 0.085, 0.21)), (6, (0.37, 0.077, 0.21)), (10, (0.36, 0.077, 0.21)), (15, WC_FOOT_L)],
        foot_r=[(6, WC_FOOT_R), (8, (-0.09, 0.085, -0.19)), (10, (-0.01, 0.08, -0.19)), (11, (-0.01, 0.077, -0.19)), (15, WC_FOOT_R)],
        heel_r=[(2, 12.0), (4, 22.0), (6, 18.0), (10, 14.0), (15, 12.0)],
        hand_l=[(2, (0.01, 1.215, 0.46)), (4, (0.1, 1.217, 0.46)), (6, (0.18, 1.207, 0.46)), (10, (0.16, 1.21, 0.46)), (15, (0.07, 1.22, 0.46))],
        hand_r=[(2, (-0.05, 1.115, 0.26)), (4, (0.04, 1.117, 0.26)), (6, (0.12, 1.107, 0.26)), (10, (0.1, 1.11, 0.26)), (15, (0.01, 1.12, 0.26))],
    ),
}

kit.main(STYLE, ELEMENT, CLIPS)
