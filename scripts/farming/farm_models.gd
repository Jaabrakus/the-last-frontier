class_name FarmModels
## The farm's models, built in code from ForageModels' parts (leaves, stalks, berries; vertex coloured, the forage
## plants' materials), so the crops sit in the same painted world as the wild plants:
##
##   crop_mesh(crop, stage, v, dead)   one hill's plants of `crop` ("corn", "beans", "squash", "tobacco", "flax";
##                                     "bush_beans": beans with no corn to climb) at `stage` 0 sprout, 1 young,
##                                     2 grown, 3 ripe; `dead`: killed by frost, brown and fallen
##   weeds_mesh(v)                     a few weeds come up in a bed that wants hoeing
##   bed_mesh(hills, heights, broken)  the worked soil of a bed: dark, rough, heaped into hills
##   build(kind) / has(kind)           the items (inventory icons): seeds, ears of corn, beans, squash, tobacco leaves, flax
##
## A plant's origin is its hill's foot (y 0 on the ground), +Y up.

const CROPS := ["corn", "beans", "bush_beans", "squash", "tobacco", "flax"]
const ITEMS := ["seed_corn", "seed_beans", "seed_squash", "seed_tobacco", "seed_flax", "corn", "roast_corn", "charred_corn",
		"beans", "bean_pot", "scorched_beans", "squash", "roast_squash", "charred_squash", "tobacco_leaves", "flax"]
const SOIL := Color(0.24, 0.17, 0.11)
const SOIL_DRY := Color(0.36, 0.28, 0.2)

static var _cache := {}
static var _mats := {}


# --- Crops ---------------------------------------------------------------------------------------------------

static func crop_mesh(crop: String, stage: int, v: int, dead := false) -> Mesh:
	var key := "%s:%d:%d:%s" % [crop, stage, v, dead]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(crop) + stage * 131 + v * 7919 + (17 if dead else 0)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fruit := SurfaceTool.new()
	fruit.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nf := 0
	match crop:
		"corn":
			nf = _corn(leaves, fruit, rng, stage, dead)
		"beans":
			nf = _beans(leaves, fruit, rng, stage, dead, true)
		"bush_beans":
			nf = _beans(leaves, fruit, rng, stage, dead, false)
		"squash":
			nf = _squash(leaves, fruit, rng, stage, dead)
		"tobacco":
			nf = _tobacco(leaves, fruit, rng, stage, dead)
		"flax":
			nf = _flax(leaves, fruit, rng, stage, dead)
	var mesh := leaves.commit()
	mesh.surface_set_material(0, ForageModels.leaf_material("farm"))
	if nf > 0:
		fruit.commit(mesh)
		mesh.surface_set_material(1, ForageModels.fruit_material())
	_cache[key] = mesh
	return mesh


## Greens by stage, faded to straw when ripe (the grain crops dry on the stalk) and to brown when frost-killed.
static func _green(stage: int, dead: bool, dry_when_ripe := false) -> Array[Color]:
	if dead:
		return [Color(0.32, 0.24, 0.13), Color(0.42, 0.33, 0.2)]
	if stage >= 3 and dry_when_ripe:
		return [Color(0.5, 0.42, 0.24), Color(0.62, 0.53, 0.32)]
	return [Color(0.2, 0.36, 0.1), Color(0.34, 0.5, 0.16)]


