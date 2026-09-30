class_name Raven
extends Node3D
## A raven: the scavenger of the food chain (user 2026-09-26: "have wolves and ravens come and eat the remains").
## A procedural bird (the project's own: body, head and beak, a wedge tail, wings that flap and hold a glide) that
## flies in to a carcass, circles over it (ravens circling above the trees tell a hunter something lies dead there),
## glides down beside it and hops and pecks (taking meat), calls (the recorded NPS raven), and bursts up when the player
## comes close or a shot is fired. It feeds beside wolves. When only bones are left it flies off. WildlifeSpawner sends
## them to carcasses.

enum Mode { ARRIVE, CIRCLE, LAND, PECK, FLEE, LEAVE }

const EAT := 0.0008              ## meat per second while pecking (x WildlifeSpawner.time_scale)
const SHY_M := 11.0              ## the player this close to it or the carcass: it takes off

var spawner: WildlifeSpawner
var carcass: Node3D                ## any carcass (WildlifeSpawner): a deer, a mammoth, a chopped-off leg
var mode := Mode.ARRIVE
var rng := RandomNumberGenerator.new()
var velocity := Vector3.ZERO

var _t := 0.0
var _ang := 0.0
var _r := 10.0
var _alt := 14.0
var _dir := 1.0
var _flap := 0.0
var _flap_amp := 0.8
var _ground := Vector3.ZERO
var _away := Vector3.FORWARD
var _call_t := 4.0
var _hop_t := 0.0
var _body: Node3D
var _wings: Array[Node3D] = []


func setup(sp: WildlifeSpawner, c: Node3D, seed_: int) -> void:
	spawner = sp
	carcass = c
	rng.seed = seed_
	_r = rng.randf_range(8.0, 14.0)
	_alt = rng.randf_range(11.0, 19.0)
	_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_ang = rng.randf() * TAU
	_call_t = rng.randf_range(2.0, 8.0)
	var a := rng.randf() * TAU
	_away = Vector3(cos(a), 0.0, sin(a))


func _ready() -> void:
	add_to_group(&"ravens")
	_build()


func _build() -> void:
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.035, 0.035, 0.045)
	black.roughness = 0.5
	black.metallic = 0.15
	var beak_m := StandardMaterial3D.new()
	beak_m.albedo_color = Color(0.02, 0.02, 0.02)
	beak_m.roughness = 0.35
	_body = Node3D.new()
	add_child(_body)
	_ellipsoid(_body, Vector3(0.085, 0.075, 0.2), Vector3.ZERO, black)
	_ellipsoid(_body, Vector3(0.06, 0.06, 0.07), Vector3(0, 0.045, -0.19), black)
	var beak := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.022
	cone.height = 0.09
	beak.mesh = cone
	beak.material_override = beak_m
	beak.position = Vector3(0, 0.035, -0.29)
	beak.rotation.x = -PI * 0.5
	_body.add_child(beak)
	var tail := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.11, 0.012, 0.16)
	tail.mesh = tb
	tail.material_override = black
	tail.position = Vector3(0, 0.015, 0.25)
	_body.add_child(tail)
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.06 * side, 0.035, -0.03)
		_body.add_child(pivot)
		var w := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(0.44, 0.012, 0.17)
		w.mesh = wb
		w.material_override = black
		w.position = Vector3(0.22 * side, 0.0, 0.02)
		pivot.add_child(w)
		pivot.set_meta("side", side)
		_wings.append(pivot)


static func _ellipsoid(parent: Node3D, r: Vector3, pos: Vector3, mat: Material) -> void:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 12
	s.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.scale = r
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


func _physics_process(dt: float) -> void:
	_t += dt
	var gone: bool = carcass == null or not is_instance_valid(carcass) or float(carcass.meat_left) <= 0.02
	if gone and mode != Mode.LEAVE:
		_enter(Mode.LEAVE)
	var c := carcass.global_position if not gone else global_position
	if mode in [Mode.CIRCLE, Mode.LAND, Mode.PECK] and _disturbed(c):
		_enter(Mode.FLEE)
		if spawner:
			spawner.sound(&"wild_rec_raven_call", global_position)
	match mode:
		Mode.ARRIVE:
			var entry := c + Vector3(cos(_ang), 0.0, sin(_ang)) * _r + Vector3.UP * _alt
			_fly_to(entry, 10.0, dt, 1.0)
			if global_position.distance_to(entry) < 3.0:
				_enter(Mode.CIRCLE)
		Mode.CIRCLE, Mode.FLEE:
			var r := _r * (1.7 if mode == Mode.FLEE else 1.0)
			var alt := _alt + (8.0 if mode == Mode.FLEE else 0.0)
			_ang += _dir * 7.5 / r * dt
			var tgt := c + Vector3(cos(_ang), 0.0, sin(_ang)) * r + Vector3.UP * alt
			_fly_to(tgt, 7.5, dt, 1.0 if mode == Mode.FLEE else 0.12)
			if mode == Mode.FLEE and _t > 10.0:
				_enter(Mode.CIRCLE)
			elif mode == Mode.CIRCLE and _t > rng.randf_range(8.0, 20.0) and not _disturbed(c):
				var a := rng.randf() * TAU
				var g := c + Vector3(cos(a), 0.0, sin(a)) * (WildlifeSpawner.carcass_rim(carcass) + rng.randf_range(1.2, 2.4))
				_ground = Vector3(g.x, FrontierTerrain.height_at(g.x, g.z) + 0.02, g.z)
				_enter(Mode.LAND)
		Mode.LAND:
			_fly_to(_ground + Vector3.UP * 0.1, maxf(2.5, global_position.distance_to(_ground) * 0.9), dt, 0.5)
			if global_position.distance_to(_ground) < 0.4:
				global_position = _ground
				velocity = Vector3.ZERO
				_enter(Mode.PECK)
		Mode.PECK:
			_peck(dt, c)
			if _t > rng.randf_range(20.0, 40.0) and rng.randf() < 0.02:
				_enter(Mode.CIRCLE)
		Mode.LEAVE:
			_fly_to(global_position + _away * 20.0 + Vector3.UP * 6.0, 11.0, dt, 1.0)
			if _t > 12.0:
				queue_free()
				return
	_wing_beat(dt)
	_calls(dt)


