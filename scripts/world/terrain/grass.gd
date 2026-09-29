class_name FrontierGrass
extends Node3D
## Grass for the Frontier ground (look-dev spec, section 5.5). Owner: package B.
## Built by FrontierTerrain.build() (windowed runs only; headless builds have no grass).
##
## Technique: GPU-instanced tuft cards streamed around the camera in 8 x 8 m cells. Every cell
## is a MultiMeshInstance3D that shares one of five MultiMesh "tiers" (100 / 55 / 36 / 20 / 10 %
## of a fixed 25 x 25 jittered pattern, stored in a random order so every tier is a spatially
## uniform prefix of the next), chosen from the distance falloff and the cell's baked maximum
## ground density (terrain_grass_cells.res: bare cells get no node, forest floor a small tier). The CPU only moves cell nodes when the camera crosses cells
## (no per-instance work, no allocations after the pool warms up); the vertex shader does
## the rest per tuft from the terrain textures: ground height, local density (meadow
## 10 / m2, forest floor 3 / m2, none on dirt, mud and rock), grass height (knee-high meadow,
## mowed range shoulders, tufts at the palisade foot), variant, colour, wind and trampling,
## and the distance falloff (full density to 12 m, linear to 25 % at 0.8 x grass_distance,
## then shrinking to nothing at grass_distance). All multiplied by WorldSettings.grass_density.
## Placement is deterministic (a fixed pattern plus hashes of world positions): the same
## grass every visit. Cast shadows off, GI off.
##
## The camera followed is the one actually rendering: an off-window SubViewport at the root
## (the environment tools' capture view) when one is updating, else the viewport's camera.
## Set `follow` to override.

const CELL := 8.0
const PATTERN_SIDE := 25
const PATTERN_N := PATTERN_SIDE * PATTERN_SIDE      ## 9.8 tufts / m2 at full density
const TIER_FRACTIONS := [1.0, 0.55, 0.36, 0.2, 0.1]
const CELLS_PATH := "res://assets/environment/terrain/terrain_grass_cells.res"
const FULL_DENSITY_DIST := 12.0
const SHADER_PATH := "res://shaders/grass/grass.gdshader"
const ATLAS_PATH := "res://assets/environment/grass/grass_atlas.png"
const VARIANTS_PATH := "res://assets/environment/grass/grass_variants.json"
const MAX_VARIANTS := 16
## The herbs and wildflowers some tufts become by chance (user 2026-09-28: "a procdure grass thing ... with chance for
## herbs and etc"; tools/environment/terrain/make_herb_atlas.py): fern beds, wood sorrel, mayapples, trilliums and violets
## under the trees, drifts of black-eyed Susans, bergamot, asters and goldenrod in the open, each in its season.
const HERB_ATLAS_PATH := "res://assets/environment/grass/herb_atlas.png"
const HERBS_PATH := "res://assets/environment/grass/herb_variants.json"
## Grass blocker map (2026-09-24 clipping pass): an R8 map at BLOCK_RES m per texel over the
## whole world marks every solid footprint on the ground (walls, buildings, crates, barrels, hay,
## ramps, dummies' posts, tree trunks, stumps, logs, rocks), grown by BLOCK_GROW (half a tuft), so
## no tuft pokes through a floor, a wall, a log or a rock. Built from the StaticBody3D colliders
## once the level has finished building (deferred), so it follows the real layout; plus the
## GrassBlockers boxes of visual parts that reach past their colliders (2026-09-25, e.g. the
## blockhouses' log ends, scripts/world/structures/fort_structures.gd _grass_blockers()).
const BLOCK_RES := 0.25
const BLOCK_HALF := 400.0
const BLOCK_GROW := 0.15
## Only the parts of a solid within this height of the ground block grass (a walkway overhead
## does not).
const BLOCK_CLEAR := 0.7

var settings: WorldSettings
var terrain: Node3D
var material: ShaderMaterial
var follow: Node3D
var distance := 55.0
var density := 1.0
var cells := {}                     ## Vector2i -> MultiMeshInstance3D
var _pool: Array[MultiMeshInstance3D] = []
var _tiers: Array[MultiMesh] = []
var _tier_of := {}                  ## Vector2i -> tier index
var _last := Vector2(INF, INF)
var _reach := 0
var _cell_max := PackedByteArray()  ## max local density per 8 m cell (baked), 0 = no grass
var _cell_n := 0
var _cell_off := 0
## Another square of ground's cells and material (FrontierTerrain's squares; the fort's: _cell_max, material).
var _square_cells := {}
var _square_mats := {}
var blocker_stats := {}


