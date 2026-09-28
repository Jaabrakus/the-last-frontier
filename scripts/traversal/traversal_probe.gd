class_name TraversalProbe
extends RefCounted
## Obstacle detection for traversal (design 6.2 A-K). Stateless between calls apart from the
## query counter; every result is a TravObstacleInfo.
##
##   var probe := TraversalProbe.new(space, registry, ledges, settings, [player_rid])
##   var info := probe.probe_ahead(feet, heading, speed)        # B-F: walls, tops, depth, landing
##   var over := probe.probe_overhead(feet, heading, speed)     # A: LedgeGraph lips overhead
##   var edge := probe.probe_edge(feet, heading, speed)         # G: edges and gaps
##   var low  := probe.probe_ceiling(feet, heading)             # H: crouch-under
##   var why  := probe.validate_path(path, info)                # J: capsule samples of a warp
##
## Units: heights are above the SUPPORT under the character (a foot ray), not the origin. Every
## hit is resolved to its shape (collider + shape index) and gated by the ShapeRegistry (6.4).

const WORLD_MASK := 1 | 4          ## layer 1 world + layer 3 thin_props (design 14.1)
const MARKER_MASK := 1 << 8        ## layer 9 trav_markers

var space: PhysicsDirectSpaceState3D
var registry: TravShapeRegistry
var ledges: TravLedgeGraph
var settings := {}
var exclude: Array[RID] = []
var queries := 0
var last := {}                      ## debug: the last probe's intermediate values


func _init(p_space: PhysicsDirectSpaceState3D = null, p_registry: TravShapeRegistry = null,
		p_ledges: TravLedgeGraph = null, p_settings := {}, p_exclude: Array[RID] = []) -> void:
	space = p_space
	registry = p_registry if p_registry else TravShapeRegistry.new()
	ledges = p_ledges
	settings = p_settings
	exclude = p_exclude


func _s(path: String, def: Variant) -> Variant:
	var cur: Variant = settings
	for k in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(k):
			cur = cur[k]
		else:
			return def
	return cur


# --------------------------------------------------------------------------------------------------
# Low-level queries
# --------------------------------------------------------------------------------------------------

func ray(from: Vector3, to: Vector3, mask := WORLD_MASK) -> Dictionary:
	queries += 1
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	q.hit_back_faces = false
	return space.intersect_ray(q)


## Sphere cast from `from` along `motion`; returns {} or {point, normal, collider, shape, rid, fraction}.
func sphere_cast(from: Vector3, motion: Vector3, radius: float, mask := WORLD_MASK) -> Dictionary:
	var sh := SphereShape3D.new()
	sh.radius = radius
	return _shape_cast(sh, Transform3D(Basis.IDENTITY, from), motion, mask)


func capsule_cast(center: Vector3, motion: Vector3, radius: float, height: float, mask := WORLD_MASK) -> Dictionary:
	var sh := CapsuleShape3D.new()
	sh.radius = radius
	sh.height = height
	return _shape_cast(sh, Transform3D(Basis.IDENTITY, center), motion, mask)


func _shape_cast(sh: Shape3D, xf: Transform3D, motion: Vector3, mask: int) -> Dictionary:
	queries += 2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = xf
	q.motion = motion
	q.collision_mask = mask
	q.exclude = exclude
	q.margin = 0.001
	var fr := space.cast_motion(q)
	if fr.is_empty() or fr[1] >= 1.0:
		return {}
	var q2 := PhysicsShapeQueryParameters3D.new()
	q2.shape = sh
	q2.transform = Transform3D(xf.basis, xf.origin + motion * fr[1])
	q2.collision_mask = mask
	q2.exclude = exclude
	q2.margin = 0.001
	var info := space.get_rest_info(q2)
	if info.is_empty():
		return {}
	info["fraction"] = fr[0]
	info["center"] = xf.origin + motion * fr[0]
	info["collider"] = instance_from_id(int(info.collider_id)) if info.has("collider_id") else null
	return info


