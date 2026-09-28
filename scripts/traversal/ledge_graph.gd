class_name TravLedgeGraph
extends RefCounted
## Traversal geometry of a level (design 9.1 / 14.4), SOURCE-CLIP moves only (user decision
## 2026-09-24): ledges (top edges baked from boxes, hulls and meshes, and authored narrow sidle
## ledges), ladder lanes, beams (logs, raised beams, thick branches) and marker volumes
## (crouch-under, squeeze), with a 2 m spatial hash for the ledges. The hang network (links,
## far jumps, perches, trunk lanes) was removed with the free climbing it served.
##
## Ledge  {id, points: PackedVector3Array (lip line), normal: Vector3 (outward, horizontal),
##         grip: braced | hang, lip_m, top_class: none | crouch | stand, surface, kind:
##         ledge | narrow | limb, two_sided, source, route, prefer_onto}
## Lane   {id, kind: ladder, bottom, top, normal (out of the surface), width, rung_pitch, rail, source}
## Beam   {id, a, b, width, walkable, radius (logs), shape (CollisionShape3D path), source}
## Volume {id, kind: crouch_under | squeeze, center, size, basis, axis, source}
## IDs are hashes of quantized geometry (endpoints at 5 cm, normal at 10 deg), so they are
## stable across builds and independent of node names (design 9.1).

const CELL := 2.0
const SAMPLE := 0.25

var ledges := {}          ## id -> ledge
var lanes := {}
var beams := {}
var volumes := {}
var _hash := {}           ## Vector3i cell -> [{ledge_id, s, point, normal, tangent}]
var report := {}


static func geo_id(kind: String, a: Vector3, b: Vector3, n: Vector3) -> int:
	var qa := Vector3i((a / 0.05).round())
	var qb := Vector3i((b / 0.05).round())
	if qb < qa:
		var t := qa
		qa = qb
		qb = t
	var ang := int(round(rad_to_deg(atan2(n.x, n.z)) / 10.0)) if Vector2(n.x, n.z).length() > 1e-3 else 99
	return absi(hash("%s|%s|%s|%d" % [kind, qa, qb, ang]))


func add_ledge(points: PackedVector3Array, normal: Vector3, props := {}) -> int:
	if points.size() < 2:
		return -1
	var n := Vector3(normal.x, 0, normal.z)
	n = n.normalized() if n.length() > 1e-4 else Vector3.FORWARD
	var id := geo_id(str(props.get("kind", "ledge")), points[0], points[points.size() - 1], n)
	while ledges.has(id):
		id += 1
	var d := {"id": id, "points": points, "normal": n, "grip": "braced", "lip_m": 0.3, "top_class": "none",
			"surface": "", "kind": "ledge", "two_sided": false, "source": "", "length": _poly_len(points)}
	d.merge(props, true)
	d["id"] = id
	d["points"] = points
	d["normal"] = n
	ledges[id] = d
	_index_ledge(d)
	return id


func add_lane(props: Dictionary) -> int:
	var b: Vector3 = props.get("bottom", Vector3.ZERO)
	var t: Vector3 = props.get("top", Vector3.UP)
	var id := geo_id("lane_" + str(props.get("kind", "climb")), b, t, props.get("normal", Vector3.FORWARD))
	while lanes.has(id):
		id += 1
	var d := {"id": id, "kind": "climb", "width": 0.6, "radius": 0.0, "rung_pitch": 0.24, "rail": false, "source": ""}
	d.merge(props, true)
	d["id"] = id
	lanes[id] = d
	return id


func add_beam(a: Vector3, b: Vector3, width: float, props := {}) -> int:
	var id := geo_id("beam", a, b, Vector3.UP)
	while beams.has(id):
		id += 1
	var d := {"id": id, "a": a, "b": b, "width": width, "walkable": width >= 0.2, "source": ""}
	d.merge(props, true)
	d["id"] = id
	beams[id] = d
	return id


func add_volume(props: Dictionary) -> int:
	var c: Vector3 = props.get("center", Vector3.ZERO)
	var id := geo_id("volume_" + str(props.get("kind", "")), c, c, props.get("axis", Vector3.FORWARD))
	while volumes.has(id):
		id += 1
	var d := props.duplicate()
	d["id"] = id
	volumes[id] = d
	return id


func ledge(id: int) -> Dictionary:
	return ledges.get(id, {})


