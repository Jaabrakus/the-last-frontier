class_name BendKnock
extends Node
## One knockback for everyone (Tidebreak, the ring sport: "knockback wins. A hit pushes the enemy back through the three
## zones, and off the edge into the water wins the round", docs/bending_design.md). The player and the bots are knocked by
## the same numbers, so a ring-out is fair: an 8 m/s knock carries either about 5.3 m on flat ground (v^2 / 2 GROUND_DECEL).
##
## A child of the knocked body (FrontierPlayer, NpcFighter), made lazily by of(body) on its first knock; peek(body) finds it
## without making one, so a body never knocked carries none and moves exactly as before. BendStatus.knock is the one entry
## (the anchor is checked there); NpcFighter.launch / shove come through it too.
##
##   kv          the knock's own horizontal velocity, kept apart from the body's steering: each frame the controller takes
##               last frame's kv out of its velocity (base_of), eases what is left toward its own wish as always, then adds
##               the decayed kv back (extra_velocity). So the player's ground_decel 18 and the bot's DECEL 7 never eat a
##               knock; it decays at GROUND_DECEL on the floor and AIR_DECEL in the air, the same for both. A wall it runs
##               into takes the part going into it (after_slide).
##   up part     added to the body's velocity.y at once (gravity takes it from there); LAUNCH_UP_MPS or more launches it:
##               launched() from the knock until it is back on the floor after leaving it (`landed` once), its floor snap
##               off meanwhile (a bot's -0.5 floor clamp and the player's clip speed caps skipped by their controllers).
##   knock_t     a reaction window (0.25 + |kv| / 20 s): a bot's steering held off while it runs; the pose layer may read
##               it (and is_launched()) for a knocked slide or an airborne clip.
##   ragdoll     a knock of ragdoll_mps or more throws the player off his feet (FrontierPlayer.knock_down: PlayerRagdoll);
##               under it he is only pushed. The ring raises ragdoll_mps.
##   rules       the ring's hook (static): an Object with knock_scale(n, v, by) -> Vector3 rescales/caps each knock first.
##   listeners   every node in group LISTENERS gets on_knocked(n, v, by) after a knock is applied (v as applied).
##   the body    its on_bend_knock(v, by) when it has one (NpcFighter: its brain told who did it, a flinch at
##               NpcFighter.FLINCH_KNOCK_MPS or more).
## ROUND 3, the % ring (smash_r3 spec v2 §2.2, §3, §14.3; PERCENT's; all of it behind the gate, RingRules.stock_on(), so with
## the gate off every line above is today's: the knock ADDS, AIR_DECEL 0.8, the ragdoll, knock_t):
##   set, not add   knock(v, by, info) with info._launch (RingRules.on_hit's launch, BendStatus passes it) SETS the motion: kv
##                  to the launch's flat part, the vertical speed to its up part (a flinch on the feet: no up part); a
##                  tumbling one launches the body (tumble). launched(v, hitstun_s, refresh) (refresh: a tumbling launch
##                  class; MOVE refreshes the air moves only then)
##   hitstun        stun_t (s left, counted in physics time from the hit; knock_t holds today's controllers' steering through
##                  it), act_left() (until he can act: the escape_s escape counted), can_escape(), escape(press_at) (a fresh
##                  press at escape_s or later ends it; a press made before then never does), end_stun()
##   the carry      decays at stock decel_air (8) in the air, decel_ground (6) on the deck; scale_carry(k) (MOVE's double jump)
##   steering       apply_di(dir) (MOVE, di_read_s after the hit, the held keys; bots the same): the part across the flight
##                  turns the carry's yaw by up to di_deg (never the pitch: steer_deg), the part against it adds
##                  di_against_decel to the decay for di_against_s
##   the fall       press_break(dir) (MOVE: each E press while tumbling) judged at the deck or a wall: a press within tech_s
##                  before contact breaks it unless one came tech_s..tech_spoil_s before (spoiled); broke_fall(kind, dir)
##                  ("stand", "roll" with a direction, "wall"), intangible tech_intangible_s. Missed on the deck: a bounce
##                  when falling faster than bounce_mps (vy x -bounce_k), then lying (lying_t: up by itself at lie_auto_s,
##                  intangible its first lie_intangible_s; getup(kind) after lie_s); missed on a wall: off at wall_miss_k
##   intangible()   a fall broken, the first of lying down, standing up (RingRules.take_ok reads it through
##                  BendStatus.take_filters)

