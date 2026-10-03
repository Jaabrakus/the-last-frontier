class_name Throwable
extends Weapon
## Thrown weapons: throwing spear, tomahawk (trade or pipe) and the atlatl
## (spear-thrower with darts, a legendary relic). Same control feel as the bow and the flintlocks:
##
##   hold LMB   raise the weapon and wind up; the arc (ThrowableArc) and the
##              centre aim dot show where it will land. Power builds over
##              `windup_time`; a quick click still throws once `min_windup` has
##              passed, weaker and less accurate.
##   release    throw. The object leaves the hand `release_time` after the
##              release (the frame the throw animation lets go), then the arm
##              follows through and the next one is taken from the back, the belt
##              or the dart bundle.
##   RMB / R    while holding LMB: lower the weapon without throwing (a new LMB
##              press is needed to raise it again).
##   sprint     lets the throw down, like the bow.
##
## The throw is "zeroed" like the arrows: at full power it leaves on the arc that
## lands on the aim point (Weapon.ballistic_dir), from where the object actually is
## in the hand, so it flies out of the hand on screen (point blank the direction is taken
## from the hand, _throw_dir; the first flight step checks from the hand too, so nothing
## closer than the point is passed through). Thrown weapons stick in wood,
## straw, targets and soft ground (ThrownProjectile) and are picked up again by
## walking over them or pressing E near them (ThrownPickup). Only `count` are carried
## (`max_count`). throw_phase() names the cycle: idle, aiming, throwing, recovering, empty.
##
## Animation contract (see source/graph_analysis/throwables/
## throwables_design.md, section 3). Signals are the ones every Weapon has:
##   action_started("equip", equip_time)
##   action_started("throw", release_time + follow_time)   release-start -> release-end,
##                     played at throw_anim_rate(); the object leaves the hand at release_time
##                     (RELEASE_PHASE of the joined clips); `fired` and `thrown` fire on that frame
##   action_started("draw", draw_time)    take the next spear / tomahawk / dart
##   action_cancelled                     cancel (RMB/R), sprint, weapon switch
##   fired + thrown(projectile)           the frame the object leaves the hand
##   aim (0..1) and charge_amount()       raise into the cocked pose / wind-up
## With `wait_for_anim_release` the weapon instead waits for the animation to call
## release_from_animation() (with a timeout), for an event-driven release frame.
##
## The throw clips of the source library do not key the right-hand prop bone
## (tests/throwables/survey_throw_clips.gd), so the held object is placed here: in the
## fist, oriented in character space for the carry (or in the fist, `carry_in_fist`) and
## along the throw line while aimed (`_place_held`, run after the skeleton update like the
## bow's nocked arrow).
## The fist (THROW2) is the palm's final pose times the grip: the prop bone's pose relative to
## the palm in the weapon's grip clip (`grip_clip_carry` / `grip_clip_aim`, read from the Actor_B
## library), which is where the hand's grip layer puts the prop bone in the carry and aim poses.
## It is not the prop bone itself: the draw, holster, grab and finish clips of a weapon switch
## key that bone along their own object's path (the long-gun draw starts with it behind the left
## shoulder, up to 0.7 m from the right palm), so an object placed on it trailed away from the
## hand whenever a switch played (user playtest 2026-09-25).
## THROW2 review: `switch_path` sets where the object is through a switch's draw and holster: in the
## fist (FIST), on the draw clip's own object path until the hand has it (SOURCE: the spear from its
## sling, as the long gun), or in the fist stood up at the belt (STOW: the tomahawk). The aimed pose
## blends in from a body-space carry reference held while the aim rises (RefState), so the wind-up
## turn is uniform in time however the fist turns.

enum State { READY, WINDUP, HOLDING, RELEASING, RECOVER, DRAWING, EMPTY }
## The throw cycle in five steps, for the HUD, AI and the animation layer (`state` has the
## finer steps):
##   IDLE        ready, nothing raised                               (READY)
##   AIMING      winding up, or holding the wind-up                  (WINDUP, HOLDING)
##   THROWING    released; the arm comes through until the object leaves the hand (RELEASING)
##   RECOVERING  follow-through, then taking the next one            (RECOVER, DRAWING)
##   EMPTY       none carried; walk over a thrown one to get it back (EMPTY)
enum Phase { IDLE, AIMING, THROWING, RECOVERING, EMPTY }
const PHASE_NAMES: Array[String] = ["idle", "aiming", "throwing", "recovering", "empty"]

## The player lowered a raised throw without throwing (RMB or R while holding LMB, or sprint).
signal throw_cancelled
## throw_phase() changed (checked after every tick, equip and unequip).
signal phase_changed(phase: Phase)
## The object left the hand (same frame as `fired`).
signal thrown(projectile: ThrownProjectile)
## Sound hook (ThrowableAudio; WeaponAudio must skip throwables): &"windup" when the throw is raised,
## &"cancel" when it is lowered, &"release" as it leaves the hand, &"draw" when the next
## one is taken, &"empty" on LMB with none left, &"pickup" when one is picked up again.
signal sfx(id: StringName, at: Vector3)

const ACTION_THROW := "throw"
const ACTION_DRAW := "draw"
## Actor_B release-start (0.2 s) + release-end (0.6 s), stand and crouch, at 1x.
const THROW_CHAIN_LEN := 0.8
## Measured on Actor_B (tests/throwables/survey_throw_clips.gd): the hand is fastest in
## the first key interval of release-end (0.2-0.3 s into the chain, peak 11.5 m/s stand,
## 8.8 m/s crouch), so the object leaves the hand at 0.25 s = 0.3125 of the chain.
const RELEASE_PHASE := 0.3125

@export_group("Throw")
@export var ammo_kind := "spear"          ## Pickup / count key.
@export var model_kind := "spear"         ## ThrowableModels kind held in the hand.
@export var projectile_kind := "spear"    ## ThrowableModels kind that flies.
@export var windup_time := 0.5            ## LMB held: seconds to full power.
@export var min_windup := 0.12            ## A click throws once this much wind-up has passed.
@export var release_time := 0.25          ## Throw start -> the object leaves the hand.
@export var follow_time := 0.55           ## Follow-through after the release.
@export var draw_time := 0.6              ## Taking the next one.
@export var fatigue_start := 3.0          ## Seconds held at full wind-up before the arm trembles.
@export var fatigue_full := 7.0

@export_group("Flight")
@export var min_speed := 12.0
@export var max_speed := 20.0
@export var flight_gravity := 9.8
@export var flight_drag := 0.02
@export var min_damage := 40.0
@export var max_damage := 100.0

@export_group("Carry")
@export var count := 2
@export var max_count := 2

@export_group("Spread")
@export var spread_undercharge := 3.0
@export var spread_fatigue := 1.5

