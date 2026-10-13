extends SceneTree
## Round 4's HUD for the owner's eye (Tidebreak, task HUD: a cleaner HUD and side colours): the % ring (the stock rules), earth
## against a fire bot held where it stands, at noon unless light= says. Windowed (it draws):
##   Godot --path . --resolution 1280x720 -s tools/ring/r4_hud_shots.gd -- out=<dir> phase=before|after|sides [light=noon|night]
## phase=before (run at the base, before the HUD's change) and phase=after write r4_hud_firstmatch_<phase>.png (round 2's
## first-match frame: key 1 cast twice) and r4_hud_keys_<element>_<phase>.png. phase=after adds r4_hud_air_strip.png (in the
## air: the Slam and Dodge chips), r4_hud_layouts_L1|L2|L3.png (each layout under camera A | camera C, the body's box
## outlined in the image only), r4_hud_res_1280|1440|1920.png (a fall's centre words up, the plates, the strip), r4_hud_plates.png
## (an earth mirror's plates: home and away), r4_hud_centre_words.png, r4_hud_icons_sheet.png (every chip's icon on the dark and
## on the noon deck at 40 and 80 px) and r4_hud_sheet.png. phase=sides (light=noon, then light=night) writes
## r4_hud_sides_<element>_<light>.png (each element's mirror, home left and away right, at 8, 15 and 25 m from the player's
## camera) and, at noon, the METRIC sides lines (the OKLab dE between the two sides' mean garment colour at 25 m: the garments'
## own pixels, masked by a flat-colour pass of the same frozen frame); light=night also writes r4_hud_sides_sheet.png from both.
## Ends with R4 HUD SHOTS DONE.

const OWN_CFG := "user://r4_hud_shots.cfg"
const Cam := preload("res://tests/ring/r4_hud_cam.gd")

var out := ""
var phase := "after"
var light := "noon"
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var mode: RingMode
var rules: RingRules
var foe: NpcFighter
var strip: Control
var shots := {}
## The camera framing forced at each draw ("" the player's own camera).
var cam_force := ""
var _fwd := Vector3.FORWARD


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("phase="):
			phase = a.substr(6)
		elif a.begins_with("light="):
			light = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup._aim_help = "strong"
	MatchSetup.reload_scheme()
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["earth"] if phase == "sides" else ["fire"]
	MatchSetup.difficulty = "easy"
	MatchSetup.light = light
	RingRules.rule_set_override = "stock"
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	for i in int(round(s * Engine.physics_ticks_per_second)):
		await physics_frame


## The forced framing (A or C): a camera of the tool's own (no spring, no smoothing) put at Cam.xf just before each draw.
var _cam: Camera3D


func _pre_draw() -> void:
	if p == null or not is_instance_valid(p) or p.camera == null:
		return
	if cam_force == "":
		if _cam != null and _cam.current:
			p.camera.make_current()
		return
	if _cam == null:
		_cam = Camera3D.new()
		_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		current_scene.add_child(_cam)
	_cam.fov = p.camera.fov
	_cam.global_transform = Cam.xf(p.global_position, _fwd, cam_force)
	_cam.make_current()


func _grab() -> Image:
	for i in 3:
		RenderingServer.force_draw(true)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(out.path_join(name + ".png"))
	shots[name] = img
	print("  wrote %s.png (%dx%d)" % [name, img.get_width(), img.get_height()])


func _shot(name: String) -> Image:
	await _frames(4)
	var img := await _grab()
	_save(img, name)
	return img


func _element(el: String) -> void:
	MatchSetup.element = el
	for i in 300:
		if p.arena_element == el and p.hotbar.spell != "":
			break
		await process_frame
	await _frames(20)
	if c != null:
		c._quick[el] = KitWords.jab(el)


func _run() -> void:
	await _frames(20)
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	p = lvl.player
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	c = SwayCaster.of(p)
	for i in 1500:
		if mode != null and mode.phase == "FIGHT" and mode.foe != null and not LoadingScreen.covering():
			break
		await physics_frame
	foe = mode.foe
	if foe != null:
		foe.held = true
	await _secs(2.6)                          # (the countdown's words gone)
	rules = RingRules.current()
	strip = p.hud.bend_strip
	_fwd = -p.camera.global_basis.z if p.camera != null else Vector3.FORWARD
	if phase == "sides":
		await _sides()
	else:
		await _common()
		if phase == "after":
			await _after()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	print("R4 HUD SHOTS DONE ", out)
	quit(0)


