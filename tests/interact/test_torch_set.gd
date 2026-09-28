extends SceneTree
## The torch's keys and the torch mode (PlayerTorch; PlayerInteractor.begin_torch_place), in the real level with the
## real keys, headless:
##
##   Godot --headless --path . -s tests/interact/test_torch_set.gd
##
##   keys     a tap of T takes a torch out; with it in the hand a tap raises it and another lowers it; a hold puts it
##            away
##   set      a double tap of T opens the torch mode, setting it: a ghost torch at arm's length, "Push the torch into
##            the ground"; the gun takes no fire meanwhile; a left click sets it standing there lit, its butt in the
##            soil, and the musket stays loaded; a tap of E takes it up again
##   throw    in the mode a tap of T turns to throwing: an arc to where the crosshair lands; a left click throws it and
##            it comes down near the ring, burning; the same from the left hand (the pistol out)
##   keep     holding T in the mode puts the mode away and keeps the torch in the hand
##   wall     the crosshair on a wall: "Wedge the torch in the wall" at shoulder height, the head out and up; a rock
##            face takes none

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var it: PlayerInteractor
var pt: PlayerTorch
var at := Vector3.ZERO


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func seconds(t: float) -> void:
	await frames(int(t * Engine.physics_ticks_per_second))


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


func _tap(action: StringName, n := 4) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(3)


func _double_t() -> void:
	await _tap(PlayerTorch.ACTION)
	await frames(4)
	await _tap(PlayerTorch.ACTION)
	await frames(4)


func _hold_t() -> void:
	Input.action_press(PlayerTorch.ACTION)
	await seconds(PlayerTorch.HOLD_S + 0.15)
	Input.action_release(PlayerTorch.ACTION)
	await frames(4)


func _in_hand() -> void:
	for i in 240:
		await physics_frame
		if pt.holding() and not pt.pending:
			break
	await seconds(0.3)


func _stand() -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.yaw = 0.0                     # facing -Z
	player.rotation.y = 0.0


