extends SceneTree
## Stills of the skeleton map on animals, spawned on the climbing yard's flat ground (a window):
##   Godot --path . -s tools/fx/anatomy_animal_shots.gd -- shots=/some/dir
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
var shots := ""
var view


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots = a.substr(6)
	_run.call_deferred()


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	var p := current_scene.get_node("Player") as FrontierPlayer
	DirAccess.make_dir_recursive_absolute(shots)
	root.content_scale_size = Vector2i(1280, 720)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1280, 720))
	root.disable_3d = true
	var at := Vector3(0.0, 0.0, -140.0)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	p.global_position = at + Vector3(0, 0, 30)
	await _fr(60)
	for sp in ["deer", "wolf", "bison"]:
		var a := WildAnimal.new()
		a.species = sp
		current_scene.add_child(a)
		a.global_position = at
		a.rotation.y = PI * 0.5
		await _fr(20)
		a.set_active(false)
		var sk: Skeleton3D = a.get("_skel")
		Anatomy.attach_to(sk)
		Anatomy.set_shown(true, self)
		var h := float(a.data.body[2])
		var c := at + Vector3.UP * h * 0.5
		var side := Vector3(-0.35, 0.0, 0.94).normalized()
		var dist := maxf(h * 3.4, 4.0)
		var from := c + side * dist + Vector3.UP * h * 0.15
		view.camera.global_transform = Transform3D(Basis.looking_at(c - from, Vector3.UP), from)
		view.camera.fov = 45.0
		for i in 4:
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		(view.get_texture().get_image() as Image).save_png(shots.path_join("animal_%s.png" % sp))
		Anatomy.set_shown(false, self)
		a.queue_free()
		await _fr(5)
	quit()
