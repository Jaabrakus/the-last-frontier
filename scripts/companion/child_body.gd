class_name ChildBody
extends CharacterBody3D
## A child's walking body, from the toddler stage on (user 2026-09-28: "the SCALED Actor_B rig: child proportions: smaller body, bigger
## head ratio, using the existing walk/idle/work clips with stride scaled"). The same Actor_B rig and clips as Spouse, dressed from the
## look mixed from its parents, the model scaled by the stage (growth.json scale) with the head bigger (ChildProportion), the walk clip's
## speed set so the feet do not slide (stride scaled: speed / (foot speed x scale)). It follows the parent it is `with` (mother or father,
## or stays where it is when told), stands watching a parent at work, and plays when nobody is busy (picking flowers, sitting).
## Toddlers and children cannot work; the teen who has done the core curriculum is a junior worker (a Spouse body scaled the same way:
## Spouse.set_proportions), not this. E on it: take along / stay / teach / household. Logic lives in Growth, Teaching and GrowthLink.
##   ChildBody.spawn(link, child, at) -> the body;  body.refresh() after a stage change

const LIB := "actor_b"
const CLIP_IDLE := "actor_b-p-relax-idle"
const CLIP_WALK := "actor_b-p-walk-fw"
const CLIP_RUN := "actor_b-p-run-fw"
const CLIP_PLAY := "actor_b-cap-casual-pick-flower-loop"
const CLIP_SIT := "actor_b-cap-casual-sit-floor-loop"
const CLIP_WATCH := "actor_b-cap-look-curiously-front-loop"
const BODY_PATH := "res://assets/character/actor_b_body.glb"
const GRAVITY := 18.0
const CHILD_LAYER := 1 << 11
## The rig's adult foot speeds (m/s): a child's clip is played at speed / (this x scale).
const FOOT_WALK := 1.3
const FOOT_RUN := 3.4
## Follows to within this many metres (x the stage scale + a base), starts again from this far, runs from this far.
const NEAR_BASE := 1.1
const FAR_BASE := 2.2
const RUN_FROM := 8.0
## PATHS: it walks to its guardian along the navigation mesh (NavMover: round trees and buildings, through the gate, opening a shut
## door), straight where there is none. It is brought back beside the guardian only as a last resort: fallen through the ground,
## further than RECOVER_FAR (the player rode or fast-travelled off), further than RECOVER_M with no way to it for LOST_S, or
## further than LOST_M with no way for LOST_LONG_S.
const RECOVER_M := 60.0
const RECOVER_FAR := 150.0
const LOST_S := 4.0
const LOST_M := 20.0
const LOST_LONG_S := 15.0

var link: GrowthLink
var child: Dictionary
var sk: Skeleton3D
var ap: AnimationPlayer
var interact_reach := 2.4

var _model: Node3D
var _prop: ChildProportion
var body: CharacterBodyMesh
var _stage := ""
var _shape: CollisionShape3D
var _clip := ""
var _face := 0.0
var _turn_bias := 0.0
var _rng := RandomNumberGenerator.new()
var _mood := "idle"        ## "idle" | "play" | "sit" | "watch"
var _mood_t := 0.0
var _stuck_t := 0.0
var _last := Vector3.ZERO
## PATHS: its way on the navigation mesh; this frame's direction came from it; how long it has had no way to its guardian;
## how many times it was brought back (the last resort; tests).
var nav: NavMover
var step: BodyStep                ## STEP: over a log in the way
## Following her guardian: from when it is further than `far` till it is within `near` (a stop for a door's swing is not the end
## of it: the clip it was walking in is not the state).
var _following := false
var _nav_dir := false
var _lost_t := 0.0
var teleports := 0


## A child's body at `stage` on the skeleton `sk`: the game's body v4 dressed from `look` (its drawn look: Growth.body_look) in a child's
## clothes (ChildLook.dress_look: `sex` the child's own), then shaped (shape_body). Null without the body.
static func dress_body(sk: Skeleton3D, anim: AnimationPlayer, look: Dictionary, sex: float, stage: String, done := Callable()) -> CharacterBodyMesh:
	var b := CharacterBodyMesh.attach_parts(sk, anim, {"head": BodyMaterials.BODY_GLB})
	if b == null:
		return null
	PlayerAppearance.dress(b, AppearanceStore.validate(ChildLook.dress_look(ChildLook.young(look, stage), sex, stage)))
	shape_body(b, look, stage, done)
	return b


