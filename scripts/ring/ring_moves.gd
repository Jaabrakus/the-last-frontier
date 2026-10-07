class_name RingMoves
extends Node
## The movement set of Tidebreak's % ring (round 3, smash_r3 spec §4, §5.3-5.4, §14.3; MOVE's file): one mover for the player
## and the bots. A Node child named NODE_NAME of the body, installed only in a stock-rules ring (RingMode, PERCENT's: THE GATE
## per body is `RingMoves.of(body) != null`), so with none the open world, the duel and the classic ring move exactly as
## before. Every number in data/ring/movement.json.
##
##   install(body) / of(body)     put one on the body (once) / the body's, or null
##   pre(intent, dt) -> bool      the body's whole frame of motion: true (it moved the body: the controller skips its own
##                                steering and move). intent: NpcPad.intent()'s keys (the bots), or intent_from_keys() (the
##                                player's keys): {move (flat, world, |move| <= 1), jump, jump_short, jump_held, dodge,
##                                dodge_dir, fast_fall, down_held, guard_held, guard_pressed, ledge ("" / a bool / "climb",
##                                "roll", "jump", "attack", "drop"), di}, and when present sprint, fresh_dir (a direction key
##                                pressed this frame: the guard's roll), attack (LMB: the edge and getup attacks), cast (a
##                                cast key pressed: the spout, the "spent" beat), aim (the Jet's way)
##   profile()                    the body's ring numbers (self_up_mult: the self-cast lifts scaled to the ring's gravity)
##   the state                    can_cast(), airborne(), off_deck(), helpless(), on_ledge(), on_spout(), intangible(),
##                                in_landing_lag(); jumps_left, dodge_ready, rise_ready, ledge_safe_left(); clip_state()
##                                (the body-state clip SwayPose and NpcBody play), lean() (the steer's lean)
##   asked of it                  dodge(dir) (AIR: 3 in the air), land_lag(s) (AIR: an aerial's landing lag), spend_rise()
##                                (a self-launch from the deck used the airtime's Rise), ride_spout(pos, max_s) (PERCENT:
##                                left_spout as it ends), leave_spout() (AIR: a cast key on the spout), cam_bias() and
##                                cam_yaw_step(yaw, dt) (the player's camera), note_mouse() (the player moved his mouse)
##   simulate(state, plan, dt, horizon)   (static) the bots' look-ahead: the same code on a body of numbers (virtual) over a
##                                deck box: where a plan of inputs takes it ({result: deck | edge | water | air, t, pos, ...});
##                                plan(kind, ...) makes spec §9.6's six recovery plans and the lead model's policy
##
## THE RULES (spec v2): gravity 20 (BendKnock.gravity_override when set), run 5 / sprint 6.5, the element's air drift; Space
## is always the full jump (2.0 m) and the short hop (0.8 m) is Space within 0.05 s of a cast's release (either order);
## Space in the air the double jump (it keeps half the launch's carry: BendKnock.scale_carry); once it is spent, off the deck
## and a fresh press 0.2 s after it, the Rise (once per airtime, helpless after); refreshed by landing, a grab and a tumbling
## launch only (BendKnock.launched with refresh). C: fast fall after the apex, crouch held on the deck, no grab while held,
## let go on the edge; the guard's Roll and Duck; the air dodge (3, AIR routes it here); the teeter at every lip; the edge
## (the grab box, the snap, 0.6 s first-grab safety, 4 s, deck-relative options, occupancy, three grabs then the deck); each
## element's Rise (the Pillar's lean, the Jet's +20 floor, the scramble); hitstun (no steering, one buffered press, the 0.6 s
## escape by a fresh press, the steer read at 0.1 s), breaking the fall's motion and the getups (PERCENT judges, this
## moves); the spout ride; the camera's framing and the recovery turn. Intangible windows are one BendStatus.take_filter, and
## the body's collision layers go to 0 meanwhile so a bolt flies through unspent.

## kind: jump, double_jump, dodge, rise, grab, climb, ledge_jump, ledge_roll, ledge_attack, break_fall, roll, duck, scramble.
signal moved(kind: String)
## The spout let the body go (a key, or its time up).
signal left_spout

const NODE_NAME := "RingMoves"
const DATA_PATH := "res://data/ring/movement.json"
const ELEMENTS := ["earth", "water", "fire", "air"]
## Modes that hold the body on or at the lip (the edge's).
const LEDGE_MODES := ["hang", "climb", "ledge_roll", "ledge_attack", "scramble"]

static var _data := {}
## The bodies hanging on the lip now: instance id -> {point (world), side}.
static var _hangers := {}
## The take filter (intangible: no hurt, no knock) registered once with BendStatus.
static var _filter := Callable()
## A deck to use instead of the RingArena's (tests; {} the arena's): {xf (Transform3D: the deck's frame, its top at y
## `top`), hl, hw (half length along x, half width along z), top, water_y (world), tank (the curtain, m past the lips)}.
static var geo_override := {}

## Jumps left in this airtime (the double jump's).
var jumps_left := 1
## The air dodge is there to use in this airtime.
var dodge_ready := true
## The Rise is there to use (off the deck, the double jump spent).
var rise_ready := true
## The body this moves (null in a simulation).
var body: CharacterBody3D
## A body of numbers (simulate()): no tree, no hits, no looks, its own deck box.
var virtual := false
## The mode: "" free (run, jump, fall), dodge, roll, duck, break_roll, getup_roll, hang, climb, ledge_roll, ledge_attack,
## scramble, rise, lie, getup_attack, wall, spout; its time and its numbers.
var mode := ""
var mode_t := 0.0
var _m := {}
## The looks and sounds on this body (RingMoveLooks; null on a bot's or a simulation's when nothing shows).
var looks: RingMoveLooks

## This frame's intent and own velocity (the knock's carry kept out), the body's clock.
var _it := {}
var _o := Vector3.ZERO
var _g_corr := 0.0
var _placed_n := 0
var _last_dt := 1.0 / 60.0
var _t := 0.0
var _air := false
var _helpless := false
var _glide := false
var _ff := false
var _lag := 0.0
var _lag_heavy := false
var _crouch := false
var _teeter_t := 0.0
var _teetering := false
var _jump_at := -INF
var _jump_y := 0.0
var _jump_short := false
var _dj_at := -INF
var _cast_rel_at := -INF
var _guard_at := -INF
var _grabs := 0
var _first_safe := true
var _hang_safe_until := -INF
var _regrab_until := -INF
var _int_from := INF
var _int_until := -INF
var _rise_end_at := -INF
var _ledge_jump_at := -INF
var _tech_at := -INF
var _getup_at := -INF
var _land_at := -INF
var _rep_n := 0
var _rep_end := -INF
var _exhaled := false
## Hitstun: last frame's, the buffered press ("" none, "jump", "dodge") and its dodge's way, the fallback's own tracking (no
## stock RingRules: tests, a classic ring), the escape's tick told.
var _was_stun := false
var _buffer := ""
var _buffer_dir := Vector3.ZERO
var _stun_from := -INF
var _stun_total := 0.0
var _last_stun_t := 0.0
var _tick_told := false
## The steer: when it is read, the launch's flat way, the lean (-1..1) and until when.
var _di_at := INF
var _launch_dir := Vector3.ZERO
var _lean := 0.0
var _lean_until := -INF
## The knock's look: thrown downward (a Slam's spike) until he lands; the knock's bounce off the deck seen (its time).
var _spiked := false
var _bounce_at := -INF
var _kn_bounced := false
## The camera (the player's): the off-deck framing's weight, the hang's, the recovery turn's state.
var _cam_w := 0.0
var _hang_w := 0.0
var _mouse_at := -INF
var _turning := false
var _turn_off := false
## The body's collision layers kept while intangible (-1: not taken).
var _layers_kept := {}
var _last_pos := Vector3.INF
var _caster_hooked := false
var _kn_hooked: BendKnock
var _arena: RingArena
var _geo_cache := {}
var _geo_frame := -1
## A simulation's body: place, own velocity, the carry, on the floor, its hitstun, its deck.
var _vpos := Vector3.ZERO
var _vkv := Vector3.ZERO
var _vfloor := false
var _vstun := 0.0
var _vgeo := {}
var _vleft := false
var _vel_name := "water"


# ---------------------------------------------------------------- install, data
## A RingMoves on `b` (one only: the one it has, else a new one). Only a stock-rules ring calls it.
static func install(b: Node) -> RingMoves:
	var m := of(b)
	if m != null or b == null or not is_instance_valid(b):
		return m
	m = RingMoves.new()
	m.name = NODE_NAME
	m.body = b as CharacterBody3D
	b.add_child(m)
	return m


## The body's RingMoves, or null (the gate: none outside a stock-rules ring).
static func of(b: Node) -> RingMoves:
	if b == null or not is_instance_valid(b):
		return null
	return b.get_node_or_null(NODE_NAME) as RingMoves


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else {}
		_data = d if d is Dictionary else {}
	return _data


## movement.json's block `key` ({} none).
static func block(key: String) -> Dictionary:
	var b: Variant = data().get(key, {})
	return b if b is Dictionary else {}


## Number `key` of block `blk` (a nested block by "a.b").
static func num(blk: String, key: String, def := 0.0) -> float:
	var d := block(blk)
	if key.contains("."):
		var parts := key.split(".")
		var sub: Variant = d.get(parts[0], {})
		return float((sub as Dictionary).get(parts[1], def)) if sub is Dictionary else def
	return float(d.get(key, def))


## The element's number: block `blk`'s `key_el`[el] when it has one, else `key`.
static func el_num(blk: String, key: String, el: String, def := 0.0) -> float:
	var per: Variant = block(blk).get(key + "_el", {})
	if per is Dictionary and (per as Dictionary).has(el):
		return float(per[el])
	return num(blk, key, def)


## The one ring gravity (BendKnock.gravity_override when RingMode set it, else movement.json's).
static func gravity() -> float:
	return BendKnock.gravity_override if BendKnock.gravity_override > 0.0 else num("physics", "gravity", 20.0)


## The Rise's numbers for `el`.
static func rise_of(el: String) -> Dictionary:
	var r: Variant = block("rise").get(el, {})
	return r if r is Dictionary else {}


## [drift m/s, accel m/s^2] for `el`.
static func drift_of(el: String) -> Vector2:
	var d: Variant = block("drift").get(el, [4.0, 16.0])
	return Vector2(float(d[0]), float(d[1])) if d is Array and (d as Array).size() >= 2 else Vector2(4.0, 16.0)


func _ready() -> void:
	if virtual or body == null:
		return
	_ensure_filter()
	if &"ring_moves" in body:
		body.set(&"ring_moves", self)            # (FrontierPlayer's and NpcFighter's gate)
	var kn := BendKnock.of(body)
	_hook_knock(kn)
	_last_pos = body.global_position
	# (the looks on him: his own sounds and shadow only when he is the local player)
	looks = RingMoveLooks.new()
	looks.name = "RingMoveLooks"
	looks.moves = self
	looks.own = body is FrontierPlayer and (body as FrontierPlayer).is_local
	add_child(looks)


func _exit_tree() -> void:
	_unhang()
	_set_layers(false)
	if not virtual and body != null and is_instance_valid(body) and body.get(&"ring_moves") == self:
		body.set(&"ring_moves", null)
	if not virtual and body != null:
		_live -= 1
		if _live <= 0:
			_live = 0
			BendStatus.take_filters.erase(_filter)


## RingMoves in the tree now (the take filter stands while any is).
static var _live := 0


## The intangibility filter (BendStatus.take_filters), once for every RingMoves; taken away with the last.
func _ensure_filter() -> void:
	_live += 1
	if _filter.is_valid() and BendStatus.take_filters.has(_filter):
		return
	_filter = func(n: Node, _caster: Node) -> bool:
		var m := RingMoves.of(n)
		return m == null or not m.intangible()
	BendStatus.take_filters.append(_filter)


func _hook_knock(kn: BendKnock) -> void:
	if kn == null or kn == _kn_hooked:
		return
	_kn_hooked = kn
	kn.launched.connect(_on_launched)
	kn.broke_fall.connect(_on_broke_fall)
	kn.knocked.connect(_on_knocked)


func _hook_caster() -> void:
	if _caster_hooked or virtual or body == null:
		return
	var c := SwayCaster.of(body) if body is FrontierPlayer else null
	if c == null:
		return
	_caster_hooked = true
	c.cast_released.connect(_on_cast_released)
	c.air_cast.connect(func(_m2: String, _md: String) -> void:
		if looks != null:
			looks.air_legs_at = _t)


