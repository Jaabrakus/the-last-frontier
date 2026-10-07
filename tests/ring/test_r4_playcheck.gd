extends SceneTree
## Round 4's play check (the merge's; the owner's "do what you think would make a viral round 4" and "simple like runescape but
## hard to master like runescape"): the round's pieces met the way a player meets them, from the main menu, under the default
## (% ring, lives) rules:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_r4_playcheck.gd -- pc_el=earth [pc_foe=water]
##   a new player  a fresh settings file: the Controls preset's default is Basic (MatchSetup._controls_default; a script run
##                 reads Full unless asked, so the menu's Controls row steps it to Basic as a new player's game has it), the
##                 scheme row hidden under Basic, the preset kept in the file at once
##   the match     Begin from the sport's panel (one game, 3 lives): the player's RingAssist active and the strip Basic's (no Q
##                 line, Basic's help line); three falls of the foe, each a real launch of the player's (BendKnock, as the
##                 replay test does): every fall gets the KO splash (RingMoment.falls) and the Splash Cam's replay (the
##                 setting's default, Every fall: RingReplay.force on, as a script run gets none otherwise), the tree held
##                 through it and the match exactly as it was after it (places, %, lives, the lock, the camera); the game's last
##                 fall gets the slow beat (time_scale down to the moment's slow_scale and back to 1); no game or match screen
##                 while a replay plays; the match screen after the last replay with its highlight cards; a SPLASH! callout
##   back          the match screen's Main menu row; Controls stepped to Full (kept; the scheme row back)
##   the Basics    Basic again, the first-launch offer's "Learn the basics": a practice with the lessons, every lesson on the
##                 list the Basics track's, the first card up, no round's end
## In-test watchdog LIMIT_S; seed(1750); MatchSetup._aim_help pinned; GameSettings.path its own. Last line "R4 PLAYCHECK
## PASSED" or "R4 PLAYCHECK FAILED"; exit 0 only on a pass.

const NAME := "R4 PLAYCHECK"
const LIMIT_S := 400.0
const OWN_CFG := "user://r4_playcheck_test.cfg"

