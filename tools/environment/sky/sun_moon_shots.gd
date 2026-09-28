extends SceneTree
## Proof captures of the sun and the moon crossing the sky (sun and moon push, 2026-09-26). Windowed; wrap it in a
## time limit (a full run takes about 6 minutes):
##
##   Godot --path . --resolution 1600x900 -s tools/environment/sky/sun_moon_shots.gd -- --no-capture out=<dir> \
##       [what=sun_arc,sunset,sunrise,moon_night,phases,day_moon,clouds,glare] [settle=24] [year=1765]
##
## Per item a sheet <out>/sheet_<item>.png and its frames in <out>/<item>/; every frame is labelled (date, local
## solar time, where the sun / moon stands). The weather is held (clear, no cumulus, except in `clouds`) and the time
## jumps do not move it on (DayNight would otherwise advance the fronts by the skipped hours).
##   sun_arc     21 December, a fixed wide camera facing south: sunrise to sunset every 30 min, and one multiple
##               exposure of the whole arc (the suns pasted into the noon frame)
##   sunset / sunrise  25 August (the game's date), a fixed camera toward where it sets / rises: the disc going down
##               (up) through 20 .. 0 deg, reddening and dimming
##   moon_night  the summer full moon of the year, a fixed wide camera facing south: moonrise to moonset, and one
##               multiple exposure
##   phases      one lunation (from the new moon before 25 August): 8 ages from the young crescent with earthshine to
##               the old crescent, each at its best hour, through a 4 deg "telescope" (the disc's orientation is the
##               real one at that hour), and the same moons at game scale (70 deg field of view, native pixels x2)
##   day_moon    the moon in the afternoon sky (70 deg and 12 deg views)
##   clouds      a fair-weather cumulus edge passing over the moon at night and over the sun by day
##   glare       the stars around a bright moon, and the same view without the glare
## Checks (printed; the run ends with "CHECKS FAILED <n>" if any is off, then SUN MOON SHOTS DONE):
##   SUNVIS     the drawn sun: display value at its centre against the sky 3 disc radii out, and the position of its
##              brightest pixels against the astronomical position projected by the camera (px)
##   MOONCHECK  the rendered moon (telescope views): lit share of the disc and the direction of its bright part on
##              the screen, against SkyBodies.moon_lit_stats() (the sun's direction on the sky)

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const SkyBodies := preload("res://scripts/world/env/sky_bodies.gd")
const HIGH := Vector3(3.0, 60.0, -130.0)      ## over the trees, 130 m north of the fort
const GROUND := Vector3(3.0, 1.7, -130.0)     ## the player's eye on the open range
## [age (days after the new moon), name]. The first is the "new moon" of the almanacs of the time: the first crescent
## seen in the evening twilight (the moon at its conjunction is lost in the sun's glare, as in reality).
const PHASES := [[3.0, "new moon (first crescent), earthshine"], [5.0, "waxing crescent"], [7.4, "first quarter"],
		[11.0, "waxing gibbous"], [14.8, "full"], [18.5, "waning gibbous"], [22.1, "last quarter"],
		[25.8, "waning crescent, earthshine"]]

var args := {}
var view: OffscreenView
var dn: Node
var out := ""
var label: Label
var settle := 24
var fails := 0
var year := 1765


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = String(args.get("out", "user://sun_moon_shots"))
	settle = int(args.get("settle", "24"))
	year = int(args.get("year", "1765"))
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var level := current_scene
	var player: Node3D = level.get_node("Player")
	player.set("ignore_mouse_capture", true)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	var hud = player.get("hud")
	if hud:
		hud.visible = false
	var rig: Node = level.get_node("EnvironmentRig")
	dn = rig.get("clock_driver")
	if dn == null:
		print("SUN MOON SHOTS: no DayNight (headless?)")
		quit(1)
		return
	dn.clock.running = false
	dn.clock.year = year
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	rig.follow_camera = view.camera
	view.camera.current = true
	view.camera.far = 4000.0
	# the dust motes float round the camera: through a 4 deg view they are big blurred squares, not sky
	var motes = rig.get("_motes")
	if motes:
		motes.visible = false
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	var layer := CanvasLayer.new()
	view.add_child(layer)
	label = Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	await _frames(30)
	var what: PackedStringArray = String(args.get("what", "sun_arc,sunset,sunrise,moon_night,phases,day_moon,clouds,glare")).split(",", false)
	for w in what:
		DirAccess.make_dir_recursive_absolute(out.path_join(w))
		match w:
			"sun_arc":
				await _sun_arc()
			"sunset":
				await _sun_low(true)
			"sunrise":
				await _sun_low(false)
			"moon_night":
				await _moon_night()
			"phases":
				await _phases()
			"day_moon":
				await _day_moon()
			"clouds":
				await _clouds()
			"glare":
				await _glare()
	if fails > 0:
		print("CHECKS FAILED %d" % fails)
	print("SUN MOON SHOTS DONE")
	quit()


