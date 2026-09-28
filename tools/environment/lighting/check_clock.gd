extends SceneTree
## WorldClock sanity check (package A sky system). Headless:
##
##   Godot --headless --path . -s tools/environment/lighting/check_clock.gd
##
## Checks the default state against the gameplay-validated static sun (azimuth 222.5, elevation
## 19.1: EnvironmentRig.sun_direction()), noon elevations and day lengths against the latitude and
## seasons.json (June 15.3 h, December 9.0 h), a known full moon (2000-01-21 04:40 UT), the
## celestial pole's altitude (= latitude) and the survival calendar mapping. Prints CLOCK CHECK
## PASSED / FAILED.

const Clock := preload("res://scripts/world/env/world_clock.gd")

var fails := 0


func _check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	var c: Node = Clock.new()
	var ref := Vector3(-0.6384, 0.3272, 0.6967).normalized()
	var d: Vector3 = c.sun_direction()
	var ang := rad_to_deg(d.angle_to(ref))
	print("CLOCK default %s hour=%.4f (%s) north_offset=%.3f sun=%s el=%.3f az=%.3f off_ref=%.4f deg" % [
			c.date_string(), c.hour, c.time_string(), Clock.north_offset_deg(), d, c.sun_elevation_deg(),
			c.sun_azimuth_deg(), ang])
	_check(ang < 0.05, "default sun within 0.05 deg of the validated static sun")
	_check(absf(c.sun_elevation_deg() - 19.1) < 0.02 and absf(c.sun_azimuth_deg() - 222.5) < 0.05, "default elevation / azimuth")
	_check(c.season() == "summer", "default season is summer")

	# Noon elevation = 90 - latitude + declination (refraction ~0.02 deg at these heights).
	for doy in [80.0, 172.0, 237.0, 355.0]:
		c.set_date(doy)
		c.set_time(12.0)
		var dec := float(Clock.sun_equatorial(Clock.days_j2000(c.year, doy, 12.0))[1])
		var expect := 90.0 - 43.0 + dec
		_check(absf(c.sun_elevation_deg() - expect) < 0.1, "noon elevation doy %d: %.2f vs %.2f" % [doy, c.sun_elevation_deg(), expect])
	c.set_date(172.0)
	var june: float = c.daylight_hours()
	c.set_date(355.0)
	var dec_day: float = c.daylight_hours()
	print("CLOCK day length June 21 %.2f h, Dec 21 %.2f h (seasons.json: June 15.3, December 9.0)" % [june, dec_day])
	_check(absf(june - 15.3) < 0.35 and absf(dec_day - 9.0) < 0.35, "day lengths match seasons.json within 0.35 h")

	# Sunrise / sunset symmetric about noon, sun up at the default hour, down at midnight.
	c.set_date(237.0)
	c.set_time(0.0)
	_check(c.sun_elevation_deg() < -20.0, "midnight sun below -20 deg (%.1f)" % c.sun_elevation_deg())

	# Known full moon: 2000-01-21 04:40 UT = local solar 23.70 h on 20 January at 74.5 W.
	c.year = 2000
	c.set_date(20.0)
	c.set_time(4.0 + 40.0 / 60.0 - 74.5 / 15.0 + 24.0)
	print("CLOCK full moon test phase=%.3f illumination=%.3f" % [c.moon_phase(), c.moon_illumination()])
	_check(absf(c.moon_phase() - 0.5) < 0.02 and c.moon_illumination() > 0.99, "full moon of 2000-01-21")
	# A new moon one half synodic month earlier (2000-01-06 18:14 UT).
	c.set_date(6.0)
	c.set_time(18.0 + 14.0 / 60.0 - 74.5 / 15.0)
	print("CLOCK new moon test phase=%.3f illumination=%.3f" % [c.moon_phase(), c.moon_illumination()])
	_check(c.moon_phase() < 0.02 or c.moon_phase() > 0.98, "new moon of 2000-01-06")
	# The moon is roughly opposite the sun at full moon.
	c.set_date(20.0)
	c.set_time(4.0 + 40.0 / 60.0 - 74.5 / 15.0 + 24.0)
	var opp := rad_to_deg((c.moon_direction() as Vector3).angle_to(-(c.sun_direction() as Vector3)))
	_check(opp < 6.0, "full moon opposite the sun (%.1f deg off)" % opp)

	# Celestial pole: altitude = latitude, toward true north.
	c.year = 1765
	c.set_date(237.0)
	var b: Basis = c.celestial_basis_of_date()
	var pole_world: Vector3 = b.inverse() * Vector3(0, 0, 1)
	var alt := rad_to_deg(asin(pole_world.y))
	var north: Vector3 = Clock.enu_to_world(Vector3(0, 1, 0))
	var az_err := rad_to_deg(Vector2(pole_world.x, pole_world.z).normalized().angle_to(Vector2(north.x, north.z)))
	print("CLOCK celestial pole altitude %.2f deg, %.2f deg from true north" % [alt, absf(az_err)])
	_check(absf(alt - 43.0) < 0.05 and absf(az_err) < 0.1, "celestial pole")
	# Precession: the star map (J2000) turned to 1765. Polaris (J2000 RA 37.9546, Dec 89.2641) sat 1.95 deg from
	# the pole of 1765 (Dec 88.05; 0.74 in 2000; IAU 1976, reproduces Meeus example 21.b), and through
	# celestial_basis() the star map puts it that far from the date's pole in the sky.
	var polaris: Vector3 = Clock.radec_vector(37.9546, 89.2641)
	var p1765: Vector3 = Clock.precession_matrix(Clock.days_j2000(1765, 1.0, 12.0)) * polaris
	var off := 90.0 - rad_to_deg(asin(p1765.z))
	var star_world: Vector3 = (c.celestial_basis() as Basis).inverse() * polaris
	var sep := rad_to_deg(star_world.angle_to(pole_world))
	print("CLOCK Polaris 1765: %.2f deg from the pole (world: %.2f deg); 2000: %.2f deg" % [off, sep, 90.0 - 89.2641])
	_check(off > 1.9 and off < 2.0 and absf(sep - off) < 0.05, "Polaris precessed to 1765")

	# Survival calendar mapping: aug_late (game day 23) -> 25 August = doy 237.
	_check(Clock.game_day_to_doy(23) == 237.0 and Clock.game_day_to_doy(0) == 5.0, "game day -> day of year")
	c.free()
	print("CLOCK CHECK %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit()
