extends SceneTree
## Headless tests for the cloud engine's logic (2026-09-26): the weather state machine (WeatherSystem), its storm
## fronts and what they do at the player, the clouds' CPU mirror (CloudField) and the star map's precession to the
## game year (WorldClock).
##
##   Godot --headless --path . -s tests/env/test_weather.gd [-- --only <name>]
##
## The GPU side of the mirror (the sky shader's clouds against CloudField) needs a window:
## tests/env/weather_mirror_check.gd. Failures are listed and the exit code is 1.

const PLAYER := Vector3(3.0, 1.7, -130.0)

var failures := PackedStringArray()
var passes := 0
var current := ""


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and str(args[0]) == "--only":
		only = str(args[1])
	for name in ["test_determinism", "test_seasonal_chain", "test_storm_passage", "test_forced_states",
			"test_sun_shade_mirror", "test_wind", "test_wind_follows_weather", "test_drift_wraps", "test_dev_cycle", "test_precession"]:
		if only != "" and not name.contains(only):
			continue
		current = name
		var n0 := failures.size()
		call(name)
		print("  %s %s" % ["ok  " if failures.size() == n0 else "FAIL", name])
	print("")
	print("weather: %d checks passed, %d failed (%d ms)" % [passes, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	print("WEATHER TEST %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures.append("%s: %s" % [current, what])


## Runs `w` for `hours` game hours in steps of `step` h, `dt` real seconds per step; returns the phases seen, in order.
func _run(w: WeatherSystem, hours: float, step := 0.1, dt := 0.5, hour := 15.0, month := 7) -> PackedStringArray:
	var seen := PackedStringArray()
	var h := 0.0
	while h < hours:
		w.update(dt, step, PLAYER, fposmod(hour + h, 24.0), month)
		var p := w.phase()
		if seen.is_empty() or seen[seen.size() - 1] != p:
			seen.append(p)
		h += step
	return seen


func test_determinism() -> void:
	var a := WeatherSystem.new(null, 99)
	var b := WeatherSystem.new(null, 99)
	_run(a, 72.0)
	_run(b, 72.0)
	_check(a.describe() == b.describe(), "same seed, same inputs -> same weather (%s | %s)" % [a.describe(), b.describe()])
	_check(a.field.front == b.field.front and a.field.drift == b.field.drift, "same front and cloud drift")
	var c := WeatherSystem.new(null, 100)
	_run(c, 72.0)
	_check(c.describe() != a.describe(), "another seed, another weather")


## A summer month of game hours visits every kind, and each front passes through its phases in order.
func test_seasonal_chain() -> void:
	var w := WeatherSystem.new(null, 1765)
	var kinds := {}
	var fronts := 0
	var order_ok := true
	var rank := {"storm_distant": 0, "storm_approach": 1, "storm": 2, "rain": 3, "clearing": 4}
	var last_rank := -1
	var was_storm := false
	var h := 0.0
	while h < 30.0 * 24.0:
		w.update(0.5, 0.1, PLAYER, fposmod(h, 24.0), 6)
		kinds[WeatherSystem.KIND_NAMES[w.kind]] = true
		var storm := w.kind == WeatherSystem.Kind.STORM and w.front_active
		if storm and not was_storm:
			fronts += 1
			last_rank = -1
		if storm:
			var r: int = rank.get(w.phase(), -1)
			if r < last_rank:
				order_ok = false
			last_rank = maxi(last_rank, r)
		was_storm = storm
		h += 0.1
	_check(kinds.size() == 4, "all four kinds in a summer month (%s)" % [kinds.keys()])
	_check(fronts >= 2, "storm fronts in a summer month (%d)" % fronts)
	_check(order_ok, "each front's phases come in order: distant, approach, storm, rain, clearing")
	# winter: storms nearly never
	var ww := WeatherSystem.new(null, 1765)
	var wf := 0
	var was := false
	h = 0.0
	while h < 30.0 * 24.0:
		ww.update(0.5, 0.1, PLAYER, fposmod(h, 24.0), 0)
		var st := ww.kind == WeatherSystem.Kind.STORM
		if st and not was:
			wf += 1
		was = st
		h += 0.1
	_check(wf < fronts, "fewer storms in January (%d) than in July (%d)" % [wf, fronts])


## A forced storm: seen from 140 km, arrives, rains, gusts, flashes and thunders, passes and clears.
func test_storm_passage() -> void:
	var w := WeatherSystem.new(null, 7)
	w.update(0.0, 0.0, PLAYER, 15.0, 7)
	_check(w.force_state("storm"), "force a storm")
	_check(w.phase() == "storm_distant", "a new front is on the horizon (%s)" % w.phase())
	_check(absf(w.storm_distance() - WeatherSystem.FRONT_START_M) < 1.0, "140 km upwind (%.0f m)" % w.storm_distance())
	var max_rain := 0.0
	var max_gust := 0.0
	var max_overcast := 0.0
	var thunders := 0
	var delay_ok := true
	var hours_to_arrive := -1.0
	var h := 0.0
	var phases := PackedStringArray()
	var strength0 := w.field.front.w
	var last_w := strength0     # the drawn front's strength on the last update it was still on the map
	var fade_ok := true
	while h < 8.0 and w.kind == WeatherSystem.Kind.STORM:
		var w_before := w.field.front.w
		w.update(1.0, 0.02, PLAYER, 15.0, 7)
		if w.front_active:
			last_w = w.field.front.w
			fade_ok = fade_ok and w.field.front.w <= w_before + 1e-6
		if hours_to_arrive < 0.0 and w.phase() == "storm":
			hours_to_arrive = h
		max_rain = maxf(max_rain, w.rain)
		max_gust = maxf(max_gust, w.gust)
		max_overcast = maxf(max_overcast, w.overcast)
		for t: Dictionary in w.thunder:
			thunders += 1
			if absf(float(t.delay) - float(t.distance) / 343.0) > 0.01:
				delay_ok = false
		w.thunder.clear()
		if phases.is_empty() or phases[phases.size() - 1] != w.phase():
			phases.append(w.phase())
		h += 0.02
	print("    storm passage: %s; arrives after %.1f game h; rain %.2f gust %.2f overcast %.2f; %d strokes, %d thunders" % [
			" > ".join(phases), hours_to_arrive, max_rain, max_gust, max_overcast, w.strikes, thunders])
	_check("storm_approach" in phases and "storm" in phases and "rain" in phases, "approach, storm and rain phases")
	_check(hours_to_arrive > 2.0 and hours_to_arrive < 4.5, "it takes 2-4.5 game hours to arrive (%.1f)" % hours_to_arrive)
	_check(max_rain > 0.7, "heavy rain in the core (%.2f)" % max_rain)
	_check(max_gust > 0.3, "a gust front (%.2f)" % max_gust)
	_check(max_overcast > 0.9, "the sky covered overhead (%.2f)" % max_overcast)
	_check(w.strikes > 20 and thunders == w.strikes, "lightning strokes with their thunder (%d / %d)" % [w.strikes, thunders])
	_check(delay_ok, "thunder delayed by the distance / 343 m/s")
	_check(w.kind != WeatherSystem.Kind.STORM and not w.front_active, "the front passes and the storm ends (%s)" % w.describe())
	_check(w.phase() == "clearing", "clearing after the front (%s)" % w.phase())
	_check(fade_ok and last_w < 0.05 * strength0, "the passed front dissolves before it is dropped (strength %.2f -> %.3f)" % [strength0, last_w])
	_run(w, 1.0, 0.05)
	_check(w.field.haze_km > 45.0, "crisp air after the front (%.0f km)" % w.field.haze_km)


func test_forced_states() -> void:
	var w := WeatherSystem.new(null, 3)
	w.update(0.0, 0.0, PLAYER, 15.0, 7)
	for st in ["clear", "fair", "overcast", "storm", "storm_near", "storm_here"]:
		_check(w.force_state(st), "force %s" % st)
		w.update(0.016, 0.0, PLAYER, 15.0, 7)
		match st:
			"clear":
				_check(w.field.cu_cover < 0.1 and w.field.sc_cover < 0.05 and w.rain == 0.0, "clear: few clouds, no rain")
				_check(w.survival_state() == "clear", "clear -> survival clear")
			"fair":
				_check(w.field.cu_cover > 0.15 and w.field.sc_cover < 0.05, "fair: cumulus (%.2f)" % w.field.cu_cover)
			"overcast":
				_check(w.field.sc_cover > 0.8 and w.overcast > 0.8, "overcast: a deck (%.2f, %.2f)" % [w.field.sc_cover, w.overcast])
				_check(w.survival_state() in ["overcast", "rain"], "overcast -> survival overcast / rain")
			"storm_near":
				_check(absf(w.storm_distance() - 40000.0) < 1.0, "storm_near is 40 km off")
				_check(w.field.cloud_ceiling > 11000.0, "the march reaches the anvils with a storm about")
			"storm_here":
				_check(w.phase() == "storm" and w.rain > 0.5, "storm_here: in the core, raining (%s %.2f)" % [w.phase(), w.rain])
				_check(w.survival_state() == "storm", "storm -> survival storm")
				_check(w.fog_mult > 2.5, "fog thickens in heavy rain (%.1f)" % w.fog_mult)
	_check(not w.force_state("hail"), "an unknown state is refused")


## The CPU mirror of the clouds: clear sky lets the sun through, a deck or a storm core does not.
func test_sun_shade_mirror() -> void:
	var f := CloudField.new()
	_check(f.has_noise(), "the 3D cloud noise loads on the CPU")
	var w := WeatherSystem.new(f, 11)
	w.update(0.0, 0.0, PLAYER, 15.0, 7)
	var sun := Vector3(-0.47, 0.48, 0.74).normalized()
	w.force_state("clear")
	w.update(0.016, 0.0, PLAYER, 15.0, 7)
	var up := f.sun_transmittance(Vector3.UP, PLAYER)
	_check(up > 0.9, "clear sky overhead lets the sun through (%.2f)" % up)
	w.force_state("overcast")
	w.update(0.016, 0.0, PLAYER, 15.0, 7)
	var oc := f.sun_transmittance(sun, PLAYER)
	_check(oc < 0.1, "an overcast deck hides the sun (%.2f)" % oc)
	w.force_state("storm_here")
	w.update(0.016, 0.0, PLAYER, 15.0, 7)
	var t0 := Time.get_ticks_usec()
	var sc := f.sun_transmittance(sun, PLAYER)
	var us := Time.get_ticks_usec() - t0
	_check(sc < 0.05, "a storm core hides the sun (%.2f)" % sc)
	_check(us < 5000, "the mirror's march is cheap (%d us)" % us)
	# fair weather: some directions clear, some cloudy (cumulus, not a sheet)
	w.force_state("fair")
	w.update(0.016, 0.0, PLAYER, 15.0, 7)
	var clear_n := 0
	var cloudy_n := 0
	for i in 64:
		var az := float(i) * 0.7
		var el := deg_to_rad(25.0 + float(i % 8) * 7.0)
		var d := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var tr := f.view_transmittance(d, PLAYER)
		if tr > 0.8:
			clear_n += 1
		elif tr < 0.2:
			cloudy_n += 1
	_check(clear_n > 10 and cloudy_n > 5, "fair cumulus: clear gaps (%d) and clouds (%d) among 64 views" % [clear_n, cloudy_n])


func test_wind() -> void:
	var w := WeatherSystem.new(null, 5)
	var lo := 360.0
	var hi := 0.0
	var ok := true
	var h := 0.0
	while h < 200.0:
		w.update(0.1, 0.25, PLAYER, 12.0, 7)
		lo = minf(lo, w.wind_from_deg)
		hi = maxf(hi, w.wind_from_deg)
		if w.wind_ms < 1.0 or w.wind_ms > 31.0 or w.wind_ground_strength < 0.0 or w.wind_ground_strength > 1.0:
			ok = false
		if absf(w.wind_ground_dir.length() - 1.0) > 0.01:
			ok = false
		h += 0.25
	_check(lo > 205.0 and hi < 305.0, "prevailing westerly: from %.0f..%.0f deg" % [lo, hi])
	_check(hi - lo > 15.0, "the wind veers and backs over the days (%.0f deg)" % (hi - lo))
	_check(ok, "wind speeds and the ground wind stay in range")
	# the fronts come from upwind and move downwind
	w.force_state("storm")
	var d0 := w.storm_distance()
	w.update(0.0, 0.5, PLAYER, 12.0, 7)
	_check(d0 - w.storm_distance() > 0.45 * WeatherSystem.FRONT_SPEED_M_PER_H, "the front moves in with the wind")


## The wind and the clouds follow the weather (user 2026-09-26): calm clear days, some without a cloud; the wind builds
## before a storm and peaks with it.
func test_wind_follows_weather() -> void:
	var w := WeatherSystem.new(null, 11)
	var calm: Array[float] = []
	var brewing: Array[float] = []
	var storm: Array[float] = []
	var empty := 0
	var clear_spells := 0
	var last_kind := -1
	var h := 0.0
	while h < 24.0 * 60.0:
		w.update(0.0, 0.1, PLAYER, 12.0, 7)
		if w.kind != last_kind:
			last_kind = w.kind
			if w.kind == WeatherSystem.Kind.CLEAR:
				clear_spells += 1
				if w.clouds_spell == 0.0:
					empty += 1
		if w.kind == WeatherSystem.Kind.CLEAR and not (w.next_known and w.next_kind == WeatherSystem.Kind.STORM):
			calm.append(w.wind_ms)
		elif w.kind != WeatherSystem.Kind.STORM and w.next_known and w.next_kind == WeatherSystem.Kind.STORM \
				and w.kind_hours > w.kind_duration - 0.3:
			brewing.append(w.wind_ms)
		elif w.kind == WeatherSystem.Kind.STORM and w.phase() == "storm":
			storm.append(w.wind_ms)
		h += 0.1
	var avg := func(a: Array[float]) -> float:
		var t := 0.0
		for x in a:
			t += x
		return t / maxf(a.size(), 1.0)
	print("    wind aloft: calm clear %.1f m/s, just before a storm %.1f, in the storm %.1f; %d of %d clear spells cloudless" % [
			avg.call(calm), avg.call(brewing), avg.call(storm), empty, clear_spells])
	_check(calm.size() > 0 and brewing.size() > 0 and storm.size() > 0, "clear spells, storms brewing and storm cores all seen")
	_check(avg.call(calm) < 6.5, "clear days are calm (%.1f m/s)" % avg.call(calm))
	_check(avg.call(brewing) > avg.call(calm) + 6.0, "the wind builds before a storm (%.1f vs %.1f)" % [avg.call(brewing), avg.call(calm)])
	_check(avg.call(storm) > 20.0, "the storm blows hardest (%.1f)" % avg.call(storm))
	_check(empty > 0 and empty < clear_spells, "some clear spells have no clouds at all (%d of %d)" % [empty, clear_spells])


func test_drift_wraps() -> void:
	var w := WeatherSystem.new(null, 8)
	for i in 2000:
		w.update(1.0, 0.0, PLAYER, 12.0, 7)
	var d := w.field.drift
	_check(d.x >= 0.0 and d.x < CloudField.BASE_TILE and d.y >= 0.0 and d.y < CloudField.BASE_TILE, "cloud drift wraps in the noise tile (%s)" % d)
	_check(w.field.patch_offset.length() > 20000.0, "the coverage patches keep moving (unwrapped, %.0f m)" % w.field.patch_offset.length())
	_check(w.field.cloud_evolve >= 0.0 and w.field.cloud_evolve < CloudField.BASE_TILE, "the evolution offset wraps")


func test_dev_cycle() -> void:
	var w := WeatherSystem.new(null, 9)
	w.update(0.0, 0.0, PLAYER, 12.0, 7)
	w.force_state("clear")
	var seq := []
	for i in 5:
		seq.append(w.cycle_forced())
	_check(seq == ["fair", "overcast", "storm", "clear", "fair"], "Shift+F8 cycles clear -> fair -> overcast -> storm (%s)" % [seq])


## The star map (J2000) turned to 1765: Polaris 1.95 deg from the pole (0.74 in 2000), in the sky as drawn.
func test_precession() -> void:
	var polaris := WorldClock.radec_vector(37.9546, 89.2641)
	var p2000 := WorldClock.precession_matrix(0.0) * polaris
	var off2000 := 90.0 - rad_to_deg(asin(p2000.z))
	var p1765 := WorldClock.precession_matrix(WorldClock.days_j2000(1765, 237.0, 12.0)) * polaris
	var off1765 := 90.0 - rad_to_deg(asin(p1765.z))
	print("    Polaris from the celestial pole: %.3f deg in 1765, %.3f deg in 2000" % [off1765, off2000])
	_check(absf(off2000 - 0.736) < 0.01, "J2000 unchanged (%.3f)" % off2000)
	_check(off1765 > 1.9 and off1765 < 2.0, "1765: %.3f deg (Dec 88 deg 03')" % off1765)
	# Meeus example 21.b (theta Persei to 2028 Nov 13.19 TD): 41.547214, +49.348483
	var th := WorldClock.radec_vector(41.054063, 49.227750)
	var pm := WorldClock.precession_matrix(2462088.69 - 2451545.0) * th
	var ra := fposmod(rad_to_deg(atan2(pm.y, pm.x)), 360.0)
	var dec := rad_to_deg(asin(pm.z))
	_check(absf(ra - 41.547214) < 0.0005 and absf(dec - 49.348483) < 0.0005, "Meeus 21.b reproduced (%.6f, %.6f)" % [ra, dec])
	# in the sky: the date's pole at the latitude's altitude above true north, Polaris 1.95 deg from it
	var c := WorldClock.new()
	c.year = 1765
	c.set_date(237.0)
	var pole_w: Vector3 = c.celestial_basis_of_date().inverse() * Vector3(0, 0, 1)
	var star_w: Vector3 = c.celestial_basis().inverse() * polaris
	var alt := rad_to_deg(asin(pole_w.y))
	var sep := rad_to_deg(star_w.angle_to(pole_w))
	_check(absf(alt - WorldClock.LATITUDE_DEG) < 0.05, "the pole stands at the latitude (%.2f)" % alt)
	_check(absf(sep - off1765) < 0.05, "Polaris drawn %.2f deg from the pole" % sep)
	# Polaris circles the pole through the night
	var alts := []
	for hh in [18.0, 0.0, 6.0]:
		c.set_time(hh)
		var sw: Vector3 = c.celestial_basis().inverse() * polaris
		alts.append(rad_to_deg(asin(sw.y)))
	var span: float = alts.max() - alts.min()
	_check(span > 1.5 and span < 4.0, "Polaris swings %.2f deg in altitude over the night" % span)
	c.free()
