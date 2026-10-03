class_name NpcCover
extends RefCounted
## Cover for a fighter (NpcBrain): the nearest spot behind something solid, away from the threat. One query of what stands
## within RADIUS (a sphere of the world's bodies: trunks, rocks, walls, built pieces, trusses, crates; not the ground, not
## people), for each thing a spot on its far side from the threat (round things: past their radius; boxes: off the face that
## looks away from the threat, at the point of it nearest the fighter, in the box's own frame, so a crate or a cabin he stands
## on the threat's side of sends him round it, never into it), kept when the thing is tall enough to hide a crouching man
## (MIN_H) and the spot is not much nearer
## the threat than he is; the nearest few checked with one ray each from the threat's eyes to the spot (blocked: covered).
## Spots another fighter has taken are left to him. Called a few times in a fight, not each frame.
##   NpcCover.find(fighter, threat_pos) -> Vector3 (INF: none near)

const RADIUS := 12.0
const MIN_H := 0.95
const GAP_ROUND := 0.55
const GAP_FLAT := 0.7
const CHECKED := 3
const TAKEN_M := 1.3


static func find(me: NpcFighter, threat: Vector3, radius := RADIUS) -> Vector3:
	if not me.is_inside_tree():
		return Vector3.INF
	var space := me.get_world_3d().direct_space_state
	var at := me.global_position
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0)
	q.collision_mask = 1
	q.exclude = [me.get_rid()]
	var hits := space.intersect_shape(q, 32)
	var d_me := _flat(threat, at)
	var spots: Array = []
	for h: Dictionary in hits:
		var col := h.get("collider") as Object
		if col == null or col is CharacterBody3D or col is RigidBody3D:
			continue
		var rid: RID = h.get("rid")
		var idx := int(h.get("shape", 0))
		var srid := PhysicsServer3D.body_get_shape(rid, idx)
		if not srid.is_valid():
			continue
		var bx: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
		var xf := bx * PhysicsServer3D.body_get_shape_transform(rid, idx)
		var spot := _spot(PhysicsServer3D.shape_get_type(srid), PhysicsServer3D.shape_get_data(srid), xf, at, threat)
		if spot == Vector3.INF:
			continue
		spot.y = at.y
		var d_spot := _flat(threat, spot)
		if d_spot < 5.0 or d_spot < d_me - 3.0 or _taken(me, spot):
			continue
		spots.append([_flat(at, spot), spot])
	spots.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var eye := threat + Vector3.UP * 1.3
	for i in mini(spots.size(), CHECKED):
		var s: Vector3 = spots[i][1]
		var ray := PhysicsRayQueryParameters3D.create(eye, s + Vector3.UP * 0.9, 1, [me.get_rid()])
		if not space.intersect_ray(ray).is_empty():
			return s
	return Vector3.INF


## The spot behind one shape (INF: not cover: the ground, a mesh, too low).
static func _spot(kind: int, data: Variant, xf: Transform3D, at: Vector3, threat: Vector3) -> Vector3:
	var c := Vector3.INF
	var r := 0.0
	var top := -INF
	match kind:
		PhysicsServer3D.SHAPE_SPHERE:
			r = float(data)
			c = xf.origin
			top = c.y + r
		PhysicsServer3D.SHAPE_CYLINDER, PhysicsServer3D.SHAPE_CAPSULE:
			var d: Dictionary = data
			r = float(d.get("radius", 0.3))
			c = xf.origin
			top = c.y + float(d.get("height", 1.0)) * 0.5 * xf.basis.get_scale().y
		PhysicsServer3D.SHAPE_CONVEX_POLYGON:
			var pts: PackedVector3Array = data
			if pts.is_empty():
				return Vector3.INF
			var box := AABB(xf * pts[0], Vector3.ZERO)
			for p in pts:
				box = box.expand(xf * p)
			c = box.get_center()
			r = maxf(box.size.x, box.size.z) * 0.5
			top = box.end.y
			if r > 4.0:
				return Vector3.INF          # (a big rock face or a roof: no single side to hide behind)
		PhysicsServer3D.SHAPE_BOX:
			var half: Vector3 = data
			top = (xf * Vector3(0.0, half.y, 0.0)).y
			if half.x > 30.0 or half.z > 30.0 or top - at.y < MIN_H:
				return Vector3.INF          # (a floor or a ground slab; too low)
			# the far face: of the box's sides (its own frame), the one the threat is furthest outside of, opposite him
			var inv := xf.affine_inverse()
			var lt := inv * threat
			var lm := inv * at
			var ax := 0 if absf(lt.x) / maxf(half.x, 0.01) >= absf(lt.z) / maxf(half.z, 0.01) else 2
			var sgn := -signf(lt[ax]) if lt[ax] != 0.0 else 1.0
			# on it, the point nearest the fighter (kept off its ends a little)
			var mx := maxf(half.x - 0.25, 0.0)
			var mz := maxf(half.z - 0.25, 0.0)
			var lp := Vector3(clampf(lm.x, -mx, mx), 0.0, clampf(lm.z, -mz, mz))
			lp[ax] = sgn * half[ax]
			var ln := Vector3.ZERO
			ln[ax] = sgn
			var out := xf.basis * ln
			out.y = 0.0
			if out.length() < 0.01:
				return Vector3.INF
			return xf * lp + out.normalized() * GAP_FLAT
		_:
			return Vector3.INF
	if top - at.y < MIN_H or r > 4.0:
		return Vector3.INF
	var dir := Vector3(c.x - threat.x, 0.0, c.z - threat.z).normalized()
	if dir == Vector3.ZERO:
		return Vector3.INF
	return c + dir * (r + GAP_ROUND)


## Another fighter has this spot (his cover, or he stands on it).
static func _taken(me: NpcFighter, spot: Vector3) -> bool:
	for f in NpcSenses.fighters:
		if f == me or not is_instance_valid(f) or f.is_dead():
			continue
		if _flat(f.global_position, spot) < TAKEN_M:
			return true
		if f.brain != null and f.brain.cover != Vector3.INF and _flat(f.brain.cover, spot) < TAKEN_M:
			return true
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
