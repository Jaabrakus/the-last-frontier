extends SceneTree
## The survival bridge in the level (scripts/survival_game; the core in scripts/survival), headless:
##
##   Godot --headless --path . -s tests/survival_game/test_survival_bridge.gd -- survival=on survival_seed=7
##
## Headless there is no sky to tell the core its weather: the test tells it clear (SurvivalWeather.set_external), rain
## only where it tests rain. The bridge works in _process: after a change the test waits render frames (settle()).
##
##   start     the level has the bridge; Early September 1765, 08:00; the kit's jerky and cornmeal are in the pack and
##             no longer in the core; the clothes stay on in the core
##   clock     real time drives the core (10 game minutes in 24 real seconds by day); the sky clock follows it (the
##             game day as its date, the hour smooth between the core's steps); a dev jump of the sky clock moves the
##             core on
##   hunger    the stomach empties with the hours, the stage worsens and a notice says so; eating a pack unit (jerky,
##             raw venison) fills it and takes one from the pack; cornmeal wants cooking, acorns leaching, a full
##             stomach refuses; V eats the best food (safe before raw); the pack screen eats on a right-click
##   body      the activity follows the player (rest, sprint); tiredness never builds (sleep is a boost, not a need);
##             cold slows the player and stops the sprint
##   health    one health: the core's drain comes off the player, a bite counts for the core; hunger never drains health
##             or kills (user 2026-09-27: no starving to death), the cold still can; a respawn brings the core back
##   sleep     holding Z sits the player down and sleeps (the core's rest.sleep, until after sunrise at night) with the
##             hours passing fast, then the player gets up WELL RESTED (hours by the sleep's length and quality):
##             healing 3 x, skills 1.25 x, a poultice stronger; it wears off; a wolf near wakes them; moving wakes them
##   weather   the sky's weather is the core's (storm, rain, overcast, clear); told, the core stops rolling its own, and
##             the rain on screen is what wets the player
##   save      save_state / load_state bring the core back as it was

var checks := 0
var fails: Array[String] = []
var report := {}
var b: SurvivalBridge
var player: FrontierPlayer


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func secs(t: float) -> void:
	await create_timer(t).timeout


## Render and physics frames: the bridge updates the player in _process.
func settle(n := 3) -> void:
	for i in n:
		await process_frame
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	check(b != null and player != null, "the level has the survival bridge (survival=on)")
	if b == null:
		_end()
		return
	player.ignore_mouse_capture = true
	SurvivalWeather.set_external(b.core, "clear", 2.0, 250.0)
	_test_start()
	await _test_clock()
	await _test_hunger()
	await _test_body()
	await _test_health()
	await _test_sleep()
	_test_weather()
	_test_save()
	_end()


