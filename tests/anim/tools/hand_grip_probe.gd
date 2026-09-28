extends SceneTree
## Diagnosis probe for the musket left-hand placement (CROUCH_HANDS, part ch-harness-hands).
## Prints the facts graph_analysis/crouch_hands/hands_diagnosis.md is built on:
##  1. the IK / modifier classes this Godot build really has (ClassDB) and their properties;
##  2. the left arm chain (l_palm up to the root) and where the stabilizer's drivers sit;
##  3. the reference grips (HandGripMeter.calibrate): palm normal, the source forestock line;
##  4. the palm's soft tissue in front of l_palm along the palm normal, on the skinned body;
##  5. the Brown Bess forestock derived from the model's meshes;
##  6. in the level: the Skeleton3D's children in order (modifiers, BoneAttachment3Ds), and when
##     the weapon node's transform follows the prop bone relative to the modifier pass (a probe
##     modifier placed where a left-hand IK would go: after AimStabilizer, before the body's).
##   Godot --headless --path . -s tests/anim/tools/hand_grip_probe.gd -- --no-capture

const Meter := preload("res://tests/anim/lib/hand_grip_meter.gd")
const ProbeMod := preload("res://tests/anim/tools/hand_grip_probe_modifier.gd")


func _initialize() -> void:
	await process_frame
	await process_frame
	_classes()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var p: Node = current_scene.get_node_or_null("Player")
	if p == null:
		print("PROBE: no player")
		quit(1)
		return
	p.ignore_mouse_capture = true
	for i in 240:
		await physics_frame
	var sk: Skeleton3D = p.skeleton
	_chain(sk)
	var m = Meter.new(p)
	var ok: bool = m.calibrate(self)
	print("\n== 3. reference grips (calibrate ok=%s)" % ok)
	var ax := {"+X": Vector3.RIGHT, "-X": Vector3.LEFT, "+Y": Vector3.UP, "-Y": Vector3.DOWN, "+Z": Vector3.BACK, "-Z": Vector3.FORWARD}
	var best := ""
	var bd := 999.0
	for k in ax:
		var d := rad_to_deg(m.palm_n_local.angle_to(ax[k]))
		if d < bd:
			bd = d
			best = k
	print("palm normal (l_palm local) %s: %.0f deg from l_palm %s" % [m.palm_n_local.snapped(Vector3.ONE * 0.001), bd, best])
	print("source forestock (r_hand_prop_attachment frame): centre line x %.3f y %.3f, radius %.3f, z %.3f .. %.3f" % [
			m.src_xy.x, m.src_xy.y, m.src_r, m.src_z0, m.src_z1])
	for r in m.refs:
		print("  ref %-11s palm point %s, wrap centre %s" % [r.name, (r.palm as Vector3).snapped(Vector3.ONE * 0.001), (r.centre as Vector2).snapped(Vector2.ONE * 0.001)])
	_skin(p, sk, m)
	print("\n== 5. Brown Bess forestock (model meshes)")
	var musket: Node3D = p.weapons["musket"].model
	print("build_stock ok=%s: %s" % [m.build_stock(musket), m.stock_info])
	for z in [-0.2, -0.3, -0.4, -0.6, -0.8, -1.0, -1.15]:
		print("  z %.2f: bottom %.3f top %.3f half width %.3f" % [z, Meter._at(m.stock.bot, z), Meter._at(m.stock.top, z), Meter._at(m.stock.half, z)])
	print("  LeftGrip marker: %s" % ("present" if musket.find_child("LeftGrip", true, false) else "absent"))
	await _order(p, sk)
	quit(0)


func _classes() -> void:
	print("== 1. Godot %s: SkeletonModifier3D classes" % Engine.get_version_info().string)
	var mods := []
	for c in ClassDB.get_class_list():
		if ClassDB.is_parent_class(c, "SkeletonModifier3D"):
			mods.append(c)
	mods.sort()
	for c in mods:
		var props := []
		for pr in ClassDB.class_get_property_list(c, true):
			if pr.usage & PROPERTY_USAGE_EDITOR or pr.usage & PROPERTY_USAGE_STORAGE:
				props.append(pr.name)
		print("  %-32s <- %-22s %s" % [c, ClassDB.get_parent_class(c), ", ".join(props)])
	# TwoBoneIK3D settings are indexed properties; instance one to list them.
	for c in ["TwoBoneIK3D", "FABRIK3D", "CCDIK3D", "JacobianIK3D"]:
		if ClassDB.class_exists(c):
			var o: Object = ClassDB.instantiate(c)
			if o.has_method("set_setting_count"):
				o.call("set_setting_count", 1)
			var names := []
			for pr in o.get_property_list():
				var n := String(pr.name)
				if n.begins_with("settings/0/"):
					names.append(n.trim_prefix("settings/0/"))
			print("  %s settings/0/*: %s" % [c, ", ".join(names)])
			if o is Node:
				(o as Node).free()


func _chain(sk: Skeleton3D) -> void:
	print("\n== 2. left arm chain")
	var b := sk.find_bone("l_hand_prop_attachment")
	var names := []
	while b >= 0:
		names.append(sk.get_bone_name(b))
		b = sk.get_bone_parent(b)
	print("  " + " <- ".join(names))
	for n in ["l_shoulder", "l_elbow", "l_wrist", "l_palm"]:
		var i := sk.find_bone(n)
		var par := sk.get_bone_parent(i)
		print("  %-12s parent %-22s rest length from parent %.3f" % [n, sk.get_bone_name(par) if par >= 0 else "-", sk.get_bone_rest(i).origin.length()])
	var r := sk.find_bone("r_hand_prop_attachment")
	print("  r_hand_prop_attachment parent %s" % sk.get_bone_name(sk.get_bone_parent(r)))


