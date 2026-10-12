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
##   lightning  forks with a white core in a blue sheath that flicker, sparks and a flash where it strikes; with SB_BOLT the
##              same forks in Spellbreak's lightning shading (a white-hot core, a lavender sheath, a blue-violet fringe that
##              crackles and erodes), short forks crackling off the hands at the charge and the release and at the strike,
##              the sparks and stars round it in the same violet (ToonFx spark_sb, star_sb)
## Cheap: ToonFxPool reuses every emitter, shape and trail (caps per kind), materials and meshes are shared; no node is
## made per hit once warm (a bolt's body is made with the bolt). Nothing is drawn headless.
## The sounds are the ring's own (BendSounds: synthesized for each element, tools/sfx/bend/): sound() hands them on.
## rise(at, size, way): the dust and cracks along the foot of an earth wall coming up (for FormRaised's raise to call).
## warm_up(cam): every effect played once out of sight at the level's load (their shaders compiled then, not at a first hit).
## ROUND 4 (LOOKS; data/bending/fx_looks.json, ToonFx.looks; the same looks wherever they are cast, the open world's and the
## duel's too; no hitbox, speed, damage or zone radius changes):
##   flames      soft-edged and licking (toon_flame), 7-9 tongues on a fireball each its own phase, a soft additive glow under
##               every flame cluster ("flame_glow")
##   the Kick    three rows of tongues (a bright crest, a body, a low trail; 1.0-1.4 m deep) whose visible top is the height a
##               jump clears (wave_top: the bolt's miss_above_m), a bright lip along the deck under the crest (a ToonRibbon
##               laid across), sparks thrown ahead, scorches left along its path (2 s), embers spilling past the lip
##   shadows     every bolt but air and lightning casts its own shadow from a shadow-only core (_shadow); under an air bolt
##               within 1.5 m of the deck a thin line of dust rises (AirDust)
##   at range    a bolt's drawn core grows with its distance from the camera past 14 m, up to x2.2 (instance range_on)
##   puffs       a hit's burst on a body stays within 0.6 of the body's height in count and size (burst_cap), and the puffs
##               between the camera and the struck body are drawn at half (the pool's occl)

const KINDS := ["stone", "ice", "water", "fire", "air", "lightning"]
const FIRE := Color(1.0, 0.45, 0.06)
const FIRE_HOT := Color(1.0, 0.82, 0.25)
const WATER := Color(0.2, 0.6, 1.0)
const FOAM := Color(0.92, 0.98, 1.0)
const ICE := Color(0.6, 0.88, 1.0)
const AIR := Color(0.85, 0.95, 1.0)
const DUST := Color(0.72, 0.6, 0.45)
const DUST_LIGHT := Color(0.88, 0.78, 0.6)
const ELEC := Color(0.45, 0.68, 1.0)


## Round 4: a test may build the looks headless too (tests/bending/test_r4_looks.gd: what is drawn, counted without drawing).
static var build_headless := false


static func live() -> bool:
	return build_headless or DisplayServer.get_name() != "headless"


## A cast or a hit of `kind` heard at `at` (BendSounds.bend: the move's own sound, its jitter on BendSounds' dice).
static func sound(kind: String, what: String, at: Vector3, db := 0.0) -> void:
	BendSounds.bend(kind, what, at, db)


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
## A bolt's body: under `parent`, its forward -Z (a long one, a shard or a slice, drawn along it). `shape` (a thrown one's,
## BendThrow): "disc" (stone: a flat faceted rock standing in the flight's plane, its rim chipped so a turn reads; fire: a
## wheel of flame tongues round a hot core), "spear" (ice: a long crystal shaft behind a heavy faceted head and a glint at
## its point; stone: a long rock spike), else the kind's own body.
static func bolt_body(parent: Node3D, kind: String, r: float, long := false, shape := "ball") -> void:
	if shape == "disc" and kind in ["stone", "fire"]:
		_disc_body(parent, kind, r)
		return
	if shape == "crescent":
		_crescent_body(parent, kind, r)
		return
	if shape == "spear" and kind in ["stone", "ice", "air"]:
		_spear_body(parent, kind, r)
		return
	if kind == "air" and shape in ["slice", "pull"]:
		_air_blade(parent, r, shape)
		return
	match kind:
		"fire":
			_fire_body(parent, r, long)
		"water":
			var mi := _mesh(parent, ToonFx.sphere(16), ToonFx.mat("water"))
			mi.scale = Vector3(r * 1.3, r * 1.3, r * (2.6 if long else 1.8))
			mi.position = Vector3(0.0, 0.0, r * 0.35)
			mi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
			_core(mi)
			_shadow(parent, "water", r, Vector3(1.0, 1.0, 2.0 if long else 1.4), mi.position)
		"ice":
			var mi := _mesh(parent, ToonFx.shard_mesh(1.0, 0.2, ToonFx.vis_rng.randi() % 4), ToonFx.mat("ice"))
			var l := r * (11.0 if long else 5.5)
			mi.scale = Vector3(r * 7.0, r * 7.0, l)
			_core(mi)
			_shadow(parent, "ice", r, Vector3(1.0, 1.0, l / maxf(r, 1e-3) * 0.3), Vector3(0.0, 0.0, -l * 0.15))
			if live():
				var g := _mesh(parent, ToonFx.quad(), ToonFx.mat("star_still"))
				g.position = Vector3(0.0, 0.0, -l * 0.72)
				g.scale = Vector3.ONE * maxf(r * 4.5, 0.45)
		"air":
			if long:
				var mi := _mesh(parent, ToonFx.arc_mesh(1.0, 0.42, 2.3), ToonFx.mat("wind_arc"))
				mi.scale = Vector3.ONE * r * 5.0
				_core(mi)
			else:
				for i in 3:
					var b := _mesh(parent, ToonFx.band_mesh(1.0, 0.85, 0.5), ToonFx.mat("wind_band_fast"))
					b.scale = Vector3.ONE * r * (1.25 - i * 0.18)
					b.rotation = Vector3(0.5 + i * 0.9, i * 1.3, 0.35 * i)
					b.position = -b.basis.y.normalized() * 0.25 * b.scale.y
					b.set_instance_shader_parameter(&"seed", i * 0.31)
					_core(b)
				var core := _mesh(parent, ToonFx.sphere(12), ToonFx.mat("bubble"))
				core.scale = Vector3.ONE * r * 0.55
				_core(core)
			_air_dust(parent)
		"lightning":
			var o := _mesh(parent, ToonFx.quad(), ToonFx.mat("orb"))
			o.scale = Vector3.ONE * r * 3.0
			o.set_instance_shader_parameter(&"tint", ELEC)
			o.set_instance_shader_parameter(&"tint2", Color(0.8, 0.9, 1.0))
			_core(o)
		_:
			var mi := MeshInstance3D.new()
			mi.name = "Body"
			# (the effects' own dice: a stone's body never moves the game's rolls)
			var sd := ToonFx.vis_rng.randi() % 50
			mi.mesh = FormModels.ball_mesh(r, sd) if not long else FormModels.spike_mesh(r, r * 7.0, sd, 0.0)
			if long:
				mi.rotation.x = -PI / 2.0
			mi.material_override = ToonFx.mat("rock")
			parent.add_child(mi)
			_core(mi)
			_shadow(parent, "stone", r, Vector3(1.0, 1.0, 3.5) if long else Vector3.ONE, Vector3(0.0, 0.0, -r * 3.0) if long else Vector3.ZERO)


## A thrown disc (BendThrow's spinning flight turns its parent about local X: the disc stands in the YZ plane, so it turns
## like a wheel, a tomahawk end over end). Stone: a lens of faceted rock, its rim chipped (one deep notch), a pale band of
## grit round its edge. Fire: a white-hot core and eight flame tongues fanned round it in the same plane, swept back a
## little as they turn (one MultiMesh), a warm light.
static func _disc_body(parent: Node3D, kind: String, r: float) -> void:
	if kind == "stone":
		var mi := _mesh(parent, disc_mesh(ToonFx.vis_rng.randi() % 6), ToonFx.mat("rock"))
		mi.scale = Vector3.ONE * r * 1.45
		_core(mi)
		_shadow(parent, "stone", r, Vector3(0.3, 1.45, 1.45), Vector3.ZERO)       # (round 4: its shadow from a core, not the scaled rock)
		return
	var o := _mesh(parent, ToonFx.quad(), ToonFx.mat("flame_orb"))
	o.scale = Vector3.ONE * r * 1.9
	o.set_instance_shader_parameter(&"tint", Color(0.95, 0.22, 0.04))
	o.set_instance_shader_parameter(&"tint2", Color(1.0, 0.7, 0.12))
	o.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	_core(o)
	_shadow(parent, "fire", r, Vector3(0.4, 1.2, 1.2), Vector3.ZERO)
	_glow(parent, Vector3.ONE * r * 5.5, Vector3.ZERO)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ToonFx.quad_base()
	var n := 8
	mm.instance_count = n
	for i in n:
		var a := TAU * i / n
		var out := Vector3(0.0, cos(a), sin(a))                         # (round in the disc's plane, YZ)
		var swept := out.rotated(Vector3.RIGHT, 0.45).normalized()      # (swept back against the turn)
		var side := Vector3.RIGHT.cross(swept).normalized()
		var l := r * (2.3 if i % 2 == 0 else 1.6)
		var basis := Basis(side * r * 1.15, swept * l, Vector3.RIGHT)
		mm.set_instance_transform(i, Transform3D(basis, out * r * 0.45))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Wheel"
	mmi.multimesh = mm
	mmi.material_override = ToonFx.mat("flame")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	mmi.extra_cull_margin = r * 4.0
	parent.add_child(mmi)
	if live():
		var l2 := OmniLight3D.new()
		l2.light_color = Color(1.0, 0.58, 0.22)
		l2.light_energy = 1.3
		l2.omni_range = 3.0 + r * 2.0
		l2.shadow_enabled = false
		parent.add_child(l2)


## The High Kick's crescent (round 2; BendThrow, shape "crescent", point first: -Z along its flight): a bold arc of flame
## standing across its line, its horns swept back, a hot core at its middle and a warm light.
static func _crescent_body(parent: Node3D, kind: String, r: float) -> void:
	var w := maxf(r, 0.4)
	var arc := _mesh(parent, ToonFx.arc_mesh(1.0, 0.36, 2.5), ToonFx.mat("flame_strip" if kind == "fire" else "wind_arc"))
	arc.scale = Vector3.ONE * w * 1.25
	if kind == "fire":
		_shadow(parent, "fire", w, Vector3(1.6, 0.35, 0.6), Vector3.ZERO)
		_glow(parent, Vector3(w * 3.2, w * 2.0, 1.0), Vector3.ZERO)
	else:
		_air_dust(parent)
	# (flat across its flight, tipped up a little: the kick's sweep; fire's High Kick stood up into a rising sweep, the move
	# review 2026-10-12: the flame went out flat, not like an uppercut)
	arc.rotation = Vector3(1.05 if kind == "fire" else 0.35, 0.0, 0.0)
	arc.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	var o := _mesh(parent, ToonFx.quad(), ToonFx.mat("flame_orb" if kind == "fire" else "orb"))
	o.scale = Vector3.ONE * w * 0.9
	_core(o)
	o.set_instance_shader_parameter(&"tint", Color(0.95, 0.22, 0.04) if kind == "fire" else AIR)
	o.set_instance_shader_parameter(&"tint2", Color(1.0, 0.7, 0.12) if kind == "fire" else Color(0.6, 0.8, 1.0))
	o.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	if live() and kind == "fire":
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.58, 0.22)
		l.light_energy = 1.3
		l.omni_range = 3.5
		l.shadow_enabled = false
		parent.add_child(l)


## Air's Slice and Pull told apart from the Gust's pale wave (the move review 2026-10-12: all three a thin white streak): the
## Slice a wider, thinner blade with a deep blue inked edge, flat across its flight; the Pull a teal hook whose curve faces back
## to the caster (it draws him in), a second smaller hook inside it. Small as the Gust (the owner, 2026-10-11, hated a big air
## wave): shape and colour, not size.
static func _air_blade(parent: Node3D, r: float, shape: String) -> void:
	if shape == "slice":
		var arc := _mesh(parent, ToonFx.arc_mesh(1.0, 0.28, 2.6), ToonFx.mat("wind_arc_slice"))
		arc.scale = Vector3.ONE * r * 6.5
		_core(arc)
	else:
		for i in 2:
			var hook := _mesh(parent, ToonFx.arc_mesh(1.0, 0.34, 2.2), ToonFx.mat("wind_arc_pull"))
			hook.scale = Vector3.ONE * r * (5.0 - 1.8 * i)
			hook.rotation = Vector3(0.0, PI, 0.0)            # (its bulge toward the caster: a hook pulling back)
			hook.position = Vector3(0.0, 0.0, r * 1.2 * i)
			hook.set_instance_shader_parameter(&"seed", 0.37 * i)
			_core(hook)
	_air_dust(parent)


