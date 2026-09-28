class_name TandemArmHold
extends PalmReachIK
## The crawling pair's arm hold: the tandem partner's RIGHT hand holds the crawler's RIGHT bicep. Put on the
## partner's skeleton (before the body mesh, as the game's other PalmReachIK), with `lead` the crawler's skeleton.
## Each frame, after the clips: the target is the point `along` her right upper arm (a little out from its axis, toward
## the partner), the partner's upper body leans forward from the spine just far enough to reach it (LEAN_MAX at
## most, eased), and the right arm is solved to it (ReachIK.apply_side: the shoulder-elbow-wrist chain, the palm
## on the target, the elbow kept in the clip's plane). It follows her whatever she is doing, so her flinches and the
## backward recoil move the held arm with her. `hold` (0..1) is how far the hand is on the arm; the owner eases it
## in as the partner arrives.

## Where on her upper arm the hand takes hold: 0 the shoulder, 1 the elbow.
@export var along := 0.45
## m out from the arm's axis toward the partner: the arm's thickness, so the palm lies on it.
@export var grip_out := 0.04
@export var lean_max := deg_to_rad(35.0)
## rad / s the lean follows what the reach asks for.
@export var lean_rate := 1.6
@export_range(0.0, 1.0) var hold := 0.0
var lead: Skeleton3D
## The lift on her arm (TandemArmLift): where her raised bicep is. Without one her upper arm is read from her bones.
var lead_lift: Node   # a TandemArmLift (typed loosely: a new class_name is unknown until the editor rescans)
## The lean now (rad) and the last frame's palm miss (m), for tests.
var lean := 0.0
var palm_miss := 0.0

const SPINE := ["spinea", "spineb", "spinec"]

var _spine_idx: Array = []
var _last_us := 0


func _process_modification() -> void:
	var sk := get_skeleton()
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_us) / 1.0e6, 0.0, 0.1) if _last_us > 0 else 0.0
	_last_us = now
	if sk == null or not is_instance_valid(lead) or hold <= 0.0:
		lean = move_toward(lean, 0.0, lean_rate * dt)
		return
	var ids := _bones(sk, "r")
	if ids.is_empty():
		return
	var target := sk.global_transform.affine_inverse() * _bicep_world(sk)
	_lean_toward(sk, ids, target, dt)
	apply_side(sk, "r", target, hold)
	palm_miss = sk.get_bone_global_pose(int(ids[3])).origin.distance_to(target)


## The point on her right upper arm the hand takes hold of, in world space.
func _bicep_world(sk: Skeleton3D) -> Vector3:
	var p: Vector3
	if is_instance_valid(lead_lift) and lead_lift.bicep_world != Vector3.INF:
		p = lead_lift.bicep_world
	else:
		var a := lead.find_bone("r_shoulder")
		var b := lead.find_bone("r_elbow")
		if a < 0 or b < 0:
			return sk.global_position
		var pa := lead.global_transform * lead.get_bone_global_pose(a).origin
		var pb := lead.global_transform * lead.get_bone_global_pose(b).origin
		p = pa.lerp(pb, along)
	var mine := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("r_shoulder")).origin
	return p + (mine - p).normalized() * grip_out


## Leans the partner's spine forward, the least that brings the shoulder within reach of the target.
func _lean_toward(sk: Skeleton3D, ids: Array, target: Vector3, dt: float) -> void:
	if _spine_idx.is_empty():
		for n: String in SPINE:
			var i := sk.find_bone(n)
			if i >= 0:
				_spine_idx.append(i)
	if _spine_idx.is_empty():
		return
	var sh: Vector3 = sk.get_bone_global_pose(int(ids[0])).origin
	var el: Vector3 = sk.get_bone_global_pose(int(ids[1])).origin
	var wr: Vector3 = sk.get_bone_global_pose(int(ids[2])).origin
	var hand: Vector3 = sk.get_bone_global_pose(int(ids[3])).origin - wr
	# the arm's reach is the shoulder to the wrist; the wrist has to get to the target less the hand
	var reach := (sh.distance_to(el) + el.distance_to(wr)) * MAX_REACH * 0.97
	var pivot: Vector3 = sk.get_bone_global_pose(int(_spine_idx[0])).origin
	var axis := _right_axis(sk)
	var sign := 1.0
	if _gap(target, pivot, axis, 0.05, sh, hand) > _gap(target, pivot, axis, 0.0, sh, hand):
		sign = -1.0   # forward is the direction that closes the distance
	var want := 0.0
	if _gap(target, pivot, axis, 0.0, sh, hand) > reach:
		want = lean_max
		var step := deg_to_rad(2.0)
		var th := step
		while th <= lean_max:
			if _gap(target, pivot, axis, sign * th, sh, hand) <= reach:
				want = th
				break
			th += step
	lean = move_toward(lean, want * hold, lean_rate * dt)
	if lean <= 1e-4:
		return
	var each := sign * lean / float(_spine_idx.size())
	for i: int in _spine_idx:
		var g := sk.get_bone_global_pose(i)
		sk.set_bone_global_pose(i, Transform3D(Basis(axis, each) * g.basis, g.origin))


## The distance from the shoulder to where the wrist must be (the target less the hand) after leaning `th` about `axis`.
func _gap(target: Vector3, pivot: Vector3, axis: Vector3, th: float, sh: Vector3, hand: Vector3) -> float:
	var r := Basis(axis, th)
	return (target - r * hand).distance_to(pivot + r * (sh - pivot))


## The skeleton-space axis across the partner's shoulders, horizontal (what a forward lean turns about).
func _right_axis(sk: Skeleton3D) -> Vector3:
	var r := sk.find_bone("r_shoulder")
	var l := sk.find_bone("l_shoulder")
	var v := sk.get_bone_global_pose(r).origin - sk.get_bone_global_pose(l).origin
	v.y = 0.0
	return v.normalized() if v.length() > 1e-5 else Vector3.RIGHT
