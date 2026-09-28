class_name WorldClock
extends Node
## Time of day, calendar and sky geometry for the Frontier environment (package A sky system).
##
## Local apparent solar time (`hour`, 12.0 = the sun on the meridian), a calendar date (`year`,
## `day_of_year` 1..365, fractional allowed) and the site (latitude 43.0 N, longitude 74.5 W: the
## upper Mohawk Valley). The sun follows the date and latitude (solar declination from the
## ecliptic longitude); the moon has its real 18th-century position and phase (the main terms of the
## lunar theory, ~0.1 deg; as seen from the ground: its parallax, and its distance for the drawn size), and
## the stars turn with local sidereal time.
##
## The level's compass is rotated against true north by `north_offset_deg()` (the fort's gate faces
## true bearing ~44 deg): at the default date and time (DEFAULT_DAY_OF_YEAR = 237, 25 August, and
## the afternoon hour at which the sun is 19.1 deg high) the sun stands exactly at the
## gameplay-validated world azimuth EnvironmentRig.SUN_AZIMUTH_DEG = 222.5 deg (look-dev spec 3.2),
## so every gate validated at the static sun keeps passing at the default state.
##
## World compass: 0 = north = -Z, 90 = east = +X (as EnvironmentRig.sun_direction()).
##
## Clock rate (data/survival/seasons.json clock.real_min_per_game_h): 2.4 real minutes per game
## hour by day, 1.2 at night. The clock does not run unless `running` is set (the test level keeps
## the validated golden hour); the survival systems will drive it (EnvironmentRig.sync_from_survival)
## or set it directly (set_time / set_date / set_game_day).
##
## Survival calendar: 36 game days a year (12 months x early / mid / late). game_day_to_doy()
## maps a game day index (0 = Early January) to the real day of the year (5th, 15th or 25th).

signal changed

const LATITUDE_DEG := 43.0
const LONGITUDE_DEG := -74.5
const DEFAULT_YEAR := 1765
const DEFAULT_DAY_OF_YEAR := 237.0          ## 25 August (the survival calendar's "aug_late")
const DEFAULT_SUN_ELEVATION_DEG := 19.1     ## EnvironmentRig.SUN_ELEVATION_DEG
const DEFAULT_SUN_AZIMUTH_DEG := 222.5      ## EnvironmentRig.SUN_AZIMUTH_DEG
const MONTH_START_DOY := [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]
const PHASE_DAY := [5, 15, 25]
const MONTH_NAMES := ["January", "February", "March", "April", "May", "June", "July", "August",
		"September", "October", "November", "December"]
const SYNODIC_DAYS := 29.530588
const EARTH_RADIUS_KM := 6378.14

@export var latitude_deg := LATITUDE_DEG
@export var longitude_deg := LONGITUDE_DEG
@export var year := DEFAULT_YEAR
@export_range(1.0, 366.0) var day_of_year := DEFAULT_DAY_OF_YEAR
@export_range(0.0, 24.0) var hour := 17.0
## Advance time in _process (game hours at the seasons.json rate x time_scale).
@export var running := false
@export var time_scale := 1.0
@export var real_min_per_game_h_day := 2.4
@export var real_min_per_game_h_night := 1.2

static var _default_hour := -1.0
static var _north_offset := INF


func _init() -> void:
	hour = default_hour()


func _process(delta: float) -> void:
	if running and time_scale != 0.0:
		advance_hours(delta * time_scale * game_hours_per_real_second())


## Game hours that pass per real second at the current time (day / night rate).
func game_hours_per_real_second() -> float:
	var rate := real_min_per_game_h_night if sun_elevation_deg() < 0.0 else real_min_per_game_h_day
	return 1.0 / (maxf(rate, 0.01) * 60.0)


func advance_hours(h: float) -> void:
	hour += h
	while hour >= 24.0:
		hour -= 24.0
		day_of_year += 1.0
		if day_of_year >= days_in_year(year) + 1.0:
			day_of_year = 1.0
			year += 1
	while hour < 0.0:
		hour += 24.0
		day_of_year -= 1.0
		if day_of_year < 1.0:
			year -= 1
			day_of_year = float(days_in_year(year))
	changed.emit()


func set_time(h: float) -> void:
	hour = fposmod(h, 24.0)
	changed.emit()


func set_date(doy: float, y := -1) -> void:
	if y > 0:
		year = y
	day_of_year = clampf(doy, 1.0, float(days_in_year(year)))
	changed.emit()


## Survival calendar day (0 = Early January .. 35 = Late December).
func set_game_day(game_day: int, y := -1) -> void:
	set_date(game_day_to_doy(game_day), y)


func reset_default() -> void:
	year = DEFAULT_YEAR
	day_of_year = DEFAULT_DAY_OF_YEAR
	hour = default_hour()
	changed.emit()


