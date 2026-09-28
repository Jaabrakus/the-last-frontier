extends SceneTree
## Weapons while hanging from a grip (user 2026-09-27: "for hanging i think being able to shoot pistols throw axes and
## spears should be okay"), headless, the climbing test scene's 6 m cliff, the player driven by its input actions:
##   pistol    on the grip RMB plays the one-hand draw from the hang (hang_atk_start: the left hand holding) with the
##             pistol out in the right, the arm on the crosshair, the camera in over the shoulder; a camera turned round behind the climber comes back
##             in front (user: "should only work in front of the user like on a tree"); LMB fires a ball toward the
##             crosshair; RMB let go: both hands on again, the pistol back on the body
##   switch    a weapon key on the grip only picks the weapon (none drawn into the holding hands)
##   tomahawk  RMB, LMB throws it toward the crosshair
##   musket    a long gun does not come out on the grip
##   stamina   hanging one-handed costs more than by both hands
##
##   Godot --headless --path . -s tests/climb/test_hang_aim.gd -- --no-capture
## "HANG AIM TEST PASSED" and exit 0 when every check passes. Run it under a hard time limit.

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
		print("HANG AIM TEST FAILED (no player or yard)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	await _fr(240)
	await _run()
	if failures.is_empty():
		print("HANG AIM TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("HANG AIM TEST FAILED (%d of %d)" % [failures.size(), checks])
		quit(1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _count(cls: String) -> int:
	return current_scene.find_children("*", cls, true, false).size()


func _run() -> void:
	# the pistol out on the ground, then up the cliff a little
	p.switch_weapon("pistol")
	await _fr(240)
	var st: Dictionary = yard.stations["cliff"]
	p.global_position = (st.stand as Vector3) + Vector3(0.0, 0.1, 0.0)
	p.velocity = Vector3.ZERO
	var to: Vector3 = (st.look as Vector3) - p.global_position
	p.yaw = atan2(-to.x, -to.z)
	p.pitch = 0.0
	await _fr(60)
	Input.action_press("grip")
	await _fr(150)
	var g := p.grip
	Input.action_press("move_forward")
	await _fr(120)
	Input.action_release("move_forward")
	await _fr(90)
	_expect(g.state == PlayerGrip.HOLD and p.weapon_key == "pistol" and not p.weapon.active, "hold: on the cliff, the pistol on the body")
	# turn the camera away from the rock to aim out over the yard
	p.yaw += PI
	await _fr(10)
	var s0 := g.stamina
	Input.action_press("aim")
	await _fr(90)
	_expect(g.hang_aim and g._clip == "hang_atk_start" and p.weapon.active and p.weapon.aim > 0.5,
			"pistol: RMB, the one-hand draw from the hang (hang_atk_start), the pistol out and aimed (hang_aim %s, clip %s, aim %.2f)" % [g.hang_aim, g._clip, p.weapon.aim])
	var face := -g.anchor.global_basis.y
	face.y = 0.0
	var look := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
	var off := rad_to_deg(absf(face.normalized().signed_angle_to(look, Vector3.UP)))
	_expect(off <= rad_to_deg(PlayerGrip.HANG_AIM_YAW) + 3.0, "pistol: the aim comes back in front of the climber (%.0f deg off the way they face)" % off)
	_expect(p.spring_arm.spring_length < 1.8, "pistol: the camera in over the shoulder (%.2f m)" % p.spring_arm.spring_length)
	_expect(g.aim_arm.influence > 0.5, "pistol: the right arm on the crosshair (influence %.2f)" % g.aim_arm.influence)
	var balls := _count("Projectile")
	var aim_pt := p.get_aim_point()
	Input.action_press("fire")
	await _fr(8)
	Input.action_release("fire")
	await _fr(20)
	var shot: Projectile = null
	for n in current_scene.find_children("*", "Projectile", true, false):
		shot = n as Projectile
	_expect(_count("Projectile") > balls and shot != null, "pistol: LMB fires (projectiles %d -> %d)" % [balls, _count("Projectile")])
	if shot:
		var to_aim := (aim_pt - p.weapon.muzzle.global_position).normalized()
		_expect(shot.velocity.normalized().dot(to_aim) > 0.95, "pistol: the ball goes toward the crosshair (%.3f)" % shot.velocity.normalized().dot(to_aim))
	_expect(g.state == PlayerGrip.HOLD, "pistol: still holding on after the shot")
	Input.action_release("aim")
	await _fr(180)
	_expect(not g.hang_aim and not p.weapon.active and g.state == PlayerGrip.HOLD and p.spring_arm.spring_length > 3.0,
			"pistol: RMB let go, both hands on, the pistol back on the body, the camera back (%.2f m)" % p.spring_arm.spring_length)
	_expect(s0 - g.stamina > 2.0 * 3.0 * 0.5, "stamina: one-handed costs more (%.1f in 3 s)" % (s0 - g.stamina))
	# a long gun does not come out
	p.switch_weapon("musket")
	await _fr(10)
	_expect(p.weapon_key == "musket" and not p.weapon.active and p.climbing == g, "switch: a weapon key on the grip only picks the weapon")
	Input.action_press("aim")
	await _fr(60)
	_expect(not g.hang_aim and not p.weapon.active, "musket: a long gun does not come out on the grip")
	Input.action_release("aim")
	await _fr(30)
	# the tomahawk
	if p.weapons.has("tomahawk") and p.is_usable("tomahawk"):
		p.switch_weapon("tomahawk")
		await _fr(10)
		var thrown := _count("ThrownProjectile")
		Input.action_press("aim")
		await _fr(90)
		_expect(g.hang_aim and p.weapon.active, "tomahawk: RMB, out in the right hand")
		Input.action_press("fire")
		var wound := false
		for i in 30:
			await physics_frame
			wound = wound or g._clip.begins_with("hang_atk_tame")
		Input.action_release("fire")
		var struck := false
		for i in 150:
			await physics_frame
			struck = struck or g._clip == "hang_atk_drop" or g._clip == "hang_atk_a"
		_expect(wound and struck, "tomahawk: wound up as the charged stab, thrown with its strike (%s, %s)" % [wound, struck])
		_expect(_count("ThrownProjectile") > thrown, "tomahawk: LMB throws it (%d -> %d)" % [thrown, _count("ThrownProjectile")])
		Input.action_release("aim")
		await _fr(150)
		_expect(not g.hang_aim and g.state == PlayerGrip.HOLD, "tomahawk: hanging by both hands again after the throw")
	else:
		_expect(false, "tomahawk: in the loadout")
	Input.action_release("grip")
	await _fr(60)
