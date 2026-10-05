class_name BendLooks
extends RefCounted
## How the bent elements look and sound (BendEffects, BendBolt, BendZone; docs/bending_design.md): a bolt's body by its kind
## (stone, ice, water, fire, air, lightning), its trail, the bursts where it lands, the cone and the ring of a blast, the
## lightning. Drawn in the cel look (ToonFx: hard colour bands, bold shapes, 2D animated effects stood up in 3D):
##   fire       a boiling white-hot orb with banded flame tongues licking back off it, a flame ribbon and embers behind;
##              on a hit a spiked flash, flame puffs, embers, a shock ring and a scorch on the ground
##   water      a wobbling head of water with a stream behind it (a tube of flowing foam) and two strands coiling round it,
##              droplets; on a hit a splash crown, a ripple ring, droplets and foam, a wet mark
##   ice        a faceted crystal with a sweeping glint, a frost streak and sparkles; it shatters into spinning shards,
##              frost and sparkles, frost on the ground
##   air        swirl bands spinning round a ball (a crescent for a slice), two speed lines corkscrewing behind; on a hit
##              crescents spin out, speed lines, puffs, dust off the ground
##   stone      the rock in cel facets, dust and grit behind it; chunks, dust puffs, a dust ring and cracks in the ground
##   lightning  forks with a white core in a blue sheath that flicker, sparks and a flash where it strikes
## Cheap: ToonFxPool reuses every emitter, shape and trail (caps per kind), materials and meshes are shared; no node is
## made per hit once warm (a bolt's body is made with the bolt). Nothing is drawn headless.
## The sounds are the nearest the game has (no water, fire or wind recordings yet): SOUNDS.
## rise(at, size, way): the dust and cracks along the foot of an earth wall coming up (for FormRaised's raise to call).
## warm_up(cam): every effect played once out of sight at the level's load (their shaders compiled then, not at a first hit).

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
const FIRE := Color(1.0, 0.45, 0.06)
const FIRE_HOT := Color(1.0, 0.82, 0.25)
const WATER := Color(0.2, 0.6, 1.0)
const FOAM := Color(0.92, 0.98, 1.0)
const ICE := Color(0.6, 0.88, 1.0)
const AIR := Color(0.85, 0.95, 1.0)
const DUST := Color(0.72, 0.6, 0.45)
const DUST_LIGHT := Color(0.88, 0.78, 0.6)
const ELEC := Color(0.45, 0.68, 1.0)


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


## The surface material of `kind` (shared): water, ice, the air's swirl, fire's flame, lightning, stone's rock.
static func material(kind: String) -> Material:
	match kind:
		"water":
			return ToonFx.mat("water")
		"ice":
			return ToonFx.mat("ice")
		"fire":
			return ToonFx.mat("flame")
		"air":
			return ToonFx.mat("wind_band")
		"lightning":
			return ToonFx.mat("bolt")
	return ToonFx.mat("rock")


static func _pool() -> ToonFxPool:
	return ToonFxPool.of(_scene())


# ---------------------------------------------------------------- bolts
## A bolt's body: under `parent`, its forward -Z (a long one, a shard or a slice, drawn along it).
static func bolt_body(parent: Node3D, kind: String, r: float, long := false) -> void:
	match kind:
		"fire":
			_fire_body(parent, r, long)
		"water":
			var mi := _mesh(parent, ToonFx.sphere(16), ToonFx.mat("water"))
			mi.scale = Vector3(r * 1.3, r * 1.3, r * (2.6 if long else 1.8))
			mi.position = Vector3(0.0, 0.0, r * 0.35)
			mi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
		"ice":
			var mi := _mesh(parent, ToonFx.shard_mesh(1.0, 0.2, ToonFx.vis_rng.randi() % 4), ToonFx.mat("ice"))
			var l := r * (11.0 if long else 5.5)
			mi.scale = Vector3(r * 7.0, r * 7.0, l)
			if live():
				var g := _mesh(parent, ToonFx.quad(), ToonFx.mat("star_still"))
				g.position = Vector3(0.0, 0.0, -l * 0.72)
				g.scale = Vector3.ONE * maxf(r * 4.5, 0.45)
		"air":
			if long:
				var mi := _mesh(parent, ToonFx.arc_mesh(1.0, 0.42, 2.3), ToonFx.mat("wind_arc"))
				mi.scale = Vector3.ONE * r * 5.0
			else:
				for i in 3:
					var b := _mesh(parent, ToonFx.band_mesh(1.0, 0.85, 0.5), ToonFx.mat("wind_band_fast"))
					b.scale = Vector3.ONE * r * (1.25 - i * 0.18)
					b.rotation = Vector3(0.5 + i * 0.9, i * 1.3, 0.35 * i)
					b.position = -b.basis.y.normalized() * 0.25 * b.scale.y
					b.set_instance_shader_parameter(&"seed", i * 0.31)
				var core := _mesh(parent, ToonFx.sphere(12), ToonFx.mat("bubble"))
				core.scale = Vector3.ONE * r * 0.55
		"lightning":
			var o := _mesh(parent, ToonFx.quad(), ToonFx.mat("orb"))
			o.scale = Vector3.ONE * r * 3.0
			o.set_instance_shader_parameter(&"tint", ELEC)
			o.set_instance_shader_parameter(&"tint2", Color(0.8, 0.9, 1.0))
		_:
			var mi := MeshInstance3D.new()
			mi.name = "Body"
			mi.mesh = FormModels.ball_mesh(r, randi() % 50) if not long else FormModels.spike_mesh(r, r * 7.0, randi() % 50, 0.0)
			if long:
				mi.rotation.x = -PI / 2.0
			mi.material_override = ToonFx.mat("rock")
			parent.add_child(mi)


