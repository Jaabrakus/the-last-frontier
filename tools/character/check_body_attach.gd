extends SceneTree
## Checks the in-game body (scripts/player/character_body.gd) headless.
##
##   Godot --headless --path <Frontier> -s tools/character/check_body_attach.gd [-- parts=customizer|legacy|all|<glb>,<glb>...] [sex=0,1]
##
## parts=legacy (the default until the player switches to the customizer body) checks the
## player of scenes/main.tscn and actor_b_body.glb. parts=customizer attaches
## assets/character/body/body.glb and every hair style (CharacterBodyMesh.attach_parts, one
## shared Skin) on a fresh Actor_B and runs 2-4 for each `sex` blend-shape value (CPU
## skinning includes the blend shapes); the helper table is compared with body.json.
## parts=all runs both. parts=<glb>,<glb>... runs 2-4 for body.glb plus the listed parts
## (garments of a set, for example).
##
## 1. The player in scenes/main.tscn has a CharacterBodyMesh under its Skeleton3D.
##    It has 6 meshes (plus the customizer head and hair of PlayerAppearance) whose
##    skeleton paths resolve to that skeleton, binds from
##    null-add, no missing bones and no mannequin (show_mannequin defaults to false).
## 2. On a fresh Actor_B, the AnimationPlayer plays null-add. CPU linear-blend skinning
##    of every vertex with the live bone poses and the rebuilt Skin must reproduce the
##    modeled mesh. This proves that the bind computed from track data equals the pose
##    the mixer really produces.
## 3. Limb test on the gameplay clips. For vertices bound rigidly (weight 1) to a limb or
##    spine bone, the distance to the line from that joint to its child joint must be the
##    same in every clip as in the bind pose: the mesh stays around the limb. Rest-pose
##    binds fail this by tens of centimetres. Blended vertices (weight >= 0.95) are also
##    measured and only reported, because linear blending legitimately moves them.
##    The driven twist helpers count as their limb (they rotate about its axis).
## 4. Helper bones: every helper of CharacterBodyMesh.HELPERS (both sides) and the queue
##    pendulum is driven; the table and the skirt / queue / twist constants match the ones
##    build_body.py wrote into the sidecar json; at null-add every helper sits exactly at
##    its bind; build_body.py's preview twin of the driver gives the same helper globals as
##    CharacterBodyMesh._drive() for the reference poses in the json; the live SkeletonModifier3D
##    result (read in skeleton_updated) equals skinning_globals(); outside the skeleton
##    update the helpers keep their animated pose (game code never sees the driver); and
##    the body is the last SkeletonModifier3D of the skeleton, also after another modifier
##    is added later.
## All CPU skinning uses CharacterBodyMesh.skinning_globals() (animated pose + helpers).
## Prints CHECK PASSED / CHECK FAILED.

const CLIPS := ["actor_b-p-stealth-idle", "actor_b-p-walk-fw", "actor_b-p-run-fw",
		"actor_b-p-sprint-fw", "actor_b-p-crouch-walk-fw", "actor_b-p-rifle-idle-aim",
		"actor_b-p-pistol-aim-idle", "actor_b-p-bow-aim-idle",
		"actor_b-p-rifle-idle-aim-reload-mid--part", "actor_b-p-bow-reload--part"]
