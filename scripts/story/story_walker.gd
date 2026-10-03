class_name StoryWalker
extends CharacterBody3D
## Someone the story walks who never fights (docs/main_story.md 10.1-10.2: the neighbours brought to the ford on the raid's
## night, Jost beside you on the march, Rook walking you home): an NpcBody (Actor_B dressed from a look, its own few clips) on
## a walking body of its own layer (it does not block the player, nor he it), walked on the walk grid as a fighter is
## (NavMover use_grid: planned once, rays adjusting it), straight with a light probe where there is no way.
##
##   var w := StoryWalker.make(level, at, StoryWalker.settler_look("palatine_f_a"), {"tag": "neighbour", "group": "raid_neighbours"})
##   w.follow(player, Vector3(-1.2, 0.0, 1.6))   keeps that place beside them (x right, z behind), walking; runs to catch up
##   w.go(p, StoryWalker.RUN)                    goes there (arrived(), `arrived_at`)
##   w.stop(face)                                stands (facing a point)
##   w.crouch(true)                              crouched where it stands (waiting in a field, sat at a fire)
##   w.play_once("club_intro")                   a one-shot clip of NpcBody's (a gesture); while it plays it stands
## A child (opts size 0.7: Jost at nine): the model at that scale, the clips' rate scaled to its stride, its capsule smaller.
## Shadowless (opts shadow false): none of its meshes casts a shadow (Rook, who has none under our sun: docs 9.2).
## Nobody is hurt here: a ball or a blow that meets it stops in it and does nothing (apply_hit; `hits` counts them), it has no
## hit parts, and it never dies (is_dead false: the story's escort and follow kinds read it).
## LEVEL OF DETAIL (as the fighters' and the animals'): every LOD_S its body's clips are stepped at WildlifeSpawner.anim_step_at
## its distance from the camera (every frame only within 40 m), and past NpcSenses.VISIBLE_M it is not drawn nor stepped. One
## standing settled (no one to follow, nowhere to go, on the ground, still, facing where it should) rests: its physics is left
## alone but a look every REST_S (an order wakes it at once).

signal arrived_at(at: Vector3)

const WALK := 1.3
const RUN := 3.4
const GRAVITY := 18.0
const ACCEL := 5.0
const DECEL := 8.0
## Its own layer (ChildBody's): the ground and walls stop it, it does not block the player's walk.
const LAYER := 1 << 11
const RADIUS := 0.3
const HEIGHT := 1.7
## Following: stands within NEAR of its place, sets off again past FAR, runs past RUN_FROM.
const NEAR := 0.8
const FAR := 2.0
const RUN_FROM := 6.0
## Its plan on the walk grid is made again for a goal that moved more than this (m), or this share of the way, at most once each
## REPLAN_S (a moving leader's place).
const GOAL_SNAP_M := 2.5
const GOAL_SNAP_FRAC := 0.3
const REPLAN_S := 1.0
## Fewer metres than this to go, it walks straight (no plan).
const STRAIGHT_M := 10.0
## The level of detail looked at this often (s); a resting one's physics looked at this often (s).
const LOD_S := 0.5
const REST_S := 0.5
## The look's garments wanted (the first this build dresses in, by slot), as NpcFactions' looks: a settler man's working dress
## (the tucked shirt under the waistcoat), a settler woman's (cap, kerchief, stays and apron over the shift and petticoat).
const SETTLER_WANTS := {"shirt": ["shirt_tucked"], "head": ["round_hat"], "vest": ["waistcoat_sb"], "legs.over": ["stockings"],
		"feet": ["shoes_buckled"]}
const SETTLER_WANTS_WOMEN := {"head": ["cap_linen"], "vest": ["stays_laced"], "accessories.neck": ["kerchief_womens"],
		"accessories.waist": ["apron"], "legs.over": ["stockings"], "feet": ["shoes_buckled"]}
## The story people's own clothes by tag (costume, person_look): Margaretha, Anna, Jost, Vane, Leclerc, Ithel, Rook.
const COSTUMES := "res://data/story/costumes.json"
static var _costumes := {}

