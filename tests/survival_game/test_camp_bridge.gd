extends SceneTree
## Fire, cold and shelter through the survival bridge (CampLink, CampCooking, the linked Campfire, SurvivalSleep's
## quality; user 2026-09-27: "they need to tell the bridge when you're near a lit fire or inside a shelter. The same
## connection lets them cook cornmeal and venison, and makes sleep better so the well-rested boost lasts longer"), on the
## level with the real player, a campfire and a lean-to placed through build mode, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_camp_bridge.gd -- survival=on survival_seed=7
##
##   context   the new game's line-camp context (a fire at 1.5 m, a shelter) is gone: no fire, no roof; near the
##             campfire the core has its record and the distance; under the lean-to the core has its shelter (quality 3),
##             in front of it none
##   fire      unlit it gives no warmth; lit it warms (+20 C and more at 1-2 m); the fuel is the record's, in game
##             minutes: firewood adds 120, it burns on the core's clock and goes out here when it burns down there;
##             rain drowns it and the record goes out; smothered, out
##   cold      a January night (a new core): the campfire gets a record in it again; an hour by the fire warms the
##             player far more than one away from it (the core's winter kit keeps a resting player warm at -11 C)
##   rain      under the lean-to's roof the rain does not wet the player, in the open it does
##   cooking   F on a lit fire roasts venison (3 a roast) and bakes cornmeal into johnnycake, one cooked unit for each;
##             stopping gives the raw food back; an unlit fire does not cook; johnnycake eats
##   sleep     rough < by the fire < in the lean-to < in the lean-to by the fire; a sleep in the lean-to by the fire
##             earns more hours of WELL RESTED than the same on bare ground; the fire burning down wakes the sleeper
## Ends with "CAMP BRIDGE TEST OK (<n> checks)" or "CAMP BRIDGE TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var mode: BuildMode
var cf: Campfire
var lean: BuiltPiece
var spot := Vector3(21.0, 0.0, 6.0)


class FakeRain:
	extends Node
	var rain := 1.0

	func rain_intensity(_pos: Vector3) -> float:
		return rain


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


func count(kind: String) -> int:
	return Campfire._pack_count(player, kind)