func build(owner_terrain: Node3D, ws: WorldSettings) -> void:
	terrain = owner_terrain
	settings = ws
	distance = maxf(ws.grass_distance, FULL_DENSITY_DIST + 4.0)
	density = ws.grass_density
	_reach = int(ceil(distance / CELL)) + 1
	var cm := load(CELLS_PATH) as Image if ResourceLoader.exists(CELLS_PATH) else null
	if cm:
		_cell_max = cm.get_data()
		_cell_n = cm.get_width()
		_cell_off = _cell_n / 2
	material = _make_material()
	# the other squares of ground: their cells, their material (their own textures, square_origin)
	for sq: Vector2i in FrontierTerrain.squares():
		if sq == Vector2i.ZERO:
			continue
		var path := FrontierTerrain.DATA_DIR + FrontierTerrain.SQUARE_DIR % [sq.x, sq.y] + "terrain_grass_cells.res"
		var scm := load(path) as Image if ResourceLoader.exists(path) else null
		if scm:
			_square_cells[sq] = scm.get_data()
		_square_mats[sq] = _make_material(sq)
	var mesh := tuft_mesh()
	var pattern := _pattern()
	for f: float in TIER_FRACTIONS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var count := clampi(int(ceil(PATTERN_N * f * density)), 1, PATTERN_N)
		mm.instance_count = count
		for i in count:
			mm.set_instance_transform(i, Transform3D(Basis(), pattern[i]))
		_tiers.append(mm)
	set_process(true)
	_apply_blockers.call_deferred()


## Builds the blocker map from the finished level and hands it to the grass shader.
func _apply_blockers() -> void:
	var level := get_parent().get_parent() if get_parent() else null
	if level == null:
		return
	var t0 := Time.get_ticks_usec()
	var mask := blocker_map(level)
	material.set_shader_parameter("blocker_map", ImageTexture.create_from_image(mask.image))
	material.set_shader_parameter("blocker_rect", Vector4(-BLOCK_HALF, -BLOCK_HALF, 2.0 * BLOCK_HALF, 2.0 * BLOCK_HALF))
	blocker_stats = {"shapes": mask.shapes, "texels": mask.texels, "ms": (Time.get_ticks_usec() - t0) / 1000.0}


