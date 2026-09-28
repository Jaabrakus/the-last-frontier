extends RefCounted
## Footprint geometry shared by the vegetation layout (veg_layout.gd: spacing, grounding) and the
## clipping check (tools/environment/check_clipping.gd), so both use exactly the same shapes.
## No class_name (preloaded), like veg_assets.gd.
##
## A footprint is a PackedFloat32Array [type, cx, cz, a, b, ux, uz, y0, y1]:
##   type 0 = circle of radius a;  type 1 = oriented box, half extents a along (ux, uz) and b across;
##   y0 / y1 = the vertical extent (world y) of the object.
## Overlap tests are 2D (XZ) with a margin, plus a vertical-range test.

const CIRCLE := 0.0
const BOX := 1.0


static func circle(c: Vector2, r: float, y0: float, y1: float) -> PackedFloat32Array:
	return PackedFloat32Array([CIRCLE, c.x, c.y, r, r, 1.0, 0.0, y0, y1])


## Oriented box: half extents ha along u (unit XZ direction), hb across.
static func box(c: Vector2, u: Vector2, ha: float, hb: float, y0: float, y1: float) -> PackedFloat32Array:
	var n := u.normalized() if u.length() > 1e-6 else Vector2(1, 0)
	return PackedFloat32Array([BOX, c.x, c.y, ha, hb, n.x, n.y, y0, y1])


## Footprint of a set of world points (convex hull approximated by an oriented box along `u`).
static func from_points(pts: PackedVector3Array, u: Vector2) -> PackedFloat32Array:
	var n := u.normalized() if u.length() > 1e-6 else Vector2(1, 0)
	var v := Vector2(-n.y, n.x)
	var amin := INF
	var amax := -INF
	var bmin := INF
	var bmax := -INF
	var y0 := INF
	var y1 := -INF
	for p in pts:
		var q := Vector2(p.x, p.z)
		var a := q.dot(n)
		var b := q.dot(v)
		amin = minf(amin, a)
		amax = maxf(amax, a)
		bmin = minf(bmin, b)
		bmax = maxf(bmax, b)
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var c := n * (amin + amax) * 0.5 + v * (bmin + bmax) * 0.5
	return box(c, n, (amax - amin) * 0.5, (bmax - bmin) * 0.5, y0, y1)


## Bounding radius of a footprint about its centre.
static func radius(f: PackedFloat32Array) -> float:
	return f[3] if f[0] == CIRCLE else sqrt(f[3] * f[3] + f[4] * f[4])


static func centre(f: PackedFloat32Array) -> Vector2:
	return Vector2(f[1], f[2])


## Signed-ish 2D separation test: true when f and g overlap (grown by margin) in XZ and their
## vertical ranges overlap.
static func overlaps(f: PackedFloat32Array, g: PackedFloat32Array, margin := 0.0) -> bool:
	if f[8] < g[7] or g[8] < f[7]:
		return false
	var d := Vector2(g[1] - f[1], g[2] - f[2])
	var rr := radius(f) + radius(g) + margin
	if d.length_squared() > rr * rr:
		return false
	if f[0] == CIRCLE and g[0] == CIRCLE:
		return true
	if f[0] == CIRCLE:
		return _circle_box(f, g, margin)
	if g[0] == CIRCLE:
		return _circle_box(g, f, margin)
	return _box_box(f, g, margin)


static func _circle_box(c: PackedFloat32Array, b: PackedFloat32Array, margin: float) -> bool:
	var u := Vector2(b[5], b[6])
	var v := Vector2(-u.y, u.x)
	var d := Vector2(c[1] - b[1], c[2] - b[2])
	var la := clampf(d.dot(u), -b[3], b[3])
	var lb := clampf(d.dot(v), -b[4], b[4])
	var near := u * la + v * lb
	return d.distance_to(near) < c[3] + margin


static func _box_box(f: PackedFloat32Array, g: PackedFloat32Array, margin: float) -> bool:
	var fu := Vector2(f[5], f[6])
	var fv := Vector2(-fu.y, fu.x)
	var gu := Vector2(g[5], g[6])
	var gv := Vector2(-gu.y, gu.x)
	var d := Vector2(g[1] - f[1], g[2] - f[2])
	for axis: Vector2 in [fu, fv, gu, gv]:
		var rf := f[3] * absf(fu.dot(axis)) + f[4] * absf(fv.dot(axis))
		var rg := g[3] * absf(gu.dot(axis)) + g[4] * absf(gv.dot(axis))
		if absf(d.dot(axis)) > rf + rg + margin:
			return false
	return true


## True when the XZ point lies inside the footprint (grown by margin).
static func contains(f: PackedFloat32Array, p: Vector2, margin := 0.0) -> bool:
	var d := Vector2(p.x - f[1], p.y - f[2])
	if f[0] == CIRCLE:
		return d.length() < f[3] + margin
	var u := Vector2(f[5], f[6])
	var v := Vector2(-u.y, u.x)
	return absf(d.dot(u)) < f[3] + margin and absf(d.dot(v)) < f[4] + margin


