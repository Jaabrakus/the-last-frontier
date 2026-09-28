extends SceneTree
## Screenshots of the two tomahawk variants in Godot lighting (the project's sky HDRI for
## ambient light and reflections, a sun and shadows). Needs a window, not --headless:
##   Godot --path . --resolution 1400x1000 -s tests/throwables/tomahawk_model_screens.gd -- out=/abs/dir
## Saves tomahawk_godot_variants.png (both, upright, flat side to the camera),
## tomahawk_godot_spike_head.png and tomahawk_godot_pipe_head.png (3/4 close-ups).

const SKY := "res://assets/environment/sky/qwantani_late_afternoon_nosun_2k.exr"
const SUN_DIR := Vector3(-0.55723, 0.32684, 0.76333)   ## Toward the sun (sky/sun.json).

var out := "user://tomahawk_shots"
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	_environment(world)

	# View direction: from the sun side, a little to the right of it, slightly above.
	var s := Vector3(SUN_DIR.x, 0.0, SUN_DIR.z).normalized()
	var c := s.rotated(Vector3.UP, deg_to_rad(-35.0))
	var right := Vector3.UP.cross(c).normalized()
	# Model +X (the blade's flat side) toward the camera, haft up, model -Z (edge) to the right.
	var b := Basis(c, Vector3.UP, c.cross(Vector3.UP))
	var spike := ThrowableModels.build("tomahawk")
	var pipe := ThrowableModels.build("tomahawk_pipe")
	world.add_child(spike)
	world.add_child(pipe)
	spike.global_transform = Transform3D(b, right * 0.17)
	pipe.global_transform = Transform3D(b, -right * 0.17)

	cam = Camera3D.new()
	cam.fov = 32.0
	cam.near = 0.01
	world.add_child(cam)
	cam.current = true

	_look(Vector3(0, 0.2, 0) + c * 1.25 + Vector3.UP * 0.12, Vector3(0, 0.2, 0))
	await _shot("tomahawk_godot_variants.png")
	var hs := spike.global_transform * Vector3(0, 0.40, -0.03)
	_look(hs + (c * 0.75 - b.z * 0.55 + Vector3.UP * 0.3).normalized() * 0.42, hs)
	await _shot("tomahawk_godot_spike_head.png")
	var hp := pipe.global_transform * Vector3(0, 0.40, 0.0)
	_look(hp + (c * 0.8 + b.z * 0.5 + Vector3.UP * 0.35).normalized() * 0.42, hp)
	await _shot("tomahawk_godot_pipe_head.png")
	quit()


func _environment(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.38, 0.4)
	var tex := load(SKY) as Texture2D
	if tex:
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = tex
		var sky := Sky.new()
		sky.sky_material = pano
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.52, 0.55)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.2
	sun.light_color = Color(1.0, 0.93, 0.84)
	sun.shadow_enabled = true
	world.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR, Vector3.UP)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.28, 0.25)
	gm.roughness = 0.95
	ground.material_override = gm
	ground.position = Vector3(0, -0.075, 0)
	world.add_child(ground)


func _look(from: Vector3, at: Vector3) -> void:
	cam.look_at_from_position(from, at, Vector3.UP)


func _shot(file: String) -> void:
	for i in 30:
		await process_frame
	var img := root.get_texture().get_image()
	var path := out.path_join(file)
	img.save_png(path)
	print("SAVED ", path)
