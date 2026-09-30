extends SceneTree
## An order with a job ("go there and forage"): the worker walks to the place, takes the job on, and her outside work is
## round that place, not round home; a plain order changes nothing; a new job order from the Talk tab's buttons (Household
## .order) puts her work round home again.
##   Godot --headless --fixed-fps 120 --path . -s tests/companion/test_order_act.gd -- survival=on
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
	_expect(h != null and h.body != null, "the household and the wife's body are in")
	if h == null or h.body == null:
		quit(1)
		return
	player.global_position = Vector3(3.0, 0.1, 12.0)
	for i in 300:
		await physics_frame
	var b := h.body
	var at := h.home + Vector3(6.0, 0.0, 6.0)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	# a plain go: no job taken, no work place set
	var before := b.sc.focus
	WorkerOrders.order(b, at)
	_expect(b.order_acts.size() == 1 and String(b.order_acts[0]) == "", "a plain order holds no job")
	for i in 120 * 25:
		await physics_frame
		if b.orders.is_empty():
			break
	_expect(b.orders.is_empty(), "she got there")
	_expect(b.work_at == Vector3.INF and b.sc.focus == before, "a plain order leaves her work alone")
	# a job at a place
	var far := Vector3(10.0, 0.0, 12.0)
	far.y = FrontierTerrain.height_at(far.x, far.z)
	WorkerOrders.order(b, far, false, PackedVector3Array(), "forage")
	for i in 120 * 25:
		await physics_frame
		if b.orders.is_empty():
			break
	print("  she is ", b.global_position, " the place ", far, " orders ", b.orders.size(), " home ", h.home)
	_expect(b.orders.is_empty() and b.order_acts.is_empty(), "she got there, the job spent")
	_expect(b.sc.focus == "forage" and b.sc.role == "outside", "she took on foraging, outside")
	_expect(b.work_at.distance_to(far) < 0.01, "her work is round the place she was sent to")
	var site := b._site_for({"site": "woods"})
	_expect(Vector2(site.x - far.x, site.z - far.z).length() < 8.5, "a woods site is within 8.5 m of it (%.1f)" % Vector2(site.x - far.x, site.z - far.z).length())
	# the Talk tab's own order puts her work round home again
	h.order("firewood", b.sc)
	_expect(b.work_at == Vector3.INF, "asking for a job from the Talk tab clears the place")
	# the Talk tab's "Send her out to" row: picks her, and the next click places the job
	h.open(b, "talk")
	await physics_frame
	await physics_frame
	var scr: HouseholdScreen = null
	for n in root.find_children("*", "HouseholdScreen", true, false):
		scr = n as HouseholdScreen
	_expect(scr != null, "the Talk tab opens")
	var sends: Array[Button] = []
	if scr != null:
		for bt in scr.find_children("*", "Button", true, false):
			if (bt as Button).text == "Forage":
				sends.append(bt as Button)
	_expect(sends.size() == 2, "Forage is on the tab twice: ask, and send out (%d)" % sends.size())
	if sends.size() == 2:
		sends[1].pressed.emit()
		await physics_frame
		await physics_frame
		var wo := WorkerOrders.ensure(self)
		_expect(wo.picked == b and wo.next_act == "forage", "she is picked with the job waiting for a place")
		_expect(scr == null or not is_instance_valid(scr) or scr.is_queued_for_deletion(), "the screen closes")
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)
