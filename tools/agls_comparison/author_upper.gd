extends SceneTree
## Blend the existing Frontier upper body over a separate AGLS derivative.
const INPUT := "res://animations_extra/AGLS_Preview.res"
const OUTPUT := "res://animations_extra/AGLS_Upper_Variants.res"
const WEIGHTS := {"torso": 0.85, "arms": 0.95, "hands": 0.95, "head": 1.0}
const REFERENCES := {
	"ALSv2_Mantle_2m_Walking_01": "actor_b-p-ledge-chest-climb-up^idle",
	"ALSv2_Mantle_2m_Walking_02": "actor_b-p-ledge-chest-climb-up^run",
	"LMv2_Movement_Up_01": "actor_b-p-ladder-climb-up",
	"LMv2_Movement_Down_01": "actor_b-p-ladder-climb-down",
	"LMv2_Exit_Ladder_Up_01": "actor_b-p-ladder-dismount--top-start",
	"LMv2_Enter_Ladder_Down_01": "actor_b-p-ladder-mount-top",
	"CMC_Climb_Hanging_Idle_Loop": "actor_b-p-ledge-idle",
	"CMC_Shimmy_Long_LH_U": "actor_b-p-ledge-hang-climb-up^ledge-knee",

	"ALS_CLF_Walk_F": "actor_b-p-crouch-walk-fw",
	"ALS_CLF_Walk_B": "actor_b-p-crouch-walk-bw",
	"ALS_CLF_Walk_L": "actor_b-p-crouch-walk-fw-lt",
	"ALS_CLF_Walk_R": "actor_b-p-crouch-walk-fw-rt",
	"ALS_Props_Bow_Aim_Sweep": "actor_b-p-bow-aim-idle",
	"ALS_Props_Bow_Aim_Sweep_Crouched": "actor_b-p-bow-aim-crouch-idle",
	"ALS_Props_RecurveBow_Draw_Stand": "actor_b-p-bow-aim-idle",
	"ALS_Props_RecurveBow_Draw_Crouch": "actor_b-p-bow-aim-crouch-idle",
	"ALS_Props_RecurveBow_Recoil": "actor_b-p-bow-aim-idle",
	"ALS_Props_Bow_Sheath_Stand": "actor_b-p-relax-idle",
	"ALS_Props_Bow_Sheath_Crouch": "actor_b-p-crouch-idle",
	"ALS_Props_Rifle_Aim_Sweep": "actor_b-p-rifle-idle-aim",
	"ALS_Props_Rifle_Aim_Sweep_Crouched": "actor_b-p-rifle-aim-crouch-idle",

	"ALS_N_Walk_F": "actor_b-p-walk-fw", "ALS_N_Walk_B": "actor_b-p-walk-bw",
	"ALS_N_Walk_LF": "actor_b-p-walk-fw-lt", "ALS_N_Walk_RF": "actor_b-p-walk-fw-rt",
	"ALS_N_Run_F": "actor_b-p-run-fw", "ALS_N_Run_B": "actor_b-p-run-bw",
	"ALS_N_Run_LF": "actor_b-p-run-fw-lt", "ALS_N_Run_RF": "actor_b-p-run-fw-rt",
	"ALS_N_Sprint_F": "actor_b-p-sprint-fw", "ALSv2_JumpSeq_Idle": "actor_b-p-jump-long",
	"ALSv2_N_Vault_1m_LH": "actor_b-p-vault-1m", "ALSv2_N_Vault_1m_RH": "actor_b-p-vault-1m",
}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var base: AnimationLibrary = load(INPUT)
	var reference: AnimationLibrary = load("res://.comparison-private/Actor_B_original.res")
	var rig: Node3D = load("res://characters/Actor_B.tscn").instantiate()
	root.add_child(rig)
	var sk: Skeleton3D = rig.get_node("Skeleton3D")
	var upper := {}
	var weights: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/anim_author/agls_upper.json"))
	var upper_root := sk.find_bone("upper_base")
	for i in sk.get_bone_count():
		var p := i
		while p >= 0:
			if p == upper_root:
				upper[String(sk.get_bone_name(i))] = i
				break
			p = sk.get_bone_parent(p)
	var result := AnimationLibrary.new()
	var reports := []
	for name in base.get_animation_list():
		var original := base.get_animation(name)
		var legacy := reference.get_animation(REFERENCES[String(name)])
		var variant: Animation = original.duplicate(true)
		var before := unaffected_tracks(original, upper)
		var authored := []
		for bone: String in upper:
			var rest := sk.get_bone_rest(upper[bone])
			var group := group_for_bone(bone)
			var amount := clampf(float(weights.get(group, WEIGHTS[group])), 0, 1)
			for type in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
				var source_track := find_track(legacy, bone, type)
				if source_track < 0:
					continue
				var base_track := find_track(original, bone, type)
				var old_track := find_track(variant, bone, type)
				if old_track >= 0:
					variant.remove_track(old_track)
				var track := variant.add_track(type)
				variant.track_set_path(track, NodePath("Skeleton3D:" + bone))
				variant.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
				var previous := Quaternion.IDENTITY
				var count := ceili(original.length*120)
				for i in count+1:
					var t := float(i)/count*original.length
					var phase := t/original.length
					var rt := phase*legacy.length
					var w := amount
					# Full upper-body style match. Transitions retain the source's entry/exit pose.
					if original.loop_mode == Animation.LOOP_NONE:
						w *= smoothstep(0.0, 0.1, phase)*smoothstep(0.0, 0.1, 1.0-phase)
					if type == Animation.TYPE_ROTATION_3D:
						var base_q := original.rotation_track_interpolate(base_track, t) if base_track >= 0 else rest.basis.get_rotation_quaternion()
						var legacy_q := legacy.rotation_track_interpolate(source_track, rt)
						var q := base_q.normalized().slerp(legacy_q.normalized(), w).normalized()
						if i > 0 and previous.dot(q) < 0:
							q = -q
						previous = q
						variant.rotation_track_insert_key(track, t, q)
					else:
						var base_p := original.position_track_interpolate(base_track, t) if base_track >= 0 else rest.origin
						var legacy_p := legacy.position_track_interpolate(source_track, rt)
						variant.position_track_insert_key(track, t, base_p.lerp(legacy_p, w))
				authored.append({"bone": bone, "track_type": type, "weight": amount})
		assert(unaffected_tracks(variant, upper) == before, "AGLS hips/legs or root tracks changed: " + String(name))
		variant.set_meta("original_name", String(name))
		variant.set_meta("upper_variant", true)
		variant.set_meta("sample_rate", 120.0)
		variant.set_meta("variant_identity", (String(original.get_meta("source_asset_sha256"))+"|"+FileAccess.get_sha256("res://.comparison-private/Actor_B_original.res")+"|frontier-full-upper-v1|"+String(name)+"|"+JSON.stringify(weights)).sha256_text())
		variant.set_meta("upper_reference_clip", REFERENCES[String(name)])
		variant.set_meta("upper_reference_native_asset_id", legacy.get_meta("native_asset_id"))
		variant.set_meta("upper_authoring", {"method": "Phase-aligned full upper-body local pose blend; 120 Hz authoring", "weights": weights,
			"source_timing_preserved": true, "hips_and_legs_tracks_preserved": true, "root_tracks_preserved": true})
		result.add_animation(name, variant)
		reports.append({"name": name, "authored_upper_tracks": authored, "reference": REFERENCES[String(name)], "unaffected_tracks_identical": true})
		print("AGLS_UPPER_VARIANT ", name, " upper_tracks=", authored.size())
	assert(ResourceSaver.save(result, OUTPUT) == OK)
	var file := FileAccess.open("res://.comparison-private/reports/upper-variants.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"variants": reports, "method": "Full upper-body reference blend in a separate derived library", "hips_legs_and_root_tracks_preserved": true}, "\t"))
	rig.queue_free()
	quit()

func find_track(a: Animation, bone: String, type: Animation.TrackType) -> int:
	for t in a.get_track_count():
		if a.track_get_type(t) == type and String(a.track_get_path(t).get_concatenated_subnames()) == bone:
			return t
	return -1

static func group_for_bone(bone: String) -> String:
	if bone in ["upper_base", "spinea", "spineb", "spinec", "spined"]:
		return "torso"
	if bone in ["l_clavicle", "r_clavicle", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist"]:
		return "arms"
	if bone.begins_with("l_") or bone.begins_with("r_"):
		if any_hand_name(bone):
			return "hands"
	return "head"

static func any_hand_name(bone: String) -> bool:
	for part in ["palm", "index", "middle", "ring", "pinky", "thumb", "hand"]:
		if part in bone:
			return true
	return false

func unaffected_tracks(a: Animation, upper: Dictionary) -> Array:
	var tracks := []
	for t in a.get_track_count():
		if upper.has(String(a.track_get_path(t).get_concatenated_subnames())):
			continue
		var keys := []
		for k in a.track_get_key_count(t):
			keys.append([a.track_get_key_time(t, k), a.track_get_key_value(t, k), a.track_get_key_transition(t, k)])
		tracks.append([a.track_get_type(t), a.track_get_path(t), a.track_get_interpolation_type(t), keys])
	return tracks
