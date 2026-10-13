extends SceneTree
## Round 4 READ's camera lineup for the owner's eye (RingCamera, data/ring/camera.json): the % ring itself (stock rules),
## earth against an earth bot held where it stands, at noon, 1280 x 720, each variant A-D (A is round 3's camera: the
## "before") on the same three frozen moments:
##   spike     an incoming Spike from 15 m straight on, frozen 2.5 m before his chest (the player aiming at the thrower)
##   fireball  a Fireball from 8 m at 20 degrees to his right, frozen 2 m before his chest (the player aiming down the deck)
##   lip       the player thrown off the lip backward, frozen 1.4 m out (MOVE's off-deck framing on)
## and, for each variant, the last 3 m of the incoming Spike in 6 frames (3.0, 2.4, 1.8, 1.2, 0.6 and 0 m before his chest).
## Windowed (it draws):
##   Godot --path . --resolution 1280x720 -s tools/ring/camera_lineup.gd -- out=<dir> [light=noon]
## Writes <dir>/r4_read_camera_<variant>_<moment>.png, r4_read_camera_sheet.png (A-D x the moments, labelled) and
## r4_read_camera_last3m_<A..D>.png. Ends with CAMERA LINEUP DONE.

const OWN_CFG := "user://camera_lineup.cfg"
const VARIANTS := ["close", "shoulder", "high", "high_shoulder"]
const MOMENTS := ["spike", "fireball", "lip"]
const LAST := [3.0, 2.4, 1.8, 1.2, 0.6, 0.0]
const CHEST_M := 1.15
## How long the off-deck framing eases before the lip's frame (s; movement.json cam.in_s 0.35).
const LIP_S := 0.6

var out := ""
var light := "noon"
var lvl: RingLevel
var p: FrontierPlayer
var mode: RingMode
var foe: NpcFighter
var ring: RingArena
var _hold := {}
var _label: Label
var _shots := {}           ## "variant/moment" -> Image


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("light="):
			light = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup._aim_help = "off"
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["earth"]
	MatchSetup.difficulty = "easy"
	MatchSetup.light = light
	RingRules.rule_set_override = "stock"
	physics_frame.connect(_holds)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	for i in int(round(s * Engine.physics_ticks_per_second)):
		await physics_frame


func _holds() -> void:
	for b: Variant in _hold.keys():
		if not is_instance_valid(b):
			_hold.erase(b)
			continue
		var n := b as CharacterBody3D
		n.global_position = _hold[b]
		n.velocity = Vector3.ZERO


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
	print("  wrote %s.png" % name)


## A deck place `s` m in from end `e`'s lip (negative: out past it), `z` across, `y` over the deck's top.
func at_s(e: int, s: float, z := 0.0, y := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * (ring.half_l() - s), ring.top() + y, z))


func _run() -> void:
	await _frames(20)
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	p = lvl.player
	ring = lvl.ring
	p.ignore_mouse_capture = true
	for i in 900:
		if mode.phase == "FIGHT" and not LoadingScreen.covering():
			break
		await physics_frame
	await _secs(0.5)
	foe = mode.foe
	foe.held = true
	print("  stock %s, RingMoves on the player %s" % [RingRules.stock_on(), RingMoves.of(p) != null])
	var layer := CanvasLayer.new()
	layer.layer = 120
	current_scene.add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 650)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)
	for k: String in VARIANTS:
		RingCamera.override = k
		var v := RingCamera.variant(k)
		await _spike(k, v)
		await _fireball(k, v)
		await _lip(k, v)
	_label.text = ""
	_sheet()
	RingCamera.override = ""
	RingRules.rule_set_override = ""
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	print("CAMERA LINEUP DONE")
	quit(0)


func _tag(v: Dictionary, what: String) -> void:
	_label.text = "%s  %s%s  ·  %s" % [v.get("letter", "?"), v.get("label", "?"), "  (round 3)" if v.get("letter", "") == "A" else "", what]


## The player at `pos` facing `look`, still and held; the foe at `fpos` facing the player, held.
func _stage(pos: Vector3, look: Vector3, fpos: Vector3) -> void:
	_hold.clear()
	var f := look - pos
	f.y = 0.0
	RingLevel.place(p, Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), pos))
	var g := pos - fpos
	g.y = 0.0
	RingLevel.place(foe, Transform3D(Basis.looking_at(g.normalized(), Vector3.UP), fpos))
	_hold[p] = pos
	_hold[foe] = fpos
	p.pitch = 0.0
	p.yaw = atan2(-f.x, -f.z)
	await _secs(0.8)


## The crosshair on `t` (yaw and pitch stepped onto it).
func _aim_at(t: Vector3) -> void:
	for i in 14:
		var cam := p.camera
		var to := t - cam.global_position
		var fwd := -cam.global_basis.z
		p.yaw = wrapf(p.yaw + wrapf(atan2(-to.x, -to.z) - atan2(-fwd.x, -fwd.z), -PI, PI), -PI, PI)
		p.pitch += atan2(to.y, Vector2(to.x, to.z).length()) - atan2(fwd.y, Vector2(fwd.x, fwd.z).length())
		await physics_frame
		await process_frame