func point_solid(p: Vector3, mask := WORLD_MASK) -> bool:
	queries += 1
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = mask
	q.exclude = exclude
	return not space.intersect_point(q, 1).is_empty()


## Ground under a point: {y, normal, hit} (hit false when nothing within `depth`).
func support_at(p: Vector3, up := 0.5, depth := 6.0) -> Dictionary:
	var h := ray(p + Vector3.UP * up, p - Vector3.UP * depth)
	if h.is_empty():
		return {"y": p.y, "normal": Vector3.UP, "hit": false}
	return {"y": (h.position as Vector3).y, "x": (h.position as Vector3).x, "z": (h.position as Vector3).z, "normal": h.normal, "hit": true,
			"collider": h.collider, "shape": h.shape}


func _describe(collider: Object, shape_idx: int) -> Dictionary:
	return registry.describe(collider, shape_idx) if registry else {}


# --------------------------------------------------------------------------------------------------
# B-F: the obstacle ahead
# --------------------------------------------------------------------------------------------------

func probe_ahead(feet: Vector3, heading: Vector3, speed: float, careful := false) -> TravObstacleInfo:
	queries = 0
	heading.y = 0.0
	if heading.length() < 1e-3:
		return TravObstacleInfo.none("no_obstacle")
	heading = heading.normalized()
	var sup := support_at(feet)
	var support_y: float = sup.y
	var r := float(_s("sweep_capsule.radius", 0.25))
	var bot := float(_s("sweep_capsule.bottom", 0.35))
	var top := float(_s("sweep_capsule.top", 1.85))
	var L := maxf(float(_s("lookahead.min", 0.8)), speed * float(_s("lookahead.per_speed", 0.45)) + float(_s("lookahead.extra", 0.3)))
	var center := Vector3(feet.x, support_y + 0.5 * (bot + top), feet.z)
	var hit := capsule_cast(center, heading * L, r, top - bot)
	if hit.is_empty():
		var o := TravObstacleInfo.none("no_obstacle")
		o.support_y = support_y
		o.queries = queries
		return o
	var info := TravObstacleInfo.new()
	info.support_y = support_y
	info.collider = hit.collider
	info.shape_idx = int(hit.get("shape", -1))
	info.rid = hit.get("rid", RID())
	info.shape_node = TravShapeRegistry.resolve(info.collider, info.shape_idx)
	info.descriptor = _describe(info.collider, info.shape_idx)
	info.tags = info.descriptor.get("tags", [])
	info.surface = str(info.descriptor.get("surface", ""))
	info.hit_point = hit.point
	var n: Vector3 = hit.normal
	var ny := n.y
	var nh := Vector3(n.x, 0, n.z)
	if nh.length() < 1e-3:
		nh = -heading
	nh = nh.normalized()
	var P: Vector3 = hit.point
	# The capsule's first contact can be a corner of a small or rotated prop (a 0.8 m crate turned
	# 17 deg is touched at its leading corner, and the support area measured there fails): the
	# top, the support area and the depth are measured where the character's own line meets the
	# same face (review 2026-09-24).
	if absf(ny) < 0.5:
		var lf := Vector3(feet.x, P.y, feet.z)
		var lh := ray(lf, lf + heading * (L + r + 0.6))
		if not lh.is_empty() and lh.collider == hit.collider and int(lh.get("shape", -1)) == info.shape_idx:
			var ln: Vector3 = lh.normal
			var lnh := Vector3(ln.x, 0, ln.z)
			if absf(ln.y) < 0.5 and lnh.length() > 1e-3 and lnh.normalized().dot(nh) > 0.85:
				P = lh.position
				nh = lnh.normalized()
	info.normal = nh
	info.face_class = "walkable" if ny >= float(_s("face_classes.walkable", 0.707)) else ("steep" if ny >= float(_s("face_classes.steep", 0.5)) else "wall")
	info.distance = Vector2(P.x - feet.x, P.z - feet.z).length()
	if info.face_class == "walkable":
		info.kind = "none"
		info.reason = "no_obstacle"
		info.queries = queries
		return info
	var gate := TravShapeRegistry.gate(info.descriptor)
	if gate != "":
		info.kind = "none"
		info.reason = gate
		info.queries = queries
		return info
	# C. free space and top.
	var into := -nh
	var tangent := Vector3.UP.cross(nh).normalized()
	var ceil_hit := ray(Vector3(P.x, support_y + 0.35, P.z) + nh * 0.05, Vector3(P.x, support_y + 3.8, P.z) + nh * 0.05)
	var y0 := support_y + float(_s("top_probe.start", 3.8))
	if not ceil_hit.is_empty():
		info.ceiling = (ceil_hit.position as Vector3).y
		y0 = float(info.ceiling) - 0.05
	var probe_base := Vector3(P.x, 0, P.z)
	if point_solid(Vector3(probe_base.x, y0, probe_base.z) + into * 0.05):
		info.kind = "none"
		info.reason = "ceiling"
		info.queries = queries
		return info
	var sr := float(_s("top_probe.sphere_radius", 0.06))
	var cands := []
	var offsets: Array = _s("top_probe.behind", [0.05, 0.12, 0.25, 0.4])
	var samples := []
	for b in offsets:
		samples.append(into * float(b))
	var tg := float(_s("top_probe.tangent", 0.2))
	samples.append(into * 0.12 + tangent * tg)
	samples.append(into * 0.12 - tangent * tg)
	var ymin := support_y + 0.3
	for off: Vector3 in samples:
		var from := Vector3(probe_base.x, y0, probe_base.z) + off
		var c := sphere_cast(from, Vector3(0, -(y0 - ymin), 0), sr)
		if c.is_empty():
			continue
		var cn: Vector3 = c.normal
		if cn.y < 0.7:
			continue
		var cy: float = (c.point as Vector3).y
		cands.append({"y": cy, "off": off, "point": c.point, "collider": c.collider, "shape": int(c.get("shape", -1))})
	if cands.is_empty():
		info.kind = "none"
		info.reason = "wall"
		info.queries = queries
		return info
	var ys := []
	var best: Dictionary = cands[0]
	for c: Dictionary in cands:
		ys.append(float(c.y))
		if float(c.y) > float(best.y):
			best = c
	ys.sort()
	info.irregular = float(ys[ys.size() - 1]) - float(ys[0]) > 0.25
	var top_y: float = ys[ys.size() / 2] if info.irregular else float(best.y)
	# The top's own shape must pass the gate too (a trunk cap above a rock, a no_stand rail).
	var tdesc := _describe(best.collider, int(best.shape))
	var tgate := TravShapeRegistry.gate(tdesc)
	if tgate != "":
		info.kind = "none"
		info.reason = tgate
		info.queries = queries
		return info
	info.top_point = Vector3(P.x, top_y, P.z) + into * 0.12
	info.face_point = Vector3(P.x, top_y, P.z)
	info.h = top_y - support_y
	# The obstacle's own height: above the ground at the foot of its face (0.3 m in front), not
	# above the ground under the feet, which on a slope differs by up to 0.4 m at the sprint
	# lookahead (an 8 deg upslope made a 0.95 wall read 1.31 m with its landing +0.63 m: no
	# vault). The move is chosen and its landing judged by this height; the warp still starts
	# from the support under the feet (review 2026-09-24).
	info.base_y = support_y
	var fb := Vector3(P.x, 0, P.z) + nh * 0.3
	var bh := ray(Vector3(fb.x, top_y - 0.05, fb.z), Vector3(fb.x, support_y - 1.0, fb.z))
	if not bh.is_empty() and (bh.normal as Vector3).y >= 0.707:
		var by: float = (bh.position as Vector3).y
		if absf(by - support_y) <= 0.5 and by < top_y - 0.2:
			info.base_y = by
	info.h_face = top_y - info.base_y
	# Support area (C4) and depth (D).
	var on_top := func(p: Vector3) -> bool:
		var hh := ray(Vector3(p.x, top_y + 0.4, p.z), Vector3(p.x, top_y - 0.3, p.z))
		return not hh.is_empty() and absf((hh.position as Vector3).y - top_y) <= 0.1
	var no_stand := bool(tdesc.get("no_stand", info.descriptor.get("no_stand", false)))
	# Room to stand: 0.6 m deep and 0.4 m wide on the approach line (a stance is ~0.35 m wide; the
	# old 0.6 m width failed a 0.8 m crate met 12 cm off its middle; review 2026-09-24).
	info.support_area = {
		"hands": on_top.call(info.face_point + into * 0.1),
		"knee": on_top.call(info.face_point + into * 0.3),
		"stand": not no_stand and on_top.call(info.face_point + into * 0.6) and on_top.call(info.face_point + into * 0.3 + tangent * 0.2) and on_top.call(info.face_point + into * 0.3 - tangent * 0.2),
	}
	var d := 0.05
	var last_on := 0.0
	info.depth = INF
	while d <= 2.2:
		var p := info.face_point + into * d
		var c := sphere_cast(Vector3(p.x, top_y + 0.35, p.z), Vector3(0, -(top_y + 0.35 - (support_y - 6.0)), 0), 0.03)
		var cy: float = (c.point as Vector3).y if not c.is_empty() else -INF
		if cy < top_y - 0.3:
			info.depth = 0.5 * (last_on + d)
			break
		last_on = d
		d += 0.15
	# Width across the heading (beam tops).
	var wl := 0.0
	var wr := 0.0
	for s in [0.1, 0.2, 0.3, 0.45, 0.6, 1.0]:
		if on_top.call(info.face_point + into * 0.12 + tangent * s):
			wl = s
		else:
			break
	for s in [0.1, 0.2, 0.3, 0.45, 0.6, 1.0]:
		if on_top.call(info.face_point + into * 0.12 - tangent * s):
			wr = s
		else:
			break
	info.width = wl + wr + 0.1
	# E. landing beyond a thin obstacle: where the feet come down (0.6 m past the far edge), unless
	# something farther stands 0.35 m higher (a step or a box behind the wall). The highest of the
	# samples was taken before, which on an 8 deg upslope read +0.32 m and ruled out every vault.
	if info.depth < INF:
		var far := info.face_point + into * info.depth
		var best_l: Variant = null
		var first_l: Variant = null
		var first_p := Vector3.ZERO
		var best_p := Vector3.ZERO
		for x in [0.6, 1.2, maxf(0.6, speed * 0.3)]:
			var lp := far + into * float(x)
			var lh := ray(Vector3(lp.x, top_y + 0.5, lp.z), Vector3(lp.x, support_y - 6.0, lp.z))
			if lh.is_empty():
				continue
			var ly: float = (lh.position as Vector3).y
			if first_l == null:
				first_l = ly
				first_p = lh.position
			if best_l == null or ly > float(best_l):
				best_l = ly
				best_p = lh.position
		if first_l != null and float(best_l) - float(first_l) < 0.35:
			best_l = first_l
			best_p = first_p
		if best_l != null:
			info.landing_point = best_p
			info.landing_y = best_l
			info.landing = float(best_l) - info.base_y
	# F. clearance on the top.
	var up := ray(info.top_point + Vector3.UP * 0.05, info.top_point + Vector3.UP * 2.0)
	info.clearance_h = ((up.position as Vector3).y - top_y) if not up.is_empty() else 2.0
	info.clearance = "stand" if info.clearance_h >= float(_s("clearance.stand", 1.6)) else ("crouch" if info.clearance_h >= float(_s("clearance.crouch", 1.1)) else "none")
	info.kind = "wall"
	info.queries = queries
	last = info.to_dict()
	return info


