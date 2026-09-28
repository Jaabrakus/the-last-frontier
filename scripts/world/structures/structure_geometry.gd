class_name StructureGeometry
extends RefCounted
## Procedural meshes for the fort and the range (look-dev spec, section 8.3). Visual only: every
## collider is made by FrontierStructures, and every shape here stays on or within a few
## centimetres of the collider it dresses (log faces, deck boards, crate battens), except where
## FrontierStructures adds a documented collider (chimney, cabin log ends, walkway posts, props).
##
## All builders add to a StructureMeshKit (material keys, see StructureMaterials) and take an
## RNG for their visual variation, so the fort looks the same on every run. Units are metres.

const K := preload("res://scripts/world/structures/structure_mesh_kit.gd")

const BARK_TILE := 1.25      ## metres per bark_palisade tile
const SHINGLE_TILE := 2.8    ## metres per shingles_riven tile (8 courses of 0.35 m)
const STONE_TILE := 1.6      ## metres per fieldstone tile
const STRAW_TILE := 0.6      ## metres per straw_fibre tile

const PALISADE_H := 4.2      ## mesh height of a palisade log (instances scale y by h / 4.2)


# --- Palisade -------------------------------------------------------------------------------

## One palisade log, base at y = -0.15 (sunk into the ground), sharpened to a point at y = 4.2.
## Local +X runs along the wall (the neighbours), so vertex AO darkens the sides that face the
## next logs. Surfaces: bark_mm (bark), hewn_mm (axe-hewn facets of the point).
## variant 0/2: four facets, 1: three facets; slightly different taper, wobble and tip length.
static func palisade_log(variant: int, materials: Dictionary) -> ArrayMesh:
	var kit := K.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1777 + variant * 31
	const SEG := 12
	var facets := 3 if variant == 1 else 4
	var tip_len := 0.44 + 0.06 * variant
	var phase := rng.randf_range(0.0, TAU)
	var ys := [-0.15, 0.08, 0.55, 1.5, 2.45, 3.2]
	var rows_p := []
	var rows_n := []
	var rows_uv := []
	var rows_c := []
	var centre := Vector3.ZERO
	var r_last := 0.2
	for i in ys.size():
		var y: float = ys[i]
		var r := 0.212 - 0.01 * (y / PALISADE_H) + rng.randf_range(-0.004, 0.004)
		if i > 1:
			centre += Vector3(rng.randf_range(-0.004, 0.004), 0.0, rng.randf_range(-0.004, 0.004))
		r_last = r
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		var U := PackedVector2Array()
		var C := PackedColorArray()
		for j in SEG + 1:
			var a := phase + TAU * j / SEG
			var n := Vector3(cos(a), 0.0, sin(a))
			P.append(centre + n * r + Vector3(0, y, 0))
			N.append(n)
			U.append(Vector2(float(j) / SEG, y / BARK_TILE))
			C.append(Color(1, 1, 1, _log_ao(n, y)))
		rows_p.append(P)
		rows_n.append(N)
		rows_uv.append(U)
		rows_c.append(C)
	# Scallop ring where the axe facets meet the bark (planar facets through the apex).
	var apex := centre + Vector3(rng.randf_range(-0.015, 0.015), PALISADE_H, rng.randf_range(-0.015, 0.015))
	var r_top := r_last - 0.002
	var fa := TAU / facets
	var P2 := PackedVector3Array()
	var N2 := PackedVector3Array()
	var U2 := PackedVector2Array()
	var C2 := PackedColorArray()
	var ring: Array[Vector3] = []
	for j in SEG + 1:
		var a := phase + TAU * j / SEG
		var rel := fposmod(a - phase, fa) - fa * 0.5          # angle from the facet centre
		var n := Vector3(cos(a), 0.0, sin(a))
		var p := Vector3(apex.x, 0.0, apex.z) + n * r_top
		p.y = PALISADE_H - tip_len * cos(rel)
		ring.append(p)
		P2.append(p)
		N2.append(n)
		U2.append(Vector2(float(j) / SEG, p.y / BARK_TILE))
		C2.append(Color(1, 1, 1, _log_ao(n, p.y)))
	rows_p.append(P2)
	rows_n.append(N2)
	rows_uv.append(U2)
	rows_c.append(C2)
	kit.grid(&"bark_mm", rows_p, rows_n, rows_uv, rows_c)
	# Facets: SEG / facets segments each (ridges on ring vertices j = f * per), one flat
	# normal per facet; every ring point of facet f lies on its plane through the apex.
	var per := SEG / facets
	var k := tip_len / r_top
	for f in facets:
		var dir_a := phase + fa * (f + 0.5)
		var d := Vector3(cos(dir_a), 0.0, sin(dir_a))
		var t := Vector3(-d.z, 0.0, d.x)
		var nf := Vector3(k * d.x, 1.0, k * d.z).normalized()
		var row := (variant + f) % 4
		for s in per:
			var j := f * per + s
			var pa: Vector3 = ring[j]
			var pb: Vector3 = ring[j + 1]
			var ua := Vector2((PALISADE_H - pa.y) * 1.3, K.row_v(row, 0.5 + (pa - apex).dot(t) / (2.2 * r_top)))
			var ub := Vector2((PALISADE_H - pb.y) * 1.3, K.row_v(row, 0.5 + (pb - apex).dot(t) / (2.2 * r_top)))
			var uc := Vector2(0.0, K.row_v(row, 0.5))
			# Counter-clockwise seen from outside: ring j+1, ring j, apex.
			kit.tri(&"hewn_mm", pb, pa, apex, ub, ua, uc, Color(1, 1, 1, 0.95), K.KIND_TEX, 0.0, nf)
	return kit.commit(materials)


## A piece of palisade log `variant` (the same log as palisade_log: its rng draws are the same), the part between
## local heights y_lo and y_hi (mesh space: base -0.15, apex PALISADE_H): a window chopped through the wall
## (WallCuts) leaves the log below the sill and above the lintel. A cut end is a flat axe-hewn face (hewn_mm);
## a piece whose y_hi reaches the point keeps it. y_hi at most the lowest point of the tip's scallop ring.
static func palisade_log_piece(variant: int, materials: Dictionary, y_lo: float, y_hi: float) -> ArrayMesh:
	var kit := K.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1777 + variant * 31
	const SEG := 12
	var facets := 3 if variant == 1 else 4
	var tip_len := 0.44 + 0.06 * variant
	var phase := rng.randf_range(0.0, TAU)
	var ys := [-0.15, 0.08, 0.55, 1.5, 2.45, 3.2]
	# The rows as palisade_log draws them (radius, centre), then clipped to [y_lo, y_hi].
	var rows: Array = []
	var centre := Vector3.ZERO
	var r_last := 0.2
	for i in ys.size():
		var y: float = ys[i]
		var r := 0.212 - 0.01 * (y / PALISADE_H) + rng.randf_range(-0.004, 0.004)
		if i > 1:
			centre += Vector3(rng.randf_range(-0.004, 0.004), 0.0, rng.randf_range(-0.004, 0.004))
		r_last = r
		rows.append([y, r, centre])
	var apex := centre + Vector3(rng.randf_range(-0.015, 0.015), PALISADE_H, rng.randf_range(-0.015, 0.015))
	var tip := y_hi >= PALISADE_H
	var ring_lo := PALISADE_H - tip_len
	var y_top := ring_lo if tip else minf(y_hi, ring_lo)
	var at := func(y: float) -> Array:
		# radius and centre at height y (linear between the rows, the last row's above it)
		for i in range(1, rows.size()):
			if y <= float(rows[i][0]):
				var f := (y - float(rows[i - 1][0])) / (float(rows[i][0]) - float(rows[i - 1][0]))
				return [y, lerpf(float(rows[i - 1][1]), float(rows[i][1]), f), (rows[i - 1][2] as Vector3).lerp(rows[i][2], f)]
		var last: Array = rows[rows.size() - 1]
		return [y, float(last[1]), last[2]]
	var cut: Array = [at.call(maxf(y_lo, -0.15))]
	for rw: Array in rows:
		if float(rw[0]) > maxf(y_lo, -0.15) + 0.01 and float(rw[0]) < y_top - 0.01:
			cut.append(rw)
	cut.append(at.call(y_top))
	var rows_p := []
	var rows_n := []
	var rows_uv := []
	var rows_c := []
	for rw: Array in cut:
		var y: float = rw[0]
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		var U := PackedVector2Array()
		var C := PackedColorArray()
		for j in SEG + 1:
			var a := phase + TAU * j / SEG
			var n := Vector3(cos(a), 0.0, sin(a))
			P.append((rw[2] as Vector3) + n * float(rw[1]) + Vector3(0, y, 0))
			N.append(n)
			U.append(Vector2(float(j) / SEG, y / BARK_TILE))
			C.append(Color(1, 1, 1, _log_ao(n, y)))
		rows_p.append(P)
		rows_n.append(N)
		rows_uv.append(U)
		rows_c.append(C)
	var fa := TAU / facets
	var ring: Array[Vector3] = []
	var r_top := r_last - 0.002
	if tip:
		# The scallop ring and the facets through the apex, as palisade_log.
		var P2 := PackedVector3Array()
		var N2 := PackedVector3Array()
		var U2 := PackedVector2Array()
		var C2 := PackedColorArray()
		for j in SEG + 1:
			var a := phase + TAU * j / SEG
			var rel := fposmod(a - phase, fa) - fa * 0.5
			var n := Vector3(cos(a), 0.0, sin(a))
			var p := Vector3(apex.x, 0.0, apex.z) + n * r_top
			p.y = PALISADE_H - tip_len * cos(rel)
			ring.append(p)
			P2.append(p)
			N2.append(n)
			U2.append(Vector2(float(j) / SEG, p.y / BARK_TILE))
			C2.append(Color(1, 1, 1, _log_ao(n, p.y)))
		rows_p.append(P2)
		rows_n.append(N2)
		rows_uv.append(U2)
		rows_c.append(C2)
	kit.grid(&"bark_mm", rows_p, rows_n, rows_uv, rows_c)
	if tip:
		var per := SEG / facets
		var k := tip_len / r_top
		for f in facets:
			var dir_a := phase + fa * (f + 0.5)
			var d := Vector3(cos(dir_a), 0.0, sin(dir_a))
			var t := Vector3(-d.z, 0.0, d.x)
			var nf := Vector3(k * d.x, 1.0, k * d.z).normalized()
			var row := (variant + f) % 4
			for s in per:
				var j := f * per + s
				var pa: Vector3 = ring[j]
				var pb: Vector3 = ring[j + 1]
				var ua := Vector2((PALISADE_H - pa.y) * 1.3, K.row_v(row, 0.5 + (pa - apex).dot(t) / (2.2 * r_top)))
				var ub := Vector2((PALISADE_H - pb.y) * 1.3, K.row_v(row, 0.5 + (pb - apex).dot(t) / (2.2 * r_top)))
				var uc := Vector2(0.0, K.row_v(row, 0.5))
				kit.tri(&"hewn_mm", pb, pa, apex, ub, ua, uc, Color(1, 1, 1, 0.95), K.KIND_TEX, 0.0, nf)
	# The axe-hewn cut faces (flat, fresh wood).
	var caps: Array = []
	if y_lo > -0.15 + 0.01:
		caps.append([cut[0], Vector3.DOWN])
	if not tip:
		caps.append([cut[cut.size() - 1], Vector3.UP])
	for cp: Array in caps:
		var rw: Array = cp[0]
		var nrm: Vector3 = cp[1]
		var c0: Vector3 = (rw[2] as Vector3) + Vector3(0, float(rw[0]), 0)
		for j in SEG:
			var a0 := phase + TAU * j / SEG
			var a1 := phase + TAU * (j + 1) / SEG
			var p0 := c0 + Vector3(cos(a0), 0.0, sin(a0)) * float(rw[1])
			var p1 := c0 + Vector3(cos(a1), 0.0, sin(a1)) * float(rw[1])
			kit.tri(&"hewn_mm", p0, p1, c0, Vector2(cos(a0), sin(a0)) * 0.2 + Vector2(0.5, 0.5),
					Vector2(cos(a1), sin(a1)) * 0.2 + Vector2(0.5, 0.5), Vector2(0.5, 0.5), Color(1, 1, 1, 1.0), K.KIND_TEX, 0.0, nrm)
	return kit.commit(materials)


