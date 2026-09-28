extends SceneTree
## The stars while the camera moves (stars blur push, 2026-09-26; user: "fix the blur on the stars when we move"), and
## the check of the fix (SkyMotionVectors: the sky's motion vectors for the TAA). Windowed (it renders); wrap it in a
## time limit (about 3 minutes):
##
##   Godot --path . --resolution 1600x900 -s tools/environment/sky/star_motion.gd -- --no-capture out=<dir> \
##       [cases=still,pan_slow,pan,pan_fast,tilt,walk,run,walk_turn] [frames=8] [lead=30] [strip=1] [fix=0] \
##       [same=1] [day=1] [cost=1] [cost_reps=6] [aa=taa|off|fxaa|msaa2x] [upscale=<mode>[,<level>]]
##
## A clear, moonless night (the new moon before 25 August 1765, 01:30) on the open range north of the fort, looking
## north-east 42 deg up. The stars of a still reference view (the 40 brightest isolated ones) are followed through
## every moving frame by their true sky direction (Camera3D.unproject_position()) and measured:
##   peak   the star's display value above the sky round it (sRGB luma, 0..1)
##   width  its equivalent width sqrt(flux / peak) in pixels (1 for a one-pixel star; a smear grows it)
##   along  its second-moment width (px) along the screen motion (a trail)
## Cases: still (a fixed camera, the TAA settled); pan_slow / pan / pan_fast (the camera turning 0.25 / 1 / 3 deg a
## frame: 15 / 60 / 180 deg/s at 60 fps, a steady mouse look); tilt (raising the view 0.5 deg a frame: the vertical
## part of the motion); walk / run (the player walking / sprinting forward: the camera only moves, the sky should not
## move at all); walk_turn (walking and turning 1 deg a frame). Each runs `lead` frames first (the TAA's steady
## state), then measures `frames`. Prints
##   STAR <case> stars=<n> motion=<px/frame> peak=<moving / still> width=<moving / still> along=<px>
##        lost=<share of the stars under 30% of their still peak> flicker=<frame-to-frame peak change / peak>
##   STARCHECK <case> width ratio <= 1.5 and peak ratio >= 0.5: ok / FAIL
## fix=0 turns SkyMotionVectors off (the engine's TAA alone: the "before"). With the effect present, also:
##   same=1  STARSAME night / day: a still view renders as without the effect (sky, against the TAA's own noise)
##   day=1   <out>/sheet_day.png: a daytime pan through cumulus, the effect off (row 1) and on (row 2)
##   cost=1  STARCOST <pose>: frame time off / on / with 17 passes (the pass's own cost), see _cost()
## strip=1 writes <out>/sheet.png: every case one row, 4 consecutive frames of the same patch of sky (x3 nearest).
## Ends with STAR MOTION DONE, after "CHECKS FAILED <n>" if any check failed.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const EYE := Vector3(3.0, 1.7, -130.0)          ## the open range, 130 m north of the fort
const RATES := {"pan_slow": 0.25, "pan": 1.0, "pan_fast": 3.0, "tilt": 0.5, "walk_turn": 1.0}
## [name, camera xz, eye height, look direction] for the cost: the night sky view is added in code.
const COST_POSES := [
	["forest_in", Vector3(-58.0, 1.7, -62.0), Vector3(0.6, 0.05, 0.8)],
	["fort", Vector3(0.9, 2.2, 9.5), Vector3(0.0, 0.0, -1.0)],
]
const REF_STARS := 40
const MIN_PEAK := 0.08         ## display value above the sky for a reference star
const WIN := 6                 ## measuring window half size (px)
const NOISE := 0.012           ## display value treated as sky noise in the window
const MAX_WIDTH_RATIO := 1.5
const MIN_PEAK_RATIO := 0.5
const CROP := Vector2i(200, 112)
const ZOOM := 3

