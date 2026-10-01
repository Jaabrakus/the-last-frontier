class_name StandInGiant
extends Node3D
## The climbing yard's woolly mammoth (user 2026-09-27: "lets add a mammoth in our test climb scene we had a four legged
## monster we could reskin that to be a wolly mammoth"), for trying the grip on a moving body (user 2026-09-27: "theses
## climbs will work on rock service and giants right"). It replaced the first stand-in, a beast of capsules and spheres.
## The look is Riley Kuhlman's low-poly woolly mammoth (CC0, assets/wildlife/ice_age/SOURCE.md) at MODEL_SCALE: about
## 5 m at the shoulders and the dome of the head, 5.5 m from the rump to the face, the tusks curling 2.5 m further. It
## plays the model's own clips: Walk while it paces (at the pacing's speed; backwards as it backs), Idle when it stands,
## HeadShake while it shakes.
## Weak points (user 2026-09-27: "we need weak point animations if they shoot the behind the leg it falls on one knee"):
## behind each knee a small hit zone (HIT_LAYER, like an animal's: a ball, an arrow or a thrown weapon); a hit there and
## that leg buckles: Kneel<leg> (made in Blender, tools/wildlife/mammoth_clips.py: onto the front knee, the body pitched
## forward and rolled toward it; or onto the hind hock, the rump sunk), DOWN_S seconds down (it neither paces nor
## shakes: the time to climb it), then Rise<leg>. As the knee strikes the ground the view shakes for the players about
## (CameraShake).
## It can be killed (user 2026-09-27: "for the mammoth we have to chop it in pieces when we skin it and butcher it"):
## MAX_HEALTH, a hit costing its damage times HIDE_MULT in the hide, KNEE_MULT behind a knee (and down on it), HEAD_MULT
## in the head. Dead it rolls onto a side (Die_L / Die_R, made in Blender) and lies there, a carcass to butcher
## (MammothButchery: each part cut off where the player looks).
## Its temper (MammothTemper, user 2026-09-27: "they will attack us charge at us and swing there trunk to get us to back
## away, there goal is to survive and run away", "do a ground stomp") drives it: set_driven() takes it off its pacing,
## then its home moves and turns (drive_speed, turn_toward()), it walks at that speed, shows its threat (display: the
## head up and shaking) and plays its attacks (act(): TrunkSwing_L / _R, Stomp; the clips from
## tools/wildlife/mammoth_clips.py).
## Under the model are the bodies the grip holds and the player stands on, none with a mesh of its own, every one an
## AnimatableBody3D moved in the physics step (sync_to_physics), so the grip's anchor rides it and a player standing on
## its back is carried:
##   Torso   a capsule lying along the body and a sphere over the shoulders' hump (GripSurface "fur") on Body; down on
##           a leg, on the model's back (TORSO_BONE), so it goes down with the kneel
##   Head    a box over the dome of the skull and the face, on the model's head bone
##   Legs    four capsules from the hip to the toe, on the model's leg bones (they step with the walk)
## It is this project's own stand-in; its geometry and behavior are implemented here.
##
## The model hangs from Body, which paces its beat (walking forward; at each end it may stop to eat, or to drink with
## water within its trunk's reach, and turns round on the spot, its feet stepping round: Turn_L / Turn_R, Eat, Drink,
## made in Blender), sways and breathes; a while after someone climbs on it, it tries to shake them off: bursts
## of rolling, bucking and lurching (SHAKES), so the grip's swing and its "being shaken" clips have something to answer.

## The shakes, in order, repeating (user 2026-09-27: fun "without it being too much to handle"): small ones that only
## jostle the climber, and big ones it warns of first (WARN_S: it crouches, lifts its head and trembles), which fling a
## climber's legs off the fur and cost the grip dearly. Seconds, and the amplitudes of the roll (rad), the pitch (rad),
## the buck (m) and their rates (Hz).
const SHAKES := [
	{"big": false, "s": 2.4, "roll": 0.03, "roll_hz": 1.0, "pitch": 0.02, "pitch_hz": 1.3, "buck": 0.04, "buck_hz": 1.6},
	{"big": true, "s": 3.0, "roll": 0.08, "roll_hz": 0.8, "pitch": 0.03, "pitch_hz": 1.2, "buck": 0.12, "buck_hz": 1.1},
	{"big": false, "s": 2.0, "roll": 0.02, "roll_hz": 1.2, "pitch": 0.03, "pitch_hz": 0.9, "buck": 0.05, "buck_hz": 1.8},
	{"big": true, "s": 2.8, "roll": 0.04, "roll_hz": 0.9, "pitch": 0.09, "pitch_hz": 0.7, "buck": 0.14, "buck_hz": 1.0},
]
## The warning before a big shake (seconds).
const WARN_S := 1.1
const MODEL := "res://assets/wildlife/ice_age/mammoth.glb"
const MODEL_SCALE := 1.2
const CLIP_IDLE := "Idle"
const CLIP_WALK := "Walk"
const CLIP_SHAKE := "HeadShake"
## The Walk clip's ground speed at speed 1 (m/s as modelled, times MODEL_SCALE in the yard): a front foot's travel over
## its stance. The pacing plays it at the pacing's speed.
const WALK_MPS := 0.82
## The coat: the model's "Wool" (a near-black brown as it comes) warmed to a rusty brown, matte.
const WOOL_COLOR := Color(0.5, 0.34, 0.22)
const BODY_R := 1.45                            ## the torso: a capsule lying along the body
const BODY_LEN := 4.7
const BODY_Z := 0.43                            ## the capsule's centre behind the torso's origin (toward the rump)
const HUMP_R := 1.1
const HUMP_AT := Vector3(0.0, 0.95, -0.55)      ## the hump over the shoulders, from the torso's origin
const TORSO_Y := 2.95                           ## the body's axis over the ground
const HEAD_BOX := Vector3(1.8, 2.1, 1.4)
const HEAD_AT := Vector3(0.0, 4.0, -2.75)       ## the head box's centre at rest, from the ground under the torso
const HEAD_BONE := "spine.011"
## The torso follows this bone of the back (its move from the rest pose).
const TORSO_BONE := "spine.007"
const NECK_BONE := "spine.010"
const LEG_R := 0.42
## The legs, in order: their names (the clips' Kneel<name> / Rise<name>, the weak points' "knee_<name>"), their capsules
## from the first bone (the hip) to the second (the toe), and the joint whose back is the weak point (from the first bone,
## the shin, to the second, the foot: KNEE_AT of the way down it).
const LEG_NAMES := ["Front_L", "Front_R", "Hind_L", "Hind_R"]
const LEG_BONES := [["front_thigh.L", "front_toe.L"], ["front_thigh.R", "front_toe.R"],
		["thigh.L", "toe.L"], ["thigh.R", "toe.R"]]