var tag := ""
var label := ""
var look := {}
## Model scale (a child 0.7).
var size := 1.0
## Its meshes cast shadows (Rook: false).
var shadow := true
var body: NpcBody
var nav: NavMover
## Following: who, and its place beside them (their frame: x to the right, z behind).
var leader: Node3D
var side := Vector3(0.0, 0.0, 1.6)
## Going: where, how fast, there within.
var goal := Vector3.INF
var pace := WALK
var arrive := 0.8
## Hits taken (it is never hurt).
var hits := 0
var is_crouching := false
## Never: a property, not a method (StoryObjectives reads either; WildlifeSpawner.people_near reads a property).
var is_dead := false
var _face := 0.0
var _dt := 0.0
var _following := false
var _nav_goal := Vector3.INF
var _replan_t := 0.0
var _steer_t := 0.0
var _steer_k := 0.0
var _stuck_t := 0.0
var _last := Vector3.ZERO
var _once_t := 0.0
var _face_at := Vector3.INF
var _was_arrived := true
var _shade_t := 0.0
var _shade_n := 0
var _back := Vector3.ZERO
var _lod_t := 0.0
## Standing settled: the physics frame skipped but a look every REST_S (rest_now(); an order wakes it).
var resting := false
var _rest_t := 0.0


## A walker at `at` (on the ground) in `p_look`, under `parent` (a plain Node or the level). opts: tag, name (label), group
## (a group, or an Array of them), size, shadow, face (a point), node_name.
static func make(parent: Node, at: Vector3, p_look: Dictionary, opts := {}) -> StoryWalker:
	var w := StoryWalker.new()
	w.look = p_look
	w.tag = String(opts.get("tag", ""))
	w.label = String(opts.get("name", w.tag.capitalize()))
	w.size = float(opts.get("size", 1.0))
	w.shadow = bool(opts.get("shadow", true))
	w.name = "StoryWalker_" + String(opts.get("node_name", w.tag if w.tag != "" else "person")).validate_node_name()
	var groups: Variant = opts.get("group", [])
	for g in (groups if groups is Array else [groups]):
		if String(g) != "":
			w.add_to_group(StringName(String(g)))
	var gp := Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)
	w.position = gp + Vector3.UP * 0.05
	var face: Variant = opts.get("face")
	if face is Vector3:
		var d := (face as Vector3) - gp
		if Vector2(d.x, d.z).length() > 0.05:
			w.rotation.y = atan2(-d.x, -d.z)
	parent.add_child(w)
	return w


## A settler's look: the peoples preset `preset` (CharacterPeoples) in the basic dress for its sex with `wants` over it (slot ->
## garment ids, the first this build dresses in), as NpcFactions.look_for dresses a fighter; by default a man's SETTLER_WANTS,
## a woman's SETTLER_WANTS_WOMEN.
static func settler_look(preset: String, wants: Variant = null) -> Dictionary:
	var look := CharacterPeoples.preset_look(preset)
	if look.is_empty():
		look = CharacterPeoples.preset_look("palatine_m_a")
	var sex := float(look.get("sex", 1.0))
	if not (wants is Dictionary):
		wants = SETTLER_WANTS if sex >= 0.5 else SETTLER_WANTS_WOMEN
	var outfit := {}
	for slot: String in (wants as Dictionary):
		for gid: Variant in (wants as Dictionary)[slot]:
			if PlayerOutfit.usable(String(gid)):
				outfit[slot] = {"id": String(gid), "colors": {}}
				break
	var basic := PlayerOutfit.basic(sex)
	for slot: String in basic:
		if not outfit.has(slot):
			outfit[slot] = {"id": String(basic[slot].id), "colors": {}}
	look["outfit"] = outfit
	return look


## A child's look at nine (Growth's "child" stage): the preset's face toward a child's (ChildLook.young), the child's flat body
## keys and a child's clothes (a boy's shirt and breeches, a girl's shift and petticoat).
static func child_look(preset: String) -> Dictionary:
	var base := CharacterPeoples.preset_look(preset)
	if base.is_empty():
		base = CharacterPeoples.preset_look("palatine_m_a")
	var sex := float(base.get("sex", 1.0))
	return ChildLook.dress_look(ChildLook.young(ChildLook.body_for_stage(base, "child"), "child"), sex, "child")


## A story person's look: the peoples preset (a child of nine when `child`: child_look) in the costume of `p_tag` over the basic
## dress when data/story/costumes.json has one (in_costume), else as a settler (settler_look). `mission`: the mission it is
## made for (its costume's by_mission dress for it: Margaretha's jacket and cloak).
##   StoryWalker.person_look("palatine_f_a", "margaretha")      StoryWalker.person_look("palatine_m_b", "jost", true)
static func person_look(preset: String, p_tag: String, child := false, mission := "") -> Dictionary:
	if child:
		return in_costume(child_look(preset), p_tag, mission)
	return in_costume(settler_look(preset, {} if not costume(p_tag).is_empty() else null), p_tag, mission)


