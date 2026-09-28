class_name ForageModels
extends RefCounted
## The forage plants' models (project-made, built here from leaves, stems and berries; no textures): each plant a
## leaf-and-stem mesh and, apart, its fruit (berries, nuts, acorns), which ForageField draws only in season and while
## there is some left. Vertex colours carry the look; a MultiMesh's instance colour tints them per plant. Sizes are
## real (m). Local frame: +Y up, the plant's base at the origin. VARIANTS shapes of each.
##
##   blackberry   a clump of arching canes with three-leaflet leaves; the fruit black, a few still red
##   strawberry   a rosette of three-leaflet leaves on stalks; the fruit small and red, low
##   plantain     a flat rosette of broad ribbed leaves and its seed spikes
##   wintergreen  short upright stems with three glossy leaves each; a red berry under them in the fall
##   ginseng      one stem, a whorl of three leaves of five leaflets; the red berry cluster in the middle
##   acorns       a fallen oak leaf or two; the fruit an acorn in its cap
##   hazelnuts    (the plant is the vegetation's hazel shrub) the fruit a cluster of nuts in their leafy husks
##   willow       a clump of slender stems, narrow pale leaves (the bark is what is taken)
##   yarrow       feathery leaves on upright stems; flat white flower heads in summer
##   slippery_elm a sapling, a grey trunk and spreading branches of big rough leaves (the inner bark)
##   elderberry   arching pale stems, leaves of paired leaflets; flat heads of dark purple berries
##   hemp         a tall stalk, leaves of narrow leaflets fanned out, a leafy flowering top
##   bearberry    trailing runners thick with small glossy leaves; red berries
##   red_osier    a thicket of blood-red stems, oval leaves in pairs; white berries at the tips
##   jimsonweed   a forked bushy plant of big coarse leaves; white trumpet flowers and spiny pods
##   crabapple    a small crooked tree, leaves in clusters; small yellow-green and red apples
## The woods' own materials (user 2026-09-28: "we need to have most of items can be craftable"), the "fruit" what is
## taken, so it goes when gathered and comes back:
##   deadwood     (the fruit) grey dead sticks lying crossed on the litter, a fork or two
##   windfall     (the fruit) a dead limb down on the ground, its side branches and broken stubs, lichen on the bark
##   arrowwood    a thicket of long straight grey shoots, oval toothed leaves in pairs
##   pine_pitch   a wound in the bark, crusted pale; the fruit amber beads and runs of resin (on a pine's trunk: +Z out
##                of the bark)
##   turkey_scratch  leaf litter thrown back from a scratched spot; the fruit a barred wing or tail feather or two
##   fieldstones  (the fruit) two to four rounded grey stones half in the ground
##   flint_nodules (the fruit) knobbly chert nodules in their pale rind, one broken open, dark and glassy
##   dead_pole    (the fruit) a dead sapling lying whole, grey and straight, its twigs broken short
##   bog_ore      (the fruit) dark rusty knobbly lumps of limonite half dug out of the wet ground
##   clay_bank    (the fruit) lumps of grey-blue clay cut from the bank, one slab with the spade's face
## Icons for the pack (ItemIcons): build(item) for the items the plants give.

const VARIANTS := 3
const ITEMS := ["blackberries", "strawberries", "plantain", "wintergreen", "ginseng", "acorns", "hazelnuts",
		"willow_bark", "yarrow", "elm_bark", "elderberries", "hemp_tops", "bearberry", "dogwood_bark", "jimsonweed",
		"crabapples", "shoots", "pine_pitch", "feathers", "bog_iron", "clay"]
## Plants whose fruit is wood or feathers: drawn matte, not glossy like berries.
const MATTE_FRUIT := ["deadwood", "windfall", "turkey_scratch", "fieldstones", "flint_nodules", "dead_pole", "bog_ore", "clay_bank"]

static var _cache := {}
static var _mats := {}


## The leaf-and-stem mesh of plant `kind` (null: none, as the hazel's).
static func plant_mesh(kind: String, v: int) -> Mesh:
	return _mesh_for(kind, v, false)


## The fruit mesh of plant `kind` (null: none).
static func fruit_mesh(kind: String, v: int) -> Mesh:
	return _mesh_for(kind, v, true)


