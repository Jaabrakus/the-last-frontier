class_name WeatherSystem
extends RefCounted
## The weather the sky shows (cloud engine, 2026-09-26; user: "we can see a storm coming in"). Pure logic on game
## hours, testable headless (tests/env/test_weather.gd); DayNight ticks it, uploads its CloudField to the sky and
## drives the light, fog and wind from it; WeatherFx plays the rain, the lightning light and the thunder.
##
## Kinds, in a seasonal chain (NEXT, DURATION_H): clear (a few cumulus), fair (fair-weather cumulus that
## build through the day and flatten at night), overcast (a stratocumulus deck, a cirrostratus veil, sometimes light
## rain) and storm. A storm is a front: a squall line spawned FRONT_START_M upwind of the player that moves with the
## wind aloft at FRONT_SPEED_M_PER_H. Its phases at the player (phase()):
##   storm_distant   towers and anvil tops on the upwind horizon, lightning flickering in them, rain shafts under them
##   storm_approach  the anvil shield spreads overhead (the sun dims, a halo), the dark bases rise from the horizon
##   storm           the gust front (wind), then the core: heavy rain, lightning and thunder close by
##   rain            the trailing nimbostratus deck: steady light rain
##   clearing        the front has gone downwind; crisp air (long views), broken cumulus
## Wind aloft: the prevailing westerly (true bearing FROM ~255 deg) wandering +-40 deg, its speed set by the weather
## (WIND_BAND, brewing before storms); the clouds drift with it (CLOUD_TIME_SCALE faster, the day being 25x), the
## cirrus with a faster, veered wind above (parallax); the ground wind (the vegetation's wind_direction / wind_strength globals) is backed, weaker, and
## gusts at the storm's arrival. The survival weather (scripts/survival/survival_weather.gd) is a separate gameplay
## model; survival_state() maps this one onto its ids for a later hook-up.
##
## Dev: force_state() / cycle_forced() (DayNight: Shift+F8 cycles clear -> fair -> overcast -> storm approaching).

enum Kind { CLEAR, FAIR, OVERCAST, STORM }
const KIND_NAMES: Array[String] = ["clear", "fair", "overcast", "storm"]

## Target look per kind: fair-weather cumulus cover, stratocumulus deck, cirrus, cirrostratus veil, haze (km).
## No cirrus streaks (user 2026-09-26: "i do not like cirrus clouds"): "ci" stays 0; the smooth cirrostratus veil and
## the storm's anvil shield (veil, the front) are not streaks and stay.
const LOOK := {
	Kind.CLEAR: {"cu": 0.07, "sc": 0.0, "ci": 0.0, "veil": 0.0, "haze": 42.0},
	Kind.FAIR: {"cu": 0.27, "sc": 0.0, "ci": 0.0, "veil": 0.0, "haze": 30.0},
	Kind.OVERCAST: {"cu": 0.2, "sc": 0.93, "ci": 0.0, "veil": 0.5, "haze": 16.0},
	Kind.STORM: {"cu": 0.26, "sc": 0.0, "ci": 0.0, "veil": 0.05, "haze": 38.0},
}
## Game hours a kind lasts (min, max); a storm lasts until its front has passed.
const DURATION_H := {Kind.CLEAR: [3.0, 9.0], Kind.FAIR: [4.0, 10.0], Kind.OVERCAST: [5.0, 12.0], Kind.STORM: [0.0, 0.0]}
## The next kind's odds in summer (June-August); spring and autumn halve the storms (more overcast), winter
## nearly none.
const NEXT := {
	Kind.CLEAR: {Kind.FAIR: 0.7, Kind.OVERCAST: 0.15, Kind.STORM: 0.15},
	Kind.FAIR: {Kind.CLEAR: 0.3, Kind.OVERCAST: 0.3, Kind.STORM: 0.4},
	Kind.OVERCAST: {Kind.FAIR: 0.35, Kind.CLEAR: 0.2, Kind.STORM: 0.45},
	Kind.STORM: {Kind.FAIR: 0.6, Kind.CLEAR: 0.4},
}
## Clouds and wind follow the weather (user 2026-09-26: "i dont want the clouds to move all the time sometimes theres
## no clouds it should be based on the weather ... a rainstorm is happening the clouds start to move faster ... a next
## relaxing day very slow winds"). Each spell rolls its wind aloft in WIND_BAND (m/s; the clouds drift at
## CLOUD_TIME_SCALE x it) and its cloud amount (x LOOK's cumulus; a clear spell is empty CLEAR_EMPTY_ODDS of the time).
## BREW_H before a storm (or an overcast spell) the next spell is known and the wind builds toward WIND_BREW: something
## brewing. A storm's wind follows its phase at the player (WIND_STORM), then falls away with the next calm spell.
const WIND_BAND := {Kind.CLEAR: Vector2(1.5, 6.0), Kind.FAIR: Vector2(3.0, 9.0), Kind.OVERCAST: Vector2(8.0, 14.0),
		Kind.STORM: Vector2(14.0, 20.0)}
