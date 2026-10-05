extends SceneTree
## Tidebreak's rules on the deck (RingRules, RingMode; data/ring/rules.json; the owner, 2026-10-04: "knockback wins", 1v1
## first), in the ring scene with a match asked for and the foe held (a scripted fight: every knock is the test's own):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_rules.gd -- mode=ring element=earth foe=earth
##   menu       Esc (RingMenu) pauses, its note "Round 1 · 2:59 left · You 0 : 0 Stone", the element choice waits for the
##              restart, the controls list each key
##   contract   RingMode in group ring_match with round, score, phase, round_left_s(), side_of(), confined_of() and the
##              signals phase_changed, knocked_back, rang_out, round_over, match_over
##   hold       the countdown holds the player (drag_speed_cap 0) even when a root ends inside it
##   confined   a knock that carries the player across his zone-1 line confines him to zone 2 (knocked_back 1 -> 2)
##   scale      one hit moves a body at most max_push_m: an earth knock of 12 m/s, an air ball of 13 m/s, a column-like
##              launch (up and out), a cyclone-like 14 m/s air push
##   soft wall  3 s of forward input then keeps him behind his line (s >= line_s(1) - 0.15)
##   advancing  the foe may then stand in the player's zone 1 but not his zone 2 (pushed back to the line)
##   winded     999 of a blow on the player and on the foe leaves both alive: confined + 1, health 40%, behind the line
##   grates     a waterbender is near water within 1.5 m of a grate, not at 1.8 m (Bending.near_water, meta reach_m)
##   ring-out   the held foe knocked off his open end: round_over("win", "ringout") within 1 s, score (1, 0), credited to
##              the player (rang_out's by, last_by), no fall damage to anyone
##   between    the next round: the ends swapped, both at their spawns, whole, zone 1; the round's leavings (BendBolt,
##              BendZone, FormRaised, GustLift groups) gone; the root metas cleared
##   time-out   confined 1 against 2: "territory" to the side with 1 (score 2: match_over(0), DONE); after a restart,
##              level ground and the player at half health: "health" to the foe; level ground and health: a draw
## A watchdog ends it at LIMIT_S (under the runner's GODOT_TIMEOUT). Last line: "RING RULES TEST PASSED" or "... FAILED".

const NAME := "RING RULES TEST"
const LIMIT_S := 330.0

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var events := {"phase": [], "knocked_back": [], "rang_out": [], "round_over": [], "match_over": []}


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
	Input.action_release(&"move_forward")
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


## The world point at s (metres back from the centre into deck end `e`), across the deck at z.
func at_s(e: int, s: float, z := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * s, ring.top() + 0.05, z))


## Toward deck end `e`'s open edge (flat, unit).
func back_of(e: int) -> Vector3:
	var b := ring.axis() * RingArena.side_sign(e)
	b.y = 0.0
	return b.normalized()


func _settle(b: Node3D, pos: Vector3) -> void:
	b.global_position = pos
	if b is CharacterBody3D:
		(b as CharacterBody3D).velocity = Vector3.ZERO
	var kn := BendKnock.peek(b)
	if kn != null:
		kn.reset()


## Through the countdown to the fight at once, the foe held after.
func _go_fight() -> void:
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 5.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	if foe() != null:
		foe().held = true


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	_expect(lvl != null, "the scene is the ring")
	if lvl == null:
		return _end()
	ring = lvl.ring
	player = lvl.player
	mode = RingMode.find(self)
	_expect(mode != null and mode.is_in_group(&"ring_match") and lvl.mode == mode, "a match installed (RingMode in group ring_match)")
	if mode == null:
		return _end()
	var sigs := ["phase_changed", "knocked_back", "rang_out", "round_over", "match_over"]
	var ok := true
	for s: String in sigs:
		ok = ok and mode.has_signal(s)
	for m: String in ["round_left_s", "side_of", "confined_of"]:
		ok = ok and mode.has_method(m)
	ok = ok and mode.get("round") is int and mode.get("score") is Vector2i and mode.get("phase") is String
	_expect(ok, "the contract: round, score, phase, round_left_s, side_of, confined_of and the five signals")
	mode.phase_changed.connect(func(p: String) -> void: events.phase.append(p))
	mode.knocked_back.connect(func(w: Node3D, a: int, b: int) -> void: events.knocked_back.append([w, a, b]))
	mode.rang_out.connect(func(w: Node3D, by: Node) -> void: events.rang_out.append([w, by]))
	mode.round_over.connect(func(r: String, why: String) -> void: events.round_over.append([r, why]))
	mode.match_over.connect(func(w: int) -> void: events.match_over.append(w))
	await _hold()
	await _go_fight()
	_expect(mode.phase == "FIGHT" and foe() != null, "the fight on (%s), the foe there" % mode.phase)
	if foe() == null:
		return _end()
	_expect(mode.side_of(player) == 0 and mode.side_of(foe()) == 1 and mode.confined_of(player) == 1 and mode.confined_of(foe()) == 1,
			"side_of 0 / 1, both confined to zone 1")
	_menu()
	await _confined()
	await _scale()
	await _soft_wall()
	await _advancing()
	await _winded()
	_grates()
	await _ring_out()
	await _between()
	await _time_out()
	_end()


