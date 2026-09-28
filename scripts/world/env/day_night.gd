class_name DayNight
extends Node
## Day and night (user 2026-09-25: "fix the sky and the day and night cycle"; a real sky that keeps the moody
## u10 grade, about 48 real minutes a day). Drives the world from a running WorldClock (the upper Mohawk Valley,
## 1765; 2.4 real minutes per game hour by day, 1.2 at night):
##   - the dynamic sky (shaders/sky/frontier_sky_dynamic.gdshader): sun, moon with its phase (SkyBodies: the
##     discs crossing the sky, drawn larger than life), stars turning with
##     sidereal time (precessed to the game year, WorldClock.celestial_basis), and the cloud engine's clouds
##     (cloud_engine.gdshaderinc) lit by the sun or the moon;
##   - the weather (WeatherSystem: clear / fair cumulus / overcast / storm fronts you see coming): its clouds
##     (CloudField, uploaded every frame), the sun's shade by the clouds in front of it (CloudField's CPU mirror of
##     the march), fog, grey skies, the ground wind (wind_direction / wind_strength globals), and WeatherFx's rain,
##     lightning light and thunder;
##   - the key light: the sun (colour and strength through the atmosphere, SkyModel.transmittance), or the moon
##     at night (its phase), faded through twilight;
##   - fog colour and ambient from the sky's own table (SkyModel.sky_lut), kept low for the u10 deep shadows;
##   - exposure: the u10 exposure at golden hour, opened gently as the light goes (nights dark but readable).
## F6 / F7 (with Shift: the debug overlay's keys are taken) skip time back / forward an hour; Shift+F8 cycles the
## weather (clear -> fair -> overcast -> storm approaching); the HUD's clock reads `clock.time_string()`.

const SkyModel := preload("res://scripts/world/env/sky_model.gd")
const ForestLight := preload("res://scripts/world/env/forest_light.gd")
const SkyBodies := preload("res://scripts/world/env/sky_bodies.gd")   ## the sun and moon discs
const SKY_SHADER := "res://shaders/sky/frontier_sky_dynamic.gdshader"
const SKY_NOISE := "res://assets/environment/sky/sky_noise.png"
const STAR_MAP := "res://assets/environment/sky/stars/star_map.png"   ## tools/environment/sky/bake_star_map.py
const MIE := 4.0
## Sun energy at the default golden-hour sun (EnvironmentRig.SUN_ENERGY), scaled by the atmosphere's
## transmittance against that sun's.
const MOON_ENERGY := 0.09            ## a full moon's key light (artistic: moonlight reads in the u10 grade)
const MOON_COLOR := Color(0.62, 0.72, 1.0)
const AMBIENT_SKY := 0.4            ## share of the sky's light as ambient (u10: deep shadows)
const STAR_MAP_INTENSITY := 2.2   ## the catalogued stars (flux at V = 0)
const STAR_INTENSITY := 0.14        ## many stars (dark 18th-century sky)
const CLOUD_NOISE := "res://assets/environment/sky/cloud_noise_3d.png"   ## tools/environment/sky/make_cloud_noise.py
const CLOUD_SHADE := 0.85           ## how much of the sun a thick cloud takes (the rest: light through its edges)
const STORM_SHADE := 0.995          ## ... under a sky covered by a deck or a storm (no light from around it)
const SHADE_PERIOD := 0.1           ## s between the CPU mirror's marches toward the sun
## Raymarch steps and light-march steps per quality preset (WorldSettings.quality), and whether the step jitter
## changes every frame (a temporal AA / upscaler resolves it; FXAA on low does not).
const CLOUD_QUALITY := {"high": [28, 3, 1.0], "medium": [24, 3, 1.0], "low": [18, 2, 0.0]}
const MILKY_WAY := 0.03
const EXPOSURE_OPEN_MAX := 3.2       ## how far the eye opens at night (x the day exposure)
## Group of the nodes that tell the rain at a point (rain_intensity(pos)); the torch reads it (TorchState.rain_at).
const WEATHER_GROUP := &"weather"

