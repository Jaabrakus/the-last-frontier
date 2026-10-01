class_name LocoBrain
extends RefCounted
## Lower-body controller (plan section 6.4, WP4). It chooses the lower-body input of the player
## tree (selector L over the TreeBuilder inputs L__<id>) and drives the bank internals: the
## hemisphere Blend2 of every move / start / stop / reversal bank, its direction weights, its
## playback rate and its seeks.
##
## Graph-faithful by default. The lower-body states are the graph's own states (graph_states of
## animations/actor_b_graph.json: idle, run-fw / run-bkwd, the start states idle^run-fwd / -bkwd,
## the stops run-fw^idle / run-bk^idle, the reversals with their -begin shims, the idle turns,
## the air states, every landing, the crouch change, the aim states), and each tick the current
## state's transition records are evaluated in source order, first match wins, as the graph does:
##   - request "auto" records fire on their conditions; other records only when the Frontier code
##     layer posts that request this tick (see "Requests");
##   - conditions: phase gates (normalized phase of the state's input), frame gates (frames since
##     entry at gates.land_move_gate.fps = 30 Hz, INFERRED), the "secondary variable" (move
##     direction, INFERRED), and the decoded lambda expressions (evaluated with Godot Expression
##     over the graph field names below);
##   - fades and gates come from transitions[key] via AnimGraphData.transition_use(key, record),
##     so every enabled gameplay override applies (all off by default); a record that no row
##     lists (a gap in WP1's bindings) plays with its own fade and gates under the explicit key
##     "graph_record" (LOCAL_ROWS, status graph), so no transition is ever emitted without a key;
##   - a record whose target has no input (no Actor_B clip, an option off, or a state Frontier
##     does not have: cover, peek, vault, ...) is skipped, as an unavailable target;
##   - a self re-entry into identical content (e.g. idle or aim-idle on a walk / run change, same
##     input) changes nothing on screen: its request is consumed and the later records are still
##     evaluated in the same frame. Otherwise at most one state change happens per tick.
## Graph fields (plan section 7): loco_enabled (i32@C0+132) = on floor, alive, not HIT;
## move_speed (f32@C0+120) = speed while `moving`, else 0. `moving` follows the stick: on while it
## is held (wish > moving_on_wish), off on the frame it is released (release_grace_s, 0 by
## default: a keyboard direction change with a gap frame then plays a stop and a backward start,
## not the reversal), as the graph's desired speed
## (plan 7's hysteresis kept it on until the body fell below moving_off_speed, which started the
## stop 0.1-0.3 s late, at 0.3-0.5 m/s, and its speed-synced clip at 6-35 % of real time); without
## the stick, body speed alone switches it on above moving_on_speed (+ margin; not while the body
## coasts after a release) and off below moving_off_speed; move_dir_deg (f32@C0+144)
## = the stick direction (wish) while there is move input, else the velocity direction above
## dir_from_velocity_above, else held; + = left. The graph reads it as the desired direction (its
## reversal and hemisphere records react to the stick; the source game's motion follows the
## animation), so Frontier's physics lag must not delay them (plan 6.5 took velocity first; that
## bounces a reversal straight back to its start state). blend angle (f32@C8+4): the graph's
## direction chains read one angle a, the fw chain as clamp(a, -90, 90) and the bw chain as
## clamp(angle-mod(int(a) + 180), -90, 90); each chain saturates at its +-90 seam, where the fw
## chain jumps from full *-rt to full *-lt (a = +-180) and the bw chain likewise (a = 0). The
## source game's smoothing of C8+4 is native code (not in the data), so LocoBrain keeps one
## position per hemisphere (blend_pos: those two clamped values of move_dir_deg), each smoothed
## linearly at blend_angle_rate (at most blend_angle_max_dps; a hemisphere with no weight on
## screen takes its target at once), so neither crosses its seam and a strafe reversal (D <-> A)
## passes through the chain's center clip instead of snapping side to side (G9). At a steady
## direction the weights equal the graph formulas exactly; blend_deg (the circle-smoothed
## angle) is kept for reporting only;
## use_transition_anims (i32@C0+128) = options.use_transition_anims; crouch_change_pending
## (i32@C0+136) = a crouch toggle not yet consumed (INFERRED: the data does not say when the game
## sets it; read as any toggle, moving or not, so crouching at a run takes run-fw's own record
## 0x0002a940 into the full-body crouch change, then idle at its phase 0.75 (0x0003d180) and the
## crouch start clip, while Frontier's body keeps its speed: foot slide until the crouch start
## ends, see WP7's foot-slip test; override_crouch_crossfade avoids it); idle_turn_deg
## (f32@C0+160) = camera yaw minus the legs' facing (Frontier turns the body with the camera, so
## the legs' facing is emulated: it follows the yaw at 90 deg per turn-clip cycle while an idle
## turn plays, INFERRED);
## turn_delta_deg (f32@C0+124) = 0 (no 180 turn clips for Actor_B); aim_flag_140 = 0;
## cover_* = 0.
##
## Code-entered states (no incoming record in the graph; rows marked "proposed"):
##   any_to_death (play_death), any_to_hit (play_hit, grounded only), ground_to_takeoff (jumped;
##   crouch_to_takeoff from a crouch-stance input, Frontier-only),
##   ground_to_fall (airborne without a jump for longer than coyote_s: the pre-fall clip is
##   missing, so the grounded state fades straight into fall with pre-fall's 0.5 s),
##   air_to_land (landed: the landing table picks the landing state; a touchdown within
##   jump_land_gate_tolerance_s of jump-long's phase-0.9 idle record counts as reaching it, see
##   landing_role()), jump_to_fall (the jump clip ended while still airborne; see the note on
##   jump_to_fall below), idle_to_aimidle and aim_enter_move (aim_stance: the graph's aim-idle /
##   aim-run states are code-entered; in MOVE a relabel only while the aim-run state stays on the
##   same move-bank input, else the aim-remapped change-move-mode record moves first).
##   The queued edge events of a tick are applied in order, each state change before the next
##   event (landed then jumped in one frame lands and takes off again; every jumped event is
##   recorded for the landing table); records are then skipped for that tick.
##   While aim_stance holds, a record into idle / run-fw / run-bkwd / a start or stop state goes
##   to the aim equivalent instead (aim-idle / aim-run-forward / aim-run-backward), with the
##   record's fade. With options.aim_walk off (default) the aim-run states play the move bank
##   (masked aim tree + AimStabilizer above it), so their records are used for fades and exits
##   while the legs keep the locomotion clips.
##
## Requests the Frontier code layer posts (INFERRED from the transitions rows' `when`):
##   change-move-mode   held from a movement-mode change (walk / run / sprint / crouch) or a
##                      crouch toggle until a record consumes it (dropped after held_max_age_s;
##                      also a weapon change in the aim states, aimidle_change); posted every tick
##                      while moving in a landing (land_to_move / land_run_to_move);
##   run-fw / #e2d6c492 while moving (fw if |move_dir| <= 90) in a landing, and in a heavy hit
##                      once its 20-frame change-move-mode gate has passed (loco_enabled is false
##                      during the hit before that);
##   idle               while not moving in a landing (land_run_stop), and when aim_stance ends in
##                      aim-idle / aim-run;
##   run                when aim_stance ends while moving in aim-run (aimwalk_to_move);
##   #96646cbc / #e78e5cf7  the reversal requests (move_reversal; trigger not in the data,
##                      proposed): use_transition_anims, speed >= reversal_min_speed, the stick in
##                      the other hemisphere (past 97.5 / 82.5) and at least reversal_angle_deg
##                      from the current velocity direction (the stick reverses against the
##                      motion). In a slow turn the velocity follows the stick, so it takes the
##                      graph's hemisphere record instead.
##
## Entry phases (graph start-phase callbacks): run-fw / run-bkwd start at phase 0 after their own
## start or reversal state, else by ankle match: from another move bank by gait phase (metrics
## plant onsets: left plant = 0, right plant = 0.5, per stride), from a static pose by the heel
## positions (metrics heel_z) at the two plant phases; idle / aim-idle / turns keep their phase
## while still weighted (start-for-streaming-anim), aim-idle follows the aim tree's base phase.
## An entry that follows another input (aim-idle, gait match) targets that input's phase after
## this frame's advance (+ dt x its scale): a seek applies without advancing its frame;
## every other state starts at 0. A still-weighted input is never seeked (no pop). Instance
## stack: the graph starts a new instance of a state on every entry and fades it over the old
## one still on screen. The one-shot banks (start / stop / rev) and the heavy hits have two
## inputs each (TreeBuilder instance_slots); an entry into one of their states takes a slot with
## no weight (seeked to the entry phase) and fades over the other, so a second heavy hit from the
## same sector restarts the reaction; only the -begin shim continues into its own state on the
## same instance. With both slots still weighted (a third entry within one fade) the least
## weighted one continues its phase. Other inputs (idle, move banks, the other singles) continue
## when re-entered while weighted; a bank's hemisphere that has no weight is seeked on entry.
## Landings have one input each (slots would add 555 nodes, about 150 us per frame): a landing
## re-entered within the fall fade (land, walk off a ledge, land again within about 0.3 s)
## continues its phase and ends early instead of restarting.
## Fade-0 records (a one-shot's end into its successor) while the current input is still fading
## in would cut the rest of that fade: they use the remaining fade time instead (info fade_guard;
## the graph's successor instance takes the replaced one's place in the running blend).
## Rates: move banks play at ratio = speed / sum(w_i v_i) (clamped to tuning.rate_clamp, floor
## rate_floor_decel while fading out of MOVE), timeline scale = ratio * sum(w v) / sum(w v T)
## cycles per second (graph calc-new-phase-from-speed). Start and reversal banks follow their
## graph phase callback, speed / the clip's final body speed (at least 0.5; the start's desired
## speed, see start_speed_from_wish and start_rate_boost; the reversal's body speed), and through
## a start the body follows the clip (root_motion_speed(), WP7; the clip's body speed is INFERRED
## from the metrics' foot-contact body_profile, the clips carry no root track); stop banks start at
## entry speed / the clip's initial body speed and reach real time by phase 0.2 (never faster),
## entry speed = stop_entry_speed() (the speed at the stick release), kept per instance slot;
## body speeds from metrics body_profile (see _align_rate; align_rate_sync). Single clips play in
## real time.
##
## Gameplay overrides (graph gameplay_overrides, all off by default; AnimGraphData.set_override):
## G1 override_no_transition_anims, G2 override_fast_hemisphere_fade, G5 override_no_idle_turns,
## G6 override_immediate_land_move (gated landing records at once; landings without a movement
## record, such as jump-long-land-run, are left for run-fw / run-bkwd at once by a code rule with
## land_to_move's fade), override_fast_aim_to_move, override_crouch_crossfade (a crouch toggle
## becomes a 0.25 s self re-entry into the other stance), override_fall_fade. LocoBrain's own
## opt-in: join_fade_s (fade-0 input joins fade instead of cutting; see the var).
##
## Per frame (plan 3.1): tick() (rules, requests on L, bank internals), then the caller runs
## UpperBody.tick(inp, state, dt, carry_inputs()), L.update(dt), L.write(), advance(dt).
## UpperBody (WP5) writes the carry layers from carry_inputs() and fires the crouch-change
## additive; drive_carry / drive_crouch_add let this class do either instead (off by default).
## step() does tick + L.update/write (+ W.update and the carry layers when drive_carry) for
## standalone use and tests; snap() jumps to idle / aim-idle with no fade (spawn, tests).
##
## Record offsets and state IDs are reported as the graph table has them.

signal transitioned(from: StringName, to: StringName, info: Dictionary)

const IDLE := &"IDLE"
const AIM_IDLE := &"AIM_IDLE"
const MOVE := &"MOVE"
const START := &"START"
const STOP := &"STOP"
const REVERSAL := &"REVERSAL"
const TURN := &"TURN"
const TAKEOFF := &"TAKEOFF"
const JUMP := &"JUMP"
const FALL := &"FALL"
const LAND := &"LAND"
const HIT := &"HIT"
const DEATH := &"DEATH"
const CCHANGE := &"CCHANGE"

const GROUNDED := [IDLE, AIM_IDLE, MOVE, START, STOP, REVERSAL, TURN, LAND, HIT, CCHANGE]
const AIRBORNE := [TAKEOFF, JUMP, FALL]
const RT_OF_GROUP := {"move": MOVE, "start": START, "stop": STOP, "rev": REVERSAL}