## A thrown spear (its point -Z, along its flight). Ice: a long thin crystal shaft and a heavy faceted head on it, a glint at
## the point. Stone: a long rock spike. Air (the Air Lance, the Gust held long): a long pale shaft of wind with a sharp head,
## bands of wind turning round it, its dust under it.
static func _spear_body(parent: Node3D, kind: String, r: float) -> void:
	if kind == "air":
		var sa := ToonFx.vis_rng.randi() % 4
		var shaft_a := _mesh(parent, ToonFx.shard_mesh(1.0, 0.2, sa, 5), ToonFx.mat("bubble"))
		shaft_a.scale = Vector3(r * 2.0, r * 2.0, r * 16.0)
		shaft_a.position = Vector3(0.0, 0.0, r * 3.5)
		var head_a := _mesh(parent, ToonFx.shard_mesh(1.0, 0.3, (sa + 1) % 4, 6), ToonFx.mat("bubble"))
		head_a.scale = Vector3(r * 3.6, r * 3.6, r * 6.0)
		head_a.position = Vector3(0.0, 0.0, -r * 4.2)
		_core(shaft_a)
		_core(head_a)
		for i in 2:
			var band := _mesh(parent, ToonFx.band_mesh(1.0, 0.85, 0.5), ToonFx.mat("wind_band_fast"))
			band.scale = Vector3.ONE * r * 3.2
			band.rotation = Vector3(PI / 2.0, float(i) * 1.3, 0.0)
			band.position = Vector3(0.0, 0.0, -r * (1.0 + 3.5 * float(i)))
			band.set_instance_shader_parameter(&"seed", float(i) * 0.31)
		_air_dust(parent)
		return
	if kind == "stone":
		var mi := MeshInstance3D.new()
		mi.name = "Body"
		mi.mesh = FormModels.spike_mesh(r, r * 9.0, ToonFx.vis_rng.randi() % 50, 0.0)
		mi.rotation.x = -PI / 2.0
		mi.position = Vector3(0.0, 0.0, r * 4.0)
		mi.material_override = ToonFx.mat("rock")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		_core(mi)
		_shadow(parent, "stone", r, Vector3(1.0, 1.0, 4.5), Vector3.ZERO)
		return
	var sd := ToonFx.vis_rng.randi() % 4
	var shaft := _mesh(parent, ToonFx.shard_mesh(1.0, 0.2, sd, 5), ToonFx.mat("ice"))
	shaft.scale = Vector3(r * 2.6, r * 2.6, r * 15.0)
	shaft.position = Vector3(0.0, 0.0, r * 3.5)
	var head := _mesh(parent, ToonFx.shard_mesh(1.0, 0.3, (sd + 1) % 4, 6), ToonFx.mat("ice"))
	head.scale = Vector3(r * 5.5, r * 5.5, r * 6.5)
	head.position = Vector3(0.0, 0.0, -r * 4.2)
	_core(shaft)
	_core(head)
	_shadow(parent, "ice", r, Vector3(0.9, 0.9, 6.0), Vector3(0.0, 0.0, -r * 1.0))
	if live():
		var g := _mesh(parent, ToonFx.quad(), ToonFx.mat("star_still"))
		g.position = Vector3(0.0, 0.0, -r * 8.6)
		g.scale = Vector3.ONE * maxf(r * 4.0, 0.4)


static var _discs := {}