# ---------------------------------------------------------------- the answers
## The body's ring numbers: self_up_mult (the self-cast lifts scaled to the ring's gravity), the physics for its element.
## With no body (no ring) today's: self_up_mult 1.
func profile() -> Dictionary:
	if body == null and not virtual:
		return {"self_up_mult": 1.0}
	var el := _el()
	var d := drift_of(el)
	var g := gravity()
	return {"self_up_mult": num("jump", "self_up_mult", 1.43), "gravity": g, "run": num("physics", "run", 5.0),
			"sprint": num("physics", "sprint", 6.5), "drift": d.x, "air_accel": d.y,
			"max_fall": el_num("physics", "max_fall", el, 11.0), "fast_fall": el_num("fast_fall", "mps", el, 17.0),
			"jump_v": sqrt(2.0 * g * num("jump", "apex_m", 2.0)), "short_v": sqrt(2.0 * g * num("jump", "short_apex_m", 0.8)),
			"double_jump_v": sqrt(2.0 * g * el_num("double_jump", "m", el, 1.6)), "element": el}


## A cast may start now (not hanging or on the edge's moves, helpless, in an air dodge, in landing lag, lying, in hitstun).
func can_cast() -> bool:
	if body == null and not virtual:
		return true
	if mode in LEDGE_MODES or mode in ["dodge", "lie", "getup_attack", "roll", "duck", "rise", "wall"]:
		return false
	return not _helpless and _lag <= 0.0 and not _stunned()


func airborne() -> bool:
	if body == null and not virtual:
		return false
	return _air and not mode in LEDGE_MODES and mode != "spout"


## Over the water: the feet outside the deck's rectangle, or more than rise.off_under_m under the lip.
func off_deck() -> bool:
	if body == null and not virtual:
		return false
	var g := _geo()
	if g.is_empty():
		return false
	var l := _local(g, _pos())
	return absf(l.x) > float(g.hl) or absf(l.z) > float(g.hw) or l.y < float(g.top) - num("rise", "off_under_m", 0.3)


## After the Rise: no more air moves until he lands or grabs the edge.
func helpless() -> bool:
	return _helpless


func on_ledge() -> bool:
	return mode in LEDGE_MODES


func on_spout() -> bool:
	return mode == "spout"


## Hits pass through him now (a dodge's window, the first grab's safety, an edge option's, a getup's).
func intangible() -> bool:
	if body == null and not virtual:
		return false
	if _t >= _int_from and _t < _int_until:
		return true
	if mode == "hang" and _t < _hang_safe_until:
		return true
	var w: Variant = _m.get("int", null)
	if w is Array and (w as Array).size() == 2:
		return mode_t >= float(w[0]) and mode_t < float(w[1])
	return false


func in_landing_lag() -> bool:
	return _lag > 0.0


## Seconds of the edge's first-grab safety left.
func ledge_safe_left() -> float:
	return maxf(_hang_safe_until - _t, 0.0) if mode == "hang" else 0.0


## The Rise used up for this airtime (a self-launch from the deck: Lift, Jets, Leap), without leaving him helpless.
func spend_rise() -> void:
	rise_ready = false


## `s` seconds of landing lag (AIR: an aerial landing while it is out).
func land_lag(s: float) -> void:
	if s > _lag:
		_lag = s
		_lag_heavy = false
	_land_at = _t


# ---------------------------------------------------------------- the frame
## The body's frame of motion before its controller's: true when this moved it (always, on a live body).
func pre(intent: Dictionary, dt: float) -> bool:
	if not virtual:
		if body == null or not is_instance_valid(body) or not body.is_inside_tree() or _dead():
			return false
		_hook_knock(BendKnock.peek(body))
		_hook_caster()
	_t += dt
	_last_dt = dt
	_it = intent
	_teleport_check()
	var stun := _stunned()
	_track_stun(stun, dt)
	_track_bounce()
	if _b("guard_pressed"):
		_guard_at = _t
	_lag = maxf(_lag - dt, 0.0)
	_teetering = false
	if _was_stun and not stun:
		_on_free()
	if _b("guard_pressed") and _tumbling():
		_press_break()
	if _t >= _di_at:
		_read_di()
	if mode == "" and _lying():
		_set_mode("lie", {})
	_o = _read_own()
	_step(dt)
	_post(dt)
	_was_stun = stun
	if not virtual:
		_last_pos = body.global_position
	return true


func _step(dt: float) -> void:
	match mode:
		"dodge":
			_step_dodge(dt)
		"roll", "duck", "break_roll", "getup_roll":
			_step_roll(dt)
		"hang":
			_step_hang(dt)
		"climb", "ledge_roll", "ledge_attack":
			_step_ledge_move(dt)
		"scramble":
			_step_scramble(dt)
		"rise":
			_step_rise(dt)
		"lie":
			_step_lie(dt)
		"getup_attack":
			_step_getup_attack(dt)
		"wall":
			_step_wall(dt)
		"spout":
			_step_spout(dt)
		_:
			_step_free(dt)


func _set_mode(m: String, spec: Dictionary) -> void:
	if mode == "rise" and m != "rise" and looks != null and _m.has("el"):
		# (the Rise left any way (its end, the scramble, a grab, a landing, a knock): its trail stops, its column sinks)
		looks.rise_end(String(_m.el), _pos())
	mode = m
	mode_t = 0.0
	_m = spec


## The free frame: the run on the deck, the drift in the air, the jumps, fast fall, the guard's dodges, the teeter, the grab.
func _step_free(dt: float) -> void:
	# (just put somewhere: the body's floor is last frame's place's until it has moved once)
	var floor := _grounded() and _placed_n <= 0
	_placed_n -= 1
	var stun := _stunned()
	if floor and _air and _o.y <= 0.01 and _t - _jump_at > 0.02:
		_land()
	elif not _air and (not floor or _o.y > 1.0):
		# (off the floor: walked off, or lifted by something else: a self-launch's up dash, a knock's up part)
		_leave_ground()
		floor = false
	var on_ground := floor and not _air
	# the guard's Roll and Duck (a fresh direction, C)
	if on_ground and not stun and _lag <= 0.0 and _try_ground_dodge():
		_step(dt)
		return
	_crouch_to(on_ground and _b("down_held") and not stun and _lag <= 0.0)
	if _b("jump"):
		_on_jump_press(on_ground)
		if mode != "":
			_step(dt)
			return
		on_ground = on_ground and not _air
	elif _b("jump_short") and on_ground and not stun:
		_ground_jump(true)
		on_ground = false
	if _b("dodge") and _air:
		dodge(_v3("dodge_dir"))
		if mode != "":
			_step(dt)
			return
	if _b("fast_fall"):
		_on_down_press()
	if _air and _helpless and (_b("guard_pressed") or _b("cast") or _b("attack")):
		_spent()
	if on_ground:
		_ground_physics(dt, stun)
		_lip_guard(dt, stun)
	else:
		_air_physics(dt, stun, 1.0)
	_apply(dt)
	if _air and _t - _rise_end_at <= num("rise", "scramble_after_s", 0.1) + 1e-4 and _try_scramble():
		return
	if _air:
		_try_grab()


## The deck's run: toward the held way at run (sprint) speed, its accel and decel; held still crouched, in landing lag, in
## hitstun (no steering) and at a speed cap of the body's own (a root, the countdown, a floor cast).
func _ground_physics(dt: float, stun: bool) -> void:
	var mv := _move_vec()
	var spd := num("physics", "sprint", 6.5) if _b("sprint") else num("physics", "run", 5.0)
	spd = minf(spd, _speed_cap())
	var target := mv * spd
	if _crouch or _lag > 0.0 or stun or _guard_zone():
		target = Vector3.ZERO
	var flat := Vector3(_o.x, 0.0, _o.z)
	var acc := num("physics", "accel", 40.0) if target.length() > flat.length() else num("physics", "decel", 30.0)
	flat = flat.move_toward(target, acc * dt)
	_o.x = flat.x
	_o.z = flat.z
	_o.y = minf(_o.y, 0.0) - gravity() * dt


## The air: the element's drift (x mult; helpless x helpless_drift), a little friction with nothing held; no steering in
## hitstun; gravity, the glide, max fall (none in hitstun), fast fall.
func _air_physics(dt: float, stun: bool, mult: float) -> void:
	var el := _el()
	var d := drift_of(el)
	var drift := d.x * mult * (num("rise", "helpless_drift", 0.6) if _helpless else 1.0)
	var mv := _move_vec()
	var flat := Vector3(_o.x, 0.0, _o.z)
	if not stun:
		if mv.length() > 0.05:
			flat = flat.move_toward(mv * drift, d.y * dt)
		else:
			flat = flat.move_toward(Vector3.ZERO, num("physics", "air_friction", 2.0) * dt)
	_o.x = flat.x
	_o.z = flat.z
	var vy0 := _o.y
	_o.y -= gravity() * dt
	if _glide:
		_o.y = maxf(_o.y, -float(rise_of(el).get("glide_mps", 3.0)))
	if not stun:
		_o.y = maxf(_o.y, -el_num("physics", "max_fall", el, 11.0))
	if _ff and not stun:
		_o.y = -el_num("fast_fall", "mps", el, 17.0)
	# (the step moves at the frame's mean fall speed, so a jump's arc is exact at every frame: 2.0 m is 2.0 m at any rate)
	if is_equal_approx(_o.y, vy0 - gravity() * dt):
		_g_corr = gravity() * dt * 0.5


## Space: on the deck the jump (the short hop within hop_cast_s after a cast's release); in the air the double jump, else
## off the deck the Rise; held back in hitstun (buffered, or the escape), helpless ("spent"), landing lag.
func _on_jump_press(on_ground: bool) -> void:
	if _stunned():
		_press_in_stun("jump", Vector3.ZERO)
		return
	if mode == "spout":
		return
	if on_ground:
		if _lag > 0.0:
			return
		var short := _b("jump_short") or _t - _cast_rel_at <= num("jump", "hop_cast_s", 0.05) + 1e-4
		_ground_jump(short)
		return
	if _helpless:
		_spent()
		return
	_air_jump()


func _ground_jump(short: bool) -> void:
	var apex := num("jump", "short_apex_m", 0.8) if short else num("jump", "apex_m", 2.0)
	_o.y = sqrt(2.0 * gravity() * apex)
	_air = true
	_jump_at = _t
	_jump_y = _pos().y
	_jump_short = short
	_crouch_to(false)
	moved.emit("jump")


## The double jump, else the Rise (off the deck, rise_after_s after the double jump); true when one went.
func _air_jump() -> bool:
	if jumps_left > 0:
		_double_jump()
		return true
	if rise_ready and off_deck() and _t - _dj_at >= num("double_jump", "rise_after_s", 0.2) - 1e-4:
		_start_rise()
		return true
	return false


func _double_jump() -> void:
	var el := _el()
	_o.y = sqrt(2.0 * gravity() * el_num("double_jump", "m", el, 1.6))
	_scale_carry(num("double_jump", "carry_keep", 0.5))
	var mv := _move_vec()
	var flat := Vector3(_o.x, 0.0, _o.z)
	if mv.length() > 0.1:
		flat = mv.normalized() * drift_of(el).x
	else:
		flat *= num("double_jump", "own_keep", 0.5)
	_o.x = flat.x
	_o.z = flat.z
	jumps_left = 0
	_dj_at = _t
	_ff = false
	_glide = false
	if looks != null:
		looks.double_jump(el)
	moved.emit("double_jump")
	_check_exhale()


## C pressed: after the apex the fast fall (kept until he lands, jumps or dodges); it ends the glide. Not in hitstun.
func _on_down_press() -> void:
	if not _air or _stunned():
		return
	_glide = false
	if _o.y <= num("fast_fall", "after_vy", 0.5):
		_ff = true


## AIR's 3 in the air (a bot's pad too): directional along `dir` (flat), neutral with none. Once per airtime; in hitstun the
## buffer or the escape; helpless "spent".
func dodge(dir: Vector3) -> void:
	if body == null and not virtual:
		return
	if mode == "spout":
		leave_spout()
	if not _air or mode in LEDGE_MODES:
		return
	if _stunned():
		_press_in_stun("dodge", dir)
		return
	if _helpless:
		_spent()
		return
	if not dodge_ready or mode != "":
		return
	_start_dodge(dir)


func _start_dodge(dir: Vector3) -> void:
	dodge_ready = false
	_ff = false
	_glide = false
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.1:
		_set_mode("dodge", {"dir": flat.normalized(), "neutral": false, "int": block("air_dodge").get("intangible", [0.04, 0.3]),
				"len": num("air_dodge", "s", 0.22) + num("air_dodge", "end_s", 0.28)})
	else:
		_o = _read_own() * num("air_dodge", "neutral_keep", 0.3)
		_write_own()
		_set_mode("dodge", {"dir": Vector3.ZERO, "neutral": true,
				"int": block("air_dodge").get("neutral_intangible", [0.04, 0.4]),
				"len": num("air_dodge", "neutral_s", 0.4) + num("air_dodge", "neutral_end_s", 0.15)})
	if looks != null:
		looks.dash(_el())
	moved.emit("dodge")
	_check_exhale()


