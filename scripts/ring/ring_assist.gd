class_name RingAssist
extends Node
## THE BASIC CONTROLS' HELPERS (Tidebreak round 4, SIMPLE; the owner, 2026-10-05/06: "simple like runescape but hard to master
## like runescape", "make the skills easy hard to master ... think human made think avg IQ"): under the Basic controls
## (MatchSetup.controls() "basic", a new player's default) the game does the hard parts for him, the way RuneScape's one click
## does the thing and the game the rest. A Node child named NODE_NAME of this machine's player in a % ring (installed beside
## his RingMoves: RingMode's set-up), acting only while active(): Basic on, the player this machine's (is_local), alive, his
## RingMoves on. Never for a bot (a bot is no player), never under Full: then every key reaches the game exactly as it does
## without it. Every toggle and number in data/ring/assist.json.
## HOW: it drives the player's OWN keys, the way NpcPad drives a bot (round 3 MOVE's seam: RingMoves.pre reads the keys through
## FrontierPlayer.controls): the player's PlayerControls is wrapped (AssistControls) and the helpers press Space, hold a
## direction or hold a key back in it. It never edits RingMoves' or SwayCaster's code, and it never turns the camera, moves
## the aim or touches a lock (no yaw, pitch, camera or caster is written here).
##   recovery  off the deck, or thrown (in hitstun after a launch), with Space HELD (or pressed within mash_window_s: mashing
##             works too): his own Space presses are held back and the helper steers toward the nearest lip (the direction he
##             would hold) and presses Space for the double jump, then the Rise, when RingMoves.simulate (the bots' look-ahead
##             on the same mover) says it brings him back: the drift alone first (nothing spent), else the earliest press
##             that comes back (the Rise after it at its earliest), the plan kept while it still comes back; nothing comes
##             back: the lead model's late order. A press it makes in hitstun is the escape when that is open (the plan says)
##   steer     thrown (from a launch until he is back on the deck, on the edge, or out): a light steer toward the deck's
##             centre, frac of the full one, added to what he holds (the steer read at 0.1 s, then the air drift)
##   edge      hanging: Space or any direction climbs, and it climbs by itself climb_after_s after the grab unless E or C is
##             held; E, a click and C do nothing there (the edge's options are Full's)
##   blocks    Full-only keys held back: 3 in the air (the air dodge), the guard's roll (a fresh direction), C (crouch, duck,
##             fast fall), the short hop (Space within the hop's window of a cast's release is always the full jump); keys 4
##             and 5 (Wall, Heal) until his first win (won_once: GameSettings' match section, key first_win, set when he
##             wins a match; key_locked(p, n) for the strip)
##   the aim   the owner's Aim help setting (MatchSetup.aim_help, light by default) is left as it is
## Read by the tests and the newcomer sim: stats ({presses: {double_jump, rise, escape, climb}, plans, sims, desperate}),
## the signal assisted(kind).

## A press the helper made for him: "double_jump", "rise", "escape" (a press that ended his hitstun), "climb" (the edge).
signal assisted(kind: String)

const NODE_NAME := "RingAssist"
const DATA_PATH := "res://data/ring/assist.json"
## GameSettings' match section key: the player has won a match (keys 4 and 5 under Basic from then on).
const FIRST_WIN_KEY := "first_win"
const JUMP := &"jump"
const CROUCH := &"crouch"
const FIRE := &"fire"
const MOVES := [&"move_forward", &"move_back", &"move_left", &"move_right"]

static var _data := {}

var player: FrontierPlayer
## The wrapper on the player's controls (null until the first frame).
var controls: AssistControls
var stats := {"presses": {}, "plans": 0, "sims": 0, "desperate": 0}

var _t := 0.0
var _active := false
var _active_frame := -1
var _rm: RingMoves
var _kn: BendKnock
var _launched := false
var _stun_total := 0.0
var _space_at := -INF
var _dj_at := -INF
## This frame's helper output: the jump pressed for him (its physics frame), the move he is given (key space) and when, his
## own Space held back (capturing), the hang's climb asked.
var _press_frame := -1
var _press_kind := ""
var _move := Vector2.ZERO
var _move_frame := -1
var _capturing := false
var _climb_pending := false
var _hang_seen := false
## The recovery's plan: {events: [{t (this helper's clock), key}], desperate}; when it is looked at again.
var _plan := {}
var _replan_at := -INF
var _hooked_mode: Node


