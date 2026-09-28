extends SceneTree
## Package C cost breakdown (needs a window; wrap it in a time limit). For a few fixed poses it
## renders the frame off-window (tools/environment/offscreen_view.gd, like benchmark.gd's cost
## probe) with every vegetation category shown, then with one category hidden at a time, and
## prints the render time, draw calls, primitives and objects of each, so the share of trees
## (per LOD), shadow proxies, impostors, saplings / shrubs, ferns and props is visible.
##
##   Godot --path . --resolution 1600x900 -s tools/environment/vegetation/veg_cost.gd -- \
##       [quality=high] [reps=3] [poses=fort,aim,forest,aerial,lookback]
##
## Lines: VEGCOST pose=<p> hide=<category|none|all> ms=<mean> draws=<n> prims=<n> objs=<n>
## followed by VEGCOST share lines (all - hidden) and VEGCOST DONE. Timings are max(CPU, GPU)
## per frame like benchmark.gd; on a busy machine compare A/B pairs, not absolute numbers.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

const CATEGORIES := ["TreeLod0", "TreeLod1", "TreeLod2", "TreeShadow3", "TreeShadow4", "TreeImpostors", "Plant", "Fern", "Prop"]
const POSES := {
	"fort": [Vector3.ZERO, Vector3.ZERO],            # the gameplay camera at the spawn
	"aim": [Vector3.ZERO, Vector3.ZERO],
	"forest": [Vector3(-55.0, 1.7, -52.0), Vector3(-90.0, 3.0, -70.0)],
	"lookback": [Vector3(5.0, 1.7, -118.0), Vector3(0.0, 2.8, -16.0)],
	"aerial": [Vector3(48.0, 30.0, 48.0), Vector3(0.0, 0.0, -22.0)],
}

var view: SubViewport
var player: Node3D


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var reps := int(args.get("reps", "3"))
	var poses: PackedStringArray = String(args.get("poses", "fort,aim,forest,lookback,aerial")).split(",", false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode_sleep_usec = 0
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.set("ignore_mouse_capture", true)
	if player.get("hud"):
		player.get("hud").visible = false
	player.call("switch_weapon", "musket")
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	var groups := {}
	for cat in CATEGORIES:
		groups[cat] = []
	var veg := current_scene.get_node("Vegetation")
	for n in veg.find_children("*", "MultiMeshInstance3D", true, false):
		for cat: String in CATEGORIES:
			if String(n.name).begins_with(cat):
				groups[cat].append(n)
				break
	for cat: String in CATEGORIES:
		print("VEGCOST category %s multimeshes=%d" % [cat, groups[cat].size()])
	await _frames(120)
	for pose: String in poses:
		_pose(pose)
		await _frames(30)
		var base := await _measure(reps)
		print("VEGCOST pose=%-8s hide=%-13s ms=%6.2f draws=%5d prims=%8d objs=%5d" % [pose, "none", base[0], base[1], base[2], base[3]])
		var configs: Array = []
		for cat: String in CATEGORIES:
			configs.append([cat, groups[cat]])
		configs.append(["all", [veg]])
		for cfg: Array in configs:
			# Interleaved A/B: shown, hidden, shown, hidden ... ; the minimum of each side is
			# robust against other processes on the machine.
			var shown := INF
			var hidden := INF
			var info := []
			for k in reps:
				var a := await _measure(1)
				shown = minf(shown, a[0])
				for n: Node3D in cfg[1]:
					n.visible = false
				var b := await _measure(1)
				hidden = minf(hidden, b[0])
				info = b
				for n: Node3D in cfg[1]:
					n.visible = true
			print("VEGCOST pose=%-8s hide=%-13s ms=%6.2f (shown %6.2f) draws=%5d prims=%8d objs=%5d   share ms=%+.2f draws=%d prims=%d" % [
					pose, cfg[0], hidden, shown, info[1], info[2], info[3], shown - hidden, base[1] - info[1], base[2] - info[2]])
		await _frames(4)
	print("VEGCOST DONE")
	quit()


func _pose(pose: String) -> void:
	if pose == "fort" or pose == "aim":
		player.set("yaw", 0.0)
		player.set("pitch", deg_to_rad(-2.0 if pose == "fort" else 1.0))
		if pose == "aim":
			Input.action_press("aim")
		else:
			Input.action_release("aim")
		view.source = player.get("camera")
	else:
		Input.action_release("aim")
		view.source = null
		var p: Array = POSES[pose]
		var cam: Camera3D = view.camera
		cam.fov = 70.0
		var pos: Vector3 = p[0]
		if pos.y < 10.0:
			pos.y += FrontierTerrain.height_at(pos.x, pos.z)
		cam.global_position = pos
		cam.look_at(p[1] + Vector3(0, pos.y - p[0].y, 0))


## [min over batches of the per-frame ms, draws, prims, objs] of the off-window view; each batch
## is 5 forced frames after 3 warm-up frames.
func _measure(reps: int) -> Array:
	view.sync_camera()
	for k in 3:
		RenderingServer.force_draw(false)
	var best := INF
	for r in reps:
		var t := Time.get_ticks_usec()
		for k in 5:
			RenderingServer.force_draw(false)
		best = minf(best, (Time.get_ticks_usec() - t) / 5000.0)
		await process_frame
	RenderingServer.force_draw(false)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	return [best, draws, prims, objs]


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if view:
			view.sync_camera()
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
