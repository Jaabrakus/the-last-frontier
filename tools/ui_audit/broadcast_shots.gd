extends SceneTree
## The broadcast menus' AFTER shots (the owner chose the "Arena broadcast" style, 2026-10-10): the main menu (the lobby), the
## match setup with each element chosen, the ring's Esc menu with its two sub-panels, and the match-end board, as a player
## meets them in the game itself. Needs a window (not --headless); never opens the character creator.
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/broadcast_shots.gd -- part=menu|ring|all [out=DIR] [tag=] [px=1600x900] [els=fire,earth,water,air] [format=4v4]
## part=practice plays a practice from the menu's Practice screen and takes the Esc menu there (pause_practice.png and its panel).
## part=element runs the first-run path of the menu with a stand-in for the character creator (MainMenu.creator_hook: the creator is
## never opened, a made-up look is saved as its Accept): the "Choose your element" step (element.png with Fire picked,
## element_air.png after the key 4, element_720 as the tag has it), Enter keeping it and the match setup after it, then the
## Character Advancement window opened from the lobby's row (main_class.png), from the match setup's link (match_class.png); part=ring
## adds the Esc menu's Class & talents row focused (pause_class_row.png) and the window over the menu (pause_class.png; falls=off stops it after the Esc menu, without the falls and the boards).
## part=loading draws the loading screen alone (LoadingScreen.preview) in a SubViewport of `px`: loading.png into the ring part of the
## way, loading_start.png at its start, loading_world.png on the way into the open world (a painting); its .json measures the type
## floor as every shot's does. part=round draws the between-games plate over the ring still with a stand-in for the match (round.png a
## game of yours in the % match, round_loss.png the foe's, round_zones.png a drawn round of the zones, round_decided.png the match
## decided): the real plate in a real match is part=ring's round.png.
## part=end draws the match-end board over the ring still with a stand-in for a decided match (end_stub.png, any `px`).
## part=menu draws the main menu's scene inside a SubViewport of `px` (so a window behind another one still renders, and any size
## can be taken); part=ring plays a real match in the window (the Esc menu and the board are layers over the ring), so that
## part needs the window drawn: --resolution as the shots' size, tag=_720 for the small window.
## Names follow the mock-ups: main.png (fire) / main_<element>.png, match.png (fire) / match_<element>.png, pause.png,
## pause_setup.png, pause_options.png, end.png; with `tag` appended before .png. Each shot also gets a .json of every visible text
## control: its rect, its design size and its size on screen (the audit's floor: 16 px at 1600 x 900, 14 px at 1280 x 720).
## The look is a made-up one (FighterWorld.look_override: the name "Rowan"): the shots never carry the owner's own character.
## GameSettings.path is its own file (deleted after); the player's user://how_to.cfg is restored byte for byte (CaptureKit.keep
## keeps the original on disk, so a run the timeout killed is healed by the next run).

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const LIMIT_S := 560.0
const OWN_CFG := "user://broadcast_shots.cfg"
const HOWTO := "user://how_to.cfg"
const OUT := "res://artifacts/ui_audit/after/broadcast"

var out := OUT
var part := "menu"
var tag := ""
var px := Vector2i(1600, 900)
var els: Array = ["fire", "earth", "water", "air"]
var with_falls := true           ## falls=off: part=ring stops after the Esc menu's shots (no falls, no round or match-end boards)
## format=: the match setup shown in that team format (MatchSetup.FORMATS).
var fmt_arg := ""
var vp: SubViewport
var n := 0
var m: MainMenu
var lvl: RingLevel
var mode: RingMode
var player: FrontierPlayer
## The test run's own look file and offered flag (AppearanceStore): put aside for the shots (the character's element is read from it),
## given back as they were.
var _look_stash := {}
var kos: Array = []
var stubs: Array = []


## The character creator's stand-in: only its closed(accepted) signal.
class StubCreator extends Node:
	signal closed(accepted: bool)


