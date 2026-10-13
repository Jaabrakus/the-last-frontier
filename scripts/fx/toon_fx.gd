class_name ToonFx
extends RefCounted
## The cel look of the bent elements' effects (BendLooks, BendZone; 2D animated effects stood up in 3D): hard-edged colour
## bands, bold shapes, no soft dots. Everything here is made once and shared: the shaders (shaders/bend_fx/), their
## materials by key (mat), the meshes (a flame's quad, bands, shards, rock chunks, a crescent), the particle recipes the
## pool plays (recipe: draw mesh, material, process template), and one tiling noise every shader reads.
## style: "cel" (hard bands) or "ink" (the same with a dark outline round every shape, a drawn look). A tool can set it with
## Engine meta "bend_fx_style" before the first effect is made.
## The per-scene pool that plays them, caps them and reuses their nodes: ToonFxPool. The trail along a line: ToonRibbon.
## Round 4 (LOOKS; the owner: "not blocky sprites", nothing of your own filling your view; data/bending/fx_looks.json, looks):
## the flames blend soft (toon_flame, flame_field) over a soft additive glow (flame_glow, toon_glow), Breath's smoke is a lit
## volume (puff_smoke, toon_smoke), every effect thins in a screen-door near the camera (near_alpha mirrors the shaders'
## near_cut), a bolt's core grows at range (range_scale mirrors the shaders'), each bolt casts its own shadow from a
## shadow-only core (shadow_mat), and is_own tells your own body (your own Wind Guard and walls are drawn for your eye).

const SHADERS := {
	"monsoon_seal": preload("res://shaders/bend_fx/monsoon_seal.gdshader"),
	"flame": preload("res://shaders/bend_fx/toon_flame.gdshader"),
	"puff": preload("res://shaders/bend_fx/toon_puff.gdshader"),
	"spark": preload("res://shaders/bend_fx/toon_spark.gdshader"),
	"water": preload("res://shaders/bend_fx/toon_water.gdshader"),
	"wind": preload("res://shaders/bend_fx/toon_wind.gdshader"),
	"facet": preload("res://shaders/bend_fx/toon_facet.gdshader"),
	"bolt": preload("res://shaders/bend_fx/toon_bolt.gdshader"),
	"sprite": preload("res://shaders/bend_fx/toon_sprite.gdshader"),
	"mark": preload("res://shaders/bend_fx/toon_mark.gdshader"),
	"glow": preload("res://shaders/bend_fx/toon_glow.gdshader"),
	"smoke": preload("res://shaders/bend_fx/toon_smoke.gdshader"),
}
## The looks' numbers (round 4).
const LOOKS_PATH := "res://data/bending/fx_looks.json"

static var style := "cel"
## The effects' own dice (their seeds, jitters, forks): never the global RNG, so drawing them (or not, headless) leaves the
## game's own rolls (a caster's spread, a bot's pick) as they were under a test's seed.
static var vis_rng := RandomNumberGenerator.new()
## Every effect's brightness (the shaders' fx_gain): set_gain; 1 by default (RingLook lowers it at night).
static var gain := 1.0

static var _noise: Texture2D
static var _mats := {}
static var _meshes := {}
static var _recipes := {}
static var _style_used := ""
static var _looks := {}
static var _shadow_mat: StandardMaterial3D


## The style in force: the Engine meta a tool set, else `style`.
static func style_now() -> String:
	return String(Engine.get_meta(&"bend_fx_style", style)) if Engine.has_meta(&"bend_fx_style") else style


## A tiling noise (128 px, made once, synchronously: no frame waits for it).
static func noise() -> Texture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3
		n.frequency = 0.035
		n.seed = 4127
		var img := n.get_seamless_image(128, 128, false, false, 0.1, true)
		img.convert(Image.FORMAT_L8)
		img.generate_mipmaps()
		_noise = ImageTexture.create_from_image(img)
	return _noise