const REQ_MODE := "change-move-mode"
const REQ_FW := "run-fw"
const REQ_BW := "#e2d6c492"
const REQ_REV_TO_BW := "#96646cbc"
const REQ_REV_TO_FW := "#e78e5cf7"
const REQ_IDLE := "idle"
const REQ_RUN := "run"

## Rows whose records handle a crouch toggle (a record listed under one of these and another row
## reports the crouch row while crouch_change_pending).
const CROUCH_ROWS := ["idle_stance_change", "move_mode_change_crouch", "stop_mode_change",
		"transition_state_crouch_change", "land_crouch_change"]
## Graph states entered at phase 0 by run-fw / run-bkwd (their start-phase callbacks).
const MOVE_ZERO_FROM := {"fw": ["idle^run-fwd", "run-bw^run-fwd"], "bw": ["idle^run-bkwd", "run-fw^run-bkwd"]}
## Aim equivalents of locomotion targets while aim_stance holds.
const AIM_REMAP := {"idle": "aim-idle", "run-fw^idle": "aim-idle", "run-bk^idle": "aim-idle",
		"run-fw": "aim-run-forward", "idle^run-fwd": "aim-run-forward",
		"run-bkwd": "aim-run-backward", "idle^run-bkwd": "aim-run-backward"}
## Transition keys used by code rules that are not rows of the graph table (all proposed).
const LOCAL_ROWS := {
	"aim_enter_move": {"status": "proposed", "fade_from": "idle_to_aimidle",
			"why": "the graph's aim-run states are code-entered (no incoming record): aim_stance in START / STOP / REVERSAL / TURN while moving enters aim-run with the aim-entry fade; from MOVE it only relabels the state (same move-bank input, no fade)"},
	"revive": {"status": "proposed", "why": "respawn: straight to idle (no graph record)"},
	"debug_enter": {"status": "proposed", "why": "tests / debug: immediate entry"},
	"graph_record": {"status": "graph", "why": "a graph record that no transitions row lists (WP1 bindings gap): played with the record's own fade and gates; info.record names it"},
}
const HEMI_KEYS := ["fw", "bw"]
const EXPR_VARS := ["loco_enabled", "move_speed", "move_dir_deg", "use_transition_anims", "crouch_change_pending",
		"idle_turn_deg", "turn_delta_deg", "aim_flag_140", "cover_side", "cover_f152"]
const TRACE_MAX := 32

## Proposed Frontier triggers (not graph data).
## A held request (change-move-mode) that no record consumed is dropped after this long.
var held_max_age_s := 2.0
## Reversal request: the stick points at least this far from the current velocity direction ...
var reversal_angle_deg := 135.0
## ... while the body still moves at least this fast.
var reversal_min_speed := 1.0
## The idle-turn legs' facing lags the camera yaw by at most this much.
var idle_turn_max_lag_deg := 90.0
## A touchdown this close (s) before jump-long reaches its idle record's phase gate (0.9) takes
## that record's landing (jump-long-land-idle), as the graph would a frame or two later; earlier
## touchdowns take the early-landing sibling (landing table idle_early). Default: 2 frames at the
## graph's 30 Hz (a flat Frontier jump touches down at phase 0.87-0.89). tuning
## jump_land_gate_tolerance_s overrides it.
var jump_land_gate_tolerance_s := 2.0 / 30.0
## Gameplay override (opt-in; 0 = the graph): a fade-0 record that switches the lower input from
## a fully weighted one (a one-shot's end into its successor) cuts, as authored. Most such joins
## match exactly (start -> move 0.000 rad), but some Actor_B data does not (crouch reversal end
## crouch-quickstop-bw -> crouch-walk-bw 0.88 rad; idle^run-bw-rt -> run-bw-rt 0.49 rad; and
## inputs with different carry-layer sets, e.g. musket reversal -> run-bkwd, the arms). > 0 fades
## those joins over this long instead (info override "join_fade_s"). PlayerAnim (WP6) exposes it
## in its 'Gameplay overrides' export group.
var join_fade_s := 0.0
## Stick release (INFERRED; 0 = the graph's move_speed drops on the release frame): > 0 keeps
## `moving` this long (s) after the stick is released, so a keyboard direction change with a gap
## (W released, S pressed a few frames later) still takes the reversal instead of a stop and a
## backward start, at the cost of starting a real stop that much later. The data does not say how
## the source game filters the stick (tuning stick_release_grace_s overrides it).
var release_grace_s := 0.0
## Speed limit (deg/s) of the chain positions on top of the blend_angle_rate approach (proposed,
## hybrid proposal's 720 deg/s): a 180 deg stick change then takes 0.25 s instead of moving 18 %
## of the way in the first frame (tuning blend_angle_max_dps overrides it).
var blend_angle_max_dps := 720.0
## The start / reversal / stop banks follow the graph's speed-synced phase callbacks (see
## _align_rate); false plays them in real time.
var align_rate_sync := true
## f32[D8+820] of the start phase callback (INFERRED; WP7): true = the desired speed (the stick's
## wish, m/s; the body speed while there is none), false = the body speed. The loops' rate reads
## another field (calc-new-phase-from-speed(f32[D8+824]), the body speed). With the body following
## the start clip (root_motion_speed()) the body speed would hold the start at its 0.5 floor, so
## the start plays at desired speed / its final speed and ends at the desired speed. The reversal
## banks (same callback 0x0001466c) keep the body speed: Frontier's body is not driven by them.
var start_speed_from_wish := true
## Gameplay override, ON by default pending the owner's decision (WP7; set by PlayerAnim's
## override_start_rate_boost; false = graph-faithful): where a start clip's own (inferred) body
## speed is below the desired speed it plays faster than the graph's align rate, as fast as reaches
## the desired speed but at most tuning rate_clamp[1] (1.75, the plan's locomotion clamp D9). With
## the body following the clip (root_motion_speed()), the graph rate alone takes 0.8-3 s to full
## speed (a run start: 1.7 m in the first second; Frontier's smoke test wants over 2 m).
var start_rate_boost := true
## Through a graph stop (STOP) the body follows the stop clip as it follows a start (root_motion_speed()):
## on release it keeps going over the stop's own travel (run-fw^idle: about 0.86 m in its first 0.5 s)
## instead of stopping in 0.2 s at player.gd's ground_decel while the clip's legs still travel, which slid
## the pelvis back over the planted feet (user playtest 2026-09-25: "a whole like backwards step").
## PlayerAnim.override_crisp_stops turns it off.
var stop_root_motion := true
## Crouch toggles (WP10, CROUCH_HANDS part ch-crouchB; see _edges() and _stance_switch()):
## crouch_pending_while_moving = the earlier literal reading, every toggle sets
## crouch_change_pending (off: only a toggle while not moving does; see _edges());
## crouch_crossfade_blend = plain crossfades across a stance change (off: the lower selector
## switches at once, phase-matched, and StanceInertializer blends the pose over the record's fade:
## inertia_request, read and cleared by PlayerAnim each frame).
var crouch_pending_while_moving := false
var crouch_crossfade_blend := false
var inertia_request := 0.0
## Parameters this controller may drive; UpperBody (WP5) owns both by default.
var drive_carry := false
var drive_crouch_add := false
## Tests: when true, tick() only derives the fields and drives the banks (no state changes).
var frozen := false

var data: AnimGraphData
var tree: AnimationTree
var idx: TreeIndex
var L: XFadeSelector
var W: XFadeSelector

var state: StringName = IDLE
## True: a run forward goes straight to idle, blending, with no stop clip (the graph's use_transition_anims = false branch taken
## from MOVE while the hemisphere is forward: reversals out of a forward run lose their clips too). Off here (the graph's own
## transitions, which the tests check); the player's PlayerAnim turns it on.
var no_forward_stop_anim := false
var graph_state := "idle"
var mode: StringName = &"run"
var stance := "stand"
var hemi: StringName = &"fw"
var input_id: StringName = &""
var aimed := false
var weapon: StringName = &""
var time_in_state := 0.0

var moving := false
var move_dir_deg := 0.0
var blend_deg := 0.0
## Direction-chain position of each hemisphere (deg, -90..90; see the header): the fw chain's
## clamp(a, -90, 90) and the bw chain's clamp(angle-mod(int(a) + 180), -90, 90), smoothed linearly.
var blend_pos := {"fw": 0.0, "bw": 0.0}
var wish_dir_deg := 0.0
var vel_dir_deg := 0.0
var loco_enabled := true
var idle_turn_deg := 0.0
var anim_yaw_deg := 0.0
var crouch_change_pending := false
var ratio := 1.0
var ratio_raw := 1.0
var rates := {"fw": 0.0, "bw": 0.0}
var last_landing := {}

var _clock := 0.0
var _dt := 1.0 / 60.0         ## this tick's dt (the tree advances by it right after)
var _frame := 0
var _inp := AnimInputs.new()
var _started := false
var _prev_crouched := false
var _last_jump_t := -INF
var _requests := {}
var _held := {}               ## request -> clock time it was posted (held until consumed)
var _gs := {}                 ## graph state -> spec {kind, rt, role, group, hemi, aimed, begin}
var _gs_of_role := {}         ## role -> graph state
var _rec_keys := {}           ## record offset -> [row keys]
var _rec_opt := {}            ## record offset -> option it requires
var _expr := {}               ## expression text -> Expression (null when it does not parse)
var _expr_vals: Array = []
var _hemi_sels := {}          ## input id (String) -> XFadeSelector over [fw, bw]
var _dir := {}                ## input id (String) -> {hemi: Vector2(w_neg, w_pos)}
var _gait := {}               ## clip -> gait table
var _ends := {}               ## clip -> [first, last] body_profile speed
var _stop_entry_speed := 0.0  ## entry speed of the current stop state (reporting)
var _stop_entry := {}         ## stop input id (String; per instance slot) -> its entry speed
var _prev_stick := false      ## the stick was held last tick
var _coasting := false        ## released while moving; the body still coasts above moving_off_speed
var _stick_speed := 0.0       ## body speed on the last tick with the stick held
var _release_speed := 0.0     ## body speed on the last stick tick before the release (0 while held)
var _release_t := -1.0        ## clock of a stick release still inside release_grace_s (-1: none)
var _trace: Array = []
var _counts := {}             ## transitions key -> times fired
var _warned := {}
var _split := 2.055
var _hyst := 0.1
var _fps := 30.0
var _coyote := 0.15
var _hit_gate := 0.666667


func _init(p_data: AnimGraphData, p_tree: AnimationTree, p_index: TreeIndex, p_L: XFadeSelector, p_W: XFadeSelector = null) -> void:
	data = p_data
	tree = p_tree
	idx = p_index
	L = p_L
	W = p_W
	_build_state_map()
	_build_record_index()
	_hyst = float(data.tuning("mode_split_hysteresis_mps", 0.1))
	_coyote = float(data.tuning("coyote_s", 0.15))
	_fps = float(data.graph.get("gates", {}).get("land_move_gate", {}).get("fps", 30.0))
	_hit_gate = float(data.transition_use("hit_mode_change").get("gate_s", 20.0 / _fps))
	jump_land_gate_tolerance_s = float(data.tuning("jump_land_gate_tolerance_s", 2.0 / _fps))
	blend_angle_max_dps = float(data.tuning("blend_angle_max_dps", blend_angle_max_dps))
	release_grace_s = float(data.tuning("stick_release_grace_s", release_grace_s))
	weapon = _default_weapon()
	_split = _mode_split()
	var ms := data.modes()
	mode = &"run" if ms.has("run") else (StringName(ms[0]) if not ms.is_empty() else &"run")
	stance = data.stance_of(String(mode))
	for i in EXPR_VARS.size():
		_expr_vals.append(0.0)
	var res := _resolve("idle")
	if not res.is_empty():
		input_id = res.input
		L.set_immediate(input_id, 0.0)


# --- public -------------------------------------------------------------------------------

## One animation frame: rules and records (at most one state change), requests on L, bank
## direction weights, rates and hemisphere fades. events: the queued AnimInputs edge events.
func tick(inp: AnimInputs, events: Array, dt: float, weapon_key: StringName, aim_stance: bool) -> void:
	_frame += 1
	_clock += dt
	if dt > 0.0:
		_dt = dt
	_inp = inp if inp != null else AnimInputs.new()
	_set_weapon(weapon_key)
	_derive(_inp, dt)
	if not _started:
		_started = true
		_prev_crouched = _inp.crouched
	if not frozen:
		_edges(_inp)
		var fired := _code_rules(_inp, events, aim_stance)
		if not fired:
			_post_requests(_inp, aim_stance)
			fired = _eval_records(aim_stance)
			if not fired:
				_override_rules(aim_stance)
		_requests.clear()
	_drive_banks(dt)
	time_in_state += dt