func _hold() -> void:
	await _until(func() -> bool: return foe() != null, 5.0)
	var e := mode.player_end
	_expect(mode.phase == "COUNTDOWN" and player.drag_speed_cap == 0.0, "the countdown holds the player (cap %.1f)" % player.drag_speed_cap)
	_expect(player.global_position.distance_to(ring.spawn(e).origin) < 0.5 and foe() != null
			and foe().global_position.distance_to(ring.spawn(1 - e).origin) < 0.6,
			"both at their spawns, mid zone 1 (player %.2f m, foe %.2f m off)" % [player.global_position.distance_to(ring.spawn(e).origin),
			foe().global_position.distance_to(ring.spawn(1 - e).origin) if foe() != null else -1.0])
	BendStatus.root(player, 0.4)
	await _secs(0.8)
	_expect(mode.phase == "COUNTDOWN" and player.drag_speed_cap == 0.0 and player.bend_speed_cap == INF,
			"a root ending inside the countdown leaves the hold (drag cap %.1f, bend cap %s)" % [player.drag_speed_cap, player.bend_speed_cap])


## The Esc menu: it pauses, its note reads the round, the time and the score, a choice waits for the next restart.
func _menu() -> void:
	var m := mode.menu as RingMenu
	_expect(m != null, "RingMenu installed with the match")
	if m == null:
		return
	m.open()
	var note := m.note_text()
	var paused_ok := paused and m.is_open()
	var was := MatchSetup.element
	m.cycle_element()
	var waits := MatchSetup.element != was and mode.element == was
	MatchSetup.element = was
	var lines := RingMenu.control_lines(mode.element)
	m.close()
	_expect(paused_ok and not paused and note.begins_with("Round 1") and note.contains("left") and note.contains("You 0  :  0 Stone"),
			"Esc pauses; the note '%s'" % note)
	_expect(waits and lines.size() == Bending.keys(mode.element).size() and String(lines[0]).begins_with("1"),
			"the element choice waits for the restart; the controls list each key (%d lines: '%s')" % [lines.size(), lines[0] if not lines.is_empty() else ""])


func _confined() -> void:
	var e := mode.end_of(player)
	_settle(player, at_s(e, 4.5))
	await _ticks(2)
	var s0 := ring.s_of(player.global_position, e)
	var n0: int = events.knocked_back.size()
	BendStatus.knock(player, back_of(e) * 12.0, foe())
	await _secs(2.0)
	var s1 := ring.s_of(player.global_position, e)
	_expect(mode.confined_of(player) == 2 and events.knocked_back.size() == n0 + 1
			and (events.knocked_back.back() as Array)[0] == player and (events.knocked_back.back() as Array)[1] == 1
			and (events.knocked_back.back() as Array)[2] == 2,
			"a knock across his zone-1 line confines the player to zone 2 (s %.2f -> %.2f, confined %d, knocked_back %s)" % [
			s0, s1, mode.confined_of(player), events.knocked_back.size() - n0])
	_expect(s1 - s0 <= RingRules.num("max_push_m", 3.5) + 0.15 and s1 - s0 > 2.5,
			"an earth knock of 12 m/s moves him at most max_push_m (%.2f m)" % (s1 - s0))


