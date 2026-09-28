class_name EnvironmentRig
extends Node3D
## Sky, sun, ambient light, fog, post-processing and the viewport's render settings for the
## Frontier level (look-dev spec, sections 3-4). Owner: package A.
##
## Integration API (frozen; see the spec, section 11):
##   var rig := EnvironmentRig.new(); rig.name = "EnvironmentRig"; add_child(rig)
##   rig.build(settings)          -- creates the WorldEnvironment ("WorldEnvironment") and the
##                                   sun ("Sun"), applies settings to the viewport and the
##                                   RenderingServer. Called first, before any other builder.
##   rig.track(player)            -- per frame: updates the global shader uniform
##                                   player_position (grass trampling, near-camera fades).
##   EnvironmentRig.sun_direction()  unit vector TOWARD the sun (world space). Vegetation uses
##                                   it to keep the dummies and the spawn in sunlight.
##   rig.get_sun() / rig.get_environment()
## Extras (package A):
##   rig.get_camera_attributes()  -- the CameraAttributesPractical (auto exposure) on the
##                                   WorldEnvironment, shared by every camera without its own.
##   rig.follow_camera            -- camera the dust motes stay around (default: the viewport's
##                                   current camera). Tools that render through another viewport
##                                   (scenic_shots.gd) point it at their camera.
##   rig.apply_viewport(vp)       -- AA / upscaling / mip bias / anisotropy for another viewport.
##   EnvironmentRig.sky_rotation_degrees()  compass rotation applied to the sky panorama.
##
## Global shader uniforms (declared in project.godot [shader_globals], shared through
## res://shaders/common/wind.gdshaderinc): wind_direction (vec2), wind_strength (float),
## player_position (vec3), sun_direction (vec3). The rig writes player_position every frame
## and sun_direction / wind_* in build().
##
## What it builds (quality presets from WorldSettings, spec 9.2):
##   sky        custom sky shader (shaders/sky/frontier_sky.gdshader) on the Poly Haven HDRI
##              qwantani_late_afternoon_puresky with its sun painted out
##              (assets/environment/sky/, tools/environment/lighting/process_hdri.py), rotated by
##              +6.37 deg so the panorama's sun sits exactly where the DirectionalLight is.
##   sun        DirectionalLight3D "Sun" at azimuth 222.5 / elevation 19.1 deg, the HDRI's sun
##              colour and an energy that matches the sky's own irradiance (sun.json), PSSM
##              shadows and PCSS through light_angular_distance (the real sun's 0.53 deg).
##   ambient    sky light (energy 1 on high with SDFGI, 0.85 medium, 0.8 low), sky reflections.
##   GI         SDFGI (high only; half resolution through the project setting).
##   SSAO       high and medium.  SSIL / SSR off.
##   fog        exponential depth fog with aerial perspective on every preset; on high,
##              volumetric fog (sun shafts) replaces part of it. Dust motes on high/medium.
##   tonemap    AgX, fixed base exposure, and on high/medium a narrow auto exposure
##              (CameraAttributesPractical) calibrated so outdoor views stay at the base.
##   grade      3D LUT (scripts/world/env/grade_lut.gd, baked in assets/environment/lut/).
##   glow       sun / glints / muzzle flashes only (threshold 1.0).
##   viewport   high TAA; medium MetalFX temporal 0.75 (TAA off Apple); low FXAA; MSAA off. The
##              WorldEnvironment's compositor (SkyMotionVectors) gives the TAA the sky's motion vectors.
##              The upscaling graphics setting (scripts/world/settings/: Graphics panel F2,
##              user://settings.cfg, upscale=<mode>[,<level>]) replaces this when on; default off.
## Headless (tests): only a plain Environment and the sun, no textures, no post, no particles.

const GradeLut := preload("res://scripts/world/env/grade_lut.gd")

## Target sun (spec, section 3): the HDRI's own sun elevation (19.1 deg), rotated from its
## native azimuth 216.1 to 222.5 deg (compass: 0 = north = -Z, 90 = east = +X): the widest
## window in which the spawn stays out of the cabin's and the south wall's shadows.
const SUN_AZIMUTH_DEG := 222.5
const SUN_ELEVATION_DEG := 19.1

