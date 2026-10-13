extends SceneTree
## The main menu, the loading screen and the pause menu (scripts/ui/menu), headless:
##
##   Godot --headless --path . -s tests/ui/test_main_menu.gd
##
##   start     Tidebreak app title and arena splash; the existing desktop user-data directory remains stable
##   pictures  every game picture there (the menu's and the loading screens'), each with a title and a caption; a
##             round shows each before a repeat; the museum's paintings, each with its artist and story; no portraits
##   menu      the ring sport first (Tidebreak; the owner, 2026-10-04), Quick match (its line the last setup against a random
##             opponent), Practice, Your look,
##             Settings, Credits, Quit; legacy Open world is absent from the public menu. The sport's row opens its panel (the setup itself:
##             tests/ring/test_match_setup.gd); Your look opens the character creator over the menu
##   open world  the open world's rows in their own panel. No save: New game first, Load greyed ("no saves yet"),
##             Campaigns greyed ("coming"), Co-op open, the Museum and the duel test; a save: Continue first, its line
##             "Quick save  ·  <date>, <hour>  ·  just now", Load open and listing it; Esc from a screen opened there
##             comes back to the panel
##   museum    from the Open world panel: the paintings one at a time, Next and the arrows go on (round to the first),
##             Esc leaves (back to the panel)
##   co-op     its panel: the squad (a press steps it), Host a game, the host's address, Join (none pressed: no network)
##   new game  no background to pick (2026-10-01: the default newcomer); the story, start-with-nothing and spouse switches
##             (each press flips its line); Begin at once into the level through the loading screen, no save continued,
##             no background, the story Two Fires, and the creator's offer taken
##   credits   CREDITS.md in blocks, the CC-BY models (when the file is there; nothing when not: no line about a missing
##             file, the UI audit 2026-10-09); the copyright notice and the licence (NOTICE.txt, EULA.txt)
##   settings  a value written and read back (GameSettings.path pointed at a file of the test's own: never the player's)
##   element   the character's element is the lobby's (its fighter card, the setup's start); Class & talents opens the real
##             AdvancementWindow for it (over the menu, Esc closes it alone and the focus is back on the row), from the match
##             setup's small link too (the setup's own choices left as they were); its Your look tab asks the creator (a
##             stand-in: the real one is never opened here). The element step itself: tests/customizer/test_appearance_element.gd
##   pause     Esc's menu over the level: the game paused, closed again: running

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