func _step_dodge(dt: float) -> void:
	var prev := mode_t
	mode_t += dt
	var neutral := bool(_m.get("neutral", false))
	var s := num("air_dodge", "s", 0.22)
	var travel_over := false
	if not neutral and prev < s:
		# (the travel: m in s, flat, gravity off; the last frame's share so it is m exactly; stopped after, vy 0)
		var frac := clampf((s - prev) / dt, 0.0, 1.0)
		var sp := num("air_dodge", "m", 3.2) / s
		var d: Vector3 = _m.dir
		_o = d * sp * frac
		travel_over = mode_t >= s
	else:
		_air_physics(dt, false, 1.0)
	_apply(dt)
	if travel_over:
		_o = Vector3.ZERO
		_write_own()
	if _grounded() and mode_t > dt * 0.5:
		var lag := num("air_dodge", "neutral_land_lag_s", 0.15) if neutral else num("air_dodge", "land_lag_s", 0.3)
		_set_mode("", {})
		_land()
		_lag = maxf(_lag, lag)
		_lag_heavy = true
		return
	if mode_t >= float(_m.get("len", 0.5)):
		_set_mode("", {})


# ---------------------------------------------------------------- the guard's Roll and Duck
## The guard is up (his zone stands) or E went down within guard_window_s.
func _guard_ok() -> bool:
	if _t - _guard_at <= num("ground_dodge", "guard_window_s", 0.1) + 1e-4:
		return true
	return _guard_zone()


## A round-2 guard zone of his stands (SwayCaster.guard_up's test, for any body): no walking meanwhile (spec §4.4).
func _guard_zone() -> bool:
	if virtual or body == null or not body.is_inside_tree():
		return false
	for z in body.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.r2 and bz.owner_node == body and BendZone.R2_GUARDS.has(bz.kind) and not bz.is_queued_for_deletion():
			return true
	return false


func _try_ground_dodge() -> bool:
	var fresh := _v3("fresh_dir")
	var pad_dir := _v3("dodge_dir")
	var roll := fresh.length() > 0.1 or (_b("dodge") and pad_dir.length() > 0.1)
	var duck := _b("fast_fall") or (_b("dodge") and pad_dir.length() <= 0.1)
	if not roll and not duck:
		return false
	if not _guard_ok():
		return false
	var rep := 0.0
	if _t - _rep_end <= num("ground_dodge", "repeat_s", 1.0):
		_rep_n += 1
		rep = minf(_rep_n * num("ground_dodge", "repeat_add_s", 0.1), num("ground_dodge", "repeat_max_s", 0.3))
	else:
		_rep_n = 0
	_crouch_to(false)
	if roll:
		var d := fresh if fresh.length() > 0.1 else pad_dir
		d.y = 0.0
		_start_roll("roll", d.normalized(), num("ground_dodge", "roll_m", 3.5), num("ground_dodge", "roll_s", 0.45),
				block("ground_dodge").get("roll_intangible", [0.05, 0.3]), num("ground_dodge", "roll_end_s", 0.15) + rep)
		moved.emit("roll")
	else:
		_start_roll("duck", Vector3.ZERO, 0.0, num("ground_dodge", "duck_s", 0.3),
				block("ground_dodge").get("duck_intangible", [0.04, 0.3]), num("ground_dodge", "duck_end_s", 0.15) + rep)
		moved.emit("duck")
	if looks != null:
		looks.dash(_el())
	return true


func _start_roll(kind: String, dir: Vector3, m: float, s: float, intang: Variant, end_s: float) -> void:
	_set_mode(kind, {"dir": dir, "m": m, "s": s, "int": intang, "end": end_s, "len": s + end_s, "rep": end_s})


func _step_roll(dt: float) -> void:
	var prev := mode_t
	mode_t += dt
	var s := float(_m.s)
	var flat := Vector3.ZERO
	if prev < s and float(_m.m) > 0.0:
		var frac := clampf((s - prev) / dt, 0.0, 1.0)
		flat = Vector3(_m.dir) * (float(_m.m) / s) * frac
	_o.x = flat.x
	_o.z = flat.z
	_o.y = minf(_o.y, 0.0) - gravity() * dt
	_lip_keep(num("ground_dodge", "lip_keep_m", 0.3), dt)
	_apply(dt)
	if mode_t >= float(_m.len) - 1e-6:
		if mode in ["roll", "duck"]:
			_rep_end = _t
		_set_mode("", {})
		# (the roll's own speed ends with it)
		_o.x = 0.0
		_o.z = 0.0
		_write_own()


## Own outward speed taken out where the next step would cross `margin` inside a lip (rolls, dashes; never off).
func _lip_keep(margin: float, dt: float) -> void:
	var g := _geo()
	if g.is_empty():
		return
	var xf: Transform3D = g.xf
	var l := _local(g, _pos())
	var lv := xf.basis.inverse() * _o
	var lim := Vector2(float(g.hl) - margin, float(g.hw) - margin)
	lv.x = _stop_at(l.x, lv.x, lim.x, dt)
	lv.z = _stop_at(l.z, lv.z, lim.y, dt)
	_o = xf.basis * lv


## Speed `v` along an axis at `p` cut so this step ends no further out than +-`lim` (exactly at it; never pulled back).
static func _stop_at(p: float, v: float, lim: float, dt: float) -> float:
	if v > 0.0 and p + v * dt > lim:
		return maxf((lim - p) / dt, 0.0)
	if v < 0.0 and p + v * dt < -lim:
		return minf((-lim - p) / dt, 0.0)
	return v


## The teeter on the deck (all four lips): running stops lip_m inside; holding toward the water step_off_s steps off; a
## dash (BendMotion's carry) stops lip_keep_m inside; hitstun and the knock's carry go over.
func _lip_guard(dt: float, stun: bool) -> void:
	if stun:
		return
	var g := _geo()
	if g.is_empty():
		return
	if _dashing():
		_lip_keep(num("ground_dodge", "lip_keep_m", 0.3), dt)
		return
	var xf: Transform3D = g.xf
	var l := _local(g, _pos())
	var lv := xf.basis.inverse() * _o
	var lm := xf.basis.inverse() * _move_vec()
	var margin := num("teeter", "lip_m", 0.05)
	var lim := Vector2(float(g.hl) - margin, float(g.hw) - margin)
	var hold := num("teeter", "hold_dot", 0.3)
	var crossing := false
	var holding := false
	for ax in [0, 2]:
		var limit: float = lim.x if ax == 0 else lim.y
		var p: float = l[ax]
		var v: float = lv[ax]
		for sgn in [1.0, -1.0]:
			if p * sgn + v * sgn * dt > limit and v * sgn > 0.0:
				crossing = true
				if lm[ax] * sgn > hold:
					holding = true
	if not crossing:
		_teeter_t = 0.0
		return
	if holding:
		_teeter_t += dt
		if _teeter_t >= num("teeter", "step_off_s", 0.3):
			return                                   # (held toward the water long enough: off he steps)
	else:
		_teeter_t = 0.0
	_teetering = true
	lv.x = _stop_at(l.x, lv.x, lim.x, dt)
	lv.z = _stop_at(l.z, lv.z, lim.y, dt)
	_o = xf.basis * lv


# ---------------------------------------------------------------- landing, leaving the ground, refreshes
func _land() -> void:
	_air = false
	_spiked = false
	_ff = false
	_glide = false
	_jump_short = false
	if _helpless:
		_lag = maxf(_lag, num("rise", "helpless_lag_s", 0.35))
		_lag_heavy = true
	_helpless = false
	_refresh()
	_grabs = 0
	_first_safe = true
	_dj_at = -INF
	_turning = false
	_turn_off = false
	_land_at = _t


func _leave_ground() -> void:
	_air = true
	# (a self-launch from the deck, round 2's Lift, Jets or Leap: BendMotion's up dash, uses up the airtime's Rise)
	if not virtual and body != null and _t - _jump_at > 0.05:
		var bm := body.get_node_or_null(^"BendMotion")
		if bm != null and int(bm.get(&"_dash")) == 2:
			rise_ready = false


func _refresh() -> void:
	jumps_left = 1
	dodge_ready = true
	rise_ready = true
	_helpless = false
	_exhaled = false


## "Spent": a press while helpless (Space, 3, E, a cast key), heard by himself.
func _spent() -> void:
	if looks != null:
		looks.spent()


## The last air move gone (helpless, or the double jump, the dodge and the Rise all used): a short exhale and a dull puff,
## once an airtime.
func _check_exhale() -> void:
	if _exhaled:
		return
	if _helpless or (jumps_left <= 0 and not dodge_ready and not rise_ready):
		_exhaled = true
		if looks != null:
			looks.exhale(_el())


# ---------------------------------------------------------------- hitstun, the steer, breaking the fall, lying
## In hitstun now (RingRules' under stock rules; else BendKnock.stun_t, the tests' and a simulation's own).
func _stunned() -> bool:
	if virtual:
		return _vstun > 0.0
	var r := _rules()
	if r != null:
		return r.stunned(body)
	var kn := BendKnock.peek(body)
	return kn != null and kn.stun_t > 0.0


## A fresh press may end hitstun now (RingRules.can_escape under stock; else from escape_s into a stun longer than it).
func _can_escape() -> bool:
	var r := _rules()
	if r != null:
		return r.can_escape(body)
	var e := num("hitstun", "escape_s", 0.6)
	return _stun_total > e and _t - _stun_from >= e - 1e-4


func _rules() -> RingRules:
	if virtual or not RingRules.stock_on():
		return null
	return RingRules.current()


## The fallback's stun clock (no stock RingRules: BendKnock.stun_t counted down here; a new stun seen as it rises) and the
## escape's tick on his own ears.
func _track_stun(stun: bool, dt: float) -> void:
	if virtual:
		if _vstun > 0.0:
			_vstun = maxf(_vstun - dt, 0.0)
		return
	var kn := BendKnock.peek(body)
	if _rules() == null and kn != null:
		# (PERCENT's BendKnock.stun_t counts itself down in physics time: only a new stun is seen here, never written)
		var st := kn.stun_t
		if st > _last_stun_t + 1e-4:
			_stun_from = _t
			_stun_total = st
		_last_stun_t = st
		if kn.lying_t > 0.0:
			kn.lying_t = maxf(kn.lying_t - dt, 0.0)
	if stun and not _tick_told and _can_escape():
		_tick_told = true
		if looks != null:
			looks.escape_tick()
	if looks != null:
		looks.whoosh(stun)


## A press in hitstun: the escape when it is open (a fresh press at escape_s or later), else the one buffered press.
func _press_in_stun(kind: String, dir: Vector3) -> void:
	if _can_escape():
		_end_stun()
		if kind == "jump":
			_air_jump() if _air else _ground_jump(false)
		elif kind == "dodge" and _air and dodge_ready:
			_start_dodge(dir)
		return
	_buffer = kind
	_buffer_dir = dir


func _end_stun() -> void:
	if virtual:
		_vstun = 0.0
		return
	var r := _rules()
	if r != null and r.has_method(&"escape"):
		r.call(&"escape", body)
	var kn := BendKnock.peek(body)
	if kn != null:
		kn.stun_t = 0.0
		_last_stun_t = 0.0
	_was_stun = false
	if looks != null:
		looks.whoosh(false)


## Hitstun's first free frame: the buffered press fires.
func _on_free() -> void:
	_tick_told = false
	var b := _buffer
	_buffer = ""
	if b == "jump":
		if _air:
			if _helpless:
				_spent()
			else:
				_o = _read_own()
				_air_jump()
				_write_own()
		elif _lag <= 0.0:
			_o = _read_own()
			_ground_jump(false)
			_write_own()
	elif b == "dodge" and _air and dodge_ready and mode == "":
		_o = _read_own()
		_start_dodge(_buffer_dir)
		_write_own()


func _write_own() -> void:
	if virtual:
		return
	var kn := BendKnock.peek(body)
	var ap := kn.applied if kn != null else Vector3.ZERO
	body.velocity = Vector3(_o.x + ap.x, _o.y, _o.z + ap.z)


func _tumbling() -> bool:
	if virtual:
		return false
	var kn := BendKnock.peek(body)
	return kn != null and kn.tumble


## E while tumbling: a try at breaking the fall (PERCENT judges it at contact).
func _press_break() -> void:
	var kn := BendKnock.peek(body)
	if kn != null:
		kn.press_break(_move_vec())


func _lying() -> bool:
	if virtual:
		return false
	var kn := BendKnock.peek(body)
	return kn != null and kn.lying_t > 0.0


