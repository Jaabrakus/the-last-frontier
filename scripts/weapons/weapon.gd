class_name Weapon
extends Node
## Shared weapon logic: CS-style spread, projectile launch, animation clip
## table and the "action" channel (equip, nock, reload stages) that the
## player's AnimationTree plays on the upper body.
##
## Spread is a cone in degrees built from stance and movement. It eases
## toward its target so the crosshair blooms and recovers smoothly.

signal fired
## An upper-body action started: `key` looks up a clip in `clips`, `duration`
## is how long the gameplay step takes (the clip is time-scaled to fit).
signal action_started(key: String, duration: float)
signal action_cancelled

enum Hand { LEFT, RIGHT }

@export var display_name := "Weapon"
@export var hand := Hand.RIGHT
@export var equip_time := 0.45
@export var move_speed_mult := 1.0     ## While this weapon is out.
@export var busy_speed_mult := 0.55    ## While drawing / reloading.

@export_group("Aim")
@export var aim_in_time := 0.3         ## Seconds to bring the weapon up from the relaxed carry.
@export var aim_out_time := 0.3        ## Seconds to lower it again.
## Calibration so the weapon points at the crosshair: each aim clip bakes a
## stance in which the weapon sits a few degrees off the body's facing. While
## aimed, the character turns by the yaw offset and the aim-pitch layer is
## shifted by the pitch offset. Measured with tests/aim_alignment.gd.
@export var aim_yaw_offset_deg := 0.0
@export var aim_pitch_offset_deg := 0.0
@export var aim_yaw_offset_crouch_deg := 0.0
@export var aim_pitch_offset_crouch_deg := 0.0
@export var aim_move_mult := 1.0       ## Extra speed multiplier at full aim (the player also caps aimed speed to the aim-walk clips).

@export_group("Spread (degrees)")
@export var spread_base := 0.3
@export var spread_move := 2.5         ## Added at run speed; scales with speed.
@export var spread_air := 6.0
@export var crouch_mult := 0.65
@export var aim_mult := 1.0            ## Multiplier while steady-aiming (RMB).
@export var spread_unaimed := 3.0      ## Added when fully lowered; fades out quadratically as you aim in.
@export var fire_bloom := 1.5
@export var spread_response := 12.0

## Animation clip names (without library prefix). Keys the AnimationTree uses:
## aim, up, down, fire (+ "_crouch" variants), plus any action keys.
var clips := {}
## Relaxed carry while not aiming: arm-pose clips laid over locomotion, with
## the layer weights authored in the bundled weapon-base overlays.
## Keys idle / walk / run / sprint / crouch_idle / crouch_walk -> [clip, weight].
var relaxed := {}
## 0 = weapon lowered (relaxed carry), 1 = fully aimed. Drives the anim layers.
var aim := 0.0
## The hands are not ready for the aim yet (HandHolds, push n01c: the torch being tossed, the long gun still in the
## left hand): the aim waits.
var aim_hold := false
var player: FrontierPlayer
var model: Node3D
var muzzle: Marker3D
var spread := 3.0
var active := false
## Turned round and held as a club (GatherTools.club, a long gun): no fire, aim or reload input while so.
var clubbed := false

var _bloom := 0.0
var _equip_left := 0.0
var _input_on_since := -1              ## physics frame the fire input came on, unbroken since (-1 off): _fire_input_steady
var _input_tick := -1                  ## physics frame of the last tick


func equip() -> void:
	active = true
	if model:
		model.visible = true
	_equip_left = equip_time
	_on_equip()
	action_started.emit("equip", equip_time)


## Back in the hand without its draw (push n01c: the long gun from the left hand, where the quick throwables kept it;
## QuickOffhand): usable after `seconds`, no draw clip.
func equip_quick(seconds: float) -> void:
	active = true
	if model:
		model.visible = true
	_equip_left = seconds
	_on_equip()


func unequip() -> void:
	active = false
	aim = 0.0
	if model:
		model.visible = false
	_on_unequip()
	action_cancelled.emit()


func tick(delta: float) -> void:
	_equip_left = maxf(_equip_left - delta, 0.0)
	_track_input()
	_tick(delta)
	var up := wants_aim() and not aim_hold
	aim = move_toward(aim, 1.0 if up else 0.0, delta / maxf(aim_in_time if up else aim_out_time, 0.01))
	_bloom = move_toward(_bloom, 0.0, delta * 5.0)
	spread = lerpf(spread, target_spread(), 1.0 - exp(-spread_response * delta))


func is_equipping() -> bool:
	return _equip_left > 0.0


