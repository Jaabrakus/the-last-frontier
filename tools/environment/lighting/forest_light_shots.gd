extends SceneTree
## Forest lighting at every time of day and weather (2026-09-26, "fix the lighting in the forest"). Windowed; wrap it
## in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/environment/lighting/forest_light_shots.gd -- --no-capture \
##       out=<dir> [conds=dawn,morning,noon,golden,dusk,night_full,night_new,overcast,storm] \
##       [views=deep,inside_out,edge,open,up,player] [settle=50] [date=237] [sheet=1] [size=1280x720]
##
## For every condition (a time of day on the level's date, 25 August 1765, clear sky unless named) and view it saves
## <out>/<cond>_<view>.png and prints
##   SHOT <cond> <view> luma=<mean display luma 0-255> lo=<darkest 5 %> hi=<brightest 5 %> dark=<share of pixels under
##        12/255> sun_el=<deg> sun_energy= exposure= key_tr=
## and a contact sheet <out>/sheet_<view>.png per view (conditions left to right, top to bottom in the order given).
## Conditions: dawn (sun 3 deg up in the morning), morning (9 h), noon (12 h), golden (the default 19.1 deg afternoon
## sun), dusk (sun 4 deg under the horizon, evening), night_full / night_new (the nearest full / new moon to `date`,
## at the hour the full moon stands highest; the new-moon night at midnight), overcast (13 h, overcast), storm (15 h,
## the storm's core overhead: rain). Clear conditions hold the cumulus at 0 (DayNight.force_cover), so the key light is
## never behind a cloud and before / after pairs match.
## Views: deep (inside the forest, 40 m from any clearing), inside_out (from inside the forest toward the fort
## clearing), edge (from the range lane at the forest wall, 25-35 m off), open (the open range looking back to the
## fort), up (the canopy seen from under it, 55 deg up toward the sun's side: back-lit leaves), player (the gameplay
## camera behind the player standing in the forest), far (deep in the western forest, 150 m and more from any clearing:
## a low sun has to come through the trees), trunk (the foot of the tree nearest (-88, -48) from 3.5 m: its contact with
## the ground), sunward (from the range lane toward the sun, or the moon, 8 deg up: the tree line against the light).
## gate, firing, aerial: the u10 reference views of tools/environment/scenic_shots.gd (spawn_gate, firing_line, aerial),
## here with the clock held (scenic_shots runs the clock, so its sun moves with the load time). Ends with FOREST LIGHT
## SHOTS DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
## Loaded at run time (not preloaded), so the tool also runs on a checkout from before the forest light (before shots).
const CANOPY_MAP := "res://scripts/world/vegetation/canopy_map.gd"

## [name, camera xz + eye height, look target (point) or direction (flag), is direction, fov]
const VIEWS := {
	"deep": [Vector3(-95.0, 1.7, -45.0), Vector3(-1.0, 0.02, 0.1), true, 70.0],
	"inside_out": [Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), false, 70.0],
	"edge": [Vector3(0.0, 1.7, -90.0), Vector3(-1.0, 0.06, 0.12), true, 70.0],
	"open": [Vector3(3.0, 1.7, -130.0), Vector3(0.0, 3.0, -16.0), false, 60.0],
	"up": [Vector3(-95.0, 1.7, -45.0), Vector3.ZERO, true, 75.0],
	"player": [Vector3(-80.0, 0.0, -52.0), Vector3.ZERO, true, 70.0],
	"far": [Vector3(-250.0, 1.7, 60.0), Vector3(0.3, 0.02, -1.0), true, 70.0],
	"trunk": [Vector3(-88.0, 1.4, -48.0), Vector3.ZERO, true, 60.0],
	"sunward": [Vector3(0.0, 1.7, -90.0), Vector3.ZERO, true, 70.0],
	"gate": [Vector3(1.4, 1.7, 4.0), Vector3(0.0, 1.4, -45.0), false, 60.0],
	"firing": [Vector3(-1.2, 1.7, -18.5), Vector3(0.0, 1.2, -110.0), false, 55.0],
	"aerial": [Vector3(48.0, 30.0, 48.0), Vector3(0.0, 0.0, -22.0), false, 55.0],
}
const PLAYER_SPOT := Vector3(-80.0, 0.0, -52.0)