## The knock's bounce off the deck (BendKnock's, a missed fall falling fast) seen as it happens: its clip (knock_bounce).
func _track_bounce() -> void:
	if virtual or body == null:
		return
	var kn := BendKnock.peek(body)
	var bb := kn != null and bool(kn.get(&"_bounced"))
	if bb and not _kn_bounced:
		_bounce_at = _t
		_spiked = false
	_kn_bounced = bb


func _on_launched(v: Vector3, hitstun_s: float, refresh: bool) -> void:
	_spiked = v.y < -num("hitstun", "spike_vy", 4.0)
	if refresh:
		_refresh()
	_launch_dir = Vector3(v.x, 0.0, v.z)
	_di_at = _t + num("hitstun", "di_read_s", 0.1)
	if _rules() == null:
		_stun_from = _t
		_stun_total = hitstun_s
	_tick_told = false
	if v.y > 0.0:
		_air = true


## Any knock that got through (can_take: not intangible): off the edge and out of any move; his own run gone (the knock sets
## the motion).
func _on_knocked(v: Vector3, _by: Node) -> void:
	if mode in LEDGE_MODES:
		_unhang()
		_regrab_until = _t + num("edge", "regrab_s", 0.4)
	if mode != "" and mode != "lie":
		_set_mode("", {})
	_ff = false
	_glide = false
	_crouch_to(false)
	if not virtual and body != null:
		var kn := BendKnock.peek(body)
		var ap := kn.applied if kn != null else Vector3.ZERO
		body.velocity.x = ap.x
		body.velocity.z = ap.z
	if v.y > 0.0:
		_air = true


## The steer read di_read_s after the launch: the held keys (flat, world) to BendKnock.apply_di; the body leans toward the
## held side for lean_s.
func _read_di() -> void:
	_di_at = INF
	var di := _v3("di")
	di.y = 0.0
	var kn := BendKnock.peek(body) if not virtual else null
	if kn != null:
		kn.apply_di(di)
	if di.length() > 0.1 and _launch_dir.length() > 0.1:
		var side := _launch_dir.normalized().cross(di.normalized()).y
		_lean = clampf(-side * 1.5, -1.0, 1.0)
		_lean_until = _t + num("hitstun", "lean_s", 0.3)


## The steer's lean now: x the roll toward the held side (-1..1), y the twist.
func lean() -> Vector2:
	if _t >= _lean_until:
		return Vector2.ZERO
	var k := clampf((_lean_until - _t) / maxf(num("hitstun", "lean_s", 0.3), 0.01), 0.0, 1.0)
	var w := sin(k * PI)
	return Vector2(_lean * w, _lean * w)


## PERCENT's broken fall: "stand" (intangible, up at once), "roll" (2.5 m, never off the lip), "wall" (stick, spring off).
func _on_broke_fall(kind: String, dir: Vector3) -> void:
	_ff = false
	match kind:
		"stand":
			_set_mode("", {})
			_air = false
			_o = Vector3.ZERO
			_int_from = _t
			_int_until = _t + num("break_fall", "stand_intangible_s", 0.25)
			_tech_at = _t
		"roll":
			var d := Vector3(dir.x, 0.0, dir.z)
			_air = false
			_start_roll("break_roll", d.normalized() if d.length() > 0.05 else Vector3.ZERO, num("break_fall", "roll_m", 2.5),
					num("break_fall", "roll_s", 0.4), [0.0, num("break_fall", "roll_intangible_s", 0.25)], 0.0)
		"wall":
			_set_mode("wall", {"len": num("break_fall", "wall_stick_s", 0.1), "pos": _pos()})
	moved.emit("break_fall")


func _step_wall(dt: float) -> void:
	mode_t += dt
	_set_pos(Vector3(_m.pos))
	_o = Vector3.ZERO
	_zero_vel()
	if mode_t >= float(_m.len):
		_set_mode("", {})
		_o = Vector3.UP * num("break_fall", "wall_vy", 3.0)
		_air = true
		_apply(dt)


## Lying (PERCENT's lying_t): still; W or Space (any direction without E) stands, E + a direction rolls, a click attacks.
func _step_lie(dt: float) -> void:
	mode_t += dt
	if _air and _grounded():
		_land()                                      # (down on the deck: not in the air while he lies there)
	_o = Vector3(0.0, minf(_o.y, 0.0) - gravity() * dt, 0.0)
	_apply(dt)
	if not _lying():
		_set_mode("", {})
		_getup_at = _t
		return
	var mv := _move_vec()
	var guard := _b("guard_pressed") or _b("guard_held")
	if _b("attack"):
		_getup("attack")
		_set_mode("getup_attack", {"len": num("getup", "attack_s", 0.6), "int": [0.0, num("getup", "attack_intangible_s", 0.25)],
				"struck": false})
	elif guard and mv.length() > 0.3:
		_getup("roll")
		_start_roll("getup_roll", mv.normalized(), num("getup", "roll_m", 2.5), num("getup", "roll_s", 0.4),
				[0.0, num("getup", "roll_intangible_s", 0.3)], 0.0)
	elif _b("jump") or (mv.length() > 0.3 and not guard):
		_getup("stand")
		_set_mode("", {})
		_int_from = _t
		_int_until = _t + num("getup", "stand_intangible_s", 0.3)
		_getup_at = _t


func _getup(kind: String) -> void:
	var kn := BendKnock.peek(body)
	if kn == null:
		return
	kn.getup(kind)
	kn.lying_t = 0.0                            # (cleared by PERCENT's getup; by hand while it is a stub)


func _step_getup_attack(dt: float) -> void:
	mode_t += dt
	_o = Vector3(0.0, minf(_o.y, 0.0) - gravity() * dt, 0.0)
	_apply(dt)
	if not bool(_m.get("struck", false)) and mode_t >= num("getup", "attack_strike_s", 0.25):
		_m.struck = true
		var r := num("getup", "attack_r", 1.6)
		for n in _bodies():
			var q := (n as Node3D).global_position
			var off := q - _pos()
			if Vector2(off.x, off.z).length() <= r and absf(off.y) < 1.5:
				var away := Vector3(off.x, 0.0, off.z).normalized() if Vector2(off.x, off.z).length() > 0.05 else -body.global_basis.z
				_hit(n, String(block("getup").get("tag", "getup/attack")), num("getup", "d", 5.0), away,
						num("getup", "set_mps", 5.0), num("getup", "angle_deg", 20.0))
	if mode_t >= float(_m.len):
		_set_mode("", {})


# ---------------------------------------------------------------- the edge
## The grab (spec §5.3): the head in the box, falling (vy <= grab_vy), not in hitstun, C not held, not just let go, a Rise
## past its startup + rise_grab_after_s, fewer than grab_limit grabs since the deck, the spot not held by another.
func _try_grab() -> bool:
	if not _air or _stunned() or _b("down_held") or _t < _regrab_until:
		return false
	if mode == "rise":
		if mode_t < float(_m.get("startup", 0.0)) + num("edge", "rise_grab_after_s", 0.2):
			return false
	elif mode != "":
		return false
	if _o.y > num("edge", "grab_vy", 1.0):
		return false
	if _grabs >= int(num("edge", "grab_limit", 3.0)):
		return false
	var g := _geo()
	if g.is_empty():
		return false
	var head := _pos() + Vector3.UP * num("edge", "head_m", 1.6)
	var lip := _lip(g, head)
	var out := float(lip.out_m)
	var dy := head.y - _lip_y(g)
	if out < -num("edge", "box_in_m", 0.3) or out > num("edge", "box_out_m", 0.9):
		return false
	if dy < num("edge", "box_low_m", -0.5) or dy > num("edge", "box_high_m", 0.6):
		return false
	var spot := _grab_spot(g, lip)
	if _occupied(spot.point):
		return false
	_grabs += 1
	_hang_at(spot)
	moved.emit("grab")
	return true


## The lip point a grab takes: the nearest, slid corner_m along its side off a corner.
func _grab_spot(g: Dictionary, lip: Dictionary) -> Dictionary:
	var xf: Transform3D = g.xf
	var lp := _local(g, Vector3(lip.point))
	var c := num("edge", "corner_m", 0.5)
	var side := int(lip.side)
	if side <= RingArena.LIP_END_1:
		lp.z = clampf(lp.z, -float(g.hw) + c, float(g.hw) - c)
		lp.x = float(g.hl) * (1.0 if side == RingArena.LIP_END_1 else -1.0)
	else:
		lp.x = clampf(lp.x, -float(g.hl) + c, float(g.hl) - c)
		lp.z = float(g.hw) * (1.0 if side == RingArena.LIP_LONG_POS else -1.0)
	lp.y = float(g.top)
	return {"point": xf * lp, "normal": Vector3(lip.normal), "side": side}


## Another hanger holds the lip within occupy_m of `point`.
func _occupied(point: Vector3) -> bool:
	if virtual:
		return false
	var me := body.get_instance_id() if body != null else 0
	for id: int in _hangers.keys():
		if id == me:
			continue
		var o: Object = instance_from_id(id)
		if o == null or not is_instance_valid(o):
			_hangers.erase(id)
			continue
		var p: Vector3 = (_hangers[id] as Dictionary).point
		if Vector2(p.x - point.x, p.z - point.z).length() <= num("edge", "occupy_m", 1.2) + 1e-3:
			return true
	return false


## Hanging at `spot`: snapped (feet snap_feet_m under the lip, snap_out_m off its face, facing the deck), still, every air
## move back, the first grab since the deck safe for first_safe_s (a regrab not), the spot held.
func _hang_at(spot: Dictionary) -> void:
	var n: Vector3 = spot.normal
	var feet: Vector3 = Vector3(spot.point) + n * num("edge", "snap_out_m", 0.35) + Vector3.UP * num("edge", "snap_feet_m", -2.0)
	_set_pos(feet)
	_o = Vector3.ZERO
	_zero_vel()
	_scale_carry(0.0)
	if not virtual:
		var kn := BendKnock.peek(body)
		if kn != null:
			kn.reset()
	else:
		_vkv = Vector3.ZERO
	_refresh()
	_ff = false
	_glide = false
	_air = true
	var safe := num("edge", "first_safe_s", 0.6) if _first_safe else 0.0
	_first_safe = false
	_hang_safe_until = _t + safe
	if not virtual and body != null:
		_hangers[body.get_instance_id()] = {"point": Vector3(spot.point), "side": int(spot.side)}
	_set_mode("hang", {"point": Vector3(spot.point), "normal": n, "side": int(spot.side), "feet": feet})
	_turning = false
	_turn_off = false


func _unhang() -> void:
	if body != null and is_instance_valid(body):
		_hangers.erase(body.get_instance_id())


## Hanging: held at the snap; after settle_s an option (deck-relative: any direction key climbs, E rolls in, Space jumps, a
## click attacks, only C lets go; a bot's pad says it by name); dropped at hang_s.
func _step_hang(dt: float) -> void:
	mode_t += dt
	_set_pos(Vector3(_m.feet))
	_o = Vector3.ZERO
	_zero_vel()
	if mode_t >= num("edge", "hang_s", 4.0):
		_drop()
		return
	if mode_t < num("edge", "settle_s", 0.15) - 1e-4:
		return
	var opt := ""
	var lg: Variant = _it.get("ledge", "")
	if lg is String:
		opt = String(lg)
	elif lg is bool and bool(lg):
		opt = "climb"
	if opt == "":
		if _b("fast_fall") or _b("down_held"):
			opt = "drop"
		elif _b("jump"):
			opt = "jump"
		elif _b("guard_pressed"):
			opt = "roll"
		elif _b("attack"):
			opt = "attack"
		elif _move_vec().length() > 0.3 or _v3("fresh_dir").length() > 0.1:
			opt = "climb"
	match opt:
		"drop":
			_drop()
		"jump":
			_ledge_jump(dt)
		"roll":
			_ledge_move("ledge_roll", block("edge").get("roll", {}))
		"attack":
			_ledge_move("ledge_attack", block("edge").get("attack", {}))
		"climb":
			_ledge_move("climb", block("edge").get("climb", {}))


## Let go (C, or the time): the safety ends, no regrab for regrab_s, every air move kept.
func _drop() -> void:
	_unhang()
	_hang_safe_until = _t
	_regrab_until = _t + num("edge", "regrab_s", 0.4)
	_set_mode("", {})
	_o = Vector3.ZERO


func _ledge_jump(dt: float) -> void:
	var j: Dictionary = block("edge").get("jump", {})
	var n: Vector3 = _m.normal
	_unhang()
	_set_mode("", {})
	_o = -n * float(j.get("in_mps", 2.0)) + Vector3.UP * float(j.get("vy", 11.8))
	_air = true
	var w: Array = j.get("intangible", [0.0, 0.12])
	_int_from = _t + float(w[0])
	_int_until = _t + float(w[1])
	_regrab_until = _t + float(j.get("regrab_s", 0.4))
	_ledge_jump_at = _t
	_hang_safe_until = _t
	moved.emit("ledge_jump")
	_apply(dt)


