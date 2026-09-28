extends SceneTree
## Health, bleeding and rest (user 2026-09-27: "resting or sleeping just refills the bar, we don't need to speed up
## time"; "losing health works as a blood lost system ... if well rested it drains it to stop the bleeding";
## "bleeding versus blunt force"; "starvation shouldn't be a thing"; hunger "should cap the well rested"; "full
## stomachs drain the well rested slower"), on the real level with the survival rules on:
##   wounds   blunt force comes off at once and that is all; a bleeding wound takes 40% now and keeps the rest as a
##            pool that drains until the wound closes: about two thirds of it lost, half well rested, a third well
##            rested and resting; a poultice or a salve stops it; too big a pool bleeds the player to death; the HUD's
##            health ring shows the pool; "You are bleeding" / "The bleeding stops"
##   rest     a tap of Z sits down to rest: the bar refills with the clock at its own pace; a tap gets up; holding Z
##            sleeps
##   hunger   caps the boost (hungry 8 h, starving none) and runs it down faster; a full stomach slower
##
##   Godot --headless --path . -s tests/survival_game/test_wounds_rest.gd -- survival=on
## "WOUNDS REST TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var p: FrontierPlayer


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


## A source that says what kind of wound it gives.
func _src(kind: String) -> Node:
	var n := Node.new()
	if kind != "":
		n.set_meta(&"damage_kind", kind)
	root.add_child(n)
	return n


## Runs the wound's bleeding `seconds` in fixed steps (no waiting): the health it cost.
func _bleed(seconds: float) -> float:
	var h0 := p.health
	var t := 0.0
	while t < seconds and p.wounds.pool > 0.0 and not p.is_dead:
		p.wounds._physics_process(1.0 / 60.0)
		t += 1.0 / 60.0
	return h0 - p.health


func _stage(stomach: float, reserve: float) -> String:
	b.core.state.needs["stomach"] = stomach
	b.core.state.needs["reserve"] = reserve
	b.core.advance(1.0)
	return String(b.core.need_stages()["need.food"])


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	check(b != null and p != null and p.wounds != null, "the level has the survival rules and the player's wounds (survival=on)")
	if b == null or p == null:
		_end()
		return
	p.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		c.close(false)
	SurvivalWeather.set_external(b.core, "clear", 2.0, 250.0)
	b.core.state.flags["well_rested_until"] = -1.0
	await settle()
	await _test_wounds()
	await _test_drink()
	await _test_rest()
	await _test_hunger_boost()
	_end()


func _test_wounds() -> void:
	# blunt force: all at once
	p.health = 100.0
	p.apply_hit(30.0, p.global_position + Vector3.UP, Vector3.FORWARD, _src("blunt"), "body")
	check(is_equal_approx(p.health, 70.0) and p.wounds.pool == 0.0 and not p.wounds.bleeding(), "blunt force: 30 off at once, no bleeding (%.1f, pool %.1f)" % [p.health, p.wounds.pool])
	check(PlayerWounds.kind_of(FelledTree.new()) == "blunt" and PlayerWounds.kind_of(_src("")) == "bleed" and PlayerWounds.kind_of(b) == "",
			"a falling tree is blunt, a bite or a ball bleeds, the survival rules' own death is neither")
	# a bleeding wound: 40% now, the rest a pool
	p.health = 100.0
	p.apply_hit(50.0, p.global_position + Vector3.UP, Vector3.FORWARD, _src("bleed"), "body")
	check(is_equal_approx(p.health, 80.0) and is_equal_approx(p.wounds.pool, 30.0) and p.wounds.bleeding(), "a bleeding wound of 50: 20 now, 30 still to lose (%.1f, pool %.1f)" % [p.health, p.wounds.pool])
	await settle()
	check(p.interactor._notice.text.begins_with("You are bleeding"), "and says so (%s)" % p.interactor._notice.text)
	await secs(0.3)
	var pend: float = p.hud._bleed_bar.value - p.hud._health_bar.value
	var room := minf(p.wounds.pool, p.max_health - p.health) / p.max_health
	check(pend > 0.15 and absf(pend - room) < 0.02,
			"the health bar shows the blood still to lose, dark red past the health, as far as the bar goes (%.2f)" % pend)
	var lost := _bleed(300.0)
	check(p.wounds.pool == 0.0 and lost > 30.0 * 0.6 and lost < 30.0 * 0.72, "it bleeds until it closes: %.1f of the 30 lost (about two thirds)" % lost)
	await settle()
	check(p.interactor._notice.text == "The bleeding stops", "and says when it stops (%s)" % p.interactor._notice.text)
	# well rested: it closes sooner
	b.core.state.flags["well_rested_until"] = b.core.state.minutes + 600.0
	p.health = 100.0
	p.apply_hit(50.0, p.global_position, Vector3.FORWARD, _src("bleed"), "body")
	var lost_r := _bleed(300.0)
	check(lost_r > 30.0 * 0.44 and lost_r < 30.0 * 0.56, "well rested: %.1f of the 30 lost (about half)" % lost_r)
	# well rested and resting
	p.health = 100.0
	p.apply_hit(50.0, p.global_position, Vector3.FORWARD, _src("bleed"), "body")
	b.sleeper.resting = true
	var lost_s := _bleed(300.0)
	b.sleeper.resting = false
	check(lost_s > 30.0 * 0.28 and lost_s < 30.0 * 0.39, "well rested and resting: %.1f of the 30 lost (about a third)" % lost_s)
	b.core.state.flags["well_rested_until"] = -1.0
	# a poultice stops it
	p.health = 100.0
	p.apply_hit(50.0, p.global_position, Vector3.FORWARD, _src("bleed"), "body")
	var inv := InventoryState.from_player(p)
	inv.add("plantain", 1)
	var line := ForageUse.use(p, "plantain", inv)
	var lost_d := _bleed(8.0)
	check(p.wounds.pool == 0.0 and lost_d < 30.0 * 0.12 and line.contains("bleeding stops"), "a plantain poultice stops it within seconds: %.1f lost (%s)" % [lost_d, line])
	for n in p.get_children():
		if n.name == "Poultice":
			n.queue_free()
	await settle()
	# bled to death
	p.health = 30.0
	p.apply_hit(60.0, p.global_position, Vector3.FORWARD, _src("bleed"), "body")
	_bleed(300.0)
	await settle()
	check(p.is_dead and b.death_cause == "bleeding", "a wound too big to close bleeds the player to death (%s)" % b.death_cause)
	p.respawn()
	await settle(6)
	check(not p.is_dead and p.wounds.pool == 0.0 and not b.core.is_dead(), "a respawn: whole again, no wound")


