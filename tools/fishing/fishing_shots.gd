extends SceneTree
## Stills of the fishing for its look (FishingGear): the player on the river's bank with the rod ready, back over the
## shoulder in the cast, and with the float out drifting, from the side and from behind. Windowed:
##   Godot --path . -s tools/fishing/fishing_shots.gd -- out=<dir> [tag=<name>]

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var view
var p: FrontierPlayer
var g: FishingGear
var out := "user://fishing_shots"
var tag := "now"
var imgs: Array[Image] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	p = lvl.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	if p.get("hud"):
		p.hud.visible = false
	var rig := lvl.get_node("EnvironmentRig") as EnvironmentRig
	rig.clock_driver.clock.running = false
	rig.clock_driver.clock.set_time(16.0)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(960, 540))
	root.disable_3d = true
	view.camera.fov = 50.0
	var z := -140.0
	var cx := WorldRiver.x_at(z)
	var edge := cx
	while WorldRiver.surface_at(edge + 0.25, z) != WorldRiver.NO_WATER and edge < cx + 14.0:
		edge += 0.25
	var at := Vector3(edge + 1.2, 0.0, z)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	p.global_position = at
	p.rotation.y = atan2(1.0, 0.0)     # facing -X: the water
	p.yaw = p.rotation.y
	for i in 30:
		await process_frame
	g = FishingGear.find(p)
	g.give("fishing_rod")
	g.take_out("fishing_rod")
	for i in 40:
		await process_frame
	var pp := p.global_position
	await _shot(pp + Vector3(0.5, 1.2, 4.2), pp + Vector3(-1.0, 1.2, 0.0))          # side, ready
	await _shot(pp + Vector3(3.6, 2.0, 0.6), pp + Vector3(-4.0, 0.6, -0.3))         # behind, ready
	# back over the shoulder
	g.aim_override = Vector3(cx + 1.0, 0.0, z - 1.0)
	g.fire_override = 1
	for i in 40:
		await process_frame
	await _shot(pp + Vector3(0.5, 1.2, 4.2), pp + Vector3(-1.0, 1.4, 0.0))          # side, wound up
	g.fire_override = 0
	for i in 70:
		await process_frame
	await _shot(pp + Vector3(3.6, 2.2, 0.6), pp + Vector3(-5.0, 0.0, -0.8))         # behind, drifting
	await _shot(pp + Vector3(-2.0, 1.4, 5.5), pp + Vector3(-5.0, -0.3, -1.0))       # the float, from the side
	var sheet := Image.create(960 * 2, 540 * 3, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
	sheet.save_jpg(out.path_join("fishing_%s.jpg" % tag), 0.85)
	print("FISHING SHOTS DONE ", tag, " state ", FishingGear.Rod.keys()[g.rod_state])
	quit()


func _shot(from: Vector3, at: Vector3) -> void:
	view.camera.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
	for i in 6:
		await process_frame
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	imgs.append(img)