const KNEE_BONES := [["front_shin.L", "front_foot.L"], ["front_shin.R", "front_foot.R"],
		["shin.L", "foot.L"], ["shin.R", "foot.R"]]
const KNEE_AT := 0.72
## The weak point: a sphere this big (m), this far behind the leg's bone line.
const WEAK_R := 0.32
const WEAK_BACK := 0.4
## Seconds down on a buckled leg before it rises, and how much of the idle sway it keeps while down.
const DOWN_S := 6.0
const DOWN_SWAY := 0.25
const MAX_HEALTH := 1200.0
const HIDE_MULT := 0.25
const KNEE_MULT := 1.0
const HEAD_MULT := 2.0
## The knee (or the hock) strikes the ground this far into the kneel (its clip's frame 11 at 24 fps): the ground shakes
## for the players about (CameraShake, user 2026-09-27: "if the mammoth kneels i want the screen to shake for the players
## within the area"), QUAKE close by (within a third of QUAKE_R), nothing past QUAKE_R m, over QUAKE_S seconds.
const KNEE_STRIKE_S := 11.0 / 24.0
const QUAKE := 0.85
const QUAKE_R := 35.0
const QUAKE_S := 1.1
## The pacing (user 2026-09-27, it walked backwards half the time: "lets do the mammoth add turns into blender for
## them"): along its beat, PACE_M either side of where it began, forward at PACE_MPS; at each end it turns round on the
## spot, two quarter turns (Turn_L at the far end, Turn_R at the near), the body turned by turn_angle() over each clip
## as the clip's planted feet expect (tools/wildlife/mammoth_clips.py).
const PACE_M := 4.0
const PACE_MPS := 0.45
const CLIP_TURN_L := "Turn_L"
const CLIP_TURN_R := "Turn_R"
## A turn clip's mean rate (rad/s: a quarter turn over its 3.58 s): turning on the spot at another rate (its temper
## facing someone) plays it faster or slower.
const TURN_CLIP_RATE := (PI * 0.5) / 3.58
## Its meals (user 2026-09-27: "eating and drinking clips as well", "eating uses trunk to pick up grass and leaves from
## tress and ground", "the drinking animation is they use there trunk to blow water into there mouths", "mammoths also
## eats the herbs, so players are competing for the same resources"): at an end of its beat, GRAZE_CHANCE of the time,
## GRAZE_BITES of a meal before it turns, the first that its trunk reaches of:
##   water    under DRINK_REACH (TorchState.under_water): Drink, two squirts blown into the mouth (SQUIRT_S: a spray)
##   forage   a plant people pick (ForageField) at EAT_REACH: Eat, and it eats it (ForageField.deer_eat, APPETITE
##            times a deer's rate: the ripe food first, then the plant; the patch shows it has been fed at)
##   a tree   BROWSE_R ahead, within BROWSE_ANGLE of its facing (VegHarvest): Browse, leaves shed at the tug (TUG_S)
##   grass    Eat
## Calm, every SEEK_EVERY s it looks for forage within SEEK_R (never beyond LEASH_R of where it was built): it turns to
## it on the spot (the turn clips), walks till its trunk reaches, eats, and paces on from there.
const CLIP_EAT := "Eat"
const CLIP_DRINK := "Drink"
const CLIP_BROWSE := "Browse"
const GRAZE_BITES := 2
const DRINK_REACH := Vector3(0.0, -0.2, -5.0)
const EAT_REACH := Vector3(0.0, 0.0, -4.2)
const BROWSE_R := Vector2(3.5, 7.5)
const BROWSE_ANGLE := 0.7
const APPETITE := 8.0
const SEEK_EVERY := 25.0
## Off by more than SEEK_TURN (rad) it turns on the spot to face the food; less, it steers on as it walks (SEEK_STEER
## rad/s).
const SEEK_TURN := 0.6
const SEEK_STEER := 0.25
const SEEK_R := 18.0
const LEASH_R := 30.0
const SQUIRT_S := [56.0 / 24.0, 64.0 / 24.0]
const TUG_S := 22.0 / 24.0
## Seconds of someone on it before it starts to shake, and between the shakes.
@export var shake_after := 3.0
@export var shake_every := 4.5
@export var shake_scale := 1.0
@export var paces := true

