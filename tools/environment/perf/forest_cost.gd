extends SceneTree
## Forest cost probe for the invisible performance pass (2026-09-25). Windowed; wrap it in a
## time limit (a script error leaves the window open):
##
##   Godot --path . --resolution 1600x900 -s tools/environment/perf/forest_cost.gd -- --no-capture \
##       [quality=high] [reps=1] [only=v1,v2] [poses=hot,bench,u10,...] [info=1] [shots=<dir>]
##
## Poses: the benchmark's free-camera forest_walk poses (bench_walk0..5, the worst ones of
## benchmark.gd), the player-camera forest path poses (walk / run / turn / edge, the same spots
## as forest_ab.gd), the fort gameplay view and the u10 reference viewpoints of scenic_shots.gd.
## Every variant is measured back-to-back with REF at each pose (REF, variant, REF, variant; the
## minimum of each pair of blocks), because the load of this shared Mac drifts over a run.
## Cost = RenderingServer.force_draw(false) into an off-window SubViewport of the window's size
## (offscreen_view.gd), i.e. max(CPU render, GPU) per frame, as in benchmark.gd.
##
## Lines: COST rep<k> <variant> ref_avg= var_avg= delta_avg= ref_max= var_max= | <group><delta> ...
##        COSTINFO <variant> <pose> ref= var= vis_draws vis_prims shd_draws shd_prims (REF/variant)
## Ends with FOREST COST DONE. Pose groups for poses=: hot (bench, walk, run, turn), forest (+ edge),
## u10, inplant (free camera inside saplings / shrubs, for the near-camera leaf fade), fort_look.
##
## Findings of the 2026-09-25 pass (1600x900, high; details in the variants' comments below):
##   veg_off -12.8 ms (vegetation = 13 of ~21 ms at the hot poses); no_sun_shadow -9.3; tree_shd_off
##   -4.8 (shadow proxies, incl. the cheaper shading of unshadowed pixels); no_fade_lods -2.5 average,
##   up to -11 at the worst poses (the tree LOD / impostor nodes inside their fade band go to the
##   TRANSPARENT pass; the fade itself never shows on these alpha-scissor materials, but switching it
##   off changes how the band trees are composited: ~2.5 % of the reference pixels, see ab_shots.gd);
##   no_prepass +4.4 in the forest (-4.4 at the fort); no_occlusion, prio_*, no_fade_shadow,
##   no_fade_small, small_off: within +-0.5.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const DRAWS := 6
const BLOCKS := 3

