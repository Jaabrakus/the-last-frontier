extends SceneTree
## Look-check of the player paddling and crouching in a canoe in the level, windowed, survival on:
##   Godot --path . --resolution 1280x720 -s tests/boats/boat_ride_shots.gd -- out=<abs dir> survival=on
## A close camera beside the boat: the paddler idle (crouched, the paddle ready), a stroke on the right in five moments, a stroke on the left
## (steering right), and crouched low in the boat with the pistol aimed.
var out := ""
var player: FrontierPlayer
var b: Boat
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(name: String) -> void:
	# the close camera: beside the boat, level with the paddler, looking at them
	var seat := b.rider.seat_position()
	var side := b.right()
	var at := seat + side * 2.6 + Vector3.UP * 1.05 - b.forward() * 0.4
	cam.transform = Transform3D(Basis.looking_at(seat + Vector3.UP * 0.55 - at, Vector3.UP), at)
	for i in 4:
		await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	for i in 30:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	var z0 := -120.0
	var x0 := WorldRiver.x_at(z0)
	b = Boat.make("birchbark", Vector3(x0, 0.0, z0), atan2(WorldRiver.flow_at(z0).x, WorldRiver.flow_at(z0).z))
	current_scene.add_child(b)
	cam = Camera3D.new()
	cam.fov = 38
	current_scene.add_child(cam)
	cam.current = true
	await _frames(5)
	var bank := b.to_global(Vector3(b.num("beam") * 0.5 + 1.2, 0.0, 0.0))
	player.global_position = Vector3(bank.x, FrontierTerrain.height_at(bank.x, bank.z) + 0.05, bank.z)
	await _frames(3)
	b.rider.interact(player)
	await _frames(45)
	await _shot("1_ready_crouch")
	Input.action_press("move_forward")
	await _frames(70)
	for k in 5:
		await _shot("2_stroke_right_%d" % k)
		await _frames(12)
	Input.action_press("move_right")
	await _frames(50)
	for k in 4:
		await _shot("3_stroke_left_%d" % k)
		await _frames(12)
	Input.action_release("move_right")
	Input.action_release("move_forward")
	await _frames(20)
	Input.action_press("crouch")
	await _frames(4)
	Input.action_release("crouch")
	await _frames(40)
	player.switch_weapon("pistol")
	for i in 600:
		if not player.is_switching() and not player.weapon.is_equipping():
			break
		await physics_frame
	await _frames(30)
	Input.action_press("aim")
	await _frames(60)
	await _shot("4_crouched_pistol_aim")
	Input.action_release("aim")
	quit()
