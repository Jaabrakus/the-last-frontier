extends SceneTree
## Frontier is the base. AGLS contributes joint rotations; Frontier owns timing and root travel.
const Mapping := preload("res://tools/agls_comparison/author_upper.gd")
const Names := preload("res://tools/agls_comparison/legacy_names.gd")
const FRONTIER := "res://.comparison-private/Actor_B_original.res"
const AGLS := "res://animations_extra/AGLS_Preview.res"
const CONFIG := "res://animations_extra/Frontier_Legacy/blend_settings.json"
const REFERENCE_OUT := "res://animations_extra/Frontier_Comparison_Reference.res"
const OUTPUT := "res://animations_extra/Frontier_Legacy/Frontier_Legacy.res"
var sampler: TravClipSampler
var source: AnimationLibrary
var settings: Dictionary
var vault_move: Dictionary
var original_hash := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	source = load(FRONTIER)
	var agls: AnimationLibrary = load(AGLS)
	settings = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	original_hash = FileAccess.get_sha256(FRONTIER)
	var rig: Node3D = load("res://characters/Actor_B.tscn").instantiate()
	root.add_child(rig)
	var sk: Skeleton3D = rig.get_node("Skeleton3D")
	sampler = TravClipSampler.from_skeleton(sk)
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.comparison-private/traversal_runtime_original.json"))
	vault_move = runtime.moves[settings.vault_reference_move]
	var full_vault := compose_vault()
	var weapon_refs: AnimationLibrary = load("res://animations_extra/Frontier_Weapon_Original.res")
	var refs := AnimationLibrary.new()
	var variants := AnimationLibrary.new()
	var rows := []
	for name in agls.get_animation_list():
		var kind := "vault" if "Vault" in String(name) else ("jump" if "Jump" in String(name) else ("weapon" if "Props_" in String(name) else ("climb" if String(name).begins_with("LMv2_") or String(name).begins_with("CMC_") or "Mantle" in String(name) else "locomotion")))
		var original: Animation = full_vault if kind == "vault" else source.get_animation(Mapping.REFERENCES[String(name)])
		if kind == "weapon":
			original = weapon_refs.get_animation(name)
		elif String(name) == "LMv2_Exit_Ladder_Up_01":
			vault_move = runtime.moves.ladder_dismount_top
			original = compose_vault()
		refs.add_animation(name, original)
		var motion := agls.get_animation(name)
		var phase := best_stride_phase(original, motion) if kind == "locomotion" else 0.0
		var variant := blend(original, motion, kind, phase, String(name))
		var legacy_name: String = Names.CLIPS[String(name)]
		variant.set_meta("frontier_legacy_clip", legacy_name)
		assert(ResourceSaver.save(variant, "res://animations_extra/Frontier_Legacy/clips/" + legacy_name + ".res", ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_COMPRESS) == OK)
		variants.add_animation(legacy_name, variant)
		var row := {"clip": name, "frontier_legacy_clip": legacy_name, "frontier_reference": Mapping.REFERENCES[String(name)] if kind != "vault" else settings.vault_reference_move,
			"duration": variant.length, "agls_rotation_weights": settings[kind], "agls_phase_offset": phase,
			"root_and_position_tracks_identical": position_signature(variant) == position_signature(original),
			"leg_tracks_identical": leg_signature(variant) == leg_signature(original) if kind == "locomotion" else false,
			"variant_identity": variant.get_meta("variant_identity"), "source_sha256": motion.get_meta("source_asset_sha256")}
		if not row.root_and_position_tracks_identical:
			push_error("Frontier root/translation changed: " + String(name))
			quit(1)
			return
		if kind == "locomotion":
			assert(row.leg_tracks_identical, "Frontier gait contacts changed: " + String(name))
		rows.append(row)
		print("FRONTIER_AGLS_VARIANT ", name, " length=", variant.length, " AGLS=", settings[kind])
	assert(ResourceSaver.save(refs, REFERENCE_OUT) == OK)
	assert(ResourceSaver.save(variants, OUTPUT) == OK)
	var file := FileAccess.open("res://.comparison-private/reports/frontier-variants.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"method": "Frontier base, AGLS local joint rotation blend", "config": settings,
		"frontier_snapshot_sha256": original_hash, "vault_reference_parts": vault_move.parts, "variants": rows}, "\t") + "\n")
	var manifest := FileAccess.open("res://animations_extra/Frontier_Legacy/clip_manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"name": "Frontier Legacy", "base": "Frontier", "method": "Authored blend of existing Frontier and AGLS motion", "source_library_sha256": original_hash, "config": settings, "clips": rows}, "\t") + "\n")
	rig.queue_free()
	quit()

func compose_vault() -> Animation:
	var full := Animation.new()
	full.length = float(vault_move.duration)
	full.loop_mode = Animation.LOOP_NONE
	var channels := {}
	var source_ids := []
	for part: Dictionary in vault_move.parts:
		var clip := source.get_animation(part.clip)
		source_ids.append(clip.get_meta("native_asset_id"))
		for t in clip.get_track_count():
			var type := clip.track_get_type(t)
			if type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				channels[String(clip.track_get_path(t)) + "|" + str(type)] = {"path": clip.track_get_path(t), "type": type}
	var count := ceili(full.length * float(settings.sample_rate))
	var align_start := align_at(0)
	for channel: Dictionary in channels.values():
		var path: NodePath = channel.path
		var bone := String(path.get_concatenated_subnames())
		var b := sampler.bone(bone)
		if b < 0:
			continue
		var track := full.add_track(channel.type)
		full.track_set_path(track, path)
		var prev := Quaternion.IDENTITY
		for k in count + 1:
			var time := float(PackedFloat32Array([float(k) / count * full.length])[0])
			var part := part_at(time)
			var clip := source.get_animation(part.clip)
			var pose := sampler.local(clip, b, clampf(time - float(part.t0), 0, clip.length))
			match channel.type:
				Animation.TYPE_POSITION_3D:
					var pos := pose.origin
					if bone == "root":
						pos += align_at(time) - align_start
					full.position_track_insert_key(track, time, pos)
				Animation.TYPE_ROTATION_3D:
					var q := pose.basis.get_rotation_quaternion().normalized()
					if k > 0 and prev.dot(q) < 0:
						q = -q
					prev = q
					full.rotation_track_insert_key(track, time, q)
				Animation.TYPE_SCALE_3D:
					full.scale_track_insert_key(track, time, pose.basis.get_scale())
	full.set_meta("native_asset_ids", source_ids)
	full.set_meta("source_attribution", source.get_animation(vault_move.parts[0].clip).get_meta("source_attribution", ""))
	full.set_meta("original_name", settings.vault_reference_move)
	full.set_meta("derivation", "Complete Frontier traversal assembled from its original parts and reference align path; no AGLS")
	full.set_meta("sample_rate", float(settings.sample_rate))
	return full

func part_at(time: float) -> Dictionary:
	var chosen: Dictionary = vault_move.parts[0]
	for part: Dictionary in vault_move.parts:
		if time + 1e-4 >= float(part.t0):
			chosen = part
	return chosen

func align_at(time: float) -> Vector3:
	var tr: Dictionary = vault_move.track
	var x := clampf(time * float(tr.hz), 0, float(tr.n) - 1)
	var i := mini(floori(x), int(tr.n) - 1)
	var j := mini(i + 1, int(tr.n) - 1)
	var v: Array = tr.align
	return Vector3(v[3*i], v[3*i+1], v[3*i+2]).lerp(Vector3(v[3*j], v[3*j+1], v[3*j+2]), x - i)

func blend(original: Animation, agls: Animation, kind: String, offset: float, source_name: String) -> Animation:
	var variant: Animation = original.duplicate(true)
	var weights: Dictionary = settings[kind]
	var count := ceili(original.length * float(settings.sample_rate))
	for at in agls.get_track_count():
		if agls.track_get_type(at) != Animation.TYPE_ROTATION_3D:
			continue
		var path := agls.track_get_path(at)
		var bone := String(path.get_concatenated_subnames())
		var amount := float(weights.get(group(bone), 0))
		if amount <= 0 or bone == "root":
			continue
		var old_track := variant.find_track(path, Animation.TYPE_ROTATION_3D)
		var reference_track := original.find_track(path, Animation.TYPE_ROTATION_3D)
		if old_track >= 0:
			variant.remove_track(old_track)
		var track := variant.add_track(Animation.TYPE_ROTATION_3D)
		variant.track_set_path(track, path)
		var rest_q: Quaternion = sampler.rest[sampler.bone(bone)].basis.get_rotation_quaternion()
		var previous := Quaternion.IDENTITY
		for k in count + 1:
			var time := float(k) / count * original.length
			var phase := time / original.length
			var agls_time := (fposmod(phase + offset, 1) if kind == "locomotion" else phase) * agls.length
			var weight := amount
			if kind != "locomotion":
				var edge := float(settings.action_edge_fade)
				weight *= smoothstep(0, edge, phase) * smoothstep(0, edge, 1 - phase)
			var a := original.rotation_track_interpolate(reference_track, time) if reference_track >= 0 else rest_q
			var b := agls.rotation_track_interpolate(at, agls_time)
			var q := a.normalized().slerp(b.normalized(), weight).normalized()
			if k > 0 and previous.dot(q) < 0:
				q = -q
			previous = q
			assert(q.is_finite(), "Non-finite blended pose")
			variant.rotation_track_insert_key(track, time, q)
	variant.set_meta("sample_rate", float(settings.sample_rate))
	variant.set_meta("frontier_base_variant", true)
	variant.set_meta("agls_original_name", source_name)
	variant.set_meta("agls_native_asset_id", agls.get_meta("native_asset_id"))
	variant.set_meta("agls_source_sha256", agls.get_meta("source_asset_sha256"))
	variant.set_meta("frontier_reference_library_sha256", original_hash)
	if kind == "weapon":
		variant.set_meta("frontier_weapon_reference_sha256", FileAccess.get_sha256("res://animations_extra/Frontier_Weapon_Original.res"))
	variant.set_meta("variant_identity", (original_hash + "|" + String(agls.get_meta("source_asset_sha256")) + "|frontier-base-v1|" + JSON.stringify(settings) + "|" + str(offset)).sha256_text())
	variant.set_meta("derivation", "Frontier base clip with phase-aligned AGLS joint rotations; both source identities retained")
	variant.set_meta("blend_authoring", {"base": "Frontier", "agls_rotation_weights": weights, "agls_phase_offset": offset,
		"timing_source": "Frontier", "root_and_position_tracks_preserved": true, "preview_only_action": kind != "locomotion"})
	return variant

static func group(bone: String) -> String:
	if bone == "pelvis":
		return "hips"
	for part in ["upper_leg", "knee", "ankle", "ball", "heel"]:
		if part in bone:
			return "legs"
	return Mapping.group_for_bone(bone)

func best_stride_phase(original: Animation, agls: Animation) -> float:
	var best_offset := 0.0
	var best_error := INF
	for step in 60:
		var offset := float(step) / 60
		var error := 0.0
		for bone in ["l_upper_leg", "r_upper_leg", "l_knee", "r_knee"]:
			var a := original.find_track(NodePath("Skeleton3D:" + bone), Animation.TYPE_ROTATION_3D)
			var b := agls.find_track(NodePath("Skeleton3D:" + bone), Animation.TYPE_ROTATION_3D)
			if a < 0 or b < 0:
				continue
			for k in 24:
				var phase := float(k) / 24
				var qa := original.rotation_track_interpolate(a, phase * original.length).normalized()
				var qb := agls.rotation_track_interpolate(b, fposmod(phase + offset, 1) * agls.length).normalized()
				error += 1 - absf(qa.dot(qb))
		if error < best_error:
			best_error = error
			best_offset = offset
	return best_offset

static func position_signature(a: Animation) -> Array:
	var rows := []
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D and String(a.track_get_path(t).get_concatenated_subnames()) != "root":
			continue
		rows.append(track_signature(a, t))
	return rows

static func leg_signature(a: Animation) -> Array:
	var rows := []
	for t in a.get_track_count():
		if group(String(a.track_get_path(t).get_concatenated_subnames())) == "legs":
			rows.append(track_signature(a, t))
	return rows

static func track_signature(a: Animation, track: int) -> Array:
	var keys := []
	for k in a.track_get_key_count(track):
		keys.append([a.track_get_key_time(track, k), a.track_get_key_value(track, k), a.track_get_key_transition(track, k)])
	return [a.track_get_type(track), a.track_get_path(track), a.track_get_interpolation_type(track), keys]