static func _log_ao(n: Vector3, y: float) -> float:
	var side := 1.0 - 0.5 * n.x * n.x          # neighbours along local X
	var ground := lerpf(0.55, 1.0, clampf((y + 0.05) / 0.45, 0.0, 1.0))
	return side * ground


# --- Hewn square-log walls --------------------------------------------------------------------

## Hewn square-log courses on one face of a box. `c` is the centre of the face at the collider
## surface (its y is ignored), `out` the outward unit normal, `w` the face width. `bounds` are
## the course boundaries (absolute y). Every other course shows the end grain of the crossing
## log at both corners (dovetail corners; `parity` alternates it between adjacent faces).
## Chinking (clay) sits recessed between courses; chamfered edges catch the edge wear.
static func hewn_face(kit: K, c: Vector3, out: Vector3, w: float, bounds: PackedFloat32Array,
		rng: RandomNumberGenerator, parity: int, end_len := 0.28, ground_ao := true) -> void:
	var up := Vector3.UP
	var along := up.cross(out)
	var o0 := Vector3(c.x, 0.0, c.z) - along * (w * 0.5)
	var cg := 0.014
	var ch := 0.026
	for k in bounds.size() - 1:
		var ya: float = bounds[k]
		var yb: float = bounds[k + 1]
		var o := rng.randf_range(0.004, 0.02)
		var row := rng.randi_range(0, 3)
		var u0 := rng.randf()
		var tint := rng.randf_range(0.86, 1.08)
		var col := Color(tint * rng.randf_range(0.98, 1.03), tint, tint * rng.randf_range(0.96, 1.01), 1.0)
		var ao_lo := 0.72 if (k == 0 and ground_ao) else 0.8
		# Profile (y, depth) bottom -> top.
		var prof := [Vector2(ya, -0.03), Vector2(ya + cg, -0.03), Vector2(ya + cg + ch, o), Vector2(yb - ch, o), Vector2(yb, -0.03)]
		var fy0 := ya + cg + ch
		var fy1 := yb - ch
		var segs := [[0.0, end_len], [end_len, w - end_len], [w - end_len, w]]
		for si in 3:
			var s0: float = segs[si][0]
			var s1: float = segs[si][1]
			var end_grain := si != 1 and (k + parity) % 2 == 0
			for pi in 4:
				var pa: Vector2 = prof[pi]
				var pb: Vector2 = prof[pi + 1]
				var a := o0 + along * s0 + up * pa.x + out * pa.y
				var b := o0 + along * s1 + up * pa.x + out * pa.y
				var cc := o0 + along * s1 + up * pb.x + out * pb.y
				var d := o0 + along * s0 + up * pb.x + out * pb.y
				var kind := K.KIND_TEX
				var edge := 0.0
				var ua: Vector2
				var ub: Vector2
				var uc: Vector2
				var ud: Vector2
				var ao_a := 1.0
				var ao_b := 1.0
				if pi == 0:
					kind = K.KIND_CLAY
					ao_a = 0.55
					ao_b = 0.6
				elif pi == 2 and end_grain:
					kind = K.KIND_ENDGRAIN
					var mid := (s0 + s1) * 0.5
					var my := (fy0 + fy1) * 0.5
					ua = Vector2(s0 - mid, pa.x - my)
					ub = Vector2(s1 - mid, pa.x - my)
					uc = Vector2(s1 - mid, pb.x - my)
					ud = Vector2(s0 - mid, pb.x - my)
				else:
					if pi != 2:
						edge = 1.0
					var fa := clampf((pa.x - fy0) / (fy1 - fy0), -0.08, 1.08)
					var fb := clampf((pb.x - fy0) / (fy1 - fy0), -0.08, 1.08)
					ua = Vector2(s0 + u0, K.row_v(row, fa))
					ub = Vector2(s1 + u0, K.row_v(row, fa))
					uc = Vector2(s1 + u0, K.row_v(row, fb))
					ud = Vector2(s0 + u0, K.row_v(row, fb))
				if pi == 1:
					ao_a = 0.62
					ao_b = 0.9
				elif pi == 2:
					ao_a = ao_lo if k == 0 else 0.95
					ao_b = 1.0
				elif pi == 3:
					ao_a = 1.0
					ao_b = 0.7
				var cols := PackedColorArray([Color(col, ao_a), Color(col, ao_a), Color(col, ao_b), Color(col, ao_b)])
				if kind == K.KIND_CLAY:
					cols = PackedColorArray([Color(1, 1, 1, ao_a), Color(1, 1, 1, ao_a), Color(1, 1, 1, ao_b), Color(1, 1, 1, ao_b)])
				kit.quad(&"boards", a, b, cc, d, ua, ub, uc, ud, col, kind, edge, cols)


## All four faces of a box as hewn-log walls, plus a dark backing box (inset 3.5 cm) that closes
## the corners. `skip_faces`: faces to leave out ("+x", "-x", "+z", "-z").
static func hewn_box(kit: K, center: Vector3, size: Vector3, courses: int, rng: RandomNumberGenerator,
		skip_faces := PackedStringArray(), ground_ao := true) -> void:
	var y0 := center.y - size.y * 0.5
	var y1 := center.y + size.y * 0.5
	var bounds := PackedFloat32Array()
	for k in courses + 1:
		bounds.append(lerpf(y0, y1, float(k) / courses))
	var faces := [["+x", Vector3.RIGHT, size.z], ["-x", Vector3.LEFT, size.z], ["+z", Vector3.BACK, size.x], ["-z", Vector3.FORWARD, size.x]]
	for i in faces.size():
		var f: Array = faces[i]
		if String(f[0]) in skip_faces:
			continue
		var out: Vector3 = f[1]
		var half := size.x * 0.5 if absf(out.x) > 0.5 else size.z * 0.5
		hewn_face(kit, center + out * half, out, f[2], bounds, rng, 0 if i < 2 else 1, 0.28, ground_ao)
	kit.box(&"boards", Transform3D(Basis(), center), size - Vector3(0.07, 0.0, 0.07), K.GRAIN_X, 0, 0.0,
			Color(0.35, 0.33, 0.3, 0.4), K.KIND_TEX, 8)


