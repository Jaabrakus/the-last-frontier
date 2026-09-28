extends SceneTree
## Look-check stills of the beds, racks and crafting stations (windowed, survival on; wrap it in a time limit):
##
##   Godot --path . --resolution 1280x720 -s tests/survival_game/stations_shots.gd -- --no-capture survival=on out=<dir>
##
## Built through build mode east of the fort: a campfire with the drying rack over it (venison strips hanging), the
## tanning frame, the alchemy table, a bough bed and a pole bed, a musket rack and a spear barrel with weapons in them.
## Ends with STATIONS SHOTS DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var out := "user://stations_shots"
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
	for k in [["stone", 12], ["firewood", 12], ["pole", 40], ["branches", 40], ["log", 8], ["deer_hide", 3]]:
		inv.add(k[0], k[1])
	player.inventory_pack = inv.pack.duplicate(true)
	var mode := player.get_node("BuildMode") as BuildMode
	var spot := Vector3(24.0, 0.0, 10.0)
	var plan := [["campfire", Vector3(0, 0, 0)], ["drying_rack", Vector3(0, 0, 0)], ["tanning_frame", Vector3(4.0, 0, -0.5)],
			["alchemy_table", Vector3(-3.2, 0, 0)], ["bough_bed", Vector3(-1.5, 0, 6.0)], ["pole_bed", Vector3(1.5, 0, 6.0)],
			["musket_rack", Vector3(6.5, 0, 5.0)], ["spear_barrel", Vector3(8.6, 0, 5.0)]]
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
	player.global_position = spot + Vector3(0, 0.2, 14.0)
	player.global_position.y = FrontierTerrain.height_at(player.global_position.x, player.global_position.z) + 0.1
	# the fire lit, meat on the rack, weapons in the racks
	var cf := (built.campfire as BuiltPiece).get_node("Campfire") as Campfire
	cf.light()
	if b:
		var st := (built.drying_rack as BuiltPiece).get_node("Station") as CampStation
		SurvivalCamp.rack_at(b.core, st.tag(), true).hanging.append({"id": "item.food.jerky", "qty": 8.0, "meta": {}, "ready_at": b.core.state.minutes + 900.0})
	for spec in [["musket_rack", "musket", 3], ["spear_barrel", "spear_pair", 3]]:
		var rp: BuiltPiece = built.get(spec[0])
		var w: Weapon = player.weapons.get("musket" if spec[1] == "musket" else "spear")
		if rp == null or w == null:
			continue
		var rack := rp.get_node("Rack") as WeaponRack
		for i in int(spec[2]):
			var pw := PlacedWeapon.from_weapon(w, "musket" if spec[1] == "musket" else "spear")
			pw.state = WeaponState.capture(w)
			if w is Throwable:
				pw.state.count = 1
			current_scene.add_child(pw)
			rack.place(pw, i + (1 if spec[0] == "musket_rack" else 0))
	await _frames(120)
	var g := func(v: Vector3) -> Vector3: return Vector3(v.x, FrontierTerrain.height_at(v.x, v.z) + v.y, v.z)
	await _shot("stations_overview", g.call(spot + Vector3(1.0, 5.0, 13.0)), g.call(spot + Vector3(1.5, 0.3, 2.5)), 60.0)
	await _shot("drying_rack_fire", g.call(spot + Vector3(2.4, 1.6, 2.6)), g.call(spot + Vector3(0, 0.9, 0)))
	await _shot("tanning_frame", g.call(spot + Vector3(5.2, 1.6, 2.6)), g.call(spot + Vector3(4.3, 0.9, -0.5)))
	await _shot("alchemy_table", g.call(spot + Vector3(-2.4, 1.6, 1.8)), g.call(spot + Vector3(-3.2, 0.85, 0)))
	await _shot("beds", g.call(spot + Vector3(0.0, 2.2, 9.6)), g.call(spot + Vector3(0.0, 0.2, 6.0)))
	await _shot("racks", g.call(spot + Vector3(7.5, 1.5, 8.0)), g.call(spot + Vector3(7.5, 0.6, 5.0)))
	print("STATIONS SHOTS DONE")
	quit()
