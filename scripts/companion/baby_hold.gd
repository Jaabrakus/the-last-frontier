class_name BabyHold
extends SkeletonModifier3D
## Holding a baby, on any Actor_B skeleton (the wife's, the husband's, a worker's, the player's): the upper body takes a hold
## pose over whatever the legs are playing (idle, walk, sit, kneel), added to the skeleton by code (BabyHold.attach), faded in
## and out with `influence`. Data: data/companion/baby.json "poses" and "hold".
##
## The poses (the chest frame: the spined bone's origin, +x the holder's left, +y up, +z the way the rig faces; a hold on the
## right arm mirrors x):
##   cradle    the baby in the crook of the near arm, the forearm across the body, the other hand under it
##   shoulder  over the shoulder, upright against the chest, head on the near shoulder (a settled baby, burping)
##   feed      seated feeding: the baby close at the chest under a shawl (a modest clothed cradle hold)
##   reach     the baby at a world point (reach_to()): laying down, taking up, handing over; the spine leans to it
## Each pose says where the baby lies and where the two hands are ON the baby (in the baby's own frame), so the hands end on
## the baby whatever the pose; a two-bone IK puts each wrist there (the elbow toward the pole hint), the palm turned to the
## baby. On top of the pose: the spine and head, a sway in the body while walking (in step, by speed), a slow weight shift and
## breathing, and the rock (the soothing sway, `rocking`).
## The baby rides `hold`, a Node3D under a BoneAttachment3D on the chest bone that this moves to the pose's baby transform.
##   var h := BabyHold.attach(skeleton); h.engage("cradle", side); h.speed = ...; h.reach_to(point); h.release()

signal settled(engaged: bool)   ## the fade in (true) or out (false) finished

const ARM := {"l": ["l_shoulder", "l_elbow", "l_wrist"], "r": ["r_shoulder", "r_elbow", "r_wrist"]}
const FINGER_BONES := {"l": ["l_middle_metacarpal", "l_thumba", "l_pinkya"], "r": ["r_middle_metacarpal", "r_thumba", "r_pinkya"]}
const SPINE := ["spinea", "spineb", "spinec"]
const CHEST := "spined"
const SHOULDER_ARM := 0.36   ## spinea to the shoulders
const ARM_BEND := 0.34      ## how far the shoulders stay from a point being reached (the arm bent)
const NECK := ["neck", "heada"]

## The pose in force and which arm is the near one (+1 the left arm cradles, -1 the right).
var pose_name := "cradle"
var side := 1.0
## The holder's ground speed (m/s): the walking sway.
var speed := 0.0
## Rocking the baby (the soothing sway).
var rocking := false
## The world point `reach` puts the baby at (reach_to()).
var reach_point := Vector3.ZERO
## Set false to see the pose without the sway (tests).
var alive_motion := true
## Where the baby rides (a child of `attachment`), set by attach().
var hold: Node3D
var attachment: BoneAttachment3D
## The last pose computed, for tests and the look: {near, far (wrist targets, skeleton space), near_wrist, far_wrist (the wrists after the
## IK), baby (skeleton space transform), reach_ok}.
var last := {}

var _engaged := false
var _w := 0.0
var _from := {}
var _to := {}
var _pb := 1.0
var _t := 0.0
var _phase := 0.0
var _rock := 0.0
var _rw := 0.0   ## how far the reach has gone out (0..1)
var _ids := {}
var _rest := {}
var _palm := {}
var _ready_bones := false
var _cfg := {}


static func cfg() -> Dictionary:
	return BabyCare.cfg()


