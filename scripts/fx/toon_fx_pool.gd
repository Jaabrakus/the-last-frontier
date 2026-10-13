class_name ToonFxPool
extends Node3D
## Plays the cel effects of a scene (ToonFx) and keeps them cheap: one per scene (of), under it. Nothing is made per hit once
## warm: every kind of particle has a few GPU emitters taken in turn (shoot: the oldest restarted when all are busy, so a
## flurry of hits can never pile up more than SLOTS of them), the short shapes (flashes, rings, splash crowns, swirls) and
## the marks on the ground are a few meshes each reused the same way and animated here by their instance uniforms (shared
## materials), flash lights a few, lightning a few strips rebuilt as it flickers, the bolts' trails handed out and taken back
## (trail_take / trail_release). Particles count: at most SLOTS emitters of `amount` per kind.

const LIGHTS := 4
const BOLTS := 4
const TRAILS_PER_KIND := 12
## Marks on the ground of each kind at once (round 4: the Kick's scorches along its path, ToonFx.looks floor_wave).
const MARKS := 16

static var _pool: ToonFxPool

## kind of particle -> {"list": Array[GPUParticles3D], "i": next}
var _parts := {}
## kind of shape -> {"list": Array[MeshInstance3D], "i": next}
var _shapes := {}
## the shapes playing: [node, t, life, scale0, scale1, key]
var _playing: Array = []
var _lights: Array[OmniLight3D] = []
var _light_i := 0
## the lights fading: [light, t, time, energy]
var _lit: Array = []
var _bolts: Array = []
var _bolt_i := 0
## trails: kind -> Array of {"g": GPUParticles3D, "free_at": float (-1 in use)}
var _trails := {}
var _now := 0.0


## The pool of `scene` (made under it the first time).
static func of(scene: Node) -> ToonFxPool:
	if scene == null:
		return null
	if _pool != null and is_instance_valid(_pool) and _pool.is_inside_tree() and _pool.get_parent() == scene:
		return _pool
	var p := scene.get_node_or_null("ToonFxPool") as ToonFxPool
	if p == null:
		p = ToonFxPool.new()
		p.name = "ToonFxPool"
		scene.add_child(p)
	_pool = p
	return p


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY


func now() -> float:
	return _now


# ---------------------------------------------------------------- particles
## `count` particles of `key` (ToonFx.recipe) from `at` along `dir` within `spread` deg, at `v` m/s (min, max), `s` m big
## (min, max), living `life` s, pulled by `gravity`, slowed by `damp` m/s². opt: r (the emission sphere's radius), box
## (emission box half extents), flat (flatness 0..1), ang (angular velocity, deg/s, min = -max), xf (the emitter's basis:
## local coords), radial (m/s outward), occl (round 4: Vector4 a struck body's middle and radius: the puffs between the
## camera and it drawn at half; none: zero).
func shoot(key: String, at: Vector3, count: int, dir: Vector3, spread: float, v: Vector2, s: Vector2, life: float,
		gravity := Vector3.ZERO, damp := 0.0, opt := {}) -> GPUParticles3D:
	if count <= 0:
		return null
	var rec := ToonFx.recipe(key)
	var g := _slot(key, rec)
	var pm := g.process_material as ParticleProcessMaterial
	pm.direction = dir.normalized() if dir.length_squared() > 1e-6 else Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = v.x
	pm.initial_velocity_max = v.y
	pm.scale_min = s.x
	pm.scale_max = s.y
	pm.gravity = gravity
	pm.damping_min = damp * 0.7
	pm.damping_max = damp
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX if opt.has("box") else ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = float(opt.get("r", 0.08))
	pm.emission_box_extents = opt.get("box", Vector3.ONE * 0.1)
	pm.flatness = float(opt.get("flat", 0.0))
	pm.radial_velocity_min = float(opt.get("radial", 0.0)) * 0.6
	pm.radial_velocity_max = float(opt.get("radial", 0.0))
	if opt.has("ang"):
		pm.angular_velocity_min = -float(opt.ang)
		pm.angular_velocity_max = float(opt.ang)
	if (rec.mat as ShaderMaterial).shader == ToonFx.SHADERS.puff:
		g.set_instance_shader_parameter(&"occl", opt.get("occl", Vector4.ZERO))
	g.lifetime = life
	g.amount_ratio = clampf(float(count) / float(g.amount), 0.02, 1.0)
	g.global_transform = Transform3D(opt.get("basis", Basis.IDENTITY), at)
	g.visible = true
	g.restart()
	return g


