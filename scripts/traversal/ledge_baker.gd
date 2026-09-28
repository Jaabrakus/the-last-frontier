class_name TravLedgeBaker
extends RefCounted
## Builds a TravLedgeGraph from level geometry, shape metadata and marker nodes (design 14.4).
##
##   var baker := TravLedgeBaker.new(registry, settings)
##   var graph := baker.bake(level_root, space, [player_rid])     # after one physics frame
##   print(baker.report)
##
## Sources:
##   BoxShape3D          the 4 top edges of an upright box become ledges when the drop on that
##                       side is >= MIN_DROP (lower edges are vaults, not ledges) or the shape is
##                       tagged trav_hang / trav_climb; seams (a probe 5 cm outside the side face
##                       and 10 cm below the edge lies inside another shape) are rejected; grip =
##                       braced when a face >= 1 m tall lies within 0.5 m below the lip, else hang;
##                       lip_m = the top's depth; top_class from a clearance ray. Narrow raised
##                       tops (0.20-0.50 m) are beams.
##   Cylinder / Capsule  horizontal: a beam (width 0.20-0.50, or tagged trav_beam / kind log /
##                       branch) for the balance clips; vertical ones are not traversal geometry.
##   ConvexPolygon       hull edges between a top face (n.y >= 0.8) and a side face (|n.y| <=
##                       0.35) with a convex dihedral; collinear edges merged (10 deg), < 0.4 m
##                       dropped. Kept when tagged (rocks need a visual proxy, design 8.4).
##   ConcavePolygon      the same edge rule on the triangle mesh (adjacent triangles).
##   Markers             TravLedge (narrow sidle ledges), TravLadder, TravBeam, TravVolume
##                       (crouch_under, squeeze) (marker_info()).
## Ledges are the level's climbable top edges (the jump-up / vault targets, debug view); no hang
## network is built from them (source-clip moves only).
## IDs come from quantized geometry (TravLedgeGraph.geo_id), so two bakes give the same IDs.

const MIN_DROP := 1.0
const MIN_EDGE := 0.4

var registry: TravShapeRegistry
var settings := {}
var report := {}
var _space: PhysicsDirectSpaceState3D
var _exclude: Array[RID] = []
var _rej := {}


func _init(p_registry: TravShapeRegistry = null, p_settings := {}) -> void:
	registry = p_registry if p_registry else TravShapeRegistry.new()
	settings = p_settings


func bake(root: Node, space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []) -> TravLedgeGraph:
	var t0 := Time.get_ticks_usec()
	_space = space
	_exclude = exclude
	_rej = {}
	var g := TravLedgeGraph.new()
	var shapes := 0
	for node in root.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		if cs.disabled or cs.shape == null:
			continue
		var body := cs.get_parent() as CollisionObject3D
		if body == null or body is CharacterBody3D or body is RigidBody3D or body is Area3D:
			continue
		shapes += 1
		var d := registry.describe_node(cs, body)
		var gate := TravShapeRegistry.gate(d)
		if gate == "excluded" or gate == "truncated":
			_reject("gate_" + gate)
			continue
		if gate == "tree":
			_reject("gate_tree")
			continue
		if TravShapeRegistry.is_terrain(d):
			continue
		var sh := cs.shape
		if sh is BoxShape3D:
			_box(g, cs, body, sh as BoxShape3D, d)
		elif sh is CylinderShape3D or sh is CapsuleShape3D:
			_round(g, cs, body, sh, d)
		elif sh is ConvexPolygonShape3D:
			_convex(g, cs, body, sh as ConvexPolygonShape3D, d)
		elif sh is ConcavePolygonShape3D:
			_concave(g, cs, body, sh as ConcavePolygonShape3D, d)
	var markers := 0
	for m in root.find_children("*", "", true, false):
		if m is TravMarker:
			markers += 1
			_marker(g, m as TravMarker)
	report = g.report.duplicate()
	report["shapes"] = shapes
	report["markers"] = markers
	report["rejected"] = _rej
	report["ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	return g


func _reject(why: String) -> void:
	_rej[why] = int(_rej.get(why, 0)) + 1


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 4, _exclude)
	return _space.intersect_ray(q)


func _inside_other(p: Vector3, body: CollisionObject3D, cs: CollisionShape3D) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = 1 | 4
	q.exclude = _exclude
	for r in _space.intersect_point(q, 8):
		var other := TravShapeRegistry.resolve(r.collider, int(r.shape))
		if other != cs:
			return true
	return false


func _ground_below(p: Vector3, depth := 12.0) -> float:
	var h := _ray(p, p - Vector3.UP * depth)
	return (h.position as Vector3).y if not h.is_empty() else p.y - depth