# --------------------------------------------------------------------------------------------------
# A: overhead lips from the LedgeGraph (no wall needed)
# --------------------------------------------------------------------------------------------------

func probe_overhead(feet: Vector3, heading: Vector3, speed: float, careful := false, cooldown := {}) -> TravObstacleInfo:
	if ledges == null:
		return TravObstacleInfo.none("no_obstacle")
	heading.y = 0.0
	if heading.length() < 1e-3:
		return TravObstacleInfo.none("no_obstacle")
	heading = heading.normalized()
	var sup := support_at(feet)
	var support_y: float = sup.y
	var near := float(_s("overhead.near", 0.3))
	var far := float(_s("overhead.far", 0.8)) + speed * float(_s("overhead.far_per_speed", 0.45))
	var ang := deg_to_rad(float(_s("overhead.angle_careful_deg" if careful else "overhead.angle_deg", 40)))
	var lo := float(_s("overhead.lip_min", 2.22))
	var hi := float(_s("overhead.lip_max", 3.3))
	var best := {}
	var best_score := INF
	# (The lips are 2.2-3.3 m over the feet: the query is centred at their height, its radius in 3D.)
	var qc := feet + heading * (0.5 * (near + far)) + Vector3.UP * (support_y - feet.y + 0.5 * (lo + hi))
	for c: Dictionary in ledges.query_near(qc, far + 1.0 + 0.5 * (hi - lo)):
		var q: Vector3 = c.point
		var lip_h := q.y - support_y
		if lip_h < lo or lip_h > hi:
			continue
		if cooldown.has(int(c.ledge_id)):
			continue
		var dv := Vector3(q.x - feet.x, 0, q.z - feet.z)
		var dist := dv.length()
		if dist < near or dist > far:
			continue
		var a := heading.angle_to(dv.normalized()) if dist > 1e-3 else 0.0
		if a > ang:
			continue
		var lg: Dictionary = ledges.ledge(int(c.ledge_id))
		var n: Vector3 = c.normal
		if str(lg.get("grip", "hang")) == "braced" and n.dot(heading) > -cos(deg_to_rad(60.0)):
			continue
		# The edge of a platform (a top to stand on) is climbed from its open side only: from under the
		# platform the edge is ahead too (the fort's firing step, 2026-09-26), and the climb went up
		# through the boards.
		if str(lg.get("top_class", "none")) != "none" and n.dot(dv) > 0.0:
			continue
		var score := a * 2.0 + dist * 0.5 + lip_h * 0.1
		if score < best_score:
			best_score = score
			best = c
	if best.is_empty():
		var o := TravObstacleInfo.none("no_obstacle")
		o.support_y = support_y
		return o
	var info := TravObstacleInfo.new()
	info.kind = "overhead"
	info.support_y = support_y
	info.base_y = support_y
	info.ledge_id = int(best.ledge_id)
	info.ledge_point = best.point
	info.ledge_tangent = best.tangent
	var n: Vector3 = best.normal
	# Approach from the ledge's open side: the face normal points at the character.
	if n.dot(Vector3(feet.x - (best.point as Vector3).x, 0, feet.z - (best.point as Vector3).z)) < 0.0:
		n = -n
	info.normal = n
	info.face_point = best.point
	info.top_point = best.point
	info.h = (best.point as Vector3).y - support_y
	var lg: Dictionary = ledges.ledge(info.ledge_id)
	info.free_hang = str(lg.get("grip", "hang")) != "braced"
	info.clearance = str(lg.get("top_class", "none"))
	info.depth = float(lg.get("lip_m", INF))
	info.distance = Vector2((best.point as Vector3).x - feet.x, (best.point as Vector3).z - feet.z).length()
	info.descriptor = lg
	# The shape the lip belongs to (just inside its top edge): the IK's top surface and the one shape the
	# path check lets the climb touch.
	var qp := PhysicsPointQueryParameters3D.new()
	qp.position = (best.point as Vector3) - n * 0.03 - Vector3.UP * 0.03
	qp.collision_mask = WORLD_MASK
	qp.exclude = exclude
	queries += 1
	for r in space.intersect_point(qp, 4):
		info.collider = r.collider
		info.rid = r.rid
		info.shape_idx = int(r.shape)
		info.shape_node = TravShapeRegistry.resolve(r.collider, int(r.shape))
		info.descriptor = _describe(r.collider, int(r.shape)).merged(lg)
		break
	return info