## Sky panorama and its sun, measured by process_hdri.py (assets/environment/sky/sun.json).
const SKY_PANORAMA := "res://assets/environment/sky/qwantani_late_afternoon_nosun_2k.exr"
const SKY_SHADER := "res://shaders/sky/frontier_sky.gdshader"
## u10 reproduced exactly: in that run the sky shader was swapped for one with no code, which
## draws a flat dark slate sky and gives almost no sky light, so shadows go deep and the sunlit
## areas carry the contrast. The user chose that look; a proper sky with the same mood is a
## follow-up. Set to false for the HDRI golden-hour sky.
const USER_LOOK_EMPTY_SKY := true
const PANORAMA_SUN_AZIMUTH_DEG := 216.129
## sRGB colour of the HDRI's sun (linear 1.0, 0.805, 0.572).
const SUN_COLOR := Color(1.0, 0.909, 0.781)
## E_sun / pi / luma(colour) with E_sun = 7.638 (removed normal irradiance): the energy at
## which the sun and the sky (at energy 1) have the photograph's own ratio.
const SUN_ENERGY := 2.93

## Base exposure (tonemap_exposure) and the auto-exposure calibration (see _camera_attributes).
## The look the user picked on 2026-09-24 (the focused lighting pass's tuning run "u10"):
## exposure 1.7, AgX contrast 1.45, no volumetric fog, fixed exposure, and the sky shader
## replaced by an empty one (see USER_LOOK_EMPTY_SKY). Earlier values: 1.85, 1.0, on, auto.
@export var exposure := 1.7
## The day and night cycle (DayNight: the dynamic sky, sun and moon on the WorldClock). Off: the static u10 look.
@export var day_night := true
var clock_driver: DayNight
@export var sky_energy := 1.0

var settings: WorldSettings
var follow_camera: Camera3D
var _env: Environment
var _sun: DirectionalLight3D
var _attributes: CameraAttributesPractical
var _sky_material: ShaderMaterial
var _motes: GPUParticles3D
var _player: Node3D
var _globals := {}              ## uniform -> declared in project.godot?
var _headless := false


## Unit vector toward the sun.
static func sun_direction() -> Vector3:
	var az := deg_to_rad(SUN_AZIMUTH_DEG)
	var el := deg_to_rad(SUN_ELEVATION_DEG)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


## DirectionalLight3D rotation (degrees) whose -Z axis points away from the sun.
static func sun_rotation_degrees() -> Vector3:
	return Vector3(-SUN_ELEVATION_DEG, 180.0 - SUN_AZIMUTH_DEG, 0.0)


## Compass rotation (deg) that puts the panorama's sun on sun_direction().
static func sky_rotation_degrees() -> float:
	return SUN_AZIMUTH_DEG - PANORAMA_SUN_AZIMUTH_DEG


func build(world_settings: WorldSettings) -> void:
	settings = world_settings if world_settings else WorldSettings.preset(WorldSettings.DEFAULT_QUALITY)
	_headless = DisplayServer.get_name() == "headless"
	_build_sun()
	_build_environment()
	if day_night and not _headless and _sky_material:
		# the dynamic sky and the clock (DayNight; user 2026-09-25: a real sky, the u10 grade kept)
		clock_driver = DayNight.new()
		clock_driver.name = "DayNight"
		add_child(clock_driver)
		clock_driver.setup(self, _env, _sun, _sky_material)
	elif USER_LOOK_EMPTY_SKY and _sky_material:   # no sky material headless
		_sky_material.shader = Shader.new()
	_set_global(&"sun_direction", sun_direction())
	_set_global(&"wind_direction", Vector2(0.866, -0.5))
	_set_global(&"wind_strength", 0.3)
	if not _headless:
		_apply_rendering_server()
		apply_viewport(get_viewport())
		if settings.quality != "low":
			_build_dust_motes()
	print(log_line())


## The startup line that proves which preset is active (spec 9.2), e.g.
## "ENV quality=high aa=taa scale=1.00 sdfgi=true ssao=true volfog=true shadows=4096/4/200m/soft3 ae=true grass=1.00/55m veg=1.00".
func log_line() -> String:
	return "ENV quality=%s aa=%s scale=%.2f sdfgi=%s ssao=%s volfog=%s shadows=%d/%d/%.0fm/soft%d ae=%s grass=%.2f/%.0fm veg=%.2f%s" % [
			settings.quality, _aa_mode_name(), settings.render_scale, settings.sdfgi, settings.ssao,
			settings.volumetric_fog, settings.shadow_atlas_size, settings.shadow_splits,
			settings.shadow_max_distance, settings.soft_shadow_quality, settings.auto_exposure,
			settings.grass_density, settings.grass_distance, settings.vegetation_distance_scale,
			" (headless: no rendering)" if _headless else ""]


