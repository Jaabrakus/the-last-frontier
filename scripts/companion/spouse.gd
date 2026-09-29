class_name Spouse
extends CharacterBody3D
## The spouse's body (user 2026-09-28: "a wife NPC for my char ... we will then be able to talk to the npc and delegate
## tasks either through talking or an npc management tab"): Actor_B dressed from her look (PlayerAppearance.dress, as
## the player), a walking body that follows the player, waits, or goes about her role's work on her own, with the
## logic in SpouseCore. E talks to her.
##
## She walks straight at what she is going to (no navmesh in this world): the ground under her feet is the terrain's
## collider, a wall or a tree in the way turns her aside (a probe ahead of her). At her work she kneels over it (the
## search-low clips, as the player cooking or butchering) while her core's job runs on the game clock; cooking, she
## faces the hearth.

signal talk_requested(spouse: Spouse, tab: String)

const LIB := "actor_b"
const CLIP_IDLE := "actor_b-p-relax-idle"
const CLIP_WALK := "actor_b-p-walk-fw"
const CLIP_RUN := "actor_b-p-run-fw"
const CLIP_WORK_IN := "actor_b-cap-ambi-search-low-in-place-entry"
const CLIP_WORK := "actor_b-cap-ambi-search-low-in-place"
const CLIP_WORK_OUT := "actor_b-cap-ambi-search-low-in-place-exit"
## GROWTH: a young worker (a child's or teen's body) works at waist height, standing: the low search folds a small body flat on the
## ground like a crawl.
const CLIP_WORK_YOUNG := ["actor_b-cap-ambi-search-1m-in-place-entry", "actor_b-cap-ambi-search-1m-in-place", "actor_b-cap-ambi-search-1m-in-place-exit"]
const BODY_PATH := "res://assets/character/actor_b_body.glb"
## The walk clip's foot speed (m/s), and how fast she goes to catch up.
const WALK_SPEED := 1.3
const RUN_SPEED := 3.4
const GRAVITY := 18.0
## Follows to within this (m), starts again from this far; runs to catch up from this far.
const FOLLOW_NEAR := 2.6
const FOLLOW_FAR := 4.0
const FOLLOW_RUN := 9.0
## Has arrived within this of a work spot (m).
const ARRIVE := 0.9
## Forage and firewood spots: this far from home (m).
const WOODS_RANGE := Vector2(18.0, 42.0)
const KEEP := &"spouse"
## Her stations (woodpile, smokehouse, rack, frame, hoop) are within this of the hearth (m); her chores at the others too.
const HOUSE_RANGE := 16.0
## The stations she idles at, as chores when she has no task (CampStation kinds).
const CHORE_KINDS := ["workbench", "tanning_frame", "stretching_hoop", "drying_rack", "alchemy_table", "work_stone", "forge"]

var sc: SpouseCore
var player: Node3D
var home := Vector3.ZERO
## The hearth (the spot she cooks at) and where she keeps house.
var hearth := Vector3.ZERO
var interact_reach := 2.6

var sk: Skeleton3D
var ap: AnimationPlayer
var _model: Node3D
var _clip := ""
var _goal := Vector3.ZERO
var _has_goal := false
var _plan := {}
var _face := 0.0
var _rng := RandomNumberGenerator.new()
var _phase := ""            ## "" idle / walking, "in", "work", "out" while at her work
var _phase_t := 0.0
var _turn_bias := 0.0
var _stuck_t := 0.0
var _last := Vector3.ZERO
var _look_at := Vector3.ZERO
var _look_on := false
## BABY (scripts/companion/baby_link.gd): while valid it is called each physics frame as errand(dt) and answers [direction, speed]
## (her walk to the cradle or the player) or null (no errand now); it takes precedence over her work and chores. `idle_clip` is
## the clip she stands in when not walking ("" the plain idle): the sit and kneel of feeding and changing the baby.
var errand := Callable()
var idle_clip := ""
## Her chores when there is no task: a spot to go to, and how long she works at it (s); 0 when she is not at one.
var _chore := false
var _chore_len := 0.0
var _chore_wait := 0.0
var _chore_face := Vector3.INF


static func spawn(parent: Node, core: SpouseCore, p: Node3D, at: Vector3) -> Spouse:
	var s := Spouse.new()
	s.name = "Spouse" if core.worker_id == 0 else "Worker%d" % core.worker_id
	s.sc = core
	s.player = p
	s.home = at
	s.hearth = at
	parent.add_child(s)
	s.global_position = at + Vector3.UP * 0.3
	return s