var args := {}
var view: SubViewport
var level: Node
var dn: Node
var rig: Node
var player: Node3D
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = String(args.get("out", "user://forest_light"))
	DirAccess.make_dir_recursive_absolute(out)
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.global_position = Vector3(PLAYER_SPOT.x, FrontierTerrain.height_at(PLAYER_SPOT.x, PLAYER_SPOT.z) + 0.1, PLAYER_SPOT.z)
	var hud = player.get("hud")
	if hud:
		hud.visible = false
	rig = level.get_node("EnvironmentRig")
	dn = rig.get("clock_driver")
	if dn == null:
		print("FOREST LIGHT SHOTS: no DayNight (headless?)")
		quit(1)
		return
	dn.clock.running = false
	var px := DisplayServer.window_get_size()
	if args.has("size"):
		px = Vector2i(int(String(args["size"]).get_slice("x", 0)), int(String(args["size"]).get_slice("x", 1)))
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, px)
	root.disable_3d = true
	rig.follow_camera = view.camera
	view.camera.current = true
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	await _frames(60)
	# fl.<name>=<value>: a ForestLight look value (tuning); dapple.<name>=<value>: a canopy_dapple.gdshader uniform
	var fl: Node = dn.get("forest")
	for k: String in args:
		if k.begins_with("fl.") and fl:
			var cur: Variant = fl.get(k.substr(3))
			if cur is Color:
				var parts := String(args[k]).split(":")
				fl.set(k.substr(3), Color(float(parts[0]), float(parts[1]), float(parts[2])))
			else:
				fl.set(k.substr(3), float(args[k]))
			print("TUNE ", k, " = ", fl.get(k.substr(3)))
		elif k.begins_with("dapple.") and ResourceLoader.exists(CANOPY_MAP):
			load(CANOPY_MAP).dapple_material().set_shader_parameter(k.substr(7), float(args[k]))
			print("TUNE ", k, " = ", args[k])
	if args.get("sdfgi", "") == "0":
		(rig.get_environment() as Environment).sdfgi_enabled = false
	if args.has("sdfgi_energy"):
		(rig.get_environment() as Environment).sdfgi_energy = float(args["sdfgi_energy"])
	if args.has("dump_canopy") and ResourceLoader.exists(CANOPY_MAP) and load(CANOPY_MAP).image:
		(load(CANOPY_MAP).image as Image).save_png(String(args["dump_canopy"]))
	var veg := level.get_node_or_null("Vegetation/Visuals")
	if veg:
		var n := 0
		for c in veg.get_children():
			if String(c.name).begins_with("TreeDapple_"):
				n += 1
		print("DAPPLE casters: %d MultiMeshes" % n)
	var settle := int(args.get("settle", "50"))
	var date := float(args.get("date", str(WorldClock.DEFAULT_DAY_OF_YEAR)))
	var conds: PackedStringArray = String(args.get("conds", "dawn,morning,noon,golden,dusk,night_full,night_new,overcast,storm")).split(",", false)
	var views: PackedStringArray = String(args.get("views", "deep,inside_out,edge,open,up,player")).split(",", false)
	var sheets := {}
	for c in conds:
		if not await _set_condition(c, date):
			print("FOREST LIGHT SHOTS: unknown condition ", c)
			continue
		await _frames(settle)
		for v in views:
			_aim(v)
			var fl0: Node = dn.get("forest")
			if fl0:
				fl0.set("_last_cam", Vector3(INF, INF, INF))    # a cut, not a walk: the eye starts adapted
			await _frames(maxi(settle / 2, 8))
			var img: Image = view.get_texture().get_image()
			img.save_png(out.path_join("%s_%s.png" % [c, v]))
			var st := _stats(img)
			var env: Environment = rig.get_environment()
			var fs := _floor_stats(img)
			print("SHOT %-10s %-10s luma=%6.1f lo=%5.1f hi=%6.1f dark=%.3f floor=%5.1f/%5.1f sun_el=%6.1f sun_energy=%.3f exposure=%.2f key_tr=%.2f fog=%.3f cover=%.2f eye=%.2f %s" % [
					c, v, st.x, st.y, st.z, st.w, fs.x, fs.y, dn.clock.sun_elevation_deg(), dn.sun.light_energy,
					env.tonemap_exposure, dn._key_tr, env.fog_light_energy, fl.get("cover") if fl else 0.0,
					fl.get("eye_gain") if fl else 1.0, dn.weather.phase()])
			if not sheets.has(v):
				sheets[v] = []
			sheets[v].append(img)
	if args.get("sheet", "1") == "1":
		for v: String in sheets:
			_sheet(sheets[v], out.path_join("sheet_%s.png" % v))
	print("FOREST LIGHT SHOTS DONE")
	quit()


