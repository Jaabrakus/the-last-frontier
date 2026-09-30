extends PalmReachIK
## Forward lean and right-hand brace on the crawler's outer upper chest.
@export_range(0.0, 1.0) var hold := 0.0
@export var minimum_lean_degrees := 45.0
@export var maximum_lean_degrees := 70.0
var lead: Skeleton3D
var lead_motion: Node
var palm_miss := 0.0
var lean_degrees := 0.0
var target_world := Vector3.ZERO
var forearm_world := {}
var _neutral_arms := {}
var _hand_jolt_ms := -10000
var hand_jolt_degrees := 0.0
var elbow_twist_error := 0.0
var twist_position_error := 0.0
var grip_miss := {"l": 0.0, "r": 0.0}
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or not is_instance_valid(lead) or hold <= 0.0: return
	# Remove the flinch clip's shoulder/elbow gesture. The chest brace owns
	# these joints; reaction articulation is applied at the wrist below.
	if hold > 0.999 and _neutral_arms.is_empty():
		for side: String in ["l", "r"]:
			for name: String in ["clavicle", "shoulder", "elbow", "wrist"]:
				var i := sk.find_bone(side + "_" + name)
				_neutral_arms[i] = sk.get_bone_pose(i)
	for i: int in _neutral_arms:
		var neutral: Transform3D = _neutral_arms[i]
		sk.set_bone_pose_position(i, neutral.origin)
		sk.set_bone_pose_rotation(i, neutral.basis.get_rotation_quaternion())
		sk.set_bone_pose_scale(i, neutral.basis.get_scale())
	var ids := _bones(sk, "r")
	var spine := sk.find_bone("spinea")
	if ids.is_empty() or spine < 0: return
	var chest := lead.find_bone("spined")
	var chest_pose := lead.global_transform * lead.get_bone_global_pose(chest)
	if is_instance_valid(lead_motion): chest_pose = lead_motion.chest_world
	# Contact the right side of the upper chest, clear of the spine and shoulder joint.
	target_world = chest_pose.origin + lead.global_basis * Vector3(-0.17, -0.055, 0.03)
	var target := sk.global_transform.affine_inverse() * target_world
	var base := sk.get_bone_global_pose(spine)
	var shoulder := sk.get_bone_global_pose(int(ids[0])).origin
	var elbow := sk.get_bone_global_pose(int(ids[1])).origin
	var wrist := sk.get_bone_global_pose(int(ids[2])).origin
	var palm := sk.get_bone_global_pose(int(ids[3])).origin
	var reach := (shoulder.distance_to(elbow) + elbow.distance_to(wrist)) * 0.96 + wrist.distance_to(palm)
	var angle := deg_to_rad(maximum_lean_degrees)
	for degrees in range(int(minimum_lean_degrees), int(maximum_lean_degrees) + 1):
		var candidate := deg_to_rad(float(degrees))
		var at := base.origin + Basis(Vector3.RIGHT, candidate) * (shoulder - base.origin)
		if at.distance_to(target) <= reach:
			angle = candidate
			break
	lean_degrees = rad_to_deg(angle) * hold
	sk.set_bone_global_pose(spine, Transform3D(Basis(Vector3.RIGHT, angle * hold) * base.basis, base.origin))
	palm_miss = 0.0
	for side: String in ["l", "r"]:
		ids = _bones(sk, side)
		if side == "r": _mirror_left_arm(sk, ids)
		target_world = chest_pose.origin + lead.global_basis * Vector3(0.17 if side == "l" else -0.17, -0.055, 0.03)
		target = sk.global_transform.affine_inverse() * target_world
		var gw := sk.get_bone_global_pose(int(ids[2]))
		var gp := sk.get_bone_global_pose(int(ids[3])).origin
		var gs := sk.get_bone_global_pose(int(ids[0])).origin
		var turn := Quaternion.IDENTITY.slerp(_arc((gp - gw.origin).normalized(), (target - gs).normalized()), hold)
		sk.set_bone_global_pose(int(ids[2]), Transform3D(Basis(turn) * gw.basis, gw.origin))
		apply_side(sk, side, target, hold)
		if side == "r":
			_remove_elbow_roll(sk, ids)
			var elapsed := float(Time.get_ticks_msec() - _hand_jolt_ms) / 1000.0
			var u := clampf(elapsed / 0.55, 0.0, 1.0)
			hand_jolt_degrees = 5.0 * sin(u * TAU * 2.0) * pow(sin(u * PI), 2.0)
			gw = sk.get_bone_global_pose(int(ids[2]))
			sk.set_bone_global_pose(int(ids[2]), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(hand_jolt_degrees)) * gw.basis, gw.origin))
		grip_miss[side] = sk.get_bone_global_pose(int(ids[3])).origin.distance_to(target)
		palm_miss = maxf(palm_miss, grip_miss[side])
		var forearm := sk.get_bone_global_pose(int(ids[1])).origin.lerp(sk.get_bone_global_pose(int(ids[2])).origin, 0.6)
		# Publish the inside surface for the crawler's hands to hook around.
		forearm_world[side] = sk.global_transform * forearm + lead.global_basis * Vector3(-0.035 if side == "l" else 0.035, 0, 0)


	var left := _bones(sk, "l")
	var right := _bones(sk, "r")
	var expected := _mirrored_basis(sk, int(left[1]), int(right[1]))
	var actual := sk.get_bone_global_pose(int(right[1]))
	var direction := sk.get_bone_global_pose(int(right[2])).origin - actual.origin
	var local_direction := actual.basis.inverse() * direction
	var aligned := Basis(_arc((expected * local_direction).normalized(), direction.normalized())) * expected
	elbow_twist_error = aligned.get_rotation_quaternion().angle_to(actual.basis.get_rotation_quaternion())

