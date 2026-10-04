class_name OverUnderMusket
extends Musket
## Over-under turnover gun (German "Wender", English "swivel-breech" or "turnover" gun).
##
## Two smoothbore barrels, one above the other, turn together by hand on a pin in front of the
## lock. One lock fires whichever barrel is on top; each barrel has its own pan, frizzen and
## frizzen spring. After the first shot: half cock, press the catch at the front of the trigger
## guard, turn the barrels half a turn until they latch, full cock, fire. Design:
## source/graph_analysis/weapons/weapons_balance_design.md section 2 (numbers
## 2.2, state machine 2.4, HUD 2.5, animation 2.6); history in over_under_research.md.
##
## Honest rules it keeps:
##   * the lower barrel cannot fire until it is turned up: the turnover is an action (1.3 s, the
##     source shotgun pump clip at its own rate), not a fire-mode toggle
##   * each barrel loads from its own muzzle like a musket (powder, patch and ball, ramming,
##     rod back: 6.6 s) wherever it lies, and is primed (1.6 s) only on top, so one barrel
##     takes the musket's 8.2 s and both take 17.7 s; the gain is a fast second shot
##   * the barrel on top is always in the same place: same muzzle, pan and sight line
##   * a turnover cut after its commit (sprint, jump, weapon switch: the barrels finish their half
##     turn and latch) leaves the cock at half cock: the rest of the turnover (full cock, back on
##     the shoulder) is still owed, and LMB plays it before the gun can fire. Without this a
##     sprint tap during the turnover gave the second shot at 0.98 s instead of 1.77 s, without
##     the turnover bloom and from half cock (review, weapons_balance_design.md 2.4)
##
## Controls are the musket's (hold LMB to shoulder, release to fire, RMB steadies, RMB or R
## while holding LMB lowers). New: LMB when the top barrel is spent and the bottom one loaded =
## turn over (a release during it fires as soon as it latches and comes back up). R runs the
## reload chain: the top barrel first, then the bottom one in place, then turn and prime it.
##
## The turnover is a sub-state held in `turning`, not a Firearm.State: GDScript cannot extend a
## parent's enum, and outside readers (WeaponAudio, PlayerAnim, the HUD) only see Firearm
## states and the usual signals: action_started("turnover", 1.3) / action_cancelled, the
## per-barrel reload steps as action_started("reload_begin" | "reload_mid" | "reload_end", s),
## fired, sfx (&"half_cock", &"catch", &"latch", &"full_cock" besides &"lock" and &"dry"), and
## barrels_turned(top) at the latch. Clips, carry layers and aim offsets are the musket's
## (inherited); the graph plays the musket's rows through the "over_under" -> "musket" alias.

## The barrels latched after a half turn; `top` is the physical barrel now under the lock.
signal barrels_turned(top: int)

const KEY := "over_under"
const TIME_EPS := 1e-6                 ## Timers end within this of zero (float sums of 1/120 s ticks).
enum Why { SHOT, CHAIN, EMERGENCY }   ## Why a turnover started.

@export_group("Over-under")
@export var turnover_bloom_deg := 1.5  ## Added when a turnover ends: the cheek and sight picture found again.
@export var hold_spread_deg := 0.3     ## Hold fatigue at full: extra cone.
@export var hold_sway_deg := 0.35      ## Hold fatigue at full: slow muzzle wander (tremble_offset).
@export var hold_fatigue_start := 2.5  ## Seconds shouldered before the weight tells.
@export var hold_fatigue_full := 7.0

