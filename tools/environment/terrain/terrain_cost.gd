extends SceneTree
## Package B cost probe: the GPU/CPU render cost of the terrain and of the grass, measured
## A/B inside one run at fixed poses. Needs a window (not --headless); wrap it in a time limit.
##
##   Godot --path . --resolution 1600x900 -s tools/environment/terrain/terrain_cost.gd -- \
##       --no-capture [quality=high|medium|low] [reps=5] [out=<json>]
##
## Why not only benchmark.gd: on this Mac other processes (the other workflows' renders and
## Blender bakes) share the GPU, and back-to-back benchmark runs drift by more than the
## effect being measured. Here the three states are interleaved at every pose and repeated,
## so slow drifts cancel; the per-state minimum over the repetitions (the least contended
## sample) gives the costs, medians are printed alongside.
##   full     terrain chunks + grass (as shipped)
##   nograss  grass hidden                                  grass cost   = full - nograss
##   flat     grass and chunks hidden, the old flat plane    terrain cost = nograss - flat
## Diagnostic states (states=full,nograss,flat,noshadow,simple):
##   noshadow grass hidden, chunks not casting shadows       shadow share = nograss - noshadow
##   simple   grass hidden, chunks with a trivial fragment   pixel share  = nograss - simple
##   noaniso  grass hidden, albedo array without anisotropic filtering
##   lowshadow grass hidden, 4 m shadow proxies, LOD2/3 not casting
##   farshadow grass hidden, only LOD2/3 (220 m+) casting
##   grass_half   grass at half density (density_scale 0.5; hidden tufts still run the vertex early-out)
##   grass_opaque grass with an opaque trivial fragment (no alpha test, no lighting inputs)
## Frame cost = force_draw(false) of an off-window 1600x900 SubViewport (the same method and
## caveats as benchmark.gd's cost probe). Also prints main-pass and shadow-pass primitives.
## Ends with TERRAIN COST DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

const POSES := [
	# name, camera, target, fov
	["fort_range", Vector3(0.0, 2.3, 9.6), Vector3(0.0, 1.2, -45.0), 70.0],
	["firing_line", Vector3(-1.2, 1.7, -18.5), Vector3(0.0, 1.2, -110.0), 70.0],
	["range_lookback", Vector3(5.0, 1.7, -118.0), Vector3(0.0, 2.8, -16.0), 70.0],
	["meadow", Vector3(-21.0, 1.7, 2.0), Vector3(-60.0, 0.5, 22.0), 70.0],
	["forest", Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), 70.0],
	["aerial", Vector3(48.0, 30.0, 48.0), Vector3(0.0, 0.0, -22.0), 70.0],
]
var STATES := ["full", "nograss", "flat"]
const DRAWS := 12

