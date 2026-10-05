class_name FormModels
extends RefCounted
## The Form art's models (FormEffects; our own, made here): the raised earth wall (a rough slab, lumpy faces, a ragged top, its
## foot running on below the ground so it can rise out of it; by its matter, FormMatter: packed earth with turf on its top, wet
## mud smoothed and slumped, grey fieldstones packed together, packed snow; from a tree, a palisade section of upright split
## logs: palisade_mesh), the pillar (a rough ten-sided column, a low domed cap on it to stand on), a stone spike (a jagged
## six-sided cone), the cannonball (a round fieldstone ball, a little lumpy), the rubble a stone wall falls into (chunk_mesh),
## and the spells' icon models (ItemIcons renders them like every item: "form_<spell>": the effect over its circle; the HUD's
## hotbar draws the SVGs, assets/ui/icons/spell_<id>.svg). Materials: our own procedural surfaces, no textures
## (FormMatter.material: shaders/sway/form_matter.gdshader; the user, 2026-10-03: "we need to work on the textures"); the
## palisade's bark is the tree's own (GatherModels.bark_material). The vertex colours: rgb the hollows' darkening, alpha how
## fresh a face is (a stone's freshly broken faces come out lighter).
##
##   FormModels.wall_mesh(3.0, 2.0, 0.6, seed, FormModels.BURY_M, "mud")   # ArrayMesh, its base at y 0 (and BURY_M under it), centred on x and z
##   FormModels.has("form_earth_wall"); FormModels.build("form_earth_wall")

const FormMatter := preload("res://scripts/sway/form_matter.gd")
const PLANKS := "res://assets/polyhaven/textures/structures/brown_planks_07/brown_planks_07_%s_2k.jpg"
## How far each raised thing's foot runs on under the ground (m): it rises out of the earth that much before it shows its base.
const BURY_M := 0.45
const ICONS := ["form_earth_wall", "form_stone_form", "form_pillar", "form_mend"]

static var _wood: StandardMaterial3D


## A stone's look (grey fieldstone, as Stone Form raises from rock; FormMatter.rock_material).
static func stone_material() -> Material:
	return FormMatter.rock_material("stone")


## The cannonball's (and a small boulder's): the same fieldstone.
static func ball_material() -> Material:
	return FormMatter.rock_material("stone")


## Planks (the Mend icon's built piece).
static func wood_material() -> StandardMaterial3D:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.roughness = 0.85
		_wood.uv1_triplanar = true
		_wood.uv1_scale = Vector3.ONE * 0.9
		_wood.albedo_color = Color(0.92, 0.84, 0.74)
		if ResourceLoader.exists(PLANKS % "diffuse"):
			_wood.albedo_texture = load(PLANKS % "diffuse")
	return _wood


static func _noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = 3
	return n


## A matter's shape numbers (earth_wall.wall.materials.<matter>.shape: bump, batter_m, top_m, sag_m, round_m, fresh).
static func _shape_of(matter: String) -> Dictionary:
	return (FormMatter.wall_materials().get(matter, {}) as Dictionary).get("shape", {})


## A vertex's colour: rgb the hollows' darkening (`n` the noise there, -1..1), alpha how fresh the face is (fresh.x at the
## foot to fresh.y toward the top, `top` high).
static func _tint(y: float, top: float, n: float, fresh := Vector2.ZERO) -> Color:
	var k := 0.86 + 0.14 * n
	var u := clampf(y / maxf(top, 0.01), 0.0, 1.0)
	var f := lerpf(fresh.x, fresh.y, smoothstep(0.1, 0.8, u)) * (0.75 + 0.25 * n)
	return Color(k, k, k, clampf(f, 0.0, 1.0))


