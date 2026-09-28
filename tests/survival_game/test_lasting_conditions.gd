extends SceneTree
## What neglect leaves behind (LastingConditions; user 2026-09-27: "the pressure is stunted growth and decay people have
## to fix their toon with"), on the level with the survival bridge, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_lasting_conditions.gd -- survival=on survival_seed=7
##
##   wasted     a day starving: health held at 80%, skills grow 25% slower (the axe's and the core's); two days fed end it
##   ague       soaked and cold: a sleep's boost halved, heals at 70%; wintergreen tea helps; a day dry, warm and
##              well rested ends it
##   festering  a bleeding wound left undressed six hours: health held at 60% and drained to half, never lower; a
##              poultice stops the drain; rest closes it
##   flux       the stomach turned by raw meat twice: a meal nourishes half; raw meat sets the cure back; blackberries
##              help; two days end it
##   sore feet  three hours barefoot on the move: restless (not slower: user "i dont think i want it to effect movement
##              speed"); a night in moccasins mends them
##   shown      the Condition tab's Lasting harm rows (and what is coming on), festering's cap on the health bar, the save;
##              no one dies
## Ends with "LASTING CONDITIONS TEST OK (<n> checks)" or "LASTING CONDITIONS TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var lc: LastingConditions
var player: FrontierPlayer
var spot := Vector3(24.0, 0.0, 10.0)


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


## `minutes` of game time in 20-minute steps, the bridge running between them. `needs` forced each step (stomach,
## reserve, warmth, wetness); `rested` keeps the boost on.
func pass_time(minutes: float, needs := {}, rested := false) -> void:
	var left := minutes
	while left > 0.0:
		var m := minf(20.0, left)
		for k in needs:
			b.core.state.needs[k] = needs[k]
		if rested:
			# the day's healing sleep's boost (SurvivalBridge.is_healing_rest)
			b.core.state.flags["well_rested_until"] = b.core.state.minutes + 600.0
			b.core.state.flags["heal_rest_until"] = b.core.state.minutes + 600.0
		b.core.invalidate_modifiers()
		b.core.advance(m)
		await settle(1)
		left -= m


