extends SceneTree
## Stills of the Tidebreak ring for its look (scenes/ring.tscn; the owner judges by eye): from high over a corner, from the
## player's spawn down the deck, from the stands across it, from over the water at an open end, and close on a grate and a
## socket's stone, at the ring's noon. Windowed (it draws):
##   Godot --path . -s tools/ring/ring_shots.gd -- out=<dir> [tag=<name>]
## Writes <dir>/ring_<view>_<tag>.png and <dir>/ring_sheet_<tag>.png (the views two by two... and the last).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const W := 1280
const H := 720


func _initialize() -> void:
	var out := "user://ring_shots"
	var tag := "now"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene as RingLevel
	var ring := lvl.ring
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	view.camera.fov = 60.0
	view.camera.far = 1500.0
	var views := [
		["over", Vector3(-30.0, 15.0, 21.0), Vector3(0.0, -1.0, 0.0)],
		["spawn", Vector3(-6.4, 2.0, 0.6), Vector3(12.0, 0.2, -0.4)],
		["stands", Vector3(1.0, 4.6, 19.5), Vector3(1.0, -0.6, -2.0)],
		["end", Vector3(23.0, 1.6, 9.0), Vector3(9.0, -0.8, -1.5)],
		["grate", Vector3(-4.6, 1.7, 7.4), Vector3(-6.4, -0.2, 4.4)],
	]
	var imgs: Array[Image] = []
	for v in views:
		view.camera.global_transform = Transform3D(Basis.looking_at((v[2] as Vector3) - (v[1] as Vector3), Vector3.UP), v[1])
		for i in 90:
			await process_frame
		var img: Image = view.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(out.path_join("ring_%s_%s.png" % [v[0], tag]))
		imgs.append(img)
	var cols := 2
	var rows := ceili(imgs.size() / float(cols))
	var hw := W / 2
	var hh := H / 2
	var sheet := Image.create(hw * cols, hh * rows, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var small := imgs[i].duplicate() as Image
		small.resize(hw, hh, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(small, Rect2i(0, 0, hw, hh), Vector2i((i % cols) * hw, (i / cols) * hh))
	sheet.save_png(out.path_join("ring_sheet_%s.png" % tag))
	print("RING SHOTS DONE ", tag, " ", ring != null)
	quit()
