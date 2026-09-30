class_name PlayerAnim
extends AnimationTree
## The player's animation facade (plan section 6.12, WP6): the AnimationTree that plays the
## extracted player animation graph on the Actor_B rig.
##
## setup() builds the tree from the generated graph table (TreeBuilder over AnimGraphData:
## animations/actor_b_graph.json + actor_b_clip_metrics.json), and each frame runs the two
## controllers that stand in for the graph's state machine:
##
##   _physics_process (priority 100, after the player)
##     AnimInputs.sample(player)          -> `inputs`; its edge events (jumped / fell / landed)
##                                           are queued for the next frame
##   _process(dt) = manual_step(dt)       (callback mode MANUAL)
##     1 queued events, in order          weapon: set_weapon / fired / action_started /
##                                           action_cancelled; player: hurt / died / respawned;
##                                           set_option (gameplay overrides)
##     2 LocoBrain.tick                   lower body: the graph's states and transition records
##     3 UpperBody.tick                   aim / carry / hands / actions / fire / charge / hits
##     4 L.update + L.write               lower selector
##     5 advance(dt)
##     6 UpperBody.post_advance           AimStabilizer inputs; then recorder + trace
##   Skeleton3D update -> PropFlipGuard (plays the action partials on the weapon prop bones),
##   AimStabilizer (SkeletonModifier3Ds, UpperBody's) -> BoneAttachment3D (weapons)
##
## Graph-faithful by default: every gameplay override of the graph table is an opt-in flag in
## the "Gameplay overrides" export group, all off except override_start_rate_boost (DEFAULT_ON: on
## by default pending the owner's decision, see its comment). With them off the lower body plays the
## graph's start / stop / quick-reversal states, idle turns, its 0.75 s hemisphere fade, the
## landings' movement gate, the aim idle -> aimed movement 0.5 s fade and the full-body crouch
## change; the upper body plays the graph's hands layers and the holster (options.holster), and
## the thrown weapons wind up through the graph's aim-in (the aim tree).
##
## Frontier behaviour kept (owner requirements): the weapon is carried lowered and raised only
## while Weapon.aim > 0 (upper aim weight = Weapon.aim); aimed movement is the masked aim tree
## over the locomotion clips plus the AimStabilizer (the graph's aim-walk clips move at
## 0.545 m/s, so options.aim_walk stays off); the stabilizer's aim trim keeps the barrel on the
## crosshair point and replaces the weapons' interim aim_yaw / aim_pitch offsets (trims_aim():
## player.gd then leaves the body facing the camera); a weapon switch while aimed lowers the old
## aim over the weapon crossfade instead of in one frame (_aim_carried). Weapon signals (fired,
## action_started(key, duration), action_cancelled) and setup() / set_weapon() are unchanged.
##
## Holster (options.holster, on): the graph puts a weapon away before the next one is drawn. The
## gameplay owns the timing (player.gd switch_weapon(); FrontierPlayer.switch_stages()) and calls,
## in order: play_holster(old, s) (idle-pistol-holster-part: the old weapon's draw clip backwards,
## at the speed its draw plays), play_switch_stage(old, "holster_finish", s) (the empty hand back
## to idle), play_switch_stage(new, "grab", s) (draw step 1: the hand to the new weapon), then
## the new weapon's own equip draw (Weapon.action_started "equip"). Each stage starts on the
## pose the previous one ends on (as authored). instant_weapon_switch (override) turns it off.
## body_speed_cap(): through a graph start clip the body follows the clip's body speed, INFERRED
## (the metrics' foot-contact body_profile estimate; the clips carry no root track;
## override_free_start_speed keeps player.gd's acceleration). graph_key(): the graph key a roster
## key plays.
##
## Thrown weapons (THROW; the graph's pick-up weapon-base profiles spear / tomahawk / atlatl):
## UpperBody's ThrowChain plays the graph's throw chain on Weapon.action_started("throw") and, on
## the release frame (throw.release_s into release-end at the throw rate), calls the weapon's
## release_from_animation(); setup() switches those weapons to the event-driven release
## (wait_for_anim_release, with anim_release_timeout = tuning throw_release_timeout_s as the timer
## fallback). Their `fired` plays no fire additive. Their wind-up is the graph's aim-in (the aim
## tree weighted by Weapon.aim); override_throw_windup_raise opts into the charge-seeked raise.
## Debug: debug_snapshot() (plan section 9), `--anim-trace` prints every lower-body transition
## with its graph record, `--anim-record=<path>` records every frame (AnimRecorder JSONL) from
## setup; set_input_source(AnimRecorder.replay_source(lines)) replays one. Tests set
## auto_process = false and drive manual_step() / sample_inputs() themselves.
##
## Nothing here changes the tree resources after setup (no filter, animation, loop or layout
## edit; test_tree_build lints this file, test_facade hashes the resources).
##
## Asset IDs, record offsets and attribution stay in the graph table
## (debug_snapshot().provenance).

signal anim_transition(from: StringName, to: StringName, info: Dictionary)
## A thrown weapon's release frame (THROW: UpperBody's ThrowChain; the weapon has been told through
## Throwable.release_from_animation()). weapon_key: the graph key.
signal throw_released(weapon_key: StringName)
## The torch toss lets go of the torch (play_torch_toss(); PlayerTorch then drops it where the hand is).
signal torch_released

## Graph-table gameplay override flags exposed as exports (AnimGraphData.set_override).
const OVERRIDE_FLAGS := ["override_no_transition_anims", "override_fast_hemisphere_fade", "override_no_idle_turns",
		"override_immediate_land_move", "override_fast_aim_to_move", "override_crouch_crossfade", "override_fall_fade",
		"override_exact_hands_grip", "override_throw_windup_raise"]
## Facade-level overrides (not graph-table flags).
const FACADE_OPTIONS := ["join_fade_s", "stick_release_grace_s", "instant_weapon_switch", "strict_graph_cuts",
		"override_free_start_speed", "override_start_rate_boost", "override_crisp_stops", "crouch_pending_while_moving",
		"crouch_crossfade_blend"]
## Gameplay overrides that are ON by default, pending the owner's decision (tests/anim/README.md
## "Documented deviations pending owner decision"); every other override is off (graph-faithful).
const DEFAULT_ON := ["override_start_rate_boost"]
const TRACE_ARG := "--anim-trace"
const RECORD_ARG := "--anim-record="
const TRACE_KEEP := 64

@export_group("Gameplay overrides")
## G1: no start, stop or quick-reversal clips (the graph's own use_transition_anims = false
## branch). Off = the graph plays them.
@export var override_no_transition_anims := false:
	set(v):
		override_no_transition_anims = v
		_export_changed(&"override_no_transition_anims", v)
## G2: 0.3 s hemisphere crossfade instead of the graph's 0.75 s.
@export var override_fast_hemisphere_fade := false:
	set(v):
		override_fast_hemisphere_fade = v
		_export_changed(&"override_fast_hemisphere_fade", v)
## G5: no turn-in-place clips; the legs follow the camera yaw.
@export var override_no_idle_turns := false:
	set(v):
		override_no_idle_turns = v
		_export_changed(&"override_no_idle_turns", v)
## G6: movement leaves a landing at once instead of after the graph's m2 >= 10 gate.
@export var override_immediate_land_move := false:
	set(v):
		override_immediate_land_move = v
		_export_changed(&"override_immediate_land_move", v)
## 0.3 s from aim idle into aimed movement instead of the graph's 0.5 s.
@export var override_fast_aim_to_move := false:
	set(v):
		override_fast_aim_to_move = v
		_export_changed(&"override_fast_aim_to_move", v)
## Plain 0.25 s stand / crouch crossfade instead of the graph's full-body crouch change and its
## crouch-change additive.
@export var override_crouch_crossfade := false:
	set(v):
		override_crouch_crossfade = v
		_export_changed(&"override_crouch_crossfade", v)
## 0.3 s into the fall loop instead of pre-fall's 0.5 s.
@export var override_fall_fade := false:
	set(v):
		override_fall_fade = v
		_export_changed(&"override_fall_fade", v)
## The grip clips drive the finger, palm and prop bones at full weight in every pose instead of
## the graph's hands layers.
@export var override_exact_hands_grip := false:
	set(v):
		override_exact_hands_grip = v
		_export_changed(&"override_exact_hands_grip", v)
## Thrown weapons (THROW): the wind-up plays the graph's raise clip (throw-object-aim) seeked by the
## wind-up charge, so the arm draws back as power builds (a Frontier-only layer; a quick throw
## while moving then plays the rest of the raise first). Off = the graph's aim-in: the aim tree
## (the cocked throw aim pose) weighted by Weapon.aim, then the throw from aim idle / aimed movement.
@export var override_throw_windup_raise := false:
	set(v):
		override_throw_windup_raise = v
		_export_changed(&"override_throw_windup_raise", v)
## > 0: a fade-0 lower-body join from a fully weighted input (a one-shot clip's end into its
## successor) fades over this long instead of cutting as authored (LocoBrain.join_fade_s).
@export_range(0.0, 0.5, 0.01, "suffix:s") var join_fade_s := 0.0:
	set(v):
		join_fade_s = v
		_export_changed(&"join_fade_s", v)
## > 0: `moving` stays on this long after the stick is released, so a keyboard direction change
## with a gap frame keeps the quick reversal (LocoBrain.release_grace_s; 0 = graph literal).
@export_range(0.0, 0.3, 0.01, "suffix:s") var stick_release_grace_s := 0.0:
	set(v):
		stick_release_grace_s = v
		_export_changed(&"stick_release_grace_s", v)
## No holster clip before a weapon swap (options.holster off): today's instant switch.
@export var instant_weapon_switch := false:
	set(v):
		instant_weapon_switch = v
		_export_changed(&"instant_weapon_switch", v)
## Through a graph start clip (idle^run etc.) the body keeps player.gd's own acceleration instead
## of following the clip's body speed (body_speed_cap(); LocoBrain.root_motion_speed(); INFERRED
## from the metrics' foot-contact body_profile): the body is at full speed in about 0.25 s while
## the start clip accelerates over 0.8-3 s, so the feet slide. Off = the body follows the start
## clip (the source game's body is taken to follow the animation).
@export var override_free_start_speed := false:
	set(v):
		override_free_start_speed = v
		_export_changed(&"override_free_start_speed", v)
