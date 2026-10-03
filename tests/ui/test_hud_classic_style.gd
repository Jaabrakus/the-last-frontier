extends SceneTree
## The classic HUD put together (the owner 2026-10-03: "can the hud be similar to world of warcraft vanilla?": ClassicFrames
## and HudClassicMap on FrontierHUD), on the real level with the real player, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/ui/test_hud_classic_style.gd -- survival=on hud=classic
##
##   layout    at 1280x720, 1600x900 and 1920x1080: the player and target frames, the minimap and the quest tracker, the
##             chat log, the renown and action bars, the micro menu and the bags all on the screen, in their corners, none
##             over another; the interactor's prompt and its "Hold E" line clear above the bars (PlayerInteractor.prompt_lift)
##   layers    the story's cards, the death screen, the Tab screen, the dialogue and the pause menu over the HUD; while a
##             talk is open the action bar, the renown bar and the chat step aside for its box (ClassicFrames.talking)
##   command   the command mode (RtsMode, its own screen) hides the frames; leaving it brings them back
##   switch    the Settings row "HUD style" (GameSettings.hud_style_row): Minimal takes the classic parts off at once (the
##             vitals, the compass, the toasts and StoryHUD's mission lines back, the prompt at its old place), Classic puts
##             them on again; the choice is kept in the settings file (the file is put back as it was after)
## Ends with "HUD CLASSIC STYLE TEST OK (<n> checks)" or "HUD CLASSIC STYLE TEST FAILED <failures>/<n>".

const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var hud: FrontierHUD
var fr: ClassicFrames
var m: HudClassicMap
var story: StoryDirector


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func settle(n := 3) -> void:
	for i in n:
		await process_frame
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await settle(20)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	hud = player.hud if player else null
	check(hud != null, "the level has the player's HUD")
	if hud == null:
		_end()
		return
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	fr = hud.classic
	m = HudClassicMap.find(hud)
	check(fr != null and m != null, "hud=classic: the classic frames and the map corner are on the HUD")
	if fr == null or m == null:
		_end()
		return
	story = StoryDirector.find(self)
	if story != null and story.hud != null:
		story.hud.set_mission("The Clearing", "Fell a pine by the fort and bring the logs to the store, then tell Margaretha at the trading post",
				"1 / 3", [])
		story.hud.marker_at = player.global_position + Vector3(60.0, 0.0, -110.0)
	await settle(10)
	await _test_layout()
	await _test_layers()
	await _test_command()
	await _test_switch()
	_end()


# --- the layout ------------------------------------------------------------------------------------------------------

func _parts() -> Dictionary:
	return {"player frame": fr.player_frame, "target frame": fr.target_frame, "action bar": fr.action_bar, "renown": fr.renown,
			"micro menu": fr.micro, "bags": fr.bags, "minimap": m.minimap, "tracker": m.tracker, "chat": m.chat}


## A label's first line as drawn (its top, the font's height): what the eye sees of a one-line label.
func _line_box(l: Label) -> Rect2:
	var r := l.get_global_rect()
	var f := l.get_theme_font(&"font")
	var px := l.get_theme_font_size(&"font_size")
	return Rect2(r.position, Vector2(r.size.x, f.get_height(px)))


