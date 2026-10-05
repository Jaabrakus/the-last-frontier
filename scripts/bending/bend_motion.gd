class_name BendMotion
extends Node
## The bender's own movement for a while (BendEffects' dash and buff; on any body that bends: BendMotion.of, the player's or a
## bot's): a dash's speed carried on through the body's own easing (carry), a slow fall (fall: hover, glide), a fast pace (run:
## wind run, the air scooter, along `facing`: the player's camera, a bot's own way). Each frame before the body moves
## (process_physics_priority): its own easing takes it from there.

var body: CharacterBody3D
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
	_trail(kind)


func run(mps: float, s: float, kind: String) -> void:
	_run = mps
	_run_t = s
	_trail(kind)


func active() -> bool:
	return _carry_t > 0.0 or _fall_t > 0.0 or _run_t > 0.0


## A dash's speed being carried now (the player's legs' clip speed does not cap it meanwhile: FrontierPlayer).
func carrying() -> bool:
	return _carry_t > 0.0


func _trail(kind: String) -> void:
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
	if _carry_t > 0.0:
		_carry_t -= dt
		var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if flat.length() < _carry.length():
			body.velocity.x = _carry.x
			body.velocity.z = _carry.z
	if _fall_t > 0.0:
		_fall_t -= dt
		if body.velocity.y < -_fall:
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