## tick() + L.update/write (+ W.update and the carry layers when drive_carry): standalone use.
func step(inp: AnimInputs, events: Array, dt: float, weapon_key: StringName, aim_stance: bool) -> void:
	tick(inp, events, dt, weapon_key, aim_stance)
	L.update(dt)
	L.write()
	if drive_carry:
		if W != null:
			W.update(dt)
		write_carry()


## The lower context UpperBody.tick() takes for the carry layers (TreeIndex.carry_targets):
## {input_w, hemi_w, dir_w, phase}. The current target is included at 1e-6 until it has weight.
func carry_inputs() -> Dictionary:
	var input_w := {}
	var ws := L.weights()
	for k in ws:
		if float(ws[k]) > 0.0:
			input_w[String(k)] = float(ws[k])
	var t := String(L.target())
	if t != "" and not input_w.has(t):
		input_w[t] = 1e-6
	var hemi_w := {}
	var dir_w := {}
	var ph := {}
	for id in input_w:
		var rec := idx.lower_record(StringName(id))
		if rec.get("kind", "") in ["bank", "aimmove"]:
			var hs := _hemi_sel(StringName(id))
			if hs != null:
				hemi_w[id] = {"fw": hs.weight(&"fw"), "bw": hs.weight(&"bw")}
			var d := {}
			for h in _dir.get(id, {}):
				var v: Vector2 = _dir[id][h]
				d[h] = [v.x, v.y]
			dir_w[id] = d
			ph[id] = idx.phase(tree, StringName(id), _dominant_hemi(StringName(id)))
		else:
			ph[id] = idx.phase(tree, StringName(id))
	return {"input_w": input_w, "hemi_w": hemi_w, "dir_w": dir_w, "phase": ph}


## Writes the carry layers of the weighted lower inputs (only when UpperBody does not).
func write_carry() -> void:
	var ci := carry_inputs()
	var ww := {}
	if W != null:
		var wws := W.weights()
		for k in wws:
			ww[String(k)] = float(wws[k])
	else:
		ww[String(weapon)] = 1.0
	idx.write_carry(tree, idx.carry_targets(ci.input_w, ww, ci.hemi_w, ci.dir_w, ci.phase))


## Normalized phase of the current lower input (the state's hemisphere for banks).
func phase() -> float:
	return _phase_of(input_id, String(hemi))


## Heavy hit (plan 6.10): the full-body hit clip of the stance and the 90-degree sector the hit
## came from (local_dir: x right, y forward). Grounded, alive states only.
func play_hit(local_dir: Vector2) -> void:
	if state == DEATH or not state in GROUNDED:
		return
	var dir := hit_sector(local_dir)
	var res := _resolve("hit-reaction-full-body", dir)
	if res.is_empty():
		_warn_once("hit:" + dir, "LocoBrain: no heavy-hit input for %s/%s/%s" % [weapon, mode, dir])
		return
	var use := data.transition_use("any_to_hit")
	_enter("hit-reaction-full-body", res, float(use.get("fade_s", 0.1)), _info("any_to_hit", use, "heavy hit from %s" % dir))


## Death: crouch when crouched, generic without a direction, else front / back by sector. Holds
## the last frame until revive().
func play_death(local_dir := Vector2.ZERO) -> void:
	if state == DEATH:
		return
	var variant := "crouch"
	if stance != "crouch":
		if local_dir.length() < 1e-4:
			variant = "generic"
		else:
			variant = "front" if absf(_deg(local_dir)) <= 90.0 else "back"
	var res := _resolve("death-front-mid", variant)
	if res.is_empty():
		res = _resolve("death-front-mid", "front")
	if res.is_empty():
		_warn_once("death", "LocoBrain: no death input for %s/%s" % [weapon, mode])
		return
	var use := data.transition_use("any_to_death")
	_enter("death-front-mid", res, float(use.get("fade_s", 0.2)), _info("any_to_death", use, "died (%s)" % variant))


## Jumps to the idle (or aim-idle) state of the input's mode and stance with no fade and no
## pending request (spawn, teleport, tests).
func snap(inp: AnimInputs, weapon_key := &"", aim_stance := false) -> void:
	_inp = inp if inp != null else AnimInputs.new()
	_set_weapon(weapon_key)
	_held.clear()
	crouch_change_pending = false
	_started = true
	_prev_crouched = _inp.crouched
	moving = false
	_prev_stick = false
	_coasting = false
	_release_speed = 0.0
	_release_t = -1.0
	mode = select_mode(0.0, _inp.crouched, false, mode, _split, _hyst, data.modes())
	stance = data.stance_of(String(mode))
	var gs := "aim-idle" if aim_stance else "idle"
	var res := _resolve(gs)
	if res.is_empty():
		gs = "idle"
		res = _resolve(gs)
	if res.is_empty():
		return
	L.set_immediate(res.input, 0.0)
	_apply_state(gs, res)
	hemi = &"fw"
	anim_yaw_deg = rad_to_deg(_inp.yaw)
	idle_turn_deg = 0.0
	set_blend_deg(0.0)


## Respawn: idle at once.
func revive() -> void:
	_held.clear()
	crouch_change_pending = false
	var res := _resolve("idle")
	if res.is_empty():
		return
	var from := state
	var from_gs := graph_state
	L.set_immediate(res.input, 0.0)
	input_id = res.input
	graph_state = "idle"
	state = IDLE
	hemi = &"fw"
	aimed = false
	time_in_state = 0.0
	anim_yaw_deg = rad_to_deg(_inp.yaw)
	_emit(from, from_gs, _info("revive", {"fade_s": 0.0, "status": "proposed"}, "revive"))


## Tests / debug: enters a graph state at once (no fade), optionally in a mode and at a phase.
func debug_enter(gs: String, p_mode := &"", entry_phase := 0.0) -> bool:
	if p_mode != &"":
		mode = p_mode
		stance = data.stance_of(String(mode))
	var res := _resolve(gs)
	if res.is_empty():
		return false
	var from := state
	var from_gs := graph_state
	var h := String(res.get("hemi", ""))
	if h != "":
		var hs := _hemi_sel(res.input)
		if hs != null:
			hs.set_immediate(StringName(h))
			hs.write()
	_seek(res.input, h, entry_phase)
	L.set_immediate(res.input)
	_apply_state(gs, res)
	if state == STOP:
		_stop_entry_speed = _inp.speed
		_stop_entry[String(res.input)] = _inp.speed
	_emit(from, from_gs, _info("debug_enter", {"fade_s": 0.0, "status": "proposed"}, "debug"))
	return true


## Tests / debug: snaps the travel direction, the smoothed blend angle (C8+4) and both chain
## positions to angle a (deg).
func set_blend_deg(a: float) -> void:
	blend_deg = wrapf(a, -180.0, 180.0)
	move_dir_deg = blend_deg
	for h in HEMI_KEYS:
		blend_pos[h] = hemi_position(h, blend_deg)


## Writes the direction weights of every hemisphere of a bank input for blend angle a (deg; the
## graph formulas, dir_weights); returns {hemi: Vector2(w_neg, w_pos)}.
func apply_direction(id: StringName, a: float) -> Dictionary:
	var pos := {}
	for h in HEMI_KEYS:
		pos[h] = hemi_position(h, a)
	return _apply_positions(id, pos)


## Writes the direction weights of every hemisphere of a bank input from chain positions
## {hemi: deg}; returns {hemi: Vector2(w_neg, w_pos)}.
func _apply_positions(id: StringName, pos: Dictionary) -> Dictionary:
	var rec := idx.lower_record(id)
	var out := {}
	for h in rec.get("hemis", {}):
		var w2 := position_weights(float(pos.get(String(h), 0.0)))
		idx.set_bank_weights(tree, id, String(h), w2.x, w2.y)
		out[h] = w2
	_dir[String(id)] = out
	return out


## Graph direction chains (run-fw / run-bkwd trees): (w_neg, w_pos) of a bank hemisphere at blend
## angle a. fw: neg = *-rt at lerp-scale(-90, 0, 1, 0, a), pos = *-lt at lerp-scale(0, 90, 0, 1, a).
## bw: a' = angle-mod(int(a) + 180) (the graph truncates to int); neg = *-lt, pos = *-rt.
## Equals position_weights(hemi_position(h, a)).
static func dir_weights(h: String, a: float) -> Vector2:
	var x := a if h == "fw" else fposmod(float(int(a)) + 180.0 + 180.0, 360.0) - 180.0
	return Vector2(_lerp_scale(-90.0, 0.0, 1.0, 0.0, x), _lerp_scale(0.0, 90.0, 0.0, 1.0, x))


## The angle a hemisphere's direction formulas read at travel angle a, clamped to the chain's
## -90..90 (both formulas are saturated beyond): fw a, bw angle-mod(int(a) + 180).
static func hemi_position(h: String, a: float) -> float:
	var x := a if h == "fw" else fposmod(float(int(a)) + 180.0 + 180.0, 360.0) - 180.0
	return clampf(x, -90.0, 90.0)


## Direction weights (w_neg, w_pos) at chain position p: lerp-scale(-90, 0, 1, 0, p),
## lerp-scale(0, 90, 0, 1, p).
static func position_weights(p: float) -> Vector2:
	return Vector2(_lerp_scale(-90.0, 0.0, 1.0, 0.0, p), _lerp_scale(0.0, 90.0, 0.0, 1.0, p))


## Movement mode (plan 6.6, G3): crouched -> crouch, sprinting -> sprint, else walk / run split
## at `split` (sqrt(v_walk-fw * v_run-fw)) with +-hyst hysteresis around the previous mode (prev
## &"" = starting from standstill: the nearest side); without move input the mode is kept (a
## standing player leaving crouch takes run).
static func select_mode(target_speed: float, crouched: bool, sprinting: bool, prev: StringName, split: float,
		hyst: float, modes := PackedStringArray(["walk", "run", "sprint", "crouch"])) -> StringName:
	if crouched and modes.has("crouch"):
		return &"crouch"
	if sprinting and modes.has("sprint"):
		return &"sprint"
	var stand := &"run" if modes.has("run") else (&"walk" if modes.has("walk") else prev)
	if target_speed <= 0.0:
		return prev if prev != &"crouch" and prev != &"" else stand
	if not modes.has("walk") or not modes.has("run"):
		return stand
	if target_speed < split - hyst:
		return &"walk"
	if target_speed > split + hyst:
		return &"run"
	if prev == &"walk" or prev == &"run":
		return prev
	return &"walk" if target_speed < split else &"run"


## Sector of a local direction (x right, y forward): fw / lt / rt / bw.
static func hit_sector(local_dir: Vector2) -> String:
	var a := _deg(local_dir)
	if absf(a) <= 45.0:
		return "fw"
	if a > 45.0 and a <= 135.0:
		return "lt"
	if a < -45.0 and a >= -135.0:
		return "rt"
	return "bw"


## Speed a stop state entered now starts from (graph stop phase callback 0x00013a6c, f32[D4+16]):
## the body speed on the last tick the stick was held when it has since been released (the source
## game's body follows the animation, so its speed at the stop is the speed it was moving at; the
## Frontier body already decelerates from the release on), else the current body speed.
func stop_entry_speed() -> float:
	if _prev_stick:
		return _inp.speed
	return maxf(_inp.speed, _release_speed)


## Graph-field values (plan section 7) of this tick.
func derived() -> Dictionary:
	return {"moving": moving, "move_speed": _move_speed(), "move_dir_deg": move_dir_deg, "blend_deg": blend_deg,
			"blend_pos_fw": blend_pos.fw, "blend_pos_bw": blend_pos.bw,
			"wish_dir_deg": wish_dir_deg, "vel_dir_deg": vel_dir_deg, "hemi": String(hemi), "anim_mode": String(mode), "stance": stance,
			"ratio": ratio, "ratio_raw": ratio_raw, "rate_fw": rates.fw, "rate_bw": rates.bw,
			"gait_phase": gait_phase_of(input_id, String(hemi)), "loco_enabled": loco_enabled,
			"idle_turn_deg": idle_turn_deg, "turn_delta_deg": 0.0, "crouch_change_pending": crouch_change_pending,
			"use_transition_anims": _uta(), "mode_split_mps": _split, "aimed": aimed,
			"stick": _prev_stick, "coasting": _coasting, "release_speed": _release_speed, "stop_entry_speed": _stop_entry_speed}


