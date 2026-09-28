class_name GunMiddleCarryIK
extends ReachIK
## The long gun carried in the LEFT hand alone, gripped in the middle at its balance point (push n01c; user
## 2026-09-26: "the gun should be held in the middle not at the end", "the right hand holds the torch and the left
## hand holds the gun which makes it looks better allows us to do the one hand middle hold", "yes i want the middle
## grip on the crouch walk as well", "allows user to have the right hand to throwables and easily switch back to
## rifle"). A trail-arms carry: the arm hanging at the side, the fist round the gun just ahead of the lock, the gun
## about level along the left leg, the muzzle forward and a little down.
##
## Used for the torch carry (the torch in the right hand, HandHolds), the crouch-walk one-hand hold and the quick
## throwables (the throwable in the right hand). PlayerAnim poses the left arm first (LeftArmPose: the source's own
## one-hand rifle arms, mirrored from the right: standing actor_b-rifle-idle-no-aim--part, crouch-moving
## actor_b-p-rifle-cover-low-left-fw--arms at the stride's phase; the fingers from the grip in use, GRIPS: the
## tomahawk's knife fist by default); this modifier then:
##  - puts the gun where the grip's fit has it in the fist (placed through a fixed reference frame in the palm, REF_CLIP;
##    the left prop bone, whatever its place in the palm, is solved for through it) (palm_in_gun(): the palm on the wood, the fingers and thumb closed
##    round it; tests/torch/lib/grip_gauge.gd measures it on the skinned hand);
##  - turns the gun to lie along the left side (pitch_deg below horizontal, out_deg out to the left, upright, in the
##    player's facing turned HIP_FOLLOW of the way with the hips), the fist turned round the gun's middle line toward
##    the side the arm comes from (ArmSolve.roll_toward, at most roll_max_deg: it stays wrapped round the wood), and
##    moves the fist `anchor_weight` of the way from the source pose to `anchor` (from the pelvis; out and up by
##    AIR_OFFSET in the air, off the knees), the arm solved to it with the wrist kept straight (ArmSolve.place),
##    through a critically damped spring (as TorchCarryIK: the source keys its locomotion at 10-15 Hz);
##  - hands the gun over: `progress` runs 0 (the gun on the right prop, as the carry holds it) .. 1 (in the left
##    hand) over HANDOFF_S: the left hand closes on the balance point first, then the gun travels to the left carry
##    with both hands on it, then the right hand lets go (and the reverse: the right hand takes the wrist of the
##    stock, the gun comes back to the right hand's carry, the left hand lets go into whatever the arm does next:
##    LeftGripIK's fore-end grip, the aim's own arms);
##  - places the gun's model: it stays on its socket (a BoneAttachment3D of the right prop bone, Weapon.model's
##    parent, which the SlingRig and the weapons know), and its transform is set relative to that socket so it sits
##    in the left fist (`gun`, restored to `gun_offset` when the hold is off).
## The gun's frame F: the right prop's frame when the right hand holds it (+Z the muzzle's way, +Y up, the origin at
## the wrist of the stock: WeaponModels' grip). The left prop in the middle grip is F * grip_in_gun(prop_local): the
## palm where the grip's fit puts it, `balance_m` along the barrel from the grip (the model's -Z). Through a handoff
## the gun's frame goes between the hands' frames by _blend() (a turn that keeps its way round from frame to frame).
## `exchange` (0..1, HandHolds) brings the fist in front of the left hip for a weapon switch's exchange with the torch
## (the right fist brings the torch to this fist, or takes it from it: TorchCarryIK.gun_fist).
## Order: the last of the hands' modifiers (after TorchCarryIK, GunCarryDamper and LeftGripIK: the right prop is final
## there), before CharacterBodyMesh; it also places the held things at the end (the torch: TorchCarryIK.place_socket()).

