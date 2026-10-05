extends SceneTree
## A Tidebreak soak with bots on both sides (spectate: the player parked off the deck, out of the rules and out of every
## bot's sight; a bot of his element fights in his place on his side, ring_team_a, each round a new one as the mode's foe is),
## one pairing per run, played fast to the end of the match:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_soak.gd -- mode=ring element=earth foe=water
##         [round_s=60] [to_win=2] [ts=4] [difficulty=normal]
## The ring scene with the match asked for (MatchSetup: round_s 60, to_win 2 unless the args say), Engine.time_scale ts (4).
##   the match   reaches DONE (match_over once) within the watchdog; no SCRIPT ERROR (the runner counts them)
##   the rules   no self ring-out (every ring-out credited to a knocker of the other side, never none or one's own)
##   both sides  each side's bot casts (only its own element's moves, Mend and Patch)
##   metrics     printed, not gated (balance by data: data/sway/moves.json, data/ring/rules.json, data/npc/bend_ai.json):
##               "METRIC pair=<a>-<b> ring_out_ratio=<ring-outs / rounds>" (the target is about 0.6: more ring-outs than
##               time-outs), the rounds' whys, the casts by move per side (and each move's share of all its side's casts:
##               no move should dominate), catches and answers per side, knocks landed per side, the walls raised and those
##               capped (rules.json max_walls) per side
## The clock: BendStatus.now() counts physics frames, so under ts 4 its timers (the bots' rests, cools, reactions and
## opening grace; roots, slows) last 4 times as long in game time as the locks and flights do. ts=1 is the game's own pace
## (headless with a fixed fps it runs unthrottled anyway: a match in a few seconds); read the balance there.
## In-test watchdog LIMIT_S real seconds (under the runner's GODOT_TIMEOUT 420). Last line "RING SOAK PASSED" or "... FAILED".

const NAME := "RING SOAK"
const LIMIT_S := 400.0
const PARK := Vector3(0.0, 60.0, 400.0)

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var ts := 4.0
var mate: NpcFighter
var mate_squad: NpcSquad
var rounds: Array = []
var outs: Array = []
var matches: Array = []
## Per side (0 the player's, the mate bot; 1 the foe): casts by "move/mode", catches, answered, reactions, lost, walls, capped.
var by_side: Array = [{}, {}]
var tallies: Array = [{"casts": 0, "catches": 0, "answered": 0, "lost": 0, "walls": 0, "capped": 0, "reactions": {}}, {"casts": 0, "catches": 0, "answered": 0, "lost": 0, "walls": 0, "capped": 0, "reactions": {}}]
var knocks := Vector2i.ZERO
var _seed := 9100


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
		_metrics()
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with("ts=") and kv.get_slice("=", 1).is_valid_float():
			ts = float(kv.get_slice("=", 1))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.round_s = 60.0
	MatchSetup.rounds_to_win = 2
	MatchSetup.incoming = true
	node_added.connect(_on_node_added)
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


## Walls raised (FormRaised kind "wall", earth and ice: the cap's) counted per side as they rise, and those capped.
func _on_node_added(nd: Node) -> void:
	if not (nd is FormRaised):
		return
	(func() -> void:
		if not is_instance_valid(nd):
			return
		var fr := nd as FormRaised
		if fr.kind != "wall" or mode == null:
			return
		var side := _side_of_id(int(fr.get_meta(&"bend_by", -1)))
		if side < 0:
			return
		tallies[side]["walls"] = int(tallies[side]["walls"]) + 1
		fr.crumbled.connect(func(_r: FormRaised, why: String) -> void:
			if why == "capped":
				tallies[side]["capped"] = int(tallies[side]["capped"]) + 1)).call_deferred()


