extends SceneTree
## UI audit capture (read-only on the game): screenshots of the menus and the ring HUD as a player meets them, from the
## main menu, the way tests/ring/test_r4_playcheck.gd drives a match. Needs a window (not --headless):
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/capture_ui.gd -- out=DIR part=menu|match|practice [el=earth] [controls=basic|full] [tag=1600]
## Each shot: DIR/<tag>_<nn>_<name>.png and DIR/<tag>_<nn>_<name>.json (every visible text control: rect, font size, font,
## text; plus the overlaps between visible text rects). GameSettings.path is its own file (deleted after); the player's
## user://how_to.cfg is restored byte for byte at the end (FirstHints marks its topics seen; CaptureKit.keep keeps the original
## on disk, so a run the timeout killed is healed by the next run).

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")

const LIMIT_S := 280.0
const OWN_CFG := "user://ui_audit_settings.cfg"
const HOWTO := "user://how_to.cfg"

var out := ""
var part := "menu"
var el := "earth"
var controls := "basic"
var tag := "1600"
var n := 0
var m: MainMenu
var lvl: RingLevel
var mode: RingMode
var player: FrontierPlayer
var kos: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var v := kv.get_slice("=", 1)
		match kv.get_slice("=", 0):
			"out": out = v
			"part": part = v
			"el": el = v
			"controls": controls = v
			"tag": tag = v
	if not CaptureKit.begin(self, "capture_ui", out, true):
		return
	CaptureKit.keep([HOWTO])
	seed(1750)
	MatchSetup._aim_help = "strong"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup.reload_scheme()
	InputSetup.ensure()
	MatchSetup.set_controls(controls)
	MainMenu.launch_hook = Callable()
	MainMenu._look_offered = true                # (never the character creator: no first-press offer of it either)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("UI AUDIT watchdog at shot %d (phase %s, paused %s, time_scale %.2f, scene %s, covering %s, drawn %d, processed %d)" % [n,
				mode.phase if mode != null and is_instance_valid(mode) else "-", paused, Engine.time_scale,
				current_scene.name if current_scene != null else "-", LoadingScreen.covering(), Engine.get_frames_drawn(),
				Engine.get_process_frames()])
		_end(2))
	print("UI AUDIT part=%s el=%s controls=%s window=%s" % [part, el, controls, DisplayServer.window_get_size()])
	process_frame.connect(_watch_window)
	change_scene_to_file("res://scenes/main_menu.tscn")
	_run.call_deferred()


func _end(code := 0) -> void:
	Engine.time_scale = 1.0
	paused = false
	RingReplay.force = ""
	FirstHints.force = false
	RingMode.lessons_asked = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	CaptureKit.restore([HOWTO])
	print("UI AUDIT DONE shots=%d code=%d" % [n, code])
	quit(code)


## The window's mode and focus as they change (a window minimized from outside draws no frame while the game is paused:
## the shots wait for one, and the log says why).
var _win_was := ""


func _watch_window() -> void:
	var now := "mode %d focused %s mouse %d" % [DisplayServer.window_get_mode(), DisplayServer.window_is_focused(), Input.mouse_mode]
	if now != _win_was:
		print("UI AUDIT window %s (was %s) t=%.2f shot %d paused %s drawn %d" % [now, _win_was, Time.get_ticks_msec() / 1000.0, n,
				paused, Engine.get_frames_drawn()])
		_win_was = now


func _frames(k: int) -> void:
	await CaptureKit.frames(self, k)


func _secs(s: float) -> void:
	await CaptureKit.secs(self, s)


func _until(cond: Callable, limit: float) -> float:
	return await CaptureKit.until(self, cond, limit)


