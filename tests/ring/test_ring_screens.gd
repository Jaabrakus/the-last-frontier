extends SceneTree
## Tidebreak's screens (the plan's T13: RoundScreen, MatchScreen, the loading screen's tips, Quick match's setup;
## data/ring/screens.json), in the ring scene reached the menu's way (MatchSetup.incoming, LoadingScreen.go):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_screens.gd
##   words       screens.json read, every string in it free of the show's words (whole words, as test_player_words);
##               every tip one line (<= 120 characters)
##   quick       MatchSetup.quick_match(rng): the last element kept, the opponent drawn (a seeded rng: repeatable), a match,
##               and save() leaves the kept opponent as it was; the Quick match line says "against a random opponent"
##   loading     LoadingScreen.go to the ring shows a tip of the sport's (its Tip label, one of screens.json's tips); none
##               for another scene (tip_for)
##   round       earth against water, the foe held: two casts of the player's (SwayCaster.cast), a catch (a stone bolt of
##               the foe's taken by the player's catch guard), the foe knocked over his zone-1 line (a knock-back) and then
##               from deep in zone 2 over its line and off his open end (a second): the round screen opens in the pause
##               (OVER) with "Round 1 · yours", why "Into the water", the score "You 1 : 0 Tide" and the player's tally
##               "casts 2 · catches 1 · knock-backs 2"; the banner says
##               nothing over it; Space-skip: it closes as round 2 counts down
##   match       round 2 to the time-out on ground held (confined 1 against 2): DONE, the match screen with "Victory", the
##               score 2 : 0, a line for each round ("into the water at", "ground held at the bell"), the match's tally,
##               the rows Rematch, Your element, Opponent, Main menu; the mouse free; the player held
##   for rematch Your element and Opponent step the setup without a restart (still DONE, the match's own element kept);
##               Rematch: the score nil, round 1, the new element in play, the screen gone
## Watchdog LIMIT_S. Last line "RING SCREENS TEST PASSED" or "RING SCREENS TEST FAILED" (exit 0 only on a pass).

const NAME := "RING SCREENS TEST"
const LIMIT_S := 300.0
const OWN_CFG := "user://test_ring_screens.cfg"
const WORDS := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?",
		"republic city", "ba sing se", "omashu"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var _re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(WORDS)))


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	GameSettings.path = OWN_CFG
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(maxi(int(s * Engine.physics_ticks_per_second), 1))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _end() -> void:
	if FileAccess.file_exists(OWN_CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func at_s(e: int, s: float, z := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * s, ring.top() + 0.05, z))


func back_of(e: int) -> Vector3:
	var b := ring.axis() * RingArena.side_sign(e)
	b.y = 0.0
	return b.normalized()


func _settle(b: Node3D, pos: Vector3) -> void:
	b.global_position = pos
	if b is CharacterBody3D:
		(b as CharacterBody3D).velocity = Vector3.ZERO
	var kn := BendKnock.peek(b)
	if kn != null:
		kn.reset()


func _go_fight() -> void:
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null and not LoadingScreen.covering(), 25.0)
	mode.phase_t = mode.countdown_s() - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	if foe() != null:
		foe().held = true


func _show(text: String) -> Array:
	var out: Array = []
	for m in _re.search_all(text):
		out.append(m.get_string())
	return out