# --- Round-log cabin walls ----------------------------------------------------------------------

## Round logs hewn flat on the outside (bark left on the rounded backs), clay chinking between
## them. Same face conventions as hewn_face. Bark goes to &"bark", the hewn faces to &"boards".
static func round_log_face(kit: K, c: Vector3, out: Vector3, w: float, bounds: PackedFloat32Array,
		rng: RandomNumberGenerator) -> void:
	var up := Vector3.UP
	var along := up.cross(out)
	var o0 := Vector3(c.x, 0.0, c.z) - along * (w * 0.5)
	for k in bounds.size() - 1:
		var ya: float = bounds[k]
		var yb: float = bounds[k + 1]
		var h := yb - ya
		var face := 0.035 + rng.randf_range(-0.004, 0.008)
		var row := rng.randi_range(0, 3)
		var u0 := rng.randf()
		var bu := rng.randf()
		var tint := rng.randf_range(0.86, 1.06)
		var col := Color(tint * rng.randf_range(0.98, 1.03), tint, tint * rng.randf_range(0.95, 1.0), 1.0)
		var cg := minf(0.032, h * 0.15)
		var lo := minf(0.055, h * 0.2)
		var hi := minf(0.06, h * 0.22)
		# (y, depth, kind) bottom -> top: chink, 2 bark segments, hewn face, 2 bark segments.
		var prof := [
			Vector2(ya, -0.012), Vector2(ya + cg, -0.012),
			Vector2(ya + cg + lo * 0.45, face * 0.55), Vector2(ya + cg + lo, face),
			Vector2(yb - hi, face),
			Vector2(yb - hi * 0.45, face * 0.6), Vector2(yb, -0.012),
		]
		var keys := [&"boards", &"bark", &"bark", &"boards", &"bark", &"bark"]
		var arc := 0.0
		for pi in 6:
			var pa: Vector2 = prof[pi]
			var pb: Vector2 = prof[pi + 1]
			var seg_len := Vector2(pb.x - pa.x, pb.y - pa.y).length()
			var a := o0 + up * pa.x + out * pa.y
			var b := o0 + along * w + up * pa.x + out * pa.y
			var cc := o0 + along * w + up * pb.x + out * pb.y
			var d := o0 + up * pb.x + out * pb.y
			var key: StringName = keys[pi]
			var ao_a := 1.0
			var ao_b := 1.0
			match pi:
				0:
					ao_a = 0.5
					ao_b = 0.55
				1:
					ao_a = 0.6
					ao_b = 0.85
				5:
					ao_a = 0.9
					ao_b = 0.62
			if k == 0 and pi <= 2:
				ao_a *= 0.85
			var cols := PackedColorArray([Color(col, ao_a), Color(col, ao_a), Color(col, ao_b), Color(col, ao_b)])
			if pi == 0:
				kit.quad(key, a, b, cc, d, Vector2(), Vector2(), Vector2(), Vector2(), Color.WHITE, K.KIND_CLAY, 0.0,
						PackedColorArray([Color(1, 1, 1, ao_a), Color(1, 1, 1, ao_a), Color(1, 1, 1, ao_b), Color(1, 1, 1, ao_b)]))
			elif key == &"bark":
				# Bark fissures run along the log: texture v along the wall, u across it.
				var va := Vector2(bu + arc / BARK_TILE, 0.0)
				var vb := Vector2(bu + (arc + seg_len) / BARK_TILE, 0.0)
				kit.quad(key, a, b, cc, d, va, va + Vector2(0, w / BARK_TILE), vb + Vector2(0, w / BARK_TILE), vb,
						col, K.KIND_TEX, 0.0, cols)
			else:
				var fy0: float = prof[3].x
				var fy1: float = prof[4].x
				var fa := clampf((pa.x - fy0) / (fy1 - fy0), 0.0, 1.0)
				var fb := clampf((pb.x - fy0) / (fy1 - fy0), 0.0, 1.0)
				kit.quad(key, a, b, cc, d, Vector2(u0, K.row_v(row, fa)), Vector2(u0 + w, K.row_v(row, fa)),
						Vector2(u0 + w, K.row_v(row, fb)), Vector2(u0, K.row_v(row, fb)), col, K.KIND_TEX, 0.0, cols)
			arc += seg_len


## A protruding saddle-notched log end: bark cylinder along `dir` from `start` (its axis) for
## `length`, end grain cap at the far end.
static func log_end(kit: K, start: Vector3, dir: Vector3, length: float, r: float, rng: RandomNumberGenerator) -> void:
	const SEG := 10
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	var end := start + dir * length
	var bu := rng.randf()
	var P0 := PackedVector3Array()
	var P1 := PackedVector3Array()
	var N0 := PackedVector3Array()
	var U0 := PackedVector2Array()
	var U1 := PackedVector2Array()
	var C0 := PackedColorArray()
	var C1 := PackedColorArray()
	var rr := r * rng.randf_range(0.94, 1.04)
	for j in SEG + 1:
		var a := TAU * j / SEG
		var n := side * cos(a) + up * sin(a)
		P0.append(start + n * rr)
		P1.append(end + n * rr * 0.97)
		N0.append(n)
		U0.append(Vector2(bu + float(j) / SEG * (TAU * rr / BARK_TILE), 0.0))
		U1.append(Vector2(bu + float(j) / SEG * (TAU * rr / BARK_TILE), length / BARK_TILE))
		var ao := 0.75 + 0.25 * clampf(n.y + 0.5, 0.0, 1.0)
		C0.append(Color(1, 1, 1, ao * 0.8))
		C1.append(Color(1, 1, 1, ao))
	kit.grid(&"bark", [P0, P1], [N0, N0], [U0, U1], [C0, C1])
	# End grain cap (fan), UV = offset from the pith in metres.
	var ctr := end + dir * 0.004
	var pith := Vector2(rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02))
	for j in SEG:
		var a0 := TAU * j / SEG
		var a1 := TAU * (j + 1) / SEG
		var p0 := end + (side * cos(a0) + up * sin(a0)) * rr * 0.95
		var p1 := end + (side * cos(a1) + up * sin(a1)) * rr * 0.95
		var q0 := Vector2(cos(a0), sin(a0)) * rr * 0.95 - pith
		var q1 := Vector2(cos(a1), sin(a1)) * rr * 0.95 - pith
		kit.tri(&"boards", ctr, p0, p1, -pith, q0, q1, Color(1, 1, 1, 1), K.KIND_ENDGRAIN, 0.0, dir)


# --- Roofs --------------------------------------------------------------------------------------