# ---------------------------------------------------------------- the shot and its text dump
## `extra`: a shot the audit's before set has no match for, named "<tag>_x_<name>" so the numbered ones keep its names.
func shot(name: String, extra := false) -> void:
	# (a frame drawn first; none within 1.5 s: the frame is drawn by hand, and the window's state said)
	if not await CaptureKit.drawn(self):
		# (a window covered or on a sleeping screen is not drawn by the system: drawn by hand)
		print("UI AUDIT no frame drawn for 1.5 s before %s (drawn %d, processed %d, window mode %d, focused %s, paused %s): drawn by hand"
				% [name, Engine.get_frames_drawn(), Engine.get_process_frames(), DisplayServer.window_get_mode(),
				DisplayServer.window_is_focused(), paused])
	if not extra:
		n += 1
	var base := ("%s/%s_x_%s" % [out, tag, name]) if extra else ("%s/%s_%02d_%s" % [out, tag, n, name])
	var img := root.get_texture().get_image()
	img.save_png(base + ".png")
	var items := CaptureKit.text_dump(root, root.get_visible_rect(), true)
	var overlaps := []
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: Dictionary = items[i]
			var b: Dictionary = items[j]
			var ra := Rect2(a.x, a.y, a.w, a.h)
			var rb := Rect2(b.x, b.y, b.w, b.h)
			if ra.intersects(rb) and not a.path.begins_with(b.path) and not b.path.begins_with(a.path):
				var x := ra.intersection(rb)
				if x.get_area() > 40.0:
					overlaps.append({"a": "%s '%s'" % [a.path.get_file(), String(a.text).left(40)],
							"b": "%s '%s'" % [b.path.get_file(), String(b.text).left(40)], "px": int(x.get_area())})
	var f := FileAccess.open(base + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"shot": name, "size": [img.get_width(), img.get_height()], "texts": items,
			"overlaps": overlaps}, " "))
	f.close()
	print("shot %s (%dx%d) texts=%d overlaps=%d t=%.1fs fps=%d" % [base.get_file(), img.get_width(), img.get_height(), items.size(),
			overlaps.size(), Time.get_ticks_msec() / 1000.0, Engine.get_frames_per_second()])


# ---------------------------------------------------------------- the run
func _run() -> void:
	await _frames(8)
	m = current_scene as MainMenu
	if m == null:
		print("UI AUDIT: no main menu")
		return _end(1)
	match part:
		"menu":
			await _menu()
		"match":
			await _match_part(false)
		"falls":
			await _match_part(true)
		"practice":
			await _practice_part()
	_end(0)


func _row(nm: String) -> Button:
	return m._panel.find_child(nm, true, false) as Button


# ---------------------------------------------------------------- the menus and the loading screen (never the creator)
func _menu() -> void:
	await _secs(1.5)
	await shot("menu_main")
	m._offer_basics()
	await _frames(4)
	await shot("menu_start_here")
	MainMenu._look_offered = true
	m._open_match()
	await _frames(4)
	await shot("menu_match_panel")
	var wr := m._element_rows.get("water") as Button
	if wr != null:
		wr.grab_focus()
		await _frames(3)
		await shot("menu_match_water_focus")
	m._open_controls()
	await _frames(4)
	await shot("menu_controls")
	m._open_practice()
	await _frames(4)
	await shot("menu_practice")
	m._open_settings()
	await _frames(4)
	await shot("menu_settings")
	m._open_credits()
	await _frames(4)
	await shot("menu_credits")
	m._close_panel()
	await _frames(2)
	# (the character creator is never opened here: the owner does not want it popping up. Its three shots' numbers are
	# skipped so the loading screen's keep the names of the audit's before shots.)
	n += 3
	paused = false
	# the pause menu of the open world is not reachable from the Tidebreak menu; the loading screen into the ring:
	m = current_scene as MainMenu
	m._open_match()
	await _frames(3)
	MatchSetup.games_n = 1
	(_row("Begin") as Button).pressed.emit()
	await _secs(0.4)
	await shot("loading_early")
	await _secs(1.6)
	await shot("loading_mid")
	var t := await _until(func() -> bool: return current_scene is RingLevel and RingMode.find(self) != null, 60.0)
	if t < INF:
		await _secs(0.5)
		if LoadingScreen.covering():
			await shot("loading_late")


# ---------------------------------------------------------------- the match: HUD, pause, round and match screens
func _into_ring() -> bool:
	var t := await _until(func() -> bool: return current_scene is RingLevel and RingMode.find(self) != null, 60.0)
	print("UI AUDIT into ring: scene after %.1f s" % t)
	if t == INF:
		print("UI AUDIT: the ring never loaded")
		return false
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	player = lvl.player
	var t2 := await _until(func() -> bool: return not LoadingScreen.covering() and player.arena_element != "", 30.0)
	print("UI AUDIT into ring: uncovered after %.1f s (element '%s')" % [t2, player.arena_element])
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func _press(action: StringName, hold_s: float) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _secs(hold_s)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)


