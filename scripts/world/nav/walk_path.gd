class_name WalkPath
extends RefCounted
## THE WALK (user 2026-09-30: "the user is queued a action the path finder sees it then the raycasting looks for obstacles
## from here and there and adjust"; "the npc walking is not fluid"): a walker's way to a goal, planned once (WalkGrid.plan:
## a few long straight legs) and walked smoothly, rays adjusting it.
##
##   the plan    made when the goal is new, or has moved on more than REPLAN_M (a walker following someone), or when the
##               walker has made no headway for STUCK_S (a new plan from where it stands)
##   the walk    toward the point AHEAD_M along the plan from the point of it nearest the walker (so it rounds a corner in
##               a curve, not a snap to it; the body's own turn rate and speed ramp do the rest)
##   the rays    every RAY_S, six rays ahead the walker's width (its middle and both sides, at knee and chest height) out to
##               LOOK_M: clear, it goes on; a shut door, it is opened (NavWorld); anything else (a person, a horse, a cart,
##               a pile the plan did not know) a fan of rays either side (FAN_DEG) finds the clearest way still heading on
##               and it goes round that way for DETOUR_S; the logs and stumps are stepped over (BodyStep), not rayed
##   used by     NavMover.steer when its use_grid is on (the same call every walker and job makes)

const AHEAD_M := 1.4
const RAY_S := 0.2
const LOOK_M := 2.6
const STUCK_S := 2.5
const REPLAN_M := 1.5
const DETOUR_S := 1.0
const DETOUR_M := 1.5
const FAN_DEG := [25.0, -25.0, 50.0, -50.0, 75.0, -75.0]
## The rays are cast just over what she gets over (her step, or with a tool her climb: `can`), and again a little higher:
## what is lower is stepped over or vaulted (BodyStep, WorkerTraversal), not detoured round.
const RAY_OVER_M := 0.1
const RAY_UP_M := 0.7
## No headway after this many new plans in a row: the walk is given up (status "no_way": the caller's own steer takes over,
## as it did when the navigation mesh gave up) for RETRY_S.
const REPLANS := 3
const RETRY_S := 6.0
## A door she is at is waited for while its leaf swings (within this of it), at most DOOR_WAIT_S.
const DOOR_NEAR_M := 1.8
const DOOR_WAIT_S := 4.0
## A DOOR STEP (user 2026-09-30: "add npc in the route they can use e to interact"): each door the plan goes through is a step
## of the walk: she comes up to it, and within DOOR_USE_M of a shut one stops facing it, takes DOOR_PRESS_S (her E) and opens
## it (NavWorld.use_door: held open while she, or anyone behind her using it, is near; shut behind them), waits for the swing
## and walks through. A door already open is only passed (and held for her). The plan passes within DOOR_ON_M of the door's
## middle for the door to be on it.
const DOOR_USE_M := 1.3
const DOOR_PRESS_S := 0.35
const DOOR_ON_M := 0.9

var body: CharacterBody3D
var radius := 0.3
## What the walker can do (WalkGrid: step_m, climb_m, wade_m); empty: a person on foot.
var can := {}
## The plan: its points, the first where the walk began.
var way := PackedVector3Array()
## The goal the plan is for (INF: none yet).
var goal := Vector3.INF
## "", "walking", "arrived", "no_way".
var status := ""
## Counters for the tests and the debug view; the last rays' hit (INF: clear).
var plans := 0
var detours := 0
var doors_opened := 0
var last_hit := Vector3.INF
## Rays ahead of her (true), or only the plan (a rider: the horse has its own feelers, HorseLead).
var rays := true
## The door she waits for while its leaf swings (null: none).
var waiting_door: BuildDoor = null
## The door she is pressing E at now (null: none): a body may play its reach for it.
var using_door: BuildDoor = null
## The doors on the plan still before her, in order.
var doors_ahead: Array[BuildDoor] = []
var _press := 0.0
var _door_side := 0.0
var _door: BuildDoor = null
var _door_wait := 0.0
var _clock := 0.0
var _blocked_until := -1.0
var _replans := 0
var _ray_t := 0.0
var _detour := Vector3.ZERO
var _detour_t := 0.0
var _best := INF
var _best_t := 0.0
var _ray: PhysicsRayQueryParameters3D


