class_name WildAnimal
extends CharacterBody3D
## One wild animal: a stand-in model (WildlifeSpecies) with needs, a place in its group and a state machine (first
## playable wildlife 2026-09-26; the "brains" the same day: routines, memory, herd roles, food chain).
##
## Needs: hunger and fatigue rise while it is up and about (x WildlifeSpawner.time_scale) and fall as it grazes, eats or
## rests. WildPlanner turns the group's needs, the hour and its memory into an activity (WildGroup): the members carry
## it out. The leader goes to the group's `dest`; the others follow it in a loose file and spread round it there.
##   FEED   prey graze in the open; the herd's SENTRY stands head up and keen-eyed while the rest have their heads down
##          (they see less); a fox mouses (a pounce now and then)
##   BED    rest in thick cover (head low, dozing: they see less, hear as well)
##   PATROL wolves and foxes roam their range
##   HUNT   wolves go to a herd, STALK closer, then CHASE the one the pack picked and pull it down (bites, bleeding)
##   EAT    wolves and foxes eat at a carcass (it loses meat); wolves guard it (they turn on a player who comes close)
##   TRACK  wolves short of deer that cross a wounded animal's fresh blood follow the trail at a trot (WildPlanner)
## Senses: sight (a wide field for prey, crouching / keeping still shorten it), footfalls and the horse, gunshots
## (WildlifeSpawner.shot), scent on the shared wind (wind_direction global); prey also watch for wolves. Awareness rises
## to ALERT (0.45: stop and stare; keep still and it may settle) and at 1 prey bolt and the herd goes with them (the
## herd remembers the place: WildGroup.remember); wolves aware of the player stalk and chase him, keep off a lit torch
## (HOLD_OFF), leave after two losses, and never come into the fort. A shot close by startles them; only at night does
## a shot draw them in. Wolves at dusk / night / dawn howl (the pack, WildlifeSpawner.sound); foxes call.
##
## Hits: Hit.deliver() finds apply_hit() from the movement body or the hit zones (torso, vitals, head; HIT_LAYER, seen
## only by projectiles); where the shot goes through the body makes the wound (wound_at: heart, lungs, spine, gut, leg,
## graze, head; WildlifeSpecies.WOUNDS): its damage, its bleeding (clotting or not: a clotted wound heals, HEAL_S) and
## its trail of drops (the look, their size and spacing by how hard it bleeds). Badly bleeding, a deer lies up where
## it stopped (BED_BLEED) till pushed; a leg wound lames it (LAME_SPEED). The dead animal is a carcass with meat (meat_left): the player
## skins and butchers it with a knife (FieldDressing, the interactor's E hook); what is left (the remains) draws ravens,
## foxes and wolves, which eat it down until only bones are left (WildlifeSpawner removes them then).

signal died(animal: WildAnimal)

enum State { IDLE, GRAZE, WANDER, ALERT, FLEE, STALK, CHASE, ATTACK, HOLD_OFF, DEAD, TRAVEL, REST, EAT, SENTRY }

## Layer of the hit zones: projectiles' rays (all layers) see them; bodies (mask 1) do not.
const HIT_LAYER := 1 << 15
## A pack against a player (user 2026-09-27: "wolfs will attack hindlegs and etc but there goal is to either get us weak
## so we have to heal and recoup"): a wolf the player faces (within FACED_DEG of where he looks, near) holds off
## FACED_KEEP m and circles round toward his side; one at his side or back darts in and bites the back of his legs.
## Once he is weak (WEAK_FRAC of his health, or bleeding hard) the pack draws off to SHADOW_R and shadows him, and
## comes on again only when he is whole (RECOVERED_FRAC, the bleeding stopped): he must get to a fire or the fort, or
## heal. Fresh drops of his blood (BLOOD_FRESH_S, within BLOOD_SMELL_R) give a wolf his scent.
## The alpha (WildGroup.alpha): this much larger, its coat this much darker; hurt under ALPHA_HURT of its health, it
## falls and the pack is routed.
const ALPHA_SCALE := 1.12
const ALPHA_DARK := 0.62
const ALPHA_HURT := 0.6
const FACED_DEG := 55.0
const FACED_KEEP := 7.0
const WEAK_FRAC := 0.35
const RECOVERED_FRAC := 0.6
## Fed (hunger under FED: it has just eaten) a wolf hunts no one (user 2026-09-28: "why did it go after the player after
## it just ate"): it comes at the player only at its kill or when he has hurt it (PROVOKED_S).
const FED := 0.2
const PROVOKED_S := 30.0
## Wounds: a wound bleeding less than this (health a second) has stopped; its bleeding stopped, any animal heals
## (user 2026-09-28: "add this universally to all the animals ... the weakest one heals"): whole over HEAL_S fed and at
## rest (x (1 - hunger): a starving one hardly mends; x HEAL_REST resting, grazing or eating). Weak (under WEAK_HEALTH
## of its health, or lamed) a wolf leaves the chase to the pack and follows on; at the kill the pack lets it feed first
## (WEAK_EAT: fed, it mends). Bleeding this hard or more (all its wounds), prey lie up where they stopped instead of
## going on with the herd; lamed (a leg wound still bleeding LAME_BLEED or more) it runs this much slower.
const STOPPED_BLEED := 0.03
const HEAL_S := 900.0
const HEAL_REST := 1.5
const WEAK_HEALTH := 0.6
const WEAK_EAT := 1.6
const BED_BLEED := 0.15
const LAME_BLEED := 0.1
const LAME_SPEED := 0.78
const SHADOW_R := 26.0
const BLOOD_SMELL_R := 30.0
const BLOOD_FRESH_S := 180.0
const GRAVITY := 9.8
## Ticks standing still on the floor before its body rests (no slide over the ground: _stand).
const REST_TICKS := 3
## Far from the player (this far or more), an animal moves without its body (user 2026-09-28, "that sounds smart": a
## herd on the move cost ~0.3 ms a bison a tick in the body's slide): its place goes by its velocity and its height is
## the ground's (FrontierTerrain.height_at), the trunks and rocks still steered round (_probe); nearer, the body slides
## and collides as ever (with him, with each other, with what is built).
const FAR_SIM_D := 60.0
## A prey's charge ("defend" with "charge"): at most this long (s), at this share of its run.
const CHARGE_S := 4.0
const CHARGE_PACE := 0.85
## Winded (a species that "tires", WildlifeSpecies: its fatigue climbs that much faster while it runs): between these
## shares of its fatigue its run falls off to a trot of WINDED_TROT x its walk (user 2026-09-28, the wild horses: run
## down, they can be caught).
const WINDED := Vector2(0.6, 0.95)
const WINDED_TROT := 2.6
## Prey keep this far from the fort's centre (m); wolves do not come closer than FORT_KEEP_OUT.
const FORT_AVOID := 45.0
const FORT_KEEP_OUT := 26.0
const WORLD_LIMIT := 330.0
## The square of the land it lives on (WorldSquares; set from its group's home): it keeps within it.
var home_sq := Vector2i.ZERO
## Needs per game second (x WildlifeSpawner.time_scale): hunger fills in ~6 min for prey, ~8 min for wolves.
const HUNGER_RATE := {"prey": 1.0 / 360.0, "predator": 1.0 / 480.0}
## PEOPLE other than the player within this are looked for (m: past its sight, hearing and scent).
const PERSON_SENSE_M := 120.0
## How high it steps up (m; the species' `step`) and the step assist that lifts it over a low log or stump.
var step_m := 0.5
var _step: BodyStep
const FATIGUE_RATE := 1.0 / 600.0
const GRAZE_FEED := 1.0 / 90.0
const REST_RATE := 1.0 / 120.0
## Meat a wolf / fox / raven tears off a carcass per second (1 = a whole deer).
## After a butchering, the remains: the gut pile and the bones with what the knife left (of a whole carcass's meat).
const REMAINS_MEAT := 0.3

var species := "deer"
var data: Dictionary
var group: WildGroup
var spawner: WildlifeSpawner
var state := State.IDLE
var health := 100.0
## How sure the animal is that there is danger / quarry (0..1.3; ALERT from 0.45, flight / hunt from 1).
var awareness := 0.0
var threat_pos := Vector3.ZERO
## Processing on (WildlifeSpawner turns far animals off).
var active := true
## Another machine's animal as this one shows it (NetWildlife: a joiner's world): placed and played from the host's,
## its own brain off; what hits it goes to the host's.
var mirrored := false
## Seconds between animation updates for its distance (WildlifeSpawner._lod: 0 every frame near the player, longer far
## off); off-screen it updates every OFFSCREEN_ANIM_S. The pose is the same when it updates: the clip is advanced by all
## the time since (user 2026-10-02: the animals' animation was ~29 ms of a 35 ms frame).
var anim_step := 0.0
var interact_reach := 2.4
var hunger := 0.3
var fatigue := 0.2
## Field dressing: 0 whole, 1 skinned, 2 butchered; progress of the current step 0..1 (kept when the work stops).
var dress_step := 0
var dress_progress := 0.0
## The carcass's meat (1 a whole animal); scavengers and the knife take it.
var meat_left := 1.0
## Who killed it ("player", "wolf"; bled out, whoever wounded it; "bleed" when no one is known).
var killed_by := ""
## Who wounded it last ("player", "wolf"; "" not known): the player's wounded and dead are wolves' only when the land is
## short of deer (WildPlanner.TRACK_HUNGER).
var hurt_by := ""
## Its build against its species' model (WildlifeSpecies "sizes": a cow's or a bull's): the body, the hit zones and the
## reach are scaled by it (set_size).
var size := 1.0

var rng := RandomNumberGenerator.new()
var _t := 0.0
var _len := 3.0
var _target := Vector3.ZERO
var _yaw := 0.0
var _speed := 0.0
## The open wounds: [{kind, rate (health a second), clot, look}].
var _wounds: Array[Dictionary] = []
## The last wound it took (WildlifeSpecies.WOUNDS), for the tests and tools.
var last_wound := ""
var _hurt_at := -1e9
var _drop_dist := 0.0
var _last_pos := Vector3.ZERO
var _think := 0.0
var _los_t := 0.0
var _los_ok := false
var _avoid_t := 0.0
var _avoid_yaw := 0.0
var _stuck_t := 0.0
var _bit := false
var _bite_cd := 0.0
var _flee_jitter := 0.0
var _flee_run := 0.0
var _call_t := 0.0
var _pounce_t := 0.0
var _visual: Node3D
var _model: Node3D
var _ap: AnimationPlayer
var _skel: Skeleton3D
var _anim := ""
var _anim_acc := 0.0
var _zones: Array[StaticBody3D] = []
var _zone_bones: Array[int] = []
var _pitch := 0.0
var _base_scale := 1.0
## Where it stood still after its last slide, and how many ticks it has stood so (_stand: the body at rest).
var _rest_pos := Vector3.INF
var _rest_ticks := 0
## Moving without its body just now (FAR_SIM_D or more from the player: _glide).
var _far := false


