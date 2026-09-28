extends SceneTree
## The woolly mammoth's weak points (user 2026-09-27: "we need weak point animations if they shoot the behind the leg it
## falls on one knee"), on the climbing yard (StandInGiant), headless:
##
##   Godot --headless --path . -s tests/climb/test_mammoth_knee.gd -- --no-capture
##
##   zones     a weak point behind each knee, on the hit layer; a ray from the leg's rear quarter meets it first
##   hide      a ball into the body does nothing
##   front     a musket ball behind the front left knee: it goes down on that knee (the knee on the ground, the front
##             lower, the other three feet where they stood); down it neither paces nor shakes; after DOWN_S it rises
##             and stands where it stood
##   quake     as the knee strikes the ground the view shakes for a player about (and settles); not for one far off
##   rider     a climber gripping its back goes down with it and keeps the grip
##   hind      a hit behind the right hind knee: down on that hock, the rump sunk
## Ends with "MAMMOTH KNEE TEST PASSED (<n> checks)" or "MAMMOTH KNEE TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var gi: StandInGiant


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	gi = (current_scene.get("yard") as ClimbYard).giant
	gi.paces = false
	await _fr(60)
	_zones()
	await _hide()
	await _front()
	await _rider()
	await _hind()
	if fails.is_empty():
		print("MAMMOTH KNEE TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("MAMMOTH KNEE TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _bone(nm: String) -> Vector3:
	var sk := gi.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(nm)).origin


## A bone's place in the mammoth's own frame (Body: its sway taken out).
func _bone_local(nm: String) -> Vector3:
	return gi.body.global_transform.affine_inverse() * _bone(nm)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _back() -> Vector3:
	return gi.body.global_basis.z.normalized()


## Behind leg `i` and out to its side, 45 degrees (a shot from straight behind a front leg meets the hind one first).
func _rear_quarter(i: int) -> Vector3:
	var x := gi.body.global_basis.x.normalized()
	var out := x if (gi.legs[i].global_position - gi.body.global_position).dot(x) > 0.0 else -x
	return (_back() + out).normalized()


## A musket ball from `from` at `at`.
func _shoot(from: Vector3, at: Vector3) -> void:
	var b := Projectile.new()
	b.kind = Projectile.Kind.BALL
	b.velocity = (at - from).normalized() * 300.0
	b.gravity = 0.0
	b.damage = 110.0
	current_scene.add_child(b)
	b.global_position = from
	await _fr(8)


func _zones() -> void:
	_expect(gi.weak.size() == 4, "a weak point behind each of the four knees (%d)" % gi.weak.size())
	var ok := true
	var reach := true
	for i in gi.weak.size():
		var z := gi.weak[i]
		ok = ok and z.collision_layer == WildAnimal.HIT_LAYER and String(z.get_meta("hit_part", "")) == "knee_" + String(StandInGiant.LEG_NAMES[i])
		var leg_mid := gi.legs[i].global_position
		ok = ok and (z.global_position - leg_mid).dot(_back()) > 0.2
		var from := z.global_position + _rear_quarter(i) * 3.0 + Vector3.UP * 0.1
		var q := PhysicsRayQueryParameters3D.create(from, z.global_position)
		q.collision_mask = 0xFFFFFFFF
		var r := root.world_3d.direct_space_state.intersect_ray(q)
		reach = reach and not r.is_empty() and r.collider == z
	_expect(ok, "zones: on the hit layer, named for their legs, behind the legs")
	_expect(reach, "zones: a shot from behind a leg (its rear quarter) meets its weak point first")


func _hide() -> void:
	var c := gi.torso.global_position
	await _shoot(c + Vector3(-12.0, 0.5, 0.0), c)
	_expect(gi.down_phase == "", "hide: a ball into the body does nothing")