# --- Items -------------------------------------------------------------------------------------------------------

func _sun_arc() -> void:
	var doy := float(args.get("arc_doy", "355"))
	var rise := _crossing(doy, 3.0, 12.0, true, 0.0)
	var set_h := _crossing(doy, 12.0, 21.0, false, 0.0)
	var eye := _eye(HIGH)
	var south: Vector3 = WorldClock.enu_to_world(Vector3(0, -1, 0))
	_place(eye, _dir_toward(south, 16.0), 100.0)
	var frames: Array[Image] = []
	var suns: Array[Vector2] = []
	var hours: Array[float] = []
	var h := ceilf((rise + 0.05) * 2.0) / 2.0
	while h < set_h:
		hours.append(h)
		h += 0.5
	hours.push_front(rise + 0.08)
	hours.append(set_h - 0.08)
	var base: Image
	for hh in hours:
		await _at(doy, hh)
		var sd: Vector3 = dn.clock.sun_direction()
		label.text = "%s  %s  sun alt %.1f  az %.0f  (fixed camera, south, 100 deg fov)" % [dn.clock.date_string(), dn.clock.time_string(), _alt(sd), _az(sd)]
		var img := await _grab()
		img.save_png(out.path_join("sun_arc/sun_%05.2f.png" % hh))
		var p := view.camera.unproject_position(eye + sd * 3000.0)
		_sunvis("arc %s" % dn.clock.time_string(), img, p, sd)
		frames.append(img)
		suns.append(p)
		if base == null and hh >= 12.0:
			label.text = "Sun arc, %s, sunrise %s to sunset %s every 30 min (multiple exposure; fixed camera, south, 100 deg fov)" % [
					dn.clock.date_string(), _hm(rise), _hm(set_h)]
			base = await _grab()
	var comp: Image = base.duplicate()
	var r := int(view.size.y / 100.0 * 1.4) + 6
	for i in frames.size():
		_paste_disc(comp, frames[i], suns[i], r)
	comp.save_png(out.path_join("sheet_sun_arc.png"))
	_sheet(frames, 5, "sheet_sun_arc_frames.png")


func _sun_low(setting: bool) -> void:
	var doy := float(args.get("low_doy", "237"))
	var tag := "sunset" if setting else "sunrise"
	var cross := _crossing(doy, 12.0, 21.0, false, 0.0) if setting else _crossing(doy, 3.0, 12.0, true, 0.0)
	await _at(doy, cross)
	var sd0: Vector3 = dn.clock.sun_direction()
	var eye := _eye(HIGH)
	var hz := Vector3(sd0.x, 0.0, sd0.z).normalized()
	var els := [20.0, 12.0, 8.0, 5.0, 3.0, 2.0, 1.0, 0.3, -0.3]
	if not setting:
		els.reverse()
	var frames: Array[Image] = []
	for el: float in els:
		var hh := _crossing(doy, 12.0, 21.0, false, el) if setting else _crossing(doy, 3.0, 12.0, true, el)
		await _at(doy, hh)
		var sd: Vector3 = dn.clock.sun_direction()
		# a fixed camera toward where the sun meets the horizon, 40 deg fov, horizon a third up
		_place(eye, _dir_toward(hz, 9.0), 40.0)
		await _frames(4)
		label.text = "%s  %s  %s  sun alt %.1f  az %.0f  (fixed camera, 40 deg fov)" % [tag, dn.clock.date_string(), dn.clock.time_string(), _alt(sd), _az(sd)]
		var img := await _grab()
		img.save_png(out.path_join("%s/%s_el%+05.1f.png" % [tag, tag, el]))
		_sunvis("%s el %.1f" % [tag, el], img, view.camera.unproject_position(eye + sd * 3000.0), sd)
		frames.append(img)
	_sheet(frames, 3, "sheet_%s.png" % tag)


