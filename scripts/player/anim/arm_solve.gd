class_name ArmSolve
extends RefCounted
## Places a hand's prop bone at a whole transform (push n01c: the torch's axe and raised holds, the long gun gripped
## in the middle). The hand takes the wanted rotation; the arm is a two-bone solve (shoulder, elbow) whose elbow is
## chosen on its circle so the forearm lines up with the hand as Actor_B's rest pose has them: the wrist stays as
## straight as the reach allows (ReachIK keeps the clip's elbow plane instead, and turning only the hand bent the
## wrist 45-90 degrees off the forearm in these holds). The elbow never goes in toward the body: past ELBOW_IN_MAX
## (m, off the shoulder-hand line toward the body's middle) it is turned out and back.
##
##   ArmSolve.place(sk, "l", prop_xf, weight)   # skeleton space; returns the wrist's bend off the rest (deg)
##
## The forearm twist helpers follow the hand (CharacterBodyMesh, last in the stack).

## Never stretch the arm to more than this fraction of its length (a straight arm pops).
const MAX_REACH := 0.995
## The elbow may sit this far (m) from the shoulder-hand line toward the body's middle; further it is turned out and
## back (ELBOW_OUT / ELBOW_BACK, the character's frame: the rig faces +Z, its left is +X).
const ELBOW_IN_MAX := 0.02
const ELBOW_OUT := 0.5
const ELBOW_BACK := 0.85
## How far the forearm may be from the hand's neutral line before the elbow takes the clip's own side instead (deg): a
## hand pointing its fingers straight at the shoulder has no neutral elbow.
const ALIGN_MIN_DEG := 1.0

static var _cache := {}      ## skeleton instance id + side -> {ids, forearm in the wrist's frame, bend at rest}


## Puts the prop bone of `side` `w` of the way from where it is to `want` (skeleton space). Returns the wrist's bend
## off the rest pose's (deg; 0 = as straight as at rest).
static func place(sk: Skeleton3D, side: String, want: Transform3D, w: float) -> float:
	var c := _info(sk, side)
	if c.is_empty() or w <= 0.0:
		return 0.0
	var sh: int = c.ids[0]
	var el: int = c.ids[1]
	var wr: int = c.ids[2]
	var pr: int = c.ids[3]
	var gs := sk.get_bone_global_pose(sh)
	var ge := sk.get_bone_global_pose(el)
	var gw := sk.get_bone_global_pose(wr)
	var gp := sk.get_bone_global_pose(pr)
	var cur := gp.orthonormalized()
	var p_want := cur.interpolate_with(want.orthonormalized(), clampf(w, 0.0, 1.0))
	# the wrist that puts the prop there (the prop rides rigidly on the wrist through the palm)
	var rel := gw.affine_inverse() * gp
	var wb := (p_want.basis * rel.basis.orthonormalized().inverse()).orthonormalized()
	var w_pos := p_want.origin - wb * rel.origin
	var a := gs.origin
	var la := a.distance_to(ge.origin)
	var lb := ge.origin.distance_to(gw.origin)
	var ac := w_pos - a
	var d := ac.length()
	var lt := clampf(d, absf(la - lb) + 1e-4, (la + lb) * MAX_REACH)
	var axis := ac / d if d > 1e-6 else (gw.origin - a).normalized()
	var tw := a + axis * lt
	# the elbow's circle about the shoulder -> wrist line
	var x := (la * la - lb * lb + lt * lt) / (2.0 * lt)
	var r := sqrt(maxf(la * la - x * x, 0.0))
	var cc := a + axis * x
	# the elbow the hand's neutral forearm asks for: back along the forearm from the wrist
	var fore := (wb * (c.forearm as Vector3)).normalized()
	var ideal := tw - fore * lb
	var perp := (ideal - cc) - axis * (ideal - cc).dot(axis)
	var clip_perp := (ge.origin - cc) - axis * (ge.origin - cc).dot(axis)
	if perp.length() < 1e-4 or rad_to_deg(fore.angle_to(axis)) < ALIGN_MIN_DEG:
		perp = clip_perp
	if perp.length() < 1e-5:
		perp = axis.cross(Vector3.UP)
	perp = perp.normalized()
	# never in toward the body
	var out := Vector3.RIGHT if side == "l" else Vector3.LEFT
	if perp.dot(-out) * r > ELBOW_IN_MAX:
		var pref := out * ELBOW_OUT + Vector3.FORWARD * ELBOW_BACK
		pref = (pref - axis * pref.dot(axis))
		if pref.length() > 1e-4:
			var k := clampf((perp.dot(-out) * r - ELBOW_IN_MAX) / 0.08, 0.0, 1.0)
			perp = perp.slerp(pref.normalized(), k).normalized()
	var e_new := cc + perp * r
	var q1 := ReachIK._arc((ge.origin - a).normalized(), (e_new - a).normalized())
	sk.set_bone_global_pose(sh, Transform3D(Basis(q1) * gs.basis, a))
	var ge2 := sk.get_bone_global_pose(el)
	var c2 := sk.get_bone_global_pose(wr).origin
	var q2 := ReachIK._arc((c2 - ge2.origin).normalized(), (tw - ge2.origin).normalized())
	sk.set_bone_global_pose(el, Transform3D(Basis(q2) * ge2.basis, ge2.origin))
	sk.set_bone_global_pose(wr, Transform3D(wb, sk.get_bone_global_pose(wr).origin))
	# the wrist's bend now, off the rest's
	var f2 := (tw - e_new).normalized()
	return rad_to_deg(f2.angle_to(fore))


## `want` (a prop rotation, skeleton space) turned about its own `axis_local` (the prop frame: what the fist holds runs
## along it, a torch's haft, a gun's barrel) so the hand's neutral forearm points as near `pref` as that turn allows:
## the hand wraps round the thing it holds from the side the arm comes from. Returns the turn about the axis (rad).
static func roll_toward(sk: Skeleton3D, side: String, want: Basis, axis_local: Vector3, pref: Vector3) -> float:
	var c := _info(sk, side)
	if c.is_empty():
		return 0.0
	var gw := sk.get_bone_global_pose(c.ids[2])
	var gp := sk.get_bone_global_pose(c.ids[3])
	var rel := gw.affine_inverse() * gp
	var f_prop := rel.basis.orthonormalized().inverse() * (c.forearm as Vector3)
	var a := (want * axis_local).normalized()
	var v := want * f_prop
	var vp := v - a * v.dot(a)
	var pp := pref - a * pref.dot(a)
	if vp.length() < 1e-4 or pp.length() < 1e-4:
		return 0.0
	return vp.signed_angle_to(pp, a)


## The hand's neutral forearm (from the rest pose): the elbow -> wrist line in the wrist's frame.
static func _info(sk: Skeleton3D, side: String) -> Dictionary:
	var key := "%d:%s" % [sk.get_instance_id(), side]
	if _cache.has(key):
		return _cache[key]
	var ids: Array = []
	for bn: String in ReachIK.CHAINS[side]:
		var b := sk.find_bone(bn)
		if b < 0:
			_cache[key] = {}
			return {}
		ids.append(b)
	var we := sk.get_bone_global_rest(ids[1])
	var ww := sk.get_bone_global_rest(ids[2])
	var f := ww.basis.orthonormalized().inverse() * (ww.origin - we.origin).normalized()
	_cache[key] = {"ids": ids, "forearm": f}
	return _cache[key]