@export_group("Held pose")
## Carry (not aiming), in character space: yaw/pitch/roll in degrees of the model's
## -Z (forward) and +Y (up) relative to the character's forward and up.
@export var carry_rot_deg := Vector3(-12.0, 0.0, 0.0)
@export var carry_offset := Vector3.ZERO           ## Character space, from the hand.
@export var aim_offset := Vector3.ZERO             ## Character space, from the hand, while aimed.
## THROW2: the carry orientation is taken in the fist (fist_basis turns the model's axes into the
## grip's prop axes; carry_rot_deg is then unused) instead of in character space: the object turns
## with the hand (the tomahawk's haft runs through the fist).
@export var carry_in_fist := false
## Model axes -> fist axes (the grip clip's prop frame) for carry_in_fist.
@export var fist_basis := Basis.IDENTITY
## Extra rotation (degrees, about the character's right axis) of the aimed pose: + tilts
## the model's -Z up. Spear/dart 0: along the throw line.
@export var aim_tilt_deg := 0.0
## THROW2 review: the character-space carry (carry_rot_deg) turns toward carry_low_rot_deg as the hand
## drops below the right shoulder: not at all while the fist is less than carry_low_band.x m below it,
## fully from carry_low_band.y m (Vector2.ZERO: off); standing only (it fades out over CROUCH_FADE_S as the
## body crouches: crouched, the hand is only low in a switch, where the port would turn the point across
## the face). The spear is held level in the overhand javelin carry and at port (point up and across the
## body) when the arm is lowered: the graph's pick-up sprint arm, a draw's hand-over, an arm swinging
## through a jump.
@export var carry_low_rot_deg := Vector3.ZERO
@export var carry_low_band := Vector2.ZERO
## THROW2 fix 2: the lowered carry fades back out as the fist goes behind the right shoulder: fully out once it
## is carry_low_back.y m behind it, starting at carry_low_back.x (Vector2.ZERO: off). An arm swinging back
## through a jump carries the object level, not at port (the port's point went through the head).
@export var carry_low_back := Vector2.ZERO
## Seconds for the lowered carry's weight to swing fully in or out (0: it follows the fist at once, which
## snapped the object round in one frame when the arm dropped fast at a jump's take-off).
@export var carry_low_time := 0.0
## The lowered carry also holds while crouched (the spear: with the felling axe's carry arm the fist hangs low crouched too).
@export var carry_low_crouched := false
## The carry (level and lowered) turns about the character's up with this fraction of the hips' yaw (the line
## between the hip joints), low-passed over carry_follow_time s: the body turns into strafes and diagonal runs,
## so a carry fixed to the character's facing crossed the legs or the chest there. 0: off.
@export var carry_follow_hips := 0.0
@export var carry_follow_time := 0.15

@export_group("Switch")
## Where the object is while a weapon switch draws or holsters it and while the throw cycle takes the
## next one (THROW2 review):
##   FIST    in the fist, with the carry orientation, in every stage.
##   SOURCE  on the draw clip's own object path (the prop bone: the long gun the clip draws, slung on the
##           back and swung over the shoulder) until the right hand has it, then in the fist; turned like
##           that object (its muzzle = the object's point) and handing over to the carry orientation over
##           switch_blend of the draw. A holster runs the same path backwards. A draw shows the object once
##           that path has it on the back (at the sling); when the draw never takes it there (the throw
##           cycle's draw, whose arm starts from the throw's follow-through with the chest still twisted by
##           the recover; some crouched draws), the object is in the hand from source_fallback_from on, with
##           the carry orientation.
##   STOW    in the fist, turned to the stow orientation (stow_up / stow_edge, character space) while the
##           hand is at the belt, handing over to the carry orientation over switch_blend of the draw.
## The hand-overs keep their path continuous from frame to frame (THROW2 fix 2: a shortest-path slerp between
## orientations about a half turn apart flipped the object in one frame): SOURCE moves the object's point along
## the great circle from the source line to the carry line and turns it about its own axis separately (a long
## shaft's line is what reads); STOW keeps the quaternion signs continuous and uses slerpni.
enum SwitchPath { FIST, SOURCE, STOW }
@export var switch_path := SwitchPath.FIST
## Draw phase (0..1; a holster runs it from 1 back to 0) over which the switch orientation hands over to the
## carry orientation (smoothstep).
@export var switch_blend := Vector2(0.55, 1.0)
## SOURCE: prop-to-fist distances (m): nearer than .x the object is in the fist, farther than .y on the
## source path (smoothstep between).
@export var source_near := Vector2(0.06, 0.15)
## SOURCE: where the hand holds the object on the source path, metres from the model origin toward +Z (the
## butt). A long gun's grip sits near its butt, so an object held this far back swings over the shoulder and
## comes across the body as the gun does. The hold moves out from the origin (the balance point) over
## source_hold_in of the draw (slung on the back the object hangs from its balance point) and slides back to
## it as the orientation hands over to the carry (switch_blend).
@export var source_hold := 0.0
@export var source_hold_in := Vector2(0.25, 0.43)
## SOURCE, crouched (blended in by the crouch weight): the hold and its phase window (< 0: the standing ones).
## Crouched the long gun's own path goes through the lap, so the object is held nearer its butt, later.
@export var source_hold_crouch := -1.0
@export var source_hold_in_crouch := Vector2(-1.0, -1.0)
## SOURCE: a draw shows the object once the draw's own object is at the sling: at least source_show (m) from the
## fist, behind the upper spine and at least source_sling_up (m) up the torso (the pelvis -> spined line).
@export var source_show := 0.5
@export var source_sling_up := 0.25
## SOURCE: a draw that has not taken its object to the sling by this phase shows it in the hand, on the carry.
@export var source_fallback_from := 0.5
## SOURCE, crouched: that in-hand object shows only once the fist is less than this (m) below the right shoulder
## (the crouched draw's hand passes through the lap first). < 0: off.
@export var source_fallback_drop_crouch := -1.0
## STOW: character-space directions (x right, y up, z forward) of the model's +Y and -Z at the belt.
@export var stow_up := Vector3.UP
@export var stow_edge := Vector3.LEFT
## STOW: a draw shows the object once the fist is at the back of the belt, this far (m) behind the pelvis; a
## draw whose fist never gets there (the throw cycle's next tomahawk, from the follow-through) shows it in the
## fist from source_fallback_from on.
@export var stow_behind := 0.03

@export_group("Animation")
@export var wait_for_anim_release := false
@export var anim_release_timeout := 0.2
## The hand's grip (THROW2): Actor_B clips whose prop-bone key, relative to the palm, is where the
## grip layer holds the object: in the carry (at grip_sample_carry s) and while aimed / throwing (the
## graph's pick-up grip, p-fingers-brick, on the aim trees and the throw chain).
@export var grip_clip_carry := "actor_b-p-fingers-brick"
@export var grip_sample_carry := 0.0
@export var grip_clip_aim := "atk-actor_b-knife-v-thug-hit1-intro"
## The fist the right hand keeps on the object while it is in the hand (HeldFist; user 2026-10-03: the throwables held
## as the saber is, the fingers closed through the wind-up and the throw instead of the graph's open brick grip): the
## fingers and the thumb of `fist_clip` at `fist_sample` s, the same knife grip the aim now holds the object in
## (grip_clip_aim), so the fingers close on it.
@export var fist_clip := "atk-actor_b-knife-v-thug-hit1-intro"
@export var fist_sample := 0.0

var state := State.READY
var charge := 0.0
var hold_time := 0.0
## Test / AI hook: when true, `scripted_input` replaces the mouse ({"fire": held,
## "cancel": pressed this tick}); "cancel" is consumed when read.
var use_scripted_input := false
var scripted_input := {}
## The BoneAttachment3D the model hangs under (set by ThrowableKit.install).
var socket: Node3D
## The last projectile thrown (tests, HUD).
var last_thrown: ThrownProjectile

