extends SceneTree
## Tidebreak's 3 v 3 groundwork (the plan's T14): the team filters (BendCaster.team_of / same_team / ally_rids, BendStatus
## can_take and near, BendBolt's flight and meet, BendZone.on_bolt) and RingRules' team rules, in the ring with a match asked
## for (earth against fire, the foe held), two more bots of the other side added to its list directly:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_teams.gd -- mode=ring element=earth foe=fire
##   1 v 1       before the others come: team_mode false, the player and the foe marked ring_0 / ring_1, not one side
##   open world  two fighters with no side (a militia pair) are not one side; a bend still reaches the other
##   bolts       a fire bolt of rival A at rival B passes through him (no hurt, no knock, the bolt flies on past him); the same
##               at the player hurts him; two water bolts of A and B meeting do not cancel
##   reach       BendStatus.near about B for A's bend leaves B out and takes the player; can_take likewise
##   shields     B's water bubble lets A's fire bolt through untouched and puts the player's out (steam); B's air shield
##               sends the player's air bolt back and lets A's through
##   advance     rivals confined 2, 2 and 1: the player's side may not enter their zone 1; all at 2: it may (zone 1, not 2),
##               and the player's forward limit runs into their zone 1
##   sit out     one rival rung out: still the fight, the round on, he held (sits out); the third out: a knockout, the match
##               over at once (match_over(0), DONE, why "knockout")
##   cleared     a restart takes the side marks off the bots that left the books and puts them back on the new ones
## Watchdog LIMIT_S. Last line "RING TEAMS TEST PASSED" or "RING TEAMS TEST FAILED" (exit 0 only on a pass).

const NAME := "RING TEAMS TEST"
const LIMIT_S := 300.0

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rivals: Array = []
var _seed := 900


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(maxi(int(s * Engine.physics_ticks_per_second), 1))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _end() -> void:
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func at_s(e: int, s: float, z := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * s, ring.top() + 0.05, z))


func _settle(b: Node3D, pos: Vector3) -> void:
	b.global_position = pos
	if b is CharacterBody3D:
		(b as CharacterBody3D).velocity = Vector3.ZERO
	var kn := BendKnock.peek(b)
	if kn != null:
		kn.reset()


func chest(b: Node3D) -> Vector3:
	return b.global_position + Vector3.UP * 1.3


func _bot(faction: String, el: String, at: Vector3) -> NpcFighter:
	_seed += 1
	var sq := NpcSquad.spawn(current_scene, faction, 1, at, {"element": el, "tactics": "bend", "weapon": "", "sidearm": "",
			"skill": "normal", "seed": _seed, "y": ring.deck_y()})
	var f: NpcFighter = sq.members[0] if sq != null and not sq.members.is_empty() else null
	if f != null:
		f.held = true
		f.no_death = true
	return f


## A bolt gone: spent, or freed since.
static func _gone(x: Variant) -> bool:
	return not is_instance_valid(x) or (x as BendBolt).spent


func _bolt(by: Node3D, to: Vector3, kind: String) -> Array:
	var from := chest(by) + (to - chest(by)).normalized() * 0.7
	var b := BendBolt.launch(by, from, to - from, {"kind": kind, "mps": 20.0, "damage": 12.0, "knock_mps": 6.0, "up_mps": 1.0, "range_m": 30.0})
	var why := [""]
	b.ended.connect(func(w: String) -> void: why[0] = w)
	return [b, why]


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	_expect(lvl != null and mode != null, "the ring with a match")
	if mode == null:
		return _end()
	ring = lvl.ring
	player = lvl.player
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 5.0)
	mode.phase_t = mode.countdown_s() - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	foe().held = true
	var rules := mode.rules
	_expect(not rules.team_mode() and BendCaster.team_of(player) == &"ring_0" and BendCaster.team_of(foe()) == &"ring_1"
			and not BendCaster.same_team(player, foe()), "1 v 1: no team mode; the player ring_0, the foe ring_1, not one side")
	await _open_world()
	# two more rivals on the foe's side (ring_team_b), added to the books
	var fe := mode.end_of(foe())
	var a := foe()
	_settle(a, at_s(fe, 6.0, -3.0))
	var b := _bot("ring_team_b", "water", at_s(fe, 6.0, 3.0))
	var c := _bot("ring_team_b", "air", at_s(fe, 9.0, 0.0))
	rivals = [a, b, c]
	rules.add(b, 1)
	rules.add(c, 1)
	_expect(rules.team_mode() and BendCaster.same_team(a, b) and BendCaster.same_team(b, c) and not BendCaster.same_team(player, b),
			"three rivals: team mode, all three one side, not the player's")
	await _ticks(3)
	await _bolts(a, b)
	_reach(a, b)
	await _shields(a, b)
	_advance()
	await _sit_out()
	await _cleared()
	_end()


