class_name SurvivalClock
extends RefCounted
## The survival calendar and time of day (the GDD's SimClock), as functions over SurvivalCore.
##
## seasons.json calendar: 12 months x early/mid/late = a 36-day game year; a game day stands for about ten calendar
## days, and the living in it is counted with the one flow factor (5). Time is kept as game minutes since 00:00 of
## Early January of the base year (SurvivalState.minutes). Time of day is gameplay-only (light_level) until the visuals
## workflow agrees an interface (seasons.json time_of_day): nothing here touches the environment rig or shader globals.

const MIN_PER_DAY := 1440.0
const PHASE_NAMES := ["Early", "Mid", "Late"]
const MONTH_NAMES := {"jan": "January", "feb": "February", "mar": "March", "apr": "April", "may": "May",
		"jun": "June", "jul": "July", "aug": "August", "sep": "September", "oct": "October", "nov": "November",
		"dec": "December"}
## Hour of the day's warmest air (the day curve's peak) [D].
const WARMEST_HOUR := 15.0
## Civil twilight modelled as 0.75 game hours either side of sunrise and sunset [D].
const TWILIGHT_H := 0.75
const DEFAULT_REGION := "reg.fort_clearing"


static func days_per_year(core: SurvivalCore) -> int:
	return int(SurvivalUtil.num(core.data.section("seasons", "calendar").get("days_per_year"), 36.0))


static func abs_day(core: SurvivalCore) -> int:
	return floori(core.state.minutes / MIN_PER_DAY)


static func day_of_year(core: SurvivalCore) -> int:
	return posmod(abs_day(core), days_per_year(core))


static func year(core: SurvivalCore) -> int:
	return core.state.base_year + floori(float(abs_day(core)) / float(days_per_year(core)))


static func day_id(core: SurvivalCore, doy: int = -1) -> String:
	var d := day_of_year(core) if doy < 0 else posmod(doy, days_per_year(core))
	return str(core.data.day_ids[d]) if d < core.data.day_ids.size() else ""


static func month_index(core: SurvivalCore, doy: int = -1) -> int:
	var d := day_of_year(core) if doy < 0 else posmod(doy, days_per_year(core))
	return floori(d / 3.0)


static func month_id(core: SurvivalCore, doy: int = -1) -> String:
	return str(core.data.month_ids[month_index(core, doy)])


static func phase(core: SurvivalCore) -> int:
	return day_of_year(core) % 3


static func hour(core: SurvivalCore) -> float:
	return fposmod(core.state.minutes, MIN_PER_DAY) / 60.0


static func season(core: SurvivalCore, doy: int = -1) -> String:
	return str(core.data.month(month_id(core, doy)).get("season", ""))


static func date_string(core: SurvivalCore) -> String:
	return "%s %s %d" % [PHASE_NAMES[phase(core)], MONTH_NAMES.get(month_id(core), month_id(core)), year(core)]


static func time_string(core: SurvivalCore) -> String:
	var h := hour(core)
	return "%02d:%02d" % [floori(h), floori(fposmod(h * 60.0, 60.0))]


static func day_index_of(core: SurvivalCore, id: String) -> int:
	return core.data.day_ids.find(id)


## Game minutes for a date: the first occurrence of day_id in `for_year` at `at_hour`.
static func minutes_at(core: SurvivalCore, id: String, for_year: int, at_hour: float = 0.0) -> float:
	var doy := maxi(0, day_index_of(core, id))
	var d := (for_year - core.state.base_year) * days_per_year(core) + doy
	return float(d) * MIN_PER_DAY + at_hour * 60.0


## Is the day (default: today) inside [from_day_id, to_day_id]? Windows may wrap the year end (nov_early..mar_late).
static func in_window(core: SurvivalCore, window, doy: int = -1) -> bool:
	var w: Array = SurvivalUtil.arr(window)
	if w.size() < 2:
		if w.size() == 1:
			return day_id(core, doy) == str(w[0])
		return false
	var d := day_of_year(core) if doy < 0 else posmod(doy, days_per_year(core))
	var a := day_index_of(core, str(w[0]))
	var b := day_index_of(core, str(w[1]))
	if a < 0 or b < 0:
		return false
	if a <= b:
		return d >= a and d <= b
	return d >= a or d <= b