## A rough box w (x) by h (y, over the ground; BURY_M more under it) by t (z), its faces lumpy and its top ragged, shaped by
## its matter (_shape_of: how lumpy, how much wider at the foot, how ragged its top, how much it sags: mud's slumps) and
## drawn in its look (FormMatter.wall_material).
static func wall_mesh(w: float, h: float, t: float, seed := 1, bury := BURY_M, matter := "earth") -> ArrayMesh:
	var sh := _shape_of(matter)
	var bump_k := float(sh.get("bump", 1.0))
	var batter_m := float(sh.get("batter_m", 0.08))
	var top_m := float(sh.get("top_m", 0.12))
	var sag_m := float(sh.get("sag_m", 0.0))
	var round_m := float(sh.get("round_m", 0.3))
	var fresh := Vector2(0.0, float(sh.get("fresh", 0.0)))
	var nz := _noise(seed, 1.6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := maxi(int(w / 0.18), 4)
	var ny := maxi(int((h + bury) / 0.18), 4)
	var nt := maxi(int(t / 0.18), 2)
	var top := func(x: float, z: float) -> float:
		var ux := x / (w * 0.5)
		var uz := z / (t * 0.5)
		# (the ends a little lower; a slumping wall sags in its middle and rounds over its top)
		return h + nz.get_noise_2d(x * 2.0 + 40.0, z * 2.0) * top_m - ux * ux * 0.18 - sag_m * (0.6 * (1.0 - ux * ux) + uz * uz)
	# (each point pushed out along a way that depends on where it is only, so the faces meet at their edges without cracks)
	var shape := func(x: float, y: float, z: float, _out: Vector3) -> Vector3:
		var ty: float = top.call(x, z)
		var yy := minf(y, ty)
		var bump := (nz.get_noise_3d(x * 2.6, yy * 2.6, z * 2.6) * 0.07 + nz.get_noise_3d(x * 7.0, yy * 7.0, z * 7.0) * 0.025) * bump_k
		# (the slab thicker at its foot, as packed earth stands; mud spreads)
		var batter := (1.0 - clampf(yy / maxf(h, 0.1), 0.0, 1.0)) * batter_m
		var way := Vector3(x / (w * 0.5), 0.0, z / (t * 0.5))
		way = (way.normalized() if way.length_squared() > 1e-6 else Vector3.ZERO) + Vector3.UP * smoothstep(h - round_m, h, yy)
		return Vector3(x, yy, z) + way.normalized() * (bump + batter * (1.0 - way.normalized().y))
	# the two long faces, the two ends, the top (each a grid; the bottom is under the ground)
	_face(st, shape, top, Vector3(0, 0, 1), w, h, t, nx, ny, nz, bury, fresh)
	_face(st, shape, top, Vector3(0, 0, -1), w, h, t, nx, ny, nz, bury, fresh)
	_face(st, shape, top, Vector3(1, 0, 0), w, h, t, nt, ny, nz, bury, fresh)
	_face(st, shape, top, Vector3(-1, 0, 0), w, h, t, nt, ny, nz, bury, fresh)
	_top(st, shape, top, w, t, nx, nt, h, nz, fresh)
	st.index()                                # (the faces' shared corners merged: smooth, not faceted)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, FormMatter.wall_material(matter))
	return m


static func _face(st: SurfaceTool, shape: Callable, top: Callable, out: Vector3, w: float, h: float, t: float, nu: int, nv: int,
		nz: FastNoiseLite, bury := BURY_M, fresh := Vector2.ZERO) -> void:
	var along_x := absf(out.z) > 0.5
	var span := w if along_x else t
	var grid: Array = []
	for j in nv + 1:
		var row: Array = []
		for i in nu + 1:
			var u := -span * 0.5 + span * float(i) / nu
			var x := u if along_x else out.x * w * 0.5
			var z := out.z * t * 0.5 if along_x else u
			var ty: float = top.call(x, z)
			var y := -bury + (ty + bury) * float(j) / nv
			row.append(shape.call(x, y, z, out))
		grid.append(row)
	for j in nv:
		for i in nu:
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			_quad(st, a, b, c, d, out, nz, h, fresh)


static func _top(st: SurfaceTool, shape: Callable, top: Callable, w: float, t: float, nu: int, nv: int, h: float, nz: FastNoiseLite,
		fresh := Vector2.ZERO) -> void:
	var grid: Array = []
	for j in nv + 1:
		var row: Array = []
		for i in nu + 1:
			var x := -w * 0.5 + w * float(i) / nu
			var z := -t * 0.5 + t * float(j) / nv
			var p: Vector3 = shape.call(x, h + 1.0, z, Vector3.UP)
			row.append(p)
		grid.append(row)
	for j in nv:
		for i in nu:
			_quad(st, grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i], Vector3.UP, nz, h, fresh)


