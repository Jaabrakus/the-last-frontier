extends SceneTree
## Render cost of the torch at night in the forest (push n01b; the user's forest runs about 31 fps, and the torch
## must not add heavy GPU cost). Windowed; wrap it in a time limit:
##   Godot --path . --resolution 1600x900 -s tests/torch/tools/torch_cost.gd -- --no-capture [hour=22.5] [reps=2]
##       [poses=walk_a,run_b,...] [variants=lit,plus2_lit,...] [shots=<dir>]
## At each pose (the player's own camera at the forest-path spots of tools/environment/perf/forest_cost.gd, and the
## fort) the frame is rendered with RenderingServer.force_draw(false) into an off-window SubViewport of the window's
## size (tools/environment/offscreen_view.gd), as forest_cost.gd does: max(CPU render, GPU) per frame. Each variant
## is measured back to back with REF (no torch: the held torch hidden), REF / variant / REF / variant, the minimum of
## each pair, because this Mac's load drifts (other work runs beside it).
## Variants: lit (the held torch, its light without shadows: the game default, FrontierPlayer.torch_shadows off),
## shadow (the light's cube shadow, torch_shadows on), dual (the shadow as dual paraboloid), plus2 (the held torch
## with shadow and two more burning on the ground nearby, unshadowed: TorchFire.budget_shadows keeps one shadow),
## plus2_lit (the default: the three lights, none shadowed).
## Lines: TCOST <variant> ref_avg= var_avg= delta_avg= ref_max= var_max= | per pose; ends with TORCH COST DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const DRAWS := 6
const BLOCKS := 3
const POSES := [
	["walk_a", Vector2(-68.5, -53.7), 129.7, -3.0],
	["walk_c", Vector2(-61.5, -48.0), 110.0, -3.0],
	["run_b", Vector2(-89.3, -39.0), 145.0, -3.0],
	["turn_n", Vector2(-85.3, -42.1), 0.0, 0.0],
	["turn_w", Vector2(-85.3, -42.1), 90.0, 5.0],
	["edge_c", Vector2(-44.0, 2.0), -90.0, 2.0],
	["fort", Vector2(0.0, 6.0), 0.0, 0.0],
]

var args := {}
var view
var player: FrontierPlayer
var extra: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode_sleep_usec = 0
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var level := current_scene
	player = level.get_node("Player")
	player.ignore_mouse_capture = true
	if player.hud:
		player.hud.visible = false
	for n in level.find_children("*", "DayNight", true, false):
		(n as DayNight).clock.running = false
		(n as DayNight).clock.set_time(float(args.get("hour", "22.5")))
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.disable_3d = true
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	await _frames(60)
	player.torch.take_out()
	player.torch.set_physics_process(false)    # the shadow budget is set by the variants here
	await _frames(30)
	var only: PackedStringArray = String(args.get("poses", "")).split(",", false)
	var reps := int(args.get("reps", "2"))
	var variants := [["lit", _lit.bind(false, OmniLight3D.SHADOW_CUBE, 0)], ["shadow", _lit.bind(true, OmniLight3D.SHADOW_CUBE, 0)],
			["dual", _lit.bind(true, OmniLight3D.SHADOW_DUAL_PARABOLOID, 0)], ["plus2", _lit.bind(true, OmniLight3D.SHADOW_CUBE, 2)],
			["plus2_lit", _lit.bind(false, OmniLight3D.SHADOW_CUBE, 2)]]
	for rep in reps:
		for v: Array in variants:
			if args.has("variants") and not String(v[0]) in String(args.variants).split(","):
				continue
			var s_ref := 0.0
			var s_var := 0.0
			var m_ref := 0.0
			var m_var := 0.0
			var n := 0
			var per := ""
			for p: Array in POSES:
				if not only.is_empty() and not String(p[0]) in only:
					continue
				await _place(p)
				_off()
				await _frames(3)
				var c0 := _cost()
				(v[1] as Callable).call()
				await _frames(4)
				var c1 := _cost()
				if args.has("shots") and rep == 0:
					DirAccess.make_dir_recursive_absolute(String(args.shots))
					view.get_texture().get_image().save_png(String(args.shots).path_join("%s_%s.png" % [v[0], p[0]]))
				_off()
				await _frames(3)
				var c2 := _cost()
				if args.has("shots") and rep == 0 and v[0] == "lit":
					view.get_texture().get_image().save_png(String(args.shots).path_join("REF_%s.png" % p[0]))
				(v[1] as Callable).call()
				await _frames(3)
				var c3 := _cost()
				var r := minf(c0, c2)
				var x := minf(c1, c3)
				s_ref += r
				s_var += x
				m_ref = maxf(m_ref, r)
				m_var = maxf(m_var, x)
				n += 1
				per += " %s%+.2f" % [p[0], x - r]
			print("TCOST rep%d %-7s ref_avg=%6.2f var_avg=%6.2f delta_avg=%+6.2f ref_max=%6.2f var_max=%6.2f |%s" % [rep, v[0],
					s_ref / n, s_var / n, (s_var - s_ref) / n, m_ref, m_var, per])
	print("TORCH COST DONE")
	quit()


func _off() -> void:
	player.torch.socket.visible = false
	for d in extra:
		(d as Node3D).visible = false


func _lit(shadow: bool, mode: int, n_extra: int) -> void:
	player.torch.socket.visible = true
	player.torch.fire.shadows = shadow
	player.torch.fire.light.omni_shadow_mode = mode
	while extra.size() < n_extra:
		var s := TorchState.new()
		s.light()
		var d := DroppedTorch.spawn(current_scene, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), player.global_position), Vector3.ZERO, Vector3.ZERO, s)
		d.freeze = true
		extra.append(d)
	for i in extra.size():
		var d: DroppedTorch = extra[i]
		d.visible = i < n_extra
		var fwd := -player.global_basis.z
		d.global_position = player.global_position + fwd * (2.5 + 2.0 * i) + player.global_basis.x * (1.5 if i % 2 == 0 else -1.5) + Vector3.UP * 0.05


func _place(p: Array) -> void:
	var xz: Vector2 = p[1]
	player.global_position = Vector3(xz.x, FrontierTerrain.height_at(xz.x, xz.y) + 0.05, xz.y)
	player.velocity = Vector3.ZERO
	player.yaw = deg_to_rad(float(p[2]))
	player.pitch = deg_to_rad(float(p[3]))
	await _frames(10)
	view.source = player.camera
	view.sync_camera()
	await _frames(2)


func _cost() -> float:
	for k in 3:
		RenderingServer.force_draw(false)
	var ms := INF
	for b in BLOCKS:
		var t := Time.get_ticks_usec()
		for k in DRAWS:
			RenderingServer.force_draw(false)
		ms = minf(ms, (Time.get_ticks_usec() - t) / 1000.0 / DRAWS)
	return ms


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