## A stand-in for RingMode, with what RoundScreen reads of it (the real plate in the real ring is part=ring's).
class RoundStub extends Node:
	signal phase_changed(ph: String)
	var practice := false
	var phase := "OVER"
	var phase_t := 1.8
	var round := 1
	var score := Vector2i(1, 0)
	var to_win := 2
	var element := "fire"
	var foe_element := "water"
	var last_result := "win"
	var last_why := "falls"
	var history: Array = []
	var rules: RingRules
	var is_stock := true
	var is_decided := false

	func stock() -> bool:
		return is_stock

	func decided() -> bool:
		return is_decided

	func foe_name() -> String:
		return MatchSetup.competitor(foe_element)

	func score_text() -> String:
		return "You %d  :  %d %s" % [score.x, score.y, foe_name()]

	func result_line() -> String:
		return ""


## A stand-in for a decided RingMode, with what MatchScreen reads of it (part=end: the board without playing a match; the board after a
## real match is part=ring's end.png). A best of 3 of the % ring, won 2 : 0, the last game's three falls.
class EndStub extends Node:
	signal phase_changed(ph: String)
	var practice := false
	var phase := "DONE"
	var winner := 0
	var score := Vector2i(2, 0)
	var element := "fire"
	var foe_element := "water"
	var to_win := 2
	var player: Node = null
	var history: Array = [{"round": 1, "result": "win", "why": "ringout", "at_s": 31.0, "lives": [3, 0]},
			{"round": 2, "result": "win", "why": "ringout", "at_s": 24.0, "lives": [3, 0]}]
	var falls: Array = []

	func _ready() -> void:
		player = self
		for f: Array in [[6.0, 143.0, "stone_form/spike"], [14.0, 145.0, "fire_blast/punch"], [22.0, 143.0, "fire_blast/punch"]]:
			falls.append({"game": 2, "at_s": f[0], "pct": f[1], "tag": f[2], "by": self, "who": null})

	func stock() -> bool:
		return true

	func foe_name() -> String:
		return MatchSetup.competitor(foe_element)

	func score_text() -> String:
		return "You %d  :  %d %s" % [score.x, score.y, foe_name()]

	func stock_tally(side: int) -> Dictionary:
		if side == 0:
			return {"falls_dealt": 6.0, "pct_dealt": 79.0, "best_pct": 9.0, "string_hits": 1, "catches": 0.0, "perfect_guards": 0.0, "edge_saves": 0.0}
		return {"falls_dealt": 0.0, "pct_dealt": 9.0, "best_pct": 149.0, "string_hits": 1}

	func match_tally(_side: int) -> Dictionary:
		return {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var v := kv.get_slice("=", 1)
		match kv.get_slice("=", 0):
			"out": out = v
			"part": part = v
			"tag": tag = v
			"px": px = Vector2i(int(v.get_slice("x", 0)), int(v.get_slice("x", 1)))
			"els": els = Array(v.split(",", false))
			"falls": with_falls = v != "off"
			"format": fmt_arg = v if v in MatchSetup.FORMATS else ""
	out = ProjectSettings.globalize_path(out)
	if not CaptureKit.begin(self, "broadcast_shots", out):
		return
	auto_accept_quit = false
	CaptureKit.keep([HOWTO])
	seed(1750)
	BroadcastUI.hover_focus = false              # (the owner's own pointer is over the window: it must not choose a row)
	MatchSetup._aim_help = "strong"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	if fmt_arg != "":
		MatchSetup.format = fmt_arg              # (the match card's format chips: kept in its own file, where the menu reads it)
		MatchSetup.save()
	MatchSetup.reload_scheme()
	InputSetup.ensure()
	MatchSetup.set_controls("full")
	MainMenu.launch_hook = Callable()
	MainMenu._look_offered = true                # (never the character creator: no first-press offer of it either)
	var look := AppearanceStore.default_look()
	look["name"] = "Rowan"
	FighterWorld.look_override = AppearanceStore.validate(look)
	for lp: String in [AppearanceStore.current_path(), AppearanceStore.offered_path()]:
		_look_stash[lp] = FileAccess.get_file_as_bytes(lp) if FileAccess.file_exists(lp) else null
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
	MainMenu.creator_hook = func(_first: bool) -> Object:       # (the character creator is never opened here)
		var sc := StubCreator.new()
		stubs.append(sc)
		return sc
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("BROADCAST SHOTS watchdog at shot %d" % n)
		_end(2))
	print("BROADCAST SHOTS part=%s tag=%s window=%s" % [part, tag, DisplayServer.window_get_size()])
	_run.call_deferred()


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_CLOSE_REQUEST:
		print("BROADCAST SHOTS a close request at %d ms: the run goes on" % Time.get_ticks_msec())


