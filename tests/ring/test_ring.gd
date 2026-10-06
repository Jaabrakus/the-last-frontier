extends SceneTree
## The Tidebreak ring as a light scene (scenes/ring.tscn: RingLevel, RingArena, RingWater; data/ring/ring.json; the owner,
## 2026-10-04: the elemental ring sport "Tidebreak"; zones read from the deck's own build, no painted or lit lines):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring.gd [-- baseline=<dir>]
##   scene    it loads with the level's parts (EnvironmentRig, RingArena, the player, Bending's meter, the caster)
##   deck     the player stands on the deck at spawn(0) after 2 s (|y| < 0.2); FormEffects.ground_at on the deck about 0;
##            each zone's deck part is its own body, laid in its own stone or wood (form_matter "earth", surface stone/wood)
##   zones    zone_of: 0 at the centre, 1, 2, 3 at s 2.5, 7.5, 12.5 on both sides, 4 past 17 m; spawns 9 m apart
##   grates   Bending.near_water true standing on a grate (the grates in Bending.POOLS)
##   earth    an Earth Wall cast on the deck is earth (FormMatter from the deck's meta form_matter, not "stone"); cast 0.3 m
##            from the deck's long edge, no part of it shows under y -0.6 outside the plinth, rising or up
##   ropes    a 10 m/s knock toward a long side leaves the player on the deck after 1.5 s, not rung out
##   out      a stone pushed off the open end is rung out within 0.5 s (is_ring_out), splashing (the water's splashed
##            signal); the player dropped into the tank is rung out and keeps full health (no fall hurts)
##   sockets  each side's stones sit in their sockets; one taken away, another rises there refill_s later
##   clear    clear_dropped takes every listed group's nodes in the ring and the tank, not one far away, nor a seated stone
##   terrain  FrontierTerrain's baked data never loaded in 10 s or more in the scene (its static _data_ok read directly:
##            data_loaded() would load it); WorldRiver.off while the ring stands
##   time     the first frame's time logged (RING first_frame_ms); with baseline=<dir> written to
##            <dir>/ring_first_frame_ms.txt (informational: no limit is asserted on it)
## A watchdog ends it at LIMIT_S (under the runner's 300 s). The last line: "RING TEST PASSED" or "RING TEST FAILED".
## Round 3: pinned to the classic rule set (RingRules.rule_set_override "classic": the zones' ring this test was written for);
## the % ring's own checks are test_ring_stage, test_ring_pct, test_ring_hitstun and test_percent_hud.

const LIMIT_S := 240.0
const FormMatter := preload("res://scripts/sway/form_matter.gd")

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var splashed_bodies: Array[Node3D] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("RING TEST FAILED (watchdog)")
		quit(2))
	RingRules.rule_set_override = "classic"
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	_expect(lvl != null, "the scene is the ring (RingLevel)")
	if lvl == null:
		return _end()
	ring = lvl.ring
	player = lvl.player
	_expect(ring != null and player != null and lvl.get_node_or_null(^"EnvironmentRig") is EnvironmentRig,
			"its parts: EnvironmentRig, RingArena, the player")
	if ring == null or player == null:
		return _end()
	_expect(SwayCaster.of(player) != null and player.get_node_or_null(NodePath(Bending.NODE_NAME)) != null,
			"the caster and Bending's water meter on the player")
	_expect(WorldRiver.off and not WorldRiver.has_water(), "WorldRiver off in the ring")
	if ring.water != null:
		ring.water.splashed.connect(func(b: Node3D, _at: Vector3) -> void: splashed_bodies.append(b))
	await _deck()
	_zones()
	await _grates()
	await _earth()
	await _ropes()
	await _out()
	await _sockets()
	await _clear()
	# at least 10 s in the scene by now; FrontierTerrain's data never asked for
	var in_scene := (Time.get_ticks_msec() - t0) / 1000.0
	if in_scene < 10.0:
		await _secs(10.0 - in_scene)
	_expect(not FrontierTerrain._data_ok, "FrontierTerrain's baked data never loaded (%.0f s in the scene; tried: %s)" % [
			maxf(in_scene, 10.0), FrontierTerrain._data_tried])
	_expect(lvl.first_frame_ms > 0.0, "the first frame's time logged (%.0f ms)" % lvl.first_frame_ms)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("baseline="):
			var dir := a.substr(9)
			DirAccess.make_dir_recursive_absolute(dir)
			var f := FileAccess.open(dir.path_join("ring_first_frame_ms.txt"), FileAccess.WRITE)
			if f != null:
				f.store_line("%.0f" % lvl.first_frame_ms)
				f.close()
	_end()


