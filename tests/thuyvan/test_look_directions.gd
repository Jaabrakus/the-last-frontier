extends SceneTree
## Thủy Vân's look directions (data/thuyvan_art/look_directions.json, ThuyVanLook). Headless:
##
##   Godot --headless --path . -s tests/thuyvan/test_look_directions.gd
##
##   data       the three directions and the night proposal, each with its painted sky and grade LUT on disk; AgX
##              contrast 1.05-1.15; SDFGI off, SSAO contact only, glow at 0.9; the four karst ranks stepping 15-80 %
##              fog; the day cycle covering 0-24 h in order, morning jade, noon bright, evening dusk
##   apply      a direction onto a bare Environment and sun: the sun's way, colour and energy, ambient, the
##              direction's fog (and height fog), the painted sky shader, AgX and the LUT
##   cycle      at_hour picks and blends the keys (06:30 jade, 13:00 noon, 18:30 dusk, 02:00 night; 09:45 between jade
##              and noon); a blended LUT is a 64-deep Texture3D
##   gated      today's world (no region) and a region without "look" get no ThuyVanLook and keep the frontier rig's
##              environment as it was; a forced look on the rig overrides it
##   shaders    every Thủy Vân shader file loads
## Ends with "LOOK DIRECTIONS TEST PASSED (<n> checks)" or "LOOK DIRECTIONS TEST FAILED (<f> of <n>)".