func setup(p_species: String, p_spawner: WildlifeSpawner, p_group: WildGroup, seed_: int) -> void:
	species = p_species
	spawner = p_spawner
	group = p_group
	data = WildlifeSpecies.get_data(species)
	home_sq = WorldSquares.square_at(p_group.home) if p_group else Vector2i.ZERO
	rng.seed = seed_
	health = float(data.health)
	_flee_jitter = rng.randf_range(-0.5, 0.5)
	hunger = rng.randf_range(0.1, 0.5)
	fatigue = rng.randf_range(0.0, 0.4)
	_call_t = rng.randf_range(40.0, 160.0)
	set_size(_pick_size())


## A build from the species' "sizes" ([[share, smallest, largest], ...]: a bull's, a cow's), 1 without.
func _pick_size() -> float:
	var sizes: Array = data.get("sizes", [])
	if sizes.is_empty():
		return 1.0
	var r := rng.randf()
	for e: Array in sizes:
		r -= float(e[0])
		if r <= 0.0:
			return rng.randf_range(float(e[1]), float(e[2]))
	var last: Array = sizes[sizes.size() - 1]
	return rng.randf_range(float(last[1]), float(last[2]))


## Its build `s` (before it is in the tree: a save's animal is given its own): its own copy of the species' data with
## the model's scale, the body (collision and hit capsule), the vitals' and the head's spheres, its reach, its defence's
## reach and the herd's spacing scaled.
func set_size(s: float) -> void:
	size = s
	data = WildlifeSpecies.get_data(species)
	if is_equal_approx(s, 1.0):
		return
	data = data.duplicate(true)
	data.scale = float(data.scale) * s
	var body: Array = data.body
	for i in body.size():
		body[i] = float(body[i]) * s
	(data.vitals as Array)[0] = float((data.vitals as Array)[0]) * s
	(data.head as Array)[0] = float((data.head as Array)[0]) * s
	for k in ["reach", "spacing"]:
		if data.has(k):
			data[k] = float(data[k]) * s
	if data.has("defend") and (data.defend as Dictionary).has("reach"):
		data.defend.reach = float(data.defend.reach) * s


func _ready() -> void:
	if data.is_empty():
		data = WildlifeSpecies.get_data(species)
		health = float(data.health)
	add_to_group(&"wildlife")
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(55.0)
	collision_layer = 1
	collision_mask = 1
	var body: Array = data.body
	# STEP: up on to a log or a stump in its way and over (the species' `step`; the player's step assist, BodyStep)
	step_m = float(data.get("step", 0.5))
	_step = BodyStep.new(self, step_m, float(body[0]))
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(body[0])
	cap.height = maxf(float(body[2]), cap.radius * 2.0 + 0.01)
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_model = WildlifeSpecies.model(species).instantiate() as Node3D
	_visual.add_child(_model)
	AnimalHair.apply(_model)
	_visual.rotation.y = PI            # the models face +Z; the animal's forward is -Z
	_base_scale = float(data.scale)
	_visual.scale = Vector3.ONE * _base_scale
	_visual.position.y = -0.04
	_ap = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL     # (stepped in _process)
	_skel = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_yaw = rotation.y
	_last_pos = global_position
	_build_zones()
	_enter(State.IDLE, rng.randf_range(2.0, 6.0))


func is_prey() -> bool:
	return String(data.kind) == "prey"


func is_dead() -> bool:
	return state == State.DEAD


func now() -> float:
	return spawner.now if spawner else 0.0


# --- Hit zones -----------------------------------------------------------------------------------

func _build_zones() -> void:
	var body: Array = data.body
	var torso := _zone("body", 1.0, _capsule(float(body[0]), float(body[1])), -1)
	torso.set_meta("capsule_up", float(body[2]) * 0.72)
	torso.set_meta("capsule_fwd", float(body[3]) if body.size() > 3 else 0.0)
	_fit_torso(torso)
	var vit: Array = data.vitals
	_zone("vitals", WildlifeSpecies.VITALS_MULT, _sphere(float(vit[0])), _skel.find_bone(String(vit[1])))
	var hd: Array = data.head
	_zone("head", WildlifeSpecies.HEAD_MULT, _sphere(float(hd[0])), _skel.find_bone(String(hd[1])))


func _zone(part: String, mult: float, shape: Shape3D, bone: int) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "Hit_" + part
	sb.collision_layer = HIT_LAYER
	sb.collision_mask = 0
	sb.set_meta("hit_part", part)
	sb.set_meta("damage_mult", mult)
	# (Sfx.surface_of: flesh sounds, and thrown weapons stick in it: ThrownProjectile.stick_surfaces)
	sb.set_meta("surface", "flesh")
	sb.top_level = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	sb.add_child(cs)
	add_child(sb)
	_zones.append(sb)
	_zone_bones.append(bone)
	return sb


static func _sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


