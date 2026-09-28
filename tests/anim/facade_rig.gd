extends RefCounted
## WP6 test harness (not a suite; run_all only picks up test_*.gd): the whole PlayerAnim facade
## (TreeBuilder tree, LocoBrain, UpperBody, AimStabilizer, recorder) on the Actor_B rig, with the
## real weapon objects (Bow, Musket, FlintlockPistol) for their signals, driven by a small
## kinematic model of scripts/player/player.gd instead of the level (no FrontierPlayer: setup()
## gets a null player and set_input_source() supplies the AnimInputs of each frame).
##
##   const FacadeRig := preload("res://tests/anim/facade_rig.gd")
##   var h = FacadeRig.new()
##   if not h.setup(ctx): return
##   h.switch("musket")                     # unequip / set_weapon / equip, as player.gd does
##   h.run(60, Vector2(0, 1), 3.6)          # 60 frames holding forward at run speed
##   h.aiming = true; h.run(30)             # Weapon.aim eases in at the weapon's aim_in_time
##   h.action("reload_begin", 1.3)          # Weapon.action_started
##
## Kinematic player: ground accel 14 / decel 18 m/s^2, air accel 2.5, gravity 9.8, jump 4.4 m/s,
## edge events as AnimInputs.sample(). The rig faces +Z at the origin; the crosshair point is
## `aim_dist` m ahead at `elev_deg` from the stance's chest point.

const DT := 1.0 / 60.0
const WEAPON_KEYS := ["bow", "musket", "pistol"]
const DIRS := [Vector2.ZERO, Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
		Vector2(1, 0), Vector2(1, 1)]

var ctx: AnimTestContext
var rig: RigFixture
var anim: PlayerAnim
var weapons := {}
var weapon := "musket"
var dt := DT

## Kinematic player state (local plane: x right, y forward).
var vel := Vector2.ZERO
var y := 0.0
var vy := 0.0
var on_floor := true
var air_time := 0.0
var last_air_vy := 0.0
var yaw := 0.0
var crouched := false
var sprinting := false
var walking := false
var alive := true
## Upper body: aiming raises Weapon.aim at the weapon's aim_in_time (lowers at aim_out_time).
var aiming := false
var steady := false
var aim := 0.0
var charge := 0.0
var elev_deg := 0.0
var aim_dist := 25.0
var blocked_hit_m := INF
var accel := 14.0
var decel := 18.0
var air_accel := 2.5
var gravity := 9.8
var jump_v := 4.4

var frame := 0
var inp: AnimInputs


## opts: weapon (musket), exports ({PlayerAnim export: value}, set before setup), record (path).
func setup(p_ctx: AnimTestContext, opts := {}) -> bool:
	ctx = p_ctx
	rig = ctx.rig({"tree": false})
	if rig == null:
		return false
	for k in WEAPON_KEYS:
		var w: Weapon = {"bow": Bow, "musket": Musket, "pistol": FlintlockPistol}[k].new()
		w.name = "FacadeRig_" + k
		ctx.add_node(w)
		weapons[k] = w
	anim = PlayerAnim.new()
	anim.name = "PlayerAnim"
	anim.auto_process = false
	var ex: Dictionary = opts.get("exports", {})
	for k in ex:
		anim.set(k, ex[k])
	rig.root.add_child(anim)
	anim.setup(null, rig.ap, rig.sk, weapons)
	if not anim.is_ready():
		ctx.fail("PlayerAnim.setup() on the rig: %s" % [anim.setup_report.get("refused", "?")])
		return false
	anim.set_input_source(_source)
	if opts.has("record"):
		anim.start_recording(String(opts.record))
	inp = _make_inputs([])
	switch(String(opts.get("weapon", "musket")), true)
	return true


## Weapon switch as player.gd does it: old weapon's action_cancelled, set_weapon, equip.
func switch(key: String, first := false) -> void:
	if not first:
		weapons[weapon].action_cancelled.emit()
	weapon = key
	anim.set_weapon(key)
	aim = 0.0
	weapons[key].action_started.emit("equip", weapons[key].equip_time)


func fire() -> void:
	weapons[weapon].fired.emit()


func action(key: String, dur: float) -> void:
	weapons[weapon].action_started.emit(key, dur)


func cancel() -> void:
	weapons[weapon].action_cancelled.emit()


func _source(_f: int) -> Variant:
	return inp


