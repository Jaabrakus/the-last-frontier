extends SceneTree
## Exports what tools/anim/grip_fit.py needs to fit the long gun into the LEFT fist (push n01c; user 2026-09-26: "for
## the one hand hold the left hand doesn grip it properly"): for each candidate finger pose (a source clip's hand, the
## right hand's mirrored onto the left as LeftArmPose mirrors), the left hand's skin vertices in the l_palm frame
## (skinned on the CPU with the body's Skin, GripGauge's selection), and the gun meshes' triangles round the grip.
##   Godot --headless --path . -s tests/torch/tools/grip_fit_export.gd -- out=<file.json> [gun=musket|over_under]
##       [z0=-0.56] [z1=-0.24]

const Gauge := preload("res://tests/torch/lib/grip_gauge.gd")
## [name, clip, side the fingers come from ("l" as they are, "r" mirrored), time (s)]
const CANDIDATES := [
	["flashlight", "actor_b-fist-ambi-flashlight--hand", "l", 0.0],
	["rifle_fore_aim", "actor_b-p-rifle-idle-aim--hands", "l", 0.0],
	["rifle_fore_crouch", "actor_b-p-rifle-aim-crouch-idle--hands", "l", 0.0],
	["rifle_fore_carry", "actor_b-p-rifle-run-arms", "l", 0.0],
	["rifle_fore_crouch_carry", "actor_b-p-rifle-crouch-idle--hands", "l", 0.0],
	["rifle_wrist_aim", "actor_b-p-rifle-idle-aim--hands", "r", 0.0],
	["rifle_wrist_carry", "actor_b-p-rifle-run-arms", "r", 0.0],
	["pistol", "actor_b-pistol-r--hand", "r", 0.0],
	["knife", "atk-actor_b-knife-v-thug-hit1-intro", "r", 0.0],
	["one_hand_hip", "actor_b-rifle-idle-no-aim--part", "r", 0.0],
	["one_hand_low", "actor_b-p-rifle-cover-low-left-fw--arms", "r", 0.0],
]
const HAND_KEYS := ["palm", "index", "middle", "ring", "pinky", "thumb"]


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var out: String = args.get("out", "user://grip_fit.json")
	# the hand as the game draws it: the player's body in the level (the customizer's hands, PlayerAppearance), its
	# skin data; the bones posed on a scratch Actor_B (the same rig, bone for bone)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: FrontierPlayer = current_scene.get_node("Player")
	for i in 30:
		await physics_frame
	var g = Gauge.new()
	g.sk = player.skeleton
	if not g._hand(null):
		print("GRIP_FIT_EXPORT: ", g.info)
		quit(1)
		return
	var inst: Node3D = load("res://characters/Actor_B.tscn").instantiate()
	root.add_child(inst)
	var sk: Skeleton3D = inst.get_node("Skeleton3D")
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	for i in sk.get_bone_count():
		if sk.get_bone_name(i) != player.skeleton.get_bone_name(i):
			print("GRIP_FIT_EXPORT: the rigs differ at bone ", i)
			quit(1)
			return
	print("hand: %d vertices from %s" % [g._n, g.info])
	# the hand bones LeftArmPose poses (palm, metacarpals, fingers, thumb) and the prop
	var hand_bones: Array[int] = []
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.begins_with("l_") and HAND_KEYS.any(func(k: String) -> bool: return n.substr(2).begins_with(k)):
			hand_bones.append(i)
	var palm := sk.find_bone("l_palm")
	var wrist := sk.find_bone("l_wrist")
	var elbow := sk.find_bone("l_elbow")
	var prop := sk.find_bone("l_hand_prop_attachment")
	var res := {"candidates": [], "gun": {}}
	for c: Array in CANDIDATES:
		var clip := "actor_b/" + String(c[0 + 1])
		if not ap.has_animation(clip):
			print("missing ", clip)
			continue
		var anim := ap.get_animation(clip)
		for b in hand_bones:
			sk.reset_bone_pose(b)
			var n := sk.get_bone_name(b)
			var src := n if String(c[2]) == "l" else "r_" + n.substr(2)
			var ti := _find(anim, src)
			if ti >= 0:
				sk.set_bone_pose_rotation(b, anim.rotation_track_interpolate(ti, float(c[3])))
			# (positions: the rest's, as LeftArmPose leaves them)
		var pg := sk.get_bone_global_pose(palm)
		var inv := pg.affine_inverse()
		var verts := []
		for v in g._n:
			var p := Vector3.ZERO
			for k in g._per:
				var w: float = g._vw[v * g._per + k]
				if w <= 0.0:
					continue
				p += (sk.get_bone_global_pose(g._vb[v * g._per + k]) * g._vl[v * g._per + k]) * w
			var q := inv * p
			verts.append([snappedf(q.x, 1e-5), snappedf(q.y, 1e-5), snappedf(q.z, 1e-5), g._region[v], g._tip[v]])
		# the forearm (the wrist -> elbow line of the rest arm, in the palm frame) and the wrist joint
		var wg := sk.get_bone_global_pose(wrist)
		var eg := sk.get_bone_global_pose(elbow)
		var fore := inv.basis * (eg.origin - wg.origin).normalized()
		var wr := inv * wg.origin
		var joints := {}
		for b in hand_bones:
			var o := inv * sk.get_bone_global_pose(b).origin
			joints[sk.get_bone_name(b)] = [o.x, o.y, o.z]
		var pp := inv * sk.get_bone_global_pose(prop)
		res.candidates.append({"name": c[0], "clip": c[1], "side": c[2], "verts": verts, "forearm": [fore.x, fore.y, fore.z],
				"wrist": [wr.x, wr.y, wr.z], "joints": joints, "prop": _xf(pp)})
		print("candidate %s: %d vertices" % [c[0], verts.size()])
	# the gun
	var gun: String = args.get("gun", "musket")
	var model: Node3D = OverUnderModel.build() if gun == "over_under" else WeaponModels.build(gun)
	root.add_child(model)
	var z0 := float(args.get("z0", "-0.56"))
	var z1 := float(args.get("z1", "-0.24"))
	var tris := []
	var parts := []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or String(mi.name).to_lower().contains("ramrod"):
			continue
		var xf := Gauge._local_to(model, mi)
		var pi := parts.size()
		parts.append(String(mi.name))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var n: int = (idx.size() if idx != null and idx.size() > 0 else vs.size()) / 3
			for t in n:
				var tri := []
				var zmin := INF
				var zmax := -INF
				for k in 3:
					var vi: int = idx[t * 3 + k] if idx != null and idx.size() > 0 else t * 3 + k
					var q := xf * vs[vi]
					tri.append_array([snappedf(q.x, 1e-5), snappedf(q.y, 1e-5), snappedf(q.z, 1e-5)])
					zmin = minf(zmin, q.z)
					zmax = maxf(zmax, q.z)
				if zmax < z0 or zmin > z1:
					continue
				tri.append(pi)
				tris.append(tri)
	res.gun = {"name": gun, "parts": parts, "tris": tris, "z0": z0, "z1": z1}
	print("gun %s: %d triangles in z %.2f .. %.2f" % [gun, tris.size(), z0, z1])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(res))
	f.close()
	print("GRIP_FIT_EXPORT wrote ", out)
	quit()


static func _find(anim: Animation, bone: String, type := Animation.TYPE_ROTATION_3D) -> int:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == type and String(anim.track_get_path(t)).get_slice(":", 1) == bone:
			return t
	return -1


static func _xf(t: Transform3D) -> Array:
	var b := t.basis.orthonormalized()
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]