func track(player: Node3D) -> void:
	_player = player


func get_sun() -> DirectionalLight3D:
	return _sun


func get_environment() -> Environment:
	return _env


func get_camera_attributes() -> CameraAttributesPractical:
	return _attributes


func _process(_delta: float) -> void:
	if is_instance_valid(_player):
		_set_global(&"player_position", _player.global_position)
	if _motes:
		var cam := follow_camera if is_instance_valid(follow_camera) else get_viewport().get_camera_3d()
		if cam:
			_motes.global_position = cam.global_position


## Sets a global shader uniform if project.godot declares it ([shader_globals]). The
## RenderingServer's own list is editor-only, so the project settings are asked instead.
func _set_global(uniform: StringName, value: Variant) -> void:
	if not _globals.has(uniform):
		_globals[uniform] = ProjectSettings.has_setting("shader_globals/" + String(uniform))
	if _globals[uniform]:
		RenderingServer.global_shader_parameter_set(uniform, value)


# --- Sun ------------------------------------------------------------------------------------

func _build_sun() -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = sun_rotation_degrees()
	_sun.light_color = SUN_COLOR
	_sun.light_energy = SUN_ENERGY
	_sun.light_indirect_energy = 1.0
	_sun.light_specular = 0.8
	_sun.light_volumetric_fog_energy = 1.2
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.1
	_sun.shadow_normal_bias = 2.0
	_sun.shadow_blur = 1.2
	_sun.directional_shadow_max_distance = settings.shadow_max_distance
	_sun.directional_shadow_fade_start = 0.85
	# No pancaking: with the forest's shadow-only crown proxies (cells ~45 m tall, 60-80 m wide)
	# in the near splits, the default 20 m pancake dropped the cabin's and the palisade's shadows
	# on the fort floor (measured on the live level, 2026-09-24).
	_sun.directional_shadow_pancake_size = 0.0
	if settings.shadow_splits >= 4:
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		_sun.directional_shadow_split_1 = 0.06
		_sun.directional_shadow_split_2 = 0.18
		_sun.directional_shadow_split_3 = 0.45
	else:
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_sun.directional_shadow_split_1 = 0.2
	_sun.directional_shadow_blend_splits = settings.quality == "high"
	# PCSS penumbra from the real sun's angular diameter (off on low: plain PCF is cheaper).
	_sun.light_angular_distance = 0.53 if settings.quality != "low" else 0.0
	add_child(_sun)


# --- Environment ----------------------------------------------------------------------------