# ---------------------------------------------------------------- install, data
## A RingAssist on player `p` (one only). RingMode's set-up calls it for its player in a stock ring.
static func install(p: Node) -> RingAssist:
	var a := of(p)
	if a != null or not (p is FrontierPlayer) or not is_instance_valid(p):
		return a
	a = RingAssist.new()
	a.name = NODE_NAME
	a.player = p as FrontierPlayer
	p.add_child(a)
	return a


static func of(p: Node) -> RingAssist:
	if p == null or not is_instance_valid(p):
		return null
	return p.get_node_or_null(NODE_NAME) as RingAssist


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else {}
		_data = d if d is Dictionary else {}
	return _data


static func reload_data() -> void:
	_data = {}


static func block(key: String) -> Dictionary:
	var b: Variant = data().get(key, {})
	return b if b is Dictionary else {}


static func num(blk: String, key: String, def := 0.0) -> float:
	return float(block(blk).get(key, def))


static func on(blk: String) -> bool:
	return bool(block(blk).get("on", true))


static func blocks(key: String) -> bool:
	return bool(block("blocks").get(key, true))


## The player has won a match once (Basic's keys 4 and 5 from then on).
static func won_once() -> bool:
	var cf := ConfigFile.new()
	cf.load(GameSettings.file())
	return bool(cf.get_value(MatchSetup.SECTION, FIRST_WIN_KEY, false))


static func note_win() -> void:
	if not won_once():
		GameSettings.set_value(MatchSetup.SECTION, FIRST_WIN_KEY, true)


## The Basics lessons offered on the game's first launch, once: true the first time it is asked under Basic (kept at once in
## GameSettings' match section, key basics_offered; the main menu asks it as it opens), false ever after and under Full.
static func offer_basics() -> bool:
	if not MatchSetup.basic():
		return false
	var cf := ConfigFile.new()
	cf.load(GameSettings.file())
	if bool(cf.get_value(MatchSetup.SECTION, "basics_offered", false)):
		return false
	GameSettings.set_value(MatchSetup.SECTION, "basics_offered", true)
	return true


## Key `n` (1-5) held back from player `p` now: Basic's later keys (4 Wall, 5 Heal) before his first win (the strip hides them).
static func key_locked(p: Node, n: int) -> bool:
	var a := of(p)
	if a == null or not a.active():
		return false
	for k: Variant in (block("blocks").get("later_keys", [4, 5]) as Array):
		if int(k) == n:
			return not won_once()
	return false


# ---------------------------------------------------------------- the frame
func _ready() -> void:
	process_physics_priority = -8            # (after a sim's or the network's keys (-20, -10), before the player (0) reads his)


func _exit_tree() -> void:
	if player != null and is_instance_valid(player) and player.controls == controls and controls != null:
		player.controls = controls.inner


## The helpers act now: Basic, this machine's player, alive, his RingMoves on (THE GATE per body).
func active() -> bool:
	if Engine.get_physics_frames() == _active_frame:
		return _active
	return _compute_active()


func _compute_active() -> bool:
	return player != null and is_instance_valid(player) and player.is_local and not player.is_dead \
			and MatchSetup.basic() and RingMoves.of(player) != null


func _physics_process(dt: float) -> void:
	_t += dt
	_wrap()
	_hook_mode()
	_active = _compute_active()
	_active_frame = Engine.get_physics_frames()
	_capturing = false
	if not _active:
		_plan = {}
		_launched = false
		_climb_pending = false
		return
	_rm = RingMoves.of(player)
	_hook_knock()
	var inner := controls.inner
	if inner.just_pressed(JUMP):
		_space_at = _t
	_track_launch()
	if _rm.mode == "hang":
		_edge(inner)
		return
	_hang_seen = false
	_climb_pending = false
	_recovery(inner)
	if _move_frame != Engine.get_physics_frames() and _launched and on("steer") and _rm.mode in ["", "rise"]:
		var add := _centre_dir() * num("steer", "frac", 0.4)
		_give_move(_world_to_keys((_raw_world(inner) + add).limit_length(1.0)))
	if blocks("short_hop") and (inner.just_pressed(JUMP) or _press_frame == Engine.get_physics_frames()):
		# (the hop's window after a cast's release: under Basic Space is always the full jump; RingMoves reads it at the press)
		_rm.set(&"_cast_rel_at", -INF)