## The left fist on the gun (push n01c; user 2026-09-26: "for the one hand hold the left hand doesn grip it properly"):
## the fingers from a source grip (`clip`, the right hand's mirrored onto the left when `mirror`) and where the gun
## sits in that fist, `palm`: the l_palm bone in the gun model's frame (origin at the wrist of the stock, barrel -Z,
## up +Y), fitted by tools/anim/grip_fit.py against the Brown Bess's own meshes (tests/torch/tools/grip_fit_export.gd:
## the skinned hand in that pose) so the palm lies on the wood, every finger and the thumb close round it and no skin
## goes into it; the palm's middle BALANCE_FIT_M along the barrel from the wrist of the stock (`balance_m` moves it).
## Refitted 2026-09-28 on body v4's hands (the MakeHuman hand: the old fits left the palm about 1 cm off the wood).
const GRIPS := {
	"flashlight": {"clip": "actor_b-fist-ambi-flashlight--hand", "mirror": false,
		"palm": Transform3D(Basis(Vector3(-0.34293, -0.28435, 0.89529), Vector3(-0.93521, 0.19280, -0.29698), Vector3(-0.08817, -0.93913, -0.33205)), Vector3(-0.07553, 0.06435, -0.40450))},
	"rifle_fore_crouch_carry": {"clip": "actor_b-p-rifle-crouch-idle--hands", "mirror": false,
		"palm": Transform3D(Basis(Vector3(-0.56991, -0.22447, 0.79046), Vector3(-0.79450, 0.39603, -0.46036), Vector3(-0.20971, -0.89038, -0.40404)), Vector3(-0.07314, 0.05604, -0.40941))},
	"rifle_wrist_carry": {"clip": "actor_b-p-rifle-run-arms", "mirror": true,
		"palm": Transform3D(Basis(Vector3(-0.51647, -0.22798, 0.82540), Vector3(-0.85311, 0.22010, -0.47302), Vector3(-0.07383, -0.94846, -0.30817)), Vector3(-0.07791, 0.07086, -0.41244))},
	"pistol": {"clip": "actor_b-pistol-r--hand", "mirror": true,
		"palm": Transform3D(Basis(Vector3(-0.36826, -0.36705, 0.85420), Vector3(-0.92910, 0.11157, -0.35261), Vector3(0.03412, -0.92349, -0.38211)), Vector3(-0.08316, 0.05628, -0.40766))},
	"knife": {"clip": "atk-actor_b-knife-v-thug-hit1-intro", "mirror": true,
		"palm_over_under": Transform3D(Basis(Vector3(-0.34839, -0.36733, 0.86238), Vector3(-0.92663, 0.27369, -0.25777), Vector3(-0.14134, -0.88891, -0.43573)), Vector3(-0.05950, -0.00749, -0.40396)),
		"palm": Transform3D(Basis(Vector3(-0.38815, -0.33374, 0.85904), Vector3(-0.90323, 0.32290, -0.28268), Vector3(-0.18304, -0.88564, -0.42678)), Vector3(-0.06265, 0.02024, -0.40478))},
}
## A grip may have its own fit per gun ("palm_<gun_kind>": the over-under's fore-end is 5.1 cm deep at the balance
## point, the Brown Bess's 4.3).
const BALANCE_FIT_M := 0.40
## The fist's reference frame in the palm, the placement's handle (the frame `anchor`, `offset` and the roll were tuned
## for: the source's flashlight grip key of the left prop bone, REF_CLIP). The left prop bone itself may sit anywhere
## in the palm (the torch's grip puts it on the torch when the torch is in this fist too, else the clips'); the arm is
## solved for it through this frame, so the fist lands in the same place either way.
const REF_CLIP := "actor_b-fist-ambi-flashlight--hand"
## The gun's middle line at the grip (model y, per gun_kind: the fore-end from its bottom to the barrels' top), the
## line the fist turns about (`_roll`).
const GRIP_AXIS_Y := {"musket": 0.029, "over_under": 0.0215}
## Seconds for a whole handoff (right -> left or back).
const HANDOFF_S := 0.3
## How much of the hips' turn the gun's carry frame takes (0 = the player's facing).
const HIP_FOLLOW := 0.3
const FREQ := 12.0
const STEP_S := 1.0 / 240.0
const REACH_FRAC := 0.985
const REACH_SOFT_M := 0.05

## The middle carry wanted (PlayerAnim, every frame) and the handoff's progress (0 right .. 1 left).
var on := false
var progress := 0.0
## The handoff's rate (1 / seconds; PlayerAnim may make it quicker: the aim takes the gun back in HANDOFF_S * 0.8).
var handoff_s := HANDOFF_S
## 0 standing .. 1 crouched (eased by PlayerAnim): the crouched values blend in.
var crouch := 0.0

