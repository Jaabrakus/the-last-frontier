extends SceneTree
## Blood drops age (user 2026-09-28: "lets apply this drop age"; WildlifeSpawner.DROP_FRESH_S .. DROP_GONE_S), on the
## real level with its wildlife, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_drop_aging.gd -- wildlife=on
##
##   curve     fresh as laid for DROP_FRESH_S, then darker, dried by DROP_DARK_S, fading from DROP_FADE_S
##   live      a drop laid on the ground darkens as it ages and is gone at DROP_GONE_S
##   clock     the game's clock ages them too (a night slept through dries a trail)
##   budget    a slaughter's worth of new blood does not wipe out an older trail: the longest trail loses its oldest
##   melee     the melee's blood on the ground (BloodFx) ages with the rest
## Ends with "DROP AGING TEST PASSED (<n> checks)" or "DROP AGING TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var w: WildlifeSpawner


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	w = current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	_expect(w != null and WildlifeSpawner.find(self) == w, "the level has its wildlife, found by WildlifeSpawner.find")
	if w == null:
		_end()
		return
	await _secs(1.0)
	_curve()
	await _live()
	await _clock()
	await _budget()
	await _melee()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("DROP AGING TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("DROP AGING TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _curve() -> void:
	var fresh := WildlifeSpawner.drop_modulate("red", 0.0)
	var still := WildlifeSpawner.drop_modulate("red", WildlifeSpawner.DROP_FRESH_S - 5.0)
	var dark := WildlifeSpawner.drop_modulate("red", WildlifeSpawner.DROP_DARK_S)
	var fading := WildlifeSpawner.drop_modulate("red", (WildlifeSpawner.DROP_FADE_S + WildlifeSpawner.DROP_GONE_S) * 0.5)
	_expect(fresh.is_equal_approx(Color(1, 1, 1, 0.95)) and still.is_equal_approx(fresh), "curve: fresh as laid for its first minutes")
	_expect(dark.r < 0.6 and is_equal_approx(dark.a, 0.95), "curve: darker and drier by DROP_DARK_S (red x%.2f)" % dark.r)
	_expect(fading.a > 0.3 and fading.a < 0.65, "curve: fading halfway to gone (alpha %.2f)" % fading.a)
	var gut := WildlifeSpawner.drop_modulate("gut", WildlifeSpawner.DROP_DARK_S)
	_expect(gut.g <= 1.0 and gut.r <= 1.0, "curve: the gut's dries darker, its flecks not greener (x%.2f, x%.2f)" % [gut.r, gut.g])


func _drop_at(x: float, z: float, look := "red", who: WildAnimal = null) -> Decal:
	w.blood_drop(Vector3(x, 0.0, z), 1.0, who, look)
	return w._drops.back()


func _live() -> void:
	var d := _drop_at(90.0, 90.0)
	await _secs(2.5)
	_expect(is_instance_valid(d) and d.modulate.is_equal_approx(Color(1, 1, 1, 0.95)), "live: a new drop is fresh")
	d.set_meta(&"born_s", w.now - 1000.0)
	await _secs(2.5)
	_expect(is_instance_valid(d) and d.modulate.r < 0.6, "live: 1000 s on it has darkened (x%.2f)" % (d.modulate.r if is_instance_valid(d) else -1.0))
	d.set_meta(&"born_s", w.now - WildlifeSpawner.DROP_GONE_S - 1.0)
	await _secs(2.5)
	_expect(not is_instance_valid(d) or d.is_queued_for_deletion(), "live: a game day old, it is gone")


func _clock() -> void:
	var rig := w.environment_rig
	if rig == null:
		_expect(false, "clock: the level has its environment")
		return
	var made: DayNight = null
	if rig.clock_driver == null or rig.clock_driver.clock == null:
		# (headless the level makes no day and night: a bare clock of its own, not running, for the spawner to read)
		made = DayNight.new()
		made.clock = WorldClock.new()
		made.add_child(made.clock)
		rig.clock_driver = made
	var d := _drop_at(92.0, 90.0)
	await _secs(2.5)
	rig.clock_driver.clock.advance_hours(8.0)
	await _secs(2.5)
	var age := w.drop_age(d) if is_instance_valid(d) else -1.0
	_expect(is_instance_valid(d) and age > 1000.0 and d.modulate.r < 0.6,
			"clock: a night slept through (8 game hours) dries it (%.0f s old, x%.2f)" % [age, d.modulate.r if is_instance_valid(d) else -1.0])
	rig.clock_driver.clock.advance_hours(20.0)
	await _secs(2.5)
	_expect(not is_instance_valid(d) or d.is_queued_for_deletion(), "clock: past a game day, it is gone")
	if made:
		rig.clock_driver = null
		made.free()


func _budget() -> void:
	var deer: Array = w.animals().filter(func(a: WildAnimal) -> bool: return a.species in ["deer", "stag"] and not a.is_dead())
	if deer.size() < 2:
		_expect(false, "budget: two deer")
		return
	var a: WildAnimal = deer[0]
	var b: WildAnimal = deer[1]
	var trail_a: Array[Decal] = []
	for i in 30:
		trail_a.append(_drop_at(60.0 + i * 1.3, 60.0, "red", a))
	for i in WildlifeSpawner.MAX_DROPS + 60:
		_drop_at(-60.0 - float(i % 40), -60.0 - float(i / 40), "red", b)
	await process_frame
	var kept := trail_a.filter(func(d: Decal) -> bool: return is_instance_valid(d) and not d.is_queued_for_deletion()).size()
	var live := w._drops.filter(func(d: Decal) -> bool: return is_instance_valid(d)).size()
	_expect(kept == 30 and live <= WildlifeSpawner.MAX_DROPS,
			"budget: %d new drops of one trail, the older trail keeps all its %d (on the ground %d of %d at most)" %
			[WildlifeSpawner.MAX_DROPS + 60, kept, live, WildlifeSpawner.MAX_DROPS])
	for d in w._drops:
		if is_instance_valid(d):
			d.queue_free()
	w._drops.clear()


func _melee() -> void:
	var at := Vector3(94.0, FrontierTerrain.height_at(94.0, 94.0) + 1.0, 94.0)
	BloodFx.hit(current_scene, at, Vector3.RIGHT, Vector3.LEFT, 1.0, null)
	await _secs(2.0)
	var mine := w._drops.filter(func(d: Decal) -> bool: return is_instance_valid(d) and int(d.get_meta(&"trail", 0)) == -2)
	_expect(mine.size() > 0 and (mine[0] as Decal).has_meta(&"born_s"),
			"melee: its blood on the ground is kept with the rest, to age (%d drops)" % mine.size())