## Game days from today until day_id next comes round (0 = today).
static func days_until(core: SurvivalCore, id: String) -> int:
	var target := day_index_of(core, id)
	if target < 0:
		return -1
	return posmod(target - day_of_year(core), days_per_year(core))


## A month value interpolated by the phase: early leans toward the previous month, late toward the next.
static func month_value(core: SurvivalCore, key: String, doy: int = -1) -> float:
	var d := day_of_year(core) if doy < 0 else posmod(doy, days_per_year(core))
	var mi := floori(d / 3.0)
	var ph := d % 3
	var cur := SurvivalUtil.num(core.data.month(str(core.data.month_ids[mi])).get(key), 0.0)
	if ph == 1:
		return cur
	var other_i := posmod(mi - 1, 12) if ph == 0 else posmod(mi + 1, 12)
	var other := SurvivalUtil.num(core.data.month(str(core.data.month_ids[other_i])).get(key), cur)
	return cur * (2.0 / 3.0) + other * (1.0 / 3.0)


static func daylight_h(core: SurvivalCore) -> float:
	return month_value(core, "daylight_h")


## seasons.json clock.sunrise_rule: sunrise = 12:00 - daylight_h / 2 (solar time).
static func sunrise_h(core: SurvivalCore) -> float:
	return 12.0 - daylight_h(core) / 2.0


static func sunset_h(core: SurvivalCore) -> float:
	return 12.0 + daylight_h(core) / 2.0


static func is_night(core: SurvivalCore) -> bool:
	var h := hour(core)
	return h < sunrise_h(core) or h >= sunset_h(core)


## Gameplay light 0-1 from the date, daylight hours and weather (seasons.json time_of_day.gameplay_light).
## Weather dims by visibility: clear 1.0, overcast ~0.88, rain ~0.65, fog or blizzard ~0.5.
static func light_level(core: SurvivalCore) -> float:
	var h := hour(core)
	var sr := sunrise_h(core)
	var ss := sunset_h(core)
	var sun := 0.0
	if h >= sr + TWILIGHT_H and h <= ss - TWILIGHT_H:
		sun = 1.0
	elif h >= sr - TWILIGHT_H and h < sr + TWILIGHT_H:
		sun = (h - (sr - TWILIGHT_H)) / (2.0 * TWILIGHT_H)
	elif h > ss - TWILIGHT_H and h <= ss + TWILIGHT_H:
		sun = 1.0 - (h - (ss - TWILIGHT_H)) / (2.0 * TWILIGHT_H)
	var vis := SurvivalUtil.num(SurvivalWeather.row(core).get("visibility_m"), 2000.0)
	return clampf(sun * clampf(0.5 + vis / 4000.0, 0.5, 1.0), 0.0, 1.0)


static func region_id(core: SurvivalCore) -> String:
	return str(core.state.context.get("region", DEFAULT_REGION))


static func region_climate(core: SurvivalCore) -> Dictionary:
	var ro := SurvivalUtil.dict(core.data.section("seasons", "climate").get("region_offsets"))
	return SurvivalUtil.dict(ro.get(region_id(core), {}))


