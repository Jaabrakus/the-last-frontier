extends SceneTree
## Windowed screenshots of death and the dropped pack (needs a window, not --headless):
##   dead.png      the message after dying (how, where you will wake, the pack)
##   home.png      awake at home (the pack unmarked: the player remembers where they fell)
##   pack.png      at the pack: its E prompt
##   sheet.png     all of them
##
##   Godot --path . --resolution 1280x720 -s tests/save/save_shots.gd -- out=/abs/dir save=on survival=on

const CELL := Vector2i(640, 360)

var out := ""
var shots: Array = []
var player: FrontierPlayer


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	await _frames(200)
	var dr := DeathRule.find(self)
	# a home by the fort's gate, then out into the field to die
	dr.home = Vector3(0.0, FrontierTerrain.height_at(0.0, -24.0), -24.0)
	dr.home_yaw = PI
	dr.has_home = true
	player.gather.give("stone", 4)
	var at := Vector3(18.0, 0.0, -52.0)
	player.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
	await _frames(30)
	player.apply_hit(player.health + 5.0, player.global_position + Vector3.UP, Vector3.FORWARD, null, "body")
	await _frames(120)
	await _shot("dead")
	while player.is_dead:
		await process_frame
	await _frames(60)
	# face the pack from home
	var pd := get_nodes_in_group(PackDrop.GROUP)[0] as PackDrop
	var d := pd.global_position - player.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	await _frames(30)
	await _shot("home")
	player.global_position = pd.global_position + Vector3(1.4, 0.1, 0.4)
	d = pd.global_position - player.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-25.0)
	await _frames(40)
	await _shot("pack")
	_sheet()
	print("SHOTS DONE ", out)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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
	var grid := Image.create(CELL.x * shots.size(), CELL.y, false, Image.FORMAT_RGB8)
	for i in shots.size():
		grid.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i * CELL.x, 0))
	grid.save_png(out.path_join("sheet.png"))