## Three stalks to a hill: long drooping blades up the stalk, a tassel on top and two ears in their husks when grown.
static func _corn(st: SurfaceTool, fr: SurfaceTool, rng: RandomNumberGenerator, stage: int, dead: bool) -> int:
	var h := [0.14, 0.62, 1.7, 1.85][stage] as float
	var cols := _green(stage, dead, true)
	var nf := 0
	for s in 3:
		var a := TAU * s / 3.0 + rng.randf_range(-0.4, 0.4)
		var base := Vector3(cos(a), 0.0, sin(a)) * 0.09
		var lean := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.02, 0.07) * (3.0 if dead else 1.0)
		var hh := h * rng.randf_range(0.88, 1.08) * (0.6 if dead else 1.0)
		var top := base + Vector3.UP * hh + lean * hh
		ForageModels._stem(st, base, top, 0.016 if stage >= 2 else 0.007, 0.006, cols[0].darkened(0.1), 5)
		var n := 2 if stage == 0 else (4 if stage == 1 else 8)
		for i in n:
			var t := (i + 0.5) / n * 0.85
			var at := base.lerp(top, t)
			var ang := a + (PI if i % 2 == 0 else 0.0) + rng.randf_range(-0.5, 0.5)
			var out := Vector3(cos(ang), 0.0, sin(ang))
			var l := (0.18 if stage == 0 else 0.42 if stage == 1 else 0.72) * rng.randf_range(0.8, 1.1) * (1.0 - 0.35 * t)
			var dir := (out + Vector3.UP * (0.9 if stage == 0 else 0.55)).normalized()
			ForageModels._leaf(st, at, dir, Vector3.UP, l, l * 0.13, cols[0], cols[1], 0.3, 0.2, 0.85 if dead else 0.45, 5)
		if stage >= 2:
			# the tassel
			for k in 6:
				var ta := TAU * k / 6.0
				var tip := top + Vector3(cos(ta) * 0.09, 0.12, sin(ta) * 0.09)
				ForageModels._stem(st, top, tip, 0.004, 0.002, Color(0.66, 0.56, 0.3) if stage >= 3 or dead else Color(0.58, 0.55, 0.28), 3)
			# two ears in their husks, angled out from the stalk at about waist height
			for e in 2:
				var et := 0.42 + 0.14 * e
				var at2 := base.lerp(top, et)
				var ea := a + PI * 0.5 + PI * e
				var eo := Vector3(cos(ea), 0.0, sin(ea))
				var ax := (eo * 0.55 + Vector3.UP).normalized()
				var husk := Color(0.72, 0.64, 0.4) if stage >= 3 or dead else Color(0.36, 0.5, 0.2)
				_ear(fr if stage >= 3 else st, at2 + eo * 0.03, ax, 0.19, husk, stage >= 3 and not dead)
				nf += 1
	return nf


## An ear in its husk along `ax`: the husk leaves, and the kernels showing at the tip once it is ripe.
static func _ear(st: SurfaceTool, at: Vector3, ax: Vector3, l: float, husk: Color, open: bool) -> void:
	_lathe(st, at, ax, [[0.0, 0.0], [0.022, 0.03], [0.028, l * 0.4], [0.02, l * 0.85], [0.004, l]], husk.darkened(0.1), husk)
	if open:
		ForageModels._blob(st, at + ax * l * 0.95, 0.016, Color(0.86, 0.62, 0.2), Vector3(1.0, 1.4, 1.0))


## Beans: pole beans twine up the corn's stalks (a spiral of thin vine with heart-shaped leaves), bush beans stand low;
## pods hang when grown and dry to straw when ripe.
static func _beans(st: SurfaceTool, fr: SurfaceTool, rng: RandomNumberGenerator, stage: int, dead: bool, climbing: bool) -> int:
	var cols := _green(stage, dead, true)
	var nf := 0
	var vines := 3 if climbing else 4
	for s in vines:
		var a := TAU * s / vines + rng.randf_range(-0.3, 0.3) + 0.5
		var r := 0.1 if climbing else 0.06
		var h := ([0.08, 0.35, 1.3, 1.35][stage] as float) if climbing else ([0.06, 0.2, 0.42, 0.44][stage] as float)
		if dead:
			h *= 0.5
		var pts: Array[Vector3] = []
		var turns := 2.5 if climbing else 0.6
		for i in 9:
			var t := i / 8.0
			var ang := a + t * TAU * turns
			pts.append(Vector3(cos(ang) * r * (1.0 - 0.3 * t), t * h, sin(ang) * r * (1.0 - 0.3 * t)))
		ForageModels._stems(st, pts, 0.005, 0.003, cols[0].darkened(0.15))
		var nl := 2 if stage == 0 else (4 if stage == 1 else 7)
		for i in nl:
			var t := 0.2 + 0.75 * i / maxf(nl - 1, 1)
			var at := ForageModels._along(pts, t)
			var out := Vector3(at.x, 0.0, at.z).normalized() if Vector2(at.x, at.z).length() > 1e-4 else Vector3.FORWARD
			out = (out + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))).normalized()
			var l := 0.07 if stage == 0 else 0.1
			ForageModels._leaf(st, at, (out + Vector3.UP * 0.2).normalized(), Vector3.UP, l, l * 0.85, cols[0], cols[1], 0.35, 0.2,
					0.6 if dead else 0.25, 4)
		if stage >= 2 and not dead:
			var pod := Color(0.72, 0.64, 0.38) if stage >= 3 else Color(0.34, 0.5, 0.18)
			for i in 5:
				var at := ForageModels._along(pts, rng.randf_range(0.35, 0.95))
				var down := (Vector3.DOWN + Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))).normalized()
				ForageModels._stem(fr, at, at + down * 0.1, 0.007, 0.004, pod, 4)
				nf += 1
	return nf


