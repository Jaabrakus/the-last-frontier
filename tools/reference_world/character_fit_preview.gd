extends SceneTree
## Isolated verification of source meshes fitted onto Tidebreak's current Actor_B rig.
## No appearance saves, playable character assets, or shared runtime code are modified.
## Godot --path . -s tools/reference_world/character_fit_preview.gd -- \
##   hands=res://artifacts/world_reference/character_fit/link_hands_actor_b.glb \
##   [body=res://artifacts/world_reference/character_fit/link_body_actor_b.glb] \
##   out=res://artifacts/world_reference/character_fit/preview [check=1]
## Use --headless check=1 for structural/CPU skinning checks; render requires graphics.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const ReferenceParts := preload("res://tools/reference_world/reference_character_parts.gd")
const DEFAULT_HANDS := "res://artifacts/world_reference/character_fit/link_hands_actor_b.glb"
const DEFAULT_BODY := "res://artifacts/world_reference/character_fit/link_body_actor_b.glb"
const DEFAULT_OUT := "res://artifacts/world_reference/character_fit/preview"
const SIZE := Vector2i(960, 720)
const SAMPLES := [
	["idle", "actor_b/actor_b-p-stealth-idle", 0.3],
	["run", "actor_b/actor_b-p-run-fw", 0.3],
	["cast", "bend/own-bend-air-palm", 0.5],
	["grip", "boxing/own-style-boxing-jab", 0.5],
]
const WEAPON_SAMPLES := [
	["sword_grip", "actor_b/atk-actor_b-knife-v-thug-hit1-intro", 0.0],
	["spear_grip", "actor_b/atk-actor_b-knife-v-thug-hit1-intro", 0.0],
]
## Existing project saber generator's measured grip offset (tools/models/saber.py:48).
const PROP_GRIP := Transform3D(Basis(Vector3(-0.9397, 0.0915, -0.3295),
	Vector3(0.3256, -0.0551, -0.9439), Vector3(-0.1045, -0.9943, 0.0220)),
	Vector3(0.0057, 0.0059, -0.0060))

var args: Dictionary = {}
var output := ""
var world: Node3D
var view: SubViewport
var label: Label
var actors: Array[Dictionary] = []
var source_reports: Array[Dictionary] = []
var failures := PackedStringArray()
var checks := 0
var samples: Array[Dictionary] = []
var wanted_samples: Array = SAMPLES.duplicate()


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if "=" in arg:
			args[arg.get_slice("=", 0)] = arg.substr(arg.find("=") + 1)
	output = ProjectSettings.globalize_path(String(args.get("out", DEFAULT_OUT)))
	DirAccess.make_dir_recursive_absolute(output)
	if args.get("weapons", "0") == "1":
		wanted_samples.append_array(WEAPON_SAMPLES)
	if args.has("only"):
		wanted_samples = wanted_samples.filter(func(spec: Array) -> bool: return String(spec[0]) in String(args.only).split(","))
	await process_frame
	_stage()
	var hands_path := String(args.get("hands", DEFAULT_HANDS))
	var hands_scene := _load_glb(hands_path)
	if hands_scene == null:
		_finish()
		return
	actors.append(_current_actor("Current hands", null))
	actors.append(_current_actor("Fitted source hands", hands_scene))
	var body_path := String(args.get("body", DEFAULT_BODY))
	if FileAccess.file_exists(body_path):
		var body_scene := _load_glb(body_path)
		if body_scene:
			actors.append(_source_actor(body_scene))
	for actor: Dictionary in actors:
		_check_binding(actor)
		_check_weights(actor)
		_check_null_pose(actor)
		if args.get("weapons", "0") == "1":
			_install_weapon_models(actor)
	for spec: Array in wanted_samples:
		await _sample(spec)
	if args.get("weapons", "0") == "1":
		await _check_weapon_cast_swap()
	if args.get("check", "0") != "1" and failures.is_empty():
		await _render()
	_finish()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _stage() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#B9C7C3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#DBE4E5")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var environment := WorldEnvironment.new()
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32, -30, 0)
	light.light_color = Color("#FFF1D6")
	light.light_energy = 1.2
	world.add_child(light)
	if args.get("check", "0") == "1":
		return
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, SIZE)
	view.msaa_3d = Viewport.MSAA_4X
	view.camera.fov = 35.0
	view.camera.near = 0.01
	root.disable_3d = true
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color("#283D42"))
	view.add_child(label)