static func game_day_to_doy(game_day: int) -> float:
	var d := posmod(game_day, 36)
	return float(MONTH_START_DOY[d / 3] - 1 + PHASE_DAY[d % 3])


static func days_in_year(y: int) -> int:
	return 366 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 365


## Month index 0..11 of a day of the year (non-leap table; close enough for the look).
static func month_of(doy: float) -> int:
	var m := 0
	for i in 12:
		if doy >= MONTH_START_DOY[i]:
			m = i
	return m


## Season name as in seasons.json calendar.seasons (winter = Dec-Feb, ...).
func season() -> String:
	var m := month_of(day_of_year)
	if m == 11 or m <= 1:
		return "winter"
	if m <= 4:
		return "spring"
	if m <= 7:
		return "summer"
	return "autumn"


func date_string() -> String:
	var m := month_of(day_of_year)
	var dom: int = int(day_of_year) - int(MONTH_START_DOY[m]) + 1
	return "%d %s %d" % [dom, MONTH_NAMES[m], year]


func time_string() -> String:
	return "%02d:%02d" % [int(hour), int(fposmod(hour * 60.0, 60.0))]


# --- Astronomy -----------------------------------------------------------------------------------

## Days since J2000.0 (2000-01-01 12:00 UT) for the clock's date and local solar time.
static func days_j2000(y: int, doy: float, local_hour: float, lon_deg := LONGITUDE_DEG) -> float:
	# Julian day of January 0.0 of year y (Gregorian), Meeus ch. 7.
	var yy := y - 1
	var a := int(floor(yy / 100.0))
	var b := 2 - a + int(floor(a / 4.0))
	var jd_jan0: float = floor(365.25 * (yy + 4716)) + floor(30.6001 * 14) + b - 1524.5   # 2000 -> 2451543.5
	var ut := local_hour - lon_deg / 15.0
	return jd_jan0 + doy + ut / 24.0 - 2451545.0


## Sun: [right ascension deg, declination deg, ecliptic longitude deg].
static func sun_equatorial(n: float) -> Array:
	var g := deg_to_rad(fposmod(357.529 + 0.98560028 * n, 360.0))
	var q := fposmod(280.459 + 0.98564736 * n, 360.0)
	var lam := deg_to_rad(q + 1.915 * sin(g) + 0.020 * sin(2.0 * g))
	var eps := deg_to_rad(23.439 - 0.00000036 * n)
	var ra := rad_to_deg(atan2(cos(eps) * sin(lam), cos(lam)))
	var dec := rad_to_deg(asin(sin(eps) * sin(lam)))
	return [ra, dec, rad_to_deg(lam)]


## Moon: [right ascension deg, declination deg, ecliptic longitude deg], of the date. The largest terms of Meeus
## ch. 47 (ELP-2000/82): within ~0.1 deg in right ascension and declination (checked over 1765 against the main
## series, review of the sun and moon push; with the single 5.1 deg latitude term alone it was up to 0.8 deg off).
static func moon_equatorial(n: float) -> Array:
	var L := 218.316 + 13.176396 * n
	var M := deg_to_rad(134.963 + 13.064993 * n)
	var F := deg_to_rad(93.272 + 13.229350 * n)
	var D := deg_to_rad(297.850 + 12.190749 * n)
	var Ms := deg_to_rad(357.529 + 0.98560028 * n)
	var lam := L + 6.289 * sin(M) + 1.274 * sin(2.0 * D - M) + 0.658 * sin(2.0 * D) + 0.214 * sin(2.0 * M) \
			- 0.186 * sin(Ms) - 0.114 * sin(2.0 * F) + 0.059 * sin(2.0 * D - 2.0 * M) + 0.057 * sin(2.0 * D - Ms - M) \
			+ 0.053 * sin(2.0 * D + M) + 0.046 * sin(2.0 * D - Ms) - 0.041 * sin(Ms - M) - 0.035 * sin(D) \
			- 0.030 * sin(Ms + M)
	var beta := deg_to_rad(5.128 * sin(F) + 0.281 * sin(M + F) + 0.278 * sin(M - F) + 0.173 * sin(2.0 * D - F) \
			+ 0.055 * sin(2.0 * D - M + F) + 0.046 * sin(2.0 * D - M - F) + 0.033 * sin(2.0 * D + F) + 0.017 * sin(2.0 * M + F))
	var lr := deg_to_rad(fposmod(lam, 360.0))
	var eps := deg_to_rad(23.439 - 0.00000036 * n)
	var x := cos(beta) * cos(lr)
	var yv := cos(eps) * cos(beta) * sin(lr) - sin(eps) * sin(beta)
	var z := sin(eps) * cos(beta) * sin(lr) + cos(eps) * sin(beta)
	return [rad_to_deg(atan2(yv, x)), rad_to_deg(asin(clampf(z, -1.0, 1.0))), fposmod(lam, 360.0)]