## Mechanism (ballistics.json weapons.over_under.mechanism; these defaults equal it).
var mechanism := {
	"turnover_s": 1.3,
	"turnover_clip": {"stand": "actor_b-p-shotgun-idle-aim-reload-pump--part",
			"crouch": "actor_b-p-shotgun-idle-crouch-aim-reload-pump--part"},
	"turnover_fade_in_s": 0.35,
	"commit_s": {"stand": 0.067, "crouch": 0.033},
	"turn_window_s": {"stand": [0.067, 0.467], "crouch": [0.033, 0.433]},
	"catch_s": {"stand": [0.05, 0.10], "crouch": [0.016, 0.066]},
	"full_cock_s": 1.0,
	"finish_after_commit_max_s": 0.2,
	"loading": "charge_in_place_prime_on_top",
	"load_taken_at_step": 0,
	"ammo_kind": "load_62",
	"start_reserve": 10,
}
## Per-barrel cue list for WeaponAudio (hook H9 reads reload_cues[_stage]); the format of
## WeaponAudio.RELOAD, ids from the existing sound manifest.
var reload_cues := [
	[1.3, [["musket_handle", 0.10], ["powder_pour_barrel", 0.45]]],                                          # Charging powder
	[1.8, [["ball_seat", 0.90]]],                                                                           # Patch and ball
	[2.2, [["ramrod_draw", 0.08], ["ram_stroke", 0.80], ["ram_stroke", 1.25], ["ram_stroke", 1.70, 2.0, 0.97]]],  # Ramming
	[1.3, [["ramrod_return", 0.05], ["musket_handle", 0.78]]],                                               # Returning rod
	[1.6, [["cock_half", 0.05], ["powder_pour_pan", 0.30], ["frizzen_close", 1.00], ["cock_full", 1.35]]],    # Priming
]

var barrels := OverUnderBarrels.new()
var rig := OverUnderRig.new()
## Physical barrel that fired last (-1 before the first shot).
var last_fired_barrel := -1

# Turnover sub-state (read by OverUnderRig and the tests).
var turning := false
var turn_clock := 0.0          ## Clip time since action_started("turnover").
var turn_progress := 0.0       ## 0..1 of the half turn (1 = latched).
var turn_from_top := 0
var turn_why := Why.SHOT
var turn_crouched := false
var _turn_committed := false
var _turn_latched := false
var _turn_full_cocked := false
var _turn_finishing := false
var _finish_rate := 0.0
var _fire_intent := false      ## LMB pressed for this turnover (or in the recoil): shoulder after it.
var _turn_queued := false      ## LMB in the recoil with the bottom loaded: turn when it ends.
## A turnover was cut after it latched but before full cock: the cock is at half cock and the rest
## of the turnover (from `_owed_clock` to turnover_s()) must be played before the gun can fire.
## LMB plays it (_resume_turn); a new turnover or a Priming step (it cocks) clears it.
var half_cocked := false
var _owed_clock := 0.0

# Reload chain (R). work_* describe the barrel step being worked (read by the rig and tests).
var chain := false
var work_barrel := -1
var work_step := -1
var work_elapsed := 0.0
var _work_total := 0.0
var _work_done := 0.0

var _hold_t := 0.0
var _sway_t := 0.0


func _init() -> void:
	super()
	display_name = "Over-Under Turnover Gun"
	hand = Hand.RIGHT
	# Numbers: ballistics.json weapons.over_under.set (design 2.2). WeaponBalance.apply()
	# writes the same values; tests assert that these defaults equal the file.
	equip_time = 0.9
	move_speed_mult = 0.88
	damage = 110.0
	muzzle_speed = 342.0
	ball_gravity = 9.8
	ball_drag = 0.551
	hang_fire = 0.1
	recoil_time = 0.35
	recoil_pitch_deg = 4.5
	smoke_scale = 1.2
	pan_distance = 0.9
	reserve = 10
	spread_base = 0.42
	spread_move = 4.0
	spread_air = 10.0
	spread_unaimed = 5.5
	crouch_mult = 0.9
	aim_mult = 0.95
	fire_bloom = 2.5
	aim_in_time = 0.45
	aim_out_time = 0.35
	aim_speed_mult = 0.45
	aim_move_mult = 0.9
	# Per-barrel steps, sporting order, the musket's clips at the musket's rates:
	# [anim key, seconds, HUD label, where].
	reload_stages = [
		["reload_begin", 1.3, "Charging powder", "any"],
		["reload_mid", 1.8, "Patch and ball", "any"],
		["reload_mid", 2.2, "Ramming", "any"],
		["reload_end", 1.3, "Returning rod", "any"],
		["reload_mid", 1.6, "Priming", "top"],
	]
	# The turnover clips (pinned graph rows musket/<stance>/turnover, hook H7). Kept here so the
	# weapon's clip table names every clip it asks for.
	clips["turnover"] = "actor_b-p-shotgun-idle-aim-reload-pump--part"
	clips["turnover_crouch"] = "actor_b-p-shotgun-idle-crouch-aim-reload-pump--part"


## Takes the model's moving nodes (OverUnderModel). The muzzle is the fixed top-slot marker.
func bind_model(m: Node3D) -> void:
	model = m
	muzzle = m.get_node_or_null("Muzzle") as Marker3D
	rig.bind(m)
	rig.update(self, 0.0, true)