const FED := {"stomach": 2500.0, "warmth": 90.0, "wetness": 0.0}


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	lc = b.lasting if b else null
	check(b != null and player != null and lc != null, "the bridge has its lasting conditions (survival=on)")
	if lc == null:
		_end()
		return
	player.ignore_mouse_capture = true
	SurvivalWeather.set_external(b.core, "clear", 12.0, 300.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	player.global_position = spot + Vector3.UP * 0.05
	await frames(10)
	await _test_wasted()
	await _test_ague()
	await _test_festering()
	await _test_flux()
	await _test_sore_feet()
	await _test_shown()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("LASTING CONDITIONS TEST OK (%d checks)" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("LASTING CONDITIONS TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _full_health() -> void:
	player.health = player.max_health
	b.core.state.needs["health"] = player.health
	b._health = b.core.health()


func _test_wasted() -> void:
	_full_health()
	await pass_time(20.0 * 60.0, {"stomach": 0.0, "reserve": 3000.0, "warmth": 90.0, "wetness": 0.0})
	check(not lc.is_on("wasted") and lc.exposure("wasted") > 0.7, "twenty hours starving: not yet (%.0f%%)" % (lc.exposure("wasted") * 100.0))
	var rows: Array = ConditionPanel.make(player).lasting_rows(b)
	check(rows.any(func(r: Array) -> bool: return String(r[1]).begins_with("Starving")), "the Condition tab says it is coming on")
	await pass_time(6.0 * 60.0, {"stomach": 0.0, "reserve": 3000.0, "warmth": 90.0, "wetness": 0.0})
	check(lc.is_on("wasted"), "a day starving: wasted")
	check(player.health <= player.max_health * LastingConditions.WASTED_CAP + 0.01 and not player.is_dead, "the health held at 80%% (%.0f), alive" % player.health)
	check(absf(b.skill_mult() - LastingConditions.SKILL_MULT) < 0.001 and absf(float(b.core.state.flags.get("skill_growth_mult", 1.0)) - LastingConditions.SKILL_MULT) < 0.001,
			"skills grow 25% slower (the axe's and the core's)")
	var g: GatherSkills = player.gather.skills
	check(absf(g.award_mult - LastingConditions.SKILL_MULT) < 0.001, "the gathering skills too (%.2f)" % g.award_mult)
	await pass_time(47.0 * 60.0, FED)
	check(lc.is_on("wasted") and lc.recovery("wasted") > 0.9, "47 hours fed: nearly (%.0f%%)" % (lc.recovery("wasted") * 100.0))
	await pass_time(2.0 * 60.0, FED)
	check(not lc.is_on("wasted") and absf(b.skill_mult() - 1.0) < 0.001, "two days fed: whole again")


func _test_ague() -> void:
	_full_health()
	var cold_soaked := {"stomach": 2500.0, "warmth": 40.0, "wetness": 0.9}
	await pass_time(100.0, cold_soaked)
	check(lc.is_on("ague"), "soaked and cold an hour and a half: the ague")
	check(lc.restless() and absf(lc.rest_mult() - LastingConditions.RESTLESS_REST_MULT) < 0.001 and absf(b.heal_mult() - LastingConditions.AGUE_HEAL_MULT) < 0.001,
			"restless: a sleep's boost halved away from a fire, heals at 70%")
	check(lc.rest_mult(true) == 1.0 and absf(lc.rest_drain_mult() - LastingConditions.RESTLESS_DRAIN) < 0.001,
			"by a fire the boost in full, wearing off twice as fast")
	var h_ague := SurvivalBridge.rest_earned_h(8.0, 1.0) * lc.rest_mult()
	check(h_ague < SurvivalBridge.rest_earned_h(8.0, 1.0) * 0.6, "eight hours asleep earn %.1f boost hours, not %.1f" % [h_ague, SurvivalBridge.rest_earned_h(8.0, 1.0)])
	# dry and warm but not rested: no mending; rested: it mends
	await pass_time(4.0 * 60.0, FED)
	check(lc.recovery("ague") < 0.01, "dry and warm but not rested: no mending yet")
	await pass_time(6.0 * 60.0, FED, true)
	var r0 := lc.recovery("ague")
	check(r0 > 0.2, "dry, warm and well rested: mending (%.0f%%)" % (r0 * 100.0))
	# wintergreen tea: half a day of it
	var inv := InventoryState.from_player(player)
	inv.add("wintergreen_tea", 1)
	player.inventory_pack = inv.pack.duplicate(true)
	Remedies.use(player, "wintergreen_tea", InventoryState.from_player(player))
	check(lc.recovery("ague") >= r0 + 0.45, "wintergreen tea: half a day's mending (%.0f%% -> %.0f%%)" % [r0 * 100.0, lc.recovery("ague") * 100.0])
	# soaked and cold again sets it back
	await pass_time(20.0, cold_soaked)
	check(lc.recovery("ague") < 0.01, "soaked and cold again: back to nothing")
	await pass_time(24.0 * 60.0, FED, true)
	check(not lc.is_on("ague"), "a day dry, warm and well rested: gone")


func _bleed_source() -> Node:
	var n := Node.new()
	n.set_meta(&"damage_kind", "bleed")
	current_scene.add_child(n)
	return n


func _test_festering() -> void:
	_full_health()
	var w := PlayerWounds.of(player)
	var src := _bleed_source()
	player.apply_hit(20.0, player.global_position + Vector3.UP, Vector3.FORWARD, src, "body")
	await frames(10)
	check(lc.exposure("festering") >= 0.0 and float(lc.state("festering").get("wound_min", -1.0)) >= 0.0, "a bleeding wound: the festering clock runs")
	await pass_time(5.0 * 60.0, FED)
	check(not lc.is_on("festering"), "five hours undressed: not yet")
	await pass_time(80.0, FED)
	check(lc.is_on("festering"), "six hours undressed: festering")
	check(player.health <= player.max_health * LastingConditions.FESTER_CAP + 0.01, "held at 60%% (%.0f)" % player.health)
	await pass_time(12.0 * 60.0, FED)
	var floor_h := player.max_health * LastingConditions.FESTER_FLOOR
	check(player.health >= floor_h - 0.5 and player.health <= floor_h + 1.0 and not player.is_dead, "drained to half and no lower (%.1f), alive" % player.health)
	# a poultice (the plantain) on it: the drain stops
	var inv := InventoryState.from_player(player)
	inv.add("plantain", 1)
	player.inventory_pack = inv.pack.duplicate(true)
	var said := ForageUse.use(player, "plantain", InventoryState.from_player(player))
	await frames(5)
	check(bool(lc.state("festering").get("dressed", false)), "a poultice dresses it: %s" % said)
	var hp0 := player.health
	await pass_time(3.0 * 60.0, FED)
	check(player.health >= hp0 - 0.01, "dressed: no more drain (%.0f -> %.0f)" % [hp0, player.health])
	await pass_time(6.0 * 60.0, FED, true)
	check(not lc.is_on("festering"), "six hours well rested (twelve's worth): closed")
	src.queue_free()
	w.clear()


func _test_flux() -> void:
	_full_health()
	lc.ate("venison", true, true)
	check(not lc.is_on("flux"), "raw meat turns the stomach once: not yet")
	lc.ate("venison", true, true)
	check(lc.is_on("flux") and absf(lc.food_mult() - LastingConditions.FLUX_FOOD_MULT) < 0.001, "twice: the flux, a meal nourishes half")
	# the bridge's meal: half of a jerky's worth
	var inv := InventoryState.from_player(player)
	inv.add("jerky", 1)
	player.inventory_pack = inv.pack.duplicate(true)
	b.core.state.needs["stomach"] = 500.0
	var s0 := float(b.core.state.needs.stomach)
	var r := b.eat("jerky")
	var gained := float(b.core.state.needs.stomach) - s0
	var full := b.unit_kcal("jerky")
	check(bool(r.ok) and absf(gained - full * 0.5) < full * 0.15, "a jerky nourishes %.0f of its %.0f" % [gained, full])
	await pass_time(20.0 * 60.0, FED)
	var r1 := lc.recovery("flux")
	lc.ate("blackberries", false, false)
	check(lc.recovery("flux") > r1 + 0.05, "blackberries steady the gut (%.0f%% -> %.0f%%)" % [r1 * 100.0, lc.recovery("flux") * 100.0])
	lc.ate("venison", true, false)
	check(lc.recovery("flux") < 0.01, "raw meat again: back to nothing")
	await pass_time(48.0 * 60.0, FED)
	check(not lc.is_on("flux"), "two days without raw meat: settled")


func _test_sore_feet() -> void:
	var core := b.core
	var had := SurvivalInventory.count(core, LastingConditions.MOCCASINS)
	SurvivalInventory.remove(core, LastingConditions.MOCCASINS, had)
	check(SurvivalInventory.count_usable(core, LastingConditions.MOCCASINS) < 0.5, "no moccasins")
	var steps := 0
	Input.action_press(&"move_forward")
	while not lc.is_on("sore_feet") and steps < 30:
		player.global_position = spot + Vector3.UP * 0.05
		await pass_time(20.0, FED)
		await frames(20)                  # on the move between the steps
		steps += 1
	Input.action_release(&"move_forward")
	check(lc.is_on("sore_feet"), "barefoot on the move: sore feet (%d steps)" % steps)
	await settle(3)
	check(player.sprint_allowed and player.survival_speed_mult > 0.99 and lc.restless(),
			"not slower, still running (%.2f); restless" % player.survival_speed_mult)
	lc.slept(8.0)
	check(lc.is_on("sore_feet"), "a night's sleep barefoot does not mend them")
	SurvivalInventory.add(core, LastingConditions.MOCCASINS, 1.0)
	lc.slept(3.0)
	check(lc.is_on("sore_feet"), "a nap in moccasins does not either")
	lc.slept(7.0)
	await settle(3)
	check(not lc.is_on("sore_feet") and player.sprint_allowed and not lc.restless(), "a night in moccasins: mended")
	if had > 1.0:
		SurvivalInventory.add(core, LastingConditions.MOCCASINS, had - 1.0)


func _test_shown() -> void:
	# two at once: the Condition tab rows, the icons, the save
	lc.ate("venison", true, true)
	lc.ate("venison", true, true)
	await pass_time(100.0, {"stomach": 2500.0, "warmth": 40.0, "wetness": 0.9})
	check(lc.is_on("flux") and lc.is_on("ague"), "the flux and the ague at once")
	var rows: Array = ConditionPanel.make(player).lasting_rows(b)
	var names := rows.map(func(r: Array) -> String: return String(r[0]))
	check("The flux" in names and "The ague" in names, "the Condition tab's Lasting harm lists both: %s" % [names])
	check(rows.filter(func(r: Array) -> bool: return r[2] == ConditionPanel.BAD).all(func(r: Array) -> bool: return String(r[1]).contains("Cure:")),
			"each with its cure")
	# the HUD shows no badges (user: "the other badges users can look in the tab to find"); what festering holds the
	# health under is shaded on the health bar
	var cap: ProgressBar = player.hud._cap_bar
	await settle(2)
	check(not cap.visible, "the ague and the flux cap nothing: no shade on the health bar")
	lc.state("festering")["on"] = true
	await settle(2)
	check(cap.visible and absf(cap.value - (1.0 - LastingConditions.FESTER_CAP)) < 0.01,
			"festering: the health bar shades the %d%% it cannot heal to (%.2f)" % [roundi((1.0 - LastingConditions.FESTER_CAP) * 100.0), cap.value])
	lc.state("festering")["on"] = false
	var doc := b.save_state()
	lc.state("ague")["on"] = false
	lc.state("flux")["on"] = false
	b.load_state(doc)
	await settle(3)
	check(b.lasting.is_on("ague") and b.lasting.is_on("flux"), "saved with the core, back on a load")
	check(not player.is_dead, "no one died of any of it")