var args := {}
var view: OffscreenView
var level: Node
var player: Node3D
var dn: Node
var out := ""
var lead := 30
var n_frames := 8
var fails := 0
var yaw0 := 0.0
var pitch0 := deg_to_rad(42.0)
## Reference stars: {dir: Vector3, peak, width} from the still frames.
var stars: Array[Dictionary] = []
var strips := {}          ## case -> Array[Image]
var results := {}         ## case -> summary Dictionary
var eye := Vector3.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = String(args.get("out", "user://star_motion"))
	lead = int(args.get("lead", "30"))
	n_frames = int(args.get("frames", "8"))
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	level = current_scene
	player = level.get_node("Player")
	player.set("ignore_mouse_capture", true)
	eye = Vector3(EYE.x, FrontierTerrain.height_at(EYE.x, EYE.z) + EYE.y, EYE.z)
	player.global_position = Vector3(EYE.x, FrontierTerrain.height_at(EYE.x, EYE.z) + 0.1, EYE.z)
	var hud = player.get("hud")
	if hud:
		hud.visible = false
	var rig: Node = level.get_node("EnvironmentRig")
	dn = rig.get("clock_driver")
	if dn == null:
		print("STAR MOTION: no DayNight (headless?)")
		quit(1)
		return
	# fix=0: without the sky's motion vectors (SkyMotionVectors), the engine's TAA alone (before / after)
	var sky_mv := false
	var we := rig.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.compositor:
		for e in we.compositor.compositor_effects:
			if e is SkyMotionVectors:
				e.enabled = args.get("fix", "1") != "0"
				sky_mv = e.enabled
				# stage=post_sky|pre_transparent: run the pass later in the frame (investigation)
				match String(args.get("stage", "")):
					"post_sky":
						e.effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_SKY
					"pre_transparent":
						e.effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	rig.follow_camera = view.camera
	view.camera.current = true
	view.camera.fov = 70.0
	view.camera.far = 1500.0
	_override_aa()
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	# a clear night with no moon: the new moon before 25 August 1765, 01:30 local time
	dn.clock.running = false
	var nm := _new_moon_before(float(args.get("doy", "237")))
	dn.clock.set_date(floorf(nm))
	dn.clock.set_time(float(args.get("hour", "1.5")))
	dn.force_weather("clear")
	dn.force_cover = 0.0
	dn.set("_snap", true)
	# north-east, 42 deg up (Cassiopeia, Perseus, the Pleiades rising): many bright stars over the trees
	var ne: Vector3 = WorldClock.enu_to_world(Vector3(0.7, 0.7, 0.0)).normalized()
	yaw0 = atan2(-ne.x, -ne.z)
	await _frames(40)
	print("STAR MOTION %s  sun alt %.1f  moon illum %.2f  view %s aa=%s taa=%s scaling=%d/%.2f sky_mv=%s  %s" % [
			dn.clock.date_string(), rad_to_deg(asin(dn.clock.sun_direction().y)), dn.clock.moon_illumination(), view.size,
			args.get("aa", "preset"), view.use_taa, view.scaling_3d_mode, view.scaling_3d_scale, sky_mv, dn.weather.describe()])
	var cases: PackedStringArray = String(args.get("cases", "still,pan_slow,pan,pan_fast,tilt,walk,run,walk_turn")).split(",", false)
	if not "still" in cases:
		cases.insert(0, "still")
	for c in cases:
		await _run_case(c)
	if args.get("strip", "1") == "1":
		await _sheet(cases)
	if _effect() and args.get("same", "1") == "1":
		await _same_when_still("night")
	if _effect() and args.get("day", "1") == "1":
		await _day()
	if _effect() and args.get("cost", "1") == "1":
		await _cost()
	if fails > 0:
		print("CHECKS FAILED %d" % fails)
	print("STAR MOTION DONE")
	quit()


