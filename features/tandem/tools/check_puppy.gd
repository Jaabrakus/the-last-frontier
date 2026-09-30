extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		push_error(msg)
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 0.2, 20)
	collision.shape = shape
	floor.add_child(collision)
	world.add_child(floor)
	floor.position.y = -0.1
	var p := FrontierPlayer.new()
	p.is_local = false
	p.controls = PlayerControls.new(false)
	p.use_appearance = false
	p.show_gear = false
	p.demo_horse = false
	p.demo_wheelbarrow = false
	world.add_child(p)
	p.position.y = 0.1
	var tandem: Node = load("res://features/tandem/frontier_tandem.gd").new()
	tandem.player = p
	p.add_child(tandem)
	var wide: Node = load("res://features/tandem/puppy_pose.gd").new()
	wide.player = p
	p.add_child(wide)
	await create_timer(3.0).timeout
	check(wide.start(), "Pose entry failed")
	if not wide.active: quit(1); return
	await create_timer(0.4).timeout
	check(p.kneeling == wide and not p.anim.active, "Competing animation ownership")
	var sk := p.skeleton
	for side in ["l", "r"]:
		var wrist := sk.get_bone_global_pose(sk.find_bone(side + "_wrist")).origin
		var shoulder := sk.get_bone_global_pose(sk.find_bone(side + "_shoulder")).origin
		check(absf(wrist.y - 0.05) < 0.003, "Wrist not grounded")
		var elbow := sk.get_bone_global_pose(sk.find_bone(side + "_elbow")).origin
		check(absf(elbow.y - 0.04) < 0.003, "Elbow not grounded")
		var angle := rad_to_deg((shoulder - elbow).angle_to(wrist - elbow))
		check(angle > 80.0 and angle < 110.0, "Arm not L-shaped: " + str(angle))
		check(wrist.z - elbow.z > 0.2, "Forearm not reaching forward")
	var left_knee := sk.get_bone_global_pose(sk.find_bone("l_knee")).origin
	var right_knee := sk.get_bone_global_pose(sk.find_bone("r_knee")).origin
	check(left_knee.x - right_knee.x > 0.55, "Knees not spread into saddle stance")
	check(absf(left_knee.y - 0.051665) < 0.003 and absf(right_knee.y - 0.051665) < 0.003, "Knees not grounded")
	for side in ["l", "r"]:
		var knee := sk.get_bone_global_pose(sk.find_bone(side + "_knee")).origin
		var ankle := sk.get_bone_global_pose(sk.find_bone(side + "_ankle")).origin
		var ball := sk.get_bone_global_pose(sk.find_bone(side + "_ball")).origin
		check(absf(ankle.x) - absf(knee.x) > 0.12, "Shins not flared outward")
		check(absf(ankle.y - 0.065) < 0.003 and absf(ball.y - 0.04) < 0.003, "Relaxed feet not grounded")
	var planted := {}
	for side in ["l", "r"]:
		var todo: Array[int] = [sk.find_bone(side + "_knee"), sk.find_bone(side + "_elbow")]
		while not todo.is_empty():
			var i: int = todo.pop_back()
			planted[i] = sk.get_bone_global_pose(i)
			for child in sk.get_bone_children(i): todo.append(child)
	var initial_hip := sk.get_bone_global_pose(sk.find_bone("pelvis")).origin
	var initial_body := p.global_position
	var peak_forward := 0.0
	var max_contact_error := 0.0
	var max_contact_rotation := 0.0
	wide.flinch()
	for frame in 35:
		await create_timer(0.02).timeout
		peak_forward = maxf(peak_forward, sk.get_bone_global_pose(sk.find_bone("pelvis")).origin.z - initial_hip.z)
		for i in planted:
			var at := sk.get_bone_global_pose(i)
			max_contact_error = maxf(max_contact_error, at.origin.distance_to(planted[i].origin))
			check(at.origin.distance_to(planted[i].origin) < 0.003, "Planted contact moved: " + sk.get_bone_name(i))
			max_contact_rotation = maxf(max_contact_rotation, at.basis.get_rotation_quaternion().angle_to(planted[i].basis.get_rotation_quaternion()))
			check(at.basis.get_rotation_quaternion().angle_to(planted[i].basis.get_rotation_quaternion()) < 0.015, "Planted contact rotated: " + sk.get_bone_name(i))
	check(peak_forward > 0.04, "Upper body did not flinch forward")
	check(wide.ap.current_animation == "puppy/idle", "Flinch did not return to idle")
	check(sk.get_bone_global_pose(sk.find_bone("pelvis")).origin.distance_to(initial_hip) < 0.001, "Flinch failed to settle")
	check(Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(initial_body.x, initial_body.z)) < 0.001, "Flinch moved collision body")
	wide.flinch()
	await create_timer(0.15).timeout
	wide.flinch()
	check(wide.ap.current_animation == "puppy/flinch" and wide.ap.current_animation_position < 0.01, "Flinch repeat locked")
	print("PUPPY_FLINCH peak_forward=", peak_forward, " planted_bones=", planted.size(), " contact_error=", max_contact_error, " contact_rotation=", max_contact_rotation)
	wide.stop()
	check(p.kneeling == null and p.anim.active and p.anim.auto_process, "Movement/animation not restored")
	check(wide.start(), "Reentry failed")
	p.health -= 1
	await process_frame
	await process_frame
	check(not wide.active and p.kneeling == null, "Damage failed to release pose")
	print("PUPPY_CHECK failures=", failures)
	quit(failures)
