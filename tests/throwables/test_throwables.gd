extends "res://tests/throwables/harness.gd"
## Headless test of the thrown weapons (spear, tomahawk, atlatl) before they are wired
## into the player's weapon roster and animation graph. Loads the level, installs the
## throwables on the player with ThrowableKit (extra child weapons, not in the roster;
## player.gd untouched; harness.gd), drives the active one with scripted input and checks:
##   models      GLBs imported, markers present, sizes plausible
##   controls    hold to wind up (aim + arc), RMB/R cancel, release to throw, quick click,
##               sprint lets it down, EMPTY when none are left
##   launch      the throw leaves from where the object is in the hand (uniform with the
##               bow's arrow-from-the-bow fix), zeroed on the aim point
##   flight      the arc (ThrowableArc) lands where the throw lands; spear and dart stick
##               in the straw dummy point first; tomahawk sticks blade first at 5, 8.6 and
##               12.4 m (spin assist) and bounces at 6.3 m with raw physics (1.5 turns)
##   pickup      E at a stuck or fallen weapon returns it (up to max_count; no walk-over pickup since the E interaction)
## Damage, surfaces, the pickup key, phases, audio and clip names: test_throw_rules.gd.
##
##   Godot --headless --path . -s tests/throwables/test_throwables.gd -- --no-capture


func _initialize() -> void:
	if not await _boot():
		print("THROWABLES TEST FAILED")
		quit(1)
		return
	_test_models()
	await _test_spear()
	await _test_tomahawk()
	await _test_atlatl()
	await _test_arc_matches_flight()
	_finish("THROWABLES TEST")


# --- Tests -------------------------------------------------------------------------------