func _slot(key: String, rec: Dictionary) -> GPUParticles3D:
	var e: Dictionary = _parts.get(key, {})
	if e.is_empty():
		e = {"list": [], "i": 0}
		_parts[key] = e
	var list: Array = e.list
	for j in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[j]):
			list.remove_at(j)
	# a free one, else a new one while under the cap, else the next in turn (its burst cut short)
	for g: GPUParticles3D in list:
		if not g.emitting:
			return g
	if list.size() < int(rec.slots):
		var g := GPUParticles3D.new()
		g.amount = int(rec.amount)
		g.one_shot = true
		g.explosiveness = 1.0
		g.randomness = 0.4
		g.local_coords = false
		g.interpolate = false
		g.process_material = (rec.proc as ParticleProcessMaterial).duplicate()
		g.draw_pass_1 = rec.mesh
		g.material_override = rec.mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_aabb = AABB(Vector3(-12, -6, -12), Vector3(24, 18, 24))
		g.emitting = false
		add_child(g)
		list.append(g)
		return g
	e.i = (int(e.i) + 1) % list.size()
	return list[e.i]


# ---------------------------------------------------------------- shapes
## Shape `key` (a material of ToonFx's sprite: flash, ring, crown, swirl; mark_*: a mark on the ground) at `xf` for `life`
## s, its scale going `s0` -> `s1` (eased out), coloured `tint` / `tint2`.
func play(key: String, xf: Transform3D, life: float, s0: float, s1: float, tint := Color.WHITE, tint2 := Color.WHITE,
		mesh: Mesh = null) -> MeshInstance3D:
	var mi := _shape(key, mesh)
	mi.global_transform = xf.scaled_local(Vector3.ONE * maxf(s0, 0.001))
	mi.set_instance_shader_parameter(&"t", 0.0)
	mi.set_instance_shader_parameter(&"tint", tint)
	mi.set_instance_shader_parameter(&"tint2", tint2)
	mi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	mi.visible = true
	for i in _playing.size():
		if _playing[i][0] == mi:
			_playing.remove_at(i)
			break
	_playing.append([mi, 0.0, life, s0, s1, xf])
	return mi


func _shape(key: String, mesh: Mesh) -> MeshInstance3D:
	var cap := MARKS if key.begins_with("mark") else 12
	var k := key + (str(mesh.get_instance_id()) if mesh != null else "")
	var e: Dictionary = _shapes.get(k, {})
	if e.is_empty():
		e = {"list": [], "i": 0}
		_shapes[k] = e
	var list: Array = e.list
	for j in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[j]):
			list.remove_at(j)
	for mi: MeshInstance3D in list:
		if not mi.visible:
			return mi
	if list.size() < cap:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh if mesh != null else (ToonFx.plane() if key == "ring" or key.begins_with("mark") else ToonFx.quad())
		mi.material_override = ToonFx.mat(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
		mi.visible = false
		add_child(mi)
		list.append(mi)
		return mi
	e.i = (int(e.i) + 1) % list.size()
	return list[e.i]


## A mark on the ground at `at` (mode: scorch, cracks, frost, wet), lying on `normal`, `size` m across, `life` s.
func mark(mode: String, at: Vector3, normal: Vector3, size: float, life: float) -> void:
	var n := normal.normalized() if normal.length_squared() > 1e-6 else Vector3.UP
	var x := n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT).normalized()
	var b := Basis(x, n, x.cross(n)).rotated(n, ToonFx.vis_rng.randf() * TAU)
	play("mark_" + mode, Transform3D(b, at + n * 0.02), life, size * 0.5, size * 0.5)


func light(at: Vector3, col: Color, energy: float, time: float, reach: float) -> void:
	var l: OmniLight3D
	if _lights.size() < LIGHTS:
		l = OmniLight3D.new()
		l.shadow_enabled = false
		l.omni_attenuation = 0.6
		l.light_volumetric_fog_energy = 0.0
		add_child(l)
		_lights.append(l)
	else:
		_light_i = (_light_i + 1) % _lights.size()
		l = _lights[_light_i]
		for i in _lit.size():
			if _lit[i][0] == l:
				_lit.remove_at(i)
				break
	l.global_position = at
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.visible = true
	_lit.append([l, 0.0, time, energy])


# ---------------------------------------------------------------- lightning
## Lightning from `a` to `b` (ToonFx.lightning_strips builds the forks): rebuilt `flickers` times over its life, then thinned
## out.
func lightning(a: Vector3, b: Vector3, life := 0.26, flickers := 3) -> void:
	var e: Dictionary
	if _bolts.size() < BOLTS:
		var mi := MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		mi.material_override = ToonFx.mat("bolt")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 4.0
		add_child(mi)
		e = {"mi": mi}
		_bolts.append(e)
	else:
		_bolt_i = (_bolt_i + 1) % _bolts.size()
		e = _bolts[_bolt_i]
	e.a = a
	e.b = b
	e.t = 0.0
	e.life = life
	e.next = life * 0.22
	e.left = flickers - 1
	e.on = true
	var mi: MeshInstance3D = e.mi
	mi.visible = true
	mi.set_instance_shader_parameter(&"fade", 1.0)
	ToonFx.lightning_strips(mi.mesh as ImmediateMesh, a, b)


