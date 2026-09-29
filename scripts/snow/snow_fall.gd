class_name SnowFall
extends Node3D
## The falling snow round the camera (SnowCover's; WeatherFx's rain streaks give way to it while the core says it snows):
## soft flakes in a box that follows the camera, drifting down and with the ground wind, as many as the snowfall asks
## (SnowCover.falling), lit by the scene's light level as the rain is. None falls under a roof (shaders/weather/
## precip.gdshader: the shelter map).

const AMOUNT := {"high": 6000, "medium": 4000, "low": 2000}
const BOX := Vector3(15.0, 1.0, 15.0)      ## half extents of the spawn box above the camera
const HEIGHT := 8.0
const SPEED := 1.05                        ## m/s, a flake's fall

var cover: SnowCover
var _p: GPUParticles3D
var _proc: ParticleProcessMaterial
var _draw: ShaderMaterial
var _level := 0.0


func _ready() -> void:
	top_level = true
	var q := "medium"
	var dn := get_tree().get_first_node_in_group(&"weather")
	var rig: Variant = dn.get("rig") if dn else null
	if rig and "settings" in rig and rig.settings:
		q = String(rig.settings.quality)
	_proc = ParticleProcessMaterial.new()
	_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_proc.emission_box_extents = BOX
	_proc.direction = Vector3.DOWN
	_proc.spread = 12.0
	_proc.initial_velocity_min = SPEED * 0.7
	_proc.initial_velocity_max = SPEED * 1.3
	_proc.gravity = Vector3(0.0, -0.15, 0.0)
	_proc.turbulence_enabled = true
	_proc.turbulence_noise_strength = 0.6
	_proc.turbulence_noise_scale = 2.2
	_proc.turbulence_noise_speed = Vector3(0.2, 0.0, 0.2)
	_proc.turbulence_influence_min = 0.05
	_proc.turbulence_influence_max = 0.15
	_proc.scale_min = 0.6
	_proc.scale_max = 1.4
	_draw = ShaderMaterial.new()
	_draw.shader = load("res://shaders/weather/precip.gdshader")
	_draw.set_shader_parameter("billboard", 0)
	_draw.set_shader_parameter("tex", Fx._soft_dot())
	_draw.set_shader_parameter("tint", Color(0.92, 0.94, 0.97, 0.85))
	# flakes right at the lens would be big blobs: they fade in from 0.3 m
	_draw.set_shader_parameter("fade_min", 0.3)
	_draw.set_shader_parameter("fade_max", 1.2)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	quad.material = _draw
	_p = GPUParticles3D.new()
	_p.name = "Snow"
	_p.amount = int(AMOUNT.get(q, 4000))
	_p.lifetime = (HEIGHT + 2.0) / SPEED
	_p.preprocess = _p.lifetime
	_p.local_coords = false
	_p.process_material = _proc
	_p.draw_pass_1 = quad
	_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_p.visibility_aabb = AABB(Vector3(-22.0, -20.0, -22.0), Vector3(44.0, 34.0, 44.0))
	_p.emitting = false
	_p.amount_ratio = 0.0
	add_child(_p)


func _process(delta: float) -> void:
	if cover == null or DisplayServer.get_name() == "headless":
		return
	_level = move_toward(_level, cover.falling, delta * 0.4)
	var on := _level > 0.01
	if _p.emitting != on:
		_p.emitting = on
	if not on:
		return
	_p.amount_ratio = clampf(_level, 0.0, 1.0)
	var dn := get_tree().get_first_node_in_group(&"weather")
	var ws: Variant = dn.get("weather") if dn else null
	var wind := Vector3.ZERO
	if ws:
		wind = Vector3(ws.wind_ground_dir.x, 0.0, ws.wind_ground_dir.y) * (0.6 + 3.5 * float(ws.wind_ground_strength))
	_proc.gravity = Vector3(wind.x, -0.15, wind.z)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_p.global_position = cam.global_position + Vector3(0.0, HEIGHT * 0.6, 0.0) - wind * 2.0
	# lit by the scene (the fog's light level, as the rain; ForestLight's under the trees)
	var lvl := 0.5
	var env: Variant = dn.get("env") if dn else null
	if env:
		var forest: Node = dn.get("forest")
		var fog_e: float = forest.rain_light if forest and forest.enabled else (env as Environment).fog_light_energy
		lvl = clampf(fog_e * 1.3, 0.12, 1.0)
	_draw.set_shader_parameter("tint", Color(0.9 * lvl + 0.08, 0.92 * lvl + 0.08, 0.96 * lvl + 0.08, 0.55 + 0.35 * _level))