## Squash: a sprawl of vines along the ground from the hill, big lobed leaves on stalks, squashes when grown (green, then
## yellow-orange when ripe).
static func _squash(st: SurfaceTool, fr: SurfaceTool, rng: RandomNumberGenerator, stage: int, dead: bool) -> int:
	var cols := _green(stage, dead)
	var reach := [0.06, 0.3, 0.8, 0.85][stage] as float
	var nf := 0
	for s in 3:
		var a := TAU * s / 3.0 + rng.randf_range(-0.4, 0.4) + 1.1
		var dir := Vector3(cos(a), 0.0, sin(a))
		var pts: Array[Vector3] = []
		for i in 6:
			var t := i / 5.0
			var side := Vector3(-dir.z, 0.0, dir.x) * sin(t * PI * 1.5) * 0.08
			pts.append(dir * reach * t + side + Vector3.UP * (0.02 + 0.03 * sin(t * PI)))
		ForageModels._stems(st, pts, 0.009, 0.005, cols[0].darkened(0.1))
		var nl := 1 if stage == 0 else (3 if stage == 1 else 5)
		for i in nl:
			var at := ForageModels._along(pts, (i + 0.5) / nl)
			var lsz := (0.08 if stage == 0 else 0.16 if stage == 1 else 0.24) * rng.randf_range(0.85, 1.15)
			var up := at + Vector3.UP * lsz * (0.3 if dead else 0.9)
			ForageModels._stem(st, at, up, 0.004, 0.003, cols[0], 3)
			var ld := (dir + Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))).normalized()
			ForageModels._leaf(st, up, (ld + Vector3.UP * 0.25).normalized(), Vector3.UP, lsz, lsz * 1.05, cols[0], cols[1], 0.45, 0.3,
					0.5 if dead else 0.2, 5)
		if stage >= 2:
			var at := ForageModels._along(pts, rng.randf_range(0.55, 0.85)) + Vector3(0.0, 0.0, 0.0)
			var col := Color(0.86, 0.56, 0.16) if stage >= 3 and not dead else (Color(0.4, 0.36, 0.2) if dead else Color(0.36, 0.5, 0.2))
			var r := 0.075 if stage >= 3 else 0.055
			_lathe(fr, at + Vector3.UP * 0.005, Vector3.UP, [[0.0, 0.0], [r * 0.8, r * 0.1], [r, r * 0.55], [r * 0.85, r * 1.05],
					[r * 0.2, r * 1.3], [0.0, r * 1.32]], col.darkened(0.15), col, 10)
			nf += 1
	return nf