## The spread a shot would have right now, in degrees.
func target_spread() -> float:
	var s := spread_base + _extra_spread() + spread_unaimed * pow(1.0 - aim, 2.0)
	s += spread_move * clampf(player.horizontal_speed() / player.run_speed, 0.0, 1.5)
	if not player.is_on_floor():
		s += spread_air
	if player.is_crouching:
		s *= crouch_mult
	if is_steady_aiming():
		s *= aim_mult
	s *= player.aim_spread_mult      # too much drink (Vices: the core's spread_mult)
	return s + _bloom


func speed_mult() -> float:
	return move_speed_mult * (busy_speed_mult if is_busy() else 1.0) * lerpf(1.0, aim_move_mult, aim)


# --- Overridables -----------------------------------------------------------

func _tick(_delta: float) -> void:
	pass

func _on_equip() -> void:
	pass

func _on_unequip() -> void:
	pass

func _extra_spread() -> float:
	return 0.0

## True while the weapon should be raised to the aim pose.
func wants_aim() -> bool:
	return false

## Drawing, reloading... slows you down and blocks sprinting.
func is_busy() -> bool:
	return false

func can_sprint() -> bool:
	return not is_busy()

func is_steady_aiming() -> bool:
	return false

## Aim calibration for the current stance (see aim_yaw_offset_deg).
func aim_yaw_offset() -> float:
	return aim_yaw_offset_crouch_deg if player.is_crouching else aim_yaw_offset_deg


func aim_pitch_offset() -> float:
	return aim_pitch_offset_crouch_deg if player.is_crouching else aim_pitch_offset_deg


## Camera FOV multiplier (steady-aim zoom).
func fov_mult() -> float:
	return 1.0

## 0..1 draw/charge amount for the animation layer (bow only).
func charge_amount() -> float:
	return 0.0

## Short state line for the HUD.
func status_text() -> String:
	return ""

func ammo_text() -> String:
	return ""

## Progress bar for the HUD: [label, 0..1], or [] for none.
func progress() -> Array:
	return []


# --- Helpers -----------------------------------------------------------------

