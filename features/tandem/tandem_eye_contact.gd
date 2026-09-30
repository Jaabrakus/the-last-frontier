extends SkeletonModifier3D
## Aim the neck/head at the other player's eye line after torso and hand modifiers.
@export var turn_head := true
@export_range(0.0, 1.0) var hold := 0.0
@export var maximum_turn_degrees := 95.0
@export_range(1, 12) var solve_iterations := 3
var peer: Skeleton3D
var peer_gaze: Node
var eye_world := Vector3.INF
var face_world := Vector3.FORWARD
var gaze_error := 0.0
var limited := false
func _eye(sk: Skeleton3D, head: int) -> Vector3:
	var rest := sk.get_bone_global_rest(head).basis
	var offset := rest.inverse() * Vector3(0, 0.065, 0.065)
	var pose := sk.get_bone_global_pose(head)
	return sk.global_transform * (pose.origin + pose.basis * offset)
func _forward(sk: Skeleton3D, head: int) -> Vector3:
	var local := sk.get_bone_global_rest(head).basis.inverse() * Vector3(0, 0, 1)
	return (sk.get_bone_global_pose(head).basis * local).normalized()
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or not is_instance_valid(peer): return
	var head := sk.find_bone("heada")
	var neck := sk.find_bone("neck")
	var other_head := peer.find_bone("heada")
	if head < 0 or neck < 0 or other_head < 0: return
	if not turn_head:
		eye_world = _eye(sk, head)
		face_world = (sk.global_basis * _forward(sk, head)).normalized()
		return
	var target := _eye(peer, other_head)
	if is_instance_valid(peer_gaze) and peer_gaze.eye_world != Vector3.INF: target = peer_gaze.eye_world
	var local_target := sk.global_transform.affine_inverse() * target
	var local_eye := sk.global_transform.affine_inverse() * _eye(sk, head)
	var direction := (local_target - local_eye).normalized()
	var original := _forward(sk, head)
	var angle := original.angle_to(direction)
	limited = angle > deg_to_rad(maximum_turn_degrees)
	var weight := hold
	if limited: direction = original.slerp(direction, deg_to_rad(maximum_turn_degrees) / maxf(angle, 0.0001)).normalized()
	var turn := Quaternion(original, direction)
	var pose := sk.get_bone_global_pose(neck)
	sk.set_bone_global_pose(neck, Transform3D(Basis(Quaternion.IDENTITY.slerp(turn, weight * 0.35)) * pose.basis, pose.origin))
	for iteration in solve_iterations:
		local_eye = sk.global_transform.affine_inverse() * _eye(sk, head)
		direction = (local_target - local_eye).normalized()
		if limited:
			var wanted_angle := original.angle_to(direction)
			direction = original.slerp(direction, minf(1.0, deg_to_rad(maximum_turn_degrees) / maxf(wanted_angle, 0.0001))).normalized()
		turn = Quaternion(_forward(sk, head), direction)
		pose = sk.get_bone_global_pose(head)
		sk.set_bone_global_pose(head, Transform3D(Basis(Quaternion.IDENTITY.slerp(turn, weight)) * pose.basis, pose.origin))
	eye_world = _eye(sk, head)
	face_world = (sk.global_basis * _forward(sk, head)).normalized()
	gaze_error = rad_to_deg(face_world.angle_to((target - eye_world).normalized()))
