extends SceneTree
## Round 2's guards and effects (skills_r2 spec §2.5, §2.6, §2.8, §2.9, §3; the owner's answers 2026-10-05: "one is good but
## dont forget the other elements"), in Tidebreak's ring (scenes/ring.tscn; the foe held where he stands and used as the one
## who shoots): each element's guard made on the player (BendZone with his element: r2) and met by a shot timed to arrive
## at 0.2 s (perfect) or 0.6 s (late) of it, the specs passed straight to BendZone, BendBolt, BendEffects and BendThrow:
##   earth     Catch: every stone kind (a bolt, a pebble, a spike, a boulder, a chunk) caught and held, perfect or late, the
##             catcher not moved an inch; its window and radius today's; fire passes. The return: the lock 0.35 s, 0.1 s
##             off a clean catch; x1.2 clean; the rally's steps and its x1.6 cap; never under gust.stone.hurl; two taps of E
##             in all (catch, throw back); held 10 s with hold_drop_s 0 and still held
##   water     Turn: a water bolt on the beat swings round the waist and leaves along the aim x1.2; fire on the beat is
##             doused; a Wave on the beat parts round him; late, half gets through; stone passes; a whiff makes the next
##             guard's lock whiff_lock_s. The Air Lance (the Gust held long; the owner, 2026-10-11): on the beat it wraps
##             round him and turns to ice (its body made anew, drawn short on the circle), his, and leaves an ice lance along
##             his aim x1.2; late, half gets through and it stays air; a plain air bolt passes as before
##   fire      Parry: fire on the beat circles him once like a moon (the owner, 2026-10-12) and leaves along the aim x1.2, no
##             dice thrown; air on the beat the same, turned to fire as it is caught; ice on the beat melts to a puddle;
##             lightning back only on the beat; late, half; water passes
##   air       Wind Guard: air on the beat circles him once and goes back x1.2, Carried wind charged; fire on the beat the
##             same, still fire; stone on the beat cushioned and dropped loose, late half
##   the Kick  the floor wave strikes a man standing and misses one 0.7 m up; a wall stops it; its line and form the same at
##             any crosshair pitch; a jump 0.2 s before it reaches him clears it
##   High Kick its crescent clears a 2 m wall
##   lightning it strikes flash_s after the release; a man 1.5 m aside by then is missed
##   steer     Flowing: a water bolt bends 15 deg at most
##   weight    the heavier stone goes on, equal ones both break
##   each      every element's guard alike (the owner: "dont forget the other elements"): a guard that took nothing is a
##             whiff (its caster's guarded signal, its meta), the next guard's lock whiff_lock_s within whiff_s and its own
##             again after; its perfect and late sounds its own and different; a Parry on the beat sends the Kick's floor wave
##             back along the floor and the High Kick's crescent back along the aim
## METRIC lines (perfect_window_ok, late_half_ok, catch_return_inputs, late_catch_zero_slide_ok, kick_floor_jump_miss_ok,
## kick_form_pitch_free_ok, high_kick_clears_wall_ok, lightning_flash_dodge_ok). Last line "R2 GUARDS PASSED" or
## "R2 GUARDS FAILED"; exit 0 only on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_r2_guards.gd

const NAME := "R2 GUARDS"
const WATCHDOG_S := 480.0
const OWN_CFG := "user://r2_guards_test.cfg"
const STONE := {"kind": "stone", "mps": 40.0, "gravity": 0.0, "damage": 20.0, "knock_mps": 6.0, "up_mps": 0.0, "radius_m": 0.25,
		"range_m": 30.0}
const KICK := {"do": "floor_wave", "kind": "fire", "width_m": 2.2, "height_m": 0.9, "miss_above_m": 0.6, "mps": 18.0,
		"range_m": 16.0, "damage": 18.0, "knock_mps": 7.0, "up_mps": 1.5}
const HIGH_KICK := {"do": "throw", "kind": "fire", "shape": "crescent", "width_m": 1.6, "mps": 22.0, "gravity": 9.0,
		"damage": 16.0, "knock_mps": 5.0, "up_mps": 4.0, "range_m": 30.0}

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode
var foe: NpcFighter
var fbc: BodyBendCaster
var metrics := {}
var _foe_at := Vector3.INF
var _hold_y := -INF
var _perfect_ok := true
var _late_ok := true
var _late_kinds := {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"
	seed(1750)
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	# (the merge: rules.json plays the % ring by default; this test is the classic ring's, pinned)
	RingRules.rule_set_override = "classic"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _hold_foe() -> void:
	if foe == null or not is_instance_valid(foe):
		return
	foe.held = true
	if _foe_at == Vector3.INF:
		_foe_at = foe.global_position
	foe.global_position = _foe_at
	foe.velocity = Vector3.ZERO
	if _hold_y > -INF and p != null:
		p.global_position.y = _hold_y
		p.velocity = Vector3.ZERO


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null, "the ring and its player")
	if p == null:
		return _end()
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 6.0)
	rm = RingMode.find(self)
	if rm != null:
		await _until(func() -> bool: return rm.phase == "FIGHT", 10.0)
		foe = rm.foe
		rm.rules.soft_walls = false
	_expect(foe != null, "the foe")
	if foe == null:
		return _end()
	fbc = BendCaster.of(foe) as BodyBendCaster
	_expect(fbc != null, "the foe's caster (%s)" % BendCaster.of(foe))
	if fbc == null:
		return _end()
	fbc.scatter_deg = 0.0                        # (his shots go where he aims: the test's timing, not his skill)
	fbc.lead = 0.0
	physics_frame.connect(_hold_foe)
	await _secs(0.4)
	await _earth()
	await _return()
	await _water()
	await _fire()
	await _air()
	await _kick()
	await _high_kick()
	await _lightning()
	await _steer()
	await _weights()
	await _whiffs()
	await _parry_kicks()
	metrics["perfect_window_ok"] = _perfect_ok
	metrics["late_half_ok"] = _late_ok
	_end()


