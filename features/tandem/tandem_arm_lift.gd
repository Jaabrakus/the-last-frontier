class_name TandemArmLift
extends PalmReachIK
## The crawler's RIGHT arm held up by her tandem partner: her right upper arm is raised back and a little out from
## her side, and her forearm hangs from the elbow, so the arm stands clear of her body where a hand can hold it
## (lifting the palm and leaving the elbow to the solver tucked it into her flank). The two bones are aimed directly
## (`upper_dir`, `fore_dir`, in the rig's own space: +Z forward, +Y up, -X her right), `lift` of the way from what the
## clip does. It works on her clip's own pose every frame, so the lift goes with her whatever she does (her flinches
## and the backward recoil). Put on the CRAWLER's skeleton (before the body
## mesh, as the game's other PalmReachIK). Her chest also turns slightly to her right, which brings her right shoulder
## and arm back toward her partner's hand. `lift` (0..1) is how far it is raised and turned; the owner eases it in as the
## partner takes hold. After solving it publishes `bicep_world`, the point on the raised upper arm her partner's hand
## holds (TandemArmHold reads it), so the two stay together.

## Where her upper arm points (shoulder to elbow) and her forearm (elbow to wrist) when the arm is held up, in the
## rig's own space: the upper arm back, well up (about 40 deg above level) and a little out to her right; the forearm
## carries on nearly straight from it (about 27 deg above level: a slight bend at the elbow).
@export var upper_dir := Vector3(-0.30, 0.65, -0.70)
@export var fore_dir := Vector3(-0.32, 0.45, -0.83)
## How far her right shoulder moves toward her left, across toward her spine (m). Positive is toward her left; the
## arm is solved after it, so it goes with the shoulder.
@export var shoulder_left := 0.04
## How far her torso rolls about its own long axis, right side up (rad, shared over the upper spine): her chest turns
## open toward her right, and her right shoulder goes up with it.
@export var chest_roll := deg_to_rad(30.0)
## How far her right shoulder joint rides up on top of that (rad of clavicle roll).
@export var shoulder_up := deg_to_rad(15.0)
## How far her chest turns to her right (rad), shared over the upper spine.
@export var twist := deg_to_rad(14.0)
## Where on the upper arm the partner takes hold: 0 the shoulder, 1 the elbow.
@export var along := 0.45
@export_range(0.0, 1.0) var lift := 0.0
## World position of the held point on her right upper arm, after the lift (INF before the first frame).
var bicep_world := Vector3.INF

const CHEST := ["spineb", "spinec", "spined"]

var _chest_idx: Array = []


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var ids := _bones(sk, "r")
	if ids.is_empty():
		return
	if lift > 0.0:
		_roll_chest(sk, ids)
		_turn_chest(sk, ids)
		_shift_shoulder(sk, ids)
		_aim_arm(sk, ids)
	var a: Vector3 = sk.get_bone_global_pose(int(ids[0])).origin
	var b: Vector3 = sk.get_bone_global_pose(int(ids[1])).origin
	bicep_world = sk.global_transform * a.lerp(b, along)


## Turns her chest to her right about the vertical (before the arm is solved, so the arm follows). "Right" is the way
## her right shoulder goes back: toward her partner behind her.
func _turn_chest(sk: Skeleton3D, ids: Array) -> void:
	if _chest_idx.is_empty():
		for n: String in CHEST:
			var i := sk.find_bone(n)
			if i >= 0:
				_chest_idx.append(i)
	if _chest_idx.is_empty() or twist == 0.0:
		return
	var pivot: Vector3 = sk.get_bone_global_pose(int(_chest_idx[0])).origin
	var rs: Vector3 = sk.get_bone_global_pose(int(ids[0])).origin - pivot
	var sign := -1.0 if (Basis(Vector3.UP, 0.05) * rs).z > rs.z else 1.0   # the rig faces +Z: back is -Z
	var each := sign * twist * lift / float(_chest_idx.size())
	for i: int in _chest_idx:
		var g := sk.get_bone_global_pose(i)
		sk.set_bone_global_pose(i, Transform3D(Basis(Vector3.UP, each) * g.basis, g.origin))


