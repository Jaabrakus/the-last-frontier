extends SceneTree
## Chilled to the bone (LastingChill; user 2026-09-27: hypothermia is not death but lasting damage, healed by being warm
## and well rested long enough; in extreme cold no rest without a heat source), on the level with the survival bridge,
## headless:
##
##   Godot --headless --path . -s tests/survival_game/test_lasting_chill.gd -- survival=on survival_seed=7
##
##   no death   freezing for hours: the health stops at the floor, the player lives
##   chilled    the exposure makes it: the health held at 70%, every heal at half speed, the health bar shades the rest
##   rest       chilled, a sleep away from a fire earns no boost ("too cold to rest"); by a lit campfire it does
##   recovery   warm and well rested for two game days ends it (and the cap); going cold again sets it back
##   bitter     a January night out of doors is extreme cold too: no rest without a fire
## Ends with "LASTING CHILL TEST OK (<n> checks)" or "LASTING CHILL TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var mode: BuildMode
var spot := Vector3(24.0, 0.0, 10.0)
var cf: Campfire


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func settle(n := 3) -> void:
	for i in n:
		await process_frame
		await physics_frame


func stand(p: Vector3) -> void:
	p.y = FrontierTerrain.height_at(p.x, p.z) + 0.05
	player.global_position = p
	player.velocity = Vector3.ZERO
	await frames(6)
	b.camp.refresh()


