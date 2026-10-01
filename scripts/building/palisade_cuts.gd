class_name PalisadeCuts
extends RefCounted
## Windows cut through the BUILT palisade, in pieces, anywhere (user 2026-09-28, replacing the axe-chopping of
## the classic fort's walls, WallCuts: "the fort should be recreated from builder pieces"; "windows are made by cutting the
## built palisade in pieces, from belly height up, measured from where the player stands, deck or ground"; the old slot
## "was too small from the ramp/deck, needed two cuts"; "no cutting below belly height, no chopping a hole down to the
## ground"; "a cut opening can be filled back in"; "halfway up the ramp measure from the feet too").
##
## The rules (user 2026-09-30: "no rules, users can cut anywhere to their hearts' content"; they were belly height up, then
## top down):
##   * a cut takes the piece of stakes where the axe is (the crosshair's height on the wall), two stakes wide (a quarter of
##     the 3 m section, 0.75 m) and PIECE_H (1.0 m) tall, at any height down to the ground and in any order (span_at);
##   * a piece that would leave less than TOP_SNAP of stake over or under it takes that too: near the points the top comes
##     off, points and all; near the ground it goes down to the foot;
##   * WORK strokes of the felling axe cut a piece (GatherTools: aim at a built palisade within REACH, "Chop through the
##     palisade", the same feel as the old chop); the palisade gate is a builder piece with its own doors and is not cut.
## A cut opening is a hole [k, h0, h1, covered] of its BuiltPiece (`cuts`; k the pair of stakes 0..3 along the section,
## h0 / h1 the heights over the section's origin, covered 0 / 1): the stakes of the pair are shown as the pieces above
## and below it (StructureGeometry.palisade_log_piece), the collider is rebuilt as boxes round it (shots, aim rays and the
## player pass an open hole), the holes are saved with the piece (SaveParts.save_building). Build mode closes a hole
## again (BuildMode: repair, the stakes stand as they were; cover, horizontal logs across it, the collider closes and the
## cut stakes stay cut; chopping into a cover knocks it out). Everything works on BuiltPiece / BuildWorld and needs no node.

const WORK := 8.0                    ## strokes of power 1 to cut a piece
const BELLY := 1.0                   ## (no longer a rule: user 2026-09-30, cut anywhere) kept for callers
const FOOT := -0.15                  ## the stakes' foot (mesh space) over the section's origin: a cut can go down to it
const PIECE_H := 1.0                 ## a piece's height
const STAKES_PER_CUT := 2            ## a piece is this many stakes wide
const TOP := 3.95                    ## the stakes' points over the section's origin on level ground
const TOP_SNAP := 0.4                ## a piece whose top would come this close to the points takes the top off
const TOP_OVER := 0.5                ## ... up to this far over them
const MIN_LEFT := 0.2                ## a base this close to the points (or over them) has nothing left to cut
const BOX_TOP := 3.95                ## the collider's top over the section's lowest ground: the stakes' points (it was
                                     ## 3.4, and shots went through the top of the wall, user 2026-09-30)
const THICK := 0.4                   ## the collider's depth
const REACH := 1.5                   ## the aim's point at most this far from the chest (horizontally)
const AIM_PAST := 0.6                ## the camera's aim ray reaches this far past REACH from the chest (a third-person
                                     ## camera stands metres behind the chest)
const CHEST := 1.3                   ## the chest over the feet
const BELOW_SLACK := 0.2             ## an aim this far under the base still counts (the crosshair is not a needle)
const COVER_LOG_R := 0.1             ## the cover's horizontal logs
const NAME := "palisade"
const NO_TRAVERSE := {"no_traverse": true}

static var _piece_meshes := {}


## Drops the cached meshes (BuildWorld._exit_tree, with BuildGeometry's).
static func release() -> void:
	_piece_meshes.clear()


# --- Geometry of the cuts ----------------------------------------------------------------------------------

@warning_ignore("integer_division")
static func pairs() -> int:
	return BuildGeometry.STAKES / STAKES_PER_CUT


## The x range of pair k in the section's frame.
static func x_range(k: int) -> Vector2:
	var w := BuildGeometry.L / float(pairs())
	return Vector2(-BuildGeometry.L * 0.5 + k * w, -BuildGeometry.L * 0.5 + (k + 1) * w)


## The pair a stake belongs to.
@warning_ignore("integer_division")
static func pair_of(stake: int) -> int:
	return stake / STAKES_PER_CUT