## A stone disc 2 m across in local YZ (its axis X), a lens of rock facets: nine uneven rim points, the faces between its
## rim and its two hubs flat-shaded, one notch cut in its rim (a turn reads). Its own dice (`seed`), cached.
static func disc_mesh(seed := 0) -> Mesh:
	if _discs.has(seed):
		return _discs[seed]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 6151 + 29
	var n := 9
	var notch := rng.randi() % n
	var rim: Array[Vector3] = []
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.12, 0.12)
		var rr := rng.randf_range(0.86, 1.06) * (0.68 if i == notch else 1.0)
		rim.append(Vector3(rng.randf_range(-0.05, 0.05), cos(a) * rr, sin(a) * rr))
	var hub_a := Vector3(0.3, rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08))
	var hub_b := Vector3(-0.3, rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var p := rim[i]
		var q := rim[(i + 1) % n]
		# (each rim edge a little thick: an inner ring 0.55 out on each face)
		var pa := p * 0.62 + Vector3(0.17, 0.0, 0.0)
		var qa := q * 0.62 + Vector3(0.17, 0.0, 0.0)
		var pb := p * 0.62 - Vector3(0.17, 0.0, 0.0)
		var qb := q * 0.62 - Vector3(0.17, 0.0, 0.0)
		var tris: Array[Vector3] = [hub_a, pa, qa, pa, p, q, pa, q, qa, hub_b, qb, pb, pb, q, p, pb, qb, q]
		for k in range(0, tris.size(), 3):
			# (both windings: whichever way the engine fronts a face, the outward one shows)
			for v: Vector3 in [tris[k], tris[k + 1], tris[k + 2], tris[k], tris[k + 2], tris[k + 1]]:
				st.add_vertex(v)
	st.generate_normals()
	var m := st.commit()
	_discs[seed] = m
	return m


static func _mesh(parent: Node3D, m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A bolt's drawn core (round 4): it grows at range in its shader (range_on; ToonFx.range_scale), and draws no shadow of
## its own (a grown core's shadow would grow too: its shadow is _shadow's).
static func _core(g: GeometryInstance3D) -> void:
	g.set_instance_shader_parameter(&"range_on", 1.0)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A bolt's own shadow (round 4: every bolt but air and lightning; no decal, no marker): a shadow-only ellipsoid the size of
## its core (`r` x the kind's share, ToonFx.looks shadow, stretched by `stretch`) at `at` under `parent`. Named "Shadow".
static func _shadow(parent: Node3D, kind: String, r: float, stretch: Vector3, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Shadow"
	mi.mesh = ToonFx.sphere(10)
	mi.material_override = ToonFx.shadow_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mi.scale = stretch * r * float(ToonFx.looks("shadow").get(kind, 1.0))
	mi.position = at
	parent.add_child(mi)
	return mi


## The soft additive glow under a flame cluster (round 4, ToonFx "flame_glow"): `size` its width and height, at `at`.
static func _glow(parent: Node3D, size: Vector3, at: Vector3) -> MeshInstance3D:
	if not live():
		return null
	var g := _mesh(parent, ToonFx.quad(), ToonFx.mat("flame_glow"))
	g.name = "Glow"
	g.scale = Vector3(size.x, size.y, 1.0)
	g.position = at
	g.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	return g


## The fireball's tongues (round 4): ToonFx.looks flame.tongues of them fanned round the orb, licking back (+Z), each its
## own length and lean (its phase is its instance's own in the shader). Their transforms under the body.
static func fire_tongues(r: float, long := false) -> Array[Transform3D]:
	var n := clampi(int(ToonFx.looks("flame").get("tongues", 8)), 1, 16)
	var k := 1.6 if long else 1.0
	var out: Array[Transform3D] = []
	for i in n:
		var a := TAU * float(i) / float(n) + ToonFx.vis_rng.randf_range(-0.25, 0.25)
		var ring := 0.0 if i == 0 else 0.36
		var out_dir := Vector3(cos(a), sin(a), 0.0)
		var l := r * (4.8 if i == 0 else ToonFx.vis_rng.randf_range(2.8, 4.1)) * k
		var w := r * (2.3 if i == 0 else ToonFx.vis_rng.randf_range(1.45, 1.95))
		var axis := (Vector3.BACK + out_dir * (0.0 if i == 0 else 0.32)).normalized()
		var side := axis.cross(Vector3.UP)
		side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
		out.append(Transform3D(Basis(side * w, axis * l, side.cross(axis).normalized()), out_dir * r * ring + Vector3(0.0, 0.0, -r * 0.5)))
	return out


## Under an air bolt (round 4): a thin line of dust rising off the deck while it flies within ToonFx.looks air_dust.over_m of
## it (AirDust; the pool's puff_dust). Live only.
static func _air_dust(parent: Node3D) -> void:
	if not live():
		return
	var d := AirDust.new()
	d.name = "AirDust"
	parent.add_child(d)


## A fireball: the boiling orb and its flame tongues licking back from it (round 4: ToonFx.looks flame.tongues, 7-9, smaller,
## fanned round the orb and each its own phase; one MultiMesh), a soft glow under them, a warm light on a big one, its
## shadow from a shadow-only core.
static func _fire_body(parent: Node3D, r: float, long: bool) -> void:
	var o := _mesh(parent, ToonFx.quad(), ToonFx.mat("flame_orb"))
	o.scale = Vector3.ONE * r * 2.5
	o.set_instance_shader_parameter(&"tint", Color(0.95, 0.22, 0.04))
	o.set_instance_shader_parameter(&"tint2", Color(1.0, 0.62, 0.08))
	o.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	_core(o)
	_shadow(parent, "fire", r, Vector3.ONE, Vector3.ZERO)
	_glow(parent, Vector3.ONE * r * (7.0 if long else 6.0), Vector3(0.0, 0.0, r * 1.2))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ToonFx.quad_base()
	var tongues := fire_tongues(r, long)
	mm.instance_count = tongues.size()
	for i in tongues.size():
		mm.set_instance_transform(i, tongues[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tongues"
	mmi.multimesh = mm
	mmi.material_override = ToonFx.mat("flame")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	mmi.extra_cull_margin = r * 7.0
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
	if key == "puff_smoke":
		g.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH          # (round 4: the smoke blends; its puffs sorted)
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
	if not g.is_inside_tree():
		return
	var xf := g.global_transform
	var scn := g.get_tree().current_scene
	if scn == null:
		return
	g.emitting = false
	var longest := g.lifetime
	for c in g.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).emitting = false
			longest = maxf(longest, (c as GPUParticles3D).lifetime)
	# A fighter's exit can end a sibling guard while the scene is removing children. Reparent only once that
	# notification has finished; deferred calls run before queued deletion. Weak references also cover a scene freed now.
	_finish_trail.call_deferred(weakref(g), weakref(scn), xf, longest + 0.2)


static func _finish_trail(trail_ref: WeakRef, scene_ref: WeakRef, xf: Transform3D, fade_s: float) -> void:
	var g := trail_ref.get_ref() as GPUParticles3D
	var scn := scene_ref.get_ref() as Node
	if g == null or g.is_queued_for_deletion():
		return
	if scn == null or not scn.is_inside_tree() or scn.is_queued_for_deletion():
		g.queue_free()
		return
	if g.get_parent() == null:
		scn.add_child(g)
	elif g.get_parent() != scn:
		g.reparent(scn, false)
	g.global_transform = xf
	scn.get_tree().create_timer(fade_s, false).timeout.connect(g.queue_free)


# ---------------------------------------------------------------- bursts
## A burst of `kind` at `at` (a hit, a cast): `n` bits flung along `dir` within `spread` deg (180: all round).
## `cap` (round 4): on a body, kept within its share of his height (false: a guard's own reward on the guarder, as it was).
static func burst(at: Vector3, kind: String, n := 18, dir := Vector3.UP, spread := 180.0, speed := 4.0, size := 0.25, cap := true) -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var d := dir.normalized() if dir.length_squared() > 1e-6 else Vector3.UP
	# (round 4: on a body, the burst kept within body_share of its height, its count and size; the puffs between the camera
	# and the body drawn at half)
	var occl := {}
	var body := struck_body(at) if cap else null
	if body != null:
		var f := burst_cap(kind, speed, size, body_h(body))
		n = maxi(4, int(round(n * f)))
		speed *= f
		size *= f
		var h := body_h(body)
		occl = {"occl": Vector4(body.global_position.x, body.global_position.y + h * 0.5, body.global_position.z, h * 0.28)}
	var k := clampf(size / 0.25, 0.5 if body == null else 0.05, 4.0)
	var g := _ground(pool, at, d)
	var up := Transform3D(Basis.IDENTITY, at)
	match kind:
		"fire":
			pool.play("flash", up, 0.18, 0.7 * k, 2.2 * k, FIRE, FIRE_HOT)
			pool.shoot("puff_fire", at, int(n * 0.9), d, spread, Vector2(speed * 0.3, speed * 0.9), Vector2(0.45, 1.0) * k,
					0.5, Vector3(0, 3.0, 0), 3.0, {"r": 0.15 * k}.merged(occl))
			pool.shoot("spark_fire", at, n, d, spread, Vector2(speed * 0.8, speed * 2.2), Vector2(0.03, 0.06), 0.65,
					Vector3(0, -5.0, 0), 1.5)
			pool.light(at, Color(1.0, 0.6, 0.25), 3.0, 0.2, 4.0)
			if not g.is_empty():
				pool.play("ring", _flat(g), 0.32, 0.4 * k, 1.8 * k, FIRE, FIRE_HOT)
				pool.mark("scorch", g.pos, g.normal, 1.3 * k, 6.0)
		"water":
			pool.shoot("drop", at, int(n * 1.3), d, spread, Vector2(speed * 0.6, speed * 1.8), Vector2(0.1, 0.2) * k,
					0.75, Vector3(0, -14.0, 0), 0.5, {"r": 0.1 * k}.merged(occl))
			pool.shoot("foam", at, int(n * 0.45), d, spread * 1.2, Vector2(speed * 0.2, speed * 0.6), Vector2(0.35, 0.7) * k,
					0.5, Vector3.ZERO, 2.0, {"r": 0.15 * k}.merged(occl))
			if not g.is_empty():
				pool.play("crown", _flat(g), 0.55, 0.6 * k, 1.3 * k, WATER, FOAM, ToonFx.band_mesh(1.0, 1.5, 1.0))
				pool.play("ring", _flat(g), 0.7, 0.3 * k, 1.9 * k, FOAM, Color(0.55, 0.85, 1.0))
				pool.mark("wet", g.pos, g.normal, 1.6 * k, 4.0)
			else:
				pool.play("flash", up, 0.14, 0.4 * k, 1.0 * k, WATER, FOAM)
		"steam":
			pool.shoot("puff_steam", at, n, d, spread, Vector2(speed * 0.3, speed), Vector2(0.4, 0.9) * k, 1.1,
					Vector3(0, 1.8, 0), 2.0, {"r": 0.3 * k}.merged(occl))
			pool.play("ring", Transform3D(Basis.IDENTITY, at), 0.4, 0.3 * k, 1.6 * k, FOAM, Color(0.75, 0.82, 0.9))
		"ice":
			var big := n >= 24
			var sk := 1.7 if big else 1.0
			pool.play("flash", up, 0.14, 0.4 * k * sk, 1.2 * k * sk, ICE, Color(0.9, 0.98, 1.0))
			pool.shoot("shard", at, int(n * 0.9), d, spread, Vector2(speed * 0.7, speed * (2.2 if big else 1.6)),
					Vector2(0.16, 0.34) * sk * k, 0.95, Vector3(0, -12.0, 0), 0.5, {"r": (0.7 if big else 0.1) * k, "ang": 600.0})
			pool.shoot("puff_frost", at, int(n * (0.45 if big else 0.25)), d, spread, Vector2(speed * 0.2, speed * 0.6), Vector2(0.3, 0.6) * sk * k,
					0.55, Vector3.ZERO, 2.0, {"r": (0.5 if big else 0.1) * k}.merged(occl))
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
					0.4, Vector3.ZERO, 3.0, occl)
			if not g.is_empty():
				_dust(pool, g, n, k)
		"stone":
			pool.shoot("chunk", at, n, d, spread, Vector2(speed * 0.7, speed * 1.5), Vector2(0.12, 0.3) * k, 1.1,
					Vector3(0, -16.0, 0), 0.3, {"r": 0.15 * k, "ang": 400.0})
			pool.shoot("puff_dust", at, int(n * 0.7), d, spread, Vector2(speed * 0.2, speed * 0.6), Vector2(0.55, 1.1) * k,
					1.0, Vector3(0, 0.3, 0), 3.0, {"r": 0.2 * k}.merged(occl))
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


## The body a burst at `at` lands on (a fighter or a player standing within ToonFx.looks puffs.find_r_m of it, `at` within
## his height), or null.
static func struck_body(at: Vector3) -> Node3D:
	var ml := Engine.get_main_loop() as SceneTree
	if ml == null:
		return null
	var pu := ToonFx.looks("puffs")
	var r := float(pu.get("find_r_m", 0.9))
	var best: Node3D = null
	var bd := INF
	for grp: StringName in [NpcFighter.GROUP, &"player"]:
		for n in ml.get_nodes_in_group(grp):
			var b := n as Node3D
			if b == null or not b.is_inside_tree():
				continue
			var q := b.global_position
			var dd := Vector2(q.x - at.x, q.z - at.z).length()
			if dd <= r and at.y >= q.y - 0.3 and at.y <= q.y + body_h(b) + 0.3 and dd < bd:
				best = b
				bd = dd
	return best


## A body's height for the puffs' cap (ToonFx.looks puffs.body_h_m; a crouched one lower).
static func body_h(b: Node) -> float:
	var h := float(ToonFx.looks("puffs").get("body_h_m", 1.8))
	return h * (0.65 if NpcSenses.crouched(b) else 1.0)


## The burst's occluding cloud (its puffs, flashes and swirls; the sparks and drops are thin) at `f` of its speed and size:
## how tall it stands (m): twice its puffs' reach plus their size. The table: [speed share, size (x its size's k), life,
## damping] of each of the kind's occluding shots, as burst plays them.
const BURST_CLOUD := {
	"fire": [[0.9, 1.0, 0.5, 3.0], [0.0, 2.2, 0.0, 0.0]],
	"water": [[0.6, 0.7, 0.5, 2.0], [0.0, 1.0, 0.0, 0.0]],
	"steam": [[1.0, 0.9, 1.1, 2.0]],
	"ice": [[0.6, 0.6, 0.55, 2.0], [0.0, 1.2, 0.0, 0.0]],
	"air": [[0.8, 0.45, 0.4, 3.0], [0.0, 1.9, 0.0, 0.0]],
	"stone": [[0.6, 1.1, 1.0, 3.0]],
	"lightning": [[0.0, 1.3, 0.0, 0.0]],
}


static func burst_span(kind: String, speed: float, size: float, f := 1.0) -> float:
	var k := clampf(size * f / 0.25, 0.05, 4.0)
	var span := 0.0
	for e: Array in BURST_CLOUD.get(kind, [[1.0, 0.4, 0.5, 0.0]]):
		var v := float(e[0]) * speed * f
		var life := float(e[2])
		var dmp := float(e[3])
		var reach := v * life
		if dmp > 0.0 and v / dmp < life:
			reach = v * v / (2.0 * dmp)
		elif dmp > 0.0:
			reach = v * life - dmp * life * life * 0.5
		span = maxf(span, 2.0 * reach + float(e[1]) * k)
	return span


## The share of its speed, size and count a burst on a body of height `h` keeps (1: as it is) so its cloud stands within
## ToonFx.looks puffs.body_share of `h`.
static func burst_cap(kind: String, speed: float, size: float, h: float) -> float:
	var cap := h * float(ToonFx.looks("puffs").get("body_share", 0.6))
	if burst_span(kind, speed, size, 1.0) <= cap:
		return 1.0
	var lo := 0.0
	var hi := 1.0
	for i in 20:
		var m := (lo + hi) * 0.5
		if burst_span(kind, speed, size, m) <= cap:
			lo = m
		else:
			hi = m
	return lo


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


## Patch on `body` (round 3's heal: the fresh % taken back), in element `el`'s matter: three rings rising from his feet to his chest,
## each closing in on him, and the matter drawn up round him (stone flakes, drops, embers, wisps), a light at his middle. Round
## him, never over his face (the move review 2026-10-12: Patch showed only a circle at the feet).
static func patch_glow(body: Node3D, el: String) -> void:
	if not live() or body == null or not is_instance_valid(body):
		return
	var pool := _pool()
	if pool == null:
		return
	var tree := pool.get_tree()
	if tree == null:
		return
	var cols: Array = {"earth": [DUST, DUST_LIGHT], "water": [WATER, FOAM], "fire": [FIRE, FIRE_HOT]}.get(el, [AIR, Color(0.6, 0.82, 1.0)])
	var h := body_h(body)
	pool.light(body.global_position + Vector3.UP * h * 0.5, (cols[1] as Color), 2.5, 0.5, 3.5)
	for i in 3:
		tree.create_timer(0.11 * i, false).timeout.connect(_patch_ring.bind(body, el, h * (0.06 + 0.36 * i), cols))


## One of Patch's rings on `body` at `y` over his feet, closing in, and its element's matter drawn up from it.
static func _patch_ring(body: Node3D, el: String, y: float, cols: Array) -> void:
	var p2 := _pool()
	if p2 == null or not is_instance_valid(body):
		return
	var at := body.global_position + Vector3.UP * y
	p2.play("ring", Transform3D(Basis.IDENTITY, at), 0.42, 1.0, 0.5, cols[0], cols[1])
	match el:
		"earth":
			p2.shoot("chunk", at, 7, Vector3.UP, 30.0, Vector2(0.8, 1.6), Vector2(0.05, 0.1), 0.5, Vector3(0, -2.0, 0), 0.0, {"r": 0.55})
		"water":
			p2.shoot("drop", at, 10, Vector3.UP, 25.0, Vector2(1.0, 2.0), Vector2(0.05, 0.1), 0.5, Vector3(0, -3.0, 0), 0.0, {"r": 0.5})
		"fire":
			p2.shoot("spark_fire", at, 12, Vector3.UP, 25.0, Vector2(1.0, 2.4), Vector2(0.03, 0.05), 0.6, Vector3(0, 1.0, 0), 0.5,
					{"r": 0.5})
		_:
			p2.shoot("spark_line", at, 10, Vector3.UP, 20.0, Vector2(1.5, 3.0), Vector2(0.03, 0.04), 0.4, Vector3.ZERO, 1.0,
					{"r": 0.55})


## The Wave's water going out from `at` (the caster's chest) along `dir`, `deg` wide, to `reach` m at `mps` (BendEffects.cone's
## travel_mps: its hits land as this front reaches them, the move review 2026-10-12: he flew before the foam got there): a blue
## curl of water, `tall` m, risen afresh every step along the way, spray thrown off its lip and drops left on the deck.
static func wave_front(at: Vector3, dir: Vector3, deg: float, reach: float, mps: float, tall := 1.2) -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var tree := pool.get_tree()
	if tree == null:
		return
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	if d.length_squared() < 1e-6:
		return
	var foot := FormEffects.ground_at(pool, at)
	var span := deg_to_rad(clampf(deg, 20.0, 160.0))
	var mesh := ToonFx.band_arc_mesh(1.0, 1.12, 1.0, span)
	var look := Basis.looking_at(d, Vector3.UP)
	pool.shoot("drop", at, 16, d, deg * 0.4, Vector2(4.0, 8.0), Vector2(0.08, 0.16), 0.5, Vector3(0, -10, 0), 0.0)
	var steps := clampi(int(ceil(reach / 0.55)), 6, 24)
	for i in steps:
		var r := 0.7 + (reach - 0.7) * float(i + 1) / steps
		var h := tall * lerpf(0.75, 1.0, sin(PI * float(i + 1) / (steps + 1)))   # (it swells, then breaks at its end)
		var wait := r / maxf(mps, 1.0)
		var last := i == steps - 1
		tree.create_timer(maxf(wait - 0.04, 0.0), false).timeout.connect(func() -> void:
			var p2 := _pool()
			if p2 == null:
				return
			var xf := Transform3D(look * Basis.from_scale(Vector3(r, h, r)), foot + Vector3.UP * 0.02)
			p2.play("crown", xf, 0.32, 1.0, 1.06, WATER, FOAM, mesh)
			var lip := foot + d * r + Vector3.UP * h
			p2.shoot("foam", lip, 3, d + Vector3.UP * 0.6, 50.0, Vector2(1.0, 2.5), Vector2(0.25, 0.45), 0.4, Vector3(0, -3, 0), 1.5,
					{"r": r * sin(span * 0.5) * 0.8})
			p2.shoot("drop", lip, 5, d + Vector3.UP * 0.8, 40.0, Vector2(2.0, 4.5), Vector2(0.06, 0.12), 0.6, Vector3(0, -10, 0), 0.0,
					{"r": r * sin(span * 0.5) * 0.8})
			if last:
				p2.shoot("foam", foot + d * r + Vector3.UP * 0.3, 10, d + Vector3.UP, 70.0, Vector2(1.0, 3.0), Vector2(0.3, 0.6), 0.6,
						Vector3(0, -2, 0), 1.0, {"r": r * sin(span * 0.5)}))


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
## strikes, a smaller flash at the hand, a flash of light. With SB_BOLT the same forks are shaded the way Spellbreak's
## lightning is (sb_strike).
static func lightning(a: Vector3, b: Vector3) -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var c1 := SB_VIOLET if sb_bolt else ELEC
	var c2 := SB_LAVENDER if sb_bolt else Color(0.85, 0.92, 1.0)
	var back := (a - b).normalized()
	# (the stroke held 0.36 s, four flickers: at 0.26 it was gone between two looks, the move review 2026-10-12; the strike's
	# timing is the spec's flash_s, not this)
	if sb_bolt:
		sb_strike(pool, a, b, 0.36, 4)
		_sb_crackle(pool, b, back, SB_HIT_FORKS, 0.36)
	else:
		pool.lightning(a, b, 0.36, 4)
	pool.play("flash", Transform3D(Basis.IDENTITY, b), 0.2, 0.6, 1.8, c1, c2)
	pool.play("flash", Transform3D(Basis.IDENTITY, a), 0.12, 0.3, 0.8, c1, c2)
	pool.shoot("spark_sb" if sb_bolt else "spark_elec", b, 26, back, 75.0, Vector2(3.0, 9.0), Vector2(0.025, 0.045), 0.35,
			Vector3(0, -8.0, 0), 2.0)
	pool.light((a + b) * 0.5, SB_LIGHT if sb_bolt else Color(0.65, 0.78, 1.0), 4.0, 0.2, a.distance_to(b) * 0.6 + 4.0)
	var g := _ground(pool, b, -back)
	if not g.is_empty():
		pool.mark("scorch", g.pos, g.normal, 1.0, 4.0)
		pool.play("ring", _flat(g), 0.25, 0.3, 1.4, c1, c2)


## The bolt's look (the owner, 2026-10-09: "for lightning i like our lightning but maybe make it look like spellbreaks or
## use its shaders"). true: our own forked bolt (the same ToonFx.lightning_strips forks, widths, flicker and timing as
## ToonFxPool.lightning) drawn with Spellbreak's lightning shading (shaders/cascade/lightning_bolt.gdshader, on Spellbreak's
## T_f_GenericLighting_F plateaus: a white-hot core in a lavender sheath with a blue-violet fringe, crackling at the
## material's 15 fps and eroding from its fringe as it dies). false: the old cel bolt (ToonFxPool.lightning, toon_bolt), at
## once. sb_bolt is the switch in force (a test or a capture may flip it). Visual only: where it strikes, when, and what it
## hits are BendEffects' and unchanged.
const SB_BOLT := true
static var sb_bolt := SB_BOLT
## The flashes, ring and light round a Spellbreak-shaded bolt in its colours (the shader's fringe and sheath).
const SB_VIOLET := Color(0.46, 0.36, 1.0)
const SB_LAVENDER := Color(0.88, 0.85, 1.0)
const SB_LIGHT := Color(0.8, 0.78, 1.0)
## The short forks of the hand's crackle at the release (Spellbreak's muzzle bolts: GauntletLightningMuzzle_FX's "Lightning
## Mulit Center") and of the strike's end (Lightning_Shocked01_FxP's "Torso Forks"); their reach (m) and width share.
const SB_HAND_FORKS := 3
const SB_HIT_FORKS := 2
const SB_FORK_M := Vector2(0.35, 0.7)
const SB_FORK_WIDTH := 0.45
## The Spellbreak-shaded bolts one scene keeps (SbBolt, under its ToonFxPool): a strike's and the hand's crackle; past
## this the oldest is taken again (never one node per strike).
const SB_BOLTS := 10
const SB_BOLT_SHADER := "res://shaders/cascade/lightning_bolt.gdshader"
## Spellbreak's textures (assets/fx/spellbreak/SOURCE.md): "Lightning Bolt" and "Noise 1/2" of MI_f_lightningBranchingBolt.
const SB_BOLT_TEX := "res://assets/fx/spellbreak/assets/VFX/Textures/T_f_GenericLighting_F.png"
const SB_BOLT_NOISE := "res://assets/fx/spellbreak/assets/VFX/Textures/T_f_SmokeHeight_Greyscale_Uncompressed.png"
static var _sb_mat: ShaderMaterial
static var _sb_bolts: Array = []
static var _sb_i := 0


## The Spellbreak-shaded bolt's material (shared; made once; the scene's effect brightness and near fade as ToonFx's own).
static func sb_bolt_material() -> ShaderMaterial:
	if _sb_mat == null:
		_sb_mat = ShaderMaterial.new()
		_sb_mat.shader = load(SB_BOLT_SHADER)
		_sb_mat.set_shader_parameter(&"bolt_tex", load(SB_BOLT_TEX))
		_sb_mat.set_shader_parameter(&"noise_tex", load(SB_BOLT_NOISE))
		var nr := ToonFx.looks("near")
		_sb_mat.set_shader_parameter(&"near_m", float(nr.get("near_m", 2.5)))
		_sb_mat.set_shader_parameter(&"far_m", float(nr.get("far_m", 4.0)))
		_sb_mat.set_shader_parameter(&"near_alpha", float(nr.get("near_alpha", 0.25)))
	_sb_mat.set_shader_parameter(&"fx_gain", ToonFx.gain)
	return _sb_mat


## Our forked bolt from `a` to `b` in Spellbreak's shading (SB_BOLT): rebuilt `flickers` times over `life` s and eroded over
## its last 45 %, as the pool's own bolt. A bolt node of the scene's few (SbBolt) is reused; the one used, or null.
static func sb_strike(pool: ToonFxPool, a: Vector3, b: Vector3, life := 0.26, flickers := 3, width_k := 1.0) -> SbBolt:
	if pool == null or not is_instance_valid(pool):
		return null
	for i in range(_sb_bolts.size() - 1, -1, -1):
		var o: Variant = _sb_bolts[i]
		if not is_instance_valid(o) or (o as Node).get_parent() != pool:
			_sb_bolts.remove_at(i)
	var bolt: SbBolt = null
	for o: SbBolt in _sb_bolts:
		if not o.on:
			bolt = o
			break
	if bolt == null:
		if _sb_bolts.size() < SB_BOLTS:
			bolt = SbBolt.new()
			bolt.name = "SbBolt"
			pool.add_child(bolt)
			_sb_bolts.append(bolt)
		else:
			_sb_i = (_sb_i + 1) % _sb_bolts.size()
			bolt = _sb_bolts[_sb_i]
	bolt.strike(a, b, life, flickers, width_k)
	return bolt


## A crackle of `n` short thin forks off `at`, mostly along `way` (turned up to `spread` off it), `reach` m long (min, max),
## `width` of a strike's width, living `life` s and rebuilt `flickers` times.
static func _sb_crackle(pool: ToonFxPool, at: Vector3, way: Vector3, n: int, life: float, reach := SB_FORK_M,
		width := SB_FORK_WIDTH, spread := 0.85, flickers := 2) -> void:
	if pool == null:
		return
	var w := way.normalized() if way.length_squared() > 1e-6 else Vector3.UP
	var r := ToonFx.vis_rng
	for i in n:
		var off := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.5, 0.9), r.randf_range(-1.0, 1.0))
		var d := (w + off * spread).normalized()
		sb_strike(pool, at, at + d * r.randf_range(reach.x, reach.y), life, flickers, width)


## The lightning's share of the level's warm-up (warm_up): the bolt in force drawn once, tiny, so its shader is compiled
## behind the loading screen (both looks when the switch is on: the old one stays a frame away).
static func _warm_lightning(pool: ToonFxPool, at: Vector3) -> void:
	pool.lightning(at, at + Vector3.UP * 0.05, 0.15, 1)
	if sb_bolt:
		sb_strike(pool, at, at + Vector3.UP * 0.05, 0.15, 1)
		for k in ["spark_sb", "star_sb"]:                # (its sparks' own particle programs: their colour ramps)
			pool.shoot(k, at, 1, Vector3.UP, 10.0, Vector2(0.01, 0.01), Vector2(0.001, 0.001), 0.1)


## One Spellbreak-shaded bolt (sb_strike): our forks (ToonFx.lightning_strips) under the shared sb_bolt_material, stepped
## on the pool's timing (ToonFxPool._bolt_step): rebuilt every 22 % of its life while flickers are left, fade 1 -> 0 over
## the last 45 % (the shader erodes it), then hidden and its strips cleared, free for the next.
class SbBolt:
	extends MeshInstance3D

	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var t := 0.0
	var life := 0.26
	var next := 0.0
	var left := 0
	var on := false
	## How many times its forks were built (the tests).
	var builds := 0

	func _init() -> void:
		mesh = ImmediateMesh.new()
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		extra_cull_margin = 4.0
		visible = false
		set_process(false)

	func strike(from: Vector3, to: Vector3, s: float, flickers: int, width_k := 1.0) -> void:
		material_override = BendLooks.sb_bolt_material()
		a = from
		b = to
		t = 0.0
		life = maxf(s, 0.01)
		next = life * 0.22
		left = flickers - 1
		on = true
		visible = true
		set_instance_shader_parameter(&"fade", 1.0)
		set_instance_shader_parameter(&"len_m", maxf(a.distance_to(b), 0.05))
		set_instance_shader_parameter(&"width_k", width_k)
		_build()
		set_process(true)

	func _build() -> void:
		ToonFx.lightning_strips(mesh as ImmediateMesh, a, b)
		set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf())
		builds += 1

	func _process(dt: float) -> void:
		t += dt
		if t >= life:
			on = false
			visible = false
			(mesh as ImmediateMesh).clear_surfaces()
			set_process(false)
			return
		if left > 0 and t >= next:
			left -= 1
			next += life * 0.22
			_build()
		set_instance_shader_parameter(&"fade", 1.0 - clampf((t - life * 0.55) / (life * 0.45), 0.0, 1.0))