## aa=<taa|off|fxaa|msaa2x> overrides the preset's anti-aliasing on the capture view (investigation).
func _override_aa() -> void:
	match String(args.get("aa", "")):
		"off":
			view.use_taa = false
			view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			view.msaa_3d = Viewport.MSAA_DISABLED
		"fxaa":
			view.use_taa = false
			view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"taa":
			view.use_taa = true
		"msaa2x":
			view.use_taa = false
			view.msaa_3d = Viewport.MSAA_2X


# --- Cases -------------------------------------------------------------------------------------------------------

func _run_case(c: String) -> void:
	var frames: Array[Image] = []
	var cams: Array[Transform3D] = []
	var fovs: Array[float] = []
	match c:
		"still", "pan_slow", "pan", "pan_fast", "tilt":
			_use_view_camera()
			var rate := deg_to_rad(float(RATES.get(c, 0.0)))
			var start := -rate * (lead + n_frames / 2)
			for i in lead + n_frames:
				# pans turn the view (yaw); tilt raises it (pitch: the vectors' vertical part)
				if c == "tilt":
					_aim(yaw0, pitch0 + start + rate * i)
				else:
					_aim(yaw0 + start + rate * i)
				await _draw()
				if i >= lead:
					frames.append(view.get_texture().get_image())
					cams.append(view.camera.global_transform)
					fovs.append(view.camera.fov)
			if c == "still":
				_find_stars(frames[0])
		"walk", "run", "walk_turn":
			# the player walks (runs) forward; the capture camera sits where the player's camera is (its spring
			# arm) and looks where the player looks, turned by this tool (walk_turn: 1 deg a frame)
			await _use_player_camera()
			var pcam: Camera3D = player.get("camera")
			var rate := deg_to_rad(float(RATES.get(c, 0.0)))
			var yaw := yaw0 - rate * (30 + lead + n_frames / 2)
			Input.action_press(&"move_forward")
			if c == "run":
				Input.action_press(&"sprint")
			for i in 30 + lead + n_frames:
				player.set("yaw", yaw)
				view.camera.global_position = pcam.global_position
				view.camera.basis = Basis.from_euler(Vector3(pitch0, yaw, 0.0))
				await _draw()
				if i >= 30 + lead:
					frames.append(view.get_texture().get_image())
					cams.append(view.camera.global_transform)
					fovs.append(view.camera.fov)
				yaw += rate
			Input.action_release(&"move_forward")
			Input.action_release(&"sprint")
			await _frames(20)
			_use_view_camera()
	_measure(c, frames, cams, fovs)
	strips[c] = _strip(frames, cams, fovs)


func _use_view_camera() -> void:
	view.source = null
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	view.camera.fov = 70.0


## The player walking (its camera's place is used; the view's direction is set by the tool).
func _use_player_camera() -> void:
	player.global_position = Vector3(EYE.x, FrontierTerrain.height_at(EYE.x, EYE.z) + 0.1, EYE.z)
	player.visible = false   # its camera only (the body would hide stars low in the view)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set("yaw", yaw0)
	player.set("pitch", pitch0)
	view.source = null
	view.camera.fov = 70.0
	await _frames(20)


func _aim(yaw: float, pitch := pitch0) -> void:
	var cam := view.camera
	cam.global_position = eye
	cam.basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))


# --- Measuring ---------------------------------------------------------------------------------------------------

