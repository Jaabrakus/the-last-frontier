extends Node
## Runs inside the isolated exported fixture, never as the game's main scene.

const LIBRARIES := {
	"res://animations/Actor_B.res": 2490,
	"res://animations_extra/Actor_B_from_A.res": 154,
	"res://animations_extra/Actor_B_from_C.res": 117,
	"res://animations_extra/actor_a_rt_proto.res": 29,
	"res://animations_extra/Frontier_Own.res": 8,
}
var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _ready() -> void:
	var debug := "debug" in OS.get_cmdline_user_args()
	var hashes := {}
	var metadata_hashes := {}
	var total := 0
	for path: String in LIBRARIES:
		var lib := load(path) as AnimationLibrary
		check(lib != null, "library loads from pack " + path)
		if lib == null:
			continue
		var names := lib.get_animation_list()
		check(names.size() == LIBRARIES[path], "pack clip count " + path)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		var metadata_digest := HashingContext.new()
		metadata_digest.start(HashingContext.HASH_SHA256)
		var records := 0
		for name in names:
			var animation := lib.get_animation(name)
			var metadata := {}
			for key in animation.get_meta_list():
				metadata[key] = animation.get_meta(key)
			metadata_digest.update(str(name).to_utf8_buffer())
			metadata_digest.update(var_to_bytes(metadata))
			if animation.has_meta("native_asset_id") or animation.has_meta("authored"):
				records += 1
			if not debug:
				check(not animation.has_meta("source_attribution") and not animation.has_meta("native_asset_id")
						and not animation.has_meta("retarget") and not animation.has_meta("authored"), "release metadata " + name)
			var properties := {}
			for property in animation.get_property_list():
				var key: String = property.name
				if int(property.usage) & PROPERTY_USAGE_STORAGE and not key.begins_with("metadata/"):
					properties[key] = animation.get(key)
			digest.update(str(name).to_utf8_buffer())
			digest.update(var_to_bytes(properties))
		# RESET and other synthetic source clips need not have an origin record. The runner
		# compares the complete debug metadata digest to the original project as well.
		check(records > 0 if debug else records == 0, "debug/release metadata boundary " + path)
		hashes[path] = digest.finish().hex_encode()
		metadata_hashes[path] = metadata_digest.finish().hex_encode()
		total += names.size()
	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://animations/actor_b_graph.json"))
	check(graph.meta.has("authorization") == debug, "graph bookkeeping follows export mode")
	check(graph.clips.size() == 347, "all graph clips survive")
	var alias_count := 0
	for clip: Dictionary in graph.clips.values():
		check(clip.has("original_name") and clip.has("source_names"), "runtime graph aliases survive")
		alias_count += clip.source_names.size()
	var climbing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/climb/climb_tree.json"))
	check(climbing.has("source") == debug, "climbing authoring record follows export mode")
	var unrelated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://unrelated.json"))
	check(unrelated.get("source_attribution") == "fixture record", "unrelated JSON retained")
	check(FileAccess.get_file_as_string("res://CREDITS.md") == "Fixture credits remain present.\n", "credits retained")
	var rig := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	add_child(rig)
	var sk := rig.get_node("Skeleton3D") as Skeleton3D
	check(sk.get_meta("bind_rest").has("native_asset_id") == debug, "scene stamp follows export mode")
	check(sk.get_meta("bind_rest").source == "null-add", "functional bind-rest stamp retained")
	var ap := rig.get_node("AnimationPlayer") as AnimationPlayer
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.play("actor_b/actor_b-p-run-fw")
	ap.seek(0.2, true)
	var pose: Array = []
	for bone in sk.get_bone_count():
		pose.append(sk.get_bone_pose(bone))
	var pose_hash := HashingContext.new()
	pose_hash.start(HashingContext.HASH_SHA256)
	pose_hash.update(var_to_bytes(pose))
	print("PACK_RESULT " + JSON.stringify({"debug": debug, "clips": total, "motion": hashes,
			"metadata": metadata_hashes, "pose": pose_hash.finish().hex_encode(), "aliases": alias_count, "failures": failures}))
	rig.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)
