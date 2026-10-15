extends SceneTree
## The menus on a controller only (PadInput; the owner, 2026-10-15: "just focus on contorller support"): from the main menu
## to a practice and back, by the pad's D-pad, A and Start alone (Input.parse_input_event, as a pad sends them; no click,
## no key, no button pressed by the test):
##   menu       the first pad press finds a button focused (the menu's own, or PadInput's first); the D-pad walks the
##              rows to Practice; A opens its panel, the focus going into it
##   panel      the D-pad walks the panel to Begin; A: a practice asked for, the ring loads and the fight begins
##   practice   its line names the pad's buttons (View, R3, Start); View puts him back at his end, R3 steps the dummy's way
##   ring       Start opens the Esc menu, B closes it; Start again, the D-pad walks it to Main menu; A: back at the main menu,
##              no match under way
##   Godot --headless --fixed-fps 60 --path . -s tests/ui/test_pad_menus.gd
## The last line "PAD MENUS PASSED (<n> checks)" or "PAD MENUS FAILED (<f> of <n>)".

const OWN_CFG := "user://test_pad_menus.cfg"
var checks := 0
var fails: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL " + what)
	else:
		print("  ok   " + what)


func _initialize() -> void:
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup.reload_scheme()
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("PAD MENUS FAILED (watchdog)")
		quit(2))
	change_scene_to_file("res://scenes/main_menu.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


## A pad's button pressed and let go.
func _pad(b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = true
	e.pressure = 1.0
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	e.pressure = 0.0
	Input.parse_input_event(e)
	await _frames(3)


func _focus() -> Control:
	return root.gui_get_focus_owner()


## The focused button's words ("" none): its "Text" label's (BroadcastUI rows), else its own text.
func _words(c: Control) -> String:
	if c == null:
		return ""
	var tl := c.find_child("Text", true, false) as Label
	if tl != null:
		return tl.text
	return String(c.get("text")) if c.get("text") != null else String(c.name)


## Presses the D-pad `dir` until the focused control satisfies `hit` (at most `most` presses): whether it did.
func _walk_to(hit: Callable, dir := JOY_BUTTON_DPAD_DOWN, most := 16) -> bool:
	for i in most:
		if hit.call(_focus()):
			return true
		await _pad(dir)
	return hit.call(_focus())


func _run() -> void:
	await _until(func() -> bool: return current_scene is MainMenu, 600)
	var m := current_scene as MainMenu
	_expect(m != null, "the main menu")
	if m == null:
		return _end()
	await _frames(30)

	# ---- the menu: a focus at the first press, the D-pad to Practice, A into its panel
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var f0 := _focus()
	_expect(f0 is BaseButton and PadInput.active, "the first pad press: a button focused (%s)" % _words(f0))
	var on_practice := await _walk_to(func(c: Control) -> bool: return c != null and c.get_parent() == m._items and _words(c) == "Practice")
	_expect(on_practice, "the D-pad walks the rows to Practice (%s)" % _words(_focus()))
	await _pad(JOY_BUTTON_A)
	await _frames(10)
	var panel := m._panel.find_child("Practice", true, false) != null
	var inside := _focus() != null and m._panel.is_ancestor_of(_focus())
	_expect(panel and inside, "A opens its panel (%s), the focus in it (%s: %s)" % [panel, inside, _words(_focus())])

	# ---- the panel: the D-pad to Begin, A: the ring
	var begin := m._panel.find_child("Begin", true, false) as Button
	var on_begin := await _walk_to(func(c: Control) -> bool: return c != null and c == begin)
	if not on_begin:
		on_begin = await _walk_to(func(c: Control) -> bool: return c != null and c == begin, JOY_BUTTON_DPAD_UP)
	_expect(begin != null and on_begin, "the D-pad walks the panel to Begin (%s)" % _words(_focus()))
	await _pad(JOY_BUTTON_A)
	var asked := MatchSetup.incoming and MatchSetup.practice()
	var fight := await _until(func() -> bool:
		var rm := RingMode.find(self)
		return rm != null and rm.phase == "FIGHT" and current_scene != null and not current_scene.get_meta("loading_hold", false), 3600)
	_expect(asked and fight, "A on Begin: a practice asked for (%s), the ring loaded and fighting (%s)" % [asked, fight])
	if not fight:
		return _end()
	await _frames(60)

	# ---- the practice: its line, View, R3
	var mode := RingMode.find(self)
	var pc := mode.practice_ctl
	var line := pc.practice_line() if pc != null else ""
	_expect(line.contains("View") and line.contains("R3") and line.contains("Start"), "the practice's line names the pad's buttons (%s)" % line)
	var p := mode.player
	var home := p.global_position
	p.global_position = home + (mode.foe.global_position - home).normalized() * 3.0
	await _frames(4)
	var moved := p.global_position.distance_to(home)
	await _pad(JOY_BUTTON_BACK)
	await _frames(20)
	var back_home := p.global_position.distance_to(home)
	_expect(moved > 2.0 and back_home < 1.0, "View puts him back at his end (%.1f m off, then %.1f m)" % [moved, back_home])
	var way0 := String(pc.dummy)
	await _pad(JOY_BUTTON_RIGHT_STICK)
	await _frames(4)
	_expect(String(pc.dummy) != way0, "R3 steps the dummy's way (%s, then %s)" % [way0, pc.dummy])

	# ---- the ring: Start, B, Start, the D-pad to Main menu, A: the main menu again
	var menu := mode.menu as RingMenu
	await _pad(JOY_BUTTON_START)
	var opened := await _until(func() -> bool: return menu.is_open(), 60)
	await _frames(6)
	_expect(opened and _focus() != null, "Start opens the Esc menu, a row focused (%s)" % _words(_focus()))
	await _pad(JOY_BUTTON_B)
	var closed := await _until(func() -> bool: return not menu.is_open(), 60)
	_expect(closed, "B closes it")
	await _frames(6)
	await _pad(JOY_BUTTON_START)
	await _until(func() -> bool: return menu.is_open(), 60)
	await _frames(6)
	var on_main := await _walk_to(_is_main_row, JOY_BUTTON_DPAD_DOWN, 20)
	_expect(on_main, "the D-pad walks it to Main menu (%s)" % _words(_focus()))
	await _pad(JOY_BUTTON_A)
	var back := await _until(func() -> bool: return current_scene is MainMenu, 1200)
	_expect(back and not MatchSetup.active(), "A on it: back at the main menu, no match under way")
	_end()


## The Esc menu's Main menu row.
func _is_main_row(c: Control) -> bool:
	return c != null and _words(c).to_lower() == "main menu"


func _end() -> void:
	if fails.is_empty():
		print("PAD MENUS PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("PAD MENUS FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
