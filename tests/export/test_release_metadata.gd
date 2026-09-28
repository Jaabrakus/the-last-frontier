extends SceneTree
## Real libraries: exact stored motion before/after save + reload, alias resolution, bind pose,
## graph validation/build, and early/middle/late skeleton playback. Writes only to a temp folder.
## Godot --headless --path . -s tests/export/test_release_metadata.gd -- out=/tmp/frontier-release-check

const Policy := preload("res://addons/release_metadata/policy.gd")
const LIBRARIES := [
	"res://animations/Actor_B.res", "res://animations_extra/Actor_B_from_A.res",
	"res://animations_extra/Actor_B_from_C.res", "res://animations_extra/actor_a_rt_proto.res",
	"res://animations_extra/Frontier_Own.res",
]
var failures: Array[String] = []
var checks := 0
var clip_count := 0
var pose_count := 0
var out := "/tmp/frontier-release-check"
var originals: Array[AnimationLibrary] = []
var released: Array[AnimationLibrary] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	if not out.is_absolute_path() or out.simplify_path().begins_with(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		push_error("Test output must be an absolute directory outside the project.")
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "temp output directory")
	_test_copy_boundary()
	for path: String in LIBRARIES:
		_check_library(path)
	if originals.size() == LIBRARIES.size() and released.size() == originals.size():
		await _check_graph_and_playback()
	check(pose_count >= 60 and clip_count > 2700, "all library and playback checks completed")
	print("Release metadata: %d checks, %d clips, %d sampled poses, %d failures" %
			[checks, clip_count, pose_count, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_copy_boundary() -> void:
	var a := Animation.new()
	a.set_meta("source_attribution", "development record")
	a.set_meta("additive_source", true)
	var b := Policy.copy_resource(a) as Animation
	check(b != a and not b.has_meta("source_attribution"), "release callback removes bookkeeping from a copy")
	check(a.has_meta("source_attribution") and b.get_meta("additive_source") == true, "source and additive flag survive")
	var table := {"source_state": 12, "source": "null-add", "original_name": "alias",
			"native_asset_id": "internal-id", "items": [{"attribution": "development", "time": 0.125}]}
	var copy: Dictionary = Policy.copy_animation_table("res://animations/test.json", table)
	check(copy.source_state == 12 and copy.source == "null-add" and copy.original_name == "alias", "functional source fields and aliases survive")
	check(not copy.has("native_asset_id") and not copy.items[0].has("attribution"), "nested bookkeeping is omitted")
	check(table.has("native_asset_id") and table.items[0].has("attribution"), "JSON input is not mutated")
	var material := StandardMaterial3D.new()
	material.set_meta("source_attribution", "unrelated material")
	check(Policy.copy_resource(material) == null, "unrelated resources are untouched")
	check(not Policy.is_animation_table("res://assets/catalog.json"), "unrelated JSON is outside the policy")


func _check_library(path: String) -> void:
	var file_hash := FileAccess.get_sha256(path)
	var lib := load(path) as AnimationLibrary
	check(lib != null, "load " + path)
	if lib == null:
		return
	var original_metadata := {}
	for name in lib.get_animation_list():
		original_metadata[name] = _metadata(lib.get_animation(name))
	var copy := Policy.copy_resource(lib) as AnimationLibrary
	var saved := out.path_join(path.get_file())
	check(ResourceSaver.save(copy, saved, ResourceSaver.FLAG_COMPRESS) == OK, "save copy " + path)
	var loaded := ResourceLoader.load(saved, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
	check(loaded != null, "reload copy " + path)
	if loaded == null:
		return
	check(lib.get_animation_list() == loaded.get_animation_list(), "all runtime clip names survive " + path)
	for name in lib.get_animation_list():
		var original := lib.get_animation(name)
		var after := loaded.get_animation(name)
		check(_metadata(original) == original_metadata[name], "cached source metadata unchanged " + str(name))
		check(_motion(original) == _motion(after), "exact stored motion " + str(name))
		check(copy.get_animation(name) != original, "copy isolation " + str(name))
		for key in original.get_meta_list():
			if key in Policy.ANIMATION_FIELDS:
				check(not after.has_meta(key), "omitted metadata " + str(key))
			else:
				check(after.has_meta(key) and original.get_meta(key) == after.get_meta(key), "preserved metadata " + str(key))
		clip_count += 1
	check(FileAccess.get_sha256(path) == file_hash, "source file byte-identical " + path)
	originals.append(lib)
	released.append(loaded)
	print("Verified %s: %d clips" % [path, lib.get_animation_list().size()])


func _metadata(resource: Resource) -> Dictionary:
	var result := {}
	for name in resource.get_meta_list():
		result[name] = resource.get_meta(name)
	return result


func _motion(animation: Animation) -> Dictionary:
	var result := {}
	for property in animation.get_property_list():
		var name: String = property.name
		if int(property.usage) & PROPERTY_USAGE_STORAGE and not name.begins_with("metadata/"):
			result[name] = animation.get(name)
	return result


func _check_graph_and_playback() -> void:
	var original_data := AnimGraphData.load_files()
	var graph: Dictionary = Policy.copy_animation_table(AnimGraphData.GRAPH_PATH, original_data.graph)
	var metrics: Dictionary = Policy.copy_animation_table(AnimGraphData.METRICS_PATH, original_data.metrics)
	# Match the export JSON serialization, including floating-point precision.
	var data := AnimGraphData.from_dicts(JSON.parse_string(JSON.stringify(graph, "", true, true)),
			JSON.parse_string(JSON.stringify(metrics, "", true, true)))
	check(data._alias == original_data._alias, "every graph alias resolves identically")
	check(data.referenced_clips() == original_data.referenced_clips(), "every graph clip reference survives")
	var scene := load("res://characters/Actor_B.tscn") as PackedScene
	var before := scene.instantiate()
	var after := scene.instantiate()
	root.add_child(before)
	root.add_child(after)
	await process_frame
	var ap1 := before.get_node("AnimationPlayer") as AnimationPlayer
	var ap2 := after.get_node("AnimationPlayer") as AnimationPlayer
	var sk1 := before.get_node("Skeleton3D") as Skeleton3D
	var sk2 := after.get_node("Skeleton3D") as Skeleton3D
	ap1.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap2.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap2.remove_animation_library("actor_b")
	ap2.add_animation_library("actor_b", released[0])
	Policy.strip_bind_rest_ids(after)
	check(not sk2.get_meta("bind_rest").has("native_asset_id"), "export scene omits the bind-rest tracking ID")
	check(sk1.get_meta("bind_rest").has("native_asset_id"), "development scene retains the bind-rest tracking ID")
	check(BindRest.verify(sk2, ap2).ok and BindRest.is_stamped(sk2), "export bind pose and stamp remain valid")
	var errors := data.validate(ap2)
	check(errors.is_empty(), "export graph validates: %s" % [errors])
	var tree := TreeBuilder.build(data, ap2, sk2)
	check(tree.errors.is_empty(), "export animation tree builds: %s" % [tree.errors])
	for i in originals.size():
		var library_name := "actor_b" if i == 0 else "probe_%d" % i
		if i > 0:
			check(ap1.add_animation_library(library_name, originals[i]) == OK, "install original playback library")
			check(ap2.add_animation_library(library_name, released[i]) == OK, "install exported playback library")
		var names := originals[i].get_animation_list()
		var samples: Array = [names[0], names[names.size() / 2], names[-1]]
		if i == 0:
			samples.append("actor_b-p-run-fw")
		if i == originals.size() - 1:
			samples = Array(names)  # All custom axe attacks, intro and hit.
		for name: StringName in samples:
			var animation := originals[i].get_animation(name)
			var clip_path := library_name + "/" + name
			check(ap1.has_animation(clip_path) and ap2.has_animation(clip_path), "both players have " + clip_path)
			for fraction: float in [0.05, 0.5, 0.95]:
				sk1.reset_bone_poses()
				sk2.reset_bone_poses()
				for ap: AnimationPlayer in [ap1, ap2]:
					ap.stop()
					ap.play(clip_path)
					ap.seek(animation.length * fraction, true)
				var same := true
				for bone in sk1.get_bone_count():
					same = same and sk1.get_bone_pose(bone) == sk2.get_bone_pose(bone)
				check(same, "identical skeleton pose %s @ %s" % [name, fraction])
				pose_count += 1
		ap1.stop()
		ap2.stop()
	before.free()
	after.free()
	TreeBuilder.clear_cache()