func _end() -> void:
	if c != null:
		c.held_override = null
		c.guard_override = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = ""
	GameSettings.path = GameSettings.PATH
	for k: String in metrics:
		print("METRIC %s=%s" % [k, str(metrics[k])])
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


## The player whole and still at a spot 9 m before the foe facing him, as `el`, nothing bent about.
func _calm(el := "") -> void:
	c.held_override = false
	c.guard_override = false
	_hold_y = -INF
	if el != "" and p.arena_element != el:
		Bending.of(p).element = el
		await _until(func() -> bool: return p.arena_element == el, 3.0)
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP, GustLift.GROUP, FormEffects.Throw.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()
	for b: Node in [p, foe]:
		for k: StringName in BendStatus.ROUND_METAS:
			if b.has_meta(k):
				b.remove_meta(k)
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	var to := (_foe_at - p.global_position)
	var axis := rm.ring.axis()
	var at := _foe_at - axis * signf(axis.dot(_foe_at - rm.ring.center())) * 9.0
	at.y = rm.ring.deck_y()
	var face := _foe_at - at
	face.y = 0.0
	RingLevel.place(p, Transform3D(Basis.looking_at(face.normalized(), Vector3.UP), at))
	p.velocity = Vector3.ZERO
	p.health = p.max_health
	p.pitch = -0.05
	fbc.target = p
	await _secs(0.35)


func _chest() -> Vector3:
	return p.global_position + Vector3.UP * 1.2


## A shot of `spec` from the foe arriving at the player's chest from `d` m off along the line from the foe.
func _shoot(spec: Dictionary, d: float) -> BendBolt:
	var dir := (_chest() - NpcSenses.chest_of(foe)).normalized()
	return BendBolt.launch(foe, _chest() - dir * d, dir, spec)


## The Air Lance's bolt: the Gust's spec with its grow (moves.json air_gust gust: a spear of air thrown point first).
func _lance_spec() -> Dictionary:
	var g: Dictionary = ((SwayMoves.move("air_gust").bend as Dictionary).gust as Dictionary).duplicate(true)
	var grow: Dictionary = g.get("grow", {})
	g.erase("grow")
	g.merge(grow, true)
	return g


## A guard `kind` of `spec` made on the player now.
func _guard(kind: String, spec: Dictionary) -> BendZone:
	return BendZone.make(p, kind, p.global_position, spec, BendCaster.of(p).facing())


## A shot of `spec` met on the beat by guard `kind`'s moon (BendZone._moon_back): [took it, circling him (his, swinging),
## left along his aim x1.2 once the lap was over, no dice thrown, its kind as it left]; `kind_after` is what it should be
## when caught.
func _moon(kind: String, gspec: Dictionary, spec: Dictionary, kind_after: String) -> Array:
	await _calm()
	var z := _guard(kind, gspec)
	await _secs(0.2)
	var b := _shoot(spec, 4.0)
	b.set_physics_process(false)
	b.global_position = _chest() + (NpcSenses.chest_of(foe) - _chest()).normalized() * 1.5
	var v0 := b.velocity.length()
	seed(4242)
	var r0 := randf()
	seed(4242)
	var acted := z.on_bolt(b)
	var r1 := randf()
	var circling: bool = acted and b.caster == p and b.swinging() and b.kind == kind_after
	b.set_physics_process(true)
	await _until(func() -> bool: return not is_instance_valid(b) or not b.swinging(), BendZone.MOON_S + 0.3)
	await _ticks(2)
	var left := false
	var k := ""
	if is_instance_valid(b) and not b.spent:
		var aim := BendZone.guard_aim(p, b.global_position)
		left = b.velocity.normalized().dot((aim - b.global_position).normalized()) > 0.97 and absf(b.velocity.length() - v0 * 1.2) < 0.05
		k = b.kind
	return [acted, circling, left, r0 == r1, k]


## The player's health lost to a shot of `spec` met by guard `kind` (none: "") made `wait` s before it arrives: [lost, zone,
## bolt, the zone's results (its own array: read after the zone is gone)].
func _met(kind: String, gspec: Dictionary, spec: Dictionary, wait: float) -> Array:
	await _calm()
	var z: BendZone = _guard(kind, gspec) if kind != "" else null
	var res: Array[String] = z.results if z != null else ([] as Array[String])
	await _secs(wait)
	var b := _shoot(spec, (z.radius if z != null else 2.0) + 0.6)
	await _secs(0.25)
	return [p.max_health - p.health, z, b, res]


# ---------------------------------------------------------------- earth (spec §2.6)
func _held() -> Node3D:
	return BendZone.held_stone(p)


