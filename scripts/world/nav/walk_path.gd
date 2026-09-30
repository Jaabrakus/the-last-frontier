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
var last_hit := Vector3.INF
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
	status = "walking"
	_detour_t = 0.0
	_best = INF
	_best_t = 0.0


## Forgets the plan (a new errand).
func reset() -> void:
	way = PackedVector3Array()
	goal = Vector3.INF
	status = ""
	_detour_t = 0.0
	_best = INF
	_best_t = 0.0


## The way to go this frame toward `to` (horizontal, unit length; ZERO when within `arrive`).
func steer(to: Vector3, dt: float, arrive: float) -> Vector3:
	var at := body.global_position
	var d := _flat(at, to)
	if d <= arrive:
		status = "arrived"
		_best = INF
		return Vector3.ZERO
	if goal == Vector3.INF or _flat(goal, to) > maxf(REPLAN_M, d * 0.15):
		_plan(at, to)
	# headway: none for STUCK_S, a new plan from here
	if d < _best - 0.3:
		_best = d
		_best_t = 0.0
	else:
		_best_t += dt
	if _best_t > STUCK_S:
		_best_t = 0.0
		_best = d
		_plan(at, to)
	if way.is_empty():
		status = "no_way"
		return _flat_dir(to - at)
	status = "walking"
	if _detour_t > 0.0:
		_detour_t -= dt
		var dd := _flat_dir(_detour - at)
		if dd != Vector3.ZERO and _flat(_detour, at) > 0.3:
			return dd
		_detour_t = 0.0
	var aim := carrot(way, at, AHEAD_M)
	if d < AHEAD_M or _flat(aim, to) < 0.3:
		aim = to
	var dir := _flat_dir(aim - at)
	_ray_t -= dt
	if _ray_t <= 0.0 and dir != Vector3.ZERO:
		_ray_t = RAY_S
		# (from here to the point it walks for and a little past: not round the corner beyond it)
		var look := minf(minf(LOOK_M, d), _flat(aim, at) + 0.8)
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
		if col is AnimatableBody3D and col.get_parent() is BuildDoor:
			var door := col.get_parent() as BuildDoor
			if not door.is_open:
				var nw := NavWorld.of(body.get_tree())
				if nw != null:
					nw.open_door(door)
			ex.append(hit.rid)                    # (a door: opened as she comes, walked through)
			continue
		if col.get_parent() is BuildDoor or (col is Node and col.get_parent() != null and col.get_parent().get_parent() is BuildDoor):
			ex.append(hit.rid)
			continue
		return hit.position
	return Vector3.INF


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