## Gable roof over a w x d footprint whose eaves are at `center.y`, the same envelope as the
## original placeholder (0.3 m overhang, top surface 6 cm above the old board centre line):
## riven-shingle courses (detail) or a flat shingle-textured deck, ridge boards, barge boards,
## fascia and board-clad gable ends. Local X is across the ridge, Z along it; rot_y turns it.
## `over`: the overhang past the footprint at the -Z and +Z ends (0.3 m each by default); an end with no
## overhang has no barge boards (a bay of a longer roof that the next bay continues, scripts/building/).
static func gable_roof(kit: K, center: Vector3, w: float, d: float, pitch_deg: float, rot_y: float,
		rng: RandomNumberGenerator, detail: bool, gable_walls := true, over := Vector2(0.3, 0.3)) -> void:
	var saved := kit.xform
	kit.xform = saved * Transform3D(Basis(Vector3.UP, rot_y), center)
	var p := deg_to_rad(pitch_deg)
	var half := w * 0.5 + 0.3
	var S := half / cos(p)
	var z0 := -(d * 0.5 + over.x)
	var z1 := d * 0.5 + over.y
	var none := PackedColorArray()
	for sg: float in [-1.0, 1.0]:
		var eave := Vector3(sg * half, 0.0, 0.0)
		var up_s := Vector3(-sg * cos(p), sin(p), 0.0)      # up the slope
		var nrm := Vector3(sg * sin(p), cos(p), 0.0)        # out of the roof
		var down_s := -up_s
		var P := func(s: float, n: float, z: float) -> Vector3: return eave + up_s * s + nrm * n + Vector3(0, 0, z)
		# Deck soffit underneath (boards along the ridge).
		var srow := rng.randi_range(0, 3)
		kit.quad(&"boards", P.call(0.0, -0.06, z0), P.call(0.0, -0.06, z1), P.call(S, -0.06, z1), P.call(S, -0.06, z0),
				Vector2(z0, K.row_v(srow, 0)), Vector2(z1, K.row_v(srow, 0)), Vector2(z1, K.row_v(srow, 1)), Vector2(z0, K.row_v(srow, 1)),
				Color(0.8, 0.78, 0.75, 0.6), K.KIND_TEX, 0.0, none, -nrm)
		if detail:
			var e_len := 0.35
			var n_c := int(ceil((S + 0.02) / e_len))
			for ci in n_c:
				var sb := ci * e_len - 0.02
				var st := minf(sb + e_len + 0.06, S + 0.01)
				var tb := 0.06
				var tt := 0.026
				var r := rng.randi_range(0, 7)
				var uo := rng.randf()
				var tint := rng.randf_range(0.94, 1.05)
				var vb := (r + 1) / 8.0 - 0.002
				var vt := vb - (st - sb) / SHINGLE_TILE
				var cb := Color(tint, tint, tint, 1.0)
				var ct := Color(tint, tint, tint, 0.62)
				var cbd := Color(tint * 0.8, tint * 0.8, tint * 0.8, 0.8)
				var uz0 := z0 / SHINGLE_TILE + uo
				var uz1 := z1 / SHINGLE_TILE + uo
				# Course top: butt (thick, lower) -> top end (thin, under the next course).
				kit.quad(&"shingles", P.call(sb, tb, z0), P.call(sb, tb, z1), P.call(st, tt, z1), P.call(st, tt, z0),
						Vector2(uz0, vb), Vector2(uz1, vb), Vector2(uz1, vt), Vector2(uz0, vt), cb, K.KIND_TEX, 0.0,
						PackedColorArray([cb, cb, ct, ct]), nrm)
				# Butt face: the shadow line of each course.
				kit.quad(&"shingles", P.call(sb, 0.018, z0), P.call(sb, 0.018, z1), P.call(sb, tb, z1), P.call(sb, tb, z0),
						Vector2(uz0, vb + 0.004), Vector2(uz1, vb + 0.004), Vector2(uz1, vb), Vector2(uz0, vb), cbd, K.KIND_TEX, 1.0,
						none, down_s)
				# Slivers at the gable ends.
				for zz: float in [z0, z1]:
					kit.quad(&"shingles", P.call(sb, 0.018, zz), P.call(st, 0.018, zz), P.call(st, tt, zz), P.call(sb, tb, zz),
							Vector2(uz0, vb), Vector2(uz0 + 0.01, vt), Vector2(uz0 + 0.01, vt), Vector2(uz0, vb), cbd, K.KIND_TEX, 0.0,
							none, Vector3(0, 0, signf(zz)))
		else:
			var v0 := S / SHINGLE_TILE
			kit.quad(&"shingles", P.call(0.0, 0.06, z0), P.call(0.0, 0.06, z1), P.call(S, 0.06, z1), P.call(S, 0.06, z0),
					Vector2(z0 / SHINGLE_TILE, v0), Vector2(z1 / SHINGLE_TILE, v0), Vector2(z1 / SHINGLE_TILE, 0), Vector2(z0 / SHINGLE_TILE, 0),
					Color.WHITE, K.KIND_TEX, 0.0, none, nrm)
		# Ridge (saddle) board lying on the top course, with its lower edge.
		var rr := rng.randi_range(0, 3)
		var ra: Vector3 = P.call(S - 0.19, 0.075, z0 - 0.02)
		var rb: Vector3 = P.call(S - 0.19, 0.075, z1 + 0.02)
		var rc: Vector3 = P.call(S + 0.035, 0.075, z1 + 0.02)
		var rd: Vector3 = P.call(S + 0.035, 0.075, z0 - 0.02)
		kit.quad(&"boards", ra, rb, rc, rd, Vector2(z0, K.row_v(rr, 0)), Vector2(z1, K.row_v(rr, 0)), Vector2(z1, K.row_v(rr, 1)),
				Vector2(z0, K.row_v(rr, 1)), Color(1, 1, 1, 1), K.KIND_TEX, 0.3, none, nrm)
		kit.quad(&"boards", P.call(S - 0.19, 0.04, z0 - 0.02), P.call(S - 0.19, 0.04, z1 + 0.02), rb, ra,
				Vector2(z0, K.row_v(rr, 0)), Vector2(z1, K.row_v(rr, 0)), Vector2(z1, K.row_v(rr, 0.1)), Vector2(z0, K.row_v(rr, 0.1)),
				Color(1, 1, 1, 0.8), K.KIND_TEX, 1.0, none, down_s)
		# Fascia board along the eave.
		var frow := rng.randi_range(0, 3)
		var f0: Vector3 = P.call(0.0, 0.06, z0 - 0.03) + Vector3(sg * 0.03, 0, 0)
		var f1: Vector3 = P.call(0.0, 0.06, z1 + 0.03) + Vector3(sg * 0.03, 0, 0)
		kit.quad(&"boards", f0 + Vector3(0, -0.2, 0), f1 + Vector3(0, -0.2, 0), f1, f0,
				Vector2(z0, K.row_v(frow, 0)), Vector2(z1, K.row_v(frow, 0)), Vector2(z1, K.row_v(frow, 1)), Vector2(z0, K.row_v(frow, 1)),
				Color(1, 1, 1, 0.9), K.KIND_TEX, 0.2, none, Vector3(sg, 0, 0))
		# Barge boards on both gable ends, following the rake, with their underside.
		for zz: float in [z0 - 0.035, z1 + 0.035]:
			if (zz < 0.0 and over.x < 0.05) or (zz > 0.0 and over.y < 0.05):
				continue
			var brow := rng.randi_range(0, 3)
			var g0: Vector3 = P.call(-0.02, 0.085, zz)
			var g1: Vector3 = P.call(S + 0.02, 0.085, zz)
			var g2 := g1 + Vector3(0, -0.24, 0)
			var g3 := g0 + Vector3(0, -0.24, 0)
			kit.quad(&"boards", g3, g2, g1, g0, Vector2(0, K.row_v(brow, 0)), Vector2(S, K.row_v(brow, 0)),
					Vector2(S, K.row_v(brow, 1)), Vector2(0, K.row_v(brow, 1)), Color(1, 1, 1, 0.95), K.KIND_TEX, 0.2,
					none, Vector3(0, 0, signf(zz)))
			var zi := zz - signf(zz) * 0.035
			kit.quad(&"boards", g3, g2, Vector3(g2.x, g2.y, zi), Vector3(g3.x, g3.y, zi),
					Vector2(0, K.row_v(brow, 0)), Vector2(S, K.row_v(brow, 0)), Vector2(S, K.row_v(brow, 0.1)), Vector2(0, K.row_v(brow, 0.1)),
					Color(1, 1, 1, 0.7), K.KIND_TEX, 1.0, none, Vector3.DOWN)
	if gable_walls:
		_gable_ends(kit, w, d, p, half, rng)
	kit.xform = saved


## Horizontal lapped boards filling the triangles at both gable ends (z = +-d/2).
static func _gable_ends(kit: K, w: float, d: float, p: float, half: float, rng: RandomNumberGenerator) -> void:
	var under := 0.07 / cos(p)
	var top := half * tan(p) - under
	var bh := 0.24
	for zs: float in [-1.0, 1.0]:
		var z := zs * (d * 0.5 + 0.022)
		var y := 0.0
		while y < top - 0.02:
			var y1 := minf(y + bh, top)
			var xa := minf(w * 0.5, half - (y + under) / tan(p))
			var xb := maxf(minf(w * 0.5, half - (y1 + under) / tan(p)), 0.0)
			var row := rng.randi_range(0, 3)
			var u0 := rng.randf()
			var tint := rng.randf_range(0.88, 1.06)
			var cl := Color(tint, tint, tint, 1.0)
			var ch := Color(tint, tint, tint, 0.72)
			var lap := 0.012 * zs
			var a := Vector3(-xa, y, z + lap)
			var b := Vector3(xa, y, z + lap)
			var c := Vector3(xb, y1, z)
			var e := Vector3(-xb, y1, z)
			var ua := Vector2(-xa + u0, K.row_v(row, 0))
			var ub := Vector2(xa + u0, K.row_v(row, 0))
			var uc := Vector2(xb + u0, K.row_v(row, 1))
			var ue := Vector2(-xb + u0, K.row_v(row, 1))
			kit.quad(&"boards", a, b, c, e, ua, ub, uc, ue, cl, K.KIND_TEX, 0.0, PackedColorArray([cl, cl, ch, ch]), Vector3(0, 0, zs))
			# Drip edge under the lap.
			var a2 := Vector3(-xa, y, z)
			var b2 := Vector3(xa, y, z)
			kit.quad(&"boards", a2, b2, b, a, ua, ub, ub, ua, Color(tint, tint, tint, 0.6), K.KIND_TEX, 1.0, PackedColorArray(), Vector3.DOWN)
			y = y1


# --- Openings -----------------------------------------------------------------------------------

