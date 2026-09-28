extends SceneTree
## Look-check stills of the birds and fireflies (windowed; wrap it in a time limit):
##
##   Godot --path . --resolution 1280x720 -s tests/wildlife/birdlife_shots.gd -- --no-capture birdlife=on out=<dir>
##
## Fireflies over the range meadow after sunset, an owl on its limb at dusk, a flock crossing the sky by day.
## Ends with BIRDLIFE SHOTS DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var args := {}
var view: OffscreenView
var player: FrontierPlayer
var clock: WorldClock


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	OS.low_processor_usage_mode_sleep_usec = 0
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	var out: String = args.get("out", "user://birdlife_shots")
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	if player.hud:
		player.hud.visible = false
	var rig := current_scene.get_node("EnvironmentRig") as EnvironmentRig
	clock = rig.clock_driver.clock if rig.clock_driver else null
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	if rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	var birds := current_scene.get_node("BirdLife") as BirdLife
	# 1. fireflies over the meadow after sunset
	if clock:
		clock.set_time(20.1)
	var m := Vector3(20.0, 0.0, -110.0)
	player.global_position = Vector3(m.x, FrontierTerrain.height_at(m.x, m.z) + 0.1, m.z)
	await _frames(240)
	var cam := Vector3(18.0, 0.0, -100.0)
	cam.y = FrontierTerrain.height_at(cam.x, cam.z) + 1.5
	await _shot(out, "fireflies", cam, Vector3(24.0, cam.y - 0.3, -125.0), 60.0, 30)
	# 2. an owl on its limb (dusk light)
	if clock:
		clock.set_time(19.35)
	birds.sun_override = -8.0          # the owls are out; the sky still has some light
	await _frames(120)
	var owls := birds.owls()
	if not owls.is_empty():
		var o := owls[0]
		var to := (o.global_position - player.global_position)
		to.y = 0.0
		var c := o.global_position - to.normalized() * 1.6
		c.y = o.global_position.y + 0.35
		player.global_position = o.global_position - to.normalized() * 30.0      # far enough: it stays
		player.global_position.y = FrontierTerrain.height_at(player.global_position.x, player.global_position.z) + 0.1
		await _frames(30)
		await _shot(out, "owl", c, o.global_position + Vector3.UP * 0.32, 40.0, 60)
		birds.sun_override = -16.0
		await _shot(out, "owl_night", c, o.global_position + Vector3.UP * 0.32, 40.0, 30)
	birds.sun_override = INF
	# 3. a flock crossing the sky by day
	if clock:
		clock.set_time(13.0)
	var d := Vector3(10.0, 0.0, -60.0)
	player.global_position = Vector3(d.x, FrontierTerrain.height_at(d.x, d.z) + 0.1, d.z)
	var g := FrontierTerrain.height_at(d.x, d.z)
	birds._spawn_flock(Vector3(d.x - 60.0, g + 22.0, d.z - 30.0), Vector3(d.x + 60.0, g + 26.0, d.z - 20.0), 26, false)
	await _frames(300)
	await _shot(out, "flock", Vector3(d.x, g + 1.6, d.z + 5.0), Vector3(d.x + 5.0, g + 22.0, d.z - 25.0), 70.0, 1)
	print("BIRDLIFE SHOTS DONE")
	quit()


func _shot(out: String, name: String, pos: Vector3, target: Vector3, fov: float, settle: int) -> void:
	var cam: Camera3D = view.camera
	view.source = null
	cam.fov = fov
	for i in settle:
		cam.global_position = pos
		cam.look_at(target)
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
	view.sync_camera()
	RenderingServer.force_draw(false)
	var img: Image = view.get_texture().get_image()
	img.save_png(out.path_join("%s.png" % name))
	print("saved ", out.path_join("%s.png" % name))


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