## Sets the clock, the date and the weather of a condition. False for an unknown name.
func _set_condition(c: String, date: float) -> bool:
	var clock: WorldClock = dn.clock
	clock.set_date(date)
	var weather := "clear"
	var hour := 12.0
	match c:
		"dawn":
			hour = _sun_crossing(date, 3.0, true)
		"morning":
			hour = 9.0
		"noon":
			hour = 12.0
		"golden":
			hour = WorldClock.default_hour()
		"dusk":
			hour = _sun_crossing(date, -4.0, false)
		"night_full", "night_new":
			var dt := _moon_night(date, c == "night_full")
			clock.set_date(dt.x)
			hour = dt.y
		"overcast":
			hour = 13.0
			weather = "overcast"
		"storm":
			hour = 15.0
			weather = "storm_here"
		_:
			return false
	clock.set_time(hour)
	await _frames(2)
	dn.force_cover = 0.0 if weather == "clear" else -1.0
	dn.force_weather(weather)
	dn.set("_snap", true)      # the exposure follows the weather at once (in game over ~1.5 s)
	print("COND %s %s %s sun_el=%.1f moon_el=%.1f moon_lit=%.2f %s" % [c, clock.date_string(), clock.time_string(),
			clock.sun_elevation_deg(), rad_to_deg(asin(clampf(clock.moon_direction().y, -1.0, 1.0))),
			clock.moon_illumination(), dn.weather.describe()])
	return true


## Hour at which the sun crosses `el` degrees on `doy`, in the morning (rising) or the evening.
func _sun_crossing(doy: float, el: float, morning: bool) -> float:
	var clock: WorldClock = dn.clock
	clock.set_date(doy)
	var h0 := 3.0 if morning else 12.0
	var h1 := 12.0 if morning else 21.0
	var prev := -INF
	var h := h0
	while h <= h1:
		clock.set_time(h)
		var e := clock.sun_elevation_deg()
		if prev > -INF and ((morning and prev < el and e >= el) or (not morning and prev > el and e <= el)):
			return h
		prev = e
		h += 0.02
	return h0


## (day of year, hour) of the full (or new) moon night nearest `doy`: the full moon at its highest in astronomical
## night, the new moon at midnight.
func _moon_night(doy: float, full: bool) -> Vector2:
	var clock: WorldClock = dn.clock
	var best := Vector2(doy, 0.0)
	var best_score := -INF
	for d in range(int(doy) - 16, int(doy) + 16):
		clock.set_date(float(d))
		clock.set_time(0.0)
		var lit := clock.moon_illumination()
		var score := lit if full else -lit
		score -= absf(d - doy) * 0.002
		if score > best_score:
			best_score = score
			best = Vector2(d, 0.0)
	if not full:
		return best
	# the hour the full moon stands highest while the sun is well down (the evening before or after midnight)
	var top := -INF
	var hour := 0.0
	for k in 48:
		var h := 20.0 + k * 0.25
		clock.set_date(best.x + (0.0 if h < 24.0 else 1.0))
		clock.set_time(fposmod(h, 24.0))
		if clock.sun_elevation_deg() > -18.0:
			continue
		var alt := clock.moon_direction().y
		if alt > top:
			top = alt
			hour = h
	if hour >= 24.0:
		return Vector2(best.x + 1.0, hour - 24.0)
	return Vector2(best.x, hour)