func _end() -> void:
	if fails.is_empty() and checks > 0:
		print("RING TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("RING TEST FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _deck() -> void:
	await _secs(2.0)
	var sp := ring.spawn(0)
	var p := player.global_position
	_expect(absf(p.y - ring.deck_y()) < 0.2 and Vector2(p.x - sp.origin.x, p.z - sp.origin.z).length() < 0.5
			and player.is_on_floor(), "the player stands on the deck at spawn(0) after 2 s (%s, spawn %s)" % [p, sp.origin])
	var g := FormEffects.ground_at(player, Vector3(6.0, 0.5, -2.0))
	_expect(absf(g.y - ring.deck_y()) < 0.05, "FormEffects.ground_at on the deck about 0 (%.3f)" % g.y)
	var kinds := {}
	var ok := ring.decks.size() == 7
	for b in ring.decks:
		ok = ok and b.collision_layer & 1 and String(b.get_meta(&"form_matter", "")) == "earth"
		kinds[String(b.get_meta(&"surface", ""))] = true
	_expect(ok and kinds.has("stone") and kinds.has("wood"),
			"the deck in 7 layer-1 bodies (the neutral strip, three zones a side), form_matter earth, laid in stone and wood (%s)" % [kinds.keys()])
	var s0 := ring.spawn(0).origin
	var s1 := ring.spawn(1).origin
	_expect(absf(s0.distance_to(s1) - 9.0) < 0.01 and ring.zone_of(s0, 0) == 1 and ring.zone_of(s1, 1) == 1,
			"the spawns in each side's zone 1, 9 m apart (%.2f)" % s0.distance_to(s1))
	var props := 0
	for n in current_scene.get_children():
		if n is WeaponRack or n is PlacedWeapon:
			props += 1
	_expect(props == 0, "no gun racks or weapons standing about (the demo's taken away: %d)" % props)
	var f0 := -ring.spawn(0).basis.z
	_expect(f0.dot(ring.center() - s0) > 0.0, "spawn(0) faces the centre")


func _zones() -> void:
	var ok := true
	var got := []
	for side in 2:
		var sg := RingArena.side_sign(side)
		for e: Array in [[0.0, 0], [2.5, 1], [7.5, 2], [12.5, 3], [17.5, 4], [21.0, 4]]:
			var pos := ring.to_global(Vector3(sg * float(e[0]), 0.0, 1.0))
			var z := ring.zone_of(pos, side)
			got.append(z)
			ok = ok and z == int(e[1]) and absf(ring.s_of(pos, side) - float(e[0])) < 1e-4
	_expect(ok, "zone_of: 0 at the centre, 1/2/3 at s 2.5/7.5/12.5, 4 past 17 m, both sides (%s)" % [got])
	_expect(is_equal_approx(ring.line_s(0, 0), 2.0) and is_equal_approx(ring.line_s(1, 3), 17.0), "line_s: 2 m and the end at 17 m")
	var r := ring.rect_for(1, 1, 3)
	_expect(is_equal_approx(r.position.x, 2.0) and is_equal_approx(r.end.x, 17.0) and is_equal_approx(r.size.z, 14.0),
			"rect_for(side 1, zones 1-3): x 2..17, the deck's width (%s)" % r)
	_expect(ring.on_deck(Vector3(16.5, 0.0, 6.5)) and not ring.on_deck(Vector3(17.5, -0.2, 0.0)) and not ring.is_out(Vector3(16.9, 0.0, 0.0))
			and ring.is_out(Vector3(18.5, -0.7, 0.0)) and ring.is_out(Vector3(26.0, 0.0, 0.0)),
			"on_deck and is_out at the edges (the end at 17 m; below -0.6 out; on the walk round the tank out)")


func _grates() -> void:
	var pools := ring.pools()
	var in_group := true
	for g in pools:
		in_group = in_group and g.is_in_group(Bending.POOLS)
	_expect(pools.size() == 12 and in_group, "12 grates (2 on each of 3 lines a side) in Bending.POOLS (%d)" % pools.size())
	if pools.is_empty():
		return
	var g: Node3D = pools[4]
	RingLevel.place(player, Transform3D(Basis(), g.global_position))
	await _secs(0.3)
	var b := Bending.of(player)
	_expect(b != null and b.near_water() and absf(player.global_position.y - ring.deck_y()) < 0.2,
			"Bending.near_water standing on a grate (%s)" % g.global_position)


func _earth() -> void:
	var c := SwayCaster.of(player)
	if c == null:
		_expect(false, "the caster")
		return
	_expect(FormMatter.of_ground(self, Vector3(4.5, 0.0, 1.0)) == "earth"
			and FormMatter.of_ground(self, Vector3(-9.5, 0.0, 1.0)) == "earth",
			"FormMatter.of_ground on the deck's wood and stone: earth (the deck's form_matter)")
	# across the middle of zone 1, side 1
	RingLevel.place(player, Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), Vector3(2.5, 0.0, -1.0)))
	await _secs(0.2)
	var w := FormEffects.earth_wall(c, Vector3(5.0, 0.0, -1.0), SwayMoves.move("earth_wall"))
	_expect(w != null and w.matter == "earth", "an Earth Wall cast on the deck is earth, not stone (%s)" % (w.matter if w else "none"))
	# at the long edge, 0.3 m in, along it: no part of it under -0.6 outside the plinth (its foot plinth_out_m