## The player's controls wrapped (again when something put a new one on him).
func _wrap() -> void:
	if player == null or not is_instance_valid(player):
		return
	if controls != null and player.controls == controls:
		controls.from_input = controls.inner.from_input
		return
	var base: PlayerControls = player.controls
	if base is AssistControls:
		base = (base as AssistControls).inner
	controls = AssistControls.new(base, self)
	player.controls = controls


func _hook_mode() -> void:
	var m: RingMode = RingMode.find(get_tree()) if is_inside_tree() else null
	if m != null and m != _hooked_mode:
		_hooked_mode = m
		m.match_over.connect(func(winner: int) -> void:
			if winner == 0 and not m.practice:
				note_win())


func _hook_knock() -> void:
	var kn := BendKnock.peek(player)
	if kn != null and kn != _kn:
		_kn = kn
		kn.launched.connect(_on_launched)
	if _rm != null and not _rm.moved.is_connected(_on_moved):
		_rm.moved.connect(_on_moved)


func _on_launched(_v: Vector3, hitstun_s: float, _refresh: bool) -> void:
	_launched = true
	_stun_total = hitstun_s
	_plan = {}
	_replan_at = -INF


func _on_moved(kind: String) -> void:
	match kind:
		"double_jump":
			_dj_at = _t
		"jump":
			if active() and blocks("short_hop"):
				# (the other order: a cast let go just after Space never caps it to the hop's height under Basic)
				_rm.set(&"_jump_short", true)
		"grab", "rise", "scramble":
			_plan = {}


## Thrown until back on the deck, on the edge, on the spout, or out.
func _track_launch() -> void:
	if not _launched:
		return
	var stun := _stunned()
	if _rm.on_ledge() or _rm.on_spout() or (not stun and not _rm.airborne() and player.is_on_floor()):
		_launched = false
		_plan = {}


func _stunned() -> bool:
	return _kn != null and _kn.stun_t > 0.0


# ---------------------------------------------------------------- the edge
func _edge(inner: PlayerControls) -> void:
	_launched = false
	_plan = {}
	if not on("edge"):
		return
	if not _hang_seen:
		_hang_seen = true
		_climb_pending = false
	if inner.just_pressed(JUMP):
		_climb_pending = true                # (Space climbs; the climb waits for the hang's settle)
	var kept := false
	for a: Variant in (block("edge").get("kept_by", []) as Array):
		kept = kept or inner.pressed(StringName(String(a)))
	if _climb_pending or (_rm.mode_t >= num("edge", "climb_after_s", 0.4) and not kept):
		_give_move(Vector2(0.0, -1.0))       # (any direction climbs: the climb is the deck's way; held until it starts)
		if not _climb_pending:
			_climb_pending = true
			stats.presses["climb"] = int((stats.presses as Dictionary).get("climb", 0)) + 1
			assisted.emit("climb")


# ---------------------------------------------------------------- the recovery
func _recovery(inner: PlayerControls) -> void:
	if not on("recovery"):
		return
	var stun := _stunned()
	# (over the water nobody stands: off the deck is enough, before RingMoves has marked the airtime this frame)
	var off := _rm.off_deck()
	if not ((stun and _launched) or off) or not _rm.mode in ["", "rise"]:
		_plan = {}
		return
	_capturing = true                        # (his own Space is the helper's now)
	var wants := inner.pressed(JUMP) or _t - _space_at <= num("recovery", "mash_window_s", 0.35)
	if not wants:
		_plan = {}
		return
	var pos := player.global_position
	var lip := _rm.lip_near(pos)
	if off and not lip.is_empty():
		_give_move(_world_to_keys(steer_dir(pos, lip, _centre(), num("recovery", "lip_in_m", 0.5), num("steer", "frac", 0.4))))
	if _rm.mode != "" or _rm.helpless() or (_rm.jumps_left <= 0 and not _rm.rise_ready):
		return
	if _t >= _replan_at:
		_replan_at = _t + num("recovery", "replan_s", 0.1)
		_look()
	if _plan.is_empty() or bool(_plan.get("desperate", false)):
		_desperate(pos, lip, stun)
		return
	if stun and (_kn == null or not _kn.can_escape()):
		return                               # (in his hitstun a press would only wait for its end: it goes on the first free frame)
	for ev: Dictionary in (_plan.events as Array):
		if bool(ev.get("done", false)) or float(ev.t) > _t + 1e-4:
			continue
		ev.done = true
		_press(stun)
		break