## Drink: blunt force goes on the bleed pool at half from tipsy on (nothing at once); bleeding as ever; no well-rested
## boost while drunk or hungover; no aim or skill penalty in its data.
func _test_drink() -> void:
	var c := b.core
	c.state.needs["drunk"] = 65.0
	SurvivalConditions.update_driven(c)
	c.invalidate_modifiers()
	check(SurvivalConditions.stage_of(c, "cond.drunk") == "drunk" and p.wounds.drunk(), "a drunk player (%s)" % SurvivalConditions.stage_of(c, "cond.drunk"))
	p.health = 100.0
	p.wounds.clear()
	p.apply_hit(30.0, p.global_position, Vector3.FORWARD, _src("blunt"), "body")
	check(is_equal_approx(p.health, 100.0) and is_equal_approx(p.wounds.pool, 15.0), "drunk, a blunt hit of 30 hurts nothing at once: 15 goes on the pool (%.1f, pool %.1f)" % [p.health, p.wounds.pool])
	p.apply_hit(50.0, p.global_position, Vector3.FORWARD, _src("bleed"), "body")
	check(is_equal_approx(p.health, 80.0) and is_equal_approx(p.wounds.pool, 45.0), "a bleeding wound bleeds as ever (%.1f, pool %.1f)" % [p.health, p.wounds.pool])
	_bleed(300.0)
	c.state.flags["well_rested_until"] = c.state.minutes + 600.0
	await settle()
	c.advance(1.0)
	await settle()
	check(not b.is_well_rested() and b.rest_cap_h() == 0.0, "no well-rested boost while drunk")
	var mods := c.get_modifiers()
	# no skill penalty from drink; too much (drunk) is when the aim sways (user 2026-09-27: "too much drink is when
	# aiming sways"; Vices)
	check(float(mods.get("check_mod", 0.0)) == 0.0 and float(mods.get("reload_speed_mult", 1.0)) == 1.0 and float(mods.get("aim_sway_mult", 1.0)) > 1.0,
			"drunk: no skill penalty, only the aim sways (%s)" % str({"check": mods.get("check_mod"), "reload": mods.get("reload_speed_mult"), "sway": mods.get("aim_sway_mult")}))
	# sober again, the morning after: hungover, still no boost
	c.state.needs["drunk_peak"] = 65.0
	c.state.needs["drunk"] = 0.0
	SurvivalConditions.update_driven(c)
	c.invalidate_modifiers()
	check(not p.wounds.drunk() and String(SurvivalUtil.dict(c.state.conditions.get("cond.queasy")).get("cause", "")) == "hangover" and b.rest_cap_h() == 0.0,
			"sober and hungover: still no boost (the hangover)")
	SurvivalConditions.remove(c, "cond.queasy")
	c.invalidate_modifiers()
	check(b.rest_cap_h() > 0.0, "over the hangover, the boost can come again")
	p.health = p.max_health
	p.wounds.clear()


