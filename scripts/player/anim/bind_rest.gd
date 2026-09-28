class_name BindRest
extends RefCounted
## Runtime guard for the Actor_B rest pose (plan WP0, section 4.4).
##
## The extracted clips, and the game's additive composition base * (null-add^-1 * add),
## are authored against the bind pose held in the 1-frame clip `null-add`. The asset
## pipeline (Player_Animation_Project/godot_export/tools/build_libraries.gd) bakes that
## pose into the Skeleton3D rest: every channel `null-add` keys at t = 0 becomes the rest
## value of that channel, and every other channel keeps the imported glTF rest. With that
## rest, Godot's Add2 (base * rest^-1 * add) equals the game's composition, and bones a
## clip does not key fall back to the bind pose.
##
## verify() checks that convention; ensure() re-applies it if a rig ever arrives without
## it. With the shipped rig ensure() is a no-op. Neither function touches animation data
## (asset IDs, native_asset_id and source_attribution metadata stay as extracted), and
## ensure() only edits this Skeleton3D instance, never the shared AnimationLibrary.
##
## Call order in the game: ensure() right after the rig is instantiated, before anything
## reads bone rests (BoneMannequin, BoneAttachment3D, skinned meshes, PlayerAnim).

const REF := &"null-add"
## Tolerances of the rest == null-add check (radians / metres).
const ROT_TOL := 1e-6
const POS_TOL := 1e-6
const SCL_TOL := 1e-6
## Skeleton3D metadata key written by build_libraries.gd.
const STAMP := &"bind_rest"

static var _warned := false


## Checks rest == null-add@t0 on every channel null-add keys.
## Returns {ok: bool, max_rot: float (rad), max_pos: float (m), channels: int, stamped: bool,
##          max_scl: float, worst: String ("bone|r" etc.), reason: String ("" when ok)}.
static func verify(sk: Skeleton3D, ap: AnimationPlayer, lib := &"actor_b") -> Dictionary:
	var out := {"ok": false, "max_rot": 0.0, "max_pos": 0.0, "max_scl": 0.0, "channels": 0,
			"stamped": is_stamped(sk), "worst": "", "reason": ""}
	var ref := reference_clip(ap, lib)
	if sk == null or ref == null:
		out.reason = "no Skeleton3D" if sk == null else "library '%s' has no '%s' clip" % [lib, REF]
		return out
	var worst_err := 0.0
	for t in ref.get_track_count():
		var bone := sk.find_bone(str(ref.track_get_path(t).get_concatenated_subnames()))
		if bone == -1:
			continue
		var rest := sk.get_bone_rest(bone)
		var err := 0.0
		var tag := ""
		match ref.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				err = quat_angle(rest.basis.get_rotation_quaternion(), ref.rotation_track_interpolate(t, 0.0).normalized())
				out.max_rot = maxf(out.max_rot, err)
				tag = "r"
				err /= ROT_TOL
			Animation.TYPE_POSITION_3D:
				err = vec_dist(rest.origin, ref.position_track_interpolate(t, 0.0))
				out.max_pos = maxf(out.max_pos, err)
				tag = "p"
				err /= POS_TOL
			Animation.TYPE_SCALE_3D:
				err = vec_dist(rest.basis.get_scale(), ref.scale_track_interpolate(t, 0.0))
				out.max_scl = maxf(out.max_scl, err)
				tag = "s"
				err /= SCL_TOL
			_:
				continue
		out.channels += 1
		if err > worst_err:
			worst_err = err
			out.worst = "%s|%s" % [sk.get_bone_name(bone), tag]
	if out.channels == 0:
		out.reason = "'%s' keys no bone of this skeleton" % REF
	elif out.max_rot > ROT_TOL or out.max_pos > POS_TOL or out.max_scl > SCL_TOL:
		out.reason = "rest differs from %s (rot %s rad, pos %s m, worst %s)" % [REF, sci(out.max_rot), sci(out.max_pos), out.worst]
	else:
		out.ok = true
	return out


