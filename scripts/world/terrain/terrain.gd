class_name FrontierTerrain
extends Node3D
## Ground of the Frontier level: height field, splat-mapped material, grass and the ground
## colliders (look-dev spec, sections 5 and 6). Owner: package B.
##
## Integration API (frozen; see the spec, section 11):
##   var t := FrontierTerrain.new(); t.name = "Terrain"; add_child(t)
##   t.build(settings)             -- collision (always), chunk meshes and grass (windowed
##                                    only). Called right after EnvironmentRig.build(), before
##                                    structures and vegetation.
##   FrontierTerrain.height_at(x, z)   rendered ground height (m); exactly 0.0 in the flat zones.
##                                    Same samples and triangle split as the LOD0 mesh and the
##                                    collision, so a point placed at height_at sits on both.
##   FrontierTerrain.normal_at(x, z)   ground normal
##   FrontierTerrain.flat_distance(x, z), flat_blend(x, z), in_flat_zone(x, z)
##   FrontierTerrain.ground_layers(x, z)  splat weights, PackedFloat32Array indexed by LAYER_*
##                                    (sums to 1); vegetation uses them to pick what grows where
##   FrontierTerrain.forest_density(x, z) 0 open ground (clearing, meadow, range lane, glades,
##                                    path corridors) .. 1 closed forest; the forest edge is
##                                    defined here (edge ~12-22 m outside the flat zones, +-6 m
##                                    noise), trees follow it
## Extra statics (additive): grass_height_at(x, z) (m, 0 = no grass), collision_height_at(x, z)
## (TerrainBody surface: height_at minus 5 cm on flat-zone samples), data_loaded().
## All statics are deterministic and cheap (1-4 us; vegetation calls them tens of thousands of
## times). They lazily load the baked data, so they work before build() and in tools.
##
## Data: baked offline (tools/environment/terrain/bake_terrain.py, then pack_terrain.gd) into
## assets/environment/terrain/*.res: an 833 x 833 height field at 1 m covering +-416 m
## (x = i - 416, z = j - 416), splat control maps at 1 m, a 0.25 m detail map over the fort and
## range, normals/AO, chunk bounds and the surface overlay colliders.
##
## Collision contract (audio: Sfx.surface_of and Footsteps):
##   GroundFloor   group "terrain", NO "surface" meta: boxes over exactly the flat zones, top at
##                 y = 0, so the fort floor and range lane read as dirt (Sfx.is_dirt) and the
##                 rest of the flat ground as grass (rule 4).
##   TerrainBody   group "terrain", meta surface = "grass": 13 x 13 HeightMapShape3D chunks
##                 (65 x 65 at 1 m, a power of two plus one for Jolt); flat-zone samples lie
##                 5 cm below the box so the box wins there.
##   GroundDirt    group "terrain", meta surface = "dirt": trampled paths and the brook bed
##                 outside the flat zones, 1.5 cm above the terrain (footsteps and bullet
##                 impacts sound like dirt there).
##   GroundStone   group "terrain", meta surface = "stone": rock outcrops and steep rock.
##   WorldEdge     invisible walls at +-410 m (the height field ends at +-416 m).
##
## Rendering: 13 x 13 chunks of 64 m, each with 4 LOD MeshInstance3Ds sharing four flat grid
## meshes (1/2/4/8 m) that the shader displaces; visibility ranges 100 / 220 / 450 m
## (x WorldSettings.terrain_lod_scale), exact (no hysteresis margins); 1.5 m skirts hide cracks.
## Only LOD2/3 (220 m+) cast shadows (see NEAR_SHADOWS).
## Only LOD0/1 are in the global illumination (SDFGI voxelizes every LOD at once; the coarse grids over the river's
## channel read as solid over its bed).
## Grass: FrontierGrass (grass.gd), streamed around the camera. Headless builds skip meshes
## and grass (colliders only).
##
## Squares of ground (user 2026-09-27: "add another square map thats open planes with a river to a lake"; the world's
## squares: WorldSquares, data/world/squares.json): the ground is baked a square at a time (bake_terrain.py --square),
## each the same 833 x 833 layout about its own middle, the fort's (0, 0) in DATA_DIR, another in DATA_DIR/sq_X_Y/.
## Every square found is loaded and set side by side (SQUARE_M apart: neighbours share their edge samples, so they meet
## without a seam): the statics sample the square under (x, z) (past the ground there is: the nearest square's edge), the
## meshes, collision and grass are built for each (a material per square: the shaders' square_origin), and the
## WorldEdge walls stand only where the ground ends (a side with no square beyond). in_world(): on the ground there is.
##
## Debug switches (command line user args, B-local): terrain_debug=placeholder builds the old
## flat plane instead (A/B cost), grass_density=<0..1> overrides WorldSettings.grass_density.

