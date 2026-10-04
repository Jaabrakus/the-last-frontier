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
##
## COVER TO FIGHT FROM (NpcSkirmish, the duel's opponent; the user, 2026-10-04: "npc can find cover aim and etc"):
##   NpcCover.pick(fighter, threat, opts) -> {} or the record {spot, low, top, peek, peek_low, peek_side, body, center, side_m,
##       d_threat, mode}: of the spots within opts.radius (FIGHT_RADIUS) behind what stands there (the same spots as find's),
##       one that HIDES it from the threat (low: the line from his eyes, THREAT_EYE over where he is, to its crouched chest and
##       head blocked; tall, TALL_H and more: to its standing chest and head) with a place to FIGHT from (peek: standing up over
##       a low thing, or a step out past a tall one's end, or a low one's crouched, PEEK_OUT past it: the line from the
##       musket there to the threat clear), for what it wants (opts.mode): "fight", "reload" (hidden only), "advance" (ADVANCE_M
##       nearer him at least), "flank" (FLANK_DEG round him from where it is), "fallback" (FALLBACK_M further off); the nearest
##       of them, the way there in his sight (a ray to its middle) and a spot far from KEEP_M from him dearer (in a hurry,
##       opts.urgent, the walk and the open way dearer still: URGENT_K); opts.avoid (spots it means to leave), opts.bounds (a
##       Rect2 on the ground it keeps to: the duel's arena), opts.foe (left out of the rays)
##   NpcCover.protects(fighter, rec, threat, foe) -> bool    the record's spot still hidden from the threat (false: flanked)
##   NpcCover.broken(rec) -> bool                            what it hid behind is gone (crumbled, freed)
##   NpcCover.peek_for(fighter, rec, threat, foe, side)      the record's peek again for where the threat is now (side: the
##                                                           side to try first, 1 its right, -1 its left, 0 either)
##   NpcCover.exposed(fighter, threat, foe) -> bool          a clear line from the threat's eyes to its chest where it is now

const RADIUS := 12.0
const MIN_H := 0.95
const GAP_ROUND := 0.55
const GAP_FLAT := 0.7
const CHECKED := 3
const TAKEN_M := 1.3
const FIGHT_RADIUS := 24.0
## A thing this high or more over the ground hides a man standing (behind lower ones it crouches).
const TALL_H := 1.65
## The threat's eyes over where he stands (a standing man's, a little low), the heights hidden behind a low thing (a crouching
## man's chest and head) and a tall one (a standing man's), and the musket's height to peek from, standing and crouched (the
## fighters' aim clips: its line at 1.2 m standing, 1.0 m crouched; a low thing of 1.15 m is shot over standing).
const THREAT_EYE := 1.5
const HIDE_LOW := [0.8, 1.12]
const HIDE_TALL := [1.25, 1.62]
const MUZZLE_UP := 1.22
const MUZZLE_LOW := 0.98
## The threat's chest the peek must see (a standing man's; a crouched man hidden behind his own cover is not to be seen).
const AIM_UP := 1.3
## A step out to peek goes this far past the thing's edge (m).
const PEEK_OUT := 0.55
## A spot behind a box is kept this far in from its ends (m); a hidden man's shoulders are this far either side of his chest.
const INSET_M := 0.55
const SHOULDER_M := 0.28
const ADVANCE_M := 6.0
const FALLBACK_M := 4.0
const FLANK_DEG := 35.0
const KEEP_M := 24.0
## Spots this near the threat are no cover from him (m); in a pick the nearest spots are looked at closely (rays) until
## PICK_FOUND of them hide it, PICK_TESTED at most.
const NEAR_THREAT_M := 6.0
const PICK_TESTED := 14
const PICK_FOUND := 5
## A pick in a hurry (opts.urgent: flanked, hit, its cover gone) weighs the walk there and the way in his sight this much more.
const URGENT_K := 1.8
const SHAPES_MAX := 64
## A spot with nowhere to fight from costs this much more (m of walking) to a fighter that means to fight from it; the way
## there in the threat's sight costs EXPOSED_COST more.
const NO_PEEK_COST := 14.0
const EXPOSED_COST := 6.0


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