## One frame: kinematics toward wish_dir x speed, inputs, PlayerAnim.manual_step.
## extra: {jump: bool}.
func step(wish_dir := Vector2.ZERO, speed := 0.0, extra := {}) -> void:
	frame += 1
	var wish := wish_dir.normalized() * speed if wish_dir.length() > 1e-6 else Vector2.ZERO
	var events: Array[Dictionary] = []
	var was_floor := on_floor
	if extra.get("jump", false) and on_floor and alive:
		vy = jump_v
		on_floor = false
	var a := accel if wish.length() > vel.length() else decel
	if not was_floor:
		a = air_accel
	vel = vel.move_toward(wish if alive else Vector2.ZERO, a * dt)
	if not on_floor and not was_floor:
		vy -= gravity * dt
	y += vy * dt
	if y <= 1e-6 and vy <= 0.0:
		y = 0.0
		on_floor = true
		vy = 0.0
	elif y > 1e-4:
		on_floor = false
	if not on_floor:
		air_time += dt
		last_air_vy = vy
	if was_floor and not on_floor:
		events.append({"t": "jumped" if vy > 1.0 else "fell"})
	elif not was_floor and on_floor:
		events.append({"t": "landed", "impact": -last_air_vy})
	if on_floor:
		air_time = 0.0
	var w: Weapon = weapons[weapon]
	var up := aiming and alive and not sprinting
	aim = move_toward(aim, 1.0 if up else 0.0, dt / maxf(w.aim_in_time if up else w.aim_out_time, 0.01))
	inp = _make_inputs(events, wish, speed if wish.length() > 0.0 else 0.0)
	anim.manual_step(dt)


func run(n: int, wish_dir := Vector2.ZERO, speed := 0.0, extra := {}) -> void:
	for i in n:
		step(wish_dir, speed, extra)


func _make_inputs(events: Array, wish := Vector2.ZERO, target := 0.0) -> AnimInputs:
	var s := AnimInputs.new()
	s.frame = frame
	s.dt = dt
	s.velocity_local = vel
	s.wish_local = wish
	s.target_speed = target
	s.speed = vel.length()
	s.vertical_speed = vy
	s.on_floor = on_floor
	s.air_time = air_time
	s.last_air_vy = last_air_vy
	for e in events:
		s.events.append(e)
	s.crouched = crouched
	s.walking = walking
	s.sprinting = sprinting
	s.alive = alive
	s.yaw = yaw
	s.weapon_key = StringName(weapon)
	s.weapon_aim = aim
	s.wants_aim = aiming and alive and not sprinting
	s.steady_aim = steady
	s.busy = false
	s.charge = charge
	var st := "crouch" if crouched else "stand"
	var chest := Vector3(0.0, y + anim.data.chest_height(st), 0.0)
	var d := Vector3(0.0, sin(deg_to_rad(elev_deg)), cos(deg_to_rad(elev_deg)))
	s.aim_point = rig.sk.global_transform * (chest + d * aim_dist)
	s.aim_elev_deg = elev_deg
	s.aim_pitch = deg_to_rad(elev_deg)
	s.blocked_hit_m = blocked_hit_m
	return s


## Core bones (the bones actor_b-p-run-fw keys; plan section 10 continuity).
func core_bones() -> PackedStringArray:
	return rig.keyed_bones("actor_b-p-run-fw")


