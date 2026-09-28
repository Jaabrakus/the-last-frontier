extends SceneTree
## Stills of blood drops as they age (WildlifeSpawner.drop_modulate; user 2026-09-28: "lets apply this drop age"): rows
## the looks (front to back: red, the lungs' froth, the gut's), columns the ages (left to right: fresh, 5, 10, 15, 30
## and 45 minutes), a few drops each, laid by the real drop code on the range lane's dirt. No text on the pictures.
##   Godot --path . -s tools/wildlife/drop_age_shots.gd -- wildlife=on out=<dir> [size=1600x900]

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const LOOKS := ["red", "froth", "gut"]
const AGES := [0.0, 300.0, 600.0, 900.0, 1800.0, 2700.0]

var out := ""
var size := Vector2i(1600, 900)


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
	var w := lvl.get_node_or_null("Wildlife") as WildlifeSpawner
	p.ignore_mouse_capture = true
	var rig := lvl.get_node_or_null("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(11.0)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, size)
	root.disable_3d = true
	if p.hud:
		p.hud.visible = false
	var tries := 0
	while (p.traversal == null or not p.traversal.world_ready) and tries < 2000:
		await process_frame
		tries += 1
	for a in w.animals():
		a.global_position = Vector3(-250.0, FrontierTerrain.height_at(-250.0, 250.0), 250.0)
	var at := Vector3(-3.0, 0.0, -100.0)
	p.global_position = Vector3(8.0, FrontierTerrain.height_at(8.0, -96.0) + 0.1, -96.0)
	p.visible = false
	w._age_t = 1e9                       # (held at the ages set here)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for r in LOOKS.size():
		for c in AGES.size():
			var n0 := w._drops.size()
			for k in 4:
				var q := at + Vector3(float(c) * 1.3 + rng.randf_range(-0.25, 0.25), 0.0, -float(r) * 1.3 + rng.randf_range(-0.25, 0.25))
				w.blood_drop(q, 1.3, null, String(LOOKS[r]))
			for i in range(n0, w._drops.size()):
				(w._drops[i] as Decal).modulate = WildlifeSpawner.drop_modulate(String(LOOKS[r]), float(AGES[c]))
	for i in 30:
		await process_frame
	await _shot(view, at + Vector3(3.2, 3.6, 2.2), at + Vector3(3.2, 0.0, -1.3), "ages", )
	await _shot(view, at + Vector3(3.2, 1.9, 1.6), at + Vector3(3.2, 0.0, -0.6), "ages_close")
	print("DROP AGE SHOTS DONE")
	quit()


func _shot(view, from: Vector3, look: Vector3, name: String) -> void:
	from.y += FrontierTerrain.height_at(from.x, from.z)
	look.y += FrontierTerrain.height_at(look.x, look.z)
	view.camera.global_position = from
	view.camera.look_at(look, Vector3.UP)
	view.camera.fov = 50.0
	for i in 12:
		await process_frame
	var img: Image = view.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
