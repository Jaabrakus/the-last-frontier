extends Node
## THE FIRST FIVE MINUTES' PLAYERS (Tidebreak round 4, SIMPLE): scripted human input models that play the % ring through the
## player's own keys (his PlayerControls driven by set_held, the number keys as key events through the game's own input,
## the mouse as his camera's yaw and pitch: nothing else of the game is touched), for tests/ring/test_first_five.gd:
##   newcomer   walks at the foe (W, the mouse turned toward him slowly and loosely); in jab range jabs (LMB) every
##              click_s; far off taps 1 and casts (right-click); when something flies at him taps E
##              late and imperfectly (reaction react_s, 0.35-0.6 s, a share of them missed: miss_share); thrown (or off the
##              deck however he got there), he HOLDS Space (and lets go of everything else) until he is back on the deck
##   expert     the same with quicker hands (react 0.15-0.3 s, the mouse quicker and steadier), Push (2) at mid range, and his
##              own recovery under Full: toward the lip, the double jump falling near the lip, the Rise falling under it
##              (the lead model's order), never his Space held
## A cast's button (LMB, right-click) is held until its lock is full and let go a human beat after (release_lag; the owner,
## 2026-10-10: casts are held, no click and forget: _cast_hold); E stays a tap (the timed guard).
## Its books (read by the runner): launches [{v, hitstun, survivable (RingPredict.flight: the model's recovery comes back),
## off (he went off the deck), result "back" | "out"}], falls [{unused (the double jump or the Rise left, free 0.3 s or more
## off the deck before it)}].
##   var sim := preload("res://tools/ring/newcomer_sim.gd").new(); sim.setup(player, mode, "newcomer", seed); add_child(sim)

const MODELS := {
	"newcomer": {"react": [0.35, 0.6], "miss_share": 0.25, "turn_rate": 3.0, "aim_err_deg": 4.0, "click_s": [0.25, 0.45],
			"jab_m": 3.2, "close_m": 2.0, "far_m": 7.0, "cast_every_s": [1.4, 2.4], "push": false, "hold_space": true,
			"release_lag": [0.08, 0.2]},
	"expert": {"react": [0.15, 0.3], "miss_share": 0.05, "turn_rate": 8.0, "aim_err_deg": 1.5, "click_s": [0.18, 0.28],
			"jab_m": 3.2, "close_m": 2.2, "far_m": 7.0, "cast_every_s": [0.9, 1.4], "push": true, "hold_space": false,
			"release_lag": [0.03, 0.08]},
}

var player: FrontierPlayer
var mode: RingMode
var model := "newcomer"
var m: Dictionary = {}
var rng := RandomNumberGenerator.new()
var launches: Array = []
var falls: Array = []
var guards := 0
var casts := 0
var clicks := 0

var _t := 0.0
var _taps := {}                 ## action -> release time
## A cast's button held until its lock is full: action -> {since, at_least (s held at least: a grow's hold), full_at, lag}.
var _cast_holds := {}
var _next_click := 0.0
var _next_cast := 0.0
var _seen := {}                 ## bolt id -> true
var _guard_at: Array = []       ## times to tap E
var _launch := {}               ## the launch under way ({} none)
var _free_off := 0.0
var _last_moves := {"jumps": 1, "rise": true}
var _rules: RingRules
var _aim_jitter := Vector2.ZERO
var _jit_t := 0.0
var _dj_at := -INF


func setup(p: FrontierPlayer, md: RingMode, model_name: String, sd: int) -> void:
	player = p
	mode = md
	model = model_name
	m = MODELS.get(model_name, MODELS.newcomer)
	rng.seed = sd


func _ready() -> void:
	process_physics_priority = -20          # (his hands before the game reads them: RingAssist -8, the player 0)


func _physics_process(dt: float) -> void:
	_t += dt
	if player == null or not is_instance_valid(player) or mode == null or not is_instance_valid(mode):
		return
	_hook()
	_untap()
	_cast_release()
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
	if not _launch.is_empty() or rm.on_ledge() or (rm.off_deck() and rm.airborne()):
		_thrown(rm)                              # (thrown, or off the deck however he got there: Space)
		return
	_hold(&"jump", false)
	_mouse(foe, dt)
	_feet(foe)
	_hands(foe)
	_guard(foe)


func _hook() -> void:
	var r := RingRules.current()
	if r != null and r != _rules:
		_rules = r
		r.launched.connect(_on_launched)
		r.ko.connect(_on_ko)


func _on_launched(b: Node3D, v: Vector3, hitstun_s: float, _by: Node, _tag: String) -> void:
	if b != player:
		return
	if not _launch.is_empty() and String(_launch.get("result", "")) == "":
		_launch.result = "again"            # (hit again in the air: the new launch is the one judged)
	var el := String(player.arena_element)
	var fl := RingPredict.flight(v, hitstun_s, player.global_position, el)
	_launch = {"v": v.length(), "hitstun": hitstun_s, "survivable": String(fl.get("lands", "")) != "water", "off": false,
			"result": "", "at": _t}
	launches.append(_launch)
	_free_off = 0.0
	_let_go()


