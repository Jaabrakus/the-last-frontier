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
	var puppy: Node = load("res://features/tandem/puppy_pose.gd").new()
	puppy.player = p
	p.add_child(puppy)
	var pair: Node = load("res://features/tandem/puppy_tandem.gd").new()
	pair.player = p
	pair.puppy = puppy
	p.add_child(pair)
	await create_timer(3.0).timeout
	check(puppy.start(), "Puppy entry failed")
	check(await pair.invite_partner(), "Puppy upright pair invitation failed")
	if not pair.joined: quit(1); return
	await create_timer(0.5).timeout
	var partner: FrontierPlayer = pair.partner
	var partner_pose: Node = pair.partner_pose
	var planted := {}
	for actor: FrontierPlayer in [p, partner]:
		var sk := actor.skeleton
		var bones := {}
		for side in ["l", "r"]:
			var todo: Array[int] = [sk.find_bone(side + "_knee")]
			while not todo.is_empty():
				var i: int = todo.pop_back()
				bones[i] = sk.get_bone_global_pose(i)
				for child in sk.get_bone_children(i): todo.append(child)
		planted[actor] = bones
	var up := partner.skeleton.get_bone_global_pose(partner.skeleton.find_bone("neck")).origin - partner.skeleton.get_bone_global_pose(partner.skeleton.find_bone("spinea")).origin
	check(rad_to_deg(up.angle_to(Vector3.UP)) < 3.0, "Partner torso not upright")
	var initial := p.skeleton.get_bone_global_pose(p.skeleton.find_bone("pelvis")).origin
	var support: Node = pair.support
	var max_miss := 0.0
	var cost_before: float = partner_pose.stamina
	check(pair.react(), "Pair reaction rejected")
	await create_timer(0.07).timeout
	check(puppy.ap.current_animation == "puppy/idle", "Puppy reaction started too early")
	var peak := 0.0
	for frame in 75:
		await create_timer(0.02).timeout
		for side in ["l", "r"]: max_miss = maxf(max_miss, support.palm_miss[side])
		peak = maxf(peak, p.skeleton.get_bone_global_pose(p.skeleton.find_bone("pelvis")).origin.z - initial.z)
		for actor: FrontierPlayer in planted:
			for i in planted[actor]:
				check(actor.skeleton.get_bone_global_pose(i).origin.distance_to(planted[actor][i].origin) < 0.003, "Lower leg moved in pair: " + actor.skeleton.get_bone_name(i))
	check(max_miss < 0.015, "Hip support hands missed target: " + str(max_miss))
	check(peak > 0.04, "Puppy did not respond forward")
	check(puppy.ap.current_animation == "puppy/idle" and not partner_pose.is_flinching(), "Pair did not return to idle")
	check(partner_pose.stamina < cost_before, "Partner flinch did not use stamina")
	for kind in ["wave", "sway"]:
		for who in ["both", "puppy", "upright"]:
			check(pair.play_motion(kind, who), "Motion rejected: " + kind + who)
			if who == "both": check(puppy.motion.started_ms == pair.motion.started_ms, "Pair clocks differ")
			check(puppy.motion.moving == (who != "upright") and pair.motion.moving == (who != "puppy"), "Independent motion changed the other player")
			var motion_miss := 0.0
			var max_length_error := 0.0
			var max_ground_error := 0.0
			var traveled := 0.0
			var puppy_hand_miss := 0.0
			var elbow_lift := 0.0
			var hand_slide := 0.0
			var chest_drift := 0.0
			var initial_motion: Vector3 = puppy.motion.pelvis_world.origin if who != "upright" else pair.motion.pelvis_world.origin
			for frame in 95:
				await create_timer(0.02).timeout
				puppy_hand_miss = maxf(puppy_hand_miss, puppy.motion.palm_miss)
				chest_drift = maxf(chest_drift, puppy.motion.chest_drift)
				hand_slide = maxf(hand_slide, puppy.motion.hand_slide)
				elbow_lift = maxf(elbow_lift, puppy.motion.elbow_lift)
				for modifier: Node in [puppy.motion, pair.motion]:
					max_length_error = maxf(max_length_error, modifier.length_error)
					max_ground_error = maxf(max_ground_error, modifier.planted_error)
				for side in ["l", "r"]: motion_miss = maxf(motion_miss, support.palm_miss[side])
				var position: Vector3 = puppy.motion.pelvis_world.origin if who != "upright" else pair.motion.pelvis_world.origin
				traveled = maxf(traveled, position.distance_to(initial_motion))
			check(chest_drift < 0.015, "Puppy torso moved too much: " + str(chest_drift))
			check(hand_slide < 0.08, "Puppy hand glide too large: " + str(hand_slide))
			check(puppy_hand_miss < 0.01, "Puppy palm lifted from ground: " + str(puppy_hand_miss))
			check(elbow_lift < 0.001, "Puppy planted elbow missed its anchor: " + str(elbow_lift))
			check(traveled > 0.015, "Motion too small: " + kind + who)
			check(max_length_error < 0.001, "Motion stretched a bone: " + str(max_length_error))
			check(max_ground_error < 0.001, "Motion moved a grounded lower leg")
			check(motion_miss < 0.015, "Motion lost hip contact: " + str(motion_miss))
			check(not puppy.motion.moving and not pair.motion.moving, "Motion did not settle")
			print("YOGA_MOTION_CHECK ", kind, " ", who, " travel=", traveled, " length_error=", max_length_error, " grip_miss=", motion_miss, " puppy_hand_miss=", puppy_hand_miss, " elbow_lift=", elbow_lift, " hand_slide=", hand_slide, " chest_drift=", chest_drift)
	check(pair.react(), "Repeat pair reaction rejected")
	puppy.stop()
	check(not support.active and pair.support == null, "Support modifier survived exit")
	check(not pair.joined and pair.partner == null and pair._responses.is_empty(), "Exit left a partner or pending reaction")
	check(p.kneeling == null and p.anim.active, "Lead cleanup failed")
	check(partner.kneeling == null and partner.anim.active, "Partner cleanup failed")
	await create_timer(0.3).timeout
	check(not puppy.active, "Cancelled reaction restarted pose")
	print("PUPPY_UPRIGHT_PAIR_CHECK failures=", failures, " peak_forward=", peak, " palm_miss=", max_miss)
	quit(failures)