var _t := 0.0
var _queued_release := false
var _wait_fire_release := false
var _release_charge := 0.0
var _phase_left := 0.0
var _phase_len := 0.0
var _anim_released := false
var _aim_dir := Vector3.FORWARD
var _hand_bone := -1
var _palm_bone := -1
## Hand prop bone position (skeleton space) on the last final pose, read in
## Skeleton3D.skeleton_updated after the skeleton's modifiers (the AimStabilizer turns the upper body
## over the locomotion); the pose read outside that signal is the one before the modifiers. INF
## until the first update.
var _hand_final := Vector3.INF
## The palm's final pose (skeleton space), read with _hand_final; the fist is this times the grip.
var _palm_final := Transform3D()
var _palm_ok := false
## Grip transforms (prop bone relative to the palm) of grip_clip_carry / grip_clip_aim; null until
## read (_grips()), {} when the library or the clip's prop track is not there (the prop bone is used).
var _grip := {}
## clip|hand|time -> Transform3D (found grips only), shared by every throwable.
static var _grip_cache := {}
## Last time (ms) the grips were looked for and not found: a rig without the Actor_B library is
## searched again at most once a second, not on every frame.
var _grip_retry_ms := 0
var _placed := false
var _last_phase := Phase.IDLE
## The prop bone's final pose (skeleton space; SOURCE path) and the right shoulder's final position
## (skeleton space; carry_low_band), read with _palm_final.
var _prop_final := Transform3D()
var _shoulder_bone := -1
var _shoulder_final := Vector3.ZERO
## Carry orientation in body space that the aimed pose is blended from (THROW2 review), `_ref`:
##   IN_FIST    the live carry (aim 0).
##   HELD       held from the frame the aim leaves 0 while it rises or stays up: a carry that turns with the
##              fist (the tomahawk's) would otherwise add the fist's own turn to the aim-in, which snapped
##              the model round in its first frames; the blend into the aimed pose is uniform in time.
##   RETURNING  the let-down: from the held carry back into the live one, as the fist comes back near the
##              held carry (within REF_NEAR degrees: fully at .x, starting at .y) or over REF_LATE_S once the
##              aim is down, whichever is first; the model is back in the fist then. Handing over as the aim
##              falls would first turn the object with the cocked fist (the arm is still wound up while the
##              aim falls) and whip it round (up to 250 deg in the crouch).
## Quaternion signs are kept continuous from frame to frame and the blends use slerpni, so the model never
## flips to the other way round when the carry and the aimed pose are about a half turn apart.
enum RefState { IN_FIST, HELD, RETURNING }
const REF_NEAR := Vector2(15.0, 50.0)
const REF_LATE_S := 0.35
var _ref_state := RefState.IN_FIST
var _ref := Quaternion.IDENTITY
var _ref_from := Quaternion.IDENTITY
var _ref_back := 0.0
var _ref_late := 0.0
var _ref_aim := 0.0
var _q_live_prev := Quaternion.IDENTITY
var _q_ref_prev := Quaternion.IDENTITY
var _q_aim_prev := Quaternion.IDENTITY
## Holster: the draw phase the holster starts from (1 when the weapon was drawn) and whether the object was
## in the hand when the switch put it away (player.gd shows the model through the holster only then).
var _holster_from := 1.0
var _holster_shown := true
## 0 standing .. 1 crouched, eased over CROUCH_FADE_S (carry_low_band).
const CROUCH_FADE_S := 0.3
var _crouch_w := 0.0
## SOURCE draw: the draw's own object has been at the sling in this draw (_src_seen); it has not by
## source_fallback_from, so the object is in the hand on the carry (_src_fallback); crouched, that in-hand
## object has been shown (_fb_shown).
var _src_seen := false
var _src_fallback := false
var _fb_shown := false
## SOURCE draw: the draw phase the object showed at the sling (the hold's window starts no earlier).
var _src_seen_sw := 0.0
## Final-pose bones for the sling test and the hips' yaw (skeleton space), read with _palm_final.
var _pelvis_bone := -1
var _spined_bone := -1
var _hip_l_bone := -1
var _hip_r_bone := -1
var _pelvis_final := Vector3.ZERO
var _spined_final := Vector3.ZERO
var _hip_l_final := Vector3.ZERO
var _hip_r_final := Vector3.ZERO
## Per-frame carry state (advanced once per rendered frame, _advance_carry): the low-passed hips' yaw
## (carry_follow_hips), the rate-limited lowered-carry weight (carry_low_time), whether they are primed.
var _hips_yaw := 0.0
var _port_w := 0.0
var _carry_primed := false
var _carry_frame := -1
## Switch hand-over continuity (see SwitchPath): SOURCE's twist about the object's axis, STOW's quaternions.
var _sw_phi := 0.0
var _sw_phi_set := false
var _sw_blending := false
## SOURCE holster: the object turned a half turn about its own axis on the drawn object's path (decided once).
var _src_flip := false
var _src_flip_decided := false
var _sw_u_prev := -1.0
var _q_sw_src := Quaternion.IDENTITY
var _q_sw_car := Quaternion.IDENTITY
## Aim carried over a weapon switch (THROW2 fix 2): Weapon.unequip() zeroes `aim` at once, but PlayerAnim keeps
## the arm's aim weight and lowers it over tuning weapon_fade_s, so the object follows the arm down with it.
var _held_aim := 0.0
var _held_fist: HeldFist
const HELD_AIM_FADE_S := 0.25


func _ready() -> void:
	add_to_group(&"throwables")


func _init() -> void:
	hand = Hand.RIGHT
	busy_speed_mult = 0.7
	spread_base = 0.4
	spread_move = 3.0
	spread_air = 8.0
	crouch_mult = 0.7
	spread_unaimed = 0.0
	fire_bloom = 1.0
	aim_in_time = 0.18
	aim_out_time = 0.3
	# Current (pre-rebuild) clip tables, like the other weapons. The graph-driven
	# PlayerAnim reads its own profile (design doc section 3); these name the same clips.
	relaxed = {
		"idle": ["actor_b-p-1h-arm--part", 1.0],
		"walk": ["actor_b-p-1h-arm--part", 1.0],
		"run": ["actor_b-p-1h-arm--part", 1.0],
		"sprint": ["actor_b-p-1h-arm--part", 1.0],
		"crouch_idle": ["actor_b-p-1h-arm-crouch--part", 1.0],
		"crouch_walk": ["actor_b-p-1h-arm-crouch--part", 1.0],
	}
	clips = {
		"aim": "actor_b-p-1h-aim-throw-idle",
		"aim_crouch": "actor_b-p-1h-aim-crouch-throw-idle",
		"aim_walk": "actor_b-p-1h-aim-walk",
		"aim_walk_crouch": "actor_b-p-1h-aim-crouch-walk",
		"up": "actor_b-p-1h-aim-throw--add-up",
		"down": "actor_b-p-1h-aim-throw--add-down",
		"up_crouch": "actor_b-p-1h-aim-throw-crouch--add-up",
		"down_crouch": "actor_b-p-1h-aim-throw-crouch--add-down",
		"hands": "actor_b-p-fingers-brick",
		"hands_crouch": "actor_b-p-fingers-brick",
		# Standing blocked-aim is null for Actor_B in the graph; only the crouched pose exists.
		"blocked_crouch": "actor_b-p-1h-aim-crouch-throw^aim--blocked",
		"raise": "actor_b-p-1h-aim-throw^aim",
		"raise_crouch": "actor_b-p-1h-aim-crouch-throw^aim",
		"throw": "actor_b-p-1h-aim-throw-release-start",
		"throw_crouch": "actor_b-p-1h-aim-crouch-throw-release-start",
		"throw_end": "actor_b-p-1h-aim-throw-release-end",
		"throw_end_crouch": "actor_b-p-1h-aim-crouch-throw-release-end",
		"recover": "actor_b-p-1h-aim-throw-release-end^idle",
		"recover_crouch": "actor_b-p-1h-aim-crouch-throw-release-end^idle",
		"equip": "actor_b-p-molotov-draw^idle--part",
		"draw": "actor_b-p-molotov-draw^idle--part",
	}


# --- Weapon overrides ---------------------------------------------------------------

## Where the weapon is in the throw cycle (see Phase).
func throw_phase() -> Phase:
	match state:
		State.WINDUP, State.HOLDING:
			return Phase.AIMING
		State.RELEASING:
			return Phase.THROWING
		State.RECOVER, State.DRAWING:
			return Phase.RECOVERING
		State.EMPTY:
			return Phase.EMPTY
	return Phase.IDLE


## "idle", "aiming", "throwing", "recovering" or "empty".
func throw_phase_name() -> String:
	return PHASE_NAMES[throw_phase()]


func is_winding() -> bool:
	return state == State.WINDUP or state == State.HOLDING


func wants_aim() -> bool:
	return active and (is_winding() or state == State.RELEASING)