# ---------------------------------------------------------------- round 2: the tells on the caster (or guarder) only
## (skills_r2 spec §8.2 "BendLooks"; the owner's rule: no target cues, nothing is ever drawn on or about the opponent: each
## of these plays on the one who casts or guards, his hands, his feet, his own body.)
## Each guard's result's colours (a flash, a ring) by element.
const GUARD_TINTS := {"earth": [Color(0.88, 0.76, 0.55), Color(1.0, 0.95, 0.8)], "water": [Color(0.25, 0.62, 1.0), FOAM],
		"fire": [Color(1.0, 0.45, 0.08), FIRE_HOT], "air": [Color(0.8, 0.92, 1.0), Color(1.0, 1.0, 1.0)]}
## Each guard's sounds by element ([perfect, late]; BendSounds' own, synthesized).
const GUARD_SOUNDS := {"earth": [&"guard_earth_clean", &"stone_catch"], "water": [&"guard_water_clean", &"guard_water_late"],
		"fire": [&"guard_fire_clean", &"guard_fire_late"], "air": [&"guard_air_clean", &"guard_air_late"]}


## A guard's result on the guarder `body` (BendZone.report): perfect, a bright flash and a sharp crack ring round his chest
## in his element's colours, stars and the element's own bits flung off, his element's clean sound; late, a smaller puff and
## its late sound; whiff, a dull puff at his hands, no sound.
static func guard_result(body: Node3D, el: String, result: String) -> void:
	var at := body.global_position + Vector3.UP * 1.2
	var snd: Array = GUARD_SOUNDS.get(el, [&"stone_catch", &"stone_catch"])
	if result == "perfect":
		BendSounds.play(StringName(snd[0]), at, 1.0)
	elif result == "late":
		BendSounds.play(StringName(snd[1]), at, -2.0)
	if not live():
		return
	var g := Bending.guard(el)
	if SbFx.fire(body, "%s/%s" % [String(g.get("id", "")), String(g.get("mode", ""))], result, {"at": at, "el": el}):
		return                                   # (the guard's Spellbreak result played instead: SbFx)
	var pool := _pool()
	if pool == null:
		return
	var tint: Array = GUARD_TINTS.get(el, [Color.WHITE, Color.WHITE])
	var xf := Transform3D(Basis.IDENTITY, at)
	match result:
		"perfect":
			pool.play("flash", xf, 0.22, 0.6, 2.4, tint[0], tint[1])
			pool.play("ring", Transform3D(Basis.IDENTITY, at), 0.3, 0.4, 2.6, tint[1], tint[0])     # (flat round his chest)
			pool.shoot("star", at, 14, Vector3.UP, 180.0, Vector2(2.0, 5.0), Vector2(0.2, 0.36), 0.5, Vector3.ZERO, 4.0)
			burst(at, el if el in KINDS else "air", 14, Vector3.UP, 180.0, 4.0, 0.3, false)
			pool.light(at, tint[0], 3.5, 0.2, 5.0)
		"late":
			pool.play("flash", xf, 0.14, 0.3, 1.0, tint[0], tint[1])
			burst(at, el if el in KINDS else "air", 8, Vector3.UP, 120.0, 2.0, 0.2, false)
		"whiff":
			pool.shoot("puff_air", at, 6, Vector3.UP, 120.0, Vector2(0.3, 0.8), Vector2(0.15, 0.3), 0.4)


## The Kick's floor wave's body (BendBolt floor_wave, under the bolt: its local X across, -Z its way; round 4, LOOKS: bigger
## and thicker, ToonFx.looks floor_wave): three rows of flame tongues across `width` m (wave_tongues: a bright crest at the
## front, a body, a low trail; 1.0-1.4 m deep), the crest's visible top the height a jump clears (wave_top: the bolt's
## miss_above_m, read from its spec; `height` when it has none), a soft glow under them, a bright lip along the deck under
## the crest (a ToonRibbon laid across), sparks thrown ahead, embers, a warm light that travels with it, scorches left along
## its path and embers spilling past the deck's lip (WaveFx). The holder (its scale.x the wave's width over `width`: the bolt
## widens it as it runs). Headless: the holder alone.
## Earth's Fissure (a floor wave of kind stone): FissureFx, our own stone spikes bursting along it (a plain holder when nothing
## is drawn). Loaded by its path (FISSURE_FX): a class name new to the project is unknown to a run until the editor has scanned
## the project, and naming it here made a launcher run of an unscanned checkout fail to compile every effect (2026-10-11).
const FISSURE_FX := preload("res://scripts/bending/fissure_fx.gd")
static func fissure_body(parent: Node3D, width: float, height: float) -> Node3D:
	if not live():
		var holder := Node3D.new()
		holder.name = "Fissure"
		parent.add_child(holder)
		return holder
	var f := FISSURE_FX.new()
	f.name = "Fissure"
	f.width = width
	f.height = height
	parent.add_child(f)
	return f