## {state, graph_state, input_id, hemi, mode, time_in_state, phase, selector, hemis, trace, ...}
func snapshot() -> Dictionary:
	var hs := {}
	for id in _hemi_sels:
		if L.weight(StringName(id)) > 0.0:
			hs[id] = _hemi_sels[id].snapshot()
	return {"state": String(state), "graph_state": graph_state, "input_id": String(input_id), "hemi": String(hemi),
			"mode": String(mode), "stance": stance, "aimed": aimed, "time_in_state": time_in_state, "phase": phase(),
			"selector": L.snapshot(), "hemis": hs, "held": _held.keys(), "landing": last_landing,
			"trace": _trace.duplicate(), "derived": derived()}


func trace() -> Array:
	return _trace.duplicate()


## transitions key -> times fired since construction.
func counts() -> Dictionary:
	return _counts.duplicate()


## Back from a traversal move (PlayerTraversal, vault speed push 2026-09-26): the moving bank goes on at
## gait phase g (left plant 0, right plant 0.5; the move's last pose), in the stride nearest to where it
## was frozen, so the pose inertialized out of the move lands in the matching step of the run or sprint.
## Nothing unless the lower body is in MOVE on an input with alternating plants.
func match_gait_phase(g: float) -> void:
	if state != MOVE or input_id == &"":
		return
	var h := String(hemi)
	var clip := _center_clip(input_id, h)
	if clip == "" or _gait_table(clip).is_empty():
		return
	_seek(input_id, h, phase_for_gait(clip, g, _phase_of(input_id, h)))


## Gait phase (left plant = 0, right plant = 0.5) of a lower input's hemisphere center clip at its
## current position; -1 when the clip has no alternating plants.
func gait_phase_of(id: StringName, h: String) -> float:
	var clip := _center_clip(id, h)
	if clip == "" or _gait_table(clip).is_empty():
		return -1.0
	return gait_phase(clip, _phase_of(id, h))


## Gait phase of a clip at normalized phase u (metrics plant onsets; u itself without them).
func gait_phase(clip: String, u: float) -> float:
	var tb := _gait_table(clip)
	if tb.is_empty():
		return fposmod(u, 1.0)
	return fposmod(_gait_g(tb, fposmod(u, 1.0)), 1.0)


## Normalized phase of `clip` whose gait phase is g, in the stride nearest to near_u.
func phase_for_gait(clip: String, g: float, near_u: float) -> float:
	var tb := _gait_table(clip)
	if tb.is_empty():
		return fposmod(near_u, 1.0)
	var n := int(round(tb[tb.size() - 1][1] - tb[0][1])) - 1
	var best := fposmod(near_u, 1.0)
	var best_d := INF
	var g0: float = tb[0][1]
	for k in range(int(floor(g0)) - 1, int(ceil(g0)) + n + 2):
		var target := float(k) + fposmod(g, 1.0)
		for i in tb.size() - 1:
			var a: Array = tb[i]
			var b: Array = tb[i + 1]
			if target >= float(a[1]) and target <= float(b[1]) and float(b[1]) > float(a[1]):
				var u := lerpf(float(a[0]), float(b[0]), (target - float(a[1])) / (float(b[1]) - float(a[1])))
				u = fposmod(u, 1.0)
				var d := absf(wrapf(u - near_u, -0.5, 0.5))
				if d < best_d:
					best_d = d
					best = u
	return best


# --- per tick -----------------------------------------------------------------------------

func _derive(inp: AnimInputs, dt: float) -> void:
	var wish := inp.wish_local
	var on_wish := float(data.tuning("moving_on_wish", 0.05))
	var off_speed := float(data.tuning("moving_off_speed", 0.6))
	# The table's on-speed (0.35) is below its off-speed (0.6), which would chatter between
	# them without input: the speed-only switch-on uses the larger value plus a margin.
	var on_speed := maxf(float(data.tuning("moving_on_speed", 0.35)), off_speed) + 0.05
	var was_moving := moving
	var stick := wish.length() > on_wish
	if stick:
		moving = true
		_stick_speed = inp.speed
		_release_speed = 0.0
		_release_t = -1.0
	elif moving:
		if _prev_stick:
			_release_t = _clock
		if _release_t >= 0.0:
			# Stick release: the graph's move_speed drops at once (header, move_speed; after
			# release_grace_s, 0 by default), so the stop records fire this frame instead of after
			# Frontier's deceleration; the body then coasts to rest without switching `moving`
			# back on by speed.
			if _clock - _release_t + 1e-6 >= release_grace_s:
				moving = false
				_coasting = true
				_release_speed = _stick_speed
				_release_t = -1.0
		elif inp.speed < off_speed:
			moving = false
	elif inp.speed > on_speed and not _coasting:
		moving = true
	if _coasting and (stick or inp.speed < off_speed):
		_coasting = false
	_prev_stick = stick
	var v := inp.velocity_local
	if wish.length() > on_wish:
		wish_dir_deg = _deg(wish)
		move_dir_deg = wish_dir_deg
	elif v.length() > float(data.tuning("dir_from_velocity_above", 0.3)):
		move_dir_deg = _deg(v)
	if v.length() > 1e-3:
		vel_dir_deg = _deg(v)
	if dt > 0.0:
		var k := 1.0 - exp(-float(data.tuning("blend_angle_rate", 12.0)) * dt)
		blend_deg = wrapf(blend_deg + wrapf(move_dir_deg - blend_deg, -180.0, 180.0) * k, -180.0, 180.0)
		# Each chain position approaches its own target linearly (never across its +-90 seam);
		# a hemisphere with no weight in any playing bank takes its target at once (invisible).
		var vis := _hemi_visible()
		var cap := blend_angle_max_dps * dt
		for h in HEMI_KEYS:
			var tg := hemi_position(h, move_dir_deg)
			if vis[h]:
				var p := float(blend_pos[h])
				blend_pos[h] = p + clampf((tg - p) * k, -cap, cap)
			else:
				blend_pos[h] = tg
	loco_enabled = inp.on_floor and inp.alive and state != HIT
	# Mode (frozen in the air: the landing uses the mode of the take-off).
	# The walk / run hysteresis applies while moving; starting from standstill takes the nearest.
	if inp.on_floor:
		var target := inp.target_speed if wish.length() > on_wish else 0.0
		var prev := mode if (was_moving or target <= 0.0) else &""
		var nm := select_mode(target, inp.crouched, inp.sprinting, prev, _split, _hyst, data.modes())
		if nm == &"":
			nm = mode
		if nm != mode:
			mode = nm
			stance = data.stance_of(String(mode))
			_held[REQ_MODE] = _clock
	# Idle turns: the legs' facing follows the camera yaw only through the turn clips.
	var yaw_deg := rad_to_deg(inp.yaw)
	if state == IDLE or state == TURN:
		if state == TURN and dt > 0.0:
			var T := maxf(float(idx.lower_record(input_id).get("length", 1.0)), 0.1)
			var d := wrapf(yaw_deg - anim_yaw_deg, -180.0, 180.0)
			anim_yaw_deg += clampf(d, -90.0 / T * dt, 90.0 / T * dt)
		var lag := wrapf(yaw_deg - anim_yaw_deg, -180.0, 180.0)
		if absf(lag) > idle_turn_max_lag_deg:
			anim_yaw_deg = yaw_deg - signf(lag) * idle_turn_max_lag_deg
		idle_turn_deg = wrapf(yaw_deg - anim_yaw_deg, -180.0, 180.0)
	else:
		anim_yaw_deg = yaw_deg
		idle_turn_deg = 0.0


