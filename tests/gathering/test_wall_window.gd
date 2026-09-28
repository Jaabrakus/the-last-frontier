extends SceneTree
## Pieces chopped out of the palisade where the axe aims (user 2026-09-26: "i also want to be able to gate to be
## chopable where we can use the axe so it allows us to create a window to shoot weapons", then "i want a whole piece
## of the wall choped down where the user aims the axe"), on the real level with the real player:
##   * the palisade's colliders and logs are registered (WallCuts); without the axe in the hand the wall is no target
##   * the axe in the hand, the camera aimed at the wall: the target is the piece around the aim ("Chop through the
##     palisade"); held strokes cut it out; a ray through it passes the wall, rays beside and over it are stopped;
##     the body does not walk through a piece at eye height
##   * the aim decides the piece: aimed low it reaches the ground, at the top it takes the top off, points too
##   * pieces add up: the ones under it cut too, the opening reaches the ground and the body walks out through it
##   * on the walkway the wall over the boards can be cut too
##
##   Godot --headless --fixed-fps 120 --path . -s tests/gathering/test_wall_window.gd
## "WALL WINDOW TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0
var p: FrontierPlayer


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _ray_hits_wall(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [p.get_rid()]
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return false
	var n: Node = h.collider
	return n != null and str(n.get_path()).contains("Palisade")


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.yaw = yaw
	p.pitch = 0.0
	p.traversal.controller.teleported()
	await _ticks(30)


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 3:
		await process_frame
	await _ticks(120)
	p = current_scene.get_node("Player")
	p.set("ignore_mouse_capture", true)
	while p.traversal == null or not p.traversal.world_ready:
		await physics_frame
	var wc := WallCuts.find(self)
	var n_static := 0
	var n_logs := 0
	if wc:
		for wi in wc.walls.size():
			if not bool(wc.walls[wi].local):
				n_static += 1
				n_logs += (wc.logs[wi] as Array).size()
	_check(n_static == 5, "the palisade's 5 colliders are cut walls (%d)" % n_static)
	_check(n_logs > 300, "its logs are registered (%d)" % n_logs)
	var g: GatherTools = p.gather

	# the east wall (x = 16) from inside, facing it (yaw -PI/2 faces +X)
	await _place(Vector3(15.0, 0.02, 2.0), -PI * 0.5)
	await _ticks(10)
	_check(str(g.target.get("type", "")) != "wall", "no target on the wall without the axe in the hand (%s)" % str(g.target.get("type", "")))
	g.take_out("felling_axe")
	var t := 0.0
	while t < 3.0 and g.in_hand() != "felling_axe":
		await physics_frame
		t += 1.0 / 120.0
	await _ticks(20)
	_check(str(g.target.get("type", "")) == "wall", "the axe in the hand, aimed at the wall: the target is a piece of it (%s)" % str(g.target.get("type", "")))
	_check(g.prompt().begins_with("Chop through the palisade"), "the prompt says so (%s)" % g.prompt())
	var cam := p.get_viewport().get_camera_3d()
	var aq := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 5.0)
	aq.exclude = [p.get_rid()]
	var aim_hit := p.get_world_3d().direct_space_state.intersect_ray(aq)
	var aim_y := float((aim_hit.position as Vector3).y) if not aim_hit.is_empty() else -1.0
	Input.action_press("fire")
	t = 0.0
	while t < 40.0 and wc.window_count() == 0:
		await physics_frame
		t += 1.0 / 120.0
	Input.action_release("fire")
	await _ticks(60)
	_check(wc.window_count() == 1, "held strokes chop the piece out (%.1f s)" % t)
	if wc.window_count() == 0:
		_finish()
		return
	var win: Dictionary = wc.windows[0]
	var wi := int(win.wall)
	var w: Dictionary = wc.walls[wi]
	var nrm: Vector3 = (w.dir as Vector3).cross(Vector3.UP).normalized()
	var ym := 0.5 * (float(win.y0) + float(win.y1))
	var uc := 0.5 * (float(win.u0) + float(win.u1))
	var through := func(u: float, y: float) -> bool:
		var q := (w.a as Vector3) + (w.dir as Vector3) * u
		return _ray_hits_wall(Vector3(q.x, y, q.z) + nrm, Vector3(q.x, y, q.z) - nrm)
	_check(aim_y >= float(win.y0) - 0.05 and aim_y <= float(win.y1) + 0.05, "the piece is where the axe aimed (aim %.2f m, piece %.2f-%.2f m)" % [aim_y, float(win.y0), float(win.y1)])
	_check(not through.call(uc, ym), "a ray through the opening passes the wall")
	_check(through.call(uc, float(win.y1) + 0.3) and through.call(float(win.u0) - 0.25, ym) and through.call(float(win.u1) + 0.25, ym),
			"over and beside the opening the wall still stops it")
	var tk := str(p.gather.target.get("key", ""))
	_check(tk == "" or tk != str(win.get("key", "-")), "the piece cut is no target any more")
	Input.action_press("move_forward")
	await _ticks(150)
	Input.action_release("move_forward")
	_check(p.global_position.x < 15.9, "the body does not walk through an opening at eye height (x %.2f)" % p.global_position.x)

	# the aim decides the piece (synthetic aims from in front of the wall at the same logs)
	var face := (w.a as Vector3) + (w.dir as Vector3) * uc - nrm * 1.0
	var at := func(y: float) -> Dictionary:
		return wc.aim(Vector3(face.x, y, face.z), nrm, Vector3(face.x, 1.3, face.z), [p.get_rid()])
	var low := at.call(0.35) as Dictionary
	_check(not low.is_empty() and float(low.h0) == 0.0, "aimed low, the piece reaches the ground (%s)" % str(low.get("h0", "-")))
	var high := at.call(3.9) as Dictionary
	_check(not high.is_empty() and float(high.h1) > float(w.height) + 0.4, "aimed at the top, the piece takes the top off, points too (%s)" % str(high.get("h1", "-")))
	# pieces add up: under the eye-height piece down to the ground, then the body walks out through the opening
	var k := int(win.k)
	var y0 := float(win.y0)
	while y0 > 0.01:
		var h0 := maxf(0.0, y0 - WallCuts.CUT_H)
		wc.cut(wi, k, h0, y0)
		y0 = h0
	var open := wc.removed_at(wi, float(wc.logs[wi][k].u))
	_check(open.size() == 1 and float(open[0][0]) == 0.0 and float(open[0][1]) >= float(win.y1) - 0.001,
			"the pieces join into one opening from the ground up (%s)" % str(open))
	var q0 := (w.a as Vector3) + (w.dir as Vector3) * uc
	g.put_away()
	await _place(Vector3(q0.x, 0.02, q0.z) - nrm * 1.2, -PI * 0.5)
	Input.action_press("move_forward")
	await _ticks(240)
	Input.action_release("move_forward")
	_check(p.global_position.x > 16.3, "the body walks out through it (x %.2f)" % p.global_position.x)

	# on the walkway: the wall over the boards (the north wall, z = -16)
	await _place(Vector3(9.0, 2.3, -14.9), 0.0)
	var over := wc.aim(Vector3(9.0, 3.4, -14.9), Vector3(0, 0, -1), Vector3(9.0, 3.6, -14.9), [p.get_rid()])
	_check(not over.is_empty() and float(over.h0) > 2.3, "on the walkway the wall over the boards can be cut (%s)" % str(over.get("h0", "-")))
	if not over.is_empty():
		wc.cut(int(over.wall), int(over.k), float(over.h0), float(over.h1))
		await _ticks(4)
		var ow: Dictionary = wc.walls[int(over.wall)]
		var ou := 0.5 * (float(wc.logs[int(over.wall)][int(over.k)].u) + float(wc.logs[int(over.wall)][int(over.k) + 1].u))
		var oc := (ow.a as Vector3) + (ow.dir as Vector3) * ou
		_check(not _ray_hits_wall(Vector3(oc.x, 3.9, oc.z + 1.0), Vector3(oc.x, 3.9, oc.z - 1.0))
				and _ray_hits_wall(Vector3(oc.x, float(over.h0) - 0.2, oc.z + 1.0), Vector3(oc.x, float(over.h0) - 0.2, oc.z - 1.0)),
				"the notch in the top: a shot over the walkway passes it, the wall under it still stops one")
	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("WALL WINDOW TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("WALL WINDOW TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