## The blocker map of `level`: {image (R8, 255 = no grass), shapes, texels}. Static, so
## tools/environment/check_clipping.gd can test the same map headless.
static func blocker_map(level: Node) -> Dictionary:
	var n := int(round(2.0 * BLOCK_HALF / BLOCK_RES))
	var data := PackedByteArray()
	data.resize(n * n)
	var st := {"shapes": 0, "texels": 0}
	# Vegetation: the visual footprints of the trunks, stumps, logs and rocks from its layout (the
	# colliders are slimmer than the meshes).
	var veg := level.get_node_or_null("Vegetation")
	var lay: Variant = veg.get("layout") if veg else null
	if lay != null:
		for i in lay.tree_pos.size():
			_raster_footprint(data, n, lay.trunk_footprint(i), st)
		for i in lay.prop_pos.size():
			if lay.prop_has_collider(lay.prop_kind[i]):
				_raster_footprint(data, n, lay.prop_footprint(i), st)
	for node in level.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		if cs.disabled or cs.shape == null or not (cs.get_parent() is StaticBody3D):
			continue
		var body := cs.get_parent() as Node
		if body.is_in_group(&"terrain") or _under(body, level, ["Terrain", "Player"]):
			continue
		if lay != null and _under(body, level, ["Vegetation"]):
			continue
		var xf := cs.global_transform
		var shape := cs.shape
		if shape is CylinderShape3D or shape is CapsuleShape3D or shape is SphereShape3D:
			var r: float = shape.get("radius")
			var h: float = shape.get("height") if not shape is SphereShape3D else 2.0 * r
			_raster(data, n, PackedVector2Array(), Vector3(xf.origin.x, xf.origin.z, r), xf.origin.y - h * 0.5,
					Transform3D(), Vector3.ZERO, st)
			continue
		var pts := PackedVector3Array()
		var box_e := Vector3.ZERO
		if shape is BoxShape3D:
			box_e = (shape as BoxShape3D).size * 0.5
			for sx in [-1, 1]:
				for sy in [-1, 1]:
					for sz in [-1, 1]:
						pts.append(xf * Vector3(box_e.x * sx, box_e.y * sy, box_e.z * sz))
		elif shape is ConvexPolygonShape3D:
			for p in (shape as ConvexPolygonShape3D).points:
				pts.append(xf * p)
		else:
			var ab := shape.get_debug_mesh().get_aabb()
			for k in 8:
				pts.append(xf * ab.get_endpoint(k))
		var flat := PackedVector2Array()
		var y0 := INF
		for p in pts:
			flat.append(Vector2(p.x, p.z))
			y0 = minf(y0, p.y)
		_raster(data, n, Geometry2D.convex_hull(flat), Vector3.ZERO, y0, xf.affine_inverse(), box_e, st)
	# Grass blocker boxes of visual parts that reach past their colliders (a GrassBlockers node
	# under a level child, e.g. Structures/GrassBlockers: Node3D with meta half_extents).
	for top in level.get_children():
		var gb := top.get_node_or_null("GrassBlockers")
		if gb == null:
			continue
		for b in gb.get_children():
			if not (b is Node3D and b.has_meta(&"half_extents")):
				continue
			var xf := (b as Node3D).global_transform
			var e: Vector3 = b.get_meta(&"half_extents")
			var flat := PackedVector2Array()
			var y0 := INF
			for sx in [-1, 1]:
				for sy in [-1, 1]:
					for sz in [-1, 1]:
						var p := xf * Vector3(e.x * sx, e.y * sy, e.z * sz)
						flat.append(Vector2(p.x, p.z))
						y0 = minf(y0, p.y)
			_raster(data, n, Geometry2D.convex_hull(flat), Vector3.ZERO, y0, xf.affine_inverse(), e, st)
	return {"image": Image.create_from_data(n, n, false, Image.FORMAT_R8, data), "shapes": st.shapes, "texels": st.texels}


## Rasterises a vegetation footprint (veg_geom.gd layout: [type, cx, cz, a, b, ux, uz, y0, y1]).
static func _raster_footprint(data: PackedByteArray, n: int, f: PackedFloat32Array, st: Dictionary) -> void:
	if f[0] == 0.0:
		_raster(data, n, PackedVector2Array(), Vector3(f[1], f[2], f[3]), f[7], Transform3D(), Vector3.ZERO, st)
		return
	var c := Vector2(f[1], f[2])
	var u := Vector2(f[5], f[6]) * f[3]
	var v := Vector2(-f[6], f[5]) * f[4]
	_raster(data, n, PackedVector2Array([c - u - v, c + u - v, c + u + v, c - u + v]), Vector3.ZERO, f[7],
			Transform3D(), Vector3.ZERO, st)


