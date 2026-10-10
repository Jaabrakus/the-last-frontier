"""Capoeira for air: the second fighting style (Tidebreak's fighting-style layer, docs/fighting_styles_design.md, the Air
roster's Capoeira row: "ginga (constant rocking footwork), acrobatics, spinning kicks"; the owner chose it on 2026-10-09).
Every move keeps what it DOES; only how the body performs it changes.

PARKED 2026-10-09 after the owner played them: "the animations for the caporia looks whack lets keep it simple for now";
they chose to drop Capoeira for now (air keeps its original clips). The clips stay in the library, mapped nowhere
(data/bending/style_poses.json no longer lists the style). Keyed without a video reference (below); a retry should start
from one.

Built on tools/anim_author/blender/style_kit.py (bend_clips.py's solver and bake, the owner's closed hands, clip(), main()):
key poses typed into the CLIPS table below, posed by two-bone IK on Actor_B's own rig (assets/character/actor_b_body.glb)
from its rest pose; no library clip, dumped move or reference motion is read. Every clip starts and ends on the ginga's
first frame (BASE: the right foot back, the left arm across the face).

References: none watched for this style yet. The browser pane could not draw the videos (it stayed hidden, then the Mac
restarted), so these clips are keyed from standard capoeira mechanics: the ginga's triangle step, the meia lua de frente's
vertical crescent, the martelo's instep roundhouse, the bencao's push kick, the armada's spinning outside crescent, the
esquiva's low dodge and the au's cartwheel. A catalogue was found and its chapter list read (move names and times only):
Mestre Koioty, "60 movimentos de capoeira para Luta (51 Golpes e 9 esquivas)" https://www.youtube.com/watch?v=hXyQk4LTlm8.

The clips (own-style-capoeira-<name> in animations_extra/Frontier_Style_Capoeira.res), each the variation of one air move
(data/sway/moves.json; the meta `move` and `mode`):
  ginga              the stance loop (air's stance while playing capoeira): the triangle step, the right foot back then the
                     left, the guard arm across the face swapping sides, the body low and rocking
  meia_lua           Palm (LMB): the meia lua de frente, the rear leg swung up and across the front in a vertical crescent
  meia_lua_front     Palm's alt (the next hand): the same with the front leg
  martelo            Slice (1): the instep roundhouse, chambered and snapped across at the chest's height
  bencao             Wind Ball (1 twice): the push kick, the sole driven straight out, the body leaning back
  armada             Gust (2, the signature): a whole turn on the ball of the crossed foot, the other leg swung straight round
                     in an outside crescent at the head's height
  esquiva            Wind Guard (E): the low lateral dodge under the shot (held: the window), then up with the palm swept
                     out ahead (the wind sent back)
  au                 Slip (3): the cartwheel, the hands to the deck and the legs over in a wide V
  rasteira           Pull (2 twice): dropped low onto one hand, the leg slid out along the deck and hooked back in
  compasso           the jab string's Pop: the meia lua de compasso, the trunk folded down onto both hands and a whole turn
                     with the rear leg swung round behind, the heel through the mark
Metas as style_boxing.py's (strike_s, hold_s, back_s, antic_s, follow_s, stills; hand, mask, root, style, element, move,
mode, order).

  Blender -b --factory-startup --python tools/anim_author/blender/style_capoeira.py -- --out <capoeira.json>
      [--clips ginga,armada] [--fit] [--angles] [--points] [--quiet]
  (through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import style_kit as kit  # noqa: E402
from style_kit import FACING, FPS, STAND  # noqa: E402

kit.hands()

STYLE = "capoeira"
ELEMENT = "air"
S = 1.0 / FPS

## The capoeirista's hands (the right hand's; the left's mirrored).
FACING.update({
    "cap_guard": ((0.3, 0.9, 0.3), (0.15, -0.3, 0.94)),       # the guard across the face: the fingers up and in, palm out
    "cap_low": ((0.1, -0.95, -0.3), (0.95, 0.0, 0.3)),        # the trailing hand low by the hip, the fingers down, palm in
    "cap_floor": ((0.0, -0.1, 1.0), (0.0, -1.0, -0.1)),       # a hand on the deck: the fingers ahead, the palm down
    "cap_up": ((-1.0, 0.05, 0.0), (0.0, 1.0, 0.05)),          # a hand overhead for the au: the fingers out, the palm up
    "cap_sweep": ((-0.2, 0.3, 0.93), (0.0, -0.95, 0.3)),      # a palm swept out ahead, the fingers forward, the palm down
})

## The ginga's first frame (BASE, every clip's first and last pose): the right foot stepped back on its ball, the left foot
## ahead, the body sunk low between them and bowed forward, the head up on the opponent; the left forearm across the face
## (the open hand by the right cheek), the right hand trailing low behind the hip.
G_FOOT_L = (0.17, 0.077, 0.16)
G_FOOT_R = (-0.13, 0.077, -0.5)
G_HAND_L = (-0.06, 1.12, 0.36)
G_HAND_R = (-0.32, 0.74, -0.2)
BASE = dict(STAND)
BASE.update({
    "root": (0.02, -0.16, -0.1), "yaw": -14.0, "twist": -12.0, "hips": 24.0, "roll": 0.0, "chest": 12.0, "side": 0.0,
    "head": -18.0, "look": 0.0, "clav_r": (-4.0, 4.0), "clav_l": (8.0, -4.0),
    "hand_r": G_HAND_R, "hand_l": G_HAND_L, "face_r": "cap_low", "face_l": "cap_guard",
    "pole_r": (-0.4, -0.6, -0.8), "pole_l": (0.4, -0.7, 0.6), "grip_r": 0.3, "grip_l": 0.1,
    "foot_r": G_FOOT_R, "foot_l": G_FOOT_L, "fyaw_r": 28.0, "fyaw_l": 10.0, "heel_r": 34.0, "heel_l": 0.0,
    "knee_r": (-0.25, -0.3, 1.0), "knee_l": (0.35, 0.0, 1.0),
})
META = {"mask": "full", "root": "place", "style": STYLE, "element": ELEMENT}
clip = kit.clip_on(BASE, META)


def mx(v):
    """A place mirrored across the body's middle (left for right)."""
    return (-v[0], v[1], v[2])


