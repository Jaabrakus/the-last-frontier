extends SceneTree
## Stills of the start-with-nothing crafting for its look: the knapping stone (BuildGeometry._work_stone) at the
## wood's edge beside a campfire, close and from standing height. Windowed:
##   Godot --path . --resolution 1280x720 -s tools/survival/craft_shots.gd -- out=<dir> [at=x,z] [hour=11]

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var view
var out := "user://craft_shots"
var at := Vector3(-34.0, 0.0, 30.0)
var hour := 11.0
var imgs: Array[Image] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("at="):
			var xz := a.substr(3).split(",")
			at = Vector3(float(xz[0]), 0.0, float(xz[1]))
		elif a.begins_with("hour="):
			hour = float(a.substr(5))
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
	rig.clock_driver.clock.running = false
	rig.clock_driver.clock.set_time(hour)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(960, 540))
	root.disable_3d = true
	view.camera.fov = 45.0
	var pp := at + Vector3(0.0, 0.0, 14.0)
	pp.y = FrontierTerrain.height_at(pp.x, pp.z) + 0.05
	p.global_position = pp
	for i in 60:
		await process_frame
	var world := BuildWorld.of(self)
	var q := at
	q.y = FrontierTerrain.height_at(q.x, q.z)
	world.add_piece("work_stone", Transform3D(Basis(Vector3.UP, 0.4), q), true, -1)
	var f := at + Vector3(1.6, 0.0, -0.4)
	f.y = FrontierTerrain.height_at(f.x, f.z)
	world.add_piece("campfire", Transform3D(Basis(), f), true, -1)
	var m := at + Vector3(-4.0, 0.0, -1.0)
	m.y = FrontierTerrain.height_at(m.x, m.z)
	world.add_piece("charcoal_mound", Transform3D(Basis(), m), true, -1)
	var g := at + Vector3(4.5, 0.0, -1.5)
	g.y = FrontierTerrain.height_at(g.x, g.z)
	world.add_piece("forge", Transform3D(Basis(Vector3.UP, -0.3), g), true, -1)
	for i in 30:
		await process_frame
	await _shot(q + Vector3(0.9, 0.9, 1.1), q + Vector3(0.0, 0.25, 0.0))
	await _shot(q + Vector3(-1.6, 1.7, 2.6), q + Vector3(0.6, 0.15, -0.2))
	await _shot(m + Vector3(1.6, 1.4, 2.8), m + Vector3(0.0, 0.4, 0.0))
	await _shot(g + Vector3(0.6, 1.6, 3.2), g + Vector3(0.2, 0.6, 0.0))
	await _shot(g + Vector3(-2.6, 1.5, -2.2), g + Vector3(0.2, 0.6, 0.0))
	await _shot(q + Vector3(0.5, 2.6, 8.5), q + Vector3(0.3, 0.3, -1.0))
	var sheet := Image.create(960 * 2, 540 * 3, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
	sheet.save_png(out.path_join("work_stone.png"))
	print("CRAFT SHOTS DONE")
	quit()


func _shot(from: Vector3, look: Vector3) -> void:
	view.camera.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	for i in 12:
		await process_frame
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	imgs.append(img)
