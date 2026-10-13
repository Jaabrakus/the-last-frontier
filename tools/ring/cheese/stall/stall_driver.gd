extends "res://tools/ring/highlight_input.gd"
## Stall-lens player models (cheese hunt, 2026-10-10). Ordinary key and mouse inputs only, through the player's own
## PlayerControls (set_held) and the number keys as input events, exactly as tools/ring/newcomer_sim.gd and
## highlight_input.gd drive him. Nothing of the game's state is written: no damage, no launches, no results.
##   expert   highlight_input's expert (the BASELINE: normal good play)
##   idle     stands still; only recovers when thrown (how fast a bot kills a target that does nothing)
##   hang     ledge camping: steps off the nearest lip and lets the edge grab catch him, hangs ~hang_hold_s, drops with C
##            and double-jumps back into the grab, three grabs, then climbs and steps off again (the 3-grab rule obeyed)
##   run      kites: sprints to the deck point farthest from the foe (2.5 m inside the lips), taps E at what flies at him
##   turtle   faces the foe holding E (the shield) as long as the game lets him, then presses it again
## after_lead=<model>: plays the expert until his side has more lives than the other, then switches to <model>.

var stall := "expert"
var after_lead := ""
var switched_at := -1.0
var hang_hold_s := 3.85
## Counters for the probe.
var drops := 0
var climbs := 0
var regrab_jumps := 0
var _drop_t := -1.0
var _djumped := false
var _run_goal := Vector3.INF
var _run_t := 0.0
var _turtle_t := 0.0


func set_stall(m: String, after := "") -> void:
	stall = m
	after_lead = after


func _lives(b: Node) -> int:
	return mode.rules.stocks_of(b) if mode != null and mode.rules != null else 0


func _physics_process(dt: float) -> void:
	if after_lead != "" and switched_at < 0.0 and mode != null and mode.phase == "FIGHT" and mode.foe != null \
			and is_instance_valid(mode.foe) and _lives(player) > _lives(mode.foe):
		switched_at = _t
		stall = after_lead
		_let_go()
		print("STALL SWITCH to %s at t=%.1f lives %d-%d" % [after_lead, _t, _lives(player), _lives(mode.foe)])
	if stall == "expert":
		super._physics_process(dt)
		return
	_t += dt
	if player == null or not is_instance_valid(player) or mode == null or not is_instance_valid(mode):
		return
	_hook()
	_untap()
	if mode.phase != "FIGHT":
		_let_go()
		_launch = {}
		return
	var rm := RingMoves.of(player)
	var foe := mode.foe
	if rm == null or foe == null or not is_instance_valid(foe) or (_rules != null and _rules.is_away(player)):
		_let_go()
		return
	_books(rm)
	match stall:
		"idle":
			_idle_tick(rm, foe, dt)
		"hang":
			_hang_tick(rm, foe, dt)
		"run":
			_run_tick(rm, foe, dt)
		"turtle":
			_turtle_tick(rm, foe, dt)
		"perch":
			_perch_tick(rm, foe, dt)
		"coping":
			_coping_tick(rm, foe, dt)
		_:
			_idle_tick(rm, foe, dt)


func _dirs_off() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint"]:
		_hold(a, false)


# ---------------------------------------------------------------- idle
func _idle_tick(rm: RingMoves, foe: Node3D, dt: float) -> void:
	if not _launch.is_empty() or rm.on_ledge() or (rm.off_deck() and rm.airborne()):
		_thrown(rm)
		return
	_dirs_off()
	_hold(&"jump", false)
	_mouse(foe, dt)