func _spike(k: String, v: Dictionary) -> void:
	var e := mode.player_end
	var me := at_s(e, 10.0)
	var them := at_s(e, 25.0)
	await _stage(me, them, them)
	var chest := me + Vector3.UP * CHEST_M
	await _aim_at(them + Vector3.UP * CHEST_M)
	var dir := (chest - (them + Vector3.UP * CHEST_M)).normalized()
	var sd: Dictionary = SwayMoves.move("stone_form").get("spike", {})
	var st := FormStone.spike(current_scene, them, dir, sd, 3, "stone")
	st.take()
	st.collision_layer = 0
	st.collision_mask = 0
	var frames: Array = []
	for d: float in [2.5] + LAST:
		var tip := chest - dir * (0.3 + d)
		st.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), tip - dir * st.height)
		await _frames(2)
		if is_equal_approx(d, 2.5):
			_tag(v, "a Spike from 15 m, 2.5 m out")
			_shots[k + "/spike"] = await _grab()
			_save(_shots[k + "/spike"], "r4_read_camera_%s_spike" % k)
		else:
			_tag(v, "the last 3 m: %.1f m out" % d)
			frames.append(await _grab())
	st.queue_free()
	_grid(frames, 3, 0.4, "r4_read_camera_last3m_%s" % String(v.get("letter", k)))


func _fireball(k: String, v: Dictionary) -> void:
	var e := mode.player_end
	var me := at_s(e, 10.0)
	var ahead := at_s(e, 25.0)
	var fwd := (ahead - me).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var from_dir := (fwd * cos(deg_to_rad(20.0)) + right * sin(deg_to_rad(20.0))).normalized()
	var them := me + from_dir * 8.0
	await _stage(me, ahead, them)
	await _aim_at(ahead + Vector3.UP * CHEST_M)
	var chest := me + Vector3.UP * CHEST_M
	var spec: Dictionary = ((SwayMoves.move("fire_blast").get("bend", {}) as Dictionary).get("fireball", {}) as Dictionary).duplicate(true)
	var at := chest + from_dir * 2.0
	var b := BendBolt.launch(foe, at, -from_dir, spec)
	b.set_physics_process(false)
	b.global_position = at
	await _secs(0.25)
	_tag(v, "a Fireball from 8 m at 20 deg, 2 m out")
	_shots[k + "/fireball"] = await _grab()
	_save(_shots[k + "/fireball"], "r4_read_camera_%s_fireball" % k)
	b.end("lineup")
	await _secs(0.3)


func _lip(k: String, v: Dictionary) -> void:
	# (frozen, not played: thrown back off the end's lip, 1.4 m out and 0.4 m over the deck's top, still rising, facing the
	# deck; held there so no life is lost between the variants; the off-deck framing given LIP_S to ease in)
	var e := mode.player_end
	var them := at_s(e, 9.0)
	var lip := ring.nearest_lip(at_s(e, 0.0))
	var n: Vector3 = lip.normal
	var me := Vector3(lip.point) + n * 1.4 + Vector3.UP * 0.4
	await _stage(me, them, them)
	var rm := RingMoves.of(p)
	if rm != null:
		rm.set(&"_air", true)
	await _aim_at(them + Vector3.UP * CHEST_M)
	await _secs(LIP_S)
	_tag(v, "thrown off the lip (the off-deck view)")
	_shots[k + "/lip"] = await _grab()
	_save(_shots[k + "/lip"], "r4_read_camera_%s_lip" % k)
	_hold.erase(p)
	await _stage(at_s(e, 10.0), them, them)
	if rm != null:
		rm.set(&"_air", false)
	await _secs(0.6)


## Images in a grid of `cols`, each scaled by `sc`.
func _grid(imgs: Array, cols: int, sc: float, name: String) -> void:
	if imgs.is_empty():
		return
	var w := int((imgs[0] as Image).get_width() * sc)
	var h := int((imgs[0] as Image).get_height() * sc)
	var rows := int(ceil(float(imgs.size()) / cols))
	var sheet := Image.create(cols * w + (cols - 1) * 6, rows * h + (rows - 1) * 6, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.09))
	for i in imgs.size():
		var s := (imgs[i] as Image).duplicate() as Image
		s.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(s, Rect2i(0, 0, w, h), Vector2i((i % cols) * (w + 6), (i / cols) * (h + 6)))
	_save(sheet, name)


func _sheet() -> void:
	var imgs: Array = []
	for k: String in VARIANTS:
		for m: String in MOMENTS:
			if _shots.has(k + "/" + m):
				imgs.append(_shots[k + "/" + m])
	_grid(imgs, MOMENTS.size(), 0.4, "r4_read_camera_sheet")
