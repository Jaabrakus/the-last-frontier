extends SceneTree
## The binds (2026-10-11, the owner: "i think each element should have binds and finishers and how they build team comps is on
## them right?"; his answers: the feet only, as a skill tree twist each element has, fire's a lightning shock): Stone Grip,
## Frost Geyser, Static Shock and Tripwind in a real ring match, headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_binds.gd
##   the twists     each resolves and is live; the wearer's spec has bind_s 0.7, a body that wears nothing has none; the hit
##                  info of a cast with it carries bind_s (BendR3.info_for), without it none
##   the hold       a real hit (BendR3.deliver, the wearer's own class: % and tag) on the bot holds his feet 0.7 s (feet_held, no
##                  run: RingMoves' cap 0), with no launch; again within 6 s 0.42, then 0.25, then none; a long rest and it is
##                  0.7 again; a late guard halves it, a perfect one stops it; a hit that launches him frees the feet; it ends
##                  on its own after its time
##   the held one   the player bound: no jump, no hop (RingMoves), his dash key goes nowhere (BendEffects records "held"),
##                  but a Punch still flies and his guard still goes up; the Column's grip raises no pillar
## Ends with "BINDS TEST PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "BINDS TEST"
const LIMIT_S := 240.0
const BINDS := {"earth.column.grip": ["earth", "earth_shove", "column"], "water.geyser.frost": ["water", "wave", "spout"],
		"fire.lightning.shock": ["fire", "fire_arc", "lightning"], "air.pull.trip": ["air", "air_gust", "pull"]}

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1751)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	BendLoadout.config_override = {}
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


## Game seconds of physics frames (the project ticks physics_ticks_per_second a second: 120, not the test's 60 fps).
func _secs(s: float) -> void:
	await _ticks(ceili(s * float(Engine.physics_ticks_per_second)))


func _near(a: float, b: float, tol := 0.03) -> bool:
	return absf(a - b) <= tol


