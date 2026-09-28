extends SceneTree
## The fort's gate leaves (user 2026-09-26: "i also want to be able to gate to be chopable where we can use the axe so
## it allows us to create a window to shoot weapons"; asked where: "Both"), on the real level with the real player:
## the gate stands open at the start (the way out is clear); E ("Close the gate") closes it and the body cannot walk
## out; with the felling axe in the hand the gate is no E target but its leaf is a firing window target; held strokes
## cut the window, a ray through it passes the leaf while a ray beside it is stopped; the axe away, E opens the gate
## again and the leaf with its window swings clear.
##
##   Godot --headless --fixed-fps 120 --path . -s tests/gathering/test_gate_window.gd
## "GATE WINDOW TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0
var p: FrontierPlayer


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _hit_leaf(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [p.get_rid()]
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	return not h.is_empty() and h.collider is AnimatableBody3D


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.yaw = yaw
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
	var gate := FortGate.find(self)
	var wc := WallCuts.find(self)
	_check(gate != null and gate.leaves.size() == 2, "the gate has two leaves")
	if gate == null:
		quit(1)
		return
	var z := gate.hinge_z
	_check(gate.open and not _hit_leaf(Vector3(0, 1.0, z - 2.0), Vector3(0, 1.0, z + 2.0)), "open at the start: the way through is clear")

	# (clear of the leaves' swing: a closing leaf pushes a body in its way)
	await _place(Vector3(0.8, 0.02, z + 3.2), 0.0)
	_check(gate.interact_prompt(p) == "Close the gate", "E at the gate: \"%s\"" % gate.interact_prompt(p))
	gate.interact(p)
	await _ticks(int(FortGate.SWING_S * 120.0) + 30)
	_check(gate.is_closed() and _hit_leaf(Vector3(0.8, 1.0, z - 2.0), Vector3(0.8, 1.0, z + 2.0)), "closed: the leaves fill the gateway")
	Input.action_press("move_forward")
	await _ticks(180)
	Input.action_release("move_forward")
	_check(p.global_position.z > z - 0.05, "the body cannot walk out through the closed gate (z %.2f)" % p.global_position.z)

	# the axe out at the closed leaf: a firing window target, the gate no E target
	await _place(Vector3(0.8, 0.02, z + 1.0), 0.0)
	var g: GatherTools = p.gather
	g.take_out("felling_axe")
	var t := 0.0
	while t < 3.0 and g.in_hand() != "felling_axe":
		await physics_frame
		t += 1.0 / 120.0
	await _ticks(20)
	_check(gate.interact_prompt(p) == "", "with the axe in the hand the gate is no E target")
	var leaf_walls := [int(gate.leaves[0].wall), int(gate.leaves[1].wall)]
	_check(str(g.target.get("type", "")) == "wall" and int(g.target.get("wall", -1)) in leaf_walls,
			"the target is a window through the leaf (%s, wall %s)" % [str(g.target.get("type", "")), str(g.target.get("wall", ""))])
	var n0 := wc.window_count()
	Input.action_press("fire")
	t = 0.0
	while t < 40.0 and wc.window_count() == n0:
		await physics_frame
		t += 1.0 / 120.0
	Input.action_release("fire")
	await _ticks(60)
	_check(wc.window_count() == n0 + 1, "held strokes cut the window (%.1f s)" % t)
	if wc.window_count() == n0 + 1:
		var win: Dictionary = wc.windows[wc.window_count() - 1]
		var fr := wc.frame(int(win.wall))
		var a: Vector3 = fr[0]
		var dir: Vector3 = fr[1]
		var nrm := dir.cross(Vector3.UP).normalized()
		var ym := 0.5 * (float(win.y0) + float(win.y1))
		var at := func(u: float, y: float) -> bool:
			var q := a + dir * u
			return _hit_leaf(Vector3(q.x, y, q.z) + nrm, Vector3(q.x, y, q.z) - nrm)
		var uc := 0.5 * (float(win.u0) + float(win.u1))
		_check(not at.call(uc, ym), "a ray through the window passes the leaf")
		_check(at.call(uc, ym + 0.6) and at.call(float(win.u1) + 0.3, ym), "over and beside the window the leaf stops it")
		# the axe away, E opens the gate: the leaf swings clear of the gateway
		g.put_away()
		await _ticks(120)
		_check(gate.interact_prompt(p) == "Open the gate", "the axe away, E at the gate: \"%s\"" % gate.interact_prompt(p))
		gate.interact(p)
		await _ticks(int(FortGate.SWING_S * 120.0) + 30)
		_check(gate.open and not _hit_leaf(Vector3(0.8, 1.0, z - 2.0), Vector3(0.8, 1.0, z + 2.0)), "open again: the way through is clear")
		var fr2 := wc.frame(int(win.wall))
		_check(absf((fr2[1] as Vector3).dot(dir)) < 0.1, "the window's leaf swung with it (its line turned %.0f deg)" % rad_to_deg(acos(clampf((fr2[1] as Vector3).dot(dir), -1.0, 1.0))))

	if _fails.is_empty():
		print("GATE WINDOW TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("GATE WINDOW TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