func _on_ko(b: Node3D, _by: Node, _pct: float, _tag: String, _left: int) -> void:
	if b != player:
		return
	var unused := _free_off >= 0.3 and (int(_last_moves.jumps) > 0 or bool(_last_moves.rise))
	var a := RingAssist.of(player)
	falls.append({"unused": unused, "free_off_s": snappedf(_free_off, 0.01), "jumps": _last_moves.jumps, "rise": _last_moves.rise,
			"launch": {"v": snappedf(float(_launch.get("v", 0.0)), 0.1), "survivable": _launch.get("survivable", null),
			"off": _launch.get("off", null)} if not _launch.is_empty() else {}, "at": snappedf(_t, 0.1),
			"assist": a.stats.duplicate(true) if a != null else {}})
	if not _launch.is_empty() and String(_launch.get("result", "")) == "":
		_launch.result = "out"
	_launch = {}
	_free_off = 0.0
	_let_go()


## The launch's and the fall's books: off the deck, free time off it, back.
func _books(rm: RingMoves) -> void:
	var stun := _rules != null and _rules.stunned(player)
	if rm.airborne() and rm.off_deck():
		if not _launch.is_empty():
			_launch.off = true
		if not stun and rm.mode in ["", "rise"]:
			_free_off += 1.0 / Engine.physics_ticks_per_second
		_last_moves = {"jumps": rm.jumps_left, "rise": rm.rise_ready and not rm.helpless()}
	if not _launch.is_empty() and String(_launch.get("result", "")) == "":
		if rm.on_ledge() or (not stun and not rm.airborne() and player.is_on_floor() and not rm.off_deck()):
			_launch.result = "back"
			_launch = {}
			_free_off = 0.0
	elif _launch.is_empty() and rm.on_ledge():
		pass
	if not rm.airborne() and player.is_on_floor():
		_free_off = 0.0


# ---------------------------------------------------------------- thrown
func _thrown(rm: RingMoves) -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"fire", &"aim", InputSetup.GUARD_ACTION]:
		_hold(a, false)
	if bool(m.hold_space):
		_hold(&"jump", true)                  # (the newcomer: Space held the whole way back)
		return
	_hold(&"jump", false)
	if rm.on_ledge():
		if rm.mode_t > 0.25:
			_hold(&"move_forward", true)    # (the expert climbs at once)
		return
	# the expert's own recovery: toward the lip, the lead model's order
	var stun := _rules != null and _rules.stunned(player)
	if stun or not (rm.airborne() and rm.off_deck()):
		return
	var lip := rm.lip_near(player.global_position)
	if lip.is_empty():
		return
	var to: Vector3 = Vector3(lip.point) - Vector3(lip.normal) * 0.5 - player.global_position
	to.y = 0.0
	_hold_world(to.normalized())
	var kn := BendKnock.peek(player)
	var vy := kn.base_of(player.velocity).y if kn != null else player.velocity.y
	var ly := float(Vector3(lip.point).y)
	var y := player.global_position.y
	if rm.mode != "" or vy >= 0.0:
		return
	if rm.jumps_left > 0 and y < ly + 0.5:
		_tap(&"jump")
		_dj_at = _t
	elif rm.jumps_left <= 0 and rm.rise_ready and not rm.helpless() and y < ly - 0.5 and _t - _dj_at > 0.25:
		_tap(&"jump")


# ---------------------------------------------------------------- on the deck
## The mouse: his camera turned toward the foe's chest at turn_rate, loosely (a wandering error of aim_err_deg).
func _mouse(foe: Node3D, dt: float) -> void:
	_jit_t -= dt
	if _jit_t <= 0.0:
		_jit_t = rng.randf_range(0.4, 0.9)
		var e := deg_to_rad(float(m.aim_err_deg))
		_aim_jitter = Vector2(rng.randf_range(-e, e), rng.randf_range(-e, e) * 0.6)
	var to := foe.global_position + Vector3.UP * 1.1 - (player.global_position + Vector3.UP * 1.6)
	var want_yaw := atan2(-to.x, -to.z) + _aim_jitter.x
	var flat := Vector2(to.x, to.z).length()
	var want_pitch := atan2(to.y, maxf(flat, 0.1)) + _aim_jitter.y
	var k := 1.0 - exp(-float(m.turn_rate) * dt)
	player.yaw += wrapf(want_yaw - player.yaw, -PI, PI) * k
	player.pitch = lerpf(player.pitch, clampf(want_pitch, -1.2, 1.2), k)