static func _mesh(parent: Node3D, m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A fireball: the boiling orb and three flame tongues licking back from it (one MultiMesh), a warm light on a big one.
static func _fire_body(parent: Node3D, r: float, long: bool) -> void:
	var o := _mesh(parent, ToonFx.quad(), ToonFx.mat("orb"))
	o.scale = Vector3.ONE * r * 2.5
	o.set_instance_shader_parameter(&"tint", Color(0.95, 0.22, 0.04))
	o.set_instance_shader_parameter(&"tint2", Color(1.0, 0.62, 0.08))
	o.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ToonFx.quad_base()
	var tongues := [[4.6, 2.3, 0.0, 0.0], [3.6, 1.7, 0.35, 0.2], [3.2, 1.6, -0.35, -0.15]]
	mm.instance_count = tongues.size()
	var k := 1.6 if long else 1.0
	for i in tongues.size():
		var tg: Array = tongues[i]
		var basis := Basis(Vector3.RIGHT * r * float(tg[1]), Vector3.BACK * r * float(tg[0]) * k, Vector3.UP)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(r * float(tg[2]), r * float(tg[3]), -r * 0.55)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tongues"
	mmi.multimesh = mm
	mmi.material_override = ToonFx.mat("flame")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	mmi.extra_cull_margin = r * 6.0
	parent.add_child(mmi)
	if live() and r >= 0.15:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.58, 0.22)
		l.light_energy = 1.4
		l.omni_range = 3.0 + r * 2.0
		l.shadow_enabled = false
		parent.add_child(l)


## A trail that follows `parent` (emitting till let go; left behind to fade when the bolt ends: stop_trail). Taken from the
## pool (null when every one of its kind is busy).
static func trail(parent: Node3D, kind: String, r: float) -> GPUParticles3D:
	if not live():
		return null
	var pool := _pool()
	if pool == null:
		return null
	var k := kind if kind in KINDS else "air"
	var g := pool.trail_take(k, func() -> GPUParticles3D: return _make_trail(k))
	if g == null:
		return null
	_setup_trail(g, k, r)
	if g.get_parent() != null:
		g.get_parent().remove_child(g)
	parent.add_child(g)
	g.position = Vector3.ZERO
	for c in g.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).restart()
		elif c is ToonRibbon:
			(c as ToonRibbon).follow(g)
	g.restart()
	return g


static func _stream(key: String, amount: int, life: float) -> GPUParticles3D:
	var rec := ToonFx.recipe(key)
	var g := GPUParticles3D.new()
	g.amount = amount
	g.lifetime = life
	g.one_shot = false
	g.explosiveness = 0.0
	g.randomness = 0.3
	g.local_coords = false
	g.process_material = (rec.proc as ParticleProcessMaterial).duplicate()
	g.draw_pass_1 = rec.mesh
	g.material_override = rec.mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	return g