## Room under an overhead lip for the hanging body at the character's side of it: nothing solid in the
## box from `top_face` below the lip down to 0.35 m over the support, from the lip's face out to `out`
## m, `half_w` m to each side (the fort's walkway posts stand under its edge), apart from `skip`
## (the lip's own shape). "" or "blocked_below".
func room_below(info: TravObstacleInfo, top_face := 0.35, out := 0.45, half_w := 0.35) -> String:
	var n := info.normal
	var t := Vector3.UP.cross(n).normalized()
	var y1 := info.ledge_point.y - top_face
	var y0 := info.support_y + 0.35
	if y1 - y0 < 0.1:
		return ""
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.0 * half_w, y1 - y0, out)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = bx
	var c := Vector3(info.ledge_point.x, 0.5 * (y0 + y1), info.ledge_point.z) + n * (0.5 * out - 0.02)
	q.transform = Transform3D(Basis(t, Vector3.UP, n), c)
	q.collision_mask = WORLD_MASK
	q.exclude = exclude
	q.margin = 0.001
	queries += 1
	for r in space.intersect_shape(q, 8):
		if info.rid.is_valid() and r.rid == info.rid and int(r.shape) == info.shape_idx:
			continue
		return "blocked_below"
	return ""


# --------------------------------------------------------------------------------------------------
# G: edges and gaps (slope-relative, design 6.2 G)
# --------------------------------------------------------------------------------------------------

