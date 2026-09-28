extends SceneTree
## Windowed screenshots of building (needs a window, not --headless): the real level and player; the pieces are
## built by this script through build mode itself (BuildMode: the piece chosen, the crosshair's point, the same
## snapping and checks as a player's hold of E).
##
##   cabin     a one-room cabin east of the fort: floor, two log walls, a window wall, a door wall with its steps,
##             two gables, a roof, a hearth and chimney on the gable end (cabin_front.png, cabin_back.png,
##             cabin_window.png, cabin_door.png with the door open, cabin_inside.png after walking in)
##   palisade  a palisade line with a corner and a gate (palisade.png; palisade_gate.png with the leaves open)
##   ghost     the gameplay view in build mode: a green ghost where a wall can go and a red one where it cannot,
##             with the build panel (ghost_ok.png, ghost_bad.png), and Take down aimed at the door wall
##             (take_down.png: it glows, the prompt says the roof rests on it)
##   slope     a floor with walls, and a wall between two corner posts, on sloping ground: the fieldstone
##             footings take up the fall (slope.png, slope_posts.png)
##
##   Godot --path . --resolution 1280x720 -s tests/building/building_shots.gd -- --no-capture out=/abs/dir \
##       [what=cabin,palisade,ghost,slope] [hour=11]

const G := preload("res://scripts/building/build_geometry.gd")
const CABIN := Vector3(21.0, 0.0, 6.0)
const PAL := Vector3(21.0, 0.0, -6.0)

var args := {}
var out := ""
var player: FrontierPlayer
var mode: BuildMode


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = String(args.get("out", "user://building_shots"))
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in current_scene.find_children("*", "", true, false):
		if n is DayNight:
			(n as DayNight).clock.running = false
			(n as DayNight).clock.set_time(float(args.get("hour", "11")))
			if (n as DayNight).has_method("force_weather"):
				(n as DayNight).force_weather("clear")
	await _frames(int(args.get("settle", "150")))
	mode = player.building
	var inv := InventoryState.from_player(player)
	inv.add("log", 300)
	inv.add("stone", 200)
	player.inventory_pack = inv.pack.duplicate(true)
	var what: PackedStringArray = String(args.get("what", "cabin,palisade,ghost,slope")).split(",")
	if "cabin" in what:
		await _cabin()
	if "palisade" in what:
		await _palisade()
	if "ghost" in what:
		await _ghost()
	if "slope" in what:
		await _slope()
	print("SHOTS DONE ", out)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _stand(at: Vector3, face: Vector3, pitch_deg := -12.0) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.yaw = atan2(-face.x, -face.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(pitch_deg)


## Builds `type` where build mode puts it for the crosshair on `p` (the ray from `from`, else from 1 m above).
func _build(type: String, p: Vector3, from := Vector3.INF) -> BuiltPiece:
	if not mode.active:
		mode.set_active(true)
	mode.select_type(type)
	mode.aim_at = p
	mode.aim_from = from
	await _phys(3)
	var kind := String(mode.cand.get("kind", ""))
	var piece := mode.place()
	print("%s (crosshair %s): %s%s" % [type, p, ("built at %s, %s" % [piece.global_position, kind if kind != "" else "on the ground"]) if piece
			else "NOT built: ", "" if piece else String(mode.verdict.get("reason", ""))])
	return piece


func _shot(name: String, from: Vector3, at: Vector3, fov := 50.0, hide_player := false) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 900.0
	current_scene.add_child(cam)
	cam.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
	cam.current = true
	var was := player.visible
	if hide_player:
		player.visible = false
	var hud_vis := mode.hud.visible
	mode.hud.visible = false
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name))
	print("saved ", name)
	cam.queue_free()
	player.camera.current = true
	player.visible = was
	mode.hud.visible = hud_vis


## A camera spot `h` m over the ground at `p`.
func _cam(p: Vector3, h: float) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z) + h, p.z)