## The plan looked at again: kept while what is left of it still comes back, else the first that does.
func _look() -> void:
	var st := sim_state()
	if st.is_empty():
		return
	if not _plan.is_empty() and not bool(_plan.get("desperate", false)):
		var rest: Array = []
		for ev: Dictionary in (_plan.events as Array):
			if not bool(ev.get("done", false)):
				rest.append({"t": maxf(float(ev.t) - _t, 0.0), "key": ev.key})
		if not rest.is_empty() and _comes_back(st, rest):
			return
	stats.plans = int(stats.plans) + 1
	_plan = {}
	var evs: Variant = find_plan(st)
	if evs == null:
		_plan = {"events": [], "desperate": true}
		stats.desperate = int(stats.desperate) + 1
		return
	var abs_evs: Array = []
	for ev: Dictionary in (evs as Array):
		abs_evs.append({"t": _t + float(ev.t), "key": ev.key})
	_plan = {"events": abs_evs, "desperate": false}


## The first plan that comes back from `st` (relative events [{t, key: "jump"}]; [] the drift alone), or null: none.
func find_plan(st: Dictionary) -> Variant:
	var budget := int(num("recovery", "budget", 40.0))
	var n := 0
	if _comes_back(st, []):
		return []
	n += 1
	var jumps := int(st.get("jumps_left", 0)) > 0
	var rise := bool(st.get("rise_ready", false)) and not bool(st.get("helpless", false))
	var dj_wait := maxf(RingMoves.num("double_jump", "rise_after_s", 0.2) - (_t - _dj_at), 0.0) + 0.02
	for tv: Variant in (block("recovery").get("press_times_s", [0.0]) as Array):
		var t := float(tv)
		if jumps:
			var base: Array = [{"t": t, "key": "jump"}]
			if _comes_back(st, base):
				return base
			n += 1
			if rise:
				for uv: Variant in (block("recovery").get("rise_after_s", [0.22]) as Array):
					var two: Array = [{"t": t, "key": "jump"}, {"t": t + float(uv), "key": "jump"}]
					n += 1
					if _comes_back(st, two):
						return two
					if n >= budget:
						return null
		elif rise:
			var one: Array = [{"t": maxf(t, dj_wait), "key": "jump"}]
			n += 1
			if _comes_back(st, one):
				return one
		if n >= budget:
			return null
	return null


func _comes_back(st: Dictionary, evs: Array) -> bool:
	stats.sims = int(stats.sims) + 1
	var cb := plan_callable(evs, _aim(), _centre(), num("recovery", "lip_in_m", 0.5), num("steer", "frac", 0.4))
	var r := RingMoves.simulate(st, cb, num("recovery", "sim_dt", 1.0 / 30.0), num("recovery", "horizon_s", 2.4))
	return String(r.get("result", "")) in ["deck", "edge"]


## The lead model's late order when no plan comes back: the double jump falling under the lip + dj_under_m, the Rise falling
## under the lip + rise_under_m (rise_after_s after the double jump).
func _desperate(pos: Vector3, lip: Dictionary, stun: bool) -> void:
	if stun or lip.is_empty():
		return
	var vy := _kn.base_of(player.velocity).y if _kn != null else player.velocity.y
	var lip_y := float(Vector3(lip.point).y)
	var d: Dictionary = block("recovery").get("desperate", {})
	if vy >= 0.0:
		return
	if _rm.jumps_left > 0 and pos.y < lip_y + float(d.get("dj_under_m", 0.5)):
		_press(false)
	elif _rm.jumps_left <= 0 and _rm.rise_ready and pos.y < lip_y + float(d.get("rise_under_m", -0.5)) \
			and _t - _dj_at > RingMoves.num("double_jump", "rise_after_s", 0.2) + 0.02:
		_press(false)