func jolt_hand() -> void:
	_hand_jolt_ms = Time.get_ticks_msec()

func _mirrored_basis(sk: Skeleton3D, left: int, right: int) -> Basis:
	var reflect := Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, 1))
	var chest := sk.find_bone("spined")
	var torso := (sk.get_bone_global_pose(chest).basis * sk.get_bone_global_rest(chest).basis.inverse()).orthonormalized()
	return (torso * reflect * torso.inverse() * sk.get_bone_global_pose(left).basis * sk.get_bone_global_rest(left).basis.inverse() * reflect * sk.get_bone_global_rest(right).basis).orthonormalized()

func _mirror_left_arm(sk: Skeleton3D, right: Array) -> void:
	var l_clavicle := sk.find_bone("l_clavicle")
	var r_clavicle := sk.find_bone("r_clavicle")
	var clavicle := sk.get_bone_global_pose(r_clavicle)
	var mirrored_clavicle := _mirrored_basis(sk, l_clavicle, r_clavicle)
	sk.set_bone_global_pose(r_clavicle, Transform3D(Basis(clavicle.basis.get_rotation_quaternion().slerp(mirrored_clavicle.get_rotation_quaternion(), hold)), clavicle.origin))
	var left := _bones(sk, "l")
	for i in 3:
		var current := sk.get_bone_global_pose(int(right[i]))
		var mirrored := _mirrored_basis(sk, int(left[i]), int(right[i]))
		var rotation := current.basis.get_rotation_quaternion().slerp(mirrored.get_rotation_quaternion(), hold)
		sk.set_bone_global_pose(int(right[i]), Transform3D(Basis(rotation), current.origin))

## Correct axial forearm roll without changing the elbow bend or wrist contact.
func _remove_elbow_roll(sk: Skeleton3D, right: Array) -> void:
	var left := _bones(sk, "l")
	var elbow := sk.get_bone_global_pose(int(right[1]))
	var wrist := sk.get_bone_global_pose(int(right[2]))
	var direction := wrist.origin - elbow.origin
	var local_direction := elbow.basis.inverse() * direction
	var reference := _mirrored_basis(sk, int(left[1]), int(right[1]))
	var aligned := Basis(_arc((reference * local_direction).normalized(), direction.normalized())) * reference
	sk.set_bone_global_pose(int(right[1]), Transform3D(aligned.orthonormalized(), elbow.origin))
	twist_position_error = sk.get_bone_global_pose(int(right[2])).origin.distance_to(wrist.origin)
	sk.set_bone_global_pose(int(right[2]), wrist)