func _gameplay(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	print("saved ", name)


func _cabin() -> void:
	_stand(CABIN + Vector3(4.0, 0, 3.5), Vector3.LEFT)
	await _phys(4)
	var fl := await _build("floor", CABIN)
	if fl == null:
		return
	var fo := fl.global_position
	var top := G.FLOOR_H
	var walls := {}
	for s: Array in [["wall", Vector3(1.3, 0, 0)], ["wall_window", Vector3(-1.3, 0, 0)], ["wall_door", Vector3(0, 0, 1.3)],
			["wall", Vector3(0, 0, -1.3)]]:
		walls[s[1]] = await _build(String(s[0]), fo + (s[1] as Vector3) + Vector3(0, top, 0))
	for k: Vector3 in [Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]:
		var w: BuiltPiece = walls.get(k)
		if w:
			await _build("gable", w.global_transform * Vector3(0, G.WALL_H + 0.01, 0))
	await _build("roof", fo + Vector3(0, top, 0))
	await _build("hearth", fo + Vector3(2.3, 0, 0))
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	_stand(CABIN + Vector3(-2.5, 0, 5.0), Vector3(0.4, 0, -1).normalized())
	await _phys(20)
	var c := fo + Vector3(0, 1.6, 0)
	await _shot("cabin_front.png", _cam(fo + Vector3(2.5, 0, 7.5), 1.8), c)
	await _shot("cabin_back.png", _cam(fo + Vector3(7.5, 0, -6.0), 2.2), c)
	# the window wall and its gable, from the lane between the cabin and the fort's east wall
	await _shot("cabin_window.png", _cam(fo + Vector3(-4.3, 0, 3.2), 1.6), fo + Vector3(-1.5, 2.0, 0), 62.0)
	var door: BuiltPiece = walls.get(Vector3(0, 0, 1.3))
	if door and door.door:
		door.door.set_open(true, true)
		_stand(fo + Vector3(0.6, 0, 3.4), Vector3.FORWARD)
		await _phys(20)
		await _shot("cabin_door.png", fo + Vector3(1.8, 1.7, 6.0), fo + Vector3(0, 1.1, 1.5), 45.0)
		# walk in through the doorway, then look back out from inside
		_stand(fo + Vector3(0, 0, 2.8), Vector3.FORWARD)
		await _phys(6)
		Input.action_press(&"move_forward")
		await _phys(170)
		Input.action_release(&"move_forward")
		await _phys(20)
		print("walked in to ", player.global_position - fo)
		await _shot("cabin_inside.png", fo + Vector3(-1.0, 1.6, -1.1), fo + Vector3(0.4, 1.0, 1.5), 70.0, true)


func _palisade() -> void:
	_stand(PAL + Vector3(1.5, 0, 3.0), Vector3.FORWARD)
	await _phys(6)
	var first := await _build("palisade", PAL)
	if first == null:
		return
	var fx := first.global_transform
	var second := await _build("palisade", fx * Vector3(3.2, 0, 0))
	if second:
		await _build("palisade", second.global_transform * Vector3(1.5, 0, -1.6))
	var gate := await _build("palisade_gate", fx * Vector3(-3.2, 0, 0))
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	_stand(PAL + Vector3(1.0, 0, 3.5), Vector3.FORWARD)
	await _phys(20)
	var c := fx * Vector3(0.5, 1.8, 0)
	await _shot("palisade.png", _cam(PAL + Vector3(6.0, 0, 7.0), 2.0), c, 55.0)
	if gate and gate.door:
		gate.door.set_open(true, true)
		await _phys(10)
		await _shot("palisade_gate.png", _cam(gate.global_transform * Vector3(1.2, 0, 7.5), 1.7), gate.global_transform * Vector3(0, 1.6, 0), 50.0)


func _ghost() -> void:
	# a wall on the ground in front of the cabin (the camera's own crosshair)
	_stand(CABIN + Vector3(0.6, 0, 10.5), Vector3.FORWARD, -24.0)
	await _phys(10)
	mode.set_active(true)
	mode.aim_at = Vector3.INF
	mode.select_type("wall")
	await _phys(12)
	print("ghost 1: ", mode.verdict.get("ok"), " ", mode.verdict.get("reason", ""), " at ", mode.aim.get("position"))
	await _gameplay("ghost_ok.png" if bool(mode.verdict.get("ok", false)) else "ghost_view1.png")
	# the same wall through the player: red, with the reason
	mode.aim_at = player.global_position + Vector3(0.0, 0.0, -0.05)
	await _phys(6)
	print("ghost 2: ", mode.verdict.get("ok"), " ", mode.verdict.get("reason", ""))
	await _gameplay("ghost_bad.png")
	# Take down: the door wall under the crosshair glows, the prompt says what comes back (or what rests on it)
	var world := BuildWorld.of(self)
	var door_wall: BuiltPiece = null
	for q in world.pieces():
		if q.type == "wall_door":
			door_wall = q
	if door_wall:
		_stand(door_wall.global_transform * Vector3(0.8, 0, 4.0), -door_wall.global_transform.basis.z, -8.0)
		await _phys(6)
		mode.select(mode.data.order.size())
		mode.aim_at = door_wall.global_transform * Vector3(-1.0, 1.2, 0.0)
		mode.aim_from = door_wall.global_transform * Vector3(-1.0, 1.2, 4.0)
		await _phys(8)
		print("take down: ", mode.aimed_piece, " prompt '", mode.take_down_prompt(), "' target ", player.interactor.target)
		await _gameplay("take_down.png")
	mode.aim_at = Vector3.INF
	mode.aim_from = Vector3.INF
	mode.set_active(false)
	print("grass texels kept clear by the pieces: ", world.grass.marked)


func _slope() -> void:
	# a spot beyond the clearing where the ground falls 0.5-0.9 m across 3 m
	var spot := Vector3.INF
	for r in range(34, 120, 4):
		for k in 36:
			var a := TAU * k / 36.0
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			if FrontierTerrain.in_flat_zone(p.x, p.z):
				continue
			var lo := INF
			var hi := -INF
			for sx: float in [-1.25, 0.0, 1.25]:
				for sz: float in [-1.25, 0.0, 1.25]:
					var y := FrontierTerrain.height_at(p.x + sx, p.z + sz)
					lo = minf(lo, y)
					hi = maxf(hi, y)
			if hi - lo > 0.5 and hi - lo < 0.85:
				p.y = FrontierTerrain.height_at(p.x, p.z)
				var v := BuildSnap.check("floor", {"xf": Transform3D(Basis(), p), "kind": "", "grounded": true}, BuildWorld.of(self),
						player.get_world_3d().direct_space_state, {"log": 99, "stone": 99}, mode.data)
				if v.ok:
					spot = p
					break
		if spot != Vector3.INF:
			break
	if spot == Vector3.INF:
		print("no slope spot found")
		return
	_stand(spot + Vector3(0, 0, 5.0), Vector3.FORWARD)
	await _phys(8)
	var fl := await _build("floor", spot)
	if fl:
		await _build("wall", fl.global_transform * Vector3(0, G.FLOOR_H, -1.3))
		await _build("wall", fl.global_transform * Vector3(0, G.FLOOR_H, 1.3) + Vector3(0, 0, 0))
	var fence := await _build("wall", spot + Vector3(4.0, 0, 0))
	if fence:
		# corner posts at both its ends (post-and-log)
		for sx: float in [-1.0, 1.0]:
			await _build("post", fence.global_transform * Vector3(sx * 1.5, 0.05, 0.25))
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	var c := spot + Vector3(1.5, 1.0, 0)
	await _shot("slope.png", spot + Vector3(-3.5, 2.5, 7.5), c, 55.0, true)
	if fence:
		await _shot("slope_posts.png", fence.global_transform * Vector3(1.0, 1.6, 4.5), fence.global_transform * Vector3(0, 1.0, 0), 60.0, true)
	print("slope at ", spot)
