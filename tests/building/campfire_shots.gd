extends SceneTree
## Look-check stills of the camp pieces (windowed; wrap it in a time limit):
##
##   Godot --path . --resolution 1280x720 -s tests/building/campfire_shots.gd -- --no-capture out=<dir>
##
## A lean-to facing a campfire, placed through build mode east of the fort: unlit at the golden hour, burning at
## night. Ends with CAMPFIRE SHOTS DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var out := "user://campfire_shots"
var view: OffscreenView
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
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


func _shot(name: String, pos: Vector3, target: Vector3, settle := 40) -> void:
	var cam: Camera3D = view.camera
	view.source = null
	cam.fov = 55.0
	for i in settle:
		cam.global_position = pos
		cam.look_at(target)
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
	view.sync_camera()
	RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", out.path_join(name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	if player.hud:
		player.hud.visible = false
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	var rig := current_scene.get_node("EnvironmentRig") as EnvironmentRig
	var clock: WorldClock = rig.clock_driver.clock if rig.clock_driver else null
	if rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	var inv := InventoryState.from_player(player)
	for k in [["stone", 6], ["firewood", 6], ["pole", 5], ["branches", 10]]:
		inv.add(k[0], k[1])
	player.inventory_pack = inv.pack.duplicate(true)
	var mode := player.get_node("BuildMode") as BuildMode
	var spot := Vector3(21.0, 0.0, 6.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	player.global_position = spot + Vector3(2.5, 0.1, 0.5)
	await _frames(30)
	var pieces := []
	for e in [["campfire", spot], ["lean_to", spot + Vector3(0, 0, -3.3)]]:
		mode.set_active(true)
		mode.select_type(e[0])
		mode.aim_at = e[1]
		await _frames(8)
		mode.refresh_placement()
		pieces.append(mode.place())
		if pieces[-1] == null:
			print("  not placed: %s (%s)" % [e[0], mode.verdict.get("reason", "")])
		mode.set_active(false)
	mode.aim_at = Vector3.INF
	player.global_position = spot + Vector3(-6.0, 0.1, 5.0)
	var cf := (pieces[0] as BuiltPiece).get_node("Campfire") as Campfire
	var cam := spot + Vector3(3.2, 1.5, 3.4)
	await _frames(90)
	await _shot("camp_day_unlit", cam, spot + Vector3(0, 0.5, -1.2))
	if clock:
		clock.set_time(21.0)
	cf.light()
	await _frames(240)
	await _shot("camp_night_lit", cam, spot + Vector3(0, 0.5, -1.2))
	await _shot("camp_night_wide", spot + Vector3(9.0, 2.5, 8.0), spot + Vector3(0, 0.6, -1.0))
	print("CAMPFIRE SHOTS DONE")
	quit()
