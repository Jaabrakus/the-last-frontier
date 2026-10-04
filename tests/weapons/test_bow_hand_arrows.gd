extends SceneTree
## The bow's hand kept at three, and shot arrows picked up again (the user, 2026-10-03: "i want the game to auto have 3 in
## hand and reload automatically or like that the new way not single shot anymore also have the ability to pick up arrows"),
## driven through the real player in scenes/main.tscn with Input.action_press, as tests/smoke_test.gd drives the bow:
##   Godot --headless --fixed-fps 120 --path . -s tests/weapons/test_bow_hand_arrows.gd -- --no-capture
##   hand     the bow drawn out: the hand fills to Bow.hand_capacity by itself (auto_hand), the quiver count unchanged
##   volley   three shots in a row, each nocked from the hand (the quick nock), the hand 2, 1, 0; let alone, it fills again
##   cut      a draw during the grab: the arrows already pulled stay in the hand, the draw is on at once
##   off      auto_hand false: the hand stays empty; R still fills it
##   pickup   a player's arrow stuck in the ground: an "arrow" ThrownPickup on it, its prompt; taken: the quiver +1, the arrow gone
##   bundle   three arrows stuck close together: one press takes all three ("pick up 3 arrows")
##   ghost    another player's arrow as this machine sees it: no pickup
##   cap      more than Projectile.MAX_STUCK stuck: the oldest go first
## Writes none of the user's files (no saves in a script run). Ends with "BOW HAND ARROWS TEST PASSED (<n> checks)" or
## "BOW HAND ARROWS TEST FAILED (<f> of <n>)".

const HZ := 120.0

var player: FrontierPlayer
var failures := PackedStringArray()
var checks := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") if current_scene else null
	if player == null:
		printerr("FAIL: level or player failed to load (see script errors above)")
		print("BOW HAND ARROWS TEST FAILED (1 of 1)")
		quit(1)
		return
	player.ignore_mouse_capture = true
	await _frames(60)
	var b := await _hand()
	if b != null:
		await _volley(b)
		await _cut(b)
		await _off(b)
		await _pickup(b)
		await _bundle(b)
		await _ghost()
		await _cap()
	_finish()


# ---------------------------------------------------------------- helpers
func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Waits until `cond` holds or `max_frames` pass; true when it held.
func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _tap(action: String, hold_frames := 3) -> void:
	Input.action_press(action)
	await _frames(hold_frames)
	Input.action_release(action)
	await _frames(2)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)
	print(("  ok   " if ok else "  FAIL ") + what)


func _aim_at(p: Vector3) -> void:
	for i in 4:
		var from := player.camera.global_position
		var d := p - from
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await _frames(2)


## A point on the ground `ahead` m in front of the player, `side` m to its right.
func _ground_ahead(ahead: float, side := 0.0) -> Vector3:
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var p := player.global_position + fwd * ahead + right * side
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