func _feet(foe: Node3D) -> void:
	var d := _flat_d(foe)
	_hold(&"move_forward", d > float(m.close_m))
	for a: StringName in [&"move_back", &"move_left", &"move_right"]:
		_hold(a, false)


func _hands(foe: Node3D) -> void:
	var d := _flat_d(foe)
	if d <= float(m.jab_m):
		if _t >= _next_click:
			_next_click = _t + rng.randf_range(float(m.click_s[0]), float(m.click_s[1]))
			_cast_hold(&"fire")
			clicks += 1
		return
	if _t < _next_cast:
		return
	var push := bool(m.push) and d < float(m.far_m)
	if d >= float(m.far_m) or push:
		_next_cast = _t + rng.randf_range(float(m.cast_every_s[0]), float(m.cast_every_s[1]))
		_key(&"weapon_2" if push else &"weapon_1")
		_cast_hold(&"aim")
		casts += 1


## E when something flies at him: a newcomer late and not always (react, miss_share).
func _guard(_foe: Node3D) -> void:
	var c := player.global_position + Vector3.UP * 1.2
	for b in get_tree().get_nodes_in_group(BendBolt.GROUP):
		var bb := b as BendBolt
		if bb == null or bb.spent or bb.caster == player or _seen.has(bb.get_instance_id()):
			continue
		var rel := c - bb.global_position
		if bb.velocity.length() < 1.0 or rel.length() > 30.0 or rel.normalized().dot(bb.velocity.normalized()) < 0.9:
			continue
		_seen[bb.get_instance_id()] = true
		if rng.randf() < float(m.miss_share):
			continue
		_guard_at.append(_t + rng.randf_range(float(m.react[0]), float(m.react[1])))
	for i in range(_guard_at.size() - 1, -1, -1):
		if _t >= float(_guard_at[i]):
			_guard_at.remove_at(i)
			_tap(InputSetup.GUARD_ACTION, 0.1)
			guards += 1


# ---------------------------------------------------------------- his hands
func _flat_d(foe: Node3D) -> float:
	var d := foe.global_position - player.global_position
	return Vector2(d.x, d.z).length()


func _hold(a: StringName, on: bool) -> void:
	if player.controls.pressed(a) == on and not _taps.has(a):
		return
	if not on and _taps.has(a):
		return                                   # (a tap lets itself go)
	player.controls.set_held(a, on)


## The keys held for a world direction (his camera's yaw: W/A/S/D as he would press them).
func _hold_world(w: Vector3) -> void:
	var l := Basis(Vector3.UP, player.yaw).inverse() * w
	_hold(&"move_forward", l.z < -0.38)
	_hold(&"move_back", l.z > 0.38)
	_hold(&"move_left", l.x < -0.38)
	_hold(&"move_right", l.x > 0.38)


func _tap(a: StringName, s := 0.0) -> void:
	player.controls.set_held(a, true)
	_taps[a] = _t + maxf(s, 1.0 / Engine.physics_ticks_per_second)


## A cast's button pressed and kept down until the lock is full (then let go a human beat later: release_lag), or held at
## least `at_least` s (a grow: the Fireball's, a grown push's). Let go anyway when the lock ends without filling or after 3 s.
func _cast_hold(a: StringName, at_least := 0.0) -> void:
	player.controls.set_held(a, true)
	var lag: Array = m.get("release_lag", [0.05, 0.12])
	_cast_holds[a] = {"since": _t, "at_least": at_least, "full_at": -1.0, "lag": rng.randf_range(float(lag[0]), float(lag[1]))}


func _cast_release() -> void:
	var c := SwayCaster.of(player)
	for a: StringName in _cast_holds.keys():
		var h: Dictionary = _cast_holds[a]
		var go := _t - float(h.since) > 3.0 or c == null
		if not go:
			if c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING]:
				if float(h.full_at) < 0.0:
					h.full_at = _t
				go = _t >= float(h.full_at) + float(h.lag) and _t - float(h.since) >= float(h.at_least)
			elif c.state == SwayCaster.State.IDLE and _t - float(h.since) > 0.1:
				go = true                        # (the lock broke or the move went: nothing more to hold)
		if go:
			_cast_holds.erase(a)
			player.controls.set_held(a, false)


## A cast's button is being held for its lock.
func casting() -> bool:
	return not _cast_holds.is_empty()


func _untap() -> void:
	for a: StringName in _taps.keys():
		if _t >= float(_taps[a]):
			_taps.erase(a)
			player.controls.set_held(a, false)


## A number key pressed and let go (an event, as the hotbar reads them).
func _key(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)


func _let_go() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"fire", &"aim", &"jump",
			InputSetup.GUARD_ACTION]:
		player.controls.set_held(a, false)
	_taps.clear()
	_cast_holds.clear()
