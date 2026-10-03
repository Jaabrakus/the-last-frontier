class_name FormCrackle
extends MeshInstance3D
## The blue-white crackle of a Form cast (FormCast): thin jagged arcs running along the ground from the pressed palms to the
## circle and flickering round its rim, re-drawn every few hundredths of a second, and a few sparks jumping off the rim (one
## GPU particle emitter on a ring). `level` (0..1) how much of it shows; burst() a moment of it all at full (the release).
## Cheap: an ImmediateMesh of a few hundred vertices, additive and unshaded, no shadow, no light of its own.

const WIDTH := 0.006
const REDRAW_S := 0.05
const BURST_S := 0.45

var color := Color(0.6, 0.84, 1.0)
var level := 0.0
## The palms (world) and the circle (its centre, its up, its radius).
var from := Vector3.ZERO
var center := Vector3.ZERO
var up := Vector3.UP
var radius := 1.0

var _im: ImmediateMesh
var _mat: StandardMaterial3D
var _t := 0.0
var _redraw := 0.0
var _burst := 0.0
var _rng := RandomNumberGenerator.new()
var _sparks: GPUParticles3D


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = FormCircle.FX_LAYER                   # (as the circle: no ground decal darkens it)
	_im = ImmediateMesh.new()
	mesh = _im
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_mat.disable_fog = true
	material_override = _mat
	_rng.randomize()
	_sparks = _make_sparks()
	_sparks.layers = FormCircle.FX_LAYER
	add_child(_sparks)


func burst() -> void:
	_burst = BURST_S


func _make_sparks() -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.name = "Sparks"
	g.amount = 28
	g.lifetime = 0.28
	g.explosiveness = 0.0
	g.randomness = 0.6
	g.local_coords = false
	g.emitting = false
	g.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 4, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_height = 0.02
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	g.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.035
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.6, 1.8, 2.0)
	m.albedo_texture = Fx._soft_dot()
	quad.material = m
	g.draw_pass_1 = quad
	return g


func _process(dt: float) -> void:
	_t += dt
	_burst = maxf(_burst - dt, 0.0)
	var lv := clampf(maxf(level, _burst / BURST_S), 0.0, 1.0)
	if _sparks != null:
		_sparks.emitting = lv > 0.15
		var pm := _sparks.process_material as ParticleProcessMaterial
		pm.emission_ring_radius = radius * 0.95
		pm.emission_ring_inner_radius = radius * 0.85
		pm.emission_ring_axis = up
		_sparks.global_position = center
		_sparks.amount_ratio = clampf(lv, 0.05, 1.0)
	_redraw -= dt
	if _redraw > 0.0:
		return
	_redraw = REDRAW_S
	_im.clear_surfaces()
	if lv <= 0.02:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam != null else center + Vector3.UP * 3.0
	global_transform = Transform3D.IDENTITY
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# from the palms to the circle (two arcs), and a few round its rim
	var n_line := 1 + int(lv * 1.5)
	for i in n_line:
		var a := from + up * 0.02
		var b := center + (Vector3(_rng.randf() - 0.5, 0.0, _rng.randf() - 0.5)).slide(up) * radius * 0.6
		_arc(a, b, 0.09 * (0.6 + lv), 9, lv, eye)
	var n_rim := 1 + int(lv * 3.0)
	var bx := FormCircle.basis_on(up)
	for i in n_rim:
		var a0 := _rng.randf() * TAU
		var a1 := a0 + _rng.randf_range(0.4, 1.2)
		var pa := center + bx * (Vector3(cos(a0), 0.0, sin(a0)) * radius * 0.93)
		var pb := center + bx * (Vector3(cos(a1), 0.0, sin(a1)) * radius * 0.93)
		_arc(pa, pb, 0.05, 6, lv * 0.8, eye)
	_im.surface_end()


## A jagged arc from `a` to `b`: `n` pieces jolted off the straight line by up to `jag` (along the surface and a little up).
func _arc(a: Vector3, b: Vector3, jag: float, n: int, lv: float, eye: Vector3) -> void:
	var pts: Array[Vector3] = [a]
	var side := (b - a).cross(up)
	side = side.normalized() if side.length_squared() > 1e-8 else Vector3.RIGHT
	for i in range(1, n):
		var u := float(i) / n
		var env := sin(u * PI)
		pts.append(a.lerp(b, u) + side * _rng.randf_range(-jag, jag) * env + up * _rng.randf_range(0.0, jag * 0.6) * env)
	pts.append(b)
	var a_col := Color(color.r, color.g, color.b, clampf(lv * _rng.randf_range(0.55, 1.0), 0.0, 1.0))
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var d := p1 - p0
		var face := (eye - p0).normalized()
		var w := d.cross(face)
		w = w.normalized() * WIDTH if w.length_squared() > 1e-10 else side * WIDTH
		var c0 := a_col.lerp(Color(1, 1, 1, a_col.a), 0.25)
		for v in [p0 - w, p0 + w, p1 + w, p0 - w, p1 + w, p1 - w]:
			_im.surface_set_color(c0)
			_im.surface_add_vertex(v)
