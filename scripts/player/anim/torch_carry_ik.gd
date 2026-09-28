class_name TorchCarryIK
extends ReachIK
## The hand torch, in either hand (push n01b; reworked by push n01c, user 2026-09-26: "the torch should be like the
## ace hold", "lets do 2 and 3" (2: a raised hold beside the shoulder, the flame above the head; 3: the one-hand
## grip the tomahawk uses), "axe hold", then "the right hand holds the torch and the left hand holds the gun").
##
## Which hand: HandHolds decides (`side`: "r" with a long gun, the bow, hands free; "l" with the pistol and the
## thrown weapons) and passes the torch between the hands (pass_to(), PASS_S). The arms come from source clips
## first (HandHolds sets the arm poses through LeftArmPose / RightArmPose): the axe hold is the tomahawk's own
## one-hand carry (THROW2's hatchet carry: the source's one-hand melee carry arm actor_b-p-knife--arm under the knife
## ready arm, over the locomotion's own swing), the raised hold the source's one-hand throw raise
## (actor_b-p-1h-aim-throw^aim, THROW2's javelin carry: the hand above and a little in front of the shoulder, the
## elbow out), both mirrored onto the left arm there; the fist is the tomahawk's knife grip (GRIP_CLIP: the fist round
## the haft, the prop bone in it with the haft along +Y), mirrored for the left hand. This modifier then:
##  - puts the torch's prop bone in the fist as that grip has it;
##  - turns the torch toward upright (axe_tilt_deg forward of vertical and axe_out_deg out from the leg; raised:
##    raise_tilt_deg / raise_out_deg; in the player's facing), at most MAX_TURN_DEG at the wrist, and moves the fist
##    `anchor_weight` of the way from the source pose to its place: the axe hold's `axe_fist` from the pelvis (beside
##    and a little in front of the hip, the arm hanging with the elbow a little bent), the raised hold's `raise_fist`
##    from the shoulder; `upright` (0..1) lets the source pose through (the toss);
##  - places the torch (place_socket(), from HandPropsFinal after every arm modifier): `socket` (a Node3D on the
##    skeleton, PlayerTorch's model under it) takes the fist's grip frame times HAND_OFFSET, and through a pass it goes
##    from one fist to the other where they meet in front of the belly. With `gun_fist` the left fist also holds the
##    long gun (GunMiddleCarryIK owns that arm): a pass to or from the left hand then puts the torch in that fist
##    beside the gun (GUN_FIST_OFFSET: the handle crossing the gun on its outer side, the head up), the exchange of a
##    weapon switch (HandHolds): the two things change hands through the left fist.
## Order: after LeftArmPose / RightArmPose, before GunCarryDamper, LeftGripIK and GunMiddleCarryIK; the placement last.

const FADE_S := 0.2
## The tomahawk's one-hand grip (THROW2 knife_grip: the first frame of the knife ready pose): the fingers and the
## right prop bone, the haft along the prop's +Y. The left hand takes it mirrored (MIRROR_PROP).
const GRIP_CLIP := "atk-actor_b-knife-v-thug-hit1-intro"
## The torch model on the hand's prop bone: its head (the model's -Z) up the haft's way (+Y), the fist on its grip.
const HAND_OFFSET := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
## A right prop rotation mirrored onto the left prop: MIRROR_PROP * (x, -y, -z, w) (Actor_B's rest: the left prop's
## global rest is the right one's mirrored, its parent palm's the right palm's mirrored and turned half about X).
const MIRROR_PROP := Quaternion(-1.0, 0.0, 0.0, 0.0)
## Largest correction of the torch's axis at the wrist (deg); a larger one is only partly made.
const MAX_TURN_DEG := 150.0
## The torch follows its target through a critically damped spring (rad/s; positions relative to the root bone): the
## source keys its locomotion at 10-15 Hz, so the target's velocity jumped at every key.
const TORCH_FREQ := 16.0
const STEP_S := 1.0 / 240.0
## The fist stays within this fraction of the arm's length from the shoulder, eased over the last REACH_SOFT_M (m).
const REACH_FRAC := 0.97
const REACH_SOFT_M := 0.06
## A pass from one hand to the other (s): the fists meet in front of the belly (PASS_MEET from the pelvis: x out to
## the character's left, y up, z forward), the giving fist holds the torch lower, the taking one PASS_GAP_M above it.
const PASS_S := 0.32
const PASS_MEET := Vector3(0.0, 0.12, 0.3)
const PASS_GAP_M := 0.09
## The torch in the left fist beside the long gun, in the gun's frame at the fist (gun_fist_frame: +Z along the barrel,
## +Y up the gun, the origin on its middle line): the handle up across the gun's outer side, the head up and a little
## forward.
const GUN_FIST_OFFSET := Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(15.0)), Vector3(0.045, 0.0, -0.02))
## The giving / taking right fist this far above the left gun fist at the meeting (m).
const GUN_FIST_LIFT := Vector3(-0.02, 0.1, 0.02)

