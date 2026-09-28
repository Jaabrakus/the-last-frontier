extends Node
## The light in the forest (2026-09-26, the user: "fix the lighting in the forest"). DayNight creates it and calls
## apply(delta, snap) at the end of every update, after the sun, the sky, the fog and the exposure are set; it adds
## what the forest does to them:
##   - canopy_light (shader global, shaders/common/canopy.gdshaderinc): under a closed canopy the crowns take
##     `sky_taken` of the sky light (the ambient -- SDFGI's on high -- and its reflections) and scatter `scatter` of
##     the key light's ground irradiance down, green-gold; the terrain, the grass, the ferns, the trees and the
##     impostors read it with the crown cover of scripts/world/vegetation/canopy_map.gd. The moon's the same way at
##     night. The crowns pass part of the sky's own light down too (`sky_scatter`, the clear sky's irradiance of
##     SkyModel): at a low sun the sky is most of the light, and the shade under the crowns (where SDFGI's crown
##     blobs also take the ambient) would otherwise go black at dawn and dusk. (The sunflecks themselves come from the dappled crown shadows, shaders/vegetation/canopy_dapple.gdshader.)
##   - leaf_glow: the key light seen through thin outer leaves (forward scatter toward the sun or the moon);
##   - the eye under the trees: the exposure opens as the camera goes under the canopy (the crown cover round the
##     camera, fading out from 7 to 20 m above the ground: `eye_ev` at full cover, `eye_ev_night` at night), slowly (`eye_tau`: an eye adapting to the shade, not
##     a meter pumping; it snaps with DayNight's hour skips and when the camera jumps);
##   - the air under the trees: the fog's light (and its glare round the sun) dims under the canopy (`fog_under`); the
##     rain streaks (WeatherFx reads `rain_light`) dim less (`rain_under`), so a storm still shows in the forest;
##   - night: the night sky's own light (starlight, airglow) as a faint shadowless fill from overhead (NightFill, a
##     DirectionalLight3D: the environment's ambient colour is ignored while SDFGI runs, and the dynamic sky's light at
##     night is far too faint to read by, so a moonless forest was black), and colours fading toward grey as the
##     light goes (`night_saturation`: rod vision), so moonlit leaves no longer glow green.
## The crown blobs stay out of SDFGI while it runs (scripts/world/vegetation/vegetation.gd gi_blobs(): the canopy terms
## take the sky light under the crowns; SDFGI's blobs on top of them left black pockets under the trees).
## The user argument forest_light=0 turns it all off (A/B): every global neutral, the environment as DayNight sets it,
## the crown blobs back in SDFGI (add veg_dapple=0 for the shadow casters from before the forest light too).

const CanopyMap := preload("res://scripts/world/vegetation/canopy_map.gd")
const SkyModel := preload("res://scripts/world/env/sky_model.gd")

## The crown map's cover -> the sky cover seen from under it (shaders/common/canopy.gdshaderinc CANOPY_SKY_VIEW).
const SKY_VIEW := 1.7
## The green-grey the air under the leaves turns (fog_leaf).
const FOG_LEAF := Color(0.8, 1.0, 0.78)

# The look (vars, so tools can tune them live: tools/environment/lighting/forest_light_shots.gd fl.<name>=<value>).
## Share of the sky light a closed canopy takes from what stands under it.
var sky_taken := 0.6
## Share of the key light's ground irradiance a closed canopy scatters down (leaf transmission and reflection after
## the layers of leaves), and its colour (linear: leaves pass green and some red). The sunlight the clouds take off
## the key light still reaches the canopy as diffuse light: `cloud_diffuse` of it counts too.
var scatter := 0.14
var cloud_diffuse := 0.35
## Share of the clear sky's irradiance a closed canopy passes down, diffuse (the leaves transmit and reflect part of
## the sky light they take), in the same tint; an overcast sky gives half of it.
var sky_scatter := 0.1
var scatter_tint := Color(0.78, 1.0, 0.42)
## The key light through a thin leaf (emission per unit albedo per unit key energy) and the phase's sharpness.
var glow := 0.2
var glow_sharpness := 5.0
## Exposure opening (EV) under a closed canopy by day and at night, and its time constant (s).
var eye_ev := 0.8
var eye_ev_night := 1.2
var eye_tau := 2.5
## Radius (m) of the crown cover round the camera the eye and the fog read.
var eye_radius := 12.0
## Share of the fog's light (in-scatter) and sun glare the canopy takes at full cover, and the green-grey the air
## under the leaves turns (the fog colour's share toward FOG_LEAF at full cover).
var fog_under := 0.7
var fog_leaf := 0.3
## Share of the rain streaks' light the canopy takes at full cover (less than the fog's: the eye opens under the trees
## and the drops falling through the gaps and off the leaves stay in view).
var rain_under := 0.4
## The night sky's light (NightFill's energy at full night: starlight and airglow, plus the moonlit sky's share at a
## full moon well up) and its colour, and the colour saturation at full night.
var night_fill := 0.018
var night_fill_moon := 0.006
var night_fill_color := Color(0.62, 0.72, 1.0)
var night_saturation := 0.7

var day_night: Node
var enabled := true
## Crown cover round the camera (0..1 of the sky, smoothed) and the exposure gain it gives (read by tools and tests).
var cover := 0.0
var eye_gain := 1.0
## The light the rain streaks take (WeatherFx): the fog's light before the canopy dimmed it, less `rain_under`.
var rain_light := 1.0
## The canopy_light and leaf_glow globals as last written.
var canopy_light := Vector4.ZERO
var leaf_glow := Vector4.ZERO
var _last_cam := Vector3(INF, INF, INF)
var _fog_scatter_base := 0.15
## DayNight's sky model: its Mie density and the sun's reference transmittance (the sun energy's unit).
var _mie := 4.0
var _t_ref := 1.0
var _fill: DirectionalLight3D