## Free-camera poses: [name, "F", position, look-at target, fov]. Player poses: [name, "P",
## feet xz, yaw deg (0 = north, +90 = west), pitch deg].
const POSES := [
	# benchmark.gd forest_walk (F) at t = (i + 0.5) / 6.
	["bench_walk0", "F", Vector3(-42.5, 1.7, -42.08), 30.0, 70.0],
	["bench_walk1", "F", Vector3(-47.5, 1.7, -46.25), 90.0, 70.0],
	["bench_walk2", "F", Vector3(-52.5, 1.7, -50.42), 150.0, 70.0],
	["bench_walk4", "F", Vector3(-62.5, 1.7, -58.75), 270.0, 70.0],
	["bench_walk5", "F", Vector3(-67.5, 1.7, -62.92), 330.0, 70.0],
	# The player on the benchmark's forest path (forest_ab.gd).
	["walk_a", "P", Vector2(-68.5, -53.7), 129.7, -3.0],
	["walk_c", "P", Vector2(-61.5, -48.0), 110.0, -3.0],
	["run_a", "P", Vector2(-77.7, -48.6), 129.7, 0.0],
	["run_b", "P", Vector2(-89.3, -39.0), 145.0, -3.0],
	["run_c", "P", Vector2(-100.8, -29.4), 129.7, 2.0],
	["turn_n", "P", Vector2(-85.3, -42.1), 0.0, 0.0],
	["turn_w", "P", Vector2(-85.3, -42.1), 90.0, 5.0],
	["turn_s", "P", Vector2(-85.3, -42.1), 180.0, -5.0],
	["edge_c", "P", Vector2(-44.0, 2.0), -90.0, 2.0],
	["fort_look", "P", Vector2(0.0, 6.0), 0.0, 0.0],
	# scenic_shots.gd u10 viewpoints (target point instead of yaw).
	["u10_spawn_gate", "T", Vector3(1.4, 1.7, 4.0), Vector3(0.0, 1.4, -45.0), 60.0],
	["u10_firing_line", "T", Vector3(-1.2, 1.7, -18.5), Vector3(0.0, 1.2, -110.0), 55.0],
	["u10_range_lookback", "T", Vector3(5.0, 1.7, -118.0), Vector3(0.0, 2.8, -16.0), 50.0],
	["u10_forest", "T", Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), 65.0],
	["u10_parade", "T", Vector3(7.0, 1.7, 11.0), Vector3(-8.0, 2.4, 3.0), 65.0],
	["u10_aerial", "T", Vector3(48.0, 30.0, 48.0), Vector3(0.0, 0.0, -22.0), 55.0],
	# Camera inside undergrowth (the near-camera leaf fade): [name, "S", k-th sapling / shrub west of
	# the fort (x < -40), camera height above its base (m), yaw deg]; the camera stands 0.5 m from
	# the plant's axis, looking across it, fov 70.
	["inplant_0", "S", 0, 1.3, 30.0],
	["inplant_1", "S", 7, 1.5, 120.0],
	["inplant_2", "S", 15, 1.1, 250.0],
	["inplant_3", "S", 23, 1.6, 300.0],
	["inplant_4", "S", 31, 1.2, 60.0],
	["inplant_5", "S", 40, 1.4, 190.0],
]
const GROUPS := {"hot": ["bench", "walk", "run", "turn"], "forest": ["bench", "walk", "run", "turn", "edge"],
		"u10": ["u10"], "inplant": ["inplant"]}

