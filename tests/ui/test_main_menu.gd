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
##   credits   CREDITS.md in blocks, the CC-BY models (when the file is there; the menu's fallback line when not); the
##             copyright notice and the licence (NOTICE.txt, EULA.txt)
##   settings  a value written and read back (GameSettings.path pointed at a file of the test's own: never the player's)
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
		check(cr.size() >= 8, "the credits in blocks (%d)" % cr.size())
		check(text.contains("Poly by Google"), "the CC-BY models' credits are in it")
		check(not text.contains("**") and not text.contains("`"), "without the markdown")
	else:
		# (CREDITS.md is not in the project now, 2026-10-03: the Credits screen shows its fallback line)
		print("  WARNING: res://CREDITS.md is missing: the Credits screen has no credits (the CC-BY models' among them)")
		check(cr.size() == 1 and text.contains("see CREDITS.md"), "no CREDITS.md: the credits' fallback line (%s)" % text)
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
	check(names == [MatchSetup.sport(), "Start here", "Quick match", "Practice", "Your look", "Settings", "Credits", "Quit"],
			"the demo menu keeps the arena entry points and omits the legacy Open world (%s)" % [names])
	check((m.find_child("GameTitle", true, false) as Label).text == "TIDEBREAK"
			and (m.find_child("GameSubtitle", true, false) as Label).text == "ELEMENTAL ARENA COMBAT", "the visible title identifies the elemental arena game")
	check(_sub(m, "Quick match") == MatchSetup.quick_line() and _sub(m, MatchSetup.sport()) != "",
			"Quick match's line is the last setup against a random opponent (%s)" % _sub(m, "Quick match"))
	check(_sub(m, "Practice").contains("dummy"), "Practice's line names the dummy (%s)" % _sub(m, "Practice"))
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
	root.size = previous
	m._cap_title.text = old_title
	m._cap_text.text = old_caption
	m.set_process(true)
	await frames(3)


func _names(m: MainMenu) -> Array:
	var out: Array = []
	for b in m._items.get_children():
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
	for b in m._items.get_children():
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
