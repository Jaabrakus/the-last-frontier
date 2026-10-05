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
##   metrics     printed: "METRIC ring_out_ratio=<ring-outs / rounds>", the rounds' whys, the knocks landed per side
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


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
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
		print("  round %d: %s by %s (%.0f s left, score %s, knocks %s)" % [mode.round, r, why, mode.round_left_s(), mode.score, mode.rules.knocks]))
	mode.rang_out.connect(func(who: Node3D, by: Node) -> void:
		outs.append([mode.side_of(who), mode.side_of(by) if by != null and is_instance_valid(by) else -1, who == by]))
	mode.match_over.connect(func(w: int) -> void: matches.append(w))
	await _until(func() -> bool: return mode.foe != null, 5.0)
	_expect(is_equal_approx(mode.round_s, 60.0) and mode.to_win == 2, "round_s %.0f, to_win %d (the args through MatchSetup)" % [mode.round_s, mode.to_win])
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
		BendEffects.apply(bc, String(pick[0]), String(pick[1]), pick[2] as Dictionary)
	Engine.time_scale = 1.0
	var real_s := (Time.get_ticks_msec() - t0) / 1000.0
	print("  (%.0f s of the game in %.0f s; %d casts by the player's side)" % [game_t, real_s, casts])
	_expect(mode.phase == "DONE", "the match reaches DONE (%s, round %d, score %s)" % [mode.phase, mode.round, mode.score])
	_expect(matches.size() == 1 and matches[0] == mode.winner, "match_over once (%s), the winner %d" % [matches, mode.winner])
	var max_r := int(RingRules.num("max_rounds", 7.0))
	_expect(mode.score.x >= mode.to_win or mode.score.y >= mode.to_win or mode.round >= max_r,
			"a side at to_win, or max_rounds played (score %s, rounds %d)" % [mode.score, mode.round])
	_expect(rounds.size() == mode.rounds_played and rounds.size() >= 2, "the rounds counted (%d)" % rounds.size())
	var whys_ok := true
	var whys: Array = []
	for r in rounds:
		whys.append(String(r[2]))
		whys_ok = whys_ok and String(r[2]) in ["ringout", "winded", "territory", "health", "time"]
	_expect(whys_ok, "every round's why is a rule's (%s)" % [whys])
	var selfs := 0
	for o in outs:
		if int(o[1]) < 0 or bool(o[2]) or int(o[1]) == int(o[0]):
			selfs += 1
	_expect(selfs == 0 and mode.self_outs == 0, "no self ring-out (%d of %d ring-outs; the mode's count %d)" % [selfs, outs.size(), mode.self_outs])
	_expect(not dead_seen, "neither side ever dead in the ring (winded instead)")
	var ratio := float(mode.ringouts) / float(maxi(mode.rounds_played, 1))
	print("METRIC ring_out_ratio=%.2f (%d of %d rounds)" % [ratio, mode.ringouts, mode.rounds_played])
	print("METRIC whys=%s" % [whys])
	print("METRIC hits=%s" % [[mode.stats[0].get("hits", 0), mode.stats[1].get("hits", 0)]])
	print("METRIC knock_backs=%s" % [[mode.stats[0].get("knock_backs", 0), mode.stats[1].get("knock_backs", 0)]])
	_end()


## The element's attacks with a bend spec of an ATTACKS kind: [[id, mode, spec], ...].
func _attacks(el: String) -> Array:
	var out: Array = []
	for pair in Bending.keys(el):
		for id: String in pair:
			for md: String in SwayCaster.modes_of(id):
				var spec: Dictionary = (SwayMoves.move(id).get("bend", {}) as Dictionary).get(md, {})
				if String(spec.get("do", "")) in ATTACKS:
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
