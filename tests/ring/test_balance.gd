extends SceneTree
## Tidebreak's balance at a glance (R1-BALANCE, 2026-10-05: in the bot-vs-bot soaks air had won 15 of 18 cross-element
## matches): bot against bot for every cross-element pairing, both seats (12), each played `passes` times (2), all in one ring
## (RingMode.restart between matches with MatchSetup's element and foe; the player parked off the deck as the soak's
## spectate does, a bot of his element on his side), at the game's own pace (ts 1: BendStatus.now() counts physics frames).
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_balance.gd -- [passes=2] [round_s=60] [to_win=2]
##         [difficulty=normal] [seed=7300]
##   every match reaches DONE; no SCRIPT ERROR (the runner counts them)
##   the gate   no element takes more than MAX_SHARE (0.75) of the rounds it decided against the other elements (rounds,
##              not matches: about 30 a side, so one lucky match does not fail it; its matches are printed, not gated: 12 a
##              side swing by a sixth on a seed)
##   printed    "BALANCE <el> rounds <won>/<decided> matches <won>/<played>", and a line per match (its rounds' whys, the
##              last round's casts a side, the game seconds it took)
## Before the tuning (R1-BALANCE, 4 passes): air took 46 of 55 rounds (0.84) and 23 of 24 matches; after it every element
## took 0.46 to 0.54 of its rounds (0.46 to 0.56 of its matches) over four seeds of 3 passes (the review's
## r1_balance_after.md).
## The full table is the soak's (tests/ring/test_ring_soak.gd, one pairing a run, several seeds): this is the quick check.
## ROUND 3, the % ring (rules=stock; smash_r3 spec §12): lives instead of rounds: each fall (RingRules.ko) credited to the
## knocker's element, both elements' decided; no element takes more than MAX_LIFE_SHARE (0.65) of the lives it decided
## against the others; printed "BALANCE <el> lives <won>/<decided> matches <won>/<played>". When the ring plays another rule
## set (PERCENT's RingMode not taking MatchSetup.rule_set() yet) the rounds' gate runs as before and the lives say n/a.
## In-test watchdog LIMIT_S real seconds, by the wall clock (under the runner's GODOT_TIMEOUT 420). Last line "BALANCE PASSED"
## or "BALANCE FAILED".

const NAME := "BALANCE"
const LIMIT_S := 400.0
const PARK := Vector3(0.0, 60.0, 400.0)
const MAX_SHARE := 0.75
const MAX_LIFE_SHARE := 0.65
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
var passes := 2
var _seed := 9100
var _done := false
var _game_t := 0.0
var _t0 := 0
## Per element: rounds won and decided (a drawn round decides nothing), matches won and played; cross-element only.
var tally := {}
## Round 3: the ring plays the stock rules (lives).
var stock := false


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	_t0 = Time.get_ticks_msec()
	# (the matches run unthrottled: a game second is a few real milliseconds, so the watchdog reads the wall clock, each
	# frame of the loop; this game-time timer only backs it up)
	create_timer(LIMIT_S * 50.0, true, false, true).timeout.connect(_watchdog)
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with("passes=") and kv.get_slice("=", 1).is_valid_int():
			passes = maxi(int(kv.get_slice("=", 1)), 1)
		elif kv.begins_with("seed=") and kv.get_slice("=", 1).is_valid_int():
			_seed = int(kv.get_slice("=", 1)) + 1800
	for el: String in ELS:
		tally[el] = {"won": 0, "decided": 0, "m_won": 0, "m_played": 0, "l_won": 0, "l_decided": 0}
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
		RingRules.current().ko.connect(_on_ko)
	elif "rules=stock" in OS.get_cmdline_user_args():
		print("  (rules=stock asked, the ring plays the %s rules: the lives are n/a, the rounds gated)" % RingRules.current().rule_set)
	var pairs: Array = []
	for p in passes:
		for a: String in ELS:
			for b: String in ELS:
				if a != b:
					pairs.append([a, b])
	var played := 0
	for pr: Array in pairs:
		MatchSetup.element = String(pr[0])
		MatchSetup.foes = [String(pr[1])]
		mode._seed = _seed + played * 101          # (the foe's rolls too: RingMode seeds each round's foe from its match seed)
		_done = false
		mode.restart()
		_game_t = 0.0
		while not _done and _game_t < 1500.0:
			await physics_frame
			_game_t += 1.0 / Engine.physics_ticks_per_second
			if Time.get_ticks_msec() - _t0 > int(LIMIT_S * 1000.0):
				return _watchdog()
			if player.global_position.distance_to(PARK) > 1.0 and not _done:
				_park()
		if not _done:
			_expect(false, "%s vs %s reaches DONE (%s, round %d, score %s)" % [pr[0], pr[1], mode.phase, mode.round, mode.score])
			continue
		played += 1
		_count(String(pr[0]), String(pr[1]))
	_expect(played == pairs.size(), "every match played to its end (%d of %d)" % [played, pairs.size()])
	_report()
	for el: String in ELS:
		var t: Dictionary = tally[el]
		var rs := float(t.won) / float(maxi(int(t.decided), 1))
		var ms := float(t.m_won) / float(maxi(int(t.m_played), 1))
		if stock:
			var ls := float(t.l_won) / float(maxi(int(t.l_decided), 1))
			_expect(ls <= MAX_LIFE_SHARE, "%s takes at most %.0f%% of the lives it decided against the others (lives %.2f; matches %.2f)"
					% [el, MAX_LIFE_SHARE * 100.0, ls, ms])
		else:
			_expect(rs <= MAX_SHARE, "%s takes at most %.0f%% of its rounds against the others (rounds %.2f; matches %.2f)"
					% [el, MAX_SHARE * 100.0, rs, ms])
	_end()


