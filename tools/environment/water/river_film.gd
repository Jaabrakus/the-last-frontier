extends SceneTree
## A short film of the river (RiverWater; user 2026-09-27: "i know theres some realistic peformance based water tech
## right?", "have the river have some spots be like white water rapids"): the water running past a low camera on the
## bank, a slow pass along it from above, a rapid (white water round its boulders) from its bank and from over it, the
## player wading up it (slowed, splashing), and drinking at its edge. Frames as JPGs in <out>/ for an encoder
## (tools/showcase/video_encode.swift in the showcase clone, or any):
##   Godot --path . --fixed-fps 30 -s tools/environment/water/river_film.gd -- out=<dir>
## The window opens but draws nothing (OffscreenView renders off-window).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const FPS := 30.0

var out := "user://river_film"
var view
var p: FrontierPlayer
var river: RiverWater
var frame := 0
var cam_from := Vector3.ZERO
var cam_at := Vector3.FORWARD


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	p = lvl.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	if p.get("hud"):
		p.hud.visible = false
	river = lvl.get_node_or_null("River") as RiverWater
	var rig := lvl.get_node("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(10.0)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1280, 720)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1280, 720))
	view.camera.fov = 55.0
	view.camera.far = 2500.0
	root.disable_3d = true
	# the player out of the first shots, on the bank
	_put(Vector3(WorldRiver.x_at(-150.0) + 30.0, 0.0, -150.0), Vector3.LEFT)
	await _run(60, false)
	await _bank()
	await _pass()
	await _rapid()
	await _wade()
	await _drink()
	print("RIVER FILM DONE (%d frames)" % frame)
	quit()


func _run(n: int, rec := true) -> void:
	for i in n:
		view.camera.global_transform = Transform3D(Basis.looking_at(cam_at - cam_from, Vector3.UP), cam_from)
		await process_frame
		if rec:
			frame += 1
			(view.get_texture().get_image() as Image).save_jpg(out.path_join("f%05d.jpg" % frame), 0.9)


func _g(x: float, z: float, up: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z) + up, z)


func _put(at: Vector3, facing: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.yaw = atan2(-facing.x, -facing.z)
	p.rotation.y = p.yaw


## The water running past a low camera on the bank.
func _bank() -> void:
	var z := -40.0
	# on the bank where the camera stands (the river bends: its centre there, not at z)
	cam_from = _g(WorldRiver.x_at(z + 6.0) + 12.5, z + 6.0, 1.2)
	cam_at = Vector3(WorldRiver.x_at(z - 14.0) - 2.0, WorldRiver.level_at(z - 14.0), z - 14.0)
	await _run(int(5.0 * FPS))


## A slow pass along it from above.
func _pass() -> void:
	var n := int(6.0 * FPS)
	for i in n:
		var z := lerpf(60.0, 10.0, float(i) / n)
		var cx := WorldRiver.x_at(z)
		cam_from = Vector3(cx + 16.0, WorldRiver.level_at(z) + 14.0, z + 20.0)
		cam_at = Vector3(WorldRiver.x_at(z - 30.0), WorldRiver.level_at(z - 30.0), z - 30.0)
		await _run(1)


## A rapid: from its bank looking up it, then drifting over it.
func _rapid() -> void:
	var r: Dictionary = WorldRiver.rapids()[0]
	var z := float(r.z) + float(r.length) * 0.5 + 10.0
	cam_from = _g(WorldRiver.x_at(z) + 13.0, z, 1.6)
	cam_at = Vector3(WorldRiver.x_at(z - 30.0), WorldRiver.level_at(z - 30.0) + 0.3, z - 30.0)
	await _run(int(5.0 * FPS))
	var n := int(5.0 * FPS)
	for i in n:
		var zz := lerpf(float(r.z) + 30.0, float(r.z) - 10.0, float(i) / n)
		cam_from = Vector3(WorldRiver.x_at(zz) - 9.0, WorldRiver.level_at(zz) + 7.0, zz + 10.0)
		cam_at = Vector3(WorldRiver.x_at(zz - 16.0), WorldRiver.level_at(zz - 16.0), zz - 16.0)
		await _run(1)


## The player wading up it, slowed, splashing; the camera beside.
func _wade() -> void:
	var z := 140.0
	_put(Vector3(WorldRiver.x_at(z), 0.0, z), -WorldRiver.flow_at(z))
	await _run(10, false)
	Input.action_press(&"move_forward")
	for i in int(7.0 * FPS):
		var f := -WorldRiver.flow_at(p.global_position.z)
		p.yaw = atan2(-f.x, -f.z)
		p.rotation.y = p.yaw
		var pp := p.global_position
		var side := Vector3(f.z, 0.0, -f.x)
		cam_from = Vector3(pp.x, WorldRiver.level_at(pp.z) + 1.9, pp.z) + side * 5.5 - f * 3.0
		cam_at = pp + Vector3.UP * 0.9 + f * 1.5
		await _run(1)
	Input.action_release(&"move_forward")
	await _run(10)


## Drinking at its edge.
func _drink() -> void:
	var z := 60.0
	var cx := WorldRiver.x_at(z)
	var edge := 0.0
	while WorldRiver.surface_at(cx + edge + 0.5, z) != WorldRiver.NO_WATER:
		edge += 0.5
	_put(Vector3(cx + edge + 1.1, 0.0, z), Vector3.LEFT)
	cam_from = _g(cx + edge + 3.2, z + 3.8, 1.3)
	cam_at = Vector3(cx + edge, WorldRiver.level_at(z) + 0.4, z)
	await _run(15)
	if river:
		await _run(1, false)
		river.interact(p)
		var t := 0.0
		while river.drinking and t < 12.0:
			await _run(1)
			t += 1.0 / FPS
	await _run(int(1.0 * FPS))