static func _make_trail(kind: String) -> GPUParticles3D:
	var g: GPUParticles3D
	var rb := ToonRibbon.new()
	match kind:
		"fire":
			g = _stream("puff_fire", 18, 0.3)
			g.add_child(_stream("spark_fire", 12, 0.55))
			rb.main_mat = ToonFx.mat("flame_strip")
		"water":
			g = _stream("drop", 22, 0.55)
			rb.main_mat = ToonFx.mat("water_strip")
			rb.coil_mat = ToonFx.mat("water_strip")
			rb.coils = 2
		"ice":
			g = _stream("puff_frost", 16, 0.3)
			g.add_child(_stream("star", 10, 0.45))
			rb.main_mat = ToonFx.mat("ice_strip")
		"stone":
			g = _stream("puff_dust", 10, 0.4)
			g.add_child(_stream("chunk", 6, 0.8))
			rb.main_mat = ToonFx.mat("dust_strip")
		"lightning":
			g = _stream("spark_elec", 16, 0.25)
			rb = null
		_:
			g = _stream("puff_air", 10, 0.3)
			rb.main_mat = ToonFx.mat("wind_strip")
			rb.coil_mat = ToonFx.mat("wind_strip")
			rb.coils = 2
	g.name = "Trail_" + kind
	if rb != null:
		rb.name = "Ribbon"
		g.add_child(rb)
	return g


## A pooled trail set for a bolt of radius `r`.
static func _setup_trail(g: GPUParticles3D, kind: String, r: float) -> void:
	var pm := g.process_material as ParticleProcessMaterial
	var sub: GPUParticles3D = null
	var rb: ToonRibbon = null
	for c in g.get_children():
		if c is GPUParticles3D:
			sub = c
		elif c is ToonRibbon:
			rb = c
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = r * 0.5
	pm.direction = Vector3.UP
	pm.spread = 180.0
	match kind:
		"fire":
			_pm(pm, Vector2(0.3, 1.2), Vector2(maxf(r * 0.7, 0.12), maxf(r * 1.25, 0.2)), Vector3(0, 2.5, 0), 1.5)
			_pm(sub.process_material, Vector2(1.0, 3.0), Vector2(0.025, 0.045), Vector3(0, -2.0, 0), 1.0)
			_ribbon(rb, maxf(r * 1.5, 0.12), 0.2, 0.14)
		"water":
			_pm(pm, Vector2(0.4, 1.8), Vector2(r * 0.25, r * 0.55), Vector3(0, -12.0, 0), 0.5)
			_ribbon(rb, r * 1.05, 0.45, 0.13)
			rb.coil_r = r * 1.5
			rb.coil_w = r * 0.42
			rb.coil_spin = 26.0
		"ice":
			_pm(pm, Vector2(0.2, 0.8), Vector2(maxf(r * 1.6, 0.16), maxf(r * 2.6, 0.26)), Vector3.ZERO, 1.5)
			_pm(sub.process_material, Vector2(0.2, 1.0), Vector2(0.07, 0.13), Vector3(0, -1.0, 0), 1.0)
			_ribbon(rb, maxf(r * 0.9, 0.08), 0.1, 0.1)
		"stone":
			_pm(pm, Vector2(0.1, 0.6), Vector2(maxf(r * 0.9, 0.14), maxf(r * 1.6, 0.24)), Vector3(0, 0.3, 0), 1.0)
			_pm(sub.process_material, Vector2(0.5, 1.5), Vector2(r * 0.18, r * 0.4), Vector3(0, -12.0, 0), 0.0)
			_ribbon(rb, maxf(r * 0.8, 0.07), 0.1, 0.12)
		"lightning":
			_pm(pm, Vector2(1.0, 3.0), Vector2(0.03, 0.05), Vector3.ZERO, 2.0)
		_:
			_pm(pm, Vector2(0.2, 0.7), Vector2(r * 0.6, r * 1.3), Vector3.ZERO, 1.5)
			_ribbon(rb, r * 0.7, 0.1, 0.12)
			rb.coil_r = r * 1.35
			rb.coil_w = 0.05 + r * 0.14
			rb.coil_spin = 16.0


static func _pm(pm: ParticleProcessMaterial, v: Vector2, s: Vector2, gravity: Vector3, damp: float) -> void:
	pm.initial_velocity_min = v.x
	pm.initial_velocity_max = v.y
	pm.scale_min = s.x
	pm.scale_max = s.y
	pm.gravity = gravity
	pm.damping_min = damp * 0.6
	pm.damping_max = damp


