class_name RecruitBody
extends CharacterBody3D
## A visitor's body (RECRUIT, scripts/companion/recruit_link.gd): the Actor_B rig dressed from their look, as the spouse's is
## (a teen at the teen's body and proportions), walking a list of waypoints (the road in, the way round to the gate and
## home, the road out) and standing or sitting about the camp between. E on a visitor talks to them (RecruitScreen).
## NAV: it walks from point to point along the navigation mesh (NavMover: round trees, rocks and the palisade, through the
## gate, opening a shut door); where there is no mesh or no way it walks straight with a probe ahead turning it past what is
## in the way, and held up there for a while it steps through (no collision for a moment) so a scripted walk always ends.

signal arrived(body: RecruitBody)

const LIB := "actor_b"
const CLIP_IDLE := "actor_b-p-relax-idle"
const CLIP_WALK := "actor_b-p-walk-fw"
const CLIP_SIT := "actor_b-cap-casual-sit-floor-loop"
const BODY_PATH := "res://assets/character/actor_b_body.glb"
const GRAVITY := 18.0
const ARRIVE := 0.8
## Held up this long (s) it steps through for GHOST_S.
const STUCK_S := 2.0
const GHOST_S := 1.2

var link: RecruitLink
## The candidate this body is ("" for a worker walking away).
var rec_id := ""
var person_name := ""
var desc := ""
var look := {}
var draw_look := {}
var teen := false
## "walk" (the route), "camp" (about the camp spot), "leave" (the route, then gone)
var mode := "camp"
var route: Array = []
var speed := 1.25
var camp := Vector3.ZERO
var interact_reach := 2.6

var sk: Skeleton3D
var ap: AnimationPlayer
var _model: Node3D
var _clip := ""
var _face := 0.0
var _turn_bias := 0.0
var _stuck_t := 0.0
var _ghost_t := 0.0
var _last := Vector3.ZERO
var _idle_t := 0.0
var _sitting := false
var _rng := RandomNumberGenerator.new()
## NAV: its way on the navigation mesh; this frame's direction came from it; the step-throughs it needed (tests).
var nav: NavMover
var step: BodyStep                ## STEP: over a log in the way
var _nav_dir := false
var ghosts := 0


static func spawn(parent: Node, at: Vector3, the_look: Dictionary, drawn: Dictionary, is_teen: bool) -> RecruitBody:
	var b := RecruitBody.new()
	b.look = the_look
	b.draw_look = drawn
	b.teen = is_teen
	parent.add_child(b)
	b.global_position = at + Vector3.UP * 0.2
	return b


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)
	add_to_group(WildlifeSpawner.PEOPLE)   # PEOPLE
	collision_layer = 1
	collision_mask = 1
	_rng.seed = hash(rec_id + person_name)
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	cap.shape = shape
	cap.position.y = 0.85
	add_child(cap)
	_build_model()
	if teen:
		var row := Growth.stage_row("teen")
		var sv := float(row.get("scale", 0.93))
		_model.scale = Vector3.ONE * sv
		shape.radius = 0.3 * sv
		shape.height = 1.7 * sv
		cap.position.y = shape.height * 0.5
	_last = global_position
	nav = NavMover.new(self, shape.radius)   # NAV
	step = BodyStep.new(self, 0.45)          # STEP: over a log in the way


func _build_model() -> void:
	var scene := BackgroundLoad.take("res://characters/Actor_B.tscn") as PackedScene
	_model = scene.instantiate() as Node3D
	_model.rotation.y = deg_to_rad(180.0)
	add_child(_model)
	sk = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] as AnimationPlayer if not aps.is_empty() else null
	var body := CharacterBodyMesh.attach(sk, ap, BODY_PATH)
	if body:
		var drawn: Dictionary = draw_look if not draw_look.is_empty() else look
		var st := String(drawn.get("stage", ""))
		if st != "" and st != "adult":
			PlayerAppearance.dress(body, AppearanceStore.validate(ChildLook.dress_look(ChildLook.young(drawn, st), float(look.get("sex", 0.0)), st)))
			ChildBody.shape_body(body, drawn, st)
		else:
			PlayerAppearance.dress(body, AppearanceStore.validate(drawn))
	if ap:
		for c in [CLIP_IDLE, CLIP_WALK, CLIP_SIT]:
			var full := "%s/%s" % [LIB, c]
			if ap.has_animation(full):
				ap.get_animation(full).loop_mode = Animation.LOOP_LINEAR
	_show(CLIP_IDLE)


func _show(clip: String, spd := 1.0) -> void:
	if ap == null:
		return
	var full := "%s/%s" % [LIB, clip]
	if not ap.has_animation(full):
		return
	ap.speed_scale = spd
	if _clip != clip:
		_clip = clip
		ap.play(full, 0.3)


## Walks `points` (Vector3s; y is ignored) in `new_mode` ("walk" or "leave"); `arrived` is emitted at the last.
func walk(points: Array, new_mode := "walk") -> void:
	route = points.duplicate()
	mode = new_mode
	_sitting = false
	_stuck_t = 0.0


func settle(at: Vector3) -> void:
	camp = at
	mode = "camp"
	route = []
	_idle_t = _rng.randf_range(4.0, 10.0)