## The torch wanted in the hand (HandHolds, every frame) and its weight after the fade.
var torch_on := false
var torch_weight := 0.0
## The hand holding it ("r" / "l"); during a pass the hand it goes to.
var side := "r"
## A pass: the hand it comes from ("" = none) and its progress 0..1.
var pass_from := ""
var pass_t := 0.0
## How much of the upright / placement correction applies (1 holding; HandHolds lowers it through the toss).
var upright := 1.0
## The fade in use (FADE_S unless the caller sets a quicker one: the toss lets go fast).
var fade_s := FADE_S
## 0 standing .. 1 crouched; 0 axe hold .. 1 raised (hold T). Eased by HandHolds.
var crouch := 0.0
var raise := 0.0

## Tunables (PlayerAnim's "Torch" exports; x out to the torch hand's side, y up, z forward, in the player's facing).
var axe_tilt_deg := 30.0
var axe_out_deg := 14.0
var axe_fist := Vector3(0.28, -0.1, 0.24)
var axe_fist_crouch := Vector3(0.3, 0.06, 0.24)
var raise_tilt_deg := 15.0
var raise_out_deg := 8.0
var raise_fist := Vector3(0.12, 0.08, 0.36)
var anchor_weight := 0.8

## The torch's node (a skeleton child; PlayerTorch puts the model under it).
var socket: Node3D
## Each hand's share of its hold (HandHolds eases it in after restart_hand(): a fist taking over the torch).
var hand_in := {"l": 1.0, "r": 1.0}
## The left fist holds the long gun too (GunMiddleCarryIK owns the left arm): passes to and from the left hand go
## through that fist, and a torch on the left rides in it beside the gun.
var gun_fist := false
## gun_fist eased (0..1 over GUN_FIST_BLEND_S): the torch goes between its place beside the gun and the fist's own
## grip over it (the fist lets go of the gun and takes the torch alone), no jump.
var gun_fist_blend := 0.0
const GUN_FIST_BLEND_S := 0.15
## The left fist's grip frame last frame (GunMiddleCarryIK's left prop, skeleton space): where the right fist meets it.
var gun_fist_frame := Transform3D()

## Last frame's measures (tests, the debug view; skeleton space): the torch's axis (unit, toward the head), its grip,
## the flame (TorchModels' Flame marker), the fist from the pelvis in the player's facing (x out to the torch hand's
## side), the wrist's correction.
var last_torch_axis := Vector3.UP
var last_grip := Vector3.ZERO
var last_flame := Vector3.ZERO
var last_fist := Vector3.ZERO
var last_torch_turn_deg := 0.0