signal landed
signal knocked(v: Vector3, by: Node)
## Round 3 (stock only): launched at `v` with `hitstun_s` of hitstun; `refresh` a tumbling launch class (MOVE refreshes the
## air moves only then).
signal launched(v: Vector3, hitstun_s: float, refresh: bool)
## Round 3 (stock only): the fall broken at contact: kind "stand", "roll" or "wall", `dir` the roll's (the wall's normal).
signal broke_fall(kind: String, dir: Vector3)

const NAME := "BendKnock"
const LISTENERS := &"bend_knock_listeners"
## m/s^2 a knock's horizontal speed decays on the floor, and in the air.
const GROUND_DECEL := 6.0
const AIR_DECEL := 0.8
## An up part this strong (m/s) or more launches the body (see above); a smaller one is only a hop for whoever takes it.
const LAUNCH_UP_MPS := 2.0
## A launch that never leaves the floor (a low ceiling, an anchor of another kind) is over after this long (s).
const LAUNCH_WAIT_S := 0.3

## The ring's knock rules (an Object with knock_scale(n, v, by) -> Vector3), or null: as given.
static var rules: Object = null
## A knock this hard (m/s) or more throws the player off his feet (the ring raises it).
static var ragdoll_mps := 9.0
## Round 3: the gravity a launched body falls by (m/s^2; 0: the world's default, as today). The stock ring sets 20.
static var gravity_override := 0.0

var body: CharacterBody3D
## The knock's horizontal velocity now (m/s), and the part of it in the body's velocity since the last extra_velocity.
var kv := Vector3.ZERO
var applied := Vector3.ZERO
## Seconds left of the knock's reaction window.
var knock_t := 0.0
## Who knocked it last, and when (BendStatus.now(), s).
var last_knocker: Node = null
var last_knock_at := -INF
## Knocks taken (for tests and the HUD).
var knocks := 0
## Round 3 (stock only): seconds of hitstun left (physics time from the hit; set: a hitstun of that length from now).
var stun_t: float:
	get:
		return maxf(_stun_end - BendStatus.now(), 0.0)
	set(value):
		_stun_from = BendStatus.now()
		_stun_len = maxf(value, 0.0)
		_stun_end = _stun_from + _stun_len
## Round 3 (stock only): thrown into the air tumbling (until the deck or a wall), seconds left lying down.
var tumble := false
var lying_t := 0.0
## Round 3 (stock only): the last launch's steer (degrees of yaw, signed), and the falls broken.
var steer_deg := 0.0
var breaks := 0

var _launched := false
var _left := false
var _wait := 0.0
var _snap_was := -1.0
var _stun_from := -INF
var _stun_len := 0.0
var _stun_end := -INF
var _di_done := true
var _against_until := -INF
var _against_k := 0.0
var _presses: Array = []
var _press_dir := Vector3.ZERO
var _intangible_until := -INF
var _lie_age := 0.0
var _bounced := false
var _air_vy := 0.0


## The body's BendKnock, made on first use.
static func of(b: Node) -> BendKnock:
	var k := peek(b)
	if k == null and b is CharacterBody3D:
		k = BendKnock.new()
		k.name = NAME
		k.body = b as CharacterBody3D
		b.add_child(k)
	return k


## The body's BendKnock, or null when it was never knocked.
static func peek(b: Node) -> BendKnock:
	if b == null or not is_instance_valid(b):
		return null
	return b.get_node_or_null(NAME) as BendKnock


