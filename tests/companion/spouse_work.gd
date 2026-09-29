extends SceneTree
## The spouse at work in the level, windowed (survival on): a home role with raw venison in the store walks to the hearth, kneels
## and cooks; an outside role goes out to forage. Game time is pushed on by hand.
##   Godot --path . --resolution 1280x720 -s tests/companion/spouse_work.gd -- out=<abs dir> survival=on
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


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	await _frames(120)
	h = Household.find(self)
	var sc := h.sc
	# the fort's own chests (FortPlan) are the household's store: raw venison in them
	var store: HouseholdStock = h.stock
	print("chests: ", get_nodes_in_group(StorageChest.GROUP).size())
	store.put("venison", 6)
	print(h.set_role("home"))
	var core := h.bridge.core
	var first_kneel := -1
	for i in 1500:
		await process_frame
		core.advance(0.8)
		if h.body._phase == "work" and sc.busy() and first_kneel < 0:
			first_kneel = i
			print("kneeling at frame ", i, " at ", h.body.global_position, " task ", sc.task)
			var to := h.body.global_position - player.global_position
			player.yaw = atan2(-to.x, -to.z)
			player.rotation.y = player.yaw
			await _frames(20)
			await _shot("cooking")
		if first_kneel >= 0 and not sc.busy() and h.body._phase == "":
			print("finished at frame ", i)
			break
	print("store: ", store.all(), " journal: ", sc.journal.slice(-3))
	# outside: goes out to forage
	print(h.set_role("outside"))
	var far := 0.0
	var did := false
	for i in 2500:
		await process_frame
		core.advance(0.8)
		far = maxf(far, h.body.global_position.distance_to(h.home))
		if sc.busy() and not did:
			did = true
			print("outside task ", sc.task, " at ", h.body.global_position.distance_to(h.home), " m from home")
			await _shot("foraging")
		if did and not sc.busy():
			break
	print("outside: farthest ", far, " m, journal ", sc.journal.slice(-2))
	print("SPOUSE WORK DONE ", out)
	quit()