func _ready() -> void:
	add_to_group(KEEP)
	add_to_group(PlacedWeapon.GROUP)
	collision_layer = 1
	collision_mask = 1
	_rng.seed = hash(sc.name) if sc else 1
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	cap.shape = shape
	cap.position.y = 0.85
	add_child(cap)
	_build_model()
	if sc:
		sc.carcass_finder = _carcass_near_home
		sc.fire_finder = _fire_needing_wood
		sc.finders = {
			"pile": func() -> Object: return HouseholdSites.low_pile(get_tree(), hearth, HOUSE_RANGE),
			"smoke": func() -> Object: return HouseholdSites.smokehouse(get_tree(), hearth, HOUSE_RANGE),
			"rack": func() -> Object: return _lit_rack(),
			"frame": func() -> Object: return HouseholdSites.station(get_tree(), "tanning_frame", hearth, HOUSE_RANGE, CampStation.TAN_FIRE_M),
			"hoop": func() -> Object: return HouseholdSites.station(get_tree(), "stretching_hoop", hearth, HOUSE_RANGE),
		}
		sc.task_finished.connect(_on_task_finished)


var _body: CharacterBodyMesh
var _work_clips: Array = [CLIP_WORK_IN, CLIP_WORK, CLIP_WORK_OUT]


func _build_model() -> void:
	var scene := BackgroundLoad.take("res://characters/Actor_B.tscn") as PackedScene
	_model = scene.instantiate() as Node3D
	_model.rotation.y = deg_to_rad(_player_yaw_offset())
	add_child(_model)
	sk = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] as AnimationPlayer if not aps.is_empty() else null
	var body := CharacterBodyMesh.attach(sk, ap, BODY_PATH)
	if body:
		# GROWTH: a young worker is drawn at its stage body (Growth.body_look), in a child's clothes with its stage's proportions, rounded
		# head and soft skin (ChildBody.shape_body); an adult as she is
		var st := String(sc.body_look.get("stage", "")) if not sc.body_look.is_empty() else ""
		if st != "" and st != "adult":
			PlayerAppearance.dress(body, AppearanceStore.validate(ChildLook.dress_look(ChildLook.young(sc.body_look, st), float(sc.look.get("sex", 0.0)), st)))
			ChildBody.shape_body(body, sc.body_look, st)
			_work_clips = CLIP_WORK_YOUNG
		else:
			PlayerAppearance.dress(body, AppearanceStore.validate(sc.body_look if not sc.body_look.is_empty() else sc.look))
		_body = body
	if ap:
		for c in [CLIP_IDLE, CLIP_WALK, CLIP_RUN, CLIP_WORK, CLIP_WORK_YOUNG[1]]:
			var full := "%s/%s" % [LIB, c]
			if ap.has_animation(full):
				ap.get_animation(full).loop_mode = Animation.LOOP_LINEAR
	_show(CLIP_IDLE)


## GROWTH: a young worker's proportions (a junior: growth.json stage scale and head): the model scaled, the head bigger, the collider to fit.
func set_proportions(scale_v: float, head_v: float) -> void:
	if _model == null:
		return
	_model.scale = Vector3.ONE * scale_v
	# a body shaped for its stage has its head baked in (ChildProportion.shape); an older one only takes the head scale
	if ChildProportion.of(_body) == null:
		ChildProportion.attach(sk).head_scale = head_v
	for c in get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is CapsuleShape3D:
			var cap := (c as CollisionShape3D).shape as CapsuleShape3D
			cap.radius = maxf(0.3 * scale_v, 0.14)
			cap.height = maxf(1.7 * scale_v, cap.radius * 2.0 + 0.05)
			(c as CollisionShape3D).position.y = cap.height * 0.5


func _player_yaw_offset() -> float:
	if player != null and player.get("model_yaw_offset_deg") != null:
		return float(player.get("model_yaw_offset_deg"))
	return 180.0


func _show(clip: String, speed := 1.0) -> void:
	if ap == null:
		return
	var full := "%s/%s" % [LIB, clip]
	if not ap.has_animation(full):
		return
	ap.speed_scale = speed
	if _clip != clip:
		_clip = clip
		ap.play(full, 0.25)


