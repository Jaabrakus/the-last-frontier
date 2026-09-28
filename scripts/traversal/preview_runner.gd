class_name TravPreviewRunner
extends CharacterBody3D
## A stand-in for FrontierPlayer in the standalone traversal preview: the same capsule and
## locomotion speeds (walk 1.6, run 3.6, sprint 5.6 m/s), driven by scripted input or the
## keyboard, calling the TraversalController exactly where the player hooks will (design 16):
##   pre_step(input) -> if owned: physics_step(delta) (skip locomotion) -> else locomotion,
##   step_assist, move_and_slide. The TravPreviewActor shows the result on Actor_B.
##
## input: {move: Vector2 (x right, y back), sprint, walk, jump, crouch, yaw}

signal stepped(delta: float)

@export var walk_speed := 1.6
@export var run_speed := 3.6
@export var sprint_speed := 5.6
@export var ground_accel := 14.0
@export var ground_decel := 18.0
@export var air_accel := 2.5
@export var jump_velocity := 4.4
@export var stand_height := 1.6

var controller: TraversalController
var actor: TravPreviewActor
var scripted := true
var input := {}
var yaw := 0.0
var _gravity := 9.81
var _step := TravStepAssist.new()


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = stand_height
	cs.shape = cap
	cs.position.y = stand_height * 0.5
	cs.name = "Capsule"
	add_child(cs)
	floor_snap_length = 0.3


func setup(ctrl: TraversalController, p_actor: TravPreviewActor) -> void:
	controller = ctrl
	actor = p_actor


func keyboard_input() -> Dictionary:
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return {"move": mv, "sprint": Input.is_action_pressed("sprint"), "walk": Input.is_action_pressed("walk"),
			"jump": Input.is_action_just_pressed("jump"), "crouch": Input.is_action_just_pressed("crouch"), "yaw": yaw}


func _physics_process(delta: float) -> void:
	var inp := input if scripted else keyboard_input()
	inp["yaw"] = float(inp.get("yaw", yaw))
	yaw = float(inp.yaw)
	if controller:
		controller.pre_step(inp, delta)
		if bool(inp.get("jump", false)) and scripted:
			input["jump"] = false
		if bool(inp.get("crouch", false)) and scripted:
			input["crouch"] = false
	if controller and controller.owns_body():
		controller.physics_step(delta)
	else:
		_locomotion(inp, delta)
		if controller:
			controller.tick(delta)
	if actor and controller:
		actor.pending_plan = controller.pending
		actor.approach = controller.approach()
		actor.show_state(controller.anim_state(), self, delta)
	stepped.emit(delta)


func _locomotion(inp: Dictionary, delta: float) -> void:
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	var sprint := bool(inp.get("sprint", false)) and mv.y < -0.1
	var speed := sprint_speed if sprint else (walk_speed if bool(inp.get("walk", false)) else run_speed)
	var wish := Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, mv.y)
	wish.y = 0.0
	var target := wish.limit_length(1.0) * speed
	var horiz := Vector3(velocity.x, 0, velocity.z)
	# Approach (hook for the player's ground movement): ease the speed down to the next entry's
	# speed by its start point (TraversalController.approach(): planned moves, standing moves the
	# body stops for, beams, crouch-under, squeeze gaps, narrow ledges), so every clip starts at
	# the speed it was made for (no velocity snap at the entry seam; design 8.3 setting A, user
	# decision: the clip's own timing). The slowdown is gentle and starts early: a constant
	# deceleration of APPROACH_DECEL, or the constant one that just makes it when the entry was
	# found late (no step down of the speed when a move is found).
	var ap: Dictionary = controller.approach() if controller else {}
	if not ap.is_empty() and target.length() > 0.1:
		var ve := float(ap.speed)
		var v_now := horiz.length()
		var d := float(ap.dist)
		var a := TraversalController.APPROACH_DECEL
		if d > 0.02 and v_now > ve:
			a = maxf(a, (v_now * v_now - ve * ve) / (2.0 * d))
		# (the profile at where the body will be after this tick: at the current position it would
		# allow the current speed forever)
		var v_allowed := sqrt(ve * ve + 2.0 * a * maxf(0.0, d - v_now * delta))
		if v_allowed < target.length():
			target = target.normalized() * v_allowed
	# A wall close ahead and nothing planned (no move, no approach): ease down to stop WALL_STOP_M in
	# front of it instead of running into it (fix round 3, 2026-09-25: after the tree stand's
	# dismount, forward held on, the run's reaching hand and swinging foot went 7 cm into the trunk
	# the capsule had stopped against).
	if ap.is_empty() and controller and controller.pending == null and controller.mode == TraversalController.Mode.OFF \
			and target.length() > 0.1 and is_on_floor():
		var dw := _wall_ahead(target.normalized())
		if dw < INF:
			var v_w := sqrt(2.0 * WALL_STOP_DECEL * maxf(0.0, dw - WALL_STOP_M - horiz.length() * delta))
			if v_w < target.length():
				target = target.normalized() * v_w
	var accel := ground_accel if target.length() > horiz.length() else ground_decel
	if not is_on_floor() and not _step.stepping():
		accel = air_accel
	horiz = horiz.move_toward(target, accel * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	if is_on_floor():
		if bool(inp.get("jump", false)) and (controller == null or controller.mode == TraversalController.Mode.OFF):
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta
	_step_assist(wish.limit_length(1.0), delta)
	move_and_slide()
	# Beam entry: standing on a beam line (design 9.5).
	if controller and controller.mode == TraversalController.Mode.OFF and is_on_floor():
		var bid := _beam_under()
		if bid >= 0:
			controller.enter_beam(bid)


const WALL_LOOK_M := 1.2
const WALL_STOP_M := 0.55          ## capsule centre to the wall where the body comes to rest
const WALL_STOP_DECEL := 9.0

## Distance from the capsule's axis to a wall ahead along `dir` (rays at knee, chest and head
## height, up to WALL_LOOK_M), or INF.
func _wall_ahead(dir: Vector3) -> float:
	if controller == null or controller.probe == null:
		return INF
	var best := INF
	for h: float in [0.5, 1.1, 1.6]:
		var o := global_position + Vector3.UP * h
		var hit: Dictionary = controller.probe.ray(o, o + dir * WALL_LOOK_M)
		if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.5:
			continue
		best = minf(best, o.distance_to(hit.position))
	return best


## True while the step assist lifts the body (tests: those OFF frames belong to traversal).
func stepping() -> bool:
	return _step.stepping()


## Step assist (design 7.9): TravStepAssist, called where the player hook will call it.
func _step_assist(wish: Vector3, delta: float) -> void:
	if controller == null:
		return
	var h := Vector3(velocity.x, 0, velocity.z)
	var dir := h if h.length() > 0.5 else wish
	_step.step(self, controller.probe, dir, maxf(h.length(), wish.length() * 3.0), delta)


func _beam_under() -> int:
	if controller.ledges == null:
		return -1
	var p := global_position
	for id: int in controller.ledges.beams:
		var bm: Dictionary = controller.ledges.beams[id]
		var a: Vector3 = bm.a
		var b: Vector3 = bm.b
		var ab := b - a
		var u := (p - a).dot(ab) / ab.length_squared()
		if u < 0.02 or u > 0.98:
			continue
		var q := a + ab * u
		if absf(p.y - q.y) < 0.2 and Vector2(p.x - q.x, p.z - q.z).length() < float(bm.width) * 0.5 + 0.2:
			if float(bm.width) < 0.5:
				return id
	return -1