func _end(code := 0) -> void:
	Engine.time_scale = 1.0
	paused = false
	RingReplay.force = ""
	FirstHints.force = false
	RingMode.lessons_asked = false
	FighterWorld.look_override = {}
	MainMenu.creator_hook = Callable()
	MainMenu.offer_check_run = true
	for lp: String in _look_stash:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
		if _look_stash[lp] != null:
			var lf := FileAccess.open(lp, FileAccess.WRITE)
			if lf != null:
				lf.store_buffer(_look_stash[lp])
				lf.close()
	BroadcastUI.hover_focus = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	CaptureKit.restore([HOWTO])
	print("BROADCAST SHOTS DONE shots=%d code=%d" % [n, code])
	quit(code)


func _frames(k: int) -> void:
	await CaptureKit.frames(self, k)


func _secs(s: float) -> void:
	await CaptureKit.secs(self, s)


func _until(cond: Callable, limit: float) -> float:
	return await CaptureKit.until(self, cond, limit)


# ---------------------------------------------------------------- the shot and its text dump
## A shot of the window (`from` null) or of the SubViewport `from`.
func shot(name: String, from: SubViewport = null) -> void:
	var img: Image
	if from != null:
		for i in 4:
			await process_frame
			RenderingServer.force_draw(false)
		img = from.get_texture().get_image()
	else:
		await CaptureKit.drawn(self)               # (a window covered or on a sleeping screen is drawn by hand)
		img = root.get_texture().get_image()
	n += 1
	var base := "%s/%s%s" % [out, name, tag]
	img.save_png(base + ".png")
	var items := CaptureKit.text_dump(from if from != null else root, Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var small := 9999.0
	for it: Dictionary in items:
		small = minf(small, float(it.screen_px))
	var f := FileAccess.open(base + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"shot": name, "size": [img.get_width(), img.get_height()], "smallest_text_px": small, "texts": items}, " "))
	f.close()
	print("shot %s%s (%dx%d) texts=%d smallest on screen %.1f px" % [name, tag, img.get_width(), img.get_height(), items.size(), small])


# ---------------------------------------------------------------- the run
func _run() -> void:
	await _frames(4)
	match part:
		"menu":
			await _menu()
		"ring":
			await _ring()
		"practice":
			await _practice()
		"element":
			await _element()
		"loading":
			await _loading()
		"round":
			await _round_stub()
		"end":
			await _end_stub()
		"all":
			await _menu()
			await _element()
			await _loading()
			await _round_stub()
			await _ring()
			await _practice()
	_end(0)


func _setup_for(el: String) -> void:
	MatchSetup.element = el
	MatchSetup.foes = [{"fire": "water", "earth": "air", "water": "fire", "air": "earth"}[el]]
	MatchSetup.difficulty = "normal"
	MatchSetup.rules_choice = "stock"
	MatchSetup.games_n = 3
	MatchSetup.light = "noon"
	MatchSetup.save()


## The main menu scene inside a SubViewport of `px` (a fresh one each time).
func _fresh_menu(el: String) -> bool:
	_setup_for(el)
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