##            wider than the deck under the drop), rising or up
	RingLevel.place(player, Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), Vector3(10.0, 0.0, 4.0)))
	await _secs(0.2)
	var hw := ring.half_w()
	var spot := Vector3(10.0, 0.0, hw - 0.3 - 0.75)
	var e := FormEffects.earth_wall(c, spot, SwayMoves.move("earth_wall"))
	var shows := 0
	var fh := ring.foot_half()
	var foot_z := e.base.origin.z if e != null else 0.0
	for i in 60:
		if e == null or not is_instance_valid(e):
			break
		var box := e.global_transform * (e.mesh_instance.mesh.get_aabb() if e.mesh_instance and e.mesh_instance.mesh else AABB())
		if box.position.y < -0.6 and (absf(box.position.z) > fh.y or absf(box.end.z) > fh.y
				or absf(box.position.x) > fh.x or absf(box.end.x) > fh.x):
			shows += 1
		await physics_frame
	_expect(e != null and absf(foot_z - (hw - 0.3)) < 0.1 and shows == 0,
			"an Earth Wall 0.3 m from the long edge (its foot at z %.2f) shows nothing under -0.6 outside the plinth (%d frames)" % [foot_z, shows])
	ring.clear_dropped()
	await _ticks(2)


func _ropes() -> void:
	RingLevel.place(player, ring.spawn(1))
	player.health = player.max_health
	await _secs(0.5)
	BendStatus.knock(player, Vector3(0.0, 0.0, 10.0), null)
	var out := false
	for i in int(1.5 * Engine.physics_ticks_per_second):
		out = out or ring.is_ring_out(player)
		await physics_frame
	_expect(ring.on_deck(player.global_position) and not out and absf(player.global_position.z) < ring.half_w(),
			"a 10 m/s knock toward a long side: on the deck after 1.5 s, never rung out (%s)" % player.global_position)
	# (up again, if it threw him down)
	await _secs(2.5)


func _out() -> void:
	# a stone pushed off the open end
	var s := RigidBody3D.new()
	s.name = "TestStone"
	s.mass = 20.0
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.25
	cs.shape = sp
	s.add_child(cs)
	current_scene.add_child(s)
	s.global_position = ring.to_global(Vector3(16.6, 0.3, 2.0))
	s.linear_velocity = ring.axis() * 4.0
	var early := ring.is_ring_out(s)
	var left := await _until(func() -> bool: return absf(ring.to_local(s.global_position).x) > ring.half_l(), 2.0)
	var t := await _until(func() -> bool: return ring.is_ring_out(s), 2.0)
	_expect(not early and left < 2.0 and t < 0.5,
			"a stone pushed off the open end is rung out within 0.5 s of leaving the deck (off at %.2f s, out %.2f s later)" % [left, t])
	var t2 := await _until(func() -> bool: return splashed_bodies.has(s), 2.0)
	_expect(t2 < 2.0 and ring.water.splashes >= 1, "it splashes into the water (the splashed signal)")
	s.queue_free()
	# the player into the tank
	player.health = player.max_health
	RingLevel.place(player, Transform3D(Basis(), ring.to_global(Vector3(-20.0, 0.6, 3.0))))
	t = await _until(func() -> bool: return ring.is_ring_out(player), 2.0)
	await _secs(2.0)
	var y := player.global_position.y
	_expect(t < 2.0 and ring.is_ring_out(player) and splashed_bodies.has(player) and y < RingArena.num("water_y", -1.4)
			and y > RingArena.num("floor_y", -3.4) - 0.2,
			"the player dropped into the tank: rung out, splashed, on its floor (y %.2f)" % y)
	_expect(is_equal_approx(player.health, player.max_health), "... at full health: no fall hurts (%.1f)" % player.health)
	_expect(ring.water.is_under_water(player.global_position + Vector3.UP * 0.5) and TorchState.under_water(ring.get_world_3d(), self,
			player.global_position + Vector3.UP * 0.3), "the tank's water is water to TorchState (WATER_GROUP)")
	RingLevel.place(player, ring.spawn(0))
	await _secs(0.5)


