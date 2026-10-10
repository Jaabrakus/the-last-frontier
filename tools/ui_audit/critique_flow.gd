extends SceneTree
## Critique probe (FUNCTIONAL) of the broadcast menus' flows, driven by real key and mouse events and read back from the
## scenes (never the character creator: MainMenu.creator_hook is a stand-in with a closed(accepted) signal). Needs a window.
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/critique_flow.gd -- part=menu|ring [out=DIR] [tag=_720] [px=1280x720]
## part=menu (the menu's scene in a SubViewport of px):
##   back     the first press offers the creator; Back counts as offered (no look kept, the setup opens, no second offer, not in a new run)
##   element  Accept -> "Choose your element" -> the pick by key and by a single and a double mouse click -> the lobby shows that
##            element and the character's name, and a new menu (a new run) keeps both and asks nothing
##   class    the rundown's Class & talents opens the window, Esc closes it, the focus is back on the row; the same from the setup's link
##   keys     the lobby's rows reached with Up, Down, Left, Right; Esc in the setup comes back to the row that opened it
## part=ring (a real quick match, the window's size): the Esc menu's rows all inside the window and reachable by Down/Up, each panel's
##   rows reachable and Left/Right changing a value, Esc stepping back out, and the match-end board's numbers against the match's own
## Prints "CRITIQUE FLOW ... PASSED n" / "FAILED" with each failed check; writes flow_<part><tag>.json under `out`.
## The test run's own look file and offered flag (user://appearance_test) are put aside and given back; GameSettings has its own cfg.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const HOWTO := "user://how_to.cfg"
const OWN_CFG := "user://critique_flow.cfg"
const LIMIT_S := 540.0

var part := "menu"
var out := ""
var tag := ""
var px := Vector2i(1600, 900)
var vp: SubViewport
var m: MainMenu
var lvl: RingLevel
var mode: RingMode
var player: FrontierPlayer
var checks := 0
var fails: Array[String] = []
var notes := {}
var stubs: Array = []
var _stash := {}
var kos: Array = []


class StubCreator extends Node:
	signal closed(accepted: bool)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var v := kv.get_slice("=", 1)
		match kv.get_slice("=", 0):
			"part": part = v
			"out": out = v
			"tag": tag = v
			"px": px = Vector2i(int(v.get_slice("x", 0)), int(v.get_slice("x", 1)))
	if not CaptureKit.begin(self, "critique_flow", out, true):
		return
	auto_accept_quit = false
	CaptureKit.keep([HOWTO])
	seed(1750)
	BroadcastUI.hover_focus = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup.reload_scheme()
	InputSetup.ensure()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = "strong"
	MainMenu.launch_hook = Callable()
	if part == "menu" or part == "mouse":
		MainMenu.launch_hook = func(path: String) -> void:          # (Begin never loads the ring in the menu part: it is noted)
			notes["launched"] = path
			print("CRITIQUE FLOW launch_hook called with ", path)
	for lp: String in [AppearanceStore.current_path(), AppearanceStore.offered_path()]:
		_stash[lp] = FileAccess.get_file_as_bytes(lp) if FileAccess.file_exists(lp) else null
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
	MainMenu.creator_hook = func(_first: bool) -> Object:
		var sc := StubCreator.new()
		stubs.append(sc)
		return sc
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		ok(false, "watchdog: the run did not finish in %d s" % int(LIMIT_S))
		_end(2))
	print("CRITIQUE FLOW part=%s window=%s" % [part, DisplayServer.window_get_size()])
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails.append(what)
		print("  FAIL ", what)


func _end(code := 0) -> void:
	Engine.time_scale = 1.0
	paused = false
	RingReplay.force = ""
	FirstHints.force = false
	MainMenu.creator_hook = Callable()
	MainMenu.launch_hook = Callable()
	MainMenu.offer_check_run = true
	for lp: String in _stash:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
		if _stash[lp] != null:
			var lf := FileAccess.open(lp, FileAccess.WRITE)
			if lf != null:
				lf.store_buffer(_stash[lp])
				lf.close()
	BroadcastUI.hover_focus = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	CaptureKit.restore([HOWTO])
	var f := FileAccess.open("%s/flow_%s%s.json" % [out, part, tag], FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"part": part, "checks": checks, "fails": fails, "notes": notes}, " "))
		f.close()
	print("CRITIQUE FLOW %s %s %d checks, %d failed" % [part, "PASSED" if fails.is_empty() and code == 0 else "FAILED", checks, fails.size()])
	quit(code if fails.is_empty() else maxi(code, 1))