## Climb, roll in or the edge attack: owned from the hang up over the lip to `in_m` inside, its intangible window.
func _ledge_move(kind: String, spec: Dictionary) -> void:
	var n: Vector3 = _m.normal
	var point: Vector3 = _m.point
	var from := _pos()
	var to := point - n * float(spec.get("in_m", 0.6)) + Vector3.UP * 0.02
	_unhang()
	_hang_safe_until = _t
	_set_mode(kind, {"from": from, "to": to, "normal": n, "point": point, "len": float(spec.get("s", 0.5)),
			"int": spec.get("intangible", [0.0, 0.35]), "struck": false, "spec": spec})
	moved.emit(kind)


func _step_ledge_move(dt: float) -> void:
	mode_t += dt
	var k := clampf(mode_t / maxf(float(_m.len), 0.01), 0.0, 1.0)
	var from: Vector3 = _m.from
	var to: Vector3 = _m.to
	var n: Vector3 = _m.normal
	var point: Vector3 = _m.point
	# up the face first (to the lip, just off its face), then in over the deck
	var lip_out := point + n * 0.32
	var up_k := smoothstep(0.0, 0.5, k)
	var in_k := smoothstep(0.4, 1.0, k)
	var y := lerpf(from.y, to.y, up_k)
	var flat_from := Vector3(from.x, 0.0, from.z).lerp(Vector3(lip_out.x, 0.0, lip_out.z), up_k)
	var flat := flat_from.lerp(Vector3(to.x, 0.0, to.z), in_k)
	_set_pos(Vector3(flat.x, y, flat.z))
	_o = Vector3.ZERO
	_zero_vel()
	if mode == "ledge_attack" and not bool(_m.struck) and mode_t >= float((_m.spec as Dictionary).get("strike_s", 0.3)):
		_m.struck = true
		_edge_attack_hit()
	if k >= 1.0:
		_set_mode("", {})
		_air = false
		_land()
		_o = Vector3(0.0, -0.5, 0.0)
		_apply(dt)


## The edge attack's low sweep: reach_m in from the lip, half_w_m along it, up to up_m over the deck: edge/attack, a set
## knock away from the lip at its angle.
func _edge_attack_hit() -> void:
	var a: Dictionary = (_m.spec as Dictionary)
	var n: Vector3 = _m.normal
	var point: Vector3 = _m.point
	var along := Vector3.UP.cross(n).normalized()
	var g := _geo()
	var ly := _lip_y(g)
	for b in _bodies():
		var q := (b as Node3D).global_position
		var rel := q - point
		var inn := -rel.dot(n)
		if inn < -0.3 or inn > float(a.get("reach_m", 2.0)) or absf(rel.dot(along)) > float(a.get("half_w_m", 1.2)):
			continue
		if q.y < ly - 2.5 or q.y > ly + float(a.get("up_m", 1.2)):
			continue
		_hit(b, String(a.get("tag", "edge/attack")), float(a.get("d", 7.0)), -n, float(a.get("set_mps", 6.0)),
				float(a.get("angle_deg", 20.0)))


# ---------------------------------------------------------------- the Rise
func _start_rise() -> void:
	var el := _el()
	var r := rise_of(el)
	rise_ready = false
	_ff = false
	_glide = false
	var spec := {"el": el, "kind": String(r.get("kind", "up")), "startup": float(r.get("startup_s", 0.1)),
			"dur": float(r.get("s", 0.5)), "m": float(r.get("m", 4.0)), "drift": float(r.get("drift", 1.0)),
			"start": _pos(), "hit": {}, "dir": Vector3.UP, "r": r}
	_set_mode("rise", spec)
	if looks != null:
		looks.rise_tell(el, _pos(), _tell_point())
	moved.emit("rise")
	_check_exhale()


## Where the Rise's tell shows above the lip: over the lip point nearest the body.
func _tell_point() -> Vector3:
	var g := _geo()
	if g.is_empty():
		return _pos()
	var lip := _lip(g, _pos())
	return Vector3(lip.point)


## The Rise's travel way, fixed as the startup ends: the Pillar leaning lean_deg toward the nearest lip, the Jet along the
## aim (pitch floored at pitch_floor_deg), the others up.
func _rise_dir() -> Vector3:
	var kind := String(_m.kind)
	var r: Dictionary = _m.r
	var g := _geo()
	if kind == "pillar":
		var lean := deg_to_rad(float(r.get("lean_deg", 20.0)))
		var to := Vector3.ZERO
		if not g.is_empty():
			var lip := _lip(g, _pos())
			to = Vector3(lip.point) - _pos()
			to.y = 0.0
		if to.length() < 0.05:
			return Vector3.UP
		return (Vector3.UP * cos(lean) + to.normalized() * sin(lean)).normalized()
	if kind == "jet":
		var aim := _v3("aim")
		if aim.length() < 0.1:
			# (no aim given: toward the nearest lip at 45 degrees)
			var to2 := Vector3.FORWARD
			if not g.is_empty():
				to2 = Vector3(_lip(g, _pos()).point) - _pos()
			to2.y = 0.0
			aim = (to2.normalized() + Vector3.UP).normalized() if to2.length() > 0.05 else Vector3.UP
		aim = aim.normalized()
		var floor_rad := deg_to_rad(float(r.get("pitch_floor_deg", 20.0)))
		var flat := Vector3(aim.x, 0.0, aim.z)
		var pitch := asin(clampf(aim.y, -1.0, 1.0))
		if pitch < floor_rad:
			var f := flat.normalized() if flat.length() > 1e-3 else Vector3.FORWARD
			aim = (f * cos(floor_rad) + Vector3.UP * sin(floor_rad)).normalized()
		return aim
	return Vector3.UP


func _step_rise(dt: float) -> void:
	var prev := mode_t
	mode_t += dt
	var kind := String(_m.kind)
	var startup := float(_m.startup)
	var dur := float(_m.dur)
	var r: Dictionary = _m.r
	var el := String(_m.el)
	var ending := false
	if mode_t < startup:
		if kind == "jet":
			_o = Vector3.ZERO                        # (the hover: held in place, its roar the tell)
		elif kind == "pillar":
			_o.y = 0.0
		else:
			_air_physics(dt, false, 1.0)
	else:
		if not _m.has("way"):
			_m.way = _rise_dir()
		var sp := float(_m.m) / dur
		# (this frame's share of the travel window, so the lift is its m exactly)
		var frac := clampf((minf(mode_t, startup + dur) - maxf(prev, startup)) / dt, 0.0, 1.0)
		var way: Vector3 = _m.way
		var d := drift_of(el)
		match kind:
			"pillar":
				_o = way * sp * frac + _move_vec() * d.x * float(_m.drift) * frac
			"jet":
				_o = way * sp * frac
			_:
				var flat := Vector3(_o.x, 0.0, _o.z).move_toward(_move_vec() * d.x * float(_m.drift), d.y * dt)
				_o = Vector3(flat.x, sp * frac, flat.z)
		_rise_hits()
		ending = mode_t >= startup + dur - 1e-6
	_apply(dt)
	if ending:
		_end_rise()
		_write_own()
	if mode == "rise" or _t - _rise_end_at <= num("rise", "scramble_after_s", 0.1) + 1e-4:
		if _try_scramble():
			return
	if mode == "rise":
		if _grounded() and mode_t > startup + 0.05:
			_set_mode("", {})
			_helpless = true
			_land()
			return
		_try_grab()


func _end_rise() -> void:
	var kind := String(_m.kind)
	var r: Dictionary = _m.r
	var el := String(_m.el)
	_set_mode("", {})
	_helpless = true
	_rise_end_at = _t
	# (helpless from here: his own flat speed no more than the helpless drift, the Pillar's its own share; the Jet's burst
	# does not carry on past its 7.5 m)
	var cap := drift_of(el).x * num("rise", "helpless_drift", 0.6)
	if kind == "pillar":
		_o.y = float(r.get("end_vy", 3.0))
		cap = minf(cap, drift_of(el).x * float(r.get("drift", 0.3)))
	else:
		_o.y = minf(_o.y, float(r.get("end_vy", 2.0)))
	var flat := Vector3(_o.x, 0.0, _o.z).limit_length(cap)
	_o.x = flat.x
	_o.z = flat.z
	if kind == "updraft":
		_glide = true
	if looks != null:
		looks.rise_end(el, _pos())
	_check_exhale()


## The scramble: a Rise meeting the deck's face (during it or scramble_after_s after) with the head no more than
## scramble_m under the grab box slides up the face to the hang in scramble_s; it counts as a grab.
func _try_scramble() -> bool:
	if _grabs >= int(num("edge", "grab_limit", 3.0)) or _b("down_held"):
		return false
	var g := _geo()
	if g.is_empty():
		return false
	var p := _pos()
	var ly := _lip_y(g)
	if p.y >= ly - 0.05:
		return false
	var lip := _lip(g, p)
	var out := float(lip.out_m)
	if out > num("rise", "face_m", 0.4) or out < -0.05:
		return false
	var head := p.y + num("edge", "head_m", 1.6)
	if head < ly + num("edge", "box_low_m", -0.5) - num("rise", "scramble_m", 2.0) - 1e-3:
		return false
	var spot := _grab_spot(g, lip)
	if _occupied(spot.point):
		return false
	_grabs += 1
	var n: Vector3 = spot.normal
	var feet: Vector3 = Vector3(spot.point) + n * num("edge", "snap_out_m", 0.35) + Vector3.UP * num("edge", "snap_feet_m", -2.0)
	_set_mode("scramble", {"from": p, "feet": feet, "spot": spot, "len": num("rise", "scramble_s", 0.3)})
	_helpless = false
	moved.emit("scramble")
	return true


func _step_scramble(dt: float) -> void:
	mode_t += dt
	var k := clampf(mode_t / maxf(float(_m.len), 0.01), 0.0, 1.0)
	var from: Vector3 = _m.from
	var feet: Vector3 = _m.feet
	_set_pos(from.lerp(feet, smoothstep(0.0, 1.0, k)))
	_o = Vector3.ZERO
	_zero_vel()
	if k >= 1.0:
		_hang_at(_m.spot)


## The Rise's hit (its tag, a set knock), once a body: the Pillar on whoever the column rises through over him, the
## Fountain's and the Updraft's push on whoever is near, the Jet's trail on whoever it passed.
func _rise_hits() -> void:
	if virtual or body == null:
		return
	var r: Dictionary = _m.r
	var kind := String(_m.kind)
	var hit: Dictionary = _m.hit
	var hr := float(r.get("hit_r", 1.0))
	var p := _pos()
	for b: Node in _bodies():
		var id := b.get_instance_id()
		if hit.has(id):
			continue
		var q := (b as Node3D).global_position
		var off := q - p
		var flat := Vector2(off.x, off.z).length()
		var ok := false
		var away := Vector3(off.x, 0.0, off.z).normalized() if flat > 0.05 else Vector3.FORWARD
		match kind:
			"pillar":
				ok = flat <= hr and off.y > -0.5 and off.y < num("edge", "head_m", 1.6) + 1.5
			"jet":
				var a: Vector3 = _m.start
				var seg := p - a
				var u := clampf((q - a).dot(seg) / maxf(seg.length_squared(), 1e-4), 0.0, 1.0)
				ok = (a + seg * u).distance_to(q + Vector3.UP * 0.9) <= hr + 0.6
			_:
				ok = flat <= hr and absf(off.y) < 2.0
		if ok:
			hit[id] = true
			_hit(b, String(r.get("tag", "rise/up")), float(r.get("d", 3.0)), away, float(r.get("set_mps", 5.0)),
					float(r.get("angle_deg", 10.0)))


# ---------------------------------------------------------------- the spout
## On the respawn spout at `pos` for at most `max_s`: held there standing, every air move back, his camera toward the deck's
## middle and level; any move, jump, cast key or the time lets him go (left_spout).
func ride_spout(pos: Vector3, max_s: float) -> void:
	_unhang()
	_set_mode("spout", {"pos": pos, "len": max_s})
	_set_pos(pos)
	_o = Vector3.ZERO
	_zero_vel()
	if not virtual and body != null:
		var kn := BendKnock.peek(body)
		if kn != null:
			kn.reset()
	_refresh()
	_air = true
	_ff = false
	_glide = false
	_helpless = false
	_lag = 0.0
	_grabs = 0
	_first_safe = true
	_buffer = ""
	if body is FrontierPlayer:
		var p := body as FrontierPlayer
		var g := _geo()
		var mid: Vector3 = (g.xf as Transform3D).origin if not g.is_empty() else Vector3.ZERO
		var to := mid - pos
		to.y = 0.0
		if to.length() > 0.05:
			p.yaw = atan2(-to.x, -to.z)
			p.rotation.y = p.yaw
		p.pitch = 0.0