## The ginga (own-style-capoeira-ginga, a loop of GINGA_LEN frames): the right foot back (f0), both feet level (a quarter),
## the left foot back (a half), level again, the right back; each foot stepped on its ball with a little lift; the root
## sinking between the feet when one is back and rising a touch when level; the guard arm swapping across the face as the
## feet change (the arm on the front foot's side up), the trailing hand low behind the hip; the trunk turned with the feet.
GINGA_LEN = 56
_Q = GINGA_LEN // 4
_LEVEL_R = (-0.18, 0.077, 0.02)


def _ginga():
    q, n = _Q, GINGA_LEN
    level_l = mx(_LEVEL_R)
    keys = {
        "root": [(0, BASE["root"]), (q, (0.0, -0.12, 0.0)), (2 * q, mx(BASE["root"])), (3 * q, (0.0, -0.12, 0.0)),
                 (n, BASE["root"])],
        "yaw": [(0, -14.0), (q, 0.0), (2 * q, 14.0), (3 * q, 0.0), (n, -14.0)],
        "twist": [(0, -12.0), (q, 0.0), (2 * q, 12.0), (3 * q, 0.0), (n, -12.0)],
        "hips": [(0, 24.0), (q, 14.0), (2 * q, 24.0), (3 * q, 14.0), (n, 24.0)],
        "chest": [(0, 12.0), (q, 8.0), (2 * q, 12.0), (3 * q, 8.0), (n, 12.0)],
        "head": [(0, -18.0), (q, -10.0), (2 * q, -18.0), (3 * q, -10.0), (n, -18.0)],
        "clav_l": [(0, (8.0, -4.0)), (q, (4.0, 0.0)), (2 * q, (-4.0, 4.0)), (3 * q, (4.0, 0.0)), (n, (8.0, -4.0))],
        "clav_r": [(0, (-4.0, 4.0)), (q, (4.0, 0.0)), (2 * q, (8.0, -4.0)), (3 * q, (4.0, 0.0)), (n, (-4.0, 4.0))],
        # the right foot: back (f0) -> stepped up level (a quarter), stays level while the left steps back and up again, then
        # back again over the last quarter (lifted a little on the way)
        "foot_r": [(0, G_FOOT_R), (q // 2, (-0.15, 0.11, -0.24)), (q, _LEVEL_R), (3 * q, _LEVEL_R), (3 * q + q // 2, (-0.15, 0.11, -0.24)),
                   (n, G_FOOT_R)],
        "foot_l": [(0, G_FOOT_L), (q, level_l), (q + q // 2, (0.15, 0.11, -0.24)), (2 * q, mx(G_FOOT_R)),
                   (2 * q + q // 2, (0.15, 0.11, -0.24)), (3 * q, level_l), (n, G_FOOT_L)],
        "heel_r": [(0, 34.0), (q // 2, 20.0), (q, 4.0), (2 * q, 0.0), (3 * q, 4.0), (3 * q + q // 2, 20.0), (n, 34.0)],
        "heel_l": [(0, 0.0), (q, 4.0), (q + q // 2, 20.0), (2 * q, 34.0), (2 * q + q // 2, 20.0), (3 * q, 4.0), (n, 0.0)],
        "fyaw_r": [(0, 28.0), (q, 12.0), (2 * q, 10.0), (3 * q, 12.0), (n, 28.0)],
        "fyaw_l": [(0, 10.0), (q, 12.0), (2 * q, 28.0), (3 * q, 12.0), (n, 10.0)],
        # the arms: the left across the face while the right foot is back, both before the chest when level, the right across
        # the face while the left foot is back
        "hand_l": [(0, G_HAND_L), (q, (0.12, 0.98, 0.3)), (2 * q, mx(G_HAND_R)), (3 * q, (0.14, 0.96, 0.26)), (n, G_HAND_L)],
        "hand_r": [(0, G_HAND_R), (q, (-0.14, 0.96, 0.26)), (2 * q, mx(G_HAND_L)), (3 * q, (-0.12, 0.98, 0.3)), (n, G_HAND_R)],
        "face_l": [(0, "cap_guard"), (q, "float"), (2 * q, "cap_low"), (3 * q, "float"), (n, "cap_guard")],
        "face_r": [(0, "cap_low"), (q, "float"), (2 * q, "cap_guard"), (3 * q, "float"), (n, "cap_low")],
        "pole_l": [(0, (0.4, -0.7, 0.6)), (q, (0.5, -1.0, 0.0)), (2 * q, (0.4, -0.6, -0.8)), (3 * q, (0.5, -1.0, 0.0)),
                   (n, (0.4, -0.7, 0.6))],
        "pole_r": [(0, (-0.4, -0.6, -0.8)), (q, (-0.5, -1.0, 0.0)), (2 * q, (-0.4, -0.7, 0.6)), (3 * q, (-0.5, -1.0, 0.0)),
                   (n, (-0.4, -0.6, -0.8))],
        "grip_l": [(0, 0.1), (2 * q, 0.3), (n, 0.1)],
        "grip_r": [(0, 0.3), (2 * q, 0.1), (n, 0.3)],
        "knee_r": [(0, (-0.25, -0.3, 1.0)), (q, (-0.3, 0.0, 1.0)), (2 * q, (-0.35, 0.0, 1.0)), (3 * q, (-0.3, 0.0, 1.0)),
                   (n, (-0.25, -0.3, 1.0))],
        "knee_l": [(0, (0.35, 0.0, 1.0)), (q, (0.3, 0.0, 1.0)), (2 * q, (0.25, -0.3, 1.0)), (3 * q, (0.3, 0.0, 1.0)),
                   (n, (0.35, 0.0, 1.0))],
    }
    c = {"length": GINGA_LEN, "loop": True, "base": BASE, "meta": dict(META, hand="both", move="stance", mode="stance", order=0)}
    c.update(keys)
    return c


CLIPS = {
    "ginga": _ginga(),

    # ---------------------------------------------------------------- LMB: Palm as the meia lua de frente (and its alt)
    # the meia lua de frente (air_palm "palm"): the weight onto the front leg, then the rear (right) leg swung up straight
    # out to the right and across the front at the head's height from right to left in a vertical crescent (the palm's cone
    # of wind), the trunk leaning back from it and the guard kept up; down on the left side and stepped back into the ginga.
    # strike_s: the foot across the middle
    "meia_lua": clip(24, dict(hold_s=3 * S, strike_s=9 * S, back_s=14 * S, antic_s=3 * S, follow_s=12 * S, hand="foot_r",
                              move="air_palm", mode="palm", order=1),
        root=[(3, (0.03, -0.09, 0.02)), (6, (0.04, -0.07, 0.04)), (9, (0.03, -0.06, 0.03)), (12, (0.03, -0.07, 0.02)),
              (16, (0.02, -0.1, -0.04))],
        yaw=[(3, -6.0), (6, -24.0), (9, 4.0), (12, 18.0), (16, -4.0)],
        twist=[(3, -6.0), (6, -14.0), (9, 4.0), (12, 10.0), (16, -6.0)],
        hips=[(3, 10.0), (6, 0.0), (9, -6.0), (12, 2.0), (16, 14.0)],
        chest=[(3, 8.0), (6, -4.0), (9, -10.0), (12, -2.0), (16, 8.0)],
        side=[(6, -10.0), (9, -6.0), (12, 6.0), (16, 0.0)],
        head=[(3, -10.0), (9, -4.0), (16, -12.0)],
        foot_r=[(3, (-0.13, 0.1, -0.36)), (6, (-0.45, 1.0, 0.18)), (9, (-0.02, 1.34, 0.38)), (12, (0.35, 1.02, 0.25)),
                (15, (0.05, 0.3, -0.05)), (18, (-0.1, 0.1, -0.35))],
        heel_r=[(3, 20.0), (6, 10.0), (9, -10.0), (12, 0.0), (18, 24.0)],
        knee_r=[(3, (-0.3, 0.0, 1.0)), (6, (-0.6, 0.6, 0.6)), (9, (0.0, 1.0, 0.3)), (12, (0.6, 0.6, 0.6)), (16, (-0.25, -0.3, 1.0))],
        heel_l=[(3, 0.0), (6, 8.0), (9, 12.0), (12, 8.0), (16, 0.0)],
        fyaw_l=[(6, 20.0), (12, 6.0)],
        hand_l=[(6, (0.02, 1.18, 0.34)), (12, (-0.02, 1.2, 0.36))],
        hand_r=[(4, (-0.36, 0.95, 0.0)), (9, (-0.5, 1.15, -0.1)), (13, (-0.4, 1.0, -0.05)), (17, (-0.32, 0.82, -0.14))],
        face_r=[(4, "arms_out"), (13, "arms_out"), (18, "cap_low")],
        pole_r=[(4, (-0.6, -0.6, -0.4)), (13, (-0.6, -0.6, -0.4))],
    ),
    # the meia lua de frente with the front leg (Palm's alt, the next cast within the combo window): the weight back onto the
    # rear leg, the front (left) leg swung up out to the left and across the front from left to right, set back down ahead.
    # strike_s: the foot across the middle
    "meia_lua_front": clip(24, dict(hold_s=3 * S, strike_s=9 * S, back_s=14 * S, antic_s=3 * S, follow_s=12 * S, hand="foot_l",
                                    move="air_palm", mode="palm_alt", order=2),
        root=[(3, (0.0, -0.13, -0.12)), (6, (-0.03, -0.1, -0.12)), (9, (-0.03, -0.095, -0.1)), (12, (-0.02, -0.1, -0.1)),
              (16, (0.0, -0.11, -0.09))],
        yaw=[(3, -16.0), (6, 6.0), (9, -12.0), (12, -26.0), (16, -16.0)],
        twist=[(3, -12.0), (6, 2.0), (9, -8.0), (12, -14.0), (16, -12.0)],
        hips=[(3, 16.0), (6, 2.0), (9, -6.0), (12, 2.0), (16, 14.0)],
        chest=[(3, 10.0), (6, -2.0), (9, -10.0), (12, -2.0), (16, 8.0)],
        side=[(6, 10.0), (9, 6.0), (12, -6.0), (16, 0.0)],
        head=[(3, -12.0), (9, -4.0), (16, -12.0)],
        foot_l=[(3, (0.17, 0.1, 0.08)), (6, (0.48, 1.0, 0.25)), (9, (0.02, 1.29, 0.37)), (12, (-0.32, 1.0, 0.3)),
                (15, (-0.02, 0.3, 0.2)), (18, (0.15, 0.1, 0.15))],
        heel_l=[(3, 10.0), (6, 10.0), (9, -10.0), (12, 0.0), (18, 6.0)],
        knee_l=[(3, (0.3, 0.0, 1.0)), (6, (0.6, 0.6, 0.6)), (9, (0.0, 1.0, 0.3)), (12, (-0.6, 0.6, 0.6)), (16, (0.35, 0.0, 1.0))],
        heel_r=[(3, 24.0), (9, 14.0), (16, 30.0)],
        fyaw_r=[(6, 34.0), (12, 20.0)],
        hand_l=[(4, (0.3, 1.0, 0.1)), (9, (0.45, 1.15, -0.05)), (13, (0.35, 1.05, 0.05)), (17, (0.0, 1.16, 0.36))],
        face_l=[(4, "arms_out"), (13, "arms_out"), (17, "cap_guard")],
        pole_l=[(4, (0.6, -0.6, -0.4)), (13, (0.6, -0.6, -0.4)), (17, (0.4, -0.7, 0.6))],
        hand_r=[(4, (-0.1, 1.12, 0.24)), (9, (-0.08, 1.1, 0.16)), (13, (-0.1, 1.12, 0.22)), (18, (-0.28, 0.84, -0.12))],
        face_r=[(4, "cap_guard"), (14, "cap_guard"), (19, "cap_low")],
        pole_r=[(4, (-0.4, -0.7, 0.6)), (14, (-0.4, -0.7, 0.6))],
    ),

    # ---------------------------------------------------------------- 1: Slice as the martelo, Wind Ball as the bencao
    # the martelo (air_blast "slice"): the rear knee chambered up across the front, the hips turned over and the support foot
    # pivoted, the shin snapped out flat at the chest's height (the instep: the thin blade of wind), the trunk leaning away
    # from it; snapped back to the chamber and stepped back.  strike_s: the leg out
    "martelo": clip(24, dict(hold_s=4 * S, strike_s=8 * S, back_s=12 * S, antic_s=4 * S, follow_s=10 * S, hand="foot_r",
                             move="air_blast", mode="slice", order=3),
        root=[(4, (0.04, -0.08, 0.03)), (8, (0.06, -0.06, 0.04)), (10, (0.05, -0.07, 0.03)), (15, (0.03, -0.1, -0.03))],
        yaw=[(4, 18.0), (8, 52.0), (10, 50.0), (13, 26.0), (17, -6.0)],
        twist=[(4, 6.0), (8, 4.0), (10, 2.0), (14, -6.0)],
        hips=[(4, 6.0), (8, -4.0), (10, -2.0), (15, 14.0)],
        chest=[(4, 6.0), (8, -6.0), (10, -4.0), (15, 8.0)],
        side=[(4, -6.0), (8, -18.0), (10, -16.0), (14, -4.0), (17, 0.0)],
        roll=[(4, -4.0), (8, -10.0), (10, -8.0), (15, 0.0)],
        head=[(4, -10.0), (8, -6.0), (15, -12.0)],
        foot_r=[(2, (-0.1, 0.12, -0.25)), (4, (-0.05, 0.62, 0.18)), (6, (0.05, 1.05, 0.38)), (8, (0.3, 1.25, 0.45)),
                (10, (0.28, 1.23, 0.43)), (12, (0.02, 0.7, 0.22)), (15, (-0.06, 0.25, -0.15)), (18, (-0.1, 0.1, -0.36))],
        heel_r=[(2, 20.0), (4, 30.0), (8, 45.0), (10, 45.0), (13, 20.0), (18, 24.0)],
        knee_r=[(2, (-0.2, 0.0, 1.0)), (4, (0.2, 0.3, 1.0)), (8, (0.4, 1.0, 0.3)), (11, (0.3, 0.6, 1.0)), (15, (-0.25, -0.3, 1.0))],
        fyaw_l=[(4, 40.0), (8, 100.0), (11, 96.0), (15, 30.0)],
        heel_l=[(4, 10.0), (8, 20.0), (11, 18.0), (15, 4.0)],
        hand_l=[(4, (0.06, 1.18, 0.28)), (8, (0.1, 1.16, 0.22)), (10, (0.1, 1.16, 0.22)), (15, (-0.04, 1.17, 0.36))],
        hand_r=[(4, (-0.28, 0.95, 0.02)), (8, (-0.26, 0.92, 0.16)), (12, (-0.28, 0.9, 0.06))],
    ),
    # the bencao (air_blast "ball", Wind Ball, air's big knock): the rear knee drawn up high before the chest, the body leaning
    # back over the standing leg, the sole driven straight out ahead at the chest's height (heel first, the toes up), held,
    # drawn back and stepped back down.  strike_s: the sole out
    "bencao": clip(26, dict(hold_s=5 * S, strike_s=9 * S, back_s=14 * S, antic_s=5 * S, follow_s=11 * S, hand="foot_r",
                            move="air_blast", mode="ball", order=4),
        root=[(3, (0.03, -0.09, 0.0)), (5, (0.04, -0.07, -0.02)), (9, (0.04, -0.07, -0.06)), (12, (0.04, -0.075, -0.05)),
              (17, (0.03, -0.1, -0.05))],
        yaw=[(5, -2.0), (9, 4.0), (12, 2.0), (17, -8.0)],
        twist=[(5, -4.0), (9, 2.0), (17, -8.0)],
        hips=[(5, 4.0), (9, -12.0), (12, -10.0), (17, 12.0)],
        chest=[(5, 2.0), (9, -12.0), (12, -10.0), (17, 8.0)],
        head=[(5, -8.0), (9, 6.0), (12, 4.0), (17, -12.0)],
        foot_r=[(3, (-0.12, 0.15, -0.2)), (5, (-0.08, 0.72, 0.16)), (7, (-0.06, 1.0, 0.4)), (9, (-0.04, 1.1, 0.58)),
                (12, (-0.04, 1.08, 0.56)), (14, (-0.06, 0.66, 0.2)), (17, (-0.08, 0.3, -0.1)), (20, (-0.1, 0.1, -0.36))],
        heel_r=[(3, 20.0), (5, 0.0), (9, -40.0), (12, -38.0), (15, 0.0), (20, 24.0)],
        knee_r=[(3, (-0.2, 0.0, 1.0)), (5, (-0.1, 0.6, 1.0)), (9, (0.0, 1.0, 0.3)), (14, (-0.1, 0.6, 1.0)), (18, (-0.25, -0.3, 1.0))],
        fyaw_l=[(5, 14.0), (12, 16.0)],
        heel_l=[(5, 0.0), (12, 0.0)],
        hand_l=[(5, (0.02, 1.2, 0.28)), (9, (0.02, 1.18, 0.18)), (12, (0.02, 1.18, 0.2)), (15, (-0.04, 1.18, 0.35))],
        hand_r=[(5, (-0.3, 0.98, 0.05)), (9, (-0.4, 1.05, -0.1)), (14, (-0.34, 0.9, -0.1))],
        face_r=[(5, "arms_out"), (13, "arms_out"), (18, "cap_low")],
    ),

    # ---------------------------------------------------------------- 2: Gust as the armada (the signature)
    # the armada (air_gust "gust": a full spinning crescent of wind): the rear foot crossed over ahead of the front one, the
    # body turned on its ball until the back faces the mark and the head looks back over the left shoulder (held: the Gust
    # grows); the turn carried on whole and the left leg swung up straight in an outside crescent at the head's height
    # through the mark, the trunk leaning away; down out of the turn into the ginga.  strike_s: the leg through the mark
    "armada": clip(34, dict(hold_s=7 * S, strike_s=12 * S, back_s=18 * S, antic_s=7 * S, follow_s=15 * S, hand="foot_l",
                            move="air_gust", mode="gust", order=5),
        spin=[(0, 0.0), (4, 40.0), (7, 160.0), (9, 205.0), (12, 285.0), (15, 335.0), (18, 360.0), (34, 360.0)],
        root=[(4, (0.0, -0.1, 0.02)), (7, (0.0, -0.08, 0.0)), (12, (0.0, -0.05, 0.0)), (16, (0.0, -0.09, 0.0)),
              (22, (0.02, -0.11, -0.07))],
        yaw=[(4, -6.0), (7, 0.0), (12, 0.0), (18, -6.0), (24, -12.0)],
        twist=[(4, -4.0), (7, -18.0), (10, -10.0), (12, 6.0), (16, 0.0), (24, -10.0)],
        look=[(4, -20.0), (7, -70.0), (10, -40.0), (12, 0.0), (18, 0.0)],
        hips=[(4, 10.0), (7, 8.0), (12, -6.0), (16, 6.0), (24, 18.0)],
        chest=[(4, 8.0), (7, 6.0), (12, -8.0), (16, 4.0), (24, 10.0)],
        side=[(7, 4.0), (12, 24.0), (15, 12.0), (20, 0.0)],
        head=[(7, -6.0), (12, -2.0), (20, -14.0)],
        foot_r=[(2, (-0.08, 0.12, -0.15)), (4, (0.02, 0.077, 0.06)), (18, (0.02, 0.077, 0.06)), (21, (-0.08, 0.11, -0.25)),
                (24, G_FOOT_R)],
        fyaw_r=[(4, 40.0), (18, 30.0), (24, 28.0)],
        heel_r=[(2, 20.0), (4, 24.0), (16, 24.0), (20, 10.0), (24, 34.0)],
        foot_l=[(4, G_FOOT_L), (7, (0.22, 0.1, -0.08)), (9, (0.4, 0.7, -0.12)), (12, (0.52, 1.36, 0.04)),
                (14, (0.45, 1.05, 0.0)), (16, (0.3, 0.45, 0.02)), (18, (0.16, 0.077, 0.14))],
        heel_l=[(4, 0.0), (7, 20.0), (12, -6.0), (16, 10.0), (18, 0.0)],
        knee_l=[(4, (0.35, 0.0, 1.0)), (9, (0.6, 0.3, 0.8)), (12, (0.3, 1.0, 0.2)), (16, (0.6, 0.0, 0.8)), (19, (0.35, 0.0, 1.0))],
        hand_l=[(4, (0.1, 1.15, 0.3)), (7, (0.32, 1.1, 0.1)), (12, (0.42, 1.0, -0.12)), (16, (0.2, 1.1, 0.25)),
                (21, (0.0, 1.16, 0.34))],
        hand_r=[(4, (-0.2, 1.05, 0.25)), (7, (-0.36, 1.12, 0.15)), (12, (-0.3, 1.25, 0.25)), (16, (-0.25, 1.0, 0.1)),
                (22, G_HAND_R)],
        face_l=[(4, "float"), (7, "arms_out"), (14, "arms_out"), (19, "cap_guard")],
        face_r=[(4, "float"), (7, "arms_out"), (12, "cap_guard"), (16, "cap_guard"), (22, "cap_low")],
        pole_l=[(4, (0.5, -1.0, 0.0)), (12, (0.7, -0.6, -0.2)), (19, (0.4, -0.7, 0.6))],
        pole_r=[(4, (-0.5, -1.0, 0.0)), (12, (-0.4, -0.7, 0.6)), (22, (-0.4, -0.6, -0.8))],
    ),

    # ---------------------------------------------------------------- E: Wind Guard as the esquiva
    # the esquiva (air_shield "shield": a dodge in the ginga's sway): dropped low out to the right under the shot, the knees
    # bent deep, the trunk bent to the right over the right knee, the left forearm over the head and the right hand down by
    # the deck (held: the window); up out of it, the left palm swept out ahead at the chest's height (the wind bounced back
    # along the aim); back into the ginga.  strike_s: the palm out
    "esquiva": clip(26, dict(hold_s=5 * S, strike_s=11 * S, back_s=15 * S, hand="l", move="air_shield", mode="shield", order=6,
                             stills="ready:2;the dodge (the window):6;the palm out:11;back:16"),
        root=[(2, (0.0, -0.13, -0.06)), (5, (-0.16, -0.36, -0.08)), (8, (-0.16, -0.37, -0.08)), (11, (-0.06, -0.18, 0.02)),
              (15, (0.0, -0.12, -0.02))],
        yaw=[(5, -26.0), (8, -26.0), (11, 0.0), (15, -8.0)],
        twist=[(5, -16.0), (8, -16.0), (11, 10.0), (15, -6.0)],
        side=[(5, 26.0), (8, 26.0), (11, 4.0), (15, 0.0)],
        hips=[(5, 26.0), (8, 26.0), (11, 10.0), (15, 16.0)],
        chest=[(5, 18.0), (8, 18.0), (11, 4.0), (15, 9.0)],
        head=[(5, -20.0), (8, -20.0), (11, -10.0)],
        hand_l=[(2, (-0.04, 1.18, 0.34)), (5, (-0.3, 0.98, 0.16)), (8, (-0.3, 0.97, 0.16)), (10, (-0.05, 1.05, 0.38)),
                (11, (0.04, 1.1, 0.5)), (13, (0.05, 1.1, 0.5)), (17, (-0.04, 1.17, 0.36))],
        face_l=[(5, "cap_guard"), (8, "cap_guard"), (11, "push"), (14, "push"), (18, "cap_guard")],
        pole_l=[(5, (0.6, 0.4, 0.4)), (8, (0.6, 0.4, 0.4)), (11, (0.5, -0.8, 0.0)), (16, (0.4, -0.7, 0.6))],
        grip_l=[(9, 0.1), (11, -0.3), (14, -0.3), (17, 0.1)],
        hand_r=[(3, (-0.4, 0.6, -0.06)), (5, (-0.55, 0.35, 0.05)), (8, (-0.55, 0.34, 0.05)), (11, (-0.4, 0.75, -0.08)), (15, (-0.3, 0.82, -0.16))],
        face_r=[(5, "cap_floor"), (8, "cap_floor"), (12, "cap_low")],
        pole_r=[(5, (-0.8, 0.2, -0.4)), (8, (-0.8, 0.2, -0.4)), (12, (-0.4, -0.6, -0.8))],
        foot_r=[(3, (-0.2, 0.1, -0.35)), (5, (-0.42, 0.077, -0.3)), (11, (-0.42, 0.077, -0.3)), (14, (-0.25, 0.1, -0.36)),
                (17, G_FOOT_R)],
        heel_r=[(3, 20.0), (5, 0.0), (11, 0.0), (14, 16.0), (17, 34.0)],
        fyaw_r=[(5, 40.0), (11, 40.0), (17, 28.0)],
        knee_r=[(5, (-0.6, 0.0, 0.8)), (11, (-0.6, 0.0, 0.8))],
        heel_l=[(5, 26.0), (8, 26.0), (11, 6.0), (15, 0.0)],
        knee_l=[(5, (0.2, 0.0, 1.0)), (11, (0.3, 0.0, 1.0))],
    ),

    # ---------------------------------------------------------------- 3: Slip as the au (the game carries the body)
    # the au (evade "slip"): the arms swung up overhead, then a cartwheel over to the left: the left hand and the right set
    # down on the deck in turn as the legs go over in a wide V, the right foot then the left set down beyond, up into the
    # ginga.  strike_s: upside down on the hands
    "au": dict(clip(32, dict(hold_s=3 * S, strike_s=12 * S, back_s=20 * S, antic_s=6 * S, follow_s=16 * S, hand="both",
                             move="evade", mode="slip", order=7, legs_always=1.0),
        cart=[(0, 0.0), (3, 0.0), (6, -25.0), (9, -95.0), (12, -180.0), (15, -265.0), (18, -335.0), (20, -360.0), (32, -360.0)],
        pivot=[(0, (0.0, 0.93, 0.0)), (32, (0.0, 0.93, 0.0))],
        ground=[(0, 0.0), (8, 0.0), (10, 1.0), (14, 1.0), (16, 0.0), (32, 0.0)],
        root=[(3, (0.0, -0.08, -0.02)), (6, (0.0, -0.04, 0.0)), (12, (0.0, 0.0, 0.0)), (18, (0.0, -0.06, 0.0)),
              (24, (0.02, -0.11, -0.07))],
        yaw=[(3, -4.0), (6, 0.0), (18, 0.0), (24, -12.0)],
        twist=[(3, -4.0), (6, 0.0), (18, 0.0), (24, -10.0)],
        hips=[(3, 8.0), (6, 2.0), (12, 0.0), (18, 6.0), (24, 18.0)],
        chest=[(3, 6.0), (6, 0.0), (12, -4.0), (18, 4.0), (24, 10.0)],
        side=[(6, -6.0), (12, 0.0), (18, 4.0), (22, 0.0)],
        head=[(3, -8.0), (9, 10.0), (12, 14.0), (16, 6.0), (22, -14.0)],
        clav_l=[(6, (0.0, -24.0)), (16, (0.0, -24.0)), (22, (8.0, -4.0))],
        clav_r=[(6, (0.0, -24.0)), (16, (0.0, -24.0)), (22, (-4.0, 4.0))],
        hand_l=[(3, (0.2, 1.4, 0.15)), (6, (0.2, 1.7, 0.03)), (8, (0.2, 1.75, 0.03)), (10, (0.2, 1.77, 0.03)), (15, (0.2, 1.77, 0.03)), (19, (0.25, 1.4, 0.15)),
                (23, (-0.04, 1.17, 0.36))],
        hand_r=[(3, (-0.2, 1.4, 0.15)), (6, (-0.2, 1.74, 0.03)), (14, (-0.2, 1.77, 0.03)), (16, (-0.2, 1.71, 0.03)), (19, (-0.3, 1.2, 0.1)),
                (24, G_HAND_R)],
        face_l=[(3, "float"), (6, "cap_up"), (16, "cap_up"), (20, "float"), (23, "cap_guard")],
        face_r=[(3, "float"), (6, "cap_up"), (16, "cap_up"), (20, "float"), (24, "cap_low")],
        pole_l=[(3, (0.6, -0.4, -0.4)), (6, (0.8, 0.2, -0.4)), (16, (0.8, 0.2, -0.4)), (22, (0.4, -0.7, 0.6))],
        pole_r=[(3, (-0.6, -0.4, -0.4)), (6, (-0.8, 0.2, -0.4)), (16, (-0.8, 0.2, -0.4)), (22, (-0.4, -0.6, -0.8))],
        grip_l=[(4, -0.3), (17, -0.3), (22, 0.1)],
        grip_r=[(4, -0.3), (17, -0.3), (22, 0.3)],
        foot_l=[(3, (0.2, 0.077, 0.05)), (7, (0.22, 0.077, 0.02)), (9, (0.3, 0.3, 0.0)), (12, (0.45, 0.32, 0.0)),
                (15, (0.4, 0.3, 0.0)), (18, (0.2, 0.077, 0.02)), (23, G_FOOT_L)],
        foot_r=[(3, (-0.18, 0.077, 0.0)), (6, (-0.3, 0.2, 0.0)), (9, (-0.45, 0.35, 0.0)), (12, (-0.48, 0.32, 0.0)),
                (15, (-0.3, 0.2, 0.0)), (17, (-0.2, 0.077, 0.0)), (24, G_FOOT_R)],
        heel_l=[(3, 0.0), (7, 10.0), (12, -20.0), (17, 0.0), (23, 0.0)],
        heel_r=[(3, 6.0), (6, -10.0), (12, -20.0), (16, 0.0), (24, 34.0)],
        knee_l=[(3, (0.3, 0.0, 1.0)), (12, (0.5, 0.0, 1.0)), (20, (0.35, 0.0, 1.0))],
        knee_r=[(3, (-0.3, 0.0, 1.0)), (12, (-0.5, 0.0, 1.0)), (20, (-0.25, -0.3, 1.0))],
    ), toes="foot"),
}


CLIPS.update({
    # ---------------------------------------------------------------- 2 twice: Pull as the rasteira
    # the rasteira (air_gust "pull": drags whoever it meets toward you): dropped low to the left onto the left hand by the
    # deck, the right leg slid out ahead along the deck to the opponent's ankle (the hook), then hooked back in toward the
    # body (the pull); up into the ginga.  strike_s: the foot hooked at its farthest
    "rasteira": clip(30, dict(hold_s=5 * S, strike_s=9 * S, back_s=15 * S, antic_s=5 * S, follow_s=13 * S, hand="foot_r",
                              move="air_gust", mode="pull", order=8),
        root=[(3, (0.04, -0.22, -0.08)), (5, (0.13, -0.56, -0.06)), (9, (0.13, -0.6, -0.02)), (13, (0.11, -0.58, -0.05)),
              (18, (0.05, -0.28, -0.08)), (23, (0.02, -0.16, -0.1))],
        yaw=[(5, 10.0), (9, 6.0), (13, 0.0), (20, -12.0)],
        twist=[(5, 8.0), (9, 4.0), (13, -4.0), (20, -12.0)],
        hips=[(5, 44.0), (9, 40.0), (13, 42.0), (20, 24.0)],
        chest=[(5, 22.0), (9, 18.0), (13, 20.0), (20, 12.0)],
        side=[(5, -34.0), (9, -32.0), (13, -33.0), (20, 0.0)],
        head=[(5, -26.0), (9, -24.0), (13, -24.0), (20, -18.0)],
        hand_l=[(3, (0.22, 0.6, 0.15)), (5, (0.34, 0.09, 0.06)), (13, (0.34, 0.09, 0.06)), (17, (0.25, 0.55, 0.15)), (22, G_HAND_L)],
        face_l=[(4, "cap_floor"), (14, "cap_floor"), (20, "cap_guard")],
        pole_l=[(4, (0.8, 0.0, -0.4)), (14, (0.8, 0.0, -0.4)), (20, (0.4, -0.7, 0.6))],
        grip_l=[(4, -0.2), (14, -0.2), (20, 0.1)],
        hand_r=[(5, (0.0, 0.75, 0.3)), (13, (0.02, 0.75, 0.28)), (22, G_HAND_R)],
        face_r=[(5, "cap_guard"), (14, "cap_guard"), (22, "cap_low")],
        pole_r=[(5, (-0.4, -0.7, 0.6)), (14, (-0.4, -0.7, 0.6)), (22, (-0.4, -0.6, -0.8))],
        foot_r=[(3, (-0.14, 0.1, -0.35)), (5, (-0.16, 0.09, 0.05)), (9, (-0.06, 0.08, 0.62)), (11, (0.02, 0.08, 0.55)),
                (13, (-0.04, 0.08, 0.3)), (17, (-0.1, 0.1, -0.1)), (22, G_FOOT_R)],
        heel_r=[(3, 20.0), (5, 0.0), (9, -20.0), (13, -10.0), (18, 10.0), (22, 34.0)],
        fyaw_r=[(5, 0.0), (9, -40.0), (12, -50.0), (16, 0.0), (22, 28.0)],
        knee_r=[(5, (-0.3, 1.0, 0.4)), (9, (-0.3, 1.0, 0.3)), (13, (-0.2, 1.0, 0.6)), (18, (-0.25, -0.3, 1.0))],
        foot_l=[(5, (0.24, 0.077, 0.02)), (14, (0.24, 0.077, 0.02)), (20, G_FOOT_L)],
        heel_l=[(5, 30.0), (14, 30.0), (20, 0.0)],
        knee_l=[(5, (0.8, 0.2, 0.6)), (14, (0.8, 0.2, 0.6)), (20, (0.35, 0.0, 1.0))],
    ),

    # ---------------------------------------------------------------- the jab string's Pop as the meia lua de compasso
    # the meia lua de compasso (air_palm "pop", the design doc's half-moon spin): turned to the right as the trunk folds
    # down over the left leg and both hands go to the deck, the head looking back under the arm at the mark (held); then a
    # whole turn on the left foot with the right leg swung up and round behind in a big circle, the heel through the mark at
    # the head's height; up out of the turn into the ginga.  strike_s: the heel through the mark
    "compasso": clip(32, dict(hold_s=7 * S, strike_s=12 * S, back_s=17 * S, antic_s=7 * S, follow_s=15 * S, hand="foot_r",
                              move="air_palm", mode="pop", order=9),
        spin=[(0, 0.0), (4, -40.0), (7, -110.0), (10, -200.0), (12, -260.0), (15, -330.0), (17, -360.0), (32, -360.0)],
        root=[(4, (0.0, -0.28, 0.0)), (7, (0.0, -0.45, 0.02)), (12, (0.0, -0.43, 0.02)), (16, (0.0, -0.32, 0.0)),
              (22, (0.02, -0.16, -0.1))],
        yaw=[(4, 0.0), (17, 0.0), (24, -14.0)],
        hips=[(4, 40.0), (7, 70.0), (12, 66.0), (16, 46.0), (24, 24.0)],
        chest=[(4, 18.0), (7, 30.0), (12, 28.0), (16, 18.0), (24, 12.0)],
        side=[(7, -10.0), (12, -16.0), (16, -6.0), (22, 0.0)],
        twist=[(4, -6.0), (7, 14.0), (12, 6.0), (16, 0.0), (24, -12.0)],
        look=[(4, 20.0), (7, 70.0), (10, 50.0), (12, 0.0), (17, 0.0)],
        head=[(4, -20.0), (7, -36.0), (12, -30.0), (17, -22.0), (24, -18.0)],
        hand_l=[(3, (0.12, 0.72, 0.3)), (5, (0.15, 0.36, 0.32)), (7, (0.16, 0.09, 0.3)), (11, (0.16, 0.09, 0.3)), (14, (0.2, 0.55, 0.3)),
                (21, G_HAND_L)],
        hand_r=[(3, (-0.12, 0.72, 0.3)), (5, (-0.11, 0.36, 0.34)), (7, (-0.1, 0.09, 0.33)), (10, (-0.1, 0.09, 0.33)), (12, (-0.14, 0.2, 0.3)),
                (14, (-0.25, 0.55, 0.2)), (22, G_HAND_R)],
        face_l=[(4, "cap_floor"), (11, "cap_floor"), (19, "cap_guard")],
        face_r=[(4, "cap_floor"), (11, "cap_floor"), (20, "cap_low")],
        pole_l=[(4, (0.8, 0.0, -0.4)), (11, (0.8, 0.0, -0.4)), (19, (0.4, -0.7, 0.6))],
        pole_r=[(4, (-0.8, 0.0, -0.4)), (11, (-0.8, 0.0, -0.4)), (20, (-0.4, -0.6, -0.8))],
        grip_l=[(4, -0.2), (11, -0.2), (19, 0.1)],
        grip_r=[(4, -0.2), (11, -0.2), (20, 0.3)],
        foot_l=[(3, (0.08, 0.077, 0.08)), (16, (0.08, 0.077, 0.08)), (21, G_FOOT_L)],
        fyaw_l=[(3, 10.0), (16, 10.0), (21, 10.0)],
        heel_l=[(3, 10.0), (12, 16.0), (17, 6.0), (21, 0.0)],
        knee_l=[(3, (0.4, 0.0, 1.0)), (16, (0.4, 0.0, 1.0))],
        foot_r=[(4, (-0.2, 0.15, -0.45)), (7, (-0.35, 0.5, -0.5)), (10, (-0.6, 0.93, -0.2)), (12, (-0.62, 1.0, 0.08)),
                (14, (-0.5, 0.75, 0.25)), (17, (-0.3, 0.2, 0.05)), (21, (-0.15, 0.1, -0.3)), (24, G_FOOT_R)],
        heel_r=[(4, 30.0), (7, 10.0), (12, -30.0), (15, -10.0), (19, 10.0), (24, 34.0)],
        knee_r=[(4, (-0.3, -0.5, 0.8)), (10, (-0.6, -0.3, -0.6)), (12, (-0.3, 0.2, -1.0)), (16, (-0.5, -0.3, 0.6)),
                (21, (-0.25, -0.3, 1.0))],
    ),
})

if __name__ == "__main__":
    kit.main(STYLE, ELEMENT, CLIPS)