var checks := 0
var fails: Array[String] = []
var el := "earth"
var foe_el := ""
var m: MainMenu
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var rp: RingReplay
var kos: Array = []
var replays := 0
var resumed_exact := 0
var screen_during_replay := 0
var lowest_ts := 1.0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("  (watchdog: phase %s)" % [mode.phase if mode != null and is_instance_valid(mode) else "-"])
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var v := kv.get_slice("=", 1)
		match kv.get_slice("=", 0):
			"pc_el":
				el = v
			"pc_foe":
				foe_el = v
	if foe_el == "":
		var els: Array = Bending.ELEMENTS
		foe_el = String(els[(els.find(el) + 1) % els.size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup.reload_scheme()
	InputSetup.ensure()
	MainMenu.launch_hook = Callable()
	RingReplay.force = "on"                      # (the game's default, Every fall; a script run plays none unless asked)
	change_scene_to_file("res://scenes/main_menu.tscn")
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	RingReplay.force = ""
	RingMode.lessons_asked = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	MatchSetup.reload_scheme()
	print("METRIC r4pc_el=%s replays=%d resumed_exact=%d screen_frames_during_replay=%d lowest_time_scale=%.2f" % [el, replays,
			resumed_exact, screen_during_replay, lowest_ts])
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


## Waits on process frames (they run while the tree is held, as during a replay) until `cond`, at most `limit` s of frames.
func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await process_frame
		t += 1.0 / 60.0
	return INF


func _row(n: String) -> Button:
	return m._panel.find_child(n, true, false) as Button


func _step(n: String, done: Callable, most := 8) -> bool:
	var b := _row(n)
	if b == null:
		return false
	for i in most:
		if done.call():
			return true
		b.pressed.emit()
		await process_frame
	return done.call()


func _kept(key: String) -> String:
	var cf := ConfigFile.new()
	cf.load(GameSettings.file())
	return str(cf.get_value(MatchSetup.SECTION, key, ""))


func _run() -> void:
	for i in 6:
		await process_frame
	m = current_scene as MainMenu
	_expect(m != null, "the main menu")
	if m == null:
		return _end()
	await _new_player()
	await _menu_match()
	if await _into_ring():
		await _match()
	await _back_and_full()
	await _basics()
	_end()


# ---------------------------------------------------------------- a new player: Basic
func _new_player() -> void:
	_expect(MatchSetup._controls_default() == "basic" and _kept(MatchSetup.CONTROLS_KEY) == "",
			"a fresh settings file: the Controls preset's default is Basic (%s), nothing kept yet" % MatchSetup._controls_default())
	m._open_match()
	await process_frame
	var ctl := _row("Controls")
	_expect(ctl != null, "the sport's panel: its Controls row")
	if ctl == null:
		return
	ctl.pressed.emit()
	await process_frame
	_expect(_row("ControlsPreset") != null and await _step("ControlsPreset", func() -> bool: return MatchSetup.basic()),
			"Controls: the preset row steps to Basic (%s)" % MatchSetup.controls())
	await process_frame
	var sch := _row("Scheme")
	_expect(sch != null and not sch.visible and _kept(MatchSetup.CONTROLS_KEY) == "basic",
			"under Basic the scheme row is hidden and the preset kept at once ('%s')" % _kept(MatchSetup.CONTROLS_KEY))


func _menu_match() -> void:
	m._open_match()
	await process_frame
	(m._element_rows[el] as Button).pressed.emit()
	await process_frame
	_expect(MatchSetup.element == el, "the panel: %s chosen" % el)
	_expect(await _step("Opponent", func() -> bool: return MatchSetup.foe() == foe_el), "the panel: the opponent %s" % foe_el)
	MatchSetup.games_n = 1
	var begin := _row("Begin")
	_expect(begin != null, "the panel's Begin")
	if begin != null:
		begin.pressed.emit()
	_expect(MatchSetup.incoming and not MatchSetup.practice(), "Begin: a match asked for")


func _into_ring() -> bool:
	var t := await _until(func() -> bool: return current_scene is RingLevel and RingMode.find(self) != null, 60.0)
	_expect(t < INF, "the ring loaded from the menu")
	if t == INF:
		return false
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	ring = lvl.ring
	player = lvl.player
	rules = mode.rules
	await _until(func() -> bool: return not LoadingScreen.covering() and player.arena_element != "", 30.0)
	player.ignore_mouse_capture = true
	return true


# ---------------------------------------------------------------- the match
func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func _match() -> void:
	_expect(RingRules.stock_on() and mode.to_win == 1, "the default rules: the %% ring, lives, one game (%s, to_win %d)" % [
			RingRules.stock_on(), mode.to_win])
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 10.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 4.0)
	var a := RingAssist.of(player)
	var strip := lvl.find_child("BendStrip", true, false)
	if strip == null:
		for n in lvl.find_children("*", "", true, false):
			if n is BendStrip:
				strip = n
				break
	_expect(a != null and a.active(), "Basic: the player's RingAssist on and active")
	_expect(strip != null and (strip as BendStrip).basic_strip() and (strip as BendStrip).q_line() == "" and (strip as BendStrip).help_line() != "",
			"Basic: the strip is Basic's (no Q line; help \"%s\")" % ((strip as BendStrip).help_line() if strip != null else "-"))
	rp = RingReplay.find(self)
	_expect(rp != null and RingHighlights.find(self) != null and Callouts.find(self) != null and PhotoMode.find(self) != null
			and BendClash.find(self) != null, "RingMode installed the Splash Cam, the highlights, the callouts, photo mode and the clashes")
	if rp == null or foe() == null:
		return
	foe().held = true
	rules.ko.connect(func(b: Node3D, _by: Node, _p: float, _t: String, _l: int) -> void: kos.append(b))
	var said: Array = []
	var co := Callouts.find(self)
	var st := {}
	rp.started.connect(func(_c: RingReplay.Clip) -> void:
		replays += 1
		st["start"] = _state())
	rp.finished.connect(func(_s: bool) -> void:
		var e := _state()
		if st.has("start") and _same(st.start as Dictionary, e):
			resumed_exact += 1
		st.erase("start"))
	var moment_falls0 := RingMoment.current().falls if RingMoment.current() != null else 0
	await _ticks(int(RingReplay.num("replay_s", 3.5) * Engine.physics_ticks_per_second) + 30)
	for i in 3:
		await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null and not rules.is_away(foe()), 15.0)
		if mode.phase != "FIGHT":
			break
		await _launch_foe()
		var n0 := kos.size()
		var fell := await _until(func() -> bool: return kos.size() > n0, 8.0)
		_expect(fell < INF, "fall %d: the foe in the water" % (i + 1))
		if i == 2:
			# (the game's last fall: the slow beat, the time scale back after)
			var low := 1.0
			var tt := 0.0
			while tt < 1.6:
				low = minf(low, Engine.time_scale)
				await process_frame
				tt += 1.0 / 60.0
			lowest_ts = low
			_expect(low <= BendImpact.num("moment", "slow_scale", 0.35) + 0.02, "the last fall: the slow beat (time scale down to %.2f)" % low)
		var started := await _until(func() -> bool: return rp.is_playing(), 8.0)
		_expect(started < INF and paused, "fall %d: the Splash Cam's replay plays, the tree held" % (i + 1))
		while rp.is_playing():
			if (mode.round_screen as RoundScreen).is_open() or (mode.match_screen as MatchScreen).is_open():
				screen_during_replay += 1
			await process_frame
		await process_frame
		_expect(not paused and is_equal_approx(Engine.time_scale, 1.0), "fall %d: after the replay the match goes on (tree running, time scale %.2f)" % [
				i + 1, Engine.time_scale])
		if co != null:
			for c: Variant in Callouts.shown:
				said.append(str(c))
	_expect(RingMoment.current() != null and RingMoment.current().falls - moment_falls0 >= 3, "every fall got the KO splash (%d)" % [
			RingMoment.current().falls - moment_falls0 if RingMoment.current() != null else -1])
	_expect(replays == 3 and resumed_exact == 3, "three falls, three replays, the match exactly as it was after each (%d of %d)" % [resumed_exact, replays])
	_expect(screen_during_replay == 0, "no game or match screen while a replay plays (%d frames)" % screen_during_replay)
	print("  callouts said: %s" % [said])
	_expect(said.any(func(s: Variant) -> bool: return String(s).contains("SPLASH")), "a SPLASH! callout")
	var done := await _until(func() -> bool: return mode.phase == "DONE" and (mode.match_screen as MatchScreen).is_open(), 20.0)
	_expect(done < INF, "the match screen after the last replay (%s)" % mode.phase)
	var cards := (mode.match_screen as MatchScreen)._cards
	await process_frame
	_expect(cards != null and cards.visible and cards.shown.size() >= 1, "the highlight cards on the match screen (%d: %s)" % [
			cards.shown.size() if cards != null else -1, cards.shown if cards != null else []])