## `p_look` in the costume of `p_tag` (the look itself when there is none): the costume's garments over the look's slot by
## slot (a slot it does not name keeps the look's), its hair style; for `mission`, its by_mission garments over those.
static func in_costume(p_look: Dictionary, p_tag: String, mission := "") -> Dictionary:
	var c := costume(p_tag, mission)
	if c.is_empty():
		return p_look
	var out := p_look.duplicate(true)
	var outfit: Dictionary = (out.get("outfit") as Dictionary).duplicate(true) if out.get("outfit") is Dictionary else {}
	var co: Dictionary = c.get("outfit", {}) if c.get("outfit") is Dictionary else {}
	for slot: String in co:
		outfit[slot] = (co[slot] as Dictionary).duplicate(true) if co[slot] is Dictionary else {"id": String(co[slot]), "colors": {}}
	out["outfit"] = outfit
	if String(c.get("hair_style", "")) != "":
		var h: Dictionary = (out.get("hair") as Dictionary).duplicate() if out.get("hair") is Dictionary else {}
		h["style"] = String(c.hair_style)
		out["hair"] = h
	return out


## The costume of the story person tagged `p_tag` (data/story/costumes.json: {"outfit": {slot: {id, colors}}, "hair_style",
## "by_mission": {mission id: {slot: {id, colors}}}}), {} when there is none; for `mission` with a by_mission entry, that
## dress over its outfit slot by slot (the costume of the season: a jacket out of doors in late October, a cloak at night).
static func costume(p_tag: String, mission := "") -> Dictionary:
	if _costumes.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(COSTUMES)) if FileAccess.file_exists(COSTUMES) else null
		_costumes = ((d as Dictionary).get("costumes", {}) if d is Dictionary else {}) as Dictionary
	var c: Variant = _costumes.get(p_tag, {}) if p_tag != "" else {}
	if not (c is Dictionary):
		return {}
	var out: Dictionary = (c as Dictionary).duplicate(true)
	var bm: Variant = out.get("by_mission", {})
	if mission != "" and bm is Dictionary and (bm as Dictionary).get(mission) is Dictionary:
		var outfit: Dictionary = out.get("outfit", {}) if out.get("outfit") is Dictionary else {}
		var over: Dictionary = (bm as Dictionary)[mission]
		for slot: Variant in over:
			outfit[slot] = over[slot]
		out["outfit"] = outfit
	return out


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 1
	platform_floor_layers = 0
	platform_wall_layers = 0
	floor_snap_length = 0.4
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(RADIUS * size, 0.15)
	cap.height = maxf(HEIGHT * size, cap.radius * 2.0 + 0.05)
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)
	body = NpcBody.new()
	body.name = "Body"
	add_child(body)
	body.build(look)
	body.drop_parts()                     # (no hit parts: nobody here is a target)
	if size < 0.85 and body.mesh:
		# a child's own body (as the household's children: ChildBody, Growth's "child" stage), not a grown body shrunk
		ChildBody.shape_body(body.mesh, look, "child")
	if not is_equal_approx(size, 1.0):
		body.scale = Vector3.ONE * size
	nav = NavMover.new(null, RADIUS * size)
	nav.body = self
	nav.use_grid = true
	nav.landmarks = false
	nav.can = WalkGrid.CHILD.duplicate() if size < 0.85 else WalkGrid.PERSON.duplicate()
	nav.can["climb_m"] = 0.0
	_face = rotation.y
	_last = global_position
	_replan_t = randf() * REPLAN_S
	_lod_t = randf() * LOD_S
	if not shadow:
		_unshade()


## A ball or a blow meeting it: it stops here and does nothing (nobody is hurt in these scenes).
func apply_hit(_damage: float, _point: Vector3, _direction: Vector3, _source: Node = null, _part := "body") -> void:
	hits += 1


# ---------------------------------------------------------------- orders
## Keeps its place beside `who` (their frame: `p_side`.x to the right, .z behind), walking, running to catch up.
func follow(who: Node3D, p_side := Vector3(0.0, 0.0, 1.6)) -> void:
	resting = false
	leader = who
	side = p_side
	goal = Vector3.INF
	_face_at = Vector3.INF
	_back = Vector3.ZERO
	crouch(false)


## Goes to `to` at `p_pace`, there within `p_arrive` (`arrived_at` when it gets there).
func go(to: Vector3, p_pace := WALK, p_arrive := 0.8) -> void:
	resting = false
	leader = null
	goal = to
	pace = p_pace
	arrive = p_arrive
	_face_at = Vector3.INF
	_was_arrived = false
	crouch(false)


