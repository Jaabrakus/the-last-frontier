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

	var brace: Node = tandem._crawl_brace
	for kind in ["wave", "sway"]:
		for who in ["both", "crawl", "upright"]:
			check(tandem.play_motion(kind, who), "Crawl motion rejected: " + kind + who)
			if who == "both": check(tandem._crawl_lead_motion.started_ms == tandem._crawl_partner_motion.started_ms, "Crawl clocks differ")
			var miss := 0.0
			var lengths := 0.0
			var ground := 0.0
			var torso_drift := 0.0
			var torso_turn := 0.0
			var support_miss := 0.0
			var leg_ground := 0.0
			var knee_span := 0.0
			var pelvic_travel := 0.0
			var initial_pelvis: Vector3 = tandem._crawl_lead_motion.pelvis_world.origin
			for frame in 120:
				await create_timer(0.02).timeout
				if tandem._crawl_motion_blend > 0.999: miss = maxf(miss, brace.palm_miss)
				var lead_motion: Node = tandem._crawl_lead_motion
				if tandem._crawl_motion_blend > 0.999:
					support_miss = maxf(support_miss, tandem._crawl_inside_hold.palm_miss)
					leg_ground = maxf(leg_ground, lead_motion.ground_height_error)
					knee_span = lead_motion.knee_span
				if kind == "sway" and who != "upright" and lead_motion.moving:
					pelvic_travel = maxf(pelvic_travel, absf(lead_motion.pelvis_world.origin.x - initial_pelvis.x))
					torso_drift = maxf(torso_drift, lead_motion.torso_drift)
					torso_turn = maxf(torso_turn, lead_motion.torso_turn)
				for motion: Node in [tandem._crawl_lead_motion, tandem._crawl_partner_motion]:
					lengths = maxf(lengths, motion.length_error)
					ground = maxf(ground, motion.planted_error)
			check(tandem._arm_lift.lift < 0.001 and tandem._arm_hold.hold < 0.001, "Crawl arm was not released")
			check(brace.hold > 0.999 and brace.lean_degrees >= 34.0, "Partner did not lean into chest brace")
			check(miss < 0.015, "Chest brace lost contact: " + str(miss))
			check(lengths < 0.001, "Crawl wave stretched a bone: " + str(lengths))
			check(leg_ground < 0.003, "Wide crawl knees/feet lost floor contact: " + str(leg_ground))
			check(knee_span > 0.55, "Crawl knees did not use the puppy saddle stance")
			check(tandem._crawl_lead_motion.support_chest_lift > 0.07, "Crawl chest was not lifted")
			check(support_miss < 0.015, "Crawler hands lost floor contact: " + str(support_miss))
			check(tandem._crawl_inside_hold.length_error < 0.001, "Extended arm changed bone length")
			if kind == "sway":
				if who != "upright": check(pelvic_travel > 0.01, "Pelvis did not sway")
				check(torso_drift < 0.001 and torso_turn < 0.005, "Sway moved the crawl torso: " + str(torso_drift) + " turn=" + str(torso_turn))
			check(ground < 0.001, "Crawl wave moved grounded legs")
			print("CRAWL_CHEST_MOTION_CHECK ", kind, " ", who, " miss=", miss, " lean=", brace.lean_degrees, " length_error=", lengths, " torso_drift=", torso_drift, " support_miss=", support_miss, " knee_span=", knee_span, " floor_error=", leg_ground)
	for reaction in ["jolt", "backward"]:
		if reaction == "jolt": tandem.partner_reaction()
		else: tandem.lead_backward()
		var miss := 0.0
		var twist := 0.0
		var hand_jolt := 0.0
		for frame in 100:
			await create_timer(0.02).timeout
			miss = maxf(miss, brace.palm_miss)
			twist = maxf(twist, brace.elbow_twist_error)
			hand_jolt = maxf(hand_jolt, absf(brace.hand_jolt_degrees))
		check(brace.twist_position_error < 0.001, "Elbow correction moved wrist contact")
		check(twist < deg_to_rad(2.0), "Reaction twisted supporting elbow: " + str(rad_to_deg(twist)))
		check(hand_jolt > 1.0, "Hand-only reaction did not play")
		check(tandem._arm_lift.lift < 0.001 and brace.hold > 0.999, "Reaction restored the raised-arm hold")
		check(miss < 0.015, "Chest brace missed during " + reaction + ": " + str(miss))
		print("CRAWL_CHEST_REACTION_CHECK ", reaction, " miss=", miss, " elbow_twist_deg=", rad_to_deg(twist), " hand_jolt_deg=", hand_jolt)
	tandem.play_motion("wave")
	tandem.stop_pose()
	check(not brace.active and tandem._crawl_brace == null, "Chest brace survived exit")
	check(p.kneeling == null and p.anim.active, "Crawl cleanup failed")
	check(partner.kneeling == null and partner.anim.active, "Upright partner cleanup failed")
	print("UPRIGHT_KNEEL_CHECK failures=", failures, " upright_degrees=", upright_angle)
	quit(failures)