## The gravity a launched body falls by (the player's own: the world's default), so a bot flies as long as the player.
static func launch_gravity() -> float:
	if gravity_override > 0.0:
		return gravity_override
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


## A stock number (rules.json stock: RingRules.stock_num).
static func _sn(key: String, def: float) -> float:
	return RingRules.stock_num(key, def)


## `body` knocked along `v` (m/s) by `by`: the ring's rules first, then the player off his feet at ragdoll_mps or the push
## (kv, the up part), the listeners told. Returns the knock as applied (ZERO: none). `info`: round 3's hit info (spec §14.3);
## with info._launch (the stock ring: RingRules.on_hit's launch) the motion is SET (_stock_knock).
func knock(v: Vector3, by: Node, info := {}) -> Vector3:
	if body == null or not is_instance_valid(body):
		return Vector3.ZERO
	var l: Variant = info.get("_launch", null)
	if l is Dictionary and RingRules.stock_on():
		return _stock_knock(l as Dictionary, by)
	if rules != null and is_instance_valid(rules) and rules.has_method(&"knock_scale"):
		var r: Variant = rules.call(&"knock_scale", body, v, by)
		if r is Vector3:
			v = r
	if v.length_squared() < 1e-4:
		return Vector3.ZERO
	last_knocker = by if by != null and is_instance_valid(by) else null
	last_knock_at = BendStatus.now()
	knocks += 1
	var down := false
	if v.length() >= ragdoll_mps and body.has_method(&"knock_down"):
		down = bool(body.call(&"knock_down", v))
	if not down:
		kv += Vector3(v.x, 0.0, v.z)
		if v.y > 0.0:
			body.velocity.y = maxf(body.velocity.y, 0.0) + v.y
		else:
			body.velocity.y += v.y
		if v.y >= LAUNCH_UP_MPS:
			_launch()
		knock_t = maxf(knock_t, 0.25 + kv.length() / 20.0)
	_tell(v, by)
	return v


## The body's and the listeners' word of a knock taken.
func _tell(v: Vector3, by: Node) -> void:
	if body.has_method(&"on_bend_knock"):
		body.call(&"on_bend_knock", v, by)
	knocked.emit(v, by)
	if body.is_inside_tree():
		for lst in body.get_tree().get_nodes_in_group(LISTENERS):
			if lst.has_method(&"on_knocked"):
				lst.call(&"on_knocked", body, v, by)


## The stock ring's knock (spec §2.2): the motion SET to the launch `l` ({v, hitstun_s, tumble, refresh}), never added.
func _stock_knock(l: Dictionary, by: Node) -> Vector3:
	var v: Vector3 = l.get("v", Vector3.ZERO)
	var hs := float(l.get("hitstun_s", 0.0))
	last_knocker = by if by != null and is_instance_valid(by) else null
	last_knock_at = BendStatus.now()
	knocks += 1
	kv = Vector3(v.x, 0.0, v.z)
	var tum := bool(l.get("tumble", false))
	if tum or not body.is_on_floor():
		body.velocity.y = v.y
	else:
		body.velocity.y = minf(body.velocity.y, 0.0)     # (a flinch on the feet: a slide, no hop)
	tumble = tum
	_bounced = false
	if tum:
		_launch()
	elif _launched and body.is_on_floor():
		_end_launch(false)
	if not bool(l.get("lying", false)):
		lying_t = 0.0
	stun_t = hs
	knock_t = hs                              # (today's controllers hold their steering through the hitstun)
	steer_deg = 0.0
	_di_done = false
	_against_until = -INF
	_presses.clear()
	_tell(v, by)
	launched.emit(v, hs, bool(l.get("refresh", false)))
	return v


## In the air from an up-knock until back on the floor after leaving it.
func is_launched() -> bool:
	return _launched


