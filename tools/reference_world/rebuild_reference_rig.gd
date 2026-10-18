extends SceneTree
## Rebuild the inspected source skeleton as a separate Godot scene.
## Godot --headless --path . -s tools/reference_world/rebuild_reference_rig.gd -- input.json output.tscn
## Preserves source names/rest transforms; does not modify the playable rig.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]):
		push_error("Expected input.json and a NEW output.tscn")
		quit(1)
		return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var model: Dictionary = input.models[0]
	var character := Node3D.new()
	character.name = "ReferenceCharacterRig"
	character.set_meta("source_game", input.source_game)
	character.set_meta("source_sha256", input.source_sha256)
	character.set_meta("purpose", "Source rig reference; not installed as playable character")
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	character.add_child(skeleton)
	skeleton.owner = character
	root.add_child(character)
	for bone: Dictionary in model.bones:
		skeleton.add_bone(bone.name)
	for bone: Dictionary in model.bones:
		var index := int(bone.index)
		skeleton.set_bone_parent(index, int(bone.parent))
		var rotation: Array = bone.rotation
		var basis := Basis.IDENTITY
		if bone.rotation_mode == "EulerXYZ":
			# BFRES XYZ uses local X, then Y, then Z; column-vector product Rz Ry Rx.
			basis = Basis(Vector3.BACK, rotation[2]) * Basis(Vector3.UP, rotation[1]) * Basis(Vector3.RIGHT, rotation[0])
		elif bone.rotation_mode == "Quaternion":
			basis = Basis(Quaternion(rotation[0], rotation[1], rotation[2], rotation[3]).normalized())
		else:
			push_error("Unsupported rotation mode")
			quit(1)
			return
		var scale_values: Array = bone.scale
		var translation: Array = bone.translation
		var scale := Vector3(scale_values[0], scale_values[1], scale_values[2])
		var position := Vector3(translation[0], translation[1], translation[2])
		skeleton.set_bone_rest(index, Transform3D(basis * Basis.from_scale(scale), position))
	skeleton.reset_bone_poses()
	var scene := PackedScene.new()
	var error := scene.pack(character)
	if error == OK:
		error = ResourceSaver.save(scene, args[1])
	if error != OK:
		push_error("Could not save rig: %s" % error)
		quit(1)
		return
	# Reload source data to confirm names, hierarchy, and local transforms survived.
	var reloaded := (load(args[1]) as PackedScene).instantiate()
	var check := reloaded.get_node("Skeleton3D") as Skeleton3D
	if check.get_bone_count() != skeleton.get_bone_count():
		quit(1)
		return
	var positions := []
	for index in skeleton.get_bone_count():
		if check.get_bone_name(index) != skeleton.get_bone_name(index) or check.get_bone_parent(index) != skeleton.get_bone_parent(index) or not check.get_bone_rest(index).is_equal_approx(skeleton.get_bone_rest(index)):
			push_error("Rig roundtrip mismatch: %s" % index)
			quit(1)
			return
		var global_rest := check.get_bone_global_rest(index)
		positions.append({"name": check.get_bone_name(index), "position": [global_rest.origin.x, global_rest.origin.y, global_rest.origin.z]})
	var report := FileAccess.open(args[1] + ".verified.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"bones": check.get_bone_count(), "roundtrip_verified": true, "source_sha256": input.source_sha256, "global_rest_positions": positions}, "\t"))
	report.close()
	reloaded.free()
	print("Reference rig saved and roundtrip verified: %d bones" % skeleton.get_bone_count())
	quit()
