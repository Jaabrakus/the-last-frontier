extends SceneTree
## The character's element (the owner, 2026-10-10: "we just need the char made and then the element that char chooses"), headless;
## the character creator itself is never opened (MainMenu.creator_hook gives the menu a stand-in with its closed signal):
##
##   Godot --headless --path . -s tests/customizer/test_appearance_element.gd
##
##   store      AppearanceStore's `element` ("" = not chosen yet; earth, water, fire, air): validated (a word that is none, a number
##              or a dictionary reads as none), round-tripped by save_file and load_file, an old save without it loads as "", and
##              element(), file_element() and set_element() read and write it on the look's file alone (the other keys kept)
##   carry      a look the creator builds anew (another people, a body type) has no element: PlayerAppearance.carry_element keeps
##              the character's own; PlayerAppearance.element_due(accepted) is the post-Accept hook (true only for an Accept with
##              no element chosen yet)
##   first run  the first press of Tidebreak offers the creator; an Accept ends on the "Choose your element" step (the four
##              cards, the focus on the one in force), the number keys and the arrows pick, Enter keeps it in the character
##              (AppearanceStore, MatchSetup, the kept setup) and the match setup follows with it chosen; Back keeps no look, counts
##              as offered and opens the match setup at once, with no step
##   your look  the same Accept from Your look: the step, Esc for later (nothing kept, the setup's element as it was), once more
##              kept with a click and a double click; an element already chosen is not asked again, and a look the creator saved
##              without one keeps the chosen one
##   defaults   the character's element is the setup's default (MatchSetup.load over the kept setup, Quick match), the lobby's
##              fighter card and the advancement window's default; a match's own choice is left as that match's
## Ends with "APPEARANCE ELEMENT TEST PASSED" or "... FAILED" (exit 0 only on a pass; a watchdog quits with 2). The test run's own
## look file and its offered flag are put back as they were.

const NAME := "APPEARANCE ELEMENT TEST"
const LIMIT_S := 150.0
const OWN_CFG := "user://test_element_settings.cfg"
const OWN_FILE := "user://appearance_test/element_roundtrip.json"
const OLD_FILE := "user://appearance_test/element_old_save.json"

## The character creator's stand-in: only its closed(accepted) signal.
class StubCreator extends Node:
	signal closed(accepted: bool)
	var first := false

var checks := 0
var fails: Array[String] = []
var stubs: Array = []
var _stash_of := {}


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		_restore()
		quit(2))
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("  ok   ", what)
	else:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


## A UI action as the keys or the pad send it (pressed, and released for a button's press), through the window.
func _action(a: StringName, release := false) -> void:
	for down in ([true, false] if release else [true]):
		var ev := InputEventAction.new()
		ev.action = a
		ev.pressed = down
		root.push_input(ev)
	await frames(2)


func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
		root.push_input(ev)
	await frames(2)


