extends SceneTree
## Offline conversion only. Keeps third-party clips in the explicit external reference folder.
## Usage: Godot --headless --path <empty reference project> -s <this file> -- <godot-folder>

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var base := OS.get_cmdline_user_args()[0]
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("conversion_report.json")))
	var results: Array[Dictionary] = []
	var saved_rigs: Dictionary = {}
	var failed := 0
	for item: Dictionary in report.clips:
		var state := GLTFState.new()
		var doc := GLTFDocument.new()
		var err := doc.append_from_file(item.file, state)
		if err != OK:
			results.append({"clip": item.clip, "error": "GLB parse", "code": err})
			failed += 1
			continue
		var scene := doc.generate_scene(state)
		root.add_child(scene)
		var skeletons := scene.find_children("*", "Skeleton3D", true, false)
		var players := scene.find_children("*", "AnimationPlayer", true, false)
		if skeletons.size() != 1 or players.size() != 1:
			failed += 1
			results.append({"clip": item.clip, "error": "Missing skeleton/player"})
			scene.free()
			continue
		var sk := skeletons[0] as Skeleton3D
		var ap := players[0] as AnimationPlayer
		var library := AnimationLibrary.new()
		var animation := ap.get_animation(item.clip).duplicate(true) as Animation
		animation.set_meta("source_attribution", "Spellbreak community Windows client; third-party reference")
		animation.set_meta("original_name", item.clip)
		animation.set_meta("source_sha256", item.source_sha256)
		animation.set_meta("reference_only", true)
		animation.set_meta("source_additive_type", item.get("source_additive_type", "unknown"))
		var names := PackedStringArray()
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		var rig_key := (item.skeleton as String) + "_" + "|".join(names).sha256_text().left(12)
		var rig_path := base.path_join("rigs/" + rig_key + ".tscn")
		if not saved_rigs.has(rig_key):
			var rig := Node3D.new()
			rig.name = "ReferenceRig"
			var skeleton := sk.duplicate() as Skeleton3D
			skeleton.name = "Skeleton3D"
			rig.add_child(skeleton)
			skeleton.owner = rig
			for child in skeleton.get_children():
				child.free()
			var packed := PackedScene.new()
			assert(packed.pack(rig) == OK)
			DirAccess.make_dir_recursive_absolute(rig_path.get_base_dir())
			assert(ResourceSaver.save(packed, rig_path) == OK)
			rig.free()
			saved_rigs[rig_key] = rig_path
		# Reference rig is the playback root; use one stable, explicit Skeleton3D path.
		for tr in animation.get_track_count():
			var original := animation.track_get_path(tr)
			if original.get_subname_count() > 0:
				var bone := original.get_subname(0)
				assert(sk.find_bone(bone) >= 0)
				animation.track_set_path(tr, NodePath("Skeleton3D:" + bone))
		library.add_animation(item.clip, animation)
		var path := (item.file as String).replace(base.path_join("glb"), base.path_join("libraries")).get_basename() + ".res"
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		assert(ResourceSaver.save(library, path, ResourceSaver.FLAG_COMPRESS) == OK)
		var saved := ResourceLoader.load(path, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
		assert(saved != null and saved.has_animation(item.clip))
		# Sample original imported playback at early/mid/late frames and validate hierarchy output.
		ap.play(item.clip)
		for t in [0.0, animation.length * 0.5, animation.length]:
			ap.seek(t, true)
			sk.force_update_all_bone_transforms()
			for i in sk.get_bone_count():
				assert(sk.get_bone_global_pose(i).origin.is_finite())
		results.append({"clip": item.clip, "library": path, "rig": rig_path, "bones": sk.get_bone_count(), "length": animation.length, "tracks": animation.get_track_count(), "source_sha256": item.source_sha256, "source_additive_type": item.get("source_additive_type", "unknown")})
		scene.free()
		if results.size() % 100 == 0:
			print("GODOT_BAKED ", results.size(), "/", report.clips.size())
			await process_frame
	var file := FileAccess.open(base.path_join("godot_library_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "clips": results, "failures": failed, "rigs": saved_rigs.size()}, "\t"))
	print("GODOT_BAKE_COMPLETE clips=", results.size(), " rigs=", saved_rigs.size(), " failures=", failed)
	quit(0 if failed == 0 else 1)