func probe_edge(feet: Vector3, heading: Vector3, speed: float) -> TravObstacleInfo:
	heading.y = 0.0
	if heading.length() < 1e-3:
		return TravObstacleInfo.none("no_obstacle")
	heading = heading.normalized()
	var sup := support_at(feet)
	var y0: float = sup.y
	var n: Vector3 = sup.normal
	var slope := (Vector3(n.x, 0, n.z).dot(heading)) / maxf(n.y, 0.2)
	var prev_y := y0
	var prev_x := 0.0
	for x in [0.4, 1.0, maxf(1.2, speed * 0.35)]:
		var p := feet + heading * float(x)
		var y_exp := y0 - float(x) * slope
		var h := ray(Vector3(p.x, y0 + 0.6, p.z), Vector3(p.x, y0 - 6.0, p.z))
		var hy: float = (h.position as Vector3).y if not h.is_empty() else -INF
		var excess := y_exp - hy
		var brk := h.is_empty() or (h.normal as Vector3).y < 0.707 or absf(hy - prev_y) / maxf(float(x) - prev_x, 0.05) > 1.0
		if excess > 0.5 and brk:
			var info := TravObstacleInfo.new()
			info.kind = "edge"
			info.support_y = y0
			info.distance = float(x)
			info.drop = excess if not h.is_empty() else INF
			# Find the edge line: bisect between the last supported x and x.
			var a := prev_x
			var b := float(x)
			for i in 6:
				var m := 0.5 * (a + b)
				var pm := feet + heading * m
				var hm := ray(Vector3(pm.x, y0 + 0.6, pm.z), Vector3(pm.x, y0 - 0.5, pm.z))
				if hm.is_empty():
					b = m
				else:
					a = m
			info.face_point = feet + heading * a
			info.face_point.y = y0
			info.normal = heading
			# Gap scan: a landing near the support level (-0.9 .. +0.6 m) beyond a real hole (a floor
			# at least 0.8 m below the landing, or none); a lower ground right after the edge is a
			# drop, not a gap.
			var gx := b + 0.25
			var hole := false
			while gx <= 6.0:
				var pg := feet + heading * gx
				var hg := ray(Vector3(pg.x, y0 + 1.7, pg.z), Vector3(pg.x, y0 - 6.0, pg.z))
				var gy: float = (hg.position as Vector3).y if not hg.is_empty() else -INF
				if not hg.is_empty() and (hg.normal as Vector3).y >= 0.707 and gy >= y0 - 0.9 and gy <= y0 + 0.6:
					if hole:
						info.gap_distance = gx - a
						info.landing_y = gy
						info.landing = gy - y0
						info.landing_point = hg.position
					break
				if gy < y0 - 0.95:
					hole = true
				gx += 0.25
			return info
		prev_y = hy
		prev_x = float(x)
	var o := TravObstacleInfo.none("no_obstacle")
	o.support_y = y0
	return o