func _test_layout() -> void:
	check(m.tracker.visible, "a mission: the quest tracker shows it (%s)" % m.tracker.title)
	m.chat.add("Mind the river ice when you cross, and the ford below the mill where the bank gives way", "say", null, "",
			"Margaretha Rauch")
	for sz: Vector2i in SIZES:
		root.size = sz
		await settle(4)
		m._fit_chat()                                # (once a second in play)
		await settle(2)
		var tag := "%dx%d" % [sz.x, sz.y]
		var screen := Rect2(Vector2.ZERO, Vector2(sz))
		var parts := _parts()
		var rects := {}
		var off := PackedStringArray()
		for k: String in parts:
			var r := (parts[k] as Control).get_global_rect()
			if k == "action bar":                    # (from its plate down: the renown bar sits in the margin over it)
				r = Rect2(r.position + Vector2(0, fr.action_bar.plate.position.y), r.size - Vector2(0, fr.action_bar.plate.position.y))
			rects[k] = r
			if not screen.encloses(r) or r.size.x < 4.0 or r.size.y < 4.0:
				off.append("%s %s" % [k, r])
		check(off.is_empty(), "%s: every part on the screen %s" % [tag, ", ".join(off)])
		var over := PackedStringArray()
		var keys := rects.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				if (rects[keys[i]] as Rect2).intersects(rects[keys[j]] as Rect2):
					over.append("%s / %s" % [keys[i], keys[j]])
		check(over.is_empty(), "%s: none over another %s" % [tag, ", ".join(over)])
		var w := float(sz.x)
		var h := float(sz.y)
		var pf: Rect2 = rects["player frame"]
		var mm: Rect2 = rects["minimap"]
		var ab: Rect2 = rects["action bar"]
		var bg: Rect2 = rects["bags"]
		var ch: Rect2 = rects["chat"]
		check(pf.position.x < 40.0 and pf.position.y < 40.0 and mm.end.x > w - 40.0 and mm.position.y < 40.0
				and absf(ab.get_center().x - w * 0.5) < 2.0 and ab.end.y > h - 10.0 and bg.end.x > w - 40.0 and bg.end.y > h - 20.0
				and ch.position.x < 40.0 and ch.end.y > h - 40.0,
				"%s: in their corners (frames top left, map top right, bar bottom centre, bags bottom right, chat bottom left)" % tag)
		check(ch.size.x >= HudChatLog.MIN_W, "%s: the chat %.0f px wide" % [tag, ch.size.x])
		var wide := 0.0
		for ln: Dictionary in m.chat.lines:
			wide = maxf(wide, (ln.node as Control).size.x)
		check(wide <= m.chat._clip.size.x + 0.5, "%s: its lines wrap inside it (%.0f / %.0f)" % [tag, wide, m.chat._clip.size.x])
		# the interactor's prompt over the bars
		var it := player.interactor
		var top: float = (rects["renown"] as Rect2).position.y
		var lb := _line_box(it._label)
		var mb := _line_box(it._more)
		check(it.prompt_lift == ClassicFrames.PROMPT_LIFT and lb.end.y <= top and mb.end.y <= top and lb.end.y <= mb.position.y + 1.0,
				"%s: the prompt (%.0f) and its Hold E line (%.0f) end over the renown bar (%.0f)" % [tag, lb.end.y, mb.end.y, top])
	root.size = Vector2i(1600, 900)
	await settle(3)


# --- the layers ------------------------------------------------------------------------------------------------------

func _test_layers() -> void:
	var hl := hud.layer
	check(story != null and story.hud != null and story.hud.layer > hl, "the story's cards over the HUD (%d > %d)" % [story.hud.layer if story and story.hud else -1, hl])
	# (a test run has no death rule nor pause menu, as a game does: FrontierLevel; one each for the look, then gone)
	var death := current_scene.get_node_or_null("Death")
	var own_death := death == null
	if own_death:
		var dr := DeathRule.new()
		dr.player = player
		current_scene.add_child(dr)
		death = dr
	var dl: Variant = death.get("_layer")
	check(dl is CanvasLayer and (dl as CanvasLayer).layer > hl, "the death screen over the HUD (%d)" % ((dl as CanvasLayer).layer if dl is CanvasLayer else -1))
	if own_death:
		death.queue_free()
	var pm := current_scene.find_child("PauseMenu", false, false) as CanvasLayer
	var own_pm := pm == null
	if own_pm:
		pm = PauseMenu.install(current_scene, player)
	check(pm != null and pm.layer > hl, "the pause menu over the HUD (%d)" % (pm.layer if pm else -1))
	if own_pm:
		pm.queue_free()
	await settle(2)
	var s := InventoryScreen.open_for(player, "gear")
	await settle(3)
	check(is_instance_valid(s) and s.layer > hl, "the Tab screen over the HUD (%d)" % s.layer)
	s.close()
	await settle(3)
	paused = false
	StoryDialogue.open(self, "rumours", func(_o: String) -> void: pass)
	await settle(3)
	var dg := StoryDialogue.find(self)
	check(dg != null and dg.layer > hl, "the dialogue over the HUD (%d)" % (dg.layer if dg else -1))
	await settle(10)
	check(fr.talking and not fr.action_bar.visible and not fr.renown.visible and not m.chat.visible and fr.player_frame.visible
			and m.minimap.visible, "a talk: its box has the bottom (the action bar, the renown bar and the chat away)")
	if dg != null:
		dg._finish("")
	await settle(30)
	paused = false
	await settle(10)
	check(not fr.talking and fr.action_bar.visible and fr.renown.visible and m.chat.visible, "the talk over: they are back")


