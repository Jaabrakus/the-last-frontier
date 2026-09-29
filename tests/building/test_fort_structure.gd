extends SceneTree
## The fort built from the build menu's pieces (FortPlan.stamp_structure, data/building/fort_structure.json; user
## 2026-09-28: "the fort should be recreated from builder pieces, not hardcoded"), without the level (a bare scene with a
## BuildWorld and the terrain's height function):
##   * the plan's pieces are all there, exactly where they are listed (no jitter), the structure flag is set
##   * the four walls are closed at the height of a chest: a ray across the perimeter every 5 cm finds the gate's clear
##     opening in the north wall and no other gap wider than a hand (the walls stop 10 cm short of the blockhouses)
##   * the firing step lies against the palisade's inside, a ramp's top meets its edge, the ladders have their climb markers
##   * the gate stands open at the start and its leaves stop a ray when shut; the blockhouses hang their doors where the
##     classic fort's were (the parade side of each)
##
##   Godot --headless --fixed-fps 120 --path . -s tests/building/test_fort_structure.gd
## "FORT STRUCTURE TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0
var world: BuildWorld


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _of(type: String) -> Array[BuiltPiece]:
	var out: Array[BuiltPiece] = []
	for p in world.pieces():
		if p.type == type:
			out.append(p)
	return out


