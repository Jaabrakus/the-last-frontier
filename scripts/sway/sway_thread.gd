class_name SwayThread
extends MeshInstance3D
## The faint thread of light from the casting hand to the locked target (SwayCaster; docs/main_story.md 11.4: from half the
## lock, "visible to everyone"): one ribbon in the world, SEGMENTS long, turned to face the camera, in the art's colour,
## additive and unshaded, a slight waver along it that settles as the lock fills. `strength` (0..1) is its brightness
## (0: hidden); set_line() each frame. Cheap: an ImmediateMesh of 2 x (SEGMENTS + 1) vertices, no shadow, no particles.

const SEGMENTS := 14
const WIDTH := 0.014
const WAVER_M := 0.035

var from := Vector3.ZERO
var to := Vector3.ZERO
var strength := 0.0
var color := Color(0.74, 0.88, 1.0)
var _im: ImmediateMesh
var _mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_mat.no_depth_test = false
	material_override = _mat
	visible = false


func set_line(a: Vector3, b: Vector3, s: float) -> void:
	from = a
	to = b
	strength = s
	visible = strength > 0.01 and a.distance_to(b) > 0.2


func _process(dt: float) -> void:
	_t += dt
	if not visible or _im == null:
		return
	global_transform = Transform3D.IDENTITY
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam != null else from + Vector3.UP
	var line := to - from
	var length_m := line.length()
	var dir := line / length_m
	var side0 := dir.cross(Vector3.UP)
	if side0.length_squared() < 1e-6:
		side0 = dir.cross(Vector3.RIGHT)
	side0 = side0.normalized()
	var up0 := side0.cross(dir).normalized()
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var waver := WAVER_M * (1.0 - clampf(strength / 0.75, 0.0, 1.0) * 0.7)
	for i in SEGMENTS + 1:
		var u := float(i) / SEGMENTS
		var env := sin(u * PI)                                  # (the ends stay on the hand and the target)
		var p := from + line * u + (side0 * sin(u * 9.0 + _t * 5.0) + up0 * sin(u * 7.0 - _t * 4.0) * 0.6) * waver * env
		var face := (eye - p).normalized()
		var w := dir.cross(face)
		w = w.normalized() * WIDTH * (0.6 + 0.4 * env) if w.length_squared() > 1e-8 else side0 * WIDTH
		var a := strength * (0.55 + 0.45 * env) * (0.85 + 0.15 * sin(_t * 23.0 + u * 11.0))
		var col := Color(color.r, color.g, color.b, a)
		_im.surface_set_color(col)
		_im.surface_add_vertex(p - w)
		_im.surface_set_color(col)
		_im.surface_add_vertex(p + w)
	_im.surface_end()
