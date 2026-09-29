class_name NavMover
extends RefCounted
## A walking body's way on the NavWorld mesh: any CharacterBody3D that moves itself (a worker, a child) asks each physics
## frame which way to go toward a point, and walks that way with its own speed and clips.
##   var nav := NavMover.new(self, 0.3)                    # registers with the level's NavWorld (none: nav.world == null)
##   var dir := nav.steer(goal, dt, 0.9)                   # a horizontal unit vector, ZERO when there or waiting at a door
##   if nav.on_path: walk dir as it is                     # else: no mesh here / no way found: steer as before (fallback)
## It asks for a path when the target is new or has moved (following someone), when the map has changed under it (a rebake),
## and when the body makes no headway (STUCK_S: blocked by something the mesh does not know); it asks the NavWorld for the
## tiles it needs (a long walk), follows the path's corners, opens a shut door on its way (and waits for the leaf), keeps
## clear of the other walkers (NavWorld.separation), and gives up with a `reason` ("no_nav": nothing baked here and
## nothing coming, "off_mesh": the body is not on the mesh, "no_path", "unreachable": the path ends short of the target,
## "stuck": no headway after REPATHS tries), after which on_path is false for that target (the caller's own steer takes
## over) until the target moves off or RETRY_S passes.

enum { IDLE, WAIT, MOVING, ARRIVED, FAILED }

const STUCK_S := 1.2
const REPATHS := 3
const RETRY_S := 6.0
## Corners are passed within this (m): small, so a wide body does not cut a corner into the post it goes round.
const CORNER := 0.2
## A path that ends further than this from the target is short of it (m).
const SLACK := 1.2
## The body is on the mesh within this of it (m).
const ON_MESH := 1.6
## A target further than this is not baked for (m).
const FAR_M := 200.0

var body: CharacterBody3D
var world: NavWorld
var radius := 0.3
var status := IDLE
var reason := ""
## The steer this frame came from a path (walk it as it is); false: the caller steers itself.
var on_path := false
var target := Vector3.INF
## Where the walker lives (NavWorld keeps the tiles round it baked): a worker's home.
var home := Vector3.INF
var path := PackedVector3Array()
## Counters for the tests: paths asked for, doors opened, give-ups.
var paths := 0
var doors_opened := 0
var give_ups := 0
var waiting_door: BuildDoor

var _i := 0
var _path_to := Vector3.INF
var _path_t := 0.0
var _iter := -1
var _clock := 0.0
var _fail_to := Vector3.INF
var _fail_t := -100.0
var _check_t := 0.0
var _check_at := Vector3.ZERO
var _repaths := 0
var _door_wait := 0.0
var _partial := false


func _init(b: CharacterBody3D, r := 0.3) -> void:
	body = b
	radius = r
	if b != null and b.is_inside_tree():
		attach()
	elif b != null:
		b.tree_entered.connect(attach, CONNECT_ONE_SHOT)


func attach() -> void:
	if world != null or body == null or not body.is_inside_tree():
		return
	world = NavWorld.of(body.get_tree())
	if world != null:
		world.register(self)
		body.tree_exiting.connect(release, CONNECT_ONE_SHOT)


func release() -> void:
	if world != null and is_instance_valid(world):
		world.unregister(self)
	world = null


## Forgets the path (a new errand); the next steer asks again.
func reset() -> void:
	path = PackedVector3Array()
	_path_to = Vector3.INF
	status = IDLE
	reason = ""
	_repaths = 0
	_fail_to = Vector3.INF


## The way to go this frame toward `to` (horizontal, unit length, ZERO when within `arrive` or waiting for a door). See on_path.
func steer(to: Vector3, dt: float, arrive := 0.6) -> Vector3:
	_clock += dt
	on_path = false
	target = to
	if world == null or not is_instance_valid(world):
		world = null
		attach()
		if world == null:
			return _fail("no_nav")
	var at := body.global_position
	var flat := Vector2(to.x - at.x, to.z - at.z).length()
	if flat <= arrive:
		status = ARRIVED
		on_path = true
		return Vector3.ZERO
	# given up on this target a moment ago
	if _fail_to != Vector3.INF and _fail_to.distance_to(to) < 2.0 and _clock - _fail_t < RETRY_S:
		return Vector3.ZERO
	if _need_path(to, at, flat):
		if not _make_path(at, to):
			return Vector3.ZERO
	var dir := _follow(at, to, arrive)
	if status == FAILED:
		return Vector3.ZERO
	on_path = true
	if dir == Vector3.ZERO:
		return dir
	# a wall it is pressed against (a post it clipped going round): along the wall, and a little off it
	if body.is_on_wall():
		var n := body.get_wall_normal()
		n.y = 0.0
		if n.length() > 0.1:
			n = n.normalized()
			var into := dir.dot(n)
			if into < -0.1:
				var along := dir - n * into
				dir = (along + n * 0.4).normalized() if along.length() > 0.05 else n.rotated(Vector3.UP, PI * 0.5)
	# the others close by: a sidestep (never straight back against the way)
	# (only where the step aside stays on the mesh: not into a wall's corner or behind a door's leaf)
	var push := world.separation(self)
	if push.length() > 0.02:
		var side := push - dir * push.dot(dir)
		var back := minf(push.dot(dir), 0.0)
		var aside := (dir + side * 1.2 + dir * back * 0.3).normalized()
		if world.on_mesh(at + aside * 0.6):
			dir = aside
	_headway(dt, at)
	return dir