func _sockets() -> void:
	var n := ring.sockets.size()
	var seated := 0
	for sk: Dictionary in ring.sockets:
		var st: Variant = sk.get("stone")
		if st is FormStone and is_instance_valid(st) and (st as FormStone).is_in_group(FormStone.GROUP) \
				and Vector2((st as FormStone).global_position.x - (sk.at as Vector3).x, (st as FormStone).global_position.z - (sk.at as Vector3).z).length() < 0.3:
			seated += 1
	_expect(n >= 2 and seated == n, "the stones sit in their sockets (%d of %d)" % [seated, n])
	if n == 0:
		return
	var sk0: Dictionary = ring.sockets[0]
	var first: FormStone = sk0.stone
	first.freeze = true
	first.global_position = (sk0.at as Vector3) + Vector3(0.0, 0.4, 2.0) * (1.0 if (sk0.at as Vector3).z < 0.0 else -1.0)
	var refill := float((RingArena.data().get("sockets", {}) as Dictionary).get("refill_s", 8.0))
	await _ticks(3)
	_expect(sk0.stone == null, "one taken away: the socket empty")
	var t := await _until(func() -> bool: return sk0.stone is FormStone and is_instance_valid(sk0.stone) and sk0.stone != first, refill + 2.0)
	_expect(absf(t - refill) < 0.5, "another rises in it refill_s later (%.1f s, refill %.1f)" % [t, refill])
	if is_instance_valid(first):
		first.queue_free()


func _clear() -> void:
	var groups: Array[StringName] = [FormRaised.GROUP, FormHollow.GROUP, FormCircle.GROUP, FormStone.GROUP, BendBolt.GROUP,
			BendZone.GROUP, GustLift.GROUP, FormEffects.Throw.GROUP, NpcBending.FLIGHT_GROUP]
	var inside: Array[Node] = []
	var far: Array[Node] = []
	var i := 0
	for g in groups:
		for at: Vector3 in [Vector3(3.0 + i, 0.5, 1.0), Vector3(-21.0, -2.0, 10.0), Vector3(400.0, 0.0, 0.0)]:
			var n := Node3D.new()
			n.name = "Dropped_%s_%d" % [g, i]
			n.add_to_group(g)
			current_scene.add_child(n)
			n.global_position = at
			(far if at.x > 100.0 else inside).append(n)
		i += 1
	var seated_before: Array = []
	for sk: Dictionary in ring.sockets:
		seated_before.append(sk.stone)
	var c := ring.clear_dropped()
	await process_frame
	await process_frame
	var left := 0
	for n in inside:
		if is_instance_valid(n):
			left += 1
	var far_ok := true
	for n in far:
		far_ok = far_ok and is_instance_valid(n)
	var seated_ok := true
	for st: Variant in seated_before:
		seated_ok = seated_ok and (st == null or is_instance_valid(st))
	var stray := 0
	for g in groups:
		for n: Node in get_nodes_in_group(g):
			if n is Node3D and ring.in_bounds((n as Node3D).global_position) and not seated_before.has(n):
				stray += 1
	_expect(left == 0 and stray == 0 and c >= inside.size(), "clear_dropped takes what lies in the ring and the tank (%d taken, %d left)" % [c, left + stray])
	_expect(far_ok and seated_ok, "... not what lies far away, nor the stones seated in their sockets")
	for n in far:
		if is_instance_valid(n):
			n.queue_free()