## Knocked within the last `s` seconds (a fall's credit: who threw it).
func knocked_within(s: float) -> bool:
	return last_knocker != null and is_instance_valid(last_knocker) and BendStatus.now() - last_knock_at <= s


## `vel` without the knock the body carries (its own steering's part, flat; the y kept).
func base_of(vel: Vector3) -> Vector3:
	return Vector3(vel.x - applied.x, vel.y, vel.z - applied.z)


## The knock's velocity to add this frame (flat), decayed by `dt` on the floor or in the air; the launch's landing seen.
## Call once a frame, after the controller's own easing, before move_and_slide.
func extra_velocity(dt: float) -> Vector3:
	return step(dt, body.is_on_floor() if body != null else true)


func step(dt: float, on_floor: bool) -> Vector3:
	knock_t = maxf(knock_t - dt, 0.0)
	if RingRules.stock_on():
		return _stock_step(dt, on_floor)
	if _launched:
		if not on_floor:
			_left = true
		elif _left:
			_end_launch(true)
		else:
			_wait += dt
			if _wait > LAUNCH_WAIT_S:
				_end_launch(false)
	kv = kv.move_toward(Vector3.ZERO, (GROUND_DECEL if on_floor else AIR_DECEL) * dt)
	if kv.length_squared() < 1e-6:
		kv = Vector3.ZERO
	applied = kv
	return kv


## The stock ring's frame: lying down, the landing (the fall broken, a bounce, lying), the carry's decay (decel_air 8 and the
## steer held against it; decel_ground 6).
func _stock_step(dt: float, on_floor: bool) -> Vector3:
	var now := BendStatus.now()
	if lying_t > 0.0:
		_lie_age += dt
		lying_t = maxf(lying_t - dt, 0.0)
		knock_t = maxf(knock_t, lying_t)
	if _launched:
		if not on_floor:
			_left = true
			_air_vy = body.velocity.y if body != null else 0.0
		elif not _left:
			_wait += dt
			if _wait > LAUNCH_WAIT_S:
				_end_launch(false)
				tumble = false
		# (the landing itself is judged in after_slide: the controllers set their velocity after this, a bounce set here
		# would be lost)
	var dec := _sn("decel_ground", GROUND_DECEL) if on_floor else _sn("decel_air", 8.0)
	if not on_floor and now < _against_until:
		dec += _sn("di_against_decel", 2.0) * _against_k
	kv = kv.move_toward(Vector3.ZERO, dec * dt)
	if kv.length_squared() < 1e-6:
		kv = Vector3.ZERO
	applied = kv
	return kv


## Down on the deck from a launch (stock): the fall broken, a bounce, or lying down.
func _contact_deck() -> void:
	var fall := -_air_vy
	_end_launch(true)
	if not tumble:
		return
	var now := BendStatus.now()
	# (a tumbling body meeting the deck skids, it does not glide on: land_keep of the carry kept; the KO numbers count a
	# launch that comes down on the deck as one that stayed on it)
	kv *= _sn("land_keep", 0.3)
	if _judge_break() == "ok":
		var d := Vector3(_press_dir.x, 0.0, _press_dir.z)
		_broke("roll" if d.length() > 0.3 else "stand", d.normalized() if d.length() > 0.3 else Vector3.ZERO)
		return
	if fall > _sn("bounce_mps", 6.0) and not _bounced and body != null:
		_bounced = true
		body.velocity.y = fall * _sn("bounce_k", 0.3)
		_launch()
		return
	tumble = false
	lying_t = _sn("lie_auto_s", 1.0)
	_lie_age = 0.0
	_intangible_until = now + _sn("lie_intangible_s", 0.2)
	knock_t = maxf(knock_t, lying_t)