## The brightest isolated stars of the still view, as sky directions.
func _find_stars(img: Image) -> void:
	var cam := view.camera
	var w := img.get_width()
	var h := img.get_height()
	var lum := _lum_array(img)
	var cands: Array[Vector3] = []     # (x, y, excess)
	for y in range(WIN + 12, h - WIN - 12):
		for x in range(WIN + 12, w - WIN - 12):
			var v: float = lum[y * w + x]
			if v < MIN_PEAK:
				continue
			var is_max := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if (dx != 0 or dy != 0) and lum[(y + dy) * w + x + dx] > v:
						is_max = false
			if not is_max:
				continue
			var e := v - _ring_bg(lum, w, h, Vector2(x + 0.5, y + 0.5))
			if e >= MIN_PEAK:
				cands.append(Vector3(x, y, e))
	cands.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
	var picked: Array[Vector3] = []
	for p in cands:
		var d := cam.project_ray_normal(Vector2(p.x + 0.5, p.y + 0.5))
		if rad_to_deg(asin(d.y)) < 12.0:
			continue   # over the trees only
		var alone := true
		for q in cands:
			if q != p and Vector2(q.x - p.x, q.y - p.y).length() < 12.0 and q.z > 0.3 * p.z:
				alone = false
				break
		if alone:
			picked.append(p)
		if picked.size() >= REF_STARS:
			break
	stars.clear()
	for p in picked:
		stars.append({"dir": cam.project_ray_normal(Vector2(p.x + 0.5, p.y + 0.5))})
	print("STAR reference: %d isolated stars (of %d candidates), brightest excess %.2f" % [stars.size(), cands.size(),
			picked[0].z if not picked.is_empty() else 0.0])


func _measure(c: String, frames: Array[Image], cams: Array[Transform3D], fovs: Array[float]) -> void:
	var cam := view.camera
	var keep := cam.global_transform
	var keep_fov := cam.fov
	var peaks := []       # per star: Array of peaks over frames
	var widths := []
	var alongs := []
	var motion := Vector2.ZERO
	for s in stars:
		peaks.append([])
		widths.append([])
		alongs.append([])
	for f in frames.size():
		var img := frames[f]
		var lum := _lum_array(img)
		cam.global_transform = cams[f]
		cam.fov = fovs[f]
		var pos := cam.global_position
		# the screen motion at the view centre over this frame (from the previous camera)
		if f > 0:
			var ahead := -cams[f].basis.z
			cam.global_transform = cams[f - 1]
			var before := cam.unproject_position(cams[f - 1].origin + ahead * 1000.0)
			cam.global_transform = cams[f]
			motion += cam.unproject_position(pos + ahead * 1000.0) - before
		for i in stars.size():
			var d: Vector3 = stars[i].dir
			if cam.is_position_behind(pos + d * 1000.0):
				continue
			var p := cam.unproject_position(pos + d * 1000.0)
			if p.x < WIN + 12 or p.y < WIN + 12 or p.x > img.get_width() - WIN - 12 or p.y > img.get_height() - WIN - 12:
				continue
			var m := _star_at(lum, img.get_width(), img.get_height(), p)
			peaks[i].append(m.peak)
			widths[i].append(m.width)
			alongs[i].append(m.m2)
	cam.global_transform = keep
	cam.fov = keep_fov
	if frames.size() > 1:
		motion /= float(frames.size() - 1)
	var dirn := motion.normalized() if motion.length() > 0.05 else Vector2.RIGHT
	# per star medians; `along` recomputed with the motion direction
	var s_peak: Array[float] = []
	var s_width: Array[float] = []
	var s_along: Array[float] = []
	var s_flick: Array[float] = []
	var used := 0
	for i in stars.size():
		if (peaks[i] as Array).size() < 2:
			continue
		used += 1
		var pk: float = _median(peaks[i])
		var wd: float = _median(widths[i])
		var al := 0.0
		for m2: Vector3 in alongs[i]:
			al += sqrt(maxf(m2.x * dirn.x * dirn.x + 2.0 * m2.z * dirn.x * dirn.y + m2.y * dirn.y * dirn.y, 0.0))
		al /= maxf((alongs[i] as Array).size(), 1)
		var var_sum := 0.0
		for k in range(1, (peaks[i] as Array).size()):
			var_sum += absf(float(peaks[i][k]) - float(peaks[i][k - 1]))
		var flick := var_sum / maxf((peaks[i] as Array).size() - 1, 1) / maxf(pk, 1e-3)
		s_peak.append(pk)
		s_width.append(wd)
		s_along.append(al)
		s_flick.append(flick)
		if c == "still":
			stars[i]["peak"] = pk
			stars[i]["width"] = wd
			stars[i]["along"] = al
	var r := {"stars": used, "motion": motion.length()}
	if c == "still":
		r["peak"] = _median(s_peak)
		r["width"] = _median(s_width)
		r["along"] = _median(s_along)
		r["flicker"] = _median(s_flick)
		print("STAR still stars=%d peak=%.3f width=%.2fpx along=%.2fpx flicker=%.3f" % [used, r.peak, r.width, r.along, r.flicker])
	else:
		var pr: Array[float] = []
		var wr: Array[float] = []
		var lost := 0
		var j := 0
		for i in stars.size():
			if (peaks[i] as Array).size() < 2 or not stars[i].has("peak"):
				continue
			var p0: float = stars[i].peak
			var pk: float = s_peak[j]
			pr.append(pk / maxf(p0, 1e-3))
			wr.append(s_width[j] / maxf(float(stars[i].width), 0.5))
			if pk < 0.3 * p0:
				lost += 1
			j += 1
		r["peak_ratio"] = _median(pr)
		r["width_ratio"] = _median(wr)
		r["along"] = _median(s_along)
		r["flicker"] = _median(s_flick)
		r["lost"] = float(lost) / maxf(pr.size(), 1)
		var ok: bool = r.width_ratio <= MAX_WIDTH_RATIO and r.peak_ratio >= MIN_PEAK_RATIO
		if not ok:
			fails += 1
		print("STAR %s stars=%d motion=%.1fpx/frame peak=%.2fx width=%.2fx along=%.2fpx lost=%.0f%% flicker=%.3f" % [c,
				used, r.motion, r.peak_ratio, r.width_ratio, r.along, 100.0 * r.lost, r.flicker])
		print("STARCHECK %s width %.2fx (<= %.1f) peak %.2fx (>= %.1f) %s" % [c, r.width_ratio, MAX_WIDTH_RATIO,
				r.peak_ratio, MIN_PEAK_RATIO, "ok" if ok else "FAIL"])
	results[c] = r