## The removed height spans of pair k (over the section's origin; sorted, merged): [[h0, h1], ...]. `visual`: with the
## covered ones (the stakes cut there stay cut under the cover); the collider leaves those solid.
static func removed(cuts: Array, k: int, visual := true) -> Array:
	var spans := []
	for c: Array in cuts:
		if int(c[0]) != k or (int(c[3]) != 0 and not visual):
			continue
		spans.append([float(c[1]), float(c[2])])
	spans.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out := []
	for sp: Array in spans:
		if not out.is_empty() and float(sp[0]) <= float(out[out.size() - 1][1]) + 0.001:
			out[out.size() - 1][1] = maxf(float(out[out.size() - 1][1]), float(sp[1]))
		else:
			out.append([float(sp[0]), float(sp[1])])
	return out


## What is left of [y0, y1] after taking `spans` out: [[a, b], ...].
static func solid_spans(y0: float, y1: float, spans: Array) -> Array:
	var solid := [[y0, y1]]
	for sp: Array in spans:
		var nxt := []
		for so: Array in solid:
			if float(sp[1]) <= float(so[0]) or float(sp[0]) >= float(so[1]):
				nxt.append(so)
				continue
			if float(sp[0]) > float(so[0]):
				nxt.append([float(so[0]), float(sp[0])])
			if float(sp[1]) < float(so[1]):
				nxt.append([float(sp[1]), float(so[1])])
		solid = nxt
	return solid


## The span a cut of pair k takes when the axe is at height `y` (over the section's origin): a piece PIECE_H tall round
## that height, inside the standing part of the stakes there (user 2026-09-30: "no rules, users can cut anywhere to their
## hearts' content": any height, down to the ground, in any order). A piece that would leave less than TOP_SNAP of stake
## above or below it takes that too (near the points: the points with it; near the ground: down to the foot). [] when the
## stakes are not there.
static func span_at(cuts: Array, k: int, y: float) -> Array:
	var part: Array = []
	for so: Array in solid_spans(FOOT, TOP + TOP_OVER, removed(cuts, k)):
		if y >= float(so[0]) - 0.02 and y <= float(so[1]) + 0.02 and float(so[1]) - float(so[0]) >= 0.02:
			part = so
	if part.is_empty() or float(part[0]) > TOP - MIN_LEFT:
		return []
	var lo := float(part[0])
	var hi := minf(float(part[1]), TOP)
	var y0 := clampf(y - PIECE_H * 0.5, lo, maxf(lo, hi - PIECE_H))
	var y1 := minf(y0 + PIECE_H, hi)
	if y0 - lo < TOP_SNAP:
		y0 = lo
	if hi - y1 < TOP_SNAP:
		y1 = float(part[1]) if float(part[1]) < TOP else TOP + TOP_OVER
	return [y0, y1]


## The pair's span [h0, h1] is already open over its whole height (`visual`: a covered hole counts as open, its stakes are cut).
static func is_open(cuts: Array, k: int, h0: float, h1: float, visual := true) -> bool:
	for sp: Array in removed(cuts, k, visual):
		if float(sp[0]) <= h0 + 0.02 and float(sp[1]) >= h1 - 0.02:
			return true
	return false


# --- Colliders and visuals ------------------------------------------------------------------------------------

## The piece's colliders with its holes: [[Shape3D, Transform3D, meta]] like BuildGeometry.colliders; the columns of stakes
## without a hole are one box, a column with holes has the solid spans round them.
static func colliders(ctx: Dictionary, cuts: Array) -> Array:
	var g: Array = ctx.get("gy", [0.0, 0.0])
	var lo := minf(float(g[0]), float(g[1]))
	var gmin := float(ctx.get("gmin", lo))
	var y0 := gmin - BuildGeometry.STAKE_SINK
	var y1 := gmin + BOX_TOP
	var out: Array = []
	var k := 0
	while k < pairs():
		var rem := removed(cuts, k, false)
		if rem.is_empty():
			var k2 := k
			while k2 + 1 < pairs() and removed(cuts, k2 + 1, false).is_empty():
				k2 += 1
			out.append(_box(x_range(k).x, x_range(k2).y, y0, y1))
			k = k2 + 1
			continue
		var xr := x_range(k)
		for so: Array in solid_spans(y0, y1, rem):
			if float(so[1]) - float(so[0]) >= 0.01:
				out.append(_box(xr.x, xr.y, float(so[0]), float(so[1])))
		k += 1
	return out