## A real launch of the player's on the foe from near the end: over the lip into the water (the replay test's way).
func _launch_foe() -> void:
	var f := foe()
	var kn := BendKnock.of(f)
	kn.reset()
	f.velocity = Vector3.ZERO
	var side := RingArena.side_sign(1 - mode.player_end) if mode.player_end in [0, 1] else 1.0
	f.global_position = ring.to_global(Vector3(side * (ring.half_l() - 2.5), ring.top() + 0.05, 0.0))
	player.global_position = ring.to_global(Vector3(side * (ring.half_l() - 7.0), ring.top() + 0.05, 1.0))
	await _ticks(10)
	rules.reset_pct(f, 120.0)
	var v := ring.global_basis * Vector3(16.0 * side, 7.0, 0.0)
	rules.launched.emit(f, v, 0.8, player, "stone_form/spike")
	kn.knock(Vector3.ZERO, player, {"_launch": {"v": v, "hitstun_s": 0.8, "tumble": true}})


func _state() -> Dictionary:
	var sc := SwayCaster.of(player)
	return {"p_xf": player.global_transform, "p_pct": rules.pct_of(player), "f_pct": rules.pct_of(foe()) if foe() != null else -1.0,
			"p_lives": rules.stocks_of(player), "f_lives": rules.stocks_of(foe()) if foe() != null else -1,
			"lock": [int(sc.state), sc.fill, sc.lock_s, sc.hold_t] if sc != null else [], "cam": player.camera.global_transform,
			"p_v": player.velocity, "phase": mode.phase}