## Tobacco: a rosette of broad leaves on a stout stalk, a head of pink flowers when grown; the ripe leaves yellow.
static func _tobacco(st: SurfaceTool, fr: SurfaceTool, rng: RandomNumberGenerator, stage: int, dead: bool) -> int:
	var cols := _green(stage, dead)
	if stage >= 3 and not dead:
		cols = [Color(0.46, 0.5, 0.16), Color(0.66, 0.62, 0.24)]
	var h := [0.08, 0.35, 1.2, 1.25][stage] as float
	if dead:
		h *= 0.55
	ForageModels._stem(st, Vector3.ZERO, Vector3.UP * h, 0.014, 0.007, cols[0].darkened(0.15), 5)
	var n := 3 if stage == 0 else (6 if stage == 1 else 10)
	for i in n:
		var t := float(i) / n
		var at := Vector3.UP * h * (0.05 + 0.75 * t)
		var a := i * 2.4 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(a), 0.0, sin(a))
		var l := (0.09 if stage == 0 else 0.22 if stage == 1 else 0.4) * (1.0 - 0.55 * t) * rng.randf_range(0.9, 1.1)
		ForageModels._leaf(st, at, (out + Vector3.UP * (0.5 - 0.3 * t)).normalized(), Vector3.UP, l, l * 0.52, cols[0], cols[1],
				0.4, 0.25, 0.7 if dead else 0.35, 5)
	var nf := 0
	if stage >= 2 and not dead:
		for k in 7:
			var fa := TAU * k / 7.0
			var fp := Vector3.UP * h + Vector3(cos(fa) * 0.05, rng.randf_range(0.0, 0.08), sin(fa) * 0.05)
			ForageModels._blob(fr, fp, 0.014, Color(0.86, 0.5, 0.62) if stage == 2 else Color(0.56, 0.44, 0.24), Vector3(0.8, 1.6, 0.8))
			nf += 1
	return nf


## Flax: a thick stand of thin stalks with fine leaves, blue flowers when grown, golden stalks and seed bolls when ripe.
static func _flax(st: SurfaceTool, fr: SurfaceTool, rng: RandomNumberGenerator, stage: int, dead: bool) -> int:
	var cols := _green(stage, dead, true)
	var h := [0.07, 0.3, 0.8, 0.82][stage] as float
	var nf := 0
	for s in 26:
		var p := Vector3(rng.randf_range(-0.42, 0.42), 0.0, rng.randf_range(-0.42, 0.42))
		var hh := h * rng.randf_range(0.8, 1.1) * (0.6 if dead else 1.0)
		var tip := p + Vector3(rng.randf_range(-0.04, 0.04), hh, rng.randf_range(-0.04, 0.04)) + (Vector3(0.12, -0.2, 0.0) * hh if dead else Vector3.ZERO)
		ForageModels._stem(st, p, tip, 0.0035, 0.002, cols[0], 3)
		if stage >= 1:
			for i in 2:
				var at := p.lerp(tip, 0.35 + 0.3 * i)
				var a := rng.randf_range(0.0, TAU)
				ForageModels._leaf(st, at, (Vector3(cos(a), 0.0, sin(a)) + Vector3.UP * 0.8).normalized(), Vector3.UP, 0.05, 0.01,
						cols[0], cols[1], 0.4, 0.1, 0.1, 3)
		if stage >= 2 and not dead and s % 2 == 0:
			ForageModels._blob(fr, tip, 0.012, Color(0.45, 0.58, 0.9) if stage == 2 else Color(0.62, 0.5, 0.28), Vector3(1.2, 0.6, 1.2))
			nf += 1
	return nf


## Weeds: a few rough tufts (pigweed, lamb's quarters) between the hills.
static func weeds_mesh(v: int) -> Mesh:
	var key := "weeds:%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for w in 5:
		var p := Vector3(rng.randf_range(-0.85, 0.85), 0.0, rng.randf_range(-0.85, 0.85))
		for i in 5:
			var a := rng.randf_range(0.0, TAU)
			var l := rng.randf_range(0.08, 0.16)
			ForageModels._leaf(st, p, (Vector3(cos(a), 0.0, sin(a)) + Vector3.UP * 0.7).normalized(), Vector3.UP, l, l * 0.45,
					Color(0.24, 0.38, 0.12), Color(0.4, 0.52, 0.2), 0.4, 0.2, 0.3, 3)
	var mesh := st.commit()
	mesh.surface_set_material(0, ForageModels.leaf_material("farm"))
	_cache[key] = mesh
	return mesh


# --- The bed ---------------------------------------------------------------------------------------------------

