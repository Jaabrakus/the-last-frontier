extends SceneTree
## Look-check stills of limbing, pulling a log on foot and a log barricade (GatherTools' Limb, LogPull); windowed,
## wrap it in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tests/horse/log_pull_shots.gd -- out=<abs dir>
##
##   felled.png      a felled pine with its crown
##   limbed.png      the same limbed: a bare log, the chips
##   pull_side.png   pulling a log backward, both hands on the rope (from the side)
##   pull_game.png   the same from the game's camera
##   crouch.png      a three-high barricade, the player crouched behind it (from in front of it)
##   aim.png         standing behind it, the musket aimed over it
##   sheet.png       all of them
## Ends with LOG PULL SHOTS DONE. The trees and logs are the project's own models.

const CELL := Vector2i(640, 360)

var out := ""
var shots: Array = []
var player: FrontierPlayer
var lp: LogPull


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
	lp = player.log_pull
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
		clock.set_time(12.0)
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Horse).global_position = _ground(-60.0, 60.0)
	await _frames(120)
	await _limb_shots()
	await _pull_shots()
	await _barricade_shots()
	_sheet()
	print("LOG PULL SHOTS DONE ", out)
	quit()


# --- Limbing -------------------------------------------------------------------------------------------------

func _limb_shots() -> void:
	var vh := VegHarvest.find(self)
	var best := -1
	var bd := INF
	for i in vh.lay.tree_pos.size():
		if int(vh.lay.tree_kind[i]) >= VegHarvest.Assets.CANOPY_COUNT or vh.lay.tree_collider[i] == 0:
			continue
		var p: Vector3 = vh.lay.tree_pos[i]
		if absf(p.x) < 35.0 and absf(p.z) < 35.0:
			continue
		var d := vh.describe("tree", "tree", i)
		if d.is_empty() or String(d.get("species", "")) != "white_pine" or float(d.radius) > 0.3:
			continue
		var dist := Vector2(p.x, p.z).length()
		if dist < bd:
			bd = dist
			best = i
	var desc := vh.describe("tree", "tree", best)
	var got := [null]
	var cb := func(ft: FelledTree) -> void: got[0] = ft
	player.gather.felled.connect(cb)
	player.global_position = desc.pos + Vector3(1.3, 0.1, 0.3)
	await _frames(2)
	player.gather._fell(desc)
	player.gather.felled.disconnect(cb)
	var ft: FelledTree = got[0]
	for k in 60 * 10:
		await process_frame
		if ft.is_down():
			break
	await _frames(60)
	var mid := ft.hinge + ft.axis() * ft.length * 0.55
	var side := ft.axis().cross(Vector3.UP).normalized()
	player.global_position = _ground(mid.x, mid.z) + side * 2.2 + Vector3.UP * 0.1
	player.yaw = atan2(side.x, side.z)
	player.rotation.y = player.yaw
	var cam_at := mid + side * 4.5 + Vector3.UP * 7.5 - ft.axis() * 1.0
	await _cam_shot("felled", cam_at, mid + Vector3.UP * 0.2)
	player.gather.limb(ft)
	await _frames(20)
	await _cam_shot("limbed", cam_at, mid + Vector3.UP * 0.2)


# --- Pulling -------------------------------------------------------------------------------------------------

func _log(a: Vector3, dir: Vector3, L: float, r: float) -> SkidLoad:
	var d := dir.normalized()
	var f := Vector3(a.x, FrontierTerrain.height_at(a.x, a.z) + r, a.z)
	var b := f + d * L
	b.y = FrontierTerrain.height_at(b.x, b.z) + r
	var s := SaveParts._loose_bole({"info": {"species": "white_pine", "name": "white pine", "radius": r, "i": 9000 + randi() % 1000,
			"pos": [a.x, a.y, a.z]}, "front": [f.x, f.y, f.z], "back": [b.x, b.y, b.z], "r0": r, "r1": r * 0.92,
			"logs_total": 1, "logs_left": 1}, GatherData.get_default().felling, true)
	current_scene.add_child(s)
	return s


func _pull_shots() -> void:
	var s := _log(_ground(26.0, -40.0), Vector3(0, 0, -1), 2.4, 0.24)
	await _frames(60)
	player.global_position = s.front + Vector3(0, 0.1, 1.4)
	var d := s.front - player.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	await _frames(20)
	lp.start(s, 0)
	await _frames(130)
	player.yaw = player.rotation.y
	player.pitch = deg_to_rad(-10.0)
	Input.action_press(&"move_back")
	await _frames(200)
	var mid := (player.global_position + s.front) * 0.5
	var right := player.global_basis.x
	right.y = 0.0
	await _cam_shot("pull_side", mid + right.normalized() * 4.2 + Vector3.UP * 1.5, mid + Vector3.UP * 0.7, false)
	await _shot("pull_game")
	Input.action_release(&"move_back")
	await _frames(30)
	lp.lay()
	await _frames(120)
	s.queue_free()


# --- The barricade -------------------------------------------------------------------------------------------

func _barricade_shots() -> void:
	var at := _ground(20.0, -52.0)
	var ax := Vector3(1, 0, 0)
	var side := Vector3(0, 0, 1)            # the player's side of it (+Z, toward the fort)
	var logs: Array[SkidLoad] = []
	for k in 3:
		var n := _log(at + side * (0.0 if k == 0 else 0.6), ax, 2.4, 0.2)
		await _frames(40)
		lp.start(n, 0)
		await _frames(130)
		lp.stack_on = lp._find_stack()
		lp.lay()
		await _frames(80)
		logs.append(n)
	var mid := logs[0].mid()
	# crouched behind it, seen from the far side (where a raid would come from)
	player.global_position = _ground(mid.x, mid.z + 0.9) + Vector3.UP * 0.1
	player.yaw = 0.0                          # facing -Z: over the barricade
	player.rotation.y = 0.0
	player.pitch = deg_to_rad(-5.0)
	player.is_crouching = true
	player._set_capsule_height(player.crouch_height)
	await _frames(90)
	await _cam_shot("crouch", mid - side * 6.0 + Vector3.UP * 1.2 + ax * 1.5, mid + Vector3.UP * 0.6)
	player.is_crouching = false
	player._set_capsule_height(player.stand_height)
	Input.action_press(&"aim")
	await _frames(120)
	await _cam_shot("aim", mid + ax * 4.5 + Vector3.UP * 1.4 - side * 1.0, mid + Vector3.UP * 0.9 + side * 0.5)
	Input.action_release(&"aim")


# --- Shots ---------------------------------------------------------------------------------------------------

func _cam_shot(name: String, at: Vector3, look: Vector3, settle := true) -> void:
	var cam := Camera3D.new()
	cam.fov = 50.0
	current_scene.add_child(cam)
	cam.global_position = at
	cam.look_at(look)
	cam.make_current()
	if settle:
		await _frames(3)
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