## The shared material of `key` (see the match below for the keys).
static func mat(key: String) -> ShaderMaterial:
	var s := style_now()
	if s != _style_used:
		_mats.clear()
		_recipes.clear()
		_style_used = s
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	var p := {}
	match key:
		"monsoon_seal":
			m.shader = SHADERS.monsoon_seal
		"flame":
			m.shader = SHADERS.flame
		"flame_strip":
			m.shader = SHADERS.flame
			p = {"mode": 1, "speed": 3.2, "nscale": Vector2(1.0, 2.6), "turb": 1.0, "taper": 0.1}
		"flame_low":
			m.shader = SHADERS.flame
			p = {"speed": 1.8, "turb": 1.1, "nscale": Vector2(1.4, 1.1)}
		"flame_wave":
			# (round 4: the Kick's rows, their heat in each instance's colour)
			m.shader = SHADERS.flame
			p = {"speed": 1.8, "turb": 1.0, "nscale": Vector2(1.4, 1.1), "heat_on": 1.0}
		"flame_lip":
			m.shader = SHADERS.flame
			p = {"mode": 2, "speed": 3.0, "turb": 0.9, "nscale": Vector2(1.0, 2.2), "glow": 2.6, "embers": 0.0}
		"flame_orb":
			# (round 4: a fireball's core, soft-edged; drawn over its tongues)
			m.shader = SHADERS.flame
			p = {"mode": 3, "glow": 2.4}
			m.render_priority = 1
		"flame_glow":
			m.shader = SHADERS.glow
			p = {"strength": float(looks("flame").get("glow", 0.55))}
			m.render_priority = -1                       # (under its flames: drawn first)
		"puff_fire":
			m.shader = SHADERS.puff
			p = {"mode": 0, "glow": 1.8}
		"puff_steam":
			m.shader = SHADERS.puff
			p = {"mode": 1, "c_a": Color(1.0, 1.0, 1.0), "c_b": Color(0.84, 0.88, 0.93), "c_c": Color(0.6, 0.67, 0.77),
					"c_ink": Color(0.25, 0.3, 0.38)}
		"puff_smoke":
			# (round 4: a lit volume, its own shader; the smoke kind only)
			var sm := looks("smoke")
			var gk: Array = sm.get("grow", [0.85, 1.35])
			m.shader = SHADERS.smoke
			p = {"curl": float(sm.get("curl", 1.6)), "grow_k": Vector2(float(gk[0]), float(gk[1])), "tint_k": float(sm.get("tint", 0.55)),
					"deck_fade_m": float(sm.get("deck_fade_m", 0.6)), "opacity": float(sm.get("opacity", 0.92))}
		"puff_dust":
			m.shader = SHADERS.puff
			p = {"mode": 1, "c_a": Color(0.9, 0.8, 0.62), "c_b": Color(0.7, 0.58, 0.43), "c_c": Color(0.46, 0.37, 0.27),
					"c_ink": Color(0.2, 0.14, 0.09)}
		"puff_frost":
			m.shader = SHADERS.puff
			p = {"mode": 1, "c_a": Color(1.0, 1.0, 1.0), "c_b": Color(0.76, 0.92, 1.0), "c_c": Color(0.45, 0.7, 0.95),
					"c_ink": Color(0.1, 0.25, 0.45)}
		"puff_air":
			m.shader = SHADERS.puff
			p = {"mode": 1, "c_a": Color(1.0, 1.0, 1.0), "c_b": Color(0.88, 0.95, 1.0), "c_c": Color(0.7, 0.83, 0.95),
					"c_ink": Color(0.3, 0.45, 0.6), "wobble": 0.6}
		"foam":
			m.shader = SHADERS.puff
			p = {"mode": 1, "c_a": Color(1.0, 1.0, 1.0), "c_b": Color(0.82, 0.94, 1.0), "c_c": Color(0.5, 0.76, 0.98),
					"c_ink": Color(0.05, 0.2, 0.45)}
		"drop":
			m.shader = SHADERS.puff
			p = {"mode": 2, "c_a": Color(0.62, 0.9, 1.0), "c_b": Color(0.22, 0.6, 1.0), "c_c": Color(0.08, 0.33, 0.8),
					"c_d": Color(1.0, 1.0, 1.0), "c_ink": Color(0.02, 0.1, 0.3), "wobble": 0.12}
		"spark_fire":
			m.shader = SHADERS.spark
			p = {"mode": 0, "c_core": Color(1.0, 0.95, 0.65), "glow": 2.6, "stretch": 4.5}
		"spark_elec":
			m.shader = SHADERS.spark
			p = {"mode": 0, "c_core": Color(1.0, 1.0, 1.0), "glow": 4.5, "rim_glow": 1.8, "stretch": 6.0}
		"spark_line":
			m.shader = SHADERS.spark
			p = {"mode": 0, "c_core": Color(1.0, 1.0, 1.0), "glow": 1.3, "rim_glow": 1.0, "stretch": 12.0}
		"spark_sb":
			# (the Spellbreak-shaded bolt's sparks, BendLooks.SB_BOLT: spark_elec's shader (nothing new to compile), a
			# lavender core in the bolt's violet)
			m.shader = SHADERS.spark
			p = {"mode": 0, "c_core": Color(0.8, 0.72, 1.0), "glow": 3.2, "rim_glow": 1.8, "stretch": 6.0}
		"star":
			m.shader = SHADERS.spark
			p = {"mode": 1, "c_core": Color(1.0, 1.0, 1.0), "glow": 3.0, "rim_glow": 1.6}
		"star_sb":
			m.shader = SHADERS.spark
			p = {"mode": 1, "c_core": Color(0.84, 0.78, 1.0), "glow": 2.6, "rim_glow": 1.6}
		"star_still":
			m.shader = SHADERS.spark
			p = {"mode": 1, "c_core": Color(1.0, 1.0, 1.0), "glow": 3.0, "rim_glow": 1.6, "twinkle": 1.0}
		"water":
			m.shader = SHADERS.water
			p = {"wobble": 0.03, "flow": Vector2(0.0, -1.6), "nscale": Vector2(2.0, 1.0)}
		"water_wall":
			m.shader = SHADERS.water
			p = {"wobble": 0.06, "flow": Vector2(0.0, 0.45), "nscale": Vector2(5.0, 0.7), "foam": 0.8, "rim": 0.6}
		"bubble":
			m.shader = SHADERS.water
			p = {"wobble": 0.05, "flow": Vector2(0.12, 0.0), "nscale": Vector2(1.2, 4.0), "foam": 0.84, "rim": 0.42,
					"alpha_mul": 0.5, "c_shade": Color(0.16, 0.5, 0.95, 0.55), "c_body": Color(0.3, 0.66, 1.0, 0.5)}
		"water_strip":
			m.shader = SHADERS.water
			p = {"mode": 1, "flow": Vector2(-2.0, 0.0), "nscale": Vector2(3.0, 1.0), "foam": 0.8, "rim": 0.55}
		"wind_band":
			m.shader = SHADERS.wind
			p = {"mode": 0, "spin": 5.0, "nscale": Vector2(2.0, 0.7), "streak": 0.62}
		"wind_band_slow":
			m.shader = SHADERS.wind
			p = {"mode": 0, "spin": 2.6, "nscale": Vector2(3.0, 0.7), "streak": 0.58}
		"wind_band_fast":
			m.shader = SHADERS.wind
			p = {"mode": 0, "spin": 9.0, "nscale": Vector2(2.0, 0.8), "streak": 0.55}
		"wind_funnel":
			m.shader = SHADERS.wind
			p = {"mode": 0, "spin": 7.0, "nscale": Vector2(2.5, 0.9), "streak": 0.74}
		"wind_strip":
			m.shader = SHADERS.wind
			p = {"mode": 1, "speed": 2.0, "nscale": Vector2(1.5, 0.4), "streak": 0.25}
		"ice_strip":
			m.shader = SHADERS.wind
			p = {"mode": 1, "speed": 2.0, "nscale": Vector2(1.5, 0.4), "streak": 0.25,
					"c_main": Color(0.92, 0.99, 1.0, 0.95), "c_edge": Color(0.45, 0.78, 1.0, 0.8)}
		"dust_strip":
			m.shader = SHADERS.wind
			p = {"mode": 1, "speed": 2.0, "nscale": Vector2(1.5, 0.4), "streak": 0.3,
					"c_main": Color(0.86, 0.76, 0.6, 0.9), "c_edge": Color(0.62, 0.5, 0.38, 0.7), "c_ink": Color(0.25, 0.18, 0.1)}
		"wind_arc":
			m.shader = SHADERS.wind
			p = {"mode": 2, "speed": 0.0, "nscale": Vector2(1.6, 0.6), "streak": 0.18, "glow": 1.1}
		"wind_arc_slice":
			# (the Slice's blade: a deeper blue edge and an ink line, so it reads on the pale planks and apart from the Gust's
			# pale wave; the move review 2026-10-12)
			m.shader = SHADERS.wind
			p = {"mode": 2, "speed": 0.0, "nscale": Vector2(1.6, 0.6), "streak": 0.12, "glow": 1.25,
					"c_edge": Color(0.3, 0.6, 1.0, 0.9), "c_ink": Color(0.12, 0.28, 0.55), "ink": 0.7}
		"wind_arc_pull":
			# (the Pull's hook: teal, inked, its curve facing back to the caster)
			m.shader = SHADERS.wind
			p = {"mode": 2, "speed": 0.0, "nscale": Vector2(1.6, 0.6), "streak": 0.15, "glow": 1.15,
					"c_main": Color(0.85, 1.0, 0.97, 0.92), "c_edge": Color(0.25, 0.75, 0.75, 0.85), "c_ink": Color(0.08, 0.35, 0.38),
					"ink": 0.6}
		"ice":
			m.shader = SHADERS.facet
			p = {"c_light": Color(0.96, 1.0, 1.0), "c_mid": Color(0.66, 0.9, 1.0), "c_dark": Color(0.3, 0.62, 0.95)}
		"rock":
			m.shader = SHADERS.facet
			p = {"c_light": Color(0.78, 0.69, 0.56), "c_mid": Color(0.55, 0.47, 0.37), "c_dark": Color(0.32, 0.26, 0.21),
					"rim_on": 0.0, "glint": 0.0, "c_ink": Color(0.1, 0.07, 0.05)}
		"magma":
			# (a magma ball, where earth and fire meet in a guard; the owner 2026-10-12: "if earth parries fire then magma ball and
			# if fire catches earth then magma ball": the cel liquid's body as molten rock: a dark crust in its shade, the lit
			# side orange, a yellow-hot rim, bright cracks crawling over it (the flow's crests), a hard glint; slow to swell)
			m.shader = SHADERS.water
			p = {"c_shade": Color(0.32, 0.05, 0.02, 1.0), "c_body": Color(1.0, 0.36, 0.05, 1.0), "c_rim": Color(1.0, 0.78, 0.25, 1.0),
					"c_foam": Color(1.0, 0.92, 0.55, 1.0), "c_ink": Color(0.12, 0.02, 0.0), "ink": 0.5, "flow": Vector2(0.0, -0.22),
					"nscale": Vector2(2.6, 1.8), "foam": 0.74, "rim": 0.6, "wobble": 0.012}
		"mud":
			# (mud, where earth and water meet in a guard; the owner 2026-10-12: "a mud spear or blast that slows", "it needs to
			# look like mud": the cel liquid as wet mud: dark brown in its shade, a lighter wet rim, pale silty streaks oozing
			# down it (the flow's crests), the hard wet glint, a slow gloopy swell; opaque)
			m.shader = SHADERS.water
			p = {"c_shade": Color(0.17, 0.1, 0.05, 1.0), "c_body": Color(0.34, 0.22, 0.12, 1.0), "c_rim": Color(0.5, 0.36, 0.22, 1.0),
					"c_foam": Color(0.58, 0.45, 0.3, 1.0), "c_ink": Color(0.05, 0.03, 0.02), "ink": 0.45, "flow": Vector2(0.0, -0.35),
					"nscale": Vector2(2.4, 1.6), "foam": 0.8, "rim": 0.58, "wobble": 0.025}
		"mud_strip":
			# (the muddy water round a stone a water Turn swings (the owner, 2026-10-12: "for the water parry channel i also want
			# it to turn muddy"): the stream's strip in mud's colours)
			m.shader = SHADERS.water
			p = {"mode": 1, "flow": Vector2(-1.6, 0.0), "nscale": Vector2(3.0, 1.0), "foam": 0.82, "rim": 0.55,
					"c_shade": Color(0.2, 0.12, 0.06, 0.92), "c_body": Color(0.4, 0.27, 0.15, 0.88), "c_rim": Color(0.56, 0.42, 0.27, 0.92),
					"c_foam": Color(0.66, 0.53, 0.38, 1.0), "c_ink": Color(0.06, 0.03, 0.02)}
		"drop_mud":
			# (a drop of mud: the water drop in mud's browns)
			m.shader = SHADERS.puff
			p = {"mode": 2, "c_a": Color(0.6, 0.46, 0.3), "c_b": Color(0.38, 0.25, 0.14), "c_c": Color(0.2, 0.12, 0.06),
					"c_d": Color(0.82, 0.72, 0.58), "c_ink": Color(0.06, 0.03, 0.02), "wobble": 0.12}
		"bolt":
			m.shader = SHADERS.bolt
		"flash":
			m.shader = SHADERS.sprite
			p = {"mode": 0}
		"orb":
			m.shader = SHADERS.sprite
			p = {"mode": 4}
		"ring":
			m.shader = SHADERS.sprite
			p = {"mode": 1}
		"crown":
			m.shader = SHADERS.sprite
			p = {"mode": 2}
		"swirl":
			m.shader = SHADERS.sprite
			p = {"mode": 3}
		"mark_scorch", "mark_cracks", "mark_frost", "mark_wet":
			m.shader = SHADERS.mark
			p = {"mode": ["mark_scorch", "mark_cracks", "mark_frost", "mark_wet"].find(key)}
		_:
			push_warning("ToonFx: no material %s" % key)
			m.shader = SHADERS.puff
	if m.shader == SHADERS.flame:
		var fl := looks("flame")
		for fk: String in ["soft", "warp", "embers", "deck_fade_m"]:
			if not p.has(fk) and fl.has(fk):
				m.set_shader_parameter(fk, float(fl[fk]))
	var nr := looks("near")
	var rg := looks("range")
	m.set_shader_parameter(&"near_m", float(nr.get("near_m", 2.5)))
	m.set_shader_parameter(&"far_m", float(nr.get("far_m", 4.0)))
	m.set_shader_parameter(&"near_alpha", float(nr.get("near_alpha", 0.25)))
	m.set_shader_parameter(&"range_from_m", float(rg.get("from_m", 14.0)))
	m.set_shader_parameter(&"range_full_m", float(rg.get("full_m", 25.0)))
	m.set_shader_parameter(&"range_max", float(rg.get("max", 2.2)))
	for k in p:
		m.set_shader_parameter(k, p[k])
	if m.shader in [SHADERS.flame, SHADERS.puff, SHADERS.water, SHADERS.wind, SHADERS.sprite, SHADERS.mark, SHADERS.smoke]:
		m.set_shader_parameter(&"noise", noise())
	m.set_shader_parameter(&"ink", 1.0 if s == "ink" else 0.0)
	m.set_shader_parameter(&"fx_gain", gain)
	_mats[key] = m
	return m


