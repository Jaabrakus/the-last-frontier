extends SceneTree
## Import a local source GLB directly, even under an ignored artifact directory.
## -- model.glb output-directory [check]
## Reference viewer only; does not modify the playable character or camera.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		quit(1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(args[0], state)
	if error != OK:
		push_error("GLB load failed: %s" % error)
		quit(1)
		return
	var character := document.generate_scene(state) as Node3D
	if character == null:
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(character)
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	var meshes := character.find_children("*", "MeshInstance3D", true, false)
	var count := 0
	for skeleton: Skeleton3D in skeletons:
		count += skeleton.get_bone_count()
	print("Reference character imported: %d skeleton bones, %d meshes" % [count, meshes.size()])
	if count < 1 or meshes.is_empty():
		quit(1)
		return
	if args.size() > 2 and args[2] == "check":
		quit()
		return
	DirAccess.make_dir_recursive_absolute(args[1])
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a6b9b7")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d1e1e7")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var environment_node := WorldEnvironment.new()
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -40, 0)
	light.light_color = Color("fff0d0")
	light.light_energy = 1.3
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 30
	camera.near = 0.02
	await process_frame
	# Face/upper head avoids presenting incomplete default armor as a full costume.
	var focus := Vector3(0, 1.57, 0)
	for shot in [{"name": "front", "eye": Vector3(0, 1.59, 1.25)}, {"name": "three_quarter", "eye": Vector3(0.72, 1.62, 1.1)}, {"name": "side", "eye": Vector3(1.25, 1.59, 0.12)}]:
		camera.position = shot.eye
		camera.look_at(focus)
		for _frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		error = image.save_png(args[1].path_join("source_" + shot.name + ".png"))
		if error != OK:
			quit(1)
			return
	print("REFERENCE CHARACTER PREVIEW DONE")
	quit()