## Tunables (PlayerAnim's "Middle grip" exports).
## The fist (GRIPS) and the gun it holds ("musket" / "over_under": HandHolds sets it).
var grip := "knife"
var gun_kind := "musket"
## Where the fist grips: the palm's middle this far along the barrel from the wrist of the stock (m; the musket's
## balance point, just ahead of the lock).
var balance_m := 0.40
## How far the fist may turn about the gun's middle line from the fitted grip to bring the forearm toward the
## shoulder (deg).
var roll_max_deg := 35.0
## The barrel below horizontal (deg), standing and crouched; out to the left of straight ahead (deg).
var pitch_deg := 6.0
var pitch_crouch_deg := 3.0
var out_deg := 2.0
## The fist moved from the source pose (m): x out to the character's left, y up, z forward (hips' yaw frame);
## `anchor_weight` of the way to `anchor` from the pelvis instead (0 = the source pose + offset).
var offset := Vector3(0.0, 0.0, 0.0)
var offset_crouch := Vector3(0.0, 0.0, 0.0)
var anchor := Vector3(0.335, -0.21, 0.06)
var anchor_crouch := Vector3(0.32, 0.0, 0.2)
var anchor_weight := 0.8
## In the air (a jump's knees come up under the gun): the fist moved this much (as `offset`) and the muzzle turned this
## much further out (deg), `air` (0..1, eased by HandHolds) of the way.
const AIR_OFFSET := Vector3(0.05, 0.05, 0.0)
const AIR_OUT_DEG := 10.0
var air := 0.0
## The exchange with the torch: the fist this far from the pelvis (as `anchor`), the gun this far out (deg).
const EXCHANGE_ANCHOR := Vector3(0.15, 0.02, 0.24)
const EXCHANGE_OUT_DEG := 22.0
var exchange := 0.0

## The torch (its node is placed here, after every arm modifier).
var torch: TorchCarryIK

## The gun's model (Weapon.model, on its right-prop socket) and its transform there when the right hand holds it.
var gun: Node3D
var gun_offset := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)

## Last frame's measures (tests, the debug view): the gun's frame F (skeleton space), the left prop, how far the
## left and right hands hold it (0..1), the wrist's turn.
var last_gun := Transform3D()
var last_left := Transform3D()
var last_w_left := 0.0
var last_w_right := 0.0
var last_turn_deg := 0.0
## The source fist's turn from the wanted grip split into the barrel's direction and the roll about it (deg).
var last_axis_deg := 0.0
var last_roll_deg := 0.0

var _ids := {}
var _have_ids := false
var _pelvis_fwd := Vector3.BACK
var _pelvis_up := Vector3.UP
var _dt := 0.0
var _spring := TorchCarryIK.Spring.new()
## The fist's turn about the barrel (rad; ArmSolve.roll_toward, eased at ROLL_RATE 1/s) and the grip in use this frame.
const ROLL_RATE := 14.0
var _roll := 0.0
var _have_roll := false
var _k := Transform3D()
var _restored := true
var _ref := Transform3D()


## Reads the fist's reference frame (REF_CLIP's left prop key at its first frame; the prop bone's rest without it).
func set_reference(anim: Animation, sk: Skeleton3D = null) -> void:
	if sk != null:
		var b := sk.find_bone("l_hand_prop_attachment")
		if b >= 0:
			_ref = sk.get_bone_rest(b)
	if anim == null:
		return
	for t in anim.get_track_count():
		if String(anim.track_get_path(t)).get_slice(":", 1) != "l_hand_prop_attachment":
			continue
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			_ref.origin = anim.position_track_interpolate(t, 0.0)
		elif anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			_ref.basis = Basis(anim.rotation_track_interpolate(t, 0.0))


func advance(dt: float) -> void:
	_dt += maxf(dt, 0.0)
	progress = move_toward(progress, 1.0 if on else 0.0, dt / maxf(handoff_s, 1e-3))


## Takes the wanted state at once.
func snap() -> void:
	progress = 1.0 if on else 0.0
	_spring.have = false
	_have_roll = false


## The gun is in the left hand (the handoff past the right hand's letting go).
func in_left() -> bool:
	return progress >= 0.8


