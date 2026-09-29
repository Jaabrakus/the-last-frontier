extends SceneTree
## Look-check of the fort's openable doors, windowed: the cabin's door shut and open, the inside of the cabin, and a blockhouse.
##   Godot --path . --resolution 1280x720 -s tests/building/fort_doors_shots.gd -- out=<abs dir>
var out := ""
var player: FrontierPlayer


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
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _view(from: Vector3, look: Vector3) -> void:
	player.global_position = from
	player.velocity = Vector3.ZERO
	var to := look - from
	player.yaw = atan2(-to.x, -to.z)
	player.rotation.y = player.yaw
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	await _frames(120)
	var st := current_scene.get_node("Structures") as FrontierStructures
	var cabin: BuildDoor = st.doors["cabin"]
	_view(Vector3(-8, 0.05, 12.5), Vector3(-8, 1.2, 9.5))
	await _shot("cabin_shut")
	cabin.set_open(true, true)
	await _frames(5)
	await _shot("cabin_open")
	_view(Vector3(-8, 0.05, 8.6), Vector3(-8, 1.4, 5.0))
	await _shot("cabin_inside")
	_view(Vector3(-8.0, 0.05, 6.0), Vector3(-8, 1.2, 9.5))
	await _shot("cabin_inside_door")
	var bh: BuildDoor = null
	for q in BuildWorld.of(self, false).pieces():
		if q.type == "blockhouse" and q.global_position.x < 0.0:
			bh = q.door
	bh.set_open(true, true)
	_view(Vector3(-14.8, 0.05, -9.5), Vector3(-14.8, 1.5, -13.75))
	await _shot("blockhouse_open")
	print("FORT DOOR SHOTS DONE ", out)
	quit()