signal went_down(leg: String)
signal got_up(leg: String)
signal died

## The attack clips (act()) and their lengths' ends as played.
const ATTACKS := ["TrunkSwing_L", "TrunkSwing_R", "Stomp"]

var player: FrontierPlayer
## The pacing, swaying frame the model hangs from (the ground under its middle).
var body: Node3D
var torso: AnimatableBody3D
var head: AnimatableBody3D
var legs: Array[AnimatableBody3D] = []
## The weak points behind the knees (StaticBody3D on WildAnimal.HIT_LAYER), in LEG_NAMES order.
var weak: Array[StaticBody3D] = []
## The leg it is down on ("" standing), and how far: "kneel" (going down), "down", "rise" (getting up), or "".
var down_leg := ""
var down_phase := ""
var health := MAX_HEALTH
## Dead (a carcass): the side it lies on ("L" / "R"; "" alive), and its butchery (made when it dies).
var dead_side := ""
var butchery: MammothButchery
var _down_t := 0.0
var _struck := false
var _sway_w := 1.0
## The model (the FBX's scene), its skeleton and its clips.
var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var shaking := false
## A big shake is coming (the warning plays).
var warning := false
var _warn_t := 0.0
var _crouch := 0.0               ## the warning's crouch (0..1), eased out as the shake starts (a heave, not a snap)
var t := 0.0
## The pacing: "walk" or "turn"; its line (the middle and the way along it; INF: from where it stands when it next
## paces), the turn under way, and its walking speed now.
var pace_state := "walk"
var _pace_c := Vector3.INF
var _pace_dir := Vector3.ZERO
var _turn_side := 1.0
var _turns_left := 0
var _turn_t := 0.0
var _turn_yaw0 := 0.0
var _walk_mps := 0.0
## How fast it is turning now (rad/s, + to its left), for the turn clips.
var _yaw_prev := INF
var _yaw_rate := 0.0
## The chance it stops to eat at an end of its beat (tests set it), and the meal under way.
var graze_chance := 0.6
var _meal := ""
var _meal_t := 0.0
## Forage it has eaten (handfuls and browse, ForageField.deer_eat), squirts blown, sprays of leaves torn (tests).
var eaten := 0.0
var squirts := 0
var leaf_sheds := 0
var _seek_t := 0.0
var _seek_to := Vector3.INF
## Driven by its temper: off its pacing, its home moving at drive_speed (m/s, + ahead), the head lifted head_aim (rad,
## + up, - down: a charge), display the threat (the head up and shaking); acting the attack clip playing ("" none).
var driven := false
var drive_speed := 0.0
var head_aim := 0.0
var display := false
var acting := ""
## Where it was built (its temper walks it back here).
var spawn: Transform3D
var _home: Transform3D
var _on_t := 0.0
var _wait := 0.0
var _shake_i := 0
var _shake_t := 0.0
var _head_bone := -1
var _head_off := Transform3D()   ## the head box from the head bone (its rest frame, unscaled)
var _leg_bones: Array = []       ## [hip, toe] bone indices a leg
var _knee_bones: Array = []      ## [shin, foot] bone indices a leg
var _leg_caps: Array[CapsuleShape3D] = []
var _torso_bone := -1
var _torso_rest_inv := Transform3D()
var _k := Transform3D()          ## the skeleton's frame in Body's
var _lift: HeadLift
var _clip := ""


## Builds it at `at` (the ground under its middle, facing -Z). (`_fur` and `_stone` were the first stand-in's looks.)
func build(at: Transform3D, _fur: Material = null, _stone: Material = null) -> void:
	_home = at
	spawn = at
	# its blows (a ram, the trunk, a stomp) are blunt force (PlayerWounds.kind_of)
	set_meta(&"damage_kind", "blunt")
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	torso = _part("Torso")
	# a long round body lying along its length: the fur wraps from the flanks over the back and under the belly
	var tc := CapsuleShape3D.new()
	tc.radius = BODY_R
	tc.height = BODY_LEN
	_shape(torso, tc, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, BODY_Z)))
	var hs := SphereShape3D.new()
	hs.radius = HUMP_R
	_shape(torso, hs, Transform3D(Basis(), HUMP_AT))
	GripSurface.tag(torso, "fur")
	head = _part("Head")
	head.set_meta("hit_part", "head")
	head.set_meta("surface", "flesh")
	var hb := BoxShape3D.new()
	hb.size = HEAD_BOX
	_shape(head, hb)
	for i in LEG_BONES.size():
		var leg := _part("Leg%d" % i)
		var cap := CapsuleShape3D.new()
		cap.radius = LEG_R
		cap.height = 2.5
		_shape(leg, cap)
		legs.append(leg)
		_leg_caps.append(cap)
		weak.append(_weak_point(String(LEG_NAMES[i])))
	_build_model()
	_apply(0.0)
	_settle_parts([torso, head] + legs)


## Its moving bodies are made at this node's origin (the world's middle: the fort's) and posed onto the model after;
## their first physics step is that jump, which would fling anything there as a moving body does (a player in the
## middle of the fort, at thousands of m/s, as a chopped-off leg once did). So they touch nothing till they are there.
func _settle_parts(bodies: Array) -> void:
	if not is_inside_tree():
		return
	var keep := []
	for b: CollisionObject3D in bodies:
		keep.append([b, b.collision_layer, b.collision_mask])
		b.collision_layer = 0
		b.collision_mask = 0
	for i in 2:
		await get_tree().physics_frame
	for k: Array in keep:
		var b: CollisionObject3D = k[0]
		if is_instance_valid(b):
			b.collision_layer = int(k[1])
			b.collision_mask = int(k[2])