func is_busy() -> bool:
	return is_winding() or state == State.RELEASING


## Sprinting lets a raised throw down; only the throw itself blocks it.
func can_sprint() -> bool:
	return state != State.RELEASING


func charge_amount() -> float:
	return charge if is_winding() else 0.0


## 0..1: how much the arm trembles from holding the wind-up.
func fatigue() -> float:
	if state != State.HOLDING:
		return 0.0
	return clampf((hold_time - fatigue_start) / maxf(fatigue_full - fatigue_start, 0.01), 0.0, 1.0)


## Speed the object leaves the hand with if released now (the arc uses it too).
func throw_speed() -> float:
	var c := _release_charge if state == State.RELEASING else charge
	if state == State.READY:
		c = min_windup / windup_time
	return lerpf(min_speed, max_speed, ease(clampf(c, 0.0, 1.0), 0.7))


func throw_damage() -> float:
	var c := _release_charge if state == State.RELEASING else charge
	return lerpf(min_damage, max_damage, ease(clampf(c, 0.0, 1.0), 0.6))


## Playback rate for the release-start + release-end chain so its release frame lands on
## release_time. With follow_time = release_time * (1 / RELEASE_PHASE - 1) the chain also
## ends exactly when the "throw" action does.
func throw_anim_rate() -> float:
	return THROW_CHAIN_LEN * RELEASE_PHASE / maxf(release_time, 0.01)


## Takes up to `n` more (never past max_count; none, and none lost, when count is already
## over it). Returns how many were taken.
func add_items(n: int) -> int:
	var took := clampi(n, 0, maxi(max_count - count, 0))
	count += took
	return took


## A thrown one coming back (ThrownPickup): `model` the ThrowableModels kind it flew as, `grade` its made standard.
## Here as add_items(); ThrowableSpear keeps which head came back.
func add_items_from(n: int, _model: String, _grade := "") -> int:
	return add_items(n)


func can_take(kind: String) -> bool:
	return kind == ammo_kind and count < max_count


## For the trajectory arc (ThrowableArc): {origin, velocity, gravity, drag} while the
## throw is raised, else {}.
func trajectory_params() -> Dictionary:
	if not active or not is_winding() or player == null:
		return {}
	var origin := launch_origin()
	var dir := _throw_dir(origin, player.get_aim_point())
	return {"origin": origin, "velocity": dir * throw_speed(), "gravity": flight_gravity, "drag": flight_drag}


## Where the throw leaves from: the centre of mass of the object in the hand.
func launch_origin() -> Vector3:
	var node := _thrown_node()
	if node and _placed:
		return node.global_transform * _com_local()
	if muzzle and muzzle.is_inside_tree():
		return muzzle.global_position
	return player.global_position + Vector3.UP * 1.5


## Event-driven release (wait_for_anim_release): the animation calls this on the frame
## the object leaves the hand.
func release_from_animation() -> void:
	if state == State.RELEASING:
		_anim_released = true


func status_text() -> String:
	match state:
		State.WINDUP: return "Winding up  (RMB/R: lower)"
		State.HOLDING: return ("Trembling" if fatigue() > 0.0 else "Ready to throw") + "  (RMB/R: lower)"
		State.RELEASING, State.RECOVER: return "Thrown"
		State.DRAWING: return "Taking the next"
		State.EMPTY: return "None left - pick them up"
	return "Ready"


func ammo_text() -> String:
	return "%d / %d" % [count, max_count]


func progress() -> Array:
	if is_winding():
		return ["Wind-up", charge]
	if state == State.DRAWING:
		return ["Taking", 1.0 - _phase_left / maxf(_phase_len, 0.01)]
	return []


# --- Tick ---------------------------------------------------------------------------

func _on_equip() -> void:
	_ref_state = RefState.IN_FIST
	_held_aim = 0.0
	_reset_draw_flags()
	_carry_primed = false
	_crouch_w = 1.0 if player.is_crouching else 0.0
	_connect_skeleton()
	if count <= 0:
		state = State.EMPTY
	_update_visibility()
	_sync_phase()


## Weapon.unequip() zeroes `aim` before _on_unequip(): keep it first, so the held pose follows the arm down over
## HELD_AIM_FADE_S (PlayerAnim carries the arm's aim weight over the switch the same way) instead of snapping from
## the wind-up to the carry in one frame (0.6 m and up to 171 deg before THROW2 fix 2).
func unequip() -> void:
	_held_aim = clampf(aim, 0.0, 1.0) if active else 0.0
	super()


func _on_unequip() -> void:
	# Before the state changes: whether the object is in the hand (a switch holsters the model only then:
	# none when all were thrown, or right after a throw) and the draw phase a holster starts from. The carry
	# reference stays as it is while an aim is carried over (it lets the held pose down from there).
	if _held_aim <= 0.0:
		_ref_state = RefState.IN_FIST
	_src_flip = false
	_src_flip_decided = false
	_holster_shown = _object_in_hand()
	_holster_from = 1.0
	if _equip_left > 0.0 and equip_time > 0.0:
		_holster_from = clampf(1.0 - _equip_left / equip_time, 0.0, 1.0)
	elif state == State.DRAWING and _phase_len > 0.0:
		_holster_from = clampf(1.0 - _phase_left / _phase_len, 0.0, 1.0)
	match state:
		State.WINDUP, State.HOLDING, State.RELEASING:
			charge = 0.0
			_queued_release = false
			state = State.READY if count > 0 else State.EMPTY
		State.RECOVER, State.DRAWING:
			# Finish taking the next one off-screen.
			state = State.READY if count > 0 else State.EMPTY
	_update_visibility()
	_sync_phase()


func _sync_phase() -> void:
	var ph := throw_phase()
	if ph != _last_phase:
		_last_phase = ph
		phase_changed.emit(ph)


func _tick(delta: float) -> void:
	_t += delta
	_crouch_w = move_toward(_crouch_w, 1.0 if player.is_crouching else 0.0, delta / CROUCH_FADE_S)
	# The body moved this physics tick (move_and_slide runs before the weapon ticks): place the object
	# in the fist at the body's new transform first, so a release this tick leaves from the hand.
	_place_held()
	var fire := _fire_held()
	var cancel := _cancel_pressed()
	var can_wind := not player.is_sprinting and not is_equipping()
	match state:
		State.READY:
			if not fire:
				_wait_fire_release = false
			if fire and can_wind and not _wait_fire_release:
				_start_windup()
		State.WINDUP:
			hold_time = 0.0
			charge = minf(charge + delta / windup_time, 1.0)
			if cancel or player.is_sprinting:
				_cancel()
			elif not fire or _queued_release:
				if charge * windup_time >= min_windup:
					_begin_release()
				else:
					_queued_release = true
			elif charge >= 1.0:
				state = State.HOLDING
		State.HOLDING:
			hold_time += delta
			if cancel or player.is_sprinting:
				_cancel()
			elif not fire:
				_begin_release()
		State.RELEASING:
			_phase_left -= delta
			var due := _phase_left <= 0.0
			if wait_for_anim_release:
				due = _anim_released or _phase_left <= -anim_release_timeout
			if due:
				_release()
		State.RECOVER:
			_phase_left -= delta
			if _phase_left <= 0.0:
				if count > 0:
					_start_draw()
				else:
					state = State.EMPTY
		State.DRAWING:
			_phase_left -= delta
			if _phase_left <= 0.0:
				state = State.READY
				if fire and can_wind and not _wait_fire_release:
					_start_windup()
		State.EMPTY:
			if fire and not _wait_fire_release:
				_wait_fire_release = true
				_emit_sfx(&"empty")
			if not fire:
				_wait_fire_release = false
			if count > 0:
				_start_draw()
	if is_winding() or state == State.RELEASING:
		var origin := launch_origin()
		_aim_dir = _throw_dir(origin, player.get_aim_point())
	_update_visibility()
	_place_held()
	_sync_phase()


