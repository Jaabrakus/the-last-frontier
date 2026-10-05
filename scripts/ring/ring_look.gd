class_name RingLook
extends Node
## The Tidebreak ring's light (look task C; the owner judges by eye: "the arena and the special effects ... more polish,
## cel shading"): three moods over the ring's own EnvironmentRig (its DayNight clock, sky, sun and fog), each with clean
## light shapes for cel shading (a single hard key light, short-reach warm lamps, glow only on what burns):
##   "noon"    crisp midday sun high over the deck, cool clear air, sharp short shadows, the water's light dancing on the
##             tank's walls
##   "golden"  late afternoon: a low warm sun over the far stands, long shadows across the water and the deck, warm haze,
##             the braziers already lit
##   "night"   a moonlit sky with its stars, every lantern and brazier lit, the deck pooled in warm light from the
##             scoreboard tower's lamps, soft halos round the flames
## Entry (the integrator wires it after wave 2; tools/ring/look_c_shots.gd shows it):
##   RingLook.apply(level, "golden") -> RingLook     level: a RingLevel (its environment_rig, its ring); call again to
##                                                   change the mood (the same node is reused). It also sets the mood
##                                                   of the ring's RingDressing when there is one.
## What it holds: the clock (stopped at the mood's hour and date, the weather clear) and, every frame after DayNight
## (process_priority), the mood's multipliers on the sun, the exposure and the fog, and its colour grade. Once: glow,
## SSAO, the ambient light. Headless: the clock only (no rendering to change).

const NAME := "RingLook"
## The moods. hour < 0: found from sun_el (the default day's afternoon sun at that height); night: the clock's moon.
const PRESETS := {
	"noon": {
		"fx_gain": 1.0, "hour": 12.25, "clouds": 0.16, "rays": 0.9, "sun_scale": 1.12, "exposure": 0.98, "sky_ambient": 0.42, "ambient": Color(0.0, 0.0, 0.0),
		"fog_density": 0.0007, "fog_tint": Color(0.8, 0.88, 0.98), "fog_mix": 0.3, "sun_scatter": 0.08,
		"saturation": 1.12, "contrast": 1.04,
		"glow_threshold": 1.4, "glow_intensity": 0.35, "glow_bloom": 0.0,
		"ssao_intensity": 1.5, "ssao_radius": 1.1,
	},
	"golden": {
		"fx_gain": 0.92, "sun_el": 13.0, "clouds": 0.08, "rays": 0.6, "sun_scale": 1.35, "exposure": 0.9, "sky_ambient": 0.34, "ambient": Color(0.0, 0.0, 0.0),
		"fog_density": 0.0011, "fog_tint": Color(1.0, 0.66, 0.4), "fog_mix": 0.45, "sun_scatter": 0.18,
		"saturation": 1.22, "contrast": 1.08,
		"glow_threshold": 1.25, "glow_intensity": 0.4, "glow_bloom": 0.0,
		"ssao_intensity": 1.7, "ssao_radius": 1.2,
	},
	"night": {
		"fx_gain": 0.5, "night": true, "clouds": 0.06, "rays": 1.5, "sun_scale": 1.6, "exposure": 0.62, "sky_ambient": 0.3, "ambient": Color(0.05, 0.07, 0.13),
		"fog_density": 0.003, "fog_tint": Color(0.3, 0.36, 0.55), "fog_mix": 0.6, "sun_scatter": 0.1,
		"saturation": 1.1, "contrast": 1.05,
		"glow_threshold": 1.05, "glow_intensity": 0.6, "glow_bloom": 0.02,
		"ssao_intensity": 1.4, "ssao_radius": 1.0,
	},
}

static var _night_cache := Vector2(-1.0, -1.0)       ## (doy, hour)
static var _golden_cache := {}

var preset := "noon"
var cfg: Dictionary = {}
var rig: EnvironmentRig
var level: Node


## Sets `level` (a RingLevel) to the mood `name` ("noon", "golden", "night"); the same RingLook again on later calls.
static func apply(p_level: Node, name := "noon") -> RingLook:
	var look := p_level.get_node_or_null(NAME) as RingLook
	if look == null:
		look = RingLook.new()
		look.name = NAME
		look.process_priority = 100              # after DayNight (and its ForestLight) has set the frame's light
		p_level.add_child(look)
	look.level = p_level
	look.set_preset(name)
	return look


func set_preset(name: String) -> void:
	preset = name if PRESETS.has(name) else "noon"
	cfg = PRESETS[preset]
	rig = level.get(&"environment_rig") as EnvironmentRig if level != null else null
	_clock()
	_once()
	# (the element effects are unshaded: under the night's opened eye they would blow out to white; wave 3's stills)
	ToonFx.set_gain(float(cfg.get("fx_gain", 1.0)))
	var dressing := RingDressing.find_in(level)
	if dressing != null:
		dressing.set_mood(preset)


