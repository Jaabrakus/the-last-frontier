extends "res://tests/bending/test_clip_situations.gd"
## Matched arena-palette stills: fixed actors, cameras, mood and shader time.
## Godot --path . --fixed-fps 60 -s tools/ring/palette_shots.gd -- out=<new-dir>
## Captures the installed build; no runtime palette overrides or image retouching.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
var output_dir := "/private/tmp/tidebreak-palette-shots"
var capture_view: SubViewport


func _initialize() -> void:
	seed(1750)
	GameSettings.path = "user://tidebreak_palette_shots.cfg"
	MatchSetup._aim_help = "strong"
	MatchSetup.light = "noon"
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	physics_frame.connect(_physics)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_title("Palette comparison — still images")
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output_dir = arg.trim_prefix("out=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	el = "fire"
	if not await _scene(el):
		quit(1)
		return
	while bool(lvl.get_meta(&"loading_hold", false)):
		await process_frame
	await _reset("p", _at(-3.0), _deck_way(), false)
	foe.global_position = _at(4.0)
	await _secs(0.4)
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	capture_view = OffscreenView.new()
	capture_view.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(capture_view)
	capture_view.setup(root, Vector2i(1280, 720))
	root.disable_3d = true
	var rig := lvl.environment_rig
	rig.follow_camera = capture_view.camera
	rig.process_mode = Node.PROCESS_MODE_ALWAYS
	lvl.look.process_mode = Node.PROCESS_MODE_ALWAYS
	paused = true
	Engine.time_scale = 0.0
	var shots := {
		"behind": [_at(-6.5, 0.65, 2.25), _at(5.0, 0.0, 1.1), 62.0],
		"deck": [_at(-10.0, 6.0, 7.5), _at(1.0, 0.0, 0.5), 58.0],
		"sky": [_at(-6.5, 0.65, 1.9), _at(9.0, 0.0, 5.1), 62.0],
	}
	var rows: Array = []
	for shot: String in shots:
		var sh: Array = shots[shot]
		capture_view.camera.fov = sh[2]
		capture_view.camera.look_at_from_position(sh[0], sh[1])
		for settle in 40:
			await process_frame
			RenderingServer.force_draw(false)
		var img: Image = capture_view.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var filename := shot + ".png"
		img.save_png(output_dir.path_join(filename))
		var env := rig.get_environment()
		rows.append({"file": filename, "camera": str(capture_view.camera.global_transform),
			"fov": sh[2], "time_scale": Engine.time_scale, "sky_time": rig.clock_driver._sky_t,
			"hour": rig.clock_driver.clock.hour, "player_position": str(player.global_position),
			"foe_position": str(foe.global_position), "sun_energy": rig.get_sun().light_energy,
			"exposure": env.tonemap_exposure, "agx_contrast": env.tonemap_agx_contrast,
			"saturation": env.adjustment_saturation, "ambient": str(env.ambient_light_color)})
		print("PALETTE CAPTURE ", filename)
	FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
	print("PALETTE SHOTS DONE")
	quit(0)
