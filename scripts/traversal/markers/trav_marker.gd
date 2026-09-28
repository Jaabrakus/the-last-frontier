@tool
class_name TravMarker
extends Node3D
## Base of the traversal authoring markers (design 14.3). A marker describes a feature that
## geometry alone cannot (a ladder, a narrow ledge, a beam line, a perch, a tunnel volume).
## LedgeBaker reads marker_info() (world space). At runtime each marker adds an Area3D on
## layer 9 ("trav_markers", collide_with_areas only) so probes find it; projectiles, aim rays and
## footstep rays never see it. In the editor a line gizmo shows the feature.

const MARKER_LAYER := 1 << 8
@export var debug_draw := true
@export var color := Color(1.0, 0.75, 0.1)
var _mesh: MeshInstance3D


func _ready() -> void:
	if not Engine.is_editor_hint():
		_add_area()
	if debug_draw:
		redraw()


func marker_info() -> Dictionary:
	return {}


## Local line segments for the gizmo: [[a, b], ...].
func gizmo_lines() -> Array:
	return []


func _area_shape() -> Array:
	return []   # [Shape3D, Transform3D]


func _add_area() -> void:
	var s := _area_shape()
	if s.is_empty():
		return
	var area := Area3D.new()
	area.name = "MarkerArea"
	area.collision_layer = MARKER_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var cs := CollisionShape3D.new()
	cs.shape = s[0]
	cs.transform = s[1]
	area.add_child(cs)
	add_child(area)


func redraw() -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Gizmo"
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mesh)
	var im := ImmediateMesh.new()
	var lines := gizmo_lines()
	if not lines.is_empty():
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for seg: Array in lines:
			im.surface_add_vertex(seg[0])
			im.surface_add_vertex(seg[1])
		im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true
	_mesh.mesh = im
	_mesh.material_override = mat
	_mesh.visible = debug_draw
