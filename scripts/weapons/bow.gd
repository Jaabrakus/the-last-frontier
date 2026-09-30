class_name Bow
extends Weapon
## Hunting bow. Silent, quick follow-up shots, arrows can be recovered later.
##
## Hold LMB to draw and release to shoot. A quick click still fires once the
## minimum draw is reached, with less power and more spread. RMB lets the
## string down. Holding a full draw too long makes the aim tremble.
##
## Rapid shooting: press R to pull a few arrows from the quiver and hold them
## against the grip in the bow hand (a period archer's trick). Nocking from
## the hand is about twice as fast as reaching back to the quiver.

enum State { READY, DRAWING, HOLDING, NOCKING, EMPTY, GRABBING }

## Sound hook (scripts/audio/weapon_audio.gd): &"draw" when a draw starts, &"let_down" when
## a drawn string is eased back. `at` is the bow.
signal sfx(id: StringName, at: Vector3)

@export_group("Timing")
@export var draw_time := 0.6          ## Seconds from nock to full draw.
@export var min_draw := 0.12          ## A click fires once this much draw time has passed.
@export var nock_time := 0.75         ## Time to nock the next arrow.
@export var fatigue_start := 2.5      ## Seconds of full draw before the tremble starts.
@export var fatigue_full := 6.0
@export var grab_time := 1.1          ## R: pull arrows from the quiver into the bow hand.
@export var hand_nock_time := 0.35    ## Nocking an arrow held in the bow hand.
@export var hand_capacity := 3

@export_group("Arrow")
@export var min_arrow_speed := 22.0
@export var max_arrow_speed := 62.0
@export var arrow_gravity := 5.0
@export var min_damage := 30.0
@export var max_damage := 90.0
@export var quiver := 24

@export_group("Spread")
@export var spread_undercharge := 3.5 ## Added at zero draw; fades out quadratically.
@export var spread_fatigue := 2.5

var state := State.READY
var charge := 0.0
var hold_time := 0.0
var _t := 0.0
var _queued_release := false
var _wait_fire_release := false        ## After a let-down, LMB must be released before redrawing.
var _nock_left := 0.0
var _nock_duration := 0.75
var _grab_left := 0.0
## Arrows held in the bow hand (counted in `quiver` too).
var held := 0
var _held_models: Array[Node3D] = []
## The arrow on the string while drawing; the shot leaves from its tip.
var _nocked: Node3D
var _nock_bones := PackedInt32Array()
var _tip := Vector3.ZERO
var _tip_valid := false
const ARROW_LENGTH := 0.72


func _init() -> void:
	display_name = "Hunting Bow"
	hand = Hand.LEFT
	move_speed_mult = 1.0
	busy_speed_mult = 0.7
	spread_base = 0.2
	spread_move = 2.8
	spread_air = 7.0
	crouch_mult = 0.6
	fire_bloom = 1.2
	aim_yaw_offset_deg = 13.0
	aim_pitch_offset_deg = -6.7
	# Crouched, the aim clip rolls the bow flat (90 degree cant) and points it higher.
	aim_yaw_offset_crouch_deg = 12.1
	aim_pitch_offset_crouch_deg = 12.2
	spread_unaimed = 0.0        # Undercharge spread already covers a half-drawn bow.
	aim_in_time = 0.12
	aim_out_time = 0.25
	relaxed = {
		"idle": ["actor_b-p-bow-move--arms", 1.0],
		"walk": ["actor_b-p-bow-move--arms", 1.0],
		"run": ["actor_b-p-bow-move--arms", 1.0],
		"sprint": ["actor_b-p-bow-sprint--arms", 1.0],
		"crouch_idle": ["actor_b-p-bow-crouch-idle--arms", 1.0],
		"crouch_walk": ["actor_b-p-bow-crouch-move--arms", 1.0],
	}
	clips = {
		# Hand + prop-bone layer over the aim pose (places the weapon in the hands).
		"aim_walk": "actor_b-p-bow-aim-walk",               # + -fw / -fw-lt / ... / -bw-rt
		"aim_walk_crouch": "actor_b-p-bow-aim-crouch-walk",
		"hands": "actor_b-p-bow-aim-hands-idle",
		"hands_crouch": "actor_b-p-bow-aim-crouch-hands-idle",
		"aim": "actor_b-p-bow-aim-idle",
		"aim_crouch": "actor_b-p-bow-aim-crouch-idle",
		"up": "actor_b-p-bow-aim-up--add",
		"down": "actor_b-p-bow-aim-down--add",
		"up_crouch": "actor_b-p-bow-crouch-aim-up--add",
		"down_crouch": "actor_b-p-bow-crouch-aim-down--add",
		"charge": "actor_b-p-bow-aim-charge--add",
		"charge_crouch": "actor_b-p-bow-crouch-aim-charge--add",
		"fire": "actor_b-p-bow-fire--add",
		"fire_crouch": "actor_b-p-crouch-bow-fire--add",
		"nock": "actor_b-p-bow-reload--part",
		"nock_crouch": "actor_b-p-crouch-bow-reload--part",
		"equip": "actor_b-p-bow-draw-grab^idle--part",
		"grab": "actor_b-p-bow-reload--part",
		"grab_crouch": "actor_b-p-crouch-bow-reload--part",
	}


