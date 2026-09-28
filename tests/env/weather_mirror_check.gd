extends SceneTree
## The clouds' CPU mirror against the GPU (cloud engine, 2026-09-26). Windowed (the sky shader must run); wrap it in a
## time limit:
##
##   Godot --path . --resolution 640x640 -s tests/env/weather_mirror_check.gd -- --no-capture [shots=<dir>]
##
## For each weather it looks along a set of directions (the sun's among them) through a narrow camera (1 deg, the
## smallest Camera3D.fov; sky only, cull_mask 0) with the sky's cloud_debug = 1 (the half-res pass draws the clouds'
## transmittance, 1 - alpha), with a linear tonemap and no fog, grade or glow, so the pixel is the transmittance
## itself; the step jitter is frozen per pixel (the CPU march uses the middle of the step) and the cirrus streaks are
## off (they do not shade; the storm's anvil shield still draws). The mean over the centre 9 x 9 pixels is compared
## with CloudField.view_transmittance() for the same ray; the sun's shade in DayNight comes from that function.
## Prints MIRROR lines and MIRROR CHECK PASSED / FAILED (the mean |GPU - CPU| over all rays under 0.03 and no ray off
## by more than 0.2: single rays graze cloud edges, where the 9 x 9 block and the one CPU ray see different amounts
## of cloud; review 2026-09-26: 0.007 and 0.10).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const EYE := Vector3(3.0, 1.7, -130.0)

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var level := current_scene
	var player: Node3D = level.get_node("Player")
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = player.get("hud")
	if hud:
		hud.visible = false
	var dn = level.get_node("EnvironmentRig").clock_driver
	if dn == null:
		print("MIRROR CHECK FAILED (no DayNight: run it windowed)")
		quit(1)
		return
	dn.clock.running = false
	dn.clock.set_time(15.0)
	var view := OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(320, 320))
	view.use_taa = false
	view.camera.cull_mask = 0   # the sky alone: no tree or roof in front of a ray (one ray looked through a tree)
	root.disable_3d = true
	var env: Environment = dn.env
	var m: ShaderMaterial = dn.sky_mat
	var sun: Vector3 = dn.clock.sun_direction()
	var dirs: Array[Vector3] = [sun]
	for i in 7:
		var az := 0.4 + float(i) * 0.9
		var el := deg_to_rad(30.0 + float(i) * 8.0)   # over the tree line around the range
		dirs.append(Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el)))
	var total := 0.0
	var count := 0
	var worst := 0.0
	for w in ["clear", "fair", "overcast", "storm_near", "storm_here"]:
		dn.force_weather(w)
		for i in 3:
			await process_frame
		# freeze everything that moves (the sky's uniforms applied once more), then measure
		dn.set_process(false)
		dn.call("_apply", 0.0)
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.tonemap_exposure = 1.0
		env.adjustment_enabled = false
		env.fog_enabled = false
		env.glow_enabled = false
		m.set_shader_parameter(&"cloud_debug", 1)
		m.set_shader_parameter(&"cloud_jitter_anim", 0.0)
		m.set_shader_parameter(&"cirrus_coverage", 0.0)   # the streaks are drawn but do not shade (not in the CPU ray)
		m.set_shader_parameter(&"flash", Vector4.ZERO)
		m.set_shader_parameter(&"bolt", Vector4.ZERO)
		var line := "MIRROR %-10s" % w
		for k in dirs.size():
			var d: Vector3 = dirs[k]
			view.camera.global_position = EYE
			view.camera.fov = 1.0
			view.camera.look_at(EYE + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = view.get_texture().get_image()
			var s := 0.0
			for y in range(-4, 5):
				for x in range(-4, 5):
					s += img.get_pixel(160 + x, 160 + y).srgb_to_linear().r
			var gpu := s / 81.0
			var cpu: float = dn.field.view_transmittance(d, EYE)
			var diff := absf(gpu - cpu)
			total += diff
			count += 1
			worst = maxf(worst, diff)
			line += " %s%.2f/%.2f" % ["sun:" if k == 0 else "", gpu, cpu]
			if args.has("shots"):
				DirAccess.make_dir_recursive_absolute(String(args["shots"]))
				img.save_png(String(args["shots"]).path_join("mirror_%s_%d.png" % [w, k]))
		print(line)
		m.set_shader_parameter(&"cloud_debug", 0)
		dn.set_process(true)
	var mean := total / maxf(count, 1)
	print("MIRROR mean |gpu - cpu| = %.3f over %d rays, worst %.3f" % [mean, count, worst])
	var ok := mean < 0.03 and worst < 0.2
	print("MIRROR CHECK %s" % ("PASSED" if ok else "FAILED"))
	quit(0 if ok else 1)
