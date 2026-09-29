extends SceneTree
## The fort's ladders up to the firing step (user 2026-09-26: "add the climbing and ladders in the game"; since 2026-09-28
## the ladder build pieces FortPlan stamps at x = +-6, z = -13.95), on the real level with the real player: both ladders
## are baked as climbing lanes; walking into a ladder mounts it, holding
## forward climbs it and steps off onto the walkway's boards; holding back climbs down and steps off onto the ground.
##
##   Godot --headless --fixed-fps 120 --path . -s tests/traversal/test_fort_ladders.gd
## "FORT LADDERS TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0
var p: FrontierPlayer
const LADDER_X := [6.0, -6.0]          ## the ladder pieces' x (data/building/fort_structure.json)
const LADDER_Z := -13.95               ## their z: 25 cm in front of the firing step's open edge (z -14.2)
const WALK_TOP := FortPieces.WALK_TOP
const WALK_EDGE_Z := -14.2


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _release() -> void:
	for a in ["move_forward", "move_back", "jump", "sprint"]:
		Input.action_release(a)


## From 2 m in front of the ladder at x, walking into it: forward to the top, or (down) back from the upper hub.
func _climb(x: float, down: bool, secs: float) -> Dictionary:
	_release()
	p.global_position = Vector3(x, 0.02, LADDER_Z + 2.0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.traversal.controller.teleported()
	for i in 60:
		await physics_frame
	Input.action_press("move_forward")
	var moves := []
	var modes := {}
	var back := false
	var t := 0.0
	var c: TraversalController = p.traversal.controller
	while t < secs:
		await physics_frame
		t += 1.0 / 120.0
		modes[c.mode_name()] = true
		var mv := str(c.anim_state().get("move", ""))
		if mv != "" and (moves.is_empty() or moves[moves.size() - 1] != mv):
			moves.append(mv)
		if down and not back and c.mode_name() == "CLIMB" and c.lane.u > 0.8 and c.lane.cycle == "":
			Input.action_release("move_forward")
			Input.action_press("move_back")
			back = true
	_release()
	for i in 30:
		await physics_frame
	return {"moves": moves, "modes": modes, "end": p.global_position, "floor": p.is_on_floor()}


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 3:
		await process_frame
	for i in 120:
		await physics_frame
	p = current_scene.get_node("Player")
	p.set("ignore_mouse_capture", true)
	while p.traversal == null or not p.traversal.world_ready:
		await physics_frame
	var lanes: Array = p.traversal.controller.ledges.lanes.values()
	_check(lanes.size() == LADDER_X.size(), "both ladders are climbing lanes (%d)" % lanes.size())
	for x: float in LADDER_X:
		var r := await _climb(x, false, 9.0)
		var e: Vector3 = r.end
		_check("ladder_mount_bottom" in r.moves and "ladder_dismount_top" in r.moves and (r.modes as Dictionary).has("CLIMB"),
				"x %.1f up: mount, climb, top dismount (%s)" % [x, str(r.moves)])
		_check(absf(e.y - WALK_TOP) < 0.03 and bool(r.floor) and e.z < WALK_EDGE_Z - 0.1,
				"x %.1f up: on the walkway's boards after it (%s, floor %s)" % [x, str(e.snapped(Vector3.ONE * 0.01)), r.floor])
	var d := await _climb(LADDER_X[0], true, 10.0)
	var de: Vector3 = d.end
	_check("ladder_dismount_bottom" in d.moves and not ("ladder_dismount_top" in d.moves),
			"down: climbs back down and steps off at the bottom (%s)" % str(d.moves))
	_check(absf(de.y) < 0.05 and bool(d.floor), "down: on the ground after it (%s)" % str(de.snapped(Vector3.ONE * 0.01)))
	if _fails.is_empty():
		print("FORT LADDERS TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("FORT LADDERS TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
