extends SceneTree
## A whole Tidebreak match against a bot, run fast (RingMode, RingRules; the owner, 2026-10-04: "1v1 first"; best of three):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_match.gd -- mode=ring element=earth foe=earth
##         round_s=60 to_win=2 [ts=4] [cast_s=1.8]
## The ring scene with the match asked for, Engine.time_scale ts (4). The bot fights as it fights (its tactics "bend"); the
## player's side is scripted: standing his ground, he casts his element's attacks at the bot every cast_s (BodyBendCaster
## aimed at its chest: bolts, cones, rings, a column; no dashes), so both sides knock. Each round ends on its own: a
## ring-out, spent in the last zone, or the time-out (more ground, then more health, else a draw); Space is never pressed.
##   the match   reaches DONE with match_over once, a side at to_win (or max_rounds played), the rounds counted
##   the rules   no self ring-out (every ring-out credited to a knocker of the other side, never none or one's own);
##               neither side ever dead (winded instead); every round_over's why one of ringout, winded, territory,
##               health, time
##   the seams   (wave 2's first playable check, the menu's path: MatchSetup with element and foe) the player gun-free
##               with his element's bar laid (FrontierPlayer.arena, Hotbar.lay_spells) and the arena HUD (set_arena: the
##               BendStrip and the MatchBar reading the match); the foe a bot of the foe's element on ring_team_b (NpcSquad
##               opts.element), the ring's bounds_fn / edge_fn on its bending; over the match the bot casts (only its own
##               element's moves, Mend and Patch) and knocks the player; the countdown holds the player's casting
##               (SwayCaster.enabled) and the fight lets it go
##   metrics     printed: "METRIC ring_out_ratio=<ring-outs / rounds>", the rounds' whys, the knocks landed per side, the
##               bot's casts by move
## Round 3 (smash_r3 spec v2 §7, §15): in the % ring (rule set stock, rules.json's default; rules=classic for the zones)
## the match is one game of lives on its clock: it reaches DONE; every game's why falls, time, sudden or a sudden draw; each
## fall credited to the other side or his own; health never touched; the plates shown in place of the match bar; METRIC
## falls with each fall's %.
## In-test watchdog LIMIT_S real seconds (under the runner's GODOT_TIMEOUT 420). Last line: "RING MATCH TEST PASSED" or
## "... FAILED".