## Through a graph stop the body keeps player.gd's quick deceleration (ground_decel: at rest in about 0.2 s
## from a run) instead of following the stop clip's travel (body_speed_cap(); LocoBrain.stop_root_motion):
## the stop clip's legs then still travel about 0.86 m over its first 0.5 s, so the pelvis slides back over
## the planted feet (user playtest 2026-09-25: "a whole like backwards step"). Off = the body follows the
## stop clip as it follows a start (graph-faithful: about 1.1-1.6 m of stopping travel from a run).
@export var override_crisp_stops := false:
	set(v):
		override_crisp_stops = v
		_export_changed(&"override_crisp_stops", v)
## ON BY DEFAULT, pending the owner's decision (DEFAULT_ON): a graph start clip plays faster than
## the graph's align rate (desired speed / the clip's final body speed; LocoBrain._align_rate)
## where its own (inferred) body speed is below the desired speed, up to the locomotion rate clamp
## 1.75 (plan D9; LocoBrain.start_rate_boost). With the body following the start clip
## (body_speed_cap()) a run start from a stand reaches full speed after 0.64-0.65 s and 1 s of W
## covers 2.32-2.43 m (musket / bow). Off = graph-faithful (the align rate only): 0.86-0.93 s and
## 1.52-1.80 m, and tests/smoke_test.gd's movement check (over 2 m) fails.
@export var override_start_rate_boost := true:
	set(v):
		override_start_rate_boost = v
		_export_changed(&"override_start_rate_boost", v)

@export_group("Graph approximations")
## On: at the graph's fade-0 lower-body joins (e.g. take-off -> jump, record 0x00026ab0) the carry
## layers cut together with the base clip, the literal reading. Off (default): the incoming
## input's carry layers ramp from the outgoing input's amounts over tuning carry_join_s (0.25 s,
## status "approximation"): the decoded layer records give weights only, not how the layers change
## at such a cut, and the two states' layer stacks differ (the musket's take-off has no
## rifle-run-arms layer, the jump has; cutting them snaps the left wrist at about 112 rad/s).
@export var strict_graph_cuts := false:
	set(v):
		strict_graph_cuts = v
		_export_changed(&"strict_graph_cuts", v)
## Crouch toggles (WP10, ch-crouchB). Off (default): crouch_change_pending (INFERRED) is set by a
## toggle while the lower body is not moving, which plays the graph's in-place crouch change
## (crouch-change-idle^idle); a toggle while moving takes the graph's change-move-mode record to the
## other stance's locomotion bank (0x0002a970 / 0x000252f0 0.5 s, aimed 0x00030a50 0.25 s) with the
## crouch-change additive on top (the source game's moving crouch changes come from a runtime clip
## grid that Actor_B's data does not have). On: every toggle sets it (the earlier reading: while
## moving, the in-place change, idle, then the crouch start clip, while the body keeps moving).
@export var crouch_pending_while_moving := false:
	set(v):
		crouch_pending_while_moving = v
		_export_changed(&"crouch_pending_while_moving", v)
## Off (default): a transition into the other stance (crouch <-> stand) switches the lower body at
## once, phase-matched to the stride, and StanceInertializer blends the pose (offset and velocity)
## into it over the transition's graph fade. On: the plain crossfade over the same fade.
@export var crouch_crossfade_blend := false:
	set(v):
		crouch_crossfade_blend = v
		_export_changed(&"crouch_crossfade_blend", v)

## The long gun's left hand. "source" (default; push n01, user playtest 2026-09-25: "the gun bounces in the
## left hand when we move"): LeftGripIK keeps the left hand on the gun in every two-hand carry, standing or
## crouched, still or moving, on the ground or in a jump, not while aiming (the source holds it there) nor
## in actions; moving, the left arm is the source's two-hand carry arm at full weight (LeftArmPose GRIP),
## which the grip closes onto the gun. The idles are as authored (both hands already on the gun: the IK
## moves nothing there; the standing hold the user liked is unchanged). (Before n01 the grip was on only
## while crouch-moving, user 2026-09-25 "i only want the IK in the crouch move rifle": walking, the left hand
## rode 13-35 cm off the gun.) "one_hand": moving without aiming, the gun in the right hand and the left
## arm swinging free (LeftArmPose; the relaxed carry). "two_hand": as "source", the grip also while aiming.
@export_enum("source", "one_hand", "two_hand") var long_gun_move_carry := "source"
## The relaxed one-hand carry (user 2026-09-25: "if its on one hand mode holding for a while keep it like
## that until they press fire or to reset it"): after this many seconds with a long gun and no aiming, the
## gun is HELD DOWN at the side in one hand (user 2026-09-25: "the one hand hold its where the rifle is held down
## with one hand during crouch"): since push n01c the LEFT hand, gripped in the middle at the balance point, the
## right hand free (user 2026-09-26: "yes i want the middle grip on the crouch walk as well", "allows user to have the
## right hand to throwables and easily switch back to rifle"; HandHolds, GunMiddleCarryIK; the arm is the source's
## one-hand crouch-move rifle arm ONE_HAND_LOW_ARM, mirrored); shown only while crouch-moving (one_hand; user
## 2026-09-25), until the player raises the gun (fire / aim), reloads or switches. 0 = off (user 2026-09-30: "the one handed
## musket hold for crouch i do not like that we should remove that for now": off; set this back to 6.0 to bring it back).
@export var relax_after_s := 0.0
## The long gun's hold while running and sprinting (standing, both hands on the gun, not aiming; walking keeps the
## graph's). "graph": the graph's run carry layer (actor_b-p-rifle-run-arms at 0.8-0.9 over the empty-handed arm
## swing: the right arm swung the gun up and back over the shoulder with every stride, user 2026-09-27: "you see how
## the gun moves back we need to keep the gun in front on runs"). "port_low" (default; the user's pick, "A on runs,
## B on sprints"): running, port arms (the source's run carry arms held at full weight by both arms: the muzzle up
## and forward across the chest, moving with the stride); sprinting, low ready (the standing hold,
## actor_b-p-rifle-idle-arms: the muzzle forward and low). "run" / "idle": one of the two for both gaits.
@export_enum("graph", "port_low", "run", "idle") var long_gun_run_hold := "port_low"
## How much of the source's rifle spine lean the long gun's carry keeps (1 = the graph: the additive layer
## actor_b-p-rifle-idle-spine--add at its layer weights, idle and stops 0.6, walk 0.5, starts 0.4, run 0.2,
## bends the torso about 32 deg back at full weight; the rifle idle stood 25 deg back against the pistol's
## 8; user playtest 2026-09-25: "arch to far back"). 0.25: the rifle idle about 11 deg back. None with the hands free
## (the gun slung, not held: it had still leaned him back, the user 2026-09-29: "how come he leans back like that, why
## not upright and straight").
@export_range(0.0, 1.0, 0.05) var long_gun_spine_lean := 0.25:
	set(v):
		long_gun_spine_lean = v
		if upper:
			upper.spine_add_scale = 0.0 if hands_free else v

@export_group("Performance")
## Carry-layer layout (TreeBuilder, applied at setup): "input" = every carry layer inside its
## lower input, graph-exact through crossfades (default); "shared" = one stack per weapon, about
## half the per-frame cost, exact only while one lower input is weighted (a fidelity trade-off).
@export_enum("input", "shared") var carry_layers := "input"

@export_group("Torch")
## The torch (push n01b, reworked by n01c; torch_hand, set by PlayerTorch) in the hand the weapon does not need
## (HandHolds): held like a hatchet, the axe hold (the tomahawk's carry arm, TorchCarryIK turns it upright and puts
## the fist beside the hip), raised beside the shoulder while T is held; with a long gun the left hand carries the
## gun gripped in the middle (GunMiddleCarryIK). The player's exports of the same names are copied onto these before
## setup (torch_option_names()).
## How far the torch leans forward of vertical in the axe hold (deg), and out from the leg.
@export_range(0.0, 45.0, 1.0, "suffix:deg") var torch_tilt_deg := 30.0
@export_range(0.0, 30.0, 1.0, "suffix:deg") var torch_out_deg := 14.0
## Where the axe hold's fist goes, from the pelvis (m: x out to the torch hand's side, y up, z forward, in the
## player's facing), standing and crouched; the raised hold's from the torch hand's shoulder.
@export var torch_fist := Vector3(0.28, -0.1, 0.24)
@export var torch_fist_crouch := Vector3(0.3, 0.06, 0.24)
@export var torch_raise_fist := Vector3(0.12, 0.08, 0.36)
## How much of the locomotion's own arm swing the axe hold keeps (the tomahawk's carry arm takes the rest).
@export_range(0.0, 1.0, 0.01) var torch_arm_swing := 0.45
## The toss (aiming a long gun, drawing the bow, reloading): seconds from its start to letting go.
@export_range(0.05, 0.5, 0.01, "suffix:s") var torch_toss_release_s := 0.16
## The long gun in the left hand, gripped in the middle (push n01c: GunMiddleCarryIK; the torch carry, the crouch-walk
## one-hand hold, the quick throwables): the barrel below horizontal (deg), standing and crouched, and how far along
## the barrel from the wrist of the stock the fist grips (m: the musket's balance point, just ahead of the lock).
@export_range(0.0, 30.0, 1.0, "suffix:deg") var gun_mid_pitch_deg := 6.0
@export_range(0.0, 30.0, 1.0, "suffix:deg") var gun_mid_pitch_crouch_deg := 3.0
@export_range(0.1, 0.8, 0.01, "suffix:m") var gun_balance_m := 0.40

@export_group("Debug")
## Print every lower-body transition with its graph record (also on with --anim-trace).
@export var trace := false

## Latest AnimInputs sample (read-only).
var inputs: AnimInputs
## false in tests: nothing runs by itself; drive with sample_inputs() / manual_step(). Turned back on
## (PlayerTraversal and the horse turn it off while they own the pose, with the skeleton modifiers), the arm
## modifiers take their weights at once on the next step instead of fading from where they were left.
var auto_process := true:
	set(v):
		if v and not auto_process:
			_resume_snap = true
		auto_process = v
var _resume_snap := false
## false (tests of the weapon's own timer fallback): the throw's release frame only emits
## throw_released; the weapon is not told (Throwable.release_from_animation()).
var drive_throw_release := true