func _load_glb(path: String) -> PackedScene:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	_expect(error == OK, "load " + path)
	if error != OK:
		return null
	var node := document.generate_scene(state)
	_expect(node != null, "generate fitted scene")
	if node == null:
		return null
	var skeletons := node.find_children("*", "Skeleton3D", true, false)
	var mesh_nodes := node.find_children("*", "MeshInstance3D", true, false)
	var names: Array[String] = []
	for skeleton: Skeleton3D in skeletons:
		for bone in skeleton.get_bone_count():
			names.append(String(skeleton.get_bone_name(bone)))
	source_reports.append({"path": path, "bones": names, "mesh_count": mesh_nodes.size()})
	_expect(not mesh_nodes.is_empty() and not skeletons.is_empty(), "fitted file has mesh and rig")
	var packed := PackedScene.new()
	error = packed.pack(node)
	node.free()
	_expect(error == OK, "pack runtime imported GLB")
	return packed if error == OK else null


func _rig(label_text: String) -> Dictionary:
	var actor := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	actor.name = label_text.replace(" ", "")
	world.add_child(actor)
	var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var animation_player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure_character(actor)
	for entry: Array in [["bend", "res://animations_extra/Frontier_Bend.res"], ["boxing", "res://animations_extra/Frontier_Style_Boxing.res"]]:
		if ResourceLoader.exists(entry[1]):
			animation_player.add_animation_library(entry[0], load(entry[1]) as AnimationLibrary)
	return {"name": label_text, "actor": actor, "skeleton": skeleton, "player": animation_player, "parts": []}


func _current_actor(label_text: String, hands_scene: PackedScene) -> Dictionary:
	var info := _rig(label_text)
	var body := CharacterBodyMesh.attach(info.skeleton, info.player)
	info.body = body
	var look := AppearanceStore.validate(CharacterPeoples.preset_look("vietnamese_m_a"))
	look["outfit"] = PlayerAppearance.arena_outfit("earth", 1.0)
	var fit := PlayerAppearance.dress(body, look)
	if hands_scene:
		var dressed := PlayerAppearance.dressed_look(look, fit)
		(dressed.hide_regions as Array).append_array(["hand_l", "hand_r"])
		BodyMaterials.apply_look(body, dressed, ["head", "body_hair"])
		info.hand_transfer = ReferenceParts.apply_hands(body, hands_scene)
		_expect(bool(info.hand_transfer.ok), "native hand triangles replaced in copied mesh")
		info.parts = body.part_meshes("fitted_hands")
	else:
		info.parts = body.part_meshes("head")
	return info


func _source_actor(scene: PackedScene) -> Dictionary:
	var info := _rig("Fitted source body")
	var body := CharacterBodyMesh.new()
	body.name = "FittedBody"
	var bind := (info.player as AnimationPlayer).get_animation("actor_b/null-add")
	_expect(body.build(info.skeleton, scene, bind), "build fitted body")
	(info.skeleton as Skeleton3D).add_child(body)
	info.body = body
	info.parts = body.meshes.duplicate()
	# Source default costume is shown on its own. Current clothing is not fitted here.
	return info


func _check_binding(info: Dictionary) -> void:
	var body := info.body as CharacterBodyMesh
	_expect((body.report.missing as Array).is_empty(), String(info.name) + " has no missing target bones")
	_expect(float(body.report.max_bind_diff) < 0.001, String(info.name) + " inverse binds match null-add")
	_expect(not (info.parts as Array).is_empty(), String(info.name) + " has target mesh parts")