func _run() -> void:
	# ---------------------------------------------------------------- the twists
	for id: String in BINDS:
		var el: String = BINDS[id][0]
		var mv: String = BINDS[id][1]
		var md: String = BINDS[id][2]
		_expect(BendLoadout.why_not(id) == "", "%s is live (%s)" % [id, BendLoadout.why_not(id)])
		var w := Node3D.new()
		var plain := Node3D.new()
		root.add_child(w)
		root.add_child(plain)
		BendLoadout.wear(w, [id], "", el)
		var base: Dictionary = SwayMoves.move(mv).bend[md]
		var ws := BendLoadout.spec(w, mv, md, base)
		_expect(_near(float(ws.get("bind_s", 0.0)), 0.7) and not BendLoadout.spec(plain, mv, md, base).has("bind_s") and not base.has("bind_s"),
				"%s: the wearer's %s/%s holds 0.7 s, a body that wears nothing has no bind" % [id, mv, md])
		_expect(_near(float(BendR3.info_for(w, mv, md, false, ws).get("bind_s", 0.0)), 0.7)
				and not BendR3.info_for(plain, mv, md, false, base).has("bind_s"), "%s: the cast's hit carries the bind, Classic's none" % id)
		w.free()
		plain.free()

	# ---------------------------------------------------------------- the ring
	MatchSetup.incoming = true
	MatchSetup.element = "fire"
	MatchSetup.foes = ["earth"]
	MatchSetup.round_s = 120.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	InputSetup.ensure()
	SwayCaster.free_override = true
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 20:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(mode != null and player != null and mode.foe != null and RingRules.stock_on(), "the % ring with a match and a bot")
	if mode == null or player == null or mode.foe == null:
		return _end()
	var bot: NpcFighter = mode.foe
	var rules := RingRules.current()
	rules.stale_off = true
	await _secs(4.5)                                 # (past the countdown and the start's safety)
	bot.held = true                                  # (the bot stands: its feet on the deck for every hit below)
	await _secs(0.25)
	_expect(bot.is_on_floor() and not BendStatus.bound(bot), "the bot stands on the deck, free")

	# a real hit: the wearer's Stone Grip on the bot
	BendLoadout.wear(player, ["earth.column.grip"], "", "")
	var p0 := rules.pct_of(bot)
	var info := {"tag": "earth_shove/column", "move": "earth_shove", "mode": "column", "from": player.global_position, "bind_s": 0.7}
	BendR3.deliver(bot, 10.0, bot.global_position + Vector3.UP, Vector3.UP, player, 0.5, Vector3.UP * 11.0, info)
	var kn := BendKnock.peek(bot)
	_expect(BendStatus.bound(bot) and bot.feet_held and _near(BendStatus.until(bot, &"bend_root"), 0.7, 0.05),
			"Stone Grip holds the bot's feet 0.7 s (%.2f)" % BendStatus.until(bot, &"bend_root"))
	_expect(kn == null or not kn.is_launched(), "...and does not launch him")
	_expect(_near(rules.pct_of(bot) - p0, 5.0 * RingRules.stock_num("pct_scale", 1.0), 0.05),
			"...and adds the grip's 5%% x the pace (%.2f)" % (rules.pct_of(bot) - p0))
	var mv_b := RingMoves.of(bot)
	_expect(mv_b != null and is_zero_approx(mv_b._speed_cap()), "a held bot's run is capped at 0 (RingMoves)")

	# weaker each time within 6 s, then none; a long rest and it is whole again
	var held: Array[float] = []
	for i in 3:
		var r := rules.on_hit(bot, player, info)
		held.append(float(r.get("bind_s", -1.0)))
	_expect(_near(held[0], 0.42) and _near(held[1], 0.252) and is_zero_approx(held[2]),
			"again within 6 s: 0.42, then 0.25, then none (%s)" % [held])
	var memo: Dictionary = bot.get_meta(BendStatus.BIND_MEMO_META)
	memo["at"] = BendStatus.now() - 7.0
	bot.set_meta(BendStatus.BIND_MEMO_META, memo)
	_expect(_near(float(rules.on_hit(bot, player, info).get("bind_s", -1.0)), 0.7), "after 6 s without one, a bind holds 0.7 s again")

	# the guards
	bot.remove_meta(BendStatus.BIND_MEMO_META)
	var late := info.duplicate()
	late["guard"] = "late"
	_expect(_near(float(rules.on_hit(bot, player, late).get("bind_s", -1.0)), 0.35), "a late guard halves it")
	bot.remove_meta(BendStatus.BIND_MEMO_META)
	var perfect := info.duplicate()
	perfect["guard"] = "perfect"
	_expect(not rules.on_hit(bot, player, perfect).has("bind_s"), "a perfect guard stops it")

	# a launch frees the feet
	_expect(BendStatus.bound(bot), "(still held)")
	BendLoadout.clear(player)
	# (a jab's small set push: enough to move him, not to throw him off the deck)
	BendR3.deliver(bot, 4.0, bot.global_position + Vector3.UP, Vector3.FORWARD, player, 0.3, Vector3.FORWARD * 3.0,
			{"tag": "rock_jab/pebbles", "move": "rock_jab", "mode": "pebbles", "from": player.global_position})
	_expect(not BendStatus.bound(bot) and not bot.feet_held, "a hit that moves him frees his feet")
	await _secs(0.75)

	# it ends on its own
	bot.remove_meta(BendStatus.BIND_MEMO_META)
	await _secs(1.0)
	_expect(bot.is_on_floor(), "the bot is back on the deck")
	BendStatus.bind(bot, 0.7, "water")
	_expect(BendStatus.bound(bot), "held again")
	await _secs(0.85)
	_expect(not BendStatus.bound(bot) and not bot.feet_held, "the hold ends on its own after its 0.7 s")

	# ---------------------------------------------------------------- the player held
	var pc := BendCaster.of(player)
	var rm := RingMoves.of(player)
	_expect(pc != null and rm != null and player.is_on_floor(), "the player has a caster and the ring's moves, on the deck")
	if pc == null or rm == null:
		return _end()
	if player.has_meta(BendStatus.BIND_MEMO_META):
		player.remove_meta(BendStatus.BIND_MEMO_META)
	_expect(_near(BendStatus.bind(player, 0.7, "fire"), 0.7) and rm._bound() and is_zero_approx(player.bend_speed_cap),
			"the player's feet held: his run capped at 0")
	rm._on_jump_press(true)
	_expect(not rm._air and rm.mode == "", "no jump while held")
	BendEffects.apply(pc, "footwork", "step", SwayMoves.move("footwork").bend.step)
	_expect(String(BendEffects.last_of(pc).get("do", "")) == "held" and not BendEffects.last_of(pc).has("v"), "his dash key goes nowhere (%s)" % BendEffects.last_of(pc))
	var bolts := get_nodes_in_group(BendBolt.GROUP).size()
	BendEffects.apply(pc, "fire_blast", "punch", SwayMoves.move("fire_blast").bend.punch)
	_expect(get_nodes_in_group(BendBolt.GROUP).size() > bolts, "a Punch still flies while held")
	BendEffects.apply(pc, "fire_parry", "parry", SwayMoves.move("fire_parry").bend.parry)
	_expect(String(BendEffects.last_of(pc).get("do", "")) != "held", "his guard still goes up while held (%s)" % BendEffects.last_of(pc).get("do", "-"))
	await _secs(0.85)
	_expect(not rm._bound() and player.bend_speed_cap == INF, "free again after 0.7 s")

	# the Column's grip raises no pillar; the plain Column does
	var spec_g: Dictionary = SwayMoves.move("earth_shove").bend.column.duplicate()
	spec_g["bind_s"] = 0.7
	var at := bot.global_position + Vector3(3.0, 0.0, 0.0)
	_expect(BendEffects.column(pc, at, spec_g) == null, "Stone Grip raises no pillar to stand him on")
	var plain_col := BendEffects.column(pc, at + Vector3(0.0, 0.0, 3.0), SwayMoves.move("earth_shove").bend.column)
	_expect(plain_col != null, "the plain Column still raises its pillar")
	if plain_col != null:
		plain_col.queue_free()
	_end()
