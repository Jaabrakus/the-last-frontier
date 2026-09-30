extends SceneTree
## Export the actual Frontier carry graph over Frontier Legacy locomotion.
## These clips retain source identities and need the game's grip/aim modifiers when reused.
const Names := preload("res://tools/agls_comparison/legacy_names.gd")
const UpperRig := preload("res://tests/anim/upper_rig.gd")
const ROOT := "res://animations_extra/Frontier_Legacy/"
const MOVES := [
	["walk_forward", "walk", "fw", 0.0], ["walk_backward", "walk", "bw", 0.0],
	["walk_left", "walk", "fw_lt", 90.0], ["walk_right", "walk", "fw_rt", -90.0],
	["run_forward", "run", "fw", 0.0], ["run_backward", "run", "bw", 0.0],
	["run_left", "run", "fw_lt", 90.0], ["run_right", "run", "fw_rt", -90.0],
	["sprint_forward", "sprint", "fw", 0.0],
]
var rig: RigFixture
var data: AnimGraphData
var index: TreeIndex
var selector: XFadeSelector
var upper: UpperBody
var inp := AnimInputs.new()
var library := AnimationLibrary.new()
var rows := []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "weapons"))
	rig = RigFixture.actor_b(root)
	data = AnimGraphData.load_files()
	index = TreeBuilder.build(data, rig.ap, rig.sk)
	if not index.errors.is_empty():
		push_error(str(index.errors))
		quit(1)
		return
	rig.play(AnimationNodeBlendTree.new())
	index.install(rig.tree)
	selector = XFadeSelector.new(rig.tree, "L", index.L_inputs, index.L_seek)
	upper = UpperBody.new(data, rig.tree, index)
	upper.set_lower_selector(selector)
	inp.alive = true
	inp.on_floor = true
	inp.dt = 0.0
	for weapon in data.weapons():
		for move: Array in MOVES:
			var role := data.role(weapon, move[1], move[2])
			var base: Animation = rig.ap.get_animation(data.godot_anim(String(role.clip)))
			bake(String(weapon), String(move[0]), String(move[1]), String(move[2]), float(move[3]), base.length, false, false)
		for stance in ["stand", "crouch"]:
			var mode := "walk" if stance == "stand" else "crouch"
			var idle := data.role_clip(weapon, mode, "idle")
			var base: Animation = rig.ap.get_animation(data.godot_anim(idle))
			bake(String(weapon), "carry_idle_" + stance, mode, "idle", 0.0, base.length, stance == "crouch", false)
		# Thrown weapons' aim requires their throw controller; keep that live in the game.
		if weapon in ["musket", "pistol", "bow"]:
			for stance in ["stand", "crouch"]:
				bake(String(weapon), "aim_idle_" + stance, "walk" if stance == "stand" else "crouch", "idle", 0.0, 1.0, stance == "crouch", true)
	assert(ResourceSaver.save(library, ROOT + "Frontier_Legacy_Weapons.res") == OK)
	var f := FileAccess.open(ROOT + "weapon_manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"name": "Frontier Legacy weapon poses", "method": "Baked from the existing Frontier AnimationTree and carry/aim controllers over Frontier Legacy base motion",
		"runtime_grip_and_aim_modifiers_required": true, "clips": rows}, "\t") + "\n")
	print("FRONTIER_LEGACY_WEAPONS_READY clips=", rows.size())
	rig.root.queue_free()
	quit()