static func _box(x0: float, x1: float, y0: float, y1: float) -> Array:
	var b := BoxShape3D.new()
	b.size = Vector3(x1 - x0, y1 - y0, THICK)
	return [b, Transform3D(Basis(), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0)), {"trav": NO_TRAVERSE}]


## A stake with holes, as pieces: `s` is [variant, Transform3D, custom Color] (BuildGeometry.stake_transforms), `spans` the
## removed heights over the section's origin. The pieces are one-instance MultiMeshes under `parent` with the stake's own
## look; returns them.
static func stake_pieces(parent: Node3D, s: Array, spans: Array) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var t: Transform3D = s[1]
	var sy := t.basis.y.length()
	var model := []
	for sp: Array in spans:
		model.append([(float(sp[0]) - t.origin.y) / sy, (float(sp[1]) - t.origin.y) / sy])
	# (mesh space: base -0.15, apex PALISADE_H; a height h over the origin is (h - origin.y) / sy there)
	for so: Array in solid_spans(-0.15, StructureGeometry.PALISADE_H, model):
		if float(so[1]) - float(so[0]) < 0.03:
			continue
		var m := MultiMesh.new()
		m.transform_format = MultiMesh.TRANSFORM_3D
		m.use_custom_data = true
		m.mesh = _piece_mesh(int(s[0]), float(so[0]), float(so[1]))
		m.instance_count = 1
		m.set_instance_transform(0, t)
		m.set_instance_custom_data(0, s[2])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "CutStake"
		mmi.multimesh = m
		parent.add_child(mmi)
		out.append(mmi)
	return out


static func _piece_mesh(variant: int, m0: float, m1: float) -> ArrayMesh:
	var key := "%d|%d|%d" % [variant, roundi(m0 * 100.0), roundi(m1 * 100.0)]
	if not _piece_meshes.has(key):
		_piece_meshes[key] = StructureGeometry.palisade_log_piece(variant, StructureMaterials.all(), m0, m1)
	return _piece_meshes[key]


## The horizontal logs across the covered holes (bark round, hewn ends), a hand's width past the sides, in the piece's frame.
static func cover_meshes(parent: Node3D, cuts: Array, seed_of: int) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var kit := StructureMeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + seed_of * 31
	var any := false
	for c: Array in cuts:
		if int(c[3]) == 0:
			continue
		any = true
		var xr := x_range(int(c[0]))
		var top := minf(float(c[2]), TOP)
		var hgt := top - float(c[1])
		if hgt < 0.05:
			continue
		var n := maxi(2, int(ceil(hgt / (COVER_LOG_R * 2.0 * 0.95))))
		var length := xr.y - xr.x + 0.24
		for i in n:
			var y := float(c[1]) + (i + 0.5) * hgt / n
			var r := COVER_LOG_R * rng.randf_range(0.92, 1.05)
			_log_across(kit, Vector3(0.5 * (xr.x + xr.y) + rng.randf_range(-0.04, 0.04), y, 0.0), length, r, rng)
	if not any:
		return out
	var mi := MeshInstance3D.new()
	mi.name = "Cover"
	mi.mesh = kit.commit(StructureMaterials.all())
	parent.add_child(mi)
	out.append(mi)
	return out


## One round log along X (centre c, in the piece's frame): bark round, hewn ends.
static func _log_across(kit: StructureMeshKit, c: Vector3, length: float, r: float, rng: RandomNumberGenerator) -> void:
	const SEG := 10
	var ax := Vector3.RIGHT
	var u := ax.cross(Vector3.UP).normalized()
	var v := u.cross(ax).normalized()
	var a := c - ax * length * 0.5
	var b := c + ax * length * 0.5
	var rows_p := []
	var rows_n := []
	var rows_u := []
	var rows_c := []
	var ph := rng.randf() * TAU
	for e: Vector3 in [a, b]:
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		var U := PackedVector2Array()
		var C := PackedColorArray()
		for j in SEG + 1:
			var ang := ph + TAU * j / SEG
			var nr := u * cos(ang) + v * sin(ang)
			P.append(e + nr * r)
			N.append(nr)
			U.append(Vector2(float(j) / SEG, (e - a).length() / StructureGeometry.BARK_TILE))
			C.append(Color(1, 1, 1, 0.9))
		rows_p.append(P)
		rows_n.append(N)
		rows_u.append(U)
		rows_c.append(C)
	kit.grid(&"bark_mm", rows_p, rows_n, rows_u, rows_c)
	for e2: Array in [[a, -ax], [b, ax]]:
		var e: Vector3 = e2[0]
		for j in SEG:
			var a0 := ph + TAU * j / SEG
			var a1 := ph + TAU * (j + 1) / SEG
			var p0 := e + (u * cos(a0) + v * sin(a0)) * r
			var p1 := e + (u * cos(a1) + v * sin(a1)) * r
			kit.tri(&"hewn_mm", p0, p1, e, Vector2(cos(a0), sin(a0)) * 0.2 + Vector2(0.5, 0.5),
					Vector2(cos(a1), sin(a1)) * 0.2 + Vector2(0.5, 0.5), Vector2(0.5, 0.5), Color(1, 1, 1, 1), StructureMeshKit.KIND_TEX, 0.0, e2[1])


