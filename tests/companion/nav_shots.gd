extends SceneTree
## PATHS, windowed look-check: the baked navigation mesh round the fort (NavWorld.show_debug) from above: the gate, the cabin and the
## storehouse doors; then the wife walking from inside the cabin out through the gate toward a woods spot, her path drawn as a line.
##   Godot --path . --resolution 1280x720 -s tests/companion/nav_shots.gd -- out=<abs dir> survival=on fort_plan=on
var out := ""
var h: Household
var nav_w: NavWorld
var cam: Camera3D
var _target := Vector3.ZERO
var _driving := false


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


func _shot(name: String, at: Vector3, from: Vector3, ortho := 0.0) -> void:
	if cam == null:
		cam = Camera3D.new()
		current_scene.add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL if ortho > 0.0 else Camera3D.PROJECTION_PERSPECTIVE
	if ortho > 0.0:
		cam.size = ortho
	cam.global_position = from
	cam.look_at(at, Vector3.UP if absf((at - from).normalized().y) < 0.99 else Vector3.FORWARD)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _errand(_dt: float) -> Variant:
	if not _driving:
		return null
	return h.body.walk_to(_target, Spouse.WALK_SPEED)


func _line(pts: PackedVector3Array, col: Color) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	for p in pts:
		im.surface_add_vertex(p + Vector3.UP * 0.15)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	current_scene.add_child(mi)
	return mi


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for i in 20:
		await physics_frame
	var player := current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	for i in 600:
		await physics_frame
		h = Household.find(self)
		if h != null and h.body != null:
			break
	nav_w = NavWorld.of(self)
	player.global_position = Vector3(3.0, 0.1, 12.0)
	for i in 20 * 60:
		await physics_frame
		if nav_w.ready_count() >= 25 and nav_w.baking() == 0:
			break
	print("tiles ready ", nav_w.ready_count(), " stats ", nav_w.stats)
	h.set_role("stay")
	var b := h.body
	b.global_position = Vector3(-8.0, 0.1, 6.6)
	for i in 30:
		await physics_frame
	var woods := Vector3(-14.0, 0.0, -48.0)
	woods.y = FrontierTerrain.height_at(woods.x, woods.z)
	woods = nav_w.snap(woods)
	var p := nav_w.path(b.global_position, woods)
	nav_w.show_debug(true)
	var ln := _line(p, Color(1.0, 0.2, 0.1))
	for i in 10:
		await physics_frame
	await _shot("nav_fort_top", Vector3(0, 0, -2), Vector3(0, 80, -2.01), 44.0)
	await _shot("nav_gate_top", Vector3(0, 0, -16), Vector3(0, 40, -15.99), 12.0)
	await _shot("nav_cabin_top", Vector3(-8, 0, 7), Vector3(-8, 40, 7.01), 12.0)
	# round the hearth in the yard (a visitor's last steps home)
	var hp := nav_w.path(nav_w.snap(Vector3(1.5, 0.0, 4.0)), nav_w.snap(Vector3(-2.3, 0.0, 3.7)))
	print("hearth path ", hp)
	var ln2 := _line(hp, Color(1.0, 0.9, 0.1))
	await _shot("nav_hearth_top", Vector3(0, 0, 6), Vector3(0, 40, 6.01), 18.0)
	ln2.queue_free()
	nav_w.show_debug(false)
	# her walk: out of the cabin, through the gate
	_target = woods
	_driving = true
	b.errand = _errand
	var shot := false
	for i in 120 * 90:
		await physics_frame
		if b.errand != Callable(self, "_errand"):
			b.errand = _errand
		if not shot and b.global_position.z < -12.0 and absf(b.global_position.x) < 4.0:
			shot = true   # coming up to the gate, from inside the yard
			await _shot("worker_gate_in", b.global_position + Vector3(0, 1.0, -1.0), b.global_position + Vector3(2.5, 2.8, 5.0))
		if b.global_position.z < -17.2:
			break
	# out through it: from outside, the gate behind her
	await _shot("worker_gate_out", b.global_position + Vector3(0, 1.2, 1.5), b.global_position + Vector3(4.0, 2.6, -6.0))
	ln.queue_free()
	_driving = false
	quit(0)
