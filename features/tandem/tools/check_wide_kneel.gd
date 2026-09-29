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
	var wide: Node = load("res://features/tandem/wide_kneel.gd").new()
	wide.player = p
	p.add_child(wide)
	await create_timer(3.0).timeout
	check(wide.start(), "Pose entry failed")
	if not wide.active: quit(1); return
	await create_timer(0.4).timeout
	check(p.kneeling == wide and not p.anim.active, "Competing animation ownership")
	var sk := p.skeleton
	var fixed := {}
	for n in ["l_knee", "r_knee", "l_ankle", "r_ankle"]:
		fixed[n] = sk.get_bone_global_pose(sk.find_bone(n)).origin
	var initial := sk.get_bone_global_pose(sk.find_bone("pelvis"))
	var max_drop := 0.0
	var max_angle := 0.0
	for kind in ["bounce", "wave"]:
		wide.react(kind)
		for i in 45:
			await create_timer(0.025).timeout
			for n in fixed:
				check(sk.get_bone_global_pose(sk.find_bone(n)).origin.distance_to(fixed[n]) < 0.003, "Ground contact drift " + n)
			var pelvis := sk.get_bone_global_pose(sk.find_bone("pelvis"))
			max_drop = maxf(max_drop, initial.origin.y - pelvis.origin.y)
			max_angle = maxf(max_angle, initial.basis.get_rotation_quaternion().angle_to(pelvis.basis.get_rotation_quaternion()))
		check(wide.ap.current_animation == "wide_kneel/idle", "Reaction failed to return to idle")
	check(max_drop > 0.02, "Bounce did not move pelvis")
	check(max_angle > 0.03, "Wave did not tilt pelvis")
	wide.react("bounce")
	await create_timer(0.15).timeout
	wide.react("wave")
	check(wide.ap.current_animation == "wide_kneel/wave", "Repeated input locked")
	wide.stop()
	check(p.kneeling == null and p.anim.active and p.anim.auto_process, "Movement/animation not restored")
	print("WIDE_KNEEL_CHECK failures=", failures, " pelvis_drop=", max_drop, " wave_radians=", max_angle)
	quit(failures)