## The frames made at the base and after: each element's keys, round 2's first-match frame.
func _common() -> void:
	strip.set(&"first_match_override", false)
	for el: String in Bending.ELEMENTS:
		await _element(el)
		await _shot("r4_hud_keys_%s_%s" % [el, phase])
	await _element("earth")
	strip.set(&"first_match_override", true)
	strip.set(&"_casts", [0, 0, 0, 0, 0])
	await _frames(60)
	strip.call(&"count_cast", 0)
	strip.call(&"count_cast", 0)
	await _frames(60)
	await _shot("r4_hud_firstmatch_" + phase)
	strip.set(&"first_match_override", false)


func _after() -> void:
	var sides: GDScript = load("res://scripts/ring/ring_sides.gd")
	# in the air: key 2 the Slam, 3 Dodge, 4 and 5 grey
	await _element("air")
	strip.set(&"air_override", true)
	await _frames(20)
	await _shot("r4_hud_air_strip")
	strip.set(&"air_override", null)
	await _element("earth")
	# the three layouts under camera A and camera C: the body's box drawn on the image only (never on the HUD)
	for lay: String in ["L1", "L2", "L3"]:
		strip.set(&"layout_override", lay)
		var pair: Array = []
		for cam: String in ["A", "C"]:
			cam_force = cam
			await _frames(6)
			var img := await _grab()
			var bx := _body_box(cam, Vector2(img.get_size()))
			var ov := _overlap(bx)
			print("METRIC strip_body_overlap_px layout=%s cam=%s %d (body %s)" % [lay, cam, ov, bx])
			_outline(img, bx, Color(1, 0.2, 0.6))
			pair.append(img)
		cam_force = ""
		_pair(pair, "r4_hud_layouts_" + lay)
	strip.set(&"layout_override", "")
	await _frames(6)
	if rules != null and foe != null:
		rules.reset_pct(p, 0.0)
		rules.reset_pct(foe, 0.0)
		rules.add_pct(p, 37.0, foe, "stone_form/spike")
		rules.add_pct(foe, 128.0, p, "stone_form/cannonball")
	# the centre words: a fall's line, at three sizes
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)   # (1920x1080 fits the screen without a title bar)
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		DisplayServer.window_set_position(Vector2i.ZERO)
		DisplayServer.window_set_size(res)
		await _frames(12)
		if mode != null:
			mode.set(&"_ko_line", RingMode.words("ko_line") % [MatchSetup.competitor("fire"), RingMode.words("ko_left") % 2])
			mode.set(&"_ko_t", 5.0)
		await _frames(8)
		var img := await _shot("r4_hud_res_%d" % res.x)
		print("  window %s -> image %s" % [res, img.get_size()])
		if res.x == 1280:
			_save(img.get_region(Rect2i(0, 0, img.get_width(), int(img.get_height() * 0.5))), "r4_hud_centre_words")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(12)
	if mode != null:
		mode.set(&"_ko_t", 0.0)
	_icons_sheet()
	_sheet()


## The body's box under framing `cam` (Cam's numbers: the same the test measures).
func _body_box(cam: String, size: Vector2) -> Rect2:
	var xf := Cam.xf(p.global_position, _fwd, cam)
	return Cam.box(Cam.body_points(p), xf, p.camera.fov if p.camera != null else 60.0, size)


## How many px of the strip's rects fall in box `bx` (the largest overlap's area's side, px).
func _overlap(bx: Rect2) -> int:
	var worst := 0
	if strip.has_method(&"strip_rects"):
		for r: Rect2 in strip.call(&"strip_rects"):
			var i := r.intersection(bx)
			if i.has_area():
				worst = maxi(worst, int(ceil(minf(i.size.x, i.size.y))))
	return worst


func _outline(img: Image, r: Rect2, col: Color) -> void:
	var a := Vector2i(r.position)
	var b := Vector2i(r.end) - Vector2i.ONE
	for t in 2:
		for x in range(maxi(a.x, 0), mini(b.x + 1, img.get_width())):
			for y: int in [a.y + t, b.y - t]:
				if y >= 0 and y < img.get_height():
					img.set_pixel(x, y, col)
		for y in range(maxi(a.y, 0), mini(b.y + 1, img.get_height())):
			for x: int in [a.x + t, b.x - t]:
				if x >= 0 and x < img.get_width():
					img.set_pixel(x, y, col)