func _extra_spread() -> float:
	var c := charge
	if not is_winding():
		c = _release_charge if state == State.RELEASING else min_windup / windup_time
	return spread_undercharge * pow(1.0 - c, 2.0) + spread_fatigue * fatigue()


func _fire_held() -> bool:
	if use_scripted_input:
		return bool(scripted_input.get("fire", false))
	return _fire_input_enabled() and Input.is_action_pressed("fire")


func _cancel_pressed() -> bool:
	if use_scripted_input:
		var c := bool(scripted_input.get("cancel", false))
		scripted_input["cancel"] = false
		return c
	return (_aim_input_enabled() and Input.is_action_just_pressed("aim")) or (_fire_input_enabled() and Input.is_action_just_pressed("reload"))


# --- Steps --------------------------------------------------------------------------

func _start_windup() -> void:
	charge = 0.0
	hold_time = 0.0
	_queued_release = false
	state = State.WINDUP
	_emit_sfx(&"windup")


func _cancel() -> void:
	charge = 0.0
	_queued_release = false
	_wait_fire_release = true
	state = State.READY
	throw_cancelled.emit()
	action_cancelled.emit()
	_emit_sfx(&"cancel")


func _begin_release() -> void:
	_release_charge = charge
	_queued_release = false
	_anim_released = false
	state = State.RELEASING
	_phase_len = release_time
	_phase_left = release_time
	action_started.emit(ACTION_THROW, release_time + follow_time)


func _release() -> void:
	var overshoot := maxf(-_phase_left, 0.0) if not wait_for_anim_release else 0.0
	last_thrown = _launch_thrown()
	count -= 1
	charge = 0.0
	hold_time = 0.0
	state = State.RECOVER
	_phase_len = follow_time
	_phase_left = follow_time - overshoot
	_emit_sfx(&"release")


func _start_draw() -> void:
	_reset_draw_flags()
	state = State.DRAWING
	_phase_len = draw_time
	_phase_left = draw_time
	action_started.emit(ACTION_DRAW, draw_time)
	_emit_sfx(&"draw")


func _emit_sfx(id: StringName) -> void:
	var at := model.global_position if model and model.is_inside_tree() else player.global_position + Vector3.UP
	sfx.emit(id, at)


## Zeroed throw direction from `origin` (the centre of mass of the object in the hand) to
## `target`. The held pose is turned along this direction, and the centre of mass sits off
## the hand (a seated dart's about 0.45 m out, up to 1 m once the atlatl's flick has swung
## it; a tomahawk's 0.3 m up the haft), so where the aim point is about as close as that,
## aiming from the object chases its own pose round and can throw it sideways or back.
## Point blank the direction is taken from the hand instead: from the hand within twice
## that offset, from the object beyond four times, blended between. (The spear is held at
## its balance point: always from the object.)
func _throw_dir(origin: Vector3, target: Vector3) -> Vector3:
	var d := ballistic_dir(origin, target, max_speed, flight_gravity, flight_drag)
	if player == null or player.skeleton == null or _hand_bone < 0:
		return d
	var hand := _hand_pos()
	var r := origin.distance_to(hand)
	if r < 0.05:
		return d
	var t := clampf((hand.distance_to(target) - 2.0 * r) / (2.0 * r), 0.0, 1.0)
	if t >= 1.0:
		return d
	var dh := ballistic_dir(hand, target, max_speed, flight_gravity, flight_drag)
	return dh.slerp(d, t).normalized()


## Spawns the projectile at the object's centre of mass, zeroed on the aim point.
func _launch_thrown() -> ThrownProjectile:
	var origin := shot_origin(launch_origin())   # (not from beyond a wall the hand reached through: Weapon.shot_origin())
	var target := player.get_aim_point()
	var dir := _throw_dir(origin, target)
	dir = apply_spread(dir, deg_to_rad(spread))
	var speed := throw_speed()
	var p := ThrownProjectile.new()
	p.kind = ammo_kind
	p.model_kind = projectile_kind
	p.velocity = dir * speed
	p.gravity = flight_gravity
	p.drag = flight_drag
	p.damage = throw_damage()
	p.exclude = [player.get_rid()]
	p.shooter = player
	# The point is out past the hand: the first step checks from the hand (no tunnelling
	# through a wall, a tree or the ground closer than the point).
	p.sweep_from = _hand_pos()
	_configure_projectile(p, origin, dir, speed)
	player.get_tree().current_scene.add_child(p)
	p.launch(origin, dir, _launch_basis(dir))
	_bloom += fire_bloom
	fired.emit()
	thrown.emit(p)
	NetSession.shot(player, p, true)        # (the others see it fly)
	return p


# --- Overridables -------------------------------------------------------------------

## Called once by ThrowableKit.install after `model` is set (the atlatl adds its dart).
func _setup_model() -> void:
	pass


## Per-weapon flight setup (spin, reach, stick rules).
func _configure_projectile(_p: ThrownProjectile, _origin: Vector3, _dir: Vector3, _speed: float) -> void:
	pass


## World basis of the projectile model at launch. Default: model -Z along the flight.
func _launch_basis(dir: Vector3) -> Basis:
	return Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK)


## The node that is thrown (its COM marker is the launch point). Default: the model.
func _thrown_node() -> Node3D:
	return model


func _com_local() -> Vector3:
	var node := _thrown_node()
	return ThrowableModels.marker_pos(node, "COM") if node else Vector3.ZERO


## Extra rotation of the aimed pose during the release (0..1 through release_time), in
## degrees about the character's right axis (+ = model -Z rotates up). Tomahawk / atlatl.
func _release_swing_deg(_u: float) -> float:
	return 0.0


## Whether the thrown object is visible in the hand right now. Taking the next one shows it from the draw's
## first frame when the switch path places it where the draw takes it from (SOURCE: once on the back; STOW: at
## the belt), else from the draw's middle.
func _object_in_hand() -> bool:
	if _source_waiting():
		return false
	match state:
		State.RECOVER, State.EMPTY:
			return false
		State.DRAWING:
			return switch_path != SwitchPath.FIST or _phase_left <= _phase_len * 0.5
	return count > 0


## SOURCE / STOW: a draw before its own object has been at the sling (the fist at the back of the belt); after
## source_fallback_from the object is in the hand instead (crouched: once the fist is up near the shoulder,
## source_fallback_drop_crouch).
func _source_waiting() -> bool:
	if switch_path == SwitchPath.FIST or _src_seen or not active:
		return false
	var sw := _switch_phase()
	if sw < 0.0:
		return false
	if not _src_fallback:
		return true
	return source_fallback_drop_crouch >= 0.0 and _crouch_w > 0.5 and not _fb_shown


func _reset_draw_flags() -> void:
	_src_seen = false
	_src_seen_sw = 0.0
	_src_fallback = false
	_fb_shown = false
	_src_flip = false
	_src_flip_decided = false


## player.gd, weapon switch: whether the holster shows this weapon's model (it was in the hand when the
## switch put the weapon away; not with none left, nor right after a throw).
func holster_shows_model() -> bool:
	return _holster_shown


## player.gd, death: whether the dead player's hand keeps this weapon's model (THROW2 fix 2). A spear or a
## tomahawk falls from the hand: in a dying body's fist it lay through the corpse (and one caught in a switch's
## holster snapped into the fist); the atlatl's board stays, like the firearms.
func death_shows_model() -> bool:
	return false


func _exit_tree() -> void:
	if _held_fist != null and is_instance_valid(_held_fist):
		_held_fist.queue_free()
	_held_fist = null


## Whether the right hand is closed on the weapon now (HeldFist): the weapon out and its object in the hand.
func fist_held() -> bool:
	return active and not is_queued_for_deletion() and _object_in_hand()


func _update_visibility() -> void:
	if model:
		model.visible = active and _object_in_hand()