func _build_environment() -> void:
	_env = Environment.new()
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = _env
	if _headless:
		# Tests: no texture loads, no post. Plain sky-coloured background and flat ambient.
		_env.background_mode = Environment.BG_COLOR
		_env.background_color = Color(0.62, 0.7, 0.78)
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = Color(0.5, 0.55, 0.6)
		add_child(we)
		return
	var q := settings.quality

	# Sky.
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = load(SKY_SHADER)
	_sky_material.set_shader_parameter(&"panorama", load(SKY_PANORAMA))
	_sky_material.set_shader_parameter(&"panorama_energy", sky_energy)
	_sky_material.set_shader_parameter(&"rotation_deg", sky_rotation_degrees())
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky

	# Ambient and reflections.
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# ambient_light_energy does not scale sky ambient (only the flat colour part), so the sky's
	# share is set through sky_contribution with a black flat colour: high 1.0 (SDFGI occludes),
	# medium and low less, standing in for the missing GI occlusion (spec 3.3).
	_env.ambient_light_color = Color.BLACK
	_env.ambient_light_energy = 1.0
	_env.ambient_light_sky_contribution = {"low": 0.95, "medium": 0.85, "high": 1.0}[q]
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Tonemap (AgX) and grade.
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.tonemap_exposure = exposure
	_env.tonemap_agx_contrast = 1.45
	_env.adjustment_enabled = true
	_env.adjustment_color_correction = GradeLut.texture()

	# Depth fog: aerial perspective on every preset. Transmittance at 120 m stays >= 0.85.
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_light_color = Color(0.74, 0.78, 0.8)
	_env.fog_light_energy = 1.0
	_env.fog_density = 0.0012
	_env.fog_aerial_perspective = 0.7
	_env.fog_sun_scatter = 0.15
	_env.fog_sky_affect = 0.25
	_env.fog_height = -5.0
	_env.fog_height_density = 0.015

	# Volumetric fog (high): sun shafts. It adds extinction on top of the depth fog within
	# `length`, so the depth fog is thinned to keep the 120 m dummy's transmittance.
	_env.volumetric_fog_enabled = false
	if settings.volumetric_fog:
		_env.volumetric_fog_density = 0.001
		_env.volumetric_fog_albedo = Color(0.92, 0.88, 0.8)
		_env.volumetric_fog_anisotropy = 0.6
		_env.volumetric_fog_length = 96.0
		_env.volumetric_fog_detail_spread = 2.0
		_env.volumetric_fog_gi_inject = 0.3
		_env.volumetric_fog_ambient_inject = 0.15
		_env.volumetric_fog_sky_affect = 0.0
		_env.volumetric_fog_temporal_reprojection_enabled = true
		_env.volumetric_fog_temporal_reprojection_amount = 0.9

	# SSAO (high, medium). SSIL and SSR stay off (spec 4.2).
	_env.ssao_enabled = settings.ssao
	_env.ssao_radius = 1.2
	_env.ssao_intensity = 1.6
	_env.ssao_power = 1.5
	_env.ssao_detail = 0.5
	_env.ssao_horizon = 0.06
	_env.ssao_sharpness = 0.98
	_env.ssao_light_affect = 0.1
	_env.ssao_ao_channel_affect = 1.0
	_env.ssil_enabled = settings.ssil
	_env.ssr_enabled = false

	# SDFGI (high).
	_env.sdfgi_enabled = settings.sdfgi
	if settings.sdfgi:
		_env.sdfgi_cascades = 4
		_env.sdfgi_min_cell_size = 0.2
		_env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
		_env.sdfgi_use_occlusion = true
		_env.sdfgi_read_sky_light = true
		_env.sdfgi_bounce_feedback = 0.4
		_env.sdfgi_energy = 1.1
		_env.sdfgi_normal_bias = 1.1
		_env.sdfgi_probe_bias = 1.1

	# Glow: only the sun, glints and muzzle flashes (spec 4.8).
	_env.glow_enabled = settings.glow
	for i in 7:
		_env.set_glow_level(i, 0.0)
	_env.set_glow_level(2, 1.0)
	_env.set_glow_level(3, 0.8)
	_env.set_glow_level(4, 0.4)
	_env.glow_normalized = false
	_env.glow_intensity = 0.35
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.02
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.glow_hdr_threshold = 4.0
	_env.glow_hdr_scale = 2.0
	_env.glow_hdr_luminance_cap = 12.0

	_attributes = _camera_attributes()
	we.camera_attributes = _attributes
	# the sky's motion vectors for the TAA: stars sharp while the camera turns (SkyMotionVectors)
	we.compositor = SkyMotionVectors.compositor()
	add_child(we)


## Auto exposure (high, medium): Godot scales the exposure by auto_exposure_scale / L, with L the
## frame's mean HDR luminance clamped to [min, max] sensitivity x 0.00125. The bounds are
## calibrated (tools/environment/lighting/calibrate_exposure.gd) so that outdoor gameplay views
## sit at (or just under) the upper bound -- i.e. at the base exposure -- and only darker views
## (shade, forest interior, facing a wall, interiors) open up, by at most +0.7 EV. The spec's
## -0.5 EV lower bound is not used (AE_CLOSE_EV = 0): brighter views (facing the sun) keep the
## base exposure, so outdoor gameplay views never pump (measured drift 0 EV between spawn_play and
## firing_line). Calibrated per preset on the testbed content (2026-09-24), high: L = 0.30 at the
## spawn, 0.36 on the firing line, 0.45 parade, 0.74 facing the sun; medium: 0.317 at the spawn.
## Re-run the tool (mode=calibrate) after the terrain / vegetation / structure content lands.
const AE_REFERENCE_LUMINANCE := {"high": 0.30, "medium": 0.315}
const AE_OPEN_EV := 0.7
const AE_CLOSE_EV := 0.0