func bake(weapon: String, suffix: String, mode: String, role: String, angle: float, duration: float, crouched: bool, aiming: bool) -> void:
	inp.weapon_key = StringName(weapon)
	inp.crouched = crouched
	inp.weapon_aim = 1.0 if aiming else 0.0
	inp.wants_aim = aiming
	inp.aim_point = Vector3(0, data.chest_height("crouch" if crouched else "stand"), 25)
	inp.aim_elev_deg = 0
	upper.set_weapon(StringName(weapon))
	upper.snap(inp)
	var id: StringName = StringName("aimidle__%s__%s" % [weapon, "crouch" if crouched else "stand"]) if aiming else index.input_for("%s/%s/%s" % [weapon, mode, role])
	assert(id != &"", "Weapon role has no graph input: " + weapon + "/" + role)
	var rec := index.lower_record(id)
	var hemi := "bw" if role == "bw" else "fw"
	var lower := {}
	if rec.kind == "bank":
		if rec.has("hemi_param"):
			rig.tree.set(rec.hemi_param, 1.0 if hemi == "bw" else 0.0)
		var weights := [maxf(-angle / 90, 0), maxf(angle / 90, 0)]
		index.set_bank_weights(rig.tree, id, hemi, weights[0], weights[1])
		lower = {"hemi_w": {String(id): {"fw": 1.0 if hemi == "fw" else 0.0, "bw": 1.0 if hemi == "bw" else 0.0}}, "dir_w": {String(id): {hemi: weights}}}
	var clip := Animation.new()
	clip.length = duration
	clip.loop_mode = Animation.LOOP_LINEAR
	var paths := []
	for bone in rig.sk.get_bone_count():
		var pos := clip.add_track(Animation.TYPE_POSITION_3D)
		var rot := clip.add_track(Animation.TYPE_ROTATION_3D)
		var path := NodePath("Skeleton3D:" + String(rig.sk.get_bone_name(bone)))
		clip.track_set_path(pos, path)
		clip.track_set_path(rot, path)
		paths.append([pos, rot])
	var count := ceili(duration * 60)
	for k in count + 1:
		var phase := float(k) / count
		selector.set_immediate(id, phase)
		if aiming:
			upper.A.set_immediate(StringName(index.aim["%s/%s" % [weapon, "crouch" if crouched else "stand"]].input), phase)
		upper.tick(inp, &"AIM_IDLE" if aiming else (&"IDLE" if role == "idle" else &"MOVE"), 0.0, lower)
		selector.update(0.0)
		selector.write()
		# Second advance(0) flushes the seek requests, exactly as the runtime fixtures do.
		rig.tree.advance(0.0)
		rig.tree.advance(0.0)
		for b in paths.size():
			clip.position_track_insert_key(paths[b][0], phase * duration, rig.sk.get_bone_pose_position(b))
			var q := rig.sk.get_bone_pose_rotation(b).normalized()
			assert(q.is_finite(), "Non-finite weapon carry")
			clip.rotation_track_insert_key(paths[b][1], phase * duration, q)
	var sources := []
	if not aiming:
		var info := data.role(weapon, mode, role)
		if info.has("clip"):
			sources.append(String(info.clip))
		for layer: Dictionary in info.get("layers", []):
			if not sources.has(String(layer.clip)):
				sources.append(String(layer.clip))
	else:
		collect_clips(data.aim_tree(weapon, "crouch" if crouched else "stand"), sources)
	var weapon_out: Dictionary = data.graph.get("weapon_layers", {}).get("weapon_out", {}).get("clips", {}).get(weapon, {})
	if weapon_out.has("clip") and not sources.has(String(weapon_out.clip)):
		sources.append(String(weapon_out.clip))
	var source_records := []
	var source_ids := []
	for name: String in sources:
		if rig.ap.has_animation(data.godot_anim(name)):
			var motion := rig.ap.get_animation(data.godot_anim(name))
			source_ids.append(motion.get_meta("native_asset_id", ""))
			source_records.append({"alias": name, "path": data.godot_anim(name), "native_asset_id": motion.get_meta("native_asset_id", ""), "agls_source_sha256": motion.get_meta("agls_source_sha256", ""), "variant_identity": motion.get_meta("variant_identity", "")})
	clip.set_meta("source_records", source_records)
	clip.set_meta("source_original_names", sources)
	clip.set_meta("source_native_asset_ids", source_ids)
	clip.set_meta("frontier_legacy_weapon", weapon)
	clip.set_meta("sample_rate", 60.0)
	clip.set_meta("derivation", "Frontier Legacy base plus existing Frontier carry/aim graph layers; apply live grip and aim IK when reused")
	clip.set_meta("variant_identity", (FileAccess.get_sha256(ROOT + "Frontier_Legacy.res") + "|" + weapon + "|" + suffix + "|" + JSON.stringify(source_ids)).sha256_text())
	clip.optimize(0.00001, 0.00001, 3)
	var name := "frontier_legacy_" + weapon + "_" + suffix
	assert(ResourceSaver.save(clip, ROOT + "weapons/" + name + ".res", ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_COMPRESS) == OK)
	library.add_animation(name, clip)
	rows.append({"name": name, "weapon": weapon, "duration": duration, "source_clips": sources, "source_native_ids": source_ids,
		"runtime_grip_and_aim_modifiers_required": true})

func collect_clips(value: Variant, out: Array) -> void:
	if value is Dictionary:
		for key in value:
			if key == "clip" and value[key] is String and not out.has(value[key]): out.append(value[key])
			else: collect_clips(value[key], out)
	elif value is Array:
		for item in value: collect_clips(item, out)