static func _ribbon(rb: ToonRibbon, w: float, tail: float, life: float) -> void:
	if rb == null:
		return
	rb.width = w
	rb.tail_w = tail
	rb.life = life


## A lasting emitter of `kind` under `parent` over a box of `extents` (half sizes, local): a fire wall's flames, a cloud,
## a wall of water's spray, a tornado's dust. `rise` m/s up; `amount` live at once over `life` s each.
static func emitter(parent: Node3D, kind: String, extents: Vector3, amount := 60, life := 0.9, rise := 1.5, size := 0.5) -> GPUParticles3D:
	if not live():
		return null
	var key := "puff_air"
	var gravity := Vector3.ZERO
	match kind:
		"fire":
			key = "puff_fire"
			gravity = Vector3(0, 1.0, 0)
		"water", "spray":
			key = "drop"
			gravity = Vector3(0, -9.0, 0)
		"smoke":
			key = "puff_smoke"
		"dust", "stone":
			key = "puff_dust"
		"steam":
			key = "puff_steam"
		"ice", "frost":
			key = "puff_frost"
		"embers":
			key = "spark_fire"
			gravity = Vector3(0, 1.5, 0)
		"sparkle":
			key = "star"
		"debris":
			key = "chunk"
		"foam":
			key = "foam"
		"lightning":
			key = "spark_elec"
	var g := _stream(key, amount, life)
	var pm := g.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3.UP if rise >= 0.0 else Vector3.DOWN
	pm.spread = 25.0
	_pm(pm, Vector2(absf(rise) * 0.5, absf(rise)), Vector2(size * 0.6, size * 1.3), gravity, 0.5)
	g.local_coords = true
	g.visibility_aabb = AABB(-extents - Vector3(2, 2, 2), extents * 2.0 + Vector3(4, 8, 4))
	parent.add_child(g)
	g.emitting = true
	return g


## The trail let go of its bolt: it stays where it is, stops and is reused (a pooled trail) or freed once its last
## particles fade.
static func stop_trail(g: GPUParticles3D) -> void:
	if g == null or not is_instance_valid(g):
		return
	if g.has_meta(&"toon_trail"):
		var pool := _pool()
		if pool != null:
			pool.trail_release(g)
			return
	var xf := g.global_transform
	var scn := g.get_tree().current_scene if g.is_inside_tree() else null
	if scn == null:
		return
	g.get_parent().remove_child(g)
	scn.add_child(g)
	g.global_transform = xf
	g.emitting = false
	var longest := g.lifetime
	for c in g.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).emitting = false
			longest = maxf(longest, (c as GPUParticles3D).lifetime)
	g.get_tree().create_timer(longest + 0.2, false).timeout.connect(g.queue_free)