const Look := preload("res://scripts/thuyvan/look/thuyvan_look.gd")
const Region := preload("res://scripts/world/world_region.gd")

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_data()
	_apply()
	_cycle()
	_gated()
	_shaders()
	if fails.is_empty():
		print("LOOK DIRECTIONS TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("LOOK DIRECTIONS TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		print("  FAIL " + what)
		fails.append(what)


func _data() -> void:
	var d := Look.data()
	_expect(not d.is_empty(), "data: %s parses" % Look.DATA)
	_expect(Look.directions() == ["jade_mist_morning", "bright_saturated_noon", "golden_lantern_dusk"],
			"data: the three directions in order %s" % str(Look.directions()))
	for key: String in Look.directions() + ["night"]:
		var l: Dictionary = d.looks.get(key, {})
		_expect(not l.is_empty(), "data: %s present" % key)
		if l.is_empty():
			continue
		_expect(ResourceLoader.exists(String(l.sky.panorama)), "data: %s sky %s exists" % [key, l.sky.panorama])
		var lut := load(String(l.grade.lut)) as Texture3D
		_expect(lut != null and lut.get_depth() == 64, "data: %s LUT is a 64-deep Texture3D" % key)
		var c := float(l.tonemap.contrast)
		_expect(c >= 1.05 and c <= 1.15, "data: %s AgX contrast %.2f in 1.05-1.15" % [key, c])
		_expect(float(l.sun.energy) > 0.0 and float(l.fog.density) > 0.0 and float(l.fog.height_density) > 0.0,
				"data: %s sun, fog and height fog set" % key)
	var r: Dictionary = d.render
	_expect(r.sdfgi == false and r.ssil == false and r.ssr == false, "data: SDFGI, SSIL and SSR off")
	_expect(is_equal_approx(float(r.ssao.radius), 1.0) and is_equal_approx(float(r.ssao.intensity), 0.6),
			"data: SSAO contact only (radius 1, intensity 0.6)")
	_expect(is_equal_approx(float(r.glow.threshold), 0.9), "data: glow threshold 0.9")
	var fogs: Array = []
	for k: Dictionary in d.karst_ranks:
		fogs.append(float(k.fog))
	_expect(fogs == [0.15, 0.35, 0.6, 0.8], "data: four karst ranks at 15/35/60/80 %% fog %s" % str(fogs))
	var cyc: Array = d.day_cycle
	var ordered := true
	for i in cyc.size() - 1:
		ordered = ordered and float(cyc[i][0]) <= float(cyc[i + 1][0])
	_expect(ordered and float(cyc[0][0]) == 0.0 and float(cyc[cyc.size() - 1][0]) == 24.0,
			"data: the day cycle runs 0-24 h in order")
	# the palette's colours, not retyped: the noon sun is palettes.json's
	var pal: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/thuyvan/plan/look/palettes.json"))
	if pal is Dictionary:
		_expect(String(d.looks.bright_saturated_noon.sun.color) == String(pal.directions.bright_saturated_noon.sun.color),
				"data: the noon sun's colour is the palette's")


func _apply() -> void:
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	var look := Look.resolve("golden_lantern_dusk")
	Look.apply(look, env, sun, true)
	var to_sun := sun.basis.z.normalized()
	var want := Look.sun_vector(285.0, 5.0)
	_expect(to_sun.distance_to(want) < 0.01, "apply: the dusk sun's way %s ~ %s" % [to_sun, want])
	_expect(sun.light_color.is_equal_approx(Color("#ff9a45")), "apply: the dusk sun's colour")
	_expect(env.tonemap_mode == Environment.TONE_MAPPER_AGX and is_equal_approx(env.tonemap_agx_contrast, 1.1),
			"apply: AgX at the dusk contrast")
	_expect(is_equal_approx(env.fog_density, float(Look.data().looks.golden_lantern_dusk.fog.density))
			and env.fog_density > 0.0003 and is_equal_approx(env.fog_height, 170.0)
			and is_equal_approx(env.fog_height_density, 0.01), "apply: the dusk fog and height fog")
	_expect(env.ambient_light_color.is_equal_approx(Color("#6e6a9e")), "apply: the dusk ambient colour")
	_expect(not env.sdfgi_enabled and env.ssao_enabled and env.glow_enabled, "apply: SDFGI off, SSAO and glow on")
	var sm := env.sky.sky_material as ShaderMaterial if env.sky else null
	_expect(sm != null and sm.shader.resource_path == Look.SKY_SHADER, "apply: the sky is tv_sky.gdshader")
	_expect(env.adjustment_enabled and env.adjustment_color_correction is Texture3D, "apply: the grade LUT is set")
	var paper := load("res://assets/thuyvan/village/materials/tvv_paper.tres") as BaseMaterial3D
	_expect(paper and is_equal_approx(paper.emission_energy_multiplier, 3.0), "apply: dusk lights the lantern paper")
	Look.apply(Look.resolve("bright_saturated_noon"), env, sun, true)
	_expect(paper and is_equal_approx(paper.emission_energy_multiplier, 0.0), "apply: noon puts the lanterns out")
	_expect(env.sky.sky_material == sm, "apply: the sky material is reused, not remade")


func _cycle() -> void:
	_expect(Look.at_hour(6.5).keys == ["jade_mist_morning"], "cycle: 06:30 is jade mist (%s)" % str(Look.at_hour(6.5).keys))
	_expect(Look.at_hour(13.0).keys == ["bright_saturated_noon"], "cycle: 13:00 is noon")
	_expect(Look.at_hour(18.5).keys == ["golden_lantern_dusk"], "cycle: 18:30 is dusk")
	_expect(Look.at_hour(2.0).keys == ["night"], "cycle: 02:00 is night")
	var mid := Look.at_hour(9.75)
	_expect(mid.keys == ["jade_mist_morning", "bright_saturated_noon"] and float(mid.weights[1]) > 0.2
			and float(mid.weights[1]) < 0.8, "cycle: 09:45 blends jade into noon %s" % str(mid.weights))
	var e0 := float(Look.resolve("jade_mist_morning").sun_energy)
	var e1 := float(Look.resolve("bright_saturated_noon").sun_energy)
	_expect(float(mid.sun_energy) > minf(e0, e1) and float(mid.sun_energy) < maxf(e0, e1), "cycle: the sun's energy between")
	var lut := Look.lut_for(mid, true)
	_expect(lut is ImageTexture3D and lut.get_depth() == 64, "cycle: a blended LUT is a 64-deep Texture3D")


func _gated() -> void:
	Region.set_region("")
	_expect(Look.region_look() == "", "gated: today's world names no look")
	var rig := EnvironmentRig.new()
	root.add_child(rig)
	rig.build(WorldSettings.preset(WorldSettings.DEFAULT_QUALITY))
	var env := rig.get_environment()
	var before := [env.fog_density, env.background_mode, env.ambient_light_color]
	_expect(Look.attach(rig) == null, "gated: no ThuyVanLook in today's world")
	_expect([env.fog_density, env.background_mode, env.ambient_light_color] == before, "gated: the frontier rig untouched")
	Region.set_region("r1_grey")
	_expect(Look.attach(rig) == null, "gated: none in a region without a look (r1_grey)")
	Region.set_region("")
	var node := Look.attach(rig, "bright_saturated_noon")
	_expect(node != null and node.get_parent() == rig, "gated: a forced look attaches to the rig")
	_expect(is_equal_approx(env.fog_density, 0.00035) and env.tonemap_mode == Environment.TONE_MAPPER_AGX,
			"gated: the forced look overrides the rig's fog and tonemap")
	rig.queue_free()


func _shaders() -> void:
	for s: String in ["tv_terrain", "tv_rock", "tv_rock_far", "tv_river", "tv_card", "tv_sky", "tv_foliage", "tv_cloth"]:
		var sh := load("res://shaders/thuyvan/%s.gdshader" % s) as Shader
		_expect(sh != null and sh.code.length() > 100, "shaders: %s loads" % s)
	var rock := load("res://assets/thuyvan/rock/materials/rock_karst.tres") as ShaderMaterial
	_expect(rock and rock.shader.resource_path == "res://shaders/thuyvan/tv_rock.gdshader",
			"shaders: the rock kit's materials use tv_rock.gdshader")