## A quad wound to face `out` (Godot's front face: clockwise seen from outside, its (b - a) x (c - a) pointing in).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, nz: FastNoiseLite, top: float,
		fresh := Vector2.ZERO) -> void:
	var n := (b - a).cross(d - a)
	var tri := [a, b, c, a, c, d] if n.dot(out) < 0.0 else [a, c, b, a, d, c]
	for p: Vector3 in tri:
		st.set_color(_tint(p.y, top, nz.get_noise_3d(p.x * 9.0, p.y * 9.0, p.z * 9.0), fresh))
		st.add_vertex(p)


## A triangle wound to face `out`, every corner coloured `col`.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, col: Color) -> void:
	var tri := [a, b, c] if (b - a).cross(c - a).dot(out) < 0.0 else [a, c, b]
	for p: Vector3 in tri:
		st.set_color(col)
		st.add_vertex(p)


## A rough column of radius r and height h (over the ground; BURY_M under), ten-sided, wider at its foot by its matter, and on
## it a low domed cap to stand on (a rim, an inner ring, the middle a little higher; wound to face up, so it is drawn from
## above: the user, 2026-10-03, "for the pillar top dont make it see thru"), freshly broken stone on a stone pillar's cap.
static func pillar_mesh(r: float, h: float, seed := 2, bury := BURY_M, matter := "earth") -> ArrayMesh:
	var sh := _shape_of(matter)
	var bump_k := float(sh.get("bump", 1.0))
	var flare := 0.1 * float(sh.get("batter_m", 0.08)) / 0.08
	var fresh := Vector2(0.0, float(sh.get("fresh", 0.0)))
	var nz := _noise(seed, 1.8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 10
	var rings := maxi(int((h + bury) / 0.2), 4)
	var pts: Array = []
	for j in rings + 1:
		var y := -bury + (h + bury) * float(j) / rings
		var row: Array = []
		for i in sides:
			var a := TAU * float(i) / sides
			var dir := Vector3(cos(a), 0.0, sin(a))
			var rr := r * (1.0 + flare * (1.0 - clampf(y / h, 0.0, 1.0))) + nz.get_noise_3d(dir.x * 3.0, y * 2.5, dir.z * 3.0) * 0.07 * bump_k
			row.append(dir * rr + Vector3.UP * y)
		pts.append(row)
	for j in rings:
		for i in sides:
			var i2 := (i + 1) % sides
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i2]
			var c: Vector3 = pts[j + 1][i2]
			var d: Vector3 = pts[j + 1][i]
			var mid := (a + c) * 0.5
			_quad(st, a, b, c, d, Vector3(mid.x, 0.0, mid.z).normalized(), nz, h, fresh)
	# the cap: the rim (the column's top ring) in to an inner ring a little higher, and the middle higher still
	var rim: Array = pts[rings]
	var inner: Array = []
	for i in sides:
		var q: Vector3 = rim[i]
		inner.append(Vector3(q.x * 0.62, h + 0.035 + nz.get_noise_2d(q.x * 6.0, q.z * 6.0) * 0.012, q.z * 0.62))
	var ctr := Vector3(0.0, h + 0.05, 0.0)
	var cap_fresh := Vector2(fresh.y, fresh.y)
	for i in sides:
		var i2 := (i + 1) % sides
		_quad(st, rim[i], rim[i2], inner[i2], inner[i], Vector3.UP, nz, h, cap_fresh)
		_tri(st, ctr, inner[i], inner[i2], Vector3.UP, _tint(h, h, nz.get_noise_2d(float(i) * 3.0, 1.0), cap_fresh))
	st.index()
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, FormMatter.wall_material(matter))
	return m