var clock: WorldClock
## The weather (its CloudField holds the sky's cloud uniforms) and its rain, lightning and thunder.
var weather: WeatherSystem
var field: CloudField
var fx: Node
## The light in the forest (ForestLight: the canopy's light, the eye under the trees, night vision), after _apply.
var forest: Node
## >= 0: the cumulus coverage held there (tests); < 0: the weather's.
var force_cover := -1.0
var rig: Node
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var base_exposure := 1.7
var base_sun_energy := 2.93
var sun_color := Color(1.0, 0.909, 0.781)

var _t_ref := Vector3.ONE
var _irr_ref := 1.0
var _exposure_now := 1.0


func setup(p_rig: Node, p_env: Environment, p_sun: DirectionalLight3D, p_sky: ShaderMaterial) -> void:
	rig = p_rig
	env = p_env
	sun = p_sun
	sky_mat = p_sky
	base_exposure = env.tonemap_exposure
	base_sun_energy = sun.light_energy
	sun_color = sun.light_color
	clock = WorldClock.new()
	clock.name = "WorldClock"
	clock.running = true
	add_child(clock)
	clock.changed.connect(func() -> void:
		if absf(clock.hour - _last_hour) > 0.25 and absf(clock.hour - _last_hour) < 23.75:
			_snap = true
		_last_hour = clock.hour)
	var mu_ref := sin(deg_to_rad(WorldClock.DEFAULT_SUN_ELEVATION_DEG))
	_t_ref = SkyModel.transmittance(mu_ref, MIE)
	_irr_ref = SkyModel.luma(SkyModel.sky_lut("irradiance", WorldClock.DEFAULT_SUN_ELEVATION_DEG, MIE)) + maxf(mu_ref, 0.0) * SkyModel.luma(_t_ref)
	if sky_mat:
		sky_mat.shader = load(SKY_SHADER)
		if ResourceLoader.exists(SKY_NOISE):
			sky_mat.set_shader_parameter(&"sky_noise", load(SKY_NOISE))
		if ResourceLoader.exists(STAR_MAP):
			sky_mat.set_shader_parameter(&"star_map", load(STAR_MAP))
		sky_mat.set_shader_parameter(&"mie_density", MIE)
		SkyBodies.setup(sky_mat)
		if ResourceLoader.exists(CLOUD_NOISE):
			sky_mat.set_shader_parameter(&"cloud_noise", load(CLOUD_NOISE))
		var q: Array = CLOUD_QUALITY.get(_quality(), CLOUD_QUALITY.high)
		sky_mat.set_shader_parameter(&"cloud_steps", q[0])
		sky_mat.set_shader_parameter(&"cloud_light_steps", q[1])
		sky_mat.set_shader_parameter(&"cloud_jitter_anim", q[2])
	if env.sky:
		env.sky.process_mode = Sky.PROCESS_MODE_REALTIME
		env.sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.ambient_light_sky_contribution = AMBIENT_SKY
	_exposure_now = base_exposure
	_fog_base = env.fog_density
	field = CloudField.new()
	weather = WeatherSystem.new(field)
	add_to_group(WEATHER_GROUP)
	if sky_mat:
		field.cloud_steps = int((CLOUD_QUALITY.get(_quality(), CLOUD_QUALITY.high) as Array)[0])
	if DisplayServer.get_name() != "headless":
		fx = WeatherFx.new()
		fx.name = "WeatherFx"
		add_child(fx)
		fx.setup(self)
	forest = ForestLight.new()
	forest.name = "ForestLight"
	add_child(forest)
	forest.setup(self)
	_apply(0.0)


func _process(delta: float) -> void:
	if clock:
		_apply(delta)


