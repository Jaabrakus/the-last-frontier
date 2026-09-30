class_name NavLandmarks
extends RefCounted
## LANDMARKS (user 2026-09-29: "it should do landmarks like gate etc, that's better logic for npc pathfinding"): the big
## plan of a walk or a ride, over the navigation mesh's leg by leg and the feelers' last metres. The fort's gates are the
## landmarks: a trip from inside the palisade to outside it, or in, goes to the gate's side it starts on (GATE_OUT_M in front
## of it), through to the other side, then on; the gate the one that makes the trip shortest. Inside: within the ring of
## palisade stretches, gates and blockhouses (a point is inside when rays from it cross the ring an odd number of times,
## RAYS of them voting: a ray through a corner's seam miscounts). Outside, a trip whose straight line runs into the fort goes
## round it by its corners (the ring's bounds AROUND_M out, the shorter way round): the far side of the fort from the gate
## is reached round the outside, not back through it. Read from the world's built pieces
## (BuildWorld: every "palisade" stretch a wall, every "palisade_gate" a gate with its door), kept a moment (KEEP_S).
##   NavLandmarks.leg(tree, at, to)  -> the point to make for now: `to` itself, or a gate's near or far side
##   NavLandmarks.route(tree, at, to) -> the gate's sides still ahead ([] when no palisade stands between)
##   NavLandmarks.gate_near(tree, p, r) -> the gate's door within r of p (to open it on the way), or null

## A gate's sides this far out from it (m): room for a horse to come square to it.
const GATE_OUT_M := 4.0
## A side is reached within this (m).
const AT_M := 1.6
## A palisade stretch is this long (m): the build's 3 m modules.
const STRETCH_M := 3.0
const KEEP_S := 2.0
## Round the fort this far out from its bounds (m); a corner is passed within CORNER_AT_M.
const AROUND_M := 7.0
const CORNER_AT_M := 3.0

static var _walls: Array = []        ## [centre, along (unit, flat), half length]
static var _ring: Array = []         ## [a, b] (Vector2): the palisade, the gates and the blockhouses' sides, for inside()
static var _box := Rect2()           ## the ring's bounds (x, z)
static var _gates: Array = []        ## {pos, n (unit, flat, out of the fort), door, half}
static var _at_ms := -100000
static var _tree_id := 0


static func _refresh(tree: SceneTree) -> void:
	var now := Time.get_ticks_msec()
	if tree != null and tree.get_instance_id() == _tree_id and now - _at_ms < int(KEEP_S * 1000.0):
		return
	_at_ms = now
	_tree_id = tree.get_instance_id() if tree else 0
	_walls = []
	_gates = []
	_ring = []
	_box = Rect2()
	var world := BuildWorld.of(tree, false) if tree else null
	if world == null:
		return
	for p in world.pieces():
		if not is_instance_valid(p) or not p.is_inside_tree():
			continue
		var along := p.global_basis.x
		along.y = 0.0
		if along.length() < 1e-3:
			continue
		along = along.normalized()
		var half := STRETCH_M * 0.5 * p.global_basis.x.length()
		var c := Vector2(p.global_position.x, p.global_position.z)
		var u := Vector2(along.x, along.z) * half
		if p.type == "palisade":
			_walls.append([p.global_position, along, half])
			_ring.append([c - u, c + u])
		elif p.type == "palisade_gate":
			var n := p.global_basis.z
			n.y = 0.0
			_gates.append({"pos": p.global_position, "n": n.normalized(), "door": p.door, "half": half})
			_ring.append([c - u, c + u])
		elif p.type == "blockhouse":
			# (its four sides: it stands on a corner of the ring)
			var v := Vector2(-u.y, u.x)
			for e: Array in [[c - u - v, c + u - v], [c + u - v, c + u + v], [c + u + v, c - u + v], [c - u + v, c - u - v]]:
				_ring.append(e)
	var first := true
	for e: Array in _ring:
		for q: Vector2 in e:
			_box = Rect2(q, Vector2.ZERO) if first else _box.expand(q)
			first = false


## Whether the straight way from `a` to `b` goes through a palisade stretch (not a gate).
static func walled(tree: SceneTree, a: Vector3, b: Vector3) -> bool:
	_refresh(tree)
	for w: Array in _walls:
		var c: Vector3 = w[0]
		var u: Vector3 = w[1]
		var h: float = w[2]
		if _cross(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x - u.x * h, c.z - u.z * h), Vector2(c.x + u.x * h, c.z + u.z * h)):
			return true
	return false


