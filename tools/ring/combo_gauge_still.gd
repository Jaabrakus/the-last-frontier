extends SceneTree
## The combo and the guard's gauge on the strip, for the owner's eye (2026-10-12; BendCombo): the Lives ring, earth against a
## held fire bot, the player's own view. Windowed (it draws; never on top):
##   Godot --path . --resolution 1280x720 -s tools/ring/combo_gauge_still.gd -- out=<dir>
## Writes combo_gauge_x3.png (three hits landed: the combo's bracket), combo_gauge_guard.png (a guard held: its gauge's bracket
## too), combo_gauge_broken.png (the gauge broken: its bracket red) and combo_gauge_crosshair.png (the three crosshairs close,
## side by side). The meters are SwayRing's, round the crosshair.
## Ends with COMBO GAUGE STILL DONE.

const OWN_CFG := "user://combo_gauge_still.cfg"

var out := ""
var p: FrontierPlayer
var c: SwayCaster
var mode: RingMode
var shots: Array[Image] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.light = "noon"
	MatchSetup.round_s = 600.0
	RingRules.rule_set_override = "stock"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _secs(s: float) -> void:
	for i in int(round(s * Engine.physics_ticks_per_second)):
		await physics_frame


func _grab() -> Image:
	for i in 3:
		RenderingServer.force_draw(true)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(name: String) -> void:
	var img := await _grab()
	img.save_png(out.path_join(name + ".png"))
	shots.append(img)
	print("  wrote %s.png" % name)


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	if p == null or mode == null:
		print("COMBO GAUGE STILL DONE (no ring)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	while mode.phase != "FIGHT":
		await process_frame
	mode.foe.held = true
	await _secs(3.5)
	# three hits landed: the combo's bracket (left)
	for i in 3:
		mode.rules.on_hit(mode.foe, p, {"tag": "stone_form/spike", "move": "stone_form"})
	await _secs(0.4)
	await _save("combo_gauge_x3")
	# a guard held: its gauge's bracket (right) drawing down, the combo's still there
	for i in 2:
		mode.rules.on_hit(mode.foe, p, {"tag": "stone_form/spike", "move": "stone_form"})
	c.guard_override = true
	await _secs(1.4)
	await _save("combo_gauge_guard")
	c.guard_override = false
	# broken: the gauge's bracket red
	BendCombo._break(p, null)
	for i in 3:
		mode.rules.on_hit(mode.foe, p, {"tag": "stone_form/spike", "move": "stone_form"})
	await _secs(0.4)
	await _save("combo_gauge_broken")
	# the crosshair close, the three side by side (a 200 px square round the screen's middle, twice the size)
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var r := Rect2i(w / 2 - 100, h / 2 - 100, 200, 200)
	var sheet := Image.create(r.size.x * 3, r.size.y, false, Image.FORMAT_RGB8)
	for i in shots.size():
		sheet.blit_rect(shots[i], r, Vector2i(r.size.x * i, 0))
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	sheet.save_png(out.path_join("combo_gauge_crosshair.png"))
	print("COMBO GAUGE STILL DONE")
	quit(0)