## The lobby and the match setup per element.
func _menu() -> void:
	for el: String in els:
		if not await _fresh_menu(el):
			print("BROADCAST SHOTS: no main menu")
			return
		# the figure is made after the first frames: wait for it and its fade
		await _until(func() -> bool: return m._fighter.modulate.a >= 0.99, 20.0)
		await _secs(1.2)
		await shot("main" if el == "fire" else "main_" + el, vp)
		if el == "fire":
			# a lower row focused: the rows below it move, the plate follows
			var cr := m._items.find_child("ClassTalents", true, false) as Button
			if cr != null:
				cr.grab_focus()
				await _frames(4)
				await shot("main_row5", vp)
			m._first_focus()
		m._open_match()
		await _secs(0.6)
		await _until(func() -> bool: return _cards_ready(), 25.0)
		await _secs(0.8)
		await shot("match" if el == "fire" else "match_" + el, vp)
		if el == "fire":
			var wr := m._element_rows.get("water") as Button
			if wr != null:
				wr.grab_focus()
				await _frames(4)
				await shot("match_focus_water", vp)
			# a chip focused (a keyboard or pad's way through the choices)
			var hard := m._panel.find_child("Difficulty", true, false) as BroadcastUI.Segments
			if hard != null:
				hard.chip(2).grab_focus()
				await _frames(4)
				await shot("match_chip_focus", vp)
				(m._element_rows["fire"] as Button).grab_focus()
			var zones := m._panel.find_child("Rules", true, false) as BroadcastUI.Segments
			if zones != null:
				zones.chip(1).pressed.emit()
				await _frames(4)
				await shot("match_zones", vp)
				zones.chip(0).pressed.emit()
				await _frames(2)
			m._open_practice()
			await _frames(5)
			await shot("practice", vp)
			m._open_settings()
			await _frames(5)
			await shot("settings", vp)
			m._offer_basics()
			await _frames(5)
			await shot("start_here", vp)
			m._close_panel()
			await _frames(3)


## The first-run path (the creator's stand-in), the element step and the advancement window opened from the menu.
func _element() -> void:
	for lp: String in [AppearanceStore.current_path(), AppearanceStore.offered_path()]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
	MainMenu.offer_check_run = false
	MainMenu._look_offered = false
	if not await _fresh_menu("fire"):
		print("BROADCAST SHOTS: no main menu")
		return
	await _until(func() -> bool: return m._fighter.modulate.a >= 0.99, 20.0)
	m._open_match()                               # (the first press of the sport: the creator's stand-in)
	await _frames(3)
	if stubs.is_empty():
		print("BROADCAST SHOTS: the creator was not offered")
		return
	# its Accept: the look saved as the creator saves it, then the step
	AppearanceStore.save_current(FighterWorld.look_override)
	(stubs.back() as StubCreator).closed.emit(true)
	await _frames(4)
	await _until(func() -> bool: return _cards_ready(), 40.0)
	await _secs(1.0)
	await shot("element", vp)
	var k4 := InputEventKey.new()
	k4.physical_keycode = KEY_4
	k4.keycode = KEY_4
	k4.pressed = true
	vp.push_input(k4)
	await _frames(4)
	await shot("element_air", vp)
	# Enter: kept in the character, the match setup after it
	m._confirm_element()
	await _frames(4)
	print("BROADCAST SHOTS the character's element: '%s' (the match element %s)" % [AppearanceStore.element(), MatchSetup.element])
	await _until(func() -> bool: return _cards_ready(), 25.0)
	await _secs(0.8)
	# the window from the match setup's link, then from the lobby's row
	var link := m._panel.find_child("ClassLink", true, false) as Button
	if link != null:
		link.grab_focus()
		link.pressed.emit()
		await _secs(1.0)
		await shot("match_class", vp)
		var w := m.find_children("*", "AdvancementWindow", false, false)
		if not w.is_empty():
			(w[0] as AdvancementWindow).close()
		await _frames(4)
	m._close_panel()
	await _frames(3)
	var row := m._items.find_child("ClassTalents", true, false) as Button
	if row != null:
		row.grab_focus()
		row.pressed.emit()
		await _secs(1.0)
		await shot("main_class", vp)
		var w2 := m.find_children("*", "AdvancementWindow", false, false)
		if not w2.is_empty():
			(w2[0] as AdvancementWindow).close()
		await _frames(4)
	_setup_for("fire")
	for lp: String in [AppearanceStore.current_path(), AppearanceStore.offered_path()]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
	MainMenu._look_offered = true