func _blocked(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	return not world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## The unblocked runs along a side: rays across the wall (`axis`: the ray's direction, from outside to inside) at every
## `step` along the wall from `from` to `to`; returns [[start, end]] of the open runs (along the wall's coordinate).
func _gaps(fixed: Vector3, along: Vector3, axis: Vector3, from: float, to: float, y: float) -> Array:
	var runs := []
	var start := INF
	var t := from
	while t <= to + 0.001:
		var c := fixed + along * t + Vector3(0, y, 0)
		var open := not _blocked(c - axis * 3.0, c + axis * 3.0)
		if open and start == INF:
			start = t
		if not open and start != INF:
			runs.append([start, t - 0.05])
			start = INF
		t += 0.05
	if start != INF:
		runs.append([start, to])
	return runs


func _initialize() -> void:
	await process_frame
	var scene := Node3D.new()
	scene.name = "Level"
	root.add_child(scene)
	current_scene = scene
	world = BuildWorld.of(self)
	var n := FortPlan.stamp_structure(world)
	await _ticks(6)
	_check(world.fort_built, "the structure flag is set")
	var counts := {}
	for p in world.pieces():
		counts[p.type] = int(counts.get(p.type, 0)) + 1
	_check(n == 55 and world.pieces().size() == 55, "55 pieces stamped (%d, %d): %s" % [n, world.pieces().size(), str(counts)])
	_check(counts.get("palisade", 0) == 39 and counts.get("palisade_gate", 0) == 1 and counts.get("blockhouse", 0) == 2
			and counts.get("walkway", 0) == 8 and counts.get("walkway_ramp", 0) == 2 and counts.get("ladder", 0) == 2 and counts.get("flagpole", 0) == 1,
			"39 palisade sections, a gate, 2 blockhouses, 8 firing steps, 2 ramps, 2 ladders, the flag pole")
	# exactly where planned
	var first_n: BuiltPiece = null
	for p in _of("palisade"):
		if absf(p.global_position.z + 16.0) < 0.001 and absf(p.global_position.x + 12.15) < 0.001:
			first_n = p
	_check(first_n != null, "the north wall's first section stands at x -12.15 exactly")
	var gate := _of("palisade_gate")[0]
	_check(absf(gate.global_position.x) < 0.001 and absf(gate.global_position.z + 16.0) < 0.001 and gate.global_transform.basis.z.dot(Vector3.FORWARD) > 0.99,
			"the gate is in the middle of the north wall, its outside facing north (%s)" % str(gate.global_position))
	var pole := _of("flagpole")[0]
	_check(Vector2(pole.global_position.x + 6.0, pole.global_position.z + 2.0).length() < 0.001, "the flag pole is at (-6, -2)")
	# the stakes follow the ground (flat here): each has its height
	_check(first_n != null and first_n.ground.size() == BuildGeometry.STAKES, "each stake has its ground height (%d)" % (first_n.ground.size() if first_n else -1))

	# the walls are closed
	var y := 1.5
	var north := _gaps(Vector3(0, 0, -16.0), Vector3.RIGHT, Vector3(0, 0, 1), -17.0, 17.0, y)
	# (a run that starts past a corner, or ends before the other, is open air outside the wall: not a gap)
	var big := north.filter(func(r: Array) -> bool: return float(r[1]) - float(r[0]) > 0.15 and float(r[0]) < 16.15 and float(r[1]) > -16.15)
	_check(big.size() == 1 and absf(float(big[0][0]) + 1.04) < 0.12 and absf(float(big[0][1]) - 1.04) < 0.12,
			"the north wall has one gap wider than a hand: the gate's opening (%s)" % str(big))
	var sides := {"south": [Vector3(0, 0, 16.0), Vector3.RIGHT, Vector3(0, 0, 1)], "west": [Vector3(-16.0, 0, 0), Vector3(0, 0, 1), Vector3.RIGHT],
			"east": [Vector3(16.0, 0, 0), Vector3(0, 0, 1), Vector3.RIGHT]}
	for name: String in sides:
		var sd: Array = sides[name]
		var runs := _gaps(sd[0], sd[1], sd[2], -17.0, 17.0, y)
		var wide := runs.filter(func(r: Array) -> bool: return float(r[1]) - float(r[0]) > 0.15)
		wide = wide.filter(func(r: Array) -> bool: return float(r[0]) < 16.15 and float(r[1]) > -16.15)
		_check(wide.is_empty(), "the %s wall is closed (open runs: %s)" % [name, str(wide)])

	# the gate: open at the start, its leaves stop a ray when shut
	_check(gate.door != null and gate.door.is_open, "the gate stands open at the start")
	_check(not _blocked(Vector3(0, 1.2, -19.0), Vector3(0, 1.2, -12.0)), "a ray through the open gate passes")
	gate.door.set_open(false, true)
	await _ticks(4)
	_check(_blocked(Vector3(0.5, 1.2, -19.0), Vector3(0.5, 1.2, -12.0)), "shut, its leaves stop it")
	gate.door.set_open(true, true)

	# the firing step against the palisade's inside; ramps and ladders at its edge
	var lo := 999.0
	var hi := -999.0
	for w in _of("walkway"):
		var back := w.global_transform * Vector3(0, 0, -0.8)
		_check(absf(back.z + 15.8) < 0.01, "a firing step's back edge lies against the wall's inside face (z %.2f)" % back.z)
		lo = minf(lo, w.global_position.x)
		hi = maxf(hi, w.global_position.x)
	_check(lo < -11.9 and hi > 11.9, "the steps run both sides of the gate (x %.1f .. %.1f)" % [lo, hi])
	for r in _of("walkway_ramp"):
		var top := r.global_transform * Vector3(0, FortPieces.WALK_TOP, -FortPieces.RAMP_RUN * 0.5)
		var deck_edge := Vector3(r.global_position.x, FortPieces.WALK_TOP, -14.2)
		_check(top.distance_to(deck_edge) < 0.05, "the ramp at x %.0f meets the deck's edge (%s)" % [r.global_position.x, str(top)])
	for l in _of("ladder"):
		_check(l.get_node_or_null("Ladder") is TravLadder and absf(l.global_position.z + 13.95) < 0.001, "the ladder at x %.0f has its climb marker" % l.global_position.x)

	# the blockhouses' doors on the parade side
	var nw: BuiltPiece = null
	var se: BuiltPiece = null
	for b in _of("blockhouse"):
		if b.global_position.x < 0.0:
			nw = b
		else:
			se = b
	_check(nw != null and se != null and nw.door != null and se.door != null, "both blockhouses hang a door")
	if nw and se and nw.door and se.door:
		var d1 := nw.door.global_position
		var d2 := se.door.global_position
		_check(Vector2(d1.x + 14.8, d1.z + 13.75).length() < 0.05, "the north-west blockhouse's door is at (-14.8, -13.75) (%s)" % str(d1))
		_check(Vector2(d2.x - 14.8, d2.z - 13.75).length() < 0.05, "the south-east blockhouse's door is at (14.8, 13.75) (%s)" % str(d2))
		_check(_blocked(Vector3(-14.8, 1.0, -12.5), Vector3(-14.8, 1.0, -14.5)), "shut, the north-west door stops a ray")
		nw.door.set_open(true, true)
		await _ticks(4)
		_check(not _blocked(Vector3(-14.8, 1.0, -12.5), Vector3(-14.8, 1.0, -14.5)), "open, it lets it through")

	# taking the fort down is possible (ordinary pieces): a section goes, the gap opens
	var victim: BuiltPiece = null
	for p in _of("palisade"):
		if absf(p.global_position.z + 16.0) < 0.001 and absf(p.global_position.x + 9.1) < 0.001:
			victim = p
	_check(victim != null and _blocked(Vector3(-9.5, 1.5, -19.0), Vector3(-9.5, 1.5, -12.0)), "a palisade section stops a ray")
	if victim:
		world.remove_piece(victim)
		await _ticks(4)
		_check(not _blocked(Vector3(-9.5, 1.5, -19.0), Vector3(-9.5, 1.5, -12.0)), "taken down, its gap is open")

	if _fails.is_empty():
		print("FORT STRUCTURE TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("FORT STRUCTURE TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