# ---------------------------------------------------------------- hang: ledge camping
func _hang_tick(rm: RingMoves, foe: Node3D, dt: float) -> void:
	_mouse(foe, dt)
	var stun := _rules != null and _rules.stunned(player)
	if stun:
		_dirs_off()
		_hold(&"jump", false)
		_hold(&"crouch", false)
		_drop_t = -1.0
		return
	if rm.on_ledge():
		_hold(&"jump", false)
		_hold(&"crouch", false)
		_drop_t = -1.0
		if rm.mode != "hang":
			_dirs_off()
			return
		var grabs := int(rm.get(&"_grabs"))
		if rm.mode_t < hang_hold_s:
			_dirs_off()
			return
		if grabs < int(RingMoves.num("edge", "grab_limit", 3.0)):
			_dirs_off()
			_tap(&"crouch", 0.05)                 # (C: let go)
			_drop_t = _t
			_djumped = false
			drops += 1
		else:
			var n: Vector3 = rm._m.get("normal", Vector3.ZERO)
			_hold_world(-n)                       # (any direction key climbs; toward the deck)
			climbs += 1
		return
	if rm.airborne() and rm.off_deck():
		if _drop_t > 0.0 and _t - _drop_t < 1.2:
			_dirs_off()
			_hold(&"crouch", false)
			if not _djumped and _t - _drop_t > 0.08 and rm.jumps_left > 0:
				_tap(&"jump", 0.05)               # (the double jump back up into the grab box)
				_djumped = true
				regrab_jumps += 1
			return
		if not _launch.is_empty():
			_thrown(rm)                           # (launched: the expert's own recovery)
			return
		_to_grab(rm)
		return
	if rm.airborne():
		if not _launch.is_empty():
			_thrown(rm)
			return
		_to_grab(rm)
		return
	# on the deck (or on the plinth's step under the lip): to the lip, then a hop out over it into the grab
	_drop_t = -1.0
	var lip := rm.lip_near(player.global_position)
	if lip.is_empty():
		return
	_hold(&"sprint", false)
	if float(lip.out_m) > -0.25 and _t - _hop_t > 0.6:
		_hop_t = _t
		_hold(&"jump", false)
		_tap(&"jump", 0.05)
		_hold_world(Vector3(lip.normal))
		hops += 1
		return
	_hold(&"jump", false)
	_hold_world(Vector3(lip.normal))


var _hop_t := -INF
var hops := 0


## Off the deck, not launched (a hop out, a missed regrab): drift to the grab box just outside the lip; the double jump
## and the Rise when below it.
func _to_grab(rm: RingMoves) -> void:
	var lip := rm.lip_near(player.global_position)
	if lip.is_empty():
		_dirs_off()
		return
	var out := float(lip.out_m)
	var below := float(Vector3(lip.point).y) - player.global_position.y
	var n: Vector3 = lip.normal
	var hop_age := _t - _hop_t
	if hop_age < 0.12:
		_hold_world(n)                            # (the hop's first moment: out over the lip)
		return
	if out > 0.75:
		_hold_world(-n)
	elif out < 0.15:
		_hold_world(n)
	else:
		_dirs_off()
	var vy := player.velocity.y
	if vy < 0.0 and below > 1.0 and rm.jumps_left > 0:
		_hold(&"jump", false)
		_tap(&"jump", 0.05)
		_dj_at = _t
	elif vy < 0.0 and below > 1.6 and rm.jumps_left <= 0 and rm.rise_ready and not rm.helpless() and _t - _dj_at > 0.25:
		_hold(&"jump", false)
		_tap(&"jump", 0.05)
		_dj_at = _t


# ---------------------------------------------------------------- run: kiting without attacking
func _run_tick(rm: RingMoves, foe: Node3D, dt: float) -> void:
	if not _launch.is_empty() or rm.on_ledge() or (rm.off_deck() and rm.airborne()):
		_thrown(rm)
		return
	_hold(&"jump", false)
	_mouse(foe, dt)
	var g := RingMoves.arena_geo(mode.ring)
	var xf: Transform3D = g.xf
	var inv := xf.affine_inverse()
	var lf: Vector3 = inv * foe.global_position
	var lm: Vector3 = inv * player.global_position
	var hl := float(g.hl) - 2.5
	var hw := float(g.hw) - 2.5
	_run_t -= dt
	if _run_t <= 0.0 or _run_goal == Vector3.INF:
		_run_t = 0.5
		var best := Vector3.INF
		var best_s := -INF
		for gx: float in [-hl, -hl * 0.5, 0.0, hl * 0.5, hl]:
			for gz: float in [-hw, 0.0, hw]:
				var c := Vector3(gx, 0.0, gz)
				var dfo := Vector2(c.x - lf.x, c.z - lf.z).length()
				# (far from him, and a way there that does not pass him)
				var to_c := Vector2(c.x - lm.x, c.z - lm.z)
				var to_f := Vector2(lf.x - lm.x, lf.z - lm.z)
				var toward := 0.0
				if to_c.length() > 0.1 and to_f.length() > 0.1:
					toward = maxf(to_c.normalized().dot(to_f.normalized()), 0.0) * clampf(4.0 / to_f.length(), 0.0, 2.0)
				var s := dfo - 6.0 * toward
				if s > best_s:
					best_s = s
					best = c
		_run_goal = best
	var d := Vector3(_run_goal.x - lm.x, 0.0, _run_goal.z - lm.z)
	if d.length() < 0.6:
		_dirs_off()
	else:
		_hold_world((xf.basis * d).normalized())
		_hold(&"sprint", true)
	_guard(foe)