func _earth() -> void:
	await _calm("earth")
	var cspec: Dictionary = (SwayMoves.move("stone_catch").bend as Dictionary).catch
	var z := _guard("catch", cspec)
	_expect(z.r2 and is_equal_approx(z.life_s, float(cspec.get("window_s", 1.0))) and is_equal_approx(z.radius, float(cspec.get("radius_m", 3.5))),
			"Catch: today's window and radius (%.2f s, %.2f m)" % [z.life_s, z.radius])
	await _calm()
	var at0 := p.global_position
	var r := await _met("catch", cspec, STONE, 0.2)
	var zp: Array = r[3]
	var hs := _held()
	var perfect := zp == ["perfect"] and hs != null and bool(hs.get_meta(&"bend_clean", false))
	_expect(perfect and float(r[0]) == 0.0, "Catch on the beat: held, clean, nothing through (%s, %.1f)" % [zp, r[0]])
	_perfect_ok = _perfect_ok and perfect
	var r2 := await _met("catch", cspec, STONE, 0.6)
	var zl: Array = r2[3]
	hs = _held()
	var late := zl == ["late"] and hs != null and not bool(hs.get_meta(&"bend_clean", true)) and float(r2[0]) == 0.0
	_expect(late, "Catch late: still a full catch, held, not clean (%s, %.1f through)" % [zl, r2[0]])
	# every stone kind, late: held, the catcher not moved
	var kinds := {}
	var slide := 0.0
	var slides := {}
	for k: String in ["pebble", "spike", "boulder", "chunk"]:
		await _calm()
		var before := p.global_position
		await _stone_kind(k, cspec)
		var got := _held() != null
		kinds[k] = got
		slides[k] = snappedf(Vector2(p.global_position.x - before.x, p.global_position.z - before.z).length(), 0.001)
		slide = maxf(slide, float(slides[k]))
	var all := not kinds.values().has(false)
	for k: String in _late_kinds:
		all = all and _late_kinds[k] == ["late"]
	_expect(all and slide < 0.05, "a late catch of every stone kind holds it with no slide (%s %s; slid %s m)" % [kinds, _late_kinds, slides])
	metrics["late_catch_zero_slide_ok"] = all and slide < 0.05
	# fire, water, air pass
	var base := await _met("", {}, {"kind": "fire", "mps": 40.0, "damage": 20.0, "knock_mps": 2.0, "radius_m": 0.2, "range_m": 30.0}, 0.0)
	var thru := await _met("catch", cspec, {"kind": "fire", "mps": 40.0, "damage": 20.0, "knock_mps": 2.0, "radius_m": 0.2, "range_m": 30.0}, 0.2)
	_expect(float(base[0]) > 0.0 and is_equal_approx(float(thru[0]), float(base[0])), "Catch lets fire through (%.1f of %.1f)" % [thru[0], base[0]])


## A stone of kind `k` thrown at the player by the foe, met late by a catch (made as it flies).
func _stone_kind(k: String, cspec: Dictionary) -> void:
	match k:
		"pebble":
			var z := _guard("catch", cspec)
			await _secs(0.6)
			_shoot({"kind": "stone", "flight": "flick", "mps": 34.0, "damage": 7.0, "knock_mps": 2.0, "radius_m": 0.09, "range_m": 30.0}, z.radius + 0.6)
			await _secs(0.3)
			_late_kinds[k] = z.results
		"spike", "boulder":
			var z := _guard("catch", cspec)            # (made as he throws: it arrives past perfect_s, a late catch)
			BendCast.cast(fbc, "stone_form", "spike" if k == "spike" else "cannonball")
			await _until(func() -> bool: return _held() != null, 2.0)
			_late_kinds[k] = z.results
			await _secs(0.1)
		"chunk":
			var wall := FormEffects.earth_wall(fbc, NpcSenses.chest_of(foe) + (_chest() - NpcSenses.chest_of(foe)).normalized() * 2.0,
					SwayMoves.move("earth_wall"))
			await _secs(1.0)
			var face := wall.global_position + Vector3.UP * 1.0
			var z := _guard("catch", cspec)
			await _secs(0.25)
			FormEffects.gust_chunk(fbc, wall, face, (_chest() - face).normalized())
			await _until(func() -> bool: return _held() != null, 2.0)
			_late_kinds[k] = z.results
			await _secs(0.1)


func _flying() -> GustLift:
	for l in get_nodes_in_group(GustLift.GROUP):
		if (l as GustLift).phase == GustLift.Phase.FLIGHT:
			return l as GustLift
	return null


