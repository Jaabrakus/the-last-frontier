extends SceneTree
## Look-check stills of the wildlife in the level (windowed; wrap it in a time limit, a script error leaves the window
## open):
##
##   Godot --path . --resolution 1280x720 -s tests/wildlife/wildlife_shots.gd -- --no-capture wildlife=on out=<dir>
##
## Views: the range herd seen down the lane from the firing line (zoomed), a doe, a buck, a wolf and a fox from the
## side at a few metres, and a shot doe on the ground. Saves <out>/<view>.png and <out>/sheet.png. Ends with
## WILDLIFE SHOTS DONE. Frames go through an off-window SubViewport (tools/environment/offscreen_view.gd), as in
## tools/environment/scenic_shots.gd.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var args := {}
var view: OffscreenView
var w: WildlifeSpawner
var player: FrontierPlayer


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
	var out: String = args.get("out", "user://wildlife_shots")
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player.hud:
		player.hud.visible = false
	w = current_scene.get_node("Wildlife") as WildlifeSpawner
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	var rig := current_scene.get_node_or_null("EnvironmentRig")
	if rig and rig.has_method("get_camera_attributes") and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	await _frames(150)
	var images: Array[Image] = []
	# 1. the range herd from the firing line
	player.global_position = Vector3(0, FrontierTerrain.height_at(0, -14) + 0.1, -14)
	images.append(await _shot(out, "range_herd", Vector3(0, 1.7, -18.5), WildlifeSpawner.RANGE_HERD_HOME + Vector3.UP * 0.8, 18.0, 60))
	# 2-5. each species from the side
	for sp in ["deer", "stag", "wolf", "fox"]:
		var a := _pick(sp)
		if a == null:
			continue
		var dist: float = {"deer": 5.0, "stag": 5.5, "wolf": 4.5, "fox": 2.6}[sp]
		images.append(await _side(out, sp, a, dist))
	# 6. a doe shot through the vitals, on the ground
	var doe := _pick("deer")
	if doe:
		var zone: StaticBody3D = doe.get_node("Hit_vitals")
		Hit.deliver(zone, 150.0, zone.global_position, Vector3(1, 0, 0), player)
		images.append(await _side(out, "carcass", doe, 4.5, 150))
	# 7-8. field dressing: the player kneels over a fresh kill (the game camera), then the skinned carcass
	var kill := _pick("deer")
	if kill:
		var zk: StaticBody3D = kill.get_node("Hit_vitals")
		Hit.deliver(zk, 150.0, zk.global_position, Vector3(1, 0, 0), player)
		var side := (-kill.global_basis.z).cross(Vector3.UP).normalized()
		var at := kill.global_position + side * 1.3
		player.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
		await _frames(80)
		kill.interact(player)
		await _frames(150)
		images.append(await _player_view(out, "kneel_skinning", 40))
		await _frames(int(float(kill.data.skin_s) * 60.0))
		images.append(await _side(out, "skinned", kill, 3.5, 120))
	# 9-10. the food chain: a wolf pack at a kill, ravens circling and landing (a doe, the pack round it)
	var prey := _pick("deer")
	var pk: WildGroup = null
	for e: Dictionary in w.groups:
		if e.kind == "wolf_pack":
			pk = e.group
	if prey and pk:
		prey.apply_hit(500.0, prey.global_position + Vector3.UP * 0.6, Vector3(1, 0, 0), null, "body")
		var cpos := prey.global_position
		var i := 0
		for m in pk.alive():
			var q := cpos + Vector3(cos(i * 1.7), 0.0, sin(i * 1.7)) * 1.4
			m.global_position = Vector3(q.x, FrontierTerrain.height_at(q.x, q.z) + 0.02, q.z)
			m.hunger = 1.0
			m.set_active(true)
			i += 1
		pk.carcass = prey
		pk.activity = WildGroup.Activity.EAT
		pk.dest = cpos
		pk.dest_set = true
		var park := cpos + Vector3(60.0, 0.0, 30.0)
		player.global_position = Vector3(park.x, FrontierTerrain.height_at(park.x, park.z) + 0.1, park.z)
		prey.set_meta("died_at", w.now - 60.0)      # ravens come at once
		await _frames(900)
		var c1 := cpos + Vector3(6.0, 0.0, 4.5)
		c1.y = FrontierTerrain.height_at(c1.x, c1.z) + 1.8
		var ground := FrontierTerrain.height_at(cpos.x, cpos.z)
		images.append(await _shot(out, "wolves_at_kill", c1, Vector3(cpos.x, ground + 0.4, cpos.z), 50.0, 30))
		# the ravens: wait for them to land, then a low camera beside the kill, and one looking up at the circlers
		await _frames(2400)
		var landed: Vector3 = Vector3.INF
		var flying: Vector3 = Vector3.INF
		for r in get_nodes_in_group(&"ravens"):
			var rv := r as Raven
			if rv.carcass != prey:
				continue
			if rv.mode == Raven.Mode.PECK and landed == Vector3.INF:
				landed = rv.global_position
			elif rv.mode == Raven.Mode.CIRCLE and flying == Vector3.INF:
				flying = rv.global_position
		print("ravens: landed=", landed, " flying=", flying)
		var look := landed if landed != Vector3.INF else Vector3(cpos.x, ground + 0.3, cpos.z)
		var c2 := look + Vector3(3.2, 0.0, 2.4)
		c2.y = FrontierTerrain.height_at(c2.x, c2.z) + 0.8
		images.append(await _shot(out, "ravens_at_kill", c2, look + Vector3.UP * 0.15, 45.0, 10))
		if flying != Vector3.INF:
			var c3 := Vector3(cpos.x + 3.0, 0.0, cpos.z + 3.0)
			c3.y = FrontierTerrain.height_at(c3.x, c3.z) + 1.6
			images.append(await _shot(out, "ravens_circling", c3, flying, 55.0, 2))
	# 11. the new items' inventory icons, side by side
	var icons := ItemIcons.shared(self)
	var kinds := ["skinning_knife", "venison", "deer_hide", "antler", "wolf_pelt", "fox_pelt"]
	for k in kinds:
		icons.get_icon(k)
	for i in 400:
		await process_frame
		var done := true
		for k in kinds:
			if icons.get_icon(k) == null:
				done = false
		if done:
			break
	var strip := Image.create(128 * kinds.size(), 128, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.18, 0.16, 0.14))
	for i in kinds.size():
		var tex := icons.get_icon(kinds[i])
		if tex:
			var im := tex.get_image()
			im.convert(Image.FORMAT_RGBA8)
			im.resize(128, 128)
			strip.blend_rect(im, Rect2i(0, 0, 128, 128), Vector2i(i * 128, 0))
	strip.save_png(out.path_join("icons.png"))
	print("saved ", out.path_join("icons.png"))
	if images.size() > 1:
		_sheet(images, out.path_join("sheet.png"))
	print("WILDLIFE SHOTS DONE")
	quit()