func _moon_night() -> void:
	# the summer full moon: low in the south, its whole night arc fits a fixed south-facing view
	var best := 0.0
	var best_t := 0.0
	var t := 150.0
	while t < 210.0:
		dn.clock.set_date(floorf(t))
		dn.clock.set_time(fposmod(t, 1.0) * 24.0)
		var k: float = dn.clock.moon_illumination()
		if k > best:
			best = k
			best_t = t
		t += 0.05
	var doy := floorf(best_t)
	# the night around the full moon: from its rise in the evening to its setting the next morning
	var hours: Array[Vector2] = []    # (day, hour)
	var h := 16.0
	while h < 32.0:
		var d := doy + floorf(h / 24.0)
		var hh := fposmod(h, 24.0)
		dn.clock.set_date(d)
		dn.clock.set_time(hh)
		if _alt(dn.clock.moon_direction()) > 0.5:
			hours.append(Vector2(d, hh))
		h += 0.75
	var eye := _eye(HIGH)
	var south: Vector3 = WorldClock.enu_to_world(Vector3(0, -1, 0))
	_place(eye, _dir_toward(south, 14.0), 100.0)
	var frames: Array[Image] = []
	var moons: Array[Vector2] = []
	var base: Image
	for dh in hours:
		await _at(dh.x, dh.y)
		var md: Vector3 = dn.clock.moon_direction()
		var sd: Vector3 = dn.clock.sun_direction()
		label.text = "%s  %s  moon alt %.1f  az %.0f  lit %.2f  sun alt %.0f  (fixed camera, south, 100 deg fov)" % [
				dn.clock.date_string(), dn.clock.time_string(), _alt(md), _az(md), dn.clock.moon_illumination(), _alt(sd)]
		var img := await _grab()
		img.save_png(out.path_join("moon_night/moon_%03d_%05.2f.png" % [int(dh.x), dh.y]))
		frames.append(img)
		moons.append(view.camera.unproject_position(eye + md * 3000.0))
		if base == null and dh.x > doy and dh.y >= 0.0:
			label.text = "Moon across the night of %s (full moon), every 45 min (multiple exposure; fixed camera, south, 100 deg fov)" % dn.clock.date_string()
			base = await _grab()
	if base == null and not frames.is_empty():
		base = frames[frames.size() / 2]
	var comp: Image = base.duplicate()
	for i in frames.size():
		_paste_disc(comp, frames[i], moons[i], int(view.size.y / 100.0 * 1.6) + 5)
	comp.save_png(out.path_join("sheet_moon_night.png"))
	_sheet(frames, 5, "sheet_moon_night_frames.png")