# ---------------------------------------------------------------- her day
func _physics_process(dt: float) -> void:
	if sc == null or player == null or not is_instance_valid(player):
		return
	var move := Vector3.ZERO
	var speed := WALK_SPEED
	var baby_errand: Variant = errand.call(dt) if errand.is_valid() else null   # BABY
	if baby_errand is Array:
		if _phase != "":
			_phase = ""
			_chore = false
			_clip = ""
		move = baby_errand[0]
		speed = baby_errand[1]
	elif _phase != "":
		_work_step(dt)
	elif sc.busy():
		# a task began where she stands: kneel to it
		_chore = false
		_start_work()
	else:
		var d := _decide(dt)
		move = d[0]
		speed = d[1]
	_move(move, speed * Pregnancy.speed_mult(sc.pregnancy, sc.core.state.minutes), dt)   # PREGNANCY: slower late on


## What she does now when not at work: [direction, speed].
func _decide(dt: float) -> Array:
	match sc.role:
		"follow":
			return _follow()
		"stay":
			_has_goal = false
			return [Vector3.ZERO, 0.0]
	# home / outside: plan, walk to the work, begin it there
	if _plan.is_empty():
		_plan = sc.plan()
		if not _plan.is_empty():
			_goal = _site_for(_plan)
			_has_goal = true
	if not _plan.is_empty():
		var to := _goal - global_position
		to.y = 0.0
		if to.length() > ARRIVE:
			_plan_check()
			return [to.normalized(), WALK_SPEED]
		var id := String(_plan.task)
		_plan = {}
		_has_goal = false
		if id == "cook":
			sc.set_place("home")
		if sc.begin(id):
			_start_work()
		return [Vector3.ZERO, 0.0]
	# nothing to do: her chores round the house, in a loop (asleep, indoors, at night)
	if sc.role == "home" and sc.awake():
		return _chores(dt)
	var back := (hearth if sc.role == "home" else home) - global_position
	back.y = 0.0
	if back.length() > 3.0:
		return [back.normalized(), WALK_SPEED]
	return [Vector3.ZERO, 0.0]


## Round the house: to a spot near the hearth or the home, a spell of work there (the kneeling clips, tidying, laying
## the fire), a rest, and on to the next.
func _chores(dt: float) -> Array:
	if not _has_goal:
		_chore_wait -= dt
		if _chore_wait > 0.0:
			return [Vector3.ZERO, 0.0]
		_chore_face = Vector3.INF
		var p := Vector3.ZERO
		var st: Node3D = _chore_station() if _rng.randf() < 0.45 else null
		if st != null:
			# a spell at a bench, frame or hoop: beside it, turned to it
			_chore_face = st.global_position
			p = st.global_position + _ring(1.3)
		else:
			var centre := hearth if _rng.randf() < 0.6 else home
			p = centre + _ring(_rng.randf_range(1.0, 5.0))
		p.y = global_position.y
		_goal = p
		_has_goal = true
	var to := _goal - global_position
	to.y = 0.0
	if to.length() > ARRIVE or _stuck_t > 3.0:
		if _stuck_t > 3.0:
			_stuck_t = 0.0
			_has_goal = false
			_chore_wait = 1.0
		return [to.normalized(), WALK_SPEED]
	_has_goal = false
	_chore_wait = _rng.randf_range(2.0, 6.0)
	_chore_len = _rng.randf_range(6.0, 14.0)
	_chore = true
	_look_on = _chore_face != Vector3.INF
	_look_at = _chore_face
	_phase = "in"
	_phase_t = 0.0
	_play_work(_work_clips[0])
	return [Vector3.ZERO, 0.0]


## Gives up a plan whose spot she cannot reach (stuck against something for a while).
func _plan_check() -> void:
	# the woods are everywhere out there: stuck among the trees short of a woods spot, she works where she stands (a field
	# lesson's child is with her either way) instead of giving the plan up
	if _stuck_t > 1.5 and String(_plan.get("site", "")) == "woods" \
			and Vector2(global_position.x - home.x, global_position.z - home.z).length() >= WOODS_RANGE.x * 0.5:
		_goal = Vector3(global_position.x, _goal.y, global_position.z)
		_stuck_t = 0.0
		return
	if _stuck_t > 4.0:
		_plan = {}
		_has_goal = false
		_stuck_t = 0.0
		sc.abandon_plan()
		sc._cool = SpouseCore.RETRY_MIN * 0.3


func _follow() -> Array:
	var to := player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > FOLLOW_FAR or (_clip in [CLIP_WALK, CLIP_RUN] and d > FOLLOW_NEAR):
		return [to.normalized(), RUN_SPEED if d > FOLLOW_RUN else WALK_SPEED]
	# stands facing the player
	_face = atan2(-to.x, -to.z) if d > 0.1 else _face
	return [Vector3.ZERO, 0.0]


