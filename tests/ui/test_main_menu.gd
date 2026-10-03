extends SceneTree
## The main menu, the loading screen and the pause menu (scripts/ui/menu), headless:
##
##   Godot --headless --path . -s tests/ui/test_main_menu.gd
##
##   start     the project starts at the menu; the boot splash is the game's own painting
##   pictures  every game picture there (the menu's and the loading screens'), each with a title and a caption; a
##             round shows each before a repeat; the museum's paintings, each with its artist and story; no portraits
##   museum    the menu's Museum: the paintings one at a time, Next and the arrows go on (round to the first), Back
##             and Esc leave
##   menu      no save: New game first, Load greyed, Co-op and Campaigns greyed ("coming"); a save: Continue first,
##             its line "Quick save  ·  <date>, <hour>  ·  just now"
##   new game  the backgrounds from the survival rules, their money in shillings; Begin into the level through the
##             loading screen, no save continued, the background kept and the creator's offer taken
##   credits   CREDITS.md in blocks, the CC-BY models; the copyright notice and the licence (NOTICE.txt, EULA.txt)
##   settings  a value written and read back (the file restored after)
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
	check(String(ProjectSettings.get_setting("application/boot_splash/image")) == "res://assets/ui/splash.png"
			and ResourceLoader.exists("res://assets/ui/splash.png"), "the boot splash is the game's own")
	# the game's pictures, and the museum's
	var all := MenuPaintings.all()
	check(all.size() == MenuPaintings.PICTURES.size() and all.size() >= 4,
			"every game picture is there (%d of %d)" % [all.size(), MenuPaintings.PICTURES.size()])
	check(all.all(func(e: Dictionary) -> bool: return String(e.path).begins_with(MenuPaintings.PICTURES_DIR) and not e.has("by")),
			"the menu and loading screens show the game's own pictures")
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
	check(cr.size() >= 8, "the credits in blocks (%d)" % cr.size())
	check(text.contains("Poly by Google"), "the CC-BY models' credits are in it")
	check(not text.contains("**") and not text.contains("`"), "without the markdown")
	# the notice and the licence (NOTICE.txt, EULA.txt)
	var notice := MainMenu.text_file("res://NOTICE.txt")
	var eula := MainMenu.paragraphs(MainMenu.text_file("res://EULA.txt"))
	check(notice.contains("All rights reserved") and notice.contains("NO AI TRAINING"), "the copyright notice with the AI reservation")
	check(eula.size() > 20 and " ".join(eula).contains("artificial intelligence") and " ".join(eula).contains("reverse engineer"),
			"the licence in paragraphs, forbidding AI training and reverse engineering (%d)" % eula.size())
	# settings (the file put back as it was)
	var had := FileAccess.file_exists(GameSettings.PATH)
	var before := FileAccess.get_file_as_string(GameSettings.PATH) if had else ""
	GameSettings.set_value("controls", "mouse", 3.3)
	check(absf(float(GameSettings.get_value("controls", "mouse")) - 3.3) < 0.001, "a setting written and read back")
	check(float(GameSettings.get_value("audio", "master")) >= 0.0, "defaults read where unset")
	if had:
		var f := FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
		f.store_string(before)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))
	# the menu with no save, then with one
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
	check(names.size() > 0 and names[0] == "New game", "no save: New game first (%s)" % [names])
	check(_off(m, "Load game") and _off(m, "Co-op") and _off(m, "Campaigns"), "Load, Co-op and Campaigns greyed")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.dir()))
	var doc := {"format": SaveParts.FORMAT, "version": SaveParts.VERSION, "parts": {},
			"meta": {"saved_unix": Time.get_unix_time_from_system(), "slot": "quick", "date": "25 August 1765", "time": "20:24"}}
	var f2 := FileAccess.open(SaveGame.dir() + "quick.json", FileAccess.WRITE)
	f2.store_string(JSON.stringify(doc))
	f2.close()
	m._build_items()
	await frames(2)
	names = _names(m)
	check(names.size() > 0 and names[0] == "Continue", "a save: Continue first (%s)" % [names])
	var line := MainMenu._save_line("quick")
	check(line == "Quick save  ·  25 August 1765, 20:24  ·  just now", "its line: '%s'" % line)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.dir() + "quick.json"))
	# the museum, a menu item
	check(names.has("Museum"), "the menu has the Museum (%s)" % [names])
	var mb: Button = null
	for b in m._items.get_children():
		var tl := b.find_child("Text", true, false) as Label
		if tl and tl.text == "Museum":
			mb = b
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
		var esc := InputEventAction.new()
		esc.action = &"ui_cancel"
		esc.pressed = true
		m._unhandled_input(esc)
		await frames(1)
		check(not m._museum.visible, "Esc leaves the museum")
	# new game
	m._open_new_game()
	await frames(2)
	var rows := m._panel.find_children("*", "Button", true, false)
	var bg_rows := rows.filter(func(b: Node) -> bool: return b.has_meta(&"name"))
	check(bg_rows.size() == 2, "the survival rules' two backgrounds (%d)" % bg_rows.size())
	var begin: Button = null
	for b: Button in rows:
		var t := b.find_child("Text", true, false) as Label
		if t and t.text == "Begin":
			begin = b
	check(begin != null and begin.disabled, "Begin waits for a background")
	if bg_rows.size() > 0:
		(bg_rows[0] as Button).pressed.emit()
		await frames(2)
	check(begin != null and not begin.disabled and m._chosen_bg == "bg.backcountry_hunter", "chosen: Begin (%s)" % m._chosen_bg)
	SaveGame._launched = false
	if begin:
		begin.pressed.emit()
	await frames(2)
	check(SaveGame._launched and SaveGame.pending.is_empty() and MainMenu.background_id == "bg.backcountry_hunter",
			"into a new game: no save continued, the background kept")
	var ls := root.find_children("*", "LoadingScreen", true, false)
	check(ls.size() == 1, "through the loading screen")
	for i in 900:
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
	for b in m._items.get_children():
		var t := b.find_child("Text", true, false) as Label
		if t and t.text == name:
			return (b as Button).disabled
	return false


func _end() -> void:
	if fails.is_empty():
		print("MAIN MENU TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("MAIN MENU TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