func _same(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		if a[k] != b[k]:
			print("    differs: %s %s -> %s" % [k, str(a[k]), str(b[k])])
			return false
	return true


# ---------------------------------------------------------------- back at the menu: Full
func _back_and_full() -> void:
	if mode != null and is_instance_valid(mode):
		var mm := (mode.match_screen as MatchScreen)._items.find_child("MainMenu", false, false) as Button
		if mm != null:
			mm.pressed.emit()
	var back := await _until(func() -> bool: return current_scene is MainMenu, 30.0)
	_expect(back < INF, "the match screen's Main menu row: back at the menu")
	if back == INF:
		return
	for i in 6:
		await process_frame
	m = current_scene as MainMenu
	m._open_match()
	await process_frame
	var ctl := _row("Controls")
	if ctl != null:
		ctl.pressed.emit()
		await process_frame
	_expect(await _step("ControlsPreset", func() -> bool: return not MatchSetup.basic()), "Controls: stepped to Full")
	await process_frame
	var sch := _row("Scheme")
	_expect(MatchSetup.controls() == "full" and _kept(MatchSetup.CONTROLS_KEY) == "full" and sch != null and sch.visible,
			"Full kept ('%s'), the scheme row back" % _kept(MatchSetup.CONTROLS_KEY))


# ---------------------------------------------------------------- the Basics lessons
func _basics() -> void:
	if not (current_scene is MainMenu):
		return
	MatchSetup.set_controls("basic")
	m._offer_basics()
	await process_frame
	var go := m._panel.find_child("Basics", true, false) as Button
	_expect(go != null and m._panel.find_child("NotNow", true, false) != null, "the first-launch offer: Learn the basics / Not now")
	if go == null:
		return
	go.pressed.emit()
	if not await _into_ring():
		return
	var up := await _until(func() -> bool: return mode.phase == "FIGHT" and RingLessons.find(self) != null, 20.0)
	var rl := RingLessons.find(self)
	_expect(up < INF and mode.practice and rl != null, "Learn the basics: a practice with the lessons (%s)" % [mode.phase])
	if rl == null:
		return
	await _until(func() -> bool: return not rl.list.is_empty() and rl.at >= 0, 10.0)
	var all_basics := not rl.list.is_empty()
	for l: Variant in rl.list:
		all_basics = all_basics and String((l as Dictionary).get("track", "")) == "basics"
	_expect(all_basics and rl.at >= 0 and rl.card != null and rl.card.visible,
			"the Basics track's %d lessons, the first card up (%s)" % [rl.list.size(), String((rl.list[maxi(rl.at, 0)] as Dictionary).get("title", "")) if not rl.list.is_empty() else "-"])
	var overs := [0]
	mode.round_over.connect(func(_r: String, _w: String) -> void: overs[0] += 1)
	await _ticks(int(5.0 * Engine.physics_ticks_per_second))
	_expect(overs[0] == 0 and mode.phase == "FIGHT", "the practice runs on: no round's end")
