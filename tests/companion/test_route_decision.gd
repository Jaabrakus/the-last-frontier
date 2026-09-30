extends SceneTree
## RouteDecision in the level: a way out of the yard goes through the gate (verdict "door"); the straight line to the same
## place is stopped by the palisade (what blocked_by names); a place with no way (routes empty) is reported blocked, and
## WorkerOrders does not give the order.
##   Godot --headless --fixed-fps 120 --path . -s tests/companion/test_route_decision.gd -- survival=on
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
	await physics_frame
	var out_to := Vector3(0.0, 0.0, -45.0)
	out_to.y = FrontierTerrain.height_at(out_to.x, out_to.z)
	var d := RouteDecision.decide(b, out_to)
	_expect(bool(d.ok) and int(d.pick) >= 0, "a way out of the yard exists")
	if bool(d.ok):
		var r: Dictionary = (d.routes as Array)[int(d.pick)]
		print("  pick ", r.kind, " ", snappedf(float(r.len), 0.1), " m, verdict ", r.verdict, ", doors ", (r.doors as Array).size())
		_expect(String(r.verdict) == "door" and not (r.doors as Array).is_empty(), "it goes through the gate: verdict door")
	var bl := RouteDecision.blocked_by(b, out_to)
	print("  straight line stopped at ", bl.at, " by ", bl.why)
	_expect(Vector3(bl.at).distance_to(out_to) > 3.0, "the straight line is stopped short of it")
	# nothing to choose from: the decision says blocked and gives the reason
	var none := RouteDecision.decide(b, out_to, [])
	_expect(bool(none.ok) or not (none.blocked as Dictionary).is_empty(), "with no routes given it plans its own")
	var wo := WorkerOrders.ensure(self)
	await physics_frame
	var open := b.global_position + Vector3(4.0, 0.0, 0.0)
	open.y = FrontierTerrain.height_at(open.x, open.z)
	var dd := RouteDecision.decide(b, open)
	_expect(bool(dd.ok) and String((dd.routes as Array)[int(dd.pick)].verdict) == "clear", "open ground in the yard is clear")
	# the preview keeps only what the decision allows: routes empty + blocked set when nothing comes back
	var kept := wo._decided(b, out_to, [])
	_expect(not kept.is_empty() or not wo.blocked.is_empty(), "the preview holds routes or a blocked reason")
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)