## A weak point behind a knee: a hit zone (as an animal's) whose hits come to apply_hit() as "knee_<leg>".
func _weak_point(leg: String) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "Weak_" + leg
	sb.collision_layer = WildAnimal.HIT_LAYER
	sb.collision_mask = 0
	sb.set_meta("hit_part", "knee_" + leg)
	sb.set_meta("surface", "flesh")
	sb.top_level = true
	var sp := SphereShape3D.new()
	sp.radius = WEAK_R
	_shape(sb, sp)
	add_child(sb)
	return sb


## The mammoth model under Body (its feet on the ground, facing -Z), its standing clips looping, the head lift after them;
## the torso's, the head's and the legs' bodies and the weak points found on its bones.
func _build_model() -> void:
	var ps := load(MODEL) as PackedScene
	if ps == null:
		push_error("StandInGiant: no mammoth model at %s" % MODEL)
		return
	model = ps.instantiate() as Node3D
	model.name = "Mammoth"
	body.add_child(model)
	model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * MODEL_SCALE), Vector3.ZERO)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(si) as BaseMaterial3D
			if mat != null and mat.resource_name in ["Wool", "Hide_L", "Hide_R"]:
				var w := mat.duplicate() as BaseMaterial3D
				w.albedo_color = WOOL_COLOR
				w.roughness = 1.0
				w.metallic_specular = 0.2
				m.set_surface_override_material(si, w)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	for c in [CLIP_IDLE, CLIP_WALK, CLIP_SHAKE, CLIP_TURN_L, CLIP_TURN_R, CLIP_EAT, CLIP_DRINK, CLIP_BROWSE]:
		if anim.has_animation(c):
			anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
	_lift = HeadLift.new()
	_lift.name = "HeadLift"
	_lift.bone = skeleton.find_bone(NECK_BONE)
	skeleton.add_child(_lift)
	_head_bone = skeleton.find_bone(HEAD_BONE)
	for pair: Array in LEG_BONES:
		_leg_bones.append([skeleton.find_bone(String(pair[0])), skeleton.find_bone(String(pair[1]))])
	for pair: Array in KNEE_BONES:
		_knee_bones.append([skeleton.find_bone(String(pair[0])), skeleton.find_bone(String(pair[1]))])
	_torso_bone = skeleton.find_bone(TORSO_BONE)
	_torso_rest_inv = skeleton.get_bone_global_rest(_torso_bone).affine_inverse()
	# the skeleton in Body's frame; the head box's place on the head bone, from the rest pose
	_k = model.transform * (model.global_transform.affine_inverse() * skeleton.global_transform)
	var hx := _unscaled(_k * skeleton.get_bone_global_rest(_head_bone))
	_head_off = hx.affine_inverse() * Transform3D(Basis(), HEAD_AT)
	_play(CLIP_IDLE, 0.0)


static func _unscaled(x: Transform3D) -> Transform3D:
	return Transform3D(x.basis.orthonormalized(), x.origin)


func _part(nm: String) -> AnimatableBody3D:
	var b := AnimatableBody3D.new()
	b.name = nm
	b.sync_to_physics = true
	add_child(b)
	return b


func _shape(b: CollisionObject3D, s: Shape3D, at := Transform3D()) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.transform = at
	b.add_child(cs)


## How hard it shakes now for a climber (PlayerGrip reads it from the gripped part's ancestors): 0 calm or warning, up
## to 0.35 in a small shake (a jostle), up to 1 in a big one (the legs flung off the fur).
func grip_shake() -> float:
	if not shaking:
		return 0.0
	var s: Dictionary = SHAKES[_shake_i]
	var u := _shake_t / float(s.s)
	var env := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.7, 1.0, u))
	return env * (1.0 if bool(s.big) else 0.35)


## True while the player grips one of its parts or stands on it.
func carrying() -> bool:
	return carries(player)


## True while player `p` grips one of its parts or stands on it.
func carries(p: FrontierPlayer) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	if p.grip and p.grip.state != PlayerGrip.OFF and p.grip.gripped != null and is_ancestor_of(p.grip.gripped):
		return true
	if p.is_on_floor():
		for i in p.get_slide_collision_count():
			var k := p.get_slide_collision(i)
			var c := k.get_collider() as Node
			# standing on it (on top: not brushing a leg at its side)
			if c != null and is_ancestor_of(c) and k.get_normal().y > 0.6:
				return true
	return false


## Which way it faces (flat, the world's).
func heading() -> Vector3:
	var f := -_home.basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


## Where it stands (the ground under its middle).
func where() -> Vector3:
	return _home.origin


## Its temper takes it off its pacing or gives it back (the pacing on from where it stands, the way it faces).
func set_driven(on: bool) -> void:
	if on == driven:
		return
	_pace_c = Vector3.INF
	pace_state = "walk"
	_walk_mps = 0.0
	driven = on
	if not on:
		drive_speed = 0.0
		head_aim = 0.0
		display = false


## A turn clip's turn at `u` (0..1 of the clip) of a turn of `total` radians: at rest at both ends (the same curve the
## clip was made on: mammoth_clips.py turn_angle).
static func turn_angle(u: float, total: float) -> float:
	return total * (u - sin(TAU * u) / TAU)


