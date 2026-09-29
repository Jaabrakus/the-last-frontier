class_name TriggerFinger
extends SkeletonModifier3D
## The right index on the musket's trigger (the user 2026-09-29: "the right hand index finger should be on the
## trigger"). After the arms and the hands' IK (PlayerAnim adds it after them; CharacterBodyMesh stays last), the index's
## three joints are turned from the pose they have (the fist round the wrist of the stock) until its tip rests on the
## back of the trigger: a curl about the knuckles' line and a small swing to the side, searched for the nearest reach.
## PlayerAnim sets `wanted` each step (the musket in the right hand, held as the gun: carried, aimed and fired; not
## hands free, not in the middle carry or with the torch, not reloading or switching); the finger eases in and out
## over EASE_S. Nothing moves when the trigger is out of the finger's reach (MAX_REACH_M).

## The back edge of the trigger blade in the musket model's frame (the iron under the wrist of the stock: z -0.094..
## -0.049, y -0.063..-0.020), from where it leaves the stock down to near its end: the tip rests on the nearest of it.
const TRIGGER := [Vector3(0.0, -0.024, -0.049), Vector3(0.0, -0.056, -0.053)]
const EASE_S := 0.15
const MAX_REACH_M := 0.035
## The search: the curl at the first joint and at the other two (rad each), the swing to the side at the first. A
## coarse grid (COARSE) when the finger has no fit yet or the last one is worse than REFIT_M; else a few rounds of steps
## (FINE) from the last fit.
const CURL_A := Vector2(-1.0, 1.3)
const CURL_BC := Vector2(-0.7, 1.5)
const SWING := 0.6
const COARSE := 0.2
const FINE := 0.03
const REFIT_M := 0.012

var wanted := false
## The model on the right hand's prop bone (FrontierPlayer.musket_offset).
var offset := Transform3D()
## Where the tip ended up from the trigger in the last step (m; tests), INF when the finger was left alone.
var last_gap := INF

var _w := 0.0
var _last_us := 0
var _joints := PackedInt32Array()
var _pinky := -1
var _prop := -1
var _fit := Vector3.INF   ## the last fit: (curl a, curl b and c, swing)


func _setup(sk: Skeleton3D) -> bool:
	if _joints.size() == 3:
		return true
	_joints.clear()
	for nm: String in ["r_indexa", "r_indexb", "r_indexc"]:
		var b := sk.find_bone(nm)
		if b < 0:
			return false
		_joints.append(b)
	_pinky = sk.find_bone("r_pinkya")
	_prop = sk.find_bone("r_hand_prop_attachment")
	return _pinky >= 0 and _prop >= 0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or not _setup(sk):
		return
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_us) / 1e6, 0.0, 0.1) if _last_us > 0 else 0.0
	_last_us = now
	_w = move_toward(_w, 1.0 if wanted else 0.0, dt / EASE_S if dt > 0.0 else 1.0)
	last_gap = INF
	if _w <= 0.0:
		return
	var ga := sk.get_bone_global_pose(_joints[0])
	var gb := sk.get_bone_global_pose(_joints[1])
	var gc := sk.get_bone_global_pose(_joints[2])
	var model := sk.get_bone_global_pose(_prop) * offset
	var t0: Vector3 = model * (TRIGGER[0] as Vector3)
	var t1: Vector3 = model * (TRIGGER[1] as Vector3)
	var hinge := (sk.get_bone_global_pose(_pinky).origin - ga.origin).normalized()
	var along := (gb.origin - ga.origin).normalized()
	var swing_axis := hinge.cross(along).normalized()
	var lb := ga.affine_inverse() * gb
	var lc := gb.affine_inverse() * gc
	# the tip: past the last joint as far as the middle piece is long, in the last piece's own direction
	var tip_dir := gb.basis.inverse() * (gc.origin - gb.origin)
	var tip_len := tip_dir.length() * 0.85
	tip_dir = tip_dir.normalized()
	var cost := func(q: Vector3) -> float:
		var ch := _chain(ga, lb, lc, hinge, swing_axis, q)
		var tip: Vector3 = (ch[2] as Transform3D).origin + (ch[2] as Transform3D).basis * tip_dir * tip_len
		return tip.distance_to(Geometry3D.get_closest_point_to_segment(tip, t0, t1))
	var fit := _fit
	var gap: float = cost.call(fit) if fit.x < INF else INF
	if gap > REFIT_M:
		var sa := CURL_A.x
		while sa <= CURL_A.y + 1e-6:
			var sb := CURL_BC.x
			while sb <= CURL_BC.y + 1e-6:
				var f := -SWING
				while f <= SWING + 1e-6:
					var d: float = cost.call(Vector3(sa, sb, f))
					if d < gap:
						gap = d
						fit = Vector3(sa, sb, f)
					f += COARSE
				sb += COARSE
			sa += COARSE
	for round in 4:
		var moved := false
		for axis in 3:
			for sgn: float in [-1.0, 1.0]:
				var q := fit
				q[axis] += sgn * FINE
				var d: float = cost.call(q)
				if d < gap:
					gap = d
					fit = q
					moved = true
		if not moved:
			break
	_fit = fit
	var best := [gap, fit]
	if float(best[0]) > MAX_REACH_M:
		return
	last_gap = float(best[0])
	var solved := _chain(ga, lb, lc, hinge, swing_axis, best[1] as Vector3)
	for k in 3:
		var b := _joints[k]
		var parent := sk.get_bone_global_pose(sk.get_bone_parent(b)) if k == 0 else solved[k - 1] as Transform3D
		var local := (parent.basis.inverse() * (solved[k] as Transform3D).basis).get_rotation_quaternion()
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(local, _w).normalized())


## The index's three joints turned by q: the first q.x and the other two q.y each (rad, about the knuckles' line: +
## closes the finger), the first swung q.z (rad) to the side: their globals.
static func _chain(ga: Transform3D, lb: Transform3D, lc: Transform3D, hinge: Vector3, swing_axis: Vector3, q: Vector3) -> Array:
	var ra := Basis(hinge, q.x) * Basis(swing_axis, q.z)
	var a := Transform3D(ra * ga.basis, ga.origin)
	var h := (ra * hinge).normalized()
	var b := a * lb
	b = Transform3D(Basis(h, q.y) * b.basis, b.origin)
	var c := b * lc
	c = Transform3D(Basis(h, q.y) * c.basis, c.origin)
	return [a, b, c]