var args := {}
var view: SubViewport
var level: Node
var player: Node3D
var veg: Node
var rig: Node
var cam: Camera3D
var _cache := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var reps := int(args.get("reps", "1"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	var groups: PackedStringArray = String(args.get("poses", "hot")).split(",", false)
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
	veg = level.get_node("Vegetation")
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
	await _frames(60)
	print("COSTENV vendor=%s adapter=%s prepass=%s disable_for_vendors=%s occlusion=%s" % [RenderingServer.get_video_adapter_vendor(),
			RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/driver/depth_prepass/enable"),
			ProjectSettings.get_setting("rendering/driver/depth_prepass/disable_for_vendors"), view.use_occlusion_culling])

	var poses := []
	for p: Array in POSES:
		var g := String(p[0]).get_slice("_", 0)
		var want := groups.is_empty()
		for gg: String in groups:
			if gg == g or gg == String(p[0]) or (GROUPS.has(gg) and g in GROUPS[gg]):
				want = true
		if want:
			poses.append(p)
	for rep in reps:
		for v: Array in _variants():
			var vname: String = v[0]
			if vname == "REF" or (not only.is_empty() and not vname in only):
				continue
			var line := "COST rep%d %-18s" % [rep, vname]
			var s_ref := 0.0
			var s_var := 0.0
			var m_ref := 0.0
			var m_var := 0.0
			var by_group := {}
			var n_group := {}
			for p: Array in poses:
				await _place(p)
				var c0 := _cost()
				var undo: Callable = (v[1] as Callable).call()
				await _frames(4)
				var c1 := _cost()
				if args.has("shots") and rep == 0:
					DirAccess.make_dir_recursive_absolute(String(args["shots"]))
					view.get_texture().get_image().save_png(String(args["shots"]).path_join("%s_%s.png" % [vname, p[0]]))
				if undo.is_valid():
					undo.call()
				await _frames(2)
				var c2 := _cost()
				if args.has("shots") and rep == 0 and not FileAccess.file_exists(String(args["shots"]).path_join("REF_%s.png" % p[0])):
					view.get_texture().get_image().save_png(String(args["shots"]).path_join("REF_%s.png" % p[0]))
				if c2.ms < c0.ms:
					c0 = c2
				undo = (v[1] as Callable).call()
				await _frames(2)
				var c3 := _cost()
				if c3.ms < c1.ms:
					c1 = c3
				if undo.is_valid():
					undo.call()
				await _frames(1)
				s_ref += c0.ms
				s_var += c1.ms
				m_ref = maxf(m_ref, c0.ms)
				m_var = maxf(m_var, c1.ms)
				var g := String(p[0]).get_slice("_", 0)
				by_group[g] = by_group.get(g, 0.0) + (c1.ms - c0.ms)
				n_group[g] = n_group.get(g, 0) + 1
				if args.get("info", "0") == "1":
					print("COSTINFO %-18s %-18s ref=%6.2f var=%6.2f vis_draws=%5d/%5d vis_prims=%8d/%8d shd_draws=%5d/%5d shd_prims=%8d/%8d" % [
							vname, p[0], c0.ms, c1.ms, c0.vd, c1.vd, c0.vp, c1.vp, c0.sd, c1.sd, c0.sp, c1.sp])
			var n := float(poses.size())
			line += " ref_avg=%6.2f var_avg=%6.2f delta_avg=%+6.2f ref_max=%6.2f var_max=%6.2f |" % [s_ref / n, s_var / n, (s_var - s_ref) / n, m_ref, m_var]
			for g: String in by_group:
				line += " %s%+.2f" % [g, by_group[g] / float(n_group[g])]
			print(line)
	print("FOREST COST DONE")
	quit()


func _place(p: Array) -> void:
	match String(p[1]):
		"P":
			var xz: Vector2 = p[2]
			player.global_position = Vector3(xz.x, FrontierTerrain.height_at(xz.x, xz.y) + 0.05, xz.y)
			player.set("velocity", Vector3.ZERO)
			player.set("yaw", deg_to_rad(float(p[3])))
			player.set("pitch", deg_to_rad(float(p[4])))
			await _frames(8)
			view.source = player.get("camera")
			view.sync_camera()
		"F":
			var pos: Vector3 = p[2]
			var yaw := deg_to_rad(float(p[3]))
			cam.fov = float(p[4])
			_look(pos, pos + Vector3(-sin(yaw), -0.05, -cos(yaw)))
			await _frames(4)
			view.source = cam
			view.sync_camera()
		"T":
			cam.fov = float(p[4])
			_look(p[2], p[3])
			await _frames(4)
			view.source = cam
			view.sync_camera()
		"S":
			var base := _plant(int(p[2]))
			var yaw := deg_to_rad(float(p[4]))
			var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var pos := base + Vector3(0.0, float(p[3]), 0.0) - fwd * 0.5
			cam.fov = 70.0
			cam.global_position = pos
			cam.look_at(pos + fwd * 10.0 + Vector3(0.0, -0.3, 0.0))
			await _frames(4)
			view.source = cam
			view.sync_camera()
	await _frames(2)


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


## Base of the k-th sapling / shrub of the layout west of the fort (x < -40, forest side).
func _plant(k: int) -> Vector3:
	var layout: Variant = veg.get("layout")
	var n := 0
	var pos: PackedVector3Array = layout.plant_pos
	for i in pos.size():
		if pos[i].x < -40.0 and pos[i].z > -120.0 and pos[i].z < 40.0:
			if n == k:
				return pos[i]
			n += 1
	return pos[0]


## Every foliage ShaderMaterial of the vegetation that has the near-camera fade uniforms.
func _near_fade_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for c in veg.get_node("Visuals").get_children():
		var m := (c as GeometryInstance3D).material_override as ShaderMaterial
		if m and not m in out and m.shader:
			for u in m.shader.get_shader_uniform_list():
				if u.name == "near_fade_end":
					out.append(m)
					break
	return out


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


func _mmis(prefixes: Array) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	var vis := veg.get_node_or_null("Visuals")
	if vis == null:
		return out
	for c in vis.get_children():
		if not c is MultiMeshInstance3D or not (c as Node3D).visible:
			continue
		var n := String(c.name)
		for pf: String in prefixes:
			if n.begins_with(pf):
				out.append(c)
				break
	return out


func _hide(prefixes: Array) -> Callable:
	var hidden := _mmis(prefixes)
	for n in hidden:
		n.visible = false
	return func() -> void:
		for n in hidden:
			n.visible = true


## Gives the matching MultiMeshes a duplicate of their material with render_priority = prio
## (identical parameters, so identical pixels; only the draw order may change).
func _priority(prefixes: Array, prio: int) -> Callable:
	var saved := {}
	var dup := {}
	for n in _mmis(prefixes):
		var m := n.material_override
		if m == null:
			continue
		var key := "%d_%d" % [m.get_instance_id(), prio]
		if not dup.has(key):
			var d := m.duplicate() as Material
			d.render_priority = prio
			dup[key] = d
		saved[n] = m
		n.material_override = dup[key]
	return func() -> void:
		for n: MultiMeshInstance3D in saved:
			n.material_override = saved[n]


func _env_toggle(prop: String, value: Variant) -> Callable:
	var env: Environment = rig.get_environment()
	var was: Variant = env.get(prop)
	env.set(prop, value)
	return func() -> void: env.set(prop, was)


func _variants() -> Array:
	return [
		["REF", func() -> Callable: return Callable()],
		# Diagnosis (not candidates: they change the picture).
		["veg_off", func() -> Callable:
			var v := veg.get_node("Visuals") as Node3D
			v.visible = false
			return func() -> void: v.visible = true],
		["lod0_off", func() -> Callable: return _hide(["TreeLod0_"])],
		["lod1_off", func() -> Callable: return _hide(["TreeLod1_"])],
		["lod2_off", func() -> Callable: return _hide(["TreeLod2_"])],
		["lod2imp_off", func() -> Callable: return _hide(["TreeLod2_", "TreeImpostors_"])],
		["tree_shd_off", func() -> Callable: return _hide(["TreeShadow"])],
		["shd3_off", func() -> Callable: return _hide(["TreeShadow3_"])],
		["shd4_off", func() -> Callable: return _hide(["TreeShadow4_"])],
		["small_off", func() -> Callable: return _hide(["Plant", "Fern", "Prop"])],
		["grass_off", func() -> Callable:
			var g := level.get_node_or_null("Terrain/Grass") as Node3D
			if g == null:
				return Callable()
			g.visible = false
			return func() -> void: g.visible = true],
		["no_sun_shadow", func() -> Callable:
			var sun: DirectionalLight3D = rig.get_sun()
			sun.shadow_enabled = false
			return func() -> void: sun.shadow_enabled = true],
		["no_sdfgi", func() -> Callable: return _env_toggle("sdfgi_enabled", false)],
		["no_ssao", func() -> Callable: return _env_toggle("ssao_enabled", false)],
		["no_taa", func() -> Callable:
			var was := view.use_taa
			view.use_taa = false
			return func() -> void: view.use_taa = was],
		# Candidates (identical pixels): draw order through material render_priority.
		["prio_near_first", func() -> Callable:
			var u0 := _priority(["TreeLod0_", "Plant0_", "Fern0_"], 3)
			var u1 := _priority(["TreeLod1_", "Plant1_", "Fern1_"], 2)
			var u2 := _priority(["TreeLod2_"], 1)
			return func() -> void:
				u0.call()
				u1.call()
				u2.call()],
		["prio_near_last", func() -> Callable:
			var u0 := _priority(["TreeLod0_", "Plant0_", "Fern0_"], -3)
			var u1 := _priority(["TreeLod1_", "Plant1_", "Fern1_"], -2)
			var u2 := _priority(["TreeLod2_"], -1)
			return func() -> void:
				u0.call()
				u1.call()
				u2.call()],
		["prio_imp_last", func() -> Callable: return _priority(["TreeImpostors_"], -5)],
		["prio_imp_first", func() -> Callable: return _priority(["TreeImpostors_"], 5)],
		# Diagnosis: the visibility-range fades (pops instead of 5 m cross-fades).
		["no_fade_all", func() -> Callable: return _fade(["Tree", "Plant", "Fern", "Prop"])],
		["no_fade_lods", func() -> Callable: return _fade(["TreeLod", "TreeImpostors_"])],
		["no_fade_shadow", func() -> Callable: return _fade(["TreeShadow"])],
		["no_fade_small", func() -> Callable: return _fade(["Plant", "Fern", "Prop"])],
		["no_prepass", func() -> Callable:
			ProjectSettings.set_setting("rendering/driver/depth_prepass/enable", false)
			return func() -> void: ProjectSettings.set_setting("rendering/driver/depth_prepass/enable", true)],
		["prepass_all_vendors", func() -> Callable:
			var was: Variant = ProjectSettings.get_setting("rendering/driver/depth_prepass/disable_for_vendors")
			ProjectSettings.set_setting("rendering/driver/depth_prepass/disable_for_vendors", "")
			ProjectSettings.set_setting("rendering/driver/depth_prepass/enable", true)
			return func() -> void: ProjectSettings.set_setting("rendering/driver/depth_prepass/disable_for_vendors", was)],
		# The near-camera leaf fade (shaders/vegetation/near_fade.gdshaderinc) switched off, i.e. the
		# look before 2026-09-25: delta = what the fade saves (negative = the fade is cheaper).
		["near_fade_off", func() -> Callable:
			var mats := _near_fade_materials()
			var was := {}
			for m in mats:
				was[m] = [m.get_shader_parameter("near_fade_begin"), m.get_shader_parameter("near_fade_end")]
				m.set_shader_parameter("near_fade_begin", 0.0)
				m.set_shader_parameter("near_fade_end", 0.0)
			return func() -> void:
				for m: ShaderMaterial in was:
					m.set_shader_parameter("near_fade_begin", was[m][0])
					m.set_shader_parameter("near_fade_end", was[m][1])],
		# Tree LOD / impostor switching without Godot's FADE_SELF (NOT invisible: see ab_shots.gd, the
		# band trees change; measured for the report). hard_switch: switch at the band centre, no
		# overlap; overlap_band: both LODs over [begin - margin, end + margin], opaque pass.
		["hard_switch", func() -> Callable: return _lod_switch(0.0)],
		["overlap_band", func() -> Callable: return _lod_switch(1.0)],
		["no_occlusion", func() -> Callable:
			var was := view.use_occlusion_culling
			view.use_occlusion_culling = false
			return func() -> void: view.use_occlusion_culling = was],
	]


func _lod_switch(k: float) -> Callable:
	var saved := {}
	for n in _mmis(["TreeLod", "TreeImpostors_"]):
		saved[n] = [n.visibility_range_begin, n.visibility_range_end, n.visibility_range_begin_margin,
				n.visibility_range_end_margin, n.visibility_range_fade_mode]
		if n.visibility_range_begin > 0.0:
			n.visibility_range_begin = maxf(n.visibility_range_begin - k * n.visibility_range_begin_margin, 0.001)
		if n.visibility_range_end > 0.0:
			n.visibility_range_end += k * n.visibility_range_end_margin
		n.visibility_range_begin_margin = 0.0
		n.visibility_range_end_margin = 0.0
		n.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return func() -> void:
		for n: MultiMeshInstance3D in saved:
			var sv: Array = saved[n]
			n.visibility_range_begin = sv[0]
			n.visibility_range_end = sv[1]
			n.visibility_range_begin_margin = sv[2]
			n.visibility_range_end_margin = sv[3]
			n.visibility_range_fade_mode = sv[4]


func _fade(prefixes: Array) -> Callable:
	var saved := {}
	for n in _mmis(prefixes):
		saved[n] = n.visibility_range_fade_mode
		n.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return func() -> void:
		for n: MultiMeshInstance3D in saved:
			n.visibility_range_fade_mode = saved[n]