## Sample points (XZ) covering a footprint: centre, perimeter and a coarse interior grid.
static func samples(f: PackedFloat32Array, step := 0.5) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := Vector2(f[1], f[2])
	out.append(c)
	if f[0] == CIRCLE:
		var n := maxi(8, int(TAU * f[3] / step))
		for i in n:
			var a := TAU * i / n
			out.append(c + Vector2(cos(a), sin(a)) * f[3])
			out.append(c + Vector2(cos(a), sin(a)) * f[3] * 0.5)
		return out
	var u := Vector2(f[5], f[6])
	var v := Vector2(-u.y, u.x)
	var na := maxi(1, int(ceil(2.0 * f[3] / step)))
	var nb := maxi(1, int(ceil(2.0 * f[4] / step)))
	for i in na + 1:
		for j in nb + 1:
			out.append(c + u * lerpf(-f[3], f[3], float(i) / na) + v * lerpf(-f[4], f[4], float(j) / nb))
	return out


## Euler tilt (x, z) that turns the object's up axis onto world normal n for a given yaw, in
## the Basis.from_euler(Vector3(tx, yaw, tz)) convention (YXZ) used by vegetation.gd.
static func tilt_for_normal(n: Vector3, yaw: float) -> Vector2:
	var nl := Basis(Vector3.UP, -yaw) * n.normalized()
	var tz := -asin(clampf(nl.x, -1.0, 1.0))
	var tx := atan2(nl.z, nl.y)
	return Vector2(tx, tz)


## Grounding of a hull-shaped prop: given its basis (rotation * scale applied to hull points)
## and XZ position, returns [y, float_gap, buried] where y places the object so that none of its
## bottom points (the lowest `bottom_frac` of the hull height) is above the terrain, float_gap is
## then 0, and buried is the deepest bottom point below the terrain (m).
static func ground_hull(hull: PackedVector3Array, b: Basis, xz: Vector2, bottom_frac := 0.2) -> PackedFloat32Array:
	var ymin := INF
	var ymax := -INF
	for p in hull:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var cut := ymin + (ymax - ymin) * bottom_frac
	var y := INF
	var rel := PackedVector3Array()
	var ground := PackedFloat32Array()
	for p in hull:
		if p.y > cut:
			continue
		var q := b * p
		var g := FrontierTerrain.height_at(xz.x + q.x, xz.y + q.z)
		rel.append(q)
		ground.append(g)
		y = minf(y, g - q.y)
	if y == INF:
		y = FrontierTerrain.height_at(xz.x, xz.y)
	var buried := 0.0
	for i in rel.size():
		buried = maxf(buried, ground[i] - (y + rel[i].y))
	return PackedFloat32Array([y, 0.0, buried])


## Largest gap (m) between the bottom points of a placed hull and the terrain below them
## (positive = floating), and the deepest bottom point below the terrain.
static func hull_gaps(hull: PackedVector3Array, xf: Transform3D, bottom_frac := 0.2) -> Vector2:
	var ymin := INF
	var ymax := -INF
	for p in hull:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var cut := ymin + (ymax - ymin) * bottom_frac
	var gap := -INF
	var buried := 0.0
	for p in hull:
		if p.y > cut:
			continue
		var q := xf * p
		var g := FrontierTerrain.height_at(q.x, q.z)
		gap = maxf(gap, q.y - g)
		buried = maxf(buried, g - q.y)
	return Vector2(gap, buried)


## Uniform-grid spatial hash of footprints (XZ), for fast overlap queries while placing.
class Grid:
	var cell := 4.0
	var items: Array[PackedFloat32Array] = []
	var tags := PackedInt32Array()
	var cells := {}

	func _init(cell_size := 4.0) -> void:
		cell = cell_size

	func add(f: PackedFloat32Array, tag: int) -> int:
		var id := items.size()
		items.append(f)
		tags.append(tag)
		var r := radius_of(f)
		var c0 := Vector2i(floori((f[1] - r) / cell), floori((f[2] - r) / cell))
		var c1 := Vector2i(floori((f[1] + r) / cell), floori((f[2] + r) / cell))
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var k := Vector2i(i, j)
				if not cells.has(k):
					cells[k] = PackedInt32Array()
				cells[k].append(id)
		return id

	func radius_of(f: PackedFloat32Array) -> float:
		return f[3] if f[0] == 0.0 else sqrt(f[3] * f[3] + f[4] * f[4])

	## Ids of the stored footprints whose cells touch f's bounding circle (grown by margin).
	func candidates(f: PackedFloat32Array, margin := 0.0) -> PackedInt32Array:
		var out := PackedInt32Array()
		var r := radius_of(f) + margin
		var c0 := Vector2i(floori((f[1] - r) / cell), floori((f[2] - r) / cell))
		var c1 := Vector2i(floori((f[1] + r) / cell), floori((f[2] + r) / cell))
		var seen := {}
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var ids: Variant = cells.get(Vector2i(i, j))
				if ids == null:
					continue
				for id: int in ids:
					if not seen.has(id):
						seen[id] = true
						out.append(id)
		return out


## Ids of the footprints in `grid` overlapping f (grown by margin); tag_mask filters by tag (bit
## per tag, 0 = all).
static func query(grid: Grid, f: PackedFloat32Array, margin := 0.0, tag_mask := 0) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in grid.candidates(f, margin):
		if tag_mask != 0 and (tag_mask & (1 << grid.tags[id])) == 0:
			continue
		if overlaps(grid.items[id], f, margin):
			out.append(id)
	return out
