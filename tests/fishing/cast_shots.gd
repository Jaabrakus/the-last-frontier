extends SceneTree
## Look-check stills of the rod's cast (FishingGear; user 2026-09-28: "the fishing cast is the attack musket animations
## left right up and then held in the up attack two hands lower", "should be a throw cast arc for fishing"), on the
## river's bank east of the fort; windowed, wrap it in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tests/fishing/cast_shots.gd -- out=<abs dir>
##
##   hold_side.png              the rod out over the water in both hands, low (own-rod-hold)
##   <W|A|D>_windup_side.png    the cast wound up (the button held), from the side
##   <W|A|D>_arc.png            the same from the game's camera: the arc and the ring it comes down within
##   <W|A|D>_swing_side.png     let go: the swing through
##   <W|A|D>_drift_side.png     the float out, the rod back in the hold
##   sheet.png                  all of them
## Each shot prints the rod's way against the player's facing. Ends with CAST SHOTS DONE. The swings and the rod's
## poses are the project's own clips (Frontier_Own.res).

const CELL := Vector2i(480, 270)

var out := ""
var p: FrontierPlayer
var g: FishingGear
var shots: Array[Image] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	var c := img.duplicate() as Image
	c.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	shots.append(c)
	var fwd := -p.global_basis.z
	var d := g.rod_dir()
	print("  shot ", name, "  state ", FishingGear.Rod.keys()[g.rod_state], "  rod . forward %.2f  rod up %.2f  butt %s tip %s player %s" % [d.dot(fwd), d.y, g.rod_transform().origin, g.tip_point(), p.global_position])


## From the player's side (the rod's swing seen side on), the game's camera put back after.
func _side(name: String) -> void:
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	var b := p.global_basis
	var chest := p.global_position + Vector3.UP * 1.3
	cam.global_position = chest + b.x * 4.2 + Vector3.UP * 0.6 + b.z * 1.2
	cam.look_at(chest - b.z * 1.4 + Vector3.UP * 0.3, Vector3.UP)
	cam.current = true
	await _shot(name)
	cam.current = false
	cam.queue_free()
	p.camera.current = true


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		c.queue_free()
	paused = false
	var rig := current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(10.5)
	if rig and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(60)
	g = FishingGear.find(p)
	# on the bank, the water to the west (-X), as tests/fishing/test_fishing.gd stands
	var z := -140.0
	var cx := WorldRiver.x_at(z)
	var o := 0.0
	while WorldRiver.depth_at(Vector3(cx + o + 0.25, WorldRiver.level_at(z), z)) > 0.0 and o < 14.0:
		o += 0.25
	var at := Vector3(cx + o + 1.2, 0.0, z)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	p.global_position = at
	p.rotation.y = atan2(1.0, 0.0)
	p.yaw = p.rotation.y
	p.pitch = deg_to_rad(-12.0)
	await _frames(240)
	g.give("fishing_rod")
	g.take_out("fishing_rod")
	await _frames(60)
	await _side("hold_side")
	for dir in ["W", "A", "D"]:
		g.cast_override = dir
		g.aim_override = Vector3(cx - 1.5, 0.0, z - 1.0)
		g.fire_override = 1
		await _frames(50)
		await _side(dir + "_windup_side")
		await _shot(dir + "_arc")
		g.fire_override = 0
		await _frames(4)
		await _side(dir + "_swing_side")
		await _frames(90)
		await _side(dir + "_drift_side")
		# lift the float out for the next cast
		g.fire_override = 1
		await _frames(3)
		g.fire_override = 0
		await _frames(60)
	var cols := 4
	var rows := int(ceil(shots.size() / float(cols)))
	var grid := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		var c := shots[i]
		c.convert(Image.FORMAT_RGB8)
		grid.blit_rect(c, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	grid.save_png(out.path_join("sheet.png"))
	print("CAST SHOTS DONE")
	quit(0)
