extends SceneTree
## Closing the openings cut in the palisade (user 2026-09-26: "each one hole we cut we need to either be able to build a
## doors there or cover it up with logs or repair it"; 2026-09-28: "a cut opening can be filled back in"; doors stay a builder
## piece: the palisade gate / a wall with a door), from build mode on the real level with the real player, on the fort's own
## built palisade (PalisadeCuts):
##   cover   horizontal logs across an opening close it (a ray through it is stopped, 1 log paid); chopping into the cover
##           knocks it out again (no second hole)
##   repair  the stakes stand there again (the opening is gone, 2 logs paid)
##   nothing to close where the crosshair is not in an opening; no "door in the wall" entry in the menu any more
##
##   Godot --headless --fixed-fps 120 --path . -s tests/building/test_opening_fixes.gd
## "OPENING FIXES TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0
var p: FrontierPlayer
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
	bm = p.building
	var world := BuildWorld.of(self, false)
	var inv := InventoryState.from_player(p)
	inv.add("log", 20)
	p.inventory_pack = inv.pack.duplicate(true)
	_check(not bm.data.order.has("opening_door") and bm.data.order.has("opening_cover") and bm.data.order.has("opening_repair"),
			"the menu has Repair and Cover, no door in the wall")
	# the east wall (x = 16): the built section about z = 2
	var sec: BuiltPiece = null
	for q in world.pieces():
		if q.type == "palisade" and absf(q.global_position.x - 16.0) < 0.01 and absf(q.global_position.z - 2.0) < 1.5:
			sec = q
	_check(sec != null, "a built palisade section on the east wall")
	if sec == null:
		_finish()
		return
	var into := -sec.global_transform.basis.z             # from the wall toward the fort
	var k := 1
	var xr := PalisadeCuts.x_range(k)
	var xm := 0.5 * (xr.x + xr.y)
	var c1: Vector3 = sec.global_transform * Vector3(xm, 1.5, 0.0)
	await _place(Vector3(c1.x, 0.02, c1.z) + into * 1.2, -PI * 0.5)

	# nothing to close where the wall is whole
	var v := await _aim("opening_cover", c1 + into * 1.0 + Vector3(0, 1.0, 0), c1 + Vector3(0, 1.0, 0))
	_check(not bool(v.get("ok", true)), "no opening under the crosshair: nothing to cover (%s)" % str(v.get("reason", "")))

	# cover
	PalisadeCuts.cut(world, sec.piece_id, k, 1.0, 2.0)
	await _ticks(4)
	_check(not _blocked(c1 + into, c1 - into), "an opening cut (a ray passes it)")
	v = await _aim("opening_cover", c1 + into * 1.0, c1)
	_check(bool(v.get("ok", false)), "build mode: Cover with logs on it (%s)" % str(v.get("reason", "")))
	var n0 := _logs()
	bm.place()
	await _ticks(4)
	_check(_blocked(c1 + into, c1 - into), "covered: the ray is stopped")
	_check(_logs() == n0 - 1, "1 log paid (%d -> %d)" % [n0, _logs()])
	v = await _aim("opening_cover", c1 + into * 1.0, c1)
	_check(not bool(v.get("ok", true)), "a covered opening takes no second cover (%s)" % str(v.get("reason", "")))
	PalisadeCuts.cut(world, sec.piece_id, k, 1.0, 2.0)
	await _ticks(4)
	_check(not _blocked(c1 + into, c1 - into) and sec.cuts.size() == 1, "chopping into the cover knocks it out (no second hole: %d)" % sec.cuts.size())

	# repair
	v = await _aim("opening_repair", c1 + into * 1.0, c1)
	_check(bool(v.get("ok", false)), "build mode: Repair the wall on it (%s)" % str(v.get("reason", "")))
	n0 = _logs()
	bm.place()
	await _ticks(4)
	_check(_blocked(c1 + into, c1 - into) and sec.cuts.is_empty(), "repaired: the wall is whole again")
	_check(_logs() == n0 - 2, "2 logs paid (%d -> %d)" % [n0, _logs()])
	bm.set_active(false)
	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("OPENING FIXES TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("OPENING FIXES TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
