class_name StoryLayerProps
extends RefCounted
## The parts of a story layer (StoryLayer, data/world/layers/<id>.json) that are not build pieces: built in code with the
## fort's kit (StructureMeshKit, StructureGeometry, StructureMaterials) and the forest's own tree models (VegAssets), each
## a Node3D the layer keeps under its node (rebuilt with the level, never saved: the same every time).
##   church(spec, seed)            the church's unfinished stone walls (stone: they do not burn), stepping down from the
##                                 east end, a door gap in the west wall, cut stones and a scaffold by them
##   grove(spec, clear, settings, visuals)
##                                 a stand of white pine and hemlock on the ground in an ellipse (trunk colliders in the
##                                 "trees" group, climbable bark; drawn LODs, impostors and shadow blobs as the forest's,
##                                 FrontierVegetation), none within `clear` [[point, r]] (the wreck's clearing)
##   mill_wheel(spec, water_y)     the mill's undershot wheel on its shaft (wood: in FireSpread's burnable group), turning
##                                 slowly with the river, stopped once it has caught fire
## Headless runs build the colliders only for the grove (as the forest does).

const K := preload("res://scripts/world/structures/structure_mesh_kit.gd")
const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const TREES_GROUP := &"trees"
## The forest's tree LOD ends (FrontierVegetation.TREE_LOD, x the preset's vegetation_distance_scale), its hand-over band
## (LOD_BAND of the switch distance, at least LOD_BAND_MIN m) and the reach a MultiMesh stays drawn past its trees' band.
const TREE_LOD := [30.0, 60.0, 100.0]
const LOD_BAND := 0.12
const LOD_BAND_MIN := 3.0
## The grove's drawn trees are grouped in cells of this many metres (one MultiMesh per cell, kind and LOD); a cell's
## MultiMesh is drawn this much past its trees' band (its half diagonal and height).
const CELL := 32.0
const REACH := 30.0


# --- The church ---------------------------------------------------------------------------------------------------------

## The church's walls, in its own frame (origin on the ground at its middle; x along the nave, the east end at +x):
## `length` x `width` outside, walls `thick`; the east wall `east_h` high, the long walls stepping down to `west_h` at
## the west, whose wall has a `door` gap. Returns a Node3D (put it where the church stands).
static func church(spec: Dictionary, seed_value: int, ground: Callable) -> Node3D:
	var root := Node3D.new()
	root.name = "Church"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hl := float(spec.get("length", 14.0)) * 0.5
	var hw := float(spec.get("width", 9.0)) * 0.5
	var t := float(spec.get("thick", 0.7))
	var east_h := float(spec.get("east_h", 3.6))
	var west_h := float(spec.get("west_h", 1.1))
	var door := float(spec.get("door", 1.6))
	var kit := K.new()
	var ts := 1.0 / StructureGeometry.STONE_TILE
	var body := StaticBody3D.new()
	body.name = "Walls"
	body.set_meta(&"surface", "stone")
	GripSurface.tag(body, "rock")
	# the height of the courses laid so far at x along the nave (west to east), a little ragged per stretch
	var h_at := func(x: float) -> float:
		var f := clampf((x + hl) / (2.0 * hl), 0.0, 1.0)
		return lerpf(west_h + 0.5, east_h - 0.2, smoothstep(0.0, 1.0, f))
	# the two long walls (the full length, their ends the corners), then the end walls between them
	for side: float in [-1.0, 1.0]:
		_stone_run(kit, body, rng, Vector3(-hl, 0, side * (hw - t * 0.5)), Vector3(hl, 0, side * (hw - t * 0.5)), t, h_at, ts, [], ground)
	_stone_run(kit, body, rng, Vector3(hl - t * 0.5, 0, -hw + t), Vector3(hl - t * 0.5, 0, hw - t), t,
			func(_x: float) -> float: return east_h, ts, [], ground)
	_stone_run(kit, body, rng, Vector3(-hl + t * 0.5, 0, -hw + t), Vector3(-hl + t * 0.5, 0, hw - t), t,
			func(_x: float) -> float: return west_h, ts, [Vector2(-door * 0.5, door * 0.5)], ground)
	# the cut stones waiting by the west end, and a scaffold of poles against the east wall
	for i in 11:
		var sz := Vector3(rng.randf_range(0.45, 0.8), rng.randf_range(0.22, 0.34), rng.randf_range(0.32, 0.5))
		var layer := 0 if i < 7 else 1
		var p := Vector3(-hl - 2.2 + rng.randf_range(-0.9, 0.9), sz.y * 0.5 + layer * 0.3 - 0.03, 2.2 + rng.randf_range(-1.1, 1.1))
		p.y += float(ground.call(p.x, p.z))
		kit.box(&"stone", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)), p), sz, K.GRAIN_X, rng.randi_range(0, 3),
				rng.randf(), Color(0.82, 0.82, 0.8, 1.0))
	var gy := float(ground.call(hl + 1.4, 0.0))
	for z: float in [-2.6, 0.0, 2.6]:
		BuildGeometry._pole_between(kit, Vector3(hl + 1.4, gy - 0.3, z), Vector3(hl + 1.35, gy + east_h + 0.9, z + 0.05), 0.07, rng)
		BuildGeometry._pole_between(kit, Vector3(hl + 1.4, gy + east_h - 0.6, z), Vector3(hl - t * 0.5, gy + east_h - 0.55, z), 0.05, rng)
	BuildGeometry._pole_between(kit, Vector3(hl + 1.47, gy + east_h - 0.47, -3.0), Vector3(hl + 1.47, gy + east_h - 0.47, 3.0), 0.06, rng)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = kit.commit(StructureMaterials.all())
	root.add_child(mi)
	root.add_child(body)
	return root


