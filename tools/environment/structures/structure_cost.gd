extends SceneTree
## Render cost of the fort structures (package D), measured in one process with interleaved
## A/B/C configurations so that load from other processes cancels out. Needs a window.
##
##   Godot --path . --resolution 1600x900 -s tools/environment/structures/structure_cost.gd -- \
##       --no-capture [rounds=5] [draws=20] [quality=high] [out=<json>] [only=pose,..]
##       [hide=Vegetation]
##
## Loads the level with FrontierStructures (preview/preview_hook.gd). At fixed camera poses
## (the benchmark's gameplay and free-camera views) it renders an off-window SubViewport of the
## window's size with RenderingServer.force_draw() (as benchmark.gd's cost probe) in three
## configurations, round-robin:
##   on         structures visible, occluders active
##   no_occ     structures visible, occlusion culling off for the probe viewport
##   hidden     every structure mesh hidden (colliders stay), occlusion culling off
## and prints per pose the median frame ms, draw calls, primitives and objects (visible and
## shadow passes) for each, then "COST structures=<on - hidden> occluders=<on - no_occ>".

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

## [name, camera position, look-at target, fov]; "spawn" uses the player's gameplay camera.
const POSES := [
	["spawn_look", Vector3.ZERO, Vector3.ZERO, 70.0],
	["gate_fly", Vector3(0.3, 2.0, 2.0), Vector3(0.0, 1.4, -70.0), 70.0],
	["walkway", Vector3(9.0, 4.8, -13.2), Vector3(4.0, 4.2, -60.0), 70.0],
	["walkway_in", Vector3(9.0, 4.8, -13.2), Vector3(-6.0, 1.0, 5.0), 70.0],
	["range_lookback", Vector3(0.0, 1.7, -140.0), Vector3(0.0, 3.0, -16.0), 70.0],
	["parade", Vector3(7.0, 1.7, 11.0), Vector3(-8.0, 2.4, 3.0), 70.0],
	["aerial", Vector3(39.0, 30.0, 39.0), Vector3(0.0, 0.0, -25.0), 70.0],
	# Diagnostic: right behind the north wall, looking north into it (everything beyond the wall
	# is hidden: the occluders should cull it).
	["behind_wall", Vector3(8.0, 1.2, -14.8), Vector3(8.0, 1.2, -100.0), 60.0],
]
const CONFIGS := ["on", "no_occ", "hidden"]

var args := {}
var view: SubViewport
var player: FrontierPlayer
var geo: Array[GeometryInstance3D] = []
var occ: Array[OccluderInstance3D] = []
var occ_shapes: Array[Occluder3D] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var rounds := int(args.get("rounds", "5"))
	var draws := int(args.get("draws", "20"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode_sleep_usec = 0
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	preload("res://tools/environment/structures/preview/preview_hook.gd").install()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	player.switch_weapon("musket")
	player.yaw = 0.0
	player.pitch = 0.0
	var structures := current_scene.get_node_or_null("Structures")
	if structures == null:
		printerr("COST: no Structures node (run through the preview hook)")
		quit(1)
		return
	_collect(structures)
	# hide=Vegetation,...: hide other top-level builders in every configuration, to isolate the
	# structures' own cost (solid walls also save the cost of the forest they hide).
	for n in String(args.get("hide", "")).split(",", false):
		var node := current_scene.get_node_or_null(n) as Node3D
		if node:
			node.visible = false
			print("COST hiding %s" % n)
	print("COST structure geometry instances=%d occluders=%d" % [geo.size(), occ.size()])
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# offscreen_view copies the root's use_occlusion_culling, which stays false on the root
	# (the root uses the project setting instead): enable it for the probe as the game has it.
	_occlusion_on = bool(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", false))
	view.use_occlusion_culling = _occlusion_on
	print("COST root.use_occlusion_culling=%s probe=%s" % [root.use_occlusion_culling, view.use_occlusion_culling])
	root.disable_3d = true
	for i in 120:
		await process_frame
	var results := {}
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	for pose: Array in POSES:
		if not only.is_empty() and not String(pose[0]) in only:
			continue
		_place(pose)
		for i in 10:
			await process_frame
		var samples := {}
		var info := {}
		for c in CONFIGS:
			samples[c] = []
		for r in rounds:
			for c: String in CONFIGS:
				_config(c)
				for k in 6:
					RenderingServer.force_draw(false)
				var t := Time.get_ticks_usec()
				for k in draws:
					RenderingServer.force_draw(false)
				(samples[c] as Array).append((Time.get_ticks_usec() - t) / 1000.0 / draws)
				info[c] = _info()
			await process_frame
		_config("on")
		var line := "COST pose=%-15s" % pose[0]
		var res := {}
		for c: String in CONFIGS:
			var arr: Array = samples[c]
			arr.sort()
			var med: float = arr[arr.size() / 2]
			res[c] = {"ms": med, "samples": arr, "info": info[c]}
			line += "  %s %.2f ms (d %d p %dk o %d / sh d %d o %d)" % [c, med, info[c].draws, info[c].prims / 1000,
					info[c].objs, info[c].shadow_draws, info[c].shadow_objs]
		res["structures_ms"] = res.on.ms - res.hidden.ms
		res["occluders_ms"] = res.on.ms - res.no_occ.ms
		print(line)
		print("COST pose=%-15s structures=%+.2f ms occluders=%+.2f ms objects culled by occluders=%d" % [pose[0],
				res.structures_ms, res.occluders_ms, int(res.no_occ.info.objs) - int(res.on.info.objs)])
		results[pose[0]] = res
	if args.has("out"):
		var f := FileAccess.open(String(args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(results, "  "))
		f.close()
	print("STRUCTURE COST DONE")
	quit()


func _collect(n: Node) -> void:
	if n is GeometryInstance3D and not n is Label3D:
		geo.append(n)
	if n is OccluderInstance3D:
		occ.append(n)
		occ_shapes.append((n as OccluderInstance3D).occluder)
	for c in n.get_children():
		_collect(c)


## Occlusion culling is switched per viewport (the occluders stay in the scenario: re-adding
## them rebuilds the occlusion BVH asynchronously, which takes frames to land).
func _config(c: String) -> void:
	for g in geo:
		g.visible = c != "hidden"
	view.use_occlusion_culling = c == "on" and _occlusion_on


var _occlusion_on := true


func _place(pose: Array) -> void:
	if pose[0] == "spawn_look":
		view.source = player.camera
		view.sync_camera()
		return
	view.source = null
	view.camera.fov = pose[3]
	view.camera.global_position = pose[1]
	view.camera.look_at(pose[2])


func _info() -> Dictionary:
	var v := view
	return {
		"draws": v.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"prims": v.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"objs": v.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"shadow_draws": v.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow_objs": v.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
	}