## Peak above the local sky, equivalent width sqrt(flux / peak) and the second moments (xx, yy, xy) of a star
## expected near p (the brightest pixel within 2 px of p is its centre).
func _star_at(lum: PackedFloat32Array, w: int, h: int, p: Vector2) -> Dictionary:
	var bg := _ring_bg(lum, w, h, p)
	var cx := int(p.x)
	var cy := int(p.y)
	var best := -1.0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var v: float = lum[(cy + dy) * w + cx + dx]
			if v > best:
				best = v
	var peak := maxf(best - bg, 0.0)
	var flux := 0.0
	var sx := 0.0
	var sy := 0.0
	for dy in range(-WIN, WIN + 1):
		for dx in range(-WIN, WIN + 1):
			var e: float = lum[(cy + dy) * w + cx + dx] - bg
			if e > NOISE:
				flux += e
				sx += e * dx
				sy += e * dy
	var mx := sx / maxf(flux, 1e-6)
	var my := sy / maxf(flux, 1e-6)
	var xx := 0.0
	var yy := 0.0
	var xy := 0.0
	for dy in range(-WIN, WIN + 1):
		for dx in range(-WIN, WIN + 1):
			var e: float = lum[(cy + dy) * w + cx + dx] - bg
			if e > NOISE:
				xx += e * (dx - mx) * (dx - mx)
				yy += e * (dy - my) * (dy - my)
				xy += e * (dx - mx) * (dy - my)
	var inv := 1.0 / maxf(flux, 1e-6)
	return {"peak": peak, "width": sqrt(flux / maxf(peak, 1e-3)) if peak > NOISE else 0.0,
			"m2": Vector3(xx * inv, yy * inv, xy * inv)}