# ---------------------------------------------------------------- bursts
## A burst of `kind` at `at` (a hit, a cast): `n` bits flung along `dir` within `spread` deg (180: all round).
static func burst(at: Vector3, kind: String, n := 18, dir := Vector3.UP, spread := 180.0, speed := 4.0, size := 0.25) -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var d := dir.normalized() if dir.length_squared() > 1e-6 else Vector3.UP
	var k := clampf(size / 0.25, 0.5, 4.0)
	var g := _ground(pool, at, d)
	var up := Transform3D(Basis.IDENTITY, at)
	match kind:
		"fire":
			pool.play("flash", up, 0.18, 0.7 * k, 2.2 * k, FIRE, FIRE_HOT)
			pool.shoot("puff_fire", at, int(n * 0.9), d, spread, Vector2(speed * 0.3, speed * 0.9), Vector2(0.45, 1.0) * k,
					0.5, Vector3(0, 3.0, 0), 3.0, {"r": 0.15 * k})
			pool.shoot("spark_fire", at, n, d, spread, Vector2(speed * 0.8, speed * 2.2), Vector2(0.03, 0.06), 0.65,
					Vector3(0, -5.0, 0), 1.5)
			pool.light(at, Color(1.0, 0.6, 0.25), 3.0, 0.2, 4.0)
			if not g.is_empty():
				pool.play("ring", _flat(g), 0.32, 0.4 * k, 1.8 * k, FIRE, FIRE_HOT)
				pool.mark("scorch", g.pos, g.normal, 1.3 * k, 6.0)
		"water":
			pool.shoot("drop", at, int(n * 1.3), d, spread, Vector2(speed * 0.6, speed * 1.8), Vector2(0.1, 0.2) * k,
					0.75, Vector3(0, -14.0, 0), 0.5, {"r": 0.1 * k})
			pool.shoot("foam", at, int(n * 0.45), d, spread * 1.2, Vector2(speed * 0.2, speed * 0.6), Vector2(0.35, 0.7) * k,
					0.5, Vector3.ZERO, 2.0, {"r": 0.15 * k})
			if not g.is_empty():
				pool.play("crown", _flat(g), 0.55, 0.6 * k, 1.3 * k, WATER, FOAM, ToonFx.band_mesh(1.0, 1.5, 1.0))
				pool.play("ring", _flat(g), 0.7, 0.3 * k, 1.9 * k, FOAM, Color(0.55, 0.85, 1.0))
				pool.mark("wet", g.pos, g.normal, 1.6 * k, 4.0)
			else:
				pool.play("flash", up, 0.14, 0.4 * k, 1.0 * k, WATER, FOAM)
		"steam":
			pool.shoot("puff_steam", at, n, d, spread, Vector2(speed * 0.3, speed), Vector2(0.4, 0.9) * k, 1.1,
					Vector3(0, 1.8, 0), 2.0, {"r": 0.3 * k})
			pool.play("ring", Transform3D(Basis.IDENTITY, at), 0.4, 0.3 * k, 1.6 * k, FOAM, Color(0.75, 0.82, 0.9))
		"ice":
			var big := n >= 24
			var sk := 1.7 if big else 1.0
			pool.play("flash", up, 0.14, 0.4 * k * sk, 1.2 * k * sk, ICE, Color(0.9, 0.98, 1.0))
			pool.shoot("shard", at, int(n * 0.9), d, spread, Vector2(speed * 0.7, speed * (2.2 if big else 1.6)),
					Vector2(0.16, 0.34) * sk * k, 0.95, Vector3(0, -12.0, 0), 0.5, {"r": (0.7 if big else 0.1) * k, "ang": 600.0})
			pool.shoot("puff_frost", at, int(n * (0.45 if big else 0.25)), d, spread, Vector2(speed * 0.2, speed * 0.6), Vector2(0.3, 0.6) * sk * k,
					0.55, Vector3.ZERO, 2.0, {"r": (0.5 if big else 0.1) * k})
			pool.shoot("star", at, int(n * 0.6), d, spread, Vector2(speed * 0.4, speed * 1.2), Vector2(0.18, 0.32), 0.7,
					Vector3(0, -2.0, 0), 2.0, {"r": (0.6 if big else 0.15) * k})
			if not g.is_empty():
				pool.mark("frost", g.pos, g.normal, (2.2 if big else 1.2) * k, 6.0)
		"air":
			pool.play("swirl", up, 0.36, 0.6 * k, 1.9 * k, AIR, Color(0.5, 0.75, 1.0))
			pool.play("swirl", up, 0.28, 0.4 * k, 1.2 * k, AIR, Color(0.5, 0.75, 1.0))
			pool.shoot("spark_line", at, n, d, spread, Vector2(speed * 1.5, speed * 3.0), Vector2(0.045, 0.07), 0.32,
					Vector3.ZERO, speed * 3.0)
			pool.shoot("puff_air", at, int(n * 0.4), d, spread, Vector2(speed * 0.3, speed * 0.8), Vector2(0.2, 0.45) * k,
					0.4, Vector3.ZERO, 3.0)
			if not g.is_empty():
				_dust(pool, g, n, k)
		"stone":
			pool.shoot("chunk", at, n, d, spread, Vector2(speed * 0.7, speed * 1.5), Vector2(0.12, 0.3) * k, 1.1,
					Vector3(0, -16.0, 0), 0.3, {"r": 0.15 * k, "ang": 400.0})
			pool.shoot("puff_dust", at, int(n * 0.7), d, spread, Vector2(speed * 0.2, speed * 0.6), Vector2(0.55, 1.1) * k,
					1.0, Vector3(0, 0.3, 0), 3.0, {"r": 0.2 * k})
			if not g.is_empty():
				_dust(pool, g, n, k)
				pool.mark("cracks", g.pos, g.normal, 1.8 * k, 7.0)
		"lightning":
			pool.play("flash", up, 0.14, 0.4 * k, 1.3 * k, ELEC, Color(0.85, 0.92, 1.0))
			pool.shoot("spark_elec", at, int(n * 1.6), d, spread, Vector2(speed * 1.0, speed * 3.0), Vector2(0.025, 0.045),
					0.3, Vector3(0, -6.0, 0), 2.0)
			pool.light(at, Color(0.6, 0.75, 1.0), 2.5, 0.15, 4.0)
		_:
			pool.shoot("puff_air", at, n, d, spread, Vector2(speed * 0.5, speed), Vector2(0.2, 0.4) * k, 0.5)


static func _dust(pool: ToonFxPool, g: Dictionary, n: int, k: float) -> void:
	pool.play("ring", _flat(g), 0.45, 0.3 * k, 1.7 * k, DUST, DUST_LIGHT)
	pool.shoot("puff_dust", (g.pos as Vector3) + (g.normal as Vector3) * 0.15, int(n * 0.6), g.normal, 80.0,
			Vector2(1.5, 3.5) * k, Vector2(0.3, 0.6) * k, 0.7, Vector3.ZERO, 5.0, {"flat": 0.85, "r": 0.3 * k})


## The ground just under (or before) a burst at `at` going `d`: {pos, normal}, or {} in the air.
static func _ground(pool: ToonFxPool, at: Vector3, d: Vector3) -> Dictionary:
	var w := pool.get_world_3d()
	if w == null:
		return {}
	var down := -d if d.y < -0.2 else Vector3.DOWN
	var q := PhysicsRayQueryParameters3D.create(at - down * 0.3, at + down * 0.75, 1)
	var h := w.direct_space_state.intersect_ray(q)
	if h.is_empty() or (h.normal as Vector3).y < 0.55:
		return {}
	return {"pos": h.position, "normal": h.normal}


static func _flat(g: Dictionary) -> Transform3D:
	var n: Vector3 = g.normal
	var x := n.cross(Vector3.FORWARD).normalized()
	return Transform3D(Basis(x, n, x.cross(n)), (g.pos as Vector3) + n * 0.04)


## A blast over a cone (from `at` along `dir`, `deg` wide, `reach` m) or, at 360, a ring round `at`.
static func blast(at: Vector3, dir: Vector3, deg: float, reach: float, kind: String) -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var n := clampi(int(deg / 4.0 * reach / 3.0), 16, 48)
	var ring := deg >= 359.0
	var d := Vector3.UP if ring else dir.normalized()
	var half := 180.0 if ring else deg * 0.5
	# the speed that carries a bit `reach` m against its slowing (damping a): v = sqrt(2 a reach)
	var v := reach * 3.0
	var damp := v * v / (2.0 * reach)
	var opt := {"flat": 0.9} if ring else {}
	var foot := FormEffects.ground_at(pool, at) if ring else at
	var flat := Transform3D(Basis.IDENTITY, foot + Vector3.UP * 0.05)
	match kind:
		"fire":
			pool.shoot("puff_fire", at, n, d, half, Vector2(v * 0.6, v), Vector2(0.4, 0.85), 0.55, Vector3(0, 2.0, 0), damp, opt)
			pool.shoot("spark_fire", at, n, d, half, Vector2(v * 0.8, v * 1.4), Vector2(0.03, 0.06), 0.6, Vector3(0, -3, 0), damp * 0.6, opt)
			pool.light(at, Color(1.0, 0.6, 0.25), 3.0, 0.25, reach + 2.0)
			if ring:
				pool.play("ring", flat, 0.4, 0.5, reach, FIRE, FIRE_HOT)
		"water":
			pool.shoot("drop", at, n * 2, d, half, Vector2(v * 0.6, v * 1.1), Vector2(0.08, 0.16), 0.7, Vector3(0, -10, 0), damp * 0.7, opt)
			pool.shoot("foam", at, n, d, half, Vector2(v * 0.5, v), Vector2(0.3, 0.6), 0.5, Vector3.ZERO, damp, opt)
			if ring:
				pool.play("ring", flat, 0.6, 0.5, reach, FOAM, WATER)
		"air":
			pool.shoot("spark_line", at, n * 2, d, half, Vector2(v * 1.2, v * 1.8), Vector2(0.035, 0.05), 0.35, Vector3.ZERO, damp, opt)
			pool.shoot("puff_air", at, n, d, half, Vector2(v * 0.5, v), Vector2(0.25, 0.5), 0.45, Vector3.ZERO, damp, opt)
			pool.play("swirl", Transform3D(Basis.IDENTITY, at + (Vector3.ZERO if ring else d * reach * 0.4)), 0.4, 0.6,
					reach * (1.0 if ring else 0.6), AIR, Color(0.6, 0.82, 1.0))
			if ring:
				pool.play("ring", flat, 0.45, 0.5, reach, AIR, DUST_LIGHT)
		"stone":
			pool.shoot("chunk", at, n, d, half, Vector2(v * 0.4, v * 0.8), Vector2(0.1, 0.25), 1.0, Vector3(0, -14, 0), damp * 0.4,
					opt.merged({"ang": 400.0}))
			pool.shoot("puff_dust", at, n, d, half, Vector2(v * 0.4, v * 0.9), Vector2(0.5, 1.0), 0.9, Vector3.ZERO, damp, opt)
			if ring:
				pool.play("ring", flat, 0.5, 0.5, reach, DUST, DUST_LIGHT)
				pool.mark("cracks", foot, Vector3.UP, reach * 0.9, 7.0)
		_:
			burst(at, kind, n, d, half, v, 0.45)