const WIND_BREW := {Kind.STORM: 17.0, Kind.OVERCAST: 11.0}
const WIND_STORM := {"storm_distant": 16.0, "storm_approach": 22.0, "storm": 27.0, "rain": 15.0, "clearing": 7.0}
const WIND_TAU_H := 0.5                ## game hours for the wind to follow its target
const BREW_H := 3.0
const CLOUDS_BAND := {Kind.CLEAR: Vector2(0.5, 1.4), Kind.FAIR: Vector2(0.7, 1.3), Kind.OVERCAST: Vector2(1.0, 1.0),
		Kind.STORM: Vector2(1.0, 1.0)}
const CLEAR_EMPTY_ODDS := 0.45
const FRONT_START_M := 140000.0        ## a new front appears this far upwind: towers on the horizon
const FRONT_SPEED_M_PER_H := 42000.0   ## per game hour (squall lines move 40-60 km/h): ~3 game h / 8 real min to arrive
const FRONT_PASSED_M := 30000.0        ## gone once the player is this far behind its trailing deck
const FRONT_SHAPE := Vector4(16000.0, 45000.0, 75000.0, 13000.0)
const COVER_TAU_H := 0.35              ## game hours for the clouds to follow a change of weather
const CLOUD_TIME_SCALE := 2.5          ## the clouds drift this much faster than the wind aloft (the day runs 25x)
const RISE_MS := 3.0                   ## m/s the cloud noise rises (the shapes build and dissolve)
const CIRRUS_TILE_M := 26000.0         ## the sky shader's cirrus_tile_m
## The cirrus drift wraps every 100 tiles, not every tile: ce_cirrus samples the veil's noise at 0.37 x the tile, so a
## one-tile wrap would make the veil (overcast, the anvil shield) jump every ~7 real minutes.
const CIRRUS_WRAP_M := CIRRUS_TILE_M * 100.0
const SOUND_MS := 343.0

var field: CloudField
var rng := RandomNumberGenerator.new()
var kind := Kind.FAIR
var kind_hours := 0.0                  ## game hours in the current kind
var kind_duration := 6.0
var hours_total := 0.0                 ## the weather's own clock (game hours)
var clearing := false                  ## the fair / clear spell right after a front (crisp air)
var drizzle := false                   ## this overcast spell rains lightly
var front_active := false
## Wind aloft: true bearing it blows FROM (deg) and speed (m/s).
var wind_from_deg := 255.0
var wind_ms := 5.0
var wind_spell := 5.0                  ## this spell's wind aloft (m/s), before the brewing and the storm
var clouds_spell := 1.0                ## this spell's cloud amount (x LOOK's cumulus); 0: not a cloud in the sky
var next_kind := Kind.FAIR             ## the spell after this one, known BREW_H before it starts
var next_known := false