## The sky's level round p: the median of a ring 9-12 px out.
func _ring_bg(lum: PackedFloat32Array, w: int, h: int, p: Vector2) -> float:
	var vals: Array[float] = []
	for k in 32:
		var a := TAU * k / 32.0
		for r in [9.0, 12.0]:
			var q: Vector2 = p + Vector2(cos(a), sin(a)) * r
			var qx := clampi(int(q.x), 0, w - 1)
			var qy := clampi(int(q.y), 0, h - 1)
			vals.append(lum[qy * w + qx])
	return _median(vals)


func _lum_array(img: Image) -> PackedFloat32Array:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var step := 4 if img.get_format() == Image.FORMAT_RGBA8 else 3
	if img.get_format() != Image.FORMAT_RGBA8 and img.get_format() != Image.FORMAT_RGB8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGB8)
		data = img.get_data()
		step = 3
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	for i in w * h:
		var o := i * step
		lum[i] = (0.2126 * data[o] + 0.7152 * data[o + 1] + 0.0722 * data[o + 2]) / 255.0
	return lum


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() / 2])


# --- Strips ------------------------------------------------------------------------------------------------------

## The same patch of sky (round the reference view's centre) in 4 consecutive frames, x3 nearest.
func _strip(frames: Array[Image], cams: Array[Transform3D], fovs: Array[float], crop := CROP, zoom := ZOOM,
		count := 4) -> Array[Image]:
	var cam := view.camera
	var keep := cam.global_transform
	var keep_fov := cam.fov
	var centre := Basis.from_euler(Vector3(pitch0, yaw0, 0.0)) * Vector3.FORWARD
	var outs: Array[Image] = []
	for f in mini(count, frames.size()):
		cam.global_transform = cams[f]
		cam.fov = fovs[f]
		var p := cam.unproject_position(cams[f].origin + centre * 1000.0)
		var img := frames[f]
		var r := Rect2i(Vector2i(p) - crop / 2, crop)
		r.position = r.position.clamp(Vector2i.ZERO, img.get_size() - crop)
		var part := img.get_region(r)
		part.convert(Image.FORMAT_RGB8)
		part.resize(crop.x * zoom, crop.y * zoom, Image.INTERPOLATE_NEAREST)
		outs.append(part)
	cam.global_transform = keep
	cam.fov = keep_fov
	return outs


func _sheet(cases: PackedStringArray, file := "sheet.png") -> void:
	var cw := CROP.x * ZOOM
	var ch := CROP.y * ZOOM
	var cols := 1
	for c in cases:
		var imgs: Array = strips.get(c, [])
		if not imgs.is_empty():
			cw = (imgs[0] as Image).get_width()
			ch = (imgs[0] as Image).get_height()
			cols = maxi(cols, imgs.size())
	var gap := 6
	var head := 30
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.size = Vector2i(cols * cw + (cols + 1) * gap, cases.size() * (ch + head + gap) + gap)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.12)
	bg.size = vp.size
	vp.add_child(bg)
	var y := gap
	for c in cases:
		var imgs: Array = strips.get(c, [])
		imgs = imgs.duplicate()
		var lab := Label.new()
		var r: Dictionary = results.get(c, {})
		lab.text = c
		if c == "still":
			lab.text += "  (reference)"
		elif not r.is_empty():
			lab.text += "  %.1f px/frame: peak %.2fx, width %.2fx" % [r.get("motion", 0.0), r.get("peak_ratio", 0.0),
					r.get("width_ratio", 0.0)]
		lab.position = Vector2(gap, y + 2)
		lab.add_theme_font_size_override("font_size", 20)
		vp.add_child(lab)
		for i in imgs.size():
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(imgs[i])
			tr.position = Vector2(gap + i * (cw + gap), y + head)
			tr.size = Vector2(cw, ch)
			vp.add_child(tr)
		y += ch + head + gap
	root.add_child(vp)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var sheet := vp.get_texture().get_image()
	sheet.save_png(out.path_join(file))
	vp.queue_free()


# --- The sky's vectors off and on: still views, the day's clouds, the cost ----------------------------------------