## The stage's proportions (ChildProportion, the stage's form: nothing for an adult), the head's rounding (HeadRound: the stage's and
## the look's child_round) and the skin's smoothness (ChildSkin) on a dressed body.
static func shape_body(b: CharacterBodyMesh, look: Dictionary, stage: String, done := Callable()) -> ChildProportion:
	var form := ChildLook.stage_form(stage)
	var p: ChildProportion = null
	if not form.is_empty():
		# CHILD BAKE: with `done` the bake is off the main thread (ChildProportion.shape_async; `done` when the body is shaped)
		p = ChildProportion.shape_async(b, form, ChildLook.roundness(look, stage), done) if done.is_valid() else ChildProportion.shape(b, form, ChildLook.roundness(look, stage))
	elif done.is_valid():
		done.call(null)            # CHILD BAKE
	ChildSkin.apply(b, ChildLook.skin_smooth(stage))
	return p


static func spawn(l: GrowthLink, c: Dictionary, at: Vector3) -> ChildBody:
	var b := ChildBody.new()
	b.name = "Child_%s" % String(c.get("id", "x")).replace(".", "_")
	b.link = l
	b.child = c
	l.house.get_parent().add_child(b)
	b.global_position = at + Vector3.UP * 0.3
	return b


func _ready() -> void:
	add_to_group(WildlifeSpawner.PEOPLE)   # PEOPLE: the wild keeps off a child as off the player
	add_to_group(PlacedWeapon.GROUP)   # an interactable (Player interactor: interact_prompt, interact_point, interact)
	collision_layer = CHILD_LAYER   # its own layer: the ground and walls stop it, but it does not block the parents' walk (or each other)
	collision_mask = 1
	platform_floor_layers = 0   # no riding on the other bodies: two children (or a child on its mother) launched each other as moving platforms
	platform_wall_layers = 0
	_rng.seed = hash(String(child.get("id", "x"))) ^ int(child.get("seed", 1))
	_shape = CollisionShape3D.new()
	_shape.shape = CapsuleShape3D.new()
	add_child(_shape)
	_build_model()
	refresh()
	nav = NavMover.new(self, 0.2)
	step = BodyStep.new(self, 0.35)


func _build_model(old: Node3D = null) -> void:
	var scene := BackgroundLoad.take("res://characters/Actor_B.tscn") as PackedScene
	_model = scene.instantiate() as Node3D
	_model.visible = false            # CHILD BAKE: shown when its bake is on (_on_shaped), the old body (a stage change) until then
	var p: Variant = link.house.player if link != null and link.house != null else null
	_model.rotation.y = deg_to_rad(float(p.get("model_yaw_offset_deg")) if p != null and p.get("model_yaw_offset_deg") != null else 180.0)
	add_child(_model)
	sk = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] as AnimationPlayer if not aps.is_empty() else null
	# the flat asexual child body at every stage that has this body (ChildLook.body_for_stage through Growth.body_look), clothed for a
	# child, with the stage's proportions, rounded head and soft skin (ChildProportion, HeadRound, ChildSkin)
	_stage = Growth.stage_of(child)
	body = dress_body(sk, ap, Growth.body_look(child, link.now() if link != null and link._ok() else 0.0), float(child.get("sex", 0.0)), _stage, _on_shaped.bind(_model, old))
	if ap:
		for c in [CLIP_IDLE, CLIP_WALK, CLIP_RUN, CLIP_PLAY, CLIP_SIT, CLIP_WATCH]:
			var full := "%s/%s" % [LIB, c]
			if ap.has_animation(full):
				ap.get_animation(full).loop_mode = Animation.LOOP_LINEAR
	_prop = ChildProportion.of(body)
	if body != null:
		var blink := FaceBlink.new()           # (the face engine's blink, on the child's own meshes)
		blink.name = "FaceBlink"
		_model.add_child(blink)
		blink.body = body
	_show(CLIP_IDLE)