## The worked soil of a `size` square bed, its centre at the origin: a grid laid on the ground (`height(x, z)` the ground's
## height under a point, relative to the bed's centre), heaped into a hill at each of `hills` (local x, z) once it is
## worked (`broken` 1); partly broken ground (0..1) is rougher and paler at the edges. Vertex coloured.
static func bed_mesh(size: float, hills: Array, height: Callable, broken: float, rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var n := 12
	var half := size * 0.5
	var pts: Array = []
	var cols: Array = []
	for j in n + 1:
		for i in n + 1:
			var x := -half + size * i / n
			var z := -half + size * j / n
			var edge := maxf(absf(x), absf(z)) / half
			var y := float(height.call(x, z)) + 0.03 + rng.randf_range(-0.012, 0.012)
			var col := SOIL.lerp(SOIL_DRY, clampf(rng.randf_range(0.0, 0.45) + (1.0 - broken) * 0.5, 0.0, 1.0))
			if edge > 0.92:
				y -= 0.025
				col = col.lerp(SOIL_DRY, 0.5)
			for hp: Vector2 in hills:
				var d := Vector2(x - hp.x, z - hp.y).length()
				if d < 0.32:
					y += broken * 0.09 * (1.0 + cos(d / 0.32 * PI)) * 0.5
					col = col.darkened(0.08 * broken)
			pts.append(Vector3(x, y, z))
			cols.append(col)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + n + 1
			var d := c + 1
			for idx: int in [a, b, d, a, d, c]:
				st.set_color(cols[idx])
				st.add_vertex(pts[idx])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, soil_material())
	return mesh