# --------------------------------------------------------------------------------------------------
# H: low ceilings (crouch-under) and marker volumes
# --------------------------------------------------------------------------------------------------

func probe_ceiling(feet: Vector3, heading: Vector3) -> TravObstacleInfo:
	heading.y = 0.0
	heading = heading.normalized()
	var sup := support_at(feet)
	var y0: float = sup.y
	var p := feet + heading * 0.7
	var up := ray(Vector3(p.x, y0 + 0.2, p.z), Vector3(p.x, y0 + 2.0, p.z))
	if up.is_empty():
		return TravObstacleInfo.none("no_obstacle")
	var ch: float = (up.position as Vector3).y - y0
	var lo := float(_s("clearance.crouch_under_min", 1.07))
	var hi := float(_s("clearance.crouch_under_max", 1.4))
	var info := TravObstacleInfo.new()
	info.support_y = y0
	info.clearance_h = ch
	if ch >= lo and ch <= hi:
		info.kind = "crawl"
		info.face_point = p
		info.normal = -heading
		return info
	info.kind = "none"
	info.reason = "no_clearance" if ch < lo else "no_obstacle"
	return info


## Marker volumes around a point (layer 9 Area3Ds): [{node, kind, ...}].
func markers_near(p: Vector3, radius := 3.0) -> Array:
	queries += 1
	var sh := SphereShape3D.new()
	sh.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, p)
	q.collision_mask = MARKER_MASK
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var out := []
	for r in space.intersect_shape(q, 16):
		var n: Node = r.collider
		var m: Node = n.get_parent() if n and n.get_parent() and n.get_parent().has_method("marker_info") else n
		if m and m.has_method("marker_info"):
			out.append(m.call("marker_info"))
	return out