## The stage's proportions (after the stage changes): the model's scale, the head, the collider.
func refresh() -> void:
	var s := scale_now()
	if _model != null and _stage != "" and Growth.stage_of(child) != _stage:
		# a new stage: the body made again at its proportions
		var old := _model                 # CHILD BAKE: the old body shows until the new one is shaped
		_model = null
		_clip = ""
		_build_model(old)
	if _model != null:
		_model.scale = Vector3.ONE * s
	var cap := _shape.shape as CapsuleShape3D
	cap.radius = maxf(0.3 * s, 0.14)
	cap.height = maxf(1.7 * s, cap.radius * 2.0 + 0.05)
	_shape.position.y = cap.height * 0.5


## CHILD BAKE: the new body's bake is on: it shows, the one it replaces goes.
func _on_shaped(_p: ChildProportion, m: Node3D, old: Node3D) -> void:
	if is_instance_valid(m):
		m.visible = true
	if is_instance_valid(old):
		old.queue_free()


func scale_now() -> float:
	return Growth.num(child, "scale", 1.0)


## The legs' length at the stage (the model's scale x the form's legs): the walk clip's stride.
func leg_now() -> float:
	return scale_now() * (_prop.leg_scale() if _prop != null else 1.0)


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


# ---------------------------------------------------------------- its day
func _physics_process(dt: float) -> void:
	if link == null or not is_instance_valid(link) or link.house == null:
		return
	var move := Vector3.ZERO
	var speed := 0.0
	_nav_dir = false
	var g: Node3D = link.guardian(child)
	var mode := String(child.get("mode", "follow"))
	var s := scale_now()
	if g != null and mode == "follow":
		var dg := global_position.distance_to(g.global_position)
		var fell := global_position.y < FrontierTerrain.height_at(global_position.x, global_position.z) - 15.0
		if fell or dg > RECOVER_FAR or (dg > RECOVER_M and _lost_t > LOST_S) or (dg > LOST_M and _lost_t > LOST_LONG_S):
			var at := g.global_position + Vector3(0.9, 0.3, 0.9)
			# the last resort, logged: which of the reasons, how far, and what its way said
			print("ChildBody %s: brought back beside its guardian (%s, %.0f m off, lost %.1f s, nav %s)" % [String(child.get("name", name)),
					"fell through" if fell else "too far" if dg > RECOVER_FAR else "no way", dg, _lost_t, nav.reason if nav != null else "-"])
			global_position = at
			velocity = Vector3.ZERO
			_lost_t = 0.0
			teleports += 1
			if nav != null:
				nav.reset()
	if link.frozen(child):
		pass   # a lesson or the household screen has it standing
	elif mode == "follow" and g != null:
		var to := g.global_position - global_position
		to.y = 0.0
		var d := to.length()
		var near := NEAR_BASE + 0.8 * s
		var far := FAR_BASE + 1.2 * s
		# near but with a wall between (the palisade, a shut door): the way round is the way to go
		var walled := d > 1.2 and d <= far and NavMover.walled(self, g)
		if d > far or walled or (_following and d > near):
			_following = true
			var long := d > RUN_FROM or (nav != null and nav.on_path and nav.remaining() > RUN_FROM)
			speed = Growth.num(child, "run_speed", 2.0) if long else Growth.num(child, "walk_speed", 1.0)
			move = _way(g.global_position, dt, 0.9 if walled else near * 0.9)
			if move == Vector3.ZERO and _nav_dir:
				_stand(dt, to, link.guardian_busy(child))   # there by the way, or waiting for a door
			# no way to the guardian (the straight steer, making no headway): lost for a while
			if not _nav_dir and _stuck_t > 0.5:
				_lost_t += dt
			else:
				_lost_t = maxf(_lost_t - dt * 2.0, 0.0)
		else:
			_following = false
			_lost_t = 0.0
			_stand(dt, to, link.guardian_busy(child))
	else:
		_following = false
		_lost_t = 0.0
		_stand(dt, Vector3.ZERO, false)
	_move(move, speed, dt)


