class_name CreatorStage
extends Node3D
## The character creator's stage (CharacterCreator): the player's Actor_B (the game's body,
## legacy outfit and PlayerAppearance.dress path) idling on a round plank dais in a dark
## room, lit like a stage in the game's grade (AgX and the u10 grade LUT): a warm key from
## the front left, a cool rim from behind, a low fill. It lives in its own world (a
## SubViewport) and runs while the game is paused.
##
## The camera eases between framings (FRAMES: the face, the upper body, the whole figure)
## and follows the head of the idling figure; drag turns the figure (turn()), with a little
## inertia.
##
##   stage.show_look(look)        # every row change
##   stage.frame("face")          # face / bust / body

const IDLE := &"actor_b/actor_b-p-relax-idle"
const IDLE_FALLBACK := &"actor_b/actor_b-p-stealth-idle"
const GRADE_LUT := preload("res://scripts/world/env/grade_lut.gd")
const PLANKS := "res://assets/polyhaven/textures/structures/brown_planks_07/brown_planks_07_%s_2k.jpg"
const DIRT := "res://assets/polyhaven/textures/terrain/dirt_floor/dirt_floor_%s_2k.jpg"
## name -> [look-at offset from the head (or a fixed point when `fixed`), distance (m), fov,
## fixed look-at point or null]. The figure stands a little left of centre in "face" and
## "bust" so the right-hand option list does not cover it.
const FRAMES := {
	"face": [Vector3(0.0, 0.05, 0.0), 1.2, 22.0, null],
	"bust": [Vector3(0.0, -0.16, 0.0), 2.1, 26.0, null],
	"body": [Vector3.ZERO, 3.9, 30.0, Vector3(0.0, 0.92, 0.0)],
}
## Screen offset of the figure (camera h_offset, m at the target's distance): the side panels
## are wider on the right.
const SIDE_SHIFT := 0.1

var body: CharacterBodyMesh
var skeleton: Skeleton3D
var camera: Camera3D
var env: Environment
var frame_name := "body"
var _pivot: Node3D
var _yaw := 0.0
var _yaw_target := 0.0
var _yaw_vel := 0.0
var _cam_target := Vector3(0.0, 0.92, 0.0)
var _cam_dist := 3.9
var _cam_fov := 30.0
var _head_bone := -1
var _blink: FaceBlink
var _ready_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_environment()
	_build_set()
	_build_figure()
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	add_child(camera)
	_snap_camera()
	_ready_done = true


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.028, 0.032, 0.036)
	# a dim sky for reflections only (silver and gold read dark with nothing to reflect)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.18, 0.21)
	sky_mat.sky_horizon_color = Color(0.3, 0.29, 0.27)
	sky_mat.ground_horizon_color = Color(0.12, 0.11, 0.1)
	sky_mat.ground_bottom_color = Color(0.04, 0.04, 0.04)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.43, 0.48)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.tonemap_agx_contrast = 1.45
	env.adjustment_enabled = true
	env.adjustment_color_correction = GRADE_LUT.texture()
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.03
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.09, 0.1, 0.11)
	env.fog_density = 0.05
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# key: nearly white (a warm key turns every skin orange), high front left, the only hard
	# shadow
	var key := SpotLight3D.new()
	key.name = "Key"
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 8.0
	key.spot_range = 12.0
	key.spot_angle = 26.0
	key.spot_angle_attenuation = 1.6
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	add_child(key)
	key.position = Vector3(-2.2, 3.6, 3.0)
	key.look_at(Vector3(0.0, 1.1, 0.0))
	# rim: cool, from behind right, outlines the head and shoulders against the dark
	var rim := SpotLight3D.new()
	rim.name = "Rim"
	rim.light_color = Color(0.62, 0.74, 0.92)
	rim.light_energy = 7.0
	rim.spot_range = 10.0
	rim.spot_angle = 22.0
	add_child(rim)
	rim.position = Vector3(1.8, 3.0, -2.6)
	rim.look_at(Vector3(0.0, 1.35, 0.0))
	# fill: low and weak from the front right, keeps the shadow side of the face readable
	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color(0.88, 0.9, 0.94)
	fill.light_energy = 0.8
	fill.omni_range = 6.0
	fill.position = Vector3(1.6, 1.4, 2.4)
	add_child(fill)


