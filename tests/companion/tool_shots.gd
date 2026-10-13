extends SceneTree
## Look-check of the household's tool pool in the level, windowed (survival on, the fort's plan built): a hand set to gather
## firewood walks to the chest for a hatchet, splits wood in the woods with it in her hand, and at dusk walks it back to the
## chest; then the Tasks tab with the pool.
##   Godot --path . --resolution 1280x720 -s tests/companion/tool_shots.gd -- out=<abs dir> survival=on fort_plan=on
var out := ""
var player: FrontierPlayer
var h: Household


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	var drawn := [false]
	var on_draw := func() -> void: drawn[0] = true
	RenderingServer.frame_post_draw.connect(on_draw, CONNECT_ONE_SHOT)
	for i in 600:
		await process_frame
		if drawn[0]:
			break
	if not drawn[0]:
		print("(no frame drawn for ", name, ")")
		RenderingServer.frame_post_draw.disconnect(on_draw)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _look(at: Vector3, target: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	player.global_position = at
	var to := target - at
	player.yaw = atan2(-to.x, -to.z)
	player.rotation.y = player.yaw
	if player.get("pitch") != null:
		player.set("pitch", -0.12)


var cam: Camera3D


## A camera of its own `off` from her (m, flat) at eye height, looking at her hands (or at `at`).
func _watch(b: Node3D, off := Vector3(2.4, 0, 2.2), at := Vector3.INF) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 55.0
		current_scene.add_child(cam)
	cam.current = true
	var from := b.global_position + off
	from.y = maxf(b.global_position.y + 1.45, FrontierTerrain.height_at(from.x, from.z) + 0.8)
	cam.global_position = from
	cam.look_at(at if at != Vector3.INF else b.global_position + Vector3(0, 0.95, 0), Vector3.UP)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, OS.has_environment("TB_ON_TOP"))
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	await _frames(120)
	h = Household.find(self)
	if h == null or h.body == null or h.stock.pool == null:
		print("TOOL SHOTS FAILED: no household or pool (%s)" % [h])
		quit(1)
		return
	var p := h.stock.pool
	var main := h.bridge.core
	main.state.minutes = floorf(main.state.minutes / 1440.0) * 1440.0 + 9.0 * 60.0 + 1440.0
	for i in 40:
		await process_frame
		if bool(p.seeded.chest):
			break
	print("pool: ", p.counts().keys(), " chests ", h.stock.chests_ready(), " racks ", h.stock.racks_ready())
	print("hatchets in store ", p.in_store("hatchet"), " axe ", p.in_store("axe"), " musket ", p.in_store("musket"))
	# the wife keeps house (no firewood); a hand does only firewood, outside; the store short of wood
	h.stock.put("jerky", 20)
	h.stock.take("firewood", 999)
	for id: String in JobBook.ids():
		h.sc.enabled[id] = id not in ["firewood", "butcher"]
	var w := h.add_worker(4242, 1.0, ["firewood"])
	w.role = "outside"
	# only one hatchet, and no felling axe: she has to take that one
	h.stock.take("hatchet", maxi(p.in_store("hatchet") - 1, 0))
	h.stock.take("axe", p.in_store("axe"))
	await _frames(5)
	var b := h.body_of(w)
	var chest: Node3D = h.stock.spot_for("hatchet", true)
	print("worker ", w.name, " at ", b.global_position, " chest ", chest.global_position if chest else Vector3.INF, " kit in core: ",
			SurvivalInventory.has(w.core, "item.tool.hatchet"))
	# she plans firewood, claims the hatchet and walks to the chest for it
	var fetched := false
	for i in 1800:
		await process_frame
		if p.held_by(w).has("hatchet"):
			fetched = true
			break
	print("fetched ", fetched, " held ", p.held_by(w), " at ", b.global_position, " dist to chest ",
			b.global_position.distance_to(chest.global_position) if chest else -1.0)
	await _frames(10)
	# on her right, the hand with the hatchet toward the camera, the chest behind
	_watch(b, (-b.global_basis.x * 1.5 + b.global_basis.z * 1.0) * 1.2)   # (her body faces its +Z)
	await _frames(20)
	await _shot("t1_hatchet_from_chest")
	# out to the woods and at work
	var working := false
	for i in 9000:
		await process_frame
		if w.busy() and w.task == "firewood":
			working = true
			break
	print("working ", working, " core has hatchet ", SurvivalInventory.has(w.core, "item.tool.hatchet"), " at ", b.global_position)
	await _frames(90)
	_watch(b, (b.global_basis.z - b.global_basis.x) * 1.3 + Vector3.UP * 0.6)
	await _frames(20)
	await _shot("t2_splitting_with_hatchet")
	# the run ends; dusk: she walks it back
	for i in 60:
		main.advance(10.0)
		await _frames(3)
		if not w.busy():
			break
	print("run done, store firewood ", h.stock.count("firewood"), " held ", p.held_by(w), " journal ", w.journal.slice(-3))
	main.state.minutes = floorf(main.state.minutes / 1440.0) * 1440.0 + 19.2 * 60.0
	var back := false
	for i in 9000:
		await process_frame
		if p.held_by(w).is_empty():
			back = true
			break
	print("returned ", back, " store hatchet ", p.in_store("hatchet"), " at ", b.global_position, " wear ", p.stored_wear)
	await _frames(20)
	var ch2: Node3D = h.stock.spot_for("hatchet", true)
	print("chest with the hatchet ", ch2.global_position if ch2 else Vector3.INF, " by her ", b.global_position.distance_to(ch2.global_position) if ch2 else -1.0)
	_watch(b, (b.global_basis.z * 1.5 - b.global_basis.x) * 1.4)
	await _frames(20)
	await _shot("t3_returned_at_dusk")
	if cam != null:
		cam.current = false
	h.open(b, "tasks")
	await _frames(15)
	if h.screen != null:
		var sc := h.screen.find_children("*", "ScrollContainer", true, false)
		if not sc.is_empty():
			(sc[0] as ScrollContainer).scroll_vertical = 100000
	await _frames(10)
	await _shot("t4_tasks_tab")
	print("TOOL SHOTS DONE ", out)
	quit()