## The trunk's capsule fitted round the animal's own body (BodyModel: the barrel and the chest as its skin has them, in the
## rest pose), so the round is caught wherever the body is and what aims by the capsule (a hunter at the heart, WildlifeSpecies.HEART
## and LUNGS) meets the organs where they are (the user, 2026-10-03: hits worked out in the fitted body; data.body's capsule sat a
## hand under a doe's back). data.body's numbers stay when the rig is not known.
func _fit_torso(torso: StaticBody3D) -> void:
	var m := BodyModel.of(_skel) if _skel != null else null
	if m == null or m.human:
		return
	var to_me := global_transform.affine_inverse() * _skel.global_transform
	var mid := 0.0
	var tops: Array[float] = []
	var bottoms: Array[float] = []
	var back := INF
	var front := -INF
	for s: Dictionary in m.shapes:
		if String(s.kind) != "flesh" or not (String(s.name) == "Barrel" or String(s.name) == "Chest"):
			continue
		var w := to_me * _skel.get_bone_global_rest(int(s.bone)) * (s.xf as Transform3D)
		var sz := s.s as Vector3
		var y0 := (w * Vector3(0.0, 0.0, -sz.z)).y
		var y1 := (w * Vector3(0.0, 0.0, sz.z)).y
		tops.append(maxf(y0, y1))
		bottoms.append(minf(y0, y1))
		mid += (y0 + y1) * 0.5
		for k: float in [-1.0, 1.0]:
			var a := w * Vector3(0.0, sz.y * k, 0.0)
			back = minf(back, -a.z)
			front = maxf(front, -a.z)
	if tops.size() < 3:
		return
	# (its axis through the trunk's middle, the slabs' mean; wide enough to take in the deepest of them: the withers, the brisket)
	mid /= float(tops.size())
	var r := 0.05
	for i in tops.size():
		r = maxf(r, maxf(tops[i] - mid, mid - bottoms[i]))
	var length := maxf(front - back, r * 2.0 + 0.01)
	var cap := (torso.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	cap.radius = r
	cap.height = length
	torso.set_meta("capsule_up", mid)
	torso.set_meta("capsule_fwd", (front + back) * 0.5)


static func _capsule(r: float, length: float) -> CapsuleShape3D:
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = maxf(length, r * 2.0 + 0.01)
	return c


func _update_zones() -> void:
	for i in _zones.size():
		var sb := _zones[i]
		var bone := _zone_bones[i]
		if bone < 0:
			var up: float = sb.get_meta("capsule_up", 0.6)
			var b := global_basis * Basis(Vector3.RIGHT, PI * 0.5)
			# (its middle along the body: the trunk's, forward (+) of the animal's origin: data.body[3])
			var fwd := -global_basis.z * float(sb.get_meta("capsule_fwd", 0.0))
			sb.global_transform = Transform3D(b, global_position + Vector3.UP * up + fwd)
		else:
			var p := _skel.global_transform * _skel.get_bone_global_pose(bone).origin
			sb.global_transform = Transform3D(Basis.IDENTITY, p)


## The bones a weapon stuck in the body rides on: the trunk, neck and head (the stand-in models' shared chain). A
## leg or tail bone swings with the stride: a tomahawk in the flank, carried by the thigh's bone, hung under the belly.
const STUCK_BONES := ["Body", "Back", "Torso", "Torso2", "Torso3", "Neck1", "Neck2", "Neck3", "Head"]

## The ragdoll's bodies on the stand-in models' shared rig (BoneRagdoll rows: bone, to, radius as a part of length, share
## of the mass, swing, twist, jointed to): the barrel in two, the neck, the head, each leg in two.
const RAG_ROWS := [
	["Back", "Torso2", 0.40, 0.26, 0.0, 0.0, ""],
	["Torso2", "Neck1", 0.36, 0.28, 35.0, 20.0, "Back"],
	["Neck1", "Head", 0.26, 0.07, 45.0, 30.0, "Torso2"],
	["Head", "", 0.30, 0.06, 50.0, 35.0, "Neck1"],
	["FrontUpperLeg.L", "FrontLowerLeg.L", 0.13, 0.035, 70.0, 20.0, "Torso2"],
	["FrontLowerLeg.L", "", 0.10, 0.02, 70.0, 10.0, "FrontUpperLeg.L"],
	["FrontUpperLeg.R", "FrontLowerLeg.R", 0.13, 0.035, 70.0, 20.0, "Torso2"],
	["FrontLowerLeg.R", "", 0.10, 0.02, 70.0, 10.0, "FrontUpperLeg.R"],
	["BackUpperLeg.L", "BackLowerLeg.L", 0.13, 0.045, 70.0, 20.0, "Back"],
	["BackLowerLeg.L", "", 0.10, 0.02, 70.0, 10.0, "BackUpperLeg.L"],
	["BackUpperLeg.R", "BackLowerLeg.R", 0.13, 0.045, 70.0, 20.0, "Back"],
	["BackLowerLeg.R", "", 0.10, 0.02, 70.0, 10.0, "BackUpperLeg.R"],
]
## Its push from a blow that kills it (m/s from the damage: a ball is hard, an arrow is light), and the most.
const DEATH_PUSH := Vector2(0.04, 5.0)
## The carcass lying on the ground (BoneRagdoll; null: a clip's pose, or a ragdoll frozen where it lay: `_rag.frozen`).
var _rag: BoneRagdoll
var _death_v := Vector3.ZERO
var _report: Array[String] = []              ## what the last wound went through (Anatomy), for the hunter's report
var _death_push := Vector3.ZERO
var _death_at := Vector3.ZERO


## The node that carries what sticks in the animal at `point` (a thrown weapon, an arrow; user 2026-09-27: "thrown
## weapons and animals ... lets do this"): a BoneAttachment3D on the trunk, neck or head bone nearest to the point
## (STUCK_BONES; any bone on a model without them), so the weapon runs, falls and is hauled with the body (the hit
## zones only follow their bone's position while the animal is alive, and stop when it dies). Made once per bone;
## freed with the animal (a thrown weapon then drops to the ground, ThrownProjectile._exit_tree).
func stuck_anchor(point: Vector3) -> Node3D:
	if _skel == null or not is_instance_valid(_skel):
		return self
	var cands: Array[int] = []
	for nm in STUCK_BONES:
		var i := _skel.find_bone(nm)
		if i >= 0:
			cands.append(i)
	if cands.is_empty():
		for i in _skel.get_bone_count():
			cands.append(i)
	var best := -1
	var bd := INF
	for b in cands:
		var d := (_skel.global_transform * _skel.get_bone_global_pose(b).origin).distance_squared_to(point)
		if d < bd:
			bd = d
			best = b
	if best < 0:
		return self
	var nm := "Stuck_%d" % best
	var ba := _skel.get_node_or_null(nm) as BoneAttachment3D
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = nm
		_skel.add_child(ba)
		ba.bone_idx = best
	# (placed now: the attachment follows its bone from the skeleton's next update, and the weapon is parented
	# to it keeping where it is)
	ba.global_transform = _skel.global_transform * _skel.get_bone_global_pose(best)
	return ba


func _zones_off() -> void:
	for sb in _zones:
		sb.collision_layer = 0


# --- Frame ---------------------------------------------------------------------------------------

func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	# asleep, its hit zones stay where it lies (they follow it only while it is awake: one put to sleep before its first
	# tick had them at the world's origin, the fort's middle, where a shot or a load on a rope ran into them)
	if not on and state != State.DEAD and is_inside_tree():
		_update_zones()
	if _ap and _rag == null:
		if on:
			_ap.play()
		else:
			_ap.pause()


## Off-screen, the animation updates this often (s).
const OFFSCREEN_ANIM_S := 0.25


func _process(delta: float) -> void:
	_step_anim(delta)


## The clip advanced every anim_step (every frame at 0), every OFFSCREEN_ANIM_S out of the camera's view.
func _step_anim(delta: float) -> void:
	if _ap == null or not _ap.is_playing():
		_anim_acc = 0.0
		return
	_anim_acc += delta
	var step := anim_step
	var cam := get_viewport().get_camera_3d()
	if cam and not cam.is_position_in_frustum(global_position + Vector3.UP):
		step = maxf(step, OFFSCREEN_ANIM_S)
	if _anim_acc >= step:
		_ap.advance(_anim_acc)
		_anim_acc = 0.0


func _physics_process(dt: float) -> void:
	if mirrored:
		if state != State.DEAD:
			_update_zones()
		return
	if not active or state == State.DEAD:
		return
	_t += dt
	_bite_cd -= dt
	_think -= dt
	if _think <= 0.0:
		_think = 0.2
		_perceive(0.2)
	_needs(dt)
	_bleed_tick(dt)
	if state == State.DEAD:
		return
	_calls(dt)
	if is_prey():
		_prey(dt)
	else:
		_predator(dt)
	_ground_pitch(dt)
	_update_zones()


func _needs(dt: float) -> void:
	var k := (spawner.time_scale if spawner else 1.0) * dt
	var resting := state in [State.REST, State.EAT]
	hunger = clampf(hunger + float(HUNGER_RATE["prey" if is_prey() else "predator"]) * k, 0.0, 1.0)
	if state == State.GRAZE:
		hunger = maxf(hunger - GRAZE_FEED * k, 0.0)
		# a deer grazing on a patch of its food eats it (ForageField: the ripe food first, and it leaves its sign)
		if data.get("forage", false) and spawner and spawner.forage:
			spawner.forage.deer_eat(global_position, k)
	if state == State.REST:
		fatigue = maxf(fatigue - REST_RATE * k, 0.0)
	elif not resting:
		var run := 3.0 * float(data.get("tires", 1.0))
		fatigue = minf(fatigue + FATIGUE_RATE * k * (run if state in [State.FLEE, State.CHASE] else 1.0), 1.0)


## A species' own call (its "call": the fox's; the pack's howl is WildlifeSpawner's, from WildPlanner).
func _calls(dt: float) -> void:
	if not data.has("call") or spawner == null:
		return
	_call_t -= dt
	if _call_t <= 0.0:
		_call_t = rng.randf_range(90.0, 240.0)
		if spawner.sun_elevation() < 25.0 and state != State.FLEE:
			spawner.sound(StringName(data.call), global_position + Vector3.UP * 0.4)


# --- Senses --------------------------------------------------------------------------------------

func _player() -> FrontierPlayer:
	return spawner.nearest_player(global_position) if spawner else null      # (in a session: whoever is nearest)


## How well this animal sees just now (the sentry keen, grazing / dozing heads down).
func _sight_mult() -> float:
	match state:
		State.SENTRY:
			return 1.5
		State.GRAZE, State.EAT:
			return 0.6
		State.REST:
			return 0.5
	return 1.0


func _perceive(dt: float) -> void:
	var nerves := group.nerves(now()) if group else 1.0
	var gain := 0.0
	var p := _player()
	if p != null and not p.is_dead:
		gain += _sense_player(p, dt)
	if is_prey() and spawner:
		gain += _sense_wolves(dt)
		# PEOPLE: the household's and the camp's bodies as the player (a hunter out after it: her hunt notices her, HuntRun)
		for n: Node3D in spawner.people_near(global_position, PERSON_SENSE_M, p):
			var hsc: Variant = n.get(&"sc")
			if hsc is SpouseCore and (hsc as SpouseCore).task == HuntJob.JOB:
				continue
			gain += _sense_body(n, dt)
	if gain > 0.0:
		awareness = minf(awareness + gain * dt * nerves, 1.3)
	else:
		awareness = maxf(awareness - dt * 0.15, 0.0)


func _sense_player(p: FrontierPlayer, dt: float) -> float:
	return _sense_body(p, dt)


## How much `p` (the player, or anyone of the PEOPLE: their velocity, is_crouching, riding, kneeling as the player has
## them, where they have them) raises its awareness this step: seen, heard, scented; the player's fresh blood too.
func _sense_body(p: Node3D, dt: float) -> float:
	var pp := p.global_position
	var to_p := pp - global_position
	to_p.y = 0.0
	var d := to_p.length()
	var v: Variant = p.get(&"velocity")
	var pv := Vector2((v as Vector3).x, (v as Vector3).z).length() if v is Vector3 else 0.0
	var rd: Variant = p.get(&"riding")
	var riding := rd is Node
	if riding and "velocity" in rd:
		pv = Vector2(rd.velocity.x, rd.velocity.z).length()
	var crouching: bool = p.get(&"is_crouching") == true
	var kneeling := p.get(&"kneeling") is Node
	var gain := 0.0
	var sight := float(data.sight) * _sight_mult() * (0.55 if crouching else 1.0) * (0.65 if pv < 0.3 else 1.0) \
			* (1.4 if riding else 1.0) * (0.6 if kneeling else 1.0)
	if d < sight:
		var fwd := -global_basis.z
		var ang := absf(rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to_p.x, to_p.z))))
		if ang < float(data.fov) * 0.5:
			var seen := false
			if p == _player():
				_los_t -= dt
				if _los_t <= 0.0:
					_los_t = 0.4
					_los_ok = _line_of_sight(pp, p)
				seen = _los_ok
			else:
				seen = _line_of_sight(pp, p)   # (another of the PEOPLE: its own look, not the player's kept one)
			if seen:
				gain += (1.0 - d / sight) * (1.2 + 0.35 * minf(pv, 6.0)) * 0.6
	var noise := 0.0
	if riding and pv > 1.0:
		noise = 35.0
	elif pv > 5.0:
		noise = 24.0
	elif pv > 2.2:
		noise = 12.0
	elif pv > 0.3:
		noise = 3.5 if crouching else 7.0
	noise *= float(data.hearing)
	if d < noise:
		gain += (1.0 - d / noise) * 1.5
	if d < float(data.scent) and d > 0.01 and spawner:
		var w := spawner.wind
		if w.length_squared() > 1e-4:
			var k := Vector2(-to_p.x, -to_p.z).normalized().dot(w.normalized())
			if k > 0.8:
				gain += (1.0 - d / float(data.scent)) * (k - 0.8) * 5.0 * (0.5 + spawner.wind_strength)
	# his blood on the ground, fresh: the scent of him (the wolves)
	if p == _player() and data.get("blood_scent", false) and spawner:
		var b := spawner.fresh_player_blood(global_position, BLOOD_SMELL_R, BLOOD_FRESH_S)
		if not b.is_empty():
			gain += 0.7 * (1.0 - global_position.distance_to(b.pos as Vector3) / BLOOD_SMELL_R)
	if gain > 0.0:
		threat_pos = pp
	return gain


## Prey watch for wolves: seen within their sight (a hunting or running wolf is plain), or scented down the wind.
func _sense_wolves(dt: float) -> float:
	var best := 0.0
	for w: WildAnimal in spawner.wolves_now():
		var to := w.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 95.0:
			continue
		var moving := w.state in [State.CHASE, State.TRAVEL, State.STALK, State.ATTACK]
		var sight := float(data.sight) * _sight_mult() * (1.3 if w.state == State.CHASE else (0.6 if w.state == State.STALK else 1.0))
		var g := 0.0
		var fwd := -global_basis.z
		if d < sight and absf(rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))) < float(data.fov) * 0.5:
			g += (1.0 - d / sight) * (1.6 if moving else 0.8)
		if d < 18.0:
			g += (1.0 - d / 18.0) * 1.5          # heard close by
		if spawner.wind.length_squared() > 1e-4 and d > 0.01:
			var k := Vector2(-to.x, -to.z).normalized().dot(spawner.wind.normalized())
			if k > 0.8:
				g += (1.0 - d / 95.0) * (k - 0.8) * 5.0
		if g > best:
			best = g
			threat_pos = w.global_position
	return best


func _line_of_sight(target: Vector3, who: Node = null) -> bool:
	var eye := global_position + Vector3.UP * (float(data.body[2]) + 0.25)
	var q := PhysicsRayQueryParameters3D.create(eye, target + Vector3.UP * 1.3, 1)
	q.exclude = _exclude()
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == (who if who != null else _player())


func _exclude() -> Array[RID]:
	var ex: Array[RID] = [get_rid()]
	for sb in _zones:
		ex.append(sb.get_rid())
	return ex


