extends SceneTree
## RouteDecision with nothing to reach and barred doors:
##   walled   a place inside a ring of walls built in the yard: no way (ok false), the red line has a way to where she gets
##            nearest and says it cannot be reached; WorkerOrders does not give the order;
##   barred   the fort's gate barred: no route goes through it (a shut gate is a wall to the grid), E does nothing to it and
##            NavWorld does not open it; unbarred, the way out is through it again (verdict "door").
##   Godot --headless --fixed-fps 120 --path . -s tests/companion/test_route_blocked.gd -- survival=on
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	Sharpness.slips_on = false
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _wall(at: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	current_scene.add_child(sb)
	sb.global_position = at


func _run() -> void:
	for i in 20:
		await physics_frame
	var player := current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	var h: Household = null
	for i in 600:
		await physics_frame
		h = Household.find(self)
		if h != null and h.body != null:
			break
	if h == null or h.body == null:
		print("FAIL no household")
		quit(1)
		return
	player.global_position = Vector3(3.0, 0.1, 12.0)
	for i in 300:
		await physics_frame
	var b := h.body
	b.global_position = Vector3(3.0, 0.1, 9.0)
	var wo := WorkerOrders.ensure(self)
	await physics_frame
	var g := WalkGrid.of(self)
	# ---- walled: a closed ring of walls round (10, y, 12) in the yard
	var cx := 10.0
	var cz := 12.0
	var gy := FrontierTerrain.height_at(cx, cz)
	for s: float in [-1.0, 1.0]:
		_wall(Vector3(cx + s * 3.0, gy + 1.5, cz), Vector3(0.4, 3.0, 6.4))
		_wall(Vector3(cx, gy + 1.5, cz + s * 3.0), Vector3(6.4, 3.0, 0.4))
	g.dirty(Vector3(cx, gy, cz), 12.0)
	await physics_frame
	var inside := Vector3(cx, gy, cz)
	var d := RouteDecision.decide(b, inside)
	_expect(not bool(d.ok), "a place inside a closed ring of walls has no way")
	_expect(not (d.blocked as Dictionary).is_empty() and String(d.blocked.why).contains("reached"), "it says it cannot be reached (%s)" % String(d.blocked.get("why", "")))
	_expect((d.blocked as Dictionary).has("way"), "the red line has a way to where she gets nearest")
	wo.picked = b
	var kept := wo._decided(b, inside, WorkerOrders.routes_for(b, inside))
	_expect(kept.is_empty() and not wo.blocked.is_empty(), "the preview keeps no route and holds the reason")
	var n0 := b.orders.size()
	wo.order(b, b.global_position + Vector3(2.0, 0.0, 0.0))     # (a plain order still goes)
	_expect(b.orders.size() == n0 + 1, "an order to open ground is still given")
	b.orders.clear()
	b.order_acts.clear()
	b.order_ways.clear()
	# ---- barred: the gate
	var gate: BuildDoor = null
	for dd: BuildDoor in g._door_list():
		if dd.kind == "gate":
			gate = dd
	_expect(gate != null, "the level has a gate")
	if gate == null:
		quit(1)
		return
	var out_to := Vector3(0.0, 0.0, -45.0)
	out_to.y = FrontierTerrain.height_at(out_to.x, out_to.z)
	var open_d := RouteDecision.decide(b, out_to)
	_expect(bool(open_d.ok), "with the gate unbarred there is a way out")
	gate.locked = true
	g.dirty(gate.global_position, 12.0)
	await physics_frame
	var shut := RouteDecision.decide(b, out_to)
	var through := false
	if bool(shut.ok):
		for r: Dictionary in shut.routes:
			through = through or (r.doors as Array).has(gate)
	_expect(not through, "barred: no way goes through the gate")
	print("  barred: ok ", shut.ok, " ", String((shut.blocked as Dictionary).get("why", "")))
	var nw := NavWorld.of(self)
	if nw != null:
		nw.open_door(gate)
	_expect(not gate.is_open, "NavWorld does not open a barred gate")
	gate.interact(player)
	_expect(not gate.is_open and gate.interact_prompt(player).contains("barred"), "E does nothing and the prompt says barred")
	gate.locked = false
	g.dirty(gate.global_position, 12.0)
	await physics_frame
	var again := RouteDecision.decide(b, out_to)
	_expect(bool(again.ok) and String((again.routes as Array)[int(again.pick)].verdict) == "door", "unbarred: the way out is through the gate again")
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)
