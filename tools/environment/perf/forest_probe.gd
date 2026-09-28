extends SceneTree
## Where does the frame go? A/B render cost of every content category and lighting feature at
## fixed forest and fort poses (package A performance pass). Windowed; wrap it in a time limit:
##
##   Godot --path . --resolution 1600x900 -s tools/environment/perf/forest_probe.gd -- --no-capture \
##       [quality=high] [reps=1] [only=REF,veg_off,...] [poses=fort,forest_in,...] [out=<json>]
##
## Same measurement as benchmark.gd's cost probe: RenderingServer.force_draw(false) into an
## off-window SubViewport of the window's size (max(CPU render, GPU) per frame, valid with the
## window covered). For every variant it prints
##   PROBE <variant> <pose>=<ms> ... avg=<ms> delta=<ms vs REF>  vis_draws= vis_prims= shd_draws= shd_prims= cpu_ms=
## Content variants hide nodes by name prefix (Vegetation/Visuals/<prefix>*, Terrain/Grass,
## Terrain/Chunks); feature variants toggle the live EnvironmentRig / viewport / RenderingServer.
## Ends with FOREST PROBE DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const VegRelod := preload("res://tools/environment/perf/veg_relod.gd")
const DRAWS := 15

## [name, camera xz, eye height above ground, look direction (x, y, z) or target point (flag)].
const POSES := [
	["fort", Vector3(0.9, 2.2, 9.5), Vector3(0.0, 1.6, -40.0), false],
	["forest_in", Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), false],
	["forest_deep", Vector3(-95.0, 1.7, -45.0), Vector3(-1.0, 0.02, 0.1), true],
	["forest_sun", Vector3(-75.0, 1.7, -25.0), Vector3(-0.68, 0.05, 0.74), true],
	["forest_across", Vector3(-62.0, 1.7, 40.0), Vector3(1.0, -0.03, -0.15), true],
	["lookback", Vector3(3.0, 1.7, -130.0), Vector3(0.0, 3.0, -16.0), false],
]