## The level's SkyMotionVectors effect (null when the rig has none).
func _effect() -> SkyMotionVectors:
	var we := current_scene.get_node_or_null("EnvironmentRig/WorldEnvironment") as WorldEnvironment
	if we and we.compositor:
		for e in we.compositor.compositor_effects:
			if e is SkyMotionVectors:
				return e
	return null


## A still camera must render exactly as without the effect (its vectors are 0 there): the mean and largest display
## difference over the upper third of a settled still frame (sky) with the effect off and on, against on and on again
## (the noise floor: the TAA's jitter phase). The clock and the weather are held (DayNight paused: no cloud drift, no
## twinkle, no cloud step jitter) and the dust motes hidden.
func _same_when_still(tag: String, yaw := yaw0, pitch := pitch0) -> void:
	var fx := _effect()
	var was: bool = fx.enabled
	var motes = current_scene.get_node("EnvironmentRig").get("_motes")
	if motes:
		motes.visible = false
	_use_view_camera()
	_aim(yaw, pitch)
	dn.set_process(false)
	var shots: Array[Image] = []
	for i in 3:
		fx.enabled = i > 0
		await _frames(48)
		var img := view.get_texture().get_image()
		img.save_png(out.path_join("same_%s_%s.png" % [tag, ["off", "on", "on_again"][i]]))
		shots.append(img.get_region(Rect2i(0, 0, img.get_width(), img.get_height() / 3)))
	dn.set_process(true)
	if motes:
		motes.visible = true
	fx.enabled = was
	var d_fix := _diff(shots[0], shots[1])
	var d_noise := _diff(shots[1], shots[2])
	var ok := d_fix.x <= d_noise.x * 1.5 + 0.0005 and d_fix.y <= d_noise.y + 0.03
	if not ok:
		fails += 1
	print("STARSAME %s still (sky), effect off vs on: mean %.4f max %.3f; on vs on again: mean %.4f max %.3f %s" % [tag,
			d_fix.x, d_fix.y, d_noise.x, d_noise.y, "ok" if ok else "FAIL"])


## (mean, max) absolute difference of the display values (all channels).
func _diff(a: Image, b: Image) -> Vector2:
	var da := a.get_data()
	var db := b.get_data()
	var sum := 0.0
	var mx := 0
	for i in mini(da.size(), db.size()):
		var d: int = absi(int(da[i]) - int(db[i]))
		sum += d
		mx = maxi(mx, d)
	return Vector2(sum / maxf(da.size(), 1) / 255.0, mx / 255.0)


## The day: 15:00, fair weather with cumulus, looking away from the sun 28 deg up. The still view with the effect
## off and on (STARSAME day), then the same pan (1 deg a frame) off and on: <out>/sheet_day.png (row 1 off, row 2
## on; 2 consecutive frames of the same patch of sky, 480 x 270 px x2 nearest).
func _day() -> void:
	var fx := _effect()
	dn.clock.set_time(15.0)
	dn.force_weather("fair")
	dn.force_cover = 0.45
	dn.set("_prev_hour", -1.0)
	dn.set("_snap", true)
	await _frames(20)
	var sd: Vector3 = dn.clock.sun_direction()
	var yaw := atan2(sd.x, sd.z)    # facing away from the sun
	var pitch := deg_to_rad(28.0)
	await _same_when_still("day", yaw, pitch)
	var rows := {}
	var keep_yaw0 := yaw0
	var keep_pitch0 := pitch0
	yaw0 = yaw
	pitch0 = pitch
	for on in [false, true]:
		fx.enabled = on
		var frames: Array[Image] = []
		var cams: Array[Transform3D] = []
		var fovs: Array[float] = []
		var rate := deg_to_rad(1.0)
		for i in lead + 4:
			_aim(yaw + rate * (i - lead - 2))
			await _draw()
			if i >= lead:
				frames.append(view.get_texture().get_image())
				cams.append(view.camera.global_transform)
				fovs.append(view.camera.fov)
		rows["day_pan_" + ("on" if on else "off")] = _strip(frames, cams, fovs, Vector2i(480, 270), 2, 2)
	yaw0 = keep_yaw0
	pitch0 = keep_pitch0
	fx.enabled = true
	var keep := strips
	var keep_r := results
	strips = rows
	results = {}
	await _sheet(PackedStringArray(["day_pan_off", "day_pan_on"]), "sheet_day.png")
	strips = keep
	results = keep_r
	print("STARDAY pan strips (effect off / on) in sheet_day.png")