## Paces its beat: forward along its line; at an end, round on the spot (two quarter-turn clips), and back.
func _pace(dt: float) -> void:
	if _pace_c == Vector3.INF:
		_pace_c = _home.origin            # (its line from here; a meal under way goes on)
		_pace_dir = heading()
	match pace_state:
		"walk":
			# now and then, forage near: off to it
			_seek_t += dt
			if _seek_t >= SEEK_EVERY:
				_seek_t = 0.0
				var f := _find_forage()
				if f != Vector3.INF:
					_seek_to = f
					_meal = ""
					pace_state = "seek"
					_walk_mps = 0.0
					return
			var d := (_home.origin - _pace_c).dot(_pace_dir)
			var along := heading().dot(_pace_dir)
			if (along >= 0.0 and d >= PACE_M) or (along < 0.0 and d <= -PACE_M):
				# a meal first, now and then (a drink with water in reach)
				if _meal == "" and pace_state == "walk" and _begin_meal():
					return
				_meal = ""
				pace_state = "turn"
				_turns_left = 2
				_turn_t = 0.0
				_turn_yaw0 = atan2(-heading().x, -heading().z)
				_turn_side = 1.0 if along >= 0.0 else -1.0
				_walk_mps = 0.0
				_play(CLIP_TURN_L if _turn_side > 0.0 else CLIP_TURN_R, 1.0)
				return
			_walk_mps = move_toward(_walk_mps, PACE_MPS, PACE_MPS * dt)
			_home.origin += heading() * _walk_mps * dt
			_home.origin.y = FrontierTerrain.height_at(_home.origin.x, _home.origin.z)
		"seek":
			var to := _seek_to - _home.origin
			to.y = 0.0
			var ang := heading().signed_angle_to(to.normalized(), Vector3.UP) if to.length() > 0.1 else 0.0
			var yaw := atan2(-heading().x, -heading().z)
			if absf(ang) > SEEK_TURN or (_walk_mps <= 0.0 and absf(ang) > 0.12):
				# round on the spot to face it (the turn clip at its own rate: _apply plays it)
				_walk_mps = 0.0
				_home.basis = Basis(Vector3.UP, yaw + clampf(ang, -TURN_CLIP_RATE * dt, TURN_CLIP_RATE * dt))
			elif to.length() > EAT_REACH.length() + 0.3:
				# walking, it steers on to it
				_home.basis = Basis(Vector3.UP, yaw + clampf(ang, -SEEK_STEER * dt, SEEK_STEER * dt))
				_walk_mps = move_toward(_walk_mps, PACE_MPS, PACE_MPS * dt)
				_home.origin += heading() * _walk_mps * dt
				_home.origin.y = FrontierTerrain.height_at(_home.origin.x, _home.origin.z)
			else:
				_walk_mps = 0.0
				_seek_to = Vector3.INF
				if not _begin_meal(true):
					pace_state = "walk"
				_pace_c = Vector3.INF           # (its beat on from here)
		"graze":
			var ml := anim.get_animation(_meal).length if anim and anim.has_animation(_meal) else 2.2
			var t0 := fposmod(_meal_t, ml)
			_meal_t += dt
			var t1 := fposmod(_meal_t, ml)
			var tip := _trunk_tip()
			match _meal:
				CLIP_EAT:
					var ff := ForageField.find(get_tree())
					if ff:
						eaten += ff.deer_eat(body.global_transform * EAT_REACH, dt * APPETITE)
				CLIP_DRINK:
					for s in SQUIRT_S:
						if _crossed(t0, t1, s):
							squirts += 1
							_burst(tip, Color(0.72, 0.84, 0.95, 0.85), 36, 2.2)
				CLIP_BROWSE:
					if _crossed(t0, t1, TUG_S):
						leaf_sheds += 1
						_burst(tip, Color(0.52, 0.68, 0.24, 1.0), 24, 0.8)
			if _meal_t >= ml * GRAZE_BITES:
				pace_state = "walk"             # (at its end still: the turn comes next; _meal stays set till then)
		"turn":
			var clip := CLIP_TURN_L if _turn_side > 0.0 else CLIP_TURN_R
			var length := anim.get_animation(clip).length if anim and anim.has_animation(clip) else 3.58
			_turn_t += dt
			_home.basis = Basis(Vector3.UP, _turn_yaw0 + turn_angle(minf(_turn_t / length, 1.0), _turn_side * PI * 0.5))
			if _turn_t >= length:
				_turns_left -= 1
				_turn_yaw0 += _turn_side * PI * 0.5
				_turn_t -= length
				if _turns_left <= 0:
					pace_state = "walk"
					# square to its line again
					_home.basis = Basis.looking_at(-_pace_dir if heading().dot(_pace_dir) < 0.0 else _pace_dir, Vector3.UP)


## Stops for a meal (GRAZE_CHANCE, or `sure`): what its trunk reaches: water (Drink), forage or grass (Eat), a tree's
## leaves (Browse). True when it does.
func _begin_meal(sure := false) -> bool:
	if (not sure and randf() >= graze_chance) or anim == null:
		return false
	var ff := ForageField.find(get_tree())
	if TorchState.under_water(get_world_3d(), get_tree(), body.global_transform * DRINK_REACH):
		_meal = CLIP_DRINK
	elif ff and not ff.deer_spots(body.global_transform * EAT_REACH, 3.0, 1).is_empty():
		_meal = CLIP_EAT
	elif _tree_ahead():
		_meal = CLIP_BROWSE
	else:
		_meal = CLIP_EAT
	if not anim.has_animation(_meal):
		_meal = ""
		return false
	pace_state = "graze"
	_meal_t = 0.0
	_walk_mps = 0.0
	_play(_meal, 1.0)
	return true