func _phases() -> void:
	var nm := _new_moon_before(float(args.get("lunation_doy", "237")))
	var tele: Array[Image] = []
	var game: Array[Image] = []
	for ph: Array in PHASES:
		var target := nm + float(ph[0])
		var when := _best_moon_time(target - 0.7, 1.4, 4.0 if absf(float(ph[0]) - 14.8) > 10.0 else 8.0)
		await _at(when.x, when.y)
		var md: Vector3 = dn.clock.moon_direction()
		var sd: Vector3 = dn.clock.sun_direction()
		var age := (when.x + when.y / 24.0) - nm
		var desc := "%s: %s %s, age %.1f d, lit %.2f, moon alt %.0f az %.0f, sun alt %.0f" % [ph[1], dn.clock.date_string(),
				dn.clock.time_string(), age, dn.clock.moon_illumination(), _alt(md), _az(md), _alt(sd)]
		# the telescope: 4 deg, the moon centred with the sky's up at the top (its tilt is the real one)
		var eye := _eye(HIGH)
		_place(eye, md, 4.0)
		label.text = desc + "\n4 deg telescope view (the soft squares are catalogued stars, magnified 13x; at the game's 52-70 deg they are points)"
		var img := await _grab()
		img.save_png(out.path_join("phases/tele_%04.1f.png" % float(ph[0])))
		_moon_check(String(ph[1]), img, eye, md, sd)
		tele.append(img)
		# game scale: 70 deg (the player's field of view), over the trees so a low moon is not hidden
		var ge := _eye(HIGH)
		var aim := _dir_toward(Vector3(md.x, 0.0, md.z).normalized(), clampf(_alt(md) - 18.0, 8.0, 60.0))
		_place(ge, aim, 70.0)
		label.text = desc + "  (game view, 70 deg)"
		var gimg := await _grab()
		gimg.save_png(out.path_join("phases/game_%04.1f.png" % float(ph[0])))
		var p := view.camera.unproject_position(ge + md * 3000.0)
		var crop := _crop(gimg, p, 64)
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		game.append(crop)
		print("PHASE %s" % desc)
	_sheet(tele, 4, "sheet_phases.png")
	_sheet(game, 4, "sheet_phases_game_scale.png", 1.0)


func _day_moon() -> void:
	# a first-quarter to gibbous moon in the afternoon (the usual day moon): both well up
	var nm := _new_moon_before(float(args.get("lunation_doy", "237")))
	var found := Vector2(-1, -1)
	var best := -1e9
	var t := nm + 6.5
	while t < nm + 10.5:
		dn.clock.set_date(floorf(t))
		dn.clock.set_time(fposmod(t, 1.0) * 24.0)
		var m_alt := _alt(dn.clock.moon_direction())
		var s_alt := _alt(dn.clock.sun_direction())
		var score := minf(m_alt, 40.0) + minf(s_alt, 30.0)
		if s_alt > 12.0 and m_alt > 20.0 and score > best:
			best = score
			found = Vector2(floorf(t), fposmod(t, 1.0) * 24.0)
		t += 0.02
	if found.x < 0.0:
		print("DAY MOON: no afternoon moon found")
		return
	await _at(found.x, found.y)
	var md: Vector3 = dn.clock.moon_direction()
	var sd: Vector3 = dn.clock.sun_direction()
	var frames: Array[Image] = []
	var ge := _eye(HIGH)     # over the trees
	_place(ge, _dir_toward(Vector3(md.x, 0.0, md.z).normalized(), clampf(_alt(md) - 15.0, 5.0, 60.0)), 70.0)
	var desc := "moon by day: %s %s, lit %.2f, moon alt %.0f az %.0f, sun alt %.0f az %.0f" % [dn.clock.date_string(),
			dn.clock.time_string(), dn.clock.moon_illumination(), _alt(md), _az(md), _alt(sd), _az(sd)]
	label.text = desc + "  (game view, 70 deg)"
	frames.append(await _grab())
	_place(ge, md, 12.0)
	label.text = desc + "  (12 deg)"
	var img := await _grab()
	_moon_check("day moon", img, ge, md, sd)
	frames.append(img)
	for i in frames.size():
		frames[i].save_png(out.path_join("day_moon/day_moon_%d.png" % i))
	_sheet(frames, 2, "sheet_day_moon.png")


func _clouds() -> void:
	# night: a bright moon well up; day: the sun at about 35 deg
	var nm := _new_moon_before(float(args.get("lunation_doy", "237")))
	var when := _best_moon_time(floorf(nm + 12.0), 2.0)
	await _at(when.x, when.y, "fair", 0.45)
	await _frames(settle)
	_sheet(await _cloud_edge("moon", dn.clock.moon_direction()), 3, "sheet_clouds_moon.png")
	var doy := 237.0
	await _at(doy, _crossing(doy, 12.0, 21.0, false, 35.0), "fair", 0.45)
	await _frames(settle)
	_sheet(await _cloud_edge("sun", dn.clock.sun_direction()), 3, "sheet_clouds_sun.png")