## An arrow shot by the player (as Weapon._launch makes one) into the ground at `at`, from 2.5 m above and 1.5 m back.
func _arrow_into(at: Vector3, ghost := false) -> Projectile:
	var from := at + Vector3(0.0, 2.5, 0.0) + (player.global_position - at).normalized() * 1.5
	var dir := (at - from).normalized()
	var p := Projectile.new()
	p.kind = Projectile.Kind.ARROW
	p.velocity = dir * 30.0
	p.gravity = 5.0
	p.damage = 10.0
	p.shooter = player
	p.ghost = ghost
	p.exclude = [player.get_rid()]
	current_scene.add_child(p)
	p.global_position = from
	p.look_at(from + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	return p


static func _pickup_of(p: Node) -> ThrownPickup:
	if not is_instance_valid(p):
		return null
	for c in p.get_children():
		if c is ThrownPickup:
			return c as ThrownPickup
	return null


# ---------------------------------------------------------------- the hand
func _hand() -> Bow:
	print("hand")
	player.switch_weapon("bow")
	await _aim_at(_ground_ahead(25.0) + Vector3.UP * 1.2)
	var b := player.weapon as Bow
	_expect(b != null and b.auto_hand, "the bow drawn out, auto_hand on")
	if b == null:
		return null
	b.quiver = 24
	var q0 := b.quiver
	var full := await _until(func() -> bool: return b.held == b.hand_capacity, int((1.5 + b.auto_grab_idle + b.grab_time) * HZ))
	_expect(full and b.quiver == q0 and b.state == Bow.State.READY,
			"the hand fills to %d by itself (held %d), the quiver count unchanged (%d)" % [b.hand_capacity, b.held, b.quiver])
	_expect(b.ammo_text() == "%d in hand  |  %d arrows" % [b.held, b.quiver], "the ammo line: '%s'" % b.ammo_text())
	return b


func _shoot(b: Bow) -> void:
	Input.action_press("fire")
	await _until(func() -> bool: return b.state == Bow.State.HOLDING, int(2.0 * HZ))
	Input.action_release("fire")
	await _frames(2)


func _volley(b: Bow) -> void:
	print("volley")
	var hand_nock := b.hand_nock_time * player.reload_time_mult
	for i in 3:
		var q := b.quiver
		await _shoot(b)
		_expect(b.quiver == q - 1 and b.state == Bow.State.NOCKING and b.held == 2 - i and is_equal_approx(b._nock_duration, hand_nock),
				"shot %d: nocked from the hand (%.2f s), %d left in it" % [i + 1, b._nock_duration, b.held])
		await _until(func() -> bool: return b.state == Bow.State.READY, int(2.0 * HZ))
	var refilled := await _until(func() -> bool: return b.held == b.hand_capacity, int((b.auto_grab_idle + b.grab_time + 0.5) * HZ))
	_expect(refilled, "let alone, the hand fills again (%d)" % b.held)


func _cut(b: Bow) -> void:
	print("cut")
	b.held = 0
	var grabbing := await _until(func() -> bool: return b.state == Bow.State.GRABBING, int(1.0 * HZ))
	_expect(grabbing, "with the hand empty a grab begins by itself")
	await _frames(int(b.grab_time * HZ * 0.7))
	Input.action_press("fire")
	await _frames(2)
	_expect(b.is_drawn() and b.held == 2, "a draw cuts the grab 70%% through: the draw on, 2 arrows pulled kept (%d)" % b.held)
	await _until(func() -> bool: return b.state == Bow.State.HOLDING, int(2.0 * HZ))
	Input.action_release("fire")
	await _until(func() -> bool: return b.state == Bow.State.READY, int(2.0 * HZ))


func _off(b: Bow) -> void:
	print("off")
	b.auto_hand = false
	b.held = 0
	await _frames(int((b.auto_grab_idle + b.grab_time + 0.3) * HZ))
	_expect(b.held == 0 and b.state == Bow.State.READY, "auto_hand off: the hand stays empty")
	await _tap("reload")
	await _frames(int(b.grab_time * HZ) + 20)
	_expect(b.held == b.hand_capacity, "R still fills it (%d)" % b.held)
	b.auto_hand = true


# ---------------------------------------------------------------- the arrows picked up
func _pickup(b: Bow) -> void:
	print("pickup")
	var p := _arrow_into(_ground_ahead(1.6, 0.5))    # (within E's reach: ThrownPickup.interact_radius from the chest)
	await _frames(int(0.8 * HZ))                 # (in the ground, and the pickup armed: ThrownPickup.arm_delay)
	var pk := _pickup_of(p)
	_expect(pk != null and pk.kind == ThrownPickup.ARROW and pk.is_armed() and p.max_life == Projectile.STUCK_LIFE_S,
			"a player's arrow stuck in the ground: an arrow pickup on it, kept %d s" % int(p.max_life if is_instance_valid(p) else 0.0))
	if pk == null:
		return
	_expect(pk.prompt(player) == "E  pick up arrow", "its prompt: '%s'" % pk.prompt(player))
	_expect(ThrownPickup.nearest_for(player) == pk, "the nearest pickup in reach (what E and the HUD name)")
	var q := b.quiver
	_expect(pk.try_give(player) and b.quiver == q + 1, "taken: into the quiver (%d -> %d)" % [q, b.quiver])
	await _frames(2)
	_expect(not is_instance_valid(p), "and the arrow gone from the ground")


func _bundle(b: Bow) -> void:
	print("bundle")
	var arrows: Array[Projectile] = []
	for i in 3:
		arrows.append(_arrow_into(_ground_ahead(3.0, -1.0 + 0.3 * i)))
	await _frames(int(0.8 * HZ))
	var pk := _pickup_of(arrows[0])
	_expect(pk != null and pk.prompt(player) == "E  pick up 3 arrows", "three close together: '%s'" % (pk.prompt(player) if pk else "no pickup"))
	if pk == null:
		return
	var q := b.quiver
	_expect(pk.try_give(player) and b.quiver == q + 3, "one press takes all three (%d -> %d)" % [q, b.quiver])
	await _frames(2)
	_expect(arrows.all(func(a: Variant) -> bool: return not is_instance_valid(a)), "and all three gone")    # (Variant: a freed one is no Projectile)


func _ghost() -> void:
	print("ghost")
	var p := _arrow_into(_ground_ahead(3.0, 2.0), true)
	await _frames(int(0.8 * HZ))
	_expect(is_instance_valid(p) and _pickup_of(p) == null and p.max_life == 30.0,
			"another player's arrow as seen here: no pickup, gone in 30 s")
	if is_instance_valid(p):
		p.queue_free()


func _cap() -> void:
	print("cap")
	var arrows: Array[Projectile] = []
	for i in Projectile.MAX_STUCK + 5:
		arrows.append(_arrow_into(_ground_ahead(4.0 + 0.25 * float(i / 10), -1.5 + 0.3 * float(i % 10))))
		if i % 10 == 9:
			await _frames(1)                     # (stuck in the order shot)
	await _frames(int(0.8 * HZ))
	var gone := 0
	for i in 5:
		gone += 0 if is_instance_valid(arrows[i]) else 1
	var kept := arrows.filter(func(a: Variant) -> bool: return is_instance_valid(a)).size()
	_expect(gone == 5 and kept == Projectile.MAX_STUCK,
			"%d stuck: the oldest %d gone, %d kept" % [Projectile.MAX_STUCK + 5, gone, kept])
	for a in arrows:
		if is_instance_valid(a):
			a.queue_free()


func _finish() -> void:
	Input.action_release("fire")
	if failures.is_empty():
		print("BOW HAND ARROWS TEST PASSED (%d checks)" % checks)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("BOW HAND ARROWS TEST FAILED (%d of %d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
