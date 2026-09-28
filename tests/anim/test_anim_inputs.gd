extends AnimTestSuite
## WP3 (plan section 6.3): AnimInputs.sample().
##   - works against a stub player without wish_local / target_speed (and without local_move,
##     get_aim_point, camera, is_dead): the fallbacks give player.gd's target speed (speed band,
##     weapon multiplier, aim cap) and the input-map wish, and are listed in `fallbacks`;
##   - edges: floor -> air with vy > 1 is "jumped", otherwise "fell"; air -> floor is "landed"
##     with impact = -(vy on the last airborne tick); air_time accumulates;
##   - aim elevation from the fixed chest height; to_dict() / from_dict() round trip;
##   - FrontierPlayer / Weapon have the members the sampler reads (script reflection; the level
##     is not loaded, see _real()).


class StubWeapon:
	extends RefCounted
	var aim := 0.0
	var busy := false

	func speed_mult() -> float:
		return 0.92 * (0.45 if busy else 1.0)

	func wants_aim() -> bool:
		return aim > 0.5

	func is_busy() -> bool:
		return busy

	func is_steady_aiming() -> bool:
		return false

	func charge_amount() -> float:
		return 0.25


## FrontierPlayer's members, minus wish_local / target_speed / local_move / get_aim_point / camera.
class StubPlayer:
	extends Node3D
	var velocity := Vector3.ZERO
	var is_crouching := false
	var is_walking := false
	var is_sprinting := false
	var run_speed := 3.6
	var walk_speed := 1.6
	var sprint_speed := 5.6
	var crouch_speed := 1.4
	var aim_walk_speed := 1.3
	var weapon_key := "musket"
	var weapon: StubWeapon = StubWeapon.new()
	var grounded := true
	var yaw := 0.0

	func is_on_floor() -> bool:
		return grounded


class AimStub:
	extends Node3D
	var target := Vector3.ZERO

	func get_aim_point() -> Vector3:
		return target


func describe() -> String:
	return "AnimInputs.sample(): stub-player fallbacks, air edges, aim elevation, round trip, FrontierPlayer members"


func timeout_s() -> float:
	return 90.0


func run(ctx: AnimTestContext) -> void:
	InputSetup.ensure()
	_bare(ctx)
	_fallbacks(ctx)
	await _edges(ctx)
	_aim(ctx)
	await _real(ctx)


func _bare(ctx: AnimTestContext) -> void:
	var n := Node3D.new()
	ctx.add_node(n)
	var s := AnimInputs.sample(n, null, 1.0 / 60.0)
	ctx.check(s != null and s.alive and s.on_floor and s.target_speed == 0.0 and s.events.is_empty(),
			"a bare Node3D samples without errors (alive, on floor, no speed, no events)")
	ctx.check(s.fallbacks.has("wish_local") and s.fallbacks.has("target_speed") and s.fallbacks.has("aim_point"),
			"bare node: fallbacks listed %s" % [s.fallbacks])
	var s0 := AnimInputs.sample(null, null, 1.0 / 60.0)
	ctx.check(s0 != null and s0.fallbacks.has("player"), "a null player gives a default sample")