## One wall from `a` to `b` (its frame's floor; ground(x, z) the terrain's height there, in the church's frame), `t`
## thick, laid in stretches of about a metre each to h(x) over the ground (a stone or two more on some), but `gaps`
## ([from, to] along it, from its middle) left open; each stretch its box collider.
static func _stone_run(kit: K, body: StaticBody3D, rng: RandomNumberGenerator, a: Vector3, b: Vector3, t: float, h: Callable,
		ts: float, gaps: Array, ground: Callable) -> void:
	var dir := (b - a)
	var length := dir.length()
	dir = dir.normalized()
	var along_x := absf(dir.x) > 0.5
	var s := 0.0
	while s < length - 0.05:
		var seg := minf(rng.randf_range(0.9, 1.5), length - s)
		if length - s - seg < 0.5:
			seg = length - s
		var s0 := s
		var s1 := s + seg
		s = s1
		# a gap in this stretch: lay up to it and on from it
		var parts: Array = [[s0, s1]]
		for g: Vector2 in gaps:
			var g0 := g.x + length * 0.5
			var g1 := g.y + length * 0.5
			var next: Array = []
			for pr: Array in parts:
				if float(pr[1]) <= g0 or float(pr[0]) >= g1:
					next.append(pr)
					continue
				if float(pr[0]) < g0 - 0.05:
					next.append([pr[0], g0])
				if float(pr[1]) > g1 + 0.05:
					next.append([g1, pr[1]])
			parts = next
		for pr: Array in parts:
			var p0 := a + dir * float(pr[0])
			var p1 := a + dir * float(pr[1])
			var mid := (p0 + p1) * 0.5
			var lo := minf(float(ground.call(p0.x, p0.z)), float(ground.call(p1.x, p1.z)))
			var top := float(ground.call(mid.x, mid.z)) + float(h.call(mid.x)) + rng.randf_range(-0.22, 0.22)
			var y0 := lo - 0.35
			var len_seg := float(pr[1]) - float(pr[0])
			var size := Vector3(len_seg, top - y0, t) if along_x else Vector3(t, top - y0, len_seg)
			var ctr := Vector3(mid.x, (y0 + top) * 0.5, mid.z)
			StructureGeometry._stone_box(kit, ctr, size, ts, 8)
			# a stone or two set on its top, the next course begun
			if rng.randf() < 0.65:
				for k in rng.randi_range(1, 2):
					var w := rng.randf_range(0.35, 0.6)
					var off := rng.randf_range(-len_seg * 0.5 + w * 0.5, len_seg * 0.5 - w * 0.5) if len_seg > w else 0.0
					var sh := rng.randf_range(0.16, 0.26)
					var sp := ctr + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
					sp.y = top + sh * 0.5 - 0.01
					var ssz := Vector3(w, sh, t * rng.randf_range(0.55, 0.9)) if along_x else Vector3(t * rng.randf_range(0.55, 0.9), sh, w)
					StructureGeometry._stone_box(kit, sp, ssz, ts, 8)
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			cs.shape = box
			cs.position = ctr
			body.add_child(cs)