## A jagged spike: a seven-sided cone of base radius r and height h (its point a little off true, its faces uneven), BURY_M
## under the ground, in the look of a stone raised from `matter`'s ground (FormMatter.rock_material); each facet freshly
## broken (lighter) or weathered, the upper ones mostly fresh, drawn flat (a broken stone's facets).
static func spike_mesh(r: float, h: float, seed := 3, bury := BURY_M, matter := "stone") -> ArrayMesh:
	var nz := _noise(seed, 2.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 131 + 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var tip := Vector3(nz.get_noise_1d(1.0) * r * 0.5, h, nz.get_noise_1d(9.0) * r * 0.5)
	var rings := 6
	var pts: Array = []
	for j in rings + 1:
		var u := float(j) / rings
		var y := lerpf(-bury, h * 0.92, u)
		var row: Array = []
		for i in sides:
			var a := TAU * (float(i) + nz.get_noise_2d(float(i) * 3.1, float(j) * 1.7) * 0.3) / sides + float(seed) * 0.3
			var k := (1.0 - clampf(y / h, 0.0, 1.0))
			var rr := r * maxf(k, 0.08) * (0.76 + 0.48 * (nz.get_noise_2d(float(i) * 7.0, float(j) * 5.0) * 0.5 + 0.5))
			row.append(Vector3(cos(a) * rr, y, sin(a) * rr) + Vector3(tip.x, 0, tip.z) * clampf(y / h, 0.0, 1.0))
		pts.append(row)
	for j in rings:
		for i in sides:
			var i2 := (i + 1) % sides
			var a: Vector3 = pts[j][i]
			var mid := (a + (pts[j + 1][i2] as Vector3)) * 0.5
			var fresh := 0.9 if rng.randf() < lerpf(0.2, 0.75, float(j) / rings) else 0.08
			var k := 0.78 + 0.22 * rng.randf()
			# (outward from the leaning middle at that height, not from the foot's: near the point the lean is wider than the
			# spike, and a face wound from the foot's middle faced in, culled: "the spike form doesnt have a texture its see thru")
			_quad_col(st, a, pts[j][i2], pts[j + 1][i2], pts[j + 1][i], _spike_out(mid, tip, h), Color(k, k, k, fresh))
	var cap: Array = pts[rings]
	for i in sides:
		var a: Vector3 = cap[i]
		var b: Vector3 = cap[(i + 1) % sides]
		_tri(st, tip, a, b, _spike_out((a + b) * 0.5, tip, h), Color(0.95, 0.95, 0.95, 0.9))
	# its foot closed, facing down: it stood in the ground once, but Stone Form throws it now (FormEffects.Throw) and a spike
	# lying in a crate showed its open foot, the inside culled ("the spike is still see thru")
	var foot: Array = pts[0]
	var fc := Vector3.ZERO
	for p: Vector3 in foot:
		fc += p
	fc /= float(sides)
	for i in sides:
		_tri(st, fc, foot[(i + 1) % sides], foot[i], Vector3.DOWN, Color(0.8, 0.8, 0.8, 0.9))
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, FormMatter.rock_material(matter))
	return m


## Outward at `p` on a spike of height `h` leaning to `tip`: flat, away from its middle at p's height.
static func _spike_out(p: Vector3, tip: Vector3, h: float) -> Vector3:
	var k := clampf(p.y / h, 0.0, 1.0)
	var o := Vector3(p.x - tip.x * k, 0.0, p.z - tip.z * k)
	return o.normalized() if o.length_squared() > 1e-10 else Vector3(p.x, 0.0, p.z).normalized()


