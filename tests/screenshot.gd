extends SceneTree
## Renders the level and saves screenshots (needs a window, not --headless).
##
##   Godot --path . -s tests/screenshot.gd -- --no-capture out=/tmp/shots weapon=musket
##
## Saves <out>/<weapon>_play.png (gameplay camera), _side.png and _front.png
## (close-ups of the character for checking weapon placement).

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://shots")
	DirAccess.make_dir_recursive_absolute(out)
	var weapons: PackedStringArray = String(args.get("weapon", "bow,musket,pistol")).split(",")
	var crouch: bool = args.get("crouch", "0") == "1"
	var aimed: bool = args.get("aim", "0") == "1"   # Hold aim (bow: draw) before the shots.

	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if crouch:
		Input.action_press("crouch")
		await _frames(2)
		Input.action_release("crouch")
	player.pitch = deg_to_rad(float(args.get("pitch", "0")))
	if args.get("held", "0") == "1":
		(player.weapons["bow"] as Bow).held = 3

	for w in weapons:
		player.switch_weapon(w)
		await _frames(90)
		# The graph weapon switch (holster, finish, grab, then the draw) can take 1-1.6 s.
		for i in 120:
			if not player.is_switching() and not player.weapon.is_equipping():
				break
			await _frames(1)
		var raise := "fire" if w == "bow" else "aim"
		if aimed:
			Input.action_press(raise)
			await _frames(90)
		var tag := w + ("_crouch" if crouch else "") + ("_aim" if aimed else "")
		await _shot(out + "/%s_play.png" % tag)
		var cam := Camera3D.new()
		cam.fov = 40
		current_scene.add_child(cam)
		var center := player.global_position + Vector3(0, 1.1, 0)
		for view: Array in [["side", Vector3(3.2, 0.3, 0)], ["front", Vector3(0.6, 0.4, -3.2)]]:
			cam.global_position = center + player.global_basis * view[1]
			cam.look_at(center)
			cam.current = true
			await _shot(out + "/%s_%s.png" % [tag, view[0]])
		cam.queue_free()
		player.camera.current = true
		if aimed:
			Input.action_release(raise)
			await _frames(60)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
