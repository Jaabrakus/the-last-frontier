extends SceneTree
## Purposeful movement variants of the approved Frontier Legacy blend.
## Authored timing and posture differences do not change the underlying asset permissions.
const ROOT := "res://animations_extra/Frontier_Legacy/"
var sampler: TravClipSampler
var settings: Dictionary
var skeleton: Skeleton3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "style_settings.json"))
	var base: AnimationLibrary = load(ROOT + "Frontier_Legacy.res")
	var rig: Node3D = load("res://characters/Actor_B.tscn").instantiate()
	root.add_child(rig)
	skeleton = rig.get_node("Skeleton3D")
	sampler = TravClipSampler.from_skeleton(skeleton)
	for style in ["grounded", "athletic"]:
		var folder: String = style.capitalize()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + folder + "/clips"))
		var library := AnimationLibrary.new()
		var rows := []
		for name in base.get_animation_list():
			var original := base.get_animation(name)
			var changed := "walk" in String(name) or "run" in String(name) or "sprint" in String(name) or String(name) == "frontier_legacy_jump" or "vault" in String(name)
			# Weapon and climb contacts stay with the approved preview until specifically authored.
			changed = changed and "mantle" not in String(name)
			var variant: Animation = author(original, String(name), settings[style]) if changed else original.duplicate(true)
			variant.set_meta("frontier_legacy_style", style)
			variant.set_meta("style_authoring", settings[style])
			variant.set_meta("style_base_asset_sha256", FileAccess.get_sha256(original.resource_path))
			variant.set_meta("variant_identity", (String(original.get_meta("variant_identity")) + "|" + style + "|" + JSON.stringify(settings[style])).sha256_text())
			variant.set_meta("derivation", "Frontier Legacy blend with authored stance timing, torso posture and swing knee flex; sources retained")
			variant.set_meta("source_timing_preserved", not changed)
			variant.set_meta("style_motion_changed", changed)
			var blend_info: Dictionary = variant.get_meta("blend_authoring", {}).duplicate(true)
			blend_info["timing_source"] = style if changed else "Frontier"
			blend_info["root_and_position_tracks_preserved"] = not changed
			variant.set_meta("blend_authoring", blend_info)
			variant.set_meta("source_leg_tracks_preserved", not changed)
			variant.set_meta("sample_rate", float(settings.sample_rate))
			assert(ResourceSaver.save(variant, ROOT + folder + "/clips/" + String(name) + ".res", ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_CHANGE_PATH) == OK)
			library.add_animation(name, variant)
			rows.append({"name": name, "original_duration": original.length, "duration": variant.length,
				"timing_and_pose_authored": changed, "source_permission_requirements_retained": true})
		assert(ResourceSaver.save(library, ROOT + folder + "/Frontier_Legacy_" + folder + ".res") == OK)
		var f := FileAccess.open(ROOT + folder + "/manifest.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"name": "Frontier Legacy " + folder, "settings": settings[style], "clips": rows}, "\t") + "\n")
		print("FRONTIER_LEGACY_STYLE_READY style=", style, " clips=", rows.size())
	rig.queue_free()
	quit()

func author(original: Animation, name: String, config: Dictionary) -> Animation:
	var variant: Animation = original.duplicate(true)
	var kind := "walk" if "walk" in name else ("sprint" if "sprint" in name else ("run" if "run" in name else ("vault" if "vault" in name else "jump")))
	var tempo := float(config[kind + "_tempo"])
	variant.length = original.length / tempo
	var bounds := {"l": INF, "r": INF}
	for k in 65:
		var g := sampler.globals(original, original.length * float(k) / 64)
		for side in ["l", "r"]:
			var b := sampler.bone(side + "_ankle")
			bounds[side] = minf(float(bounds[side]), (g[b] as Transform3D).origin.y)
	var count := ceili(variant.length * float(settings.sample_rate))
	for track in range(variant.get_track_count() - 1, -1, -1):
		var type := variant.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var path := variant.track_get_path(track)
		var bone := String(path.get_concatenated_subnames())
		var b := sampler.bone(bone)
		var reference := original.find_track(path, type)
		variant.remove_track(track)
		var out := variant.add_track(type)
		variant.track_set_path(out, path)
		var previous := Quaternion.IDENTITY
		for k in count + 1:
			var phase := float(k) / count
			# Positive bias extends the early stance; negative bias makes a brisker toe-off.
			var source_phase := clampf(phase - float(config.stance_bias) * sin(4 * PI * phase), 0, 1)
			var time := phase * variant.length
			var source_time := source_phase * original.length
			if type == Animation.TYPE_POSITION_3D:
				variant.position_track_insert_key(out, time, original.position_track_interpolate(reference, source_time))
			elif type == Animation.TYPE_SCALE_3D:
				variant.scale_track_insert_key(out, time, original.scale_track_interpolate(reference, source_time))
			else:
				var q := original.rotation_track_interpolate(reference, source_time).normalized()
				var edge := 1.0 if original.loop_mode != Animation.LOOP_NONE else smoothstep(0, 0.08, phase) * smoothstep(0, 0.08, 1-phase)
				if bone in ["spineb", "spined", "neck"]:
					var lean := float(config.forward_lean_degrees) * (0.6 if bone == "spineb" else (0.4 if bone == "spined" else -0.25))
					var axis := skeleton.get_bone_rest(b).basis.inverse() * Vector3.RIGHT
					q = q * Quaternion(axis.normalized(), deg_to_rad(lean) * edge)
					if bone == "spined":
						var roll_axis := skeleton.get_bone_rest(b).basis.inverse() * Vector3.BACK
						q = q * Quaternion(roll_axis.normalized(), deg_to_rad(float(config.counter_roll_degrees)) * sin(2 * PI * phase) * edge)
				elif bone in ["l_knee", "r_knee"]:
					var side := bone.left(1)
					var g := sampler.globals(original, source_time)
					var upper: Transform3D = g[sampler.bone(side + "_upper_leg")]
					var knee: Transform3D = g[b]
					var ankle: Transform3D = g[sampler.bone(side + "_ankle")]
					var swing := smoothstep(0.025, 0.12, ankle.origin.y - float(bounds[side])) * edge
					var hinge := (upper.origin-knee.origin).cross(ankle.origin-knee.origin)
					if hinge.length() > 0.00001:
						var axis := knee.basis.inverse() * hinge.normalized()
						q = q * Quaternion(axis.normalized(), -deg_to_rad(float(config.swing_knee_flex_degrees)) * swing)
				q = q.normalized()
				if k > 0 and previous.dot(q) < 0:
					q = -q
				previous = q
				assert(q.is_finite(), "Non-finite style pose")
				variant.rotation_track_insert_key(out, time, q)
	# The stronger knee bend is limited to the raised foot; stance feet retain their base pose.
	return variant
