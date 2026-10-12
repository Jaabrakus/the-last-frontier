extends SceneTree
## Zones on the new ring (the owner, 2026-10-11: "zones is still good ... but it should have all the new bending movements not
## the frontiers stuff"; picked hits like Lives and the new deep-water deck): RingRules rule_set "zones", bot against bot (the
## player parked off the deck, a bot of his element joined in his slot each round, as test_team_formats.gd does).
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_zones_ring.gd -- [format=1v1] [rounds=3] [seed=7400]
##         [limit_s=500]
##   the set-up    the new ring's gate on (stock_on), the % off (pct_on), the deep-water deck (RingArena.mode "stock"), every
##                 competitor with MOVE's RingMoves, no ragdoll; the menu offers Lives and Zones, a kept "classic" read as
##                 zones
##   the meter     a hit's d on the meter, the body's health showing it; the launch the same at 0 and at 80 on the meter
##                 (it never grows); full: winded (back a zone, the meter down to winded_refill's share); in the last zone out
##   the outs      round 1: the foe winded in his last zone is out of the round ("winded"; 1v1 the round to us); round 2: the
##                 foe put in the water is rung out ("ringout"); in a team format each sits out hidden, the round going on
##   the rounds    the match reaches DONE; printed "ZONES ROUND ..." (who won it, why) and "ZONES RUN ..." (knock-backs,
##                 windings, ring-outs over the run); someone pushed back a zone by the bots' own play
##   the walls     a confined body not under a knock never stands forward of its limit by more than WALL_SLACK_M
##   the out       one out of the round is hidden off the deck while the round goes on
## Last line "ZONES_RING PASSED" or "ZONES_RING FAILED".

const NAME := "ZONES_RING"
const PARK := Vector3(0.0, 60.0, 400.0)
const OWN_CFG := "user://test_zones_ring.cfg"
const WALL_SLACK_M := 0.6

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var mate: NpcFighter
var mate_squad: NpcSquad
var fmt := "1v1"
var rounds := 3
var limit_s := 500.0
var _seed := 7400
var _done := false
var _t0 := 0
var knock_backs := 0
var windings := 0
var ringouts := 0
var wind_outs := 0
var wall_bad := 0
var wall_worst := 0.0
var shown_bad := 0
var hidden_bad := 0
var ends := {}
var _forced := {}


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
		elif kv.begins_with("rounds=") and v.is_valid_int():
			rounds = maxi(int(v), 1)
		elif kv.begins_with("seed=") and v.is_valid_int():
			_seed = int(v)
		elif kv.begins_with("limit_s=") and v.is_valid_float():
			limit_s = float(v)
	create_timer(limit_s * 50.0, true, false, true).timeout.connect(_watchdog)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	# (the menu's rows: Lives and Zones; a setting kept as "classic" before 2026-10-11 read back as Zones)
	_expect(MatchSetup.RULE_SETS == ["stock", "zones"], "the menu offers Lives and Zones (%s)" % [MatchSetup.RULE_SETS])
	GameSettings.set_value("match", "rules", "classic")
	MatchSetup.load()
	_expect(MatchSetup.rules_choice == "zones", "a kept \"classic\" is read as Zones (%s)" % MatchSetup.rules_choice)
	MatchSetup._aim_help = "light"
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.set_match()
	MatchSetup.format = fmt
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	MatchSetup.mates = []
	MatchSetup.incoming = true
	MatchSetup.rounds_to_win = rounds
	MatchSetup.difficulty = "hard"
	RingRules.rule_set_override = "zones"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _watchdog() -> void:
	_cleanup()
	print("%s FAILED (watchdog)" % NAME)
	quit(2)