## Plank door (vertical boards, two strap hinges, latch) with a casing, on a wall whose outer
## surface is at `c` (centre of the door at the ground line), facing `out`.
static func door(kit: K, c: Vector3, out: Vector3, width: float, height: float, rng: RandomNumberGenerator,
		proud := 0.04) -> void:
	var up := Vector3.UP
	var along := up.cross(out)
	var frame := Basis(along, up, out)
	var saved := kit.xform
	kit.xform = saved * Transform3D(frame, c + out * proud)
	var n := maxi(3, int(round(width / 0.2)))
	var bw := width / n
	for i in n:
		var x := -width * 0.5 + bw * (i + 0.5)
		var t := rng.randf_range(0.85, 1.05)
		kit.box(&"boards", Transform3D(Basis(), Vector3(x, height * 0.5 + 0.03, 0.0)), Vector3(bw - 0.008, height, 0.04),
				K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(t * 0.92, t * 0.9, t * 0.88, 1.0), K.KIND_TEX, 32)
	# Strap hinges (hinge side at -x) and a latch bar.
	for hy: float in [height * 0.2, height * 0.8]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(-width * 0.5 + width * 0.33, hy, 0.024)), Vector3(width * 0.62, 0.05, 0.008),
				K.GRAIN_X, 0, 0.0, Color.WHITE, K.KIND_IRON, 32)
		kit.box(&"boards", Transform3D(Basis(), Vector3(-width * 0.5 - 0.02, hy, 0.02)), Vector3(0.05, 0.08, 0.03),
				K.GRAIN_X, 0, 0.0, Color.WHITE, K.KIND_IRON, 32)
	kit.box(&"boards", Transform3D(Basis(), Vector3(width * 0.36, height * 0.52, 0.03)), Vector3(0.2, 0.04, 0.03),
			K.GRAIN_X, 1, 0.3, Color(0.8, 0.78, 0.75, 1.0), K.KIND_TEX, 32)
	# Casing: jambs and head.
	for sx: float in [-1.0, 1.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx * (width * 0.5 + 0.06), (height + 0.1) * 0.5, 0.0)),
				Vector3(0.11, height + 0.1, 0.07), K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(1, 1, 1, 1), K.KIND_ENDGRAIN, 32)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, height + 0.1, 0.0)), Vector3(width + 0.34, 0.12, 0.08),
			K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), Color(1, 1, 1, 1), K.KIND_ENDGRAIN, 32)
	kit.xform = saved


## Closed shutter with a casing (window), bottom at y0.
static func shutter(kit: K, c: Vector3, out: Vector3, width: float, height: float, y0: float,
		rng: RandomNumberGenerator) -> void:
	var up := Vector3.UP
	var along := up.cross(out)
	var saved := kit.xform
	kit.xform = saved * Transform3D(Basis(along, up, out), Vector3(c.x, y0, c.z) + out * 0.04)
	var n := 3
	var bw := width / n
	for i in n:
		var t := rng.randf_range(0.85, 1.02)
		kit.box(&"boards", Transform3D(Basis(), Vector3(-width * 0.5 + bw * (i + 0.5), height * 0.5, 0.0)),
				Vector3(bw - 0.006, height, 0.035), K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(t, t * 0.98, t * 0.95, 1.0), K.KIND_TEX, 32)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, height * 0.5, 0.024)), Vector3(width * 0.9, 0.08, 0.02),
			K.GRAIN_X, 2, 0.1, Color(0.9, 0.9, 0.9, 1.0), K.KIND_TEX, 32)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, -0.05, 0.02)), Vector3(width + 0.2, 0.07, 0.1),
			K.GRAIN_X, 1, 0.4, Color(1, 1, 1, 0.9), K.KIND_ENDGRAIN, 32)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, height + 0.04, 0.0)), Vector3(width + 0.16, 0.08, 0.07),
			K.GRAIN_X, 3, 0.2, Color(1, 1, 1, 1), K.KIND_ENDGRAIN, 32)
	kit.xform = saved


## Dark loophole slot on a wall face (visual; the wall behind stays solid).
static func loophole(kit: K, c: Vector3, out: Vector3, width: float, height: float, depth := 0.035) -> void:
	var up := Vector3.UP
	var along := up.cross(out)
	var o := c + out * depth
	var a := o - along * width * 0.5 - up * height * 0.5
	var b := o + along * width * 0.5 - up * height * 0.5
	var cc := o + along * width * 0.5 + up * height * 0.5
	var d := o - along * width * 0.5 + up * height * 0.5
	kit.quad(&"boards", a, b, cc, d, Vector2(), Vector2(), Vector2(), Vector2(), Color(1, 1, 1, 0), K.KIND_VOID, 0.0,
			PackedColorArray(), out)
	# A thin sill below it.
	kit.box(&"boards", Transform3D(Basis(along, up, out), o - up * (height * 0.5 + 0.02)), Vector3(width + 0.08, 0.04, 0.05),
			K.GRAIN_X, 0, 0.0, Color(1, 1, 1, 0.9), K.KIND_ENDGRAIN, 32)


# --- Supplies -------------------------------------------------------------------------------------

## Plank crate filling a size^3 box centred on `t`: framed edges flush with the collider,
## board panels recessed 1.5 cm, a dark backing inside the gaps.
static func crate(kit: K, t: Transform3D, size: float, rng: RandomNumberGenerator) -> void:
	var saved := kit.xform
	kit.xform = saved * t
	var h := size * 0.5
	var fw := 0.07
	var tint := rng.randf_range(0.85, 1.08)
	var col := Color(tint, tint * rng.randf_range(0.97, 1.0), tint * rng.randf_range(0.93, 0.99), 1.0)
	kit.box(&"boards", Transform3D.IDENTITY, Vector3.ONE * (size - 0.05), K.GRAIN_X, 0, 0.0, Color(0.25, 0.24, 0.22, 0.3), K.KIND_TEX, 8)
	# Frame: 12 edge battens.
	for ax in 3:
		for s1: float in [-1.0, 1.0]:
			for s2: float in [-1.0, 1.0]:
				var p := Vector3.ZERO
				var o1 := (ax + 1) % 3
				var o2 := (ax + 2) % 3
				p[o1] = s1 * (h - fw * 0.5)
				p[o2] = s2 * (h - fw * 0.5)
				var sz := Vector3.ONE * fw
				sz[ax] = size - (0.0 if ax == 1 else 2.0 * fw)
				var grain: int = [K.GRAIN_X, K.GRAIN_Y, K.GRAIN_Z][ax]
				var ao := 0.8 if p.y < 0.0 else 1.0
				kit.box(&"boards", Transform3D(Basis(), p), sz, grain, rng.randi_range(0, 3), rng.randf(),
						Color(col, ao), K.KIND_ENDGRAIN, 0, 0.0, 0.7)
	# Panels: three boards per face, recessed.
	var inner := size - 2.0 * fw
	for ax in 3:
		for sg: float in [-1.0, 1.0]:
			if ax == 1 and sg < 0.0:
				continue
			var nb := 3
			var bw := inner / nb
			for i in nb:
				var p := Vector3.ZERO
				p[ax] = sg * (h - 0.025)
				var run := 2 if ax == 0 else 0                 # boards run horizontally
				var across := 3 - ax - run
				p[across] = -inner * 0.5 + bw * (i + 0.5)
				var sz := Vector3.ZERO
				sz[ax] = 0.02
				sz[run] = inner
				sz[across] = bw - 0.01
				var grain: int = [K.GRAIN_X, K.GRAIN_Y, K.GRAIN_Z][run]
				var t2 := rng.randf_range(0.9, 1.06)
				kit.box(&"boards", Transform3D(Basis(), p), sz, grain, rng.randi_range(0, 3), rng.randf(),
						Color(col.r * t2, col.g * t2, col.b * t2, 0.92), K.KIND_ENDGRAIN)
	kit.xform = saved


