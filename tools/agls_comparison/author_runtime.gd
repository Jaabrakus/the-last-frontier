extends SceneTree
## Adapt approved comparison poses to Frontier's existing runtime layers and traversal stages.
const OUT := "res://animations_extra/Frontier_Legacy/Frontier_Legacy_Runtime.res"
const CONFIG := "res://data/anim_author/frontier_legacy_gameplay.json"
const LIB := "frontier_legacy_runtime"
var source: AnimationLibrary
var native: AnimationLibrary
var output := AnimationLibrary.new()
var sampler: TravClipSampler
var upper: Array
var config := {"enabled": true, "charge_trajectory": true, "clips": {}, "actions": {}, "pitch": {}, "vaults": {}}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rig := RigFixture.actor_b(root, {"tree": false})
	sampler = TravClipSampler.from_skeleton(rig.sk)
	source = load("res://animations_extra/Frontier_Legacy/Frontier_Legacy.res")
	native = load("res://animations/Actor_B.res")
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AnimGraphData.METRICS_PATH))
	upper = metrics.bone_sets.upper
	for stance: String in ["stand", "crouch"]:
		var suffix := "_crouch" if stance == "crouch" else ""
		var aim := source.get_animation("frontier_legacy_bow_aim" + suffix)
		var neutral := freeze(aim, aim.length * 0.5)
		var up := difference(aim, 0.0, neutral)
		var down := difference(aim, aim.length, neutral)
		add("bow_aim_" + stance, neutral)
		add("bow_up_" + stance, up)
		add("bow_down_" + stance, down)
		var draw := source.get_animation("frontier_legacy_bow_draw" + suffix)
		var charge := trajectory(draw, neutral)
		add("bow_charge_" + stance, charge)
		var release := source.get_animation("frontier_legacy_bow_release")
		var stand_neutral := freeze(source.get_animation("frontier_legacy_bow_aim"), 0.5)
		add("bow_fire_" + stance, recoil(release, stand_neutral, charge))
		# Frontier plays a holster backwards and holds its first frame. Reverse the approved
		# forward sheath during baking so that the existing stage clock plays it forward.
		add("bow_holster_" + stance, sheath(source.get_animation("frontier_legacy_bow_sheath" + suffix)))
		var base_alias := "actor_b-p-bow-aim-idle" if stance == "stand" else "actor_b-p-bow-aim-crouch-idle"
		var hands_alias := "actor_b-p-bow-aim-hands-idle" if stance == "stand" else "actor_b-p-bow-aim-crouch-hands-idle"
		var aim_prefix := "actor_b-p-bow-" + ("crouch-" if stance == "crouch" else "") + "aim-"
		map_clip(base_alias, "bow_aim_" + stance)
		map_clip(hands_alias, "bow_aim_" + stance)
		map_clip(aim_prefix + "up--add", "bow_up_" + stance)
		map_clip(aim_prefix + "down--add", "bow_down_" + stance)
		map_clip(aim_prefix + "charge--add", "bow_charge_" + stance)
		map_clip("actor_b-p-bow-fire--add" if stance == "stand" else "actor_b-p-crouch-bow-fire--add", "bow_fire_" + stance)
		var holster_alias := "frontier-legacy-bow-holster-" + stance
		map_clip(holster_alias, "bow_holster_" + stance)
		config.actions["bow/" + stance + "/holster"] = {"partial": holster_alias, "twin": null}
		config.pitch["bow/" + stance] = calibrate(neutral, up, down)
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TravMoveLibrary.TABLE))
	var move: Dictionary = runtime.moves.vault_sprint
	for hand: String in ["left", "right"]:
		var full := source.get_animation("frontier_legacy_vault_" + hand + "_hand")
		config.vaults[hand] = {}
		for i in move.parts.size():
			var part: Dictionary = move.parts[i]
			var name := "vault_" + hand + "_" + str(i + 1)
			add(name, vault_part(full, native.get_animation(part.clip), float(part.t0)))
			config.vaults[hand][part.clip] = LIB + "/" + name
	config["library"] = OUT
	config["library_name"] = LIB
	config["source_library_sha256"] = FileAccess.get_sha256("res://animations_extra/Frontier_Legacy/Frontier_Legacy.res")
	config["about"] = "Worktree runtime adapters of the approved blend; gameplay clocks, projectile ownership and traversal paths remain Frontier. Bow aim sweeps become directional layers; vaults are split into the existing four stages."
	assert(ResourceSaver.save(output, OUT, ResourceSaver.FLAG_COMPRESS) == OK)
	FileAccess.open(CONFIG, FileAccess.WRITE).store_string(JSON.stringify(config, "\t") + "\n")
	print("FRONTIER_LEGACY_RUNTIME_READY clips=", output.get_animation_list().size())
	rig.root.queue_free()
	quit()