var args := {}
var view: SubViewport
var terrain: Node3D
var flat: MeshInstance3D
var simple_mat: ShaderMaterial
var noaniso_mat: ShaderMaterial
var mesh_orig := {}
var grass_mat: ShaderMaterial
var grass_opaque_mat: ShaderMaterial
var mesh_4m: Mesh
var cast_orig := {}
var shipped_mat: ShaderMaterial


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var reps := int(args.get("reps", "5"))
	if args.has("states"):
		STATES = Array(String(args.states).split(",", false))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode_sleep_usec = 0
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: Node = current_scene.get_node("Player")
	player.set("ignore_mouse_capture", true)
	player.set_process(false)
	player.set_physics_process(false)
	terrain = current_scene.get_node("Terrain")
	view = OffscreenView.new()
	view.name = "TerrainCostView"
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true

	flat = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800, 800)
	flat.mesh = plane
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.4, 0.2)
	flat.material_override = m
	flat.visible = false
	current_scene.add_child(flat)
	var chunks := terrain.get_node_or_null("Chunks")
	if chunks:
		for c: GeometryInstance3D in chunks.get_children():
			cast_orig[c] = c.cast_shadow
			mesh_orig[c] = (c as MeshInstance3D).mesh
		mesh_4m = FrontierTerrain.grid_mesh(4)
	var gnode: Node = terrain.get("grass")
	if gnode:
		grass_mat = gnode.get("material")
		if "grass_opaque" in STATES:
			var gcode: String = (load("res://shaders/grass/grass.gdshader") as Shader).code
			var sh3 := Shader.new()
			sh3.code = gcode.substr(0, gcode.find("void fragment()")) + "void fragment() { ALBEDO = vec3(0.3, 0.35, 0.15); }\n"
			grass_opaque_mat = grass_mat.duplicate()
			grass_opaque_mat.shader = sh3
	if chunks and "noaniso" in STATES:
		var code2: String = (load("res://shaders/terrain/terrain.gdshader") as Shader).code
		var sh2 := Shader.new()
		sh2.code = code2.replace("filter_linear_mipmap_anisotropic", "filter_linear_mipmap")
		noaniso_mat = (terrain.get("material") as ShaderMaterial).duplicate()
		noaniso_mat.shader = sh2
		shipped_mat = terrain.get("material")
	if chunks and "simple" in STATES:
		var code: String = (load("res://shaders/terrain/terrain.gdshader") as Shader).code
		code = code.substr(0, code.find("void fragment()")) + "void fragment() { ALBEDO = vec3(0.35, 0.3, 0.2); }\n"
		var sh := Shader.new()
		sh.code = code
		simple_mat = (terrain.get("material") as ShaderMaterial).duplicate()
		simple_mat.shader = sh
		shipped_mat = terrain.get("material")

	# Warm-up: compile pipelines for every state at every pose.
	for p: Array in POSES:
		for s: String in STATES:
			await _apply(p, s)
	var samples := {}
	for rep in reps:
		for p: Array in POSES:
			for s: String in STATES:
				await _apply(p, s)
				var key := "%s/%s" % [p[0], s]
				if not samples.has(key):
					samples[key] = []
				samples[key].append(_measure())
	var out := {}
	print("TCOST info window=%s quality=%s reps=%d" % [DisplayServer.window_get_size(), args.get("quality", "(default)"), reps])
	for p: Array in POSES:
		var row := {}
		for s: String in STATES:
			var ms: Array = samples["%s/%s" % [p[0], s]].map(func(r): return r[0])
			ms.sort()
			var last: Array = samples["%s/%s" % [p[0], s]][-1]
			row[s] = {"ms": ms[ms.size() / 2], "ms_min": ms[0], "prims": last[1], "shadow_prims": last[2],
					"draws": last[3], "shadow_draws": last[4], "objects": last[5]}
		# The minimum over repetitions is the least-contended estimate (other processes only
		# ever add time); the medians are kept in the JSON.
		row["grass_ms"] = row.full.ms_min - row.nograss.ms_min
		row["terrain_ms"] = row.nograss.ms_min - row.flat.ms_min
		var extra := ""
		for s: String in STATES:
			if not s in ["full", "nograss", "flat"]:
				extra += " %s=%.2f" % [s, row[s].ms_min]
		extra += " | draws main %d/%d/%d shadow %d/%d/%d objs %d/%d/%d" % [row.full.draws, row.nograss.draws, row.flat.draws,
				row.full.shadow_draws, row.nograss.shadow_draws, row.flat.shadow_draws, row.full.objects, row.nograss.objects, row.flat.objects]
		if extra != "":
			print("TCOST pose=%-15s diag:%s" % [p[0], extra])
		out[p[0]] = row
		print("TCOST pose=%-15s min full=%5.2f nograss=%5.2f flat=%5.2f ms | grass=%+5.2f terrain=%+5.2f ms | median full/nograss/flat=%.2f/%.2f/%.2f | prims main full/nograss/flat=%d/%d/%d shadow=%d/%d/%d" % [
				p[0], row.full.ms_min, row.nograss.ms_min, row.flat.ms_min, row.grass_ms, row.terrain_ms,
				row.full.ms, row.nograss.ms, row.flat.ms,
				row.full.prims, row.nograss.prims, row.flat.prims,
				row.full.shadow_prims, row.nograss.shadow_prims, row.flat.shadow_prims])
	if args.has("out"):
		var f := FileAccess.open(String(args.out), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
	print("TERRAIN COST DONE")
	quit(0)


func _apply(p: Array, s: String) -> void:
	var cam: Camera3D = view.camera
	cam.fov = p[3]
	cam.global_position = p[1]
	cam.look_at(p[2])
	var grass: Node3D = terrain.get("grass")
	if grass:
		grass.visible = s == "full" or s.begins_with("grass_")
		if grass_mat:
			grass_mat.set_shader_parameter("density_scale", 0.5 if s == "grass_half" else float(grass.get("density")))
			var gm: Material = grass_opaque_mat if s == "grass_opaque" and grass_opaque_mat else grass_mat
			for c in grass.get_children():
				(c as GeometryInstance3D).material_override = gm
	var chunks := terrain.get_node_or_null("Chunks") as Node3D
	if chunks:
		chunks.visible = s != "flat"
		for c: GeometryInstance3D in chunks.get_children():
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if s == "noshadow" else cast_orig[c]
			(c as MeshInstance3D).mesh = mesh_orig[c]
			if s == "farshadow" and not (String(c.name).ends_with("L2") or String(c.name).ends_with("L3")):
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if s == "lowshadow":
				if cast_orig[c] == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
					(c as MeshInstance3D).mesh = mesh_4m
				elif String(c.name).ends_with("L2") or String(c.name).ends_with("L3"):
					c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if shipped_mat and cast_orig[c] != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				var mat: Material = shipped_mat
				if s == "simple" and simple_mat:
					mat = simple_mat
				elif s == "noaniso" and noaniso_mat:
					mat = noaniso_mat
				(c as MeshInstance3D).material_override = mat
	flat.visible = s == "flat"
	for i in 6:
		await process_frame


func _measure() -> Array:
	for k in 4:
		RenderingServer.force_draw(false)
	var t := Time.get_ticks_usec()
	for k in DRAWS:
		RenderingServer.force_draw(false)
	var ms := (Time.get_ticks_usec() - t) / 1000.0 / DRAWS
	var rid := view.get_viewport_rid()
	var prims := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var sprims := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var draws := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var sdraws := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var objs := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	return [ms, prims, sprims, draws, sdraws, objs]
