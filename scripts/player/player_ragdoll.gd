class_name PlayerRagdoll
extends Node
## Knocked down (user 2026-09-27: "what about mammoth attacks do we have ragdoll physics?", "when we get hit?"; picked
## "mammoth attacks + knockdown"): a blow that knocks the player down (FrontierPlayer.knock_down: the mammoth's ram, its
## trunk, its stomp) throws them as a ragdoll, and when they come to rest they get up with the game's own get-up clips.
##   thrown   the player kneels in the game's sense (begin_kneel: their animation and skeleton modifiers suspended, the
##            weapon to the body, the camera orbiting them, input ignored) and a PhysicalBoneSimulator3D takes the
##            skeleton: a body on each main bone (BONES: the hips, the spine, the chest, the head, the upper arms and
##            forearms, the thighs, the shins, the feet), jointed to the next up (cone joints, limited), all given the
##            blow's velocity. The rest of the rig follows them (the helper bones after, CharacterBodyMesh). The
##            player's body goes along with the hips.
##   at rest  after MIN_S, once the hips have been still (under REST_MPS) for REST_S (or MAX_S at most): the get-up clip
##            whose first frame lies most like the body (actor_b-ground-recover-back, -left or -right: on the back or on
##            a side) is laid where the body lies (the player turned and moved so its hips and its line from hips to
##            head fall on the ragdoll's), the ragdoll fades into it over BLEND_S, and it plays (HorsePhaseBlender on the
##            kneel's AnimationPlayer)
##   up       end_kneel: the player's own animation and the weapon back
## What is in the hands (user 2026-09-27: "i like the idea of the player losing there weapon to if they are not careful",
## "works with any object being held on hand", "like a dice roll sometimes they drop sometimes they dont"):
##   let go    what cannot be held on to while thrown, always: a carcass's rope (FootDrag), the wheelbarrow's handles,
##             a log being pulled (LogPull); the off hand's long gun goes onto the back (QuickOffhand)
##   by chance each thing in the hands, drop_chance (a dice roll each):
##             a weapon: knocked out of them, it flies off the way the blow went and lands DROP_M off, lying on the
##             ground as a PlacedWeapon with its state (the charge, the count; E takes it again), and the player gets
##             up empty-handed; kept, it goes onto the body and is drawn again after (as for kneeling)
##             the torch: it falls (PlayerTorch.drop, a DroppedTorch; E takes it again)
##             a gathering tool: knocked out of them the same way (user 2026-09-27: "tools can be losable"), lying
##             on the ground as a DroppedItem (E puts it back in the pack); the player has it no more till then
##             (GatherTools.lose_in_hand)
## A weapon on the body (slung, the hands free) stays there.
## One under each player ("Ragdoll"), the physical bones made the first time it is needed.

const LIB := "actor_b"
const GETUPS := ["actor_b-ground-recover-back", "actor_b-ground-recover-left", "actor_b-ground-recover-right"]
## The bodies: bone -> [the bone its length runs to ("" : a ball), radius (m), mass (kg), swing and twist limits (deg)].
const BONES := {
	"root": ["spinea", 0.15, 12.0, 0.0, 0.0],
	"spineb": ["spined", 0.14, 9.0, 25.0, 15.0],
	"spined": ["neck", 0.16, 13.0, 25.0, 15.0],
	"heada": ["", 0.11, 5.0, 40.0, 35.0],
	"l_shoulder": ["l_elbow", 0.055, 2.5, 80.0, 30.0],
	"l_elbow": ["l_wrist", 0.045, 1.8, 70.0, 20.0],
	"r_shoulder": ["r_elbow", 0.055, 2.5, 80.0, 30.0],
	"r_elbow": ["r_wrist", 0.045, 1.8, 70.0, 20.0],
	"l_upper_leg": ["l_knee", 0.08, 8.0, 60.0, 15.0],
	"l_knee": ["l_ankle", 0.06, 4.0, 65.0, 10.0],
	"l_ankle": ["l_ball", 0.045, 1.2, 30.0, 10.0],
	"r_upper_leg": ["r_knee", 0.08, 8.0, 60.0, 15.0],
	"r_knee": ["r_ankle", 0.06, 4.0, 65.0, 10.0],
	"r_ankle": ["r_ball", 0.045, 1.2, 30.0, 10.0],
}
## Of the blow's push each body takes (the rest: all of it): the legs lag.
const THROW_SHARE := {"root": 0.75, "l_upper_leg": 0.45, "r_upper_leg": 0.45, "l_knee": 0.25, "r_knee": 0.25,
		"l_ankle": 0.15, "r_ankle": 0.15}
