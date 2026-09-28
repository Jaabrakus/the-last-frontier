extends SceneTree
## Preview screenshots of the over-under (needs a window, not --headless):
##
##   Godot --path . --windowed --resolution 1600x900 -s tests/weapons/over_under_preview.gd -- \
##       --no-capture quality=medium out=/tmp/ou_preview
##
## Writes into <out>:
##   turnaround.png        3 x 3 sheet of the model alone: four sides, top, three-quarters, the
##                         lock, the lock with the barrels half turned (90 deg), the muzzles
##   held_<pose>_<view>.png  the gun in Actor_B's hands in the level, installed by OverUnderKit on
##                         the right prop bone with the musket's attach transform:
##                         pose = aim (RMB steady, standing), aim_crouch, turning (mid turnover,
##                         barrels about 90 deg, slow motion while captured), carry (lowered);
##                         view = play (game camera), side, front, lock (close-up of the breech
##                         from the lock side, in the gun's own axes)
##   musket_aim_<view>.png the musket in the same aim pose, for comparing the hands
##   held_sheet.png        the held shots side by side
##
## Until hook H7 the turnover plays no pump clip (the hands keep the musket's aim pose while the
## barrels turn); the model and rig are what is previewed.

var args := {}
var out := "user://ou_preview"
var shots: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = String(args.get("out", out))
	DirAccess.make_dir_recursive_absolute(out)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame            # the root enters the tree after _initialize (look_at needs it)
	await _turnaround()
	await _held()
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab() -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()


func _save(img: Image, name: String) -> void:
	var path := out + "/" + name + ".png"
	img.save_png(path)
	print("saved ", path)


func _sheet(images: Array, cols: int, cell: Vector2i, name: String) -> void:
	var rows := int(ceil(images.size() / float(cols)))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.12, 0.12))
	for i in images.size():
		var im := (images[i] as Image).duplicate() as Image
		im.convert(Image.FORMAT_RGBA8)
		im.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, cell), Vector2i((i % cols) * cell.x, (i / cols) * cell.y))
	_save(sheet, name)


# --- The model alone ------------------------------------------------------------------------

func _turnaround() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.55, 0.65, 0.8)
	mat.sky_horizon_color = Color(0.8, 0.78, 0.72)
	mat.ground_bottom_color = Color(0.2, 0.18, 0.15)
	mat.ground_horizon_color = Color(0.5, 0.46, 0.4)
	sky.sky_material = mat
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.37, 0.39)
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(35), 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-140), 0)
	fill.light_energy = 0.5
	stage.add_child(fill)
	var model := OverUnderModel.build()
	stage.add_child(model)
	var w := OverUnderMusket.new()        # only for the rig pose (frizzen shut, full cock)
	w.bind_model(model)
	var cam := Camera3D.new()
	cam.fov = 30
	stage.add_child(cam)
	cam.current = true
	var mid := Vector3(0, 0.0, -0.38)
	var views := [
		["right", mid + Vector3(2.6, 0.15, 0), mid, 0.0],
		["left", mid + Vector3(-2.6, 0.15, 0), mid, 0.0],
		["top", mid + Vector3(0, 2.6, 0.01), mid, 0.0],
		["three_quarter", mid + Vector3(1.6, 0.9, 1.6), mid, 0.0],
		["rear_left", mid + Vector3(-1.4, 0.6, 2.0), mid + Vector3(0, 0, 0.2), 0.0],
		["muzzles", Vector3(0.14, 0.09, -1.34), Vector3(0, 0.02, -1.04), 0.0],
		["lock", Vector3(0.34, 0.13, -0.05), Vector3(0.02, 0.03, -0.13), 0.0],
		["lock_half_turned", Vector3(0.34, 0.13, -0.05), Vector3(0.02, 0.03, -0.13), 90.0],
		["breech_below", Vector3(0.28, -0.22, -0.02), Vector3(0.0, 0.0, -0.13), 0.0],
	]
	var imgs := []
	var barrels := model.get_node("Barrels") as Node3D
	var rest := barrels.transform
	for v: Array in views:
		barrels.transform = Transform3D(rest.basis * Basis(Vector3.BACK, deg_to_rad(float(v[3]))), rest.origin)
		cam.position = v[1]
		cam.look_at(v[2], Vector3.UP if absf((v[2] - v[1]).normalized().y) < 0.99 else Vector3.FORWARD)
		cam.fov = 30 if String(v[0]) in ["right", "left", "top", "three_quarter", "rear_left"] else 40
		var img := await _grab()
		imgs.append(img)
	_sheet(imgs, 3, Vector2i(800, 450), "turnaround")
	w.free()
	stage.queue_free()
	await _frames(2)