## Whether a wall (anything static) stands between `a` and `b` at chest height: near in a straight line, but not by the way.
static func walled(a: CollisionObject3D, b: Node3D) -> bool:
	if a == null or b == null or not a.is_inside_tree():
		return false
	var from := a.global_position + Vector3.UP * 0.9
	var to := b.global_position + Vector3.UP * 0.9
	var ex: Array[RID] = [a.get_rid()]
	if b is CollisionObject3D:
		ex.append((b as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, ex)
	var hit := a.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.get("collider") is StaticBody3D


## The length of the path left (m; INF without one).
func remaining() -> float:
	if path.is_empty() or body == null:
		return INF
	var s := 0.0
	var p := body.global_position
	for i in range(_i, path.size()):
		s += p.distance_to(path[i])
		p = path[i]
	return s


func _fail(why: String) -> Vector3:
	on_path = false
	if status != FAILED or reason != why:
		give_ups += 1
	status = FAILED
	reason = why
	_fail_to = target
	_fail_t = _clock
	path = PackedVector3Array()
	return Vector3.ZERO


func _need_path(to: Vector3, at: Vector3, flat: float) -> bool:
	if path.is_empty():
		return true
	if _clock - _path_t < 0.35:
		return false
	# the target moved (following): off by more than a share of the way left
	if _path_to.distance_to(to) > 0.8 + 0.1 * flat:
		return true
	if world.iteration() != _iter and _clock - _path_t > 0.5:
		return true   # a tile was baked again under the path
	return false


func _make_path(at: Vector3, to: Vector3) -> bool:
	if not world.ready_at(at) or not world.ready_at(to):
		var far := Vector2(to.x - at.x, to.z - at.z).length()
		if far > FAR_M:
			_fail("no_nav")   # too far to bake the way: straight at it (the tiles come as it goes)
			return false
		# the tiles on the way are asked for; meanwhile the caller steers itself
		world.request(at, to, 1 if far > NavWorld.TILE else 0)
		status = WAIT
		reason = "baking"
		path = PackedVector3Array()
		return false
	var from := world.snap(at)
	if Vector2(from.x - at.x, from.z - at.z).length() > ON_MESH or absf(from.y - at.y) > 2.0:
		_fail("off_mesh")
		return false
	var p := world.path(at, to)
	paths += 1
	_path_t = _clock
	_path_to = to
	_iter = world.iteration()
	if p.size() < 2:
		# on the same spot of the mesh, or nothing: straight at it when close, else no way
		if Vector2(to.x - at.x, to.z - at.z).length() < 2.0:
			p = PackedVector3Array([at, to])
		else:
			_fail("no_path")
			return false
	path = p
	_i = 1
	var end := p[p.size() - 1]
	_partial = Vector2(end.x - to.x, end.z - to.z).length() > SLACK
	status = MOVING
	reason = ""
	_check_t = 0.0
	_check_at = at
	return true


func _follow(at: Vector3, to: Vector3, arrive: float) -> Vector3:
	# past the corners it is at (or has gone by: nearer the next leg than this corner)
	while _i < path.size():
		var c := path[_i]
		var d := Vector2(c.x - at.x, c.z - at.z).length()
		if d < CORNER or (_i < path.size() - 1 and d < 1.2 and _passed(at, path[_i - 1], c)):
			_i += 1
		else:
			break
	var aim: Vector3
	if _i >= path.size():
		if _partial:
			_fail("unreachable")
			return Vector3.ZERO
		aim = to   # the last bit, off the mesh's end (within SLACK)
	else:
		aim = path[_i]
	# a door on the next leg: opened, and waited for while the leaf swings
	if _door_ahead(at, aim):
		return Vector3.ZERO
	var v := Vector3(aim.x - at.x, 0.0, aim.z - at.z)
	if v.length() < 0.05:
		v = Vector3(to.x - at.x, 0.0, to.z - at.z)
	status = MOVING
	return v.normalized() if v.length() > 0.001 else Vector3.ZERO


## Whether the walker has gone past the corner `c` of the leg a -> c (its projection on the leg beyond c).
func _passed(at: Vector3, a: Vector3, c: Vector3) -> bool:
	var leg := Vector2(c.x - a.x, c.z - a.z)
	if leg.length() < 0.01:
		return true
	return Vector2(at.x - a.x, at.z - a.z).dot(leg) >= leg.length_squared()


func _door_ahead(at: Vector3, aim: Vector3) -> bool:
	var ahead := at + Vector3(aim.x - at.x, 0.0, aim.z - at.z).limit_length(3.0)
	var d := world.door_on(at, ahead, 0.9)
	if d == null and _i + 1 < path.size() and Vector2(aim.x - at.x, aim.z - at.z).length() < 3.0:
		d = world.door_on(aim, path[_i + 1], 0.9)
	waiting_door = null
	if d == null:
		_door_wait = 0.0
		return false
	var c := d.global_position
	var dist := Vector2(c.x - at.x, c.z - at.z).length()
	if dist > 3.0:
		return false
	if not d.is_open:
		world.open_door(d)
		doors_opened += 1
	if d.swing() < 0.95 and dist < 1.8 and dist > 0.3:   # (the leaf swings in: a walker going on under it is swept aside)
		_door_wait += 1.0 / Engine.physics_ticks_per_second
		waiting_door = d
		_check_t = 0.0
		_check_at = at
		return _door_wait < 4.0
	return false


## No headway for STUCK_S: a new path from here; after REPATHS of those, it gives up.
func _headway(dt: float, at: Vector3) -> void:
	_check_t += dt
	if _check_t < STUCK_S:
		return
	var moved := Vector2(at.x - _check_at.x, at.z - _check_at.z).length()
	_check_t = 0.0
	_check_at = at
	if moved > 0.35:
		_repaths = 0
		return
	_repaths += 1
	if _repaths > REPATHS:
		_repaths = 0
		_fail("stuck")
		return
	path = PackedVector3Array()   # asked again next frame, from here
