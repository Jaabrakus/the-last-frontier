extends RefCounted
## The sun and moon discs of the dynamic sky (user 2026-09-26: "the sun and moon actually move across the sky ... and
## the moon with its phases"). DayNight calls setup() once and apply() every frame; the drawing is moon_disc() and the
## sun disc in shaders/sky/frontier_sky_dynamic.gdshader. No class_name: DayNight and the tests preload this file.
##
## Positions stay exactly astronomical (WorldClock: the sun, the moon seen from the ground with its parallax and
## refraction). Only the drawn SIZE is artistic: the real discs are ~0.5 deg, about 6 px at the player's 70 deg field
## of view on a 900 px tall window, too small to read a phase or even notice; SUN_DISC_SCALE and MOON_DISC_SCALE
## enlarge them (about 14 and 17 px). The moon's size also follows its distance (perigee / apogee).
##
## The sun: a limb-darkened disc (the limb redder), HDR bright so the glow (bloom) picks it up and nothing else in the
## sky does, with a small glow around it; the atmosphere's own Mie aureole (the sky shader) lies beyond. Disc and glow
## are the colour of the sunlight through the atmosphere (SkyModel.transmittance): white by day, orange then red
## and dim at sunrise and sunset.
##
## The moon: the near side (assets/environment/sky/moon_albedo.png, tools/environment/sky/make_moon_map.py: maria and
## highlands at their real places) turned with the moon's north toward the ecliptic pole, lit by the sun: the lit
## part faces the sun, so the phase and the tilt of the bright limb are what an observer sees (a waxing crescent
## low in the west with its bright limb toward the set sun, and so on). Lommel-Seeliger shading (the regolith: the
## full moon evenly bright to its limb), earthshine on the dark part near new moon, reddened and dimmed near the
## horizon like the sun. It is brighter by day than by night (MOON_DAY / MOON_NIGHT stand in for the eye's
## adaptation, which the exposure only partly follows): a pale disc in the blue by day with the sky's light over it,
## a clear moon with its maria at night. At night a faint halo and its glare hides the stars near it. Clouds pass in
## front of both (the cloud engine's layer is composited over them).
##
## moon_frame() / moon_sample() / moon_lit_stats() mirror moon_disc()'s geometry and shading on the CPU for the tests
## (tests/env/test_sun_moon.gd) and the GPU check of tools/environment/sky/sun_moon_shots.gd. Keep them in step.

const SkyModel := preload("res://scripts/world/env/sky_model.gd")
const MOON_MAP := "res://assets/environment/sky/moon_albedo.png"

const SUN_SIZE_DEG := 0.533          ## the real sun's mean angular diameter
const MOON_RADIUS_KM := 1737.4
## Artistic disc scales (drawn size / real size). Positions are not affected.
const SUN_DISC_SCALE := 2.0
const MOON_DISC_SCALE := 2.5
## Sun disc radiance above the atmosphere (x the transmittance), far above the glow threshold: the disc blooms.
const SUN_DISC := Vector3(60.0, 48.0, 34.0)
## The small glow right around the disc (x the transmittance), fading over SUN_GLOW_WIDTH_DEG beyond its limb.
const SUN_GLOW := Vector3(1.0, 0.8, 0.57)
const SUN_GLOW_WIDTH_DEG := 0.8
## Near the horizon the disc is capped (radiance before the exposure; the largest channel) so the tonemapper does not
## bleach it: the sky around a low sun is itself at the top of the tonemap, and a disc many times brighter would be
## a white spot lost in it. The cap is SUN_LOW_MAX up to 2 deg, rising (log) to the full disc by SUN_LOW_TOP deg, so
## the setting sun shows orange, then red, and dimmer. The key light is not affected.
const SUN_LOW_MAX := 1.8
const SUN_LOW_TOP := 15.0
## The glare's knee (the sky shader's glare_knee) as an exposed value: the sky round the sun rolls off from there
## (AgX shows 0.8 as about 0.9 of white) toward twice it.
const GLARE_KNEE := 0.8
## The moon's colour (a faintly warm grey) and radiance of the full moon's highlands high in the sky, at night and
## by day (sun above 4 deg; blended through twilight).
const MOON_TINT := Vector3(1.0, 0.97, 0.92)
const MOON_NIGHT := 0.2
const MOON_DAY := 0.55
## Earthshine at new moon, as a share of the full moon's radiance (much brighter than the real 1/1000s, so the
## "old moon in the new moon's arms" reads in the dark).
const EARTHSHINE := 0.05
## Halo radiance at the full moon's limb at night (x its colour), and how much its glare hides the stars next to it.
const MOON_HALO := 0.05
const STAR_GLARE := 0.85
const MIE := 4.0