func _frames(k: int) -> void:
	await CaptureKit.frames(self, k)


func _secs(s: float) -> void:
	await CaptureKit.secs(self, s)


func _until(cond: Callable, limit: float) -> float:
	return await CaptureKit.until(self, cond, limit)


func _run() -> void:
	await _frames(4)
	match part:
		"menu":
			await _menu_flows()
		"ring":
			await _ring_flows()
		"mouse":
			await _mouse_flows()
		"hover":
			await _hover_flow()
	_end(0)


# ---------------------------------------------------------------- helpers
func _key(target: Viewport, code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		target.push_input(ev)
		await process_frame
	await process_frame


func _click(target: Viewport, at: Vector2, double := false) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.double_click = double and pressed
		ev.position = at
		ev.global_position = at
		target.push_input(ev, true)
		await process_frame
	await process_frame


func _focus(target: Viewport) -> String:
	var f := target.gui_get_focus_owner()
	return String(f.name) if f != null else ""


func _fresh_menu() -> bool:
	if vp != null:
		vp.queue_free()
		await process_frame
	vp = SubViewport.new()
	vp.size = px
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	vp.add_child(scene)
	await _frames(10)
	m = scene as MainMenu
	return m != null


func _wipe_look() -> void:
	for lp: String in [AppearanceStore.current_path(), AppearanceStore.offered_path()]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))


func _cards_ready() -> bool:
	if m == null or m._element_rows.is_empty():
		return false
	for el: String in m._element_rows:
		var b := m._element_rows[el] as Control
		if b == null or b.find_child("CardView", true, false) == null:
			return false
	return true