# --- outputs at the player (update()) ------------------------------------------------------------------------------
var rain := 0.0                        ## rain rate 0..1
var gust := 0.0                        ## the storm's gust front 0..1
var overcast := 0.0                    ## how much of the sky overhead is covered 0..1 (greys the air, dims the sky)
var fog_mult := 1.0                    ## x the level's fog density
var wind_ground_dir := Vector2(0.866, -0.5)   ## world xz the ground wind blows toward (the wind_direction global)
var wind_ground_strength := 0.3        ## 0..1 (the wind_strength global)
# lightning
var flash := Vector4.ZERO              ## world x, altitude, world z, power: the flash inside the cloud
var bolt := Vector4.ZERO               ## world x, z, seed, brightness: a stroke to the ground
var sky_flash := 0.0                   ## a nearby flash lighting up the whole sky 0..1
var ground_flash := 0.0                ## its light on the ground 0..1
var flash_dir := Vector3.UP            ## toward the flash (world)
var strikes := 0                       ## strokes so far
## Thunder to play: {"delay": s after now, "distance": m, "power": 0..1}. WeatherFx takes them.
var thunder: Array[Dictionary] = []

var _cu := 0.3
var _sc := 0.0
var _ci := 0.0
var _veil := 0.0
var _haze := 30.0
var _player := Vector2.ZERO
var _hour := 12.0
var _wind_noise := FastNoiseLite.new()
var _next_strike := 3.0
var _strike_t := -1.0
var _strike := {}
var _front_strength := 1.0


func _init(p_field: CloudField = null, seed := 1765) -> void:
	field = p_field if p_field else CloudField.new(false)
	rng.seed = seed
	_wind_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_wind_noise.frequency = 0.05
	_wind_noise.seed = seed + 1
	field.front_shape = FRONT_SHAPE
	kind_duration = rng.randf_range(DURATION_H[kind][0], DURATION_H[kind][1])
	_roll_spell(kind)
	wind_ms = wind_spell
	_snap_look(12.0)


## Advance: dt real seconds (cloud motion, lightning) and dh game hours (the weather itself). player: world position
## of the player / camera; hour: local solar time; month 0..11.
func update(dt: float, dh: float, player: Vector3, hour: float, month: int) -> void:
	_player = Vector2(player.x, player.z)
	_hour = hour
	hours_total += dh
	_update_wind(dh)
	if kind == Kind.STORM:
		if front_active:
			field.front.z += FRONT_SPEED_M_PER_H * dh
			var behind := -field.front_u(_player) - FRONT_SHAPE.x - FRONT_SHAPE.y   # m past the trailing deck
			if behind > FRONT_PASSED_M:
				front_active = false
				field.front.w = 0.0
				_set_kind(Kind.FAIR if rng.randf() < 0.6 else Kind.CLEAR)
				clearing = true
			else:
				# the passed front dissolves as it goes off downwind, so dropping it is not a pop on the horizon
				field.front.w = _front_strength * (1.0 - smoothstep(0.0, FRONT_PASSED_M, behind))
		else:
			_set_kind(Kind.FAIR)
	else:
		kind_hours += dh
		if not next_known and kind_hours >= kind_duration - BREW_H:
			next_kind = _pick_next(month)
			next_known = true
		if kind_hours >= kind_duration:
			clearing = false
			_set_kind(next_kind if next_known else _pick_next(month))
	_update_look(dh, hour)
	_update_drift(dt)
	_update_ground()
	_update_lightning(dt, player)


## The phase at the player: clear / fair / overcast, or the storm's storm_distant / storm_approach / storm / rain /
## clearing.
func phase() -> String:
	if kind == Kind.STORM and front_active:
		var u := field.front_u(_player)
		if u > FRONT_SHAPE.z:
			return "storm_distant"
		if u > 1500.0:
			return "storm_approach"
		if u > -FRONT_SHAPE.x:
			return "storm"
		if u > -FRONT_SHAPE.x - FRONT_SHAPE.y:
			return "rain"
		return "clearing"
	if clearing and kind_hours < 2.0:
		return "clearing"
	return KIND_NAMES[kind]


## Metres from the player to the storm's leading edge (> 0: still coming), INF without a storm.
func storm_distance() -> float:
	return field.front_u(_player) if front_active else INF


## The survival model's weather id for this sky (seasons.json weather.states): clear, overcast, rain or storm.
func survival_state() -> String:
	if rain > 0.5 or gust > 0.5:
		return "storm"
	if rain > 0.05:
		return "rain"
	if overcast > 0.6:
		return "overcast"
	return "clear"


