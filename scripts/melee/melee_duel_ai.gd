class_name MeleeDuelAI
extends Node
## A duellist's mind for a player driven by `controls` (FrontierPlayer.is_local false, controls not from the keyboard;
## user 2026-09-27: "can you use ai to check these", player against player without multiplayer): it plays the same
## melee as a person at the keys (AxeMelee through the player's controls: the move keys with LMB pick the cut, A+D the
## parry, RMB a feint), nothing more. It keeps facing its opponent; when the opponent begins an attack it answers,
## after a reaction time (REACT_S, give or take), with that attack's counter ("counters" in the melee data) as often as
## its `skill` says, else it misreads (another attack) or lets it come; left alone a while it attacks, now and then a
## feint first; tired (stamina), it waits; between its presses it walks in or backs off to keep in reach (keep_range).
## Runs before the players each physics frame (its presses are theirs that
## frame). The attacks it sees and makes, and how its answers went, are counted for tests.

const REACT_S := 0.2
const REACT_JITTER_S := 0.08
const HOLD_TICKS := 2
## The keys of each attack (the move keys held with LMB, as a player presses them).
const KEYS := {"D": [&"move_right"], "A": [&"move_left"], "W": [&"move_forward"], "S": [&"move_back"],
		"STAB": [&"move_back", &"move_right"], "AD": [&"move_left", &"move_right"]}

var me: FrontierPlayer
var opponent: FrontierPlayer
## 0..1: how often it reads an attack right and counters it.
var skill := 0.7
## s between its own attacks when nothing happens (a range).
var patience := Vector2(0.7, 1.6)
var feint_chance := 0.15
## The distance it keeps from its opponent (m), walking in or backing off between its presses.
var keep_range := Vector2(0.95, 1.25)
## (S is the high block, AD the parry: answers, not attacks)
var attack_mix := {"D": 3.0, "A": 3.0, "W": 1.5}
var enabled := true

var seen := 0              ## attacks of the opponent it saw begin
var countered := 0         ## answered with the counter
var misread := 0           ## answered with something else
var attacks := 0           ## its own attacks begun
var feints := 0

var _rng := RandomNumberGenerator.new()
var _plan := {}            ## {"at": frame, "dir": attack} its next press
var _release_at := -1
var _feint_at := -1
var _idle_s := 0.0
var _next_idle_s := 1.0
var _seen_swing: Dictionary = {}   ## the opponent's swing it last answered (the same dictionary: is_same)


static func attach(who: FrontierPlayer, against: FrontierPlayer, seed := 0) -> MeleeDuelAI:
	var ai := MeleeDuelAI.new()
	ai.name = "MeleeDuelAI"
	ai.me = who
	ai.opponent = against
	ai.process_physics_priority = -100
	if seed != 0:
		ai._rng.seed = seed
	who.add_child(ai)
	return ai


func _ready() -> void:
	_next_idle_s = _rng.randf_range(patience.x, patience.y)


func _physics_process(delta: float) -> void:
	if not enabled or me == null or opponent == null or me.controls.from_input or me.is_dead:
		return
	var frame := Engine.get_physics_frames()
	var c := me.controls
	# (the last press let go after a couple of frames, as a finger does)
	if _release_at >= 0 and frame >= _release_at:
		c.release_all()
		_release_at = -1
	if _feint_at >= 0 and frame >= _feint_at:
		c.set_held(&"aim", true)
		_release_at = frame + HOLD_TICKS
		_feint_at = -1
		feints += 1
	_face()
	_footwork()
	# the opponent begins an attack: answer it, a reaction later
	var os: Dictionary = opponent.gather._swing if opponent.gather else {}
	if bool(os.get("melee", false)) and not bool(os.get("cancel", false)) and not is_same(os, _seen_swing):
		_seen_swing = os
		seen += 1
		var dir := String(os.get("dir", ""))
		if dir != "AD":
			var answer := ""
			if _rng.randf() < skill:
				answer = _counter_of(dir)
				countered += 1
			elif _rng.randf() < 0.5:
				answer = _pick_attack()
				misread += 1
			if answer != "":
				_plan = {"at": frame + int(round((REACT_S + _rng.randf_range(-REACT_JITTER_S, REACT_JITTER_S)) * Engine.physics_ticks_per_second)),
						"dir": answer}
	# left alone a while: attack (now and then a feint first)
	var busy := not me.gather._swing.is_empty() or me.gather.melee == null or me.gather.melee.flinching()
	_idle_s = 0.0 if busy or not _plan.is_empty() else _idle_s + delta
	if _idle_s >= _next_idle_s and me.grip and me.grip.stamina >= 30.0:
		_idle_s = 0.0
		_next_idle_s = _rng.randf_range(patience.x, patience.y)
		_plan = {"at": frame, "dir": _pick_attack(), "feint": _rng.randf() < feint_chance}
	if not _plan.is_empty() and frame >= int(_plan.at) and _release_at < 0:
		_press(String(_plan.dir))
		if bool(_plan.get("feint", false)):
			_feint_at = frame + int(0.15 * Engine.physics_ticks_per_second)
		_plan = {}


## Presses an attack's keys with LMB (let go HOLD_TICKS later).
func _press(dir: String) -> void:
	var c := me.controls
	c.release_all()
	for k: StringName in KEYS.get(dir, []):
		c.set_held(k, true)
	c.set_held(&"fire", true)
	_release_at = Engine.get_physics_frames() + HOLD_TICKS
	attacks += 1


## Between presses: walk in when further than keep_range, back off when nearer, else stand.
func _footwork() -> void:
	if _release_at >= 0:
		return
	var d := opponent.global_position - me.global_position
	d.y = 0.0
	var dist := d.length()
	var fwd := dist > keep_range.y
	var back := dist < keep_range.x
	var c := me.controls
	c.set_held(&"walk", fwd or back)
	c.set_held(&"move_forward", fwd)
	c.set_held(&"move_back", back)


func _face() -> void:
	var d := opponent.global_position - me.global_position
	d.y = 0.0
	if d.length_squared() > 1e-4:
		me.yaw = atan2(-d.x, -d.z)


func _counter_of(dir: String) -> String:
	var counters: Dictionary = me.gather.melee.data.get("counters", {}) if me.gather.melee else {}
	return String(counters.get(dir, ""))


func _pick_attack() -> String:
	var total := 0.0
	for k: String in attack_mix:
		total += float(attack_mix[k])
	var r := _rng.randf() * total
	for k: String in attack_mix:
		r -= float(attack_mix[k])
		if r <= 0.0:
			return k
	return "D"