## [bone, joint, child joint] segments for the limb test: vertices of `bone` keep their
## distance to the joint -> child joint line.
const SEGMENTS := [["l_upper_leg", "l_upper_leg", "l_knee"], ["l_knee", "l_knee", "l_ankle"],
		["r_upper_leg", "r_upper_leg", "r_knee"], ["r_knee", "r_knee", "r_ankle"],
		["l_shoulder", "l_shoulder", "l_elbow"], ["l_elbow", "l_elbow", "l_wrist"],
		["r_shoulder", "r_shoulder", "r_elbow"], ["r_elbow", "r_elbow", "r_wrist"],
		["spinea", "spinea", "spineb"], ["spineb", "spineb", "spinec"], ["spinec", "spinec", "spined"],
		["neck", "neck", "heada"],
		["l_shoulder_twist_b", "l_shoulder", "l_elbow"], ["l_shoulder_twist_c", "l_shoulder", "l_elbow"],
		["l_shoulder_twist_d", "l_shoulder", "l_elbow"], ["r_shoulder_twist_b", "r_shoulder", "r_elbow"],
		["r_shoulder_twist_c", "r_shoulder", "r_elbow"], ["r_shoulder_twist_d", "r_shoulder", "r_elbow"],
		["l_forarm_twist_a", "l_elbow", "l_wrist"], ["l_forarm_twist_b", "l_elbow", "l_wrist"],
		["l_forarm_twist_c", "l_elbow", "l_wrist"], ["r_forarm_twist_a", "r_elbow", "r_wrist"],
		["r_forarm_twist_b", "r_elbow", "r_wrist"], ["r_forarm_twist_c", "r_elbow", "r_wrist"]]
const SIDECAR := "res://assets/character/actor_b_body.json"
const BODY_SIDECAR := "res://assets/character/body/body.json"
const TOL_BIND_POSE := 2e-4    # m, CPU skinning at null-add vs the modeled mesh.
const TOL_LIMB := 0.002        # m, change of a rigid limb vertex's distance to its bone line.
const RIGID := 0.999

var failures := PackedStringArray()
var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var mode: String = args.get("parts", "legacy")
	if mode in ["legacy", "all"]:
		await _check_game()
		await _check_skinning({}, 0.0, SIDECAR)
	if mode in ["customizer", "all"]:
		var parts := {"body": "res://assets/character/body/body.glb"}
		for f in DirAccess.get_files_at("res://assets/character/hair"):
			if f.ends_with(".glb"):
				parts[f.get_basename()] = "res://assets/character/hair/" + f
		for sx in String(args.get("sex", "0,1")).split(","):
			await _check_skinning(parts, float(sx), BODY_SIDECAR)
	elif not mode in ["legacy"]:
		# parts=<glb>,<glb>...: the customizer body plus the listed parts (garments, hair)
		var parts := {"body": "res://assets/character/body/body.glb"}
		for p in mode.split(","):
			parts[p.get_file().get_basename()] = p
		for sx in String(args.get("sex", "0,1")).split(","):
			await _check_skinning(parts, float(sx), BODY_SIDECAR)
	print("CHECK PASSED" if failures.is_empty() else "CHECK FAILED")
	for f in failures:
		printerr("FAIL: ", f)
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures.append(msg)


