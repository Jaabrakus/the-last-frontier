extends SceneTree
## A close look at our own foraging grab in the game (tools/anim_author/install_forage.gd): the real player on the level, the grab
## over the game's own pose as ForagePick plays it (ToolPose "reach_r" / "reach_l", eased in and out): standing with the hands free,
## walking on with a grab now and then, and standing with the musket in the right hand (the left arm grabs). Frames to
## <out>/f00000.jpg ...
##   Godot --path . --resolution 960x540 --fixed-fps 30 -s tools/anim_author/forage_preview.gd -- out=<dir>

const AT := Vector3(21.0, 0.0, 9.0)

var out := ""
var frame := 0
var player: FrontierPlayer
var cam: Camera3D
var lib: AnimationLibrary
var pose: ToolPose
var cam_off := Vector3.ZERO      ## the camera in the player's frame (it follows a walk)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for i in 90:
		await physics_frame
	lib = load(ForagePick.CLIPS) as AnimationLibrary
	cam = Camera3D.new()
	cam.fov = 40.0
	current_scene.add_child(cam)
	cam.current = true
	pose = ToolPose.new()
	player.skeleton.add_child(pose)
	# standing, the hands free: two grabs from the side, two from the front
	_place(AT)
	if not player.hands_free:
		player.toggle_hands_free()
	await _idle(1.0)
	cam_off = Vector3(-2.4, 1.2, -0.6)
	await _idle(0.4)
	for i in 2:
		await _grab("r")
	cam_off = Vector3(-1.0, 1.25, -2.4)
	await _idle(0.4)
	for i in 2:
		await _grab("r")
	# walking on, a grab now and then
	_place(AT + Vector3(0, 0, 6))
	cam_off = Vector3(-2.6, 1.2, -1.2)
	Input.action_press(&"move_forward")
	await _idle(0.8)
	for i in 3:
		await _grab("r")
		await _idle(0.35)
	Input.action_release(&"move_forward")
	await _idle(0.6)
	# the musket in the right hand: the left arm grabs
	_place(AT)
	player.switch_weapon("musket")
	await _idle(1.6)
	cam_off = Vector3(1.6, 1.2, -1.9)
	await _idle(0.3)
	for i in 2:
		await _grab("l")
	print("PREVIEW %d frames" % frame)
	quit()


func _place(at: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO


func _grab(side: String) -> void:
	var a := lib.get_animation(StringName("own-forage-grab-" + side))
	var n := int(round(a.length * 30.0))
	for i in n + 1:
		var t := minf(i / 30.0, a.length)
		var w := minf(clampf(t / ForagePick.BLEND_IN_S, 0.0, 1.0), clampf((a.length - t) / ForagePick.BLEND_OUT_S, 0.0, 1.0))
		pose.layers = [{"anim": a, "time": t, "weight": w, "mask": "reach_" + side}]
		await _snap()
	pose.layers = []


func _idle(secs: float) -> void:
	for i in int(secs * 30.0):
		await _snap()


func _snap() -> void:
	await process_frame
	var b := player.global_transform.basis
	var c := player.global_position + Vector3(0, 1.0, 0)
	cam.global_position = c + b.x * cam_off.x + Vector3.UP * (cam_off.y - 1.0) - b.z * cam_off.z * -1.0
	cam.look_at(c + Vector3(0, -0.05, 0) - b.z * 0.3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join("f%05d.jpg" % frame), 0.9)
	frame += 1