func _cards_ready() -> bool:
	if m == null or m._element_rows.is_empty():
		return false
	for el: String in m._element_rows:
		var b := m._element_rows[el] as Control
		if b == null or b.find_child("CardView", true, false) == null:
			return false
	return true


# ---------------------------------------------------------------- the loading screen and the between-games plate
func _fresh_vp() -> void:
	if vp != null:
		vp.queue_free()
		await process_frame
	vp = SubViewport.new()
	vp.size = px
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)


## The loading screen alone, the ring's way (its still, its caption and a tip), at its start and part of the way, and the open world's
## (a painting).
func _loading() -> void:
	MatchSetup.element = "fire"
	for k: Array in [["loading", LoadingScreen.RING_SCENE, 0.62, "Chalking the score"], ["loading_start", LoadingScreen.RING_SCENE, 0.06, ""],
			["loading_world", "res://scenes/main.tscn", 0.4, "Raising the valley"]]:
		await _fresh_vp()
		var ls := LoadingScreen.preview(vp, String(k[1]), float(k[2]), String(k[3]))
		await _secs(0.8)
		print("loading %s: picture '%s' tip '%s'" % [k[0], ls.picture, ls.tip])
		await shot(String(k[0]), vp)
		ls.queue_free()


## One round plate over the ring's still: the stand-in match and what it says.
func _round_plate(name: String, el: String, foe_el: String, res: String, why: String, stock: bool, score: Vector2i, rnd: int, decided := false) -> void:
	await _fresh_vp()
	var back := TextureRect.new()
	back.texture = load("res://assets/ui/tidebreak/deck.png") as Texture2D
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(back)
	var st := RoundStub.new()
	st.element = el
	st.foe_element = foe_el
	st.last_result = res
	st.last_why = why
	st.is_stock = stock
	st.score = score
	st.round = rnd
	st.is_decided = decided
	st.history = [{"tally": [{"casts": 9, "catches": 2, "knock_backs": 3}, {"casts": 7, "catches": 0, "knock_backs": 1}]}]
	st.rules = RingRules.new()
	st.rules.tally = [{"falls_dealt": 3.0, "pct_dealt": 139.0, "catches": 2.0}, {"falls_dealt": 1.0, "pct_dealt": 88.0, "catches": 0.0}]
	vp.add_child(st)
	var rs := RoundScreen.install(vp, st)
	await _frames(2)
	st.phase_changed.emit("OVER")
	await _secs(0.8)
	await shot(name, vp)
	rs.queue_free()
	st.queue_free()


func _round_stub() -> void:
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	await _round_plate("round", "fire", "water", "win", "falls", true, Vector2i(1, 0), 1)
	await _round_plate("round_loss", "earth", "air", "loss", "falls", true, Vector2i(0, 1), 1)
	await _round_plate("round_zones", "water", "fire", "draw", "time", false, Vector2i(1, 1), 2)
	await _round_plate("round_decided", "fire", "earth", "win", "territory", false, Vector2i(2, 0), 2, true)


## The match-end board over the ring's still with a stand-in for the decided match (end_stub.png): its layout at any `px`.
func _end_stub() -> void:
	_setup_for("fire")
	await _fresh_vp()
	var back := TextureRect.new()
	back.texture = load("res://assets/ui/tidebreak/deck.png") as Texture2D
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(back)
	var st := EndStub.new()
	vp.add_child(st)
	var ms := MatchScreen.install(vp, st)
	await _frames(2)
	ms.open()
	await _secs(1.2)
	await shot("end_stub", vp)
	ms.queue_free()
	st.queue_free()