var player: FrontierPlayer
var data: AnimGraphData
var index: TreeIndex
var L: XFadeSelector
var loco: LocoBrain
var upper: UpperBody
var stabilizer: AimStabilizer
## Inertialized stance changes (ch-crouchB): the first skeleton modifier (LocoBrain.inertia_request).
var inertializer: StanceInertializer
## Planted feet held on the ground while a stance change is inertialized (TraversalIK in plant /
## hold mode): the inertialized pelvis eases between the stances' heights while the target
## stance's legs are already straight or bent, which pushed a planted foot through the floor and
## dragged it (stand-up at a run: 13 cm under the floor, 1-2 m/s slide). Empty pins otherwise.
var stance_foot_ik: TraversalIK
## Left hand on the long gun's forestock while it is carried with both hands (LeftGripIK; user playtests:
## the crouch-walk rifle hold, the gun bouncing in the left hand). Off while aiming, in the one-hand hold,
## hands free, during actions (reload, draw, holster), switches and death.
var left_grip: LeftGripIK
## The long gun's damped carry bob (GunCarryDamper): on while a long gun is carried, not aimed, no action.
var gun_damper: GunCarryDamper
## The left arm of the long-gun carries while moving (LeftArmPose): see long_gun_move_carry.
var left_arm: LeftArmPose
## Hands free (FrontierPlayer.hands_free: H, or the weapon was put down): both arms take the locomotion's
## own swing (left_arm and right_arm with the lower-body clips as sources); the weapon's carry is off, and its spine lean.
var hands_free := false:
	set(v):
		hands_free = v
		if upper:
			upper.spine_add_scale = 0.0 if v else long_gun_spine_lean
var right_arm: LeftArmPose
## A torch is in a hand (PlayerTorch, every physics tick): HandHolds decides which (TorchCarryIK) and where the long gun
## goes (GunMiddleCarryIK: the left hand, gripped in the middle).
var torch_hand := false
var torch_ik: TorchCarryIK
var mid_ik: GunMiddleCarryIK
## The right hand seated on the stock (RightSeatIK) and its index on the trigger (TriggerFinger), after the hands' IK.
var right_seat: RightSeatIK
var trigger_finger: TriggerFinger
var holds: HandHolds
## The relaxed one-hand carry is on (relax_after_s); read by tests and the debug overlay.
var relaxed := false
## The gun is in one hand now (relaxed and crouch-moving, or a jump taken off that way).
var one_hand := false
var _no_aim_t := 0.0
## Graph weapon keys whose left hand LeftGripIK keeps on the gun (the over-under plays the musket's).
const LEFT_GRIP_WEAPONS := ["musket"]
## Weapons aimed with one hand (user 2026-09-29: "have pistols aim with one hand not 2"): while one is aimed the left arm is the
## relaxed free arm (LeftArmPose "free"), not the two-handed aim clip's; a reload, a draw and every other action keep the tree's arm.
const ONE_HAND_AIM_WEAPONS := ["pistol"]
## Off: the pistol is aimed in both hands as the source's clip has it (the look-check compares).
var one_hand_aim_on := true
## The left arm of a one-handed aim: the source's plain idle arm, hanging at the side (user 2026-09-29 chose it from the lineup of arm
## poses: the fall's and the jump's arms out were tried and passed over); crouched, the plain crouch idle's arm.
var one_hand_left_arm := "actor_b-p-relax-idle"
## The phase (0..1) of that clip the arm is taken at.
var one_hand_left_phase := 0.0
const ONE_HAND_LEFT_ARM_CROUCH := "actor_b-p-crouch-idle"
## A foot counts as planted when the animated ball / ankle is this low (skeleton space, m; the
## walk, run, sprint and crouch-walk clips plant the ball at 0.00-0.04 and the ankle at 0.06-0.10).
const STANCE_PLANT_BALL := Vector2(0.045, 0.09)
const STANCE_PLANT_ANKLE := Vector2(0.11, 0.16)
## The pins fade out over this much of the end of the stance change (s).
const STANCE_IK_FADE_S := 0.12
## A foot's pin weight changes at most this fast (1/s): no knee snap when a foot lifts or plants.
const STANCE_IK_RATE := 12.0
var _stance_w := {"l": 0.0, "r": 0.0}
var _last_dt := 1.0 / 120.0
var recorder: AnimRecorder
## BindRest.verify() result, TreeBuilder summary and the reason setup() refused (if it did).
var setup_report := {}
## Animation frames run since setup (manual_step calls).
var frame := 0

var _ap: AnimationPlayer
var _sk: Skeleton3D
var _weapons: Dictionary = {}          ## key -> Weapon
var _ok := false
var _weapon := &""
var _events: Array[Dictionary] = []    ## facade events queued since the last frame
var _edges: Array[Dictionary] = []     ## AnimInputs edge events queued since the last frame
var _source := Callable()
var _time := 0.0
var _cfg := {}
var _applying := false
var _trace_lines: Array[String] = []
var _warnings := PackedStringArray()
var _aim_hold := 0.0                   ## aim weight carried over a weapon switch (_aim_carried)
var _aim_hold_frame := -1              ## physics frame of the input sample the hold was taken against


func _init() -> void:
	process_physics_priority = 100
	process_priority = 100


# --- setup ----------------------------------------------------------------------------------

## Builds the tree and the controllers (plan 6.12). p_player may be null in tests (inputs then
## come from set_input_source()). weapons: key -> Weapon (their signals are connected once).
func setup(p_player: FrontierPlayer, ap: AnimationPlayer, sk: Skeleton3D, weapons: Dictionary) -> void:
	if _ok:
		push_warning("PlayerAnim.setup: already set up")
		return
	player = p_player
	_ap = ap
	_sk = sk
	_weapons = weapons
	# 1. Rest = the game's bind pose (null-add).
	var rest := BindRest.verify(sk, ap)
	setup_report["bind_rest"] = rest
	if not bool(rest.get("ok", false)):
		_refuse("rest is not the bind pose null-add: %s (BindRest.ensure() must run first)" % rest.get("reason", "?"))
		return
	# 2. Graph and metrics tables.
	data = AnimGraphData.load_files()
	if data == null:
		_refuse("graph table %s cannot be read" % AnimGraphData.GRAPH_PATH)
		return
	_warnings.append_array(data.warnings)
	_apply_exports_to_data()
	# 3.-5. AnimationPlayer, paths, manual callback.
	ap.stop()
	TreeBuilder.ensure_none(ap)
	root_node = get_path_to(ap.get_node(ap.root_node))
	callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# 6. Tree.
	index = TreeBuilder.build(data, ap, sk, {"carry": carry_layers})
	setup_report["tree"] = index.summary()
	if not index.errors.is_empty() or index.tree_root == null:
		_refuse("TreeBuilder failed: %s" % [index.errors])
		return
	_warnings.append_array(index.warnings)
	# The tree takes the player's library list when anim_player is assigned and does not see
	# libraries added later: assign it after TreeBuilder added frontier / frontier_bank (the
	# direction banks' difference clips). A missing clip makes the engine abort the whole frame
	# whenever a node that plays it is weighted, which freezes the pose (measured: 17 frames of a
	# reversal crossfade, then a 78 rad/s jump).
	anim_player = get_path_to(ap)
	_sync_libraries(ap)
	index.install(self)
	# 7. Selectors and controllers.
	L = XFadeSelector.new(self, "L", index.L_inputs, index.L_seek)
	upper = UpperBody.new(data, self, index)
	upper.set_lower_selector(L)
	upper.strict_graph_cuts = strict_graph_cuts
	upper.spine_add_scale = 0.0 if hands_free else long_gun_spine_lean
	stabilizer = upper.attach_stabilizer(sk)
	loco = LocoBrain.new(data, self, index, L, upper.W)
	loco.join_fade_s = join_fade_s
	loco.release_grace_s = stick_release_grace_s
	loco.start_rate_boost = override_start_rate_boost
	loco.stop_root_motion = not override_crisp_stops
	loco.crouch_pending_while_moving = crouch_pending_while_moving
	loco.crouch_crossfade_blend = crouch_crossfade_blend
	inertializer = StanceInertializer.create(sk, _lower_bones(sk, ap))
	stance_foot_ik = TraversalIK.new()
	stance_foot_ik.name = "StanceFootIK"
	stance_foot_ik.active = false   # on only while a stance change is inertialized (_stance_feet)
	sk.add_child(stance_foot_ik)    # CharacterBodyMesh moves itself behind it (it stays last)
	left_arm = LeftArmPose.new()
	left_arm.name = "LeftArmPose"
	sk.add_child(left_arm)          # after PropFlipGuard / AimStabilizer, before LeftGripIK
	right_arm = LeftArmPose.new()
	right_arm.name = "RightArmPose"
	right_arm.side = "r"
	sk.add_child(right_arm)
	torch_ik = TorchCarryIK.new()
	torch_ik.name = "TorchCarryIK"
	var grip := data.godot_anim(TorchCarryIK.GRIP_CLIP)
	if ap.has_animation(grip):
		torch_ik.set_grip(ap.get_animation(grip))
	sk.add_child(torch_ik)          # after the arm poses, before GunCarryDamper
	gun_damper = GunCarryDamper.new()
	gun_damper.name = "GunCarryDamper"
	sk.add_child(gun_damper)        # after the arm poses (they move the gun), before LeftGripIK
	left_grip = LeftGripIK.new()
	left_grip.name = "LeftGripIK"
	gun_damper.grip = left_grip
	sk.add_child(left_grip)         # after PropFlipGuard / AimStabilizer (they move the gun)
	mid_ik = GunMiddleCarryIK.new()
	mid_ik.name = "GunMiddleCarryIK"
	var ref := data.godot_anim(GunMiddleCarryIK.REF_CLIP)
	mid_ik.set_reference(ap.get_animation(ref) if ap.has_animation(ref) else null, sk)
	mid_ik.torch = torch_ik
	sk.add_child(mid_ik)            # the last of the hands' modifiers (it places the held gun and torch)
	right_seat = RightSeatIK.new()
	right_seat.name = "RightSeatIK"
	trigger_finger = TriggerFinger.new()
	trigger_finger.name = "TriggerFinger"
	if player != null:
		right_seat.offset = player.musket_offset
		trigger_finger.offset = player.musket_offset
	sk.add_child(right_seat)        # the right hand onto the gun as it is held at last
	sk.add_child(trigger_finger)    # then its index on the trigger
	holds = HandHolds.new(self, torch_ik, mid_ik)
	_torch_ik_options()
	loco.transitioned.connect(_on_loco_transition)
	if upper.throw != null:
		upper.throw.released.connect(_on_throw_released)
	# 8. Weapon signals (queued; unchanged signatures).
	for key in weapons:
		var w: Object = weapons[key]
		if w == null:
			continue
		w.fired.connect(_on_fired.bind(key))
		w.action_started.connect(_on_action.bind(key))
		w.action_cancelled.connect(_on_action_cancelled.bind(key))
		# THROW: the animation lets go of a thrown weapon (release_from_animation()); the weapon's
		# timer stays as the fallback.
		if upper.throw != null and upper.throw.handles(StringName(String(key))) and "wait_for_anim_release" in w:
			w.set("wait_for_anim_release", true)
			w.set("anim_release_timeout", float(data.tuning("throw_release_timeout_s", 0.35)))
	# 9. Player signals, when the player has them (WP7).
	if player != null:
		if player.has_signal(&"hurt"):
			player.connect(&"hurt", _on_player_hurt)
		if player.has_signal(&"died"):
			player.connect(&"died", _on_player_died)
		if player.has_signal(&"respawned"):
			player.connect(&"respawned", _on_player_respawned)
	# 10. Initial state: idle (or aim idle) of the player's stance, no fade.
	_cfg = {"chest_height": {"stand": data.chest_height("stand"), "crouch": data.chest_height("crouch")},
			"blocked_len_m": data.tuning("blocked_len_m", AnimInputs.DEFAULT_BLOCKED_LEN),
			"blocked": bool(data.option("blocked", true))}
	inputs = AnimInputs.sample(player, null, 1.0 / float(Engine.physics_ticks_per_second), _cfg) if player != null else AnimInputs.new()
	inputs.events.clear()
	upper.snap(inputs)
	loco.snap(inputs, _weapon, upper.aim_stance(inputs))
	L.write()
	# 11. Activate, two warm-up advances (plan P12).
	_ok = true
	active = true
	advance(0.0)
	advance(0.0)
	# 12. Command line.
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if TRACE_ARG in args:
		trace = true
	for a in args:
		if String(a).begins_with(RECORD_ARG):
			start_recording(String(a).substr(RECORD_ARG.length()))
	if trace:
		print("[anim] PlayerAnim ready: %s" % [index.summary()])