func _check_weights(info: Dictionary) -> void:
	var invalid := 0
	var count := 0
	var worst_sum := 0.0
	var weighted_bones: Dictionary = {}
	for mesh: MeshInstance3D in info.parts:
		if mesh.skin == null:
			invalid += 1
			continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var slots := indices.size() / maxi(vertices.size(), 1)
			_expect(slots == 4 or slots == 8, String(info.name) + " supported influence count")
			if indices.size() != weights.size():
				invalid += 1
				continue
			for vertex in vertices.size():
				count += 1
				var total := 0.0
				for slot in slots:
					var offset := vertex * slots + slot
					var weight := float(weights[offset])
					if not is_finite(weight) or weight < -0.00001:
						invalid += 1
					if weight > 0.0:
						if indices[offset] < 0 or indices[offset] >= mesh.skin.get_bind_count():
							invalid += 1
						else:
							var bone := mesh.skin.get_bind_bone(indices[offset])
							var skeleton := info.skeleton as Skeleton3D
							weighted_bones[String(skeleton.get_bone_name(bone))] = true
						total += weight
				worst_sum = maxf(worst_sum, absf(total - 1.0))
	_expect(invalid == 0 and count > 0, String(info.name) + " finite valid weights and joint indices")
	_expect(worst_sum < 0.001, String(info.name) + " weights normalized")
	info["weight_report"] = {"vertices": count, "invalid": invalid, "maximum_weight_sum_error": worst_sum,
		"weighted_bones": weighted_bones.keys()}


func _pose(info: Dictionary, clip: String, time: float) -> void:
	var player := info.player as AnimationPlayer
	var skeleton := info.skeleton as Skeleton3D
	player.stop()
	skeleton.reset_bone_poses()
	player.play("actor_b/null-add")
	player.seek(0.0, true)
	player.advance(0.0)
	player.play(clip)
	player.seek(time, true)
	player.advance(0.0)
	player.pause()


func _vertices(info: Dictionary) -> PackedVector3Array:
	var output_vertices := PackedVector3Array()
	var globals := (info.body as CharacterBodyMesh).skinning_globals()
	for mesh: MeshInstance3D in info.parts:
		if mesh.skin == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices := _mesh_vertices(mesh, surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var slots := indices.size() / maxi(vertices.size(), 1)
			for index in vertices.size():
				var point := Vector3.ZERO
				for slot in slots:
					var weight := weights[index * slots + slot]
					if weight <= 0.0:
						continue
					var bind_index := indices[index * slots + slot]
					var bone := mesh.skin.get_bind_bone(bind_index)
					point += (globals[bone] * mesh.skin.get_bind_pose(bind_index) * vertices[index]) * weight
				output_vertices.append(point)
	return output_vertices


func _mesh_vertices(mesh: MeshInstance3D, surface: int) -> PackedVector3Array:
	var arrays := mesh.mesh.surface_get_arrays(surface)
	var base: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vertices := base.duplicate()
	var shapes := mesh.mesh.surface_get_blend_shape_arrays(surface)
	for shape in shapes.size():
		var weight := mesh.get_blend_shape_value(shape)
		if absf(weight) < 0.000001:
			continue
		var target: PackedVector3Array = shapes[shape][Mesh.ARRAY_VERTEX]
		if target.size() != base.size():
			continue
		for index in vertices.size():
			vertices[index] += (target[index] - base[index]) * weight
	return vertices


func _check_null_pose(info: Dictionary) -> void:
	_pose(info, "actor_b/null-add", 0.0)
	var posed := _vertices(info)
	var original := PackedVector3Array()
	for mesh: MeshInstance3D in info.parts:
		for surface in mesh.mesh.get_surface_count():
			original.append_array(_mesh_vertices(mesh, surface))
	var error := 0.0
	for index in mini(posed.size(), original.size()):
		error = maxf(error, posed[index].distance_to(original[index]))
	_expect(posed.size() == original.size() and error < 0.0002, String(info.name) + " null-add skin reproduces fitted geometry")
	info["null_pose_max_error_m"] = error


func _sample(spec: Array) -> void:
	var row := {"pose": String(spec[0]), "clip": String(spec[1]), "actors": []}
	for info: Dictionary in actors:
		var player := info.player as AnimationPlayer
		var clip := String(spec[1])
		_expect(player.has_animation(clip), String(info.name) + " clip " + clip)
		if not player.has_animation(clip):
			continue
		var animation := player.get_animation(clip)
		var time := float(spec[2])
		if String(spec[0]) == "cast" or String(spec[0]) == "grip":
			time = float(animation.get_meta("strike_s", animation.length * 0.5))
		_pose(info, clip, time)
		var points := _vertices(info)
		var bounds := AABB(points[0], Vector3.ZERO) if not points.is_empty() else AABB()
		var finite := true
		for point: Vector3 in points:
			finite = finite and point.is_finite()
			bounds = bounds.expand(point)
		_expect(finite and not points.is_empty(), String(info.name) + " finite " + String(spec[0]) + " deformation")
		_expect(bounds.size.length() < 4.5, String(info.name) + " bounded " + String(spec[0]) + " deformation")
		(row.actors as Array).append({"name": info.name, "time_s": time, "bounds_position": _vector(bounds.position), "bounds_size": _vector(bounds.size)})
	samples.append(row)
	await process_frame
	for info: Dictionary in actors:
		if info.has("weapon_socket"):
			var socket := info.weapon_socket as BoneAttachment3D
			var skeleton := info.skeleton as Skeleton3D
			var expected := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("r_hand_prop_attachment"))
			_expect(socket.global_transform.origin.distance_to(expected.origin) < 0.0001, String(info.name) + " weapon attachment follows native prop bone")


