class_name Fireflies
extends Node3D
## Fireflies at dusk (user 2026-09-26: "add in fireflys and Owls and birds in the game to make it more legit"; 2026-09-27:
## "i dont want the fireflies around me i want them to be in the world"): swarms that belong to places, not to the
## player. PATCHES patches are set once, from the forest's canopy map (CanopyMap: open ground with trees round it: the
## meadows and the forest edges, where fireflies rise over the tall grass; the country round the fort first), spread
## at least PATCH_GAP apart, none in the fort. Each is a cloud of particles 0.8-3 m up over its patch, flashing on its own rhythm
## (shaders/wildlife/firefly.gdshader). Only the ACTIVE nearest patches within ACTIVE_M of the player glow (the rest
## are off), so walking out at dusk you come on them where they are, and they stay behind when you walk on.
## They come out as the sun goes down (from SUN_FROM deg, full by SUN_FULL) and fade again toward dawn, in summer only
## (DOY_SUMMER; the core's early September is late in their season).
##
##   var ff := Fireflies.new(); ff.player = player; ff.environment_rig = rig; add_child(ff)

const CanopyMap := preload("res://scripts/world/vegetation/canopy_map.gd")
const AMOUNT := 70             ## per patch (user 2026-09-27: "too many fire flies and its to strong": the old swarm 120)
const AREA := Vector3(9.0, 1.1, 9.0)          ## a patch's emission box, half extents
const PATCHES := 26
const PATCH_GAP := 45.0
const ACTIVE := 4
const ACTIVE_M := 170.0
const FORT_HALF := 26.0
const SEARCH := 380.0
## Patches this far from the fort score higher (the evenings are spent round it).
const NEAR_FORT := Vector2(90.0, 240.0)
const SUN_FROM := 6.0
const SUN_FULL := -4.0
const SUN_LATE := -20.0                      ## deep night: fewer (they fly mostly in the first hours of dark)
const DOY_SUMMER := Vector2(150.0, 265.0)

var player: Node3D
var environment_rig: EnvironmentRig
## The patches' centres (world, on the ground).
var patches: PackedVector3Array = PackedVector3Array()
## One GPUParticles3D per patch (null until first near).
var swarms: Array = []
var presence := 0.0
## The sun's height to use instead of the clock's (tests; INF = the clock).
var sun_override := INF
var _mat: ShaderMaterial
var _pm: ParticleProcessMaterial
var _quad: QuadMesh
var _pick_t := 0.0


func _ready() -> void:
	add_to_group(&"fireflies")
	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_pm.emission_box_extents = AREA
	_pm.direction = Vector3(0, 0.2, 0)
	_pm.spread = 180.0
	_pm.initial_velocity_min = 0.05
	_pm.initial_velocity_max = 0.3
	_pm.gravity = Vector3.ZERO
	_pm.damping_min = 0.02
	_pm.damping_max = 0.08
	_pm.turbulence_enabled = true
	_pm.turbulence_noise_strength = 0.6
	_pm.turbulence_noise_scale = 4.0
	_pm.turbulence_noise_speed = Vector3(0.05, 0.02, 0.05)
	_pm.turbulence_influence_min = 0.04
	_pm.turbulence_influence_max = 0.14
	_quad = QuadMesh.new()
	_quad.size = Vector2(0.1, 0.1)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/wildlife/firefly.gdshader")
	_quad.material = _mat
	_update(0.0)


func _process(dt: float) -> void:
	_update(dt)


func _update(dt: float) -> void:
	if patches.is_empty() and CanopyMap.image != null:
		place_patches()
	var want := target_presence()
	presence = move_toward(presence, want, dt * 0.2) if dt > 0.0 else want
	_mat.set_shader_parameter("presence", presence)
	_pick_t -= dt
	if _pick_t <= 0.0:
		_pick_t = 1.0
		_pick_active()