func _aim(v: String) -> void:
	var cfg: Array = VIEWS.get(v, VIEWS.deep)
	var cam: Camera3D = view.camera
	player.visible = v == "player"
	if v == "player":
		view.source = player.get("camera")
		view.sync_camera()
		return
	view.source = null
	var pos: Vector3 = cfg[0]
	var eye := Vector3(pos.x, FrontierTerrain.height_at(pos.x, pos.z) + pos.y, pos.z)
	var dir: Vector3 = cfg[1]
	if v == "trunk":
		var t := _nearest_tree(Vector2(pos.x, pos.z))
		var from := Vector2(t.x, t.z) + Vector2(3.0, 1.6)
		eye = Vector3(from.x, FrontierTerrain.height_at(from.x, from.y) + pos.y, from.y)
		cam.global_position = eye
		cam.look_at(Vector3(t.x, t.y + 0.35, t.z))
		cam.fov = cfg[3]
		return
	if v == "up" or v == "sunward":
		var sd: Vector3 = dn.clock.sun_direction() if dn.clock.sun_elevation_deg() > -6.0 else dn.clock.moon_direction()
		var h := Vector2(sd.x, sd.z).normalized()
		var pitch := deg_to_rad(55.0 if v == "up" else 8.0)
		dir = Vector3(h.x, 0.0, h.y) * cos(pitch) + Vector3.UP * sin(pitch)
	var target := eye + dir.normalized() if cfg[2] else Vector3(dir.x, FrontierTerrain.height_at(dir.x, dir.z) + dir.y, dir.z)
	cam.global_position = eye
	cam.look_at(target)
	cam.fov = cfg[3]


## Base of the canopy tree nearest to xz (the layout's position).
func _nearest_tree(xz: Vector2) -> Vector3:
	var veg: Node = level.get_node_or_null("Vegetation")
	var best := Vector3(xz.x, 0.0, xz.y)
	if veg == null or veg.get("layout") == null:
		return best
	var lay: RefCounted = veg.get("layout")
	var d := INF
	for i in (lay.tree_pos as PackedVector3Array).size():
		var p: Vector3 = lay.tree_pos[i]
		if lay.tree_kind[i] >= 5:
			continue
		var dd := Vector2(p.x, p.z).distance_to(xz)
		if dd < d:
			d = dd
			best = p
	return best


## Mean display luma (0-255), the mean of the darkest and of the brightest 5 %, and the share of pixels under 12/255.
func _stats(img: Image) -> Vector4:
	var im := img.duplicate() as Image
	im.convert(Image.FORMAT_RGB8)
	im.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var ls := PackedFloat32Array()
	var sum := 0.0
	var dark := 0
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			var l := (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
			ls.append(l)
			sum += l
			if l < 12.0:
				dark += 1
	ls.sort()
	var n := ls.size()
	var k := maxi(n / 20, 1)
	var lo := 0.0
	var hi := 0.0
	for i in k:
		lo += ls[i]
		hi += ls[n - 1 - i]
	return Vector4(sum / n, lo / k, hi / k, float(dark) / n)


## The ground in the lower 40 % of the frame: its median display luma (the shade) and its 90th percentile (sunflecks).
func _floor_stats(img: Image) -> Vector2:
	var im := img.duplicate() as Image
	im.convert(Image.FORMAT_RGB8)
	im.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var ls := PackedFloat32Array()
	for y in range(54, 90):
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			ls.append((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0)
	ls.sort()
	return Vector2(ls[ls.size() / 2], ls[ls.size() * 9 / 10])


func _sheet(images: Array, path: String) -> void:
	var first: Image = images[0]
	var w := first.get_width() / 3
	var h := first.get_height() / 3
	var cols := mini(images.size(), 3)
	var rows := ceili(images.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im := (images[i] as Image).duplicate() as Image
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