static func floor_wave_body(parent: Node3D, width: float, height: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Wave"
	parent.add_child(holder)
	if not live():
		return holder
	var fw := ToonFx.looks("floor_wave")
	var top := wave_top(parent, height)
	var tg := wave_tongues(width, top)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = ToonFx.quad_base()
	mm.instance_count = tg.size()
	for i in tg.size():
		mm.set_instance_transform(i, tg[i].xf)
		mm.set_instance_color(i, Color(float(tg[i].heat), 1.0, 1.0, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tongues"
	mmi.multimesh = mm
	mmi.set_meta(&"tongues", tg)                  # (what it laid out: the tests read it, a dummy server keeps no instances)
	mmi.material_override = ToonFx.mat("flame_wave")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 3.0
	mmi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 10.0)
	mmi.set_instance_shader_parameter(&"grow", 1.0)
	holder.add_child(mmi)
	_glow(holder, Vector3(width * 1.5, top * 1.9, 1.0), Vector3(0.0, top * 0.45, 0.45))
	var lip := ToonRibbon.new()
	lip.name = "Lip"
	lip.main_mat = ToonFx.mat("flame_lip")
	lip.width = 0.13
	holder.add_child(lip)
	lip.lay_across(holder, width * 0.55, 0.04)
	var em := emitter(holder, "embers", Vector3(width * 0.5, 0.15, 0.5), 14, 0.6, 1.4, 0.05)
	if em != null:
		em.position = Vector3(0.0, 0.3, 0.45)
	var sv: Array = fw.get("spark_mps", [3.0, 6.5])
	var sp := emitter(holder, "embers", Vector3(width * 0.5, 0.1, 0.05), int(fw.get("sparks", 16)), 0.45, 1.0, 0.05)
	if sp != null:
		sp.position = Vector3(0.0, 0.2, -0.1)
		var pm := sp.process_material as ParticleProcessMaterial
		pm.direction = Vector3(0.0, 0.35, -1.0).normalized()          # (thrown ahead of the crest, along its way)
		pm.spread = 28.0
		pm.initial_velocity_min = float(sv[0])
		pm.initial_velocity_max = float(sv[1])
		pm.gravity = Vector3(0.0, -6.0, 0.0)
	var fx := WaveFx.new()
	fx.name = "WaveFx"
	fx.base_w = width
	holder.add_child(fx)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.0
	l.omni_range = 4.0
	l.position = Vector3.UP * 0.5
	l.shadow_enabled = false
	holder.add_child(l)
	return holder


## The Kick's visible top (round 4): the height its strike stops at for a jumper (the bolt's miss_above_m: feet over it clear
## it), else `height`.
static func wave_top(bolt: Node, height: float) -> float:
	if bolt != null and "miss_above_m" in bolt:
		return float(bolt.get(&"miss_above_m"))
	return height


## The Kick's tongues (round 4; ToonFx.looks floor_wave.rows): [{xf, heat, row}] across `width` m, the crest's tallest one's
## visible top (its quad's height x fill) at `top` m; each row behind the last, the middle leading a little.
static func wave_tongues(width: float, top: float) -> Array[Dictionary]:
	var fw := ToonFx.looks("floor_wave")
	var fill := float(fw.get("fill", 0.92))
	var out: Array[Dictionary] = []
	var rows: Array = fw.get("rows", [])
	for ri in rows.size():
		var row: Dictionary = rows[ri]
		var n := int(row.get("n", 8))
		var zr: Array = row.get("z", [0.0, 0.1])
		var hr: Array = row.get("h", [0.9, 1.0])
		for i in n:
			var x := ((float(i) + 0.5 + ToonFx.vis_rng.randf_range(-0.2, 0.2)) / n - 0.5) * width
			var edge := absf(x) / maxf(width * 0.5, 0.01)
			var h := top / fill * ToonFx.vis_rng.randf_range(float(hr[0]), float(hr[1])) * (1.0 - 0.22 * edge * edge)
			var z := ToonFx.vis_rng.randf_range(float(zr[0]), float(zr[1])) + edge * 0.18
			var w := width / n * float(row.get("w", 1.8))
			out.append({"xf": Transform3D(Basis(Vector3.RIGHT * w, Vector3.UP * h, Vector3.BACK), Vector3(x, 0.0, z)),
					"heat": float(row.get("heat", 1.0)), "row": String(row.get("name", str(ri)))})
	return out


## The Geyser's water at `at` (BendEffects.spout): low and weak at once, its column at its peak `rise_s` later, `r` round.
## No mark on the deck: the rising water is the tell.
static func spout(at: Vector3, r: float, rise_s: float) -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	pool.shoot("drop", at, 14, Vector3.UP, 20.0, Vector2(1.5, 3.0), Vector2(0.08, 0.16), 0.5, Vector3(0, -9.0, 0), 0.0,
			{"r": r * 0.6})
	pool.shoot("foam", at, 8, Vector3.UP, 30.0, Vector2(0.5, 1.2), Vector2(0.3, 0.5), 0.5, Vector3.ZERO, 1.0, {"r": r * 0.5})
	var tree := pool.get_tree()
	if tree == null:
		return
	tree.create_timer(maxf(rise_s, 0.01), false).timeout.connect(func() -> void:
		var p2 := _pool()
		if p2 == null:
			return
		p2.shoot("drop", at, 48, Vector3.UP, 12.0, Vector2(7.0, 13.0), Vector2(0.12, 0.24), 1.1, Vector3(0, -12.0, 0), 0.0,
				{"r": r * 0.7})
		p2.shoot("foam", at + Vector3.UP * 0.5, 22, Vector3.UP, 20.0, Vector2(3.0, 7.0), Vector2(0.4, 0.8), 0.8, Vector3(0, -4.0, 0),
				1.0, {"r": r * 0.6})
		p2.play("crown", Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.05), 0.6, r * 0.6, r * 1.4, WATER, FOAM,
				ToonFx.band_mesh(1.0, 1.5, 1.0)))


## A bind's tell where it is cast (Stone Grip and Frost Geyser, the skill tree's binds, 2026-10-11: what shows in place of the
## Column's stone or the Geyser's water at `at`, `r` across, the hold landing rise_s later): cracks or frost spreading on the
## deck and a low puff, then teeth of stone or ice snapping up at the rise. Nothing drawn on anyone.
static func bind_tell(at: Vector3, el: String, r: float, rise_s: float) -> void:
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var ice := el == "water"
	pool.mark("frost" if ice else "cracks", at, Vector3.UP, r * 1.6, rise_s + 1.2)
	pool.shoot("puff_frost" if ice else "puff_dust", at + Vector3.UP * 0.1, 10, Vector3.UP, 70.0, Vector2(0.4, 1.0),
			Vector2(0.3, 0.6), 0.6, Vector3.ZERO, 1.5, {"r": r * 0.6})
	var tree := pool.get_tree()
	if tree == null:
		return
	tree.create_timer(maxf(rise_s, 0.01), false).timeout.connect(func() -> void:
		var p2 := _pool()
		if p2 == null:
			return
		p2.shoot("drop" if ice else "chunk", at, 12, Vector3.UP, 25.0, Vector2(2.0, 4.0), Vector2(0.08, 0.22) if ice else Vector2(0.12, 0.22),
				0.5, Vector3(0, -12.0, 0), 0.0, {"r": r * 0.7})
		p2.play("crown", Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.05), 0.45, r * 0.5, r * 0.7, ICE if ice else DUST,
				FOAM if ice else DUST_LIGHT, ToonFx.band_mesh(1.0, 1.3, 0.6)))


## A bind's hold on `body`'s feet for `s` (BendStatus.bind), in element `el`'s matter (BindLook: solid for the whole hold): stone
## closing round the ankles (earth), ice shards (water), lightning crackling up the legs (fire's shock), rings of wind spinning
## round them (air); a burst of the matter as it takes. At the legs only.
static func bind_feet(body: Node3D, el: String, s: float) -> void:
	if not live() or body == null or not is_instance_valid(body):
		return
	BindLook.make(body, el, s)
	var pool := _pool()
	if pool == null:
		return
	var at := body.global_position + Vector3.UP * 0.05
	match el:
		"earth":
			pool.shoot("chunk", at, 10, Vector3.UP, 35.0, Vector2(1.0, 2.2), Vector2(0.1, 0.18), 0.4, Vector3(0, -10.0, 0), 0.0,
					{"r": 0.35})
			pool.mark("cracks", at, Vector3.UP, 1.4, s + 0.8)
		"water":
			# (no "shard" sparks here: that recipe is stone's colour; the ice is BindLook's own)
			pool.shoot("drop", at + Vector3.UP * 0.1, 12, Vector3.UP, 40.0, Vector2(1.0, 2.2), Vector2(0.06, 0.12), 0.4,
					Vector3(0, -9.0, 0), 0.0, {"r": 0.3})
			pool.shoot("puff_frost", at + Vector3.UP * 0.2, 8, Vector3.UP, 60.0, Vector2(0.2, 0.6), Vector2(0.25, 0.45), s,
					Vector3.ZERO, 1.0, {"r": 0.3})
			pool.mark("frost", at, Vector3.UP, 1.4, s + 1.0)
		"fire":
			pool.shoot("spark_elec", at + Vector3.UP * 0.15, 24, Vector3.UP, 80.0, Vector2(1.5, 4.0), Vector2(0.04, 0.08),
					minf(s, 0.5), Vector3.ZERO, 2.0, {"r": 0.3})
			pool.mark("scorch", at, Vector3.UP, 1.0, s + 0.6)
			pool.light(at + Vector3.UP * 0.4, ELEC, 1.8, s, 3.0)
		_:
			pool.shoot("puff_air", at + Vector3.UP * 0.3, 10, Vector3.UP, 90.0, Vector2(0.5, 1.2), Vector2(0.25, 0.4), s,
					Vector3.ZERO, 1.0, {"r": 0.4})


## A Wind Prison's hold round `body` for `s` (BendZone._imprison): a whirl of wind bands round his middle (BindLook "prison"), a
## puff of air about him for the hold.
static func prison(body: Node3D, s: float) -> void:
	if not live() or body == null or not is_instance_valid(body):
		return
	BindLook.make(body, "prison", s)
	var pool := _pool()
	if pool != null:
		pool.shoot("puff_air", body.global_position + Vector3.UP * 0.9, 12, Vector3.UP, 180.0, Vector2(0.4, 1.0), Vector2(0.3, 0.5),
				s, Vector3.ZERO, 1.0, {"r": 0.6})


## Drenched (BendStatus.drench) for `s`: water dripping off `body` the while (Drip: a few drops every DRIP_S from his shoulders
## and arms, falling).
static func drench(body: Node3D, s: float) -> void:
	if not live() or body == null or not is_instance_valid(body):
		return
	for c in body.get_children():
		if c is Drip:
			(c as Drip).life = maxf((c as Drip).life, (c as Drip).t + s)
			return
	var d := Drip.new()
	d.name = "Drip"
	d.life = s
	body.add_child(d)


class Drip:
	extends Node3D

	const DRIP_S := 0.12
	var life := 1.5
	var t := 0.0
	var _next := 0.0

	func _process(dt: float) -> void:
		t += dt
		_next -= dt
		if _next <= 0.0:
			_next = DRIP_S
			var pool := BendLooks._pool()
			var p := get_parent() as Node3D
			if pool != null and p != null:
				pool.shoot("drop", p.global_position + Vector3.UP * randf_range(0.6, 1.5), 4, Vector3.DOWN, 25.0, Vector2(0.5, 1.5),
						Vector2(0.04, 0.08), 0.45, Vector3(0, -9.0, 0), 0.0, {"r": 0.25})
		if t >= life:
			queue_free()


## The hold on `body`'s feet broken early (a hit that launched him: BendStatus.unbind): its look breaks up at once, a puff
## where it held.
static func bind_end(body: Node3D) -> void:
	if not live() or body == null or not is_instance_valid(body):
		return
	var lk: Variant = body.get_meta(BindLook.META) if body.has_meta(BindLook.META) else null
	if lk is BindLook and is_instance_valid(lk):
		(lk as BindLook).finish()
	var pool := _pool()
	if pool != null:
		pool.shoot("puff_dust", body.global_position + Vector3.UP * 0.1, 8, Vector3.UP, 80.0, Vector2(1.0, 2.5),
				Vector2(0.2, 0.4), 0.5, Vector3.ZERO, 2.0, {"r": 0.3})