## A round stone ball of radius r (its middle at 0), a little lumpy, in the look of a stone raised from `matter`'s ground;
## patches of it freshly broken (lighter).
static func ball_mesh(r: float, seed := 4, matter := "stone") -> ArrayMesh:
	var nz := _noise(seed, 2.4)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 12
	var segs := 18
	var pts: Array = []
	for j in rings + 1:
		var v := PI * float(j) / rings
		var row: Array = []
		for i in segs:
			var u := TAU * float(i) / segs
			var dir := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
			var bump := nz.get_noise_3d(dir.x * 3.0, dir.y * 3.0, dir.z * 3.0) * 0.07 + nz.get_noise_3d(dir.x * 9.0, dir.y * 9.0, dir.z * 9.0) * 0.025
			row.append(dir * r * (1.0 + bump))
		pts.append(row)
	for j in rings:
		for i in segs:
			var i2 := (i + 1) % segs
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i2]
			var c: Vector3 = pts[j + 1][i2]
			var d: Vector3 = pts[j + 1][i]
			var mid := (a + b + c + d) * 0.25
			var tri := [a, b, c, a, c, d] if (b - a).cross(d - a).dot(mid) < 0.0 else [a, c, b, a, d, c]
			for p: Vector3 in tri:
				var n := nz.get_noise_3d(p.x * 14.0, p.y * 14.0, p.z * 14.0) * 0.5 + 0.5
				var chip := smoothstep(0.15, 0.45, nz.get_noise_3d(p.x * 3.5 + 20.0, p.y * 3.5, p.z * 3.5))
				st.set_color(Color(0.95, 0.95, 0.96, 0.2 + 0.7 * chip) * Color(0.78 + 0.26 * n, 0.78 + 0.26 * n, 0.78 + 0.26 * n, 1.0))
				st.add_vertex(p)
	st.index()
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, FormMatter.rock_material(matter))
	return m


## A lump of broken stone about r across (the rubble a stone wall falls into): a rough, flattened, faceted ball.
static func chunk_mesh(r: float, seed := 5, matter := "stone") -> ArrayMesh:
	var nz := _noise(seed, 3.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 4
	var segs := 6
	var pts: Array = []
	for j in rings + 1:
		var v := PI * float(j) / rings
		var row: Array = []
		for i in segs:
			var u := TAU * float(i) / segs + float(j) * 0.4
			var dir := Vector3(sin(v) * cos(u), cos(v) * 0.7, sin(v) * sin(u))
			row.append(dir * r * (1.0 + nz.get_noise_3d(dir.x * 2.0, dir.y * 2.0, dir.z * 2.0) * 0.3))
		pts.append(row)
	for j in rings:
		for i in segs:
			var i2 := (i + 1) % segs
			var a: Vector3 = pts[j][i]
			var c: Vector3 = pts[j + 1][i2]
			_quad(st, a, pts[j][i2], c, pts[j + 1][i], (a + c) * 0.5, nz, r, Vector2(0.8, 0.8))
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, FormMatter.rock_material(matter))
	return m