func _install_weapon_models(info: Dictionary) -> void:
	var skeleton := info.skeleton as Skeleton3D
	var socket := BoneAttachment3D.new()
	socket.name = "ReferenceGripCheck"
	socket.bone_name = "r_hand_prop_attachment"
	skeleton.add_child(socket)
	var offset := Node3D.new()
	offset.name = "MeasuredGripOffset"
	offset.transform = PROP_GRIP
	socket.add_child(offset)
	var sword := (load("res://assets/weapons/saber.glb") as PackedScene).instantiate() as Node3D
	var scabbard := sword.find_child("Scabbard", true, false) as Node3D
	if scabbard:
		scabbard.visible = false
	offset.add_child(sword)
	var spear := ThrowableModels.build("spear")
	offset.add_child(spear)
	sword.visible = false
	spear.visible = false
	info.weapon_socket = socket
	info.weapon_sword = sword
	info.weapon_spear = spear
	_expect(skeleton.find_bone(socket.bone_name) >= 0, String(info.name) + " native weapon socket exists")
	_expect(not sword.find_children("*", "MeshInstance3D", true, false).is_empty(), "project saber mesh loaded")
	_expect(ThrowableModels.has_glb("spear"), "project spear imported mesh loaded")


func _check_weapon_cast_swap() -> void:
	for info: Dictionary in actors:
		var player := info.player as AnimationPlayer
		var sword := info.weapon_sword as Node3D
		var spear := info.weapon_spear as Node3D
		_pose(info, "actor_b/atk-actor_b-knife-v-thug-hit1-intro", 0.0)
		sword.visible = true
		spear.visible = false
		player.play("bend/own-bend-air-palm", 0.12)
		sword.visible = false
		for _step in 4:
			player.advance(0.03)
			_expect((info.skeleton as Skeleton3D).get_bone_global_pose(0).origin.is_finite(), String(info.name) + " finite weapon-to-cast blend")
		player.play("actor_b/atk-actor_b-knife-v-thug-hit1-intro", 0.12)
		spear.visible = true
		for _step in 4:
			player.advance(0.03)
			_expect((info.skeleton as Skeleton3D).get_bone_global_pose(0).origin.is_finite(), String(info.name) + " finite cast-to-weapon blend")
		_expect(not sword.visible and spear.visible, String(info.name) + " single weapon visible after swap")
		spear.visible = false
		player.pause()


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _render() -> void:
	for spec: Array in wanted_samples:
		var row: Array[Image] = []
		for info: Dictionary in actors:
			for other: Dictionary in actors:
				(other.actor as Node3D).visible = other == info
			var animation := (info.player as AnimationPlayer).get_animation(String(spec[1]))
			var time := float(spec[2])
			if String(spec[0]) in ["cast", "grip"]:
				time = float(animation.get_meta("strike_s", animation.length * 0.5))
			_pose(info, String(spec[1]), time)
			if info.has("weapon_sword"):
				(info.weapon_sword as Node3D).visible = String(spec[0]) == "sword_grip"
				(info.weapon_spear as Node3D).visible = String(spec[0]) == "spear_grip"
			if args.get("shots", "all") == "heads":
				var head := await _capture(info, String(spec[0]), "head", "")
				if head:
					row.append(head)
				await _capture(info, String(spec[0]), "head_side", "")
				continue
			var full := await _capture(info, String(spec[0]), "full", "")
			if full:
				row.append(full)
			for side: String in ["r", "l"]:
				await _capture(info, String(spec[0]), "hand_" + side, side)
		_sheet(row, output.path_join(String(spec[0]) + ("_head_comparison.png" if args.get("shots", "all") == "heads" else "_body_comparison.png")))
	if args.get("shots", "all") == "heads":
		return
	for side: String in ["r", "l"]:
		var cells: Array[Image] = []
		for spec: Array in wanted_samples:
			for index in 2:
				var path := output.path_join(_file_name(actors[index], String(spec[0]), "hand_" + side) + ".png")
				cells.append(Image.load_from_file(path))
		_sheet(cells, output.path_join("hand_" + side + "_comparison.png"), 2)


