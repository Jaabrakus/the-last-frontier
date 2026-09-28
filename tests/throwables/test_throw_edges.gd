extends "res://tests/throwables/harness.gd"
## Headless edge-case test of the thrown weapons (review pass), on the player in the real
## level with the same harness as test_throwables.gd / test_throw_rules.gd:
##   point blank   a spear, dart or tomahawk thrown with a board (or the ground) closer than
##                 its point hits it and does not pass through (the first step sweeps from the
##                 hand), and leaves toward the aim point (aimed from the hand point blank)
##   moving        a spear stuck in a moving body rides along with it and is picked up
##   bounce        glancing off stone, the spear bounces from where its tip touched (no jump
##                 forward by its length into the stone)
##   timeout       a weapon still tumbling at max_flight_time is laid down, not deleted
##   ammo          two try_give calls on one pickup give one item; add_items never takes
##                 ammo away when count > max_count; install is idempotent
##   removed       a target taken out of the tree (not freed) and put back keeps one spear,
##                 not a spear plus a dropped copy; taken out for good, it drops the spear;
##                 a hit part freed at once by its owner's apply_hit drops the spear to the ground
##   switching     switching away mid-throw keeps the spear; mid-recover with the last one
##                 leaves it empty; a pickup while holstered is drawn on the next equip
##   cancel        RMB/R after a quick click (release queued) still lowers it; RMB/R once the
##                 throw is committed is ignored and does not carry over to the next wind-up
##
##   Godot --headless --path . -s tests/throwables/test_throw_edges.gd -- --no-capture


func _initialize() -> void:
	if not await _boot():
		print("THROW EDGES TEST FAILED")
		quit(1)
		return
	for k in kit:
		_no_spread(kit[k])
	# only=name[,name] runs a subset (debugging).
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	var run := func(n: String) -> bool: return only.is_empty() or n in only
	if run.call("point_blank"):
		await _test_point_blank("spear", 0.32)
		await _test_point_blank("atlatl", 0.32)
		await _test_point_blank("tomahawk", 0.32)
	if run.call("feet"):
		await _test_throw_at_feet()
	if run.call("moving"):
		await _test_moving_target()
	if run.call("bounce"):
		await _test_stone_bounce()
	if run.call("timeout"):
		await _test_tumble_timeout()
	if run.call("ammo"):
		await _test_ammo_guards()
	if run.call("removed"):
		await _test_removed_not_freed()
	if run.call("switching"):
		await _test_switching()
	if run.call("cancel"):
		await _test_cancel_edges()
	if run.call("freed"):
		await _test_freed_by_hit()
	var left := _in_world()
	_expect(left.is_empty(), "every thrown weapon was picked up again (%d left in the world)" % left.size())
	_finish("THROW EDGES TEST")


func _in_world() -> Array:
	var out: Array = []
	for n in current_scene.find_children("*", "ThrownProjectile", true, false):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _first_hit(p: ThrownProjectile) -> Dictionary:
	var rec := {}
	p.hit.connect(func(c: Object, pt: Vector3, stuck: bool) -> void:
		if rec.has("collider"):
			return
		rec["collider"] = c
		rec["point"] = pt
		rec["stuck"] = stuck
		rec["com"] = p.global_position
		rec["dir"] = p.velocity.normalized())
	return rec