## A gunshot or another loud noise at `pos` (WildlifeSpawner.shot): prey within earshot bolt and remember the place;
## wolves are startled when it is close, leave by day, and only at night come to it.
func hear(pos: Vector3, radius: float) -> void:
	if state == State.DEAD:
		return
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	threat_pos = pos
	if group:
		group.remember(pos, 0.7 if d > 60.0 else 1.0, now())
	if is_prey():
		awareness = 1.3
		if group:
			group.raise_alarm(pos, now())
	else:
		if d < 40.0 and state in [State.CHASE, State.STALK, State.ATTACK]:
			_enter(State.HOLD_OFF, rng.randf_range(3.0, 5.0))
		elif spawner and spawner.boldness() < 0.6 and d < 150.0:
			_start_flee(pos)
		elif spawner and spawner.is_night() and d < 180.0:
			awareness = 1.0
		else:
			awareness = maxf(awareness, 0.3)


# --- Prey ----------------------------------------------------------------------------------------

func _prey(dt: float) -> void:
	var herd_alarm := group != null and group.alarmed(now()) and group.alarm_pos.distance_to(global_position) < 90.0
	var danger := awareness >= 1.0 or herd_alarm
	match state:
		State.FLEE:
			_flee_tick(dt)
		State.CHASE:
			_charge_tick(dt)
		State.ALERT:
			_face(threat_pos, dt)
			_stand(dt)
			_play(String(data.clips.alert))
			if danger:
				_start_flee(threat_pos)
			elif awareness < 0.2 and _t > 2.5:
				_enter(State.IDLE, 1.0)
		State.ATTACK:
			if data.get("eats", "") == "mice":
				_mousing(dt)                     # the pounce on a mouse, not an attack
			else:
				_attack_tick(dt, float((data.get("defend", {}) as Dictionary).get("damage", 20.0)), _player())
		_:
			if danger:
				_start_flee(group.alarm_pos if herd_alarm and awareness < 1.0 else threat_pos)
			elif awareness >= 0.45 and state != State.SENTRY:
				_enter(State.ALERT, 4.0)
			elif bleed_rate() >= BED_BLEED:
				_lie_up(dt)
			else:
				_routine(dt)


## The flight: away from the danger (the nearest chasing wolf when there is one), tiring after ~12 s.
func _flee_tick(dt: float) -> void:
	var away := global_position - threat_pos
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = -global_basis.z
	var dir := away.normalized().rotated(Vector3.UP, _flee_jitter)
	if _cornered_attack():
		return
	_flee_run += dt
	var speed := float(data.run) * (0.82 if _flee_run > 12.0 else 1.0) * (0.75 if health < float(data.health) * 0.5 else 1.0) \
			* (LAME_SPEED if lame() else 1.0)
	speed = lerpf(speed, minf(speed, float(data.walk) * WINDED_TROT), winded())
	_move(_keep_off_fort(dir), speed, dt, true)
	_play(String(data.clips.run), 0.2, clampf(_speed / float(data.run_ref), 0.6, 2.4))
	if _t > _len and global_position.distance_to(threat_pos) > 80.0:
		awareness = 0.4
		_flee_run = 0.0
		if group:
			if group.is_leader(self) or group.leader() == null:
				group.home = global_position
				group.dest_set = false          # new feeding / bedding places, away from here
		_enter(State.IDLE, 2.0)


## Badly wounded: it lies up where it stopped, head low (the herd goes on without it), till something pushes it.
func _lie_up(dt: float) -> void:
	if state != State.REST:
		_enter(State.REST, 60.0)
	_stand(dt)
	_play(String(data.clips.low), 0.5, 0.45)


## Prey that turn on the player (the species' "defend"): hurt (under `hurt` of its health) with him within `reach` it
## strikes instead of running (a wounded buck butts); with `charge` it runs at him from that far (a hurt bison), and
## crowded (him within `crowd`, hurt or not) it charges too.
func _cornered_attack() -> bool:
	var df: Dictionary = data.get("defend", {})
	var p := _player()
	if df.is_empty() or p == null or p.is_dead or _bite_cd > 0.0:
		return false
	var d := global_position.distance_to(p.global_position)
	var hurt := health <= float(data.health) * float(df.get("hurt", 0.6))
	var crowded := d < float(df.get("crowd", 0.0))
	if not hurt and not crowded:
		return false
	if d < float(df.get("reach", 2.4)):
		_enter(State.ATTACK, 0.9)
		_bit = false
		return true
	if d < float(df.get("charge", 0.0)) and _line_of_sight(p.global_position):
		_enter(State.CHASE, CHARGE_S)
		return true
	return false


## The charge (a prey's CHASE; "defend" with "charge"): flat out at the player, head down, and a butt when it reaches
## him (ATTACK); given up after CHARGE_S or when he is well away, it runs on (FLEE).
func _charge_tick(dt: float) -> void:
	var p := _player()
	var df: Dictionary = data.get("defend", {})
	if p == null or p.is_dead:
		_enter(State.FLEE, 6.0)
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d < float(df.get("reach", 2.4)):
		_enter(State.ATTACK, 0.9)
		_bit = false
		return
	if _t > _len or d > float(df.get("charge", 10.0)) * 1.8:
		threat_pos = p.global_position
		_enter(State.FLEE, 6.0)
		return
	threat_pos = p.global_position
	var pace := float(data.run) * CHARGE_PACE * (LAME_SPEED if lame() else 1.0)
	_move(to, lerpf(pace, minf(pace, float(data.walk) * WINDED_TROT), winded()), dt, true)
	_play(String(data.clips.run), 0.15, clampf(_speed / float(data.run_ref), 0.6, 2.4))


func _start_flee(from: Vector3) -> void:
	threat_pos = from
	awareness = maxf(awareness, 1.0)
	if group:
		group.raise_alarm(from, now())
		group.remember(from, 1.0, now())
	if state != State.FLEE:
		_flee_run = 0.0
		_enter(State.FLEE, rng.randf_range(6.0, 10.0))
		if data.has("call") and spawner and rng.randf() < float(data.get("flee_call", 0.0)):
			spawner.sound(StringName(data.call), global_position + Vector3.UP * 0.4)


## The group's activity, as this member's part of it: the leader goes to the destination, the others follow it; there
## they graze / stand sentry / rest / eat. Without a plan yet: idle and graze where they are.
func _routine(dt: float) -> void:
	var act := group.activity if group else WildGroup.Activity.FEED
	var spot := _my_spot()
	var to := spot - global_position
	to.y = 0.0
	var far := to.length()
	var arrive := 3.0 if group and group.is_leader(self) else 5.0
	if group and group.dest_set and far > arrive + 6.0 and state != State.TRAVEL:
		_enter(State.TRAVEL, 90.0)
	match state:
		State.TRAVEL:
			if far < arrive or _t > _len:
				_enter(State.IDLE, rng.randf_range(1.0, 3.0))
				return
			var lead := group.leader() if group else null
			# (on a blood trail: a trot, nose down)
			var pace := float(data.walk) * (1.6 if act == WildGroup.Activity.HUNT else (1.8 if act == WildGroup.Activity.TRACK else 1.0))
			if lead and lead != self and lead.global_position.distance_to(global_position) > 18.0:
				pace *= 1.6                     # catching up with the leader
			_move(to, pace, dt, false)
			_play(String(data.clips.walk), 0.3, clampf(_speed / float(data.walk_ref), 0.5, 2.6))
		State.IDLE, State.GRAZE, State.WANDER, State.REST, State.SENTRY, State.EAT:
			_at_spot(dt, act, to, far)
		_:
			_enter(State.IDLE, 2.0)


## Where this member should be: the destination for the leader, a place round it for the others.
func _my_spot() -> Vector3:
	if group == null or not group.dest_set:
		return global_position
	if group.is_leader(self):
		return group.dest
	var slot := group.slot_of(self)
	if data.has("spacing"):
		# a big herd: a spiral round the leader (the golden angle), each member its own room
		var ga := float(slot) * 2.39996 + 0.7
		return group.dest + Vector3(cos(ga), 0.0, sin(ga)) * float(data.spacing) * sqrt(float(slot) + 0.6)
	var a := float(slot) * 2.2 + 0.7
	var r := 3.0 + float(slot % 3) * 2.0
	return group.dest + Vector3(cos(a), 0.0, sin(a)) * r


func _at_spot(dt: float, act: WildGroup.Activity, to: Vector3, far: float) -> void:
	match act:
		WildGroup.Activity.FEED:
			if group and group.sentry == self and group.alive().size() > 1:
				if state != State.SENTRY:
					_enter(State.SENTRY, 30.0)
				_stand(dt)
				_play(String(data.clips.alert))
				# a slow look round
				_yaw += sin(now() * 0.35 + float(get_instance_id() % 7)) * 0.35 * dt
				rotation.y = _yaw
				return
			if data.get("eats", "") == "mice":
				_mousing(dt)
				return
			_graze_cycle(dt)
		WildGroup.Activity.EAT:
			# a fox at a carcass (the pack eats in _predator)
			var c := group.carcass if group else null
			var rim := WildlifeSpawner.carcass_rim(c)
			if c != null and is_instance_valid(c) and c.meat_left > 0.02 and c.global_position.distance_to(global_position) < 2.4 + rim:
				if state != State.EAT:
					_enter(State.EAT, 30.0)
				_eat_tick(dt)
			elif c != null and is_instance_valid(c) and c.meat_left > 0.02:
				var tc := c.global_position + (global_position - c.global_position).normalized() * (1.0 + rim) - global_position
				tc.y = 0.0
				_move(tc, float(data.walk), dt, false)
				_play(String(data.clips.walk), 0.3, clampf(_speed / float(data.walk_ref), 0.5, 2.0))
			else:
				_graze_cycle(dt)
		WildGroup.Activity.BED:
			if state != State.REST:
				_enter(State.REST, 60.0)
			_stand(dt)
			_play(String(data.clips.low), 0.5, 0.45)
		_:
			_graze_cycle(dt)


## Grazing on the spot with a step now and then and a look up.
func _graze_cycle(dt: float) -> void:
	match state:
		State.GRAZE:
			_stand(dt)
			_play(String(data.clips.graze))
			if _t > _len:
				_enter(State.IDLE, rng.randf_range(2.0, 5.0))
		State.WANDER:
			var to := _target - global_position
			to.y = 0.0
			if to.length() < 0.8 or _t > _len:
				_enter(State.GRAZE, rng.randf_range(6.0, 14.0))
			else:
				_move(to, float(data.walk) * 0.7, dt, false)
				_play(String(data.clips.walk), 0.3, clampf(_speed / float(data.walk_ref), 0.5, 2.0))
		_:
			_stand(dt)
			if state != State.IDLE:
				_enter(State.IDLE, rng.randf_range(2.0, 5.0))
			if _t > _len:
				if rng.randf() < 0.35:
					var a := rng.randf() * TAU
					_target = global_position + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(1.5, 4.0)
					_enter(State.WANDER, 8.0)
				else:
					_enter(State.GRAZE, rng.randf_range(6.0, 14.0))


