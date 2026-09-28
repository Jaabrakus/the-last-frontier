extends SceneTree
## Motion choice and timing (user fix 2026-09-24, "motion looks wrong"):
##   1 selection  the clip authored for the obstacle's height, depth and entry speed is picked,
##                and obstacles no clip was made for are rejected (never forced): boxes of every
##                authored height +- a few cm, thin and deep, sprinting / walking / standing
##   2 timing     every plan plays at rate 1.0 (the clip's own timing); a move's path duration is
##                the sum of its clip lengths
##   3 travel     the reconstructed pelvis travel of every part equals the survey's (no double
##                travel: the align already excludes the hips' own skeleton-space travel; parts
##                re-derived by a hero annotation, align_zero_parts / align_anchor_parts, are
##                skipped), and
##                the four clips that move their hips in skeleton space are either unused or pass
##   4 source     every move plays Actor_B clips only (source: actor_b) and none of the removed
##                free-climbing moves is in the table
##
##   Godot --headless --path . -s tests/traversal/test_traversal_selection.gd

const HIP_MOVERS := ["actor_b-ambi-run^vault-over-down-exit", "actor_b-p-death-ladder", "actor_b-p-vault-end^sprint",
		"hun4-hotel-vator-boost-n-fall--actor_b"]
const REMOVED := ["jump_hang", "hang_hub_free", "hang_climb_up", "hang_climb_up_idle", "drop_to_hang", "fall_grab"]

var failures := 0
var checks := 0
var lib: TravMoveLibrary


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])


