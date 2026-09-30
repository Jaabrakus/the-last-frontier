extends SceneTree
## Look-check of the flintlock pistol aimed with one hand (PlayerAnim.one_hand_aim_on) against the source's two-handed aim, windowed:
##   Godot --path . --resolution 1280x720 -s tests/anim/pistol_shots.gd -- out=<abs dir>
## Views of the player standing and crouched, aimed, from the front-left, one hand and two.
var out := ""
var player: FrontierPlayer


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
	for i in 4:
		await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _view(name: String) -> void:
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	var fwd := -player.global_basis.z
	var left := -player.global_basis.x
	var at := player.global_position + fwd * 2.3 + left * 1.3 + Vector3.UP * 1.4
	cam.transform = Transform3D(Basis.looking_at(player.global_position + Vector3.UP * 1.1 - at, Vector3.UP), at)
	cam.fov = 40
	cam.current = true
	await _frames(3)
	await _shot(name)
	cam.queue_free()
	player.get_viewport().get_camera_3d()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	for i in 30:
		await process_frame
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	player.switch_weapon("pistol")
	for i in 600:
		if not player.is_switching() and not player.weapon.is_equipping():
			break
		await physics_frame
	await _frames(40)
	Input.action_press("aim")
	await _frames(70)
	player.anim.one_hand_aim_on = false
	await _frames(30)
	await _view("opt0_two_hands")
	player.anim.one_hand_aim_on = true
	var options := [["opt1_hang", "actor_b-p-relax-idle", 0.0], ["opt2_fall_a", "actor_b-p-fall", 0.0], ["opt3_fall_b", "actor_b-p-fall", 0.5],
			["opt4_jump_a", "actor_b-p-jump-long", 0.3], ["opt5_jump_b", "actor_b-p-jump-long", 0.6], ["opt6_run_jump", "actor_b-p-run^jump-long", 0.4]]
	for o: Array in options:
		player.anim.one_hand_left_arm = String(o[1])
		player.anim.one_hand_left_phase = float(o[2])
		await _frames(40)
		await _view(String(o[0]))
	Input.action_release("aim")
	quit()