## The mood's hour and date on the level's clock (stopped), the weather clear.
func _clock() -> void:
	if rig == null or rig.clock_driver == null:
		return
	var clock: WorldClock = rig.clock_driver.clock
	if clock == null:
		return
	clock.running = false
	var doy := WorldClock.DEFAULT_DAY_OF_YEAR
	var hour := float(cfg.get("hour", -1.0))
	if cfg.get("night", false):
		var nd := night_time()
		doy = nd.x
		hour = nd.y
	elif hour < 0.0:
		hour = hour_for_elevation(float(cfg.get("sun_el", 12.0)))
	clock.set_date(doy)
	clock.set_time(hour)
	if rig.clock_driver.has_method(&"force_weather"):
		rig.clock_driver.force_weather("clear")
	rig.clock_driver.force_cover = float(cfg.get("clouds", -1.0))


## The afternoon hour (on the default day) at which the sun stands el_deg high.
static func hour_for_elevation(el_deg: float) -> float:
	if _golden_cache.has(el_deg):
		return _golden_cache[el_deg]
	var c := WorldClock.new()
	c.set_date(WorldClock.DEFAULT_DAY_OF_YEAR)
	var lo := 12.5
	var hi := 20.5
	for i in 40:
		var mid := 0.5 * (lo + hi)
		c.set_time(mid)
		if c.sun_elevation_deg() > el_deg:
			lo = mid
		else:
			hi = mid
	c.free()
	_golden_cache[el_deg] = 0.5 * (lo + hi)
	return _golden_cache[el_deg]


## A late evening near the default day with a bright moon high in the sky and the sun well down (doy, hour).
static func night_time() -> Vector2:
	if _night_cache.x > 0.0:
		return _night_cache
	var c := WorldClock.new()
	var best := -1.0
	var out := Vector2(WorldClock.DEFAULT_DAY_OF_YEAR, 22.5)
	for d in range(-45, 46):
		var doy := WorldClock.DEFAULT_DAY_OF_YEAR + float(d)
		c.set_date(doy)
		for k in 7:
			var h := 21.5 + 0.5 * float(k)
			c.set_time(fposmod(h, 24.0))
			if c.sun_elevation_deg() > -16.0:
				continue
			var md := c.moon_direction()
			var el := rad_to_deg(asin(clampf(md.y, -1.0, 1.0)))
			# bright and high, but not overhead (its light then comes from a side: shapes read), close to the default day
			var score := c.moon_illumination() * smoothstep(15.0, 40.0, el) * (1.0 - smoothstep(65.0, 85.0, el)) \
					- absf(float(d)) * 0.002
			if score > best:
				best = score
				out = Vector2(doy, fposmod(h, 24.0))
	c.free()
	_night_cache = out
	return out


## Glow, SSAO and the ambient light (DayNight leaves these alone after its setup).
func _once() -> void:
	if rig == null:
		return
	var env := rig.get_environment()
	if env == null or DisplayServer.get_name() == "headless":
		return
	env.glow_enabled = true
	env.glow_hdr_threshold = float(cfg.glow_threshold)
	env.glow_intensity = float(cfg.glow_intensity)
	env.glow_bloom = float(cfg.glow_bloom)
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = rig.settings == null or rig.settings.ssao
	env.ssao_intensity = float(cfg.ssao_intensity)
	env.ssao_radius = float(cfg.ssao_radius)
	env.ambient_light_sky_contribution = float(cfg.sky_ambient)
	env.ambient_light_color = cfg.ambient
	env.ambient_light_energy = 1.0
	env.fog_sun_scatter = float(cfg.sun_scatter)
	env.adjustment_contrast = float(cfg.contrast)
	# the sun's shafts (GodRays) softer by day: a clean key light reads better beside cel shading than a glare
	var rays: Variant = rig.get(&"_god_rays")
	if rays != null:
		rays.set(&"strength", float(cfg.get("rays", 1.5)))
	if rig.clock_driver != null:
		rig.clock_driver.env.ambient_light_sky_contribution = float(cfg.sky_ambient)


func _exit_tree() -> void:
	ToonFx.set_gain(1.0)                     # (the open world's effects as they were)


func _process(_dt: float) -> void:
	if rig == null or cfg.is_empty() or DisplayServer.get_name() == "headless":
		return
	var env := rig.get_environment()
	var sun := rig.get_sun()
	if env == null or sun == null:
		return
	sun.light_energy *= float(cfg.sun_scale)
	env.tonemap_exposure *= float(cfg.exposure)
	env.fog_density = float(cfg.fog_density)
	env.fog_light_color = env.fog_light_color.lerp(cfg.fog_tint, float(cfg.fog_mix))
	env.adjustment_saturation = float(cfg.saturation)