## Two images side by side at half size.
func _pair(imgs: Array, name: String) -> void:
	var hw := 640
	var hh := 360
	var sheet := Image.create(hw * imgs.size() + 6 * (imgs.size() - 1), hh, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	for i in imgs.size():
		var s := (imgs[i] as Image).duplicate() as Image
		s.resize(hw, hh, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(s, Rect2i(0, 0, hw, hh), Vector2i(i * (hw + 6), 0))
	_save(sheet, name)


## Every chip's icon (BendStrip.every_chip) on the dark and on the noon deck (cut from the keys frame), at 40 and 80 px,
## readied (its element's colour) and not (dimmed).
func _icons_sheet() -> void:
	if not ClassDB.class_exists(&"Node") or not strip.has_method(&"every_chip"):
		return
	var chips: Array = strip.call(&"every_chip")
	var deck: Image = shots.get("r4_hud_keys_earth_after")
	var cols := 14
	var cell := Vector2i(96, 128)
	assert(cols >= 14)
	var rows := Bending.ELEMENTS.size()
	var slot := {}
	var pos: Array = []
	for ch: Dictionary in chips:
		var r := Bending.ELEMENTS.find(String(ch.element))
		var k := int(slot.get(r, 0))
		slot[r] = k + 1
		pos.append(Vector2i(k, r))
	var sheet := Image.create(cols * cell.x, rows * cell.y * 2 + 8, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.065, 0.06))
	var deck_tile := deck.get_region(Rect2i(900, 560, cell.x, cell.y)) if deck != null else null
	for half in 2:
		for i in chips.size():
			var ch: Dictionary = chips[i]
			var at := Vector2i((pos[i] as Vector2i).x * cell.x, half * (rows * cell.y + 8) + (pos[i] as Vector2i).y * cell.y)
			if half == 1 and deck_tile != null:
				sheet.blit_rect(deck_tile, Rect2i(Vector2i.ZERO, cell), at)
			var tex: Texture2D = strip.call(&"icon_texture", String(ch.id), String(ch.mode))
			if tex == null:
				continue
			var src := tex.get_image()
			src.convert(Image.FORMAT_RGBA8)
			var lit: Color = strip.call(&"element_colour", String(ch.element))
			_stamp(sheet, src, at + Vector2i(8, 8), 80, lit)
			_stamp(sheet, src, at + Vector2i(28, 90), 40, Color(FrontierHUD.TEXT, 0.85))
	_save(sheet, "r4_hud_icons_sheet")


func _stamp(dst: Image, src: Image, at: Vector2i, px: int, tint: Color) -> void:
	var s := src.duplicate() as Image
	s.resize(px, px, Image.INTERPOLATE_LANCZOS)
	for y in px:
		for x in px:
			var sc := s.get_pixel(x, y)
			var a := sc.a * tint.a
			if a <= 0.01:
				continue
			var q := at + Vector2i(x, y)
			if q.x < 0 or q.y < 0 or q.x >= dst.get_width() or q.y >= dst.get_height():
				continue
			# (the ink round it as the strip draws it, then the tinted art)
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 1)]:
				var sh := q + d
				if sh.x >= 0 and sh.y >= 0 and sh.x < dst.get_width() and sh.y < dst.get_height():
					dst.set_pixelv(sh, dst.get_pixelv(sh).lerp(Color.BLACK, a * 0.45))
	for y in px:
		for x in px:
			var sc := s.get_pixel(x, y)
			var a := sc.a * tint.a
			var q := at + Vector2i(x, y)
			if a <= 0.01 or q.x < 0 or q.y < 0 or q.x >= dst.get_width() or q.y >= dst.get_height():
				continue
			dst.set_pixelv(q, dst.get_pixelv(q).lerp(Color(sc.r * tint.r, sc.g * tint.g, sc.b * tint.b), a))