## _input, not _unhandled_input: the animation debug overlay takes F6-F8 in _unhandled_input (its actions match
## with Shift held too), so the Shift combinations are claimed here first.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.shift_pressed:
		if event.physical_keycode == KEY_F7:
			clock.advance_hours(1.0)
		elif event.physical_keycode == KEY_F6:
			clock.advance_hours(-1.0)
		elif event.physical_keycode == KEY_F8:
			force_weather(weather.next_forced())
			print(weather.describe())
		else:
			return
		get_viewport().set_input_as_handled()


## The rain rate 0..1 at `_pos` (WEATHER_GROUP): the weather's rain at the player (a storm's core is over 0.5).
func rain_intensity(_pos: Vector3) -> float:
	return weather.rain if weather else 0.0


## Sets the weather now (dev key, tools): WeatherSystem.force_state() and the light follows at once.
func force_weather(state: String) -> bool:
	var ok := weather.force_state(state)
	_snap_weather = true
	return ok


var _last_hour := 0.0
var _snap_weather := true
var _shade := 0.0
var _snap := true
var _sky_t := 0.0
var _prev_hour := -1.0
var _shade_in := 0.0
var _key_tr := 1.0
var _key_trs := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])   ## one per CloudField.SHADE_JITTERS
var _jit_i := 0
var _fog_base := 0.0012


