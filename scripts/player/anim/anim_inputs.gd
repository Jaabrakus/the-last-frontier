class_name AnimInputs
extends RefCounted
## One physics tick of everything the animation controllers read from gameplay (plan section
## 6.3, WP3). PlayerAnim._physics_process (process_physics_priority 100, after the player) calls
##
##   inputs = AnimInputs.sample(player, inputs, delta, cfg)
##
## and queues inputs.events until its next _process consumes them. The sampler only reads the
## player and its weapon, by duck typing, so it works on FrontierPlayer and on test stubs; members
## the player does not have fall back (wish_local and target_speed are computed from the input
## map and the speed bands exactly as player.gd does, is_dead defaults to alive, ...).
## `fallbacks` lists which fields came from a fallback this tick.
##
## cfg (optional): {chest_height: {stand, crouch} (m; default 1.35 / 0.95, the tuning fallback;
## pass AnimGraphData.chest_height), blocked_len_m: {weapon: m} (default bow 0.9, musket 1.5,
## pistol 0.6), blocked: bool (cast the blocked ray; default true), jump_vy: float (vertical
## speed above which leaving the floor counts as a jump; default 1.0)}.
##
## Units: m, m/s, radians unless the name says deg. Local plane: x = right, y = forward.

const JUMP_VY := 1.0
const DEFAULT_CHEST := {"stand": 1.35, "crouch": 0.95}
const DEFAULT_BLOCKED_LEN := {"bow": 0.9, "musket": 1.5, "pistol": 0.6}
const MOVE_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]

var frame := 0
var dt := 0.0
## Horizontal velocity in the player's local plane (m/s; x right, y forward).
var velocity_local := Vector2.ZERO
## Movement wish in the local plane (m/s): input direction x the speed the player is heading for.
var wish_local := Vector2.ZERO
## Speed the player is heading for (after weapon multipliers and the aim cap); 0 without input.
var target_speed := 0.0
var speed := 0.0
var vertical_speed := 0.0
var on_floor := true
## Seconds since leaving the floor (0 on the floor).
var air_time := 0.0
## Vertical speed on the last airborne tick (impact speed = -last_air_vy).
var last_air_vy := 0.0
## Edges detected this tick: {t: "jumped"}, {t: "fell"}, {t: "landed", impact: float}.
var events: Array[Dictionary] = []
var crouched := false
var walking := false
var sprinting := false
var alive := true
## Camera pitch including recoil (rad), debug.
var aim_pitch := 0.0
## What the crosshair is on (world).
var aim_point := Vector3.ZERO
## Elevation (deg) from a fixed chest point (origin + up * chest height of the stance) to aim_point.
var aim_elev_deg := 0.0
var weapon_key := &""
var weapon_aim := 0.0
var wants_aim := false
var steady_aim := false
var busy := false
var charge := 0.0
## Distance to the first obstacle along the camera forward from the chest (INF when clear).
var blocked_hit_m := INF
var yaw := 0.0
var yaw_rate := 0.0
## Field names that came from a fallback this tick (wish_local, target_speed, ...).
var fallbacks := PackedStringArray()


