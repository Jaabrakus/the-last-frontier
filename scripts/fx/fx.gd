class_name Fx
## One-shot visual effects built from CPUParticles3D. Each effect frees itself.
## Black powder weapons throw a big, slow cloud of white smoke that hangs in
## the air, which is half the feel of a musket.
##
## The shot (user 2026-09-28: "it should be like powder smoke shooting out and within that powder smoke is some light
## or fire"; "i still like the orignal thick smoke cloud that was good and how it lingered"): the thick cloud as it
## always was, with a jet at its heart shooting out of the barrel, and a short, dim tongue of fire at the muzzle whose
## light is out in the smoke, lighting it from inside. The smoke is lit by the scene (the sun, the dusk, a torch) and
## fades as it comes near the camera. The fire is kept dim on purpose: at dusk and at night the eye's exposure (auto
## exposure) is far up, and a flame even of plain full colour bloomed into a white disc wider than the man.

## Powder smoke (the original cloud's white).
const SMOKE := Color(0.92, 0.92, 0.9)


static func muzzle_blast(parent: Node, xform: Transform3D, scale := 1.0) -> void:
	var dir := -xform.basis.z
	var wind := _wind(parent)
	var dim := _fire_dim(parent)
	# the fire's light, out in the smoke it throws, lighting it from inside
	_flash_light(parent, xform.origin + dir * 0.8, 0.7 * scale * dim, 0.1, 3.0)
	var fire := _particles(parent, xform.origin + dir * 0.05, 6, 0.02, 0.08, false, 0.9 * dim)
	fire.direction = dir
	fire.spread = 8.0
	fire.initial_velocity_min = 5.0 * scale
	fire.initial_velocity_max = 10.0 * scale
	fire.damping_min = 80.0
	fire.damping_max = 110.0
	fire.scale_amount_min = 0.06 * scale
	fire.scale_amount_max = 0.14 * scale
	fire.color_ramp = _ramp_at([[0.0, Color(1.0, 0.85, 0.5, 1.0)], [0.5, Color(1.0, 0.5, 0.15, 0.8)],
			[1.0, Color(0.8, 0.25, 0.05, 0.0)]])
	_emit(fire, true)
	# burning powder: a few grains flung out of the barrel, falling away
	var sparks := _particles(parent, xform.origin + dir * 0.05, int(12 * scale), 0.04, 0.6, false, 1.0 * dim)
	sparks.direction = dir
	sparks.spread = 14.0
	sparks.initial_velocity_min = 4.0 * scale
	sparks.initial_velocity_max = 12.0 * scale
	sparks.damping_min = 3.0
	sparks.damping_max = 6.0
	sparks.gravity = Vector3(0.0, -9.8, 0.0)
	sparks.scale_amount_min = 0.015
	sparks.scale_amount_max = 0.028
	sparks.color_ramp = _ramp_at([[0.0, Color(1.0, 0.8, 0.45, 1.0)], [0.6, Color(1.0, 0.45, 0.12, 0.8)],
			[1.0, Color(0.6, 0.15, 0.02, 0.0)]])
	_emit(sparks, false)
	# the jet: smoke shooting out along the barrel, stopping a metre or three out, where the cloud gathers
	var jet := _particles(parent, xform.origin + dir * 0.1, int(22 * scale), 0.04, 5.0, true)
	jet.direction = dir
	jet.spread = 8.0
	jet.initial_velocity_min = 6.0 * scale
	jet.initial_velocity_max = 12.0 * scale
	jet.damping_min = 18.0
	jet.damping_max = 22.0
	jet.damping_curve = _points([Vector2(0.0, 1.0), Vector2(0.12, 1.0), Vector2(0.2, 0.15), Vector2(1.0, 0.15)])
	jet.gravity = wind * 0.5
	jet.scale_amount_min = 0.16 * scale
	jet.scale_amount_max = 0.36 * scale
	jet.scale_amount_curve = _points([Vector2(0.0, 0.5), Vector2(0.15, 1.2), Vector2(1.0, 2.8)], 2.9)
	jet.color_ramp = _ramp_at([[0.0, Color(SMOKE, 0.0)], [0.03, Color(SMOKE, 0.5)], [0.5, Color(SMOKE, 0.4)],
			[1.0, Color(SMOKE, 0.0)]])
	_emit(jet, false)
	# the cloud, as it always was: big, slow, thick, and it hangs
	var smoke := _particles(parent, xform.origin + dir * 0.2, int(28 * scale), 0.25, 5.0, true)
	smoke.direction = dir
	smoke.spread = 25.0
	smoke.initial_velocity_min = 2.0 * scale
	smoke.initial_velocity_max = 6.0 * scale
	smoke.damping_min = 3.0
	smoke.damping_max = 5.0
	smoke.gravity = wind * 0.5 + Vector3.UP * 0.25
	smoke.scale_amount_min = 0.35 * scale
	smoke.scale_amount_max = 0.8 * scale
	smoke.scale_amount_curve = _curve(0.4, 1.0, 2.2)
	smoke.color_ramp = _ramp([Color(SMOKE, 0.0), Color(0.9, 0.9, 0.88, 0.55), Color(0.85, 0.85, 0.83, 0.0)])
	_emit(smoke, false)