## Sets the weather now (dev key, tests, captures): clear, fair, overcast, storm (a front on the upwind horizon),
## storm_near (40 km off), storm_here (the core overhead). False for an unknown name.
func force_state(name: String) -> bool:
	match name:
		"clear":
			_set_kind(Kind.CLEAR)
		"fair":
			_set_kind(Kind.FAIR)
		"overcast":
			_set_kind(Kind.OVERCAST)
		"storm":
			_start_front(FRONT_START_M)
		"storm_near":
			_start_front(40000.0)
		"storm_here":
			_start_front(-0.45 * FRONT_SHAPE.x)
		_:
			return false
	clearing = false
	kind_duration = maxf(kind_duration, 2.0)
	_snap_look(_hour)
	_update_ground()
	return true


## The dev key's cycle (Shift+F8): clear -> fair -> overcast -> storm (approaching) -> clear ...
func next_forced() -> String:
	var order := ["clear", "fair", "overcast", "storm"]
	return order[(order.find(KIND_NAMES[kind]) + 1) % order.size()]


## Forces the next state of the dev cycle; returns its name.
func cycle_forced() -> String:
	var next := next_forced()
	force_state(next)
	return next


func describe() -> String:
	return "weather %s (%s) cu=%.2f sc=%.2f ci=%.2f veil=%.2f haze=%.0fkm rain=%.2f gust=%.2f wind %03.0f@%.0fm/s storm=%s" % [
			KIND_NAMES[kind], phase(), _cu, _sc, _ci, _veil, _haze, rain, gust, wind_from_deg, wind_ms,
			("%.1f km" % (storm_distance() / 1000.0)) if front_active else "-"]


# --- internals -----------------------------------------------------------------------------------------------------

func _set_kind(k: Kind) -> void:
	kind = k
	kind_hours = 0.0
	var dr: Array = DURATION_H[k]
	kind_duration = rng.randf_range(dr[0], dr[1])
	drizzle = k == Kind.OVERCAST and rng.randf() < 0.4
	_roll_spell(k)
	if k == Kind.STORM and not front_active:
		_start_front(FRONT_START_M)
	elif k != Kind.STORM:
		front_active = false
		field.front.w = 0.0


func _start_front(ahead_m: float) -> void:
	kind = Kind.STORM
	kind_hours = 0.0
	front_active = true
	var to := wind_to()
	field.front = Vector4(to.x, to.y, 0.0, rng.randf_range(0.8, 1.0))
	_front_strength = field.front.w
	# leading edge `ahead_m` upwind of the player (the bow of the line included)
	field.front.z = 0.0
	var u0 := field.front_u(_player)
	field.front.z = u0 - ahead_m
	_next_strike = rng.randf_range(1.0, 4.0)


func _pick_next(month: int) -> Kind:
	var odds: Dictionary = (NEXT[kind] as Dictionary).duplicate()
	var storm_mult := 1.0
	if month == 11 or month <= 1:
		storm_mult = 0.08
	elif month <= 4 or month >= 8:
		storm_mult = 0.5
	if odds.has(Kind.STORM):
		var s: float = odds[Kind.STORM]
		odds[Kind.STORM] = s * storm_mult
		odds[Kind.OVERCAST] = float(odds.get(Kind.OVERCAST, 0.0)) + s * (1.0 - storm_mult)
	var total := 0.0
	for k in odds:
		total += float(odds[k])
	var r := rng.randf() * total
	for k in odds:
		r -= float(odds[k])
		if r <= 0.0:
			return k
	return Kind.FAIR


## Unit world xz vector the wind aloft blows toward.
func wind_to() -> Vector2:
	var b := deg_to_rad(wind_from_deg + 180.0)
	var w := WorldClock.enu_to_world(Vector3(sin(b), cos(b), 0.0))
	return Vector2(w.x, w.z).normalized()


func _update_wind(dh: float) -> void:
	wind_from_deg = fposmod(255.0 + 40.0 * _wind_noise.get_noise_1d(hours_total), 360.0)
	var k := 1.0 - exp(-maxf(dh, 0.0) / WIND_TAU_H)
	wind_ms = lerpf(wind_ms, wind_target() * (1.0 + 0.15 * _wind_noise.get_noise_1d(hours_total * 0.7 + 400.0)), k)