## Forage within SEEK_R (and LEASH_R of where it was built), the richest: its place, or INF.
func _find_forage() -> Vector3:
	var ff := ForageField.find(get_tree())
	if ff == null:
		return Vector3.INF
	for s: Dictionary in ff.deer_spots(_home.origin, SEEK_R, 6):
		var at: Vector3 = s.pos
		if Vector2(at.x - spawn.origin.x, at.z - spawn.origin.z).length() <= LEASH_R:
			return at
	return Vector3.INF


## A tree whose leaves its trunk reaches: BROWSE_R ahead, within BROWSE_ANGLE of its facing.
func _tree_ahead() -> bool:
	var vh := VegHarvest.find(get_tree())
	if vh == null:
		return false
	for c: Dictionary in vh.near(_home.origin, BROWSE_R.y):
		if String(c.get("type", "")) != "tree":
			continue
		var to: Vector3 = (c.pos as Vector3) - _home.origin
		to.y = 0.0
		if to.length() >= BROWSE_R.x and to.length() <= BROWSE_R.y and heading().angle_to(to.normalized()) <= BROWSE_ANGLE:
			return true
	return false


## The trunk's tip now (its last bone on, a length further).
func _trunk_tip() -> Vector3:
	var bi := skeleton.find_bone("Bone.002") if skeleton else -1
	if bi < 0:
		return body.global_transform * EAT_REACH
	var g := skeleton.global_transform * skeleton.get_bone_global_pose(bi)
	return g.origin + g.basis.y.normalized() * 1.1 * MODEL_SCALE


static func _crossed(t0: float, t1: float, at: float) -> bool:
	return (t0 < at and t1 >= at) or (t1 < t0 and (at > t0 or at <= t1))


## A burst at `at`: water blown into its mouth (droplets), leaves torn from a tree (fluttering down). Sized to be
## seen on a mammoth from a way off; played as GPU particles (Fx._emit: CPU particles draw black quads, Godot 4.7).
func _burst(at: Vector3, col: Color, n: int, speed: float) -> void:
	var water := speed > 1.0
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = 0.9
	p.explosiveness = 0.85
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 70.0 if water else 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -6.0 if water else -0.9, 0.0)
	p.scale_amount_min = 0.1 if water else 0.1
	p.scale_amount_max = 0.18 if water else 0.2
	if not water:
		# leaves shaken loose all through the branches it pulled, not one clump
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.9
		p.lifetime = 2.6
		p.damping_min = 0.3
		p.damping_max = 0.8
		p.hue_variation_min = -0.04
		p.hue_variation_max = 0.04
	var mesh: PrimitiveMesh = SphereMesh.new() if water else QuadMesh.new()
	if mesh is SphereMesh:
		(mesh as SphereMesh).radius = 0.5
		(mesh as SphereMesh).height = 1.0
	else:
		# a leaf's own size (a billboard's particle scale is dropped: at 1 m square they fell as green slabs)
		(mesh as QuadMesh).size = Vector2(0.16, 0.11)
		p.scale_amount_min = 1.0
		p.scale_amount_max = 1.0
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if col.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not water:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES     # (a leaf never edge-on)
	mesh.material = m
	p.mesh = mesh
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(p)
	p.global_position = at
	Fx._emit(p, false)


## Turns its home toward flat direction `dir`, at most `rate` (rad/s) over `dt`. The angle left (rad).
func turn_toward(dir: Vector3, rate: float, dt: float) -> float:
	var want := atan2(-dir.x, -dir.z)
	var now := atan2(-heading().x, -heading().z)
	var d := wrapf(want - now, -PI, PI)
	var step := clampf(d, -rate * dt, rate * dt)
	_home.basis = Basis(Vector3.UP, now + step)
	return absf(d - step)


## Plays attack `clip` (ATTACKS) once. False when it cannot now (down, or already acting).
func act(clip: String) -> bool:
	if down_phase != "" or acting != "" or anim == null or not anim.has_animation(clip):
		return false
	acting = clip
	anim.speed_scale = 1.0
	anim.play(clip, 0.15)
	_clip = clip
	return true


## Seconds into the attack playing (-1: none).
func act_time() -> float:
	return anim.current_animation_position if acting != "" and anim and anim.is_playing() else -1.0


func _physics_process(dt: float) -> void:
	t += dt
	var yaw_now := atan2(-heading().x, -heading().z)
	_yaw_rate = wrapf(yaw_now - _yaw_prev, -PI, PI) / dt if _yaw_prev != INF and dt > 0.0 else 0.0
	_yaw_prev = yaw_now
	# its beat, while nothing else has it (its temper, a buckled leg, a shake)
	if paces and not driven and down_phase == "" and not shaking and not warning and acting == "":
		_pace(dt)
	elif pace_state != "walk":
		pace_state = "walk"
		_pace_c = Vector3.INF
		_walk_mps = 0.0
		_meal = ""
	if driven and absf(drive_speed) > 0.0 and down_phase == "":
		_home.origin += heading() * drive_speed * dt
		_home.origin.y = FrontierTerrain.height_at(_home.origin.x, _home.origin.z)
	if acting != "" and anim and not anim.is_playing():
		acting = ""
	var on := carrying()
	_on_t = _on_t + dt if on else maxf(_on_t - dt * 2.0, 0.0)
	if down_phase != "":
		_step_down(dt)
	elif shaking and dead_side == "":
		_shake_t += dt
		if _shake_t >= float(SHAKES[_shake_i].s):
			shaking = false
			_shake_i = (_shake_i + 1) % SHAKES.size()
			_wait = shake_every
	elif warning:
		_warn_t += dt
		if _warn_t >= WARN_S:
			warning = false
			shaking = true
			_shake_t = 0.0
	elif _on_t > shake_after:
		_wait -= dt
		if _wait <= 0.0:
			if bool(SHAKES[_shake_i].big):
				warning = true
				_warn_t = 0.0
			else:
				shaking = true
				_shake_t = 0.0
	else:
		_wait = minf(_wait, 0.5) if _wait > 0.0 else 0.5
	_apply(dt)