# --- The axe: what is aimed at, the strokes ----------------------------------------------------------------

## The built palisade section a collider belongs to (null for anything else, the gate too).
static func section_of(collider: Variant) -> BuiltPiece:
	var p := BuildMode.piece_of(collider)
	return p if p != null and p.type == "palisade" else null


## The distance along the ray to the first thing it hits (`reach` when nothing).
static func _first_hit(world: BuildWorld, eye: Vector3, look: Vector3, reach: float, exclude: Array[RID]) -> float:
	var q := PhysicsRayQueryParameters3D.create(eye, eye + look * reach)
	q.exclude = exclude
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	return eye.distance_to(hit.position) if not hit.is_empty() else reach


## The piece the camera's aim (from `eye` along `look`) points at on a built palisade within REACH of the player standing
## at `feet`: {} or the gathering candidate {type "wall", src, key, piece, k, h0, h1, i, pos, point, normal, radius, dist,
## name}. The wall is a plane through the section's stakes (its collider stops at BOX_TOP, the stakes' points go higher: from
## the firing step the crosshair is over the collider), and a solid thing nearer the eye than the wall blocks the aim.
## Nothing under belly height (the feet's + BELLY) is a target, nor open air, nor a piece that is open already.
static func aim(world: BuildWorld, eye: Vector3, look: Vector3, feet: Vector3, exclude: Array[RID] = []) -> Dictionary:
	if world == null or not world.is_inside_tree():
		return {}
	look = look.normalized()
	var chest := feet + Vector3.UP * CHEST
	var reach := eye.distance_to(chest) + REACH + AIM_PAST
	var d_hit := _first_hit(world, eye, look, reach, exclude)
	var best := {}
	var best_t := INF
	for p: BuiltPiece in world.near(chest, 8.0):
		if p.type != "palisade":
			continue
		var inv := p.global_transform.affine_inverse()
		var o := inv * eye
		var d := inv.basis * look
		if absf(d.z) < 0.05:
			continue
		var t := -o.z / d.z
		if t <= 0.0 or t > d_hit + THICK * 0.5 + 0.05 or t >= best_t:
			continue
		var loc := o + d * t
		if absf(loc.x) > BuildGeometry.L * 0.5 or loc.y > TOP or loc.y < FOOT:
			continue
		var k := clampi(int(floor((loc.x + BuildGeometry.L * 0.5) / (BuildGeometry.L / float(pairs())))), 0, pairs() - 1)
		# (open air where a hole is cut: the stakes are not there to be aimed at)
		var open := false
		for sp: Array in removed(p.cuts, k, false):
			if loc.y > float(sp[0]) and loc.y < float(sp[1]):
				open = true
		if open:
			continue
		var wp := p.global_transform * loc
		if Vector2(wp.x - chest.x, wp.z - chest.z).length() > REACH:
			continue
		best = {"piece": p, "k": k, "y": loc.y, "dist": Vector2(wp.x - chest.x, wp.z - chest.z).length()}
		best_t = t
	if best.is_empty():
		return {}
	var bp: BuiltPiece = best.piece
	# a cover over a hole: the axe is at the logs across it (chopping into them knocks them out: the hole's own span)
	var span := []
	for c: Array in bp.cuts:
		if int(c[0]) == int(best.k) and int(c[3]) != 0 and float(best.y) >= float(c[1]) and float(best.y) <= float(c[2]):
			span = [float(c[1]), float(c[2])]
	if span.is_empty():
		span = span_at(bp.cuts, int(best.k), float(best.y))
	if span.is_empty():
		return {}
	return _candidate(bp, int(best.k), float(span[0]), float(span[1]), chest, float(best.dist))


