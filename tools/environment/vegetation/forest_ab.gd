extends SceneTree
## Forest A/B cost probe (2026-09-24 "the forest is laggy" pass). Windowed; wrap it in a time
## limit, a script error leaves the window open:
##
##   Godot --path . --resolution 1600x900 -s tools/environment/vegetation/forest_ab.gd -- \
##       --no-capture [quality=high] [reps=2] [only=REF,veg_off,...] [poses=walk,run,turn,edge,deep] [shots=<dir>]
##
## The player stands at fixed forest poses on the benchmark's forest path (benchmark.gd
## forest_*_p segments: walk / sprint along the trunk-free heading from (-70, -55), turns at the
## densest spot, the edge look across the clearing from (-44, 2)) and the frame is rendered with
## the real third-person camera into an off-window SubViewport (offscreen_view.gd), exactly like
## benchmark.gd's cost probe: RenderingServer.force_draw(false), max(CPU render, GPU) per frame.
## Variants change the built vegetation at runtime (hide categories, thin instances, move LOD
## switch distances, swap shader variants), so every variant is compared with REF inside one
## run: on this shared Mac only interleaved A/B numbers are trustworthy.
##
## Lines: ABPROBE rep<k> <variant> ref_avg= var_avg= delta_avg= ref_max= var_max= | <group><delta>...
##        ABINFO <variant> <pose> ref= var= draws / prims (REF / variant)   (info=1)
## Ends with FOREST AB DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const DRAWS := 6
const BLOCKS := 3

## [name, feet xz, yaw deg (0 = north, +90 = west), pitch deg]
const POSES := [
	["walk_a", Vector2(-68.5, -53.7), 129.7, -3.0],
	["walk_b", Vector2(-64.6, -50.5), 129.7, 2.0],
	["walk_c", Vector2(-61.5, -48.0), 110.0, -3.0],
	["run_a", Vector2(-77.7, -48.6), 129.7, 0.0],
	["run_b", Vector2(-89.3, -39.0), 145.0, -3.0],
	["run_c", Vector2(-100.8, -29.4), 129.7, 2.0],
	["turn_n", Vector2(-85.3, -42.1), 0.0, 0.0],
	["turn_w", Vector2(-85.3, -42.1), 90.0, 5.0],
	["turn_s", Vector2(-85.3, -42.1), 180.0, -5.0],
	["turn_e", Vector2(-85.3, -42.1), 270.0, 0.0],
	["edge_c", Vector2(-44.0, 2.0), -90.0, 2.0],
	["edge_l", Vector2(-44.0, 2.0), -40.0, 2.0],
	["edge_r", Vector2(-44.0, 2.0), -140.0, 2.0],
	["deep_a", Vector2(-120.0, 60.0), 45.0, 0.0],
	["deep_b", Vector2(90.0, 90.0), 200.0, 0.0],
]