## The bones the lower-body inputs key (their clips and carry layers): StanceInertializer's set.
func _lower_bones(sk: Skeleton3D, ap: AnimationPlayer) -> PackedInt32Array:
	var clips := {}
	for id in index.lower:
		var rec: Dictionary = index.lower[id]
		if rec.has("instance_of"):
			continue
		clips[String(rec.get("clip", ""))] = true
		for l: Dictionary in rec.get("layers", []):
			clips[String(l.get("clip", ""))] = true
		for h in rec.get("hemis", {}):
			for c in rec.hemis[h].get("clips", []):
				clips[String(c)] = true
			for l: Dictionary in rec.hemis[h].get("layers", []):
				clips[String(l.get("clip", ""))] = true
	var anims: Array = []
	for c in clips:
		if c == "":
			continue
		var p := data.godot_anim(c)
		if ap.has_animation(p):
			anims.append(ap.get_animation(p))
	return StanceInertializer.bones_of(sk, anims)


## Re-links the AnimationPlayer when the tree misses one of its libraries (see setup()).
func _sync_libraries(ap: AnimationPlayer) -> void:
	var have := get_animation_library_list()
	for lib in ap.get_animation_library_list():
		if not have.has(lib):
			var p := anim_player
			anim_player = NodePath()
			anim_player = p
			break
	var missing := []
	have = get_animation_library_list()
	for lib in ap.get_animation_library_list():
		if not have.has(lib):
			missing.append(lib)
	setup_report["libraries"] = Array(have)
	if not missing.is_empty():
		_warn_once("PlayerAnim: the tree does not see the player's libraries %s" % [missing])


func _refuse(reason: String) -> void:
	setup_report["refused"] = reason
	_warnings.append(reason)
	push_error("PlayerAnim.setup: %s; the animation tree stays inactive." % reason)
	active = false


## True once setup() succeeded.
func is_ready() -> bool:
	return _ok


# --- public API -----------------------------------------------------------------------------

## Current weapon (player.gd switch_weapon: after the old weapon's unequip, before the new
## weapon's equip). Applied in order with the weapon signals at the next frame.
func set_weapon(key: String) -> void:
	if not _ok:
		return
	_queue({"t": "weapon", "w": key})


## Graph holster of `weapon_key` (its draw clip backwards over `duration`), for the gameplay to
## call before it swaps the models (see the header). False when holster_enabled() is false.
func play_holster(weapon_key: String, duration: float) -> bool:
	if not _ok or not holster_enabled():
		return false
	_queue({"t": "holster", "w": weapon_key, "d": duration})
	return true


## The later graph stages of a weapon switch (player.gd switch_weapon(), graph-faithful timing):
## stage "holster_finish" (idle-pistol-finish-part: the empty hand back from the holster to idle,
## after play_holster) or "grab" (idle-pistol-grab-part, draw step 1: the hand from idle to the
## next weapon at its holster, before its equip draw) of `weapon_key` over `duration`. False
## when holster_enabled() is false or the weapon has no clip for the stage (switch_stages()
## gives it 0 s then).
func play_switch_stage(weapon_key: String, stage: String, duration: float) -> bool:
	if not _ok or not holster_enabled() or not stage in ["holster_finish", "grab"]:
		return false
	_queue({"t": "switch_stage", "w": weapon_key, "k": stage, "d": duration})
	return true


## The graph weapon key a player roster key plays: the key itself when the graph has rows for
## it, else GRAPH_ALIAS (hook H6 of the weapons workflow) when this script defines one, else the
## key the weapon's action_started is bound with on this PlayerAnim (a weapon installed under
## another roster key, e.g. the over-under, is connected with the musket's key); "" when none.
func graph_key(roster_key: String) -> String:
	if not _ok or roster_key == "":
		return ""
	if index.weapons.has(roster_key):
		return roster_key
	var alias: Variant = (get_script() as Script).get_script_constant_map().get("GRAPH_ALIAS")
	if alias is Dictionary and (alias as Dictionary).has(roster_key) and index.weapons.has(String(alias[roster_key])):
		return String(alias[roster_key])
	var w: Object = _weapons.get(roster_key)
	if w == null and player != null:
		w = player.weapons.get(roster_key)
	if w != null and w.has_signal(&"action_started"):
		for c: Dictionary in w.get_signal_connection_list(&"action_started"):
			var cb: Callable = c.callable
			if cb.get_object() == self and cb.get_method() == &"_on_action":
				var args := cb.get_bound_arguments()
				if args.size() == 1 and index.weapons.has(String(args[0])):
					return String(args[0])
	return ""


## Speed limit (m/s) the gameplay puts on the body this physics tick: through a graph start or stop
## clip the body follows the clip's body speed (LocoBrain.root_motion_speed(), INFERRED from the
## metrics' foot-contact body_profile: the source game's body is taken to follow the animation);
## INF otherwise, before setup, in a start with override_free_start_speed and in a stop with
## override_crisp_stops.
func body_speed_cap() -> float:
	if not _ok or loco == null or (override_free_start_speed and loco.state == LocoBrain.START):
		return INF
	var v := loco.root_motion_speed()
	return v if v >= 0.0 else INF


## options.holster (graph default on; instant_weapon_switch turns it off).
func holster_enabled() -> bool:
	return _ok and upper.holster_enabled()


## The torch toss (push n01b; PlayerTorch, when the player aims a long gun, draws the bow or reloads with the
## torch in the hand): the torch hand's arm swings from the hold down and forward into the source's lowered flashlight
## arm (HandHolds.TOSS_CLIP, mirrored for the right hand) over torch_toss_release_s, emits torch_released there (the
## torch leaves the hand) and fades back to the arm underneath (the aim). False when no torch is in the hand or a toss
## is already running.
func play_torch_toss() -> bool:
	if not _ok or not torch_hand or holds == null:
		return false
	return holds.play_toss()


## Starts the torch hand's throw (the torch mode's; HandHolds.play_throw); torch_released at the release. False
## when it cannot play.
func play_torch_throw() -> bool:
	if not _ok or not torch_hand or holds == null:
		return false
	return holds.play_throw()


## A torch toss is playing (until the arm is back from it).
func torch_tossing() -> bool:
	return holds != null and holds.toss_t >= 0.0


## Names of this node's "Torch" exports (the player's exports of the same names are copied onto them).
func torch_option_names() -> PackedStringArray:
	return _group_names("Torch")


## The "Torch" exports TorchCarryIK reads, onto it (at setup and every step, so a change while the game runs
## shows): {export: TorchCarryIK property}.
const TORCH_IK_OPTIONS := {"torch_tilt_deg": "axe_tilt_deg", "torch_out_deg": "axe_out_deg", "torch_fist": "axe_fist",
		"torch_fist_crouch": "axe_fist_crouch", "torch_raise_fist": "raise_fist"}
## The "Torch" exports GunMiddleCarryIK reads: {export: GunMiddleCarryIK property}.
const MID_IK_OPTIONS := {"gun_mid_pitch_deg": "pitch_deg", "gun_mid_pitch_crouch_deg": "pitch_crouch_deg",
		"gun_balance_m": "balance_m"}


func _torch_ik_options() -> void:
	for f: String in TORCH_IK_OPTIONS:
		torch_ik.set(String(TORCH_IK_OPTIONS[f]), get(f))
	if mid_ik != null:
		for f: String in MID_IK_OPTIONS:
			mid_ik.set(String(MID_IK_OPTIONS[f]), get(f))
	if holds != null:
		holds.axe_swing = torch_arm_swing


## Names of the properties in this node's "Gameplay overrides" export group, in order (the
## player's exports of the same names are copied onto them before setup()).
func gameplay_override_names() -> PackedStringArray:
	return _group_names("Gameplay overrides")


func _group_names(group: String) -> PackedStringArray:
	var out := PackedStringArray()
	var inside := false
	for p in get_property_list():
		var u := int(p.usage)
		if (u & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY)) != 0:
			inside = (u & PROPERTY_USAGE_GROUP) != 0 and String(p.name) == group
			continue
		if inside and (u & PROPERTY_USAGE_EDITOR) != 0:
			out.append(String(p.name))
	return out


## True while the AimStabilizer's aim trim keeps the barrel on the crosshair. It replaces the
## weapons' interim aim_yaw_offset / aim_pitch_offset calibration: player.gd then leaves the body
## facing the camera (no visual yaw) and the pitch offset is not used.
func trims_aim() -> bool:
	return _ok and stabilizer != null and stabilizer.aim_trim


