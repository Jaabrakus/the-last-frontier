extends SceneTree
## Round 4 SIMPLE's review images for the owner's eye, the % ring (rules stock), earth against a water bot held at its end,
## 1280 x 720. Windowed (it draws):
##   Godot --path . --resolution 1280x720 -s tools/ring/r4_simple_shots.gd -- out=<dir>
## <dir>/r4_simple_strip_basic.png: the key strip, three crops stacked: Basic on the deck (LMB, E, 1, 2, 3: 4 and 5 not there
## before the first win; Basic's help line), Basic in the air (3 grey "lands": no dodge under Basic), Full on the deck (the
## seven chips, as round 3). <dir>/r4_simple_recovery_strip.png: a held-Space recovery under Basic, 8 frames (every
## STEP_S from the hit) from the side: thrown off the end, the helper's double jump and Rise, the edge, the climb.
## Needs SIMPLE's hooks applied (the strip's Basic look: api_needed_from_others); without them the strip is Full's in all
## three. Ends with R4 SIMPLE SHOTS DONE.

const OWN_CFG := "user://r4_simple_shots.cfg"
const STEP_S := 0.3

var out := ""
var p: FrontierPlayer
var mode: RingMode
var ring: RingArena
var foe: NpcFighter
var rm: RingMoves
var _foe_at := Vector3.INF
var _side_cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup._aim_help = "light"
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("basic")
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "easy"
	RingRules.rule_set_override = "stock"
	physics_frame.connect(_hold_foe)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _hold_foe() -> void:
	if foe != null and is_instance_valid(foe):
		foe.held = true
		if _foe_at == Vector3.INF:
			_foe_at = foe.global_position
		foe.global_position = _foe_at
		foe.velocity = Vector3.ZERO


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


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


func _run() -> void:
	for i in 900:
		await physics_frame
		mode = RingMode.find(self)
		p = mode.player if mode != null else null
		if p != null and p.arena_element != "" and mode.rules != null and SwayCaster.of(p) != null and mode.foe != null:
			break
	if p == null:
		print("R4 SIMPLE SHOTS FAILED (no ring)")
		quit(1)
		return
	while mode.phase != "FIGHT":
		await physics_frame
	foe = mode.foe
	ring = mode.ring
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	RingAssist.install(p)
	rm = RingMoves.of(p)
	await _strip_shots()
	await _recovery_shots()
	print("R4 SIMPLE SHOTS DONE")
	RingRules.rule_set_override = ""
	quit(0)


func _strip_node() -> Control:
	var found := root.find_children("*", "BendStrip", true, false)
	return found[0] as Control if not found.is_empty() else null


## The strip's rect, a margin round it, cut from a frame.
func _crop(img: Image, st: Control) -> Image:
	var r := Rect2i(st.get_global_rect()) if st != null else Rect2i(0, img.get_height() - 220, img.get_width(), 220)
	r = r.grow(14).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r)


func _place_deck() -> void:
	var g := RingMoves.arena_geo(ring)
	var xf: Transform3D = g.xf
	p.global_position = xf * Vector3(-float(g.hl) + 8.0, float(g.top) + 0.05, 0.0)
	p.velocity = Vector3.ZERO
	rm.placed()


func _strip_shots() -> void:
	p.camera.make_current()
	_place_deck()
	await _secs(1.0)
	var st := _strip_node()
	var crops: Array = []
	crops.append(_crop(await _grab(), st))
	# in the air (BendStrip.air_override: the strip as it stands through any jump)
	st.set(&"air_override", true)
	await _secs(0.4)
	crops.append(_crop(await _grab(), st))
	st.set(&"air_override", null)
	await _secs(0.4)
	MatchSetup.set_controls("full")
	await _secs(0.5)
	crops.append(_crop(await _grab(), st))
	MatchSetup.set_controls("basic")
	var w := 0
	var h := 0
	for c: Image in crops:
		w = maxi(w, c.get_width())
		h += c.get_height() + 8
	var sheet := Image.create(w, h - 8, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	var y := 0
	for c: Image in crops:
		sheet.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i((w - c.get_width()) / 2, y))
		y += c.get_height() + 8
	_save(sheet, "r4_simple_strip_basic")


func _recovery_shots() -> void:
	var g := RingMoves.arena_geo(ring)
	var xf: Transform3D = g.xf
	var n: Vector3 = (xf.basis * Vector3(-1.0, 0.0, 0.0)).normalized()
	var side: Vector3 = (xf.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var lip: Vector3 = xf * Vector3(-float(g.hl), float(g.top), 0.0)
	p.global_position = lip - n * 3.0 + Vector3.UP * 0.05
	p.yaw = atan2(-n.x, -n.z)
	p.velocity = Vector3.ZERO
	rm.placed()
	await _secs(0.6)
	_side_cam = Camera3D.new()
	_side_cam.fov = 55.0
	current_scene.add_child(_side_cam)
	_side_cam.global_position = lip + n * 2.0 + side * 7.5 + Vector3.UP * 0.6
	_side_cam.look_at(lip + n * 2.0 - Vector3.UP * 1.2, Vector3.UP)
	_side_cam.make_current()
	await _frames(4)
	BendKnock.of(p).knock(Vector3.ZERO, foe, {"_launch": {"v": n * 13.0 + Vector3.UP * 7.0, "hitstun_s": 0.55, "tumble": true}})
	p.controls.set_held(&"jump", true)
	var shots: Array = []
	for k in 8:
		shots.append(await _grab())
		await _secs(STEP_S)
	p.controls.set_held(&"jump", false)
	var cols := 4
	var sw := 640
	var sh := 360
	var sheet := Image.create(cols * sw + (cols - 1) * 6, 2 * sh + 6, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	for k in shots.size():
		var s := (shots[k] as Image).duplicate() as Image
		s.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(s, Rect2i(0, 0, sw, sh), Vector2i((k % cols) * (sw + 6), (k / cols) * (sh + 6)))
	_save(sheet, "r4_simple_recovery_strip")
