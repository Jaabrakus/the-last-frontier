extends SceneTree
## Closing the openings chopped in the wall (user 2026-09-26: "each one hole we cut we need to either be able to build a
## doors there or cover it up with logs or repair it"), from build mode on the real level with the real player:
##   cover   horizontal logs across an opening close it (a ray through it is stopped, 1 log paid); chopping into the
##           cover knocks it out again
##   repair  the logs stand there again (the opening is gone, 2 logs paid)
##   door    an opening chopped from the ground up takes a door (3 logs): shut it stops the body, E opens it and the
##           body walks through; an opening that does not reach the ground takes none (the reason says why)
##   gate    an opening in the gate's leaf can be covered; no door in the gate
##
##   Godot --headless --fixed-fps 120 --path . -s tests/building/test_opening_fixes.gd
## "OPENING FIXES TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0
var p: FrontierPlayer
var wc: WallCuts
var bm: BuildMode


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _logs() -> int:
	return bm.pack_count("log")


func _blocked(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [p.get_rid()]
	return not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Build mode with `type`, the crosshair from `from` into `at`: the verdict after a refresh.
func _aim(type: String, from: Vector3, at: Vector3) -> Dictionary:
	bm.set_active(true)
	bm.select_type(type)
	bm.aim_from = from
	bm.aim_at = at
	await _ticks(6)
	return bm.verdict


func _place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.yaw = yaw
	p.traversal.controller.teleported()
	await _ticks(20)


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
	wc = WallCuts.find(self)
	bm = p.building
	var inv := InventoryState.from_player(p)
	inv.add("log", 20)
	p.inventory_pack = inv.pack.duplicate(true)
	# the east wall (x = 16), its logs k .. k + 1 about z = 2
	var wi := -1
	for i in wc.walls.size():
		if not bool(wc.walls[i].local) and absf((wc.walls[i].a as Vector3).x - 16.0) < 0.01:
			wi = i
	var w: Dictionary = wc.walls[wi]
	var k := 0
	var best := INF
	for j in (wc.logs[wi] as Array).size() - 1:
		var d := absf(((w.a as Vector3) + (w.dir as Vector3) * float(wc.logs[wi][j].u)).z - 2.0)
		if d < best:
			best = d
			k = j
	var at := func(kk: int, h: float) -> Vector3:
		var u := 0.5 * (float(wc.logs[wi][kk].u) + float(wc.logs[wi][kk + 1].u))
		return (w.a as Vector3) + (w.dir as Vector3) * u + Vector3.UP * h
	var inside := Vector3(-1.0, 0, 0)          # from the wall toward the fort
	await _place(Vector3(14.9, 0.02, 2.0), -PI * 0.5)

	# cover
	wc.cut(wi, k, 1.0, 1.7)
	var c1: Vector3 = at.call(k, 1.35)
	_check(not _blocked(c1 + inside, c1 - inside), "an opening chopped (a ray passes it)")
	var v := await _aim("opening_cover", c1 + inside * 1.0, c1)
	_check(bool(v.get("ok", false)), "build mode: Cover with logs on it (%s)" % str(v.get("reason", "")))
	var n0 := _logs()
	bm.place()
	await _ticks(4)
	_check(_blocked(c1 + inside, c1 - inside), "covered: the ray is stopped")
	_check(_logs() == n0 - 1, "1 log paid (%d -> %d)" % [n0, _logs()])
	wc.cut(wi, k, 1.0, 1.7)
	await _ticks(4)
	_check(not _blocked(c1 + inside, c1 - inside) and wc.fills.is_empty(), "chopping into the cover knocks it out")

	# repair
	v = await _aim("opening_repair", c1 + inside * 1.0, c1)
	_check(bool(v.get("ok", false)), "build mode: Repair the wall on it (%s)" % str(v.get("reason", "")))
	n0 = _logs()
	bm.place()
	await _ticks(4)
	_check(_blocked(c1 + inside, c1 - inside) and (w.holes as Array).is_empty(), "repaired: the wall is whole again")
	_check(_logs() == n0 - 2, "2 logs paid (%d -> %d)" % [n0, _logs()])

	# door: not where the opening does not reach the ground, then in one chopped from the ground up
	wc.cut(wi, k + 4, 1.0, 1.7)
	var c2: Vector3 = at.call(k + 4, 1.35)
	v = await _aim("opening_door", c2 + inside * 1.0, c2)
	_check(not bool(v.get("ok", true)) and str(v.get("reason", "")).begins_with("Chop it open from the ground up"),
			"no door where the opening does not reach the ground (%s)" % str(v.get("reason", "")))
	for h: Array in [[0.0, 0.7], [0.7, 1.4], [1.4, 2.1]]:
		wc.cut(wi, k, float(h[0]), float(h[1]))
	var c3: Vector3 = at.call(k, 1.0)
	v = await _aim("opening_door", c3 + inside * 1.0, c3)
	_check(bool(v.get("ok", false)), "a door fits the opening chopped from the ground up (%s)" % str(v.get("reason", "")))
	n0 = _logs()
	bm.place()
	bm.set_active(false)
	await _ticks(10)
	var door: BuildDoor = null
	for f: Dictionary in wc.fills:
		if str(f.kind) == "door":
			door = f.door
	_check(door != null and _logs() == n0 - 3, "the door hangs in it (3 logs paid)")
	if door:
		await _place(Vector3(c3.x, 0.02, c3.z) + inside * 1.3, -PI * 0.5)
		Input.action_press("move_forward")
		await _ticks(180)
		Input.action_release("move_forward")
		_check(p.global_position.x < 15.8, "shut, the door stops the body (x %.2f)" % p.global_position.x)
		_check(door.interact_prompt(p) == "Open the door", "E at it: %s" % door.interact_prompt(p))
		door.interact(p)
		await _place(Vector3(c3.x, 0.02, c3.z) + inside * 1.3, -PI * 0.5)
		await _ticks(90)
		Input.action_press("move_forward")
		await _ticks(240)
		Input.action_release("move_forward")
		_check(p.global_position.x > 16.3, "open, the body walks out through it (x %.2f)" % p.global_position.x)

	# the gate's leaf: cover yes, door no
	var gate := FortGate.find(self)
	gate.set_open(false, true)
	await _ticks(10)
	var lw: int = gate.leaves[1].wall
	wc.cut(lw, 3, 1.0, 1.7)
	var fr := wc.frame(lw)
	var gu := 0.5 * (float(wc.logs[lw][3].u) + float(wc.logs[lw][4].u))
	var gc: Vector3 = (fr[0] as Vector3) + (fr[1] as Vector3) * gu + Vector3.UP * 1.35
	await _place(Vector3(gc.x, 0.02, gc.z + 1.2), 0.0)
	v = await _aim("opening_door", gc + Vector3(0, 0, 1.0), gc)
	_check(not bool(v.get("ok", true)) and str(v.get("reason", "")) == "No door in the gate", "no door in the gate (%s)" % str(v.get("reason", "")))
	v = await _aim("opening_cover", gc + Vector3(0, 0, 1.0), gc)
	_check(bool(v.get("ok", false)), "the gate's opening can be covered (%s)" % str(v.get("reason", "")))
	bm.place()
	await _ticks(4)
	_check(_blocked(gc + Vector3(0, 0, 1.0), gc - Vector3(0, 0, 1.0)), "covered, the gate's opening stops the ray")
	bm.set_active(false)

	if _fails.is_empty():
		print("OPENING FIXES TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("OPENING FIXES TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