## Samples `player` for this physics tick. prev: the previous sample (null on the first tick).
static func sample(player: Node, prev: AnimInputs, p_dt: float, cfg := {}) -> AnimInputs:
	var s := AnimInputs.new()
	s.frame = Engine.get_physics_frames()
	s.dt = p_dt
	if player == null:
		s.fallbacks.append("player")
		return s
	var weapon: Object = player.get("weapon") if "weapon" in player else null

	# Motion.
	var vel := Vector3.ZERO
	if "velocity" in player:
		vel = player.get("velocity")
	if "local_move" in player:
		s.velocity_local = player.get("local_move")
	elif player is Node3D:
		var b := (player as Node3D).global_basis
		s.velocity_local = Vector2(vel.dot(b.x), vel.dot(-b.z))
		s.fallbacks.append("velocity_local")
	s.speed = s.velocity_local.length()
	s.vertical_speed = vel.y
	s.on_floor = bool(player.call("is_on_floor")) if player.has_method("is_on_floor") else true
	s.crouched = bool(player.get("is_crouching")) if "is_crouching" in player else false
	s.walking = bool(player.get("is_walking")) if "is_walking" in player else false
	s.sprinting = bool(player.get("is_sprinting")) if "is_sprinting" in player else false
	s.alive = not bool(player.get("is_dead")) if "is_dead" in player else true

	# Wish and target speed (player.gd sets wish_local / target_speed once WP7 lands).
	var input := Vector2.ZERO
	var have_input := false
	if not ("wish_local" in player and "target_speed" in player):
		have_input = true
		for a in MOVE_ACTIONS:
			if not InputMap.has_action(a):
				have_input = false
		if have_input:
			input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Band speed (plan 6.3 / 8.1: target_speed = the band speed whenever there is input; the
	# analog magnitude scales wish_local only, as player.gd's `wish.limit_length(1.0) * speed`).
	var band := _fallback_target_speed(player, weapon, input, s)
	if "target_speed" in player:
		s.target_speed = float(player.get("target_speed"))
	else:
		s.target_speed = band
		s.fallbacks.append("target_speed")
	if "wish_local" in player:
		s.wish_local = player.get("wish_local")
	else:
		# Input.get_vector: y < 0 is forward; local plane y is forward.
		s.wish_local = Vector2(input.x, -input.y).limit_length(1.0) * band
		s.fallbacks.append("wish_local")

	# Air edges.
	var prev_floor := prev.on_floor if prev else s.on_floor
	s.air_time = 0.0 if s.on_floor else (prev.air_time if prev else 0.0) + p_dt
	s.last_air_vy = prev.last_air_vy if prev else 0.0
	if not s.on_floor:
		s.last_air_vy = s.vertical_speed
	if prev:
		var jump_vy := float(cfg.get("jump_vy", JUMP_VY))
		if prev_floor and not s.on_floor:
			s.events.append({"t": "jumped" if s.vertical_speed > jump_vy else "fell"})
		elif not prev_floor and s.on_floor:
			s.events.append({"t": "landed", "impact": -prev.last_air_vy})

	# Weapon.
	if "weapon_key" in player:
		s.weapon_key = StringName(str(player.get("weapon_key")))
	if weapon:
		s.weapon_aim = float(weapon.get("aim")) if "aim" in weapon else 0.0
		s.wants_aim = bool(weapon.call("wants_aim")) if weapon.has_method("wants_aim") else false
		s.steady_aim = bool(weapon.call("is_steady_aiming")) if weapon.has_method("is_steady_aiming") else false
		s.busy = bool(weapon.call("is_busy")) if weapon.has_method("is_busy") else false
		s.charge = float(weapon.call("charge_amount")) if weapon.has_method("charge_amount") else 0.0

	# Aim.
	s.aim_pitch = float(player.call("aim_pitch")) if player.has_method("aim_pitch") else float(player.get("pitch")) if "pitch" in player else 0.0
	var origin := (player as Node3D).global_position if player is Node3D else Vector3.ZERO
	var chest_h: Dictionary = cfg.get("chest_height", DEFAULT_CHEST)
	var chest := origin + Vector3.UP * float(chest_h.get("crouch" if s.crouched else "stand", DEFAULT_CHEST["crouch" if s.crouched else "stand"]))
	if player.has_method("get_aim_point"):
		s.aim_point = player.call("get_aim_point")
	else:
		var fwd := -(player as Node3D).global_basis.z if player is Node3D else Vector3.FORWARD
		s.aim_point = chest + fwd * 100.0
		s.fallbacks.append("aim_point")
	var d := s.aim_point - chest
	s.aim_elev_deg = rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))

	# Blocked ray (graph f32@C8+172 input): chest along the camera forward, weapon's length.
	s.blocked_hit_m = INF
	if bool(cfg.get("blocked", true)) and player is Node3D and (player as Node3D).is_inside_tree():
		var cam: Node3D = player.get("camera") if "camera" in player else null
		var lens: Dictionary = cfg.get("blocked_len_m", DEFAULT_BLOCKED_LEN)
		var length := float(lens.get(String(s.weapon_key), 0.0))
		if cam and length > 0.0:
			var dir := -cam.global_basis.z
			var q := PhysicsRayQueryParameters3D.create(chest, chest + dir * length)
			if player is CollisionObject3D:
				q.exclude = [(player as CollisionObject3D).get_rid()]
			var hit := (player as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				s.blocked_hit_m = chest.distance_to(hit.position)

	# Yaw.
	s.yaw = float(player.get("yaw")) if "yaw" in player else ((player as Node3D).rotation.y if player is Node3D else 0.0)
	if prev and p_dt > 0.0:
		s.yaw_rate = wrapf(s.yaw - prev.yaw, -PI, PI) / p_dt
	return s


## player.gd's target speed: speed band (crouch / sprint / walk / run), weapon multiplier (not
## when sprinting), aim cap toward aim_walk_speed by weapon.aim; 0 without input, and not scaled
## by the analog input magnitude (plan 8.1: target_speed = speed when the input is non-zero).
## Without speed band members, the current horizontal speed.
static func _fallback_target_speed(player: Node, weapon: Object, input: Vector2, s: AnimInputs) -> float:
	if input.length() <= 0.0:
		return 0.0
	if not "run_speed" in player:
		return s.speed
	var spd := float(player.get("run_speed"))
	if s.crouched and "crouch_speed" in player:
		spd = float(player.get("crouch_speed"))
	elif s.sprinting and "sprint_speed" in player:
		spd = float(player.get("sprint_speed"))
	elif s.walking and "walk_speed" in player:
		spd = float(player.get("walk_speed"))
	if not s.sprinting and weapon:
		if weapon.has_method("speed_mult"):
			spd *= float(weapon.call("speed_mult"))
		if "aim_walk_speed" in player and "aim" in weapon:
			spd = lerpf(spd, minf(spd, float(player.get("aim_walk_speed"))), float(weapon.get("aim")))
	return spd


## Fields as plain JSON-able values (recorder, debug snapshot).
func to_dict() -> Dictionary:
	return {"frame": frame, "dt": dt, "velocity_local": [velocity_local.x, velocity_local.y],
			"wish_local": [wish_local.x, wish_local.y], "target_speed": target_speed, "speed": speed,
			"vertical_speed": vertical_speed, "on_floor": on_floor, "air_time": air_time, "last_air_vy": last_air_vy,
			"events": events.duplicate(true), "crouched": crouched, "walking": walking, "sprinting": sprinting,
			"alive": alive, "aim_pitch": aim_pitch, "aim_point": [aim_point.x, aim_point.y, aim_point.z],
			"aim_elev_deg": aim_elev_deg, "weapon_key": String(weapon_key), "weapon_aim": weapon_aim,
			"wants_aim": wants_aim, "steady_aim": steady_aim, "busy": busy, "charge": charge,
			"blocked_hit_m": -1.0 if is_inf(blocked_hit_m) else blocked_hit_m, "yaw": yaw, "yaw_rate": yaw_rate,
			"fallbacks": Array(fallbacks)}


## Inverse of to_dict() (replay).
static func from_dict(d: Dictionary) -> AnimInputs:
	var s := AnimInputs.new()
	s.frame = int(d.get("frame", 0))
	s.dt = float(d.get("dt", 0.0))
	var v: Array = d.get("velocity_local", [0, 0])
	s.velocity_local = Vector2(float(v[0]), float(v[1]))
	var w: Array = d.get("wish_local", [0, 0])
	s.wish_local = Vector2(float(w[0]), float(w[1]))
	s.target_speed = float(d.get("target_speed", 0.0))
	s.speed = float(d.get("speed", 0.0))
	s.vertical_speed = float(d.get("vertical_speed", 0.0))
	s.on_floor = bool(d.get("on_floor", true))
	s.air_time = float(d.get("air_time", 0.0))
	s.last_air_vy = float(d.get("last_air_vy", 0.0))
	for e in d.get("events", []):
		s.events.append(e)
	s.crouched = bool(d.get("crouched", false))
	s.walking = bool(d.get("walking", false))
	s.sprinting = bool(d.get("sprinting", false))
	s.alive = bool(d.get("alive", true))
	s.aim_pitch = float(d.get("aim_pitch", 0.0))
	var ap: Array = d.get("aim_point", [0, 0, 0])
	s.aim_point = Vector3(float(ap[0]), float(ap[1]), float(ap[2]))
	s.aim_elev_deg = float(d.get("aim_elev_deg", 0.0))
	s.weapon_key = StringName(String(d.get("weapon_key", "")))
	s.weapon_aim = float(d.get("weapon_aim", 0.0))
	s.wants_aim = bool(d.get("wants_aim", false))
	s.steady_aim = bool(d.get("steady_aim", false))
	s.busy = bool(d.get("busy", false))
	s.charge = float(d.get("charge", 0.0))
	var b := float(d.get("blocked_hit_m", -1.0))
	s.blocked_hit_m = INF if b < 0.0 else b
	s.yaw = float(d.get("yaw", 0.0))
	s.yaw_rate = float(d.get("yaw_rate", 0.0))
	s.fallbacks = PackedStringArray(d.get("fallbacks", []))
	return s