## Where a plan's work is.
func _site_for(plan: Dictionary) -> Vector3:
	match String(plan.site):
		"home":
			return hearth + _ring(1.1)
		"carcass", "fire", "pile", "smoke", "rack", "frame", "hoop":
			# the station or carcass the plan claimed (the finders, when it names none)
			var o: Object = plan.get("obj")
			var at := _pos_of(o if o != null and is_instance_valid(o) else sc.find_site(String(plan.site)))
			var reach := 1.2 if String(plan.site) == "carcass" else 1.5
			return (at + _ring(reach)) if at != Vector3.INF else home
	# the woods: a spot round home, on the ground
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(WOODS_RANGE.x, WOODS_RANGE.y)
	var p := home + Vector3(cos(ang), 0.0, sin(ang)) * r
	p.y = FrontierTerrain.height_at(p.x, p.z)
	return p


## Where a station object is (Vector3.INF: not a place).
func _pos_of(o: Object) -> Vector3:
	if o is Node3D:
		return (o as Node3D).global_position
	if o != null and o.has_method("pos"):
		return o.pos()
	return Vector3.INF


## A drying rack with a lit campfire beside it (the meat hangs over the fire).
func _lit_rack() -> Object:
	var st := HouseholdSites.station(get_tree(), "drying_rack", hearth, HOUSE_RANGE, CampStation.DRY_FIRE_M) as Node3D
	if st != null and HouseholdSites._lit_fire_near(get_tree(), st.global_position, CampStation.DRY_FIRE_M):
		return st
	return null


## A station of one of her chore kinds within reach of the house, picked at random (null: none).
func _chore_station() -> Node3D:
	var opts: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group(BuiltPiece.GROUP):
		var st := (n as Node).get_node_or_null("Station") as CampStation
		if st != null and st.kind in CHORE_KINDS and st.global_position.distance_to(hearth) <= HOUSE_RANGE:
			opts.append(st)
	return opts[_rng.randi() % opts.size()] if not opts.is_empty() else null


func _ring(r: float) -> Vector3:
	var a := _rng.randf() * TAU
	return Vector3(cos(a), 0.0, sin(a)) * r


## The lit campfire nearest the hearth (within 12 m) that is low on wood.
func _fire_needing_wood() -> Object:
	var best: Object = null
	var bd := 12.0
	for n in get_tree().get_nodes_in_group(Campfire.GROUP):
		var c := n as Campfire
		if c == null or not is_instance_valid(c) or not c.is_lit() or c.wood_left() > 1 or c.fuel_min() > 100.0:
			continue
		var d := c.global_position.distance_to(hearth)
		if d < bd:
			bd = d
			best = c
	return best


## The carcass nearest the hearth that is worth working, passing over the ids in `skip` (another worker has it).
func _carcass_near_home(skip: Array = []) -> Object:
	var best: Object = null
	var bd := 30.0
	for n in get_tree().get_nodes_in_group(&"carcasses"):
		var a := n as Node3D
		if a == null or not is_instance_valid(a) or a.get("meat_left") == null or skip.has(a.get_instance_id()):
			continue
		if float(a.get("meat_left")) <= 0.02 or a.get("dress_step") == null or int(a.get("dress_step")) >= 2:
			continue
		var d := a.global_position.distance_to(hearth)
		if d < bd:
			bd = d
			best = a
	return best


# ---------------------------------------------------------------- at work
func _start_work() -> void:
	if sc.task == "teach":   # GROWTH: a lesson is given standing, turned to the child
		_phase = "lesson"
		_phase_t = 0.0
		_has_goal = false
		_look_on = false
		var h := Household.find(get_tree())
		var kid: Node3D = h.growth.lesson_child(sc) if h != null and h.growth != null else null
		if kid != null:
			_look_at = kid.global_position
			_look_on = true
		_clip = ""
		_show(CLIP_IDLE)
		return
	_phase = "in"
	_phase_t = 0.0
	_has_goal = false
	_look_on = false
	if sc.task == "cook":
		_look_at = hearth
		_look_on = true
	elif SpouseCore.site_of(sc.task) not in ["home", "woods"]:
		# faces the station, fire or carcass the job works at
		var at := _pos_of(sc.site_object())
		if at != Vector3.INF:
			_look_at = at
			_look_on = true
	_show(_work_clips[1])
	_clip = ""
	_play_work(_work_clips[0])