func _edges(inp: AnimInputs) -> void:
	if inp.crouched != _prev_crouched:
		_prev_crouched = inp.crouched
		# crouch_change_pending (i32@C0+136, INFERRED; ch-crouchB): set by a toggle while the lower
		# body is not moving. The records it gates (0x0003f3b0 idle, 0x0002a940 run-fw, 0x000252c0
		# run-bkwd, 0x0003bd90 start, 0x0003fc30 stop) all enter crouch-change-idle^idle, an
		# in-place idle-to-idle change whose moving variants come from a runtime clip grid
		# (its tree's script blend, f32@C8+16) that Actor_B's data does not have; while moving, the
		# graph's own change-move-mode records (0x0002a970 / 0x000252f0 0.5 s, aim-run 0x00030a50
		# 0.25 s) move to the other stance's locomotion bank instead, with the crouch-change
		# additive on top (UpperBody). crouch_pending_while_moving restores the earlier reading.
		crouch_change_pending = crouch_pending_while_moving or not moving
		_held[REQ_MODE] = _clock
		if drive_crouch_add and bool(data.option("crouch_change_add", true)):
			var dir := "stand_to_crouch" if inp.crouched else "crouch_to_stand"
			var rec := idx.oneshot("CC", String(idx.crouch_add.get("%s/%s" % [weapon, dir], "")))
			if not rec.is_empty():
				tree.set(rec.request, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _set_weapon(key: StringName) -> void:
	var k := StringName(key)
	if k == &"" or not idx.weapons.has(String(k)):
		k = _default_weapon()
	if k != weapon:
		weapon = k
		if state == AIM_IDLE or (state == MOVE and aimed):
			_held[REQ_MODE] = _clock


## Code-entered states; returns true when the state changed (records are then skipped).
func _code_rules(inp: AnimInputs, events: Array, aim_stance: bool) -> bool:
	if not inp.alive and state != DEATH:
		play_death(Vector2.ZERO)
		return true
	if state == DEATH:
		return true
	# Every queued edge in order, each state change applied before the next event (a landed and
	# a jumped queued in one frame land, then take off again).
	var changed := false
	for e in events:
		var t := String(e.get("t", "")) if e is Dictionary else ""
		if t == "jumped":
			_last_jump_t = _clock
			if state in GROUNDED and _enter_role("takeoff", _takeoff_key(), "jumped"):
				changed = true
		elif t == "landed":
			if state in AIRBORNE:
				_land(float(e.get("impact", -inp.last_air_vy)))
				changed = true
	if changed:
		return true
	if state in AIRBORNE and inp.on_floor and time_in_state > 0.25:
		_land(-inp.last_air_vy)
		return true
	if state in GROUNDED and not inp.on_floor and inp.air_time > _coyote:
		if _enter_role("fall", "ground_to_fall", "airborne %.2f s without a jump" % inp.air_time):
			return true
	# jump_to_fall (proposed): the jump clip ended and the player is still airborne. The row's
	# `when` also has vy < -3.0, which a flat jump reaches before it lands (4.4 m/s at
	# touchdown): the graph keeps jump-long until the landing, so that clause is not used.
	if state == JUMP and not inp.on_floor and phase() >= 1.0 - 1e-5:
		if _enter_role("fall", "jump_to_fall", "jump clip ended while airborne"):
			return true
	return _aim_rules(aim_stance)


func _aim_rules(aim_stance: bool) -> bool:
	if not aim_stance:
		return false
	var fade := float(data.transition_use("idle_to_aimidle").get("fade_s", 0.2))
	match state:
		IDLE, TURN:
			return _enter_gs("aim-idle", "idle_to_aimidle", fade, "aim_stance")
		START, STOP, REVERSAL:
			if moving:
				return _enter_gs(_aim_run_for_dir(), "aim_enter_move", fade, "aim_stance while moving")
			return _enter_gs("aim-idle", "idle_to_aimidle", fade, "aim_stance")
		CCHANGE:
			# (a crouch change while aiming held its last frame, the deep crouch, for as long as the aim lasted: no record
			# leaves it in an aim stance; user 2026-09-30) once the change has played out, the aim idle of the new stance
			if phase() >= 0.98:
				return _enter_gs("aim-idle", "idle_to_aimidle", fade, "aim_stance after a crouch change")
		MOVE:
			if not aimed:
				# Relabel only: the aim-run state on the same move-bank input and hemisphere (no
				# fade, nothing changes on screen). When the mode changed this tick the records'
				# change-move-mode (aim-remapped) moves to the new bank with its fade first.
				var gs := "aim-run-forward" if hemi == &"fw" else "aim-run-backward"
				var res := _resolve(gs)
				if res.is_empty() or res.input != _primary(input_id):
					return false
				return _enter_gs(gs, "aim_enter_move", 0.0, "aim_stance while moving (relabel)")
	return false


func _post_requests(inp: AnimInputs, aim_stance: bool) -> void:
	for r in _held.keys():
		if _clock - float(_held[r]) > held_max_age_s:
			_held.erase(r)
			if r == REQ_MODE:
				crouch_change_pending = false
	_requests = _held.duplicate()
	var fw := absf(move_dir_deg) <= float(data.threshold("hemi_enter_deg", 90.0))
	match state:
		LAND:
			if moving:
				_requests[REQ_FW if fw else REQ_BW] = true
				_requests[REQ_MODE] = true
			else:
				_requests[REQ_IDLE] = true
		HIT:
			if moving and time_in_state + 1e-6 >= _hit_gate:
				_requests[REQ_FW if fw else REQ_BW] = true
		AIM_IDLE:
			if not aim_stance:
				_requests[REQ_IDLE] = true
		MOVE:
			if aimed and not aim_stance:
				_requests[REQ_RUN if moving else REQ_IDLE] = true
	if state in [MOVE, START, REVERSAL] and not aimed and _uta() and moving and inp.speed >= reversal_min_speed \
			and inp.wish_local.length() > float(data.tuning("moving_on_wish", 0.05)) \
			and absf(wrapf(wish_dir_deg - vel_dir_deg, -180.0, 180.0)) >= reversal_angle_deg:
		if hemi == &"fw" and absf(wish_dir_deg) > float(data.threshold("hemi_to_bw_deg", 97.5)):
			_requests[REQ_REV_TO_BW] = true
		elif hemi == &"bw" and absf(wish_dir_deg) < float(data.threshold("hemi_to_fw_deg", 82.5)):
			_requests[REQ_REV_TO_FW] = true


## The current graph state's records in source order; the first that matches fires.
func _eval_records(aim_stance: bool) -> bool:
	var st: Dictionary = data.graph.get("graph_states", {}).get(graph_state, {})
	var trs: Array = st.get("transitions", [])
	if trs.is_empty():
		return false
	_fill_expr_vals()
	var ph := phase()
	for r: Dictionary in trs:
		var target := String(r.get("target", ""))
		var req := String(r.get("request", "auto"))
		var rec_off := String(r.get("record", ""))
		if req == "auto" and target == graph_state:
			continue   # loop record: the input's custom timeline loops
		if req != "auto" and not _requests.has(req):
			continue
		if _rec_opt.has(rec_off) and not bool(data.option(String(_rec_opt[rec_off]), true)):
			continue
		var tgt := target
		if aim_stance and not _is_aim_state(graph_state) and AIM_REMAP.has(target):
			tgt = String(AIM_REMAP[target])
		var res := _resolve(tgt)
		if res.is_empty():
			continue
		# no stop clip after a forward run however short: the start's own stop record (phase >= 0.2) is not on use_transition_anims, so
		# it is passed over here and the start's next record (straight to idle) fires; user 2026-09-30: "that forward stop is terrible"
		if no_forward_stop_anim and res.rt == STOP and state == START and hemi == &"fw":
			continue
		var key := _key_for(rec_off)
		var use: Dictionary = data.transition_use(key, rec_off) if key != "graph_record" else record_use(r)
		if not _conditions_ok(r, use, ph):
			continue
		if req == REQ_MODE and crouch_change_pending and data.override_enabled("override_crouch_crossfade"):
			var ov: Dictionary = data.override_info("override_crouch_crossfade").get("transitions", {})
			var f: Variant = ov.get("idle_stance_change", {}).get("fade_s")
			if f != null:
				use = use.duplicate()
				use["fade_s"] = float(f)
				use["override"] = "override_crouch_crossfade"
		# Consume the request.
		if req != "auto":
			_held.erase(req)
			_requests.erase(req)
			if req == REQ_MODE:
				crouch_change_pending = false
		if res.input == _primary(input_id) and tgt == graph_state and (String(res.get("hemi", "")) == "" or String(res.hemi) == String(hemi)):
			# Self re-entry into the same content (e.g. aim-idle on a walk / run change): nothing
			# changes on screen, so the request is consumed and the later records still get
			# their turn this frame instead of one frame later.
			continue
		var info := _info(key, use, "record %s (%s)" % [rec_off, r.get("condition_text", "")])
		info["record"] = rec_off
		info["request"] = req
		info["graph_target"] = target
		if tgt != target:
			info["aim_remap"] = tgt
		_enter(tgt, res, float(use.get("fade_s", 0.0)), info)
		return true
	return false


## Gameplay override G6 (override_immediate_land_move, off by default): movement leaves any
## landing at once. Gated records already fire at once under the override (gate 0); this covers
## the landings without a movement record (jump-long-land-run exits only by phase).
func _override_rules(aim_stance: bool) -> bool:
	if state != LAND or not moving or not data.override_enabled("override_immediate_land_move"):
		return false
	var fw := absf(move_dir_deg) <= float(data.threshold("hemi_enter_deg", 90.0))
	var gs := "run-fw" if fw else "run-bkwd"
	if aim_stance:
		gs = String(AIM_REMAP[gs])
	var use := data.transition_use("land_to_move")
	use = use.duplicate()
	use["override"] = "override_immediate_land_move"
	return _enter_gs(gs, "land_to_move", float(use.get("fade_s", 0.2)), "moving in a landing (override G6)", use)


func _conditions_ok(r: Dictionary, use: Dictionary, ph: float) -> bool:
	for c: Dictionary in r.get("conditions", []):
		var mode_c := int(c.get("mode", 0))
		var var_name := String(c.get("variable", ""))
		if mode_c != 0:
			if var_name.begins_with("frames"):
				var gate := float(use.get("gate_s", float(c.get("min", 0.0)) / _fps)) if use.has("gate_s") else float(c.get("min", 0.0)) / _fps
				if time_in_state + 1e-6 < gate:
					return false
			else:
				var val := 0.0
				if var_name.begins_with("phase"):
					val = ph
				elif var_name.begins_with("secondary"):
					val = move_dir_deg
				if not _compare(val, mode_c, c.get("min"), c.get("max")):
					return false
		var ex: Variant = c.get("expr")
		if ex is String and ex != "":
			if not _eval_expr(String(ex)):
				return false
	return true


static func _compare(v: float, m: int, lo: Variant, hi: Variant) -> bool:
	const EPS := 1e-5
	match m:
		1:
			return hi == null or v <= float(hi) + EPS
		2:
			return lo == null or v + EPS >= float(lo)
		3:
			return (lo == null or v + EPS >= float(lo)) and (hi == null or v <= float(hi) + EPS)
	return true


func _fill_expr_vals() -> void:
	_expr_vals[0] = loco_enabled
	_expr_vals[1] = _move_speed()
	_expr_vals[2] = move_dir_deg
	# (no stop clip after a forward run: MOVE goes to IDLE on the graph's own use_transition_anims = false branch; the backward stop and the
	# start from idle keep theirs; user 2026-09-30: "there's still a stop animation")
	_expr_vals[3] = _uta() and not (no_forward_stop_anim and state == MOVE and hemi == &"fw")
	_expr_vals[4] = 1 if crouch_change_pending else 0
	_expr_vals[5] = idle_turn_deg
	_expr_vals[6] = 0.0
	_expr_vals[7] = 0
	_expr_vals[8] = 0.0
	_expr_vals[9] = 0.0


func _eval_expr(src: String) -> bool:
	var e: Variant = _expr.get(src, false)
	if e is bool:
		var ex := Expression.new()
		if ex.parse(src, PackedStringArray(EXPR_VARS)) != OK:
			_warn_once("expr:" + src, "LocoBrain: cannot parse graph condition '%s' (%s); treated as false" % [src, ex.get_error_text()])
			_expr[src] = null
			return false
		_expr[src] = ex
		e = ex
	if e == null:
		return false
	var v: Variant = (e as Expression).execute(_expr_vals, null, false)
	if (e as Expression).has_execute_failed():
		_warn_once("exec:" + src, "LocoBrain: graph condition '%s' failed: %s" % [src, (e as Expression).get_error_text()])
		return false
	return bool(v)


# --- entering states --------------------------------------------------------------------------

## Frontier-only (proposed): a jump out of a crouch-stance input stands up into the take-off
## (the graph has no crouched jump) with its own row, crouch_to_takeoff; else ground_to_takeoff.
func _takeoff_key() -> String:
	if data.transition("crouch_to_takeoff").is_empty():
		return "ground_to_takeoff"
	for m in idx.lower_record(input_id).get("modes", []):
		if data.stance_of(String(m)) == "crouch":
			return "crouch_to_takeoff"
	return "ground_to_takeoff"


func _enter_role(role: String, key: String, reason: String) -> bool:
	var gs := String(_gs_of_role.get(role, ""))
	if gs == "":
		return false
	var use := data.transition_use(key)
	return _enter_gs(gs, key, float(use.get("fade_s", 0.2)), reason, use)


func _enter_gs(gs: String, key: String, fade: float, reason: String, use := {}) -> bool:
	var res := _resolve(gs)
	if res.is_empty():
		return false
	if use.is_empty():
		use = data.transition_use(key) if data.transition(key).size() > 0 else LOCAL_ROWS.get(key, {}).duplicate()
	var info := _info(key, use, reason)
	info["fade_used"] = fade
	if res.input == _primary(input_id) and gs == graph_state:
		return false
	_enter(gs, res, fade, info)
	return true


func _land(impact: float) -> void:
	var sel := landing_role(impact)
	var role := String(sel.role)
	var gs := String(_gs_of_role.get(role, ""))
	var res := _resolve(gs)
	if res.is_empty():
		var fb: Variant = data.graph.get("landing", {}).get("fallback", {}).get(role)
		if fb is String:
			sel["fallback_from"] = role
			role = fb
			sel.role = role
			gs = String(_gs_of_role.get(role, ""))
			res = _resolve(gs)
	if res.is_empty():
		_warn_once("land:" + role, "LocoBrain: no landing input for %s/%s/%s; idle instead" % [weapon, mode, role])
		gs = "idle"
		res = _resolve(gs)
		if res.is_empty():
			return
	last_landing = sel
	var use := data.transition_use("air_to_land")
	var info := _info("air_to_land", use, "landed at %.2f m/s: %s %s %s -> %s" % [impact, sel.kind, sel.band, sel.dir, role])
	info["landing"] = sel
	_enter(gs, res, float(use.get("fade_s", 0.1)), info)


## The landing table (graph `landing`, proposed): {role, kind, band, dir, impact}.
func landing_role(impact: float) -> Dictionary:
	var ld: Dictionary = data.graph.get("landing", {})
	var hard := float(ld.get("hard_impact_mps", 8.0))
	var med := float(ld.get("medium_impact_mps", 6.0))
	var band := "hard" if impact >= hard else ("medium" if impact >= med else "soft")
	var jump_len := data.clip_length(data.role_clip(String(weapon), String(mode), "jump"))
	if jump_len <= 0.0:
		jump_len = 0.9
	var recent := (_clock - _last_jump_t) <= jump_len + float(ld.get("jump_land_window_s", 0.25))
	var sel_t: Dictionary = ld.get("select", {})
	var kind := "jump" if recent and sel_t.get("jump", {}).has(band) else "fall"
	var dir := "idle"
	var back := float(ld.get("derived", {}).get("backward_deg", data.threshold("hemi_enter_deg", 90.0)))
	if moving:
		dir = "run" if absf(move_dir_deg) <= back else "run_bw"
	elif kind == "jump":
		# jump-long's only landing record (0x000256a0, request idle) is gated at phase >= 0.9; a
		# touchdown within jump_land_gate_tolerance_s of that gate is taken as reaching it (the
		# graph would fire it a frame or two later), an earlier one is an early landing.
		var jp := 1.0
		var left_s := 0.0
		var gate := float(data.threshold("jump_land_phase", 0.9))
		if state == JUMP:
			jp = phase()
			left_s = (gate - jp) * maxf(jump_len, 1e-3)
		elif state == TAKEOFF:
			jp = 0.0
			left_s = INF
		if jp < gate and left_s > jump_land_gate_tolerance_s + 1e-6:
			dir = "idle_early"
	var table: Dictionary = sel_t.get(kind, {}).get(band, {})
	var role := String(table.get(dir, table.get("idle", "land_soft_idle")))
	return {"role": role, "kind": kind, "band": band, "dir": dir, "impact": impact}


func _enter(gs: String, res: Dictionary, fade: float, info: Dictionary) -> void:
	var from := state
	var from_gs := graph_state
	var new_hemi := String(res.get("hemi", ""))
	var entry := _entry_phase(gs, from_gs, res)
	var new_input := _pick_instance(res.input, gs, from_gs, info)
	if new_input != res.input:
		res = res.duplicate()
		res.input = new_input
	fade = _guard_fade(fade, new_input, info)
	fade = _stance_switch(fade, new_input, info)
	if new_input == input_id:
		if new_hemi != "" and new_hemi != String(hemi):
			var hs := _hemi_sel(new_input)
			if hs != null:
				if hs.weight(StringName(new_hemi)) <= 0.0 and entry >= 0.0:
					_seek(new_input, new_hemi, entry)
				hs.request(StringName(new_hemi), fade)
	else:
		var fresh := L.weight(new_input) <= 0.0
		if new_hemi != "":
			var hs := _hemi_sel(new_input)
			if hs != null:
				if fresh:
					hs.set_immediate(StringName(new_hemi))
					hs.write()
				else:
					# A hemisphere with no weight is frozen at an old phase: seek it on entry.
					if hs.weight(StringName(new_hemi)) <= 0.0 and entry >= 0.0:
						_seek(new_input, new_hemi, entry)
					hs.request(StringName(new_hemi), fade)
		if fresh and entry >= 0.0:
			_seek(new_input, new_hemi, entry)
		L.request(new_input, fade)
	info["fade_used"] = fade
	info["entry_phase"] = entry
	_apply_state(gs, res)
	_emit(from, from_gs, info)


## The input slot a state entry plays on (see "Instance stack" in the header): the primary for
## inputs without instances; the current slot when the -begin shim continues into its state;
## else a slot with no weight (it is seeked to the entry phase), else the least weighted slot
## other than the current one (it continues its phase; info instance_reused).
func _pick_instance(prim: StringName, gs: String, from_gs: String, info: Dictionary) -> StringName:
	var slots: Array = idx.lower_record(prim).get("instances", [])
	if slots.size() < 2:
		return prim
	if _primary(input_id) == prim and from_gs == gs + "-begin" and bool(_gs.get(from_gs, {}).get("begin", false)):
		return input_id
	var best := &""
	var best_w := INF
	for s in slots:
		var sid := StringName(s)
		if sid == input_id:
			continue
		var w := L.weight(sid)
		if w <= 0.0 and sid != L.target():
			info["instance"] = String(sid)
			return sid
		if w < best_w:
			best_w = w
			best = sid
	if best == &"":
		return prim
	info["instance"] = String(best)
	info["instance_reused"] = best_w
	return best


## A fade-0 record while the current input is still fading in: the remaining fade time of that
## fade instead of a cut (header, "Fade-0 records"); info fade_guard = the time used.
func _guard_fade(fade: float, new_input: StringName, info: Dictionary) -> float:
	if fade > 0.0 or new_input == input_id:
		return fade
	var out := fade
	if L.target() == input_id and L.weight(input_id) < 1.0:
		var rate := float(L.snapshot().get("rate", INF))
		if not is_inf(rate) and rate > 0.0:
			out = (1.0 - L.weight(input_id)) / rate
			info["fade_guard"] = out
	if join_fade_s > out:
		out = join_fade_s
		info["override"] = "join_fade_s"
	return out


## Inertialized stance change (ch-crouchB): a transition with a fade into an input of the other
## stance (crouch <-> stand: the other stance's bank, idle or aim idle, the full-body crouch
## change) switches the lower selector at once (the entry phase already matched to the stride:
## _entry_phase) and asks StanceInertializer to blend the shown pose into it over the record's fade
## (inertia_request; info inertialized = that fade). crouch_crossfade_blend keeps the crossfade.
## A landing keeps the graph's crossfade: the airborne inputs carry the mode of the take-off (a jump
## from a crouch plays jump__crouch, though every jump stands up), so a landing looked like a stance
## change, and its short fade (air_to_land 0.1 s) inertialized the arms in half of it (StanceInertializer
## calm bones): the bow and pistol arms swung 1.6 rad in three frames, the wrist at 56-126 rad/s
## (test_continuity's storms, push n09).
func _stance_switch(fade: float, new_input: StringName, info: Dictionary) -> float:
	if crouch_crossfade_blend or fade <= 0.0 or new_input == input_id or state in AIRBORNE:
		return fade
	var a := _input_stance(input_id)
	var b := _input_stance(new_input)
	if a == "" or b == "" or a == b:
		return fade
	inertia_request = fade
	info["inertialized"] = fade
	return 0.0


## Stance of a lower input ("stand" / "crouch"; "" when it serves both or is unknown). The crouch
## change inputs count as their destination stance.
func _input_stance(id: StringName) -> String:
	if id == &"":
		return ""
	var ms: Array = idx.lower_record(_primary(id)).get("modes", [])
	var st := ""
	for m in ms:
		var s := data.stance_of(String(m))
		if st != "" and s != st:
			return ""
		st = s
	return st


## The primary input of an instance slot (the input itself otherwise).
func _primary(id: StringName) -> StringName:
	var r := idx.lower_record(id)
	return StringName(r.instance_of) if r.has("instance_of") else id


func _apply_state(gs: String, res: Dictionary) -> void:
	var rt: StringName = res.rt
	if rt == STOP and (state != STOP or res.input != input_id):
		_stop_entry_speed = stop_entry_speed()
		_stop_entry[String(res.input)] = _stop_entry_speed
	if rt == IDLE and state != IDLE and state != TURN:
		anim_yaw_deg = rad_to_deg(_inp.yaw)
		idle_turn_deg = 0.0
	graph_state = gs
	state = rt
	input_id = res.input
	if String(res.get("hemi", "")) != "":
		hemi = StringName(res.hemi)
	aimed = bool(res.get("aimed", false))
	time_in_state = 0.0


## Entry phase of a graph state (normalized; -1 = keep): see the header.
func _entry_phase(gs: String, from_gs: String, res: Dictionary) -> float:
	var spec: Dictionary = _gs.get(gs, {})
	var rt: StringName = spec.get("rt", &"")
	if rt == MOVE:
		var h := String(spec.get("hemi", "fw"))
		if not spec.get("aimed", false) and from_gs in MOVE_ZERO_FROM.get(h, []):
			return 0.0
		var from_spec: Dictionary = _gs.get(from_gs, {})
		if from_spec.get("rt", &"") == MOVE:
			return _gait_match(input_id, String(hemi), res.input, h)
		if spec.get("aimed", false):
			return 0.0
		return _heel_match(res.input, h)
	if spec.get("kind", "") == "aimidle":
		# The aim tree's base phase one frame ahead: a seek applies without advancing that frame
		# (engine contract ec_timeseek_timescale) while the aim input advances by dt x its scale,
		# so both read the same phase after this frame's advance.
		var a: Dictionary = idx.aim.get("%s/%s" % [weapon, stance], {})
		if a.has("position_node"):
			var ph := float(tree.get(a.position_node))
			if a.has("ts"):
				ph += _dt * float(tree.get(a.ts))
			return fposmod(ph, 1.0)
	return 0.0


func _emit(from: StringName, from_gs: String, info: Dictionary) -> void:
	info["from_graph"] = from_gs
	info["to_graph"] = graph_state
	info["input_id"] = String(input_id)
	info["hemi"] = String(hemi)
	info["mode"] = String(mode)
	info["frame"] = _frame
	info["t"] = _clock
	var key := String(info.get("key", ""))
	_counts[key] = int(_counts.get(key, 0)) + 1
	_trace.append({"frame": _frame, "t": _clock, "from": String(from), "to": String(state), "from_graph": from_gs,
			"to_graph": graph_state, "key": key, "record": info.get("record", ""), "fade_graph": info.get("fade_graph", 0.0),
			"fade_used": info.get("fade_used", 0.0), "status": info.get("status", ""), "reason": info.get("reason", "")})
	while _trace.size() > TRACE_MAX:
		_trace.pop_front()
	transitioned.emit(from, state, info)


func _info(key: String, use: Dictionary, reason: String) -> Dictionary:
	var row := data.transition(key)
	var status := String(use.get("status", row.get("status", LOCAL_ROWS.get(key, {}).get("status", ""))))
	return {"key": key, "reason": reason, "record": String(use.get("record", "")), "status": status,
			"fade_graph": float(use.get("fade_graph", use.get("fade_s", 0.0))), "fade_used": float(use.get("fade_s", 0.0)),
			"override": String(use.get("override", "")), "row": "table" if not row.is_empty() else ("local" if LOCAL_ROWS.has(key) else "")}


# --- banks ------------------------------------------------------------------------------------

func _drive_banks(dt: float) -> void:
	var ws := L.weights()
	var tgt := L.target()
	for k in ws:
		var id := StringName(k)
		if float(ws[k]) <= 0.0 and id != tgt:
			continue
		var rec := idx.lower_record(id)
		if not rec.get("kind", "") in ["bank", "aimmove"]:
			continue
		var dw := _apply_positions(id, blend_pos)
		for h in rec.get("hemis", {}):
			var hr: Dictionary = rec.hemis[h]
			tree.set(hr.ts, _rate(id, rec, String(h), dw[h]))
		var hs := _hemi_sel(id)
		if hs != null:
			hs.update(dt)
			hs.write()


## {fw, bw}: true when that hemisphere has weight (or is the hemisphere target) in a bank input
## that has L weight or is the L target, i.e. its direction weights are on screen.
func _hemi_visible() -> Dictionary:
	var vis := {"fw": false, "bw": false}
	var ws := L.weights()
	var tg := L.target()
	for k in ws:
		var id := StringName(k)
		if float(ws[k]) <= 0.0 and id != tg:
			continue
		var rec := idx.lower_record(id)
		if not rec.get("kind", "") in ["bank", "aimmove"]:
			continue
		var hs := _hemi_sel(id)
		for h in rec.get("hemis", {}):
			if hs == null or hs.weight(StringName(h)) > 0.0 or hs.target() == StringName(h):
				vis[String(h)] = true
	return vis


## Timeline scale (cycles per second) of a bank hemisphere.
func _rate(id: StringName, rec: Dictionary, h: String, w2: Vector2) -> float:
	var hr: Dictionary = rec.hemis[h]
	var w3 := [maxf(0.0, 1.0 - w2.x - w2.y), w2.x, w2.y]
	for i in [1, 2]:
		if String(hr.clips[i]) == "":
			w3[0] += w3[i]
			w3[i] = 0.0
	var lengths: Array = hr.lengths
	if String(rec.get("group", "")) == "move" and bool(hr.get("loop", false)):
		var sv := 0.0
		var st := 0.0
		for i in 3:
			var c := String(hr.clips[i]) if String(hr.clips[i]) != "" else String(hr.clips[0])
			var v := data.clip_speed(c)
			sv += w3[i] * v
			st += w3[i] * v * float(lengths[i])
		if sv <= 1e-4 or st <= 1e-6:
			return 1.0 / maxf(float(lengths[0]), 1e-3)
		var cl: Array = data.tuning("rate_clamp", [0.55, 1.75])
		var raw := _inp.speed / sv
		var r := clampf(raw, float(cl[0]), float(cl[1]))
		if not moving:
			r = maxf(r, float(data.tuning("rate_floor_decel", 0.6)))
		if id == input_id and h == String(hemi):
			ratio = r
			ratio_raw = raw
		if id == input_id:
			rates[h] = r * sv / st
		return r * sv / st
	var tl := 0.0
	for i in 3:
		tl += w3[i] * float(lengths[i])
	var s := 1.0 / maxf(tl, 1e-3)
	if align_rate_sync:
		s *= _align_rate(id, rec, h, w3)
	if id == input_id:
		rates[h] = s
	return s


## Playback multiplier of the start / reversal (graph phase callback 0x0001466c) and stop
## (0x00013a6c) banks, with f32[D8+820] = the start's desired speed (_start_speed(), see
## start_speed_from_wish) or the reversal's body speed, f32[D4+16] = the speed on entering the stop and
## get-state-align-speed-from-tree(.., x) = the leaves' body speed (metrics body_profile) at
## normalized phase x, weighted by the direction weights (INFERRED; the flag i32[D4+24] that
## selects plain real time is taken as clear):
##   start / reversal: speed / align(1.0), at least 0.5 (1 when the align speed is 0);
##   stop: min(1, lerp-scale(0, 0.2, max(entry speed / align(0.0), 0.01), 1, phase)).
func _align_rate(id: StringName, rec: Dictionary, h: String, w3: Array) -> float:
	var g := String(rec.get("group", ""))
	var hr: Dictionary = rec.hemis[h]
	if g == "start" or g == "rev":
		var al := _align_speed(hr, w3, 1.0)
		if al <= 0.0:
			return 1.0
		# f32[D8+820]: through a start the body follows the clip (root_motion_speed()), so the
		# desired speed; through a reversal the body moves at the gameplay speed, so that one.
		var q := (_start_speed() if g == "start" else _inp.speed) / al
		q = q if q > 0.5 else 0.5
		if g == "start" and start_rate_boost:
			# Approximation (WP7): where the clip's own speed is below the desired speed the start
			# plays faster, as fast as reaches it but at most the locomotion rate clamp (plan D9):
			# the body follows the clip (root_motion_speed()), so a start from standing keeps
			# Frontier's responsiveness with the feet planted (graph rate: 0.8-3 s to full speed).
			var cl: Array = data.tuning("rate_clamp", [0.55, 1.75])
			var v1 := _start_clip_speed(id, rec, h, w3)
			if v1 > 1e-3:
				q = maxf(q, minf(_start_speed() / v1, float(cl[1])))
		return q
	if g == "stop":
		var al := _align_speed(hr, w3, 0.0)
		var k := 1.0 if al <= 0.0 else maxf(float(_stop_entry.get(String(id), _stop_entry_speed)) / al, 0.01)
		var m := _lerp_scale(0.0, 0.2, k, 1.0, _phase_of(id, h))
		return 1.0 if m > 1.0 else m
	return 1.0


## f32[D8+820] of the start / reversal phase callback (see start_speed_from_wish).
func _start_speed() -> float:
	if start_speed_from_wish:
		var w := _inp.wish_local.length()
		if w > 0.0:
			return w
	return _inp.speed


## Root-motion speed of a start (WP7): while the lower body plays a graph start state (START:
## idle^run-fwd / -bkwd and their walk / sprint / crouch clips), the horizontal body speed of its
## clips (INFERRED: the clips carry no root track; _profile_velocity() differentiates the metrics'
## foot-contact body_profile displacement, coverage 0.39-0.73 on some starts; blended as vectors
## by the direction weights, then by the hemisphere weights) at their current phase,
## times the speed they play at (_align_rate); the same through a graph stop (STOP) with its stop
## bank (stop_root_motion); -1 in every other state, where the body moves at the gameplay speed and
## the loops follow it (ratio). The source game's body is taken to follow the animation (INFERRED; see
## stop_entry_speed()), so a start from standing moves the body at the start clip's own speed:
## FrontierPlayer limits its speed to this through a start
## (PlayerAnim.body_speed_cap(); PlayerAnim.override_free_start_speed keeps player.gd's
## ground_accel instead, and the feet slide). With the start's rate from the desired speed
## (start_speed_from_wish) the body reaches the desired speed as the start clip ends.
func root_motion_speed() -> float:
	if input_id == &"" or not (state == START or (state == STOP and stop_root_motion)):
		return -1.0
	# The lower selector's crossfade into the start blends poses: an input that stands (idle, aim
	# idle, a turn in place) moves its feet with the body, so the body speed that keeps the
	# blended feet planted is the weighted sum: start inputs at their clip speed, standing inputs
	# at 0, any other (a stop, a landing, a hit) at the current body speed.
	var ws := L.weights()
	var total := 0.0
	var any := false
	for k in ws:
		var w := float(ws[k])
		if w <= 0.0:
			continue
		var rec := idx.lower_record(StringName(k))
		var g := String(rec.get("group", ""))
		if (g == "start" or g == "stop") and rec.get("kind", "") == "bank":
			var v := _start_root_speed(StringName(k), rec)
			if v >= 0.0:
				total += w * v
				any = true
				continue
		if g in ["idle", "aimidle"] or g.begins_with("turn_"):
			continue
		total += w * _inp.speed
	return total if any else -1.0


## Root-motion speed of one start bank input (see root_motion_speed()); -1 without hemispheres.
func _start_root_speed(id: StringName, rec: Dictionary) -> float:
	if rec.get("hemis", {}).is_empty():
		return -1.0
	var hs := _hemi_sel(id)
	var dw: Dictionary = _dir.get(String(id), {})
	var total := 0.0
	var tw := 0.0
	for h in rec.hemis:
		var hw := 1.0 if hs == null else hs.weight(StringName(h))
		if hw <= 0.0:
			continue
		var hr: Dictionary = rec.hemis[h]
		var w2: Vector2 = dw.get(h, Vector2.ZERO)
		var w3 := [maxf(0.0, 1.0 - w2.x - w2.y), w2.x, w2.y]
		for i in [1, 2]:
			if String(hr.clips[i]) == "":
				w3[0] += w3[i]
				w3[i] = 0.0
		var lengths: Array = hr.lengths
		var tl := 0.0
		for i in 3:
			tl += w3[i] * float(lengths[i])
		if tl <= 1e-6:
			continue
		var mult := _align_rate(id, rec, String(h), w3) if align_rate_sync else 1.0
		# The body moves in the physics tick before the next advance: take the clips' speed half
		# that advance ahead (the middle of the pose change the body's motion goes with).
		var ahead := 0.5 * _dt * float(tree.get(hr.ts)) if hr.has("ts") else 0.0
		total += hw * _start_clip_speed(id, rec, String(h), w3, ahead) * mult
		tw += hw
	return total / tw if tw > 0.0 else -1.0


## Body speed (m/s at playback rate 1; inferred, see _profile_velocity()) of a start bank
## hemisphere at its current phase
## (+ `ahead`, normalized):
## each clip of the synced direction chain plays at (its length / the blended length) of real
## time, and the blended pose moves the body by the blend of the clips' own motion (a vector: a
## 45 deg blend of a forward and a sideways start covers 0.71 of their speeds).
func _start_clip_speed(id: StringName, rec: Dictionary, h: String, w3: Array, ahead := 0.0) -> float:
	var hr: Dictionary = rec.hemis[h]
	var lengths: Array = hr.lengths
	var tl := 0.0
	for i in 3:
		tl += float(w3[i]) * float(lengths[i])
	if tl <= 1e-6:
		return 0.0
	var u := clampf(_phase_of(id, h) + ahead, 0.0, 1.0)
	var v := Vector2.ZERO
	for i in 3:
		if float(w3[i]) <= 0.0:
			continue
		var c := String(hr.clips[i]) if String(hr.clips[i]) != "" else String(hr.clips[0])
		v += float(w3[i]) * _profile_velocity(c, u) * float(lengths[i]) / tl
	return v.length()


## Horizontal body velocity of a clip (m per clip second; x = side, left +, y = forward) at
## normalized phase u, INFERRED from the feet (metrics body_profile is a foot-contact estimate, not
## an authored root track): the derivative of metrics body_profile's cumulative fwd / side
## displacement, linear between its sample intervals; its speed samples along forward when it has
## no displacement, the clip's travel speed when it has neither.
func _profile_velocity(clip: String, u: float) -> Vector2:
	var bp: Variant = data.clip_metrics(clip).get("body_profile")
	var fw: Array = bp.get("fwd", []) if bp is Dictionary else []
	var sd: Array = bp.get("side", []) if bp is Dictionary else []
	var length := data.clip_length(clip)
	if fw.size() >= 2 and sd.size() == fw.size() and length > 0.0:
		var n := fw.size() - 1
		var dt := length / float(n)
		var x := clampf(clampf(u, 0.0, 1.0) * float(n) - 0.5, 0.0, float(n - 1))
		var i := mini(int(x), maxi(n - 2, 0))
		var j := mini(i + 1, n - 1)
		var a := Vector2(float(sd[i + 1]) - float(sd[i]), float(fw[i + 1]) - float(fw[i])) / dt
		var b := Vector2(float(sd[j + 1]) - float(sd[j]), float(fw[j + 1]) - float(fw[j])) / dt
		return a.lerp(b, clampf(x - float(i), 0.0, 1.0))
	var sp: Array = bp.get("speed", []) if bp is Dictionary else []
	if sp.is_empty():
		return Vector2(0.0, data.clip_speed(clip))
	if sp.size() == 1:
		return Vector2(0.0, float(sp[0]))
	var xs := clampf(u, 0.0, 1.0) * float(sp.size() - 1)
	var k := mini(int(xs), sp.size() - 2)
	return Vector2(0.0, lerpf(float(sp[k]), float(sp[k + 1]), xs - float(k)))


func _align_speed(hr: Dictionary, w3: Array, at: float) -> float:
	var s := 0.0
	for i in 3:
		if float(w3[i]) <= 0.0:
			continue
		var c := String(hr.clips[i]) if String(hr.clips[i]) != "" else String(hr.clips[0])
		var ends: Array = _profile_ends(c)
		s += float(w3[i]) * (float(ends[1]) if at >= 0.5 else float(ends[0]))
	return s


## [body speed at the first sample, at the last sample] of a clip (metrics body_profile; the
## travel speed when it has none).
func _profile_ends(clip: String) -> Array:
	if _ends.has(clip):
		return _ends[clip]
	var out := [0.0, 0.0]
	var bp: Variant = data.clip_metrics(clip).get("body_profile")
	var sp: Array = bp.get("speed", []) if bp is Dictionary else []
	if not sp.is_empty():
		out = [float(sp[0]), float(sp[sp.size() - 1])]
	else:
		var v := data.clip_speed(clip)
		out = [v, v]
	_ends[clip] = out
	return out


func _hemi_sel(id: StringName) -> XFadeSelector:
	var k := String(id)
	if _hemi_sels.has(k):
		return _hemi_sels[k]
	var rec := idx.lower_record(id)
	var hs: XFadeSelector = null
	if rec.get("hemi_param") != null and rec.get("hemis", {}).size() == 2:
		var seeks := {}
		for h in rec.hemis:
			seeks[h] = [rec.hemis[h].seek]
		hs = XFadeSelector.new(tree, String(rec.hemi_prefix), PackedStringArray(["fw", "bw"]), seeks)
		hs.write()
	_hemi_sels[k] = hs
	return hs


func _dominant_hemi(id: StringName) -> String:
	var hs := _hemi_sel(id)
	if hs != null:
		return String(hs.dominant())
	var rec := idx.lower_record(id)
	for h in rec.get("hemis", {}):
		return String(h)
	return ""


func _seek(id: StringName, h: String, u: float) -> void:
	var rec := idx.lower_record(id)
	if rec.is_empty():
		return
	if h != "" and rec.get("hemis", {}).has(h):
		tree.set(rec.hemis[h].seek, clampf(u, 0.0, 1.0))
	elif rec.has("seek"):
		tree.set(rec.seek, clampf(u, 0.0, 1.0))


## Normalized phase of a lower input's hemisphere; a seek requested since the tree last advanced
## (its TimeSeek seek_request is >= 0 until the next advance applies it) counts as done, so an
## entry made between frames (play_hit, play_death) is not judged at the phase it left off at.
func _phase_of(id: StringName, h: String) -> float:
	if id == &"":
		return 0.0
	var rec := idx.lower_record(id)
	var sp: Variant = rec.get("seek")
	if rec.has("hemis") and not rec.hemis.is_empty():
		var hs: Dictionary = rec.hemis
		var hr: Dictionary = hs.get(h, hs.get("fw", hs.get("bw", {})))
		sp = hr.get("seek")
	if sp != null:
		var v: Variant = tree.get(sp)
		if v != null and float(v) >= 0.0:
			return float(v)
	return idx.phase(tree, id, h)


func _center_clip(id: StringName, h: String) -> String:
	var rec := idx.lower_record(id)
	if rec.has("hemis"):
		var hr: Dictionary = rec.hemis.get(h, rec.hemis.values()[0] if not rec.hemis.is_empty() else {})
		return String(hr.get("clips", [""])[0]) if not hr.is_empty() else ""
	return String(rec.get("clip", ""))


# --- phase matching (graph calc-ankle-match-phase) --------------------------------------------

## Gait phase of the outgoing bank hemisphere -> the phase of the incoming one in the nearest stride.
func _gait_match(from_id: StringName, from_h: String, to_id: StringName, to_h: String) -> float:
	var c_out := _center_clip(from_id, from_h)
	var c_in := _center_clip(to_id, to_h)
	# The outgoing bank's phase after this frame's advance (the seeked incoming one does not
	# advance this frame): the two then share the gait phase on screen.
	var u_out := _phase_of(from_id, from_h)
	var fr := idx.lower_record(from_id)
	if fr.get("hemis", {}).has(from_h):
		u_out = fposmod(u_out + _dt * float(tree.get(fr.hemis[from_h].ts)), 1.0)
	if c_out == "" or c_in == "":
		return fposmod(u_out, 1.0)
	if _gait_table(c_out).is_empty() or _gait_table(c_in).is_empty():
		return fposmod(u_out, 1.0)
	return phase_for_gait(c_in, gait_phase(c_out, u_out), u_out)


## From a static pose: the plant phase (gait 0 = left plant, 0.5 = right plant) of the incoming
## clip whose forward heel spread (metrics heel_z, left minus right) is closest to the live pose.
func _heel_match(to_id: StringName, to_h: String) -> float:
	var clip := _center_clip(to_id, to_h)
	if clip == "" or _gait_table(clip).is_empty():
		return 0.0
	var sk := _skeleton()
	var hz: Variant = data.clip_metrics(clip).get("heel_z")
	var u0 := phase_for_gait(clip, 0.0, 0.0)
	var u5 := phase_for_gait(clip, 0.5, 0.5)
	if sk == null or not hz is Dictionary:
		return u0
	var li := sk.find_bone("l_heel")
	var ri := sk.find_bone("r_heel")
	if li < 0 or ri < 0:
		return u0
	var d_cur := sk.get_bone_global_pose(li).origin.z - sk.get_bone_global_pose(ri).origin.z
	var d0 := _heel_spread(hz, clip, u0)
	var d5 := _heel_spread(hz, clip, u5)
	return u0 if absf(d0 - d_cur) <= absf(d5 - d_cur) else u5


func _heel_spread(hz: Dictionary, clip: String, u: float) -> float:
	var l: Array = hz.get("l", [])
	var r: Array = hz.get("r", [])
	var rate := float(hz.get("rate", 10.0))
	if l.is_empty() or r.is_empty() or l.size() != r.size():
		return 0.0
	var x := clampf(u * data.clip_length(clip) * rate, 0.0, float(l.size() - 1))
	var i := mini(int(x), l.size() - 2) if l.size() > 1 else 0
	var f := x - i
	if l.size() == 1:
		return float(l[0]) - float(r[0])
	return lerpf(float(l[i]), float(l[i + 1]), f) - lerpf(float(r[i]), float(r[i + 1]), f)


## [[u, G], ...]: plant onsets on the unwrapped gait coordinate G (left onsets at integers, right
## onsets at half integers), with one wrapped sentinel at each end; [] when the plants do not
## alternate left / right.
func _gait_table(clip: String) -> Array:
	if _gait.has(clip):
		return _gait[clip]
	var out: Array = []
	var p := data.plants(clip)
	var l: Array = p.get("l", [])
	var r: Array = p.get("r", [])
	if not l.is_empty() and l.size() == r.size():
		var ev: Array = []
		for u in l:
			ev.append([fposmod(float(u), 1.0), 0])
		for u in r:
			ev.append([fposmod(float(u), 1.0), 1])
		ev.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var ok := true
		for i in range(1, ev.size()):
			if ev[i][1] == ev[i - 1][1]:
				ok = false
		if ok and ev.size() >= 2 and ev[0][1] != ev[ev.size() - 1][1]:
			var g := 0.0 if ev[0][1] == 0 else 0.5
			var n := ev.size() >> 1
			for e in ev:
				out.append([float(e[0]), g])
				g += 0.5
			var first: Array = out[0]
			var last: Array = out[out.size() - 1]
			out.push_front([float(last[0]) - 1.0, float(last[1]) - n])
			out.append([float(first[0]) + 1.0, float(first[1]) + n])
	_gait[clip] = out
	return out


static func _gait_g(tb: Array, u: float) -> float:
	for i in tb.size() - 1:
		var a: Array = tb[i]
		var b: Array = tb[i + 1]
		if u >= float(a[0]) and u <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6))
	return float(tb[0][1])


