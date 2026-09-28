class_name GunCarryDamper
extends ReachIK
## A damped carry bob for the long gun (push n01, user playtest 2026-09-25: "the gun bounces in the left
## hand when we move").
##
## Why: the source's clips are sampled at 10-15 keys a second and play with linear interpolation, and the
## carries cross-fade linearly between gaits: the gun (the right prop bone) moved in straight segments whose
## velocity jumped at every key (0.2-0.3 m/s in the chest's frame at a jog, eight times a stride) and at the
## end of every cross-fade (0.6-2.7 m/s at walk and crouch-walk starts, 1.3-2.3 m/s at a jump's take-off):
## a visible jitter and small pops of a 1.5 m musket.
## How: the gun's pose in the chest's frame (spined) follows the animated pose through a critically damped
## spring (FREQ), position and rotation; the right arm is then solved to hold the gun there (the wrist
## turned so the prop takes the smoothed rotation, shoulder and elbow by ReachIK.apply_side). The gait's own
## bob stays (about three quarters of it at a jog, a quarter of a stride late); the key-rate kinks and the
## cross-fade corners go. LeftGripIK runs after this and keeps the left hand on the smoothed gun.
## The weight follows `enabled` (PlayerAnim: a long gun carried, not aimed, no action) over FADE_S, so the
## aim, reloads and draws get the animation's exact gun. Order: after LeftArmPose / RightArmPose, before
## LeftGripIK.

## Natural frequency of the spring (rad/s; critically damped). 25: the key-rate kinks (60-95 rad/s) pass at
## 7-15 %, a jog's step bob (about 16 rad/s) at about 70 %.
const FREQ := 25.0
## Seconds for the damping to come on or off.
const FADE_S := 0.2
## Integration step (s): longer frames are split.
const STEP_S := 1.0 / 240.0

## Damping wanted (set every frame by PlayerAnim).
var enabled := false
## The left hand's grip (LeftGripIK, after this in the stack): its reach pull is applied first, so it is
## smoothed with the gun (PlayerAnim sets it).
var grip: LeftGripIK
## Current weight 0..1 (after the fade).
var damp_weight := 0.0
## How far the damping moved the gun last frame (m), and the animated gun it followed (the prop's origin in
## the chest's frame), for tests and the debug view.
var last_shift := 0.0
var last_target := Vector3.ZERO

var _lin := 0.0
var _dt := 1.0 / 60.0
var _ids := PackedInt32Array()
var _have := false
var _p := Vector3.ZERO
var _v := Vector3.ZERO
var _q := Quaternion.IDENTITY
var _omega := Vector3.ZERO


func advance(dt: float) -> void:
	# the spring steps once per animation step: a second skeleton update in the same step (tests that
	# advance by hand) finds no time left
	_dt = maxf(dt, 0.0)
	_lin = move_toward(_lin, 1.0 if enabled else 0.0, dt / FADE_S)
	damp_weight = smoothstep(0.0, 1.0, _lin)


## Takes the wanted weight at once and forgets the spring's state (the next frame starts on the
## animated gun).
func snap() -> void:
	_lin = 1.0 if enabled else 0.0
	damp_weight = _lin
	_have = false


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if damp_weight <= 0.0:
		_have = false
		last_shift = 0.0
		return
	if _ids.is_empty():
		for bn in ["spined", "r_wrist", "r_hand_prop_attachment"]:
			var b := sk.find_bone(bn)
			if b < 0:
				return
			_ids.append(b)
	var chest := sk.get_bone_global_pose(_ids[0]).orthonormalized()
	var gw := sk.get_bone_global_pose(_ids[1])
	var gr := sk.get_bone_global_pose(_ids[2])
	# the left hand's reach pull goes into the target, so one solve from the animated arm takes the gun to the
	# smoothed, pulled place (push n09: the pull solved on its own first turned the right shoulder by up to
	# 1 rad, and as it let go at a start out of an idle turn, 34 cm in 0.1 s, that turn came through this
	# solve unsmoothed: the shoulder at 27-30 rad/s, test_continuity's storm)
	var pulled := gr
	if grip != null:
		pulled.origin += grip.pull_in(sk)
	var local := chest.affine_inverse() * pulled.orthonormalized()
	var tp := local.origin
	last_target = tp
	var tq := local.basis.get_rotation_quaternion()
	if not _have:
		_p = tp
		_v = Vector3.ZERO
		_q = tq
		_omega = Vector3.ZERO
		_have = true
	elif _dt > 0.0:
		var n := maxi(int(ceil(_dt / STEP_S)), 1)
		var h := _dt / n
		_dt = 0.0
		for i in n:
			_v += (FREQ * FREQ * (tp - _p) - 2.0 * FREQ * _v) * h
			_p += _v * h
			# rotation error as a rotation vector in the smoothed frame (the shorter way round)
			var e := _q.inverse() * tq
			if e.w < 0.0:
				e = -e
			var ang := 2.0 * acos(clampf(e.w, -1.0, 1.0))
			var ev := Vector3.ZERO
			if ang > 1e-6:
				ev = Vector3(e.x, e.y, e.z).normalized() * ang
			_omega += (FREQ * FREQ * ev - 2.0 * FREQ * _omega) * h
			var wl := _omega.length() * h
			if wl > 1e-9:
				_q = (_q * Quaternion(_omega.normalized(), wl)).normalized()
	# the smoothed gun, blended in by the weight (skeleton space)
	var want_q := (chest.basis.get_rotation_quaternion() * tq).slerp(chest.basis.get_rotation_quaternion() * _q, damp_weight)
	var want_p := pulled.origin.lerp(chest * _p, damp_weight)
	# wrist turned so the prop takes the smoothed rotation (the prop rides rigidly on the wrist), then the
	# arm reaches so the prop origin gets there
	var rel := gw.affine_inverse() * gr
	var wb := (Basis(want_q) * rel.basis.orthonormalized().inverse()).orthonormalized()
	sk.set_bone_global_pose(_ids[1], Transform3D(wb, gw.origin))
	var moved := apply_side(sk, "r", want_p, 1.0)
	last_shift = maxf((moved - (pulled.origin - gr.origin)).length(), pulled.origin.distance_to(want_p))
