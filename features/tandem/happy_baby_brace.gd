extends PalmReachIK
## Happy Baby braces the kneeling partner with hands at the outer upper back
## with the original bent Happy Baby legs unchanged. Targets follow the plank pose.
var partner: Skeleton3D
var partner_motion: Node
var hold := 0.0
var palm_miss := 0.0
var foot_miss := 0.0
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or not is_instance_valid(partner) or hold <= 0: return
	var chest := partner.global_transform * partner.get_bone_global_pose(partner.find_bone("spined"))
	var pelvis := partner.global_transform * partner.get_bone_global_pose(partner.find_bone("pelvis"))
	if is_instance_valid(partner_motion):
		chest = partner_motion.chest_world
		pelvis = partner_motion.pelvis_world
	palm_miss = 0.0
	foot_miss = 0.0
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var target := sk.global_transform.affine_inverse() * (chest.origin + sk.global_basis * Vector3(sign_x * 0.17, 0.01, 0.0))
		apply_side(sk, side, target, hold)
		var ids := _bones(sk, side)
		palm_miss = maxf(palm_miss, sk.get_bone_global_pose(int(ids[3])).origin.distance_to(target))