## Applies a `mechanism` block (ballistics.json); unknown keys are kept, `steps` become
## reload_stages.
func apply_mechanism(m: Dictionary) -> void:
	for k in m:
		if k == "steps":
			var rows: Array = []
			for s: Array in m[k]:
				rows.append([String(s[0]), float(s[1]), String(s[2]), String(s[3]) if s.size() > 3 else "any"])
			if rows.size() == OverUnderBarrels.READY:
				reload_stages = rows
		else:
			mechanism[k] = m[k]


# --- Queries -------------------------------------------------------------------------------

func is_busy() -> bool:
	return state == State.RELOADING or turning


func wants_aim() -> bool:
	if turning:
		# The source plays the pump from its aim state: the aim layer stays up under it.
		return active and not player.is_sprinting and not is_equipping()
	return super()


func is_steady_aiming() -> bool:
	return not turning and super()


## [top barrel ready, bottom barrel ready].
func barrels_loaded() -> Array:
	return barrels.barrels_loaded()


func turnover_s() -> float:
	return float(mechanism.get("turnover_s", 1.3))


func hold_fatigue() -> float:
	return clampf((_hold_t - hold_fatigue_start) / maxf(hold_fatigue_full - hold_fatigue_start, 0.01), 0.0, 1.0)


## Slow muzzle wander of a heavy fore-end (radians: pitch, yaw), like Bow.tremble_offset but
## at a far lower frequency. Used by the camera through hook H10.
func tremble_offset() -> Vector2:
	var f := hold_fatigue()
	if f <= 0.0:
		return Vector2.ZERO
	var a := deg_to_rad(hold_sway_deg) * f
	return Vector2((0.6 * sin(3.8 * _sway_t) + 0.4 * sin(5.7 * _sway_t)) * a,
			(0.6 * sin(3.8 * _sway_t + 1.7) + 0.4 * sin(5.7 * _sway_t + 0.9)) * a)


func _extra_spread() -> float:
	return hold_spread_deg * hold_fatigue()


## The shot leaves from the physical top barrel's own muzzle (the same point as the fixed
## Muzzle marker once the barrels have latched).
func launch_origin() -> Vector3:
	var m := rig.muzzle_of(barrels.top)
	return m.global_position if m and m.is_inside_tree() else super()


# --- State machine -------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_sway_t += delta
	var enabled := _fire_input_steady()     # (as the Firearm's: the click that closed a card or a screen is no press)
	if turning:
		_tick_turn(delta, enabled)
	else:
		match state:
			State.READY:
				if half_cocked and enabled and Input.is_action_just_pressed("fire") and not is_equipping():
					if _can_start_action():
						_resume_turn()      # at half cock: finish the turnover first, then shoulder
				elif enabled and Input.is_action_just_pressed("reload") and not is_equipping() \
						and not player.is_sprinting and not Input.is_action_pressed("fire"):
					start_reload()
				else:
					super(delta)
			State.RECOIL:
				_tick_recoil(delta, enabled)
			State.EMPTY:
				_tick_empty(enabled)
			State.RELOADING:
				_tick_reload(delta, enabled)
			_:
				super(delta)      # AIMING, HANGFIRE: the Firearm's (the top barrel fires)
	_tick_hold(delta)
	_mirror()
	rig.update(self, delta)


func _tick_recoil(delta: float, enabled: bool) -> void:
	if enabled and Input.is_action_just_pressed("fire") and barrels.is_ready(barrels.bottom()):
		_turn_queued = true
		_fire_intent = true
	if enabled and Input.is_action_just_pressed("reload"):
		_reload_queued = true
	_timer -= delta
	if _timer <= TIME_EPS:
		state = State.EMPTY
		if _turn_queued:
			_turn_queued = false
			_reload_queued = false
			if _can_start_action():
				_start_turn(Why.SHOT)
			else:
				_fire_intent = false
		elif _reload_queued:
			_reload_queued = false
			start_reload()