func _bolt_step(e: Dictionary, dt: float) -> void:
	e.t = float(e.t) + dt
	var mi: MeshInstance3D = e.mi
	if not is_instance_valid(mi):
		e.on = false
		return
	if float(e.t) >= float(e.life):
		e.on = false
		mi.visible = false
		(mi.mesh as ImmediateMesh).clear_surfaces()
		return
	if int(e.left) > 0 and float(e.t) >= float(e.next):
		e.left = int(e.left) - 1
		e.next = float(e.next) + float(e.life) * 0.22
		ToonFx.lightning_strips(mi.mesh as ImmediateMesh, e.a, e.b)
	var fade := 1.0 - clampf((float(e.t) - float(e.life) * 0.55) / (float(e.life) * 0.45), 0.0, 1.0)
	mi.set_instance_shader_parameter(&"fade", fade)


# ---------------------------------------------------------------- trails
## A trail of `kind` free to follow a bolt (made by `make` when none is free and under the cap; null at the cap).
func trail_take(kind: String, make: Callable) -> GPUParticles3D:
	var list: Array = _trails.get(kind, [])
	_trails[kind] = list
	for j in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[j].g):
			list.remove_at(j)
	for e: Dictionary in list:
		if float(e.free_at) >= 0.0 and _now >= float(e.free_at):
			e.free_at = -1.0
			(e.g as GPUParticles3D).visible = true      # (hidden as it was let go: trail_release)
			return e.g
	if list.size() >= TRAILS_PER_KIND:
		return null
	var g: GPUParticles3D = make.call()
	if g == null:
		return null
	g.set_meta(&"toon_trail", kind)
	list.append({"g": g, "free_at": -1.0})
	return g


## Trail `g` let go of its bolt: left where it is to fade, then free for the next.
func trail_release(g: GPUParticles3D) -> void:
	var kind := String(g.get_meta(&"toon_trail", ""))
	var xf := g.global_transform
	if g.get_parent() != self:
		if g.get_parent() != null:
			g.get_parent().remove_child(g)
		add_child(g)
	g.global_transform = xf
	var longest := g.lifetime
	g.emitting = false
	for c in g.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).emitting = false
			longest = maxf(longest, (c as GPUParticles3D).lifetime)
		elif c is ToonRibbon:
			(c as ToonRibbon).stop()
	for e: Dictionary in _trails.get(kind, []):
		if e.g == g:
			e.free_at = _now + longest + 0.25
			# (hidden once its last particles' time is up: a let-go trail's particles were left drawn where they stopped,
			# frozen, till it was taken again: the Lash's drops and mist hanging along its path, 2026-10-12)
			var at := float(e.free_at)
			get_tree().create_timer(longest + 0.05, false).timeout.connect(func() -> void:
				if is_instance_valid(g) and float(e.free_at) == at:
					g.visible = false)
			return


func _process(dt: float) -> void:
	_now += dt
	var i := 0
	while i < _playing.size():
		var p: Array = _playing[i]
		var mi: MeshInstance3D = p[0]
		if not is_instance_valid(mi):
			_playing.remove_at(i)
			continue
		p[1] = float(p[1]) + dt
		var t := clampf(float(p[1]) / float(p[2]), 0.0, 1.0)
		mi.set_instance_shader_parameter(&"t", t)
		if not is_equal_approx(float(p[3]), float(p[4])):
			var e := 1.0 - pow(1.0 - t, 2.4)
			mi.global_transform = (p[5] as Transform3D).scaled_local(Vector3.ONE * maxf(lerpf(p[3], p[4], e), 0.001))
		if t >= 1.0:
			mi.visible = false
			_playing.remove_at(i)
			continue
		i += 1
	i = 0
	while i < _lit.size():
		var q: Array = _lit[i]
		var l: OmniLight3D = q[0]
		q[1] = float(q[1]) + dt
		var k := clampf(float(q[1]) / float(q[2]), 0.0, 1.0)
		l.light_energy = float(q[3]) * (1.0 - k)
		if k >= 1.0:
			l.visible = false
			_lit.remove_at(i)
			continue
		i += 1
	for e: Dictionary in _bolts:
		if bool(e.get("on", false)):
			_bolt_step(e, dt)