## Launches a projectile at the crosshair. With `zero_speed` > 0 the shot is
## "zeroed": it leaves on the arc that a projectile of that speed needs to land
## exactly on the crosshair point (so drop is compensated), before spread.
func _launch(kind: Projectile.Kind, speed: float, gravity: float, drag: float, damage: float, zero_speed := -1.0) -> Projectile:
	var origin := shot_origin(launch_origin())
	var target := player.get_aim_point()
	var dir := (target - origin).normalized()
	if zero_speed > 0.0:
		dir = ballistic_dir(origin, target, zero_speed, gravity, drag)
	dir = apply_spread(dir, deg_to_rad(spread))
	var p := Projectile.new()
	p.kind = kind
	p.velocity = dir * speed
	p.gravity = gravity
	p.drag = drag
	p.damage = damage
	p.exclude = [player.get_rid()]
	p.shooter = player
	player.get_tree().current_scene.add_child(p)
	p.global_position = origin
	p.look_at(origin + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	_bloom += fire_bloom
	fired.emit()
	NetSession.shot(player, p, false)       # (the others see it fly)
	return p


## Launch direction for which a projectile integrated like Projectile (per
## physics tick: gravity, then drag, then move) passes through `target`.
## Newton iteration on the elevation angle. A target the solve misses (out of reach, or steeper
## down than its clamp) takes BallisticsUtil.fallback_elevation (weapons balance hook H3): a
## reachable target is met by bisection, an unreachable one gets the longest-carry elevation
## (never flatter than the aim line), so a full-power shot past its reach falls short at max carry.
static func ballistic_dir(origin: Vector3, target: Vector3, speed: float, gravity: float, drag: float) -> Vector3:
	var to := target - origin
	var flat := Vector3(to.x, 0.0, to.z)
	var dist := flat.length()
	if dist < 1.0 or (gravity <= 0.0 and drag <= 0.0):
		return to.normalized()
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var theta := atan2(to.y, dist)
	for i in 8:
		var miss := _height_at(dist, theta, speed, gravity, drag, dt) - to.y
		if is_nan(miss) or absf(miss) < 0.002:
			break
		var slope := (_height_at(dist, theta + 0.001, speed, gravity, drag, dt) - to.y - miss) / 0.001
		if is_nan(slope) or absf(slope) < 1e-6:
			break
		theta = clampf(theta - miss / slope, -1.55, 1.55)
	var h := _height_at(dist, theta, speed, gravity, drag, dt)
	if is_nan(h) or absf(h - to.y) > 0.05:   # missed: out of reach, or steeper down than the clamp
		theta = BallisticsUtil.fallback_elevation(dist, to.y, theta, speed, gravity, drag)
	return (flat / dist * cos(theta) + Vector3.UP * sin(theta)).normalized()


static func _height_at(dist: float, theta: float, speed: float, g: float, drag: float, dt: float) -> float:
	var vx := cos(theta) * speed
	var vy := sin(theta) * speed
	var x := 0.0
	var y := 0.0
	for step in 6000:
		vy -= g * dt
		var k := maxf(1.0 - drag * dt, 0.0)
		vx *= k
		vy *= k
		var nx := x + vx * dt
		var ny := y + vy * dt
		if nx >= dist:
			return y + (ny - y) * (dist - x) / (nx - x)
		x = nx
		y = ny
		if vx < 0.5:
			break
	return NAN


## A shot's start kept on the shooter's side of a wall (user 2026-10-01: "if a gun pokes through a wall they can fire"): from the
## chest (its spine bone, or 1.35 m up from the feet) to `origin`; anything solid between them (the player excluded) and the shot
## starts just short of it, so it strikes that wall rather than leaving from the muzzle beyond it.
func shot_origin(origin: Vector3) -> Vector3:
	if player == null or not player.is_inside_tree():
		return origin
	var chest := player.global_position + Vector3.UP * 1.35
	if player.skeleton != null:
		var b := player.skeleton.find_bone("spined")
		if b >= 0:
			chest = player.skeleton.global_transform * player.skeleton.get_bone_global_pose(b).origin
	var q := PhysicsRayQueryParameters3D.create(chest, origin)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return origin
	return (hit.position as Vector3) + (chest - origin).normalized() * 0.05


## Where shots leave from. Firearms: the muzzle. The bow overrides this with
## the tip of the arrow drawn on the string.
func launch_origin() -> Vector3:
	return muzzle.global_position


## Random direction inside a cone. Center-weighted like CS inaccuracy:
## most shots land near the middle, a few reach the edge.
static func apply_spread(dir: Vector3, cone: float) -> Vector3:
	if cone <= 0.0:
		return dir
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 1e-4:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var r := tan(cone) * randf()
	var phi := randf() * TAU
	return (dir + side * cos(phi) * r + up * sin(phi) * r).normalized()


## The fire input's unbroken run (_fire_input_steady), kept at each tick: a tick with the input off ends it, and so does a
## tick missed (the tree paused under a story card or the pause menu, the weapon slung or put away).
func _track_input() -> void:
	var f := Engine.get_physics_frames()
	if not _fire_input_enabled():
		_input_on_since = -1
	elif _input_on_since < 0 or _input_tick < f - 1:
		_input_on_since = f
	_input_tick = f


## The fire input on, and on since the tick before this one (bug pass 2026-10-03, the musket that fired by itself): the
## Input singleton sees every click, the GUI's too, so the click that closed a story card, a dialogue or the Tab screen,
## or that took the mouse back, reads as a fire press on the first tick the input is back. That press is not the weapon's.
func _fire_input_steady() -> bool:
	return _input_on_since >= 0 and _input_on_since < Engine.get_physics_frames() and _fire_input_enabled()


## The aim button (RMB) is this weapon's: fire input enabled and no Sway spell readied (an expert's spell readied with a
## pistol or a tomahawk in the right hand: the RMB is the spell's lock, the LMB still the weapon's, "cast and shoot in the
## same breath"; SwayCaster.SPELL_META).
func _aim_input_enabled() -> bool:
	return _fire_input_enabled() and not (player != null and player.has_meta(&"sway_spell"))


func _fire_input_enabled() -> bool:
	# (and only while this weapon is out: a slung weapon takes no fire / aim input; nor while the torch mode has the
	# mouse, PlayerTorch.blocks_fire; nor while a vault or climb plays, the weapon kept in the hand through it:
	# PlayerTraversal.keep_weapon)
	# (and only for this machine's player: another player's weapons, an AI's or the network's, never take this
	# keyboard's fire: FrontierPlayer.is_local)
	# (a Sway spell readied, an expert's pistol or tomahawk in the other hand: it still fires (LMB), its aim is the spell's:
	# _aim_input_enabled)
	return active and not clubbed and not (player != null and player.hands_free) \
			and (player == null or not ("is_local" in player) or player.is_local) \
			and not (player != null and player.get("traversal") != null and player.traversal.showing) \
			and not (player != null and player.get("equip_wheel") != null and player.equip_wheel.blocks_fire()) \
			and not (player != null and player.get("torch") != null and player.torch.blocks_fire()) \
			and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or player.ignore_mouse_capture)