## Stave barrel filling a cylinder of radius r and height hgt centred on `t` (bulged staves
## touching the collider at mid height), iron hoops, a sunk head with its chime.
static func barrel(kit: K, t: Transform3D, r: float, hgt: float, rng: RandomNumberGenerator, open := false) -> void:
	const STAVES := 16
	var saved := kit.xform
	kit.xform = saved * t
	var hh := hgt * 0.5
	var ys := [-hh, -hh * 0.8, -hh * 0.42, 0.0, hh * 0.42, hh * 0.8, hh]
	var prof := func(y: float) -> float: return r - 0.045 * pow(y / hh, 2.0)
	var phase := rng.randf() * TAU
	var tint := rng.randf_range(0.82, 1.05)
	for s in STAVES:
		var a0 := phase + TAU * s / STAVES
		var a1 := phase + TAU * (s + 1) / STAVES
		var row := rng.randi_range(0, 3)
		var u0 := rng.randf()
		var st := tint * rng.randf_range(0.9, 1.08)
		var rows_p := []
		var rows_n := []
		var rows_u := []
		var rows_c := []
		for y: float in ys:
			var P := PackedVector3Array()
			var N := PackedVector3Array()
			var U := PackedVector2Array()
			var C := PackedColorArray()
			var rr: float = prof.call(y)
			for j in 3:
				var a := lerpf(a0, a1, j * 0.5)
				var n := Vector3(cos(a), 0.12 * y / hh * -1.0, sin(a)).normalized()
				P.append(Vector3(cos(a) * rr, y, sin(a) * rr))
				N.append(n)
				U.append(Vector2((y + hh) / 1.0 + u0, K.row_v(row, j * 0.5)))
				var ao := 0.72 if j != 1 else 1.0
				if y < -hh * 0.9:
					ao *= 0.7
				C.append(Color(st, st * 0.98, st * 0.95, ao))
			rows_p.append(P)
			rows_n.append(N)
			rows_u.append(U)
			rows_c.append(C)
		kit.grid(&"boards", rows_p, rows_n, rows_u, rows_c)
	# Hoops.
	var hoop_ys := [-hh * 0.88, -hh * 0.46, hh * 0.46, hh * 0.88]
	if rng.randf() < 0.35:
		hoop_ys = [-hh * 0.86, -hh * 0.3, hh * 0.3, hh * 0.86]
	for hy: float in hoop_ys:
		var hw := 0.022
		var P0 := PackedVector3Array()
		var P1 := PackedVector3Array()
		var N0 := PackedVector3Array()
		var U0 := PackedVector2Array()
		var U1 := PackedVector2Array()
		var C0 := PackedColorArray()
		for j in STAVES * 2 + 1:
			var a := TAU * j / (STAVES * 2)
			var rr: float = prof.call(hy) + 0.006
			P0.append(Vector3(cos(a) * rr, hy - hw, sin(a) * rr))
			P1.append(Vector3(cos(a) * rr, hy + hw, sin(a) * rr))
			N0.append(Vector3(cos(a), 0.0, sin(a)))
			U0.append(Vector2(a, 0))
			U1.append(Vector2(a, 1))
			C0.append(Color(1, 1, 1, 1))
		kit.grid(&"boards", [P0, P1], [N0, N0], [U0, U1], [C0, C0], K.KIND_IRON)
		# Hoop edges (top and bottom lips).
		for sgn: float in [-1.0, 1.0]:
			var Q0 := PackedVector3Array()
			var Q1 := PackedVector3Array()
			var NQ := PackedVector3Array()
			for j in STAVES * 2 + 1:
				var a := TAU * j / (STAVES * 2)
				var rr: float = prof.call(hy + sgn * hw)
				Q0.append(Vector3(cos(a) * (rr - 0.002), hy + sgn * hw, sin(a) * (rr - 0.002)))
				Q1.append(Vector3(cos(a) * (rr + 0.006), hy + sgn * hw, sin(a) * (rr + 0.006)))
				NQ.append(Vector3(0, sgn, 0))
			kit.grid(&"boards", [Q0, Q1], [NQ, NQ], [U0, U1], [C0, C0], K.KIND_IRON)
	# Chime (inner wall above the head), rim, head (an open barrel's head knocked in: down at the bottom).
	var rt: float = prof.call(hh)
	var head_y := -hh + 0.05 if open else hh - 0.035
	var rim_in := rt - 0.022
	var RP := PackedVector3Array()
	var RI := PackedVector3Array()
	var HP := PackedVector3Array()
	var NU := PackedVector3Array()
	var NI := PackedVector3Array()
	var UR0 := PackedVector2Array()
	var UR1 := PackedVector2Array()
	var CR := PackedColorArray()
	var CI := PackedColorArray()
	for j in STAVES + 1:
		var a := phase + TAU * j / STAVES
		RP.append(Vector3(cos(a) * rt, hh, sin(a) * rt))
		RI.append(Vector3(cos(a) * rim_in, hh, sin(a) * rim_in))
		HP.append(Vector3(cos(a) * rim_in, head_y, sin(a) * rim_in))
		NU.append(Vector3.UP)
		NI.append(Vector3(-cos(a), 0.0, -sin(a)))
		UR0.append(Vector2(cos(a) * rt, sin(a) * rt))
		UR1.append(Vector2(cos(a) * rim_in, sin(a) * rim_in))
		CR.append(Color(tint, tint, tint, 1.0))
		CI.append(Color(tint, tint, tint, 0.45))
	kit.grid(&"boards", [RP, RI], [NU, NU], [UR0, UR1], [CR, CR], K.KIND_ENDGRAIN, 0.8)
	kit.grid(&"boards", [RI, HP], [NI, NI], [UR1, UR1], [CI, CI], K.KIND_TEX)
	var hrow := rng.randi_range(0, 3)
	for j in STAVES:
		var p0: Vector3 = HP[j]
		var p1: Vector3 = HP[j + 1]
		var ctr := Vector3(0, head_y, 0)
		kit.tri(&"boards", ctr, p1, p0, Vector2(0.5, K.row_v(hrow, 0.5)),
				Vector2(0.5 + p1.x, K.row_v(hrow, 0.5 + p1.z / (2.2 * rim_in))),
				Vector2(0.5 + p0.x, K.row_v(hrow, 0.5 + p0.z / (2.2 * rim_in))), Color(tint, tint, tint, 0.7), K.KIND_TEX, 0.0, Vector3.UP)
	kit.xform = saved


# --- Straw ----------------------------------------------------------------------------------------

## Bound straw truss (a lumpy, rounded bolster) filling a box `size` centred on `t` (length
## along local X), with two twisted straw bands. Replaces the anachronistic rectangular bale.
static func straw_truss(kit: K, t: Transform3D, size: Vector3, rng: RandomNumberGenerator) -> void:
	const AROUND := 18
	var saved := kit.xform
	kit.xform = saved * t
	var hx := size.x * 0.5
	var hy := size.y * 0.5 - 0.005
	var hz := size.z * 0.5 - 0.005
	var xs := [-hx, -hx + 0.05, -hx + 0.14, -hx * 0.55, -hx * 0.2, hx * 0.2, hx * 0.55, hx - 0.14, hx - 0.05, hx]
	var ends := [0.62, 0.86, 0.97, 1.0, 1.0, 1.0, 1.0, 0.97, 0.86, 0.62]
	var bumps := []
	for i in xs.size():
		var b := PackedFloat32Array()
		for j in AROUND + 1:
			b.append(rng.randf_range(-0.022, 0.018) if j < AROUND else 0.0)
		b[AROUND] = b[0]
		bumps.append(b)
	var shape := func(a: float, sc: float, bump: float) -> Vector3:
		var c := cos(a)
		var s := sin(a)
		var e := 2.0 / 3.2
		var y := signf(s) * pow(absf(s), e) * hy
		var z := signf(c) * pow(absf(c), e) * hz
		var v := Vector3(0, y, z) * sc + Vector3(0, y, z).normalized() * bump
		v.y = maxf(v.y, -hy)
		return v
	var rows_p := []
	var rows_n := []
	var rows_u := []
	var rows_c := []
	for i in xs.size():
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		var U := PackedVector2Array()
		var C := PackedColorArray()
		var x: float = xs[i]
		for j in AROUND + 1:
			var a := TAU * j / AROUND
			var p: Vector3 = shape.call(a, ends[i], (bumps[i] as PackedFloat32Array)[j])
			p.x = x
			var n := Vector3(0, p.y / (hy * hy), p.z / (hz * hz)).normalized()
			if i == 0 or i == xs.size() - 1:
				n = (n + Vector3(signf(x), 0, 0)).normalized()
			P.append(p)
			N.append(n)
			U.append(Vector2(x / STRAW_TILE, float(j) / AROUND * 2.2))
			var ao := lerpf(0.45, 1.0, clampf((p.y + hy) / (hy * 1.2), 0.0, 1.0))
			C.append(Color(1, 1, 1, ao))
		rows_p.append(P)
		rows_n.append(N)
		rows_u.append(U)
		rows_c.append(C)
	kit.grid(&"straw", rows_p, rows_n, rows_u, rows_c)
	# End caps: fibre ends seen head-on (fan).
	for i: int in [0, xs.size() - 1]:
		var P: PackedVector3Array = rows_p[i]
		var ctr := Vector3(xs[i] + signf(xs[i]) * 0.03, 0.0, 0.0)
		for j in AROUND:
			var p0: Vector3 = P[j]
			var p1: Vector3 = P[j + 1]
			var uv0 := Vector2(p0.z, p0.y) / STRAW_TILE
			var uv1 := Vector2(p1.z, p1.y) / STRAW_TILE
			kit.tri(&"straw", ctr, p0, p1, Vector2(0.5, 0.5), uv0, uv1, Color(0.82, 0.8, 0.74, 0.85), K.KIND_TEX, 0.0,
					Vector3(signf(xs[i]), 0, 0))
	# Twisted straw bands.
	for bx: float in [-hx * 0.52, hx * 0.52]:
		var bw := 0.035
		var R0 := PackedVector3Array()
		var R1 := PackedVector3Array()
		var NN := PackedVector3Array()
		var U0 := PackedVector2Array()
		var U1 := PackedVector2Array()
		var CC := PackedColorArray()
		for j in AROUND + 1:
			var a := TAU * j / AROUND
			var p: Vector3 = shape.call(a, 1.0, 0.02)
			var n := Vector3(0, p.y / (hy * hy), p.z / (hz * hz)).normalized()
			R0.append(p + Vector3(bx - bw, 0, 0))
			R1.append(p + Vector3(bx + bw, 0, 0))
			NN.append(n)
			U0.append(Vector2(float(j) * 0.35, 0.0))
			U1.append(Vector2(float(j) * 0.35 + 0.12, 0.18))
			CC.append(Color(0.58, 0.52, 0.42, lerpf(0.5, 1.0, clampf((p.y + hy) / hy, 0.0, 1.0))))
		kit.grid(&"straw", [R0, R1], [NN, NN], [U0, U1], [CC, CC])
	kit.xform = saved


