
extends Node3D
## Ground of the Frontier level: height field, splat-mapped material, grass and the ground
## colliders (look-dev spec, section 5). Owner: package B.
##
## Integration API (frozen; see the spec, section 11):
##   var t := FrontierTerrain.new(); t.name = "Terrain"; add_child(t)
##   t.build(settings)             -- meshes, material, grass, collision. Called right after
##                                    EnvironmentRig.build(), before structures and vegetation.
##   FrontierTerrain.height_at(x, z)   rendered ground height (m); exactly 0.0 in the flat zones
##   FrontierTerrain.normal_at(x, z)   ground normal
##   FrontierTerrain.flat_blend(x, z)  0 inside the flat zones .. 1 at BLEND_WIDTH outside them
##   FrontierTerrain.in_flat_zone(x, z)
##   FrontierTerrain.ground_layers(x, z)  splat weights, PackedFloat32Array indexed by LAYER_*
##                                    (sums to 1); vegetation uses them to pick what grows where
##   FrontierTerrain.forest_density(x, z) 0 open ground (clearing, meadow, range lane) .. 1 closed
##                                    forest; the forest edge is defined here, trees follow it
## All statics are deterministic and cheap (vegetation calls them tens of thousands of times).
##
## Collision contract (audio: Sfx.surface_of and Footsteps): the flat zones keep the
## "GroundFloor" box (top at y = 0, no "surface" meta, so the fort floor and range lane still
## read as dirt and the rest of the flat ground as grass); ground outside them is a separate
## body in group "terrain" with meta surface = "grass" whose collision lies 5 cm below the box
## wherever the ground is flat, so the box always wins there.
##
## SKELETON: build() still makes the original flat 800 m plane with the two dirt patches, and
## height_at() is 0 everywhere. Package B replaces both.

## Flat zones (gameplay layout, fixed): the fort and its clearing, and the range lane.
const FORT_FLAT_HALF := 26.0
const LANE_FLAT_HALF_X := 14.0
const LANE_FLAT_Z_MIN := -175.0
const LANE_FLAT_Z_MAX := -12.0
## Width (m) over which the terrain blends from the flat zones into the hills.
const BLEND_WIDTH := 24.0
## World extent of the ground (square, centred on the fort).
const WORLD_HALF := 400.0

enum { LAYER_GRASS, LAYER_DRY_GRASS, LAYER_DIRT, LAYER_MUD, LAYER_FOREST_FLOOR, LAYER_ROCK, LAYER_COUNT }

const FORT_HALF := 16.0
const FIRING_LINE_Z := -20.0

var settings: WorldSettings
var _mats := {}


## Distance (m) from (x, z) to the nearest flat zone (0 inside one).
static func flat_distance(x: float, z: float) -> float:
	var fx := maxf(absf(x) - FORT_FLAT_HALF, 0.0)
	var fz := maxf(absf(z) - FORT_FLAT_HALF, 0.0)
	var d_fort := Vector2(fx, fz).length()
	var lx := maxf(absf(x) - LANE_FLAT_HALF_X, 0.0)
	var lz := maxf(maxf(LANE_FLAT_Z_MIN - z, z - LANE_FLAT_Z_MAX), 0.0)
	var d_lane := Vector2(lx, lz).length()
	return minf(d_fort, d_lane)


static func in_flat_zone(x: float, z: float) -> bool:
	return flat_distance(x, z) <= 0.0


## 0 inside the flat zones, smoothstep up to 1 at BLEND_WIDTH outside them.
static func flat_blend(x: float, z: float) -> float:
	return smoothstep(0.0, BLEND_WIDTH, flat_distance(x, z))


## Rendered ground height (m). Exactly 0.0 in the flat zones.
static func height_at(_x: float, _z: float) -> float:
	return 0.0


static func normal_at(x: float, z: float) -> Vector3:
	var e := 0.5
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## Splat weights at (x, z), indexed by LAYER_*; they sum to 1.
static func ground_layers(x: float, z: float) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(LAYER_COUNT)
	w[LAYER_DIRT if Sfx.is_dirt(Vector3(x, 0.0, z)) else LAYER_GRASS] = 1.0
	return w


## 0 = open (fort clearing, range lane, meadows) .. 1 = closed forest. The placeholder is the
## original forest rule: everything outside the clearing and the lane.
static func forest_density(x: float, z: float) -> float:
	if absf(x) < FORT_HALF + 10.0 and absf(z) < FORT_HALF + 10.0:
		return 0.0
	if absf(x) < 14.0 and z < FIRING_LINE_Z + 4.0 and z > FIRING_LINE_Z - 150.0:
		return 0.0
	return 1.0


func build(world_settings: WorldSettings) -> void:
	settings = world_settings if world_settings else WorldSettings.preset(WorldSettings.DEFAULT_QUALITY)
	_build_placeholder()


func _mat(key: String, color: Color, roughness := 0.9) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


## The original ground from frontier_level.gd, unchanged.
func _build_placeholder() -> void:
	var size := 800.0
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	m.mesh = plane
	var grass := StandardMaterial3D.new()
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
	grass.albedo_texture = tex
	grass.uv1_scale = Vector3(60, 60, 1)
	grass.roughness = 1.0
	m.material_override = grass
	add_child(m)

	# Packed dirt inside the fort and along the range lane.
	var dirt := _mat("dirt", Color(0.45, 0.37, 0.26), 1.0)
	_flat(Vector3(0, 0.01, 0), Vector2(FORT_HALF * 2, FORT_HALF * 2), dirt)
	_flat(Vector3(0, 0.01, FIRING_LINE_Z - 70), Vector2(10, 140), dirt)

	var body := StaticBody3D.new()
	body.name = "GroundFloor"
	body.add_to_group(&"terrain")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2, size)
	cs.shape = box
	cs.position.y = -1
	body.add_child(cs)
	add_child(body)


func _flat(pos: Vector3, size: Vector2, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = size
	m.mesh = p
	m.material_override = mat
	m.position = pos
	add_child(m)
