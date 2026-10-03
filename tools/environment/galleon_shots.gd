extends SceneTree
## Look-dev shots of the sky galleons over the valley (SkyTraffic, assets/sky/sky_galleon.glb) under the wonder sky: a
## ship put on a leg past the camera, captured as it comes on, overhead and going away, at a day and a dusk hour. Needs a
## window and look=wonder.
##   Godot --path . --resolution 1280x720 -s tools/environment/galleon_shots.gd -- look=wonder out=<dir> [hours=16,20.3]

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://galleon")
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
	var rig: EnvironmentRig = current_scene.get_node("EnvironmentRig")
	var dn = rig.clock_driver
	dn.clock.running = false
	dn.force_weather("clear")
	var traffic: SkyTraffic = rig.get_node("SkyTraffic")
	traffic.set_process(false)      # the shots place their own ship
	var cam := Camera3D.new()
	cam.fov = 60.0
	current_scene.add_child(cam)
	cam.make_current()
	rig.follow_camera = cam
	if rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	var eye := Vector3(10.0, 0.0, 30.0)
	eye.y = FrontierTerrain.height_at(eye.x, eye.z) + 1.7
	cam.global_position = eye
	var ship := (load(SkyTraffic.MODEL) as PackedScene).instantiate() as Node3D
	current_scene.add_child(ship)
	for h in String(args.get("hours", "16,20.3")).split(","):
		dn.clock.set_time(float(h))
		# a leg crossing 140 m up, passing 90 m to the camera's side
		var dir := Vector3(0.8, 0.0, -0.6).normalized()
		var side := Vector3(-dir.z, 0.0, dir.x) * 90.0
		for k in 3:
			var along: float = [-170.0, -20.0, 140.0][k]
			ship.global_position = eye + side + dir * along + Vector3.UP * 140.0
			ship.look_at(ship.global_position + dir, Vector3.UP)
			for m in ship.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).visible = not String(m.name).begins_with("Galleon_LOD1")   # the near model
			cam.look_at(ship.global_position + Vector3.DOWN * 10.0)
			await _frames(40)
			RenderingServer.force_draw(false)
			var path := out.path_join("galleon_%s_%d.png" % [h, k])
			root.get_texture().get_image().save_png(path)
			print("saved ", path)
	print("GALLEON SHOTS DONE")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