func _physics_process(dt: float) -> void:
	var dir := Vector3.ZERO
	_nav_dir = false
	match mode:
		"walk", "leave":
			while not route.is_empty():
				var to: Vector3 = (route[0] as Vector3) - global_position
				to.y = 0.0
				# NAV: a point the way cannot quite reach (in a bush, on a hearth): there once at the nearest the way goes
				var short := nav != null and nav.status == NavMover.FAILED and nav.reason == "unreachable" and nav.reach_end != Vector3.INF \
						and Vector2(nav.reach_end.x - global_position.x, nav.reach_end.z - global_position.z).length() < ARRIVE + 0.3 \
						and Vector2(nav.reach_end.x - (route[0] as Vector3).x, nav.reach_end.z - (route[0] as Vector3).z).length() < 2.5
				if to.length() > ARRIVE and not short:
					dir = _way(route[0] as Vector3, dt, ARRIVE)   # NAV
					break
				if nav != null:
					nav.reset()
				route.pop_front()
			if route.is_empty():
				dir = Vector3.ZERO
				var m := mode
				mode = "camp"
				camp = global_position
				_idle_t = 2.0
				arrived.emit(self)
				if m == "leave":
					return
		"camp":
			var to := camp - global_position
			to.y = 0.0
			if to.length() > 1.6:
				dir = _way(camp, dt, 1.4)   # NAV
				_sitting = false
			else:
				_idle_t -= dt
				if _idle_t <= 0.0:
					_sitting = not _sitting and _rng.randf() < 0.6
					_idle_t = _rng.randf_range(8.0, 20.0)
				# turned to the player when they come near
				var p := link.house.player if link != null and link.house != null else null
				if p != null and is_instance_valid(p) and p.global_position.distance_to(global_position) < 5.0:
					var tp := p.global_position - global_position
					_face = atan2(-tp.x, -tp.z)
					_sitting = false
	_move(dir, dt)


## NAV: the way to `to` now along the navigation mesh (ZERO when there or waiting for a door), or straight at it where there
## is none (turned aside by the probe in _move).
func _way(to: Vector3, dt: float, arrive: float) -> Vector3:
	if nav != null:
		var d := nav.steer(to, dt, arrive)
		if nav.on_path:
			_nav_dir = true
			return d
	var st := to - global_position
	st.y = 0.0
	return st.normalized() if st.length() > 0.05 else Vector3.ZERO


func _move(dir: Vector3, dt: float) -> void:
	var v := velocity
	var moving := dir.length() > 0.01
	if _ghost_t > 0.0:
		_ghost_t -= dt
		if _ghost_t <= 0.0:
			collision_mask = 1
	if moving:
		var want := dir if _nav_dir or _ghost_t > 0.0 else _steer(dir)
		v.x = want.x * speed
		v.z = want.z * speed
		_face = lerp_angle(_face, atan2(-want.x, -want.z), clampf(dt * 8.0, 0.0, 1.0))
		_show(CLIP_WALK, speed / 1.3 * (1.0 / (0.93 if teen else 1.0)))
		_sitting = false
	else:
		v.x = move_toward(v.x, 0.0, 12.0 * dt)
		v.z = move_toward(v.z, 0.0, 12.0 * dt)
		_show(CLIP_SIT if _sitting else CLIP_IDLE)
	if _ghost_t > 0.0:
		# stepping through: kept on the ground by hand
		global_position.y = FrontierTerrain.height_at(global_position.x, global_position.z)
		v.y = 0.0
	elif not is_on_floor():
		v.y -= GRAVITY * dt
	else:
		v.y = -0.5
	velocity = v
	rotation.y = lerp_angle(rotation.y, _face, clampf(dt * 10.0, 0.0, 1.0))
	if moving and _ghost_t <= 0.0 and step != null:
		step.step(Vector3(v.x, 0.0, v.z), speed, dt)
	move_and_slide()
	if global_position.y < FrontierTerrain.height_at(global_position.x, global_position.z) - 2.0:
		global_position.y = FrontierTerrain.height_at(global_position.x, global_position.z) + 0.2
	if moving and not _nav_dir and global_position.distance_to(_last) < speed * dt * 0.3:   # NAV: on a path it repaths itself
		_stuck_t += dt
		if _stuck_t > STUCK_S:
			_stuck_t = 0.0
			_ghost_t = GHOST_S
			ghosts += 1
			collision_mask = 0
	else:
		_stuck_t = maxf(_stuck_t - dt, 0.0)
	_last = global_position


func _steer(dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.5
	for k in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var d := dir.rotated(Vector3.UP, float(k) + _turn_bias)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 1.0, 1, [get_rid()])
		if space.intersect_ray(q).is_empty():
			_turn_bias = clampf(float(k) * 0.5, -1.0, 1.0) if k != 0.0 else move_toward(_turn_bias, 0.0, 0.05)
			return d
	return dir


# ---------------------------------------------------------------- E
func interact_point() -> Vector3:
	return global_position + Vector3.UP * (1.1 if teen else 1.2)


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func interact_prompt(_p: Node) -> String:
	if rec_id == "" or mode == "leave" or link == null or not link.can_talk(rec_id):
		return ""
	return "Talk to %s (%s)" % [person_name, desc]


func interact(_p: Node) -> void:
	if link != null:
		link.open(rec_id)
