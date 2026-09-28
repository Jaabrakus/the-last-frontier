extends SceneTree
## Render cost of every upscaling mode and level (scripts/world/settings/upscaling.gd) at fixed
## fort and forest views. Windowed (minimized by default); wrap it in a time limit:
##
##   Godot --path . --resolution 1600x900 -s tools/environment/settings/upscaling_cost.gd -- --no-capture \
##       [blocks=4] [draws=6] [poses=fort,forest] [only=off,auto/quality,...] [minimize=0] [shots=<dir>]
##
## Cost = RenderingServer.force_draw(false) into an off-window SubViewport of the window's size
## (offscreen_view.gd; the window's own 3D is off), i.e. max(CPU render, GPU) per frame without
## the display's 60 Hz pacing -- the method of benchmark.gd's cost probe. The upscaler is put on
## that viewport by EnvironmentRig.apply_viewport(), the game's own code path.
## The Mac is shared with other builds and its load drifts: at every pose all configurations are
## measured in `blocks` rounds (the order rotates each round) and each keeps its fastest round.
##
## Lines: UPCOST <config> fort_ms= forest_ms= forest_max_ms= fort_fps= forest_fps= (render-only
## fps = 1000 / ms) and per pose "UPPOSE <pose> <config>=<ms> ...". Ends with UPSCALING COST DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const Upscaling := preload("res://scripts/world/settings/upscaling.gd")

## [name, group, kind, a, b, c]: kind "P" = the player camera at feet xz `a`, yaw `b` (deg, 0 =
## north, +90 = west), pitch `c`; "T" = free camera at `a` looking at `b`, fov `c`. The forest
## poses are the benchmark's forest path (benchmark.gd forest_walk_p / run / turn / edge, as in
## perf/forest_cost.gd); the T poses are scenic_shots.gd's u10 viewpoints.
const POSES := [
	["fort_look", "fort", "P", Vector2(0.0, 6.0), 0.0, 0.0],
	["fort_look_e", "fort", "P", Vector2(0.0, 6.0), -22.0, -2.0],
	["u10_spawn_gate", "fort", "T", Vector3(1.4, 1.7, 4.0), Vector3(0.0, 1.4, -45.0), 60.0],
	["u10_firing_line", "fort", "T", Vector3(-1.2, 1.7, -18.5), Vector3(0.0, 1.2, -110.0), 55.0],
	["u10_parade", "fort", "T", Vector3(7.0, 1.7, 11.0), Vector3(-8.0, 2.4, 3.0), 65.0],
	["walkway", "fort", "T", Vector3(9.0, 4.8, -13.2), Vector3(-12.0, 1.0, -75.0), 65.0],
	["walk_a", "forest", "P", Vector2(-68.5, -53.7), 129.7, -3.0],
	["walk_c", "forest", "P", Vector2(-61.5, -48.0), 110.0, -3.0],
	["run_a", "forest", "P", Vector2(-77.7, -48.6), 129.7, 0.0],
	["run_b", "forest", "P", Vector2(-89.3, -39.0), 145.0, -3.0],
	["run_c", "forest", "P", Vector2(-100.8, -29.4), 129.7, 2.0],
	["turn_n", "forest", "P", Vector2(-85.3, -42.1), 0.0, 0.0],
	["turn_w", "forest", "P", Vector2(-85.3, -42.1), 90.0, 5.0],
	["turn_s", "forest", "P", Vector2(-85.3, -42.1), 180.0, -5.0],
	["edge_c", "forest", "P", Vector2(-44.0, 2.0), -90.0, 2.0],
	["u10_forest", "forest", "T", Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), 65.0],
]

