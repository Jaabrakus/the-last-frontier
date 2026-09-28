extends SceneTree
## Look-check stills of dragging a deer on foot (scripts/horse/foot_drag.gd); windowed, wrap it in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tests/horse/foot_drag_shots.gd -- out=<abs dir>
##
##   offer.png   at the doe's neck: "E  Drag the deer"
##   behind.png  the game's camera while dragging it, a torch in the right hand (evening)
##   side.png    from the left, mid-stride: the left arm back along the rope to the deer
##   night.png   from the right at night: the torch in the right hand the only light
##   hand.png    the left hand and the rope to the collar, close
##   sheet.png   all of them
## Ends with FOOT DRAG SHOTS DONE. The deer is a CC0 stand-in model.

const CELL := Vector2i(640, 360)

var out := ""
var shots: Array = []
var player: FrontierPlayer
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)      # the desk's keys stay out of it
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
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
		clock.set_time(18.2)
	var hs := current_scene.find_children("*", "Horse", true, false)
	if not hs.is_empty():
		(hs[0] as Horse).global_position = Vector3(-60.0, FrontierTerrain.height_at(-60.0, 60.0), 60.0)
	await _frames(120)
	# a doe shot in the field north of the fort
	var at := Vector3(24.0, 0.0, -46.0)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	var doe := WildAnimal.new()
	doe.setup("deer", null, null, 11)
	doe.name = "ShotDoe"
	current_scene.add_child(doe)
	doe.global_position = at
	doe.rotation.y = PI * 0.5
	doe._yaw = doe.rotation.y
	await _frames(3)
	doe.apply_hit(9999.0, doe.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	await _frames(200)
	var neck := CarcassLoad.neck_point(doe)
	var fwd := neck - doe.global_position              # from the body out past the head
	fwd.y = 0.0
	_put(neck + fwd.normalized() * 1.4 + fwd.normalized().cross(Vector3.UP) * 0.5, neck)
	player.pitch = deg_to_rad(-22.0)
	await _frames(40)
	await _shot("offer")
	# on the rope, a torch in the right hand, walked away north-east
	player.foot_drag.start(doe)
	await _frames(120)
	player.torch.take_out(true)
	await _frames(90)
	var dir := Vector3(0.6, 0.0, -1.0).normalized()
	player.yaw = atan2(-dir.x, -dir.z)
	player.pitch = deg_to_rad(-12.0)
	Input.action_press(&"move_forward")
	await _frames(300)
	await _shot("behind")
	await _side_shot("side", 4.6, 1.9, -1.0)
	if clock:
		clock.set_time(21.8)
	await _frames(150)
	await _side_shot("night", 4.4, 1.7)
	await _hand_shot("hand")
	Input.action_release(&"move_forward")
	_sheet()
	print("FOOT DRAG SHOTS DONE ", out)
	quit()


func _put(p: Vector3, look: Vector3) -> void:
	p.y = FrontierTerrain.height_at(p.x, p.z) + 0.05
	player.global_position = p
	player.velocity = Vector3.ZERO
	var d := look - p
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw


## From the player's right (`side` 1; -1 the left), `dist` out, at `h`, looking between the player and the deer.
func _side_shot(name: String, dist: float, h: float, side := 1.0) -> void:
	var fd := player.foot_drag
	var mid := player.global_position
	if fd.load:
		mid = player.global_position.lerp(fd.load.back, 0.45)
	var right := player.global_basis.x
	right.y = 0.0
	cam = Camera3D.new()
	cam.fov = 50.0
	current_scene.add_child(cam)
	cam.global_position = mid + right.normalized() * dist * side + Vector3.UP * h
	cam.look_at(mid + Vector3.UP * 0.8)
	cam.make_current()
	await _frames(2)
	await _shot(name)
	cam.queue_free()
	player.camera.make_current()


func _hand_shot(name: String) -> void:
	var fd := player.foot_drag
	var hp := fd.hitch_point()
	var right := player.global_basis.x
	right.y = 0.0
	var back := player.global_basis.z
	back.y = 0.0
	cam = Camera3D.new()
	cam.fov = 45.0
	current_scene.add_child(cam)
	cam.global_position = hp - right.normalized() * 1.4 + back.normalized() * 0.6 + Vector3.UP * 0.35
	cam.look_at(hp + back.normalized() * 0.6 + Vector3.DOWN * 0.2)
	cam.make_current()
	await _frames(2)
	await _shot(name)
	cam.queue_free()
	player.camera.make_current()


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	var cell := img.duplicate() as Image
	cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	shots.append(cell)
	print("saved ", name)


func _sheet() -> void:
	var cols := 3
	var rows := int(ceil(shots.size() / float(cols)))
	var grid := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		grid.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	grid.save_png(out.path_join("sheet.png"))