var grip_anim: Animation
var _tracks := {}                      ## "r" -> [position track, rotation track] of the right prop in grip_anim
var _ids := {}
var _have_ids := false
var _dt := 0.0
var _springs := {"l": Spring.new(), "r": Spring.new()}
var _fresh := {"l": false, "r": false}
## Each fist's turn about the handle (rad; ArmSolve.roll_toward, eased at ROLL_RATE 1/s).
const ROLL_RATE := 14.0
var _rolls := {"l": {"r": 0.0, "have": false}, "r": {"r": 0.0, "have": false}}
## How place_socket() puts the torch this frame: [from side, to side, blend 0..1 from -> to, gap of `to`]
var _recipe := ["r", "r", 1.0, 0.0]
var _placed := false


## A critically damped spring on a transform (position and rotation), stepped once per animation step.
class Spring:
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var q := Quaternion.IDENTITY
	var w := Vector3.ZERO
	var have := false

	func step(tp: Vector3, tq: Quaternion, dt: float, freq: float, step_s := TorchCarryIK.STEP_S) -> void:
		if not have:
			p = tp
			q = tq
			v = Vector3.ZERO
			w = Vector3.ZERO
			have = true
			return
		if dt <= 0.0:
			return
		var n := maxi(int(ceil(dt / step_s)), 1)
		var h := dt / n
		for i in n:
			v += (freq * freq * (tp - p) - 2.0 * freq * v) * h
			p += v * h
			var e := q.inverse() * tq
			if e.w < 0.0:
				e = -e
			var ang := 2.0 * acos(clampf(e.w, -1.0, 1.0))
			var ev := Vector3(e.x, e.y, e.z).normalized() * ang if ang > 1e-6 else Vector3.ZERO
			w += (freq * freq * ev - 2.0 * freq * w) * h
			var wl := w.length() * h
			if wl > 1e-9:
				q = (q * Quaternion(w.normalized(), wl)).normalized()


## Sets the grip clip (the AnimationPlayer's library animation).
func set_grip(anim: Animation) -> void:
	grip_anim = anim
	_tracks = {}


func advance(dt: float) -> void:
	# the springs take the animation time since the skeleton last updated
	_dt += maxf(dt, 0.0)
	torch_weight = move_toward(torch_weight, 1.0 if torch_on else 0.0, dt / maxf(fade_s, 1e-3))
	gun_fist_blend = move_toward(gun_fist_blend, 1.0 if gun_fist else 0.0, dt / GUN_FIST_BLEND_S)
	if pass_from != "":
		pass_t = move_toward(pass_t, 1.0, dt / PASS_S)
		if pass_t >= 1.0:
			pass_from = ""
			pass_t = 0.0


## Takes the wanted weight at once.
func snap() -> void:
	torch_weight = 1.0 if torch_on else 0.0
	pass_from = ""
	pass_t = 0.0
	for s: Spring in _springs.values():
		s.have = false


## Starts passing the torch to the other hand (`to`); nothing when it is already there or a pass is running.
func pass_to(to: String) -> void:
	if to == side or pass_from != "":
		return
	pass_from = side
	side = to
	pass_t = 0.0


func passing() -> bool:
	return pass_from != ""


## Hand `s` takes over the torch from where its fist is now: its share eases in (hand_in) and its spring starts at the
## fist (no pop).
func restart_hand(s: String) -> void:
	hand_in[s] = 0.0
	_fresh[s] = true


