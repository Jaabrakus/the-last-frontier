extends SceneTree
## Look-check of the spouse in the level, windowed (survival on): she stands by the player, follows when they walk off, goes
## to work at home (a chest of raw venison), and the household screen's three tabs.
##   Godot --path . --resolution 1280x720 -s tests/companion/spouse_shots.gd -- out=<abs dir> survival=on
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
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
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
	print("household: ", h != null, " spouse: ", h.sc.name if h and h.sc else "-", " sex: ", h.sc.look.get("sex") if h and h.sc else "-")
	if h == null or h.body == null:
		print("SPOUSE SHOTS FAILED: no household")
		quit(1)
		return
	print("spouse at ", h.body.global_position, " player at ", player.global_position)
	# look at her
	var to := h.body.global_position - player.global_position
	player.yaw = atan2(-to.x, -to.z)
	player.rotation.y = player.yaw
	await _frames(40)
	await _shot("beside")
	# she follows when the player walks off 20 m
	var start := h.body.global_position
	player.global_position += Vector3(0, 0, -20)
	await _frames(400)
	print("followed: moved ", start.distance_to(h.body.global_position), " m, now ", h.body.global_position.distance_to(player.global_position), " m from the player, clip ", h.body._clip)
	await _shot("followed")
	# the screen
	h.open(h.body, "talk")
	await _frames(15)
	await _shot("talk")
	h.screen._show("tasks")
	await _frames(10)
	await _shot("tasks")
	h.screen._show("stats")
	await _frames(10)
	await _shot("stats")
	h.screen.queue_free()
	await _frames(5)
	print("SPOUSE SHOTS DONE ", out)
	quit()
