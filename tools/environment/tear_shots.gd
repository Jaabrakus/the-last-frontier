extends SceneTree
## Look-dev shots of the sky tear (SkyTear: the story's reveal, mission 11 "Two Fires"): at night from the raiders' camp
## looking north-east toward the tear, the tear held (SkyTear.pose) at several amounts, the wonder where the tear's clock
## puts it, then the sky fully open (the wonder at 1, the tear put away). Needs a window.
##   Godot --path . --resolution 1280x720 -s tools/environment/tear_shots.gd -- out=<dir> [amounts=0,0.15,0.3,0.5,0.7,0.85,open]
##       [hour=22.5] [at=835,-265] [az=62] [alt=34] [look=24] [fov=75] [wide=1] [flash=0.5] [perf=1] [weather=clear]
##       [quality=medium] [rays=0]
## perf=1 prints the frame's time (vsync and the fps cap off for a few seconds) with the tear off and on (its cost).
## The cost and the flash shot come first: once the sky is open the sky galleons sail in (SkyTraffic) and would be in them.

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://tear")
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
	var rig: EnvironmentRig = current_scene.get_node_or_null("EnvironmentRig")
	var dn = rig.clock_driver
	dn.clock.running = false
	dn.force_weather(String(args.get("weather", "clear")))
	dn.clock.set_time(float(args.get("hour", "22.5")))
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.make_current()
	rig.follow_camera = cam
	if rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	var xz: PackedStringArray = String(args.get("at", "835,-265")).split(",")
	var p := Vector3(float(xz[0]), 0.0, float(xz[1]))
	player.global_position = p + Vector3(0.0, 2.0, 0.0)   # the terrain and the trees round the camp
	await _frames(90)
	player.visible = false   # the camera stands where the player is (the body round it, lit by a flash)
	if args.get("rays", "1") == "0" and rig._god_rays:
		rig._god_rays.enabled = false   # (look-dev: the tear without the moon's god rays)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 300.0, p + Vector3.DOWN * 300.0)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	p.y = (hit.position.y if hit else FrontierTerrain.height_at(p.x, p.z)) + 1.7
	var az := deg_to_rad(float(args.get("az", "62")))
	var alt := deg_to_rad(float(args.get("alt", "34")))
	var dir := Vector3(sin(az) * cos(alt), sin(alt), -cos(az) * cos(alt))
	var look := deg_to_rad(float(args.get("look", "24")))
	cam.global_position = p
	cam.look_at(p + Vector3(sin(az) * cos(look), sin(look), -cos(az) * cos(look)))
	var views := [["", float(args.get("fov", "75")), look]]
	if args.get("wide", "1") == "1":
		views.append(["_wide", 105.0, deg_to_rad(38.0)])
	print("TEAR SHOTS at %s toward az %.0f alt %.0f, hour %s" % [p, rad_to_deg(az), rad_to_deg(alt), args.get("hour", "22.5")])
	# the cost and the flash first: once the sky is open (the last shots) the sky galleons come (SkyTraffic)
	if args.get("perf", "0") == "1":
		# the tear's cost: the viewport's GPU time with the tear off, early and well on (the camera on it)
		cam.fov = float(args.get("fov", "75"))
		cam.look_at(p + Vector3(sin(az) * cos(look), sin(look), -cos(az) * cos(look)))
		var vp := root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		# the GPU timer reads 0 on the Mac's Metal: the frame's wall time with the vsync off (a few seconds only)
		var vsync := DisplayServer.window_get_vsync_mode()
		var cap := Engine.max_fps
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0   # the settings' 60 cap off too
		for a in [0.0, 0.3, 0.6, 0.0, 0.3]:
			SkyTear.pose(rig, dir, a)
			rig.set_wonder(0.0)
			await _frames(30)
			var gpu := 0.0
			var t0 := Time.get_ticks_usec()
			for i in 90:
				await process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			var wall := (Time.get_ticks_usec() - t0) / 90000.0
			print("PERF tear %.1f: frame %.2f ms (gpu timer %.2f ms)" % [a, wall, gpu / 90.0])
		DisplayServer.window_set_vsync_mode(vsync)
		Engine.max_fps = cap
	if args.has("flash"):
		var fa := float(args.get("flash"))
		SkyTear.pose(rig, dir, fa)
		cam.fov = float(args.get("fov", "75"))
		cam.look_at(p + Vector3(sin(az) * cos(look), sin(look), -cos(az) * cos(look)))
		await _frames(30)
		var tear := SkyTear.of(rig)
		tear.set_process(false)   # the flash held for the shot
		SkyTear.flash(rig, 1.0, dir)
		await _frames(4)
		RenderingServer.force_draw(false)
		var path := out.path_join("tear_%s_flash.png" % fa)
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
		tear.flash_amount = 0.0
		tear._push_flash()
		tear.set_process(true)
	for a in String(args.get("amounts", "0,0.15,0.3,0.5,0.7,0.85,open")).split(","):
		var tag := a
		if a == "open":
			SkyTear.pose(rig, dir, 0.0)
			rig.set_wonder(1.0)
		else:
			SkyTear.pose(rig, dir, float(a))
		for v: Array in views:
			cam.fov = float(v[1])
			var lk: float = v[2]
			cam.look_at(p + Vector3(sin(az) * cos(lk), sin(lk), -cos(az) * cos(lk)))
			await _frames(40)
			RenderingServer.force_draw(false)
			var path := out.path_join("tear_%s%s.png" % [tag, v[0]])
			root.get_texture().get_image().save_png(path)
			print("saved ", path, "  wonder ", snappedf(rig.wonder, 0.01))
	print("TEAR SHOTS DONE")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