func _process_modification() -> void:
	_placed = false
	var sk := get_skeleton()
	if sk == null or torch_weight <= 0.0:
		for s: Spring in _springs.values():
			s.have = false
		_dt = 0.0
		return
	if not _have_ids and not _find(sk):
		return
	var w := smoothstep(0.0, 1.0, torch_weight)
	if pass_from == "":
		if not (side == "l" and gun_fist):
			_hand(sk, side, w, 0.0, 0.0)
		(_springs[_other(side)] as Spring).have = false
		_recipe = [side, side, 1.0, 0.0]
	else:
		# the giving hand to the meeting point and away, the taking hand in and to its hold (the left gun fist is
		# GunMiddleCarryIK's: the right fist comes to it)
		var t := pass_t
		var meet := sin(PI * clampf(t, 0.0, 1.0))
		var w_from := w * (1.0 - smoothstep(0.55, 0.85, t))
		var w_to := w * smoothstep(0.05, 0.4, t)
		if not (pass_from == "l" and gun_fist):
			_hand(sk, pass_from, w_from, meet, 0.0)
		if not (side == "l" and gun_fist):
			_hand(sk, side, w_to, meet, PASS_GAP_M)
		# the torch leaves the giving fist for the taking one while they hold it together
		_recipe = [pass_from, side, smoothstep(0.4, 0.6, t), PASS_GAP_M]
	_placed = true
	_dt = 0.0


## Puts the torch's node where the fist(s) holding it are now (HandPropsFinal, after every arm modifier; the
## skeleton's final pose). Returns the torch's grip frame (skeleton space; the handle along +Y).
func place_socket(sk: Skeleton3D) -> Transform3D:
	if not _placed or not _have_ids:
		return Transform3D()
	var xa := _grip_frame(sk, String(_recipe[0]), 0.0)
	var xb := _grip_frame(sk, String(_recipe[1]), float(_recipe[3]))
	var xf := xa.interpolate_with(xb, float(_recipe[2]))
	var head := xf.basis.y.normalized()
	last_torch_axis = head
	last_grip = xf.origin
	last_flame = xf.origin + head * (TorchModels.LENGTH - TorchModels.GRIP_FROM_BUTT - 0.03)
	if socket != null and is_instance_valid(socket):
		socket.transform = xf * HAND_OFFSET
	return xf


## Where the torch's grip is when fist `s` holds it (final pose): the fist's prop frame, or the left gun fist's with
## GUN_FIST_OFFSET; `gap`: the taking fist holds it this much higher up the handle (the grip moved down the handle).
func _grip_frame(sk: Skeleton3D, s: String, gap: float) -> Transform3D:
	var f := sk.get_bone_global_pose(_ids[s + "_hand_prop_attachment"]).orthonormalized()
	if s == "l" and gun_fist_blend > 0.0:
		# beside the gun in the gun's frame at the fist (the left prop is not aligned with it), eased
		f = f.interpolate_with(gun_fist_frame * GUN_FIST_OFFSET, smoothstep(0.0, 1.0, gun_fist_blend))
	elif gap != 0.0:
		f = f * Transform3D(Basis(), Vector3(0.0, -gap, 0.0))
	return f