## The grip in use (GRIPS[grip]).
func grip_info() -> Dictionary:
	return GRIPS.get(grip, GRIPS.flashlight)


## The l_palm bone in the gun's frame F (+Z the muzzle's way; the model is F * gun_offset), at `balance_m`.
func palm_in_gun() -> Transform3D:
	var gi := grip_info()
	var pm: Transform3D = gi.get("palm_" + gun_kind, gi.palm)
	pm.origin.z -= balance_m - BALANCE_FIT_M
	return gun_offset * pm


## The left prop in the gun's frame F for the prop's local pose `prop_local` (in the palm).
func grip_in_gun(prop_local := Transform3D()) -> Transform3D:
	return palm_in_gun() * prop_local


## The gun's middle line at the grip in F (the point the fist turns about).
func grip_centre() -> Vector3:
	return gun_offset * Vector3(0.0, float(GRIP_AXIS_Y.get(gun_kind, GRIP_AXIS_Y.musket)), -balance_m)


## The hands' weights on the gun at a handoff progress `s`: [left, right, travel] (the left hand closes first, the
## gun travels with both hands on it, then the right hand lets go).
static func weights(s: float) -> Array:
	return [smoothstep(0.0, 0.35, s), 1.0 - smoothstep(0.45, 0.8, s), smoothstep(0.25, 1.0, s)]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if progress <= 0.0 or (not _have_ids and not _find(sk)):
		_spring.have = false
		_have_roll = false
		_rv_have = [false, false]
		_fr_have = false
		_fr_frozen = false
		_restore()
		_dt = 0.0
		if torch != null:
			torch.place_socket(sk)
		return
	_hold(sk)
	if torch != null:
		torch.place_socket(sk)
	_dt = 0.0


func _hold(sk: Skeleton3D) -> void:
	var ws := weights(progress)
	var wl: float = ws[0]
	var wr: float = ws[1]
	var g: float = ws[2]
	var rp: int = _ids.r_hand_prop_attachment
	var lp: int = _ids.l_hand_prop_attachment
	# the gun as the right hand holds it now; on the way into the left hand, as the right hand held it when the handoff
	# began (the right hand then goes with the gun: the right arm's own pose changes as the carry lets it go, the tree's
	# carry cross-fade and the free swing, and the gun must not follow that: 2-4 m/s kinks at the crouch-walk start)
	var f_r := sk.get_bone_global_pose(rp).orthonormalized()
	if on:
		if not _fr_frozen:
			_fr_frozen = true
			_fr_hold = _fr_last if _fr_have else f_r
		f_r = _fr_hold
	else:
		_fr_frozen = false
	_fr_last = f_r
	_fr_have = true
	# the fist's grip on the gun for the left prop's place in the palm now (whatever sets it: the torch's grip when the
	# torch is in this fist too, else the clips'), and where the carry wants the gun (the grip turned round the gun's
	# middle line)
	var prop_local := Transform3D(Basis(sk.get_bone_pose_rotation(lp)), sk.get_bone_pose_position(lp))
	var x := _ref.affine_inverse() * prop_local     # the prop in the reference frame
	var k := grip_in_gun(_ref)                        # the reference frame in F
	var f_l := _carry_frame(sk, k, x)
	k = _k
	var f_mix := _blend(f_r, f_l, g, 0)
	# the left hand onto the gun at the balance point (wl), the arm solved (for the prop bone, through the reference)
	var want_l := (f_mix * k * x).orthonormalized()
	_place(sk, "l", lp, _ids.l_wrist, want_l.basis.get_rotation_quaternion(), want_l.origin, wl)
	var got_l := (sk.get_bone_global_pose(_ids.l_palm) * _ref).orthonormalized()
	# the gun follows the left fist as it takes it over; the right hand holds the wrist of the stock until it lets go
	var f := _blend(f_r, got_l * k.affine_inverse(), g, 1)
	if wr > 0.0 and g > 0.0:
		_place(sk, "r", rp, _ids.r_wrist, f.basis.get_rotation_quaternion(), f.origin, wr)
	last_gun = f
	last_left = got_l
	last_w_left = wl
	last_w_right = wr
	if torch != null:
		# the gun's frame at the fist (+Z along the barrel, +Y up the gun): where the torch meets the gun fist
		torch.gun_fist_frame = f * Transform3D(Basis(), grip_centre())
	# the model on its right-prop socket, placed where the gun is
	if gun != null and is_instance_valid(gun):
		var r_final := sk.get_bone_global_pose(rp)
		gun.transform = r_final.affine_inverse() * f * gun_offset
		_restored = false


