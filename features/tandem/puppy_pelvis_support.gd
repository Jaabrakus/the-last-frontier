extends PalmReachIK
## Both hands support the puppy player's outer hips after the kneeling animation.
@export var hip_half_width := 0.175
@export var grip_height := 0.065
@export var grip_back := 0.0
@export var look_down_max := 65.0
@export var head_raise_degrees := 20.0
@export_range(0.0, 1.0) var hold := 0.0
var lead_motion: Node
var lead: Skeleton3D
var palm_miss := {"l": 0.0, "r": 0.0}
var reach_lean := 0.0
var targets := {"l": Vector3.ZERO, "r": Vector3.ZERO}
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or not is_instance_valid(lead) or hold <= 0.0: return
	var pelvis := lead.find_bone("pelvis")
	if pelvis < 0: return
	if is_instance_valid(lead_motion) and lead_motion.moving: _fit_support_reach(sk)
	_look_at_back(sk)
	var center := lead.get_bone_global_pose(pelvis).origin
	if is_instance_valid(lead_motion): center = lead.global_transform.affine_inverse() * lead_motion.pelvis_world.origin
	for side: String in ["l", "r"]:
		var ids := _bones(sk, side)
		if ids.is_empty(): continue
		var offset := Vector3(hip_half_width if side == "l" else -hip_half_width, grip_height, grip_back)
		var target: Vector3 = sk.global_transform.affine_inverse() * (lead.global_transform * (center + offset))
		targets[side] = target
		if side == "r": _mirror_left_arm(sk, ids)
		# Turn the hand down along the reach so its palm cups the hip rather than
		# retaining the source clip's chest-level wrist angle.
		var wrist := sk.get_bone_global_pose(int(ids[2]))
		var palm := sk.get_bone_global_pose(int(ids[3])).origin
		var shoulder := sk.get_bone_global_pose(int(ids[0])).origin
		var turn := Quaternion.IDENTITY.slerp(_arc((palm - wrist.origin).normalized(), (target - shoulder).normalized()), hold)
		sk.set_bone_global_pose(int(ids[2]), Transform3D(Basis(turn) * wrist.basis, wrist.origin))
		_solve_support(sk, ids, target)
		palm_miss[side] = sk.get_bone_global_pose(int(ids[3])).origin.distance_to(target)

## Pitch only the neck and head; leave the upright torso and arm anchors untouched.
func _look_at_back(sk: Skeleton3D) -> void:
	var back := lead.find_bone("spineb")
	var head := sk.find_bone("heada")
	var neck := sk.find_bone("neck")
	if back < 0 or head < 0 or neck < 0: return
	var target := sk.global_transform.affine_inverse() * (lead.global_transform * lead.get_bone_global_pose(back).origin)
	if is_instance_valid(lead_motion): target = sk.global_transform.affine_inverse() * lead_motion.back_world
	var direction := target - sk.get_bone_global_pose(head).origin
	var pitch := clampf(atan2(-direction.y, maxf(direction.z, 0.01)) - deg_to_rad(head_raise_degrees), 0.0, deg_to_rad(look_down_max)) * hold
	for bone: int in [neck, head]:
		var pose := sk.get_bone_global_pose(bone)
		var share := 0.3 if bone == neck else 0.7
		sk.set_bone_global_pose(bone, Transform3D(Basis(Vector3.RIGHT, pitch * share) * pose.basis, pose.origin))

## Mirror the complete left arm relative to each side's bind pose. Mirroring
## only the elbow pole retains the source shoulder roll and twists the skin.
func _mirror_left_arm(sk: Skeleton3D, ids: Array) -> void:
	var left := _bones(sk, "l")
	if left.is_empty(): return
	var reflect := Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, 1))
	var left_shoulder := sk.get_bone_global_pose(int(left[0])).origin
	var right_shoulder := sk.get_bone_global_pose(int(ids[0])).origin
	var poses: Array[Transform3D] = []
	for i in 3:
		var source := sk.get_bone_global_pose(int(left[i]))
		var left_rest := sk.get_bone_global_rest(int(left[i])).basis.orthonormalized()
		var right_rest := sk.get_bone_global_rest(int(ids[i])).basis.orthonormalized()
		var rotation := reflect * source.basis * left_rest.inverse() * reflect * right_rest
		var position := right_shoulder + reflect * (source.origin - left_shoulder)
		var current := sk.get_bone_global_pose(int(ids[i]))
		poses.append(current.interpolate_with(Transform3D(rotation, position), hold))
	for i in 3: sk.set_bone_global_pose(int(ids[i]), poses[i])

