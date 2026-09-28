extends SceneTree
## Windowed screenshot strips of the thrown weapons' carries and weapon switches (THROW2; needs a
## window, not --headless). The real player with the real input path, the scene frozen
## (SceneTree.paused) for each shot and rendered from three cameras:
##   rows     side (the character's right), front, over the shoulder (the gameplay camera)
## carry strips (what=carry): columns idle, walk, run, sprint, crouch, crouch walk, one grid per
##   weapon: <out>/carry_<weapon>.png
## switch strips (what=switch): musket -> weapon and weapon -> musket while running (move=run, or
##   sprint / walk), a column every `step` seconds from the switch, `per` columns a page:
##   <out>/switch_<from>_<to>_<move>_<page>.png; each column is labelled in the output with the
##   switch stage it shows (holster, finish, grab, draw, carry).
##
##   Godot --path . --resolution 1280x720 -s tests/throwables/throw_carry_screens.gd -- --no-capture out=/abs/dir [what=carry,switch] [weapon=spear,tomahawk,atlatl] [move=run] [step=0.1] [n=18] [per=6]

const CELL := Vector2i(400, 300)
const CARRY_COLS := ["idle", "walk", "run", "sprint", "crouch", "crouch_walk"]

var args := {}
var player: FrontierPlayer
var out := ""
var ticker: Ticker


class Ticker extends Node:
	var ticks := 0
	func _physics_process(_d: float) -> void:
		ticks += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = args.get("out", "user://throw_carry_shots")
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ticker = Ticker.new()
	current_scene.add_child(ticker)
	var what: PackedStringArray = String(args.get("what", "carry,switch")).split(",")
	var weapons: PackedStringArray = String(args.get("weapon", "spear,tomahawk,atlatl")).split(",")
	if "carry" in what:
		for w in weapons:
			await _carry_strip(w)
	if "switch" in what:
		var move := String(args.get("move", "run"))
		for w in weapons:
			await _switch_strip("musket", w, move)
			await _switch_strip(w, "musket", move)
	quit()


## Open field, facing +Z's far side, level camera.
func _reset() -> void:
	player.global_position = Vector3(float(args.get("x", "0")), 0.3, float(args.get("z", "30")))
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = deg_to_rad(-4.0)


func _set_crouch(on: bool) -> void:
	if player.is_crouching != on:
		Input.action_press("crouch")
		await _frames(3)
		Input.action_release("crouch")
		await _frames(3)


func _equip(key: String) -> void:
	if player.weapon_key != key:
		player.switch_weapon(key)
	await _frames(40)
	for i in 400:
		if player.weapon_key == key and not player.is_switching() and not player.weapon.is_equipping():
			break
		await _frames(1)
	await _frames(40)


func _move_keys(move: String) -> Array:
	match move:
		"walk":
			return ["move_forward", "walk"]
		"run", "crouch_walk":
			return ["move_forward"]
		"sprint":
			return ["move_forward", "sprint"]
	return []


func _carry_strip(key: String) -> void:
	_reset()
	await _set_crouch(false)
	await _equip(key)
	var shots := {}
	for col in CARRY_COLS:
		_reset()
		await _set_crouch(col.begins_with("crouch"))
		# Long enough for a landing after the move back (air and landing roles carry no arm layer).
		await _frames(int(args.get("settle", "200")))
		var keys := _move_keys(col)
		for k in keys:
			Input.action_press(k)
		await _frames(70 if not keys.is_empty() else 30)
		shots[col] = await _capture()
		for k in keys:
			Input.action_release(k)
		await _frames(30)
	await _set_crouch(false)
	var grid := Image.create(CELL.x * CARRY_COLS.size(), CELL.y * 3, false, Image.FORMAT_RGB8)
	for c in CARRY_COLS.size():
		var views: Array = shots.get(CARRY_COLS[c], [])
		for r in views.size():
			grid.blit_rect(views[r], Rect2i(Vector2i.ZERO, CELL), Vector2i(c * CELL.x, r * CELL.y))
	var path := out.path_join("carry_%s.png" % key)
	grid.save_png(path)
	print("saved %s (columns %s; rows side, front, over the shoulder)" % [path, ", ".join(CARRY_COLS)])


func _switch_strip(from: String, to: String, move: String) -> void:
	_reset()
	await _set_crouch(false)
	await _equip(from)
	var keys := _move_keys(move)
	for k in keys:
		Input.action_press(k)
	await _frames(60)
	player.switch_weapon(to)
	var t0 := ticker.ticks
	var hz := float(Engine.physics_ticks_per_second)
	var step := float(args.get("step", "0.1"))
	var n := int(args.get("n", "18"))
	var shots: Array = []
	for i in n:
		var target := t0 + int(round(i * step * hz))
		while ticker.ticks < target:
			await process_frame
		var stage := player.switch_stage()
		if stage == "":
			stage = "draw" if player.weapon.is_equipping() else "carry"
		shots.append(["%.1fs %s" % [i * step, stage], await _capture()])
	for k in keys:
		Input.action_release(k)
	await _frames(30)
	var per := maxi(1, int(args.get("per", "6")))
	var page := 0
	for c0 in range(0, shots.size(), per):
		var cols := mini(per, shots.size() - c0)
		var grid := Image.create(CELL.x * cols, CELL.y * 3, false, Image.FORMAT_RGB8)
		var labels := []
		for c in cols:
			var views: Array = shots[c0 + c][1]
			labels.append(shots[c0 + c][0])
			for r in views.size():
				grid.blit_rect(views[r], Rect2i(Vector2i.ZERO, CELL), Vector2i(c * CELL.x, r * CELL.y))
		var path := out.path_join("switch_%s_%s_%s_%d.png" % [from, to, move, page])
		grid.save_png(path)
		print("saved %s (columns %s; rows side, front, over the shoulder)" % [path, ", ".join(labels)])
		page += 1


## Freezes the scene and renders the three views; returns [side, front, play] cropped to CELL.
func _capture() -> Array:
	paused = true
	await _frames(2)
	var views := []
	var cam := Camera3D.new()
	cam.fov = 34.0
	current_scene.add_child(cam)
	# A fill light on the character's front right (the field is back-lit at some times of day).
	var light := OmniLight3D.new()
	light.omni_range = 8.0
	light.light_energy = 2.0
	current_scene.add_child(light)
	var center := player.global_position + Vector3(0, 1.1 if not player.is_crouching else 0.8, 0)
	light.global_position = center + player.global_basis * Vector3(1.5, 1.2, -2.0)
	for view: Vector3 in [Vector3(2.5, 0.15, 0.1), Vector3(0.6, 0.2, -2.6)]:
		cam.global_position = center + player.global_basis * view
		cam.look_at(center)
		cam.current = true
		views.append(await _grab(true))
	cam.queue_free()
	player.camera.current = true
	views.append(await _grab(false))
	light.queue_free()
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
		h = int(sz.y * 0.7)
		wdt = int(h * 4.0 / 3.0)
		x0 = (sz.x - wdt) / 2
		y0 = sz.y - h
	var crop := img.get_region(Rect2i(x0, y0, wdt, h))
	crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	return crop


func _frames(n: int) -> void:
	for i in n:
		await process_frame