func _match_part(falls: bool) -> void:
	# the player's own first match: a quick match from Start here's "Play an easy match" has FirstHints; this is the
	# Tidebreak panel's Begin (best of 3 games so a round screen shows), with FirstHints asked for as a new player sees them
	FirstHints.force = true
	MainMenu._look_offered = true
	m._open_match()
	await _frames(3)
	(m._element_rows[el] as Button).pressed.emit()
	MatchSetup.games_n = 3
	MatchSetup.quick = true
	RingReplay.force = "on" if falls else "off"
	var begin := _row("Begin")
	begin.pressed.emit()
	MatchSetup.quick = true
	MatchSetup.games_n = 3
	if not await _into_ring():
		return
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 10.0)
	if falls:
		mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
		await _until(func() -> bool: return mode.phase == "FIGHT", 4.0)
		await _falls()
		return
	await _secs(0.6)
	await shot("ring_countdown")
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 4.0)
	await _secs(0.4)
	await shot("ring_fight_start")
	# F1's help
	var hud := player.hud as FrontierHUD
	if hud != null and hud._help_box != null:
		hud._help_label.text = hud.help_text()
		hud._help_box.visible = true
		await _frames(3)
		await shot("ring_f1_help")
		hud._help_box.visible = false
	# a readied move and the aim held
	await _press(&"weapon_1", 0.1)
	await _frames(4)
	var e := InputEventAction.new()
	e.action = &"aim"
	e.pressed = true
	Input.parse_input_event(e)
	await _secs(0.5)
	await shot("ring_aiming_strike")
	var r := InputEventAction.new()
	r.action = &"aim"
	r.pressed = false
	Input.parse_input_event(r)
	# mid-fight: the bot fights for a while
	await _secs(7.0)
	await shot("ring_midfight_a")
	await _secs(4.0)
	await shot("ring_midfight_b")
	# the pause (Esc) menu and its panels
	var menu := mode.menu as RingMenu
	if menu != null:
		menu.open()
		await _frames(4)
		await shot("ring_pause")
		menu._controls()
		await _frames(4)
		await shot("ring_pause_controls")
		menu._settings()
		await _frames(4)
		await shot("ring_pause_settings")
		menu.close()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _frames(3)
	# photo mode
	print("UI AUDIT photo mode t=%.1f" % (Time.get_ticks_msec() / 1000.0))
	var pm := PhotoMode.find(self)
	if pm != null and pm.enter():
		await _frames(4)
		await shot("ring_photo_mode")
		pm.leave()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _frames(3)
	# the Esc menu's Match setup and Options panels (after the audit's shots, so their numbers stay as they were)
	if menu != null and menu.has_method("setup_rows"):
		menu.open()
		await _frames(2)
		menu.setup_rows()
		await _frames(4)
		await shot("ring_pause_setup")
		menu.option_rows()
		await _frames(4)
		await shot("ring_pause_options")
		menu.close()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _frames(3)
		# (the HUD the menu put away, back as it closed)
		await shot("ring_after_menu", true)


