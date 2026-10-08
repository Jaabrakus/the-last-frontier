extends SceneTree
## Tidebreak's balance at a glance, the % ring (round 5, R5-BALANCE; R1-BALANCE's rounds check before it): bot against bot,
## every cross-element pairing in both seats (12), each played `passes` times (1), and with mirrors=1 the four mirrors too,
## all in one ring (RingMode.restart between games with MatchSetup's element and foe; the player parked off the deck as the
## soak's spectate does, a bot of his element on his side joined through RingMode.join, so it has its RingMoves as the foe
## has), at the game's own pace (ts 1; headless with a fixed fps it runs unthrottled: a game in 10-25 real seconds).
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_balance.gd -- [passes=1] [mirrors=0|1]
##         [pairs=earth-air,water-fire] [difficulty=normal] [seed=7300] [limit_s=400]
##   every game reaches DONE; no SCRIPT ERROR (the runner counts them)
##   the gate   no element takes more than MAX_SHARE (0.70) of its sample against the other elements: the lives it decided
##              (each fall credited to the knocker's element; about 30 a side at passes=1, so a lucky game does not fail it)
##              and, once it has played GAMES_MIN (24) games against the others, its games as well
##   printed    "BALANCE <el> games <won>/<played> lives <won>/<decided>", "BALANCE mirror <el> seat0 <n> seat1 <n>", and a
##              line a game ("BAL GAME a-b ..."): the winner and his seat, the game seconds, the lives each side lost, the
##              falls each side dealt by the finishing move's tag, the strings by their hits, each side's casts by move ("BAL CASTS")
##              and the launches each side landed by the hit's tag ("BAL HITS").
##              BAL SHARE prints both denominators: own-game win rate (50% aim) and share of all cross-element wins
##              (25% aim with equal participation). This smoke gate alone does not establish balance; use
##              python3 tools/ring/balance_report.py <logs> --require-balanced for the full-schedule 40–60% screen.
##              The 16 pairings x seeds table with every §12 line is the soak's (tests/ring/test_ring_soak.gd); this is the
##              quick check, and run with passes=4 three times in parallel it is round 5's fast sweep.
## When the ring plays another rule set (the classic zones), the games are played and printed and nothing is gated but DONE.
## MatchSetup._aim_help pinned (no player aims here); GameSettings.path its own file. In-test watchdog limit_s real seconds
## (the wall clock; default 400, under the runner's GODOT_TIMEOUT 420). Last line "BALANCE PASSED" or "BALANCE FAILED".

const NAME := "BALANCE"
const PARK := Vector3(0.0, 60.0, 400.0)
const MAX_SHARE := 0.70
const GAMES_MIN := 24
const ELS := ["earth", "water", "fire", "air"]
## Its own settings file (GameSettings.path), so a kept setup never leaks in or out.
const OWN_CFG := "user://test_balance.cfg"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var mate: NpcFighter
var mate_squad: NpcSquad
var passes := 1
var mirrors := false
var only_pairs: Array = []
var limit_s := 400.0
var _seed := 9100
var _done := false
var _game_t := 0.0
var _t0 := 0
## Per element: games won and played, lives won and decided (cross-element only).
var tally := {}
## Per element: mirror games won by seat 0 and seat 1, and games with no winner.
var mirror := {}
## Round 3: the ring plays the stock rules (lives).
var stock := false
## This game's books: falls dealt per side by tag, lives lost per side, strings by hits (1, 2, 3+).
var g_kos: Array = [{}, {}]
var g_lost := [0, 0]
var g_strings := [0, 0, 0]
## This game's launches each side landed, by the hit's tag (RingRules.launched).
var g_hits: Array = [{}, {}]


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	_t0 = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var v := kv.get_slice("=", 1)
		if kv.begins_with("passes=") and v.is_valid_int():
			passes = maxi(int(v), 1)
		elif kv.begins_with("seed=") and v.is_valid_int():
			_seed = int(v) + 1800
		elif kv.begins_with("mirrors="):
			mirrors = v == "1"
		elif kv.begins_with("pairs="):
			only_pairs = Array(v.split(",", false))
		elif kv.begins_with("limit_s=") and v.is_valid_float():
			limit_s = float(v)
		elif kv.begins_with("difficulty="):
			MatchSetup.difficulty = v
	# (the games run unthrottled: a game second is a few real milliseconds, so the watchdog reads the wall clock, each frame
	# of the loop; this game-time timer only backs it up)
	create_timer(limit_s * 50.0, true, false, true).timeout.connect(_watchdog)
	for el: String in ELS:
		tally[el] = {"won": 0, "played": 0, "l_won": 0, "l_decided": 0}
		mirror[el] = [0, 0, 0]
	MatchSetup._aim_help = "light"              # (no player aims here; pinned so a kept setting never matters)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.round_s = 60.0
	MatchSetup.rounds_to_win = 2
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	MatchSetup.incoming = true
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _watchdog() -> void:
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))   # (its own settings file gone on this way out too)
	GameSettings.path = GameSettings.PATH
	_report()
	print("%s FAILED (watchdog)" % NAME)
	quit(2)


