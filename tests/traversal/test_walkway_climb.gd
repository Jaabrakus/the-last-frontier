extends SceneTree
## Climbing onto the fort's walkway (user 2026-09-26: "make the ramp climbable and the ledge we stand on", "add the
## climb on the walkway dude", "as long as you dont lock movement when climb up something"): Space facing the firing
## step's edge (2.275 m, open ground under it) jumps up to the lip and climbs onto the boards (the hang climb, offered
## on overhead lips only), on the real level with the real player:
##   stand   Space standing 0.6 m from the edge: the standing climb, ending on the boards (on the floor, 20+ cm in)
##   walk    Space walking at the edge: the moving climb, ending on the boards
##   stick   the stick held through the climb: the move hands back once both feet are up (before its end) and the
##           body walks on along the boards
##   under   Space under the walkway facing the edge from below: no climb up through the boards
##   nospace walking up to the edge and under it without Space: no climb
##   post    Space at a walkway post: no climb (the post stands under the lip)
## and the rendered body (pelvis, knees, feet, head) never inside the boards and the rim beam under them, the soles
## never under the ground; the hang climb carries no wall band in the player's library (walls: the forearm went
## into them, READY_FOR_INTEGRATION.md).
##
##   Godot --headless --fixed-fps 120 --path . -s tests/traversal/test_walkway_climb.gd
## "WALKWAY CLIMB TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

const LIP_Z := -14.2                ## the east walkway's front edge (the firing step pieces, FortPieces: centred on z -15, 1.6 deep)
const DECK_TOP := 2.275
const DECK_BOT := 2.125
const RIM_BOT := 1.93               ## the rim beam under the boards' front (visual, FortPieces.RIM_BOTTOM)
const RIM_Z0 := -14.37
const INSIDE_TOL := 0.03
const BODY := ["pelvis", "spine_2", "head", "l_knee", "r_knee", "l_ankle", "r_ankle", "l_ball", "r_ball", "l_heel", "r_heel"]
const SOLES := ["l_ball", "r_ball", "l_heel", "r_heel"]

var _fails: Array[String] = []
var _checks := 0
var p: FrontierPlayer
var sk: Skeleton3D
var _bi := {}
var _bw := {}


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _pose() -> void:
	for b: String in _bi:
		_bw[b] = sk.global_transform * sk.get_bone_global_pose(int(_bi[b])).origin


func _release_all() -> void:
	for a in ["move_forward", "jump", "sprint", "walk"]:
		if InputMap.has_action(a):
			Input.action_release(a)


