extends SceneTree
## The world under the Look setting's Soft (SoftWorld: the character study's light and colours). Headless (the ring builds no
## visuals headless, so the swap itself is seen in the review shots, tools/character/soft_look_shots.gd): what decides it.
##   Godot --headless --path . -s tests/env/test_soft_world.gd
## Ends with "SOFT WORLD TEST OK (<n> checks)" (exit 0) or "SOFT WORLD TEST FAILED (<f> of <n>)" (exit 1).
##   light     each mood's Environment is the study's kind: a plain three-colour sky, one flat ambient colour (no sky light, no
##             reflections), a linear tone curve at exposure 1, no SSAO / SSIL / SDFGI; noon's numbers are the study's own
##   key       the key light stands at the mood's height on the bearing it is given, the study's colour and strength
##   palette   any colour lands within KEEP_L / KEEP_AB of one of the study's colours; each study colour maps to itself
##   deck      every part of the deck (ring.json looks) is told by its tint in its own material, jittered slab to slab too, and
##             never taken for another; a tint of no part is not
##   shader    the stone and planks' soft shader is made (the structure shader still has what STRUCTURE_SWAPS replaces): the
##             texture around its mean, Lambert, the detail a uniform
##   global    the soft characters' share of the ambient is a declared global (project.godot), AMBIENT_SHARE by default
##   headless  sync() never builds a soft world headless, and refresh() is safe with none

var _fails: Array[String] = []
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
		print("  FAIL ", what)


func _initialize() -> void:
	GameSettings.path = "user://soft_world_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
	_run.call_deferred()


