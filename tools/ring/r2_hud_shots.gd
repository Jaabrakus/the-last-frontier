extends SceneTree
## Round 2's HUD and lessons for the owner's eye (skills_r2 HUD_LESSONS: what the player reads): the ring at noon, the bot held,
## the HUD over it at 1280 x 720. Windowed (it draws):
##   Godot --path . --resolution 1280x720 -s tools/ring/r2_hud_shots.gd -- out=<dir>
## Writes <dir>/r2_hud_keys_<element>.png, r2_hud_firstmatch.png (key 1 cast twice: its "tap twice" in, the others out),
## r2_hud_direction.png (W held), r2_hud_firstmoves.png, r2_hud_wheel.png (Tab held, a move pointed at), r2_hud_firsttime.png
## (the buttons' first-time panel), r2_hud_heldstone.png (a stone of his held: "E again: throw it back"), r2_hud_otherways.png
## (the Esc menu's Controls panel), r2_hud_lesson_<element>.png (each element's guard drill card) and r2_hud_sheet.png (the
## strips cropped one under another, the wheel, the panel and the cards beside them). The key layout of round 2 is put in
## (tests/ring/r2_layout.gd) where the kits' data has not merged; the held stone is a stand-in carrying his mark (no catch
## is made). Ends with R2 HUD SHOTS DONE.

const R2Layout := preload("res://tests/ring/r2_layout.gd")
const OWN_CFG := "user://r2_hud_shots.cfg"
const STRIP_RECT := Rect2i(140, 520, 1000, 200)

var out := ""
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode
var shots := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup.reload_scheme()
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	R2Layout.apply()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.light = "noon"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> Image:
	await _frames(4)
	for i in 3:
		RenderingServer.force_draw(true)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join(name + ".png"))
	shots[name] = img
	print("  shot ", name)
	return img


func _element(el: String) -> void:
	MatchSetup.element = el
	for i in 240:
		if p.arena_element == el and p.hotbar.spell != "":
			break
		await process_frame
	await _frames(20)