## One hand's torch hold, `w` of the way: the prop in the fist, the torch turned upright and the fist placed (`meet`:
## 0..1 of the way to the pass's meeting point, `gap` above it along the torch). Returns the fist's grip frame (the
## prop bone's final pose, skeleton space: the haft along +Y).
func _hand(sk: Skeleton3D, s: String, w: float, meet: float, gap: float) -> Transform3D:
	var lp: int = _ids[s + "_hand_prop_attachment"]
	# the prop in the fist as the grip has it whenever this hand holds the torch (the torch is placed on it: left to
	# the clips' own prop key, a hand taking the torch over showed it wherever the clip keyed that bone, up to the
	# far side of the body); the hold's placement eases in with hand_in
	_prop_from(sk, s, lp, 1.0 if w > 0.0 else 0.0)
	w *= smoothstep(0.0, 1.0, float(hand_in[s]))
	var cw := w * clampf(upright, 0.0, 1.0)
	var gp := sk.get_bone_global_pose(lp).orthonormalized()
	if cw <= 0.0:
		(_springs[s] as Spring).have = false
		_rolls[s].have = false
		return gp
	# the player's facing (skeleton +Z; its left +X); `out` toward the torch hand's side
	var fwd := Vector3.BACK
	var out := Vector3.RIGHT if s == "l" else Vector3.LEFT
	var r := clampf(raise, 0.0, 1.0)
	var t := deg_to_rad(lerpf(axe_tilt_deg, raise_tilt_deg, r))
	var o := deg_to_rad(lerpf(axe_out_deg, raise_out_deg, r))
	var want := (Vector3.UP * cos(t) + fwd * sin(t)).normalized()
	want = (want * cos(o) + out * sin(o)).normalized()
	var a := gp.basis.y.normalized()
	var turn := a.angle_to(want)
	last_torch_turn_deg = rad_to_deg(turn)
	var q_src := gp.basis.get_rotation_quaternion()
	var q_want := q_src
	if turn > 1e-4:
		var k := minf(1.0, deg_to_rad(MAX_TURN_DEG) / turn)
		q_want = Quaternion.IDENTITY.slerp(Quaternion(a, want), k) * q_src
	# the fist wraps round the handle from the side the arm comes from (a turn about the handle, eased): the wrist
	# stays straight (ArmSolve)
	var sh0 := sk.get_bone_global_pose(_ids[s + "_shoulder"]).origin
	var roll := ArmSolve.roll_toward(sk, s, Basis(q_want), Vector3.UP, (gp.origin - sh0).normalized())
	var rs: Dictionary = _rolls[s]
	rs.r = float(rs.r) + wrapf(roll - float(rs.r), -PI, PI) * (1.0 - exp(-ROLL_RATE * maxf(_dt, 0.0))) if bool(rs.have) else roll
	rs.have = true
	var axis_now := (Basis(q_want) * Vector3.UP).normalized()
	q_want = Quaternion(axis_now, float(rs.r)) * q_want
	# where the fist goes: the axe hold beside the hip (from the pelvis), the raised hold beside the shoulder
	var pel := sk.get_bone_global_pose(_ids.pelvis).origin
	var sh := sk.get_bone_global_pose(_ids[s + "_shoulder"]).origin
	var ax := axe_fist.lerp(axe_fist_crouch, clampf(crouch, 0.0, 1.0))
	var p_axe := pel + out * ax.x + Vector3.UP * ax.y + fwd * ax.z
	var p_raise := sh + out * raise_fist.x + Vector3.UP * raise_fist.y + fwd * raise_fist.z
	var anchor := p_axe.lerp(p_raise, smoothstep(0.0, 1.0, r))
	var target := gp.origin.lerp(anchor, clampf(anchor_weight, 0.0, 1.0))
	if meet > 0.0:
		var m := pel + Vector3.RIGHT * PASS_MEET.x + Vector3.UP * PASS_MEET.y + fwd * PASS_MEET.z + want * gap
		if gun_fist and s == "r":
			# the left fist holds the gun: the right fist comes to it, just above
			m = gun_fist_frame.origin + GUN_FIST_LIFT
		target = target.lerp(m, clampf(meet, 0.0, 1.0))
	target = _reachable(sk, s, gp, q_want, target)
	var root := sk.get_bone_global_pose(_ids.root).origin
	var sp: Spring = _springs[s]
	if bool(_fresh[s]):
		_fresh[s] = false
		sp.have = true
		sp.p = gp.origin - root
		sp.q = gp.basis.get_rotation_quaternion()
		sp.v = Vector3.ZERO
		sp.w = Vector3.ZERO
	sp.step(target - root, q_want, _dt, TORCH_FREQ)
	_place(sk, s, lp, _ids[s + "_wrist"], sp.q, sp.p + root, cw)
	var g2 := sk.get_bone_global_pose(lp).orthonormalized()
	var rel := g2.origin - pel
	last_fist = Vector3(rel.dot(out), rel.y, rel.dot(fwd))
	return g2


static func _other(s: String) -> String:
	return "l" if s == "r" else "r"


func _find(sk: Skeleton3D) -> bool:
	for bn in ["l_wrist", "l_hand_prop_attachment", "r_wrist", "r_hand_prop_attachment", "neck", "pelvis", "l_shoulder",
			"l_elbow", "r_shoulder", "r_elbow", "root"]:
		var b := sk.find_bone(bn)
		if b < 0:
			return false
		_ids[bn] = b
	_have_ids = true
	return true