func _run() -> void:
	# ---- light
	for mood: String in SoftWorld.MOODS:
		var env := SoftWorld.environment(mood)
		var m: Dictionary = SoftWorld.MOODS[mood]
		_check(env.background_mode == Environment.BG_SKY and env.sky != null and env.sky.sky_material is ProceduralSkyMaterial,
				"%s: a plain procedural sky" % mood)
		var sm := env.sky.sky_material as ProceduralSkyMaterial
		_check(sm.sky_top_color.is_equal_approx(Color(String(m.sky_top))) and sm.sky_horizon_color.is_equal_approx(Color(String(m.sky_horizon))),
				"%s: the sky's colours" % mood)
		_check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and env.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED,
				"%s: a flat ambient colour, no reflections" % mood)
		_check(env.tonemap_mode == Environment.TONE_MAPPER_LINEAR and is_equal_approx(env.tonemap_exposure, 1.0),
				"%s: a linear tone curve at exposure 1" % mood)
		_check(not env.ssao_enabled and not env.ssil_enabled and not env.sdfgi_enabled and not env.adjustment_enabled,
				"%s: no SSAO, SSIL, SDFGI or grade" % mood)
	var noon := SoftWorld.environment("noon")
	var ss := noon.sky.sky_material as ProceduralSkyMaterial
	_check(ss.sky_top_color.is_equal_approx(Color("#87AEC2")) and ss.sky_horizon_color.is_equal_approx(Color("#E7E8D7"))
			and ss.ground_bottom_color.is_equal_approx(Color("#8F9979")), "noon: the study's sky")
	_check(noon.ambient_light_color.is_equal_approx(Color("#CDDCDD")) and is_equal_approx(noon.ambient_light_energy, 0.35),
			"noon: the study's ambient (#CDDCDD at 0.35)")

	# ---- key
	for mood: String in SoftWorld.MOODS:
		var sun := DirectionalLight3D.new()
		var travel := Vector3(0.6, -0.9, -0.3)
		SoftWorld.key_light(sun, mood, travel)
		var fwd := -sun.basis.z
		var el := rad_to_deg(asin(-fwd.y))
		var m: Dictionary = SoftWorld.MOODS[mood]
		_check(absf(el - float(m.sun_el)) < 0.5, "%s: the key light at %.1f degrees (%.1f)" % [mood, float(m.sun_el), el])
		var flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
		_check(flat.dot(Vector3(travel.x, 0.0, travel.z).normalized()) > 0.999, "%s: on the bearing it was given" % mood)
		_check(sun.light_color.is_equal_approx(Color(String(m.sun))) and is_equal_approx(sun.light_energy, float(m.sun_energy)),
				"%s: the key light's colour and strength" % mood)
		sun.free()
	var st := DirectionalLight3D.new()
	SoftWorld.key_light(st, "noon", Vector3(0.0, -1.0, 0.0))
	_check(st.basis.is_finite(), "a sun straight overhead still gets a bearing")
	st.free()

	# ---- palette
	var labs: Array = []
	for k: String in SoftWorld.PALETTE:
		var c := Color(String(SoftWorld.PALETTE[k])).srgb_to_linear()
		labs.append(SoftLook.lin_to_oklab(Vector3(c.r, c.g, c.b)))
		var back := SoftWorld.nearest(Color(c.r / SoftWorld.GAIN, c.g / SoftWorld.GAIN, c.b / SoftWorld.GAIN))
		var bl := SoftLook.lin_to_oklab(Vector3(back.r, back.g, back.b))
		_check(bl.distance_to(labs[-1]) < 0.002, "%s maps to itself (%.4f)" % [k, bl.distance_to(labs[-1])])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var worst := 0.0
	for i in 400:
		var c := Color(rng.randf(), rng.randf(), rng.randf())
		var o := SoftWorld.nearest(c)
		var ol := SoftLook.lin_to_oklab(Vector3(o.r, o.g, o.b))
		var best := INF
		for p: Vector3 in labs:
			var d := maxf(absf(ol.x - p.x) - SoftWorld.KEEP_L, 0.0) + maxf(Vector2(ol.y - p.y, ol.z - p.z).length() - SoftWorld.KEEP_AB * 1.5, 0.0)
			best = minf(best, d)
		worst = maxf(worst, best)
	_check(worst < 0.01, "every colour lands near a study colour (worst %.4f)" % worst)
	_check(SoftWorld.colour(["cream", "ochre", 0.5]).is_equal_approx(Color("#EDE3C6").lerp(Color("#C8A75B"), 0.5)), "a mix of two")
	_check(SoftWorld.colour("teal").is_equal_approx(Color("#4D9BA5")), "a name")

	# ---- deck
	var sw := SoftWorld.new()
	for key: StringName in SoftWorld.LOOK_MATERIALS:
		var parts: Array = SoftWorld.LOOK_MATERIALS[key]
		for p: String in parts:
			var t := SoftWorld._look_tint(p)
			for k in [0.92, 1.0, 1.08]:
				var c := Color(t.r * k, t.g * k * 1.02, t.b * k)
				var got := sw._look_of(c, parts)
				_check(got == p, "%s in %s (x%.2f) is told as itself (%s)" % [p, key, k, got])
	_check(sw._look_of(Color(0.2, 0.6, 0.2), SoftWorld.LOOK_MATERIALS[&"ring_stone"]) == "", "a green is no part of the deck")
	for p: String in SoftWorld.LOOKS:
		_check(SoftWorld.colour(SoftWorld.LOOKS[p]).srgb_to_linear().get_luminance() <= 1.0, "%s's colour is a colour" % p)
	sw.free()

	# ---- shader
	var src := load(SoftWorld.STRUCTURE) as Shader
	var soft := SoftWorld._structure_shader(src)
	_check(soft != null, "the stone and planks' soft shader is made (the structure shader has what it replaces)")
	if soft != null:
		_check(soft.code.contains("uniform float softworld_detail") and soft.code.contains("textureLod(albedo_tex, UV, 12.0)")
				and not soft.code.contains("diffuse_burley"), "its texture around its mean, Lambert, the detail a uniform")
		_check(SoftWorld._structure_shader(src) == soft, "made once")

	# ---- global
	_check(ProjectSettings.has_setting("shader_globals/" + String(SoftLook.AMBIENT_GLOBAL)), "the ambient share is a declared global")
	_check(is_equal_approx(float((ProjectSettings.get_setting("shader_globals/" + String(SoftLook.AMBIENT_GLOBAL)) as Dictionary).value),
			SoftLook.AMBIENT_SHARE), "at AMBIENT_SHARE by default")
	var cloth := load("res://assets/character/shaders/cloth.gdshader") as Shader
	var sc := SoftLook.soft_shader(cloth)
	_check(sc.code.contains("global uniform float %s;" % SoftLook.AMBIENT_GLOBAL) and sc.code.contains("AO *= %s;" % SoftLook.AMBIENT_GLOBAL),
			"a soft character shader reads it")

	# ---- headless
	var host := Node3D.new()
	root.add_child(host)
	SoftLook.override = SoftLook.SOFT
	_check(SoftWorld.sync(host, "noon") == null and host.get_node_or_null(SoftWorld.NAME) == null, "no soft world headless")
	SoftWorld.refresh(self)
	_check(host.is_in_group(SoftWorld.HOSTS), "a host joins the hosts")
	SoftLook.override = ""
	host.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
	if _fails.is_empty():
		print("SOFT WORLD TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("SOFT WORLD TEST FAILED (%d of %d)" % [_fails.size(), _checks])
		quit(1)
