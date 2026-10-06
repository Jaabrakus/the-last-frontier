extends SceneTree
## Wave 3's play check: a Tidebreak match reached the way a player reaches it, from the main menu, and played to its end
## by the player's own input under one control scheme (MatchSetup.scheme; the owner, 2026-10-05: "still difficult for a
## human to switch spells" -> all three schemes as options), or a practice reached from the menu's Practice row:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_playcheck.gd -- pc_el=earth pc_scheme=direction
##         [pc_foe=water] [pc_round_s=40]
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_playcheck.gd -- pc_practice=throw [pc_el=earth] [pc_foe=earth]
## (pc_ args, not MatchSetup's own element= / foe= / scheme=, so the setup is what the menu's rows chose.)
##   the menu    scenes/main_menu.tscn; the sport's panel: the element's row, Opponent stepped to pc_foe, Rounds to best of
##               3, its Controls row and there "Other ways to pick moves" stepped to pc_scheme (round 2: the scheme is
##               chosen only there; kept at once in the test's own settings file), back to the panel, Begin: through the
##               LoadingScreen into scenes/ring.tscn (no launch hook)
##   the match   the player's casts made through the scheme's own input every CAST_S in the fight, aimed at the bot:
##               keys      a key pressed (Hotbar.select, 1-5 in turn), RMB held to the full lock and let go
##               direction SwayCaster.dir_override forward / back / side / none in turn, RMB
##               radial    the wheel held (RadialWheel.held_override), the mouse toward a move (pick_toward), let go: the
##                         move readied on its key, then RMB
##               first_moves  1-4 in turn (each key's first move only; it replaced simple, and pc_scheme=simple asks
##                         for it), RMB
##               the match reaches DONE (match_over once), the round screen shows in a round's pause, the match screen at
##               the end; its Main menu row goes back to the menu (MatchSetup.leave)
##   practice    the menu's Practice row: its panel's Dummy and It rows stepped to pc_foe / pc_practice, Begin practice:
##               the ring in practice (RingMode.practice, the dummy's way, the soft walls off), the clock counting up, no
##               round's end and no screen over 12 s, a throwing dummy casts at the player, the practice line shown
## In-test watchdog LIMIT_S. The last line "PLAYCHECK PASSED" or "PLAYCHECK FAILED"; exit 0 only on a pass.

const NAME := "PLAYCHECK"
const LIMIT_S := 400.0
const OWN_CFG := "user://playcheck_test.cfg"
const CAST_S := 1.6

