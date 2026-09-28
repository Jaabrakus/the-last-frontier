extends SceneTree
## Checks the Actor_A -> Actor_B retarget library `actor_b_from_a` in the game project, by
## playing every clip on the game's own Actor_B rig and comparing with the Actor_A source.
##
##   Godot --headless --path ~/Downloads/Frontier -s tests/retarget/test_actor_b_from_a.gd
##
## Library   res://animations_extra/Actor_B_from_A.res   (tools/retarget/build_library.gd)
## Manifest  res://animations_extra/Actor_B_from_A.json  (tools/retarget/retarget.py --manifest)
## Reference res://tests/retarget/data/actor_b_from_a_ref.json (retarget.py --test-ref): the
##           Actor_A source paths (scaled like the retarget), contact frames, prop frames, hinge
##           angles, wrist swing and local rotation steps, seams. Angles in tenths of a degree.
##
## Per clip:
##  1. provenance: native_asset_id (== manifest), original_name, retarget stamp (source clip /
##     actor / source_native_asset_id / library)
##  2. every track is "Skeleton3D:<bone>" and the bone exists on the game skeleton
##  3. playback == the tool's forward kinematics (3 frames x 13 joints, 2 mm)
##  4. joint path similarity to the source: r2 >= 0.85 and speed-weighted velocity cosine
##     >= 0.88 over the pelvis-relative joint paths (skipped for near-static clips, RMS < 1 cm;
##     a prop bone the source does not key is left out)
##  5. contact slide: heels / balls the source keeps planted slide at most 0.05 m/s more than
##     the source (hands / knees on the floor: 0.10 m/s)
##  6. hand / prop placement: keyed prop bones keep the source's world rotation in the library's
##     weapon frame (1 deg; the two-handed pipe clips, whose roll is set from the right palm: the
##     weapon axis, and a left prop riding on it its rotation relative to the right prop); the off
##     hand stays on two-handed weapons (5 cm, in the source's prop frame); a left prop that
##     follows the right one keeps its offset (1 cm); two-handed clips: the weapon's ends are not
##     swapped (right palm not below the left one along +Z); guard clips: a 1.8 m spear held at its
##     butt stays above the floor; pipe and guard clips: the weapon's roll in the right palm is the
##     canonical grip's (1 deg). Guard clips with a synthetic weapon frame, on the frames the source
##     holds with both hands: the off hand's grip point within 2 cm of the weapon axis and within
##     5 cm of the source's placement relative to the right grip point (scaled), the weapon axis
##     within 20 deg of the line through the source's grip points, the fist centres >= 8 cm apart
##     along it
##  7. joints: elbows / knees never bend more than 3 deg past straight where the source does
##     not (signed hinge angle on the joint's hinge axis); flexion speed <= max(1.5 x source,
##     source + 8 deg) + 1 deg per frame; knees the source keeps straight (< 12 deg) bend at most
##     30 deg more, elbows at most 20 deg more; local rotation step of the limb bones <= source +
##     15 deg per frame; wrist swing <= source + 20 deg
##  8. continuity: no frame-to-frame joint jump more than 10 cm beyond 1.25x the source's;
##     real loops are closed (0.5 cm); ground clips keep heel / ball above the floor (the
##     source's own lowest point - 3 cm) and, per frame, heel / ball / ankle at least
##     min(the source's scaled height on that frame, 0) - 1.5 cm
##  9. mount clips: under the manifest's runtime recipe on the game horse (assets/horse
##     horse_meta.json attach_height) and at 1.37 / 1.60 m, the push-off ball stays on the floor
##     (>= -2 cm) and slides < 0.1 m/s over the push-off frames, and every ground contact of the
##     ground phase (the planted ball, the standing feet of frame 0) is within -2 / +1 cm of its bind
##     contact height (no hovering)
## Across clips: 10. seams (intro -> hit, start -> loop -> stop, block cycles, and every pair the
##     source joins within 5 cm) stay within the source's distance + 2 cm (named) or
##     1.5x + 3 cm (found automatically); 11. weapon seams (guard <-> haft sweep <-> blocked): the
##     weapon's whole turn in the right hand (swing and roll) at most 45 deg and its roll at most
##     10 deg; seams where the source's own hands turn the haft more (status "regrip (source)") at
##     most the source's turn + 15 deg; 12. AnimationTree Add2 of the additive clips equals the
##     tool's composition (2 mm).
## Exit code 0 when every check passes.