func _run() -> void:
	for i in 10:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	check(player != null and player.interactor != null and player.torch != null, "the player has the interactor and torches")
	if player == null or player.interactor == null or player.torch == null:
		_end()
		return
	player.ignore_mouse_capture = true
	it = player.interactor
	pt = player.torch
	await seconds(1.0)
	at = _ground(Vector3(21.0, 0, 9.0)) + Vector3(0, 0.1, 0)
	_stand()
	player.pitch = deg_to_rad(-12.0)
	await _test_keys()
	await _test_set()
	await _test_throw("r")
	await _test_keep()
	await _test_left_throw()
	await _test_wall()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("TORCH SET TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("TORCH SET TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _test_keys() -> void:
	await _tap(PlayerTorch.ACTION)
	await _in_hand()
	check(pt.holding() and pt.held.lit, "a tap of T takes a torch out, lit")
	await _tap(PlayerTorch.ACTION)
	await seconds(PlayerTorch.DOUBLE_S + HandHolds.RAISE_S + 0.3)
	check(pt.raised and player.anim.holds.raise > 0.95, "with it in the hand a tap raises it (%.2f)" % player.anim.holds.raise)
	await _tap(PlayerTorch.ACTION)
	await seconds(PlayerTorch.DOUBLE_S + HandHolds.RAISE_S + 0.3)
	check(not pt.raised and player.anim.holds.raise < 0.05 and pt.holding(), "another lowers it, still in the hand")
	await _hold_t()
	await seconds(0.3)
	check(not pt.holding(), "a hold puts it away")
	await _tap(PlayerTorch.ACTION)
	await _in_hand()


func _test_set() -> void:
	var musket := player.weapon as Firearm
	var loaded := musket != null and musket.loaded
	await _double_t()
	check(it.torch_placing and it.torch_mode == "set" and pt.placing, "a double tap: the torch mode, setting it")
	check(not pt.raised, "(the double tap did not raise it)")
	check(pt.blocks_fire(), "the gun takes no fire meanwhile")
	check(String(it.place.get("what", "")) == "Push the torch into the ground", "'%s'" % it.place.get("what", ""))
	check(it._ghost != null and it._ghost.visible and it._ghost_key == "~torch", "a ghost torch shows where")
	check(it._label.text == "Click  Push the torch into the ground", "prompt '%s'" % it._label.text)
	await _tap(&"fire")
	await seconds(0.8)
	var d := pt.last_dropped
	check(not pt.holding() and d != null and is_instance_valid(d) and not it.torch_placing, "a click sets it: the hand empty, the mode off")
	check(musket == null or musket.loaded == loaded, "and the musket did not fire")
	if d == null or not is_instance_valid(d):
		return
	var butt := d.global_transform * Vector3(0, 0, TorchModels.GRIP_FROM_BUTT)
	var g := FrontierTerrain.height_at(butt.x, butt.z)
	var head := (-d.global_basis.z).normalized()
	check(d.standing() and head.y > 0.98, "it stands upright, frozen (head %s)" % head)
	check(butt.y < g - 0.05 and butt.y > g - 0.25, "its butt in the soil (%.2f m under)" % (g - butt.y))
	check(d.state.lit and d.flame_position().y > g + 0.4, "and burns there, the flame above the ground")
	player.pitch = deg_to_rad(-40.0)
	await frames(8)
	check(it.target == d and it._label.text.ends_with("Take the torch"), "looked at: '%s'" % it._label.text)
	await _tap(&"interact")
	await _in_hand()
	check(pt.holding() and (not is_instance_valid(d) or d.is_queued_for_deletion()), "a tap of E takes it up again")


func _test_throw(side: String) -> void:
	player.pitch = deg_to_rad(-16.0)
	await frames(6)
	await _double_t()
	await _tap(PlayerTorch.ACTION)
	await frames(4)
	check(it.torch_mode == "throw" and not it.throw.is_empty(), "%s hand: a tap in the mode turns to throwing" % side)
	if it.throw.is_empty():
		return
	var land: Vector3 = it.throw.land
	var dist := Vector2(land.x - at.x, land.z - at.z).length()
	check(it._arc != null and it._arc.visible and it._arc.multimesh.visible_instance_count > 5 and it._ring.visible,
			"the arc and the ring show (%d dots, %.1f m)" % [it._arc.multimesh.visible_instance_count if it._arc else 0, dist])
	check(dist > 3.0 and dist <= PlayerTorch.THROW_MAX + 0.5, "to where the crosshair lands (%.1f m)" % dist)
	check(it._label.text.begins_with("Click  Throw the torch"), "prompt '%s'" % it._label.text)
	await _tap(&"fire")
	await seconds(3.0)
	var d := pt.last_dropped
	check(not pt.holding() and d != null and is_instance_valid(d) and not it.torch_placing, "a click throws it")
	if d == null or not is_instance_valid(d):
		return
	var off := Vector2(d.global_position.x - land.x, d.global_position.z - land.z).length()
	check(off < 1.6, "it comes down by the ring (%.2f m off)" % off)
	check(d.state.lit, "still burning")
	d.interact(player)
	await _in_hand()
	_stand()


func _test_keep() -> void:
	await _double_t()
	check(it.torch_placing, "the mode up again")
	await _hold_t()
	await seconds(0.4)
	check(not it.torch_placing and pt.holding() and not pt.placing, "holding T puts the mode away, the torch still in the hand")
	check(not pt.blocks_fire(), "and the gun takes fire again")


func _test_left_throw() -> void:
	player.switch_weapon("pistol")
	await seconds(1.6)
	check(player.weapon_key == "pistol" and pt.holding() and player.anim.torch_ik.side == "l",
			"the pistol out: the torch in the left hand (%s, %s)" % [player.weapon_key, player.anim.torch_ik.side])
	await _test_throw("l")
	player.switch_weapon("musket")
	await seconds(1.6)


func _test_wall() -> void:
	if not pt.holding():
		await _tap(PlayerTorch.ACTION)
		await _in_hand()
	var wall := StaticBody3D.new()
	wall.name = "TestWall"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.0, 3.2, 0.3)
	cs.shape = bs
	wall.add_child(cs)
	current_scene.add_child(wall)
	wall.global_position = at + Vector3(0, 1.5, -1.6)
	var face_z := wall.global_position.z + 0.15
	await frames(4)
	var ok := false
	for i in 12:
		player.pitch = deg_to_rad(4.0 - 3.0 * i)
		await frames(4)
		var h := it._look_hit()
		if not h.is_empty() and (h.hit as Dictionary).get("collider") == wall:
			ok = true
			break
	check(ok, "the crosshair finds the wall")
	await _double_t()
	check(String(it.place.get("kind", "")) == "wall" and String(it.place.get("what", "")) == "Wedge the torch in the wall",
			"on the wall: '%s'" % it.place.get("what", ""))
	await _tap(&"fire")
	await seconds(0.5)
	var d := pt.last_dropped
	check(not pt.holding() and d != null and is_instance_valid(d) and d.standing(), "a click: it stays in the wall")
	if d == null or not is_instance_valid(d):
		wall.queue_free()
		return
	var butt := d.global_transform * Vector3(0, 0, TorchModels.GRIP_FROM_BUTT)
	var head := (-d.global_basis.z).normalized()
	var h := butt.y - at.y
	check(absf(butt.z - face_z) < 0.08, "its butt in the wall's face (%.2f m off)" % absf(butt.z - face_z))
	check(h >= PlayerInteractor.WEDGE_H.x - 0.12 and h <= PlayerInteractor.WEDGE_H.y + 0.02, "at shoulder height (%.2f m)" % h)
	check(head.z > 0.4 and head.y > 0.7, "the head out from the wall and up (%s)" % head)
	d.interact(player)
	await _in_hand()
	wall.set_meta(&"surface", "stone")
	await _double_t()
	check(it.torch_placing and it.place.is_empty() and it._label.text.contains("to set the torch"),
			"a rock face takes no torch: '%s'" % it._label.text)
	await _tap(&"fire")
	await seconds(0.3)
	check(pt.holding() and it.torch_placing, "a click there does nothing")
	await _hold_t()
	wall.queue_free()
