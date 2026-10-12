class_name BendMotion
extends Node
## The bender's own movement for a while (BendEffects' dash and buff; on any body that bends: BendMotion.of, the player's or a
## bot's): a dash's speed carried on through the body's own easing (carry), a slow fall (fall: hover, glide), a fast pace (run:
## wind run, the air scooter, along `facing`: the player's camera, a bot's own way). Each frame before the body moves
## (process_physics_priority): its own easing takes it from there.
## ROUND 2: a dash's END is kept (dash_began: a low dash ends with its carry, one thrown up as it lands again: a Leap, a
## Jets jump): an air fighter's Carried wind is charged then (BendZone.carry_wind; meta bend_dash_end), and glide(fall, s,
## held) is Leap's slow fall while `held` (jump) says so.

var body: CharacterBody3D
## The dash running: 0 none, 1 low (ends with its carry), 2 up (ends on landing, once it has left the ground).
var _dash := 0
var _dash_left := false
var _glide_held: Callable
## The way a run goes (a flat Vector3): the player's camera's; else the body's facing.
var facing: Callable
var _carry := Vector3.ZERO
var _carry_t := 0.0
var _fall := INF
var _fall_t := 0.0
var _run := 0.0
var _run_t := 0.0
var _fx: GPUParticles3D


static func of(n: CharacterBody3D) -> BendMotion:
	var m := n.get_node_or_null(^"BendMotion") as BendMotion
	if m == null:
		m = BendMotion.new()
		m.name = "BendMotion"
		m.body = n
		m.facing = m._default_facing
		m.process_physics_priority = -5
		n.add_child(m)
	return m


func carry(v: Vector3, s: float) -> void:
	_carry = Vector3(v.x, 0.0, v.z)
	_carry_t = s


func fall(mps: float, s: float, kind: String) -> void:
	_fall = mps
	_fall_t = s
	_glide_held = Callable()
	_trail(kind)


func run(mps: float, s: float, kind: String) -> void:
	_run = mps
	_run_t = s
	_trail(kind)


## A dash began (BendEffects.dash) with `up_mps` up: its end watched (see the header).
func dash_began(up_mps: float) -> void:
	_dash = 2 if up_mps >= 2.0 else 1
	_dash_left = false


## Leap's glide: a fall no faster than `mps` for up to `s` while `held` (a Callable -> bool: the jump key) says so, once
## off the ground.
func glide(mps: float, s: float, held: Callable) -> void:
	_fall = mps
	_fall_t = s
	_glide_held = held


## The dash's end now (see the header): its time kept, Carried wind charged for an air fighter.
func _dash_end() -> void:
	_dash = 0
	body.set_meta(&"bend_dash_end", BendStatus.now())
	SbFx.dash_ended(body)                     # (its Spellbreak trails stopped, its end played: visual only)
	BendZone.carry_wind(body)


func active() -> bool:
	return _carry_t > 0.0 or _fall_t > 0.0 or _run_t > 0.0


## A dash's speed being carried now (the player's legs' clip speed does not cap it meanwhile: FrontierPlayer).
func carrying() -> bool:
	return _carry_t > 0.0


func _trail(kind: String) -> void:
	if kind == "":
		return                                 # (a Spellbreak ride drawn instead: BendEffects.buff, SbFx)
	if _fx == null or not is_instance_valid(_fx):
		_fx = BendLooks.trail(body, kind, 0.35)
		if _fx != null:
			_fx.position = Vector3.UP * 0.3


## Down or out of it: a player's is_dead, a fighter's is_dead().
func _dead() -> bool:
	if body.has_method(&"is_dead"):
		return bool(body.call(&"is_dead"))
	return bool(body.get(&"is_dead"))


## The player's camera's way (as his run always went), else the body's facing.
func _default_facing() -> Vector3:
	var cam: Variant = body.get(&"camera")
	var fwd := -body.global_basis.z
	if cam is Camera3D and is_instance_valid(cam):
		fwd = -(cam as Camera3D).global_basis.z
	elif body.has_method(&"forward"):
		fwd = body.call(&"forward")
	return fwd


func _physics_process(dt: float) -> void:
	if body == null or _dead():
		return
	if not NetSpells.owns(body):
		_puppet_tick(dt)                          # (online another machine's fighter: his motion is his machine's)
		return
	if body.has_meta(&"bend_slam_lift") and body.is_on_floor():
		body.remove_meta(&"bend_slam_lift")       # (round 3: Down Gust's lift is once an airtime; landing gives it back)
	if _carry_t > 0.0:
		_carry_t -= dt
		var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if flat.length() < _carry.length():
			body.velocity.x = _carry.x
			body.velocity.z = _carry.z
	if _dash == 1 and _carry_t <= 0.0:
		_dash_end()
	elif _dash == 2:
		if not body.is_on_floor():
			_dash_left = true
		elif _dash_left:
			_dash_end()
	if _fall_t > 0.0:
		_fall_t -= dt
		var gliding := not _glide_held.is_valid() or bool(_glide_held.call())
		if not gliding:
			_fall_t = 0.0                          # (the jump key let go: the glide is over)
		elif body.velocity.y < -_fall:
			body.velocity.y = -_fall
	if _run_t > 0.0:
		_run_t -= dt
		var fwd: Vector3 = facing.call() if facing.is_valid() else -body.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
		var along := flat.dot(fwd)
		if along < _run and flat.length() > 0.5:
			body.velocity.x += fwd.x * (_run - along) * minf(1.0, dt * 8.0)
			body.velocity.z += fwd.z * (_run - along) * minf(1.0, dt * 8.0)
	if not active() and _fx != null and is_instance_valid(_fx):
		BendLooks.stop_trail(_fx)
		_fx = null


## Online, another machine's fighter (RingNet's puppet: NetBody moves him as his machine does): only the looks run here, his
## dash's end played when its time is up or he is down again (RingMoves' puppet state), never his motion, never his Carried
## wind (his machine charges it).
func _puppet_tick(dt: float) -> void:
	_carry_t = maxf(_carry_t - dt, 0.0)
	_fall_t = maxf(_fall_t - dt, 0.0)
	_run_t = maxf(_run_t - dt, 0.0)
	var rm := RingMoves.of(body)
	if _dash == 2 and rm != null and rm.airborne():
		_dash_left = true
	if (_dash == 1 and _carry_t <= 0.0) or (_dash == 2 and _dash_left and rm != null and not rm.airborne()):
		_dash = 0
		SbFx.dash_ended(body)
	if not active() and _fx != null and is_instance_valid(_fx):
		BendLooks.stop_trail(_fx)
		_fx = null