func _scale() -> void:
	var e := mode.end_of(player)
	var f := foe()
	var bd := Bending.of(f)
	var was := bd.element
	var side := ring.global_basis.z.normalized()
	# (lateral: along the deck's width, his zone the same)
	for c: Array in [["air", side * 13.0, "an air ball of 13 m/s"], ["earth", side * 8.0 + Vector3.UP * 9.0, "a column-like launch (8 out, 9 up)"],
			["air", -side * 14.0, "a cyclone-like air push of 14 m/s"]]:
		bd.element = String(c[0])
		if &"element" in f:
			f.set(&"element", String(c[0]))
		var z0 := -2.5 if (c[1] as Vector3).dot(side) > 0.0 else 2.5
		_settle(player, at_s(e, 9.5, z0))
		await _ticks(3)
		var p0 := player.global_position
		BendStatus.knock(player, c[1] as Vector3, f)
		await _secs(3.0)
		var d := Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
		_expect(d <= RingRules.num("max_push_m", 3.5) + 0.3 and d > 0.5 and player.is_on_floor(),
				"%s moves the player at most max_push_m (%.2f m)" % [String(c[2]), d])
	bd.element = was
	if &"element" in f:
		f.set(&"element", was)


func _soft_wall() -> void:
	var e := mode.end_of(player)
	var line := ring.line_s(e, 1)
	_settle(player, at_s(e, line + 1.0))
	var fwd := -back_of(e)
	player.yaw = atan2(-fwd.x, -fwd.z)
	player.rotation.y = player.yaw
	player.pitch = 0.0
	await _ticks(2)
	Input.action_press(&"move_forward")
	var lo := INF
	var t := 0.0
	while t < 3.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		lo = minf(lo, ring.s_of(player.global_position, e))
	Input.action_release(&"move_forward")
	_expect(lo >= line - 0.15 and lo < line + 0.4, "3 s of forward input keeps him behind his line (lowest s %.2f, line %.2f)" % [lo, line])
	_expect(mode.confined_of(player) == 2, "and walking confines nothing more (zone %d)" % mode.confined_of(player))


func _advancing() -> void:
	var e := mode.end_of(player)
	var f := foe()
	_expect(is_equal_approx(mode.rules.forward_limit(f), -ring.line_s(e, 1)),
			"the foe's forward limit is the player's zone-2 line (%.2f)" % mode.rules.forward_limit(f))
	_settle(player, at_s(e, 13.0, -3.0))
	_settle(f, at_s(e, 5.0, 3.0))
	await _secs(1.0)
	var s_in := ring.s_of(f.global_position, e)
	_expect(ring.zone_of(f.global_position, e) == 1 and absf(s_in - 5.0) < 0.2,
			"the foe may stand in the player's zone 1 (s %.2f in the player's end)" % s_in)
	_settle(f, at_s(e, 9.5, 3.0))
	await _secs(1.5)
	var s_out := ring.s_of(f.global_position, e)
	_expect(s_out <= ring.line_s(e, 1) + 0.15 and ring.zone_of(f.global_position, e) <= 2,
			"but not in his zone 2: pushed back to the line (s %.2f, line %.2f)" % [s_out, ring.line_s(e, 1)])
	var c := mode.rules.clamp_for(at_s(e, 12.0, 0.0), f)
	_expect(ring.s_of(c, e) <= ring.line_s(e, 1), "the foe's bounds_fn keeps him out of it too (s %.2f)" % ring.s_of(c, e))
	_settle(f, ring.spawn(1 - e).origin + Vector3.UP * 0.05)
	await _ticks(2)


func _winded() -> void:
	var e := mode.end_of(player)
	var f := foe()
	_settle(player, at_s(e, 9.0))
	await _ticks(2)
	var wp: Array = []
	player.winded.connect(func(by: Node) -> void: wp.append(by))
	Hit.deliver(player, 999.0, player.global_position + Vector3.UP, back_of(e), f)
	await _ticks(3)
	var s := ring.s_of(player.global_position, e)
	_expect(not player.is_dead and wp.size() == 1 and mode.confined_of(player) == 3
			and absf(player.health - player.max_health * RingRules.num("winded_refill", 0.4)) < 0.6
			and s >= ring.line_s(e, 2) + 0.3,
			"999 on the player: alive, winded once, confined 2 -> 3, health %.0f (40%%), behind the zone-2 line (s %.2f)" % [player.health, s])
	var fe := mode.end_of(f)
	_settle(f, at_s(fe, 5.0))
	await _ticks(2)
	var wn: Array = []
	f.winded.connect(func(by: Node) -> void: wn.append(by))
	Hit.deliver(f, 999.0, NpcSenses.chest_of(f), back_of(fe), player)
	await _ticks(3)
	var sf := ring.s_of(f.global_position, fe)
	_expect(not f.is_dead() and wn.size() >= 1 and mode.confined_of(f) == 2
			and absf(f.health - f.health_max * RingRules.num("winded_refill", 0.4)) < 0.6 and sf >= ring.line_s(fe, 1) + 0.3,
			"999 on the foe: alive, winded, confined 1 -> 2, health %.0f (40%%), behind his zone-1 line (s %.2f)" % [f.health, sf])
	_expect(mode.phase == "FIGHT", "being winded short of the last zone goes on with the round")