## The fall broken: kind "stand", "roll" or "wall" (dir the roll's, or the wall's normal): free and intangible at once.
func _broke(kind: String, dir: Vector3) -> void:
	tumble = false
	lying_t = 0.0
	breaks += 1
	if kind != "wall":
		kv = Vector3.ZERO                    # (on his feet at once; a roll is MOVE's to move)
	var rr := RingRules.current()
	if rr != null:
		rr.note_stat(body, "breaks")
	end_stun()
	_intangible_until = BendStatus.now() + _sn("tech_intangible_s", 0.25)
	broke_fall.emit(kind, dir)


## The E presses before this contact: "ok" (one within tech_s and none tech_s..tech_spoil_s before), "spoiled", "none".
func _judge_break() -> String:
	var now := BendStatus.now()
	var ok := false
	var spoil := false
	var win := _sn("tech_s", 0.25)
	var bad := _sn("tech_spoil_s", 0.5)
	for p: Array in _presses:
		var ago := now - float(p[0])
		if ago < -1e-4:
			continue
		if ago <= win + 1e-4:
			ok = true
			_press_dir = p[1]
		elif ago <= bad + 1e-4:
			spoil = true
	_presses.clear()
	if ok and not spoil:
		return "ok"
	return "spoiled" if spoil else "none"


## After move_and_slide: the part of kv going into what it hit (a wall, a post; not the floor) is gone. Stock: a tumbling
## body meeting a wall breaks its fall there (a press in time) or bounces off it at wall_miss_k.
func after_slide() -> void:
	if body == null:
		return
	if RingRules.stock_on():
		_stock_after_slide()
		return
	if kv == Vector3.ZERO:
		return
	for i in body.get_slide_collision_count():
		var n := body.get_slide_collision(i).get_normal()
		var flat := Vector3(n.x, 0.0, n.z)
		if flat.length() < 0.3:
			continue
		flat = flat.normalized()
		var into := kv.dot(flat)
		if into < 0.0:
			kv -= flat * into
	applied = kv


## Stock: a wall met (the part into it gone from the carry, or, tumbling, the fall broken there or a bounce off it at
## wall_miss_k) and the deck met from a launch (_contact_deck). `applied` stays what of the knock the body's velocity
## carries now, so the controller takes exactly that out next frame (a carry cut here never leaves a ghost in the body's own
## velocity).
func _stock_after_slide() -> void:
	if kv != Vector3.ZERO:
		for i in body.get_slide_collision_count():
			var n := body.get_slide_collision(i).get_normal()
			var flat := Vector3(n.x, 0.0, n.z)
			if flat.length() < 0.7:
				continue
			flat = flat.normalized()
			var into := kv.dot(flat)
			if into >= 0.0:
				continue
			var slid := kv - flat * into
			if tumble and not body.is_on_floor():
				applied = slid
				if _judge_break() == "ok":
					kv = Vector3.ZERO
					_broke("wall", flat)
				else:
					kv = (kv - flat * 2.0 * into) * _sn("wall_miss_k", 0.5)
				break
			kv = slid
			applied = kv
	if _launched and _left and body.is_on_floor():
		_contact_deck()


## The body's velocity was set by something else (a vault, a ride): none of the knock is in it now.
func drop_applied() -> void:
	applied = Vector3.ZERO


# ---------------------------------------------------------------- round 3 (stock only)
## Seconds until he can act (spec §3.2): the hitstun's end, or escape_s into it when it runs longer (the escape counted).
func act_left() -> float:
	var left := stun_t
	var esc := _sn("escape_s", 0.6)
	if _stun_len > esc + 1e-4:
		left = minf(left, maxf(_stun_from + esc - BendStatus.now(), 0.0))
	return left


## In a hitstun longer than escape_s and escape_s into it: a fresh press may end it now.
func can_escape() -> bool:
	var esc := _sn("escape_s", 0.6)
	return stun_t > 0.0 and _stun_len > esc + 1e-4 and BendStatus.now() - _stun_from >= esc - 1e-4