## Space pressed for him this frame (the double jump, the Rise, or the escape from hitstun).
func _press(stun: bool) -> void:
	_press_frame = Engine.get_physics_frames()
	var kind := "double_jump" if _rm.jumps_left > 0 else "rise"
	if stun and _kn != null and _kn.can_escape():
		kind = "escape"
	_press_kind = kind
	var pr: Dictionary = stats.presses
	pr[kind] = int(pr.get(kind, 0)) + 1
	assisted.emit(kind)


## The look-ahead's body now (RingMoves.simulate's state): his feet, his own velocity and the knock's carry, his element,
## the air moves left, his hitstun left ({} none).
func sim_state() -> Dictionary:
	if _rm == null:
		return {}
	var kn := _kn
	var vel := kn.base_of(player.velocity) if kn != null else player.velocity
	var kv := Vector3(kn.kv.x, 0.0, kn.kv.z) if kn != null else Vector3.ZERO
	var st := {"pos": player.global_position, "vel": vel, "kv": kv, "element": _element(), "jumps_left": _rm.jumps_left,
			"dodge_ready": false, "rise_ready": _rm.rise_ready, "helpless": _rm.helpless(), "air": true,
			"grabs": int(_rm.get(&"_grabs")) if _rm.get(&"_grabs") != null else 0}
	if kn != null and kn.stun_t > 0.0:
		st["stun_s"] = kn.stun_t
		st["stun_total"] = maxf(_stun_total, kn.stun_t)
	return st


## A plan for RingMoves.simulate: each event's Space pressed once at its time, the steer of steer_dir held, `aim` the Rise's
## way (the Jet's: his camera's, as it is: never turned).
static func plan_callable(evs: Array, aim: Vector3, centre: Vector3, lip_in: float, frac: float) -> Callable:
	var fired := {}
	return func(s: Dictionary) -> Dictionary:
		var it := {"move": steer_dir(Vector3(s.pos), s.lip, centre, lip_in, frac), "aim": aim}
		for i in evs.size():
			if fired.has(i) or float((evs[i] as Dictionary).t) > float(s.t) + 1e-4:
				continue
			fired[i] = true
			it["jump"] = true
			break
		return it


## The way he is steered (flat, world): off the deck toward the nearest lip (lip_in m inside it), over the deck toward its
## centre at `frac`.
static func steer_dir(pos: Vector3, lip: Dictionary, centre: Vector3, lip_in: float, frac: float) -> Vector3:
	if lip.is_empty():
		return Vector3.ZERO
	var point: Vector3 = lip.point
	var out := float(lip.get("out_m", 0.0)) > 0.0 or pos.y < point.y - RingMoves.num("rise", "off_under_m", 0.3)
	if out:
		var to: Vector3 = point - Vector3(lip.normal) * lip_in - pos
		to.y = 0.0
		return to.normalized() if to.length() > 0.05 else -Vector3(lip.normal)
	var c := centre - pos
	c.y = 0.0
	return c.normalized() * frac if c.length() > 0.3 else Vector3.ZERO


# ---------------------------------------------------------------- the keys he holds, as the game reads them
## The deck's centre (world): the test deck's when there is one, else the arena's.
func _centre() -> Vector3:
	if not RingMoves.geo_override.is_empty():
		return (RingMoves.geo_override.xf as Transform3D).origin
	var a: RingArena = RingArena.find(get_tree()) if is_inside_tree() else null
	return a.global_position if a != null else Vector3.ZERO


func _centre_dir() -> Vector3:
	var c := _centre() - player.global_position
	c.y = 0.0
	return c.normalized() if c.length() > 0.3 else Vector3.ZERO