## A cloud's edge crossing the disc toward `dir`: the clouds are held still (DayNight paused: the frames differ only
## by where the camera stands), the camera walks east then north (60 m over the ground) until the clouds' CPU mirror
## (CloudField, the same field the sky draws) finds the sharpest edge from clear sky into thick cloud, then six frames
## step across it: at the clouds' height a few km away that is the cloud drifting over the disc. 24 deg views.
func _cloud_edge(tag: String, dir: Vector3) -> Array[Image]:
	var out_imgs: Array[Image] = []
	dn.set_process(false)
	print("CLOUDS %s weather: %s" % [tag, dn.weather.describe()])
	var base := _eye(HIGH)
	var best := 0.0
	var axis := Vector3.RIGHT
	var d0 := 0.0     # the last clear sample before the edge (m along the axis)
	var d1 := 0.0     # the first thick one after it
	for ax: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
		var trs: Array[float] = []
		for i in 600:
			trs.append(dn.field.view_transmittance(dir, base + ax * (i * 20.0)))
		# a clear stretch, then the thickest cloud within 300 m
		for i in range(3, 584):
			var clear := minf(trs[i - 3], minf(trs[i - 2], minf(trs[i - 1], trs[i])))
			var thick := 1.0
			var jt := i + 1
			for j in range(i + 1, i + 16):
				if trs[j] < thick:
					thick = trs[j]
					jt = j
			if clear > 0.85 and clear - thick > best + 0.02:
				best = clear - thick
				axis = ax
				d0 = i * 20.0
				d1 = jt * 20.0
	print("CLOUDS %s edge: clear - thick %.2f between %.0f and %.0f m along %s" % [tag, best, d0, d1, axis])
	if best <= 0.0:
		print("CLOUDS %s: no cloud edge found within 12 km" % tag)
		dn.set_process(true)
		return out_imgs
	# six frames spread over the edge, from just before the clear side to just past the thick one
	var step := (d1 - d0 + 40.0) / 5.0
	for k in 6:
		var eye := base + axis * (d0 - 20.0 + k * step)
		_place(eye, dir, 24.0)
		var tr: float = dn.field.view_transmittance(dir, eye)
		label.text = "cloud passing in front of the %s: %s %s, frame %d (%.0f m steps = the cloud drifting), CPU cloud transmittance %.2f (24 deg)" % [
				tag, dn.clock.date_string(), dn.clock.time_string(), k, step, tr]
		var img := await _grab()
		img.save_png(out.path_join("clouds/%s_%d.png" % [tag, k]))
		print("CLOUDS %s frame %d transmittance %.2f" % [tag, k, tr])
		out_imgs.append(img)
	dn.set_process(true)
	return out_imgs


func _glare() -> void:
	var nm := _new_moon_before(float(args.get("lunation_doy", "237")))
	var when := _best_moon_time(floorf(nm + 11.0), 2.0)
	await _at(when.x, when.y)
	var md: Vector3 = dn.clock.moon_direction()
	var eye := _eye(HIGH)
	_place(eye, md, 50.0)
	await _frames(settle)
	var frames: Array[Image] = []
	label.text = "stars near a bright moon (lit %.2f): the glare hides the stars next to it (50 deg)" % dn.clock.moon_illumination()
	frames.append(await _grab())
	# the same without the local glare: DayNight paused for the frame (the rest of the sky unchanged)
	dn.set_process(false)
	dn.sky_mat.set_shader_parameter(&"moon_glare", 0.0)
	await _frames(settle)
	label.text = "the same without the moon's glare (comparison only)"
	frames.append(await _grab())
	dn.set_process(true)
	for i in frames.size():
		frames[i].save_png(out.path_join("glare/glare_%d.png" % i))
	_sheet(frames, 2, "sheet_glare.png")


# --- Checks ------------------------------------------------------------------------------------------------------