## Hit on the player. local_dir: where it came from (x right, y forward). Heavy: the full-body
## hit reaction; light: the no-arms additive.
func play_hit(local_dir: Vector2, heavy := false) -> void:
	_queue({"t": "hurt", "dir": [local_dir.x, local_dir.y], "a": 60.0 if heavy else 10.0, "heavy": heavy})


func play_death(local_dir := Vector2.ZERO) -> void:
	_queue({"t": "died", "dir": [local_dir.x, local_dir.y]})


func revive() -> void:
	_queue({"t": "revive"})


## Pins the planted feet to the ground under the player while a stance change is inertialized
## (stance_foot_ik). A foot's weight is how planted the target content has it (the animated ball /
## ankle height, read after the advance, before the modifiers), faded out at the end.
func _stance_feet() -> void:
	if stance_foot_ik == null:
		return
	if inertializer == null or not inertializer.running() or player == null or not player.is_on_floor() \
			or not loco.moving:
		# Off between stance changes: TraversalIK keeps per-limb state (its joint-speed limiter covers the
		# arms too) that held the arms back in later fast motions (the aim raise, the recoil) and swung
		# the elbow 40-50 cm sideways in a frame.
		if stance_foot_ik.active:
			stance_foot_ik.pins = []
			stance_foot_ik.reset()
			stance_foot_ik.active = false
		_stance_w = {"l": 0.0, "r": 0.0}
		return
	if not stance_foot_ik.active:
		stance_foot_ik.reset()
		stance_foot_ik.active = true
	var step := STANCE_IK_RATE * maxf(_last_dt, 1.0 / 240.0)
	var env := clampf(inertializer.remaining() / STANCE_IK_FADE_S, 0.0, 1.0)
	var ground := TravSurfaces.ground_plane(player.global_position, player.get_floor_normal(), "stance_ground")
	var pins: Array = []
	for side in ["l", "r"]:
		var ball := _sk.find_bone(side + "_ball")
		var ankle := _sk.find_bone(side + "_ankle")
		if ball < 0 or ankle < 0:
			continue
		var by := _sk.get_bone_global_pose(ball).origin.y
		var ay := _sk.get_bone_global_pose(ankle).origin.y
		var want := maxf(1.0 - smoothstep(STANCE_PLANT_BALL.x, STANCE_PLANT_BALL.y, by),
				1.0 - smoothstep(STANCE_PLANT_ANKLE.x, STANCE_PLANT_ANKLE.y, ay))
		_stance_w[side] = move_toward(float(_stance_w[side]), want, step)
		var w := float(_stance_w[side]) * env
		if w > 0.001:
			pins.append({"limb": side + "_foot", "weight": w, "mode": "plant", "shape": ground})
	stance_foot_ik.pins = pins


## Gameplay override flags (OVERRIDE_FLAGS), facade options (FACADE_OPTIONS; `release_grace_s`
## is an alias of stick_release_grace_s) and graph-table options (options block: blocked,
## weapon_out_fingers, ...). Applied at the next frame, in order with the other events, and
## recorded. Options that change the tree layout (aim_walk) need a new PlayerAnim. Before
## setup() only the exports can be set.
func set_option(name: StringName, value: Variant) -> void:
	if not _ok:
		_set_local(String(name), value)
		return
	_queue({"t": "option", "name": String(name), "value": value})


## Records every frame to `path` (AnimRecorder JSONL). A recording started before the first
## frame replays exactly on a fresh PlayerAnim set up from the same inputs (header start_inputs:
## the sample setup() snapped the controllers to; a rig facade set up without a player starts
## from AnimInputs.new()).
func start_recording(path: String) -> bool:
	if not _ok:
		return false
	if recorder == null:
		recorder = AnimRecorder.new()
	var ok := recorder.start(path, {"from_setup": frame == 0, "start_frame": frame + 1,
			"start_inputs": inputs.to_dict() if inputs != null else {},
			"graph_sha256": FileAccess.get_sha256(data.graph_path) if data.graph_path != "" else "",
			"overrides": _override_state(), "weapon": String(_weapon), "carry_layers": carry_layers,
			"attribution": data.attribution()})
	if ok and trace:
		print("[anim] recording to %s" % path)
	return ok


func stop_recording() -> void:
	if recorder != null:
		recorder.stop()


func is_recording() -> bool:
	return recorder != null and recorder.is_recording()


## Replay / scripted input: source(frame: int) -> AnimInputs (this frame's inputs; its events are
## the edge events; queued weapon / player events still apply), or {"in": AnimInputs or dict,
## "ev": [facade events], "dt": float} (a recorded frame: its events replace the queue and its dt
## the step's), or null (source finished; live sampling resumes). frame = the frame about to run
## (1 = the first frame after setup). An invalid Callable clears the source.
func set_input_source(source: Callable) -> void:
	_source = source


## Runs the physics-tick sampler once (what _physics_process does).
func sample_inputs(dt: float) -> void:
	if not _ok or _source.is_valid():
		return
	inputs = AnimInputs.sample(player, inputs, dt, _cfg)
	_edges.append_array(inputs.events)