## How far the weapon knocked out of the hands lands (m, the way the blow went), and its flight (s).
const DROP_M := Vector2(1.6, 3.2)
const DROP_FLIGHT_S := 0.65
const MIN_S := 0.9
const MAX_S := 4.0
const REST_MPS := 0.35
const REST_S := 0.4
const BLEND_S := 0.4
## The skeleton's own facing and side (the rig's +Z ahead, +X its left) for reading how the body lies.
const FRONT := Vector3(0.0, 0.0, 1.0)
const LEFT := Vector3(1.0, 0.0, 0.0)

signal down
signal up

var player: FrontierPlayer
var skeleton: Skeleton3D
var sim: PhysicalBoneSimulator3D
var bodies := {}                  ## bone name -> PhysicalBone3D
## "" (on their feet), "thrown", "blend" (the ragdoll into the get-up's first frame), "getup".
var phase := ""
var clip := ""
var _t := 0.0
var _still := 0.0
var _clip_t := 0.0
var _ap: AnimationPlayer
var _blender: HorsePhaseBlender
var _front_rest := {}             ## "spined" facing and side in its own frame at rest (the skeleton's +Z, +X)
## The chance each thing in the hands is lost to a knock (0: never, 1: always).
var drop_chance := 0.5
## The weapon and the tool the last knock took from the hands (null: none).
var dropped: PlacedWeapon
var dropped_tool: DroppedItem


static func of(p: FrontierPlayer) -> PlayerRagdoll:
	var r := p.get_node_or_null(^"Ragdoll") as PlayerRagdoll
	if r == null:
		r = PlayerRagdoll.new()
		r.name = "Ragdoll"
		r.player = p
		p.add_child(r)
	return r


## Thrown with velocity `v` (m/s). `dying` (FrontierPlayer._die, just before it marks the player dead; user 2026-09-30: "ragdoll
## physics on deaths"): the body goes limp and stays down (no get-up: respawn() ends it), the weapon is slung, not dropped.
## False when the player cannot be knocked down now (dead, riding, climbing, kneeling,
## mid-vault, or already down).
func knock(v: Vector3, dying := false) -> bool:
	if phase != "" or player == null or (player.is_dead and not dying):
		return false
	skeleton = player.skeleton
	if skeleton == null:
		return false
	_let_go_all()
	# the weapon in the hands, as it is (before the knock slings it), if the dice say it goes
	var held: Weapon = player.weapon if player.weapon and player.weapon.active and not player.hands_free \
			and not dying and randf() < drop_chance else null
	var held_key := player.weapon_key
	var held_xf := held.model.global_transform if held and held.model else Transform3D()
	var ahead := player.global_position - player.global_basis.z
	_ap = player.begin_kneel(self, ahead)
	if _ap == null:
		return false
	dropped = null
	dropped_tool = _lose_tool(v) if not dying else null
	if held:
		dropped = _knock_out(held, held_key, held_xf, v)
	if sim == null:
		_build()
	# the bodies where the bones are now, the ragdoll on, all thrown
	for bn in bodies:
		var pb := bodies[bn] as PhysicalBone3D
		var bi := skeleton.find_bone(String(bn))
		pb.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bi) * pb.body_offset.affine_inverse()
	sim.active = true
	sim.influence = 1.0
	sim.physical_bones_start_simulation()
	# the blow takes the upper body; the legs lag (THROW_SHARE), so the body goes over as it flies
	for bn in bodies:
		var pb := bodies[bn] as PhysicalBone3D
		var share := float(THROW_SHARE.get(bn, 1.0))
		pb.linear_velocity = Vector3(v.x * share, v.y * (0.6 + 0.4 * share), v.z * share)
		pb.angular_velocity = Vector3(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0), randf_range(-1.5, 1.5))
	player.velocity = Vector3.ZERO
	phase = "thrown"
	_t = 0.0
	_still = 0.0
	down.emit()
	return true


func is_down() -> bool:
	return phase != ""