# --- Flag -------------------------------------------------------------------------------------------

## Flat grid for flag_cloth.gdshader: x = 0 (hoist) .. length, y = -height/2 .. height/2.
static func flag_mesh(length: float, height: float, material: Material) -> ArrayMesh:
	var nx := 24
	var ny := 12
	var P := PackedVector3Array()
	var N := PackedVector3Array()
	var U := PackedVector2Array()
	var T := PackedFloat32Array()
	var I := PackedInt32Array()
	for j in ny + 1:
		for i in nx + 1:
			P.append(Vector3(length * i / nx, height * (float(j) / ny - 0.5), 0.0))
			N.append(Vector3(0, 0, 1))
			U.append(Vector2(float(i) / nx, 1.0 - float(j) / ny))
			T.append_array(PackedFloat32Array([1, 0, 0, 1]))
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			I.append_array(PackedInt32Array([a, a + nx + 1, a + 1, a + 1, a + nx + 1, a + nx + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = P
	arrays[Mesh.ARRAY_NORMAL] = N
	arrays[Mesh.ARRAY_TANGENT] = T
	arrays[Mesh.ARRAY_TEX_UV] = U
	arrays[Mesh.ARRAY_INDEX] = I
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	# The shader turns and waves it: a generous AABB keeps it from being culled.
	mesh.custom_aabb = AABB(Vector3(-length - 0.5, -height, -length - 0.5), Vector3(2.0 * length + 1.0, 2.0 * height, 2.0 * length + 1.0))
	return mesh


## Tapered round pole from y0 to y1 (bottom radius r0, top r1), hewn-wood grain along it, with
## a turned cap (truck) on top.
static func pole(kit: K, base: Vector3, y0: float, y1: float, r0: float, r1: float, rng: RandomNumberGenerator, cap := true) -> void:
	const SEG := 10
	var rows_p := []
	var rows_n := []
	var rows_u := []
	var rows_c := []
	var row := rng.randi_range(0, 3)
	var n_rings := 6
	for i in n_rings:
		var f := float(i) / (n_rings - 1)
		var y := lerpf(y0, y1, f)
		var r := lerpf(r0, r1, f)
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		var U := PackedVector2Array()
		var C := PackedColorArray()
		for j in SEG + 1:
			var a := TAU * j / SEG
			P.append(base + Vector3(cos(a) * r, y, sin(a) * r))
			N.append(Vector3(cos(a), 0.0, sin(a)))
			U.append(Vector2(y * 0.5, K.row_v(row, float(j) / SEG)))
			C.append(Color(1, 1, 1, 0.75 if y < 0.3 else 1.0))
		rows_p.append(P)
		rows_n.append(N)
		rows_u.append(U)
		rows_c.append(C)
	kit.grid(&"boards", rows_p, rows_n, rows_u, rows_c)
	if cap:
		var ctr := base + Vector3(0, y1, 0)
		kit.box(&"boards", Transform3D(Basis(), ctr + Vector3(0, 0.035, 0)), Vector3(r1 * 2.6, 0.07, r1 * 2.6), K.GRAIN_X, 2, 0.0, Color(0.9, 0.88, 0.85, 1.0))
		kit.box(&"boards", Transform3D(Basis(), ctr + Vector3(0, 0.1, 0)), Vector3(r1 * 1.1, 0.07, r1 * 1.1), K.GRAIN_X, 1, 0.0, Color(0.9, 0.88, 0.85, 1.0))


# --- Chimney ----------------------------------------------------------------------------------------

## Fieldstone chimney: a firebox base (`base_min`..`base_max`), sloped shoulders up to a stack
## (`stack_min`..`stack_max` in XZ, from shoulder_y to top_y) and a cap course.
static func chimney(kit: K, base_min: Vector3, base_max: Vector3, stack_min: Vector2, stack_max: Vector2,
		shoulder_y: float, top_y: float) -> void:
	var ts := 1.0 / STONE_TILE
	var b0 := base_min
	var b1 := base_max
	# Base block (sides only; the wall side is hidden but closed for shadows).
	var bctr := (b0 + b1) * 0.5
	var bsz := b1 - b0
	_stone_box(kit, bctr, bsz, ts, 8)
	# Shoulders: loft from the base top to the stack bottom.
	var sy := b1.y
	var tops := [Vector3(b0.x, sy, b0.z), Vector3(b1.x, sy, b0.z), Vector3(b1.x, sy, b1.z), Vector3(b0.x, sy, b1.z)]
	var stk := [Vector3(stack_min.x, shoulder_y, stack_min.y), Vector3(stack_max.x, shoulder_y, stack_min.y),
			Vector3(stack_max.x, shoulder_y, stack_max.y), Vector3(stack_min.x, shoulder_y, stack_max.y)]
	for i in 4:
		var a: Vector3 = tops[i]
		var b: Vector3 = tops[(i + 1) % 4]
		var c: Vector3 = stk[(i + 1) % 4]
		var d: Vector3 = stk[i]
		var ua := Vector2((a.x + a.z) * ts, a.y * ts)
		var ub := Vector2((b.x + b.z) * ts, b.y * ts)
		var uc := Vector2((c.x + c.z) * ts, c.y * ts)
		var ud := Vector2((d.x + d.z) * ts, d.y * ts)
		var outward := ((a + b) * 0.5 - Vector3((b0.x + b1.x) * 0.5, sy, (b0.z + b1.z) * 0.5))
		outward.y = 0.0
		kit.quad(&"stone", a, b, c, d, ua, ub, uc, ud, Color(0.95, 0.95, 0.95, 0.9), K.KIND_TEX, 0.0, PackedColorArray(), outward)
	# Stack.
	var sctr := Vector3((stack_min.x + stack_max.x) * 0.5, (shoulder_y + top_y) * 0.5, (stack_min.y + stack_max.y) * 0.5)
	var ssz := Vector3(stack_max.x - stack_min.x, top_y - shoulder_y, stack_max.y - stack_min.y)
	_stone_box(kit, sctr, ssz, ts, 4 | 8)
	# Cap course (slightly wider) with a dark flue.
	var cap := Vector3(ssz.x + 0.1, 0.12, ssz.z + 0.1)
	_stone_box(kit, Vector3(sctr.x, top_y + 0.06, sctr.z), cap, ts, 4)
	var fy := top_y + 0.121
	var fh := Vector2(ssz.x * 0.28, ssz.z * 0.28)
	var rimx := cap.x * 0.5
	var rimz := cap.z * 0.5
	# Top ring around the flue (4 quads) and the flue itself (void).
	var cx := sctr.x
	var cz := sctr.z
	var ring := [
		[Vector3(cx - rimx, fy, cz - rimz), Vector3(cx + rimx, fy, cz - rimz), Vector3(cx + fh.x, fy, cz - fh.y), Vector3(cx - fh.x, fy, cz - fh.y)],
		[Vector3(cx + rimx, fy, cz - rimz), Vector3(cx + rimx, fy, cz + rimz), Vector3(cx + fh.x, fy, cz + fh.y), Vector3(cx + fh.x, fy, cz - fh.y)],
		[Vector3(cx + rimx, fy, cz + rimz), Vector3(cx - rimx, fy, cz + rimz), Vector3(cx - fh.x, fy, cz + fh.y), Vector3(cx + fh.x, fy, cz + fh.y)],
		[Vector3(cx - rimx, fy, cz + rimz), Vector3(cx - rimx, fy, cz - rimz), Vector3(cx - fh.x, fy, cz - fh.y), Vector3(cx - fh.x, fy, cz + fh.y)],
	]
	for q: Array in ring:
		var a: Vector3 = q[0]
		var b: Vector3 = q[1]
		var c: Vector3 = q[2]
		var d: Vector3 = q[3]
		kit.quad(&"stone", a, b, c, d, Vector2(a.x, a.z) * ts, Vector2(b.x, b.z) * ts, Vector2(c.x, c.z) * ts, Vector2(d.x, d.z) * ts,
				Color(0.5, 0.5, 0.5, 0.8), K.KIND_TEX, 0.0, PackedColorArray(), Vector3.UP)
	kit.quad(&"stone", Vector3(cx - fh.x, fy - 0.001, cz - fh.y), Vector3(cx - fh.x, fy - 0.001, cz + fh.y),
			Vector3(cx + fh.x, fy - 0.001, cz + fh.y), Vector3(cx + fh.x, fy - 0.001, cz - fh.y),
			Vector2(), Vector2(), Vector2(), Vector2(), Color(1, 1, 1, 0), K.KIND_VOID, 0.0, PackedColorArray(), Vector3.UP)


## Box with world-projected stone UVs (1 tile per STONE_TILE metres).
static func _stone_box(kit: K, ctr: Vector3, size: Vector3, ts: float, skip := 0) -> void:
	var h := size * 0.5
	var faces := [[Vector3.RIGHT, 1], [Vector3.LEFT, 2], [Vector3.UP, 4], [Vector3.DOWN, 8], [Vector3.BACK, 16], [Vector3.FORWARD, 32]]
	for f: Array in faces:
		if skip & int(f[1]):
			continue
		var n: Vector3 = f[0]
		var u := Vector3.UP.cross(n) if absf(n.y) < 0.5 else Vector3.RIGHT
		var v := n.cross(u)
		var ext_u := absf(u.dot(h))
		var ext_v := absf(v.dot(h))
		var c := ctr + n * absf(n.dot(h))
		var pts := [c - u * ext_u - v * ext_v, c + u * ext_u - v * ext_v, c + u * ext_u + v * ext_v, c - u * ext_u + v * ext_v]
		var uvs := []
		for p: Vector3 in pts:
			var uu := p.dot(u) * ts
			var vv := (p.y if absf(n.y) < 0.5 else p.dot(v)) * ts
			uvs.append(Vector2(uu, -vv))
		var ao := 0.75 if n.y < -0.5 else 1.0
		var cols := PackedColorArray()
		for p: Vector3 in pts:
			cols.append(Color(1, 1, 1, ao * (0.7 if p.y < 0.2 else 1.0)))
		kit.quad(&"stone", pts[0], pts[1], pts[2], pts[3], uvs[0], uvs[1], uvs[2], uvs[3], Color.WHITE, K.KIND_TEX, 0.0, cols)


# --- Firewood and chopping block ----------------------------------------------------------------

## Stacked split firewood between two stakes: pieces of `piece_len` along local Z, the pile
## `length` long (local X) and `height` tall, centred on `t` at ground level.
static func woodpile(kit: K, t: Transform3D, length: float, height: float, piece_len: float, rng: RandomNumberGenerator) -> void:
	var saved := kit.xform
	kit.xform = saved * t
	var y := 0.0
	var layer := 0
	while y < height - 0.06:
		var x := -length * 0.5 + 0.1
		var layer_h := 0.0
		while x < length * 0.5 - 0.1:
			var r := rng.randf_range(0.075, 0.12)
			var kind := rng.randi_range(0, 2)            # 0 quarter, 1 half, 2 small round
			var w := r * (1.5 if kind != 2 else 1.8)
			if x + w > length * 0.5 - 0.08:
				break
			var zj := rng.randf_range(-0.03, 0.03)
			var cx := x + w * 0.5
			_firewood_piece(kit, Vector3(cx, y, zj), r, piece_len * rng.randf_range(0.94, 1.04), kind, rng.randf() * TAU, rng)
			layer_h = maxf(layer_h, r * (1.0 if kind == 0 else 0.95))
			x += w + rng.randf_range(0.0, 0.015)
		y += layer_h * 0.92
		layer += 1
	# Stakes at both ends.
	for sx: float in [-1.0, 1.0]:
		kit.box(&"bark", Transform3D(Basis(), Vector3(sx * (length * 0.5 - 0.02), (height + 0.15) * 0.5, 0.0)),
				Vector3(0.07, height + 0.15, 0.07), K.GRAIN_Y, 0, rng.randf(), Color(1, 1, 1, 1), K.KIND_ENDGRAIN)
	kit.xform = saved


## One split: a wedge / half / round cross-section extruded along Z; bark on the outside,
## split faces in hewn wood, end grain on both ends.
static func _firewood_piece(kit: K, base: Vector3, r: float, length: float, kind: int, rot: float, rng: RandomNumberGenerator) -> void:
	var pts: Array[Vector2] = []
	var bark_edge: Array[bool] = []
	match kind:
		0:  # quarter: centre + arc of 90 deg
			pts = [Vector2.ZERO]
			for i in 4:
				var a := deg_to_rad(90.0 * i / 3.0)
				pts.append(Vector2(cos(a), sin(a)) * r * 1.3)
			bark_edge = [false, true, true, true, false]
		1:  # half: flat bottom + arc
			for i in 5:
				var a := PI * i / 4.0
				pts.append(Vector2(cos(a), sin(a)) * r)
			bark_edge = [true, true, true, true, false]
		_:  # small round
			for i in 7:
				var a := TAU * i / 7.0
				pts.append(Vector2(cos(a), sin(a)) * r * 0.62)
			bark_edge = [true, true, true, true, true, true, true]
	# Place: rotate the section, rest it on y = 0 (lowest point).
	var ca := cos(rot)
	var sa := sin(rot)
	var min_y := INF
	var cx := 0.0
	for i in pts.size():
		var p := pts[i]
		pts[i] = Vector2(p.x * ca - p.y * sa, p.x * sa + p.y * ca)
		min_y = minf(min_y, pts[i].y)
		cx += pts[i].x / pts.size()
	for i in pts.size():
		pts[i] = pts[i] - Vector2(cx, min_y)
	var z0 := -length * 0.5
	var z1 := length * 0.5
	var row := rng.randi_range(0, 3)
	var tint := rng.randf_range(0.85, 1.1)
	var col := Color(tint, tint, tint * 0.97, 1.0)
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		# Section is counter-clockwise in (x, y); seen from outside the edge a -> b, with Z out of
		# the pile: quad (a,z0) (b,z0) (b,z1) (a,z1) faces outward if a->b is CCW.
		var pa0 := base + Vector3(a.x, a.y, z0)
		var pb0 := base + Vector3(b.x, b.y, z0)
		var pb1 := base + Vector3(b.x, b.y, z1)
		var pa1 := base + Vector3(a.x, a.y, z1)
		var ao := 0.6 if (a.y < 0.02 and b.y < 0.02) else 0.95
		var c2 := Color(col, ao)
		var outward := Vector3(b.y - a.y, -(b.x - a.x), 0.0)
		if bark_edge[i]:
			var u0 := a.length() * 3.0
			kit.quad(&"bark", pa0, pa1, pb1, pb0, Vector2(u0, z0 / BARK_TILE), Vector2(u0, z1 / BARK_TILE),
					Vector2(u0 + 0.08, z1 / BARK_TILE), Vector2(u0 + 0.08, z0 / BARK_TILE), c2, K.KIND_TEX, 0.0,
					PackedColorArray(), outward)
		else:
			kit.quad(&"boards", pa0, pa1, pb1, pb0, Vector2(z0, K.row_v(row, 0)), Vector2(z1, K.row_v(row, 0)),
					Vector2(z1, K.row_v(row, 0.6)), Vector2(z0, K.row_v(row, 0.6)), Color(col.r * 1.1, col.g * 1.08, col.b, ao),
					K.KIND_TEX, 0.5, PackedColorArray(), outward)
	# End grain caps (fan from the first point / centroid).
	var ctr2 := Vector2.ZERO
	for p in pts:
		ctr2 += p / n
	var pith := pts[0] if kind == 0 else (ctr2 if kind == 2 else Vector2(ctr2.x, pts[0].y))
	for zz: float in [z0, z1]:
		var cc := base + Vector3(ctr2.x, ctr2.y, zz)
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			var pa := base + Vector3(a.x, a.y, zz)
			var pb := base + Vector3(b.x, b.y, zz)
			if zz > 0.0:
				kit.tri(&"boards", cc, pa, pb, ctr2 - pith, a - pith, b - pith, Color(1, 1, 1, 1), K.KIND_ENDGRAIN, 0.0, Vector3(0, 0, 1))
			else:
				kit.tri(&"boards", cc, pb, pa, ctr2 - pith, b - pith, a - pith, Color(1, 1, 1, 0.9), K.KIND_ENDGRAIN, 0.0, Vector3(0, 0, -1))


## Log round standing on end (chopping block): bark sides, end grain top.
static func log_round(kit: K, base: Vector3, r: float, h: float, rng: RandomNumberGenerator) -> void:
	const SEG := 14
	var P0 := PackedVector3Array()
	var P1 := PackedVector3Array()
	var N := PackedVector3Array()
	var U0 := PackedVector2Array()
	var U1 := PackedVector2Array()
	var C0 := PackedColorArray()
	var C1 := PackedColorArray()
	var bumps := PackedFloat32Array()
	for j in SEG:
		bumps.append(rng.randf_range(-0.012, 0.012))
	bumps.append(bumps[0])
	for j in SEG + 1:
		var a := TAU * j / SEG
		var rr := r + bumps[j]
		var n := Vector3(cos(a), 0, sin(a))
		P0.append(base + n * (rr + 0.01) + Vector3(0, -0.02, 0))
		P1.append(base + n * rr + Vector3(0, h, 0))
		N.append(n)
		U0.append(Vector2(float(j) / SEG * TAU * r / BARK_TILE, 0.0))
		U1.append(Vector2(float(j) / SEG * TAU * r / BARK_TILE, h / BARK_TILE))
		C0.append(Color(1, 1, 1, 0.55))
		C1.append(Color(1, 1, 1, 1.0))
	kit.grid(&"bark", [P0, P1], [N, N], [U0, U1], [C0, C1])
	var ctr := base + Vector3(0, h + 0.004, 0)
	var pith := Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
	for j in SEG:
		var p0: Vector3 = P1[j]
		var p1: Vector3 = P1[j + 1]
		kit.tri(&"boards", ctr, p1, p0, -pith, Vector2(p1.x - base.x, p1.z - base.z) - pith,
				Vector2(p0.x - base.x, p0.z - base.z) - pith, Color(0.92, 0.9, 0.86, 1.0), K.KIND_ENDGRAIN, 0.0, Vector3.UP)
