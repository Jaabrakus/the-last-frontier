class_name BendLooks
extends RefCounted
## How the bent elements look and sound (BendEffects, BendBolt, BendZone; docs/bending_design.md): a bolt's body by its kind
## (stone, ice, water, fire, air, lightning), its trail, the bursts where it lands, the cone and the ring of a blast. Built
## of the game's own particles (Fx._particles: the fire's glow, the soft dust) and plain meshes; nothing is drawn headless.
## The sounds are the nearest the game has (no water, fire or wind recordings yet): SOUNDS.

const FormMatter := preload("res://scripts/sway/form_matter.gd")

const KINDS := ["stone", "ice", "water", "fire", "air", "lightning"]
## [sound id, pitch] by kind and what happens (the nearest recordings the game has).
const SOUNDS := {
	"stone": {"cast": [&"gather_rec_rock_split", 1.0], "hit": [&"gather_rec_pick_rock_hard", 0.9]},
	"ice": {"cast": [&"arrow_whoosh", 1.3], "hit": [&"gather_rec_pick_rock_hard", 1.5]},
	"water": {"cast": [&"arrow_whoosh", 0.8], "hit": [&"land_dirt", 1.3]},
	"fire": {"cast": [&"torch_ignite", 1.0], "hit": [&"torch_toss", 0.8]},
	"air": {"cast": [&"arrow_whoosh", 0.6], "hit": [&"arrow_whoosh", 0.45]},
	"lightning": {"cast": [&"musket_shot", 1.6], "hit": [&"pan_flash", 0.7]},
	"steam": {"hit": [&"torch_snuff", 1.0]},
}

static var _mats := {}


static func live() -> bool:
	return DisplayServer.get_name() != "headless"


static func sound(kind: String, what: String, at: Vector3, db := 0.0) -> void:
	var e: Array = (SOUNDS.get(kind, {}) as Dictionary).get(what, [])
	if e.is_empty() or not Sfx.has(e[0]):
		return
	Sfx.play_3d(e[0], at, db, float(e[1]) * randf_range(0.93, 1.07))


static func color(kind: String) -> Color:
	match kind:
		"stone":
			return Color(0.55, 0.5, 0.42)
		"ice":
			return Color(0.8, 0.93, 1.0)
		"water":
			return Color(0.32, 0.6, 0.95)
		"fire":
			return Color(1.0, 0.5, 0.15)
		"air":
			return Color(0.92, 0.96, 1.0)
		"lightning":
			return Color(0.7, 0.82, 1.0)
	return Color.WHITE