## Throws `key` at a wooden board whose face is `gap` metres in front of the player: the
## held point is past the face at launch. It must hit the board, not come out behind it.
func _test_point_blank(key: String, gap: float) -> void:
	print("point blank: ", key)
	var w := await _use(key)
	var board := _board(10.0, -32.0, "wood")
	var face_z := board.global_position.z + 0.15
	var back_z := board.global_position.z - 0.15
	var stand := Vector3(10.0, _ground_at(10.0, face_z + gap), face_z + gap)
	await _stand_and_aim(stand, Vector3(10.0, stand.y + 0.8, face_z))
	# At the height of the hand (the arm is not raised yet): the point reaches out level.
	await _aim_at(Vector3(10.0, w._hand_pos().y, face_z))
	_fire(true)
	for i in 240:
		await _frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	var node := w._thrown_node()
	# Spear, tomahawk: the Muzzle marker is the point / edge. Dart: its origin is the point.
	var tip := node.global_transform * (Vector3.ZERO if key == "atlatl" else ThrowableModels.marker_pos(node, "Muzzle"))
	var hand := w._hand_pos()
	print("    hand z %.2f, point z %.2f, board face z %.2f, back z %.2f" % [hand.z, tip.z, face_z, back_z])
	if key != "tomahawk":
		_expect(tip.z < face_z, "%s: set-up: the held point is already past the board face (%.2f < %.2f)" % [key, tip.z, face_z])
	var before := w.last_thrown
	var at := {}
	var on_thrown := func(q: ThrownProjectile) -> void:
		at["origin"] = q.global_position
		at["dir"] = q.velocity.normalized()
		at["aim"] = player.get_aim_point()
		at["hand"] = w._hand_pos()
	w.thrown.connect(on_thrown)
	_fire(false)
	for i in 120:
		await _frames(1)
		if w.last_thrown != before:
			break
	w.thrown.disconnect(on_thrown)
	var p := w.last_thrown
	if not at.is_empty():
		var to_aim: Vector3 = (at.aim as Vector3) - (at.hand as Vector3)
		print("    launch: origin %s hand %s aim %s dir %s (%.1f deg off the hand->aim line)" % [at.origin, at.hand, at.aim, at.dir,
				rad_to_deg((at.dir as Vector3).angle_to(to_aim))])
		_expect((at.dir as Vector3).dot(to_aim.normalized()) > 0.9, "%s point blank: thrown toward the aim point, not off to the side or back" % key)
	if p == before or p == null:
		_expect(false, "%s thrown point blank" % key)
		_clear_boards()
		return
	var rec := _first_hit(p)
	var phase := await _wait_rest(p, 600)
	var hl: Array = board.get("hit_log")
	var behind := is_instance_valid(p) and p.global_position.z < back_z - 0.05 and p.get_parent() != board
	_expect(rec.get("collider") == board and hl.size() <= 1 and not behind,
			"%s point blank: hits the board (%s, %d hits, rests at z %.2f, board back %.2f)" % [key,
			(rec.get("collider") as Node).name if rec.get("collider") is Node else "nothing", hl.size(),
			p.global_position.z if is_instance_valid(p) else INF, back_z])
	if is_instance_valid(p):
		print("    phase %d, parent %s" % [phase, p.get_parent().name])
		_expect(await _pick_up(p), "%s: picked up again" % key)
	_clear_boards()
	await _frames(int((w.draw_time + w.follow_time) * 120) + 10)


## Turns the camera onto `target` without moving the player.
func _aim_at(target: Vector3) -> void:
	for i in 5:
		var d := target - player.camera.global_position
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -deg_to_rad(player.pitch_limit_deg), deg_to_rad(player.pitch_limit_deg))
		await _frames(3)


## Aimed at the ground 1.2 m in front of the feet: the point starts below the ground.
func _test_throw_at_feet() -> void:
	print("throw at the feet")
	var w := await _use("spear")
	var x := 8.0
	var stand := Vector3(x, _ground_at(x, -24.0), -24.0)
	player.global_position = stand + Vector3.UP * 0.3
	player.velocity = Vector3.ZERO
	await _frames(30)
	var target := Vector3(x, _ground_at(x, -25.2), -25.2)
	for i in 5:
		var from := player.camera.global_position
		var d := target - from
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -deg_to_rad(player.pitch_limit_deg), deg_to_rad(player.pitch_limit_deg))
		await _frames(3)
	var p := await _full_throw()
	if p == null:
		_expect(false, "thrown at the feet")
		return
	var rec := _first_hit(p)
	var phase := await _wait_rest(p, 600)
	var ok := is_instance_valid(p) and rec.has("collider") and phase >= ThrownProjectile.Phase.STUCK
	var y := p.global_position.y if is_instance_valid(p) else -INF
	_expect(ok and y > _ground_at(p.global_position.x, p.global_position.z) - 0.5,
			"thrown down at the feet it hits the ground and stays above it (phase %d, y %.2f)" % [phase, y])
	if is_instance_valid(p):
		_expect(await _pick_up(p), "picked up again")
	await _frames(int(w.draw_time * 120) + 10)