static func _tex(pattern: String, kind: String) -> Texture2D:
	var p := pattern % kind
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _material(pattern: String, uv_scale: float, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = _tex(pattern, "diffuse")
	var nrm := _tex(pattern, "nor_gl")
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm
	var arm := _tex(pattern, "arm")
	if arm:
		m.roughness_texture = arm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_enabled = true
		m.ao_texture = arm
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.uv1_triplanar = true
	return m


func _build_set() -> void:
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	var pm := PlaneMesh.new()
	pm.size = Vector2(24.0, 24.0)
	floor_mi.mesh = pm
	floor_mi.material_override = _material(DIRT, 0.5, Color(0.55, 0.52, 0.5))
	add_child(floor_mi)
	var dais := MeshInstance3D.new()
	dais.name = "Dais"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.95
	cm.bottom_radius = 1.0
	cm.height = 0.12
	cm.radial_segments = 48
	dais.mesh = cm
	dais.position.y = 0.06
	dais.material_override = _material(PLANKS, 0.8, Color(0.7, 0.66, 0.62))
	add_child(dais)


func _build_figure() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Figure"
	_pivot.position.y = 0.12
	add_child(_pivot)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	_pivot.add_child(inst)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if not aps.is_empty() else null
	body = CharacterBodyMesh.attach(skeleton, ap)
	BindRest.ensure_character(inst)
	if ap:
		var clip := IDLE if ap.has_animation(IDLE) else IDLE_FALLBACK
		if ap.has_animation(clip):
			ap.play(clip)
	_head_bone = skeleton.find_bone("headb")
	_blink = FaceBlink.new()
	_blink.name = "FaceBlink"
	_blink.body = body
	add_child(_blink)


## Dresses the figure. With `hat_off` (the face and hair rows) the hat is taken off first, as
## a creator shows the hair (dress() then leaves the hair unpressed): the legacy tricorn is
## hidden and a garment outfit's head slot is set to bare ("-", PlayerOutfit); the clothing
## view shows the outfit as worn.
func show_look(look: Dictionary, hat_off := true) -> void:
	if body == null:
		return
	var lk := look
	if hat_off:
		lk = look.duplicate(true)
		var o: Dictionary = (lk.get("outfit", {}) as Dictionary).duplicate(true) if lk.get("outfit") is Dictionary else {}
		o["head"] = {"id": "-"}
		lk["outfit"] = o
	for mi: MeshInstance3D in body.meshes:
		if is_instance_valid(mi) and String(mi.name) == "Hat":
			mi.visible = not hat_off
	PlayerAppearance.dress(body, lk)


## The head's position in this world (the idle sways it).
func head_position() -> Vector3:
	if skeleton == null or _head_bone < 0:
		return Vector3(0.0, 1.62, 0.0)
	return skeleton.global_transform * skeleton.get_bone_global_pose(_head_bone).origin + Vector3(0.0, 0.03, 0.0)


func frame(which: String) -> void:
	if FRAMES.has(which):
		frame_name = which


## Turns the figure by `amount` radians (mouse drag); it keeps turning a little after release.
func turn(amount: float) -> void:
	_yaw_target += amount
	_yaw_vel = amount * 8.0


## Turns the figure to `yaw` radians (0 = facing the camera) without the drag's run-on.
func set_yaw(yaw: float) -> void:
	_yaw_target = yaw
	_yaw_vel = 0.0


func _goal() -> Array:
	var f: Array = FRAMES[frame_name]
	var target: Vector3 = f[3] if f[3] != null else head_position() + (f[0] as Vector3)
	return [target, float(f[1]), float(f[2])]


func _snap_camera() -> void:
	var g := _goal()
	_cam_target = g[0]
	_cam_dist = g[1]
	_cam_fov = g[2]
	_place()


func _place() -> void:
	if camera == null:
		return
	var dir := Vector3(0.0, 0.1, 1.0).normalized()
	camera.fov = _cam_fov
	camera.position = _cam_target + dir * _cam_dist
	camera.look_at(_cam_target)
	camera.h_offset = SIDE_SHIFT * _cam_dist * 0.35


func _process(delta: float) -> void:
	if not _ready_done:
		return
	var dt := minf(delta, 0.1)
	# drag inertia: the release keeps a short spin that dies out
	_yaw_target += _yaw_vel * dt
	_yaw_vel *= exp(-dt * 7.0)
	_yaw = lerpf(_yaw, _yaw_target, 1.0 - exp(-dt * 14.0))
	_pivot.rotation.y = _yaw
	var g := _goal()
	var k := 1.0 - exp(-dt * 5.0)
	_cam_target = _cam_target.lerp(g[0], k)
	_cam_dist = lerpf(_cam_dist, g[1], k)
	_cam_fov = lerpf(_cam_fov, g[2], k)
	_place()


## True when the camera has (nearly) reached the current framing (tests, shots).
func settled() -> bool:
	var g := _goal()
	return absf(_cam_dist - float(g[1])) < 0.01 and _cam_target.distance_to(g[0]) < 0.01
