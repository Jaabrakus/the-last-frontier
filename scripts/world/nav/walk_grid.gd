class_name WalkGrid
extends Node
## THE WALK GRID: where a walker can go, and the plan of a walk made once (user 2026-09-30: "the user is queued a action the
## path finder sees it then the raycasting looks for obstacles from here and there and adjust"; "a point and click direction
## to go to"). The walk itself (following the plan, rays adjusting it) is WalkPath's.
##
## Movement costs, as in Civilization (user 2026-09-30: "it's kind of like civilization's turn based system ... the line
## itself will route, or if it has a tool it can jump over it or climb over it"): every cell has a cost to cross (the
## ground's slope, shallow water, near a wall), some cells cannot be crossed (too steep, deep water, a wall), and what
## cannot be crossed depends on what the walker CAN do (its `can`: step_m the height it steps over, climb_m the height it
## gets over with a tool or a skill (a rope, a vault), at CLIMB_COST; wade_m the depth of water it walks in).
##
## What is in the way is read from the world's own colliders, a 32 m sector at a time (a physics query of the sector's box;
## kept until something is built, felled or quarried there: dirty()): the trunks, the rocks, the logs and stumps, every
## built piece. A shape counts where it stands between BAND_LO and BAND_HI over the ground under it: lower (a log, a low
## stump) is stepped over (BodyStep) and only costs more, higher (a walkway's deck, a roof, the crowns) is walked under.
## Door leaves are not in the way (a walker opens the door as it comes).
##
## A plan (plan()): a grid of CELL cells over the start's and the goal's bounds, MARGIN_M more on every side (coarser past
## MAX_REGION_M), every shape in it grown by the walker's radius (a person 0.3 m, a horse 0.75 m: the horse's plan keeps it
## out of the gaps it cannot turn in), A* through it (Godot's AStarGrid2D), then straightened: from each point of the path
## to the furthest one in a clear straight line of it (a ray along the grid), so the walk is a few long legs, not a zig-zag.
##   WalkGrid.of(tree).plan(from, to, radius, can) -> PackedVector3Array   (from ... to; [] when there is no way)
##   WalkGrid.of(tree).routes(from, to, radius, can) -> Array   the ways there to choose from (user 2026-09-30: "go this way
##       or this or jump over"): [{kind, way, len, cost, over}, ...], the cheapest first ("best"); "around" the same trip
##       without the climb when the best goes over something; "other" a different way (the first one's cells made dearer)

const NODE_NAME := "WalkGrid"
const CELL := 0.5
const SECTOR_M := 32.0
## Over the ground: below BAND_LO a shape is stepped over, above BAND_HI walked under (m).
const BAND_LO := 0.55
const BAND_HI := 1.9
## The plan's grid reaches this far past the start and the goal (m); past MAX_REGION_M a side, its cells are coarser.
const MARGIN_M := 24.0
const MAX_REGION_M := 320.0
## A cell with a log or a low stump in it costs this much more to cross.
const STEP_COST := 2.5
const QUERY_MAX := 4096
## What a walker can do when it says nothing: step over what is under 0.5 m, climb nothing, wade to 0.6 m.
const CAN_STEP_M := 0.5
## Logs and stumps lying about are stepped over up to this (BodyStep.STEP_M), by anyone.
const LOW_STEP_M := 0.75
const CAN_WADE_M := 0.6
## Getting over a climbable obstacle costs this much more than the ground.
const CLIMB_COST := 6.0
## The ground's cost is sampled on this lattice (m); steeper than SLOPE_MAX degrees cannot be crossed, from SLOPE_EASY the
## cost climbs.
const GROUND_M := 2.0
const SLOPE_EASY := 12.0
const SLOPE_MAX := 38.0
const WATER_COST := 3.0
## An "other" route: the cells within OTHER_NEAR_M of the best route cost OTHER_COST times as much; it counts when it is
## a different way (OTHER_DIFF of its length more than OTHER_APART_M from the best) and no longer than OTHER_LONGER times.
const OTHER_NEAR_M := 3.0
const OTHER_COST := 6.0
const OTHER_APART_M := 4.0
const OTHER_DIFF := 0.3
const OTHER_LONGER := 1.7
## A goal (or a start) inside something: the nearest free cell within this many cells stands in for it.
const NEAR_FREE := 8
## Cells this near a wall, a trunk or a rock cost NEAR_COST more: a walk keeps a little off them where there is room.
const NEAR_M := 0.6
const NEAR_COST := 1.6
## The fort's ring (NavLandmarks) is always wholly in a plan's grid that meets it, with this much round it (m): a way
## round it is not cut off by the grid's edge. A plan more than RETRY_LONGER times the straight way is tried again on a
## grid RETRY_GROW times as wide.
const RING_ROOM_M := 14.0
const RETRY_LONGER := 1.8
const RETRY_GROW := 2.5