## Marks the texels of a circle (circle.z > 0: centre x, z and radius) or convex polygon, grown by
## BLOCK_GROW. A raised or tilted box (box_e != 0, inv = its inverse transform) only blocks where
## its underside is within BLOCK_CLEAR of the ground.
static func _raster(data: PackedByteArray, n: int, poly_in: PackedVector2Array, circle: Vector3, y0: float,
		inv: Transform3D, box_e: Vector3, st: Dictionary) -> void:
	var poly := poly_in
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	if circle.z > 0.0:
		var rr := circle.z + BLOCK_GROW
		lo = Vector2(circle.x - rr, circle.y - rr)
		hi = Vector2(circle.x + rr, circle.y + rr)
	else:
		if poly.size() < 3:
			return
		var grown := Geometry2D.offset_polygon(poly, BLOCK_GROW)
		if not grown.is_empty():
			poly = grown[0]
		for p in poly:
			lo = lo.min(p)
			hi = hi.max(p)
	var ground := FrontierTerrain.height_at((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5)
	if y0 > ground + BLOCK_CLEAR + 0.5:
		return
	st.shapes += 1
	var i0 := clampi(int(floor((lo.x + BLOCK_HALF) / BLOCK_RES)), 0, n - 1)
	var i1 := clampi(int(floor((hi.x + BLOCK_HALF) / BLOCK_RES)), 0, n - 1)
	var j0 := clampi(int(floor((lo.y + BLOCK_HALF) / BLOCK_RES)), 0, n - 1)
	var j1 := clampi(int(floor((hi.y + BLOCK_HALF) / BLOCK_RES)), 0, n - 1)
	var rr2 := (circle.z + BLOCK_GROW) * (circle.z + BLOCK_GROW)
	var raised := box_e != Vector3.ZERO and y0 > ground + 0.05
	for j in range(j0, j1 + 1):
		var z := -BLOCK_HALF + (j + 0.5) * BLOCK_RES
		for i in range(i0, i1 + 1):
			var x := -BLOCK_HALF + (i + 0.5) * BLOCK_RES
			if circle.z > 0.0:
				if Vector2(x - circle.x, z - circle.y).length_squared() > rr2:
					continue
			elif not Geometry2D.is_point_in_polygon(Vector2(x, z), poly):
				continue
			if raised and _box_bottom(inv, box_e, x, z) > FrontierTerrain.height_at(x, z) + BLOCK_CLEAR:
				continue
			var k := j * n + i
			if data[k] == 0:
				data[k] = 255
				st.texels += 1


## True when the blocker map removes grass at (x, z).
static func blocked(mask: Dictionary, x: float, z: float) -> bool:
	var img: Image = mask.image
	var i := int(floor((x + BLOCK_HALF) / BLOCK_RES))
	var j := int(floor((z + BLOCK_HALF) / BLOCK_RES))
	if i < 0 or j < 0 or i >= img.get_width() or j >= img.get_height():
		return false
	return img.get_pixel(i, j).r > 0.5


static func _under(n: Node, level: Node, names: Array) -> bool:
	var p := n
	while p and p.get_parent() != level:
		p = p.get_parent()
	return p != null and String(p.name) in names


## Lowest y of a box (inverse transform, half extents; the box's scale is in the transform) on
## the vertical line through (x, z), or INF when the line misses it (grown by BLOCK_GROW, so a
## tuft beside the edge still counts).
static func _box_bottom(inv: Transform3D, e: Vector3, x: float, z: float) -> float:
	var o := inv * Vector3(x, -1000.0, z)
	var d := inv.basis * Vector3.UP
	var t0 := -INF
	var t1 := INF
	for a in 3:
		var ea := e[a] + BLOCK_GROW
		if absf(d[a]) < 1e-9:
			if absf(o[a]) > ea:
				return INF
			continue
		var ta := (-ea - o[a]) / d[a]
		var tb := (ea - o[a]) / d[a]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t0 > t1:
		return INF
	return -1000.0 + t0


## The grass material for square `sq` (the fort's by default): its ground textures, its middle.
func _make_material(sq := Vector2i.ZERO) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH)
	m.set_shader_parameter("atlas", load(ATLAS_PATH))
	var fort := sq == Vector2i.ZERO
	var tex: Dictionary = terrain.get("textures") if fort else (terrain.get("square_textures") as Dictionary).get(sq, {})
	for k in ["height_map", "splat0", "splat1", "terrain_normal", "core_map"]:
		if tex.has(k):
			m.set_shader_parameter(k, tex[k])
	var o := FrontierTerrain.square_origin(sq)
	m.set_shader_parameter("square_origin", Vector2(o.x, o.z))
	m.set_shader_parameter("grid_half", float(FrontierTerrain.GRID_HALF))
	m.set_shader_parameter("grid_size", float(FrontierTerrain.GRID_N))
	m.set_shader_parameter("core_rect", Vector4(FrontierTerrain.CORE_X0, FrontierTerrain.CORE_Z0,
			FrontierTerrain.CORE_W, FrontierTerrain.CORE_D) if fort else FrontierTerrain.NO_CORE)
	m.set_shader_parameter("grass_h_scale", FrontierTerrain.GRASS_H_SCALE)
	m.set_shader_parameter("grass_distance", distance)
	m.set_shader_parameter("full_density_dist", FULL_DENSITY_DIST)
	m.set_shader_parameter("density_scale", density)
	m.set_shader_parameter("pattern_n", float(PATTERN_N))
	# Atlas cells: uv rect and aspect (width / height) per variant.
	var rects := PackedVector4Array()
	var aspects := PackedFloat32Array()
	rects.resize(MAX_VARIANTS)
	aspects.resize(MAX_VARIANTS)
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(VARIANTS_PATH)) if FileAccess.file_exists(VARIANTS_PATH) else null
	if meta is Array:
		for v: Dictionary in meta:
			var i := int(v.cell)
			if i < MAX_VARIANTS:
				var r: Array = v.uv_rect
				rects[i] = Vector4(r[0], r[1], r[2], r[3])
				aspects[i] = float(v.aspect)
	m.set_shader_parameter("variant_rects", rects)
	m.set_shader_parameter("variant_aspects", aspects)
	# the herbs and wildflowers some tufts become (grass.gdshader pick_herb; make_herb_atlas.py)
	var hrects := PackedVector4Array()
	var haspects := PackedFloat32Array()
	hrects.resize(MAX_VARIANTS)
	haspects.resize(MAX_VARIANTS)
	var hmeta: Variant = JSON.parse_string(FileAccess.get_file_as_string(HERBS_PATH)) if FileAccess.file_exists(HERBS_PATH) else null
	if hmeta is Array and ResourceLoader.exists(HERB_ATLAS_PATH):
		for v: Dictionary in hmeta:
			var i := int(v.cell)
			if i < MAX_VARIANTS:
				var r: Array = v.uv_rect
				hrects[i] = Vector4(r[0], r[1], r[2], r[3])
				haspects[i] = float(v.aspect)
		m.set_shader_parameter("herb_atlas", load(HERB_ATLAS_PATH))
	else:
		m.set_shader_parameter("herb_chance", 0.0)
	m.set_shader_parameter("herb_rects", hrects)
	m.set_shader_parameter("herb_aspects", haspects)
	return m