## `a` `t` of the way to `b` (position lerped, rotation turned about a fixed axis): the turn goes the same way round
## as last frame's (`slot`: one per blend), so a relative turn passing half a turn does not flip to the other side
## (the right prop's pose while the right hand tosses the torch can face away from the carry: slerp's shortest way
## swung the 1.3 m gun 0.6 m in a frame).
var _rv := [Vector3.ZERO, Vector3.ZERO]
var _rv_have := [false, false]
var _fr_last := Transform3D()
var _fr_hold := Transform3D()
var _fr_have := false
var _fr_frozen := false


func _blend(a: Transform3D, b: Transform3D, t: float, slot: int) -> Transform3D:
	var qa := a.basis.get_rotation_quaternion()
	var rel := qa.inverse() * b.basis.get_rotation_quaternion()
	if rel.w < 0.0:
		rel = -rel
	var ang := 2.0 * acos(clampf(rel.w, -1.0, 1.0))
	var rv := Vector3.ZERO
	if ang > 1e-6:
		rv = Vector3(rel.x, rel.y, rel.z).normalized() * ang
		if bool(_rv_have[slot]) and ang > deg_to_rad(90.0) and rv.dot(_rv[slot] as Vector3) < 0.0:
			rv = rv.normalized() * (ang - TAU)    # the long way round: continuous with last frame
	_rv[slot] = rv
	_rv_have[slot] = true
	var q := qa
	if rv.length() > 1e-6:
		q = qa * Quaternion(rv.normalized(), rv.length() * t)
	return Transform3D(Basis(q.normalized()), a.origin.lerp(b.origin, t))


func _restore() -> void:
	if _restored:
		return
	_restored = true
	if gun != null and is_instance_valid(gun):
		gun.transform = gun_offset


func _find(sk: Skeleton3D) -> bool:
	for bn in ["l_wrist", "l_hand_prop_attachment", "r_wrist", "r_hand_prop_attachment", "pelvis", "l_shoulder", "l_elbow", "root",
			"l_palm"]:
		var b := sk.find_bone(bn)
		if b < 0:
			return false
		_ids[bn] = b
	var pr := sk.get_bone_global_rest(_ids.pelvis).basis.orthonormalized().inverse()
	_pelvis_fwd = (pr * Vector3.BACK).normalized()
	_pelvis_up = (pr * Vector3.UP).normalized()
	_have_ids = true
	return true