func _end() -> void:
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
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
	mode.phase_changed.connect(_on_phase)
	mode.match_over.connect(func(_w: int) -> void: _done = true)
	stock = RingRules.stock_on()
	if stock:
		var r := RingRules.current()
		r.ko.connect(_on_ko)
		r.string_ended.connect(func(_by: Node, _v: Node3D, hits: int, _p: float) -> void:
			g_strings[clampi(hits, 1, 3) - 1] += 1)
		r.launched.connect(func(b: Node3D, _v: Vector3, _s: float, by: Node, tag: String) -> void:
			var ks := mode.side_of(by) if by != null and is_instance_valid(by) else -1
			if ks >= 0 and ks != mode.side_of(b):
				g_hits[ks][tag] = int(g_hits[ks].get(tag, 0)) + 1)
	else:
		print("  (the ring plays the %s rules: the games are printed, nothing but DONE gated)" % RingRules.current().rule_set)
	var pairs: Array = []
	for p in passes:
		for a: String in ELS:
			for b: String in ELS:
				if (a != b or mirrors) and (only_pairs.is_empty() or "%s-%s" % [a, b] in only_pairs):
					pairs.append([a, b])
	var played := 0
	for pr: Array in pairs:
		MatchSetup.element = String(pr[0])
		MatchSetup.foes = [String(pr[1])]
		mode._seed = _seed + played * 101          # (the foe's rolls too: RingMode seeds each round's foe from its match seed)
		_done = false
		g_kos = [{}, {}]
		g_lost = [0, 0]
		g_strings = [0, 0, 0]
		g_hits = [{}, {}]
		mode.restart()
		_game_t = 0.0
		while not _done and _game_t < 1500.0:
			await physics_frame
			_game_t += 1.0 / Engine.physics_ticks_per_second
			if Time.get_ticks_msec() - _t0 > int(limit_s * 1000.0):
				return _watchdog()
			if player.global_position.distance_to(PARK) > 1.0 and not _done:
				_park()
		if not _done:
			_expect(false, "%s vs %s reaches DONE (%s, round %d, score %s)" % [pr[0], pr[1], mode.phase, mode.round, mode.score])
			continue
		played += 1
		_count(String(pr[0]), String(pr[1]))
	_expect(played == pairs.size(), "every game played to its end (%d of %d)" % [played, pairs.size()])
	_report()
	if stock:
		for el: String in ELS:
			var t: Dictionary = tally[el]
			if int(t.played) == 0:
				continue
			var ls := float(t.l_won) / float(maxi(int(t.l_decided), 1))
			var gs := float(t.won) / float(maxi(int(t.played), 1))
			_expect(ls <= MAX_SHARE, "%s takes at most %.0f%% of the lives it decided against the others (%d/%d = %.2f; games %d/%d)"
					% [el, MAX_SHARE * 100.0, int(t.l_won), int(t.l_decided), ls, int(t.won), int(t.played)])
			if int(t.played) >= GAMES_MIN:
				_expect(gs <= MAX_SHARE, "%s takes at most %.0f%% of its %d games against the others (%.2f)"
						% [el, MAX_SHARE * 100.0, int(t.played), gs])
	_end()


