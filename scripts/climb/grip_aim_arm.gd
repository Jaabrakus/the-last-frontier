class_name GripAimArm
extends SkeletonModifier3D
## The free right arm while hanging one-handed from a grip (user 2026-09-27: "for hanging i think being able to shoot
## pistols throw axes and spears should be okay"): over the one-hand hang (hang3_loop: the left hand holds, the right
## hangs free) the right arm is turned to point at the crosshair, the shoulder at the target and the forearm straight,
## and the hand turned so the weapon's muzzle lies along it (a pistol aims down the arm). For a throw, `cock` draws the
## arm back and up behind the shoulder (winding up, holding) and letting it go to 0 swings it through (the release).
## The shots and throws leave toward the crosshair whatever the arm does (Weapon._launch, Throwable); this is how it
## looks. PlayerGrip sets target, muzzle, cock and fades influence in and out.

const SHOULDER := "r_shoulder"
const ELBOW := "r_elbow"
const WRIST := "r_wrist"
const PROP := "r_hand_prop_attachment"

## The aim point (world).
var target := Vector3.ZERO
## The weapon's muzzle (a Marker3D under the prop bone's attachment, pointing along -Z), or null.
var muzzle: Node3D
## 0 aimed at the target .. 1 drawn back to throw.
var cock := 0.0

var _ids := PackedInt32Array()


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _ids.is_empty():
		for b in [SHOULDER, ELBOW, WRIST, PROP]:
			_ids.append(sk.find_bone(b))
		if _ids.has(-1):
			_ids = PackedInt32Array()
			return
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var s := sk.get_bone_global_pose(_ids[0])
	var e := sk.get_bone_global_pose(_ids[1])
	var w := sk.get_bone_global_pose(_ids[2])
	var pr := sk.get_bone_global_pose(_ids[3])
	var d := (inv * target - s.origin).normalized()
	if cock > 0.0:
		# back and up behind the shoulder, the way it will throw
		var flat := Vector3(d.x, 0.0, d.z)
		flat = flat.normalized() if flat.length_squared() > 1e-4 else Vector3.BACK
		d = d.slerp((-flat * 0.55 + Vector3.UP * 0.85).normalized(), clampf(cock, 0.0, 1.0)).normalized()
	# the upper arm at it, then the forearm straight on along it
	var s2 := Transform3D(Basis(Quaternion((e.origin - s.origin).normalized(), d)) * s.basis, s.origin)
	sk.set_bone_global_pose(_ids[0], s2)
	var e2 := s2 * (s.affine_inverse() * e)
	var w2 := e2 * (e.affine_inverse() * w)
	var e3 := Transform3D(Basis(Quaternion((w2.origin - e2.origin).normalized(), d)) * e2.basis, e2.origin)
	sk.set_bone_global_pose(_ids[1], e3)
	var w3 := e3 * (e.affine_inverse() * w)
	# the hand: the muzzle along the arm's line to the target
	if muzzle != null and is_instance_valid(muzzle) and muzzle.is_inside_tree() and cock < 0.5:
		var att := muzzle.get_parent()
		while att != null and not (att is BoneAttachment3D):
			att = att.get_parent()
		if att != null:
			var rel := (att as Node3D).global_transform.affine_inverse() * muzzle.global_transform
			var m := w3 * (w.affine_inverse() * pr) * rel
			var f := (m.basis * Vector3.FORWARD).normalized()
			var aim := (inv * target - m.origin).normalized()
			sk.set_bone_global_pose(_ids[2], Transform3D(Basis(Quaternion(f, aim)) * w3.basis, w3.origin))