## The prop bone of side `s` from the grip clip's first frame, `w` of the way (the right prop's track; the left prop
## takes it mirrored).
func _prop_from(sk: Skeleton3D, s: String, bone: int, w: float) -> void:
	if grip_anim == null or w <= 0.0:
		return
	if _tracks.is_empty():
		var m := [-1, -1]
		for k in grip_anim.get_track_count():
			if String(grip_anim.track_get_path(k)).get_slice(":", 1) != "r_hand_prop_attachment":
				continue
			if grip_anim.track_get_type(k) == Animation.TYPE_POSITION_3D:
				m[0] = k
			elif grip_anim.track_get_type(k) == Animation.TYPE_ROTATION_3D:
				m[1] = k
		_tracks = {"r": m}
	var tr: Array = _tracks.r
	if int(tr[0]) >= 0:
		var pos := grip_anim.position_track_interpolate(int(tr[0]), 0.0)
		if s == "l":
			pos = -pos
		sk.set_bone_pose_position(bone, sk.get_bone_pose_position(bone).lerp(pos, w))
	if int(tr[1]) >= 0:
		var q := grip_anim.rotation_track_interpolate(int(tr[1]), 0.0)
		if s == "l":
			q = MIRROR_PROP * Quaternion(q.x, -q.y, -q.z, q.w)
		sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone).slerp(q, w).normalized())


## A bone's forward (from its rest) flattened onto the ground plane: [forward, left] (skeleton space; the rig
## faces +Z, its left is +X). The bone's up is added before flattening: a chest bent over past the horizontal
## (the crouch-walk) has its forward pointing down and back, its up forward.
static func yaw_frame(basis: Basis, fwd_local: Vector3, up_local: Vector3) -> Array:
	var b := basis.orthonormalized()
	var f := b * fwd_local + b * up_local * 0.8
	f.y = 0.0
	if f.length() < 1e-4:
		f = Vector3.BACK
	f = f.normalized()
	return [f, Vector3.UP.cross(f).normalized()]


## `target` for the prop of side `s` (at rotation `q`) pulled softly within the arm's reach of the shoulder
## (REACH_FRAC, the last REACH_SOFT_M eased): out of reach the solve would leave the fist on the shoulder's keyed
## motion.
func _reachable(sk: Skeleton3D, s: String, gp: Transform3D, q: Quaternion, target: Vector3) -> Vector3:
	var sh := sk.get_bone_global_pose(_ids[s + "_shoulder"]).origin
	var el := sk.get_bone_global_pose(_ids[s + "_elbow"]).origin
	var gw := sk.get_bone_global_pose(_ids[s + "_wrist"])
	var rel := gw.affine_inverse() * gp
	var d := (Basis(q) * rel.basis.orthonormalized().inverse()) * rel.origin
	var v := target - d - sh
	var reach := (sh.distance_to(el) + el.distance_to(gw.origin)) * REACH_FRAC
	var l := v.length()
	var knee := reach - REACH_SOFT_M
	if l <= knee or l < 1e-5:
		return target
	return sh + v / l * (knee + REACH_SOFT_M * (1.0 - exp(-(l - knee) / REACH_SOFT_M))) + d


## The prop bone of `s` placed at rotation `q` and `w` of the way to `pos` (ArmSolve: the hand takes the rotation, the
## elbow is chosen so the wrist stays straight and out of the body), skeleton space.
var last_wrist_bend := {"l": 0.0, "r": 0.0}


func _place(sk: Skeleton3D, s: String, _prop: int, _wrist: int, q: Quaternion, pos: Vector3, w: float) -> void:
	last_wrist_bend[s] = ArmSolve.place(sk, s, Transform3D(Basis(q), pos), w)
