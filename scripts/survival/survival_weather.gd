class_name SurvivalWeather
extends RefCounted
## Gameplay weather (seasons.json weather): a Markov chain per season, ticked every tick_game_h (6) game hours.
##
## The chains give the kind of weather; the month's snow fraction and the air temperature decide whether precipitation
## falls as rain or snow, so March and November get their mixed weather even though they sit in the spring and
## autumn chains. Weather computes gameplay wind (scent, smoke, arrow drift) and never writes the wind_direction or
## wind_strength shader globals, which the environment rig owns (seasons.json weather.wind).

## Snow on the ground: accumulation and melt rates in cm per game hour [D].
const SNOW_CM_PER_H := {"snow": 1.0, "blizzard": 2.0}
const MELT_CM_PER_H := 1.5
const DRIFT_TO_NORMAL_PER_H := 0.02
## Precipitation phase: always snow below this air temperature, always rain above the other [D].
const ALL_SNOW_BELOW_C := -3.0
const ALL_RAIN_ABOVE_C := 5.0
const RAIN_TO_SNOW := {"rain": "snow", "storm": "blizzard"}
const SNOW_TO_RAIN := {"snow": "rain", "blizzard": "storm"}


static func init(core: SurvivalCore) -> void:
	var w := core.state.weather
	var season := SurvivalClock.season(core)
	w["state"] = "overcast" if season == "winter" else "clear"
	w["hours_to_tick"] = tick_hours(core)
	w["noise_c"] = 0.0
	w["wind_dir_deg"] = core.rng.randf_range(0.0, 360.0)
	w["wind_ms"] = 2.0
	w["snow_depth_cm"] = normal_snow_depth(core)
	w["snowed_tonight"] = false
	w["hours_in_state"] = 0.0
	_roll_wind(core)


static func tick_hours(core: SurvivalCore) -> float:
	return SurvivalUtil.num(core.data.section("seasons", "weather").get("tick_game_h"), 6.0)


static func state_id(core: SurvivalCore) -> String:
	return str(core.state.weather.get("state", "clear"))


static func row(core: SurvivalCore) -> Dictionary:
	return core.data.weather_states.get(state_id(core), {})


## "rain", "snow" or "" (seasons.json weather states: precip).
static func precip(core: SurvivalCore) -> String:
	var p = row(core).get("precip")
	return "" if p == null else str(p)


static func is_storm(core: SurvivalCore) -> bool:
	var s := state_id(core)
	return s == "storm" or s == "blizzard"


static func wind_ms(core: SurvivalCore) -> float:
	return SurvivalUtil.num(core.state.weather.get("wind_ms"), 0.0)


static func snow_depth_cm(core: SurvivalCore) -> float:
	return SurvivalUtil.num(core.state.weather.get("snow_depth_cm"), 0.0)


static func normal_snow_depth(core: SurvivalCore) -> float:
	var mult := SurvivalUtil.num(SurvivalClock.region_climate(core).get("snow_depth_mult"), 1.0)
	return SurvivalClock.month_value(core, "snow_depth_cm") * mult


## Wet weather for actions' difficulty_by "weather.wet": falling rain or a thaw.
static func is_wet(core: SurvivalCore) -> bool:
	return precip(core) == "rain" or state_id(core) == "thaw"


## The weather the player sees, from the game's sky (SurvivalBridge, 2026-09-27: one weather). `sid` is a state id
## (clear, overcast, fog, rain, storm); rain turns to snow and a storm to a blizzard below freezing. While it is set
## (weather.external) the chains no longer roll the state; snow on the ground, wind and the signals go on as before.
static func set_external(core: SurvivalCore, sid: String, wind_speed_ms: float, wind_from_deg: float) -> void:
	var w := core.state.weather
	w["external"] = true
	var air := SurvivalClock.air_temp_c(core)
	if air < 0.0 and RAIN_TO_SNOW.has(sid):
		sid = str(RAIN_TO_SNOW[sid])
	w["wind_ms"] = maxf(wind_speed_ms, 0.0)
	w["wind_dir_deg"] = fposmod(wind_from_deg, 360.0)
	var old := state_id(core)
	if sid != old and core.data.weather_states.has(sid):
		w["state"] = sid
		w["hours_in_state"] = 0.0
		core._on_weather_changed(old, sid)