## `minutes` of game time in 20-minute steps, the bridge running between them; `warmth` forced each step (-1: left).
func pass_time(minutes: float, warmth := -1.0, rested := false) -> void:
	var left := minutes
	while left > 0.0:
		var m := minf(20.0, left)
		if warmth >= 0.0:
			b.core.state.needs["warmth"] = warmth
		if rested:
			# well rested by the day's healing sleep (SurvivalBridge.is_healing_rest; a nap's boost would not count)
			b.core.state.flags["well_rested_until"] = b.core.state.minutes + 600.0
			b.core.state.flags["heal_rest_until"] = b.core.state.minutes + 600.0
		b.core.state.needs["stomach"] = 2500.0
		b.core.advance(m)
		await settle(1)
		left -= m


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	check(b != null and player != null and b.chill != null, "the bridge has its chill (survival=on)")
	if b == null or b.chill == null:
		_end()
		return
	player.ignore_mouse_capture = true
	mode = player.get_node_or_null("BuildMode") as BuildMode
	SurvivalWeather.set_external(b.core, "clear", 3.0, 300.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	await _test_no_death()
	await _test_chilled()
	await _test_rest()
	await _test_recovery()
	await _test_bitter()
	_end()


func _test_no_death() -> void:
	await stand(spot + Vector3(0, 0, 30))
	player.health = 40.0
	b.core.state.needs["health"] = 40.0
	b._health = b.core.health()
	await pass_time(8.0 * 60.0, 0.0)
	check(not player.is_dead and not b.core.is_dead(), "eight hours freezing: alive")
	check(player.health >= LastingChill.COLD_FLOOR - 0.5, "the health never under the floor (%.1f)" % player.health)
	# a hard drain: the core's freezing takes 12 at once from just over the floor: it stops at the floor
	player.health = LastingChill.COLD_FLOOR + 2.0
	b.core.state.needs["health"] = player.health
	b._health = b.core.health()
	b.core.state.needs["warmth"] = 0.0
	b.core.invalidate_modifiers()
	b.core.state.needs["health"] = player.health - 12.0
	await process_frame
	await process_frame
	check(not player.is_dead and absf(player.health - LastingChill.COLD_FLOOR) < 0.6, "a 12-point freezing drain from %.0f: held at %.1f" % [LastingChill.COLD_FLOOR + 2.0, player.health])
	# and a core that died of the cold (a long skip) wakes again at the floor
	b.core.state.needs["warmth"] = 0.0
	b.core.state.needs["health"] = 0.0
	b.core.state.flags["dead"] = true
	b.core.state.flags["death_cause"] = "cold"
	await process_frame
	await process_frame
	check(not player.is_dead and not b.core.is_dead() and float(b.core.state.needs.health) >= LastingChill.COLD_FLOOR - 0.5,
			"a core dead of the cold wakes again (health %.1f), the player lives" % float(b.core.state.needs.health))


func _test_chilled() -> void:
	check(b.chill.is_on(), "the long freezing left the player chilled to the bone")
	player.health = 100.0
	await settle(2)
	check(absf(player.health - 70.0) < 0.5, "the health held at 70%% (%.1f)" % player.health)
	check(is_equal_approx(b.chill.heal_mult(), 0.5) and b.heal_item_mult() <= 0.76, "every heal at half speed (items x%.2f)" % b.heal_item_mult())
	var cap: ProgressBar = player.hud._cap_bar
	check(cap.visible and absf(cap.value - (1.0 - LastingChill.HEALTH_CAP)) < 0.01,
			"the health bar shades the 30%% it cannot heal to (%.2f)" % cap.value)


func _test_rest() -> void:
	# warm again, but chilled: a sleep with no fire by earns nothing
	b.core.state.needs["warmth"] = 100.0
	b.core.state.flags.erase("well_rested_until")
	await stand(spot + Vector3(0, 0, 30))
	check(b.extreme_cold() and not b.by_heat(), "chilled, and no fire by: extreme cold, no heat")
	check(b.sleeper.start(), "asleep away from any fire")
	var t0 := Time.get_ticks_msec()
	while b.sleeper.sleeping and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	await frames(30)
	check(b.sleeper.too_cold and b.sleeper.earned_h == 0.0 and not b.is_well_rested(), "woke: too cold to rest, no boost (%.1f h slept)" % b.sleeper.slept_h)
	# by a lit campfire it rests
	for k in [["stone", 6], ["firewood", 12]]:
		var inv := InventoryState.from_player(player)
		inv.add(k[0], k[1])
		player.inventory_pack = inv.pack.duplicate(true)
	await stand(spot + Vector3(0, 0, 3.0))
	mode.set_active(true)
	mode.select_type("campfire")
	mode.aim_at = spot
	await frames(6)
	mode.refresh_placement()
	var fp := mode.place()
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	check(fp != null, "a campfire built")
	if fp == null:
		return
	cf = fp.get_node("Campfire") as Campfire
	b.camp.refresh()
	cf.add_wood(player)
	cf.add_wood(player)
	cf.light()
	await stand(cf.global_position + Vector3(1.4, 0, 0.6))
	b.core.state.needs["warmth"] = 100.0
	check(b.by_heat(), "by the lit fire: heat")
	check(b.sleeper.start(), "asleep by the fire")
	t0 = Time.get_ticks_msec()
	while b.sleeper.sleeping and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	await frames(30)
	check(not b.sleeper.too_cold and b.sleeper.earned_h > 0.0 and b.is_well_rested(), "by the fire the sleep rests: well rested %.1f h" % b.sleeper.earned_h)


func _test_recovery() -> void:
	check(b.chill.is_on(), "still chilled after one night")
	# warm and well rested by a nap (not the day's healing sleep): no recovery (healing once a day)
	var r0 := b.chill.recovery()
	for i in 6:
		b.core.state.needs["warmth"] = 100.0
		b.core.state.needs["stomach"] = 2500.0
		b.core.state.flags["well_rested_until"] = b.core.state.minutes + 600.0
		b.core.state.flags["heal_rest_until"] = b.core.state.minutes - 1.0
		b.core.advance(20.0)
		await settle(1)
	check(b.is_well_rested() and not b.is_healing_rest() and b.chill.recovery() <= r0 + 0.001,
			"warm and rested by a nap: no nearer to mended (healing once a day)")
	# warm and well rested: a game day and a half, then cold for a moment: back to nothing
	await pass_time(36.0 * 60.0, 100.0, true)
	var r1 := b.chill.recovery()
	check(r1 > 0.7 and r1 < 1.0 and b.chill.is_on(), "a day and a half warm and rested: %.0f%% of the way" % (r1 * 100.0))
	await pass_time(20.0, 10.0, true)
	check(b.chill.recovery() == 0.0 and b.chill.is_on(), "cold again: the recovery starts over")
	await pass_time(2.0 * 24.0 * 60.0 + 40.0, 100.0, true)
	check(not b.chill.is_on(), "two game days warm and well rested: the cold has left the bones")
	player.health = 95.0
	await settle(2)
	check(player.health > 90.0 and is_equal_approx(b.chill.heal_mult(), 1.0), "the health heals whole again (%.1f)" % player.health)


func _test_bitter() -> void:
	b.new_game(SurvivalBridge.BACKGROUND, {"start_day": "jan_late", "start_hour": 5.0})
	SurvivalWeather.set_external(b.core, "clear", 3.0, 300.0)
	await settle(3)
	await stand(spot + Vector3(0, 0, 40))
	var air := SurvivalClock.air_temp_c(b.core)
	check(air < SurvivalBridge.EXTREME_AIR_C and b.extreme_cold() and not b.chill.is_on(), "a January night out of doors (%.0f C): extreme cold, not chilled" % air)
	b.core.state.flags.erase("well_rested_until")
	check(b.sleeper.start(), "asleep in the open")
	var t0 := Time.get_ticks_msec()
	while b.sleeper.sleeping and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	await frames(30)
	check(b.sleeper.too_cold and not b.is_well_rested(), "a bitter night with no fire: no rest (woke for %s)" % b.sleeper.why_woke)
	await _test_warm_rest()


## Drink caps the boost to nothing; a sleep by a fire is a warm rest, not capped; well rested, the drink wears off faster.
func _test_warm_rest() -> void:
	if cf == null:
		return
	b.core.state.needs["stomach"] = 2500.0
	b.core.state.needs["drunk"] = 45.0
	b.core.state.needs["drunk_peak"] = 45.0
	b.core.invalidate_modifiers()
	SurvivalConditions.update_driven(b.core)
	check(b.rest_cap_h() == 0.0, "tipsy: the boost is capped to nothing (%s)" % SurvivalConditions.stage_of(b.core, "cond.drunk"))
	b.core.state.flags.erase("well_rested_until")
	b.core.state.flags.erase("warm_rest_until")
	var hm := b.grant_rest(8.0, 0.9)
	check(hm == 0.0, "a sleep away from heat earns nothing drunk")
	var hw := b.grant_rest(8.0, 0.9, true)
	check(hw > 8.0 and b.is_well_rested() and b.rest_cap_h() == INF, "by a fire (a warm rest): well rested %.1f h, the cap lifted" % hw)
	await settle(3)
	check(b.is_well_rested(), "and it holds while drunk")
	var d0 := float(b.core.state.needs.drunk)
	await pass_time(60.0)
	var fell := d0 - float(b.core.state.needs.drunk)
	# the plain rate from the data (a gill 25, 6 an hour off since Vices): twice it, well rested
	var plain := float((b.core.data.condition("cond.drunk").get("meter", {}) as Dictionary).get("decay_per_game_h", 10.0))
	check(fell > plain * 1.5, "well rested, the drink wears off twice as fast (%.1f in an hour; %.0f plain)" % [fell, plain])


func _end() -> void:
	if fails.is_empty():
		print("LASTING CHILL TEST OK (%d checks)" % checks)
	else:
		print("LASTING CHILL TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
