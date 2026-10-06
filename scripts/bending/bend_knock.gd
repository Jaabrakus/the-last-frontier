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
## ROUND 3 (the % layer, smash_r3 spec §2.2, §3, §14.3; SEAMS stubbed it, PERCENT fills it; all of it behind the gate,
## RingRules.stock_on()): gravity_override (0: the world's, as today), stun_t / tumble / lying_t (the hitstun, the tumble
## and lying down), apply_di(dir) (the steer), press_break(dir) (E while tumbling), getup(kind), scale_carry(k) (MOVE's
## double jump halves the launch's carry), knock(v, by, info) (the hit info; under stock it SETS the motion, today it adds),
## the signals launched(v, hitstun_s, refresh) and broke_fall(kind, dir).

signal landed
signal knocked(v: Vector3, by: Node)
## Round 3 (stock only): launched at `v` with `hitstun_s` of hitstun; `refresh` a tumbling launch class (MOVE refreshes the
## air moves only then).
signal launched(v: Vector3, hitstun_s: float, refresh: bool)
## Round 3 (stock only): the fall broken at contact: kind "stand", "roll" or "wall", `dir` the roll's.
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
## Round 3: the gravity a launched body falls by (m/s^2; 0: the world's default, as today). MOVE's ring physics sets it.
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
## Round 3 (stock only): seconds of hitstun left, thrown into the air tumbling, seconds left lying down.
var stun_t := 0.0
var tumble := false
var lying_t := 0.0

var _launched := false
var _left := false
var _wait := 0.0
var _snap_was := -1.0


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


## `body` knocked along `v` (m/s) by `by`: the ring's rules first, then the player off his feet at ragdoll_mps or the push
## (kv, the up part), the listeners told. Returns the knock as applied (ZERO: none). `info`: round 3's hit info (spec §14.3;
## unread until PERCENT: today's knock still adds).
func knock(v: Vector3, by: Node, _info := {}) -> Vector3:
	if body == null or not is_instance_valid(body):
		return Vector3.ZERO
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
	if body.has_method(&"on_bend_knock"):
		body.call(&"on_bend_knock", v, by)
	knocked.emit(v, by)
	if body.is_inside_tree():
		for l in body.get_tree().get_nodes_in_group(LISTENERS):
			if l.has_method(&"on_knocked"):
				l.call(&"on_knocked", body, v, by)
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


## After move_and_slide: the part of kv going into what it hit (a wall, a post; not the floor) is gone.
func after_slide() -> void:
	if body == null or kv == Vector3.ZERO:
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


## The body's velocity was set by something else (a vault, a ride): none of the knock is in it now.
func drop_applied() -> void:
	applied = Vector3.ZERO


## Round 3 (stock only): the steer read in hitstun (dir: the held direction, flat). A no-op until PERCENT.
func apply_di(_dir: Vector3) -> void:
	pass


## Round 3 (stock only): E pressed while tumbling (judged at contact: broke_fall). A no-op until PERCENT.
func press_break(_dir: Vector3) -> void:
	pass


## Round 3 (stock only): up from lying down (kind: "stand", "roll", "attack"). A no-op until PERCENT.
func getup(_kind: String) -> void:
	pass


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