# ---------------------------------------------------------------- the return (spec §2.6)
func _return() -> void:
	await _calm("earth")
	var cspec: Dictionary = (SwayMoves.move("stone_catch").bend as Dictionary).catch
	# two taps of E in all: catch, then throw back
	var taps := 0
	c.guard_override = true
	taps += 1
	await _ticks(3)
	c.guard_override = false
	await _until(func() -> bool: return get_nodes_in_group(BendZone.GROUP).any(func(z: Node) -> bool: return (z as BendZone).kind == "catch"), 1.0)
	await _secs(0.1)
	_shoot(STONE, 4.1)
	var caught := await _until(func() -> bool: return _held() != null, 1.5)
	var hs := _held()
	var clean := hs != null and bool(hs.get_meta(&"bend_clean", false))
	await _secs(0.2)
	c.guard_override = true
	taps += 1
	await _ticks(2)
	var lock := c.lock_s
	c.guard_override = false
	var thrown := await _until(func() -> bool: return _flying() != null, 1.5)
	var fl := _flying()
	var toward := fl != null and fl.velocity.normalized().dot((NpcSenses.chest_of(foe) - fl.stone.global_position).normalized()) > 0.7
	var want_lock := Bending.rule("perfect_return_lock_s", 0.1) if clean else Bending.rule("return_lock_s", 0.35)
	_expect(caught < INF and absf(lock - want_lock) < 0.02, "the return's lock: %.2f s (%s catch; want %.2f)" % [lock, "clean" if clean else "late", want_lock])
	var ok := caught < INF and thrown < INF and toward and taps == 2
	_expect(ok, "catch and return in two taps of E, the stone back at the foe (%s)" % ("flying" if fl != null else "-"))
	metrics["catch_return_inputs"] = taps if ok else -1
	# the numbers: x1.2 clean, the rally's steps and cap, never under gust.stone.hurl
	await _calm()
	var s := FormStone.ball(current_scene, p.global_position + Vector3(0, 1.1, 1.3), {"radius_m": 0.25, "rise_s": 0.01}, 1, "stone")
	s.set_meta(&"bend_clean", true)
	var m1 := BendZone.return_mult(s)
	s.set_meta(&"bend_clean", false)
	s.set_meta(&"bend_rally", 0.1)
	var m2 := BendZone.return_mult(s)
	s.set_meta(&"bend_rally", 0.3)
	var m3 := BendZone.return_mult(s)
	s.set_meta(&"bend_rally", 2.0)
	var m4 := BendZone.return_mult(s)
	_expect(is_equal_approx(m1, 1.2) and is_equal_approx(m2, 1.1) and is_equal_approx(m3, 1.3) and is_equal_approx(m4, 1.6),
			"the return: x1.2 clean, the rally +0.1 a return, at most x1.6 (%.2f %.2f %.2f %.2f)" % [m1, m2, m3, m4])
	s.set_meta(&"bend_rally", 0.0)
	s.set_meta(&"bend_clean", true)
	s.set_meta(&"bend_held_by", p.get_instance_id())
	s.set_meta(&"bend_stone_d", {"mps": 34.0, "damage": 7.0, "knock_mps": 2.0})
	BendZone.return_stone(BendCaster.of(p), s)
	var ret: Dictionary = s.get_meta(&"bend_return", {})
	var floor_d: Dictionary = ((SwayMoves.move("gust").stone as Dictionary).hurl as Dictionary).get(GustLift.kind_of(s), {})
	var fd: Array = floor_d.get("damage", [0.0, 0.0])
	_expect(float(ret.get("damage", 0.0)) >= float(fd[fd.size() - 1]) - 0.01 and is_equal_approx(float(s.get_meta(&"bend_rally", 0.0)), 0.2),
			"a pebble's return never under gust.stone.hurl (%.1f >= %.1f), a clean return's rally step 0.2" % [float(ret.get("damage", 0.0)), float(fd[fd.size() - 1])])
	# held 10 s with hold_drop_s 0: still held
	await _calm()
	_guard("catch", cspec)
	await _secs(0.5)
	_shoot(STONE, 4.1)
	await _until(func() -> bool: return _held() != null, 1.5)
	var h0 := _held()
	await _secs(10.0)
	_expect(h0 != null and is_instance_valid(h0) and _held() == h0 and (h0 as FormStone).state != FormStone.State.SINKING,
			"a caught stone is still held after 10 s (hold_drop_s %.1f)" % Bending.rule("hold_drop_s", 0.0))