func _init(b: CharacterBody3D, r := 0.3) -> void:
	body = b
	radius = r


## Walks the route the leader chose (`chosen`: its points, the last at `to`) instead of planning one: no plan is made for `to`
## until the walker is stuck.
func use_route(chosen: PackedVector3Array, to: Vector3) -> void:
	way = chosen
	goal = to
	_find_doors()
	status = "walking"
	_detour_t = 0.0
	_best = INF
	_best_t = 0.0


## Forgets the plan (a new errand).
func reset() -> void:
	way = PackedVector3Array()
	goal = Vector3.INF
	status = ""
	_blocked_until = -1.0
	_replans = 0
	_door = null
	waiting_door = null
	using_door = null
	doors_ahead.clear()
	_press = 0.0
	_detour_t = 0.0
	_best = INF
	_best_t = 0.0


## The point to make for now on the way to `to`: `ahead` m along the plan from where she is (Vector3.INF when she is within
## `arrive` of it). The plan is made when the goal is new or has moved, and again when she makes no headway; REPLANS of those
## in a row and the walk is given up for RETRY_S (status "no_way": the point returned is `to` itself).
func follow(to: Vector3, dt: float, arrive: float, ahead := AHEAD_M) -> Vector3:
	_clock += dt
	var at := body.global_position
	var d := _flat(at, to)
	if d <= arrive:
		status = "arrived"
		_best = INF
		_replans = 0
		return Vector3.INF
	if _clock < _blocked_until:
		status = "no_way"
		return to
	if goal == Vector3.INF or _flat(goal, to) > maxf(REPLAN_M, d * 0.15):
		_plan(at, to)
	# headway: none for STUCK_S, a new plan from here
	if d < _best - 0.3:
		_best = d
		_best_t = 0.0
		_replans = 0
	else:
		_best_t += dt
	if _best_t > STUCK_S and not waiting_door:
		_best_t = 0.0
		_best = d
		_replans += 1
		if _replans > REPLANS:
			_replans = 0
			_blocked_until = _clock + RETRY_S
			way = PackedVector3Array()
			goal = Vector3.INF
			status = "no_way"
			return to
		_plan(at, to)
	if way.is_empty():
		status = "no_way"
		_blocked_until = _clock + 2.0           # (no way on the grid: the caller's own steer for a moment, then it is asked again)
		goal = Vector3.INF
		return to
	status = "walking"
	var aim := carrot(way, at, ahead)
	if d < ahead or _flat(aim, to) < 0.3:
		aim = to
	return aim


## The way to go this frame toward `to` (horizontal, unit length; ZERO when within `arrive` or at a door that swings).
func steer(to: Vector3, dt: float, arrive: float) -> Vector3:
	var at := body.global_position
	var aim := follow(to, dt, arrive)
	if aim == Vector3.INF:
		return Vector3.ZERO
	if status == "no_way":
		return _flat_dir(to - at)
	if not rays:
		return _flat_dir(aim - at)
	# the next door of the plan: E pressed at it, and gone through
	waiting_door = null
	var ds := _door_step(at, dt)
	if ds != Vector3.INF:
		return ds
	# a door she is at: waited for while its leaf swings in
	if _door != null and is_instance_valid(_door):
		var dd := _flat(at, _door.global_position)
		if dd > 3.0:
			_door = null
			_door_wait = 0.0
		elif _door.swing() < 0.95 and dd < DOOR_NEAR_M and dd > 0.3 and _door_wait < DOOR_WAIT_S:
			_door_wait += dt
			waiting_door = _door
			_best_t = 0.0
			return Vector3.ZERO
	else:
		_door_wait = 0.0
	if _detour_t > 0.0:
		_detour_t -= dt
		var dv := _flat_dir(_detour - at)
		if dv != Vector3.ZERO and _flat(_detour, at) > 0.3:
			return dv
		_detour_t = 0.0
	var dir := _flat_dir(aim - at)
	_ray_t -= dt
	if _ray_t <= 0.0 and dir != Vector3.ZERO:
		_ray_t = RAY_S
		# (from here to the point it walks for and a little past: not round the corner beyond it)
		var look := minf(minf(LOOK_M, _flat(at, to)), _flat(aim, at) + 0.8)
		var hit := _look(at, dir, look)
		last_hit = hit
		if hit != Vector3.INF:
			var side := _fan(at, dir, look)
			if side != Vector3.ZERO:
				detours += 1
				_detour = at + side * DETOUR_M
				_detour_t = DETOUR_S
				return side
	return dir