## The way his camera looks (the Rise's aim, as RingMoves reads it from his keys): never changed here.
func _aim() -> Vector3:
	return -player.camera.global_basis.z if player.camera != null else -player.global_basis.z


func _element() -> String:
	var e := String(player.arena_element)
	if e in RingMoves.ELEMENTS:
		return e
	var b := Bending.of(player)
	return b.element if b != null and b.element in RingMoves.ELEMENTS else "water"


## His held direction (flat, world), as RingMoves reads his keys.
func _raw_world(inner: PlayerControls) -> Vector3:
	var mv := inner.move_vector()
	return Basis(Vector3.UP, player.yaw) * Vector3(mv.x, 0.0, mv.y)


func _world_to_keys(w: Vector3) -> Vector2:
	var l := Basis(Vector3.UP, player.yaw).inverse() * Vector3(w.x, 0.0, w.z)
	return Vector2(l.x, l.z).limit_length(1.0)


func _give_move(keys: Vector2) -> void:
	_move = keys
	_move_frame = Engine.get_physics_frames()


## AssistControls' answers (this frame's): held, pressed this frame, the move keys.
func held(inner: PlayerControls, action: StringName) -> bool:
	var raw := inner.pressed(action)
	if not raw or not active():
		return raw
	if action == CROUCH and (blocks("crouch") or blocks("fast_fall")):
		return false
	if _rm != null and _rm.mode == "hang" and blocks("edge_options") and action in [InputSetup.GUARD_ACTION, FIRE]:
		return false
	return raw


func pressed_now(inner: PlayerControls, action: StringName) -> bool:
	var raw := inner.just_pressed(action)
	if not active():
		return raw
	var fr := Engine.get_physics_frames()
	if action == JUMP:
		if _press_frame == fr:
			return true
		if _capturing or (_rm != null and _rm.mode == "hang" and on("edge")):
			return false
		return raw
	if not raw:
		return false
	if action == CROUCH and (blocks("crouch") or blocks("fast_fall")):
		return false
	if action in MOVES and blocks("roll"):
		return false                         # (no fresh direction: the guard's roll is Full's; a held one still walks)
	if _rm != null and _rm.mode == "hang" and blocks("edge_options") and action in [InputSetup.GUARD_ACTION, FIRE]:
		return false
	return raw


func move_keys(inner: PlayerControls) -> Vector2:
	if active() and _move_frame == Engine.get_physics_frames():
		return _move
	return inner.move_vector()


## Key events held back under Basic before the game reads them (the hotbar's 3 in the air, 4 and 5 before the first win).
func _input(e: InputEvent) -> void:
	if not e.is_pressed() or e.is_echo() or not _compute_active():
		return
	var rm := RingMoves.of(player)
	if blocks("air_dodge") and e.is_action(&"weapon_3") and rm != null and (rm.airborne() or rm.off_deck() or _stunned()):
		get_viewport().set_input_as_handled()
		return
	for n: Variant in (block("blocks").get("later_keys", [4, 5]) as Array):
		if e.is_action(StringName("weapon_%d" % int(n))) and not won_once():
			get_viewport().set_input_as_handled()
			return


## The player's PlayerControls as the game reads them under the helpers (Full, or not active: exactly the wrapped one's).
class AssistControls:
	extends PlayerControls
	var inner: PlayerControls
	var helper: RingAssist

	func _init(base: PlayerControls = null, a: RingAssist = null) -> void:
		inner = base if base != null else PlayerControls.new()
		helper = a
		from_input = inner.from_input

	func pressed(action: StringName) -> bool:
		return helper.held(inner, action) if helper != null and is_instance_valid(helper) else inner.pressed(action)

	func just_pressed(action: StringName) -> bool:
		return helper.pressed_now(inner, action) if helper != null and is_instance_valid(helper) else inner.just_pressed(action)

	func move_vector() -> Vector2:
		return helper.move_keys(inner) if helper != null and is_instance_valid(helper) else inner.move_vector()

	## (its own book kept as the wrapped one's too, so a reader of _held / _down_at sees the same)
	func set_held(action: StringName, on: bool) -> void:
		inner.set_held(action, on)
		super.set_held(action, on)

	func release_all() -> void:
		inner.release_all()
		super.release_all()
