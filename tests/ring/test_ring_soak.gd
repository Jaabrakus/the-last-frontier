extends SceneTree
## A Tidebreak soak with bots on both sides (spectate: the player parked off the deck, out of the rules and out of every
## bot's sight; a bot of his element fights in his place on his side, ring_team_a, each round a new one as the mode's foe is),
## one pairing per run, played fast to the end of the match:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_soak.gd -- mode=ring element=earth foe=water
##         [round_s=60] [to_win=2 | rounds=2] [ts=4] [difficulty=normal] [seed=7300]
## The ring scene with the match asked for (MatchSetup: round_s 60, to_win 2 unless the args say), Engine.time_scale ts (4).
## seed= (RingMode's: the foe's rolls) seeds the player's-side bot too (seed + 1800), so a pairing's seeds are distinct runs.
##   the match   reaches DONE (match_over once) within the watchdog; no SCRIPT ERROR (the runner counts them)
##   the rules   no self ring-out (every ring-out credited to a knocker of the other side, never none or one's own)
##   both sides  each side's bot casts (only its own element's kit: its keys' moves, its guard and its jab; round 2)
##   metrics     printed, not gated (balance by data: data/sway/moves.json, data/ring/rules.json, data/npc/bend_ai.json):
##               "METRIC pair=<a>-<b> ring_out_ratio=<ring-outs / rounds>" (the target is about 0.6: more ring-outs than
##               time-outs), the rounds' whys, the casts by move per side (and each move's share of all its side's casts:
##               no move should dominate), catches and answers per side, knocks landed per side, the walls raised and those
##               capped (rules.json max_walls) per side; the knocks landed per side by the knocker's last release (its move: a
##               bolt in flight is its last release's, near enough) with their summed m/s as applied, and the move behind each
##               ring-out (its last knock's); the health it took off the other side by its last release (dmg_by: a drop polled
##               each frame, the winding blow itself missed), the zone lines each side was pushed over (pushed) and its
##               windings (winded), its strikes (hits), its bolts' damage by kind (bolt_dmg, sent_back: bolts a guard of its
##               turned on their caster) and its held-and-hurled stones' (lift_dmg: Gust lift's, Earth Shove's, by the stone's
##               kind). R1-BALANCE (2026-10-05) read with these that air won on the deck's socket cannonballs (lifted, about 110
##               a strike) more than on knocks. Round 2 (KITS): per side its guards (clean catches, perfect, late, whiffs), its
##               returns (a caught stone sent back by its guard again) and the longest rally (one stone's returns), its locks
##               pushed back by hits (setbacks), the waves along the deck it saw and jumped, the casts held to grow (grows_by)
##               and the kit's moves it never cast (uncast; tools: scratchpad kits/soak_report.py reads them over every run)
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
var tallies: Array = [_tally(), _tally()]
## Per side: casts held to grow by "move/mode" (round 2's ▲).
var grows_by: Array = [{}, {}]
## The most times one stone was sent back (NpcBending.RALLY_META on it: every return of it, by either side).
var longest_rally := 0
var knocks := Vector2i.ZERO
var _seed := 9100
## Per side: "move/mode" -> [knocks landed, their summed m/s as applied]; the ring-outs by the move of the last knock; the
## health it took off the other side by its last release (polled each frame: a drop in the other's health).
var knock_by: Array = [{}, {}]
var dmg_by: Array = [{}, {}]
## Per side: zone lines it was pushed back over by a knock, and by being winded (RingRules.knocked_back, winded).
var pushed := [0, 0]
## Per side: bolt damage dealt by its kind, and the part of it from bolts sent back (a guard's: the bolt was the other's).
var bolt_dmg: Array = [{}, {}]
var back_dmg := [0.0, 0.0]
## Per side: damage dealt by held-and-hurled stones (GustLift: Gust lift's, Earth Shove's, a stone form's), by its kind.
var lift_dmg: Array = [{}, {}]
var winds := [0, 0]
var _hp := [-1.0, -1.0]
var out_by: Array = [{}, {}]
var _last_knock := {}


static func _tally() -> Dictionary:
	return {"casts": 0, "hits": 0, "catches": 0, "clean": 0, "answered": 0, "perfect": 0, "late": 0, "whiff": 0, "returns": 0,
			"lost": 0, "setbacks": 0, "walls": 0, "capped": 0, "floor_seen": 0, "floor_jumped": 0, "reactions": {}}