static func _mesh_for(kind: String, v: int, fruit: bool) -> Mesh:
	var key := "%s:%d:%s" % [kind, v, fruit]
	if not _cache.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(kind) + v * 7919 + (1 if fruit else 0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 0
		match kind:
			"blackberry":
				n = _bramble(st, rng, fruit)
			"strawberry":
				n = _strawberry(st, rng, fruit)
			"plantain":
				n = 0 if fruit else _plantain(st, rng)
			"wintergreen":
				n = _wintergreen(st, rng, fruit)
			"ginseng":
				n = _ginseng(st, rng, fruit)
			"acorns":
				n = _acorn(st, rng) if fruit else _oak_litter(st, rng)
			"hazelnuts":
				n = _nut_cluster(st, rng) if fruit else 0
			"willow":
				n = 0 if fruit else _willow(st, rng)
			"yarrow":
				n = _yarrow(st, rng, fruit)
			"slippery_elm":
				n = 0 if fruit else _elm(st, rng)
			"elderberry":
				n = _elder(st, rng, fruit)
			"hemp":
				n = 0 if fruit else _hemp(st, rng)
			"bearberry":
				n = _bearberry(st, rng, fruit)
			"red_osier":
				n = _osier(st, rng, fruit)
			"jimsonweed":
				n = _jimson(st, rng, fruit)
			"crabapple":
				n = _crab(st, rng, fruit)
			"deadwood":
				n = _sticks(st, rng) if fruit else 0
			"windfall":
				n = _windfall(st, rng) if fruit else 0
			"arrowwood":
				n = 0 if fruit else _arrowwood(st, rng)
			"pine_pitch":
				n = _pitch(st, rng, fruit)
			"turkey_scratch":
				n = _feathers(st, rng) if fruit else _scratch(st, rng)
			"fieldstones":
				n = _fieldstones(st, rng) if fruit else 0
			"flint_nodules":
				n = _nodules(st, rng) if fruit else 0
			"dead_pole":
				n = _dead_pole(st, rng) if fruit else 0
			"bog_ore":
				n = _bog_ore(st, rng) if fruit else 0
			"clay_bank":
				n = _clay(st, rng) if fruit else 0
		var mesh: Mesh = null
		if n > 0:
			mesh = st.commit()
			mesh.surface_set_material(0, (matte_material() if kind in MATTE_FRUIT else fruit_material()) if fruit else leaf_material(kind))
		_cache[key] = mesh
	return _cache[key]


# --- Materials ---------------------------------------------------------------------------------------------

static func leaf_material(kind: String) -> StandardMaterial3D:
	var k := "leaf_glossy" if kind in ["wintergreen", "bearberry"] else "leaf"
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.5 if k == "leaf_glossy" else 0.82
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		m.backlight_enabled = true
		m.backlight = Color(0.16, 0.2, 0.08)
		_mats[k] = m
	return _mats[k]


## Dead wood and feathers: rough, both faces drawn.
static func matte_material() -> StandardMaterial3D:
	if not _mats.has("matte"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.92
		# (dead wood, stone and feathers hardly shine: at the default specular the sky's reflection turned them blue-white
		# in the shade)
		m.metallic_specular = 0.12
		_mats["matte"] = m
	return _mats["matte"]


static func fruit_material() -> StandardMaterial3D:
	if not _mats.has("fruit"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.32
		_mats["fruit"] = m
	return _mats["fruit"]


# --- Parts -------------------------------------------------------------------------------------------------

## A leaf from `base` along `dir`, its face toward `up` (square to dir): length `l`, width `w`, an ovate outline
## widest at `widest` of its length, the edges raised by `cup` (x the half width) and the tip bent down by `droop`
## (x the length). Colours from the stalk end to the tip.
static func _leaf(st: SurfaceTool, base: Vector3, dir: Vector3, up: Vector3, l: float, w: float, c0: Color, c1: Color,
		widest := 0.4, cup := 0.25, droop := 0.15, segs := 5) -> void:
	dir = dir.normalized()
	up = (up - dir * up.dot(dir)).normalized()
	var side := dir.cross(up).normalized()
	var mids: Array[Vector3] = []
	var lefts: Array[Vector3] = []
	var rights: Array[Vector3] = []
	var cols: Array[Color] = []
	for i in segs + 1:
		var t := float(i) / segs
		var shape := 0.0
		if t < widest:
			shape = pow(sin(t / widest * PI * 0.5), 0.75)
		else:
			shape = pow(cos((t - widest) / (1.0 - widest) * PI * 0.5), 0.9)
		var hw := w * 0.5 * shape
		var m := base + dir * l * t - up * droop * l * t * t
		mids.append(m)
		lefts.append(m + side * hw + up * cup * hw)
		rights.append(m - side * hw + up * cup * hw)
		cols.append(c0.lerp(c1, t))
	for i in segs:
		var cm := cols[i].lightened(0.08)
		var cn := cols[i + 1].lightened(0.08)
		_tri(st, mids[i], cm, lefts[i], cols[i], lefts[i + 1], cols[i + 1], up)
		_tri(st, mids[i], cm, lefts[i + 1], cols[i + 1], mids[i + 1], cn, up)
		_tri(st, mids[i], cm, mids[i + 1], cn, rights[i + 1], cols[i + 1], up)
		_tri(st, mids[i], cm, rights[i + 1], cols[i + 1], rights[i], cols[i], up)


## One triangle facing `n`: Godot's front faces wind clockwise seen from the front, so the corners are put in that
## order (a leaf wound the other way was lit from below, its normal flipped: black leaves, blue glossy ones).
static func _tri(st: SurfaceTool, a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color, n: Vector3,
		na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(n if na == Vector3.ZERO else na)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(n if nb == Vector3.ZERO else nb)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_normal(n if nc == Vector3.ZERO else nc)
	st.set_color(cc)
	st.add_vertex(c)


## A stalk from a to b, a prism of `sides` sides, radius r0 at a to r1 at b.
static func _stem(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, c: Color, sides := 4) -> void:
	var d := b - a
	if d.length() < 1e-5:
		return
	var ax := d.normalized()
	var x := ax.cross(Vector3.UP if absf(ax.y) < 0.95 else Vector3.RIGHT).normalized()
	var y := ax.cross(x).normalized()
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var n0 := x * cos(a0) + y * sin(a0)
		var n1 := x * cos(a1) + y * sin(a1)
		var q0 := a + n0 * r0
		var q1 := a + n1 * r0
		var q2 := b + n1 * r1
		var q3 := b + n0 * r1
		var fn := (n0 + n1).normalized()
		_tri(st, q0, c, q1, c, q2, c, fn, n0, n1, n1)
		_tri(st, q0, c, q2, c, q3, c, fn, n0, n1, n0)


## A stalk along the points `pts`, tapering from r0 to r1.
static func _stems(st: SurfaceTool, pts: Array[Vector3], r0: float, r1: float, c: Color) -> void:
	for i in pts.size() - 1:
		_stem(st, pts[i], pts[i + 1], lerpf(r0, r1, float(i) / (pts.size() - 1)), lerpf(r0, r1, float(i + 1) / (pts.size() - 1)), c)


## A round berry (an octahedron) at c, radius r, stretched by `s` in its own axes.
static func _blob(st: SurfaceTool, c: Vector3, r: float, col: Color, s := Vector3.ONE) -> void:
	var v := [Vector3(r * s.x, 0, 0), Vector3(-r * s.x, 0, 0), Vector3(0, r * s.y, 0), Vector3(0, -r * s.y, 0),
			Vector3(0, 0, r * s.z), Vector3(0, 0, -r * s.z)]
	var faces := [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]
	for f: Array in faces:
		var p0: Vector3 = v[f[0]]
		var p1: Vector3 = v[f[1]]
		var p2: Vector3 = v[f[2]]
		var n := (p0 + p1 + p2).normalized()
		_tri(st, c + p0, col.lightened(0.18) if p0.y > 0.0 else col, c + p1, col.lightened(0.18) if p1.y > 0.0 else col,
				c + p2, col.lightened(0.18) if p2.y > 0.0 else col, n,
				(p0.normalized() + n).normalized(), (p1.normalized() + n).normalized(), (p2.normalized() + n).normalized())


## A turned shape round `axis` (unit) from `c`: `profile` [radius, distance along the axis] rings, `segs` round.
static func _lathe(st: SurfaceTool, c: Vector3, axis: Vector3, profile: Array, col0: Color, col1: Color, segs := 8) -> void:
	var x := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var y := axis.cross(x).normalized()
	for i in profile.size() - 1:
		var r0 := float(profile[i][0])
		var r1 := float(profile[i + 1][0])
		var h0 := float(profile[i][1])
		var h1 := float(profile[i + 1][1])
		var c0 := col0.lerp(col1, float(i) / (profile.size() - 1))
		var c1 := col0.lerp(col1, float(i + 1) / (profile.size() - 1))
		for k in segs:
			var a0 := TAU * k / segs
			var a1 := TAU * (k + 1) / segs
			var d0 := x * cos(a0) + y * sin(a0)
			var d1 := x * cos(a1) + y * sin(a1)
			var p00 := c + axis * h0 + d0 * r0
			var p01 := c + axis * h0 + d1 * r0
			var p10 := c + axis * h1 + d0 * r1
			var p11 := c + axis * h1 + d1 * r1
			var fn := ((d0 + d1) * 0.5).normalized()
			_tri(st, p00, c0, p01, c0, p11, c1, fn, d0, d1, d1)
			_tri(st, p00, c0, p11, c1, p10, c1, fn, d0, d1, d0)


## A wild strawberry: a small red cone hanging from `c` (its calyx) along `down`, with its green sepals.
static func _strawberry_fruit(st: SurfaceTool, c: Vector3, r: float, down := Vector3.DOWN) -> void:
	var prof := []
	for k in [[0.55, 0.0], [0.92, 0.25], [1.0, 0.5], [0.9, 0.8], [0.66, 1.05], [0.34, 1.25], [0.0, 1.38]]:
		prof.append([float(k[0]) * r, float(k[1]) * r])
	_lathe(st, c, down, prof, Color(0.72, 0.06, 0.07), Color(0.86, 0.2, 0.14), 8)
	var side := down.cross(Vector3.RIGHT if absf(down.x) < 0.9 else Vector3.FORWARD).normalized()
	for k in 5:
		var d := (side.rotated(down, TAU * k / 5.0) - down * 0.25).normalized()
		_leaf(st, c, d, -down, r * 1.1, r * 0.55, Color(0.22, 0.36, 0.1), Color(0.28, 0.42, 0.12), 0.45, 0.1, 0.0, 3)


## A blackberry: drupelets round a core, on its stalk from `stalk`.
static func _blackberry(st: SurfaceTool, at: Vector3, stalk: Vector3, rng: RandomNumberGenerator, ripe: bool) -> void:
	var col := Color(0.07, 0.03, 0.07) if ripe else (Color(0.55, 0.06, 0.08) if rng.randf() < 0.6 else Color(0.45, 0.5, 0.16))
	_stem(st, stalk, at + Vector3.UP * 0.006, 0.0012, 0.001, Color(0.3, 0.3, 0.12), 3)
	_blob(st, at, 0.0065, col, Vector3(1.0, 1.25, 1.0))
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf() * 0.4
		_blob(st, at + Vector3(cos(a) * 0.0045, rng.randf_range(-0.004, 0.004), sin(a) * 0.0045), 0.0034, col)


# --- Plants ------------------------------------------------------------------------------------------------

## Blackberry: two or three canes rising and arching over, leaves of three leaflets along them; the fruit in
## clusters hanging from the upper cane (a few red among the black).
static func _bramble(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var n := 0
	var canes := rng.randi_range(4, 6)
	for c in canes:
		var yaw := TAU * c / canes + rng.randf_range(-0.5, 0.5)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var base := out * rng.randf_range(0.0, 0.08)
		var peak := base + out * rng.randf_range(0.25, 0.45) + Vector3.UP * rng.randf_range(0.85, 1.3)
		var tip := base + out * rng.randf_range(0.95, 1.5) + Vector3.UP * rng.randf_range(0.3, 0.6)
		var pts: Array[Vector3] = []
		for i in 9:
			var t := float(i) / 8.0
			pts.append(base.lerp(peak, t).lerp(peak.lerp(tip, t), t))
		if not fruit:
			_stems(st, pts, 0.009, 0.004, Color(0.36, 0.15, 0.13))
			n += 1
		for i in range(1, 9):
			var p := pts[i]
			var along := (pts[mini(i + 1, 8)] - pts[i - 1]).normalized()
			var side := along.cross(Vector3.UP).normalized() * (1.0 if i % 2 == 0 else -1.0)
			if fruit:
				if i >= 4 and rng.randf() < 0.9:
					var hang := p + side * 0.03 + Vector3.DOWN * 0.035
					for b in rng.randi_range(3, 5):
						_blackberry(st, hang + Vector3(rng.randf_range(-0.02, 0.02), rng.randf_range(-0.015, 0.01), rng.randf_range(-0.02, 0.02)),
								p, rng, rng.randf() < 0.72)
						n += 1
				continue
			var pet := p + (side + Vector3.UP * 0.3).normalized() * 0.04
			_stem(st, p, pet, 0.0018, 0.0014, Color(0.3, 0.3, 0.12), 3)
			var fwd := (side + Vector3.UP * 0.15).normalized()
			var up := Vector3.UP.lerp(-side * 0.3, 0.2).normalized()
			var leaflets := 5 if i < 5 else 3
			for k in leaflets:
				var off := float(k) - float(leaflets - 1) * 0.5
				var d := fwd.rotated(Vector3.UP, off * 0.6)
				var s := 1.0 - absf(off) * 0.12
				_leaf(st, pet, d, up, 0.115 * s, 0.068 * s, Color(0.16, 0.27, 0.06), Color(0.22, 0.35, 0.08), 0.42, 0.3, 0.22, 3)
			if i % 2 == 1 and i < 8:
				# a second leaf on the other side, a little on
				var p2 := p.lerp(pts[i + 1], 0.5)
				var pet2 := p2 + (-side + Vector3.UP * 0.3).normalized() * 0.035
				_stem(st, p2, pet2, 0.0016, 0.0013, Color(0.3, 0.3, 0.12), 3)
				for k in 3:
					var d2 := (-side + Vector3.UP * 0.15).normalized().rotated(Vector3.UP, (k - 1) * 0.6)
					_leaf(st, pet2, d2, up, 0.1 * (1.0 if k == 1 else 0.86), 0.06 * (1.0 if k == 1 else 0.86), Color(0.16, 0.27, 0.06), Color(0.22, 0.35, 0.08), 0.42, 0.3, 0.22, 3)
	return n


## Wild strawberry: a rosette of leaves of three leaflets on hairy stalks, a few low red berries.
static func _strawberry(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var n := 0
	var leaves := rng.randi_range(5, 7)
	for i in leaves:
		var yaw := TAU * i / leaves + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		if fruit:
			if i % 2 == 0:
				var at := out * rng.randf_range(0.04, 0.07) + Vector3.UP * 0.025
				_stem(st, Vector3.UP * 0.01, at + Vector3.UP * 0.008, 0.001, 0.001, Color(0.35, 0.4, 0.15), 3)
				_strawberry_fruit(st, at + Vector3.UP * 0.006, 0.0065, (Vector3.DOWN + out * 0.5).normalized())
				n += 1
			continue
		var top := out * rng.randf_range(0.06, 0.11) + Vector3.UP * rng.randf_range(0.08, 0.14)
		_stem(st, Vector3.ZERO, top, 0.0018, 0.0015, Color(0.3, 0.38, 0.16), 3)
		for k in 3:
			var d := (out.rotated(Vector3.UP, (k - 1) * 0.8) + Vector3.UP * 0.1).normalized()
			_leaf(st, top, d, Vector3.UP, 0.052, 0.037, Color(0.19, 0.32, 0.07), Color(0.25, 0.39, 0.09), 0.5, 0.2, 0.12)
		n += 1
	return n


## Plantain: broad ribbed leaves spread flat from the crown, and one to three seed spikes.
static func _plantain(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var leaves := rng.randi_range(5, 8)
	for i in leaves:
		var yaw := TAU * i / leaves + rng.randf_range(-0.25, 0.25)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var el := deg_to_rad(rng.randf_range(12.0, 35.0))
		var dir := (out * cos(el) + Vector3.UP * sin(el)).normalized()
		var up := dir.cross(out.cross(Vector3.UP)).normalized() * -1.0
		if up.y < 0.0:
			up = -up
		var pet := dir * 0.03
		_stem(st, Vector3.ZERO, pet, 0.003, 0.0025, Color(0.42, 0.5, 0.25), 3)
		_leaf(st, pet, dir, up, rng.randf_range(0.12, 0.18), rng.randf_range(0.07, 0.1), Color(0.19, 0.32, 0.08), Color(0.25, 0.38, 0.1), 0.45, 0.18, 0.18, 6)
	for s in rng.randi_range(1, 3):
		var tilt := Vector3(rng.randf_range(-0.2, 0.2), 1.0, rng.randf_range(-0.2, 0.2)).normalized()
		var h := rng.randf_range(0.15, 0.22)
		_stem(st, Vector3.ZERO, tilt * h * 0.55, 0.0012, 0.0011, Color(0.28, 0.34, 0.14), 3)
		_stem(st, tilt * h * 0.55, tilt * h, 0.0024, 0.0014, Color(0.3, 0.3, 0.15), 4)
	return leaves


## Wintergreen: short upright stems, three glossy dark leaves at the top of each; a red berry under them.
static func _wintergreen(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var n := 0
	var stems := rng.randi_range(6, 9)
	for i in stems:
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.08)
		var h := rng.randf_range(0.06, 0.11)
		var top := base + Vector3(rng.randf_range(-0.01, 0.01), h, rng.randf_range(-0.01, 0.01))
		if fruit:
			if i % 2 == 0:
				_blob(st, top + Vector3(0.01, -0.025, 0.0), 0.0048, Color(0.75, 0.05, 0.05))
				n += 1
			continue
		_stem(st, base, top, 0.0015, 0.0013, Color(0.35, 0.22, 0.12), 3)
		for k in 3:
			var d := Vector3(cos(a + TAU * k / 3.0), 0.6, sin(a + TAU * k / 3.0)).normalized()
			_leaf(st, top - Vector3.UP * 0.01, d, Vector3.UP, rng.randf_range(0.032, 0.042), 0.024, Color(0.12, 0.25, 0.06), Color(0.18, 0.32, 0.07), 0.5, 0.3, 0.25)
		n += 1
	return n


## Ginseng: one stem, a whorl of three leaves of five leaflets; the berry cluster on a stalk from the middle.
static func _ginseng(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var h := rng.randf_range(0.26, 0.36)
	var top := Vector3(rng.randf_range(-0.02, 0.02), h, rng.randf_range(-0.02, 0.02))
	if fruit:
		var c := top + Vector3.UP * 0.05
		for i in 9:
			var a := TAU * i / 9.0
			_blob(st, c + Vector3(cos(a) * 0.009, rng.randf_range(-0.004, 0.006), sin(a) * 0.009), 0.0052, Color(0.82, 0.07, 0.05))
		return 9
	_stem(st, Vector3.ZERO, top, 0.003, 0.0025, Color(0.3, 0.3, 0.15), 4)
	_stem(st, top, top + Vector3.UP * 0.045, 0.0012, 0.001, Color(0.3, 0.36, 0.15), 3)
	var a0 := rng.randf() * TAU
	for k in 3:
		var yaw := a0 + TAU * k / 3.0
		var out := Vector3(cos(yaw), 0.25, sin(yaw)).normalized()
		var end := top + out * 0.07
		_stem(st, top, end, 0.0018, 0.0015, Color(0.28, 0.35, 0.14), 3)
		for j in 5:
			var d := Vector3(cos(yaw + (j - 2) * 0.55), 0.1, sin(yaw + (j - 2) * 0.55)).normalized()
			var s := [0.62, 0.85, 1.0, 0.85, 0.62][j] as float
			_leaf(st, end, d, Vector3.UP, 0.1 * s, 0.045 * s, Color(0.19, 0.34, 0.07), Color(0.26, 0.42, 0.09), 0.62, 0.2, 0.15)
	return 1


## An acorn in its cap, lying on the ground.
static func _acorn(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var tip := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
	var c := Vector3.UP * 0.009
	var basis := Basis(Vector3.UP.cross(tip).normalized(), Vector3.UP, tip)     # a rotation (no mirror: that turns the faces)
	var col := Color(0.47, 0.32, 0.13) if rng.randf() < 0.6 else Color(0.38, 0.4, 0.16)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_blob(st2, Vector3.ZERO, 0.009, col, Vector3(1.0, 1.0, 1.35))
	_blob(st2, Vector3(0, 0, -0.008), 0.0085, Color(0.33, 0.24, 0.12), Vector3(1.1, 1.1, 0.7))
	var arrays := st2.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in verts.size():
		st.set_normal(basis * norms[i])
		st.set_color(cols[i])
		st.add_vertex(c + basis * verts[i])
	return 1


## A fallen oak leaf or two (brown and a green one), flat on the ground.
static func _oak_litter(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	for i in rng.randi_range(1, 2):
		var d := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
		var base := Vector3(rng.randf_range(-0.05, 0.05), 0.004, rng.randf_range(-0.05, 0.05))
		var green := rng.randf() < 0.35
		_leaf(st, base, d + Vector3.UP * 0.05, Vector3.UP, 0.12, 0.07, Color(0.4, 0.3, 0.14) if not green else Color(0.25, 0.33, 0.12),
				Color(0.5, 0.37, 0.17) if not green else Color(0.3, 0.38, 0.14), 0.55, -0.1, 0.0, 5)
	return 1


## Hazelnuts: two or three nuts, each in its frilled leafy husk.
static func _nut_cluster(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var nuts := rng.randi_range(2, 3)
	for i in nuts:
		var a := TAU * i / nuts
		var out := Vector3(cos(a), -0.4, sin(a)).normalized()
		var c := out * 0.016
		_blob(st, c + out * 0.004, 0.0075, Color(0.52, 0.38, 0.18), Vector3(1.0, 1.1, 1.0))
		for k in 4:
			var d := (out.rotated(Vector3.UP, k * PI * 0.5) * 0.5 + out).normalized()
			_leaf(st, c - out * 0.008, d, out.cross(d).normalized() if out.cross(d).length() > 0.01 else Vector3.UP, 0.028, 0.016,
					Color(0.36, 0.46, 0.18), Color(0.42, 0.5, 0.2), 0.5, 0.4, 0.3, 3)
	_stem(st, Vector3.ZERO, Vector3.UP * 0.02, 0.0015, 0.0012, Color(0.3, 0.26, 0.14), 3)
	return nuts


# --- The remedy and vice plants (user 2026-09-27: "we will need more plants and herbs for these new things") ----------

## The same structure for a plant's leaf-and-stem mesh and its fruit mesh (their rngs are seeded apart): an rng seeded
## as the leaf pass's, so the berries hang where the stems are.
static func _srng(rng: RandomNumberGenerator, fruit: bool) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = rng.seed - (1 if fruit else 0)
	return r


## Which way a shrub's or a tree's leaf faces: up, tipped any way up to about 50 degrees, so from the side (as the
## player sees them) the leaves show their faces, not their edges.
static func _tilt(rng: RandomNumberGenerator) -> Vector3:
	return (Vector3.UP + Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))).normalized()


## The point `t` (0..1) of the way along the points `pts`.
static func _along(pts: Array[Vector3], t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(floori(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - i)


## A curve from `a` rising through `peak` and on to `tip` (a quadratic), `n` points.
static func _arch(a: Vector3, peak: Vector3, tip: Vector3, n: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for i in n:
		var t := float(i) / (n - 1)
		pts.append(a.lerp(peak, t).lerp(peak.lerp(tip, t), t))
	return pts


## A flat-topped head of small berries or flowers (an umbel or a corymb) at `c`: `n` of radius `r` over a disc of
## `rad`, on fine stalks from `stalk` below it.
static func _umbel(st: SurfaceTool, c: Vector3, rad: float, n: int, r: float, col: Color, stalk_col: Color,
		rng: RandomNumberGenerator, stalks := true) -> void:
	var base := c + Vector3.DOWN * rad * 0.6
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * rad
		var p := c + Vector3(cos(a) * d, -d * d / rad * 0.35 + rng.randf_range(-0.003, 0.003), sin(a) * d)
		if stalks and i % 3 == 0:
			_stem(st, base, p, 0.0008, 0.0006, stalk_col, 3)
		_blob(st, p, r * rng.randf_range(0.85, 1.15), col)


## Willow: a clump of slender stems from the ground, narrow pale leaves along their upper halves.
static func _willow(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var stems := rng.randi_range(8, 11)
	for i in stems:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var h := rng.randf_range(1.4, 2.4)
		var base := out * rng.randf_range(0.0, 0.12)
		var top := base + out * h * rng.randf_range(0.12, 0.35) + Vector3.UP * h
		var pts := _arch(base, base.lerp(top, 0.55) + Vector3.UP * 0.05, top, 5)
		_stems(st, pts, 0.012, 0.003, Color(0.5, 0.42, 0.22))
		for k in 38:
			var p := _along(pts, 0.25 + 0.75 * k / 37.0)
			var yaw := rng.randf() * TAU
			var d := Vector3(cos(yaw), rng.randf_range(0.1, 0.6), sin(yaw)).normalized()
			_leaf(st, p, d, _tilt(rng), rng.randf_range(0.13, 0.18), 0.034, Color(0.36, 0.48, 0.2), Color(0.5, 0.58, 0.28), 0.35, 0.1, 0.3, 2)
	return stems


## Slippery elm: a sapling, one grey trunk with a few spreading branches, big rough oval leaves hanging from them.
static func _elm(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var h := rng.randf_range(2.4, 3.4)
	var top := Vector3(rng.randf_range(-0.2, 0.2), h, rng.randf_range(-0.2, 0.2))
	_stem(st, Vector3.ZERO, top, 0.045, 0.012, Color(0.34, 0.29, 0.23), 6)
	var branches := rng.randi_range(7, 9)
	for i in branches:
		var t := rng.randf_range(0.35, 0.92)
		var p := top * t
		var a := TAU * i / branches + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), rng.randf_range(0.5, 1.0), sin(a)).normalized()
		var end := p + out * rng.randf_range(0.6, 0.95) * (1.35 - t)
		_stem(st, p, end, 0.014, 0.005, Color(0.36, 0.3, 0.24), 4)
		# twigs off the branch, each with its two rows of leaves
		for tw in 3:
			var q0 := p.lerp(end, 0.3 + 0.3 * tw)
			var tdir := (out + out.cross(Vector3.UP) * (1.0 if tw % 2 == 0 else -1.0) * 0.8 + Vector3.UP * 0.2).normalized()
			var q1 := q0 + tdir * rng.randf_range(0.2, 0.35)
			_stem(st, q0, q1, 0.006, 0.003, Color(0.36, 0.3, 0.24), 3)
			for k in 6:
				var q := q0.lerp(q1, 0.2 + 0.8 * k / 5.0)
				for s2: float in [-1.0, 1.0]:
					var d := (tdir.cross(Vector3.UP).normalized() * s2 + tdir * 0.4 + Vector3.DOWN * 0.3).normalized()
					_leaf(st, q, d, _tilt(rng), rng.randf_range(0.14, 0.18), 0.09, Color(0.2, 0.31, 0.08), Color(0.29, 0.39, 0.11), 0.45, 0.15, 0.25, 2)
		for k in 10:
			var q := p.lerp(end, 0.15 + 0.85 * k / 9.0)
			for s2: float in [-1.0, 1.0]:
				var side := out.cross(Vector3.UP).normalized() * s2
				var d := (side + out * 0.35 + Vector3.DOWN * 0.25 + Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))).normalized()
				_leaf(st, q, d, _tilt(rng), rng.randf_range(0.14, 0.18), 0.09, Color(0.2, 0.31, 0.08), Color(0.28, 0.38, 0.1), 0.45, 0.15, 0.25, 2)
	for k in 10:
		var d := Vector3(cos(TAU * k / 10.0), 0.5, sin(TAU * k / 10.0)).normalized()
		_leaf(st, top - Vector3.UP * 0.08 * (k % 2), d, _tilt(rng), 0.14, 0.075, Color(0.22, 0.33, 0.09), Color(0.3, 0.4, 0.11), 0.45, 0.15, 0.2, 2)
	return 1


## Elderberry: arching pale stems, leaves of five to seven leaflets in pairs; the fruit in flat heads of dark purple
## berries on red-purple stalks.
static func _elder(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var r := _srng(rng, fruit)
	var n := 0
	var stems := r.randi_range(6, 8)
	for i in stems:
		var a := TAU * i / stems + r.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0.0, sin(a))
		var base := out * r.randf_range(0.0, 0.1)
		var peak := base + out * r.randf_range(0.2, 0.4) + Vector3.UP * r.randf_range(1.4, 2.0)
		var tip := base + out * r.randf_range(0.6, 0.95) + Vector3.UP * r.randf_range(1.15, 1.55)
		var pts := _arch(base, peak, tip, 7)
		if not fruit:
			_stems(st, pts, 0.016, 0.006, Color(0.5, 0.45, 0.35))
			n += 1
		for k in range(2, 7):
			var p := pts[k]
			var along := (pts[mini(k + 1, 6)] - pts[k - 1]).normalized()
			if fruit:
				if k == 6 or k == 4:
					_umbel(st, p + Vector3.UP * 0.06 + out * 0.04, 0.075, 22, 0.0042, Color(0.13, 0.04, 0.13), Color(0.45, 0.12, 0.22), rng)
					n += 1
				continue
			for side: float in [-1.0, 1.0]:
				var sd := along.cross(Vector3.UP).normalized() * side
				var dir := (sd + Vector3.UP * 0.15 + along * 0.2).normalized()
				var end := p + dir * 0.2
				_stem(st, p, end, 0.003, 0.002, Color(0.32, 0.36, 0.16), 3)
				for j in 3:
					var q := p.lerp(end, 0.35 + 0.3 * j)
					for s2: float in [-1.0, 1.0]:
						var d := (dir.cross(Vector3.UP).normalized() * s2 + dir * 0.35).normalized()
						_leaf(st, q, d, _tilt(rng), 0.11, 0.042, Color(0.19, 0.33, 0.08), Color(0.26, 0.41, 0.1), 0.45, 0.2, 0.2, 2)
				_leaf(st, end, dir, _tilt(rng), 0.12, 0.045, Color(0.19, 0.33, 0.08), Color(0.26, 0.41, 0.1), 0.45, 0.2, 0.2, 2)
	return n


## Hemp: one tall green stalk, leaves of five to seven narrow toothed leaflets in pairs up it, a leafy flowering top.
static func _hemp(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var stalks := rng.randi_range(2, 3)
	for sk in stalks:
		var a0 := rng.randf() * TAU
		var base := Vector3(cos(a0), 0.0, sin(a0)) * rng.randf_range(0.0, 0.12) * float(sk)
		_hemp_stalk(st, rng, base, rng.randf_range(1.2, 1.9))
	return stalks


static func _hemp_stalk(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, h: float) -> void:
	var top := base + Vector3(rng.randf_range(-0.1, 0.1), h, rng.randf_range(-0.1, 0.1))
	_stem(st, base, top, 0.009, 0.004, Color(0.46, 0.56, 0.26), 5)
	for k in 8:
		var t := 0.18 + 0.72 * k / 7.0
		var p := base.lerp(top, t)
		for side in 2:
			var a := k * PI * 0.5 + side * PI
			var out := Vector3(cos(a), 0.2, sin(a)).normalized()
			var pet := p + out * 0.1 * (1.2 - t)
			_stem(st, p, pet, 0.0022, 0.0016, Color(0.46, 0.56, 0.26), 3)
			var nl := 7 if t < 0.6 else 5
			var up := _tilt(rng)
			for j in nl:
				var off := j - (nl - 1) * 0.5
				var d := (out.rotated(Vector3.UP, off * 0.33) + Vector3.DOWN * absf(off) * 0.06).normalized()
				var s := (1.25 - t) * (1.0 - absf(off) * 0.13)
				_leaf(st, pet, d, up, 0.22 * s, 0.045 * (1.25 - t), Color(0.2, 0.38, 0.1), Color(0.3, 0.48, 0.14), 0.45, 0.15, 0.25, 2)
	for j in 26:
		var a := rng.randf() * TAU
		var q := top + Vector3.DOWN * rng.randf_range(0.0, 0.25)
		var d := Vector3(cos(a), rng.randf_range(0.8, 2.2), sin(a)).normalized()
		_leaf(st, q, d, _tilt(rng), rng.randf_range(0.05, 0.08), 0.02, Color(0.3, 0.46, 0.15), Color(0.46, 0.56, 0.22), 0.4, 0.2, 0.05, 2)


static func _bearberry(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var r := _srng(rng, fruit)
	var n := 0
	var runners := r.randi_range(7, 9)
	for i in runners:
		var a := TAU * i / runners + r.randf_range(-0.5, 0.5)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := dir.cross(Vector3.UP)
		var pts: Array[Vector3] = []
		var l := r.randf_range(0.3, 0.55)
		for k in 7:
			var t := float(k) / 6.0
			pts.append(dir * l * t + side * sin(t * 5.0 + a) * 0.04 + Vector3.UP * (0.012 + 0.02 * sin(t * PI)))
		if not fruit:
			_stems(st, pts, 0.003, 0.002, Color(0.46, 0.24, 0.15))
			n += 1
		for k in range(1, 7):
			var p := pts[k]
			if fruit:
				if k % 3 == 1:
					_blob(st, p + Vector3.UP * 0.018 + side * 0.01, 0.0045, Color(0.8, 0.1, 0.06))
					n += 1
				continue
			for j in 5:
				var d := (dir.rotated(Vector3.UP, rng.randf_range(-1.5, 1.5)) + Vector3.UP * 0.45).normalized()
				_leaf(st, p + Vector3(rng.randf_range(-0.01, 0.01), 0.0, rng.randf_range(-0.01, 0.01)), d, Vector3.UP, 0.032, 0.017,
						Color(0.12, 0.3, 0.09), Color(0.2, 0.4, 0.12), 0.62, 0.2, 0.05, 3)
	return n


## Red-osier dogwood: a thicket of upright blood-red stems, oval leaves in pairs; white berries in flat clusters at the
## tips.
static func _osier(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var r := _srng(rng, fruit)
	var n := 0
	var stems := r.randi_range(9, 12)
	for i in stems:
		var a := r.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var h := r.randf_range(1.0, 1.8)
		var base := out * r.randf_range(0.0, 0.15)
		var top := base + out * h * r.randf_range(0.15, 0.3) + Vector3.UP * h
		var pts := _arch(base, base.lerp(top, 0.6) + Vector3.UP * 0.05, top, 5)
		if fruit:
			if i % 2 == 0:
				_umbel(st, top + Vector3.UP * 0.03, 0.045, 14, 0.004, Color(0.9, 0.9, 0.85), Color(0.6, 0.14, 0.12), rng)
				n += 1
			continue
		_stems(st, pts, 0.008, 0.003, Color(0.5, 0.1, 0.08))
		n += 1
		for k in 9:
			var p := _along(pts, 0.3 + 0.7 * k / 8.0)
			var along := (top - base).normalized()
			var sd := along.cross(Vector3.UP).normalized().rotated(along, k * PI * 0.5)
			for s2: float in [-1.0, 1.0]:
				var d := (sd * s2 + along * 0.3 + Vector3.DOWN * 0.1).normalized()
				_leaf(st, p, d, _tilt(rng), 0.12, 0.06, Color(0.2, 0.34, 0.1), Color(0.28, 0.42, 0.13), 0.45, 0.2, 0.2, 2)
	return n


## Jimsonweed: a forked, bushy green-purple plant, big coarse leaves; white trumpet flowers and spiny pods at the forks.
static func _jimson(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var r := _srng(rng, fruit)
	var n := 0
	var h := r.randf_range(0.6, 1.0)
	var fork := Vector3(r.randf_range(-0.04, 0.04), h * 0.5, r.randf_range(-0.04, 0.04))
	if not fruit:
		_stem(st, Vector3.ZERO, fork, 0.014, 0.01, Color(0.34, 0.3, 0.22), 5)
	var arms := r.randi_range(4, 5)
	for i in arms:
		var a := TAU * i / arms + r.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0.0, sin(a))
		var end := fork + out * r.randf_range(0.25, 0.4) + Vector3.UP * h * r.randf_range(0.35, 0.55)
		if fruit:
			var dir := (end - fork).normalized()
			if i % 2 == 0:
				var prof := [[0.004, 0.0], [0.006, 0.035], [0.011, 0.07], [0.03, 0.095], [0.032, 0.1]]
				_lathe(st, end, (dir + Vector3.UP).normalized(), prof, Color(0.8, 0.84, 0.7), Color(0.96, 0.95, 0.92), 8)
			else:
				_blob(st, end + Vector3.UP * 0.02, 0.018, Color(0.3, 0.42, 0.14), Vector3(1.0, 1.2, 1.0))
				for k in 10:
					var sd := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.6, 1.0), r.randf_range(-1.0, 1.0)).normalized()
					_stem(st, end + Vector3.UP * 0.02 + sd * 0.016, end + Vector3.UP * 0.02 + sd * 0.026, 0.0016, 0.0003, Color(0.36, 0.44, 0.16), 3)
			n += 1
			continue
		_stem(st, fork, end, 0.009, 0.005, Color(0.34, 0.3, 0.22), 4)
		for k in 5:
			var p := fork.lerp(end, 0.15 + 0.2 * k)
			var yaw := a + (k - 2) * 0.9 + rng.randf_range(-0.3, 0.3)
			var d := Vector3(cos(yaw), 0.15, sin(yaw)).normalized()
			_leaf(st, p, d, _tilt(rng), rng.randf_range(0.17, 0.22), 0.12, Color(0.15, 0.29, 0.07), Color(0.21, 0.36, 0.09), 0.45, 0.12, 0.28, 5)
	return maxi(n, 1) if not fruit else n


## Crabapple: a small crooked tree, a short trunk and three or four crooked limbs with twigs, the leaves in dense
## clusters along them; small yellow-green and red apples hanging from the clusters in the fall.
static func _crab(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var r := _srng(rng, fruit)
	var n := 0
	var crotch := Vector3(r.randf_range(-0.1, 0.1), r.randf_range(0.8, 1.05), r.randf_range(-0.1, 0.1))
	if not fruit:
		_stem(st, Vector3.ZERO, crotch, 0.07, 0.05, Color(0.3, 0.25, 0.2), 6)
		n += 1
	var limbs := r.randi_range(4, 5)
	for i in limbs:
		var a := TAU * i / limbs + r.randf_range(-0.35, 0.35)
		var out := Vector3(cos(a), 0.0, sin(a))
		var pts: Array[Vector3] = [crotch]
		for k in 3:
			var bend := out.rotated(Vector3.UP, r.randf_range(-0.5, 0.5))
			pts.append(pts[k] + bend * r.randf_range(0.28, 0.42) + Vector3.UP * r.randf_range(0.22, 0.42))
		if not fruit:
			_stems(st, pts, 0.04, 0.008, Color(0.31, 0.26, 0.21))
		# the leaves in clusters all along the limb and on short twigs off it: a full, rounded crown
		for k in 11:
			var p := _along(pts, 0.2 + 0.8 * k / 10.0)
			var tw := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.1, 0.8), r.randf_range(-1.0, 1.0)).normalized()
			var c := p + tw * r.randf_range(0.15, 0.32)
			if fruit:
				if k % 2 == 1:
					for f in rng.randi_range(2, 4):
						var at := c + Vector3(rng.randf_range(-0.08, 0.08), -0.09, rng.randf_range(-0.08, 0.08))
						_stem(st, c, at + Vector3.UP * 0.015, 0.0012, 0.001, Color(0.35, 0.3, 0.14), 3)
						_blob(st, at, 0.02, Color(0.74, 0.66, 0.2) if rng.randf() < 0.55 else Color(0.72, 0.3, 0.13), Vector3(1.0, 0.9, 1.0))
						n += 1
				continue
			_stem(st, p, c, 0.008, 0.004, Color(0.33, 0.27, 0.21), 3)
			for j in 13:
				var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.9), rng.randf_range(-1.0, 1.0)).normalized()
				_leaf(st, c + d * rng.randf_range(0.02, 0.1), d, _tilt(rng), rng.randf_range(0.13, 0.17), 0.085,
						Color(0.17, 0.3, 0.07), Color(0.26, 0.4, 0.1), 0.45, 0.15, 0.25, 3)
	return n


## Yarrow: a few upright stems with fine feathery leaves, a rosette of them at the foot; flat white flower heads.
static func _yarrow(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var r := _srng(rng, fruit)
	var n := 0
	var stems := r.randi_range(5, 7)
	for i in stems:
		var a := r.randf() * TAU
		var h := r.randf_range(0.35, 0.6)
		var top := Vector3(cos(a) * 0.05, h, sin(a) * 0.05) + Vector3(r.randf_range(-0.04, 0.04), 0.0, r.randf_range(-0.04, 0.04))
		if fruit:
			_umbel(st, top + Vector3.UP * 0.01, 0.035, 26, 0.0032, Color(0.93, 0.92, 0.85), Color(0.36, 0.42, 0.2), rng, false)
			n += 1
			continue
		_stem(st, Vector3.ZERO, top, 0.0028, 0.002, Color(0.5, 0.58, 0.3), 3)
		n += 1
		for k in 5:
			var p := top * (0.2 + 0.14 * k)
			var yaw := rng.randf() * TAU
			_leaf(st, p, Vector3(cos(yaw), 0.35, sin(yaw)), Vector3.UP, 0.08, 0.02, Color(0.28, 0.42, 0.16), Color(0.36, 0.5, 0.2), 0.4, 0.3, 0.15, 3)
	if not fruit:
		for k in 7:
			var yaw := TAU * k / 7.0
			_leaf(st, Vector3.UP * 0.01, Vector3(cos(yaw), 0.25, sin(yaw)), Vector3.UP, 0.13, 0.026, Color(0.28, 0.42, 0.16), Color(0.36, 0.5, 0.2), 0.4, 0.3, 0.2, 4)
	return n


## A curled strip of bark: `outer` its outside, a narrower stripe of `inner`, the inner bark, down its middle.
# --- The woods' materials -----------------------------------------------------------------------------------

## Dry sticks: four to seven dead sticks lying crossed on the litter, bent a little, a fork on some.
static func _sticks(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var n := rng.randi_range(4, 7)
	for i in n:
		var a := rng.randf() * TAU
		var d := Vector3(cos(a), 0.0, sin(a))
		var l := rng.randf_range(0.4, 0.9)
		var c := Vector3(rng.randf_range(-0.22, 0.22), 0.0, rng.randf_range(-0.22, 0.22))
		var rad := rng.randf_range(0.011, 0.022)
		var lift := Vector3.UP * (rad + 0.006 * i)
		var a0 := c - d * l * 0.5 + lift
		var b0 := c + d * l * 0.5 + lift + Vector3.UP * rng.randf_range(0.0, 0.02)
		var m0 := a0.lerp(b0, 0.5) + d.cross(Vector3.UP) * rng.randf_range(-0.03, 0.03)
		var col := Color(0.26, 0.2, 0.15).lerp(Color(0.36, 0.3, 0.23), rng.randf())
		_stem(st, a0, m0, rad, rad * 0.8, col, 6)
		_stem(st, m0, b0, rad * 0.8, rad * 0.5, col, 6)
		if rng.randf() < 0.6:
			var f := a0.lerp(b0, rng.randf_range(0.35, 0.7))
			var fd := d.rotated(Vector3.UP, rng.randf_range(0.4, 0.8) * (1.0 if rng.randf() < 0.5 else -1.0))
			_stem(st, f, f + fd * l * rng.randf_range(0.2, 0.4) + Vector3.UP * 0.01, rad * 0.6, rad * 0.3, col, 5)
	return n


## A fallen dead limb: a bent main limb 1.6-2.6 m long, side branches, broken stubs, grey-green lichen on the bark.
static func _windfall(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var a := rng.randf() * TAU
	var d := Vector3(cos(a), 0.0, sin(a))
	var sd := d.cross(Vector3.UP)
	var l := rng.randf_range(1.6, 2.6)
	var r0 := rng.randf_range(0.055, 0.08)
	var bend := rng.randf_range(-0.12, 0.12)
	var pts: Array[Vector3] = []
	for k in 7:
		var t := k / 6.0
		pts.append(d * l * (t - 0.5) + sd * sin(t * PI) * bend + Vector3.UP * r0 * (1.0 - t * 0.45))
	var bark := Color(0.2, 0.16, 0.12)
	for k in pts.size() - 1:
		_stem(st, pts[k], pts[k + 1], lerpf(r0, r0 * 0.35, k / 6.0), lerpf(r0, r0 * 0.35, (k + 1) / 6.0), bark.lerp(Color(0.27, 0.22, 0.17), k / 6.0), 8)
	# the butt end broken off, pale wood showing
	var ax := (pts[1] - pts[0]).normalized()
	var ux := ax.cross(Vector3.UP).normalized()
	var uy := ax.cross(ux).normalized()
	for k in 8:
		var q0 := pts[0] + (ux * cos(TAU * k / 8.0) + uy * sin(TAU * k / 8.0)) * r0
		var q1 := pts[0] + (ux * cos(TAU * (k + 1) / 8.0) + uy * sin(TAU * (k + 1) / 8.0)) * r0
		_tri(st, pts[0] - ax * 0.004, Color(0.52, 0.44, 0.32), q0, Color(0.44, 0.37, 0.27), q1, Color(0.44, 0.37, 0.27), -ax)
	for i in rng.randi_range(3, 5):
		var t := rng.randf_range(0.2, 0.85)
		var p := _along(pts, t)
		var r1 := lerpf(r0, r0 * 0.35, t) * 0.55
		var bd := d.rotated(Vector3.UP, rng.randf_range(0.5, 1.1) * (1.0 if i % 2 == 0 else -1.0))
		var len := rng.randf_range(0.25, 0.7)
		if rng.randf() < 0.3:
			len = rng.randf_range(0.05, 0.1)   # a broken stub
		var tip := p + bd * len + Vector3.UP * rng.randf_range(-0.01, 0.06)
		tip.y = maxf(tip.y, r1)
		_stem(st, p, tip, r1, r1 * 0.35, bark.lightened(0.04), 6)
	for i in rng.randi_range(3, 6):
		var p := _along(pts, rng.randf_range(0.1, 0.9)) + Vector3.UP * r0 * 0.75
		_blob(st, p, rng.randf_range(0.02, 0.035), Color(0.34, 0.37, 0.28).lerp(Color(0.42, 0.45, 0.34), rng.randf()), Vector3(1.0, 0.25, 1.0))
	return 1


## Arrowwood: a dense shrub of long straight shoots from the root, leaning out a little, thick with oval toothed leaves
## in pairs.
static func _arrowwood(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var n := rng.randi_range(10, 14)
	for i in n:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var h := rng.randf_range(1.3, 2.1)
		var base := out * rng.randf_range(0.0, 0.2)
		var top := base + out * h * rng.randf_range(0.12, 0.28) + Vector3.UP * h
		_stem(st, base, top, 0.01, 0.004, Color(0.26, 0.23, 0.18).lerp(Color(0.33, 0.29, 0.22), rng.randf()), 5)
		var along := (top - base).normalized()
		var side := along.cross(Vector3.UP).normalized()
		for k in 11:
			var p := base.lerp(top, 0.3 + 0.7 * k / 10.0)
			var sd := side.rotated(along, k * PI * 0.5)
			for s2: float in [-1.0, 1.0]:
				var dl := (sd * s2 + along * 0.3 + Vector3.DOWN * 0.15).normalized()
				_leaf(st, p, dl, _tilt(rng), 0.1, 0.075, Color(0.12, 0.24, 0.07), Color(0.19, 0.32, 0.1), 0.45, 0.2, 0.15, 3)
	return n


## Pine pitch on the bark (+Z out of the bark, +Y up the trunk): the wound crusted pale; the fruit amber beads and
## runs of resin down from it.
static func _pitch(st: SurfaceTool, rng: RandomNumberGenerator, fruit: bool) -> int:
	var r := _srng(rng, fruit)
	var h := r.randf_range(0.16, 0.26)
	if not fruit:
		_leaf(st, Vector3(0.0, -h * 0.45, 0.02), Vector3.UP, Vector3.BACK, h * 0.7, r.randf_range(0.045, 0.065),
				Color(0.34, 0.26, 0.16), Color(0.44, 0.35, 0.22), 0.5, -0.1, 0.0, 5)
		return 1
	for i in r.randi_range(4, 7):
		var p := Vector3(r.randf_range(-0.03, 0.03), r.randf_range(-h * 0.5, h * 0.3), 0.024)
		var len := r.randf_range(0.015, 0.05)
		var rad := r.randf_range(0.007, 0.013)
		var col := Color(0.5, 0.26, 0.04).lerp(Color(0.8, 0.5, 0.12), r.randf())
		# a drip: round at the bottom, drawn out upward
		var prof := [[0.0, 0.0], [rad * 0.8, rad * 0.3], [rad, rad * 0.9], [rad * 0.7, len * 0.6], [rad * 0.35, len], [0.0, len + rad * 0.3]]
		_lathe(st, p, Vector3.UP, prof, col.darkened(0.1), col.lightened(0.15), 8)
	return 1


## Leaf litter scratched back by turkeys: dry oak leaves thrown into a ring round the bare spot (the ground itself
## shows through: the grass is cleared).
static func _scratch(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var rad := rng.randf_range(0.2, 0.3)
	for i in rng.randi_range(6, 9):
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0.0, sin(a)) * rad * rng.randf_range(0.9, 1.5) + Vector3.UP * 0.006
		var d := Vector3(cos(a + rng.randf_range(-1.0, 1.0)), 0.05, sin(a + rng.randf_range(-1.0, 1.0)))
		var brown := Color(0.34, 0.24, 0.12).lerp(Color(0.44, 0.31, 0.15), rng.randf())
		_leaf(st, base, d, Vector3.UP, 0.11, 0.065, brown, brown.lightened(0.08), 0.55, -0.1, 0.0, 4)
	return 1


## Loose fieldstones: two to four rounded stones of the till, half sunk, grey with a warmer or a greener cast.
static func _fieldstones(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var n := rng.randi_range(2, 4)
	for i in n:
		var r := rng.randf_range(0.07, 0.14)
		var c := Vector3(rng.randf_range(-0.3, 0.3), r * 0.25, rng.randf_range(-0.3, 0.3))
		var col := Color(0.27, 0.24, 0.2).lerp([Color(0.31, 0.26, 0.2), Color(0.24, 0.24, 0.2), Color(0.29, 0.27, 0.24)][i % 3], rng.randf())
		_stone(st, c, r, Vector3(rng.randf_range(0.9, 1.3), rng.randf_range(0.55, 0.8), rng.randf_range(0.85, 1.2)), col, rng)
	return n


## Chert nodules: two or three knobbly lumps in a pale weathered rind; one broken open, the dark glassy inside showing.
static func _nodules(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var n := rng.randi_range(2, 3)
	for i in n:
		var r := rng.randf_range(0.045, 0.075)
		var c := Vector3(rng.randf_range(-0.18, 0.18), r * 0.4, rng.randf_range(-0.18, 0.18))
		var rind := Color(0.31, 0.28, 0.23).lerp(Color(0.25, 0.22, 0.18), rng.randf())
		_stone(st, c, r, Vector3(rng.randf_range(1.0, 1.5), rng.randf_range(0.7, 0.9), rng.randf_range(0.8, 1.1)), rind, rng)
		# a knob or two
		for k in rng.randi_range(1, 2):
			var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.0, 0.6), rng.randf_range(-1.0, 1.0)).normalized()
			_stone(st, c + d * r * 0.8, r * 0.45, Vector3.ONE, rind.darkened(0.05), rng)
		if i == 0:
			# broken open: a flat dark face
			var up := Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.4, 0.4)).normalized()
			var side := up.cross(Vector3.RIGHT).normalized()
			var fwd := up.cross(side)
			var inside := Color(0.1, 0.09, 0.085)
			for k in 8:
				var a0 := TAU * k / 8.0
				var a1 := TAU * (k + 1) / 8.0
				var p0 := c + up * r * 0.72 + (side * cos(a0) + fwd * sin(a0)) * r * 0.62
				var p1 := c + up * r * 0.72 + (side * cos(a1) + fwd * sin(a1)) * r * 0.62
				_tri(st, c + up * r * 0.74, inside.lightened(0.1), p0, inside, p1, inside, up)
	return n


## A dead sapling lying whole: a long thin grey pole, straight, its twigs broken short, the root end a knot.
static func _dead_pole(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var a := rng.randf() * TAU
	var d := Vector3(cos(a), 0.0, sin(a))
	var l := rng.randf_range(2.4, 3.2)
	var r0 := rng.randf_range(0.03, 0.04)
	var a0 := -d * l * 0.5 + Vector3.UP * r0
	var b0 := d * l * 0.5 + Vector3.UP * r0 * 0.5
	var col := Color(0.29, 0.24, 0.19)
	var m := a0.lerp(b0, 0.5) + d.cross(Vector3.UP) * rng.randf_range(-0.04, 0.04)
	_stem(st, a0, m, r0, r0 * 0.75, col, 7)
	_stem(st, m, b0, r0 * 0.75, r0 * 0.35, col.lightened(0.04), 6)
	_stone(st, a0 - d * 0.03, r0 * 1.5, Vector3(1.0, 0.8, 1.0), Color(0.28, 0.24, 0.2), rng)
	for i in rng.randi_range(4, 7):
		var p := a0.lerp(b0, rng.randf_range(0.3, 0.95))
		var bd := (d.rotated(Vector3.UP, rng.randf_range(0.6, 1.2) * (1.0 if i % 2 == 0 else -1.0)) + Vector3.UP * 0.3).normalized()
		_stem(st, p, p + bd * rng.randf_range(0.04, 0.12), r0 * 0.3, r0 * 0.15, col, 4)
	return 1


## Bog iron: three to five rusty knobbly lumps, dark brown to orange where the mud is rubbed off.
static func _bog_ore(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var n := rng.randi_range(3, 5)
	for i in n:
		var r := rng.randf_range(0.04, 0.07)
		var c := Vector3(rng.randf_range(-0.2, 0.2), r * 0.35, rng.randf_range(-0.2, 0.2))
		var col := Color(0.2, 0.11, 0.06).lerp(Color(0.3, 0.16, 0.08), rng.randf())
		_stone(st, c, r, Vector3(rng.randf_range(1.0, 1.4), rng.randf_range(0.6, 0.85), rng.randf_range(0.9, 1.2)), col, rng)
		_stone(st, c + Vector3(rng.randf_range(-1.0, 1.0), 0.3, rng.randf_range(-1.0, 1.0)).normalized() * r * 0.8, r * 0.45, Vector3.ONE, col.darkened(0.1), rng)
	return n


## Clay: lumps of grey-blue clay cut from a bank, one a slab with a flat face.
static func _clay(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var clay := Color(0.27, 0.27, 0.25)
	_stone(st, Vector3(0.0, 0.05, 0.0), 0.14, Vector3(1.4, 0.55, 1.0), clay, rng)
	for i in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		_stone(st, Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.18, 0.3) + Vector3.UP * 0.03, rng.randf_range(0.05, 0.08),
				Vector3(1.2, 0.7, 1.0), clay.lerp(Color(0.31, 0.3, 0.27), rng.randf()), rng)
	return 1


## A rounded stone at `c`: a squashed, lumpy ball of radius `r` stretched by `s`.
static func _stone(st: SurfaceTool, c: Vector3, r: float, s: Vector3, col: Color, rng: RandomNumberGenerator) -> void:
	var rings := 5
	var segs := 9
	var pts := []
	for i in rings + 1:
		var v := PI * i / rings
		var row := []
		for k in segs:
			var u := TAU * k / segs
			var bump := 1.0 + rng.randf_range(-0.12, 0.12) * sin(v)
			row.append(Vector3(sin(v) * cos(u) * s.x, cos(v) * s.y, sin(v) * sin(u) * s.z) * r * bump)
		pts.append(row)
	for i in rings:
		for k in segs:
			var q00: Vector3 = pts[i][k]
			var q01: Vector3 = pts[i][(k + 1) % segs]
			var q10: Vector3 = pts[i + 1][k]
			var q11: Vector3 = pts[i + 1][(k + 1) % segs]
			var c0 := col.lightened(0.06) if i < 2 else col.darkened(0.08 * (i - 1))
			var n0 := ((q00 + q01 + q11) / 3.0).normalized()
			var n1 := ((q00 + q11 + q10) / 3.0).normalized()
			_tri(st, c + q00, c0, c + q01, c0, c + q11, c0, n0, q00.normalized(), q01.normalized(), q11.normalized())
			_tri(st, c + q00, c0, c + q11, c0, c + q10, c0, n1, q00.normalized(), q11.normalized(), q10.normalized())


## One or two turkey feathers lying on the scratched ground: a quill, the vane barred brown and buff.
static func _feathers(st: SurfaceTool, rng: RandomNumberGenerator) -> int:
	var n := rng.randi_range(1, 2)
	for i in n:
		var a := rng.randf() * TAU
		var d := Vector3(cos(a), 0.0, sin(a))
		var c := Vector3(rng.randf_range(-0.08, 0.08), 0.01 + 0.003 * i, rng.randf_range(-0.08, 0.08))
		_feather(st, c - d * 0.15, d, Vector3.UP, rng.randf_range(0.28, 0.36), rng.randf() < 0.5)
	return n


## A feather from `base` along `dir`, flat to `up`: the quill, and the vane dark brown with narrow buff bars (a wing
## feather) or bronze with a dark band and a buff tip (a tail feather).
static func _feather(st: SurfaceTool, base: Vector3, dir: Vector3, up: Vector3, l: float, tail: bool) -> void:
	dir = dir.normalized()
	var side := dir.cross(up).normalized()
	_stem(st, base, base + dir * l, 0.0022, 0.0008, Color(0.7, 0.66, 0.56), 3)
	var segs := 16
	for k in segs:
		var t0 := float(k) / segs
		var t1 := float(k + 1) / segs
		var w0 := sin(clampf(t0 * 1.3, 0.0, 1.0) * PI * 0.5) * (1.0 - pow(t0, 4.0)) * l * 0.1
		var w1 := sin(clampf(t1 * 1.3, 0.0, 1.0) * PI * 0.5) * (1.0 - pow(t1, 4.0)) * l * 0.1
		var col := Color(0.2, 0.14, 0.09)
		if tail:
			col = Color(0.33, 0.23, 0.12) if t0 < 0.75 else (Color(0.1, 0.08, 0.06) if t0 < 0.87 else Color(0.6, 0.5, 0.36))
		elif k % 3 == 1:
			col = Color(0.44, 0.39, 0.3)
		var m0 := base + dir * l * t0 + up * 0.001
		var m1 := base + dir * l * t1 + up * 0.001
		for sgn: float in [1.0, -0.7]:
			_tri(st, m0, col, m0 + side * w0 * sgn, col, m1 + side * w1 * sgn, col, up)
			_tri(st, m0, col, m1 + side * w1 * sgn, col, m1, col, up)


static func _bark_strip(st: SurfaceTool, at: Vector3, dir: Vector3, l: float, w: float, outer: Color, inner: Color) -> void:
	_leaf(st, at, dir, Vector3.UP, l, w, outer, outer.lightened(0.12), 0.5, 0.7, 0.0, 5)
	_leaf(st, at + Vector3.UP * 0.0015, dir, Vector3.UP, l * 0.9, w * 0.4, inner, inner.lightened(0.08), 0.5, 0.3, 0.0, 5)


## A round fruit or pod (turned, rounder than a _blob) at `c`, radius `r`, a little flattened.
static func _ball(st: SurfaceTool, c: Vector3, r: float, col0: Color, col1: Color) -> void:
	var prof := []
	for k in 7:
		var a := PI * k / 6.0
		prof.append([sin(a) * r, -cos(a) * r * 0.9])
	_lathe(st, c, Vector3.UP, prof, col0, col1, 10)


# --- Icons ---------------------------------------------------------------------------------------------------

static func has(item: String) -> bool:
	return item in ITEMS


## A small model of `item` for its icon (ItemIcons): a handful of it.
static func build(item: String) -> Node3D:
	var top := Node3D.new()
	top.name = "Forage_" + item
	# the icon camera looks at the side from +X: things that lie flat are turned to show their top, three quarters on
	var root := Node3D.new()
	root.name = "View"
	if item in ["blackberries", "strawberries", "plantain", "acorns", "willow_bark", "elm_bark", "dogwood_bark",
			"elderberries", "crabapples", "feathers"]:
		root.rotation = Vector3(0.0, 0.0, deg_to_rad(-62.0))
	top.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat: Material = fruit_material()
	match item:
		"blackberries":
			for i in 7:
				var a := TAU * i / 7.0
				var bp := Vector3(cos(a) * 0.014 * float(i % 3 > 0), 0.008 + 0.012 * float(i == 6), sin(a) * 0.014 * float(i % 3 > 0))
				_blackberry(st, bp, bp + Vector3.UP * 0.009, rng, true)
		"strawberries":
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				var at := Vector3(cos(a) * 0.012, 0.009, sin(a) * 0.012)
				_strawberry_fruit(st, at, 0.0085, Vector3(cos(a), -0.15, sin(a)).normalized())
		"acorns":
			for i in 3:
				var one := SurfaceTool.new()
				one.begin(Mesh.PRIMITIVE_TRIANGLES)
				_acorn(one, rng)
				var mi := MeshInstance3D.new()
				mi.mesh = one.commit()
				mi.mesh.surface_set_material(0, mat)
				mi.position = Vector3((i - 1) * 0.022, 0.0, (i % 2) * 0.012)
				root.add_child(mi)
			return top
		"hazelnuts":
			_nut_cluster(st, rng)
		"plantain":
			mat = leaf_material("plantain")
			for i in 3:
				var d := Vector3((i - 1) * 0.35, 0.0, -1.0).normalized()
				_leaf(st, Vector3.ZERO, d, Vector3.UP, 0.14, 0.085, Color(0.19, 0.32, 0.08), Color(0.25, 0.38, 0.1), 0.45, 0.18, 0.0, 6)
		"wintergreen":
			mat = leaf_material("wintergreen")
			_stem(st, Vector3.ZERO, Vector3(0, 0.08, 0), 0.002, 0.0017, Color(0.35, 0.22, 0.12), 3)
			for k in 3:
				_leaf(st, Vector3(0, 0.08, 0), Vector3(cos(TAU * k / 3.0), 0.3, sin(TAU * k / 3.0)), Vector3.UP, 0.04, 0.024, Color(0.05, 0.18, 0.07), Color(0.09, 0.25, 0.09), 0.5, 0.35, 0.1)
			var b := SurfaceTool.new()
			b.begin(Mesh.PRIMITIVE_TRIANGLES)
			_blob(b, Vector3(0.012, 0.055, 0.0), 0.0055, Color(0.75, 0.05, 0.05))
			_blob(b, Vector3(-0.008, 0.05, 0.01), 0.0055, Color(0.75, 0.05, 0.05))
			var bm := MeshInstance3D.new()
			bm.mesh = b.commit()
			bm.mesh.surface_set_material(0, fruit_material())
			root.add_child(bm)
		"ginseng":
			# the root: a pale forked taproot with a few fine rootlets
			mat = fruit_material()
			var tan := Color(0.78, 0.66, 0.46)
			_stem(st, Vector3(0, 0.0, 0), Vector3(0.0, -0.05, 0.004), 0.009, 0.011, tan, 6)
			_stem(st, Vector3(0.0, -0.05, 0.004), Vector3(0.012, -0.09, 0.0), 0.009, 0.004, tan, 6)
			_stem(st, Vector3(0.0, -0.045, 0.004), Vector3(-0.016, -0.085, 0.006), 0.007, 0.003, tan, 6)
			_stem(st, Vector3(0.012, -0.09, 0.0), Vector3(0.02, -0.12, -0.004), 0.004, 0.001, tan, 4)
			_stem(st, Vector3(-0.016, -0.085, 0.006), Vector3(-0.03, -0.11, 0.01), 0.003, 0.001, tan, 4)
			_stem(st, Vector3(0, 0.0, 0), Vector3(0.0, 0.03, 0.0), 0.0035, 0.003, Color(0.55, 0.45, 0.3), 4)
		"willow_bark", "elm_bark", "dogwood_bark":
			# three curled strips of the bark, the inner bark showing
			mat = leaf_material("bark")
			var outer: Color = {"willow_bark": Color(0.42, 0.38, 0.26), "elm_bark": Color(0.28, 0.22, 0.18),
					"dogwood_bark": Color(0.58, 0.1, 0.08)}[item]
			var inner: Color = {"willow_bark": Color(0.7, 0.66, 0.44), "elm_bark": Color(0.78, 0.56, 0.4),
					"dogwood_bark": Color(0.62, 0.66, 0.36)}[item]
			for i in 3:
				_bark_strip(st, Vector3(-0.06, 0.004 * i, (i - 1) * 0.022), Vector3(1.0, 0.0, (i - 1) * 0.12), 0.12, 0.026, outer, inner)
		"shoots":
			# a bundle of straight arrowwood shoots, tied with bark
			mat = matte_material()
			for i in 6:
				var o := Vector3(0.0, (i % 3) * 0.009 - 0.009, (i / 3) * 0.009 - 0.0045)
				_stem(st, o + Vector3(0, 0, -0.16), o + Vector3(0, 0, 0.16), 0.0045, 0.003, Color(0.3, 0.27, 0.2).lerp(Color(0.4, 0.35, 0.26), i / 6.0), 5)
			_stem(st, Vector3(0, 0, -0.01), Vector3(0, 0, 0.01), 0.017, 0.017, Color(0.35, 0.27, 0.18), 6)
		"bog_iron":
			mat = matte_material()
			for i in 3:
				_stone(st, Vector3((i - 1) * 0.03, 0.02, (i % 2) * 0.02), 0.022, Vector3(1.2, 0.8, 1.0), Color(0.24, 0.13, 0.07).lerp(Color(0.34, 0.18, 0.09), i / 2.0), rng)
		"clay":
			mat = matte_material()
			_stone(st, Vector3(0, 0.025, 0), 0.05, Vector3(1.3, 0.6, 1.0), Color(0.32, 0.32, 0.3), rng)
		"pine_pitch":
			# three lumps of amber pitch
			for i in 3:
				var col := Color(0.55, 0.28, 0.05).lerp(Color(0.82, 0.52, 0.13), i / 2.0)
				_ball(st, Vector3((i - 1) * 0.022, 0.011, (i % 2) * 0.014), 0.013 - i * 0.002, col.darkened(0.1), col.lightened(0.12))
		"feathers":
			# three turkey feathers fanned: two barred wing feathers and a banded tail feather
			mat = matte_material()
			for i in 3:
				var d := Vector3(1.0, 0.0, (i - 1) * 0.28).normalized()
				_feather(st, Vector3(-0.1, 0.002 * i, 0.0), d, Vector3.UP, 0.22, i == 2)
		"elderberries":
			_umbel(st, Vector3(0, 0.03, 0), 0.032, 34, 0.0042, Color(0.13, 0.04, 0.13), Color(0.45, 0.12, 0.22), rng)
			_stem(st, Vector3(0, -0.01, 0), Vector3(0, 0.012, 0), 0.0018, 0.0015, Color(0.45, 0.12, 0.22), 3)
		"crabapples":
			for i in 3:
				var at := Vector3((i - 1) * 0.034, 0.017, (i % 2) * 0.02)
				var c: Color = [Color(0.74, 0.66, 0.2), Color(0.72, 0.3, 0.13), Color(0.7, 0.55, 0.18)][i]
				_ball(st, at, 0.017, c.darkened(0.15), c.lightened(0.1))
				_stem(st, at + Vector3.UP * 0.014, at + Vector3(0.004, 0.03, 0.0), 0.0014, 0.001, Color(0.35, 0.3, 0.14), 3)
		"yarrow", "hemp_tops", "bearberry", "jimsonweed":
			mat = leaf_material(item)
			var fr := SurfaceTool.new()
			fr.begin(Mesh.PRIMITIVE_TRIANGLES)
			match item:
				"yarrow":
					_stem(st, Vector3.ZERO, Vector3(0, 0.13, 0), 0.0025, 0.002, Color(0.36, 0.42, 0.22), 3)
					for k in 6:
						var yaw := TAU * k / 6.0
						_leaf(st, Vector3(0, 0.02 + 0.015 * k, 0), Vector3(cos(yaw), 0.4, sin(yaw)), Vector3.UP, 0.055, 0.012,
								Color(0.24, 0.37, 0.14), Color(0.3, 0.44, 0.17), 0.4, 0.3, 0.15, 3)
					_umbel(fr, Vector3(0, 0.135, 0), 0.03, 26, 0.0035, Color(0.93, 0.92, 0.85), Color(0.36, 0.42, 0.2), rng, false)
				"hemp_tops":
					_stem(st, Vector3.ZERO, Vector3(0, 0.14, 0), 0.004, 0.0025, Color(0.3, 0.4, 0.15), 4)
					for j in 16:
						var a := rng.randf() * TAU
						_leaf(st, Vector3(0, rng.randf_range(0.05, 0.13), 0), Vector3(cos(a), rng.randf_range(0.8, 2.0), sin(a)), Vector3.UP,
								rng.randf_range(0.03, 0.05), 0.01, Color(0.26, 0.4, 0.13), Color(0.4, 0.5, 0.2), 0.4, 0.2, 0.05, 3)
					for j in 7:
						var off := j - 3.0
						_leaf(st, Vector3(0, 0.03, 0), Vector3(1.0, 0.1, 0.0).rotated(Vector3.UP, off * 0.33 + PI * 0.5), Vector3.UP,
								0.1 * (1.0 - absf(off) * 0.13), 0.014, Color(0.17, 0.33, 0.09), Color(0.25, 0.42, 0.12), 0.45, 0.15, 0.2, 4)
				"bearberry":
					_stem(st, Vector3(-0.06, 0, 0), Vector3(0.06, 0.01, 0), 0.0025, 0.0018, Color(0.42, 0.22, 0.14), 3)
					for k in 9:
						var p := Vector3(-0.05 + 0.012 * k, 0.006, 0)
						var yaw := k * 2.1
						_leaf(st, p, Vector3(cos(yaw), 0.4, sin(yaw)), Vector3.UP, 0.024, 0.012, Color(0.08, 0.24, 0.07), Color(0.14, 0.32, 0.09), 0.62, 0.2, 0.05, 3)
					_blob(fr, Vector3(0.02, 0.012, 0.012), 0.0055, Color(0.8, 0.1, 0.06))
					_blob(fr, Vector3(0.028, 0.01, -0.006), 0.0055, Color(0.8, 0.1, 0.06))
				"jimsonweed":
					# a leaf, a white trumpet flower and a spiny pod
					_leaf(st, Vector3(-0.08, 0, 0.02), Vector3(1, 0.05, -0.2), Vector3.UP, 0.13, 0.08, Color(0.15, 0.29, 0.07), Color(0.21, 0.36, 0.09), 0.45, 0.12, 0.0, 5)
					var prof := [[0.004, 0.0], [0.006, 0.035], [0.011, 0.07], [0.028, 0.095], [0.03, 0.1]]
					_lathe(fr, Vector3(-0.03, 0.01, -0.02), Vector3(0.3, 1.0, -0.6).normalized(), prof, Color(0.78, 0.82, 0.68), Color(0.97, 0.96, 0.93), 10)
					var pod := Vector3(0.03, 0.03, 0.015)
					_ball(fr, pod, 0.02, Color(0.26, 0.38, 0.12), Color(0.36, 0.48, 0.16))
					for k in 22:
						var sd := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.7, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
						_stem(fr, pod + sd * 0.017, pod + sd * 0.032, 0.0022, 0.0003, Color(0.4, 0.48, 0.18), 3)
			if item != "hemp_tops":
				var fm := MeshInstance3D.new()
				fm.mesh = fr.commit()
				if fm.mesh.get_surface_count() > 0:
					fm.mesh.surface_set_material(0, fruit_material())
					root.add_child(fm)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	if m.mesh.get_surface_count() > 0:
		m.mesh.surface_set_material(0, mat)
	root.add_child(m)
	return top
