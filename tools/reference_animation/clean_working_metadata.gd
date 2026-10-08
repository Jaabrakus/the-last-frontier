extends SceneTree
## Creates metadata-free AnimationLibrary working copies. Never overwrites input files.
## Godot --headless --path . -s <this script> -- input=<dir> output=<dir>

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if "=" in arg:
			args[arg.get_slice("=", 0)] = arg.substr(arg.find("=") + 1)
	var source := String(args.get("input", "")).simplify_path().trim_suffix("/")
	var output := String(args.get("output", "")).simplify_path().trim_suffix("/")
	if source == "" or output == "" or source == output or output.begins_with(source + "/"):
		push_error("Provide distinct input and output directories, with output outside input.")
		quit(1)
		return
	var files: Array[String] = []
	_collect(source, files)
	var clips := 0
	var fields := 0
	for path in files:
		var before_hash := FileAccess.get_sha256(path)
		var original := ResourceLoader.load(path, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
		if original == null:
			_fail("Cannot load " + path)
			return
		var copy := AnimationLibrary.new()
		fields += original.get_meta_list().size()
		for key in original.get_animation_list():
			var animation := original.get_animation(key).duplicate(true) as Animation
			for meta in animation.get_meta_list():
				animation.remove_meta(meta)
				fields += 1
			animation.resource_name = ""
			copy.add_animation(key, animation)
		var dest := output.path_join(path.trim_prefix(source + "/"))
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		if ResourceSaver.save(copy, dest, ResourceSaver.FLAG_COMPRESS) != OK:
			_fail("Cannot save " + dest)
			return
		var saved := ResourceLoader.load(dest, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
		if saved == null or not saved.get_meta_list().is_empty() or saved.get_animation_list() != original.get_animation_list():
			_fail("Library verification failed " + dest)
			return
		for key in saved.get_animation_list():
			var animation := saved.get_animation(key)
			if not animation.get_meta_list().is_empty() or _motion(animation) != _motion(original.get_animation(key)):
				_fail("Animation verification failed " + dest)
				return
			clips += 1
		if FileAccess.get_sha256(path) != before_hash:
			_fail("Source changed " + path)
			return
		if clips % 100 == 0:
			print("Verified clean clips: ", clips)
			await process_frame
	print("CLEAN WORKING COPIES: libraries=", files.size(), " clips=", clips, " removed_fields=", fields,
			" remaining_metadata=0 exact_motion=true source_unchanged=true")
	quit(0 if clips > 0 else 1)

func _collect(dir: String, files: Array[String]) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	for name in access.get_files():
		if name.ends_with(".res") or name.ends_with(".tres"):
			files.append(dir.path_join(name))
	for name in access.get_directories():
		if not name.begins_with("."):
			_collect(dir.path_join(name), files)
	files.sort()

func _motion(animation: Animation) -> Dictionary:
	var data := {}
	# Include every stored animation property, including keys and interpolation flags,
	# while excluding only Resource bookkeeping and metadata.
	for property in animation.get_property_list():
		var key := String(property.name)
		if int(property.usage) & PROPERTY_USAGE_STORAGE and not key.begins_with("metadata/") and not key.begins_with("resource_") and key != "script":
			data[key] = animation.get(key)
	return data

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
