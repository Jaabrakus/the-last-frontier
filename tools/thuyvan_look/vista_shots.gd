extends SceneTree
## The Đá Trắng vista in the engine (docs/thuyvan/plan/look/vista_spec.md): R1's packed ground (ThuyVanTerrain), its
## water (ThuyVanWater) and dressing (ThuyVanDressing), the same pieces scenes/thuyvan_r1.tscn builds, shot from the
## spec's cameras V1-V3 in each look direction (ThuyVanLook), with a contact sheet and the frame time at medium. Needs a
## window:
##
##   Godot --path . --resolution 1920x1080 -s tools/thuyvan_look/vista_shots.gd -- out=DIR [dirs=a,b] [views=V1,V3]
##       [perf=0] [quality=medium] [still=1] [hour=H] [w=1920] [h=1080]
##
## Writes DIR/V<n>_<direction>.png (captioned), DIR/vista_contact.png (views down, directions across) and prints
## "PERF <view> ..." for V1 and V3 at the medium preset (mean / p95 frame ms with vsync off, GPU and CPU render ms, draw
## calls and primitives). `still=1` stills the Silent Reach (S1); `hour=H` shoots the day cycle at that hour instead of
## the directions (V<n>_h<H>.png).
##
## V2 moved (ROCK's note: from the spec's (-380, 257, -600) the A2 plateau's rim hides the bridge): the bake's ground was
## searched for a point that sees the deck's middle and both ends and a pier's upper half; the south bank of the torrent
## at (-540, 288, -400) does, 30 m over the ground, 300 m from the bridge (a raised vantage, as the sheet's).

const Region := preload("res://scripts/world/world_region.gd")
const Look := preload("res://scripts/thuyvan/look/thuyvan_look.gd")
const Kit := preload("res://scripts/thuyvan/look/thuyvan_kit.gd")
const TerrainScript := preload("res://scripts/thuyvan/world/thuyvan_terrain.gd")
const WaterScript := preload("res://scripts/thuyvan/world/thuyvan_water.gd")
const DressingScript := preload("res://scripts/thuyvan/world/thuyvan_dressing.gd")

## [name, title, position, yaw deg, pitch deg, vertical fov]
const VIEWS := [
	["V1", "the Reach", Vector3(938.0, 220.7, -1250.0), 99.0, -8.0, 50.0],
	["V2", "the Two Heights", Vector3(-540.0, 288.0, -400.0), 79.0, 3.0, 34.0],
	["V3", "on the bridge", Vector3(857.0, 199.3, -1211.0), -3.0, -10.0, 60.0],
]
## The stand-in figure on the rope bridge's east span (V3's player).
const FIGURE_AT := Vector2(857.0, -1215.0)