## What the hands cannot keep hold of while thrown (always), and the torch and a tool by chance.
func _let_go_all() -> void:
	if player.foot_drag and player.foot_drag.load != null:
		player.foot_drag.let_go("hit")
	if player.pushing != null and player.pushing.has_method(&"set_down"):
		player.pushing.set_down("hit")
	if player.log_pull and player.log_pull.load != null:
		player.log_pull._drop("kneeling")          # (its kneel ends at once: the knock's own begins)
	if player.quick and player.quick.active():
		player.quick.drop()
	if player.torch and player.torch.holding() and randf() < drop_chance:
		player.torch.drop("fall")

## The tool in the hands, if the dice say so: knocked out of them, off the way the blow went, lying on the ground.
func _lose_tool(v: Vector3) -> DroppedItem:
	var g := player.gather
	if g == null or g.in_hand() == "" or randf() >= drop_chance:
		return null
	var hand = g.get("_model_hand")
	var from: Transform3D = (hand as Node3D).global_transform if hand is Node3D and is_instance_valid(hand) \
			else player.global_transform * Transform3D(Basis(), Vector3(0.3, 1.1, -0.3))
	var kind := g.lose_in_hand()
	if kind == "":
		return null
	var d := DroppedItem.make(kind, 1, g.data.name_of(kind).to_lower() if g.data else "")
	player.get_tree().current_scene.add_child(d)
	d.global_transform = from
	_fling(d, d.model, from, v)
	return d


## Weapon `w` (roster `key`, its model at `from`) knocked out of the hands by a blow of velocity `v`: a PlacedWeapon with
## its state flies off the way the blow went and comes to lie on the ground; the player no longer carries it.
func _knock_out(w: Weapon, key: String, from: Transform3D, v: Vector3) -> PlacedWeapon:
	var pw := PlacedWeapon.from_weapon(w, key)
	if pw.model == null:
		pw.free()
		return null
	if w is Throwable:
		(w as Throwable).count = 0          # the whole of it in the hand is gone (the placed one holds the count)
	player.set_carried(key, false, false)
	player.get_tree().current_scene.add_child(pw)
	pw.global_transform = from
	_fling(pw, pw.model, from, v)
	return pw


## `n` (its model `model`) flies from `from` off the way a blow of velocity `v` went and comes to lie on the ground
## DROP_M off, turned any way, tumbling on its arc.
func _fling(n: Node3D, model: Node3D, from: Transform3D, v: Vector3) -> void:
	var dir := Vector3(v.x, 0.0, v.z)
	dir = dir.normalized() if dir.length() > 0.1 else -player.global_basis.z
	dir = dir.rotated(Vector3.UP, randf_range(-0.7, 0.7))
	var land := player.global_position + dir * randf_range(DROP_M.x, DROP_M.y)
	var q := PhysicsRayQueryParameters3D.create(land + Vector3.UP * 3.0, land + Vector3.DOWN * 6.0)
	q.exclude = [player.get_rid()]
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	var pos: Vector3 = r.position if not r.is_empty() else land
	var up: Vector3 = (r.normal as Vector3).normalized() if not r.is_empty() else Vector3.UP
	# lying on the ground, turned any way, its middle where it lands
	var along := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	along = along - up * along.dot(up)
	along = along.normalized() if along.length() > 0.05 else Vector3.FORWARD
	var b := Basis(up.cross(along).normalized(), up, along)
	var ext := PlacedWeapon.z_extent(model) if model else Vector2.ZERO
	var lie := Transform3D(b, pos + up * 0.03 - b * Vector3(0.0, 0.0, (ext.x + ext.y) * 0.5))
	# the flight: an arc, tumbling
	var q0 := from.basis.get_rotation_quaternion()
	var q1 := lie.basis.get_rotation_quaternion()
	var spin_axis := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)).normalized()
	var o0 := from.origin
	var fly := func(k: float) -> void:
		if not is_instance_valid(n):
			return
		var o := o0.lerp(lie.origin, k) + Vector3.UP * sin(PI * k) * 1.1
		var tumble := Quaternion(spin_axis, TAU * 1.5 * k * (1.0 - k) * 2.0)
		n.global_transform = Transform3D(Basis(tumble * q0.slerp(q1, k)), o)
	var tw := n.create_tween()
	tw.tween_method(fly, 0.0, 1.0, DROP_FLIGHT_S).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## The physical bones: one body on each bone of BONES, a capsule from the bone to the next (a ball on the head), jointed to