## The dust and cracks along the foot of an earth wall coming up at `at` (its foot's middle), `size` (x across), facing
## `way`; `matter` "ice" for an ice wall (frost and sparkles in place of dust).
static func rise(at: Vector3, size: Vector3, way: Vector3, matter := "earth") -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var x := Vector3.UP.cross(way).normalized()
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	var b := Basis(x, Vector3.UP, x.cross(Vector3.UP))
	var ice := matter in ["ice", "snow"]
	pool.shoot("puff_frost" if ice else "puff_dust", at + Vector3.UP * 0.2, 24, Vector3.UP, 70.0, Vector2(0.8, 2.4),
			Vector2(0.4, 0.9), 0.9, Vector3.ZERO, 2.5, {"box": Vector3(size.x * 0.5, 0.1, size.z * 0.6 + 0.2), "basis": b})
	pool.shoot("shard" if ice else "chunk", at + Vector3.UP * 0.2, 16, Vector3.UP, 45.0, Vector2(2.0, 5.0),
			Vector2(0.08, 0.2), 1.0, Vector3(0, -14, 0), 0.0, {"box": Vector3(size.x * 0.5, 0.1, size.z * 0.5), "basis": b, "ang": 400.0})
	var marks := maxi(1, int(size.x / 1.6))
	for i in marks:
		var off := (float(i) + 0.5) / marks - 0.5
		pool.mark("frost" if ice else "cracks", at + x * off * size.x, Vector3.UP, 1.9, 7.0)


## A wall breaking apart at `at` (its foot's middle), `size` (x across, y up, z through), facing `way`: an ice wall into
## spinning crystal shards, frost and sparkles flung out of its whole face; an earth wall ("earth") into rock chunks and
## dust (for FormRaised's crumble or a shattering hit to call).
static func shatter(at: Vector3, size: Vector3, way: Vector3, matter := "ice") -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var x := Vector3.UP.cross(way).normalized()
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	var b := Basis(x, Vector3.UP, x.cross(Vector3.UP))
	var mid := at + Vector3.UP * size.y * 0.5
	var box := {"box": Vector3(size.x * 0.5, size.y * 0.45, size.z * 0.5), "basis": b, "ang": 500.0}
	var ice := matter in ["ice", "snow"]
	pool.shoot("shard" if ice else "chunk", mid, 32, Vector3.UP, 180.0, Vector2(2.5, 6.5), Vector2(0.2, 0.45), 1.1,
			Vector3(0, -12.0, 0), 0.8, box)
	pool.shoot("puff_frost" if ice else "puff_dust", mid, 24, Vector3.UP, 180.0, Vector2(0.8, 2.2), Vector2(0.5, 1.0), 0.8,
			Vector3.ZERO, 2.5, box)
	if ice:
		pool.shoot("star", mid, 20, Vector3.UP, 180.0, Vector2(1.0, 3.5), Vector2(0.2, 0.35), 0.8, Vector3(0, -3.0, 0), 1.5, box)
		pool.play("flash", Transform3D(Basis.IDENTITY, mid), 0.16, 0.8, 2.6, ICE, Color(0.9, 0.98, 1.0))
	pool.mark("frost" if ice else "cracks", at, Vector3.UP, size.x * 0.9, 6.0)


