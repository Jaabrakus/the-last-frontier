extends SceneTree
## Command mode (RtsMode; user 2026-09-30: "we need to make npc logic like rts logic ... lets build a rts mode"), headless, in the level:
##
##   Godot --headless --fixed-fps 120 --path . -s tests/rts/test_rts_mode.gd -- survival=on fort_plan=on
##
##   mode      F1: the camera is over the land and current, the player's own controls rest; again: the player's camera and controls back
##   select    a click's pick, a box's pick (from the camera's projection), Esc lets go, groups keep and recall
##   orders    the selection sent to a place: each worker has an order near it, spread (not on one spot), and walks there;
##             Shift queues after the places they have; X stops them
## Ends with "RTS MODE TEST PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var h: Household
var rts: RtsMode


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await _fr(20)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	for i in 600:
		await physics_frame
		h = Household.find(self)
		if h != null and h.body != null:
			break
	_expect(h != null and h.body != null, "the household and the wife's body are in (survival=on)")
	rts = p.rts
	_expect(rts != null, "the player has the command mode")
	if h == null or rts == null:
		quit(1)
		return
	h.add_worker()
	h.add_worker()
	await _fr(60)
	var us := rts.units()
	_expect(us.size() >= 3, "three workers are commandable (%d)" % us.size())
	# the mode
	rts.set_active(true)
	await _fr(5)
	_expect(rts.active and rts.cam.current and not p.controls.from_input, "F1: the camera is over the land, the player's keys rest")
	_expect(rts.cam.global_position.y > p.global_position.y + 10.0, "the camera is high (%.0f m over)" % (rts.cam.global_position.y - p.global_position.y))
	# selection
	var u0 := us[0]
	var sp := rts.cam.unproject_position(u0.global_position + Vector3.UP * 0.9)
	_expect(rts.unit_at(sp) == u0, "a click on a worker picks her")
	var box := Rect2(Vector2.ZERO, rts.get_viewport().get_visible_rect().size)
	var inbox := rts.units_in(box)
	_expect(inbox.size() >= 1 and inbox.has(u0), "a box over the screen picks the ones in view (%d)" % inbox.size())
	rts.select(us)
	_expect(rts.selected.size() == us.size(), "all selected (%d)" % rts.selected.size())
	rts.keep_group(1)
	rts.deselect()
	_expect(rts.selected.is_empty(), "let go")
	rts.recall_group(1)
	_expect(rts.selected.size() == us.size(), "group 1 recalled")
	# orders
	var mid := Vector3.ZERO
	for u in rts.selected:
		mid += u.global_position
	mid /= float(rts.selected.size())
	var at := mid + Vector3(14.0, 0.0, 0.0)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	var n := rts.order_to(at)
	_expect(n == rts.selected.size(), "the order is given to all %d" % n)
	var spots := {}
	var near := true
	for u in rts.selected:
		var o: Vector3 = u.orders[0]
		spots[snappedf(o.x, 0.1) * 1000.0 + snappedf(o.z, 0.1)] = true
		near = near and Vector2(o.x - at.x, o.z - at.z).length() < 4.0
	_expect(spots.size() == rts.selected.size() and near, "spread in a formation round the place, not on one spot")
	var d0 := (rts.selected[0].global_position - at).length()
	await _fr(8 * 120)
	var d1 := (rts.selected[0].global_position - at).length()
	_expect(d1 < d0 - 4.0, "they walk there (%.0f m -> %.0f m)" % [d0, d1])
	rts.order_to(at + Vector3(0, 0, 10.0), true)
	_expect(rts.selected[0].orders.size() >= 2 or rts.selected[0].global_position.distance_to(at) < 3.0, "Shift queues a place after")
	rts.stop()
	var cleared := true
	for u in rts.selected:
		cleared = cleared and u.orders.is_empty()
	_expect(cleared, "X stops them")
	# leaving
	rts.set_active(false)
	await _fr(5)
	_expect(not rts.active and not rts.cam.current and p.controls.from_input and p.camera.current, "F1 again: the player's camera and keys back")
	if fails.is_empty():
		print("RTS MODE TEST PASSED (%d checks)" % checks)
	else:
		print("RTS MODE TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