## Weapon / player rules of scripts/player/player.gd and scripts/weapons/*.gd, in short.
class GameSim:
	## Random gameplay for FacadeRig (test_continuity, test_replay, test_facade): seeded, so a run is
	## reproducible. tick() before each FacadeRig.step(dir, speed(), extras).
	var h
	var rng := RandomNumberGenerator.new()
	var hold := 0
	var dir := Vector2.ZERO
	var spd := 3.6
	var yaw_rate := 0.0
	var want_sprint := false
	var want_aim := false
	var loaded := {"musket": true, "pistol": true}
	var stages := {"musket": 0, "pistol": 0}
	var reloading := false
	var stage_left := 0.0
	var equip_left := 0.0
	var nock_left := 0.0
	var grab_left := 0.0
	var dead_left := 0.0
	var fire_wait := 0.0

	func _init(p_h, seed: int) -> void:
		h = p_h
		rng.seed = seed

	## One gameplay tick before the animation frame; returns step extras ({jump}, {revive}).
	func tick() -> Dictionary:
		var dt: float = h.dt
		var ex := {}
		if dead_left > 0.0:
			dead_left -= dt
			if dead_left <= 0.0:
				h.alive = true
				h.anim.revive()
				ex["revive"] = true
			return ex
		if hold <= 0:
			hold = rng.randi_range(3, 90)
			dir = DIRS[rng.randi() % DIRS.size()]
			var r := rng.randf()
			spd = 1.6 if r < 0.3 else (3.6 if r < 0.85 else 5.6)
			want_sprint = spd > 5.0
			h.walking = spd < 2.0
			if rng.randf() < 0.07:
				h.crouched = not h.crouched
			if rng.randf() < 0.2:
				want_aim = not want_aim
			yaw_rate = rng.randf_range(-3.0, 3.0) if rng.randf() < 0.3 else 0.0
			h.elev_deg = clampf(h.elev_deg + rng.randf_range(-20.0, 20.0), -40.0, 40.0)
		hold -= 1
		h.yaw += yaw_rate * dt
		var w: String = h.weapon
		h.sprinting = want_sprint and dir.y > 0.1 and h.on_floor
		if h.sprinting:
			h.crouched = false
		if equip_left > 0.0:
			equip_left -= dt
		if rng.randf() < 0.0015:
			var nw: String = ["bow", "musket", "pistol"][rng.randi() % 3]
			if nw != w:
				reloading = false
				nock_left = 0.0
				grab_left = 0.0
				h.switch(nw)
				equip_left = h.weapons[nw].equip_time
				return ex
		if w == "bow":
			_bow(dt)
		else:
			_firearm(w, dt)
		var r2 := rng.randf()
		if r2 < 0.0012:
			h.anim.play_hit(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), rng.randf() < 0.4)
		elif r2 < 0.00135 and h.on_floor:
			h.alive = false
			h.aiming = false
			reloading = false
			h.anim.play_death(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)))
			dead_left = rng.randf_range(2.0, 4.0)
		if rng.randf() < 0.004 and h.on_floor:
			ex["jump"] = true
			h.crouched = false
			if reloading:
				reloading = false
				h.cancel()
		return ex

	func _firearm(w: String, dt: float) -> void:
		if reloading:
			h.aiming = false
			if h.sprinting or not h.on_floor:
				reloading = false
				h.cancel()
				return
			stage_left -= dt
			if stage_left <= 0.0:
				stages[w] += 1
				if stages[w] >= h.weapons[w].reload_stages.size():
					stages[w] = 0
					loaded[w] = true
					reloading = false
				else:
					_begin_stage(w)
			return
		h.aiming = want_aim and not h.sprinting and equip_left <= 0.0 and loaded[w]
		if h.aiming and h.aim >= 0.85 and rng.randf() < 0.02:
			h.fire()
			loaded[w] = false
			h.aiming = false
			fire_wait = 0.35 + rng.randf_range(0.0, 1.5)
		if not loaded[w] and not h.sprinting and h.on_floor and equip_left <= 0.0:
			fire_wait -= dt
			if fire_wait <= 0.0:
				reloading = true
				_begin_stage(w)

	func _begin_stage(w: String) -> void:
		var s: Array = h.weapons[w].reload_stages[stages[w]]
		stage_left = s[1]
		h.action(s[0], s[1])

	func _bow(dt: float) -> void:
		if nock_left > 0.0:
			nock_left -= dt
			h.aiming = false
			return
		if grab_left > 0.0:
			grab_left -= dt
			h.aiming = false
			if h.sprinting:
				grab_left = 0.0
				h.cancel()
			return
		var was: bool = h.aiming
		h.aiming = want_aim and not h.sprinting and equip_left <= 0.0
		if h.aiming:
			h.charge = minf(h.charge + dt / 0.6, 1.0)
			if h.charge > 0.2 and rng.randf() < 0.01:
				h.fire()
				h.charge = 0.0
				h.aiming = false
				want_aim = rng.randf() < 0.5
				nock_left = 0.35 if rng.randf() < 0.4 else 0.75
				h.action("nock", nock_left)
		else:
			h.charge = 0.0
			if not was and rng.randf() < 0.002:
				grab_left = 1.1
				h.action("grab", 1.1)

	## Ground speed the kinematic player heads for this tick.
	func speed() -> float:
		return 5.6 if h.sprinting else (1.4 if h.crouched else spd)

	## Direction to step toward (none while dead).
	func wish() -> Vector2:
		return dir if h.alive else Vector2.ZERO