## The wind aloft the weather is heading for (m/s): the spell's own, building before a storm or an overcast spell,
## the storm's by its phase at the player.
func wind_target() -> float:
	if kind == Kind.STORM and front_active:
		return float(WIND_STORM.get(phase(), wind_spell))
	var t := wind_spell
	if next_known and WIND_BREW.has(next_kind):
		t = lerpf(t, maxf(t, float(WIND_BREW[next_kind])), smoothstep(kind_duration - BREW_H, kind_duration, kind_hours))
	return t


func _roll_spell(k: Kind) -> void:
	next_known = false
	var wb: Vector2 = WIND_BAND[k]
	wind_spell = rng.randf_range(wb.x, wb.y)
	var cb: Vector2 = CLOUDS_BAND[k]
	clouds_spell = 0.0 if k == Kind.CLEAR and rng.randf() < CLEAR_EMPTY_ODDS else rng.randf_range(cb.x, cb.y)


## Diurnal cycle of the fair-weather cumulus: they build from mid-morning, peak in the afternoon, flatten at dusk.
static func convection(hour: float) -> float:
	return 0.35 + 0.65 * smoothstep(8.5, 13.0, hour) * (1.0 - smoothstep(17.0, 20.5, hour))


func _targets(hour: float) -> Dictionary:
	var look: Dictionary = (LOOK[kind] as Dictionary).duplicate()
	var conv := convection(hour)
	if kind != Kind.OVERCAST:
		look.cu = float(look.cu) * conv
	look.cu = float(look.cu) * clouds_spell
	if clearing:
		look.haze = 60.0
		look.cu = float(look.cu) * 0.8
	return look


func _snap_look(hour: float) -> void:
	var t := _targets(hour)
	_cu = t.cu
	_sc = t.sc
	_ci = t.ci
	_veil = t.veil
	_haze = t.haze
	_update_look(0.0, hour)


func _update_look(dh: float, hour: float) -> void:
	var t := _targets(hour)
	var k := 1.0 - exp(-maxf(dh, 0.0) / COVER_TAU_H)
	_cu = lerpf(_cu, t.cu, k)
	_sc = lerpf(_sc, t.sc, k)
	_ci = lerpf(_ci, t.ci, k)
	_veil = lerpf(_veil, t.veil, k)
	_haze = lerpf(_haze, t.haze, k)
	var conv := convection(hour)
	field.cu_cover = _cu
	field.cu_base = lerpf(1100.0, 1600.0, conv)
	field.cu_top = field.cu_base + 600.0 + 1000.0 * conv   # humilis in the morning, mediocris by afternoon
	field.sc_cover = _sc
	field.sc_base = 1000.0
	field.sc_top = 2000.0 + 400.0 * _sc
	field.cirrus_coverage = _ci
	field.veil = _veil
	field.haze_km = _haze
	field.cloud_ceiling = 11500.0 if front_active else maxf(field.cu_top, field.sc_top) + 300.0
	if not front_active:
		field.front.w = 0.0


func _update_drift(dt: float) -> void:
	var to := wind_to()
	var step := to * wind_ms * CLOUD_TIME_SCALE * dt
	field.drift = Vector2(fposmod(field.drift.x + step.x, CloudField.BASE_TILE), fposmod(field.drift.y + step.y, CloudField.BASE_TILE))
	field.patch_offset += step
	# cirrus: the faster wind aloft, veered 25 deg (parallax against the cumulus)
	var hi := to.rotated(deg_to_rad(25.0)) * wind_ms * 1.8 * CLOUD_TIME_SCALE * dt
	field.cirrus_drift = Vector2(fposmod(field.cirrus_drift.x + hi.x, CIRRUS_WRAP_M), fposmod(field.cirrus_drift.y + hi.y, CIRRUS_WRAP_M))
	field.cloud_evolve = fposmod(field.cloud_evolve + RISE_MS * dt, CloudField.BASE_TILE)