# --- tables -----------------------------------------------------------------------------------

func _build_state_map() -> void:
	var roles: Dictionary = data.graph.get("roles", {})
	var role_state := {}
	for k in roles:
		var r := String(k).get_slice("/", 2)
		if not role_state.has(r) and roles[k] is Dictionary and roles[k].get("state") is String:
			role_state[r] = String(roles[k].state)
	for g in AnimGraphData.BANK_GROUPS:
		for h in ["fw", "bw"]:
			var rs := data.bank_roles(String(AnimGraphData.BANK_GROUPS[g][h]))
			if rs.is_empty() or not role_state.has(rs[0]):
				continue
			var st := String(role_state[rs[0]])
			_gs[st] = {"kind": "bank", "group": g, "hemi": h, "rt": RT_OF_GROUP[g], "role": rs[0]}
			for r in rs:
				_gs_of_role[r] = st
			if g == "rev":
				_gs[st + "-begin"] = {"kind": "bank", "group": g, "hemi": h, "rt": REVERSAL, "role": rs[0], "begin": true}
	for r in role_state:
		if data.is_bank_role(r) or r == "hit_add":
			continue
		var st := String(role_state[r])
		var spec := {"kind": "single", "role": r, "rt": _rt_of_role(r)}
		if r == "hit_full":
			spec = {"kind": "hit", "role": r, "rt": HIT}
		elif r == "death":
			spec = {"kind": "death", "role": r, "rt": DEATH}
		_gs[st] = spec
		_gs_of_role[r] = st
	_gs["aim-idle"] = {"kind": "aimidle", "rt": AIM_IDLE, "role": "aimidle"}
	_gs["aim-run-forward"] = {"kind": "bank", "group": "move", "hemi": "fw", "rt": MOVE, "aimed": true, "role": "fw"}
	_gs["aim-run-backward"] = {"kind": "bank", "group": "move", "hemi": "bw", "rt": MOVE, "aimed": true, "role": "bw"}
	_gs["crouch-change-idle^idle"] = {"kind": "cchange", "rt": CCHANGE, "role": "cchange"}