func _test_rest() -> void:
	p.global_position = Vector3(40, FrontierTerrain.height_at(40, 40) + 0.1, 40)
	p.velocity = Vector3.ZERO
	await frames(30)
	b.core.clear_threat()
	p.health = 40.0
	var m0 := b.core.state.minutes
	Input.action_press(&"sleep")
	await frames(2)
	Input.action_release(&"sleep")
	await frames(2)
	check(b.sleeper.resting and not b.sleeper.sleeping and p.kneeling == b.sleeper, "a tap of Z sits down to rest")
	await secs(5.0)
	var gained := p.health - 40.0
	var dm := b.core.state.minutes - m0
	check(gained > 4.0, "resting refills the bar (+%.1f in 5 s)" % gained)
	check(dm < 10.0 and not b.core.state.asleep, "with the clock at its own pace (%.1f game minutes, not the night)" % dm)
	var r_fed := b.sleeper.fill_rate()
	b.core.state.needs["stomach"] = 600.0
	b.core.advance(1.0)
	var r_hungry := b.sleeper.fill_rate()
	b.core.state.needs["stomach"] = 2600.0
	b.core.advance(1.0)
	check(r_fed > r_hungry and r_hungry > 0.0, "well fed rests faster than hungry, and hungry still heals (%.4f / %.4f a second)" % [r_fed, r_hungry])
	Input.action_press(&"sleep")
	await frames(2)
	Input.action_release(&"sleep")
	await secs(3.0)
	check(not b.sleeper.resting and p.kneeling == null, "a tap gets up")
	# held from standing: sleep
	p.health = 40.0
	Input.action_press(&"sleep")
	await secs(SurvivalSleep.HOLD_SLEEP_S + 0.3)
	Input.action_release(&"sleep")
	await frames(2)
	check(b.sleeper.sleeping and b.core.state.asleep, "holding Z sleeps")
	await secs(3.0)
	check(p.health > 55.0 or not b.sleeper.sleeping, "asleep the bar refills fast (%.1f)" % p.health)
	b.sleeper.wake()
	await secs(3.0)
	check(not b.sleeper.sleeping and p.kneeling == null, "and they get up")
	# a wolf near: no sitting down
	b.core.report_threat(20.0)
	check(b.sleeper.why_not_rest().contains("wolf"), "not with a wolf 20 m off (%s)" % b.sleeper.why_not_rest())
	b.core.clear_threat()
	p.health = p.max_health


func _test_hunger_boost() -> void:
	var c := b.core
	# the wounds the hits above left where they landed (LastingConditions) make the player restless (a leg): gone here
	b.lasting.wounds().clear()
	c.state.flags.erase("restless_eased")
	var fed := _stage(2600.0, 2500.0)
	c.state.flags["well_rested_until"] = c.state.minutes + 600.0
	await settle()
	c.advance(60.0)
	await settle()
	var left_fed := b.rested_hours_left()
	check(fed == "fed" and left_fed > 9.3, "a full stomach: the boost runs down slower (%s: %.2f h of 10 left after an hour)" % [fed, left_fed])
	var pk := _stage(1400.0, 2500.0)
	c.state.flags["well_rested_until"] = c.state.minutes + 600.0
	await settle()
	c.advance(60.0)
	await settle()
	var left_pk := b.rested_hours_left()
	check(left_pk < left_fed - 0.2, "less fed, faster (%s: %.2f h)" % [pk, left_pk])
	var hg := _stage(600.0, 2500.0)
	c.state.flags["well_rested_until"] = c.state.minutes + 900.0
	await settle()
	check(hg in ["hungry", "very_hungry"] and b.rested_hours_left() <= 8.01, "hungry: the boost is capped (%s: %.1f h)" % [hg, b.rested_hours_left()])
	check(b.grant_rest(8.0, 1.0) <= 8.01, "and a night's sleep earns no more than the cap")
	var st := _stage(0.0, 0.0)
	await settle()
	check(st in ["starving", "wasting"] and not b.is_well_rested(), "starving: no boost at all (%s)" % st)
	check(not p.is_dead and not c.is_dead(), "and nobody dies of it")
	_stage(2400.0, 2500.0)


func _end() -> void:
	if fails.is_empty():
		print("WOUNDS REST TEST OK (%d checks)" % checks)
		quit(0)
	else:
		print("WOUNDS REST TEST FAILED (%d of %d): %s" % [fails.size(), checks, fails])
		quit(1)