## A fox hunting mice in the grass: listens, then pounces.
func _mousing(dt: float) -> void:
	_pounce_t -= dt
	if _pounce_t <= 0.0 and state != State.ATTACK:
		_pounce_t = rng.randf_range(12.0, 30.0)
		_enter(State.ATTACK, 1.3)
		_bit = true
	if state == State.ATTACK:
		_stand(dt)
		_play(String(data.clips.jump), 0.15)
		if _t > _len:
			_enter(State.IDLE, 3.0)
			hunger = maxf(hunger - 0.15, 0.0)
		return
	_graze_cycle(dt)


# --- Predators -----------------------------------------------------------------------------------

func _predator(dt: float) -> void:
	var p := _player()
	var bold := spawner.boldness() if spawner else 1.0
	if state == State.FLEE:
		var away := global_position - threat_pos
		away.y = 0.0
		_move(away if away.length_squared() > 0.01 else -global_basis.z, float(data.run), dt, true)
		_play(String(data.clips.run), 0.2, clampf(_speed / float(data.run_ref), 0.6, 2.4))
		if _t > _len and global_position.distance_to(threat_pos) > 90.0:
			awareness = 0.0
			if group and (group.is_leader(self)):
				group.home = global_position
				group.dest_set = false
			_enter(State.IDLE, rng.randf_range(4.0, 8.0))
		return
	var hurt := health < float(data.health) * 0.4
	var beaten := group != null and group.losses >= 2
	# the alpha fallen: the pack runs till it has a new one
	var routed: bool = group != null and String(data.get("brain", "")) == "pack" and group.is_routed(now())
	if (hurt or beaten or routed) and p:
		_start_flee(threat_pos if routed and threat_pos != Vector3.ZERO else p.global_position)
		return
	# the player: hunted when the pack is aware of him outside the fort, and guarded against at a kill
	var p_out := p != null and not p.is_dead and Vector2(p.global_position.x, p.global_position.z).length() > FORT_KEEP_OUT - 4.0
	var eating := group != null and group.activity == WildGroup.Activity.EAT and is_instance_valid(group.carcass)
	if eating and p_out and group.carcass.global_position.distance_to(p.global_position) < 12.0 \
			and not _fire_near(p.global_position) and state in [State.EAT, State.IDLE, State.TRAVEL, State.HOLD_OFF]:
		awareness = 1.2                          # too close to the kill: they turn on him
	# starving, the kill they tracked was his (he dresses it, or carries its meat off): they come for him (WildPlanner)
	if group and p_out and now() < group.after_player_until and not _fire_near(p.global_position):
		awareness = maxf(awareness, 1.2)
		threat_pos = p.global_position
	var at_kill := eating and p_out and group.carcass.global_position.distance_to(p.global_position) < 25.0
	var fed := hunger < FED and not at_kill and now() - _hurt_at > PROVOKED_S
	var hunting_player := p_out and not fed and awareness >= 0.5 \
			and (bold > 0.6 or global_position.distance_to(p.global_position) < 30.0)
	var prey := group.prey if group and group.activity == WildGroup.Activity.HUNT and is_instance_valid(group.prey) \
			and not group.prey.is_dead() else null
	# weak, it leaves the chase to the pack and follows on (to eat at the kill)
	if prey != null and weak():
		prey = null
	match state:
		State.STALK, State.CHASE, State.ATTACK, State.HOLD_OFF:
			_hunt_tick(dt, p, prey, hunting_player, bold)
		_:
			if hunting_player and not (eating and group.carcass.global_position.distance_to(p.global_position) > 25.0):
				_enter(State.STALK, rng.randf_range(5.0, 9.0))
				if group:
					group.raise_alarm(p.global_position, now())
			elif prey != null and global_position.distance_to(prey.global_position) < 70.0:
				_enter(State.STALK, rng.randf_range(3.0, 6.0))
			elif group and group.alarmed(now(), 8.0) and p_out and group.activity != WildGroup.Activity.EAT:
				awareness = maxf(awareness, 0.6)
				threat_pos = p.global_position
			elif eating and state == State.EAT:
				_eat_tick(dt)
			else:
				_routine_predator(dt, prey)


## Out on the routine: going to the pack's place (or toward the herd it hunts), resting, patrolling.
func _routine_predator(dt: float, prey: WildAnimal) -> void:
	if prey != null:
		# closing in on the herd at a trot, spread out
		var to := prey.global_position - global_position
		to.y = 0.0
		_move(to, float(data.walk) * 2.4, dt, false)
		_play(String(data.clips.walk), 0.3, clampf(_speed / float(data.walk_ref), 0.5, 3.0))
		if state != State.TRAVEL:
			_enter(State.TRAVEL, 60.0)
		return
	var act := group.activity if group else WildGroup.Activity.PATROL
	if act == WildGroup.Activity.EAT and group and is_instance_valid(group.carcass):
		var ring := _ring_at(group.carcass.global_position,
				float(data.get("eat_ring", 1.0)) + WildlifeSpawner.carcass_rim(group.carcass))
		var to := ring - global_position
		to.y = 0.0
		if to.length() > 0.8:
			if state != State.TRAVEL:
				_enter(State.TRAVEL, 60.0)
			_move(to, float(data.walk) * 1.8, dt, false)
			_play(String(data.clips.walk), 0.3, clampf(_speed / float(data.walk_ref), 0.5, 2.6))
		else:
			_enter(State.EAT, 30.0)
		return
	_routine(dt)


## Feeding at the carcass: it loses meat, hunger falls; the kill's smell and the tearing keep the others close.
func _eat_tick(dt: float) -> void:
	var c := group.carcass if group else null
	if c == null or not is_instance_valid(c) or c.meat_left <= 0.02:
		_enter(State.IDLE, 2.0)
		return
	if c.global_position.distance_to(global_position) > 2.6 + WildlifeSpawner.carcass_rim(c):
		_enter(State.IDLE, 0.5)            # pushed off it: back round to it
		return
	_face(c.global_position, dt)
	_stand(dt)
	_play(String(data.clips.eat))
	# (the pack lets the weak one feed first)
	var took := float(c.eat(float(data.get("eat_rate", 0.003)) * (WEAK_EAT if weak() else 1.0) * dt
			* (spawner.time_scale if spawner else 1.0)))
	hunger = maxf(hunger - took * 4.0, 0.0)


## Stalking, chasing and attacking the quarry: the player (hunting_player) or the prey the pack chose.
func _hunt_tick(dt: float, p: FrontierPlayer, prey: WildAnimal, hunting_player: bool, bold: float) -> void:
	var quarry: Node3D = p if hunting_player or prey == null else prey
	if quarry == null or (quarry == p and (p.is_dead or not hunting_player)) or (quarry is WildAnimal and (quarry as WildAnimal).is_dead()):
		_enter(State.IDLE, 2.0)
		return
	var on_player := quarry == p
	# worn down: the pack draws off and shadows him
	var shadow := on_player and _shadowing(p)
	if on_player and _fire_near(p.global_position) and state != State.HOLD_OFF:
		_enter(State.HOLD_OFF, rng.randf_range(4.0, 7.0))
		return
	var to := quarry.global_position - global_position
	to.y = 0.0
	var d := to.length()
	match state:
		State.STALK:
			var ring := _ring_point(quarry.global_position, (SHADOW_R if shadow else (14.0 if bold > 0.6 else 22.0)) \
					if on_player else 22.0)
			var rt := ring - global_position
			rt.y = 0.0
			if rt.length() > 1.5:
				_move(rt, float(data.walk) * (2.0 if on_player else 1.2), dt, false)
				_play(String(data.clips.walk), 0.3, clampf(_speed / float(data.walk_ref), 0.5, 2.6))
			else:
				_face(quarry.global_position, dt)
				_stand(dt)
				_play(String(data.clips.alert))
			var bolted := not on_player and (quarry as WildAnimal).state == State.FLEE
			if shadow:
				if _t > _len:
					_enter(State.STALK, rng.randf_range(5.0, 8.0))
			elif bolted or _t > _len or (not on_player and d < 25.0):
				if on_player and not (bold > 0.6 or d < 10.0):
					if _t > 25.0:
						_enter(State.IDLE, 5.0)
				else:
					_enter(State.CHASE, 25.0 if not on_player else 12.0)
					if group and not on_player:
						group.hunt_since = now()
		State.CHASE:
			if shadow:
				_enter(State.STALK, rng.randf_range(5.0, 8.0))
				return
			# the player faces it: it holds off, circling round toward his side (the one behind him comes in)
			if on_player and _faced_by(p):
				_circle(p, dt)
				if _t > _len:
					_enter(State.HOLD_OFF, 3.0)
				return
			if d < 1.9 and _bite_cd <= 0.0:
				_enter(State.ATTACK, 0.8)
				_bit = false
				return
			if on_player:
				# for the back of his legs
				to = p.global_position - _player_fwd(p) * 0.9 - global_position
				to.y = 0.0
			var lead := to.normalized() * 1.5 + (quarry.get("velocity") as Vector3 if quarry.get("velocity") != null else Vector3.ZERO) * 0.35
			_move(to + lead, float(data.run) * (0.9 if _t > 18.0 else 1.0), dt, true)
			_play(String(data.clips.run), 0.2, clampf(_speed / float(data.run_ref), 0.6, 2.4))
			if _t > _len:
				_enter(State.HOLD_OFF if on_player else State.IDLE, 3.0)
				if not on_player and group:
					group.prey = null            # it got away: the pack gives up for now
		State.ATTACK:
			_attack_tick(dt, float(data.get("bite", 12.0)) * (1.0 if on_player else 2.4), quarry)
		State.HOLD_OFF:
			_hold_off_tick(dt, p, bold)


## Circling at a respectful distance: from a fire when there is one, else from the player.
func _hold_off_tick(dt: float, p: FrontierPlayer, bold: float) -> void:
	if p == null or p.is_dead:
		_enter(State.IDLE, 5.0)
		return
	var centre := p.global_position
	var keep := 8.0
	var f := spawner.nearest_fire(p.global_position, 7.0) if spawner else Vector3.INF
	if f != Vector3.INF:
		centre = f
		keep = 8.5
	var from_c := global_position - centre
	from_c.y = 0.0
	var d := from_c.length()
	var tangent := from_c.cross(Vector3.UP).normalized() * (1.0 if group == null or group.slot_of(self) % 2 == 0 else -1.0)
	var want := tangent + from_c.normalized() * clampf((keep - d) * 0.6, -1.0, 1.5)
	_move(want, float(data.walk) * 1.8, dt, false)
	_play(String(data.clips.walk), 0.3, clampf(_speed / float(data.walk_ref), 0.5, 2.6))
	if _t > _len and not _fire_near(p.global_position):
		_enter(State.CHASE if bold > 0.6 else State.STALK, 10.0)


## Where the player looks (flat).
static func _player_fwd(p: FrontierPlayer) -> Vector3:
	var f := -Basis(Vector3.UP, p.yaw).z
	return Vector3(f.x, 0.0, f.z).normalized()