const LIB_PATH := "res://animations_extra/Actor_B_from_A.res"
const MANIFEST_PATH := "res://animations_extra/Actor_B_from_A.json"
const REF_PATH := "res://tests/retarget/data/actor_b_from_a_ref.json"
const HORSE_META := "res://assets/horse/horse_meta.json"
const LIB_NAME := "actor_b_from_a"
const FPS := 30.0
const POS_TOL := 0.002
const PROPS := ["l_hand_prop_attachment", "r_hand_prop_attachment"]
const SPEAR_L := 1.8

var sk: Skeleton3D
var ap: AnimationPlayer
var lib: AnimationLibrary
var man: Dictionary
var ref: Dictionary
var th: Dictionary
var fails := 0
var checks := 0
var verbose := false
var bone_cache := {}
var seam_cache := {}
var attach_heights := [1.37, 1.60]


func _initialize() -> void:
	verbose = "verbose" in OS.get_cmdline_user_args()
	var inst: Node3D = load("res://characters/Actor_B.tscn").instantiate()
	root.add_child(inst)
	sk = inst.get_node("Skeleton3D")
	ap = inst.get_node("AnimationPlayer")
	lib = load(LIB_PATH)
	man = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	ref = JSON.parse_string(FileAccess.get_file_as_string(REF_PATH))
	_check(lib != null and man != null and ref != null, "library, manifest and reference load")
	if lib == null or man == null or ref == null:
		_finish()
		return
	th = man.get("check_thresholds", {})
	if FileAccess.file_exists(HORSE_META):
		var hm = JSON.parse_string(FileAccess.get_file_as_string(HORSE_META))
		if hm is Dictionary and hm.has("attach_height"):
			attach_heights.push_front(float(hm["attach_height"]))
	ap.add_animation_library(LIB_NAME, lib)
	await process_frame
	_check(str(lib.get_meta("library_name", "")) == LIB_NAME and lib.resource_name == LIB_NAME,
			"library is named %s" % LIB_NAME)
	_check(lib.get_animation_list().size() == man["clips"].size(),
			"library has %d animations (manifest %d)" % [lib.get_animation_list().size(), man["clips"].size()])
	var t0 := Time.get_ticks_msec()
	for name: String in man["clips"]:
		_check_clip(name, man["clips"][name])
	for s: Dictionary in ref.get("seams", []):
		_check_seam(s)
	for s: Dictionary in ref.get("weapon_seams", []):
		_check_weapon_seam(s)
	for r: Dictionary in man.get("add2_reference", []):
		_check_add2(inst, r)
	print("  (sampled in %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_finish()


# ----------------------------------------------------------------------------- sampling
func _bi(b: String) -> int:
	if not bone_cache.has(b):
		bone_cache[b] = sk.find_bone(b)
	return bone_cache[b]


func _pose(name: String, t: float) -> void:
	sk.reset_bone_poses()
	ap.play(LIB_NAME + "/" + name)
	ap.seek(t, true)
	ap.stop(true)


func _gp(b: String) -> Vector3:
	return sk.get_bone_global_pose(_bi(b)).origin


func _gb(b: String) -> Basis:
	return sk.get_bone_global_pose(_bi(b)).basis.orthonormalized()


func _pose_vec() -> Array:
	# joints relative to the pelvis in the hips' heading frame + pelvis height (checks.py)
	var d := _gp("l_upper_leg") - _gp("r_upper_leg")
	var left := Vector3(d.x, 0, d.z).normalized()
	var fwd := left.cross(Vector3.UP)
	var pel := _gp("pelvis")
	var rel := []
	for j: String in ref["seam_joints"]:
		var v := _gp(j) - pel
		rel.append(Vector3(v.dot(left), v.y, v.dot(fwd)))
	return [rel, pel.y]


func _pose_dist(a: Array, b: Array) -> float:
	var s := 0.0
	for i in a[0].size():
		s += (a[0][i] as Vector3).distance_squared_to(b[0][i])
	return sqrt(s / a[0].size() + pow(float(a[1]) - float(b[1]), 2))


func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _signed_flex(hinge: String) -> float:
	# checks.signed_flex: angle between the segments, negative on the flexion side (deg)
	var h: Array = ref["hinges"][hinge]
	var u := _gp(hinge) - _gp(h[0])
	var v := _gp(h[1]) - _gp(hinge)
	var a := rad_to_deg(u.angle_to(v))
	var ax: Vector3 = _gb(hinge)[int(h[2])]
	return a * signf(u.cross(v).dot(ax))


func _wrist_swing(s: String) -> float:
	# checks.wrist_swing: wrist bend from the bind, twist about the forearm (local Z) removed
	var w := _bi(s + "_wrist")
	var L := _gb(s + "_elbow").inverse() * _gb(s + "_wrist")
	var q := (L * sk.get_bone_rest(w).basis.orthonormalized().transposed()).get_rotation_quaternion()
	var tw := Vector2(q.z, q.w).normalized()
	return rad_to_deg(2.0 * acos(clampf(absf(q.w * tw.y + q.z * tw.x), 0.0, 1.0)))


# ----------------------------------------------------------------------------- per clip
func _check_clip(name: String, rec: Dictionary) -> void:
	if not lib.has_animation(name):
		_check(false, "%s present" % name)
		return
	var anim := lib.get_animation(name)
	var stamp: Dictionary = anim.get_meta("retarget", {})
	var prov_ok: bool = str(anim.get_meta("native_asset_id", "")) == str(rec["native_asset_id"]) \
			and str(anim.get_meta("original_name", "")) != "" \
			and stamp.get("source_clip", "") == name and stamp.get("source_actor", "") == "Actor_A" \
			and str(stamp.get("source_native_asset_id", "")) == str(rec["native_asset_id"]) \
			and stamp.get("library", "") == LIB_NAME
	var bad_paths := []
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if str(path.get_concatenated_names()) != "Skeleton3D" or sk.find_bone(str(path.get_concatenated_subnames())) == -1:
			bad_paths.append(str(path))
	_check(prov_ok and bad_paths.is_empty(), "%s: provenance %s, %d tracks, bad paths %s" % [
			name, "ok" if prov_ok else "MISSING", anim.get_track_count(), bad_paths])
	if not rec.has("reference"):
		return  # additive: covered by the Add2 checks
	# 3. playback == tool FK
	var err := 0.0
	var worst := ""
	for i in rec["reference"]["frames"].size():
		var f: int = rec["reference"]["frames"][i]
		_pose(name, f / FPS)
		for j: String in rec["reference"]["joints"]:
			var e := _gp(j).distance_to(_v(rec["reference"]["joints"][j][i]))
			if e > err:
				err = e
				worst = "%s@%d" % [j, f]
	_check(err <= POS_TOL, "%s: playback == tool FK (max %.5f m %s)" % [name, err, worst])
	if not ref["clips"].has(name):
		return
	var r: Dictionary = ref["clips"][name]
	var F: int = r["frames"]
	var joints: Array = ref["joints"]
	var skip: Array = r.get("path_skip", [])
	# sample every frame once
	var P := []  # [F][J] Vector3, the reference joints
	var X := {}  # extra bones -> [F] Vector3
	var extra := ["pelvis", "l_heel", "r_heel", "l_ball", "r_ball", "l_wrist", "r_wrist", "l_knee", "r_knee", "l_palm", "r_palm",
			"l_ankle", "r_ankle"]
	for sd in ["l_", "r_"]:
		for fb: String in ref.get("fist_bones", []):
			if not (sd + fb) in extra:
				extra.append(sd + fb)
	for b: String in extra:
		X[b] = []
	var Q := {}  # prop -> [F] Quaternion
	var props_T := {}  # prop -> [F] Transform3D
	for pr in PROPS:
		Q[pr] = []
		props_T[pr] = []
	var palm_B := {"l_palm": [], "r_palm": []}  # [F] Basis
	var flex := {}  # hinge -> [F] deg
	for h: String in r.get("a_flex", {}):
		flex[h] = []
	var wsw := {}  # side -> [F] deg
	for s: String in r.get("a_wrist_swing", {}):
		wsw[s] = []
	var lrot := {}  # bone -> [F] Quaternion (local pose rotation)
	for b: String in r.get("a_step", {}):
		lrot[b] = []
	var floor_low := 1e9
	var bind_h: Dictionary = ref["bind_contact_height_B"]
	var first_pose: Array
	var last_pose: Array
	for f in F:
		_pose(name, minf(f / FPS, anim.length))
		var row := []
		for j: String in joints:
			row.append(_gp(j))
		P.append(row)
		for b: String in extra:
			X[b].append(_gp(b))
		for pr in PROPS:
			var T := sk.get_bone_global_pose(_bi(pr))
			Q[pr].append(T.basis.get_rotation_quaternion())
			props_T[pr].append(T)
		for pm: String in palm_B:
			palm_B[pm].append(_gb(pm))
		for h: String in flex:
			flex[h].append(_signed_flex(h))
		for s: String in wsw:
			wsw[s].append(_wrist_swing(s))
		for b: String in lrot:
			lrot[b].append(sk.get_bone_pose_rotation(_bi(b)).normalized())
		if r["profile"] == "ground":
			for p in ["l_heel", "l_ball", "r_heel", "r_ball"]:
				floor_low = minf(floor_low, _gp(p).y - float(bind_h[p]))
		if f == 0:
			first_pose = _pose_vec()
			seam_cache["%s|0" % name] = first_pose
		if f == F - 1:
			last_pose = _pose_vec()
			seam_cache["%s|1" % name] = last_pose
	var msgs := []
	var ok := true
	# 4. path similarity (pelvis-relative, per-joint mean removed)
	var a_rel: Array = r["a_rel"]
	var num := 0.0
	var den := 0.0
	var rms := []
	for ji in joints.size():
		if joints[ji] in skip:
			continue
		var mb := Vector3.ZERO
		var ma := Vector3.ZERO
		var rb := []
		for f in F:
			rb.append((P[f][ji] as Vector3) - (X["pelvis"][f] as Vector3))
			mb += rb[f]
			ma += _v(a_rel[f][ji])
		mb /= F
		ma /= F
		var jn := 0.0
		for f in F:
			var da := _v(a_rel[f][ji]) - ma
			var db: Vector3 = rb[f] - mb
			jn += db.distance_squared_to(da)
			den += da.length_squared()
		num += jn
		rms.append(sqrt(jn / F))
	rms.sort()
	var r2 := 1.0 - num / maxf(den, 1e-12)
	var med_rms: float = (rms[(rms.size() - 1) / 2] + rms[rms.size() / 2]) * 50.0
	# velocity cosine (clip-space paths, A scaled as in the tool)
	var a_abs: Array = r["a_abs"]
	var cs := 0.0
	var ws := 0.0
	for ji in joints.size():
		if joints[ji] in skip:
			continue
		for f in F - 1:
			var va := _v(a_abs[f + 1][ji]) - _v(a_abs[f][ji])
			var vb: Vector3 = (P[f + 1][ji] as Vector3) - (P[f][ji] as Vector3)
			if va.length() * FPS > 0.2 and vb.length() > 1e-9:
				cs += va.normalized().dot(vb.normalized()) * va.length()
				ws += va.length()
	var vcos := cs / ws if ws > 0 else 1.0
	var moving := med_rms > float(th.get("static_rms_cm", 1.0))
	if moving and (r2 < float(th.get("r2", 0.85)) or vcos < float(th.get("vel_cos", 0.88))):
		ok = false
	msgs.append("path r2 %.3f vcos %.3f dynRMS %.1f cm" % [r2, vcos, med_rms])
	# 5. contact slide
	var worst_slide := ""
	for pt: String in r.get("contacts", {}):
		var c: Dictionary = r["contacts"][pt]
		var mask: String = c["mask"]
		var sp := []
		for f in F - 1:
			if mask[f] == "1" and mask[f + 1] == "1":
				var a: Vector3 = X[pt][f]
				var b: Vector3 = X[pt][f + 1]
				sp.append(Vector2(b.x - a.x, b.z - a.z).length() * FPS)
		if sp.size() < 5 or c["a_slide_mps"] == null:
			continue
		sp.sort()
		var med: float = (sp[(sp.size() - 1) / 2] + sp[sp.size() / 2]) * 0.5
		var slide_extra := float(th.get("foot_slide_extra_mps", 0.05)) if (pt.ends_with("heel") or pt.ends_with("ball")) \
				else float(th.get("limb_slide_extra_mps", 0.10))
		if med > float(c["a_slide_mps"]) + slide_extra:
			ok = false
			worst_slide += " %s %.3f>%.3f" % [pt, med, float(c["a_slide_mps"])]
	if not r.get("contacts", {}).is_empty():
		msgs.append("contacts %d%s" % [r["contacts"].size(), worst_slide])
	# 6. props and weapons
	var prop_err := 0.0
	var axis_only: bool = r.get("prop_axis_only", false)
	var apq: Dictionary = r.get("a_prop_world_q", {})
	for pr: String in apq:
		var qa: Array = apq[pr]
		for f in F:
			var q := _q(qa[f])
			var qb: Quaternion = (Q[pr][f] as Quaternion).normalized()
			if axis_only and pr == "r_hand_prop_attachment":
				# roll set from the right palm: the weapon axis keeps the source's world direction
				prop_err = maxf(prop_err, rad_to_deg((Basis(q).z).angle_to(Basis(qb).z)))
			elif axis_only and apq.has("r_hand_prop_attachment"):
				# a left prop riding on the weapon: its rotation relative to the right prop
				var qra := _q(apq["r_hand_prop_attachment"][f])
				var qrb: Quaternion = (Q["r_hand_prop_attachment"][f] as Quaternion).normalized()
				var ra := qra.inverse() * q
				var rb := qrb.inverse() * qb
				prop_err = maxf(prop_err, rad_to_deg(2.0 * acos(clampf(absf(ra.dot(rb)), 0.0, 1.0))))
			else:
				prop_err = maxf(prop_err, rad_to_deg(2.0 * acos(clampf(absf(q.dot(qb)), 0.0, 1.0))))
	if not r.get("a_prop_world_q", {}).is_empty():
		msgs.append("prop rot %.2f deg" % prop_err)
		if prop_err > float(th.get("prop_rot_deg", 1.0)):
			ok = false
	var held := ""
	if r.has("grip"):
		var g: Dictionary = r["grip"]
		held = g["held"]
		var ge := 0.0
		for f in F:
			if g["held"][f] != "1":
				continue
			var T: Transform3D = props_T[g["main_prop"]][f]
			# in the source's prop frame (the pipe clips' roll is set from the palm; the grip is compared without it)
			var Rm := T.basis.orthonormalized()
			if apq.has(g["main_prop"]):
				Rm = Basis(_q(apq[g["main_prop"]][f]))
			var rel := Rm.inverse() * ((X[g["palm"]][f] as Vector3) - T.origin)
			ge = maxf(ge, rel.distance_to(_v(g["a_palm_in_prop"][f])))
		msgs.append("grip %.1f cm" % (ge * 100))
		if ge * 100 > float(th.get("grip_cm", 5.0)):
			ok = false
	if r.has("axis_grip"):
		var g: Dictionary = r["axis_grip"]
		held = g["held"]
		var pt_l := _v(ref["axis_grip_point_l"])
		var pt_r := _v(ref["axis_grip_point_r"])
		var ge := 0.0
		var disp := 0.0
		var ax_dev := 0.0
		var sep := 1e9
		for f in F:
			if g["held"][f] != "1":
				continue
			var T: Transform3D = props_T[g["main_prop"]][f]
			var z := T.basis.orthonormalized().z
			var gl: Vector3 = (X["l_palm"][f] as Vector3) + (palm_B["l_palm"][f] as Basis) * pt_l
			var gr: Vector3 = (X["r_palm"][f] as Vector3) + (palm_B["r_palm"][f] as Basis) * pt_r
			var c: Vector3 = gl - T.origin
			ge = maxf(ge, (c - z * c.dot(z)).length())
			# against the source's hands: grip point placement (scaled), weapon axis, fists apart
			disp = maxf(disp, (gl - gr).distance_to(_v(g["a_rel_s"][f])))
			ax_dev = maxf(ax_dev, rad_to_deg(z.angle_to(_v(g["a_line"][f]))))
			sep = minf(sep, (_fist(X, "r_", f) - _fist(X, "l_", f)).dot(z))
		msgs.append("off hand on the weapon axis %.1f cm, %.1f cm from the source's placement, axis %.1f deg off the source's hands, fists %.2f m apart" % [
				ge * 100, disp * 100, ax_dev, sep])
		if ge * 100 > float(th.get("axis_grip_cm", 2.0)) or disp * 100 > float(th.get("offhand_source_cm", 5.0)) \
				or ax_dev > float(th.get("axis_source_deg", 20.0)) or sep < float(th.get("fist_sep_m", 0.08)):
			ok = false
	if r.has("weapon") and held != "":
		var swapped := 0
		var tip_low := 1e9
		for f in F:
			if held[f] != "1":
				continue
			var T: Transform3D = props_T["r_hand_prop_attachment"][f]
			var z := T.basis.orthonormalized().z
			var al := ((X["l_palm"][f] as Vector3) - T.origin).dot(z)
			var ar := ((X["r_palm"][f] as Vector3) - T.origin).dot(z)
			if ar < al - 0.05:
				swapped += 1
			tip_low = minf(tip_low, (T.origin + z * (SPEAR_L - 0.08)).y)
		msgs.append("weapon ends swapped on %d frames" % swapped)
		if swapped > int(th.get("ends_swapped_frames", 0)):
			ok = false
		if r["weapon"].get("guard", false):
			msgs.append("1.8 m spear tip >= %.2f m" % tip_low)
			if tip_low < float(th.get("spear_tip_min_y_m", 0.0)):
				ok = false
	if r.get("roll_check", false) and ref.has("canonical_right_grip_q"):
		var Mc := Basis(_q(ref["canonical_right_grip_q"]))
		var roll := 0.0
		for f in F:
			var Rin := (palm_B["r_palm"][f] as Basis).inverse() * (props_T["r_hand_prop_attachment"][f] as Transform3D).basis.orthonormalized()
			roll = maxf(roll, absf(_roll(Mc, Rin)))
		msgs.append("weapon roll in the palm %.2f deg" % roll)
		if roll > float(th.get("in_palm_roll_deg", 1.0)):
			ok = false
	if r.has("left_prop_in_right"):
		var le := 0.0
		for f in F:
			var T: Transform3D = props_T["r_hand_prop_attachment"][f]
			var rel := T.basis.orthonormalized().inverse() * ((props_T["l_hand_prop_attachment"][f] as Transform3D).origin - T.origin)
			le = maxf(le, rel.distance_to(_v(r["left_prop_in_right"][f])))
		msgs.append("left prop %.2f cm" % (le * 100))
		if le * 100 > float(th.get("left_prop_cm", 1.0)):
			ok = false
	# 7. joints
	var hyper := 0
	var flex_ex := -1e9
	var knee_ex := 0.0
	var elbow_ex := 0.0
	for h: String in flex:
		var fa: Array = r["a_flex"][h]
		for f in F:
			var a := float(fa[f]) * 0.1
			var b: float = flex[h][f]
			var folded := absf(a) > 170.0 and absf(b) > 170.0
			if b > float(th.get("hyper_deg", 3.0)) and a <= float(th.get("hyper_deg", 3.0)) and not folded:
				hyper += 1
			if h.ends_with("knee") and absf(a) < 12.0:
				knee_ex = maxf(knee_ex, absf(b) - absf(a))
			if h.ends_with("elbow") and absf(a) < 12.0:
				elbow_ex = maxf(elbow_ex, absf(b) - absf(a))
			if f > 0:
				var da := absf(absf(a) - absf(float(fa[f - 1]) * 0.1))
				var db := absf(absf(b) - absf(float(flex[h][f - 1])))
				flex_ex = maxf(flex_ex, db - maxf(1.5 * da, da + 8.0))
	if not flex.is_empty():
		msgs.append("backwards %d, flex speed %+.1f deg, straight knee +%.0f deg, straight elbow +%.0f deg" % [
				hyper, maxf(flex_ex, 0.0), knee_ex, elbow_ex])
		if hyper > 0 or flex_ex > float(th.get("flex_speed_excess_deg", 1.0)) \
				or knee_ex > float(th.get("straight_knee_fail_deg", 30.0)) or elbow_ex > float(th.get("straight_elbow_fail_deg", 20.0)):
			ok = false
	var step_ex := 0.0
	var step_worst := ""
	for b: String in lrot:
		var sa: Array = r["a_step"][b]
		for f in F - 1:
			var qb0: Quaternion = lrot[b][f]
			var qb1: Quaternion = lrot[b][f + 1]
			var sb := rad_to_deg(2.0 * acos(clampf(absf(qb0.dot(qb1)), 0.0, 1.0)))
			var e := sb - float(sa[f]) * 0.1
			if e > step_ex:
				step_ex = e
				step_worst = "%s@%d" % [b, f + 1]
	var wr_ex := 0.0
	for s: String in wsw:
		var wa: Array = r["a_wrist_swing"][s]
		for f in F:
			wr_ex = maxf(wr_ex, float(wsw[s][f]) - float(wa[f]) * 0.1)
	if not lrot.is_empty() or not wsw.is_empty():
		msgs.append("rot step +%.1f deg %s, wrist swing +%.1f deg" % [step_ex, step_worst, wr_ex])
		if step_ex > float(th.get("rot_step_excess_deg", 15.0)) or wr_ex > float(th.get("wrist_swing_excess_deg", 20.0)):
			ok = false
	# 8. continuity
	var excess := 0.0
	for f in F - 1:
		for ji in joints.size():
			if joints[ji] in skip:
				continue
			var sa := _v(a_abs[f + 1][ji]).distance_to(_v(a_abs[f][ji]))
			var sb := (P[f + 1][ji] as Vector3).distance_to(P[f][ji])
			excess = maxf(excess, sb - 1.25 * sa)
	msgs.append("step excess %.1f cm" % (excess * 100))
	if excess * 100 > float(th.get("step_excess_fail_cm", 10.0)):
		ok = false
	if r.get("loop", false):
		var ls := _pose_dist(first_pose, last_pose) * 100
		msgs.append("loop seam %.2f cm" % ls)
		if ls > float(th.get("loop_seam_cm", 0.5)):
			ok = false
	if r["profile"] == "ground" and r.has("a_floor_lowest_cm"):
		var lim := minf(float(r["a_floor_lowest_cm"]), 0.0) - 3.0
		msgs.append("floor %.1f cm (limit %.1f)" % [floor_low * 100, lim])
		if floor_low * 100 < lim:
			ok = false
	if r.has("a_floor_h_mm"):
		# per frame: heel / ball / ankle >= min(source's scaled height on that frame, 0) - 1.5 cm
		var slack := float(th.get("floor_frame_slack_cm", 1.5)) * 0.01
		var margin := 1e9
		var where := ""
		for pt: String in r["a_floor_h_mm"]:
			var ha: Array = r["a_floor_h_mm"][pt]
			for f in F:
				var mg: float = ((X[pt][f] as Vector3).y - float(bind_h[pt])) - (minf(float(ha[f]) * 0.001, 0.0) - slack)
				if mg < margin:
					margin = mg
					where = "%s@%d" % [pt, f]
		msgs.append("floor per frame margin %.1f cm %s" % [margin * 100, where])
		if margin < 0.0:
			ok = false
	# 9. mount recipe
	if r.has("mount"):
		var m: Dictionary = r["mount"]
		var g2s: Array = m["ground_to_saddle"]
		var ref_h := float(m["reference_saddle_height_m"])
		var ball: String = str(m["push_off_foot"]) + "_ball"
		var w0: int = m["push_off_frames"][0]
		var w1: int = m["push_off_frames"][1]
		var bh := sk.get_bone_global_rest(_bi(ball)).origin.y
		var worst_m := ""
		for H: float in attach_heights:
			var low := 1e9
			var slide := 0.0
			var prev := Vector3.ZERO
			for f in range(w0, w1 + 1):
				var p: Vector3 = X[ball][f] + Vector3(0, H - (H - ref_h) * (1.0 - float(g2s[f])), 0)
				low = minf(low, p.y - bh)
				if f > w0:
					slide = maxf(slide, Vector2(p.x - prev.x, p.z - prev.z).length() * FPS)
				prev = p
			# ground contacts of the ground phase: on the floor, not hovering
			var c_lo := 1e9
			var c_hi := -1e9
			var gc: Dictionary = m.get("ground_contacts", {})
			for pt: String in gc:
				var ch := sk.get_bone_global_rest(_bi(pt)).origin.y
				for fv in gc[pt]:
					var f := int(fv)
					var y: float = (X[pt][f] as Vector3).y + H - (H - ref_h) * (1.0 - float(g2s[f])) - ch
					c_lo = minf(c_lo, y)
					c_hi = maxf(c_hi, y)
			worst_m += " %.3f m: %.1f cm %.3f m/s, contacts %.1f .. %.1f cm;" % [H, low * 100, slide, c_lo * 100, c_hi * 100]
			if low * 100 < float(th.get("mount_floor_cm", -2.0)) or slide > float(th.get("mount_slide_mps", 0.1)):
				ok = false
			if not gc.is_empty() and (c_lo * 100 < float(th.get("mount_floor_cm", -2.0)) or c_hi * 100 > float(th.get("mount_contact_max_cm", 1.0))):
				ok = false
		msgs.append("mount push-off at saddle%s" % worst_m)
	_check(ok, "%s: %s" % [name, ", ".join(msgs)])


# ----------------------------------------------------------------------------- across clips
func _seam_pose(name: String, last: bool) -> Array:
	var key := "%s|%d" % [name, 1 if last else 0]
	if not seam_cache.has(key):
		var a := lib.get_animation(name)
		_pose(name, a.length if last else 0.0)
		seam_cache[key] = _pose_vec()
	return seam_cache[key]


func _check_seam(s: Dictionary) -> void:
	if not (lib.has_animation(s["from"]) and lib.has_animation(s["to"])):
		return
	var d := _pose_dist(_seam_pose(s["from"], true), _seam_pose(s["to"], false)) * 100
	var lim: float
	if s["named"]:
		lim = float(s["A_cm"]) + float(th.get("named_seam_extra_cm", 2.0))
	else:
		lim = float(s["A_cm"]) * float(th.get("auto_seam_factor", 1.5)) + float(th.get("auto_seam_extra_cm", 3.0))
	var ok := d <= lim
	if verbose or not ok or s["named"]:
		_check(ok, "seam %s -> %s: %.1f cm (source %.1f, limit %.1f)" % [s["from"], s["to"], d, float(s["A_cm"]), lim])
	else:
		checks += 1


func _in_hand(name: String, last: bool) -> Basis:
	var a := lib.get_animation(name)
	_pose(name, a.length if last else 0.0)
	return _gb("r_palm").inverse() * _gb("r_hand_prop_attachment")


func _check_weapon_seam(s: Dictionary) -> void:
	if not (lib.has_animation(s["from"]) and lib.has_animation(s["to"])):
		return
	var ia := _in_hand(s["from"], true)
	var ib := _in_hand(s["to"], false)
	var qd := (ia.inverse() * ib).get_rotation_quaternion()
	var d := rad_to_deg(2.0 * acos(clampf(absf(qd.w), 0.0, 1.0)))  # the shorter way round
	var roll := absf(_roll(ia, ib))
	var lim := float(th.get("weapon_in_hand_deg", 45.0))
	var roll_lim := float(th.get("weapon_seam_roll_deg", 10.0))
	var st: String = s.get("status", s.get("kind", "same_grip"))
	var ok := true
	var how := ""
	if st == "same_grip":
		ok = d <= lim and roll <= roll_lim
		how = "limit %.0f, roll %.0f" % [lim, roll_lim]
	elif st == "regrip (source)":
		var src := float(s.get("source_in_hand_deg", 0.0))
		ok = d <= src + float(th.get("regrip_extra_deg", 15.0)) and roll <= roll_lim
		how = "regrip in the source (%.0f deg), limit %.0f" % [src, src + float(th.get("regrip_extra_deg", 15.0))]
	else:
		how = "reported"
	_check(ok, "weapon seam %s -> %s: turns %.0f deg (roll %.1f) in the right hand (%s, %s)" % [
			s["from"], s["to"], d, roll, st, how])


func _roll(Ma: Basis, Mb: Basis) -> float:
	# roll (deg) of Mb about its own +Z against Ma swung onto the same axis (minimal swing)
	var za := Ma.z.normalized()
	var zb := Mb.z.normalized()
	var S := Basis(Quaternion(za, zb)) if za.cross(zb).length() > 1e-9 else Basis()
	var T := (S * Ma).inverse() * Mb
	return rad_to_deg(atan2(T.x.y, T.x.x))


func _q(a: Array) -> Quaternion:
	return Quaternion(a[0], a[1], a[2], a[3]).normalized()


func _fist(X: Dictionary, sd: String, f: int) -> Vector3:
	var c := Vector3.ZERO
	for fb: String in ref["fist_bones"]:
		c += X[sd + fb][f]
	return c / float(ref["fist_bones"].size())


func _check_add2(inst: Node3D, r: Dictionary) -> void:
	var tree := AnimationTree.new()
	inst.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(inst)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var err := 0.0
	var worst := ""
	for i in r["frames"].size():
		var f: int = r["frames"][i]
		var bt := AnimationNodeBlendTree.new()
		var a := AnimationNodeAnimation.new()
		a.animation = LIB_NAME + "/" + str(r["base"])
		bt.add_node("base", a)
		var n := AnimationNodeAnimation.new()
		n.animation = LIB_NAME + "/" + str(r["add"])
		bt.add_node("add", n)
		bt.add_node("sum", AnimationNodeAdd2.new())
		bt.connect_node("sum", 0, "base")
		bt.connect_node("sum", 1, "add")
		bt.connect_node("output", 0, "sum")
		sk.reset_bone_poses()
		tree.tree_root = bt
		tree.active = true
		tree.set("parameters/sum/add_amount", 1.0)
		tree.advance(0.0)
		tree.advance(f / FPS)
		for j: String in r["joints"]:
			var e := _gp(j).distance_to(_v(r["joints"][j][i]))
			if e > err:
				err = e
				worst = "%s@%d" % [j, f]
		tree.active = false
	tree.queue_free()
	_check(err <= POS_TOL, "Add2(%s, %s) in an AnimationTree == tool reference (max %.5f m %s)" % [
			r["base"], r["add"], err, worst])


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	if verbose or not ok or not msg.contains(": provenance ok"):
		print(("  ok   " if ok else "  FAIL ") + msg)


func _finish() -> void:
	print("ACTOR_B_FROM_A LIBRARY %s (%d checks, %d failed)" % ["OK" if fails == 0 else "FAILED", checks, fails])
	quit(0 if fails == 0 else 1)
