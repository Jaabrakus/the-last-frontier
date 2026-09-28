class_name GatherFx
## Chips and dust for the gathering strokes (set up as CPUParticles3D, played as GPU particles by Fx._emit; one-shot,
## freed when done; nothing headless):
##
##   GatherFx.wood_chips(parent, point, normal)     pale chips flying out of an axe cut, a little bark dust
##   GatherFx.stone_chips(parent, point, normal)    grey flakes and dust from a mattock blow
##   GatherFx.fall_dust(parent, point, width)       a low cloud of dust and needles where a tree comes down

static var _chip_mat: StandardMaterial3D
static var _flake_mat: StandardMaterial3D
static var _dust_mat: StandardMaterial3D


static func wood_chips(parent: Node, point: Vector3, normal: Vector3, amount := 14) -> void:
	if not _visuals(parent):
		return
	var p := _chips(parent, point + normal * 0.03, amount, _chip(), Vector2(0.018, 0.04))
	p.direction = (normal + Vector3.UP * 0.5).normalized()
	p.spread = 40.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 4.2
	p.color_ramp = Fx._ramp([Color(0.78, 0.66, 0.47), Color(0.7, 0.58, 0.41), Color(0.6, 0.49, 0.34)])
	Fx._emit(p, false)
	_dust(parent, point + normal * 0.05, normal, 6, Vector2(0.06, 0.16), 0.9, Color(0.45, 0.39, 0.31, 0.3))


static func stone_chips(parent: Node, point: Vector3, normal: Vector3, amount := 12) -> void:
	if not _visuals(parent):
		return
	var p := _chips(parent, point + normal * 0.03, amount, _flake(), Vector2(0.012, 0.03))
	p.direction = (normal + Vector3.UP * 0.7).normalized()
	p.spread = 55.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.6
	p.color_ramp = Fx._ramp([Color(0.5, 0.49, 0.47), Color(0.4, 0.39, 0.37)])
	Fx._emit(p, false)
	_dust(parent, point + normal * 0.05, normal, 8, Vector2(0.07, 0.2), 1.2, Color(0.52, 0.51, 0.48, 0.32))


static func fall_dust(parent: Node, point: Vector3, width: float) -> void:
	if not _visuals(parent):
		return
	var d := _dust(parent, point + Vector3.UP * 0.2, Vector3.UP, 26, Vector2(0.3, 0.7), 2.0, Color(0.42, 0.38, 0.31, 0.22), false)
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	d.emission_box_extents = Vector3(width, 0.2, width)
	d.spread = 80.0
	Fx._emit(d, false)


## Dust: soft, dim, unshaded puffs (lit billboards read as dark balls against the sun).
## `emit` false: the caller changes it and emits it (Fx._emit plays it as GPU particles and frees this one).
static func _dust(parent: Node, pos: Vector3, dir: Vector3, amount: int, size: Vector2, life: float, col: Color,
		emit := true) -> CPUParticles3D:
	if _dust_mat == null:
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dust_mat.vertex_color_use_as_albedo = true
		_dust_mat.albedo_texture = Fx._soft_dot()
		_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_mat.disable_receive_shadows = true
	var d := CPUParticles3D.new()
	d.amount = amount
	d.lifetime = life
	d.one_shot = true
	d.explosiveness = 0.85
	d.randomness = 0.5
	d.local_coords = false
	# the particle scale is not applied to BILLBOARD_PARTICLES quads here (measured 2026-09-26: 0.1 scale
	# drew 1 m puffs, fx.gd's dust_puff too): the quad itself has the size, the scale only varies it
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size.y
	quad.material = _dust_mat
	d.mesh = quad
	d.direction = dir
	d.spread = 50.0
	d.initial_velocity_min = 0.2
	d.initial_velocity_max = 0.9
	d.gravity = Vector3(0, -0.4, 0)
	d.damping_min = 0.5
	d.damping_max = 1.0
	d.scale_amount_min = size.x / size.y
	d.scale_amount_max = 1.0
	d.color_ramp = Fx._ramp([col, Color(col.r, col.g, col.b, 0.0)])
	parent.add_child(d)
	d.global_position = pos
	if emit:
		Fx._emit(d, false)
	return d


static func _visuals(parent: Node) -> bool:
	return parent != null and parent.is_inside_tree() and DisplayServer.get_name() != "headless"


static func _chips(parent: Node, pos: Vector3, amount: int, mat: Material, size: Vector2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.92
	p.randomness = 0.5
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size.y   # (see _dust: the quad has the size)
	quad.material = mat
	p.mesh = quad
	p.gravity = Vector3(0, -9.8, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = size.x / size.y
	p.scale_amount_max = 1.0
	parent.add_child(p)
	p.global_position = pos
	return p


static func _chip() -> StandardMaterial3D:
	if _chip_mat == null:
		_chip_mat = StandardMaterial3D.new()
		_chip_mat.vertex_color_use_as_albedo = true
		_chip_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_chip_mat.roughness = 0.9
		_chip_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return _chip_mat


static func _flake() -> StandardMaterial3D:
	if _flake_mat == null:
		_flake_mat = _chip().duplicate()
		_flake_mat.roughness = 0.7
	return _flake_mat