## A palisade section (the Earth Wall from a tree: FormMatter "wood"): upright split logs of about `lr` radius side by side
## across w (x), about h high (BURY_M more under the ground), their tops sharpened and uneven, each split flat on the
## caster's side (-z: the pale wood) and round with the tree's bark on the far side, two split rails pegged across the
## caster's side. Two surfaces: the bark (the species' own: GatherModels.bark_material) and the wood (FormMatter "wood").
static func palisade_mesh(w: float, h: float, lr: float, seed := 1, species := "", bury := BURY_M) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 17
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(roundi(w / (lr * 2.0)), 2)
	var step := w / n
	var r := step * 0.52
	var cut := -0.42                          # (the split: where the round side ends, as a share of r toward -z)
	var a0 := asin(cut)                       # (the round from a0 round through +z to PI - a0)
	var a1 := PI - a0
	var segs := 8
	var front := 0.0                          # (the split faces' nearest z: the rails go in front of them)
	for i in n:
		var cx := -w * 0.5 + step * (float(i) + 0.5) + rng.randf_range(-0.015, 0.015)
		var cz := rng.randf_range(-0.025, 0.025)
		var top := h * rng.randf_range(0.9, 1.04)
		var lean := Vector2(rng.randf_range(-0.025, 0.025), rng.randf_range(-0.015, 0.015))
		var k := rng.randf_range(0.8, 1.0)
		var col := Color(k, k * rng.randf_range(0.96, 1.0), k * rng.randf_range(0.92, 1.0), 0.35)
		var ring := func(y: float) -> Array:
			var pts: Array = []
			for s in segs + 1:
				var a := lerpf(a0, a1, float(s) / segs)
				pts.append(Vector3(cx + cos(a) * r + lean.x * y, y, cz + sin(a) * r + lean.y * y))
			return pts
		var lo: Array = ring.call(-bury)
		var hi: Array = ring.call(top)
		front = minf(front, cz + cut * r)
		# the round, barked: segs faces from the one end of the split round to the other
		for s in segs:
			var p0: Vector3 = lo[s]
			var p1: Vector3 = lo[s + 1]
			var p2: Vector3 = hi[s + 1]
			var p3: Vector3 = hi[s]
			var out := Vector3((p0.x + p1.x) * 0.5 - cx, 0.0, (p0.z + p1.z) * 0.5 - cz)
			var u0 := float(s) / segs * 1.4
			var u1 := float(s + 1) / segs * 1.4
			var tri := [[p0, u0, -p0.y], [p1, u1, -p1.y], [p2, u1, -p2.y], [p0, u0, -p0.y], [p2, u1, -p2.y], [p3, u0, -p3.y]]
			if (p1 - p0).cross(p3 - p0).dot(out) >= 0.0:
				tri = [[p0, u0, -p0.y], [p2, u1, -p2.y], [p1, u1, -p1.y], [p0, u0, -p0.y], [p3, u0, -p3.y], [p2, u1, -p2.y]]
			for v: Array in tri:
				bark.set_uv(Vector2(float(v[1]), float(v[2]) * 0.8))
				bark.set_color(Color(1, 1, 1, 1))
				bark.add_vertex(v[0])
		# the split face, flat toward the caster (the chord between the round's ends)
		var f0: Vector3 = lo[segs]
		var f1: Vector3 = lo[0]
		var f2: Vector3 = hi[0]
		var f3: Vector3 = hi[segs]
		_quad_col(wood, f0, f1, f2, f3, Vector3(0, 0, -1), col)
		# the point: axe facets from the top ring (the round and the split) up to the tip
		var tip := Vector3(cx + lean.x * (top + r * 1.6), top + r * 1.6, cz + r * 0.15 + lean.y * (top + r * 1.6))
		var fcol := Color(col.r, col.g, col.b, 1.0)
		for s in segs:
			var q0: Vector3 = hi[s]
			var q1: Vector3 = hi[s + 1]
			_tri(wood, q0, q1, tip, Vector3((q0.x + q1.x) * 0.5 - cx, 0.6, (q0.z + q1.z) * 0.5 - cz), fcol)
		_tri(wood, hi[segs], hi[0], tip, Vector3(0, 0.6, -1), fcol)
	# two split rails across the caster's side, at about knee and shoulder height
	for ry: float in [h * 0.32, h * 0.78]:
		var y0 := ry - 0.07
		var y1 := ry + 0.07
		var z1 := front - 0.005
		var z0 := z1 - 0.09
		var x0 := -w * 0.5 + 0.06
		var x1 := w * 0.5 - 0.06
		var rc := Color(0.9, 0.86, 0.8, 0.5)
		_quad_col(wood, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(0, 0, -1), rc)
		_quad_col(wood, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, rc)
		_quad_col(wood, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN, rc)
		_quad_col(wood, Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3.LEFT, rc)
		_quad_col(wood, Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3.RIGHT, rc)
	bark.index()
	bark.generate_normals()
	wood.generate_normals()
	var m := bark.commit()
	m.surface_set_material(0, GatherModels.bark_material(species))
	wood.commit(m)
	m.surface_set_material(1, FormMatter.wall_material("wood"))
	return m