# ---------------------------------------------------------------- water's Turn
func _water() -> void:
	await _calm("water")
	var tspec := {"do": "zone", "zone": "redirect", "window_s": 0.8, "radius_m": 2.2}
	var water := {"kind": "water", "mps": 30.0, "gravity": 0.0, "damage": 20.0, "knock_mps": 5.0, "radius_m": 0.2, "range_m": 30.0}
	var base := await _met("", {}, water, 0.0)
	await _calm()
	var z := _guard("redirect", tspec)
	await _secs(0.2)
	var b := _shoot(water, 2.8)
	var v0 := b.velocity.length()
	var swung := await _until(func() -> bool: return b.swinging(), 0.5)
	await _until(func() -> bool: return not is_instance_valid(b) or not b.swinging(), 1.0)
	var aim := BendZone.guard_aim(p, b.global_position) if is_instance_valid(b) else Vector3.ZERO
	var along := is_instance_valid(b) and b.velocity.normalized().dot((aim - b.global_position).normalized()) > 0.95
	var fast := is_instance_valid(b) and absf(b.velocity.length() - v0 * 1.2) < 0.5
	_expect(swung < INF and along and fast and z.results == ["perfect"] and p.health == p.max_health,
			"Turn on the beat: the water swings round him and leaves along his aim x1.2 (%s %s %s)" % [swung, along, fast])
	_perfect_ok = _perfect_ok and swung < INF and along
	var late := await _met("redirect", tspec, water, 0.6)
	var half := absf(float(late[0]) - float(base[0]) * 0.5) < 1.0
	_expect(late[3] == ["late"] and half, "Turn late: half gets through (%.1f of %.1f)" % [late[0], base[0]])
	_late_ok = _late_ok and half
	var fire := await _met("redirect", tspec, {"kind": "fire", "mps": 40.0, "damage": 20.0, "knock_mps": 2.0, "radius_m": 0.2, "range_m": 30.0}, 0.2)
	_expect(float(fire[0]) == 0.0 and fire[3] == ["perfect"], "Turn on the beat douses fire (%.1f through)" % fire[0])
	var st := await _met("redirect", tspec, STONE, 0.2)
	_expect(float(st[0]) > 0.0 and st[3].is_empty(), "Turn lets stone pass (%.1f)" % st[0])
	# the Air Lance: on the beat it wraps round him as ice and leaves along his aim x1.2, his
	var lance := _lance_spec()
	var lbase := await _met("", {}, lance, 0.0)
	await _calm()
	var zl := _guard("redirect", tspec)
	await _secs(0.2)
	var lb := _shoot(lance, 2.8)
	var lv0 := lb.velocity.length()
	var l_swung := await _until(func() -> bool: return lb.swinging(), 0.5)
	var iced := is_instance_valid(lb) and lb.kind == "ice" and lb.caster == p and lb.find_child("Look", false, false) != null
	var wrapped := is_instance_valid(lb) and lb._look != null and lb._look.scale.z < 1.0
	await _secs(0.1)
	wrapped = wrapped or (is_instance_valid(lb) and lb.swinging() and lb._look != null and lb._look.scale.z < 0.9)
	await _until(func() -> bool: return not is_instance_valid(lb) or not lb.swinging(), 1.0)
	var l_aim := BendZone.guard_aim(p, lb.global_position) if is_instance_valid(lb) else Vector3.ZERO
	var l_along := is_instance_valid(lb) and lb.velocity.normalized().dot((l_aim - lb.global_position).normalized()) > 0.95
	var l_fast := is_instance_valid(lb) and absf(lb.velocity.length() - lv0 * 1.2) < 0.6
	var l_ice := is_instance_valid(lb) and lb.kind == "ice" and lb.shape == "spear"
	_expect(l_swung < INF and iced and wrapped and l_along and l_fast and l_ice and zl.results == ["perfect"] and p.health == p.max_health,
			"Turn on the beat takes the Air Lance: it wraps round him as ice and leaves an ice lance along his aim x1.2 (%s ice %s wrapped %s along %s fast %s)"
			% [l_swung, iced, wrapped, l_along, l_fast])
	await _secs(0.4)
	var ll := await _met("redirect", tspec, lance, 0.6)
	var l_half := absf(float(ll[0]) - float(lbase[0]) * 0.5) < 1.0
	var l_air := not is_instance_valid(ll[2]) or (ll[2] as BendBolt).kind == "air"
	_expect(ll[3] == ["late"] and l_half and l_air, "Turn late on the Air Lance: half gets through, still air (%.1f of %.1f)" % [ll[0], lbase[0]])
	var airb := await _met("redirect", tspec, {"kind": "air", "mps": 30.0, "gravity": 0.0, "damage": 20.0, "knock_mps": 5.0, "radius_m": 0.2, "range_m": 30.0}, 0.2)
	_expect(float(airb[0]) > 0.0 and airb[3].is_empty(), "Turn lets a plain air bolt pass, the Lance alone is taken (%.1f)" % airb[0])
	# a Wave on the beat parts round him
	await _calm()
	_guard("redirect", tspec)
	await _secs(0.1)
	var flat := (_chest() - NpcSenses.chest_of(foe))
	flat.y = 0.0
	foe.global_position = p.global_position - flat.normalized() * 4.0
	_foe_at = foe.global_position
	await physics_frame
	BendEffects.cone(foe, NpcSenses.chest_of(foe), flat.normalized(), {"kind": "water", "range_m": 9.0, "deg": 50.0, "damage": 10.0, "knock_mps": 11.0})
	_expect(p.health == p.max_health, "a Wave on the beat parts round the Turn (%.1f)" % (p.max_health - p.health))
	_foe_at = Vector3.INF
	rm.ring.spawn(1 - rm.player_end)
	foe.global_position = rm.ring.spawn(1 - rm.player_end).origin
	await physics_frame
	# a whiff: the next guard's lock slower
	await _calm()
	var wz := _guard("redirect", tspec)
	await _secs(1.0)
	_expect(not is_instance_valid(wz) or wz.is_queued_for_deletion(), "the Turn's window ended")
	_expect(BendStatus.until(p, &"bend_whiff_until") > 0.0 and is_equal_approx(BendZone.guard_lock_s(p, 0.2), Bending.rule("whiff_lock_s", 0.5))
			and String((p.get_meta(&"bend_last_guard", {}) as Dictionary).get("result", "")) == "whiff",
			"a whiff: the next guard's lock %.2f s within whiff_s" % BendZone.guard_lock_s(p, 0.2))