## Flat zones (gameplay layout, fixed): the fort and its clearing, and the range lane.
const FORT_FLAT_HALF := 26.0
const LANE_FLAT_HALF_X := 14.0
const LANE_FLAT_Z_MIN := -175.0
const LANE_FLAT_Z_MAX := -12.0
## Width (m) over which the terrain blends from the flat zones into the hills.
const BLEND_WIDTH := 24.0
## World extent of the ground (square, centred on the fort). The height field extends to
## GRID_HALF so the outer bowl rises past the playable edge.
const WORLD_HALF := 400.0

enum { LAYER_GRASS, LAYER_DRY_GRASS, LAYER_DIRT, LAYER_MUD, LAYER_FOREST_FLOOR, LAYER_ROCK, LAYER_COUNT }

const FORT_HALF := 16.0
const FIRING_LINE_Z := -20.0

## Baked data layout (keep in sync with tools/environment/terrain/bake_terrain.py).
const DATA_DIR := "res://assets/environment/terrain/"
## The region loader (Thủy Vân; WorldRegion): a region's baked ground when it names one (data_dir), DATA_DIR otherwise.
const Region := preload("res://scripts/world/world_region.gd")
const GRID_HALF := 416
const GRID_N := 833
const CHUNK_SIZE := 64
const CHUNK_COUNT := 13
const CORE_X0 := -32.0
const CORE_Z0 := -184.0
const CORE_W := 64.0
const CORE_D := 216.0
const CORE_NX := 256
const CORE_NZ := 864
## Grass height channels: 1.0 = GRASS_H_SCALE metres.
const GRASS_H_SCALE := 0.8
## LOD switch distances (m) at terrain_lod_scale 1 (1 m grid, 2 m, 4 m, then 8 m).
const LOD_DISTANCES := [100.0, 220.0, 450.0]
const LOD_STEPS := [1, 2, 4, 8]
## No margins: with fade off, margins act as hysteresis, and a camera that jumps into a
## margin band (a teleport, a respawn, the tools' fixed views) left both neighbouring LODs
## hidden: holes. All LODs of a chunk share one AABB, so exact ranges tile without gaps.
const LOD_MARGIN := 0.0
## Only the far LODs (LOD2/3, 220 m+) cast shadows: the ridge, the backstop hill and the rim
## shading valleys at the low sun (spec 4.4). Near the fort the relief is far gentler than the
## sun's 19 deg, so near-terrain shadows are practically invisible (N.L already darkens the
## lee sides), and casting them cost ~0.4 ms at 1600x900 whatever the caster resolution
## (measured with tools/environment/terrain/terrain_cost.gd). Set true to have every LOD cast.
const NEAR_SHADOWS := false
const SKIRT_DEPTH := 1.5
const FLAT_COLLISION_DROP := 0.05
const EDGE_WALL := 410.0
## A square's side (its grid's; neighbours share their edge samples) and where another square's data lies.
const SQUARE_M := 832.0
const SQUARE_DIR := "sq_%d_%d/"
## The detail rectangle for a square without one (never met).
const NO_CORE := Vector4(1e7, 1e7, 1.0, 1.0)

const SHADER_PATH := "res://shaders/terrain/terrain.gdshader"
const ALBEDO_ARRAY_PATH := "res://assets/environment/terrain/textures/terrain_albedo_array.webp"
const NRM_ARRAY_PATH := "res://assets/environment/terrain/textures/terrain_nrm_array.webp"
const GRASS_SCRIPT := "res://scripts/world/terrain/grass.gd"

static var _heights := PackedFloat32Array()
static var _splat0 := PackedByteArray()
static var _splat1 := PackedByteArray()
static var _normals := PackedByteArray()
static var _core := PackedByteArray()
static var _collision := PackedFloat32Array()
static var _images := {}
static var _data_ok := false
static var _data_tried := false
## Every square with ground: Vector2i -> {sq, ox, oz (its middle), h, s0, s1, nm (its data), col (collision, when
## read), dir}. The fort's (0, 0) is also in the arrays above (its fast path).
static var _squares := {}
static var _nearest_of := {}

var settings: WorldSettings
var material: ShaderMaterial
var grass: Node3D
var ground_floor: StaticBody3D
var terrain_body: StaticBody3D
var textures := {}
var _mats := {}
## Another square's textures and material (the fort's: textures, material): Vector2i -> {} / ShaderMaterial.
var square_textures := {}
var square_materials := {}


## A level with no fort (a start with nothing): the fort's clearing and the range lane are open ground, grown over like the rest.
static var open_ground := false


# --- Static API ------------------------------------------------------------------------------

