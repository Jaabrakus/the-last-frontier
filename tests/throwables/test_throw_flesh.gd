extends "res://tests/throwables/harness.gd"
## Thrown weapons and arrows in animals (user 2026-09-27: "thrown weapons and animals: thrown weapons don't stick in
## animals yet. lets do this"), headless, on the real level and player with a deer (WildAnimal) placed broadside:
##   surface    the hit zones read "flesh" (Sfx.surface_of) and the flesh impact sounds are in the table
##   tomahawk   thrown into the body: sticks (not bounced), on a BoneAttachment3D of the deer's skeleton (not the
##              hit zone, which only follows its bone's position while alive), and takes the throw's full damage
##              (a bounce did blunt damage)
##   rides      where it sits on the body stays put as the deer is moved and turned, and through its death fall
##   pickup     E takes it back from the carcass
##   spear      into the vitals (a sphere zone read as stone before: bounced): sticks; the deer freed, the spear
##              drops to the ground as a pickup
##   atlatl     the dart sticks
##   arrow      an arrow shot into the deer rides on its bone as well; a musket ball leaves no dust puff there
##
##   Godot --headless --fixed-fps 120 --path . -s tests/throwables/test_throw_flesh.gd -- --no-capture
## "THROW FLESH TEST PASSED" and exit 0 when every check passes. Run it under a hard time limit.
## The animals are Quaternius's CC0 stand-in models (assets/wildlife/quaternius/SOURCE.md).

const SPOT := Vector3(9.0, 0.0, -44.0)


func _initialize() -> void:
	if not await _boot():
		print("THROW FLESH TEST FAILED")
		quit(1)
		return
	for k in kit:
		_no_spread(kit[k])
	_test_surface()
	await _test_tomahawk()
	await _test_spear_vitals()
	await _test_atlatl()
	await _test_arrow_and_ball()
	_finish("THROW FLESH TEST")


## A deer standing broadside at `at`, its left side toward +Z (the player stands south of it).
func _deer(at: Vector3, seed_ := 5) -> WildAnimal:
	var a := WildAnimal.new()
	a.setup("deer", null, null, seed_)
	current_scene.add_child(a)
	a.global_position = Vector3(at.x, _ground_at(at.x, at.z), at.z)
	a.rotation.y = PI * 0.5
	a._yaw = a.rotation.y
	a.set_active(true)
	await _frames(20)
	return a


func _calm(a: WildAnimal, n: int) -> void:
	for i in n:
		if is_instance_valid(a):
			a.awareness = 0.0
		await _frames(1)


func _zone(a: WildAnimal, part: String) -> Node3D:
	return a.get_node_or_null("Hit_" + part) as Node3D


func _on_skeleton(p: Node, a: WildAnimal) -> bool:
	var par := p.get_parent() if is_instance_valid(p) else null
	return par is BoneAttachment3D and a.is_ancestor_of(par)


func _test_surface() -> void:
	var a := WildAnimal.new()
	a.setup("deer", null, null, 3)
	current_scene.add_child(a)
	var z := _zone(a, "vitals")
	_expect(z != null and Sfx.surface_of(z, z.global_position, Vector3.UP) == "flesh", "surface: a deer's hit zone reads flesh")
	_expect(Sfx.has(&"arrow_hit_flesh") and Sfx.has(&"ball_hit_flesh"), "surface: the flesh impact sounds are in the table")
	a.queue_free()


func _throw_at(a: WildAnimal, key: String, target: Vector3) -> ThrownProjectile:
	await _use(key)
	var stand := Vector3(target.x, 0.0, target.z + 6.0)
	stand.y = _ground_at(stand.x, stand.z)
	await _stand_and_aim(stand, target)
	await _calm(a, 4)
	return await _full_throw()