var _out := ""
var _dirs: Array = []
var _views: Array = []
var _perf := true
var _quality := "medium"
var _still := false
var _hour := -1.0
var _w := 1920
var _h := 1080
var _world: Node3D
var _env: Environment
var _sun: DirectionalLight3D
var _cam: Camera3D
var _caption: Label
var _water: Node3D
var _dressing: Node3D
var _settings: WorldSettings


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": _out = kv[1]
			"dirs": _dirs = Array(kv[1].split(","))
			"views": _views = Array(kv[1].split(","))
			"perf": _perf = kv[1] != "0"
			"quality": _quality = kv[1]
			"still": _still = kv[1] == "1"
			"hour": _hour = float(kv[1])
			"w": _w = int(kv[1])
			"h": _h = int(kv[1])
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("vista_shots: needs out=DIR and a window")
		quit(1)
		return
	if _dirs.is_empty():
		_dirs = Look.directions()
	if _views.is_empty():
		_views = ["V1", "V2", "V3"]
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(_w, _h)
	root.use_debanding = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	Region.set_region("r1")
	FrontierTerrain.open_ground = true
	_settings = WorldSettings.preset(_quality)
	_stage()
	var terrain: FrontierTerrain = TerrainScript.new()
	terrain.name = "Terrain"
	_world.add_child(terrain)
	terrain.build(_settings)
	print("VISTA terrain %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_water = WaterScript.new()
	_water.name = "Water"
	_world.add_child(_water)
	_water.call("build", String(Region.info().get("water", "res://data/world/maps/r1/water.json")))
	WorldRiver.reach_state = "S1" if _still else "S0"
	_water.call("set_still_band", WorldRiver.still_band())
	print("VISTA water %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_dressing = DressingScript.new()
	_dressing.name = "Dressing"
	_world.add_child(_dressing)
	_dressing.call("build", _settings)
	print("VISTA dressing %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# the stand-in figure on the deck under V3 (the deck's height from its collider)
	for i in 3:
		await physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(FIGURE_AT.x, 230.0, FIGURE_AT.y), Vector3(FIGURE_AT.x, 150.0, FIGURE_AT.y))
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(q)
	var fig := Kit.village("porter_walking")
	if fig and not hit.is_empty():
		fig.position = hit.position
		fig.rotation_degrees.y = 180.0
		_world.add_child(fig)
		print("VISTA figure on the deck at y %.2f" % (hit.position as Vector3).y)
	var shots := {}
	var looks: Array = []
	if _hour >= 0.0:
		looks.append(["h%05.2f" % _hour, Look.at_hour(_hour), "Day cycle %05.2f h" % _hour])
	else:
		for d: String in _dirs:
			var lk := Look.resolve(d)
			if not lk.is_empty():
				looks.append([d, lk, String(Look.data().looks[d].title)])
	for l: Array in looks:
		var look: Dictionary = l[1]
		Look.apply(look, _env, _sun, true)
		_dressing.call("set_look", look)
		_water.call("set_sky_tint", look.water_sky_tint)
		for v: Array in VIEWS:
			if not String(v[0]) in _views:
				continue
			var img := await _shot(v, "%s, %s  ·  %s%s" % [v[0], v[1], l[2], "  (still river)" if _still else ""])
			var p := "%s/%s_%s%s.png" % [_out, v[0], l[0], "_still" if _still else ""]
			img.save_png(p)
			shots[String(v[0]) + "|" + String(l[0])] = img
			print("VISTA -> ", p)
	_contact(shots, looks)
	if _perf:
		var noon := Look.resolve("bright_saturated_noon")
		Look.apply(noon, _env, _sun, true)
		_dressing.call("set_look", noon)
		for v: Array in VIEWS:
			if String(v[0]) in ["V1", "V3"]:
				await _measure(v)
	print("VISTA done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _aim(v: Array) -> void:
	_cam.global_position = v[2]
	_cam.rotation = Vector3(deg_to_rad(float(v[4])), deg_to_rad(float(v[3])), 0.0)
	_cam.fov = float(v[5])


func _shot(v: Array, title: String) -> Image:
	_aim(v)
	root.msaa_3d = Viewport.MSAA_4X
	_caption.text = title
	_caption.get_parent().visible = true
	for i in 50:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Frame time at the quality preset (no MSAA, its shadow distance), vsync off, from the view.
func _measure(v: Array) -> void:
	_aim(v)
	_caption.get_parent().visible = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_sun.directional_shadow_max_distance = _settings.shadow_max_distance
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for i in 90:
		await process_frame
	var dts: Array[float] = []
	var gpu := 0.0
	var cpu := 0.0
	var draws := 0.0
	var prims := 0.0
	var n := 180
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		dts.append((now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	dts.sort()
	var mean := 0.0
	for d in dts:
		mean += d
	mean /= n
	print("PERF %s %s %dx%d: frame %.2f ms mean (%.0f fps), p95 %.2f ms; GPU %.2f ms, CPU render %.2f ms; %d draw calls, %.2fM primitives" % [
			v[0], _quality, _w, _h, mean, 1000.0 / mean, dts[int(n * 0.95)], gpu / n, cpu / n, int(draws / n), prims / n / 1e6])
	RenderingServer.viewport_set_measure_render_time(rid, false)
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_sun.directional_shadow_max_distance = float(Look.data().get("render", {}).get("shadows", {}).get("max_distance_m", 1500.0))


## The contact sheet: views down, directions across, each shot at a third.
func _contact(shots: Dictionary, looks: Array) -> void:
	var cw := _w / 3
	var chh := _h / 3
	var rows: Array = []
	for v: Array in VIEWS:
		if String(v[0]) in _views:
			rows.append(String(v[0]))
	if rows.is_empty() or looks.is_empty():
		return
	var sheet := Image.create(cw * looks.size(), chh * rows.size(), false, Image.FORMAT_RGB8)
	for r in rows.size():
		for c in looks.size():
			var key := String(rows[r]) + "|" + String(looks[c][0])
			if not shots.has(key):
				continue
			var img: Image = (shots[key] as Image).duplicate()
			img.convert(Image.FORMAT_RGB8)
			img.resize(cw, chh, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(0, 0, cw, chh), Vector2i(c * cw, r * chh))
	var p := "%s/vista_contact%s.png" % [_out, "_still" if _still else ""]
	sheet.save_png(p)
	print("VISTA -> ", p)


func _stage() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	var sh: Dictionary = Look.data().get("render", {}).get("shadows", {})
	_sun.directional_shadow_max_distance = float(sh.get("max_distance_m", 1500.0))
	_sun.directional_shadow_split_1 = 0.04
	_sun.directional_shadow_split_2 = 0.12
	_sun.directional_shadow_split_3 = 0.35
	_sun.shadow_blur = float(sh.get("blur", 1.5))
	_sun.shadow_bias = 0.08
	_sun.shadow_normal_bias = 1.5
	_world.add_child(_sun)
	_env = Environment.new()
	var we := WorldEnvironment.new()
	we.environment = _env
	_world.add_child(we)
	_cam = Camera3D.new()
	_cam.near = 0.3
	_cam.far = 14000.0
	_world.add_child(_cam)
	_cam.make_current()
	var ui := CanvasLayer.new()
	root.add_child(ui)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.12, 0.72)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	_caption = Label.new()
	_caption.add_theme_font_override("font", UiFonts.sans(600))
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	panel.add_child(_caption)
	panel.position = Vector2(16, 14)
	ui.add_child(panel)