func _tick_empty(enabled: bool) -> void:
	if not enabled or is_equipping():
		return
	var lmb := Input.is_action_just_pressed("fire")
	var r := Input.is_action_just_pressed("reload")
	if not (lmb or r):
		return
	if lmb and barrels.is_ready(barrels.bottom()):
		if _can_start_action():
			_fire_intent = true
			_start_turn(Why.SHOT)
		return
	var nothing := String(barrels.next_work(reserve).do) == "done"
	if not _begin_chain() and lmb and nothing:
		sfx.emit(&"dry", model.global_position if model else player.global_position)


func _tick_reload(delta: float, enabled: bool) -> void:
	if player.is_sprinting or not player.is_on_floor():
		_interrupt_reload()
		return
	if enabled and Input.is_action_just_pressed("fire") and not is_equipping():
		if work_barrel != barrels.top and barrels.is_ready(barrels.top):
			# Emergency shot: the top barrel is loaded. Drop the work below (steps kept), shoulder.
			_interrupt_reload()
			state = State.AIMING
			_release_queued = not fire_on_release
			return
		if work_barrel == barrels.top and barrels.is_ready(barrels.bottom()):
			# Emergency shot: the loaded barrel is underneath. Drop the work (steps kept), turn over.
			_interrupt_reload()
			_fire_intent = true
			_start_turn(Why.EMERGENCY)
			return
	work_elapsed += delta
	_stage_left -= delta
	if _stage_left <= TIME_EPS:
		# The overshoot of this tick carries into the next step, so a chain of steps ends on
		# the sum of their lengths (17.7 s for both barrels), not one tick later per step.
		var carry := minf(_stage_left, 0.0)
		if work_step == OverUnderBarrels.PRIME_STEP:
			half_cocked = false       # priming ends at full cock (the step's cock_full cue)
		barrels.finish_step(work_barrel)
		_work_done += float(reload_stages[work_step][1])
		_mirror()
		_next_in_chain()
		if state == State.RELOADING and not turning:
			_stage_left += carry
			work_elapsed -= carry


func _can_start_action() -> bool:
	return not player.is_sprinting and player.is_on_floor()


## R: the reload chain (a public Firearm method; RECOIL's queued R also lands here).
func start_reload() -> void:
	_begin_chain()


## Starts the reload chain. False when there is nothing to charge or prime.
func _begin_chain() -> bool:
	if turning or state == State.RELOADING or not _can_start_action():
		return false
	if String(barrels.next_work(reserve).do) == "done":
		return false
	chain = true
	_next_in_chain()
	return true


func _next_in_chain() -> void:
	var w := barrels.next_work(reserve)
	match String(w.do):
		"step":
			_begin_barrel_step(int(w.barrel))
		"turn":
			_start_turn(Why.CHAIN)
		_:
			_end_chain()


func _begin_barrel_step(i: int) -> void:
	if i != work_barrel:
		# A new run for this barrel in this position (progress() shows its remaining work).
		_work_total = barrels.work_seconds(i, reload_stages)
		_work_done = 0.0
	work_barrel = i
	work_step = barrels.stage[i]
	work_elapsed = 0.0
	if barrels.begin_step(i):
		reserve -= 1
	_stage = work_step
	state = State.RELOADING
	_begin_stage()


func _end_chain() -> void:
	chain = false
	work_barrel = -1
	work_step = -1
	state = State.READY if barrels.is_ready(barrels.top) else State.EMPTY


## Sprint, jump, weapon switch or an emergency shot: the chain ends, finished steps are kept.
func _interrupt_reload() -> void:
	chain = false
	work_barrel = -1
	work_step = -1
	state = State.READY if barrels.is_ready(barrels.top) else State.EMPTY
	action_cancelled.emit()


func _finish_reload() -> void:
	_mirror()        # Never reached (the chain replaces Firearm's single reload).


func _discharge() -> void:
	var b := barrels.top
	super()
	last_fired_barrel = barrels.fire()
	if last_fired_barrel < 0:
		last_fired_barrel = b
	_mirror()


# --- Turnover ------------------------------------------------------------------------------

func _stance() -> String:
	return "crouch" if turn_crouched else "stand"


func _mech2(key: String, fallback: Array) -> Array:
	return mechanism.get(key, {}).get(_stance(), fallback)


func _start_turn(why: int) -> void:
	turning = true
	turn_why = why
	turn_clock = 0.0
	turn_progress = 0.0
	turn_from_top = barrels.top
	turn_crouched = player.is_crouching
	_turn_committed = false
	_turn_latched = false
	_turn_full_cocked = false
	_turn_finishing = false
	half_cocked = false           # this turnover ends at full cock
	work_barrel = -1
	work_step = -1
	state = State.READY if barrels.is_ready(barrels.top) else State.EMPTY
	action_started.emit("turnover", turnover_s())
	sfx.emit(&"half_cock", _pan_point())