# ---------------------------------------------------------------- fire's Parry
func _fire() -> void:
	await _calm("fire")
	var pspec := {"do": "zone", "zone": "parry", "window_s": 0.8, "radius_m": 2.5}
	var fire := {"kind": "fire", "mps": 32.0, "gravity": 0.0, "damage": 20.0, "knock_mps": 5.0, "radius_m": 0.2, "range_m": 30.0}
	var base := await _met("", {}, fire, 0.0)
	# on the beat: it circles him once like a moon (the owner, 2026-10-12), then leaves along the aim x1.2; no dice
	var moon := await _moon("parry", pspec, fire, "fire")
	_expect(moon[0] and moon[1] and moon[2] and moon[3], "Parry on the beat: it circles him once like a moon, then leaves along his aim x1.2, no dice thrown (%s)" % [moon])
	_perfect_ok = _perfect_ok and moon[2]
	# air too (the owner, 2026-10-12, "Counter it"): turned to fire as it is caught
	var air := {"kind": "air", "mps": 28.0, "gravity": 0.0, "damage": 6.0, "knock_mps": 11.0, "radius_m": 0.35, "range_m": 30.0}
	var turned := await _moon("parry", pspec, air, "fire")
	_expect(turned[0] and turned[1] and turned[2] and turned[4] == "fire",
			"Parry on the beat: air turned to fire, circled once and sent back along his aim x1.2 (%s)" % [turned])
	var late := await _met("parry", pspec, fire, 0.6)
	var half := absf(float(late[0]) - float(base[0]) * 0.5) < 1.0
	_expect(late[3] == ["late"] and half, "Parry late: half gets through (%.1f of %.1f)" % [late[0], base[0]])
	_late_ok = _late_ok and half
	var ice := await _met("parry", pspec, {"kind": "ice", "mps": 38.0, "damage": 20.0, "knock_mps": 2.0, "radius_m": 0.15, "range_m": 30.0}, 0.2)
	var puddle := get_nodes_in_group(BendZone.GROUP).any(func(n: Node) -> bool: return (n as BendZone).kind == "puddle")
	_expect(float(ice[0]) == 0.0 and puddle, "Parry on the beat melts ice to a puddle (%.1f through)" % ice[0])
	var water := await _met("parry", pspec, {"kind": "water", "mps": 30.0, "damage": 20.0, "knock_mps": 2.0, "radius_m": 0.2, "range_m": 30.0}, 0.2)
	_expect(float(water[0]) > 0.0, "Parry lets water pass (%.1f)" % water[0])
	# lightning: back only on the beat
	var light := {"do": "lightning", "kind": "lightning", "damage": 30.0, "range_m": 45.0, "knock_mps": 2.0}
	await _calm()
	_guard("parry", pspec)
	await _secs(0.15)
	foe.health = foe.health_max
	BendEffects.apply(fbc, "fire_arc", "lightning", light)
	var rec := BendEffects.last_of(foe)
	await _ticks(2)
	var on_beat := bool(rec.get("redirected", false)) and p.health == p.max_health
	await _calm()
	_guard("parry", pspec)
	await _secs(0.5)
	BendEffects.apply(fbc, "fire_arc", "lightning", light)
	var rec2 := BendEffects.last_of(foe)
	await _ticks(2)
	var late_hit := not bool(rec2.get("redirected", false)) and p.health < p.max_health
	_expect(on_beat and late_hit, "lightning is sent back only by a Parry on the beat (beat %s, late hit %s)" % [on_beat, late_hit])


# ---------------------------------------------------------------- air's Wind Guard
func _air() -> void:
	await _calm("air")
	var gspec := {"do": "zone", "zone": "air_shield", "at": "self", "window_s": 0.8, "radius_m": 2.2}
	var air := {"kind": "air", "mps": 28.0, "gravity": 0.0, "damage": 6.0, "knock_mps": 11.0, "radius_m": 0.35, "range_m": 30.0}
	await _calm()
	var z := _guard("air_shield", gspec)
	await _secs(0.2)
	var b := _shoot(air, 2.8)
	var v0 := b.velocity.length()
	# (it circles him once like a moon first, the owner 2026-10-12: x1.2 as it leaves)
	await _until(func() -> bool: return not is_instance_valid(b) or (b.caster == p and not b.swinging()), 0.6 + BendZone.MOON_S)
	var bounced := is_instance_valid(b) and b.caster == p and absf(b.velocity.length() - v0 * 1.2) < 0.2
	_expect(bounced and z.results == ["perfect"] and BendStatus.until(p, &"bend_carry_until") > 0.0,
			"Wind Guard on the beat: air circled once and sent back x1.2, Carried wind charged (%s)" % [z.results])
	_perfect_ok = _perfect_ok and bounced
	var st := await _met("air_shield", gspec, STONE, 0.2)
	var loose := get_nodes_in_group(FormStone.GROUP).any(func(n: Node) -> bool: return n.has_meta(FormStone.LOOSE_META))
	_expect(float(st[0]) == 0.0 and loose, "Wind Guard on the beat: a stone cushioned and dropped loose (%.1f through)" % st[0])
	var base := await _met("", {}, STONE, 0.0)
	var late := await _met("air_shield", gspec, STONE, 0.6)
	var half := absf(float(late[0]) - float(base[0]) * 0.5) < 1.0
	_expect(late[3] == ["late"] and half, "Wind Guard late on stone: half gets through (%.1f of %.1f)" % [late[0], base[0]])
	_late_ok = _late_ok and half
	# fire too (the owner, 2026-10-12): circled once and sent back, still fire
	var fire := await _moon("air_shield", gspec, {"kind": "fire", "mps": 40.0, "gravity": 0.0, "damage": 20.0, "knock_mps": 2.0, "radius_m": 0.2, "range_m": 30.0}, "fire")
	_expect(fire[0] and fire[1] and fire[2] and fire[4] == "fire", "Wind Guard on the beat: fire circled once and sent back along his aim x1.2, still fire (%s)" % [fire])
	await _calm("earth")


# ---------------------------------------------------------------- the Kick (spec §2.8, §3.3)
func _wave_at_player(spec: Dictionary) -> BendBolt:
	return BendEffects.floor_wave(fbc, {}, spec)


