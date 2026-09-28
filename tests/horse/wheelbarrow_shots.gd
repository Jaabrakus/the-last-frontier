extends SceneTree
## Look-check stills of the wheelbarrow (scripts/horse/wheelbarrow.gd); windowed, wrap it in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tests/horse/wheelbarrow_shots.gd -- out=<abs dir>
##
##   parked.png  standing by the start: "E  Push the wheelbarrow"
##   push.png    pushed empty, from the side: both hands on the grips, the wheel on the ground
##   deer.png    a doe in the bed, pushed
##   log.png     a log length in the bed, pushed
##   game.png    pushing, from the game's camera
##   screen.png  the chest screen on it: the pack beside the bed, Load / Unload everything
##   goods.png   stone, firewood and logs in the bed
##   goods_push.png  pushed with them
##   sheet.png   all of them
## Ends with WHEELBARROW SHOTS DONE. The deer is a CC0 stand-in; the barrow is the project's own.

const CELL := Vector2i(640, 360)

var out := ""
var shots: Array = []
var player: FrontierPlayer
var w: Wheelbarrow


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


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


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
		clock.set_time(15.0)
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Horse).global_position = _ground(-60.0, 60.0)
	await _frames(120)
	w = Wheelbarrow.find(self)
	# parked: the player at its handles
	var fwd := w.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var g := w.grips_point()
	_put(g - fwd * 0.9 - fwd.cross(Vector3.UP) * 0.5, w.bed_point())
	player.pitch = deg_to_rad(-20.0)
	await _frames(40)
	var sd := fwd.cross(Vector3.UP).normalized()
	await _cam("parked", w.bed_point() + sd * 3.2 + fwd * 1.6 + Vector3.UP * 1.4, w.bed_point() - fwd * 0.4)
	# pushed empty up the range lane (open ground)
	var lane := Vector3(0.0, 0.0, -1.0)
	w.park_at(_ground(2.5, -27.0), lane)
	await _take()
	await _walk(2.0, lane)
	Input.action_press(&"move_forward")
	await _frames(40)
	await _side("push", 3.6, 1.2)
	player.pitch = deg_to_rad(-28.0)
	await _frames(10)
	await _shot("game")
	Input.action_release(&"move_forward")
	await _frames(20)
	w.set_down("e")
	await _frames(60)
	# a doe in it
	var side := -w.global_basis.x
	side.y = 0.0
	var doe := WildAnimal.new()
	doe.setup("deer", null, null, 11)
	current_scene.add_child(doe)
	doe.global_position = _ground(w.bed_point().x, w.bed_point().z) + side.normalized() * 1.4
	await _frames(3)
	doe.apply_hit(9999.0, doe.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	await _frames(200)
	w.put_carcass(doe)
	await _take()
	Input.action_press(&"move_forward")
	await _frames(120)
	await _side("deer", 3.4, 1.4)
	Input.action_release(&"move_forward")
	await _frames(20)
	w.set_down("e")
	await _frames(40)
	w.tip_out()
	doe.queue_free()
	await _frames(20)
	# a log length in it
	var bp := w.bed_point()
	var s := SaveParts._loose_bole({"info": {"species": "white_pine", "name": "white pine", "radius": 0.2, "i": 9600, "pos": [bp.x, bp.y, bp.z]},
			"front": [bp.x + 3.0, bp.y, bp.z], "back": [bp.x + 5.4, bp.y, bp.z], "r0": 0.2, "r1": 0.18, "logs_total": 1, "logs_left": 1},
			GatherData.get_default().felling, true)
	current_scene.add_child(s)
	await _frames(20)
	w.put_log(s)
	await _take()
	Input.action_press(&"move_forward")
	await _frames(120)
	await _side("log", 3.8, 1.5)
	Input.action_release(&"move_forward")
	await _frames(20)
	w.set_down("e")
	await _frames(30)
	w.tip_out()
	await _frames(20)
	# the chest screen on it
	var inv := InventoryState.from_player(player)
	inv.add("stone", 6)
	inv.add("firewood", 4)
	inv.add("log", 3)
	player.inventory_pack = inv.pack.duplicate(true)
	inv = InventoryState.from_player(player)
	w.put(inv, "stone", 6)
	w.put(inv, "firewood", 4)
	w.put(inv, "log", 3)
	player.inventory_pack = inv.pack.duplicate(true)
	var sc := ChestScreen.open_for(player, w)
	await _frames(45)
	await _shot("screen")
	sc.close()
	await _frames(20)
	# what is in it shows in the bed, parked and pushed
	var bf := w.global_basis.z
	bf.y = 0.0
	bf = bf.normalized()
	var bs := bf.cross(Vector3.UP).normalized()
	await _cam("goods", w.bed_point() + bs * 1.8 + bf * 0.6 + Vector3.UP * 1.7, w.bed_point())
	await _take()
	Input.action_press(&"move_forward")
	await _frames(100)
	await _side("goods_push", 3.0, 2.3)
	Input.action_release(&"move_forward")
	_sheet()
	print("WHEELBARROW SHOTS DONE ", out)
	quit()


func _put(at: Vector3, look: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	var d := look - at
	d.y = 0.0
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw


func _take() -> void:
	var fwd := w.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var g := w.grips_point()
	_put(g - fwd * 0.45, g + fwd * 2.0)
	player.pitch = deg_to_rad(-12.0)
	await _frames(10)
	w.start(player)
	await _frames(90)


func _walk(secs: float, dir: Vector3) -> void:
	player.yaw = atan2(-dir.x, -dir.z)
	Input.action_press(&"move_forward")
	await _frames(int(secs * 60.0))
	Input.action_release(&"move_forward")


func _cam(name: String, at: Vector3, look: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 50.0
	current_scene.add_child(cam)
	cam.global_position = at
	cam.look_at(look)
	cam.make_current()
	await _frames(2)
	await _shot(name)
	cam.queue_free()
	player.camera.make_current()


func _side(name: String, dist: float, h: float) -> void:
	var mid := (player.global_position + w.global_position) * 0.5
	var right := player.global_basis.x
	right.y = 0.0
	var cam := Camera3D.new()
	cam.fov = 50.0
	current_scene.add_child(cam)
	cam.global_position = mid + right.normalized() * dist + Vector3.UP * h
	cam.look_at(mid + Vector3.UP * 0.6)
	cam.make_current()
	await _frames(2)
	await _shot(name)
	cam.queue_free()
	player.camera.make_current()


func _shot(name: String) -> void:
	await _frames(2)
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