const NAME := "RING MATCH TEST"
const LIMIT_S := 400.0
## The kinds of the player's scripted casts (no dashes: he stands his ground).
const ATTACKS := ["bolt", "cone", "ring", "column"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var rounds: Array = []
var outs: Array = []
var matches: Array = []
var dead_seen := false
var casts := 0
var ts := 4.0
var cast_s := 1.8
## The bot's casts over the match (a new bot each round: summed at each round's end), by "move/mode"; knocks per side.
var bot_casts := 0
var bot_by := {}
var knocks := Vector2i.ZERO
## Frames of the player's caster: [held in the countdown, open in the countdown, open in the fight, held in the fight].
var cast_frames := [0, 0, 0, 0]
## Round 3: the % match (RingRules.stock_on(): rules.json's default) or the classic zones (rules=classic).
var stock := false


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		print("  (watchdog: round %s, phase %s, score %s)" % [mode.round if mode else -1, mode.phase if mode else "-", mode.score if mode else "-"])
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with("ts=") and kv.get_slice("=", 1).is_valid_float():
			ts = float(kv.get_slice("=", 1))
		elif kv.begins_with("cast_s=") and kv.get_slice("=", 1).is_valid_float():
			cast_s = float(kv.get_slice("=", 1))
	SwayCaster.free_override = true
	InputSetup.ensure()
	# (the soak's own numbers unless the args give others: MatchSetup.take() applies the args over these)
	MatchSetup.round_s = 60.0
	MatchSetup.rounds_to_win = 2
	MatchSetup.incoming = true
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(mode != null and player != null, "the ring with a match")
	if mode == null or player == null:
		return _end()
	mode.round_over.connect(func(r: String, why: String) -> void:
		rounds.append([mode.round, r, why, mode.round_left_s()])
		knocks += mode.rules.knocks
		var bend: Variant = mode.foe.brain.bending if mode.foe != null and is_instance_valid(mode.foe) and mode.foe.brain != null else null
		if bend is NpcBending:
			bot_casts += (bend as NpcBending).casts
			for k: String in (bend as NpcBending).casts_by:
				bot_by[k] = int(bot_by.get(k, 0)) + int((bend as NpcBending).casts_by[k])
		print("  round %d: %s by %s (%.0f s left, score %s, knocks %s)" % [mode.round, r, why, mode.round_left_s(), mode.score, mode.rules.knocks]))
	mode.rang_out.connect(func(who: Node3D, by: Node) -> void:
		outs.append([mode.side_of(who), mode.side_of(by) if by != null and is_instance_valid(by) else -1, who == by]))
	mode.match_over.connect(func(w: int) -> void: matches.append(w))
	await _until(func() -> bool: return mode.foe != null, 5.0)
	stock = RingRules.stock_on()
	if stock:
		# (round 3's % match: an 8:00 game unless round_s= says, one game unless games=3)
		var want_s := RingMode._arg_num("round_s", RingRules.stock_num("time_s", 480.0))
		_expect(is_equal_approx(mode.round_s, want_s) and mode.to_win == (2 if mode.games() >= 3 else 1),
				"the %% match: round_s %.0f, to_win %d (games %d)" % [mode.round_s, mode.to_win, mode.games()])
	else:
		_expect(is_equal_approx(mode.round_s, 60.0) and mode.to_win == 2, "round_s %.0f, to_win %d (the args through MatchSetup)" % [mode.round_s, mode.to_win])
	await _seams()
	Engine.time_scale = ts
	var t0 := Time.get_ticks_msec()
	var game_t := 0.0
	var next_cast := 0.0
	var plan := _attacks(mode.element)
	_expect(not plan.is_empty(), "the player's element has attacks to script (%d)" % plan.size())
	var bc: BodyBendCaster = null
	var bc_foe: Node = null
	while mode.phase != "DONE" and game_t < 1200.0:
		await physics_frame
		var dt := 1.0 / Engine.physics_ticks_per_second * Engine.time_scale
		game_t += dt
		if player.is_dead or (mode.foe != null and is_instance_valid(mode.foe) and mode.foe.is_dead()):
			dead_seen = true
		var sc := SwayCaster.of(player)
		if sc != null and mode.phase == "COUNTDOWN" and mode.phase_t > 0.1:
			cast_frames[1 if sc.enabled else 0] += 1
		elif sc != null and mode.phase == "FIGHT" and not (stock and mode.rules.is_away(player)):
			cast_frames[2 if sc.enabled else 3] += 1
		if mode.phase != "FIGHT" or mode.foe == null or not is_instance_valid(mode.foe):
			next_cast = 0.6
			continue
		next_cast -= dt
		if next_cast > 0.0 or plan.is_empty():
			continue
		next_cast = cast_s
		if bc == null or bc_foe != mode.foe:
			bc = BodyBendCaster.new(player, mode.foe, 0.8, 2.0)
			bc_foe = mode.foe
		var pick: Array = plan[casts % plan.size()]
		casts += 1
		var to := mode.foe.global_position - player.global_position
		player.yaw = atan2(-to.x, -to.z)
		player.rotation.y = player.yaw
		BendCast.cast(bc, String(pick[0]), String(pick[1]), mode.foe)   # (the one entry for any caster)
	Engine.time_scale = 1.0
	var real_s := (Time.get_ticks_msec() - t0) / 1000.0
	print("  (%.0f s of the game in %.0f s; %d casts by the player's side)" % [game_t, real_s, casts])
	_expect(mode.phase == "DONE", "the match reaches DONE (%s, round %d, score %s)" % [mode.phase, mode.round, mode.score])
	_expect(matches.size() == 1 and matches[0] == mode.winner, "match_over once (%s), the winner %d" % [matches, mode.winner])
	var max_r := int(RingRules.num("max_rounds", 7.0))
	_expect(mode.score.x >= mode.to_win or mode.score.y >= mode.to_win or mode.round >= max_r,
			"a side at to_win, or max_rounds played (score %s, rounds %d)" % [mode.score, mode.round])
	_expect(rounds.size() == mode.rounds_played and rounds.size() >= (1 if stock else 2), "the rounds counted (%d)" % rounds.size())
	var whys_ok := true
	var whys: Array = []
	var rule_whys := ["falls", "time", "sudden", "sudden_draw"] if stock else ["ringout", "winded", "territory", "health", "time"]
	for r in rounds:
		whys.append(String(r[2]))
		whys_ok = whys_ok and String(r[2]) in rule_whys
	_expect(whys_ok, "every round's why is a rule's (%s)" % [whys])
	var selfs := 0
	for o in outs:
		if int(o[1]) < 0 or bool(o[2]) or int(o[1]) == int(o[0]):
			selfs += 1
	if stock:
		# (a fall with no knocker within 6 s is his own: allowed in the % ring, counted apart)
		var falls_ok := true
		for fl: Dictionary in mode.falls:
			falls_ok = falls_ok and (fl.get("by") == null or mode.side_of(fl.get("by")) != int(fl.get("team", -1)))
		_expect(falls_ok and not mode.falls.is_empty(), "every fall credited to the other side or his own (%d falls, %d own)" % [mode.falls.size(), mode.self_outs])
		_expect(player.health == player.max_health and (mode.foe == null or not is_instance_valid(mode.foe) or mode.foe.health == mode.foe.health_max),
				"health never touched in the %% ring (%.0f)" % player.health)
	else:
		_expect(selfs == 0 and mode.self_outs == 0, "no self ring-out (%d of %d ring-outs; the mode's count %d)" % [selfs, outs.size(), mode.self_outs])
	_expect(not dead_seen, "neither side ever dead in the ring (winded instead)")
	_expect(cast_frames[0] > 0 and cast_frames[1] == 0 and cast_frames[2] > 0 and cast_frames[3] == 0,
			"the countdown holds the player's casting, the fight lets it go (frames held/open in the countdown, open/held in the fight: %s)" % [cast_frames])
	var own: Dictionary = {}
	for pair in Bending.keys(mode.foe_element):
		for id: String in pair:
			own[id] = true
	for extra: Dictionary in [Bending.jab(mode.foe_element), Bending.guard(mode.foe_element)]:
		own[String(extra.get("id", ""))] = true    # (round 2: its jab on the left button and its guard on E are its own too)
	var foreign: Array = []
	for k: String in bot_by:
		var id := k.get_slice("/", 0)
		if not own.has(id) and not id in ["mend", "patch"]:
			foreign.append(k)
	_expect(bot_casts > 0 and foreign.is_empty(), "the %s bot fights with its own element's moves (%d casts, %d distinct; not its own: %s)" % [mode.foe_element, bot_casts, bot_by.size(), foreign])
	_expect(knocks.y > 0, "the bot knocks the player (knocks landed %s)" % knocks)
	var ratio := float(mode.ringouts) / float(maxi(mode.rounds_played, 1))
	print("METRIC ring_out_ratio=%.2f (%d of %d rounds)" % [ratio, mode.ringouts, mode.rounds_played])
	print("METRIC whys=%s" % [whys])
	print("METRIC hits=%s" % [[mode.stats[0].get("hits", 0), mode.stats[1].get("hits", 0)]])
	print("METRIC knock_backs=%s" % [[mode.stats[0].get("knock_backs", 0), mode.stats[1].get("knock_backs", 0)]])
	print("METRIC knocks=%s bot_casts=%d bot_by=%s catches=%d" % [knocks, bot_casts, bot_by, int(mode.stats[1].get("catches", 0))])
	if stock:
		var pcts: Array = []
		for fl: Dictionary in mode.falls:
			pcts.append(roundi(float(fl.get("pct", 0.0))))
		print("METRIC falls=%d fall_pcts=%s own_falls=%d" % [mode.falls.size(), pcts, mode.self_outs])
	_end()


## The seams between wave 2's tasks, as the menu's path leaves them (round 1's countdown): the arena player (T9), the bot
## (T7a) on the ring's side (T8), the HUD reading the match (T9 on T8).
func _seams() -> void:
	await _until(func() -> bool: return player.arena_element != "", 3.0)
	var el := mode.element
	_expect(bool(player.get(&"arena")) and player.weapon == null and player.weapons.is_empty() and player.weapon_order.is_empty(),
			"the player gun-free in the arena (arena %s, weapon %s, %d weapons)" % [player.get(&"arena"), player.weapon, player.weapons.size()])
	_expect(MatchSetup.element == el and Bending.of(player).element == el and player.arena_element == el,
			"the player's element the setup's (%s; bending %s, bar laid for %s)" % [el, Bending.of(player).element, player.arena_element])
	var bar := Hotbar.of(player)
	var want: Array = Bending.bar(el)
	var got: Array = []
	for i in want.size():
		got.append(String(bar.entry(i).get("id", "")) if bar != null else "")
	_expect(bar != null and got == want and bar.spells_only and bar.kit_placed, "the element's bar laid, the kit closed (%s)" % [got])
	var hud := player.hud
	_expect(hud != null and hud.arena and hud.bend_strip != null and hud.match_bar != null and hud.percent_bar != null,
			"the arena HUD: the strip, the match bar and the % plates")
	if hud != null and hud.bend_strip != null:
		var c0: Dictionary = hud.bend_strip.column(0)
		_expect(String(c0.get("id", "")) == String(want[0]) if not want.is_empty() else false, "the strip's key 1 is the bar's (%s)" % c0.get("id", ""))
	if stock and hud != null:
		await process_frame
		var pl: Dictionary = hud.percent_bar.lines()
		_expect(hud.percent_bar.visible and not hud.match_bar.visible and (pl.plates[0] as Array).size() == 1
				and (pl.plates[1] as Array).size() == 1 and int(((pl.plates[0] as Array)[0] as Dictionary).lives) == 3,
				"the %% ring: the plates in place of the match bar, one a side, 3 lives (%s)" % str(pl.clock))
	elif hud != null and hud.match_bar != null:
		var l: Dictionary = hud.match_bar.lines()
		_expect(String(l.round) == "ROUND 1" and String(l.score).contains(MatchSetup.competitor(mode.foe_element)) and String(l.score).count("○") == 2 * mode.to_win,
				"the match bar reads the match (%s · %s · %s)" % [l.round, l.time, l.score])
	var foe := mode.foe
	_expect(foe != null and foe.faction == "ring_team_b" and String(foe.get(&"element")) == mode.foe_element,
			"the foe a bot of %s on ring_team_b (%s, %s)" % [mode.foe_element, foe.faction if foe else "-", foe.get(&"element") if foe else "-"])
	var bend: NpcBending = foe.brain.bending if foe != null and foe.brain != null else null
	_expect(bend != null and bend.element == mode.foe_element and bend.bounds_fn.is_valid() and bend.edge_fn.is_valid() and foe.weapon in ["", "none"],
			"its bending of %s, the ring's bounds and edges set, no gun (weapon '%s')" % [bend.element if bend else "-", foe.weapon if foe else "-"])
	_expect(mode.side_of(player) == 0 and mode.side_of(foe) == 1 and (stock or (mode.confined_of(player) == 1 and mode.confined_of(foe) == 1)),
			"the sides and zones (player 0 / zone 1, foe 1 / zone 1)")


## The element's attacks with a bend spec of an ATTACKS kind: [[id, mode, spec], ...].
func _attacks(el: String) -> Array:
	var out: Array = []
	for pair in Bending.keys(el):
		for id: String in pair:
			for md: String in SwayCaster.modes_of(id):
				var spec: Dictionary = (SwayMoves.move(id).get("bend", {}) as Dictionary).get(md, {})
				# (not Breath: its smoke hides the player from the bot, by design, and the script's every-other cast at
				# it would keep the bot blind all match; an owner question in round 2's gate)
				if String(spec.get("do", "")) in ATTACKS and not spec.has("smoke_s"):
					out.append([id, md, spec])
	return out


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF
