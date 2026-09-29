class_name NavSource
extends RefCounted
## The geometry a nav tile is baked from (NavWorld): gathered on the main thread for a box of the world, handed to the
## NavigationServer's bake on a worker thread. Not the engine's own parser: that walks whole nodes (a 50 m cell of tree
## trunks, a 64 m height-field chunk) and cannot tell a door leaf from a wall; this takes only what is in the box.
##   - the ground: FrontierTerrain.height_at on the 1 m grid (the height field's own samples), not the colliders (the
##     "terrain" bodies are skipped: the flat-zone boxes, the height-field chunks and the dirt / stone overlays all lie on it);
##   - every other static collider in the box (one physics shape query): boxes, concave meshes and small convex hulls as
##     faces (floors, ramps, walls, roofs: Recast walks what it can stand on), upright cylinders and capsules (tree trunks,
##     posts, stumps) and big convex hulls (rocks) as projected obstructions (a hole the agent's radius wide round them in
##     the ground under them, so no island on a trunk's top), lying cylinders (felled trunks, logs) as prisms;
##   - a BuildDoor's leaves (AnimatableBody3D hinges) where they stand OPEN, shut or not: the doorway is open on the mesh (the
##     NavMover opens a shut door as it comes to it) and the path keeps off the open leaf;
##   - not: moving bodies (characters, animals, the player's horse), rigid bodies, other AnimatableBody3Ds.
## Faces are wound as Godot's (clockwise seen from outside): Recast reads a face as floor when cross(b - a, c - a) points down.

const QUERY_MAX := 4096
## Convex hulls with at most this many points are made into faces (a brute-force hull: a roof, a gable); more (a rock's hull)
## become an obstruction of their footprint.
const HULL_FACES_MAX := 16
const CYL_SIDES := 10
## An upright shape leaning less than this (cos of the angle to up) is an obstruction.
const UPRIGHT_COS := 0.94

static var _qshape: BoxShape3D
static var _local_box := {}


## Fills `out` with the geometry of the box `box` (its x / z; y is the height range to take colliders from). `stats` gets
## counts: faces, obstructions, shapes, skipped, full (the query hit QUERY_MAX).
static func gather(world: World3D, box: AABB, out: NavigationMeshSourceGeometryData3D, stats: Dictionary) -> void:
	_terrain(box, out, stats)
	if world != null:
		_colliders(world, box, out, stats)


# ---------------------------------------------------------------- the ground
static func _terrain(box: AABB, out: NavigationMeshSourceGeometryData3D, stats: Dictionary) -> void:
	var x0 := floori(box.position.x)
	var z0 := floori(box.position.z)
	var x1 := ceili(box.end.x)
	var z1 := ceili(box.end.z)
	var nx := x1 - x0 + 1
	var nz := z1 - z0 + 1
	var h := PackedFloat32Array()
	h.resize(nx * nz)
	var lo := INF
	var hi := -INF
	for j in nz:
		for i in nx:
			var y := FrontierTerrain.height_at(x0 + i, z0 + j)
			h[j * nx + i] = y
			lo = minf(lo, y)
			hi = maxf(hi, y)
	var faces := PackedVector3Array()
	faces.resize((nx - 1) * (nz - 1) * 6)
	var k := 0
	for j in nz - 1:
		for i in nx - 1:
			var a := Vector3(x0 + i, h[j * nx + i], z0 + j)
			var b := Vector3(x0 + i + 1, h[j * nx + i + 1], z0 + j)
			var c := Vector3(x0 + i + 1, h[(j + 1) * nx + i + 1], z0 + j + 1)
			var d := Vector3(x0 + i, h[(j + 1) * nx + i], z0 + j + 1)
			# a -> b -> c: cross points down (Godot's winding for an up face)
			faces[k] = a
			faces[k + 1] = b
			faces[k + 2] = c
			faces[k + 3] = a
			faces[k + 4] = c
			faces[k + 5] = d
			k += 6
	out.add_faces(faces, Transform3D.IDENTITY)
	stats["ground_lo"] = lo
	stats["ground_hi"] = hi
	stats["faces"] = int(stats.get("faces", 0)) + faces.size() / 3


# ---------------------------------------------------------------- the colliders
static func _colliders(world: World3D, box: AABB, out: NavigationMeshSourceGeometryData3D, stats: Dictionary) -> void:
	if _qshape == null:
		_qshape = BoxShape3D.new()
	_qshape.size = box.size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _qshape
	q.transform = Transform3D(Basis(), box.get_center())
	q.collision_mask = 1
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hits := world.direct_space_state.intersect_shape(q, QUERY_MAX)
	stats["full"] = hits.size() >= QUERY_MAX
	# the query answers a body once (Jolt: not per shape of a compound), so every shape of each body hit is looked at and
	# kept when its bounds meet the box (a 50 m cell's trunks are one body)
	var seen := {}
	var faces := PackedVector3Array()
	var n_obs := 0
	var n_shapes := 0
	var n_skip := 0
	var grown := box.grow(0.5)
	for hit: Dictionary in hits:
		var body := hit.get("collider") as CollisionObject3D
		if body == null or seen.has(body.get_instance_id()):
			continue
		seen[body.get_instance_id()] = true
		if body is AnimatableBody3D and body.get_parent() is BuildDoor:
			n_obs += _open_leaf(body, out)   # a door's leaf: where it stands open (a walker opens it as it comes)
			continue
		if not _takes(body):
			n_skip += 1
			continue
		for owner_id in body.get_shape_owners():
			var cs := body.shape_owner_get_owner(owner_id) as CollisionShape3D
			if cs == null or cs.disabled or cs.shape == null:
				continue
			var xf := cs.global_transform
			if not _bounds(cs.shape, xf).intersects(grown):
				continue
			n_shapes += 1
			n_obs += _shape(cs.shape, xf, faces, out)
	if not faces.is_empty():
		out.add_faces(faces, Transform3D.IDENTITY)
	stats["faces"] = int(stats.get("faces", 0)) + faces.size() / 3
	stats["obstructions"] = n_obs
	stats["shapes"] = n_shapes
	stats["skipped"] = n_skip


## A shape's world bounds (rough: its local box through the transform).
static func _bounds(shape: Shape3D, xf: Transform3D) -> AABB:
	var local: AABB
	if shape is BoxShape3D:
		var e := (shape as BoxShape3D).size
		local = AABB(-e * 0.5, e)
	elif shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		local = AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius), Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	elif shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		local = AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius), Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	elif shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		local = AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	else:
		var id := shape.get_instance_id()
		if not _local_box.has(id):
			var pts := PackedVector3Array()
			if shape is ConvexPolygonShape3D:
				pts = (shape as ConvexPolygonShape3D).points
			elif shape is ConcavePolygonShape3D:
				pts = (shape as ConcavePolygonShape3D).get_faces()
			elif shape is HeightMapShape3D:
				var hm := shape as HeightMapShape3D
				pts = PackedVector3Array([Vector3(-(hm.map_width - 1) * 0.5, hm.get_min_height(), -(hm.map_depth - 1) * 0.5),
						Vector3((hm.map_width - 1) * 0.5, hm.get_max_height(), (hm.map_depth - 1) * 0.5)])
			var b := AABB(pts[0], Vector3.ZERO) if not pts.is_empty() else AABB(Vector3(-1e4, -1e4, -1e4), Vector3(2e4, 2e4, 2e4))
			for p in pts:
				b = b.expand(p)
			if _local_box.size() > 20000:
				_local_box.clear()
			_local_box[id] = b
		local = _local_box[id]
	return xf * local


## A door leaf (its hinge body under a BuildDoor) as an obstruction where it stands open, whatever it is now: the doorway
## itself stays open on the mesh and the path keeps off the open leaf (a walker going round it into the corner behind it
## was trapped there).
static func _open_leaf(body: CollisionObject3D, out: NavigationMeshSourceGeometryData3D) -> int:
	var door := body.get_parent() as BuildDoor
	var i := door._hinges.find(body)
	if i < 0:
		return 0
	var hinge := Transform3D(Basis(Vector3.UP, door._open_yaw[i]), (body as Node3D).position)
	var n := 0
	for owner_id in body.get_shape_owners():
		var cs := body.shape_owner_get_owner(owner_id) as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var xf := door.global_transform * hinge * cs.transform
		var e := (cs.shape as BoxShape3D).size * 0.5
		e.z = maxf(e.z, 0.1)   # (a 5 cm leaf marks no voxel of the bake: at least a cell each side of it)
		var ring := PackedVector3Array()
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			ring.append(xf * Vector3(c.x * e.x, 0.0, c.y * e.z))
		var lo := (xf * Vector3(0, -e.y, 0)).y
		out.add_projected_obstruction(ring, lo - 0.3, e.y * 2.0 + 0.3, false)
		n += 1
	return n


## Whether a body is baked: static things only, not the ground (made from the height field) and not a door's leaf.
static func _takes(body: CollisionObject3D) -> bool:
	if not (body is StaticBody3D) or body is AnimatableBody3D:
		return false
	if body.is_in_group(&"terrain") or body.is_in_group(NavWorld.NO_NAV_GROUP):
		return false
	return (body.collision_layer & 1) != 0


## One shape into faces (appended to `faces`) or an obstruction (added to `out`); returns the obstructions added.
static func _shape(shape: Shape3D, xf: Transform3D, faces: PackedVector3Array, out: NavigationMeshSourceGeometryData3D) -> int:
	if shape is BoxShape3D:
		_box(faces, xf, (shape as BoxShape3D).size * 0.5)
	elif shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		return _column(faces, out, xf, c.radius, c.height)
	elif shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		return _column(faces, out, xf, c.radius, c.height)
	elif shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		var s := xf.basis.get_scale()
		return _column(faces, out, Transform3D(Basis.from_scale(s), xf.origin), r, r * 2.0)
	elif shape is ConcavePolygonShape3D:
		var f := (shape as ConcavePolygonShape3D).get_faces()
		for i in f.size():
			faces.append(xf * f[i])
	elif shape is ConvexPolygonShape3D:
		var pts := (shape as ConvexPolygonShape3D).points
		if pts.size() <= HULL_FACES_MAX:
			_hull_faces(faces, xf, pts)
		else:
			return _footprint(out, xf, pts)
	elif shape is HeightMapShape3D:
		_heightmap(faces, xf, shape as HeightMapShape3D)
	return 0


## A triangle wound for Recast: its cross product against the outward normal `n`.
static func _tri(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		faces.append(a)
		faces.append(c)
		faces.append(b)
	else:
		faces.append(a)
		faces.append(b)
		faces.append(c)


static func _box(faces: PackedVector3Array, xf: Transform3D, e: Vector3) -> void:
	var c := [xf * Vector3(-e.x, -e.y, -e.z), xf * Vector3(e.x, -e.y, -e.z), xf * Vector3(e.x, -e.y, e.z), xf * Vector3(-e.x, -e.y, e.z),
			xf * Vector3(-e.x, e.y, -e.z), xf * Vector3(e.x, e.y, -e.z), xf * Vector3(e.x, e.y, e.z), xf * Vector3(-e.x, e.y, e.z)]
	var mid := xf.origin
	for q: Array in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]]:
		var a: Vector3 = c[q[0]]
		var b: Vector3 = c[q[1]]
		var cc: Vector3 = c[q[2]]
		var d: Vector3 = c[q[3]]
		var n := (a + b + cc + d) * 0.25 - mid
		_tri(faces, a, b, cc, n)
		_tri(faces, a, cc, d, n)


## A cylinder (or capsule) about the shape's local Y: upright, an obstruction of its ring (the ground under it is no floor);
## lying or leaning, a prism of faces.
static func _column(faces: PackedVector3Array, out: NavigationMeshSourceGeometryData3D, xf: Transform3D, r: float, h: float) -> int:
	var up := xf.basis.y.normalized()
	var sc := xf.basis.get_scale()
	var rr := r * maxf(sc.x, sc.z)
	var hh := h * sc.y
	if up.dot(Vector3.UP) >= UPRIGHT_COS:
		var ring := PackedVector3Array()
		for k in CYL_SIDES:
			var a := TAU * k / CYL_SIDES
			ring.append(xf.origin + Vector3(cos(a), 0.0, sin(a)) * rr)
		var lo := xf.origin.y - hh * 0.5
		out.add_projected_obstruction(ring, lo, hh, false)
		return 1
	var ax := xf.basis.y.normalized()
	var side := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var side2 := ax.cross(side).normalized()
	var top := xf.origin + ax * hh * 0.5
	var bot := xf.origin - ax * hh * 0.5
	for k in CYL_SIDES:
		var a0 := TAU * k / CYL_SIDES
		var a1 := TAU * (k + 1) / CYL_SIDES
		var d0 := (side * cos(a0) + side2 * sin(a0)) * rr
		var d1 := (side * cos(a1) + side2 * sin(a1)) * rr
		var n := (d0 + d1) * 0.5
		_tri(faces, bot + d0, bot + d1, top + d1, n)
		_tri(faces, bot + d0, top + d1, top + d0, n)
		_tri(faces, top, top + d0, top + d1, ax)
		_tri(faces, bot, bot + d1, bot + d0, -ax)
	return 0


## A small convex hull's faces: every triple of points with all the others on one side (brute force; few points).
static func _hull_faces(faces: PackedVector3Array, xf: Transform3D, pts: PackedVector3Array) -> void:
	var w := PackedVector3Array()
	var mid := Vector3.ZERO
	for p in pts:
		w.append(xf * p)
		mid += xf * p
	var n := w.size()
	if n < 4:
		return
	mid /= n
	for i in n:
		for j in range(i + 1, n):
			for k in range(j + 1, n):
				var nrm := (w[j] - w[i]).cross(w[k] - w[i])
				if nrm.length_squared() < 1e-8:
					continue
				var pos := false
				var neg := false
				for m in n:
					if m == i or m == j or m == k:
						continue
					var s := nrm.dot(w[m] - w[i])
					if s > 1e-4:
						pos = true
					elif s < -1e-4:
						neg = true
					if pos and neg:
						break
				if pos and neg:
					continue
				var out_n := nrm if nrm.dot(w[i] - mid) > 0.0 else -nrm
				_tri(faces, w[i], w[j], w[k], out_n)


## A big convex hull (a rock): its footprint on the ground as an obstruction, from its lowest point to its highest.
static func _footprint(out: NavigationMeshSourceGeometryData3D, xf: Transform3D, pts: PackedVector3Array) -> int:
	var flat := PackedVector2Array()
	var lo := INF
	var hi := -INF
	for p in pts:
		var w := xf * p
		flat.append(Vector2(w.x, w.z))
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
	var hull := Geometry2D.convex_hull(flat)
	if hull.size() < 4:
		return 0
	var ring := PackedVector3Array()
	for i in hull.size() - 1:   # the hull comes closed (its first point again at the end)
		ring.append(Vector3(hull[i].x, 0.0, hull[i].y))
	out.add_projected_obstruction(ring, lo, hi - lo, false)
	return 1


static func _heightmap(faces: PackedVector3Array, xf: Transform3D, hm: HeightMapShape3D) -> void:
	var w := hm.map_width
	var d := hm.map_depth
	var data := hm.map_data
	var ox := (w - 1) * 0.5
	var oz := (d - 1) * 0.5
	for j in d - 1:
		for i in w - 1:
			var a := xf * Vector3(i - ox, data[j * w + i], j - oz)
			var b := xf * Vector3(i + 1 - ox, data[j * w + i + 1], j - oz)
			var c := xf * Vector3(i + 1 - ox, data[(j + 1) * w + i + 1], j + 1 - oz)
			var e := xf * Vector3(i - ox, data[(j + 1) * w + i], j + 1 - oz)
			_tri(faces, a, b, c, Vector3.UP)
			_tri(faces, a, c, e, Vector3.UP)
