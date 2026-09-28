extends SceneTree
## The grip system (PlayerGrip) in the climbing test scene, headless, the player driven by its input actions:
##   cliff    G at the 6 m rock face grabs it; W crawls up; at the top it pulls up and stands on the top
##   press    standing up there with G still held does not grip again (a fresh press is needed)
##   kneel    kneeling is refused while gripping
##   fail     the grip gives out at zero stamina on still rock: the climber drops off, is not thrown
##   giant    gripping the stand-in giant's back: its small shake stays under the flung-off level, its big shake (after
##            its warning) goes over; held on until the grip gives out, the climber is thrown clear onto the ground
##
##   Godot --headless --path . -s tests/climb/test_grip.gd -- --no-capture
## "GRIP TEST PASSED" and exit 0 when every check passes. Run it under a hard time limit.

var p: FrontierPlayer
var yard: ClimbYard
var failures := PackedStringArray()
var checks := 0


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	p = current_scene.get_node_or_null("Player")
	yard = current_scene.get("yard")
	if p == null or yard == null:
		print("GRIP TEST FAILED (no player or yard)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	yard.giant.paces = false
	await _fr(240)
	await _cliff()
	await _fail_on_rock()
	await _giant()
	if failures.is_empty():
		print("GRIP TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("GRIP TEST FAILED (%d of %d)" % [failures.size(), checks])
		quit(1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _all_up() -> void:
	for a in ["grip", "move_forward", "move_back", "move_left", "move_right", "jump"]:
		Input.action_release(a)


func _stand(station: String) -> void:
	_all_up()
	await _fr(30)
	var st: Dictionary = yard.stations[station]
	p.global_position = (st.stand as Vector3) + Vector3(0.0, 0.1, 0.0)
	p.velocity = Vector3.ZERO
	var to: Vector3 = (st.look as Vector3) - p.global_position
	p.yaw = atan2(-to.x, -to.z)
	p.grip.stamina = p.grip.stamina_max
	await _fr(60)


func _cliff() -> void:
	await _stand("cliff")
	Input.action_press("grip")
	await _fr(24)
	_expect(p.grip.state != PlayerGrip.OFF and p.climbing == p.grip, "cliff: G at the rock face grabs it (state %d)" % p.grip.state)
	_expect(p.begin_kneel(root, p.global_position) == null, "kneel: refused while gripping")
	await _fr(120)
	_expect(p.grip.state == PlayerGrip.HOLD, "cliff: holding on after the catch (state %d)" % p.grip.state)
	var y0 := p.grip.anchor.global_position.y if p.grip.anchor else 0.0
	Input.action_press("move_forward")
	var up := false
	for i in 120 * 16:
		await physics_frame
		if p.grip.state == PlayerGrip.UP:
			up = true
		if up and p.grip.state == PlayerGrip.OFF:
			break
	Input.action_release("move_forward")
	_expect(up, "cliff: crawled up to the top edge and pulled up (from %.2f m)" % y0)
	await _fr(60)
	_expect(p.grip.state == PlayerGrip.OFF and p.is_on_floor() and p.global_position.y > 5.8,
			"cliff: standing on the 6 m top (y %.2f, floor %s)" % [p.global_position.y, p.is_on_floor()])
	# G still held: no grip again
	await _fr(120)
	_expect(p.grip.state == PlayerGrip.OFF, "press: G held from the climb does not grip the top again")
	_all_up()
	await _fr(30)


func _fail_on_rock() -> void:
	await _stand("cliff")
	Input.action_press("grip")
	await _fr(150)
	_expect(p.grip.state == PlayerGrip.HOLD, "fail: holding the rock face")
	p.grip.stamina = 0.5
	var gone: Array[String] = []
	p.grip.released.connect(func(r: String) -> void: gone.append(r), CONNECT_ONE_SHOT)
	await _fr(120)
	_expect(gone == ["stamina"], "fail: the grip gives out at zero stamina (released: %s)" % str(gone))
	_expect(Vector2(p.velocity.x, p.velocity.z).length() < 1.0, "fail: on still rock the climber is not thrown")
	await _fr(120)
	_expect(p.is_on_floor() and p.global_position.y < 0.5, "fail: dropped to the ground (y %.2f)" % p.global_position.y)
	_all_up()
	await _fr(60)


func _giant() -> void:
	var gi: StandInGiant = yard.giant
	_all_up()
	await _fr(30)
	p.global_position = gi.torso.global_position + Vector3(0.3, 1.7, 0.5)
	p.velocity = Vector3.ZERO
	p.grip.stamina = p.grip.stamina_max
	await _fr(90)
	Input.action_press("grip")
	await _fr(60)
	_expect(p.grip.state != PlayerGrip.OFF and p.grip.gripped == gi.torso, "giant: gripping its back")
	var small_max := 0.0
	var big_max := 0.0
	var thrown := false
	for i in 120 * 50:
		await physics_frame
		if gi.shaking:
			var big: bool = bool(gi.SHAKES[gi._shake_i].big)
			if big:
				big_max = maxf(big_max, p.grip.shake_amt)
			else:
				small_max = maxf(small_max, p.grip.shake_amt)
		if p.grip.state == PlayerGrip.OFF:
			thrown = gi.shaking or gi.warning
			break
	_expect(small_max > 0.05 and small_max < p.grip.body_shake_md, "giant: a small shake only jostles (%.2f < %.2f)" % [small_max, p.grip.body_shake_md])
	_expect(big_max > p.grip.body_shake_md, "giant: a big shake flings (%.2f > %.2f)" % [big_max, p.grip.body_shake_md])
	_expect(thrown, "giant: the grip gave out during a shake")
	await _fr(300)
	var d := Vector2(p.global_position.x - gi.torso.global_position.x, p.global_position.z - gi.torso.global_position.z)
	_expect(p.is_on_floor() and p.global_position.y < 0.5 and d.length() > StandInGiant.BODY_R + 0.3,
			"giant: thrown clear onto the ground (y %.2f, %.2f m from its axis)" % [p.global_position.y, d.length()])
	_all_up()