## Adds a hold modifier (and the baby's mount) under `sk`. Null when the skeleton lacks the bones.
static func attach(sk: Skeleton3D) -> BabyHold:
	if sk == null:
		return null
	for b: String in [CHEST, "spinea", "l_shoulder", "l_elbow", "l_wrist", "r_shoulder", "r_elbow", "r_wrist", "heada"]:
		if sk.find_bone(b) < 0:
			return null
	var old := sk.get_node_or_null("BabyHold") as BabyHold
	if old != null:
		return old
	var h := BabyHold.new()
	h.name = "BabyHold"
	h.active = false
	h.influence = 0.0
	sk.add_child(h)   # the last child: after the other modifiers
	h.attachment = BoneAttachment3D.new()
	h.attachment.name = "BabyMount"
	sk.add_child(h.attachment)
	h.attachment.bone_name = CHEST
	h.hold = Node3D.new()
	h.hold.name = "Hold"
	h.attachment.add_child(h.hold)
	return h


## Takes the hold away again (the modifier, the mount, and the baby if it is still in it: the caller has moved it).
func detach() -> void:
	if attachment != null and is_instance_valid(attachment):
		attachment.queue_free()
	queue_free()


# ---------------------------------------------------------------- driving it
## Begins the hold in `pose` on the near arm `near_side` (+1 left, -1 right). `snap`: no fade.
func engage(pose := "cradle", near_side := 1.0, snap := false) -> void:
	side = -1.0 if near_side < 0.0 else 1.0
	if not _engaged:
		_from = _resolve(pose)
		_pb = 1.0
		_engaged = true
		active = true
		if snap:
			_w = 1.0
			influence = 1.0
	else:
		set_pose(pose)
	pose_name = pose
	_to = _resolve(pose)


## Changes the pose (a blend of pose_blend seconds).
func set_pose(pose: String) -> void:
	if pose == pose_name and _pb >= 1.0:
		return
	_from = _current()
	pose_name = pose
	_to = _resolve(pose)
	_pb = 0.0


## The hands go out with the baby to a world point.
func reach_to(world_point: Vector3) -> void:
	reach_point = world_point
	if pose_name != "reach":
		set_pose("reach")


## Fades the hold out.
func release() -> void:
	_engaged = false


func engaged() -> bool:
	return _engaged


func weight() -> float:
	return _w


## Blend times and motion numbers from the data.
func _h(key: String, dflt: float) -> float:
	return float((cfg().get("hold", {}) as Dictionary).get(key, dflt))


func _process(dt: float) -> void:
	_t += dt
	var goal := 1.0 if _engaged else 0.0
	if not is_equal_approx(_w, goal):
		var was := _w
		_w = move_toward(_w, goal, dt / maxf(_h("blend_in", 0.5) if _engaged else _h("blend_out", 0.45), 0.05))
		influence = smoothstep(0.0, 1.0, _w)
		if is_equal_approx(_w, goal) and not is_equal_approx(was, goal):
			if not _engaged:
				active = false
			settled.emit(_engaged)
	if _pb < 1.0:
		_pb = minf(_pb + dt / maxf(_h("pose_blend", 0.4), 0.05), 1.0)
	_rw = move_toward(_rw, 1.0 if pose_name == "reach" else 0.0, dt / maxf(_h("pose_blend", 0.4), 0.05))
	_phase += speed * _h("step_hz_per_ms", 0.75) * dt
	_rock = move_toward(_rock, 1.0 if rocking else 0.0, dt * 1.5)


# ---------------------------------------------------------------- the poses as numbers
## A pose from the data, resolved for the arm in use: {baby_pos, baby_basis, near_on, near_pole, far_on, far_pole, pitch, roll,
## yaw, hpitch, hyaw, hroll, shawl}. Positions and vectors in the chest frame (mirrored for a right-arm hold); hand points
## are already in the chest frame (the baby's frame carried over).
func _resolve(pose: String) -> Dictionary:
	var poses: Dictionary = cfg().get("poses", {})
	var p: Dictionary = poses.get(pose, poses.get("cradle", {}))
	var mir := Vector3(side, 1.0, 1.0)
	var b: Dictionary = p.get("baby", {})
	var pos := _v(b.get("pos", [0, -0.15, 0.2])) * mir
	var head := (_v(b.get("head", [1, 0, 0])) * mir).normalized()
	var face := (_v(b.get("face", [0, 1, 0])) * mir)
	face = (face - head * face.dot(head)).normalized()
	var basis := Basis(head, face, head.cross(face))
	var out := {"baby_pos": pos, "baby_basis": basis}
	for k: String in ["near", "far"]:
		var hd: Dictionary = p.get(k, {})
		out[k + "_on"] = pos + basis * _v(hd.get("on", [0, -0.07, 0]))
		out[k + "_pole"] = (_v(hd.get("pole", [side * 0.5, -1, 0])) * mir).normalized()
	var sp: Dictionary = p.get("spine", {})
	var hp: Dictionary = p.get("head", {})
	out["pitch"] = float(sp.get("pitch", 0.0))
	out["roll"] = float(sp.get("roll", 0.0)) * side
	out["yaw"] = float(sp.get("yaw", 0.0)) * side
	out["hpitch"] = float(hp.get("pitch", 0.0))
	out["hyaw"] = float(hp.get("yaw", 0.0)) * side
	out["hroll"] = float(hp.get("roll", 0.0)) * side
	out["shawl"] = bool(p.get("shawl", false))
	return out