func _pick(sp: String) -> WildAnimal:
	for a in w.animals():
		if a.species == sp and not a.is_dead() and not a.get_meta("shot", false):
			a.set_meta("shot", true)
			return a
	return null


## The animal broadside from `dist` m, the player parked well behind the camera (still: out of the animal's sight).
func _side(out: String, name: String, a: WildAnimal, dist: float, settle := 90) -> Image:
	var fwd := -a.global_basis.z
	var side := fwd.cross(Vector3.UP).normalized()
	var h := float(a.data.body[2]) * 0.8
	var cam := a.global_position + side * dist + Vector3.UP * (h + 0.3) + fwd * dist * 0.15
	var park := a.global_position + side * 45.0
	player.global_position = Vector3(park.x, FrontierTerrain.height_at(park.x, park.z) + 0.1, park.z)
	a.awareness = 0.0
	return await _shot(out, name, cam, a.global_position + Vector3.UP * h * 0.8, 45.0, settle, a)


## Through the game camera (third person behind the player).
func _player_view(out: String, name: String, settle: int) -> Image:
	view.source = player.camera
	for i in settle:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
	view.sync_camera()
	RenderingServer.force_draw(false)
	var img: Image = view.get_texture().get_image()
	img.save_png(out.path_join("%s.png" % name))
	print("saved ", out.path_join("%s.png" % name))
	view.source = null
	return img


func _shot(out: String, name: String, cam_pos: Vector3, target: Vector3, fov: float, settle: int, follow: WildAnimal = null) -> Image:
	var cam: Camera3D = view.camera
	view.source = null
	cam.fov = fov
	for i in settle:
		if follow and is_instance_valid(follow):
			var fwd := -follow.global_basis.z
			var side := fwd.cross(Vector3.UP).normalized()
			var h := float(follow.data.body[2]) * 0.8
			var d := cam_pos.distance_to(target)
			cam.global_position = follow.global_position + side * d + Vector3.UP * (h + 0.3)
			cam.look_at(follow.global_position + Vector3.UP * h * 0.8)
		else:
			cam.global_position = cam_pos
			cam.look_at(target)
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
	view.sync_camera()
	RenderingServer.force_draw(false)
	var img: Image = view.get_texture().get_image()
	var path := out.path_join("%s.png" % name)
	img.save_png(path)
	print("saved ", path)
	return img


func _frames(n: int) -> void:
	for i in n:
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