static func soil_material() -> StandardMaterial3D:
	if not _mats.has("soil"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.97
		m.metallic_specular = 0.15
		_mats["soil"] = m
	return _mats["soil"]


# --- Items (inventory icons) -----------------------------------------------------------------------------------

static func has(kind: String) -> bool:
	return kind in ITEMS


static func build(kind: String) -> Node3D:
	if not has(kind):
		return null
	var root := Node3D.new()
	root.name = kind.to_pascal_case()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var matte := false
	match kind:
		"seed_corn", "seed_beans", "seed_squash", "seed_tobacco", "seed_flax":
			_seed_bag(st, rng, kind)
			matte = true
		"corn", "roast_corn", "charred_corn":
			var husk := Color(0.74, 0.66, 0.42)
			var k := Color(0.88, 0.64, 0.2)
			if kind == "roast_corn":
				husk = Color(0.46, 0.34, 0.18)
				k = Color(0.72, 0.48, 0.16)
			elif kind == "charred_corn":
				husk = Color(0.12, 0.1, 0.08)
				k = Color(0.2, 0.14, 0.08)
			_lathe(st, Vector3(0, 0, -0.1), Vector3.BACK, [[0.0, 0.0], [0.026, 0.02], [0.032, 0.08], [0.026, 0.17], [0.006, 0.2]], k.darkened(0.2), k, 12)
			for i in 4:
				var a := TAU * i / 4.0 + 0.3
				var out := Vector3(cos(a), sin(a), 0.0)
				ForageModels._leaf(st, Vector3(0, 0, -0.1) + out * 0.02, (Vector3.FORWARD * -1.0 + out * 0.35).normalized(), out, 0.2, 0.06,
						husk.darkened(0.1), husk, 0.4, 0.3, -0.05, 4)
		"beans", "bean_pot", "scorched_beans":
			if kind != "beans":
				_bowl(st, Color(0.52, 0.34, 0.22))
			var bc := Color(0.62, 0.42, 0.3) if kind == "beans" else (Color(0.5, 0.36, 0.26) if kind == "bean_pot" else Color(0.18, 0.12, 0.08))
			for i in 26:
				var p := Vector3(rng.randf_range(-0.07, 0.07), 0.03 + rng.randf_range(0.0, 0.03), rng.randf_range(-0.07, 0.07))
				if kind == "beans":
					p.y = 0.012 + rng.randf_range(0.0, 0.03) * (1.0 - Vector2(p.x, p.z).length() / 0.1)
				ForageModels._blob(st, p, 0.011, bc.lerp(Color(0.9, 0.86, 0.78), rng.randf_range(0.0, 0.35)), Vector3(1.5, 0.8, 1.0))
		"squash", "roast_squash", "charred_squash":
			var sc := Color(0.86, 0.56, 0.16) if kind == "squash" else (Color(0.66, 0.38, 0.12) if kind == "roast_squash" else Color(0.16, 0.11, 0.07))
			_lathe(st, Vector3.ZERO, Vector3.UP, [[0.0, 0.0], [0.06, 0.012], [0.085, 0.05], [0.075, 0.1], [0.03, 0.125], [0.0, 0.128]],
					sc.darkened(0.15), sc, 14)
			ForageModels._stem(st, Vector3(0, 0.125, 0), Vector3(0.012, 0.16, 0.0), 0.009, 0.006, Color(0.4, 0.36, 0.2), 5)
		"tobacco_leaves":
			for i in 5:
				var a := -0.35 + 0.18 * i
				ForageModels._leaf(st, Vector3(0, 0, 0.12), Vector3(sin(a), 0.05 * i, -cos(a)).normalized(), Vector3.UP, 0.26, 0.13,
						Color(0.4, 0.46, 0.14), Color(0.62, 0.6, 0.24), 0.45, 0.2, 0.1, 5)
			ForageModels._stem(st, Vector3(-0.02, 0.01, 0.12), Vector3(0.02, 0.01, 0.12), 0.012, 0.012, Color(0.44, 0.32, 0.18), 5)
			matte = true
		"flax":
			for i in 24:
				var o := Vector3(rng.randf_range(-0.018, 0.018), rng.randf_range(-0.018, 0.018), 0.0)
				ForageModels._stem(st, Vector3(0, 0, 0.16) + o, Vector3(0, 0, -0.16) + o * 1.6, 0.0025, 0.002, Color(0.74, 0.64, 0.36), 3)
			ForageModels._stem(st, Vector3(0, 0, 0.02), Vector3(0, 0, -0.01), 0.026, 0.026, Color(0.5, 0.4, 0.24), 6)
			matte = true
	var mi := MeshInstance3D.new()
	mi.name = "Item"
	var mesh := st.commit()
	mesh.surface_set_material(0, ForageModels.matte_material() if matte else ForageModels.fruit_material())
	mi.mesh = mesh
	root.add_child(mi)
	return root


## A small cloth seed bag, its neck tied, a few seeds spilled in front.
static func _seed_bag(st: SurfaceTool, rng: RandomNumberGenerator, kind: String) -> void:
	var cloth := Color(0.66, 0.58, 0.44)
	_lathe(st, Vector3.ZERO, Vector3.UP, [[0.0, 0.0], [0.05, 0.004], [0.062, 0.035], [0.05, 0.075], [0.018, 0.1], [0.022, 0.115],
			[0.012, 0.125], [0.0, 0.126]], cloth.darkened(0.2), cloth, 12)
	ForageModels._stem(st, Vector3(0.0, 0.1, 0.0), Vector3(0.03, 0.09, 0.02), 0.004, 0.003, Color(0.4, 0.3, 0.18), 4)
	var col: Color = {"seed_corn": Color(0.88, 0.64, 0.2), "seed_beans": Color(0.56, 0.36, 0.26), "seed_squash": Color(0.9, 0.86, 0.7),
			"seed_tobacco": Color(0.3, 0.22, 0.14), "seed_flax": Color(0.5, 0.36, 0.2)}[kind]
	var r := 0.009 if kind in ["seed_corn", "seed_beans", "seed_squash"] else 0.004
	for i in 9:
		var p := Vector3(rng.randf_range(0.02, 0.1), r, rng.randf_range(0.03, 0.09))
		ForageModels._blob(st, p, r, col.lerp(Color.WHITE, rng.randf_range(0.0, 0.15)), Vector3(1.3, 0.7, 1.0))


## A shallow earthenware bowl.
static func _bowl(st: SurfaceTool, col: Color) -> void:
	_lathe(st, Vector3.ZERO, Vector3.UP, [[0.0, 0.0], [0.05, 0.002], [0.085, 0.025], [0.1, 0.05], [0.094, 0.052], [0.078, 0.03],
			[0.0, 0.028]], col.darkened(0.2), col, 16)


## A turned shape round `axis` from `c`: `profile` [radius, distance along the axis] rings, `segs` round.
static func _lathe(st: SurfaceTool, c: Vector3, axis: Vector3, profile: Array, col0: Color, col1: Color, segs := 8) -> void:
	ForageModels._lathe(st, c, axis.normalized(), profile, col0, col1, segs)