func _update_ground() -> void:
	var f := field.front_at(_player) if front_active else Vector4.ZERO
	rain = maxf(clampf(f.w * 1.3, 0.0, 1.0), 0.22 * _sc if drizzle else 0.0)
	overcast = clampf(maxf(maxf(_sc * 0.95, maxf(f.x, f.y) * 1.2), f.z * 0.55 + _veil * 0.3), 0.0, 1.0)
	gust = 0.0
	if front_active:
		var u := field.front_u(_player)
		gust = field.front.w * smoothstep(6000.0, 1000.0, u) * smoothstep(-0.5 * FRONT_SHAPE.x, -0.15 * FRONT_SHAPE.x, u)
	var to := wind_to()
	var ground := to.rotated(deg_to_rad(-20.0))          # backed by the ground's friction
	if front_active and gust > 0.0:
		ground = ground.lerp(Vector2(field.front.x, field.front.y), gust).normalized()
	wind_ground_dir = ground
	wind_ground_strength = clampf(0.1 + wind_ms * 0.011 + 0.12 * overcast + 0.55 * gust + 0.2 * rain, 0.0, 1.0)
	fog_mult = 1.0 + 3.0 * rain + 0.5 * _sc


func _update_lightning(dt: float, player: Vector3) -> void:
	flash = Vector4.ZERO
	bolt = Vector4.ZERO
	sky_flash = 0.0
	ground_flash = 0.0
	if _strike_t >= 0.0:
		_strike_t += dt
		var b := 0.0
		for p: Array in _strike.pulses:
			var t0: float = p[0]
			if _strike_t >= t0:
				b += float(p[1]) * exp(-(_strike_t - t0) / 0.035)
		var pos: Vector3 = _strike.pos
		flash = Vector4(pos.x, pos.y, pos.z, b * 6.0)
		if _strike.cg:
			bolt = Vector4(pos.x, pos.z, _strike.seed, b * 2.5)
		var dist := Vector2(pos.x - player.x, pos.z - player.z).length()
		var near := 1.0 / (1.0 + pow(dist / 7000.0, 2.0))
		sky_flash = clampf(b * near, 0.0, 1.0)
		ground_flash = clampf(b * near * (1.0 if _strike.cg else 0.45), 0.0, 1.5)
		flash_dir = (pos - player).normalized()
		if _strike_t > 1.0:
			_strike_t = -1.0
	if not front_active or field.front.w < 0.3:
		return
	_next_strike -= dt
	if _next_strike > 0.0:
		return
	_next_strike = rng.randf_range(2.0, 8.0) / field.front.w
	# in one of the storm cells nearest the player (ce_front's cells: spacing along the line, staggered across it)
	var dir := Vector2(field.front.x, field.front.y)
	var perp := Vector2(-dir.y, dir.x)
	var spacing := FRONT_SHAPE.w
	var shift := field.front.z * 3e-6
	var ci := roundf(_player.dot(perp) / spacing + shift) + float(rng.randi_range(-1, 1) + (rng.randi_range(-2, 2) if rng.randf() < 0.3 else 0))
	var a := (ci + rng.randfn(0.0, 0.12) - shift) * spacing
	var u := rng.randfn(0.0, 0.18) * FRONT_SHAPE.x - 0.45 * FRONT_SHAPE.x - 0.12 * FRONT_SHAPE.x * sin(ci * 1.7)
	var s := field.front.z + u - 5000.0 * sin(a * 2.2e-5 + 0.7)
	var xz := perp * a + dir * s
	var f := field.front_at(xz)
	if f.x < 0.25:
		return
	var cg := rng.randf() < 0.3
	var pulses := [[0.0, 1.0]]
	var t := 0.0
	for i in rng.randi_range(1, 3):
		t += rng.randf_range(0.06, 0.2)
		pulses.append([t, rng.randf_range(0.4, 0.9)])
	_strike = {"pos": Vector3(xz.x, rng.randf_range(3000.0, 7500.0), xz.y), "cg": cg, "seed": rng.randf() * 100.0, "pulses": pulses}
	_strike_t = 0.0
	strikes += 1
	var dist := Vector2(xz.x - player.x, xz.y - player.z).length()
	thunder.append({"delay": dist / SOUND_MS, "distance": dist, "power": clampf(f.x * (1.3 if cg else 0.9), 0.0, 1.0)})
