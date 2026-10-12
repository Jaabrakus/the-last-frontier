extends SceneTree
## The fairness gate for the Advancement window's live loadouts (docs/tidebreak/loadouts_live.md; BendLoadout): mirror matches in
## the % ring (lives), the same element on both sides, bots both sides, one side wearing ONE live node (or all the live nodes of its
## element together) and the other Classic, the wearer alternating sides game by game (the sides are not equal: the end swaps each
## round, but one bot is the player's-side mate and one the match's foe) to cancel the side bias. It is tests/ring/test_ring_soak.gd's
## spectate (the player parked out of the rules, a bot of the element on his side, new each round) with several games to a run: after a
## game's DONE the same match restarts (RingMode.restart: lives full, the seeds moved on).
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/loadout_soak.gd -- element=air nodes=air.slice.keen \
##       [n=30] [seed=7300] [difficulty=normal] [start_side=0] [round_s=480] [ts=1]
##   element=<e>   both sides' element (a mirror); nodes=<id,id> the wearer's picks, or nodes=all for every live node of that element
##                 that one loadout may wear together (the skill tree's excludes: of two that exclude each other the first in the
##                 live list stays, the other is named on an "LSOAK nodes=all" line and not worn)
##   n=<count>     games in this run (a game is one match: 3 lives each; not games=, which is MatchSetup's own key: best of 3);
##                 start_side= which side wears in game 0, then alternating
##   Every node asked for is forced on here whatever loadout_apply.json's switches say (the soak is what flips them); a node that
##   cannot be applied (BendLoadout.resolve refuses it) is reported and nothing is worn.
## Lines (grep LSOAK): one per game, then the result:
##   LSOAK game=<i> wearer_side=<0|1> winner=<0|1|-1> wearer_won=<1|0|draw> game_s=<game seconds> lives_lost=<wearer>/<other> seed=<n>
##   LSOAK RESULT element= nodes= games= wearer_wins= draws= rate= (draws count half) side0=<wins>/<games> side1=<wins>/<games>
##       lives_lost_wearer= lives_lost_other= casts_wearer= casts_other= gate=<in|out> (0.40-0.60 under 60 games, 0.45-0.55 from 60)
##   LSOAK ANOMALY ... for a game that stalled (the watchdog), a side that never cast, a self ring-out
## Ends with "LOADOUT SOAK DONE" (exit 0) or "LOADOUT SOAK FAILED" (exit 1: no match, no bot, a stall). Writes nothing.

const NAME := "LOADOUT SOAK"
const GAME_LIMIT_S := 1500.0

var el := "air"
var picks: Array = []
var games := 10
var start_side := 0
var ts := 1.0
var _seed := 7300
var _mate_seed := 9100
var difficulty := "normal"
var round_s := 480.0
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var mate: NpcFighter
var mate_squad: NpcSquad
var wearer_side := 0
var kos := [0, 0]
var results: Array = []
var anomalies: Array[String] = []
var casts := [0, 0]
var _casts_seen := {}
## The wearer's casts of the node's own moves (move/mode keys the picks change), summed; and how often the loadout was found worn
## (applied) or missing (missed) at a round's start.
var node_keys: Array[String] = []
var node_casts := 0
var _by_seen := {}
var applied := 0
var missed := 0


