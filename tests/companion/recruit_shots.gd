extends SceneTree
## Look-check of recruiting in the level, windowed (survival on, the fort's plan built): a travelling party walking in along
## the east road, the party at the camp by the east path, the talk screen, a recruit joining and walking round to the gate
## and home, and the household screen with her morale.
##   Godot --path . --resolution 1280x720 -s tests/companion/recruit_shots.gd -- out=<abs dir> survival=on fort_plan=on
var out := ""
var player: FrontierPlayer
var h: Household
var link: RecruitLink


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
	# (another windowed run on top can stop this window drawing: it is kept on top, and the shot does not wait forever)
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


## The player stands at `at` looking at `target`.
func _look(at: Vector3, target: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	player.global_position = at
	var to := target - at
	player.yaw = atan2(-to.x, -to.z)
	player.rotation.y = player.yaw
	if player.get("pitch") != null:
		player.set("pitch", -0.08)


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
	link = RecruitLink.find(self)
	if h == null or link == null or h.body == null:
		print("RECRUIT SHOTS FAILED: no household (%s) or recruiting (%s)" % [h, link])
		quit(1)
		return
	var main := link.main()
	# daylight, food in the store for the wants
	main.state.minutes = floorf(main.state.minutes / 1440.0) * 1440.0 + 10.0 * 60.0 + 1440.0
	await _frames(10)
	var put := h.stock.put("jerky", 40) + h.stock.put("roast_venison", 30)
	print("store: put ", put, " ", h.stock.all())
	# a settler couple on the east road, part way in
	link._ensure()
	link.st.next_at = 1e12
	var party := Recruit.make_party(link.st, main.state.minutes, "settler_couple", main)
	var road := link._road(String(party[0].road))
	print("party: ", party.map(func(c: Dictionary) -> String: return "%s (%s, %s)" % [c.name, c.people, c.kind]), " road ", party[0].road)
	await _frames(3)
	var b0: RecruitBody = link.bodies.get(String(party[0].id))
	var b1: RecruitBody = link.bodies.get(String(party[1].id))
	if b0 == null:
		print("RECRUIT SHOTS FAILED: no body")
		quit(1)
		return
	# bring them along the road near the camp end, then watch them walk in
	var near: Vector3 = road[road.size() - 2] if road.size() >= 2 else road[0]
	b0.global_position = near + Vector3(0, 0.3, 0)
	b1.global_position = near + Vector3(0.8, 0.3, 1.2)
	b0.walk(road.slice(road.size() - 1) + [link.camp_spot(party[0])])
	b1.walk(road.slice(road.size() - 1) + [link.camp_spot(party[1])])
	await _frames(90)
	# stood on the path ahead of them, looking back down it at them coming
	var ahead: Vector3 = b0.global_position + (link.camp_spot(party[0]) - b0.global_position).normalized() * 7.0
	_look(ahead + Vector3(1.2, 0, 0), b0.global_position + Vector3(-1.0, 1.0, 0))
	print("walking: ", b0.global_position, " mode ", b0.mode, " clip ", b0._clip)
	await _shot("r1_arriving")
	for i in 900:
		await process_frame
		if b0.mode == "camp" and b1.mode == "camp":
			break
	await _frames(60)
	print("camped: ", b0.global_position, " state ", party[0].state, ", ", party[1].state)
	var mid := (b0.global_position + b1.global_position) * 0.5
	_look(mid + Vector3(-4.5, 0, -1.5), mid + Vector3(0, 1.0, 1.6))
	await _frames(40)
	await _shot("r2_camped")
	# the talk screen: talk, give food, offer a share, and the odds
	link.open(String(party[0].id))
	await _frames(10)
	var scr := link.screen
	link.talk(party[0])
	link.gift(party[0])
	link.set_share(party[0], 1)
	scr.rebuild()
	await _frames(10)
	var o := link.odds(party[0])
	print("odds ", o.pct, "% blocked '", o.blocked, "' ", Recruit.factors_text(o), " places ", link.places(), " occupants ", link.occupants())
	await _shot("r3_talk")
	# they join (a sure roll for the shot) and walk round to the gate and home
	var r := scr.ask_now(0.0)
	print("ask: ", r)
	await _frames(10)
	await _shot("r4_joined")
	scr.queue_free()
	await _frames(5)
	var w: SpouseCore = null
	for x: SpouseCore in h.workers():
		if not x.recruit.is_empty():
			w = x
	var walker: RecruitBody = link.homebound.get(w)
	print("worker ", w.name if w else "-", " id ", w.worker_id if w else -1, " role ", w.role if w else "", " walker ", walker)
	if walker != null:
		for i in 240:
			await process_frame
		_look(walker.global_position + Vector3(6.0, 0, 5.0), walker.global_position + Vector3(0, 1.0, 0))
		await _frames(20)
		await _shot("r5_walking_home")
		# (on through the gate: the last stretch in)
		if walker.route.size() > 2:
			walker.global_position = (walker.route[walker.route.size() - 2] as Vector3) + Vector3(0, 0.3, 0)
			walker.route = walker.route.slice(walker.route.size() - 1)
		var t0 := Time.get_ticks_msec()
		while is_instance_valid(walker) and link.homebound.has(w) and Time.get_ticks_msec() - t0 < 90000:
			await process_frame
		print("home after ", (Time.get_ticks_msec() - t0) / 1000.0, " s; body ", h.body_of(w))
	var sb := h.body_of(w) if w else null
	if sb != null:
		_look(sb.global_position + Vector3(3.0, 0, 3.5), sb.global_position + Vector3(0, 1.0, 0))
		await _frames(60)
		await _shot("r6_home")
		h.open(sb, "tasks")
		await _frames(15)
		await _shot("r7_household_tasks")
		h.screen.queue_free()
		await _frames(5)
		# dismissed: she walks away
		h.remove_worker(w)
		await _frames(200)
		await _shot("r8_dismissed")
	print("departures ", link.st.departures)
	print("RECRUIT SHOTS DONE ", out)
	quit()