## The game's moving target: a straw dummy (TargetDummy.move_offset) sliding along the
## throw line, so the throw cannot miss it sideways. The stuck spear rides with it.
func _test_moving_target() -> void:
	print("moving target")
	var w := await _use("spear")
	var dm := TargetDummy.new()
	dm.max_health = 1.0e6
	dm.move_offset = Vector3(0.0, 0.0, -3.0)
	dm.move_period = 6.0
	var y := _ground_at(10.0, -32.0)
	dm.position = Vector3(10.0, y, -32.0)
	current_scene.add_child(dm)
	dm.health = 1.0e6
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -25.0), -25.0), dm.global_position + Vector3(0, 1.2, 0))
	var p := await _full_throw()
	if p == null:
		_expect(false, "thrown at the moving dummy")
		dm.queue_free()
		return
	var rec := _first_hit(p)
	var phase := await _wait_rest(p)
	var body := p.get_parent() if is_instance_valid(p) else null
	print("    hit %s stuck %s phase %d parent %s" % [(rec.get("collider") as Node).name if rec.get("collider") is Node else "nothing",
			rec.get("stuck", false), phase, body.name if body else "-"])
	_expect(phase == ThrownProjectile.Phase.STUCK and _dummy_of(rec.get("collider")) == dm and _dummy_of(body) == dm,
			"sticks in the moving dummy and hangs from it")
	if phase == ThrownProjectile.Phase.STUCK and body is Node3D:
		var b3 := body as Node3D
		var rel0: Transform3D = b3.global_transform.affine_inverse() * p.global_transform
		var z0 := p.global_position.z
		var d0 := dm.global_position.z
		await _frames(60)
		var rel1: Transform3D = b3.global_transform.affine_inverse() * p.global_transform
		var moved := p.global_position.z - z0
		_expect(rel0.origin.distance_to(rel1.origin) < 0.001 and absf(moved) > 0.1 and absf(moved - (dm.global_position.z - d0)) < 0.001,
				"it rides with the dummy (%.2f m in 0.5 s, dummy %.2f m, %.4f m drift)" % [moved, dm.global_position.z - d0,
				rel0.origin.distance_to(rel1.origin)])
	dm.move_offset = Vector3.ZERO                        # Stops where it is.
	if is_instance_valid(p):
		_expect(await _pick_up(p), "pulled out of the moving dummy")
	dm.queue_free()
	await _frames(int(w.draw_time * 120) + 10)


## Glancing off stone the spear bounces from where its tip touched.
func _test_stone_bounce() -> void:
	print("stone bounce")
	var w := await _use("spear")
	var stone := _board(13.5, -32.0, "stone")
	await _stand_and_aim(Vector3(13.5, _ground_at(13.5, -24.0), -24.0), stone.global_position + Vector3(0, -0.4, 0))
	var p := await _full_throw()
	if p == null:
		_expect(false, "thrown at stone")
		_clear_boards()
		return
	var rec := _first_hit(p)
	var shots: Array = []
	for i in 150:
		await _frames(1)
		if rec.has("collider"):
			shots.append([p.global_position, p.tip_position()])
			if shots.size() >= 3:
				break
	var face_z := stone.global_position.z + 0.15
	var ok: bool = rec.has("collider") and not rec.stuck and shots.size() > 0
	var com_ahead := INF
	var tip_in := INF
	if ok:
		var pt: Vector3 = rec.point
		var dir: Vector3 = rec.dir
		com_ahead = ((shots[0][0] as Vector3) - pt).dot(dir)      # First frame after the bounce.
		tip_in = 0.0
		for sh: Array in shots:
			tip_in = maxf(tip_in, face_z - (sh[1] as Vector3).z)
	_expect(ok and com_ahead < -0.5 * p._reach, "bounce: the spear's centre stays behind the impact (%.2f m along the flight; reach %.2f)" % [com_ahead, p._reach])
	_expect(ok and tip_in < 0.1, "bounce: the point does not sink into the stone (%.2f m)" % tip_in)
	await _wait_rest(p, 900)
	if is_instance_valid(p):
		_expect(await _pick_up(p), "picked up again")
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)