func _open_world() -> void:
	var m1 := _bot("militia", "earth", at_s(0, 20.0, 30.0))
	var m2 := _bot("militia", "earth", at_s(0, 20.0, 33.0))
	await _ticks(2)
	_expect(m1 != null and m2 != null and BendCaster.team_of(m1) == &"" and not BendCaster.same_team(m1, m2) and BendStatus.can_take(m2, m1),
			"two fighters with no side are not one side: a bend still reaches the other")
	for m: NpcFighter in [m1, m2]:
		if m != null and m.squad != null:
			m.squad.get_parent().remove_child(m.squad)
			m.squad.queue_free()


func _bolts(a: NpcFighter, b: NpcFighter) -> void:
	_settle(player, at_s(1 - mode.end_of(a), 3.0, 3.0))
	await _ticks(2)
	var hb := b.health
	var r := _bolt(a, chest(b), "fire")
	var bolt := r[0] as BendBolt
	var dist := chest(a).distance_to(chest(b))
	var flew := [0.0]
	await _until(func() -> bool:
		if _gone(bolt):
			return true
		flew[0] = bolt.travelled
		return bolt.travelled > dist + 1.5, 2.0)
	var kn := BendKnock.peek(b)
	_expect(is_equal_approx(b.health, hb) and (kn == null or kn.kv.length() < 0.05) and flew[0] > dist + 1.0 and String(r[1][0]) != "hit",
			"rival A's fire bolt at rival B passes through him: health %.0f -> %.0f, knock %s, flew %.1f of %.1f m (%s)" % [hb, b.health,
			kn.kv if kn else Vector3.ZERO, flew[0], dist, r[1][0]])
	var hp := player.health
	var r2 := _bolt(a, chest(player), "fire")
	await _until(func() -> bool: return _gone(r2[0]), 2.0)
	_expect(player.health < hp and String(r2[1][0]) == "hit", "the same at the player hurts him (%.0f -> %.0f, %s)" % [hp, player.health, r2[1][0]])
	player.health = player.max_health
	# allies' water bolts meeting: no cancel
	var mid := (chest(a) + chest(b)) * 0.5
	var w1 := _bolt(a, mid + (mid - chest(a)), "water")
	var w2 := _bolt(b, mid + (mid - chest(b)), "water")
	await _until(func() -> bool: return _gone(w1[0]) and _gone(w2[0]), 2.5)
	_expect(String(w1[1][0]) != "cancel" and String(w2[1][0]) != "cancel", "allies' water bolts meeting do not cancel (%s, %s)" % [w1[1][0], w2[1][0]])


func _reach(a: NpcFighter, b: NpcFighter) -> void:
	var names: Array = []
	_settle(player, b.global_position + Vector3(1.0, 0.0, 0.0))
	for e in BendStatus.near(a, b.global_position, 3.0):
		names.append(e[0])
	_expect(not names.has(b) and names.has(player) and not BendStatus.can_take(b, a) and BendStatus.can_take(player, a)
			and BendStatus.can_take(a, player), "near / can_take: A's bend never reaches B, does reach the player (and his A)")