## Distance (m) from (x, z) to the nearest flat zone (0 inside one).
static func flat_distance(x: float, z: float) -> float:
	if open_ground:
		return 1000.0
	var fx := maxf(absf(x) - FORT_FLAT_HALF, 0.0)
	var fz := maxf(absf(z) - FORT_FLAT_HALF, 0.0)
	var d_fort := Vector2(fx, fz).length()
	var lx := maxf(absf(x) - LANE_FLAT_HALF_X, 0.0)
	var lz := maxf(maxf(LANE_FLAT_Z_MIN - z, z - LANE_FLAT_Z_MAX), 0.0)
	var d_lane := Vector2(lx, lz).length()
	return minf(d_fort, d_lane)


static func in_flat_zone(x: float, z: float) -> bool:
	if open_ground:
		return false
	return (absf(x) <= FORT_FLAT_HALF and absf(z) <= FORT_FLAT_HALF) \
			or (absf(x) <= LANE_FLAT_HALF_X and z >= LANE_FLAT_Z_MIN and z <= LANE_FLAT_Z_MAX)


## 0 inside the flat zones, smoothstep up to 1 at BLEND_WIDTH outside them.
static func flat_blend(x: float, z: float) -> float:
	return smoothstep(0.0, BLEND_WIDTH, flat_distance(x, z))


## Rendered ground height (m). Exactly 0.0 in the flat zones. Linear over the two triangles of
## each 1 m cell, split along the (x+1, z)-(x, z+1) diagonal like the collision and LOD0 mesh.
static func height_at(x: float, z: float) -> float:
	if in_flat_zone(x, z):
		return 0.0
	if not _data_ok and not _ensure_data():
		return 0.0
	if _in_fort(x, z):
		return _tri_sample(_heights, x, z)
	var d := _data_at(x, z)
	return _tri_sample(d.h, x - float(d.ox), z - float(d.oz))


## Whether (x, z) is in the fort's square (its arrays: the fast path), or it is the only one.
static func _in_fort(x: float, z: float) -> bool:
	return (absf(x) <= GRID_HALF and absf(z) <= GRID_HALF) or _squares.size() <= 1


## The square with ground under (x, z) (x = GRID_HALF itself: the next one, its first samples the same), or past the
## ground there is, the nearest.
static func _data_at(x: float, z: float) -> Dictionary:
	var sq := Vector2i(floori((x + GRID_HALF) / SQUARE_M), floori((z + GRID_HALF) / SQUARE_M))
	var d: Variant = _squares.get(sq)
	if d != null:
		return d
	if not _nearest_of.has(sq):
		var best := Vector2i.ZERO
		var bd := INF
		for o: Vector2i in _squares:
			var dd := Vector2(o - sq).length()
			if dd < bd:
				bd = dd
				best = o
		_nearest_of[sq] = best
	return _squares[_nearest_of[sq]]


## The squares with ground (the fort's first).
static func squares() -> Array[Vector2i]:
	if not _data_ok:
		_ensure_data()
	var out: Array[Vector2i] = [Vector2i.ZERO]
	for sq: Vector2i in _squares:
		if sq != Vector2i.ZERO:
			out.append(sq)
	return out


## Square `sq`'s middle.
static func square_origin(sq: Vector2i) -> Vector3:
	return Vector3(float(sq.x) * SQUARE_M, 0.0, float(sq.y) * SQUARE_M)


## Whether (x, z) is on the ground there is: in a square with ground, and no further than WORLD_HALF from its middle
## toward a side with no square beyond (the walls stand just past it).
static func in_world(x: float, z: float) -> bool:
	if not _data_ok and not _ensure_data():
		return absf(x) <= WORLD_HALF and absf(z) <= WORLD_HALF
	var sq := Vector2i(floori((x + GRID_HALF) / SQUARE_M), floori((z + GRID_HALF) / SQUARE_M))
	if not _squares.has(sq):
		return false
	var lx := x - float(sq.x) * SQUARE_M
	var lz := z - float(sq.y) * SQUARE_M
	if (lx > WORLD_HALF and not _squares.has(sq + Vector2i(1, 0))) or (lx < -WORLD_HALF and not _squares.has(sq + Vector2i(-1, 0))):
		return false
	if (lz > WORLD_HALF and not _squares.has(sq + Vector2i(0, 1))) or (lz < -WORLD_HALF and not _squares.has(sq + Vector2i(0, -1))):
		return false
	return true


## Height of the TerrainBody collision surface (height_at, 5 cm lower on flat-zone samples).
static func collision_height_at(x: float, z: float) -> float:
	if not _data_ok and not _ensure_data():
		return 0.0
	if not _in_fort(x, z):
		var d := _data_at(x, z)
		return _tri_sample(_square_collision(d), x - float(d.ox), z - float(d.oz))
	if _collision.is_empty():
		var img := data_image("terrain_collision.res")
		if img == null:
			return height_at(x, z)
		_collision = img.get_data().to_float32_array()
	return _tri_sample(_collision, x, z)