func _falls() -> void:
	# falls: the first with the KO splash, the callout and the replay; then the rest without replays
	if foe() == null:
		return
	foe().held = true
	mode.rules.ko.connect(func(b: Node3D, _by: Node, _p: float, _t: String, _l: int) -> void: kos.append(b))
	var rp := RingReplay.find(self)
	var next_game := false
	for i in 6:
		var w := await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null and not mode.rules.is_away(foe()), 20.0)
		if w == INF:
			# a round's pause: the round screen
			if (mode.round_screen as RoundScreen).is_open():
				await shot("round_screen")
				mode.phase_t = 999.0
				next_game = true
			w = await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null and not mode.rules.is_away(foe()), 20.0)
			if w == INF:
				break
		if next_game:
			# (the second game's HUD: the round screen gone, the HUD back, the first game's key hints gone)
			next_game = false
			await _secs(0.5)
			await shot("ring_next_game", true)
		if foe() != null:
			foe().held = true
		await _launch_foe()
		var n0 := kos.size()
		await _until(func() -> bool: return kos.size() > n0, 8.0)
		if i == 0:
			await _secs(0.25)
			await shot("ring_ko_splash")
			if rp != null:
				await _until(func() -> bool: return rp.is_playing(), 8.0)
				await _secs(0.8)
				await shot("ring_replay")
				RingReplay.force = "off"
				while rp.is_playing():
					await process_frame
				await _secs(1.5)
				await shot("ring_after_fall")
		else:
			RingReplay.force = "off"
			while rp != null and rp.is_playing():
				await process_frame
		if i == 2:
			var ok := await _until(func() -> bool: return (mode.round_screen as RoundScreen).is_open(), 12.0)
			if ok < INF:
				await _secs(0.5)
				await shot("round_screen")
				mode.phase_t = 999.0
				next_game = true
	var done := await _until(func() -> bool: return mode.phase == "DONE" and (mode.match_screen as MatchScreen).is_open(), 25.0)
	if done < INF:
		await _secs(1.0)
		await shot("match_screen")
	else:
		print("UI AUDIT: no match screen (phase %s)" % mode.phase)


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
	mode.rules.reset_pct(f, 120.0)
	var v := ring.global_basis * Vector3(16.0 * side, 7.0, 0.0)
	mode.rules.launched.emit(f, v, 0.8, player, "stone_form/spike")
	kn.knock(Vector3.ZERO, player, {"_launch": {"v": v, "hitstun_s": 0.8, "tumble": true}})


# ---------------------------------------------------------------- practice and the lessons, and the first-match hints
func _practice_part() -> void:
	MainMenu._look_offered = true
	m._open_practice()
	await _frames(3)
	MatchSetup.dummy = "throw" if "throw" in MatchSetup.dummy_ways() else MatchSetup.dummy
	var begin := _row("Begin")
	begin.pressed.emit()
	print("UI AUDIT practice begin t=%.1f" % (Time.get_ticks_msec() / 1000.0))
	if not await _into_ring():
		return
	print("UI AUDIT practice in ring t=%.1f phase %s paused %s" % [Time.get_ticks_msec() / 1000.0, mode.phase, paused])
	await _until(func() -> bool: return mode.phase == "FIGHT", 12.0)
	print("UI AUDIT practice phase %s t=%.1f" % [mode.phase, Time.get_ticks_msec() / 1000.0])
	await _secs(6.0)
	await shot("practice_hud")
	var menu := mode.menu as RingMenu
	if menu != null:
		menu.open()
		await _frames(4)
		await shot("practice_pause")
		if menu.has_method("practice_rows"):
			menu.practice_rows()
			await _frames(4)
			await shot("practice_pause_rows")
		menu.to_menu()
	else:
		change_scene_to_file("res://scenes/main_menu.tscn")
	var back := await _until(func() -> bool: return current_scene is MainMenu, 30.0)
	if back == INF:
		return
	await _frames(8)
	paused = false
	m = current_scene as MainMenu
	# the lessons (Start here: Learn the basics)
	m._offer_basics()
	await _frames(3)
	var go := m._panel.find_child("Basics", true, false) as Button
	if go == null:
		return
	go.pressed.emit()
	if not await _into_ring():
		return
	var up := await _until(func() -> bool: return mode.phase == "FIGHT" and RingLessons.find(self) != null, 20.0)
	if up < INF:
		await _secs(2.0)
		await shot("lessons_card")
		await _secs(5.0)
		await shot("lessons_card_later")
	(mode.menu as RingMenu).to_menu()
	back = await _until(func() -> bool: return current_scene is MainMenu, 30.0)
	if back == INF:
		return
	await _frames(8)
	paused = false
	m = current_scene as MainMenu
	# a new player's first easy match: the key hints (FirstHints) at the top left
	FirstHints.force = true
	m._offer_basics()
	await _frames(3)
	var easy := m._panel.find_child("EasyMatch", true, false) as Button
	if easy == null:
		return
	easy.pressed.emit()
	if not await _into_ring():
		return
	await _until(func() -> bool: return mode.phase == "COUNTDOWN", 10.0)
	await _secs(0.8)
	await shot("first_match_countdown")
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 4.0)
	await _secs(2.0)
	await shot("first_match_hints")
	await _secs(6.0)
	await shot("first_match_fight")