func _side_of_id(id: int) -> int:
	if mate != null and is_instance_valid(mate) and mate.get_instance_id() == id:
		return 0
	if mode != null and mode.foe != null and is_instance_valid(mode.foe) and mode.foe.get_instance_id() == id:
		return 1
	return -1


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(mode != null and player != null, "the ring with a match")
	if mode == null or player == null:
		return _end()
	mode.phase_changed.connect(_on_phase)
	mode.round_over.connect(_on_round_over)
	mode.rang_out.connect(func(who: Node3D, by: Node) -> void:
		var by_side := mode.side_of(by) if by != null and is_instance_valid(by) else -1
		outs.append([mode.side_of(who), by_side, who == by])
		if by_side < 0 or who == by or by_side == mode.side_of(who):
			# (what it was doing: its last cast and how long since it was last knocked)
			var b: NpcBending = (who as NpcFighter).brain.bending if who is NpcFighter and (who as NpcFighter).brain != null else null
			var kn := BendKnock.peek(who)
			print("  SELF OUT side %d: last cast %s, casting '%s', %.2f s since a knock, at %s, v %s" % [mode.side_of(who),
					b.last_cast if b else {}, b.casting if b else "", BendStatus.now() - kn.last_knock_at if kn else INF,
					who.global_position, (who as CharacterBody3D).velocity if who is CharacterBody3D else Vector3.ZERO]))
	mode.match_over.connect(func(w: int) -> void: matches.append(w))
	if mode.phase == "COUNTDOWN":
		_spectate()                          # (the first round's countdown began before the hooks)
	print("  pair %s vs %s, %s, round_s %.0f, to_win %d, ts %.1f" % [mode.element, mode.foe_element, mode.difficulty, mode.round_s, mode.to_win, ts])
	if not is_equal_approx(ts, 1.0):
		# (BendStatus.now() counts physics frames, not scaled time: at ts 4 every clock on it (the bots' rests, cools and
		# reactions, roots and slows) runs 4 times long in game time; the balance metrics are the game's own at ts=1)
		print("  (note: ts %.1f stretches the bend clock's timers %.0fx in game time; read the balance at ts=1)" % [ts, ts])
	Engine.time_scale = ts
	var t0 := Time.get_ticks_msec()
	var game_t := 0.0
	while mode.phase != "DONE" and game_t < 1500.0:
		await physics_frame
		game_t += 1.0 / Engine.physics_ticks_per_second * Engine.time_scale
		if player != null and is_instance_valid(player) and player.global_position.distance_to(PARK) > 1.0 and mode.phase != "DONE":
			_park()
	Engine.time_scale = 1.0
	print("  (%.0f s of the game in %.0f s)" % [game_t, (Time.get_ticks_msec() - t0) / 1000.0])
	_expect(mode.phase == "DONE", "the match reaches DONE (%s, round %d, score %s)" % [mode.phase, mode.round, mode.score])
	_expect(matches.size() == 1, "match_over once (%s)" % [matches])
	var selfs := 0
	for o in outs:
		if int(o[1]) < 0 or bool(o[2]) or int(o[1]) == int(o[0]):
			selfs += 1
	_expect(selfs == 0 and mode.self_outs == 0, "no self ring-out (%d of %d ring-outs; the mode's count %d)" % [selfs, outs.size(), mode.self_outs])
	var els := [mode.element, mode.foe_element]
	for side in 2:
		var own := {}
		for pair in Bending.keys(String(els[side])):
			for id: String in pair:
				own[id] = true
		var foreign: Array = []
		for k: String in by_side[side]:
			var id := k.get_slice("/", 0)
			if not own.has(id) and not id in ["mend", "patch"]:
				foreign.append(k)
		_expect(int(tallies[side]["casts"]) > 0 and foreign.is_empty(), "side %d (%s) casts its own element's moves (%d casts; not its own: %s)"
				% [side, els[side], int(tallies[side]["casts"]), foreign])
	_metrics()
	_end()


# ---------------------------------------------------------------- spectate
## Each round's countdown: the player out of the rules and parked out of sight; a bot of his element on his side, held.
func _on_phase(ph: String) -> void:
	match ph:
		"COUNTDOWN":
			_spectate()
		"FIGHT":
			_go_fight.call_deferred()
		"OVER", "DONE":
			if mate != null and is_instance_valid(mate):
				mate.held = true


func _park() -> void:
	player.global_position = PARK
	player.velocity = Vector3.ZERO