## Places the player (yaw 0 faces -Z, the palisade; PI faces the fort's inside), then runs `secs`: Space at
## `space_at` (or when the body is within `space_d` of the edge), the stick held from `hold_at` to the end.
func _run(pos: Vector3, yaw: float, secs: float, space_at := 0.1, hold_at := -1.0, space_d := -1.0) -> Dictionary:
	_release_all()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.yaw = yaw
	p.traversal.controller.teleported()
	for i in 90:
		await physics_frame
	var r := {"moves": {}, "deep": 0.0, "deep_at": "", "under": 0.0, "began": -1.0, "ended": -1.0, "max_y": -INF, "space": false}
	var t := 0.0
	var pressed := false
	while t < secs:
		if hold_at >= 0.0 and t >= hold_at and not Input.is_action_pressed("move_forward"):
			Input.action_press("move_forward")
		if not pressed and ((space_d < 0.0 and t >= space_at) or (space_d >= 0.0 and p.global_position.z <= LIP_Z + space_d)):
			Input.action_press("jump")
			pressed = true
			r.space = true
		elif pressed and Input.is_action_pressed("jump"):
			Input.action_release("jump")
		await physics_frame
		t += 1.0 / 120.0
		var st: Dictionary = p.traversal.controller.anim_state()
		var mv := str(st.get("move", ""))
		var showing: bool = p.traversal.showing
		if mv != "" and showing:
			(r.moves as Dictionary)[mv] = true
			if float(r.began) < 0.0:
				r.began = t
		if float(r.began) >= 0.0 and float(r.ended) < 0.0 and not showing:
			r.ended = t
		r.max_y = maxf(float(r.max_y), p.global_position.y)
		if showing:
			for b: String in BODY:
				if not _bw.has(b):
					continue
				var w: Vector3 = _bw[b]
				var in_deck := minf(minf(w.y - DECK_BOT, DECK_TOP - w.y), minf(LIP_Z - w.z, w.z + 15.8))
				var in_rim := minf(minf(w.y - RIM_BOT, DECK_BOT - w.y), minf(-14.21 - w.z, w.z - RIM_Z0))
				var d := maxf(in_deck, in_rim)
				if w.x > 3.25 and w.x < 15.75 and d > float(r.deep):
					r.deep = d
					r.deep_at = "%s %.2f s" % [b, t - float(r.began)]
				if b in SOLES and w.y < -0.02 - 0.0:
					r.under = maxf(float(r.under), -w.y)
	r["end"] = p.global_position
	r["floor"] = p.is_on_floor()
	_release_all()
	for i in 30:
		await physics_frame
	return r


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
	sk = p.skeleton
	for b: String in BODY:
		var i := sk.find_bone(b)
		if i >= 0:
			_bi[b] = i
	sk.skeleton_updated.connect(_pose)
	var lib: TravMoveLibrary = p.traversal.controller.lib
	for id in PlayerTraversal.OVERHEAD_ONLY_MOVES:
		_check(bool(lib.moves[id].get("enabled", true)) and not lib.moves[id].has("band") and lib.moves[id].has("overhead_band"),
				"%s: offered on overhead lips only (no wall band)" % id)

	var r := await _run(Vector3(8.0, 0.02, LIP_Z + 0.6), 0.0, 5.0)
	_check((r.moves as Dictionary).has("climb_hang_3m_idle"), "stand: the standing climb plays (%s)" % str((r.moves as Dictionary).keys()))
	_check(absf((r.end as Vector3).y - DECK_TOP) < 0.03 and bool(r.floor), "stand: on the boards after it (y %.3f, floor %s)" % [(r.end as Vector3).y, r.floor])
	_check((r.end as Vector3).z < LIP_Z - 0.15, "stand: 15+ cm in from the edge (%.2f m)" % [LIP_Z - (r.end as Vector3).z])
	_check(float(r.deep) <= INSIDE_TOL, "stand: the body stays out of the boards and the rim (%.3f m, %s)" % [float(r.deep), r.deep_at])
	_check(float(r.under) <= 0.02, "stand: the soles stay over the ground (%.3f m under)" % float(r.under))

	r = await _run(Vector3(8.0, 0.02, LIP_Z + 3.0), 0.0, 6.0, -1.0, 0.0, 0.7)
	_check((r.moves as Dictionary).has("climb_hang_3m"), "walk: the moving climb plays (%s)" % str((r.moves as Dictionary).keys()))
	_check(absf((r.end as Vector3).y - DECK_TOP) < 0.03 and bool(r.floor) and (r.end as Vector3).z < LIP_Z - 0.15,
			"walk: on the boards after it (%s, floor %s)" % [str((r.end as Vector3).snapped(Vector3.ONE * 0.01)), r.floor])
	_check(float(r.deep) <= INSIDE_TOL, "walk: the body stays out of the boards and the rim (%.3f m, %s)" % [float(r.deep), r.deep_at])

	r = await _run(Vector3(8.0, 0.02, LIP_Z + 0.6), 0.0, 5.0, 0.1, 1.0)
	var took := float(r.ended) - float(r.began)
	_check((r.moves as Dictionary).has("climb_hang_3m_idle") and float(r.ended) > 0.0 and took < 3.5,
			"stick: the climb hands back once the feet are up (%.2f s of 4.0)" % took)
	_check((r.end as Vector3).z < LIP_Z - 0.8 and absf((r.end as Vector3).y - DECK_TOP) < 0.03 and bool(r.floor),
			"stick: the body goes on along the boards (%s)" % str((r.end as Vector3).snapped(Vector3.ONE * 0.01)))

	r = await _run(Vector3(8.0, 0.02, -15.3), PI, 2.5)
	_check((r.moves as Dictionary).is_empty() and float(r.max_y) < 1.2, "under: no climb from under the boards (%s, top %.2f)" % [str((r.moves as Dictionary).keys()), float(r.max_y)])

	r = await _run(Vector3(8.0, 0.02, LIP_Z + 2.5), 0.0, 3.0, 99.0, 0.0)
	_check((r.moves as Dictionary).is_empty() and float(r.max_y) < 0.3, "nospace: walking up to it and under it climbs nothing (%s)" % str((r.moves as Dictionary).keys()))

	r = await _run(Vector3(9.0, 0.02, LIP_Z + 0.6), 0.0, 2.5)      # (a firing step's post stands at each section's middle: 3, 6, 9, 12)
	_check((r.moves as Dictionary).is_empty(), "post: no climb where a post stands under the lip (%s)" % str((r.moves as Dictionary).keys()))

	sk.skeleton_updated.disconnect(_pose)
	if _fails.is_empty():
		print("WALKWAY CLIMB TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("WALKWAY CLIMB TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