func setup(p_day_night: Node) -> void:
	day_night = p_day_night
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--") == "forest_light=0":
			enabled = false
	var env: Environment = day_night.env
	_fog_scatter_base = env.fog_sun_scatter
	var consts: Dictionary = day_night.get_script().get_script_constant_map() if day_night.get_script() else {}
	_mie = float(consts.get("MIE", 4.0))
	_t_ref = SkyModel.luma(SkyModel.transmittance(sin(deg_to_rad(WorldClock.DEFAULT_SUN_ELEVATION_DEG)), _mie))
	_fill = DirectionalLight3D.new()
	_fill.name = "NightFill"
	_fill.shadow_enabled = false
	_fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_fill.light_specular = 0.0
	_fill.light_indirect_energy = 0.0
	_fill.light_volumetric_fog_energy = 0.0
	_fill.rotation_degrees = Vector3(-75.0, 30.0, 0.0)     # from high overhead: the sky's light
	_fill.visible = false
	add_child(_fill)
	if not enabled:
		_set_global(&"canopy_light", Vector4.ZERO)
		_set_global(&"leaf_glow", Vector4.ZERO)


func apply(delta: float, snap: bool) -> void:
	if not enabled:
		return
	var dn := day_night
	var env: Environment = dn.env
	var sun: DirectionalLight3D = dn.sun
	var clock: WorldClock = dn.clock
	var sun_el := clock.sun_elevation_deg()
	# the key light (the sun, or the moon at night) as DayNight set it this frame; its +Z points toward the light
	var key_dir := sun.global_transform.basis.z
	var key := Vector3(sun.light_color.r, sun.light_color.g, sun.light_color.b) * sun.light_energy
	# the key light before the clouds' shade (DayNight: energy x (1 - shade)): the shaded part arrives diffuse
	var shade: float = clampf(float(dn.get("_shade")), 0.0, 0.995)
	var through := 1.0 + cloud_diffuse * shade / (1.0 - shade)
	var ground := key * through * maxf(key_dir.y, 0.15) / PI
	# the clear sky's irradiance in the sun's energy units (DayNight: energy = base x luma(t_sun) / luma(t_ref))
	var base_e: Variant = dn.get("base_sun_energy")
	var sky_e := SkyModel.luma(SkyModel.sky_lut("irradiance", sun_el, _mie)) / maxf(_t_ref, 1e-4) * (float(base_e) if base_e != null else 2.93)
	var wx: Variant = dn.get("weather")
	if wx != null:
		sky_e *= 1.0 - 0.5 * float(wx.get("overcast"))
	var sc := Vector3(scatter_tint.r, scatter_tint.g, scatter_tint.b) * (ground * scatter + Vector3.ONE * sky_e * sky_scatter / PI)
	canopy_light = Vector4(sc.x, sc.y, sc.z, sky_taken)
	_set_global(&"canopy_light", canopy_light)
	var gl := key * glow
	leaf_glow = Vector4(gl.x, gl.y, gl.z, glow_sharpness)
	_set_global(&"leaf_glow", leaf_glow)
	# the camera under the canopy
	var cam := _camera_position()
	var jump := cam.distance_to(_last_cam) > 20.0
	_last_cam = cam
	var want := minf(CanopyMap.cover_around(cam.x, cam.z, eye_radius) * SKY_VIEW, 1.0)
	# only under the crowns: a camera up a hill's trees, on a tower or in the air sees the open sky
	want *= 1.0 - smoothstep(7.0, 20.0, cam.y - FrontierTerrain.height_at(cam.x, cam.z))
	cover = want if (snap or jump or delta <= 0.0) else lerpf(cover, want, 1.0 - exp(-delta / eye_tau))
	var night := 1.0 - smoothstep(-10.0, -1.0, sun_el)
	eye_gain = pow(2.0, lerpf(eye_ev, eye_ev_night, night) * cover)
	env.tonemap_exposure *= eye_gain
	rain_light = env.fog_light_energy * (1.0 - rain_under * cover)
	env.fog_light_energy *= 1.0 - fog_under * cover
	var fc := env.fog_light_color
	var fl := (fc.r + fc.g + fc.b) / 3.0
	env.fog_light_color = fc.lerp(Color(FOG_LEAF.r * fl, FOG_LEAF.g * fl, FOG_LEAF.b * fl), fog_leaf * cover)
	env.fog_sun_scatter = _fog_scatter_base * (1.0 - fog_under * cover)
	# night: the night sky's light (from mid twilight on) and rod vision
	var dark := 1.0 - smoothstep(-9.0, 0.0, sun_el)
	_fill.visible = dark > 0.001
	var moon_alt := rad_to_deg(asin(clampf(clock.moon_direction().y, -1.0, 1.0)))
	var moon_sky := clock.moon_illumination() * smoothstep(-2.0, 6.0, moon_alt)
	_fill.light_energy = (night_fill + night_fill_moon * moon_sky) * dark
	_fill.light_color = night_fill_color
	env.adjustment_saturation = lerpf(1.0, night_saturation, night)


## The camera the player sees through (the rig's follow_camera when a tool renders through another viewport).
func _camera_position() -> Vector3:
	var rig: Node = day_night.rig
	if rig and "follow_camera" in rig and is_instance_valid(rig.follow_camera):
		return (rig.follow_camera as Camera3D).global_position
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	return cam.global_position if cam else Vector3.ZERO


static func _set_global(uniform: StringName, value: Variant) -> void:
	if ProjectSettings.has_setting("shader_globals/" + String(uniform)):
		RenderingServer.global_shader_parameter_set(uniform, value)