## A square's collision heights (read when first asked for).
static func _square_collision(d: Dictionary) -> PackedFloat32Array:
	if (d.col as PackedFloat32Array).is_empty():
		var img := data_image(String(d.dir) + "terrain_collision.res")
		d.col = img.get_data().to_float32_array() if img else d.h
	return d.col


static func normal_at(x: float, z: float) -> Vector3:
	if in_flat_zone(x, z):
		return Vector3.UP
	if not _data_ok and not _ensure_data():
		return Vector3.UP
	var b := _normals
	if not _in_fort(x, z):
		var d := _data_at(x, z)
		b = d.nm
		x -= float(d.ox)
		z -= float(d.oz)
	var fx := clampf(x + GRID_HALF, 0.0, GRID_N - 1.0001)
	var fz := clampf(z + GRID_HALF, 0.0, GRID_N - 1.0001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var k := (j * GRID_N + i) * 4
	var k2 := k + GRID_N * 4
	var nx := lerpf(lerpf(b[k], b[k + 4], u), lerpf(b[k2], b[k2 + 4], u), v) / 127.5 - 1.0
	var nz := lerpf(lerpf(b[k + 1], b[k + 5], u), lerpf(b[k2 + 1], b[k2 + 5], u), v) / 127.5 - 1.0
	return Vector3(nx, sqrt(maxf(1.0 - nx * nx - nz * nz, 0.0)), nz).normalized()


## Splat weights at (x, z), indexed by LAYER_*; they sum to 1. Inside the fort / range detail
## rectangle the 0.25 m detail map supplies dirt and mud, exactly like the terrain shader.
static func ground_layers(x: float, z: float) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(LAYER_COUNT)
	if not _data_ok and not _ensure_data():
		w[LAYER_DIRT if Sfx.is_dirt(Vector3(x, 0.0, z)) else LAYER_GRASS] = 1.0
		return w
	var sp0 := _splat0
	var sp1 := _splat1
	var lx := x
	var lz := z
	if not _in_fort(x, z):
		var d := _data_at(x, z)
		sp0 = d.s0
		sp1 = d.s1
		lx -= float(d.ox)
		lz -= float(d.oz)
	var fx := clampf(lx + GRID_HALF, 0.0, GRID_N - 1.0001)
	var fz := clampf(lz + GRID_HALF, 0.0, GRID_N - 1.0001)
	var a := _bilerp4(sp0, GRID_N, fx, fz)
	var b := _bilerp4(sp1, GRID_N, fx, fz)
	var grass := a.x
	var dry := a.y
	var dirt := a.z
	var mud := a.w
	var forest := b.x
	var rock := b.y
	var cu := (x - CORE_X0) / CORE_W
	var cv := (z - CORE_Z0) / CORE_D
	if cu > 0.0 and cv > 0.0 and cu < 1.0 and cv < 1.0:
		var c := _bilerp4(_core, CORE_NX, clampf(cu * CORE_NX - 0.5, 0.0, CORE_NX - 1.0001),
				clampf(cv * CORE_NZ - 0.5, 0.0, CORE_NZ - 1.0001))
		var k := clampf(minf(minf(cu, 1.0 - cu) * CORE_W, minf(cv, 1.0 - cv) * CORE_D) * 0.5, 0.0, 1.0)
		dirt = lerpf(dirt, c.z, k)
		mud = lerpf(mud, c.x, k)
		var rest_base := grass + dry + forest + rock
		var rest := maxf(1.0 - dirt - mud, 0.0)
		if rest_base < 0.004:
			grass = rest
		else:
			var sc := rest / rest_base
			grass *= sc
			dry *= sc
			forest *= sc
			rock *= sc
	var total := maxf(grass + dry + dirt + mud + forest + rock, 1e-6)
	w[LAYER_GRASS] = grass / total
	w[LAYER_DRY_GRASS] = dry / total
	w[LAYER_DIRT] = dirt / total
	w[LAYER_MUD] = mud / total
	w[LAYER_FOREST_FLOOR] = forest / total
	w[LAYER_ROCK] = rock / total
	return w


## 0 = open (fort clearing, range lane, meadows, glades, path corridors) .. 1 = closed forest.
static func forest_density(x: float, z: float) -> float:
	if in_flat_zone(x, z):
		return 0.0
	if not _data_ok and not _ensure_data():
		return 0.0 if flat_distance(x, z) < 10.0 else 1.0
	var b := _splat1
	if not _in_fort(x, z):
		var d := _data_at(x, z)
		b = d.s1
		x -= float(d.ox)
		z -= float(d.oz)
	var fx := clampf(x + GRID_HALF, 0.0, GRID_N - 1.0001)
	var fz := clampf(z + GRID_HALF, 0.0, GRID_N - 1.0001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var k := (j * GRID_N + i) * 4 + 2
	var k2 := k + GRID_N * 4
	return lerpf(lerpf(b[k], b[k + 4], u), lerpf(b[k2], b[k2 + 4], u), v) / 255.0


## Grass height (m) the grass system grows at (x, z); 0 = bare (dirt, mud, rock, fort floor).
static func grass_height_at(x: float, z: float) -> float:
	if not _data_ok and not _ensure_data():
		return 0.0
	var cu := (x - CORE_X0) / CORE_W
	var cv := (z - CORE_Z0) / CORE_D
	if cu > 0.0 and cv > 0.0 and cu < 1.0 and cv < 1.0:
		var c := _bilerp4(_core, CORE_NX, clampf(cu * CORE_NX - 0.5, 0.0, CORE_NX - 1.0001),
				clampf(cv * CORE_NZ - 0.5, 0.0, CORE_NZ - 1.0001))
		return c.w * GRASS_H_SCALE
	var b := _splat1
	if not _in_fort(x, z):
		var d := _data_at(x, z)
		b = d.s1
		x -= float(d.ox)
		z -= float(d.oz)
	var fx := clampf(x + GRID_HALF, 0.0, GRID_N - 1.0001)
	var fz := clampf(z + GRID_HALF, 0.0, GRID_N - 1.0001)
	return _bilerp4(b, GRID_N, fx, fz).w * GRASS_H_SCALE


static func data_loaded() -> bool:
	return _data_ok or _ensure_data()


## The baked data's folder: the region's (WorldRegion.terrain_dir), DATA_DIR with none.
static func data_dir() -> String:
	return Region.terrain_dir()


## Baked Image resource (terrain_height.res etc.), loaded once.
static func data_image(file: String) -> Image:
	if not _images.has(file):
		_images[file] = _load_image(file)
	return _images[file]


static func _ensure_data() -> bool:
	if _data_tried:
		return _data_ok
	_data_tried = true
	var h := data_image("terrain_height.res")
	var s0 := data_image("terrain_splat0.res")
	var s1 := data_image("terrain_splat1.res")
	var nm := data_image("terrain_normal.res")
	var core := data_image("terrain_core.res")
	if h == null or s0 == null or s1 == null or nm == null or core == null \
			or h.get_width() != GRID_N or h.get_format() != Image.FORMAT_RF:
		push_warning("FrontierTerrain: baked terrain data missing under %s; using the flat placeholder" % data_dir())
		return false
	_heights = h.get_data().to_float32_array()
	var n4 := GRID_N * GRID_N * 4
	_splat0 = s0.get_data().slice(0, n4)
	_splat1 = s1.get_data().slice(0, n4)
	_normals = nm.get_data().slice(0, n4)
	_core = core.get_data().slice(0, CORE_NX * CORE_NZ * 4)
	_squares[Vector2i.ZERO] = {"sq": Vector2i.ZERO, "ox": 0.0, "oz": 0.0, "h": _heights, "s0": _splat0, "s1": _splat1,
			"nm": _normals, "col": PackedFloat32Array(), "dir": ""}
	# the other squares baked (WorldSquares' grid)
	for sq in WorldSquares.squares():
		if sq == Vector2i.ZERO:
			continue
		var dir := SQUARE_DIR % [sq.x, sq.y]
		var sh := data_image(dir + "terrain_height.res")
		var ss0 := data_image(dir + "terrain_splat0.res")
		var ss1 := data_image(dir + "terrain_splat1.res")
		var snm := data_image(dir + "terrain_normal.res")
		if sh == null or ss0 == null or ss1 == null or snm == null or sh.get_width() != GRID_N:
			continue
		var o := square_origin(sq)
		_squares[sq] = {"sq": sq, "ox": o.x, "oz": o.z, "h": sh.get_data().to_float32_array(),
				"s0": ss0.get_data().slice(0, n4), "s1": ss1.get_data().slice(0, n4), "nm": snm.get_data().slice(0, n4),
				"col": PackedFloat32Array(), "dir": dir}
	_data_ok = true
	return true


static func _load_image(file: String) -> Image:
	var path := data_dir() + file
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Image


## Triangle-interpolated sample of an N x N float grid (the height-field triangulation).
static func _tri_sample(data: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf(x + GRID_HALF, 0.0, GRID_N - 1.0001)
	var fz := clampf(z + GRID_HALF, 0.0, GRID_N - 1.0001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var k := j * GRID_N + i
	if u + v <= 1.0:
		var h00 := data[k]
		return h00 + (data[k + 1] - h00) * u + (data[k + GRID_N] - h00) * v
	var h11 := data[k + GRID_N + 1]
	return h11 + (data[k + GRID_N] - h11) * (1.0 - u) + (data[k + 1] - h11) * (1.0 - v)


## Bilinear RGBA8 sample (0..1) at texel coordinates (texel centres on integers).
static func _bilerp4(b: PackedByteArray, width: int, fx: float, fz: float) -> Vector4:
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var k := (j * width + i) * 4
	var k2 := k + width * 4
	var q00 := Vector4(b[k], b[k + 1], b[k + 2], b[k + 3])
	var q10 := Vector4(b[k + 4], b[k + 5], b[k + 6], b[k + 7])
	var q01 := Vector4(b[k2], b[k2 + 1], b[k2 + 2], b[k2 + 3])
	var q11 := Vector4(b[k2 + 4], b[k2 + 5], b[k2 + 6], b[k2 + 7])
	return q00.lerp(q10, u).lerp(q01.lerp(q11, u), v) / 255.0


# --- Build -------------------------------------------------------------------------------------

func build(world_settings: WorldSettings) -> void:
	settings = world_settings if world_settings else WorldSettings.preset(WorldSettings.DEFAULT_QUALITY)
	var gd := _user_arg("grass_density")
	if gd != "":
		settings.grass_density = clampf(gd.to_float(), 0.0, 1.0)
	if _user_arg("terrain_debug") == "placeholder" or not _ensure_data():
		_build_placeholder()
		return
	_build_collision()
	if DisplayServer.get_name() == "headless":
		return
	_build_meshes()
	if settings.grass_density > 0.0:
		grass = load(GRASS_SCRIPT).new()
		grass.name = "Grass"
		add_child(grass)
		grass.call("build", self, settings)


static func _user_arg(key: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		var s := a.trim_prefix("--")
		if s.begins_with(key + "="):
			return s.get_slice("=", 1)
	return ""


func _build_collision() -> void:
	# Flat zones: the box the audio code classifies (no surface meta).
	ground_floor = StaticBody3D.new()
	ground_floor.name = "GroundFloor"
	ground_floor.add_to_group(&"terrain")
	_add_box(ground_floor, Vector3(0, -1, 0), Vector3(FORT_FLAT_HALF * 2.0, 2.0, FORT_FLAT_HALF * 2.0))
	_add_box(ground_floor, Vector3(0, -1, (LANE_FLAT_Z_MIN + LANE_FLAT_Z_MAX) * 0.5),
			Vector3(LANE_FLAT_HALF_X * 2.0, 2.0, LANE_FLAT_Z_MAX - LANE_FLAT_Z_MIN))
	add_child(ground_floor)

	# Height field, one 65 x 65 shape per 64 m chunk, every square's.
	terrain_body = StaticBody3D.new()
	terrain_body.name = "TerrainBody"
	terrain_body.add_to_group(&"terrain")
	terrain_body.set_meta(&"surface", "grass")
	if _collision.is_empty():
		var col_img := data_image("terrain_collision.res")
		_collision = col_img.get_data().to_float32_array() if col_img else _heights
	var side := CHUNK_SIZE + 1
	for sq: Vector2i in squares():
		var col := _collision if sq == Vector2i.ZERO else _square_collision(_squares[sq])
		var o := square_origin(sq)
		for cj in CHUNK_COUNT:
			for ci in CHUNK_COUNT:
				var data := PackedFloat32Array()
				for r in side:
					var src := (cj * CHUNK_SIZE + r) * GRID_N + ci * CHUNK_SIZE
					data.append_array(col.slice(src, src + side))
				var hm := HeightMapShape3D.new()
				hm.map_width = side
				hm.map_depth = side
				hm.map_data = data
				var cs := CollisionShape3D.new()
				cs.shape = hm
				cs.position = o + _chunk_centre(ci, cj)
				terrain_body.add_child(cs)
	add_child(terrain_body)

	# Surface overlays: dirt paths / brook bed and rock, for footsteps and impacts (each square's about its middle).
	for sq: Vector2i in squares():
		var dir := "" if sq == Vector2i.ZERO else SQUARE_DIR % [sq.x, sq.y]
		for kind in [["GroundDirt", "dirt"], ["GroundStone", "stone"]]:
			var path := data_dir() + dir + "terrain_overlay_%s.res" % kind[1]
			var shape := load(path) as Shape3D if ResourceLoader.exists(path) else null
			if shape == null:
				continue
			var body := StaticBody3D.new()
			body.name = kind[0] if sq == Vector2i.ZERO else "%s_%d_%d" % [kind[0], sq.x, sq.y]
			body.add_to_group(&"terrain")
			body.set_meta(&"surface", kind[1])
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			add_child(body)
			body.position = square_origin(sq)

	# Invisible walls where the ground ends: each square's sides with no square beyond.
	var edge := StaticBody3D.new()
	edge.name = "WorldEdge"
	var span := SQUARE_M + 4.0
	for sq: Vector2i in squares():
		var o := square_origin(sq)
		for s: float in [-1.0, 1.0]:
			if not _squares.has(sq + Vector2i(int(s), 0)):
				_add_box(edge, o + Vector3(s * (EDGE_WALL + 1.0), 60.0, 0.0), Vector3(2.0, 240.0, span))
			if not _squares.has(sq + Vector2i(0, int(s))):
				_add_box(edge, o + Vector3(0.0, 60.0, s * (EDGE_WALL + 1.0)), Vector3(span, 240.0, 2.0))
	add_child(edge)


static func _chunk_centre(ci: int, cj: int) -> Vector3:
	return Vector3(ci * CHUNK_SIZE - GRID_HALF + CHUNK_SIZE * 0.5, 0.0, cj * CHUNK_SIZE - GRID_HALF + CHUNK_SIZE * 0.5)


func _add_box(body: Node3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	body.add_child(cs)


func _build_meshes() -> void:
	material = make_material(settings)
	var meshes: Array[ArrayMesh] = []
	for step: int in LOD_STEPS:
		meshes.append(grid_mesh(step))
	var chunks := Node3D.new()
	chunks.name = "Chunks"
	add_child(chunks)
	for sq: Vector2i in squares():
		_build_square_meshes(sq, meshes, chunks)


## Square `sq`'s 13 x 13 chunks (the fort's named C<i>_<j>_L<l>, another's S<x>_<y>_C<i>_<j>_L<l>).
func _build_square_meshes(sq: Vector2i, meshes: Array[ArrayMesh], chunks: Node3D) -> void:
	var fort := sq == Vector2i.ZERO
	var dir := "" if fort else SQUARE_DIR % [sq.x, sq.y]
	var mat := material if fort else make_material(settings, sq)
	var bounds := data_image(dir + "terrain_bounds.res")
	var o := square_origin(sq)
	var s := settings.terrain_lod_scale
	for cj in CHUNK_COUNT:
		for ci in CHUNK_COUNT:
			var lo := -2.0
			var hi := 40.0
			if bounds:
				var c := bounds.get_pixel(ci, cj)
				lo = c.r
				hi = c.g
			var aabb := AABB(Vector3(-CHUNK_SIZE * 0.5, lo - SKIRT_DEPTH - 0.1, -CHUNK_SIZE * 0.5),
					Vector3(CHUNK_SIZE, hi - lo + SKIRT_DEPTH + 0.2, CHUNK_SIZE))
			for l in LOD_STEPS.size():
				var mi := MeshInstance3D.new()
				mi.name = ("C%d_%d_L%d" % [ci, cj, l]) if fort else ("S%d_%d_C%d_%d_L%d" % [sq.x, sq.y, ci, cj, l])
				mi.mesh = meshes[l]
				mi.material_override = mat
				mi.custom_aabb = aabb
				mi.position = o + _chunk_centre(ci, cj)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if NEAR_SHADOWS or l >= 2 \
						else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				# only the fine LODs in the global illumination (SDFGI takes every LOD whatever its distance: the coarse
				# ones' 8 m and 4 m grids bridge the river's channel and darken its bed in blocky wedges)
				mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC if l < 2 else GeometryInstance3D.GI_MODE_DISABLED
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				if l > 0:
					mi.visibility_range_begin = LOD_DISTANCES[l - 1] * s
					mi.visibility_range_begin_margin = LOD_MARGIN
				if l < LOD_DISTANCES.size():
					mi.visibility_range_end = LOD_DISTANCES[l] * s
					mi.visibility_range_end_margin = LOD_MARGIN
				chunks.add_child(mi)


## The terrain ShaderMaterial with every baked texture bound (also used by the grass for its
## ground lookups through `textures`); for another square `sq`, its own (square_textures, square_materials: the
## fort's detail map and macro noise shared, the detail rectangle never met).
func make_material(ws: WorldSettings, sq := Vector2i.ZERO) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH)
	var fort := sq == Vector2i.ZERO
	if fort or textures.is_empty():
		textures["height_map"] = ImageTexture.create_from_image(data_image("terrain_height.res"))
		textures["splat0"] = ImageTexture.create_from_image(data_image("terrain_splat0.res"))
		textures["splat1"] = ImageTexture.create_from_image(data_image("terrain_splat1.res"))
		textures["terrain_normal"] = ImageTexture.create_from_image(data_image("terrain_normal.res"))
		textures["core_map"] = ImageTexture.create_from_image(data_image("terrain_core.res"))
		textures["macro_noise"] = ImageTexture.create_from_image(data_image("terrain_macro.res"))
	var tex := textures
	if not fort:
		var dir := SQUARE_DIR % [sq.x, sq.y]
		tex = {"core_map": textures.core_map, "macro_noise": textures.macro_noise}
		for k: String in ["height_map", "splat0", "splat1", "terrain_normal"]:
			var file := {"height_map": "terrain_height.res", "splat0": "terrain_splat0.res", "splat1": "terrain_splat1.res",
					"terrain_normal": "terrain_normal.res"}[k] as String
			tex[k] = ImageTexture.create_from_image(data_image(dir + file))
		square_textures[sq] = tex
		square_materials[sq] = m
	for k: String in tex:
		m.set_shader_parameter(k, tex[k])
	var o := square_origin(sq)
	m.set_shader_parameter("square_origin", Vector2(o.x, o.z))
	if ResourceLoader.exists(ALBEDO_ARRAY_PATH):
		m.set_shader_parameter("albedo_array", load(ALBEDO_ARRAY_PATH))
	if ResourceLoader.exists(NRM_ARRAY_PATH):
		m.set_shader_parameter("nrm_array", load(NRM_ARRAY_PATH))
	m.set_shader_parameter("grid_half", float(GRID_HALF))
	m.set_shader_parameter("grid_size", float(GRID_N))
	m.set_shader_parameter("core_rect", Vector4(CORE_X0, CORE_Z0, CORE_W, CORE_D) if fort else NO_CORE)
	m.set_shader_parameter("skirt_depth", SKIRT_DEPTH)
	m.set_shader_parameter("detail", ws.terrain_detail)
	m.set_shader_parameter("canopy_darkening", 0.0 if ws.sdfgi else 0.25)
	return m


## Flat grid of 64 x 64 m with `step` m spacing, centred on the origin, plus a skirt ring
## (vertices at y = -1, which the shader drops SKIRT_DEPTH below the ground). Cells are split
## along the (x+1, z)-(x, z+1) diagonal like the height-field collision.
static func grid_mesh(step: int) -> ArrayMesh:
	var n := CHUNK_SIZE / step
	var h := CHUNK_SIZE * 0.5
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in n + 1:
		for i in n + 1:
			verts.append(Vector3(-h + i * step, 0.0, -h + j * step))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var c := a + n + 1
			idx.append_array([a, a + 1, c, a + 1, c + 1, c])
	# Skirts: [edge vertex indices in order, outward direction].
	var edges := []
	var north := PackedInt32Array()
	var south := PackedInt32Array()
	var west := PackedInt32Array()
	var east := PackedInt32Array()
	for k in n + 1:
		north.append(k)
		south.append(n * (n + 1) + k)
		west.append(k * (n + 1))
		east.append(k * (n + 1) + n)
	edges = [[north, Vector3.FORWARD], [south, Vector3.BACK], [west, Vector3.LEFT], [east, Vector3.RIGHT]]
	for e: Array in edges:
		var top: PackedInt32Array = e[0]
		var out: Vector3 = e[1]
		var base := verts.size()
		for t in top:
			verts.append(Vector3(verts[t].x, -1.0, verts[t].z))
		for k in n:
			var t1 := top[k]
			var t2 := top[k + 1]
			var b1 := base + k
			var b2 := base + k + 1
			# Godot front faces: (B - A) x (C - A) points away from the viewer.
			var p1 := verts[t1]
			var p2 := verts[t2]
			var p3 := verts[b1] + Vector3(0, 0.0, 0)
			var cr := (p2 - p1).cross(p3 - p1)
			if cr.dot(out) < 0.0:
				idx.append_array([t1, t2, b1, t2, b2, b1])
			else:
				idx.append_array([t2, t1, b1, t2, b1, b2])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _mat(key: String, color: Color, roughness := 0.9) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


## The original flat ground (debug A/B and fallback when the baked data is missing).
func _build_placeholder() -> void:
	var size := 800.0
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	m.mesh = plane
	var grass_mat := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.3, 0.36, 0.17), Color(0.42, 0.45, 0.22)])
	tex.color_ramp = ramp
	grass_mat.albedo_texture = tex
	grass_mat.uv1_scale = Vector3(60, 60, 1)
	grass_mat.roughness = 1.0
	m.material_override = grass_mat
	add_child(m)
	var dirt := _mat("dirt", Color(0.45, 0.37, 0.26), 1.0)
	if not SurvivalBridge.bare_ahead():        # (no fort yard and no firing lane in a start with nothing)
		_flat(Vector3(0, 0.01, 0), Vector2(FORT_HALF * 2, FORT_HALF * 2), dirt)
		_flat(Vector3(0, 0.01, FIRING_LINE_Z - 70), Vector2(10, 140), dirt)
	var body := StaticBody3D.new()
	body.name = "GroundFloor"
	body.add_to_group(&"terrain")
	_add_box(body, Vector3(0, -1, 0), Vector3(size, 2, size))
	add_child(body)


func _flat(pos: Vector3, size: Vector2, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = size
	m.mesh = p
	m.material_override = mat
	m.position = pos
	add_child(m)
