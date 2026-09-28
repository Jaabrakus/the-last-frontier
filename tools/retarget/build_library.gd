extends SceneTree
## Builds an AnimationLibrary from tools/retarget/retarget.py output (Actor_A clips
## retargeted onto the Actor_B rig).
##
##   Godot --headless --path <any project> -s <Frontier>/tools/retarget/build_library.gd -- \
##       in=<retarget out.json> out=<Frontier>/animations_extra/actor_a_rt_proto.res
##
## Every animation keeps the source clip's name and metadata verbatim (native_asset_id,
## original_name, source_names, sample_rate, sample_count, source_kind, additive_source,
## complete_stream_start, conversion, source_attribution, source_library) and gets a
## `retarget` dictionary (source actor/clip/asset id, profile, tool, Actor_A bind pose).
## Tracks are "Skeleton3D:<bone>" position / rotation tracks with one key per 30 fps frame,
## only for the channels the source clip keys (partial-body masks are kept).
## Add the library to the Actor_B AnimationPlayer under its name, e.g.
##   anim_player.add_animation_library("actor_b_from_a", load("res://animations_extra/Actor_B_from_A.res"))
## (the prototype: "actor_a_rt" / actor_a_rt_proto.res). When the retarget output carries a
## library_name, the library resource gets resource_name and a few provenance metas too.


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args["in"]))
	if data == null or not data.has("clips"):
		push_error("build_library: cannot read %s" % args.get("in"))
		quit(1)
		return
	var fps := float(data.get("fps", 30.0))
	var lib := AnimationLibrary.new()
	var names: Array = data["clips"].keys()
	names.sort()
	for name: String in names:
		var c: Dictionary = data["clips"][name]
		var anim := Animation.new()
		anim.length = float(c["length"])
		anim.step = 1.0 / fps
		anim.loop_mode = int(c.get("loop_mode", 0))
		var bones: Array = c["tracks"].keys()
		bones.sort()
		for bone: String in bones:
			var ch: Dictionary = c["tracks"][bone]
			var path := NodePath("Skeleton3D:" + bone)
			if ch.has("pos"):
				var t := anim.add_track(Animation.TYPE_POSITION_3D)
				anim.track_set_path(t, path)
				var keys: Array = ch["pos"]
				for i in keys.size():
					var v: Array = keys[i]
					anim.position_track_insert_key(t, minf(i / fps, anim.length), Vector3(v[0], v[1], v[2]))
			if ch.has("rot"):
				var t := anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(t, path)
				var keys: Array = ch["rot"]
				for i in keys.size():
					var q: Array = keys[i]
					anim.rotation_track_insert_key(t, minf(i / fps, anim.length), Quaternion(q[0], q[1], q[2], q[3]).normalized())
		for k: String in c["meta"]:
			anim.set_meta(k, c["meta"][k])
		var stamp: Dictionary = c["retarget"].duplicate()
		stamp["diag"] = c.get("diag", {})
		anim.set_meta("retarget", stamp)
		lib.add_animation(name, anim)
	if data.has("library_name"):
		# the name the game registers it under (add_animation_library(<name>, lib))
		lib.resource_name = str(data["library_name"])
		lib.set_meta("library_name", str(data["library_name"]))
		# (the Actor_A retarget's defaults; a retarget from another source names its own, climb_from_c.py)
		lib.set_meta("source_actor", str(data.get("source_actor", "Actor_A")))
		lib.set_meta("target_actor", "Actor_B")
		lib.set_meta("tool", str(data.get("tool", "")))
		if data.has("source_attribution"):
			lib.set_meta("source_attribution", str(data["source_attribution"]))
	var err := ResourceSaver.save(lib, args["out"], ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("build_library: saving %s failed: %s" % [args["out"], error_string(err)])
		quit(1)
		return
	print("build_library: %d animations -> %s" % [lib.get_animation_list().size(), args["out"]])
	quit(0)