## Three crossed vertical cards (60 degrees apart), 6 triangles. The card-local position is in
## UV (x across, y up) and the plane angle in COLOR.r; the shader builds the world vertex.
static func tuft_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for p in 3:
		var a := p * PI / 3.0
		var d := Vector3(cos(a), 0.0, sin(a)) * 0.5
		var base := verts.size()
		for c in [[0.0, 1.0], [1.0, 1.0], [1.0, 0.0], [0.0, 0.0]]:
			var u: float = c[0]
			var v: float = c[1]
			verts.append(d * (u * 2.0 - 1.0) + Vector3(0, 1.0 - v, 0))
			uvs.append(Vector2(u, v))
			cols.append(Color(float(p) / 3.0, 0, 0, 1))
			norms.append(Vector3.UP)
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 25 x 25 jittered points in a cell centred on the origin, in a fixed random order.
static func _pattern() -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1778
	var pts := PackedVector3Array()
	var step := CELL / PATTERN_SIDE
	for j in PATTERN_SIDE:
		for i in PATTERN_SIDE:
			pts.append(Vector3(-CELL * 0.5 + (i + rng.randf()) * step, 0.0, -CELL * 0.5 + (j + rng.randf()) * step))
	for i in range(pts.size() - 1, 0, -1):
		var k := rng.randi_range(0, i)
		var t := pts[i]
		pts[i] = pts[k]
		pts[k] = t
	return pts


func _process(_delta: float) -> void:
	var cam := _camera()
	if cam == null:
		return
	var p := cam.global_position
	var c := Vector2(p.x, p.z)
	if c.distance_squared_to(_last) < 1.0:
		return
	_last = c
	_update(c)


func _camera() -> Node3D:
	if follow and is_instance_valid(follow):
		return follow
	for ch in get_tree().root.get_children():
		var sv := ch as SubViewport
		if sv and sv.render_target_update_mode == SubViewport.UPDATE_ALWAYS and not sv.own_world_3d:
			var sc := sv.get_camera_3d()
			if sc:
				return sc
	return get_viewport().get_camera_3d()


## Shader density at distance d (fraction of the full pattern), before local ground density.
func density_at(d: float) -> float:
	var d1 := maxf(distance * 0.8, FULL_DENSITY_DIST + 1.0)
	if d <= FULL_DENSITY_DIST:
		return 1.0
	if d <= d1:
		return lerpf(1.0, 0.25, (d - FULL_DENSITY_DIST) / (d1 - FULL_DENSITY_DIST))
	return 0.25