# ---------------------------------------------------------------- cover to fight from (see the header)
static func pick(me: NpcFighter, threat: Vector3, opts := {}) -> Dictionary:
	if not me.is_inside_tree():
		return {}
	var space := me.get_world_3d().direct_space_state
	var at := me.global_position
	var mode := String(opts.get("mode", "fight"))
	var avoid: Array = opts.get("avoid", [])
	var bounds: Rect2 = opts.get("bounds", Rect2())
	var ex := _exclude(me, opts.get("foe"))
	var eye := threat + Vector3.UP * THREAT_EYE
	var d_me := _flat(threat, at)
	var cands: Array = []
	for s: Dictionary in _shapes(space, me, at, float(opts.get("radius", FIGHT_RADIUS))):
		var sp := _spot(int(s.kind), s.data, s.xf, at, threat)
		if sp == Vector3.INF:
			continue
		sp = _inset(int(s.kind), s.data, s.xf, sp)
		sp.y = _ground_y(space, sp, at.y, ex)
		var h := float(s.top) - sp.y
		var dt := _flat(threat, sp)
		if h < MIN_H or dt < NEAR_THREAT_M or (bounds.has_area() and not bounds.has_point(Vector2(sp.x, sp.z))):
			continue
		if _near_any(sp, avoid, 2.0) or _taken(me, sp):
			continue
		match mode:
			"advance":
				if dt > d_me - ADVANCE_M:
					continue
			"fallback":
				if dt < d_me + FALLBACK_M:
					continue
			"flank":
				var a := absf(rad_to_deg(Vector2(at.x - threat.x, at.z - threat.z).angle_to(Vector2(sp.x - threat.x, sp.z - threat.z))))
				if a < FLANK_DEG or dt > d_me + 6.0:
					continue
		cands.append([_flat(at, sp), sp, h, s])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var best := {}
	var best_cost := INF
	var urgent := 1.0 + (URGENT_K - 1.0) * float(bool(opts.get("urgent", false)))
	var found := 0
	for i in mini(cands.size(), PICK_TESTED):
		if found >= PICK_FOUND:
			break
		var c: Array = cands[i]
		var sp: Vector3 = c[1]
		var low := float(c[2]) < TALL_H
		if not _hidden(space, sp, low, eye, ex):
			continue
		found += 1
		var s: Dictionary = c[3]
		var rec := {"spot": sp, "low": low, "top": float(c[2]), "body": int(s.id), "center": (s.xf as Transform3D).origin,
				"kind": int(s.kind), "data": s.data, "xf": s.xf, "mode": mode, "d_threat": _flat(threat, sp)}
		_peek(space, rec, threat, ex, 0)
		var cost := float(c[0]) * urgent
		if mode != "reload":
			cost += (NO_PEEK_COST if rec.peek == Vector3.INF else 0.0) + absf(float(rec.d_threat) - KEEP_M) * 0.25
		if float(c[0]) > 3.0 and _clear(space, eye, (at + sp) * 0.5 + Vector3.UP * 1.2, ex):
			cost += EXPOSED_COST * urgent             # (the way there in his sight)
		if cost < best_cost:
			best_cost = cost
			best = rec
	if not best.is_empty():
		best["cost"] = best_cost
	return best


## Whether the record's spot still hides a man there from `threat` (the lines from his eyes to its chest and head blocked).
static func protects(me: NpcFighter, rec: Dictionary, threat: Vector3, foe: Node = null) -> bool:
	if rec.is_empty() or not me.is_inside_tree():
		return false
	return _hidden(me.get_world_3d().direct_space_state, rec.spot, bool(rec.low), threat + Vector3.UP * THREAT_EYE, _exclude(me, foe))


## Whether what the record's spot hid behind is gone: freed, out of the world, an earth wall crumbling (FormRaised), a thing
## that says it is broken (is_broken()).
static func broken(rec: Dictionary) -> bool:
	var id := int(rec.get("body", 0))
	if id == 0 or not is_instance_id_valid(id):
		return true
	var o := instance_from_id(id)
	if o is Node and (not (o as Node).is_inside_tree() or (o as Node).is_queued_for_deletion()):
		return true
	if o is FormRaised and (o as FormRaised).state == FormRaised.State.CRUMBLING:
		return true
	return o.has_method(&"is_broken") and bool(o.call(&"is_broken"))


## The record's peek worked out again for where the threat is now (`side` first: 1 its right as it faces him, -1 its left).
static func peek_for(me: NpcFighter, rec: Dictionary, threat: Vector3, foe: Node = null, side := 0) -> void:
	if rec.is_empty() or not me.is_inside_tree():
		return
	_peek(me.get_world_3d().direct_space_state, rec, threat, _exclude(me, foe), side)