func metadata(a: Animation, donor: Animation, operation: String) -> void:
	for key in donor.get_meta_list():
		a.set_meta(key, donor.get_meta(key))
	a.set_meta("runtime_adapter", operation)
	a.set_meta("approved_variant_identity", donor.get_meta("variant_identity", ""))
	a.set_meta("sample_rate", 120.0)
	a.set_meta("variant_identity", (str(donor.get_meta("variant_identity", "")) + "|runtime-v1|" + operation).sha256_text())

func add(name: String, a: Animation) -> void:
	a.resource_name = "frontier_legacy_" + name
	assert(output.add_animation(name, a) == OK)

func map_clip(alias: String, name: String) -> void:
	config.clips[alias] = {"lib": LIB, "clip": name, "length": output.get_animation(name).length}

func new_track(a: Animation, type: int, bone: String) -> int:
	var tr := a.add_track(type)
	a.track_set_path(tr, NodePath("Skeleton3D:" + bone))
	return tr

func freeze(a: Animation, time: float) -> Animation:
	var out := Animation.new()
	out.length = 1.0
	out.loop_mode = Animation.LOOP_LINEAR
	for b in sampler.bone_count():
		var p := sampler.local(a, b, time)
		out.position_track_insert_key(new_track(out, Animation.TYPE_POSITION_3D, sampler.names[b]), 0.0, p.origin)
		out.rotation_track_insert_key(new_track(out, Animation.TYPE_ROTATION_3D, sampler.names[b]), 0.0, p.basis.get_rotation_quaternion())
	metadata(out, a, "Neutral aim held at the middle of the approved sweep")
	return out

func insert_delta(out: Animation, p: int, r: int, b: int, time: float, target: Transform3D, center: Transform3D) -> void:
	var rest: Transform3D = sampler.rest[b]
	out.position_track_insert_key(p, time, rest.origin + target.origin - center.origin)
	var q := (rest.basis.get_rotation_quaternion() * center.basis.get_rotation_quaternion().inverse() * target.basis.get_rotation_quaternion()).normalized()
	if out.track_get_key_count(r) > 0:
		var prev: Quaternion = out.track_get_key_value(r, out.track_get_key_count(r) - 1)
		if prev.dot(q) < 0.0: q = -q
	out.rotation_track_insert_key(r, time, q)

func difference(a: Animation, time: float, neutral: Animation) -> Animation:
	var out := Animation.new()
	out.length = 1.0
	out.loop_mode = Animation.LOOP_LINEAR
	for bone: String in upper:
		var b := sampler.bone(bone)
		if b < 0: continue
		insert_delta(out, new_track(out, Animation.TYPE_POSITION_3D, bone), new_track(out, Animation.TYPE_ROTATION_3D, bone), b, 0.0, sampler.local(a, b, time), sampler.local(neutral, b, 0.0))
	metadata(out, a, "Rest-relative upper body aim direction from approved sweep at " + str(time))
	return out

func trajectory(a: Animation, neutral: Animation) -> Animation:
	var out := Animation.new()
	out.length = a.length
	for bone: String in upper:
		var b := sampler.bone(bone)
		if b < 0: continue
		var p := new_track(out, Animation.TYPE_POSITION_3D, bone)
		var r := new_track(out, Animation.TYPE_ROTATION_3D, bone)
		var center := sampler.local(neutral, b, 0.0)
		for k in 121:
			var u := float(k) / 120
			var target := sampler.local(a, b, u * a.length)
			var blend := smoothstep(0.0, 0.12, u)
			target = Transform3D(Basis(center.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), blend)), center.origin.lerp(target.origin, blend))
			insert_delta(out, p, r, b, u * a.length, target, center)
	metadata(out, a, "Charge-seeked upper body trajectory; neutral at zero draw; full additive weight")
	return out