## Local (east, north, up) unit vector of a body at hour angle ha (deg, westward) and declination. parallax_deg: the
## body's horizontal parallax (the moon's ~0.95 deg): seen from the ground rather than the Earth's centre it stands
## lower by parallax x cos(elevation).
static func local_enu(ha_deg: float, dec_deg: float, lat_deg: float, parallax_deg := 0.0) -> Vector3:
	var h := deg_to_rad(ha_deg)
	var d := deg_to_rad(dec_deg)
	var p := deg_to_rad(lat_deg)
	var east := -cos(d) * sin(h)
	var north := sin(d) * cos(p) - cos(d) * cos(h) * sin(p)
	var up := sin(d) * sin(p) + cos(d) * cos(h) * cos(p)
	var v := Vector3(east, north, up)
	var el := rad_to_deg(asin(clampf(up, -1.0, 1.0)))
	if parallax_deg != 0.0:
		el -= parallax_deg * cos(deg_to_rad(el))
		var hz0 := Vector2(east, north).normalized() * cos(deg_to_rad(el))
		v = Vector3(hz0.x, hz0.y, sin(deg_to_rad(el)))
	# Atmospheric refraction (Saemundsson), lifts bodies near the horizon by up to ~0.57 deg.
	if el > -2.0:
		var r := 1.02 / tan(deg_to_rad(el + 10.3 / (el + 5.11))) / 60.0
		var el2 := deg_to_rad(el + clampf(r, 0.0, 0.6))
		var hz := Vector2(east, north).normalized() * cos(el2)
		v = Vector3(hz.x, hz.y, sin(el2))
	return v


## World vector (compass rotated by north_offset_deg) from a local (east, north, up) vector.
static func enu_to_world(v: Vector3) -> Vector3:
	var off := deg_to_rad(north_offset_deg())
	var n_w := Vector3(-sin(off), 0.0, -cos(off))
	var e_w := Vector3(cos(off), 0.0, -sin(off))
	return (e_w * v.x + n_w * v.y + Vector3.UP * v.z).normalized()


static func _sun_enu(y: int, doy: float, h: float, lat := LATITUDE_DEG) -> Vector3:
	var s := sun_equatorial(days_j2000(y, doy, h))
	return local_enu(15.0 * (h - 12.0), s[1], lat)


## Hour (local solar time, afternoon) at which the default day's sun is DEFAULT_SUN_ELEVATION_DEG high.
static func default_hour() -> float:
	if _default_hour < 0.0:
		var lo := 12.0
		var hi := 20.0
		var target := sin(deg_to_rad(DEFAULT_SUN_ELEVATION_DEG))
		for i in 60:
			var mid := 0.5 * (lo + hi)
			if _sun_enu(DEFAULT_YEAR, DEFAULT_DAY_OF_YEAR, mid).z > target:
				lo = mid
			else:
				hi = mid
		_default_hour = 0.5 * (lo + hi)
	return _default_hour


## Level compass rotation: world azimuth = true azimuth - north_offset_deg().
static func north_offset_deg() -> float:
	if _north_offset == INF:
		var v := _sun_enu(DEFAULT_YEAR, DEFAULT_DAY_OF_YEAR, default_hour())
		var true_az := rad_to_deg(atan2(v.x, v.y))
		_north_offset = fposmod(true_az - DEFAULT_SUN_AZIMUTH_DEG, 360.0)
	return _north_offset


func _n() -> float:
	return days_j2000(year, day_of_year, hour, longitude_deg)


## Unit vector toward the sun (world space; below the horizon at night).
func sun_direction() -> Vector3:
	var s := sun_equatorial(_n())
	return enu_to_world(local_enu(15.0 * (hour - 12.0), s[1], latitude_deg))


## Unit vector toward the moon (world space), as seen from the ground (topocentric: its parallax lowers it by up to
## ~1 deg, two of its own diameters).
func moon_direction() -> Vector3:
	var n := _n()
	var s := sun_equatorial(n)
	var m := moon_equatorial(n)
	var ha := 15.0 * (hour - 12.0) + float(s[0]) - float(m[0])
	return enu_to_world(local_enu(ha, m[1], latitude_deg, rad_to_deg(asin(EARTH_RADIUS_KM / moon_distance_km_at(n)))))