## sector -> [{poly: PackedVector2Array (a footprint, convex) or c: Vector2 + r: float (a circle), step: bool}]
var _sectors := {}
## sector -> PackedFloat32Array (SECTOR_M / GROUND_M squared, rows of x): the slope in degrees and (next array) the water's
## depth at each lattice point; the ground does not change, so they are kept.
var _slope := {}
var _depth := {}
var _qshape: BoxShape3D
var _low := false
## The last plan's grid (the debug view draws it), and counters for the tests.
var last := {}
var plans := 0


static func of(tree: SceneTree) -> WalkGrid:
	var scene := tree.current_scene if tree else null
	if scene == null:
		return null
	var g := scene.get_node_or_null(NODE_NAME) as WalkGrid
	if g != null:
		return g
	g = WalkGrid.new()
	g.name = NODE_NAME
	scene.add_child(g)
	return g


static func sector_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / SECTOR_M), floori(p.z / SECTOR_M))


## Something changed round `center` (built, felled, quarried): its sectors are read again when next planned over.
func dirty(center: Vector3, r: float) -> void:
	var a := sector_of(center - Vector3(r, 0, r))
	var b := sector_of(center + Vector3(r, 0, r))
	for z in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			_sectors.erase(Vector2i(x, z))


# ---------------------------------------------------------------- what is in the way
func _obstacles(k: Vector2i) -> Array:
	var got: Variant = _sectors.get(k)
	if got != null:
		return got
	var out: Array = []
	var world := get_viewport().find_world_3d() if is_inside_tree() else null
	if world == null:
		return out
	if _qshape == null:
		_qshape = BoxShape3D.new()
	var box := AABB(Vector3(k.x * SECTOR_M, -400.0, k.y * SECTOR_M), Vector3(SECTOR_M, 1200.0, SECTOR_M))
	_qshape.size = box.size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _qshape
	q.transform = Transform3D(Basis(), box.get_center())
	q.collision_mask = 1
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hits := world.direct_space_state.intersect_shape(q, QUERY_MAX)
	var seen := {}
	var r2 := Rect2(box.position.x - 1.0, box.position.z - 1.0, SECTOR_M + 2.0, SECTOR_M + 2.0)
	for hit: Dictionary in hits:
		var body := hit.get("collider") as CollisionObject3D
		if body == null or seen.has(body.get_instance_id()):
			continue
		seen[body.get_instance_id()] = true
		if not (body is StaticBody3D) or body is AnimatableBody3D or body.is_in_group(&"terrain") \
				or body.is_in_group(NavWorld.NO_NAV_GROUP) or (body.collision_layer & 1) == 0:
			continue
		for owner_id in body.get_shape_owners():
			var cs := body.shape_owner_get_owner(owner_id) as CollisionShape3D
			if cs == null or cs.disabled or cs.shape == null:
				continue
			_add_shape(cs.shape, cs.global_transform, r2, out, body.is_in_group(FrontierVegetation.LOW_GROUP))
	_sectors[k] = out
	return out


## A shape's footprint(s) into `out` when it meets `r2` and stands in the walking band (or low: a step).
func _add_shape(shape: Shape3D, xf: Transform3D, r2: Rect2, out: Array, low := false) -> void:
	_low = low
	if shape is ConcavePolygonShape3D:
		# (a mesh: each of its walls on its own, not the hull of all of it; the floors are walked on)
		var f := (shape as ConcavePolygonShape3D).get_faces()
		for i in range(0, f.size() - 2, 3):
			var a := xf * f[i]
			var b := xf * f[i + 1]
			var c := xf * f[i + 2]
			var n := (b - a).cross(c - a)
			if n.length() < 1e-6 or absf(n.normalized().y) > 0.7:
				continue
			_add_hull([a, b, c], r2, out)
		return
	var pts: Array = []
	if (shape is CylinderShape3D or shape is CapsuleShape3D) and xf.basis.y.normalized().dot(Vector3.UP) > 0.9:
		# upright: a trunk, a post, a stump
		var rr: float = shape.get("radius") * maxf(xf.basis.x.length(), xf.basis.z.length())
		var hh: float = shape.get("height") * xf.basis.y.length() * 0.5
		var c2 := Vector2(xf.origin.x, xf.origin.z)
		if not r2.grow(rr).has_point(c2):
			return
		var ground := FrontierTerrain.height_at(c2.x, c2.y)
		var top := _top(xf.origin.y - hh, xf.origin.y + hh, ground)
		if top >= 0.0:
			out.append({"c": c2, "r": rr, "top": top, "low": low})
		return
	if shape is BoxShape3D:
		var e := (shape as BoxShape3D).size * 0.5
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					pts.append(xf * Vector3(e.x * sx, e.y * sy, e.z * sz))
	elif shape is ConvexPolygonShape3D:
		for p in (shape as ConvexPolygonShape3D).points:
			pts.append(xf * p)
	elif shape is CylinderShape3D or shape is CapsuleShape3D:
		# lying: a log, a felled trunk (its box)
		var rr2: float = shape.get("radius")
		var hh2: float = shape.get("height") * 0.5
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					pts.append(xf * Vector3(rr2 * sx, hh2 * sy, rr2 * sz))
	elif shape is SphereShape3D:
		var rs := (shape as SphereShape3D).radius * xf.basis.get_scale().x
		var cs2 := Vector2(xf.origin.x, xf.origin.z)
		var g2 := FrontierTerrain.height_at(cs2.x, cs2.y)
		var bs := _top(xf.origin.y - rs, xf.origin.y + rs, g2)
		if bs >= 0.0 and r2.grow(rs).has_point(cs2):
			out.append({"c": cs2, "r": rs, "top": bs, "low": low})
		return
	else:
		var ab := shape.get_debug_mesh().get_aabb()
		for i in 8:
			pts.append(xf * ab.get_endpoint(i))
	_add_hull(pts, r2, out)


func _add_hull(pts: Array, r2: Rect2, out: Array) -> void:
	var flat := PackedVector2Array()
	var lo := INF
	var hi := -INF
	for p: Vector3 in pts:
		flat.append(Vector2(p.x, p.z))
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var hull := Geometry2D.convex_hull(flat)
	if hull.size() < 3:
		# (a wall face seen edge on: a sliver, thickened a little)
		if flat.size() >= 2:
			var a := flat[0]
			var b := flat[flat.size() - 1]
			var n := (b - a).orthogonal().normalized() * 0.05
			hull = PackedVector2Array([a - n, b - n, b + n, a + n])
		else:
			return
	var bb := Rect2(hull[0], Vector2.ZERO)
	for v in hull:
		bb = bb.expand(v)
	if not bb.intersects(r2):
		return
	var cc := bb.get_center()
	var top := _top(lo, hi, FrontierTerrain.height_at(cc.x, cc.y))
	if top >= 0.0:
		out.append({"poly": hull, "top": top, "low": _low})


## How high a shape stands over the ground (m) when it is in the way of a walker (it starts within BAND_HI of the ground
## and reaches up off it); -1 where it is walked under (its underside over BAND_HI) or does not reach up off the ground.
static func _top(lo: float, hi: float, ground: float) -> float:
	if lo > ground + BAND_HI or hi < ground + 0.06:
		return -1.0
	return maxf(hi - ground, 0.0)


# ---------------------------------------------------------------- the plan
## The way from `from` to `to` for a walker `radius` wide: its points (the first `from`, the last `to` or, when `to` is
## inside something, the nearest free place to it), each straight on to the next; [] when there is no way at all.
func plan(from: Vector3, to: Vector3, radius := 0.3, can := {}, avoid := PackedVector3Array()) -> PackedVector3Array:
	plans += 1
	var out := _plan(from, to, radius, MARGIN_M, can, avoid)
	var straight := Vector2(to.x - from.x, to.z - from.z).length()
	if out.is_empty() or (straight > 4.0 and _length(out) > straight * RETRY_LONGER):
		var wide := _plan(from, to, radius, MARGIN_M * RETRY_GROW, can, avoid)
		if not wide.is_empty() and (out.is_empty() or _length(wide) < _length(out)):
			out = wide
	return out