func _clearance_above(p: Vector3) -> float:
	var h := _ray(p + Vector3.UP * 0.05, p + Vector3.UP * 2.0)
	return ((h.position as Vector3).y - p.y) if not h.is_empty() else 2.0


func _braced(mid: Vector3, n: Vector3) -> bool:
	var hits := 0
	for dy: float in [0.4, 0.8, 1.2]:
		var a := mid + n * 0.6 - Vector3.UP * dy
		var h := _ray(a, a - n * 1.1)
		if not h.is_empty() and ((h.position as Vector3) - (mid - Vector3.UP * dy)).dot(n) > -0.5:
			hits += 1
	return hits >= 2


func _top_class(p: Vector3, depth: float, d: Dictionary) -> String:
	if bool(d.get("no_stand", false)):
		return "none"
	if depth < 0.3:
		return "none"
	var c := _clearance_above(p)
	var st: Dictionary = settings.get("clearance", {})
	return "stand" if c >= float(st.get("stand", 1.6)) else ("crouch" if c >= float(st.get("crouch", 1.1)) else "none")


func _src(cs: Node) -> String:
	return str(cs.get_path()) if cs.is_inside_tree() else cs.name


# --------------------------------------------------------------------------------------------------

func _box(g: TravLedgeGraph, cs: CollisionShape3D, body: CollisionObject3D, box: BoxShape3D, d: Dictionary) -> void:
	var xf := cs.global_transform
	var up := xf.basis.y.normalized()
	if up.dot(Vector3.UP) < 0.95:
		_reject("box_not_upright")
		return
	var hs := box.size * 0.5
	var sx := xf.basis.x.length()
	var sz := xf.basis.z.length()
	var tags: Array = d.get("tags", [])
	var tagged_hang := tags.has("trav_hang") or str(d.get("grip", "")) == "hang"
	var tagged_climb := tags.has("trav_climb")
	var top_y := (xf * Vector3(0, hs.y, 0)).y
	var bottom_y := (xf * Vector3(0, -hs.y, 0)).y
	var dims := [box.size.x * sx, box.size.z * sz]
	var edges := [
		[Vector3(-hs.x, hs.y, -hs.z), Vector3(-hs.x, hs.y, hs.z), Vector3(-1, 0, 0), dims[0]],
		[Vector3(hs.x, hs.y, hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(1, 0, 0), dims[0]],
		[Vector3(hs.x, hs.y, -hs.z), Vector3(-hs.x, hs.y, -hs.z), Vector3(0, 0, -1), dims[1]],
		[Vector3(-hs.x, hs.y, hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(0, 0, 1), dims[1]],
	]
	var made := 0
	for e: Array in edges:
		var a: Vector3 = xf * (e[0] as Vector3)
		var b: Vector3 = xf * (e[1] as Vector3)
		var n: Vector3 = (xf.basis * (e[2] as Vector3))
		n.y = 0.0
		n = n.normalized()
		var depth: float = e[3]
		if a.distance_to(b) < MIN_EDGE:
			_reject("short")
			continue
		var mid := (a + b) * 0.5
		if _inside_other(mid + n * 0.05 - Vector3.UP * 0.1, body, cs):
			_reject("seam")
			continue
		var ground := _ground_below(mid + n * 0.2 - Vector3.UP * 0.02)
		var drop := top_y - ground
		if drop < MIN_DROP and not (tagged_hang or tagged_climb or bool(d.get("ledges", false))):
			_reject("low")
			continue
		var braced := _braced(mid, n)
		var grip := str(d.get("grip", "braced" if braced else "hang"))
		var props := {"grip": grip, "lip_m": depth, "top_class": _top_class(mid - n * minf(0.3, depth * 0.5), depth, d),
				"surface": str(d.get("surface", cs.get_meta("surface", body.get_meta("surface", "")))),
				"kind": str(d.get("ledge_kind", "narrow" if depth < 0.3 and braced and not tagged_hang else "ledge")),
				"source": _src(cs), "drop": drop, "route": d.get("route", ""), "prefer_onto": bool(d.get("prefer_onto", false))}
		g.add_ledge(PackedVector3Array([a, b]), n, props)
		made += 1
	# Beams: raised narrow tops, walked along the long axis.
	var narrow := minf(dims[0], dims[1])
	var longd := maxf(dims[0], dims[1])
	var width_rng: Dictionary = settings.get("beam_width", {"min": 0.2, "max": 0.5})
	if (tags.has("trav_beam") or (narrow >= float(width_rng.min) and narrow < float(width_rng.max) and longd >= 1.5)) \
			and top_y - _ground_below(xf.origin + Vector3.UP * (hs.y + 0.05) + xf.basis.x.normalized() * (hs.x * sx + 0.3)) > 0.3:
		var along := xf.basis.x.normalized() if dims[0] >= dims[1] else xf.basis.z.normalized()
		var half := longd * 0.5
		var c := xf * Vector3(0, hs.y, 0)
		g.add_beam(c - along * half, c + along * half, narrow, {"source": _src(cs)})



func _round(g: TravLedgeGraph, cs: CollisionShape3D, body: CollisionObject3D, sh: Shape3D, d: Dictionary) -> void:
	var xf := cs.global_transform
	var axis := xf.basis.y.normalized()
	var scale_r := maxf(xf.basis.x.length(), xf.basis.z.length())
	var r := float(sh.get("radius")) * scale_r
	var h := float(sh.get("height")) * xf.basis.y.length()
	var tags: Array = d.get("tags", [])
	# Horizontal cylinders and capsules (fallen logs, thick branches, round rails): beams to walk
	# along with the balance clips when their width is in the beam range.
	if absf(axis.dot(Vector3.UP)) >= 0.35:
		_reject("round_not_horizontal")
		return
	var half := h * 0.5 - (r if sh is CapsuleShape3D else 0.0)
	var top_c := xf.origin + Vector3.UP * r
	var a := top_c - axis * half
	var b := top_c + axis * half
	var width := 2.0 * r
	var wr: Dictionary = settings.get("beam_width", {"min": 0.2, "max": 0.5})
	if tags.has("trav_beam") or str(d.get("kind", "")) in ["log", "branch"] or (width >= float(wr.min) and width < float(wr.max)):
		g.add_beam(a, b, width, {"source": _src(cs), "radius": r, "shape": str(cs.get_path())})
	else:
		_reject("round_width")


## Hull faces of a small convex point set (brute force; rocks have 24-48 points).
static func hull_faces(pts: PackedVector3Array) -> Array:
	var faces := []
	var n := pts.size()
	var seen := {}
	for i in n:
		for j in range(i + 1, n):
			for k in range(j + 1, n):
				var nrm := (pts[j] - pts[i]).cross(pts[k] - pts[i])
				if nrm.length() < 1e-6:
					continue
				nrm = nrm.normalized()
				var dd := nrm.dot(pts[i])
				var pos := 0
				var neg := 0
				for m in n:
					var s := nrm.dot(pts[m]) - dd
					if s > 1e-4:
						pos += 1
					elif s < -1e-4:
						neg += 1
					if pos > 0 and neg > 0:
						break
				if pos > 0 and neg > 0:
					continue
				if pos > 0:
					nrm = -nrm
				var key := Vector3i((nrm * 100.0).round())
				faces.append({"i": [i, j, k], "n": nrm})
	return faces


func _edge_candidates(tris: Array, xf: Transform3D) -> Array:
	# tris: [{"v": [a, b, c] (local), "n": normal (local)}]. Returns merged world segments with normals.
	var edge_map := {}
	var q := func(v: Vector3) -> Vector3i:
		return Vector3i((v / 0.01).round())
	for ti in tris.size():
		var t: Dictionary = tris[ti]
		var v: Array = t.v
		for e in [[0, 1], [1, 2], [2, 0]]:
			var ka: Vector3i = q.call(v[e[0]])
			var kb: Vector3i = q.call(v[e[1]])
			var key := [ka, kb] if ka < kb else [kb, ka]
			var ks := str(key)
			if not edge_map.has(ks):
				edge_map[ks] = {"a": v[e[0]], "b": v[e[1]], "tris": []}
			(edge_map[ks].tris as Array).append(ti)
	var segs := []
	for ks: String in edge_map:
		var em: Dictionary = edge_map[ks]
		var ts: Array = em.tris
		if ts.size() < 2:
			continue
		for x in ts.size():
			for y in ts.size():
				if x == y:
					continue
				var nt: Vector3 = (xf.basis * (tris[ts[x]].n as Vector3)).normalized()
				var ns: Vector3 = (xf.basis * (tris[ts[y]].n as Vector3)).normalized()
				if nt.y >= 0.8 and absf(ns.y) <= 0.35:
					var a: Vector3 = xf * (em.a as Vector3)
					var b: Vector3 = xf * (em.b as Vector3)
					# Convex dihedral: the side face's centroid lies below the top plane.
					var tri_s: Array = tris[ts[y]].v
					var cs_w: Vector3 = xf * ((tri_s[0] + tri_s[1] + tri_s[2]) / 3.0)
					if nt.dot(cs_w - a) < -1e-3:
						segs.append({"a": a, "b": b, "n": Vector3(ns.x, 0, ns.z).normalized()})
	# Merge collinear segments with matching normals (10 deg).
	var merged := []
	var used := {}
	for i in segs.size():
		if used.has(i):
			continue
		var s: Dictionary = segs[i]
		var a: Vector3 = s.a
		var b: Vector3 = s.b
		var n: Vector3 = s.n
		var changed := true
		while changed:
			changed = false
			for j in segs.size():
				if used.has(j) or j == i:
					continue
				var t: Dictionary = segs[j]
				if (t.n as Vector3).angle_to(n) > deg_to_rad(10.0):
					continue
				var dirv := (b - a).normalized()
				var tdir := ((t.b as Vector3) - (t.a as Vector3)).normalized()
				if absf(dirv.dot(tdir)) < cos(deg_to_rad(10.0)):
					continue
				for pair in [[t.a, t.b], [t.b, t.a]]:
					if (pair[0] as Vector3).distance_to(b) < 0.02:
						b = pair[1]
						used[j] = true
						changed = true
						break
					elif (pair[1] as Vector3).distance_to(a) < 0.02:
						a = pair[0]
						used[j] = true
						changed = true
						break
		used[i] = true
		if a.distance_to(b) >= MIN_EDGE:
			merged.append({"a": a, "b": b, "n": n})
		else:
			_reject("short")
	return merged


func _add_mesh_edges(g: TravLedgeGraph, cs: CollisionShape3D, body: CollisionObject3D, segs: Array, d: Dictionary) -> void:
	for s: Dictionary in segs:
		var a: Vector3 = s.a
		var b: Vector3 = s.b
		var n: Vector3 = s.n
		var mid := (a + b) * 0.5
		if _inside_other(mid + n * 0.05 - Vector3.UP * 0.1, body, cs):
			_reject("seam")
			continue
		var top_y := maxf(a.y, b.y)
		var drop := top_y - _ground_below(mid + n * 0.2 - Vector3.UP * 0.02)
		var tags: Array = d.get("tags", [])
		if drop < MIN_DROP and not (tags.has("trav_hang") or tags.has("trav_climb") or bool(d.get("ledges", false))):
			_reject("low")
			continue
		var braced := _braced(mid, n)
		g.add_ledge(PackedVector3Array([a, b]), n, {"grip": "braced" if braced else "hang", "lip_m": 0.3,
				"top_class": _top_class(mid - n * 0.3, 0.6, d), "surface": str(d.get("surface", "stone")),
				"kind": "ledge", "source": _src(cs), "drop": drop})


func _convex(g: TravLedgeGraph, cs: CollisionShape3D, body: CollisionObject3D, sh: ConvexPolygonShape3D, d: Dictionary) -> void:
	var tags: Array = d.get("tags", [])
	if not (tags.has("trav_climb") or tags.has("trav_hang") or bool(d.get("ledges", false))):
		_reject("convex_untagged")
		return
	var pts := sh.points
	if pts.size() > 64:
		_reject("convex_too_many_points")
		return
	var faces := hull_faces(pts)
	var tris := []
	for f: Dictionary in faces:
		tris.append({"v": [pts[f.i[0]], pts[f.i[1]], pts[f.i[2]]], "n": f.n})
	_add_mesh_edges(g, cs, body, _edge_candidates(tris, cs.global_transform), d)


func _concave(g: TravLedgeGraph, cs: CollisionShape3D, body: CollisionObject3D, sh: ConcavePolygonShape3D, d: Dictionary) -> void:
	var f := sh.get_faces()
	var tris := []
	for i in range(0, f.size() - 2, 3):
		var nrm := (f[i + 1] - f[i]).cross(f[i + 2] - f[i])
		if nrm.length() < 1e-8:
			continue
		# Godot's triangle winding is clockwise for front faces: flip to get the outward normal.
		tris.append({"v": [f[i], f[i + 1], f[i + 2]], "n": -nrm.normalized()})
	_add_mesh_edges(g, cs, body, _edge_candidates(tris, cs.global_transform), d)


func _marker(g: TravLedgeGraph, m: TravMarker) -> void:
	var info := m.marker_info()
	match str(info.get("type", "")):
		"ledge":
			g.add_ledge(info.points, info.normal, {"grip": info.grip, "kind": info.kind, "top_class": info.top_class,
					"lip_m": info.lip_m, "two_sided": info.two_sided, "surface": info.surface, "source": info.source,
					"wall": info.get("wall", true)})
		"ladder":
			g.add_lane({"kind": "ladder", "bottom": info.bottom, "top": info.top, "normal": info.normal,
					"width": info.width, "rung_pitch": info.rung_pitch, "rung_offset": info.get("rung_offset", 0.0),
					"rung_radius": info.get("rung_radius", 0.02), "rail": info.rail, "entry_exit": info.entry_exit,
					"source": info.source, "surface": "wood"})
		"beam":
			g.add_beam(info.a, info.b, info.width, {"source": info.source})
		"volume":
			if str(info.kind) in ["crouch_under", "squeeze"]:
				g.add_volume(info)