func _test_models() -> void:
	print("models")
	var expect_len := {"spear": [1.7, 1.9], "tomahawk": [0.45, 0.6], "atlatl": [0.5, 0.65], "atlatl_dart": [1.6, 1.8]}
	for kind: String in ThrowableModels.KINDS:
		_expect(ThrowableModels.has_glb(kind), "%s.glb imported" % kind)
		var m := ThrowableModels.build(kind)
		root.add_child(m)
		var aabb := _aabb(m)
		var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var r: Array = expect_len[kind]
		_expect(longest >= r[0] and longest <= r[1], "%s is %.2f m long (%.2f-%.2f)" % [kind, longest, r[0], r[1]])
		_expect(m.get_node_or_null("COM") is Marker3D, "%s has a COM marker" % kind)
		if kind != "atlatl_dart":
			_expect(m.get_node_or_null("Muzzle") is Marker3D, "%s has a Muzzle marker" % kind)
		if kind == "atlatl":
			_expect(m.get_node_or_null("Spur") is Marker3D, "atlatl has a Spur marker")
		m.queue_free()


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _test_spear() -> void:
	print("spear")
	var w := await _use("spear")
	var dummy := Vector3(0.0, 1.25, -45.0)          # 25 m dummy (lane x = 0), chest
	await _stand_and_aim(Vector3(0.0, 0.0, -31.0), dummy)
	_expect(w.state == Throwable.State.READY and w.count == 2, "spear ready, 2 carried")
	_expect(w.model.visible and w.aim == 0.0, "spear in hand, carried lowered")

	# Wind up: aim rises, arc shows.
	_fire(true)
	await _frames(30)
	_expect(w.is_winding() and w.aim > 0.5, "holding LMB winds up and raises the spear (aim %.2f)" % w.aim)
	var arc := player.get_node("ThrowableArc") as ThrowableArc
	_expect(arc._dots.visible and arc._dots.multimesh.visible_instance_count > 3, "trajectory arc drawn while winding up")
	var tip := w.model.get_node("Muzzle") as Node3D
	var along := (tip.global_position - w.model.global_position).normalized()
	_expect(along.dot(w._aim_dir) > 0.97, "raised spear points along the throw line (%.1f deg)" % rad_to_deg(acos(clampf(along.dot(w._aim_dir), -1, 1))))

	# Cancel with RMB/R: no throw, needs a fresh press.
	var c0 := cancels
	_cancel()
	await _frames(3)
	_expect(w.state == Throwable.State.READY and w.count == 2 and cancels == c0 + 1, "RMB/R while winding lowers without throwing")
	await _frames(30)
	_expect(w.state == Throwable.State.READY, "still holding LMB after a cancel does not wind up again")
	_fire(false)
	await _frames(4)

	# Sprint lets it down too.
	_fire(true)
	await _frames(20)
	# player.gd recomputes is_sprinting every tick from the keys, so set it for this tick.
	player.is_sprinting = true
	w.tick(DT)
	player.is_sprinting = false
	_expect(w.state == Throwable.State.READY, "sprinting lets the throw down")
	_fire(false)
	await _frames(4)

	# Full throw: leaves from the hand, flies into the dummy, sticks point first.
	var f0 := fired
	var hits0 := hits.size()
	# Lambdas capture locals by value: record into a dictionary.
	var at := {}
	var on_thrown := func(q: ThrownProjectile) -> void:
		at["from"] = q.global_position
		at["hand"] = w._hand_pos()
		at["held"] = w.model.global_transform * ThrowableModels.marker_pos(w.model, "COM")
	w.thrown.connect(on_thrown)
	var p := await _full_throw()
	w.thrown.disconnect(on_thrown)
	_expect(p != null and fired == f0 + 1 and w.count == 1, "release throws one spear (%d left)" % w.count)
	if p == null or at.is_empty():
		return
	var from: Vector3 = at["from"]
	_expect(from.distance_to(at["held"]) < 0.01 and from.distance_to(at["hand"]) < 0.12,
			"the spear leaves from where it is held (%.3f m from the held spear, %.3f m from the grip bone)" % [
			from.distance_to(at["held"]), from.distance_to(at["hand"])])
	_expect(not w.model.visible, "the spear is gone from the hand after the throw")
	var phase := await _wait_rest(p)
	var dummy_hit := false
	for h in hits.slice(hits0):
		dummy_hit = dummy_hit or _is_dummy(h[0])
	_expect(dummy_hit, "full wind-up at 14 m hits the dummy")
	_expect(phase == ThrownProjectile.Phase.STUCK, "spear sticks in the straw dummy")
	if phase == ThrownProjectile.Phase.STUCK:
		var nose := -p.global_basis.z
		_expect(nose.dot(Vector3.FORWARD) > 0.8, "stuck point first, along its flight")
	await _frames(int((w.follow_time + w.draw_time) * 120) + 10)
	_expect(w.state == Throwable.State.READY and w.model.visible, "the second spear is taken up")

	# Pick the first one up again.
	_expect(await _pick_up(p), "E at the stuck spear picks it up")
	_expect(w.count == 2, "spear count back to 2")

	# Quick click still throws once the minimum wind-up has passed.
	await _stand_and_aim(Vector3(0.0, 0.0, -31.0), dummy)
	var before := w.count
	_fire(true)
	await _frames(2)
	_fire(false)
	await _frames(int((w.min_windup + w.release_time) * 120) + 10)
	_expect(w.count == before - 1, "a quick click still throws (weak)")
	var weak := w.last_thrown
	await _frames(int((w.follow_time + w.draw_time) * 120) + 10)
	# Throw the last one: none left.
	var last := await _full_throw()
	await _frames(int(w.follow_time * 120) + 10)
	_expect(w.count == 0 and w.state == Throwable.State.EMPTY, "no spears left: EMPTY")
	_expect(not w.trajectory_params().size(), "no arc with nothing in hand")
	for q in [weak, last]:
		var ph := await _wait_rest(q)
		var picked := await _pick_up(q) if is_instance_valid(q) else false
		print("    rest phase %d, picked %s" % [ph, picked])
	_expect(w.count == 2, "both spears picked up again (%d)" % w.count)
	await _frames(int(w.draw_time * 120) + 10)


func _test_tomahawk() -> void:
	print("tomahawk")
	var w := await _use("tomahawk") as ThrowableTomahawk
	var dummy := Vector3(-2.5, 1.2, -30.0)          # 10 m dummy (lane x = -2.5), chest
	_expect(w.state == Throwable.State.READY and w.count == 2, "tomahawk ready, 2 carried")
	# Blade-first sticks at 1, 2 and 3 turns with the thrower's judgement (spin assist).
	for d: float in [5.0, 8.6, 12.4]:
		await _stand_and_aim(Vector3(-2.5, 0.0, -30.0 + d), dummy)
		var hits0 := hits.size()
		var p := await _full_throw()
		if p == null:
			_expect(false, "tomahawk thrown at %.1f m" % d)
			continue
		var turns := p.spin_rate / TAU
		var rec := {}
		p.hit.connect(func(c: Object, pt: Vector3, stuck: bool) -> void:
			if not rec.has("c"):
				rec["c"] = str(c.get("name") if c else "null")
				rec["pt"] = pt
				rec["stuck"] = stuck
				rec["blade"] = -p.global_basis.z)
		var phase := await _wait_rest(p)
		print("    first hit: ", rec)
		var dummy_hit := false
		for h in hits.slice(hits0):
			dummy_hit = dummy_hit or _is_dummy(h[0])
		_expect(dummy_hit and phase == ThrownProjectile.Phase.STUCK,
				"at %.1f m it hits and sticks blade first (%.2f turns/s)" % [d, turns])
		if phase == ThrownProjectile.Phase.STUCK:
			var blade := -p.global_basis.z
			_expect(blade.dot(Vector3.FORWARD) > cos(deg_to_rad(55.0)), "  blade into the target")
		await _pick_up(p)
		await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "tomahawks picked up again (%d)" % w.count)
	# Raw physics at 1.5 turns: the haft hits and it bounces off.
	w.spin_assist = 0.0
	await _stand_and_aim(Vector3(-2.5, 0.0, -30.0 + 6.3), dummy)
	var p := await _full_throw()
	var phase := await _wait_rest(p)
	_expect(phase == ThrownProjectile.Phase.LYING, "without spin assist at 6.3 m (~1.5 turns) it bounces off and lies on the ground")
	if phase == ThrownProjectile.Phase.LYING:
		_expect(await _pick_up(p), "a fallen tomahawk is picked up too")
	w.spin_assist = 1.0
	await _frames(int(w.draw_time * 120) + 10)