## Whether a man where `me` stands now is in the threat's sight (a clear line from his eyes to its chest).
static func exposed(me: NpcFighter, threat: Vector3, foe: Node = null) -> bool:
	if not me.is_inside_tree():
		return false
	var chest := me.global_position + Vector3.UP * (0.85 if me.is_crouching else 1.3)
	return _clear(me.get_world_3d().direct_space_state, threat + Vector3.UP * THREAT_EYE, chest, _exclude(me, foe))


## Where to fight from behind the record's thing (rec.peek, peek_low, peek_side; peek INF: nowhere): over a low thing standing
## (rec.spot itself), or a step out past its edge to `first`'s side or the nearer (crouched beside a low thing, standing past a
## tall one); the step there clear and the line from the musket there to the threat's chest clear.
static func _peek(space: PhysicsDirectSpaceState3D, rec: Dictionary, threat: Vector3, ex: Array[RID], first: int) -> void:
	rec["peek"] = Vector3.INF
	rec["peek_low"] = false
	rec["peek_side"] = 0
	var spot: Vector3 = rec.spot
	var to := Vector3(threat.x - spot.x, 0.0, threat.z - spot.z)
	if to.length() < 0.5:
		return
	to = to.normalized()
	var side := to.cross(Vector3.UP).normalized()
	var aim := threat + Vector3.UP * AIM_UP
	var c: Vector3 = rec.center
	var lat := Vector3(spot.x - c.x, 0.0, spot.z - c.z).dot(side)
	var ext := _extent_along(rec, side) + PEEK_OUT + NpcFighter.RADIUS
	var low := bool(rec.low)
	var tries: Array = []
	var order := [1, -1] if (first > 0 or (first == 0 and lat >= 0.0)) else [-1, 1]
	for k: int in order:
		tries.append([spot + side * (float(k) * ext - lat), low, k])
	if low:
		# (over a low thing: standing up where it hides, first unless a side was asked for: the last peek drew his eye there)
		tries.insert(0 if first == 0 else tries.size(), [spot, false, 0])
	for t: Array in tries:
		var p: Vector3 = t[0]
		if int(t[2]) != 0:
			if not _clear(space, spot + Vector3.UP * 0.5, p + Vector3.UP * 0.5, ex):
				continue                               # (the step out held up)
			var g := _ground_y(space, p, spot.y, ex)
			if absf(g - spot.y) > 0.45:
				continue                               # (no footing there: a step up on something, a drop)
			p.y = g
		if _clear(space, p + Vector3.UP * (MUZZLE_LOW if bool(t[1]) else MUZZLE_UP), aim, ex):
			rec["peek"] = p
			rec["peek_low"] = bool(t[1])
			rec["peek_side"] = int(t[2])
			return


## Whether a man at `spot` (crouched behind a low thing, standing behind a tall one) is hidden from eyes at `eye`: his chest
## and head, and his shoulders either side of his chest (SHOULDER_M).
static func _hidden(space: PhysicsDirectSpaceState3D, spot: Vector3, low: bool, eye: Vector3, ex: Array[RID]) -> bool:
	var hs: Array = HIDE_LOW if low else HIDE_TALL
	var to := Vector3(eye.x - spot.x, 0.0, eye.z - spot.z)
	var side := to.cross(Vector3.UP).normalized() * SHOULDER_M if to.length() > 0.1 else Vector3.ZERO
	var chest := spot + Vector3.UP * float(hs[0])
	for p: Vector3 in [chest, spot + Vector3.UP * float(hs[1]), chest + side, chest - side]:
		if _clear(space, eye, p, ex):
			return false
	return true


## A box's spot moved in along its face to keep a man's breadth (INSET_M) from its ends (a man at the very end of a wall shows
## round it); other shapes' as they are.
static func _inset(kind: int, data: Variant, xf: Transform3D, sp: Vector3) -> Vector3:
	if kind != PhysicsServer3D.SHAPE_BOX:
		return sp
	var half: Vector3 = data
	var lp := xf.affine_inverse() * sp
	# (the face it is off: the axis it stands furthest outside of; along the other, kept in)
	var ax := 0 if absf(lp.x) / maxf(half.x, 0.01) >= absf(lp.z) / maxf(half.z, 0.01) else 2
	var o := 2 if ax == 0 else 0
	var m := maxf(half[o] - INSET_M, 0.0)
	lp[o] = clampf(lp[o], -m, m)
	return xf * lp