## The contact sheet: before | after of the first match and each element's keys (the bottom 220 px), the air strip, the plates.
func _sheet() -> void:
	var names := ["firstmatch", "keys_earth", "keys_water", "keys_fire", "keys_air"]
	var band := 220
	var w := 1280
	var h := band * (names.size() + 1) + 130
	var sheet := Image.create(w * 2 + 8, h, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	for i in names.size():
		for k in 2:
			var nm := "r4_hud_%s_%s" % [names[i], ["before", "after"][k]]
			var img: Image = shots.get(nm)
			if img == null and FileAccess.file_exists(out.path_join(nm + ".png")):
				img = Image.load_from_file(out.path_join(nm + ".png"))
			if img != null:
				img.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(img, Rect2i(0, img.get_height() - band, w, band), Vector2i(k * (w + 8), i * band))
	var air: Image = shots.get("r4_hud_air_strip")
	if air != null:
		sheet.blit_rect(air, Rect2i(0, air.get_height() - band, w, band), Vector2i(w + 8, names.size() * band))
	var pl: Image = shots.get("r4_hud_plates")
	if pl == null and FileAccess.file_exists(out.path_join("r4_hud_plates.png")):
		pl = Image.load_from_file(out.path_join("r4_hud_plates.png"))
		pl.convert(Image.FORMAT_RGB8)
	if pl != null:
		sheet.blit_rect(pl, Rect2i(0, 0, w, 130), Vector2i(0, (names.size() + 1) * band))
	_save(sheet, "r4_hud_sheet")


# ---------------------------------------------------------------- the sides' lineups
## Each element's mirror: a team-0 bot (home) and a team-1 bot (away) side by side 8, 15 and 25 m from the player's camera
## along the deck, seen from it; at 25 m the dress's mean colours measured.
func _sides() -> void:
	var sides: GDScript = load("res://scripts/ring/ring_sides.gd")
	# the plates of this live earth mirror (yours home, theirs away), at some %
	if rules != null and foe != null and light == "noon":
		rules.reset_pct(p, 0.0)
		rules.reset_pct(foe, 0.0)
		rules.add_pct(p, 37.0, foe, "stone_form/spike")
		rules.add_pct(foe, 128.0, p, "stone_form/cannonball")
		await _secs(0.6)
		var plates := await _grab()
		_save(plates.get_region(Rect2i(0, 0, plates.get_width(), 130)), "r4_hud_plates")
	if foe != null:
		foe.process_mode = Node.PROCESS_MODE_DISABLED  # (held where it stands, unseen: out of the lineup's frames)
		foe.visible = false
	# (the distances from the player's camera, along the deck: 25 m from the camera stands on the deck's far end, 25 m from
	# the player would be over the water)
	var cam_at := p.camera.global_position if p.camera != null else p.global_position
	var feet := Vector3(cam_at.x, p.global_position.y, cam_at.z)
	var right := _fwd.cross(Vector3.UP).normalized()
	for el: String in Bending.ELEMENTS:
		sides.set(&"sides_override", [[el], [el]])
		var imgs: Array = []
		for d: float in [8.0, 15.0, 25.0]:
			var at := feet + _fwd * d
			var gap := 1.1 + d * 0.02
			var home := _bot("ring_team_a", el, at - right * gap)
			var away := _bot("ring_team_b", el, at + right * gap)
			await _secs(0.6)
			if foe != null:
				foe.visible = false
			for b: Node in [home, away]:
				b.process_mode = Node.PROCESS_MODE_DISABLED   # (held still for the two frames)
			var img := await _grab()
			if d >= 25.0:
				await _measure(el, img, home, away)
			imgs.append(img)
			for b: Node in [home.get_parent(), away.get_parent()]:
				b.queue_free()
			await _frames(4)
		_triple(imgs, "r4_hud_sides_%s_%s" % [el, light])
	sides.set(&"sides_override", null)
	if light == "night":
		var rows: Array = []
		for el: String in Bending.ELEMENTS:
			for lt: String in ["noon", "night"]:
				var f := out.path_join("r4_hud_sides_%s_%s.png" % [el, lt])
				if FileAccess.file_exists(f):
					rows.append(Image.load_from_file(f))
		if not rows.is_empty():
			var w := (rows[0] as Image).get_width()
			var hh := (rows[0] as Image).get_height()
			var sh := Image.create(w * 2, hh * int(ceil(rows.size() / 2.0)), false, Image.FORMAT_RGB8)
			for i in rows.size():
				var im := rows[i] as Image
				im.convert(Image.FORMAT_RGB8)
				sh.blit_rect(im, Rect2i(0, 0, w, hh), Vector2i((i % 2) * w, (i / 2) * hh))
			_save(sh, "r4_hud_sides_sheet")


func _bot(faction: String, el: String, at: Vector3) -> NpcFighter:
	var opts := {"face": p.global_position, "tag": "ring", "tactics": "bend", "element": el, "weapon": "", "sidearm": "",
			"skill": "easy", "seed": 1750, "y": at.y}
	var sq := NpcSquad.spawn(lvl, faction, 1, at, opts)
	var b := sq.members[0] as NpcFighter
	b.held = true
	b.no_death = true
	return b


## The mean colour of each bot's dress in `img`: the pixels of its own middle (a column 0.2 m wide from its knees, 0.45 m up,
## to its chest, 1.45 m up, through the player's camera: the tunic, the sash and the trousers, never the deck or the curtain
## behind, which move from frame to frame). The METRIC lines.
func _measure(el: String, img: Image, home: Node3D, away: Node3D) -> void:
	var sums := [Vector3.ZERO, Vector3.ZERO]
	var ns := [0, 0]
	var bots := [home, away]
	for side in 2:
		var b := bots[side] as Node3D
		var right := p.camera.global_basis.x
		var lo := p.camera.unproject_position(b.global_position + Vector3.UP * 0.45 - right * 0.1)
		var hi := p.camera.unproject_position(b.global_position + Vector3.UP * 1.45 + right * 0.1)
		var r := Rect2i(Vector2i(mini(int(lo.x), int(hi.x)), mini(int(lo.y), int(hi.y))),
				Vector2i(absi(int(hi.x) - int(lo.x)) + 1, absi(int(hi.y) - int(lo.y)) + 1))
		for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
				var a := img.get_pixel(x, y)
				sums[side] += Vector3(a.r, a.g, a.b)
				ns[side] += 1
	if ns[0] == 0 or ns[1] == 0:
		print("METRIC sides_deltaE %s n/a (no dress pixels: %s)" % [el, ns])
		return
	var ca: Vector3 = sums[0] / float(ns[0])
	var cb: Vector3 = sums[1] / float(ns[1])
	var la := _oklab(Color(ca.x, ca.y, ca.z))
	var lb := _oklab(Color(cb.x, cb.y, cb.z))
	print("METRIC sides_deltaE %s %.1f  sides_value_diff %s %.3f  (home %s n %d, away %s n %d, 25 m, %s)" % [el,
			la.distance_to(lb) * 100.0, el, absf(la.x - lb.x), Color(ca.x, ca.y, ca.z).to_html(false), ns[0],
			Color(cb.x, cb.y, cb.z).to_html(false), ns[1], light])


## A body's box on the screen (a 0.9 x 0.9 x 1.95 m box over its feet through the player's camera).
func _screen_box(b: Node3D) -> Rect2i:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var pts: Array = []
	for i in 8:
		pts.append(b.global_position + Vector3(0.45 if i & 1 else -0.45, 1.95 if i & 2 else 0.0, 0.45 if i & 4 else -0.45))
	for pt: Vector3 in pts:
		var s2 := p.camera.unproject_position(pt)
		lo = lo.min(s2)
		hi = hi.max(s2)
	if lo.x == INF:
		return Rect2i()
	return Rect2i(Vector2i(lo) - Vector2i(3, 3), Vector2i(hi - lo) + Vector2i(6, 6))


static func _oklab(c: Color) -> Vector3:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = f.call(c.r)
	var g: float = f.call(c.g)
	var b: float = f.call(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
			0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


## Three frames side by side at a third of their size, the middle third of each (where the two stand).
func _triple(imgs: Array, name: String) -> void:
	var cw := 640
	var chh := 420
	var sheet := Image.create(cw * imgs.size() + 6 * (imgs.size() - 1), chh, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	for i in imgs.size():
		var im := imgs[i] as Image
		var r := Rect2i(im.get_width() / 2 - cw / 2, im.get_height() - chh - 20, cw, chh)
		sheet.blit_rect(im, r, Vector2i(i * (cw + 6), 0))
	_save(sheet, name)