static func _length(pts: PackedVector3Array) -> float:
	var s := 0.0
	for i in pts.size() - 1:
		s += Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
	return s


## The ways from `from` to `to` to choose from: the cheapest ("best"), the same trip without the climb when the best goes
## over something ("around"), and a different way where there is one ("other"). Each {kind, way, len (m), cost, over}.
func routes(from: Vector3, to: Vector3, radius := 0.3, can := {}, alternatives := true) -> Array:
	var out := []
	var best := plan(from, to, radius, can)
	if best.is_empty() or not alternatives:
		if not best.is_empty():
			out.append({"kind": "best", "way": best, "len": _length(best), "cost": float(last.get("cost", 0.0)), "over": bool(last.get("over", false))})
		return out
	var lb := last.duplicate()
	out.append({"kind": "best", "way": best, "len": _length(best), "cost": float(lb.get("cost", 0.0)), "over": bool(lb.get("over", false))})
	if bool(lb.get("over", false)):
		var nc := can.duplicate()
		nc["climb_m"] = 0.0
		var ar := plan(from, to, radius, nc)
		if not ar.is_empty():
			out.append({"kind": "around", "way": ar, "len": _length(ar), "cost": float(last.get("cost", 0.0)), "over": false})
	var alt := plan(from, to, radius, can, best)
	if not alt.is_empty() and _length(alt) <= _length(best) * OTHER_LONGER and _apart(alt, best) >= OTHER_DIFF:
		var dup := false
		for r: Dictionary in out:
			if _apart(alt, r.way) < OTHER_DIFF:
				dup = true
		if not dup:
			out.append({"kind": "other", "way": alt, "len": _length(alt), "cost": float(last.get("cost", 0.0)), "over": bool(last.get("over", false))})
	return out


## The share of `a`'s length that lies further than OTHER_APART_M from polyline `b`.
static func _apart(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var total := 0.0
	var far := 0.0
	for i in a.size() - 1:
		var seg := Vector2(a[i + 1].x - a[i].x, a[i + 1].z - a[i].z)
		var n := maxi(ceili(seg.length() / 1.0), 1)
		for k in n:
			var p := a[i].lerp(a[i + 1], (k + 0.5) / n)
			var d := INF
			for j in b.size() - 1:
				var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(b[j].x, b[j].z), Vector2(b[j + 1].x, b[j + 1].z))
				d = minf(d, Vector2(p.x, p.z).distance_to(q))
			total += seg.length() / n
			if d > OTHER_APART_M:
				far += seg.length() / n
	return far / maxf(total, 0.01)