## The flash in the pan of a flintlock, a moment before the main charge fires: a spit of fire, then a small grey puff
## rising from the lock.
static func pan_flash(parent: Node, pos: Vector3) -> void:
	var dim := _fire_dim(parent)
	_flash_light(parent, pos, 0.5 * dim, 0.05, 1.4)
	var f := _particles(parent, pos, 6, 0.05, 0.2, false, 0.8 * dim)
	f.direction = Vector3.UP
	f.spread = 50.0
	f.initial_velocity_min = 0.8
	f.initial_velocity_max = 2.0
	f.scale_amount_min = 0.04
	f.scale_amount_max = 0.09
	f.color_ramp = _ramp([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.6, 0.2, 0.0)])
	_emit(f, true)
	var p := _particles(parent, pos, 10, 0.1, 2.2, true)
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.damping_min = 1.0
	p.damping_max = 1.5
	p.gravity = _wind(parent) * 0.5 + Vector3.UP * 0.25
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	p.scale_amount_curve = _curve(0.5, 1.0, 2.4)
	p.color_ramp = _ramp_at([[0.0, Color(SMOKE, 0.0)], [0.06, Color(SMOKE, 0.45)], [1.0, Color(SMOKE, 0.0)]])
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


## `lit`: smoke (lit by the scene, the noisy puff turned at random, soft where it meets things); `glow` > 0: fire,
## additive and `glow` times as bright (over 1 it blooms, as the torch's embers; keep the big particles near 1: stacked,
## a dozen of them bloomed into a white disc); else dust (unshaded soft dots). All fade out as they come within a metre
## or two of the camera.
static func _particles(parent: Node, pos: Vector3, amount: int, explosiveness_time: float, lifetime: float,
		lit := false, glow := 0.0) -> CPUParticles3D:
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
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	if lit:
		mat.albedo_texture = _puff()
		mat.roughness = 1.0
		mat.metallic_specular = 0.0
		mat.backlight_enabled = true
		mat.backlight = Color(0.6, 0.6, 0.6)
		mat.proximity_fade_enabled = true
		mat.proximity_fade_distance = 0.5
		mat.distance_fade_min_distance = 0.4
		mat.distance_fade_max_distance = 2.0
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -12.0
		p.angular_velocity_max = 12.0
	elif glow > 0.0:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(glow, glow, glow)
		mat.albedo_texture = _soft_dot()
		mat.disable_fog = true
		mat.disable_receive_shadows = true
		mat.distance_fade_min_distance = 0.2
		mat.distance_fade_max_distance = 0.8
	else:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = _soft_dot()
		mat.disable_receive_shadows = true
		mat.distance_fade_min_distance = 0.2
		mat.distance_fade_max_distance = 0.8
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


## A flash's light: warm, gone in `time`; even over its `reach` (omni_attenuation 0: no hot spot, which blew the
## puffs of smoke right by it out to white discs), fading only at the edge.
static func _flash_light(parent: Node, pos: Vector3, energy: float, time: float, reach := 3.0) -> void:
	if _warming:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.38)
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 0.0
	# the flash lights the scene and the smoke, not the volumetric fog (its temporal reprojection would smear a flash of
	# a few frames over many)
	l.light_volumetric_fog_energy = 0.0
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


## A curve through `pts` (x 0..1 over the lifetime), its values up to `top`.
static func _points(pts: Array, top := 1.0) -> Curve:
	var cv := Curve.new()
	cv.max_value = top
	for q: Vector2 in pts:
		cv.add_point(q)
	return cv


## A colour ramp from [[offset, colour], ...].
static func _ramp_at(stops: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s: Array in stops:
		offsets.append(float(s[0]))
		colors.append(s[1])
	g.offsets = offsets
	g.colors = colors
	return g


## The level's DayNight (the sky's clock, the weather, the eye's exposure), or null.
static func _day_night(parent: Node) -> DayNight:
	var tree := parent.get_tree() if parent and parent.is_inside_tree() else null
	var rig := tree.current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig if tree and tree.current_scene else null
	return rig.clock_driver if rig else null


## The fire's brightness for the eye as it is now: 1 / the exposure (DayNight's tonemap exposure: about 1 at noon, 2
## at dusk, 5.4 at night), so a flame comes out on the screen at the same brightness at any hour, and the effects give
## theirs as on-screen values (under 1.5: the glow starts at 4, and it spread every brighter point, spark or flame,
## into a soft disc 50 px across; stacked, they made the white disc wider than the man).
static func _fire_dim(parent: Node) -> float:
	var dn := _day_night(parent)
	if dn == null or dn.env == null:
		return 1.0
	return 1.0 / maxf(dn.env.tonemap_exposure, 0.5)


## The ground wind as a push on the smoke (m/s², world): the weather's (WeatherSystem.wind_ground_*), else a light
## breeze. A calm day leaves the cloud hanging; a gale takes it off.
static func _wind(parent: Node) -> Vector3:
	var d := Vector2(0.866, -0.5)
	var s := 0.3
	var dn := _day_night(parent)
	var w: Variant = dn.weather if dn else null
	if w is WeatherSystem:
		d = (w as WeatherSystem).wind_ground_dir
		s = (w as WeatherSystem).wind_ground_strength
	return Vector3(d.x, 0.0, d.y).normalized() * (0.12 + 0.5 * clampf(s, 0.0, 1.0))


static var _puff_tex: Texture2D

## A puff of smoke: round and soft, broken up by noise (a cloudy edge, thinner places); white, the colour ramp tints
## it.
static func _puff() -> Texture2D:
	if _puff_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		n.frequency = 0.045
		n.seed = 1765
		var sz := 128
		var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
		for y in sz:
			for x in sz:
				var u := (x + 0.5) / sz - 0.5
				var v := (y + 0.5) / sz - 0.5
				var fall := 1.0 - smoothstep(0.35, 1.0, sqrt(u * u + v * v) * 2.0)
				var nz := n.get_noise_2d(x, y) * 0.5 + 0.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(fall * (0.62 + 0.7 * nz) - 0.04, 0.0, 1.0) * fall))
		img.generate_mipmaps()
		_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


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