## One animation frame (what _process does): events, controllers, selectors, advance.
func manual_step(dt: float) -> void:
	if not _ok:
		return
	frame += 1
	var inp := inputs
	var edges: Array = _edges
	var events: Array = _events
	if _source.is_valid():
		var s: Variant = _source.call(frame)
		if s is AnimInputs:
			inp = s
			edges = inp.events.duplicate()
		elif s is Dictionary:
			var i: Variant = s.get("in")
			inp = i if i is AnimInputs else AnimInputs.from_dict(i if i is Dictionary else {})
			edges = inp.events.duplicate()
			events = []
			for e in s.get("ev", []):
				events.append(e)
			if s.has("dt"):
				dt = float(s.dt)
		else:
			_source = Callable()
		inputs = inp
	_edges = []
	_events = []
	_time += dt
	for e: Dictionary in events:
		_apply_event(e)
	loco.tick(inp, edges, dt, _weapon, upper.aim_stance(inp))
	if loco.inertia_request > 0.0:
		if inertializer != null:
			inertializer.start(loco.inertia_request)
			if stance_foot_ik != null:
				stance_foot_ik.reset()
		loco.inertia_request = 0.0
	upper.lower_moving = loco.moving
	upper.tick(_aim_carried(inp, dt), loco.state, dt, loco.carry_inputs())
	L.update(dt)
	L.write()
	advance(dt)
	if inertializer != null:
		inertializer.tick(dt)
	_last_dt = dt
	_stance_feet()
	var long_gun := String(_weapon) in LEFT_GRIP_WEAPONS
	var busy := upper.action_playing() or (player != null and player.is_switching())
	# the long gun's left hand (long_gun_move_carry; the relaxed one-hand carry after relax_after_s)
	var aiming := upper.upper_aim_w() >= 0.05
	# (the aim asked for counts: with the gun in the left hand the aim waits for it to come back, Weapon.aim_hold)
	var aim_wanted := player != null and player.weapon != null and player.weapon.active and player.weapon.wants_aim()
	if not long_gun or busy or aiming or aim_wanted:
		_no_aim_t = 0.0
		relaxed = false
	elif relax_after_s > 0.0:
		_no_aim_t += dt
		if _no_aim_t >= relax_after_s:
			relaxed = true
	var moving_carry := long_gun and loco.moving and not busy and not aiming
	var mode := long_gun_move_carry
	# The torch (push n01b, reworked by n01c): HandHolds puts it in the hand the weapon does not need (with a long gun
	# the right hand, the gun in the left hand gripped in the middle), jumps too (the user's rule for jumps is both
	# hands on the rifle, except with the torch).
	var torch := torch_hand or torch_tossing()
	var airborne := loco.state in LocoBrain.AIRBORNE
	# Jumping with a long gun (user 2026-09-25): the graph's take-off has no rifle arms layer (the jump has),
	# so the right hand swung the gun down behind: through the take-off both arms hold it as the carry's arms
	# layer does (TAKEOFF_ARMS).
	var gun_free := long_gun and not busy and not aiming and not hands_free
	# The one-hand carry shows only while crouch-moving (user 2026-09-25: "i only want one hand movement in
	# crouch"; standing, walking and running keep both hands on the gun): the LEFT hand holds the gun in the middle
	# and the right hand is free (push n01c, user 2026-09-26: "yes i want the middle grip on the crouch walk as well",
	# "allows user to have the right hand to throwables and easily switch back to rifle"; HandHolds, GunMiddleCarryIK).
	if not airborne:
		one_hand = relaxed and loco.moving and String(loco.stance) == "crouch"
	elif not relaxed:
		one_hand = false
	# every jump keeps both hands on the gun (user 2026-09-25: "keep the hands on the rifle"), in at once: the
	# arms take over from the pose shown (LeftArmPose.take_over(), then cross-fade to the carry arms). A quick
	# fade in (0.06 s) showed the take-off's own drop of the arm layer for a frame and then pulled the arm back
	# (test_continuity's storm: the right shoulder and elbow at 47-64 rad/s at take-offs, push n09).
	var takeoff_two := gun_free and airborne and not torch
	if takeoff_two or torch:
		one_hand = false
	var owned := {"l": false, "r": false}
	if holds != null:
		_torch_ik_options()
		owned = holds.step(dt, {"long_gun": long_gun, "gun_free": gun_free, "busy": busy, "aiming": aiming,
				"one_hand": one_hand, "airborne": airborne, "crouch": String(loco.stance) == "crouch", "moving": loco.moving})
	var mid := mid_ik != null and (mid_ik.on or mid_ik.progress > 0.0)
	var air_one := false
	var change_hold := gun_free and loco.state == LocoBrain.CCHANGE and not torch and not mid
	var take_over := (takeoff_two and not _takeoff_was) or (change_hold and not _change_hold_was)
	var take_over_s := STANCE_ARM_XFADE_S if change_hold else LeftArmPose.SOURCE_XFADE_S
	_takeoff_was = takeoff_two
	_change_hold_was = change_hold
	for arm in [left_arm, right_arm]:
		if arm != null and not owned.get("l" if arm == left_arm else "r", false):
			arm.fade_s = LeftArmPose.FADE_S    # (HandHolds sets the arms it owns: the torch's, the gun in the left hand)
	# The two-hand carries: the left arm is the source's own two-hand carry arm (standing
	# actor_b-p-rifle-run-arms: the idle's, jog's and sprint's; crouched actor_b-p-rifle-crouch-idle-arms still,
	# actor_b-p-rifle-crouch-run-arms moving: the elbow down and a little out), which LeftGripIK closes onto the
	# gun. The graph plays the moving carries' arm layers at 0.8-0.9 over the empty-handed arm swing, walking it
	# plays the source's one-hand carry (actor_b-p-rifle-idle-arms: the left hand off the gun), and its idle
	# turns and in-place crouch change have no rifle arm at all: the hand swung 13-35 cm off the gun and the
	# crouch-walk elbow swung round in front of the chest (user 2026-09-25: "the gun bounces in the left hand
	# when we move", "the left elbow is inward and not out ward"; walking keeps both hands on the gun, as the
	# user asked for every standing carry). The idles already play these arms at full weight (unchanged), and
	# with the arm kept on through starts and stops no fade shows the one-hand walk arm in between. (The other
	# long_gun_move_carry modes keep their moving-only arm.)
	var grip_arm := gun_free and (mode == "source" or moving_carry)
	# the run hold (long_gun_run_hold): both arms keep the gun in front while running and sprinting
	# (by the body's speed, with a margin: on from RUN_HOLD_ON_MS at a run or sprint, kept until it is under
	# RUN_HOLD_OFF_MS, so a walk key or a stop at speed does not drop the arms back to the graph's carry at once)
	var hold_ok := long_gun_run_hold != "graph" and gun_free and mode == "source" and not airborne \
			and String(loco.stance) != "crouch" and not torch and not mid and not one_hand and not change_hold
	var body_v := player.horizontal_speed() if player != null else (RUN_HOLD_ON_MS if loco.moving else 0.0)
	# (moving backward the hold is on from the first steps: the gun is low ready at once, not port arms until the body
	# has reached a run's speed; user 2026-09-30)
	var back := loco.hemi == &"bw" and loco.moving
	var on_v := RUN_BACK_HOLD_ON_MS if back else RUN_HOLD_ON_MS
	var off_v := RUN_BACK_HOLD_OFF_MS if back else RUN_HOLD_OFF_MS
	# (a stop keeps the hold it has: the body's speed falling through the hold's threshold would drop the arms to the graph's carry
	# and bring them back at rest, the blend from the jog to the stop that was not clean; user 2026-09-30)
	var stopping := String(loco.state) == "STOP"
	if not hold_ok or (body_v < off_v and not stopping):
		_run_hold_on = false
	elif loco.moving and (String(loco.mode) in ["run", "sprint"] or (back and String(loco.mode) == "walk")) and body_v >= on_v:
		_run_hold_on = true
	# (standing still, and through a stop, the gun is at medium ready: the low ready is the backward walk's; user 2026-09-30)
	if hold_ok and (not loco.moving or stopping):
		_run_hold_on = true
		_run_hold_gait = "mid"
	var run_hold := _run_hold_on
	if run_hold and loco.moving and (String(loco.mode) in ["run", "sprint"] or (back and String(loco.mode) == "walk")):
		# (moving backward holds the gun low like the sprint does, not at port arms: user 2026-09-30, "backwards rifle
		# walk doesn't have the rifle low like the sprint in forward")
		_run_hold_gait = "low" if back else ("sprint" if String(loco.mode) == "sprint" else "run")
	var run_clip := _run_hold_clip(_run_hold_gait)
	# a one-handed weapon aimed: the left arm off it, hanging as it does in the relaxed swing
	var one_hand_aim := one_hand_aim_on and String(_weapon) in ONE_HAND_AIM_WEAPONS and (aiming or aim_wanted) and not busy and not hands_free and not torch
	if left_arm != null and not owned.l:
		left_arm.enabled = hands_free or takeoff_two or grip_arm or one_hand_aim
		if left_arm.enabled or left_arm.weight > 0.0:
			if takeoff_two:
				left_arm.set_sources(TAKEOFF_ARMS, _clip_sources(TAKEOFF_ARMS))
			elif one_hand_aim:
				left_arm.set_sources("one_hand_aim/" + String(loco.stance), _one_hand_left_sources(), STANCE_ARM_XFADE_S)
			elif hands_free or mode == "one_hand":
				left_arm.set_sources("free", _relax_sources())
			elif mode == "source":
				var grip_clip := run_clip if run_hold else TAKEOFF_ARMS
				if String(loco.stance) == "crouch":
					grip_clip = (CROUCH_GRIP_ARMS if loco.hemi == &"bw" else CROUCH_GRIP_ARMS_FW) if loco.moving else CROUCH_IDLE_ARMS
				left_arm.set_sources(grip_clip, _clip_sources(grip_clip), STANCE_ARM_XFADE_S)
			else:
				left_arm.set_sources("grip", _arm_layer_sources())
			if take_over and left_arm.enabled:
				left_arm.take_over(take_over_s)
		left_arm.advance(dt)
	if right_arm != null and not owned.r:
		# The graph's in-place crouch change (CCHANGE; a stand-in clip, the source's own change is missing from the
		# data) swings the gun 25-35 cm in its first 0.1 s: the right arm keeps the carry's two-hand arm of the
		# stance meanwhile, in at once from the pose shown (change_hold, take_over()).
		right_arm.enabled = hands_free or takeoff_two or air_one or change_hold or run_hold
		if run_hold or (_right_src == run_clip and not (hands_free or takeoff_two or air_one or change_hold)):
			right_arm.fade_s = RUN_HOLD_FADE_IN_S if run_hold else RUN_HOLD_FADE_OUT_S
		if run_hold:
			_right_src = run_clip
		elif takeoff_two:
			_right_src = TAKEOFF_ARMS
		elif air_one:
			_right_src = AIR_RIFLE_ARM
		elif change_hold:
			_right_src = CROUCH_IDLE_ARMS if String(loco.stance) == "crouch" else TAKEOFF_ARMS
		elif hands_free:
			_right_src = ""
		if right_arm.enabled or right_arm.weight > 0.0:
			if _right_src == "":
				right_arm.set_sources("free", _relax_sources())
			else:
				right_arm.set_sources(_right_src, _clip_sources(_right_src),
						STANCE_ARM_XFADE_S if change_hold else LeftArmPose.SOURCE_XFADE_S)
			if take_over and right_arm.enabled:
				right_arm.take_over(take_over_s)
		right_arm.advance(dt)
	if trigger_finger != null:
		# (the musket held as the gun: carried, aimed and fired; off for the reload, the switch, the free hands, the
		# middle carry and the torch)
		var reloading := player != null and player.weapon is Firearm and (player.weapon as Firearm).state == Firearm.State.RELOADING
		trigger_finger.wanted = String(_weapon) == "musket" and not (one_hand or hands_free or torch or mid or reloading) \
				and not (player != null and player.is_switching())
		if right_seat != null:
			right_seat.wanted = trigger_finger.wanted
	if left_grip != null:
		if one_hand or hands_free or torch or mid:
			left_grip.enabled = false
		else:
			match mode:
				"source":
					# every two-hand carry, standing or crouched, still or moving, on the ground or in a jump
					# (user 2026-09-25: "the gun bounces in the left hand when we move": the moving carries play
					# their arm layers at 0.8-0.9 and the hand slid 13-35 cm along the gun); where the source holds
					# the gun with both hands (the idles) this moves nothing; while aiming the source holds it
					left_grip.enabled = long_gun and not busy and not aiming
				"one_hand":
					left_grip.enabled = long_gun and not busy and not moving_carry
				_:
					left_grip.enabled = long_gun and not busy
		# walking or jogging: the gun carried a little further out, the left arm reaching forward to it
		# (LeftGripIK.moving). On with the first step (the locomotion's own moving, not a speed reached a step later:
		# the arm drifted out after the body and the elbow looked loose, user 2026-09-29 "the elbow is not stiff when
		# movement starts"), quickly and eased (LeftGripIK smoothsteps it), never a pop.
		var walk_w := 1.0 if (moving_carry and not (player != null and player.is_crouching)) else 0.0
		left_grip.moving = move_toward(left_grip.moving, walk_w, dt / 0.22)
		left_grip.advance(dt)
	if gun_damper != null:
		# (with the gun in the left hand, GunMiddleCarryIK's own spring smooths it in the character's frame; on the way
		# back, from the moment the gun is in the right hand again (the handoff's travel done), this damper takes over:
		# waiting for the handoff's end left it fading in only as the stop's cross-fade of the carry ended, a 0.9 m/s
		# pop of the gun at a crouch-walk stop, test_weapon_holds one_crouch_stop)
		var mid_back: bool = mid and not mid_ik.on and float(GunMiddleCarryIK.weights(mid_ik.progress)[2]) <= 0.0
		gun_damper.enabled = gun_free and not torch and (not mid or mid_back)
		gun_damper.advance(dt)
	if _resume_snap:
		# back from a traversal move or the saddle: the weights the modifiers were left with are stale
		_resume_snap = false
		for m in [left_arm, right_arm, left_grip, gun_damper]:
			if m != null:
				m.snap()
		if holds != null:
			holds.snap()
	upper.post_advance()
	if recorder != null and recorder.is_recording():
		recorder.record(frame, inp, events, AnimRecorder.pose_hash(_sk), dt, edges)


## Weapon switch while aimed: Weapon.unequip() drops the old weapon's aim to 0 and the new
## weapon starts lowered, so the upper aim weight would fall from up to 1 to 0 in one frame (the
## arms snap from the aim pose to the carry pose). The aim weight at the switch is carried over
## instead and lowered over the weapon crossfade (tuning weapon_fade_s), while the aim tree and
## the carry layers fade to the new weapon (a Frontier input condition for UpperBody only, not a
## graph rule: the graph would holster first; LocoBrain and the recorder see the raw samples).
func _aim_carried(inp: AnimInputs, dt: float) -> AnimInputs:
	if _aim_hold <= 0.0:
		return inp
	_aim_hold = maxf(_aim_hold - dt / maxf(float(data.tuning("weapon_fade_s", 0.25)), 1e-3), 0.0)
	# THROW2 fix 2: only a sample taken after the switch ends the hold. A switch made after this frame's physics
	# sample (a call from _process: tests, scripts) left the old weapon's aim in the sample, which ended the hold
	# at once, and the arm snapped from the aim pose to the new weapon's carry on the next frame (0.6 m).
	if _aim_hold <= inp.weapon_aim and inp.frame > _aim_hold_frame:
		_aim_hold = 0.0
		return inp
	var c := AnimInputs.from_dict(inp.to_dict())
	c.events = inp.events
	c.weapon_aim = _aim_hold
	return c


