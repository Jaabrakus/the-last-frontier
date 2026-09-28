extends SceneTree
## Look-check stills of the torch mode (PlayerInteractor.begin_torch_place, PlayerTorch.set_down / throw_at), at dusk
## from the game's camera; windowed, wrap it in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tests/interact/torch_set_shots.gd -- out=<abs dir>
##
##   ghost.png    a double tap of T: the ghost torch at arm's length, "Click  Push the torch into the ground"
##   set.png      clicked: the torch standing in the ground, burning; the player stepped back
##   arc.png      a tap of T in the mode: the throw's arc and ring
##   windup_side.png, release_side.png   the right arm wound up in the throw mode, and mid-throw, from the side
##   thrown.png   clicked: the torch where it came down, burning
##   arc_left.png, windup_left_side.png, release_left_side.png   the same from the left hand (the pistol out)
##   wall.png     wedged in the palisade, burning
## Ends with TORCH SET SHOTS DONE.

var out := ""
var player: FrontierPlayer
var it: PlayerInteractor
var pt: PlayerTorch


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


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(4)
	Input.action_release(action)
	await _frames(4)


func _double_t() -> void:
	await _tap(PlayerTorch.ACTION)
	await _frames(3)
	await _tap(PlayerTorch.ACTION)
	await _frames(10)


func _in_hand() -> void:
	for i in 300:
		await process_frame
		if pt.holding() and not pt.pending:
			break
	await _frames(20)


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name, "  mode '", it.torch_mode, "'  prompt '", it._label.text, "'  more '", it._more.text, "'")


## A still from beside the player (the arm's throw seen side on), the game's camera put back after.
func _side(name: String) -> void:
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	var b := player.global_basis
	var chest := player.global_position + Vector3.UP * 1.3
	cam.global_position = chest + b.x * 2.6 + Vector3.UP * 0.3 - b.z * 0.6
	cam.look_at(chest - b.z * 0.4, Vector3.UP)
	cam.current = true
	await _shot(name)
	cam.current = false
	cam.queue_free()
	if player.camera:
		player.camera.current = true


## The throw from the mode as it stands: the side view wound up, then the click and the side view mid-throw.
func _throw_frames(suffix: String) -> void:
	await _frames(20)
	await _side("windup" + suffix + "_side")
	Input.action_press(&"fire")
	await create_timer(0.14).timeout
	await _side("release" + suffix + "_side")
	Input.action_release(&"fire")
	await create_timer(3.0).timeout


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	it = player.interactor
	pt = player.torch
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
		clock.set_time(20.2)
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Horse).global_position = _ground(Vector3(-60.0, 0, 60.0))
	await _frames(120)
	var at := Vector3(24.0, 0, 12.0)
	_put(at, at + Vector3(0, 0, -5))
	player.pitch = deg_to_rad(-14.0)
	await _tap(PlayerTorch.ACTION)
	await _in_hand()
	await _double_t()
	await _shot("ghost")
	await _tap(&"fire")
	await _frames(30)
	var set_t := pt.last_dropped
	# stepped back to see it
	if set_t:
		_put(at + Vector3(1.6, 0, 1.4), set_t.global_position)
		player.pitch = deg_to_rad(-12.0)
	await _frames(40)
	await _shot("set")
	if set_t:
		set_t.interact(player)
		await _in_hand()
	# throwing
	_put(at, at + Vector3(0, 0, -5))
	player.pitch = deg_to_rad(-15.0)
	await _frames(20)
	await _double_t()
	await _tap(PlayerTorch.ACTION)
	await _frames(10)
	await _shot("arc")
	await _throw_frames("")
	await _shot("thrown")
	var th := pt.last_dropped
	if th:
		th.interact(player)
		await _in_hand()
	# the left hand: the pistol out
	player.switch_weapon("pistol")
	await create_timer(1.8).timeout
	_put(at, at + Vector3(0, 0, -5))
	player.pitch = deg_to_rad(-15.0)
	await _frames(20)
	await _double_t()
	await _tap(PlayerTorch.ACTION)
	await _frames(10)
	await _shot("arc_left")
	await _throw_frames("_left")
	var tl := pt.last_dropped
	if tl:
		tl.interact(player)
		await _in_hand()
	player.switch_weapon("musket")
	await create_timer(1.8).timeout
	# the palisade: found to the west of the spot
	var from := _ground(Vector3(21.0, 0, 9.0)) + Vector3.UP * 1.4
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(-12, 0, 0))
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var wp: Vector3 = hit.position
		_put(wp + Vector3(1.4, 0, 0), wp)
		player.pitch = deg_to_rad(-2.0)
		await _frames(30)
		await _double_t()
		print("  wall: ", it.place.get("what", "(none)"), " at ", wp, " ", hit.collider)
		await _tap(&"fire")
		await _frames(30)
		var wt := pt.last_dropped
		if wt:
			_put(wp + Vector3(3.2, 0, 2.2), wt.global_position)
			player.pitch = deg_to_rad(4.0)
		await _frames(40)
		await _shot("wall")
	print("TORCH SET SHOTS DONE")
	quit(0)
