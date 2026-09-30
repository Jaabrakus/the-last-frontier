extends PalmReachIK
## Match the right thigh's bind-relative roll to the good left thigh without
## changing the planted knee, shin, or foot transforms.
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null: return
	var left := sk.find_bone("l_upper_leg")
	var right := sk.find_bone("r_upper_leg")
	var knee := sk.find_bone("r_knee")
	if left < 0 or right < 0 or knee < 0: return
	var saved := {}
	var todo: Array[int] = [knee]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		saved[i] = sk.get_bone_global_pose(i)
		for child in sk.get_bone_children(i): todo.append(child)
	var reflect := Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, 1))
	var left_rest := sk.get_bone_global_rest(left).basis.orthonormalized()
	var right_rest := sk.get_bone_global_rest(right).basis.orthonormalized()
	var basis := reflect * sk.get_bone_global_pose(left).basis * left_rest.inverse() * reflect * right_rest
	var pose := sk.get_bone_global_pose(right)
	sk.set_bone_global_pose(right, Transform3D(basis, pose.origin))
	var current := sk.get_bone_global_pose(knee).origin - pose.origin
	var wanted: Vector3 = saved[knee].origin - pose.origin
	sk.set_bone_global_pose(right, Transform3D(Basis(_arc(current.normalized(), wanted.normalized())) * basis, pose.origin))
	for i: int in saved: sk.set_bone_global_pose(i, saved[i])