## The moon's distance from the Earth's centre (km): 356,500 at perigee to 406,700 at apogee (the main terms of
## Meeus ch. 47, ~100 km). Its angular diameter is 2 asin(1737.4 / distance): 0.49 to 0.56 deg.
static func moon_distance_km_at(n: float) -> float:
	var M := deg_to_rad(134.963 + 13.064993 * n)
	var D := deg_to_rad(297.850 + 12.190749 * n)
	var Ms := deg_to_rad(357.529 + 0.98560028 * n)
	return 385000.6 - 20905.4 * cos(M) - 3699.1 * cos(2.0 * D - M) - 2956.0 * cos(2.0 * D) - 569.9 * cos(2.0 * M) \
			+ 246.2 * cos(2.0 * D - 2.0 * M) - 204.6 * cos(2.0 * D - Ms) - 170.7 * cos(2.0 * D + M) \
			- 152.1 * cos(2.0 * D - Ms - M) - 129.6 * cos(Ms - M) + 108.7 * cos(D) + 104.8 * cos(Ms + M)


func moon_distance_km() -> float:
	return moon_distance_km_at(_n())


## Moon age as a fraction of the synodic month: 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
func moon_phase() -> float:
	var n := _n()
	return fposmod(float(moon_equatorial(n)[2]) - float(sun_equatorial(n)[2]), 360.0) / 360.0


## Illuminated fraction of the moon's disc (0 new .. 1 full).
func moon_illumination() -> float:
	return 0.5 * (1.0 - cos(moon_phase() * TAU))


func sun_elevation_deg() -> float:
	return rad_to_deg(asin(clampf(sun_direction().y, -1.0, 1.0)))


## World compass azimuth of the sun (0 = -Z, 90 = +X).
func sun_azimuth_deg() -> float:
	var d := sun_direction()
	return fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)


## World -> equatorial rotation of the DATE (celestial pole at the latitude's altitude above true north, turned
## by local sidereal time).
func celestial_basis_of_date() -> Basis:
	var n := _n()
	var s := sun_equatorial(n)
	var lst := deg_to_rad(float(s[0]) + 15.0 * (hour - 12.0))
	var p := deg_to_rad(latitude_deg)
	var n_w := enu_to_world(Vector3(0, 1, 0))
	var up := Vector3.UP
	var e_w := enu_to_world(Vector3(1, 0, 0))
	var ncp := (n_w * cos(p) + up * sin(p)).normalized()
	var mer := (-n_w * sin(p) + up * cos(p)).normalized()
	var rows := Basis(mer, e_w, ncp).transposed()      # rows: meridian, east, pole
	return Basis(Vector3(0, 0, 1), lst) * rows


## World -> J2000 equatorial rotation for the star map (the Yale catalogue is J2000): the date's frame, precessed
## back to J2000. In 1765 Polaris stood 1.95 deg from the pole (Dec 88 deg 03'; 0.74 deg in 2000) and circled it
## by that much each night, so the star map is period-true for navigation.
func celestial_basis() -> Basis:
	return precession_matrix(_n()).transposed() * celestial_basis_of_date()


## IAU 1976 precession (Lieske et al. 1977; Meeus ch. 21) from the J2000 mean equator and equinox to the mean
## equator and equinox of the date `n` days after J2000.0: v_date = precession_matrix(n) * v_j2000.
## P = R3(-z) R2(theta) R3(-zeta).
static func precession_matrix(n: float) -> Basis:
	var t := n / 36525.0
	var zeta := deg_to_rad((2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) / 3600.0)
	var z := deg_to_rad((2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) / 3600.0)
	var theta := deg_to_rad((2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) / 3600.0)
	return Basis(_precess(Vector3(1, 0, 0), zeta, z, theta), _precess(Vector3(0, 1, 0), zeta, z, theta),
			_precess(Vector3(0, 0, 1), zeta, z, theta))


static func _precess(v: Vector3, zeta: float, z: float, theta: float) -> Vector3:
	# R3(-zeta): turn by +zeta about the pole
	var a := Vector3(v.x * cos(zeta) - v.y * sin(zeta), v.x * sin(zeta) + v.y * cos(zeta), v.z)
	# R2(theta)
	var b := Vector3(a.x * cos(theta) - a.z * sin(theta), a.y, a.x * sin(theta) + a.z * cos(theta))
	# R3(-z)
	return Vector3(b.x * cos(z) - b.y * sin(z), b.x * sin(z) + b.y * cos(z), b.z)


## Unit equatorial vector from right ascension and declination (degrees).
static func radec_vector(ra_deg: float, dec_deg: float) -> Vector3:
	var ra := deg_to_rad(ra_deg)
	var dec := deg_to_rad(dec_deg)
	return Vector3(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec))


## Day length (h) from sunrise to sunset at today's declination (upper limb + refraction).
func daylight_hours() -> float:
	var dec := deg_to_rad(float(sun_equatorial(_n())[1]))
	var p := deg_to_rad(latitude_deg)
	var c := (sin(deg_to_rad(-0.833)) - sin(p) * sin(dec)) / (cos(p) * cos(dec))
	return 2.0 * rad_to_deg(acos(clampf(c, -1.0, 1.0))) / 15.0
