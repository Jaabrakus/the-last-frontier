
extends Node3D
## Trees, saplings, undergrowth, fallen wood and rocks around the fort (look-dev spec,
## section 7). Owner: package C.
##
## Integration API (frozen; see the spec, section 11):
##   var v := FrontierVegetation.new(); v.name = "Vegetation"; add_child(v)
##   v.build(settings, rng)        -- called after the terrain and the structures; places
##                                    everything on FrontierTerrain.height_at() and never in the
##                                    fort clearing, the range lane or the dummies' sun corridor.
##                                    `rng` is the level's generator (seed 1776) so the forest
##                                    layout is reproducible.
## Collision / audio contract: every tree trunk has a CylinderShape3D or CapsuleShape3D
## collider in a StaticBody3D in group "trees" (reads as wood); rocks and boulders are
## StaticBody3D in group "rocks" with meta surface = "stone"; stumps and logs are wood.
## Grass-like clutter, ferns, shrubs and saplings under 1.5 m have no collider.
##
## SKELETON: build() still makes the original cone pines and sphere rocks. Package C replaces it.

const FORT_HALF := 16.0
const FIRING_LINE_Z := -20.0

var settings: WorldSettings
var rng: RandomNumberGenerator
var _mats := {}


func build(world_settings: WorldSettings, level_rng: RandomNumberGenerator) -> void:
	settings = world_settings if world_settings else WorldSettings.preset(WorldSettings.DEFAULT_QUALITY)
	rng = level_rng if level_rng else RandomNumberGenerator.new()
	_forest()
	_rocks()


func _mat(key: String, color: Color, roughness := 0.9) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


# --- The original forest and rocks from frontier_level.gd, unchanged -----------------------

func _forest() -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var body := StaticBody3D.new()
	body.name = "TreeTrunks"
	body.add_to_group(&"trees")
	add_child(body)
	var placed := 0
	var tries := 0
	while placed < 380 and tries < 5000:
		tries += 1
		var p := Vector3(rng.randf_range(-220, 220), 0, rng.randf_range(-260, 180))
		if absf(p.x) < FORT_HALF + 10 and absf(p.z) < FORT_HALF + 10:
			continue                                            # Clearing around the fort.
		if absf(p.x) < 14 and p.z < FIRING_LINE_Z + 4 and p.z > FIRING_LINE_Z - 150:
			continue                                            # Range lane.
		var h := rng.randf_range(9.0, 17.0)
		var yaw := rng.randf() * TAU
		trunks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(h / 12.0, h / 12.0, h / 12.0)), p + Vector3(0, h * 0.5, 0)))
		crowns.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(h / 12.0, h / 12.0, h / 12.0)), p + Vector3(0, h * 0.62, 0)))
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.3 * h / 12.0
		shape.height = h
		cs.shape = shape
		cs.position = p + Vector3(0, h * 0.5, 0)
		body.add_child(cs)
		placed += 1

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.32
	trunk.height = 12.0
	trunk.radial_segments = 6
	trunk.material = _mat("bark", Color(0.3, 0.22, 0.15))
	_multimesh(trunk, trunks)

	var crown := CylinderMesh.new()      # A cone: pine silhouette.
	crown.top_radius = 0.0
	crown.bottom_radius = 2.6
	crown.height = 9.5
	crown.radial_segments = 8
	crown.material = _mat("needles", Color(0.16, 0.27, 0.15))
	_multimesh(crown, crowns)


func _multimesh(mesh: Mesh, xforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _rocks() -> void:
	var stone := _mat("rock", Color(0.46, 0.45, 0.42))
	for i in 40:
		var p := Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-160, 100))
		if absf(p.x) < FORT_HALF + 4 and absf(p.z) < FORT_HALF + 4:
			continue
		if absf(p.x) < 8 and p.z < FIRING_LINE_Z:
			continue
		var s := rng.randf_range(0.4, 1.6)
		var body := StaticBody3D.new()
		body.add_to_group(&"rocks")
		var m := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = s
		sphere.height = s * 1.3
		sphere.radial_segments = 7
		sphere.rings = 4
		m.mesh = sphere
		m.material_override = stone
		body.add_child(m)
		var cs := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = s * 0.8
		cs.shape = shape
		body.add_child(cs)
		body.position = p + Vector3(0, s * 0.3, 0)
		body.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		add_child(body)
