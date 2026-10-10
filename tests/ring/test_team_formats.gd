extends SceneTree
## Tidebreak's team formats (the owner, 2026-10-10: 2v2 and 4v4 on decks "big enough"; docs/tidebreak/team_formats_and_arenas.md):
## one format a run, bot against bot on its own deck (the player parked off the deck and a bot of his element joined in his
## slot each game, as tests/ring/test_balance.gd's spectate does), every game played to DONE.
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_team_formats.gd -- format=4v4 [games=1] [seed=7300]
##         [difficulty=normal] [limit_s=400]
##   the deck      its size, spawn slots and respawn grates are the format's (ring.json formats): n a side, every spawn on the
##                 deck and at least MIN_GAP_M from every other
##   the sides     n competitors a side on the rules' books, the player's side's bots of ring_team_a, the other's of
##                 ring_team_b; no team-mate an enemy
##   the coach     COACH_AT_S into a game every bot's target is of the other side and in play; in 4v4 each side spreads over
##                 at least two targets
##   the games     each reaches DONE; no fall credited to a team-mate; printed: "TEAM GAME ..." (winner, game seconds, the
##                 lives lost a side, falls dealt a side) and "TEAM FRAME avg_ms max_ms" (the real cost of a physics frame,
##                 headless: no drawing)
## Last line "TEAM_FORMATS PASSED" or "TEAM_FORMATS FAILED".

const NAME := "TEAM_FORMATS"
const PARK := Vector3(0.0, 60.0, 400.0)
const OWN_CFG := "user://test_team_formats.cfg"
const MIN_GAP_M := 3.0
const COACH_AT_S := 2.0
const SIZES := {"1v1": Vector2(34.0, 14.0), "2v2": Vector2(40.0, 20.0), "4v4": Vector2(52.0, 28.0)}

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var mate: NpcFighter
var mate_squad: NpcSquad
var fmt := "4v4"
var games := 1
var limit_s := 400.0
var _seed := 7300
var _done := false
var _t0 := 0
var _coach_seen := false
var _game_t := 0.0
var lost := [0, 0]
var dealt := [0, 0]
var mate_falls := 0
var frame_ms: Array[float] = []


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
		if kv.begins_with("format=") and v in MatchSetup.FORMATS:
			fmt = v
		elif kv.begins_with("games=") and v.is_valid_int():
			games = maxi(int(v), 1)
		elif kv.begins_with("seed=") and v.is_valid_int():
			_seed = int(v)
		elif kv.begins_with("limit_s=") and v.is_valid_float():
			limit_s = float(v)
		elif kv.begins_with("difficulty="):
			MatchSetup.difficulty = v
	create_timer(limit_s * 50.0, true, false, true).timeout.connect(_watchdog)
	MatchSetup._aim_help = "light"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.format = fmt
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	MatchSetup.mates = []
	MatchSetup.incoming = true
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _watchdog() -> void:
	_cleanup()
	print("%s FAILED (watchdog)" % NAME)
	quit(2)


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH


func _end() -> void:
	_cleanup()
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
	var n := MatchSetup.team_size(fmt)
	var ring := mode.ring
	var want: Vector2 = SIZES[fmt]
	_expect(RingArena.format == fmt and is_equal_approx(ring.half_l() * 2.0, want.x) and is_equal_approx(ring.half_w() * 2.0, want.y),
			"%s: the deck is %.0f x %.0f m (%.0f x %.0f)" % [fmt, want.y, want.x, ring.half_w() * 2.0, ring.half_l() * 2.0])
	_expect(n == 1 or ring.spout_count() >= n, "%s: %d respawn grates an end (%d)" % [fmt, n, ring.spout_count()])
	var rules := mode.rules
	mode.phase_changed.connect(_on_phase)
	mode.match_over.connect(func(_w: int) -> void: _done = true)
	if RingRules.stock_on():
		rules.ko.connect(_on_ko)
	for g in games:
		mode._seed = _seed + g * 101
		_done = false
		_coach_seen = false
		lost = [0, 0]
		dealt = [0, 0]
		mode.restart()
		_game_t = 0.0
		var last_us := Time.get_ticks_usec()
		while not _done and _game_t < 1500.0:
			await physics_frame
			var now := Time.get_ticks_usec()
			if mode.phase == "FIGHT":
				frame_ms.append(float(now - last_us) / 1000.0)
			last_us = now
			_game_t += 1.0 / Engine.physics_ticks_per_second
			if Time.get_ticks_msec() - _t0 > int(limit_s * 1000.0):
				return _watchdog()
			if player.global_position.distance_to(PARK) > 1.0 and not _done:
				_park()
			if mode.phase == "FIGHT" and not _coach_seen and mode.phase_t >= COACH_AT_S:
				_coach_seen = true
				_check_coach(n)
		_expect(_done, "%s game %d reaches DONE (%s, game %d, %.0f game s)" % [fmt, g + 1, mode.phase, mode.round, _game_t])
		print("TEAM GAME %s winner=%d game_s=%.0f lost=%d:%d dealt=%d:%d" % [fmt, mode.winner, _game_t, lost[0], lost[1],
				dealt[0], dealt[1]])
	_expect(mate_falls == 0, "no fall credited to a team-mate (%d)" % mate_falls)
	_check_board(n)
	if not frame_ms.is_empty():
		var sum := 0.0
		var top := 0.0
		for f in frame_ms:
			sum += f
			top = maxf(top, f)
		print("TEAM FRAME %s avg_ms=%.2f max_ms=%.1f frames=%d" % [fmt, sum / frame_ms.size(), top, frame_ms.size()])
	_end()


func _park() -> void:
	player.global_position = PARK
	player.velocity = Vector3.ZERO


func _on_ko(b: Node3D, by: Node, _pct: float, _tag: String, _left: int) -> void:
	var vs := mode.side_of(b)
	var ks := mode.side_of(by) if by != null and is_instance_valid(by) else -1
	if vs >= 0:
		lost[vs] += 1
	if ks >= 0 and vs >= 0 and by != b:
		if ks == vs:
			mate_falls += 1
		else:
			dealt[ks] += 1


func _on_phase(ph: String) -> void:
	match ph:
		"COUNTDOWN":
			_spectate()
			if mode.round == 1:
				_check_sides.call_deferred()
		"FIGHT":
			if mate != null and is_instance_valid(mate):
				mate.held = false
				mate.brain.focus(mode.foe)


## Each game's countdown: the player off the books and parked; a bot of his element joined in his slot (RingMode.join).
func _spectate() -> void:
	var rules := mode.rules
	var pid := player.get_instance_id()
	if rules.state.has(pid):
		rules.state.erase(pid)
	(rules.sides[0] as Array).erase(player)
	player.is_dead = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_park()
	if mate_squad != null and is_instance_valid(mate_squad):
		mate_squad.get_parent().remove_child(mate_squad)
		mate_squad.queue_free()
	var ring := mode.ring
	var xf := ring.spawn(mode.player_end, 0)
	var opts := {"face": xf.origin - xf.basis.z * 10.0, "tag": "ring", "tactics": "bend", "element": mode.element,
			"weapon": "", "sidearm": "", "skill": mode.difficulty, "seed": _seed + mode.round * 13, "y": ring.deck_y()}
	mate_squad = NpcSquad.spawn(lvl, RingMode.FACTIONS[0], 1, xf.origin, opts)
	mate = mate_squad.members[0] if mate_squad != null and not mate_squad.members.is_empty() else null
	if mate == null:
		_expect(false, "a bot for the player's slot")
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