var checks := 0
var fails: Array[String] = []
var el := "earth"
var foe_el := ""
var scheme := "keys"
var practice_way := ""
var round_s := 40.0
var m: MainMenu
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var c: SwayCaster
var casts: Array = []
var matches: Array = []
var round_screen_frames := 0
var rounds_over := 0
var _turn := 0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("  (watchdog: phase %s, round %s, score %s)" % [mode.phase if mode else "-", mode.round if mode else -1,
				mode.score if mode else "-"])
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
			"pc_scheme":
				scheme = String(MatchSetup.SCHEME_ALIASES.get(v, v))
			"pc_practice":
				practice_way = v
			"pc_round_s":
				if v.is_valid_float():
					round_s = float(v)
	if foe_el == "":
		var els: Array = Bending.ELEMENTS
		foe_el = el if practice_way != "" else String(els[(els.find(el) + 1) % els.size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup.reload_scheme()
	InputSetup.ensure()
	MainMenu.launch_hook = Callable()
	change_scene_to_file("res://scenes/main_menu.tscn")
	_run.call_deferred()


func _end() -> void:
	Input.action_release(&"aim")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	MatchSetup.reload_scheme()
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


func _secs(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


## The open panel's row named `n` (null when none).
func _row(n: String) -> Button:
	var b := m._panel.find_child(n, true, false)
	return b as Button


## Presses row `n` until `done` holds (at most `most` presses); whether it holds.
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


func _run() -> void:
	for i in 6:
		await process_frame
	m = current_scene as MainMenu
	_expect(m != null, "the main menu")
	if m == null:
		return _end()
	if practice_way != "":
		await _menu_practice()
	else:
		await _menu_match()
	# into the ring through the loading screen
	var t := await _until(func() -> bool: return current_scene is RingLevel and RingMode.find(self) != null, 60.0)
	_expect(t < INF, "the ring loaded from the menu (%.1f s)" % t)
	if t == INF:
		return _end()
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	player = lvl.player
	await _until(func() -> bool: return not LoadingScreen.covering() and player.arena_element != "", 30.0)
	player.ignore_mouse_capture = true
	c = SwayCaster.of(player)
	_expect(c != null and player.arena_element == el and mode.foe_element == foe_el,
			"the menu's setup in the ring: %s against %s (%s, %s)" % [el, foe_el, player.arena_element, mode.foe_element])
	if c == null:
		return _end()
	c.cast.connect(func(mv: String, _t: Node3D) -> void: casts.append([mv, c.mode_of(mv)]))
	if practice_way != "":
		await _practice()
	else:
		await _match()
	_end()


# ---------------------------------------------------------------- the menu
func _menu_match() -> void:
	m._open_match()
	await process_frame
	(m._element_rows[el] as Button).pressed.emit()
	await process_frame
	_expect(MatchSetup.element == el, "the panel: %s chosen" % el)
	_expect(await _step("Opponent", func() -> bool: return MatchSetup.foe() == foe_el), "the panel: the opponent %s" % foe_el)
	_expect(await _step("Rounds", func() -> bool: return MatchSetup.rounds_to_win == 2), "the panel: best of 3")
	# (round 2: the scheme is picked under Controls, "Other ways to pick moves"; the keys by default)
	var ctl := _row("Controls")
	_expect(ctl != null, "the panel's Controls row")
	if ctl != null:
		ctl.pressed.emit()
		await process_frame
	_expect(_row("Scheme") != null and await _step("Scheme", func() -> bool: return MatchSetup.scheme() == scheme),
			"Controls, other ways to pick moves: the %s scheme (%s)" % [scheme, MatchSetup.scheme_row()])
	m._open_match()                              # (back to the sport's panel: its picks are MatchSetup's, kept)
	await process_frame
	MatchSetup.round_s = round_s                 # (the panel has no round length: a short one for the check)
	var begin := _row("Begin")
	_expect(begin != null, "the panel's Begin")
	if begin != null:
		begin.pressed.emit()
	var cf := ConfigFile.new()                   # (the scheme is not among GameSettings.DEFAULTS: read from the file)
	cf.load(GameSettings.file())
	var kept := str(cf.get_value(MatchSetup.SECTION, MatchSetup.SCHEME_KEY, ""))
	_expect(MatchSetup.incoming and not MatchSetup.practice() and (kept == scheme or (kept == "" and scheme == "keys")),
			"Begin: a match asked for, the scheme kept in the settings ('%s'; nothing kept is the keys)" % kept)


func _menu_practice() -> void:
	var pr: Button = null
	for b in m._items.get_children():
		var tl := b.find_child("Text", true, false) as Label
		if tl and tl.text == "Practice":
			pr = b as Button
	_expect(pr != null, "the menu's Practice row")
	if pr == null:
		return
	pr.pressed.emit()
	await process_frame
	_expect(m._panel.find_child("Practice", true, false) != null, "its panel")
	_expect(await _step("Element", func() -> bool: return MatchSetup.element == el), "the panel: %s" % el)
	_expect(await _step("Dummy", func() -> bool: return MatchSetup.foe() == foe_el), "the panel: a %s dummy" % foe_el)
	_expect(await _step("Way", func() -> bool: return MatchSetup.dummy == practice_way), "the panel: it %s" % practice_way)
	var begin := _row("Begin")
	if begin != null:
		begin.pressed.emit()
	_expect(MatchSetup.incoming and MatchSetup.practice() and MatchSetup.dummy == practice_way, "Begin practice: a practice asked for")


# ---------------------------------------------------------------- the match
func _match() -> void:
	_expect(MatchSetup.scheme() == scheme and c.scheme() == scheme, "the player's caster under the %s scheme (%s)" % [scheme, c.scheme()])
	mode.match_over.connect(func(w: int) -> void: matches.append(w))
	mode.round_over.connect(func(_r: String, _w: String) -> void: rounds_over += 1)
	var f0 := Engine.get_physics_frames()
	var game_t := 0.0
	var next := 0.5
	var shown_done := false
	while mode.phase != "DONE" and game_t < 600.0:
		await physics_frame
		game_t = (Engine.get_physics_frames() - f0) / float(Engine.physics_ticks_per_second)
		if (mode.round_screen as RoundScreen).is_open():
			round_screen_frames += 1
		if mode.phase != "FIGHT" or mode.foe == null or not is_instance_valid(mode.foe):
			next = 0.5
			continue
		next -= 1.0 / Engine.physics_ticks_per_second
		if next > 0.0:
			continue
		await _scheme_cast()                     # (its frames: the round screen may open under it; counted on the next pass)
		next = CAST_S
	shown_done = (mode.match_screen as MatchScreen).is_open()
	print("  %d casts by the player (%s); rounds %d, score %s, ring-outs %d, self ring-outs %d" % [casts.size(),
			_moves(), mode.rounds_played, mode.score, mode.ringouts, mode.self_outs])
	_expect(mode.phase == "DONE" and matches.size() == 1, "the match reaches its end (%s, match_over %s, score %s)" % [mode.phase,
			matches, mode.score])
	_expect(casts.size() >= 4, "the player casts through the %s scheme (%d casts: %s)" % [scheme, casts.size(), _moves()])
	_expect(rounds_over >= 2 and round_screen_frames > 0, "the round screen shows in a round's pause (%d frames, %d rounds)" % [
			round_screen_frames, rounds_over])
	var ml := (mode.match_screen as MatchScreen).lines()
	_expect(shown_done and String(ml.head) in ["Victory", "Defeat", "A drawn match"], "the match screen at the end: \"%s\", %s" % [
			ml.head, ml.score])
	# its Main menu row: back to the menu
	var mm := (mode.match_screen as MatchScreen)._items.find_child("MainMenu", false, false) as Button
	if mm != null:
		mm.pressed.emit()
	var back := await _until(func() -> bool: return current_scene is MainMenu, 20.0)
	_expect(back < INF and not MatchSetup.active(), "its Main menu row: back at the menu, no match under way")


## One cast through the scheme's own input, aimed at the bot.
func _scheme_cast() -> void:
	_turn += 1
	match scheme:
		"keys":
			player.hotbar.select((_turn - 1) % 5)
			await _ticks(2)
		"direction":
			var dirs := ["forward", "back", "side", ""]
			c.dir_override = dirs[(_turn - 1) % dirs.size()]
		"radial":
			var w := c.radial
			if w != null:
				w.held_override = true
				await _ticks(2)
				if w.is_open:
					w.pick_toward(w.dir_of((_turn * 3) % maxi(w.items.size(), 1)) * 120.0)
				w.held_override = false
				await _ticks(2)
				w.held_override = null
		"first_moves", "simple":
			player.hotbar.select((_turn - 1) % 4)  # (1-4, each key's first move only)
			await _ticks(2)
	if mode.phase != "FIGHT" or mode.foe == null or not is_instance_valid(mode.foe):
		return
	_aim()
	Input.action_press(&"aim")
	var lim := 0
	while lim < 150 and c.state != SwayCaster.State.FULL and mode.phase == "FIGHT":
		_aim()
		await physics_frame
		lim += 1
	Input.action_release(&"aim")
	await _ticks(6)
	if scheme == "direction":
		c.dir_override = null


func _aim() -> void:
	if mode.foe == null or not is_instance_valid(mode.foe):
		return
	var to := mode.foe.global_position - player.global_position
	player.yaw = atan2(-to.x, -to.z)
	player.rotation.y = player.yaw
	player.pitch = -0.08


func _moves() -> String:
	var by := {}
	for cs: Array in casts:
		var k := "%s/%s" % cs
		by[k] = int(by.get(k, 0)) + 1
	return str(by)


# ---------------------------------------------------------------- practice
func _practice() -> void:
	var up := await _until(func() -> bool: return mode.phase == "FIGHT" and mode.foe != null, 15.0)
	_expect(up < INF and mode.practice and mode.dummy == practice_way and not mode.rules.soft_walls,
			"a practice against a %s dummy that %s, the soft walls off (%s, %s)" % [mode.foe_element, mode.dummy, mode.practice, mode.phase])
	var t0 := mode.round_left_s()
	var bend: Variant = mode.foe.brain.bending if mode.foe.brain != null else null
	var c0 := int((bend as NpcBending).casts) if bend is NpcBending else 0
	var overs := 0
	mode.round_over.connect(func(_r: String, _w: String) -> void: overs += 1)
	var screens := 0
	for i in int(12.0 * Engine.physics_ticks_per_second):
		await physics_frame
		if (mode.round_screen as RoundScreen).is_open() or (mode.match_screen as MatchScreen).is_open():
			screens += 1
	var t1 := mode.round_left_s()
	var c1 := int((bend as NpcBending).casts) if bend is NpcBending and is_instance_valid(mode.foe) else c0
	_expect(t1 > t0 + 5.0, "the clock counts up (%.1f -> %.1f s)" % [t0, t1])
	_expect(overs == 0 and screens == 0 and mode.round == 1 and mode.phase == "FIGHT", "no round's end and no screen (%d, %d)" % [overs, screens])
	if practice_way == "throw":
		_expect(c1 > c0, "the dummy throws at the player (%d casts in 12 s)" % (c1 - c0))
	var hint := mode.hint
	_expect(hint != null and hint.visible and hint.text == mode.practice_line() and hint.text.contains(MatchSetup.competitor(foe_el)),
			"the practice line: \"%s\"" % (hint.text if hint else "-"))
