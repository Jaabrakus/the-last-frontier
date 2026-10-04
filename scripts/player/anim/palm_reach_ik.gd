class_name PalmReachIK
extends ReachIK
## ReachIK solved for the palm (l_palm / r_palm) instead of the hand's prop bone: with the hands free the prop bones
## are animated well away from the hands (they follow where a held prop would be), so a reach for them misses the
## hand. For what a bare hand holds: the rope of a carcass dragged on foot (FootDrag, the left hand), the handles of
## a wheelbarrow (Wheelbarrow, both hands).
##
## The steady hold (`steady`: the wheelbarrow's handles; the user 2026-10-03: "also when we push the wheel barrow
## fix the elbows so they dont do a chicken dance"). The plain reach keeps the clip's elbow side and the hand's world
## rotation, and under the barrow the clip is the jog's free arm swing: its elbows swing back and forth about the
## shoulder -> handle line, so the solved elbows went out and up and over the top with every stride (measured
## 2026-10-03: the left elbow 28-125 deg off "toward the hip", 14 cm of sideways swing, up to 6 cm in a frame).
## Held steady:
##  - the elbow takes a side of its own, steady_side(): down toward the hips (and back, DOWN_BACK), turned
##    ELBOW_OUT_DEG out from the body, in the character's frame, not the clip's swinging elbow; the clip's side comes
##    in over the weight (taking and letting go of the handles turn it, no pop);
##  - the hand rides on the forearm as the clip bends it at the wrist (the elbow -> palm piece is solved as one),
##    not at the clip's world rotation, which turned the fist round the grip with the swing;
##  - the upper arm keeps its own twist about the arm's bend plane (a shortest-arc turn spun it with the swing).
## The shoulder joints and the arm's lengths it last solved with are kept (shoulder_at, upper_len, lower_len): the
## wheelbarrow puts its grips where the arms hold them a little bent (Wheelbarrow.ELBOW_BEND_DEG).

## The steady hold (see above); off: the plain reach (FootDrag's rope hand).
var steady := false
## The steady elbow's side about the shoulder -> palm line (deg): 0 = down toward the hips (and back by DOWN_BACK),
## + = out from the body.
const ELBOW_OUT_DEG := 22.0
## "Down" for the steady elbow leans back this much (a part of the character's back to one of its down): the elbows of a
## barrow's pusher point down and back past the hips.
const DOWN_BACK := 0.6

## At the last steady solve, per side (skeleton space, in its units: the body's stature scales the rig): the shoulder
## joint, the upper arm's length and the elbow -> palm length. INF / 0 before the first.
var shoulder_at := {"l": Vector3.INF, "r": Vector3.INF}
var upper_len := {"l": 0.0, "r": 0.0}
var lower_len := {"l": 0.0, "r": 0.0}

var _palm_idx := {}


func _bones(sk: Skeleton3D, side: String) -> Array:
	if not _palm_idx.has(side):
		var out: Array = []
		for bn: String in ["shoulder", "elbow", "wrist", "palm"]:
			var b := sk.find_bone("%s_%s" % [side, bn])
			if b < 0:
				_palm_idx[side] = []
				return []
			out.append(b)
		_palm_idx[side] = out
	return _palm_idx[side]


func apply_side(sk: Skeleton3D, side: String, target: Vector3, w: float) -> Vector3:
	if not steady:
		return super(sk, side, target, w)
	return _apply_steady(sk, side, target, w)


