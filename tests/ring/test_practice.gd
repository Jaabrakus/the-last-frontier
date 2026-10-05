extends SceneTree
## Tidebreak's practice (RingMode practice; MatchSetup kind "practice", dummy; data/ring/screens.json "practice"), in the ring
## scene asked for by the user arg practice=throw (earth against an earth dummy):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_practice.gd -- practice=throw element=earth foe=earth
##   asked       MatchSetup.take: a practice, the dummy throwing; RingMode practice, a short countdown, then the fight
##   no clock    no timer (the clock counts up, never a time-out), never decided, no round screen, round 1 throughout
##   throw       the dummy, held at its end (never walks), casts its throw (its element's key 1 first move: earth stone_form
##               spike; MatchSetup.practice_move for all four, the cover its wall) every throw_every_s: three or more in 9 s,
##               each by its own lock (NpcBending.casts, last_cast)
##   a catch     a catch guard of the player's takes one of its stones (BendZone.took): the practice tally's catches
##   R           (the key ring_reset, as a key press) both back at their ends whole, the deck cleared ("Positions reset")
##   B           (ring_dummy) steps the dummy's way: throw -> stand; standing it never casts in 5 s
##   block       block: a stone bolt of the player's at it is answered by its element's guard at once (no dice: its catch),
##               and the block's cover is earth_wall/wall
##   the water   the player knocked off his end: "Into the water", no round_over, no score; both back at their ends after
##               reset_after_out_s, still FIGHT, nobody out
##   spent       999 on the dummy: whole again at once (no death, no round's end)
##   the line    the practice line names the dummy and the keys (R, B, Esc), with none of the show's words
## Watchdog LIMIT_S. Last line "PRACTICE TEST PASSED" or "PRACTICE TEST FAILED" (exit 0 only on a pass).

const NAME := "PRACTICE TEST"
const LIMIT_S := 300.0
const WORDS := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var round_overs := 0
var _re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(WORDS)))


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
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


func bend() -> NpcBending:
	return foe().brain.bending if foe() != null and foe().brain != null else null


func at_s(e: int, s: float, z := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * s, ring.top() + 0.05, z))


func back_of(e: int) -> Vector3:
	var b := ring.axis() * RingArena.side_sign(e)
	b.y = 0.0
	return b.normalized()


func _key(code: Key) -> void:
	for down in [true, false]:
		var k := InputEventKey.new()
		k.physical_keycode = code
		k.keycode = code
		k.pressed = down
		Input.parse_input_event(k)
		await process_frame


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	_expect(lvl != null and mode != null, "the ring with a match node")
	if mode == null:
		return _end()
	ring = lvl.ring
	player = lvl.player
	mode.round_over.connect(func(_r: String, _w: String) -> void: round_overs += 1)
	await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null, 10.0)
	_expect(MatchSetup.practice() and mode.practice and mode.dummy == "throw" and mode.foe_element == "earth" and mode.phase == "FIGHT",
			"a practice against an earth dummy that throws, the fight on (%s, %s, %s)" % [mode.practice, mode.dummy, mode.phase])
	_expect(not mode.rules.soft_walls, "the soft walls off: walk anywhere")
	await _throw()
	await _reset_key()
	await _stand()
	await _block()
	await _water()
	await _spent()
	_line()
	_expect(round_overs == 0 and mode.round == 1 and mode.score == Vector2i.ZERO and not mode.decided() and mode.phase == "FIGHT"
			and not (mode.round_screen as RoundScreen).is_open() and not (mode.match_screen as MatchScreen).is_open(),
			"no rounds: round 1, no score, no round's end, no screen (%d round_overs)" % round_overs)
	_expect(mode.round_left_s() > 20.0, "no timer: the clock counts up (%.1f s)" % mode.round_left_s())
	_end()


func _throw() -> void:
	var b := bend()
	var spawn := foe().global_position
	var c0 := b.casts
	await _secs(9.0)
	var moved := foe().global_position.distance_to(spawn)
	_expect(b.casts - c0 >= 3 and String(b.last_cast.get("move", "")) == "stone_form" and String(b.last_cast.get("mode", "")) == "spike",
			"the dummy throws: %d casts in 9 s, the last %s/%s (each its own lock: %.2f s)" % [b.casts - c0, b.last_cast.get("move", ""),
			b.last_cast.get("mode", ""), float(b.last_cast.get("took_s", 0.0))])
	_expect(moved < 0.6, "held at its end (moved %.2f m)" % moved)
	# a catch: the player's guard up as the next stone comes
	var n0 := int(mode.round_tally[0].get("catches", 0))
	await _until(func() -> bool: return b.casting != "", 4.0)
	await _until(func() -> bool: return b.casting == "", 4.0)
	var z := BendZone.make(player, "catch", player.global_position, {"radius_m": 3.0, "life_s": 3.0})
	await _until(func() -> bool: return is_instance_valid(z) and z.took > 0, 3.0)
	await _ticks(2)
	_expect(is_instance_valid(z) and z.took > 0 and int(mode.round_tally[0].get("catches", 0)) == n0 + 1,
			"the player's catch takes its stone: the tally's catches %d -> %d" % [n0, int(mode.round_tally[0].get("catches", 0))])


