extends SceneTree
## Look-check stills of the wild horses (WildHorse, HorseBreaking) in the level (windowed; wrap it in a time limit, a
## script error leaves the window open):
##
##   Godot --path . --resolution 1280x720 -s tests/wildlife/wild_horse_shots.gd -- --no-capture wildlife=on out=<dir>
##
## Views: the fort's band grazing, a mare and the stallion broadside (the head down to the grass), a caught horse
## bucking with the player on it and rearing, the horse broken (a bridle, no saddle), and a dead one on its side. Saves
## <out>/<view>.png and <out>/sheet.png. Ends with WILD HORSE SHOTS DONE. Frames go through an off-window SubViewport
## (tools/environment/offscreen_view.gd), as tests/wildlife/wildlife_shots.gd.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var args := {}
var view: OffscreenView
var w: WildlifeSpawner
var player: FrontierPlayer
## Called every frame while a shot settles (holds a pose).
var _hold := Callable()


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
	var out: String = args.get("out", "user://wild_horse_shots")
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player.hud:
		player.hud.visible = false
	w = current_scene.get_node("Wildlife") as WildlifeSpawner
	w._restock_t = 1e9
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	var rig := current_scene.get_node_or_null("EnvironmentRig")
	if rig and rig.has_method("get_camera_attributes") and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(150)
	var band := _band()
	if band == null:
		print("no band")
		quit(1)
		return
	var images: Array[Image] = []
	# 1. the band grazing, from 26 m, the player far off behind the camera
	var c := band.centroid()
	var away := Vector3(1.0, 0.0, 0.4).normalized()
	_park(c + away * 180.0)
	for a in band.alive():
		a.awareness = 0.0
		a.fatigue = 0.1
		a.hunger = 0.9
	band.activity = WildGroup.Activity.FEED
	band.dest = c
	band.dest_set = true
	await _frames(600)
	c = band.centroid()
	var cam := c + away * 26.0
	cam.y = FrontierTerrain.height_at(cam.x, cam.z) + 2.2
	images.append(await _shot(out, "band_grazing", cam, c + Vector3.UP * 0.8, 40.0, 30))
	# 2-3. a mare and the stallion broadside, grazing
	for sp in ["horse", "stallion"]:
		var h := _pick(band, sp)
		if h:
			h.set_physics_process(false)
			h._play("graze")
			images.append(await _side(out, "%s_grazing" % sp, h, 6.5, 150))
			h.set_physics_process(true)
	# 4-5. caught: bucking (held at the buck's height), then rearing, the player on it
	var wild := _pick(band, "horse")
	if wild == null:
		wild = band.alive()[0] as WildHorse
	wild.fatigue = 0.9
	player.global_position = _on(wild.global_position + wild.global_basis.x * 1.2)
	player.grip.stamina = player.grip.stamina_max
	await _frames(2)
	HorseBreaking.begin(wild, player)
	var horse := player.riding
	var b := horse.get_node_or_null(^"Breaking") as HorseBreaking if horse else null
	if b:
		b.set_physics_process(false)
		await _frames(30)
		_hold = func() -> void:
			b._pitch = -28.0
			b._hop = 0.2
			b._pose()
		images.append(await _side_of(out, "bucking", horse, 5.5, 60))
		_hold = func() -> void:
			b._pitch = 0.0
			b._hop = 0.0
			b._pose()
		horse.request_rear()
		await _frames(int(horse.clip_length("rear") * 0.4 * 60.0))
		images.append(await _side_of(out, "rearing", horse, 6.0, 2))
		_hold = Callable()
		# 6. broken: the rope bridle, no saddle, the rider on it
		b.set_physics_process(true)
		b.spirit = 0.0
		b._end("broken")
		await _frames(60)
		images.append(await _side_of(out, "broken", horse, 5.0, 60))
		player.dismount()
	# 7. a dead one on its side
	var dead := _pick(band, "horse")
	if dead == null and not band.alive().is_empty():
		dead = band.alive()[0] as WildHorse
	if dead:
		dead.apply_hit(5000.0, dead.global_position + Vector3.UP * 1.0, Vector3.RIGHT, player, "body")
		_park(dead.global_position + Vector3(40.0, 0.0, 40.0))
		await _frames(120)
		var dc := dead.global_position + Vector3(4.0, 0.0, 3.0)
		dc.y = FrontierTerrain.height_at(dc.x, dc.z) + 1.6
		images.append(await _shot(out, "carcass", dc, dead.global_position + Vector3.UP * 0.3, 45.0, 10))
	if images.size() > 1:
		_sheet(images, out.path_join("sheet.png"))
	print("WILD HORSE SHOTS DONE")
	quit()


func _band() -> WildGroup:
	for e in w.groups:
		var g: WildGroup = e.group
		if String(e.kind) == "horse_herd" and WorldSquares.square_at(g.home) == Vector2i.ZERO and g.alive().size() >= 3:
			return g
	return null


func _pick(g: WildGroup, sp: String) -> WildHorse:
	for a in g.alive():
		if a.species == sp and not a.get_meta("shot", false):
			a.set_meta("shot", true)
			return a as WildHorse
	return null


func _on(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z) + 0.1, p.z)


func _park(at: Vector3) -> void:
	player.global_position = _on(at)
	player.velocity = Vector3.ZERO


## The animal broadside from `dist` m, the player parked well off (out of its sight).
func _side(out: String, name: String, a: WildAnimal, dist: float, settle := 90) -> Image:
	var fwd := -a.global_basis.z
	var side := fwd.cross(Vector3.UP).normalized()
	_park(a.global_position + side * 90.0)
	a.awareness = 0.0
	var cam := a.global_position + side * dist + Vector3.UP * 1.3 + fwd * dist * 0.15
	return await _shot(out, name, cam, a.global_position + Vector3.UP * 0.8, 45.0, settle)


## A ridden horse broadside from `dist` m, following it.
func _side_of(out: String, name: String, h: Node3D, dist: float, settle := 60) -> Image:
	var fwd := -h.global_basis.z
	var side := fwd.cross(Vector3.UP).normalized()
	var cam := h.global_position + side * dist + Vector3.UP * 1.5 + fwd * dist * 0.1
	return await _shot(out, name, cam, h.global_position + Vector3.UP * 1.2, 45.0, settle)


func _shot(out: String, name: String, cam_pos: Vector3, target: Vector3, fov: float, settle: int) -> Image:
	var cam: Camera3D = view.camera
	view.source = null
	cam.fov = fov
	for i in settle:
		cam.global_position = cam_pos
		cam.look_at(target)
		if _hold.is_valid():
			_hold.call()
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
	if _hold.is_valid():
		_hold.call()
	view.sync_camera()
	RenderingServer.force_draw(false)
	var img: Image = view.get_texture().get_image()
	var path := out.path_join("%s.png" % name)
	img.save_png(path)
	print("saved ", path)
	return img


func _frames(n: int) -> void:
	for i in n:
		if _hold.is_valid():
			_hold.call()
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


func _sheet(images: Array[Image], path: String) -> void:
	var wd := images[0].get_width() / 2
	var ht := images[0].get_height() / 2
	var cols := 3
	var rows := ceili(images.size() / float(cols))
	var sheet := Image.create(wd * cols, ht * rows, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im := images[i].duplicate() as Image
		im.convert(Image.FORMAT_RGBA8)
		im.resize(wd, ht, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, wd, ht), Vector2i((i % cols) * wd, (i / cols) * ht))
	sheet.save_png(path)
	print("saved ", path)
