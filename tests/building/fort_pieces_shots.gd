extends SceneTree
## Look-check of the fort's build pieces (FortPieces), windowed: a palisade line with the firing step behind it, a ramp and a
## ladder, a blockhouse and a flag pole.
##   Godot --path . --resolution 1280x720 -s tests/building/fort_pieces_shots.gd -- out=<abs dir>
var out := ""
var player: FrontierPlayer


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


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _view(from: Vector3, look: Vector3) -> void:
	player.global_position = from
	player.velocity = Vector3.ZERO
	var to := look - from
	player.yaw = atan2(-to.x, -to.z)
	player.rotation.y = player.yaw
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	await _frames(60)
	var world := BuildWorld.of(self)
	var base := Vector3(21.0, 0.0, -6.0)
	var yaw := PI
	var basis := Basis(Vector3.UP, yaw)
	# a palisade line of four sections, the inside toward the viewer (+Z after the turn)
	var pals := []
	for i in 4:
		var xf := Transform3D(basis, base + basis.x * (i * 3.0))
		var g := PackedFloat32Array()
		g.resize(BuildGeometry.STAKES)
		pals.append(world.add_piece("palisade", xf, true, -1, g))
	var walks := []
	for i in 3:
		var p: BuiltPiece = pals[i]
		var xf := p.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.2)) * Transform3D(Basis(), Vector3(0, 0, FortPieces.WALK_D * 0.5))
		walks.append(world.add_piece("walkway", xf, true, -1))
	var w0: BuiltPiece = walks[0]
	var ramp_xf: Transform3D = w0.global_transform * Transform3D(Basis(), Vector3(0, 0, FortPieces.WALK_D * 0.5 + FortPieces.RAMP_RUN * 0.5))
	world.add_piece("walkway_ramp", ramp_xf, true, -1)
	var w2: BuiltPiece = walks[2]
	world.add_piece("ladder", w2.global_transform * Transform3D(Basis(), Vector3(0, 0, FortPieces.WALK_D * 0.5 + FortPieces.LADDER_OFF)), true, -1)
	world.add_piece("blockhouse", Transform3D(basis, base + basis.x * -4.5 + basis.z * -2.2 - Vector3(0, 0, 0)), true, -1)
	world.add_piece("flagpole", Transform3D(basis, base + basis.x * 10.0 + basis.z * 6.0), true, -1)
	await _frames(20)
	var mid := base + basis.x * 4.0
	var inside := -basis.z
	_view(mid + inside * 14.0 + basis.x * 3.0 + Vector3(0, 2.6, 0), mid + Vector3(0, 2.0, 0))
	await _shot("overview")
	_view(mid + inside * 8.0 + basis.x * 6.0 + Vector3(0, 1.9, 0), mid + inside * 2.0 + basis.x * 1.0 + Vector3(0, 1.5, 0))
	await _shot("walkway_ramp")
	_view(base + basis.x * 5.0 + inside * 5.5 + Vector3(0, 1.8, 0), base + basis.x * 6.5 + inside * 1.5 + Vector3(0, 2.4, 0))
	await _shot("ladder")
	_view(base + basis.x * -4.5 + inside * 14.0 + Vector3(0, 2.0, 0), base + basis.x * -4.5 + inside * 2.2 + Vector3(0, 3.5, 0))
	await _shot("blockhouse")
	print("FORT PIECE SHOTS DONE ", out)
	quit()