## Every string value in `v` (not the "_..." keys, not the summary).
func _strings(v: Variant, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for x in v:
			_strings(x, out)
	elif v is Dictionary:
		for k: String in v:
			if not k.begins_with("_") and k != "summary":
				_strings((v as Dictionary)[k], out)


func _run() -> void:
	_words()
	_quick()
	await _loading()
	if mode == null:
		return _end()
	await _round()
	await _match()
	_end()


func _words() -> void:
	var d := MatchSetup.screens()
	_expect(d.has("round") and d.has("match") and d.has("practice") and (d.get("tips", []) as Array).size() >= 8,
			"screens.json read: round, match, practice and %d tips" % (d.get("tips", []) as Array).size())
	var all: Array = []
	_strings(d, all)
	var bad: Array = []
	for s: String in all:
		if not _show(s).is_empty():
			bad.append(s)
	_expect(bad.is_empty(), "none of the show's words in its %d strings (%s)" % [all.size(), bad])
	var long: Array = []
	for t: String in d.get("tips", []):
		if t.length() > 120 or t.contains("\n"):
			long.append(t)
	_expect(long.is_empty(), "every tip one line (%s)" % [long])


func _quick() -> void:
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "hard"
	MatchSetup.save()
	MatchSetup.element = "air"
	MatchSetup.foes = ["air"]
	var r := RandomNumberGenerator.new()
	r.seed = 41
	var drawn := MatchSetup.quick_match(r)
	var r2 := RandomNumberGenerator.new()
	r2.seed = 41
	var again := String(Bending.ELEMENTS[r2.randi_range(0, Bending.ELEMENTS.size() - 1)])
	_expect(MatchSetup.element == "fire" and MatchSetup.difficulty == "hard" and MatchSetup.foes == [drawn] and drawn == again
			and MatchSetup.kind == "match" and MatchSetup.quick,
			"Quick match: the last element (%s) and setup kept, the opponent drawn (%s, the seed's %s)" % [MatchSetup.element, drawn, again])
	var seen := {}
	for i in 40:
		seen[MatchSetup.quick_match()] = true
	_expect(seen.size() >= 3, "unseeded, the draw ranges over the elements (%s)" % [seen.keys()])
	MatchSetup.save()
	_expect(String(GameSettings.get_value(MatchSetup.SECTION, "foe")) == "water" and String(GameSettings.get_value(MatchSetup.SECTION, "element")) == "fire",
			"save() during a Quick match keeps the panel's opponent (%s)" % GameSettings.get_value(MatchSetup.SECTION, "foe"))
	var line := MatchSetup.quick_line()
	_expect(line.contains("random opponent") and line.begins_with(MatchSetup.label("fire")) and _show(line).is_empty(),
			"the Quick match line: \"%s\"" % line)
	MatchSetup.leave()
	_expect(not MatchSetup.quick and MatchSetup.kind == "match", "the main menu again: no quick draw, a match")
	# the setup this test plays
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "normal"
	MatchSetup.rounds_to_win = 2
	MatchSetup.round_s = 60.0


func _loading() -> void:
	_expect(LoadingScreen.tip_for("res://scenes/main.tscn") == "" and LoadingScreen.tip_for(LoadingScreen.RING_SCENE) in MatchSetup.screens().tips,
			"tip_for: a tip on the way to the ring, none to another scene")
	MatchSetup.incoming = true
	var ls := LoadingScreen.go(self, LoadingScreen.RING_SCENE)
	await process_frame
	await process_frame
	var tl := ls.find_child("Tip", true, false) as Label
	_expect(ls.tip in MatchSetup.screens().tips and tl != null and tl.text == ls.tip and tl.is_visible_in_tree(),
			"the loading screen into the ring tells a tip: \"%s\"" % ls.tip)
	var t := await _until(func() -> bool: return current_scene is RingLevel and RingMode.find(self) != null, 30.0)
	lvl = current_scene as RingLevel
	_expect(lvl != null and t < 30.0, "the ring reached through the loading screen (%.1f s)" % t)
	if lvl == null:
		return
	ring = lvl.ring
	player = lvl.player
	mode = RingMode.find(self)
	_expect(mode.round_screen is RoundScreen and mode.match_screen is MatchScreen and not mode.round_screen.is_open() and not mode.match_screen.is_open(),
			"the round and match screens installed, closed")


func _round() -> void:
	await _go_fight()
	var f := foe()
	_expect(mode.phase == "FIGHT" and f != null and mode.foe_element == "water" and mode.element == "earth", "earth against water, the fight on")
	if f == null:
		return
	var sc := SwayCaster.of(player)
	sc.cast.emit("rock_jab", f)
	sc.cast.emit("stone_form", f)
	# a catch: the foe's stone bolt taken by the player's catch guard
	var z := BendZone.make(player, "catch", player.global_position, {"radius_m": 2.5, "life_s": 3.0})
	var from := f.global_position + Vector3.UP * 1.3
	var to := player.global_position + Vector3.UP * 1.3
	BendBolt.launch(f, from, to - from, {"kind": "stone", "mps": 22.0, "damage": 2.0, "knock_mps": 0.0, "range_m": 30.0})
	await _until(func() -> bool: return is_instance_valid(z) and z.took > 0, 2.0)
	await _ticks(2)
	_expect(int(mode.round_tally[0].catches) == 1, "the player's guard took the foe's stone: a catch (%s)" % [mode.round_tally[0]])
	# a knock-back, then off his end
	var fe := mode.end_of(f)
	_settle(f, ring.spawn(fe).origin)
	await _ticks(2)
	BendStatus.knock(f, back_of(fe) * 12.0, player)
	await _until(func() -> bool: return mode.confined_of(f) >= 2, 3.0)
	_expect(mode.confined_of(f) == 2 and int(mode.round_tally[0].knock_backs) == 1,
			"the foe knocked over his zone-1 line: a knock-back (%s)" % [mode.round_tally[0]])
	_settle(f, at_s(fe, 15.5))
	await _ticks(3)
	BendStatus.knock(f, back_of(fe) * 12.0, player)
	await _until(func() -> bool: return mode.phase == "OVER", 3.0)
	await _ticks(2)
	var rs := mode.round_screen as RoundScreen
	var l := rs.lines()
	print("  round screen: ", l)
	_expect(mode.phase == "OVER" and rs.is_open(), "the round screen open in the pause (%s)" % mode.phase)
	_expect(String(l.head).begins_with("Round 1") and String(l.head).ends_with("yours") and String(l.why).begins_with("Into the water"),
			"who and why: \"%s\" / \"%s\"" % [l.head, l.why])
	_expect(String(l.score) == mode.score_text() and String(l.score).contains("1  :  0") and String(l.score).ends_with("Tide"),
			"the score: \"%s\"" % l.score)
	_expect(String(l.yours).contains("casts 2") and String(l.yours).contains("catches 1") and String(l.yours).contains("knock-backs 2")
			and String(l.theirs).begins_with("The Tide"), "the round's tally: \"%s\" / \"%s\"" % [l.yours, l.theirs])
	_expect(String(l.next).begins_with("next round in"), "the next round's line: \"%s\"" % l.next)
	_expect(mode.banner.text == "" and mode.sub.text == "", "the banner says nothing over it")
	var bad: Array = []
	for k: String in l:
		bad.append_array(_show(String(l[k])))
	_expect(bad.is_empty(), "none of the show's words on it (%s)" % [bad])
	mode._skip = true
	await _until(func() -> bool: return mode.round == 2 and mode.phase == "COUNTDOWN", 3.0)
	_expect(not rs.is_open() and mode.round == 2, "Space: round 2 counts down, the screen gone")


func _match() -> void:
	await _go_fight()
	if foe() == null:
		_expect(false, "a foe in round 2")
		return
	(mode.rules.state[player.get_instance_id()] as Dictionary)["confined"] = 1
	(mode.rules.state[foe().get_instance_id()] as Dictionary)["confined"] = 2
	mode.phase_t = mode.round_s
	await _until(func() -> bool: return mode.phase == "OVER", 2.0)
	_expect(mode.last_why == "territory" and mode.score == Vector2i(2, 0) and (mode.round_screen as RoundScreen).lines().why.begins_with("Ground held")
			and (mode.round_screen as RoundScreen).lines().next == RoundScreen.w("decided"),
			"round 2 on ground held: \"%s\", %s" % [(mode.round_screen as RoundScreen).lines().why, (mode.round_screen as RoundScreen).lines().next])
	mode._skip = true
	await _until(func() -> bool: return mode.phase == "DONE", 2.0)
	await _ticks(2)
	var ms := mode.match_screen as MatchScreen
	var l := ms.lines()
	print("  match screen: ", l)
	_expect(mode.phase == "DONE" and ms.is_open() and String(l.head) == "Victory" and String(l.line) == "You take the match"
			and String(l.score).contains("2  :  0"), "the match screen: \"%s\", \"%s\", \"%s\"" % [l.head, l.line, l.score])
	var rows: Array = l.rounds
	_expect(rows.size() == 2 and String(rows[0]).begins_with("Round 1  ·  yours  ·  into the water at 0:")
			and String(rows[1]) == "Round 2  ·  yours  ·  ground held at the bell", "a line for each round: %s" % [rows])
	_expect(String(l.totals).contains("casts 2") and String(l.totals).contains("catches 1") and String(l.totals).contains("knock-backs 2"),
			"the match's tally: \"%s\"" % l.totals)
	var names: Array = []
	for b in ms._items.get_children():
		names.append(String(b.name))
	_expect(names == ["Rematch", "Element", "Opponent", "MainMenu"], "the rows: %s" % [names])
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.drag_speed_cap == 0.0 and not SwayCaster.of(player).enabled,
			"the mouse free, the player held (drag cap %.1f, casting %s)" % [player.drag_speed_cap, SwayCaster.of(player).enabled])
	var bad: Array = []
	for r: String in rows:
		bad.append_array(_show(r))
	for k: String in ["head", "line", "score", "totals"]:
		bad.append_array(_show(String(l[k])))
	_expect(bad.is_empty(), "none of the show's words on it (%s)" % [bad])
	# for the rematch: the element and the opponent stepped, nothing restarts
	ms.cycle_element()
	ms.cycle_opponent()
	await _ticks(10)
	var el_text := (ms._elem.find_child("Text", true, false) as Label).text
	_expect(MatchSetup.element == "water" and MatchSetup.foe() == "fire" and mode.phase == "DONE" and mode.element == "earth"
			and el_text.ends_with("Water"),
			"Your element and Opponent step the setup (%s against %s, \"%s\"), no restart (%s, still %s)" % [
			MatchSetup.element, MatchSetup.foe(), el_text, mode.phase, mode.element])
	ms.rematch()
	await _ticks(3)
	_expect(not ms.is_open() and mode.score == Vector2i.ZERO and mode.round == 1 and mode.phase == "COUNTDOWN"
			and mode.element == "water" and mode.foe_element == "fire" and mode.history.is_empty(),
			"Rematch: the score nil, round 1, water against fire (%s, %d, %s, %s v %s)" % [mode.score, mode.round, mode.phase, mode.element, mode.foe_element])