func _end() -> void:
	print("REPORT ", JSON.stringify(report))
	if fails.is_empty():
		print("SURVIVAL BRIDGE TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("SURVIVAL BRIDGE TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _pack(kind: String) -> int:
	return InventoryState.from_player(player).pack_count(kind)


func _give(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	inv.add(kind, n)
	player.inventory_pack = inv.pack.duplicate(true)


func _stomach() -> float:
	return float(b.core.state.needs.stomach)


# --- Start -------------------------------------------------------------------------------------------------

func _test_start() -> void:
	var c := b.core
	check(SurvivalClock.date_string(c) == "Early September 1765", "the game starts in Early September 1765 (%s)" % SurvivalClock.date_string(c))
	check(absf(SurvivalClock.hour(c) - 8.0) < 0.2, "at eight in the morning (%s)" % SurvivalClock.time_string(c))
	check(_pack("jerky") == 6 and _pack("cornmeal") == 8, "the kit's food is in the pack (jerky %d, cornmeal %d)" % [_pack("jerky"), _pack("cornmeal")])
	check(SurvivalInventory.count(c, "item.food.jerky") == 0.0 and SurvivalInventory.count(c, "item.food.cornmeal") == 0.0, "and no longer in the core")
	check(SurvivalInventory.worn_classes(c).size() > 0, "the kit's clothes are worn (the core keeps them: warmth)")
	var st := c.need_stages()
	check(st["need.food"] == "fed" and st["need.warmth"] == "comfortable" and st["need.rest"] == "rested", "fed, comfortable and rested (%s)" % st)
	check(absf(b.pack_meals() - 6.0 * 280.0 / 800.0) < 0.01, "the pack holds %.1f meals (the jerky; cornmeal wants cooking)" % b.pack_meals())


# --- Clock -------------------------------------------------------------------------------------------------

func _test_clock() -> void:
	var c := b.core
	var m0 := c.state.minutes
	c.update(24.0)
	check(absf(c.state.minutes - m0 - 10.0) < 0.01, "24 real seconds by day are 10 game minutes (%.2f)" % (c.state.minutes - m0))
	# the sky clock (headless has no DayNight: a WorldClock of the test's, given to the bridge)
	var wc := WorldClock.new()
	wc.running = true
	root.add_child(wc)
	b._clock = wc
	b._sky_day = -1
	await process_frame
	await process_frame
	check(not wc.running, "the sky clock no longer runs on its own")
	var t := b.sky_time()
	check(absf(wc.day_of_year - WorldClock.game_day_to_doy(int(t.game_day))) < 0.01, "the sky's date is the core's game day (%.0f)" % wc.day_of_year)
	check(absf(wc.hour - float(t.hour)) < 0.01 and absf(float(t.hour) - SurvivalClock.hour(c)) < 10.0 / 60.0 + 0.01, "the sky's hour is the core's (%.3f / %.3f)" % [wc.hour, SurvivalClock.hour(c)])
	c.state.world["clock_acc"] = 5.0
	await process_frame
	check(absf(wc.hour - (SurvivalClock.hour(c) + 5.0 / 60.0)) < 0.02, "between the core's steps the sky moves on smoothly")
	var before := c.state.minutes
	wc.advance_hours(1.0)
	await process_frame
	await process_frame
	check(absf(c.state.minutes - before - 60.0) < 11.0, "the dev key's hour on the sky moves the core on (%.0f min)" % (c.state.minutes - before))
	# a day's turn: the sky's date follows the game day
	c.advance(24.0 * 60.0)
	await process_frame
	await process_frame
	check(absf(wc.day_of_year - WorldClock.game_day_to_doy(SurvivalClock.day_of_year(c))) < 0.01, "a day on, the sky's date follows (%s: %.0f)" % [SurvivalClock.date_string(c), wc.day_of_year])
	b._clock = null
	wc.queue_free()


# --- Hunger ------------------------------------------------------------------------------------------------

func _test_hunger() -> void:
	var c := b.core
	var notes := []
	b.needs_changed.connect(func() -> void: notes.append(c.need_stages()["need.food"]))
	c.state.needs["stomach"] = 2400.0
	c.state.needs["reserve"] = 2500.0
	c.advance(10.0)
	var s0 := _stomach()
	c.advance(10.0 * 60.0)
	check(_stomach() < s0 - 700.0, "ten game hours empty the stomach (%.0f -> %.0f)" % [s0, _stomach()])
	c.state.needs["stomach"] = 600.0
	c.advance(10.0)
	check(c.need_stages()["need.food"] == "hungry", "a low stomach is hungry (%s)" % c.need_stages()["need.food"])
	check(notes.has("hungry") and player.interactor._notice.text == "You are hungry", "and the player is told (%s)" % player.interactor._notice.text)
	var n0 := _pack("jerky")
	s0 = _stomach()
	var r := b.eat("jerky")
	check(bool(r.ok) and absf(_stomach() - s0 - 280.0) < 1.0 and _pack("jerky") == n0 - 1, "jerky: +280 game kcal, one less in the pack (%s)" % r.text)
	check(not bool(b.eat("cornmeal").ok) and String(b.eat("cornmeal").text).contains("cooked"), "cornmeal must be cooked first")
	_give("acorns", 2)
	check(String(b.eat("acorns").text).contains("leached"), "acorns must be leached first")
	_give("venison", 2)
	check(b.best_food() == "jerky", "the best food: jerky before raw venison (%s)" % b.best_food())
	s0 = _stomach()
	r = b.eat("venison")
	check(bool(r.ok) and _stomach() - s0 > 700.0, "raw venison: a meal (+%.0f)" % (_stomach() - s0))
	c.state.needs["stomach"] = 2950.0
	r = b.eat("venison")
	check(not bool(r.ok) and String(r.text).contains("full"), "a full stomach refuses (%s)" % r.text)
	# V: the best food
	c.state.needs["stomach"] = 300.0
	n0 = _pack("jerky")
	Input.action_press(&"eat")
	await frames(2)
	Input.action_release(&"eat")
	await frames(2)
	check(_pack("jerky") == n0 - 1, "V eats the jerky (%s)" % player.interactor._notice.text)
	# the pack screen: a right-click on the venison
	var scr := InventoryScreen.open_for(player)
	await process_frame
	var nv := scr.inv.pack_count("venison")
	scr.use_item("venison")
	check(scr.inv.pack_count("venison") == nv - 1 and scr._msg.text.begins_with("You eat the venison"), "in the pack, a right-click eats (%s)" % scr._msg.text)
	scr.close()
	await process_frame
	check(_pack("venison") == nv - 1, "and the pack keeps it eaten")


# --- Body --------------------------------------------------------------------------------------------------

func _test_body() -> void:
	var c := b.core
	c.state.needs["stomach"] = 2400.0
	player.global_position = Vector3(40, FrontierTerrain.height_at(40, 40) + 0.1, 40)
	player.yaw = atan2(-1.0, 0.0)
	await frames(10)
	check(c.state.activity == "rest", "standing still: rest (%s)" % c.state.activity)
	check(String(c.state.context.get("location", "")) == "poi.fort.woods", "outside the palisade: the woods")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await frames(90)
	check(c.state.activity == "sprint", "sprinting: sprint (%s)" % c.state.activity)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	await frames(90)
	var f0 := float(c.state.needs.fatigue)
	c.state.needs["stomach"] = 2400.0
	c.state.needs["reserve"] = 2500.0
	c.advance(30.0 * 60.0)
	check(float(c.state.needs.fatigue) <= f0 + 0.01 and c.need_stages()["need.rest"] == "rested", "thirty hours awake and never tired (sleep is a boost, not a need)")
	c.state.needs["stomach"] = 2400.0
	c.state.needs["reserve"] = 2500.0
	c.state.needs["warmth"] = 10.0
	SurvivalConditions.update_driven(c)
	c.invalidate_modifiers()
	await settle()
	check(not player.sprint_allowed and player.survival_speed_mult < 0.8, "hypothermic, no sprint (x%.2f)" % player.survival_speed_mult)
	c.state.needs["warmth"] = 100.0
	SurvivalConditions.update_driven(c)
	c.invalidate_modifiers()
	await settle()
	check(player.sprint_allowed and absf(player.survival_speed_mult - 1.0) < 0.01, "warm again, the player is as ever (x%.2f, sprint %s, %s; core mods x%s sprint %s; warmth %.0f %s; conds %s)" % [player.survival_speed_mult, player.sprint_allowed, c.icons().map(func(i): return "%s:%s" % [i.id, i.stage]), c.get_modifiers().get("move_speed_mult"), c.get_modifiers().get("sprint_allowed"), c.state.needs.warmth, c.need_stages()["need.warmth"], c.state.conditions.keys()])


# --- Health ------------------------------------------------------------------------------------------------

func _test_health() -> void:
	var c := b.core
	player.health = 100.0
	await settle()
	player.apply_hit(20.0, player.global_position + Vector3.UP, Vector3.FORWARD, null, "body")
	await settle()
	check(absf(c.health() - 80.0) < 0.5, "a bite counts for the core (%.1f)" % c.health())
	c.state.needs["stomach"] = 0.0
	c.state.needs["reserve"] = 0.0
	var h0 := player.health
	c.advance(5.0 * 60.0)
	await settle()
	report["wasting_5h"] = snappedf(h0 - player.health, 0.1)
	check(c.need_stages()["need.food"] == "wasting" and player.health >= h0 - 0.5 and absf(c.health() - player.health) < 0.5,
			"wasting weakens but drains no health (%.1f -> %.1f)" % [h0, player.health])
	player.health = 3.0
	await settle(2)
	c.advance(3.0 * 60.0)
	await settle()
	check(not player.is_dead and not c.is_dead(), "and nobody starves to death, even at 3 health (%.1f)" % player.health)
	player.respawn()
	await settle()
	check(not c.is_dead() and not player.is_dead and absf(c.health() - player.health) < 0.5, "a respawn brings the core back")
	c.state.needs["stomach"] = 2400.0
	c.state.needs["reserve"] = 2500.0


# --- Sleep -------------------------------------------------------------------------------------------------

func _press(action: StringName) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(2)


## Z held: a tap only sits down to rest; held, the player sleeps (SurvivalSleep.HOLD_SLEEP_S).
func _hold_sleep() -> void:
	Input.action_press(&"sleep")
	await secs(SurvivalSleep.HOLD_SLEEP_S + 0.3)
	Input.action_release(&"sleep")
	await frames(2)


func _test_sleep() -> void:
	var c := b.core
	player.global_position = Vector3(40, FrontierTerrain.height_at(40, 40) + 0.1, 40)
	player.velocity = Vector3.ZERO
	await frames(30)
	# late evening, tired
	var now := SurvivalClock.hour(c)
	c.advance(fposmod(22.0 - now, 24.0) * 60.0)
	c.state.needs["fatigue"] = 70.0
	c.state.needs["stomach"] = 2600.0
	await frames(3)
	await _hold_sleep()
	check(b.sleeper.sleeping and c.state.asleep and player.kneeling == b.sleeper, "Z held: the player sits down and sleeps")
	var d0 := SurvivalClock.abs_day(c)
	var t := 0.0
	while b.sleeper.sleeping and t < 30.0:
		await secs(0.25)
		t += 0.25
	report["sleep_real_s"] = t
	report["sleep_woke"] = b.sleeper.why_woke
	check(not b.sleeper.sleeping and player.kneeling == null, "and gets up after %.1f real seconds (%s)" % [t, b.sleeper.why_woke])
	var h := SurvivalClock.hour(c)
	check(SurvivalClock.abs_day(c) == d0 + 1 and h > 5.0 and h < 8.0, "in the morning (%s)" % SurvivalClock.time_string(c))
	check(float(c.state.needs.fatigue) < 30.0, "rested (fatigue %.0f)" % float(c.state.needs.fatigue))
	var left := b.rested_hours_left()
	report["rested_h"] = snappedf(left, 0.1)
	check(b.is_well_rested() and left > 4.0 and left < 13.0 and player.interactor._notice.text.contains("well rested"), "a night on the ground earns %.1f hours well rested (%s)" % [left, player.interactor._notice.text])
	check(is_equal_approx(SurvivalBridge.rest_earned_h(8.0, 1.0), 15.0) and SurvivalBridge.rest_earned_h(0.5, 1.0) == 0.0, "better sleep earns more (8 h good: 15 h); a doze earns none")
	# the boost: healing 3 x, skills 1.25 x, a poultice stronger
	player.health = 50.0
	await frames(3)
	var hp0 := player.health
	c.advance(2.0 * 60.0)
	await frames(3)
	report["rested_heal_2h"] = snappedf(player.health - hp0, 0.1)
	check(player.health - hp0 > 5.0, "well rested, two hours heal %.1f (x3 the core's 1 an hour)" % (player.health - hp0))
	check(is_equal_approx(player.gather.skills.award_mult, 1.25), "and skills grow x1.25")
	check(is_equal_approx(SurvivalBridge.heal_item_mult_in(self), 1.5), "and a poultice heals x1.5")
	c.state.flags["well_rested_until"] = c.state.minutes - 1.0
	await frames(3)
	check(not b.is_well_rested() and is_equal_approx(player.gather.skills.award_mult, 1.0) and is_equal_approx(SurvivalBridge.heal_item_mult_in(self), 1.0), "worn off, all as before")
	player.health = player.max_health
	check(c.need_stages()["need.food"] in ["fed", "peckish"], "going from fed to peckish in the night did not wake them (%s)" % c.need_stages()["need.food"])
	# a wolf near wakes a sleeper
	c.advance(fposmod(23.0 - SurvivalClock.hour(c), 24.0) * 60.0)
	await frames(3)
	await _hold_sleep()
	await secs(1.0)
	c.report_threat(40.0)
	await secs(3.0)
	check(not b.sleeper.sleeping and b.sleeper.why_woke.contains("threat"), "a wolf 40 m off wakes the sleeper (%s)" % b.sleeper.why_woke)
	c.clear_threat()
	await secs(1.0)
	# moving wakes (fed, so hunger does not wake them first)
	c.state.needs["stomach"] = 2600.0
	await _hold_sleep()
	await secs(1.5)
	Input.action_press(&"move_forward")
	await frames(10)
	Input.action_release(&"move_forward")
	await secs(3.0)
	check(not b.sleeper.sleeping and b.sleeper.why_woke == "woke", "moving wakes (%s)" % b.sleeper.why_woke)


# --- Save --------------------------------------------------------------------------------------------------

func _test_save() -> void:
	var c := b.core
	var doc := b.save_state()
	var m0 := c.state.minutes
	var s0 := _stomach()
	c.advance(5.0 * 60.0)
	c.state.needs["stomach"] = 100.0
	check(b.load_state(doc), "load_state takes the saved document")
	check(absf(b.core.state.minutes - m0) < 0.01 and absf(float(b.core.state.needs.stomach) - s0) < 0.01, "the core is back as it was saved")
	check(b.core != c, "a new core (the bridge follows it)")


# --- Weather -----------------------------------------------------------------------------------------------

func _test_weather() -> void:
	var c := b.core
	var ws := WeatherSystem.new()
	ws.kind = WeatherSystem.Kind.STORM
	ws.rain = 0.8
	check(SurvivalBridge.weather_state_of(ws) == "storm", "the sky's storm is a storm")
	ws.kind = WeatherSystem.Kind.OVERCAST
	ws.rain = 0.2
	check(SurvivalBridge.weather_state_of(ws) == "rain", "its rain is rain")
	ws.rain = 0.0
	ws.overcast = 0.8
	check(SurvivalBridge.weather_state_of(ws) == "overcast", "a grey sky is overcast")
	ws.overcast = 0.2
	ws.kind = WeatherSystem.Kind.FAIR
	check(SurvivalBridge.weather_state_of(ws) == "clear", "a fair sky is clear")
	SurvivalWeather.set_external(c, "clear", 3.0, 250.0)
	c.state.needs["wetness"] = 0.0
	c.advance(24.0 * 60.0)
	check(SurvivalWeather.state_id(c) == "clear" and float(c.state.needs.wetness) < 0.01, "told clear, it stays clear a whole day and nobody gets wet (%s)" % SurvivalWeather.state_id(c))
	SurvivalWeather.set_external(c, "rain", 4.0, 250.0)
	c.advance(2.0 * 60.0)
	check(float(c.state.needs.wetness) > 0.2, "told rain, the player out in it gets wet (%.2f)" % float(c.state.needs.wetness))
	SurvivalWeather.set_external(c, "clear", 3.0, 250.0)