## Loads the moon map into the sky material and sets the fixed uniforms.
static func setup(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	if ResourceLoader.exists(MOON_MAP):
		mat.set_shader_parameter(&"moon_albedo", load(MOON_MAP))
	mat.set_shader_parameter(&"sun_size_deg", SUN_SIZE_DEG * SUN_DISC_SCALE)
	mat.set_shader_parameter(&"sun_glow_width_deg", SUN_GLOW_WIDTH_DEG)
	mat.set_shader_parameter(&"earthshine", EARTHSHINE)


## Uploads the sun and moon for the clock's moment (exposure: the Environment's tonemap exposure, for the glare's
## knee). Returns the values (tests read them back).
static func apply(mat: ShaderMaterial, clock: WorldClock, exposure := 1.7) -> Dictionary:
	var sd := clock.sun_direction()
	var md := clock.moon_direction()
	var sun_el := rad_to_deg(asin(clampf(sd.y, -1.0, 1.0)))
	var moon_el := rad_to_deg(asin(clampf(md.y, -1.0, 1.0)))
	var k := clock.moon_illumination()
	var v := {}
	# the sun: its light through the air (the disc's upper limb shows a little after the centre has set)
	var t_sun := SkyModel.transmittance(maxf(sd.y, 0.0), MIE)
	var disc := SUN_DISC * t_sun
	var cap := SUN_LOW_MAX * pow(SUN_DISC.x / SUN_LOW_MAX, smoothstep(2.0, SUN_LOW_TOP, sun_el))
	var m := maxf(disc.x, maxf(disc.y, disc.z))
	var k_cap := minf(cap / m, 1.0) if m > 0.0 else 1.0
	v.sun_disc_color = disc * k_cap
	v.sun_glow_color = SUN_GLOW * t_sun * sqrt(k_cap)
	v.glare_knee = GLARE_KNEE / maxf(exposure, 0.01)
	# the moon: the same air, relative to the air overhead (so it is neutral high in the sky)
	var t_moon := SkyModel.transmittance(maxf(md.y, 0.0), MIE)
	var t_top := SkyModel.transmittance(1.0, MIE)
	var redden := Vector3(t_moon.x / t_top.x, t_moon.y / t_top.y, t_moon.z / t_top.z)
	var day := smoothstep(-8.0, 4.0, sun_el)
	v.moon_color = MOON_TINT * redden * moon_level(sun_el)
	v.moon_size_deg = 2.0 * rad_to_deg(asin(MOON_RADIUS_KM / clock.moon_distance_km())) * MOON_DISC_SCALE
	var up := smoothstep(-1.0, 3.0, moon_el)
	v.moon_halo = MOON_TINT * redden * (MOON_HALO * MOON_NIGHT * k * (1.0 - day) * up)
	v.moon_glare = STAR_GLARE * k * up
	v.moon_north = moon_north(clock)
	if mat:
		for key: String in v:
			mat.set_shader_parameter(StringName(key), v[key])
	return v


## The full moon's radiance high in the sky for the sun's elevation: MOON_NIGHT once the sun is 8 deg down, MOON_DAY
## from 4 deg up (the eye's adaptation, which the exposure follows only in part).
static func moon_level(sun_el: float) -> float:
	return lerpf(MOON_NIGHT, MOON_DAY, smoothstep(-8.0, 4.0, sun_el))


## World direction of the moon's north pole: toward the ecliptic's north pole (the lunar axis is 1.5 deg from it;
## libration ignored). Through the clock's star-map basis (J2000, precessed to the date).
static func moon_north(clock: WorldClock) -> Vector3:
	var eps := deg_to_rad(23.4393)
	var pole_j2000 := Vector3(0.0, -sin(eps), cos(eps))
	return ((clock.celestial_basis() as Basis).inverse() * pole_j2000).normalized()


## The disc's frame on the sky: [east (the observer's right with the moon's north up: selenographic east, the
## Mare Crisium side), north]. As moon_disc(): ee = cross(moon_dir, nn).
static func moon_frame(moon_dir: Vector3, north: Vector3) -> Array[Vector3]:
	var nn := (north - moon_dir * north.dot(moon_dir)).normalized()
	var ee := moon_dir.cross(nn)
	return [ee, nn]


## moon_disc()'s shading at disc coordinate q (|q| <= 1: x toward ee, y toward nn): the lit weight (Lommel-Seeliger
## with the soft terminator; 0 on the dark side), without albedo and earthshine.
static func moon_sample(q: Vector2, sun_dir: Vector3, moon_dir: Vector3, frame: Array[Vector3]) -> float:
	var z := sqrt(maxf(1.0 - q.length_squared(), 0.0))
	var n := frame[0] * q.x + frame[1] * q.y - moon_dir * z
	var mu0 := n.dot(sun_dir)
	var ls := minf(2.0 * maxf(mu0, 0.0) / (maxf(mu0, 0.0) + maxf(z, 0.05)), 1.3)
	return ls * smoothstep(0.0, 0.05, mu0)


## Lit share of the visible disc and the direction of its bright part on the sky, sampled on a grid of `res` x `res`:
## {"lit": fraction of the disc's area on the lit side, "centroid": Vector2 in the disc frame (the lit part's
## centre), "sun_pa": Vector2 unit direction toward the sun in the same frame}.
static func moon_lit_stats(sun_dir: Vector3, moon_dir: Vector3, north: Vector3, res := 96) -> Dictionary:
	var frame := moon_frame(moon_dir, north)
	var lit := 0.0
	var inside := 0.0
	var cen := Vector2.ZERO
	var wsum := 0.0
	for j in res:
		for i in res:
			var q := Vector2((i + 0.5) / res * 2.0 - 1.0, (j + 0.5) / res * 2.0 - 1.0)
			if q.length_squared() > 1.0:
				continue
			inside += 1.0
			var w := moon_sample(q, sun_dir, moon_dir, frame)
			if w > 0.0:
				lit += 1.0
			cen += q * w
			wsum += w
	var s2 := Vector2(sun_dir.dot(frame[0]), sun_dir.dot(frame[1]))
	return {"lit": lit / maxf(inside, 1.0), "centroid": cen / maxf(wsum, 1e-6),
			"sun_pa": s2.normalized() if s2.length() > 1e-6 else Vector2.ZERO}