## Chooses the patches once: open ground (little crown over it) with trees round it (more cover a ring out), the best
## first, PATCH_GAP apart, out of the fort. The same every game (the forest is).
func place_patches() -> void:
	patches.clear()
	swarms.clear()
	var cands: Array = []
	var step := 14.0
	var x := -SEARCH
	while x <= SEARCH:
		var z := -SEARCH
		while z <= SEARCH:
			if absf(x) > FORT_HALF or absf(z) > FORT_HALF:
				var here := CanopyMap.cover_around(x, z, 6.0)
				var ring := CanopyMap.cover_around(x, z, 28.0)
				if here < 0.12 and ring > 0.12:
					# an edge: open here, the trees a stone's throw off (a meadow ringed with woods scores best)
					var sc := (1.0 - here * 4.0) * (1.0 - absf(ring - 0.38) * 1.6)
					# the country round the fort, where the evenings are spent, first
					var d := Vector2(x, z).length()
					sc += 0.5 * (1.0 - smoothstep(NEAR_FORT.x, NEAR_FORT.y, d))
					cands.append([sc, Vector3(x, 0.0, z)])
			z += step
		x += step
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for c: Array in cands:
		var p: Vector3 = c[1]
		var ok := true
		for q in patches:
			if Vector2(q.x - p.x, q.z - p.z).length() < PATCH_GAP:
				ok = false
				break
		if not ok:
			continue
		p.y = FrontierTerrain.height_at(p.x, p.z)
		patches.append(p)
		swarms.append(null)
		if patches.size() >= PATCHES:
			break


## The nearest ACTIVE patches within ACTIVE_M glow; the rest are put out (and freed when far).
func _pick_active() -> void:
	if player == null or not is_instance_valid(player) or patches.is_empty():
		return
	var pp := player.global_position
	var order: Array = []
	for i in patches.size():
		order.append([Vector2(patches[i].x - pp.x, patches[i].z - pp.z).length(), i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var on := {}
	for k in mini(ACTIVE, order.size()):
		if float(order[k][0]) <= ACTIVE_M:
			on[int(order[k][1])] = true
	for i in patches.size():
		var s: GPUParticles3D = swarms[i]
		if on.has(i):
			if s == null:
				s = _swarm(patches[i])
				swarms[i] = s
			var glow := presence > 0.01
			if glow and not s.emitting:
				s.restart()
			s.emitting = glow
			s.amount_ratio = clampf(presence, 0.0, 1.0)
		elif s != null:
			s.emitting = false
			if Vector2(patches[i].x - pp.x, patches[i].z - pp.z).length() > ACTIVE_M * 1.6:
				s.queue_free()
				swarms[i] = null


func _swarm(at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Swarm"
	p.amount = AMOUNT
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.local_coords = false
	p.visibility_aabb = AABB(-AREA - Vector3(4, 3, 4), (AREA + Vector3(4, 3, 4)) * 2.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = _pm
	p.draw_pass_1 = _quad
	p.emitting = false
	add_child(p)
	p.global_position = at + Vector3.UP * 1.9          # 0.8-3 m: over the grass
	return p


## The patches glowing now (tests).
func active() -> Array[int]:
	var out: Array[int] = []
	for i in swarms.size():
		var s: GPUParticles3D = swarms[i]
		if s != null and s.emitting:
			out.append(i)
	return out


## How many are out (0..1): the sun low or down, summer.
func target_presence() -> float:
	var clock: WorldClock = environment_rig.clock_driver.clock if environment_rig and environment_rig.clock_driver else null
	var el := clock.sun_elevation_deg() if clock else WorldClock.DEFAULT_SUN_ELEVATION_DEG
	if sun_override != INF:
		el = sun_override
	var doy := clock.day_of_year if clock else WorldClock.DEFAULT_DAY_OF_YEAR
	var season := smoothstep(DOY_SUMMER.x - 10.0, DOY_SUMMER.x + 10.0, doy) * (1.0 - smoothstep(DOY_SUMMER.y - 10.0, DOY_SUMMER.y + 10.0, doy))
	var dusk := 1.0 - smoothstep(SUN_FULL, SUN_FROM, el)
	var late := 0.45 + 0.55 * smoothstep(SUN_LATE - 10.0, SUN_LATE, el)
	return dusk * late * season