## The looks' numbers under `key` (data/bending/fx_looks.json, read once; {} when it has none).
static func looks(key: String) -> Dictionary:
	if _looks.is_empty():
		var f := FileAccess.open(LOOKS_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_looks = d
		if _looks.is_empty():
			_looks = {"_": true}
	var v: Variant = _looks.get(key, {})
	return v if v is Dictionary else {}


## How much of an effect shows `d` m from the camera (the shaders' near_fade: near_alpha at near_m and nearer, whole from
## far_m; drawn as a screen-door, so nothing needs sorting).
static func near_alpha(d: float) -> float:
	var nr := looks("near")
	var n0 := float(nr.get("near_m", 2.5))
	var n1 := float(nr.get("far_m", 4.0))
	return lerpf(float(nr.get("near_alpha", 0.25)), 1.0, clampf((d - n0) / maxf(n1 - n0, 1e-3), 0.0, 1.0))


## A bolt's drawn core scale `d` m from the camera (the shaders' range_scale; its hitbox unchanged).
static func range_scale(d: float) -> float:
	var rg := looks("range")
	var a := float(rg.get("from_m", 14.0))
	var b := float(rg.get("full_m", 25.0))
	return 1.0 + (float(rg.get("max", 2.2)) - 1.0) * clampf((d - a) / maxf(b - a, 1e-3), 0.0, 1.0)


## The material of a bolt's shadow-only core (shared): drawn into the shadows only, never seen.
static func shadow_mat() -> StandardMaterial3D:
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.albedo_color = Color(0.2, 0.2, 0.2)
	return _shadow_mat


## Whether `body` is this machine's own player (the first of the group "player"): his own guard and walls are drawn for his
## eye (thinner, faded by his camera); everyone else's read of them is unchanged.
static func is_own(body: Node) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree() or not body.is_in_group(&"player"):
		return false
	return body.get_tree().get_first_node_in_group(&"player") == body


## Every effect's brightness `g` (the shaders' fx_gain; the shared materials now and those made later).
static func set_gain(g: float) -> void:
	gain = g
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter(&"fx_gain", g)


# ---------------------------------------------------------------- meshes
static func _cached(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


## A 1 m quad standing on its base (local Y 0..1): a flame.
static func quad_base() -> Mesh:
	return _cached("quad_base", func() -> Mesh:
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.center_offset = Vector3(0.0, 0.5, 0.0)
		return q)


## A 1 m quad about its middle: particles, flashes.
static func quad() -> Mesh:
	return _cached("quad", func() -> Mesh:
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		return q)


## A 2 m square lying flat (local XZ, facing +Y): rings, marks.
static func plane() -> Mesh:
	return _cached("plane", func() -> Mesh:
		var q := PlaneMesh.new()
		q.size = Vector2(2.0, 2.0)
		return q)


static func sphere(segs := 18) -> Mesh:
	return _cached("sphere%d" % segs, func() -> Mesh:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = segs
		s.rings = segs / 2
		return s)


## An open band round local Y: radius `r0` at the bottom, `r1` at the top, `h` high (UV.x round, UV.y up).
static func band_mesh(r0: float, r1: float, h: float, segs := 28) -> Mesh:
	return _cached("band_%.2f_%.2f_%.2f_%d" % [r0, r1, h, segs], func() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var u0 := float(i) / segs
			var u1 := float(i + 1) / segs
			var p00 := Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
			var p10 := Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
			var p01 := Vector3(cos(a0) * r1, h, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, h, sin(a1) * r1)
			for v: Array in [[p00, Vector2(u0, 0)], [p01, Vector2(u0, 1)], [p11, Vector2(u1, 1)],
					[p00, Vector2(u0, 0)], [p11, Vector2(u1, 1)], [p10, Vector2(u1, 0)]]:
				st.set_uv(v[1])
				st.set_normal(Vector3((v[0] as Vector3).x, 0.0, (v[0] as Vector3).z).normalized())
				st.add_vertex(v[0])
		return st.commit())


## An open band round local Y like band_mesh, but only `span` rad of it, centred on -Z (forward): a wave's front.
static func band_arc_mesh(r0: float, r1: float, h: float, span: float, segs := 16) -> Mesh:
	return _cached("band_arc_%.2f_%.2f_%.2f_%.2f_%d" % [r0, r1, h, span, segs], func() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in segs:
			var a0 := -PI * 0.5 + span * (float(i) / segs - 0.5)
			var a1 := -PI * 0.5 + span * (float(i + 1) / segs - 0.5)
			var u0 := float(i) / segs
			var u1 := float(i + 1) / segs
			var p00 := Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
			var p10 := Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
			var p01 := Vector3(cos(a0) * r1, h, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, h, sin(a1) * r1)
			for v: Array in [[p00, Vector2(u0, 0)], [p01, Vector2(u0, 1)], [p11, Vector2(u1, 1)],
					[p00, Vector2(u0, 0)], [p11, Vector2(u1, 1)], [p10, Vector2(u1, 0)]]:
				st.set_uv(v[1])
				st.set_normal(Vector3((v[0] as Vector3).x, 0.0, (v[0] as Vector3).z).normalized())
				st.add_vertex(v[0])
		return st.commit())


## A flat crescent in local XZ, bulging toward -Z (forward), `span` rad wide, radius `r`, `w` across at its middle (UV.x
## along the arc, UV.y across).
static func arc_mesh(r: float, w: float, span := 2.2, segs := 20) -> Mesh:
	return _cached("arc_%.2f_%.2f_%.2f" % [r, w, span], func() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ctr := Vector3(0.0, 0.0, r * 0.8)
		var prev_in := Vector3.ZERO
		var prev_out := Vector3.ZERO
		for i in segs + 1:
			var u := float(i) / segs
			var a := -PI * 0.5 + (u - 0.5) * span
			var dir := Vector3(cos(a), 0.0, sin(a))
			var hw := w * 0.5 * sin(u * PI)
			var pin := ctr + dir * (r - hw)
			var pout := ctr + dir * (r + hw)
			if i > 0:
				var pu := float(i - 1) / segs
				for v: Array in [[prev_in, Vector2(pu, 0)], [prev_out, Vector2(pu, 1)], [pout, Vector2(u, 1)],
						[prev_in, Vector2(pu, 0)], [pout, Vector2(u, 1)], [pin, Vector2(u, 0)]]:
					st.set_uv(v[1])
					st.set_normal(Vector3.UP)
					st.add_vertex(v[0])
			prev_in = pin
			prev_out = pout
		return st.commit())


## An ice crystal along -Z: a six-sided bipyramid `len` long, `r` round, its tip forward (its back short), uneven by `seed`.
static func shard_mesh(len: float, r: float, seed := 0, sides := 6) -> Mesh:
	return _cached("shard_%.2f_%.3f_%d_%d" % [len, r, seed, sides], func() -> Mesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 7919 + 13
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tip := Vector3(0.0, 0.0, -len * 0.72)
		var back := Vector3(rng.randf_range(-0.2, 0.2) * r, rng.randf_range(-0.2, 0.2) * r, len * 0.28)
		var ring: Array[Vector3] = []
		for i in sides:
			var a := TAU * i / sides + rng.randf_range(-0.2, 0.2)
			var rr := r * rng.randf_range(0.75, 1.15)
			ring.append(Vector3(cos(a) * rr, sin(a) * rr, rng.randf_range(-0.06, 0.06) * len))
		for i in sides:
			var a := ring[i]
			var b := ring[(i + 1) % sides]
			for v in [tip, b, a, back, a, b]:
				st.add_vertex(v)
		st.generate_normals()
		return st.commit())


## A rough rock chunk about 1 m across (a jittered octahedron, split once): debris.
static func chunk_mesh(seed := 0) -> Mesh:
	return _cached("chunk_%d" % seed, func() -> Mesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 104729 + 7
		var base := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
		var faces := [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 4, 2], [1, 3, 4], [1, 5, 3], [1, 2, 5]]
		var pts: Array[Vector3] = []
		for b: Vector3 in base:
			pts.append(b * rng.randf_range(0.7, 1.1))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f: Array in faces:
			var a: Vector3 = pts[f[0]]
			var b: Vector3 = pts[f[1]]
			var c: Vector3 = pts[f[2]]
			var m := ((a + b + c) / 3.0).normalized() * rng.randf_range(0.75, 1.0)
			for tri in [[a, b, m], [b, c, m], [c, a, m]]:
				for v: Vector3 in tri:
					st.add_vertex(v * 0.5 * Vector3(1.0, 0.75, 1.0))
		st.generate_normals()
		return st.commit())


# ---------------------------------------------------------------- particles
## A colour ramp whose alpha is the shape's fill (1 whole .. 0 gone; ToonFx shaders): [[offset, colour], ...].
static func ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s: Array in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 64
	return t


static func curve(pts: Array, top := 1.0) -> CurveTexture:
	var c := Curve.new()
	c.max_value = top
	for q: Vector2 in pts:
		c.add_point(q)
	var t := CurveTexture.new()
	t.curve = c
	t.width = 64
	return t


## How the pool plays particles of `key`: {mesh, mat, amount (per node), slots (nodes at most), proc (the template the
## pool copies per node; the shot sets its direction, speeds, sizes, gravity)}.
static func recipe(key: String) -> Dictionary:
	mat("flame")                                   # (the style check)
	if _recipes.has(key):
		return _recipes[key]
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	var r := {"mesh": quad(), "mat": null, "amount": 32, "slots": 8, "proc": pm, "life": 0.6}
	var fade := ramp([[0.0, Color(1, 1, 1, 1)], [0.45, Color(1, 1, 1, 0.9)], [1.0, Color(1, 1, 1, 0.0)]])
	match key:
		"puff_fire":
			r.mat = mat("puff_fire")
			pm.color_ramp = ramp([[0.0, Color(1, 1, 1, 1)], [0.3, Color(1, 0.95, 0.9, 0.9)], [1.0, Color(1.0, 0.7, 0.6, 0.0)]])
			pm.scale_curve = curve([Vector2(0, 0.55), Vector2(0.2, 1.0), Vector2(1, 0.7)])
			r.amount = 40
		"puff_steam", "puff_smoke", "puff_dust", "puff_frost", "puff_air", "foam":
			r.mat = mat(key)
			pm.color_ramp = fade
			pm.scale_curve = curve([Vector2(0, 0.5), Vector2(0.25, 1.0), Vector2(1, 1.1)], 1.2)
			r.amount = 32
		"drop", "drop_mud":
			r.mat = mat(key)
			pm.color_ramp = ramp([[0.0, Color(1, 1, 1, 1)], [0.7, Color(1, 1, 1, 0.85)], [1.0, Color(1, 1, 1, 0.0)]])
			r.amount = 48
		"spark_fire", "spark_elec", "spark_line":
			r.mat = mat(key)
			pm.particle_flag_align_y = true
			pm.angle_min = 0.0
			pm.angle_max = 0.0
			pm.color_ramp = ramp([[0.0, Color(1.0, 0.75, 0.2, 1.0)], [0.6, Color(1.0, 0.45, 0.08, 0.8)], [1.0, Color(0.9, 0.2, 0.05, 0.0)]]) \
					if key == "spark_fire" else (ramp([[0.0, Color(0.55, 0.75, 1.0, 1.0)], [1.0, Color(0.4, 0.55, 1.0, 0.0)]])
					if key == "spark_elec" else ramp([[0.0, Color(0.8, 0.92, 1.0, 1.0)], [1.0, Color(0.7, 0.85, 1.0, 0.0)]]))
			r.amount = 48
		"spark_sb":
			# (the sparks round the Spellbreak-shaded bolt, BendLooks.SB_BOLT: a lavender core, the bolt's violet rim)
			r.mat = mat("spark_sb")
			pm.particle_flag_align_y = true
			pm.angle_min = 0.0
			pm.angle_max = 0.0
			pm.color_ramp = ramp([[0.0, Color(0.52, 0.4, 1.0, 1.0)], [1.0, Color(0.42, 0.28, 1.0, 0.0)]])
			r.amount = 48
		"star":
			r.mat = mat("star")
			pm.color_ramp = ramp([[0.0, Color(0.6, 0.85, 1.0, 1.0)], [0.7, Color(0.6, 0.85, 1.0, 0.8)], [1.0, Color(0.6, 0.85, 1.0, 0.0)]])
			r.amount = 24
		"star_sb":
			# (the stars round the Spellbreak-shaded bolt: a lavender core, the bolt's violet rim)
			r.mat = mat("star_sb")
			pm.color_ramp = ramp([[0.0, Color(0.56, 0.44, 1.0, 1.0)], [0.7, Color(0.56, 0.44, 1.0, 0.8)], [1.0, Color(0.46, 0.34, 1.0, 0.0)]])
			r.amount = 24
		"shard":
			r.mesh = shard_mesh(1.0, 0.22, 3, 5)
			r.mat = mat("ice")
			pm.color_ramp = null
			pm.particle_flag_rotate_y = false
			pm.angular_velocity_min = -540.0
			pm.angular_velocity_max = 540.0
			pm.scale_curve = curve([Vector2(0, 1.0), Vector2(0.75, 1.0), Vector2(1, 0.0)])
			r.amount = 32
		"chunk":
			r.mesh = chunk_mesh(1)
			r.mat = mat("rock")
			pm.color_ramp = null
			pm.angular_velocity_min = -360.0
			pm.angular_velocity_max = 360.0
			pm.scale_curve = curve([Vector2(0, 1.0), Vector2(0.8, 1.0), Vector2(1, 0.0)])
			r.amount = 32
		_:
			push_warning("ToonFx: no recipe %s" % key)
			r.mat = mat("puff_dust")
	_recipes[key] = r
	return r


# ---------------------------------------------------------------- lightning
## The forks of a lightning stroke from `a` to `b` into `im` (cleared first): a jagged main stroke, thick, and two to four
## thinner branches off it (some forked again), each a strip for the bolt material (UV2.y: how thick a fork is).
static func lightning_strips(im: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	im.clear_surfaces()
	var m := mat("bolt")
	var main := _jag(a, b, 5, 0.17)
	_strip(im, m, main, 0.13, 1.0, 0.75)
	var len := a.distance_to(b)
	var d := (b - a).normalized()
	for k in 2 + ToonFx.vis_rng.randi() % 3:
		var i := ToonFx.vis_rng.randi_range(2, main.size() - 4)
		var p := main[i]
		var off := Vector3(ToonFx.vis_rng.randf_range(-1.0, 1.0), ToonFx.vis_rng.randf_range(-1.0, 0.2), ToonFx.vis_rng.randf_range(-1.0, 1.0)).normalized()
		var dir := (d + off * 1.1).normalized()
		var br := _jag(p, p + dir * len * ToonFx.vis_rng.randf_range(0.1, 0.28), 3, 0.25)
		_strip(im, m, br, 0.065, 0.45, 0.15)
		if ToonFx.vis_rng.randf() < 0.55 and br.size() > 4:
			var q := br[br.size() / 2]
			var dir2 := (dir + Vector3(ToonFx.vis_rng.randf_range(-1, 1), ToonFx.vis_rng.randf_range(-0.8, 0.2), ToonFx.vis_rng.randf_range(-1, 1)) * 0.9).normalized()
			_strip(im, m, _jag(q, q + dir2 * len * ToonFx.vis_rng.randf_range(0.06, 0.14), 2, 0.3), 0.04, 0.2, 0.1)


## A jagged line from `a` to `b`: its middles pushed aside `levels` times by up to `rough` of each piece's length.
static func _jag(a: Vector3, b: Vector3, levels: int, rough: float) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	var r := rough
	for l in levels:
		var nxt := PackedVector3Array()
		for i in pts.size() - 1:
			var p := pts[i]
			var q := pts[i + 1]
			var seg := q - p
			var sl := seg.length()
			var rnd := Vector3(ToonFx.vis_rng.randf_range(-1, 1), ToonFx.vis_rng.randf_range(-1, 1), ToonFx.vis_rng.randf_range(-1, 1))
			var perp := rnd - seg.normalized() * rnd.dot(seg.normalized()) if sl > 1e-5 else Vector3.ZERO
			nxt.append(p)
			nxt.append((p + q) * 0.5 + perp * sl * r)
		nxt.append(pts[pts.size() - 1])
		pts = nxt
		r *= 0.62
	return pts


static func _strip(im: ImmediateMesh, m: Material, pts: PackedVector3Array, hw: float, thick: float, end_w := 0.3) -> void:
	var n := pts.size()
	if n < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, m)
	for i in n:
		var along := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var u := float(i) / (n - 1)
		var w := hw * lerpf(1.0, end_w, u) * ToonFx.vis_rng.randf_range(0.8, 1.2)
		for a in 2:
			im.surface_set_normal(along.normalized())
			im.surface_set_uv(Vector2(u, float(a)))
			im.surface_set_uv2(Vector2(w, thick))
			im.surface_add_vertex(pts[i])
	im.surface_end()
