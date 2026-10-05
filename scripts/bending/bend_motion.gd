class_name BendMotion
extends Node
## The bender's own movement for a while (BendEffects' dash and buff; on the player: BendMotion.of): a dash's speed carried
## on through the player's own easing (carry), a slow fall (fall: hover, glide), a fast pace (run: wind run, the air
## scooter). Each frame before the player moves (process_physics_priority): his own easing takes it from there.

var player: FrontierPlayer
var _carry := Vector3.ZERO
var _carry_t := 0.0
var _fall := INF
var _fall_t := 0.0
var _run := 0.0
var _run_t := 0.0
var _fx: GPUParticles3D


static func of(p: FrontierPlayer) -> BendMotion:
	var m := p.get_node_or_null(^"BendMotion") as BendMotion
	if m == null:
		m = BendMotion.new()
		m.name = "BendMotion"
		m.player = p
		m.process_physics_priority = -5
		p.add_child(m)
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


func _trail(kind: String) -> void:
	if _fx == null or not is_instance_valid(_fx):
		_fx = BendLooks.trail(player, kind, 0.35)
		if _fx != null:
			_fx.position = Vector3.UP * 0.3


func _physics_process(dt: float) -> void:
	if player == null or player.is_dead:
		return
	if _carry_t > 0.0:
		_carry_t -= dt
		var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
		if flat.length() < _carry.length():
			player.velocity.x = _carry.x
			player.velocity.z = _carry.z
	if _fall_t > 0.0:
		_fall_t -= dt
		if player.velocity.y < -_fall:
			player.velocity.y = -_fall
	if _run_t > 0.0:
		_run_t -= dt
		var fwd := -player.global_basis.z
		if player.camera != null:
			fwd = -player.camera.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
		var along := flat.dot(fwd)
		if along < _run and flat.length() > 0.5:
			player.velocity.x += fwd.x * (_run - along) * minf(1.0, dt * 8.0)
			player.velocity.z += fwd.z * (_run - along) * minf(1.0, dt * 8.0)
	if not active() and _fx != null and is_instance_valid(_fx):
		BendLooks.stop_trail(_fx)
		_fx = null