## Aims the upper arm and then the forearm at their directions, `lift` of the way from the clip's own (the twist
## helpers and the hand follow their bones; the body mesh, last, skins the result).
func _aim_arm(sk: Skeleton3D, ids: Array) -> void:
	var sh := int(ids[0])
	var el := int(ids[1])
	var wr := int(ids[2])
	var gs := sk.get_bone_global_pose(sh)
	var a := gs.origin
	var b := sk.get_bone_global_pose(el).origin
	var now := (b - a).normalized()
	var want := now.slerp(upper_dir.normalized(), lift)
	if now.dot(want) < 0.9999:
		sk.set_bone_global_pose(sh, Transform3D(Basis(Quaternion(now, want)) * gs.basis, a))
	var ge := sk.get_bone_global_pose(el)
	var c := sk.get_bone_global_pose(wr).origin
	var fnow := (c - ge.origin).normalized()
	var fwant := fnow.slerp(fore_dir.normalized(), lift)
	if fnow.dot(fwant) < 0.9999:
		sk.set_bone_global_pose(el, Transform3D(Basis(Quaternion(fnow, fwant)) * ge.basis, ge.origin))


## Her right shoulder joint goes up and toward her left: the clavicle rolls about her fore-aft axis so the joint rides up
## (it lifts and opens her chest), then the joint moves `shoulder_left` along the line of her shoulders (a clavicle that
## points sideways would only swing the joint forward and back when turned about the vertical). The arm hangs from it
## and follows; the few centimetres are taken up by the skin.
func _shift_shoulder(sk: Skeleton3D, ids: Array) -> void:
	var l := sk.find_bone("l_shoulder")
	var c := sk.find_bone("r_clavicle")
	if l < 0:
		return
	var sh := int(ids[0])
	var to_left := sk.get_bone_global_pose(l).origin - sk.get_bone_global_pose(sh).origin
	to_left.y = 0.0
	if to_left.length() < 1e-4:
		return
	var left_dir := to_left.normalized()
	if c >= 0 and shoulder_up != 0.0:
		var gc := sk.get_bone_global_pose(c)
		var rel := sk.get_bone_global_pose(sh).origin - gc.origin
		var fore := left_dir.cross(Vector3.UP).normalized()   # her left x up is forward
		var sign := 1.0 if ((Basis(fore, 0.05) * rel) - rel).y > 0.0 else -1.0
		sk.set_bone_global_pose(c, Transform3D(Basis(fore, sign * shoulder_up * lift) * gc.basis, gc.origin))
	if shoulder_left != 0.0:
		var gs := sk.get_bone_global_pose(sh)
		sk.set_bone_global_pose(sh, Transform3D(gs.basis, gs.origin + left_dir * shoulder_left * lift))


## Rolls her upper body about her spine's own long axis so her right side comes up and her chest turns open toward her
## right (on all fours the torso is level: turning it is this roll, not a swing about the vertical).
func _roll_chest(sk: Skeleton3D, ids: Array) -> void:
	if _chest_idx.is_empty():
		for n: String in CHEST:
			var i := sk.find_bone(n)
			if i >= 0:
				_chest_idx.append(i)
	var low := sk.find_bone("spinea")
	var high := sk.find_bone("spined")
	if _chest_idx.is_empty() or low < 0 or high < 0 or chest_roll == 0.0:
		return
	var axis := (sk.get_bone_global_pose(high).origin - sk.get_bone_global_pose(low).origin).normalized()
	var rel: Vector3 = sk.get_bone_global_pose(int(ids[0])).origin - sk.get_bone_global_pose(int(_chest_idx[0])).origin
	var sign := 1.0 if ((Basis(axis, 0.05) * rel) - rel).y > 0.0 else -1.0   # her right side goes up
	var each := sign * chest_roll * lift / float(_chest_idx.size())
	for i: int in _chest_idx:
		var g := sk.get_bone_global_pose(i)
		sk.set_bone_global_pose(i, Transform3D(Basis(axis, each) * g.basis, g.origin))