func _cleanup() -> void:
	RingRules.rule_set_override = ""
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
	var rules := mode.rules
	_expect(rules.rule_set == "zones" and RingRules.stock_on() and not RingRules.pct_on() and RingRules.zones_on(),
			"zones: the new ring's gate on, the % off (%s)" % rules.rule_set)
	_expect(RingArena.mode == "stock", "zones: the deep-water deck (RingArena.mode %s)" % RingArena.mode)
	_expect(BendKnock.ragdoll_mps == INF, "zones: no ragdoll (the launch is the hit)")
	_expect(not mode.stock() and mode.new_ring(), "zones: the zones' rounds on the new ring")
	mode.phase_changed.connect(_on_phase)
	mode.match_over.connect(func(_w: int) -> void: _done = true)
	mode.round_over.connect(func(_r: String, why: String) -> void:
		ends[why] = int(ends.get(why, 0)) + 1
		print("ZONES ROUND %d result=%s why=%s score=%d:%d" % [mode.round, _r, why, mode.score.x, mode.score.y]))
	rules.knocked_back.connect(func(_w: Node3D, _a: int, _b: int) -> void: knock_backs += 1)
	rules.winded.connect(func(_w: Node3D, _by: Node, _z: int) -> void: windings += 1)
	rules.rang_out.connect(func(w: Node3D, _by: Node) -> void:
		if String(rules.last_out.get("why", "")) == "ringout":
			ringouts += 1
		else:
			wind_outs += 1
		_check_hidden.call_deferred(w))
	mode.restart()
	await _until_fight()
	await _check_meter()
	_forced[1] = true
	await _force_out(1)
	var game_t := 0.0
	while not _done and game_t < 2400.0:
		await physics_frame
		game_t += 1.0 / Engine.physics_ticks_per_second
		if Time.get_ticks_msec() - _t0 > int(limit_s * 1000.0):
			return _watchdog()
		if player.global_position.distance_to(PARK) > 1.0 and not _done:
			_park()
		if mode.phase == "FIGHT":
			_check_walls()
	_expect(_done, "the match reaches DONE (%s, round %d, %.0f game s)" % [mode.phase, mode.round, game_t])
	print("ZONES RUN %s rounds=%d knock_backs=%d windings=%d ringouts=%d wind_outs=%d ends=%s" % [fmt, mode.round,
			knock_backs, windings, ringouts, wind_outs, ends])
	_expect(knock_backs > 0, "someone was pushed back a zone (%d)" % knock_backs)
	_expect(wall_bad == 0, "no confined body past its forward limit by more than %.1f m off a knock (%d frames, worst %.2f m)"
			% [WALL_SLACK_M, wall_bad, wall_worst])
	_expect(shown_bad == 0, "every body's health showed its meter (%d off)" % shown_bad)
	_expect(hidden_bad == 0, "one out of the round is hidden off the deck (%d not)" % hidden_bad)
	_end()


func _until_fight() -> void:
	for i in 1200:
		await physics_frame
		if mode.phase == "FIGHT":
			return


func _park() -> void:
	player.global_position = PARK
	player.velocity = Vector3.ZERO


func _on_phase(ph: String) -> void:
	match ph:
		"COUNTDOWN":
			_spectate()
		"FIGHT":
			if mate != null and is_instance_valid(mate):
				mate.held = false
				mate.brain.focus(mode.foe)
			if mode.round == 2 and not _forced.has(mode.round):
				_forced[mode.round] = true
				_force_out.call_deferred(mode.round)


## Each round's countdown: the player off the books and parked; a bot of his element joined in his slot (RingMode.join).
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
	rules.reset_game()                       # (the joined bot's meter at 0 and its health shown full, as the round's start)
	var bend := mate.brain.bending
	if bend != null:
		bend.bounds_fn = rules.bounds_fn_for(mate)
		bend.edge_fn = rules.edge_along


