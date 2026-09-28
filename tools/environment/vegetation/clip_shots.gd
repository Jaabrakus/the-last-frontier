extends SceneTree
## Close-up screenshots of individual spots of the level (clipping before / after pictures,
## 2026-09-25). Needs a window (not --headless); wrap it in a time limit:
##
##   Godot --path . --resolution 960x540 -s tools/environment/vegetation/clip_shots.gd -- --no-capture \
##       views=<json> out=<dir> [prefix=<tag>_] [settle=40] [veg_clip_fix=0]
##
## views = a JSON list of [name, [x, dy, z], [x, dy, z], fov]: camera and look-at target, each at
## dy metres over the terrain at (x, z) (FrontierTerrain.height_at). Renders like scenic_shots.gd
## (off-window SubViewport, game input unbound) and saves <out>/<prefix><name>.png. Pass
## veg_clip_fix=0 to see the vegetation layout without its clipping clean-up pass
## (scripts/world/vegetation/veg_layout.gd).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://clip_shots")
	var prefix: String = args.get("prefix", "")
	var settle := int(args.get("settle", "40"))
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(String(args.get("views", "")), FileAccess.READ)
	var views: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if not views is Array:
		printerr("clip_shots: views=<json list> missing")
		quit(1)
		return

	OS.low_processor_usage_mode_sleep_usec = 0
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player.hud:
		player.hud.visible = false
	# Park the player far from every close-up (it would stand in some of them).
	player.global_position = Vector3(0, 0.1, 6)
	var view := OffscreenView.new()
	view.name = "ClipView"
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	var cam: Camera3D = view.camera
	var rig := current_scene.get_node_or_null("EnvironmentRig")
	if rig and "follow_camera" in rig:
		rig.follow_camera = cam
	if rig and rig.has_method("get_camera_attributes") and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(90)
	for v: Array in views:
		var p := _ground(v[1])
		var t := _ground(v[2])
		cam.fov = float(v[3])
		cam.global_position = p
		cam.look_at(t)
		await _frames(settle)
		view.sync_camera()
		RenderingServer.force_draw(false)
		var img: Image = view.get_texture().get_image()
		var path := out.path_join("%s%s.png" % [prefix, v[0]])
		img.save_png(path)
		print("saved ", path)
	print("CLIP SHOTS DONE")
	quit()


func _ground(a: Array) -> Vector3:
	var x := float(a[0])
	var z := float(a[2])
	return Vector3(x, FrontierTerrain.height_at(x, z) + float(a[1]), z)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