func _capture(info: Dictionary, pose_name: String, shot: String, side: String) -> Image:
	var skeleton := info.skeleton as Skeleton3D
	label.text = String(info.name) + " / " + pose_name + "\n" + ("Full body" if side.is_empty() else side.to_upper() + " hand / same target rig and animation")
	if pose_name in ["sword_grip", "spear_grip"]:
		label.text += "\nExisting project " + ("saber" if pose_name == "sword_grip" else "spear") + " / attachment study"
	if shot.begins_with("head"):
		label.text = String(info.name) + " / " + pose_name + "\nHead / existing target rig and animation"
		var head := skeleton.get_bone_global_pose(skeleton.find_bone("headb")).origin + Vector3.UP * 0.045
		view.camera.global_position = head + (Vector3(0.82, 0.04, 0.10) if shot == "head_side" else Vector3(0.13, 0.04, 0.82))
		view.camera.look_at(head)
	elif side.is_empty():
		view.camera.position = Vector3(-2.25, 1.2, 3.3)
		view.camera.look_at(Vector3(0, 0.95, 0))
	else:
		var palm := skeleton.get_bone_global_pose(skeleton.find_bone(side + "_palm")).origin
		view.camera.global_position = palm + Vector3(-0.29 if side == "r" else 0.29, 0.11, 0.4)
		view.camera.look_at(palm)
	for _frame in 3:
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := view.get_texture().get_image()
	var path := output.path_join(_file_name(info, pose_name, shot) + ".png")
	_expect(image != null and image.save_png(path) == OK, "save " + path.get_file())
	print("saved ", path)
	return image


func _file_name(info: Dictionary, pose_name: String, shot: String) -> String:
	return String(info.name).to_lower().replace(" ", "_") + "_" + pose_name + "_" + shot


func _sheet(images: Array[Image], path: String, columns := 0) -> void:
	if images.is_empty():
		return
	if columns <= 0:
		columns = images.size()
	var rows := ceili(float(images.size()) / columns)
	var sheet := Image.create(SIZE.x * columns, SIZE.y * rows, false, Image.FORMAT_RGBA8)
	for index in images.size():
		var image := images[index]
		if image == null:
			continue
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(index % columns, index / columns) * SIZE)
	_expect(sheet.save_png(path) == OK, "save comparison sheet")


func _finish() -> void:
	var summaries := []
	for info: Dictionary in actors:
		summaries.append({"name": info.name, "binding": (info.body as CharacterBodyMesh).report,
			"weights": info.get("weight_report", {}), "null_pose_max_error_m": info.get("null_pose_max_error_m", null),
			"hand_transfer": info.get("hand_transfer", {})})
	var file := FileAccess.open(output.path_join("godot_fit_report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "checks": checks,
			"failures": Array(failures), "sources": source_reports, "actors": summaries, "poses": samples,
			"shipping_defaults_changed": false,
			"weapon_inputs": ["res://assets/weapons/saber.glb", "res://assets/weapons/spear.glb"] if args.get("weapons", "0") == "1" else [],
			"limitations": "Hand overlay seam and skin tone need visual review. Full source costume is not fitted to the current customizer body. No source animations are imported by this harness."}, "\t") + "\n")
	print("CHARACTER FIT PREVIEW DONE: %d checks" % checks if failures.is_empty() else "CHARACTER FIT PREVIEW FAILED: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)
