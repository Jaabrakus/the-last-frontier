class_name Firearm
extends Weapon
## Single-shot muzzle-loading flintlock (musket or pistol).
##
## The weapon is carried lowered (relaxed idle). Hold LMB to shoulder it and
## release to fire, like the bow: a release before the weapon is up fires as
## soon as it gets there. The flint strikes, the pan flashes, and after a
## short hang-fire the main charge goes off with a big cloud of smoke. Then
## the weapon is empty. R (or LMB while empty) starts the reload, a sequence of stages that
## each play an upper-body animation. Sprinting, jumping or switching weapons
## interrupts it, and you keep the stages you already finished (a musket that
## already has powder poured doesn't need it again).
## RMB raises and steadies the aim without firing: tighter spread, slight
## zoom, slower movement. While LMB is held, RMB or R cancels the shot and
## lowers the weapon.

enum State { READY, AIMING, HANGFIRE, RECOIL, EMPTY, RELOADING }

## The player lowered a shouldered weapon without firing (RMB or R while holding LMB).
signal shot_cancelled

## Sound hook (scripts/audio/weapon_audio.gd): &"lock" when the flint falls (at the pan),
## &"dry" when the lock snaps with no cartridges left (at the weapon).
signal sfx(id: StringName, at: Vector3)

@export_group("Shot")
@export var damage := 100.0
@export var muzzle_speed := 180.0
@export var ball_gravity := 9.8
@export var ball_drag := 0.35
@export var hang_fire := 0.09          ## Pan flash -> main charge.
@export var recoil_time := 0.35
@export var recoil_pitch_deg := 4.0
@export var recoil_yaw_deg := 0.8
@export var smoke_scale := 1.0
@export var pan_distance := 1.0        ## Lock/pan position behind the muzzle.
## The view's tremble kick on the shot (CameraShake.kick: 0..1 and its seconds; the bow hold's kind of shake; user 2026-10-01 "a camera shake on musket fire and pistol fire").
@export var fire_shake := 0.35
@export var fire_shake_s := 0.3

@export_group("Trigger")
## Hold to aim, release to fire. Off = the shot goes as soon as the weapon is up.
@export var fire_on_release := true
@export var ready_aim := 0.85          ## Aim amount needed before the shot can go off.

@export_group("Ammo")
@export var reserve := 12              ## Cartridges (ball + powder) carried.
@export var loaded := true

@export_group("Steady aim")
@export var aim_fov_mult := 0.8
@export var aim_speed_mult := 0.5

## Reload stages: [anim key, seconds, HUD label].
var reload_stages: Array = []

var state := State.READY
var _timer := 0.0
var _stage := 0                        ## Next reload stage to perform.
var _stage_left := 0.0
var _reload_queued := false            ## R pressed during recoil.
var _release_queued := false           ## Fire released before the weapon was up.


func _init() -> void:
	busy_speed_mult = 0.45


func is_busy() -> bool:
	return state == State.RELOADING


func is_steady_aiming() -> bool:
	return active and _fire_input_enabled() and Input.is_action_pressed("aim") \
			and state != State.RELOADING and state != State.EMPTY and not player.is_sprinting


func wants_aim() -> bool:
	if not active or player.is_sprinting or is_equipping():
		return false
	match state:
		State.AIMING, State.HANGFIRE, State.RECOIL:
			return true
		State.READY:
			return is_steady_aiming()
	return false


## Sprinting interrupts a reload (finished stages are kept) and lowers an
## aimed weapon; only the instant of firing blocks it.
func can_sprint() -> bool:
	return state != State.HANGFIRE


func speed_mult() -> float:
	var m := super.speed_mult()
	if is_steady_aiming():
		m *= aim_speed_mult
	return m


func fov_mult() -> float:
	return aim_fov_mult if is_steady_aiming() else 1.0


func _on_unequip() -> void:
	if state == State.RELOADING:
		_interrupt_reload()
	elif state == State.AIMING:
		state = State.READY
	elif state == State.HANGFIRE or state == State.RECOIL:
		# The shot already went (or is going) off; don't lose it on a quick swap.
		if state == State.HANGFIRE:
			_discharge()
		state = State.EMPTY if not loaded else State.READY


