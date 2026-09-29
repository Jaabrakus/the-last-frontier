extends SceneTree
## Sharpness (scripts/companion/sharpness.gd), headless: the rest gauge fills whenever she sleeps or rests, at any hour, and runs down, hungry or unwell duller still;
## never below the floor; slips never below mistake_min and more often when dull; a dull worker sometimes picks a lesser job.
##   Godot --headless --path . -s tests/companion/test_sharpness.gd
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _at_hour(w: SpouseCore, hr: float) -> void:
	var day := floorf(w.core.state.minutes / 1440.0) * 1440.0
	w.core.state.minutes = day + hr * 60.0


func _initialize() -> void:
	InputSetup.ensure()
	var main := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "backlog_milestones": ["M2a", "M2b", "M3"], "settings": {"rest_need": false}})
	var w := SpouseCore.create(main, AppearanceStore.default_look(), 11)
	w.core.state.needs["stomach"] = 2500.0
	w.core.state.flags["well_rested_until"] = -1.0
	var unrested := Sharpness.of(w)
	_expect(unrested < 0.6, "no well-rested meter: not at her sharpest (%.2f)" % unrested)
	# the gauge fills while she sleeps, at any hour: 8 h asleep by night -> 12 h of well rested, filling as the time passes
	_at_hour(w, 22.0)
	for i in 8:
		w.core.state.minutes += 60.0   # the clock moves first, as SpouseCore.sync does
		Sharpness.rest_tick(w, 60.0, true, false)
	var rested := Sharpness.rested_hours(w)
	_expect(is_equal_approx(rested, 12.0) and Sharpness.of(w) > 0.95, "8 h asleep fills %.1f h and she is sharp (%.2f)" % [rested, Sharpness.of(w)])
	w.core.state.minutes += 6.0 * 60.0
	var mid := Sharpness.of(w)
	w.core.state.minutes += 8.0 * 60.0
	var spent := Sharpness.of(w)
	_expect(mid > spent and spent < 0.6, "it runs down as time goes (%.2f, then %.2f with the gauge empty)" % [mid, spent])
	# no schedule: a sleep at noon fills it just the same, and a short nap counts
	w.core.state.flags["well_rested_until"] = -1.0
	_at_hour(w, 12.0)
	w.core.state.minutes += 40.0
	Sharpness.rest_tick(w, 40.0, true, false)
	var nap := Sharpness.rested_hours(w)
	_expect(nap > 0.9 and nap < 1.1, "a 40 minute nap at noon fills %.2f h" % nap)
	w.core.state.flags["well_rested_until"] = -1.0
	for i in 4:
		w.core.state.minutes += 30.0
		Sharpness.rest_tick(w, 30.0, true, false)
	var naps := Sharpness.rested_hours(w)
	w.core.state.minutes += 1.0
	Sharpness.rest_tick(w, 1.0, false, false)
	var after := Sharpness.rested_hours(w)
	_expect(is_equal_approx(naps, 3.0) and absf(after - (naps - 1.0 / 60.0)) < 0.001, "four half-hour naps fill %.1f h; being awake and busy adds nothing" % naps)
	w.core.state.flags["well_rested_until"] = -1.0
	w.core.state.minutes += 60.0
	Sharpness.rest_tick(w, 60.0, false, true)
	var sit := Sharpness.rested_hours(w)
	w.core.state.flags["well_rested_until"] = -1.0
	w.core.state.minutes += 60.0
	Sharpness.rest_tick(w, 60.0, true, false)
	var slept := Sharpness.rested_hours(w)
	w.core.state.flags["well_rested_until"] = -1.0
	w.core.state.minutes += 60.0
	Sharpness.rest_tick(w, 60.0, true, false, true, true)
	_expect(sit > 0.0 and sit < slept and Sharpness.rested_hours(w) > slept, "sitting (%.2f h) < sleeping (%.2f h) < sleeping in a bed by a fire (%.2f h)" % [sit, slept, Sharpness.rested_hours(w)])
	w.core.state.flags["well_rested_until"] = -1.0
	for i in 40:
		w.core.state.minutes += 60.0
		Sharpness.rest_tick(w, 60.0, true, false, true)
	_expect(is_equal_approx(Sharpness.rested_hours(w), Sharpness.num("cap_h", 12.0)), "the gauge holds at %.0f h" % Sharpness.rested_hours(w))
	w.core.state.flags["well_rested_until"] = w.core.state.minutes + 600.0
	var noon := Sharpness.of(w)
	w.core.state.needs["stomach"] = 0.0
	var hungry := Sharpness.of(w)
	_expect(hungry < noon, "rested but hungry is duller (%.2f < %.2f)" % [hungry, noon])
	w.core.state.needs["health"] = 30.0
	var sick := Sharpness.of(w)
	_expect(sick < hungry and sick >= Sharpness.num("floor", 0.2), "unwell duller still, never below the floor (%.2f)" % sick)
	# her own sleeping hours: by default the night, but a night worker sleeps through the day
	_at_hour(w, 23.0)
	var night_asleep := not w.awake()
	w.sleep_from = 8.0
	w.sleep_h = 8.0
	_at_hour(w, 12.0)
	var day_asleep := not w.awake()
	_at_hour(w, 23.0)
	_expect(night_asleep and day_asleep and w.awake(), "she sleeps at night by default; with hours of her own (8 to 16) she sleeps at noon and works at 23:00")
	var back := SpouseCore.from_dict(w.to_dict(), main)
	_expect(is_equal_approx(back.sleep_from, 8.0) and is_equal_approx(back.sleep_h, 8.0), "her sleeping hours are saved")
	var mn := Sharpness.num("mistake_min", 0.05)
	_expect(is_equal_approx(Sharpness.slip(1.0, 0.8), mn) and Sharpness.slip(0.2, 0.8) > 0.5, "slips: %.2f when sharp (no one is perfect), %.2f when dull" % [Sharpness.slip(1.0, 0.8), Sharpness.slip(0.2, 0.8)])
	# the path wanders more when dull (NavMover._wander on a straight-ish path)
	var nm := NavMover.new(null, 0.3)
	nm.world = null
	var p := PackedVector3Array([Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(10, 0, 0), Vector3(15, 0, 0)])
	_expect(nm._wander(p) == p, "no world: the path is left as it is")
	print("SHARPNESS TEST %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(1 if fails else 0)