## Drops every ledge and beam baked from the collision shape at node path `src` (their `source`): a shape
## changed or removed at run time (a rock quarried away, VegHarvest). Returns how many were dropped.
func remove_source(src: String) -> int:
	var gone := {}
	for id: int in ledges.keys():
		if str((ledges[id] as Dictionary).get("source", "")) == src:
			gone[id] = true
			ledges.erase(id)
	var n := gone.size()
	for id: int in beams.keys():
		if str((beams[id] as Dictionary).get("source", "")) == src:
			beams.erase(id)
			n += 1
	if not gone.is_empty():
		for c: Vector3i in _hash.keys():
			var kept: Array = (_hash[c] as Array).filter(func(e: Dictionary) -> bool: return not gone.has(int(e.ledge_id)))
			if kept.is_empty():
				_hash.erase(c)
			else:
				_hash[c] = kept
	return n


static func _poly_len(pts: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	return l


func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))


func _index_ledge(d: Dictionary) -> void:
	var L := float(d.length)
	var k := maxi(1, int(ceil(L / SAMPLE)))
	for i in k + 1:
		var s := L * i / float(k)
		var e := sample(int(d.id), s)
		var c := _cell(e.point)
		if not _hash.has(c):
			_hash[c] = []
		(_hash[c] as Array).append(e)


## Point, tangent and normal at arc length s along a ledge.
func sample(id: int, s: float) -> Dictionary:
	var d: Dictionary = ledges[id]
	var pts: PackedVector3Array = d.points
	var rem := clampf(s, 0.0, float(d.length))
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if rem <= seg or i == pts.size() - 1:
			var u := clampf(rem / maxf(seg, 1e-6), 0.0, 1.0)
			var tg := (pts[i] - pts[i - 1]).normalized()
			var n := Vector3.UP.cross(tg).normalized()
			var dn: Vector3 = d.normal
			if n.dot(dn) < 0.0:
				n = -n
			return {"ledge_id": id, "s": clampf(s, 0.0, float(d.length)), "point": pts[i - 1].lerp(pts[i], u),
					"tangent": tg, "normal": n}
		rem -= seg
	return {"ledge_id": id, "s": 0.0, "point": pts[0], "tangent": Vector3.RIGHT, "normal": d.normal}


## Closest point on a ledge to p: {s, point, tangent, normal, dist}.
func closest(id: int, p: Vector3) -> Dictionary:
	var d: Dictionary = ledges[id]
	var pts: PackedVector3Array = d.points
	var best := {}
	var acc := 0.0
	var bd := INF
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var ab := b - a
		var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var q := a + ab * u
		var dd := q.distance_to(p)
		if dd < bd:
			bd = dd
			best = sample(id, acc + ab.length() * u)
			best["dist"] = dd
		acc += ab.length()
	return best


## Ledge samples within radius r of p (spatial hash; one entry per ledge, the closest).
func query_near(p: Vector3, r: float) -> Array:
	var c0 := _cell(p - Vector3.ONE * r)
	var c1 := _cell(p + Vector3.ONE * r)
	var seen := {}
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			for z in range(c0.z, c1.z + 1):
				for e: Dictionary in _hash.get(Vector3i(x, y, z), []):
					var id := int(e.ledge_id)
					if seen.has(id):
						continue
					seen[id] = true
	var out := []
	for id: int in seen:
		var c := closest(id, p)
		if not c.is_empty() and float(c.dist) <= r:
			out.append(c)
	out.sort_custom(func(a, b): return float(a.dist) < float(b.dist))
	return out


# --------------------------------------------------------------------------------------------------
# Serialization (data/traversal/levels/<level>.ledges.json)
# --------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var out := {"ledges": [], "lanes": [], "beams": [], "volumes": [], "report": report}
	var ids := ledges.keys()
	ids.sort()
	for id: int in ids:
		var d: Dictionary = (ledges[id] as Dictionary).duplicate()
		var pts := []
		for p: Vector3 in d.points:
			pts.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
		d["points"] = pts
		var n: Vector3 = d.normal
		d["normal"] = [snappedf(n.x, 0.001), snappedf(n.y, 0.001), snappedf(n.z, 0.001)]
		(out.ledges as Array).append(d)
	for coll in [["lanes", lanes], ["beams", beams], ["volumes", volumes]]:
		var ks: Array = (coll[1] as Dictionary).keys()
		ks.sort()
		for id: int in ks:
			var d: Dictionary = (coll[1][id] as Dictionary).duplicate()
			for k: String in d:
				if d[k] is Basis:
					d[k] = str(d[k])
				elif d[k] is Vector3:
					var v: Vector3 = d[k]
					d[k] = [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
			(out[coll[0]] as Array).append(d)
	return out