## The effect's cost, the camera turning 1 deg a frame (so the pass runs), wall time per frame rendered into the
## off-window view (RenderingServer.force_draw, as tools/environment/sky/sky_cost.gd) with the effect off, on, and
## with 40 more copies of it (41 passes, each doing the full work: the pass's own cost x 40, above the noise), in
## turn, `cost_reps` times; paired medians (other processes on the machine add a few ms of noise to single frames).
## RenderingDevice timestamps round the pass read 0 on Metal here, so they are not used.
##   STARCOST <pose> off=<ms> on=<ms> (paired <ms>) x41=<ms> -> one pass <ms> (paired (x41 - on) / 40)
func _cost() -> void:
	var fx := _effect()
	var we := current_scene.get_node("EnvironmentRig/WorldEnvironment") as WorldEnvironment
	var comp := we.compositor
	var one: Array[CompositorEffect] = [fx]
	var many: Array[CompositorEffect] = [fx]
	for i in 40:
		var extra := SkyMotionVectors.new()
		extra.effect_callback_type = fx.effect_callback_type
		many.append(extra)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode_sleep_usec = 0
	dn.clock.set_time(float(args.get("hour", "1.5")))
	dn.force_weather("clear")
	dn.force_cover = 0.0
	dn.set("_prev_hour", -1.0)
	dn.set("_snap", true)
	_use_view_camera()
	await _frames(20)
	var poses := [["night_sky", eye, Basis.from_euler(Vector3(pitch0, yaw0, 0.0)) * Vector3.FORWARD]]
	for p in COST_POSES:
		var at: Vector3 = p[1]
		poses.append([p[0], Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + at.y, at.z), p[2]])
	var reps := int(args.get("cost_reps", "6"))
	for p in poses:
		var look := Basis.looking_at(p[2])
		view.camera.global_position = p[1]
		var ms := {"off": [], "on": [], "x41": []}
		for r in reps:
			for cfg in ["off", "on", "x41"]:
				fx.enabled = cfg != "off"
				comp.compositor_effects = many if cfg == "x41" else one
				view.camera.basis = look
				for k in 8:
					RenderingServer.force_draw(false)
				var t := Time.get_ticks_usec()
				for k in 30:
					view.camera.basis = Basis(Vector3.UP, deg_to_rad(k)) * look
					RenderingServer.force_draw(false)
				(ms[cfg] as Array).append((Time.get_ticks_usec() - t) / 1000.0 / 30.0)
				await process_frame
		var on_off: Array[float] = []
		var per_pass: Array[float] = []
		for r in reps:
			on_off.append(float(ms.on[r]) - float(ms.off[r]))
			per_pass.append((float(ms.x41[r]) - float(ms.on[r])) / 40.0)
		print("STARCOST %s off=%.2fms on=%.2fms (paired %+.2f) x41=%.2fms -> one pass %.3f ms (%.3f..%.3f)" % [p[0],
				_median(ms.off), _median(ms.on), _median(on_off), _median(ms.x41), _median(per_pass), per_pass.min(),
				per_pass.max()])
	comp.compositor_effects = one
	fx.enabled = true


# --- Helpers -----------------------------------------------------------------------------------------------------

## One rendered frame (forced when macOS does not let the window draw).
func _draw() -> void:
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
	else:
		await process_frame
		RenderingServer.force_draw(false)


func _frames(n: int) -> void:
	for i in n:
		await _draw()


## The moment (day of year) of the new moon before `doy` (illumination minimum).
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
