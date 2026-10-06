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
## ROUND 3, the % ring's Practice (smash_r3 spec §11.1), the gate on by a stand-in RingRules (tests/npc/r3_standins.gd: the
## % and the hits are PERCENT's, the flight MOVE's, until they merge):
##   the % rows    its % and yours set by the rows (RingRules.reset_pct at once and by R), "grows" left alone
##   the ways      B steps practice.json's ways (stand, walk, jump, block, guard_held, guard_after, recover, throw, fight),
##                 told to the bot (NpcBending.practice_way); recover puts it off an end; fight frees its mind
##   Throw me off  R puts the player off an end, facing the deck
##   speed 1/2     Engine.time_scale 0.5, kept through a pause (the Esc menu) and a fall's moment (put back to 1)
##   the counter   a true 2-string white ("2 hits"), grey "free" once the dummy was free (the escape counted: hitstun_left)
##   the readout   "steered" equals RingRules.last_steer_deg, "out at" equals RingPredict.ko_pct (the stand-in's)
##   the notes     the Practice-only line "Hop and let go at once: a low hop."; no show word, no other game's
## Watchdog LIMIT_S. Last line "PRACTICE TEST PASSED" or "PRACTICE TEST FAILED" (exit 0 only on a pass).

const NAME := "PRACTICE TEST"
const Standins := preload("res://tests/npc/r3_standins.gd")
const OWN_CFG := "user://test_practice.cfg"
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
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
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
	Engine.time_scale = 1.0
	NpcRingMind.predict_override = null
	GameSettings.path = GameSettings.PATH
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
	await _stock()
	_end()


