class_name StopFootIK
extends SkeletonModifier3D
## Our own stop, the legs (user 2026-09-30: no stop clip after a run forward, the feet "planted + a settle step"): when the run
## is let go (LocoBrain MOVE or START to IDLE at speed) the body skids to a halt over a third of a second while the legs blend into
## idle, which alone slides the feet along the ground and leaves the back one hanging in the air through the blend. Here each foot
## on the ground when the run ends is pinned where it is while the body skids over it; the one in the air comes down onto the
## ground over LAND_S, swinging through to its place in the idle stance by where the body will come to rest (its speed and
## braking, measured; the stance's feet as last seen standing), and is pinned where it lands. Halted, the foot farther from its place in the idle
## pose steps up to it over STEP_S (the other one, if it is far too, after it); then the feet hold on the ground until the idle
## pose has its own feet down, and are handed back to the animation over BLEND_S. A SkeletonModifier3D after the animation; no
## clip, nothing owns the pose, the upper body is the locomotion's. The feet keep the animation's turn (TraversalIK.solve_live).
##
##   var ik := StopFootIK.new(); skeleton.add_child(ik); ik.player = body     # body.anim.loco is read

const LEGS := {
	"l": ["l_upper_leg", "l_knee", "l_ankle"],
	"r": ["r_upper_leg", "r_knee", "r_ankle"],
}
## The body's speed a run let go of must have had (m/s), and the speed it is called halted at.
const FAST_MPS := 1.8
const HALT_MPS := 0.12
## A foot this close to the ground (its ankle above it, m) is on it; a planted ankle's height when none was seen planted.
const PLANT_H := 0.16
const FOOT_H := 0.065
## The skid's longest (s), the airborne foot's way down (s), a settle step (s) and its lift (m).
const SKID_MAX_S := 0.7
const LAND_S := 0.24
const LAND_LIFT_M := 0.05
## The braking assumed before it is measured (m/s^2), and the least taken.
const DECEL_MPS2 := 9.0
const DECEL_MIN_MPS2 := 4.0
const STEP_S := 0.26
const STEP_LIFT_M := 0.08
## Feet closer than this to their idle place need no step (m).
const NEAR_M := 0.08
## The longest the feet hold for the idle pose's own feet to come down (s), and the hand-back to it (s).
const HOLD_MAX_S := 0.8
const BLEND_S := 0.15
const FADE_IN_S := 0.05
const RAY_UP := 0.6
const RAY_DOWN := 1.0

var player: CharacterBody3D

var _phase := 0                 ## 0 off, 1 skid, 2 settle, 3 hand back
var _t := 0.0                   ## seconds into the phase
var _t_all := 0.0
var _prev_state := &""
var _prev_speed := 0.0
var _ground := {}               ## side -> ground height under the foot (world y)
var _lock := {}                 ## side -> Vector3 (world) the foot stands at (pinned)
var _land := {}                 ## side -> seconds into its way down (the foot airborne when the run ended)
var _land_from := {}            ## side -> Vector3 the ankle was at when its way down began
var _idle_off := {}             ## side -> the idle stance's ankle from the body (m, its right / up / back), as last seen standing
var _decel := DECEL_MPS2
var _speed := 0.0
var _step := {}                 ## side -> seconds into its settle step
var _from := {}                 ## side -> Vector3 the settle step starts from
var _stepped := {}              ## side -> true: its settle step is done (or it needed none)
var _last := {}                 ## side -> Vector3 where the IK last put the foot (the hand-back starts there)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or player == null or not is_instance_valid(player) or not ("anim" in player) or player.get("anim") == null:
		return
	var loco: LocoBrain = (player.get("anim") as PlayerAnim).loco
	if loco == null:
		return
	var dt := get_process_delta_time()
	var speed := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
	var state := StringName(loco.state)
	var running := state == &"MOVE" or state == &"START"
	if _phase == 0 and state == &"IDLE" and speed < 0.01 and loco.time_in_state > 1.0:
		for side: String in LEGS:
			var g := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(LEGS[side][2])).origin
			_idle_off[side] = player.global_transform.basis.inverse() * (g - player.global_position)
	if _phase == 0:
		if (_prev_state == &"MOVE" or _prev_state == &"START") and state == &"IDLE" and _prev_speed >= FAST_MPS and loco.hemi == &"fw":
			_begin(sk)
		_prev_state = state
		_prev_speed = speed if running else _prev_speed
		if _phase == 0:
			return
	_prev_state = state
	# moving again (input, a jump, a fall, a move of the traversal controller): let go of the feet at once
	if loco.moving or not player.is_on_floor():
		_end()
		return
	_t += dt
	_t_all += dt
	if dt > 0.0 and speed < _speed:
		_decel = lerpf(_decel, maxf((_speed - speed) / dt, DECEL_MIN_MPS2), 0.5)
	_speed = speed
	# where the body will stand: its skid's rest of the way
	var v := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var rest := player.global_position + (v.normalized() * v.length_squared() / (2.0 * _decel) if v.length() > 1e-3 else Vector3.ZERO)
	# each foot's place in the idle stance there (the animation's own foot when the stance was never seen)
	var anim := {}
	var place := {}
	for side: String in LEGS:
		anim[side] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(LEGS[side][2])).origin
		var pl: Vector3 = rest + player.global_transform.basis * (_idle_off[side] as Vector3) if _idle_off.has(side) else anim[side]
		place[side] = Vector3(pl.x, float(_ground[side]) + _foot_h(side), pl.z)
	match _phase:
		1:
			if (speed < HALT_MPS or _t > SKID_MAX_S) and _land.is_empty():
				_settle(place)
		2:
			if _step.is_empty() and not _next_step(place):
				var down := true
				for side: String in LEGS:
					var d: Vector3 = anim[side] - place[side]
					down = down and d.y < PLANT_H - FOOT_H and Vector2(d.x, d.z).length() < NEAR_M * 0.5
				if down or _t > HOLD_MAX_S:
					_phase = 3
					_t = 0.0
		3:
			if _t >= BLEND_S:
				_end()
				return
	var to_skel := sk.global_transform.affine_inverse()
	var fwd := to_skel.basis * (-player.global_transform.basis.z)
	for side: String in LEGS:
		var chain: Array = LEGS[side]
		var ua := sk.find_bone(chain[0])
		var lb := sk.find_bone(chain[1])
		var ec := sk.find_bone(chain[2])
		if ua < 0 or lb < 0 or ec < 0:
			continue
		var a: Vector3 = anim[side]
		var target := a
		var gy: float = _ground[side]
		if _phase == 3:
			var b := clampf(_t / BLEND_S, 0.0, 1.0)
			target = (_last[side] as Vector3).lerp(a, b * b * (3.0 - 2.0 * b))
		elif _land.has(side):
			# the airborne foot swings down to beside where the body will stand, and stands where it lands
			var lt: float = float(_land[side]) + dt
			_land[side] = lt
			var s := clampf(lt / LAND_S, 0.0, 1.0)
			var e := s * s * (3.0 - 2.0 * s)
			var to: Vector3 = place[side]
			target = (_land_from[side] as Vector3).lerp(to, e)
			target.y += sin(PI * s) * LAND_LIFT_M
			if s >= 1.0:
				_land.erase(side)
				_lock[side] = target
		elif _step.has(side):
			var st: float = float(_step[side]) + dt
			_step[side] = st
			var s := clampf(st / STEP_S, 0.0, 1.0)
			var e := s * s * (3.0 - 2.0 * s)
			var to: Vector3 = place[side]
			target = (_from[side] as Vector3).lerp(to, e)
			target.y += sin(PI * s) * STEP_LIFT_M
			if s >= 1.0:
				_step.erase(side)
				_stepped[side] = true
				_lock[side] = to
		else:
			target = _lock[side]
		_last[side] = target
		var w := clampf(_t_all / FADE_IN_S, 0.0, 1.0)
		TraversalIK.solve_live(sk, ua, lb, ec, sk.get_bone_global_pose(ec).origin, to_skel * a.lerp(target, w), 1.0, fwd)