## Whether the player faces this wolf: it is near him and within FACED_DEG of where he looks.
func _faced_by(p: FrontierPlayer) -> bool:
	var to := global_position - p.global_position
	to.y = 0.0
	return to.length() < FACED_KEEP + 5.0 and rad_to_deg(_player_fwd(p).angle_to(to.normalized())) < FACED_DEG


## Circling a player who faces it: FACED_KEEP m off, round the way that takes it out of his view.
func _circle(p: FrontierPlayer, dt: float) -> void:
	var from_p := global_position - p.global_position
	from_p.y = 0.0
	var d := from_p.length()
	var n := from_p / maxf(d, 0.01)
	var t := Vector3.UP.cross(n)
	var f := _player_fwd(p)
	if f.angle_to(n + t * 0.3) < f.angle_to(n - t * 0.3):
		t = -t
	var want := t + n * clampf((FACED_KEEP - d) * 0.6, -1.0, 1.5)
	_move(want, float(data.run) * 0.75, dt, true)
	_play(String(data.clips.run), 0.2, clampf(_speed / float(data.run_ref), 0.6, 2.4))


## Whether the pack has worn `p` down and shadows him: weak (WEAK_FRAC of his health, or a pool of blood still to lose
## of a fifth of it) it draws off; whole again (RECOVERED_FRAC, the bleeding stopped) it comes on.
func _shadowing(p: FrontierPlayer) -> bool:
	var pool := float(p.wounds.pool) if p.wounds else 0.0
	var weak := p.health < p.max_health * WEAK_FRAC or pool > p.max_health * 0.2
	if group == null:
		return weak
	if weak:
		group.shadowing = true
	elif group.shadowing and p.health >= p.max_health * RECOVERED_FRAC and pool <= 0.0:
		group.shadowing = false
	return group.shadowing


## A point on a ring of radius r round a centre, spread by the pack slot (the pack surrounds its quarry).
func _ring_point(center: Vector3, r: float) -> Vector3:
	var from := global_position - center
	from.y = 0.0
	var base := atan2(from.z, from.x)
	var slot := group.slot_of(self) if group else 0
	var a := base + (float(slot) - 1.5) * 0.6
	var pt := center + Vector3(cos(a), 0.0, sin(a)) * r
	var fl := Vector2(pt.x, pt.z)
	if fl.length() < FORT_KEEP_OUT:
		fl = fl.normalized() * FORT_KEEP_OUT
		pt = Vector3(fl.x, pt.y, fl.y)
	return pt


## A place round a carcass for this member (the pack gathers round the kill).
func _ring_at(center: Vector3, r: float) -> Vector3:
	var slot := group.slot_of(self) if group else 0
	var a := float(slot) * TAU / maxf(group.alive().size() if group else 1, 1.0)
	return center + Vector3(cos(a), 0.0, sin(a)) * r


func _fire_near(pos: Vector3) -> bool:
	return spawner != null and spawner.nearest_fire(pos, 7.0) != Vector3.INF


## Where a strike lands on the player (the wound's place: PlayerWounds.region_at): its species' strike_h (a wolf or a
## fox bites low: the legs mostly, an arm or the belly; a buck's antlers the belly and the chest; a bison's head the
## hips and the belly); somewhere across the body's width.
func _strike_point(p: Node3D, dir: Vector3) -> Vector3:
	var hr: Array = data.get("strike_h", [0.5, 1.3])
	# a wolf from behind: the back of the legs
	if data.get("hamstring", false) and p is FrontierPlayer \
			and Vector3(dir.x, 0.0, dir.z).normalized().dot(_player_fwd(p)) > 0.3:
		hr = [0.25, 0.7]
	var side := dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.99 else Vector3.RIGHT
	return p.global_position + Vector3.UP * rng.randf_range(float(hr[0]), float(hr[1])) + side * rng.randf_range(-0.22, 0.22) \
			- Vector3(dir.x, 0.0, dir.z).normalized() * 0.15


## Face the quarry, strike once in the clip's middle, then back off (wolves) or run (a buck).
func _attack_tick(dt: float, damage: float, quarry: Node3D) -> void:
	_stand(dt)
	if quarry:
		_face(quarry.global_position, dt)
	_play(String(data.clips.attack), 0.1)
	var p := _player()
	if not is_prey() and quarry == p and _fire_near(p.global_position):
		_bit = true
		_enter(State.HOLD_OFF, rng.randf_range(4.0, 7.0))
		return
	if not _bit and _t > 0.3:
		_bit = true
		var reach := float(data.get("reach", 2.5))
		if quarry and is_instance_valid(quarry) and global_position.distance_to(quarry.global_position) < reach:
			var dir := (quarry.global_position - global_position).normalized()
			if quarry == p:
				if not p.is_dead:
					p.apply_hit(damage, _strike_point(p, dir), dir, self, "body")
					# a heavy beast's butt throws him (the species' defend "knock": m/s)
					var knock := float((data.get("defend", {}) as Dictionary).get("knock", 0.0))
					if knock > 0.0 and is_prey() and not p.is_dead and p.has_method("knock_down"):
						p.knock_down(Vector3(dir.x, 0.0, dir.z).normalized() * knock + Vector3.UP * knock * 0.35)
			elif quarry is WildAnimal and not (quarry as WildAnimal).is_dead():
				(quarry as WildAnimal).apply_hit(damage, quarry.global_position + Vector3.UP * 0.6, dir, self, "body")
	if _t > _len:
		_bite_cd = float(data.get("bite_cd", 1.5)) * (0.6 if quarry is WildAnimal else 1.0)
		if not is_prey():
			_enter(State.HOLD_OFF if quarry == p else State.CHASE, rng.randf_range(1.2, 2.2) if quarry == p else 20.0)
		else:
			_enter(State.FLEE, 6.0)


# --- Hits, blood, death, the carcass -------------------------------------------------------------

func apply_hit(damage: float, point: Vector3, direction: Vector3, source: Node = null, part := "body") -> void:
	if mirrored:
		NetWildlife.forward_hit(self, damage, point, direction, source, part)     # (the host's animal takes it)
		return
	if damage > 0.0 and not (source is WildAnimal) and _skel != null and direction.length_squared() > 1e-8:
		# the round's path through its fitted body (Anatomy, the user 2026-10-03: the hit worked out in "a perfect skeleton")
		var an := Anatomy.attach_to(_skel)
		if an:
			_report = an.add_wound(point, direction, damage)
			if not an.last_shot.is_empty() and bool((an.last_shot.fx as Dictionary).missed):
				return                          # (the hit zone caught it; the body was not there: it went by)
			# the brain, the brainstem, the cord at the neck: a clean kill, whatever the animal's health
			if bool(Anatomy.effect(an.last_hits, damage).lethal) and state != State.DEAD:
				health = 0.0
	elif _skel != null and _skel.has_node(^"Anatomy"):
		(_skel.get_node(^"Anatomy") as Anatomy).last_hits.clear()     # (a bite has no channel: the old rules)
	if state == State.DEAD and _rag != null and not _rag.frozen and damage > 0.0:
		# a shot or an arrow into a body still falling or lying loose: it is knocked by it
		_rag.push(point, _blow(damage, direction))
		return
	if state == State.DEAD or damage <= 0.0:
		return
	var kind := wound_at(point, direction, part)
	var wd: Dictionary = WildlifeSpecies.WOUNDS[kind]
	# (the wound's multiplier in place of the collider's: the vitals sphere's VITALS_MULT is in `damage` already)
	damage *= float(wd.mult) / (WildlifeSpecies.VITALS_MULT if part == "vitals" else 1.0)
	health -= damage
	last_wound = kind
	if spawner:
		spawner.blood_splash(point, direction, self, String(wd.look))
	var by_wolf := source is WildAnimal
	_hurt_at = now()
	# (the player's weapons name him: Weapon / Throwable set the shooter, AxeMelee passes him)
	hurt_by = "wolf" if by_wolf else ("player" if source is FrontierPlayer else "")
	# (the spine: down where it stands)
	if health <= 0.0 or kind == "spine":
		_death_push = _blow(damage, direction)
		_death_at = point
		_die("wolf" if by_wolf else "player")
		return
	_wounds.append({"kind": kind, "rate": damage * float(wd.bleed), "clot": float(wd.clot), "look": String(wd.look)})
	var from := (source as Node3D).global_position if source is Node3D else point - direction * 30.0
	threat_pos = from
	awareness = 1.3
	if is_prey():
		_start_flee(from)
	else:
		if health < float(data.health) * 0.4 and group:
			group.losses += 1
		if group and group.alpha == self and health < float(data.health) * ALPHA_HURT:
			group.alpha_down(now())
		if group:
			group.raise_alarm(from, now())
			group.remember(from, 1.0, now())
		if state in [State.IDLE, State.GRAZE, State.WANDER, State.REST, State.EAT, State.TRAVEL]:
			_enter(State.CHASE if spawner and spawner.boldness() > 0.6 else State.HOLD_OFF, 6.0)


## The wound a hit at `point` travelling `direction` makes (WildlifeSpecies.WOUNDS): on the head's zone the head; else
## found along the shot's path through the body capsule (the heart, then the lungs: WildlifeSpecies.HEART / LUNGS), else
## where it went in: on the vitals sphere (the spine's bone) the spine, a path passing the body's axis far out a graze,
## the gut's length the gut (GUT_ALONG), the shoulder or the haunch a leg.
func wound_at(point: Vector3, direction: Vector3, part := "body") -> String:
	# what the shot went through on its skeleton map decides it (Anatomy.effect), when it went through anything of note
	if _skel != null and not (_skel.get_node_or_null(^"Anatomy") as Anatomy == null):
		var an := _skel.get_node(^"Anatomy") as Anatomy
		var fx := Anatomy.effect(an.last_hits, 60.0)
		var k := String(fx.kind)
		if k != "" and not (k == "leg" and part == "head"):
			return k
	if part == "head":
		return "head"
	var cap := _body_capsule()
	if cap == null:
		return "lungs" if part == "vitals" else "gut"
	var sb := _zones[0]
	var r := cap.radius
	var half := cap.height * 0.5
	var c := sb.global_position
	var axis := sb.global_basis.y.normalized()
	var hb := _skel.find_bone(String((data.head as Array)[1])) if _skel else -1
	if hb >= 0 and (_skel.global_transform * _skel.get_bone_global_pose(hb).origin - c).dot(axis) < 0.0:
		axis = -axis                           # (toward the head)
	var up := Vector3.UP - axis * Vector3.UP.dot(axis)
	up = up.normalized() if up.length_squared() > 1e-4 else Vector3.UP
	var dir := direction.normalized() if direction.length_squared() > 1e-6 else (c - point).normalized()
	var a := point - dir * r * 0.2
	var b := point + dir * r * 2.4
	for organ: Array in [["heart", WildlifeSpecies.HEART], ["lungs", WildlifeSpecies.LUNGS]]:
		var o: Array = organ[1]
		var at := c + axis * half * float(o[0]) + up * r * float(o[1])
		if Geometry3D.get_closest_point_to_segment(at, a, b).distance_to(at) < r * float(o[2]):
			return String(organ[0])
	if part == "vitals":
		return "spine"
	var near := Geometry3D.get_closest_points_between_segments(a, b, c - axis * half, c + axis * half)
	if (near[0] as Vector3).distance_to(near[1] as Vector3) > r * WildlifeSpecies.GRAZE_OUT:
		return "graze"
	var along := (point - c).dot(axis) / half
	var ga: Array = WildlifeSpecies.GUT_ALONG
	return "gut" if along > float(ga[0]) and along < float(ga[1]) else "leg"