## A small upper-body adjustment maintains contact through a larger independent
## puppy wave. The partner's pelvis, knees, and feet retain their own pose.
func _fit_support_reach(sk: Skeleton3D) -> void:
	var spine := sk.find_bone("spinea")
	if spine < 0: return
	var pose := sk.get_bone_global_pose(spine)
	var best := 0.0
	var best_gap := INF
	# Measure the actual descendant poses, including the imported rig's basis.
	for step in 97:
		for sign in [-1.0, 1.0]:
			var angle: float = deg_to_rad(step * 0.25) * sign
			sk.set_bone_global_pose(spine, Transform3D(Basis(Vector3.RIGHT, angle) * pose.basis, pose.origin))
			var gap := 0.0
			for side: String in ["l", "r"]:
				var ids := _bones(sk, side)
				var sh := sk.get_bone_global_pose(int(ids[0])).origin
				var el := sk.get_bone_global_pose(int(ids[1])).origin
				var wr := sk.get_bone_global_pose(int(ids[2])).origin
				var palm := sk.get_bone_global_pose(int(ids[3])).origin
				var reach := (sh.distance_to(el) + el.distance_to(wr)) * MAX_REACH + wr.distance_to(palm)
				var offset := Vector3(hip_half_width if side == "l" else -hip_half_width, grip_height, grip_back)
				var target: Vector3 = sk.global_transform.affine_inverse() * (lead_motion.pelvis_world.origin + lead.global_basis * offset)
				gap = maxf(gap, sh.distance_to(target) - reach + 0.001)
			if gap < best_gap:
				best_gap = gap
				best = angle
			if gap <= 0.0: break
		if best_gap <= 0.0: break
	reach_lean = rad_to_deg(best)
	sk.set_bone_global_pose(spine, Transform3D(Basis(Vector3.RIGHT, best) * pose.basis, pose.origin))

## Solve both joint positions explicitly; the grip stays accurate after the
## spine reach adjustment and the mirrored right arm's bind-pose correction.
func _solve_support(sk: Skeleton3D, ids: Array, target: Vector3) -> void:
	var sh: int = ids[0]
	var el: int = ids[1]
	var wr: int = ids[2]
	var palm: int = ids[3]
	var shoulder := sk.get_bone_global_pose(sh)
	var elbow := sk.get_bone_global_pose(el)
	var wrist := sk.get_bone_global_pose(wr)
	var end := wrist.origin + (target - sk.get_bone_global_pose(palm).origin) * hold
	var upper := shoulder.origin.distance_to(elbow.origin)
	var lower := elbow.origin.distance_to(wrist.origin)
	var distance := clampf(shoulder.origin.distance_to(end), absf(upper - lower) + 0.0001, (upper + lower) * MAX_REACH)
	var direction := (end - shoulder.origin).normalized()
	end = shoulder.origin + direction * distance
	var pole := elbow.origin - shoulder.origin
	pole = (pole - direction * pole.dot(direction)).normalized()
	var along := (upper * upper + distance * distance - lower * lower) / (2.0 * distance)
	var middle := shoulder.origin + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	var q := _arc((elbow.origin - shoulder.origin).normalized(), (middle - shoulder.origin).normalized())
	sk.set_bone_global_pose(sh, Transform3D(Basis(q) * shoulder.basis, shoulder.origin))
	q = _arc((wrist.origin - elbow.origin).normalized(), (end - middle).normalized())
	sk.set_bone_global_pose(el, Transform3D(Basis(q) * elbow.basis, middle))
	sk.set_bone_global_pose(wr, Transform3D(wrist.basis, end))