## Still tumbling at max_flight_time (wedged, or rolling on a steep slope): lay it down.
func _test_tumble_timeout() -> void:
	print("tumble timeout")
	var w := await _use("spear")
	var stone := _board(13.5, -32.0, "stone")
	await _stand_and_aim(Vector3(13.5, _ground_at(13.5, -24.0), -24.0), stone.global_position + Vector3(0, 0.6, 0))
	var p := await _full_throw()
	if p == null:
		_expect(false, "thrown at stone")
		_clear_boards()
		return
	for i in 120:
		await _frames(1)
		if p.phase != ThrownProjectile.Phase.FLYING:
			break
	var tumbling := p.phase == ThrownProjectile.Phase.TUMBLING
	p._age = p.max_flight_time + 0.1
	await _frames(3)
	_expect(tumbling and is_instance_valid(p) and not p.is_queued_for_deletion() and p.phase == ThrownProjectile.Phase.LYING,
			"tumbling past max_flight_time: laid down where it is, not deleted (phase %d)" % (p.phase if is_instance_valid(p) else -1))
	if is_instance_valid(p) and not p.is_queued_for_deletion():
		_expect(await _pick_up(p), "picked up again")
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)


func _test_ammo_guards() -> void:
	print("ammo guards")
	var w := await _use("spear")
	var board := _board(10.0, -32.0, "wood")
	var r := await _stand_and_throw(w, Vector3(10.0, _ground_at(10.0, -26.0), -26.0), board.global_position)
	var p: ThrownProjectile = r
	await _wait_rest(p)
	await _frames(70)                                    # Past the pickup's arm delay.
	_expect(p != null and p.pickup != null and w.count == 1, "one spear stuck, one in hand (count %d, phase %d)" % [w.count,
			p.phase if is_instance_valid(p) else -1])
	if p and p.pickup:
		w.count = 0                                      # Room for two.
		var a := p.pickup.try_give(player)
		var b := p.pickup.try_give(player)
		_expect(a and not b and w.count == 1, "two try_give calls on one pickup give one spear (count %d)" % w.count)
		w.count = 1
	# count above max_count (a designer set count = 3): a pickup must not take one away.
	w.count = 3
	var took := w.add_items(1)
	_expect(took == 0 and w.count == 3, "add_items with count > max_count takes none and removes none (took %d, count %d)" % [took, w.count])
	w.count = 2 if not is_instance_valid(p) or p.is_queued_for_deletion() else 1
	# install twice: the same weapon nodes, no orphan duplicate that could swallow pickups.
	var keys: Array[String] = ["spear"]
	var again := ThrowableKit.install(player, keys)
	var n := 0
	for c in player.get_node("Throwables").get_children():
		if c is ThrowableSpear:
			n += 1
	_expect(again.get("spear") == kit["spear"] and n == 1, "install again reuses the spear weapon (%d spear weapons)" % n)
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)
	if is_instance_valid(p) and not p.is_queued_for_deletion():
		await _pick_up(p)
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "spears back (%d)" % w.count)


func _stand_and_throw(w: Throwable, stand: Vector3, target: Vector3) -> ThrownProjectile:
	await _stand_and_aim(stand, target)
	return await _full_throw()


