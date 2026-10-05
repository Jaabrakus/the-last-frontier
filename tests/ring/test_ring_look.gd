extends SceneTree
## Look task C's entry points on the Tidebreak ring (scenes/ring.tscn), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_look.gd
##   dressing  RingDressing.build(level, preset) gives the ring's one dressing (a second call the same node), found by
##             find_in; it adds no collider (drawn only: the match never meets it); set_mood / set_sides / set_score /
##             set_cheer are safe with nothing drawn
##   look      RingLook.apply(level, name) for each mood keeps one RingLook under the level with that preset; an unknown
##             name falls back to noon
##   clock     the golden hour's sun search lands in the afternoon; the night search finds a sky with the sun well down
##             and the moon up
## The last line: "RING LOOK TEST PASSED" or "RING LOOK TEST FAILED".

var checks := 0
var fails: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RING LOOK TEST FAILED (watchdog)")
		quit(2))
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 10:
		await process_frame
	var lvl := current_scene as RingLevel
	_expect(lvl != null and lvl.ring != null, "the ring's level loads")
	if lvl == null:
		_end()
		return
	var shapes_before := lvl.ring.find_children("*", "CollisionShape3D", true, false).size()
	var d := RingDressing.build(lvl, "night")
	_expect(d != null, "RingDressing.build gives a dressing")
	_expect(RingDressing.build(lvl, "noon") == d, "a second build gives the same dressing")
	_expect(RingDressing.find_in(lvl) == d and RingDressing.find_in(lvl.ring) == d, "find_in finds it from the level and the ring")
	_expect(d.mood == "noon", "build sets the mood (%s)" % d.mood)
	_expect(lvl.ring.find_children("*", "CollisionShape3D", true, false).size() == shapes_before, "the dressing adds no collider")
	d.set_sides("earth", "air")
	d.set_score(3, 12)
	d.set_cheer(1.0)
	d.set_mood("nonsense")
	_expect(d.mood == "noon" and d.side_elements == ["earth", "air"], "the API is safe with nothing drawn")
	for m: String in ["noon", "golden", "night"]:
		var look := RingLook.apply(lvl, m)
		_expect(look != null and look.preset == m and d.mood == m, "RingLook %s (the dressing follows)" % m)
	_expect(lvl.find_children("RingLook", "", false, false).size() == 1, "one RingLook under the level")
	_expect(RingLook.apply(lvl, "dusk?").preset == "noon", "an unknown mood is noon")
	var gh := RingLook.hour_for_elevation(13.0)
	_expect(gh > 15.0 and gh < 20.0, "the golden hour is late afternoon (%.2f)" % gh)
	var nt := RingLook.night_time()
	var c := WorldClock.new()
	c.set_date(nt.x)
	c.set_time(nt.y)
	var moon_el := rad_to_deg(asin(clampf(c.moon_direction().y, -1.0, 1.0)))
	_expect(c.sun_elevation_deg() < -16.0 and moon_el > 10.0,
			"the night: sun %.1f deg, moon %.1f deg up, %.0f %% lit (day %.0f, %.2f h)" % [c.sun_elevation_deg(), moon_el,
			c.moon_illumination() * 100.0, nt.x, nt.y])
	c.free()
	_end()


func _end() -> void:
	print("%d checks, %d failed" % [checks, fails.size()])
	print("RING LOOK TEST " + ("PASSED" if fails.is_empty() else "FAILED"))
	quit(0 if fails.is_empty() else 1)
