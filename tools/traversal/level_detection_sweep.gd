extends SceneTree
## Detection check on the Frontier level geometry (adversarial review 2026-09-24). Builds the level's colliders the way
## scripts/world/frontier_level.gd does (real FrontierTerrain and FrontierVegetation colliders,
## headless; the fort and range colliders copied from _fort() / _range()), bakes the traversal
## ledge graph on it (timed), then sweeps approaches with the TraversalController exactly as the
## player hook would call it (empty shape registry: nothing in the level registers traversal
## metadata today):
##   A  every static shape within 90 m of the fort: 8 headings, walked up to in 0.1 m steps, at a
##      sprint (free-run) and at a walk with Space (careful); first plan or the none reason
##   B  2000 random terrain points 26-150 m out, random headings, sprint: moves on terrain
## Prints a table per piece kind and writes data/traversal/reports/level_detection.json.
## The fort / range colliders are COPIES of scripts/world/frontier_level.gd _fort() / _range() (keep
## them in step when the level changes); terrain and vegetation are the real builders.
##
##   Godot --headless --path . -s tools/traversal/level_detection_sweep.gd     (~3 min)

const OUT := "res://data/traversal/reports/level_detection.json"
const FORT_HALF := 16.0
const GATE_HALF := 3.0

var level: Node3D
var runner: CharacterBody3D
var ctrl: TraversalController


func _initialize() -> void:
	level = Node3D.new()
	level.name = "Level"
	root.add_child(level)
	var settings := WorldSettings.preset("low")
	var terrain := FrontierTerrain.new()
	terrain.name = "Terrain"
	level.add_child(terrain)
	terrain.build(settings)
	_fort()
	_range()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1776
	var veg := FrontierVegetation.new()
	veg.name = "Vegetation"
	level.add_child(veg)
	veg.build(settings, rng)
	await physics_frame
	await physics_frame
	var registry := TravShapeRegistry.new()
	var baker := TravLedgeBaker.new(registry, TravMoveLibrary.shared().settings)
	var t0 := Time.get_ticks_usec()
	var ledges := baker.bake(level, level.get_world_3d().direct_space_state)
	var bake_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("BAKE %.1f ms: %s" % [bake_ms, JSON.stringify(baker.report)])
	runner = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	runner.add_child(cs)
	level.add_child(runner)
	ctrl = TraversalController.new()
	runner.add_child(ctrl)
	ctrl.setup(runner, {"registry": registry, "ledges": ledges})
	await physics_frame
	var res := {"bake_ms": bake_ms, "bake": baker.report, "beams": [], "pieces": {}, "terrain": {}}
	for id in ledges.beams:
		var bm: Dictionary = ledges.beams[id]
		res.beams.append({"a": str(bm.a), "b": str(bm.b), "width": bm.width, "source": str(bm.get("source", ""))})
	# A: static shapes near the fort
	var space := level.get_world_3d().direct_space_state
	var shapes := []
	for node in level.find_children("*", "CollisionShape3D", true, false):
		var c := node as CollisionShape3D
		var body := c.get_parent()
		if body == runner or body is Area3D:
			continue
		var bname := str(body.name)
		if bname.begins_with("TerrainBody") or bname.begins_with("GroundFloor") or bname.begins_with("WorldEdge") or bname.begins_with("Ground"):
			continue
		var p := c.global_position
		if Vector2(p.x, p.z).length() > 90.0:
			continue
		shapes.append(c)
	print("shapes near the fort: ", shapes.size())
	var summary := {}
	var t_sel := []
	for c: CollisionShape3D in shapes:
		var kind := _kind(c)
		var center := c.global_position
		var ext := _extent(c)
		for k in 8:
			var ang := k * PI / 4.0 + 0.2
			var hd := Vector3(sin(ang), 0, cos(ang))
			for prof in ["sprint", "walk"]:
				var r := await _approach(c, center, hd, ext, prof, t_sel)
				var key := "%s|%s" % [kind, prof]
				if not summary.has(key):
					summary[key] = {}
				var o := str(r.result)
				summary[key][o] = int(summary[key].get(o, 0)) + 1
				if not res.pieces.has(key):
					res.pieces[key] = []
				(res.pieces[key] as Array).append(r)
	# B: terrain
	var trng := RandomNumberGenerator.new()
	trng.seed = 42
	var tsum := {}
	var tlist := []
	for i in 2000:
		var ang := trng.randf() * TAU
		var dist := trng.randf_range(26.0, 150.0)
		var p := Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		p.y = FrontierTerrain.collision_height_at(p.x, p.z)
		var hdg := trng.randf() * TAU
		var hd := Vector3(sin(hdg), 0, cos(hdg))
		var out := _probe_at(p, hd, "sprint", t_sel)
		var o := str(out.result)
		tsum[o] = int(tsum.get(o, 0)) + 1
		if o.begins_with("move:"):
			var n := FrontierTerrain.normal_at(p.x, p.z)
			out["slope_deg"] = rad_to_deg(acos(clampf(n.y, -1, 1)))
			out["p"] = str(p)
			tlist.append(out)
	res.terrain = {"summary": tsum, "moves": tlist}
	t_sel.sort()
	var perf := {"n": t_sel.size(), "mean_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0}
	if not t_sel.is_empty():
		var s := 0.0
		for v in t_sel:
			s += float(v)
		perf.mean_ms = s / t_sel.size() / 1000.0
		perf.p95_ms = float(t_sel[int(t_sel.size() * 0.95)]) / 1000.0
		perf.max_ms = float(t_sel[t_sel.size() - 1]) / 1000.0
	res["can_traverse_cost"] = perf
	print("\nPIECES (kind|gait: outcome counts over 8 headings x shapes)")
	var keys := summary.keys()
	keys.sort()
	for key in keys:
		print("  %-26s %s" % [key, JSON.stringify(summary[key])])
	print("\nTERRAIN random sprint probes: %s" % JSON.stringify(tsum))
	for t in tlist:
		print("  terrain move %s" % JSON.stringify(t))
	print("\ncan_traverse cost on the level: %s" % JSON.stringify(perf))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " ", false))
	f.close()
	print("LEVEL REVIEW DONE")
	quit(0)