func _update(c: Vector2) -> void:
	var ci := int(floor(c.x / CELL))
	var cj := int(floor(c.y / CELL))
	var keep := {}
	for j in range(cj - _reach, cj + _reach + 1):
		for i in range(ci - _reach, ci + _reach + 1):
			var x0 := i * CELL
			var z0 := j * CELL
			var nx := clampf(c.x, x0, x0 + CELL)
			var nz := clampf(c.y, z0, z0 + CELL)
			var d := Vector2(nx, nz).distance_to(c)
			if d > distance:
				continue
			if not FrontierTerrain.in_world(x0 + CELL * 0.5, z0 + CELL * 0.5):
				continue
			var cmax := _cell_density(i, j)
			if cmax <= 0.0:
				continue
			var key := Vector2i(i, j)
			keep[key] = true
			# Smallest tier that holds every tuft the shader can show in this cell (1 m slack:
			# cells are re-tiered after every metre of camera travel).
			var need := density_at(maxf(d - 1.0, 0.0)) * density * cmax
			var tier := 0
			for t in range(TIER_FRACTIONS.size() - 1, -1, -1):
				if TIER_FRACTIONS[t] * density >= need - 1e-4:
					tier = t
					break
			var node: MultiMeshInstance3D = cells.get(key)
			if node == null:
				node = _take()
				_place(node, key)
				cells[key] = node
				_tier_of[key] = -1
			if _tier_of[key] != tier:
				node.multimesh = _tiers[tier]
				_tier_of[key] = tier
	for key: Vector2i in cells.keys():
		if not keep.has(key):
			var node: MultiMeshInstance3D = cells[key]
			node.visible = false
			_pool.append(node)
			cells.erase(key)
			_tier_of.erase(key)


## Baked maximum local density (meadow 1, forest floor ~0.3, bare 0) of the 8 m cell (i, j).
func _cell_density(i: int, j: int) -> float:
	if _cell_max.is_empty():
		return 1.0
	var sq := _square_of(i, j)
	var cm := _cell_max if sq == Vector2i.ZERO else (_square_cells.get(sq, PackedByteArray()) as PackedByteArray)
	if cm.is_empty():
		return 0.0
	var per := int(FrontierTerrain.SQUARE_M / CELL)
	var a := i - sq.x * per + _cell_off
	var b := j - sq.y * per + _cell_off
	if a < 0 or b < 0 or a >= _cell_n or b >= _cell_n:
		return 0.0
	return cm[b * _cell_n + a] / 255.0


## The square of ground cell (i, j) lies in.
func _square_of(i: int, j: int) -> Vector2i:
	var h := float(FrontierTerrain.GRID_HALF)
	return Vector2i(floori(((i + 0.5) * CELL + h) / FrontierTerrain.SQUARE_M), floori(((j + 0.5) * CELL + h) / FrontierTerrain.SQUARE_M))


func _take() -> MultiMeshInstance3D:
	if not _pool.is_empty():
		var n: MultiMeshInstance3D = _pool.pop_back()
		n.visible = true
		return n
	var node := MultiMeshInstance3D.new()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	return node


func _place(node: MultiMeshInstance3D, key: Vector2i) -> void:
	var cx := (key.x + 0.5) * CELL
	var cz := (key.y + 0.5) * CELL
	# Four pattern orientations per cell break up the 8 m repeat.
	var rot := float(posmod(key.x * 73856093 ^ key.y * 19349663, 4)) * PI * 0.5
	node.transform = Transform3D(Basis(Vector3.UP, rot), Vector3(cx, 0.0, cz))
	var sq := _square_of(key.x, key.y)
	node.material_override = material if sq == Vector2i.ZERO else _square_mats.get(sq, material)
	var lo := INF
	var hi := -INF
	for o: Vector2 in [Vector2.ZERO, Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 4), Vector2(4, 4)]:
		var h := FrontierTerrain.height_at(cx + o.x, cz + o.y)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	node.custom_aabb = AABB(Vector3(-5.0, lo - 1.0, -5.0), Vector3(10.0, hi - lo + 2.2, 10.0))