func _shields(a: NpcFighter, b: NpcFighter) -> void:
	_settle(player, at_s(1 - mode.end_of(a), 3.0, 3.0))
	await _ticks(2)
	var bub := BendZone.make(b, "bubble", b.global_position, {"radius_m": 2.0, "life_s": 4.0})
	var r := _bolt(a, chest(b) + (chest(b) - chest(a)).normalized() * 4.0, "fire")
	await _until(func() -> bool: return _gone(r[0]), 2.0)
	var r2 := _bolt(player, chest(b), "fire")
	await _until(func() -> bool: return _gone(r2[0]), 2.0)
	_expect(String(r[1][0]) != "steam" and String(r2[1][0]) == "steam",
			"B's bubble lets A's fire through (%s), puts the player's out (%s)" % [r[1][0], r2[1][0]])
	if is_instance_valid(bub):
		bub.queue_free()
	await _ticks(2)
	var sh := BendZone.make(b, "air_shield", b.global_position, {"radius_m": 2.2, "life_s": 4.0})
	var r3 := _bolt(a, chest(b) + (chest(b) - chest(a)).normalized() * 4.0, "air")
	await _until(func() -> bool: return _gone(r3[0]) or (r3[0] as BendBolt).travelled > 10.0, 2.0)
	var took_a := sh.took
	var r4 := _bolt(player, chest(b), "air")
	await _until(func() -> bool: return sh.took > took_a, 2.0)
	_expect(took_a == 0 and sh.took == 1 and is_instance_valid(r4[0]) and (r4[0] as BendBolt).caster == b,
			"B's air shield lets A's air bolt by (took %d) and sends the player's back (took %d, now B's)" % [took_a, sh.took])
	if is_instance_valid(sh):
		sh.queue_free()
	for x in get_nodes_in_group(BendBolt.GROUP):
		x.queue_free()
	await _ticks(2)


func _advance() -> void:
	var rules := mode.rules
	var conf := [2, 2, 1]
	for i in 3:
		(rules.state[(rivals[i] as Node).get_instance_id()] as Dictionary)["confined"] = conf[i]
	var lim_before := rules.forward_limit(player)
	_expect(not rules.may_enter(0, 1) and rules.min_confined(1) == 1, "rivals at 2, 2 and 1: the player's side may not enter their zone 1")
	(rules.state[(rivals[2] as Node).get_instance_id()] as Dictionary)["confined"] = 2
	var lim := rules.forward_limit(player)
	var into := -ring.line_s(1 - mode.player_end, 1)
	_expect(rules.may_enter(0, 1) and not rules.may_enter(0, 2) and is_equal_approx(lim, into) and lim < lim_before,
			"all three at 2: it may enter their zone 1, not 2 (forward limit %.1f -> %.1f m)" % [lim_before, lim])
	for i in 3:
		(rules.state[(rivals[i] as Node).get_instance_id()] as Dictionary)["confined"] = 1


func _sit_out() -> void:
	var rules := mode.rules
	var overs := [0]
	var matches: Array = []
	mode.round_over.connect(func(_r: String, _w: String) -> void: overs[0] += 1)
	mode.match_over.connect(func(w: int) -> void: matches.append(w))
	rivals[1].held = false
	rules._out(rivals[1], player, "ringout")
	await _ticks(2)
	_expect(mode.phase == "FIGHT" and overs[0] == 0 and rules.is_out(rivals[1]) and (rivals[1] as NpcFighter).held
			and rules.still_in(1).size() == 2, "one rival out: the round goes on, he sits it out (held)")
	rules._out(rivals[2], player, "ringout")
	await _ticks(2)
	_expect(mode.phase == "FIGHT" and overs[0] == 0, "two out: still on")
	rules._out(rivals[0], player, "ringout")
	await _ticks(3)
	_expect(mode.phase == "DONE" and matches == [0] and mode.last_why == "knockout" and mode.score == Vector2i(1, 0) and mode.winner == 0,
			"the third out: a knockout, the match over at once (%s, %s, %s, %s)" % [mode.phase, matches, mode.last_why, mode.score])
	_expect((mode.match_screen as MatchScreen).is_open() and String((mode.match_screen as MatchScreen).lines().rounds[0]).contains("a knockout"),
			"the match screen tells it: %s" % [(mode.match_screen as MatchScreen).lines().rounds])


func _cleared() -> void:
	var b := rivals[1] as NpcFighter
	var c := rivals[2] as NpcFighter
	mode.restart()
	await _ticks(3)
	_expect(BendCaster.team_of(b) == &"ring_b" and not b.has_meta(BendCaster.TEAM_META) and not mode.rules.team_mode()
			and BendCaster.team_of(player) == &"ring_0" and BendCaster.team_of(foe()) == &"ring_1",
			"a restart: the side marks off the bots that left the books (their faction's side only), back on the new pair")
	for f: NpcFighter in [b, c]:
		if is_instance_valid(f) and f.squad != null and is_instance_valid(f.squad):
			f.squad.get_parent().remove_child(f.squad)
			f.squad.queue_free()