# ---------------------------------------------------------------- the ring: Esc menu and the match's end
func _into_ring() -> bool:
	var t := await _until(func() -> bool: return current_scene is RingLevel and RingMode.find(self) != null, 60.0)
	print("BROADCAST SHOTS into ring: %.1f s" % t)
	if t == INF:
		return false
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	player = lvl.player
	var t2 := await _until(func() -> bool: return not LoadingScreen.covering() and player.arena_element != "", 30.0)
	print("BROADCAST SHOTS uncovered after %.1f s (element '%s')" % [t2, player.arena_element])
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true


## A practice from the menu's Practice screen: the Esc menu in it (the bug says what the dummy does, no score) and its panel.
func _practice() -> void:
	_setup_for(els[0])
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(10)
	m = current_scene as MainMenu
	if m == null:
		return
	await _secs(0.5)
	m._open_practice()
	await _frames(3)
	(m._panel.find_child("Begin", true, false) as Button).pressed.emit()
	if not await _into_ring():
		return
	await _secs(2.0)
	var menu := mode.menu as RingMenu
	if menu == null:
		return
	menu.open()
	await _frames(5)
	await shot("pause_practice")
	menu.practice_rows()
	await _frames(5)
	await shot("pause_practice_rows")
	menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func _ring() -> void:
	var el: String = els[0]
	_setup_for(el)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(10)
	m = current_scene as MainMenu
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
	if not await _into_ring():
		return
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 10.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 4.0)
	await _secs(2.0)
	var menu := mode.menu as RingMenu
	if menu != null:
		menu.open()
		await _frames(5)
		await shot("pause")
		menu.setup_rows()
		await _frames(5)
		await shot("pause_setup")
		menu.option_rows()
		await _frames(5)
		await shot("pause_options")
		menu.open()                             # (the panels shut again)
		menu._class_row.grab_focus()            # (its line: the changes apply from the next restart)
		await _frames(4)
		await shot("pause_class_row")
		menu.class_talents()                    # (the advancement window over the Esc menu)
		await _secs(1.0)
		await shot("pause_class")
		for cw in menu.find_children("*", "AdvancementWindow", false, false):
			(cw as AdvancementWindow).close()
		await _frames(3)
		menu.close()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _frames(3)
	if with_falls:
		await _falls()


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
				await shot("round")
				mode.phase_t = 999.0
			w = await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null and not mode.rules.is_away(foe()), 20.0)
			if w == INF:
				break
		if foe() != null:
			foe().held = true
		await _secs(5.0)                         # (the falls a few seconds apart, as a match has them)
		await _launch_foe()
		var n0 := kos.size()
		await _until(func() -> bool: return kos.size() > n0, 8.0)
		var rp := RingReplay.find(self)
		while rp != null and rp.is_playing():
			await process_frame
		if mode.phase == "OVER" or mode.phase == "DONE":
			var ok := await _until(func() -> bool: return (mode.round_screen as RoundScreen).is_open() or (mode.match_screen as MatchScreen).is_open(), 12.0)
			if ok < INF and (mode.round_screen as RoundScreen).is_open():
				await _secs(0.5)
				await shot("round")
				mode.phase_t = 999.0
	var done := await _until(func() -> bool: return mode.phase == "DONE" and (mode.match_screen as MatchScreen).is_open(), 25.0)
	if done < INF:
		await _secs(1.4)
		await shot("end")
	else:
		print("BROADCAST SHOTS: no match screen (phase %s)" % mode.phase)


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
	BendStatus.hurt(f, 1.0, f.global_position + Vector3.UP, Vector3.FORWARD, player, -1.0, {"tag": ["stone_form/spike", "earth_shove/push", "fire_blast/punch"][randi() % 3], "from": player.global_position})
	var v := ring.global_basis * Vector3(16.0 * side, 7.0, 0.0)
	mode.rules.launched.emit(f, v, 0.8, player, "stone_form/spike")
	kn.knock(Vector3.ZERO, player, {"_launch": {"v": v, "hitstun_s": 0.8, "tumble": true}})