## A UI action as the keys or the pad send it, through the window.
func _action(a: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = true
	root.push_input(ev)
	await frames(2)


func _run() -> void:
	check(String(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/main_menu.tscn", "the game starts at the menu")
	check(String(ProjectSettings.get_setting("application/config/name")) == "Tidebreak", "the application is named Tidebreak")
	check(String(ProjectSettings.get_setting("application/boot_splash/image")) == "res://assets/ui/tidebreak_splash.png"
			and ResourceLoader.exists("res://assets/ui/tidebreak_splash.png"), "the boot splash is Tidebreak's arena artwork")
	if OS.get_name() in ["macOS", "Windows", "Linux"]:
		var suffix := "/godot/app_userdata/Frontier" if OS.get_name() == "Linux" else "/Godot/app_userdata/Frontier"
		check(OS.get_user_data_dir().replace("\\", "/").ends_with(suffix),
				"renaming the application preserves the existing saves/settings directory (%s)" % OS.get_user_data_dir())
	# the game's pictures, and the museum's
	var all := MenuPaintings.all()
	check(all.size() == MenuPaintings.PICTURES.size() and all.size() >= 3,
			"every game picture is there (%d of %d)" % [all.size(), MenuPaintings.PICTURES.size()])
	check(all.all(func(e: Dictionary) -> bool: return String(e.path).begins_with(MenuPaintings.PICTURES_DIR) and not e.has("by")),
			"the menu and loading screens show the game's own pictures")
	check(all.all(func(e: Dictionary) -> bool: return String(e.path).begins_with("res://assets/ui/tidebreak/")),
			"the public rotation uses arena screenshots only")
	check(MenuPaintings.legacy().size() == MenuPaintings.LEGACY_PICTURES.size(), "legacy screenshots remain available outside the demo rotation")
	var mus := MenuPaintings.museum()
	check(mus.size() == MenuPaintings.LIST.size() and mus.size() >= 5, "every museum painting is there (%d of %d)" % [mus.size(), MenuPaintings.LIST.size()])
	check(not DirAccess.dir_exists_absolute("res://assets/ui/paintings/portraits") and mus.all(func(e: Dictionary) -> bool: return not e.has("whole")),
			"no portraits of the peoples")
	check(mus.all(func(e: Dictionary) -> bool: return String(e.get("by", "")) != "" and String(e.title) != "" and String(e.captions[0]).length() > 40),
			"each museum painting with its artist, title and story")
	var seen := {}
	for i in all.size():
		var e := MenuPaintings.next()
		seen[String(e.file)] = true
		check(String(e.title) != "" and String(e.caption).length() > 40, "%s: a title and a caption" % e.file)
	check(seen.size() == all.size(), "a round shows each before a repeat (%d)" % seen.size())
	# (money: the background picker and its purse are gone from New game, 2026-10-01, and _money with them)
	# credits
	var cr := MainMenu.credits()
	var heads := cr.map(func(b: Array) -> String: return String(b[0]))
	var text := " ".join(cr.map(func(b: Array) -> String: return " ".join(b[1])))
	if FileAccess.file_exists("res://CREDITS.md"):
		check(cr.size() >= 4, "the credits in blocks (%d)" % cr.size())
		check(text.contains("Poly by Google"), "the CC-BY models' credits are in it")
		check(not text.contains("**") and not text.contains("`"), "without the markdown")
	else:
		# (CREDITS.md is not in the project now, 2026-10-03: the Credits screen shows the notice and the licence it has, and no
		# line pointing at the missing file)
		print("  WARNING: res://CREDITS.md is missing: the Credits screen has no credits (the CC-BY models' among them)")
		check(cr.is_empty(), "no CREDITS.md: no credits line about a missing file (%s)" % text)
	# the notice and the licence (NOTICE.txt, EULA.txt)
	var notice := MainMenu.text_file("res://NOTICE.txt")
	var eula := MainMenu.paragraphs(MainMenu.text_file("res://EULA.txt"))
	check(notice.contains("All rights reserved") and notice.contains("NO AI TRAINING"), "the copyright notice with the AI reservation")
	check(eula.size() > 20 and " ".join(eula).contains("artificial intelligence") and " ".join(eula).contains("reverse engineer"),
			"the licence in paragraphs, forbidding AI training and reverse engineering (%d)" % eula.size())
	# settings, in a file of the test's own (the player's user://settings.cfg never written)
	var own_cfg := "user://settings_menu_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(own_cfg))
	GameSettings.path = own_cfg
	GameSettings.set_value("controls", "mouse", 3.3)
	check(absf(float(GameSettings.get_value("controls", "mouse")) - 3.3) < 0.001, "a setting written and read back")
	check(is_equal_approx(float(GameSettings.get_value("audio", "master")), 1.0), "defaults read where unset")
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(own_cfg))
	# the menu with no save, then with one: the ring sport first, the open world's rows in their own panel
	for s: String in SaveGame.SLOTS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.dir() + s + ".json"))
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(6)
	var m := current_scene as MainMenu
	check(m != null, "the menu scene")
	if m == null:
		_end()
		return
	var names := _names(m)
	check(names == [MatchSetup.sport(), "Start here", "Quick match", "Practice", "Play online", "Class & talents", "Your look", "Settings", "Credits", "Quit"],
			"the demo lobby: rows 01-10 (Tidebreak, Start here, Quick match, Practice, Play online, Class & talents, Your look, Settings, Credits, Quit), no legacy Open world (%s)" % [names])
	check((m.find_child("GameTitle", true, false) as Label).text == "TIDEBREAK"
			and (m.find_child("GameSubtitle", true, false) as Label).text == "ELEMENTAL ARENA COMBAT", "the visible title identifies the elemental arena game")
	check(_sub(m, "Quick match") == MatchSetup.quick_line() and _sub(m, MatchSetup.sport()) != "",
			"Quick match's line is the last setup against a random opponent (%s)" % _sub(m, "Quick match"))
	check(_sub(m, "Practice").contains("dummy"), "Practice's line names the dummy (%s)" % _sub(m, "Practice"))
	# the broadcast lobby's parts: the next match's bug, "your fighter" (the character's name, else You, its class, talent points
	# and passive) and the type's floor (no text under 16 px at 1600 x 900: the audit's)
	var bug := m.find_child("BugLine", true, false) as Label
	check(bug != null and bug.text == MainMenu.setup_line(), "the next match's bug says the kept setup (%s)" % [bug.text if bug else "none"])
	var info := MainMenu.fighter_info(MatchSetup.element)
	check(String(info.name) != "" and String(info.cls) != "" and String(info.talents).ends_with("pts") and String(info.passive) != "",
			"your fighter: name, class, talents, passive (%s)" % [info])
	check(FighterWorld.fighter_name({"name": "Rowan"}) == "Rowan" and FighterWorld.fighter_name({"name": "   ", "sex": 0.0}) == "You",
			"the character's name, else You")
	check((m.find_child("FighterName", true, false) as Label).text == String(info.name).to_upper() or (m.find_child("FighterName", true, false) as Label).text == String(info.name),
			"the lower third carries the character's name, not the element's nickname")
	var small := 9999
	for lab_c in m.find_children("*", "Label", true, false):
		var lb := lab_c as Label
		if lb.is_visible_in_tree() and lb.text.strip_edges() != "":
			small = mini(small, lb.get_theme_font_size("font_size"))
	check(small >= BroadcastUI.MIN_PX, "the lobby's smallest type is %d px (floor %d)" % [small, BroadcastUI.MIN_PX])
	check(BroadcastUI.view_size(m) == BroadcastUI.DESIGN or root.size.x >= 480, "a headless window's layouts are drawn at the design size")
	# the window's least size (the menus are drawn for 1280 x 720 and up), and a layout that grows with a larger window
	check(root.min_size == BroadcastUI.MIN_WINDOW, "the main menu keeps its window from going under 1280 x 720 (%s)" % [root.min_size])
	var fit_now := BroadcastUI.fit                # (the live menu's own fit is put back below: the headless window is 1280 x 720)
	BroadcastUI.set_fit(1.5)
	var up := BroadcastUI.fit == 1.5 and BroadcastUI.boost == 1.0
	BroadcastUI.set_fit(3.0)
	up = up and BroadcastUI.fit == BroadcastUI.MAX_UP
	BroadcastUI.set_fit(0.5)
	check(up and is_equal_approx(BroadcastUI.boost, 1.75), "a layout scales up to %.1f times in a larger window and the type is raised in a smaller one (boost %.2f at 0.5)" % [BroadcastUI.MAX_UP, BroadcastUI.boost])
	BroadcastUI.set_fit(fit_now)
	# the menu notes when the player last touched it (the other fighters are built behind it only once it has been left alone)
	var before := m._last_input_ms
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_A
	m._input(key)
	check(m._last_input_ms >= before and m._last_input_ms > 0, "a key press is noted as the player's touch")
	var still := InputEventMouseMotion.new()
	var at := m._last_input_ms
	await create_timer(0.05).timeout
	m._input(still)
	check(m._last_input_ms == at, "a pointer that did not move is not a touch")
	# the Credits screen: CREDITS.md in it, the licence in full but for the owner's note to have a lawyer read it (EULA.txt's DRAFT line)
	(_item(m, "Credits") as Button).pressed.emit()
	await frames(2)
	var ct := _panel_texts(m)
	check(m._panel_scroll.visible and ct.any(func(t: String) -> bool: return t.contains("Poly by Google")) and ct.any(func(t: String) -> bool: return t.begins_with("TIDEBREAK: END USER")),
			"the Credits screen shows the CC-BY credits and the licence")
	check(not ct.any(func(t: String) -> bool: return t.contains("qualified lawyer")), "no note to the owner about a lawyer on the player's Credits screen")
	m._close_panel()
	await frames(2)
	# the keys and the pad: Right along the small row at the foot (Settings, Credits, Quit), Up from it to the last row
	var settings_b := _item(m, "Settings")
	if settings_b != null:
		settings_b.grab_focus()
		await _action(&"ui_right")
		var at_credits := root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == "Credits"
		await _action(&"ui_right")
		await _action(&"ui_right")
		var at_quit := root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == "Quit"
		await _action(&"ui_up")
		var at_look := root.gui_get_focus_owner() != null and root.gui_get_focus_owner().name == "YourLook"
		check(at_credits and at_quit and at_look, "the keys: Right along Settings, Credits, Quit (and no further), Up to Your look (%s, %s, %s)" % [at_credits, at_quit, at_look])
	await _small_window(m)
	# Retained legacy code remains testable directly; it has no entry in the public demo menu.
	m._open_world()
	await frames(2)
	var wn := _panel_names(m)
	check(m._panel_scroll.visible and _panel_texts(m).has("Open world") and wn.size() > 0 and wn[0] == "New game",
			"no save: the Open world panel, New game first (%s)" % [wn])
	check(_poff(m, "Load game") and _psub(m, "Load game") == "no saves yet" and _poff(m, "Campaigns") and _psub(m, "Campaigns") == "coming",
			"no save: Load greyed (no saves yet), Campaigns greyed (coming)")
	check(_panel_button(m, "Co-op") != null and not _poff(m, "Co-op") and _psub(m, "Co-op") == "host a game or join a friend's",
			"Co-op open: %s" % _psub(m, "Co-op"))
	check(_panel_button(m, "Museum") != null and _panel_button(m, "Duel (test): 1 v 1") != null, "the Museum and the duel test there")
	# co-op: its panel (nothing pressed in it: no host, no join); Esc back to the Open world panel
	(_panel_button(m, "Co-op") as Button).pressed.emit()
	await frames(2)
	var co := _panel_texts(m)
	var addr := m._panel.find_children("*", "LineEdit", true, false)
	check(m._panel_scroll.visible and co.has("Co-op") and co.has("Squad:  1") and co.has("Host a game") and co.has("Join")
			and addr.size() == 1 and (addr[0] as LineEdit).text == "127.0.0.1", "the Co-op panel: squad, host, the address, join (%s)" % [co])
	var sq := _panel_button(m, "Squad:  1")
	if sq:
		sq.pressed.emit()
		await frames(1)
	check(_panel_texts(m).has("Squad:  2") and m._squad == 2, "a press steps the squad (%d)" % m._squad)
	m._squad = 1
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	m._unhandled_input(esc)
	await frames(2)
	check(m._panel_scroll.visible and _panel_texts(m).has("Open world"), "Esc: back to the Open world panel")
	m._unhandled_input(esc)
	await frames(2)
	check(not m._panel_scroll.visible, "Esc again: the panel closed")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.dir()))
	var doc := {"format": SaveParts.FORMAT, "version": SaveParts.VERSION, "parts": {},
			"meta": {"saved_unix": Time.get_unix_time_from_system(), "slot": "quick", "date": "25 August 1765", "time": "20:24"}}
	var f2 := FileAccess.open(SaveGame.dir() + "quick.json", FileAccess.WRITE)
	f2.store_string(JSON.stringify(doc))
	f2.close()
	m._build_items()
	m._open_world()
	await frames(2)
	wn = _panel_names(m)
	check(wn.size() > 0 and wn[0] == "Continue", "a save: Continue first (%s)" % [wn])
	var line := MainMenu._save_line("quick")
	check(line == "Quick save  ·  25 August 1765, 20:24  ·  just now", "its line: '%s'" % line)
	check(_psub(m, "Continue") == line, "under Continue: '%s'" % _psub(m, "Continue"))
	check(not _poff(m, "Load game") and _psub(m, "Load game") == "", "a save: Load open")
	(_panel_button(m, "Load game") as Button).pressed.emit()
	await frames(2)
	var qb := _panel_button(m, "Quick save")
	var qs := qb.find_child("Sub", true, false) as Label if qb else null
	check(qb != null and qs != null and qs.text == "25 August 1765, 20:24  ·  just now", "Load lists the quick save, its date and when (%s)"
			% [qs.text if qs else _panel_texts(m)])
	m._unhandled_input(esc)
	await frames(2)
	check(m._panel_scroll.visible and _panel_texts(m).has("Open world"), "Esc from Load: back to the Open world panel")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.dir() + "quick.json"))
	# the museum, from the Open world panel
	var mb := _panel_button(m, "Museum")
	check(mb != null, "the Open world panel has the Museum")
	if mb:
		mb.pressed.emit()
		await frames(2)
		var n_mus := MenuPaintings.museum().size()
		check(m._museum != null and m._museum.visible and m._museum_i == 0 and m._museum_pic.texture != null,
				"clicked: the museum over the menu, its first painting")
		check(m._museum_title.text == MenuPaintings.title_line(MenuPaintings.museum()[0]) and m._museum_text.text.length() > 40
				and m._museum_room.text.contains("1 of %d" % n_mus),
				"its title, story and room: '%s' / '%s'" % [m._museum_title.text, m._museum_room.text])
		(m._museum.find_child("Next", true, false) as Button).pressed.emit()
		await frames(1)
		check(m._museum_i == 1, "Next: the second painting (%d)" % m._museum_i)
		var ev := InputEventAction.new()
		ev.action = &"ui_left"
		ev.pressed = true
		m._unhandled_input(ev)
		m._unhandled_input(ev)
		check(m._museum_i == n_mus - 1, "the left arrow goes back, round to the last (%d)" % m._museum_i)
		m._unhandled_input(esc)
		await frames(1)
		check(not m._museum.visible and m._panel_scroll.visible and _panel_texts(m).has("Open world"),
				"Esc leaves the museum, back to the Open world panel")
	m._close_panel()
	# the sport's panel opens (its setup: tests/ring/test_match_setup.gd)
	(_item(m, MatchSetup.sport()) as Button).pressed.emit()
	await frames(2)
	var mt := _panel_texts(m)
	check(m._panel_scroll.visible and mt.has(MatchSetup.sport()) and m._element_rows.size() == 4 and mt.has("Begin"),
			"the sport's row: its panel, the four elements and Begin")
	_setup_fits(m, "1600x900")
	# (the character has no element yet in a test run: the setup offers the step that Esc left; with one it does not)
	var offered := m._panel.find_child("ElementLink", true, false) != null
	check(offered == (AppearanceStore.element() == ""), "the setup offers 'Choose your element' for as long as the character has none (%s)" % offered)
	m._close_panel()
	# your look: the character creator over the menu, on the kept look (a test run's own: AppearanceStore.TEST_CURRENT)
	(_item(m, "Your look") as Button).pressed.emit()
	await frames(3)
	var cc := root.find_children("*", "CharacterCreator", true, false)
	check(cc.size() == 1 and paused, "Your look: the character creator over the menu (%d)" % cc.size())
	for c in cc:
		c.queue_free()          # (not close(): nothing saved)
	paused = false
	await frames(2)
	root.disable_3d = false
	await _element_and_window(m)
	# new game: no background to pick; the switches; Begin at once
	m._open_new_game()
	await frames(2)
	var rows := m._panel.find_children("*", "Button", true, false)
	check(rows.filter(func(b: Node) -> bool: return b.has_meta(&"name")).is_empty() and m._chosen_bg == "",
			"no background to pick (the default newcomer)")
	var texts := _panel_texts(m)
	check(texts.has("A new life") and not texts.has("Story:  Two Fires") and texts.has("Start with nothing:  off") and texts.has("Spouse:  on"),
			"the start-with-nothing and spouse switches, no story switch (Two Fires retired) (%s)" % [texts])
	for pair: Array in [["Start with nothing:  off", "Start with nothing:  on"], ["Spouse:  on", "Spouse:  off"]]:
		var sw := _panel_button(m, String(pair[0]))
		if sw:
			sw.pressed.emit()
			await frames(1)
			var flipped := _panel_texts(m).has(String(pair[1]))
			sw.pressed.emit()
			await frames(1)
			check(flipped and _panel_texts(m).has(String(pair[0])), "a press flips '%s' and back" % pair[0])
		else:
			check(false, "the switch '%s'" % pair[0])
	check(not m._bare and m._spouse, "the switches as they began (nothing off, spouse on)")
	var begin := _panel_button(m, "Begin")
	check(begin != null and not begin.disabled, "Begin at once (no background to wait for)")
	SaveGame._launched = false
	if begin:
		begin.pressed.emit()
	await frames(2)
	check(SaveGame._launched and SaveGame.pending.is_empty() and MainMenu.background_id == "" and StoryDirector.incoming == ""
			and not MainMenu.bare_start and MainMenu.spouse_start,
			"into a new game: no save continued, no background, no storyline (free play) (%s)" % StoryDirector.incoming)
	var ls := root.find_children("*", "LoadingScreen", true, false)
	check(ls.size() == 1, "through the loading screen")
	# (by the clock, not a count of frames: under --fixed-fps the frames run faster than the level's threaded load)
	var t_load := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_load < 180000:
		await process_frame
		if root.find_children("*", "LoadingScreen", true, false).is_empty():
			break
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn", "the level (%s)" % [current_scene.scene_file_path if current_scene else "none"])
	check(not MainMenu.new_game, "the creator's offer taken by the level")
	for c in root.find_children("*", "CharacterCreator", true, false):
		c.queue_free()          # (not close(): at a first launch it saves the default look)
	paused = false
	await frames(10)
	# pause
	var player := current_scene.get_node_or_null("Player")
	var pm := current_scene.get_node_or_null("PauseMenu") as PauseMenu
	if pm == null:
		pm = PauseMenu.install(current_scene, player)
		await frames(2)
	check(pm._can_open(), "the pause menu can open")
	pm.open()
	await frames(2)
	check(paused and pm.is_open(), "Esc's menu: the game paused")
	pm.close()
	await frames(2)
	check(not paused and not pm.is_open(), "closed: running")
	_end()


