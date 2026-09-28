class_name ReachIK
extends SkeletonModifier3D
## Two-bone arm IK for the loadout handoffs (loadout_design.md 5.1.4, 8.1.6): where a stowed item's
## contact point is further from the source hand than the clip reaches, the reaching wrist is pulled by
## (target - hand prop) with a weight that the SlingRig ramps 0 -> 1 over the grab clip and 1 -> 0 over
## the first 35 % of the draw. Only the end point of the reach moves; the clip's motion and timing stay
## the source's, and the hand keeps the clip's orientation.
##
## Per side ("r" / "l"): shoulder -> elbow -> wrist, the target given for the hand prop bone
## (r_/l_hand_prop_attachment). The elbow stays in the plane of the clip's elbow (the pole). Add it to
## the Skeleton3D before CharacterBodyMesh (which keeps itself last, so the twist helpers follow the IK
## pose); in the game after PropFlipGuard and AimStabilizer.
##
##   var ik := ReachIK.new(); skeleton.add_child(ik)
##   ik.set_target("r", Callable(rig, "ik_target"), 0.5)   # Callable(side) -> Vector3 (skeleton space)

const CHAINS := {
	"r": ["r_shoulder", "r_elbow", "r_wrist", "r_hand_prop_attachment"],
	"l": ["l_shoulder", "l_elbow", "l_wrist", "l_hand_prop_attachment"],
}
## Never stretch the arm to more than this fraction of its length (a straight arm pops).
const MAX_REACH := 0.995

var _w := {"r": 0.0, "l": 0.0}
var _target := {"r": Callable(), "l": Callable()}
var _fixed := {"r": Vector3.INF, "l": Vector3.INF}
var _idx := {}
## Last applied correction (m) per side, for tests and the debug view.
var last_offset := {"r": Vector3.ZERO, "l": Vector3.ZERO}


func set_target(side: String, target: Variant, weight: float) -> void:
	_w[side] = clampf(weight, 0.0, 1.0)
	if target is Callable:
		_target[side] = target
		_fixed[side] = Vector3.INF
	elif target is Vector3:
		_fixed[side] = target
		_target[side] = Callable()


func clear(side := "") -> void:
	for s in (["r", "l"] if side == "" else [side]):
		_w[s] = 0.0
		_target[s] = Callable()
		_fixed[s] = Vector3.INF
		last_offset[s] = Vector3.ZERO


func weight(side: String) -> float:
	return float(_w.get(side, 0.0))


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for side: String in ["r", "l"]:
		if float(_w[side]) <= 0.0:
			last_offset[side] = Vector3.ZERO
			continue
		var t: Vector3 = _fixed[side]
		if t == Vector3.INF:
			var c: Callable = _target[side]
			if not c.is_valid():
				continue
			var v: Variant = c.call(side)
			if not (v is Vector3) or v == Vector3.INF:
				continue
			t = v
		apply_side(sk, side, t, float(_w[side]))


## Moves the arm of `side` so the hand prop origin goes `weight` of the way to `target` (skeleton space).
## Returns the applied offset. Public so headless tests can run it on a manually posed skeleton.
func apply_side(sk: Skeleton3D, side: String, target: Vector3, w: float) -> Vector3:
	var ids := _bones(sk, side)
	if ids.is_empty():
		return Vector3.ZERO
	var sh: int = ids[0]
	var el: int = ids[1]
	var wr: int = ids[2]
	var pr: int = ids[3]
	var gs := sk.get_bone_global_pose(sh)
	var ge := sk.get_bone_global_pose(el)
	var gw := sk.get_bone_global_pose(wr)
	var gp := sk.get_bone_global_pose(pr)
	var off := (target - gp.origin) * w
	var a := gs.origin
	var b := ge.origin
	var c := gw.origin
	var tw := c + off
	var la := a.distance_to(b)
	var lb := b.distance_to(c)
	var ac := tw - a
	var lt := clampf(ac.length(), absf(la - lb) + 1e-4, (la + lb) * MAX_REACH)
	var dir := ac.normalized() if ac.length() > 1e-6 else (c - a).normalized()
	tw = a + dir * lt
	var pole := (b - a) - dir * (b - a).dot(dir)
	if pole.length() < 1e-5:
		pole = dir.cross(Vector3.UP)
	pole = pole.normalized()
	var cos_a := clampf((la * la + lt * lt - lb * lb) / (2.0 * la * lt), -1.0, 1.0)
	var b_new := a + dir * la * cos_a + pole * la * sqrt(maxf(1.0 - cos_a * cos_a, 0.0))
	var q1 := _arc((b - a).normalized(), (b_new - a).normalized())
	sk.set_bone_global_pose(sh, Transform3D(Basis(q1) * gs.basis, a))
	var ge2 := sk.get_bone_global_pose(el)
	var c2 := sk.get_bone_global_pose(wr).origin
	var q2 := _arc((c2 - ge2.origin).normalized(), (tw - ge2.origin).normalized())
	sk.set_bone_global_pose(el, Transform3D(Basis(q2) * ge2.basis, ge2.origin))
	sk.set_bone_global_pose(wr, Transform3D(gw.basis, sk.get_bone_global_pose(wr).origin))
	last_offset[side] = sk.get_bone_global_pose(pr).origin - gp.origin
	return last_offset[side]


func _bones(sk: Skeleton3D, side: String) -> Array:
	if not _idx.has(side):
		var out: Array = []
		for bn: String in CHAINS[side]:
			var b := sk.find_bone(bn)
			if b < 0:
				_idx[side] = []
				return []
			out.append(b)
		_idx[side] = out
	return _idx[side]


static func _arc(u: Vector3, v: Vector3) -> Quaternion:
	if u.length() < 1e-6 or v.length() < 1e-6:
		return Quaternion.IDENTITY
	var d := u.dot(v)
	if d > 0.999999:
		return Quaternion.IDENTITY
	if d < -0.999999:
		var ax := u.cross(Vector3.RIGHT)
		if ax.length() < 1e-4:
			ax = u.cross(Vector3.UP)
		return Quaternion(ax.normalized(), PI)
	return Quaternion(u, v)