func is_drawn() -> bool:
	return state == State.DRAWING or state == State.HOLDING


func wants_aim() -> bool:
	return active and is_drawn()


func is_busy() -> bool:
	return is_drawn()


## Sprinting lets the string down.
func can_sprint() -> bool:
	return true


func charge_amount() -> float:
	return charge if is_drawn() else 0.0


## 0..1: how much the hold tremble currently affects the shot.
func fatigue() -> float:
	if state != State.HOLDING:
		return 0.0
	return clampf((hold_time - fatigue_start) / maxf(fatigue_full - fatigue_start, 0.01), 0.0, 1.0)


## Small rotation noise used to shake the aim while fatigued.
func tremble_offset() -> Vector2:
	var f := fatigue()
	if f <= 0.0:
		return Vector2.ZERO
	var a := deg_to_rad(0.9) * f
	return Vector2(
		(sin(_t * 23.0) * 0.6 + sin(_t * 37.0) * 0.4) * a,
		(sin(_t * 19.0 + 1.3) * 0.6 + sin(_t * 31.0) * 0.4) * a)


func _on_equip() -> void:
	_build_held_arrows()
	_build_nocked_arrow()


func _on_unequip() -> void:
	if state == State.GRABBING:
		state = State.READY
	if is_drawn():
		charge = 0.0
		state = State.READY
	if state == State.NOCKING:
		# Finish nocking off-screen so switching doesn't cost an arrow.
		state = State.READY if quiver > 0 else State.EMPTY


func _tick(delta: float) -> void:
	_t += delta
	var fire_down := _fire_input_enabled() and Input.is_action_pressed("fire")
	var can_draw := not player.is_sprinting and not is_equipping() and not aim_hold

	match state:
		State.READY:
			if not fire_down:
				_wait_fire_release = false
			if fire_down and can_draw and not _wait_fire_release:
				_start_draw()
			elif _fire_input_enabled() and Input.is_action_just_pressed("reload") and _can_grab():
				state = State.GRABBING
				_grab_left = grab_time
				action_started.emit("grab", grab_time)
		State.GRABBING:
			_grab_left -= delta
			if player.is_sprinting:
				state = State.READY
				action_cancelled.emit()
			elif _grab_left <= 0.0:
				held = mini(hand_capacity, held + _spare())
				state = State.READY
		State.DRAWING:
			hold_time = 0.0
			charge = minf(charge + delta / draw_time, 1.0)
			if Input.is_action_just_pressed("aim") or player.is_sprinting:
				_let_down()
			elif not fire_down or _queued_release:
				if charge * draw_time >= min_draw:
					_fire()
				else:
					_queued_release = true
			elif charge >= 1.0:
				state = State.HOLDING
		State.HOLDING:
			hold_time += delta
			if Input.is_action_just_pressed("aim") or player.is_sprinting:
				_let_down()
			elif not fire_down:
				_fire()
		State.NOCKING:
			_nock_left -= delta
			if _nock_left <= 0.0:
				state = State.READY
				# Keep holding fire to draw the next arrow right away.
				if fire_down and can_draw:
					_start_draw()
		State.EMPTY:
			if quiver > 0:
				_start_nock()


func _extra_spread() -> float:
	var c := charge
	if not is_drawn():
		c = min_draw / draw_time   # Show what a quick click would give you.
	return spread_undercharge * pow(1.0 - c, 2.0) + spread_fatigue * fatigue()


func _start_draw() -> void:
	charge = 0.0
	hold_time = 0.0
	_queued_release = false
	state = State.DRAWING
	sfx.emit(&"draw", model.global_position if model else player.global_position)


func _let_down() -> void:
	charge = 0.0
	_queued_release = false
	_wait_fire_release = true
	state = State.READY
	sfx.emit(&"let_down", model.global_position if model else player.global_position)


func _fire() -> void:
	var power := ease(charge, 0.6)
	_launch(Projectile.Kind.ARROW, shot_speed(), arrow_gravity, 0.0,
			lerpf(min_damage, max_damage, power), max_arrow_speed)
	quiver -= 1
	charge = 0.0
	hold_time = 0.0
	_queued_release = false
	if quiver > 0:
		_start_nock()
	else:
		state = State.EMPTY