func _initialize() -> void:
	seed(1750)
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var k := kv.get_slice("=", 0)
		var v := kv.get_slice("=", 1)
		match k:
			"element":
				el = v
			"nodes":
				picks = Array(v.split(",", false)) if v != "all" else ["all"]
			"n":
				games = maxi(int(v), 1)
			"start_side":
				start_side = int(v) % 2
			"seed":
				_seed = int(v)
				_mate_seed = int(v) + 1800
			"difficulty":
				difficulty = v
			"round_s":
				round_s = float(v)
			"ts":
				ts = float(v)
	if not el in Bending.ELEMENTS:
		print("%s FAILED (element=%s)" % [NAME, el])
		quit(1)
		return
	var all_asked := picks == ["all"]
	if all_asked:
		picks = []
		for id: String in BendLoadout.config().get("live", []):
			if id.get_slice(".", 0) == el and bool(BendLoadout.resolve(id).ok):
				picks.append(id)
	# every node asked for is on here (the soak is what decides a switch), and nothing else
	var forced := {}
	for id: Variant in picks:
		forced[String(id)] = true
	BendLoadout.config_override = {"enabled": true, "live": picks.duplicate(), "nodes": forced}
	if all_asked:
		# (nodes=all: the element's live nodes as one loadout may wear them together; the skill tree's excludes keep a later pick
		# from an earlier one (Heave or Fuming Column, Thick or Brimstone Wall, Heavy or Sulphur Boulder): the first stays)
		var ov_all := BendLoadout.overlay_for(picks, el)
		for id: Variant in (ov_all.refused as Dictionary):
			if String((ov_all.refused as Dictionary)[id]).begins_with("exclude"):
				print("LSOAK nodes=all: %s not worn with the others (%s)" % [id, (ov_all.refused as Dictionary)[id]])
				picks.erase(id)
				forced.erase(id)
		BendLoadout.config_override = {"enabled": true, "live": picks.duplicate(), "nodes": forced}
	var refused: Array = []
	for id: Variant in picks:
		if not bool(BendLoadout.resolve(String(id)).ok):
			refused.append("%s (%s)" % [id, BendLoadout.resolve(String(id)).why])
	if not refused.is_empty():
		print("LSOAK ANOMALY nodes refused, nothing to wear: %s" % [refused])
		print("%s FAILED (a node cannot be applied)" % NAME)
		quit(1)
		return
	for id: Variant in picks:
		var r := BendLoadout.resolve(String(id))
		for part: String in ["spec", "lock"]:
			for k: String in (r[part] as Dictionary):
				if not k in node_keys:
					node_keys.append(k)
		if not (r.wall as Dictionary).is_empty() and not "earth_wall/wall" in node_keys:
			node_keys.append("earth_wall/wall")
		if not (r.ice as Dictionary).is_empty() and not "water_shield/ice_wall" in node_keys:
			node_keys.append("water_shield/ice_wall")
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = el
	MatchSetup.foes = [el]
	MatchSetup.difficulty = difficulty
	MatchSetup.round_s = round_s
	MatchSetup.rounds_to_win = 1
	MatchSetup.games_n = 1
	node_added.connect(_on_node_added)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _finish(ok: bool) -> void:
	Engine.time_scale = 1.0
	BendLoadout.config_override = {}
	print("%s %s" % [NAME, "DONE" if ok else "FAILED"])
	quit(0 if ok else 1)


## Counts the casts of each side as their bolts and things appear is not needed: the bots' own books say it (casts_by).
func _on_node_added(_nd: Node) -> void:
	pass


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	if mode == null or player == null:
		print("LSOAK ANOMALY no ring match")
		return _finish(false)
	if not RingRules.stock_on():
		print("LSOAK ANOMALY the ring does not play the %% rules (%s)" % [RingRules.current().rule_set if RingRules.current() != null else "?"])
		return _finish(false)
	mode.phase_changed.connect(_on_phase)
	mode.rules.ko.connect(_on_ko)
	mode.round_over.connect(func(_r: String, _why: String) -> void: _tally_casts())
	if mode.phase == "COUNTDOWN":
		_spectate()
	Engine.time_scale = ts
	var wins := 0.0
	var side_w: Array[int] = [0, 0]
	var side_n: Array[int] = [0, 0]
	var draws := 0
	var lives: Array[int] = [0, 0]             # [wearer, other] lives lost over the games
	var ok := true
	for g in games:
		wearer_side = (start_side + g) % 2
		kos = [0, 0]
		if g > 0:
			# the next game of the same match: seeds moved on, lives full
			mode._seed = _seed + g * 101
			mode._rng.seed = mode._seed
			mode._drop_foe()                  # (a new bot each game: no knock credit, mind or zone of the last game's bots left on it)
			mode.restart()
			await physics_frame
		else:
			mode._seed = _seed
			mode._rng.seed = _seed
		_outfit()
		var game_t := 0.0
		while mode.phase != "DONE" and game_t < GAME_LIMIT_S:
			await physics_frame
			game_t += 1.0 / Engine.physics_ticks_per_second * Engine.time_scale
			if player != null and is_instance_valid(player) and player.global_position.distance_to(Vector3(0.0, 60.0, 400.0)) > 1.0 and mode.phase != "DONE":
				_park()
		if mode.phase != "DONE":
			anomalies.append("game %d stalled at round %d phase %s after %.0f s" % [g, mode.round, mode.phase, game_t])
			print("LSOAK ANOMALY %s" % anomalies.back())
			ok = false
			break
		var w := mode.winner
		var won := "draw" if w < 0 else ("1" if w == wearer_side else "0")
		side_n[wearer_side] += 1
		if w < 0:
			draws += 1
			wins += 0.5
		elif w == wearer_side:
			wins += 1.0
			side_w[wearer_side] += 1
		lives[0] += int(kos[wearer_side])
		lives[1] += int(kos[1 - wearer_side])
		print("LSOAK game=%d wearer_side=%d winner=%d wearer_won=%s game_s=%.0f lives_lost=%d/%d seed=%d" % [g, wearer_side, w, won, game_t,
				kos[wearer_side], kos[1 - wearer_side], mode._seed])
		if mode.self_outs > 0:
			print("LSOAK ANOMALY game %d: %d self ring-out(s)" % [g, mode.self_outs])
		_tally_casts()
	Engine.time_scale = 1.0
	var n: int = int(side_n[0]) + int(side_n[1])
	var rate := wins / float(maxi(n, 1))
	var lo := 0.40 if n < 60 else 0.45
	var hi := 0.60 if n < 60 else 0.55
	for side in 2:
		if n >= 4 and int(casts[side]) == 0:
			print("LSOAK ANOMALY side %d never cast" % side)
	if not picks.is_empty() and missed > 0:
		print("LSOAK ANOMALY the loadout was missing from the wearer %d time(s) of %d" % [missed, applied + missed])
		anomalies.append("loadout missing")
	print("LSOAK RESULT element=%s nodes=%s games=%d wearer_wins=%.1f draws=%d rate=%.3f side0=%d/%d side1=%d/%d lives_lost_wearer=%d lives_lost_other=%d casts_wearer=%d casts_other=%d node_casts_wearer=%d (%s) worn_ok=%d/%d gate=%s"
			% [el, ",".join(PackedStringArray(picks)), n, wins, draws, rate, side_w[0], side_n[0], side_w[1], side_n[1], lives[0], lives[1],
			casts[0], casts[1], node_casts, ",".join(PackedStringArray(node_keys)), applied, applied + missed, "in" if rate >= lo and rate <= hi else "out"])
	_finish(ok and anomalies.is_empty())