func _kick() -> void:
	await _calm("earth")
	var b := _wave_at_player(KICK)
	await _until(func() -> bool: return not is_instance_valid(b) or b.spent, 2.0)
	var hit := p.health < p.max_health
	_expect(hit, "the Kick's floor wave strikes a man standing (%.1f)" % (p.max_health - p.health))
	await _calm()
	_hold_y = p.global_position.y + 0.7
	await _ticks(2)
	b = _wave_at_player(KICK)
	await _secs(1.2)
	var up_missed := p.health == p.max_health
	_expect(up_missed, "and misses one whose feet are 0.7 m up (%.1f)" % (p.max_health - p.health))
	# a wall stops it
	await _calm()
	var mid := (NpcSenses.chest_of(foe) + _chest()) * 0.5
	FormEffects.earth_wall(p, mid, SwayMoves.move("earth_wall"))
	await _secs(1.0)
	b = _wave_at_player(KICK)
	var why := [""]
	b.ended.connect(func(w: String) -> void: why[0] = w)
	await _secs(1.2)
	_expect(why[0] == "wall" and p.health == p.max_health, "a wall stops the floor wave (%s)" % why[0])
	# the line and the form the same at any pitch (the player's own Kick)
	await _calm()
	var pbc := BendCaster.of(p)
	p.pitch = 0.0
	await _ticks(2)
	var w1 := BendEffects.floor_wave(pbc, {}, KICK)
	var d1 := Vector2(w1.velocity.x, w1.velocity.z).normalized()
	var f1 := [w1.width_m, w1.height_m, w1.velocity.y]
	p.pitch = -0.6
	await _ticks(2)
	var w2 := BendEffects.floor_wave(pbc, {}, KICK)
	var d2 := Vector2(w2.velocity.x, w2.velocity.z).normalized()
	var f2 := [w2.width_m, w2.height_m, w2.velocity.y]
	var free := d1.dot(d2) > 0.9999 and f1 == f2
	_expect(free, "the Kick's line and form do not change with the crosshair's pitch (%s %s; %s %s)" % [d1, d2, f1, f2])
	metrics["kick_form_pitch_free_ok"] = free
	await _secs(1.0)
	# a jump 0.2 s before it reaches him clears it
	await _calm()
	var dist := Vector2(_foe_at.x - p.global_position.x, _foe_at.z - p.global_position.z).length()
	b = _wave_at_player(KICK)
	var reach_s := (dist - 0.7) / float(KICK.mps)
	await _secs(maxf(reach_s - 0.2 - 1.0 / Engine.physics_ticks_per_second, 0.0))
	Input.action_press(&"jump")                 # (Space: the jump the next frame, 0.2 s before the wave reaches him)
	await _ticks(3)
	Input.action_release(&"jump")
	await _secs(1.0)
	var jumped := p.health == p.max_health
	_expect(jumped, "a jump (%.1f m/s) 0.2 s before the wave reaches him clears it (%.1f)" % [p.jump_velocity, p.max_health - p.health])
	metrics["kick_floor_jump_miss_ok"] = hit and up_missed and jumped


# ---------------------------------------------------------------- the High Kick
func _high_kick() -> void:
	await _calm("earth")
	var mid := (NpcSenses.chest_of(foe) + _chest()) * 0.5
	var wall := FormEffects.earth_wall(p, mid, SwayMoves.move("earth_wall"))
	await _secs(1.0)
	var tall := wall != null and wall.size.y >= 2.0
	var a := BendEffects.aim(fbc, HIGH_KICK)
	var b := BendThrow.throw(fbc, a, HIGH_KICK)
	var why := [""]
	b.ended.connect(func(w: String) -> void: why[0] = w)
	await _secs(2.0)
	var ok: bool = tall and why[0] != "wall" and why[0] != ""
	_expect(ok, "the High Kick's crescent clears a %.1f m wall (it ended: %s)" % [wall.size.y if wall != null else 0.0, why[0]])
	metrics["high_kick_clears_wall_ok"] = ok


# ---------------------------------------------------------------- lightning's flash (spec §3.3)
func _lightning() -> void:
	await _calm("earth")
	var light := {"do": "lightning", "kind": "lightning", "damage": 30.0, "range_m": 45.0, "knock_mps": 2.0, "flash_s": 0.25}
	var t0 := BendStatus.now()
	BendEffects.apply(fbc, "fire_arc", "lightning", light)
	var rec := BendEffects.last_of(foe)
	await _secs(0.5)
	var lag := float(rec.get("struck_at", -1.0)) - t0
	_expect(absf(lag - 0.25) < 0.04 and int(rec.get("hit", 0)) == 1, "lightning strikes flash_s after the release (%.2f s, hit %s)" % [lag, rec.get("hit")])
	await _calm()
	BendEffects.apply(fbc, "fire_arc", "lightning", light)
	rec = BendEffects.last_of(foe)
	var side := BendCaster.of(p).facing().cross(Vector3.UP).normalized()
	p.global_position += side * 1.5
	await _secs(0.5)
	var dodged := int(rec.get("hit", 1)) == 0 and p.health == p.max_health
	_expect(dodged, "a man 1.5 m aside by the strike is missed (%s)" % rec.get("hit"))
	metrics["lightning_flash_dodge_ok"] = dodged and absf(lag - 0.25) < 0.04


# ---------------------------------------------------------------- Flowing's steer
func _steer() -> void:
	await _calm("water")
	var pbc := BendCaster.of(p)
	p.yaw += PI                                   # (down the long deck, away from the foe: nothing in its way)
	await _ticks(3)
	var a := BendEffects.aim(pbc, {})
	BendEffects.bolts(pbc, a, {"kind": "water", "mps": 30.0, "gravity": 0.0, "damage": 1.0, "knock_mps": 0.0, "radius_m": 0.15, "range_m": 40.0})
	var b: BendBolt = null
	for n in get_nodes_in_group(BendBolt.GROUP):
		if (n as BendBolt).caster == p:
			b = n
	var v0 := b.velocity if b != null else Vector3.ZERO
	p.yaw += deg_to_rad(40.0)
	await _secs(0.35)
	var turned := rad_to_deg(v0.angle_to(b.velocity)) if b != null and is_instance_valid(b) else -1.0
	_expect(b != null and turned > 5.0 and turned <= 15.2, "a water bolt bends toward the aim, 15 deg at most (%.1f deg)" % turned)
	await _calm("earth")