## A target removed from the tree without being freed (pooled, or moved to another parent).
func _test_removed_not_freed() -> void:
	print("target removed, not freed")
	var w := await _use("spear")
	var board := _board(10.0, -32.0, "wood")
	var p := await _stand_and_throw(w, Vector3(10.0, _ground_at(10.0, -24.0), -24.0), board.global_position + Vector3(0, 0.2, 0))
	await _wait_rest(p)
	_expect(p != null and p.phase == ThrownProjectile.Phase.STUCK and p.get_parent() == board, "stuck in the board")
	var n0 := _in_world().size()
	# Out and straight back in within the frame (what reparent() does): the same one spear,
	# still stuck in it.
	var parent := board.get_parent()
	parent.remove_child(board)
	parent.add_child(board)
	await _frames(10)
	var spears := _in_world()
	_expect(spears.size() == n0 and is_instance_valid(p) and p.is_inside_tree() and p.get_parent() == board,
			"reparented target: the same one spear, still stuck (%d in the world, was %d)" % [spears.size(), n0])
	# Out for good (orphaned, not freed): the spear itself drops to the ground.
	parent.remove_child(board)
	await _frames(10)
	spears = _in_world()
	var lying := 0
	for q: ThrownProjectile in spears:
		if q.phase == ThrownProjectile.Phase.LYING:
			lying += 1
	var in_board := board.find_children("*", "ThrownProjectile", true, false).size()
	_expect(spears.size() == n0 and lying == 1 and in_board == 0,
			"target taken out: its spear drops to the ground (%d in the world, %d lying, %d left in the target)" % [spears.size(), lying, in_board])
	# And when that target comes back, it does not bring a second spear.
	parent.add_child(board)
	await _frames(10)
	spears = _in_world()
	_expect(spears.size() == n0, "the target back in the level: still one spear (%d)" % spears.size())
	for q: ThrownProjectile in spears:
		if q.phase == ThrownProjectile.Phase.LYING:
			await _frames(70)
			_expect(await _pick_up(q), "the dropped spear is picked up")
	_clear_boards()
	for q: ThrownProjectile in _in_world():
		await _frames(5)
		await _pick_up(q)
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "spears back (%d), none duplicated" % w.count)


func _test_switching() -> void:
	print("switching mid-throw")
	var w := await _use("spear")
	var board := _board(10.0, -32.0, "wood")
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -26.0), -26.0), board.global_position)
	var before := w.last_thrown
	# Released, then switched away before the spear leaves the hand.
	_fire(true)
	for i in 240:
		await _frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	_fire(false)
	await _frames(2)
	_expect(w.state == Throwable.State.RELEASING, "releasing")
	var t := await _use("tomahawk")
	await _frames(int(0.5 * 120))
	_expect(w.last_thrown == before and w.count == 2 and w.state == Throwable.State.READY and not w.model.visible,
			"switched away mid-release: nothing thrown, the spear is kept (count %d)" % w.count)
	# Tomahawk mid-wind-up -> spear: the tomahawk keeps both.
	_fire(true)
	await _frames(20)
	_expect(t.is_winding(), "tomahawk winding")
	await _use("spear")
	_fire(false)
	_expect(t.state == Throwable.State.READY and t.count == 2 and not t.model.visible, "tomahawk put away mid-wind-up keeps both")
	# Throw both spears, switch away during the last one's follow-through.
	var p1 := await _full_throw()
	await _frames(int((w.follow_time + w.draw_time) * 120) + 10)
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -26.0), -26.0), board.global_position + Vector3(0.4, 0.0, 0.0))
	var p2 := await _full_throw()
	_expect(w.state == Throwable.State.RECOVER and w.count == 0, "last spear thrown, recovering")
	await _use("tomahawk")
	_expect(w.state == Throwable.State.EMPTY and not w.model.visible, "switched away mid-recover with none left: empty")
	# Picked up while holstered: drawn on the next equip.
	await _wait_rest(p1)
	await _wait_rest(p2)
	await _frames(70)
	_expect(await _pick_up(p1), "picked up while the spear is put away")
	_expect(w.count >= 1 and not w.active and w.state == Throwable.State.EMPTY, "the holstered spear weapon has it (%d), still empty-handed" % w.count)
	await _use("spear")
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.state == Throwable.State.READY and w.model.visible, "equipped: taken into the hand and ready")
	await _pick_up(p2)
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "spears back (%d)" % w.count)


