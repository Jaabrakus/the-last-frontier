extends SceneTree
## Headless gameplay smoke test. Loads the level, aims at the 25 m dummy and
## drives each weapon through fire -> reload with simulated input.
##
##   Godot --headless --path . -s tests/smoke_test.gd -- --no-capture

var player: FrontierPlayer
var failures := PackedStringArray()
var hits := 0

## The balanced spread cones (weapons balance hook H1: bow 1.1, musket 0.38, pistol 1.43 deg
## base) make the hit count a draw: each shot's spread is seeded just before the trigger is
## released (weapons_balance_design.md section 4: seed(1750) wherever randf() drives spread), so
## the check stays what it was, shots reaching the dummy through the real launch and spread code.
## Unseeded, 12 of 16 runs pass (tests/anim/README.md, "Smoke test hit count": pending a
## balance / owner decision).
const SPREAD_SEED := 1750


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") if current_scene else null
	if player == null:
		printerr("FAIL: level or player failed to load (see script errors above)")
		print("SMOKE TEST FAILED")
		quit(1)
		return
	player.ignore_mouse_capture = true
	add_to_group_listener()
	await _frames(30)

	# Aim at the 25 m dummy's chest (lane x = 0).
	await _frames(20)

	await _test_musket()
	await _test_pistol()
	await _test_bow()
	await _test_movement()

	print("hits registered: ", hits)
	if hits < 2:
		failures.append("expected at least 2 hits on the dummy, got %d" % hits)
	if failures.is_empty():
		print("SMOKE TEST PASSED")
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("SMOKE TEST FAILED")
	quit(0 if failures.is_empty() else 1)


func add_to_group_listener() -> void:
	var listener := Node.new()
	listener.set_script(_listener_script())
	listener.set_meta("test", self)
	current_scene.add_child(listener)


func _listener_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nfunc _ready():\n\tadd_to_group('hit_listeners')\nfunc on_projectile_hit(c, p):\n\tget_meta('test').on_hit(c, p)\nfunc on_target_killed(t):\n\tpass\n"
	s.reload()
	return s


func on_hit(collider: Object, pos: Vector3) -> void:
	if collider is Node and FrontierHUD._is_target(collider as Node):
		hits += 1
	print("  hit ", collider, " at ", pos.snapped(Vector3.ONE * 0.01))


## Aim the camera ray at the 25 m dummy's chest (lane x = 0). Recoil moves
## the view, so every test re-aims.
func _aim() -> void:
	await _aim_at(Vector3(0.0, 1.2, -20.0 - 25.0))


## The shoulder camera is offset from the body, so aim from the camera and
## repeat a few times as the camera moves with the new yaw.
func _aim_at(p: Vector3) -> void:
	for i in 4:
		var from := player.camera.global_position
		var d := p - from
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String, hold_frames := 3) -> void:
	Input.action_press(action)
	await _frames(hold_frames)
	Input.action_release(action)
	await _frames(2)


## Flintlocks: hold fire to shoulder the weapon, release to shoot. Aimed again once shouldered (the camera comes in
## as the weapon is raised, so an aim taken before it is off by the move), so the shot does not hang on how long
## what came before took (a shorter musket reload moved the pistol's shot off the dummy).
func _hold_and_release_fire() -> void:
	Input.action_press("fire")
	for i in 120:
		await physics_frame
		if player.weapon.aim >= 1.0:
			break
	await _aim()
	seed(SPREAD_SEED)
	Input.action_release("fire")
	await _frames(2)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
	print(("  ok   " if cond else "  FAIL ") + msg)


func _test_musket() -> void:
	print("musket")
	player.switch_weapon("musket")
	await _aim()
	var m := player.weapon as Musket
	await _frames(100)
	_expect(m.loaded and m.state == Firearm.State.READY, "musket starts loaded")
	_expect(m.aim == 0.0, "musket carried lowered when not aiming")
	Input.action_press("fire")
	await _frames(20)
	_expect(m.state == Firearm.State.AIMING and m.loaded, "holding fire shoulders without firing")
	await _tap("aim")
	await _frames(5)
	_expect(m.state == Firearm.State.READY and m.loaded, "RMB while holding fire lowers without firing")
	Input.action_release("fire")
	await _frames(40)
	_expect(m.loaded, "releasing fire after a cancel does not fire")
	Input.action_press("fire")
	await _frames(20)
	seed(SPREAD_SEED)
	Input.action_release("fire")
	await _frames(90)
	_expect(not m.loaded and m.state == Firearm.State.EMPTY, "musket empty after firing")
	var reserve := m.reserve
	await _tap("reload")
	_expect(m.state == Firearm.State.RELOADING, "reload started")
	var total := 0.0
	for s in m.reload_stages:
		total += s[1]
	await _frames(int(total * 120) + 30)
	_expect(m.loaded and m.reserve == reserve - 1, "musket reloaded, one cartridge used")

	# Interrupting keeps finished stages.
	await _aim()
	await _hold_and_release_fire()
	await _frames(60)
	await _tap("reload")
	await _frames(int((m.reload_stages[0][1] + 0.3) * 120))
	player.switch_weapon("pistol")
	await _frames(10)
	player.switch_weapon("musket")
	await _frames(100)
	_expect(m._stage >= 1, "interrupted reload remembers finished stages (stage %d)" % m._stage)


func _test_pistol() -> void:
	print("pistol")
	player.switch_weapon("pistol")
	await _aim()
	var p := player.weapon as FlintlockPistol
	await _frames(60)
	_expect(p.loaded, "pistol starts loaded")
	await _hold_and_release_fire()
	await _frames(60)
	_expect(not p.loaded, "pistol fired")
	await _tap("reload")
	var total := 0.0
	for s in p.reload_stages:
		total += s[1]
	await _frames(int(total * 120) + 30)
	_expect(p.loaded, "pistol reloaded")


func _test_bow() -> void:
	print("bow")
	player.switch_weapon("bow")
	await _aim()
	var b := player.weapon as Bow
	await _frames(80)
	var arrows := b.quiver
	Input.action_press("fire")
	await _frames(40)
	_expect(b.is_drawn(), "bow drawing while fire held")
	await _frames(60)
	_expect(b.state == Bow.State.HOLDING, "bow at full draw")
	seed(SPREAD_SEED)
	Input.action_release("fire")
	await _frames(5)
	_expect(b.quiver == arrows - 1, "arrow shot")
	await _frames(120)
	_expect(b.state == Bow.State.READY, "next arrow nocked")
	var before := b.quiver
	await _tap("reload")
	await _frames(int(b.grab_time * 120) + 20)
	_expect(b.held == b.hand_capacity and b.quiver == before, "R takes %d arrows into the bow hand" % b.hand_capacity)
	Input.action_press("fire")
	await _frames(90)
	seed(SPREAD_SEED)
	Input.action_release("fire")
	await _frames(5)
	_expect(b.state == Bow.State.NOCKING and b.held == b.hand_capacity - 1, "next arrow nocked from the hand")
	await _frames(int(b.hand_nock_time * 120) + 5)
	_expect(b.state == Bow.State.READY, "hand nock is quick (%.2f s)" % b.hand_nock_time)


func _test_movement() -> void:
	print("movement")
	var start := player.global_position
	Input.action_press("move_forward")
	await _frames(120)
	Input.action_release("move_forward")
	var moved := player.global_position.distance_to(start)
	_expect(moved > 2.0, "player moves forward (%.2f m)" % moved)
	Input.action_press("crouch")
	await _frames(30)
	_expect(player.is_crouching, "player crouches")
	Input.action_release("crouch")
	await _frames(30)