func _kind(c: CollisionShape3D) -> String:
	var b := c.get_parent()
	var n := str(b.name)
	if b.has_meta("review_kind"):
		return str(b.get_meta("review_kind"))
	if n.begins_with("Trunks"):
		var r := float((c.shape as CylinderShape3D).radius) if c.shape is CylinderShape3D else 0.0
		var h := float((c.shape as CylinderShape3D).height) if c.shape is CylinderShape3D else 0.0
		return "tree r%s top%s" % ["<0.37" if r < 0.37 else ">=0.37", "3.0" if absf(h - 0.3 - 3.0) < 0.16 else "other"]
	if n.begins_with("Rocks"):
		return "rock"
	if n.begins_with("Stumps"):
		return "stump"
	if n.begins_with("Logs"):
		return "log"
	return n


func _extent(c: CollisionShape3D) -> float:
	var sh := c.shape
	if sh is BoxShape3D:
		var s: Vector3 = (sh as BoxShape3D).size
		return 0.5 * maxf(s.x, s.z)
	if sh is CylinderShape3D:
		return (sh as CylinderShape3D).radius
	if sh is ConvexPolygonShape3D:
		var m := 0.0
		for p in (sh as ConvexPolygonShape3D).points:
			m = maxf(m, Vector2(p.x, p.z).length())
		return m
	return 1.0