## Off the spout now (a key, a cast: AIR calls it before the lock starts).
func leave_spout() -> void:
	if mode != "spout":
		return
	_set_mode("", {})
	_air = true
	left_spout.emit()


func _step_spout(dt: float) -> void:
	mode_t += dt
	_set_pos(Vector3(_m.pos))
	_o = Vector3.ZERO
	_zero_vel()
	var go := _move_vec().length() > num("spout", "leave_move", 0.3) or _b("cast") or _b("attack") or _b("guard_pressed") \
			or _b("dodge") or mode_t >= float(_m.len)
	if _b("jump"):
		leave_spout()
		_ground_jump(false)
		_air = true
		_apply(dt)
		return
	if go:
		leave_spout()


# ---------------------------------------------------------------- after the frame: the looks, the layers, the camera
func _post(dt: float) -> void:
	_set_layers(intangible())
	if virtual:
		return
	_check_exhale_air()
	if body is NpcFighter:
		var y := body_yaw()
		if y != INF:
			body.rotation.y = lerp_angle(body.rotation.y, y, clampf(dt * 14.0, 0.0, 1.0))
	if body is FrontierPlayer:
		_cam_tick(dt)
	# (a stand-in's raise of the body: the hang's hands and head over the lip until its own clip)
	var vis: Node3D = (body as FrontierPlayer).visual if body is FrontierPlayer else body.get_node_or_null(^"Body") as Node3D
	if vis != null:
		vis.position.y = move_toward(vis.position.y, visual_lift(), dt * 6.0)
	if looks != null:
		looks.tick(dt)


func _check_exhale_air() -> void:
	if _air and not _exhaled and mode == "" and (_helpless or (jumps_left <= 0 and not dodge_ready and not rise_ready)):
		_check_exhale()


## The body's collision layers to 0 while intangible (a bolt's sweep then flies through him unspent; the hit parts of a
## bot's body too), put back after.
func _set_layers(off: bool) -> void:
	if virtual or body == null or not is_instance_valid(body):
		return
	if off and _layers_kept.is_empty():
		_layers_kept[body] = body.collision_layer
		body.collision_layer = 0
		var nb := body.get_node_or_null(^"Body")
		if nb != null:
			for c in nb.get_children():
				if c is StaticBody3D:
					_layers_kept[c] = (c as StaticBody3D).collision_layer
					(c as StaticBody3D).collision_layer = 0
	elif not off and not _layers_kept.is_empty():
		for o: Object in _layers_kept:
			if is_instance_valid(o):
				(o as CollisionObject3D).collision_layer = int(_layers_kept[o])
		_layers_kept.clear()


## The way the body faces now when this says (the hang and the edge's moves: the deck; INF: his own).
func body_yaw() -> float:
	if mode in LEDGE_MODES:
		var n := Vector3.ZERO
		if _m.has("normal"):
			n = _m.normal
		elif _m.has("spot"):
			n = (_m.spot as Dictionary).normal
		if n.length() > 0.1:
			return atan2(n.x, n.z)                   # (facing -normal: the deck)
	return INF


## The camera's framing wish (the player's; {} none): arm (m), pivot_up (m over the eye), pivot (world) with pivot_w (its
## share), fov with fov_w (its share); round 4 (READ) the camera variant on top (RingCamera.apply: its arm and pivot added,
## shoulder m, tilt_deg).
func cam_bias() -> Dictionary:
	if body == null or virtual or not (body is FrontierPlayer):
		return {}
	var arm := num("cam", "deck_arm", 5.25)
	var out := {"arm": arm, "pivot_up": num("cam", "deck_pivot_up", 0.3), "pivot": Vector3.ZERO, "pivot_w": 0.0, "fov": 60.0,
			"fov_w": 0.0}
	var g := _geo()
	if g.is_empty():
		return RingCamera.apply(out)
	var p := _pos()
	if _hang_w > 0.001 and mode in LEDGE_MODES:
		var pt: Vector3 = _m.get("point", (_m.get("spot", {}) as Dictionary).get("point", p))
		out.arm = lerpf(arm, num("cam", "hang_arm", 5.0), _hang_w)
		out.pivot = pt + Vector3.UP * num("cam", "hang_pivot_up", 1.0)
		out.pivot_w = _hang_w
		return RingCamera.apply(out)
	if _cam_w > 0.001:
		var chest := p + Vector3.UP * num("cam", "chest_m", 1.3)
		var lp := Vector3(_lip(g, chest).point)
		var dist := chest.distance_to(lp)
		var off_arm := clampf(num("cam", "off_base", 4.1) + num("cam", "off_k", 0.6) * dist, num("cam", "off_min", 5.25),
				num("cam", "off_max", 8.0))
		out.arm = lerpf(arm, off_arm, _cam_w)
		out.pivot = (chest + lp) * 0.5
		out.pivot_w = _cam_w
		out.fov = num("cam", "fov_far", 65.0) if dist > num("cam", "far_m", 4.0) else num("cam", "fov", 60.0)
		out.fov_w = _cam_w
	return RingCamera.apply(out)


func _cam_tick(dt: float) -> void:
	var off := (off_deck() and _air and not mode in LEDGE_MODES and mode != "spout")
	var hang := mode in LEDGE_MODES
	var cin := maxf(num("cam", "in_s", 0.35), 0.01)
	var cout := maxf(num("cam", "out_s", 0.5), 0.01)
	_cam_w = move_toward(_cam_w, 1.0 if off else 0.0, dt / (cin if off else cout))
	_hang_w = move_toward(_hang_w, 1.0 if hang else 0.0, dt / (cin if hang else cout))


## The player moved his mouse: the recovery turn stops for the rest of the airtime (if it was turning) and the still timer
## starts again.
func note_mouse() -> void:
	_mouse_at = _t
	if _turning:
		_turning = false
		_turn_off = true


## The recovery turn's yaw step (radians to add to `yaw`; 0 none; owner: yes, movement.json cam.recover_turn): off the deck,
## out of hitstun, the lip more than turn_beyond_deg from the view and the mouse still mouse_still_s: toward the lip at up
## to turn_dps until it is within turn_until_deg. Pitch never moves.
func cam_yaw_step(yaw: float, dt: float) -> float:
	if body == null or virtual or not bool(block("cam").get("recover_turn", true)):
		return 0.0
	if not (off_deck() and _air) or mode in LEDGE_MODES or mode == "spout" or _stunned() or _turn_off:
		_turning = false
		return 0.0
	var g := _geo()
	if g.is_empty():
		return 0.0
	var to := Vector3(_lip(g, _pos()).point) - _pos()
	to.y = 0.0
	if to.length() < 0.2:
		return 0.0
	var want := atan2(-to.x, -to.z)
	var diff := wrapf(want - yaw, -PI, PI)
	var ad := rad_to_deg(absf(diff))
	if not _turning:
		if ad > num("cam", "turn_beyond_deg", 100.0) and _t - _mouse_at >= num("cam", "mouse_still_s", 0.25):
			_turning = true
		else:
			return 0.0
	if ad <= num("cam", "turn_until_deg", 60.0):
		_turning = false
		return 0.0
	var dps := minf(num("cam", "turn_dps", 120.0), num("cam", "turn_k", 4.0) * ad)
	var step := deg_to_rad(dps) * dt
	return signf(diff) * minf(step, absf(diff))


## Turning the camera toward the lip now (the recovery turn).
func cam_turning() -> bool:
	return _turning


# ---------------------------------------------------------------- the body-state clip
## The body-state clip's key in movement.json clips now ("" none: the body's own locomotion and casts).
func clip_state() -> String:
	match mode:
		"hang":
			return "edge_grab" if mode_t < num("edge", "settle_s", 0.15) else "edge_hang"
		"climb":
			return "edge_climb"
		"ledge_roll":
			return "edge_roll"
		"ledge_attack":
			return "edge_attack"
		"scramble":
			return "edge_scramble"
		"roll":
			return _roll_clip()
		"duck":
			return "duck"
		"dodge":
			return "air_dodge"
		"rise":
			return "rise_" + String(_m.el)
		"lie":
			return "lie"
		"getup_roll":
			return "getup_roll_l" if _side_of(Vector3(_m.dir)) < 0.0 else "getup_roll"
		"getup_attack":
			return "getup_attack"
		"break_roll":
			return "tech_roll_l" if _side_of(Vector3(_m.dir)) < 0.0 else "tech_roll"
		"wall":
			return "tech_wall"
		"spout":
			return "spout_ride"
	if _stunned():
		if _tumbling() or (_air and not _grounded()):
			if _spiked:
				return "knock_spiked"
			if _t - _bounce_at < num("hitstun", "bounce_clip_s", 0.45):
				return "knock_bounce"
			return "tumble"
		return "flinch"
	if _t - _tech_at < num("break_fall", "stand_s", 0.25):
		return "tech"
	if _t - _getup_at < num("getup", "stand_s", 0.3):
		return "getup"
	if _t - _ledge_jump_at < 0.4 and _air:
		return "edge_jump"
	if _air:
		if _helpless:
			return "helpless"
		if _ff:
			return "fall_fast"
		if _t - _dj_at < 0.35:
			return "double_jump"
		if _o.y < -1.5 and _t - _jump_at > 0.25:
			return "fall"
		return ""
	if _lag > 0.0:
		return "land_heavy" if _lag_heavy else "land_light"
	if _teetering:
		return "teeter"
	return ""


func _roll_clip() -> String:
	var d: Vector3 = _m.dir
	var f := -body.global_basis.z if body != null else Vector3.FORWARD
	var fwd := d.dot(f)
	var side := _side_of(d)
	if absf(fwd) >= absf(side):
		return "roll_f" if fwd >= 0.0 else "roll_b"
	return "roll_side" if side > 0.0 else "roll_side_l"


## How far `d` points to the body's right (+) or left (-).
func _side_of(d: Vector3) -> float:
	if body == null:
		return 0.0
	return d.dot(body.global_basis.x)


## The clip spec for state `key` (movement.json clips): {clip, standin, loop, mask, lift_m}.
static func clip_spec(key: String) -> Dictionary:
	var c: Variant = block("clips").get(key, {})
	return c if c is Dictionary else {}


## The clip to play for state `key`: its own when it is in (BendPoses), else its stand-in's (and that one's own stand-in),
## "" none; and whether it is the stand-in.
static func clip_for(key: String) -> Array:
	var spec := clip_spec(key)
	var nm := String(spec.get("clip", ""))
	if nm != "" and BendPoses.animation(nm) != null:
		return [nm, false]
	var sub := String(spec.get("standin", ""))
	var depth := 0
	while sub != "" and depth < 3:
		if BendPoses.animation(sub) != null:
			return [sub, true]
		var nxt := ""
		for k: String in block("clips"):
			if String(clip_spec(k).get("clip", "")) == sub:
				nxt = String(clip_spec(k).get("standin", ""))
				break
		sub = nxt
		depth += 1
	return ["", true]


## The body's raise while a stand-in plays a state with lift_m (the hang's hands and head over the lip until its clip).
func visual_lift() -> float:
	var st := clip_state()
	if st == "":
		return 0.0
	var spec := clip_spec(st)
	if not spec.has("lift_m"):
		return 0.0
	var c := clip_for(st)
	if not bool(c[1]):
		return 0.0
	if st == "edge_scramble":
		return float(spec.lift_m) * clampf(mode_t / maxf(float(_m.get("len", 0.3)), 0.01), 0.0, 1.0)
	return float(spec.lift_m)


# ---------------------------------------------------------------- the player's keys
## The player's intent this frame from his keys (FrontierPlayer.controls: Space, W/A/S/D camera-relative, C or Ctrl, E,
## Shift, LMB, the cast keys).
func intent_from_keys() -> Dictionary:
	if body == null or not (body is FrontierPlayer):
		return {}
	var p := body as FrontierPlayer
	var c := p.controls
	var mv := c.move_vector()
	var yb := Basis(Vector3.UP, p.yaw)
	var move := yb * Vector3(mv.x, 0.0, mv.y)
	var fresh := Vector3.ZERO
	for pair: Array in [[&"move_forward", Vector3.FORWARD], [&"move_back", Vector3.BACK], [&"move_left", Vector3.LEFT],
			[&"move_right", Vector3.RIGHT]]:
		if c.just_pressed(pair[0]):
			fresh += yb * Vector3(pair[1])
	var attack := c.just_pressed(&"fire")
	var cast := attack or c.just_pressed(&"aim")
	for k: StringName in [&"weapon_1", &"weapon_2", &"weapon_4", &"weapon_5"]:
		cast = cast or c.just_pressed(k)
	var aim := -p.camera.global_basis.z if p.camera != null else -p.global_basis.z
	return {"move": move.limit_length(1.0), "jump": c.just_pressed(&"jump"), "jump_short": false, "jump_held": c.pressed(&"jump"),
			"dodge": false, "dodge_dir": move, "fast_fall": c.just_pressed(&"crouch"), "down_held": c.pressed(&"crouch"),
			"guard_held": c.pressed(InputSetup.GUARD_ACTION), "guard_pressed": c.just_pressed(InputSetup.GUARD_ACTION),
			"ledge": "", "di": move, "sprint": c.pressed(&"sprint"), "fresh_dir": fresh, "attack": attack, "cast": cast,
			"aim": aim}