## A BendKnock listener (its group): every knock in the ring told to the soak's tally.
class KnockTap:
	extends Node
	var cb: Callable

	func on_knocked(n: Node, v: Vector3, by: Node) -> void:
		cb.call(n, v, by)


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
		elif kv.begins_with("seed=") and kv.get_slice("=", 1).is_valid_int():
			_seed = int(kv.get_slice("=", 1)) + 1800
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
	if nd is BendBolt:
		var bb := nd as BendBolt
		(func() -> void:
			if not is_instance_valid(bb):
				return
			var first := bb.caster.get_instance_id() if bb.caster != null and is_instance_valid(bb.caster) else 0
			bb.struck.connect(func(_who: Node, dmg: float) -> void:
				var cid := bb.caster.get_instance_id() if bb.caster != null and is_instance_valid(bb.caster) else 0
				var sd := _side_of_id(cid)
				if sd < 0:
					return
				bolt_dmg[sd][bb.kind] = float(bolt_dmg[sd].get(bb.kind, 0.0)) + dmg
				if cid != first:
					back_dmg[sd] += dmg)).call_deferred()
		return
	if nd is GustLift:
		var gl := nd as GustLift
		gl.struck.connect(func(_who: Node, dmg: float) -> void:
			var by := gl.by()
			var sd := _side_of_id(by.get_instance_id()) if by != null else -1
			if sd >= 0:
				lift_dmg[sd][gl.kind] = float(lift_dmg[sd].get(gl.kind, 0.0)) + dmg)
		return
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
	var tap := KnockTap.new()
	tap.cb = _on_knocked
	tap.add_to_group(BendKnock.LISTENERS)
	root.add_child(tap)
	mode.round_over.connect(_on_round_over)
	mode.rang_out.connect(func(who: Node3D, by: Node) -> void:
		var by_side := mode.side_of(by) if by != null and is_instance_valid(by) else -1
		if by_side >= 0:
			var lk := String(_last_knock.get(who.get_instance_id(), "?"))
			out_by[by_side][lk] = int(out_by[by_side].get(lk, 0)) + 1
		outs.append([mode.side_of(who), by_side, who == by])
		if by_side < 0 or who == by or by_side == mode.side_of(who):
			# (what it was doing: its last cast and how long since it was last knocked)
			var b: NpcBending = (who as NpcFighter).brain.bending if who is NpcFighter and (who as NpcFighter).brain != null else null
			var kn := BendKnock.peek(who)
			print("  SELF OUT side %d: last cast %s, casting '%s', %.2f s since a knock, at %s, v %s" % [mode.side_of(who),
					b.last_cast if b else {}, b.casting if b else "", BendStatus.now() - kn.last_knock_at if kn else INF,
					who.global_position, (who as CharacterBody3D).velocity if who is CharacterBody3D else Vector3.ZERO]))
	mode.match_over.connect(func(w: int) -> void: matches.append(w))
	mode.rules.knocked_back.connect(func(who: Node3D, from_z: int, to_z: int) -> void:
		var sd := mode.side_of(who)
		if sd >= 0:
			pushed[sd] += maxi(to_z - from_z, 0))
	mode.rules.winded.connect(func(who: Node3D, _by: Node, _to: int) -> void:
		var sd := mode.side_of(who)
		if sd >= 0:
			winds[sd] += 1)
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
		_poll_hurt()
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
		for pr: Array in NpcBending.pairs_of(String(els[side])):
			own["%s/%s" % pr] = true
		var foreign: Array = []
		for k: String in by_side[side]:
			if not own.has(k):
				foreign.append(k)
		_expect(int(tallies[side]["casts"]) > 0 and foreign.is_empty(), "side %d (%s) casts its own kit's moves (%d casts; not its own: %s)"
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
## Each frame in a fight: a drop in either bot's health counted for the other side by that side's last release.
func _poll_hurt() -> void:
	var bots: Array = [mate, mode.foe]
	for side in 2:
		var f: Variant = bots[side]
		if f == null or not is_instance_valid(f) or mode.phase != "FIGHT":
			_hp[side] = -1.0
			continue
		var hp := (f as NpcFighter).health
		var other: Variant = bots[1 - side]
		if _hp[side] >= 0.0 and hp < _hp[side] - 0.01 and other != null and is_instance_valid(other) and (other as NpcFighter).brain != null:
			var lc: Dictionary = (other as NpcFighter).brain.bending.last_cast
			var k := "%s/%s" % [lc.get("move", "?"), lc.get("mode", "")]
			dmg_by[1 - side][k] = float(dmg_by[1 - side].get(k, 0.0)) + _hp[side] - hp
		_hp[side] = hp


## A knock landed (BendKnock's listeners): counted for the knocker's side by its last release's move.
func _on_knocked(n: Node, v: Vector3, by: Node) -> void:
	if mode == null or by == null or not is_instance_valid(by) or not (by is NpcFighter):
		return
	var side := _side_of_id(by.get_instance_id())
	var f := by as NpcFighter
	if side < 0 or f.brain == null or f.brain.bending == null:
		return
	var lc: Dictionary = f.brain.bending.last_cast
	var k := "%s/%s" % [lc.get("move", "?"), lc.get("mode", "")]
	var e: Array = knock_by[side].get(k, [0, 0.0])
	knock_by[side][k] = [int(e[0]) + 1, float(e[1]) + v.length()]
	_last_knock[n.get_instance_id()] = k


func _on_round_over(r: String, why: String) -> void:
	rounds.append([mode.round, r, why, mode.round_left_s()])
	knocks += mode.rules.knocks
	var bots: Array = [mate, mode.foe]
	for side in 2:
		var f: Variant = bots[side]
		if f == null or not is_instance_valid(f) or (f as NpcFighter).brain == null or (f as NpcFighter).brain.bending == null:
			continue
		var b := (f as NpcFighter).brain.bending
		# (the same bot is kept across rounds (RingMode._keep_foe): its counts run on, so each round adds what is new)
		var was: Dictionary = b.get_meta(&"soak_counted", {})
		var now := {"casts": b.casts, "hits": b.hits, "catches": b.catches, "clean": b.clean_catches, "answered": b.answered,
				"perfect": b.perfects, "late": b.lates, "whiff": b.whiffs, "returns": b.returns, "lost": b.lost,
				"setbacks": b.setbacks, "floor_seen": b.floor_seen, "floor_jumped": b.floor_jumped}
		for k: String in now:
			tallies[side][k] = int(tallies[side][k]) + int(now[k]) - int(was.get(k, 0))
		var was_r: Dictionary = was.get("reactions", {})
		for k: String in b.reactions_by:
			tallies[side]["reactions"][k] = int(tallies[side]["reactions"].get(k, 0)) + int(b.reactions_by[k]) - int(was_r.get(k, 0))
		var was_c: Dictionary = was.get("casts_by", {})
		for k: String in b.casts_by:
			by_side[side][k] = int(by_side[side].get(k, 0)) + int(b.casts_by[k]) - int(was_c.get(k, 0))
		var was_g: Dictionary = was.get("grows_by", {})
		for k: String in b.grows_by:
			grows_by[side][k] = int(grows_by[side].get(k, 0)) + int(b.grows_by[k]) - int(was_g.get(k, 0))
		now["reactions"] = b.reactions_by.duplicate()
		now["casts_by"] = b.casts_by.duplicate()
		now["grows_by"] = b.grows_by.duplicate()
		b.set_meta(&"soak_counted", now)
		longest_rally = maxi(longest_rally, b.longest_rally)
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
	print("METRIC pair=%s whys=%s knocks=%s longest_rally=%d" % [pair, whys, knocks, longest_rally])
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
		print("METRIC pair=%s side=%d guards clean=%d perfect=%d late=%d whiff=%d returns=%d setbacks=%d floor_seen=%d floor_jumped=%d"
				% [pair, side, int(tl.clean), int(tl.perfect), int(tl.late), int(tl.whiff), int(tl.returns), int(tl.setbacks),
				int(tl.floor_seen), int(tl.floor_jumped)])
		var uncast: Array = []
		for pr: Array in NpcBending.pairs_of(String([mode.element, mode.foe_element][side])):
			if not by_side[side].has("%s/%s" % pr):
				uncast.append("%s/%s" % pr)
		print("METRIC pair=%s side=%d by_move=%s" % [pair, side, by_side[side]])
		print("METRIC pair=%s side=%d grows_by=%s uncast=%s" % [pair, side, grows_by[side], uncast])
		var kb := {}
		for k: String in knock_by[side]:
			kb[k] = "%d:%.0f" % [int(knock_by[side][k][0]), float(knock_by[side][k][1])]
		print("METRIC pair=%s side=%d knock_by=%s out_by=%s" % [pair, side, kb, out_by[side]])
		var db := {}
		for k: String in dmg_by[side]:
			db[k] = int(round(float(dmg_by[side][k])))
		print("METRIC pair=%s side=%d dmg_by=%s pushed=%d winded=%d hits=%d" % [pair, side, db, pushed[side], winds[side], int(tl.hits)])
		var bd := {}
		for k: String in bolt_dmg[side]:
			bd[k] = int(round(float(bolt_dmg[side][k])))
		var ld := {}
		for k: String in lift_dmg[side]:
			ld[k] = int(round(float(lift_dmg[side][k])))
		print("METRIC pair=%s side=%d bolt_dmg=%s sent_back=%d lift_dmg=%s" % [pair, side, bd, int(round(float(back_dmg[side]))), ld])