# --- the command mode ------------------------------------------------------------------------------------------------

func _test_command() -> void:
	var r := player.rts
	if r == null:
		check(false, "the player has the command mode (RtsMode)")
		return
	r.set_active(true)
	await settle(3)
	check(r.active and not fr.visible, "the command mode: the frames step aside")
	r.set_active(false)
	await settle(3)
	check(not r.active and fr.visible, "out of it: the frames again")


# --- the Settings row ------------------------------------------------------------------------------------------------

func _test_switch() -> void:
	var had := FileAccess.file_exists(GameSettings.PATH)
	var before := FileAccess.get_file_as_string(GameSettings.PATH) if had else ""
	GameSettings.set_value("hud", "style", "classic")
	var row := GameSettings.hud_style_row(player)
	root.add_child(row)
	var btn := row.get_node(^"Style") as Button
	check(btn != null and btn.text == "Classic", "the Settings row: HUD style  %s" % (btn.text if btn else "?"))
	btn.pressed.emit()
	await settle(3)
	var vit := hud._root.get_node(^"Vitals") as Control
	var compass := hud._root.get_node(^"Compass") as Control
	check(hud.classic == null and HudClassicMap.find(hud) == null, "Minimal: the classic parts off at once")
	check(vit.visible and compass.visible and hud.toasts_shown, "the vitals, the compass and the toasts back")
	check(story == null or story.hud == null or not story.hud.tracker_shown, "StoryHUD's mission lines back")
	check(player.interactor.prompt_lift == 0.0, "the prompt at its old place")
	check(btn.text == "Minimal" and String(GameSettings.get_value("hud", "style")) == "minimal", "kept: minimal")
	var lst := 0
	for n in get_nodes_in_group("hit_listeners"):
		if n is ClassicFrames:
			lst += 1
	check(lst == 0, "no classic frames left listening for hits (%d)" % lst)
	btn.pressed.emit()
	await settle(3)
	fr = hud.classic
	m = HudClassicMap.find(hud)
	check(fr != null and m != null and not vit.visible and not compass.visible and not hud.toasts_shown, "Classic: on again")
	check(story == null or story.hud == null or story.hud.tracker_shown, "the tracker has the mission again")
	await settle(70)                                 # (a second: the slow look)
	check(player.interactor.prompt_lift == ClassicFrames.PROMPT_LIFT, "the prompt up over the bars again")
	check(btn.text == "Classic" and String(GameSettings.get_value("hud", "style")) == "classic", "kept: classic")
	row.queue_free()
	if had:
		var f := FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
		f.store_string(before)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))


func _end() -> void:
	if fails.is_empty():
		print("HUD CLASSIC STYLE TEST OK (%d checks)" % checks)
	else:
		print("HUD CLASSIC STYLE TEST FAILED %d/%d: %s" % [fails.size(), checks, "; ".join(fails)])
	quit(0 if fails.is_empty() else 1)