# --- The pine grove -----------------------------------------------------------------------------------------------------

## The trees of the grove ({center [x, z], radii [x, z], spacing, keep, min_h, max_slope_deg, hemlock, seed}): a jittered
## grid in the ellipse, thinning toward its rim, on ground at least min_h up and no steeper than max_slope_deg, none
## within r of a `clear` point ([[Vector3, r]]). Returns [{pos, yaw, scale, kind, variant, custom}].
static func grove_trees(spec: Dictionary, clear: Array) -> Array:
	var out: Array = []
	var c := Vector2(float(spec.center[0]), float(spec.center[1]))
	var rad := Vector2(float(spec.radii[0]), float(spec.radii[1]))
	var sp := float(spec.get("spacing", 9.0))
	var keep := float(spec.get("keep", 0.8))
	var min_h := float(spec.get("min_h", -INF))
	var max_y := cos(deg_to_rad(float(spec.get("max_slope_deg", 30.0))))
	var hemlock := float(spec.get("hemlock", 0.25))
	var sd := int(spec.get("seed", 1757))
	for iz in range(floori((c.y - rad.y) / sp), ceili((c.y + rad.y) / sp) + 1):
		for ix in range(floori((c.x - rad.x) / sp), ceili((c.x + rad.x) / sp) + 1):
			var x := (ix + 0.15 + 0.7 * _h(ix, iz, 1, sd)) * sp
			var z := (iz + 0.15 + 0.7 * _h(ix, iz, 2, sd)) * sp
			var e := Vector2((x - c.x) / rad.x, (z - c.y) / rad.y).length()
			if e > 1.0 or _h(ix, iz, 3, sd) > keep * (1.0 - 0.8 * smoothstep(0.65, 1.0, e)):
				continue
			if not FrontierTerrain.in_world(x, z) or not FrontierTerrain.in_world(x, z - 3.0) or not FrontierTerrain.in_world(x + 3.0, z):
				continue
			var y := FrontierTerrain.height_at(x, z)
			if y < min_h or FrontierTerrain.normal_at(x, z).y < max_y:
				continue
			var p := Vector3(x, y, z)
			var open := true
			for cl: Array in clear:
				var q: Vector3 = cl[0]
				if Vector2(q.x - x, q.z - z).length() < float(cl[1]):
					open = false
					break
			if not open:
				continue
			var edge := smoothstep(0.7, 1.0, e)
			var kind := Assets.HEMLOCK if _h(ix, iz, 4, sd) < hemlock else Assets.WHITE_PINE
			# one interior variant per species and drawing cell (fewer MultiMeshes, as the forest does), the low-crowned edge
			# variant round the rim
			var cell := Vector2i(floori(x / CELL), floori(z / CELL))
			var variant := 2 if edge > 0.55 else (0 if _h(cell.x, cell.y, 6 + kind, sd) < 0.5 else 1)
			out.append({"pos": p, "yaw": _h(ix, iz, 8, sd) * TAU, "kind": kind, "variant": variant,
					"scale": lerpf(0.84, 1.18, _h(ix, iz, 7, sd)) * lerpf(1.0, 0.88, edge),
					"custom": Color(_h(ix, iz, 14, sd), pow(_h(ix, iz, 12, sd), 3.0) * 0.6, _h(ix, iz, 15, sd), 0.0)})
	return out