static func _clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, ex: Array[RID]) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1, ex)).is_empty()


## Its own bodies and the foe's (a ray from his eyes starts in him).
static func _exclude(me: NpcFighter, foe: Variant) -> Array[RID]:
	var ex := me.ray_exclude()
	if foe is NpcFighter and is_instance_valid(foe):
		ex.append_array((foe as NpcFighter).ray_exclude())
	elif foe is CollisionObject3D and is_instance_valid(foe):
		ex.append((foe as CollisionObject3D).get_rid())
	return ex


## The ground under `p` (a ray down; `fallback` when it meets nothing).
static func _ground_y(space: PhysicsDirectSpaceState3D, p: Vector3, fallback: float, ex: Array[RID]) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, fallback + 1.5, p.z), Vector3(p.x, fallback - 2.5, p.z), 1, ex))
	return (hit.position as Vector3).y if not hit.is_empty() else fallback


## What stands within `radius` of `at` that could be cover: [{kind, data, xf, top, id}] (the world's bodies, not people or
## loose things; SHAPES_MAX at most).
static func _shapes(space: PhysicsDirectSpaceState3D, me: NpcFighter, at: Vector3, radius: float) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0)
	q.collision_mask = 1
	q.exclude = me.ray_exclude()
	var out: Array = []
	for h: Dictionary in space.intersect_shape(q, SHAPES_MAX):
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
		var kind := PhysicsServer3D.shape_get_type(srid)
		var data: Variant = PhysicsServer3D.shape_get_data(srid)
		out.append({"kind": kind, "data": data, "xf": xf, "top": _top(kind, data, xf), "id": col.get_instance_id()})
	return out


## The highest point of a shape (world y; -INF for what is not cover: the ground's height field, a mesh).
static func _top(kind: int, data: Variant, xf: Transform3D) -> float:
	match kind:
		PhysicsServer3D.SHAPE_SPHERE:
			return xf.origin.y + float(data)
		PhysicsServer3D.SHAPE_CYLINDER, PhysicsServer3D.SHAPE_CAPSULE:
			return xf.origin.y + float((data as Dictionary).get("height", 1.0)) * 0.5 * xf.basis.get_scale().y
		PhysicsServer3D.SHAPE_CONVEX_POLYGON:
			var top := -INF
			for p: Vector3 in (data as PackedVector3Array):
				top = maxf(top, (xf * p).y)
			return top
		PhysicsServer3D.SHAPE_BOX:
			var half: Vector3 = data
			var top := -INF
			for i in 8:
				top = maxf(top, (xf * Vector3(half.x * (1 if i & 1 else -1), half.y * (1 if i & 2 else -1), half.z * (1 if i & 4 else -1))).y)
			return top
	return -INF


## How far the record's thing reaches from its middle along `dir` (a flat world direction; m).
static func _extent_along(rec: Dictionary, dir: Vector3) -> float:
	var xf: Transform3D = rec.xf
	var data: Variant = rec.data
	match int(rec.kind):
		PhysicsServer3D.SHAPE_SPHERE:
			return float(data)
		PhysicsServer3D.SHAPE_CYLINDER, PhysicsServer3D.SHAPE_CAPSULE:
			return float((data as Dictionary).get("radius", 0.3))
		PhysicsServer3D.SHAPE_BOX:
			var half: Vector3 = data
			return absf(dir.dot(xf.basis.x)) * half.x + absf(dir.dot(xf.basis.y)) * half.y + absf(dir.dot(xf.basis.z)) * half.z
		PhysicsServer3D.SHAPE_CONVEX_POLYGON:
			var lo := INF
			var hi := -INF
			for p: Vector3 in (data as PackedVector3Array):
				var k := (xf * p - xf.origin).dot(dir)
				lo = minf(lo, k)
				hi = maxf(hi, k)
			return maxf(absf(lo), absf(hi)) if lo < INF else 0.5
	return 0.5


static func _near_any(p: Vector3, spots: Array, r: float) -> bool:
	for s: Variant in spots:
		if s is Vector3 and (s as Vector3) != Vector3.INF and _flat(p, s as Vector3) < r:
			return true
	return false


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