func _on_cast_released(_mv: String, _md: String) -> void:
	_cast_rel_at = _t
	# (the other order: Space first, the release within hop_cast_s after: the full jump capped to the short hop's)
	if _air and mode == "" and not _jump_short and _t - _jump_at <= num("jump", "hop_cast_s", 0.05) + 1e-4:
		_jump_short = true
		var h := _pos().y - _jump_y
		var cap := sqrt(maxf(2.0 * gravity() * (num("jump", "short_apex_m", 0.8) - h), 0.0))
		if virtual:
			_o.y = minf(_o.y, cap)
		else:
			body.velocity.y = minf(body.velocity.y, cap)


# ---------------------------------------------------------------- the body's plumbing (a live body or a simulation's)
func _b(key: String) -> bool:
	var v: Variant = _it.get(key, false)
	return v is bool and bool(v)


func _v3(key: String) -> Vector3:
	var v: Variant = _it.get(key, Vector3.ZERO)
	return v if v is Vector3 else Vector3.ZERO


## The held way (flat, world, at most 1).
func _move_vec() -> Vector3:
	var m := _v3("move")
	m.y = 0.0
	return m.limit_length(1.0)


func _el() -> String:
	if virtual:
		return _vel_name
	var e: Variant = body.get(&"arena_element") if body is FrontierPlayer else body.get(&"element")
	var s := String(e) if e is String or e is StringName else ""
	if s in ELEMENTS:
		return s
	var b := body.get_node_or_null(NodePath(String(Bending.NODE_NAME))) if body != null else null
	if b != null and String(b.get(&"element")) in ELEMENTS:
		return String(b.get(&"element"))
	return "water"


func _dead() -> bool:
	if body is FrontierPlayer:
		return (body as FrontierPlayer).is_dead
	if body is NpcFighter:
		return (body as NpcFighter).is_dead()
	return false


## The body's own speed cap (a root, the countdown, a floor cast; a bot's feet held or held still).
func _speed_cap() -> float:
	if virtual:
		return INF
	if body is FrontierPlayer:
		var p := body as FrontierPlayer
		return minf(p.drag_speed_cap, p.bend_speed_cap)
	if body is NpcFighter:
		var f := body as NpcFighter
		return 0.0 if f.feet_held or f.held else INF
	return INF


func _dashing() -> bool:
	if virtual or body == null:
		return false
	var bm := body.get_node_or_null(^"BendMotion") as BendMotion
	return bm != null and bm.carrying()


func _crouch_to(on: bool) -> void:
	if on == _crouch:
		return
	_crouch = on
	if virtual or body == null:
		return
	if body is FrontierPlayer:
		(body as FrontierPlayer).set_crouched(on)
		_crouch = (body as FrontierPlayer).is_crouching
	elif body is NpcFighter:
		(body as NpcFighter).crouch(on)


func _pos() -> Vector3:
	return _vpos if virtual else body.global_position


func _set_pos(p: Vector3) -> void:
	if virtual:
		_vpos = p
	else:
		body.global_position = p
		_last_pos = p


func _zero_vel() -> void:
	if not virtual:
		body.velocity = Vector3.ZERO


func _grounded() -> bool:
	return _vfloor if virtual else body.is_on_floor()


## The body's own velocity (the knock's carry taken out; whatever else set it this frame kept: BendMotion's dashes, a knock's
## up part).
func _read_own() -> Vector3:
	if virtual:
		return _o
	var kn := BendKnock.peek(body)
	return kn.base_of(body.velocity) if kn != null else body.velocity


## The knock's carry scaled by `k` (the double jump keeps half).
func _scale_carry(k: float) -> void:
	if virtual:
		_vkv *= k
		return
	var kn := BendKnock.peek(body)
	if kn != null:
		kn.scale_carry(k)


## The frame's move: own velocity plus the knock's decayed carry, slid (a live body) or stepped over the deck box.
func _apply(dt: float) -> void:
	if virtual:
		_vstep(dt)
		return
	var kn := BendKnock.peek(body)
	var ex := kn.extra_velocity(dt) if kn != null else Vector3.ZERO
	var corr := _g_corr
	_g_corr = 0.0
	body.velocity = Vector3(_o.x + ex.x, _o.y + corr, _o.z + ex.z)
	body.move_and_slide()
	if corr != 0.0 and not body.is_on_floor() and not body.is_on_ceiling():
		body.velocity.y -= corr
	if kn != null:
		kn.after_slide()
	_o = _read_own()


## A body moved this frame by more than physics.teleport_m (a respawn, a reset, RingLevel.place): every move state cleared.
func _teleport_check() -> void:
	if virtual:
		return
	var p := body.global_position
	if _last_pos != Vector3.INF and p.distance_to(_last_pos) > num("physics", "teleport_m", 3.0):
		placed()
	_last_pos = p


## The body was put somewhere else on purpose (a reset, a test): every move state cleared now, its place taken as its own.
## Put off the spout so, it has left it (left_spout: its spawn safety counts down from now).
func placed() -> void:
	if mode == "spout":
		leave_spout()
	_reset_state()
	_placed_n = 1
	if not virtual and body != null:
		_last_pos = body.global_position


func _reset_state() -> void:
	_unhang()
	_set_mode("", {})
	_refresh()
	_air = false
	_ff = false
	_glide = false
	_lag = 0.0
	_grabs = 0
	_first_safe = true
	_buffer = ""
	_hang_safe_until = -INF
	_int_until = -INF
	_cam_w = 0.0
	_hang_w = 0.0
	_turning = false
	_turn_off = false


## Every competitor the moves can strike (not him; can_take: not his side, not intangible).
func _bodies() -> Array:
	var out: Array = []
	if virtual or body == null or not body.is_inside_tree():
		return out
	var tree := body.get_tree()
	for n in tree.get_nodes_in_group(NpcFighter.GROUP) + tree.get_nodes_in_group(&"player"):
		if n != body and n is Node3D and not out.has(n) and BendStatus.can_take(n, body):
			out.append(n)
	return out


## One of his moves' set hits on `n` through BendStatus (tag, d % in the info; a set knock of `mps` along `away` raised by
## `angle_deg`).
func _hit(n: Node, tag: String, d: float, away: Vector3, mps: float, angle_deg: float) -> void:
	var a := deg_to_rad(angle_deg)
	var flat := Vector3(away.x, 0.0, away.z).normalized() if Vector2(away.x, away.z).length() > 1e-3 else Vector3.FORWARD
	var v := flat * mps * cos(a) + Vector3.UP * mps * sin(a)
	var info := {"tag": tag, "from": _pos(), "air": _air, "set_stun": -1.0}
	var at := (n as Node3D).global_position + Vector3.UP
	BendStatus.hurt(n, d, at, v.normalized(), body, -1.0, info)
	BendStatus.knock(n, v, body, info)


# ---------------------------------------------------------------- the deck's geometry
## The deck: {xf, hl, hw, top, water_y, tank} (geo_override, a simulation's, else the RingArena's; {} none).
func _geo() -> Dictionary:
	if not geo_override.is_empty():
		return geo_override
	if virtual:
		return _vgeo
	if _arena == null or not is_instance_valid(_arena):
		_arena = RingArena.find(body.get_tree()) if body != null and body.is_inside_tree() else null
	if _arena == null:
		return {}
	# (once a physics frame: the deck does not move within one, and the frame asks it several times)
	var fr := Engine.get_physics_frames()
	if fr == _geo_frame and not _geo_cache.is_empty():
		return _geo_cache
	var g := arena_geo(_arena)
	g["arena"] = _arena
	_geo_cache = g
	_geo_frame = fr
	return g


## RingArena `a`'s deck as a geo (its water and curtain from ring.json's stock overlay, modes.stock, when it has them:
## PERCENT's; else its own numbers).
static func arena_geo(a: RingArena) -> Dictionary:
	var st: Variant = (RingArena.data().get("modes", {}) as Dictionary).get("stock", {}) if RingArena.data().get("modes", {}) is Dictionary else {}
	var stock: Dictionary = st if st is Dictionary and RingRules.stock_on() else {}
	return {"xf": a.global_transform, "hl": a.half_l(), "hw": a.half_w(), "top": a.top(),
			"water_y": a.global_position.y + float(stock.get("water_y", RingArena.num("water_y", -6.0))),
			"tank": float(stock.get("tank_margin", RingArena.num("tank_margin", 10.0)))}


## The deck as `geo` for a deck box (tests, simulate): centre `at`, the deck_l x deck_w rectangle (ring.json) with its top at
## at.y, the water `water_down` m under it, the curtain `tank` m out.
static func box_geo(at := Vector3.ZERO, water_down := 6.0, tank := 10.0) -> Dictionary:
	return {"xf": Transform3D(Basis.IDENTITY, Vector3(at.x, 0.0, at.z)), "hl": RingArena.num("deck_l", 34.0) * 0.5,
			"hw": RingArena.num("deck_w", 14.0) * 0.5, "top": at.y, "water_y": at.y - water_down, "tank": tank}


static func _local(g: Dictionary, p: Vector3) -> Vector3:
	return (g.xf as Transform3D).affine_inverse() * p


static func _lip_y(g: Dictionary) -> float:
	if g.is_empty():
		return 0.0
	return ((g.xf as Transform3D) * Vector3(0.0, float(g.top), 0.0)).y


## The lip nearest `pos` (RingArena.nearest_lip on the arena's deck; the same geometry on a box): {point, normal, out_m, side,
## along}.
static func _lip(g: Dictionary, pos: Vector3) -> Dictionary:
	if g.has("arena") and is_instance_valid(g.arena):
		return (g.arena as RingArena).nearest_lip(pos)
	var xf: Transform3D = g.xf
	var l := xf.affine_inverse() * pos
	var hl := float(g.hl)
	var hw := float(g.hw)
	var ex := absf(l.x) - hl
	var ez := absf(l.z) - hw
	var side := RingArena.LIP_END_0
	var out_m := 0.0
	var p := Vector3(l.x, float(g.top), l.z)
	if ex <= 0.0 and ez <= 0.0:
		if ex >= ez:
			side = RingArena.LIP_END_1 if l.x > 0.0 else RingArena.LIP_END_0
			p.x = hl if side == RingArena.LIP_END_1 else -hl
		else:
			side = RingArena.LIP_LONG_POS if l.z > 0.0 else RingArena.LIP_LONG_NEG
			p.z = hw if side == RingArena.LIP_LONG_POS else -hw
		out_m = maxf(ex, ez)
	else:
		p.x = clampf(l.x, -hl, hl)
		p.z = clampf(l.z, -hw, hw)
		out_m = Vector2(maxf(ex, 0.0), maxf(ez, 0.0)).length()
		if ex >= ez:
			side = RingArena.LIP_END_1 if l.x > 0.0 else RingArena.LIP_END_0
		else:
			side = RingArena.LIP_LONG_POS if l.z > 0.0 else RingArena.LIP_LONG_NEG
	var n := Vector3(0.0, 0.0, 1.0)
	match side:
		RingArena.LIP_END_0:
			n = Vector3(-1.0, 0.0, 0.0)
		RingArena.LIP_END_1:
			n = Vector3(1.0, 0.0, 0.0)
		RingArena.LIP_LONG_NEG:
			n = Vector3(0.0, 0.0, -1.0)
	var wn := xf.basis * n
	wn.y = 0.0
	return {"point": xf * p, "normal": wn.normalized(), "out_m": out_m, "side": side,
			"along": p.z if side <= RingArena.LIP_END_1 else p.x}


## Public: the lip nearest `pos` on this body's deck ({} no deck).
func lip_near(pos: Vector3) -> Dictionary:
	var g := _geo()
	return {} if g.is_empty() else _lip(g, pos)