func _reset_key() -> void:
	var e := mode.player_end
	player.global_position = at_s(e, 12.0, 3.0)
	foe().global_position = at_s(1 - e, 10.0, -2.0)
	await _ticks(2)
	await _key(KEY_R)
	await _ticks(3)
	var pd := player.global_position.distance_to(ring.spawn(e).origin)
	var fd := foe().global_position.distance_to(ring.spawn(1 - e).origin)
	_expect(pd < 0.5 and fd < 0.6 and mode.banner.text == RingMode.pword("reset"),
			"R: both back at their ends (%.2f m, %.2f m), \"%s\"" % [pd, fd, mode.banner.text])


func _stand() -> void:
	await _key(KEY_B)
	_expect(mode.dummy == "stand" and MatchSetup.dummy == "stand", "B: the dummy's way throw -> %s" % mode.dummy)
	await _until(func() -> bool: return bend().casting == "", 3.0)
	await _secs(0.6)
	var c0 := bend().casts
	await _secs(5.0)
	_expect(bend().casts == c0, "standing, it never casts (%d in 5 s)" % (bend().casts - c0))


func _block() -> void:
	await _key(KEY_B)
	_expect(mode.dummy == "block", "B again: %s" % mode.dummy)
	_expect(mode._pmove("cover") == "earth_wall/wall" and mode._pmove("throw") == "stone_form/spike", "its cover %s, its throw %s" % [mode._pmove("cover"), mode._pmove("throw")])
	# (every element's dummy throws its own key 1 first move and covers with its wall: every guard has its strike to take)
	var want := {"earth": ["stone_form/spike", "earth_wall/wall"], "water": ["water_whip/whip", "water_shield/ice_wall"],
			"fire": ["fire_blast/punch", "fire_wall/wall"], "air": ["air_blast/slice", "air_wall/wall"]}
	var got := {}
	for el: String in want:
		got[el] = [MatchSetup.practice_move(el, "throw"), MatchSetup.practice_move(el, "cover")]
	_expect(got == want, "each element's dummy throws its key 1 first move and covers with its wall (%s)" % [got])
	await _secs(0.5)
	var b := bend()
	var from := player.global_position + Vector3.UP * 1.3
	var to := foe().global_position + Vector3.UP * 1.3
	var seen := [""]
	var watch := func() -> bool:
		if b.casting != "":
			seen[0] = b.casting + "/" + b.mode
		return seen[0] != ""
	BendBolt.launch(player, from, to - from, {"kind": "stone", "mps": 18.0, "damage": 2.0, "knock_mps": 0.0, "range_m": 30.0})
	var t := await _until(watch, 1.5)
	_expect(seen[0] == "stone_catch/catch", "a stone at it: answered by its guard, %s, in %.2f s" % [seen[0], t])
	await _secs(1.5)


func _water() -> void:
	var e := mode.player_end
	player.global_position = at_s(e, 15.6)
	player.velocity = Vector3.ZERO
	await _ticks(3)
	BendStatus.knock(player, back_of(e) * 12.0, foe())
	await _until(func() -> bool: return mode.rules.is_out(player), 3.0)
	await _ticks(2)
	_expect(mode.rules.is_out(player) and mode.banner.text == RingMode.pword("out") and round_overs == 0 and mode.score == Vector2i.ZERO,
			"knocked into the water: \"%s\", no round's end, no score" % mode.banner.text)
	await _secs(RingMode._pnum("reset_after_out_s", 1.6) + 0.5)
	var pd := player.global_position.distance_to(ring.spawn(e).origin)
	_expect(not mode.rules.is_out(player) and pd < 0.6 and mode.phase == "FIGHT",
			"then both back at their ends (%.2f m from his spawn), the fight on (out %s, %s)" % [pd, mode.rules.is_out(player), mode.phase])


func _spent() -> void:
	var f := foe()
	f.apply_hit(999.0, f.global_position + Vector3.UP, Vector3.FORWARD, player, "body")
	await _ticks(3)
	_expect(is_instance_valid(f) and not f.is_dead() and is_equal_approx(f.health, f.health_max) and mode.phase == "FIGHT",
			"999 on the dummy: whole again at once (%.0f of %.0f)" % [f.health if is_instance_valid(f) else -1.0, f.health_max])


func _line() -> void:
	var l := mode.practice_line()
	_expect(mode.hint.visible and mode.hint.text == l and l.contains("R: reset positions") and l.contains("B:") and l.contains("Esc")
			and l.contains(MatchSetup.competitor("earth")), "the practice line: \"%s\"" % l)
	_expect(mode.tally_label.visible and mode.tally_label.text.begins_with("casts"), "the tally line: \"%s\"" % mode.tally_label.text)
	var bad: Array = []
	for t: String in [l, mode.tally_label.text, RingMode.pword("out"), RingMode.pword("reset")]:
		for m in _re.search_all(t):
			bad.append(m.get_string())
	_expect(bad.is_empty(), "none of the show's words (%s)" % [bad])