## Stands where it is (facing `face` when given).
func stop(face := Vector3.INF) -> void:
	resting = false
	leader = null
	goal = Vector3.INF
	_face_at = face


func crouch(on: bool) -> void:
	if on != is_crouching:
		resting = false
	is_crouching = on


func arrived() -> bool:
	return goal == Vector3.INF or _flat(global_position, goal) <= arrive + 0.05


## A one-shot clip of the body's (NpcBody.CLIPS / OWN_CLIPS keys); it stands while it plays. Its length (0: no such clip).
func play_once(key: String, blend := 0.12) -> float:
	if body == null:
		return 0.0
	body.set_arms("")
	resting = false
	var l := body.play_once(key, blend)
	_once_t = maxf(_once_t, l)
	return l


## Turned to `p` at once.
func face_now(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		_face = atan2(-d.x, -d.z)
		rotation.y = _face
		resting = false


func forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


# ---------------------------------------------------------------- each frame
func _physics_process(dt: float) -> void:
	_lod(dt)
	if resting:
		_rest_t -= dt
		if _rest_t > 0.0:
			return
		resting = false                  # (a full step now and then: anything that moved it on wakes it)
	_dt = dt
	_once_t = maxf(_once_t - dt, 0.0)
	var dir := Vector3.ZERO
	var speed := 0.0
	var want := Vector3.INF
	var face_to := _face_at
	if leader != null and is_instance_valid(leader):
		want = _place_by(leader)
		var d := _flat(global_position, want)
		if _following:
			_following = d > NEAR
		else:
			_following = d > FAR
		if _following:
			speed = RUN if d > RUN_FROM else WALK * clampf(0.75 + d * 0.25, 0.8, 1.4)
		else:
			face_to = global_position - _leader_back(leader) * 4.0
			want = Vector3.INF
	elif goal != Vector3.INF:
		if _flat(global_position, goal) > arrive:
			want = goal
			speed = pace
		elif not _was_arrived:
			_was_arrived = true
			arrived_at.emit(goal)
	if _once_t > 0.0:
		want = Vector3.INF
	if want != Vector3.INF and speed > 0.0:
		dir = _way(want, speed)
	if is_crouching:
		speed = minf(speed, NpcFighter.CROUCH_SPEED)
	var v := velocity
	v.y = -0.5 if is_on_floor() else v.y - GRAVITY * dt
	var hv := Vector2(v.x, v.z)
	if dir != Vector3.ZERO:
		hv = hv.move_toward(Vector2(dir.x, dir.z) * speed, ACCEL * dt * (1.6 if speed > WALK + 0.5 else 1.0))
		_face = lerp_angle(_face, atan2(-dir.x, -dir.z), clampf(dt * 8.0, 0.0, 1.0))
	else:
		hv = hv.move_toward(Vector2.ZERO, DECEL * dt)
		if face_to != Vector3.INF:
			var fd := face_to - global_position
			if Vector2(fd.x, fd.z).length() > 0.1:
				_face = lerp_angle(_face, atan2(-fd.x, -fd.z), clampf(dt * 5.0, 0.0, 1.0))
	v.x = hv.x
	v.z = hv.y
	velocity = v
	rotation.y = lerp_angle(rotation.y, _face, clampf(dt * 9.0, 0.0, 1.0))
	move_and_slide()
	if dir != Vector3.ZERO and global_position.distance_to(_last) < speed * dt * 0.25:
		_stuck_t += dt
	else:
		_stuck_t = maxf(_stuck_t - dt, 0.0)
	_last = global_position
	_pose()
	if not shadow and _shade_n < 4:
		_shade_t -= dt
		if _shade_t <= 0.0:
			_shade_t = 0.5
			_shade_n += 1
			_unshade()             # (garments dressed a little after the body: none of them casts one either)
	if _settled(face_to):
		resting = true
		_rest_t = REST_S


## Standing settled: no one to follow and nowhere to go (there, its arrival told), no one-shot playing, on the ground and
## still, turned to where it faces, its garments all unshaded (Rook).
func _settled(face_to: Vector3) -> bool:
	if leader != null or _once_t > 0.0 or not is_on_floor() or (not shadow and _shade_n < 4):
		return false
	if goal != Vector3.INF and (not _was_arrived or not arrived()):
		return false
	if Vector2(velocity.x, velocity.z).length() > 0.05 or absf(angle_difference(rotation.y, _face)) > 0.02:
		return false
	if face_to != Vector3.INF:
		var fd := face_to - global_position
		if Vector2(fd.x, fd.z).length() > 0.1 and absf(angle_difference(_face, atan2(-fd.x, -fd.z))) > 0.02:
			return false
	return true


## The level of detail: the body's clips stepped for the distance from the camera, not drawn nor stepped past VISIBLE_M.
func _lod(dt: float) -> void:
	_lod_t -= dt
	if _lod_t > 0.0 or body == null:
		return
	_lod_t = LOD_S
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var d := cam.global_position.distance_to(global_position)
	var near := d < NpcSenses.VISIBLE_M
	body.anim_step = WildlifeSpawner.anim_step_at(d)
	if body.visible != near:
		body.visible = near
	body.animate = near


## Its place beside `who` (their frame: side.x right, side.z behind), on the ground.
func _place_by(who: Node3D) -> Vector3:
	var back := _leader_back(who)
	var right := back.cross(Vector3.UP).normalized() * -1.0
	var p := who.global_position + right * side.x + back * side.z
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


## The way behind `who` (flat): opposite the way it moves; standing, the way it last moved (at first: from it to this walker,
## so a walker told to follow keeps the side it is on).
func _leader_back(who: Node3D) -> Vector3:
	var v := NpcSenses.velocity_of(who)
	var f := Vector3(v.x, 0.0, v.z)
	if f.length() >= 0.4:
		_back = -f.normalized()
	elif _back == Vector3.ZERO:
		var d := global_position - who.global_position
		d.y = 0.0
		_back = d.normalized() if d.length() > 0.1 else Vector3.BACK
	return _back


## Which way to `to` now: going somewhere far, along the walk grid's plan; following someone (their place moves on all the
## time: a plan for where it was is soon stale) or near, straight, turned aside by a light probe a few times a second; held
## up a while (stuck), on the plan whatever it does.
func _way(to: Vector3, _speed: float) -> Vector3:
	_replan_t += _dt
	var flat_d := _flat(global_position, to)
	var following := leader != null and is_instance_valid(leader)
	if (flat_d > STRAIGHT_M and not following) or _stuck_t > 0.8:
		var moved := _flat(_nav_goal, to) if _nav_goal != Vector3.INF else INF
		var need := maxf(GOAL_SNAP_M, flat_d * GOAL_SNAP_FRAC)
		if moved > need and (_replan_t >= REPLAN_S or moved > need * 2.0 + 4.0):
			_nav_goal = to
			_replan_t = 0.0
		var d := nav.steer(_nav_goal, _dt, arrive)
		if nav.on_path:
			if nav.status == NavMover.ARRIVED and flat_d > arrive + 0.05:
				_nav_goal = Vector3.INF
			return d
	var st := to - global_position
	st.y = 0.0
	if st.length() <= 0.05:
		return Vector3.ZERO
	var line := st.normalized()
	_steer_t -= _dt
	if _steer_t <= 0.0:
		_steer_t = 0.2
		_steer_k = _probe(line)
	return line.rotated(Vector3.UP, _steer_k)


## How far to turn off `dir` (rad) for what is solid close ahead (five rays; the one it follows is no obstacle).
func _probe(dir: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.6 * maxf(size, 0.6)
	var ex: Array[RID] = [get_rid()]
	if leader != null and is_instance_valid(leader) and leader is CollisionObject3D:
		ex.append((leader as CollisionObject3D).get_rid())
	for k: float in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir.rotated(Vector3.UP, k) * 1.2, 1, ex)
		if space.intersect_ray(q).is_empty():
			return k
	return PI * 0.5


## The clip for what it does now (a one-shot playing keeps its own).
func _pose() -> void:
	if body == null or _once_t > 0.0:
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	var stride := maxf(size, 0.3)
	if hs > 0.25:
		if is_crouching:
			body.play("crouch_walk", 0.25, clampf(hs / (NpcFighter.CROUCH_SPEED * stride), 0.5, 1.8))
		elif hs > WALK * stride + 0.6:
			body.play("run", 0.25, clampf(hs / (RUN * stride), 0.6, 1.8))
		else:
			body.play("walk", 0.25, clampf(hs / (WALK * stride), 0.5, 1.8))
	else:
		body.play("crouch" if is_crouching else "idle", 0.3)


## None of its meshes casts a shadow (Rook).
func _unshade() -> void:
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Whether any of its meshes casts a shadow (tests).
func casts_shadow() -> bool:
	for g in find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi.visible and gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return true
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