## PATHS: the way to `to` now along the navigation mesh (ZERO when there or waiting for a door), or straight at it where there is
## no mesh or no way (turned aside by the probe in _move).
func _way(to: Vector3, dt: float, arrive: float) -> Vector3:
	if nav != null:
		var d := nav.steer(to, dt, arrive)
		if nav.on_path:
			_nav_dir = true
			return d
	var st := to - global_position
	st.y = 0.0
	return st.normalized() if st.length() > 0.05 else Vector3.ZERO


## Standing about: watches a parent at work, else idles and plays for a spell, in a loop.
func _stand(dt: float, to_guardian: Vector3, busy: bool) -> void:
	_mood_t -= dt
	if busy and to_guardian != Vector3.ZERO:
		_mood = "watch"
		_mood_t = 1.0
	elif _mood == "watch" or _mood_t <= 0.0:
		_mood_t = _rng.randf_range(4.0, 9.0)
		var r := _rng.randf()
		_mood = "idle" if r < 0.4 else "play" if r < 0.8 else "sit"
		if not Growth.can(child, "walk"):
			_mood = "idle"
	if to_guardian != Vector3.ZERO and (_mood == "watch" or _mood == "idle"):
		_face = atan2(-to_guardian.x, -to_guardian.z)


func _move(dir: Vector3, speed: float, dt: float) -> void:
	var v := velocity
	if not is_on_floor():
		v.y -= GRAVITY * dt
	else:
		v.y = -0.5
	var s := scale_now()
	var moving := dir.length() > 0.01 and speed > 0.0
	if moving:
		var want := dir.normalized() if _nav_dir else _steer(dir.normalized())
		v.x = want.x * speed
		v.z = want.z * speed
		_face = lerp_angle(_face, atan2(-want.x, -want.z), clampf(dt * 8.0, 0.0, 1.0))
		var run := speed > Growth.num(child, "walk_speed", 1.0) + 0.3
		if run:
			_show(CLIP_RUN, speed / (FOOT_RUN * leg_now()))
		else:
			_show(CLIP_WALK, speed / (FOOT_WALK * leg_now()))   # the stride scaled: short legs step quicker
	else:
		v.x = move_toward(v.x, 0.0, 12.0 * dt)
		v.z = move_toward(v.z, 0.0, 12.0 * dt)
		match _mood:
			"watch":
				_show(CLIP_WATCH)
			"play":
				_show(CLIP_PLAY)
			"sit":
				_show(CLIP_SIT)
			_:
				_show(CLIP_IDLE)
	velocity = v
	rotation.y = lerp_angle(rotation.y, _face, clampf(dt * 10.0, 0.0, 1.0))
	if moving and step != null:
		step.step(Vector3(v.x, 0.0, v.z), speed, dt)   # STEP: up on to a log in the way, and over (BodyStep)
	move_and_slide()
	if moving and global_position.distance_to(_last) < speed * dt * 0.25:
		_stuck_t += dt
	else:
		_stuck_t = maxf(_stuck_t - dt, 0.0)
	_last = global_position


func _steer(dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.4
	for k in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var d := dir.rotated(Vector3.UP, float(k) + _turn_bias)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 0.9, 1, [get_rid()])
		if space.intersect_ray(q).is_empty():
			_turn_bias = clampf(float(k) * 0.5, -1.0, 1.0) if k != 0.0 else move_toward(_turn_bias, 0.0, 0.05)
			return d
	return dir.rotated(Vector3.UP, PI * 0.5)


# ---------------------------------------------------------------- E
func interact_point() -> Vector3:
	return global_position + Vector3.UP * (1.7 * scale_now() * 0.7)


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func interact_prompt(_p: Node) -> String:
	return "%s (%s)" % [String(child.get("name", "")), Growth.stage_name(child).to_lower()]


func interact(_p: Node) -> void:
	link.open_family(String(child.get("id", "")))


func interact_actions(_p: Node) -> Array:
	return link.actions_for(child)


func interact_action(_p: Node, id: String) -> void:
	link.do_action(String(child.get("id", "")), id)