func _body_capsule() -> CapsuleShape3D:
	if _zones.is_empty() or _zones[0].get_child_count() == 0:
		return null
	return (_zones[0].get_child(0) as CollisionShape3D).shape as CapsuleShape3D


## How hard it bleeds now, all its wounds (health a second, standing).
func bleed_rate() -> float:
	var r := 0.0
	for w in _wounds:
		r += float(w.rate)
	return r


## The look of its blood on the ground: the worst-bleeding wound's (WildlifeSpecies.WOUNDS look), "" unwounded.
func wound_look() -> String:
	var best := ""
	var br := -1.0
	for w in _wounds:
		if float(w.rate) > br:
			br = float(w.rate)
			best = String(w.look)
	return best


## Weak: under WEAK_HEALTH of its health, or lamed (a wolf leaves the chase to the pack).
func weak() -> bool:
	return health < float(data.health) * WEAK_HEALTH or lame()


## How winded it is: 0 fresh .. 1 blown (a species that "tires", from WINDED of its fatigue; others never).
func winded() -> float:
	if not data.has("tires"):
		return 0.0
	return smoothstep(WINDED.x, WINDED.y, fatigue)


## Lamed: a leg wound still bleeding LAME_BLEED or more.
func lame() -> bool:
	for w in _wounds:
		if String(w.kind) == "leg" and float(w.rate) >= LAME_BLEED:
			return true
	return false


func _bleed_tick(dt: float) -> void:
	if _wounds.is_empty():
		# mending, fed and resting the faster (whole again, no longer his game: WildlifeSpawner.players_game)
		if state != State.DEAD and health < float(data.health):
			var k := (1.0 - hunger) * (HEAL_REST if state in [State.REST, State.EAT, State.GRAZE] else 1.0)
			health = minf(health + float(data.health) / HEAL_S * k * dt, float(data.health))
			if health >= float(data.health):
				hurt_by = ""
		return
	var rate := bleed_rate()
	health -= rate * (WildlifeSpecies.RUN_BLEED if state in [State.FLEE, State.CHASE] else 1.0) * dt
	for i in range(_wounds.size() - 1, -1, -1):
		var w := _wounds[i]
		w.rate = float(w.rate) * maxf(1.0 - float(w.clot) * dt, 0.0)
		if float(w.rate) < STOPPED_BLEED:
			_wounds.remove_at(i)
	var moved := global_position.distance_to(_last_pos)
	_drop_dist += moved + dt * 0.3
	_last_pos = global_position
	# (the harder it bleeds, the bigger the drops and the closer together)
	if _drop_dist > clampf(2.5 / (0.5 + rate), 0.45, 4.0) and spawner:
		_drop_dist = 0.0
		spawner.blood_drop(global_position + Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2)),
				clampf(0.6 + rate * 0.22, 0.6, 2.2), self, wound_look())
	if health <= 0.0:
		_die(hurt_by if hurt_by != "" else "bleed")


## Dead already (a save's carcass, SaveParts): lying as its death clip ends, not falling again.
func lie_dead(by: String) -> void:
	_die(by, false)
	if _ap == null or not _ap.has_animation(_anim):
		return
	_ap.stop()
	_ap.play(_anim, 0.0)
	_ap.seek(_ap.get_animation(_anim).length, true)


## A carcass about to be hauled (CarcassLoad.from_carcass: a rope, a drag) lies as its death clip ends, the pose the hauling is
## built for, in place of the pose its ragdoll came to rest in (a sprawl no rope can sensibly slide).
func settle_for_haul() -> void:
	if _rag == null:
		return
	_rag.release()
	_rag.queue_free()
	_rag = null
	if _ap != null and _ap.has_animation(_anim):
		_ap.stop()
		_ap.play(_anim, 0.0)
		_ap.seek(_ap.get_animation(_anim).length, true)
		_ap.advance(0.0)                  # (the bones take the pose now: the rope measures it at once)
		_ap.pause()
	if _skel != null:
		_skel.force_update_all_bone_transforms()


func _die(by: String, ragdoll := true) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	killed_by = by
	_t = 0.0
	_death_v = Vector3(velocity.x, 0.0, velocity.z)
	velocity = Vector3.ZERO
	_wounds.clear()
	_zones_off()
	collision_layer = 0
	meat_left = meat_full()
	_play(String(data.clips.death), 0.1)
	if ragdoll and is_inside_tree():
		_start_ragdoll()
	# the hunter's report: what the shot went through, and the moment seen (a heart or a brain)
	var pl := _player()
	if ragdoll and by == "player" and pl != null and pl.interactor != null and not _report.is_empty():
		pl.interactor.notice(Anatomy.report(_report), 3.5)
		if _report.any(func(l: String) -> bool: return l.begins_with("Heart") or l.begins_with("Brain")):
			Anatomy.slowmo(get_tree())
	set_meta("died_at", now())
	InspectView.ensure_hotkey(get_tree())
	if spawner:
		spawner.animal_died(self, by)            # one fewer in the land (WildlifeEcology)
	add_to_group(PlacedWeapon.GROUP)      # the interactor's carcass hook
	add_to_group(&"carcasses")
	if group:
		group.remember(global_position, 1.5, now())
		if not is_prey():
			group.losses += 1
		if group.alpha == self:
			group.alpha_down(now())
	died.emit(self)


## The push of a blow of `damage` along `direction` (m/s on the body it lands in), a ball's hard, an arrow light.
func _blow(damage: float, direction: Vector3) -> Vector3:
	var d := direction.normalized() if direction.length_squared() > 1e-6 else Vector3.ZERO
	return d * clampf(damage * DEATH_PUSH.x, 0.8, DEATH_PUSH.y)


func _mass_kg() -> float:
	var body: Array = data.body
	var r := float(body[0])
	return clampf(PI * r * r * float(body[1]) * 800.0, 3.0, 900.0)


## Down as a ragdoll: the bodies on its bones where they are, going on the way it ran and struck by the blow that killed it.
func _start_ragdoll() -> void:
	if _rag != null or _skel == null or not _skel.is_inside_tree():
		return
	# (no ground under it yet, the land round it not loaded: it falls as its clip has it)
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, global_position + Vector3.DOWN * 3.0)
	q.exclude = [get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return
	if _ap:
		_ap.pause()
	_rag = BoneRagdoll.build(_skel, RAG_ROWS, _mass_kg(), self)
	if _rag.bodies.is_empty():
		_rag.queue_free()
		_rag = null
		return
	_rag.launch(_death_v * 0.9 + _death_push * 0.5)
	if _death_push != Vector3.ZERO:
		var at := _death_at if _death_at != Vector3.ZERO else _skel.global_position
		_rag.push(at, _death_push)
	_rag.rested.connect(_on_rag_rested)


## At rest: the animal goes where the body lies (its hips on the ground, turned along the barrel), the pose kept in its
## own frame, the bodies freed: a carcass as before, where it fell.
func _on_rag_rested() -> void:
	if _rag == null or _rag.frozen:
		return
	var worlds := _rag.worlds()
	var hips := _rag.root_body()
	var fwd := Vector3.ZERO
	var b2 := _rag.bodies.get("Torso2") as RigidBody3D
	if hips and b2:
		fwd = b2.global_position - hips.global_position
		fwd.y = 0.0
	var at := hips.global_position if hips else global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 4.0)
	var ex: Array[RID] = [get_rid()]
	for rb: RigidBody3D in _rag.bodies.values():
		ex.append(rb.get_rid())             # (not its own body: that is not the ground)
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground := (hit.position as Vector3).y if not hit.is_empty() else at.y - 0.3
	_visual.rotation.x = 0.0
	if fwd.length() > 0.05:
		rotation.y = atan2(-fwd.x, -fwd.z)
	global_position = Vector3(at.x, ground, at.z)
	_rag.freeze(worlds)
	_update_zones()


## Marks this wolf the pack's alpha (larger, its coat darker) or takes the mark off.
func make_alpha(on: bool) -> void:
	if _visual == null:
		return
	_visual.scale = Vector3.ONE * _base_scale * (ALPHA_SCALE if on else 1.0)
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in m.mesh.get_surface_count():
			if not on:
				m.set_surface_override_material(si, null)
				continue
			var base := m.mesh.surface_get_material(si) as BaseMaterial3D
			if base:
				var d := base.duplicate() as BaseMaterial3D
				d.albedo_color = base.albedo_color * Color(ALPHA_DARK, ALPHA_DARK, ALPHA_DARK, 1.0)
				m.set_surface_override_material(si, d)


## A scavenger takes up to `amount` of meat; returns what it got.
func eat(amount: float) -> float:
	var took := minf(amount, meat_left)
	meat_left -= took
	WildlifeSpawner.touch(self)
	if meat_left <= 0.02 and not get_meta("bones", false):
		set_meta("bones", true)
		set_meta("bones_at", now())
		remove_from_group(PlacedWeapon.GROUP)
		_show_remains(0.0)
	elif meat_left < REMAINS_MEAT * meat_full():
		_show_remains(meat_left)
	return took


## A whole carcass's meat, in deer (the species' "meat": a buck 1.2, a bison 6; 1 a deer): the scavengers' share and the
## butchering's.
func meat_full() -> float:
	return float(data.get("meat", 1.0))


func interact_point() -> Vector3:
	return global_position + Vector3.UP * float(data.body[2]) * 0.4


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func interact_prompt(_p: Node) -> String:
	# the death clip plays out first (the dead animal's own clock stops: _physics_process returns)
	if state != State.DEAD or (spawner != null and now() - float(get_meta("died_at", 0.0)) < 1.0) or meat_left <= 0.02:
		return ""
	if _rag != null and not _rag.frozen:
		return ""          # still falling, it comes to rest first
	var s := _next_step()
	if s.is_empty():
		return ""
	var fd := spawner.dressing if spawner else null
	if fd and fd.working and fd.carcass == self:
		return "Stop"
	var line := "%s the %s" % [s.capitalize(), String(data.name)]
	if dress_progress > 0.0:
		line += " (%d%%)" % int(dress_progress * 100.0)
	if fd and not fd.has_knife():
		line += " (needs a knife)"
	return line