func _plan(at: Vector3, to: Vector3) -> void:
	goal = to
	plans += 1
	_detour_t = 0.0
	var g := WalkGrid.of(body.get_tree())
	way = g.plan(at, to, radius, can) if g != null else PackedVector3Array()
	_find_doors()


## The doors the plan goes through, in the order she comes to them (doors_ahead).
func _find_doors() -> void:
	doors_ahead.clear()
	using_door = null
	_press = 0.0
	var g := WalkGrid.of(body.get_tree())
	if g == null or way.size() < 2:
		return
	var found := []
	for d: BuildDoor in g._door_list():
		if not is_instance_valid(d):
			continue
		var c := d.global_position
		var nb := _nearest(way, c)
		if _flat(nb[1], c) > DOOR_ON_M:
			continue
		# (how far along the plan: the segment, then the point on it)
		found.append([int(nb[0]) * 1000.0 + _flat(way[int(nb[0])], nb[1]), d])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for f: Array in found:
		doors_ahead.append(f[1])
	if not doors_ahead.is_empty():
		_door_side = _side_of(doors_ahead[0], body.global_position)


## Which side of door `d` point `p` is on (the sign along its normal).
static func _side_of(d: BuildDoor, p: Vector3) -> float:
	var n := d.global_basis.z
	return signf((p.x - d.global_position.x) * n.x + (p.z - d.global_position.z) * n.z)


## The door step: ZERO while she presses E at the next door or waits for its swing, INF when there is none to do now.
func _door_step(at: Vector3, dt: float) -> Vector3:
	using_door = null
	while not doors_ahead.is_empty():
		var d := doors_ahead[0]
		if not is_instance_valid(d):
			doors_ahead.pop_front()
			continue
		# gone through: on the other side and clear of it
		var side := _side_of(d, at)
		var dd := _flat(at, d.global_position)
		if _door_side != 0.0 and side != 0.0 and side != _door_side and dd > 0.5:
			doors_ahead.pop_front()
			_press = 0.0
			if not doors_ahead.is_empty():
				_door_side = _side_of(doors_ahead[0], at)
			continue
		if _door_side == 0.0:
			_door_side = side
		if dd > DOOR_USE_M:
			return Vector3.INF
		var nw := NavWorld.of(body.get_tree())
		if not d.is_open:
			# her E: a beat facing it, then it opens
			_press += dt
			using_door = d
			_best_t = 0.0
			waiting_door = d
			if _press < DOOR_PRESS_S:
				return Vector3.ZERO
			if nw != null:
				nw.use_door(d, body)
			else:
				d.set_open(true)
			doors_opened += 1
			_door = d
			_door_wait = 0.0
			return Vector3.ZERO
		_press = 0.0
		if nw != null:
			nw.use_door(d, body)          # (held open for her while she goes through)
		_door = d
		return Vector3.INF
	return Vector3.INF


