extends SceneTree
## Drink and tobacco (Vices; user 2026-09-27), on the real level with the survival rules on:
##   kit       a new character carries rum, tobacco and a clay pipe
##   pulls     hold U: a pull as long as held (a gill in 3 s), the gauge the size of the pull; it soaks in later
##   drink     a gill: merry when it has soaked in (the player is told), blunt force on the bleed pool, no well-rested
##             boost; past merry the player is told nothing; drunk: the shots spread and the aim sways; senseless:
##             passed out, the hours run until they come to
##   tobacco   a pipeful (the clay pipe needed): steady, skill checks +0.05, reloads 8% quicker; too much close together:
##             queasy
##   habit     moderation stays free; heavy drinking takes hold; addicted and sober nothing is capped (a craving now and
##             then); a dram then is a relapse: no boost for 48 game hours; sober long enough, free of it
##
##   Godot --headless --path . -s tests/survival_game/test_vices.gd -- survival=on
## "VICES TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var p: FrontierPlayer
var v: Vices
var notices: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func secs(t: float) -> void:
	await create_timer(t).timeout


func settle(n := 3) -> void:
	for i in n:
		await process_frame
		await physics_frame


func _pack(kind: String) -> int:
	return InventoryState.from_player(p).pack_count(kind)


func _give(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(p)
	inv.add(kind, n)
	p.inventory_pack = inv.pack.duplicate(true)


func _drunk(meter: float) -> void:
	b.core.state.needs["drunk"] = meter
	SurvivalConditions.update_driven(b.core)
	b.core.invalidate_modifiers()


## Fed and warm (the long jumps of the clock would otherwise starve or freeze the test's player).
func _feed() -> void:
	b.core.state.needs["stomach"] = 2600.0
	b.core.state.needs["reserve"] = 2500.0
	b.core.state.needs["warmth"] = 100.0
	p.health = p.max_health


func _src(kind: String) -> Node:
	var n := Node.new()
	n.set_meta(&"damage_kind", kind)
	root.add_child(n)
	return n


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	v = b.vices if b else null
	check(b != null and p != null and v != null, "the level has the survival rules and Vices (survival=on)")
	if v == null:
		_end()
		return
	p.ignore_mouse_capture = true
	b.core.clear_threat()
	await settle()
	check(_pack("rum") == 6 and _pack("tobacco") == 6 and _pack("clay_pipe") == 1, "a new character carries rum (6 gills), tobacco (6 pipefuls) and a clay pipe")
	check(InputMap.has_action(&"drink") and InputMap.has_action(&"smoke"), "hold U to drink, Y to smoke")
	await _test_drink()
	await _test_tobacco()
	await _test_habit()
	await _test_pass_out()
	await _test_condition_tab()
	_end()


## The clock on `minutes` game minutes in small steps (what was drunk soaks in).
func _soak(minutes: float) -> void:
	var left := minutes
	while left > 0.0:
		var m := minf(5.0, left)
		b.core.advance(m)
		left -= m
		await settle(1)


func _test_drink() -> void:
	_feed()
	# not well rested: well rested, drink wears off twice as fast (LastingChill's rule)
	b.core.state.flags.erase("well_rested_until")
	b.core.state.flags.erase("warm_rest_until")
	# hold U: a pull as long as it is held
	Input.action_press(&"drink")
	await secs(1.5)
	Input.action_release(&"drink")
	await settle()
	var st := v._st()
	check(v.pull_s > 1.2 and float(st.flask) > 0.4 and float(st.flask) < 0.62 and _pack("rum") == 5,
			"holding U 1.5 s: half a gill from the bottle (%.2f left in it, %.1f s pulled)" % [float(st.flask), v.pull_s])
	check(v.shown_drink_stage() == "" and float(st.gut) > 5.0, "not merry yet: it has to soak in (%.1f in the gut)" % float(st.gut))
	v.take("drink", 0.5)
	await _soak(40.0)
	await settle(3)
	check(v.shown_drink_stage() == "merry" and p.interactor._notice.text.begins_with("You feel merry: a blow"), "a gill soaks in: merry, and the player is told (%s)" % p.interactor._notice.text)
	b.core.state.flags["well_rested_until"] = b.core.state.minutes + 600.0
	b.core.advance(1.0)
	await settle(3)
	check(not b.is_well_rested() and b.rest_cap_h() == 0.0, "merry: no well-rested boost (rested %s, cap %s)" % [b.is_well_rested(), b.rest_cap_h()])
	p.health = 100.0
	p.wounds.clear()
	p.apply_hit(20.0, p.global_position, Vector3.FORWARD, _src("blunt"), "body")
	check(is_equal_approx(p.health, 100.0) and is_equal_approx(p.wounds.pool, 10.0), "merry: a blow hurts nothing now, half on the bleed pool (%.1f, %.1f)" % [p.health, p.wounds.pool])
	p.wounds.clear()
	var w := p.weapon
	var s0 := w.target_spread() / maxf(p.aim_spread_mult, 0.001)
	v.take("drink", 1.0)
	await _soak(40.0)
	check(SurvivalConditions.stage_of(b.core, "cond.drunk") == "tipsy" and v.shown_drink_stage() == "" and is_equal_approx(p.aim_spread_mult, 1.0),
			"past merry nothing is told, and tipsy the aim is steady (%s)" % SurvivalConditions.stage_of(b.core, "cond.drunk"))
	v.take("drink", 1.2)
	await _soak(40.0)
	await settle(3)
	check(SurvivalConditions.stage_of(b.core, "cond.drunk") == "drunk" and p.aim_spread_mult > 1.2 and p.aim_sway > 0.5,
			"too much: the shots spread x%.2f and the aim sways %.1f degrees" % [p.aim_spread_mult, p.aim_sway])
	check(w.target_spread() > s0 * 1.2, "the weapon's spread grows with it (%.2f against %.2f)" % [w.target_spread(), s0])
	var y0 := p.yaw
	await secs(1.0)
	check(absf(p.yaw - y0) > 0.001, "and the view wanders (%.4f rad)" % absf(p.yaw - y0))
	var told := p.interactor._notice.text.to_lower()
	check(not told.contains("tipsy") and not told.contains("drunk") and not told.contains("senseless"), "no notice names the stage (%s)" % told)
	_drunk(0.0)
	b.core.state.conditions.erase("cond.queasy")
	b.core.invalidate_modifiers()
	await settle(4)
	check(is_equal_approx(p.aim_spread_mult, 1.0) and p.aim_sway == 0.0, "sober again: the aim is steady")
	check(float(b.core.get_modifiers().get("check_mod", 0.0)) >= 0.0, "drink took nothing from the skills")
	check(not v.has_method("use"), "only G drinks and Y smokes: nothing in the pack does")
	_drunk(0.0)


func _test_tobacco() -> void:
	var inv := InventoryState.from_player(p)
	inv.take("clay_pipe", 1)
	p.inventory_pack = inv.pack.duplicate(true)
	check(v.take("tobacco", 1.0) == 0.0 and v.why_not("tobacco").contains("clay pipe") and _pack("tobacco") == 6, "no pipe, no smoke (%s)" % v.why_not("tobacco"))
	_give("clay_pipe", 1)
	Input.action_press(&"smoke")
	await secs(2.0)
	Input.action_release(&"smoke")
	await settle()
	check(_pack("tobacco") == 5 and float(v._st().bowl) > 0.6, "holding Y: a draw, the pipe packed from the twist (%.2f of the bowl left)" % float(v._st().bowl))
	v.take("tobacco", 0.8)
	await _soak(10.0)
	check(v.tobacco_stage() == "steady" and p.interactor._notice.text.begins_with("Your hands feel steady: reloads 8% faster"), "a pipeful in: steady hands (%s)" % p.interactor._notice.text)
	check(is_equal_approx(p.reload_time_mult, Vices.RELOAD_MULT) and float(b.core.get_modifiers().get("check_mod", 0.0)) >= 0.049,
			"reloads x%.2f, skill checks %+.2f" % [p.reload_time_mult, float(b.core.get_modifiers().get("check_mod", 0.0))])
	var musket: Firearm = null
	for w in p.weapons.values():
		if w is Firearm and (w as Firearm).reload_stages.size() > 0:
			musket = w
			break
	if musket:
		var was_loaded := musket.loaded
		var was_state = musket.state
		var was_stage: int = musket._stage
		musket.loaded = false
		musket.reserve = maxi(musket.reserve, 1)
		musket.start_reload()
		var first := float(musket.reload_stages[was_stage][1])
		check(absf(musket._stage_left - first * Vices.RELOAD_MULT) < 0.01, "%s: the reload stage %.2f s, not %.2f" % [musket.display_name, musket._stage_left, first])
		musket.state = was_state
		musket.loaded = was_loaded
		musket._stage = was_stage
	v.take("tobacco", 2.2)
	await _soak(10.0)
	check(v.tobacco_stage() == "heavy" and String(SurvivalUtil.dict(b.core.state.conditions.get("cond.queasy")).get("cause", "")) == "tobacco",
			"too much close together: heavy, and queasy")
	check(v.dependence("tobacco") > 0.0 and not v.addicted("tobacco"), "the habit starts (%.1f), not yet a hold" % v.dependence("tobacco"))
	await _pass(12.0)
	check(v.tobacco_stage() == "" and is_equal_approx(p.reload_time_mult, 1.0), "hours later the pipe has worn off")
	b.core.state.conditions.erase("cond.queasy")
	b.core.invalidate_modifiers()


## The clock `hours` on, 4 at a time, the player kept fed, warm and whole between (the test's long jumps would starve
## or freeze them otherwise).
func _pass(hours: float) -> void:
	var left := hours
	while left > 0.0:
		_feed()
		var h := minf(4.0, left)
		b.core.advance(h * 60.0)
		left -= h
		await settle(2)


func _test_habit() -> void:
	var c := b.core
	c.state.flags.erase("well_rested_until")
	c.state.flags.erase("warm_rest_until")
	_give("rum", 60)
	# moderation: a dram a day for five days
	for d in 5:
		v.take("drink", 1.0)
		await _pass(24.0)
	check(not v.addicted("drink") and v.dependence("drink") < 15.0, "a dram a day for five days: no hold (%.1f)" % v.dependence("drink"))
	# heavy: three drams a night (drunk) for six nights
	var nights := 0
	while not v.addicted("drink") and nights < 8:
		v.take("drink", 3.0)
		await _soak(60.0)
		_drunk(0.0)
		await _pass(20.0)
		nights += 1
	check(v.addicted("drink") and nights >= 3, "drunk every night: after %d nights it has a hold (%.1f)" % [nights, v.dependence("drink")])
	# the nights after the hold were relapses: past them, sober, nothing is capped
	await _pass(49.0)
	c.state.conditions.erase("cond.queasy")
	c.invalidate_modifiers()
	check(v.addicted("drink") and not v.blocks_rest() and b.rest_cap_h() > 0.0, "addicted but sober: nothing capped (cap %s h)" % str(b.rest_cap_h()))
	(c.state.flags.vices.crave_at as Dictionary)["drink"] = c.state.minutes - 1.0
	c.advance(1.0)
	await settle(3)
	check(p.interactor._notice.text in Vices.crave_lines("drink"), "only a craving now and then, the inner voice (%s)" % p.interactor._notice.text)
	v.take("drink", 0.3)
	await _soak(30.0)
	_drunk(0.0)
	v._st()["gut"] = 0.0
	await settle()
	check(v.blocks_rest() and b.rest_cap_h() == 0.0, "a pull now is a relapse: no well-rested boost")
	await _pass(47.0)
	check(v.blocks_rest(), "still none 47 game hours later")
	await _pass(2.0)
	check(not v.blocks_rest(), "after 48 sober hours the relapse is over")
	var days := 0
	while v.addicted("drink") and days < 14:
		await _pass(24.0)
		days += 1
	check(not v.addicted("drink") and v.dependence("drink") < Vices.RECOVERED_AT, "sober on: free of it %d days after the relapse ended (%.1f)" % [days, v.dependence("drink")])


func _test_pass_out() -> void:
	_feed()
	b.core.state.flags.erase("well_rested_until")
	b.core.state.flags.erase("warm_rest_until")
	var h0 := SurvivalClock.hour(b.core)
	var m0 := b.core.state.minutes
	_drunk(70.0)
	var n0 := int(b.core.state.stats.get("passed_out", 0))
	v.take("drink", 1.0)
	var went := false
	var tt := 0.0
	while tt < 20.0 and not went:
		b.core.advance(2.0)
		await settle(1)
		went = b.sleeper.passed_out
		tt += 0.1
	check(went and int(b.core.state.stats.get("passed_out", 0)) > n0, "past senseless: the player goes down")
	check(v.shown_drink_stage() == "" and not b.sleeper._label.visible, "and nothing says why")
	var t := 0.0
	while b.sleeper.passed_out and t < 30.0:
		await secs(0.25)
		t += 0.25
	var gone := (b.core.state.minutes - m0) / 60.0
	check(not b.sleeper.passed_out and not b.core.is_passed_out() and gone >= 0.4, "they come to %.1f game hours later, in %.1f real seconds" % [gone, t])
	check(p.interactor._notice.text.contains("come to"), "and wake with a pounding head (%s)" % p.interactor._notice.text)


## Tab's Condition tab: the body and the vices, merry and nothing past it.
func _test_condition_tab() -> void:
	_feed()
	_drunk(0.0)
	v._st()["gut"] = 0.0
	b.core.state.conditions.erase("cond.queasy")
	b.core.invalidate_modifiers()
	p.health = 60.0
	p.wounds.clear()
	p.apply_hit(40.0, p.global_position, Vector3.FORWARD, _src("bleed"), "body")
	v.take("tobacco", 1.0)
	v.take("drink", 1.0)
	await _soak(40.0)
	await settle(3)
	var scr := InventoryScreen.open_for(p, "condition")
	await settle(4)
	var txt := ""
	for l in scr._condition.find_children("*", "Label", true, false):
		txt += (l as Label).text + " | "
	check(scr.tab == "condition" and scr._condition.visible and not scr._gear.visible, "Tab: the Condition tab")
	check(txt.contains("Health") and txt.contains("Bleeding") and txt.contains("Well rested") and txt.contains("Hunger") and txt.contains("Warmth"),
			"the body: health, bleeding, well rested, hunger, warmth (%s)" % txt)
	check(txt.contains("Merry") and txt.contains("Steady hands") and txt.contains("Not with drink in you"), "merry, the pipe, and why no boost")
	scr.close()
	await settle(2)
	v.take("drink", 2.5)
	await _soak(60.0)
	await settle(3)
	scr = InventoryScreen.open_for(p, "condition")
	await settle(4)
	txt = ""
	for l in scr._condition.find_children("*", "Label", true, false):
		txt += (l as Label).text + " | "
	var stage := SurvivalConditions.stage_of(b.core, "cond.drunk")
	check(stage in ["tipsy", "drunk", "senseless"] and not txt.contains("Merry") and not txt.to_lower().contains("tipsy") and not txt.to_lower().contains("drunk:"),
			"past merry the tab says nothing of the drink (%s: %s)" % [stage, txt])
	scr.close()
	_drunk(0.0)


func _end() -> void:
	if fails.is_empty():
		print("VICES TEST OK (%d checks)" % checks)
		quit(0)
	else:
		print("VICES TEST FAILED (%d of %d): %s" % [fails.size(), checks, fails])
		quit(1)
