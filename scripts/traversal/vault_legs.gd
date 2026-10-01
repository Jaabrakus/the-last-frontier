class_name TravVaultLegs
extends SkeletonModifier3D
## The lower half of a vault made procedural (user 2026-09-30: "procedural IK for the lower half of those vaults", both ways, switchable).
## A SkeletonModifier3D after the animation and before TraversalIK (whose plants and guards still have the last word: the take-off and
## landing feet on the real ground, no hand or foot inside the obstacle).
##   mode "adapt":      the clip's legs, corrected live: while the body is in the air over the obstacle, the knee, ankle, heel and toe of
##                      each leg are kept CLEAR_M above the obstacle's real top wherever they are over its footprint (the ankle lifted by a
##                      two-bone solve, the knee keeping its side); the obstacle's height and depth are the detected ones, not the clip's.
##   mode "procedural": the legs ignore the clip in the air: from take-off to landing the ankles follow a tuck (trailing under the hips at
##                      take-off, tucked up and forward over the top, reaching down and forward for the landing), together under the hips,
##                      knees forward; then "adapt"'s clearance on top. Eased in after the take-off and out into the landing.
##   mode "off":        the clip's legs.
## PlayerTraversal feeds it every tick of a move (feed()); nothing changes while no vault plays.

const CLEAR_M := {"knee": 0.09, "ankle": 0.07, "heel": 0.05, "ball": 0.05}
## How fast a leg's correction may grow and shrink (m/s): a lift comes in quickly, as the leg nears the top, and lets go more slowly.
const LIFT_UP_MS := 10.0
const LIFT_DOWN_MS := 3.0
## The knee's clearance starts this far (m) before the obstacle's near face; the foot's just before it (a foot lifted early, while it
## is still below the top in front of the face, is driven up the face and into the lip).
const PRE_EDGE_M := 0.06
## ... and in the procedural legs, whose tucked shin goes forward with the thigh, not back into the face.
const PROC_PRE_EDGE_M := 0.18
const FOOT_PRE_EDGE_M := 0.06
## The most the knee is raised by turning the thigh (more swings a folded shin back into the face).
const KNEE_LIFT_MAX := 0.15
## Seconds over which the procedural legs come in after the take-off and go before the landing.
const PROC_EASE_S := 0.12
## The procedural tuck, as ankle offsets from the pelvis over the flight (u 0 -> 1): (forward, up) in metres, sampled and smoothstepped.
const TUCK := [[0.0, -0.25, -0.70], [0.35, 0.05, -0.46], [0.6, 0.15, -0.44], [1.0, 0.30, -0.80]]
const LEG_HALF_GAP := 0.10
## "adapt" blends this much of the procedural tuck into the clip's legs (user: adapt alone, a few cm of lift, looked the same as off).
const ADAPT_TUCK_W := 0.5

var mode := "adapt"
## Fed per tick by PlayerTraversal.
var in_move := false
var t := 0.0
var takeoff_t := 0.0
var landing_t := 0.0
var top_y := 0.0
var face := Vector3.ZERO            ## the lip, world
var inward := Vector3.FORWARD       ## horizontal, into the obstacle
var depth := 0.4
var half_width := 3.0

var _lift := {"l": 0.0, "r": 0.0}
var _klift := {"l": 0.0, "r": 0.0}     ## the knee's own lift (the thigh turned up at the hip)
var _proc_w := 0.0
var _ids := {}


func feed(on: bool, p_mode: String, move_t: float, windows: Dictionary, info: TravObstacleInfo) -> void:
	mode = p_mode
	in_move = on and info != null
	if not in_move:
		return
	t = move_t
	takeoff_t = float(windows.get("takeoff", 0.0))
	landing_t = float(windows.get("landing", takeoff_t + 1.0))
	top_y = info.top_point.y if info.top_point != Vector3.ZERO else info.face_point.y
	face = info.face_point
	inward = Vector3(-info.normal.x, 0.0, -info.normal.z).normalized() if info.normal != Vector3.ZERO else Vector3.FORWARD
	depth = minf(float(info.depth), 3.0)
	half_width = minf(float(info.width) * 0.5, 3.0) if is_finite(float(info.width)) else 3.0


func _bone(sk: Skeleton3D, name: String) -> int:
	if not _ids.has(name):
		_ids[name] = sk.find_bone(name)
	return int(_ids[name])


func _dt() -> float:
	return get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()


