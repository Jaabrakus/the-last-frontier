class_name Footsteps
extends Node
## Footsteps, landings, jump push-offs, kit rattle and cloth rustle for the player.
## Added as a child of the player by frontier_level.gd. It only reads the player's public
## state (velocity, is_on_floor, is_crouching, is_sprinting, horizontal_speed, weapon).
##
## Steps: while on the floor and moving, distance is accumulated and a step plays every
## stride (walk 0.72 m, run 1.15, sprint 1.55, crouch 0.55), alternating left and right feet.
## The first step after starting to move comes at 40 % of a stride. The surface under the
## feet (a short ray down, see Sfx.surface_of) picks dirt, grass or wood; straw counts as
## grass and stone as dirt. Run and sprint steps sometimes rattle the kit (gear_jostle).
##
## Landings: after more than 0.12 s in the air, falling faster than 1.5 m/s, land_<surface>
## plays louder for harder falls (+8 dB from 2 to 7 m/s), with the kit rattling.
## Jumps: jump_takeoff on leaving the floor upward faster than 2 m/s.
## Cloth: cloth_move when crouching or standing up, starting a sprint, or steadying a
## firearm's aim (0.2 s cooldown).

const STRIDE := {"walk": 0.72, "run": 1.15, "sprint": 1.55, "crouch": 0.55}
const MIN_SPEED := 0.4
const RUN_SPEED := 2.4            ## Above this (and not sprinting / crouching) it's a run.
const FOOT_SPREAD := 0.12         ## Sideways offset of each foot.
const GEAR_CHANCE := {"run": 0.25, "sprint": 0.6}
const CLOTH_COOLDOWN := 0.2

var player: FrontierPlayer

var _acc := 0.0                   ## Distance since the last step.
var _moving := false
var _side := 1.0
var _was_floor := true
var _air_time := 0.0
var _fall_speed := 0.0            ## Fastest downward speed while airborne.
var _was_crouching := false
var _was_sprinting := false
var _was_steady := false
var _cloth_cd := 0.0


func _ready() -> void:
	if player == null:
		player = get_parent() as FrontierPlayer
	if player:
		_was_floor = player.is_on_floor()
		_was_crouching = player.is_crouching


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_cloth_cd -= delta
	var on_floor := player.is_on_floor()
	var speed := player.horizontal_speed()

	# Leaving and meeting the floor.
	if on_floor:
		if not _was_floor and _air_time > 0.12 and _fall_speed > 1.5:
			_land(_fall_speed)
			_acc = 0.0
			_moving = true
		_air_time = 0.0
		_fall_speed = 0.0
	else:
		if _was_floor and player.velocity.y > 2.0:
			_play("jump_takeoff", _feet())
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -player.velocity.y)
	_was_floor = on_floor

	# Steps.
	if on_floor and speed > MIN_SPEED:
		var gait := _gait(speed)
		var stride: float = STRIDE[gait]
		if not _moving:
			_moving = true
			_acc = 0.6 * stride
		_acc += speed * delta
		if _acc >= stride:
			_acc = fmod(_acc, stride)
			_step(gait)
	elif on_floor:
		_moving = false

	# Cloth.
	var steady := player.weapon != null and player.weapon.is_steady_aiming()
	if player.is_crouching != _was_crouching \
			or (player.is_sprinting and not _was_sprinting) \
			or (steady and not _was_steady):
		_cloth()
	_was_crouching = player.is_crouching
	_was_sprinting = player.is_sprinting
	_was_steady = steady


func _gait(speed: float) -> String:
	if player.is_crouching:
		return "crouch"
	if player.is_sprinting:
		return "sprint"
	return "run" if speed > RUN_SPEED else "walk"


func _step(gait: String) -> void:
	var pos := _feet() + player.global_basis.x * FOOT_SPREAD * _side
	_side = -_side
	Sfx.play_3d(StringName("step_%s_%s" % [surface(), gait]), pos, 0.0, 1.0, {"group": "steps", "max": 2})
	if randf() < float(GEAR_CHANCE.get(gait, 0.0)):
		_gear(3.0 if gait == "sprint" else 0.0)


func _land(fall_speed: float) -> void:
	var gain := 8.0 * clampf((fall_speed - 2.0) / 5.0, 0.0, 1.0)
	var pitch := 0.95 if fall_speed > 5.5 else 1.0
	Sfx.play_3d(StringName("land_" + surface()), _feet(), gain, pitch)
	_gear(3.0)


## Kit rattle at the hip: -18 dB with run steps, -15 with sprint steps and landings.
func _gear(gain_db: float) -> void:
	_play("gear_jostle", player.global_position + Vector3.UP * 0.9, gain_db, true)


func _cloth() -> void:
	if _cloth_cd > 0.0:
		return
	_cloth_cd = CLOTH_COOLDOWN
	_play("cloth_move", player.global_position + Vector3.UP * 1.2, 0.0, true)


func _play(id: String, pos: Vector3, gain_db := 0.0, follow := false) -> void:
	var opts := {}
	if follow:
		opts = {"follow": player, "offset": pos - player.global_position}
	Sfx.play_3d(StringName(id), pos, gain_db, 1.0, opts)


func _feet() -> Vector3:
	return player.global_position + Vector3.UP * 0.02


## Footstep surface under the player: dirt, grass or wood.
func surface() -> String:
	var from := player.global_position + Vector3.UP * 0.1
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.6)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "dirt" if Sfx.is_dirt(player.global_position) else "grass"
	match Sfx.surface_of(hit.collider, hit.position, hit.normal):
		"wood":
			return "wood"
		"dirt", "stone":
			return "dirt"
	return "grass"
