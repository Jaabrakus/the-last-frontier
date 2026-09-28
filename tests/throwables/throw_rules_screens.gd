extends "res://tests/throwables/harness.gd"
## Screenshots of the throw rules for the design doc (needs a window, not --headless):
## where thrown weapons stick and how they are picked up again. The throwables are not
## in the player's roster or animation graph yet, so the body stays in the pistol carry
## pose and the HUD shows the pistol.
##
##   Godot --path . --resolution 1600x900 -s tests/throwables/throw_rules_screens.gd -- --no-capture out=/abs/dir
##
## Saves: throw_spear_tree.png (a spear in a forest tree), throw_spear_ground.png (a spear
## stuck in the dirt lane at the end of a 36 m lob), throw_tomahawks_board.png (trade and
## pipe tomahawk blade-first in a wooden board), throw_spear_high.png (a spear stuck out of
## walking reach, the E-pickup case, with the player under it).

var out := ""


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = args.get("out", "user://throw_rules_shots")
	DirAccess.make_dir_recursive_absolute(out)
	var keys: Array[String] = ["spear", "tomahawk", "tomahawk_pipe"]
	if not await _boot(keys):
		quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for k in kit:
		_no_spread(kit[k])

	# 1. A spear in a tree.
	await _use("spear")
	var tree := _find_tree()
	if not tree.is_empty():
		await _stand_and_aim(tree.stand, tree.aim)
		var p := await _full_throw()
		await _wait_rest(p)
		await _frames(30)
		if is_instance_valid(p):
			var aim: Vector3 = tree.aim
			var stand: Vector3 = tree.stand
			var fwd := Vector3(aim.x - stand.x, 0.0, aim.z - stand.z).normalized()
			var side := fwd.cross(Vector3.UP)
			var mid := (p.tip_position() + p.tail_position()) * 0.5
			await _shot_from("throw_spear_tree.png", mid + side * 1.9 + Vector3(0, 0.35, 0) - fwd * 0.6, mid + Vector3(0, -0.05, 0) + fwd * 0.35)
			await _pick_up(p)
	else:
		print("no tree found")
	await _frames(150)

	# 2. A spear stuck in the dirt lane at the end of a long lob.
	var x := -1.25
	await _stand_and_aim(Vector3(x, _ground_at(x, -21.0), -21.0), Vector3(x, _ground_at(x, -57.0), -57.0))
	var lob := await _full_throw()
	await _wait_rest(lob)
	await _frames(30)
	if is_instance_valid(lob):
		var c := lob.tip_position()
		await _shot_from("throw_spear_ground.png", c + Vector3(2.2, 0.9, 1.1), c + Vector3(0, 0.45, 0.75))
		await _pick_up(lob)
	await _frames(150)

	# 3. Trade and pipe tomahawk blade-first in a wooden board.
	var board := _board(10.0, -32.0, "wood", 1.6, 2.4)
	var face := board.global_position + Vector3(0, 0, 0.15)
	await _use("tomahawk")
	await _stand_and_aim(Vector3(9.8, _ground_at(9.8, -27.0), -27.0), face + Vector3(-0.3, -0.1, 0))
	var t1 := await _full_throw()
	await _wait_rest(t1)
	await _use("tomahawk_pipe")
	await _stand_and_aim(Vector3(10.2, _ground_at(10.2, -27.0), -27.0), face + Vector3(0.3, -0.1, 0))
	var t2 := await _full_throw()
	await _wait_rest(t2)
	await _frames(30)
	player.visible = false
	await _shot_from("throw_tomahawks_board.png", face + Vector3(1.1, 0.25, 1.35), face + Vector3(0.0, -0.1, 0.15))
	player.visible = true
	for t in [t1, t2]:
		await _pick_up(t)
	_clear_boards()
	await _frames(60)

	# 4. A spear stuck high in a board: out of walking reach, E takes it down.
	await _use("spear")
	var high := _board(10.0, -32.0, "wood", 1.6, 4.0)
	var g := _ground_at(10.0, -31.0)
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -24.0), -24.0), Vector3(10.0, g + 2.65, high.global_position.z))
	var ps := await _full_throw()
	await _wait_rest(ps)
	if is_instance_valid(ps):
		var mid := (ps.tip_position() + ps.tail_position()) * 0.5
		player.global_position = Vector3(mid.x + 0.3, g + 0.3, mid.z + 0.2)
		player.velocity = Vector3.ZERO
		player.yaw = PI * 0.5
		await _frames(60)
		var pk := ThrownPickup.nearest_for(player)
		print("high spear: reach %.2f m, prompt \"%s\"" % [ps.pickup.distance_from(player.global_position + Vector3.UP * 0.9),
				pk.prompt(player) if pk else ""])
		await _shot_from("throw_spear_high.png", Vector3(13.2, g + 1.9, mid.z + 2.4), Vector3(10.0, g + 1.7, mid.z - 0.2))
	quit()


func _shot_from(file: String, from: Vector3, at: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 45
	current_scene.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(file))
	print("saved ", out.path_join(file))
	cam.queue_free()
	player.camera.current = true