static func _rt_of_role(r: String) -> StringName:
	if r == "idle":
		return IDLE
	if r == "takeoff":
		return TAKEOFF
	if r == "jump":
		return JUMP
	if r == "fall" or r == "pre_fall":
		return FALL
	if r.begins_with("land"):
		return LAND
	if r.begins_with("turn") or r.begins_with("quick_turn"):
		return TURN
	return IDLE


func _build_record_index() -> void:
	var rows: Dictionary = data.graph.get("transitions", {})
	var keys := rows.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = rows[key]
		var recs: Array = []
		if row.get("graph") is Dictionary:
			recs.append(String(row.graph.get("record", "")))
		for v in row.get("graph_variants", []):
			var ro := String(v.get("record", ""))
			recs.append(ro)
			if v.has("requires_option"):
				_rec_opt[ro] = String(v.requires_option)
		for ro in recs:
			if ro == "":
				continue
			if not _rec_keys.has(ro):
				_rec_keys[ro] = []
			if not _rec_keys[ro].has(key):
				_rec_keys[ro].append(key)
	# Primary rows first (a record is the primary record of at most one row).
	for ro in _rec_keys:
		var ks: Array = _rec_keys[ro]
		ks.sort_custom(func(a: String, b: String) -> bool:
			var pa: bool = rows[a].get("graph") is Dictionary and String(rows[a].graph.get("record", "")) == ro
			var pb: bool = rows[b].get("graph") is Dictionary and String(rows[b].graph.get("record", "")) == ro
			if pa != pb:
				return pa
			return a < b)


