extends SceneTree
## Retarget the decoded AGLS FK motion onto the existing Frontier bind pose.
const INPUT := "res://.comparison-private/motion.json"
const OUTPUT := "res://animations_extra/AGLS_Preview.res"
const SOURCE_OUTPUT := "res://animations_extra/AGLS_Source_Preview.res"
const SOURCE_SCENE := "res://tools/agls_comparison/source_skeleton.tscn"
const MAP := {
	"root": "pelvis", "pelvis": "pelvis", "spineb": "spine_01",
	"spinec": "spine_02", "spined": "spine_03", "neck": "neck_01", "heada": "head",
	"l_clavicle": "clavicle_l", "r_clavicle": "clavicle_r",
	"l_shoulder": "upperarm_l", "r_shoulder": "upperarm_r",
	"l_elbow": "lowerarm_l", "r_elbow": "lowerarm_r", "l_wrist": "hand_l", "r_wrist": "hand_r",
	"l_upper_leg": "thigh_l", "r_upper_leg": "thigh_r", "l_knee": "calf_l", "r_knee": "calf_r",
	"l_ankle": "foot_l", "r_ankle": "foot_r", "l_ball": "ball_l", "r_ball": "ball_r",
}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	var rig: Node3D = load("res://characters/Actor_B.tscn").instantiate()
	root.add_child(rig)
	var sk: Skeleton3D = rig.get_node("Skeleton3D")
	var source_root := Node3D.new()
	source_root.name = "AGLS_Source"
	var source_sk := Skeleton3D.new()
	source_sk.name = "Skeleton3D"
	source_root.add_child(source_sk)
	source_sk.owner = source_root
	var source_indices := {}
	var source_rests: Array[Transform3D] = []
	var source_global_rests: Array[Transform3D] = []
	for row: Dictionary in data.bones:
		var i := source_sk.add_bone(row.name)
		source_indices[String(row.name)] = i
		source_sk.set_bone_parent(i, int(row.parent))
		var rest := transform(row.rest)
		source_sk.set_bone_rest(i, rest)
		source_rests.append(rest)
		source_global_rests.append(transform(row.global_rest))
	var mapping: Dictionary = MAP.duplicate()
	for side in ["l", "r"]:
		for finger in ["index", "middle", "ring", "thumb"]:
			for j in 3:
				mapping["%s_%s%s" % [side, finger, ["a", "b", "c"][j]]] = "%s_0%d_%s" % [finger, j+1, side]
		# Frontier's extra first pinky joint is a metacarpal; source pinky starts at its next joint.
		for j in 3:
			mapping["%s_pinky%s" % [side, ["b", "c", "d"][j]]] = "pinky_0%d_%s" % [j+1, side]
	var map_indices := {}
	var rests: Array[Transform3D] = []
	var globals: Array[Transform3D] = []
	for i in sk.get_bone_count():
		rests.append(sk.get_bone_rest(i))
		globals.append(sk.get_bone_global_rest(i))
	for target: String in mapping:
		var i := sk.find_bone(target)
		assert(i >= 0 and source_indices.has(mapping[target]), "Missing retarget bone: " + target)
		map_indices[i] = source_indices[mapping[target]]
	var root_bone := sk.find_bone("root")
	var source_pelvis: int = source_indices.pelvis
	var scale_factor := globals[root_bone].origin.y / source_global_rests[source_pelvis].origin.y
	var library := AnimationLibrary.new()
	var source_library := AnimationLibrary.new()
	var reports := []
	for clip: Dictionary in data.clips:
		var animation := Animation.new()
		var native := Animation.new()
		animation.length = float(clip.length)
		native.length = animation.length
		var looping := "_Walk_" in String(clip.name) or "_Run_" in String(clip.name) or "_Sprint_" in String(clip.name) or "Movement_" in String(clip.name) or "Idle_Loop" in String(clip.name)
		animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
		native.loop_mode = animation.loop_mode
		var rot_tracks := {}
		for bone: int in map_indices:
			rot_tracks[bone] = track(animation, Animation.TYPE_ROTATION_3D, String(sk.get_bone_name(bone)))
		var pos_track := track(animation, Animation.TYPE_POSITION_3D, "root")
		var source_tracks := []
		for bone: Dictionary in data.bones:
			source_tracks.append([track(native, Animation.TYPE_POSITION_3D, bone.name), track(native, Animation.TYPE_ROTATION_3D, bone.name), track(native, Animation.TYPE_SCALE_3D, bone.name)])
		var previous := {}
		var max_source_position_error := 0.0
		for sample: Dictionary in clip.samples:
			var target_global: Array[Transform3D] = []
			var t := float(sample.time)
			for i in sk.get_bone_count():
				var parent := sk.get_bone_parent(i)
				var parent_global := target_global[parent] if parent >= 0 else Transform3D.IDENTITY
				var local := rests[i]
				if map_indices.has(i):
					var source_idx: int = map_indices[i]
					var source_global := transform(sample["global"][source_idx])
					var delta := source_global.basis.orthonormalized() * source_global_rests[source_idx].basis.inverse()
					var wanted := delta * globals[i].basis
					local.basis = parent_global.basis.inverse() * wanted
					var q := local.basis.orthonormalized().get_rotation_quaternion().normalized()
					if previous.has(i) and (previous[i] as Quaternion).dot(q) < 0.0:
						q = -q
					previous[i] = q
					animation.rotation_track_insert_key(rot_tracks[i], t, q)
				if i == root_bone:
					var p := vec(sample["global"][source_pelvis].position)
					local.origin = globals[root_bone].origin + (p - source_global_rests[source_pelvis].origin) * scale_factor
					animation.position_track_insert_key(pos_track, t, local.origin)
				target_global.append(parent_global * local)
			var decoded_source: Array[Transform3D] = []
			for i in source_tracks.size():
				var local := transform(sample.local[i])
				native.position_track_insert_key(source_tracks[i][0], t, local.origin)
				native.rotation_track_insert_key(source_tracks[i][1], t, local.basis.orthonormalized().get_rotation_quaternion())
				native.scale_track_insert_key(source_tracks[i][2], t, local.basis.get_scale())
				var parent: int = data.bones[i].parent
				var global := decoded_source[parent] * local if parent >= 0 else local
				decoded_source.append(global)
				max_source_position_error = maxf(max_source_position_error, global.origin.distance_to(vec(sample["global"][i].position)))
		assert(max_source_position_error < 0.00001, "Decoded source FK mismatch: " + String(clip.name))
		for a in [animation, native]:
			a.set_meta("native_asset_id", clip.source_sha256)
			a.set_meta("source_asset_sha256", clip.source_sha256)
			a.set_meta("source_asset_path", clip.source_path)
			a.set_meta("source_attribution", clip.source_attribution)
			a.set_meta("additive_source", false)
			a.set_meta("original_duration_seconds", clip.length)
		animation.set_meta("derivation", "AGLS FK Direct channels retargeted by global rest rotation differences to Frontier Actor_B; target bind positions and bone lengths retained; source pelvis drives target root")
		animation.set_meta("retarget_translation_scale", scale_factor)
		native.set_meta("derivation", data.decoder)
		library.add_animation(StringName(clip.name), animation)
		source_library.add_animation(StringName(clip.name), native)
		reports.append({"clip": clip.name, "length": clip.length, "samples": clip.samples.size(), "mapped_bones": map_indices.size(),
			"source_sha256": clip.source_sha256, "max_source_fk_error_m": max_source_position_error})
		print("AGLS_RETARGET ", clip.name, " bones=", map_indices.size(), " source_fk_error_m=", max_source_position_error)
	var source_player := AnimationPlayer.new()
	source_player.name = "AnimationPlayer"
	source_root.add_child(source_player)
	source_player.owner = source_root
	source_player.add_animation_library(&"agls_source", source_library)
	assert(ResourceSaver.save(library, OUTPUT) == OK)
	assert(ResourceSaver.save(source_library, SOURCE_OUTPUT) == OK)
	var packed := PackedScene.new()
	assert(packed.pack(source_root) == OK)
	assert(ResourceSaver.save(packed, SOURCE_SCENE) == OK)
	var file := FileAccess.open("res://.comparison-private/reports/conversion.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"clips": reports, "bone_mapping": mapping, "root_translation_scale": scale_factor,
		"native_fk_round_trip_verified": true, "original_durations_preserved": true,
		"limitations": ["Unreal notifies, motion matching, IK and animation Blueprint behavior are not imported", "Retargeted pose is a preview and needs contact tuning for production"]}, "\t"))
	rig.queue_free()
	source_root.free()
	quit()

func track(a: Animation, type: Animation.TrackType, bone: String) -> int:
	var i := a.add_track(type)
	a.track_set_path(i, NodePath("Skeleton3D:" + bone))
	a.track_set_interpolation_type(i, Animation.INTERPOLATION_LINEAR)
	return i

func vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func transform(row: Dictionary) -> Transform3D:
	var a: Array = row.rotation
	var rotation := Basis(Quaternion(float(a[0]), float(a[1]), float(a[2]), float(a[3])).normalized())
	if row.has("basis"):
		rotation = Basis(vec(row.basis[0]), vec(row.basis[1]), vec(row.basis[2]))
	elif row.has("scale"):
		rotation = rotation.scaled_local(vec(row.scale))
	return Transform3D(rotation, vec(row.position))