func _run() -> void:
	await _frames(10)
	lvl = current_scene as RingLevel
	var t := 0
	while t < 1500 and (float(lvl.get_meta(&"loading_progress", 1.0)) < 1.0 or bool(lvl.get_meta(&"loading_hold", false))):
		await process_frame
		t += 1
	p = lvl.player
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	c = SwayCaster.of(p)
	rm = RingMode.find(self)
	for i in 400:
		if rm == null or (rm.phase == "FIGHT" and rm.foe != null):
			break
		await process_frame
	var hold := func() -> void:
		if rm != null and rm.foe != null and is_instance_valid(rm.foe):
			rm.foe.held = true
	physics_frame.connect(hold)
	await _frames(180)                       # (the countdown's "Break!" gone from the screen)
	var strip := p.hud.bend_strip
	strip.first_match_override = false
	# the keys scheme, each element
	for el: String in Bending.ELEMENTS:
		await _element(el)
		c._quick[el] = KitWords.jab(el)
		await _shot("r2_hud_keys_" + el)
	await _element("earth")
	# the first match: key 1 cast twice, its "tap twice" in; the rest still out
	strip.first_match_override = true
	strip._casts = [0, 0, 0, 0, 0]
	await _frames(60)
	strip.count_cast(0)
	strip.count_cast(0)
	await _frames(60)
	await _shot("r2_hud_firstmatch")
	strip.first_match_override = false
	# a stone of his held
	var held := Node3D.new()
	held.name = "HeldStoneStandIn"
	held.set_meta(&"bend_held_by", p.get_instance_id())
	lvl.add_child(held)
	held.add_to_group(FormStone.GROUP)
	await _frames(10)
	await _shot("r2_hud_heldstone")
	held.queue_free()
	# the other ways to pick moves
	MatchSetup.set_scheme("direction")
	c.dir_override = "forward"
	await _frames(20)
	await _shot("r2_hud_direction")
	c.dir_override = null
	MatchSetup.set_scheme("first_moves" if "first_moves" in MatchSetup.SCHEMES else "simple")
	await _frames(20)
	await _shot("r2_hud_firstmoves")
	MatchSetup.set_scheme("radial")
	await _frames(10)
	var w := c.radial
	if w != null:
		w.held_override = true
		await _frames(10)
		if not w.is_open:
			w.open()
		w.pick_toward(w.dir_of(3) * 140.0)
		await _frames(10)
		await _shot("r2_hud_wheel")
		w.close(false)
		w.held_override = null
	MatchSetup.set_scheme("keys")
	await _frames(10)
	# the first-time panel (the buttons)
	var how := p.get_node_or_null(^"HowTo") as HowTo
	if how != null:
		how.cfg_path = "user://r2_hud_shots_howto.cfg"
		how.reset()
		how.enabled = true
		for i in 400:
			if how.current != "" and how._panel.modulate.a > 0.95:
				break
			await process_frame
		await _shot("r2_hud_firsttime")
		how.enabled = false
		how._panel.visible = false
		how.current = ""
		DirAccess.remove_absolute(ProjectSettings.globalize_path(how.cfg_path))
	# the Esc menu's Controls panel: the other ways to pick moves
	var menu := rm.menu as RingMenu if rm != null else null
	if menu != null:
		menu.open()
		await _frames(4)
		menu._controls()
		await _frames(10)
		await _shot("r2_hud_otherways")
		menu.close()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _frames(10)
	# the lessons' guard drill card for each element
	if rm != null:
		var ls := RingLessons.new()
		ls.name = RingLessons.NODE_NAME
		ls.mode = rm
		rm.add_child(ls)
		await _frames(10)
		for el: String in Bending.ELEMENTS:
			await _element(el)
			ls.start()
			for i in ls.list.size():
				if String(ls.list[i].id) in ["guard", "catch"]:
					ls.at = i
			ls._begin()
			await _frames(40)
			await _shot("r2_hud_lesson_" + el)
		ls.queue_free()
	_sheet()
	physics_frame.disconnect(hold)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	print("R2 HUD SHOTS DONE ", out)
	quit(0)


## The strips cropped one under another (the four elements, the first match, a held stone, direction, first moves), then the
## wheel, the first-time panel and the earth and fire cards side by side under them.
func _sheet() -> void:
	var rows := ["r2_hud_keys_earth", "r2_hud_keys_water", "r2_hud_keys_fire", "r2_hud_keys_air", "r2_hud_firstmatch",
			"r2_hud_heldstone", "r2_hud_direction", "r2_hud_firstmoves"]
	var w := STRIP_RECT.size.x
	var h := STRIP_RECT.size.y
	var thumb := Vector2i(w / 2, 280)
	var sheet := Image.create(w, h * rows.size() + thumb.y * 2, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.05, 0.045, 0.04))
	for i in rows.size():
		var img: Image = shots.get(rows[i])
		if img != null:
			sheet.blit_rect(img, STRIP_RECT, Vector2i(0, i * h))
	var y0 := h * rows.size()
	var tiles := [["r2_hud_wheel", Rect2i(340, 60, 600, 600)], ["r2_hud_firsttime", Rect2i(0, 0, 720, 420)],
			["r2_hud_lesson_earth", Rect2i(640, 180, 640, 360)], ["r2_hud_lesson_fire", Rect2i(640, 180, 640, 360)]]
	for i in tiles.size():
		var img: Image = shots.get(tiles[i][0])
		if img == null:
			continue
		var r: Rect2i = tiles[i][1]
		var part := img.get_region(r)
		part.resize(thumb.x, thumb.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(part, Rect2i(Vector2i.ZERO, thumb), Vector2i((i % 2) * thumb.x, y0 + (i / 2) * thumb.y))
	sheet.save_png(out.path_join("r2_hud_sheet.png"))
	print("  shot r2_hud_sheet")