## The transitions key of a graph record: its row (crouch rows first while a crouch toggle is
## pending), or "graph_record" when no row lists it (never "").
func _key_for(record: String) -> String:
	var keys: Array = _rec_keys.get(record, [])
	if keys.is_empty():
		return "graph_record"
	if crouch_change_pending:
		for k in keys:
			if k in CROUCH_ROWS:
				return k
	for k in keys:
		if not k in CROUCH_ROWS:
			return k
	return keys[0]


## The use of a graph record that no transitions row lists (key "graph_record"): its own fade;
## its frame / phase gates come from its conditions.
static func record_use(r: Dictionary) -> Dictionary:
	var f := float(r.get("fade_s", 0.0))
	return {"key": "graph_record", "record": String(r.get("record", "")), "status": "graph", "fade_s": f,
			"fade_graph": f, "override": ""}


## The transitions key a graph record fires under (tests: static coverage check).
func key_for_record(record: String) -> String:
	return _key_for(record)


## Input of a graph state for the current weapon / mode / stance: {input, hemi, rt, aimed, kind,
## role}, or {} when the state has no input (no clip, option off, or not a Frontier state).
## arg: the hit sector or death variant.
func _resolve(gs: String, arg := "") -> Dictionary:
	var spec: Dictionary = _gs.get(gs, {})
	if spec.is_empty():
		return {}
	var w := String(weapon)
	var m := String(mode)
	var id := &""
	match String(spec.kind):
		"bank":
			id = idx.input_for("%s/%s/%s" % [w, m, spec.group])
			if id != &"" and not idx.lower_record(id).get("hemis", {}).has(spec.hemi):
				id = &""
		"single":
			var role := String(spec.role)
			if role.begins_with("turn_") and (not bool(data.option("idle_turns", true))
					or (role.ends_with("_180") and not bool(data.option("turn_180", true)))):
				return {}
			id = idx.input_for("%s/%s/%s" % [w, m, role])
		"aimidle":
			id = idx.input_for("%s/%s/aimidle" % [w, stance])
		"cchange":
			if not bool(data.option("crouch_change_full_body", true)):
				return {}
			var dir := arg if arg != "" else ("stand_to_crouch" if stance == "crouch" else "crouch_to_stand")
			id = idx.input_for("%s/%s/cchange" % [w, dir])
		"hit":
			id = idx.input_for("%s/%s/hit_full/%s" % [w, m, arg])
		"death":
			id = idx.input_for("%s/%s/death/%s" % [w, m, arg])
	if id == &"" or not L.has_input(id):
		return {}
	return {"input": id, "hemi": String(spec.get("hemi", "")), "rt": spec.rt, "aimed": bool(spec.get("aimed", false)),
			"kind": String(spec.kind), "role": String(spec.get("role", ""))}


func _is_aim_state(gs: String) -> bool:
	return gs == "aim-idle" or gs == "aim-run-forward" or gs == "aim-run-backward"


func _aim_run_for_dir() -> String:
	return "aim-run-forward" if absf(move_dir_deg) <= float(data.threshold("hemi_enter_deg", 90.0)) else "aim-run-backward"


func _uta() -> bool:
	return bool(data.option("use_transition_anims", true))


func _move_speed() -> float:
	return _inp.speed if moving else 0.0


func _default_weapon() -> StringName:
	if W != null and idx.weapons.has(String(W.target())):
		return StringName(W.target())
	return StringName(idx.weapons[0]) if not idx.weapons.is_empty() else &""


func _mode_split() -> float:
	var w := String(weapon)
	var vw := data.clip_speed(data.role_clip(w, "walk", "fw"))
	var vr := data.clip_speed(data.role_clip(w, "run", "fw"))
	if vw > 0.0 and vr > 0.0:
		return sqrt(vw * vr)
	var ms: Dictionary = data.graph.get("modes", {})
	var a := float(ms.get("walk", {}).get("mode_speed", 0.0))
	var b := float(ms.get("run", {}).get("mode_speed", 0.0))
	return sqrt(a * b) if a > 0.0 and b > 0.0 else 2.055


func _skeleton() -> Skeleton3D:
	if tree == null or not tree.is_inside_tree():
		return null
	var rn := tree.get_node_or_null(tree.root_node)
	if rn == null:
		return null
	var sks := rn.find_children("*", "Skeleton3D", true, false)
	return sks[0] if not sks.is_empty() else null


static func _deg(v: Vector2) -> float:
	return rad_to_deg(atan2(-v.x, v.y))


static func _lerp_scale(in_min: float, in_max: float, out_min: float, out_max: float, x: float) -> float:
	var u := clampf((x - in_min) / (in_max - in_min), 0.0, 1.0)
	return out_min + (out_max - out_min) * u


func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(msg)
