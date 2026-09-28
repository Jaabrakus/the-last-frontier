extends SceneTree
## Stills of a rapid for its look (RiverWater's white water; user 2026-09-28: the rapids "hard to see and doesnt make it
## look good"): the middle rapid from low on its bank beside it, from the bank 5 m up, from above at a slant, and its
## biggest boulder close from above, at 10:00 in October. Windowed:
##   Godot --path . -s tools/environment/water/rapid_shots.gd -- out=<dir> [tag=<name>]
## Writes <dir>/rapid_<view>_<tag>.jpg and <dir>/rapid_<tag>.jpg (the four one above another).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")


func _initialize() -> void:
	var out := "user://rapid_shots"
	var tag := "now"
	var hour := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
		elif a.begins_with("hour="):
			hour = float(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	var p := lvl.get_node("Player") as FrontierPlayer
	var rig := lvl.get_node("EnvironmentRig") as EnvironmentRig
	rig.clock_driver.clock.running = false
	rig.clock_driver.clock.set_time(hour)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(960, 540))
	root.disable_3d = true
	view.camera.fov = 55.0
	view.camera.far = 3000.0
	var r: Dictionary = WorldRiver.rapids()[1]
	var rz := float(r.z)
	var edge := WorldRiver.x_at(rz)
	while WorldRiver.surface_at(edge + 0.25, rz) != WorldRiver.NO_WATER and edge < WorldRiver.x_at(rz) + 14.0:
		edge += 0.25
	var lv := WorldRiver.level_at(rz)
	var cx := WorldRiver.x_at(rz)
	# the biggest boulder of the rapid, close
	var rock := Vector3(cx, lv, rz)
	var best := 0.0
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/river_boulders.json"))
	for b: Array in (d as Dictionary).get("boulders", []):
		if absf(float(b[1]) - rz) < float(r.length) * 0.5 and float(b[2]) > best:
			best = float(b[2])
			rock = Vector3(float(b[0]), lv, float(b[1]))
	p.global_position = Vector3(cx + 60.0, FrontierTerrain.height_at(cx + 60.0, rz + 40.0) + 0.1, rz + 40.0)
	var views := [
		["low", Vector3(edge + 1.5, lv + 1.3, rz + 7.0), Vector3(cx - 1.0, lv + 0.2, rz - 3.0)],
		["bank", Vector3(edge + 4.0, lv + 5.0, rz + 16.0), Vector3(cx - 2.0, lv, rz - 6.0)],
		["above", Vector3(cx + 10.0, lv + 14.0, rz + 18.0), Vector3(cx, lv, rz - 2.0)],
		["rock", Vector3(rock.x + 3.0, lv + 6.5, rock.z + 9.0), Vector3(rock.x, lv, rock.z + 3.0)],
	]
	var imgs: Array[Image] = []
	for v in views:
		view.camera.global_transform = Transform3D(Basis.looking_at((v[2] as Vector3) - (v[1] as Vector3), Vector3.UP), v[1])
		for i in 90:
			await process_frame
		var img: Image = view.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out.path_join("rapid_%s_%s.jpg" % [v[0], tag]), 0.88)
		imgs.append(img)
	var sheet := Image.create(960, 540 * imgs.size(), false, Image.FORMAT_RGB8)
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(0, 0, 960, 540), Vector2i(0, 540 * i))
	sheet.save_jpg(out.path_join("rapid_%s.jpg" % tag), 0.85)
	print("RAPID SHOTS DONE ", tag)
	quit()