func _fallbacks(ctx: AnimTestContext) -> void:
	var p := StubPlayer.new()
	ctx.add_node(p)
	var dt := 1.0 / 60.0
	var s := AnimInputs.sample(p, null, dt)
	ctx.check(s.target_speed == 0.0 and s.wish_local == Vector2.ZERO, "no input: target_speed 0, wish 0")
	Input.action_press("move_forward")
	s = AnimInputs.sample(p, s, dt)
	ctx.near(s.target_speed, 3.6 * 0.92, 1e-5, "run, musket (x0.92): target_speed = run_speed x speed_mult")
	ctx.near(s.wish_local, Vector2(0.0, 3.6 * 0.92), 1e-5, "wish_local = input (forward = +y) x target_speed")
	ctx.check(s.fallbacks.has("wish_local") and s.fallbacks.has("target_speed") and s.fallbacks.has("velocity_local"),
			"fallbacks listed %s" % [s.fallbacks])
	p.weapon.aim = 1.0
	s = AnimInputs.sample(p, s, dt)
	ctx.near(s.target_speed, 1.3, 1e-5, "aimed: capped to aim_walk_speed")
	ctx.check(s.wants_aim and is_equal_approx(s.weapon_aim, 1.0) and is_equal_approx(s.charge, 0.25), "weapon fields read (wants_aim, aim, charge)")
	p.weapon.aim = 0.0
	p.is_crouching = true
	s = AnimInputs.sample(p, s, dt)
	ctx.near(s.target_speed, 1.4 * 0.92, 1e-5, "crouched: crouch_speed x speed_mult")
	p.is_crouching = false
	p.is_sprinting = true
	s = AnimInputs.sample(p, s, dt)
	ctx.near(s.target_speed, 5.6, 1e-5, "sprinting: sprint_speed, no weapon multiplier")
	p.is_sprinting = false
	p.is_walking = true
	p.weapon.busy = true
	s = AnimInputs.sample(p, s, dt)
	ctx.near(s.target_speed, 1.6 * 0.92 * 0.45, 1e-5, "walking while busy: walk_speed x speed_mult (busy)")
	p.is_walking = false
	p.weapon.busy = false
	Input.action_release("move_forward")
	Input.action_press("move_left")
	Input.action_press("move_back")
	s = AnimInputs.sample(p, s, dt)
	var dir := Vector2(-1.0, -1.0).normalized()
	ctx.near(s.wish_local, dir * 3.6 * 0.92, 1e-4, "back-left: wish points back-left (x -, y -), length target_speed")
	Input.action_release("move_left")
	Input.action_release("move_back")
	# Analog (partial) input: target_speed stays the band speed (plan 8.1); only wish_local is
	# scaled by the input magnitude, as player.gd's velocity target wish.limit_length(1) * speed.
	Input.action_press("move_forward", 0.8)
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	s = AnimInputs.sample(p, s, dt)
	ctx.check(v.length() > 0.0 and v.length() < 0.999, "analog input: |input| = %.3f is partial" % v.length())
	ctx.near(s.target_speed, 3.6 * 0.92, 1e-5, "analog input: target_speed = band speed (not x |input|)")
	ctx.near(s.wish_local, Vector2(v.x, -v.y).limit_length(1.0) * 3.6 * 0.92, 1e-5,
			"analog input: wish_local = input x band speed (magnitude applied once)")
	Input.action_release("move_forward")
	# velocity_local from velocity and the body basis (no local_move member).
	p.rotation.y = PI * 0.5
	p.velocity = Vector3(-2.0, 0.0, 0.0)
	s = AnimInputs.sample(p, s, dt)
	ctx.near(s.velocity_local, Vector2(0.0, 2.0), 1e-5, "velocity_local: body turned 90 deg left, moving -X world = forward 2 m/s")
	ctx.near(s.speed, 2.0, 1e-5, "speed = |velocity_local|")
	p.yaw = 0.1
	var s2 := AnimInputs.sample(p, s, dt)
	ctx.near(s2.yaw_rate, 0.1 / dt, 1e-3, "yaw_rate from consecutive samples")
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO


func _edges(ctx: AnimTestContext) -> void:
	var p := StubPlayer.new()
	ctx.add_node(p)
	var dt := 1.0 / 60.0
	var s := AnimInputs.sample(p, null, dt)
	p.grounded = false
	p.velocity = Vector3(0.0, 4.4, 0.0)
	s = AnimInputs.sample(p, s, dt)
	ctx.check(s.events.size() == 1 and s.events[0].t == "jumped", "floor -> air with vy 4.4: jumped %s" % [s.events])
	for i in 20:
		p.velocity.y -= 9.8 * dt
		s = AnimInputs.sample(p, s, dt)
	ctx.near(s.air_time, 21 * dt, 1e-6, "air_time accumulates")
	var last_vy := p.velocity.y
	p.grounded = true
	p.velocity.y = 0.0
	s = AnimInputs.sample(p, s, dt)
	ctx.check(s.events.size() == 1 and s.events[0].t == "landed", "air -> floor: landed")
	ctx.near(float(s.events[0].get("impact", 0.0)), -last_vy, 1e-5, "landed impact = -(vy on the last airborne tick)")
	ctx.check(s.air_time == 0.0, "air_time resets on the floor")
	p.grounded = false
	p.velocity = Vector3(0.0, -0.3, 0.0)
	s = AnimInputs.sample(p, s, dt)
	ctx.check(s.events.size() == 1 and s.events[0].t == "fell", "floor -> air without a jump: fell")
	var d := s.to_dict()
	var back := AnimInputs.from_dict(JSON.parse_string(JSON.stringify(d)))
	ctx.check(JSON.stringify(back.to_dict()) == JSON.stringify(d), "to_dict / JSON / from_dict round trip")
	await ctx.frames(1)


func _aim(ctx: AnimTestContext) -> void:
	var a := AimStub.new()
	ctx.add_node(a)
	a.target = Vector3(0.0, 1.35 + 10.0, -10.0)
	var s := AnimInputs.sample(a, null, 1.0 / 60.0)
	ctx.near(s.aim_elev_deg, 45.0, 1e-4, "aim_elev_deg: chest (1.35 m standing) to aim point, 45 deg up")
	a.target = Vector3(0.0, 0.95, 5.0)
	s = AnimInputs.sample(a, null, 1.0 / 60.0, {"chest_height": {"stand": 0.95, "crouch": 0.5}})
	ctx.near(s.aim_elev_deg, 0.0, 1e-4, "aim_elev_deg uses cfg.chest_height")


## The members the sampler reads exist on FrontierPlayer / Weapon with the expected kinds. Checked
## on the scripts, without loading the level: today's (pre-WP6) player_anim.gd sets loop_mode on
## the shared actor_b animations when a player spawns, which would change the library for every
## suite that runs after this one in the same process (test_rig hashes it).
func _real(ctx: AnimTestContext) -> void:
	var player_script: Script = load("res://scripts/player/player.gd")
	var weapon_script: Script = load("res://scripts/weapons/weapon.gd")
	var props := {}
	for p in player_script.get_script_property_list():
		props[p.name] = true
	var methods := {}
	for m in player_script.get_script_method_list():
		methods[m.name] = true
	var need_props := ["local_move", "is_crouching", "is_walking", "is_sprinting", "weapon", "weapon_key", "yaw", "camera",
			"run_speed", "walk_speed", "sprint_speed", "crouch_speed", "aim_walk_speed"]
	var missing := []
	for n in need_props:
		if not props.has(n):
			missing.append(n)
	for n in ["get_aim_point", "aim_pitch"]:
		if not methods.has(n):
			missing.append(n + "()")
	ctx.check(missing.is_empty(), "FrontierPlayer has every member AnimInputs reads directly %s" % [missing])
	ctx.check(player_script.get_instance_base_type() == &"CharacterBody3D", "FrontierPlayer is a CharacterBody3D (velocity, is_on_floor())")
	ctx.info("FrontierPlayer wish_local / target_speed / is_dead: %s / %s / %s (fallbacks used while absent; WP7 adds them)" % [
			props.has("wish_local"), props.has("target_speed"), props.has("is_dead")])
	var wm := {}
	for m in weapon_script.get_script_method_list():
		wm[m.name] = true
	var wprops := {}
	for p in weapon_script.get_script_property_list():
		wprops[p.name] = true
	var wmiss := []
	for n in ["wants_aim", "is_steady_aiming", "is_busy", "charge_amount", "speed_mult"]:
		if not wm.has(n):
			wmiss.append(n + "()")
	if not wprops.has("aim"):
		wmiss.append("aim")
	ctx.check(wmiss.is_empty(), "Weapon has aim, wants_aim(), is_steady_aiming(), is_busy(), charge_amount(), speed_mult() %s" % [wmiss])
	await ctx.frames(1)