## The pose at time t: pacing, sway, breathing, the shake; the model's clip; the head and the legs on its bones.
func _apply(dt: float) -> void:
	var standing := down_phase == ""
	# the idle sway and breathing (down on a leg, a quarter of it: the feet are planted)
	_sway_w = move_toward(_sway_w, 1.0 if standing else DOWN_SWAY, dt / 0.8)
	var yaw := 0.12 * sin(t * 0.23) * _sway_w
	var roll := 0.035 * sin(t * 1.1) * _sway_w
	var pitch := 0.02 * sin(t * 0.8 + 1.0) * _sway_w
	var lift := 0.06 * sin(t * 1.6) * _sway_w
	var head_up := 0.0
	if warning:
		_crouch = smoothstep(0.0, 0.6, _warn_t / WARN_S)
	elif shaking and _crouch > 0.0:
		_crouch = 1.0 - smoothstep(0.0, 0.6, _shake_t)
	else:
		_crouch = 0.0
	if _crouch > 0.0:
		# crouching to heave: lower, the head up, a tremble
		lift -= 0.28 * _crouch * shake_scale
		pitch -= 0.06 * _crouch * shake_scale
		# (the tremble is the head's alone: on the body it would shake the climber as hard as the shake itself)
		head_up = 0.35 * _crouch + (0.05 * _crouch * sin(TAU * 8.0 * _warn_t) if warning else 0.0)
	if shaking:
		var s: Dictionary = SHAKES[_shake_i]
		var u := _shake_t / float(s.s)
		var env := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.7, 1.0, u)) * shake_scale
		roll += env * float(s.roll) * sin(TAU * float(s.roll_hz) * _shake_t)
		pitch += env * float(s.pitch) * sin(TAU * float(s.pitch_hz) * _shake_t + 0.7)
		lift += env * float(s.buck) * 0.5 * (1.0 - cos(TAU * float(s.buck_hz) * _shake_t))
	var root := _home * Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), Vector3(0.0, lift, 0.0))
	body.global_transform = root
	var tl := Transform3D(Basis(), Vector3(0.0, TORSO_Y, 0.0))
	if skeleton == null:
		torso.global_transform = root * tl
		return
	# the clip: the head shaken while it shakes; its pacing's turn (_pace plays it); the walk at its speed; turning on the
	# spot (its temper facing someone), the turn clip at the rate it turns; else standing (down, the kneel's and the
	# rise's clips play from _step_down)
	var mps := drive_speed if driven else (_walk_mps if paces else 0.0)
	if not standing or acting != "":
		pass
	elif shaking or (display and driven):
		_play(CLIP_SHAKE, 1.0)
	elif pace_state in ["turn", "graze"] and paces and not driven:
		pass
	elif absf(mps) > 0.06:
		_play(CLIP_WALK, mps / (WALK_MPS * MODEL_SCALE))
	elif (driven or pace_state == "seek") and absf(_yaw_rate) > 0.15:
		_play(CLIP_TURN_L if _yaw_rate > 0.0 else CLIP_TURN_R, clampf(absf(_yaw_rate) / TURN_CLIP_RATE, 0.4, 2.5))
	else:
		_play(CLIP_IDLE, 1.0)
	_lift.angle = (head_up + (head_aim if driven else 0.0)) if standing else 0.0
	# down (kneeling, down, rising): the torso on the back's bone (its move from the rest pose, in Body's frame), so it
	# goes down with the body and a climber with it; standing, on Body alone (the clips' own sway stays out of the
	# shakes the grip is tuned to; the kneel starts and the rise ends at the rest pose, so the change does not jump)
	if standing:
		torso.global_transform = root * tl
	else:
		var moved := _k * (skeleton.get_bone_global_pose(_torso_bone) * _torso_rest_inv) * _k.affine_inverse()
		torso.global_transform = root * _unscaled(moved) * tl
	# the head and the legs on their bones, the weak points behind the knees (the clip's pose of the last step)
	var sx := skeleton.global_transform
	head.global_transform = _unscaled(sx * skeleton.get_bone_global_pose(_head_bone)) * _head_off
	var back := root.basis.z.normalized()
	for i in legs.size():
		var hip := sx * skeleton.get_bone_global_pose(int(_leg_bones[i][0])).origin
		var toe := sx * skeleton.get_bone_global_pose(int(_leg_bones[i][1])).origin
		var up := (hip - toe).normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		legs[i].global_transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), (hip + toe) * 0.5)
		var h := maxf(hip.distance_to(toe), LEG_R * 2.0 + 0.1)
		if absf(_leg_caps[i].height - h) > 0.02:
			_leg_caps[i].height = h
		var shin := sx * skeleton.get_bone_global_pose(int(_knee_bones[i][0])).origin
		var foot := sx * skeleton.get_bone_global_pose(int(_knee_bones[i][1])).origin
		weak[i].global_transform = Transform3D(Basis(), shin.lerp(foot, KNEE_AT) + back * WEAK_BACK)