func _front() -> void:
	var feet0 := {}
	for nm in ["front_toe.R", "toe.L", "toe.R"]:
		feet0[nm] = _bone_local(nm)
	var hump0 := gi.torso.global_transform * StandInGiant.HUMP_AT
	var body0 := gi.body.global_position
	var went := []
	gi.went_down.connect(func(l: String) -> void: went.append(l), CONNECT_ONE_SHOT)
	var z := gi.weak[0]
	await _shoot(z.global_position + _rear_quarter(0) * 14.0 + Vector3.UP * 0.4, z.global_position)
	_expect(went == ["Front_L"], "front: a ball behind the front left knee: down on it (%s)" % str(went))
	var shake := CameraShake.of(p.camera)
	var most := 0.0
	var off := 0.0
	for i in 150:
		await physics_frame
		most = maxf(most, shake.trauma)
		off = maxf(off, absf(p.camera.h_offset) + absf(p.camera.v_offset))
	_expect(most > 0.4 and off > 0.01, "quake: the knee strikes, the view shakes for a player %.0f m off (trauma %.2f)" %
			[p.global_position.distance_to(gi.body.global_position), most])
	_expect(gi.down_phase == "down", "front: the kneel played out, it is down (%s)" % gi.down_phase)
	var knee := _bone("front_foot.L")
	_expect(knee.y - gi._home.origin.y < 0.35, "front: the knee on the ground (%.2f m up)" % (knee.y - gi._home.origin.y))
	var hump := gi.torso.global_transform * StandInGiant.HUMP_AT
	_expect(hump0.y - hump.y > 0.35, "front: the front of the body lower (the hump down %.2f m)" % (hump0.y - hump.y))
	var moved := 0.0
	for nm in feet0:
		moved = maxf(moved, (feet0[nm] as Vector3).distance_to(_bone_local(nm)))
	_expect(moved < 0.08, "front: the other three feet stayed where they stood (%.3f m)" % moved)
	# down: it neither paces nor shakes, whoever is on it
	gi.paces = true
	gi._on_t = 99.0
	gi._wait = 0.0
	await _fr(4)      # (pacing on: its offset of the moment comes on the next step)
	var b1 := gi.body.global_position
	await _fr(240)
	_expect(not gi.shaking and not gi.warning and _flat(gi.body.global_position, b1) < 0.05,
			"front: down, it neither paces nor shakes (shaking %s, warning %s, moved %.3f m)" % [gi.shaking, gi.warning,
			_flat(gi.body.global_position, b1)])
	gi.paces = false
	gi._on_t = 0.0
	var up := []
	gi.got_up.connect(func(l: String) -> void: up.append(l), CONNECT_ONE_SHOT)
	await _fr(int((StandInGiant.DOWN_S + 3.0) * 120.0))
	_expect(up == ["Front_L"] and gi.down_phase == "", "front: after %.0f s it rises (%s)" % [StandInGiant.DOWN_S, str(up)])
	await _fr(60)
	var hump2 := gi.torso.global_transform * StandInGiant.HUMP_AT
	_expect(absf(hump2.y - hump0.y) < 0.08 and gi.body.global_position.distance_to(body0) < 0.1,
			"front: standing again where it stood (the hump %.2f m off)" % absf(hump2.y - hump0.y))


func _rider() -> void:
	gi._wait = 99.0
	p.global_position = gi.torso.global_position + Vector3(0.3, 1.7, 0.5)
	p.velocity = Vector3.ZERO
	p.grip.stamina = p.grip.stamina_max
	await _fr(90)
	Input.action_press("grip")
	await _fr(60)
	var on := p.grip.state != PlayerGrip.OFF and p.grip.gripped == gi.torso
	var y0 := p.global_position.y
	gi.knock_down("Front_R")
	await _fr(150)
	_expect(on and p.grip.state != PlayerGrip.OFF, "rider: gripping its back through the fall")
	_expect(y0 - p.global_position.y > 0.2, "rider: carried down with it (%.2f m)" % (y0 - p.global_position.y))
	Input.action_release("grip")
	await _fr(int((StandInGiant.DOWN_S + 3.0) * 120.0))
	_expect(p.camera.h_offset == 0.0 and p.camera.v_offset == 0.0 and CameraShake.of(p.camera).trauma == 0.0,
			"quake: the shake has settled, the view back in place")
	await _fr(240)


func _hind() -> void:
	var rump0 := gi.torso.global_transform * Vector3(0.0, StandInGiant.BODY_R, StandInGiant.BODY_Z + 1.6)
	# a player far off: no shake
	p.global_position = gi.body.global_position + Vector3(0.0, 0.5, 60.0)
	p.velocity = Vector3.ZERO
	await _fr(30)
	var went := []
	gi.went_down.connect(func(l: String) -> void: went.append(l), CONNECT_ONE_SHOT)
	Hit.deliver(gi.weak[3], 110.0, gi.weak[3].global_position, -_back(), p)
	var most := 0.0
	for i in 150:
		await physics_frame
		most = maxf(most, CameraShake.of(p.camera).trauma)
	_expect(most == 0.0, "quake: not for a player %.0f m off" % p.global_position.distance_to(gi.body.global_position))
	var rump := gi.torso.global_transform * Vector3(0.0, StandInGiant.BODY_R, StandInGiant.BODY_Z + 1.6)
	var hock := _bone("foot.R")
	_expect(went == ["Hind_R"] and gi.down_phase == "down", "hind: a hit behind the right hind knee: down on it (%s)" % str(went))
	_expect(rump0.y - rump.y > 0.5 and hock.y - gi._home.origin.y < 0.4,
			"hind: the rump sunk %.2f m, the hock on the ground (%.2f m up)" % [rump0.y - rump.y, hock.y - gi._home.origin.y])