func _approach(c: CollisionShape3D, center: Vector3, hd: Vector3, ext: float, prof: String, t_sel: Array) -> Dictionary:
	var space := level.get_world_3d().direct_space_state
	var d := ext + 3.2
	var last := {}
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	while d > 0.0:
		var p := center - hd * d
		# On the terrain (never on top of a prop: the sweep walks on the ground)
		p.y = FrontierTerrain.collision_height_at(p.x, p.z) if not FrontierTerrain.in_flat_zone(p.x, p.z) else 0.0
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = cap
		sq.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.9)
		sq.exclude = [runner.get_rid()]
		if not space.intersect_shape(sq, 1).is_empty():
			break
		var out := _probe_at(p, hd, prof, t_sel)
		if str(out.result).begins_with("move:"):
			out["dist"] = d - ext
			return out
		last = out
		d -= 0.1
	if last.is_empty():
		return {"result": "start_blocked"}
	return last


func _probe_at(p: Vector3, hd: Vector3, prof: String, t_sel: Array) -> Dictionary:
	runner.global_position = p
	var sp := 5.6 if prof == "sprint" else 1.6
	runner.velocity = hd * sp
	var yaw := atan2(-hd.x, -hd.z)
	var inp := {"move": Vector2(0, -1), "sprint": prof == "sprint", "walk": prof == "walk", "yaw": yaw}
	ctrl._jump_buffer = 0.15 if prof == "walk" else 0.0
	var ctx := ctrl.context(inp)
	var t0 := Time.get_ticks_usec()
	var plan := ctrl.can_traverse(ctx)
	t_sel.append(Time.get_ticks_usec() - t0)
	if plan == null:
		return {"result": "none:" + ctrl.last_none}
	if plan.kind == "step_assist":
		return {"result": "step_assist"}
	var inf := {}
	if plan.info:
		inf = {"h": snappedf(plan.info.h, 0.01), "depth": snappedf(minf(plan.info.depth, 99.0), 0.01), "collider": str((plan.info.collider as Node).name) if plan.info.collider else ""}
	return {"result": "move:" + plan.move_id, "info": inf}


# --- copies of frontier_level.gd colliders ---------------------------------------------------

func _sb(name: String, pos: Vector3, shape: Shape3D, rot := Vector3.ZERO, kind := "") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	b.position = pos
	b.rotation = rot
	if kind != "":
		b.set_meta("review_kind", kind)
	level.add_child(b)
	return b


func _bx(name: String, pos: Vector3, size: Vector3, rot_y := 0.0, kind := "") -> StaticBody3D:
	var s := BoxShape3D.new()
	s.size = size
	return _sb(name, pos, s, Vector3(0, rot_y, 0), kind)


func _cy(name: String, pos: Vector3, r: float, h: float, kind := "") -> StaticBody3D:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	return _sb(name, pos, s, Vector3.ZERO, kind)