## LMB at half cock (a turnover cut after its latch): the rest of that turnover from where it was
## cut, the barrels already latched (full cock at full_cock_s, the turnover bloom at the end), then
## the gun is shouldered for the shot. The animation replays the turnover clip over the time owed.
func _resume_turn() -> void:
	turning = true
	turn_why = Why.SHOT
	turn_clock = _owed_clock
	turn_progress = 1.0
	turn_from_top = barrels.bottom()     # the rig poses (from + progress) half turns: at rest
	turn_crouched = player.is_crouching
	_turn_committed = true
	_turn_latched = true
	_turn_full_cocked = false
	_turn_finishing = false
	half_cocked = false
	_fire_intent = true
	work_barrel = -1
	work_step = -1
	state = State.READY if barrels.is_ready(barrels.top) else State.EMPTY
	action_started.emit("turnover", maxf(turnover_s() - turn_clock, 1.0 / float(Engine.physics_ticks_per_second)))


func _tick_turn(delta: float, enabled: bool) -> void:
	if not _turn_finishing and (player.is_sprinting or not player.is_on_floor()):
		if not _turn_committed:
			_cancel_turn()
			return
		_begin_finish()
	if enabled and not _turn_finishing:
		if Input.is_action_just_pressed("fire"):
			if turn_why == Why.CHAIN and not _turn_committed:
				# The chain was about to turn a ready barrel down: keep it up and shoulder.
				_cancel_turn()
				if barrels.is_ready(barrels.top):
					state = State.AIMING
					_release_queued = not fire_on_release
				return
			_fire_intent = true
		elif _fire_intent and Input.is_action_just_pressed("aim"):
			_fire_intent = false          # RMB: no shot after the turnover
			shot_cancelled.emit()
	turn_clock += delta
	var win := _mech2("turn_window_s", [0.067, 0.467])
	if _turn_finishing:
		turn_progress = minf(1.0, turn_progress + _finish_rate * delta)
	elif _turn_latched:
		turn_progress = 1.0           # latched (also a turnover resumed from half cock)
	else:
		turn_progress = smoothstep(float(win[0]), float(win[1]), turn_clock)
	if not _turn_committed and turn_clock >= float(mechanism.get("commit_s", {}).get(_stance(), 0.067)) - TIME_EPS:
		_turn_committed = true
		sfx.emit(&"catch", _pan_point())
	if not _turn_latched and turn_progress >= 1.0:
		_latch()
	if _turn_finishing:
		if _turn_latched:
			_end_turn(true)
		return
	if not _turn_full_cocked and turn_clock >= float(mechanism.get("full_cock_s", 1.0)) - TIME_EPS:
		_turn_full_cocked = true
		sfx.emit(&"full_cock", _pan_point())
	if turn_clock >= turnover_s() - TIME_EPS:
		_end_turn(false)


## After the commit a sprint, jump or switch cannot stop the barrels: they complete the half
## turn in at most finish_after_commit_max_s and latch; the action is cut.
func _begin_finish() -> void:
	_turn_finishing = true
	var win := _mech2("turn_window_s", [0.067, 0.467])
	var natural := float(win[1]) - turn_clock
	var limit := float(mechanism.get("finish_after_commit_max_s", 0.2))
	var t := clampf(natural, 1.0 / float(Engine.physics_ticks_per_second), limit)
	_finish_rate = (1.0 - turn_progress) / t


func _latch() -> void:
	_turn_latched = true
	turn_progress = 1.0
	barrels.flip()
	_mirror()
	state = State.READY if barrels.is_ready(barrels.top) else State.EMPTY
	sfx.emit(&"latch", _pan_point())
	barrels_turned.emit(barrels.top)


## Before the commit: the catch is not yet released, nothing has moved.
func _cancel_turn() -> void:
	turning = false
	turn_progress = 0.0
	_fire_intent = false
	chain = false
	state = State.READY if barrels.is_ready(barrels.top) else State.EMPTY
	action_cancelled.emit()


