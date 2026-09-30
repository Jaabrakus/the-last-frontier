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
	await create_timer(3.0).timeout
	check(tandem.start_pose("crawl"), "Crawl entry failed")
	tandem.upright_kneel = true
	check(tandem.invite_partner(), "Upright invitation failed")
	for attempt in 100:
		await create_timer(0.1).timeout
		if tandem.joined: break
	check(tandem.joined, "Upright partner never joined")
	if not tandem.joined: quit(1); return
	await create_timer(1.0).timeout
	var partner: FrontierPlayer = tandem.companion
	var pose: Node = tandem.partner_pose
	check(pose.loop_clip == "idle" and pose.library == &"kneel_upright", "Wrong variant installed")
	var sk := partner.skeleton
	var direction := sk.get_bone_global_pose(sk.find_bone("neck")).origin - sk.get_bone_global_pose(sk.find_bone("spinea")).origin
	var upright_angle := rad_to_deg(direction.angle_to(Vector3.UP))
	check(upright_angle < 3.0, "Torso not upright: " + str(upright_angle))
	var planted := {}
	for side in ["l", "r"]:
		var todo: Array[int] = [sk.find_bone(side + "_knee")]
		while not todo.is_empty():
			var i: int = todo.pop_back()
			planted[i] = sk.get_bone_global_pose(i)
			for child in sk.get_bone_children(i): todo.append(child)
	var stamina: float = pose.stamina
	for kind in ["forward", "backward"]:
		check(pose.flinch() if kind == "forward" else pose.flinch_backward(), "Reaction rejected")
		for frame in 70:
			await create_timer(0.02).timeout
			for i in planted:
				check(sk.get_bone_global_pose(i).origin.distance_to(planted[i].origin) < 0.003, "Lower leg moved: " + sk.get_bone_name(i))
		check(not pose.is_flinching(), "Reaction failed to finish")
	check(pose.stamina < stamina, "Reaction stamina unchanged")
	direction = sk.get_bone_global_pose(sk.find_bone("neck")).origin - sk.get_bone_global_pose(sk.find_bone("spinea")).origin
	check(rad_to_deg(direction.angle_to(Vector3.UP)) < 3.0, "Reaction failed to return upright")
	tandem.stop_pose()
	check(p.kneeling == null and p.anim.active, "Crawl cleanup failed")
	check(partner.kneeling == null and partner.anim.active, "Upright partner cleanup failed")
	print("UPRIGHT_KNEEL_CHECK failures=", failures, " upright_degrees=", upright_angle)
	quit(failures)
