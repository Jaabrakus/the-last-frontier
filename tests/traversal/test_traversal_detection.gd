extends SceneTree
## Detection on level-like geometry (adversarial review 2026-09-24). The runner walks up to each
## obstacle in 0.1 m steps (as the free-run does, one probe per step) and the controller's
## can_traverse() must give the move authored for it, or reject it:
##   slopes        a wall on an 8 deg upslope and a block at the foot of a downslope are judged by
##                 their own height (above the foot of their face), and the plan appears early
##                 enough to slow to the clip's entry speed (the sprint vault was planned only
##                 1.0 m from the face on the upslope, entered at 4.9 m/s instead of 2.4)
##   rotated props a 0.8 m crate and a hay bale turned 17 deg (the fort's crates): at a sprint both are vaulted at
##                 speed (the sprint vault takes tops up to 1.0 m deep since 2026-09-27; the bale was climbed by the
##                 standing mantle from rest before), walking up with Space the crate is mantled
##                 (the capsule met their corner and the support area failed there)
##   trees         a vegetation trunk collider (group "trees", flat cap 3.0 m up inside the crown)
##                 is never climbed (the 3 m climb used to take it)
##   rejections    tops too narrow to stand on, heights between the authored bands, careful
##                 running without Space
##
##   Godot --headless --path . -s tests/traversal/test_traversal_detection.gd

var failures := 0
var checks := 0
var world: Node3D
var runner: CharacterBody3D
var ctrl: TraversalController


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])