func _sunvis(tag: String, img: Image, p: Vector2, sd: Vector3) -> void:
	var cam := view.camera
	var rad := deg_to_rad(float(dn.sky_mat.get_shader_parameter(&"sun_size_deg")) * 0.5)
	var eye := cam.global_position
	var side := sd.cross(Vector3.UP).normalized()
	var r_px := (cam.unproject_position(eye + (sd + side * tan(rad)) * 3000.0) - p).length()
	if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height() or cam.is_position_behind(eye + sd):
		print("SUNVIS %s: off screen" % tag)
		return
	# contrast: the largest channel difference between the disc's centre and the sky 3 disc radii out (a white disc
	# on a cream sky differs most in blue, an orange one on a pale sky in green and blue)
	var cc := img.get_pixelv(p)
	var centre := _lum(cc)
	var rc := Color(0, 0, 0)
	var n := 0
	for k in 16:
		var a := TAU * k / 16.0
		var q := p + Vector2(cos(a), sin(a)) * r_px * 3.0
		if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
			rc += img.get_pixelv(q)
			n += 1
	rc /= maxf(n, 1)
	var ring := _lum(rc)
	var contrast := maxf(absf(cc.r - rc.r), maxf(absf(cc.g - rc.g), absf(cc.b - rc.b)))
	# the brightest pixels near the predicted spot: their centroid against it
	var win := int(r_px * 3.0) + 3
	var mx := 0.0
	for y in range(int(p.y) - win, int(p.y) + win + 1):
		for x in range(int(p.x) - win, int(p.x) + win + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				mx = maxf(mx, _lum(img.get_pixel(x, y)))
	var c := Vector2.ZERO
	var w := 0.0
	for y in range(int(p.y) - win, int(p.y) + win + 1):
		for x in range(int(p.x) - win, int(p.x) + win + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and _lum(img.get_pixel(x, y)) >= mx - 0.01:
				c += Vector2(x + 0.5, y + 0.5)
				w += 1.0
	var off := (c / maxf(w, 1.0) - p).length()
	var alt := _alt(sd)
	# below 0 deg the centre has set (the upper limb only): shown, not checked
	var ok := alt < 0.0 or (off <= maxf(2.0, r_px * 0.5) and contrast > 0.04)
	if not ok:
		fails += 1
	print("SUNVIS %s alt=%.1f disc_r=%.1fpx centre=%s ring3r=%s contrast=%.3f pos_err=%.1fpx %s" % [tag, alt, r_px,
			_rgb(cc), _rgb(rc), contrast, off, "ok" if ok else "FAIL"])


func _moon_check(tag: String, img: Image, eye: Vector3, md: Vector3, sd: Vector3) -> void:
	var cam := view.camera
	var north: Vector3 = dn.sky_mat.get_shader_parameter(&"moon_north")
	var frame := SkyBodies.moon_frame(md, north)
	var rad := deg_to_rad(float(dn.sky_mat.get_shader_parameter(&"moon_size_deg")) * 0.5)
	var c := cam.unproject_position(eye + md * 3000.0)
	var pe := cam.unproject_position(eye + (md + frame[0] * tan(rad)) * 3000.0) - c
	var pn := cam.unproject_position(eye + (md + frame[1] * tan(rad)) * 3000.0) - c
	var r_px := pe.length()
	var want: Dictionary = SkyBodies.moon_lit_stats(sd, md, north, 96)
	var ring: Array[float] = []
	for k in 48:
		var a := TAU * k / 48.0
		for f in [1.25, 1.4]:
			var q: Vector2 = c + Vector2(cos(a), sin(a)) * r_px * f
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
				ring.append(_lum(img.get_pixelv(q)))
	ring.sort()
	var sky := ring[ring.size() / 2] if not ring.is_empty() else 0.0
	var vals: Array[float] = []
	var pts: Array[Vector2] = []
	var r_in := r_px * 0.96
	for y in range(int(c.y - r_in), int(c.y + r_in) + 1):
		for x in range(int(c.x - r_in), int(c.x + r_in) + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			if (q - c).length() <= r_in and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				vals.append(_lum(img.get_pixel(x, y)))
				pts.append(q)
	if vals.is_empty():
		print("MOONCHECK %s: off screen" % tag)
		return
	var sorted := vals.duplicate()
	sorted.sort()
	var p95: float = sorted[int(sorted.size() * 0.97)]
	# lit: above the dark side's level (the earthshine, or the sky) by an eighth of the disc's range (Lommel-Seeliger
	# dims the lit side toward the terminator); the bright part's direction: the centroid of the lit pixels. The dark
	# side's level: the pixels the CPU mirror puts well inside the dark hemisphere.
	var dark: Array[float] = []
	for i in vals.size():
		var qd := pts[i] - c
		var qq := Vector2(qd.dot(pe.normalized()), qd.dot(pn.normalized())) / r_px
		var z := sqrt(maxf(1.0 - qq.length_squared(), 0.0))
		var nrm: Vector3 = frame[0] * qq.x + frame[1] * qq.y - md * z
		if nrm.dot(sd) < -0.15:
			dark.append(vals[i])
	dark.sort()
	var base := maxf(sky, dark[dark.size() / 2]) if dark.size() > 20 else sky
	var th := base + 0.12 * (p95 - base)
	var lit := 0
	var cen := Vector2.ZERO
	var wsum := 0.0
	for i in vals.size():
		if vals[i] > th:
			lit += 1
			cen += pts[i] - c
			wsum += 1.0
	var frac := float(lit) / vals.size()
	var want_frac: float = want.lit
	var ok := absf(frac - want_frac) < 0.08 and p95 - sky > 0.05
	var ang_err := 0.0
	if want_frac > 0.03 and want_frac < 0.95 and wsum > 0.0:
		var sp: Vector2 = want.sun_pa
		var want_dir := (pe.normalized() * sp.x + pn.normalized() * sp.y).normalized()
		ang_err = rad_to_deg(absf(want_dir.angle_to(cen / wsum)))
		ok = ok and ang_err < 12.0
	if not ok:
		fails += 1
	print("MOONCHECK %s: disc_r=%.0fpx lit %.3f (want %.3f) bright-limb dir err %.1f deg, disc p97 %.2f sky %.2f %s" % [tag,
			r_px, frac, want_frac, ang_err, p95, sky, "ok" if ok else "FAIL"])


# --- Helpers -----------------------------------------------------------------------------------------------------

## Sets the clock and holds the weather (a time jump must not move it on).
func _at(doy: float, hour: float, weather := "clear", cover := 0.0) -> void:
	dn.clock.set_date(doy)
	dn.clock.set_time(hour)
	dn.force_weather(weather)
	dn.force_cover = cover
	dn.set("_prev_hour", -1.0)
	dn.set("_snap", true)
	await _frames(3)
	dn.set("_prev_hour", -1.0)


## Hour of `doy` between h0 and h1 at which the sun's elevation crosses el_deg (rising or setting), by bisection.
func _crossing(doy: float, h0: float, h1: float, rising: bool, el_deg: float) -> float:
	dn.clock.set_date(doy)
	var lo := h0
	var hi := h1
	for i in 40:
		var mid := 0.5 * (lo + hi)
		dn.clock.set_time(mid)
		var above: bool = dn.clock.sun_elevation_deg() > el_deg
		if above == rising:
			hi = mid
		else:
			lo = mid
	return 0.5 * (lo + hi)


## The moment (doy, hour) of the new moon before `doy` (illumination minimum).
func _new_moon_before(doy: float) -> float:
	var best := 2.0
	var best_t := doy
	var t := doy - 30.0
	while t < doy:
		dn.clock.set_date(floorf(t))
		dn.clock.set_time(fposmod(t, 1.0) * 24.0)
		var k: float = dn.clock.moon_illumination()
		if k < best:
			best = k
			best_t = t
		t += 0.02
	return best_t


## Best hour to see the moon within `span` days from `doy`: high, with the sky as dark as it gets.
func _best_moon_time(doy: float, span: float, min_alt := 8.0) -> Vector2:
	var best := -1e9
	var found := Vector2(doy, 0.0)
	var t := doy
	while t < doy + span:
		dn.clock.set_date(floorf(t))
		dn.clock.set_time(fposmod(t, 1.0) * 24.0)
		var m_alt := _alt(dn.clock.moon_direction())
		var s_alt := _alt(dn.clock.sun_direction())
		var score := minf(m_alt, 28.0) - 1.6 * maxf(s_alt + 12.0, 0.0)
		if m_alt > min_alt and score > best:
			best = score
			found = Vector2(floorf(t), fposmod(t, 1.0) * 24.0)
		t += 0.01
	return found


func _eye(e: Vector3) -> Vector3:
	return Vector3(e.x, FrontierTerrain.height_at(e.x, e.z) + e.y, e.z)


func _place(eye: Vector3, dir: Vector3, fov: float) -> void:
	view.camera.global_position = eye
	view.camera.fov = fov
	view.camera.look_at(eye + dir.normalized(), Vector3.UP)


func _dir_toward(horiz: Vector3, pitch_deg: float) -> Vector3:
	var h := Vector3(horiz.x, 0.0, horiz.z).normalized()
	return (h * cos(deg_to_rad(pitch_deg)) + Vector3.UP * sin(deg_to_rad(pitch_deg))).normalized()


func _alt(v: Vector3) -> float:
	return rad_to_deg(asin(clampf(v.y, -1.0, 1.0)))


## True compass azimuth (0 = north, 90 = east) of a world direction.
func _az(v: Vector3) -> float:
	var n: Vector3 = WorldClock.enu_to_world(Vector3(0, 1, 0))
	var e: Vector3 = WorldClock.enu_to_world(Vector3(1, 0, 0))
	return fposmod(rad_to_deg(atan2(v.dot(e), v.dot(n))), 360.0)


func _hm(h: float) -> String:
	return "%02d:%02d" % [int(h), int(fposmod(h * 60.0, 60.0))]


func _rgb(c: Color) -> String:
	return "(%.2f,%.2f,%.2f)" % [c.r, c.g, c.b]


func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _grab() -> Image:
	await _frames(settle)
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()


func _crop(img: Image, p: Vector2, half: int) -> Image:
	var x := clampi(int(p.x) - half, 0, img.get_width() - 2 * half)
	var y := clampi(int(p.y) - half, 0, img.get_height() - 2 * half)
	return img.get_region(Rect2i(x, y, 2 * half, 2 * half))


## Copies a disc of radius r around p from src into dst (multiple exposure).
func _paste_disc(dst: Image, src: Image, p: Vector2, r: int) -> void:
	for y in range(int(p.y) - r, int(p.y) + r + 1):
		for x in range(int(p.x) - r, int(p.x) + r + 1):
			if x < 0 or y < 0 or x >= dst.get_width() or y >= dst.get_height():
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(p) / r
			if d > 1.0:
				continue
			var a := clampf((1.0 - d) / 0.25, 0.0, 1.0)
			var s := src.get_pixel(x, y)
			var o := dst.get_pixel(x, y)
			# keep whichever is brighter (the discs and their glow over the base frame's sky)
			if _lum(s) > _lum(o):
				dst.set_pixel(x, y, o.lerp(s, a))


## A contact sheet: tiles `cols` wide, each scaled to 1/cols of 2400 px (or by `scale` when given).
func _sheet(imgs: Array[Image], cols: int, name: String, scale := 0.0) -> void:
	if imgs.is_empty():
		return
	var w0 := imgs[0].get_width()
	var h0 := imgs[0].get_height()
	var tw := int(2400.0 / cols) if scale <= 0.0 else int(w0 * scale)
	var th := int(float(h0) * tw / w0)
	var rows := int(ceil(imgs.size() / float(cols)))
	var sheet := Image.create(tw * cols + 4 * (cols - 1), th * rows + 4 * (rows - 1), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for i in imgs.size():
		var t: Image = imgs[i].duplicate()
		t.convert(Image.FORMAT_RGB8)
		t.resize(tw, th, Image.INTERPOLATE_LANCZOS if scale <= 0.0 else Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(t, Rect2i(0, 0, tw, th), Vector2i((i % cols) * (tw + 4), (i / cols) * (th + 4)))
	sheet.save_png(out.path_join(name))
	print("SHEET %s (%d frames)" % [out.path_join(name), imgs.size()])


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