## A hit (Hit.deliver): behind a knee ("knee_<leg>") and standing, it goes down on that leg; anywhere else, the hide
## takes it.
func apply_hit(damage: float, point: Vector3, direction: Vector3, _source: Node = null, part := "body") -> void:
	if dead_side != "" or damage <= 0.0:
		return
	var mult := HIDE_MULT
	if part.begins_with("knee_"):
		mult = KNEE_MULT
	elif part == "head":
		mult = HEAD_MULT
	health -= damage * mult
	var sp := get_tree().current_scene.get_node_or_null(^"Wildlife") as WildlifeSpawner if get_tree().current_scene else null
	if sp:
		sp.blood_splash(point, direction)
	if health <= 0.0:
		die()
		return
	if part.begins_with("knee_"):
		knock_down(part.substr(5))


## Dead: it rolls onto a side and lies there; the weak points and the temper done with; a butchery on the carcass.
func die(side := "") -> void:
	if dead_side != "":
		return
	health = 0.0
	dead_side = side if side in ["L", "R"] else ("L" if randf() < 0.5 else "R")
	down_phase = "dead"
	# one fewer mammoth in the land (WildlifeEcology)
	var scene := get_tree().current_scene if is_inside_tree() else null
	var wl := scene.get_node_or_null("Wildlife") as WildlifeSpawner if scene else null
	if wl:
		wl.land.at(where()).on_death("mammoth")
	down_leg = ""
	shaking = false
	warning = false
	acting = ""
	display = false
	drive_speed = 0.0
	_crouch = 0.0
	for z in weak:
		z.collision_layer = 0
	if anim:
		anim.speed_scale = 1.0
		anim.play("Die_" + dead_side, 0.15)
		_clip = "Die_" + dead_side
	butchery = MammothButchery.new()
	butchery.name = "Butchery"
	butchery.giant = self
	add_child(butchery)
	died.emit()


## A piece of the model: the mesh and the surface of material `nm` (Tusk_L, Hide_R...), or [].
func surface(nm: String) -> Array:
	if model == null:
		return []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(si)
			if mat and mat.resource_name == nm:
				return [m, si]
	return []


## The model's bone `nm` in the world (Vector3.INF when there is none).
func bone_at(nm: String) -> Vector3:
	var bi := skeleton.find_bone(nm) if skeleton else -1
	return skeleton.global_transform * skeleton.get_bone_global_pose(bi).origin if bi >= 0 else Vector3.INF


## A point of the model at rest (skeleton space) where it is now, carried by bone `nm`.
func carried(nm: String, rest_point: Vector3) -> Vector3:
	var bi := skeleton.find_bone(nm)
	return skeleton.global_transform * (skeleton.get_bone_global_pose(bi) * skeleton.get_bone_global_rest(bi).affine_inverse()) * rest_point


## Down on `leg` (LEG_NAMES): the leg buckles (its Kneel clip), the shakes stop. False when it is already down.
func knock_down(leg: String) -> bool:
	if down_phase != "" or not leg in LEG_NAMES or anim == null or not anim.has_animation("Kneel" + leg):
		return false
	down_leg = leg
	down_phase = "kneel"
	_down_t = 0.0
	_struck = false
	acting = ""
	drive_speed = 0.0
	shaking = false
	warning = false
	_crouch = 0.0
	anim.speed_scale = 1.0
	anim.play("Kneel" + leg, 0.12)
	_clip = "Kneel" + leg
	went_down.emit(leg)
	return true


## Down: the kneel plays out and holds its last pose, DOWN_S seconds, then the rise; standing again, the shakes wait
## their while before they start again.
func _step_down(dt: float) -> void:
	_down_t += dt
	match down_phase:
		"dead":
			# the death played out: its pose held (the clips stop; the butchery takes pieces away)
			if anim and anim.active and not anim.is_playing() and _down_t > 0.5:
				anim.active = false
		"kneel":
			if not _struck and _down_t >= KNEE_STRIKE_S:
				_struck = true
				var knee := skeleton.global_transform * skeleton.get_bone_global_pose(
						int(_knee_bones[LEG_NAMES.find(down_leg)][1])).origin
				CameraShake.quake(get_tree(), knee, QUAKE, QUAKE_R, QUAKE_S)
			if not anim.is_playing():
				down_phase = "down"
				_down_t = 0.0
		"down":
			if _down_t >= DOWN_S:
				down_phase = "rise"
				anim.speed_scale = 1.0
				anim.play("Rise" + down_leg, 0.0)
				_clip = "Rise" + down_leg
		"rise":
			if not anim.is_playing():
				var leg := down_leg
				down_phase = ""
				down_leg = ""
				_wait = shake_every
				got_up.emit(leg)


## Plays `clip` at `speed` (blending into it when it changes).
func _play(clip: String, speed: float) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if clip != _clip:
		anim.play(clip, 0.0 if _clip == "" else 0.35)
		_clip = clip
	anim.speed_scale = speed


## Lifts the head after the clips (a turn of the neck bone about its own side axis): the big shake's warning.
class HeadLift extends SkeletonModifier3D:
	var bone := -1
	var angle := 0.0

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or bone < 0 or absf(angle) < 0.001:
			return
		sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, -angle))