## The first fight's start: every competitor with its RingMoves; the meter takes a hit's d, the health shows it; the launch
## the same at 0 and at 80 on the meter; the meter full winds (back a zone, the meter down); all put back after.
func _check_meter() -> void:
	var rules := mode.rules
	var all := mode.competitors()
	var moves_ok := not all.is_empty()
	for b in all:
		moves_ok = moves_ok and RingMoves.of(b) != null
	_expect(moves_ok, "zones: every competitor moves with RingMoves (%d)" % all.size())
	var f := mode.foe
	if f == null or not is_instance_valid(f):
		_expect(false, "a foe to hit")
		return
	var info := {"tag": "stone_form/spike", "at": f.global_position + Vector3.UP, "dir": Vector3.RIGHT, "from": f.global_position - Vector3.RIGHT * 6.0}
	var r0 := rules.on_hit(f, mate, info.duplicate())
	var p0 := rules.pct_of(f)
	_expect(p0 > 0.0, "a Spike's d goes onto the meter (%.1f)" % p0)
	var want_hp := f.health_max * (1.0 - p0 / RingRules.wind_pct())
	_expect(absf(f.health - want_hp) < 0.6, "the foe's health shows the meter (%.1f of %.1f, want %.1f)" % [f.health, f.health_max, want_hp])
	rules.add_pct(f, 80.0 - p0, null, "")
	var r1 := rules.on_hit(f, mate, info.duplicate())
	var v0: Vector3 = r0.get("v", Vector3.ZERO)
	var v1: Vector3 = r1.get("v", Vector3.ZERO)
	_expect(v0.length() > 1.0 and absf(v0.length() - v1.length()) < 0.05,
			"the launch never grows: %.2f m/s at 0, %.2f at 80 on the meter" % [v0.length(), v1.length()])
	var c0 := rules.confined_of(f)
	rules.add_pct(f, RingRules.wind_pct(), null, "")
	for i in 3:
		await physics_frame
	var c1 := rules.confined_of(f)
	var after := rules.pct_of(f)
	var refill := RingRules.num("winded_refill", 0.4)
	_expect(c1 == c0 + 1 and absf(after - RingRules.wind_pct() * (1.0 - refill)) < 0.5,
			"the meter full winds: zone %d -> %d, the meter %.0f (want %.0f)" % [c0, c1, after, RingRules.wind_pct() * (1.0 - refill)])
	# (all put back: the fight from a fresh start)
	var kn := BendKnock.peek(f)
	if kn != null:
		kn.reset()
	(rules.state[f.get_instance_id()] as Dictionary)["confined"] = 1
	rules.reset_pct(f, 0.0)
	knock_backs = 0
	windings = 0


## Each FIGHT frame: a confined body off a knock stands no farther forward than its limit (WALL_SLACK_M), and its health
## shows its meter.
func _check_walls() -> void:
	var rules := mode.rules
	for b in mode.competitors():
		var body := b as Node3D
		if not mode.in_play(body) or rules._knocked(body):
			continue
		var lim := rules.forward_limit(body)
		if lim == -INF or not mode.ring.on_deck(body.global_position):
			continue
		var over := lim - rules.s_of(body)
		if over > WALL_SLACK_M:
			wall_bad += 1
			wall_worst = maxf(wall_worst, over)
		if body is NpcFighter:
			var nf := body as NpcFighter
			var want := maxf(nf.health_max * clampf(1.0 - rules.pct_of(nf) / RingRules.wind_pct(), 0.0, 1.0), 0.5)
			if absf(nf.health - want) > 1.0:
				shown_bad += 1


## Round 1 (after the meter's check): the foe confined to the last zone with the meter full: out of the round, "winded".
## Round 2: the foe put in the water past the deck: rung out, "ringout". 1v1: the round to us at once; a team format: he sits
## out hidden, the round going on.
func _force_out(r: int) -> void:
	for i in 4:
		await physics_frame
	var rules := mode.rules
	var f := mode.foe
	if f == null or not is_instance_valid(f) or mode.phase != "FIGHT":
		_expect(false, "round %d: a foe in the fight to put out (%s)" % [r, mode.phase])
		return
	var won := mode.score.x
	if r == 1:
		(rules.state[f.get_instance_id()] as Dictionary)["confined"] = rules.zones()
		rules.add_pct(f, RingRules.wind_pct(), null, "")
	else:
		var ring := mode.ring
		var out := ring.to_global(Vector3(RingArena.side_sign(mode._end(1)) * (ring.half_l() + 3.0), ring.top() - 7.0, 0.0))
		f.global_position = out
	for i in 3:
		await physics_frame
	var why := "winded" if r == 1 else "ringout"
	_expect(rules.is_out(f) and String(rules._st(f).get("why", "")) == why, "round %d: the foe is out of the round, %s (%s)"
			% [r, why, String(rules._st(f).get("why", ""))])
	if MatchSetup.team_size(fmt) == 1:
		_expect(mode.score.x == won + 1 and mode.last_why == why, "round %d: 1v1, the round to us at once, %s (score %d:%d, %s)"
				% [r, why, mode.score.x, mode.score.y, mode.last_why])
	else:
		_expect(mode.phase == "FIGHT" and not f.visible, "round %d: %s, he sits out hidden, the round goes on (%s, visible %s)"
				% [r, fmt, mode.phase, f.visible])


func _check_hidden(w: Node3D) -> void:
	if mode.phase == "FIGHT" and is_instance_valid(w) and w.visible:
		hidden_bad += 1