## The steady hold's solve (see the header): the palm `w` of the way to `target` (skeleton space). Returns the palm's
## move.
func _apply_steady(sk: Skeleton3D, side: String, target: Vector3, w: float) -> Vector3:
	var ids := _bones(sk, side)
	if ids.is_empty():
		return Vector3.ZERO
	var sh: int = ids[0]
	var el: int = ids[1]
	var pa: int = ids[3]
	var gs := sk.get_bone_global_pose(sh)
	var ge := sk.get_bone_global_pose(el)
	var p0 := sk.get_bone_global_pose(pa).origin
	var a := gs.origin
	var b := ge.origin
	var la := a.distance_to(b)
	var lp := b.distance_to(p0)
	if la < 1e-4 or lp < 1e-4:
		return Vector3.ZERO
	shoulder_at[side] = a
	upper_len[side] = la
	lower_len[side] = lp
	# the palm's goal, within the arm's reach (the hand as the clip bends it: elbow -> palm is one piece)
	var goal := p0 + (target - p0) * w
	var ac := goal - a
	var lt := clampf(ac.length(), absf(la - lp) + 1e-4, (la + lp) * MAX_REACH)
	var dir := ac.normalized() if ac.length() > 1e-6 else (p0 - a).normalized()
	var p1 := a + dir * lt
	# the elbow's side: its own, the clip's coming in over the weight
	var pole := steady_side(side, dir)
	var clip := (b - a) - dir * (b - a).dot(dir)
	if w < 1.0 and clip.length() > 1e-5:
		clip = clip.normalized()
		pole = clip.rotated(dir, clip.signed_angle_to(pole, dir) * w).normalized()
	var cos_a := clampf((la * la + lt * lt - lp * lp) / (2.0 * la * lt), -1.0, 1.0)
	var b1 := a + dir * la * cos_a + pole * la * sqrt(maxf(1.0 - cos_a * cos_a, 0.0))
	# the upper arm: its direction, then its bend plane (shoulder, elbow, palm) where the solve puts them, so it keeps its
	# own twist about that plane (faded out as the arm, the clip's or the solved, comes straight: no plane)
	var u0 := (b - a).normalized()
	var f0 := (p0 - b).normalized()
	var u1 := (b1 - a).normalized()
	var f1 := (p1 - b1).normalized()
	var q := ReachIK._arc(u0, u1)
	var n0 := Basis(q) * u0.cross(f0)
	var n1 := u1.cross(f1)
	var k := smoothstep(0.03, 0.12, minf(n0.length(), n1.length()))
	if k > 0.0:
		var m0 := n0 - u1 * n0.dot(u1)
		var m1 := n1 - u1 * n1.dot(u1)
		if m0.length() > 1e-5 and m1.length() > 1e-5:
			q = Quaternion(u1, m0.signed_angle_to(m1, u1) * k) * q
	sk.set_bone_global_pose(sh, Transform3D(Basis(q) * gs.basis, a))
	# the forearm (the hand riding on it) hinges in that plane so the palm lands on its goal
	var ge2 := sk.get_bone_global_pose(el)
	var p2 := sk.get_bone_global_pose(pa).origin
	var q2 := ReachIK._arc((p2 - ge2.origin).normalized(), (p1 - ge2.origin).normalized())
	sk.set_bone_global_pose(el, Transform3D(Basis(q2) * ge2.basis, ge2.origin))
	last_offset[side] = sk.get_bone_global_pose(pa).origin - p0
	return last_offset[side]


## The steady elbow's side (unit, perpendicular to `dir`, the shoulder -> palm line; skeleton space, where the rig faces
## +Z and its left is +X): down toward the hips and back (DOWN_BACK), turned ELBOW_OUT_DEG out from the body.
static func steady_side(side: String, dir: Vector3) -> Vector3:
	var ref := Vector3(0.0, -1.0, -DOWN_BACK).normalized()
	var down := ref - dir * ref.dot(dir)
	if down.length() < 1e-4:
		down = Vector3(0.0, 0.0, -1.0) - dir * -dir.z
	if down.length() < 1e-4:
		return dir.cross(Vector3.UP).normalized()
	down = down.normalized()
	var out := Vector3(1.0 if side == "l" else -1.0, 0.0, 0.0)
	out = out - dir * out.dot(dir)
	out = out - down * out.dot(down)
	if out.length() < 1e-4:
		return down
	var r := deg_to_rad(ELBOW_OUT_DEG)
	return (down * cos(r) + out.normalized() * sin(r)).normalized()