## The grove's node: its trunks' colliders, and (`visuals`) its trees drawn as the forest's are.
static func grove(trees: Array, settings: WorldSettings, visuals: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "PineGrove"
	var body := StaticBody3D.new()
	body.name = "Trunks"
	body.add_to_group(TREES_GROUP)
	GripSurface.tag(body, "bark")
	var shapes := {}
	for t: Dictionary in trees:
		var info := Assets.tree(int(t.kind), int(t.variant))
		var s := float(t.scale)
		var r := snappedf(clampf(float(info.get("trunk_radius", 0.3)) * s * 0.92, 0.1, 0.75), 0.02)
		var h := snappedf(maxf(float(info.get("collider_height", 6.0)) * s, 3.3), 0.25)
		var key := "%.2f_%.2f" % [r, h]
		if not shapes.has(key):
			var cy := CylinderShape3D.new()
			cy.radius = r
			cy.height = h
			shapes[key] = cy
		var cs := CollisionShape3D.new()
		cs.shape = shapes[key]
		cs.position = (t.pos as Vector3) + Vector3(0, h * 0.5 - 0.3, 0)
		body.add_child(cs)
	root.add_child(body)
	if visuals and not trees.is_empty():
		_draw_trees(root, trees, settings)
	return root


static func _draw_trees(root: Node3D, trees: Array, settings: WorldSettings) -> void:
	var dist := settings.vegetation_distance_scale if settings else 1.0
	var lod_end := [float(TREE_LOD[0]) * dist, float(TREE_LOD[1]) * dist, float(TREE_LOD[2]) * dist]
	var shadow_end := settings.tree_shadow_distance if settings else 150.0
	var dither := 1.0 if settings and settings.antialiasing in ["taa", "metalfx"] else 0.0
	var painted := Assets.PaintedLook.enabled()
	var imp_ok := not Assets.impostor_info().is_empty()
	var cells := {}
	for i in trees.size():
		var p: Vector3 = trees[i].pos
		var c := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		var key := int(trees[i].kind) * 4 + int(trees[i].variant)
		if not cells.has(c):
			cells[c] = {}
		if not cells[c].has(key):
			cells[c][key] = []
		(cells[c][key] as Array).append(i)
	var mats := {}
	for c: Vector2i in cells:
		var all: Array = []
		for key: int in cells[c]:
			var idx: Array = cells[c][key]
			all.append_array(idx)
			var kind := key / 4
			var variant := key % 4
			var aabb := _aabb(trees, idx)
			var buf := _buffer(trees, idx, false)
			for lod in 3:
				var mesh := Assets.tree_mesh(kind, variant, lod)
				if mesh == null:
					continue
				var band_in := _band(lod_end, lod - 1) if lod > 0 else Vector2.ZERO
				var band_out := _band(lod_end, lod) if (lod < 2 or imp_ok) else Vector2.ZERO
				var base := Assets.painted_tree_material(kind) if (lod == 2 and painted) else Assets.tree_material(kind)
				var mmi := _mmi(root, mesh, _lod_mat(mats, base, band_in, band_out, dither), buf, idx.size(), aabb,
						maxf(band_in.x - REACH, 0.0) if lod > 0 else 0.0, band_out.y + REACH if band_out.y > 0.0 else 0.0)
				mmi.name = "TreeLod%d_%d_%d_%d" % [lod, c.x, c.y, key]
			# the crowns' shade: the variant's opaque crown blob, shadows only
			var blob := Assets.tree_mesh(kind, variant, 4)
			if blob and shadow_end > 0.0:
				var bmi := _mmi(root, blob, Assets.shadow_blob_material(), buf, idx.size(), aabb, 0.0, shadow_end)
				bmi.name = "TreeShadow_%d_%d_%d" % [c.x, c.y, key]
				bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if imp_ok and not all.is_empty():
			var band := _band(lod_end, 2)
			var imp := Assets.painted_impostor_material() if painted else Assets.impostor_material()
			var mmi := _mmi(root, Assets.impostor_quad(), _lod_mat(mats, imp, band, Vector2.ZERO, dither), _buffer(trees, all, true),
					all.size(), _aabb(trees, all), maxf(band.x - REACH - CELL * 0.5, 0.0), 0.0)
			mmi.name = "TreeImpostors_%d_%d" % [c.x, c.y]


static func _band(lod_end: Array, k: int) -> Vector2:
	var s := float(lod_end[k])
	var w := maxf(s * LOD_BAND, LOD_BAND_MIN)
	return Vector2(s - w * 0.5, s + w * 0.5)


static func _lod_mat(cache: Dictionary, base: ShaderMaterial, band_in: Vector2, band_out: Vector2, dither: float) -> ShaderMaterial:
	var key := "%d|%s|%s" % [base.get_instance_id(), band_in, band_out]
	if not cache.has(key):
		var m := base.duplicate() as ShaderMaterial
		m.set_shader_parameter(&"lod_fade", Vector4(band_in.x, band_in.y, band_out.x, band_out.y))
		m.set_shader_parameter(&"lod_dither_anim", dither)
		cache[key] = m
	return cache[key]


static func _mmi(parent: Node, mesh: Mesh, mat: Material, buf: PackedFloat32Array, count: int, aabb: AABB, begin: float,
		end: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.custom_aabb = aabb
	mmi.visibility_range_begin = begin
	mmi.visibility_range_end = end
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mmi)
	return mmi


## The MultiMesh buffer (as FrontierVegetation._buffer: 12 floats of transform, 4 of custom data); `impostor`: the custom
## data the impostors read (atlas row, variation, dryness).
static func _buffer(trees: Array, idx: Array, impostor: bool) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(idx.size() * 16)
	var o := 0
	for i: int in idx:
		var t: Dictionary = trees[i]
		var b := Basis(Vector3.UP, float(t.yaw)).scaled(Vector3.ONE * float(t.scale))
		var p: Vector3 = t.pos
		var row := [b.x.x, b.y.x, b.z.x, p.x, b.x.y, b.y.y, b.z.y, p.y, b.x.z, b.y.z, b.z.z, p.z]
		for k in 12:
			buf[o + k] = float(row[k])
		var cc: Color = t.custom
		if impostor:
			buf[o + 12] = float(maxi(Assets.impostor_row(int(t.kind), int(t.variant)), 0))
			buf[o + 13] = cc.r
			buf[o + 14] = cc.g
			buf[o + 15] = 0.0
		else:
			buf[o + 12] = cc.r
			buf[o + 13] = cc.g
			buf[o + 14] = cc.b
			buf[o + 15] = cc.a
		o += 16
	return buf


static func _aabb(trees: Array, idx: Array) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i: int in idx:
		var p: Vector3 = trees[i].pos
		lo = lo.min(p)
		hi = hi.max(p)
	return AABB(lo - Vector3(8.0, 3.0, 8.0), hi - lo + Vector3(16.0, 36.0, 16.0))


static func _h(ix: int, iz: int, k: int, sd: int) -> float:
	var n := (ix * 73856093) ^ (iz * 19349663) ^ (k * 83492791) ^ (sd * 2654435761)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / float(0x1000000)


# --- The mill wheel -----------------------------------------------------------------------------------------------------

## The mill's wheel: `radius` and `width` (m), its axle along the node's local Z, the mill's wall `shaft` m along +Z;
## `turn` rad/s (the sign the river's flow gives it). A post in the water carries the shaft's outer end. Wood: in
## FireSpread's burnable group (it chars and falls in where it stands with the mill).
static func mill_wheel(radius: float, width: float, shaft: float, turn: float, post_down: float, seed_value: int) -> Node3D:
	var root := MillWheel.new()
	root.name = "MillWheel"
	root.turn = turn
	root.add_to_group(FireSpread.BURNABLE_GROUP)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	root.add_child(wheel)
	var kit := K.new()
	var wet := Color(0.7, 0.68, 0.64, 1.0)
	var n := 16
	for side: float in [-1.0, 1.0]:
		var z := side * width * 0.5
		for i in n:
			var a := (i + 0.5) * TAU / n
			var chord := 2.0 * radius * sin(PI / n) + 0.06
			kit.box(&"boards", Transform3D(Basis(Vector3.BACK, a + PI * 0.5), Vector3(cos(a), sin(a), 0) * (radius - 0.11) + Vector3(0, 0, z)),
					Vector3(chord, 0.22, 0.08), K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), wet)
		for i in 8:
			var a := i * TAU / 8.0 + side * 0.1
			kit.box(&"boards", Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * radius * 0.5 + Vector3(0, 0, z)),
					Vector3(radius - 0.1, 0.12, 0.09), K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), wet)
	for i in n:
		var a := i * TAU / n
		kit.box(&"boards", Transform3D(Basis(Vector3.BACK, a - PI * 0.5), Vector3(cos(a), sin(a), 0) * (radius - 0.02)),
				Vector3(0.05, 0.5, width + 0.06), K.GRAIN_Z, rng.randi_range(0, 3), rng.randf(), wet)
	kit.box(&"hewn_mm", Transform3D(Basis(), Vector3.ZERO), Vector3(0.5, 0.5, width + 0.3), K.GRAIN_Z, 0, rng.randf(), wet)
	var wm := MeshInstance3D.new()
	wm.name = "Mesh"
	wm.mesh = kit.commit(StructureMaterials.all())
	wheel.add_child(wm)
	# the shaft into the mill's wall, its outer end on a post standing in the water
	var skit := K.new()
	skit.box(&"hewn_mm", Transform3D(Basis(), Vector3(0, 0, (shaft - width * 0.5 - 0.7) * 0.5)), Vector3(0.3, 0.3, shaft + width * 0.5 + 0.7),
			K.GRAIN_Z, 1, rng.randf(), wet)
	skit.box(&"hewn_mm", Transform3D(Basis(), Vector3(0, -post_down * 0.5 + 0.1, -width * 0.5 - 0.55)), Vector3(0.28, post_down + 0.2, 0.28),
			K.GRAIN_Y, 2, rng.randf(), wet)
	var sm := MeshInstance3D.new()
	sm.name = "Shaft"
	sm.mesh = skit.commit(StructureMaterials.all())
	root.add_child(sm)
	var body := StaticBody3D.new()
	body.name = "Body"
	for b: Array in [[Vector3(0, 0, 0), Vector3(radius * 1.8, radius * 1.8, width + 0.1)],
			[Vector3(0, 0, (shaft - width * 0.5 - 0.7) * 0.5), Vector3(0.3, 0.3, shaft + width * 0.5 + 0.7)],
			[Vector3(0, -post_down * 0.5 + 0.1, -width * 0.5 - 0.55), Vector3(0.28, post_down + 0.2, 0.28)]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1]
		cs.shape = box
		cs.position = b[0]
		body.add_child(cs)
	root.add_child(body)
	return root


## The wheel turning with the river (near the camera only), until it has caught fire: then it stands still for good (a
## ruin no longer burnable, FireSpread.burnable).
class MillWheel:
	extends Node3D
	var turn := 0.3
	var stopped := false
	var visible_turning := false
	var _check := 0.0
	var _wheel: Node3D

	func _ready() -> void:
		_wheel = get_node_or_null("Wheel") as Node3D
		_check = randf()

	func _process(delta: float) -> void:
		if stopped or _wheel == null:
			return
		_check -= delta
		if _check <= 0.0:
			_check = 1.0
			var f := FireSpread.find(get_tree())
			if f and (f.is_burning(self) or not f.burnable(self)):
				stopped = true
				return
			var cam := get_viewport().get_camera_3d()
			visible_turning = cam != null and cam.global_position.distance_to(global_position) < 180.0
		if visible_turning:
			_wheel.rotate_object_local(Vector3.BACK, turn * delta)