func give(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	inv.add(kind, n)
	player.inventory_pack = inv.pack.duplicate(true)


func set_count(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	var have := inv.pack_count(kind)
	if have > n:
		inv.take(kind, have - n)
	elif have < n:
		inv.add(kind, n - have)
	player.inventory_pack = inv.pack.duplicate(true)


## The player stands at `p` (on the ground); the camp link tells the core at once.
func stand(p: Vector3) -> void:
	p.y = FrontierTerrain.height_at(p.x, p.z) + 0.05
	player.global_position = p
	player.velocity = Vector3.ZERO
	await frames(6)
	b.camp.refresh()


func place(type: String, at: Vector3) -> BuiltPiece:
	mode.set_active(true)
	mode.select_type(type)
	mode.aim_at = at
	for i in 6:
		await physics_frame
	mode.refresh_placement()
	var p := mode.place()
	if p == null:
		print("    place %s: %s" % [type, mode.verdict.get("reason", "-")])
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	return p


func ctx() -> Dictionary:
	return b.core.state.context


func rec() -> Dictionary:
	return SurvivalCamp.fire(b.core, cf.fire_id)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	check(b != null and player != null and b.camp != null and b.cook != null, "the bridge has the camp link and cooking (survival=on)")
	if b == null or b.camp == null:
		_end()
		return
	player.ignore_mouse_capture = true
	mode = player.get_node_or_null("BuildMode") as BuildMode
	SurvivalWeather.set_external(b.core, "clear", 2.0, 250.0)
	await _test_context()
	await _test_fire()
	await _test_shelter()
	await _test_cooking()
	await _test_sleep()
	await _test_cold()
	_end()


func _test_context() -> void:
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	await stand(spot + Vector3(0, 0, 30))
	check(str(ctx().get("fire_id", "x")) == "" and float(ctx().get("fire_distance_m", 0.0)) >= 99.0 and not bool(ctx().get("in_shelter", true)),
			"no camp: the new game's fire at 1.5 m and its shelter are gone (%s)" % str(b.camp.told))
	var e := SurvivalNeeds.env(b.core)
	check(float(e.fire_c) == 0.0 and float(e.shelter_q) == 0.0, "no warmth from a fire or a roof that is not there")
	for k in [["stone", 6], ["firewood", 12], ["pole", 5], ["branches", 10]]:
		give(k[0], k[1])
	await stand(spot + Vector3(0.0, 0, 3.0))
	var fp := await place("campfire", spot)
	lean = await place("lean_to", spot + Vector3(0.0, 0.0, -3.5))
	check(fp != null and lean != null, "a campfire and a lean-to are built")
	if fp == null:
		return
	cf = fp.get_node("Campfire") as Campfire
	b.camp.refresh()
	check(cf.fire_id != "" and cf.link == b.camp and str(rec().get("location", "")).begins_with("camp.fire."),
			"the campfire has its own record in the core (%s at %s)" % [cf.fire_id, rec().get("location", "")])
	check(is_equal_approx(float(rec().get("fuel_min", 0.0)), 4.0 * Campfire.FUEL_MIN_PER_WOOD) and str(rec().get("state", "")) == "out",
			"laid, unlit: 4 sticks = 480 game minutes of fuel (%.0f, %s)" % [float(rec().get("fuel_min", 0.0)), rec().get("state", "")])


func _test_fire() -> void:
	if cf == null:
		return
	await stand(spot + Vector3(1.2, 0, 0))
	check(str(ctx().fire_id) == cf.fire_id and absf(float(ctx().fire_distance_m) - 1.2) < 0.2,
			"beside it: the core knows the fire and the distance (%.2f m)" % float(ctx().fire_distance_m))
	check(float(SurvivalNeeds.env(b.core).fire_c) == 0.0, "unlit it gives no warmth")
	cf.interact(player)
	await settle(4)
	var e := SurvivalNeeds.env(b.core)
	check(cf.is_lit() and str(rec().state) == "lit", "lit here, lit in the core")
	check(float(e.fire_c) > 18.0, "lit it warms: +%.1f C at 1.2 m" % float(e.fire_c))
	await stand(spot + Vector3(6.0, 0, 0))
	var mid := float(SurvivalNeeds.env(b.core).fire_c)
	await stand(spot + Vector3(12.0, 0, 0))
	var far := float(SurvivalNeeds.env(b.core).fire_c)
	check(mid > 3.0 and mid < 12.0 and far == 0.0, "less further off, none beyond 10 m (6 m +%.1f, 12 m +%.1f)" % [mid, far])
	await stand(spot + Vector3(1.2, 0, 0))
	cf.interact(player)                                  # a stick on
	check(is_equal_approx(float(rec().fuel_min), 5.0 * Campfire.FUEL_MIN_PER_WOOD) or float(rec().fuel_min) > 4.9 * Campfire.FUEL_MIN_PER_WOOD,
			"firewood adds 120 game minutes to the record (%.0f)" % float(rec().fuel_min))
	var before := float(rec().fuel_min)
	b.core.advance(120.0)
	await settle(3)
	check(absf(before - float(rec().fuel_min) - 120.0) < 12.0 and cf.wood_left() == int(ceil(float(rec().fuel_min) / 120.0 - 0.001)),
			"it burns on the core's clock: 2 game hours, 120 minutes of fuel (%.0f -> %.0f, %d sticks)" % [before, float(rec().fuel_min), cf.wood_left()])
	b.core.advance(float(rec().fuel_min) + 20.0)
	await settle(4)
	check(not cf.is_lit() and str(rec().state) != "lit", "burnt down in the core: out here too (%s)" % rec().state)
	check(cf.interact_prompt(player).begins_with("Lay firewood"), "then it wants wood ('%s')" % cf.interact_prompt(player))
	# relit, then drowned by the rain
	cf.interact(player)
	cf.interact(player)
	await settle(2)
	check(cf.is_lit() and str(rec().state) == "lit", "wood laid, lit again")
	var rain := FakeRain.new()
	rain.add_to_group(TorchState.WEATHER_GROUP)
	current_scene.add_child(rain)
	var t0 := Time.get_ticks_msec()
	while cf.is_lit() and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	rain.queue_free()
	await settle(2)
	check(not cf.is_lit() and str(rec().state) == "out", "heavy rain drowns it: the record goes out (%s)" % rec().state)
	cf.state.wet = 0.0
	cf.interact(player)
	await settle(2)
	cf.smother()
	await settle(2)
	check(str(rec().state) == "out" and not cf.is_lit(), "smothered: out in the core")


func _test_shelter() -> void:
	if lean == null:
		return
	await stand(lean.global_transform * Vector3(0.0, 0.0, -0.3))
	var sid := str(ctx().get("shelter_id", ""))
	var sh := SurvivalCamp.shelters(b.core).get(sid, {}) as Dictionary
	check(bool(ctx().get("in_shelter", false)) and float(sh.get("quality", 0.0)) == CampLink.SHELTER_Q and str(sh.get("location", "")).begins_with("camp.shelter."),
			"under the lean-to: in its shelter, quality 3 (%s %s)" % [sid, sh])
	var e := SurvivalNeeds.env(b.core)
	check(float(e.shelter_q) == 3.0 and float(e.shelter_c) > 0.0, "out of the wind and +%.1f C" % float(e.shelter_c))
	# rain: dry under the roof, wet in the open
	SurvivalWeather.set_external(b.core, "rain", 2.0, 250.0)
	b.core.state.needs["wetness"] = 0.0
	b.core.advance(60.0)
	var under := float(b.core.state.needs.get("wetness", 0.0))
	await stand(lean.global_transform * Vector3(0.0, 0.0, 2.2))
	check(not bool(ctx().get("in_shelter", true)), "in front of it: no shelter")
	b.core.state.needs["wetness"] = 0.0
	b.core.advance(60.0)
	var open := float(b.core.state.needs.get("wetness", 0.0))
	check(under == 0.0 and open > 0.0, "the rain wets the player in the open, not under the roof (%.2f, %.2f)" % [under, open])
	SurvivalWeather.set_external(b.core, "clear", 2.0, 250.0)
	b.core.state.needs["wetness"] = 0.0


func _test_cooking() -> void:
	if cf == null:
		return
	await stand(spot + Vector3(1.4, 0, 0))
	set_count("firewood", 6)
	if not cf.is_lit():
		if cf.fuel_min() <= 0.0:
			cf.interact(player)
		cf.interact(player)
	while cf.wood_left() < 5 and count("firewood") > 0:
		cf.add_wood(player)
	await settle(2)
	b.core.state.needs["stomach"] = 0.0
	set_count("venison", 4)
	set_count("cornmeal", 3)
	set_count("roast_venison", 0)
	set_count("johnnycake", 0)
	check(cf.interact_prompt(player).contains("F  Roast venison (3)"), "a lit fire's prompt names F: '%s'" % cf.interact_prompt(player))
	# F on the fire (the key): the venison on
	Input.action_press(&"cook")
	await frames(2)
	Input.action_release(&"cook")
	await frames(2)
	check(b.cook.cooking and b.cook.kind == "venison" and b.cook.units == 3 and count("venison") == 1,
			"F: three venison go on the fire (one left in the pack)")
	check(player.kneeling == b.cook, "the player kneels at the fire")
	await _until_done()
	var got := String(b.cook.last.get("got", ""))
	check(got in ["roast_venison", "charred_venison"] and count(got) == 3 and count("venison") == 1,
			"the roast: three %s back in the pack (%s)" % [got, b.cook.last.get("text", "")])
	check(SurvivalInventory.count(b.core, "item.food.venison_raw") < 0.001 and SurvivalInventory.count(b.core, "item.food.venison_cooked") < 0.001,
			"nothing left behind in the core")
	# stopped: the food comes back raw
	check(b.cook.start(cf), "the last venison goes on")
	await frames(10)
	b.cook._cancel("moved")
	await _until_done()
	check(count("venison") == 1 and not b.cook.cooking, "stopped: the raw venison comes back")
	set_count("venison", 0)
	# cornmeal into johnnycake
	check(b.cook.start(cf) and b.cook.kind == "cornmeal" and b.cook.units == 3, "then the cornmeal: three pounds on")
	await _until_done()
	var jc := String(b.cook.last.get("got", ""))
	check(jc in ["johnnycake", "burnt_johnnycake"] and count(jc) == 3 and count("cornmeal") == 0, "three %s (%s)" % [jc, b.cook.last.get("text", "")])
	set_count("johnnycake", 1)
	var r := b.eat("johnnycake")
	check(bool(r.ok) and count("johnnycake") == 0, "johnnycake eats: %s" % r.text)
	# a cold fire does not cook
	set_count("venison", 1)
	cf.smother()
	await settle(2)
	check(not b.cook.start(cf) and not b.cook.cooking and count("venison") == 1, "an unlit fire does not cook")
	check(String(b.why_not("cornmeal")).contains("campfire"), "cornmeal's refusal says where to cook it ('%s')" % b.why_not("cornmeal"))


func _until_done() -> void:
	var t0 := Time.get_ticks_msec()
	while (b.cook.cooking or player.kneeling != null) and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await frames(4)


func _test_sleep() -> void:
	if cf == null or lean == null:
		return
	# the quality: rough, by the fire, in the lean-to, in the lean-to by the fire
	cf.interact(player)                        # lit
	set_count("firewood", 6)
	while cf.wood_left() < Campfire.MAX_WOOD and count("firewood") > 0:
		cf.add_wood(player)
	if not cf.is_lit():
		cf.light()
	await settle(2)
	await stand(spot + Vector3(40.0, 0, 0))
	var q_rough := b.rest_quality()
	await stand(spot + Vector3(1.6, 0, 0))
	var q_fire := b.rest_quality()
	cf.smother()
	await stand(lean.global_transform * Vector3(0.0, 0.0, -0.3))
	var q_lean := b.rest_quality()
	cf.light()
	await settle(2)
	b.camp.refresh()
	var q_both := b.rest_quality()
	check(q_rough < q_fire and q_fire < q_lean and q_lean < q_both,
			"sleep: rough %.2f < by the fire %.2f < in the lean-to %.2f < both %.2f" % [q_rough, q_fire, q_lean, q_both])
	var h_rough := SurvivalBridge.rest_earned_h(8.0, q_rough)
	var h_both := SurvivalBridge.rest_earned_h(8.0, q_both)
	check(h_both > h_rough + 6.0, "eight hours: well rested %.1f h rough, %.1f h in the lean-to by the fire" % [h_rough, h_both])
	# a real sleep in the lean-to by the fire, fed (hunger caps the boost: SurvivalBridge.REST_CAP_H)
	b.core.state.needs["stomach"] = 2600.0
	b.core.state.needs["reserve"] = 2500.0
	b.core.state.flags.erase("well_rested_until")
	await frames(10)
	check(b.sleeper.start(), "Z: asleep in the lean-to by the fire (%s)" % b.sleeper.where)
	var t0 := Time.get_ticks_msec()
	while b.sleeper.sleeping and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	check(b.sleeper.where == "in the lean-to by the fire" and b.sleeper.quality > q_lean, "slept there: quality %.2f (%s)" % [b.sleeper.quality, b.sleeper.where])
	var earned := b.sleeper.earned_h
	check(earned > SurvivalBridge.rest_earned_h(b.sleeper.slept_h, q_rough) + 0.01,
			"%.1f h slept earned %.1f h well rested (rough ground: %.1f)" % [b.sleeper.slept_h, earned, SurvivalBridge.rest_earned_h(b.sleeper.slept_h, q_rough)])
	# the fire burning down wakes the sleeper
	await frames(30)
	if not cf.is_lit():
		cf.interact(player)
		cf.light()
	await settle(2)
	rec()["fuel_min"] = 15.0
	await settle(2)
	b.camp.refresh()
	check(b.sleeper.start(), "asleep again, the fire nearly out")
	t0 = Time.get_ticks_msec()
	while b.sleeper.sleeping and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	check(b.sleeper.why_woke.begins_with("the fire is"), "the fire burning down wakes them: %s" % SurvivalSleep.wake_line(b.sleeper.why_woke, b.sleeper.slept_h))


## A January night: an hour by the fire warms far more than one away from it.
func _test_cold() -> void:
	if cf == null:
		return
	await frames(30)
	b.new_game(SurvivalBridge.BACKGROUND, {"start_day": "jan_mid", "start_hour": 2.0})
	SurvivalWeather.set_external(b.core, "clear", 3.0, 300.0)
	await settle(3)
	b.camp.refresh()
	check(cf.link == b.camp and SurvivalCamp.fires(b.core).has(cf.fire_id) and str(rec().location).begins_with("camp.fire."),
			"a new core: the campfire has a record in it again")
	await stand(spot + Vector3(30.0, 0, 0))
	b.core.state.needs["warmth"] = 70.0
	b.core.advance(60.0)
	var away := float(b.core.state.needs.warmth)
	await stand(spot + Vector3(1.3, 0, 0))
	if cf.fuel_min() <= 0.0:
		set_count("firewood", 2)
		cf.add_wood(player)
	cf.light()
	await settle(2)
	b.camp.refresh()
	b.core.state.needs["warmth"] = 70.0
	b.core.advance(60.0)
	var by := float(b.core.state.needs.warmth)
	check(by > away + 5.0 and by > 70.0, "a January night, an hour: away from the fire 70 -> %.0f, by it 70 -> %.0f (air %.0f C)" % [away, by, float(SurvivalNeeds.env(b.core).air_c)])


func _end() -> void:
	if fails.is_empty():
		print("CAMP BRIDGE TEST OK (%d checks)" % checks)
	else:
		print("CAMP BRIDGE TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
