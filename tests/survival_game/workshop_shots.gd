extends SceneTree
## Look-check stills of the workbench, the stretching hoop (a pelt drying in it), the storage chest (open) and the
## hearth burning (windowed, survival on; wrap it in a time limit):
##
##   Godot --path . --resolution 1280x720 -s tests/survival_game/workshop_shots.gd -- --no-capture survival=on out=<dir>
##
## Ends with WORKSHOP SHOTS DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var out := "user://workshop_shots"
var view: OffscreenView
var player: FrontierPlayer
var built := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


func _shot(name: String, pos: Vector3, target: Vector3, fov := 55.0, settle := 40) -> void:
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
	view.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", out.path_join(name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	if player.hud:
		player.hud.visible = false
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, DisplayServer.window_get_size())
	root.disable_3d = true
	var rig := current_scene.get_node("EnvironmentRig") as EnvironmentRig
	if rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	var b := SurvivalBridge.find(self)
	var inv := InventoryState.from_player(player)
	for k in [["stone", 20], ["firewood", 6], ["pole", 12], ["branches", 12], ["log", 8]]:
		inv.add(k[0], k[1])
	player.inventory_pack = inv.pack.duplicate(true)
	var mode := player.get_node("BuildMode") as BuildMode
	var spot := Vector3(24.0, 0.0, 10.0)
	var plan := [["hearth", Vector3(-3.5, 0, 0)], ["workbench", Vector3(2.0, 0, 0)], ["stretching_hoop", Vector3(5.0, 0, 0)],
			["storage_chest", Vector3(0.0, 0, 3.0)], ["woodpile", Vector3(-3.5, 0, 2.6)], ["smokehouse", Vector3(8.5, 0, 3.5)]]
	for e in plan:
		var at: Vector3 = spot + (e[1] as Vector3)
		at.y = FrontierTerrain.height_at(at.x, at.z)
		player.global_position = at + Vector3(0, 0.1, 4.0)
		await _frames(6)
		mode.set_active(true)
		mode.select_type(String(e[0]))
		mode.aim_at = at
		await _frames(8)
		mode.refresh_placement()
		var p := mode.place()
		if p == null:
			print("  not placed: %s (%s)" % [e[0], mode.verdict.get("reason", "")])
		built[String(e[0])] = p
		mode.set_active(false)
	mode.aim_at = Vector3.INF
	# the hearth laid and lit, a pelt on the hoop, the chest open
	var hf := (built.hearth as BuiltPiece).get_node("Campfire") as Campfire
	player.global_position = hf.global_position + Vector3(1.0, 0.1, 1.2)
	await _frames(6)
	hf.interact(player)
	hf.interact(player)
	hf.interact(player)
	if b:
		var st := (built.stretching_hoop as BuiltPiece).get_node("Station") as CampStation
		st.hoop_record().append({"id": "item.pelt.wolf", "meta": {"grade": "good"}, "pelt": "wolf_pelt", "hung_at": b.core.state.minutes,
				"ready_at": b.core.state.minutes + 3000.0})
	((built.storage_chest as BuiltPiece).get_node("Chest") as StorageChest).open = true
	var wp := (built.woodpile as BuiltPiece).get_node("Woodpile") as Woodpile
	wp.from_save(14)
	var sm := (built.smokehouse as BuiltPiece).get_node("Smokehouse") as Smokehouse
	var inv2 := InventoryState.from_player(player)
	inv2.add("venison", 3)
	inv2.add("firewood", 3)
	sm.put(inv2, "venison", 3)
	player.inventory_pack = inv2.pack.duplicate(true)
	sm.lay_wood(player)
	sm.tick()
	player.global_position = spot + Vector3(0, 0.2, 12.0)
	player.global_position.y = FrontierTerrain.height_at(player.global_position.x, player.global_position.z) + 0.1
	await _frames(150)
	var g := func(v: Vector3) -> Vector3: return Vector3(v.x, FrontierTerrain.height_at(v.x, v.z) + v.y, v.z)
	await _shot("workshop_overview", g.call(spot + Vector3(1.0, 3.2, 8.5)), g.call(spot + Vector3(0.8, 0.6, 0.5)), 60.0)
	await _shot("hearth_fire", g.call(spot + Vector3(-2.3, 1.4, 2.8)), g.call(spot + Vector3(-3.5, 0.9, 0.6)))
	await _shot("workbench", g.call(spot + Vector3(2.3, 1.6, 1.6)), g.call(spot + Vector3(2.0, 0.75, 0)))
	await _shot("stretching_hoop", g.call(spot + Vector3(5.6, 1.4, 2.2)), g.call(spot + Vector3(5.0, 1.0, 0)))
	await _shot("storage_chest", g.call(spot + Vector3(0.9, 1.3, 4.4)), g.call(spot + Vector3(0.0, 0.35, 3.0)))
	await _shot("woodpile", g.call(spot + Vector3(-2.2, 1.5, 4.6)), g.call(spot + Vector3(-3.5, 0.5, 2.0)))
	await _shot("smokehouse", g.call(spot + Vector3(9.6, 1.6, 7.6)), g.call(spot + Vector3(8.5, 1.1, 3.5)))
	# fireflies at night over the patch nearest the fort
	var ff := current_scene.get_node_or_null("Fireflies") as Fireflies
	var clock: WorldClock = rig.clock_driver.clock if rig.clock_driver else null
	if ff and not ff.patches.is_empty():
		var near: Vector3 = ff.patches[0]
		var bd := INF
		for q in ff.patches:
			if Vector2(q.x, q.z).length() < bd:
				bd = Vector2(q.x, q.z).length()
				near = q
		if b:
			b.core.advance(12.0 * 60.0)
		ff.sun_override = -10.0
		player.global_position = near + Vector3(6.0, 0.2, 14.0)
		player.global_position.y = FrontierTerrain.height_at(player.global_position.x, player.global_position.z) + 0.1
		await _frames(600)
		var cam := near + Vector3(7.0, 0.0, 2.0)
		cam.y = FrontierTerrain.height_at(cam.x, cam.z) + 1.5
		var look := near + Vector3(-4.0, 0.0, -1.0)
		look.y = FrontierTerrain.height_at(look.x, look.z) + 1.5
		await _shot("fireflies_night", cam, look, 70.0, 30)
	print("WORKSHOP SHOTS DONE")
	quit()