func recoil(a: Animation, neutral: Animation, charge: Animation) -> Animation:
	var out := Animation.new()
	out.length = a.length
	for bone: String in upper:
		var b := sampler.bone(bone)
		if b < 0: continue
		var p := new_track(out, Animation.TYPE_POSITION_3D, bone)
		var r := new_track(out, Animation.TYPE_ROTATION_3D, bone)
		var center := sampler.local(neutral, b, 0.0)
		var rest: Transform3D = sampler.rest[b]
		for k in ceili(a.length * 120) + 1:
			var t := minf(float(k) / 120, a.length)
			var target := sampler.local(a, b, t)
			var return_w := 1.0 - smoothstep(0.78, 1.0, t / a.length)
			target = Transform3D(Basis(center.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), return_w)), center.origin.lerp(target.origin, return_w))
			# Subtract the held draw while the existing fire fade hands it to this OneShot.
			var c := sampler.local(charge, b, maxf(1.0 - t / 0.08, 0.0) * charge.length)
			var under_q := (center.basis.get_rotation_quaternion() * rest.basis.get_rotation_quaternion().inverse() * c.basis.get_rotation_quaternion()).normalized()
			var under := Transform3D(Basis(under_q), center.origin + c.origin - rest.origin)
			insert_delta(out, p, r, b, t, target, under)
	metadata(out, a, "Upper body recoil, held-draw handoff and neutral tail; stance comes from the live lower graph")
	return out

func sheath(a: Animation) -> Animation:
	var out := Animation.new()
	out.length = a.length
	for bone: String in upper:
		var b := sampler.bone(bone)
		if b < 0: continue
		var p := new_track(out, Animation.TYPE_POSITION_3D, bone)
		var r := new_track(out, Animation.TYPE_ROTATION_3D, bone)
		for k in ceili(a.length * 120) + 1:
			var t := minf(float(k) / 120, a.length)
			var pose := sampler.local(a, b, a.length - t)
			out.position_track_insert_key(p, t, pose.origin)
			out.rotation_track_insert_key(r, t, pose.basis.get_rotation_quaternion())
	metadata(out, a, "Upper body sheath reversed for Frontier's existing reverse holster stage")
	return out

func vault_part(full: Animation, original: Animation, offset: float) -> Animation:
	var out: Animation = original.duplicate(true)
	for tr in range(out.get_track_count() - 1, -1, -1):
		if out.track_get_type(tr) == Animation.TYPE_ROTATION_3D and String(out.track_get_path(tr).get_concatenated_subnames()) != "root":
			out.remove_track(tr)
	for tr in full.get_track_count():
		if full.track_get_type(tr) != Animation.TYPE_ROTATION_3D: continue
		var bone := String(full.track_get_path(tr).get_concatenated_subnames())
		if bone == "root": continue
		var r := new_track(out, Animation.TYPE_ROTATION_3D, bone)
		var count := ceili(original.length * 120)
		for k in count + 1:
			var time := float(k) / count * original.length
			# A composed clip changes source at a join; the outgoing stage ends just before it.
			var sample_time := offset + time - (0.00001 if k == count and offset + time < full.length else 0.0)
			out.rotation_track_insert_key(r, time, full.rotation_track_interpolate(tr, sample_time))
	metadata(out, full, "Vault stage at " + str(offset) + "; original root and translation channels retained")
	out.set_meta("runtime_stage_native_asset_id", original.get_meta("native_asset_id", ""))
	return out

func calibrate(base: Animation, up: Animation, down: Animation) -> Dictionary:
	var weights := []
	var elev := []
	var yaw := []
	var prop := sampler.bone("l_hand_prop_attachment")
	var order := sampler.closure(PackedInt32Array([prop]))
	for i in range(-20, 21):
		var w := float(i) / 20
		var globals := {}
		for b in order:
			var pose := sampler.local(base, b, 0.0)
			var add_pose := sampler.local(up if w >= 0.0 else down, b, 0.0)
			var rest: Transform3D = sampler.rest[b]
			var delta := rest.basis.get_rotation_quaternion().inverse() * add_pose.basis.get_rotation_quaternion()
			var rot := pose.basis.get_rotation_quaternion() * Quaternion.IDENTITY.slerp(delta, absf(w))
			var local := Transform3D(Basis(rot), pose.origin + (add_pose.origin - rest.origin) * absf(w))
			globals[b] = globals[sampler.parents[b]] * local if sampler.parents[b] >= 0 else local
		var dir: Vector3 = (globals[prop].basis * Vector3.FORWARD * -1).normalized()
		weights.append(w)
		elev.append(rad_to_deg(asin(clampf(dir.y, -1, 1))))
		yaw.append(rad_to_deg(atan2(dir.x, dir.z)))
	var table := {"weights": weights, "elev_deg": elev, "yaw_deg": yaw, "solve_up": 1.0, "solve_down": 1.0,
		"zero_elev_deg": elev[20], "zero_yaw_deg": yaw[20], "barrel_bone": "l_hand_prop_attachment", "barrel_axis": "+Z"}
	for i in range(1, elev.size()):
		assert(elev[i] > elev[i - 1], "New bow aim range is not monotonic")
	return table