# ---------------------------------------------------------------- weights (spec §2.9)
func _weights() -> void:
	await _calm()
	var at := (_chest() + NpcSenses.chest_of(foe)) * 0.5 + Vector3.UP * 2.0
	var heavy := BendBolt.launch(foe, at + Vector3.LEFT * 2.0, Vector3.RIGHT, STONE.merged({"weight": "heavy"}))
	var medium := BendBolt.launch(p, at + Vector3.RIGHT * 2.0, Vector3.LEFT, STONE.merged({"weight": "medium"}))
	await _secs(0.2)
	var h_on := is_instance_valid(heavy) and not heavy.spent
	var m_gone := not is_instance_valid(medium) or medium.spent
	_expect(m_gone and h_on, "stone meets stone: the heavier goes on (heavy on %s, medium gone %s)" % [h_on, m_gone])
	var a := BendBolt.launch(foe, at + Vector3.LEFT * 2.0 + Vector3.FORWARD * 3.0, Vector3.RIGHT, STONE)
	var b := BendBolt.launch(p, at + Vector3.RIGHT * 2.0 + Vector3.FORWARD * 3.0, Vector3.LEFT, STONE)
	await _secs(0.2)
	_expect((not is_instance_valid(a) or a.spent) and (not is_instance_valid(b) or b.spent), "equal ones both break")


# ---------------------------------------------------------------- every element's whiff and sounds (the owner's answers)
## Each element's guard zone and its spec as the player's E makes it.
const GUARD_ZONES := {"earth": ["catch", {"do": "zone", "zone": "catch", "window_s": 1.0, "radius_m": 3.5}],
		"water": ["redirect", {"do": "zone", "zone": "redirect", "window_s": 0.8, "radius_m": 2.2}],
		"fire": ["parry", {"do": "zone", "zone": "parry", "window_s": 0.8, "radius_m": 2.5}],
		"air": ["air_shield", {"do": "zone", "zone": "air_shield", "at": "self", "window_s": 0.8, "radius_m": 2.2}]}


func _whiffs() -> void:
	for el: String in Bending.ELEMENTS:
		await _calm(el)
		var told: Array = []
		var bc := BendCaster.of(p)
		var on := func(result: String, _what: String) -> void: told.append(result)
		bc.guarded.connect(on)
		var g: Array = GUARD_ZONES[el]
		var z := _guard(String(g[0]), g[1] as Dictionary)
		var life := z.life_s
		await _secs(life + 0.1)
		var last: Dictionary = p.get_meta(&"bend_last_guard", {})
		var slow := BendZone.guard_lock_s(p, 0.2)
		await _secs(Bending.rule("whiff_s", 1.5) + 0.1)
		var again := BendZone.guard_lock_s(p, 0.2)
		bc.guarded.disconnect(on)
		_expect(told == ["whiff"] and String(last.get("result", "")) == "whiff" and String(last.get("element", "")) == el
				and is_equal_approx(slow, Bending.rule("whiff_lock_s", 0.5)) and is_equal_approx(again, 0.2),
				"%s's guard that took nothing: a whiff told (%s), its next guard's lock %.2f s, %.2f s after whiff_s" % [el, told, slow, again])
		var snd: Array = BendLooks.GUARD_SOUNDS.get(el, [])
		_expect(snd.size() == 2 and snd[0] != snd[1] and BendSounds.has(StringName(snd[0])) and BendSounds.has(StringName(snd[1])),
				"%s's guard sounds its own: perfect %s, late %s" % [el, snd[0] if snd.size() > 0 else "-", snd[1] if snd.size() > 1 else "-"])
	await _calm("earth")


# ---------------------------------------------------------------- the Parry against the kicks
## A bolt of the foe's `b` met by the player's Parry made as it comes within reach (on the beat): whether it went back his.
func _parried(b: BendBolt) -> bool:
	var near := await _until(func() -> bool: return not is_instance_valid(b) or b.spent \
			or b.global_position.distance_to(_chest()) < 4.0, 2.0)
	if near == INF or not is_instance_valid(b) or b.spent:
		return false
	var z := _guard("parry", {"do": "zone", "zone": "parry", "window_s": 0.8, "radius_m": 2.5})
	var res: Array[String] = z.results
	await _until(func() -> bool: return not is_instance_valid(b) or b.caster == p, 0.5)
	return is_instance_valid(b) and b.caster == p and res == ["perfect"]


func _parry_kicks() -> void:
	await _calm("fire")
	var w := _wave_at_player(KICK)
	var back := await _parried(w)
	var away := is_instance_valid(w) and Vector2(w.velocity.x, w.velocity.z).dot(Vector2(_foe_at.x - p.global_position.x, _foe_at.z - p.global_position.z)) > 0.0
	var low := is_instance_valid(w) and w.floor_wave and absf(w.global_position.y - w.deck_y) < 0.05
	_expect(back and away and low and p.health == p.max_health, "a Parry on the beat sends the Kick's floor wave back along the floor (%s %s %s)" % [back, away, low])
	await _calm("fire")
	var hk := BendThrow.throw(fbc, BendEffects.aim(fbc, HIGH_KICK), HIGH_KICK)
	var back2 := await _parried(hk)
	_expect(back2 and p.health == p.max_health, "and the High Kick's crescent back along his aim (%s)" % back2)
	await _calm("earth")