func _check_game() -> void:
	print("in game (scenes/main.tscn)")
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player := current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(player != null, "player exists")
	if player == null:
		return
	var bodies := player.skeleton.find_children("*", "CharacterBodyMesh", false, false)
	_expect(bodies.size() == 1, "one CharacterBodyMesh under the player skeleton")
	if bodies.is_empty():
		return
	var body := bodies[0] as CharacterBodyMesh
	print("  report: ", body.report)
	_expect(body.transform.is_equal_approx(Transform3D.IDENTITY), "body node has an identity transform")
	# the legacy glb's 6 meshes (hidden since 2026-09-28), plus the customizer body (Body, Face), a hair style,
	# the pubic hair (when nothing covers it) and the garments when PlayerAppearance is on (player.use_appearance)
	var garment_meshes := 0
	for tag in body.parts:
		if String(tag).begins_with("outfit:"):
			garment_meshes += (body.parts[tag] as Array).size()
	var want_meshes := 6 + (2 + body.part_meshes("hair").size() + body.part_meshes("body_hair").size() + garment_meshes
			if player.appearance else 0)
	_expect(body.meshes.size() == want_meshes, "%d meshes (%d)" % [want_meshes, body.meshes.size()])
	var resolved := 0
	for mi in body.meshes:
		if mi.get_node_or_null(mi.skeleton) == player.skeleton and mi.skin != null:
			resolved += 1
	_expect(resolved == body.meshes.size(), "every mesh is skinned to the player skeleton (%d)" % resolved)
	_expect(body.report.bind_source == "null-add", "binds computed from null-add")
	_expect(body.report.missing.is_empty(), "no missing bones %s" % str(body.report.missing))
	_expect(body.report.max_bind_diff < 1e-4, "computed binds match the glb binds (max %s)" % BindRest.sci(body.report.max_bind_diff))
	var mannequins := player.find_children("*", "BoneMannequin", true, false)
	_expect(mannequins.is_empty(), "no mannequin with the body")
	var want := CharacterBodyMesh.HELPERS.size() * 2 + 1
	_expect(body.report.helpers == want, "all %d helper bones are driven (%d)" % [want, body.report.helpers])
	_expect(_last_modifier(player.skeleton) == body, "the body is the skeleton's last SkeletonModifier3D")
	# A modifier added later (an aim stabiliser, IK) must still run before the helpers.
	var later := SkeletonModifier3D.new()
	later.name = "LaterModifier"
	player.skeleton.add_child(later)
	await process_frame
	await process_frame
	_expect(_last_modifier(player.skeleton) == body, "still last after another modifier is added")
	later.queue_free()
	await process_frame


func _last_modifier(sk: Skeleton3D) -> Node:
	for i in range(sk.get_child_count() - 1, -1, -1):
		if sk.get_child(i) is SkeletonModifier3D:
			return sk.get_child(i)
	return null


func _check_skinning(parts: Dictionary, sex: float, sidecar: String) -> void:
	print("skinning ", "legacy body" if parts.is_empty() else "customizer parts %s, sex %.1f" % [parts.keys(), sex])
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var body := CharacterBodyMesh.attach(sk, ap) if parts.is_empty() else CharacterBodyMesh.attach_parts(sk, ap, parts)
	_expect(body != null, "attach() on a fresh Actor_B")
	if body == null:
		return
	if not parts.is_empty():
		_expect(body.report.skins == 1, "all %d parts share one Skin (%d)" % [parts.size(), body.report.skins])
		_expect(body.report.missing.is_empty() and body.report.bind_source == "null-add",
				"binds from null-add, no missing bones")
		body.set_blend_shape("sex", sex)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.deterministic = true

	# Gather vertices once: [position (blend shapes applied), bones (skeleton indices), weights, binds].
	var verts: Array = []
	for mi in body.meshes:
		var mesh := mi.mesh as ArrayMesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var vtx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs := mesh.surface_get_blend_shape_arrays(s)
			for b in bs.size():
				var w := mi.get_blend_shape_value(b)
				if absf(w) < 1e-6:
					continue
				var sv: PackedVector3Array = bs[b][Mesh.ARRAY_VERTEX]
				for v in vtx.size():
					vtx[v] += (sv[v] - arr[Mesh.ARRAY_VERTEX][v]) * w
			var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nb := bi.size() / maxi(vtx.size(), 1)
			for v in vtx.size():
				var bones := PackedInt32Array()
				var ws := PackedFloat32Array()
				var binds: Array[Transform3D] = []
				for k in nb:
					var w := bw[v * nb + k]
					if w > 0.0:
						bones.append(mi.skin.get_bind_bone(bi[v * nb + k]))
						binds.append(mi.skin.get_bind_pose(bi[v * nb + k]))
						ws.append(w)
				verts.append([vtx[v], bones, ws, binds])
	print("  vertices: ", verts.size())

	# 2. null-add through the mixer.
	_pose(ap, "actor_b/null-add", 0.0)
	var g := body.skinning_globals()
	var err := 0.0
	for vd: Array in verts:
		err = maxf(err, _skin(g, vd).distance_to(vd[0]))
	_expect(err < TOL_BIND_POSE, "skinning at the mixer's null-add pose reproduces the mesh (max %s m)" % BindRest.sci(err))
	var herr := 0.0
	for d: Dictionary in body._drivers:
		herr = maxf(herr, CharacterBodyMesh.xform_diff(g[d.bone], d.bind))
	_expect(herr < 1e-5, "at null-add every driven helper is at its bind (max %s)" % BindRest.sci(herr))
	await _check_helpers(sk, ap, body, sidecar)

	# 3. Limb test.
	var seg_bones := {}
	for s: Array in SEGMENTS:
		seg_bones[sk.find_bone(s[0])] = [sk.find_bone(s[1]), sk.find_bone(s[2])]
	_pose(ap, "actor_b/null-add", 0.0)
	var bind_dist := []
	for vd: Array in verts:
		bind_dist.append(_limb_dist(sk, vd, seg_bones))
	for clip: String in CLIPS:
		if not ap.has_animation("actor_b/" + clip):
			_expect(false, "clip %s exists" % clip)
			continue
		var length := ap.get_animation("actor_b/" + clip).length
		var worst := 0.0
		var worst_bone := ""
		var blended := 0.0
		var n := 0
		for f in [0.0, 0.37, 0.71]:
			_pose(ap, "actor_b/" + clip, f * length)
			var gp := body.skinning_globals()
			for i in verts.size():
				var d0: float = bind_dist[i]
				if d0 < 0.0:
					continue
				var vd: Array = verts[i]
				var p := _skin(gp, vd)
				var seg: Array = seg_bones[vd[1][_dominant(vd)]]
				var d := _line_dist(p, sk.get_bone_global_pose(seg[0]).origin, sk.get_bone_global_pose(seg[1]).origin)
				if (vd[2] as PackedFloat32Array)[_dominant(vd)] < RIGID:
					blended = maxf(blended, absf(d - d0))
					continue
				n += 1
				if absf(d - d0) > worst:
					worst = absf(d - d0)
					worst_bone = sk.get_bone_name(seg[0])
		_expect(n > 0 and worst < TOL_LIMB, "%s: rigid limb vertices keep their distance to the bone line (max change %.4f m at %s, %d samples; blended >= 0.95: %.4f m)" % [clip, worst, worst_bone, n, blended])
	inst.queue_free()