## A bind's look on a body's legs for its hold (bind_feet): solid shapes round the ankles in the binder's matter, rising into
## place in BUILD_S, held, then gone (sunk, melted, faded) in END_S at the hold's end or when the hold breaks (finish). It stays
## where the feet were held (top_level: a held body does not move). One a body (a new hold replaces the last).
class BindLook:
	extends Node3D

	const META := &"bend_bind_look"
	const BUILD_S := 0.08
	const END_S := 0.16
	static var _mats := {}

	var el := ""
	var life := 0.7
	var t := 0.0
	var end_at := -1.0
	var parts: Array[MeshInstance3D] = []
	var rest: Array[Transform3D] = []
	## Fire's shock: its lightning strips (ARCS of them, rebuilt every ARC_S) and the sparks thrown off it every SPARK_S.
	const ARCS := 4
	const ARC_S := 0.04
	const SPARK_S := 0.12
	var arcs: Array[MeshInstance3D] = []
	var arc_t := 0.0
	var spark_t := 0.0

	static func make(body: Node3D, element: String, s: float) -> BindLook:
		var old: Variant = body.get_meta(META) if body.has_meta(META) else null
		if old is BindLook and is_instance_valid(old):
			(old as BindLook).queue_free()
		var lk := BindLook.new()
		lk.el = element
		lk.life = maxf(s, 0.05)
		body.add_child(lk)
		lk.top_level = true
		lk.global_transform = Transform3D(Basis.IDENTITY, body.global_position)
		body.set_meta(META, lk)
		lk._build()
		return lk

	## The game's own toon facets for stone and ice (ToonFx's rock and ice: the stones' and the Spear's look); wind its own.
	static func _mat(kind: String) -> Material:
		if kind == "stone":
			return ToonFx.mat("rock")
		if kind == "ice":
			return ToonFx.mat("ice")
		if _mats.has(kind):
			return _mats[kind]
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.97, 1.0, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[kind] = m
		return m

	func _add(mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.transform = xf
		parts.append(mi)
		rest.append(xf)
		return mi

	func _build() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = get_instance_id()
		match el:
			"earth":
				# (a cuff of stone round the ankles, up the shins: eight chunks low, five up to the knee's foot)
				for i in 13:
					var low := i < 8
					var n := 8 if low else 5
					var a := (float(i if low else i - 8) + rng.randf_range(-0.2, 0.2)) / float(n) * TAU + (0.0 if low else 0.4)
					var r := rng.randf_range(0.2, 0.26) if low else rng.randf_range(0.16, 0.2)
					var s := rng.randf_range(0.22, 0.3) if low else rng.randf_range(0.15, 0.2)
					var b := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))).scaled(Vector3.ONE * s)
					_add(ToonFx.chunk_mesh(i), _mat("stone"), Transform3D(b, Vector3(cos(a) * r, 0.1 if low else 0.32, sin(a) * r)))
			"water":
				# (ice shards leaning in round the ankles, up to the knees, on a disc of ice)
				var disc := CylinderMesh.new()
				disc.top_radius = 0.44
				disc.bottom_radius = 0.48
				disc.height = 0.04
				_add(disc, _mat("ice"), Transform3D(Basis.IDENTITY, Vector3.UP * 0.02))
				for i in 10:
					var a := (float(i) + rng.randf_range(-0.25, 0.25)) / 10.0 * TAU
					var r := rng.randf_range(0.2, 0.27)
					var out := Vector3(cos(a), 0.0, sin(a))
					var lean := Basis(out.cross(Vector3.UP).normalized(), deg_to_rad(rng.randf_range(14.0, 28.0)))
					# (ToonFx's shard points along -z: stood up first, then turned about itself and leant in)
					var b := lean * Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)) * Basis(Vector3.RIGHT, PI * 0.5)
					_add(ToonFx.shard_mesh(rng.randf_range(0.45, 0.7), rng.randf_range(0.06, 0.09), i), _mat("ice"),
							Transform3D(b, out * r + Vector3.UP * 0.02))
			"fire":
				# (lightning crackling up the legs: ARCS jagged strips, each its own mesh, rebuilt every few frames)
				for k in ARCS:
					var m := MeshInstance3D.new()
					m.mesh = ImmediateMesh.new()
					m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					m.extra_cull_margin = 2.0
					add_child(m)
					arcs.append(m)
				_arcs()
			"prison":
				# (a Wind Prison: three of the Wind Ball's spinning bands round his middle, tilted every way, a ball of wind he
				# hangs in)
				for i in 3:
					var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(-35.0 + 35.0 * i))
					var band := _add(ToonFx.band_mesh(1.0, 0.85, 0.5), ToonFx.mat("wind_band_fast"),
							Transform3D(b.scaled(Vector3.ONE * (0.72 + 0.06 * i)), Vector3.UP * 0.95))
					band.set_instance_shader_parameter(&"seed", 0.29 * i + rng.randf())
			_:
				# (a whirl of wind round the legs: two of the Wind Ball's own spinning bands, tilted, the wind shader's noise
				# breaking them up so they read as wind, never as a clean ring drawn round him)
				for i in 2:
					var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(10.0 - 20.0 * i))
					var band := _add(ToonFx.band_mesh(1.0, 0.85, 0.5), ToonFx.mat("wind_band_fast"),
							Transform3D(b.scaled(Vector3.ONE * (0.42 + 0.08 * i)), Vector3.UP * (0.18 + 0.3 * i)))
					band.set_instance_shader_parameter(&"seed", 0.31 * i + rng.randf())
		_pose(0.0)

	func _arcs() -> void:
		for m: MeshInstance3D in arcs:
			var a := randf() * TAU
			var from := Vector3(cos(a) * 0.26, 0.03, sin(a) * 0.26)
			var b := a + randf_range(1.4, 3.4)
			var to := Vector3(cos(b) * 0.18, randf_range(0.5, 1.0), sin(b) * 0.18)
			ToonFx.lightning_strips(m.mesh as ImmediateMesh, from, to)

	## The hold broken: gone now (END_S).
	func finish() -> void:
		if end_at < 0.0:
			end_at = t

	## Each part at its rest, risen u of the way in (0..1) and going g of the way out (0..1).
	func _pose(g: float) -> void:
		var u := clampf(t / BUILD_S, 0.0, 1.0)
		var k := 1.0 - (1.0 - u) * (1.0 - u)
		for i in parts.size():
			var xf: Transform3D = rest[i]
			var p := parts[i]
			match el:
				"earth":
					p.transform = Transform3D(xf.basis.scaled(Vector3.ONE * (1.0 - 0.4 * g)), xf.origin + Vector3.DOWN * (0.3 * (1.0 - k) + 0.25 * g))
				"water":
					p.transform = Transform3D(xf.basis.scaled(Vector3.ONE * maxf(k * (1.0 - 0.8 * g), 0.01)), xf.origin)
				_:
					p.transform = Transform3D(xf.basis.rotated(Vector3.UP, t * (9.0 if i % 2 == 0 else -7.0)), xf.origin)
					p.set_instance_shader_parameter(&"fade", 1.0 - g)

	func _process(dt: float) -> void:
		t += dt
		if end_at < 0.0 and t >= life:
			end_at = t
		var g := clampf((t - end_at) / END_S, 0.0, 1.0) if end_at >= 0.0 else 0.0
		_pose(g)
		if not arcs.is_empty():
			arc_t -= dt
			spark_t -= dt
			if arc_t <= 0.0 and g <= 0.0:
				arc_t = ARC_S
				_arcs()
			if spark_t <= 0.0 and g <= 0.0:
				spark_t = SPARK_S
				var pool := BendLooks._pool()
				if pool != null:
					pool.shoot("spark_elec", global_position + Vector3.UP * randf_range(0.1, 0.6), 10, Vector3.UP, 120.0,
							Vector2(1.0, 3.0), Vector2(0.03, 0.06), 0.25, Vector3.ZERO, 2.0, {"r": 0.25})
			for m: MeshInstance3D in arcs:
				m.visible = g <= 0.0
		if g >= 1.0:
			var body := get_parent()
			if body != null and body.has_meta(META) and body.get_meta(META) == self:
				body.remove_meta(META)
			queue_free()


## Lightning's flash on the caster's hand at `at` (round 2's flash_s: its tell before the strike): a white-blue flash, a
## spray of sparks off the hand, a flash of light; the charge on the hands (charge) ends with it.
static func lightning_flash(body: Node3D, at: Vector3, look := true) -> void:
	for c in body.get_children():
		if c is Charge:
			(c as Charge).end()
	if not live() or not look:
		return
	var pool := _pool()
	if pool == null:
		return
	var c1 := SB_VIOLET if sb_bolt else ELEC
	var c2 := SB_LAVENDER if sb_bolt else Color(0.92, 0.96, 1.0)
	if sb_bolt:
		var fwd := -body.global_basis.z
		_sb_crackle(pool, at, Vector3(fwd.x, 0.15, fwd.z), SB_HAND_FORKS, 0.25)
	pool.play("flash", Transform3D(Basis.IDENTITY, at), 0.25, 0.4, 1.8, c1, c2)
	pool.play("ring", Transform3D(Basis.IDENTITY, at), 0.25, 0.2, 1.1, SB_LAVENDER if sb_bolt else Color(0.9, 0.95, 1.0), c1)
	pool.shoot("star_sb" if sb_bolt else "star", at, 6, Vector3.UP, 180.0, Vector2(0.5, 1.5), Vector2(0.25, 0.4), 0.25,
			Vector3.ZERO, 2.0)
	pool.shoot("spark_sb" if sb_bolt else "spark_elec", at, 28, Vector3.UP, 180.0, Vector2(2.0, 6.0), Vector2(0.025, 0.045), 0.3,
			Vector3(0, -6.0, 0), 2.0)
	pool.light(at, SB_LIGHT if sb_bolt else Color(0.7, 0.82, 1.0), 4.5, 0.25, 6.0)


## Lightning's charge on `body`'s hands while its lock runs (SwayCaster; a bot's mind may call it too): blue sparks crackling
## round the hands and a rising hum (BendSounds lightning_charge, looped), both louder and brighter with `level` (0..1: the
## lock's fill; 1 at the click). Its node (Charge: set level, end()). `sway`: the player's caster (its hands), else the
## body's chest.
static func charge(body: Node3D, sway: Node = null) -> Charge:
	var ch := Charge.new()
	ch.name = "BendCharge"
	ch.sway = sway
	body.add_child(ch)
	return ch


## The Ice Spear's water spear in the rifle hold (the owner, 2026-10-11: "the rifle will be a rifle stance and then water
## conjures in to take the rifles spot like a spear but in water form and then fires it ... turning into a ice lance"): a
## HeldSpear under `body`, the lock's look on the hands (SwayCaster._lock_looks, a pose whose clips row says "held":
## "water_spear"), fed the lock's fill as its `level`.
static func held_spear(body: Node3D, sway: Node = null) -> HeldSpear:
	var hs := HeldSpear.new()
	hs.name = "BendHeldSpear"
	hs.sway = sway
	body.add_child(hs)
	return hs


## Grow's second click (▲) at the caster's hands (`sway`: the player's SwayCaster): a bright ring snapping out and a deeper
## click (BendSounds lock_grow).
static func grow_click(sway: Node) -> void:
	var at := _hands(sway)
	BendSounds.play(&"lock_grow", at, 0.0)
	if not live():
		return
	var body: Variant = sway.get(&"player") if sway != null and is_instance_valid(sway) else null
	if body is Node3D and sway.has_method(&"mode_of"):
		# (the Spellbreak grow on the hands, held under the caster until its lock ends: SwayCaster._end_charge; SbFx)
		var mv := String(sway.get(&"move"))
		var gk := "%s/%s.grown" % [mv, String(sway.call(&"mode_of", mv))]
		SbFx.start(sway, "grow", body, gk, "grow", {})
		if SbFx.fire(body, gk, "grow_click", {"at": at}):
			return
	var pool := _pool()
	if pool != null:
		pool.play("ring", Transform3D(Basis.IDENTITY, at), 0.28, 0.25, 1.1, Color(1.0, 0.95, 0.7), Color(1.0, 1.0, 1.0))
		pool.play("flash", Transform3D(Basis.IDENTITY, at), 0.12, 0.2, 0.6, Color(1.0, 0.95, 0.7), Color.WHITE)


## The Beat (the skill tree's timing rule, only for a wearer of a technique it pays): a cast let go on it, or a Catch's E again
## on it, gives a brief glow on the caster's own hands, his element's colour, and a click (BendSounds lock_grow, soft). `who`
## a SwayCaster (its hands) or a body (its chest). Nothing on anyone else.
static func beat_flash(who: Node, el: String) -> void:
	var at := _hands(who)
	BendSounds.play(&"lock_grow", at, -6.0)
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var tint: Array = GUARD_TINTS.get(el, [Color.WHITE, Color.WHITE])
	pool.play("flash", Transform3D(Basis.IDENTITY, at), 0.1, 0.18, 0.5, tint[0], Color.WHITE)
	pool.play("ring", Transform3D(Basis.IDENTITY, at), 0.16, 0.18, 0.6, tint[1], tint[0])