var args := {}
var view: SubViewport
var level: Node
var player: Node3D
var veg: Node
var rig: Node
var _shader_cache := {}
var _cur := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var reps := int(args.get("reps", "2"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	var groups: PackedStringArray = String(args.get("poses", "")).split(",", false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# The window would sit on the user's screen for minutes: minimise it (the off-window view still
	# renders and times correctly while the window cannot draw). minimize=0 keeps it.
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
	veg = level.get_node("Vegetation")
	rig = level.get_node("EnvironmentRig")
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.disable_3d = true
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	await _frames(60)

	var poses := []
	for p: Array in POSES:
		var g := String(p[0]).get_slice("_", 0)
		if groups.is_empty() or g in groups:
			poses.append(p)
	# Every variant is measured back-to-back with REF at each pose (REF, variant, REF, ...): the
	# machine's load drifts by several ms over a run, so only paired deltas are trustworthy.
	for rep in reps:
		for v: Array in _variants():
			var vname: String = v[0]
			if vname == "REF" or (not only.is_empty() and not vname in only):
				continue
			_cur = vname
			var line := "ABPROBE rep%d %-16s" % [rep, vname]
			var s_ref := 0.0
			var s_var := 0.0
			var m_ref := 0.0
			var m_var := 0.0
			var by_group := {}
			for p: Array in poses:
				await _place(p)
				var c0 := _cost()
				var undo: Callable = (v[1] as Callable).call()
				await _frames(4)
				var c1 := _cost()
				if undo.is_valid():
					undo.call()
				await _frames(2)
				var c2 := _cost()
				if c2.ms < c0.ms:
					c0 = c2
				undo = (v[1] as Callable).call()
				await _frames(2)
				var c3 := _cost()
				if c3.ms < c1.ms:
					c1 = c3
				if args.has("shots") and rep == 0:
					DirAccess.make_dir_recursive_absolute(String(args["shots"]))
					view.get_texture().get_image().save_png(String(args["shots"]).path_join("%s_%s.png" % [vname, p[0]]))
				if undo.is_valid():
					undo.call()
				s_ref += c0.ms
				s_var += c1.ms
				m_ref = maxf(m_ref, c0.ms)
				m_var = maxf(m_var, c1.ms)
				var g := String(p[0]).get_slice("_", 0)
				by_group[g] = by_group.get(g, 0.0) + (c1.ms - c0.ms)
				if args.get("info", "0") == "1":
					print("ABINFO %-16s %-7s ref=%6.2f var=%6.2f vis_draws=%5d/%5d vis_prims=%8d/%8d shd_draws=%5d/%5d shd_prims=%8d/%8d" % [
							vname, p[0], c0.ms, c1.ms, c0.vd, c1.vd, c0.vp, c1.vp, c0.sd, c1.sd, c0.sp, c1.sp])
			var n := float(poses.size())
			line += " ref_avg=%6.2f var_avg=%6.2f delta_avg=%+6.2f ref_max=%6.2f var_max=%6.2f |" % [s_ref / n, s_var / n, (s_var - s_ref) / n, m_ref, m_var]
			for g: String in by_group:
				line += " %s%+.2f" % [g, by_group[g] / float(_count(poses, g))]
			print(line)
	print("FOREST AB DONE")
	quit()


func _count(poses: Array, g: String) -> int:
	var n := 0
	for p: Array in poses:
		if String(p[0]).get_slice("_", 0) == g:
			n += 1
	return maxi(n, 1)


func _place(p: Array) -> void:
	var xz: Vector2 = p[1]
	player.global_position = Vector3(xz.x, FrontierTerrain.height_at(xz.x, xz.y) + 0.05, xz.y)
	player.set("velocity", Vector3.ZERO)
	player.set("yaw", deg_to_rad(float(p[2])))
	player.set("pitch", deg_to_rad(float(p[3])))
	await _frames(8)
	var cam: Camera3D = player.get("camera")
	view.source = cam
	view.sync_camera()


## Render cost of the current view: the minimum over BLOCKS blocks of DRAWS forced draws (the
## minimum rejects the other processes' spikes on this shared machine).
func _cost() -> Dictionary:
	var vp := view.get_viewport_rid()
	for k in 3:
		RenderingServer.force_draw(false)
	var ms := INF
	for b in BLOCKS:
		var t := Time.get_ticks_usec()
		for k in DRAWS:
			RenderingServer.force_draw(false)
		ms = minf(ms, (Time.get_ticks_usec() - t) / 1000.0 / DRAWS)
	return {
		"ms": ms,
		"vd": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"vp": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"sd": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"sp": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
	}


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


func _mmis(prefixes: Array, key_filter := Callable()) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	var vis := veg.get_node_or_null("Visuals")
	if vis == null:
		return out
	for c in vis.get_children():
		if not c is MultiMeshInstance3D or not (c as Node3D).visible:
			continue
		var n := String(c.name)
		for pf: String in prefixes:
			if n.begins_with(pf) and (not key_filter.is_valid() or key_filter.call(n)):
				out.append(c)
				break
	return out


func _hide(prefixes: Array, key_filter := Callable()) -> Callable:
	var hidden := _mmis(prefixes, key_filter)
	for n in hidden:
		n.visible = false
	return func() -> void:
		for n in hidden:
			n.visible = true


## Tree LOD node name TreeLod<l>_<cx>_<cz>_<key>_<sx>_<sz>: key = kind * 4 + variant.
static func _kind_of(n: String) -> int:
	var parts := n.split("_")
	return int(parts[3]) / 4 if parts.size() > 3 else -1


## Keeps only a fraction of the instances of the matching MultiMeshes (the layout order is
## spatially shuffled enough to act as uniform thinning).
func _thin(prefixes: Array, keep: float) -> Callable:
	var nodes := _mmis(prefixes)
	var was := {}
	for n in nodes:
		var mm := n.multimesh
		was[n] = mm.visible_instance_count
		mm.visible_instance_count = int(ceil(mm.instance_count * keep))
	return func() -> void:
		for n: MultiMeshInstance3D in was:
			n.multimesh.visible_instance_count = was[n]


## Sets the far visibility end of the matching MultiMeshes.
func _range_end(prefixes: Array, end: float) -> Callable:
	var saved := {}
	for n in _mmis(prefixes):
		saved[n] = n.visibility_range_end
		n.visibility_range_end = end
	return func() -> void:
		for n: MultiMeshInstance3D in saved:
			n.visibility_range_end = saved[n]


## Moves the tree LOD0 / LOD1 switch distance to d0 (LOD1 -> LOD2 stays).
func _lod0_end(d0: float) -> Callable:
	var saved := {}
	for n in _mmis(["TreeLod0_", "TreeLod1_"]):
		saved[n] = [n.visibility_range_begin, n.visibility_range_end]
		if String(n.name).begins_with("TreeLod0_"):
			n.visibility_range_end = d0
		else:
			n.visibility_range_begin = d0
	return func() -> void:
		for n: MultiMeshInstance3D in saved:
			n.visibility_range_begin = saved[n][0]
			n.visibility_range_end = saved[n][1]


## Swaps the tree shader of every tree material for a variant of its code (edit: Callable on the
## source string), keeping the parameters.
func _tree_shader(edit: Callable) -> Callable:
	var mats := {}
	for n in _mmis(["TreeLod", "Plant"]):
		var m := n.material_override as ShaderMaterial
		if m and not mats.has(m):
			mats[m] = m.shader
	if mats.is_empty():
		return Callable()
	var base: Shader = mats.values()[0]
	var key := _cur
	if not _shader_cache.has(key):
		var nsh := Shader.new()
		nsh.code = edit.call(base.code)
		_shader_cache[key] = nsh
	var sh: Shader = _shader_cache[key]
	for m: ShaderMaterial in mats:
		m.shader = sh
	return func() -> void:
		for m: ShaderMaterial in mats:
			m.shader = mats[m]


func _param(name: String, value: Variant) -> Callable:
	var mats := {}
	for n in _mmis(["TreeLod", "Plant"]):
		var m := n.material_override as ShaderMaterial
		if m and not mats.has(m):
			mats[m] = m.get_shader_parameter(name)
	for m: ShaderMaterial in mats:
		m.set_shader_parameter(name, value)
	return func() -> void:
		for m: ShaderMaterial in mats:
			m.set_shader_parameter(name, mats[m])


func _variants() -> Array:
	var conifer := func(n: String) -> bool: return _kind_of(n) in [0, 1]
	var broadleaf := func(n: String) -> bool: return _kind_of(n) in [2, 3, 4]
	return [
		["REF", func() -> Callable: return Callable()],
		["veg_off", func() -> Callable:
			var v := veg.get_node("Visuals") as Node3D
			v.visible = false
			return func() -> void: v.visible = true],
		["trees_off", func() -> Callable: return _hide(["TreeLod", "TreeImpostors_", "TreeShadow"])],
		["lod0_off", func() -> Callable: return _hide(["TreeLod0_"])],
		["lod1_off", func() -> Callable: return _hide(["TreeLod1_"])],
		["lod2imp_off", func() -> Callable: return _hide(["TreeLod2_", "TreeImpostors_"])],
		["conif_lod01_off", func() -> Callable: return _hide(["TreeLod0_", "TreeLod1_"], conifer)],
		["broad_lod01_off", func() -> Callable: return _hide(["TreeLod0_", "TreeLod1_"], broadleaf)],
		["tree_shd_off", func() -> Callable: return _hide(["TreeShadow"])],
		["shd3_off", func() -> Callable: return _hide(["TreeShadow3_"])],
		["plants_off", func() -> Callable: return _hide(["Plant"])],
		["ferns_off", func() -> Callable: return _hide(["Fern"])],
		["props_off", func() -> Callable: return _hide(["Prop"])],
		["grass_off", func() -> Callable:
			var g := level.get_node_or_null("Terrain/Grass") as Node3D
			if g == null:
				return Callable()
			g.visible = false
			return func() -> void: g.visible = true],
		["blob_end_60", func() -> Callable: return _range_end(["TreeShadow4_"], 60.0)],
		["blob_end_90", func() -> Callable: return _range_end(["TreeShadow4_"], 90.0)],
		["thin_trees_70", func() -> Callable: return _thin(["TreeLod", "TreeShadow"], 0.7)],
		["lod0_20", func() -> Callable: return _lod0_end(20.0)],
		["lod0_40", func() -> Callable: return _lod0_end(40.0)],
		["alpha_cut_55", func() -> Callable: return _param("alpha_cut", 0.55)],
		["no_leaf_nmap", func() -> Callable: return _tree_shader(func(c: String) -> String:
			return c.replace("NORMAL_MAP = s.normal_map;", "").replace("NORMAL_MAP_DEPTH = s.normal_depth;", ""))],
		["no_backlight", func() -> Callable: return _tree_shader(func(c: String) -> String:
			return c.replace("BACKLIGHT = s.albedo * backlight_strength;", ""))],
		["lambert_nospec", func() -> Callable: return _tree_shader(func(c: String) -> String:
			return c.replace("diffuse_burley, specular_schlick_ggx", "diffuse_lambert, specular_disabled"))],
		["near_fade_25", func() -> Callable: return _tree_shader(func(c: String) -> String:
			return c.replace("TreeSurface s = tree_surface(UV, dx, dy, v_col, v_custom, v_height);",
				"TreeSurface s = tree_surface(UV, dx, dy, v_col, v_custom, v_height);\n\tif (s.leaf && length(VERTEX) < 2.5) { discard; }"))],
		["no_discard_kw", func() -> Callable: return _tree_shader(func(c: String) -> String:
			return c.replace("if (s.alpha < alpha_cut) {\n\t\tdiscard;\n\t}", ""))],
	]