## A fall credited to the knocker's side (its tag counted) and to its element (cross-element only).
func _on_ko(b: Node3D, by: Node, _pct: float, tag: String, _left: int) -> void:
	var vs := mode.side_of(b)
	var ks := mode.side_of(by) if by != null and is_instance_valid(by) else -1
	if vs >= 0:
		g_lost[vs] += 1
	if vs < 0 or ks < 0 or vs == ks:
		return
	var kt: Dictionary = g_kos[ks]
	kt[tag] = int(kt.get(tag, 0)) + 1
	var sides := [mode.element, mode.foe_element]
	if sides[0] == sides[1]:
		return
	tally[sides[ks]]["l_won"] = int(tally[sides[ks]]["l_won"]) + 1
	for el: String in sides:
		tally[el]["l_decided"] = int(tally[el]["l_decided"]) + 1


## The game just ended, counted for both elements (or the mirror's seats) and printed.
func _count(a: String, b: String) -> void:
	var sides := [a, b]
	var w := mode.winner
	if a == b:
		mirror[a][w if w in [0, 1] else 2] += 1
	else:
		for el: String in sides:
			tally[el]["played"] = int(tally[el]["played"]) + 1
		if w in [0, 1]:
			tally[sides[w]]["won"] = int(tally[sides[w]]["won"]) + 1
	var fb: NpcBending = mode.foe.brain.bending if mode.foe != null and is_instance_valid(mode.foe) and mode.foe.brain != null else null
	var mb: NpcBending = mate.brain.bending if mate != null and is_instance_valid(mate) and mate.brain != null else null
	print("BAL GAME %s-%s winner=%s seat=%d game_s=%.0f lost=%d:%d strings=%d/%d/%d kos0=%s kos1=%s" % [a, b,
			sides[w] if w in [0, 1] else "none", w, _game_t, g_lost[0], g_lost[1], g_strings[0], g_strings[1], g_strings[2],
			JSON.stringify(g_kos[0]), JSON.stringify(g_kos[1])])
	print("BAL CASTS %s-%s casts0=%s casts1=%s" % [a, b, JSON.stringify(mb.casts_by if mb else {}),
			JSON.stringify(fb.casts_by if fb else {})])
	print("BAL HITS %s-%s hits0=%s hits1=%s" % [a, b, JSON.stringify(g_hits[0]), JSON.stringify(g_hits[1])])


func _report() -> void:
	var all_wins := 0
	for t: Dictionary in tally.values():
		all_wins += int(t.get("won", 0))
	for el: String in ELS:
		var t: Dictionary = tally.get(el, {})
		if t.is_empty():
			continue
		print("BALANCE %s games %d/%d lives %d/%d" % [el, int(t.won), int(t.played), int(t.l_won), int(t.l_decided)])
		print("BAL SHARE %s own_game_win_rate=%.4f pooled_win_share=%.4f total_cross_wins=%d" % [el,
				float(t.won) / maxf(float(t.played), 1.0), float(t.won) / maxf(float(all_wins), 1.0), all_wins])
	if mirrors:
		for el: String in ELS:
			print("BALANCE mirror %s seat0 %d seat1 %d none %d" % [el, mirror[el][0], mirror[el][1], mirror[el][2]])


# ---------------------------------------------------------------- spectate (the soak's)
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


## Each game's countdown: the player out of the rules and parked out of sight; a bot of his element on his side, held, joined
## through RingMode.join (its RingMoves on, as the foe's).
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
	mode.join(mate, 0)
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