## Palm tissue in front of l_palm along the palm normal: CPU-skinned body vertices mostly
## weighted to the left palm / metacarpals, within 1.2 cm of the normal ray through C.
func _skin(p: Node, sk: Skeleton3D, m) -> void:
	print("\n== 4. palm soft tissue on the skinned body")
	var hand_bones := {}
	for n in ["l_palm", "l_index_metacarpal", "l_middle_metacarpal", "l_ring_metacarpal", "l_pinkya", "l_thumba"]:
		hand_bones[sk.find_bone(n)] = true
	# Bind / rest pose (open hand: the curled fingers of an animated grip would sit on the line).
	var palm := sk.get_bone_global_rest(sk.find_bone("l_palm"))
	var inv := palm.affine_inverse()
	var front := -INF
	var back := INF
	var n_front := 0
	var count := 0
	var ts := []
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		var skin := mi.skin
		var bind_bone := PackedInt32Array()
		for i in skin.get_bind_count():
			var bb := skin.get_bind_bone(i)
			if bb < 0:
				bb = sk.find_bone(skin.get_bind_name(i))
			bind_bone.append(bb)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or verts.is_empty():
				continue
			var per: int = bones.size() / verts.size()
			for vi in verts.size():
				var top_b := -1
				var top_w := 0.0
				var pos := Vector3.ZERO
				for k in per:
					var w: float = weights[vi * per + k]
					if w <= 0.0:
						continue
					var bi: int = bind_bone[bones[vi * per + k]]
					if w > top_w:
						top_w = w
						top_b = bi
					pos += (sk.get_bone_global_rest(bi) * skin.get_bind_pose(bones[vi * per + k]) * verts[vi]) * w
				if not hand_bones.has(top_b):
					continue
				count += 1
				var q := inv * pos
				var nl: Vector3 = m.palm_n_local
				var t := q.dot(nl)
				var lat := (q - nl * t).length()
				if lat < 0.012:
					ts.append(t)
					if t > front:
						front = t
					if t < back:
						back = t
					n_front += 1
	ts.sort()
	print("  along the palm normal (m, sorted): ", ts.map(func(x): return snappedf(x, 0.001)))
	print("  %d hand vertices, %d within 1.2 cm of the palm-normal line through l_palm: palm surface %.4f m in front of l_palm, back of the hand %.4f m behind" % [
			count, n_front, front, -back])


func _order(p: Node, sk: Skeleton3D) -> void:
	print("\n== 6. Skeleton3D children (modifier order) and weapon-node timing")
	var probe := ProbeMod.new()
	probe.name = "HandGripProbe"
	probe.player = p
	var body_i := -1
	for i in sk.get_child_count():
		if sk.get_child(i).get_class() == "SkeletonModifier3D" and sk.get_child(i).get_script() and String(sk.get_child(i).get_script().resource_path).ends_with("character_body.gd"):
			body_i = i
	var mbt := ModifierBoneTarget3D.new()
	mbt.name = "GripBoneTarget"
	mbt.bone_name = "r_hand_prop_attachment"
	sk.add_child(mbt)
	probe.bone_target = mbt
	sk.add_child(probe)
	if body_i >= 0:
		sk.move_child(mbt, body_i)
		sk.move_child(probe, body_i + 1)
	await process_frame
	await process_frame
	for i in sk.get_child_count():
		var c := sk.get_child(i)
		var scr: Script = c.get_script()
		var extra := ""
		if c is BoneAttachment3D:
			extra = " bone=%s use_external=%s" % [(c as BoneAttachment3D).bone_name, (c as BoneAttachment3D).use_external_skeleton]
		if c is SkeletonModifier3D:
			extra = " active=%s influence=%.2f" % [(c as SkeletonModifier3D).active, (c as SkeletonModifier3D).influence]
		print("  %2d %-26s %-20s %s%s" % [i, c.name, c.get_class(), scr.resource_path.get_file() if scr else "", extra])
	print("  skeleton modifier_callback_mode_process=%d" % sk.modifier_callback_mode_process)
	# Weapon node lag inside the modifier pass and in skeleton_updated, standing and running.
	var lag_upd := []
	var cb := func():
		var b := sk.find_bone("r_hand_prop_attachment")
		var cur: Transform3D = sk.global_transform * sk.get_bone_global_pose(b) * (p.musket_offset as Transform3D)
		lag_upd.append(p.weapon.model.global_transform.origin.distance_to(cur.origin))
	sk.skeleton_updated.connect(cb)
	for phase in ["idle", "run"]:
		probe.samples.clear()
		lag_upd.clear()
		if phase == "run":
			Input.action_press("move_forward")
		for i in 90:
			await physics_frame
		Input.action_release("move_forward")
		var inmod := []
		for s in probe.samples:
			inmod.append(s[0])
		var tg := []
		for s in probe.samples:
			tg.append(s[2])
		print("  %s: weapon node vs the current prop bone: inside the modifier pass (probe at the IK slot) max %.4f m mean %.4f m over %d calls; in skeleton_updated max %.4f m; a ModifierBoneTarget3D(r_hand_prop_attachment) placed before the probe: max %.5f m" % [
				phase, _max(inmod), _mean(inmod), inmod.size(), _max(lag_upd), _max(tg)])
	sk.skeleton_updated.disconnect(cb)
	probe.queue_free()
	mbt.queue_free()


static func _max(a: Array) -> float:
	var m := 0.0
	for x in a:
		m = maxf(m, float(x))
	return m


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()