## The first thing in the way ahead along `dir` within `look` (its point; INF: clear). A shut door is opened as it is met.
func _look(at: Vector3, dir: Vector3, look: float) -> Vector3:
	var side := dir.cross(Vector3.UP).normalized() * radius * 0.7
	var top := maxf(float(can.get("climb_m", 0.0)), float(can.get("step_m", WalkGrid.CAN_STEP_M)))
	for h: float in [top + RAY_OVER_M, minf(top + RAY_UP_M, 1.7)]:
		for o: float in [0.0, -1.0, 1.0]:
			var from := at + Vector3.UP * h + side * o
			var hit := _cast(from, from + dir * look)
			if hit != Vector3.INF:
				return hit
	return Vector3.INF


## The clearest way round: the first of the fan's directions with nothing in it (ZERO: none).
func _fan(at: Vector3, dir: Vector3, look: float) -> Vector3:
	for a: float in FAN_DEG:
		var d2 := dir.rotated(Vector3.UP, deg_to_rad(a))
		if _look(at, d2, look * 0.8) == Vector3.INF:
			return d2
	return Vector3.ZERO


func _cast(from: Vector3, to: Vector3) -> Vector3:
	var space := body.get_world_3d().direct_space_state
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
	var ex: Array[RID] = [body.get_rid()]
	for _try in 4:
		_ray.from = from
		_ray.to = to
		_ray.exclude = ex
		var hit := space.intersect_ray(_ray)
		if hit.is_empty():
			return Vector3.INF
		var col := hit.collider as Node
		if col == null or col.is_in_group(&"terrain") or col.is_in_group(FrontierVegetation.LOW_GROUP):
			ex.append(hit.rid)                    # (the ground; a log, a stump: stepped over)
			continue
		var door := _door_of(col)
		if door != null and doors_ahead.has(door):
			ex.append(hit.rid)                        # (a door of the plan: its door step opens it, her E at it)
			continue
		if door != null:
			var nw := NavWorld.of(body.get_tree())
			if not door.is_open:
				doors_opened += 1
			if nw != null:
				nw.use_door(door, body)
			else:
				door.set_open(true)
			_door = door                          # (a door: opened as she comes, waited for while it swings, walked through)
			ex.append(hit.rid)
			continue
		return hit.position
	return Vector3.INF


## The door a leaf (or any part of a door) belongs to, or null.
static func _door_of(n: Node) -> BuildDoor:
	var p := n
	for _i in 4:
		if p == null:
			return null
		if p is BuildDoor:
			return p as BuildDoor
		p = p.get_parent()
	return null


## The point `ahead` m along polyline `pts` from the point of it nearest `at` (the pursuit point a walker or a rider
## steers for).
static func carrot(pts: PackedVector3Array, at: Vector3, ahead: float) -> Vector3:
	var nb := _nearest(pts, at)
	var bi: int = nb[0]
	var bp: Vector3 = nb[1]
	var left := ahead
	var p0 := bp
	for i in range(bi + 1, pts.size()):
		var seg := _flat(p0, pts[i])
		if seg >= left:
			return p0.lerp(pts[i], left / maxf(seg, 1e-4))
		left -= seg
		p0 = pts[i]
	return pts[pts.size() - 1]


## The plan's length left from `at` (m).
func remaining(at: Vector3) -> float:
	if way.size() < 2:
		return INF
	var nb := _nearest(way, at)
	var p0: Vector3 = nb[1]
	var s := _flat(at, p0)
	for i in range(int(nb[0]) + 1, way.size()):
		s += _flat(p0, way[i])
		p0 = way[i]
	return s


## The point of polyline `pts` nearest `at`: [the index of its segment, the point].
static func _nearest(pts: PackedVector3Array, at: Vector3) -> Array:
	var best := INF
	var bi := 0
	var bp := pts[0]
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := 0.0
		if ab.length_squared() > 1e-6:
			t = clampf(Vector2(at.x - a.x, at.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var p := a.lerp(b, t)
		var d := _flat(p, at)
		if d < best:
			best = d
			bi = i
			bp = p
	return [bi, bp]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _flat_dir(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 1e-4 else Vector3.ZERO
