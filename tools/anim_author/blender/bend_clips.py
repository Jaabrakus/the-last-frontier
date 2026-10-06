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
The fourth set (2026-10-06, round 3's first playable: the % ring's air and hit states; the CLIPS table's SET4 part, authored
the same way; the airborne ones start and end on AIR, the plain fall's first pose, and the landings start on its arms, so they
hand over to each other; revised the same day after the review: the loops keyed at every frame from their typed functions):
  tumble             a long launch's loop: one whole backward somersault a loop, typed as a turn rate (tumble_at): flung wide
                     open while the turn is slow, pulled into a tuck as it quickens, the tuck held through the fastest part and
                     the upright pass (a ball, never a man standing), the arms two frames behind the legs, the head two behind
                     the trunk, the root drifting up while open and down in the tuck
  flinch             a light hit taken on the feet (upper mask, 0.3 s): the chest snapped back, the head a beat later, the
                     reversal spread over three frames into the cringe: the shoulders hunched, the elbows up and out and both
                     hands up before the face; eased out to the stand
  jump_double        the tucked knees-up spring: a gather, the legs kick down hard against the air (the body long), the arms
                     swing up and the knees snap up under the seat, the hands pulled in onto the knees (a ball, held a beat),
                     opened out into the fall, the legs, then the arms, then the face
  fall               the athlete in control in the air (a loop): bowed a little, the arms open wide in a true balance, the legs
                     turning a bicycle that reads from the stands, the arms see-sawing behind the chest; fall_fast the tucked
                     arrow (a loop): long and straight, the arms swept back in a narrow V, the knees drawn up a little with the
                     feet together, a wind shiver twice a loop
  helpless           spent (a loop, reads apart from the fall at a glance): the arms trailing high over the head in a tall V,
                     the back arched and the head thrown back, the legs hanging long and limp, the whole body always lying back
                     off the vertical and wallowing round a cone
  air_dodge          the sharp tucked twist: the snap in from the middle out (the hips and the chest, the knees, the arms crossed
                     before the chest, the head), the head leading the turn and landing first, the tuck tightening at its
                     fastest, opened out
  air_legs           the legs only (lower mask, a loop): both knees drawn up under any cast let go in the air, the toes
                     flickering, the trailing leg on a beat of its own
  land_light         the touchdown: the knees give, the hips sit back, the arms come down from the balance; up to the stand
  land_heavy         the punish window: slammed into a deep squat, the palms slapped onto the thighs, the chest sagging after
                     them and the head hanging last, held; then a slow heavy push up off the thighs, a settle at the stand
  Pass 3 (the same day, the critic's second notes): the tumble's arms fully flung at the seam (clear of the head); the
  flinch's cringe a forearm guard (loose fists before the chin, the chin tucked); the double jump's gather over f0-f2 and its
  push at f3 (an arch, the arms in a V behind the hips), the arms on one loop up onto the knees; the fall's arms softer and
  unmirrored; the fast fall a spike (pitched 12 degrees into the dive, the arms swept back and out, the legs long and alike);
  the helpless fall lying back 22 degrees or more at every frame, its arms trailing up from the shoulders with bent elbows and
  limp hands, never level, the head lolling behind the chest, the knees soft and one foot trailing; the air legs in two
  shapes (the right knee high, the left heel back under the seat); the heavy landing 16 frames, its push up eased and its
  parts settling at different frames (back_s unchanged).
The fifth set (2026-10-06, round 3's first playable: the deck's edge and the ground dodges; the CLIPS table's SET5 and SET5B
parts, authored the same way; the edge clips keyed in the hang's frame: the lip LIP_Y over the origin and LIP_Z ahead):
  edge_grab          caught high off the face, the hands slapped flat on the deck, the body sagging as the legs swing in
                     under the lip onto the face; settled into the hang
  edge_hang          the hang (a loop): the forearms across the coping, the palms flat on the deck, the head and the shoulders
                     well over the lip, the balls of the feet on the face; a slight sway, a breath, a glance
  edge_climb         a mantle: pressed up onto straight arms, the right knee laid on the deck, the left foot up, stood up
                     CLIMB_IN in; edge_roll sprung over the lip into a forward roll along the deck (the code carries him in)
                     and up; edge_jump a coil and a hands-push spring straight up onto the fall; edge_attack pressed up into
                     a deep crouch, the straight right leg swept round low along the deck, stood up
  roll_f, roll_b     the ground rolls (facing kept): a tight ball turned over forward / back on the deck (pivot, ground);
  roll_side          roll_side the ball rolled over sideways along its spine to the right (and its twin); duck a deep sway
                     down and back with the forearms up, held, a return
  pivot              the point the flip and the cart turn the figure about (default the hips' height over the stand's middle)
  ground, floor      the share (0-1) of the gap between the floor (the clip's `floor`, 0 by default) and the body's lowest
                     surface (SURF: typed radii round the joints) the whole figure is shifted by: a roll's ball on the deck
  --points prints each frame's key joints and the lowest surface.
  Pass 2 (the same day, the critic's notes): the hang a climber's Z (the hips 0.35 m off the face, the knees folded to a
  right angle, the feet high on the face, the shoulders shrugged under the load) with a sway that reads (5 cm, the head a
  quarter loop behind, the heels re-pressing in turn, a grip flex, a look along the deck); the grab's catch sagging the chin
  to the lip with a pendulum in and out (baked four times a frame: substeps); the climb a pool-edge mantle (the knee set on
  the nose, the shin hanging, then laid back across the nose, a held load, the hips over the left foot, a rise carried
  past); the jump's hands on the deck through a real coil and push (lift, lift_w: the code's carry taken back) and the legs
  kicked straight off the face; the roll in's apex over the hands, the palms planted ahead and the right shoulder blade
  (twist) taking the deck with the head turned and tipped away; the sweep carried across past the left foot, the right arm
  whipping against it; the rolls' palms on the deck at the drop and the shoulder roll's diagonal, the back roll's palms
  pushing the head clear, the side roll tipped onto the right shoulder with the knees across the body and the left leg
  landing first; the duck 0.55 m down and 0.3 m back with the forearms by the head and a moving hold.
  lift, lift_w       (the edge jump) the code's lift (vy, g) from the clip's start, and the share of it taken back off the
                     whole figure at each frame (a uniform shift: the keys are the body over the code's carry)
  substeps           bake the clip that many times a frame (meta fps in the json; the installer keys it at that rate)
  --fit lists the frames where a limb is within SLACK of straight (and its place pulled in) and the striking limb's slack
  at strike_s (and its place carried out to STRIKE_SLACK).
The sixth set (2026-10-06, round 3's P2: the Rises and the recoveries; the CLIPS table's SET6 part, authored the same way):
  rise_earth         Pillar: the legs reach down for the column, slammed into a deep Hung Gar horse on its top with both fists
                     driven down, leant 20 degrees with the column, sunk as it drives, thrown off its top (the arms flung up)
  rise_water         Fountain: a soft sink, then standing tall on the column, both arms swung round big circles about the
                     shoulders (water_swirl) into tai chi's golden rooster: one knee drawn high, the right hand high overhead,
                     the left pressed down by the hip
  rise_fire          Jet: the hover tell (the knees drawn, the fists chambered at the hips, the roar), then the burst: long and
                     straight along it, leant into the flight, the right fist punched up leading (Northern Shaolin's rising punch)
  rise_air           Updraft: wound up, then one whole turn as a spinning crane, unfurled into the glide (glide_at, a loop from
                     meta loop_from_s to the end): laid forward into the wind with the arms spread as wings, banking
  edge_scramble      the hands slapped on the deck's face and over the lip, the feet scrabbling, hauled up onto HANG exactly
  tech, tech_roll    the breakfall: a three-point slap on the deck (the right knee down, the right palm slapped flat) and up;
                     the same slap carried on into the side roll (_roll("side")'s keys from its fourth frame; and its twin)
  tech_wall          flung into a wall (meta wall_z), the soles and the palms flat on it, folded deep, then shoved off it
  lie                dazed on his back (lie_at, a loop), the right knee up, breathing; getup the carp skip-up (a kip) from it;
                     getup_roll a whole log roll (barrel) and up (and its twin); getup_attack a crab sweep of the right leg
  knock_spiked       folded by the hit, then pitched head-down into the plunge, the arms dragged up behind, the legs trailing
  knock_bounce       flat on the back onto the deck, the limbs slamming after it, bounced up in a loose V, back onto LIE
  barrel             the figure turned about its own long axis after the flip and the cart (a log roll; + to the left)
  toes               "foot": the toes kept with the foot (a sole laid flat on the deck while the figure lies)
  _wclip             a clip typed in the deck's frame (the pelvis's place, the turn, the palms and ankles on the deck), turned
                     back into the figure's own keys at every frame; _heel_key the foot key that lands the ankle exactly
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
  flip        (an airborne figure) the whole keyed body turned about the hips' height over the stand's middle: its somersault
              (+ the head forward and down); cart its cartwheel (+ the left side up); "flip_turns": whole turns spread evenly
              over the clip under the flip keys (a tumbling loop); every place and way the keys give turns with the body
  tilt        the neck's and head's side tilt (a lolling head; only a clip that keys it)
A clip with "bones": "legs" bakes only the legs' bones (a lower-body layer: no root track).
A clip with "hands_from": "shoulder" keys hand_r/l as the arm's reach from its shoulder in the turned chest's frame (a limp
arm carried whole by the spine's sway, its elbow keeping its bend), its facings and poles in that frame too.
--angles prints each frame's elbow and knee bends (degrees, 0 straight) for checking a bend the keys mean to hold.
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
    "dive": ((0.0, -0.87, -0.5), (0.98, 0.0, 0.0)),          # swept back along the side in the dive, the wrist straight, palm in
    "balance": ((-0.85, -0.15, 0.45), (0.0, -1.0, 0.1)),     # out to the side for the balance, the palm down
    "cross": ((0.85, 0.35, 0.3), (0.0, 0.1, -1.0)),          # crossed before the chest in the dodge, the palm in to the body
    "knee": ((0.1, -0.55, 0.83), (0.0, -1.0, 0.0)),          # braced on the knee, the fingers forward and down, the palm on it
    "jolt": ((-0.25, 0.4, 0.88), (0.0, -0.9, 0.4)),          # jolted up and out by a hit, the fingers forward, the palm down
})


def _loop(length, fn, keys=None, step=1):
    """A loop's channels from fn(phase) -> {channel: value}: each sampled every `step` frames (the seam's first again at the
    last; every frame by default, so a second harmonic and a lag of a frame or two keep their shape). `keys` limits them."""
    frames = list(range(0, length + 1, step))
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
## little bowed over the hips, the arms open wide in a true balance a little over the shoulders' height (the elbows soft, the
## palms down), the legs ready under him (the right knee ahead, the left foot trailing back), the toes hanging; paddling:
## the legs turn a bicycle big enough to read from the stands, the chest breathes behind them, the arms see-saw two frames
## behind the chest (opposite each other) and the head settles last; the head and the hands carry a smaller second beat of
## their own so the extremities never ride one sine with the chest.
def fall_at(a):
    lag = 2 * math.pi * 2 / 20   # two frames of the 20
    return {
        "root": (0.0, 0.008 * _s(a), 0.0),
        "hips": 7.0 + 1.5 * _s(a), "chest": 5.0 + 3.0 * _s(a, -0.7), "roll": 1.5 * _s(a, -1.2), "twist": 3.0 * _s(a, -0.9),
        "head": 7.0 + 2.0 * _s(a, -1.5) + 0.8 * _s(2 * a, -2.2),
        "clav_r": (2.0 * _s(a, -1.4), -12.0 + 3.0 * _s(a, -1.4)), "clav_l": (-2.0 * _s(a, -1.4), -12.0 - 3.0 * _s(a, -1.4)),
        # (pass 3: a touch lower and forward, the elbows broken downward, the fingers relaxed, and the two hands see-sawing
        # by different amounts, so the arms are a fighter's balance, never an airplane's mirror-perfect wings)
        "hand_r": _add((-0.6, 1.3, 0.1), (0.025 * _c(a, -0.7 - lag), 0.07 * _s(a, -0.7 - lag) + 0.028 * _s(2 * a, -2.4),
                                             0.03 * _c(a, -0.7 - lag))),
        "hand_l": _add((0.6, 1.31, 0.08), (-0.02 * _c(a, -0.7 - lag + math.pi), 0.05 * _s(a, -0.7 - lag + math.pi)
                                           + 0.022 * _s(2 * a, -1.0), -0.025 * _c(a, -0.7 - lag + math.pi))),
        "face_r": "balance", "face_l": "balance",
        "pole_r": (-0.6, -0.5, -0.4), "pole_l": (0.6, -0.5, -0.4),
        "grip_r": 0.15, "grip_l": 0.15,
        "foot_r": _add((-0.14, 0.27, 0.1), (0.0, 0.08 * _s(a), 0.13 * _c(a))),
        "foot_l": _add((0.14, 0.33, -0.1), (0.0, -0.08 * _s(a), -0.13 * _c(a))),
        "heel_r": 26.0 + 6.0 * _s(a, -0.5), "heel_l": 30.0 - 6.0 * _s(a, -0.5),
        "fyaw_r": 6.0, "fyaw_l": 8.0,
        "knee_r": (-0.2, 0.15, 1.0), "knee_l": (0.2, 0.1, 1.0),
    }


AIR = dict(STAND)
AIR.update({k: _rv(v) if not isinstance(v, str) else v for k, v in fall_at(0.0).items()})
AR, AL = AIR["hand_r"], AIR["hand_l"]
AFR, AFL = AIR["foot_r"], AIR["foot_l"]


## The helpless fall (own-bend-helpless, a loop of 24 frames): spent and limp, nothing like the fall: the arms trailing high
## over the head as the air drags them (a tall V, the elbows soft, the shoulders hunched up under them), the back arched and
## the head thrown back looking up, the legs hanging long and limp under him (the knees soft, the toes dangling); the whole
## body always lying back off the vertical (a body falling, never a man standing) and wallowing slowly round a cone (a slow
## pitch and roll a quarter turn apart, and a lazy turn), the limbs lagging it one after another.
def _yawv(v, deg):
    """A place or a way in the character's frame turned about the vertical by deg (+ to the left), as the yaw turns the body."""
    r = math.radians(deg)
    return (v[0] * math.cos(r) + v[2] * math.sin(r), v[1], -v[0] * math.sin(r) + v[2] * math.cos(r))


## Pass 3: lying back 22 degrees or more at every frame (-34 +/- 12: never near the upright "hooray"), the arms trailing up
## in the WORLD (the hands keyed ahead of the shoulders in the body's frame, so with the body lying back they hang straight up
## on the drag), the elbows bent about 30-50 degrees, the hands dangling from the wrists (the palms back and down, the fingers
## curled), never level (the left 0.12 m lower and on its own beat), the head lolling a few frames behind the chest's side bend,
## the knees soft and the left foot trailing: dead weight.
FACING["limp_up"] = ((0.1, 0.94, -0.3), (0.05, -0.3, -0.95))   # a limp hand on a trailing arm, flopped back, the palm back and down
HELPLESS_LAG = 2 * math.pi * 3 / 24                            # the head three frames behind the chest's side bend
## The feet's places (the ankles' before the heel lift): the right knee bent about 15 degrees, the left about 25 and trailing.
HELPLESS_FOOT_R = (-0.15, 0.085, 0.01)
HELPLESS_FOOT_L = (0.16, 0.12, -0.21)


def _swing(v, u, w):
    """The arm's reach v swung u and w (m) across its own line at the hand, its length kept (a limp arm's sway that never
    pumps the elbow straight and bent)."""
    n = math.sqrt(sum(x * x for x in v))
    d = [x / n for x in v]
    t1 = (d[1], -d[0], 0.0)                     # across the line, level (d x the forward axis)
    m = math.sqrt(t1[0] ** 2 + t1[1] ** 2)
    t1 = (t1[0] / m, t1[1] / m, 0.0)
    t2 = (d[1] * t1[2] - d[2] * t1[1], d[2] * t1[0] - d[0] * t1[2], d[0] * t1[1] - d[1] * t1[0])
    p = [v[i] + u * t1[i] + w * t2[i] for i in range(3)]
    k = n / math.sqrt(sum(x * x for x in p))
    return tuple(x * k for x in p)


def helpless_at(a):
    yaw = 22.0 * _s(a, 0.6)
    side_ph = 0.67                                               # the chest's side bend 6 cos(a - 0.9) as a sine's phase
    return {
        "flip": -34.0 + 12.0 * _s(a), "cart": 24.0 * _c(a), "yaw": yaw,
        "root": (0.0, 0.03, 0.0),
        "hips": -9.0 + 2.0 * _s(a, -0.5), "chest": -14.0 + 5.0 * _s(a, -1.0), "side": 6.0 * _s(a, side_ph),
        "twist": 8.0 * _s(a, -1.0), "head": -20.0 + 7.0 * _s(a, -1.6), "look": 10.0 * _s(a, -1.4),
        "tilt": 10.0 * _s(a, side_ph - HELPLESS_LAG),
        "clav_r": (-6.0, -26.0 + 5.0 * _s(a, -1.8)), "clav_l": (-6.0, -24.0 - 5.0 * _s(2 * a, -1.8)),
        # (the arms keyed as their reach from the shoulders in the chest's frame ("hands_from": the body's sway carries them
        # whole): up and a little ahead of the lying-back body, so in the world they trail straight up on the drag, the elbows
        # bent about 35-50 degrees; the left lower and out wider, on its own beat with a second
        # harmonic, so the V is never level or mirrored)
        "hand_r": _swing((-0.174, 0.377, 0.24), 0.05 * _s(a, 0.41), 0.04 * _c(a, 0.41)),
        "hand_l": _swing((0.34, 0.24, 0.2), 0.045 * _s(a, 3.55) + 0.02 * _s(2 * a, 1.0), 0.035 * _c(a, 3.55)),
        "face_r": "limp_up", "face_l": "limp_up",
        "pole_r": (-1.0, -0.4, -0.3), "pole_l": (1.0, -0.4, -0.3),
        "grip_r": 0.05 + 0.08 * _s(a, -2.2), "grip_l": 0.08 + 0.08 * _s(2 * a, 1.0),
        # the legs hang limp, the knees soft (the right a little, the left more), the left foot trailing back; each swings a
        # little after the hips that carry it; the toes dangling, not pointed
        "foot_r": _yawv(_add(HELPLESS_FOOT_R, (0.02 * _s(a, -0.6), 0.01 * _s(a, -0.6), 0.03 * _c(a, -0.6))), yaw),
        "foot_l": _yawv(_add(HELPLESS_FOOT_L, (-0.02 * _s(a, 2.2), 0.01 * _s(a, 2.2), 0.03 * _c(a, 2.2))), yaw),
        "heel_r": 34.0 + 6.0 * _s(a, -1.2), "heel_l": 30.0 + 6.0 * _s(a, 1.9),
        "fyaw_r": 14.0 - yaw, "fyaw_l": 18.0 + yaw,
        "knee_r": _yawv((-0.3, 0.0, 1.0), yaw), "knee_l": _yawv((0.35, 0.0, 1.0), yaw),
    }


## The air legs (own-bend-air-legs, a loop of 24 frames on the legs' bones only): an aerial tuck in two different shapes: the
## right knee raised high and ahead, the left heel drawn back under the seat (its shin angled back, never hanging under a
## level thigh like a man sat on a chair), the toes pointed and flickering; the trailing leg carries a second beat of its own
## so the two never mirror one sine.
def air_legs_at(a):
    return {
        "foot_r": _add((-0.13, 0.58, 0.2), (0.0, 0.045 * _s(a), 0.06 * _c(a))),
        "foot_l": _add((0.14, 0.5, -0.08), (0.0, -0.045 * _s(a, 0.8) + 0.018 * _s(2 * a, 0.3),
                                            -0.05 * _c(a, 0.8) + 0.02 * _c(2 * a))),
        "heel_r": 34.0 + 8.0 * _s(a, -0.6), "heel_l": 45.0 + 8.0 * _s(a, 1.0) + 3.0 * _s(2 * a),
        "fyaw_r": 4.0, "fyaw_l": 10.0,
        "knee_r": (-0.12, 0.3, 1.0), "knee_l": (0.18, 0.3, 1.0),
    }


## The fast fall (own-bend-fall-fast, a loop of 16 frames): the tucked arrow: the body long and straight, only a little bowed,
## the face up enough to watch the landing, both arms swept straight back from the shoulders in a narrow V (the elbows nearly
## straight, the palms back), the knees drawn up a little with the feet pressed together under him, the toes pointed: a
## compact spike at a glance, against the fall's wide balance and the helpless fall's tall V; the wind shivers him twice a
## loop (the hands a frame behind the chest, the head two).
FACING["swept"] = ((-0.08, -0.75, -0.66), (0.6, 0.53, -0.6))   # swept back from the shoulder, the fingers trailing, the palm back


## Pass 3: the spike: the whole body pitched 12 degrees into the dive (flip), the head down to watch the landing, the arms
## swept back AND out from the shoulders (an arrowhead from behind, a long back-swept line from the side), the legs long and
## straight together with the same small bend (neither knee leads), the toes pointed; the wind buffets him: the chest shivers
## twice a loop, the hands 0.05 m two frames behind it, the head shaken at the third harmonic.
FALL_FAST_FOOT = (0.05, 0.062, -0.1)   # the left ankle's place before the heel lift (the right's mirrored): the legs near straight


def fall_fast_at(a):
    b = 2 * a
    fr = 2 * math.pi * 2 / 16          # a frame at the shiver's two beats a loop
    fx, fy, fz = FALL_FAST_FOOT
    return {
        "flip": 12.0, "root": (0.0, 0.03, 0.0),
        "hips": 2.0, "chest": 2.0 + 3.0 * _s(b), "head": 14.0 + 2.0 * _s(b, -fr), "roll": 0.8 * _s(b, 1.0),
        "look": 4.0 * _s(3 * a, 0.5), "twist": 1.5 * _s(a, 0.4),
        "clav_r": (-26.0, 6.0), "clav_l": (-26.0, 6.0),
        "hand_r": _add((-0.388, 1.055, -0.347), (0.012 * _s(a, 1.0), 0.05 * _s(b, -2 * fr), 0.02 * _c(b, -2 * fr))),
        "hand_l": _add((0.388, 1.055, -0.347), (-0.012 * _s(a, 2.0), 0.05 * _s(b, -2 * fr + 0.6), 0.02 * _c(b, -2 * fr + 0.6))),
        "face_r": "swept", "face_l": "swept",
        "pole_r": (-0.6, 0.2, -1.0), "pole_l": (0.6, 0.2, -1.0),
        "grip_r": 0.15, "grip_l": 0.15,
        "foot_r": _add((-fx, fy, fz), (0.0, 0.006 * _s(b, -0.5), 0.01 * _c(b, -0.5))),
        "foot_l": _add((fx, fy, fz), (0.0, 0.006 * _s(b, 1.5), 0.01 * _c(b, 1.5))),
        "heel_r": 72.0 + 3.0 * _s(b, -0.8), "heel_l": 72.0 + 3.0 * _s(b, 0.2), "fyaw_r": 0.0, "fyaw_l": 0.0,
        "knee_r": (0.0, 0.0, 1.0), "knee_l": (0.0, 0.0, 1.0),
    }


def _lerp(p, q, t):
    if isinstance(p, (tuple, list)):
        return tuple(x + (y - x) * t for x, y in zip(p, q))
    return p + (q - p) * t


def _win(f, up0, up1, dn0, dn1, n):
    """A window round a loop of n frames: 0, eased up from up0 to up1, 1 until dn0, eased down to 0 by dn1 (wraps)."""
    d = (f - up0) % n
    r, h, fl = up1 - up0, dn0 - up0, dn1 - up0
    if d < r:
        x = d / r
        return x * x * (3 - 2 * x)
    if d <= h:
        return 1.0
    if d < fl:
        x = (d - h) / (fl - h)
        return 1.0 - x * x * (3 - 2 * x)
    return 0.0


## The tumble's turn (own-bend-tumble, 24 frames, one whole backward somersault a loop): the figure's own pitch turns at
## TUMBLE_RATE deg a frame on average, swinging by TUMBLE_SWING either way, fastest at TUMBLE_FAST (the middle of the tuck)
## and slowest twelve frames away (the open, flung pose): the angular momentum read of a thrown body. The somersault channel
## is that pitch less half the trunk's own curl (the hips' bow and half the chest's), so the curl into the tuck adds to the
## turn instead of fighting it. TUMBLE_LEAD sets where in the turn the loop starts (lying back, just after the upright ball).
TUMBLE_RATE = 15.0
TUMBLE_SWING = 9.0
TUMBLE_FAST = 17.0
TUMBLE_LEAD = -15.0
## The root's drift (m, the world's up): up while open, down in the tuck, so the turn has no fixed axle through the hips.
TUMBLE_DRIFT = 0.03


def tumble_at(f):
    n = 24
    a = 2 * math.pi * f / n
    tl = _win(f, 8, 14, 21, 24, n)            # the legs: drawn up f8-14, held through the upright pass, flung out f21-24
    ta = _win(f, 10, 16, 20, 24, n)           # the arms: onto the shins f10-16, flung fully out f20-f24 (open at the seam)
    tt = _win(f, 9, 15, 21, 25, n)            # the trunk's curl between them
    th = _win(f - 2, 9, 15, 21, 25, n)        # the head two frames behind the trunk (it whips through)
    o = math.sin(math.pi * f / 12.0) ** 2     # the open pose's drift while flung (the arms swept back as he turns)
    hips = _lerp(-10.0 - 4.0 * o, 24.0, tt)
    chest = _lerp(-14.0 - 4.0 * o, 26.0, tt)
    pitch = -TUMBLE_RATE * f - TUMBLE_SWING * n / (2 * math.pi) * math.sin(2 * math.pi * (f - TUMBLE_FAST) / n) + TUMBLE_LEAD
    flip = pitch + TUMBLE_RATE * f - 0.5 * (hips + 0.5 * chest)
    total = math.radians(-TUMBLE_RATE * f + flip)
    d = TUMBLE_DRIFT - 2 * TUMBLE_DRIFT * tt
    sa, sl = math.sin(math.pi * ta), math.sin(math.pi * tl)
    return {
        "flip": flip, "cart": 14.0 * _s(a, 0.8), "twist": 10.0 * _s(a, 1.6),
        # (the world's up drift carried into the turned body's frame)
        "root": (0.0, d * math.cos(total), -d * math.sin(total)),
        "hips": hips, "chest": chest, "head": _lerp(-18.0 - 3.0 * o, 20.0, th), "side": _lerp(4.0 + 2.0 * o, -3.0, tt),
        "clav_r": _lerp(_lerp((-6.0, -22.0), (-8.0, -26.0), o), (10.0, 6.0), ta),
        "clav_l": _lerp(_lerp((-4.0, -18.0), (-8.0, -24.0), o), (10.0, 6.0), ta),
        # (each hand on an arc out round the body between the flung pose and the shins, not through the chest)
        "hand_r": _add(_lerp(_lerp((-0.6, 1.38, -0.24), (-0.6, 1.32, -0.29), o), (-0.17, 0.86, 0.42), ta),
                       (-0.13 * sa, 0.06 * sa, 0.05 * sa)),
        "hand_l": _add(_lerp(_lerp((0.58, 1.34, -0.17), (0.57, 1.3, -0.23), o), (0.2, 0.9, 0.4), ta),
                       (0.13 * sa, 0.06 * sa, 0.05 * sa)),
        "pole_r": _lerp((-0.3, -0.8, -0.6), (-1.0, 0.0, 0.2), ta), "pole_l": _lerp((0.3, -0.8, -0.6), (1.0, 0.0, 0.2), ta),
        "grip_r": _lerp(-0.45 - 0.05 * o, 0.7, ta), "grip_l": _lerp(-0.4 - 0.1 * o, 0.7, ta),
        "foot_r": _add(_lerp(_lerp((-0.2, 0.4, 0.24), (-0.27, 0.27, 0.14), o), (-0.13, 0.6, 0.27), tl), (0.0, 0.0, 0.05 * sl)),
        "foot_l": _add(_lerp(_lerp((0.22, 0.31, 0.05), (0.3, 0.25, -0.1), o), (0.14, 0.57, 0.23), tl), (0.0, 0.0, 0.05 * sl)),
        "heel_r": _lerp(30.0 + 10.0 * o, 32.0, tl), "heel_l": _lerp(34.0 + 10.0 * o, 30.0, tl),
        "fyaw_r": 16.0, "fyaw_l": 20.0,
        "knee_r": (-0.35, 0.3, 1.0), "knee_l": (0.4, 0.3, 1.0),
    }


def _frames(length, fn, keys):
    """A loop's channels keyed at every frame from fn(frame) (the seam's frame is the first's again)."""
    out = {}
    for ch in keys:
        out[ch] = [(f, _rv(fn(f % length)[ch])) for f in range(length + 1)]
    return out


def _up(v, dy):
    return (v[0], v[1] + dy, v[2])


SET4 = {
    # the tumble (a long launch: hitstun past the knock's own hold): one whole backward somersault a loop, typed as a turn
    # rate (tumble_at): flung wide open while the turn is slow, pulled into a tuck as it quickens, the tuck held through the
    # fastest part and through the upright pass (a ball, never a man standing), then flung open again; the legs lead, the
    # arms follow two frames behind, the head whips through two frames behind the trunk; the root drifts up while open and
    # down in the tuck. Distinct from the knock-slide (on the feet) and the knock-air (one hop) at a glance: the whole body turns.
    "tumble": dict({"length": 24, "loop": True, "flip_turns": -1.0, "base": AIR,
                    "meta": {"hand": "both", "mask": "full", "root": "place"}},
                   **_frames(24, tumble_at, [k for k in tumble_at(0.0)]),
                   face_r=[(0, "flail"), (2, "flung_up"), (10, "flung_up"), (15, "tuck_shin"), (20, "tuck_shin"), (24, "flail")],
                   face_l=[(0, "flail"), (2, "flung_up"), (10, "flung_up"), (15, "tuck_shin"), (20, "tuck_shin"), (24, "flail")]),
    # the flinch (a light hit that leaves him on his feet; upper mask, 0.3 s): the hit snaps the chest back and turns it, the
    # head whipped back a beat behind; the reversal spread over three frames into the cringe: the shoulders hunched, a
    # forearm guard (loose fists crossed up before the chin, the elbows in front of the ribs, the chin tucked behind it),
    # wide enough to read from the stands; then eased out through the stand, the arms dropping last and the head after them.
    # strike_s: the hit; hold_s: the cringe; back_s: the release
    "flinch": {
        "length": 9,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 5 / FPS, "hand": "both", "mask": "upper", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (1, (0.0, -0.025, -0.03)), (3, (0.0, -0.035, -0.02)), (5, (0.0, -0.028, -0.01)),
                 (9, (0, -0.015, 0))],
        "hips": [(0, 0), (1, -5), (3, 2), (5, 1), (9, 0)],
        "chest": [(0, 0), (1, -16), (2, -11), (3, 0), (4, 7), (5, 6), (7, 2), (9, 0)],
        "twist": [(0, 0), (1, 10), (3, 6), (5, 3), (9, 0)],
        "side": [(0, 0), (1, 4), (3, 3), (6, 1), (9, 0)],
        # (pass 3: the cringe is a ring fighter's forearm guard, not a civilian's "whoa": loose fists, the forearms crossed up
        # before the chin, the elbows in front of the ribs, the chin tucked down behind the guard; the head's whip back kept)
        "head": [(0, 0), (1, -6), (2, -16), (3, 4), (4, 6), (5, 7), (6, 6), (8, 2), (9, 0)],
        "clav_r": [(0, (0, 0)), (1, (2, -8)), (3, (12, -14)), (5, (10, -11)), (7, (4, -5)), (9, (0, 0))],
        "clav_l": [(0, (0, 0)), (1, (2, -8)), (3, (12, -13)), (5, (10, -10)), (7, (4, -5)), (9, (0, 0))],
        "hand_r": [(0, HR), (1, (-0.23, 0.97, 0.17)), (2, (-0.17, 1.17, 0.22)), (3, (-0.09, 1.3, 0.28)), (4, (-0.095, 1.29, 0.278)),
                   (5, (-0.11, 1.255, 0.265)), (6, (-0.16, 1.13, 0.2)), (7, (-0.2, 0.99, 0.13)), (8, (-0.2, 0.86, 0.085)), (9, HR)],
        "hand_l": [(0, HL), (1, (0.23, 0.95, 0.15)), (2, (0.17, 1.17, 0.23)), (3, (0.09, 1.32, 0.3)), (4, (0.095, 1.31, 0.298)),
                   (5, (0.11, 1.275, 0.285)), (6, (0.16, 1.14, 0.21)), (7, (0.2, 0.99, 0.13)), (8, (0.2, 0.85, 0.085)), (9, HL)],
        "face_r": [(0, "stand"), (1, "jolt"), (3, "guard"), (5, "guard"), (9, "stand")],
        "face_l": [(0, "stand"), (1, "jolt"), (3, "guard"), (5, "guard"), (9, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (1, (-0.7, -0.4, -0.6)), (3, (-0.8, -0.5, 0.3)), (5, (-0.8, -0.5, 0.25)),
                   (7, (-0.5, -0.4, -0.6)), (9, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (1, (0.7, -0.4, -0.6)), (3, (0.8, -0.5, 0.3)), (5, (0.8, -0.5, 0.25)),
                   (7, (0.5, -0.4, -0.6)), (9, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (1, -0.4), (3, 0.5), (5, 0.5), (7, 0.45), (9, 0.4)],
        "grip_l": [(0, 0.4), (1, -0.4), (3, 0.5), (5, 0.5), (7, 0.45), (9, 0.4)],
    },
    # the double jump (the tucked knees-up spring): from the fall a gather over three frames (the knees, the hips and the
    # chest drawn up and over, the hands lifted), then the push: the legs kick down hard against the air, the toes pointed,
    # the body stretched into an arch (the chest and the hips back, the face up), the arms swept back and down behind the hips
    # in a V; the arms swing out round and up through the shoulders' height in one loop and the knees snap up under the seat,
    # the heels tight under it, the hands pulled in onto the knees: a ball by f6, held to f8 at the height of the spring;
    # opened out into the fall again, the legs first, then the arms, the face last.  hold_s: the gather; strike_s: the push
    "jump_double": {
        "length": 12, "base": AIR,
        "meta": {"hold_s": 2 / FPS, "strike_s": 3 / FPS, "back_s": 8 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, AIR["root"]), (2, (0.0, 0.03, 0.0)), (3, (0.0, -0.04, 0.0)), (6, (0.0, 0.05, 0.0)), (8, (0.0, 0.04, 0.0)),
                 (12, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, AIR["hips"] + 6), (3, -11), (4, 4), (5, 14), (6, 20), (8, 18), (10, 12), (12, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, AIR["chest"] + 6), (3, -13), (4, 6), (5, 14), (6, 18), (8, 15), (10, 9),
                  (12, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, AIR["head"] + 3), (3, -9), (4, -3), (6, 6), (8, 8), (10, 6), (12, AIR["head"])],
        "clav_r": [(0, AIR["clav_r"]), (1, (-2, -14)), (3, (-10, 8)), (4, (0, -14)), (6, (10, 0)), (8, (10, 0)),
                   (12, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (1, (-2, -14)), (3, (-10, 8)), (4, (0, -14)), (6, (10, 0)), (8, (10, 0)),
                   (12, AIR["clav_l"])],
        # (the hands: up 0.1 m in the gather, then down and back over f1-f3 into the push's V, out round the side at f4 and on
        # up and in onto the knees: one loop, no V-shaped pop)
        "hand_r": [(0, AR), (1, _up(AR, 0.1)), (2, (-0.47, 1.16, -0.06)), (3, (-0.34, 0.86, -0.44)), (4, (-0.48, 1.15, 0.0)),
                   (5, (-0.32, 1.12, 0.28)), (6, (-0.17, 0.99, 0.36)), (8, (-0.18, 0.98, 0.35)), (10, (-0.36, 1.12, 0.24)),
                   (12, AR)],
        "hand_l": [(0, AL), (1, _up(AL, 0.1)), (2, (0.47, 1.17, -0.07)), (3, (0.35, 0.85, -0.445)), (4, (0.48, 1.16, 0.0)),
                   (5, (0.32, 1.12, 0.27)), (6, (0.17, 0.99, 0.35)), (8, (0.18, 0.98, 0.34)), (10, (0.36, 1.13, 0.23)),
                   (12, AL)],
        "face_r": [(0, "balance"), (1, "balance"), (3, "stand"), (4, "flung_up"), (6, "knee"), (8, "knee"), (12, "balance")],
        "face_l": [(0, "balance"), (1, "balance"), (3, "stand"), (4, "flung_up"), (6, "knee"), (8, "knee"), (12, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-0.3, 0.0, -1.0)), (4, (-1.0, -0.3, -0.3)), (6, (-1.0, -0.2, 0.2)), (8, (-1.0, -0.2, 0.2)),
                   (12, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (3, (0.3, 0.0, -1.0)), (4, (1.0, -0.3, -0.3)), (6, (1.0, -0.2, 0.2)), (8, (1.0, -0.2, 0.2)),
                   (12, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (3, 0.6), (4, -0.3), (6, 0.5), (8, 0.5), (12, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (3, 0.6), (4, -0.3), (6, 0.5), (8, 0.5), (12, AIR["grip_l"])],
        "foot_r": [(0, AFR), (2, _add(AFR, (0.0, 0.12, 0.03))), (3, (-0.13, -0.01, -0.15)), (4, (-0.12, 0.38, 0.12)),
                   (5, (-0.12, 0.54, 0.06)), (6, (-0.12, 0.62, 0.02)), (8, (-0.12, 0.6, 0.03)), (10, (-0.14, 0.42, 0.12)), (12, AFR)],
        "foot_l": [(0, AFL), (2, _add(AFL, (0.0, 0.12, 0.03))), (3, (0.13, 0.0, -0.17)), (4, (0.13, 0.36, 0.08)),
                   (5, (0.13, 0.52, 0.03)), (6, (0.13, 0.6, 0.0)), (8, (0.13, 0.58, 0.01)), (11, (0.15, 0.4, -0.08)), (12, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (2, AIR["heel_r"] + 6), (3, 70), (4, 50), (6, 40), (8, 40), (12, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (2, AIR["heel_l"] + 6), (3, 70), (4, 50), (6, 40), (8, 40), (12, AIR["heel_l"])],
        "knee_r": [(0, AIR["knee_r"]), (3, (-0.1, 0.0, 1.0)), (6, (-0.15, 0.15, 1.0)), (8, (-0.15, 0.15, 1.0)), (12, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (3, (0.1, 0.0, 1.0)), (6, (0.15, 0.15, 1.0)), (8, (0.15, 0.15, 1.0)), (12, AIR["knee_l"])],
    },
    "fall": dict({"length": 20, "loop": True, "base": AIR, "meta": {"hand": "both", "mask": "full", "root": "place"}},
                 **_loop(20, fall_at, [k for k in fall_at(0.0) if not k.startswith("face_")]),
                 face_r=[(0, "balance"), (20, "balance")], face_l=[(0, "balance"), (20, "balance")]),
    "fall_fast": dict({"length": 16, "loop": True, "base": AIR, "meta": {"hand": "both", "mask": "full", "root": "place"}},
                      **_loop(16, fall_fast_at, [k for k in fall_fast_at(0.0) if not k.startswith("face_")]),
                      face_r=[(0, "swept"), (16, "swept")], face_l=[(0, "swept"), (16, "swept")]),
    "helpless": dict({"length": 24, "loop": True, "base": AIR, "hands_from": "shoulder", "meta": {"hand": "both", "mask": "full", "root": "place"}},
                     **_loop(24, helpless_at, [k for k in helpless_at(0.0) if not k.startswith("face_")]),
                     face_r=[(0, "limp_up"), (24, "limp_up")], face_l=[(0, "limp_up"), (24, "limp_up")]),
    # the air dodge (a sharp tucked twist; the code moves him): from the fall the body snaps in from the middle out: the hips
    # and the chest first, the knees a frame later, the arms crossed before the chest after them and the head last; the head
    # leads the turn (looking round ahead of the body) and the tuck tightens at the turn's fastest, then the head lands on the
    # new heading first and the body comes round after it; it opens back into the fall, the legs first, the arms after.
    # hold_s: the snap in; strike_s: tucked (untouchable from here); back_s: opening
    "air_dodge": {
        "length": 15, "base": AIR,
        "meta": {"hold_s": 1 / FPS, "strike_s": 2 / FPS, "back_s": 9 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "spin": [(0, 0), (2, 30), (5, 200), (8, 330), (10, 360), (15, 360)],
        "look": [(0, 0), (1, 8), (2, 20), (5, 24), (8, 30), (9, 13), (10, 0), (15, 0)],
        "root": [(0, AIR["root"]), (2, (0.0, 0.06, 0.0)), (5, (0.0, 0.075, 0.0)), (9, (0.0, 0.06, 0.0)), (15, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 16), (5, 20), (9, 15), (12, 10), (15, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 20), (5, 23), (9, 18), (12, 9), (15, AIR["chest"])],
        "head": [(0, AIR["head"]), (1, AIR["head"] - 1), (3, 8), (4, 10), (9, 10), (13, 7), (15, AIR["head"])],
        "twist": [(0, 0), (2, 8), (9, 6), (15, 0)],
        "clav_r": [(0, AIR["clav_r"]), (2, (8, 0)), (3, (14, 8)), (10, (12, 6)), (15, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (8, 0)), (3, (14, 8)), (10, (12, 6)), (15, AIR["clav_l"])],
        "hand_r": [(0, AR), (2, (-0.2, 1.22, 0.27)), (3, (0.1, 1.26, 0.24)), (5, (0.11, 1.245, 0.23)), (9, (0.1, 1.25, 0.24)),
                   (12, (-0.3, 1.2, 0.22)), (15, AR)],
        "hand_l": [(0, AL), (2, (0.2, 1.25, 0.24)), (3, (-0.08, 1.3, 0.2)), (5, (-0.09, 1.285, 0.19)), (9, (-0.08, 1.29, 0.2)),
                   (12, (0.3, 1.26, 0.18)), (15, AL)],
        "face_r": [(0, "balance"), (3, "cross"), (10, "cross"), (15, "balance")],
        "face_l": [(0, "balance"), (3, "cross"), (10, "cross"), (15, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-0.8, -0.6, 0.2)), (10, (-0.8, -0.6, 0.2)), (15, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (3, (0.8, -0.6, 0.2)), (10, (0.8, -0.6, 0.2)), (15, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (3, 0.9), (10, 0.9), (15, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (3, 0.9), (10, 0.9), (15, AIR["grip_l"])],
        "foot_r": [(0, AFR), (2, (-0.11, 0.48, 0.22)), (3, (-0.11, 0.6, 0.26)), (5, (-0.11, 0.63, 0.27)), (9, (-0.11, 0.59, 0.25)),
                   (12, (-0.13, 0.4, 0.18)), (15, AFR)],
        "foot_l": [(0, AFL), (2, (0.11, 0.44, 0.15)), (3, (0.11, 0.56, 0.2)), (5, (0.11, 0.59, 0.21)), (9, (0.11, 0.55, 0.19)),
                   (12, (0.13, 0.42, 0.04)), (15, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (3, 36), (12, 30), (15, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (3, 36), (12, 30), (15, AIR["heel_l"])],
        "knee_r": [(0, AIR["knee_r"]), (2, (-0.1, 0.5, 1.0)), (10, (-0.1, 0.5, 1.0)), (15, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (2, (0.1, 0.5, 1.0)), (10, (0.1, 0.5, 1.0)), (15, AIR["knee_l"])],
    },
    "air_legs": dict({"length": 24, "loop": True, "bones": "legs", "base": AIR,
                      "meta": {"hand": "both", "mask": "lower", "root": "place"}}, **_loop(24, air_legs_at)),
    # the light landing (from the fall: a plain landing, short lag): the toes take the deck, the heels roll down, the knees
    # give and the hips sink and sit back a little as the chest leans over the knees (the weight kept over the feet), the arms
    # come down from the fall's balance in front a beat behind the body; up through the stand, the arms and the head settling
    # last.  strike_s: the heels down; hold_s: the lowest; back_s: rising
    "land_light": {
        "length": 10,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 5 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.01, 0.0)), (1, (0.0, -0.06, -0.015)), (3, (0.0, -0.14, -0.04)), (5, (0.0, -0.115, -0.035)),
                 (8, (0.0, -0.035, -0.01)), (10, (0, -0.015, 0))],
        "hips": [(0, 5), (1, 9), (3, 17), (5, 14), (8, 4), (10, 0)],
        "chest": [(0, 4), (1, 5), (3, 9), (5, 8), (8, 2), (10, 0)],
        "head": [(0, 6), (2, 11), (4, 7), (7, 1), (10, 0)],
        "clav_r": [(0, AIR["clav_r"]), (3, (6, 4)), (6, (3, 2)), (10, (0, 0))],
        "clav_l": [(0, AIR["clav_l"]), (3, (6, 4)), (6, (3, 2)), (10, (0, 0))],
        "hand_r": [(0, AR), (2, (-0.42, 1.0, 0.2)), (4, (-0.32, 0.84, 0.24)), (7, (-0.24, 0.8, 0.14)), (10, HR)],
        "hand_l": [(0, AL), (2, (0.42, 1.02, 0.18)), (4, (0.32, 0.86, 0.22)), (7, (0.24, 0.8, 0.13)), (10, HL)],
        "face_r": [(0, "balance"), (3, "palm_down"), (10, "stand")], "face_l": [(0, "balance"), (3, "palm_down"), (10, "stand")],
        "pole_r": [(0, AIR["pole_r"]), (4, (-0.6, -0.5, -0.6)), (10, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, AIR["pole_l"]), (4, (0.6, -0.5, -0.6)), (10, (0.35, -0.1, -1.0))],
        "grip_r": [(0, AIR["grip_r"]), (4, 0.2), (10, 0.4)], "grip_l": [(0, AIR["grip_l"]), (4, 0.2), (10, 0.4)],
        "foot_r": [(0, FR), (10, FR)], "foot_l": [(0, FL), (10, FL)],
        "heel_r": [(0, 14), (1, 0), (10, 0)], "heel_l": [(0, 16), (1, 0), (10, 0)],
        "knee_r": [(0, "auto"), (2, (-0.25, 0.0, 1.0)), (6, (-0.25, 0.0, 1.0)), (9, "auto")],
        "knee_l": [(0, "auto"), (2, (0.25, 0.0, 1.0)), (6, (0.25, 0.0, 1.0)), (9, "auto")],
    },
    # the heavy landing (the landing lag of a Slam, a missed air cast or the helpless fall: the punish window, and it must read
    # as one at a glance): from the fall's balance he slams down into a deep squat, the hips dropping hard and sitting back
    # (the weight kept over the feet); the impact travels up through him: the palms slap onto the thighs above the knees
    # first, the chest keeps sagging over them two frames after, the head hangs last; held there, sagging (the window); then a
    # slow, heavy push up off the thighs, eased in (the root's rise slow at first, its fastest in the middle, eased out at the
    # stand), the hands pressed into the thighs until f12; settling at different times: the chest overshoots back at f14 and
    # settles, the hands reach the stand at f15, the head comes up last (a touch past at f14, level at f16).
    # strike_s: the impact; hold_s: the bottom; back_s: the push up
    "land_heavy": {
        "length": 16,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 8 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.02, 0.0)), (1, (0.0, -0.15, -0.045)), (3, (0.0, -0.31, -0.11)), (5, (0.0, -0.335, -0.115)),
                 (8, (0.0, -0.32, -0.11)), (10, (0.0, -0.285, -0.1)), (12, (0.0, -0.18, -0.065)), (14, (0.0, -0.07, -0.022)),
                 (16, (0, -0.015, 0))],
        "hips": [(0, 4), (1, 18), (3, 40), (5, 42), (8, 40), (10, 36), (12, 23), (14, 7), (16, 0)],
        "chest": [(0, 2), (1, 4), (3, 13), (5, 19), (8, 16), (10, 13), (12, 6), (14, -3), (16, 0)],
        "head": [(0, AIR["head"]), (1, 1), (3, 8), (5, 20), (8, 18), (10, 15), (12, 9), (14, 4), (16, 0)],
        "side": [(0, 0), (3, -3), (8, -2), (12, -1), (16, 0)],
        "clav_r": [(0, AIR["clav_r"]), (2, (6, 0)), (4, (12, 8)), (8, (10, 6)), (12, (7, 4)), (15, (1, 0)), (16, (0, 0))],
        "clav_l": [(0, AIR["clav_l"]), (2, (6, 0)), (4, (12, 8)), (8, (10, 6)), (12, (7, 4)), (15, (1, 0)), (16, (0, 0))],
        "hand_r": [(0, AR), (1, (-0.42, 1.06, 0.18)), (2, (-0.2, 0.56, 0.23)), (3, (-0.17, 0.47, 0.22)), (5, (-0.17, 0.455, 0.22)),
                   (8, (-0.17, 0.46, 0.22)), (10, (-0.175, 0.485, 0.215)), (11, (-0.177, 0.525, 0.21)), (12, (-0.182, 0.61, 0.19)), (13, (-0.195, 0.69, 0.15)),
                   (14, (-0.195, 0.76, 0.1)), (15, HR), (16, HR)],
        "hand_l": [(0, AL), (1, (0.42, 1.08, 0.18)), (2, (0.2, 0.56, 0.23)), (3, (0.17, 0.47, 0.22)), (5, (0.17, 0.455, 0.22)),
                   (8, (0.17, 0.46, 0.22)), (10, (0.175, 0.485, 0.215)), (11, (0.177, 0.525, 0.21)), (12, (0.182, 0.61, 0.19)), (13, (0.195, 0.69, 0.15)),
                   (14, (0.195, 0.76, 0.1)), (15, HL), (16, HL)],
        "face_r": [(0, "balance"), (2, "knee"), (12, "knee"), (15, "stand"), (16, "stand")],
        "face_l": [(0, "balance"), (2, "knee"), (12, "knee"), (15, "stand"), (16, "stand")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-1.0, 0.3, -0.2)), (12, (-1.0, 0.3, -0.2)), (15, (-0.35, -0.1, -1.0)), (16, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, AIR["pole_l"]), (3, (1.0, 0.3, -0.2)), (12, (1.0, 0.3, -0.2)), (15, (0.35, -0.1, -1.0)), (16, (0.35, -0.1, -1.0))],
        "grip_r": [(0, AIR["grip_r"]), (3, -0.1), (12, -0.1), (15, 0.4), (16, 0.4)],
        "grip_l": [(0, AIR["grip_l"]), (3, -0.1), (12, -0.1), (15, 0.4), (16, 0.4)],
        "foot_r": [(0, FR), (16, FR)], "foot_l": [(0, FL), (16, FL)],
        "fyaw_r": [(0, 7), (16, 7)], "fyaw_l": [(0, 7), (16, 7)],
        "heel_r": [(0, 12), (1, 0), (16, 0)], "heel_l": [(0, 14), (1, 0), (16, 0)],
        "knee_r": [(0, "auto"), (2, (-0.35, 0.0, 1.0)), (12, (-0.35, 0.0, 1.0)), (15, "auto")],
        "knee_l": [(0, "auto"), (2, (0.35, 0.0, 1.0)), (12, (0.35, 0.0, 1.0)), (15, "auto")],
    },
}
CLIPS.update(SET4)


## ---------------------------------------------------------------- the fifth set (round 3, P1's edge and ground dodges: the
## deck's edge (the grab, the hang, the climb, the roll in, the jump and the attack from it), the ground rolls and the duck;
## authored the same way, key poses typed here, nothing read). The edge clips are keyed in the HANG'S FRAME: the origin where
## the game snaps a hanger (spec 5.3: the feet's origin LIP_Y under the lip, LIP_Z out from the deck's face, facing the deck),
## so the lip is at (y LIP_Y, z LIP_Z) in the character's frame and the deck's top is the plane y LIP_Y ahead of it; their
## metas lip_y and lip_out say so for the code. The get-ups (climb, roll, attack) end standing on the deck CLIMB_IN in from
## the lip (meta end_in: the root's place there, (0, LIP_Y, LIP_Z + CLIMB_IN)); the edge jump ends on AIR (the fall's first
## pose) at the origin, the code's jump carrying him up. The ground rolls turn the tucked figure about its ball's middle
## (pivot) on the deck (ground: the lowest of the body's surface kept on the deck, a contact like the IK's) while the code
## carries him; facing kept (no yaw). Fire Northern Shaolin, earth Hung Gar, water tai chi and air Baguazhang are style
## labels only (the edge attack's low sweep is a Shaolin/Hung Gar ground sweep in form); these are every element's.
LIP_Y = 2.0
LIP_Z = 0.35
## A palm laid flat on the deck (the palm bone over the stone).
DECK_PALM = LIP_Y + 0.03
## Where the get-ups stand: CLIMB_IN m in from the lip (spec 5.3: the climb stands 0.6 m in).
CLIMB_IN = 0.6
EDGE_META = {"hand": "both", "mask": "full", "root": "place", "legs_always": 1.0, "lip_y": LIP_Y, "lip_out": LIP_Z}


def _deck(v):
    """A stand place carried onto the deck where the get-ups stand (CLIMB_IN m in from the lip, on its top)."""
    return (v[0], v[1] + LIP_Y, v[2] + LIP_Z + CLIMB_IN)


def _mx(v):
    return (-v[0], v[1], v[2])


DFR, DFL, DHR, DHL = _deck(FR), _deck(FL), _deck(HR), _deck(HL)
DROOT = _deck(STAND["root"])
FACING.update({
    "deck": ((0.1, -0.03, 1.0), (0.0, -1.0, 0.0)),            # laid flat on the deck, the fingers forward and a little in
    "lip_reach": ((0.05, 0.55, 0.83), (0.0, -0.83, 0.55)),    # reaching up and over for the lip, the palm down and ahead
    "press": ((0.15, -0.2, 0.97), (0.0, -1.0, -0.2)),         # pressing down on the deck beside the body, the fingers ahead
    "deck_out": ((-0.6, -0.03, 0.8), (0.0, -1.0, 0.0)),       # flat on the deck, the fingers turned out (a low crouch's prop)
    "sky": ((0.0, 1.0, 0.1), (0.95, 0.0, 0.3)),               # flung up overhead, the fingers up, the palm in
    "hug": ((0.6, -0.5, 0.62), (0.0, -0.3, -0.95)),           # round the shin in a tuck, the palm on it
    "ears": ((0.1, 0.35, -0.93), (0.0, 0.95, 0.3)),           # by the ear for a back roll's push, the fingers back, the palm up
    "ward": ((0.25, 0.9, 0.35), (0.3, 0.1, -0.95)),           # a forearm up before the face, the palm toward it
    "fling": ((-0.35, 0.9, 0.25), (0.75, 0.15, 0.62)),        # swung up and out past the shoulder, open, the palm in and ahead
})

## The hang (own-bend-edge-hang, a loop of 30 frames): the forearms laid across the lip's coping, the palms flat on the deck
## ahead and the elbows on the nose of the stone, the shoulders shrugged up under the load and the head well over the lip
## (the head up, eyes on the deck); the lower body a climber's Z pressed into the stone: the hips held out off the face, the
## knees folded to about a right angle and turned out, the balls of both feet pressed high on the face (the left a little
## higher), so the line from the feet through the hips to the shoulders is a bent bow; the sway: the hips swing side to side
## (5 cm) and the trunk rolls and twists after them, a breath lifts the chest and the shoulders twice a loop, the head glances
## a quarter loop behind the hips, the heels re-press in turn as the hips swing over each foot, the right hand flexes its
## grip at f12-f18 (the palm unmoved) and the head lifts to check along the deck at f19-f28; the palms and the balls of the
## feet never move (they hold the stone).
## (pass 3: a climber's line instead of a frog squat: the right foot high with its knee folded and pulled in, the left
## foot 22 cm lower down the face with the leg running long down the stone; the hips swing 8 cm, the chest rolls after them
## and the head glances last; a 1.5 cm settle on the arms as the hips cross the middle; the check: the head turned 25 degrees
## along the deck and the chest lifted, looking for an opening)
HANG_PALM_R = (-0.22, DECK_PALM, 0.56)
HANG_FOOT_R = (-0.16, 1.3, 0.18)
HANG_FOOT_L = (0.16, 1.08, 0.18)
## The head's glance a quarter loop behind the hips' swing.
HANG_LAG = math.pi / 2


def _bump(a, f0, f1, n=30):
    """A smooth hump (0 outside frames f0..f1 of an n-frame loop, 1 at their middle) at the loop's phase a."""
    f = (a / (2 * math.pi) * n) % n
    if f <= f0 or f >= f1:
        return 0.0
    return math.sin(math.pi * (f - f0) / (f1 - f0)) ** 2


def hang_at(a):
    regrip = _bump(a, 12, 18)
    check = _bump(a, 18, 28)
    breath = _s(2 * a, 0.5)
    settle = _bump(a, 3, 9) + _bump(a, 18, 24)
    return {
        "root": (0.08 * _s(a), 0.9 + 0.015 * breath - 0.015 * settle, -0.02 + 0.01 * _c(a)),
        "hips": 24.0 + 1.5 * _s(a, -0.4), "roll": 5.0 * _s(a, -1.0), "chest": 7.0 + 1.5 * _s(2 * a, -0.8) - 3.0 * check,
        "side": -2.5 * _s(a, -1.1), "twist": 4.0 * _s(a, -1.2),
        "head": -18.0 + 2.0 * _s(2 * a, -1.6) - 8.0 * check, "look": 12.0 * _s(a, -HANG_LAG) + 25.0 * check,
        "clav_r": (6.0, -18.0 + 2.0 * _s(a, -0.6) - 1.5 * breath), "clav_l": (6.0, -18.0 - 2.0 * _s(a, -0.6) - 1.5 * breath),
        "hand_r": HANG_PALM_R, "hand_l": _mx(HANG_PALM_R),
        "face_r": "deck", "face_l": "deck",
        "pole_r": (-0.35, -1.0, -0.1), "pole_l": (0.35, -1.0, -0.1),
        # (the flex: the fingers lifted off the stone and laid back, the palm pressing)
        "grip_r": 0.3 - 0.45 * regrip, "grip_l": 0.3,
        "foot_r": HANG_FOOT_R, "foot_l": HANG_FOOT_L,
        "heel_r": 10.0 - 4.0 * _s(a), "heel_l": 14.0 + 4.0 * _s(a), "fyaw_r": 12.0, "fyaw_l": 10.0,
        "knee_r": (-0.3, 0.1, 1.0), "knee_l": (0.25, 0.0, 1.0),
    }


HANG = dict(STAND)
HANG.update({k: _rv(v) if not isinstance(v, str) else v for k, v in hang_at(0.0).items()})
GR, GL = HANG["hand_r"], HANG["hand_l"]
GFR, GFL = HANG["foot_r"], HANG["foot_l"]


def _h(key, *more):
    """The hang's first value of a channel as a key at frame 0 (and at the frames `more`)."""
    return [(fr, HANG[key]) for fr in (0,) + more]


def _turned(v, deg, piv, axis):
    """A place turned by deg about the X (flip) or the Z (cart) axis through piv, as pose() turns a tumbling figure."""
    r = math.radians(deg)
    d = [v[i] - piv[i] for i in range(3)]
    if axis == "x":
        y, z = d[1] * math.cos(r) - d[2] * math.sin(r), d[1] * math.sin(r) + d[2] * math.cos(r)
        d = [d[0], y, z]
    else:
        x, y = d[0] * math.cos(r) - d[1] * math.sin(r), d[0] * math.sin(r) + d[1] * math.cos(r)
        d = [x, y, d[2]]
    return tuple(round(piv[i] + d[i], 4) for i in range(3))


def _unturn(w, deg, piv, axis="x"):
    """The key that a flip (axis x) or a cart (axis z) of deg about piv turns onto the place w: a hand keyed to land where
    the deck is while the figure turns."""
    return _turned(w, -deg, piv, axis)


def _unturn_way(face, deg, axis="x", side="r"):
    """A named facing as the facing that the turn of deg carries onto it (the right hand's, or the left's mirrored: a typed
    facing is not mirrored by the left hand as a name is)."""
    f, n = FACING[face]
    if side == "l":
        f, n = _mx(f), _mx(n)
    return (_turned(f, -deg, (0, 0, 0), axis), _turned(n, -deg, (0, 0, 0), axis))


## The heel lift's carry of the ankle (pose(): a lifted heel turns the foot about its ball): the ankle's place to key so the
## ankle lands at `ankle` with the heel lifted by `heel` degrees (no toe-out). A foot laid back on the deck (a knee down, the
## shin along the deck, the toes over the nose) is a heel lift past 90.
FOOT_BALL = (0.0, -0.058, 0.101)


def _heel_place(ankle, heel):
    r = math.radians(heel)
    by, bz = FOOT_BALL[1], FOOT_BALL[2]
    ry, rz = by * math.cos(r) - bz * math.sin(r), by * math.sin(r) + bz * math.cos(r)
    return (ankle[0], round(ankle[1] - (by - ry), 4), round(ankle[2] - (bz - rz), 4))


## The edge jump's lift (spec 5.3: vy 11.8 at once; the ring's gravity): the code carries the hanger up from the press of
## Space. The clip's keys are the body over the code's carry (as every clip's are); `lift` is that carry and `lift_w` the
## share of it the clip takes back off (a uniform shift of the whole figure, the rotations as keyed), so the hands stay on the
## deck and the feet on the face through the coil and the push before the body goes with the code (intangible 0-0.12 s).
EDGE_JUMP_VY = 11.8
EDGE_JUMP_G = 19.9


def _rise(f, vy=EDGE_JUMP_VY, g=EDGE_JUMP_G):
    t = f / FPS
    return vy * t - 0.5 * g * t * t


## The climb's right ankle while the knee is on the deck by the lip: the shin laid back across the coping's nose (resting on it),
## the foot past the face.
CLIMB_DRAPE = (-0.2, LIP_Y - 0.08, LIP_Z - 0.2)

SET5 = {
    # the grab (6 f): caught high off the face, both arms long and spread up over the lip; the hands slap down flat on the
    # deck (the catch) and the arms take the weight with a jolt: the body sags until the chin dips to the lip, the elbows
    # give deep and the shoulders shrug up under the load, while the legs, trailing out behind, swing in under the lip like a
    # pendulum: the hips swing in past the hang toward the face, the balls of the feet strike the face (the heels dropping as
    # they take it) and the hips bounce back out into the hang; the head a frame behind the hips.  hold_s: the reach;
    # strike_s: the hands on the deck; back_s: the feet on the face
    "edge_grab": {
        "length": 6, "base": HANG, "substeps": 4,
        "meta": dict(EDGE_META, hold_s=1 / FPS, strike_s=2 / FPS, back_s=4 / FPS),
        "root": [(0, (0.0, 1.06, -0.08)), (1, (0.0, 0.95, 0.02)), (2, (0.0, 0.92, 0.05)), (3, (0.0, 0.8, 0.08)),
                 (4, (0.0, 0.85, 0.05)), (5, (0.0, 0.91, 0.0)), (6, HANG["root"])],
        "hips": [(0, -4), (1, 4), (2, 12), (3, 22), (4, 28), (5, 26), (6, HANG["hips"])],
        # (the catch square to the lip; the hang's sway comes in as the hips bounce back out)
        "roll": [(0, 0.0), (3, 0.0), (6, HANG["roll"])], "twist": [(0, 0.0), (3, 0.0), (6, HANG["twist"])],
        "side": [(0, 0.0), (3, 0.0), (6, HANG["side"])], "look": [(0, 0.0), (3, 0.0), (6, HANG["look"])],
        "chest": [(0, -2), (1, 2), (2, 6), (3, 11), (4, 9), (6, HANG["chest"])],
        "head": [(0, -28), (1, -26), (2, -18), (3, -10), (4, -20), (5, -21), (6, HANG["head"])],
        "clav_r": [(0, (2, -24)), (1, (6, -20)), (2, (8, -16)), (3, (10, -26)), (4, (8, -21)), (6, HANG["clav_r"])],
        "clav_l": [(0, (2, -24)), (1, (6, -20)), (2, (8, -16)), (3, (10, -26)), (4, (8, -21)), (6, HANG["clav_l"])],
        "hand_r": [(0, (-0.43, 2.54, 0.18)), (1, (-0.24, 2.12, 0.48)), (2, GR), (6, GR)],
        "hand_l": [(0, (0.44, 2.63, 0.17)), (1, (0.24, 2.14, 0.47)), (2, GL), (6, GL)],
        "face_r": [(0, "lip_reach"), (1, "lip_reach"), (2, "deck"), (6, "deck")],
        "face_l": [(0, "lip_reach"), (1, "lip_reach"), (2, "deck"), (6, "deck")],
        "pole_r": [(0, (-0.7, -0.5, -0.3)), (2, (-0.5, -1.0, -0.2)), (3, (-0.45, -1.0, -0.5)), (6, HANG["pole_r"])],
        "pole_l": [(0, (0.7, -0.5, -0.3)), (2, (0.5, -1.0, -0.2)), (3, (0.45, -1.0, -0.5)), (6, HANG["pole_l"])],
        "grip_r": [(0, -0.3), (1, -0.4), (2, 0.5), (4, 0.35), (6, HANG["grip_r"])],
        "grip_l": [(0, -0.3), (1, -0.4), (2, 0.5), (4, 0.35), (6, HANG["grip_l"])],
        "foot_r": [(0, (-0.14, 1.3, -0.32)), (2, (-0.15, 1.2, -0.24)), (3, (-0.16, 1.24, 0.07)), (4, GFR), (6, GFR)],
        "foot_l": [(0, (0.15, 1.18, -0.39)), (2, (0.16, 1.08, -0.28)), (3, (0.16, 1.06, 0.06)), (4, GFL), (6, GFL)],
        "heel_r": [(0, 28), (2, 22), (3, 12), (4, 0), (6, HANG["heel_r"])],
        "heel_l": [(0, 32), (2, 24), (3, 14), (4, 2), (6, HANG["heel_l"])],
        "fyaw_r": [(0, 6), (4, HANG["fyaw_r"])], "fyaw_l": [(0, 8), (4, HANG["fyaw_l"])],
        "knee_r": [(0, (-0.2, 0.0, 1.0)), (3, (-0.4, 0.2, 1.0)), (6, HANG["knee_r"])],
        "knee_l": [(0, (0.2, 0.0, 1.0)), (3, (0.35, 0.1, 1.0)), (6, HANG["knee_l"])],
    },
    "edge_hang": dict({"length": 30, "loop": True, "base": HANG, "meta": dict(EDGE_META)},
                      **_loop(30, hang_at, [k for k in hang_at(0.0) if not k.startswith("face_")]),
                      face_r=[(0, "deck"), (30, "deck")], face_l=[(0, "deck"), (30, "deck")]),
    # the climb (15 f, 0.5 s), a mantle: a dip (the elbows sink, loading), then the arms press the body up the face, the feet
    # walking up it with the knees turned out (clear of the stone), until the hips are up at the lip with the trunk leant
    # well over the hands; the right knee comes up and is set on the nose of the coping, the shin hanging down the face; the
    # weight rocks forward onto that knee (it rolls onto the deck, the shin draped back over the nose) as the left foot swings
    # up onto the deck ahead, the right hand lifting and the left coming onto the left thigh, the hips shifted left over the
    # left foot; a held load (the left hand pressing the thigh), then he drives up off the left leg (eased out) and the right
    # foot steps through to the stand CLIMB_IN in, the rise carried a touch past (onto the toes) and settled, the chest a
    # touch back; the head up first, the arms landing two frames after the hips.
    # hold_s: the press; strike_s: the knee on the nose; back_s: the load before the drive
    "edge_climb": {
        "length": 15, "base": HANG,
        "meta": dict(EDGE_META, hold_s=3 / FPS, strike_s=6 / FPS, back_s=9 / FPS, end_in=CLIMB_IN),
        "root": [(0, HANG["root"]), (1, (0.0, 0.85, 0.0)), (2, (0.0, 0.95, 0.02)), (3, (0.0, 1.06, 0.04)), (4, (0.0, 1.16, 0.05)),
                 (5, (0.0, 1.21, 0.05)), (6, (0.0, 1.24, 0.06)), (7, (0.02, 1.34, 0.24)), (8, (0.05, 1.5, 0.4)),
                 (9, (0.05, 1.55, 0.5)), (10, (0.05, 1.555, 0.56)), (11, (0.04, 1.73, 0.76)), (12, (0.02, 1.87, 0.88)),
                 (13, (0.01, 1.96, 0.93)), (14, (0.0, 1.997, 0.95)), (15, DROOT)],
        "hips": [(0, HANG["hips"]), (1, 26), (3, 30), (5, 36), (6, 40), (7, 52), (8, 38), (9, 30), (10, 30), (11, 20), (12, 10),
                 (13, 3), (14, -1), (15, 0)],
        "chest": [(0, HANG["chest"]), (1, 8), (3, 16), (5, 12), (6, 10), (7, 10), (8, 10), (9, 12), (10, 12), (11, 7), (12, 2),
                  (13, -1), (14, -3), (15, 0)],
        "head": [(0, HANG["head"]), (1, -22), (3, -26), (5, -30), (6, -30), (7, -20), (8, -20), (9, -18), (10, -14), (11, -6),
                 (12, -1), (14, 1), (15, 0)],
        "roll": [(0, HANG["roll"]), (3, -2), (5, -4), (6, -6), (8, 3), (10, 2), (15, 0)],
        "clav_r": [(0, HANG["clav_r"]), (1, (6, -22)), (3, (4, 4)), (5, (4, 10)), (7, (4, 10)), (9, (2, 6)), (11, (0, 0)),
                   (15, (0, 0))],
        "clav_l": [(0, HANG["clav_l"]), (1, (6, -22)), (3, (4, 4)), (5, (4, 10)), (7, (4, 10)), (9, (2, 6)), (11, (0, 0)),
                   (15, (0, 0))],
        "hand_r": [(0, GR), (7, GR), (8, (-0.3, 2.42, 0.64)), (10, (-0.32, 2.56, 0.8)), (12, (-0.28, 2.7, 0.95)),
                   (14, _add(DHR, (-0.04, 0.035, 0.04))), (15, DHR)],
        "hand_l": [(0, GL), (7, GL), (8, (0.19, 2.5, 0.66)), (9, (0.19, 2.52, 0.72)), (10, (0.19, 2.53, 0.76)),
                   (12, (0.24, 2.72, 0.92)), (14, _add(DHL, (0.03, 0.035, 0.03))), (15, DHL)],
        "face_r": [(0, "deck"), (7, "deck"), (9, "stand"), (15, "stand")],
        "face_l": [(0, "deck"), (7, "deck"), (8, "knee"), (10, "knee"), (12, "stand"), (15, "stand")],
        "pole_r": [(0, HANG["pole_r"]), (3, (-0.4, -0.2, -1.0)), (7, (-0.4, -0.2, -1.0)), (9, (-0.6, -0.4, -0.4)),
                   (12, (-0.4, -0.2, -1.0)), (15, STAND["pole_r"])],
        "pole_l": [(0, HANG["pole_l"]), (3, (0.4, -0.2, -1.0)), (7, (0.4, -0.2, -1.0)), (8, (1.0, 0.2, -0.2)),
                   (10, (1.0, 0.2, -0.2)), (12, (0.4, -0.2, -1.0)), (15, STAND["pole_l"])],
        "grip_r": [(0, HANG["grip_r"]), (7, 0.2), (9, 0.4), (15, 0.4)],
        "grip_l": [(0, HANG["grip_l"]), (7, 0.2), (8, 0.3), (15, 0.4)],
        # (the right foot walks up the face as the knee comes up (f3-f5), hangs from the knee on the nose (f6), is draped back
        # over the nose as the knee rolls onto the deck (f7-f9), then comes up over the nose and steps through; the left foot
        # walks up the face, swings up over the nose and is planted ahead where it will stand)
        "foot_r": [(0, GFR), (1, GFR), (3, (-0.21, 1.46, 0.18)), (4, (-0.23, 1.62, 0.2)), (5, (-0.22, 1.74, 0.24)),
                   (6, (-0.2, 1.72, 0.27)), (7, CLIMB_DRAPE), (9, CLIMB_DRAPE), (10, (-0.17, 2.14, 0.32)),
                   (11, _heel_place((-0.14, 2.28, 0.7), 30)), (12, _heel_place((-0.13, 2.16, 0.88), 10)), (13, DFR), (15, DFR)],
        "foot_l": [(0, GFL), (1, GFL), (3, (0.19, 1.4, 0.17)), (5, (0.21, 1.62, 0.17)), (6, (0.22, 1.8, 0.2)),
                   (7, (0.19, 2.24, 0.52)), (8, DFL), (15, DFL)],
        "heel_r": [(0, HANG["heel_r"]), (3, 20), (5, 30), (6, 30), (7, 20), (9, 20), (10, 40), (11, 30), (12, 10), (13, 0), (14, 5),
                   (15, 0)],
        "heel_l": [(0, HANG["heel_l"]), (3, HANG["heel_l"]), (5, 10), (7, 20), (8, 0), (13, 0), (14, 5), (15, 0)],
        "fyaw_r": [(0, HANG["fyaw_r"]), (5, 10), (6, 4), (9, 4), (11, 4), (15, 7)],
        "fyaw_l": [(0, HANG["fyaw_l"]), (6, 20), (7, 10), (8, 7), (15, 7)],
        "knee_r": [(0, HANG["knee_r"]), (3, (-0.55, 0.2, 0.8)), (5, (-0.4, 0.6, 0.7)), (6, (-0.2, 0.3, 1.0)), (7, (-0.2, -0.3, 1.0)),
                   (9, (-0.2, -0.3, 1.0)), (11, (-0.2, 0.0, 1.0)), (14, "auto")],
        "knee_l": [(0, HANG["knee_l"]), (3, (0.55, 0.2, 0.8)), (6, (0.6, 0.4, 0.6)), (7, (0.4, 0.6, 0.8)), (8, (0.2, 0.3, 1.0)),
                   (9, (0.2, 0.0, 1.0)), (13, "auto")],
    },
    # the edge jump (9 f): a real coil on the face (the hips sink 8 cm, the elbows deep, the knees folded up the face), then
    # the push: the hands drive the deck down and the legs kick off the face (straight, up on the toes), the arms locking
    # straight down by the hips while the hands are still on the deck (f2-f3: the clip takes back the code's carry, `lift`),
    # released at f3: the arms are flung up overhead, the body springs up long past the lip and the knees come up under it as
    # a reaction (from f5), opened out into the fall's balance.  hold_s: the coil; strike_s: the push (the jump); back_s:
    # the arms overhead, opening
    "edge_jump": {
        "length": 9, "base": HANG, "lift": (EDGE_JUMP_VY, EDGE_JUMP_G),
        "meta": dict(EDGE_META, hold_s=1 / FPS, strike_s=2 / FPS, back_s=5 / FPS),
        "lift_w": [(0, 1.0), (3, 1.0), (5, 0.0), (9, 0.0)],
        # (the body over the deck: f0-f3 where the clip holds it, then over the code's carry; the world's path (hang frame) is
        # 0.90, 0.82, 0.95, 1.13, 1.47, 1.78, 2.02, 2.24, 2.45, 2.64: the push the fastest, then gravity's even slowing)
        # (pass 3: the coil 13 cm deep with the elbows folded back and the head dropped; the arms locked straight down at the
        # strike (f2) with the legs driven off the face; the arms swung up wide past the shoulders, open, f3-f5 one arc)
        "root": [(0, HANG["root"]), (1, (0.0, 0.77, 0.02)), (2, (0.0, 1.08, 0.1)), (3, (0.0, 1.085, 0.14)),
                 (4, (0.0, round(1.47 - 0.5 * _rise(4), 3), 0.08)), (5, (0.0, round(1.78 - _rise(5), 3), 0.04)),
                 (6, (0.0, round(2.02 - _rise(6), 3), 0.03)), (7, (0.0, round(2.24 - _rise(7), 3), 0.02)),
                 (8, (0.0, round(2.45 - _rise(8), 3), 0.01)), (9, AIR["root"])],
        # (the hang's sway squared up in the coil, so both arms lock alike in the push)
        "roll": [(0, HANG["roll"]), (2, 0.0), (9, AIR["roll"])], "twist": [(0, HANG["twist"]), (2, 0.0), (9, AIR["twist"])],
        "side": [(0, HANG["side"]), (2, 0.0), (9, AIR["side"])],
        "hips": [(0, HANG["hips"]), (1, 30), (2, 14), (3, 10), (4, -2), (5, -6), (7, 4), (9, AIR["hips"])],
        "chest": [(0, HANG["chest"]), (1, 12), (2, 0), (3, -2), (4, -8), (5, -8), (7, 2), (9, AIR["chest"])],
        "head": [(0, HANG["head"]), (1, -28), (2, -20), (3, -12), (4, -4), (5, 2), (7, 6), (9, AIR["head"])],
        "clav_r": [(0, HANG["clav_r"]), (1, (8, -14)), (2, (0, 14)), (3, (0, 16)), (4, (-4, -14)), (5, (-4, -26)), (7, (0, -16)),
                   (9, AIR["clav_r"])],
        "clav_l": [(0, HANG["clav_l"]), (1, (8, -14)), (2, (0, 14)), (3, (0, 16)), (4, (-4, -14)), (5, (-4, -26)), (7, (0, -16)),
                   (9, AIR["clav_l"])],
        "hand_r": [(0, GR), (3, GR), (4, (-0.45, round(2.58 - 0.5 * _rise(4), 3), 0.24)), (5, (-0.34, 1.8, 0.06)),
                   (7, (-0.5, 1.52, 0.1)), (9, AR)],
        "hand_l": [(0, GL), (3, GL), (4, (0.45, round(2.59 - 0.5 * _rise(4), 3), 0.22)), (5, (0.35, 1.79, 0.04)),
                   (7, (0.51, 1.51, 0.08)), (9, AL)],
        "face_r": [(0, "deck"), (3, "deck"), (4, "fling"), (5, "sky"), (9, "balance")],
        "face_l": [(0, "deck"), (3, "deck"), (4, "fling"), (5, "sky"), (9, "balance")],
        "pole_r": [(0, HANG["pole_r"]), (1, (-0.45, -1.0, -0.7)), (2, (-0.4, -0.2, -1.0)), (3, (-0.4, 0.0, -1.0)), (5, (-1.0, 0.0, 0.0)),
                   (9, AIR["pole_r"])],
        "pole_l": [(0, HANG["pole_l"]), (1, (0.45, -1.0, -0.7)), (2, (0.4, -0.2, -1.0)), (3, (0.4, 0.0, -1.0)), (5, (1.0, 0.0, 0.0)),
                   (9, AIR["pole_l"])],
        "grip_r": [(0, HANG["grip_r"]), (3, 0.1), (4, -0.3), (5, -0.4), (9, AIR["grip_r"])],
        "grip_l": [(0, HANG["grip_l"]), (3, 0.1), (4, -0.3), (5, -0.4), (9, AIR["grip_l"])],
        "foot_r": [(0, GFR), (1, _up(GFR, 0.04)), (2, (-0.13, 1.18, 0.17)), (3, (-0.13, 1.16, 0.16)),
                   (4, (-0.12, round(1.75 - 0.5 * _rise(4), 3), 0.1)), (5, (-0.13, 0.44, 0.12)), (7, (-0.14, 0.38, 0.16)),
                   (9, AFR)],
        "foot_l": [(0, GFL), (1, _up(GFL, 0.04)), (2, (0.13, 1.14, 0.165)), (3, (0.13, 1.14, 0.15)),
                   (4, (0.12, round(1.79 - 0.5 * _rise(4), 3), 0.08)), (5, (0.13, 0.48, 0.06)), (7, (0.14, 0.44, 0.0)),
                   (9, AFL)],
        "heel_r": [(0, HANG["heel_r"]), (1, 4), (2, 50), (3, 56), (4, 60), (5, 45), (7, 35), (9, AIR["heel_r"])],
        "heel_l": [(0, HANG["heel_l"]), (1, 6), (2, 52), (3, 58), (4, 62), (5, 47), (7, 37), (9, AIR["heel_l"])],
        "fyaw_r": [(0, HANG["fyaw_r"]), (3, 4), (9, AIR["fyaw_r"])], "fyaw_l": [(0, HANG["fyaw_l"]), (3, 4), (9, AIR["fyaw_l"])],
        "knee_r": [(0, HANG["knee_r"]), (1, (-0.6, 0.3, 1.0)), (3, (-0.1, 0.0, 1.0)), (5, (-0.2, 0.3, 1.0)), (9, AIR["knee_r"])],
        "knee_l": [(0, HANG["knee_l"]), (1, (0.6, 0.3, 1.0)), (3, (0.1, 0.0, 1.0)), (5, (0.2, 0.3, 1.0)), (9, AIR["knee_l"])],
    },
    # the roll in (22 f, 0.75 s): a dip, then the arms spring the body up over the lip to an apex (f4-f5: the hips over the
    # hands, the knees tucked, the head carried out ahead of the hands, a beat), the hands hop forward and are planted on the
    # deck ahead (f5-f7, the elbows giving), the chin tucked onto the chest and the trunk rolled onto its right side so the
    # right shoulder blade takes the deck (not the head): a forward roll along the diagonal from the right shoulder to the
    # left hip in a tight ball, the hands round the shins from f8 (the code carries him in), the feet come round under him
    # into a crouch and he rises to the stand CLIMB_IN in, a touch past (onto the toes) and settled, the arms two frames
    # behind.  hold_s: the apex over the lip (the code's travel may start); strike_s: the shoulder on the deck; back_s: on his
    # feet again (the travel done)
    "edge_roll": dict({
        "length": 22, "base": HANG, "floor": LIP_Y,
        "meta": dict(EDGE_META, hold_s=5 / FPS, strike_s=7 / FPS, back_s=15 / FPS, end_in=CLIMB_IN),
        # (pass 3: the apex held up over the lip at f4-f5 with the face still forward, the chin tucked from f6; the turn about
        # a higher middle so the hips travel one arc; the ball closed through the turn (the heels at the seat, the knees
        # together); the shoulder-roll twist faded by f8; the head tipped well off the line so the hat clears the deck)
        "flip": [(0, 0), (5, 0), (6, 48), (7, 122), (9, 196), (11, 256), (13, 325), (14, 352), (15, 360), (22, 360)],
        "ground": [(0, 0), (5, 0), (6, 1), (13, 1), (14, 0.5), (15, 0), (22, 0)],
        "pivot": [(0, (0.0, LIP_Y + 0.55, 0.95)), (22, (0.0, LIP_Y + 0.55, 0.95))],
        "root": [(0, HANG["root"]), (1, (0.0, 0.85, 0.0)), (3, (0.0, 1.26, 0.28)), (4, (0.0, 1.48, 0.45)), (5, (0.0, 1.43, 0.63)),
                 (7, (0.0, 1.55, 0.8)), (13, (0.0, 1.55, 0.8)), (15, (0.0, 1.62, 0.92)), (17, (0.0, 1.84, 0.95)),
                 (19, (0.0, 1.997, 0.95)), (21, (0.0, 1.982, 0.95)), (22, DROOT)],
        "hips": [(0, HANG["hips"]), (1, 26), (3, 40), (4, 64), (5, 56), (6, 42), (7, 46), (13, 46), (15, 34), (17, 16), (19, 0),
                 (21, -1), (22, 0)],
        "chest": [(0, HANG["chest"]), (1, 8), (3, 20), (4, 24), (5, 30), (6, 44), (7, 52), (13, 52), (15, 20), (17, 8), (19, -2),
                  (21, 0.5), (22, 0)],
        "head": [(0, HANG["head"]), (1, -20), (3, -12), (4, 10), (5, 10), (6, 50), (7, 88), (12, 88), (13, 60), (15, 18), (17, 6),
                 (19, -2), (21, 0.5), (22, 0)],
        "roll": [(0, HANG["roll"]), (4, 0), (6, 8), (8, 4), (12, 0), (22, 0)],
        "twist": [(0, HANG["twist"]), (4, 0), (5, 6), (6, 26), (8, 12), (12, 0), (22, 0)],
        # (the head turned and tipped away from the right shoulder, off the roll's line, so the shoulder blade meets the deck)
        "tilt": [(0, 0), (4, 0), (5, 8), (6, 15), (9, 15), (12, 0), (22, 0)],
        "side": [(0, HANG["side"]), (4, 0), (6, -20), (9, -20), (12, 0), (22, 0)],
        "look": [(0, HANG["look"]), (4, 0), (6, 75), (9, 75), (12, 0), (22, 0)],
        "clav_r": [(0, HANG["clav_r"]), (3, (4, 6)), (5, (8, 10)), (7, (12, 6)), (13, (12, 6)), (16, (6, 2)), (22, (0, 0))],
        "clav_l": [(0, HANG["clav_l"]), (3, (4, 6)), (5, (8, 10)), (7, (12, 6)), (13, (12, 6)), (16, (6, 2)), (22, (0, 0))],
        "hand_r": [(0, GR), (3, GR), (4, (-0.21, 2.12, 0.7)), (5, (-0.2, DECK_PALM, 0.98)),
                   (6, _unturn((-0.2, DECK_PALM + 0.07, 0.97), 48, (0.0, LIP_Y + 0.55, 0.95))),
                   (7, _unturn((-0.2, DECK_PALM + 0.1, 0.92), 122, (0.0, LIP_Y + 0.55, 0.95))), (9, (-0.16, 2.42, 1.08)),
                   (13, (-0.16, 2.42, 1.08)), (15, (-0.26, 2.62, 1.3)), (18, (-0.25, 2.8, 1.12)), (20, _add(DHR, (-0.025, 0.045, 0.06))),
                   (22, DHR)],
        "hand_l": [(0, GL), (3, GL), (4, (0.21, 2.12, 0.7)), (5, (0.2, DECK_PALM, 0.98)),
                   (6, _unturn((0.2, DECK_PALM + 0.07, 0.97), 48, (0.0, LIP_Y + 0.55, 0.95))),
                   (7, _unturn((0.2, DECK_PALM + 0.1, 0.92), 122, (0.0, LIP_Y + 0.55, 0.95))), (9, (0.16, 2.42, 1.08)),
                   (13, (0.16, 2.42, 1.08)), (15, (0.26, 2.62, 1.28)), (18, (0.25, 2.8, 1.12)), (20, _add(DHL, (0.025, 0.045, 0.06))),
                   (22, DHL)],
        "face_r": [(0, "deck"), (5, "deck"), (6, _unturn_way("deck", 48)), (7, _unturn_way("deck", 122)), (9, "hug"), (13, "hug"),
                   (15, "balance"), (19, "balance"), (21, "stand"), (22, "stand")],
        "face_l": [(0, "deck"), (5, "deck"), (6, _unturn_way("deck", 48, side="l")), (7, _unturn_way("deck", 122, side="l")),
                   (9, "hug"), (13, "hug"),
                   (15, "balance"), (19, "balance"), (21, "stand"), (22, "stand")],
        "pole_r": [(0, HANG["pole_r"]), (3, (-0.4, -0.2, -1.0)), (5, (-0.6, -0.3, -0.5)), (7, (-1.0, 0.2, -0.3)), (9, (-1.0, 0.0, 0.0)),
                   (13, (-1.0, 0.0, 0.0)), (16, (-0.8, -0.5, -0.3)), (22, STAND["pole_r"])],
        "pole_l": [(0, HANG["pole_l"]), (3, (0.4, -0.2, -1.0)), (5, (0.6, -0.3, -0.5)), (7, (1.0, 0.2, -0.3)), (9, (1.0, 0.0, 0.0)),
                   (13, (1.0, 0.0, 0.0)), (16, (0.8, -0.5, -0.3)), (22, STAND["pole_l"])],
        "grip_r": [(0, HANG["grip_r"]), (4, 0.2), (5, 0.1), (7, 0.1), (9, 0.6), (13, 0.6), (15, 0.1), (22, 0.4)],
        "grip_l": [(0, HANG["grip_l"]), (4, 0.2), (5, 0.1), (7, 0.1), (9, 0.6), (13, 0.6), (15, 0.1), (22, 0.4)],
        "foot_r": [(0, GFR), (1, GFR), (3, (-0.2, 1.66, 0.12)), (4, (-0.14, 2.2, 0.3)), (5, (-0.12, 2.22, 0.5)),
                   (6, (-0.12, 2.23, 0.76)), (7, (-0.12, 2.22, 0.75)), (13, (-0.12, 2.22, 0.75)),
                   (15, DFR), (22, DFR)],
        "foot_l": [(0, GFL), (1, GFL), (3, (0.2, 1.62, 0.12)), (4, (0.14, 2.21, 0.29)), (5, (0.12, 2.23, 0.49)),
                   (6, (0.12, 2.23, 0.76)), (7, (0.12, 2.22, 0.75)), (13, (0.12, 2.22, 0.75)),
                   (15, DFL), (22, DFL)],
        "heel_r": [(0, HANG["heel_r"]), (3, 30), (7, 40), (13, 40), (15, 0), (18, 0), (19, 5), (21, 0), (22, 0)],
        "heel_l": [(0, HANG["heel_l"]), (3, 30), (7, 40), (13, 40), (15, 0), (18, 0), (19, 5), (21, 0), (22, 0)],
        "fyaw_r": [(0, HANG["fyaw_r"]), (5, 4), (14, 4), (22, 7)], "fyaw_l": [(0, HANG["fyaw_l"]), (5, 4), (14, 4), (22, 7)],
        "knee_r": [(0, HANG["knee_r"]), (3, (-1.0, 0.3, 0.3)), (4, (-0.5, 0.5, 1.0)), (6, (-0.2, 0.8, 0.6)), (13, (-0.2, 0.8, 0.6)),
                   (16, (-0.25, 0.0, 1.0)), (21, "auto")],
        "knee_l": [(0, HANG["knee_l"]), (3, (1.0, 0.3, 0.3)), (4, (0.5, 0.5, 1.0)), (6, (0.2, 0.8, 0.6)), (13, (0.2, 0.8, 0.6)),
                   (16, (0.25, 0.0, 1.0)), (21, "auto")],
    }),
    # the edge attack (18 f, 0.6 s): a dip and a hard press up, the left hand hopping forward onto the deck and the left foot
    # planted by it in a deep crouch, the right leg stretched out low to the side and the right arm thrown back and up for the
    # balance (the wind-up, the hips turned away); then the low sweep (Northern Shaolin / Hung Gar's ground sweep): the whole
    # trunk turns over the bent left leg, the head low and the eyes along the sweep, the straight right leg swept round flat
    # along the deck from the right side across the front to the left, slowing at its end, the right arm whipping across the
    # other way as the counterweight (overshooting, settling); the leg drawn in under him and stood up CLIMB_IN in.
    # hold_s: crouched, the leg out; strike_s: the sweep straight ahead; back_s: the leg at the end of the sweep
    "edge_attack": {
        "length": 18, "base": HANG,
        "meta": dict(EDGE_META, hold_s=6 / FPS, strike_s=9 / FPS, back_s=12 / FPS, end_in=CLIMB_IN, hand="foot_r"),
        "root": [(0, HANG["root"]), (1, (0.0, 0.85, 0.0)), (3, (0.0, 1.12, 0.14)), (4, (0.0, 1.27, 0.34)), (5, (0.0, 1.39, 0.56)),
                 (6, (0.02, 1.405, 0.66)), (7, (-0.03, 1.37, 0.74)), (8, (-0.02, 1.35, 0.82)), (9, (0.02, 1.35, 0.86)),
                 (10, (0.07, 1.35, 0.84)), (11, (0.18, 1.34, 0.8)), (12, (0.14, 1.44, 0.78)),
                 (14, (0.0, 1.84, 0.9)), (16, (0.0, 1.997, 0.95)), (17, (0.0, 1.983, 0.95)), (18, DROOT)],
        "yaw": [(0, 0), (5, -8), (6, -20), (8, -6), (9, 10), (11, 45), (12, 42), (14, 12), (16, -2), (18, 0)],
        "hips": [(0, HANG["hips"]), (1, 26), (3, 30), (5, 54), (6, 60), (9, 60), (11, 56), (12, 48), (14, 16), (16, 1), (18, 0)],
        "chest": [(0, HANG["chest"]), (1, 8), (3, 16), (5, 22), (6, 22), (8, 18), (10, 18), (11, 18), (12, 14), (14, 6), (16, -2),
                  (18, 0)],
        "side": [(0, HANG["side"]), (5, 10), (6, 20), (9, 20), (11, 21), (12, 12), (14, 2), (18, 0)],
        "head": [(0, HANG["head"]), (1, -20), (3, -20), (5, -28), (6, -30), (9, -26), (12, -22), (14, -6), (16, 1), (18, 0)],
        "look": [(0, HANG["look"]), (6, -10), (8, 4), (9, 12), (11, 20), (13, 8), (16, 0), (18, 0)],
        "clav_r": [(0, HANG["clav_r"]), (3, (4, 6)), (6, (-4, -10)), (10, (8, -4)), (12, (4, -2)), (15, (2, 2)), (18, (0, 0))],
        "clav_l": [(0, HANG["clav_l"]), (3, (4, 6)), (6, (10, 24)), (11, (10, 28)), (12, (10, 22)), (15, (2, 2)), (18, (0, 0))],
        "hand_r": [(0, GR), (3, GR), (4, (-0.34, 2.36, 0.72)), (6, (-0.54, 2.66, 0.66)), (8, (-0.37, 2.64, 0.8)), (10, (0.1, 2.5, 1.0)),
                   (11, (0.14, 2.5, 1.0)), (12, (0.17, 2.53, 0.98)), (14, (-0.18, 2.7, 1.02)), (16, _add(DHR, (-0.02, 0.03, 0.03))),
                   (18, DHR)],
        "hand_l": [(0, GL), (3, GL), (4, (0.22, 2.2, 0.8)), (5, (0.145, 2.05, 0.97)), (10, (0.145, 2.05, 0.97)), (11, (0.18, 2.12, 0.975)),
                   (13, (0.26, 2.5, 1.0)), (14, (0.28, 2.72, 1.06)), (16, _add(DHL, (0.0, 0.03, 0.02))), (18, DHL)],
        "face_r": [(0, "deck"), (3, "deck"), (5, "balance"), (12, "balance"), (15, "stand"), (18, "stand")],
        "face_l": [(0, "deck"), (3, "deck"), (5, "deck_out"), (12, "deck_out"), (15, "stand"), (18, "stand")],
        "pole_r": [(0, HANG["pole_r"]), (3, (-0.4, -0.2, -1.0)), (5, (-0.6, -0.6, -0.4)), (10, (-0.2, -1.0, -0.2)),
                   (12, (-0.4, -0.8, -0.3)), (18, STAND["pole_r"])],
        "pole_l": [(0, HANG["pole_l"]), (3, (0.4, -0.2, -1.0)), (5, (1.0, 0.0, -0.3)), (12, (1.0, 0.0, -0.3)),
                   (18, STAND["pole_l"])],
        "grip_r": [(0, HANG["grip_r"]), (4, -0.2), (6, 0.1), (12, 0.1), (15, 0.4), (18, 0.4)],
        "grip_l": [(0, HANG["grip_l"]), (4, -0.2), (5, 0.1), (12, 0.1), (15, 0.4), (18, 0.4)],
        # (the right leg: up the face, stretched out low to the side, swept round flat at the shin's height over the deck from
        # the right across the front to the left of the planted left foot, slowing at its end, then lifted in over the left
        # foot and drawn in under him; the left foot planted under him in the crouch)
        # (pass 3: swept round at full leg length, about 0.85 m from the planted left foot, through about 160 degrees)
        "foot_r": [(0, GFR), (1, GFR), (3, (-0.24, 1.48, 0.16)), (4, (-0.42, 1.92, 0.22)), (5, (-0.5, 2.14, 0.44)), (6, (-0.66, 2.1, 0.62)),
                   (7, (-0.7, 2.1, 1.02)), (8, (-0.52, 2.1, 1.32)), (9, (-0.08, 2.1, 1.52)), (10, (0.34, 2.1, 1.42)),
                   (11, (0.69, 2.1, 1.12)), (12, (0.72, 2.1, 0.84)), (13, (0.45, 2.22, 0.98)), (14, (-0.05, 2.16, 0.95)), (16, DFR),
                   (18, DFR)],
        "foot_l": [(0, GFL), (2, GFL), (3, (0.2, 1.38, 0.17)), (4, (0.2, 1.96, 0.26)), (5, (0.17, 2.077, 0.7)), (12, (0.17, 2.077, 0.7)),
                   (14, (0.15, 2.077, 0.82)), (16, DFL), (18, DFL)],
        "heel_r": [(0, HANG["heel_r"]), (3, 10), (5, 30), (6, 20), (11, 20), (12, 24), (14, 10), (16, 0), (18, 0)],
        "heel_l": [(0, HANG["heel_l"]), (3, HANG["heel_l"]), (5, 0), (14, 0), (16, 4), (17, 0), (18, 0)],
        "fyaw_r": [(0, HANG["fyaw_r"]), (5, -10), (11, -10), (16, 7)], "fyaw_l": [(0, HANG["fyaw_l"]), (5, 30), (12, 30), (16, 7)],
        "knee_r": [(0, HANG["knee_r"]), (3, (-1.0, 0.2, 0.3)), (5, (-0.3, 1.0, 0.2)), (12, (-0.3, 1.0, 0.2)), (14, (-0.2, 0.0, 1.0)),
                   (17, "auto")],
        "knee_l": [(0, HANG["knee_l"]), (3, (1.0, 0.2, 0.3)), (4, (1.0, 0.5, 0.4)), (5, (0.6, 0.2, 1.0)), (12, (0.6, 0.2, 1.0)), (15, "auto")],
    },
}
# (the hang's own sway at its first frame, the trunk's roll, side bend and twist and the head's glance, eased out over the
# first two thirds of a get-up, which ends on the stand, or of the jump, which ends on the fall, where a clip leaves them out)
for _k in ("edge_climb", "edge_roll", "edge_attack", "edge_jump"):
    _end = AIR if _k == "edge_jump" else STAND
    _n = SET5[_k]["length"]
    for _ch in ("roll", "side", "twist", "look"):
        if _ch not in SET5[_k]:
            SET5[_k][_ch] = [(0, HANG[_ch]), (_n * 2 // 3, _end[_ch]), (_n, _end[_ch])]
CLIPS.update(SET5)


## The ground rolls' tucked ball (the figure upright as if squatting; the flip or the cart turns it about ROLL_PIVOT): the hips
## sunk to the heels, the back rounded over the knees, the chin tucked onto the chest, the knees drawn in to it, the hands
## round the shins.
ROLL_PIVOT = (0.0, 0.5, 0.18)
TUCK = {"root": (0.0, -0.45, 0.05), "hips": 48.0, "chest": 44.0, "head": 85.0, "clav": (10.0, 6.0),
        "hand_r": (-0.15, 0.37, 0.38), "foot_r": (-0.12, 0.2, 0.1), "heel": 34.0}
## The forward roll's closed ball (pass 3; the same upright squat frame): the back rounder, the heels at the seat under the
## hips and the knees lifted up to the chest (their poles up and ahead), the hands on the shins.
BALL = {"chest": 54.0, "foot_r": (-0.12, 0.22, 0.0), "hand_r": (-0.16, 0.42, 0.32), "knee_r": (-0.2, 0.8, 0.6)}
## The rise out of a roll: a crouch on both feet, the arms out ahead for the balance.
CROUCH = {"root": (0.0, -0.4, 0.05), "hips": 30.0, "chest": 14.0, "head": 8.0, "hand_r": (-0.24, 0.62, 0.42)}
## The forward and the back roll's turn at every frame of the roll (deg; the side roll's cart its own, below).
ROLL_TURN = [(0, 0), (2, 0), (3, 30), (4, 66), (5, 105), (6, 148), (7, 190), (8, 228), (9, 262), (10, 295), (11, 325), (12, 350),
             (13, 360), (18, 360)]
## The side roll's cart: tipped onto the right shoulder and hip (f3-f6), three quarters onto the back at the strike (f7),
## quickening over the back and the left side, up.
SIDE_TURN = [(0, 0), (2, 0), (3, 30), (4, 70), (5, 100), (6, 124), (7, 145), (8, 185), (9, 230), (10, 280), (11, 320), (12, 350),
             (13, 360), (18, 360)]
## The deck's palm (a palm laid flat on the floor of a ground roll).
FLOOR_PALM = 0.03


def _roll(kind):
    """A ground roll (18 f, facing kept; kind "f", "b" or "side"): dropped into the ball (f0-f2), turned whole through 360
    degrees over f3-f13 on the deck (the ground contact: its lowest surface kept on the deck), the feet planted at f13 (the
    side roll's left at f12) in a crouch, risen to the stand by f17 a touch past it (onto the toes) and settled at f18, the
    arms two frames behind the trunk."""
    sign = -1 if kind == "b" else 1
    turn = "cart" if kind == "side" else "flip"
    table = SIDE_TURN if kind == "side" else ROLL_TURN
    t = [(fr, v * sign) for fr, v in table]
    # (the forward roll's ball: the heels drawn in at the seat and the knees lifted to the chest, the hands on the shins)
    hr, hl = BALL["hand_r"], _mx(BALL["hand_r"])
    fr, fl = BALL["foot_r"], _mx(BALL["foot_r"])
    c = {
        "length": 18, "pivot": [(0, ROLL_PIVOT), (18, ROLL_PIVOT)],
        "meta": {"hold_s": 2 / FPS, "strike_s": 7 / FPS, "back_s": 13 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        turn: t,
        "ground": [(0, 0), (2, 0), (3, 1), (12, 1), (13, 0), (18, 0)],
        # (pass 3: the drop eased in over f0-f3 behind a short step of the right foot, the palms planted at f2-f3; the ball held
        # closed through the turn (the feet at the seat, no letting out), the shoulder roll's twist and roll halved so the legs
        # stay together upside down)
        "root": [(0, STAND["root"]), (1, (0.0, -0.12, 0.06)), (2, (0.0, -0.32, 0.12)), (3, TUCK["root"]), (12, TUCK["root"]),
                 (13, CROUCH["root"]), (15, (0.0, -0.16, 0.02)), (16, (0.0, -0.035, 0.0)), (17, (0.0, -0.004, 0.0)),
                 (18, STAND["root"])],
        "hips": [(0, 0), (1, 12), (2, 36), (3, TUCK["hips"]), (12, TUCK["hips"]), (13, CROUCH["hips"]), (15, 12), (16, 2), (17, -1),
                 (18, 0)],
        "chest": [(0, 0), (1, 8), (2, 32), (3, BALL["chest"]), (12, BALL["chest"]), (13, CROUCH["chest"]), (15, 5), (16, 0),
                  (17, -2), (18, 0)],
        "head": [(0, 0), (1, 10), (2, 34), (3, 70), (4, TUCK["head"]), (11, TUCK["head"]), (12, 60), (13, 14), (15, 3), (18, 0)],
        # (the shoulder roll's diagonal: the trunk rolled onto its right side, so the right shoulder blade meets the deck and
        # the roll runs over the back to the left hip)
        "roll": [(0, 0), (2, 0), (3, 2), (4, 4), (9, 4), (12, 0), (18, 0)],
        "twist": [(0, 0), (2, 4), (3, 10), (4, 14), (9, 14), (12, 0), (18, 0)],
        # (the head turned and tipped away from that shoulder, off the roll's line)
        "tilt": [(0, 0), (2, 0), (3, 20), (4, 40), (9, 40), (12, 0), (18, 0)],
        "look": [(0, 0), (2, 0), (4, 20), (9, 20), (12, 0), (18, 0)],
        "clav_r": [(0, (0, 0)), (2, (18, 8)), (3, (22, 6)), (9, (22, 6)), (12, TUCK["clav"]), (14, (4, 2)), (18, (0, 0))],
        "clav_l": [(0, (0, 0)), (2, (18, 8)), (3, TUCK["clav"]), (12, TUCK["clav"]), (14, (4, 2)), (18, (0, 0))],
        # (the palms on the deck ahead of the feet at the drop, the elbows giving as he goes over them, then round the shins)
        "hand_r": [(0, HR), (1, (-0.215, 0.71, 0.28)), (2, (-0.2, 0.36, 0.5)),
                   (3, _unturn((-0.22, FLOOR_PALM, 0.42), 30, ROLL_PIVOT)),
                   (4, _unturn((-0.22, -0.03, 0.36), 66, ROLL_PIVOT)), (5, _unturn((-0.24, -0.01, 0.28), 105, ROLL_PIVOT)), (7, hr),
                   (12, hr), (13, CROUCH["hand_r"]),
                   (15, (-0.26, 0.71, 0.32)), (16, (-0.24, 0.83, 0.19)), (17, (-0.21, 0.8, 0.11)), (18, HR)],
        "hand_l": [(0, HL), (1, (0.22, 0.7, 0.28)), (2, (0.2, 0.37, 0.5)),
                   (3, _unturn((0.22, FLOOR_PALM, 0.42), 30, ROLL_PIVOT)),
                   (4, _unturn((0.22, -0.03, 0.36), 66, ROLL_PIVOT)), (5, _unturn((0.24, 0.0, 0.28), 105, ROLL_PIVOT)), (7, hl),
                   (12, hl), (13, _mx(CROUCH["hand_r"])),
                   (15, (0.26, 0.72, 0.32)), (16, (0.24, 0.83, 0.19)), (17, (0.21, 0.8, 0.11)), (18, HL)],
        "face_r": [(0, "stand"), (1, "palm_down"), (2, "deck"), (3, _unturn_way("deck", 30)), (4, _unturn_way("deck", 66)),
                   (5, _unturn_way("deck", 105)), (7, "hug"), (12, "hug"),
                   (13, "balance"), (16, "balance"), (18, "stand")],
        "face_l": [(0, "stand"), (1, "palm_down"), (2, "deck"), (3, _unturn_way("deck", 30, side="l")),
                   (4, _unturn_way("deck", 66, side="l")), (5, _unturn_way("deck", 105, side="l")), (7, "hug"), (12, "hug"),
                   (13, "balance"), (16, "balance"), (18, "stand")],
        "pole_r": [(0, STAND["pole_r"]), (2, (-0.8, -0.2, -0.4)), (3, (-1.0, 0.0, -0.2)), (5, (-1.0, -0.2, 0.0)), (12, (-1.0, -0.2, 0.0)),
                   (14, (-0.8, -0.5, -0.3)), (18, STAND["pole_r"])],
        "pole_l": [(0, STAND["pole_l"]), (2, (0.8, -0.2, -0.4)), (3, (1.0, 0.0, -0.2)), (5, (1.0, -0.2, 0.0)), (12, (1.0, -0.2, 0.0)),
                   (14, (0.8, -0.5, -0.3)), (18, STAND["pole_l"])],
        "grip_r": [(0, 0.4), (2, 0.0), (5, 0.0), (7, 0.6), (12, 0.6), (13, 0.15), (18, 0.4)],
        "grip_l": [(0, 0.4), (2, 0.0), (5, 0.0), (7, 0.6), (12, 0.6), (13, 0.15), (18, 0.4)],
        # (the lead-in: the right foot steps 15 cm forward at f1-f2; then both feet held at the seat through the turn)
        "foot_r": [(0, FR), (1, _add(FR, (0.0, 0.05, 0.08))), (2, _add(FR, (0.0, 0.0, 0.15))), (3, fr), (11, fr),
                   (13, FR), (18, FR)],
        "foot_l": [(0, FL), (2, FL), (3, fl), (11, fl), (13, FL), (18, FL)],
        "heel_r": [(0, 0), (1, 20), (2, 10), (3, TUCK["heel"]), (11, TUCK["heel"]), (13, 0), (16, 0), (17, 4), (18, 0)],
        "heel_l": [(0, 0), (2, 25), (3, TUCK["heel"]), (11, TUCK["heel"]), (13, 0), (16, 0), (17, 4), (18, 0)],
        "knee_r": [(0, "auto"), (2, (-0.25, 0.0, 1.0)), (3, BALL["knee_r"]), (11, BALL["knee_r"]), (13, (-0.25, 0.0, 1.0)),
                   (14, (-0.25, 0.0, 1.0)), (17, "auto")],
        "knee_l": [(0, "auto"), (2, (0.25, 0.0, 1.0)), (3, _mx(BALL["knee_r"])), (11, _mx(BALL["knee_r"])), (13, (0.25, 0.0, 1.0)),
                   (14, (0.25, 0.0, 1.0)), (17, "auto")],
    }
    if kind == "b":
        # (sat back: the trunk stays up over the seat, the back rounded and the chin in, the hands up by the ears from the drop
        # and the knees pulled in to the chest by f5; upside down the palms are planted by the head (the elbows up) and the arms
        # push (f9-f11), lifting the head clear while the legs pike over in an arc and the feet plant at f12)
        c["roll"] = [(0, 0), (18, 0)]
        # (pass 3: over the top quicker at the end, so the head is up off the deck before the feet land)
        c["flip"] = [(fr, v) for fr, v in t if fr < 10] + [(10, -310), (11, -345), (12, -358), (13, -360), (18, -360)]
        for k in ("tilt", "look", "twist"):
            c.pop(k)
        c["root"] = [(0, STAND["root"]), (1, (0.0, -0.14, -0.04)), (2, (0.0, -0.36, -0.1)), (3, TUCK["root"]), (12, TUCK["root"]),
                     (13, CROUCH["root"]), (15, (0.0, -0.16, 0.02)), (16, (0.0, -0.035, 0.0)), (17, (0.0, -0.004, 0.0)),
                     (18, STAND["root"])]
        c["hips"] = [(0, 0), (1, 4), (2, 12), (3, 30), (12, 30), (13, CROUCH["hips"]), (15, 12), (16, 2), (17, -1), (18, 0)]
        c["chest"] = [(0, 0), (1, 10), (2, 26), (3, TUCK["chest"]), (12, TUCK["chest"]), (13, CROUCH["chest"]), (15, 5), (16, 0),
                      (17, -2), (18, 0)]
        # (pass 3: the knees drawn together to the chest (f5-f7) and the hands kept by the ears, compact; the palms planted from
        # f7 and the head pitched further in, so the push lifts the hat clear of the deck)
        c["head"] = [(0, 0), (1, 10), (2, 24), (3, 34), (6, 48), (7, 65), (10, 65), (11, 35), (12, 18), (13, 8), (15, 3), (18, 0)]
        c["knee_r"] = [(0, "auto"), (2, (-0.15, 0.0, 1.0)), (14, (-0.15, 0.0, 1.0)), (17, "auto")]
        c["knee_l"] = [(0, "auto"), (2, (0.15, 0.0, 1.0)), (14, (0.15, 0.0, 1.0)), (17, "auto")]
        c["pole_r"] = [(0, STAND["pole_r"]), (2, (-1.0, 0.0, 0.4)), (5, (-0.6, 0.0, 1.0)), (11, (-0.6, 0.0, 1.0)),
                       (14, (-0.8, -0.5, -0.3)), (18, STAND["pole_r"])]
        c["pole_l"] = [(0, STAND["pole_l"]), (2, (1.0, 0.0, 0.4)), (5, (0.6, 0.0, 1.0)), (11, (0.6, 0.0, 1.0)),
                       (14, (0.8, -0.5, -0.3)), (18, STAND["pole_l"])]
        for s, hx in (("r", -0.2), ("l", 0.2)):
            c["hand_" + s] = [(0, STAND["hand_" + s]), (1, (hx * 1.1, 0.98, 0.14)), (2, (hx, 0.95, 0.04)), (4, (hx, 1.0, 0.24)),
                              (5, (hx, 0.98, 0.3)), (6, (hx, 0.97, 0.32)),
                              (7, _unturn((hx, -0.02, 0.06), -190, ROLL_PIVOT)),
                              (8, _unturn((hx, -0.02, 0.14), -228, ROLL_PIVOT)), (9, _unturn((hx, -0.05, 0.3), -262, ROLL_PIVOT)),
                              (10, _unturn((hx, -0.03, 0.42), -295, ROLL_PIVOT)), (11, (hx, 1.02, 0.42)), (12, (hx * 1.2, 0.72, 0.42)), (13, (hx * 1.2, 0.62, 0.42)),
                              (15, (hx * 1.3, 0.71, 0.32)), (16, (hx * 1.2, 0.83, 0.19)), (17, (hx * 1.05, 0.8, 0.11)),
                              (18, STAND["hand_" + s])]
            c["face_" + s] = [(0, "stand"), (1, "ears"), (11, "ears"), (13, "balance"), (16, "balance"), (18, "stand")]
            c["grip_" + s] = [(0, 0.4), (2, 0.0), (11, 0.0), (13, 0.15), (18, 0.4)]
        for s, fx in (("r", -0.12), ("l", 0.12)):
            c["foot_" + s] = [(0, STAND["foot_" + s]), (2, STAND["foot_" + s]), (4, (fx, 0.3, 0.12)), (5, (fx, 0.45, 0.3)),
                              (7, (fx, 0.6, 0.46)), (9, (fx, 0.74, 0.5)), (10, (fx, 0.62, 0.44)), (11, (fx, 0.34, 0.22)),
                              (12, STAND["foot_" + s]), (18, STAND["foot_" + s])]
            c["heel_" + s] = [(0, 0), (2, 25), (4, 40), (11, 40), (12, 8), (13, 0), (16, 0), (17, 4), (18, 0)]
    if kind == "side":
        # (the weight shifted over the right foot first and the right hand reaching down beside it to take the deck; tipped
        # onto the right shoulder and hip, the back curled to the left so the knees draw toward the left shoulder, kept low
        # and across the body; three quarters onto the back at the strike, quickening over; the left leg lands first, then
        # the right, the hips settling a touch past to the left)
        # (pass 3: the weight shift reads first: the hips carried out over the right foot and the trunk leant to the right
        # (f1-f2), the left leg long, so he topples sideways over the right foot instead of diving forward; then a flat barrel
        # low on the deck, the thighs laid across the belly toward the left shoulder (the knees across and down, not up);
        # the head curled to the up side, the cheek clear; the cart easing into its quickening)
        c["root"] = [(0, STAND["root"]), (1, (-0.1, -0.12, 0.03)), (2, (-0.25, -0.34, 0.05)), (3, (-0.17, -0.45, 0.05)), (5, (-0.04, -0.45, 0.05)),
                     (12, TUCK["root"]), (13, CROUCH["root"]), (14, (0.04, -0.25, 0.03)), (15, (0.01, -0.15, 0.02)),
                     (16, (0.0, -0.035, 0.0)), (17, (0.0, -0.004, 0.0)), (18, STAND["root"])]
        c["roll"] = [(0, 0), (1, 6), (2, 14), (4, 10), (8, 0), (18, 0)]
        for k in ("tilt", "look", "twist"):
            c.pop(k)
        c["hips"] = [(0, 0), (1, 10), (2, 25), (3, 48), (5, 56), (12, 56), (13, CROUCH["hips"]), (15, 12), (16, 2), (17, -1),
                     (18, 0)]
        c["chest"] = [(0, 0), (1, 6), (2, 18), (3, 36), (5, TUCK["chest"]), (12, TUCK["chest"]), (13, CROUCH["chest"]), (15, 5),
                      (16, 0), (17, -2), (18, 0)]
        c["side"] = [(0, 0), (1, -6), (2, -10), (3, -10), (4, -16), (8, -16), (10, -6), (12, 0), (18, 0)]
        c["head"] = [(0, 0), (1, 6), (2, 18), (3, 50), (4, 72), (11, 72), (12, 50), (13, 14), (15, 3), (18, 0)]
        c["hand_r"] = [(0, HR), (1, (-0.3, 0.71, 0.15)), (2, (-0.43, 0.45, 0.19)),
                       (3, _unturn((-0.37, FLOOR_PALM + 0.07, 0.17), 30, ROLL_PIVOT, "z")), (5, (-0.06, 0.37, 0.38)), (12, (-0.06, 0.37, 0.38)),
                       (13, CROUCH["hand_r"]), (15, (-0.26, 0.71, 0.32)), (16, (-0.24, 0.83, 0.19)), (17, (-0.21, 0.8, 0.11)), (18, HR)]
        c["hand_l"] = [(0, HL), (1, (0.22, 0.7, 0.2)), (2, (0.15, 0.56, 0.36)), (4, (0.24, 0.37, 0.38)), (12, (0.24, 0.37, 0.38)),
                       (13, _mx(CROUCH["hand_r"])), (15, (0.26, 0.72, 0.32)), (16, (0.24, 0.83, 0.19)), (17, (0.21, 0.8, 0.11)), (18, HL)]
        c["face_r"] = [(0, "stand"), (1, "palm_down"), (2, "deck"), (3, _unturn_way("deck", 30, "z")), (5, "hug"), (12, "hug"),
                       (13, "balance"), (16, "balance"), (18, "stand")]
        c["face_l"] = [(0, "stand"), (2, "hug"), (12, "hug"), (13, "balance"), (16, "balance"), (18, "stand")]
        c["foot_r"] = [(0, FR), (2, FR), (4, (0.05, 0.27, 0.1)), (5, (0.05, 0.25, 0.12)), (11, (0.05, 0.25, 0.12)), (13, FR),
                       (18, FR)]
        c["foot_l"] = [(0, FL), (1, _add(FL, (0.03, 0.02, 0.0))), (2, _add(FL, (0.06, 0.04, -0.02))), (4, (0.22, 0.3, 0.04)),
                       (5, (0.2, 0.28, 0.05)), (10, (0.2, 0.28, 0.05)), (12, FL), (18, FL)]
        c["heel_r"] = [(0, 0), (2, 15), (4, TUCK["heel"]), (11, TUCK["heel"]), (13, 0), (16, 0), (17, 4), (18, 0)]
        c["heel_l"] = [(0, 0), (1, 10), (2, 30), (4, TUCK["heel"]), (10, TUCK["heel"]), (12, 0), (16, 0), (17, 4), (18, 0)]
        c["knee_r"] = [(0, "auto"), (2, (-0.1, 0.2, 1.0)), (4, (0.9, 0.3, 0.3)), (11, (0.9, 0.3, 0.3)), (14, (-0.25, 0.0, 1.0)),
                       (17, "auto")]
        c["knee_l"] = [(0, "auto"), (1, (0.15, 0.0, 1.0)), (2, (0.1, -0.1, 1.0)), (4, (0.9, 0.3, 0.3)), (10, (0.9, 0.3, 0.3)),
                       (13, (0.25, 0.0, 1.0)), (17, "auto")]
        c["meta"] = dict(c["meta"], travel="right")
        c["mirror"] = True
    return c


## The duck's forearms: in tight against the chest, the hands by the sides of the head, the fingers up, the palms in.
FACING["cover"] = ((0.12, 0.92, -0.36), (1.0, 0.0, 0.12))
## The duck's open guard (pass 3): the forearms up before the face, the fingers up and back with the sway, the palms out.
FACING["guard_out"] = ((0.15, 0.9, -0.4), (0.1, 0.4, 0.91))

SET5B = {
    # the forward roll (18 f; 3.5 m in 0.45 s by the code, facing kept): sunk into a crouch with the palms laid on the deck
    # ahead (the elbows giving), the chin tucked onto the chest; a shoulder roll: over the right shoulder blade and the
    # rounded back to the left hip in a tight ball; the feet come round under him and plant at the travel's end in a crouch;
    # up to the stand, a touch past and settled.  hold_s: the drop; strike_s: on the back; back_s: on his feet
    "roll_f": _roll("f"),
    # the back roll (18 f, facing kept): sat back into a crouch, the hands up by the ears and the knees in to the chest;
    # rolled back over the rounded back and the shoulders, the palms planted by the head pushing (the head kept clear) as the
    # legs pike over in an arc; the feet planted in a crouch, up
    "roll_b": _roll("b"),
    # the side roll (18 f, to his right; its twin to the left; facing kept): the weight over the right foot and the right hand
    # down beside it, tipped onto the right shoulder and hip, rolled over the back with the knees across the body toward the
    # left shoulder, kept low, and up off the left leg first, then the right
    "roll_side": _roll("side"),
    # the duck (14 f; intangible 0.04-0.30 s by the code): a deep sway down and back: the knees bend deep and drive forward
    # over the toes, the hips drop fast (most of the way by f2) and the trunk sways back from them (the root a little forward
    # to keep the weight over the feet), the head drawn down and back, the forearms pulled in tight to the chest with the
    # hands by the sides of the head; a moving hold at the bottom (the head still sinking, the chest drifting back), the head
    # leading the return at f8; the chest coming up a touch past and settling, the hands a frame or two behind it, a last
    # small dip in the knees.  hold_s: going down; strike_s: the lowest; back_s: the return
    "duck": {
        "length": 14,
        "meta": {"hold_s": 3 / FPS, "strike_s": 4 / FPS, "back_s": 9 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        # (pass 3: the mass kept over the mid-foot (the root forward 13 cm, the knees driven out over the toes); a moving hold:
        # still sinking f4-f8, the chest drifting back and caught; the shoulders turned 15 degrees at the bottom, a slip, not a
        # flinch; the hands open, palms out, the forearms a guard before the face, a frame or two behind the chest each way)
        "root": [(0, STAND["root"]), (1, (0.0, -0.13, 0.04)), (2, (0.0, -0.31, 0.08)), (3, (0.0, -0.41, 0.1)),
                 (4, (0.0, -0.45, 0.11)), (6, (0.0, -0.48, 0.115)), (8, (0.0, -0.5, 0.115)), (9, (0.0, -0.46, 0.105)),
                 (11, (0.0, -0.15, 0.04)), (12, (0.0, -0.012, 0.0)), (13, (0.0, -0.027, -0.004)), (14, STAND["root"])],
        "hips": [(0, 0), (1, 2), (2, -7), (3, -14), (4, -18), (8, -19), (9, -16), (11, -3), (12, 1), (14, 0)],
        "chest": [(0, 0), (1, -4), (2, -17), (3, -28), (4, -34), (6, -38), (8, -36), (9, -31), (11, -8), (12, 3), (13, 1.5), (14, 0)],
        "twist": [(0, 0), (3, 4), (5, 12), (7, 15), (9, 11), (11, 2), (13, -1), (14, 0)],
        "head": [(0, 0), (1, 6), (2, 18), (3, 26), (4, 30), (7, 32), (8, 30), (9, 24), (11, 10), (13, 2), (14, 0)],
        "clav_r": [(0, (0, 0)), (2, (6, -4)), (3, (10, -8)), (5, (14, -10)), (9, (14, -10)), (12, (4, 0)), (14, (0, 0))],
        "clav_l": [(0, (0, 0)), (2, (6, -4)), (3, (10, -8)), (5, (14, -10)), (9, (14, -10)), (12, (4, 0)), (14, (0, 0))],
        "hand_r": [(0, HR), (1, (-0.21, 0.84, 0.16)), (2, (-0.18, 0.92, 0.16)), (3, (-0.14, 0.95, 0.12)), (4, (-0.12, 0.92, 0.06)),
                   (5, (-0.11, 0.89, 0.03)), (8, (-0.11, 0.87, 0.02)), (9, (-0.11, 0.88, 0.03)), (10, (-0.12, 0.92, 0.06)),
                   (11, (-0.14, 1.06, 0.12)), (12, (-0.2, 1.02, 0.12)), (13, (-0.21, 0.88, 0.09)), (14, HR)],
        "hand_l": [(0, HL), (1, (0.21, 0.85, 0.16)), (2, (0.18, 0.93, 0.16)), (3, (0.14, 0.96, 0.12)), (4, (0.12, 0.93, 0.06)),
                   (5, (0.11, 0.9, 0.03)), (8, (0.11, 0.88, 0.02)), (9, (0.11, 0.89, 0.03)), (10, (0.12, 0.93, 0.06)),
                   (11, (0.14, 1.07, 0.12)), (12, (0.2, 1.03, 0.12)), (13, (0.21, 0.89, 0.09)), (14, HL)],
        "face_r": [(0, "stand"), (3, "guard_out"), (10, "guard_out"), (13, "stand"), (14, "stand")],
        "face_l": [(0, "stand"), (3, "guard_out"), (10, "guard_out"), (13, "stand"), (14, "stand")],
        "pole_r": [(0, STAND["pole_r"]), (2, (-0.5, -1.0, 0.3)), (10, (-0.5, -1.0, 0.3)), (13, STAND["pole_r"]), (14, STAND["pole_r"])],
        "pole_l": [(0, STAND["pole_l"]), (2, (0.5, -1.0, 0.3)), (10, (0.5, -1.0, 0.3)), (13, STAND["pole_l"]), (14, STAND["pole_l"])],
        "grip_r": [(0, 0.4), (3, 0.1), (10, 0.1), (14, 0.4)], "grip_l": [(0, 0.4), (3, 0.1), (10, 0.1), (14, 0.4)],
        "foot_r": [(0, FR), (14, FR)], "foot_l": [(0, FL), (14, FL)],
        # (up onto the balls of the feet as the knees drive out over the toes, the balls planted; down again on the return)
        "heel_r": [(0, 0), (1, 4), (2, 16), (3, 26), (4, 30), (9, 30), (11, 10), (12, 0), (14, 0)],
        "heel_l": [(0, 0), (1, 4), (2, 16), (3, 26), (4, 30), (9, 30), (11, 10), (12, 0), (14, 0)],
        "knee_r": [(0, "auto"), (2, (-0.6, 0.2, 0.9)), (11, (-0.6, 0.2, 0.9)), (13, "auto")],
        "knee_l": [(0, "auto"), (2, (0.6, 0.2, 0.9)), (11, (0.6, 0.2, 0.9)), (13, "auto")],
    },
}
CLIPS.update(SET5B)


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
    """An airborne clip that turns the whole figure (keys flip or cart, or flip_turns; or barrel, the sixth set's log roll)."""
    return "flip" in clip or "cart" in clip or "flip_turns" in clip or "barrel" in clip


def flip_at(clip, f):
    """The somersault's angle at f (deg): flip_turns whole turns spread evenly over the clip (a loop's steady tumble, the last
    frame's turn the first's) plus the flip channel's keys on top (the turn quickening as the body tucks, slowing as it opens)."""
    base = 360.0 * clip.get("flip_turns", 0.0) * f / clip["length"]
    return base + (num(clip, "flip", f) if "flip" in clip else 0.0)


def pivot_at(clip, f):
    """The point the flip and the cart turn the figure about (the character's frame): the pivot channel's keys (a ground roll
    turns about its tucked ball's middle, low), else the hips' height over the stand's middle."""
    return Vector(num(clip, "pivot", f)) if "pivot" in clip else Vector((0.0, PIVOT_Y, 0.0))


## The body's surface round its joints (m, a sphere a joint; the head's about the middle of its two bones) for the ground
## contact of a roll (the ground channel) and the --points report: the lowest of them is where the body meets the deck.
SURF = {"heada": 0.11, "neck": 0.07, "spinea": 0.12, "spineb": 0.11, "spinec": 0.11, "spined": 0.11, "pelvis": 0.12,
        "l_shoulder": 0.07, "r_shoulder": 0.07, "l_elbow": 0.045, "r_elbow": 0.045, "l_wrist": 0.035, "r_wrist": 0.035,
        "l_palm": 0.025, "r_palm": 0.025, "l_upper_leg": 0.09, "r_upper_leg": 0.09, "l_knee": 0.055, "r_knee": 0.055,
        "l_ankle": 0.045, "r_ankle": 0.045, "l_heel": 0.0, "r_heel": 0.0, "l_ball": 0.02, "r_ball": 0.02}


def head_middle(P):
    """The skull's middle: past the head's base along its two bones (its sphere's centre)."""
    if "headb" in P:
        return P["heada"] + (P["headb"] - P["heada"]) * 0.5 + (P["headb"] - P["neck"]).normalized() * 0.03
    return P["heada"]


## The tricorne's corners and crown on the rig's headb at rest (m, the character's frame, read off the glb's Hat mesh: x
## +-0.16, y 1.535-1.627, z -0.095-0.205): --points prints the hat's lowest point, so a roll keeps the brim, not only the
## skull, clear of the deck (a report only; the ground contact stays the body's).
HAT_REST = [(0.0, 1.54, 0.2), (0.16, 1.54, -0.02), (-0.16, 1.54, -0.02), (0.0, 1.55, -0.095), (0.0, 1.627, 0.03)]


def hat_low(P, G):
    """The hat's lowest point (m) with the head as posed (P, G from SK.fk)."""
    if "headb" not in P:
        return 9.0
    q = G["headb"] @ G_REST["headb"].inverted()
    return min((P["headb"] + q @ (Vector(v) - P_REST["headb"])).y for v in HAT_REST)


def surface_low(P):
    """The lowest point of the body's surface (SURF): (its height, the joint)."""
    best = (1e9, "")
    for nm, r in SURF.items():
        if nm not in P:
            continue
        p = head_middle(P) if nm == "heada" else P[nm]
        if p.y - r < best[0]:
            best = (p.y - r, nm)
    return best


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
        # (barrel: the figure turned about its own long axis after the flip and the cart, a log roll along the deck; only
        # the sixth set's clips key it, so every other clip's Q is as before)
        if "barrel" in clip:
            Q = Q @ q_axis(Y, num(clip, "barrel", f))
        piv = pivot_at(clip, f)

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
    # the head's own side tilt (a lolling head; only the clips that key it, so the others' heads are as before)
    if "tilt" in clip:
        for nm, share in NECK:
            turn(rots, nm, q_axis(qhead @ Z, num(clip, "tilt", f) * share))
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
        # (toes "foot": the toes always with the foot; a figure lying on the deck (the sixth set) sets its sole flat on the
        # deck with a heel lift in its own frame, where the stand's "toes flat on the ground" would bend them up off it)
        if clip.get("toes") == "foot":
            gb = qh @ qy @ G_REST[s + "_ball"]
        set_global(rots, s + "_ball", gb)
    # the arms: each palm to its place, facing its way, the elbow toward its pole
    for s in "lr":
        gw = Q @ facing_at(clip, s, f)
        P, G = SK.fk(rots, root)
        if clip.get("hands_from") == "shoulder":
            # (a limp arm trailing from its shoulder: the hand keyed as the arm's reach from the shoulder in the turned chest's
            # frame, so the spine's sway carries the arm whole and the elbow keeps its bend instead of pumping)
            gw = qbody @ facing_at(clip, s, f)
            palm_t = P[s + "_shoulder"] + qbody @ num(clip, "hand_" + s, f)
        else:
            palm_t = xf(num(clip, "hand_" + s, f))
        wrist_t = palm_t - gw @ SK.rest_t[s + "_palm"]
        pole_v = (qbody if clip.get("hands_from") == "shoulder" else Q) @ num(clip, "pole_" + s, f)
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
    # the ground contact of a roll (only the clips that key it): the whole figure lifted or lowered by the ground channel's
    # share of the gap between the deck (the clip's floor, 0 but for the edge's deck top) and its lowest surface (SURF), so a
    # tucked ball rolls on the deck instead of sinking into it or floating; a uniform shift, so the joints' rotations (and the
    # IK) are unchanged
    if "ground" in clip:
        w = num(clip, "ground", f)
        if w > 0.0:
            P, _ = SK.fk(rots, root)
            root = root + Vector((0.0, (clip.get("floor", 0.0) - surface_low(P)[0]) * w, 0.0))
    # the code's carry taken back (only the clips that key it: the edge jump): the whole figure lowered by the lift_w share of
    # the code's own lift (lift: its vy and gravity, from the clip's start), so the hands stay on the deck through the push
    # while the code is already carrying the body up; a uniform shift, the rotations as keyed
    if "lift" in clip:
        vy, g = clip["lift"]
        t = f / FPS
        w = num(clip, "lift_w", f) if "lift_w" in clip else 1.0
        root = root - Vector((0.0, (vy * t - 0.5 * g * t * t) * w, 0.0))
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
    # (a side roll's travel, the way it rolls in the character's frame: right for the keys, left for the twin)
    if "travel" in out["meta"]:
        out["meta"]["travel"] = {"right": "left", "left": "right"}.get(out["meta"]["travel"], out["meta"]["travel"])

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
        if key in ("flip_turns", "bones", "hands_from", "floor", "lift", "substeps", "toes", "twin_start"):
            out[key] = keys
            continue
        if key in ("yaw", "twist", "roll", "side", "look", "spin", "cart", "tilt", "barrel"):
            out[key] = [(fr, -v) for fr, v in keys]
        elif key in ("root", "pivot"):
            out[key] = [(fr, mv(v)) for fr, v in keys]
        elif "_" in key and key.split("_")[0] in SIDED:
            base, s = key.rsplit("_", 1)
            other = base + "_" + ("l" if s == "r" else "r")
            out[other] = [(fr, mv(v)) for fr, v in keys]
        else:
            out[key] = list(keys)
    # (twin_start n: the twin's first n frames are the original's own, unmirrored, so a twin that starts from an
    # asymmetric pose (the getup roll from the lie) starts from that same pose and gathers into its mirrored keys)
    n = int(clip.get("twin_start", 0))
    if n:
        for key, keys in list(out.items()):
            if isinstance(keys, list) and isinstance(clip.get(key), list):
                out[key] = [k for k in clip[key] if k[0] < n] + [k for k in keys if k[0] >= n]
    return out


def all_clips():
    out = {}
    for name, clip in CLIPS.items():
        out[name] = clip
        if clip.get("mirror"):
            out[name + "_l"] = mirror_clip(clip)
    return out


## ---------------------------------------------------------------- the sixth set (round 3, P2: the four Rises, the scramble up
## the deck's face, breaking the fall (the slap, its roll and the wall's), lying and getting up (the lie, the getup, its roll
## and its attack) and the spiked and bounce knocks; authored the same way, key poses typed here, nothing read). The Rises and
## the airborne knocks start (and the knocks end) on AIR, the fall's first pose; the scramble ends exactly on the hang's first
## pose (HANG); the breaks and the getups end on the STAND; the bounce ends on the lie's first pose (LIE), which the getups
## start from. The figures lying on the deck (the lie, the bounce, the getups) are keyed in the DECK'S frame (_wclip below):
## the pelvis's place and the figure's turn (flip, cart, barrel) with the hands and the feet where they are on the deck,
## turned back into the figure's own keys at every frame, so a palm or a sole laid on the deck stays there while the body
## turns over it. Fire Northern Shaolin (the rocket's rising punch, the getup's carp skip-up), earth Hung Gar (the horse on
## the column, the fists driven down), water tai chi (the cloud hands' circles rising) and air Baguazhang (the spinning
## crane, the glide) are style labels for the typed key poses only.
PELV_REST = (round(P_REST["pelvis"].x, 4), round(P_REST["pelvis"].y, 4), round(P_REST["pelvis"].z, 4))
## The stand's pelvis (the place a getup ends on).
PELV_STAND = (PELV_REST[0], round(PELV_REST[1] + STAND["root"][1], 4), PELV_REST[2])
_X3, _Y3, _Z3 = Vector((1.0, 0.0, 0.0)), Vector((0.0, 1.0, 0.0)), Vector((0.0, 0.0, 1.0))
FACING.update({
    "wall": ((0.08, 1.0, 0.0), (0.0, 0.0, 1.0)),             # flat on a face ahead (the deck's or a wall), the fingers up
    "rocket": ((0.05, 0.75, 0.66), (0.98, 0.0, -0.1)),       # a fist punched up and ahead, the knuckles leading, the palm in
})


def _kv(keys, f, loop_len=None):
    """Typed keys [(frame, value)] at frame f by the clips' own monotone cubic (periodic across loop_len for a loop)."""
    xs = [k[0] for k in keys]
    v0 = keys[0][1]

    def one(ys):
        if loop_len is not None and len(keys) > 2 and xs[-1] == loop_len:
            return _periodic(xs, ys, f, loop_len)
        return _cubic(xs, ys, f)
    if isinstance(v0, (tuple, list)):
        return tuple(one([k[1][i] for k in keys]) for i in range(len(v0)))
    return one([float(k[1]) for k in keys])


def _turnq(flip, cart=0.0, barrel=0.0):
    """The figure's turn as pose() composes it (the flip, then the cart, then the barrel about its own long axis)."""
    return q_axis(_X3, flip) @ q_axis(_Z3, cart) @ q_axis(_Y3, barrel)


def _heel_key(side, ankle, heel, fyaw=0.0):
    """The foot's key (its flat place) that lands the ankle exactly at `ankle` with the heel lifted by `heel` degrees (about
    the ball; below 0 the toes up about the heel's back) and turned out by fyaw, as pose() lifts it (the figure's frame)."""
    sg = 1.0 if side == "l" else -1.0
    qy = q_axis(_Y3, sg * fyaw)
    qh = q_axis(qy @ _X3, heel)
    b = qy @ ((P_REST[side + "_ball"] if heel >= 0 else P_REST[side + "_heel"]) - P_REST[side + "_ankle"])
    return _r3(tuple(Vector(ankle) - b + qh @ b))


def _tag(v):
    """A place's frame: ('b', place) the figure's own, ('w', place) or a bare place the deck's."""
    if isinstance(v, tuple) and len(v) == 2 and v[0] in ("w", "b"):
        return v[0], v[1]
    return "w", v


def _wclip(length, keys, loop=False):
    """A clip keyed in the deck's frame: `pelvis` (the pelvis's place on or over the deck: the point the figure turns about,
    the root carried so the pelvis sits on it), flip / cart / barrel (the figure's turn), hand_r/l (the palms) and foot_r/l
    (the ankles, where they land with their heel lift and toe-out) as places on the deck (('b', place) a place in the
    figure's own frame, carried with it), face_r/l a facing name (the figure's own) or ('w', fingers, palm) on the deck,
    pole_r/l and knee_r/l in the figure's frame (('w', way) on the deck); a channel may be a function of the frame. Every
    other channel is the figure's own, passed through. Returns the clip's channels keyed at every frame."""
    def ev(ch, f, default=None):
        ks = keys.get(ch)
        if ks is None:
            return default
        if callable(ks):
            return ks(f)
        return _kv(ks, f, length if loop else None)

    def turn_at(f):
        return _turnq(ev("flip", f, 0.0), ev("cart", f, 0.0), ev("barrel", f, 0.0)), Vector(ev("pelvis", f, PELV_STAND))

    def tobody(w, f):
        R, piv = turn_at(f)
        return tuple(piv + R.inverted() @ (Vector(w) - piv))

    def toworld(b, f):
        R, piv = turn_at(f)
        return tuple(piv + R @ (Vector(b) - piv))

    def shift(f):
        # (the figure's own places are the stand's, carried with the pelvis: the root's offset puts the pelvis on its place)
        return Vector(ev("pelvis", f, PELV_STAND)) - Vector(PELV_REST)

    def place(ch, f):
        ks = keys[ch]
        if callable(ks):
            tg, p = _tag(ks(f))
            return tuple(Vector(p) + shift(f)) if tg == "b" else tobody(p, f)
        xs = [k[0] for k in ks]
        tags = [_tag(v)[0] for _, v in ks]
        W, B = [], []
        for fr, v in ks:
            tg, p = _tag(v)
            if tg == "w":
                W.append((fr, p))
                B.append((fr, tuple(Vector(tobody(p, fr)) - shift(fr))))
            else:
                W.append((fr, toworld(tuple(Vector(p) + shift(fr)), fr)))
                B.append((fr, p))
        i = max([j for j in range(len(xs)) if xs[j] <= f] or [0])
        nxt = tags[i + 1] if i + 1 < len(xs) else tags[i]
        if tags[i] == "w" and nxt == "w":
            return tobody(_kv(W, f, length if loop else None), f)
        return tuple(Vector(_kv(B, f, length if loop else None)) + shift(f))

    def way_q(v, side, fr):
        R, _ = turn_at(fr)
        if isinstance(v, str):
            fb, nb = FACING[v]
            if side == "l":
                fb, nb = mirror_v(fb), mirror_v(nb)
            fw, nw = R @ Vector(fb), R @ Vector(nb)
        else:
            fw, nw = Vector(v[1]), Vector(v[2])
        return basis(fw, nw).to_quaternion()

    def facing(ch, f):
        side = ch[-1]
        ks = keys[ch]
        if callable(ks):
            v = ks(f)
            pairs = [(f, v)]
        else:
            pairs = ks
        if f <= pairs[0][0]:
            q = way_q(pairs[0][1], side, pairs[0][0])
        elif f >= pairs[-1][0]:
            q = way_q(pairs[-1][1], side, pairs[-1][0])
        else:
            for (fa, va), (fb, vb) in zip(pairs, pairs[1:]):
                if fa <= f <= fb:
                    qa, qb = way_q(va, side, fa), way_q(vb, side, fb)
                    if qa.dot(qb) < 0:
                        qb = -qb
                    q = qa.slerp(qb, smooth((f - fa) / (fb - fa)))
                    break
        R, _ = turn_at(f)
        m = (R.inverted() @ q).to_matrix()
        return (_r3(tuple(m.col[0])), _r3(tuple(m.col[1])))

    def way(v, fr):
        if isinstance(v, tuple) and len(v) == 2 and v[0] == "w":
            R, _ = turn_at(fr)
            return _r3(tuple(R.inverted() @ Vector(v[1])))
        return v

    out = {}
    frames = range(length + 1)
    for ch in ("flip", "cart", "barrel"):
        if ch in keys:
            out[ch] = [(f, round(ev(ch, f), 3)) for f in frames]
    if "flip" not in out:
        out["flip"] = [(0, 0.0), (length, 0.0)]
    out["pivot"] = [(f, _r3(tuple(turn_at(f)[1]))) for f in frames]
    out["root"] = [(f, _r3(tuple(turn_at(f)[1] - Vector(PELV_REST)))) for f in frames]
    for s in "rl":
        if "hand_" + s in keys:
            out["hand_" + s] = [(f, _r3(place("hand_" + s, f))) for f in frames]
        if "foot_" + s in keys:
            out["foot_" + s] = [(f, _heel_key(s, place("foot_" + s, f), ev("heel_" + s, f, 0.0), ev("fyaw_" + s, f, 7.0)))
                                for f in frames]
        if "face_" + s in keys:
            out["face_" + s] = [(f, facing("face_" + s, f)) for f in frames]
        for ch in ("pole_" + s, "knee_" + s):
            if ch in keys:
                ks = keys[ch]
                out[ch] = [(f, way(ks(f), f)) for f in frames] if callable(ks) else [(fr, way(v, fr)) for fr, v in ks]
    for ch, ks in keys.items():
        if ch in out or ch in ("pelvis",) or ch.startswith(("hand_", "foot_", "face_", "pole_", "knee_")):
            continue
        out[ch] = [(f, _rv(ks(f))) for f in frames] if callable(ks) else ks
    return out


# ---------------------------------------------------------------- the lie
## The lie (own-bend-lie, a loop of 40 frames): dazed on his back on the deck, the head toward his back (-Z) and the pelvis
## LIE_PELVIS: the right knee drawn up with its sole flat on the deck, the left leg long and rolled out, the right arm flung
## out on the deck palm up, the left hand fallen on the belly, the head rolled toward the left; a slow breath lifts the chest
## and the hand on the belly, the raised knee sags out and back a beat behind it, the fingers stir, the head rolls a little.
LIE_PELVIS = (0.0, 0.12, -0.3)
LIE_LEN = 40


def lie_at(f):
    a = 2 * math.pi * f / LIE_LEN
    return {
        "flip": -90.0, "pelvis": _add(LIE_PELVIS, (0.0, 0.004 * _s(a), 0.0)),
        "hips": 0.0, "chest": 2.5 + 2.5 * _s(a), "head": -8.0 + 1.5 * _s(2 * a, -1.0), "look": 24.0 + 8.0 * _s(a, -1.6),
        "side": 1.0 * _s(a, -0.6), "twist": 0.0,
        "clav_r": (0.0, 0.0), "clav_l": (2.0, 2.0 + 1.5 * _s(a, -0.4)),
        "hand_r": (-0.63, 0.035, -0.6), "hand_l": (0.06, 0.25 + 0.012 * _s(a, -0.5), -0.36),
        "face_r": ("w", (-0.85, 0.0, -0.5), (0.0, 1.0, 0.0)), "face_l": ("w", (-0.9, -0.1, 0.35), (0.0, -1.0, 0.1)),
        "pole_r": (-1.0, 0.0, 0.5), "pole_l": (1.0, 0.0, -0.3),
        "grip_r": 0.25 + 0.1 * _s(a, 2.0), "grip_l": 0.3 + 0.05 * _s(a, 0.5),
        "foot_r": (-0.17, 0.078, 0.03), "foot_l": (0.2, 0.065, 0.4),
        "heel_r": 90.0, "heel_l": 25.0, "fyaw_r": 8.0, "fyaw_l": 28.0,
        "knee_r": (-0.3 - 0.3 * _s(a, -1.2), -0.3, 1.0), "knee_l": (0.45, 0.0, 1.0),
    }


LIE = lie_at(0)


def _lie_keys(ch, *frames):
    """The lie's first value of a channel as keys at the frames given (a getup's start, the bounce's end)."""
    v = LIE[ch]
    return [(fr, v) for fr in frames]


# ---------------------------------------------------------------- the glide (the air Rise's loop)
## The air Rise's glide (frames 14-44 of own-bend-rise-air, a loop: meta loop_from_s): the spent body laid forward into the
## wind (the flip), the arms spread wide as wings (the palms down, the fingers spread), the legs trailing long and together,
## the toes pointed; it banks slowly from side to side (cart), the low wing dipping a few frames behind the bank, the head
## looking into the turn after it, the legs scissoring a little.
GLIDE_LEN = 30


def glide_at(a):
    lag = 2 * math.pi * 3 / GLIDE_LEN
    return {
        "flip": 34.0 + 2.0 * _s(a, -0.5), "cart": 10.0 * _s(a),
        "hips": 2.0, "chest": -14.0 + 1.5 * _s(2 * a, -0.6), "head": -30.0 + 2.0 * _s(a, -1.4),
        "look": -7.0 * _s(a, -lag * 1.5), "twist": 3.0 * _s(a, -lag),
        "clav_r": (-8.0, -6.0 + 3.0 * _s(a, -lag)), "clav_l": (-8.0, -6.0 - 3.0 * _s(a, -lag)),
        "hand_r": (-0.57, 1.26 - 0.07 * _s(a, -lag), -0.15 + 0.025 * _c(a, -lag)),
        "hand_l": (0.57, 1.26 + 0.07 * _s(a, -lag) + 0.015 * _s(2 * a, 0.4), -0.15 - 0.025 * _c(a, -lag)),
        "face_r": "arms_out", "face_l": "arms_out",
        "pole_r": (-0.25, -1.0, -0.45), "pole_l": (0.25, -1.0, -0.45),
        "grip_r": -0.35, "grip_l": -0.35,
        "foot_r": _heel_key("r", (-0.075, 0.13 + 0.02 * _s(a, -1.0), -0.06 + 0.04 * _c(a, -1.0)), 55.0, 4.0),
        "foot_l": _heel_key("l", (0.075, 0.13 - 0.02 * _s(a, -1.0), -0.06 - 0.04 * _c(a, -1.0)), 55.0, 4.0),
        "heel_r": 55.0, "heel_l": 55.0, "fyaw_r": 4.0, "fyaw_l": 4.0,
        "knee_r": (-0.1, 0.0, 1.0), "knee_l": (0.1, 0.0, 1.0),
    }


GLIDE = {k: (_rv(v) if not isinstance(v, str) else v) for k, v in glide_at(0.0).items()}


def _rise_air():
    """own-bend-rise-air: the typed spin up (f0-f13) and the glide loop (f14-f44) joined (the glide keyed at every frame)."""
    c = {
        "length": 44, "base": AIR,
        "meta": {"hold_s": 2 / FPS, "strike_s": 3 / FPS, "back_s": 14 / FPS, "loop_from_s": 14 / FPS, "hand": "both",
                 "mask": "full", "root": "place"},
        # (the whirl: wound up the other way, then one whole turn, fastest in its middle, settling a touch past)
        "spin": [(0, 0), (2, -25), (4, 40), (6, 150), (8, 262), (10, 334), (12, 362), (14, 360), (44, 360)],
        "root": [(0, AIR["root"]), (2, (0.0, -0.03, 0.0)), (4, (0.0, 0.05, 0.0)), (8, (0.0, 0.08, 0.0)), (12, (0.0, 0.04, 0.0)),
                 (14, (0.0, 0.0, 0.0)), (44, (0.0, 0.0, 0.0))],
        "yaw": [(0, 0), (44, 0)], "roll": [(0, 0), (44, 0)], "side": [(0, 0), (3, 4), (8, 6), (12, 0), (44, 0)],
    }
    typed = {
        "flip": [(0, 0.0), (11, 0.0)],
        "cart": [(0, 0.0), (11, 0.0)],
        "hips": [(0, AIR["hips"]), (2, 14), (4, 2), (8, -2), (11, 2)],
        "chest": [(0, AIR["chest"]), (2, 12), (4, 0), (8, -6), (11, -6)],
        "head": [(0, AIR["head"]), (2, 10), (4, -8), (8, -16), (11, -16)],
        "look": [(0, 0), (2, -14), (4, 18), (8, 22), (11, 6)],
        "twist": [(0, 0), (2, -14), (4, 16), (8, 18), (11, 4)],
        "clav_r": [(0, AIR["clav_r"]), (2, (10, 6)), (4, (-4, -26)), (9, (-4, -28)), (11, (-6, -12))],
        "clav_l": [(0, AIR["clav_l"]), (2, (10, 6)), (4, (8, 6)), (9, (8, 6)), (11, (-6, -8))],
        # (the corkscrew: the right hand driven up overhead, the left low across the belly, the left knee raised: a crane
        # spinning on the wind; then both arms unfurled out wide into the wings)
        "hand_r": [(0, AR), (2, (0.08, 1.12, 0.26)), (4, (-0.1, 1.62, 0.16)), (6, (-0.07, 1.76, 0.06)), (9, (-0.07, 1.76, 0.06)),
                   (11, (-0.42, 1.52, -0.02))],
        "hand_l": [(0, AL), (2, (-0.06, 1.17, 0.24)), (4, (0.08, 1.02, 0.2)), (9, (0.08, 1.0, 0.19)), (11, (0.44, 1.2, 0.02))],
        "face_r": [(0, "balance"), (2, "cross"), (5, "sky"), (9, "sky"), (12, "arms_out")],
        "face_l": [(0, "balance"), (2, "cross"), (4, "cross"), (9, "cross"), (12, "arms_out")],
        "pole_r": [(0, AIR["pole_r"]), (2, (-0.8, -0.5, 0.2)), (5, (-1.0, 0.2, 0.0)), (9, (-1.0, 0.2, 0.0)), (11, (-0.4, -1.0, -0.4))],
        "pole_l": [(0, AIR["pole_l"]), (2, (0.8, -0.5, 0.2)), (5, (1.0, -0.6, 0.3)), (9, (1.0, -0.6, 0.3)), (11, (0.4, -1.0, -0.4))],
        "grip_r": [(0, AIR["grip_r"]), (2, 0.7), (5, -0.2), (9, -0.2), (11, -0.3)],
        "grip_l": [(0, AIR["grip_l"]), (2, 0.7), (9, 0.6), (11, -0.3)],
        "foot_r": [(0, AFR), (2, (-0.12, 0.38, 0.14)), (4, (-0.07, 0.14, 0.02)), (9, (-0.07, 0.13, 0.0)), (11, (-0.075, 0.13, -0.06))],
        "foot_l": [(0, AFL), (2, (0.12, 0.42, 0.1)), (4, (0.1, 0.5, 0.16)), (9, (0.1, 0.5, 0.16)), (11, (0.08, 0.22, -0.04))],
        "heel_r": [(0, AIR["heel_r"]), (2, 30), (4, 55), (11, 55)], "heel_l": [(0, AIR["heel_l"]), (2, 30), (4, 45), (11, 50)],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 4), (11, 4)], "fyaw_l": [(0, AIR["fyaw_l"]), (4, 10), (11, 4)],
        "knee_r": [(0, AIR["knee_r"]), (4, (-0.1, 0.0, 1.0)), (11, (-0.1, 0.0, 1.0))],
        "knee_l": [(0, AIR["knee_l"]), (4, (0.2, 0.2, 1.0)), (9, (0.2, 0.2, 1.0)), (11, (0.1, 0.0, 1.0))],
    }
    for ch, ks in typed.items():
        c[ch] = list(ks) + [(14 + i, GLIDE[ch] if isinstance(GLIDE[ch], str) else _rv(glide_at(2 * math.pi * i / GLIDE_LEN)[ch]))
                            for i in range(GLIDE_LEN + 1)]
    for s in "rl":
        c["face_" + s] = typed["face_" + s] + [(44, GLIDE["face_" + s])]
    return c


# ---------------------------------------------------------------- the water Rise's circles and the golden rooster
## Each arm swung round a big circle about its own shoulder in the frontal plane (tai chi's circling arms, the elbow soft):
## the right from the bottom out to his right, over the top, across before the face and round again, one and a half turns
## to end high over the head; the left a beat later, one whole turn, back down to press by the hip: the golden rooster
## standing on one leg (the left knee drawn high) on top of the water column. Swept in front of the body (the inward half
## of each circle bulges forward, clear of the chest and the face).
WATER_SWIRL = (4, 16)
WATER_R = 0.33
WATER_C = (0.16, 1.33, 0.12)


def _ease(t):
    t = max(0.0, min(1.0, t))
    return t - math.sin(2 * math.pi * t) / (2 * math.pi)


def water_swirl(f):
    t = (f - WATER_SWIRL[0]) / (WATER_SWIRL[1] - WATER_SWIRL[0])
    out = {}
    for side, s, turns, sg in (("r", _ease(t), 1.5, -1.0), ("l", _ease((t - 0.15) / 0.85), 1.0, 1.0)):
        ph = -math.pi / 2 + 2 * math.pi * turns * s
        cx, cy, cz = WATER_C
        out["hand_" + side] = (sg * (cx + WATER_R * math.cos(ph)), cy + WATER_R * math.sin(ph),
                               cz + 0.11 * max(0.0, -math.cos(ph)) + 0.1 * max(0.0, -math.sin(ph)))
        out["ph_" + side] = ph
    out["twist"] = 12.0 * math.cos(out["ph_r"])
    out["look"] = 10.0 * math.cos(out["ph_r"] - 0.5)
    out["roll"] = 4.0 * math.sin(out["ph_r"])
    return out


## The golden rooster's hands: the right high over the head (the palm up), the left pressed down beside the hip.
ROOSTER_R = (-0.13, 1.71, 0.16)
ROOSTER_L = (0.22, 0.97, 0.2)


def _rise_water():
    c = {
        "length": 28, "base": AIR,
        "meta": {"hold_s": 2 / FPS, "strike_s": 4 / FPS, "back_s": 21 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, AIR["root"]), (2, (0.0, -0.05, 0.0)), (4, (0.0, -0.03, 0.0)), (10, (0.0, 0.03, 0.0)), (16, (0.0, 0.05, 0.0)),
                 (21, (0.0, 0.055, 0.0)), (24, (0.0, 0.035, 0.0)), (28, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 12), (4, 6), (10, 2), (16, -2), (21, -3), (24, 0), (28, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 10), (4, 4), (10, -2), (16, -5), (21, -6), (24, -2), (28, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, 14), (4, 6), (10, -4), (16, -10), (21, -10), (24, -4), (28, AIR["head"])],
        "side": [(0, 0), (4, 0), (16, -3), (21, -4), (28, 0)],
        "clav_r": [(0, AIR["clav_r"]), (2, (6, 4)), (4, (2, 0)), (12, (0, -10)), (16, (-2, -22)), (21, (-2, -22)), (24, (-2, -14)),
                   (28, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (6, 4)), (4, (2, 0)), (12, (0, -10)), (16, (2, 4)), (21, (2, 4)), (24, (-2, -10)),
                   (28, AIR["clav_l"])],
        "face_r": [(0, "balance"), (2, "press_down"), (4, "press_down"), (7, "push"), (13, "push"), (16, "sky"), (21, "sky"),
                   (28, "balance")],
        "face_l": [(0, "balance"), (2, "press_down"), (5, "press_down"), (8, "push"), (12, "push"), (16, "press_down"),
                   (21, "press_down"), (28, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (4, (-1.0, -0.6, -0.2)), (16, (-1.0, -0.2, -0.2)), (21, (-1.0, -0.2, -0.2)), (28, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (4, (1.0, -0.6, -0.2)), (16, (1.0, -0.2, -0.4)), (21, (1.0, -0.2, -0.4)), (28, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, 0.1), (10, -0.15), (16, -0.3), (21, -0.3), (28, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, 0.1), (10, -0.15), (16, -0.2), (21, -0.2), (28, AIR["grip_l"])],
        # (the legs reach down onto the column; the right stands tall on it, rising onto the ball, the left knee drawn up high
        # in front, the toes hanging: the golden rooster)
        "foot_r": [(0, AFR), (2, (-0.12, 0.34, 0.14)), (4, (-0.09, 0.1, 0.04)), (21, (-0.08, 0.1, 0.02)), (24, (-0.13, 0.22, 0.12)),
                   (28, AFR)],
        "foot_l": [(0, AFL), (2, (0.12, 0.36, 0.02)), (4, (0.1, 0.12, -0.04)), (8, (0.1, 0.3, 0.1)), (12, (0.1, 0.5, 0.16)),
                   (21, (0.1, 0.52, 0.16)), (24, (0.13, 0.4, 0.0)), (28, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (2, 24), (4, 14), (10, 24), (16, 30), (21, 32), (28, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (2, 24), (4, 14), (8, 30), (12, 44), (21, 44), (28, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 10), (21, 10), (28, AIR["fyaw_r"])], "fyaw_l": [(0, AIR["fyaw_l"]), (4, 6), (21, 6), (28, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (4, (-0.15, 0.0, 1.0)), (21, (-0.15, 0.0, 1.0)), (28, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (4, (0.2, 0.0, 1.0)), (12, (0.1, 0.4, 1.0)), (21, (0.1, 0.4, 1.0)), (28, AIR["knee_l"])],
    }
    a0, a1 = WATER_SWIRL
    for s, press, top, mid in (("r", (-0.2, 0.9, 0.2), ROOSTER_R, (-0.42, 1.5, 0.12)), ("l", (0.2, 0.92, 0.19), ROOSTER_L, (0.44, 1.28, 0.1))):
        c["hand_" + s] = ([(0, AR if s == "r" else AL), (2, press)] +
                          [(f, _r3(water_swirl(f)["hand_" + s])) for f in range(a0, a1)] +
                          [(a1 + 1, top), (21, _add(top, (0.0, 0.01, 0.0))), (24, mid), (28, AR if s == "r" else AL)])
    for ch in ("twist", "look", "roll"):
        c[ch] = [(0, 0.0), (2, 0.0)] + [(f, round(water_swirl(f)[ch], 2)) for f in range(a0, a1)] + [(18, 0.0), (21, 0.0), (28, 0.0)]
    return c


# ---------------------------------------------------------------- the edge scramble
## The scramble's feet on the deck's face (the ankle's place, the balls on the stone).
SCR_FACE_Z = 0.19


def _tech_slap():
    """The breakfall's three-point slap on the deck (the tech's moment of contact, and the tech roll's first frame): the right
    knee down, the left foot planted ahead, the right palm slapped flat on the deck out to the side, the left arm flung up and
    back for the balance, the trunk bowed low over the left thigh and leant to the right, the eyes up."""
    return {
        "root": (0.0, -0.55, 0.03), "hips": 64.0, "chest": 24.0, "side": -28.0, "twist": -8.0, "head": -52.0, "look": 0.0,
        "roll": 0.0, "yaw": 0.0,
        "clav_r": (14.0, 18.0), "clav_l": (-10.0, -24.0),
        "hand_r": (-0.24, 0.03, 0.44), "hand_l": (0.4, 0.79, 0.17),
        "face_r": "deck_out", "face_l": "flung_up",
        "pole_r": (-1.0, 0.3, -0.2), "pole_l": (0.6, -0.6, -0.5),
        "grip_r": -0.4, "grip_l": -0.3,
        # (sat low on the right heel, its knee on the deck ahead of it, the toes tucked under; the left foot planted ahead)
        "foot_r": _heel_key("r", (-0.14, 0.1, -0.27), 80.0, 4.0), "heel_r": 80.0, "fyaw_r": 4.0,
        "foot_l": _heel_key("l", (0.18, 0.077, 0.34), 0.0, 14.0), "heel_l": 0.0, "fyaw_l": 14.0,
        "knee_r": (-0.15, -0.3, 1.0), "knee_l": (0.35, 0.3, 1.0),
    }


SLAP = _tech_slap()


def _tech_roll():
    """own-bend-tech-roll: the side roll (_roll("side")) entered from the breakfall's slap instead of the stand: its first
    three frames (the stand and the weight shift) replaced by the slap at f0, the ball reached at f3 as before."""
    c = _roll("side")
    for ch, ks in list(c.items()):
        if not isinstance(ks, list) or ch in ("pivot", "ground", "cart"):
            continue
        rest = [(fr, v) for fr, v in ks if fr >= 3]
        if ch in SLAP and rest:
            c[ch] = [(0, SLAP[ch])] + rest
    for ch in ("hips", "chest", "side", "twist", "head", "roll", "yaw"):
        if ch not in c:
            c[ch] = [(0, SLAP[ch]), (3, 0.0), (18, 0.0)]
    # (the right hand off the deck from the slap, round in over the shoulder to take the deck again as he tips over)
    c["hand_r"] = [k for k in c["hand_r"] if k[0] != 3]
    c["hand_r"] += [(2, (-0.42, 0.26, 0.27)), (3, _unturn((-0.36, 0.13, 0.19), 30, ROLL_PIVOT, "z"))]
    c["hand_r"].sort(key=lambda k: k[0])
    c["meta"] = dict(c["meta"], hold_s=1 / FPS, strike_s=7 / FPS, back_s=13 / FPS)
    return c


SET6 = {
    # the earth Rise (Pillar): from the fall the legs reach down wide for the column rising out of the water; it takes him
    # (f5) and he slams into a deep Hung Gar horse on its top, both fists driven down before him at the stone (the 0.2 s
    # tell held), the whole figure leaning 20 degrees forward with the column toward the lip; carried up, sinking further
    # into the horse as it drives (the load, the fists drawn up to the hips at the last), then thrown off its top: the legs
    # drive straight up onto the toes, the arms flung up overhead in a wide V, the chest arched; the feet leave it and he
    # opens into the fall.  hold_s: in the horse; strike_s: thrown off the top; back_s: free of the column
    "rise_earth": {
        "length": 32, "base": AIR,
        "meta": {"hold_s": 6 / FPS, "strike_s": 20 / FPS, "back_s": 24 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "pivot": [(0, (0.0, 0.08, 0.02)), (32, (0.0, 0.08, 0.02))],
        "flip": [(0, 0), (4, 0), (6, 9), (9, 20), (19, 20), (21, 14), (24, 4), (28, 0), (32, 0)],
        "root": [(0, AIR["root"]), (3, (0.0, 0.03, 0.0)), (5, (0.0, -0.06, 0.0)), (6, (0.0, -0.26, 0.0)), (8, (0.0, -0.41, 0.0)),
                 (10, (0.0, -0.37, 0.0)), (16, (0.0, -0.39, 0.0)), (18, (0.0, -0.44, 0.0)), (19, (0.0, -0.45, 0.0)),
                 (20, (0.0, -0.14, 0.0)), (21, (0.0, -0.04, 0.0)), (23, (0.0, 0.06, 0.0)), (27, (0.0, 0.03, 0.0)), (32, AIR["root"])],
        "hips": [(0, AIR["hips"]), (3, 4), (5, 10), (6, 22), (8, 30), (10, 27), (16, 28), (19, 34), (20, 12), (21, -6), (23, -10),
                 (27, 0), (32, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (3, 2), (6, 8), (8, 14), (10, 11), (16, 12), (19, 16), (20, 2), (21, -12), (23, -15), (27, -2),
                  (32, AIR["chest"])],
        "head": [(0, AIR["head"]), (3, 16), (5, 6), (7, -26), (10, -36), (19, -40), (20, -30), (22, -26), (26, -6), (32, AIR["head"])],
        "twist": [(0, 0), (8, -3), (19, -6), (21, 5), (26, 0), (32, 0)],
        "clav_r": [(0, AIR["clav_r"]), (6, (6, 12)), (8, (8, 16)), (17, (8, 16)), (19, (-6, 4)), (21, (-8, -26)), (23, (-8, -28)),
                   (27, (-4, -16)), (32, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (6, (6, 12)), (8, (8, 16)), (17, (8, 16)), (19, (-6, 4)), (21, (-8, -26)), (23, (-8, -28)),
                   (27, (-4, -16)), (32, AIR["clav_l"])],
        "hand_r": [(0, AR), (3, (-0.4, 1.05, 0.2)), (5, (-0.3, 0.95, 0.32)), (6, (-0.16, 0.6, 0.42)), (8, (-0.13, 0.4, 0.42)),
                   (10, (-0.13, 0.41, 0.41)), (17, (-0.13, 0.41, 0.4)), (19, (-0.25, 0.74, 0.02)), (20, (-0.3, 1.25, 0.22)),
                   (21, (-0.33, 1.6, 0.12)), (23, (-0.37, 1.7, 0.05)), (27, (-0.55, 1.45, 0.06)), (32, AR)],
        "hand_l": [(0, AL), (3, (0.4, 1.05, 0.2)), (5, (0.3, 0.95, 0.32)), (6, (0.16, 0.6, 0.42)), (8, (0.13, 0.4, 0.42)),
                   (10, (0.13, 0.41, 0.41)), (17, (0.13, 0.41, 0.4)), (19, (0.25, 0.74, 0.02)), (20, (0.3, 1.25, 0.22)),
                   (21, (0.33, 1.6, 0.12)), (23, (0.37, 1.7, 0.05)), (27, (0.55, 1.45, 0.06)), (32, AL)],
        "face_r": [(0, "balance"), (3, "fist_gather"), (6, "fist_down"), (17, "fist_down"), (19, "chamber"), (21, "sky"), (25, "sky"),
                   (30, "balance"), (32, "balance")],
        "face_l": [(0, "balance"), (3, "fist_gather"), (6, "fist_down"), (17, "fist_down"), (19, "chamber"), (21, "sky"), (25, "sky"),
                   (30, "balance"), (32, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (6, (-1.0, 0.2, -0.3)), (17, (-1.0, 0.2, -0.3)), (19, (-0.5, -0.4, -1.0)), (21, (-1.0, 0.0, 0.0)),
                   (32, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (6, (1.0, 0.2, -0.3)), (17, (1.0, 0.2, -0.3)), (19, (0.5, -0.4, -1.0)), (21, (1.0, 0.0, 0.0)),
                   (32, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (4, 0.8), (6, 1.0), (19, 1.0), (20, 0.2), (21, -0.4), (25, -0.3), (32, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (4, 0.8), (6, 1.0), (19, 1.0), (20, 0.2), (21, -0.4), (25, -0.3), (32, AIR["grip_l"])],
        "foot_r": [(0, AFR), (3, (-0.24, 0.17, 0.08)), (5, (-0.31, 0.077, 0.0)), (21, (-0.31, 0.077, 0.0)), (23, (-0.22, 0.2, 0.0)),
                   (26, (-0.16, 0.3, 0.1)), (32, AFR)],
        "foot_l": [(0, AFL), (3, (0.24, 0.18, 0.0)), (5, (0.31, 0.077, 0.02)), (21, (0.31, 0.077, 0.02)), (23, (0.22, 0.22, -0.04)),
                   (26, (0.16, 0.32, -0.12)), (32, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (3, 22), (5, 0), (19, 0), (20, 24), (21, 46), (23, 52), (32, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (3, 22), (5, 0), (19, 0), (20, 24), (21, 46), (23, 52), (32, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 26), (21, 26), (26, 10), (32, AIR["fyaw_r"])],
        "fyaw_l": [(0, AIR["fyaw_l"]), (4, 26), (21, 26), (26, 10), (32, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (4, (-0.75, 0.1, 0.7)), (19, (-0.75, 0.1, 0.7)), (21, (-0.3, 0.0, 1.0)), (32, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (4, (0.75, 0.1, 0.7)), (19, (0.75, 0.1, 0.7)), (21, (0.3, 0.0, 1.0)), (32, AIR["knee_l"])],
    },
    # the water Rise (Fountain): a soft sink (the palms pressed down before the belly, the knees drawn: the 0.12 s tell), the
    # legs reach down and stand tall on the water column as it lifts him; the arms swirl up round two rising circles in the
    # frontal plane (tai chi's cloud hands: the right from the bottom out to his right and over, the left a beat later), the
    # chest and the head turning after the leading hand and opening up, until both hands float over the head in a soft
    # circle at the top; they open out into the fall.  hold_s: the sink; strike_s: the column takes him; back_s: the top
    "rise_water": _rise_water(),
    # the fire Rise (Jet): the hover tell (8 f): the knees drawn up high under him, both fists chambered at the hips with
    # the elbows back, the chest swelling and the head thrown back on the roar, a small bob; then the burst (10 f): snapped
    # long and straight along it in two frames, leant 25 degrees into the flight, the legs straight and together with the
    # toes pointed (the jet's nozzle), the right fist punched up and ahead leading the body (Northern Shaolin's rising
    # punch), the left fist kept at the hip, the eyes along the burst; then opened into the fall.  hold_s: the hover;
    # strike_s: the burst; back_s: the burst spent
    "rise_fire": {
        "length": 24, "base": AIR,
        "meta": {"hold_s": 4 / FPS, "strike_s": 8 / FPS, "back_s": 18 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "flip": [(0, 0), (7, 0), (8, 16), (9, 25), (18, 25), (21, 8), (24, 0)],
        "root": [(0, AIR["root"]), (3, (0.0, 0.05, 0.0)), (5, (0.0, 0.075, 0.0)), (7, (0.0, 0.05, 0.0)), (8, (0.0, 0.07, 0.0)),
                 (10, (0.0, 0.09, 0.0)), (18, (0.0, 0.09, 0.0)), (21, (0.0, 0.04, 0.0)), (24, AIR["root"])],
        "hips": [(0, AIR["hips"]), (3, 14), (7, 16), (8, 2), (10, -3), (18, -2), (21, 4), (24, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (3, 2), (5, -6), (7, 4), (8, -4), (10, -7), (18, -8), (21, 0), (24, AIR["chest"])],
        "head": [(0, AIR["head"]), (3, 0), (5, -12), (7, -2), (8, -12), (10, -22), (18, -22), (21, -6), (24, AIR["head"])],
        "twist": [(0, 0), (3, 0), (7, -6), (8, 8), (10, 12), (18, 10), (22, 0), (24, 0)],
        "clav_r": [(0, AIR["clav_r"]), (3, (-10, 4)), (5, (-12, 2)), (7, (-12, 4)), (8, (6, -24)), (10, (10, -30)), (18, (10, -30)),
                   (21, (0, -16)), (24, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (3, (-10, 4)), (5, (-12, 2)), (7, (-12, 4)), (10, (-10, 4)), (18, (-10, 4)), (21, (-4, -8)),
                   (24, AIR["clav_l"])],
        "hand_r": [(0, AR), (3, (-0.2, 0.96, -0.02)), (7, (-0.2, 0.94, -0.05)), (8, (-0.12, 1.56, 0.26)), (9, (-0.07, 1.89, 0.13)),
                   (18, (-0.07, 1.89, 0.12)), (21, (-0.45, 1.45, 0.12)), (24, AR)],
        "hand_l": [(0, AL), (3, (0.2, 0.96, -0.02)), (7, (0.2, 0.94, -0.05)), (10, (0.2, 0.94, -0.03)), (18, (0.2, 0.94, -0.03)),
                   (21, (0.42, 1.15, 0.0)), (24, AL)],
        "face_r": [(0, "balance"), (3, "chamber"), (7, "chamber"), (9, "rocket"), (18, "rocket"), (22, "balance"), (24, "balance")],
        "face_l": [(0, "balance"), (3, "chamber"), (18, "chamber"), (22, "balance"), (24, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-0.4, -0.3, -1.0)), (7, (-0.4, -0.3, -1.0)), (9, (-1.0, 0.0, -0.2)), (18, (-1.0, 0.0, -0.2)),
                   (24, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (3, (0.4, -0.3, -1.0)), (18, (0.4, -0.3, -1.0)), (24, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (3, 1.0), (18, 1.0), (21, 0.2), (24, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (3, 1.0), (18, 1.0), (21, 0.2), (24, AIR["grip_l"])],
        "foot_r": [(0, AFR), (3, (-0.13, 0.5, 0.2)), (5, (-0.13, 0.53, 0.2)), (7, (-0.13, 0.55, 0.21)),
                   (8, _heel_key("r", (-0.09, 0.24, 0.02), 62.0, 2.0)), (9, _heel_key("r", (-0.08, 0.172, -0.02), 66.0, 2.0)),
                   (18, _heel_key("r", (-0.08, 0.172, -0.02), 66.0, 2.0)), (21, (-0.13, 0.3, 0.12)), (24, AFR)],
        "foot_l": [(0, AFL), (3, (0.13, 0.46, 0.12)), (5, (0.13, 0.5, 0.12)), (7, (0.13, 0.51, 0.13)),
                   (8, _heel_key("l", (0.09, 0.24, 0.0), 62.0, 2.0)), (9, _heel_key("l", (0.08, 0.165, -0.03), 66.0, 2.0)),
                   (18, _heel_key("l", (0.08, 0.165, -0.03), 66.0, 2.0)), (21, (0.13, 0.33, -0.1)), (24, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (3, 30), (7, 30), (8, 62), (9, 66), (18, 66), (24, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (3, 30), (7, 30), (8, 62), (9, 66), (18, 66), (24, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (8, 2), (18, 2), (24, AIR["fyaw_r"])], "fyaw_l": [(0, AIR["fyaw_l"]), (8, 2), (18, 2), (24, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (3, (-0.25, 0.3, 1.0)), (7, (-0.25, 0.3, 1.0)), (9, (-0.05, 0.0, 1.0)), (18, (-0.05, 0.0, 1.0)),
                   (24, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (3, (0.25, 0.3, 1.0)), (7, (0.25, 0.3, 1.0)), (9, (0.05, 0.0, 1.0)), (18, (0.05, 0.0, 1.0)),
                   (24, AIR["knee_l"])],
    },
    # the air Rise (Updraft): wound up the other way (the arms crossed before the chest, the knees drawn), then whirled up
    # through one whole turn as a crane on the wind (the right hand driven up overhead, the left low across the belly, the
    # left knee raised, the head leading the turn), unfurled into the glide (from f14 a loop to the end: meta loop_from_s):
    # laid forward into the wind with the arms spread as wings, banking slowly from side to side.  hold_s: the wind-up;
    # strike_s: the whirl starts; back_s: the glide
    "rise_air": _rise_air(),
    # the scramble (18 f): a Rise that meets the deck's face below the lip: rising close along the face with both arms up,
    # the right palm slapped flat on the stone, the right foot kicked onto the face (scrabbling, slipping down and
    # re-planted higher), the left palm slapped higher, the left foot planted; the right hand thrown over the lip onto the
    # deck, then the left, and the body hauled up the face on them past the hang and settled into the hang's first pose
    # exactly (the code's slide up the face to the hang takes 0.3 s; the clip carries the last 0.45 m of the haul itself).
    # hold_s: the first slap; strike_s: the right hand over onto the deck; back_s: hauled up, settling
    "edge_scramble": {
        "length": 18, "base": HANG,
        "meta": dict(EDGE_META, hold_s=2 / FPS, strike_s=7 / FPS, back_s=12 / FPS, haul_m=0.45),
        "root": [(0, (0.0, 0.43, -0.06)), (2, (0.0, 0.5, -0.03)), (4, (0.0, 0.6, -0.01)), (6, (0.0, 0.72, 0.0)), (8, (0.0, 0.84, -0.01)),
                 (10, (0.0, 0.95, -0.02)), (12, (0.0, 0.94, -0.02)), (14, (0.0, 0.905, -0.015)), (18, HANG["root"])],
        "hips": [(0, 2), (2, 6), (4, 12), (7, 20), (10, 28), (12, 27), (18, HANG["hips"])],
        "chest": [(0, -6), (2, 0), (4, 6), (7, 12), (10, 11), (13, 8), (18, HANG["chest"])],
        "head": [(0, -34), (2, -30), (5, -24), (8, -26), (10, -14), (12, -20), (18, HANG["head"])],
        "roll": [(0, 0.0), (2, -6), (4, 5), (6, -4), (8, 4), (11, 0), (18, HANG["roll"])],
        "twist": [(0, 0.0), (2, -6), (4, 6), (7, -4), (9, 3), (12, 0), (18, HANG["twist"])],
        "side": [(0, 0.0), (2, 3), (4, -3), (8, 2), (12, 0), (18, HANG["side"])],
        "look": [(0, 0.0), (2, -8), (4, 8), (8, -4), (12, 0), (18, HANG["look"])],
        "clav_r": [(0, (0, -28)), (2, (4, -16)), (4, (6, -6)), (6, (2, -26)), (8, (8, -20)), (11, (8, -14)), (14, (6, -20)),
                   (18, HANG["clav_r"])],
        "clav_l": [(0, (0, -30)), (2, (0, -28)), (3, (4, -18)), (5, (6, -8)), (8, (2, -26)), (10, (8, -20)), (13, (6, -16)),
                   (18, HANG["clav_l"])],
        "hand_r": [(0, (-0.3, 2.0, 0.18)), (1, (-0.26, 1.86, 0.29)), (2, (-0.24, 1.78, 0.32)), (5, (-0.24, 1.78, 0.32)),
                   (6, (-0.24, 2.1, 0.44)), (7, GR), (18, GR)],
        "hand_l": [(0, (0.28, 2.05, 0.17)), (2, (0.27, 2.0, 0.26)), (3, (0.24, 1.93, 0.32)), (7, (0.24, 1.93, 0.32)),
                   (8, (0.24, 2.12, 0.46)), (9, GL), (18, GL)],
        "face_r": [(0, "lip_reach"), (1, "lip_reach"), (2, "wall"), (5, "wall"), (6, "lip_reach"), (7, "deck"), (18, "deck")],
        "face_l": [(0, "lip_reach"), (2, "lip_reach"), (3, "wall"), (7, "wall"), (8, "lip_reach"), (9, "deck"), (18, "deck")],
        "pole_r": [(0, (-0.6, -0.6, -0.4)), (2, (-0.8, -0.5, -0.3)), (5, (-0.8, -0.6, -0.3)), (7, (-0.5, -1.0, -0.2)),
                   (18, HANG["pole_r"])],
        "pole_l": [(0, (0.6, -0.6, -0.4)), (3, (0.8, -0.5, -0.3)), (7, (0.8, -0.6, -0.3)), (9, (0.5, -1.0, -0.2)),
                   (18, HANG["pole_l"])],
        "grip_r": [(0, -0.3), (2, -0.45), (5, -0.4), (7, 0.45), (11, 0.35), (18, HANG["grip_r"])],
        "grip_l": [(0, -0.3), (3, -0.45), (7, -0.4), (9, 0.45), (13, 0.35), (18, HANG["grip_l"])],
        # (the scrabble: the right foot kicked onto the face at f2, slipping 6 cm at f4, off it at f6 and re-planted higher
        # at f8; the left planted at f4 and walked up at f10; both onto the hang's places by f13)
        "foot_r": [(0, (-0.14, 0.6, -0.02)), (2, (-0.16, 0.92, SCR_FACE_Z)), (4, (-0.16, 0.86, SCR_FACE_Z)), (6, (-0.15, 1.02, 0.07)),
                   (8, (-0.16, 1.22, SCR_FACE_Z)), (10, (-0.16, 1.24, SCR_FACE_Z)), (13, GFR), (18, GFR)],
        "foot_l": [(0, (0.14, 0.54, -0.08)), (2, (0.15, 0.7, 0.02)), (4, (0.16, 0.95, SCR_FACE_Z)), (8, (0.16, 1.0, SCR_FACE_Z)),
                   (10, (0.15, 1.13, 0.12)), (12, GFL), (18, GFL)],
        "heel_r": [(0, 30), (2, 2), (4, 14), (6, 30), (8, 4), (10, 6), (13, HANG["heel_r"]), (18, HANG["heel_r"])],
        "heel_l": [(0, 32), (2, 24), (4, 4), (8, 8), (10, 24), (12, HANG["heel_l"]), (18, HANG["heel_l"])],
        "fyaw_r": [(0, 6), (2, HANG["fyaw_r"]), (18, HANG["fyaw_r"])], "fyaw_l": [(0, 8), (4, HANG["fyaw_l"]), (18, HANG["fyaw_l"])],
        "knee_r": [(0, (-0.2, 0.0, 1.0)), (2, (-0.4, 0.3, 1.0)), (6, (-0.4, 0.5, 1.0)), (8, (-0.35, 0.2, 1.0)), (18, HANG["knee_r"])],
        "knee_l": [(0, (0.2, 0.0, 1.0)), (4, (0.35, 0.3, 1.0)), (10, (0.35, 0.5, 1.0)), (12, (0.3, 0.1, 1.0)), (18, HANG["knee_l"])],
    },
    # breaking the fall on the deck (E just as he lands: up at once): he comes down out of the tumble flung open and takes the
    # deck in a three-point breakfall (the right knee down, the left foot planted ahead, the right palm slapped flat on the
    # deck out to the side, the left arm flung up and back, bowed low with the eyes up), the slap's rebound drives him
    # straight up (the right foot stepping in under him) through the stand a touch past onto the toes, the arms coming
    # down from the balance into the stand last.  strike_s: the slap; hold_s: its rebound; back_s: driving up
    "tech": {
        "length": 14,
        "meta": {"strike_s": 1 / FPS, "hold_s": 2 / FPS, "back_s": 4 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, (0.0, -0.18, 0.0)), (1, SLAP["root"]), (2, (0.0, -0.52, 0.03)), (3, (0.0, -0.4, 0.03)), (4, (0.0, -0.3, 0.03)), (6, (0.0, -0.1, 0.01)),
                 (8, (0.0, 0.004, 0.0)), (10, (0.0, -0.025, 0.0)), (14, STAND["root"])],
        "hips": [(0, 22), (1, SLAP["hips"]), (2, 60), (3, 44), (4, 30), (6, 9), (8, -2), (10, 1), (14, 0)],
        "chest": [(0, 14), (1, SLAP["chest"]), (2, 24), (4, 12), (6, 3), (8, -3), (10, 0.5), (14, 0)],
        "side": [(0, -4), (1, SLAP["side"]), (2, -28), (4, -8), (7, 0), (14, 0)],
        "twist": [(0, -2), (1, SLAP["twist"]), (3, -5), (6, 0), (14, 0)],
        "head": [(0, 14), (1, SLAP["head"]), (2, -52), (4, -26), (6, -6), (8, 2), (10, -1), (14, 0)],
        "clav_r": [(0, (-6, -20)), (1, SLAP["clav_r"]), (3, (8, 8)), (6, (2, 0)), (14, (0, 0))],
        "clav_l": [(0, (-6, -20)), (1, SLAP["clav_l"]), (3, (-8, -20)), (6, (0, -6)), (10, (0, 0)), (14, (0, 0))],
        "hand_r": [(0, (-0.52, 1.25, -0.1)), (1, SLAP["hand_r"]), (2, (-0.24, 0.13, 0.43)), (3, (-0.27, 0.39, 0.38)), (4, (-0.3, 0.57, 0.32)), (5, (-0.36, 0.7, 0.3)),
                   (7, (-0.3, 0.95, 0.22)), (9, (-0.24, 0.85, 0.14)), (11, (-0.2, 0.8, 0.08)), (14, HR)],
        "hand_l": [(0, (0.52, 1.28, -0.12)), (1, SLAP["hand_l"]), (2, (0.42, 0.82, 0.16)), (4, (0.46, 0.95, 0.05)), (6, (0.42, 1.0, 0.08)),
                   (8, (0.3, 0.92, 0.14)), (11, (0.21, 0.81, 0.08)), (14, HL)],
        "face_r": [(0, "flail"), (1, "deck_out"), (2, "deck_out"), (4, "palm_down"), (7, "balance"), (11, "stand"), (14, "stand")],
        "face_l": [(0, "flail"), (1, "flung_up"), (3, "flung_up"), (6, "balance"), (11, "stand"), (14, "stand")],
        "pole_r": [(0, (-0.6, -0.6, -0.5)), (1, SLAP["pole_r"]), (3, (-1.0, 0.0, -0.3)), (7, (-0.6, -0.5, -0.6)), (14, STAND["pole_r"])],
        "pole_l": [(0, (0.6, -0.6, -0.5)), (1, SLAP["pole_l"]), (4, (0.6, -0.6, -0.5)), (8, (0.5, -0.4, -0.8)), (14, STAND["pole_l"])],
        "grip_r": [(0, -0.3), (1, -0.4), (3, -0.3), (6, 0.1), (14, 0.4)], "grip_l": [(0, -0.3), (2, -0.3), (6, 0.1), (14, 0.4)],
        # (the right knee to the deck, the toes tucked under, then stepped through to the stand; the left planted ahead, then
        # drawn back in as he rises)
        "foot_r": [(0, (-0.15, 0.24, -0.2)), (1, SLAP["foot_r"]), (3, SLAP["foot_r"]), (5, _heel_key("r", (-0.14, 0.14, -0.14), 30.0, 6.0)),
                   (6, FR), (14, FR)],
        "foot_l": [(0, (0.17, 0.14, 0.26)), (1, SLAP["foot_l"]), (4, SLAP["foot_l"]), (6, (0.15, 0.12, 0.12)), (7, FL), (14, FL)],
        "heel_r": [(0, 30), (1, SLAP["heel_r"]), (3, SLAP["heel_r"]), (5, 30), (6, 0), (8, 5), (10, 0), (14, 0)],
        "heel_l": [(0, 20), (1, 0), (4, 0), (5, 14), (7, 0), (8, 5), (10, 0), (14, 0)],
        "fyaw_r": [(0, 6), (1, SLAP["fyaw_r"]), (5, 6), (6, 7), (14, 7)], "fyaw_l": [(0, 8), (1, SLAP["fyaw_l"]), (5, 10), (7, 7), (14, 7)],
        "knee_r": [(0, (-0.2, 0.0, 1.0)), (1, SLAP["knee_r"]), (3, SLAP["knee_r"]), (6, (-0.2, 0.0, 1.0)), (9, "auto")],
        "knee_l": [(0, (0.3, 0.2, 1.0)), (1, SLAP["knee_l"]), (4, SLAP["knee_l"]), (7, (0.25, 0.0, 1.0)), (9, "auto")],
    },
    # breaking the fall with a roll (2.5 m in 0.4 s by the code, to his right; its twin to the left): the slap's
    # three-point breakfall, and its momentum carried straight on into the side roll over the right shoulder and the back,
    # up off the left leg first and on to the stand.  hold_s: into the ball; strike_s: over the back; back_s: on his feet
    "tech_roll": _tech_roll(),
    # breaking the fall on a wall (the deck's face, an ice or earth wall, a Column: E as he meets it): flung open into it, he
    # takes the wall like a cat, the soles and the palms flat on it, the knees and the elbows folding deep (stuck 0.1 s);
    # then the legs drive and the arms shove him off it (the code springs him at vy +3), the head and the eyes turned up
    # and back the way he goes, the arms flung up and open and the legs trailing, into the fall. The wall WALL_Z ahead
    # (meta wall_z).  strike_s: the plant; hold_s: stuck; back_s: the push
    "tech_wall": {
        "length": 15, "base": AIR,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 5 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "wall_z": 0.5},
        "root": [(0, AIR["root"]), (1, (0.0, -0.02, 0.06)), (3, (0.0, -0.05, 0.1)), (4, (0.0, -0.02, 0.0)), (5, (0.0, 0.03, -0.14)),
                 (7, (0.0, 0.05, -0.12)), (10, (0.0, 0.02, -0.04)), (15, AIR["root"])],
        "hips": [(0, -6), (1, 16), (3, 22), (4, 12), (5, -8), (7, -12), (10, -2), (15, AIR["hips"])],
        "chest": [(0, -10), (1, 6), (3, 10), (4, 2), (5, -14), (7, -16), (10, -4), (15, AIR["chest"])],
        "head": [(0, -12), (1, 4), (2, 0), (3, -8), (5, -26), (7, -24), (10, -6), (15, AIR["head"])],
        "look": [(0, 0), (1, 0), (3, 26), (5, 34), (8, 20), (12, 4), (15, 0)],
        "twist": [(0, 0), (2, 0), (3, 6), (5, 10), (9, 4), (15, 0)],
        "clav_r": [(0, (-6, -22)), (1, (8, 4)), (3, (12, 10)), (5, (-6, -20)), (7, (-8, -28)), (11, (-4, -14)), (15, AIR["clav_r"])],
        "clav_l": [(0, (-6, -22)), (1, (8, 4)), (3, (12, 10)), (5, (-6, -20)), (7, (-8, -28)), (11, (-4, -14)), (15, AIR["clav_l"])],
        "hand_r": [(0, (-0.5, 1.32, -0.18)), (1, (-0.27, 1.22, 0.47)), (3, (-0.27, 1.22, 0.47)), (4, (-0.3, 1.28, 0.36)),
                   (5, (-0.36, 1.46, 0.02)), (7, (-0.45, 1.55, -0.12)), (10, (-0.58, 1.42, -0.02)), (15, AR)],
        "hand_l": [(0, (0.5, 1.34, -0.16)), (1, (0.27, 1.24, 0.47)), (3, (0.27, 1.24, 0.47)), (4, (0.3, 1.3, 0.36)),
                   (5, (0.36, 1.47, 0.02)), (7, (0.45, 1.56, -0.12)), (10, (0.58, 1.43, -0.02)), (15, AL)],
        "face_r": [(0, "flail"), (1, "wall"), (3, "wall"), (5, "flung_up"), (8, "flung_up"), (12, "balance"), (15, "balance")],
        "face_l": [(0, "flail"), (1, "wall"), (3, "wall"), (5, "flung_up"), (8, "flung_up"), (12, "balance"), (15, "balance")],
        "pole_r": [(0, (-0.4, -0.6, -0.6)), (1, (-1.0, -0.4, 0.0)), (3, (-1.0, -0.5, 0.0)), (6, (-1.0, 0.0, -0.3)), (15, AIR["pole_r"])],
        "pole_l": [(0, (0.4, -0.6, -0.6)), (1, (1.0, -0.4, 0.0)), (3, (1.0, -0.5, 0.0)), (6, (1.0, 0.0, -0.3)), (15, AIR["pole_l"])],
        "grip_r": [(0, -0.3), (1, -0.45), (4, -0.45), (6, -0.3), (15, AIR["grip_r"])],
        "grip_l": [(0, -0.3), (1, -0.45), (4, -0.45), (6, -0.3), (15, AIR["grip_l"])],
        # (the soles flat on the wall: the toes up about the heels (heel -80), the ankles 8 cm off it; held through the push
        # (f5) while the legs straighten, then off and trailing)
        "foot_r": [(0, (-0.18, 0.32, 0.12)), (1, _heel_key("r", (-0.15, 0.58, 0.42), -80.0, 10.0)),
                   (5, _heel_key("r", (-0.15, 0.58, 0.42), -80.0, 10.0)), (7, (-0.14, 0.34, 0.16)), (10, (-0.13, 0.28, 0.14)), (15, AFR)],
        "foot_l": [(0, (0.18, 0.36, 0.04)), (1, _heel_key("l", (0.15, 0.6, 0.42), -80.0, 10.0)),
                   (5, _heel_key("l", (0.15, 0.6, 0.42), -80.0, 10.0)), (7, (0.14, 0.38, 0.0)), (10, (0.14, 0.33, -0.1)), (15, AFL)],
        "heel_r": [(0, 30), (1, -80), (5, -80), (6, 10), (7, 40), (15, AIR["heel_r"])],
        "heel_l": [(0, 30), (1, -80), (5, -80), (6, 10), (7, 40), (15, AIR["heel_l"])],
        "fyaw_r": [(0, 6), (1, 10), (5, 10), (8, 6), (15, AIR["fyaw_r"])], "fyaw_l": [(0, 8), (1, 10), (5, 10), (8, 8), (15, AIR["fyaw_l"])],
        "knee_r": [(0, (-0.3, 0.0, 1.0)), (1, (-0.6, 0.6, 0.6)), (3, (-0.6, 0.7, 0.5)), (5, (-0.3, 0.3, 1.0)), (15, AIR["knee_r"])],
        "knee_l": [(0, (0.3, 0.0, 1.0)), (1, (0.6, 0.6, 0.6)), (3, (0.6, 0.7, 0.5)), (5, (0.3, 0.3, 1.0)), (15, AIR["knee_l"])],
    },
    # the spiked knock (driven down from above): the hit folds him (the chest and the head slammed down, the arms whipped up
    # behind, the legs kicked back), then he is stretched into a long plunging line: the legs straight and together under
    # him, the toes pointed down, the arms dragged straight up overhead close together by the fall, the chin down watching
    # the water come; the hands flutter in the wind while it lasts (hold_s); opened back into the fall.
    # strike_s: the hit; hold_s: the plunge; back_s: the recovery
    "knock_spiked": {
        "length": 22, "base": AIR,
        "meta": {"strike_s": 1 / FPS, "hold_s": 4 / FPS, "back_s": 14 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "flip": [(0, 0), (1, 12), (3, 36), (4, 44), (9, 46), (14, 44), (18, 14), (22, 0)],
        "root": [(0, AIR["root"]), (1, (0.0, 0.05, -0.04)), (2, (0.0, 0.04, -0.02)), (4, (0.0, 0.03, 0.0)), (14, (0.0, 0.03, 0.0)),
                 (18, (0.0, 0.01, 0.0)), (22, AIR["root"])],
        "hips": [(0, AIR["hips"]), (1, 26), (2, 16), (4, -8), (14, -8), (18, 2), (22, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (1, 30), (2, 16), (4, -12), (9, -14), (14, -12), (18, 0), (22, AIR["chest"])],
        "head": [(0, AIR["head"]), (1, 22), (2, 36), (4, 30), (14, 28), (18, 12), (22, AIR["head"])],
        "clav_r": [(0, AIR["clav_r"]), (1, (-10, -20)), (4, (-10, -30)), (14, (-10, -30)), (18, (-2, -16)), (22, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (1, (-10, -20)), (4, (-10, -30)), (14, (-10, -30)), (18, (-2, -16)), (22, AIR["clav_l"])],
        "hand_r": [(0, AR), (1, (-0.3, 1.36, -0.22)), (2, (-0.22, 1.56, -0.28)), (4, (-0.15, 1.66, -0.3)), (6, (-0.16, 1.64, -0.33)),
                   (8, (-0.15, 1.67, -0.29)), (10, (-0.16, 1.64, -0.33)), (12, (-0.15, 1.67, -0.29)), (14, (-0.15, 1.66, -0.3)),
                   (18, (-0.5, 1.5, -0.04)), (22, AR)],
        "hand_l": [(0, AL), (1, (0.3, 1.38, -0.21)), (2, (0.22, 1.57, -0.27)), (4, (0.15, 1.67, -0.29)), (6, (0.15, 1.69, -0.27)),
                   (8, (0.16, 1.65, -0.32)), (10, (0.15, 1.69, -0.27)), (12, (0.16, 1.65, -0.32)), (14, (0.15, 1.67, -0.29)),
                   (18, (0.5, 1.52, -0.04)), (22, AL)],
        "face_r": [(0, "balance"), (1, "flung_up"), (4, "loose_up"), (14, "loose_up"), (19, "balance"), (22, "balance")],
        "face_l": [(0, "balance"), (1, "flung_up"), (4, "loose_up"), (14, "loose_up"), (19, "balance"), (22, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (1, (-0.6, -0.4, -0.7)), (4, (-1.0, 0.0, 0.3)), (14, (-1.0, 0.0, 0.3)), (22, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (1, (0.6, -0.4, -0.7)), (4, (1.0, 0.0, 0.3)), (14, (1.0, 0.0, 0.3)), (22, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (1, -0.4), (4, 0.0), (7, -0.2), (10, 0.05), (14, -0.1), (22, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (1, -0.4), (4, -0.1), (7, 0.05), (10, -0.2), (14, 0.0), (22, AIR["grip_l"])],
        # (the legs trailing up behind him as he is driven down, the knees soft, the toes pointed, scissoring a little)
        "foot_r": [(0, AFR), (1, (-0.14, 0.34, -0.28)), (2, (-0.11, 0.3, -0.24)), (4, _heel_key("r", (-0.09, 0.28, -0.3), 50.0, 4.0)),
                   (9, _heel_key("r", (-0.09, 0.3, -0.27), 50.0, 4.0)), (14, _heel_key("r", (-0.09, 0.28, -0.3), 50.0, 4.0)),
                   (18, (-0.13, 0.26, 0.14)), (22, AFR)],
        "foot_l": [(0, AFL), (1, (0.14, 0.36, -0.32)), (2, (0.11, 0.32, -0.26)), (4, _heel_key("l", (0.09, 0.32, -0.36), 50.0, 4.0)),
                   (9, _heel_key("l", (0.09, 0.3, -0.39), 50.0, 4.0)), (14, _heel_key("l", (0.09, 0.32, -0.36), 50.0, 4.0)),
                   (18, (0.13, 0.3, -0.14)), (22, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (1, 40), (4, 50), (14, 50), (18, 34), (22, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (1, 40), (4, 50), (14, 50), (18, 34), (22, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 4), (14, 4), (22, AIR["fyaw_r"])], "fyaw_l": [(0, AIR["fyaw_l"]), (4, 4), (14, 4), (22, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (1, (-0.2, -0.3, 1.0)), (4, (-0.1, -0.2, 1.0)), (14, (-0.1, -0.2, 1.0)), (22, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (1, (0.2, -0.3, 1.0)), (4, (0.1, -0.2, 1.0)), (14, (0.1, -0.2, 1.0)), (22, AIR["knee_l"])],
    },
}

## The lying ones, keyed on the deck (_wclip).
SET6.update({
    # the lie (a loop): dazed on his back (lie_at), breathing
    "lie": dict({"length": LIE_LEN, "loop": True, "toes": "foot", "meta": {"hand": "both", "mask": "full", "root": "place",
                                                                         "legs_always": 1.0, "lying": 1.0}},
                **_wclip(LIE_LEN, {k: (lambda f, k=k: lie_at(f)[k]) for k in LIE}, loop=True)),
    # the bounce (the back meets the deck falling fast): he comes down flat on his back with the limbs trailing up; the
    # trunk stops and the limbs slam down after it (the palms slapping the deck, the heels hitting), the head whipping up off
    # it; the bounce lifts him in a loose V (the knees and the chest coming up, the arms flung up), and he falls back flat,
    # the arms flopping onto the deck first, then the legs, the head last, into the lie.  strike_s: the back on the deck;
    # hold_s: the slam; back_s: falling back
    "knock_bounce": dict({"length": 18, "toes": "foot",
                          "meta": {"strike_s": 1 / FPS, "hold_s": 2 / FPS, "back_s": 8 / FPS, "hand": "both", "mask": "full",
                                   "root": "place", "legs_always": 1.0, "lying": 1.0}},
                         **_wclip(18, {
                             "pelvis": [(0, (0.0, 0.22, -0.3)), (1, LIE_PELVIS), (2, (0.0, 0.115, -0.3)), (4, (0.0, 0.25, -0.3)),
                                        (6, (0.0, 0.33, -0.3)), (8, (0.0, 0.28, -0.3)), (10, (0.0, 0.15, -0.3)), (11, LIE_PELVIS),
                                        (12, (0.0, 0.116, -0.3)), (14, LIE["pelvis"]), (18, LIE["pelvis"])],
                             "flip": [(0, -84), (1, -90), (18, -90)],
                             "hips": [(0, 10), (1, 0), (2, 2), (4, 20), (6, 26), (8, 18), (11, 3), (13, -1), (15, 0), (18, LIE["hips"])],
                             "chest": [(0, 6), (1, 2), (2, 5), (4, 10), (6, 14), (8, 10), (11, 0), (13, 3), (16, LIE["chest"]),
                                       (18, LIE["chest"])],
                             "head": [(0, 18), (1, -6), (2, 24), (4, 30), (6, 18), (9, 8), (11, -12), (13, -4), (16, LIE["head"]),
                                      (18, LIE["head"])],
                             "look": [(0, 0), (8, 6), (13, 20), (18, LIE["look"])], "side": [(0, 0), (18, LIE["side"])],
                             "twist": [(0, 0), (18, 0)],
                             "clav_r": [(0, (-6, -24)), (2, (4, 8)), (6, (-6, -20)), (12, (0, 2)), (18, LIE["clav_r"])],
                             "clav_l": [(0, (-6, -24)), (2, (4, 8)), (6, (-6, -20)), (12, (2, 3)), (18, LIE["clav_l"])],
                             "hand_r": [(0, (-0.42, 0.52, -0.56)), (1, (-0.5, 0.3, -0.6)), (2, (-0.64, 0.04, -0.6)),
                                        (4, (-0.55, 0.28, -0.52)), (6, (-0.5, 0.55, -0.5)), (9, (-0.56, 0.36, -0.55)),
                                        (12, (-0.63, 0.04, -0.6)), (18, LIE["hand_r"])],
                             "hand_l": [(0, (0.44, 0.55, -0.52)), (1, (0.52, 0.32, -0.55)), (2, (0.62, 0.04, -0.58)),
                                        (4, (0.52, 0.3, -0.46)), (6, (0.44, 0.58, -0.38)), (9, (0.3, 0.42, -0.36)),
                                        (12, (0.1, 0.27, -0.36)), (15, LIE["hand_l"]), (18, LIE["hand_l"])],
                             "face_r": [(0, "flail"), (2, ("w", (-0.9, 0.0, -0.3), (0.0, -1.0, 0.0))), (6, "flung_up"),
                                        (12, LIE["face_r"]), (18, LIE["face_r"])],
                             "face_l": [(0, "flail"), (2, ("w", (0.9, 0.0, -0.3), (0.0, -1.0, 0.0))), (6, "flung_up"),
                                        (13, LIE["face_l"]), (18, LIE["face_l"])],
                             "pole_r": [(0, (-0.6, 0.0, -0.8)), (2, (-1.0, 0.0, 0.5)), (6, (-0.8, 0.2, -0.5)), (12, LIE["pole_r"]), (18, LIE["pole_r"])],
                             "pole_l": [(0, (0.6, 0.0, -0.8)), (2, (1.0, 0.0, 0.5)), (6, (0.8, 0.2, -0.5)), (13, LIE["pole_l"]), (18, LIE["pole_l"])],
                             "grip_r": [(0, -0.3), (2, -0.5), (6, -0.2), (12, LIE["grip_r"]), (18, LIE["grip_r"])],
                             "grip_l": [(0, -0.3), (2, -0.5), (6, -0.2), (13, LIE["grip_l"]), (18, LIE["grip_l"])],
                             "foot_r": [(0, (-0.18, 0.34, 0.3)), (1, (-0.2, 0.2, 0.33)), (2, (-0.2, 0.075, 0.36)),
                                        (4, (-0.17, 0.34, 0.3)), (6, (-0.15, 0.48, 0.24)), (9, (-0.16, 0.3, 0.2)),
                                        (11, (-0.17, 0.12, 0.08)), (13, LIE["foot_r"]), (18, LIE["foot_r"])],
                             "foot_l": [(0, (0.18, 0.32, 0.36)), (2, (0.2, 0.065, 0.42)), (4, (0.18, 0.33, 0.36)),
                                        (6, (0.16, 0.46, 0.3)), (9, (0.18, 0.28, 0.36)), (12, (0.2, 0.068, 0.4)),
                                        (14, LIE["foot_l"]), (18, LIE["foot_l"])],
                             "heel_r": [(0, 30), (2, 40), (8, 40), (12, 82), (13, 90), (18, 90)],
                             "heel_l": [(0, 30), (2, 25), (18, 25)],
                             "fyaw_r": [(0, 8), (18, LIE["fyaw_r"])], "fyaw_l": [(0, 14), (12, LIE["fyaw_l"]), (18, LIE["fyaw_l"])],
                             "knee_r": [(0, (-0.2, 0.0, 1.0)), (4, (-0.2, -0.2, 1.0)), (13, LIE["knee_r"]), (18, LIE["knee_r"])],
                             "knee_l": [(0, (0.2, 0.0, 1.0)), (14, LIE["knee_l"]), (18, LIE["knee_l"])],
                         })),
})


def _getup():
    """own-bend-getup: from the lie, the carp skip-up (Northern Shaolin's kip): the knees drawn to the chest and the palms
    planted by the ears, rolled back onto the shoulders with the legs piked over the face (the coil), then the legs whipped
    over and down as the palms shove, the back arched, sprung off the deck and landed on both feet in a crouch under where
    the hips were; up through the stand a touch past and settled."""
    k = {
        "pelvis": [(0, LIE["pelvis"]), (2, (0.0, 0.13, -0.34)), (3, (0.0, 0.17, -0.42)), (4, (0.0, 0.215, -0.48)), (5, (0.0, 0.24, -0.45)), (6, (0.0, 0.52, -0.3)),
                   (7, (0.0, 0.57, -0.16)), (8, (0.0, 0.48, -0.06)), (10, (0.0, 0.55, -0.02)), (13, (0.0, 0.82, 0.015)),
                   (15, (0.0, 0.888, 0.021)), (17, (0.0, 0.876, 0.021)), (20, PELV_STAND)],
        "flip": [(0, -90), (2, -102), (4, -136), (5, -130), (6, -76), (7, -32), (8, -8), (10, 0), (20, 0)],
        "hips": [(0, LIE["hips"]), (2, 16), (4, 22), (5, 18), (6, -16), (7, 6), (8, 38), (10, 34), (13, 12), (15, -1), (17, 0.5), (20, 0)],
        "chest": [(0, LIE["chest"]), (2, 22), (4, 26), (5, 20), (6, -10), (7, 4), (8, 16), (10, 14), (13, 4), (15, -2), (17, 0.5),
                  (20, 0)],
        "head": [(0, LIE["head"]), (2, 30), (4, 40), (5, 34), (6, -6), (7, -4), (8, -14), (10, -10), (13, -2), (15, 1), (20, 0)],
        "look": [(0, LIE["look"]), (2, 6), (4, 0), (20, 0)], "side": [(0, LIE["side"]), (3, 0), (20, 0)], "twist": [(0, 0), (20, 0)],
        "clav_r": [(0, LIE["clav_r"]), (2, (-6, -20)), (5, (-6, -22)), (6, (6, 0)), (8, (10, 6)), (12, (4, 2)), (16, (0, 0)), (20, (0, 0))],
        "clav_l": [(0, LIE["clav_l"]), (2, (-6, -20)), (5, (-6, -22)), (6, (6, 0)), (8, (10, 6)), (12, (4, 2)), (16, (0, 0)), (20, (0, 0))],
        "hand_r": [(0, LIE["hand_r"]), (1, (-0.44, 0.14, -0.72)), (2, (-0.21, 0.035, -0.78)), (5, (-0.21, 0.035, -0.78)), (6, (-0.27, 0.22, -0.6)),
                   (7, (-0.32, 0.62, -0.05)), (8, (-0.32, 0.62, 0.3)), (10, (-0.3, 0.72, 0.32)), (13, (-0.26, 0.82, 0.22)),
                   (16, (-0.2, 0.8, 0.08)), (20, HR)],
        "hand_l": [(0, LIE["hand_l"]), (2, (0.21, 0.035, -0.78)), (5, (0.21, 0.035, -0.78)), (6, (0.27, 0.22, -0.6)),
                   (7, (0.32, 0.62, -0.05)), (8, (0.32, 0.62, 0.3)), (10, (0.3, 0.72, 0.32)), (13, (0.26, 0.82, 0.22)),
                   (16, (0.2, 0.8, 0.08)), (20, HL)],
        "face_r": [(0, LIE["face_r"]), (2, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))), (5, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))),
                   (8, "balance"), (12, "balance"), (17, "stand"), (20, "stand")],
        "face_l": [(0, LIE["face_l"]), (2, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))), (5, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))),
                   (8, "balance"), (12, "balance"), (17, "stand"), (20, "stand")],
        "pole_r": [(0, LIE["pole_r"]), (2, ("w", (-0.3, 1.0, 0.0))), (5, ("w", (-0.3, 1.0, 0.0))), (7, (-0.8, -0.4, -0.4)),
                   (12, (-0.6, -0.5, -0.6)), (20, STAND["pole_r"])],
        "pole_l": [(0, LIE["pole_l"]), (2, ("w", (0.3, 1.0, 0.0))), (5, ("w", (0.3, 1.0, 0.0))), (7, (0.8, -0.4, -0.4)),
                   (12, (0.6, -0.5, -0.6)), (20, STAND["pole_l"])],
        "grip_r": [(0, LIE["grip_r"]), (2, -0.2), (5, -0.2), (7, 0.1), (12, 0.2), (20, 0.4)],
        "grip_l": [(0, LIE["grip_l"]), (2, -0.2), (5, -0.2), (7, 0.1), (12, 0.2), (20, 0.4)],
        "foot_r": [(0, LIE["foot_r"]), (2, (-0.12, 0.42, -0.4)), (4, (-0.11, 0.66, -0.74)), (5, (-0.11, 0.7, -0.62)),
                   (6, (-0.13, 0.5, -0.14)), (7, (-0.13, 0.16, -0.05)), (8, (-0.13, 0.077, -0.04)), (20, (-0.13, 0.077, -0.04))],
        "foot_l": [(0, LIE["foot_l"]), (2, (0.12, 0.42, -0.4)), (4, (0.11, 0.66, -0.74)), (5, (0.11, 0.7, -0.62)),
                   (6, (0.13, 0.5, -0.14)), (7, (0.13, 0.16, -0.05)), (8, (0.13, 0.077, -0.04)), (20, (0.13, 0.077, -0.04))],
        "heel_r": [(0, LIE["heel_r"]), (2, 40), (4, 50), (6, 40), (7, 24), (8, 8), (10, 0), (14, 0), (15, 5), (17, 0), (20, 0)],
        "heel_l": [(0, LIE["heel_l"]), (2, 40), (4, 50), (6, 40), (7, 24), (8, 8), (10, 0), (14, 0), (15, 5), (17, 0), (20, 0)],
        "fyaw_r": [(0, LIE["fyaw_r"]), (4, 6), (8, 10), (20, 7)], "fyaw_l": [(0, LIE["fyaw_l"]), (4, 6), (8, 10), (20, 7)],
        "knee_r": [(0, LIE["knee_r"]), (2, (-0.2, 0.3, 1.0)), (6, (-0.2, 0.2, 1.0)), (8, (-0.35, 0.0, 1.0)), (12, (-0.3, 0.0, 1.0)),
                   (16, "auto")],
        "knee_l": [(0, LIE["knee_l"]), (2, (0.2, 0.3, 1.0)), (6, (0.2, 0.2, 1.0)), (8, (0.35, 0.0, 1.0)), (12, (0.3, 0.0, 1.0)),
                   (16, "auto")],
    }
    return dict({"length": 20, "toes": "foot",
                 "meta": {"hold_s": 4 / FPS, "strike_s": 8 / FPS, "back_s": 10 / FPS, "hand": "both", "mask": "full", "root": "place",
                          "legs_always": 1.0}}, **_wclip(20, k))


## The getup roll's log roll: the turn about the long axis (to his right) and how far it lifts the pelvis on his side.
GROLL_BARREL = [(0, 0), (2, 0), (4, -50), (5, -90), (7, -180), (9, -270), (11, -335), (12, -358), (13, -360), (26, -360)]
GROLL_SIDE_LIFT = 0.09
## ... and face down (the head and the crossed arms in front of the chest).
GROLL_FRONT_LIFT = 0.12


def _getup_roll():
    """own-bend-getup-roll (to his right; its twin to the left): from the lie the arms crossed on the chest and the legs
    drawn long together, a whole log roll along the deck (the code carries him 2.5 m), on his back again, the knees drawn
    and the palms pushing beside the hips, sat up and rocked forward over the feet into a crouch, up."""
    base = [(0, LIE["pelvis"]), (2, (0.0, 0.12, -0.3)), (13, (0.0, 0.12, -0.3)), (14, (0.0, 0.145, -0.3)), (15, (0.0, 0.16, -0.3)), (17, (0.0, 0.3, -0.17)),
            (18, (0.0, 0.44, -0.08)), (21, (0.0, 0.78, 0.0)), (23, (0.0, 0.888, 0.021)), (26, PELV_STAND)]

    def pelvis(f):
        b = _kv(GROLL_BARREL, f)
        return _add(_kv(base, f), (0.0, GROLL_SIDE_LIFT * abs(math.sin(math.radians(b)))
                                     + GROLL_FRONT_LIFT * max(0.0, -math.cos(math.radians(b))), 0.0))
    chest_r, chest_l = ("b", (0.1, 1.12, 0.17)), ("b", (-0.1, 1.08, 0.19))
    leg_r, leg_l = ("b", (-0.07, 0.1, -0.02)), ("b", (0.07, 0.1, -0.02))
    k = {
        "pelvis": pelvis, "barrel": GROLL_BARREL,
        "flip": [(0, -90), (13, -90), (15, -62), (16, -40), (17, -14), (18, -2), (19, 0), (26, 0)],
        "hips": [(0, LIE["hips"]), (2, 4), (13, 4), (15, 20), (17, 36), (18, 42), (19, 38), (21, 20), (23, -1), (25, 0.5), (26, 0)],
        "chest": [(0, LIE["chest"]), (2, 8), (13, 8), (15, 22), (17, 20), (18, 18), (21, 6), (23, -2), (25, 0.5), (26, 0)],
        "head": [(0, LIE["head"]), (2, 4), (13, 4), (15, 18), (17, 0), (18, -12), (21, -4), (23, 1), (26, 0)],
        "look": [(0, LIE["look"]), (2, 0), (26, 0)], "side": [(0, LIE["side"]), (2, 0), (26, 0)], "twist": [(0, 0), (26, 0)],
        "clav_r": [(0, LIE["clav_r"]), (2, (14, 8)), (13, (14, 8)), (15, (2, 4)), (18, (6, 4)), (22, (2, 0)), (26, (0, 0))],
        "clav_l": [(0, LIE["clav_l"]), (2, (14, 8)), (13, (14, 8)), (15, (2, 4)), (18, (6, 4)), (22, (2, 0)), (26, (0, 0))],
        "hand_r": [(0, LIE["hand_r"]), (2, chest_r), (13, chest_r), (14, (-0.27, 0.035, -0.51)), (15, (-0.27, 0.045, -0.5)), (16, (-0.3, 0.3, -0.24)),
                   (18, (-0.32, 0.5, 0.2)), (20, (-0.3, 0.68, 0.3)), (23, (-0.22, 0.82, 0.12)), (26, HR)],
        "hand_l": [(0, LIE["hand_l"]), (2, chest_l), (13, chest_l), (14, (0.27, 0.035, -0.51)), (15, (0.27, 0.045, -0.5)), (16, (0.3, 0.3, -0.24)),
                   (18, (0.32, 0.5, 0.2)), (20, (0.3, 0.68, 0.3)), (23, (0.22, 0.82, 0.12)), (26, HL)],
        "face_r": [(0, LIE["face_r"]), (2, "cross"), (13, "cross"), (14, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))),
                   (15, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))), (18, "balance"), (22, "balance"), (25, "stand"), (26, "stand")],
        "face_l": [(0, LIE["face_l"]), (2, "cross"), (13, "cross"), (14, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))),
                   (15, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))), (18, "balance"), (22, "balance"), (25, "stand"), (26, "stand")],
        "pole_r": [(0, LIE["pole_r"]), (2, (-1.0, -0.6, 0.0)), (13, (-1.0, -0.6, 0.0)), (15, (-0.4, 0.0, -1.0)), (18, (-0.8, -0.4, -0.4)),
                   (26, STAND["pole_r"])],
        "pole_l": [(0, LIE["pole_l"]), (2, (1.0, -0.6, 0.0)), (13, (1.0, -0.6, 0.0)), (15, (0.4, 0.0, -1.0)), (18, (0.8, -0.4, -0.4)),
                   (26, STAND["pole_l"])],
        "grip_r": [(0, LIE["grip_r"]), (2, 0.6), (13, 0.6), (15, -0.2), (17, -0.2), (20, 0.2), (26, 0.4)],
        "grip_l": [(0, LIE["grip_l"]), (2, 0.6), (13, 0.6), (15, -0.2), (17, -0.2), (20, 0.2), (26, 0.4)],
        "foot_r": [(0, LIE["foot_r"]), (2, leg_r), (12, leg_r), (14, (-0.15, 0.077, -0.04)), (26, (-0.13, 0.077, -0.04))],
        "foot_l": [(0, LIE["foot_l"]), (2, leg_l), (12, leg_l), (14, (0.15, 0.077, -0.04)), (26, (0.13, 0.077, -0.04))],
        "heel_r": [(0, LIE["heel_r"]), (2, 40), (12, 40), (14, 90), (15, 62), (16, 40), (17, 14), (18, 2), (19, 0), (22, 0), (23, 5), (25, 0), (26, 0)],
        "heel_l": [(0, LIE["heel_l"]), (2, 40), (12, 40), (14, 90), (15, 62), (16, 40), (17, 14), (18, 2), (19, 0), (22, 0), (23, 5), (25, 0), (26, 0)],
        "fyaw_r": [(0, LIE["fyaw_r"]), (2, 4), (12, 4), (14, 8), (26, 7)], "fyaw_l": [(0, LIE["fyaw_l"]), (2, 4), (12, 4), (14, 8), (26, 7)],
        "knee_r": [(0, LIE["knee_r"]), (2, (-0.1, 0.0, 1.0)), (12, (-0.1, 0.0, 1.0)), (14, (-0.2, -0.3, 1.0)), (16, (-0.2, -0.1, 1.0)),
                   (18, (-0.35, 0.0, 1.0)), (23, "auto")],
        "knee_l": [(0, LIE["knee_l"]), (2, (0.1, 0.0, 1.0)), (12, (0.1, 0.0, 1.0)), (14, (0.2, -0.3, 1.0)), (16, (0.2, -0.1, 1.0)),
                   (18, (0.35, 0.0, 1.0)), (23, "auto")],
    }
    return dict({"length": 26, "toes": "foot", "mirror": True, "twin_start": 2,
                 "meta": {"hold_s": 2 / FPS, "strike_s": 7 / FPS, "back_s": 13 / FPS, "hand": "both", "mask": "full", "root": "place",
                          "legs_always": 1.0, "travel": "right"}}, **_wclip(26, k))


## The getup attack's sweep: the right ankle round an arc at the shin's height about GA_CENTRE (the deck's frame), the
## angle (deg, 0 to his left, 90 straight ahead, 180 to his right) at each frame.
GA_CENTRE = (0.04, 0.1, -0.26)
GA_RADIUS = 0.68
GA_ARC = [(4, 172), (5, 156), (6, 128), (7, 92), (8, 60), (9, 40), (10, 32)]


def _ga_foot(deg):
    r = math.radians(deg)
    return (round(GA_CENTRE[0] + GA_RADIUS * math.cos(r), 4), GA_CENTRE[1], round(GA_CENTRE[2] + GA_RADIUS * math.sin(r), 4))


def _getup_attack():
    """own-bend-getup-attack: from the lie, sat up and turned onto the left hand and the left foot (the hips lifted off the
    deck, a crab), the straight right leg stretched out to the right along the deck (the wind-up), then swept round low at
    the shin's height across the front to the left (the strike straight ahead), the trunk turning against it and the right
    arm whipping the other way; the leg drawn in under him and planted, up off both feet to the stand."""
    foot_r = [(0, LIE["foot_r"]), (2, (-0.45, 0.09, -0.12)), (3, (-0.62, 0.095, -0.2))]
    foot_r += [(fr, _ga_foot(d)) for fr, d in GA_ARC]
    foot_r += [(11, (0.3, 0.16, 0.18)), (12, (-0.12, 0.12, 0.02)), (13, (-0.14, 0.077, -0.03)), (20, (-0.13, 0.077, -0.04))]
    k = {
        "pelvis": [(0, LIE["pelvis"]), (1, (0.01, 0.15, -0.3)), (2, (0.02, 0.17, -0.3)), (4, (0.04, 0.22, -0.28)), (7, (0.05, 0.24, -0.26)), (10, (0.04, 0.24, -0.24)),
                   (12, (0.02, 0.42, -0.12)), (13, (0.0, 0.48, -0.06)), (16, (0.0, 0.82, 0.015)), (18, (0.0, 0.886, 0.021)), (20, PELV_STAND)],
        "flip": [(0, -90), (2, -64), (4, -56), (7, -54), (10, -54), (12, -14), (13, -4), (14, 0), (20, 0)],
        "yaw": [(0, 0), (2, 16), (4, -14), (6, 0), (7, 10), (9, 26), (10, 28), (12, 14), (15, 2), (18, -1), (20, 0)],
        "hips": [(0, LIE["hips"]), (2, 10), (4, 6), (7, 4), (10, 8), (12, 36), (13, 40), (16, 12), (18, -1), (20, 0)],
        "chest": [(0, LIE["chest"]), (2, 14), (4, 12), (7, 10), (10, 12), (12, 18), (13, 16), (16, 4), (18, -2), (20, 0)],
        "side": [(0, LIE["side"]), (2, 10), (4, 14), (7, 12), (10, 6), (13, 0), (20, 0)],
        "head": [(0, LIE["head"]), (2, 12), (4, 6), (7, 4), (10, 2), (12, -14), (14, -10), (17, -1), (20, 0)],
        "look": [(0, LIE["look"]), (2, 10), (4, -28), (6, -12), (7, 6), (9, 22), (11, 10), (14, 0), (20, 0)],
        "twist": [(0, 0), (2, 8), (4, 18), (6, 8), (7, -4), (9, -18), (11, -10), (14, 0), (20, 0)],
        "clav_r": [(0, LIE["clav_r"]), (4, (-8, -16)), (7, (6, -4)), (10, (8, 0)), (14, (4, 2)), (20, (0, 0))],
        "clav_l": [(0, LIE["clav_l"]), (2, (-4, 6)), (10, (-4, 6)), (14, (2, 2)), (20, (0, 0))],
        "hand_r": [(0, LIE["hand_r"]), (2, (-0.38, 0.5, -0.36)), (4, (-0.48, 0.64, -0.32)), (6, (-0.3, 0.7, -0.16)), (7, (-0.04, 0.66, -0.12)),
                   (9, (0.2, 0.56, -0.2)), (11, (0.18, 0.58, -0.08)), (13, (-0.3, 0.6, 0.32)), (16, (-0.24, 0.82, 0.18)), (20, HR)],
        "hand_l": [(0, LIE["hand_l"]), (2, (0.24, 0.035, -0.58)), (10, (0.24, 0.035, -0.58)), (11, (0.27, 0.3, -0.42)), (12, (0.3, 0.5, -0.05)),
                   (13, (0.3, 0.58, 0.22)), (16, (0.24, 0.82, 0.18)), (20, HL)],
        "face_r": [(0, LIE["face_r"]), (2, "balance"), (12, "balance"), (17, "stand"), (20, "stand")],
        "face_l": [(0, LIE["face_l"]), (2, ("w", (0.3, 0.0, -0.95), (0.0, -1.0, 0.0))), (10, ("w", (0.3, 0.0, -0.95), (0.0, -1.0, 0.0))),
                   (13, "balance"), (17, "stand"), (20, "stand")],
        "pole_r": [(0, LIE["pole_r"]), (2, (-1.0, -0.4, -0.3)), (12, (-0.8, -0.5, -0.3)), (20, STAND["pole_r"])],
        "pole_l": [(0, LIE["pole_l"]), (2, ("w", (0.6, 0.4, 0.6))), (11, ("w", (0.6, 0.4, 0.6))), (13, (0.8, -0.4, -0.4)),
                   (20, STAND["pole_l"])],
        "grip_r": [(0, LIE["grip_r"]), (3, 0.3), (12, 0.3), (20, 0.4)],
        "grip_l": [(0, LIE["grip_l"]), (2, -0.3), (11, -0.3), (14, 0.2), (20, 0.4)],
        "foot_r": foot_r,
        "foot_l": [(0, LIE["foot_l"]), (2, (0.2, 0.077, -0.02)), (12, (0.2, 0.077, -0.02)), (14, (0.14, 0.077, -0.04)),
                   (20, (0.13, 0.077, -0.04))],
        "heel_r": [(0, LIE["heel_r"]), (2, 80), (3, 70), (11, 70), (12, 30), (13, 0), (16, 0), (17, 5), (19, 0), (20, 0)],
        "heel_l": [(0, LIE["heel_l"]), (2, 64), (4, 56), (7, 54), (10, 50), (12, 14), (13, 4), (14, 0), (16, 0), (17, 5), (19, 0), (20, 0)],
        "fyaw_r": [(0, LIE["fyaw_r"]), (3, 0), (11, 0), (13, 7), (20, 7)], "fyaw_l": [(0, LIE["fyaw_l"]), (2, 20), (12, 20), (14, 7), (20, 7)],
        "knee_r": [(0, LIE["knee_r"]), (2, (-0.3, 0.6, 0.6)), (11, (-0.3, 0.6, 0.6)), (13, (-0.3, 0.0, 1.0)), (17, "auto")],
        "knee_l": [(0, LIE["knee_l"]), (2, ("w", (0.4, 1.0, 0.2))), (12, ("w", (0.4, 1.0, 0.2))), (14, (0.3, 0.0, 1.0)), (17, "auto")],
    }
    return dict({"length": 20, "toes": "foot",
                 "meta": {"hold_s": 4 / FPS, "strike_s": 7 / FPS, "back_s": 10 / FPS, "hand": "foot_r", "mask": "full",
                          "root": "place", "legs_always": 1.0}}, **_wclip(20, k))


SET6.update({
    # the getup (W or Space from the lie; intangible 0.3 s by the code): the carp skip-up.  hold_s: coiled on the
    # shoulders; strike_s: the feet land; back_s: rising
    "getup": _getup(),
    # the getup roll (E and a way from the lie: 2.5 m by the code; to his right, its twin to the left): a log roll.
    # hold_s: gathered; strike_s: face down in the roll; back_s: sat up
    "getup_roll": _getup_roll(),
    # the getup attack (a click from the lie: a low sweep while rising, 5%).  hold_s: the leg out to the right; strike_s:
    # the sweep straight ahead; back_s: the leg drawn in
    "getup_attack": _getup_attack(),
})
CLIPS.update(SET6)


## The slack an arm or a leg keeps short of straight at its keys (m): less is flagged by --fit (a limb locked straight by the IK
## reads stiff; the polish pulls such keys in).
SLACK = 0.015
## The striking limb's slack at strike_s that --fit suggests (m): out nearly straight, not locked.
STRIKE_SLACK = 0.03


## The joints whose bend --angles prints (shoulder, elbow, wrist; hip, knee, ankle) and the last bake's rows.
ARM_J = ("shoulder", "elbow", "wrist")
LEG_J = ("upper_leg", "knee", "ankle")
ANGLES = []
## The joints --points prints each frame (the character's frame, m) with the body's lowest surface (SURF), for placing the
## edge clips' hands, elbows, knees and toes on the lip, the deck and the face.
PT_J = ("heada", "neck", "spinec", "r_shoulder", "l_shoulder", "r_elbow", "l_elbow", "r_palm", "l_palm", "pelvis", "r_knee", "l_knee",
        "r_ankle", "l_ankle", "r_ball", "l_ball")
POINTS = []


def bake(clip, fit=None):
    """The clip's frames; `fit` (a list) collects the frames where a limb is within SLACK of straight or past it: (frame, limb,
    slack, the channel's place pulled in to SLACK)."""
    frames, roots, report = [], [], []
    ANGLES.clear()
    POINTS.clear()
    names = keyed()
    legs_only = clip.get("bones") == "legs"
    if legs_only:
        # a legs-only layer (the air-legs under a cast): only the legs' bones keyed, their rotations each in its parent's frame,
        # so the legs keep their tuck under whatever the hips and the upper body are doing; no root place
        names = [nm for nm in names if any(nm == s + "_" + b for s in "lr" for b in LEG)]
    # (a clip with "substeps": n is baked n times a frame (meta fps FPS * n in the json): a planted hand whose arm moves fast
    # holds its place between the keys too, the game interpolating the bones between them)
    sub = int(clip.get("substeps", 1))
    for fi in range(clip["length"] * sub + 1):
        f = fi / sub if sub > 1 else fi
        rigkit.MISS.clear()
        rots, root = pose(clip, f)
        frames.append({nm: [rots[nm].x, rots[nm].y, rots[nm].z, rots[nm].w] for nm in names})
        if not legs_only:
            roots.append([root.x, root.y, root.z])
        P, G = SK.fk(rots, root)
        # (each elbow's and knee's bend in degrees, 0 straight, for --angles)
        low = surface_low(P)
        POINTS.append((f, {j: tuple(round(x, 3) for x in (head_middle(P) if j == "heada" else P[j])) for j in PT_J},
                       (round(low[0], 3), low[1]), round(hat_low(P, G), 3)))
        ANGLES.append((f, [round(math.degrees((P[s + "_" + b] - P[s + "_" + a]).angle(P[s + "_" + c] - P[s + "_" + b], 0.0)))
                           for s, (a, b, c) in (("r", ARM_J), ("l", ARM_J), ("r", LEG_J), ("l", LEG_J))]))
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
    ap.add_argument("--angles", action="store_true", help="print each frame's elbow and knee bends (deg, 0 straight)")
    ap.add_argument("--points", action="store_true", help="print each frame's key joints and the lowest surface (m)")
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
        if int(clip.get("substeps", 1)) > 1:
            out["clips"][name]["fps"] = FPS * int(clip["substeps"])
        out["names"][name] = game_name(name)
        baked[name] = (frames, roots)
        worst = max(r[-1] for r in report)
        print("BEND %s -> %s: %d frames, worst IK miss %.3f m" % (name, game_name(name), len(frames), worst))
        for fr in fit or []:
            print("   FIT %s f%02d %s slack %.3f -> %s" % (name, fr[0], fr[1], fr[2], fr[3]))
        if a.angles:
            for fr, ang in ANGLES:
                print("   ANG %s f%02d elbow r %3d l %3d  knee r %3d l %3d" % (name, fr, *ang))
        if a.points:
            for fr, pts, low, hat in POINTS:
                print("   PTS %s f%02d low %.3f (%s) " % (name, fr, low[0], low[1]) +
                      " ".join("%s=%s" % (j, list(v)) for j, v in pts.items()) + " hat=%.3f" % hat)
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