# --- In the hands -------------------------------------------------------------------------

func _held() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(2)
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(20)
	var w := OverUnderKit.select(player)
	await _frames(90)
	var sheet := []
	# Musket first, for comparison.
	player.switch_weapon("musket")
	await _frames(90)
	Input.action_press("aim")
	await _frames(80)
	sheet.append_array(await _views(player, "musket_aim"))
	Input.action_release("aim")
	await _frames(40)
	OverUnderKit.select(player)
	await _frames(100)
	Input.action_press("aim")
	await _frames(80)
	sheet.append_array(await _views(player, "held_aim", ["play", "side", "lock"]))
	Input.action_release("aim")
	await _frames(40)
	# Carry (lowered).
	await _views(player, "held_carry")
	# Fire the top barrel (A) and let the smoke clear (Fx smoke lingers about 5 s).
	Input.action_press("fire")
	for i in 120:
		await process_frame
		if w.aim >= 1.0:
			break
	Input.action_release("fire")
	await _frames(420)
	# Mid turnover: LMB with [○, ●] turns the barrels over. Slow motion while the views are taken
	# (not 0: the game divides by delta in places), so the barrels stay near 90 deg.
	Input.action_press("fire")
	await _frames(2)
	Input.action_release("fire")
	for i in 120:
		if w.turning and w.turn_progress > 0.5:
			break
		await process_frame
	Engine.time_scale = 0.02
	sheet.append_array(await _views(player, "held_turning", ["play", "side", "lock"]))
	Engine.time_scale = 1.0
	# RMB during the turnover: no shot after it, so barrel B comes up loaded for the crouched aim.
	Input.action_press("aim")
	await _frames(2)
	Input.action_release("aim")
	await _frames(150)
	print("after the turnover: ", w.ammo_text(), " / ", w.status_text())
	# Crouched aim.
	Input.action_press("crouch")
	await _frames(2)
	Input.action_release("crouch")
	await _frames(40)
	Input.action_press("aim")
	await _frames(80)
	sheet.append_array(await _views(player, "held_aim_crouch", ["side"]))
	Input.action_release("aim")
	_sheet(sheet, 3, Vector2i(640, 360), "held_sheet")


## play (game camera), side, front close-ups of the character, like tests/screenshot.gd.
func _views(player: FrontierPlayer, tag: String, which: Array = ["play", "side", "front"]) -> Array:
	var imgs := []
	if "play" in which:
		var im := await _grab()
		_save(im, tag + "_play")
		imgs.append(im)
	var cam := Camera3D.new()
	cam.fov = 32
	current_scene.add_child(cam)
	var center := player.global_position + Vector3(0, 1.25 if not player.is_crouching else 0.85, 0)
	for v: Array in [["side", Vector3(2.4, 0.25, -0.35)], ["front", Vector3(0.9, 0.35, -2.6)]]:
		if not String(v[0]) in which:
			continue
		cam.global_position = center + player.global_basis * v[1]
		cam.look_at(center + player.global_basis * Vector3(0, 0, -0.35))
		cam.current = true
		var im := await _grab()
		_save(im, "%s_%s" % [tag, v[0]])
		imgs.append(im)
	var model: Node3D = player.weapon.model if player.weapon else null
	if "lock" in which and model:
		# The breech from the lock side and a little ahead: lock, both pans, the catch, the hands.
		var mx := model.global_transform
		cam.fov = 30
		cam.global_position = mx * Vector3(0.30, 0.07, -0.62)
		cam.look_at(mx * Vector3(0.0, 0.01, -0.17), mx.basis.y.normalized())
		cam.current = true
		var im := await _grab()
		_save(im, "%s_lock" % tag)
		imgs.append(im)
	cam.queue_free()
	player.camera.current = true
	return imgs