func _grates() -> void:
	var bd := Bending.of(player)
	var g: Node3D = null
	for x in ring.pools():
		if g == null or absf(ring.to_local(x.global_position).x) > absf(ring.to_local(g.global_position).x):
			g = x
	var toward := -signf(ring.to_local(g.global_position).z)
	var was := player.global_position
	player.global_position = g.global_position + ring.global_basis.z.normalized() * toward * 1.3
	var near := bd.near_water()
	player.global_position = g.global_position + ring.global_basis.z.normalized() * toward * 1.8
	var far := bd.near_water()
	player.global_position = was
	_expect(near and not far, "near water within 1.5 m of a grate (1.3 m: %s), not at 1.8 m (%s)" % [near, far])


func _ring_out() -> void:
	var f := foe()
	var fe := mode.end_of(f)
	_settle(f, at_s(fe, 15.5))
	await _ticks(3)
	var hp := player.health
	var hf := f.health
	var n0: int = events.round_over.size()
	BendStatus.knock(f, back_of(fe) * 12.0, player)
	var t := await _until(func() -> bool: return events.round_over.size() > n0, 3.0)
	_expect(t < 2.0 and events.round_over.size() == n0 + 1 and (events.round_over.back() as Array) == ["win", "ringout"]
			and mode.score == Vector2i(1, 0),
			"the held foe knocked off his open end: round_over %s %.2f s after the knock, score %s" % [
			events.round_over.back() if events.round_over.size() > n0 else "none", t, mode.score])
	_expect(not events.rang_out.is_empty() and (events.rang_out.back() as Array)[0] == f and (events.rang_out.back() as Array)[1] == player
			and mode.last_by == player and mode.self_outs == 0,
			"credited to the player, the last knocker (self ring-outs %d)" % mode.self_outs)
	await _secs(1.5)
	_expect(is_equal_approx(player.health, hp) and is_instance_valid(f) and is_equal_approx(f.health, hf),
			"no fall damage to anyone (player %.0f -> %.0f, foe %.0f -> %.0f)" % [hp, player.health, hf, f.health if is_instance_valid(f) else -1.0])
	_expect(mode.phase == "OVER" and mode.round_left_s() > 0.0, "the pause after the round (%s)" % mode.phase)


func _between() -> void:
	# (the round's leavings: stand-ins in the groups clear_dropped takes, in the ring)
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, GustLift.GROUP]:
		var x := Node3D.new()
		x.name = "Left_%s" % g
		current_scene.add_child(x)
		x.global_position = at_s(0, 6.0, 1.0)
		x.add_to_group(g)
	BendStatus.root(player, 30.0)
	BendStatus.slow(player, 30.0)
	var e0 := mode.player_end
	mode._skip = true
	await _until(func() -> bool: return mode.round == 2 and mode.phase == "COUNTDOWN" and foe() != null, 3.0)
	await _ticks(2)
	var left := 0
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, GustLift.GROUP]:
		left += get_nodes_in_group(g).size()
	_expect(mode.round == 2 and left == 0, "round 2, and none of the round's bolts, zones, raised earth or lifts left (%d)" % left)
	var e := mode.player_end
	_expect(e == 1 - e0 and player.global_position.distance_to(ring.spawn(e).origin) < 0.5
			and foe().global_position.distance_to(ring.spawn(1 - e).origin) < 0.6,
			"the ends swapped (%d -> %d), both at their spawns" % [e0, e])
	_expect(not player.has_meta(&"bend_root") and not player.has_meta(&"bend_slow") and player.bend_speed_cap == INF
			and player.drag_speed_cap == 0.0,
			"the root and slow metas cleared (bend cap %s), the countdown's hold on (drag cap %.1f)" % [player.bend_speed_cap, player.drag_speed_cap])
	_expect(is_equal_approx(player.health, player.max_health) and mode.confined_of(player) == 1 and mode.confined_of(foe()) == 1
			and not mode.rules.is_out(foe()), "both whole and back to zone 1 (health %.0f)" % player.health)