# -------------------------------------------------------------------------------------------------- the test run's own files
## The look's file and its offered flag put aside (the test run's own: AppearanceStore.TEST_CURRENT), gone for the test.
func _stash() -> void:
	for p: String in [AppearanceStore.current_path(), AppearanceStore.offered_path(), OWN_FILE, OLD_FILE]:
		_stash_of[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG


func _restore() -> void:
	for p: String in _stash_of:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		if _stash_of[p] != null:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f != null:
				f.store_buffer(_stash_of[p])
				f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	MainMenu.creator_hook = Callable()
	MainMenu.offer_check_run = true
	MainMenu._look_offered = false


## No look file, no offered flag and no kept setup: a new player.
func _fresh_player() -> void:
	for p: String in [AppearanceStore.current_path(), AppearanceStore.offered_path(), OWN_CFG]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _look(el := "") -> Dictionary:
	var lk := AppearanceStore.default_look()
	lk["name"] = "Rowan"
	if el != "":
		lk["element"] = el
	return AppearanceStore.validate(lk)


func _run() -> void:
	_stash()
	_store()
	_carry()
	await _first_run()
	await _your_look()
	await _defaults()
	_restore()
	_end()


# -------------------------------------------------------------------------------------------------- store
func _store() -> void:
	for el: String in Bending.ELEMENTS:
		check(AppearanceStore.clean_element(el) == el, "%s is an element" % el)
	for bad: Variant in ["", "plasma", "Water", " fire", 3, null, {"a": 1}, ["fire"], 1.5]:
		check(AppearanceStore.clean_element(bad) == "", "%s is no element" % [bad])
	var lk := AppearanceStore.default_look()
	check(AppearanceStore.validate(lk).get("element", "x") == "", "a look with no element reads as not chosen yet")
	for el: String in Bending.ELEMENTS:
		lk["element"] = el
		check(AppearanceStore.validate(lk).get("element") == el, "validate keeps %s" % el)
	for bad: Variant in ["plasma", "FIRE", 7, {"a": 1}, true]:
		lk["element"] = bad
		check(AppearanceStore.validate(lk).get("element") == "", "validate: %s is none" % [bad])
	# the file: written and read back, the other keys with it
	lk = _look("fire")
	check(AppearanceStore.save_file(OWN_FILE, lk), "a look with an element saved")
	var back := AppearanceStore.load_file(OWN_FILE)
	check(back.get("element") == "fire" and back.get("name") == "Rowan", "load_file round-trips the element and the name (%s)" % back.get("element"))
	check(AppearanceStore.file_element(OWN_FILE) == "fire", "file_element reads it from the file alone")
	# an old save: the same file format, no `element`
	var old := {"format": AppearanceStore.FORMAT, "version": 2, "saved": "2026-09-01T10:00:00", "look": {"sex": 1.0, "name": "Old"}}
	var f := FileAccess.open(OLD_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var ol := AppearanceStore.load_file(OLD_FILE)
	check(ol.get("element", "x") == "" and ol.get("name") == "Old", "an old save without the field loads as not chosen yet, its name kept")
	check(AppearanceStore.file_element(OLD_FILE) == "", "file_element: an old save has none")
	check(AppearanceStore.file_element("user://appearance_test/no_such_look.json") == "", "file_element: no file, none")
	f = FileAccess.open(OLD_FILE, FileAccess.WRITE)
	f.store_string("not json at all {")
	f.close()
	check(AppearanceStore.file_element(OLD_FILE) == "", "file_element: a broken file, none")
	f = FileAccess.open(OLD_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": "something-else", "look": {"element": "fire"}}))
	f.close()
	check(AppearanceStore.file_element(OLD_FILE) == "", "file_element: not an appearance file, none")
	# the test run's own look file: element(), set_element()
	_fresh_player()
	check(AppearanceStore.element() == "" and String(AppearanceStore.load_current().get("element", "")) == "", "no look saved: no element")
	check(not AppearanceStore.set_element("plasma") and not AppearanceStore.set_element("") and not FileAccess.file_exists(AppearanceStore.current_path()),
			"set_element: a word that is none writes nothing")
	check(AppearanceStore.save_current(_look()) and AppearanceStore.element() == "", "a saved look with no element: none")
	check(AppearanceStore.set_element("water") and AppearanceStore.element() == "water" and AppearanceStore.load_current().get("element") == "water",
			"set_element(water): kept in the look")
	var cur := AppearanceStore.load_current()
	cur["name"] = "Mira"
	AppearanceStore.save_current(cur)
	check(AppearanceStore.set_element("air") and AppearanceStore.element() == "air" and AppearanceStore.load_current().get("name") == "Mira",
			"set_element(air): the element changed, the name kept")
	_fresh_player()
	check(AppearanceStore.set_element("earth") and AppearanceStore.element() == "earth" and FileAccess.file_exists(AppearanceStore.current_path()),
			"set_element with no look saved: the default look with it")
	check(not AppearanceStore.was_offered(), "set_element does not mark the creator's offer")
	_fresh_player()


# -------------------------------------------------------------------------------------------------- carry and the hook
func _carry() -> void:
	var was := _look("fire")
	var anew := CreatorOptions.with_people(was.duplicate(true), CharacterPeoples.default_people())
	check(not anew.has("element"), "a look built anew by the creator carries no element (%s)" % anew.get("element", "none"))
	check(PlayerAppearance.carry_element(anew, was).get("element") == "fire", "carry_element: the character keeps its own")
	var other := anew.duplicate(true)
	other["element"] = "air"
	check(PlayerAppearance.carry_element(other, was).get("element") == "air", "carry_element: a look that names one is taken as it is")
	check(PlayerAppearance.carry_element(anew, _look()).get("element") == "", "carry_element: none before, none after")
	# the post-Accept hook: only an Accept with no element chosen yet
	_fresh_player()
	check(PlayerAppearance.element_due(true) and not PlayerAppearance.element_due(false), "element_due: Accept, no element: due; Back: not")
	AppearanceStore.save_current(_look("water"))
	check(not PlayerAppearance.element_due(true), "element_due: an element chosen is not asked again")
	_fresh_player()


# -------------------------------------------------------------------------------------------------- the menu
## The menu scene with the creator's stand-in in; the stubs made are kept in `stubs`.
func _menu(first_run := false) -> MainMenu:
	stubs.clear()
	MainMenu.creator_hook = func(first: bool) -> Object:
		var s := StubCreator.new()
		s.first = first
		stubs.append(s)
		return s
	MainMenu.offer_check_run = false
	MainMenu._look_offered = not first_run
	MatchSetup.element = "earth"
	MatchSetup.foes = ["air"]
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(6)
	return current_scene as MainMenu


func _step(m: MainMenu) -> Control:
	return m._panel.find_child("ElementStep", true, false) as Control


func _lit(m: MainMenu) -> Array:
	var out: Array = []
	for el: String in Bending.ELEMENTS:
		var b: Button = m._element_rows.get(el)
		if b != null and bool(b.get_meta(&"chosen", false)):
			out.append(el)
	return out


func _cta_text(m: MainMenu) -> String:
	var b := m._panel.find_child("Choose", true, false)
	var t := b.find_child("Text", true, false) as Label if b != null else null
	return t.text if t != null else ""


func _first_run() -> void:
	_fresh_player()
	var m := await _menu(true)
	check(m != null and PlayerAppearance.offer_creator(false) and not AppearanceStore.was_offered(), "a new player: the creator is to be offered")
	# the first press of Tidebreak: the creator (the stand-in), not the setup
	m._open_match()
	await frames(2)
	check(stubs.size() == 1 and (stubs[0] as StubCreator).first and m._panel.find_child("MatchCard", true, false) == null,
			"the first press of the sport: the creator first (offered with first=true), not the setup")
	# Accept: the look saved (as the creator does), then the step
	AppearanceStore.save_current(_look())
	(stubs[0] as StubCreator).closed.emit(true)
	await frames(4)
	var step := _step(m)
	check(step != null and AppearanceStore.was_offered(), "Accept: the Choose your element step, the offer counted")
	check(step != null and (step.find_child("StepTitle", true, false) as Label).text == "CHOOSE YOUR ELEMENT", "its heading says what it is")
	# (the owner's words: nothing of the shows or the other games on a screen a player meets)
	var words := " ".join((step.find_children("*", "Label", true, false) as Array).map(func(l: Node) -> String: return (l as Label).text)) if step != null else ""
	var hit := RegEx.create_from_string("(?i)bend|avatar|spellbreak|azeroth|warcraft|blizzard|\\bwow\\b|ascension|korra|airbender").search(words)
	check(words.length() > 100 and hit == null, "the step's words carry no show or third-party word (%s)" % (hit.get_string() if hit else "none"))
	check(step != null and not step.find_children("*", "Label", true, false).any(func(l: Node) -> bool: return (l as Label).get_theme_font_size("font_size") < BroadcastUI.MIN_PX),
			"and no type under the %d px floor" % BroadcastUI.MIN_PX)
	check(m._element_rows.size() == 4 and m._panel.find_child("MatchCard", true, false) == null, "the four cards, no match setup yet")
	check(AppearanceStore.element() == "", "nothing kept yet")
	check(_lit(m) == [MatchSetup.element] and _cta_text(m) == "Choose %s" % MatchSetup.label(MatchSetup.element),
			"the element in force is lit and the button names it (%s, '%s')" % [_lit(m), _cta_text(m)])
	var focus := root.gui_get_focus_owner()
	check(focus != null and focus == m._element_rows.get(MatchSetup.element), "the focus is on the card in force")
	check((step.find_child("FighterName", true, false) as Label).text.to_upper() == "ROWAN", "the step says whose fighter it is")
	# the pick: a number key, then the arrows
	await _key(KEY_3)
	check(MatchSetup.element == "fire" and _lit(m) == ["fire"] and _cta_text(m) == "Choose Fire", "key 3 picks Fire (%s, '%s')" % [_lit(m), _cta_text(m)])
	check(root.gui_get_focus_owner() == m._element_rows["fire"], "the focus goes with the pick")
	await _action(&"ui_left")
	check(MatchSetup.element == "water" and _lit(m) == ["water"], "Left moves the pick to Water (%s)" % MatchSetup.element)
	await _action(&"ui_right")
	await _action(&"ui_right")
	check(MatchSetup.element == "air" and _lit(m) == ["air"], "Right twice: Air")
	await _action(&"ui_right")
	check(MatchSetup.element == "air", "Right at the last card goes nowhere")
	await _action(&"ui_down")
	check(root.gui_get_focus_owner() == m._panel.find_child("Choose", true, false) and MatchSetup.element == "air", "Down: the button, the pick kept")
	await _action(&"ui_up")
	await _key(KEY_2)
	check(MatchSetup.element == "water" and AppearanceStore.element() == "", "key 2: Water picked, still nothing kept")
	# Enter keeps it
	await _action(&"ui_accept", true)
	check(AppearanceStore.element() == "water" and MatchSetup.element == "water", "Enter: Water kept in the character (%s)" % AppearanceStore.element())
	check(String(GameSettings.get_value("match", "element")) == "water", "and in the kept setup")
	check(AppearanceStore.load_current().get("name") == "Rowan", "the saved look is the character's (name kept)")
	check(_step(m) == null and m._panel.find_child("MatchCard", true, false) != null and _lit(m) == ["water"],
			"the match setup follows, Water chosen")
	check(MainMenu._look_offered and AppearanceStore.was_offered(), "the offer made once")
	# Back from the offer: counts as offered, the setup opens at once, no step
	_fresh_player()
	m = await _menu(true)
	m._open_match()
	await frames(2)
	check(stubs.size() == 1 and not AppearanceStore.was_offered(), "a new player again: the creator offered")
	(stubs[0] as StubCreator).closed.emit(false)
	await frames(4)
	check(AppearanceStore.was_offered() and not PlayerAppearance.offer_creator(false), "Back counts as offered (no second offer)")
	check(_step(m) == null and m._panel.find_child("MatchCard", true, false) != null, "Back: the match setup at once, no element step")
	check(AppearanceStore.element() == "" and not FileAccess.file_exists(AppearanceStore.current_path()), "Back keeps no look and no element")
	# the offer does not come back
	m._close_panel()
	m._look_offered = false
	m._open_match()
	await frames(2)
	check(stubs.size() == 1 and m._panel.find_child("MatchCard", true, false) != null, "the second press of the sport: the setup, no creator again")
	# Esc on the step after the first-run Accept: later, the setup follows, nothing kept
	_fresh_player()
	m = await _menu(true)
	m._open_match()
	await frames(2)
	AppearanceStore.save_current(_look())
	(stubs[0] as StubCreator).closed.emit(true)
	await frames(4)
	await _key(KEY_4)
	check(MatchSetup.element == "air", "the pick looked at")
	await _action(&"ui_cancel")
	check(_step(m) == null and m._panel.find_child("MatchCard", true, false) != null and AppearanceStore.element() == "", "Esc: later, the setup follows, nothing kept")
	check(MatchSetup.element == "earth", "Esc gives the setup's element back as it was (%s)" % MatchSetup.element)
	_fresh_player()


func _your_look() -> void:
	_fresh_player()
	AppearanceStore.save_current(_look())
	var m := await _menu()
	var row := m._items.find_child("YourLook", true, false) as Button
	check(row != null, "Your look is a row of the lobby")
	row.pressed.emit()
	await frames(2)
	check(stubs.size() == 1 and not (stubs[0] as StubCreator).first, "Your look: the creator (not the first-run offer)")
	AppearanceStore.save_current(_look())
	(stubs[0] as StubCreator).closed.emit(true)
	await frames(4)
	check(_step(m) != null and m._panel_scroll.visible, "Accept with no element chosen yet: the step")
	# Esc: later
	await _key(KEY_3)
	await _action(&"ui_cancel")
	check(_step(m) == null and not m._panel_scroll.visible and AppearanceStore.element() == "", "Esc: back to the lobby, nothing kept")
	check(MatchSetup.element == "earth", "the setup's element as it was (%s)" % MatchSetup.element)
	var back := root.gui_get_focus_owner()
	check(back != null and back.name == "YourLook", "the focus is on Your look again (%s)" % [back.name if back else "none"])
	# once more, kept with the mouse: a click picks, a double click keeps
	m._open_look()
	await frames(2)
	AppearanceStore.save_current(_look())
	(stubs[1] as StubCreator).closed.emit(true)
	await frames(4)
	var water := m._element_rows["water"] as Button
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	m._step_click(click, water, "water")
	await frames(1)
	check(MatchSetup.element == "water" and _step(m) != null and AppearanceStore.element() == "", "a click picks Water, nothing kept yet")
	click.double_click = true
	m._step_click(click, water, "water")
	await frames(3)
	check(AppearanceStore.element() == "water" and _step(m) == null and not m._panel_scroll.visible, "a double click keeps it, back to the lobby")
	var which := m._lobby.find_child("Which", true, false) as Label
	check(which != null and which.text.to_lower().begins_with("water"), "the lobby's fighter card is Water's ('%s')" % [which.text if which else ""])
	check(m._items.find_child("YourLook", true, false) == root.gui_get_focus_owner() or root.gui_get_focus_owner() == null
			or root.gui_get_focus_owner().name == "YourLook", "the focus back on Your look")
	# an element chosen: Accept goes straight back, no step
	m._open_look()
	await frames(2)
	(stubs[2] as StubCreator).closed.emit(true)
	await frames(4)
	check(_step(m) == null and not m._panel_scroll.visible, "an element chosen: Accept asks nothing more")
	# a look the creator saved without the element (another people): the chosen one is kept
	m._open_look()
	await frames(2)
	var anew := CreatorOptions.with_people(AppearanceStore.load_current(), CharacterPeoples.default_people())
	anew.erase("element")
	AppearanceStore.save_current(AppearanceStore.validate(anew))
	check(AppearanceStore.element() == "", "(the creator's new look carries none)")
	(stubs[3] as StubCreator).closed.emit(true)
	await frames(4)
	check(AppearanceStore.element() == "water" and _step(m) == null, "the character keeps Water through a new look, no step")
	# Back from Your look: nothing changes
	m._open_look()
	await frames(2)
	(stubs[4] as StubCreator).closed.emit(false)
	await frames(4)
	check(_step(m) == null and AppearanceStore.element() == "water", "Back from Your look: nothing asked")
	_fresh_player()


func _defaults() -> void:
	_fresh_player()
	GameSettings.path = OWN_CFG
	# the kept setup says Fire; no character element: Fire (as before)
	MatchSetup.element = "earth"
	MatchSetup.foes = ["air"]
	GameSettings.set_section("match", {"element": "fire", "foe": "air"})
	AppearanceStore.save_current(_look())
	MatchSetup.load()
	check(MatchSetup.element == "fire", "no character element: the kept setup's (%s)" % MatchSetup.element)
	# the character's element wins over the kept one
	AppearanceStore.set_element("water")
	MatchSetup.element = "earth"
	MatchSetup.load()
	check(MatchSetup.element == "water", "the character's element is the default (%s)" % MatchSetup.element)
	check(String(GameSettings.get_value("match", "element")) == "fire", "(the kept setup is not rewritten by it)")
	# Quick match
	MatchSetup.element = "earth"
	MatchSetup.quick_match()
	check(MatchSetup.element == "water", "Quick match plays the character's element (%s)" % MatchSetup.element)
	# a match's own choice: that match's, and the next read starts from the character's again
	MatchSetup.element = "air"
	MatchSetup.save()
	check(String(GameSettings.get_value("match", "element")) == "air" and AppearanceStore.element() == "water",
			"a match played as Air keeps Air as the last setup, the character stays Water")
	MatchSetup.element = "earth"
	MatchSetup.load()
	check(MatchSetup.element == "water", "the next read starts from the character again")
	# the user args of a run still win (tools, tests)
	MatchSetup.parse(PackedStringArray(["element=fire"]))
	check(MatchSetup.element == "fire", "element=fire of a run's args is taken as given")
	# the lobby: the fighter card and the rundown for the character's element; the advancement window's own default
	MatchSetup.element = "earth"
	var m := await _menu()
	check(MatchSetup.element == "water", "the menu starts from the character's element (%s)" % MatchSetup.element)
	var which := m._lobby.find_child("Which", true, false) as Label
	check(which != null and which.text.to_lower().begins_with("water"), "the lobby's fighter card: Water ('%s')" % [which.text if which else ""])
	var third := m._lobby.find_child("StyleLine", true, false) as Label
	check(third != null and third.text == MatchSetup.style("water"), "and its style line")
	check(AdvancementWindow._default_element() == "water", "the advancement window's default is the character's (%s)" % AdvancementWindow._default_element())
	_fresh_player()


func _end() -> void:
	for s in stubs:
		if is_instance_valid(s):
			(s as Node).free()
	if fails.is_empty():
		print("%s PASSED %d" % [NAME, checks])
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("%s FAILED %d/%d" % [NAME, fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