## verify(); if not ok, sets the rest of every channel null-add keys to its t = 0 value
## (the build_libraries.gd algorithm), calls reset_bone_poses() and warns once.
## Returns the post-repair verify() dict plus `changed` (bones whose rest was rewritten).
## Idempotent: a second call changes 0 bones.
static func ensure(sk: Skeleton3D, ap: AnimationPlayer, lib := &"actor_b") -> Dictionary:
	var pre := verify(sk, ap, lib)
	if pre.ok:
		pre["changed"] = 0
		return pre
	var ref := reference_clip(ap, lib)
	if sk == null or ref == null:
		push_error("BindRest.ensure: %s; the rest cannot be checked or fixed." % pre.reason)
		pre["changed"] = 0
		return pre
	var changed := apply(sk, ref)
	var post := verify(sk, ap, lib)
	post["changed"] = changed
	if not _warned:
		_warned = true
		push_warning("BindRest.ensure: %s. Rest re-applied from '%s' on %d bones (post: rot %s rad, pos %s m). Rebuild the rig with godot_export/tools/build_libraries.gd." % [
				pre.reason, REF, changed, sci(post.max_rot), sci(post.max_pos)])
	if not post.ok:
		push_error("BindRest.ensure: rest still differs after the repair: %s" % post.reason)
	return post


## Convenience for a character scene root (Node3D > Skeleton3D + AnimationPlayer).
static func ensure_character(character: Node, lib := &"actor_b") -> Dictionary:
	var sks := character.find_children("*", "Skeleton3D", true, false)
	var aps := character.find_children("*", "AnimationPlayer", true, false)
	return ensure(sks[0] if not sks.is_empty() else null, aps[0] if not aps.is_empty() else null, lib)


## Writes null-add@t0 into the rest of every channel it keys; other channels keep their
## rest. Same algorithm as build_libraries.gd::_apply_bind_rest (without RESET, which lives
## in the shared library). Returns the number of bones whose rest changed.
static func apply(sk: Skeleton3D, ref: Animation) -> int:
	var rests := {}
	for t in ref.get_track_count():
		var bone := sk.find_bone(str(ref.track_get_path(t).get_concatenated_subnames()))
		if bone == -1:
			continue
		if not rests.has(bone):
			var r := sk.get_bone_rest(bone)
			rests[bone] = [r.origin, r.basis.get_rotation_quaternion(), r.basis.get_scale(), r]
		var row: Array = rests[bone]
		match ref.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				row[0] = ref.position_track_interpolate(t, 0.0)
			Animation.TYPE_ROTATION_3D:
				row[1] = ref.rotation_track_interpolate(t, 0.0).normalized()
			Animation.TYPE_SCALE_3D:
				row[2] = ref.scale_track_interpolate(t, 0.0)
	var changed := 0
	for bone: int in rests:
		var row: Array = rests[bone]
		var rest := Transform3D(Basis(row[1] as Quaternion) * Basis.from_scale(row[2]), row[0])
		if not rest.is_equal_approx(row[3]):
			changed += 1
		sk.set_bone_rest(bone, rest)
	sk.reset_bone_poses()
	return changed


static func reference_clip(ap: AnimationPlayer, lib := &"actor_b") -> Animation:
	if ap == null or not ap.has_animation_library(lib):
		return null
	var l := ap.get_animation_library(lib)
	return l.get_animation(REF) if l.has_animation(REF) else null


static func is_stamped(sk: Skeleton3D) -> bool:
	if sk == null or not sk.has_meta(STAMP):
		return false
	var s: Variant = sk.get_meta(STAMP)
	return s is Dictionary and str((s as Dictionary).get("source", "")) == String(REF)


## Angle between two rotations, numerically stable near 0 (Quaternion.angle_to goes through
## acos in single precision and cannot resolve differences below about 3e-4 rad).
static func quat_angle(a: Quaternion, b: Quaternion) -> float:
	var s := 1.0 if (a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w) >= 0.0 else -1.0
	var dx := a.x - s * b.x; var dy := a.y - s * b.y; var dz := a.z - s * b.z; var dw := a.w - s * b.w
	var sx := a.x + s * b.x; var sy := a.y + s * b.y; var sz := a.z + s * b.z; var sw := a.w + s * b.w
	return 4.0 * atan2(sqrt(dx * dx + dy * dy + dz * dz + dw * dw), sqrt(sx * sx + sy * sy + sz * sz + sw * sw))


## Short scientific notation for messages (GDScript's % operator has no %e / %g).
static func sci(x: float) -> String:
	if x == 0.0:
		return "0"
	var e := floori(log(absf(x)) / log(10.0))
	var m := x / pow(10.0, e)
	if absf(snappedf(m, 0.01)) >= 10.0:
		m /= 10.0
		e += 1
	return "%.2fe%d" % [m, e]


## Distance in double precision (Vector3.distance_to is single precision).
static func vec_dist(a: Vector3, b: Vector3) -> float:
	var dx := float(a.x) - float(b.x); var dy := float(a.y) - float(b.y); var dz := float(a.z) - float(b.z)
	return sqrt(dx * dx + dy * dy + dz * dz)