func _spectate() -> void:
	var rules := mode.rules
	var pid := player.get_instance_id()
	if rules.state.has(pid):
		rules.state.erase(pid)
	(rules.sides[0] as Array).erase(player)
	player.is_dead = true                    # (no bot fights him: NpcSenses.can_fight)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_park()
	_drop_mate()
	var ring := mode.ring
	var xf := ring.spawn(mode.player_end, int(RingRules.num("bot_slot", 0.0)))
	_seed += 13
	var opts := {"face": xf.origin - xf.basis.z * 10.0, "tag": "ring", "tactics": "bend", "element": mode.element,
			"weapon": "", "sidearm": "", "skill": mode.difficulty, "seed": _seed, "y": ring.deck_y()}
	mate_squad = NpcSquad.spawn(lvl, RingMode.FACTIONS[0], 1, xf.origin, opts)
	mate = mate_squad.members[0] if mate_squad != null and not mate_squad.members.is_empty() else null
	if mate == null:
		_expect(false, "a bot for the player's side")
		return
	mate.flees = false
	mate.calm_s = INF
	mate.held = true
	mate.no_death = true
	mate.set(&"element", mode.element)
	Bending.of(mate).element = mode.element
	rules.add(mate, 0)
	var bend := mate.brain.bending
	if bend != null:
		bend.bounds_fn = rules.bounds_fn_for(mate)
		bend.edge_fn = rules.edge_along


func _go_fight() -> void:
	if mate == null or not is_instance_valid(mate) or mode.foe == null or not is_instance_valid(mode.foe):
		return
	mate.held = false
	mate.brain.told(mode.foe, mode.foe.global_position)
	mode.foe.brain.told(mate, mate.global_position)


func _drop_mate() -> void:
	if mate_squad != null and is_instance_valid(mate_squad):
		if mate_squad.get_parent() != null:
			mate_squad.get_parent().remove_child(mate_squad)
		mate_squad.queue_free()
	mate_squad = null
	mate = null


# ---------------------------------------------------------------- the counts
func _on_round_over(r: String, why: String) -> void:
	rounds.append([mode.round, r, why, mode.round_left_s()])
	knocks += mode.rules.knocks
	var bots: Array = [mate, mode.foe]
	for side in 2:
		var f: Variant = bots[side]
		if f == null or not is_instance_valid(f) or (f as NpcFighter).brain == null or (f as NpcFighter).brain.bending == null:
			continue
		var b := (f as NpcFighter).brain.bending
		tallies[side]["casts"] = int(tallies[side]["casts"]) + b.casts
		tallies[side]["catches"] = int(tallies[side]["catches"]) + b.catches
		tallies[side]["answered"] = int(tallies[side]["answered"]) + b.answered
		tallies[side]["lost"] = int(tallies[side]["lost"]) + b.lost
		for k: String in b.reactions_by:
			tallies[side]["reactions"][k] = int(tallies[side]["reactions"].get(k, 0)) + int(b.reactions_by[k])
		for k: String in b.casts_by:
			by_side[side][k] = int(by_side[side].get(k, 0)) + int(b.casts_by[k])
	print("  round %d: %s by %s (%.0f s left, score %s, knocks %s)" % [mode.round, r, why, mode.round_left_s(), mode.score, mode.rules.knocks])


func _metrics() -> void:
	if mode == null:
		return
	var pair := "%s-%s" % [mode.element, mode.foe_element]
	var ratio := float(mode.ringouts) / float(maxi(mode.rounds_played, 1))
	var whys: Array = []
	var timeouts := 0
	for r in rounds:
		whys.append(String(r[2]))
		if String(r[2]) in ["territory", "health", "time"]:
			timeouts += 1
	print("METRIC pair=%s ring_out_ratio=%.2f (%d of %d rounds; time-outs %d) score=%s winner=%d" % [pair, ratio, mode.ringouts,
			mode.rounds_played, timeouts, mode.score, mode.winner])
	print("METRIC pair=%s whys=%s knocks=%s" % [pair, whys, knocks])
	for side in 2:
		var tl: Dictionary = tallies[side]
		var top := ""
		var top_n := 0
		for k: String in by_side[side]:
			if int(by_side[side][k]) > top_n:
				top_n = int(by_side[side][k])
				top = k
		var share := float(top_n) / float(maxi(int(tl.casts), 1))
		print("METRIC pair=%s side=%d el=%s casts=%d catches=%d answered=%d lost=%d walls=%d capped=%d top=%s share=%.2f reactions=%s"
				% [pair, side, [mode.element, mode.foe_element][side], int(tl.casts), int(tl.catches), int(tl.answered), int(tl.lost),
				int(tl.walls), int(tl.capped), top, share, tl.reactions])
		print("METRIC pair=%s side=%d by_move=%s" % [pair, side, by_side[side]])