func _plan(from: Vector3, to: Vector3, radius: float, margin: float, can: Dictionary, avoid := PackedVector3Array()) -> PackedVector3Array:
	var t0 := Time.get_ticks_usec()
	var lo := Vector2(minf(from.x, to.x), minf(from.z, to.z)) - Vector2.ONE * margin
	var hi := Vector2(maxf(from.x, to.x), maxf(from.z, to.z)) + Vector2.ONE * margin
	# (the fort's ring wholly in it, with room round it, when the grid meets it)
	NavLandmarks._refresh(get_tree())
	var ring := NavLandmarks._box
	if ring.size != Vector2.ZERO and Rect2(lo, hi - lo).intersects(ring):
		var rr := ring.grow(RING_ROOM_M)
		lo = Vector2(minf(lo.x, rr.position.x), minf(lo.y, rr.position.y))
		hi = Vector2(maxf(hi.x, rr.end.x), maxf(hi.y, rr.end.y))
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	var cell := CELL
	while span / cell > MAX_REGION_M / CELL:
		cell *= 2.0
	var w := ceili((hi.x - lo.x) / cell)
	var h := ceili((hi.y - lo.y) / cell)
	var ag := AStarGrid2D.new()
	ag.region = Rect2i(0, 0, w, h)
	ag.cell_size = Vector2(cell, cell)
	ag.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	ag.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	ag.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	ag.update()
	var n_obs := 0
	var sa := sector_of(Vector3(lo.x, 0, lo.y))
	var sb := sector_of(Vector3(hi.x, 0, hi.y))
	var steps: Array = []
	var blocks: Array = []
	var climbs: Array = []
	var step_m := float(can.get("step_m", CAN_STEP_M))
	var climb_m := float(can.get("climb_m", 0.0))
	for sz in range(sa.y, sb.y + 1):
		for sx in range(sa.x, sb.x + 1):
			for o: Dictionary in _obstacles(Vector2i(sx, sz)):
				var top := float(o.top)
				if top <= step_m or (bool(o.get("low", false)) and top <= float(can.get("low_step_m", LOW_STEP_M))):
					steps.append(o)
				elif top <= climb_m:
					climbs.append(o)
				else:
					blocks.append(o)
	# the ground's own cost first: the slope and the water (steeper than SLOPE_MAX, or deeper than she wades: solid)
	_ground_cost(ag, lo, cell, w, h, float(can.get("wade_m", CAN_WADE_M)))
	# (near a wall or a trunk: a higher cost; a log or a low stump: higher still; in it: solid)
	for o: Dictionary in blocks:
		_fill(ag, o, radius + NEAR_M, lo, cell, w, h, false, NEAR_COST)
	for o: Dictionary in steps:
		_fill(ag, o, radius * 0.5, lo, cell, w, h, false, STEP_COST)
	for o: Dictionary in climbs:
		_fill(ag, o, radius * 0.5, lo, cell, w, h, false, CLIMB_COST)   # (over it: with what she has)
	for o: Dictionary in blocks:
		n_obs += 1
		_fill(ag, o, radius, lo, cell, w, h, true)
	if avoid.size() >= 2:
		_dear(ag, avoid, lo, cell, w, h)
	var a := _cell_of(from, lo, cell, w, h)
	var b := _cell_of(to, lo, cell, w, h)
	a = _free_near(ag, a)
	var b2 := _free_near(ag, b)
	var ids: Array[Vector2i] = []
	if a.x >= 0 and b2.x >= 0:
		ids = ag.get_id_path(a, b2, true)
	var out := PackedVector3Array()
	if ids.is_empty():
		last = {"ag": ag, "lo": lo, "cell": cell, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "obs": n_obs, "ok": false}
		return out
	var cost := 0.0
	var over := false
	for i in ids.size():
		var wgt := ag.get_point_weight_scale(ids[i])
		if i > 0:
			cost += wgt * (Vector2(ids[i]) - Vector2(ids[i - 1])).length() * cell
		if not over and not climbs.is_empty() and wgt > 1.0:
			# (over something she climbs: a cell of the route inside one of the footprints she climbs)
			var pc := lo + (Vector2(ids[i]) + Vector2(0.5, 0.5)) * cell
			for o: Dictionary in climbs:
				if (o.has("c") and pc.distance_to(o.c) <= float(o.r)) or (o.has("poly") and Geometry2D.is_point_in_polygon(pc, o.poly)):
					over = true
					break
	var pull := _pull(ag, ids)
	out.append(from)
	for i in range(1, pull.size()):
		var c := pull[i]
		var p := lo + (Vector2(c) + Vector2(0.5, 0.5)) * cell
		out.append(Vector3(p.x, FrontierTerrain.height_at(p.x, p.y), p.y))
	# (the goal itself when it was free and reached; else the nearest free cell to it stands for it)
	if b2 == b and ids[ids.size() - 1] == b2:
		out[out.size() - 1] = to
	last = {"ag": ag, "lo": lo, "cell": cell, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "obs": n_obs, "ok": true,
			"raw": ids.size(), "legs": out.size() - 1, "cost": cost, "over": over}
	return out


