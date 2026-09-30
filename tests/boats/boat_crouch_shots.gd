extends SceneTree
## Look-check of the player crouched in a canoe (C), windowed, survival on:
##   Godot --path . --resolution 1280x720 -s tests/boats/boat_crouch_shots.gd -- out=<abs dir> survival=on
## The crouch from the side, the front and behind, with how low they are against the gunwale (printed); walking about the floor; the jump
## out over the side.
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


## A shot from `where`: "side", "front", "back", with the camera `dist` m off, looking at the player's middle.
func _shot(name: String, where := "side", dist := 3.3) -> void:
	var target := player.global_position + Vector3.UP * 0.55
	var dir := b.right()
	if where == "front":
		dir = b.forward()
	elif where == "back":
		dir = -b.forward()
	var at := target + dir * dist + Vector3.UP * 0.9
	cam.transform = Transform3D(Basis.looking_at(target - at, Vector3.UP), at)
	for i in 4:
		await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _height() -> void:
	var sk := player.skeleton
	var head := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("headb"))).origin
	var hull := b.hull_numbers()
	var rim := b.hull_mesh.to_global(Vector3(0.0, HullMesh.top_y(hull, 0.0), 0.0)).y
	var floor_y := b.to_global(Vector3(0.0, b.floor_y(), 0.0)).y
	print("HEIGHTS: floor %.2f  gunwale %.2f (%.2f above the floor)  head %.2f (%.2f above the floor, %.2f above the gunwale)  camera eye %.2f" % [
			floor_y, rim, rim - floor_y, head.y, head.y - floor_y, head.y - rim, player.camera_pivot.global_position.y - floor_y])


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
	cam.fov = 42
	current_scene.add_child(cam)
	cam.current = true
	await _frames(5)
	var bank := b.to_global(Vector3(b.num("beam") * 0.5 + 1.2, 0.0, 0.0))
	player.global_position = Vector3(bank.x, FrontierTerrain.height_at(bank.x, bank.z) + 0.05, bank.z)
	await _frames(3)
	b.rider.interact(player)
	await _frames(40)
	Input.action_press("crouch")
	await _frames(4)
	Input.action_release("crouch")
	await _frames(70)
	_height()
	await _shot("c_side", "side")
	await _shot("c_front", "front")
	await _shot("c_back", "back")
	# walking about: forward along the boat
	player.rotation.y = b.rotation.y + PI
	Input.action_press("move_forward")
	await _frames(30)
	await _shot("walk_a", "side")
	await _frames(40)
	await _shot("walk_b", "side")
	Input.action_release("move_forward")
	await _frames(20)
	# on their own: to the side, and over it with a hop
	player.global_position = b.to_global(Vector3(0.0, b.floor_y() + 0.02, 0.0))
	await _frames(15)
	player.yaw = atan2(-b.right().x, -b.right().z)   # facing the right side
	Input.action_press("move_forward")
	await _frames(14)
	await _shot("edge", "front")
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(6)
	await _shot("jump_a", "front")
	await _frames(12)
	await _shot("jump_b", "front")
	await _frames(30)
	Input.action_release("move_forward")
	await _shot("jump_c", "front")
	quit()
