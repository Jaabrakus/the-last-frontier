extends SceneTree
## God rays before / after (GodRays, scripts/world/env/god_rays.gd): from a few spots, the camera turned toward the sun,
## each view rendered with the rays off, on and off again, saved side by side. Needs a window.
##   Godot --path . --resolution 1280x720 -s tools/environment/god_rays_shots.gd -- out=<dir> [quality=medium] [hour=17]

## [name, camera position, metres toward the sun's bearing the camera looks, look height]
const VIEWS := [
	["forest", Vector3(-58.0, 1.7, -62.0), 30.0, 6.0],
	["forest_edge", Vector3(-30.0, 1.7, -45.0), 30.0, 7.0],
	["spawn", Vector3(0.0, 1.7, -10.0), 30.0, 6.0],
	["range", Vector3(0.0, 1.7, -90.0), 30.0, 6.0],
]

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://god_rays")
	DirAccess.make_dir_recursive_absolute(out)
	OS.low_processor_usage_mode_sleep_usec = 0
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	player.set_physics_process(false)
	player.set_process_input(false)
	if player.hud:
		player.hud.visible = false
	var rig := current_scene.get_node_or_null("EnvironmentRig")
	if args.has("hour") and rig and rig.clock_driver:
		var clock = rig.clock_driver.get("clock")
		if clock:
			clock.set_time(float(args["hour"]))
	if args.has("weather") and rig and rig.clock_driver:
		rig.clock_driver.force_weather(String(args["weather"]))
	var rays: GodRays = rig.get("_god_rays") if rig else null
	print("GODRAYS ", rays != null)
	if rays and args.has("debug"):
		rays.debug_rays_only = true
	var cam := Camera3D.new()
	cam.fov = 70.0
	current_scene.add_child(cam)
	cam.make_current()
	if rig:
		rig.follow_camera = cam
		if rig.get_camera_attributes():
			rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(120)
	var sun: DirectionalLight3D = rig.get_sun()
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	for v: Array in VIEWS:
		if not only.is_empty() and not String(v[0]) in only:
			continue
		var p: Vector3 = v[1]
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 60.0)
		var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
		if hit and hit.position.y < p.y + 8.0:
			p.y = hit.position.y + 1.7
		var toward := sun.global_basis.z
		var flat := Vector3(toward.x, 0, toward.z).normalized()
		cam.global_position = p
		cam.look_at(p + flat * float(v[2]) + Vector3.UP * float(v[3]))
		var shots: Array[Image] = []
		for on in [false, true, false]:
			if rays:
				rays.strength = float(args.get("strength", str(GodRays.new().strength))) if on else 0.0
			await _frames(40)
			RenderingServer.force_draw(false)
			shots.append(root.get_texture().get_image())
		var a := shots[0]
		var img := Image.create(a.get_width() * 3, a.get_height(), false, a.get_format())
		img.blit_rect(shots[0], Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
		img.blit_rect(shots[1], Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(a.get_width(), 0))
		img.blit_rect(shots[2], Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(a.get_width() * 2, 0))
		var path := out.path_join("%s.png" % v[0])
		img.save_png(path)
		print("saved ", path)
	print("GOD RAYS SHOTS DONE")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