## The first countdown: n a side on the books, the factions, every spawn on the deck and apart.
func _check_sides() -> void:
	var n := MatchSetup.team_size(fmt)
	var rules := mode.rules
	_expect((rules.sides[0] as Array).size() == n and (rules.sides[1] as Array).size() == n,
			"%s: %d a side on the books (%d, %d)" % [fmt, n, (rules.sides[0] as Array).size(), (rules.sides[1] as Array).size()])
	var fac_ok := true
	var foe_ok := true
	for t in 2:
		for b in rules.sides[t]:
			if b is NpcFighter:
				fac_ok = fac_ok and (b as NpcFighter).faction == RingMode.FACTIONS[t]
				for o in rules.sides[t]:
					if o != b and o is NpcFighter and (b as NpcFighter).brain._is_foe(o):
						foe_ok = false
	_expect(fac_ok, "%s: the player's side ring_team_a, the other ring_team_b" % fmt)
	_expect(foe_ok, "%s: no team-mate an enemy" % fmt)
	var all := mode.competitors()
	var on := true
	var gap := INF
	for i in all.size():
		var a := all[i] as Node3D
		on = on and mode.ring.on_deck(a.global_position)
		for j in range(i + 1, all.size()):
			gap = minf(gap, a.global_position.distance_to((all[j] as Node3D).global_position))
	_expect(on and gap >= MIN_GAP_M, "%s: every spawn on the deck, %.1f m apart at least (%.1f)" % [fmt, MIN_GAP_M, gap])
	# (every bot of the match by its own name, none twice; the other side in its away kit)
	var names := {}
	var named := 0
	for b in mode.bots():
		var nm := RingMode.name_of(b)
		if nm != "":
			named += 1
			names[nm] = true
	_expect(named == 2 * n - 1 and names.size() == named, "%s: the match's %d bots each by its own name, none twice (%s)"
			% [fmt, 2 * n - 1, ", ".join(PackedStringArray(names.keys()))])
	var away_ok := true
	for el: String in RingSides.elements(1):
		away_ok = away_ok and RingSides.away(1, el)
	_expect(away_ok and not RingSides.away(0, "earth"), "%s: their side in its away kit, yours at home" % fmt)


## COACH_AT_S into the fight: every bot's target of the other side and in play; in 4v4 each side on two targets at least.
func _check_coach(n: int) -> void:
	var rules := mode.rules
	var bad: Array[String] = []
	for t in 2:
		var picks := {}
		for b in rules.sides[t]:
			if not (b is NpcFighter) or not mode.in_play(b):
				continue
			var tg := (b as NpcFighter).brain.target
			if tg == null or not is_instance_valid(tg) or rules.team_of(tg) != 1 - t:
				bad.append("%s side %d -> %s" % [(b as NpcFighter).name, t, str(tg)])
			else:
				picks[tg.get_instance_id()] = true
		if n >= 4 and picks.size() < 2:
			bad.append("side %d all on one target" % t)
	_expect(bad.is_empty(), "%s: the coach has every bot on an opponent, spread (%s)" % [fmt, ", ".join(bad)])


## The match screen's board in a team format: your team and theirs, the roster of every fighter with his falls adding up.
func _check_board(n: int) -> void:
	var ms := mode.match_screen as MatchScreen
	if ms == null:
		_expect(false, "%s: a match screen" % fmt)
		return
	var b := ms.board()
	var lost := 0
	var dealt_sum := 0
	for e: Dictionary in b.roster:
		lost += int(e.falls_taken)
		dealt_sum += int(e.falls_dealt)
	var falls_n: int = mode.falls.size()
	_expect(bool(b.team) and (b.roster as Array).size() == 2 * n and lost == falls_n and dealt_sum <= falls_n,
			"%s: the board is a team's, its roster %d fighters, falls taken adding up (%d of %d; dealt %d)"
			% [fmt, (b.roster as Array).size(), lost, falls_n, dealt_sum])
	var line := String(ms.lines().line)
	_expect(line.begins_with("Your team") or line.begins_with("Their team") or line.begins_with("Neither"),
			"%s: the result's line names the teams (%s)" % [fmt, line])