func _camera_attributes() -> CameraAttributesPractical:
	var a := CameraAttributesPractical.new()
	a.exposure_multiplier = 1.0
	a.auto_exposure_enabled = false
	a.auto_exposure_speed = 0.6
	var ref: float = AE_REFERENCE_LUMINANCE.get(settings.quality, AE_REFERENCE_LUMINANCE.high)
	a.auto_exposure_scale = ref
	a.auto_exposure_min_sensitivity = ref * pow(2.0, -AE_OPEN_EV) / 0.00125
	a.auto_exposure_max_sensitivity = ref * pow(2.0, AE_CLOSE_EV) / 0.00125
	return a


# --- Viewport and RenderingServer ------------------------------------------------------------

## The upscaling graphics setting (Off / Auto / MetalFX / FSR 2 / FSR 1) and its in-game panel.
const Upscaling := preload("res://scripts/world/settings/upscaling.gd")
const GraphicsPanel := preload("res://scripts/world/settings/graphics_panel.gd")
## The window viewport's resolved upscaler (Upscaling.resolve(): requested, level, mode, scale,
## note), set by apply_viewport().
var upscaling_state := {}


func _metalfx_available() -> bool:
	return RenderingServer.get_current_rendering_driver_name() == "metal"


func _aa_mode_name() -> String:
	if settings.antialiasing == "metalfx" and not _metalfx_available():
		return "taa(metalfx unavailable)"
	return settings.antialiasing


## Anti-aliasing, upscaling, mip bias and anisotropy of a viewport (the root by default).
func apply_viewport(vp: Viewport) -> void:
	if vp == null:
		return
	# Leaving a temporal upscaler (the upscaling setting, live): drop it first, so the engine never
	# sees it together with the TAA set below (it warns). The mode is set again below.
	if vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 or vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_METALFX_TEMPORAL:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var aa := settings.antialiasing
	if aa == "metalfx" and not _metalfx_available():
		aa = "taa"
	vp.msaa_3d = Viewport.MSAA_2X if aa == "msaa2x" else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = aa == "taa"
	if aa == "metalfx":
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL
		vp.scaling_3d_scale = settings.render_scale
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = settings.render_scale if aa != "taa" or settings.render_scale >= 1.0 else 1.0
	# Sharper textures under TAA (it resolves the extra aliasing); upscalers set their own bias.
	vp.texture_mipmap_bias = -0.3 if aa == "taa" else 0.0
	vp.use_debanding = true
	vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X if settings.quality == "low" else Viewport.ANISOTROPY_8X
	vp.use_occlusion_culling = bool(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", false))
	# The upscaling setting: "off" (the default) keeps everything above as it is (high: native
	# TAA, the user's look); any other mode replaces the preset's anti-aliasing and render scale,
	# falling back when the renderer / GPU lacks it. Re-applied live by the Graphics panel.
	var up := Upscaling.resolve(settings.upscaling, settings.upscaling_quality)
	Upscaling.apply(vp, up, aa)
	if vp == get_viewport():
		upscaling_state = up
		print("GFX ", Upscaling.describe(up, vp, settings.upscaling_source))
		GraphicsPanel.install(self)


func _apply_rendering_server() -> void:
	RenderingServer.directional_shadow_atlas_set_size(settings.shadow_atlas_size, true)
	var soft := clampi(settings.soft_shadow_quality, 0, 5) as RenderingServer.ShadowQuality
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)
	RenderingServer.gi_set_use_half_resolution(true)
	# SDFGI: project defaults for rays (8) and convergence (30 frames); the sun is static, so its
	# light is re-injected over 4 frames.
	RenderingServer.environment_set_sdfgi_frames_to_update_light(RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_4_FRAMES)
	RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)
	RenderingServer.environment_set_volumetric_fog_filter_active(true)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.screen_space_roughness_limiter_set_active(true, 0.25, 0.18)


# --- Dust motes -------------------------------------------------------------------------------

func _build_dust_motes() -> void:
	var process := ShaderMaterial.new()
	process.shader = load("res://shaders/sky/dust_motes_process.gdshader")
	var draw := ShaderMaterial.new()
	draw.shader = load("res://shaders/sky/dust_motes.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = draw
	_motes = GPUParticles3D.new()
	_motes.name = "DustMotes"
	_motes.amount = 250 if settings.quality == "high" else 150
	_motes.lifetime = 600.0
	_motes.explosiveness = 1.0
	_motes.local_coords = false
	_motes.process_material = process
	_motes.draw_pass_1 = quad
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_motes.visibility_aabb = AABB(Vector3(-9, -4, -9), Vector3(18, 8, 18))
	add_child(_motes)