# --- Held placement -----------------------------------------------------------------

func _connect_skeleton() -> void:
	if player == null or player.skeleton == null:
		return
	var sk := player.skeleton
	if _hand_bone < 0:
		_hand_bone = sk.find_bone("r_hand_prop_attachment" if hand == Hand.RIGHT else "l_hand_prop_attachment")
		_palm_bone = sk.get_bone_parent(_hand_bone) if _hand_bone >= 0 else -1
		_shoulder_bone = sk.find_bone("r_shoulder" if hand == Hand.RIGHT else "l_shoulder")
		_pelvis_bone = sk.find_bone("pelvis")
		_spined_bone = sk.find_bone("spined")
		_hip_l_bone = sk.find_bone("l_upper_leg")
		_hip_r_bone = sk.find_bone("r_upper_leg")
	if model:
		model.top_level = true
	if _held_fist == null and hand == Hand.RIGHT:
		var ap := _anim_player()
		var path := StringName("actor_b/" + fist_clip)
		if ap != null and ap.has_animation(path):
			_held_fist = HeldFist.install(sk, ap.get_animation(path), fist_sample, fist_held)
	if not sk.skeleton_updated.is_connected(_on_skeleton_updated):
		sk.skeleton_updated.connect(_on_skeleton_updated)


## The final pose of this frame: remember the hand, then place the held object on it.
func _on_skeleton_updated() -> void:
	var sk := player.skeleton if player else null
	if sk != null and _hand_bone >= 0:
		_prop_final = sk.get_bone_global_pose(_hand_bone)
		_hand_final = _prop_final.origin
		if _palm_bone >= 0:
			_palm_final = sk.get_bone_global_pose(_palm_bone)
			_palm_ok = true
		if _shoulder_bone >= 0:
			_shoulder_final = sk.get_bone_global_pose(_shoulder_bone).origin
		if _pelvis_bone >= 0 and _spined_bone >= 0:
			_pelvis_final = sk.get_bone_global_pose(_pelvis_bone).origin
			_spined_final = sk.get_bone_global_pose(_spined_bone).origin
		if _hip_l_bone >= 0 and _hip_r_bone >= 0:
			_hip_l_final = sk.get_bone_global_pose(_hip_l_bone).origin
			_hip_r_final = sk.get_bone_global_pose(_hip_r_bone).origin
		_advance_carry()
	_place_held()


## Once per rendered frame, on the final pose: the carried-over aim's let-down, the hips' yaw (low-passed,
## carry_follow_hips) and the lowered carry's weight (rate-limited, carry_low_time; from the fist's height and
## how far it is behind the shoulder). Primed to their targets when the weapon is equipped.
func _advance_carry() -> void:
	var f := Engine.get_process_frames()
	if f == _carry_frame or player == null or player.skeleton == null:
		return
	var dt := player.get_process_delta_time() if _carry_frame >= 0 else 0.0
	_carry_frame = f
	if not active:
		_held_aim = move_toward(_held_aim, 0.0, dt / HELD_AIM_FADE_S)
	if _ref_state == RefState.RETURNING and _held_w() <= 0.0:
		_ref_late += dt
	if not (active or (model and model.visible)):
		_carry_primed = false
		return
	var cb := _char_basis()
	if carry_follow_hips != 0.0 and _hip_l_bone >= 0:
		var r := player.skeleton.global_basis * (_hip_r_final - _hip_l_final)
		var y := clampf(atan2(-r.dot(cb.z), r.dot(cb.x)) * carry_follow_hips, -PI * 0.5, PI * 0.5)
		if _carry_primed and carry_follow_time > 0.0:
			y = _hips_yaw + (y - _hips_yaw) * (1.0 - exp(-dt / carry_follow_time))
		_hips_yaw = y
	else:
		_hips_yaw = 0.0
	var t := _low_target(cb, _fist().origin)
	if _carry_primed and carry_low_time > 0.0:
		t = move_toward(_port_w, t, dt / carry_low_time)
	_port_w = t
	_carry_primed = true


## Target weight of the lowered carry (carry_low_rot_deg): the fist below the shoulder (carry_low_band), not
## behind it (carry_low_back), standing (it fades out as the body crouches).
func _low_target(cb: Basis, fist: Vector3) -> float:
	if carry_low_band.y <= carry_low_band.x or not _palm_ok or _shoulder_bone < 0 or (_crouch_w >= 1.0 and not carry_low_crouched):
		return 0.0
	var cy := _carry_frame_basis(cb)
	var rel := player.skeleton.global_transform * _shoulder_final - fist
	var t := _smooth01((rel.dot(cb.y) - carry_low_band.x) / (carry_low_band.y - carry_low_band.x))
	if carry_low_back.y > carry_low_back.x:
		t *= 1.0 - _smooth01((rel.dot(-cy.z) - carry_low_back.x) / (carry_low_back.y - carry_low_back.x))
	return t if carry_low_crouched else t * (1.0 - _crouch_w)


## The character frame turned by the hips' yaw (carry_follow_hips): the carry's frame.
func _carry_frame_basis(cb: Basis) -> Basis:
	return cb * Basis(Vector3.UP, _hips_yaw) if _hips_yaw != 0.0 else cb


## Character frame: -Z forward (the way the player faces), +Y up.
func _char_basis() -> Basis:
	return player.global_basis.orthonormalized()


## Where the object is held: the fist (see the header), world space.
func _hand_pos() -> Vector3:
	return _fist().origin


## The fist in world space: the palm's final pose times the grip (the carry grip blended into the aim
## grip by `aim`). Falls back to the prop bone (no grip data: a rig without the Actor_B library) and to
## a point beside the body (no skeleton).
func _fist() -> Transform3D:
	var sk := player.skeleton
	if sk == null or _hand_bone < 0:
		return Transform3D(_char_basis(), player.global_position + _char_basis() * Vector3(0.25, 1.0, -0.1))
	var g: Variant = _grip_local()
	if _palm_ok and g != null:
		return sk.global_transform * _palm_final * (g as Transform3D)
	if _hand_final.is_finite():
		return Transform3D(sk.global_basis * sk.get_bone_global_pose(_hand_bone).basis, sk.global_transform * _hand_final)
	return sk.global_transform * sk.get_bone_global_pose(_hand_bone)


## The grip (prop bone relative to the palm) for the current aim weight; null without grip data.
func _grip_local() -> Variant:
	if _grip.is_empty() or (_grip.carry == null and _grip.aim == null and Time.get_ticks_msec() - _grip_retry_ms >= 1000):
		_grip = {"carry": _grip_of(grip_clip_carry, grip_sample_carry), "aim": _grip_of(grip_clip_aim, 0.0)}
		_grip_retry_ms = Time.get_ticks_msec()
	var c: Variant = _grip.carry
	var a: Variant = _grip.aim
	if c == null or a == null:
		return c if a == null else a
	var w := _held_w()
	if w <= 0.0:
		return c
	if w >= 1.0:
		return a
	return (c as Transform3D).interpolate_with(a as Transform3D, w)


## Prop-bone transform relative to the palm keyed by Actor_B clip `clip` at `t` s (the player's
## AnimationPlayer, library actor_b); null when the clip or its prop track is missing.
func _grip_of(clip: String, t: float) -> Variant:
	var key := "%s|%s|%.4f" % [clip, "r" if hand == Hand.RIGHT else "l", t]
	if _grip_cache.has(key):
		return _grip_cache[key]
	var out: Variant = null
	var ap := _anim_player()
	var path := StringName("actor_b/" + clip)
	var bone := "r_hand_prop_attachment" if hand == Hand.RIGHT else "l_hand_prop_attachment"
	if ap != null and ap.has_animation(path):
		var a := ap.get_animation(path)
		var rt := -1
		var pt := -1
		for i in a.get_track_count():
			if String(a.track_get_path(i).get_concatenated_subnames()) != bone:
				continue
			if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				rt = i
			elif a.track_get_type(i) == Animation.TYPE_POSITION_3D:
				pt = i
		if rt >= 0:
			var tt := clampf(t, 0.0, a.length)
			var rest := player.skeleton.get_bone_rest(_hand_bone) if player and player.skeleton and _hand_bone >= 0 else Transform3D()
			var pos: Vector3 = a.position_track_interpolate(pt, tt) if pt >= 0 else rest.origin
			out = Transform3D(Basis(a.rotation_track_interpolate(rt, tt)), pos)
	if out != null:
		_grip_cache[key] = out
	return out