## Advance the weather by `hours` game hours: chain ticks, snow on the ground and the overnight-snow flag.
static func tick(core: SurvivalCore, hours: float) -> void:
	var w := core.state.weather
	w["hours_in_state"] = SurvivalUtil.num(w.get("hours_in_state"), 0.0) + hours
	var left := SurvivalUtil.num(w.get("hours_to_tick"), tick_hours(core)) - hours
	while left <= 0.0:
		if not bool(w.get("external", false)):
			_transition(core)
		left += tick_hours(core)
	w["hours_to_tick"] = left
	# Snow on the ground.
	var sid := state_id(core)
	var depth := snow_depth_cm(core)
	var air := SurvivalClock.air_temp_c(core)
	if SNOW_CM_PER_H.has(sid):
		depth += float(SNOW_CM_PER_H[sid]) * hours
		w["last_snow_min"] = core.state.minutes
	elif sid == "thaw" or (precip(core) == "rain" and air > 0.0):
		depth -= MELT_CM_PER_H * hours
	else:
		var target := normal_snow_depth(core)
		if air > 2.0 and depth > target:
			depth -= minf(depth - target, MELT_CM_PER_H * 0.5 * hours)
		else:
			depth += (target - depth) * minf(1.0, DRIFT_TO_NORMAL_PER_H * hours)
	w["snow_depth_cm"] = maxf(0.0, depth)
	if SNOW_CM_PER_H.has(sid) and SurvivalClock.is_night(core):
		w["snowed_tonight"] = true


static func _transition(core: SurvivalCore) -> void:
	var w := core.state.weather
	var old := state_id(core)
	var chains := SurvivalUtil.dict(core.data.section("seasons", "weather").get("chains"))
	var chain := SurvivalUtil.dict(SurvivalUtil.dict(chains.get(SurvivalClock.season(core))).get(old))
	var nxt := SurvivalUtil.weighted_pick(core.rng, chain)
	if nxt == "":
		nxt = old
	nxt = _phase_correct(core, nxt)
	w["noise_c"] = core.rng.randf_range(-3.0, 3.0)
	w["state"] = nxt
	_roll_wind(core)
	if nxt != old:
		w["hours_in_state"] = 0.0
		core._on_weather_changed(old, nxt)


## Rain or snow by the month's snow fraction and the air temperature; a thaw needs snow to thaw.
static func _phase_correct(core: SurvivalCore, sid: String) -> String:
	var air := SurvivalClock.air_temp_c(core)
	var p_snow := clampf(SurvivalClock.month_value(core, "snow_frac"), 0.0, 1.0)
	if air < ALL_SNOW_BELOW_C:
		p_snow = 1.0
	elif air > ALL_RAIN_ABOVE_C:
		p_snow = 0.0
	if RAIN_TO_SNOW.has(sid) and core.rng.randf() < p_snow:
		return str(RAIN_TO_SNOW[sid])
	if SNOW_TO_RAIN.has(sid) and core.rng.randf() >= p_snow:
		return str(SNOW_TO_RAIN[sid])
	if sid == "thaw" and snow_depth_cm(core) <= 0.5 and p_snow <= 0.0:
		return "overcast"
	return sid


static func _roll_wind(core: SurvivalCore) -> void:
	var w := core.state.weather
	var rng_pair := SurvivalUtil.pair(row(core).get("wind_ms"), 2.0)
	w["wind_ms"] = core.rng.randf_range(rng_pair.x, rng_pair.y)
	w["wind_dir_deg"] = fposmod(SurvivalUtil.num(w.get("wind_dir_deg"), 0.0) + core.rng.randf_range(-40.0, 40.0), 360.0)


## Read and clear the "it snowed in the night" flag (used by the trap line's dawn roll).
## Snow fell within the last `hours` game hours (hunt.track reads fresh snow: difficulty_by.fresh_snow).
static func fresh_snow(core: SurvivalCore, hours: float = 24.0) -> bool:
	return core.state.minutes - SurvivalUtil.num(core.state.weather.get("last_snow_min"), -1e9) <= hours * 60.0


static func take_snowed_tonight(core: SurvivalCore) -> bool:
	var v := bool(core.state.weather.get("snowed_tonight", false))
	core.state.weather["snowed_tonight"] = false
	return v


## Gameplay wind as a unit vector on the ground plane (x east, y north) times speed in m/s.
static func wind_vector(core: SurvivalCore) -> Vector2:
	var a := deg_to_rad(SurvivalUtil.num(core.state.weather.get("wind_dir_deg"), 0.0))
	return Vector2(sin(a), cos(a)) * wind_ms(core)


## A short outlook for the journal (Survival tier flags weather_outlook_h: 6 at Apprentice, 12 at Master).
static func outlook(core: SurvivalCore, hours: float) -> Array:
	if hours <= 0.0:
		return []
	var chains := SurvivalUtil.dict(core.data.section("seasons", "weather").get("chains"))
	var chain := SurvivalUtil.dict(SurvivalUtil.dict(chains.get(SurvivalClock.season(core))).get(state_id(core)))
	var likely := []
	for k in chain.keys():
		likely.append([str(k), SurvivalUtil.num(chain[k])])
	likely.sort_custom(func(a, b): return a[1] > b[1])
	return likely.slice(0, 3)