func _test_atlatl() -> void:
	print("atlatl")
	var w := await _use("atlatl") as ThrowableAtlatl
	var dummy := Vector3(0.0, 1.25, -45.0)
	await _stand_and_aim(Vector3(0.0, 0.0, -19.0), dummy)
	_expect(w.count == 5 and w.model.visible and w.dart.visible, "atlatl in hand with a dart seated, 5 darts")
	var spur := w.model.global_transform * ThrowableModels.marker_pos(w.model, "Spur")
	var nock := w.dart.global_transform * ThrowableModels.marker_pos(w.dart, "Nock")
	_expect(spur.distance_to(nock) < 0.01, "the dart's butt sits in the hook (%.3f m)" % spur.distance_to(nock))
	var hits0 := hits.size()
	var p := await _full_throw()
	_expect(p != null and w.count == 4, "cast one dart (%d left)" % w.count)
	if p == null:
		return
	_expect(p.velocity.length() > 25.0, "full cast leaves at %.1f m/s" % p.velocity.length())
	_expect(w.model.visible and not w.dart.visible, "the board stays in hand, the dart is gone")
	var phase := await _wait_rest(p)
	var dummy_hit := false
	for h in hits.slice(hits0):
		dummy_hit = dummy_hit or _is_dummy(h[0])
	_expect(dummy_hit and phase == ThrownProjectile.Phase.STUCK, "full cast at 26 m sticks in the dummy")
	await _frames(int((w.follow_time + w.draw_time) * 120) + 10)
	_expect(w.state == Throwable.State.READY and w.dart.visible, "next dart fitted to the hook")
	_expect(await _pick_up(p), "the dart is picked up again")
	_expect(w.count == 5, "darts back to 5")


## With spread off, the arc's landing point is where the throw lands.
func _test_arc_matches_flight() -> void:
	print("arc vs flight")
	for key: String in ["spear", "atlatl"]:
		var w := await _use(key)
		var keep := [w.spread_base, w.spread_move, w.spread_undercharge, w.fire_bloom, w.spread_air]
		w.spread_base = 0.0
		w.spread_move = 0.0
		w.spread_undercharge = 0.0
		w.fire_bloom = 0.0
		w.spread_air = 0.0
		w._bloom = 0.0
		w.spread = 0.0
		# Aim at open ground 20 m out, off the lanes.
		await _stand_and_aim(Vector3(8.0, 0.0, -21.0), Vector3(8.0, 0.0, -41.0))
		_fire(true)
		for i in 240:
			await _frames(1)
			if w.state == Throwable.State.HOLDING:
				break
		await _frames(30)
		var prm := w.trajectory_params()
		var excl: Array[RID] = [player.get_rid()]
		var predicted := ThrownProjectile.predict_impact(player.get_world_3d(), prm.origin, prm.velocity, prm.gravity, prm.drag, excl)
		var rec := {}
		var before := w.last_thrown
		_fire(false)
		for i in 120:
			await _frames(1)
			if w.last_thrown != before:
				break
		var p := w.last_thrown
		if p != before and p != null:
			p.hit.connect(func(_c: Object, pt: Vector3, _s: bool) -> void:
				if not rec.has("landed"):
					rec["landed"] = pt)
			await _wait_rest(p)
		var landed: Vector3 = rec.get("landed", Vector3.INF)
		var ok := not predicted.is_empty() and landed != Vector3.INF
		var err: float = (predicted.point as Vector3).distance_to(landed) if ok else INF
		_expect(ok and err < 0.5, "%s: arc lands within %.2f m of the throw (%.1f m out)" % [key, err,
				(prm.origin as Vector3).distance_to(landed) if ok else 0.0])
		w.spread_base = keep[0]
		w.spread_move = keep[1]
		w.spread_undercharge = keep[2]
		w.fire_bloom = keep[3]
		w.spread_air = keep[4]
		if is_instance_valid(p):
			await _pick_up(p)