## A lock held past sputter_s that does not grow: a fizz on the caster's own hands (BendSounds lock_sputter), a few spent
## bits of its element dropping off them.
static func sputter(sway: Node, el: String) -> void:
	var at := _hands(sway)
	BendSounds.play(&"lock_sputter", at, -2.0)
	if not live():
		return
	var pool := _pool()
	if pool == null:
		return
	var key := {"fire": "spark_fire", "water": "drop", "earth": "puff_dust", "air": "puff_air"}.get(el, "puff_air") as String
	pool.shoot(key, at, 10, Vector3.DOWN, 60.0, Vector2(0.5, 1.6), Vector2(0.04, 0.12) if key.begins_with("spark") or key == "drop" \
			else Vector2(0.12, 0.25), 0.5, Vector3(0, -6.0, 0), 1.0)


## Carried wind charged on `body` (air's passive): a spiral of wind round him rising from his feet and a whistle
## (BendSounds carried_whistle).
static func carried(body: Node3D) -> void:
	BendSounds.play(&"carried_whistle", body.global_position + Vector3.UP, -3.0)
	if not live():
		return
	var aura := SbFx.start(body, "carried", body, "passive/carried_wind", "charged", {"node": body, "el": "air",
			"life": float(Bending.passive("air").get("after_s", 0.8))})
	if SbFx.fire(body, "passive/carried_wind", "charge_pop", {"el": "air"}) or aura:
		return                                   # (the Spellbreak charge played instead: SbFx)
	var pool := _pool()
	if pool == null:
		return
	var at := body.global_position + Vector3.UP * 0.9
	pool.play("swirl", Transform3D(Basis.IDENTITY, at), 0.5, 0.5, 1.4, AIR, Color(0.55, 0.78, 1.0))
	pool.shoot("spark_line", body.global_position + Vector3.UP * 0.2, 16, Vector3.UP, 25.0, Vector2(3.0, 6.0),
			Vector2(0.035, 0.05), 0.35, Vector3.ZERO, 3.0, {"r": 0.5, "radial": 1.5})


## Rooted (earth's passive) on `body`: a faint ring of dust at his feet.
static func rooted_dust(body: Node3D) -> void:
	if not live():
		return
	if SbFx.sustain(body, "rooted", body, "rooted", "idle", {"el": "earth"}, 0.9, "take_hold"):
		return                                   # (Rooted's Spellbreak look, kept while it helps: SbFx)
	var pool := _pool()
	if pool == null:
		return
	var foot := body.global_position + Vector3.UP * 0.05
	pool.play("ring", Transform3D(Basis.IDENTITY, foot), 0.5, 0.3, 0.9, DUST, DUST_LIGHT)
	pool.shoot("puff_dust", foot, 5, Vector3.UP, 80.0, Vector2(0.3, 0.7), Vector2(0.15, 0.3), 0.6, Vector3.ZERO, 2.0,
			{"flat": 0.8, "r": 0.4})


## The hands of `sway` (a SwayCaster: its hand_point) or the chest of a body.
static func _hands(sway: Node) -> Vector3:
	if sway != null and is_instance_valid(sway) and sway.has_method(&"hand_point"):
		return sway.call(&"hand_point")
	if sway is Node3D:
		return (sway as Node3D).global_position + Vector3.UP * 1.3
	return Vector3.ZERO


## Under an air bolt (round 4): every every_s while its bolt flies within over_m of the deck under it, a thin line of dust
## rises along the stretch it flew (the pool's puff_dust laid along it). No marker: the dust is the air's own.
class AirDust:
	extends Node3D

	var _last := Vector3.INF
	var _t := 0.0

	func _process(dt: float) -> void:
		_t -= dt
		if _t > 0.0:
			return
		var ad := ToonFx.looks("air_dust")
		_t = float(ad.get("every_s", 0.1))
		var p := global_position
		var was := _last
		_last = p
		if not was.is_finite() or not is_inside_tree():
			return
		var w := get_world_3d()
		if w == null:
			return
		var over := float(ad.get("over_m", 1.5))
		var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * over, 1)
		var h := w.direct_space_state.intersect_ray(q)
		if h.is_empty():
			return
		var pool := BendLooks._pool()
		if pool == null:
			return
		var seg := Vector3(p.x - was.x, 0.0, p.z - was.z)
		var l := seg.length()
		if l < 0.05 or l > 8.0:
			return
		var fwd := seg / l
		var x := Vector3.UP.cross(fwd).normalized()
		var foot := Vector3((p.x + was.x) * 0.5, (h.position as Vector3).y + 0.05, (p.z + was.z) * 0.5)
		pool.shoot("puff_dust", foot, 7, Vector3.UP, 15.0, Vector2(0.4, 1.1), Vector2(0.12, 0.26), 0.5, Vector3.ZERO, 1.5,
				{"box": Vector3(0.04, 0.02, l * 0.5), "basis": Basis(x, Vector3.UP, fwd)})


## The Kick's own (round 4): a scorch left on the deck every scorch_every_m of its path (fading over scorch_s), and past the
## deck's lip its embers spilling and falling.
class WaveFx:
	extends Node3D

	var base_w := 1.2
	var _last := Vector3.INF
	var _acc := 0.0
	var _spill := 0.0

	func _process(dt: float) -> void:
		var pool := BendLooks._pool()
		if pool == null:
			return
		var fw := ToonFx.looks("floor_wave")
		var p := global_position
		var deck := _deck(p)
		if _last.is_finite():
			_acc += Vector2(p.x - _last.x, p.z - _last.z).length()
		_last = p
		var w := base_w * absf((get_parent() as Node3D).scale.x) if get_parent() is Node3D else base_w
		if _acc >= float(fw.get("scorch_every_m", 1.1)) or _acc == 0.0:
			_acc = 0.0001
			if deck.is_finite():
				pool.mark("scorch", deck, Vector3.UP, clampf(float(fw.get("scorch_size_m", 1.3)) * w / 2.2 + 0.4, 0.8, 2.2),
						float(fw.get("scorch_s", 2.0)))
		_spill -= dt
		if not deck.is_finite() and _spill <= 0.0:
			_spill = float(fw.get("spill_every_s", 0.05))
			pool.shoot("spark_fire", p + Vector3.UP * 0.15, int(fw.get("spill_n", 8)), Vector3.DOWN, 50.0, Vector2(0.5, 2.0),
					Vector2(0.03, 0.06), 0.9, Vector3(0.0, -9.0, 0.0), 0.3, {"box": Vector3(w * 0.5, 0.05, 0.1),
					"basis": global_basis.orthonormalized()})

	## The deck under `p` (its point), INF past the lip.
	func _deck(p: Vector3) -> Vector3:
		var w := get_world_3d()
		if w == null:
			return Vector3.INF
		var h := w.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p + Vector3.DOWN * 0.5, 1))
		return h.position if not h.is_empty() else Vector3.INF


## Lightning's charge on a body's hands (charge): sparks round the hands and a looped hum, both by `level`. end() lets it go.
class Charge:
	extends Node3D

	var sway: Node
	var level := 0.0
	## Its hum was started (the tests: headless audio may never report playing).
	var started := false
	var _sparks: GPUParticles3D
	var _hum: AudioStreamPlayer3D
	var _glow: MeshInstance3D
	var _t := 0.0
	## SB_BOLT: crackling arcs of the Spellbreak-shaded bolt at the hands instead of the spark shards (their next one in s).
	var _arcs := false
	var _arc_t := 0.0

	func _ready() -> void:
		top_level = true
		_place()
		_hum = BendSounds.loop_player(&"lightning_charge", self)
		if _hum != null:
			_hum.volume_db = -14.0
			_hum.play()
			started = true
		if not BendLooks.live():
			return
		var mv := String(sway.get(&"move")) if sway != null and is_instance_valid(sway) and "move" in sway else ""
		var ck := "%s/%s" % [mv, String(sway.call(&"mode_of", mv))] if mv != "" and sway.has_method(&"mode_of") else "fire_arc/lightning"
		if SbFx.start(self, "charge", get_parent(), ck, "charge", {"node": self}):
			return                               # (the Spellbreak charge follows this node: SbFx; the hum stays)
		_arcs = BendLooks.sb_bolt
		if not _arcs:
			_sparks = BendLooks.emitter(self, "lightning", Vector3.ONE * 0.18, 18, 0.25, 0.6, 0.04)
		_glow = MeshInstance3D.new()
		_glow.mesh = ToonFx.quad()
		_glow.material_override = ToonFx.mat("orb")
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.set_instance_shader_parameter(&"tint", SB_VIOLET if _arcs else ELEC)
		_glow.set_instance_shader_parameter(&"tint2", SB_LAVENDER if _arcs else Color(0.85, 0.92, 1.0))
		_glow.scale = Vector3.ONE * 0.05
		add_child(_glow)

	func _place() -> void:
		var at := Vector3.INF
		if sway != null and is_instance_valid(sway) and sway.has_method(&"hand_point"):
			at = sway.call(&"hand_point")
		if not at.is_finite():
			var b := get_parent() as Node3D
			at = b.global_position + Vector3.UP * 1.3 if b != null else Vector3.ZERO
		global_position = at

	func _process(dt: float) -> void:
		_t += dt
		_place()
		var k := clampf(level, 0.0, 1.0)
		if _hum != null:
			_hum.volume_db = lerpf(-14.0, 2.0, k)
			_hum.pitch_scale = lerpf(0.85, 1.15, k)
		if _sparks != null:
			_sparks.amount_ratio = lerpf(0.2, 1.0, k)
		if _glow != null:
			_glow.scale = Vector3.ONE * lerpf(0.08, 0.3 if _arcs else 0.4, k) * (1.0 + 0.15 * sin(_t * 40.0))
		if _arcs:
			# (an arc off the hands, out in front of him, every 0.16 s at the lock's start down to every 0.06 s at the click,
			# longer as it fills)
			_arc_t -= dt
			if _arc_t <= 0.0:
				_arc_t = lerpf(0.16, 0.06, k)
				var b := get_parent() as Node3D
				var way := (-b.global_basis.z + Vector3.UP * 0.4) if b != null else Vector3.UP
				BendLooks._sb_crackle(BendLooks._pool(), global_position, way, 1, 0.12,
						Vector2(0.3, 0.5) + Vector2.ONE * 0.25 * k, SB_FORK_WIDTH, 1.2, 1)

	## Whether its hum plays (the tests).
	func humming() -> bool:
		return _hum != null and started and is_inside_tree()

	func end() -> void:
		if is_queued_for_deletion():
			return
		if _hum != null:
			_hum.stop()
		if _sparks != null:
			_sparks.emitting = false
		queue_free()