# --------------------------------------------------------------------------------------------------
# J: the warped path against the world (design 6.2 J, 13)
# --------------------------------------------------------------------------------------------------

## "" when clear, else "blocked_path" / "terrain_overlap". Capsules follow the pelvis path; the
## traversed shape is ignored (only it), terrain never is. `skin` shrinks the capsule.
func validate_path(path: TravWarpedPath, info: TravObstacleInfo, skin := 0.02) -> String:
	var per_s := float(_s("path_sweep.per_second", 30))
	var count := maxi(int(_s("path_sweep.min_samples", 8)), int(ceil(per_s * path.duration)))
	var sh := CapsuleShape3D.new()
	sh.radius = 0.22 - skin
	sh.height = 1.0
	var t_first: Variant = path.windows.get("first_support")
	for k in count + 1:
		var t := path.duration * k / float(count)
		var pel := path.point_at("pelvis", t)
		var head := path.point_at("head_top", t)
		# The torso from the pelvis to below the head (legs are cleared by the warper's
		# clearance pass; the support contacts must not register, design 13 skin rule).
		var lo := pel.y - 0.2
		var hi := maxf(lo + 0.05, head.y - 0.2)
		sh.radius = 0.2 - skin
		sh.height = maxf(2.0 * sh.radius + 0.01, hi - lo + 2.0 * sh.radius)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sh
		q.transform = Transform3D(Basis.IDENTITY, Vector3(pel.x, 0.5 * (lo + hi), pel.z))
		q.collision_mask = WORLD_MASK
		q.exclude = exclude
		queries += 1
		for r in space.intersect_shape(q, 8):
			var same: bool = info != null and r.rid == info.rid and int(r.shape) == info.shape_idx
			var d := _describe(r.collider, int(r.shape))
			if same and not TravShapeRegistry.is_terrain(d):
				continue
			return "terrain_overlap" if TravShapeRegistry.is_terrain(d) else "blocked_path"
	return ""
