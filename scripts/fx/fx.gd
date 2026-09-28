class_name Fx
## One-shot visual effects built from CPUParticles3D. Each effect frees itself.
## Black powder weapons throw a big, slow cloud of white smoke that hangs in
## the air, which is half the feel of a musket.


static func muzzle_blast(parent: Node, xform: Transform3D, scale := 1.0) -> void:
	var dir := -xform.basis.z
	_flash_light(parent, xform.origin + dir * 0.1, 3.0 * scale, 0.07)
	# Fast bright core.
	var fire := _particles(parent, xform.origin, 18, 0.12, 0.25)
	fire.direction = dir
	fire.spread = 12.0
	fire.initial_velocity_min = 6.0 * scale
	fire.initial_velocity_max = 12.0 * scale
	fire.damping_min = 30.0
	fire.damping_max = 40.0
	fire.scale_amount_min = 0.08 * scale
	fire.scale_amount_max = 0.16 * scale
	fire.color_ramp = _ramp([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.6), Color(0.3, 0.3, 0.3, 0.0)])
	_emit(fire, true)
	# Slow white smoke that lingers.
	var smoke := _particles(parent, xform.origin + dir * 0.2, int(28 * scale), 0.25, 5.0)
	smoke.direction = dir
	smoke.spread = 25.0
	smoke.initial_velocity_min = 2.0 * scale
	smoke.initial_velocity_max = 6.0 * scale
	smoke.damping_min = 3.0
	smoke.damping_max = 5.0
	smoke.gravity = Vector3(0.15, 0.25, 0.0)
	smoke.scale_amount_min = 0.35 * scale
	smoke.scale_amount_max = 0.8 * scale
	smoke.scale_amount_curve = _curve(0.4, 1.0, 2.2)
	smoke.color_ramp = _ramp([Color(0.92, 0.92, 0.9, 0.0), Color(0.9, 0.9, 0.88, 0.55), Color(0.85, 0.85, 0.83, 0.0)])
	_emit(smoke, false)


## The flash in the pan of a flintlock, a moment before the main charge fires.
static func pan_flash(parent: Node, pos: Vector3) -> void:
	_flash_light(parent, pos, 1.2, 0.05)
	var p := _particles(parent, pos, 10, 0.1, 1.2)
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.scale_amount_curve = _curve(0.5, 1.0, 1.8)
	p.color_ramp = _ramp([Color(1.0, 0.85, 0.4, 1.0), Color(0.8, 0.8, 0.78, 0.5), Color(0.8, 0.8, 0.8, 0.0)])
	_emit(p, false)


static func dust_puff(parent: Node, pos: Vector3, normal: Vector3) -> void:
	var p := _particles(parent, pos + normal * 0.03, 10, 0.1, 0.9)
	p.direction = normal
	p.spread = 35.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	p.scale_amount_curve = _curve(0.6, 1.0, 1.4)
	p.color_ramp = _ramp([Color(0.55, 0.47, 0.38, 0.8), Color(0.5, 0.45, 0.38, 0.0)])
	_emit(p, false)


## Frames the warm-up effects play for.
const WARM_FRAMES := 4

## True while warm_up() plays the effects: their colours are transparent and the flash lights are left out.
static var _warming := false
static var _warm_nodes: Array[Node] = []


## Compiles the effects' particle shaders while the level loads: GPU particles compile a shader for each kind of
## effect on its first use (measured 2026-09-27: the first musket shot took a 291 ms frame). Every effect (the
## muzzle blast, the pan flash, the dust of a hit, and GatherFx's chips and dust) is played once in front of `cam`,
## fully transparent and without its light, for WARM_FRAMES frames, then freed (as PlayerTorch._warm_up does for
## the torch).
static func warm_up(cam: Camera3D) -> void:
	if cam == null or not cam.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var tree := cam.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene else cam.get_parent()
	var at := cam.global_transform * Vector3(0.0, 0.0, -2.0)
	_warming = true
	_warm_nodes.clear()
	muzzle_blast(parent, Transform3D(cam.global_basis, at))
	pan_flash(parent, at)
	dust_puff(parent, at, Vector3.UP)
	GatherFx.wood_chips(parent, at, Vector3.UP)
	GatherFx.stone_chips(parent, at, Vector3.UP)
	GatherFx.fall_dust(parent, at, 1.0)
	BloodFx.warm(parent, at)
	_warming = false
	var nodes := _warm_nodes.duplicate()
	_warm_nodes.clear()
	for i in WARM_FRAMES:
		await tree.process_frame
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()


static func _particles(parent: Node, pos: Vector3, amount: int, explosiveness_time: float, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = clampf(1.0 - explosiveness_time, 0.0, 1.0)
	p.randomness = 0.5
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	mat.disable_receive_shadows = true
	quad.material = mat
	p.mesh = quad
	parent.add_child(p)
	p.global_position = pos
	return p


## Plays the effect as GPU particles: the same settings (GPUParticles3D.convert_from_particles). A CPUParticles3D
## draws the slots it has not emitted yet as black quads at the emitter (Godot 4.7), so a musket's smoke, spread
## over its first 1.25 s, showed a black ball at the lock for that long (user 2026-09-27: "fix the black disc").
static func _emit(p: CPUParticles3D, _fast: bool) -> void:
	if _warming and p.color_ramp:
		var clear := p.color_ramp.duplicate() as Gradient
		for i in clear.get_point_count():
			var c := clear.get_color(i)
			clear.set_color(i, Color(c.r, c.g, c.b, 0.0))
		p.color_ramp = clear
	var g := GPUParticles3D.new()
	g.convert_from_particles(p)
	g.visibility_aabb = AABB(Vector3(-8.0, -4.0, -8.0), Vector3(16.0, 14.0, 16.0))
	var parent := p.get_parent()
	var xf := p.global_transform
	parent.remove_child(p)
	p.free()
	parent.add_child(g)
	g.global_transform = xf
	g.emitting = true
	g.finished.connect(g.queue_free)
	if _warming:
		_warm_nodes.append(g)


static func _flash_light(parent: Node, pos: Vector3, energy: float, time: float) -> void:
	if _warming:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = energy
	l.omni_range = 6.0
	parent.add_child(l)
	l.global_position = pos
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, time)
	t.tween_callback(l.queue_free)


static func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / maxf(colors.size() - 1, 1))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	return g


static func _curve(a: float, b: float, c: float) -> Curve:
	var cv := Curve.new()
	cv.max_value = maxf(c, b) + 0.1
	cv.add_point(Vector2(0, a))
	cv.add_point(Vector2(0.3, b))
	cv.add_point(Vector2(1, c))
	return cv


static var _dot: Texture2D

static func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_dot = t
	return _dot