static func _cross(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var r := p2 - p1
	var s := q2 - q1
	var den := r.cross(s)
	if absf(den) < 1e-6:
		return false
	var t := (q1 - p1).cross(s) / den
	var u := (q1 - p1).cross(r) / den
	return t > 0.0 and t < 1.0 and u >= 0.0 and u <= 1.0


const RAYS := [Vector2(1.0, 0.37), Vector2(-0.41, 1.0), Vector2(-1.0, -0.29)]


## Whether `p` is inside the palisade's ring.
static func inside(tree: SceneTree, p: Vector3) -> bool:
	_refresh(tree)
	if _ring.is_empty():
		return false
	var a := Vector2(p.x, p.z)
	var votes := 0
	for r: Vector2 in RAYS:
		var b := a + r.normalized() * 2000.0
		var n := 0
		for e: Array in _ring:
			if _cross(a, b, e[0], e[1]):
				n += 1
		if n % 2 == 1:
			votes += 1
	return votes * 2 > RAYS.size()


static func _side(g: Dictionary, p: Vector3) -> float:
	var d := p - (g.pos as Vector3)
	return 1.0 if Vector2(d.x, d.z).dot(Vector2((g.n as Vector3).x, (g.n as Vector3).z)) >= 0.0 else -1.0


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The gate's sides still ahead on the way from `at` to `to`: [near, far], [far] (at its near side already, or in it), or []
## (no palisade between, or no gate).
static func route(tree: SceneTree, at: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	_refresh(tree)
	if _ring.is_empty():
		return out
	var at_in := inside(tree, at)
	var to_in := inside(tree, to)
	if at_in == to_in:
		return out if at_in else _around(at, to)
	if _gates.is_empty():
		return out
	var best := {}
	var best_c := INF
	for g: Dictionary in _gates:
		# (its inner side: the one of its two sides inside the ring)
		var o := (g.pos as Vector3) + (g.n as Vector3) * GATE_OUT_M
		var s_in := -1.0 if not inside(tree, o) else 1.0
		var sa := s_in if at_in else -s_in
		var near: Vector3 = (g.pos as Vector3) + (g.n as Vector3) * sa * GATE_OUT_M
		var far: Vector3 = (g.pos as Vector3) - (g.n as Vector3) * sa * GATE_OUT_M
		var c := _flat(at, near) + _flat(far, to)
		if c < best_c:
			best_c = c
			best = {"g": g, "near": near, "far": far}
	if best.is_empty():
		return out
	var g2: Dictionary = best.g
	var near2: Vector3 = best.near
	# (in the gateway, or at its near side: through to the far side)
	var d := at - (g2.pos as Vector3)
	var n: Vector3 = g2.n
	var off := Vector2(d.x, d.z).dot(Vector2(n.x, n.z))
	var lat := absf(Vector2(d.x, d.z).dot(Vector2(-n.z, n.x)))
	if _flat(at, near2) > AT_M and not (absf(off) < GATE_OUT_M and lat < float(g2.half) * 0.6):
		if not at_in:
			out.append_array(_around(at, near2))   # (round the fort to the gate's side first)
		out.append(_ground(near2))
	out.append(_ground(best.far))
	if at_in:
		out.append_array(_around(best.far, to))   # (out of the gate and round the fort to the far side)
	return out


## Round the fort from `at` to `to` (both outside it): its corners AROUND_M out, the shorter way round, those still ahead;
## [] when the straight way does not run into it.
static func _around(at: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if _box.size == Vector2.ZERO:
		return out
	# (a point in the bounds' margin outside the ring, by a gate or a blockhouse: taken from just outside them)
	var a := _out_of(Vector2(at.x, at.z))
	var b := _out_of(Vector2(to.x, to.z))
	if not _seg_box(a, b, _box):
		return out
	var g := _box.grow(AROUND_M)
	var cs := [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]
	var best := INF
	var chain: Array = []
	for i in 4:
		if _seg_box(a, cs[i], _box):
			continue
		for j in 4:
			if _seg_box(cs[j], b, _box):
				continue
			for dirn: int in [1, -1]:
				var ch := [i]
				var k := i
				var len := a.distance_to(cs[i])
				while k != j:
					var nk := posmod(k + dirn, 4)
					len += (cs[k] as Vector2).distance_to(cs[nk])
					k = nk
					ch.append(k)
				len += (cs[j] as Vector2).distance_to(b)
				if len < best:
					best = len
					chain = ch
	for k2: int in chain:
		var c: Vector2 = cs[k2]
		if out.is_empty() and a.distance_to(c) <= CORNER_AT_M:
			continue
		out.append(_ground(Vector3(c.x, 0.0, c.y)))
	return out


## `p` moved out of the ring's bounds to just past their nearest side (p itself when it is not in them).
static func _out_of(p: Vector2) -> Vector2:
	if not _box.has_point(p):
		return p
	var d := [p.x - _box.position.x, _box.end.x - p.x, p.y - _box.position.y, _box.end.y - p.y]
	var k := 0
	for i in 4:
		if float(d[i]) < float(d[k]):
			k = i
	var m := float(d[k]) + 0.3
	return p + [Vector2(-m, 0), Vector2(m, 0), Vector2(0, -m), Vector2(0, m)][k]


## Whether segment a-b passes through box `r` (Liang-Barsky).
static func _seg_box(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for k in 4:
		var p: float = [-d.x, d.x, -d.y, d.y][k]
		var q: float = [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y][k]
		if absf(p) < 1e-9:
			if q < 0.0:
				return false
			continue
		var t := q / p
		if p < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return false
	return true


## The point to make for now on the way from `at` to `to`.
static func leg(tree: SceneTree, at: Vector3, to: Vector3) -> Vector3:
	var r := route(tree, at, to)
	return r[0] if not r.is_empty() else to


## The door of a gate whose opening is within `r` of `p`, or null.
static func gate_near(tree: SceneTree, p: Vector3, r: float) -> BuildDoor:
	_refresh(tree)
	for g: Dictionary in _gates:
		if _flat(p, g.pos) <= r and g.door != null and is_instance_valid(g.door):
			return g.door
	return null


static func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)