func _pose(ap: AnimationPlayer, anim: String, t: float) -> void:
	ap.play(anim)
	ap.seek(t, true)
	ap.advance(0.0)


## Linear blend skinning of a vertex with the bone globals `g` (skinning_globals()).
func _skin(g: Array, vd: Array) -> Vector3:
	var p := Vector3.ZERO
	var bones: PackedInt32Array = vd[1]
	var ws: PackedFloat32Array = vd[2]
	var binds: Array = vd[3]
	for k in bones.size():
		p += ((g[bones[k]] as Transform3D) * ((binds[k] as Transform3D) * (vd[0] as Vector3))) * ws[k]
	return p


## 4. The helper driver: sidecar table, live modifier vs CPU, no leak outside the update.
func _check_helpers(sk: Skeleton3D, ap: AnimationPlayer, body: CharacterBodyMesh, sidecar: String) -> void:
	var info = JSON.parse_string(FileAccess.get_file_as_string(sidecar))
	var h: Dictionary = info.get("helpers", {}) if info is Dictionary else {}
	var same := h.has("table") and (h.table as Array).size() == CharacterBodyMesh.HELPERS.size()
	if same:
		var kinds := {"upper_arm": CharacterBodyMesh.Kind.UPPER_ARM, "forearm": CharacterBodyMesh.Kind.FOREARM,
				"skirt": CharacterBodyMesh.Kind.SKIRT}
		for i in CharacterBodyMesh.HELPERS.size():
			var mine: Array = CharacterBodyMesh.HELPERS[i]
			var theirs: Array = h.table[i]
			same = same and mine[0] == theirs[0] and kinds.get(theirs[1], -1) == mine[1] \
					and is_equal_approx(float(mine[2]), float(theirs[2])) and is_equal_approx(float(mine[3]), float(theirs[3]))
		var sk_j: Dictionary = h.get("skirt", {})
		var hems: Array = sk_j.get("hems_godot", [])
		same = same and hems.size() == CharacterBodyMesh.SKIRT_HEMS.size()
		for i in mini(hems.size(), CharacterBodyMesh.SKIRT_HEMS.size()):
			var hj: Array = hems[i]
			same = same and Vector3(hj[0], hj[1], hj[2]).is_equal_approx(CharacterBodyMesh.SKIRT_HEMS[i])
		var fg: Array = sk_j.get("front_gain", [0, 0, 0])
		var ft: Array = sk_j.get("floor_tilt_deg", [0, 0])
		var q: Dictionary = h.get("queue", {})
		same = same and Vector3(fg[0], fg[1], fg[2]).is_equal_approx(CharacterBodyMesh.SKIRT_FRONT_GAIN) \
				and Vector2(ft[0], ft[1]).is_equal_approx(CharacterBodyMesh.SKIRT_FLOOR_TILT_DEG) \
				and is_equal_approx(float(sk_j.get("gravity_max_deg", 0)), CharacterBodyMesh.SKIRT_GRAVITY_MAX_DEG) \
				and is_equal_approx(float(sk_j.get("rear_clear_deg", 0)), CharacterBodyMesh.SKIRT_REAR_CLEAR_DEG) \
				and is_equal_approx(float(sk_j.get("rear_abd", 0)), CharacterBodyMesh.SKIRT_REAR_ABD) \
				and is_equal_approx(float(sk_j.get("side_clear_deg", 0)), CharacterBodyMesh.SKIRT_SIDE_CLEAR_DEG) \
				and is_equal_approx(float(sk_j.get("side_gravity", 0)), CharacterBodyMesh.SKIRT_SIDE_GRAVITY) \
				and is_equal_approx(float(sk_j.get("floor_margin", 0)), CharacterBodyMesh.SKIRT_FLOOR_MARGIN) \
				and is_equal_approx(float(sk_j.get("floor_max_deg", 0)), CharacterBodyMesh.SKIRT_FLOOR_MAX_DEG) \
				and str(sk_j.get("feet", [])) == str(CharacterBodyMesh.SKIRT_FEET) \
				and is_equal_approx(float(h.get("upper_arm_twist_center_deg", 0)), CharacterBodyMesh.UPPER_ARM_TWIST_CENTER_DEG) \
				and is_equal_approx(float(h.get("forearm_twist_center_deg", 0)), CharacterBodyMesh.FOREARM_TWIST_CENTER_DEG) \
				and q.get("bone", "") == CharacterBodyMesh.QUEUE_HELPER \
				and is_equal_approx(float(q.get("gravity", 0)), CharacterBodyMesh.QUEUE_GRAVITY) \
				and is_equal_approx(float(q.get("side_max_deg", 0)), CharacterBodyMesh.QUEUE_SIDE_MAX_DEG)
		var root_j: Array = q.get("root_godot", [0, 0, 0])
		same = same and Vector3(root_j[0], root_j[1], root_j[2]).is_equal_approx(CharacterBodyMesh.QUEUE_ROOT)
		# body v4's genital pendulum (older sidecars have none)
		var gj: Dictionary = h.get("genital", {})
		if not gj.is_empty():
			var gr: Array = gj.get("root_godot", [0, 0, 0])
			var gt: Array = gj.get("tip_godot", [0, 0, 0])
			same = same and gj.get("bone", "") == CharacterBodyMesh.GENITAL_HELPER \
					and Vector3(gr[0], gr[1], gr[2]).is_equal_approx(CharacterBodyMesh.GENITAL_ROOT) \
					and Vector3(gt[0], gt[1], gt[2]).is_equal_approx(CharacterBodyMesh.GENITAL_TIP)
	_expect(same, "helper table, skirt / queue / twist constants match the sidecar json %s" % sidecar.get_file())
	# The preview twin in build_body.py (drive_helpers) against the game's driver: the same
	# input bone globals must give the same helper globals.
	var refs: Array = info.get("driver_reference", []) if info is Dictionary else []
	var worst := 0.0
	var worst_at := ""
	for r: Dictionary in refs:
		var g := []
		g.resize(sk.get_bone_count())
		for bn: String in r.inputs:
			g[sk.find_bone(bn)] = _xf12(r.inputs[bn])
		var res := body._drive(g, Vector3.DOWN)
		for i in (res[0] as PackedInt32Array).size():
			var bn := sk.get_bone_name(res[0][i])
			if not (r.helpers as Dictionary).has(bn):
				worst = INF
				continue
			var e := CharacterBodyMesh.xform_diff(res[1][i], _xf12(r.helpers[bn]))
			if e > worst:
				worst = e
				worst_at = "%s frame %d %s" % [r.clip, int(r.frame), bn]
	_expect(refs.size() >= 6 and worst < 1e-3, "build_body.py's preview driver matches the game's on %d reference poses (max %s at %s)" % [refs.size(), BindRest.sci(worst), worst_at])
	var seen := {}
	var grab := func() -> void:
		for d: Dictionary in body._drivers:
			seen[d.bone] = sk.get_bone_global_pose(d.bone)
	sk.skeleton_updated.connect(grab)
	var live := 0.0
	var leak := 0.0
	for c in ["actor_b-p-bow-reload--part", "actor_b-p-rifle-idle-aim", "actor_b-p-crouch-walk-fw"]:
		_pose(ap, "actor_b/" + c, 0.4 * ap.get_animation("actor_b/" + c).length)
		var g := body.skinning_globals()
		var anim := []
		for d: Dictionary in body._drivers:
			anim.append(sk.get_bone_global_pose(d.bone))
		seen.clear()
		await process_frame
		await process_frame
		for i in body._drivers.size():
			var d: Dictionary = body._drivers[i]
			if seen.has(d.bone):
				live = maxf(live, CharacterBodyMesh.xform_diff(seen[d.bone], g[d.bone]))
			else:
				live = INF
			leak = maxf(leak, CharacterBodyMesh.xform_diff(sk.get_bone_global_pose(d.bone), anim[i]))
	sk.skeleton_updated.disconnect(grab)
	_expect(live < 1e-4, "the live modifier drives the helpers like skinning_globals() (max %s)" % BindRest.sci(live))
	_expect(leak < 1e-6, "outside the skeleton update the helpers keep their animated pose (max %s)" % BindRest.sci(leak))


## Transform3D from 12 floats: basis x, y, z columns, then origin (the sidecar format).
static func _xf12(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])),
			Vector3(a[9], a[10], a[11]))


func _dominant(vd: Array) -> int:
	var ws: PackedFloat32Array = vd[2]
	var best := 0
	for k in ws.size():
		if ws[k] > ws[best]:
			best = k
	return best


## Distance of a bind-pose vertex to its dominant bone's segment line, or -1 when the
## vertex is not a >= 0.95 limb vertex. Reads the skeleton's current pose (null-add).
func _limb_dist(sk: Skeleton3D, vd: Array, seg_bones: Dictionary) -> float:
	var k := _dominant(vd)
	var ws: PackedFloat32Array = vd[2]
	var bone: int = vd[1][k]
	if ws[k] < 0.95 or not seg_bones.has(bone):
		return -1.0
	var seg: Array = seg_bones[bone]
	return _line_dist(vd[0], sk.get_bone_global_pose(seg[0]).origin, sk.get_bone_global_pose(seg[1]).origin)



func _line_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var d := (b - a).normalized()
	var r := p - a
	return (r - d * r.dot(d)).length()