# ---------------------------------------------------------------- round 3: the % ring's Practice (the stand-in rules)
func _stock() -> void:
	var rules := Standins.install_rules()
	var predict := Standins.FakePredict.new(ring)
	NpcRingMind.predict_override = predict
	var ctl := mode.practice_ctl
	mode.rules.live = false
	_expect(RingRules.stock_on(), "round 3: the gate on (a stand-in stock RingRules)")
	# the % rows
	MatchSetup.foe_pct = 120.0
	MatchSetup.my_pct = -1.0
	ctl._apply_pct()
	var fid := foe().get_instance_id()
	var pid := player.get_instance_id()
	_expect(rules.pct_of(foe()) == 120.0 and not rules.f_pct.has(pid), "its %% row 120: set (%.0f); yours on grows: left alone" % rules.pct_of(foe()))
	rules.f_pct[fid] = 37.0
	await _key(KEY_R)
	await _ticks(3)
	_expect(rules.pct_of(foe()) == 120.0, "R: back to the row's 120%% (%.0f)" % rules.pct_of(foe()))
	# the ways
	_expect(ctl.ways() == MatchSetup.STOCK_DUMMIES, "B steps the %% ring's ways (%s)" % [ctl.ways()])
	ctl.set_way("stand")
	var seen: Array = []
	for i in MatchSetup.STOCK_DUMMIES.size():
		await _key(KEY_B)
		await _ticks(2)
		seen.append(ctl.dummy)
		if ctl.dummy == "recover":
			var out_m := float(ring.nearest_lip(foe().global_position).out_m)
			_expect(out_m >= 2.9 and out_m <= 7.1, "recover: the dummy put off an end, %.1f m out" % out_m)
		if ctl.dummy == "fight":
			_expect(not bend().mind().practice_dummy and bend().practice_way == "fight", "fight: its mind its own")
	_expect(seen.size() == MatchSetup.STOCK_DUMMIES.size() and "walk" in seen and "guard_after" in seen and bend().practice_way == ctl.dummy,
			"B: %s, told to the bot (%s)" % [seen, bend().practice_way])
	ctl.set_way("stand")
	# Throw me off
	MatchSetup.throw_me = true
	await _key(KEY_R)
	await _ticks(3)
	var pout := float(ring.nearest_lip(player.global_position).out_m)
	_expect(pout > 2.0, "Throw me off: R puts you off an end (%.1f m out)" % pout)
	MatchSetup.throw_me = false
	await _key(KEY_R)
	await _ticks(3)
	# speed 1/2 through a pause and a fall's moment
	MatchSetup.speed = 0.5
	ctl._apply_rows()
	_expect(is_equal_approx(Engine.time_scale, 0.5), "speed 1/2: time_scale %.2f" % Engine.time_scale)
	var menu := lvl.get_node_or_null("RingMenu") as RingMenu
	if menu == null:
		menu = mode.get_node_or_null("RingMenu") as RingMenu
	if menu != null:
		menu.open()
		await process_frame
		menu.close()
	Engine.time_scale = 1.0                      # (a fall's moment that put it back to 1)
	await _ticks(3)
	_expect(is_equal_approx(Engine.time_scale, 0.5), "after a pause and a fall's moment: still 1/2 (%.2f)" % Engine.time_scale)
	MatchSetup.speed = 1.0
	Engine.time_scale = 1.0
	await _ticks(2)
	# the counter: a true 2-string white, then grey once free
	var v := Vector3(4.0, 3.0, 0.0)
	rules.f_string[fid] = 1
	rules.stun_for(foe(), 0.5)
	rules.launched.emit(foe(), v, 0.5, player, "air_blast/slice")
	rules.pct_changed.emit(foe(), 126.0, 6.0)
	await _ticks(10)
	rules.f_string[fid] = 2
	rules.stun_for(foe(), 0.5)
	rules.launched.emit(foe(), v, 0.5, player, "air_blast/slice")
	rules.pct_changed.emit(foe(), 132.0, 6.0)
	await _ticks(2)
	ctl.paint()
	var c2 := ctl.counter_text()
	_expect(c2.begins_with("2 hits") and c2.contains("12%") and ctl.counter_white() and ctl.panel.visible
			and ctl.panel.counter_color() == PracticePanel.WHITE, "a true 2-string: \"%s\", white" % c2)
	await _secs(0.7)
	ctl.paint()
	var cf := ctl.counter_text()
	_expect(cf.contains(MatchSetup.pword("counter_free")) and not ctl.counter_white() and ctl.panel.counter_color() == PracticePanel.GREY,
			"free between hits: \"%s\", grey" % cf)
	_expect(ctl.best_text().begins_with("best 2"), "the best kept: \"%s\"" % ctl.best_text())
	# the readout: steered = last_steer_deg, out at = the predictor's
	rules.f_steer[fid] = 12.0
	rules.f_string[fid] = 1
	rules.stun_for(foe(), 0.4)
	foe().global_position = at_s(1 - mode.player_end, ring.half_l() - 3.0)
	player.global_position = at_s(1 - mode.player_end, ring.half_l() - 9.0)
	var dir := NpcRingMind.flat_dir(player.global_position, foe().global_position)
	rules.launched.emit(foe(), dir * 9.0 + Vector3.UP * 4.0, 0.4, player, "fire_blast/punch")
	await _secs(0.3)
	var want_out := predict.ko_pct("fire_blast/punch", foe(), player.global_position, dir)
	var tail := MatchSetup.pword("stays") if want_out == INF else MatchSetup.pword("out_at") % roundi(want_out)
	_expect(ctl.readout.contains("steered 12°") and ctl.readout.ends_with(tail) and ctl.readouts >= 1,
			"the readout: \"%s\" (out at %s)" % [ctl.readout, "never" if want_out == INF else str(roundi(want_out))])
	ctl.paint()
	_expect(ctl.panel.notes.text == "Hop and let go at once: a low hop." and ctl.panel.readout.text == ctl.readout,
			"the notes line and the readout on the panel")
	var bad: Array = []
	for t: String in [ctl.practice_line(), ctl.readout, c2, cf, ctl.panel.notes.text]:
		for m in _re.search_all(t):
			bad.append(m.get_string())
	_expect(bad.is_empty(), "no show word on the panel (%s)" % [bad])
	MatchSetup.foe_pct = -1.0
	NpcRingMind.predict_override = null
	Standins.uninstall(rules)


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