func _time_out() -> void:
	await _go_fight()
	var n0: int = events.round_over.size()
	(mode.rules.state[player.get_instance_id()] as Dictionary)["confined"] = 1
	(mode.rules.state[foe().get_instance_id()] as Dictionary)["confined"] = 2
	mode.phase_t = mode.round_s
	await _until(func() -> bool: return events.round_over.size() > n0, 1.0)
	_expect(events.round_over.size() == n0 + 1 and (events.round_over.back() as Array) == ["win", "territory"],
			"time-out, confined 1 against 2: the player's round on territory (%s)" % [events.round_over.back()])
	_expect(mode.score == Vector2i(2, 0), "score %s" % mode.score)
	mode._skip = true
	await _until(func() -> bool: return mode.phase == "DONE", 2.0)
	_expect(mode.phase == "DONE" and events.match_over == [0] and mode.winner == 0,
			"two round wins: match_over(0), DONE (%s, %s)" % [mode.phase, events.match_over])
	# a new match: health decides level ground, then a draw
	mode.restart()
	await _go_fight()
	_expect(mode.round == 1 and mode.score == Vector2i.ZERO, "restart: round 1, score nil")
	player.health = player.max_health * 0.5
	n0 = events.round_over.size()
	mode.phase_t = mode.round_s
	await _until(func() -> bool: return events.round_over.size() > n0, 1.0)
	_expect(events.round_over.size() == n0 + 1 and (events.round_over.back() as Array) == ["loss", "health"] and mode.score == Vector2i(0, 1),
			"time-out on level ground, the player at half health: the foe's round on health (%s, %s)" % [events.round_over.back(), mode.score])
	mode._skip = true
	await _go_fight()
	n0 = events.round_over.size()
	mode.phase_t = mode.round_s
	await _until(func() -> bool: return events.round_over.size() > n0, 1.0)
	_expect(events.round_over.size() == n0 + 1 and (events.round_over.back() as Array) == ["draw", "time"] and mode.score == Vector2i(0, 1),
			"time-out on level ground, level health: a draw (%s, %s)" % [events.round_over.back(), mode.score])
	_expect(mode.round_left_s() == 0.0 and mode.phase == "OVER", "the time left 0 after the time-out")
	await _edges()


## A fall off a long side is a ring-out, the last knocker's; winded in the last zone is a ring-out, the winder's; the match
## lost.
func _edges() -> void:
	mode._skip = true
	await _go_fight()
	var f := foe()
	var fe := mode.end_of(f)
	var side := ring.global_basis.z.normalized()
	var n0: int = events.round_over.size()
	# (over the ropes: launched steeply up and out from a metre inside them)
	_settle(f, at_s(fe, 9.0, ring.half_w() - 1.0))
	await _ticks(2)
	BendStatus.knock(f, side * 6.0 + Vector3.UP * 14.0, player)
	await _until(func() -> bool: return events.round_over.size() > n0, 4.0)
	_expect(events.round_over.size() == n0 + 1 and (events.round_over.back() as Array) == ["win", "ringout"] and mode.last_by == player
			and mode.score == Vector2i(1, 1),
			"launched over the ropes off a long side: a ring-out, the knocker's (%s, by the player %s, score %s)" % [
			events.round_over.back(), mode.last_by == player, mode.score])
	mode._skip = true
	await _go_fight()
	f = foe()
	(mode.rules.state[player.get_instance_id()] as Dictionary)["confined"] = 3
	_settle(player, at_s(mode.end_of(player), 14.0))
	await _ticks(2)
	n0 = events.round_over.size()
	Hit.deliver(player, 999.0, player.global_position + Vector3.UP, back_of(mode.end_of(player)), f)
	await _until(func() -> bool: return events.round_over.size() > n0, 1.0)
	_expect(events.round_over.size() == n0 + 1 and (events.round_over.back() as Array) == ["loss", "winded"] and mode.last_by == f
			and not player.is_dead and mode.score == Vector2i(1, 2),
			"winded in the last zone: out, the winder's round (%s, score %s, alive %s)" % [events.round_over.back(), mode.score, not player.is_dead])
	mode._skip = true
	await _until(func() -> bool: return mode.phase == "DONE", 2.0)
	_expect(mode.phase == "DONE" and events.match_over.back() == 1 and mode.winner == 1, "the match lost: match_over(1) (%s)" % [events.match_over])