## the nearest body up the rig; they do not touch the player's own capsule.
func _build() -> void:
	sim = PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	sim.active = false
	skeleton.add_child(sim)
	# before the body's helper driver (CharacterBodyMesh), which sets the helper bones from the main ones after
	for i in skeleton.get_child_count():
		if skeleton.get_child(i) is CharacterBodyMesh:
			skeleton.move_child(sim, i)
			break
	for bn: String in BONES:
		var spec: Array = BONES[bn]
		var bi := skeleton.find_bone(bn)
		if bi < 0:
			continue
		var to := String(spec[0])
		var r := float(spec[1])
		var dir := Vector3.UP
		var length := r * 2.0
		if to != "" and skeleton.find_bone(to) >= 0:
			# the next bone's place in this bone's frame (the rest pose)
			var here := skeleton.get_bone_global_rest(bi)
			var there := skeleton.get_bone_global_rest(skeleton.find_bone(to))
			var d := here.affine_inverse() * there.origin
			length = maxf(d.length(), r * 2.0)
			dir = d.normalized()
		var centre := dir * (length * 0.5 if to != "" else r * 0.6)
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bn
		pb.bone_name = bn
		pb.mass = float(spec[2])
		pb.friction = 0.9
		pb.bounce = 0.05
		pb.linear_damp = 0.2
		pb.angular_damp = 2.0
		pb.body_offset = Transform3D(Basis(), -centre)
		var cs := CollisionShape3D.new()
		if to == "":
			var sp := SphereShape3D.new()
			sp.radius = r
			cs.shape = sp
		else:
			var cap := CapsuleShape3D.new()
			cap.radius = r
			cap.height = length + r * 0.5
			cs.shape = cap
			cs.basis = Basis(Quaternion(Vector3.UP, dir))
		pb.add_child(cs)
		if bn == "root":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		else:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			# the joint at the bone's own head, its twist axis (X) along the bone
			pb.joint_offset = Transform3D(Basis(), -centre)
			pb.joint_rotation = Basis(Quaternion(Vector3.RIGHT, dir)).get_euler()
			pb.set("joint_constraints/swing_span", float(spec[3]))
			pb.set("joint_constraints/twist_span", float(spec[4]))
			pb.set("joint_constraints/softness", 0.8)
			pb.set("joint_constraints/relaxation", 1.0)
		sim.add_child(pb)
		pb.add_collision_exception_with(player)
		bodies[bn] = pb
	# (bodies next to each other along the rig do not collide: their joint holds them)
	for a in bodies.values():
		for b in bodies.values():
			if a != b:
				(a as PhysicalBone3D).add_collision_exception_with(b)
	var ci := skeleton.find_bone("spined")
	var rest := skeleton.get_bone_global_rest(ci).basis.inverse()
	_front_rest = {"front": rest * FRONT, "left": rest * LEFT}


func _physics_process(dt: float) -> void:
	if phase == "":
		return
	if player == null or not is_instance_valid(player):
		return
	_t += dt
	match phase:
		"thrown":
			var hips := bodies["root"] as PhysicalBone3D
			# the player's body goes with the hips (the camera with it)
			var at := hips.global_position
			player.global_position = Vector3(at.x, _ground(at) , at.z)
			_still = _still + dt if hips.linear_velocity.length() < REST_MPS else 0.0
			if player.is_dead:
				return
			if (_t >= MIN_S and _still >= REST_S) or _t >= MAX_S:
				_lay_getup()
		"blend":
			sim.influence = 1.0 - smoothstep(0.0, BLEND_S, _t)
			_blender.show_clip(clip, 0.0, 0.0, 1.0)
			_blender.update(dt)
			if _t >= BLEND_S:
				sim.physical_bones_stop_simulation()
				sim.active = false
				phase = "getup"
				_t = 0.0
				_clip_t = 0.0
		"getup":
			_clip_t += dt
			var length := _ap.get_animation("%s/%s" % [LIB, clip]).length
			_blender.show_clip(clip, minf(_clip_t, length), 0.0, 1.0)
			_blender.update(dt)
			if _clip_t >= length:
				_finish()


## The ground under `at` (a ray down), or its own height.
func _ground(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 4.0)
	q.exclude = [player.get_rid()]
	for pb in bodies.values():
		q.exclude.append((pb as PhysicalBone3D).get_rid())
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	return (r.position as Vector3).y if not r.is_empty() else at.y - 0.15


