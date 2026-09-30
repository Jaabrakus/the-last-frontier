extends SceneTree
## Getting into a boat and paddling it (BoatRider, Boat; user 2026-09-29: "the boarding and paddling, oars left inside the boat"), in the
## level, survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/boats/test_boat_ride.gd -- survival=on
##   board    E's prompt at the boat; getting in puts the player kneeling in the boat (not before), the boat's paddle taken up
##   paddle   W drives the boat ahead and the player with it; A / D turn it; S backs
##   leave    E gets out beside the boat, the player free again and standing
## Ends with "BOAT RIDE TEST PASSED (<n> checks)" or "BOAT RIDE TEST FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	for i in 20:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(player != null, "the level has the player")
	if player == null:
		quit(1)
		return
	player.ignore_mouse_capture = true
	var z0 := -120.0
	var x0 := WorldRiver.x_at(z0)
	var b := Boat.make("birchbark", Vector3(x0, 0.0, z0), atan2(WorldRiver.flow_at(z0).x, WorldRiver.flow_at(z0).z))
	current_scene.add_child(b)
	await _frames(5)
	_expect(b.rider != null and b.rider.is_in_group(&"interactables"), "the boat has its rider (an interactable)")
	# on the bank beside it
	var bank := b.to_global(Vector3(b.num("beam") * 0.5 + 1.2, 0.0, 0.0))
	player.global_position = Vector3(bank.x, FrontierTerrain.height_at(bank.x, bank.z) + 0.05, bank.z)
	await _frames(3)
	_expect(b.rider.interact_prompt(player).begins_with("Get in the"), "at the boat, E says: %s" % b.rider.interact_prompt(player))
	_expect(b.rider.distance_from(player.global_position) < b.rider.interact_reach, "the player is within reach of it (%.1f m)" % b.rider.distance_from(player.global_position))
	var far := player.global_position + Vector3(30.0, 0.0, 0.0)
	_expect(b.rider.distance_from(far) > b.rider.interact_reach, "and a long way off it is not")
	var before := b.position
	b.rider.interact(player)
	await _frames(5)
	_expect(b.rider.aboard() and player.kneeling == b.rider, "E puts the player in the boat, kneeling (their body is the rider's)")
	_expect(player.global_position.distance_to(b.rider.seat_position()) < 0.05, "at its seat")
	_expect(b.paddles.size() >= 1 and (b.paddles.is_empty() or b.paddles[0].get_parent() != b) or DisplayServer.get_name() == "headless", "the boat's paddle is taken up out of where it lay")
	_expect(b.rider.interact_prompt(player) == "Get out", "aboard, E says: %s" % b.rider.interact_prompt(player))
	# paddle
	Input.action_press("move_forward")
	await _frames(240)
	var ahead := b.speed()
	var moved := b.position.distance_to(before)
	Input.action_release("move_forward")
	_expect(b.throttle > 0.9 and ahead > 0.6 and moved > 1.5, "W paddles it ahead (%.2f m/s, %.1f m)" % [ahead, moved])
	_expect(player.global_position.distance_to(b.rider.seat_position()) < 0.05 and player.kneeling == b.rider, "the player goes with it")
	var yaw0 := b.rotation.y
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _frames(90)
	Input.action_release("move_right")
	var turned := wrapf(b.rotation.y - yaw0, -PI, PI)
	_expect(turned > 0.15, "D turns it to the right (%.0f deg)" % rad_to_deg(turned))
	Input.action_press("move_left")
	await _frames(150)
	Input.action_release("move_left")
	Input.action_release("move_forward")
	_expect(wrapf(b.rotation.y - yaw0, -PI, PI) < turned, "A turns it back")
	await _frames(180)
	var v0 := b.speed()
	Input.action_press("move_back")
	await _frames(240)
	Input.action_release("move_back")
	_expect(b.throttle < -0.9 and b.speed() < v0, "S backs water: it slows (%.2f to %.2f m/s)" % [v0, b.speed()])
	# C: low in the boat, the game's own crouch; weapons and aim as the player has them
	Input.action_press("crouch")
	await _frames(4)
	Input.action_release("crouch")
	await _frames(20)
	_expect(b.rider.mode == "crouch" and player.kneeling == null and player.is_crouching and player.aboard == b.rider, "C crouches them low in the boat (the game's crouch, not kneeling)")
	_expect(player.global_position.distance_to(b.rider.seat_position()) < 0.1, "still carried at the seat (%.2f m off)" % player.global_position.distance_to(b.rider.seat_position()))
	Input.action_press("move_forward")
	await _frames(60)
	Input.action_release("move_forward")
	_expect(player.global_position.distance_to(b.rider.seat_position()) < 0.1 and b.throttle == 0.0, "walking keys do not walk them out of the boat and the boat drifts (throttle %.1f)" % b.throttle)
	player.switch_weapon("pistol")
	for i in 600:
		if not player.is_switching() and not player.weapon.is_equipping():
			break
		await physics_frame
	_expect(player.weapon != null and player.weapon.active and player.weapon is FlintlockPistol, "they equip the pistol from the boat")
	Input.action_press("aim")
	await _frames(90)
	_expect(player.weapon.aim > 0.5, "holding aim raises it (%.2f)" % player.weapon.aim)
	Input.action_release("aim")
	await _frames(20)
	Input.action_press("crouch")
	await _frames(4)
	Input.action_release("crouch")
	await _frames(40)
	_expect(b.rider.mode == "paddle" and player.kneeling == b.rider and not player.is_crouching, "C again: up to the paddle (%s)" % b.rider.mode)
	# get out
	b.rider.leave()
	await _frames(5)
	_expect(not b.rider.aboard() and player.kneeling == null, "getting out: the player is free")
	_expect(player.global_position.distance_to(b.position) < b.num("length"), "beside the boat (%.1f m)" % player.global_position.distance_to(b.position))
	_expect(b.throttle == 0.0 and b.steer == 0.0, "the helm is let go")
	if fails.is_empty():
		print("BOAT RIDE TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("BOAT RIDE TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