static func _v(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and (a as Array).size() >= 3 else Vector3.ZERO


## The blend in force now.
func _current() -> Dictionary:
	if _to.is_empty():
		return _resolve(pose_name)
	if _pb >= 1.0:
		return _to
	return _mix(_from if not _from.is_empty() else _to, _to, smoothstep(0.0, 1.0, _pb))


static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var o := {}
	for k: String in b:
		var va: Variant = a.get(k, b[k])
		var vb: Variant = b[k]
		if vb is Vector3:
			o[k] = (va as Vector3).lerp(vb, t)
		elif vb is Basis:
			o[k] = Basis((va as Basis).get_rotation_quaternion().slerp((vb as Basis).get_rotation_quaternion(), t))
		elif vb is float:
			o[k] = lerpf(float(va), float(vb), t)
		else:
			o[k] = vb if t >= 0.5 else va
	return o


# ---------------------------------------------------------------- the pose on the skeleton
func _init_bones(sk: Skeleton3D) -> bool:
	if _ready_bones:
		return true
	var names := [CHEST, "spinea", "spineb", "spinec", "neck", "heada", "lower_base", "upper_base", "l_upper_leg", "l_knee", "l_ankle", "r_upper_leg", "r_knee", "r_ankle"]
	for a: String in ARM:
		names.append_array(ARM[a])
		names.append_array(FINGER_BONES[a])
	for n: String in names:
		var i := sk.find_bone(n)
		if i < 0:
			return false
		_ids[n] = i
	# the palm's normal and the hand's own line, in the wrist bone's frame, from the rest pose (the palm faces in at rest)
	for a: String in ARM:
		var wr_i: int = _ids[ARM[a][2]]
		var wg := sk.get_bone_global_rest(wr_i)
		var fb: Array = FINGER_BONES[a]
		var along := (sk.get_bone_global_rest(_ids[fb[0]]).origin - wg.origin).normalized()
		var across := (sk.get_bone_global_rest(_ids[fb[1]]).origin - sk.get_bone_global_rest(_ids[fb[2]]).origin).normalized()
		var n := along.cross(across).normalized()
		if n.x * (1.0 if a == "l" else -1.0) > 0.0:
			n = -n   # the palm's normal is the one facing the body at rest: toward -x for the left hand, +x for the right
		_palm[a] = [wg.basis.inverse() * n, wg.basis.inverse() * along]
	_rest["chest"] = sk.get_bone_global_rest(_ids[CHEST]).basis
	_ready_bones = true
	return true


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _w <= 0.0 or not _init_bones(sk):
		return
	var cfg_h: Dictionary = cfg().get("hold", {})
	var cur := _current()
	var mot := 1.0 if alive_motion else 0.0
	# ---- the body's life: walking sway (in step), weight shift, breathing, rocking
	var sway := clampf(speed * float(cfg_h.get("sway_deg_per_ms", 1.4)), 0.0, float(cfg_h.get("sway_max_deg", 2.4))) * mot
	var roll := sin(TAU * _phase) * sway
	var bob := absf(sin(TAU * _phase)) * float(cfg_h.get("bob_m", 0.006)) * clampf(speed, 0.0, 1.5) * mot
	var shift := sin(TAU * _t * float(cfg_h.get("weight_shift_hz", 0.09))) * float(cfg_h.get("weight_shift_deg", 0.9)) * mot
	var breath := sin(TAU * _t * float(cfg_h.get("breath_hz", 0.28))) * float(cfg_h.get("breath_m", 0.004)) * mot
	var rk := sin(TAU * _t * float(cfg_h.get("rock_hz", 0.85))) * _rock * mot
	roll += rk * float(cfg_h.get("rock_deg", 4.5)) + shift
	var lift := Vector3(0.0, bob + breath + rk * float(cfg_h.get("rock_bob_m", 0.014)), 0.0)
	# ---- the spine: the pose's lean, and for `reach` the lean to the point
	var pitch := float(cur.pitch) + breath * 40.0
	var yaw := float(cur.yaw)
	var rroll := float(cur.roll) + roll
	var q_total := Quaternion(Vector3.UP, deg_to_rad(yaw)) * Quaternion(Vector3.BACK, deg_to_rad(-rroll)) * Quaternion(Vector3.RIGHT, deg_to_rad(pitch))
	var reach_w := smoothstep(0.0, 1.0, _rw)
	var reach_sk := Vector3.ZERO
	if reach_w > 0.0:
		reach_sk = sk.global_transform.affine_inverse() * reach_point
		var pivot0 := sk.get_bone_global_pose(_ids[SPINE[0]]).origin
		var plan := _reach_plan(reach_sk, pivot0, cfg_h)
		_squat(sk, plan.x * reach_w)
		var pivot := sk.get_bone_global_pose(_ids[SPINE[0]]).origin
		var lean := _lean_to(reach_sk, pivot, plan.y * reach_w, cfg_h)
		q_total = lean * q_total
	# ---- upright: whatever the clip under the hold does with the back (a work crouch, a hunched sitting clip), the chest is brought
	# back toward upright (hold.upright of the way; not while reaching), so the baby is held, and seen, at the chest
	var up_w := float(cfg_h.get("upright", 0.8)) * (1.0 - reach_w)
	if up_w > 0.0:
		var tc0 := sk.get_bone_global_pose(_ids[CHEST])
		var d0: Basis = tc0.basis.orthonormalized() * (_rest.chest as Basis).orthonormalized().inverse()
		var up_now := (d0 * Vector3.UP).normalized()
		if up_now.dot(Vector3.UP) < 0.9995:
			q_total = Quaternion.IDENTITY.slerp(Quaternion(up_now, Vector3.UP), up_w) * q_total
	var shares: Dictionary = cfg_h.get("spine_share", {"spinea": 0.4, "spineb": 0.3, "spinec": 0.3})
	for n: String in SPINE:
		var i: int = _ids[n]
		var g := sk.get_bone_global_pose(i)
		var q := Quaternion.IDENTITY.slerp(q_total, float(shares.get(n, 0.33)))
		sk.set_bone_global_pose(i, Transform3D(Basis(q) * g.basis, g.origin))
	var hp := deg_to_rad(float(cur.hpitch))
	for n: String in NECK:
		var i: int = _ids[n]
		var g := sk.get_bone_global_pose(i)
		var q := Quaternion(Vector3.UP, deg_to_rad(float(cur.hyaw)) * 0.5) * Quaternion(Vector3.RIGHT, hp * 0.5) \
				* Quaternion(Vector3.BACK, deg_to_rad(-float(cur.hroll)) * 0.5)
		sk.set_bone_global_pose(i, Transform3D(Basis(q) * g.basis, g.origin))
	# ---- the chest frame after the lean
	var tc := sk.get_bone_global_pose(_ids[CHEST])
	var delta: Basis = tc.basis * (_rest.chest as Basis).inverse()
	var chest := Transform3D(delta, tc.origin)
	# the baby and the hands (a reach: the baby's place is the point, in the chest frame)
	var baby_pos: Vector3 = cur.baby_pos
	var baby_basis: Basis = cur.baby_basis
	var near_on: Vector3 = cur.near_on
	var far_on: Vector3 = cur.far_on
	if reach_w > 0.0:
		var want := chest.affine_inverse() * reach_sk
		var shift_v := (want - baby_pos) * reach_w
		baby_pos += shift_v
		near_on += shift_v
		far_on += shift_v
	baby_pos += lift
	near_on += lift
	far_on += lift
	var baby_sk := Transform3D(delta * baby_basis, chest * baby_pos)
	if rocking or _rock > 0.01:
		baby_sk.basis = Basis(Quaternion(Vector3.BACK, deg_to_rad(rk * 2.5))) * baby_sk.basis
	var near := "l" if side > 0.0 else "r"
	var far := "r" if side > 0.0 else "l"
	var ik_near := _arm(sk, near, chest * near_on, delta * (cur.near_pole as Vector3), baby_sk.origin, cfg_h)
	var ik_far := _arm(sk, far, chest * far_on, delta * (cur.far_pole as Vector3), baby_sk.origin, cfg_h)
	last = {"near": chest * near_on, "far": chest * far_on, "near_wrist": ik_near, "far_wrist": ik_far, "baby": baby_sk,
			"chest": chest, "shawl": bool(cur.shawl)}
	# the mount: the baby's transform relative to the chest bone (BoneAttachment3D follows that bone)
	if hold != null and is_instance_valid(hold):
		hold.transform = tc.affine_inverse() * baby_sk


## How the body goes to a point: [squat depth (m the hips go down, the knees bending), lean (rad)]: of the ways that put the shoulders
## within an arm's bend of it, the cheapest (a lean from the hips costs less than a squat); when none does, the nearest.
func _reach_plan(p: Vector3, pivot0: Vector3, ch: Dictionary) -> Vector2:
	var d := p - pivot0
	var flat := Vector3(d.x, 0.0, d.z)
	var dir := flat.normalized() if flat.length() > 0.02 else Vector3.BACK
	var top := deg_to_rad(float(ch.get("reach_deg_max", 58.0)))
	var best := Vector2(0.0, 0.0)
	var best_cost := 1e9
	var near := Vector2(0.0, 0.0)
	var near_d := 1e9
	for di in 11:
		var depth := 0.05 * float(di)
		var pivot := pivot0 - Vector3(0.0, depth, 0.0)
		for i in 31:
			var a := top * float(i) / 30.0
			var sh := pivot + (Vector3.UP * cos(a) + dir * sin(a)) * SHOULDER_ARM
			var dist := sh.distance_to(p)
			if dist <= ARM_BEND:
				var cost := depth + a * 0.6
				if cost < best_cost:
					best_cost = cost
					best = Vector2(depth, a)
			if dist < near_d:
				near_d = dist
				near = Vector2(depth, a)
	return best if best_cost < 1e8 else near


## The lean of the spine toward `p` by `angle`, plus a share of the turn toward it.
func _lean_to(p: Vector3, pivot: Vector3, angle: float, _ch: Dictionary) -> Quaternion:
	var d := p - pivot
	var flat := Vector3(d.x, 0.0, d.z)
	if flat.length() < 0.02:
		flat = Vector3.BACK
	var dir := flat.normalized()
	var axis := Vector3.UP.cross(dir).normalized()
	var ang := Vector3.BACK.signed_angle_to(dir, Vector3.UP)
	var turn := clampf(ang, -deg_to_rad(50.0), deg_to_rad(50.0)) * 0.5
	return Quaternion(Vector3.UP, turn) * Quaternion(axis, angle)


## Squats: the pelvis goes down `depth` and both legs bend (knees forward) with the feet where the animation has them.
func _squat(sk: Skeleton3D, depth: float) -> void:
	if depth < 0.005:
		return
	var feet := {}
	for a: String in ["l", "r"]:
		var ai: int = _ids[a + "_ankle"]
		feet[a] = sk.get_bone_global_pose(ai)
	# the rig has two roots for the body: lower_base (the pelvis and legs) and upper_base (the spine, arms, head): both go down
	for n: String in ["lower_base", "upper_base"]:
		var bi: int = _ids[n]
		var bg := sk.get_bone_global_pose(bi)
		sk.set_bone_global_pose(bi, Transform3D(bg.basis, bg.origin - Vector3(0.0, depth, 0.0)))
	for a: String in ["l", "r"]:
		var ft: Transform3D = feet[a]
		_two_bone(sk, _ids[a + "_upper_leg"], _ids[a + "_knee"], _ids[a + "_ankle"], ft.origin, Vector3.BACK, 0.999)
		sk.set_bone_global_pose(_ids[a + "_ankle"], ft)


## Puts a wrist at `target` (skeleton space) with the elbow toward `pole`, and turns the palm to `toward` (the baby). Returns the
## wrist's skeleton-space pose after it.
func _arm(sk: Skeleton3D, a: String, target: Vector3, pole: Vector3, toward: Vector3, ch: Dictionary) -> Transform3D:
	var names: Array = ARM[a]
	var wi: int = _ids[names[2]]
	var w3 := _two_bone(sk, _ids[names[0]], _ids[names[1]], wi, target, pole, float(ch.get("ik_slack", 0.985)))
	# the palm to the baby: a roll about the hand's own line
	var pl: Array = _palm[a]
	var n_cur := (w3.basis * (pl[0] as Vector3)).normalized()
	var line := (w3.basis * (pl[1] as Vector3)).normalized()
	var want := toward - w3.origin
	want = want - line * want.dot(line)
	if want.length() > 0.001:
		var nc := n_cur - line * n_cur.dot(line)
		var ang := nc.normalized().signed_angle_to(want.normalized(), line)
		w3.basis = Basis(Quaternion(line, ang)) * w3.basis
	sk.set_bone_global_pose(wi, w3)
	return w3


## Two-bone IK on the chain si, ei, wi (shoulder, elbow, wrist / hip, knee, ankle): the end to `target` (clamped to the reach times
## `slack`), the middle joint toward `pole`. Writes the first two bones; returns the end's pose after them (not written).
func _two_bone(sk: Skeleton3D, si: int, ei: int, wi: int, target: Vector3, pole: Vector3, slack: float) -> Transform3D:
	var s := sk.get_bone_global_pose(si)
	var e := sk.get_bone_global_pose(ei)
	var w := sk.get_bone_global_pose(wi)
	var l1 := (e.origin - s.origin).length()
	var l2 := (w.origin - e.origin).length()
	var d := target - s.origin
	var dist := clampf(d.length(), absf(l1 - l2) + 0.02, (l1 + l2) * slack)
	var dn := d.normalized() if d.length() > 0.001 else Vector3.FORWARD
	var reach := s.origin + dn * dist
	var along := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var hgt := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var pp := pole - dn * pole.dot(dn)
	pp = pp.normalized() if pp.length() > 0.001 else Vector3.DOWN.cross(dn).normalized()
	var elbow := s.origin + dn * along + pp * hgt
	# the first bone turns the upper limb onto the elbow, the second the lower onto the target
	var s2 := Transform3D(Basis(_swing(e.origin - s.origin, elbow - s.origin)) * s.basis, s.origin)
	sk.set_bone_global_pose(si, s2)
	var e2 := s2 * (s.affine_inverse() * e)
	var w2 := e2 * (e.affine_inverse() * w)
	var e3 := Transform3D(Basis(_swing(w2.origin - e2.origin, reach - e2.origin)) * e2.basis, e2.origin)
	sk.set_bone_global_pose(ei, e3)
	return e3 * (e.affine_inverse() * w)


static func _swing(from: Vector3, to: Vector3) -> Quaternion:
	var f := from.normalized()
	var t := to.normalized()
	var c := f.cross(t)
	if c.length() < 0.00001:
		return Quaternion.IDENTITY if f.dot(t) > 0.0 else Quaternion(f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized(), PI)
	return Quaternion(c.normalized(), f.angle_to(t))