## Round 3: a fall credited to the knocker's element (a fall with no knocker of the other side decides nothing).
func _on_ko(b: Node3D, by: Node, _pct: float, _tag: String, _left: int) -> void:
	var vs := mode.side_of(b)
	var ks := mode.side_of(by) if by != null and is_instance_valid(by) else -1
	if vs < 0 or ks < 0 or vs == ks:
		return
	var sides := [mode.element, mode.foe_element]
	if sides[0] == sides[1]:
		return
	tally[sides[ks]]["l_won"] = int(tally[sides[ks]]["l_won"]) + 1
	for el: String in sides:
		tally[el]["l_decided"] = int(tally[el]["l_decided"]) + 1


## The match just ended (mode.history: a line per round) counted for both elements.
func _count(a: String, b: String) -> void:
	var sides := [a, b]
	var line := ""
	for h: Dictionary in mode.history:
		var w := int(h.get("winner", -1))
		if w < 0:
			continue
		tally[sides[w]]["won"] = int(tally[sides[w]]["won"]) + 1
		for el: String in sides:
			tally[el]["decided"] = int(tally[el]["decided"]) + 1
		line += "%s by %s, " % [sides[w], String(h.get("why", ""))]
	for el: String in sides:
		tally[el]["m_played"] = int(tally[el]["m_played"]) + 1
	if mode.winner >= 0:
		tally[sides[mode.winner]]["m_won"] = int(tally[sides[mode.winner]]["m_won"]) + 1
	var fb: NpcBending = mode.foe.brain.bending if mode.foe != null and is_instance_valid(mode.foe) and mode.foe.brain != null else null
	var mb: NpcBending = mate.brain.bending if mate != null and is_instance_valid(mate) and mate.brain != null else null
	print("  %s vs %s: %s (%s) [mode %s-%s, casts %d-%d, game %.0f s]" % [a, b, sides[mode.winner] if mode.winner >= 0 else "drawn", line.trim_suffix(", "),
			mode.element, mode.foe_element, mb.casts if mb else -1, fb.casts if fb else -1, _game_t])


func _report() -> void:
	for el: String in ELS:
		var t: Dictionary = tally.get(el, {})
		if t.is_empty():
			continue
		print("BALANCE %s rounds %d/%d matches %d/%d" % [el, int(t.won), int(t.decided), int(t.m_won), int(t.m_played)])
		if stock:
			print("BALANCE %s lives %d/%d matches %d/%d" % [el, int(t.l_won), int(t.l_decided), int(t.m_won), int(t.m_played)])


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


## Each round's countdown: the player out of the rules and parked out of sight; a bot of his element on his side, held.
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
