class_name SkyTraffic
extends Node3D
## Sky galleons crossing high over the valley once the wonder is in (user 2026-10-02: "the user finds a whole new world
## of wonder with sky galleons"; WonderLook, EnvironmentRig.wonder). Ambient only: they sail long straight legs far above
## and around the player and are never in the way; the story's own ships (the wreck, the voyage) are placed by missions.
##
## Up to MAX_SHIPS at once while the wonder is at least SHOW_FROM: each starts out of sight on one side of the player
## (RANGE_M), crosses at ALT_M above the ground at 9-16 m/s with a slight sway, and is dropped once well past. The near
## model swaps for its far mesh (Galleon_LOD1) past LOD_M; the wings' glow (material EtheriumGlow) breathes, stronger
## at night. The model is assets/sky/sky_galleon.glb (tools/models/sky_galleon.py).

const MODEL := "res://assets/sky/sky_galleon.glb"
const MAX_SHIPS := 2
const SHOW_FROM := 0.6
const RANGE_M := 900.0
const ALT_M := Vector2(150.0, 260.0)
const SPEED := Vector2(9.0, 16.0)
const LOD_M := 450.0
const GAP_S := Vector2(25.0, 70.0)    ## between one ship and the next

var rig: EnvironmentRig
var _scene: PackedScene
var _ships: Array = []                ## [{node, dir, speed, sway, t}]
var _wait := 8.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1757
	if ResourceLoader.exists(MODEL):
		_scene = load(MODEL) as PackedScene


func _process(delta: float) -> void:
	if rig == null or _scene == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	var on := rig.wonder >= SHOW_FROM
	# under way
	for i in range(_ships.size() - 1, -1, -1):
		var s: Dictionary = _ships[i]
		var n: Node3D = s.node
		s.t = float(s.t) + delta
		n.global_position += (s.dir as Vector3) * float(s.speed) * delta
		var sway := sin(float(s.t) * 0.35 + float(s.sway)) * 0.035
		n.rotation.z = sway
		n.rotation.x = sin(float(s.t) * 0.23 + float(s.sway) * 2.0) * 0.02
		var flat := Vector2(n.global_position.x - at.x, n.global_position.z - at.z)
		var ahead := flat.dot(Vector2((s.dir as Vector3).x, (s.dir as Vector3).z))
		_lod(s, flat.length())
		_glow(s, float(s.t))
		if ahead > RANGE_M * 1.15:
			n.queue_free()
			_ships.remove_at(i)
	# a new one
	_wait -= delta
	if on and _wait <= 0.0 and _ships.size() < MAX_SHIPS:
		_wait = _rng.randf_range(GAP_S.x, GAP_S.y)
		_launch(at)


func _launch(at: Vector3) -> void:
	var n := _scene.instantiate() as Node3D
	add_child(n)
	# a straight leg across the player's sky: from out of sight on one side to the other, passing 150-600 m off
	var heading := _rng.randf_range(0.0, TAU)
	var dir := Vector3(sin(heading), 0.0, -cos(heading))
	var side := Vector3(-dir.z, 0.0, dir.x) * _rng.randf_range(150.0, 600.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var start := at - dir * RANGE_M + side
	start.y = maxf(FrontierTerrain.height_at(start.x, start.z), at.y) + _rng.randf_range(ALT_M.x, ALT_M.y)
	n.global_position = start
	n.look_at(start + dir, Vector3.UP)    # the bow (-Z) along the leg
	# its meshes and glow materials found once (not searched every frame: the sky battle's lag, user 2026-10-02)
	var near: Array = []
	var far: Array = []
	var glows: Array = []
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var m := c as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # too high to shade the valley meaningfully
		(far if m.name.begins_with("Galleon_LOD1") else near).append(m)
		for si in m.mesh.get_surface_count() if m.mesh else 0:
			var mat := m.get_active_material(si) as StandardMaterial3D
			if mat and String(mat.resource_name).begins_with("EtheriumGlow"):
				mat = mat.duplicate() as StandardMaterial3D
				m.set_surface_override_material(si, mat)
				glows.append(mat)
	_ships.append({"node": n, "dir": dir, "speed": _rng.randf_range(SPEED.x, SPEED.y), "sway": _rng.randf() * TAU, "t": 0.0,
			"near": near, "far": far, "glows": glows, "is_far": null})


## Near meshes in, the far mesh out, and the other way round past LOD_M (only when it changes).
func _lod(s: Dictionary, dist: float) -> void:
	var far := dist > LOD_M
	if s.is_far == far:
		return
	s.is_far = far
	for m: MeshInstance3D in s.near:
		m.visible = not far
	for m: MeshInstance3D in s.far:
		m.visible = far


## The wings' glow breathes, brighter in the dark.
func _glow(s: Dictionary, t: float) -> void:
	var sun := rig.get_sun()
	var night := 1.0 if sun and sun.light_color.is_equal_approx(DayNight.MOON_COLOR) else 0.0   # (DayNight: the moon's light)
	var e := (1.2 + 0.4 * sin(t * 1.3)) * lerpf(1.0, 3.0, night)
	for mat: StandardMaterial3D in s.glows:
		mat.emission_energy_multiplier = e