func _start_nock() -> void:
	state = State.NOCKING
	_nock_duration = nock_time
	# (an arrow already in the bow hand is nocked from there, with no reach back to the quiver: its own action, "nock_hand";
	# user 2026-09-30: "with arrows in hand the user doesn't need to pull arrows out the quiver")
	var from_hand := held > 0
	if from_hand:
		held -= 1
		_nock_duration = hand_nock_time
	_nock_duration *= player.reload_time_mult if player else 1.0    # a pipe: a little quicker (Vices)
	_nock_left = _nock_duration
	action_started.emit("nock_hand" if from_hand else "nock", _nock_duration)


## Arrow speed if released now (used by the shot and the trajectory arc).
func shot_speed() -> float:
	return lerpf(min_arrow_speed, max_arrow_speed, ease(charge, 0.6))


## Arrows in the quiver that are neither nocked nor already in the hand.
func _spare() -> int:
	var nocked := 1 if state != State.EMPTY else 0
	return maxi(quiver - nocked - held, 0)


func _can_grab() -> bool:
	return held < hand_capacity and _spare() > 0 and not player.is_sprinting and not is_equipping()


## Arrows held against the grip, fanned slightly, tips forward (model -Z).
func _build_held_arrows() -> void:
	if not _held_models.is_empty() or model == null:
		return
	for i in hand_capacity:
		var a := WeaponModels.build_arrow()
		a.name = "HeldArrow%d" % i
		model.add_child(a)
		a.position = Vector3(0.018 + 0.01 * i, -0.03 - 0.018 * i, -0.2)
		a.rotation = Vector3(deg_to_rad(-3.0 - 2.0 * i), deg_to_rad(2.0 - 2.0 * i), 0.0)
		a.visible = false
		_held_models.append(a)


func _process(_delta: float) -> void:
	for i in _held_models.size():
		_held_models[i].visible = active and i < held


## The arrow on the string lies from the string fingers (nock) through the
## arrow rest on the bow; the shot leaves from its tip, so it flies out of the
## bow exactly where it was drawn. Placed after the skeleton's modifiers ran.
func _build_nocked_arrow() -> void:
	if _nocked != null or model == null or player == null or player.skeleton == null:
		return
	var sk := player.skeleton
	for n in ["r_indexb", "r_middleb"]:
		var b := sk.find_bone(n)
		if b != -1:
			_nock_bones.append(b)
	if _nock_bones.is_empty():
		_nock_bones.append(sk.find_bone("r_palm"))
	_nocked = WeaponModels.build_arrow()
	_nocked.name = "NockedArrow"
	_nocked.top_level = true
	_nocked.visible = false
	model.add_child(_nocked)
	sk.skeleton_updated.connect(_place_nocked_arrow)


func _place_nocked_arrow() -> void:
	var sk := player.skeleton
	# A skeleton update can still arrive while the level is being freed (scene change).
	if not sk.is_inside_tree() or not muzzle.is_inside_tree():
		return
	var nock := Vector3.ZERO
	for b in _nock_bones:
		nock += (sk.global_transform * sk.get_bone_global_pose(b)).origin
	nock /= _nock_bones.size()
	var rest := muzzle.global_position
	var dir := rest - nock
	if dir.length_squared() < 0.0025:
		_tip_valid = false
		_nocked.visible = false
		return
	dir = dir.normalized()
	_tip = nock + dir * ARROW_LENGTH
	_tip_valid = true
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	_nocked.global_transform = Transform3D(Basis.looking_at(dir, up), _tip)
	_nocked.visible = active and is_drawn()


func launch_origin() -> Vector3:
	return _tip if _tip_valid else muzzle.global_position


func add_arrows(n: int) -> void:
	quiver += n


func status_text() -> String:
	match state:
		State.DRAWING: return "Drawing"
		State.HOLDING: return "Trembling" if fatigue() > 0.0 else "Full draw"
		State.NOCKING: return "Nocking from hand" if _nock_duration < nock_time else "Nocking"
		State.GRABBING: return "Taking arrows in hand"
		State.EMPTY: return "Quiver empty"
	return "Ready"


func ammo_text() -> String:
	if held > 0:
		return "%d in hand  |  %d arrows" % [held, quiver]
	return "%d arrows  (R: take %d in hand)" % [quiver, hand_capacity] if _spare() > 0 else "%d arrows" % quiver


func progress() -> Array:
	if is_drawn():
		return ["Draw", charge]
	if state == State.NOCKING:
		return ["Nocking", 1.0 - _nock_left / _nock_duration]
	if state == State.GRABBING:
		return ["Taking arrows", 1.0 - _grab_left / grab_time]
	return []
