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
	var pair: Node = load("res://features/tandem/reverse_plank.gd").new()
	pair.player = p
	p.add_child(pair)
	await create_timer(3.0).timeout
	check(pair.start(), "Reverse pair entry failed")
	await pair.invite_partner()
	check(is_instance_valid(pair.partner_pose) and pair.partner_pose.active, "Wide partner entry failed")
	if not is_instance_valid(pair.partner_pose) or not is_instance_valid(pair.alignment): quit(1); return
	await create_timer(0.8).timeout
	await create_timer(0.8).timeout
	check(pair.torso_anchor.chest_world.origin.y < 0.35, "Lower torso lost its lying idle pose")
	var initial_eye: Vector3 = pair.lower_gaze.eye_world
	var initial_face: Vector3 = pair.lower_gaze.face_world
	for kind in ["idle", "wave", "sway"]:
		if kind != "idle": pair.play_motion(kind)
		var error := 0.0
		for frame in 100:
			await create_timer(0.02).timeout
			var direction: Vector3 = (pair.upper_gaze.eye_world - pair.lower_gaze.eye_world).normalized()
			check(pair.lower_gaze.eye_world.distance_to(initial_eye) < 0.001 and pair.lower_gaze.face_world.angle_to(initial_face) < 0.001, "Reverse head moved")
			error = maxf(error, rad_to_deg(pair.upper_gaze.face_world.angle_to(-direction)))
		check(error < 3.0, "Eye line missed: " + str(error))
		print("EYE_CONTACT ", kind, " error_degrees=", error)
	pair.stop()
	check(pair.lower_gaze == null and pair.upper_gaze == null and p.kneeling == null, "Eye contact cleanup failed")
	print("EYE_CONTACT_CHECK failures=", failures)
	quit(failures)
