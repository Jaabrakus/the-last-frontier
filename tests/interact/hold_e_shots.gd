extends SceneTree
## Look-check stills of the hold-E list (scripts/interact/player_interactor.gd), from the game's camera; windowed, wrap
## it in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tests/interact/hold_e_shots.gd -- out=<abs dir>
##
##   prompt.png   by the wheelbarrow with a dead doe beside it, looking at her: the tap's prompt, "Hold E: n more"
##   list.png     E held: the list, putting the musket down first (its placement showing)
##   pick.png     the wheel down twice: that row chosen, its thing glowing
##   fire.png     hands free at a lit campfire, E held: add firewood / smother the fire
## Ends with HOLD E SHOTS DONE. The deer is a CC0 stand-in; the barrow is the project's own.

var out := ""
var player: FrontierPlayer
var it: PlayerInteractor


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)      # the desk's keys stay out of it
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


func _put(at: Vector3, look: Vector3) -> void:
	at = _ground(at) + Vector3(0, 0.05, 0)
	player.global_position = at
	player.velocity = Vector3.ZERO
	var d := look - at
	d.y = 0.0
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw


func _key(action: StringName) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await _frames(3)


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name, "  rows ", it.menu.map(func(r: Dictionary) -> String: return String(r.text)),
			"  prompt '", it._label.text, "'  more '", it._more.text, "'")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	it = player.interactor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	var rig := current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	var clock: WorldClock = rig.clock_driver.clock if rig and rig.clock_driver else null
	if rig and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	if clock:
		clock.set_time(15.0)
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Horse).global_position = _ground(Vector3(-60.0, 0, 60.0))
	await _frames(120)
	var w := Wheelbarrow.find(self)
	w.park_at(_ground(Vector3(2.5, 0, -27.0)), Vector3(0, 0, -1))
	await _frames(10)
	var side := -w.global_basis.x
	side.y = 0.0
	side = side.normalized()
	var doe := WildAnimal.new()
	doe.setup("deer", null, null, 11)
	current_scene.add_child(doe)
	doe.global_position = _ground(w.bed_point() + side * 1.3)
	await _frames(2)
	doe.apply_hit(9999.0, doe.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	await _frames(200)
	# at her side of the barrow, looking down at her
	var fwd := w.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	_put(w.bed_point() + side * 2.2 - fwd * 0.6, doe.global_position)
	player.pitch = deg_to_rad(-36.0)
	await _frames(60)
	await _shot("prompt")
	Input.action_press(&"interact")
	await _frames(40)
	await _shot("list")
	await _key(&"weapon_next")
	await _key(&"weapon_next")
	await _shot("pick")
	await _key(&"aim")
	Input.action_release(&"interact")
	await _frames(10)
	# a lit campfire, hands free
	var inv := InventoryState.from_player(player)
	inv.add("stone", 6)
	inv.add("firewood", 6)
	player.inventory_pack = inv.pack.duplicate(true)
	var mode := player.get_node_or_null("BuildMode") as BuildMode
	var fire_at := _ground(Vector3(21.0, 0, 6.0))
	_put(fire_at + Vector3(0, 0, 3.0), fire_at)
	await _frames(10)
	mode.set_active(true)
	mode.select_type("campfire")
	mode.aim_at = fire_at
	await _frames(6)
	mode.refresh_placement()
	var fp := mode.place()
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	var cf := fp.get_node_or_null("Campfire") as Campfire if fp else null
	if cf:
		cf.interact(player)
	player.toggle_hands_free()
	await _frames(120)
	_put(fire_at + Vector3(0.3, 0, 1.7), fire_at)
	player.pitch = deg_to_rad(-30.0)
	await _frames(40)
	Input.action_press(&"interact")
	await _frames(40)
	await _shot("fire")
	Input.action_release(&"interact")
	print("HOLD E SHOTS DONE")
	quit(0)
