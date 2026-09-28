extends SceneTree
## A short film of the river's fish (FishLife; user 2026-09-27: "we should have actual fish in the ponds and rivers with
## there own intelligence we mimic and try to catch"): brook trout holding in a pool's clear edge on a June evening,
## rising to the hatch; a school of perch from above; the player walking up to the bank standing, the fish bolting; salmon
## in their October run leaping a rapid. A few fish are put where each shot looks (as the tests do); the rest are the
## water's own. Frames as JPGs in <out>/ for an encoder:
##   Godot --path . --fixed-fps 30 -s tools/wildlife/fish_film.gd -- out=<dir>

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const FPS := 30.0

var out := "user://fish_film"
var view
var p: FrontierPlayer
var life: FishLife
var rig: EnvironmentRig
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
	life = lvl.get_node("Fish") as FishLife
	rig = lvl.get_node("EnvironmentRig") as EnvironmentRig
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1280, 720)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1280, 720))
	view.camera.fov = 50.0
	view.camera.far = 2500.0
	root.disable_3d = true
	life.eye_override = view.camera
	await _pool()
	await _school()
	await _bolt()
	await _leaps()
	print("FISH FILM DONE (%d frames)  %s" % [frame, life.summary()])
	quit()


func _time(h: float, month: int) -> void:
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(h)
	life.hour_override = h
	life.month_override = month


func _run(n: int, rec := true) -> void:
	for i in n:
		view.camera.global_transform = Transform3D(Basis.looking_at(cam_at - cam_from, Vector3.UP), cam_from)
		await process_frame
		if rec:
			frame += 1
			(view.get_texture().get_image() as Image).save_jpg(out.path_join("f%05d.jpg" % frame), 0.9)


func _put(at: Vector3, facing := Vector3.FORWARD) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.yaw = atan2(-facing.x, -facing.z)
	p.rotation.y = p.yaw


func _edge(z: float, side: float) -> float:
	var cx := WorldRiver.x_at(z)
	var o := 0.0
	while life.depth(cx + side * (o + 0.25), z) > 0.0 and o < 14.0:
		o += 0.25
	return cx + side * o


## A fish of `sp` held at (x, z) in its ways (its lie there).
func _place(sp: String, x: float, z: float, st := FishLife.State.HOLD) -> FishLife.Fish:
	var f := life.spawn_fish(sp, Vector3(x, 0.0, z))
	if f == null:
		return null
	f.pos.y = life.layer_y(f, x, z)
	f.lie = f.pos
	f.goal = f.pos
	f.state = st
	f.base = st
	return f


## Trout holding in a pool's clear shallows late on a June afternoon, rising to the hatch: seen steeply from the bank
## (less of the sky in the water), hard to make out, as fish are; the rings give them away.
func _pool() -> void:
	_time(17.8, 6)
	var z := -120.0
	var ex := _edge(z, 1.0)
	# the player well off, out of the fish's sight
	_put(Vector3(ex + 30.0, 0.0, z + 30.0))
	await _run(90, false)
	for i in 6:
		var tz := z - 3.5 + i * 1.3
		var f := _place("brook_trout", _edge(tz, 1.0) - 1.2 - 0.5 * (i % 3), tz)
		if f:
			f.hunger = 1.0
			f.length = 0.3 + 0.025 * i
	await _run(15, false)
	cam_from = Vector3(ex + 1.6, life.surface(z) + 2.8, z + 2.4)
	cam_at = Vector3(ex - 1.6, life.surface(z) - 0.3, z - 1.2)
	for i in int(10.0 * FPS):
		# insects coming down over them
		if i % 9 == 0:
			var bz := z - 9.0 - (i % 4)
			life.bugs.append([Vector3(_edge(bz, 1.0) - 1.1 - (i % 3) * 0.5, life.surface(bz), bz), 0.0])
		await _run(1)


## A school of perch in a slow pool's shallows, from above.
func _school() -> void:
	_time(13.0, 7)
	var z := -40.0
	var ex := _edge(z, 1.0)
	_put(Vector3(ex + 30.0, 0.0, z + 30.0))
	await _run(10, false)
	var home := Vector3(ex - 2.2, 0.0, z)
	for i in 9:
		var f := _place("perch", home.x - (i % 3) * 0.5, home.z + (i / 3) * 0.6 - 0.6)
		if f:
			f.length = 0.2 + 0.01 * i
	await _run(20, false)
	for i in int(7.0 * FPS):
		var a := float(i) / (7.0 * FPS)
		cam_from = Vector3(ex + 1.2 - a * 0.6, life.surface(z) + 3.0, z + 1.8 - a * 1.2)
		cam_at = Vector3(home.x - 0.4, life.surface(z) - 0.4, home.z - 0.3)
		await _run(1)


## The player walking up to the bank standing, seen from behind: the fish in the shallows bolt, wakes and rings.
func _bolt() -> void:
	_time(11.0, 7)
	var z := 110.0
	var ex := _edge(z, 1.0)
	_put(Vector3(ex + 11.0, 0.0, z), Vector3.LEFT)
	await _run(10, false)
	for i in 7:
		var tz := z - 4.5 + i * 1.5
		_place("brook_trout" if i % 2 == 0 else "sucker", _edge(tz, 1.0) - 1.3 - 0.5 * (i % 3), tz)
	await _run(20, false)
	# high behind the player, looking down over the shallows they walk up to
	cam_from = Vector3(ex + 7.5, life.surface(z) + 6.5, z + 6.0)
	cam_at = Vector3(ex - 2.5, life.surface(z) - 0.3, z - 0.5)
	await _run(int(1.2 * FPS))
	Input.action_press(&"move_forward")
	for i in int(4.0 * FPS):
		var pp := p.global_position
		await _run(1)
		if pp.x < ex + 1.0:
			break
	Input.action_release(&"move_forward")
	for i in int(3.0 * FPS):
		await _run(1)


## Salmon in their October run trying a rapid, leaping it: from low on its bank beside them.
func _leaps() -> void:
	_time(10.0, 10)
	var r: Dictionary = WorldRiver.rapids()[1]
	var rz := float(r.z)
	var z := rz + float(r.length) * 0.5 + 6.0
	_put(Vector3(_edge(z, 1.0) + 30.0, 0.0, z + 10.0))
	await _run(10, false)
	var fish: Array = []
	for i in 7:
		var f := _place("salmon", WorldRiver.x_at(z) + (i - 3) * 1.1, z + (i % 2) * 1.5)
		if f:
			f.length = 0.72 + 0.03 * i
			fish.append(f)
	# on the bank at the rapid's middle, above where they leap, looking across it
	var cz := rz + 5.0
	cam_from = Vector3(_edge(cz, 1.0) + 1.0, life.surface(cz) + 3.2, cz + 5.0)
	cam_at = Vector3(WorldRiver.x_at(rz), life.surface(rz) + 0.1, rz + 1.0)
	var t := 0.0
	var next := 0.3
	while t < 15.0:
		t += 1.0 / FPS
		if t >= next and not fish.is_empty():
			life._start_run(fish.pop_front())
			next += 1.6
		var l0 := life.leaps
		await _run(1)
		if life.leaps > l0:
			print("LEAP at frame %d (%.1f s)" % [frame, frame / FPS])
