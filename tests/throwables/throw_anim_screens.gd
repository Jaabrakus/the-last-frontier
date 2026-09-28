extends SceneTree
## Windowed screenshot strips of the thrown weapons' throw animation (THROW work package; needs a
## window, not --headless): for each weapon and stance (standing, crouched, walking) the real
## player throws with the real input path (hold LMB to wind up, release to throw), and the scene is
## frozen (SceneTree.paused) at the key moments of the throw and shot from three cameras:
##   rows     side (the character's right), front, over the shoulder (the gameplay camera)
##   columns  carry, wind-up (half charge: the aim tree coming in, the graph's aim-in), wound up
##            (full charge), release-start, release frame (ThrowChain's release event),
##            follow-through (release-end at 0.6), recover, the next one's draw (half way), back
## Saves <out>/throw_<weapon>_<mode>.png (one grid per weapon and stance) and prints what each
## column shows. The throw clips are the graph's (actor_b_graph.json throw rows).
##
##   Godot --path . --resolution 1280x720 -s tests/throwables/throw_anim_screens.gd -- --no-capture out=/abs/dir [weapon=spear,tomahawk,atlatl] [mode=stand,crouch,walk]

const CELL := Vector2i(400, 300)
const COLS := ["carry", "windup", "wound", "rel_start", "release", "follow", "recover", "draw", "back"]

var args := {}
var player: FrontierPlayer
var out := ""
var _released := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = args.get("out", "user://throw_anim_shots")
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for d in current_scene.find_children("*", "TargetDummy", true, false):
		(d as TargetDummy).max_health = 1.0e6
		(d as TargetDummy).health = 1.0e6
	player.anim.throw_released.connect(func(_k: StringName) -> void: _released = true)
	var weapons: PackedStringArray = String(args.get("weapon", "spear,tomahawk,atlatl")).split(",")
	var modes: PackedStringArray = String(args.get("mode", "stand,crouch,walk")).split(",")
	for w in weapons:
		for m in modes:
			await _strip(w, m)
	quit()


func _strip(key: String, mode: String) -> void:
	# Stand in the open, sunlit lane, facing the dummies.
	player.global_position = Vector3(float(args.get("x", "0")), 0.3, float(args.get("z", "-24")))
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = deg_to_rad(-4.0)
	if player.is_crouching != (mode == "crouch"):
		Input.action_press("crouch")
		await _frames(3)
		Input.action_release("crouch")
	player.switch_weapon(key)
	await _frames(40)
	for i in 240:
		if not player.is_switching() and not player.weapon.is_equipping():
			break
		await _frames(1)
	var w := player.weapon as Throwable
	if w.count < w.max_count:
		w.add_items(w.max_count - w.count)
	for i in 240:
		if w.state == Throwable.State.READY:
			break
		await _frames(1)
	await _frames(40)
	if mode == "walk":
		Input.action_press("move_forward")
		await _frames(50)
	var shots := {}
	shots["carry"] = await _capture()
	Input.action_press("fire")
	for i in 400:
		await _frames(1)
		if w.charge >= 0.5:
			break
	shots["windup"] = await _capture()
	for i in 400:
		await _frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	await _frames(20)
	shots["wound"] = await _capture()
	_released = false
	Input.action_release("fire")
	var th: ThrowChain = player.anim.upper.throw
	for i in 200:
		await _frames(1)
		if th.state == ThrowChain.START and th.part_phase("start") >= 0.5:
			break
	shots["rel_start"] = await _capture()
	for i in 200:
		if _released:
			break
		await _frames(1)
	shots["release"] = await _capture()
	for i in 200:
		await _frames(1)
		if th.part_phase("end") >= 0.6 or th.state in [ThrowChain.RECOVER, ThrowChain.EXIT, ThrowChain.NONE]:
			break
	shots["follow"] = await _capture()
	for i in 200:
		await _frames(1)
		if th.state == ThrowChain.RECOVER and th.part_phase("recover") >= 0.35 or th.state in [ThrowChain.EXIT, ThrowChain.NONE]:
			break
	shots["recover"] = await _capture()
	for i in 400:
		if w.state == Throwable.State.DRAWING and w.progress().size() == 2 and float(w.progress()[1]) >= 0.5:
			break
		if w.state == Throwable.State.READY:
			break    # the draw was over by the recover shot (a quick draw)
		await _frames(1)
	shots["draw"] = await _capture()
	for i in 400:
		await _frames(1)
		if th.state == ThrowChain.NONE and w.state == Throwable.State.READY:
			break
	await _frames(30)
	shots["back"] = await _capture()
	Input.action_release("move_forward")
	await _frames(30)
	# Grid: rows side / front / play, columns COLS.
	var grid := Image.create(CELL.x * COLS.size(), CELL.y * 3, false, Image.FORMAT_RGB8)
	for c in COLS.size():
		var views: Array = shots.get(COLS[c], [])
		for r in views.size():
			var img: Image = views[r]
			grid.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(c * CELL.x, r * CELL.y))
	var path := out.path_join("throw_%s_%s.png" % [key, mode])
	grid.save_png(path)
	print("saved %s (columns %s; rows side, front, over the shoulder)" % [path, ", ".join(COLS)])


## Freezes the scene and renders the three views; returns [side, front, play] cropped to CELL.
func _capture() -> Array:
	paused = true
	await _frames(2)
	var views := []
	var cam := Camera3D.new()
	cam.fov = 38.0
	current_scene.add_child(cam)
	var center := player.global_position + Vector3(0, 1.05 if not player.is_crouching else 0.8, 0)
	for view: Vector3 in [Vector3(3.0, 0.3, -0.2), Vector3(0.6, 0.3, -3.0)]:
		cam.global_position = center + player.global_basis * view
		cam.look_at(center)
		cam.current = true
		views.append(await _grab(true))
	cam.queue_free()
	player.camera.current = true
	views.append(await _grab(false))
	paused = false
	return views


func _grab(center_crop: bool) -> Image:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var sz := img.get_size()
	# Crop a 4:3 window round the character, then scale to CELL.
	var h := sz.y
	var wdt := int(h * 4.0 / 3.0)
	var x0 := (sz.x - wdt) / 2
	var y0 := 0
	if not center_crop:
		# The gameplay camera sits high behind the player: the character is in the lower middle.
		h = int(sz.y * 0.8)
		wdt = int(h * 4.0 / 3.0)
		x0 = (sz.x - wdt) / 2
		y0 = sz.y - h
	var crop := img.get_region(Rect2i(x0, y0, wdt, h))
	crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	return crop


func _frames(n: int) -> void:
	for i in n:
		await process_frame
