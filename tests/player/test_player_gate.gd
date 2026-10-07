extends SceneTree
## Round 3 MOVE's gate (smash_r3 spec §4.9, §14.1, §15): with no RingMoves on a body (the open world, the duel, the classic
## ring) the controllers are exactly today's. Headless:
##   the open world (scenes/main.tscn)  the player's ring_moves null and no take filter; his jump leaves at 4.4 m/s under the
##                world's 9.8 (about a 0.99 m apex); C is a toggle (tapped down, it stays down; tapped again, up); a second and
##                third Space in the air change nothing; the camera's arm 4.1 m and the field of view 52.5; BendKnock adds its
##                knocks (two of 3 m/s carry 6), air decay 0.8, ragdoll at 9 m/s; a fighter (the duel's kind) has no
##                RingMoves and jumps on its own GRAVITY 18 (5 m/s: about 0.69 m)
##                round 4 (READ): the camera centred and level (no ring camera variant, even one asked for); a bolt there
##                plays no flight voice (BendSounds.flight: arenas only)
##   an arena (scenes/ring.tscn, no match)  no PlayerTraversal, no PlayerGrip, no RingMoves
## METRIC gate_unchanged_ok. Last line "PLAYER GATE PASSED" or "PLAYER GATE FAILED".
##   Godot --headless --fixed-fps 60 --path . -s tests/player/test_player_gate.gd

const NAME := "PLAYER GATE"
const WATCHDOG_S := 400.0
const OWN_CFG := "user://player_gate_test.cfg"
const SPOT := Vector3(-30.0, 0.0, 30.0)

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"
	seed(1750)
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _tap(a: StringName) -> void:
	p.controls.set_held(a, true)
	await physics_frame
	p.controls.set_held(a, false)


func _run() -> void:
	await _open_world()
	await _arena()
	print("METRIC gate_unchanged_ok %s" % fails.is_empty())
	_end()


func _end() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