## A quad wound to face `out`, every corner coloured `col` (drawn flat when not indexed).
static func _quad_col(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, col: Color) -> void:
	var tri := [a, b, c, a, c, d] if (b - a).cross(d - a).dot(out) < 0.0 else [a, c, b, a, d, c]
	for p: Vector3 in tri:
		st.set_color(col)
		st.add_vertex(p)


# ---------------------------------------------------------------- the icons
static func has(kind: String) -> bool:
	return kind in ICONS


## The spell's icon model: the effect standing over its circle, tilted toward ItemIcons' camera (which looks from +X).
static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "FormIcon_" + kind
	var held := Node3D.new()
	held.rotation = Vector3(0.0, 0.0, deg_to_rad(-34.0))
	root.add_child(held)
	var col := SwayMoves.art_color("form")
	var disc := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * 2.4
	disc.mesh = pm
	var dm := FormCircle.material(col)
	dm.set_shader_parameter(&"fill", 1.0)
	dm.set_shader_parameter(&"glow", 1.4)
	dm.set_shader_parameter(&"pull_m", 0.0)
	disc.material_override = dm
	disc.position = Vector3(0, 0.02, 0)
	held.add_child(disc)
	# (the ground under it: a disc of dark earth, so the circle reads as drawn on the ground)
	var earth_disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.3
	cm.bottom_radius = 1.3
	cm.height = 0.04
	cm.radial_segments = 48
	earth_disc.mesh = cm
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.3, 0.25, 0.2)
	em.roughness = 1.0
	earth_disc.material_override = em
	earth_disc.position = Vector3(0, -0.025, 0)
	held.add_child(earth_disc)
	match kind:
		"form_earth_wall":
			var w := _mi(wall_mesh(1.9, 1.15, 0.38, 5, 0.0))
			w.rotation.y = PI * 0.5
			w.position = Vector3(-0.35, -BURY_M * 0.0, 0.0)
			held.add_child(w)
		"form_stone_form":
			# (a spike and a ball beside it)
			var s := _mi(spike_mesh(0.2, 1.25, 11, 0.0))
			s.position = Vector3(-0.3, 0.0, -0.32)
			s.rotation = Vector3(deg_to_rad(-7.0), 0.0, deg_to_rad(-6.0))
			held.add_child(s)
			var b := _mi(ball_mesh(0.3, 12))
			b.position = Vector3(-0.2, 0.3, 0.45)
			held.add_child(b)
		"form_pillar":
			held.add_child(_mi(pillar_mesh(0.32, 1.5, 7, 0.0)))
		"form_mend":
			# (a built piece: two posts and their rails, one rail set back true)
			for part: Array in [[Vector3(0.16, 1.25, 0.16), Vector3(-0.2, 0.62, -0.62), 0.0], [Vector3(0.16, 1.25, 0.16), Vector3(-0.2, 0.62, 0.62), 0.0],
					[Vector3(0.1, 0.14, 1.55), Vector3(-0.2, 0.95, 0.0), 0.0], [Vector3(0.1, 0.14, 1.55), Vector3(-0.2, 0.45, 0.0), 9.0]]:
				var b := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = part[0]
				b.mesh = bm
				b.material_override = wood_material()
				b.position = part[1]
				b.rotation = Vector3(deg_to_rad(float(part[2])), 0.0, 0.0)
				held.add_child(b)
	return root


static func _mi(m: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position.y = 0.0
	return mi
