class_name FallPose
extends SkeletonModifier3D
## Our own fall (user 2026-09-30: "we need to procedure the fall from the cliff or big ledge ... we need our own", then "we need to
## rebuild steps 1 and 3", the step off and the landing): while the player falls, the source's fall clip is replaced by a pose made
## here, live, from the fall itself; running off an edge plays no drop clip (TraversalController.own_run_off) and a landing no landing
## clip (LocoBrain.own_landing), both made here too.
##   step off:   run off an edge, the first half second: the lead leg reaches forward and down for ground that is not there, the
##               trailing leg lifts behind, the body tips a little forward; then into the air pose.
##   in the air: the legs pedal slowly (one knee up and forward, the other hanging back, swapping), the torso leans a little back,
##               the head looks down at the ground coming; unarmed, the arms go out and up for balance and circle slowly.
##   bracing:    as the ground comes (time to impact from the fall speed and a ray down), the legs come together under the hips and
##               reach for it, knees forward and a little bent, the torso comes forward over them and the arms come in front.
##   landing:    the hips drop with the impact (more the harder it is), the knees bend with the feet kept where they land, the torso
##               tips forward over them; it springs back up over a few tenths of a second, on top of the idle or the run.
## Weighted in after a short time in the air and out quickly on landing, where the absorb takes over. With something in the hands the arms are left to the hand modifiers that come after (the gun stays held).
## PlayerAnim feeds it every tick (feed()).

## Seconds in the air before the pose comes in, and how fast it comes in and goes.
const START_AIR_S := 0.18
const IN_S := 0.30
const OUT_S := 0.08
## The bracing starts this many seconds before impact and is full at BRACE_FULL_S.
const BRACE_START_S := 0.45
const BRACE_FULL_S := 0.15
## One pedal of the legs (s).
const PEDAL_S := 1.3
## Ankle offsets from the hip, in the body's frame (forward, up, out): the knee-up leg, the hanging leg, the braced leg.
const LEG_UP := Vector3(0.18, -0.58, 0.02)
const LEG_DOWN := Vector3(-0.10, -0.80, 0.04)
const LEG_BRACE := Vector3(0.08, -0.80, 0.05)
## Hand offsets from the shoulder (forward, up, out), in the air and bracing; the circle's radius (m).
const ARM_AIR := Vector3(0.08, 0.12, 0.42)
const ARM_BRACE := Vector3(0.30, -0.12, 0.28)
const ARM_CIRCLE := 0.07
## Torso lean (deg, + = back) in the air and bracing; head pitch (deg, + = down).
const LEAN_AIR := 7.0
const LEAN_BRACE := -10.0
const HEAD_DOWN := 14.0
## The step off (run off an edge): how long it holds before going into the air pose (s), the lead and trailing ankles (as LEG_*),
## the torso lean, and the free hands (as ARM_*).
const STEP_HOLD_S := 0.15
const STEP_OUT_S := 0.50
const STEP_LEAD := Vector3(0.26, -0.74, 0.03)
const STEP_TRAIL := Vector3(-0.26, -0.62, 0.03)
const LEAN_STEP := -6.0
const ARM_STEP := Vector3(0.22, -0.02, 0.30)
## The landing absorb: the hips' drop (m) per m/s of impact above LAND_FREE_MPS, its limits, the compression time (s), the recovery
## time (s, plus per m/s of impact) and the torso's forward tip (deg) at the deepest drop.
const LAND_FREE_MPS := 2.0
const LAND_DROP_PER_MPS := 0.045
const LAND_DROP_MIN := 0.03
const LAND_DROP_MAX := 0.30
const LAND_IN_S := 0.06
const LAND_OUT_S := 0.30
const LAND_OUT_PER_MPS := 0.04
const LAND_TIP_DEG := 24.0

var falling := false
var air_time := 0.0
var vy := 0.0
var arms_free := true
var body: Node3D

var _w := 0.0
var _brace := 0.0
var _fall_t := 0.0
var _step := false          ## this fall began as a run off an edge (not after a jump)
var _lead := "l"
var _land_t := INF
var _land_d := 0.0
var _land_len := 0.4
var _ids := {}


