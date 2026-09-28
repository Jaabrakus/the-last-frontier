class_name RodStance
extends SkeletonModifier3D
## The rod out, the angler strafes (user 2026-09-28: "for the rod fishing out allow strafing"): the legs keep the
## locomotion (a step to the side, back, on), and the upper body with the rod in its hands keeps facing the way the
## camera looks, the rod out over the water, as an aimed weapon's does (AimStabilizer, the same correction): the bones
## the upper body and the arms hang from (upper_base and the root's *_offset children: AimStabilizer.default_bones) are
## turned by c = root_L^-1 * root_A, the locomotion's root to the rod clip's (root_q: FishingGear sets it, the clip's
## own root, the rest for the rod's poses, the swing's for a cast), so they take the clip's model-space turn whatever
## the legs do. `weight` eases it in and out with the rod's pose.
## Runs after the rod's ToolPose (FishingGear adds it next to it); BoneAttachment3D (the rod's hand) reads the
## corrected pose.

var root_q := Quaternion.IDENTITY
var weight := 0.0

var _root := -1
var _bones: Array[int] = []


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or weight <= 0.0:
		return
	if _root < 0:
		var names := AimStabilizer.default_bones(sk)
		for n in names:
			var b := sk.find_bone(n)
			if b >= 0:
				_bones.append(b)
		_root = sk.find_bone("root")
		if _root < 0 or _bones.is_empty():
			_root = -2
	if _root < 0:
		return
	var c := (sk.get_bone_pose_rotation(_root).inverse() * root_q).normalized()
	var cw := Quaternion.IDENTITY.slerp(c, clampf(weight, 0.0, 1.0)).normalized()
	for b in _bones:
		sk.set_bone_pose_rotation(b, (cw * sk.get_bone_pose_rotation(b)).normalized())
		sk.set_bone_pose_position(b, cw * sk.get_bone_pose_position(b))