## A creator's stand-in for the menu (only its closed signal).
class StubCreator extends Node:
	signal closed(accepted: bool)


func _focus_name() -> String:
	var f := root.gui_get_focus_owner()
	return String(f.name) if f != null else ""


func _windows(m: MainMenu) -> Array:
	return m.find_children("*", "AdvancementWindow", false, false).filter(func(w: Node) -> bool: return not w.is_queued_for_deletion())


## The character's element in the lobby, and the Character Advancement window opened and closed from the menu.
func _element_and_window(m: MainMenu) -> void:
	var kept: Dictionary = {}
	for p: String in [AppearanceStore.current_path(), AppearanceStore.offered_path()]:
		kept[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	AppearanceStore.save_current(AppearanceStore.validate(AppearanceStore.default_look()))
	AppearanceStore.set_element("air")
	m._close_panel()
	m._build_items()
	m._paint_lobby()
	check(MatchSetup.element == "air", "the character's element (Air) is the lobby's (%s)" % MatchSetup.element)
	var which := m._lobby.find_child("Which", true, false) as Label
	check(which != null and which.text.to_lower().begins_with("air"), "its fighter card says Air ('%s')" % [which.text if which else ""])
	check(_sub(m, "Class & talents") != "" and m._items.find_child("ClassTalents", true, false) != null, "the Class & talents row, with its line")
	# the lobby's row: the real window, for the lobby's element, over the menu
	var row := m._items.find_child("ClassTalents", true, false) as Button
	row.grab_focus()
	row.pressed.emit()
	await frames(3)
	var wins := _windows(m)
	check(wins.size() == 1 and wins[0] is AdvancementWindow, "Class & talents opens the Character Advancement window over the menu (%d)" % wins.size())
	var win := wins[0] as AdvancementWindow if not wins.is_empty() else null
	if win != null:
		check(win.element == "air" and win.layer > 0 and win.process_mode == Node.PROCESS_MODE_ALWAYS, "for the lobby's element (%s), above the menu, working over a pause" % win.element)
		m._open_advancement()
		await frames(1)
		check(_windows(m).size() == 1, "asked again: the one window")
		await _action(&"ui_cancel")
		await frames(3)
		check(_windows(m).is_empty() and not m._panel_scroll.visible, "Esc closes the window alone (the menu stays)")
		check(_focus_name() == "ClassTalents", "the focus is back on the Class & talents row (%s)" % _focus_name())
	# the match setup's small link: the same window, the setup's own choices left as they were
	MatchSetup.difficulty = "hard"
	m._open_match()
	await frames(3)
	var link := m._panel.find_child("ClassLink", true, false) as Button
	check(link != null, "the match setup has a Class & talents link")
	if link != null:
		link.grab_focus()
		link.pressed.emit()
		await frames(3)
		check(_windows(m).size() == 1 and (_windows(m)[0] as AdvancementWindow).element == "air", "it opens the window for the same element")
		await _action(&"ui_cancel")
		await frames(3)
		check(_windows(m).is_empty() and m._panel.find_child("MatchCard", true, false) != null and m._panel_scroll.visible,
				"Esc: the window closed, the match setup still up")
		check(_focus_name() == "ClassLink" and MatchSetup.difficulty == "hard", "the focus back on the link, the setup's choices not read again (%s, %s)" % [_focus_name(), MatchSetup.difficulty])
	m._close_panel()
	# its Your look tab: the window closes, then the creator (a stand-in) is asked
	var stubs: Array = []
	MainMenu.creator_hook = func(first: bool) -> Object:
		var sc := StubCreator.new()
		stubs.append([sc, first])
		return sc
	m._open_advancement()
	await frames(3)
	var w2 := _windows(m)
	if not w2.is_empty():
		(w2[0] as AdvancementWindow).look_requested.emit()
		await frames(4)
		check(_windows(m).is_empty() and stubs.size() == 1 and not bool(stubs[0][1]), "the window's Your look tab: it closes, the creator is asked (not the first-run offer)")
	else:
		check(false, "the window opened for the Your look tab")
	MainMenu.creator_hook = Callable()
	for st: Array in stubs:
		(st[0] as Node).free()
	# put the test run's own look files back as they were
	for p: String in kept:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		if kept[p] != null:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(kept[p])
			f.close()
	MatchSetup.difficulty = "normal"
	m._close_panel()
	m._build_items()
	m._paint_lobby()
	await frames(2)


func _small_window(m: MainMenu) -> void:
	var previous := root.size
	var old_title := m._cap_title.text
	var old_caption := m._cap_text.text
	m.set_process(false)
	# Longest arena caption is the strongest check against the menu's hit targets.
	var longest := 0
	for picture: Dictionary in MenuPaintings.PICTURES:
		if String(picture.captions[0]).length() > longest:
			longest = String(picture.captions[0]).length()
			m._cap_title.text = String(picture.title)
			m._cap_text.text = String(picture.captions[0])
	m._close_panel()
	root.size = Vector2i(1280, 720)
	await frames(3)
	var view := Rect2(Vector2.ZERO, Vector2(root.size))
	var fits := true
	for b: Control in m._items.get_children():
		fits = fits and view.encloses(b.get_global_rect())
	check(fits, "1280x720: every main-menu button fits inside the window")
	var caption_gap := m._cap_title.get_global_rect().position.y - m._items.get_global_rect().end.y
	check(caption_gap >= 16.0, "1280x720: the longest arena caption clears menu hit targets by at least 16px (%.1fpx)" % caption_gap)
	var start := _item(m, "Start here")
	if start != null:
		var at := start.get_global_rect().get_center()
		for down in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			click.position = at
			root.push_input(click, true)
			await frames(1)
	await frames(2)
	var learn := m._panel.find_child("Basics", true, false) as Button
	var easy := m._panel.find_child("EasyMatch", true, false) as Button
	check(m._panel_scroll.visible and learn != null and easy != null,
			"1280x720: a click at the scaled Start here button opens its choices")
	check(learn != null and easy != null and view.encloses(learn.get_global_rect()) and view.encloses(easy.get_global_rect()),
			"1280x720: both beginner launch buttons fit inside the window")
	m._close_panel()
	# (the match setup in the small window, its type raised: the rows lay themselves from the real heights, a wrapped line included)
	(_item(m, MatchSetup.sport()) as Button).pressed.emit()
	await frames(3)
	_setup_fits(m, "1280x720")
	var small_px := 9999.0
	var small_at := ""
	for lc in m._panel.find_children("*", "Label", true, false):
		var lb := lc as Label
		if lb.is_visible_in_tree() and lb.text.strip_edges() != "":
			var px := float(lb.get_theme_font_size("font_size")) * lb.get_global_transform_with_canvas().get_scale().y
			if px < 14.0 and small_at.length() < 400:
				small_at += "'%s' %s dsz %s, " % [lb.text, m._panel.get_path_to(lb), lb.get_meta(&"dsz", "-")]
			small_px = minf(small_px, px)
	check(small_px >= 14.0, "1280x720: the match setup's smallest type is %.1f px on screen (floor 14; boost %.3f fit %.3f root %s): %s" % [small_px, BroadcastUI.boost, BroadcastUI.fit, root.size, small_at])
	m._close_panel()
	# a large window: the layouts scale up (to MAX_UP) as the mock-ups do, so the setup's cards are as big on screen as the
	# approved mock-up's (capped at 1, a 1920 x 1080 window drew them about 30% smaller, the 2026-10-10 critic)
	root.size = Vector2i(1920, 1080)
	await frames(3)
	check(is_equal_approx(m._menu_layout.scale.x, 1.2) and is_equal_approx(BroadcastUI.fit, 1.2) and BroadcastUI.boost == 1.0,
			"1920x1080: the menu's layout is drawn 1.2 times (scale %.3f, fit %.3f, boost %.3f)" % [m._menu_layout.scale.x, BroadcastUI.fit, BroadcastUI.boost])
	(_item(m, MatchSetup.sport()) as Button).pressed.emit()
	await frames(3)
	var fire := m._element_rows.get("fire") as Control
	var on_screen := fire.get_global_rect().size if fire != null else Vector2.ZERO
	check(on_screen.distance_to(Vector2(214, 452) * 1.2) < 1.0, "1920x1080: a fighter card is %s on screen (the mock-up's 214 x 452 at 1.2: %s)" % [on_screen, Vector2(214, 452) * 1.2])
	_setup_fits(m, "1920x1080")
	m._close_panel()
	root.size = Vector2i(2560, 1440)
	await frames(3)
	check(is_equal_approx(m._menu_layout.scale.x, 1.5), "2560x1440: the layout at its most, 1.5 (%.3f)" % m._menu_layout.scale.x)
	root.size = previous
	await frames(2)
	m._cap_title.text = old_title
	m._cap_text.text = old_caption
	m.set_process(true)
	await frames(3)


## The match setup's card as laid out now: in each row the name, then the chips, then the line (wrapped lines included) inside the row,
## the rows one under another without touching, the card inside the window, and Begin's words and Enter key centred on the button.
func _setup_fits(m: MainMenu, tag: String) -> void:
	var mc := m._panel.find_child("MatchCard", true, false) as Control
	if mc == null:
		check(false, "%s: the match card" % tag)
		return
	var bad: Array = []
	var prev_bottom := -1.0
	for nm: String in ["Opponent", "Difficulty", "Rules", "Rounds", "Games", "Light"]:
		var g := mc.find_child(nm + "Row", false, false) as Control
		if g == null or not g.visible:
			continue
		var ttl := g.find_child("RowTitle", false, false) as Control
		var seg := g.find_child(nm, false, false) as Control
		var ln := g.find_child("Line", false, false) as Label
		var ttl_end := ttl.position.y + ttl.size.y
		var seg_end := seg.position.y + seg.size.y
		var ln_end := ln.position.y + ln.size.y
		if ttl_end > seg.position.y + 1.0 or seg_end > ln.position.y + 1.0 or ln_end > g.size.y or ln.get_line_count() * ln.get_line_height() > ln.size.y + 1.0:
			bad.append("%s (title %.0f, chips %.0f-%.0f, line %.0f-%.0f, row %.0f)" % [nm, ttl_end, seg.position.y, seg_end, ln.position.y, ln_end, g.size.y])
		if g.position.y < prev_bottom - 0.5:
			bad.append("%s starts at %.0f over the row above (%.0f)" % [nm, g.position.y, prev_bottom])
		prev_bottom = g.position.y + g.size.y
	check(bad.is_empty(), "%s: each row of the match card holds its name, chips and wrapped line apart, the rows apart (%s)" % [tag, bad])
	var ctl := mc.find_child("ControlsRule", false, false) as Control
	check(ctl != null and ctl.position.y >= prev_bottom - 0.5, "%s: Controls under the last row (%.0f under %.0f)" % [tag, ctl.position.y if ctl else -1.0, prev_bottom])
	var begin := mc.find_child("Begin", false, false) as Control
	var text := begin.find_child("Text", true, false) as Control
	# (centres through each one's own transform: global_position is on screen, size is the control's own, the layout is scaled)
	var dy := absf(_mid_y(text) - _mid_y(begin)) / maxf(text.get_global_transform_with_canvas().get_scale().y, 0.01)
	check(dy < 2.0, "%s: Begin's words centred on its button (%.1f px off)" % [tag, dy])
	var caps := begin.find_children("*", "PanelContainer", true, false)
	var kc := (caps[0] as Control) if not caps.is_empty() else null
	var ky := absf(_mid_y(kc) - _mid_y(begin)) / maxf(kc.get_global_transform_with_canvas().get_scale().y, 0.01) if kc != null else 99.0
	check(ky < 2.0, "%s: its Enter key centred too (%.1f px off)" % [tag, ky])
	var card_end := mc.get_global_rect().end.y
	var view_h := BroadcastUI.view_size(m).y
	check(card_end <= view_h + 0.5, "%s: the card ends inside the window (%.0f of %.0f)" % [tag, card_end, view_h])
	# the breath between rows (the 2026-10-10 critic: at 1280 x 720 a wrapped line touched the next row's rule): every line's last
	# descender at least ROW_AIR_MIN above the next rule, the full ROW_AIR when the window has the room (1600 x 900 and up), each rule
	# at least a pixel tall on screen, and Begin clear of the Controls line
	var least := INF
	var rows_y: Array = []
	for nm: String in ["Opponent", "Difficulty", "Rules", "Rounds", "Games", "Light"]:
		var g := mc.find_child(nm + "Row", false, false) as Control
		if g != null and g.visible:
			rows_y.append(g)
	var thin := 99.0
	for i in rows_y.size():
		var g := rows_y[i] as Control
		var ln := g.find_child("Line", false, false) as Label
		var ink_end := g.position.y + ln.position.y + float(ln.get_line_height()) * maxi(ln.get_line_count(), 1)
		var next_rule := (rows_y[i + 1] as Control).position.y if i + 1 < rows_y.size() else ctl.position.y
		least = minf(least, next_rule - ink_end)
		var r := g.find_child("Rule", false, false) as Control
		thin = minf(thin, r.size.y * r.get_global_transform_with_canvas().get_scale().y)
	var want := MainMenu.ROW_AIR - 0.5 if BroadcastUI.fit >= 1.0 else MainMenu.ROW_AIR_MIN - 0.5
	check(least >= want, "%s: every row's line clears the next rule by %.1f design px (want %.1f)" % [tag, least, want + 0.5])
	check(thin >= 0.99, "%s: the rows' rules are at least a pixel on screen (%.2f)" % [tag, thin])
	var crow := mc.find_child("Controls", false, false) as Control
	var csub := crow.find_child("Sub", false, false) as Control
	var sub_end := crow.position.y + csub.position.y + csub.get_minimum_size().y
	check(sub_end <= begin.position.y + 0.5, "%s: Begin clear of the Controls line (%.0f under %.0f)" % [tag, begin.position.y, sub_end])
	var link := m._panel.find_child("ElementLink", true, false) as Control
	var sl := m._panel.find_child("SportLine", true, false) as Label
	if link != null and sl != null:
		var sl_end := sl.get_global_transform_with_canvas() * Vector2(0.0, sl.get_minimum_size().y)
		var link_top := link.get_global_transform_with_canvas() * Vector2.ZERO
		var card_top := (m._element_rows.values()[0] as Control).get_global_transform_with_canvas() * Vector2.ZERO
		var link_end := link.get_global_transform_with_canvas() * Vector2(0.0, link.size.y)
		check(link_top.y >= sl_end.y + 3.0 and link_end.y <= card_top.y + 0.5,
				"%s: 'Choose your element' clear of the rule line over it and of the cards under it (%.0f..%.0f, line ends %.0f, cards at %.0f)" % [tag, link_top.y, link_end.y, sl_end.y, card_top.y])


## A control's vertical middle on screen.
func _mid_y(c: Control) -> float:
	return (c.get_global_transform_with_canvas() * (c.size * 0.5)).y


func _names(m: MainMenu) -> Array:
	var out: Array = []
	for b in m._items.find_children("*", "Button", true, false):
		if b.is_queued_for_deletion():
			continue
		var t := b.find_child("Text", true, false) as Label
		if t:
			out.append(t.text)
	return out


func _off(m: MainMenu, name: String) -> bool:
	var b := _item(m, name)
	return b != null and b.disabled


## The menu's item `name` (not one on its way out), or null.
func _item(m: MainMenu, name: String) -> Button:
	for b in m._items.find_children("*", "Button", true, false):
		if b.is_queued_for_deletion():
			continue
		var t := b.find_child("Text", true, false) as Label
		if t and t.text == name:
			return b as Button
	return null


## The line under the menu's item `name` ("" none).
func _sub(m: MainMenu, name: String) -> String:
	var b := _item(m, name)
	var l := b.find_child("Sub", true, false) as Label if b else null
	return l.text if l else ""


## The texts of the open sub-screen: its headings' and labels', and its rows' main lines.
func _panel_texts(m: MainMenu) -> Array:
	var out: Array = []
	for n in m._panel.find_children("*", "Label", true, false):
		if not n.is_queued_for_deletion() and not (n as Label).text.is_empty():
			out.append((n as Label).text)
	return out


## The open sub-screen's rows' main lines, in order.
func _panel_names(m: MainMenu) -> Array:
	var out: Array = []
	for b in m._panel.find_children("*", "Button", true, false):
		if b.is_queued_for_deletion():
			continue
		var t := b.find_child("Text", true, false) as Label
		if t:
			out.append(t.text)
	return out


## The sub-screen's row `text` greyed.
func _poff(m: MainMenu, text: String) -> bool:
	var b := _panel_button(m, text)
	return b != null and b.disabled


## The line under the sub-screen's row `text` ("" none).
func _psub(m: MainMenu, text: String) -> String:
	var b := _panel_button(m, text)
	var l := b.find_child("Sub", true, false) as Label if b else null
	return l.text if l else ""


## The sub-screen's row whose main line is `text`, or null.
func _panel_button(m: MainMenu, text: String) -> Button:
	for b in m._panel.find_children("*", "Button", true, false):
		if b.is_queued_for_deletion():
			continue
		var t := b.find_child("Text", true, false) as Label
		if t and t.text == text:
			return b as Button
	return null


func _end() -> void:
	if fails.is_empty():
		print("MAIN MENU TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("MAIN MENU TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