func _physics_process(delta: float) -> void:
	if auto_process:
		sample_inputs(delta)


func _process(delta: float) -> void:
	if auto_process:
		manual_step(delta)


func _exit_tree() -> void:
	stop_recording()


# --- debug ----------------------------------------------------------------------------------

## Plan section 9: pure data for the overlay and the tests.
func debug_snapshot() -> Dictionary:
	if not _ok:
		return {"ok": false, "warnings": Array(_warnings), "setup": setup_report}
	var inp := inputs if inputs != null else AnimInputs.new()
	var ls := loco.snapshot()
	var us := upper.snapshot()
	var derived: Dictionary = loco.derived()
	derived.merge({"upper_aim_w": upper.upper_aim_w(), "aim_stance": upper.aim_stance(inp), "up_w": us.up_w,
			"down_w": us.down_w, "blocked_w": us.blocked_w, "suppress": us.suppress, "stabilizer_deg": us.stabilizer_deg,
			"trim_deg": us.trim_deg, "elev_deg": us.elev_deg, "charge": us.charge}, true)
	var lower := {"state": String(loco.state), "graph_state": loco.graph_state, "time_in_state": loco.time_in_state,
			"phase": loco.phase(), "input_id": String(loco.input_id), "mode": String(loco.mode), "hemi": String(loco.hemi),
			"stance": loco.stance, "aimed": loco.aimed, "selector": L.snapshot(), "hemis": ls.get("hemis", {}),
			"held": ls.get("held", []), "landing": ls.get("landing", {})}
	var up := {"weapon": us.weapon, "stance": us.stance, "A": us.A, "G": us.G, "W": us.W,
			"active_oneshots": us.active_oneshots, "pending": us.pending, "holster": us.holster, "aim_key": us.aim_key,
			"throw": us.get("throw", {}),
			"dead": us.dead, "trace": us.trace}
	return {"ok": true, "frame": frame, "time": _time, "inputs": inp.to_dict(), "derived": derived, "lower": lower,
			"upper": up, "slots": _slots(), "provenance": _provenance(), "trace": loco.trace(),
			"trace_lines": _trace_lines.duplicate(), "options": _options_snapshot(), "warnings": Array(_warnings),
			"recording": recorder.path if is_recording() else "", "tree": index.summary(),
			"attribution": data.attribution()}


## The last TRACE_KEEP transition lines in the --anim-trace format (kept when tracing is off).
func trace_lines() -> Array[String]:
	return _trace_lines.duplicate()


## Weighted lower inputs: [{node, hemi, clip, position (s), length (s), rate (x real time), weight, role_key}].
func _slots() -> Array:
	var out: Array = []
	var ci := loco.carry_inputs()
	var input_w: Dictionary = ci.get("input_w", {})
	for id in input_w:
		var w := float(input_w[id])
		var rec := index.lower_record(StringName(id))
		if rec.is_empty():
			continue
		var key := _role_key(rec)
		if rec.has("hemis"):
			var hw: Dictionary = ci.get("hemi_w", {}).get(id, {"fw": 1.0})
			for h in rec.hemis:
				var hwt := float(hw.get(h, 0.0))
				if hwt <= 0.0:
					continue
				var hr: Dictionary = rec.hemis[h]
				var length := float(hr.get("lengths", [0.0])[0])
				var ts := float(get(hr.ts)) if hr.has("ts") else 0.0
				out.append({"node": String(rec.get("node", "L__" + id)), "hemi": h, "clip": String(hr.get("clips", [""])[0]),
						"position": index.phase(self, StringName(id), h) * length, "length": length, "rate": ts * length,
						"weight": w * hwt, "role_key": key})
		else:
			var length := float(rec.get("length", 0.0))
			var ts := float(get(rec.ts)) if rec.has("ts") else 0.0
			out.append({"node": String(rec.get("node", "L__" + id)), "hemi": "", "clip": String(rec.get("clip", "")),
					"position": index.phase(self, StringName(id)) * length, "length": length, "rate": ts * length,
					"weight": w, "role_key": key})
	return out


## The current weapon's carry ARM layers of the weighted lower inputs, as LeftArmPose sources
## ([{anim, time, w}]): each layer's clip at its input's phase, weighted like its input.
func _arm_layer_sources() -> Array:
	var out: Array = []
	if _ap == null:
		return out
	var ci := loco.carry_inputs()
	var input_w: Dictionary = ci.get("input_w", {})
	for id in input_w:
		var w := float(input_w[id])
		if w <= 0.0:
			continue
		var rec := index.lower_record(StringName(id))
		if rec.is_empty():
			continue
		var groups: Array = []
		if rec.has("hemis"):
			var hw: Dictionary = ci.get("hemi_w", {}).get(id, {"fw": 1.0})
			for h in rec.hemis:
				if float(hw.get(h, 0.0)) > 0.0:
					groups.append([rec.hemis[h].get("layers", []), w * float(hw.get(h, 0.0)), index.phase(self, StringName(id), h)])
		else:
			groups.append([rec.get("layers", []), w, index.phase(self, StringName(id))])
		for g: Array in groups:
			for l: Dictionary in g[0]:
				if String(l.get("weapon", "")) != String(loco.weapon) or String(l.get("slot", "")) != "arms" \
						or String(l.get("kind", "")) != "partial":
					continue
				var nm := data.godot_anim(String(l.clip))
				if not _ap.has_animation(nm):
					continue
				var a := _ap.get_animation(nm)
				out.append({"anim": a, "time": fposmod(float(g[2]), 1.0) * a.length, "w": float(g[1])})
	return out


## The source's rifle arm in the air (a one-pose right-arm partial of the fall): the relaxed carry's jump.
const AIR_RIFLE_ARM := "actor_b-p-fall--rifle-part"
## The long gun's carry arms layer (both hands on the gun), held through the graph's take-off; also the
## standing two-hand grip arm of the moving carries (the left arm, closed onto the gun by LeftGripIK).
const TAKEOFF_ARMS := "actor_b-p-rifle-run-arms"
## The standing hold's arms (long_gun_run_hold "idle", and "port_low" at a sprint: low ready).
const IDLE_HOLD_ARMS := "actor_b-p-rifle-idle-arms"
## Our own low ready (tools/anim_author/author_locomotion.gd: the standing hold's arms turned down at the shoulders): standing
## still and moving backward, where the body does not lean into the sprint's low carry (user 2026-09-30: "idle low ready",
## "backwards like the sprint's rifle low").
const LOW_READY_ARMS := "own-rifle-low-ready"
## Our own medium ready (the standing hold's arms turned down part of the way): standing still and through the stop.
const MID_READY_ARMS := "own-rifle-mid-ready"
## The run hold's speed margin (m/s): on from this at a run or sprint ...
const RUN_HOLD_ON_MS := 2.4
## ... off under this.
const RUN_HOLD_OFF_MS := 1.9
## Moving backward the hold comes on from the first steps and stays until the body is nearly still.
const RUN_BACK_HOLD_ON_MS := 0.4
const RUN_BACK_HOLD_OFF_MS := 0.25
## The run hold's arms fade in over this (during a start: the start clip moves the arms too) ...
const RUN_HOLD_FADE_IN_S := 0.5
## ... and out over this (LeftArmPose.FADE_S is 0.25).
const RUN_HOLD_FADE_OUT_S := 0.35
var _run_hold_on := false
var _run_hold_gait := "run"


## The arms clip both arms hold the long gun with while running (`gait` "run") or sprinting (long_gun_run_hold).
func _run_hold_clip(gait: String) -> String:
	match long_gun_run_hold:
		"idle":
			return IDLE_HOLD_ARMS
		"port_low":
			if gait == "low":
				return LOW_READY_ARMS
			if gait == "mid":
				return MID_READY_ARMS
			return IDLE_HOLD_ARMS if gait == "sprint" else TAKEOFF_ARMS
	return TAKEOFF_ARMS
## The crouched two-hand grip arm of the moving carries (the crouch-walk carry's arms layer, one pose), and
## of the crouch idle (its arms layer, one pose: the in-place crouch change ends on it).
## Our own medium ready, backward and forward (tools/anim_author/author_locomotion.gd: the crouch run arms turned down at the shoulders).
const CROUCH_GRIP_ARMS := "own-rifle-crouch-mid"
const CROUCH_GRIP_ARMS_FW := "own-rifle-crouch-mid-fw"
## Our own crouch idle arms: the graph's with the right hand drawn toward the right hip (tools/anim_author/author_locomotion.gd).
const CROUCH_IDLE_ARMS := "own-rifle-crouch-idle"
## Seconds the grip arms take from one stance's to the other's (the musket turns 40-60 deg between them).
const STANCE_ARM_XFADE_S := 0.35
## The one-hand crouch-move hold (push n01): the source's rifle arm for moving crouched along low cover (the
## left hand on the cover, the rifle held down in the right hand at the side, the muzzle forward and down;
## a 1 s loop at the crouch-walk's phase). The source's crouch-walk carry holds the gun across the chest with
## both hands; with the left hand let go it rode up at the chest (muzzle up 40 deg) in the right hand alone.
const ONE_HAND_LOW_ARM := "actor_b-p-rifle-cover-low-left-fw--arms"
var _right_src := ""               ## the clip the right arm pose shows ("" = the lower-body clips)
var _takeoff_was := false          ## last frame's two-hand jump hold (its first frame takes the arms over)
var _change_hold_was := false      ## last frame's in-place crouch change hold (likewise)
## One clip as an arm pose source, at `phase` (0..1) of its length (its first frame by default).
func _clip_sources(clip: String, phase := 0.0) -> Array:
	if _ap == null:
		return []
	var nm := data.godot_anim(clip)
	if not _ap.has_animation(nm):
		return []
	var a := _ap.get_animation(nm)
	return [{"anim": a, "time": fposmod(phase, 1.0) * a.length, "w": 1.0}]


## The hanging idle arm, for the left arm of a one-handed aim.
func _one_hand_left_sources() -> Array:
	if String(loco.stance) == "crouch":
		return _clip_sources(ONE_HAND_LEFT_ARM_CROUCH)
	return _clip_sources(one_hand_left_arm, one_hand_left_phase)


