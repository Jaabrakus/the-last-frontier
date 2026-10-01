extends SceneTree
## Stills of the skeleton map on a body going down: the player shot dead (a ragdoll), and a deer.
##   Godot --path . -s tools/fx/anatomy_shots.gd -- shots=/some/dir        (a window: stills are drawn)
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
var shots := ""
var view
var p: FrontierPlayer


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots = a.substr(6)
	_run.call_deferred()


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(nm: String, focus: Vector3, off: Vector3) -> void:
	view.camera.global_transform = Transform3D(Basis.looking_at(focus - (focus + off), Vector3.UP), focus + off)
	view.camera.fov = 45.0
	for i in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	(view.get_texture().get_image() as Image).save_png(shots.path_join(nm + ".png"))


func _run() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	var yard := current_scene.get("yard") as ClimbYard
	yard.giant.paces = false
	DirAccess.make_dir_recursive_absolute(shots)
	root.content_scale_size = Vector2i(1280, 720)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1280, 720))
	root.disable_3d = true
	var at := Vector3(0.0, 0.0, -140.0)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	p.global_position = at
	await _fr(120)
	var hips := func() -> Vector3:
		return p.skeleton.global_transform * p.skeleton.get_bone_global_pose(p.skeleton.find_bone("root")).origin
	Anatomy.attach_to(p.skeleton)
	Anatomy.set_shown(true, self)
	var f0 := -p.global_basis.z
	var s0 := p.global_basis.x
	await _shot("alive_front", hips.call() + Vector3(0, 0.45, 0), f0 * 1.9 + Vector3(0, 0.1, 0))
	await _shot("alive_side", hips.call() + Vector3(0, 0.45, 0), s0 * 1.9 + Vector3(0, 0.1, 0))
	# shot through the chest from the front, to the back
	var fwd := -p.global_basis.z
	p.health = 1.0
	p.apply_hit(70.0, p.global_position + Vector3.UP * 1.3 + fwd * 0.3, -fwd, null, "body")
	await _fr(30)
	await _shot("falling", hips.call(), Vector3(1.6, 0.8, 1.8))
	await _fr(150)
	await _shot("down", hips.call(), Vector3(0.9, 1.9, 0.9))
	await _fr(60)
	await _shot("down_side", hips.call(), Vector3(-1.4, 1.0, 0.4))
	quit()