func _text_of(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	if n is Button:
		return (n as Button).text
	return ""


# ---------------------------------------------------------------- the menu's flows
func _menu_flows() -> void:
	MainMenu.offer_check_run = false
	# ---- back: the first press offers the creator; Back counts as offered
	_wipe_look()
	MainMenu._look_offered = false
	stubs.clear()
	ok(await _fresh_menu(), "back: the main menu scene did not build")
	await _until(func() -> bool: return m._fighter.modulate.a >= 0.99, 20.0)
	ok(not AppearanceStore.was_offered(), "back: offered flag already set before the first press")
	m._open_match()
	await _frames(3)
	ok(stubs.size() == 1, "back: the first press of Tidebreak offered the creator (stubs %d)" % stubs.size())
	(stubs[0] as StubCreator).closed.emit(false)
	await _frames(4)
	ok(AppearanceStore.was_offered(), "back: Back marked the offer as made")
	ok(not FileAccess.file_exists(AppearanceStore.current_path()), "back: Back kept a look")
	ok(m._panel_scroll.visible and not m._element_rows.is_empty(), "back: the match setup opened at once after Back")
	ok(m.find_child("ElementStep", true, false) == null, "back: the element step came up after Back")
	await _until(func() -> bool: return _cards_ready(), 25.0)
	m._close_panel()
	await _frames(3)
	m._open_match()
	await _frames(3)
	ok(stubs.size() == 1, "back: the second press offered the creator again (stubs %d)" % stubs.size())
	# a new run of the game: the static is false again, the flag file says it was offered
	MainMenu._look_offered = false
	ok(await _fresh_menu(), "back: second menu did not build")
	m._open_match()
	await _frames(3)
	ok(stubs.size() == 1, "back: a new run offered the creator again (stubs %d)" % stubs.size())
	# ---- element: Accept -> the step -> the pick -> the lobby
	_wipe_look()
	MainMenu._look_offered = false
	stubs.clear()
	ok(await _fresh_menu(), "element: the main menu scene did not build")
	await _until(func() -> bool: return m._fighter.modulate.a >= 0.99, 20.0)
	m._open_match()
	await _frames(3)
	ok(stubs.size() == 1, "element: the creator was not offered")
	var look := AppearanceStore.default_look()
	look["name"] = "Kestrel"
	var saved := AppearanceStore.save_current(AppearanceStore.validate(look))
	ok(saved, "element: the stand-in's look was not saved")
	(stubs[0] as StubCreator).closed.emit(true)
	await _frames(4)
	var t := await _until(func() -> bool: return m.find_child("ElementStep", true, false) != null and _cards_ready(), 40.0)
	ok(t < INF, "element: the element step (with its four cards) did not come up after Accept")
	ok(AppearanceStore.element() == "", "element: an element was chosen before the pick")
	var title := m.find_child("StepTitle", true, false) as Label
	ok(title != null and title.text.to_lower().contains("element"), "element: the step has no title")
	var who := m.find_child("FighterName", true, false) as Label
	ok(who != null and who.text.to_lower() == "kestrel", "element: the step's plate does not name the character (%s)" % (who.text if who != null else "-"))
	await _secs(0.6)
	await _key(vp, KEY_2)
	ok(MatchSetup.element == "water", "element: key 2 did not pick water (%s)" % MatchSetup.element)
	var go := m.find_child("Choose", true, false) as Button
	ok(go != null and _text_of(go.find_child("Text", true, false)).to_lower().contains("water"), "element: the button does not say water after key 2 (%s)" % (_text_of(go.find_child("Text", true, false)) if go != null else "-"))
	await _key(vp, KEY_RIGHT)
	ok(MatchSetup.element == "fire", "element: Right from water did not pick fire (%s)" % MatchSetup.element)
	await _key(vp, KEY_LEFT)
	ok(MatchSetup.element == "water", "element: Left did not come back to water (%s)" % MatchSetup.element)
	ok(AppearanceStore.element() == "", "element: moving the pick kept an element")
	# a single click on a card only picks, a double click confirms
	var fire_card := m._element_rows["fire"] as Control
	var centre := fire_card.get_global_transform_with_canvas() * (fire_card.size * 0.5)
	await _click(vp, centre)
	ok(MatchSetup.element == "fire", "element: a single click did not pick fire (%s)" % MatchSetup.element)
	ok(AppearanceStore.element() == "", "element: a single click kept the element (the press was not suppressed)")
	ok(m.find_child("ElementStep", true, false) != null, "element: a single click left the step")
	await _key(vp, KEY_2)
	await _key(vp, KEY_ENTER)
	await _frames(4)
	ok(AppearanceStore.element() == "water", "element: Enter did not keep water (%s)" % AppearanceStore.element())
	ok(MatchSetup.element == "water", "element: the match element is not water after the step")
	ok(m.find_child("ElementStep", true, false) == null, "element: the step stayed after Enter")
	await _until(func() -> bool: return _cards_ready(), 25.0)
	ok(m._panel_scroll.visible and not m._element_rows.is_empty(), "element: the match setup did not follow the step")
	await _frames(2)
	notes["setup_focus_after_step"] = _focus(vp)
	await _key(vp, KEY_ESCAPE)
	await _frames(4)
	ok(not m._panel_scroll.visible, "element: Esc did not close the setup")
	ok(m._lobby_el == "water", "element: the lobby shows %s, not water" % m._lobby_el)
	var which := m.find_child("Which", true, false) as Label
	ok(which != null and which.text.to_lower().contains("water"), "element: the lower third's tag says %s" % (which.text if which != null else "-"))
	var fn := m.find_child("FighterName", true, false) as Label
	ok(fn != null and fn.text.to_lower() == "kestrel", "element: the lower third names %s, not Kestrel" % (fn.text if fn != null else "-"))
	ok(m._backdrop.texture != null and m._backdrop.texture.resource_path.ends_with("lobby_water.jpg"), "element: the lobby's plate is %s" % (m._backdrop.texture.resource_path if m._backdrop.texture != null else "none"))
	var bug := m.find_child("BugLine", true, false) as Label
	notes["bug_line"] = bug.text if bug != null else ""
	# a new run: the character keeps water and the name, and nothing is asked again
	MainMenu._look_offered = false
	stubs.clear()
	MatchSetup.element = "earth"                 # (the kept setup of a run before: the character's element wins)
	MatchSetup.save()
	ok(await _fresh_menu(), "element: the new run's menu did not build")
	ok(MatchSetup.element == "water", "element: a new run starts on %s, not the character's water" % MatchSetup.element)
	ok(m._lobby_el == "water", "element: a new run's lobby shows %s" % m._lobby_el)
	var fn2 := m.find_child("FighterName", true, false) as Label
	ok(fn2 != null and fn2.text.to_lower() == "kestrel", "element: a new run's lower third names %s" % (fn2.text if fn2 != null else "-"))
	m._open_match()
	await _frames(3)
	ok(stubs.is_empty(), "element: a new run offered the creator again")
	ok(m.find_child("ElementStep", true, false) == null, "element: a new run asked for the element again")
	m._close_panel()
	await _frames(3)
	# Your look from the lobby with an element already chosen: no step
	var yl := m._items.find_child("YourLook", true, false) as Button
	ok(yl != null, "element: no Your look row")
	if yl != null:
		yl.grab_focus()
		await _frames(2)
		await _key(vp, KEY_ENTER)
		await _frames(3)
		ok(stubs.size() == 1, "element: Your look did not open the creator stand-in (%d)" % stubs.size())
		if stubs.size() == 1:
			(stubs[0] as StubCreator).closed.emit(true)
			await _frames(6)
			ok(m.find_child("ElementStep", true, false) == null, "element: Your look asked for the element again")
			await _secs(0.5)
			ok(_focus(vp) == "YourLook", "element: the focus after Your look is %s, not the row" % _focus(vp))
	# ---- class: the window opens and closes, the focus comes back
	ok(await _fresh_menu(), "class: menu did not build")
	await _until(func() -> bool: return m._fighter.modulate.a >= 0.99, 20.0)
	var row := m._items.find_child("ClassTalents", true, false) as Button
	ok(row != null, "class: no Class & talents row")
	if row != null:
		row.grab_focus()
		await _frames(2)
		await _key(vp, KEY_ENTER)
		await _secs(1.2)
		var ws := m.find_children("*", "AdvancementWindow", false, false)
		ok(not ws.is_empty(), "class: Enter on the row did not open the window")
		ok(not m._menu_layout.visible, "class: the lobby shows through the window")
		await _key(vp, KEY_ESCAPE)
		await _secs(0.8)
		ws = m.find_children("*", "AdvancementWindow", false, false)
		ok(ws.is_empty() or not (ws[0] as Control).visible, "class: Esc did not close the window")
		ok(m._menu_layout.visible, "class: the lobby did not come back after the window")
		ok(_focus(vp) == "ClassTalents", "class: the focus is %s, not the row" % _focus(vp))
		# the setup's small link
		m._open_match()
		await _until(func() -> bool: return _cards_ready(), 25.0)
		await _frames(4)                        # (the setup puts the focus on Begin one idle frame after it opens)
		ok(_focus(vp) == "Begin", "class: the setup opened with the focus on %s, not Begin" % _focus(vp))
		var link := m._panel.find_child("ClassLink", true, false) as Button
		ok(link != null, "class: no Class & talents link in the setup")
		if link != null:
			var f0 := _focus(vp)
			# by keys: Up from Begin to Controls, up through the rows to the first chip, Up again to the link
			var path: Array = []
			for i in 9:
				await _key(vp, KEY_UP)
				path.append(_focus(vp))
			notes["up_from_begin"] = path
			ok(path.back() == "ClassLink", "class: Up from Begin never reached the link (%s)" % [path])
			link.grab_focus()
			notes["link_focus_now"] = _focus(vp)
			await _frames(2)
			notes["link_focus_2f"] = _focus(vp)
			notes["link_state"] = [link.is_visible_in_tree(), link.focus_mode, link.disabled, link.get_global_rect(), f0]
			ok(_focus(vp) == "ClassLink", "class: the setup's link cannot take the focus (%s)" % _focus(vp))
			if _focus(vp) == "ClassLink":
				await _key(vp, KEY_ENTER)
			else:
				link.pressed.emit()
			await _secs(1.2)
			ws = m.find_children("*", "AdvancementWindow", false, false)
			ok(not ws.is_empty(), "class: Enter on the setup's link did not open the window")
			await _key(vp, KEY_ESCAPE)
			await _secs(0.8)
			ok(_focus(vp) == "ClassLink", "class: the focus after the window over the setup is %s, not the link" % _focus(vp))
			ok(m._panel_scroll.visible, "class: the setup closed with the window")
		m._close_panel()
		await _frames(3)
	# ---- keys: the lobby's rows by key
	var seen := {}
	var order: Array = []
	m._first_focus()
	await _frames(3)
	order.append(_focus(vp))
	for i in 9:
		await _key(vp, KEY_DOWN)
		order.append(_focus(vp))
	notes["down_order"] = order
	for n: String in order:
		seen[n] = true
	for need in ["Sport", "StartHere", "QuickMatch", "Practice", "ClassTalents", "YourLook"]:
		ok(seen.has(need), "keys: Down never reached %s (%s)" % [need, order])
	var util_order: Array = []
	for i in 4:
		await _key(vp, KEY_RIGHT)
		util_order.append(_focus(vp))
	notes["right_order"] = util_order
	for n: String in util_order:
		seen[n] = true
	ok(seen.size() >= 9, "keys: only %d of the 9 rows were reached (%s)" % [seen.size(), seen.keys()])
	await _key(vp, KEY_UP)
	notes["up_from_util"] = _focus(vp)
	ok(_focus(vp) == "YourLook", "keys: Up from the small row went to %s, not Your look" % _focus(vp))
	for i in 12:
		await _key(vp, KEY_UP)
	ok(_focus(vp) == "Sport", "keys: Up to the top ended on %s, not the first row" % _focus(vp))
	await _key(vp, KEY_LEFT)
	ok(_focus(vp) == "Sport", "keys: Left on a row moved the focus to %s" % _focus(vp))
	await _key(vp, KEY_ENTER)
	await _until(func() -> bool: return _cards_ready(), 25.0)
	ok(m._panel_scroll.visible, "keys: Enter on the first row did not open the setup")
	notes["setup_focus"] = _focus(vp)
	# the setup by keys: Left/Right along a chip row, Down to the next row, Up back, to Begin
	var visited: Array = []
	for i in 14:
		await _key(vp, KEY_DOWN)
		visited.append(_focus(vp))
	notes["setup_down"] = visited
	ok(visited.has("Begin"), "keys: Down in the setup never reached Begin (%s)" % [visited])
	await _key(vp, KEY_ESCAPE)
	await _frames(4)
	ok(not m._panel_scroll.visible, "keys: Esc did not close the setup")
	ok(_focus(vp) == "Sport", "keys: Esc from the setup put the focus on %s, not the row that opened it" % _focus(vp))
	MainMenu._look_offered = true
	_wipe_look()


# ---------------------------------------------------------------- the menu by mouse (real button events at the controls' centres)
func _centre(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)       # (through the layout's scale: a small window draws the design smaller)


func _hover(target: Viewport, at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.relative = Vector2(3, 3)
	target.push_input(ev, true)
	await process_frame
	await process_frame


func _mouse_flows() -> void:
	MainMenu._look_offered = true
	MainMenu.offer_check_run = false
	BroadcastUI.hover_focus = true               # (the pointer over a row chooses it: this part is about that)
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "normal"
	MatchSetup.save()
	ok(await _fresh_menu(), "mouse: the main menu scene did not build")
	await _until(func() -> bool: return m._fighter.modulate.a >= 0.99, 20.0)
	await _secs(0.5)
	notes["size"] = [vp.size.x, vp.size.y]
	notes["layout_scale"] = m._menu_layout.scale.x
	# hover chooses a row, a click opens it
	var pr := m._items.find_child("Practice", true, false) as Control
	await _hover(vp, _centre(pr) + Vector2(-20, 0))
	await _hover(vp, _centre(pr))
	notes["hover_in_subviewport_focus"] = _focus(vp)      # (a SubViewport is not fed pointer motion by push_input: the hover part tests it in the window)
	await _click(vp, _centre(pr))
	await _frames(4)
	ok(m._panel_scroll.visible, "mouse: a click on Practice did not open its screen")
	await _key(vp, KEY_ESCAPE)
	await _frames(3)
	ok(not m._panel_scroll.visible, "mouse: Esc did not close the Practice screen")
	# Settings in the small row
	var st := m._util.get_child(0) as Control
	await _click(vp, _centre(st))
	await _frames(4)
	ok(m._panel_scroll.visible, "mouse: a click on Settings did not open it")
	var sliders := m._panel.find_children("*", "HSlider", true, false)
	ok(sliders.size() >= 4, "mouse: Settings shows %d sliders" % sliders.size())
	await _key(vp, KEY_ESCAPE)
	await _frames(3)
	# the match setup: the first row, a card, a chip, Begin
	var sp := m._items.find_child("Sport", true, false) as Control
	await _click(vp, _centre(sp))
	await _until(func() -> bool: return _cards_ready(), 25.0)
	await _frames(4)
	ok(m._panel_scroll.visible and not m._element_rows.is_empty(), "mouse: a click on the first row did not open the setup")
	var water := m._element_rows["water"] as Control
	await _click(vp, _centre(water))
	await _frames(3)
	ok(MatchSetup.element == "water", "mouse: a click on the Water card chose %s" % MatchSetup.element)
	var hard := m._panel.find_child("Difficulty", true, false) as BroadcastUI.Segments
	await _click(vp, _centre(hard.chip(2)))
	await _frames(3)
	ok(MatchSetup.difficulty == "hard", "mouse: a click on the Hard chip chose %s" % MatchSetup.difficulty)
	var foe_chip := m._panel.find_child("Opponent_air", true, false) as Control
	await _click(vp, _centre(foe_chip))
	await _frames(3)
	ok(MatchSetup.foe() == "air", "mouse: a click on the Air opponent chip chose %s" % MatchSetup.foe())
	var zones := m._panel.find_child("Rules", true, false) as BroadcastUI.Segments
	await _click(vp, _centre(zones.chip(1)))
	await _frames(3)
	ok(MatchSetup.rule_set() == "classic", "mouse: a click on Zones chose %s" % MatchSetup.rule_set())
	await _click(vp, _centre(zones.chip(0)))
	await _frames(3)
	var link := m._panel.find_child("ClassLink", true, false) as Control
	await _click(vp, _centre(link))
	await _secs(1.2)
	ok(not m.find_children("*", "AdvancementWindow", false, false).is_empty(), "mouse: a click on the Class & talents link did not open the window")
	await _key(vp, KEY_ESCAPE)
	await _secs(0.8)
	var begin := m._panel.find_child("Begin", true, false) as Control
	var bc := _centre(begin)
	notes["begin_at"] = [bc.x, bc.y, vp.size.x, vp.size.y]
	await _click(vp, bc)
	await _frames(4)
	ok(notes.has("launched"), "mouse: a click on Begin did not start the match")
	notes["launched_to"] = notes.get("launched", "")
	ok(MatchSetup.element == "water" and MatchSetup.difficulty == "hard", "mouse: the match starts with %s / %s" % [MatchSetup.element, MatchSetup.difficulty])
	MatchSetup.difficulty = "normal"
	MatchSetup.save()


## The pointer over a row chooses it, in the window itself (the root viewport, through the Input singleton as a real pointer comes).
func _hover_flow() -> void:
	MainMenu._look_offered = true
	MainMenu.offer_check_run = false
	BroadcastUI.hover_focus = true
	MatchSetup.element = "fire"
	MatchSetup.save()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(10)
	m = current_scene as MainMenu
	ok(m != null, "hover: the menu scene did not load")
	if m == null:
		return
	await _until(func() -> bool: return m._fighter.modulate.a >= 0.99, 20.0)
	await _secs(0.5)
	var seen: Array = []
	for nm in ["Practice", "QuickMatch", "YourLook", "ClassTalents"]:
		var row := m._items.find_child(nm, true, false) as Control
		var c := _centre(row)
		for at in [c + Vector2(-30, 0), c + Vector2(-10, 0), c]:
			var ev := InputEventMouseMotion.new()
			ev.position = at
			ev.global_position = at
			ev.relative = Vector2(10, 0)
			Input.parse_input_event(ev)
			await process_frame
			await process_frame
		seen.append(_focus(root))
		ok(_focus(root) == nm, "hover: the pointer over %s put the focus on %s" % [nm, _focus(root)])
	notes["hover_focus_seq"] = seen


# ---------------------------------------------------------------- the ring's Esc menu and the board
func _into_ring() -> bool:
	var t := await _until(func() -> bool: return current_scene is RingLevel and RingMode.find(self) != null, 60.0)
	if t == INF:
		return false
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	player = lvl.player
	var t2 := await _until(func() -> bool: return not LoadingScreen.covering() and player.arena_element != "", 30.0)
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return t2 < INF


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func _inside(c: Control, what: String) -> void:
	var win := Rect2(Vector2.ZERO, Vector2(root.size))
	var r := c.get_global_rect()
	ok(win.encloses(r.grow(-0.5)), "%s: %s at %s is outside the window %s" % [what, c.name, r, win])


func _ring_flows() -> void:
	MainMenu._look_offered = true
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "normal"
	MatchSetup.rules_choice = "stock"
	MatchSetup.games_n = 3
	MatchSetup.light = "noon"
	MatchSetup.save()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(10)
	m = current_scene as MainMenu
	ok(m != null, "ring: the menu scene did not load")
	if m == null:
		return
	await _secs(0.5)
	m._open_match()
	await _frames(3)
	MatchSetup.games_n = 3
	MatchSetup.quick = true
	RingReplay.force = "off"
	(m._panel.find_child("Begin", true, false) as Button).pressed.emit()
	MatchSetup.quick = true
	MatchSetup.games_n = 3
	await _secs(2.0)                         # (the loading screen over the menu: a picture of it)
	await CaptureKit.drawn(self)
	root.get_texture().get_image().save_png("%s/loading%s.png" % [out, tag])
	ok(await _into_ring(), "ring: the match did not start")
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 10.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 4.0)
	await _secs(1.5)
	var menu := mode.menu as RingMenu
	ok(menu != null, "ring: no Esc menu")
	if menu == null:
		return
	# Esc opens it (a real key through the window), the HUD is put away, the game paused
	await _key(root, KEY_ESCAPE)
	await _frames(3)
	ok(menu.is_open(), "ring: Esc did not open the menu")
	ok(paused, "ring: the match is not paused under the menu")
	var hud_layers: Array = []
	for n in root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl != menu and cl.layer < menu.layer and cl.visible:
			hud_layers.append(String(cl.name))
	ok(hud_layers.is_empty(), "ring: layers still shown under the menu: %s" % [hud_layers])
	var rows: Array = []
	var seen := {}
	notes["window"] = [root.size.x, root.size.y]
	for i in 12:
		var f := root.gui_get_focus_owner()
		if f != null:
			seen[String(f.name)] = true
			if rows.is_empty() or rows.back() != String(f.name):
				rows.append(String(f.name))
			_inside(f, "ring rows")
		await _key(root, KEY_DOWN)
	notes["esc_rows"] = rows
	var items := menu._items.get_children()
	var shown := 0
	for r in items:
		if r is Control and (r as Control).visible:
			shown += 1
			ok(seen.has(String(r.name)), "ring: row %s was not reached by Down" % r.name)
	ok(shown >= 8, "ring: only %d rows shown" % shown)
	# the panels
	for pair: Array in [["MatchSetup", "Element"], ["Options", "AimHelp"]]:
		var row := menu._items.find_child(String(pair[0]), true, false) as Button
		ok(row != null, "ring: no %s row" % pair[0])
		if row == null:
			continue
		row.grab_focus()
		await _frames(2)
		await _key(root, KEY_ENTER)
		await _frames(3)
		var panel_rows: Array = []
		var first := root.gui_get_focus_owner()
		ok(first != null and String(first.name) == pair[1], "ring: Enter on %s put the focus on %s, not %s" % [pair[0], _focus(root), pair[1]])
		for i in 9:
			var f2 := root.gui_get_focus_owner()
			if f2 != null:
				if panel_rows.is_empty() or panel_rows.back() != String(f2.name):
					panel_rows.append(String(f2.name))
				_inside(f2, "ring %s" % pair[0])
			await _key(root, KEY_DOWN)
		notes["panel_" + String(pair[0])] = panel_rows
		ok(panel_rows.size() >= 5, "ring: %s panel reached only %s" % [pair[0], panel_rows])
		# Left/Right changes a value of the first row
		var opt := menu.find_child(String(pair[1]), true, false) as BroadcastUI.OptionRow
		if opt != null:
			opt.grab_focus()
			await _frames(2)
			var before := _row_words(opt)
			await _key(root, KEY_RIGHT)
			var after := _row_words(opt)
			if after == before:                  # (the last value: Right stops there, Left steps back)
				await _key(root, KEY_LEFT)
				after = _row_words(opt)
			notes["change_" + String(pair[1])] = [before, after]
			ok(before != after, "ring: Right and Left on %s changed nothing (%s)" % [pair[1], before])
			await _key(root, KEY_LEFT if after != before else KEY_RIGHT)
		await _key(root, KEY_ESCAPE)
		await _frames(3)
		ok(menu.is_open(), "ring: Esc in the %s panel closed the whole menu" % pair[0])
		ok(_focus(root) == pair[0], "ring: Esc out of the %s panel put the focus on %s" % [pair[0], _focus(root)])
	# Esc closes the menu
	await _key(root, KEY_ESCAPE)
	await _frames(3)
	ok(not menu.is_open(), "ring: Esc did not close the menu")
	ok(not paused, "ring: the match stayed paused")
	var back_layers := 0
	for n in root.find_children("*", "CanvasLayer", true, false):
		if (n as CanvasLayer).visible:
			back_layers += 1
	ok(back_layers >= 2, "ring: the HUD layers did not come back (%d)" % back_layers)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _falls()


func _hud_under(over: CanvasLayer, what: String) -> void:
	var shown: Array = []
	for n in root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl != over and cl.layer < over.layer and cl.visible:
			shown.append(String(cl.name))
	ok(shown.is_empty(), "%s: layers still shown under it: %s" % [what, shown])


func _row_words(o: BroadcastUI.OptionRow) -> String:
	var words: Array = []
	for t in o.find_children("*", "Label", true, false):
		words.append((t as Label).text)
	return "|".join(PackedStringArray(words))


func _falls() -> void:
	if foe() == null:
		return
	foe().held = true
	mode.rules.ko.connect(func(b: Node3D, _by: Node, _p: float, _t: String, _l: int) -> void: kos.append(b))
	for i in 8:
		var w := await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null and not mode.rules.is_away(foe()), 20.0)
		if w == INF:
			if (mode.round_screen as RoundScreen).is_open():
				await _secs(0.4)
				mode.phase_t = 999.0
			w = await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null and not mode.rules.is_away(foe()), 20.0)
			if w == INF:
				break
		if foe() != null:
			foe().held = true
		await _secs(4.0)
		await _launch_foe()
		var n0 := kos.size()
		await _until(func() -> bool: return kos.size() > n0, 8.0)
		var rp := RingReplay.find(self)
		while rp != null and rp.is_playing():
			await process_frame
		if mode.phase == "OVER" or mode.phase == "DONE":
			var good := await _until(func() -> bool: return (mode.round_screen as RoundScreen).is_open() or (mode.match_screen as MatchScreen).is_open(), 12.0)
			if good < INF and (mode.round_screen as RoundScreen).is_open():
				await _secs(0.5)
				mode.phase_t = 999.0
	var done := await _until(func() -> bool: return mode.phase == "DONE" and (mode.match_screen as MatchScreen).is_open(), 25.0)
	ok(done < INF, "end: no match screen (phase %s)" % mode.phase)
	if done == INF:
		return
	await _secs(1.4)
	var ms := mode.match_screen as MatchScreen
	_hud_under(ms, "end")
	var b: Dictionary = ms.board()
	notes["board_head"] = b.get("head", "")
	notes["board_score"] = b.get("score", "")
	notes["board_lives"] = b.get("lives_line", "")
	notes["match_score"] = [mode.score.x, mode.score.y]
	var texts := CaptureKit.text_dump(root, Rect2(Vector2.ZERO, Vector2(root.size)))
	var on_screen: Array = []
	for t: Dictionary in texts:
		on_screen.append(String(t.text))
	var digits := "%d|%d" % [mode.score.x, mode.score.y]
	var score_cells: Array = []
	for t: Dictionary in texts:
		var s := String(t.text).strip_edges()
		if s.is_valid_int() and float(t.h) > 60.0:
			score_cells.append(int(s))
	notes["big_digits_on_screen"] = score_cells
	ok(score_cells.size() >= 2 and score_cells.has(mode.score.x) and score_cells.has(mode.score.y), "end: the big score digits %s are not the match's %s" % [score_cells, digits])
	var win_word := String(b.get("head", "")).to_lower()
	var i_won := mode.score.x > mode.score.y
	ok((i_won and win_word.contains("victory")) or (not i_won and win_word.contains("defeat")), "end: the headline '%s' does not match the score %s" % [b.get("head", ""), digits])
	var games: Array = b.get("games", [])
	ok(games.size() == mode.score.x + mode.score.y, "end: %d games listed for a score of %s" % [games.size(), digits])
	var falls_total := 0
	for nrow: Dictionary in b.get("numbers", []):
		if String(nrow.get("label", "")).to_lower().contains("falls"):
			falls_total = int(nrow.get("a", 0))
	notes["falls_dealt_you"] = falls_total
	ok(falls_total <= kos.size(), "end: falls dealt %d against %d seen" % [falls_total, kos.size()])
	notes["kos_seen"] = kos.size()
	var bad_off := 0
	for t: Dictionary in texts:
		if bool(t.offscreen):
			bad_off += 1
	ok(bad_off == 0, "end: %d texts are partly outside the window" % bad_off)
	# the four buttons reachable by key
	var board_focus: Array = []
	for i in 6:
		board_focus.append(_focus(root))
		await _key(root, KEY_RIGHT)
	notes["board_focus_right"] = board_focus
	ok(board_focus.size() >= 4 and board_focus.filter(func(x: String) -> bool: return x != "").size() >= 4, "end: the board's buttons are not reachable by Right (%s)" % [board_focus])


func _launch_foe() -> void:
	var f := foe()
	if f == null:
		return
	var kn := BendKnock.of(f)
	kn.reset()
	f.velocity = Vector3.ZERO
	var ring := lvl.ring
	var side := RingArena.side_sign(1 - mode.player_end) if mode.player_end in [0, 1] else 1.0
	f.global_position = ring.to_global(Vector3(side * (ring.half_l() - 2.5), ring.top() + 0.05, 0.0))
	player.global_position = ring.to_global(Vector3(side * (ring.half_l() - 7.0), ring.top() + 0.05, 1.0))
	for i in 10:
		await physics_frame
	mode.rules.reset_pct(f, 90.0 + float(randi() % 50))
	BendStatus.hurt(f, 1.0, f.global_position + Vector3.UP, Vector3.FORWARD, player, -1.0, {"tag": "stone_form/spike", "from": player.global_position})
	var v := ring.global_basis * Vector3(16.0 * side, 7.0, 0.0)
	mode.rules.launched.emit(f, v, 0.8, player, "stone_form/spike")
	kn.knock(Vector3.ZERO, player, {"_launch": {"v": v, "hitstun_s": 0.8, "tumble": true}})