func _fort() -> void:
	var height := 4.2
	var r := 0.19
	var walls := [
		[Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, -FORT_HALF), true],
		[Vector3(-FORT_HALF, 0, FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF), false],
		[Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(-FORT_HALF, 0, FORT_HALF), false],
		[Vector3(FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF), false],
	]
	for wall in walls:
		var a: Vector3 = wall[0]
		var b: Vector3 = wall[1]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var rot := atan2(-dir.z, dir.x)
		if wall[2]:
			var seg := FORT_HALF - GATE_HALF
			_bx("palisade", Vector3(-FORT_HALF + seg * 0.5, height * 0.5, a.z), Vector3(seg, height, r * 2), 0.0, "palisade 4.2")
			_bx("palisade", Vector3(FORT_HALF - seg * 0.5, height * 0.5, a.z), Vector3(seg, height, r * 2), 0.0, "palisade 4.2")
		else:
			_bx("palisade", (a + b) * 0.5 + Vector3(0, height * 0.5, 0), Vector3(length, height, r * 2), rot, "palisade 4.2")
	for s: float in [-1.0, 1.0]:
		_cy("gatepost", Vector3(s * (GATE_HALF + 0.1), 2.6, -FORT_HALF), 0.28, 5.2, "gate post")
	_bx("lintel", Vector3(0, 5.0, -FORT_HALF), Vector3(GATE_HALF * 2 + 0.8, 0.4, 0.45), 0.0, "gate lintel 5.0")
	for s: float in [-1.0, 1.0]:
		var cx := s * (GATE_HALF + (FORT_HALF - GATE_HALF) * 0.5)
		_bx("walkway", Vector3(cx, 2.2, -FORT_HALF + 1.0), Vector3(FORT_HALF - GATE_HALF - 0.5, 0.15, 1.6), 0.0, "walkway 2.275")
		var ramp_x := FORT_HALF - 2.0 if s > 0.0 else -(FORT_HALF - 4.0)
		_ramp(ramp_x, -FORT_HALF + 6.9, -FORT_HALF + 1.9, 2.3)
	for corner in [Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF)]:
		_bx("blockhouse", corner + Vector3(0, 1.75, 0), Vector3(4.5, 3.5, 4.5), 0.0, "blockhouse 3.5")
		_bx("blockhouse_up", corner + Vector3(0, 4.6, 0), Vector3(5.5, 2.2, 5.5), 0.0, "blockhouse upper")
	_bx("cabin", Vector3(-8, 1.5, 7), Vector3(7, 3, 5), 0.0, "cabin 3.0 (roof visual, no collider)")
	_bx("chimney", Vector3(-4.43, 3.4, 8), Vector3(0.9, 1.6, 0.9), 0.0, "chimney 2.6-4.2")
	_bx("storehouse", Vector3(9, 1.2, 4), Vector3(5, 2.4, 4), 0.0, "storehouse 2.4 (roof visual)")
	var yaws := [0.21, -0.27, 0.12, 0.29, -0.14]
	var ps := [Vector3(5, 0.4, -6), Vector3(5.9, 0.4, -6.2), Vector3(5.4, 1.2, -6.1), Vector3(-10, 0.4, -4), Vector3(12, 0.4, -9)]
	for i in ps.size():
		_bx("crate", ps[i], Vector3(0.8, 0.8, 0.8), yaws[i], "crate 0.8" if i != 2 else "crate stacked top 1.6")
	for p: Vector3 in [Vector3(7, 0.5, -3), Vector3(7.7, 0.5, -3.4), Vector3(-5, 0.5, -10), Vector3(-5.8, 0.5, -10.3), Vector3(11, 0.5, 8)]:
		_cy("barrel", p, 0.32, 1.0, "barrel 1.0")
	_cy("flagpole", Vector3(-6, 5, -2), 0.07, 10.0, "flagpole")


func _ramp(x: float, z_bottom: float, z_top: float, top_y: float) -> void:
	var thickness := 0.15
	var run := z_bottom - z_top
	var angle := atan2(top_y, run)
	var length := Vector2(run, top_y).length()
	var normal := Vector3(0, cos(angle), sin(angle))
	var mid := Vector3(x, top_y * 0.5, (z_bottom + z_top) * 0.5)
	var s := BoxShape3D.new()
	s.size = Vector3(1.2, thickness, length)
	_sb("ramp", mid - normal * thickness * 0.5, s, Vector3(angle, 0, 0), "ramp 24.7 deg")


func _range() -> void:
	var z0 := -FORT_HALF - 4.0
	_bx("rail", Vector3(0, 0.55, z0), Vector3(8, 0.1, 0.12), 0.0, "firing rail 0.6")
	for x: float in [-4.0, 0.0, 4.0]:
		_bx("rail_post", Vector3(x, 0.3, z0), Vector3(0.12, 0.6, 0.12), 0.0, "rail post 0.6")
	var yaws := [0.3, -0.35, 0.1, -0.2]
	var ps := [Vector3(-5, 0.45, z0 - 15), Vector3(5, 0.45, z0 - 30), Vector3(-4.5, 0.45, z0 - 60), Vector3(4.5, 0.45, z0 - 85)]
	for i in ps.size():
		_bx("hay", ps[i], Vector3(1.6, 0.9, 0.9), yaws[i], "hay bale 0.9")