## The lower-body clips playing now, as LeftArmPose sources: [{anim, time, w}] (the free arm).
func _relax_sources() -> Array:
	var out: Array = []
	if _ap == null:
		return out
	for sl: Dictionary in _slots():
		var nm := data.godot_anim(String(sl.clip))
		if not _ap.has_animation(nm):
			continue
		out.append({"anim": _ap.get_animation(nm), "time": float(sl.position), "w": float(sl.weight)})
	return out


## The role key of a lower input for the current weapon and mode ("<w>/<m>/<role>").
func _role_key(rec: Dictionary) -> String:
	var keys: Array = rec.get("keys", [])
	if rec.has("instance_of"):
		keys = index.lower_record(StringName(rec.instance_of)).get("keys", [])
	var pre := "%s/%s/" % [loco.weapon, loco.mode]
	for k in keys:
		if String(k).begins_with(pre):
			return String(k)
	var pw := "%s/" % loco.weapon
	for k in keys:
		if String(k).begins_with(pw):
			return String(k)
	return String(keys[0]) if not keys.is_empty() else ""


## Graph provenance of the dominant lower input and the current aim base.
func _provenance() -> Dictionary:
	var out := {}
	var rec := index.lower_record(L.dominant())
	var key := _role_key(rec)
	if key != "":
		var role: Dictionary = data.graph.get("roles", {}).get(key, {})
		if role.is_empty() and rec.has("hemis") and not rec.hemis.is_empty():
			var h: Dictionary = rec.hemis.get(String(loco.hemi), rec.hemis.values()[0])
			var center := String(h.get("roles", [""])[0])
			key = "%s/%s/%s" % [key.get_slice("/", 0), key.get_slice("/", 1), center]
			role = data.graph.get("roles", {}).get(key, {})
		if not role.is_empty():
			out[key] = _prov_entry(role)
	if upper.weapon != &"":
		var base: Dictionary = data.aim_tree(String(upper.weapon), upper.stance).get("base", {})
		if not base.is_empty():
			out["aim/%s/%s/base" % [upper.weapon, upper.stance]] = _prov_entry(base)
	return out


func _prov_entry(role: Dictionary) -> Dictionary:
	var clip := String(role.get("clip", "")) if role.get("clip") is String else ""
	var ci := data.clip_info(clip) if clip != "" else {}
	return {"state": role.get("state", ""), "state_offset": role.get("state_offset", ""), "leaf": role.get("leaf", ""),
			"leaf_id": role.get("leaf_id", ""), "clip": clip, "status": role.get("status", ""), "chain": role.get("chain", []),
			"layers": role.get("layers", []), "native_asset_id": ci.get("native_asset_id", ""),
			"source_attribution": ci.get("source_attribution", "")}


func _override_state() -> Dictionary:
	var o := {}
	for f in OVERRIDE_FLAGS:
		o[f] = bool(get(f))
	for f in FACADE_OPTIONS:
		o[f] = get(f)
	return o


func _options_snapshot() -> Dictionary:
	var opts := {}
	for k in data.graph.get("options", {}):
		opts[k] = data.option(String(k))
	return {"overrides": _override_state(), "options": opts, "carry_layers": carry_layers,
			"aim_trim": stabilizer.aim_trim if stabilizer else false, "holster_enabled": holster_enabled()}


# --- events ---------------------------------------------------------------------------------

func _queue(e: Dictionary) -> void:
	_events.append(e)


func _on_fired(weapon_key: String) -> void:
	_queue({"t": "fired", "w": weapon_key})


func _on_action(key: String, duration: float, weapon_key: String) -> void:
	_queue({"t": "action", "k": key, "d": duration, "w": weapon_key})


func _on_action_cancelled(weapon_key: String) -> void:
	_queue({"t": "cancel", "w": weapon_key})


## ThrowChain's release frame: the active weapon playing under that graph key lets go.
func _on_throw_released(weapon_key: StringName) -> void:
	for k in (_weapons if drive_throw_release else {}):
		var w: Object = _weapons[k]
		if w == null or not bool(w.get("active")) or not w.has_method("release_from_animation"):
			continue
		if String(k) == String(weapon_key) or graph_key(String(k)) == String(weapon_key):
			w.call("release_from_animation")
			break
	throw_released.emit(weapon_key)
	if trace:
		print("[anim] [f %d] throw release %s" % [frame, weapon_key])


func _on_player_hurt(local_dir: Vector2, amount: float, heavy: bool) -> void:
	_queue({"t": "hurt", "dir": [local_dir.x, local_dir.y], "a": amount, "heavy": heavy})


func _on_player_died(local_dir: Vector2) -> void:
	play_death(local_dir)


func _on_player_respawned() -> void:
	revive()


func _apply_event(e: Dictionary) -> void:
	match String(e.get("t", "")):
		"weapon":
			var w := StringName(String(e.get("w", "")))
			if index.weapons.has(String(w)):
				if w != _weapon and _weapon != &"":
					_aim_hold = maxf(_aim_hold, upper.upper_aim_w())
					_aim_hold_frame = inputs.frame if inputs != null else -1
				_weapon = w
				upper.set_weapon(w)
			else:
				_warn_once("PlayerAnim: unknown weapon '%s'" % w)
		"fired":
			upper.on_fired(StringName(String(e.get("w", _weapon))))
		"action":
			upper.on_action(String(e.get("k", "")), float(e.get("d", 0.0)), StringName(String(e.get("w", _weapon))))
		"cancel":
			upper.on_action_cancelled(StringName(String(e.get("w", _weapon))))
		"holster":
			# WP7: player.gd switches `weapon` (aim 0) when the holster starts and sends set_weapon
			# only when it ends, so the aim at the switch is carried over here (_aim_carried).
			_aim_hold = maxf(_aim_hold, upper.upper_aim_w())
			_aim_hold_frame = inputs.frame if inputs != null else -1
			upper.on_holster(StringName(String(e.get("w", _weapon))), float(e.get("d", 0.0)))
		"switch_stage":
			upper.on_switch_stage(StringName(String(e.get("w", _weapon))), String(e.get("k", "")), float(e.get("d", 0.0)))
		"hurt":
			var d := _v2(e.get("dir", [0, 0]))
			var heavy := bool(e.get("heavy", false))
			if heavy:
				loco.play_hit(d)
			upper.on_hurt(d, float(e.get("a", 0.0)), heavy)
		"died":
			var d := _v2(e.get("dir", [0, 0]))
			loco.play_death(d)
			upper.on_died(d)
		"revive":
			loco.revive()
			# the inputs were sampled at the last physics tick, maybe still dead: a respawn in _process before this
			# frame's step (DeathRule) then played the death again at once (loco's alive rule) (2026-09-27)
			if inputs != null and not _source.is_valid():
				inputs.alive = true
			upper.on_revive()
		"option":
			_apply_option(String(e.get("name", "")), e.get("value"))
		_:
			_warn_once("PlayerAnim: unknown event %s" % [e])


static func _v2(a: Variant) -> Vector2:
	if a is Vector2:
		return a
	if a is Array and (a as Array).size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO


# --- options ----------------------------------------------------------------------------------

func _export_changed(name: StringName, value: Variant) -> void:
	if _applying:
		return
	if _ok:
		_queue({"t": "option", "name": String(name), "value": value})


## Applies an option now (event application; also updates the matching export).
func _apply_option(name: String, value: Variant) -> void:
	_set_local(name, value)
	if name in OVERRIDE_FLAGS:
		data.set_override(name, bool(value))
	elif name == "join_fade_s":
		loco.join_fade_s = float(value)
	elif name == "stick_release_grace_s" or name == "release_grace_s":
		loco.release_grace_s = float(value)
	elif name == "blocked":
		_cfg["blocked"] = bool(value)
		data.set_option(name, value)
	elif name == "strict_graph_cuts":
		upper.strict_graph_cuts = bool(value)
	elif name == "override_free_start_speed":
		pass    # read by body_speed_cap() (the export was set above)
	elif name == "override_crisp_stops":
		loco.stop_root_motion = not bool(value)
	elif name == "override_start_rate_boost":
		loco.start_rate_boost = bool(value)
	elif name == "crouch_pending_while_moving":
		loco.crouch_pending_while_moving = bool(value)
	elif name == "crouch_crossfade_blend":
		loco.crouch_crossfade_blend = bool(value)
	elif name == "instant_weapon_switch":
		if bool(value):
			data.set_option("holster", false)
		else:
			data.clear_option("holster")
	else:
		if name == "aim_walk":
			_warn_once("PlayerAnim: options.aim_walk changes the tree layout; it applies to a new PlayerAnim only")
		data.set_option(name, value)
	if trace:
		print("[anim] [f %d] option %s = %s" % [frame, name, value])


## Sets the export behind an option without queueing it again.
func _set_local(name: String, value: Variant) -> void:
	var prop := "stick_release_grace_s" if name == "release_grace_s" else name
	if prop in OVERRIDE_FLAGS or prop in FACADE_OPTIONS:
		_applying = true
		set(prop, value)
		_applying = false


## The exports' values into the table (setup).
func _apply_exports_to_data() -> void:
	for f in OVERRIDE_FLAGS:
		data.set_override(f, bool(get(f)))
	if instant_weapon_switch:
		data.set_option("holster", false)


# --- trace ------------------------------------------------------------------------------------

func _on_loco_transition(from: StringName, to: StringName, info: Dictionary) -> void:
	var inp := inputs if inputs != null else AnimInputs.new()
	var line := "[f %d] %s(%s,%s) %s -> %s %s  moving=%s (wish %.2f v %.2f) key=%s graph %s %s/%s %s%s" % [
			frame, from, info.get("mode", ""), info.get("hemi", ""), info.get("from_graph", ""), to, info.get("to_graph", ""),
			loco.moving, inp.wish_local.length(), inp.speed, info.get("key", ""),
			info.get("record", "") if String(info.get("record", "")) != "" else "-",
			_fmt_fade(info.get("fade_graph", 0.0)), _fmt_fade(info.get("fade_used", 0.0)), info.get("status", ""),
			(" override=" + String(info.override)) if String(info.get("override", "")) != "" else ""]
	_trace_lines.append(line)
	while _trace_lines.size() > TRACE_KEEP:
		_trace_lines.pop_front()
	if trace:
		print("[anim] " + line)
	anim_transition.emit(from, to, info)


static func _fmt_fade(v: Variant) -> String:
	var f := float(v)
	if f == 0.0:
		return "0"
	return ("%.3f" % f).rstrip("0").rstrip(".")


func _warn_once(msg: String) -> void:
	if _warnings.has(msg):
		return
	_warnings.append(msg)
	push_warning(msg)
