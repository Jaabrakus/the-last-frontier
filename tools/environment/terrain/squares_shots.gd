extends SceneTree
## Stills of the ground's squares (FrontierTerrain; user 2026-09-27: "add another square map thats open planes with a
## river to a lake"): the fort's woods giving onto the open land, the seam from above, the river's cut, the open land
## at eye height, and the two squares from high up; the river's water (RiverWater): from its bank, a bend from above,
## standing in it.
##   Godot --path . -s tools/environment/terrain/squares_shots.gd -- out=<dir>
## The window opens but draws nothing (OffscreenView renders off-window).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var out := "user://squares_shots"
var view


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	var p := lvl.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	if p.get("hud"):
		p.hud.visible = false
	var rig := lvl.get_node("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(11.0)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1280, 720)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1280, 720))
	root.disable_3d = true
	await _frames(120)
	var rx := _river_x(0.0)
	await _shot("1_woods_to_plains", _g(360.0, 24.0, 7.0), _g(520.0, 10.0, 3.0), 60.0)
	await _shot("2_seam_above", _g(360.0, -60.0, 70.0), _g(470.0, 20.0, 0.0), 60.0)
	await _shot("3_river_cut", _g(rx - 45.0, -30.0, 6.0), _g(rx, 10.0, -2.0), 55.0)
	await _shot("4_open_land", _g(640.0, 120.0, 1.7), _g(700.0, -60.0, 1.0), 65.0)
	await _shot("5_from_high", Vector3(416.0, 520.0, 820.0), Vector3(416.0, 0.0, 0.0), 55.0)
	# the river's water
	var z := -40.0
	var cx := WorldRiver.x_at(z)
	await _shot("6_river_bank", _g(cx + 15.0, z + 10.0, 1.7), Vector3(cx - 2.0, WorldRiver.level_at(z - 25.0), z - 25.0), 60.0)
	await _shot("7_river_bend", _g(cx + 30.0, z + 60.0, 22.0), Vector3(WorldRiver.x_at(z - 60.0), WorldRiver.level_at(z), z - 40.0), 55.0)
	await _shot("8_in_the_river", Vector3(cx + 2.0, WorldRiver.level_at(z) + 0.9, z + 3.0), Vector3(cx - 1.0, WorldRiver.level_at(z - 12.0) - 0.3, z - 14.0), 65.0)
	quit()


func _river_x(z: float) -> float:
	return 832.0 + 70.0 * sin(z / 140.0 + 0.4) + 25.0 * sin(z / 47.0 + 1.3)


func _g(x: float, z: float, up: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z) + up, z)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(nm: String, from: Vector3, at: Vector3, fov: float) -> void:
	view.source = null
	view.camera.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
	view.camera.fov = fov
	view.camera.far = 2500.0
	# the grass and the far chunks follow the camera: a few frames there before the still
	for i in 20:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var img: Image = view.get_texture().get_image()
	img.save_png(out.path_join(nm + ".png"))
	print("SHOT ", nm)