func _initialize() -> void:
	await process_frame
	lib = TravMoveLibrary.shared()
	var world := Node3D.new()
	root.add_child(world)
	var ground := _box(world, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	var runner := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	runner.add_child(cs)
	world.add_child(runner)
	await physics_frame
	var probe := TraversalProbe.new(world.get_world_3d().direct_space_state, TravShapeRegistry.new(), TravLedgeGraph.new(),
			lib.settings, [runner.get_rid()] as Array[RID])
	var sel := TravMoveSelector.new(lib, probe)
	print("1 selection (authored height +- tolerance, depth, entry speed)")
	# [name, height, depth (INF = deep), speed, profile, expect (move id or "none:<reason>")]
	var cases := [
		["sprint thin 0.95", 0.95, 0.3, 5.0, "freerun", "vault_sprint"],
		["sprint thin 0.99", 0.99, 0.3, 5.0, "freerun", "vault_sprint"],
		# The sprint vault's band ends 5 cm above its authored 0.95 m (user decision 2026-09-24:
		# its hand popped 8-13 cm at the plant higher up): a 1.05 m wall gets no move.
		["sprint thin 1.05 (above the band)", 1.05, 0.3, 5.0, "freerun", "none"],
		["sprint thin 0.84", 0.84, 0.3, 5.0, "freerun", "vault_sprint"],
		["walk thin 0.75 + Space", 0.75, 0.3, 1.6, "careful", "vault_idle"],
		["walk thin 0.65 + Space", 0.65, 0.3, 1.6, "careful", "vault_idle"],
		["sprint thin 1.25 (no clip)", 1.25, 0.3, 5.0, "freerun", "none"],
		["standing thin 1.58 + Space", 1.58, 0.35, 0.0, "careful", "vault_tall_fall"],
		["standing thin 1.95 (too high)", 1.95, 0.35, 0.0, "careful", "none"],
		["standing deep 0.5 + Space", 0.5, INF, 0.0, "careful", "step_on"],
		["sprint deep 0.79", 0.79, INF, 5.0, "freerun", "mantle_1m_run"],
		["standing deep 0.98 + Space", 0.98, INF, 0.0, "careful", "mantle_1m_idle"],
		# Only a standing move is made for this height: planned from rest, the approach brings the
		# body to a stop at its start (TravMovePlan.approach_stop, seam fix 2026-09-24).
		["sprint deep 1.0 (made for standing)", 1.0, INF, 5.0, "freerun", "mantle_1m_idle"],
		["sprint deep 1.34", 1.34, INF, 5.0, "freerun", "mantle_1_5m"],
		["sprint deep 2.0", 2.0, INF, 5.0, "freerun", "climb_chest"],
		["sprint deep 2.5 (no clip)", 2.5, INF, 5.0, "freerun", "none"],
		["sprint deep 3.0", 3.0, INF, 5.0, "freerun", "climb_hang_3m"],
		["standing deep 3.0 + Space", 3.0, INF, 0.0, "careful", "climb_hang_3m_idle"],
		["sprint deep 3.5 (too high)", 3.5, INF, 5.0, "freerun", "none"],
	]
	for c: Array in cases:
		var h: float = c[1]
		var depth: float = c[2]
		var d := 4.0 if depth == INF else depth
		var ob := _box(world, Vector3(0, h * 0.5, -3.0 - d * 0.5), Vector3(3.0, h, d))
		await physics_frame
		await physics_frame
		var speed: float = c[3]
		var feet := Vector3(0, 0, -3.0 + 0.35 + speed * 0.3)
		var ctx := {"feet": feet, "heading": Vector3(0, 0, -1), "speed": speed,
				"gait": "sprint" if speed > 4.0 else ("walk" if speed > 0.3 else "idle"), "stance": "stand",
				"profile": c[4], "trigger": true, "alt": false, "want_climb": true}
		var info := probe.probe_ahead(feet, Vector3(0, 0, -1), speed, str(c[4]) == "careful")
		var plan := sel.select(info, ctx)
		var got := plan.move_id if plan.ok() else "none:" + plan.reason
		var want: String = c[5]
		var ok := got == want or (want == "none" and got.begins_with("none"))
		_check(ok, "%-38s h %.2f -> %s%s" % [c[0], h, got, "" if ok else "  (want %s)" % want])
		if plan.ok():
			_check(is_equal_approx(plan.rate, 1.0), "%-38s plays at rate 1.0" % c[0])
		ob.free()
		await physics_frame
	print("2 timing (clip lengths, rate)")
	for id: String in lib.moves:
		var m: Dictionary = lib.moves[id]
		var sum := 0.0
		for p: Dictionary in m.parts:
			sum += float(p.length)
		_check(absf(sum - float(m.duration)) < 1e-4, "%-22s duration %.3f = sum of its clips %.3f" % [id, float(m.duration), sum])
	print("3 travel (no double travel)")
	var geom: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/traversal/clip_geometry.json"))
	var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/traversal/clip_geometry_extra.json"))
	if extra is Dictionary:
		geom.clips.merge(extra.clips)
	var used_movers := []
	for id: String in lib.moves:
		var m: Dictionary = lib.moves[id]
		var tr: Dictionary = m.track
		var hz := float(tr.hz)
		var n := int(tr.n)
		for p: Dictionary in m.parts:
			if HIP_MOVERS.has(str(p.clip)):
				used_movers.append("%s/%s" % [id, p.clip])
			# Parts whose align was re-derived by a hero annotation (zero align, a planted limb
			# carrying it: the survey's odometry was wrong there) are not compared to the survey.
			if str(p.get("align", "survey")) == "zero" or bool(p.get("reverse", false)) or p.has("align_anchor"):
				continue
			var gc: Dictionary = geom.clips.get(str(p.clip), {})
			if not gc.has("travel"):
				continue
			var i0 := clampi(int(round(float(p.t0) * hz)), 0, n - 1)
			var i1 := clampi(int(round((float(p.t0) + float(p.length)) * hz)), 0, n - 1)
			var a := Vector3(float(tr.pelvis[3 * i0]), 0, float(tr.pelvis[3 * i0 + 2]))
			var b := Vector3(float(tr.pelvis[3 * i1]), 0, float(tr.pelvis[3 * i1 + 2]))
			var got := a.distance_to(b)
			var tv: Dictionary = gc.travel
			var want := Vector2(float(tv.get("fwd", 0.0)), float(tv.get("side", 0.0))).length()
			_check(absf(got - want) <= 0.12, "%-22s %-44s pelvis travel %.2f m, survey %.2f m" % [id, str(p.clip).trim_prefix("actor_b-").left(44), got, want])
	_check(used_movers.is_empty(), "the four hip-moving clips are not played by any move %s" % [used_movers])
	# The solved path: the capsule travels with the pelvis (not pelvis + align twice).
	var m2 := lib.move("vault_sprint")
	var geo := {"start": Vector3.ZERO, "yaw": PI, "solve_start": false, "support_y": 0.0, "top_y": 0.95,
			"face_point": Vector3(0, 0.95, -0.85), "face_normal": Vector3(0, 0, 1), "depth": 0.3, "landing_y": 0.0}
	var path := TravMotionWarper.solve("vault_sprint", m2, geo)
	var cap_d := path.capsule_at(path.duration).distance_to(path.capsule_at(0.0))
	var pel_d := Vector2(path.point_at("pelvis", path.duration).x - path.point_at("pelvis", 0.0).x,
			path.point_at("pelvis", path.duration).z - path.point_at("pelvis", 0.0).z).length()
	_check(absf(cap_d - pel_d) < 0.1, "vault_sprint solved: capsule travel %.2f m = pelvis travel %.2f m" % [cap_d, pel_d])
	print("4 source clips only")
	for id: String in lib.moves:
		var m3: Dictionary = lib.moves[id]
		_check(str(m3.get("source", "")) == "actor_b", "%-22s source actor_b (%s)" % [id, ", ".join((m3.parts as Array).map(func(p): return str(p.clip).trim_prefix("actor_b-")))])
	for r: String in REMOVED:
		_check(not lib.moves.has(r), "free-climbing move %s is not in the table" % r)
	print("TRAVERSAL SELECTION %s (%d checks, %d failure(s))" % ["OK" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


func _box(parent: Node, center: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = center
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	return b