func _test_cancel_edges() -> void:
	print("cancel edge cases")
	var w := await _use("spear")
	var board := _board(10.0, -32.0, "wood")
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -26.0), -26.0), board.global_position)
	# Quick click: released before min_windup, so the release is queued; RMB/R before it goes.
	var before := w.last_thrown
	var c0 := cancels
	_fire(true)
	await _frames(2)
	_fire(false)
	await _frames(1)
	var queued := w.state == Throwable.State.WINDUP and w._queued_release
	_cancel()
	await _frames(int(w.min_windup * 120) + 20)
	_expect(queued and w.state == Throwable.State.READY and w.last_thrown == before and w.count == 2 and cancels == c0 + 1,
			"RMB/R with a quick-click release queued lowers it, nothing thrown")
	# Committed: RMB/R after the release is ignored; the next wind-up is not cancelled by it.
	_fire(true)
	for i in 240:
		await _frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	_fire(false)
	await _frames(2)
	_cancel()
	await _frames(int(w.release_time * 120) + 5)
	var p := w.last_thrown
	_expect(p != before and w.count == 1 and cancels == c0 + 1, "RMB/R after the release: the throw still goes (count %d)" % w.count)
	await _frames(int((w.follow_time + w.draw_time) * 120) + 10)
	_fire(true)
	await _frames(20)
	_expect(w.is_winding() and cancels == c0 + 1, "the next wind-up is not cancelled by the ignored RMB/R")
	_cancel()
	await _frames(2)
	_fire(false)
	await _frames(2)
	if is_instance_valid(p):
		await _wait_rest(p)
		await _frames(70)
		_expect(await _pick_up(p), "picked up again")
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "spears back (%d)" % w.count)


## A hit part freed at once by its owner's apply_hit (a destructible piece; Godot does not let
## a node free() itself inside its own call, but an owner can free the part that was hit):
## the spear lies on the ground below, with a pickup, instead of hanging in the air.
func _test_freed_by_hit() -> void:
	print("hit part freed by the hit")
	var w := await _use("spear")
	var sc := GDScript.new()
	sc.source_code = "extends Node3D\nfunc apply_hit(damage, point, dir, source, part):\n\tget_node('Part').free()\n"
	sc.reload()
	var owner_node := Node3D.new()
	owner_node.set_script(sc)
	var b := StaticBody3D.new()
	b.name = "Part"
	b.set_meta(&"surface", "wood")
	owner_node.add_child(b)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.4, 0.3)
	cs.shape = box
	b.add_child(cs)
	var y := _ground_at(10.0, -32.0)
	owner_node.position = Vector3(10.0, y + 1.2, -32.0)
	current_scene.add_child(owner_node)
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -26.0), -26.0), Vector3(10.0, y + 1.3, -32.0))
	var p := await _full_throw()
	if p == null:
		_expect(false, "thrown at the self-freeing target")
		return
	var phase := await _wait_rest(p)
	var gy := _ground_at(p.global_position.x, p.global_position.z) if is_instance_valid(p) else 0.0
	_expect(not is_instance_valid(b) and phase == ThrownProjectile.Phase.LYING and p.pickup != null
			and p.global_position.y < gy + 0.3, "the target is gone; the spear lies on the ground below (phase %d)" % phase)
	if is_instance_valid(p):
		await _frames(70)
		_expect(await _pick_up(p), "picked up again")
	owner_node.queue_free()
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "spears back (%d)" % w.count)