## The ground's slope and water into the grid: a GROUND_M block at a time from the kept lattice.
func _ground_cost(ag: AStarGrid2D, lo: Vector2, cell: float, w: int, h: int, wade: float) -> void:
	var sa := sector_of(Vector3(lo.x, 0, lo.y))
	var sb := sector_of(Vector3(lo.x + w * cell, 0, lo.y + h * cell))
	var per := int(SECTOR_M / GROUND_M)
	for sz in range(sa.y, sb.y + 1):
		for sx in range(sa.x, sb.x + 1):
			var k := Vector2i(sx, sz)
			var sl: PackedFloat32Array = _slope_of(k)
			var dp: PackedFloat32Array = _depth_of(k)
			for j in per:
				for i in per:
					var slope := sl[j * per + i]
					var depth := dp[j * per + i]
					if slope <= SLOPE_EASY and depth < 0.08:
						continue
					var x0 := sx * SECTOR_M + i * GROUND_M
					var z0 := sz * SECTOR_M + j * GROUND_M
					var c0 := floori((x0 - lo.x) / cell)
					var r0 := floori((z0 - lo.y) / cell)
					var span := maxi(ceili(GROUND_M / cell), 1)
					var r := Rect2i(c0, r0, span, span).intersection(Rect2i(0, 0, w, h))
					if r.size.x <= 0 or r.size.y <= 0:
						continue
					if slope > SLOPE_MAX or depth > wade:
						ag.fill_solid_region(r, true)
					else:
						var c := 1.0 + maxf(slope - SLOPE_EASY, 0.0) / (SLOPE_MAX - SLOPE_EASY) * 5.0
						if depth >= 0.08:
							c += WATER_COST
						ag.fill_weight_scale_region(r, c)


func _slope_of(k: Vector2i) -> PackedFloat32Array:
	var got: Variant = _slope.get(k)
	if got != null:
		return got
	var per := int(SECTOR_M / GROUND_M)
	var out := PackedFloat32Array()
	out.resize(per * per)
	for j in per:
		for i in per:
			var x := k.x * SECTOR_M + (i + 0.5) * GROUND_M
			var z := k.y * SECTOR_M + (j + 0.5) * GROUND_M
			out[j * per + i] = rad_to_deg(acos(clampf(FrontierTerrain.normal_at(x, z).y, 0.0, 1.0)))
	_slope[k] = out
	return out


func _depth_of(k: Vector2i) -> PackedFloat32Array:
	var got: Variant = _depth.get(k)
	if got != null:
		return got
	var per := int(SECTOR_M / GROUND_M)
	var out := PackedFloat32Array()
	out.resize(per * per)
	if WorldRiver.has_water():
		for j in per:
			for i in per:
				var x := k.x * SECTOR_M + (i + 0.5) * GROUND_M
				var z := k.y * SECTOR_M + (j + 0.5) * GROUND_M
				out[j * per + i] = WorldRiver.depth_at(Vector3(x, 0.0, z))
	_depth[k] = out
	return out


## The cells near polyline `way` made OTHER_COST times as dear (not the solid ones): a plan over it goes another way.
static func _dear(ag: AStarGrid2D, way: PackedVector3Array, lo: Vector2, cell: float, w: int, h: int) -> void:
	var r := ceili(OTHER_NEAR_M / cell)
	var done := {}
	for i in way.size() - 1:
		var a := Vector2(way[i].x, way[i].z)
		var b := Vector2(way[i + 1].x, way[i + 1].z)
		var n := maxi(ceili(a.distance_to(b) / (cell * 2.0)), 1)
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			var c0 := Vector2i(floori((p.x - lo.x) / cell), floori((p.y - lo.y) / cell))
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dz * dz > r * r:
						continue
					var c := c0 + Vector2i(dx, dz)
					if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or done.has(c) or ag.is_point_solid(c):
						continue
					done[c] = true
					ag.set_point_weight_scale(c, ag.get_point_weight_scale(c) * OTHER_COST)


static func _cell_of(p: Vector3, lo: Vector2, cell: float, w: int, h: int) -> Vector2i:
	return Vector2i(clampi(floori((p.x - lo.x) / cell), 0, w - 1), clampi(floori((p.z - lo.y) / cell), 0, h - 1))