## on: locomotion is in its fall; p_air: seconds since the ground; p_vy: vertical speed (m/s, + up).
func feed(on: bool, p_air: float, p_vy: float, p_arms_free: bool) -> void:
	if on and not falling:
		_fall_t = 0.0
		_step = p_air < 0.4
		_land_t = INF
	falling = on
	air_time = p_air
	vy = p_vy
	arms_free = p_arms_free


## Our fall is on screen (most of its weight).
func showing() -> bool:
	return _w > 0.3


## Touched down (LocoBrain.own_land): the absorb, sized by the impact (m/s down).
func land(impact: float) -> void:
	_land_d = clampf((impact - LAND_FREE_MPS) * LAND_DROP_PER_MPS, LAND_DROP_MIN, LAND_DROP_MAX)
	_land_len = LAND_OUT_S + LAND_OUT_PER_MPS * maxf(impact, 0.0)
	_land_t = 0.0


func _bone(sk: Skeleton3D, n: String) -> int:
	if not _ids.has(n):
		_ids[n] = sk.find_bone(n)
	return int(_ids[n])


func _dt() -> float:
	return get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()


## Seconds until the feet reach the ground below (INF when there is none within 30 m).
func _time_to_impact() -> float:
	if body == null or not body.is_inside_tree():
		return INF
	var from := body.global_position + Vector3.UP * 0.1
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0)
	if body is CollisionObject3D:
		q.exclude = [(body as CollisionObject3D).get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return INF
	var d := maxf(from.y - 0.1 - float((hit.position as Vector3).y), 0.0)
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var down := maxf(-vy, 0.0)
	return (-down + sqrt(down * down + 2.0 * g * d)) / g


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or body == null:
		return
	var dt := _dt()
	var want := 1.0 if falling and air_time > START_AIR_S else 0.0
	if want > 0.0 and _w <= 0.001:
		_lead = _front_leg(sk)
	_w = move_toward(_w, want, dt / ((IN_S * (0.5 if _step else 1.0)) if want > _w else OUT_S))
	if falling:
		_fall_t += dt
	var gx := sk.global_transform
	var inv := gx.affine_inverse()
	var fwd := -body.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var hl := _bone(sk, "l_upper_leg")
	var hr := _bone(sk, "r_upper_leg")
	if hl < 0 or hr < 0:
		return
	var left := (gx * sk.get_bone_global_pose(hl).origin) - (gx * sk.get_bone_global_pose(hr).origin)
	left = (left - fwd * left.dot(fwd))
	left.y = 0.0
	left = left.normalized() if left.length() > 1e-4 else Vector3.UP.cross(fwd)
	var right := -left
	if _land_t < _land_len:
		_land_t += dt
		_absorb(sk, fwd, right)
	if _w <= 0.001:
		_brace = 0.0
		return
	var tti := _time_to_impact()
	var bw := 1.0 - smoothstep(BRACE_FULL_S, BRACE_START_S, tti)
	_brace = move_toward(_brace, bw, dt / 0.12)
	var w := smoothstep(0.0, 1.0, _w)
	# the step off: full for STEP_HOLD_S of the fall, gone by STEP_OUT_S (and before any brace)
	var ks := (1.0 - smoothstep(STEP_HOLD_S, STEP_OUT_S, _fall_t)) * (1.0 - _brace) if _step else 0.0
	var ph := TAU * maxf(_fall_t - STEP_HOLD_S, 0.0) / PEDAL_S
	# 1. the torso and head (before the limbs: they hang from it)
	var lean := lerpf(lerpf(LEAN_AIR, LEAN_BRACE, _brace), LEAN_STEP, ks)
	_turn(sk, "spinea", right, deg_to_rad(lean) * 0.5 * w)
	_turn(sk, "spined", right, deg_to_rad(lean) * 0.5 * w)
	_turn(sk, "neck", right, -deg_to_rad(HEAD_DOWN) * w)
	# 2. the legs
	for s in ["l", "r"]:
		var hip := _bone(sk, s + "_upper_leg")
		var knee := _bone(sk, s + "_knee")
		var ankle := _bone(sk, s + "_ankle")
		if knee < 0 or ankle < 0:
			continue
		var out := left if s == "l" else right
		var a := 0.5 + 0.5 * sin(ph + (0.0 if s == "l" else PI))     # 1: this leg's knee up
		var air := LEG_DOWN.lerp(LEG_UP, smoothstep(0.0, 1.0, a))
		var o := air.lerp(LEG_BRACE, _brace).lerp(STEP_LEAD if s == _lead else STEP_TRAIL, ks)
		var hp := gx * sk.get_bone_global_pose(hip).origin
		var tgt := hp + fwd * o.x + Vector3.UP * o.y + out * o.z
		var pole := fwd + out * 0.15
		TraversalIK.solve_live(sk, hip, knee, ankle, sk.get_bone_global_pose(ankle).origin, inv * tgt, w, inv.basis * pole)
	# 3. the arms, when nothing is in the hands
	if not arms_free:
		return
	for s in ["l", "r"]:
		var sh := _bone(sk, s + "_shoulder")
		var el := _bone(sk, s + "_elbow")
		var wr := _bone(sk, s + "_wrist")
		if sh < 0 or el < 0 or wr < 0:
			continue
		var out := left if s == "l" else right
		var c := ph * 1.4 + (0.0 if s == "l" else 2.1)
		var air := ARM_AIR + Vector3(cos(c), sin(c), 0.0) * ARM_CIRCLE
		var o := air.lerp(ARM_BRACE, _brace).lerp(ARM_STEP, ks)
		var sp := gx * sk.get_bone_global_pose(sh).origin
		var tgt := sp + fwd * o.x + Vector3.UP * o.y + out * o.z
		var pole := -fwd * 0.4 + Vector3.DOWN * 0.6 + out * 0.4
		TraversalIK.solve_live(sk, sh, el, wr, sk.get_bone_global_pose(wr).origin, inv * tgt, w, inv.basis * pole)


## The leg whose ankle is further forward of the pelvis now (the step off's lead).
func _front_leg(sk: Skeleton3D) -> String:
	var gx := sk.global_transform
	var fwd := -body.global_basis.z
	var al := _bone(sk, "l_ankle")
	var ar := _bone(sk, "r_ankle")
	if al < 0 or ar < 0:
		return "l"
	return "l" if (gx * sk.get_bone_global_pose(al).origin).dot(fwd) >= (gx * sk.get_bone_global_pose(ar).origin).dot(fwd) else "r"


## The landing absorb: the pelvis lowered, each leg bent back down to where its foot was, the torso tipped forward over them.
func _absorb(sk: Skeleton3D, fwd: Vector3, right: Vector3) -> void:
	var c := smoothstep(0.0, LAND_IN_S, _land_t) if _land_t < LAND_IN_S else 1.0 - smoothstep(LAND_IN_S, _land_len, _land_t)
	var d := _land_d * c
	if d < 0.002:
		return
	var inv := sk.global_transform.affine_inverse()
	var pel := _bone(sk, "pelvis")
	if pel < 0:
		return
	var feet := {}
	for s in ["l", "r"]:
		var a := _bone(sk, s + "_ankle")
		if a >= 0:
			feet[s] = sk.get_bone_global_pose(a).origin
	var par := sk.get_bone_parent(pel)
	var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	var off := inv.basis * (Vector3.DOWN * d)
	sk.set_bone_pose_position(pel, sk.get_bone_pose_position(pel) + pg.basis.inverse() * off)
	var tip := -deg_to_rad(LAND_TIP_DEG) * (d / LAND_DROP_MAX)
	_turn(sk, "spinea", right, tip * 0.5)
	_turn(sk, "spined", right, tip * 0.5)
	for s: String in feet:
		var hip := _bone(sk, s + "_upper_leg")
		var knee := _bone(sk, s + "_knee")
		var ankle := _bone(sk, s + "_ankle")
		if hip < 0 or knee < 0:
			continue
		TraversalIK.solve_live(sk, hip, knee, ankle, sk.get_bone_global_pose(ankle).origin, feet[s], 1.0, inv.basis * fwd)


## Turns a bone by `ang` about the world axis (its children follow).
func _turn(sk: Skeleton3D, n: String, axis: Vector3, ang: float) -> void:
	var b := _bone(sk, n)
	if b < 0 or absf(ang) < 1e-5:
		return
	var a := (sk.global_transform.basis.inverse() * axis).normalized()
	var g := sk.get_bone_global_pose(b)
	var par := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	var ng := Basis(a, ang) * g.basis.orthonormalized()
	sk.set_bone_pose_rotation(b, (pg.basis.orthonormalized().inverse() * ng).get_rotation_quaternion())
