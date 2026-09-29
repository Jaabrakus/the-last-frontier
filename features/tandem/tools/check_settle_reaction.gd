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
	var wide: Node = load("res://features/tandem/reverse_plank.gd").new()
	wide.player = p
	p.add_child(wide)
	await create_timer(3.0).timeout
	check(wide.start(), "Pose entry failed")
	if not wide.active: quit(1); return
	await create_timer(0.4).timeout
	check(p.kneeling == wide and not p.anim.active, "Competing animation ownership")
	var entry_hands := {}
	for n in ["l_wrist", "r_wrist"]:
		entry_hands[n] = p.skeleton.get_bone_global_pose(p.skeleton.find_bone(n)).origin
	check(wide.ap.current_animation == "reverse_plank/support", "Entry skipped hip-support hold")
	await wide.invite_partner()
	check(is_instance_valid(wide.partner_pose) and wide.partner_pose.active, "Partner failed to enter wide kneel")
	if not is_instance_valid(wide.partner_pose): quit(1); return
	await create_timer(0.6).timeout
	check(wide.ap.current_animation == "reverse_plank/support", "Support hands not active")
	for n in entry_hands:
		check(p.skeleton.get_bone_global_pose(p.skeleton.find_bone(n)).origin.distance_to(entry_hands[n]) < 0.001, "Partner join changed support hand placement")
	var peer: FrontierPlayer = wide.partner
	for n in ["l_knee", "r_knee"]:
		var pos := peer.skeleton.to_global(peer.skeleton.get_bone_global_pose(peer.skeleton.find_bone(n)).origin)
		check(absf(pos.y - 0.055) < 0.05, "Upper knee not grounded")
	for side in ["l", "r"]:
		var heel := p.skeleton.to_global(p.skeleton.get_bone_global_pose(p.skeleton.find_bone(side + "_heel")).origin)
		var toe := p.skeleton.to_global(p.skeleton.get_bone_global_pose(p.skeleton.find_bone(side + "_ball")).origin)
		check((toe - heel).normalized().dot(Vector3.UP) > 0.99, "Toes not upright")
		check(heel.y > 0.015 and heel.y < 0.055, "Heel not grounded")
	var upper_pelvis := peer.skeleton.to_global(peer.skeleton.get_bone_global_pose(peer.skeleton.find_bone("pelvis")).origin)
	var lower_pelvis := p.skeleton.to_global(p.skeleton.get_bone_global_pose(p.skeleton.find_bone("pelvis")).origin)
	check(upper_pelvis.y - lower_pelvis.y > 0.24, "Insufficient body clearance")
	print("SUPPORT pelvis clearance=", upper_pelvis.y - lower_pelvis.y)
	var events: Array[float] = []
	wide.stamina_reacted.connect(func(): events.append(Time.get_ticks_msec() / 1000.0))
	var before: float = wide.stamina
	var lead_before: float = wide.partner_pose.stamina
	var pelvis_rest := peer.skeleton.get_bone_global_pose(peer.skeleton.find_bone("pelvis")).origin.y
	var began := Time.get_ticks_msec() / 1000.0
	check(wide.partner_pose.react("bounce"), "Wide Kneel rejected flinch")
	await create_timer(0.4).timeout
	check(peer.skeleton.get_bone_global_pose(peer.skeleton.find_bone("pelvis")).origin.y > pelvis_rest + 0.008, "Wide Kneel should rise before settling down")
	check(events.is_empty() and wide.ap.current_animation == "reverse_plank/support", "Lower reacted before upper settled")
	await create_timer(0.5).timeout
	check(events.size() == 1, "Missing or duplicate settled reaction")
	if events.size() == 1: check(events[0] - began >= 0.73, "Reaction preceded return-to-idle settling")
	check(wide.stamina <= before - 9.8, "Lower stamina was not drained on its reaction")
	check(wide.partner_pose.stamina < lead_before, "Upper flinch stamina was not drained")
	check(wide.ap.current_animation == "reverse_plank/recoil", "Lower did not play backward stamina recoil")
	await create_timer(1.0).timeout
	check(wide.ap.current_animation == "reverse_plank/support", "Lower failed to return to supported hold")
	var drained: float = wide.stamina
	await create_timer(0.5).timeout
	check(wide.stamina > drained, "Idle stamina did not regenerate")
	events.clear()
	wide.partner_pose.react("wave")
	await create_timer(0.25).timeout
	wide.partner_pose.react("bounce")
	await create_timer(0.5).timeout
	check(events.is_empty(), "Restarted flinch left an early response")
	await create_timer(0.4).timeout
	check(events.size() == 1, "Restarted flinch should settle once")
	events.clear()
	wide.partner_pose.react("bounce")
	await create_timer(0.2).timeout
	wide.stop()
	await create_timer(1.0).timeout
	check(events.is_empty(), "Exited pair left a delayed stamina response")
	check(p.kneeling == null and p.anim.active and p.anim.auto_process, "Movement/animation not restored")
	print("SETTLE_REACTION_CHECK failures=", failures)
	quit(failures)
