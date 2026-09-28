extends SceneTree
## Headless tests for the forest light (2026-09-26): the canopy map baked from the vegetation layout (CanopyMap), the
## shader globals it and ForestLight write, ForestLight's response to the camera, the time and the weather (the eye
## under the trees, the fog under them, the night fill and rod vision, the off switch), and the statistics of the
## dappled crowns' sunfleck noise (canopy_dapple.gdshader, mirrored here).
##
##   Godot --headless --path . -s tests/env/test_forest_light.gd [-- --only <name>]
##
## The look itself needs a window: tools/environment/lighting/forest_light_shots.gd. Failures are listed and the exit
## code is 1.

const Layout := preload("res://scripts/world/vegetation/veg_layout.gd")
const CanopyMap := preload("res://scripts/world/vegetation/canopy_map.gd")
const ForestLight := preload("res://scripts/world/env/forest_light.gd")
const Vegetation := preload("res://scripts/world/vegetation/vegetation.gd")

## Deep in the forest (the capture tool's "deep" and "far" views), and in the open (the fort, the range lane).
const DEEP := Vector2(-95.0, -45.0)
const FAR := Vector2(-250.0, 60.0)
const OPEN := [Vector2(0.0, 6.0), Vector2(0.0, -90.0), Vector2(2.0, -150.0)]

var failures := PackedStringArray()
var passes := 0
var current := ""
var layout: RefCounted


## Stands in for DayNight: what ForestLight reads from it.
class DayNightStub extends Node:
	var env := Environment.new()
	var sun: DirectionalLight3D
	var clock := WorldClock.new()
	var rig: Node
	var _shade := 0.0


## Stands in for the EnvironmentRig: the camera ForestLight follows.
class RigStub extends Node:
	var follow_camera: Camera3D


