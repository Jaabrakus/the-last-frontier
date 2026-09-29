extends SceneTree
## Windows cut in the built palisade with the felling axe (user 2026-09-26: "i also want to be able to ... create a window to
## shoot weapons"; since 2026-09-28 the fort's palisade is build-menu pieces and the windows are cut in pieces from belly
## height up, measured from where the player stands: PalisadeCuts), on the real level with the real player:
##   * without the axe in the hand the wall is no target; with it, the camera aimed at the wall: the target is a piece of it
##     ("Chop through the palisade"); held strokes cut it out
##   * from the ground the piece starts at the feet's height + 1.0 m (belly), is 1.0 m tall and two stakes wide; a ray through
##     it passes the wall, rays under it (no hole down to the ground), beside it and over it are stopped; the body does not
##     walk through it at chest height
##   * each further cut takes the next piece up; the third takes the top off; the pieces join into one opening
##   * on the firing step (deck top 2.275 m) the first cut takes everything from belly height to the top in one go: a shot over
##     the deck passes the notch, the wall under it stops one
##   * halfway up the ramp the piece rises with the feet
##
##   Godot --headless --fixed-fps 120 --path . -s tests/gathering/test_wall_window.gd
## "WALL WINDOW TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0
var p: FrontierPlayer
var world: BuildWorld


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _ray_hits_wall(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [p.get_rid()]
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	return not h.is_empty() and PalisadeCuts.section_of(h.collider) != null


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
	world = BuildWorld.of(self, false)
	var n_pal := 0
	if world:
		for q in world.pieces():
			if q.type == "palisade":
				n_pal += 1
	_check(world != null and world.fort_built and n_pal == 39, "the fort's palisade is 39 built sections (%d)" % n_pal)
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
	var tgt: Dictionary = g.target.duplicate()
	var sec := world.by_id(int(tgt.get("piece", -1)))
	_check(sec != null and sec.type == "palisade", "the target is a piece of a built palisade section")
	if sec == null:
		_finish()
		return
	var base_y := sec.global_position.y
	_check(absf(float(tgt.h0) - (p.global_position.y + PalisadeCuts.BELLY - base_y)) < 0.05 and absf(float(tgt.h1) - float(tgt.h0) - 1.0) < 0.05,
			"from the ground it starts at belly height (%.2f m over the feet) and is 1.0 m tall (%.2f - %.2f)" % [PalisadeCuts.BELLY, float(tgt.h0), float(tgt.h1)])
	Input.action_press("fire")
	t = 0.0
	while t < 40.0 and sec.cuts.is_empty():
		await physics_frame
		t += 1.0 / 120.0
	Input.action_release("fire")
	await _ticks(60)
	_check(sec.cuts.size() >= 1, "held strokes cut the piece out (%.1f s)" % t)
	if sec.cuts.is_empty():
		_finish()
		return
	var c: Array = sec.cuts[0]
	var k := int(c[0])
	var xr := PalisadeCuts.x_range(k)
	var h0 := float(c[1])
	var h1 := float(c[2])
	var loc := func(x: float, y: float) -> Vector3:
		return sec.global_transform * Vector3(x, y, 0.0)
	var across := func(x: float, y: float) -> bool:
		var q: Vector3 = loc.call(x, y)
		var nrm := sec.global_transform.basis.z
		return _ray_hits_wall(q + nrm, q - nrm)
	var xm := 0.5 * (xr.x + xr.y)
	_check(not across.call(xm, 0.5 * (h0 + h1)), "a ray through the opening passes the wall")
	_check(across.call(xm, h0 - 0.4) and across.call(xm, h1 + 0.2) and across.call(xr.x - 0.3, 0.5 * (h0 + h1)) and across.call(xr.y + 0.3, 0.5 * (h0 + h1)),
			"under (no hole down to the ground), over and beside the opening the wall still stops it")
	_check(across.call(xm, 0.3) and across.call(xm, h0 - 0.05), "the foot of the wall under belly height stands")
	Input.action_press("move_forward")
	await _ticks(150)
	Input.action_release("move_forward")
	_check(p.global_position.x < 15.9, "the body does not walk through an opening at chest height (x %.2f)" % p.global_position.x)

	# the next pieces up (synthetic aims at the same stakes)
	var into := -sec.global_transform.basis.z          # from the wall toward the fort
	var at_wall: Vector3 = loc.call(xm, 0.0)
	var aim_at := func(y: float) -> Dictionary:
		var eye: Vector3 = Vector3(at_wall.x, y, at_wall.z) + into * 1.2
		return PalisadeCuts.aim(world, eye, -into, Vector3(eye.x, 0.02, eye.z) + into * 0.0, [p.get_rid()])
	var c2: Dictionary = aim_at.call(h1 + 0.4)
	_check(not c2.is_empty() and absf(float(c2.h0) - h1) < 0.02, "the next piece is the next one up (%s)" % str(c2.get("h0", "-")))
	if not c2.is_empty():
		PalisadeCuts.cut(world, sec.piece_id, int(c2.k), float(c2.h0), float(c2.h1))
		await _ticks(4)
	var c3: Dictionary = aim_at.call(3.2)
	_check(not c3.is_empty() and float(c3.h1) > PalisadeCuts.TOP + 0.3, "then the top comes off, points and all (%s)" % str(c3.get("h1", "-")))
	if not c3.is_empty():
		PalisadeCuts.cut(world, sec.piece_id, int(c3.k), float(c3.h0), float(c3.h1))
		await _ticks(4)
	var open := PalisadeCuts.removed(sec.cuts, k, false)
	_check(open.size() == 1 and absf(float(open[0][0]) - h0) < 0.02, "the pieces join into one opening from belly height up (%s)" % str(open))
	g.put_away()
	await _ticks(10)

	# on the walkway: the wall over the boards (the north wall, z = -16; the firing step's deck is 2.275 m over the ground)
	await _place(Vector3(9.0, 2.3, -14.9), 0.0)
	var deck_feet := Vector3(9.0, p.global_position.y, -14.9)
	var over := PalisadeCuts.aim(world, Vector3(9.0, deck_feet.y + 1.6, -14.9), Vector3(0, 0, -1), deck_feet, [p.get_rid()])
	_check(not over.is_empty(), "on the walkway the wall over the boards can be cut")
	if not over.is_empty():
		var osec := world.by_id(int(over.piece))
		_check(absf(float(over.h0) - (deck_feet.y + 1.0 - osec.global_position.y)) < 0.02 and float(over.h1) > PalisadeCuts.TOP + 0.3,
				"from the deck the piece takes everything from belly height (%.2f) to the top in one go (%.2f)" % [float(over.h0), float(over.h1)])
		PalisadeCuts.cut(world, osec.piece_id, int(over.k), float(over.h0), float(over.h1))
		await _ticks(4)
		var xo := 0.5 * (PalisadeCuts.x_range(int(over.k)).x + PalisadeCuts.x_range(int(over.k)).y)
		var oc: Vector3 = osec.global_transform * Vector3(xo, 0.0, 0.0)
		_check(not _ray_hits_wall(Vector3(oc.x, deck_feet.y + 1.4, oc.z + 1.0), Vector3(oc.x, deck_feet.y + 1.4, oc.z - 1.0))
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