func _enter(m: Mode) -> void:
	mode = m
	_t = 0.0


func _disturbed(c: Vector3) -> bool:
	if spawner == null:
		return false
	# (PEOPLE: the player or anyone of his household or camp)
	if not spawner.people_near(c, SHY_M).is_empty() or not spawner.people_near(global_position, SHY_M).is_empty():
		return true
	return spawner.now - spawner.last_shot_time < 3.0 and spawner.last_shot_pos.distance_to(global_position) < 90.0


## Flies toward `target` at `speed`: turns smoothly, faces its flight, banks into turns; flap: 0 glide .. 1 flapping.
func _fly_to(target: Vector3, speed: float, dt: float, flap: float) -> void:
	var want := (target - global_position)
	if want.length() > 0.001:
		want = want.normalized() * speed
	velocity = velocity.lerp(want, clampf(dt * 2.2, 0.0, 1.0))
	var before := velocity
	global_position += velocity * dt
	_flap_amp = lerpf(_flap_amp, flap, clampf(dt * 3.0, 0.0, 1.0))
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > 0.2:
		var yaw := atan2(-flat.x, -flat.z)
		var turn := wrapf(yaw - rotation.y, -PI, PI)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(dt * 4.0, 0.0, 1.0))
		rotation.z = lerpf(rotation.z, clampf(-turn * 1.6, -0.6, 0.6), clampf(dt * 3.0, 0.0, 1.0))
	rotation.x = lerpf(rotation.x, clampf(before.y * 0.08, -0.5, 0.5), clampf(dt * 3.0, 0.0, 1.0))


## On the ground: hops about the carcass, faces it, pecks (takes meat).
func _peck(dt: float, c: Vector3) -> void:
	_flap_amp = lerpf(_flap_amp, 0.0, clampf(dt * 6.0, 0.0, 1.0))
	rotation.x = 0.0
	rotation.z = 0.0
	var to := c - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(dt * 5.0, 0.0, 1.0))
	_hop_t -= dt
	if _hop_t <= 0.0:
		_hop_t = rng.randf_range(1.5, 4.0)
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a), 0.0, sin(a)) * (WildlifeSpawner.carcass_rim(carcass) + rng.randf_range(0.9, 2.0))
		global_position = Vector3(p.x, FrontierTerrain.height_at(p.x, p.z) + 0.02, p.z)
	# a peck: the body dips forward
	_body.rotation.x = -maxf(sin(_t * 7.0), 0.0) * 0.6
	_body.position.y = 0.09
	if carcass and is_instance_valid(carcass):
		carcass.eat(EAT * dt * (spawner.time_scale if spawner else 1.0))


func _wing_beat(dt: float) -> void:
	if mode != Mode.PECK:
		_body.rotation.x = 0.0
		_body.position.y = 0.0
	_flap += dt * 4.6 * TAU
	for w in _wings:
		var side: float = w.get_meta("side")
		if mode == Mode.PECK:
			# folded: the wings swept back along the body
			w.rotation = Vector3(0.0, -side * 1.35, -side * 0.15)
			w.scale = Vector3(0.55, 1.0, 1.0)
		else:
			w.scale = Vector3.ONE
			var beat := sin(_flap) * 0.95 * _flap_amp + 0.14   # a glide holds a slight dihedral
			w.rotation = Vector3(0.0, 0.0, side * beat)


func _calls(dt: float) -> void:
	_call_t -= dt
	if _call_t <= 0.0:
		_call_t = rng.randf_range(6.0, 16.0)
		if spawner and mode in [Mode.CIRCLE, Mode.PECK, Mode.ARRIVE]:
			spawner.sound(&"wild_rec_raven_call", global_position)
