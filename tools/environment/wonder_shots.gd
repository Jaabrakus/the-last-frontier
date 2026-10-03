extends SceneTree
## Look-dev shots of the sky's giant (WonderLook, look=wonder; without it the frontier's own sky, for a before/after):
## from a few spots, the camera turned toward the ringed giant's bearing, at several hours. Needs a window.
##   Godot --path . --resolution 1280x720 -s tools/environment/wonder_shots.gd -- out=<dir> [look=wonder]
##       [hours=10,17,20.5,1] [quality=medium] [weather=clear] [only=spawn,edge]

## [name, camera position, look height above the giant's horizon bearing (deg below its altitude), fov]
const VIEWS := [
	["spawn", Vector3(0.0, 1.7, -10.0), 12.0, 75.0],
	["edge", Vector3(-30.0, 1.7, -45.0), 18.0, 75.0],
	["field", Vector3(30.0, 1.7, 20.0), 22.0, 65.0],
]
const PLANET_EQ := Vector3(0.21, 0.33, 0.92)

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://wonder")
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
	var dn = rig.clock_driver
	dn.clock.running = false
	dn.force_weather(String(args.get("weather", "clear")))
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.make_current()
	rig.follow_camera = cam
	if rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(60)
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	var tag := "wonder" if "look" in args else "frontier"
	for h in String(args.get("hours", "10,17,20.5,1")).split(","):
		dn.clock.set_time(float(h))
		await _frames(30)
		var pd: Vector3 = (dn.clock.celestial_basis().inverse() * PLANET_EQ.normalized()).normalized()
		print("HOUR %s giant az %.0f alt %.0f" % [h, rad_to_deg(atan2(pd.x, -pd.z)), rad_to_deg(asin(pd.y))])
		for v: Array in VIEWS:
			if not only.is_empty() and not String(v[0]) in only:
				continue
			var p: Vector3 = v[1]
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 60.0)
			var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
			if hit and hit.position.y < p.y + 8.0:
				p.y = hit.position.y + 1.7
			var flat := Vector3(pd.x, 0, pd.z).normalized()
			var alt := maxf(asin(pd.y) - deg_to_rad(float(v[2])), deg_to_rad(4.0))
			cam.fov = float(v[3])
			cam.global_position = p
			cam.look_at(p + flat * cos(alt) + Vector3.UP * sin(alt))
			await _frames(45)
			RenderingServer.force_draw(false)
			var path := out.path_join("%s_%s_%s.png" % [tag, v[0], h])
			root.get_texture().get_image().save_png(path)
			print("saved ", path)
	print("WONDER SHOTS DONE")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
