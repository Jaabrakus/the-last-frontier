extends SceneTree
## The fort's furnishing (FortPlan), windowed: what was built, what was left out, and a look from above and from the
## parade ground.
##   Godot --path . --resolution 1280x720 -s tests/building/fort_plan_shots.gd -- out=<abs dir> fort_plan=on
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
	await _frames(200)
	var world := BuildWorld.of(self, false)
	var counts := {}
	for p in world.pieces():
		counts[p.type] = int(counts.get(p.type, 0)) + 1
	print("pieces: ", world.pieces().size(), " ", counts, " stamped ", world.stamped)
	_view(Vector3(0, 9.0, 24.0), Vector3(0, 0, 4.0))
	await _shot("above")
	_view(Vector3(-6, 1.7, 13.0), Vector3(2, 1.2, 12.0))
	await _shot("workshop")
	_view(Vector3(6.0, 1.7, 3.0), Vector3(1.0, 0.8, 0.0))
	await _shot("hearth")
	_view(Vector3(-9.0, 1.7, -2.0), Vector3(-14.0, 0.6, -3.5))
	await _shot("barracks")
	print("FORT PLAN SHOTS DONE ", out)
	quit()