func _anim_player() -> AnimationPlayer:
	if player == null or player.skeleton == null or player.skeleton.get_parent() == null:
		return null
	var aps := player.skeleton.get_parent().find_children("*", "AnimationPlayer", true, false)
	return aps[0] as AnimationPlayer if not aps.is_empty() else null


## Places the held model after the skeleton has been posed (and once per tick). Also while the
## weapon is put away but its model is still shown in the hand (player.gd: the graph holster until
## its finish starts, and the weapon in a dead player's hand): the model is top level, so it would
## otherwise stay where the hand last was.
## Order: the carry (_carry_basis), the switch path of a draw or holster stage (switch_path), then the
## aim: the aimed pose along the throw line blended in by `aim` from the body-space carry reference
## (_ref, RefState: time-uniform, however the fist turns while the arm winds up). In a switch stage the
## path itself is the reference; after a switch the aim carried over lets the pose down (_held_w()).
func _place_held() -> void:
	if model == null or player == null or not (active or model.visible) or not model.is_inside_tree():
		return
	var cb := _char_basis()
	var fist := _fist()
	var hand_p := fist.origin
	var carry_b := _carry_basis(cb, fist)
	var hold := 0.0
	var sw := _switch_phase() if switch_path != SwitchPath.FIST else -1.0
	if sw < 0.0:
		_sw_blending = false
		_sw_phi_set = false
		_sw_u_prev = -1.0
		if active:
			_reset_draw_flags()
	else:
		var u := _smooth01((sw - switch_blend.x) / maxf(switch_blend.y - switch_blend.x, 1e-3))
		if switch_path == SwitchPath.SOURCE and _palm_ok and _hand_bone >= 0:
			var prop: Transform3D = player.skeleton.global_transform * _prop_final
			var dpf := prop.origin.distance_to(fist.origin)
			if active and not _src_seen and not _src_fallback:
				if dpf >= source_show and _at_sling(cb, prop.origin):
					_src_seen = true
					_src_seen_sw = sw
				elif sw >= source_fallback_from:
					_src_fallback = true
			if _src_fallback and not _src_seen:
				# Never at the sling: in the hand, on the carry (crouched, shown once the fist is up; _source_waiting).
				if not _fb_shown and (source_fallback_drop_crouch < 0.0 or _crouch_w <= 0.5 \
						or (player.skeleton.global_transform * _shoulder_final - fist.origin).dot(cb.y) <= source_fallback_drop_crouch):
					_fb_shown = true
			else:
				# The draw clip's own object: the prop bone's final pose, its +Z the object's point (the weapons'
				# half turn about Y, prop +Z = barrel); the hold moves from it into the fist as they meet.
				var k := _smooth01((source_near.y - dpf) / maxf(source_near.y - source_near.x, 1e-3))
				hand_p = prop.origin.lerp(fist.origin, k)
				var src := prop.basis.orthonormalized() * Basis(Vector3.UP, PI)
				if not active and not _src_flip_decided and u > 0.0 and u < 1.0:
					# A holster from the carry: turn the object a half turn about its own axis on the drawn object's
					# path when that halves the twist the hand-over unwinds (up to 180 deg; a long shaft reads the
					# same either way round). Decided while the hand-over is still at the carry end, where it
					# does not show.
					_src_flip_decided = true
					_src_flip = _sw_u_prev >= 1.0 and absf(_twist_between(cb, src, carry_b)) > PI * 0.5
				if _src_flip:
					src = src * Basis(Vector3.BACK, PI)
				_sw_u_prev = u
				var hin := source_hold_in
				var hold_len := source_hold
				var hc := source_hold_crouch if source_hold_crouch >= 0.0 else source_hold
				var hinc := source_hold_in_crouch if source_hold_in_crouch.x >= 0.0 else source_hold_in
				# A draw whose object reaches the sling late (after a hand weapon's finish) starts the hold there, so
				# the object shows hanging from its balance point on the sling.
				var late := _src_seen_sw if active and _src_seen else 0.0
				var h_s := hold_len * _smooth01((sw - maxf(hin.x, late)) / maxf(hin.y - hin.x, 1e-3))
				var h_c := hc * _smooth01((sw - maxf(hinc.x, late)) / maxf(hinc.y - hinc.x, 1e-3))
				hold = lerpf(h_s, h_c, _crouch_w) * (1.0 - u)
				carry_b = _handover_line(cb, src, carry_b, u)
		elif switch_path == SwitchPath.STOW:
			if active and not _src_seen and not _src_fallback:
				if (fist.origin - player.skeleton.global_transform * _pelvis_final).dot(-cb.z) <= -stow_behind:
					_src_seen = true
				elif sw >= source_fallback_from:
					_src_fallback = true
			if not (_src_fallback and not _src_seen):
				carry_b = _handover_quat(cb, cb * _stow_basis(), carry_b, u)
	var w := _held_w()
	var live_q := _sign_near((cb.inverse() * carry_b).get_rotation_quaternion(), _q_live_prev)
	_q_live_prev = live_q
	if sw >= 0.0 or not model.visible:
		# A switch stage's path is the reference; a hidden object (thrown, taking the next) starts afresh.
		_ref_state = RefState.IN_FIST
	_update_ref(w, live_q)
	var b := carry_b
	var offset := cb * carry_offset
	var ref_q := live_q if _ref_state == RefState.IN_FIST else _sign_near(_ref, _q_ref_prev)
	_q_ref_prev = ref_q
	if _ref_state != RefState.IN_FIST:
		b = cb * Basis(ref_q)
	if w > 0.0:
		var d := _aim_dir if _aim_dir.length_squared() > 0.5 else -cb.z
		var right := d.cross(Vector3.UP)
		right = right.normalized() if right.length_squared() > 1e-4 else cb.x
		var tilt := aim_tilt_deg
		if state == State.RELEASING:
			tilt += _release_swing_deg(1.0 - _phase_left / maxf(_phase_len, 1e-3))
		var aimed := Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.98 else -cb.z)
		aimed = Basis(right, deg_to_rad(tilt)) * aimed
		# The aimed pose in body space, its sign kept from the last frame (from the reference's as the
		# aim starts).
		var aim_q := _sign_near((cb.inverse() * aimed).get_rotation_quaternion(), _q_aim_prev if _ref_aim > 0.0 else ref_q)
		_q_aim_prev = aim_q
		b = cb * Basis(ref_q.slerpni(aim_q, w))
		offset = offset.lerp(cb * aim_offset, w)
	_ref_aim = w
	model.global_transform = Transform3D(b, hand_p + offset - b * Vector3(0.0, 0.0, hold))
	_placed = true


## The carry orientation (world, not aimed): in the fist (carry_in_fist: the grip's prop axes times
## fist_basis), else carry_rot_deg in the carry frame (the character frame turned with the hips,
## carry_follow_hips), turned toward carry_low_rot_deg by the lowered carry's weight (_advance_carry).
func _carry_basis(cb: Basis, fist: Transform3D) -> Basis:
	if carry_in_fist:
		return fist.basis.orthonormalized() * fist_basis.orthonormalized()
	var cy := _carry_frame_basis(cb)
	var b := cy * Basis.from_euler(carry_rot_deg * (PI / 180.0), EULER_ORDER_YXZ)
	var t := _port_w if _carry_primed else _low_target(cb, fist.origin)
	if t > 0.0:
		var low := cy * Basis.from_euler(carry_low_rot_deg * (PI / 180.0), EULER_ORDER_YXZ)
		b = Basis(b.get_rotation_quaternion().slerp(low.get_rotation_quaternion(), _smooth01(t) if carry_low_time > 0.0 else t))
	return b


