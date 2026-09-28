extends SceneTree
## Mount, riding camera and dismount through the E key in the Frontier level (needs a window for
## the shots; the checks also run headless):
##
##   Godot --path . --resolution 1280x720 -s tests/horse/horse_ride_camera.gd -- out=/tmp/ridecam
##
## - a tap of E at the horse's mount point mounts it (PlayerInteractor -> HorseMount);
## - on horseback the camera goes RIDE_CAMERA_BACK further back (spring length), the horse's own
##   body does not pull it in (the spring arm excludes it), and there is no on-screen wording
##   (user 2026-09-25: "remove the hold e to dismount wording");
## - holding E for DISMOUNT_HOLD_S gets off; a shorter hold does not; the camera comes back in.
## Shots: <out>/mount_0_start.png (just mounted), mount_1_back.png (camera settled back),
## mount_2_off.png (dismounted). Prints RIDE CAMERA OK / FAILED.

var out := "user://horse_ride_camera"
var fails: Array[String] = []
var player: FrontierPlayer
var horse: Horse
var interactor: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	for i in 30:
		await physics_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	var hs := current_scene.find_children("*", "Horse", true, false)
	if player == null or hs.is_empty():
		print("RIDE CAMERA FAILED: level or horse missing")
		quit(1)
		return
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	horse = hs[0]
	var its := current_scene.find_children("*", "PlayerInteractor", true, false)
	interactor = its[0] if not its.is_empty() else null
	# stand at the horse's left mount point, facing its flank, and tap E
	var mp := horse.get_mount_point(Horse.LEFT)
	player.global_position = mp.origin + Vector3.UP * 0.05
	var to := horse.get_saddle_transform().origin - player.global_position
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = deg_to_rad(-12.0)
	for i in 30:
		await physics_frame
	var prompt := _label_text()
	await _press("interact", 6)
	for i in 10:
		await physics_frame
	_check(player.riding == horse, "a tap of E at the mount point mounts the horse (prompt was '%s')" % prompt)
	if player.riding == null:
		player.mount(horse)
	player.yaw = horse.rotation.y
	player.pitch = deg_to_rad(-10.0)
	await _shot("mount_0_start")
	for i in 360:
		await physics_frame
	var want := player.camera_distance + FrontierPlayer.RIDE_CAMERA_BACK
	var arm := player.spring_arm
	var cam_d := player.camera.global_position.distance_to(arm.global_position)
	_check(absf(arm.spring_length - want) < 0.05, "riding: spring length %.2f m (on foot %.2f + %.2f)" % [
			arm.spring_length, player.camera_distance, FrontierPlayer.RIDE_CAMERA_BACK])
	_check(cam_d > want - 0.35, "riding: the camera sits %.2f m behind its pivot (not pulled in by the horse)" % cam_d)
	var txt := _label_text()
	_check(txt.strip_edges().is_empty(), "riding: no on-screen wording (label '%s')" % txt)
	await _shot("mount_1_back")
	# a short hold (0.25 s) keeps the rider on; a 0.7 s hold gets off
	await _press("interact", 30)
	for i in 20:
		await physics_frame
	_check(player.riding == horse, "a 0.25 s press of E does not dismount")
	await _press("interact", 84)
	for i in 30:
		await physics_frame
	_check(player.riding == null, "holding E 0.7 s dismounts")
	for i in 60:
		await physics_frame
	_check(absf(arm.spring_length - player.camera_distance) < 0.01, "on foot: spring length back to %.2f m" % arm.spring_length)
	await _shot("mount_2_off")
	print("RIDE CAMERA %s %s" % ["OK" if fails.is_empty() else "FAILED", fails])
	quit(0 if fails.is_empty() else 1)


func _label_text() -> String:
	if interactor == null:
		return "<no interactor>"
	var l := interactor.get("_label") as Label
	return l.text if l else ""


func _press(action: String, ticks: int) -> void:
	Input.action_press(action)
	for i in ticks:
		await physics_frame
	Input.action_release(action)
	await physics_frame


func _check(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok:
		fails.append(msg)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)