## The shape `o` grown by `grow` into the grid: solid (`block`), or a higher cost (a step).
static func _fill(ag: AStarGrid2D, o: Dictionary, grow: float, lo: Vector2, cell: float, w: int, h: int, block: bool, cost := STEP_COST) -> void:
	if o.has("c"):
		var c: Vector2 = o.c
		var rr := float(o.r) + grow
		var r0 := maxi(floori((c.y - rr - lo.y) / cell), 0)
		var r1 := mini(floori((c.y + rr - lo.y) / cell), h - 1)
		for row in range(r0, r1 + 1):
			var yc := lo.y + (row + 0.5) * cell
			var dy := yc - c.y
			if absf(dy) > rr:
				continue
			var half := sqrt(rr * rr - dy * dy)
			_run(ag, row, c.x - half, c.x + half, lo, cell, w, block, cost)
		return
	var poly: PackedVector2Array = o.poly
	if grow > 0.0:
		var grown := Geometry2D.offset_polygon(poly, grow, Geometry2D.JOIN_ROUND)
		if not grown.is_empty():
			poly = grown[0]
	var y0 := INF
	var y1 := -INF
	for v in poly:
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	var ra := maxi(floori((y0 - lo.y) / cell), 0)
	var rb := mini(floori((y1 - lo.y) / cell), h - 1)
	var n := poly.size()
	for row in range(ra, rb + 1):
		var yc := lo.y + (row + 0.5) * cell
		var xa := INF
		var xb := -INF
		for i in n:
			var p := poly[i]
			var q := poly[(i + 1) % n]
			if (p.y <= yc and q.y >= yc) or (q.y <= yc and p.y >= yc):
				var x := p.x if absf(q.y - p.y) < 1e-6 else p.x + (yc - p.y) / (q.y - p.y) * (q.x - p.x)
				xa = minf(xa, x)
				xb = maxf(xb, x)
		if xa <= xb:
			_run(ag, row, xa, xb, lo, cell, w, block, cost)


static func _run(ag: AStarGrid2D, row: int, xa: float, xb: float, lo: Vector2, cell: float, w: int, block: bool, cost: float) -> void:
	# (the cells the span covers, a cell counted when any of it is in: the walker's radius is in the span already)
	var c0 := maxi(floori((xa - lo.x) / cell), 0)
	var c1 := mini(floori((xb - lo.x) / cell), w - 1)
	if c1 < c0:
		return
	var r := Rect2i(c0, row, c1 - c0 + 1, 1)
	if block:
		ag.fill_solid_region(r, true)
	else:
		ag.fill_weight_scale_region(r, cost)


## `c` when free, else the nearest free cell within NEAR_FREE (Vector2i(-1, -1): none).
static func _free_near(ag: AStarGrid2D, c: Vector2i) -> Vector2i:
	if not ag.is_point_solid(c):
		return c
	for rr in range(1, NEAR_FREE + 1):
		var best := Vector2i(-1, -1)
		var bd := INF
		for dz in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				if maxi(absi(dx), absi(dz)) != rr:
					continue
				var k := c + Vector2i(dx, dz)
				if ag.is_in_boundsv(k) and not ag.is_point_solid(k):
					var d := Vector2(dx, dz).length()
					if d < bd:
						bd = d
						best = k
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## The path's cells straightened: from each kept cell, on to the furthest one it has a clear straight line to.
static func _pull(ag: AStarGrid2D, ids: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = [ids[0]]
	var i := 0
	var n := ids.size()
	while i < n - 1:
		# (the furthest in sight: out in doubling strides to the first one not in sight, then halved back between them)
		var j := i + 1
		var bad := n
		var s := 1
		while true:
			var k := mini(i + s, n - 1)
			if _clear(ag, ids[i], ids[k]):
				j = k
				if k == n - 1:
					break
				s *= 2
			else:
				bad = k
				break
		while bad - j > 1:
			var m := (j + bad) / 2
			if _clear(ag, ids[i], ids[m]):
				j = m
			else:
				bad = m
		out.append(ids[j])
		i = j
	return out


## Whether the straight line between two cells crosses no solid cell (a ray along the grid, both of its sides looked at
## where it runs diagonally: it does not squeeze between two cells that touch at a corner).
static func _clear(ag: AStarGrid2D, a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	var steps := maxi(absi(d.x), absi(d.y))
	if steps == 0:
		return true
	var prev := a
	for s in range(1, steps + 1):
		var t := float(s) / float(steps)
		var c := Vector2i(roundi(a.x + d.x * t), roundi(a.y + d.y * t))
		if ag.is_point_solid(c):
			return false
		if c.x != prev.x and c.y != prev.y:
			if ag.is_point_solid(Vector2i(c.x, prev.y)) or ag.is_point_solid(Vector2i(prev.x, c.y)):
				return false
		prev = c
	return true
