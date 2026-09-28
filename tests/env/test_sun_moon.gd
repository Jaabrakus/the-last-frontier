extends SceneTree
## Headless tests for the sun and moon discs (sun and moon push, 2026-09-26): the moon's phase and the tilt of its
## bright limb as SkyBodies mirrors the sky shader's moon_disc(), the moon's orientation, distance and parallax, and
## the colours and sizes SkyBodies uploads.
##
##   Godot --headless --path . -s tests/env/test_sun_moon.gd [-- --only <name>]
##
## The GPU side (the rendered disc against this mirror: lit share and bright-limb direction on the screen) needs a
## window: tools/environment/sky/sun_moon_shots.gd what=phases (MOONCHECK lines). Failures are listed; exit code 1.

const SkyBodies := preload("res://scripts/world/env/sky_bodies.gd")
const SkyModel := preload("res://scripts/world/env/sky_model.gd")

var failures := PackedStringArray()
var passes := 0
var current := ""


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and str(args[0]) == "--only":
		only = str(args[1])
	for name in ["test_moon_position_reference", "test_lit_fraction_vs_phase_angle", "test_bright_limb_toward_sun",
			"test_orientation", "test_distance_and_size", "test_parallax", "test_colours", "test_lunation_sequence"]:
		if only != "" and not name.contains(only):
			continue
		current = name
		var n0 := failures.size()
		call(name)
		print("  %s %s" % ["ok  " if failures.size() == n0 else "FAIL", name])
	print("")
	print("sun and moon: %d checks passed, %d failed (%d ms)" % [passes, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	print("SUN MOON TEST %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures.append("%s: %s" % [current, what])


func _clock(doy: float, hour: float, y := 1765) -> WorldClock:
	var c := WorldClock.new()
	c.year = y
	c.set_date(doy)
	c.set_time(hour)
	return c


## Moments across one lunation (August - September 1765), every 7 hours.
func _moments() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var t := 225.0
	while t < 255.0:
		out.append(Vector2(floorf(t), fposmod(t, 1.0) * 24.0))
		t += 7.0 / 24.0
	return out


## The moon's place against references outside the clock: Meeus's worked example 47.a (1992 April 12, 0h TD: right
## ascension 134.688 deg, declination 13.768 deg, apparent; distance 368,409.7 km) and three moments of 1765 from the
## main series of Meeus ch. 47 (tables 47.A / 47.B, 60 + 30 terms; computed offline by the review of this push). The
## drawn disc is 1.2 deg wide: its place must be good to a small part of it.
func test_moon_position_reference() -> void:
	# [days after J2000, right ascension, declination, distance km]
	var refs := [[-2820.5, 134.688, 13.768, 368409.7], [-85594.418056, 271.711, -28.283, 367052.0],
			[-85820.543056, 168.125, 5.195, 383457.0], [-85681.043056, 201.444, -12.655, 367474.0]]
	var worst := 0.0
	var worst_km := 0.0
	for r: Array in refs:
		var m: Array = WorldClock.moon_equatorial(float(r[0]))
		var a := deg_to_rad(float(m[0]))
		var d := deg_to_rad(float(m[1]))
		var a0 := deg_to_rad(float(r[1]))
		var d0 := deg_to_rad(float(r[2]))
		var sep := rad_to_deg(Vector3(cos(d) * cos(a), cos(d) * sin(a), sin(d)).angle_to(
				Vector3(cos(d0) * cos(a0), cos(d0) * sin(a0), sin(d0))))
		worst = maxf(worst, sep)
		worst_km = maxf(worst_km, absf(WorldClock.moon_distance_km_at(float(r[0])) - float(r[3])))
	print("    moon against Meeus 47 (1992 example + 3 moments of 1765): worst %.3f deg, distance %.0f km" % [worst, worst_km])
	_check(worst < 0.15, "moon position off the reference by %.3f deg" % worst)
	_check(worst_km < 300.0, "moon distance off the reference by %.0f km" % worst_km)


## The lit share of the drawn disc is the illuminated fraction of a sphere lit from the sun: (1 + cos i) / 2 with the
## phase angle i between the moon -> sun and moon -> observer directions, i.e. (1 - sun . moon) / 2; and it follows the
## clock's ecliptic phase (moon_illumination) within the moon's ecliptic latitude and parallax.
func test_lit_fraction_vs_phase_angle() -> void:
	var worst := 0.0
	var worst_clock := 0.0
	var n := 0
	for m in _moments():
		var c := _clock(m.x, m.y)
		var sd := c.sun_direction()
		var md := c.moon_direction()
		var st: Dictionary = SkyBodies.moon_lit_stats(sd, md, SkyBodies.moon_north(c), 64)
		var want := 0.5 * (1.0 - sd.dot(md))
		worst = maxf(worst, absf(float(st.lit) - want))
		worst_clock = maxf(worst_clock, absf(float(st.lit) - c.moon_illumination()))
		n += 1
		c.free()
	print("    %d moments: lit share vs (1 - cos elongation) / 2: max err %.4f; vs WorldClock.moon_illumination: %.4f" % [
			n, worst, worst_clock])
	_check(worst < 0.02, "lit share off the phase angle by %.4f" % worst)
	_check(worst_clock < 0.05, "lit share off moon_illumination() by %.4f" % worst_clock)


## The bright limb points toward the sun on the sky. Checked against the astronomical position angle of the bright
## limb (Meeus 48.5, from the equatorial coordinates of the date, measured from celestial north through east), not
## against the mirror's own frame: the lit part's centroid must lie along it.
func test_bright_limb_toward_sun() -> void:
	var worst := 0.0
	var worst_at := ""
	var n := 0
	for m in _moments():
		var c := _clock(m.x, m.y)
		var sd := c.sun_direction()
		var md := c.moon_direction()
		var k := 0.5 * (1.0 - sd.dot(md))
		if k < 0.04 or k > 0.96:
			c.free()
			continue
		var north := SkyBodies.moon_north(c)
		var frame := SkyBodies.moon_frame(md, north)
		var st: Dictionary = SkyBodies.moon_lit_stats(sd, md, north, 64)
		var cen: Vector2 = st.centroid
		var cen_w: Vector3 = (frame[0] * cen.x + frame[1] * cen.y).normalized()
		# Meeus 48.5: position angle of the bright limb, from the sun's and moon's RA / Dec of the date
		var nd := WorldClock.days_j2000(c.year, c.day_of_year, c.hour)
		var s: Array = WorldClock.sun_equatorial(nd)
		var mo: Array = WorldClock.moon_equatorial(nd)
		var a0 := deg_to_rad(float(s[0]))
		var d0 := deg_to_rad(float(s[1]))
		var a := deg_to_rad(float(mo[0]))
		var d := deg_to_rad(float(mo[1]))
		var chi := atan2(cos(d0) * sin(a0 - a), sin(d0) * cos(d) - cos(d0) * sin(d) * cos(a0 - a))
		# celestial north and east on the sky at the moon (east = north x toward, seen from inside the sphere)
		var ncp: Vector3 = (c.celestial_basis_of_date().inverse() * Vector3(0, 0, 1)).normalized()
		var nn := (ncp - md * ncp.dot(md)).normalized()
		var ee := nn.cross(md)
		var want := (nn * cos(chi) + ee * sin(chi)).normalized()
		var err := rad_to_deg(cen_w.angle_to(want))
		if err > worst:
			worst = err
			worst_at = "%s %s (lit %.2f)" % [c.date_string(), c.time_string(), k]
		n += 1
		c.free()
	print("    %d moments: bright limb vs Meeus position angle: max err %.2f deg at %s" % [n, worst, worst_at])
	_check(n > 50, "enough moments (%d)" % n)
	_check(worst < 4.0, "bright limb off the sun's position angle by %.2f deg at %s" % [worst, worst_at])


## The moon's north toward the ecliptic pole (23.4 deg from the celestial pole); on the meridian its east (the Mare
## Crisium side of the map) lies toward the western sky, as seen from the northern hemisphere.
func test_orientation() -> void:
	var c := _clock(240.0, 0.0)
	var ncp: Vector3 = (c.celestial_basis_of_date().inverse() * Vector3(0, 0, 1)).normalized()
	var mn := SkyBodies.moon_north(c)
	var tilt := rad_to_deg(mn.angle_to(ncp))
	print("    moon's north %.2f deg from the celestial pole (ecliptic obliquity 23.44)" % tilt)
	_check(absf(tilt - 23.44) < 0.6, "moon_north %.2f deg from the pole" % tilt)
	# the moon on the meridian (due south) at several dates
	var west: Vector3 = WorldClock.enu_to_world(Vector3(-1, 0, 0))
	var south: Vector3 = WorldClock.enu_to_world(Vector3(0, -1, 0))
	var seen := 0
	for doy in [230.0, 236.0, 242.0, 248.0]:
		var best := 1e9
		var best_h := 0.0
		for i in 480:
			c.set_date(doy)
			c.set_time(i * 0.05)
			var md := c.moon_direction()
			var off := absf(Vector2(md.x, md.z).normalized().angle_to(Vector2(south.x, south.z)))
			if md.y > 0.1 and off < best:
				best = off
				best_h = i * 0.05
		if best > 0.05:
			continue
		c.set_date(doy)
		c.set_time(best_h)
		var md := c.moon_direction()
		var frame := SkyBodies.moon_frame(md, SkyBodies.moon_north(c))
		var ew := (frame[0] as Vector3).dot(west)
		print("    %s %s moon on the meridian (alt %.0f): its east toward the sky's west %.3f" % [c.date_string(),
				c.time_string(), rad_to_deg(asin(md.y)), ew])
		_check(ew > 0.85, "selenographic east toward the west on the meridian (%.3f)" % ew)
		seen += 1
	_check(seen >= 3, "moon found on the meridian (%d)" % seen)
	c.free()


## Distance 356,500 .. 406,700 km over a year; the drawn disc = the real angular size x MOON_DISC_SCALE; the sun's
## = 0.533 x SUN_DISC_SCALE.
func test_distance_and_size() -> void:
	var lo := 1e9
	var hi := 0.0
	var c := _clock(1.0, 0.0)
	var t := 0.0
	while t < 365.0:
		c.set_date(1.0 + floorf(t))
		c.set_time(fposmod(t, 1.0) * 24.0)
		var dist := c.moon_distance_km()
		lo = minf(lo, dist)
		hi = maxf(hi, dist)
		t += 0.25
	print("    moon distance %.0f .. %.0f km in 1765" % [lo, hi])
	_check(lo > 355000.0 and lo < 360000.0, "perigee %.0f km" % lo)
	_check(hi > 404000.0 and hi < 407500.0, "apogee %.0f km" % hi)
	var v := SkyBodies.apply(null, c, 1.7)
	var real := 2.0 * rad_to_deg(asin(SkyBodies.MOON_RADIUS_KM / c.moon_distance_km()))
	_check(real > 0.48 and real < 0.57, "moon's real diameter %.3f deg" % real)
	_check(absf(float(v.moon_size_deg) - real * SkyBodies.MOON_DISC_SCALE) < 1e-4, "moon drawn at the scale")
	var sun_size := SkyBodies.SUN_SIZE_DEG * SkyBodies.SUN_DISC_SCALE
	_check(SkyBodies.SUN_DISC_SCALE >= 1.5 and SkyBodies.SUN_DISC_SCALE <= 2.5, "sun scale in 1.5 .. 2.5")
	_check(SkyBodies.MOON_DISC_SCALE >= 1.5 and SkyBodies.MOON_DISC_SCALE <= 2.5, "moon scale in 1.5 .. 2.5")
	print("    drawn: sun %.3f deg (x%.1f), moon %.3f deg (x%.1f); at 70 deg fov / 900 px: %.1f and %.1f px" % [sun_size,
			SkyBodies.SUN_DISC_SCALE, float(v.moon_size_deg), SkyBodies.MOON_DISC_SCALE, sun_size / 70.0 * 900.0,
			float(v.moon_size_deg) / 70.0 * 900.0])
	c.free()


## Topocentric: the moon seen from the ground stands lower than from the Earth's centre by its parallax x cos(alt).
func test_parallax() -> void:
	var c := _clock(240.0, 22.0)
	var worst := 0.0
	var n := 0
	for i in 48:
		c.set_time(i * 0.5)
		var nd := WorldClock.days_j2000(c.year, c.day_of_year, c.hour)
		var s: Array = WorldClock.sun_equatorial(nd)
		var m: Array = WorldClock.moon_equatorial(nd)
		var ha := 15.0 * (c.hour - 12.0) + float(s[0]) - float(m[0])
		var geo := WorldClock.local_enu(ha, m[1], c.latitude_deg)
		var topo := WorldClock.local_enu(ha, m[1], c.latitude_deg, rad_to_deg(asin(WorldClock.EARTH_RADIUS_KM / c.moon_distance_km())))
		var el_g := rad_to_deg(asin(geo.z))
		if el_g < 10.0:
			continue
		var el_t := rad_to_deg(asin(topo.z))
		var hp := rad_to_deg(asin(WorldClock.EARTH_RADIUS_KM / c.moon_distance_km()))
		worst = maxf(worst, absf((el_g - el_t) - hp * cos(deg_to_rad(el_g))))
		n += 1
	print("    %d moments: parallax lowering vs HP cos(alt): max err %.3f deg" % [n, worst])
	_check(n > 5 and worst < 0.05, "parallax (%.3f deg)" % worst)
	c.free()


## The sun: white high up, reddened and dimmer near the horizon (disc and glow); the moon: neutral high up, orange
## and dim near the horizon, brighter by day than by night (the eye), a halo only at night, glare with its phase.
func test_colours() -> void:
	var c := _clock(237.0, 12.0)
	var hi := _at_sun_el(c, 40.0)
	var lo := _at_sun_el(c, 2.0)
	var dh: Vector3 = hi.sun_disc_color
	var dl: Vector3 = lo.sun_disc_color
	print("    sun disc at 40 deg %s, at 2 deg %s" % [dh, dl])
	_check(dl.x / maxf(dl.z, 1e-6) > 3.0 * dh.x / dh.z, "low sun redder (r/b %.1f vs %.1f)" % [dl.x / maxf(dl.z, 1e-6), dh.x / dh.z])
	_check(SkyModel.luma(dl) < 0.1 * SkyModel.luma(dh), "low sun dimmer")
	_check(SkyModel.luma(dh) > 20.0, "high sun HDR bright (blooms): %.1f" % SkyModel.luma(dh))
	var gh: Vector3 = hi.sun_glow_color
	var gl: Vector3 = lo.sun_glow_color
	_check(gl.x / maxf(gl.z, 1e-6) > 3.0 * gh.x / gh.z, "low sun's glow redder")
	_check(float(hi.glare_knee) > 0.0 and float(hi.glare_knee) < 1.0, "glare knee under the tonemapper's white")
	# the moon high and low, both at night (the nights around the full moon of 30 August)
	var best_hi := {}
	var best_lo := {}
	var alt_hi := -90.0
	var alt_lo_err := 90.0
	for i in 96 * 4:
		c.set_date(239.0 + floorf(i / 96.0))
		c.set_time(fposmod(i * 0.25, 24.0))
		if c.sun_elevation_deg() > -12.0:
			continue
		var md := c.moon_direction()
		var alt := rad_to_deg(asin(md.y))
		var v := SkyBodies.apply(null, c, 3.0)
		if alt > alt_hi:
			alt_hi = alt
			best_hi = v
		if absf(alt - 3.0) < alt_lo_err:
			alt_lo_err = absf(alt - 3.0)
			best_lo = v
	var mh: Vector3 = best_hi.moon_color
	var ml: Vector3 = best_lo.moon_color
	print("    moon colour at %.0f deg %s, near 3 deg %s" % [alt_hi, mh, ml])
	_check(ml.x / ml.z > 2.0 * mh.x / mh.z, "low moon orange")
	_check(SkyModel.luma(ml) < 0.6 * SkyModel.luma(mh), "low moon dimmer")
	_check(mh.x / mh.z < 1.6 * SkyBodies.MOON_TINT.x / SkyBodies.MOON_TINT.z, "high moon near its own grey")
	# day and night levels (the eye), the halo only at night, the glare with the phase
	_check(is_equal_approx(SkyBodies.moon_level(-20.0), SkyBodies.MOON_NIGHT), "night level")
	_check(is_equal_approx(SkyBodies.moon_level(30.0), SkyBodies.MOON_DAY), "day level")
	_check(SkyBodies.MOON_DAY > 1.5 * SkyBodies.MOON_NIGHT, "brighter by day (the pale day moon reads against the sky)")
	var prev := 0.0
	var mono := true
	for e in range(-12, 8):
		var lv := SkyBodies.moon_level(float(e))
		mono = mono and lv >= prev
		prev = lv
	_check(mono, "the level rises through twilight")
	var day := SkyBodies.apply(null, _set_sun(c, 30.0), 1.7)
	_check(SkyModel.luma(day.moon_halo) == 0.0, "no halo by day")
	c.set_date(240.0)
	c.set_time(22.0)
	var night := SkyBodies.apply(null, c, 5.0)
	var k := c.moon_illumination()
	_check(SkyModel.luma(night.moon_halo) > 0.0 and absf(float(night.moon_glare) - SkyBodies.STAR_GLARE * k) < 0.05,
			"halo and glare at night (lit %.2f, glare %.2f)" % [k, float(night.moon_glare)])
	c.free()


## Over one lunation at 22:00 each night: the phase waxes then wanes, the glare follows it.
func test_lunation_sequence() -> void:
	var c := _clock(230.0, 22.0)
	var ks: Array[float] = []
	for i in 30:
		c.set_date(230.0 + i)
		c.set_time(22.0)
		var st: Dictionary = SkyBodies.moon_lit_stats(c.sun_direction(), c.moon_direction(), SkyBodies.moon_north(c), 48)
		ks.append(float(st.lit))
	var imax := ks.find(ks.max())
	var imin := ks.find(ks.min())
	var s := ""
	for i in range(0, 30, 3):
		s += " %.2f" % ks[i]
	print("    lit share at 22:00 from 18 August 1765, every 3 days:%s (full on day +%d, new on day +%d)" % [s, imax, imin])
	_check(ks.max() > 0.97 and ks.min() < 0.05, "a full and a new moon in 30 days")
	_check(absf(absf(imax - imin) - 15) <= 2, "full and new ~15 days apart (%d)" % absi(imax - imin))
	c.free()


## The clock at the hour of `c`'s date when the sun stands at el (afternoon): SkyBodies.apply's values.
func _at_sun_el(c: WorldClock, el: float) -> Dictionary:
	var lo := 12.0
	var hi := 21.0
	for i in 40:
		var mid := 0.5 * (lo + hi)
		c.set_time(mid)
		if c.sun_elevation_deg() > el:
			lo = mid
		else:
			hi = mid
	return SkyBodies.apply(null, c, 1.7)


## A clock at the same date with the sun at `el` (morning side), for the moon's day / night levels.
func _set_sun(c: WorldClock, el: float) -> WorldClock:
	var lo := 0.0
	var hi := 12.0
	for i in 40:
		var mid := 0.5 * (lo + hi)
		c.set_time(mid)
		if c.sun_elevation_deg() > el:
			hi = mid
		else:
			lo = mid
	return c