## The first cut's base over the section's origin for a player standing at `feet` (world).
static func belly_of(p: BuiltPiece, feet: Vector3) -> float:
	return feet.y + BELLY - p.global_position.y


## The candidate `key` again (a piece cut meanwhile, taken down: {}).
static func describe(world: BuildWorld, key: String, feet: Vector3) -> Dictionary:
	var parts := key.split(":")
	if world == null or parts.size() != 4:
		return {}
	var p := world.by_id(int(parts[0]))
	if p == null or p.type != "palisade":
		return {}
	var k := int(parts[1])
	var h0 := float(parts[2]) / 100.0
	var h1 := float(parts[3]) / 100.0
	if k < 0 or k >= pairs() or is_open(p.cuts, k, h0, h1, false):
		return {}
	var chest := feet + Vector3.UP * CHEST
	var c := _candidate(p, k, h0, h1, chest, 0.0)
	c.dist = Vector2((c.pos as Vector3).x - chest.x, (c.pos as Vector3).z - chest.z).length()
	return c


static func _candidate(p: BuiltPiece, k: int, h0: float, h1: float, chest: Vector3, dist: float) -> Dictionary:
	var xf := p.global_transform
	var xr := x_range(k)
	var top := minf(h1, TOP)
	var face_side := signf((xf.affine_inverse() * chest).z)
	if face_side == 0.0:
		face_side = 1.0
	var face := xf * Vector3(0.5 * (xr.x + xr.y), 0.5 * (h0 + top), face_side * THICK * 0.5)
	var out := xf.basis.z.normalized() * face_side
	return {"type": "wall", "src": "wall", "key": "%d:%d:%d:%d" % [p.piece_id, k, roundi(h0 * 100.0), roundi(h1 * 100.0)],
			"piece": p.piece_id, "k": k, "h0": h0, "h1": h1, "i": p.piece_id * 10 + k, "pos": face, "point": face, "normal": out,
			"radius": 0.0, "dist": dist, "name": NAME}


## One stroke of `power` at a candidate: the work done so far over the work it takes (1: the piece is out).
static func strike(world: BuildWorld, c: Dictionary, power: float) -> float:
	var key := str(c.key)
	world.cut_work[key] = float(world.cut_work.get(key, 0.0)) + power
	if float(world.cut_work[key]) >= WORK:
		world.cut_work.erase(key)
		cut(world, int(c.piece), int(c.k), float(c.h0), float(c.h1))
		return 1.0
	return float(world.cut_work[key]) / WORK


static func progress(world: BuildWorld, key: String) -> float:
	return clampf(float(world.cut_work.get(key, 0.0)) / WORK, 0.0, 0.99) if world else 0.0


## Cuts pair k of section `piece_id` between h0 and h1 (over the section's origin). Chopping into a cover knocks it out (the
## hole under it is open again, no second hole). False when it is open already or the piece is gone.
static func cut(world: BuildWorld, piece_id: int, k: int, h0: float, h1: float) -> bool:
	var p := world.by_id(piece_id) if world else null
	if p == null or p.type != "palisade" or k < 0 or k >= pairs():
		return false
	var cuts := p.cuts.duplicate(true)
	var knocked := false
	for c: Array in cuts:
		if int(c[0]) == k and int(c[3]) != 0 and float(c[1]) < h1 - 0.01 and h0 < float(c[2]) - 0.01:
			c[3] = 0
			knocked = true
	if not knocked:
		if is_open(p.cuts, k, h0, h1):
			return false
		cuts.append([k, h0, h1, 0])
	p.set_cuts(cuts)
	return true


# --- Closing an opening again (build mode) --------------------------------------------------------------------

