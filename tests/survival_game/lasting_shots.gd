extends SceneTree
## Look-check stills of the lasting conditions (LastingConditions) with survival on; windowed, wrap it in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tests/survival_game/lasting_shots.gd -- out=<abs dir> survival=on
##
##   vitals.png     the vitals row with the ague, the flux and a festering wound on (their icons, the rings)
##   condition.png  the Condition tab: Body, then Lasting harm (each with its cure and how far it has mended, what is
##                  coming on)
##   all.png        every icon at once (wasted, the ague, festering, the flux, sore feet, chilled)
##   sheet.png      all of them
## Ends with LASTING SHOTS DONE. The icons are the project's own.

const CELL := Vector2i(640, 360)

var out := ""
var shots: Array = []
var player: FrontierPlayer
var b: SurvivalBridge


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	await _frames(120)
	b = SurvivalBridge.find(self)
	var lc := b.lasting
	# the ague and the flux mending, a festering wound not yet dressed; the chill coming on
	for id in ["ague", "flux", "festering"]:
		var st := lc.state(id)
		st["on"] = true
		st["recover"] = 0.0
	lc.state("ague")["recover"] = 0.35 * float(LastingConditions.DEFS.ague.recover)
	lc.state("flux")["recover"] = 0.6 * float(LastingConditions.DEFS.flux.recover)
	lc.state("festering")["dressed"] = false
	lc.state("sore_feet")["exposure"] = 0.55 * float(LastingConditions.DEFS.sore_feet.exposure)
	b.chill.state()["exposure"] = 0.4 * LastingChill.EXPOSURE_MIN
	player.health = 55.0
	b.core.state.needs["health"] = 55.0
	b._health = b.core.health()
	await _frames(30)
	await _crop_shot("vitals", Rect2i(0, 560, 900, 160))
	var sc := InventoryScreen.open_for(player, "condition")
	await _frames(20)
	await _shot("condition")
	sc.queue_free()
	paused = false
	await _frames(10)
	for id in LastingConditions.IDS:
		lc.state(id)["on"] = true
	lc.state("festering")["dressed"] = true
	lc.state("festering")["recover"] = 0.5 * float(LastingConditions.DEFS.festering.recover)
	b.chill.state()["on"] = true
	await _frames(30)
	await _crop_shot("all", Rect2i(0, 560, 1100, 160))
	_sheet()
	print("LASTING SHOTS DONE ", out)
	quit()


func _capture() -> Image:
	await _frames(2)
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()


func _shot(name: String) -> void:
	var img := await _capture()
	img.save_png(out.path_join(name + ".png"))
	var cell := img.duplicate() as Image
	cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	shots.append(cell)
	print("saved ", name)


func _crop_shot(name: String, r: Rect2i) -> void:
	var img := await _capture()
	var sub := img.get_region(r)
	sub.save_png(out.path_join(name + ".png"))
	var cell := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGB8)
	cell.fill(Color(0.08, 0.08, 0.08))
	var s := sub.duplicate() as Image
	var k := minf(float(CELL.x) / s.get_width(), float(CELL.y) / s.get_height())
	s.resize(int(s.get_width() * k), int(s.get_height() * k), Image.INTERPOLATE_BILINEAR)
	s.convert(Image.FORMAT_RGB8)
	cell.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i((CELL.x - s.get_width()) / 2, (CELL.y - s.get_height()) / 2))
	shots.append(cell)
	print("saved ", name)


func _sheet() -> void:
	var grid := Image.create(CELL.x * shots.size(), CELL.y, false, Image.FORMAT_RGB8)
	for i in shots.size():
		grid.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i * CELL.x, 0))
	grid.save_png(out.path_join("sheet.png"))