## Lightning from `a` to `b`: forks with a white core in a blue sheath that flicker and go, a flash and sparks where it
## strikes, a smaller flash at the hand, a flash of light.
static func lightning(a: Vector3, b: Vector3) -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	pool.lightning(a, b, 0.26, 3)
	pool.play("flash", Transform3D(Basis.IDENTITY, b), 0.2, 0.6, 1.8, ELEC, Color(0.85, 0.92, 1.0))
	pool.play("flash", Transform3D(Basis.IDENTITY, a), 0.12, 0.3, 0.8, ELEC, Color(0.85, 0.92, 1.0))
	var back := (a - b).normalized()
	pool.shoot("spark_elec", b, 26, back, 75.0, Vector2(3.0, 9.0), Vector2(0.025, 0.045), 0.35, Vector3(0, -8.0, 0), 2.0)
	pool.light((a + b) * 0.5, Color(0.65, 0.78, 1.0), 4.0, 0.2, a.distance_to(b) * 0.6 + 4.0)
	var g := _ground(pool, b, -back)
	if not g.is_empty():
		pool.mark("scorch", g.pos, g.normal, 1.0, 4.0)
		pool.play("ring", _flat(g), 0.25, 0.3, 1.4, ELEC, Color(0.85, 0.92, 1.0))


## Every effect played once 3 m before `cam`, a few mm big, for WARM_FRAMES frames (each shader, particle program and
## pipeline compiled while the level loads: measured 2026-10-05, the first fire wall, tornado and bubble each froze a frame
## for 1 to 3.4 s on this Mac without it). Every burst, blast, body, trail, emitter, zone look, shape, mark and the lightning;
## then they are taken away (the pool keeps its emitters for the match). Call once the level stands; it runs on by itself.
const WARM_FRAMES := 6

static func warm_up(cam: Camera3D) -> void:
	if cam == null or not cam.is_inside_tree() or not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var tree := cam.get_tree()
	var at := cam.global_transform * Vector3(0.0, 0.0, -3.0)
	var xf := Transform3D(Basis.IDENTITY, at)
	var made: Array[Node] = []
	var holder := Node3D.new()
	holder.name = "BendLooksWarm"
	pool.add_child(holder)
	holder.global_transform = xf.scaled_local(Vector3.ONE * 0.01)
	made.append(holder)
	for k in KINDS:
		burst(at, k, 2, Vector3.UP, 30.0, 0.1, 0.01)
		blast(at, Vector3.FORWARD, 60.0, 0.05, k)
		blast(at, Vector3.FORWARD, 360.0, 0.05, k)
		for long in [false, true]:
			var body := Node3D.new()
			holder.add_child(body)
			bolt_body(body, k, 0.2, long)
		var t := trail(holder, k, 0.01)
		if t != null:
			made.append(t)
			for c in t.get_children():
				if c is ToonRibbon:
					(c as ToonRibbon).prime(at, at + Vector3.LEFT * 0.05)
	burst(at, "steam", 2, Vector3.UP, 30.0, 0.1, 0.01)
	for e in ["fire", "water", "smoke", "dust", "steam", "ice", "embers", "sparkle", "debris", "foam", "lightning", "air"]:
		emitter(holder, e, Vector3.ONE * 0.1, 2, 0.2, 0.1, 0.01)
	for z in ["bubble", "air_shield", "water_wall", "fire_wall", "burn", "ice_patch", "smoke", "tornado", "vacuum"]:
		var bz := BendZone.new()
		bz.kind = z
		bz.owner_node = holder
		bz.life_s = 0.2
		bz.size = Vector3(1.0, 1.0, 0.3)
		bz.radius = 0.5
		holder.add_child(bz)
		bz.set_physics_process(false)          # (a look only: it neither burns, lifts nor ends anyone)
		bz._look()
	for m in ["scorch", "cracks", "frost", "wet"]:
		pool.mark(m, at, Vector3.UP, 0.01, 0.2)
	for sh in ["flash", "ring", "swirl"]:
		pool.play(sh, xf, 0.2, 0.01, 0.01)
	pool.play("crown", xf, 0.2, 0.01, 0.01, Color.WHITE, Color.WHITE, ToonFx.band_mesh(1.0, 1.5, 1.0))
	pool.lightning(at, at + Vector3.UP * 0.05, 0.15, 1)
	for i in WARM_FRAMES:
		await tree.process_frame
	for t in made.slice(1):
		stop_trail(t as GPUParticles3D)
	if is_instance_valid(holder):
		holder.queue_free()


static func _scene() -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.current_scene if ml != null else null