## The opening the aim (from `eye` along `look`) passes through on a built palisade within reach of the player at `feet`, for
## closing it: kind "repair" or "cover". {ok, reason, piece, k, h0, h1, hole, xf (its middle, X along the wall, Z toward the
## viewer), size, kind}; ok false with the reason when it cannot be done.
static func opening_at(world: BuildWorld, eye: Vector3, look: Vector3, feet: Vector3, kind: String, exclude: Array[RID] = []) -> Dictionary:
	var none := {"ok": false, "reason": "Look into an opening cut in the palisade"}
	if world == null or not world.is_inside_tree():
		return none
	look = look.normalized()
	var chest := feet + Vector3.UP * CHEST
	var reach := eye.distance_to(chest) + REACH + AIM_PAST
	var q := PhysicsRayQueryParameters3D.create(eye, eye + look * reach)
	q.exclude = exclude
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	var d_hit := eye.distance_to(hit.position) if not hit.is_empty() else reach
	var best := {}
	var best_t := INF
	for p: BuiltPiece in world.near(chest, 8.0):
		if p.type != "palisade" or p.cuts.is_empty():
			continue
		var inv := p.global_transform.affine_inverse()
		var o := inv * eye
		var d := inv.basis * look
		if absf(d.z) < 0.05:
			continue
		var t := -o.z / d.z
		if t <= 0.0 or t > d_hit + THICK * 0.5 + 0.05 or t >= best_t:
			continue
		var pt := o + d * t
		var wp := p.global_transform * pt
		if Vector2(wp.x - chest.x, wp.z - chest.z).length() > REACH + 0.5:
			continue
		for hi in p.cuts.size():
			var c: Array = p.cuts[hi]
			var xr := x_range(int(c[0]))
			if pt.x >= xr.x - 0.02 and pt.x <= xr.y + 0.02 and pt.y >= float(c[1]) - 0.02 and pt.y <= minf(float(c[2]), TOP) + 0.02:
				best = {"piece": p, "hole": hi, "eye_z": o.z}
				best_t = t
				break
	if best.is_empty():
		return none
	var bp: BuiltPiece = best.piece
	var c: Array = bp.cuts[int(best.hole)]
	if kind == "cover" and int(c[3]) != 0:
		return {"ok": false, "reason": "Logs cover it already"}
	var xr := x_range(int(c[0]))
	var top := minf(float(c[2]), TOP)
	var turn := Basis() if float(best.eye_z) >= 0.0 else Basis(Vector3.UP, PI)
	var xf := bp.global_transform * Transform3D(turn, Vector3(0.5 * (xr.x + xr.y), 0.5 * (float(c[1]) + top), 0.0))
	return {"ok": true, "reason": "", "piece": bp.piece_id, "k": int(c[0]), "h0": float(c[1]), "h1": float(c[2]), "hole": int(best.hole),
			"xf": xf, "size": Vector3(xr.y - xr.x, top - float(c[1]), THICK), "kind": kind}


static func _find(p: BuiltPiece, k: int, h0: float, h1: float) -> int:
	for i in p.cuts.size():
		var c: Array = p.cuts[i]
		if int(c[0]) == k and absf(float(c[1]) - h0) < 0.01 and absf(float(c[2]) - h1) < 0.01:
			return i
	return -1


## Repairs an opening (opening_at's): the stakes stand there again.
static func repair(world: BuildWorld, op: Dictionary) -> bool:
	var p := world.by_id(int(op.piece)) if world else null
	if p == null:
		return false
	var i := _find(p, int(op.k), float(op.h0), float(op.h1))
	if i < 0:
		return false
	var cuts := p.cuts.duplicate(true)
	cuts.remove_at(i)
	p.set_cuts(cuts)
	return true


## Covers an opening with horizontal logs: the collider closes, the cut stakes stay cut under the cover.
static func cover(world: BuildWorld, op: Dictionary) -> bool:
	var p := world.by_id(int(op.piece)) if world else null
	if p == null:
		return false
	var i := _find(p, int(op.k), float(op.h0), float(op.h1))
	if i < 0:
		return false
	var cuts := p.cuts.duplicate(true)
	(cuts[i] as Array)[3] = 1
	p.set_cuts(cuts)
	return true


## The holes as plain data for a save ([[k, h0, h1, covered]]) and back.
static func to_save(cuts: Array) -> Array:
	var out := []
	for c: Array in cuts:
		out.append([int(c[0]), snappedf(float(c[1]), 0.001), snappedf(float(c[2]), 0.001), int(c[3])])
	return out


static func from_save(d: Variant) -> Array:
	var out := []
	if d is Array:
		for c in d:
			if c is Array and (c as Array).size() >= 4 and int(c[0]) >= 0 and int(c[0]) < pairs():
				out.append([int(c[0]), float(c[1]), float(c[2]), int(c[3])])
	return out