## At rest: the get-up clip that starts lying most like the body, laid where the body lies; the fade into it begins.
func _lay_getup() -> void:
	var sk_global := skeleton.global_transform
	var chest := sk_global.basis * skeleton.get_bone_global_pose(skeleton.find_bone("spined")).basis
	var front := (chest * (_front_rest.front as Vector3)).normalized()
	var left := (chest * (_front_rest.left as Vector3)).normalized()
	var root_w := sk_global * skeleton.get_bone_global_pose(skeleton.find_bone("root")).origin
	var head_w := sk_global * skeleton.get_bone_global_pose(skeleton.find_bone("heada")).origin
	# the clip whose first frame lies most like it: facing up or down, which side up
	var best := ""
	var best_d := INF
	var lib := _ap.get_animation_library(LIB)
	for c: String in GETUPS:
		var a := lib.get_animation(c) if lib else null
		if a == null:
			continue
		var f := _clip_frame(a)
		var d := absf(front.y - f.front.y) + absf(left.y - f.left.y)
		if d < best_d:
			best_d = d
			best = c
	if best == "":
		_finish()
		return
	clip = best
	var f := _clip_frame(lib.get_animation(clip))
	# the player turned so the clip's line from hips to head lies along the body's, moved so the hips meet
	var skel_in_p := player.global_transform.affine_inverse() * sk_global
	var axis_c: Vector3 = skel_in_p.basis * (f.head - f.root)
	var axis_w := head_w - root_w
	axis_c.y = 0.0
	axis_w.y = 0.0
	var yaw := player.rotation.y
	if axis_c.length() > 0.05 and axis_w.length() > 0.05:
		yaw = atan2(axis_w.x, axis_w.z) - atan2(axis_c.x, axis_c.z)
	var b := Basis(Vector3.UP, yaw)
	var hip_p: Vector3 = skel_in_p * (f.root as Vector3)
	var at := root_w - b * Vector3(hip_p.x, 0.0, hip_p.z)
	at.y = _ground(root_w)
	player.global_transform = Transform3D(b, at)
	_blender = HorsePhaseBlender.new(_ap, player, LIB)
	_blender.show_clip(clip, 0.0, 0.0, 1.0)
	_blender.update(0.0)
	phase = "blend"
	_t = 0.0


## The first frame of get-up clip `a`: the chest's facing and left side, the hips and the head (skeleton space), from the
## clip's keys at 0 (the rest where a channel has none).
func _clip_frame(a: Animation) -> Dictionary:
	var chest := _clip_global(a, skeleton.find_bone("spined"))
	return {
		"front": (chest.basis * (_front_rest.front as Vector3)).normalized(),
		"left": (chest.basis * (_front_rest.left as Vector3)).normalized(),
		"root": _clip_global(a, skeleton.find_bone("root")).origin,
		"head": _clip_global(a, skeleton.find_bone("heada")).origin,
	}


func _clip_global(a: Animation, bone: int) -> Transform3D:
	var chain: Array[int] = []
	var b := bone
	while b >= 0:
		chain.push_front(b)
		b = skeleton.get_bone_parent(b)
	var x := Transform3D()
	for bi in chain:
		var rest := skeleton.get_bone_rest(bi)
		var pos := rest.origin
		var rot := rest.basis.get_rotation_quaternion()
		var nm := skeleton.get_bone_name(bi)
		var tp := a.find_track(NodePath("Skeleton3D:" + nm), Animation.TYPE_POSITION_3D)
		if tp >= 0 and a.track_get_key_count(tp) > 0:
			pos = a.position_track_interpolate(tp, 0.0)
		var tr := a.find_track(NodePath("Skeleton3D:" + nm), Animation.TYPE_ROTATION_3D)
		if tr >= 0 and a.track_get_key_count(tr) > 0:
			rot = a.rotation_track_interpolate(tr, 0.0)
		x = x * Transform3D(Basis(rot), pos)
	return x


## Up at once, however the body lies (user 2026-09-28: "grabbing while down should be okay to mount": G at a wild
## horse from the ground takes its mane and swings him up onto it, HorseBreaking): the ragdoll and the get-up end now.
func recover_now() -> void:
	if phase != "":
		_finish()


func _finish() -> void:
	if sim and sim.active:
		sim.physical_bones_stop_simulation()
		sim.active = false
	phase = ""
	clip = ""
	_blender = null
	if player and player.kneeling == self:
		player.end_kneel()
	up.emit()
