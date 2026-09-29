extends SceneTree
## The fort's gate (since 2026-09-28 the palisade_gate build piece FortPlan stamps in the north wall; its two plank leaves are a
## BuildDoor) on the real level with the real player: it stands open at the start (the way out to the range is clear); E ("Shut
## the gate") shuts it and the body cannot walk out; the felling axe in the hand finds nothing to chop in the gate's leaves (the
## old gate windows, FortGate + WallCuts, are gone: windows are cut in the palisade sections only, PalisadeCuts); E opens the
## gate again.
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
	var world := BuildWorld.of(self, false)
	var gate: BuiltPiece = null
	for q in (world.pieces() if world else []):
		if q.type == "palisade_gate":
			gate = q
	_check(gate != null and gate.door != null, "the fort's gate is a built palisade gate with its leaves")
	if gate == null or gate.door == null:
		quit(1)
		return
	var door := gate.door
	var z := gate.global_position.z
	_check(door.is_open and not _hit_leaf(Vector3(0, 1.0, z - 2.0), Vector3(0, 1.0, z + 2.0)), "open at the start: the way through is clear")

	# (clear of the leaves' swing: a closing leaf pushes a body in its way)
	await _place(Vector3(0.6, 0.02, z + 3.2), 0.0)
	_check(door.interact_prompt(p) == "Shut the gate", "E at the gate: \"%s\"" % door.interact_prompt(p))
	door.interact(p)
	await _ticks(int(120.0 / BuildDoor.SWING_RATE) + 40)
	_check(not door.is_open and _hit_leaf(Vector3(0.6, 1.0, z - 2.0), Vector3(0.6, 1.0, z + 2.0)), "shut: the leaves fill the gateway")
	Input.action_press("move_forward")
	await _ticks(180)
	Input.action_release("move_forward")
	_check(p.global_position.z > z - 0.05, "the body cannot walk out through the shut gate (z %.2f)" % p.global_position.z)

	# the axe at the shut leaf: nothing to chop (the gate is not cut), and no wall target either
	await _place(Vector3(0.6, 0.02, z + 1.0), 0.0)
	var g: GatherTools = p.gather
	g.take_out("felling_axe")
	var t := 0.0
	while t < 3.0 and g.in_hand() != "felling_axe":
		await physics_frame
		t += 1.0 / 120.0
	await _ticks(20)
	_check(str(g.target.get("type", "")) != "wall", "with the axe in the hand the gate's leaf is no chopping target (%s)" % str(g.target.get("type", "")))
	g.put_away()
	await _ticks(60)
	door.interact(p)
	await _ticks(int(120.0 / BuildDoor.SWING_RATE) + 40)
	_check(door.is_open and not _hit_leaf(Vector3(0, 1.0, z - 2.0), Vector3(0, 1.0, z + 2.0)), "open again: the way through is clear")

	if _fails.is_empty():
		print("GATE WINDOW TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("GATE WINDOW TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