## The 0.6 s escape (spec §3.2; MOVE calls it for a press of Space or 3): a press made at `press_at` (BendStatus.now() s; NAN:
## now) ends the hitstun when it may be escaped and the press itself came escape_s or later into it (a buffered press made
## before never does). True when it ended it.
func escape(press_at := NAN) -> bool:
	var at := BendStatus.now() if is_nan(press_at) else press_at
	if not can_escape() or at < _stun_from + _sn("escape_s", 0.6) - 1e-4:
		return false
	end_stun()
	return true


## The hitstun over now.
func end_stun() -> void:
	_stun_end = BendStatus.now()
	knock_t = 0.0


## A hit can't take him now (a fall broken, the first of lying down, standing up).
func intangible() -> bool:
	return BendStatus.now() < _intangible_until


## Round 3 (stock only): the steer, read once di_read_s after the hit (dir: the held keys, flat, camera-relative; length up to
## 1): its part across the flight turns the carry's yaw by up to di_deg; its part against the flight adds di_against_decel to
## the carry's decay for di_against_s. Pitch never changes. steer_deg the turn.
func apply_di(dir: Vector3) -> void:
	if not RingRules.stock_on() or _di_done or stun_t <= 0.0:
		return
	_di_done = true
	var f := Vector3(kv.x, 0.0, kv.z)
	var d := Vector3(dir.x, 0.0, dir.z).limit_length(1.0)
	steer_deg = 0.0
	if f.length() < 0.1 or d.length() < 0.05:
		return
	f = f.normalized()
	var along := d.dot(f)
	var across := (d - f * along).length()
	var deg := _sn("di_deg", 15.0) * clampf(across, 0.0, 1.0) * signf(f.cross(d).y)
	kv = kv.rotated(Vector3.UP, deg_to_rad(deg))
	steer_deg = deg
	if along < 0.0:
		_against_until = BendStatus.now() + _sn("di_against_s", 0.3)
		_against_k = clampf(-along, 0.0, 1.0)


## Round 3 (stock only): E pressed while tumbling (dir: the held direction), judged at the next contact (the deck, a wall).
func press_break(dir: Vector3) -> void:
	if not RingRules.stock_on() or not tumble:
		return
	_presses.append([BendStatus.now(), dir])
	while _presses.size() > 8:
		_presses.pop_front()


## Round 3 (stock only): up from lying down (kind: "stand" (W or Space: intangible tech_intangible_s + 0.05), "roll" (MOVE
## rolls him), "attack" (the getup attack), "hit" (a hit on the lying body stands him)); not before lie_s unless a hit. True
## when he got up.
func getup(kind: String) -> bool:
	if lying_t <= 0.0:
		return false
	if kind != "hit" and _lie_age < _sn("lie_s", 0.4) - 1e-4:
		return false
	lying_t = 0.0
	knock_t = 0.0
	if kind == "stand":
		_intangible_until = BendStatus.now() + 0.3
	return true


## Lying down this long (s; 0 when not lying).
func lying_age() -> float:
	return _lie_age if lying_t > 0.0 else 0.0


## The knock's carry scaled by `k` (MOVE's double jump keeps half of it: 0.5).
func scale_carry(k: float) -> void:
	kv *= k


## All of it gone (a respawn, a death, a new round).
func reset() -> void:
	kv = Vector3.ZERO
	applied = Vector3.ZERO
	knock_t = 0.0
	if _launched:
		_end_launch(false)
	_stun_end = -INF
	_stun_len = 0.0
	tumble = false
	lying_t = 0.0
	_presses.clear()
	_intangible_until = -INF


func _launch() -> void:
	if not _launched:
		_snap_was = body.floor_snap_length
		body.floor_snap_length = 0.0
	_launched = true
	_left = false
	_wait = 0.0


func _end_launch(land: bool) -> void:
	_launched = false
	_left = false
	_wait = 0.0
	if _snap_was >= 0.0 and body != null and is_instance_valid(body):
		body.floor_snap_length = _snap_was
	_snap_was = -1.0
	if land:
		landed.emit()