## The Ice Spear's water spear (BendLooks.held_spear): a shaft of flowing water with a pointed head, laid along the rifle hold
## from behind the right hand (at the cheek, on the stock) through the left (under the barrel) and on past it, drawn out of
## the hands as the lock fills (`level`), drips falling off it, a glint at its point once full. end() (the lock over:
## SwayCaster._end_charge): cast, it stays in the hands to the strike (the pose's struck), then freezes as it leaves (a frost
## flash at its head, BendSounds ice_freeze: the Ice Spear's own bolt, the ice lance, flies from there); broken, it falls
## as water.
class HeldSpear:
	extends Node3D

	var sway: Node
	var level := 0.0
	## Behind the stock hand and past the barrel hand (m), the shaft's radius and the head's length at full.
	const BACK_M := 0.1
	const AHEAD_M := 0.34
	const SHAFT_R := 0.034
	const HEAD_M := 0.24
	## The fill over which it is drawn out of the hands.
	const GROW := Vector2(0.08, 0.55)
	## Cast: how long it may wait for the strike before it goes anyway (s).
	const STRIKE_WAIT_S := 0.6
	static var _cone: Mesh
	var _shaft: MeshInstance3D
	var _head: MeshInstance3D
	var _drips: GPUParticles3D
	var _glint: MeshInstance3D
	var _bones := Vector2i(-2, -2)       ## r_palm, l_palm
	## The caster's skeleton, and the two hands (world) as its last update left them: after every modifier, the cast's pose
	## included (read in its skeleton_updated, as SwayPose reads the palms; outside it the bones are the tree's own pose).
	var _sk: Skeleton3D
	var _rp := Vector3.INF
	var _lp := Vector3.INF
	var _t := 0.0
	var _ending := false
	var _end_t := 0.0
	var _gone := false
	## Listening for the pose's strike once the lock is cast (end()); let go when it leaves the tree.
	var _struck_cb := Callable()

	func _ready() -> void:
		top_level = true
		visible = false
		var b := get_parent()
		_sk = b.get(&"skeleton") as Skeleton3D if b != null and &"skeleton" in b else null
		if _sk != null:
			_sk.skeleton_updated.connect(_on_skeleton_updated)
		if BendLooks.live():
			_build()
		_place()
		BendSounds.play(&"water_slosh", global_position, -6.0)

	func _exit_tree() -> void:
		if _sk != null and is_instance_valid(_sk) and _sk.skeleton_updated.is_connected(_on_skeleton_updated):
			_sk.skeleton_updated.disconnect(_on_skeleton_updated)
		var p: Node = sway.get(&"pose") if sway != null and is_instance_valid(sway) else null
		if _struck_cb.is_valid() and p != null and is_instance_valid(p) and p.is_connected(&"struck", _struck_cb):
			p.disconnect(&"struck", _struck_cb)

	func _on_skeleton_updated() -> void:
		if _bones.x == -2:
			_bones = Vector2i(_sk.find_bone("r_palm"), _sk.find_bone("l_palm"))
		if _bones.x < 0 or _bones.y < 0:
			return
		_rp = _sk.global_transform * _sk.get_bone_global_pose(_bones.x).origin
		_lp = _sk.global_transform * _sk.get_bone_global_pose(_bones.y).origin
		if not _gone:
			_place()

	func _build() -> void:
		_shaft = BendLooks._mesh(self, ToonFx.sphere(16), ToonFx.mat("water"))
		_shaft.rotation.x = -PI / 2.0                 # (the sphere's poles, its flow's way, along the spear)
		_shaft.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
		# (the head a cone of the same water, its point ahead: it is water until it leaves the hands)
		if _cone == null:
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 1.0
			cm.height = 1.0
			cm.radial_segments = 12
			cm.rings = 2
			_cone = cm
		_head = BendLooks._mesh(self, _cone, ToonFx.mat("water"))
		_head.rotation.x = -PI / 2.0                  # (its point, the cone's top, ahead)
		_head.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
		_drips = BendLooks.emitter(self, "water", Vector3(0.025, 0.025, 0.3), 7, 0.4, -0.3, 0.045)
		_glint = BendLooks._mesh(self, ToonFx.quad(), ToonFx.mat("star_still"))
		_glint.visible = false

	## The stock hand and the barrel hand (world; INF before the skeleton's first update).
	func _hands() -> Array:
		return [_rp, _lp]

	func _place() -> void:
		var h := _hands()
		var rear: Vector3 = h[0]
		var front: Vector3 = h[1]
		var b := get_parent() as Node3D
		if not rear.is_finite() or not front.is_finite():
			if b == null:
				return
			front = b.global_position + Vector3.UP * 1.35 - b.global_basis.z * 0.45
			rear = front + b.global_basis.z * 0.45
		var way := front - rear
		# (the hands close together, through the scoop: the body's own way ahead)
		var fwd := -b.global_basis.z if b != null else Vector3.FORWARD
		way = fwd.lerp(way.normalized(), smoothstep(0.12, 0.3, way.length())) if way.length() > 1e-4 else fwd
		way = way.normalized()
		var grow := smoothstep(GROW.x, GROW.y, level)
		var a := rear - way * BACK_M
		var z := front + way * AHEAD_M
		var mid := (a + z) * 0.5
		var full := a.distance_to(z)
		var up := Vector3.UP if absf(way.dot(Vector3.UP)) < 0.98 else Vector3.BACK
		global_transform = Transform3D(Basis.looking_at(way, up), mid)
		visible = grow > 0.01 and not _gone
		var pulse := 1.0 + (0.06 * sin(_t * 14.0) if level >= 1.0 else 0.0)
		var len_now := full * grow
		if _shaft != null:
			_shaft.scale = Vector3(SHAFT_R * (0.45 + 0.55 * grow) * pulse, maxf(len_now * 0.5, 0.01), SHAFT_R * (0.45 + 0.55 * grow) * pulse)
		if _head != null:
			# (the cone: twice the shaft's girth at its base, HEAD_M long, its base just inside the shaft's end)
			var hs := HEAD_M * grow
			_head.scale = Vector3(SHAFT_R * 2.0 * grow * pulse, maxf(hs, 0.005), SHAFT_R * 2.0 * grow * pulse)
			_head.position = Vector3(0.0, 0.0, -len_now * 0.5 - hs * 0.4)
		if _drips != null:
			_drips.amount_ratio = lerpf(0.3, 1.0, grow)
		if _glint != null:
			_glint.visible = level >= 1.0
			_glint.position = Vector3(0.0, 0.0, -len_now * 0.5 - HEAD_M * 0.9)
			_glint.scale = Vector3.ONE * (0.18 + 0.05 * sin(_t * 20.0))

	## The head's point (world).
	func tip() -> Vector3:
		return global_transform * Vector3(0.0, 0.0, -(_shaft.scale.y if _shaft != null else 0.4) - HEAD_M * 0.8)

	func _process(dt: float) -> void:
		_t += dt
		if _gone:
			return
		if _ending:
			_end_t += dt
			var p: Node = sway.get(&"pose") if sway != null and is_instance_valid(sway) else null
			var phase := String(p.get(&"phase")) if p != null and is_instance_valid(p) else ""
			if phase != "release":
				_fall()                                  # (broken, or the pose gone: it falls as water)
				return
			if _end_t >= STRIKE_WAIT_S:
				_freeze()
				return
		_place()

	## The lock over (SwayCaster._end_charge): cast, it waits in the hands for the strike; else it falls.
	func end() -> void:
		if _ending or _gone or is_queued_for_deletion():
			return
		_ending = true
		_end_t = 0.0
		var p: Node = sway.get(&"pose") if sway != null and is_instance_valid(sway) else null
		if p != null and is_instance_valid(p) and p.has_signal(&"struck"):
			_struck_cb = func(_m: String) -> void: _freeze()
			p.connect(&"struck", _struck_cb, CONNECT_ONE_SHOT)

	## Thrown: it freezes into the lance as it leaves (the Ice Spear's bolt flies from the hand).
	func _freeze() -> void:
		if _gone:
			return
		_place()
		_gone = true
		var at := tip() if visible else global_position
		BendSounds.play(&"ice_freeze", at, -4.0)
		var pool := BendLooks._pool() if BendLooks.live() else null
		if pool != null and visible:
			pool.play("flash", Transform3D(Basis.IDENTITY, at), 0.14, 0.25, 0.9, BendLooks.ICE, Color(0.92, 0.99, 1.0))
			pool.shoot("puff_frost", global_position, 8, -global_basis.z, 40.0, Vector2(0.3, 1.0), Vector2(0.12, 0.22), 0.45,
					Vector3.ZERO, 3.0, {"box": Vector3(0.04, 0.04, 0.4), "basis": global_basis})
			pool.shoot("star", at, 6, -global_basis.z, 50.0, Vector2(0.8, 2.0), Vector2(0.06, 0.12), 0.35, Vector3.ZERO, 2.0)
		_finish()

	## Broken: it falls from the hands as water.
	func _fall() -> void:
		if _gone:
			return
		_gone = true
		var pool := BendLooks._pool() if BendLooks.live() else null
		if pool != null and visible:
			pool.shoot("drop", global_position, 14, Vector3.DOWN, 50.0, Vector2(0.4, 1.4), Vector2(0.04, 0.1), 0.6,
					Vector3(0, -9.0, 0), 0.6, {"box": Vector3(0.04, 0.04, 0.35), "basis": global_basis})
		_finish()

	func _finish() -> void:
		visible = false
		if _drips != null:
			_drips.emitting = false
		var tree := get_tree()
		if tree != null:
			tree.create_timer(0.6).timeout.connect(queue_free)
		else:
			queue_free()


## Every effect played once 3 m before `cam`, a few mm big (each shader, particle program and pipeline compiled while the
## level loads: measured 2026-10-05, the first fire wall, tornado and bubble each froze a frame for 1 to 3.4 s on this Mac
## without it). Every burst, blast, body, trail, emitter, zone look, shape, mark and the lightning, a group a frame (WARM_GROUPS:
## a kind's bursts and blasts, its bodies, its trail; the emitters a few at a time; each zone look alone), so what is compiled
## is spread over the frames the loading screen covers and none of them holds the window for long (all in one frame it was
## one frame of 0.2-0.8 s warm and seconds cold); then WARM_FRAMES more frames and they are taken away (the pool keeps its
## emitters for the match). `progress` (optional) is called with 0..1 as the groups go. Call once the level stands; it runs
## on by itself (await it to know when it is through).
const WARM_FRAMES := 6
## The emitters warmed in one frame.
const WARM_EMITTERS := 4
const WARM_EMITTER_KINDS := ["fire", "water", "smoke", "dust", "steam", "ice", "embers", "sparkle", "debris", "foam", "lightning",
		"air"]
const WARM_ZONES := ["bubble", "air_shield", "water_wall", "fire_wall", "burn", "ice_patch", "smoke", "tornado", "vacuum",
		"wind_wall", "puddle", "redirect", "parry"]

static func warm_up(cam: Camera3D, progress := Callable()) -> void:
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
	# (the groups, each a callable run on its own frame)
	var groups: Array[Callable] = []
	groups.append(func() -> void:
		for el: String in Bending.ELEMENTS:
			pool.play("monsoon_seal", xf, 0.1, 0.01, 0.01, MonsoonIdentity.accent(el), Color.WHITE, MonsoonIdentity.mesh(el)))
	for k: String in KINDS:
		groups.append(func() -> void:
			burst(at, k, 2, Vector3.UP, 30.0, 0.1, 0.01)
			blast(at, Vector3.FORWARD, 60.0, 0.05, k)
			blast(at, Vector3.FORWARD, 360.0, 0.05, k))
		groups.append(func() -> void:
			for long in [false, true]:
				var body := Node3D.new()
				holder.add_child(body)
				bolt_body(body, k, 0.2, long)
			for shape in ["disc", "spear", "crescent"]:
				var body2 := Node3D.new()
				holder.add_child(body2)
				bolt_body(body2, k, 0.2, false, shape)
			if k == "fire":
				floor_wave_body(holder, 0.05, 0.05))
		groups.append(func() -> void:
			var t := trail(holder, k, 0.01)
			if t != null:
				made.append(t)
				for c in t.get_children():
					if c is ToonRibbon:
						(c as ToonRibbon).prime(at, at + Vector3.LEFT * 0.05))
	groups.append(func() -> void: burst(at, "steam", 2, Vector3.UP, 30.0, 0.1, 0.01))
	for i in range(0, WARM_EMITTER_KINDS.size(), WARM_EMITTERS):
		var some := WARM_EMITTER_KINDS.slice(i, i + WARM_EMITTERS)
		groups.append(func() -> void:
			for e: String in some:
				emitter(holder, e, Vector3.ONE * 0.1, 2, 0.2, 0.1, 0.01))
	for z: String in WARM_ZONES:
		groups.append(func() -> void:
			var bz := BendZone.new()
			bz.kind = z
			bz.owner_node = holder
			bz.life_s = 0.2
			bz.size = Vector3(1.0, 1.0, 0.3)
			bz.radius = 0.5
			bz.r2 = z in ["redirect", "parry"]          # (round 2's guard looks: the Turn's ring, the Parry's)
			holder.add_child(bz)
			bz.set_physics_process(false)          # (a look only: it neither burns, lifts nor ends anyone)
			bz._look())
	groups.append(func() -> void:
		for m in ["scorch", "cracks", "frost", "wet"]:
			pool.mark(m, at, Vector3.UP, 0.01, 0.2)
		for sh in ["flash", "ring", "swirl"]:
			pool.play(sh, xf, 0.2, 0.01, 0.01)
		pool.play("crown", xf, 0.2, 0.01, 0.01, Color.WHITE, Color.WHITE, ToonFx.band_mesh(1.0, 1.5, 1.0))
		_warm_lightning(pool, at))
	# (the Spellbreak effects listed in data/bending/sb_fx: SbFx.prewarm builds each and draws it once, its share of the
	# progress after the cel groups')
	var sb_n := SbFx.ids().size()
	var toon_k := 1.0 if sb_n == 0 else 0.55
	for i in groups.size():
		if not is_instance_valid(holder) or not holder.is_inside_tree():
			return                               # (the level left meanwhile)
		groups[i].call()
		if progress.is_valid():
			progress.call(toon_k * float(i + 1) / float(groups.size() + 1))
		await tree.process_frame
	if sb_n > 0:
		await SbFx.prewarm(cam, func(f: float) -> void:
			if progress.is_valid():
				progress.call(toon_k + (1.0 - toon_k) * f * 0.95))
	for i in WARM_FRAMES:
		await tree.process_frame
	if progress.is_valid():
		progress.call(1.0)
	for t in made.slice(1):
		if is_instance_valid(t):
			stop_trail(t as GPUParticles3D)
	if is_instance_valid(holder):
		holder.queue_free()


static func _scene() -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.current_scene if ml != null else null