var args := {}
var view: SubViewport
var rig: Node
var env: Environment
var sun: DirectionalLight3D
var level: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var reps := int(args.get("reps", "1"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	var pose_filter: PackedStringArray = String(args.get("poses", "")).split(",", false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode_sleep_usec = 0
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file(String(args.get("scene", "res://scenes/main.tscn")))
	await process_frame
	await process_frame
	level = current_scene
	var player: Node = level.get_node("Player")
	player.set("ignore_mouse_capture", true)
	var hud = player.get("hud")
	if hud:
		hud.visible = false
	rig = level.get_node("EnvironmentRig")
	env = rig.get_environment()
	sun = rig.get_sun()
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	root.disable_3d = true
	if "follow_camera" in rig:
		rig.follow_camera = view.camera
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	await _frames(90)

	var poses := []
	for p: Array in POSES:
		if pose_filter.is_empty() or String(p[0]) in pose_filter:
			poses.append(p)
	# stack=v1,v2: variants applied for the whole run (before REF), e.g. to measure combinations.
	for sname in String(args.get("stack", "")).split(",", false):
		for v: Array in _variants():
			if v[0] == sname:
				(v[1] as Callable).call()
				print("PROBE stacked ", sname)
		await _frames(20)
	var results := {}
	var ref := {}
	for rep in reps:
		for v: Array in _variants():
			var vname: String = v[0]
			if not only.is_empty() and not vname in only and vname != "REF":
				continue
			var undo: Callable = (v[1] as Callable).call()
			await _frames(20)
			var line := "PROBE rep%d %-14s" % [rep, vname]
			var sum := 0.0
			var info := {}
			for p: Array in poses:
				_place(p)
				await _frames(10)
				var c := _cost()
				if args.has("shots"):
					DirAccess.make_dir_recursive_absolute(String(args["shots"]))
					view.get_texture().get_image().save_png(String(args["shots"]).path_join("%s_%s.png" % [vname, p[0]]))
				sum += c.ms
				info[p[0]] = c
				line += " %s=%6.2f" % [p[0], c.ms]
			var avg := sum / poses.size()
			if vname == "REF":
				ref = info
			line += " avg=%6.2f" % avg
			var dl := ""
			for p: Array in poses:
				if ref.has(p[0]):
					dl += " %+.2f" % (info[p[0]].ms - ref[p[0]].ms)
			line += "  delta[%s]" % dl.strip_edges()
			print(line)
			for p: Array in poses:
				var c: Dictionary = info[p[0]]
				print("PROBE_INFO rep%d %-14s %-13s ms=%6.2f cpu_ms=%5.2f vis_draws=%5d vis_prims=%8d vis_objs=%5d shd_draws=%5d shd_prims=%8d" % [
						rep, vname, p[0], c.ms, c.cpu, c.vd, c.vp, c.vo, c.sd, c.sp])
			results["%s_rep%d" % [vname, rep]] = info
			if undo.is_valid():
				undo.call()
			await _frames(10)
	if args.has("out"):
		var f := FileAccess.open(String(args["out"]), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(results, "  "))
	print("FOREST PROBE DONE")
	quit()


func _place(p: Array) -> void:
	var pos: Vector3 = p[1]
	var ground := FrontierTerrain.height_at(pos.x, pos.z)
	var eye := Vector3(pos.x, ground + pos.y, pos.z)
	var target: Vector3 = p[2]
	if p[3]:
		target = eye + target
	elif target.y < 10.0:
		target.y += FrontierTerrain.height_at(target.x, target.z)
	view.camera.global_position = eye
	view.camera.look_at(target)
	view.camera.fov = 70.0
	# player_near=1: the player stands 3 m ahead of the camera (as in play), so the near-player effects run
	# (grass trampling, pushed plants, the dappled crowns' sunflecks round player_position)
	if args.get("player_near", "0") == "1":
		var ahead: Vector3 = -view.camera.global_transform.basis.z
		ahead.y = 0.0
		var pp: Vector3 = eye + ahead.normalized() * 3.0
		level.get_node("Player").global_position = Vector3(pp.x, FrontierTerrain.height_at(pp.x, pp.z) + 0.05, pp.z)


func _cost() -> Dictionary:
	var vp := view.get_viewport_rid()
	for k in 5:
		RenderingServer.force_draw(false)
	var t := Time.get_ticks_usec()
	var cpu := 0.0
	for k in DRAWS:
		RenderingServer.force_draw(false)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	var ms := (Time.get_ticks_usec() - t) / 1000.0 / DRAWS
	return {
		"ms": ms,
		"cpu": cpu / DRAWS,
		"vd": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"vp": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"vo": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		"sd": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"sp": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
	}


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


## Hides every node under `parent_path` whose name starts with one of `prefixes`.
func _hide(parent_path: String, prefixes: Array) -> Callable:
	var parent := level.get_node_or_null(parent_path)
	var hidden: Array[Node3D] = []
	if parent == null:
		return Callable()
	for c in parent.get_children():
		for pf: String in prefixes:
			if String(c.name).begins_with(pf) and c is Node3D and (c as Node3D).visible:
				(c as Node3D).visible = false
				hidden.append(c)
				break
	return func() -> void:
		for n in hidden:
			n.visible = true


func _toggle_node(path: String) -> Callable:
	var n := level.get_node_or_null(path) as Node3D
	if n == null or not n.visible:
		return Callable()
	n.visible = false
	return func() -> void: n.visible = true


## The crown blobs (TreeShadow4_*) into SDFGI (as before the forest light, vegetation.gd gi_blobs()); the undo takes
## them out again.
func _gi_blobs(parent_path: String) -> Callable:
	var parent := level.get_node_or_null(parent_path)
	var moved: Array[GeometryInstance3D] = []
	if parent == null:
		return Callable()
	for c in parent.get_children():
		if String(c.name).begins_with("TreeShadow4_") and c is GeometryInstance3D:
			var g := c as GeometryInstance3D
			if g.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
				g.gi_mode = GeometryInstance3D.GI_MODE_STATIC
				moved.append(g)
	return func() -> void:
		for g in moved:
			g.gi_mode = GeometryInstance3D.GI_MODE_DISABLED


func _variants() -> Array:
	var veg := "Vegetation/Visuals"
	return [
		["REF", func() -> Callable: return Callable()],
		["veg_off", func() -> Callable: return _toggle_node(veg)],
		["lod0_off", func() -> Callable: return _hide(veg, ["TreeLod0_"])],
		["lod1_off", func() -> Callable: return _hide(veg, ["TreeLod1_"])],
		["lod2_off", func() -> Callable: return _hide(veg, ["TreeLod2_"])],
		["impostor_off", func() -> Callable: return _hide(veg, ["TreeImpostors_"])],
		["shd3_off", func() -> Callable: return _hide(veg, ["TreeShadow3_"])],
		["shd4_off", func() -> Callable: return _hide(veg, ["TreeShadow4_"])],
		["dapple_off", func() -> Callable: return _hide(veg, ["TreeDapple_"])],
		["canopy_terms_off", func() -> Callable:
			# the canopy's light terms neutral in every shader, the dappled crowns kept
			var fl: Node = rig.get("clock_driver").get("forest") if rig.get("clock_driver") else null
			if fl == null:
				return Callable()
			fl.set("enabled", false)
			RenderingServer.global_shader_parameter_set(&"canopy_light", Vector4.ZERO)
			RenderingServer.global_shader_parameter_set(&"leaf_glow", Vector4.ZERO)
			return func() -> void: fl.set("enabled", true)],
		["forest_light_off", func() -> Callable:
			# the canopy's light terms neutral in every shader (ForestLight stops writing them) and the dappled crowns hidden
			var fl: Node = rig.get("clock_driver").get("forest") if rig.get("clock_driver") else null
			if fl == null:
				return Callable()
			fl.set("enabled", false)
			RenderingServer.global_shader_parameter_set(&"canopy_light", Vector4.ZERO)
			RenderingServer.global_shader_parameter_set(&"leaf_glow", Vector4.ZERO)
			var unhide := _hide(veg, ["TreeDapple_"])
			return func() -> void:
				fl.set("enabled", true)
				unhide.call()],
		["gi_blobs_in", func() -> Callable: return _gi_blobs(veg)],
		["pre_forest_light", func() -> Callable:
			# the shadow and GI setup from before the forest light (run with veg_dapple=cards so the LOD3 cards exist):
			# the cards, no dappled crowns, no canopy terms, the crown blobs in SDFGI
			var fl: Node = rig.get("clock_driver").get("forest") if rig.get("clock_driver") else null
			if fl:
				fl.set("enabled", false)
			RenderingServer.global_shader_parameter_set(&"canopy_light", Vector4.ZERO)
			RenderingServer.global_shader_parameter_set(&"leaf_glow", Vector4.ZERO)
			var unhide := _hide(veg, ["TreeDapple_"])
			var gi_out := _gi_blobs(veg)
			return func() -> void:
				if fl:
					fl.set("enabled", true)
				unhide.call()
				gi_out.call()],
		["plants_off", func() -> Callable: return _hide(veg, ["Plant"])],
		["ferns_off", func() -> Callable: return _hide(veg, ["Fern"])],
		["props_off", func() -> Callable: return _hide(veg, ["Prop"])],
		["grass_off", func() -> Callable: return _toggle_node("Terrain/Grass")],
		["terrain_off", func() -> Callable: return _toggle_node("Terrain/Chunks")],
		["no_sdfgi", func() -> Callable:
			env.sdfgi_enabled = false
			return func() -> void: env.sdfgi_enabled = true],
		["no_volfog", func() -> Callable:
			var was := env.volumetric_fog_enabled
			env.volumetric_fog_enabled = false
			return func() -> void: env.volumetric_fog_enabled = was],
		["no_pcss", func() -> Callable:
			var a := sun.light_angular_distance
			sun.light_angular_distance = 0.0
			return func() -> void: sun.light_angular_distance = a],
		["soft_q1", func() -> Callable:
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
			return func() -> void: RenderingServer.directional_soft_shadow_filter_set_quality(rig.settings.soft_shadow_quality)],
		["pcf_q1_nopcss", func() -> Callable:
			var a := sun.light_angular_distance
			sun.light_angular_distance = 0.0
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			return func() -> void:
				sun.light_angular_distance = a
				RenderingServer.directional_soft_shadow_filter_set_quality(rig.settings.soft_shadow_quality)],
		["no_shadow", func() -> Callable:
			sun.shadow_enabled = false
			return func() -> void: sun.shadow_enabled = true],
		["shadow_100m", func() -> Callable:
			var d := sun.directional_shadow_max_distance
			sun.directional_shadow_max_distance = 100.0
			return func() -> void: sun.directional_shadow_max_distance = d],
		["splits2", func() -> Callable:
			var m := sun.directional_shadow_mode
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			return func() -> void: sun.directional_shadow_mode = m],
		["no_ssao", func() -> Callable:
			var was := env.ssao_enabled
			env.ssao_enabled = false
			return func() -> void: env.ssao_enabled = was],
		["no_taa", func() -> Callable:
			var was := view.use_taa
			view.use_taa = false
			return func() -> void: view.use_taa = was],
		["metalfx_075", func() -> Callable:
			var m := view.scaling_3d_mode
			var s := view.scaling_3d_scale
			var t := view.use_taa
			view.use_taa = false
			view.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL
			view.scaling_3d_scale = 0.75
			return func() -> void:
				view.scaling_3d_mode = m
				view.scaling_3d_scale = s
				view.use_taa = t],
		["metalfx_085", func() -> Callable:
			var m := view.scaling_3d_mode
			var s := view.scaling_3d_scale
			var t := view.use_taa
			view.use_taa = false
			view.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL
			view.scaling_3d_scale = 0.85
			return func() -> void:
				view.scaling_3d_mode = m
				view.scaling_3d_scale = s
				view.use_taa = t],
		["metalfx_080", func() -> Callable:
			var m := view.scaling_3d_mode
			var s := view.scaling_3d_scale
			var t := view.use_taa
			view.use_taa = false
			view.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL
			view.scaling_3d_scale = 0.8
			return func() -> void:
				view.scaling_3d_mode = m
				view.scaling_3d_scale = s
				view.use_taa = t],
		["fsr1_080_taa", func() -> Callable:
			var m := view.scaling_3d_mode
			var s := view.scaling_3d_scale
			view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			view.scaling_3d_scale = 0.8
			return func() -> void:
				view.scaling_3d_mode = m
				view.scaling_3d_scale = s],
		["no_glow", func() -> Callable:
			var was := env.glow_enabled
			env.glow_enabled = false
			return func() -> void: env.glow_enabled = was],
		["relod_12_30", func() -> Callable: return VegRelod.apply(level, 12.5, 30.0, 60.0)],
		["relod_12_25", func() -> Callable: return VegRelod.apply(level, 12.5, 25.0, 55.0)],
		["relod_16_30", func() -> Callable: return VegRelod.apply(level, 50.0 / 3.0, 30.0, 60.0)],
		["relod_12_30_nopcss", func() -> Callable:
			var u := VegRelod.apply(level, 12.5, 30.0, 60.0)
			var a := sun.light_angular_distance
			sun.light_angular_distance = 0.0
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			return func() -> void:
				u.call()
				sun.light_angular_distance = a
				RenderingServer.directional_soft_shadow_filter_set_quality(rig.settings.soft_shadow_quality)],
		["sky_color", func() -> Callable:
			var m := env.background_mode
			env.background_mode = Environment.BG_COLOR
			return func() -> void: env.background_mode = m],
	]
