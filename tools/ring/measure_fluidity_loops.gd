extends SceneTree
## Read-only endpoint measurements for currently resolved movement/arena loops.
## Records exact resource paths; a mismatch alone does not establish visible on-screen contribution.

const CANDIDATES := ["actor_b-p-fall", "actor_b-p-drop-down^fall--rifle", "actor_b-p-walk-fw-rt",
		"actor_b-p-sprint-bw-lt", "actor_b-p-sprint-bw-rt", "actor_b-p-run-fw", "actor_b-p-walk-fw", "actor_b-p-sprint-fw"]


func _initialize() -> void:
	var output := "/private/tmp/tidebreak-fluidity-loops.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=")
	var graph := AnimGraphData.load_files()
	var paths: Dictionary = graph.override_libraries().duplicate()
	paths["actor_b"] = "res://animations/Actor_B.res"
	var libraries := {}
	var rows: Array = []
	for clip: String in CANDIDATES:
		var resolved := String(graph.godot_anim(clip))
		var library_key := resolved.get_slice("/", 0)
		var path := String(paths.get(library_key, ""))
		if not libraries.has(path):
			libraries[path] = load(path) as AnimationLibrary if path != "" else null
		var library: AnimationLibrary = libraries[path]
		var name := resolved.substr(library_key.length() + 1)
		if library != null and library.has_animation(name):
			rows.append(_measure(clip, path, name, library.get_animation(name)))
	var movement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ring/movement.json"))
	var names: Array[String] = []
	for state: String in movement.clips:
		var spec: Variant = movement.clips[state]
		if spec is Dictionary and bool(spec.get("loop", false)):
			names.append(String(spec.clip))
	for section: String in ["stance", "guard_hold"]:
		for element: String in BendPoses.data().get(section, {}):
			var spec := BendPoses._as_pose(BendPoses.data()[section][element])
			var name := String(spec.get("clip", ""))
			if name != "" and not name in names:
				names.append(name)
	for name: String in names:
		var animation := BendPoses.animation(name)
		if animation != null:
			rows.append(_measure(name, animation.resource_path, name, animation))
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + output)
		quit(1)
		return
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "measurements": rows}, "\t") + "\n")
	print("FLUIDITY_LOOPS measured=%d output=%s" % [rows.size(), output])
	quit()


func _measure(requested: String, path: String, clip: String, animation: Animation) -> Dictionary:
	var rotation := 0.0
	var position := 0.0
	var worst_rotation := ""
	var worst_position := ""
	for track in animation.get_track_count():
		var count := animation.track_get_key_count(track)
		if count < 2:
			continue
		var first: Variant = animation.track_get_key_value(track, 0)
		var last: Variant = animation.track_get_key_value(track, count - 1)
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			var a: Quaternion = first
			var b: Quaternion = last
			var delta := 2.0 * acos(clampf(absf(a.normalized().dot(b.normalized())), 0.0, 1.0))
			if delta > rotation:
				rotation = delta
				worst_rotation = String(animation.track_get_path(track))
		elif animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
			var a: Vector3 = first
			var b: Vector3 = last
			var delta := a.distance_to(b)
			if delta > position:
				position = delta
				worst_position = String(animation.track_get_path(track))
	return {"requested": requested, "resource": path, "clip": clip, "length_s": animation.length,
			"endpoint_rotation_rad": rotation, "endpoint_position_m": position,
			"rotation_track": worst_rotation, "position_track": worst_position}