static func material(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"water":
			m.albedo_color = Color(0.25, 0.55, 0.92, 0.72)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.04
			m.metallic_specular = 0.9
			m.rim_enabled = true
			m.rim = 0.8
			m.emission_enabled = true
			m.emission = Color(0.05, 0.15, 0.3)
		"ice":
			m.albedo_color = Color(0.82, 0.94, 1.0, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.12
			m.emission_enabled = true
			m.emission = Color(0.18, 0.32, 0.42)
		"fire":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(1.0, 0.55, 0.18)
		"air":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.92, 0.96, 1.0, 0.22)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"lightning":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(0.75, 0.86, 1.0)
		_:
			_mats[kind] = FormMatter.rock_material("stone")
			return _mats[kind]
	_mats[kind] = m
	return m


## A bolt's body: under `parent`, its forward -Z (a long one, a shard or a slice, drawn along it).
static func bolt_body(parent: Node3D, kind: String, r: float, long := false) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind in ["fire", "air", "lightning"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	match kind:
		"stone":
			mi.mesh = FormModels.ball_mesh(r, randi() % 50) if not long else FormModels.spike_mesh(r, r * 7.0, randi() % 50, 0.0)
			if long:
				mi.rotation.x = -PI / 2.0
		"ice":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = r
			c.height = r * (8.0 if long else 4.5)
			c.radial_segments = 6
			c.rings = 1
			mi.mesh = c
			mi.rotation.x = -PI / 2.0
		"air":
			if long:
				var b := BoxMesh.new()
				b.size = Vector3(r * 9.0, 0.03, r * 2.5)
				mi.mesh = b
			else:
				var s := SphereMesh.new()
				s.radius = r
				s.height = r * 2.0
				mi.mesh = s
		_:
			var s := SphereMesh.new()
			s.radius = r
			s.height = r * (2.0 if not long else 4.0)
			s.radial_segments = 16
			s.rings = 8
			mi.mesh = s
			if long:
				mi.rotation.x = -PI / 2.0
	mi.material_override = material(kind)
	parent.add_child(mi)
	if kind == "fire" and live():
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.25)
		l.light_energy = 1.6
		l.omni_range = 3.5
		l.shadow_enabled = false
		parent.add_child(l)


## A trail that follows `parent` (emitting till freed; left behind to fade when the bolt ends: stop_trail).
static func trail(parent: Node3D, kind: String, r: float) -> GPUParticles3D:
	if not live() or kind == "stone":
		return null
	var glow := 1.4 if kind in ["fire", "lightning"] else 0.0
	var cp := Fx._particles(parent, parent.global_position, 40, 1.0, 0.45 if kind == "fire" else 0.35, false, glow)
	cp.one_shot = false
	cp.explosiveness = 0.0
	cp.direction = Vector3.UP
	cp.spread = 180.0
	cp.initial_velocity_min = 0.2
	cp.initial_velocity_max = 0.8
	cp.gravity = Vector3(0, 1.5, 0) if kind == "fire" else (Vector3(0, -4.0, 0) if kind == "water" else Vector3.ZERO)
	cp.scale_amount_min = r * 0.9
	cp.scale_amount_max = r * 2.0
	cp.color_ramp = _ramp(kind)
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = r * 0.6
	var g := GPUParticles3D.new()
	g.convert_from_particles(cp)
	g.local_coords = false
	g.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	cp.get_parent().remove_child(cp)
	cp.free()
	parent.add_child(g)
	g.emitting = true
	return g


## A lasting emitter of `kind` under `parent` over a box of `extents` (half sizes, local): a fire wall's flames, a cloud,
## a wall of water's spray, a tornado's dust. `rise` m/s up; `amount` live at once over `life` s each.
static func emitter(parent: Node3D, kind: String, extents: Vector3, amount := 60, life := 0.9, rise := 1.5, size := 0.5) -> GPUParticles3D:
	if not live():
		return null
	var glow := 1.3 if kind == "fire" else 0.0
	var cp := Fx._particles(parent, parent.global_position, amount, 1.0, life, kind in ["smoke", "dust", "stone"], glow)
	cp.one_shot = false
	cp.explosiveness = 0.0
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cp.emission_box_extents = extents
	cp.direction = Vector3.UP
	cp.spread = 25.0
	cp.initial_velocity_min = rise * 0.5
	cp.initial_velocity_max = rise
	cp.gravity = Vector3(0, -6.0, 0) if kind == "water" else Vector3.ZERO
	cp.scale_amount_min = size * 0.6
	cp.scale_amount_max = size * 1.3
	cp.color_ramp = _ramp(kind) if kind != "smoke" and kind != "dust" else (Fx._ramp_at([[0.0, Color(0.35, 0.33, 0.3, 0.0)],
			[0.2, Color(0.35, 0.33, 0.3, 0.75)], [1.0, Color(0.4, 0.38, 0.35, 0.0)]]) if kind == "smoke"
			else Fx._ramp_at([[0.0, Color(0.6, 0.55, 0.45, 0.0)], [0.2, Color(0.6, 0.55, 0.45, 0.6)], [1.0, Color(0.6, 0.55, 0.45, 0.0)]]))
	var g := GPUParticles3D.new()
	g.convert_from_particles(cp)
	g.local_coords = true
	g.visibility_aabb = AABB(-extents - Vector3(2, 2, 2), extents * 2.0 + Vector3(4, 6, 4))
	cp.get_parent().remove_child(cp)
	cp.free()
	parent.add_child(g)
	g.emitting = true
	return g


## The trail let go of its bolt: it stays where it is, stops and is freed once its last particles fade.
static func stop_trail(g: GPUParticles3D) -> void:
	if g == null or not is_instance_valid(g):
		return
	var xf := g.global_transform
	var scn := g.get_tree().current_scene if g.is_inside_tree() else null
	if scn == null:
		return
	g.get_parent().remove_child(g)
	scn.add_child(g)
	g.global_transform = xf
	g.emitting = false
	g.get_tree().create_timer(g.lifetime + 0.2, false).timeout.connect(g.queue_free)


## A burst of `kind` at `at` (a hit, a cast): `n` bits flung along `dir` within `spread` deg (180: all round).
static func burst(at: Vector3, kind: String, n := 18, dir := Vector3.UP, spread := 180.0, speed := 4.0, size := 0.25) -> void:
	var scn := _scene()
	if scn == null or not live():
		return
	var glow := 1.5 if kind in ["fire", "lightning"] else 0.0
	var p := Fx._particles(scn, at, n, 0.05, 0.7 if kind != "air" else 0.5, kind == "stone", glow)
	p.direction = dir.normalized() if dir.length_squared() > 1e-6 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.gravity = Vector3(0, 2.0, 0) if kind == "fire" else (Vector3(0, -9.0, 0) if kind in ["water", "ice", "stone"] else Vector3.ZERO)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size * 1.4
	p.color_ramp = _ramp(kind)
	Fx._emit(p, true)


## A blast over a cone (from `at` along `dir`, `deg` wide, `reach` m) or, at 360, a ring round `at`.
static func blast(at: Vector3, dir: Vector3, deg: float, reach: float, kind: String) -> void:
	if not live():
		return
	var n := clampi(int(deg / 4.0 * reach / 3.0), 16, 90)
	burst(at, kind, n, dir if deg < 359.0 else Vector3.UP, deg * 0.5 if deg < 359.0 else 180.0, reach * 2.2, 0.45)
	if deg >= 359.0:
		# (a flat ring: bits flung out level all round)
		var scn := _scene()
		var glow := 1.4 if kind == "fire" else 0.0
		var p := Fx._particles(scn, at + Vector3.UP * 0.4, n, 0.05, 0.6, kind == "stone", glow)
		p.direction = Vector3.RIGHT
		p.spread = 180.0
		p.flatness = 0.9
		p.initial_velocity_min = reach * 1.6
		p.initial_velocity_max = reach * 2.4
		p.damping_min = reach
		p.damping_max = reach * 1.5
		p.scale_amount_min = 0.3
		p.scale_amount_max = 0.7
		p.color_ramp = _ramp(kind)
		Fx._emit(p, true)


## Lightning from `a` to `b`: a jagged bright line for a moment, a flash of light.
static func lightning(a: Vector3, b: Vector3) -> void:
	var scn := _scene()
	if scn == null or not live():
		return
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = material("lightning")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scn.add_child(mi)
	var d := b - a
	var side := d.cross(Vector3.UP).normalized()
	var up := side.cross(d.normalized()).normalized()
	for strand in 2:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n := 14
		for i in n + 1:
			var t := float(i) / n
			var jit := (side * randf_range(-1, 1) + up * randf_range(-1, 1)) * 0.35 * sin(t * PI) * (1.0 if strand == 0 else 0.6)
			var p := a + d * t + jit
			var w := 0.06 if strand == 0 else 0.03
			im.surface_add_vertex(p - up * w)
			im.surface_add_vertex(p + up * w)
		im.surface_end()
	Fx._flash_light(scn, (a + b) * 0.5, 4.0, 0.15, d.length() * 0.6 + 4.0)
	var t := mi.create_tween()
	t.tween_interval(0.12)
	t.tween_callback(mi.queue_free)


static func _ramp(kind: String) -> Gradient:
	var c := color(kind)
	match kind:
		"fire":
			return Fx._ramp_at([[0.0, Color(1.0, 0.9, 0.55, 1.0)], [0.35, Color(1.0, 0.5, 0.12, 0.85)], [1.0, Color(0.35, 0.08, 0.03, 0.0)]])
		"lightning":
			return Fx._ramp_at([[0.0, Color(1, 1, 1, 1)], [1.0, Color(0.5, 0.65, 1.0, 0.0)]])
		"air":
			return Fx._ramp_at([[0.0, Color(1, 1, 1, 0.0)], [0.2, Color(1, 1, 1, 0.4)], [1.0, Color(0.9, 0.95, 1.0, 0.0)]])
		"steam":
			return Fx._ramp_at([[0.0, Color(0.95, 0.95, 0.95, 0.7)], [1.0, Color(0.9, 0.9, 0.9, 0.0)]])
	return Fx._ramp_at([[0.0, Color(c.r, c.g, c.b, 0.9)], [1.0, Color(c.r, c.g, c.b, 0.0)]])


static func _scene() -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.current_scene if ml != null else null