## The aim weight of the held pose: `aim`, or after a switch the aim carried over (see unequip()).
func _held_w() -> float:
	return clampf(aim if active else _held_aim, 0.0, 1.0)


## The draw's object (world position p) is at the sling: behind the upper spine and at least source_sling_up
## up the torso (the pelvis -> spined line; forward is perpendicular to it and to the character's right).
func _at_sling(cb: Basis, p: Vector3) -> bool:
	if _pelvis_bone < 0 or _spined_bone < 0:
		return true
	var xf := player.skeleton.global_transform
	var pel := xf * _pelvis_final
	var spd := xf * _spined_final
	var up_s := (spd - pel).normalized()
	var fwd_s := up_s.cross(cb.x).normalized()
	return (p - spd).dot(fwd_s) <= 0.0 and (p - pel).dot(up_s) >= source_sling_up


## SOURCE hand-over from src to dst (world bases) at u: the object's point (-Z) moves along the great circle
## between the two lines, and the object turns about its own axis by the remaining twist times u (kept
## continuous from frame to frame, _sw_phi). A long shaft's line is what reads; a quaternion slerp between the
## gun's roll and the carry's, about a half turn apart at a holster's start, swept the shaft through the body
## or flipped it in one frame.
func _handover_line(cb: Basis, src: Basis, dst: Basis, u: float) -> Basis:
	if u <= 0.0 or u >= 1.0:
		_sw_phi_set = false
		return src if u <= 0.0 else dst
	var d0 := -src.z.normalized()
	var axis := _swing_axis(cb, d0, -dst.z.normalized())
	var ang := acos(clampf(d0.dot(-dst.z.normalized()), -1.0, 1.0))
	var qs := src.get_rotation_quaternion()
	var phi := _twist_between(cb, src, dst)
	if _sw_phi_set:
		while phi - _sw_phi > PI:
			phi -= TAU
		while phi - _sw_phi < -PI:
			phi += TAU
	_sw_phi = phi
	_sw_phi_set = true
	var su := Quaternion(axis, ang * u)
	var du := (su * d0).normalized()
	return Basis((Quaternion(du, phi * u) * su * qs).normalized())


## STOW hand-over from src to dst (world bases) at u, in body space: the relative sign is the nearer one while
## u is at 0 or 1 and kept continuous from frame to frame while it blends; slerpni never flips.
func _handover_quat(cb: Basis, src: Basis, dst: Basis, u: float) -> Basis:
	var inv := cb.inverse()
	var qs := _sign_near((inv * src).get_rotation_quaternion(), _q_sw_src)
	var qd := (inv * dst).get_rotation_quaternion()
	qd = _sign_near(qd, _q_sw_car if (_sw_blending and u > 0.0 and u < 1.0) else qs)
	_sw_blending = u > 0.0 and u < 1.0
	_q_sw_src = qs
	_q_sw_car = qd
	return cb * Basis(qs.slerpni(qd, u))


## Axis of the great circle from line d0 to line d1 (unit; a stable perpendicular when they are parallel).
static func _swing_axis(cb: Basis, d0: Vector3, d1: Vector3) -> Vector3:
	var axis := d0.cross(d1)
	if axis.length_squared() < 1e-10:
		axis = d0.cross(cb.y)
		if axis.length_squared() < 1e-10:
			axis = d0.cross(cb.x)
	return axis.normalized()


## The turn about dst's line (-PI, PI] left once src's line has been swung onto dst's (_handover_line).
static func _twist_between(cb: Basis, src: Basis, dst: Basis) -> float:
	var d0 := -src.z.normalized()
	var d1 := -dst.z.normalized()
	var swing := Quaternion(_swing_axis(cb, d0, d1), acos(clampf(d0.dot(d1), -1.0, 1.0)))
	return _twist_about(dst.get_rotation_quaternion() * (swing * src.get_rotation_quaternion()).inverse(), d1)


## Signed angle (-PI, PI] of rotation q about the unit axis (its twist part).
static func _twist_about(q: Quaternion, axis: Vector3) -> float:
	var a := 2.0 * atan2(Vector3(q.x, q.y, q.z).dot(axis), q.w)
	while a > PI:
		a -= TAU
	while a <= -PI:
		a += TAU
	return a


## Draw phase of the switch stage the held object is in: 0..1 through a draw (Weapon.equip() or the throw
## cycle's DRAWING), from where the draw was back to 0 through a holster (player.gd's switch, this weapon
## put away and its model shown); -1 in none (the carry, a dead player's hand).
func _switch_phase() -> float:
	if active:
		if _equip_left > 0.0 and equip_time > 0.0:
			return clampf(1.0 - _equip_left / equip_time, 0.0, 1.0)
		if state == State.DRAWING and _phase_len > 0.0:
			return clampf(1.0 - _phase_left / _phase_len, 0.0, 1.0)
		return -1.0
	if player.weapon != self and player.switch_stage() == "holster":
		var st := player.switch_timing()
		var tf := float(st.get("t_finish", 0.0))
		if tf > 0.0:
			return _holster_from * clampf(1.0 - float(st.get("t", 0.0)) / tf, 0.0, 1.0)
	return -1.0


## STOW orientation, character frame (Godot axes: +X right, +Y up, -Z forward): model +Y along stow_up,
## model -Z along stow_edge (made perpendicular).
func _stow_basis() -> Basis:
	var y := Vector3(stow_up.x, stow_up.y, -stow_up.z).normalized()
	var e := Vector3(stow_edge.x, stow_edge.y, -stow_edge.z)
	e = (e - y * e.dot(y)).normalized()
	var z := -e
	return Basis(y.cross(z), y, z)


## Advances the carry reference (see RefState) for aim w and the live carry live_q (body space). Called by
## every placement; the aim changes once per physics tick, so later calls in a tick only follow the fist.
func _update_ref(w: float, live_q: Quaternion) -> void:
	match _ref_state:
		RefState.IN_FIST:
			if w > _ref_aim:
				# Held from the last placement before the aim rose (the placement this tick already sees the
				# arm a frame into the aim-in).
				_ref_state = RefState.HELD
			else:
				_ref = live_q
		RefState.HELD:
			if w < _ref_aim:
				_ref_state = RefState.RETURNING
				_ref_from = _ref
				_ref_back = 0.0
				_ref_late = 0.0
		RefState.RETURNING:
			if w > _ref_aim:
				_ref_state = RefState.HELD      # wound up again: held where it is
				return
	if _ref_state != RefState.RETURNING:
		return
	# The hand-over starts only once the fist is within REF_NEAR.y (< a half turn) of the held carry, where
	# the nearer sign is unambiguous.
	var lq := _sign_near(live_q, _ref_from)
	var near := 1.0 - (rad_to_deg(_ref_from.angle_to(lq)) - REF_NEAR.x) / (REF_NEAR.y - REF_NEAR.x)
	_ref_back = maxf(_ref_back, maxf(_smooth01(near), _ref_late / REF_LATE_S if w <= 0.0 else 0.0))
	if _ref_back >= 1.0:
		_ref_state = RefState.IN_FIST
		_ref = live_q
		return
	_ref = _ref_from.slerpni(lq, _smooth01(_ref_back))


## q or -q (the same rotation), whichever is nearer `ref`: keeps a sequence of quaternions continuous.
static func _sign_near(q: Quaternion, ref: Quaternion) -> Quaternion:
	return -q if q.dot(ref) < 0.0 else q


static func _smooth01(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