func _open_world() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 200:
		await physics_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene != null else null
	_expect(p != null, "the open world and its player")
	if p == null:
		return
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	_expect(p.ring_moves == null and RingMoves.of(p) == null and BendStatus.take_filters.is_empty() and not RingRules.stock_on(),
			"the open world: no RingMoves, no take filter, the gate off")
	_expect(is_equal_approx(p.cam_distance_now(), 4.1) and is_equal_approx(p.fov, 52.5), "the camera: arm 4.1 m, field of view 52.5")
	# (round 4, READ: the ring camera's variants and the flight voices never reach the open world)
	RingCamera.override = "high"
	await physics_frame
	var cam_ok := is_equal_approx(p.spring_arm.position.x, p.shoulder_offset) and is_equal_approx(p.cam_shoulder_now(), p.shoulder_offset) \
			and p.camera_tilt.rotation == Vector3.ZERO and p.camera.global_basis.is_equal_approx(p.camera_pivot.global_basis) \
			and is_equal_approx(p.spring_arm.spring_length, 4.1)
	RingCamera.override = ""
	print("METRIC open_world_cam_unchanged_ok %s" % cam_ok)
	_expect(cam_ok, "the camera centred and level, the ring's variants never read (even one asked for)")
	BendSounds.voices_headless = true
	var n0 := BendSounds.flights_started
	var from := p.global_position + Vector3(0.0, 1.4, 0.0)
	var bolt := BendBolt.launch(p, from, Vector3(1.0, 0.2, 0.0).normalized(), {"kind": "fire", "mps": 20.0, "damage": 10.0,
			"knock_mps": 2.0, "range_m": 30.0})
	await physics_frame
	var silent := not BendSounds.arena_on(self) and BendSounds.flights_started == n0 and BendSounds.flight_voice_of(bolt) == null \
			and BendSounds.flight_voices() == 0
	bolt.end("test")
	BendSounds.voices_headless = false
	print("METRIC open_world_silent_ok %s" % silent)
	_expect(silent, "an open-world bolt plays no flight voice (no arena)")
	# the jump: 4.4 m/s at the world's 9.8
	var at := _ground(SPOT.x, SPOT.z)
	p.global_position = at + Vector3.UP * 0.1
	p.velocity = Vector3.ZERO
	await _until(func() -> bool: return p.is_on_floor(), 2.0)
	await _secs(0.3)
	var y0 := p.global_position.y
	await _tap(&"jump")
	var v0 := p.velocity.y
	var top := y0
	var vy_apex := 0.0
	var thirds := true
	for i in 240:
		await physics_frame
		top = maxf(top, p.global_position.y)
		if absf(p.velocity.y) < 0.1 and vy_apex == 0.0:
			vy_apex = 1.0
			# a second and third Space in the air: nothing
			var before := p.velocity.y
			await _tap(&"jump")
			await _tap(&"jump")
			thirds = p.velocity.y < before
		if i > 10 and p.is_on_floor():
			break
	_expect(absf(v0 - 4.4) < 0.01 and absf(top - y0 - 0.988) < 0.06 and thirds,
			"his jump: %.2f m/s, %.3f m up (4.4 at 9.8: about 0.99); Space again in the air: nothing" % [v0, top - y0])
	# C is a toggle
	await _secs(0.3)
	await _tap(&"crouch")
	await _secs(0.3)
	var down := p.is_crouching
	await _tap(&"crouch")
	await _secs(0.3)
	_expect(down and not p.is_crouching, "C toggles the crouch (down after a tap, up after the next)")
	# BendKnock: adds, decays 0.8 in the air, ragdoll at 9
	var kn := BendKnock.of(p)
	kn.reset()
	_expect(is_equal_approx(BendKnock.ragdoll_mps, 9.0) and is_equal_approx(BendKnock.AIR_DECEL, 0.8)
			and is_zero_approx(BendKnock.gravity_override), "BendKnock: ragdoll at 9 m/s, air decay 0.8, the world's gravity")
	kn.knock(Vector3(3.0, 0.0, 0.0), null)
	kn.knock(Vector3(3.0, 0.0, 0.0), null)
	_expect(absf(kn.kv.length() - 6.0) < 0.01, "BendKnock adds its knocks (two of 3 m/s: %.2f)" % kn.kv.length())
	kn.reset()
	await _secs(0.5)
	# a fighter (the duel's kind): no RingMoves, its own GRAVITY 18
	var fat := _ground(SPOT.x + 6.0, SPOT.z)
	var sq := NpcSquad.spawn(current_scene, "militia", 1, fat, {"seed": 1750, "face": fat + Vector3.FORWARD * 5.0})
	await _ticks(6)
	var f: NpcFighter = sq.members[0] if sq != null and not sq.members.is_empty() else null
	_expect(f != null and f.ring_moves == null and RingMoves.of(f) == null, "a fighter: no RingMoves")
	if f != null:
		f.held = false
		f._think_t = 1e9
		await _until(func() -> bool: return f.is_on_floor(), 2.0)
		await _secs(0.3)
		var fy0 := f.global_position.y
		var jumped := f.jump(5.0)
		var ftop := fy0
		for i in 240:
			await physics_frame
			ftop = maxf(ftop, f.global_position.y)
			if i > 10 and f.is_on_floor():
				break
		_expect(jumped and absf(ftop - fy0 - 25.0 / 36.0) < 0.06, "the fighter's jump on its own gravity 18: %.3f m (about 0.69)" % (ftop - fy0))


func _arena() -> void:
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 12:
		await process_frame
	var lvl := current_scene as RingLevel
	var ap: FrontierPlayer = lvl.player if lvl != null else null
	_expect(ap != null and ap.arena and ap.traversal == null and ap.grip == null and ap.ring_moves == null,
			"an arena (the bare ring): no traversal, no grip, no RingMoves")
	await _secs(0.3)