## Air temperature in C: the month's low and high (Albany normals less 2 C, seasons.json climate), the region's offset,
## the weather state's temp_add and its +-3 C noise, on a day curve coldest at sunrise and warmest mid-afternoon.
static func air_temp_c(core: SurvivalCore, at_hour: float = -1.0) -> float:
	var h := hour(core) if at_hour < 0.0 else at_hour
	var low := month_value(core, "low_c")
	var high := month_value(core, "high_c")
	var sr := sunrise_h(core)
	var frac := 0.0
	if h >= sr and h <= WARMEST_HOUR:
		frac = (1.0 - cos(PI * (h - sr) / maxf(0.5, WARMEST_HOUR - sr))) / 2.0
	else:
		var span := 24.0 - WARMEST_HOUR + sr
		var e := fposmod(h - WARMEST_HOUR, 24.0)
		frac = (1.0 + cos(PI * e / span)) / 2.0
	var t := lerpf(low, high, frac)
	t += SurvivalUtil.num(region_climate(core).get("temp_c"), 0.0)
	t += SurvivalUtil.num(SurvivalWeather.row(core).get("temp_add_c"), 0.0)
	t += SurvivalUtil.num(core.state.weather.get("noise_c"), 0.0)
	return t


## Forecast low for the coming night (for the sleep dialog): the coldest hour before next sunrise, without noise.
static func night_low_c(core: SurvivalCore) -> float:
	var low := month_value(core, "low_c")
	return low + SurvivalUtil.num(region_climate(core).get("temp_c"), 0.0) \
			+ SurvivalUtil.num(SurvivalWeather.row(core).get("temp_add_c"), 0.0)


## Real minutes per game hour (seasons.json clock): 2.4 by day, 1.2 at night, overridable in state.settings.
static func real_min_per_game_h(core: SurvivalCore) -> float:
	var c := SurvivalUtil.dict(core.data.section("seasons", "clock").get("real_min_per_game_h"))
	if is_night(core) and bool(core.setting("night_compression", true)):
		return SurvivalUtil.num(core.setting("real_min_per_game_h_night", c.get("night", 1.2)), 1.2)
	return SurvivalUtil.num(core.setting("real_min_per_game_h_day", c.get("day", 2.4)), 2.4)


## How many game minutes pass per real second at the current time of day (before any job speed-up).
static func game_minutes_per_real_second(core: SurvivalCore) -> float:
	return 1.0 / maxf(0.01, real_min_per_game_h(core))


## Active season gates (seasons.json gates: trapping_season, deep_snow, mud_season, ...).
static func gate_active(core: SurvivalCore, gate_id: String) -> bool:
	var g := SurvivalUtil.dict(core.data.section("seasons", "gates").get(gate_id))
	if g.is_empty():
		return false
	if g.has("window"):
		return in_window(core, g.window)
	if g.has("months"):
		return SurvivalUtil.arr(g.months).has(month_id(core))
	return false


static func active_gates(core: SurvivalCore) -> Array:
	var out := []
	for k in core.data.section("seasons", "gates").keys():
		if gate_active(core, str(k)):
			out.append(str(k))
	return out


## Calendar events on a day (seasons.json events: `when` is a day id or a [from, to] window).
static func events_on(core: SurvivalCore, doy: int = -1) -> Array:
	var out := []
	for e in core.data.events.values():
		if _event_on(core, e, doy):
			out.append(str(e.id))
	return out


static func _event_on(core: SurvivalCore, e: Dictionary, doy: int) -> bool:
	var w = e.get("when")
	if typeof(w) == TYPE_ARRAY:
		return in_window(core, w, doy)
	return day_id(core, doy) == str(w)


static func event_active(core: SurvivalCore, event_id: String) -> bool:
	var e: Dictionary = core.data.events.get(event_id, {})
	return not e.is_empty() and _event_on(core, e, -1)


## The first day id an event occupies (its `when`, or the start of its window).
static func event_first_day(core: SurvivalCore, event_id: String) -> String:
	var w = SurvivalUtil.dict(core.data.events.get(event_id, {})).get("when")
	if typeof(w) == TYPE_ARRAY:
		return str(w[0]) if w.size() > 0 else ""
	return str(w) if w != null else ""


static func event_last_day(core: SurvivalCore, event_id: String) -> String:
	var w = SurvivalUtil.dict(core.data.events.get(event_id, {})).get("when")
	if typeof(w) == TYPE_ARRAY:
		return str(w[w.size() - 1]) if w.size() > 0 else ""
	return str(w) if w != null else ""