## The hold-E list (PlayerInteractor): the dressing's next step (the tap's) and a look inside (InspectView: the body as the
## shots left it; the user 2026-10-03).
func interact_actions(p: Node) -> Array:
	var out := []
	var t := interact_prompt(p)
	if t != "":
		out.append({"id": "", "text": t})
	if InspectView.can_inspect(self):
		out.append({"id": "inspect", "text": InspectView.ROW})
	return out


func interact_action(_p: Node, id: String) -> void:
	if id == "inspect":
		InspectView.open_on(self)


## The skeleton InspectView looks into, and the name it gives it.
func inspect_skeleton() -> Skeleton3D:
	return _skel


func inspect_title() -> String:
	return String(data.get("name", species)).capitalize()


## "skin", then "butcher" when the species has meat to take, then "" (done).
func _next_step() -> String:
	if dress_step == 0:
		return "skin"
	if dress_step == 1 and not (data.get("butcher", {}) as Dictionary).is_empty():
		return "butcher"
	return ""


func highlight_targets() -> Array:
	return _visual.find_children("*", "MeshInstance3D", true, false) if _visual else []


## E on the carcass: FieldDressing starts (or stops) its next step.
func interact(_p: Node) -> void:
	if state != State.DEAD or spawner == null or spawner.dressing == null:
		return
	var s := _next_step()
	if not s.is_empty():
		WildlifeSpawner.touch(self)
		spawner.dressing.toggle(self, s)


## A step done (FieldDressing): its yields into the pack, a note on screen. Skinned, the carcass shows raw; butchered,
## the remains stay for the scavengers (user 2026-09-26: "instead of disappearing carcass we can have wolves and ravens
## come and eat the remains"). Scavenged meat is gone from the butchering too.
func finish_dress(s: String, p: Node) -> void:
	WildlifeSpawner.touch(self)
	var yields: Dictionary = data.get(s, {})
	var inv := InventoryState.from_player(p)
	var parts: Array[String] = []
	var share := clampf(meat_left / meat_full(), 0.0, 1.0)
	for k: String in yields:
		var n := int(yields[k])
		if s == "butcher":
			n = maxi(int(round(n * share)), 1 if share > 0.15 else 0)
		if n <= 0:
			continue
		inv.add(k, n)
		parts.append("+%d %s" % [n, InventoryState.name_of(k)])
	p.set("inventory_pack", inv.pack.duplicate(true))
	if spawner and not parts.is_empty():
		spawner.note(", ".join(parts))
	dress_progress = 0.0
	if s == "skin":
		dress_step = 1
		_show_skinned()
		if (data.get("butcher", {}) as Dictionary).is_empty():
			dress_step = 2
	else:
		dress_step = 2
		meat_left = minf(meat_left, REMAINS_MEAT * meat_full())
		_show_remains(meat_left)
	if _next_step().is_empty():
		remove_from_group(PlacedWeapon.GROUP)


## The skinned carcass: the coat's colours turned to raw red and pale fat.
func _show_skinned() -> void:
	for mi: MeshInstance3D in highlight_targets():
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as StandardMaterial3D
			if src == null:
				continue
			var m := src.duplicate() as StandardMaterial3D
			var l := m.albedo_color.get_luminance()
			m.albedo_color = Color(0.5, 0.1, 0.08).lerp(Color(0.86, 0.78, 0.7), clampf((l - 0.55) * 2.5, 0.0, 1.0))
			m.roughness = 0.45
			mi.set_surface_override_material(i, m)


## Remains: the body sinks and darkens as it is eaten (0 = bones).
func _show_remains(meat: float) -> void:
	if _visual == null:
		return
	var k := clampf(meat / (REMAINS_MEAT * meat_full()), 0.0, 1.0)
	_visual.scale = Vector3(_base_scale * (0.7 + 0.3 * k), _base_scale * (0.35 + 0.45 * k), _base_scale * (0.75 + 0.25 * k))
	for mi: MeshInstance3D in highlight_targets():
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m == null:
				var src := mi.get_active_material(i) as StandardMaterial3D
				if src == null:
					continue
				m = src.duplicate() as StandardMaterial3D
				mi.set_surface_override_material(i, m)
			m.albedo_color = Color(0.35, 0.08, 0.06).lerp(Color(0.8, 0.76, 0.68), 1.0 - k)
			m.roughness = 0.5 + 0.4 * (1.0 - k)


# --- Movement ------------------------------------------------------------------------------------

func _enter(s: State, length: float) -> void:
	state = s
	_t = 0.0
	_len = length
	if s == State.IDLE:
		var idles: Array = data.clips.idle
		_play(String(idles[rng.randi() % idles.size()]))


func _play(clip: String, blend := 0.3, speed := 1.0) -> void:
	if _ap == null:
		return
	if clip != _anim:
		_anim = clip
		_ap.play(clip, blend)
	_ap.speed_scale = speed


func _face(pos: Vector3, dt: float) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length_squared() < 0.01:
		return
	_yaw = rotate_toward(_yaw, atan2(-to.x, -to.z), float(data.turn) * dt)
	rotation.y = _yaw


## Standing: slowing to a stop on the ground. Once it stands still on the floor (REST_TICKS in a row) the body is not
## slid again till it moves or is moved (user 2026-09-28, the bison's herds: a grazing herd stands most of the time,
## and every body's slide over the ground cost ~0.2 ms a tick, a bison's ~0.3: the herd's standing was most of it).
func _stand(dt: float) -> void:
	_speed = move_toward(_speed, 0.0, 6.0 * dt)
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	velocity.x = fwd.x * _speed
	velocity.z = fwd.z * _speed
	if _speed <= 0.0 and (is_on_floor() or _far) and global_position == _rest_pos:
		_rest_ticks += 1
		if _rest_ticks > REST_TICKS:
			velocity = Vector3.ZERO
			return
	else:
		_rest_ticks = 0
	if _far_from_player():
		_glide(dt)
		_rest_pos = global_position
		return
	_far = false
	_fall(dt)
	move_and_slide()
	_rest_pos = global_position


func _move(dir: Vector3, speed: float, dt: float, running: bool) -> void:
	dir.y = 0.0
	if dir.length_squared() < 1e-4:
		_stand(dt)
		return
	dir = dir.normalized()
	# kept on its own land: its home square (WildlifeSpawner.range_of: the fort's WORLD_LIMIT round the fort)
	var rg := WildlifeSpawner.range_of(home_sq, true)
	var off := global_position - (rg[0] as Vector3)
	if absf(off.x) > float(rg[1]) or absf(off.z) > float(rg[1]):
		dir = Vector3(-off.x, 0.0, -off.z).normalized()
	_avoid_t -= dt
	if _avoid_t <= 0.0:
		_avoid_t = 0.25
		_avoid_yaw = _probe(dir, 1.5 + speed * 0.35)
	var want := atan2(-dir.x, -dir.z) + _avoid_yaw
	_yaw = rotate_toward(_yaw, want, float(data.turn) * (1.3 if running else 1.0) * dt)
	rotation.y = _yaw
	_speed = move_toward(_speed, speed, (9.0 if running else 3.0) * dt)
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	velocity.x = fwd.x * _speed
	velocity.z = fwd.z * _speed
	if _far_from_player():
		_glide(dt)
		_stuck_t = 0.0
		return
	_far = false
	_fall(dt)
	var before := global_position
	if _step != null:
		_step.step(Vector3(velocity.x, 0.0, velocity.z), _speed, dt)
	move_and_slide()
	var got := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if _speed > 0.8 and got < _speed * dt * 0.25:
		_stuck_t += dt
		if _stuck_t > 0.5:
			_stuck_t = 0.0
			_avoid_yaw += (PI * 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
			_avoid_t = 0.8
	else:
		_stuck_t = 0.0


## Steering round trunks, rocks and walls: 0 when the way ahead is clear, else the smallest clear turn.
func _probe(dir: Vector3, reach: float) -> float:
	var space := get_world_3d().direct_space_state
	# (over what it steps over: a log or a stump lower than its step is not an obstacle)
	var from := global_position + Vector3.UP * maxf(minf(float(data.body[2]) * 0.6, 0.6), step_m + 0.1)
	var ex := _exclude()
	var p := _player()
	if p and not is_prey():
		ex.append(p.get_rid())
	var keep_side := 1.0 if _avoid_yaw >= 0.0 else -1.0
	for off: float in [0.0, 0.5 * keep_side, -0.5 * keep_side, 1.0 * keep_side, -1.0 * keep_side, 1.7 * keep_side, -1.7 * keep_side]:
		var d := dir.rotated(Vector3.UP, off)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * reach, 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.collider is WildAnimal or (hit.normal as Vector3).y > 0.7:
			return off
	return PI * 0.5 * keep_side


func _keep_off_fort(dir: Vector3) -> Vector3:
	var flat := Vector2(global_position.x, global_position.z)
	var r := flat.length()
	if r < FORT_AVOID + 10.0 and r > 0.01:
		var out := Vector3(flat.x, 0.0, flat.y) / r
		return (dir + out * clampf((FORT_AVOID + 10.0 - r) / 10.0, 0.0, 1.5)).normalized()
	return dir


## Whether the player is FAR_SIM_D or more away (no player, a test's: near).
func _far_from_player() -> bool:
	var p := _player()
	return p != null and global_position.distance_squared_to(p.global_position) > FAR_SIM_D * FAR_SIM_D


## A step without the body: along its velocity, on the ground (FAR_SIM_D and more from the player).
func _glide(dt: float) -> void:
	_far = true
	var np := global_position + Vector3(velocity.x, 0.0, velocity.z) * dt
	np.y = FrontierTerrain.height_at(np.x, np.z)
	velocity.y = 0.0
	global_position = np


func _fall(dt: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * dt


## The body tilts with the slope under it (nose up going uphill).
func _ground_pitch(dt: float) -> void:
	var want := 0.0
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	if _far:
		# (no body on the ground: the slope from the ground's height before and behind)
		var p := global_position
		var rise := FrontierTerrain.height_at(p.x + fwd.x * 0.8, p.z + fwd.z * 0.8) \
				- FrontierTerrain.height_at(p.x - fwd.x * 0.8, p.z - fwd.z * 0.8)
		want = clampf(atan2(rise, 1.6), -0.6, 0.6)
	elif is_on_floor():
		var n := get_floor_normal()
		want = asin(clampf(-n.dot(fwd), -0.6, 0.6))
	_pitch = lerpf(_pitch, want, clampf(dt * 6.0, 0.0, 1.0))
	_visual.rotation.x = -_pitch