# ---------------------------------------------------------------- turtle: the shield held
func _turtle_tick(rm: RingMoves, foe: Node3D, dt: float) -> void:
	if not _launch.is_empty() or rm.on_ledge() or (rm.off_deck() and rm.airborne()):
		_hold(InputSetup.GUARD_ACTION, false)
		_thrown(rm)
		return
	_dirs_off()
	_hold(&"jump", false)
	_mouse(foe, dt)
	_turtle_t += dt
	var hold := float(BendR3.block("guard").get("hold_max_s", 2.5))
	if _turtle_t < hold:
		player.controls.set_held(InputSetup.GUARD_ACTION, true)
	elif _turtle_t < hold + 0.08:
		player.controls.set_held(InputSetup.GUARD_ACTION, false)
	else:
		_turtle_t = 0.0


# ---------------------------------------------------------------- perch: up his side's Ruins perch and stays there
var perch_s := 0.0


## The opponent nearest him (team formats: any bot of the other side still in play).
func _nearest_foe(fallback: Node3D) -> Node3D:
	var best: Node3D = fallback
	var bd := INF
	if _rules == null:
		return fallback
	var mine := _rules.team_of(player)
	for b: Variant in _rules.sides[1 - mine] if mine >= 0 else []:
		if b is Node3D and is_instance_valid(b) and not _rules.is_away(b as Node):
			var d := (b as Node3D).global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = b as Node3D
	return best


func _my_perch() -> Dictionary:
	var ring := mode.ring
	var e := _rules.end_of(player) if _rules != null else 0
	var want := -1.0 if e == 0 else 1.0
	for pc: Dictionary in ring.pieces():
		if String(pc.kind) == "perch" and signf((pc.rect as Rect2).get_center().x) == want:
			return pc
	return {}


func _perch_tick(rm: RingMoves, foe: Node3D, dt: float) -> void:
	if not _launch.is_empty() or rm.on_ledge() or (rm.off_deck() and rm.airborne()):
		_thrown(rm)
		return
	var near := _nearest_foe(foe)
	_mouse(near, dt)
	_hold(&"jump", false)
	var ring := mode.ring
	var pc := _my_perch()
	if pc.is_empty():
		_dirs_off()
		return
	var l := ring.to_local(player.global_position)
	var r: Rect2 = pc.rect
	var on := r.has_point(Vector2(l.x, l.z)) and l.y > float(pc.h) - 0.5
	if on:
		perch_s += dt
		var c := r.get_center()
		var d := Vector3(c.x - l.x, 0.0, c.y - l.z)
		if d.length() > 0.6:
			_hold_world((ring.global_basis * d).normalized())
		else:
			_dirs_off()
		_guard(near)
		return
	var rp: Dictionary = pc.get("ramp", {})
	if rp.is_empty():
		_dirs_off()
		return
	var rr: Rect2 = rp.rect
	var up := String(rp.get("up", "+x"))
	var cz := rr.get_center().y
	var foot := Vector3(rr.position.x - 0.8 if up == "+x" else rr.end.x + 0.8, 0.0, cz)
	var head := Vector3(r.get_center().x, 0.0, r.get_center().y)
	var on_ramp := rr.grow(0.2).has_point(Vector2(l.x, l.z))
	var goal := head if on_ramp else foot
	if not on_ramp and Vector2(l.x - foot.x, l.z - foot.z).length() < 0.7:
		goal = head
	var d2 := Vector3(goal.x - l.x, 0.0, goal.z - l.z)
	_hold_world((ring.global_basis * d2).normalized())
	_hold(&"sprint", true)
	_guard(near)


# ---------------------------------------------------------------- coping: stands on the lip's stone coping, just past the deck
var coping_s := 0.0


func _coping_tick(rm: RingMoves, foe: Node3D, dt: float) -> void:
	_mouse(foe, dt)
	_hold(&"jump", false)
	if rm.on_ledge():
		if rm.mode == "hang" and rm.mode_t > 0.2:
			var n: Vector3 = rm._m.get("normal", Vector3.ZERO)
			_hold_world(-n)                       # (back up: any direction key climbs)
		else:
			_dirs_off()
		return
	if not _launch.is_empty() or (rm.off_deck() and rm.airborne()):
		_thrown(rm)
		return
	if rm.airborne():
		_dirs_off()
		return
	var lip := rm.lip_near(player.global_position)
	if lip.is_empty():
		_dirs_off()
		return
	if rm.off_deck():
		coping_s += dt                            # (standing on the coping: feet past the deck's edge, on its stone)
		_dirs_off()
		return
	_hold(&"sprint", false)
	_hold_world(Vector3(lip.normal))             # (to the lip: the teeter, then one step out onto the coping)