## Each round's countdown: the player parked, a bot of his element on his side, then the loadouts.
func _on_phase(ph: String) -> void:
	match ph:
		"COUNTDOWN":
			_spectate()
			_outfit()
		"FIGHT":
			_go_fight.call_deferred()
		"OVER", "DONE":
			if mate != null and is_instance_valid(mate):
				mate.held = true


func _on_ko(b: Node3D, _by: Node, _pct: float, _tag: String, _left: int) -> void:
	var s := mode.side_of(b)
	if s >= 0:
		kos[s] = int(kos[s]) + 1


func _park() -> void:
	player.global_position = Vector3(0.0, 60.0, 400.0)
	player.velocity = Vector3.ZERO


func _spectate() -> void:
	var rules := mode.rules
	var pid := player.get_instance_id()
	if rules.state.has(pid):
		rules.state.erase(pid)
	(rules.sides[0] as Array).erase(player)
	player.is_dead = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_park()
	_drop_mate()
	var ring := mode.ring
	var xf := ring.spawn(mode.player_end, int(RingRules.num("bot_slot", 0.0)))
	_mate_seed += 13
	var opts := {"face": xf.origin - xf.basis.z * 10.0, "tag": "ring", "tactics": "bend", "element": mode.element,
			"weapon": "", "sidearm": "", "skill": mode.difficulty, "seed": _mate_seed, "y": ring.deck_y()}
	mate_squad = NpcSquad.spawn(lvl, RingMode.FACTIONS[0], 1, xf.origin, opts)
	mate = mate_squad.members[0] if mate_squad != null and not mate_squad.members.is_empty() else null
	if mate == null:
		anomalies.append("no bot for the player's side")
		return
	mate.flees = false
	mate.calm_s = INF
	mate.held = true
	mate.no_death = true
	mate.set(&"element", mode.element)
	Bending.of(mate).element = mode.element
	mode.join(mate, 0)
	var bend := mate.brain.bending
	if bend != null:
		bend.bounds_fn = rules.bounds_fn_for(mate)
		bend.edge_fn = rules.edge_along


## The wearer's side gets the picks, the other side none (a new bot each round on side 0, the kept or new foe on side 1).
func _outfit() -> void:
	var bodies: Array = [mate, mode.foe]
	for side in 2:
		var b: Variant = bodies[side]
		if b == null or not is_instance_valid(b):
			continue
		if side == wearer_side:
			BendLoadout.wear(b as Node, picks, "", el)
			if not picks.is_empty():
				if BendLoadout.picks_of(b as Node).size() == picks.size() and BendLoadout.style_meta(b as Node) == "":
					applied += 1
				else:
					missed += 1
		else:
			BendLoadout.clear(b as Node)
			if not BendLoadout.overlay_of(b as Node).is_empty():
				missed += 1


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


## The casts of each bot so far (its own book, since its last count), by wearer and other.
func _tally_casts() -> void:
	var bots: Array = [mate, mode.foe]
	for side in 2:
		var f: Variant = bots[side]
		if f == null or not is_instance_valid(f) or (f as NpcFighter).brain == null or (f as NpcFighter).brain.bending == null:
			continue
		var b := (f as NpcFighter).brain.bending
		var id := b.get_instance_id()
		var was := int(_casts_seen.get(id, 0))
		var role := 0 if side == wearer_side else 1
		casts[role] = int(casts[role]) + int(b.casts) - was
		_casts_seen[id] = int(b.casts)
		if role == 0:
			var seen: Dictionary = _by_seen.get(id, {})
			for k: String in node_keys:
				node_casts += int(b.casts_by.get(k, 0)) - int(seen.get(k, 0))
		_by_seen[id] = b.casts_by.duplicate()