func _test_tomahawk() -> void:
	var a := await _deer(SPOT)
	var body := _zone(a, "body")
	var hp0 := a.health
	var p := await _throw_at(a, "tomahawk", body.global_position)
	_expect(p != null, "tomahawk: thrown")
	if p == null:
		return
	var ph := await _wait_rest(p, 240)
	_expect(ph == ThrownProjectile.Phase.STUCK, "tomahawk: sticks in the deer (phase %d, 2 = stuck)" % ph)
	_expect(_on_skeleton(p, a), "tomahawk: rides on a bone of the deer's skeleton (parent %s)" %
			(p.get_parent().name if is_instance_valid(p) and p.get_parent() else "-"))
	var took := hp0 - a.health
	_expect(took > p.blunt_damage * 1.5, "tomahawk: full damage, not blunt (took %.1f; blunt %.1f, full %.1f)" %
			[took, p.blunt_damage, p.damage])
	# rides with the body: moved and turned
	var loc0: Vector3 = a.global_transform.affine_inverse() * p.global_position
	a.global_position += Vector3(2.0, 0.0, -1.0)
	a.global_position.y = _ground_at(a.global_position.x, a.global_position.z)
	a.rotation.y += 1.2
	a._yaw = a.rotation.y
	await _frames(6)
	var loc1: Vector3 = a.global_transform.affine_inverse() * p.global_position
	_expect(loc0.distance_to(loc1) < 0.25, "rides: moved 2.2 m and turned 69 deg, the tomahawk keeps its place on the body (%.3f m)" % loc0.distance_to(loc1))
	# through the death fall
	if not a.is_dead():
		a.apply_hit(9999.0, a.global_position + Vector3.UP * 0.6, Vector3.RIGHT, player, "vitals")
	await _frames(int(2.5 * 120))
	var bone_d := INF
	if is_instance_valid(p) and p.get_parent() is BoneAttachment3D:
		var ba := p.get_parent() as BoneAttachment3D
		var sk := ba.get_parent() as Skeleton3D
		var bp := sk.global_transform * sk.get_bone_global_pose(ba.bone_idx).origin
		bone_d = bp.distance_to(p.global_position)
	_expect(a.is_dead() and bone_d < 0.9, "rides: fallen dead, the tomahawk is still on its bone (%.2f m from it)" % bone_d)
	# E takes it back
	var got := await _pick_up(p)
	_expect(got, "pickup: E takes the tomahawk back from the carcass")
	a.queue_free()
	await _frames(4)


func _test_spear_vitals() -> void:
	var a := await _deer(SPOT + Vector3(-5.0, 0.0, 0.0), 7)
	var vit := _zone(a, "vitals")
	var p := await _throw_at(a, "spear", vit.global_position)
	_expect(p != null, "spear: thrown")
	if p == null:
		a.queue_free()
		return
	var ph := await _wait_rest(p, 240)
	_expect(ph == ThrownProjectile.Phase.STUCK and _on_skeleton(p, a), "spear: sticks in the vitals, on the skeleton (phase %d)" % ph)
	# the deer freed (despawned, eaten to the bones): the spear drops to the ground as a pickup
	var where := p.global_position
	a.queue_free()
	await _frames(30)
	var lying: ThrownProjectile = null
	for n in current_scene.find_children("*", "ThrownProjectile", true, false):
		var t := n as ThrownProjectile
		if t != p and t.kind == "spear" and t.phase == ThrownProjectile.Phase.LYING and t.global_position.distance_to(where) < 3.0:
			lying = t
	_expect(lying != null, "spear: the deer freed, the spear lies on the ground below")
	if lying:
		await _pick_up(lying)


func _test_atlatl() -> void:
	if not kit.has("atlatl"):
		return
	var a := await _deer(SPOT + Vector3(5.0, 0.0, -3.0), 11)
	var body := _zone(a, "body")
	var p := await _throw_at(a, "atlatl", body.global_position)
	_expect(p != null, "atlatl: dart thrown")
	if p:
		var ph := await _wait_rest(p, 300)
		_expect(ph == ThrownProjectile.Phase.STUCK and _on_skeleton(p, a), "atlatl: the dart sticks, on the skeleton (phase %d)" % ph)
		if is_instance_valid(p):
			await _pick_up(p)
	a.queue_free()
	await _frames(4)


func _test_arrow_and_ball() -> void:
	var a := await _deer(SPOT + Vector3(0.0, 0.0, -8.0), 13)
	var body := _zone(a, "body")
	var from := body.global_position + Vector3(0.0, 0.3, 6.0)
	var arrow := Projectile.new()
	arrow.kind = Projectile.Kind.ARROW
	arrow.velocity = (body.global_position - from).normalized() * 60.0
	arrow.gravity = 0.0
	arrow.damage = 40.0
	arrow.exclude = [player.get_rid()]
	arrow.shooter = player
	current_scene.add_child(arrow)
	arrow.global_position = from
	await _calm(a, 60)
	_expect(is_instance_valid(arrow) and _on_skeleton(arrow, a), "arrow: rides on a bone of the deer (parent %s)" %
			(arrow.get_parent().name if is_instance_valid(arrow) and arrow.get_parent() else "-"))
	# a musket ball: no dust puff from the animal
	var puffs_before := _particles()
	var ball := Projectile.new()
	ball.kind = Projectile.Kind.BALL
	ball.velocity = (body.global_position - from).normalized() * 300.0
	ball.gravity = 0.0
	ball.damage = 10.0
	ball.exclude = [player.get_rid()]
	ball.shooter = player
	current_scene.add_child(ball)
	ball.global_position = from
	await _frames(20)
	_expect(_particles() == puffs_before, "ball: no dust puff from the deer (%d -> %d particle systems)" % [puffs_before, _particles()])
	a.queue_free()
	await _frames(4)


func _particles() -> int:
	return current_scene.find_children("*", "GPUParticles3D", false, false).size() \
			+ current_scene.find_children("*", "CPUParticles3D", false, false).size()