# ---------------------------------------------------------------- the simulation (the bots' look-ahead)
## A simulation's step over the deck box: the deck's top stands it, its four faces push it out (radius 0.3), the carry decays
## (carry_decel_air / _ground) and the hitstun counts down.
func _vstep(dt: float) -> void:
	var g := _vgeo
	var xf: Transform3D = g.xf
	var r := 0.3
	var on := _vfloor
	var dec := num("physics", "carry_decel_ground", 6.0) if on else num("physics", "carry_decel_air", 8.0)
	_vkv = _vkv.move_toward(Vector3.ZERO, dec * dt)
	var v := Vector3(_o.x + _vkv.x, _o.y + _g_corr, _o.z + _vkv.z)
	_g_corr = 0.0
	var l0 := xf.affine_inverse() * _vpos
	var lv := xf.basis.inverse() * v
	var l := l0 + lv * dt
	var top := float(g.top)
	var hl := float(g.hl)
	var hw := float(g.hw)
	var inside := absf(l.x) <= hl and absf(l.z) <= hw
	_vfloor = false
	if inside and l0.y >= top - 0.05 and l.y <= top + 0.001 and lv.y <= 0.0:
		l.y = top
		_o.y = 0.0
		_vfloor = true
	elif l.y < top - 0.02 and absf(l.x) < hl + r and absf(l.z) < hw + r:
		var px := hl + r - absf(l.x)
		var pz := hw + r - absf(l.z)
		var lo := xf.basis.inverse() * _o
		var lk := xf.basis.inverse() * _vkv
		if px < pz:
			l.x = signf(l.x) * (hl + r)
			if lo.x * signf(l.x) < 0.0:
				lo.x = 0.0
			if lk.x * signf(l.x) < 0.0:
				lk.x = 0.0
		else:
			l.z = signf(l.z) * (hw + r)
			if lo.z * signf(l.z) < 0.0:
				lo.z = 0.0
			if lk.z * signf(l.z) < 0.0:
				lk.z = 0.0
		_o = xf.basis * lo
		_vkv = xf.basis * lk
	if l.y > top + 0.05:
		_vleft = true
	_vpos = xf * l


## Where the simulation stands: "deck" (on it, having left it), "edge" (hanging, scrambling), "water" (in it, or over the
## curtain's plane at any height), "" still going.
func _vjudge() -> String:
	if mode in ["hang", "scramble"]:
		return "edge"
	var g := _vgeo
	var l := _local(g, _vpos)
	var hl := float(g.hl)
	var hw := float(g.hw)
	var tank := float(g.get("tank", 10.0))
	if absf(l.x) > hl + tank or absf(l.z) > hw + tank:
		return "water"
	if _vpos.y < float(g.water_y) and (absf(l.x) > hl or absf(l.z) > hw):
		return "water"
	if _vfloor and not _air and mode == "":
		return "deck"
	return ""


## A snapshot of the simulation for a plan: {t, pos, vel, jumps_left, dodge_ready, rise_ready, helpless, mode, free, lip
## (nearest: point, normal, out_m), lip_y, off_deck}.
func _snap() -> Dictionary:
	var g := _vgeo
	return {"t": _t, "dt": _last_dt, "pos": _vpos, "vel": _o + _vkv, "own": _o, "jumps_left": jumps_left, "dodge_ready": dodge_ready,
			"rise_ready": rise_ready, "helpless": _helpless, "mode": mode, "free": _vstun <= 0.0, "lip": _lip(g, _vpos),
			"lip_y": _lip_y(g), "off_deck": off_deck(), "dj_at": _dj_at, "air": _air}


## The bots' look-ahead (spec §9.6), the same mover on a body of numbers. `state`: {pos (feet, world), vel (own velocity),
## kv (the knock's flat carry), stun_s (hitstun left), stun_total, element, jumps_left, dodge_ready, rise_ready, helpless,
## grabs, air (default: not on the deck's top), geo (a deck from box_geo(); default the RingArena found, else the box at the
## origin)}. `plan`: a Callable(snapshot) -> intent, an Array of events [{t, ...intent keys}] (a press fires once at its t;
## move, aim and the holds stand until changed), or a String: a plan() kind toward the nearest lip. Steps of `dt` up to
## `horizon` s. Returns {result: "deck" | "edge" | "water" | "air", t, pos, helpless, used: [the moves it spent]} ({} for
## an empty state).
static func simulate(state: Dictionary, plan: Variant, dt: float, horizon: float) -> Dictionary:
	if state.is_empty() or dt <= 0.0:
		return {}
	var m := RingMoves.new()
	m.virtual = true
	m._vinit(state)
	var pl: Variant = plan
	if plan is String:
		pl = RingMoves.plan(String(plan))
	var t := 0.0
	var res := ""
	var used: Array = []
	m.moved.connect(func(k: String) -> void: used.append(k))
	var held := {}
	var fired := {}
	while t < horizon - 1e-6:
		var it := {}
		if pl is Callable:
			it = (pl as Callable).call(m._snap())
		elif pl is Array:
			it = _events_intent(pl as Array, t, held, fired)
		m.pre(it, dt)
		t += dt
		res = m._vjudge()
		if res != "":
			break
	var out := {"result": res if res != "" else "air", "t": t, "pos": m._vpos, "helpless": m._helpless, "used": used,
			"mode": m.mode}
	m.free()
	return out


func _vinit(s: Dictionary) -> void:
	var g: Variant = s.get("geo", {})
	if g is Dictionary and not (g as Dictionary).is_empty():
		_vgeo = g
	elif not geo_override.is_empty():
		_vgeo = geo_override
	else:
		var tree := Engine.get_main_loop() as SceneTree
		var a := RingArena.find(tree) if tree != null else null
		if a != null:
			_vgeo = arena_geo(a)
		else:
			_vgeo = box_geo()
	_vpos = s.get("pos", Vector3.ZERO)
	_o = s.get("vel", Vector3.ZERO)
	_vkv = s.get("kv", Vector3.ZERO)
	_vkv.y = 0.0
	_vstun = float(s.get("stun_s", 0.0))
	_stun_total = float(s.get("stun_total", _vstun))
	_stun_from = -(_stun_total - _vstun)
	_vel_name = String(s.get("element", "water"))
	jumps_left = int(s.get("jumps_left", 1))
	dodge_ready = bool(s.get("dodge_ready", true))
	rise_ready = bool(s.get("rise_ready", true))
	_helpless = bool(s.get("helpless", false))
	_grabs = int(s.get("grabs", 0))
	var l := _local(_vgeo, _vpos)
	var on := absf(l.x) <= float(_vgeo.hl) and absf(l.z) <= float(_vgeo.hw) and absf(l.y - float(_vgeo.top)) < 0.02
	_air = bool(s.get("air", not on))
	_vfloor = on and not _air
	_vleft = _air


## Events' intent at `t`: each event {t, ...} past is applied once (presses: jump, jump_short, dodge, fast_fall,
## guard_pressed, attack, cast, fresh_dir; the rest stand until changed).
static func _events_intent(evs: Array, t: float, held: Dictionary, fired: Dictionary) -> Dictionary:
	var it := {}
	for i in evs.size():
		var e: Dictionary = evs[i]
		if float(e.get("t", 0.0)) > t + 1e-6 or fired.has(i):
			continue
		fired[i] = true
		for k: String in e:
			if k == "t":
				continue
			if k in ["jump", "jump_short", "dodge", "fast_fall", "guard_pressed", "attack", "cast", "fresh_dir"]:
				it[k] = e[k]
			else:
				held[k] = e[k]
	for k: String in held:
		if not it.has(k):
			it[k] = held[k]
	return it


## A recovery plan for simulate() (spec §9.6), drifting toward the nearest lip (or `toward`, a world point) with `aim_up_m`
## over it for the Rise's aim:
##   drift       only drift
##   dj_late     the double jump once falling under the lip - 1 m (late_s later), then drift
##   dj_now      the double jump at once
##   dj_rise     the double jump at once, the Rise once falling and past rise_after_s
##   dj_rise_high  the same aimed 1 m over the lip
##   dodge_first   the air dodge toward the deck first, then dj_rise
##   lead        the lead model's order (lead_model.py: the double jump falling near the lip, the dodge more than 2 m out, the
##               Rise falling under lip - 0.5)
##   masher      Space every 60 ms, nothing held (lead_masher's newcomer)
##   idle        nothing at all
static func plan(kind: String, toward := Vector3.INF, aim_up_m := 0.0, late_s := 0.0) -> Callable:
	return func(s: Dictionary) -> Dictionary:
		var p: Vector3 = s.pos
		var lip: Dictionary = s.lip
		var to := (toward if toward != Vector3.INF else Vector3(lip.point)) - p
		var dir := Vector3(to.x, 0.0, to.z)
		dir = dir.normalized() if dir.length() > 0.05 else -Vector3(lip.normal)
		var it := {"move": dir, "aim": (dir + Vector3.UP * maxf((Vector3(lip.point).y + aim_up_m - p.y) / maxf(Vector2(to.x, to.z).length(), 0.5), 0.0)).normalized()}
		if not bool(s.free):
			it.move = Vector3.ZERO
			return it
		var vy: float = (s.own as Vector3).y
		var lip_y: float = s.lip_y
		var out := float(lip.out_m)
		var t: float = s.t
		match kind:
			"idle":
				it.move = Vector3.ZERO
			"masher":
				it.move = Vector3.ZERO
				it.aim = dir
				it.jump = fposmod(t + 1e-6, 0.06) < float(s.get("dt", 1.0 / 60.0))
			"drift":
				pass
			"dj_now":
				it.jump = int(s.jumps_left) > 0
			"dj_late":
				it.jump = int(s.jumps_left) > 0 and vy < 0.0 and p.y < lip_y - 1.0 - late_s * 6.0
			"dj_rise", "dj_rise_high":
				if int(s.jumps_left) > 0:
					it.jump = true
				elif bool(s.rise_ready) and vy < 0.0 and t - float(s.dj_at) > num("double_jump", "rise_after_s", 0.2) + 0.02:
					it.jump = true
			"dodge_first":
				if bool(s.dodge_ready):
					it.dodge = true
					it.dodge_dir = dir
				elif String(s.mode) == "" and int(s.jumps_left) > 0:
					it.jump = true
				elif String(s.mode) == "" and bool(s.rise_ready) and vy < 0.0 and t - float(s.dj_at) > 0.22:
					it.jump = true
			"lead":
				it.aim = (dir + Vector3.UP).normalized()          # (the model's Jet: 45 degrees toward the deck)
				if String(s.mode) == "":
					if int(s.jumps_left) > 0 and vy < 0.0 and out > -1.0 and p.y < lip_y + 0.5:
						it.jump = true
					elif int(s.jumps_left) == 0 and bool(s.dodge_ready) and out > 2.0 and vy < 0.0:
						it.dodge = true
						it.dodge_dir = dir
					elif int(s.jumps_left) == 0 and not bool(s.dodge_ready) and bool(s.rise_ready) and out > 0.0 and vy < 0.0 \
							and p.y < lip_y - 0.5 and t - float(s.dj_at) > 0.21:
						it.jump = true
					elif int(s.jumps_left) == 0 and bool(s.dodge_ready) and bool(s.rise_ready) and out > 0.0 and out <= 2.0 \
							and vy < 0.0 and p.y < lip_y - 0.5 and t - float(s.dj_at) > 0.21:
						it.jump = true
		return it


# ---------------------------------------------------------------- the steer's lean (an additive bone tilt, not a clip)
## The spine rolled toward the held side and twisted after the steer (SwayPose and NpcBody put one on their skeleton while a
## RingMoves is on the body).
class LeanMod extends SkeletonModifier3D:
	var moves: RingMoves
	const BONES := ["spinea", "spineb", "spinec", "spined"]

	func _process_modification() -> void:
		if moves == null or not is_instance_valid(moves):
			return
		var l := moves.lean()
		if l.length_squared() < 1e-6:
			return
		var sk := get_skeleton()
		if sk == null:
			return
		var roll := deg_to_rad(RingMoves.num("hitstun", "lean_deg", 14.0)) * l.x / float(BONES.size())
		var twist := deg_to_rad(RingMoves.num("hitstun", "twist_deg", 12.0)) * l.y / float(BONES.size())
		# (the rig faces +Z: a roll about +Z leans to the side, a twist about +Y)
		var share := Basis(Vector3.UP, twist) * Basis(Vector3.BACK, roll)
		for nm: String in BONES:
			var b := sk.find_bone(nm)
			if b >= 0:
				var g := sk.get_bone_global_pose(b)
				sk.set_bone_global_pose(b, Transform3D(share * g.basis, g.origin))


## The steer's lean put on `sk` (once; it reads `moves` each frame).
static func lean_on(sk: Skeleton3D, moves: RingMoves) -> void:
	if sk == null or moves == null:
		return
	var have := sk.get_node_or_null(^"RingLean") as LeanMod
	if have != null:
		have.moves = moves
		return
	var m := LeanMod.new()
	m.name = "RingLean"
	m.moves = moves
	sk.add_child(m)
