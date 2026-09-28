extends SceneTree
## Stills of the wound trails' looks (WildlifeSpecies.WOUNDS, WildlifeSpawner.DROP_LOOKS; user 2026-09-28: "do that"),
## side by side, laid by the real drop code at each wound's typical bleeding (a deer running off at 6 m/s): left to
## right heart, lungs, gut, leg, graze; on the range lane's dirt and on the grass beside it. No text on the pictures.
##   Godot --path . -s tools/wildlife/blood_look_shots.gd -- wildlife=on out=<dir> [size=1600x900]

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
## [look, bleeding (health a second) at the start, clot] as an arrow of 30 (x the wound's mult) leaves them.
const TRAILS := [
	["red", 7.9, 0.0],        # heart
	["froth", 3.0, 0.0],      # lungs
	["gut", 0.36, 0.0],       # gut
	["red", 1.35, 0.035],     # leg
	["red", 0.6, 0.12],       # graze
]

var out := ""
var size := Vector2i(1600, 900)
var view
var w: WildlifeSpawner


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("size="):
			var wh := a.substr(5).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var lvl := current_scene
	var p := lvl.get_node("Player") as FrontierPlayer
	w = lvl.get_node_or_null("Wildlife") as WildlifeSpawner
	p.ignore_mouse_capture = true
	var rig := lvl.get_node_or_null("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(11.0)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, size)
	root.disable_3d = true
	if p.hud:
		p.hud.visible = false
	var tries := 0
	while (p.traversal == null or not p.traversal.world_ready) and tries < 2000:
		await process_frame
		tries += 1
	# the animals away from the lane
	for a in w.animals():
		a.global_position = Vector3(-250.0, FrontierTerrain.height_at(-250.0, 250.0), 250.0)
	var dirt := Vector3(-4.0, 0.0, -100.0)
	var grass := Vector3(20.0, 0.0, -100.0)
	p.global_position = Vector3(8.0, FrontierTerrain.height_at(8.0, -96.0) + 0.1, -96.0)
	p.visible = false
	_lay(dirt)
	_lay(grass)
	for i in 40:
		await process_frame
	await _shot(dirt + Vector3(4.0, 1.7, 3.0), dirt + Vector3(4.0, 0.0, -6.0), "trails_dirt")
	await _shot(dirt + Vector3(4.0, 3.4, -2.0), dirt + Vector3(4.0, 0.0, -7.0), "trails_dirt_above")
	await _shot(dirt + Vector3(0.0, 1.1, -1.5), dirt + Vector3(0.0, 0.0, -3.5), "closeup_heart")
	await _shot(dirt + Vector3(2.0, 1.1, -1.5), dirt + Vector3(2.0, 0.0, -3.5), "closeup_lungs")
	await _shot(dirt + Vector3(4.0, 1.1, -1.5), dirt + Vector3(4.0, 0.0, -3.5), "closeup_gut")
	await _shot(grass + Vector3(4.0, 1.7, 3.0), grass + Vector3(4.0, 0.0, -6.0), "trails_grass")
	print("BLOOD LOOK SHOTS DONE")
	quit()


## The five trails from `at`, 2 m apart, 12 m long (on toward -z).
func _lay(at: Vector3) -> void:
	for i in TRAILS.size():
		var t: Array = TRAILS[i]
		var rate := float(t[1])
		var x := at.x + float(i) * 2.0
		# the hit's splash
		w.blood_splash(Vector3(x, FrontierTerrain.height_at(x, at.z), at.z), Vector3.FORWARD, null, String(t[0]))
		var z := 0.0
		var gap := 0.0
		var dt := 1.0 / 30.0
		while z < 12.0:
			z += 6.0 * dt
			gap += 6.0 * dt
			rate *= maxf(1.0 - float(t[2]) * dt, 0.0)
			if gap > clampf(2.5 / (0.5 + rate), 0.45, 4.0):
				gap = 0.0
				var q := Vector3(x + randf_range(-0.2, 0.2), 0.0, at.z - 1.0 - z)
				w.blood_drop(q, clampf(0.6 + rate * 0.22, 0.6, 2.2), null, String(t[0]))


func _shot(from: Vector3, look: Vector3, name: String) -> void:
	from.y += FrontierTerrain.height_at(from.x, from.z)
	look.y += FrontierTerrain.height_at(look.x, look.z)
	view.camera.global_position = from
	view.camera.look_at(look, Vector3.UP)
	view.camera.fov = 60.0
	for i in 12:
		await process_frame
	var img: Image = view.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