## The gun's frame F the carry wants (skeleton space): turned level along the left side from the fist's source pose,
## the fist moved toward `anchor`, springs on.
func _carry_frame(sk: Skeleton3D, k: Transform3D, px: Transform3D) -> Transform3D:
	var gp := (sk.get_bone_global_pose(_ids.l_palm) * _ref).orthonormalized()
	var pel := sk.get_bone_global_pose(_ids.pelvis)
	var fr := TorchCarryIK.yaw_frame(pel.basis, _pelvis_fwd, _pelvis_up)
	var fwd := Vector3.BACK.slerp(fr[0] as Vector3, HIP_FOLLOW).normalized()
	var left := Vector3.UP.cross(fwd).normalized()
	var c := clampf(crouch, 0.0, 1.0)
	var ex := smoothstep(0.0, 1.0, clampf(exchange, 0.0, 1.0))
	var p := deg_to_rad(lerpf(pitch_deg, pitch_crouch_deg, c))
	var a := smoothstep(0.0, 1.0, clampf(air, 0.0, 1.0))
	var o := deg_to_rad(lerpf(out_deg + AIR_OUT_DEG * a, EXCHANGE_OUT_DEG, ex))
	var z := (fwd * cos(p) - Vector3.UP * sin(p)).normalized()
	z = (z * cos(o) + left * sin(o)).normalized()
	var x := Vector3.UP.cross(z).normalized()
	var gun_basis := Basis(x, z.cross(x).normalized(), z)
	# the fist wraps round the gun from the side the arm comes from (its turn about the barrel: `_roll`, eased), the gun
	# upright
	var sh := sk.get_bone_global_pose(_ids.l_shoulder).origin
	# (ArmSolve works on the prop bone: its rotation is the reference's times px, the prop in the reference frame)
	var roll := ArmSolve.roll_toward(sk, "l", gun_basis * k.basis * px.basis, (k.basis * px.basis).inverse() * Vector3.BACK,
			(gp.origin - sh).normalized())
	roll = clampf(wrapf(roll, -PI, PI), -deg_to_rad(roll_max_deg), deg_to_rad(roll_max_deg))
	_roll = _roll + wrapf(roll - _roll, -PI, PI) * (1.0 - exp(-ROLL_RATE * maxf(_dt, 0.0))) if _have_roll else roll
	_have_roll = true
	# the fist turned round the gun's middle line (it stays wrapped round the wood)
	var gc := grip_centre()
	k = Transform3D(Basis(Vector3.BACK, _roll), gc - Basis(Vector3.BACK, _roll) * gc) * k
	_k = k
	# the left prop's wanted rotation (F * K), limited at the wrist
	var q0 := gp.basis.get_rotation_quaternion()
	var q1 := (gun_basis * k.basis).get_rotation_quaternion()
	var turn := q0.angle_to(q1)
	last_turn_deg = rad_to_deg(turn)
	# (no limit on the turn: ArmSolve moves the elbow with the hand, so the wrist is not wrung by it)
	var z0 := Basis(q0) * Vector3.BACK
	var z1 := Basis(q1) * Vector3.BACK
	last_axis_deg = rad_to_deg(z0.angle_to(z1))
	var rel := q1.inverse() * (Quaternion(z0, z1) * q0)
	last_roll_deg = rad_to_deg(2.0 * atan2(rel.z, rel.w))
	var q := q1
	# the fist: the source pose moved by `offset`, `anchor_weight` of the way to the pelvis anchor
	var off := offset.lerp(offset_crouch, c)
	var src := gp.origin + left * off.x + Vector3.UP * off.y + fwd * off.z
	var an := anchor.lerp(anchor_crouch, c).lerp(EXCHANGE_ANCHOR, ex)
	var at := pel.origin + left * an.x + Vector3.UP * an.y + fwd * an.z
	var target := src.lerp(at, lerpf(clampf(anchor_weight, 0.0, 1.0), 1.0, ex))
	target += (left * AIR_OFFSET.x + Vector3.UP * AIR_OFFSET.y + fwd * AIR_OFFSET.z) * a
	target = _reachable(sk, gp, q, target)
	var root := sk.get_bone_global_pose(_ids.root).origin
	_spring.step(target - root, q, _dt, FREQ, STEP_S)
	# F from the wanted left prop: F = L * K^-1
	return Transform3D(Basis(_spring.q), _spring.p + root) * _k.affine_inverse()


## `target` for the left prop pulled softly within the arm's reach (as TorchCarryIK._reachable).
func _reachable(sk: Skeleton3D, gp: Transform3D, q: Quaternion, target: Vector3) -> Vector3:
	var sh := sk.get_bone_global_pose(_ids.l_shoulder).origin
	var el := sk.get_bone_global_pose(_ids.l_elbow).origin
	var gw := sk.get_bone_global_pose(_ids.l_wrist)
	var rel := gw.affine_inverse() * gp
	var d := (Basis(q) * rel.basis.orthonormalized().inverse()) * rel.origin
	var v := target - d - sh
	var reach := (sh.distance_to(el) + el.distance_to(gw.origin)) * REACH_FRAC
	var l := v.length()
	var knee := reach - REACH_SOFT_M
	if l <= knee or l < 1e-5:
		return target
	return sh + v / l * (knee + REACH_SOFT_M * (1.0 - exp(-(l - knee) / REACH_SOFT_M))) + d


## The prop bone of `side` `w` of the way to rotation `q` at `pos` (ArmSolve: the wrist kept straight, the elbow out).
var last_wrist_bend := {"l": 0.0, "r": 0.0}


func _place(sk: Skeleton3D, side: String, _prop: int, _wrist: int, q: Quaternion, pos: Vector3, w: float) -> void:
	if w <= 0.0:
		return
	last_wrist_bend[side] = ArmSolve.place(sk, side, Transform3D(Basis(q), pos), w)