func _end_turn(cut: bool) -> void:
	turning = false
	turn_progress = 0.0
	var why := turn_why
	if cut:
		if _turn_latched and not _turn_full_cocked:
			half_cocked = true            # latched at half cock: the rest of the turnover is owed
			_owed_clock = turn_clock
		_fire_intent = false
		chain = false
		state = State.READY if barrels.is_ready(barrels.top) else State.EMPTY
		action_cancelled.emit()
		return
	_bloom += turnover_bloom_deg
	if _fire_intent and barrels.is_ready(barrels.top):
		# LMB was pressed for this turnover: shoulder; a release already made fires at once.
		_fire_intent = false
		chain = false
		state = State.AIMING
		_release_queued = false
		return
	_fire_intent = false
	state = State.READY if barrels.is_ready(barrels.top) else State.EMPTY
	if why == Why.CHAIN and chain:
		_next_in_chain()


func _on_equip() -> void:
	super()
	# PlayerAnim / WeaponAudio hear this gun under keys they have rows and sounds for, whichever
	# of the kit and hooks H4 / H6 / H9 came first (OverUnderKit.ensure_routing).
	OverUnderKit.ensure_routing(player, self)
	# Dev bridge until hook H6: PlayerAnim does not know "over_under", so ask it for the musket's
	# rows before the draw plays (switch_weapon queued "over_under" just before, which it skips).
	if OverUnderKit.anim_needs_alias(player):
		player.anim.set_weapon(OverUnderKit.graph_key(player))
	rig.update(self, 0.0, true)


func _on_unequip() -> void:
	if turning:
		if _turn_committed:
			if not _turn_latched:
				_latch()
			_end_turn(true)
		else:
			_cancel_turn()
	_turn_queued = false
	_fire_intent = false
	super()
	chain = false
	_mirror()
	rig.update(self, 0.0, true)


func _tick_hold(delta: float) -> void:
	var shouldered := (state == State.AIMING and aim >= ready_aim) or is_steady_aiming()
	if shouldered and not turning:
		_hold_t += delta
	elif aim < 0.5:
		_hold_t = maxf(_hold_t - 2.0 * delta, 0.0)


## Firearm.loaded always equals "the top barrel is ready".
func _mirror() -> void:
	loaded = barrels.is_ready(barrels.top)


func _pan_point() -> Vector3:
	var pan := model.get_node_or_null("Pan") as Node3D if model else null
	if pan and pan.is_inside_tree():
		return pan.global_position
	return player.global_position if player else Vector3.ZERO


# --- HUD -----------------------------------------------------------------------------------

func status_text() -> String:
	if turning:
		return "Turning barrels"
	var top_ready := barrels.is_ready(barrels.top)
	var bot_ready := barrels.is_ready(barrels.bottom())
	match state:
		State.AIMING:
			return super()
		State.HANGFIRE, State.RECOIL:
			return "Fired"
		State.RELOADING:
			if work_step >= 0:
				return "%s barrel: %s" % ["Top" if work_barrel == barrels.top else "Bottom",
						String(reload_stages[work_step][2])]
	if top_ready and half_cocked:
		return "Half cock - LMB: finish the turn and fire"
	if top_ready and bot_ready:
		return "Both barrels loaded"
	if top_ready:
		return "Top barrel loaded - R: load the bottom" if barrels.can_work(barrels.bottom(), reserve) \
				else "Top barrel loaded"
	if barrels.is_charged(barrels.top):
		return "Top barrel not primed - LMB: turn, R: prime" if bot_ready else "Top barrel not primed - R: prime"
	if bot_ready:
		return "Top barrel fired - LMB: turn barrels, R: reload" if barrels.can_work(barrels.top, reserve) \
				else "Top barrel fired - LMB: turn barrels"
	return "Both barrels fired - press R" if String(barrels.next_work(reserve).do) != "done" else "Out of loads"


func ammo_text() -> String:
	return "%s  |  %d loads" % [barrels.glyphs(), reserve]


## [label, 0..1]: the turnover, or the barrel being worked (its remaining work in this position).
func progress() -> Array:
	if turning:
		return ["Turning", clampf(turn_clock / turnover_s(), 0.0, 1.0)]
	if state == State.RELOADING and work_step >= 0:
		var done := _work_done + float(reload_stages[work_step][1]) - _stage_left
		return ["Top barrel" if work_barrel == barrels.top else "Bottom barrel",
				clampf(done / maxf(_work_total, 0.01), 0.0, 1.0)]
	return []