func _begin(sk: Skeleton3D) -> void:
	_clear()
	_phase = 1
	var space := player.get_world_3d().direct_space_state
	for side: String in LEGS:
		var p := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(LEGS[side][2])).origin
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + RAY_UP, p.z), Vector3(p.x, p.y - RAY_DOWN, p.z), player.collision_mask)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		var gy: float = float(hit.position.y) if not hit.is_empty() else player.global_position.y
		_ground[side] = gy
		if p.y - gy < PLANT_H:
			_lock[side] = Vector3(p.x, minf(p.y, gy + _foot_h(side)), p.z)
		else:
			_land[side] = 0.0
			_land_from[side] = p
			if not _idle_off.has(side):
				_idle_off[side] = Vector3((p - player.global_position).dot(player.global_transform.basis.x), 0.0, 0.0)


## Halted: the settle steps begin.
func _settle(place: Dictionary) -> void:
	_phase = 2
	_t = 0.0
	_next_step(place)


## Starts the settle step of the foot farthest from its idle place (only one foot is in the air at a time); false when none is left.
func _next_step(place: Dictionary) -> bool:
	var best := ""
	var best_d := NEAR_M
	for side: String in LEGS:
		if _stepped.get(side, false):
			continue
		var l: Vector3 = _lock[side]
		var a: Vector3 = place[side]
		var d := Vector2(l.x - a.x, l.z - a.z).length()
		if d >= best_d:
			best = side
			best_d = d
	if best == "":
		return false
	_step[best] = 0.0
	_from[best] = _lock[best]
	for side: String in LEGS:
		if side != best and not _stepped.get(side, false):
			var l: Vector3 = _lock[side]
			var a: Vector3 = place[side]
			if Vector2(l.x - a.x, l.z - a.z).length() < NEAR_M:
				_stepped[side] = true
	return true


## A standing ankle's height over the ground: the idle stance's, as last seen.
func _foot_h(side: String) -> float:
	return clampf((_idle_off[side] as Vector3).y, 0.03, PLANT_H) if _idle_off.has(side) else FOOT_H


func _end() -> void:
	_clear()
	_prev_state = &""
	_prev_speed = 0.0


func _clear() -> void:
	_phase = 0
	_t = 0.0
	_t_all = 0.0
	_decel = DECEL_MPS2
	_speed = 0.0
	_ground.clear()
	_lock.clear()
	_land.clear()
	_land_from.clear()
	_step.clear()
	_from.clear()
	_stepped.clear()
	_last.clear()