func _tick(delta: float) -> void:
	var enabled := _fire_input_enabled()
	match state:
		State.READY:
			if enabled and Input.is_action_just_pressed("fire") and not is_equipping() \
					and not player.is_sprinting and loaded:
				state = State.AIMING
				_release_queued = not fire_on_release
		State.AIMING:
			if player.is_sprinting or is_equipping():
				state = State.READY
				return
			# Cancel: RMB or R while shouldering lowers the weapon without firing
			# (a new LMB press is needed to raise it again).
			if enabled and (Input.is_action_just_pressed("aim") or Input.is_action_just_pressed("reload")):
				_release_queued = false
				state = State.READY
				shot_cancelled.emit()
				return
			if not (enabled and Input.is_action_pressed("fire")):
				_release_queued = true
			if _release_queued and aim >= ready_aim:
				_release_queued = false
				_pull_trigger()
		State.HANGFIRE:
			_timer -= delta
			if _timer <= 0.0:
				_discharge()
		State.RECOIL:
			if enabled and Input.is_action_just_pressed("reload"):
				_reload_queued = true
			_timer -= delta
			if _timer <= 0.0:
				state = State.EMPTY
				if _reload_queued:
					_reload_queued = false
					start_reload()
		State.EMPTY:
			if enabled and (Input.is_action_just_pressed("reload") or Input.is_action_just_pressed("fire")) \
					and not is_equipping():
				if reserve <= 0 and Input.is_action_just_pressed("fire"):
					sfx.emit(&"dry", model.global_position if model else player.global_position)
				start_reload()
		State.RELOADING:
			if player.is_sprinting or not player.is_on_floor():
				_interrupt_reload()
				return
			_stage_left -= delta
			if _stage_left <= 0.0:
				_stage += 1
				if _stage >= reload_stages.size():
					_finish_reload()
				else:
					_begin_stage()


func start_reload() -> void:
	if loaded or reserve <= 0 or state == State.RELOADING:
		return
	state = State.RELOADING
	_begin_stage()


func _begin_stage() -> void:
	var s: Array = reload_stages[_stage]
	# a pipe steadies the hands: the stages a little quicker (Vices; the clips follow the stage's time)
	var k := player.reload_time_mult if player else 1.0
	_stage_left = float(s[1]) * k
	action_started.emit(s[0], float(s[1]) * k)


func _interrupt_reload() -> void:
	state = State.EMPTY
	action_cancelled.emit()


func _finish_reload() -> void:
	reserve -= 1
	loaded = true
	_stage = 0
	state = State.READY


func _pull_trigger() -> void:
	state = State.HANGFIRE
	_timer = hang_fire
	# The Blender models carry a "Pan" marker; the primitive fallback does not,
	# so estimate from the muzzle (it points along -Z, so the lock is at +Z).
	var pan_node := model.get_node_or_null("Pan") as Node3D if model else null
	var pan := pan_node.global_position if pan_node \
			else muzzle.global_position + muzzle.global_basis.z * pan_distance + Vector3.UP * 0.03
	Fx.pan_flash(player.get_tree().current_scene, pan)
	sfx.emit(&"lock", pan)


func _discharge() -> void:
	loaded = false
	_launch(Projectile.Kind.BALL, muzzle_speed, ball_gravity, ball_drag, damage, muzzle_speed)
	Fx.muzzle_blast(player.get_tree().current_scene, muzzle.global_transform, smoke_scale)
	player.add_recoil(recoil_pitch_deg, randf_range(-recoil_yaw_deg, recoil_yaw_deg))
	if fire_shake > 0.0 and player.get("camera") is Camera3D:
		CameraShake.of(player.camera).kick(fire_shake, fire_shake_s)
	state = State.RECOIL
	_timer = recoil_time


func status_text() -> String:
	match state:
		State.AIMING: return ("Release to fire" if aim >= ready_aim else "Shouldering") + "  (RMB/R: lower)"
		State.HANGFIRE, State.RECOIL: return "Fired"
		State.EMPTY: return "Empty - press R" if reserve > 0 else "Out of cartridges"
		State.RELOADING: return reload_stages[_stage][2]
	return "Loaded"


func ammo_text() -> String:
	return "%s  |  %d cartridges" % ["●" if loaded else "○", reserve]


func progress() -> Array:
	if state != State.RELOADING:
		return []
	var total := 0.0
	var done := 0.0
	for i in reload_stages.size():
		total += reload_stages[i][1]
		if i < _stage:
			done += reload_stages[i][1]
	done += reload_stages[_stage][1] - _stage_left
	return ["Reloading", done / total]