func _initialize() -> void:
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	var ground := _box(world, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	runner = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	runner.add_child(cs)
	world.add_child(runner)
	ctrl = TraversalController.new()
	runner.add_child(ctrl)
	var registry := TravShapeRegistry.new()
	registry.register(ground.get_child(0), {"kind": "terrain", "overlap": "never"})
	ctrl.setup(runner, {"registry": registry, "ledges": TravLedgeGraph.new()})
	await physics_frame
	var a := deg_to_rad(8.0)
	# [name, builder (Callable(o: Vector3) -> void, obstacle face at o.z, runner comes from +Z),
	#  gait (sprint / walk / run), expect (move ids, or [] = none), min plan distance from the face]
	var cases := [
		["0.95 wall on an 8 deg upslope, sprint", func(o: Vector3) -> void:
			var z0 := o.z + 7.0
			var L := 12.0
			var zc := z0 - L * 0.5
			var sl := _box(world, Vector3(o.x, (z0 - zc) * tan(a) - 0.2 / cos(a), zc), Vector3(4, 0.4, L / cos(a)))
			sl.rotation.x = a
			var yf := (z0 - (o.z + 0.15)) * tan(a)
			_box(world, Vector3(o.x, yf + 0.95 * 0.5 - 0.15, o.z), Vector3(2.4, 1.25, 0.3)),
			"sprint", ["vault_sprint"], 2.0],
		["0.80 block at the foot of an 8 deg downslope, sprint", func(o: Vector3) -> void:
			var zs0 := o.z + 0.5 + 1.0 / tan(a)
			_box(world, Vector3(o.x, 0.5, zs0 + 2.0), Vector3(4, 1, 4))
			var Ld := zs0 - (o.z + 0.5)
			var sd := _box(world, Vector3(o.x, 0.5 - 0.2 / cos(a), zs0 - Ld * 0.5), Vector3(4, 0.4, Ld / cos(a)))
			sd.rotation.x = -a
			# (0.80 m: the running knee mantle's band ends 5 cm above its authored 0.79 m since
			# 2026-09-24; the case checks the slope, which read 0.85 m as step_on before the review.)
			_box(world, Vector3(o.x, 0.40, o.z - 1.25), Vector3(3, 0.80, 2.5)),
			"sprint", ["mantle_1m_run"], 0.0],
		["0.95 wall on flat ground, sprint (reference)", func(o: Vector3) -> void:
			_box(world, Vector3(o.x, 0.475, o.z), Vector3(2.4, 0.95, 0.3)),
			"sprint", ["vault_sprint"], 2.0],
		["0.8 crate turned 17 deg, sprint", func(o: Vector3) -> void:
			var b := _box(world, Vector3(o.x, 0.4, o.z - 0.4), Vector3(0.8, 0.8, 0.8))
			b.rotation.y = 0.3,
			"sprint", ["vault_sprint"], 0.0],
		["0.8 crate turned 17 deg, walk + Space", func(o: Vector3) -> void:
			var b := _box(world, Vector3(o.x, 0.4, o.z - 0.4), Vector3(0.8, 0.8, 0.8))
			b.rotation.y = -0.3,
			"walk", ["mantle_1m_run"], 0.0],
		# (0.9 m is above the running knee mantle's band since 2026-09-24: the standing mantle brought the body
		# to rest and climbed it; since 2026-09-27 the sprint vault takes it at speed, user: "when im going to a
		# haybarell the char slows down to climb and is locked in the animation".)
		["0.9 hay bale 1.6 x 0.9 turned 17 deg, sprint", func(o: Vector3) -> void:
			var b := _box(world, Vector3(o.x, 0.45, o.z - 0.45), Vector3(1.6, 0.9, 0.9))
			b.rotation.y = 0.3,
			"sprint", ["vault_sprint"], 0.0],
		["trunk collider (group trees) r 0.4, cap 3.0 m, sprint", func(o: Vector3) -> void:
			var t := _cyl(world, Vector3(o.x, 1.35, o.z - 0.4), 0.4, 3.3)
			t.add_to_group("trees"),
			"sprint", [], 0.0],
		["trunk collider (group trees) r 0.3, cap 3.0 m, walk + Space", func(o: Vector3) -> void:
			var t := _cyl(world, Vector3(o.x, 1.35, o.z - 0.3), 0.3, 3.3)
			t.add_to_group("trees"),
			"walk", [], 0.0],
		["0.6 rail open below (firing line), sprint", func(o: Vector3) -> void:
			_box(world, Vector3(o.x, 0.55, o.z), Vector3(3.4, 0.1, 0.12))
			for px in [-1.6, 1.6]:
				_box(world, Vector3(o.x + px, 0.3, o.z), Vector3(0.12, 0.6, 0.12)),
			"sprint", ["vault_idle", "step_over"], 0.0],
		["0.95 wall met 30 deg off its normal, sprint", func(o: Vector3) -> void:
			_box(world, Vector3(o.x, 0.475, o.z), Vector3(6.0, 0.95, 0.3)),
			"sprint30", ["vault_sprint"], 0.0],
		["1.34 wall with a 0.35 top (no clip), sprint", func(o: Vector3) -> void:
			_box(world, Vector3(o.x, 0.67, o.z), Vector3(2.4, 1.34, 0.35)),
			"sprint", [], 0.0],
		["2.0 block with a 0.5 top (no room to stand), sprint", func(o: Vector3) -> void:
			_box(world, Vector3(o.x, 1.0, o.z - 0.25), Vector3(3, 2.0, 0.5)),
			"sprint", [], 0.0],
		["1.10 deep block (between the knee bands), sprint", func(o: Vector3) -> void:
			_box(world, Vector3(o.x, 0.55, o.z - 1.25), Vector3(3, 1.1, 2.5)),
			"sprint", [], 0.0],
		["1.0 wall, running without Shift or Space", func(o: Vector3) -> void:
			_box(world, Vector3(o.x, 0.5, o.z), Vector3(2.4, 1.0, 0.3)),
			"run", [], 0.0],
	]
	var k := 0
	for c: Array in cases:
		var o := Vector3(-60.0 + 9.0 * k, 0, 0)
		k += 1
		var before := world.get_child_count()
		(c[1] as Callable).call(o)
		await physics_frame
		await physics_frame
		var r := _approach(o, str(c[2]))
		var want: Array = c[3]
		var got := str(r.move)
		var ok := (want.is_empty() and got == "") or want.has(got)
		_check(ok, "%-58s -> %s%s" % [c[0], got if got != "" else "none (%s)" % r.why, "" if ok else "  (want %s)" % (want if not want.is_empty() else "none")])
		if float(c[4]) > 0.0 and got != "":
			_check(float(r.dist) >= float(c[4]), "%-58s    planned %.2f m before the face (>= %.1f m to slow to the entry speed)" % [c[0], float(r.dist), float(c[4])])
		while world.get_child_count() > before:
			var n := world.get_child(world.get_child_count() - 1)
			world.remove_child(n)
			n.free()
		await physics_frame
	print("TRAVERSAL DETECTION %s (%d checks, %d failure(s))" % ["OK" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


## Walks up to the obstacle whose face is at o.z (from o.z + 7) in 0.1 m steps until the capsule
## would touch it; the first plan, or the last none reason.
func _approach(o: Vector3, gait: String) -> Dictionary:
	var ang := deg_to_rad(30.0) if gait == "sprint30" else 0.0
	var hd := Vector3(-sin(ang), 0, -cos(ang))
	var speed: float = {"sprint": 5.6, "sprint30": 5.6, "run": 3.6, "walk": 1.6}[gait]
	var space := world.get_world_3d().direct_space_state
	var why := ""
	var d := 7.0
	while d > 0.0:
		var p := Vector3(o.x, 0, o.z) - hd * d
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p - Vector3.UP * 4.0, 1, [runner.get_rid()])
		var h := space.intersect_ray(q)
		if not h.is_empty():
			p.y = (h.position as Vector3).y
		var sq := PhysicsShapeQueryParameters3D.new()
		var sh := CapsuleShape3D.new()
		sh.radius = 0.3
		sh.height = 1.4
		sq.shape = sh
		sq.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.85)
		sq.exclude = [runner.get_rid()]
		if not space.intersect_shape(sq, 1).is_empty():
			break
		runner.global_position = p
		runner.velocity = hd * speed
		var inp := {"move": Vector2(0, -1), "sprint": gait.begins_with("sprint"), "walk": gait == "walk", "yaw": atan2(-hd.x, -hd.z)}
		ctrl._jump_buffer = 0.15 if gait == "walk" else 0.0
		var plan := ctrl.can_traverse(ctrl.context(inp))
		if plan != null and plan.kind != "step_assist" and plan.move_id != "":
			var face_d := d
			if plan.info != null and plan.info.kind == "wall":
				face_d = Vector3(plan.info.face_point.x - p.x, 0, plan.info.face_point.z - p.z).dot(-plan.info.normal)
			return {"move": plan.move_id, "dist": face_d, "why": ""}
		why = ctrl.last_none
		d -= 0.1
	return {"move": "", "dist": 0.0, "why": why}


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


func _cyl(parent: Node, center: Vector3, r: float, h: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = center
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	return b