## How far up a point must go to clear the obstacle's top by `clear` (0 when it is not over the footprint or is clear already).
func _need(p: Vector3, clear: float, pre := FOOT_PRE_EDGE_M) -> float:
	var rel := p - face
	var d := rel.dot(inward)
	var lat := absf(rel.dot(Vector3.UP.cross(inward)))
	# (from `pre` before the near face: a knee swinging in toward the top is lifted before it reaches the edge, not after)
	if d < -pre or d > depth + 0.06 or lat > half_width:
		return 0.0
	return maxf(0.0, top_y + clear - p.y)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var dt := _dt()
	var in_air := in_move and mode != "off" and t > takeoff_t and t < landing_t
	var gx := sk.global_transform
	var inv := gx.affine_inverse()
	# the procedural legs' weight: in after the take-off, out into the landing
	var want_proc := 0.0
	if in_air:
		want_proc = (1.0 if mode == "procedural" else ADAPT_TUCK_W) * smoothstep(0.0, 1.0, (t - takeoff_t) / PROC_EASE_S) * smoothstep(0.0, 1.0, (landing_t - t) / PROC_EASE_S)
	_proc_w = want_proc if not in_move else move_toward(_proc_w, want_proc, dt / 0.08)
	var right := Vector3.UP.cross(inward)          # (the character's left, +X in its frame)
	for s in ["l", "r"]:
		var hip := _bone(sk, s + "_upper_leg")
		var knee := _bone(sk, s + "_knee")
		var ankle := _bone(sk, s + "_ankle")
		if hip < 0 or knee < 0 or ankle < 0:
			continue
		# 1. the procedural tuck (its own target, blended in by weight)
		if _proc_w > 0.0:
			var u := clampf((t - takeoff_t) / maxf(landing_t - takeoff_t, 0.05), 0.0, 1.0)
			var off := _tuck(u)
			var pelvis := gx * sk.get_bone_global_pose(_bone(sk, "pelvis")).origin
			var side := LEG_HALF_GAP if s == "l" else -LEG_HALF_GAP
			var tgt := pelvis + inward * off.x + Vector3.UP * off.y + right * side
			var pole := inward + Vector3.UP * 0.4 + right * (0.25 if s == "l" else -0.25)
			TraversalIK.solve_live(sk, hip, knee, ankle, sk.get_bone_global_pose(ankle).origin, inv * tgt, _proc_w, inv.basis * pole)
		# 2. the clearance over the real top (both modes). The knee first: a folded leg's knee is not raised by lifting its ankle, so the
		# thigh is turned up at the hip until the knee clears (the shin and foot ride along) ...
		var pre := PROC_PRE_EDGE_M if mode == "procedural" else PRE_EDGE_M
		var kwant := _need(gx * sk.get_bone_global_pose(knee).origin, float(CLEAR_M.knee), pre) if in_air else 0.0
		var kcur := move_toward(float(_klift[s]), kwant, dt * (LIFT_UP_MS if kwant > float(_klift[s]) else LIFT_DOWN_MS))
		_klift[s] = kcur
		if kcur > 0.0005:
			var hp := sk.get_bone_global_pose(hip)
			var v := sk.get_bone_global_pose(knee).origin - hp.origin
			var v2 := (v + inv.basis * (Vector3.UP * kcur)).normalized() * v.length()
			var r := Quaternion(v.normalized(), v2.normalized()) if v.normalized().cross(v2.normalized()).length() > 1e-6 else Quaternion.IDENTITY
			var par := sk.get_bone_parent(hip)
			var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
			var ng := Basis(r) * hp.basis
			sk.set_bone_pose_rotation(hip, (pg.basis.orthonormalized().inverse() * ng.orthonormalized()).get_rotation_quaternion())
		# ... then the ankle, heel and toe
		var want := 0.0
		if in_air:
			for part: String in CLEAR_M:
				var b := _bone(sk, s + "_" + part)
				if b >= 0:
					want = maxf(want, _need(gx * sk.get_bone_global_pose(b).origin, float(CLEAR_M[part]), pre))
		var cur := float(_lift[s])
		cur = move_toward(cur, want, dt * (LIFT_UP_MS if want > cur else LIFT_DOWN_MS))
		_lift[s] = cur
		if cur > 0.0005:
			var a := sk.get_bone_global_pose(ankle).origin
			var kp := sk.get_bone_global_pose(knee).origin - sk.get_bone_global_pose(hip).origin
			TraversalIK.solve_live(sk, hip, knee, ankle, a, a + inv.basis * (Vector3.UP * cur), 1.0, kp)


static func _tuck(u: float) -> Vector2:
	for i in range(TUCK.size() - 1):
		var a: Array = TUCK[i]
		var b: Array = TUCK[i + 1]
		if u <= float(b[0]):
			var k := smoothstep(0.0, 1.0, (u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4))
			return Vector2(lerpf(float(a[1]), float(b[1]), k), lerpf(float(a[2]), float(b[2]), k))
	var last: Array = TUCK[TUCK.size() - 1]
	return Vector2(float(last[1]), float(last[2]))