var args := {}
var view: SubViewport
var level: Node
var player: Node3D
var rig: EnvironmentRig
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var blocks := int(args.get("blocks", "4"))
	var draws := int(args.get("draws", "6"))
	var groups: PackedStringArray = String(args.get("poses", "fort,forest")).split(",", false)
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if args.get("minimize", "1") != "0":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode_sleep_usec = 0
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	level = current_scene
	player = level.get_node("Player")
	player.set("ignore_mouse_capture", true)
	if player.get("hud"):
		player.get("hud").visible = false
	rig = level.get_node("EnvironmentRig")
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.disable_3d = true
	cam = Camera3D.new()
	cam.far = 1500.0
	level.add_child(cam)
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	rig.follow_camera = view.camera
	await _frames(90)

	var configs := []
	for m: String in Upscaling.MODES:
		for l: String in Upscaling.LEVELS:
			var cname := m if m == "off" else "%s/%s" % [m, l]
			if only.is_empty() or cname in only:
				configs.append([cname, m, l])
			if m == "off":
				break
	print("UPINFO driver=%s adapter=%s view=%s configs=%d blocks=%d draws=%d load=%s" % [
			RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(),
			view.size, configs.size(), blocks, draws, _load()])
	for c: Array in configs:
		var r := Upscaling.resolve(c[1], c[2])
		print("UPINFO %-20s -> %s scale=%.2f %s" % [c[0], r.mode, r.scale, r.note])

	var best := {}          ## config -> {pose -> ms}
	for c: Array in configs:
		best[c[0]] = {}
	var used := []
	for p: Array in POSES:
		if not String(p[1]) in groups and not String(p[0]) in groups:
			continue
		used.append(p)
		await _place(p)
		for b in blocks:
			for k in configs.size():
				var c: Array = configs[(k + b * 5) % configs.size()]
				_set_config(c[1], c[2])
				await _frames(3)
				var ms := _cost(draws)
				var prev: float = best[c[0]].get(p[0], INF)
				best[c[0]][p[0]] = minf(prev, ms)
				if args.has("shots") and b == 0 and String(p[0]) in ["fort_look", "u10_forest", "walk_a"]:
					await _frames(20)
					DirAccess.make_dir_recursive_absolute(String(args["shots"]))
					view.get_texture().get_image().save_png(String(args["shots"]).path_join(
							"%s_%s.png" % [p[0], String(c[0]).replace("/", "_")]))
		var line := "UPPOSE %-16s" % p[0]
		for c: Array in configs:
			line += " %s=%.2f" % [c[0], best[c[0]][p[0]]]
		print(line)
	_set_config("off", "quality")

	var off_fort := 0.0
	var off_forest := 0.0
	for c: Array in configs:
		var fort := []
		var forest := []
		for p: Array in used:
			(fort if p[1] == "fort" else forest).append(best[c[0]][p[0]])
		var f_mean := _mean(fort)
		var w_mean := _mean(forest)
		var w_max: float = forest.max() if not forest.is_empty() else 0.0
		if c[0] == "off":
			off_fort = f_mean
			off_forest = w_mean
		print("UPCOST %-22s fort_ms=%6.2f forest_ms=%6.2f forest_max_ms=%6.2f fort_fps=%5.0f forest_fps=%5.0f forest_worst_fps=%5.0f vs_off fort=%+.0f%% forest=%+.0f%%" % [
				c[0], f_mean, w_mean, w_max, 1000.0 / maxf(f_mean, 0.01), 1000.0 / maxf(w_mean, 0.01),
				1000.0 / maxf(w_max, 0.01), 100.0 * (off_fort / maxf(f_mean, 0.01) - 1.0) if off_fort > 0.0 else 0.0,
				100.0 * (off_forest / maxf(w_mean, 0.01) - 1.0) if off_forest > 0.0 else 0.0])
	print("UPINFO load_end=%s" % _load())
	print("UPSCALING COST DONE")
	quit()


func _set_config(mode: String, level_name: String) -> void:
	rig.settings.upscaling = mode
	rig.settings.upscaling_quality = level_name
	rig.apply_viewport(view)


func _cost(n: int) -> float:
	view.sync_camera()
	for k in 2:
		RenderingServer.force_draw(false)
	var t := Time.get_ticks_usec()
	for k in n:
		RenderingServer.force_draw(false)
	return (Time.get_ticks_usec() - t) / 1000.0 / n


func _place(p: Array) -> void:
	player.process_mode = Node.PROCESS_MODE_INHERIT
	match String(p[2]):
		"P":
			var xz: Vector2 = p[3]
			player.global_position = Vector3(xz.x, FrontierTerrain.height_at(xz.x, xz.y) + 0.05, xz.y)
			player.set("velocity", Vector3.ZERO)
			player.set("yaw", deg_to_rad(float(p[4])))
			player.set("pitch", deg_to_rad(float(p[5])))
			await _frames(10)
			view.source = player.get("camera")
			# Freeze the player (idle sway, camera collision) so every configuration sees the same
			# view: near foliage a few cm of camera motion changes the overdraw a lot.
			player.process_mode = Node.PROCESS_MODE_DISABLED
		"T":
			cam.fov = float(p[5])
			_look(p[3], p[4])
			await _frames(4)
			view.source = cam
	view.sync_camera()
	await _frames(10)


## benchmark.gd / scenic_shots.gd placement: a camera below 10 m stays 1.6 m above the colliders.
func _look(p: Vector3, target: Vector3) -> void:
	if p.y < 10.0:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 60.0)
		q.exclude = [(player as CollisionObject3D).get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit and p.y - hit.position.y < 1.6 and hit.position.y < p.y + 8.0:
			var lift: float = hit.position.y + 1.6 - p.y
			p.y += lift
			target.y += lift
	cam.global_position = p
	cam.look_at(target)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()


func _load() -> String:
	var out := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.loadavg"], out)
	return String(out[0]).strip_edges() if not out.is_empty() else "?"