func _play_work(clip: String) -> void:
	if ap == null:
		return
	var full := "%s/%s" % [LIB, clip]
	if ap.has_animation(full):
		ap.speed_scale = 1.0
		ap.play(full, 0.2)
		_clip = clip


func _work_step(dt: float) -> void:
	_phase_t += dt
	if _look_on:
		var to := _look_at - global_position
		_face = atan2(-to.x, -to.z)
	match _phase:
		"lesson":   # GROWTH
			if not sc.busy():
				_phase = ""
				_look_on = false
				_show(CLIP_IDLE)
		"in":
			var l := _len(_work_clips[0])
			if _phase_t >= l:
				_phase = "work"
				_phase_t = 0.0
				_play_work(_work_clips[1])
		"work":
			if (_chore and (sc.busy() or _phase_t >= _chore_len)) or (not _chore and not sc.busy()):
				_phase = "out"
				_phase_t = 0.0
				_play_work(_work_clips[2])
		"out":
			if _phase_t >= minf(1.4, _len(_work_clips[2])):
				_phase = ""
				_chore = false
				_show(CLIP_IDLE)


func _on_task_finished(_task: String, _text: String) -> void:
	_plan = {}
	sc.abandon_plan()


func _len(clip: String) -> float:
	var full := "%s/%s" % [LIB, clip]
	return ap.get_animation(full).length if ap and ap.has_animation(full) else 1.0


# ---------------------------------------------------------------- moving
func _move(dir: Vector3, speed: float, dt: float) -> void:
	var v := velocity
	if not is_on_floor():
		v.y -= GRAVITY * dt
	else:
		v.y = -0.5
	var moving := dir.length() > 0.01 and speed > 0.0
	if moving:
		var want := _steer(dir.normalized())
		v.x = want.x * speed
		v.z = want.z * speed
		_face = lerp_angle(_face, atan2(-want.x, -want.z), clampf(dt * 8.0, 0.0, 1.0))
		_show(CLIP_RUN if speed > WALK_SPEED + 0.5 and ap and ap.has_animation("%s/%s" % [LIB, CLIP_RUN]) else CLIP_WALK,
				speed / WALK_SPEED if speed <= WALK_SPEED + 0.5 else speed / RUN_SPEED)
	else:
		v.x = move_toward(v.x, 0.0, 12.0 * dt)
		v.z = move_toward(v.z, 0.0, 12.0 * dt)
		if _phase == "":
			_show(CLIP_IDLE if idle_clip == "" else idle_clip)   # BABY: idle_clip while sitting or kneeling with the baby
	velocity = v
	rotation.y = lerp_angle(rotation.y, _face, clampf(dt * 10.0, 0.0, 1.0))
	move_and_slide()
	if moving and global_position.distance_to(_last) < speed * dt * 0.25:
		_stuck_t += dt
	else:
		_stuck_t = maxf(_stuck_t - dt, 0.0)
	_last = global_position


## The way she goes to move along `dir`: turned aside when something solid is close ahead.
func _steer(dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.5
	for k in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var d := dir.rotated(Vector3.UP, float(k) + _turn_bias)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 1.1, 1, [get_rid()])
		if space.intersect_ray(q).is_empty():
			if k != 0.0:
				_turn_bias = clampf(float(k) * 0.5, -1.0, 1.0)
			else:
				_turn_bias = move_toward(_turn_bias, 0.0, 0.05)
			return d
	return dir.rotated(Vector3.UP, PI * 0.5)


# ---------------------------------------------------------------- E
func interact_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func interact_prompt(_p: Node) -> String:
	return "Talk to %s" % sc.name if sc else ""


func interact(_p: Node) -> void:
	talk_requested.emit(self, "talk")


func interact_actions(_p: Node) -> Array:
	var out := [{"id": "talk", "text": "Talk to %s" % sc.name}, {"id": "manage", "text": "Household"}]
	var h := Household.find(get_tree())
	if h != null and h.link != null and h.link.following() and sc == h.sc:
		out.push_front({"id": "yoga", "text": "Choose a yoga pose"})   # she follows for yoga: E asks for the pose
	return out


func interact_action(_p: Node, id: String) -> void:
	if id == "yoga":
		var h := Household.find(get_tree())
		if h != null and h.link != null:
			h.link.request_pose()
		return
	talk_requested.emit(self, "tasks" if id == "manage" else "talk")