func _apply(delta: float) -> void:
	var sd := clock.sun_direction()
	var md := clock.moon_direction()
	var sun_el := clock.sun_elevation_deg()
	# the weather on game hours (a skipped hour moves the fronts on), the clouds' motion on real seconds
	var cam := _camera_position()
	var dh := 0.0
	if _prev_hour >= 0.0:
		dh = fposmod(clock.hour - _prev_hour, 24.0)
		if dh > 12.0:
			dh = 0.0          # a skip back (Shift+F6): the weather does not rewind
	_prev_hour = clock.hour
	weather.update(maxf(delta, 0.0), dh, cam, clock.hour, WorldClock.month_of(clock.day_of_year))
	if force_cover >= 0.0:
		field.cu_cover = force_cover
	_sky_t = fmod(_sky_t + delta, 3600.0)
	field.apply(sky_mat)
	# the key light's shade by the clouds in front of it (the CPU mirror of the sky's march), smoothed as edges pass
	var key_dir := sd if sun_el > -5.5 else md
	_shade_in -= delta
	if _shade_in <= 0.0 or delta <= 0.0 or _snap_weather:
		_shade_in = SHADE_PERIOD
		# one march per tick, its step jitter cycling through SHADE_JITTERS (all of them on a snap): _key_tr is their
		# mean, as the sky's TAA averages its per-frame jitter (a low sun's march is otherwise a coin toss at edges)
		var n := CloudField.SHADE_JITTERS.size()
		for k in (n if (delta <= 0.0 or _snap_weather) else 1):
			_jit_i = (_jit_i + 1) % n
			_key_trs[_jit_i] = field.sun_transmittance(key_dir, cam, CloudField.SHADE_JITTERS[_jit_i]) if key_dir.y > 0.0 else 1.0
		var sum := 0.0
		for v in _key_trs:
			sum += v
		_key_tr = sum / float(n)
	var shade_want := (1.0 - _key_tr) * lerpf(CLOUD_SHADE, STORM_SHADE, weather.overcast)
	_shade = shade_want if (delta <= 0.0 or _snap_weather) else lerpf(_shade, shade_want, 1.0 - exp(-delta / 0.6))
	_snap_weather = false
	RenderingServer.global_shader_parameter_set(&"sky_time", _sky_t)
	RenderingServer.global_shader_parameter_set(&"sun_direction", sd if sd.y > -0.05 else md)
	RenderingServer.global_shader_parameter_set(&"wind_direction", weather.wind_ground_dir)
	RenderingServer.global_shader_parameter_set(&"wind_strength", weather.wind_ground_strength)
	var t_sun := SkyModel.transmittance(maxf(sd.y, 0.0), MIE)
	# the key light: the sun above the horizon, the moon when the sun is well down
	var day_w := smoothstep(-4.0, 2.0, sun_el)
	var moon_up := smoothstep(-2.0, 6.0, rad_to_deg(asin(clampf(md.y, -1.0, 1.0))))
	var moon_w := (1.0 - smoothstep(-8.0, -2.0, sun_el)) * moon_up * clock.moon_illumination()
	if day_w > 0.001:
		var rel := Vector3(t_sun.x / maxf(_t_ref.x, 1e-4), t_sun.y / maxf(_t_ref.y, 1e-4), t_sun.z / maxf(_t_ref.z, 1e-4))
		var lum := SkyModel.luma(rel)
		var col := Color(sun_color.r * rel.x, sun_color.g * rel.y, sun_color.b * rel.z)
		var m := maxf(col.r, maxf(col.g, col.b))
		sun.light_color = Color(col.r / m, col.g / m, col.b / m) if m > 0.0 else sun_color
		sun.light_energy = base_sun_energy * clampf(lum, 0.0, 1.25) * day_w * (1.0 - _shade)
		_aim(sun, sd)
		sun.shadow_enabled = true
	else:
		sun.light_color = MOON_COLOR
		sun.light_energy = MOON_ENERGY * moon_w * (1.0 - _shade)
		_aim(sun, md)
		sun.shadow_enabled = moon_w > 0.05
	# the sky
	if sky_mat:
		sky_mat.set_shader_parameter(&"sun_dir", sd)
		sky_mat.set_shader_parameter(&"moon_dir", md)
		sky_mat.set_shader_parameter(&"celestial", clock.celestial_basis())
		SkyBodies.apply(sky_mat, clock, _exposure_now * (float(forest.eye_gain) if forest else 1.0))   # the eye under the trees too
		sky_mat.set_shader_parameter(&"cloud_light_dir", key_dir)
		# the key light at the low clouds (1.7 km) and at the cirrus / anvils (9 km): after sunset the tops stay lit
		# (reddened) while the bases are already in the Earth's shadow
		var moon_cl := Vector3(0.032, 0.038, 0.058) * moon_w
		var sun_cl := 7.0 if sun_el > -5.5 else 0.0
		sky_mat.set_shader_parameter(&"cloud_light_color", SkyModel.transmittance(sd.y, MIE, 1700.0) * sun_cl + moon_cl)
		sky_mat.set_shader_parameter(&"cloud_light_high", SkyModel.transmittance(sd.y, MIE, 9000.0) * sun_cl + moon_cl)
		var amb := SkyModel.sky_lut("zenith", sun_el, MIE) * 11.4
		# the sky's light on the clouds, part desaturated (the clouds around them and the ground light them too)
		var cloud_amb := amb.lerp(Vector3.ONE * SkyModel.luma(amb), 0.4) * 1.7 * day_w + Vector3(0.0006, 0.0008, 0.0014)
		sky_mat.set_shader_parameter(&"cloud_ambient", cloud_amb)
		# light from the ground on the cloud bases: grass and forest albedo x the ground's irradiance
		var gi := SkyModel.luma(SkyModel.sky_lut("irradiance", sun_el, MIE)) * 11.4 + maxf(sd.y, 0.0) * SkyModel.luma(t_sun) * 7.0
		sky_mat.set_shader_parameter(&"cloud_ground", Vector3(0.16, 0.17, 0.12) * gi * 0.3 * day_w)
		# the ground the sky draws below the horizon (seen past the terrain's edge from high ground): albedo x its
		# irradiance / pi, moonlit at night (the fixed daylight value drew a pale band along the horizon at night; the
		# radiance map keeps it, the lighting is tuned with it)
		sky_mat.set_shader_parameter(&"ground_view_radiance", Vector3(0.16, 0.17, 0.12) * (gi + 0.046 * moon_w) / PI)
		# a sky covered overhead: the air under it greys toward the deck
		sky_mat.set_shader_parameter(&"overcast", weather.overcast * 0.6)
		sky_mat.set_shader_parameter(&"overcast_color", Vector3.ONE * SkyModel.luma(cloud_amb) * 0.55)
		# lightning: the flash inside the cloud, a stroke to the ground, the whole sky lit by a near one
		sky_mat.set_shader_parameter(&"flash", weather.flash)
		sky_mat.set_shader_parameter(&"bolt", weather.bolt)
		sky_mat.set_shader_parameter(&"lightning", weather.sky_flash)
		sky_mat.set_shader_parameter(&"moon_sky_intensity", 0.02 * clock.moon_illumination() * moon_up)
		# 1765, no lamps for a hundred miles: a sky full of stars and the Milky Way once twilight has gone
		var dark := 1.0 - smoothstep(-16.0, -5.0, sun_el)
		sky_mat.set_shader_parameter(&"star_intensity", STAR_INTENSITY * dark * (1.0 - 0.5 * clock.moon_illumination() * moon_up))
		sky_mat.set_shader_parameter(&"star_map_intensity", STAR_MAP_INTENSITY * dark * (1.0 - 0.35 * clock.moon_illumination() * moon_up))
		sky_mat.set_shader_parameter(&"milky_way", MILKY_WAY * dark * (1.0 - 0.7 * clock.moon_illumination() * moon_up))
	# fog from the sky's horizon colour
	var hz := SkyModel.sky_lut("horizon", sun_el, MIE) * 11.4
	var hl := maxf(SkyModel.luma(hz), 1e-5)
	var fog_c := Vector3(hz.x, hz.y, hz.z) / hl
	var grey := weather.overcast
	fog_c = fog_c.lerp(Vector3.ONE * (fog_c.x + fog_c.y + fog_c.z) / 3.0, grey * 0.8)
	env.fog_light_color = Color(clampf(fog_c.x * 0.7, 0.05, 1.0), clampf(fog_c.y * 0.74, 0.05, 1.0), clampf(fog_c.z * 0.78, 0.05, 1.0))
	env.fog_light_energy = clampf(hl * 3.0 * (1.0 - 0.55 * grey), 0.02, 1.0)
	env.fog_density = _fog_base * weather.fog_mult
	# the eye: the golden-hour exposure, opening as the light goes
	var irr := SkyModel.luma(SkyModel.sky_lut("irradiance", sun_el, MIE)) + maxf(sd.y, 0.0) * SkyModel.luma(t_sun)
	irr += 0.004 * moon_w
	irr *= 1.0 - 0.6 * weather.overcast * day_w     # under a storm the eye opens a little (it stays dark)
	var open := clampf(sqrt(_irr_ref / maxf(irr, 1e-5)), 0.55, EXPOSURE_OPEN_MAX)
	if sun_el > 0.0:
		open = minf(open, lerpf(1.25, 1.0, clampf(sun_el / 15.0, 0.0, 1.0)))   # a low sun is still day: no wide eye
	var want := base_exposure * open
	_exposure_now = want if (delta <= 0.0 or _snap) else lerpf(_exposure_now, want, 1.0 - exp(-delta / 1.5))
	env.tonemap_exposure = _exposure_now
	# the forest: the canopy's light, the eye under the trees, night vision (ForestLight)
	if forest:
		forest.apply(delta, _snap)
	_snap = false


## Points a DirectionalLight3D's light along -toward.
static func _aim(l: DirectionalLight3D, toward: Vector3) -> void:
	var d := toward.normalized()
	if absf(d.y) > 0.999:
		d = Vector3(0.001, signf(d.y), 0.0).normalized()
	l.global_transform = Transform3D(Basis.looking_at(-d, Vector3.UP), l.global_position)


## World position the weather is seen from: the current camera (the player's by default).
func _camera_position() -> Vector3:
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam:
		return cam.global_position
	return Vector3.ZERO


func _quality() -> String:
	if rig and "settings" in rig and rig.settings:
		return String(rig.settings.quality)
	return "high"
