class_name SwayArm
extends SkeletonModifier3D
## The casting arm of a Sway lock (SwayCaster; docs/main_story.md 11.4: "the casting hand reaches out and trembles as the
## lock nears full"), the JogAimArm way: after every other modifier (CharacterBodyMesh stays last), the arm of `side`
## ("r" with the hands free, "l" beside a pistol) reaches out, its elbow opened by REACH of its bend, and is turned about
## its shoulder so the palm points from the shoulder at `target` (skeleton space) in PASSES passes, by up to MAX_DEG; the
## head looks at it (NECK_SHARE in the neck). `tremble` (0..1, near full) shakes the arm a little; `shove` (0..1, the
## release) opens the elbow straight and thrusts the arm out SHOVE_M. `weight` eases it all in and out; off (0) it does
## nothing.

const MAX_DEG := 110.0
const PASSES := 3
## The share of the elbow's bend taken out while locking (the arm reaching out, not locked straight).
const REACH := 0.6
const SHOVE_M := 0.045
const TREMBLE_DEG := 1.6
const HEAD_MAX_DEG := 60.0
const NECK_SHARE := 0.4
const HEAD_SHARE := 0.75

var side := "r"
var weight := 0.0
var target := Vector3.ZERO
var tremble := 0.0
var shove := 0.0

## The palm where this arm left it last (skeleton space; INF before), and its side: the thread starts there.
var last_hand := Vector3.INF
var last_side := ""
var _ids := {}                      ## side -> [shoulder, elbow, wrist, palm] (-1 missing)
var _neck := -2
var _head := -1
var _face_local := Vector3.BACK


func _process_modification() -> void:
	if weight <= 0.001:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	var ids := _bones(sk, side)
	if ids.is_empty():
		return
	var sh: int = ids[0]
	var el: int = ids[1]
	var wr: int = ids[2]
	var tip: int = ids[3] if int(ids[3]) >= 0 else wr
	# the elbow opened: the forearm turned toward the upper arm's line
	var gs := sk.get_bone_global_pose(sh)
	var ge := sk.get_bone_global_pose(el)
	var gw := sk.get_bone_global_pose(wr)
	var u := ge.origin - gs.origin
	var f := gw.origin - ge.origin
	var bend_axis := f.cross(u)
	if bend_axis.length_squared() > 1e-10:
		var open := clampf(weight * lerpf(REACH, 1.0, shove), 0.0, 1.0)
		sk.set_bone_global_pose(el, Transform3D(Basis(bend_axis.normalized(), f.angle_to(u) * open) * ge.basis, ge.origin))
	# the arm on the target
	for i in PASSES:
		var s := sk.get_bone_global_pose(sh)
		var d := sk.get_bone_global_pose(tip).origin - s.origin
		var want := target - s.origin
		if want.length_squared() < 0.04 or d.length_squared() < 1e-6:
			break
		d = d.normalized()
		want = want.normalized()
		var axis := d.cross(want)
		if axis.length_squared() < 1e-10:
			break
		var ang := minf(d.angle_to(want), deg_to_rad(MAX_DEG)) * weight
		sk.set_bone_global_pose(sh, Transform3D(Basis(axis.normalized(), ang) * s.basis, s.origin))
	var s2 := sk.get_bone_global_pose(sh)
	var out := (target - s2.origin).normalized() if (target - s2.origin).length_squared() > 1e-6 else Vector3.ZERO
	# the tremble near full, and the shove out on release
	if tremble > 0.0 and out != Vector3.ZERO:
		var t := Time.get_ticks_msec() * 0.001
		var side_ax := out.cross(Vector3.UP)
		if side_ax.length_squared() < 1e-6:
			side_ax = Vector3.RIGHT
		side_ax = side_ax.normalized()
		var up_ax := side_ax.cross(out).normalized()
		var a := deg_to_rad(TREMBLE_DEG) * tremble * weight
		var turn := Basis(side_ax, a * sin(t * 37.0) * 0.8) * Basis(up_ax, a * sin(t * 29.0 + 1.3))
		s2 = Transform3D(turn * s2.basis, s2.origin)
	if shove > 0.0 and out != Vector3.ZERO:
		s2.origin += out * SHOVE_M * shove
	sk.set_bone_global_pose(sh, s2)
	last_hand = sk.get_bone_global_pose(tip).origin
	last_side = side
	_look(sk)


## The palm (else the wrist) of `side` in the skeleton's space (INF when the rig has none).
func hand_pos(sk: Skeleton3D, s: String) -> Vector3:
	if weight > 0.001 and s == last_side and last_hand != Vector3.INF:
		return last_hand
	var ids := _bones(sk, s)
	if ids.is_empty():
		return Vector3.INF
	var tip: int = ids[3] if int(ids[3]) >= 0 else ids[2]
	return sk.get_bone_global_pose(tip).origin


func _bones(sk: Skeleton3D, s: String) -> Array:
	if not _ids.has(s):
		var a := [sk.find_bone(s + "_shoulder"), sk.find_bone(s + "_elbow"), sk.find_bone(s + "_wrist"), sk.find_bone(s + "_palm")]
		_ids[s] = [] if int(a[0]) < 0 or int(a[1]) < 0 or int(a[2]) < 0 else a
	return _ids[s]


## The head turned toward the target (the neck and the head sharing the turn), as JogAimArm's.
func _look(sk: Skeleton3D) -> void:
	if _neck == -2:
		_neck = sk.find_bone("neck")
		_head = sk.find_bone("headb")
		if _head >= 0:
			_face_local = (sk.get_bone_global_rest(_head).basis.orthonormalized().inverse() * Vector3(0, 0, 1)).normalized()
	if _head < 0:
		return
	for pair: Array in [[_neck, NECK_SHARE], [_head, 1.0]]:
		var b: int = pair[0]
		if b < 0:
			continue
		var hg := sk.get_bone_global_pose(_head)
		var face := (hg.basis.orthonormalized() * _face_local).normalized()
		var want := target - hg.origin
		if want.length_squared() < 0.04:
			return
		want = want.normalized()
		var axis := face.cross(want)
		if axis.length_squared() < 1e-10:
			return
		var ang := minf(face.angle_to(want), deg_to_rad(HEAD_MAX_DEG)) * weight * HEAD_SHARE * float(pair[1])
		var g := sk.get_bone_global_pose(b)
		sk.set_bone_global_pose(b, Transform3D(Basis(axis.normalized(), ang) * g.basis, g.origin))