func _initialize() -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and str(args[0]) == "--only":
		only = str(args[1])
	for name in ["test_globals_declared", "test_canopy_map", "test_eye_and_fog", "test_night", "test_clouds_scatter",
			"test_off_switch", "test_dapple_noise", "test_sky_scatter_and_gi", "test_remove_crown"]:
		if only != "" and not name.contains(only):
			continue
		current = name
		var n0 := failures.size()
		call(name)
		print("  %s %s" % ["ok  " if failures.size() == n0 else "FAIL", name])
	print("")
	print("forest light: %d checks passed, %d failed (%d ms)" % [passes, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	print("FOREST LIGHT TEST %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	CanopyMap.image = null
	CanopyMap.texture = null
	CanopyMap._stamps.clear()
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures.append("%s: %s" % [current, what])


func _baked() -> void:
	if layout != null:
		return
	layout = Layout.new(1776, EnvironmentRig.sun_direction())
	layout.build(false)
	var ms := CanopyMap.bake(layout)
	print("    canopy map baked in %.1f ms (%d trees)" % [ms, (layout.tree_pos as PackedVector3Array).size()])
	_check(ms < 400.0, "the bake takes %.0f ms (load-time budget 400 ms)" % ms)


## Every global the forest light writes is declared (a missing one fails to compile every forest shader).
func test_globals_declared() -> void:
	for g: String in ["canopy_map", "canopy_rect", "canopy_light", "leaf_glow", "sun_direction", "player_position",
			"wind_direction", "wind_strength"]:
		_check(ProjectSettings.has_setting("shader_globals/" + g), "shader global %s declared in project.godot" % g)
	var m: Dictionary = ProjectSettings.get_setting("shader_globals/canopy_map", {})
	_check(String(m.get("type", "")) == "sampler2D", "canopy_map is a sampler2D")
	# a scene without the forest light (no ForestLight: canopy_light = 0) is neutral in every term
	var cl: Dictionary = ProjectSettings.get_setting("shader_globals/canopy_light", {})
	_check(cl.get("value") == Vector4.ZERO, "canopy_light defaults to 0 (neutral)")


func test_canopy_map() -> void:
	_baked()
	var img: Image = CanopyMap.image
	_check(img != null and img.get_width() == CanopyMap.MAP_SIZE and img.get_height() == CanopyMap.MAP_SIZE,
			"the map is %d x %d" % [CanopyMap.MAP_SIZE, CanopyMap.MAP_SIZE])
	_check(CanopyMap.texture != null and CanopyMap.texture.get_image().has_mipmaps(), "the texture has mipmaps (the shaders' 8-16 m cover)")
	for p: Vector2 in OPEN:
		_check(CanopyMap.cover_at(p.x, p.y) == 0.0, "no canopy over the clearing at %s (%.2f)" % [p, CanopyMap.cover_at(p.x, p.y)])
	var deep := CanopyMap.cover_around(DEEP.x, DEEP.y, 12.0)
	var far := CanopyMap.cover_around(FAR.x, FAR.y, 12.0)
	print("    cover round the camera: deep %.2f, far %.2f" % [deep, far])
	# (beyond +-220 m the forest is sparser: ~1 tree per 90 m2 against 55)
	_check(deep > 0.45 and far > 0.3, "a closed canopy in the forest (deep %.2f, far %.2f)" % [deep, far])
	# every crown is in the map: at its crown's centre the cover is at least the species' opacity
	var worst := 1.0
	var n := 0
	for i in range(0, (layout.tree_pos as PackedVector3Array).size(), 37):
		var k: int = layout.tree_kind[i]
		if not CanopyMap.CROWN_OPACITY.has(k):
			continue
		var info := preload("res://scripts/world/vegetation/veg_assets.gd").tree(k, layout.tree_variant[i])
		var cc: Array = info.get("crown_center", [0.0, 0.0, 0.0])
		var yaw: float = layout.tree_yaw[i]
		var sc: float = layout.tree_scale[i]
		var off: Vector3 = Vector3(float(cc[0]), 0.0, float(cc[2])).rotated(Vector3.UP, yaw) * sc
		var p: Vector3 = layout.tree_pos[i] + off
		worst = minf(worst, CanopyMap.cover_at(p.x, p.z) / float(CanopyMap.CROWN_OPACITY[k]))
		n += 1
	_check(n > 50 and worst > 0.85, "every crown in the map (%d sampled, worst %.2f of its opacity)" % [n, worst])
	var mx := 0.0
	for y in range(0, CanopyMap.MAP_SIZE, 7):
		for x in range(0, CanopyMap.MAP_SIZE, 7):
			mx = maxf(mx, img.get_pixel(x, y).r)
	_check(mx <= 1.0 and mx > 0.9, "the cover stacks to at most 1 (max %.2f)" % mx)


## A ForestLight on a stubbed DayNight at `hour` on `doy`, the camera at xz; returns [light, stub].
func _rig(hour: float, xz: Vector2, doy := 237.0) -> Array:
	var dn := DayNightStub.new()
	root.add_child(dn)
	dn.sun = DirectionalLight3D.new()
	dn.add_child(dn.sun)
	dn.sun.light_energy = 2.9
	dn.clock.set_date(doy)
	dn.clock.set_time(hour)
	var sd := dn.clock.sun_direction()
	var key := sd if sd.y > -0.05 else dn.clock.moon_direction()
	dn.sun.global_transform = Transform3D(Basis.looking_at(-key, Vector3.UP if absf(key.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	if sd.y <= -0.05:
		dn.sun.light_energy = 0.09 * dn.clock.moon_illumination()
	dn.env.tonemap_exposure = 1.7
	dn.env.fog_light_energy = 0.8
	dn.env.fog_sun_scatter = 0.15
	var rig := RigStub.new()
	dn.add_child(rig)
	rig.follow_camera = Camera3D.new()
	rig.add_child(rig.follow_camera)
	rig.follow_camera.global_position = Vector3(xz.x, FrontierTerrain.height_at(xz.x, xz.y) + 1.7, xz.y)
	dn.rig = rig
	var fl := ForestLight.new()
	dn.add_child(fl)
	fl.setup(dn)
	fl.apply(0.0, true)
	return [fl, dn]


func _free(pair: Array) -> void:
	var dn: DayNightStub = pair[1]
	dn.clock.free()
	dn.free()


func test_eye_and_fog() -> void:
	_baked()
	var inside := _rig(12.0, DEEP)
	var outside := _rig(12.0, OPEN[1])
	var fi: Node = inside[0]
	var fo: Node = outside[0]
	var ei: Environment = (inside[1] as DayNightStub).env
	var eo: Environment = (outside[1] as DayNightStub).env
	print("    noon: eye %.2f under the trees (cover %.2f), %.2f in the open" % [fi.eye_gain, fi.cover, fo.eye_gain])
	_check(fo.eye_gain == 1.0 and is_equal_approx(eo.tonemap_exposure, 1.7), "the open keeps the exposure (u10)")
	_check(fi.eye_gain > 1.4 and fi.eye_gain <= pow(2.0, fi.eye_ev) + 1e-4, "the eye opens under the canopy, at most eye_ev (%.2f)" % fi.eye_gain)
	_check(is_equal_approx(ei.tonemap_exposure, 1.7 * fi.eye_gain), "the gain multiplies DayNight's exposure")
	_check(ei.fog_light_energy < 0.8 * 0.5 and is_equal_approx(eo.fog_light_energy, 0.8), "the fog's light dims under the canopy only")
	_check(ei.fog_sun_scatter < 0.15 and is_equal_approx(eo.fog_sun_scatter, 0.15), "the sun's glare in the fog dims under the canopy only")
	# the rain streaks keep more of their light than the fog (a storm still shows under the trees), none taken outside
	_check(fi.rain_light > ei.fog_light_energy and fi.rain_light * fi.eye_gain > 0.8 * 0.9 and is_equal_approx(fo.rain_light, 0.8),
			"the rain streaks under the canopy lit %.2f x eye %.2f (fog %.2f)" % [fi.rain_light, fi.eye_gain, ei.fog_light_energy])
	# walking in: the eye adapts over eye_tau, not at once; a jump (a cut) snaps it
	var cam: Camera3D = (outside[1] as DayNightStub).rig.follow_camera
	cam.global_position = Vector3(DEEP.x + 60.0, FrontierTerrain.height_at(DEEP.x + 60.0, DEEP.y) + 1.7, DEEP.y)   # the forest's edge
	fo.apply(0.0, true)
	var c0: float = fo.cover
	cam.global_position = Vector3(DEEP.x + 45.0, FrontierTerrain.height_at(DEEP.x + 45.0, DEEP.y) + 1.7, DEEP.y)
	fo.apply(0.1, false)
	var want := minf(CanopyMap.cover_around(DEEP.x + 45.0, DEEP.y, fo.eye_radius) * ForestLight.SKY_VIEW, 1.0)
	_check(absf(fo.cover - want) > 0.5 * absf(want - c0) or absf(want - c0) < 0.02, "the eye adapts over time (%.2f -> %.2f, target %.2f)" % [c0, fo.cover, want])
	# above the crowns (a tower, a hilltop view, the air) the eye sees the open sky
	var cam_in: Camera3D = (inside[1] as DayNightStub).rig.follow_camera
	cam_in.global_position = Vector3(DEEP.x, FrontierTerrain.height_at(DEEP.x, DEEP.y) + 30.0, DEEP.y)
	fi.apply(0.0, true)
	_check(fi.eye_gain == 1.0, "no forest eye 30 m up (%.2f)" % fi.eye_gain)
	_free(inside)
	_free(outside)


func test_night() -> void:
	_baked()
	var noon := _rig(12.0, DEEP)
	var full := _rig(0.5, DEEP, 243.0)     # 31 August 1765: full moon
	var new := _rig(0.0, DEEP, 229.0)      # 17 August 1765: new moon
	var fill_noon: DirectionalLight3D = (noon[0] as Node).get_node("NightFill")
	var fill_full: DirectionalLight3D = (full[0] as Node).get_node("NightFill")
	var fill_new: DirectionalLight3D = (new[0] as Node).get_node("NightFill")
	print("    night fill: noon %s %.3f, full moon %.3f, new moon %.3f; saturation %.2f / %.2f" % [fill_noon.visible,
			fill_noon.light_energy, fill_full.light_energy, fill_new.light_energy,
			(noon[1] as DayNightStub).env.adjustment_saturation, (new[1] as DayNightStub).env.adjustment_saturation])
	_check(not fill_noon.visible, "no night fill by day")
	_check(fill_new.visible and fill_new.light_energy > 0.01, "a moonless night has the sky's light")
	_check(fill_full.light_energy > fill_new.light_energy, "a full moon's sky is brighter than a moonless one")
	_check(not fill_full.shadow_enabled and fill_full.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY,
			"the fill casts no shadow and does not light the sky")
	_check((noon[1] as DayNightStub).env.adjustment_saturation == 1.0, "full colour by day (u10)")
	_check((new[1] as DayNightStub).env.adjustment_saturation < 0.7, "colours fade at night (rod vision)")
	_check((new[0] as Node).eye_gain > (noon[0] as Node).eye_gain, "the eye opens more under the trees at night")
	_free(noon)
	_free(full)
	_free(new)


## Under clouds the key light's lost part still reaches the canopy as diffuse light (cloud_diffuse).
func test_clouds_scatter() -> void:
	_baked()
	var clear := _rig(12.0, DEEP)
	var cloudy := _rig(12.0, DEEP)
	var dn: DayNightStub = cloudy[1]
	dn._shade = 0.9
	dn.sun.light_energy = 2.9 * 0.1       # DayNight: energy x (1 - shade)
	(cloudy[0] as Node).apply(0.0, true)
	var lc: Vector4 = (clear[0] as Node).canopy_light
	var lo: Vector4 = (cloudy[0] as Node).canopy_light
	var ratio := lo.y / maxf(lc.y, 1e-6)
	print("    canopy light: clear %.4f, 90 %% cloud shade %.4f (x%.2f); sky taken %.2f" % [lc.y, lo.y, ratio, lc.w])
	_check(lc.y > 0.0 and lc.y > lc.z, "a sunlit canopy scatters green-gold light down")
	_check(ratio > 0.3 and ratio < 0.6, "a covered sun still lights the canopy diffusely (x%.2f of clear)" % ratio)
	_check(lc.w > 0.3 and lc.w < 1.0, "the canopy takes part of the sky light")
	var glow: Vector4 = (clear[0] as Node).leaf_glow
	_check(glow.x > 0.0 and glow.w >= 1.0, "leaves glow against the sun")
	_free(clear)
	_free(cloudy)


func test_off_switch() -> void:
	_baked()
	var pair := _rig(12.0, DEEP)
	var fl: Node = pair[0]
	var env: Environment = (pair[1] as DayNightStub).env
	fl.enabled = false
	env.tonemap_exposure = 1.7
	env.fog_light_energy = 0.8
	fl.apply(0.1, false)
	_check(is_equal_approx(env.tonemap_exposure, 1.7) and is_equal_approx(env.fog_light_energy, 0.8),
			"forest_light=0 leaves the environment as DayNight set it")
	_free(pair)


## The sunfleck cut of canopy_dapple.gdshader (its threshold fit on the noise texture's G channel): the open share of a
## crown is `gap` within 0.03, and the material has its noise.
func test_dapple_noise() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(CanopyMap.DAPPLE_NOISE))
	_check(img != null and img.get_width() == 512, "the sky's noise texture is there")
	if img == null:
		return
	var mat := CanopyMap.dapple_material()
	_check(mat.get_shader_parameter(&"dapple_noise") != null, "the dappled crowns' material has the noise")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for g: float in [0.1, 0.2, 0.3]:
		var t := (0.6397 * g - 0.9245) * g + 0.9404
		var open := 0
		var n := 6000
		for i in n:
			if img.get_pixel(rng.randi_range(0, 511), rng.randi_range(0, 511)).g > t:
				open += 1
		var share := float(open) / n
		_check(absf(share - g) < 0.03, "gap %.2f opens %.3f of the crown" % [g, share])


## The crowns pass part of the sky's light down (sky_scatter): at dawn it is most of the canopy's light; the crown
## blobs stay out of SDFGI while the forest light runs (vegetation.gd gi_blobs(); no user args here).
func test_sky_scatter_and_gi() -> void:
	_baked()
	var dawn := _rig(5.4, DEEP)
	var fl: Node = dawn[0]
	var dn: DayNightStub = dawn[1]
	dn.sun.light_energy = 0.4        # DayNight's sun energy 1 deg up (base 2.93 x the transmittance's share)
	fl.apply(0.0, true)
	var with_sky: Vector4 = fl.canopy_light
	fl.sky_scatter = 0.0
	fl.apply(0.0, true)
	var without: Vector4 = fl.canopy_light
	print("    dawn (sun %.1f deg): canopy light %.4f, %.4f of it from the sky" % [dn.clock.sun_elevation_deg(), with_sky.y, with_sky.y - without.y])
	_check(dn.clock.sun_elevation_deg() > 0.0 and dn.clock.sun_elevation_deg() < 8.0, "5:24 is just after sunrise")
	_check(with_sky.y > 1.5 * without.y, "at a low sun the sky gives the canopy most of its light (%.4f vs %.4f)" % [with_sky.y, without.y])
	_check(not Vegetation.gi_blobs(), "the crown blobs stay out of SDFGI while the forest light runs")
	_free(dawn)


## A felled tree's crown comes off the map (CanopyMap.remove_crown, VegHarvest.remove_tree): the cover over its trunk
## drops to what the other crowns leave (the bake stacks them as 1 - prod(1 - a)), and the texture follows. The map is
## baked again afterwards.
func test_remove_crown() -> void:
	_baked()
	var best := -1
	var best_c := 0.0
	for i in range(0, (layout.tree_pos as PackedVector3Array).size(), 11):
		var k: int = layout.tree_kind[i]
		if not CanopyMap.CROWN_OPACITY.has(k):
			continue
		var c := CanopyMap.cover_at(layout.tree_pos[i].x, layout.tree_pos[i].z)
		# a tree standing alone: the cover over its trunk is its own crown's
		if c > float(CanopyMap.CROWN_OPACITY[k]) - 0.03 and c < float(CanopyMap.CROWN_OPACITY[k]) + 0.01 and c > best_c:
			best = i
			best_c = c
	_check(best >= 0, "a lone tree to fell")
	if best < 0:
		return
	var p: Vector3 = layout.tree_pos[best]
	var ms := CanopyMap.remove_crown(layout, best)
	var after := CanopyMap.cover_at(p.x, p.z)
	var a := float(CanopyMap.CROWN_OPACITY[layout.tree_kind[best]])
	var others := clampf(1.0 - (1.0 - best_c) / (1.0 - a), 0.0, 1.0)
	print("    felled tree %d: cover %.2f -> %.2f, the other crowns' %.2f (%.1f ms)" % [best, best_c, after, others, ms])
	_check(after < best_c - 0.5 * a and absf(after - others) < 0.04, "its crown is off the map (%.2f -> %.2f)" % [best_c, after])
	if DisplayServer.get_name() != "headless":      # the dummy renderer keeps no texture data
		var tx := Vector2i(int(p.x - CanopyMap.ORIGIN.x), int(p.z - CanopyMap.ORIGIN.y))
		var tc := CanopyMap.texture.get_image().get_pixel(tx.x, tx.y).r
		var ic := CanopyMap.image.get_pixel(tx.x, tx.y).r
		_check(absf(tc - ic) < 0.01, "and off the texture (%.2f, map %.2f)" % [tc, ic])
	_check(ms < 20.0, "the update takes %.1f ms" % ms)
	CanopyMap.bake(layout)
