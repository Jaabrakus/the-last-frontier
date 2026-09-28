extends SceneTree
## The rest of the time's vices (Vices; user 2026-09-27: whiskey and cider, laudanum, snuff and chew, kinnikinnick, hemp
## tops, jimsonweed, each with its trade-off; "no aim sway only for drunkenness"), on the level, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_vices_more.gd -- survival=on survival_seed=7
##
##   kit        a new character also carries whiskey (2) and laudanum (3)
##   drinks     right-click takes a drink in hand; a gill of whiskey twice rum's on the meter, warmer, the habit quicker;
##              hard cider weak, a little food; sweet cider food, no drink; nothing left: nothing to drink
##   cider      pressed sweet cider turns hard in the pack in two game days
##   kinnikinnick  half a pipe's steadiness and no habit; with tobacco most of it for a light habit
##   hemp       calm: a sleep rests deeper, skills slower, the stomach empties faster; its own habit
##   laudanum   every wound's cost gone (the chest's cap, a leg's restlessness, an arm's reload), the flux stayed and
##              half a day nearer mended, skills slower; a second dose within six hours: out cold and hurt
##   snuff      steady at once, for about an hour; chew: steady four hours, food nourishes less
##   jimsonweed a leaf eases the ague; more is madness (skill checks fail, no well-rested boost); a lot: a collapse
##   withdrawal addicted and sober, an inner voice keeps at it (the pains, and the talk of just one more), a line at a
##              time, often; jimsonweed's madness speaks in words too (nothing on the screen)
##   the aim    none of it sways the aim or spreads the shot, nor slows the player: only the drink's drunkenness does
## Ends with "VICES MORE TEST OK (<n> checks)" or "VICES MORE TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var p: FrontierPlayer
var v: Vices
var lc: LastingConditions


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


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


func _clear_pack(kinds: Array) -> void:
	var inv := InventoryState.from_player(p)
	for k: String in kinds:
		var n := inv.pack_count(k)
		if n > 0:
			inv.take(k, n)
	p.inventory_pack = inv.pack.duplicate(true)


## The clock on `minutes` game minutes in small steps (what was taken soaks in).
func _soak(minutes: float) -> void:
	var left := minutes
	while left > 0.0:
		var m := minf(5.0, left)
		b.core.state.needs["stomach"] = maxf(float(b.core.state.needs.get("stomach", 0.0)), 1500.0)
		b.core.advance(m)
		left -= m
		await settle(1)


func _sober() -> void:
	var st := v._st()
	for k in ["gut", "smoke_in", "hemp", "hemp_in", "jimson", "jimson_in", "pipe", "flask", "bowl"]:
		st[k] = 0.0
	for k in ["laud_until", "laud_at", "quid_until", "delirium_until", "collapsed_at", "eased_ague_at"]:
		st[k] = -1e9
	st["flask_kind"] = ""
	st["bowl_kind"] = ""
	(st.dep as Dictionary).clear()
	(st.addicted as Dictionary).clear()
	(st.relapse_until as Dictionary).clear()
	b.core.state.needs["drunk"] = 0.0
	SurvivalConditions.update_driven(b.core)
	b.core.invalidate_modifiers()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await settle(20)
	b = SurvivalBridge.find(self)
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	v = b.vices if b else null
	lc = b.lasting if b else null
	check(v != null and lc != null, "the level has the survival rules and Vices (survival=on)")
	if v == null:
		_end()
		return
	p.ignore_mouse_capture = true
	b.core.clear_threat()
	await settle()
	check(_pack("whiskey") == 2 and _pack("laudanum") == 3, "a new character also carries whiskey (2 gills) and laudanum (3 doses)")
	await _test_drinks()
	await _test_cider()
	await _test_kinnikinnick()
	await _test_hemp()
	await _test_laudanum()
	await _test_snuff_chew()
	await _test_jimsonweed()
	await _test_withdrawal()
	_end()


func _test_drinks() -> void:
	_sober()
	_give("cider", 2)
	_give("sweet_cider", 1)
	check(Vices.can_choose("whiskey") and v.choose("whiskey").contains("hold U"), "right-click: the whiskey in hand")
	b.core.state.needs["warmth"] = 60.0
	var w0 := _pack("whiskey")
	v.take("drink", 1.0)
	var st := v._st()
	check(_pack("whiskey") == w0 - 1 and absf(float(st.gut) - 50.0) < 0.01 and float(b.core.state.needs.warmth) > 65.0,
			"a gill of whiskey: twice rum's (%.0f in the gut), a little warmth" % float(st.gut))
	check(absf(v.dependence("drink") - 8.0) < 0.01, "the habit quicker than rum's (%.1f)" % v.dependence("drink"))
	_sober()
	v.choose("cider")
	var s0 := float(b.core.state.needs.get("stomach", 0.0))
	v.take("drink", 1.0)
	check(absf(float(v._st().gut) - Vices.DRINKS.cider.per) < 0.01 and float(b.core.state.needs.stomach) > s0 + 30.0
			and v.dependence("drink") < 4.0, "a gill of hard cider: weak (%.0f), a little food, the habit slow" % float(v._st().gut))
	_sober()
	v.choose("sweet_cider")
	v.take("drink", 1.0)
	check(float(v._st().gut) == 0.0 and v.dependence("drink") == 0.0, "sweet cider: no drink in it")
	_clear_pack(["rum", "whiskey", "cider", "sweet_cider"])
	v._st()["flask"] = 0.0
	check(v.why_not("drink") == "Nothing to drink", "nothing left: %s" % v.why_not("drink"))
	_give("rum", 6)
	_give("whiskey", 2)
	v._st()["drink_pick"] = ""


func _test_cider() -> void:
	_give("sweet_cider", 2)
	v.pressed_cider(2)
	await _soak(24.0 * 60.0)
	check(_pack("sweet_cider") == 2 and _pack("cider") == 0, "a day on: still sweet")
	await _soak(24.0 * 60.0 + 20.0)
	check(_pack("sweet_cider") == 0 and _pack("cider") == 2, "two days: the jugs have worked hard (%d cider)" % _pack("cider"))


func _test_kinnikinnick() -> void:
	_sober()
	_give("kinnikinnick", 1)
	_give("kinnikinnick_mix", 1)
	v.choose("kinnikinnick")
	v.take("tobacco", 1.0)
	check(absf(float(v._st().smoke_in) - 12.5) < 0.01 and v.dependence("tobacco") == 0.0, "a pipe of kinnikinnick: half the steadiness, no habit")
	await _soak(10.0)
	check(v.tobacco_stage() == "steady", "steady on it")
	_sober()
	v.choose("kinnikinnick_mix")
	v.take("tobacco", 1.0)
	check(absf(float(v._st().smoke_in) - 20.0) < 0.01 and absf(v.dependence("tobacco") - 1.5) < 0.01,
			"with tobacco: most of it (20), a light habit (%.1f)" % v.dependence("tobacco"))
	v._st()["pipe_pick"] = ""


func _test_hemp() -> void:
	_sober()
	_give("hemp_tops", 2)
	v.choose("hemp_tops")
	var skill0 := b.skill_mult()
	v.take("tobacco", 1.0)
	await _soak(10.0)
	check(v.calm() and absf(v.rest_mult() - Vices.CALM_REST_MULT) < 0.001, "a pipe of hemp: calm, a sleep rests deeper")
	check(b.skill_mult() < skill0 * 0.9, "learning slower (%.2f from %.2f)" % [b.skill_mult(), skill0])
	check(absf(v.dependence("hemp") - 3.0) < 0.01 and v.dependence("tobacco") == 0.0, "its own habit, not the tobacco's")
	b.core.state.needs["stomach"] = 2000.0
	var st0 := 2000.0
	b.core.advance(60.0)
	await settle(2)
	var ate := st0 - float(b.core.state.needs.stomach)
	_sober()
	b.core.state.needs["stomach"] = 2000.0
	b.core.advance(60.0)
	await settle(2)
	var ate_sober := st0 - float(b.core.state.needs.stomach)
	check(ate > ate_sober + 15.0, "hungry sooner while calm (%.0f kcal an hour against %.0f)" % [ate, ate_sober])
	v._st()["pipe_pick"] = ""
	_aim_ok("hemp")


func _test_laudanum() -> void:
	_sober()
	lc.wounds().clear()
	lc.hit("chest", "front", "bleed", 20.0)
	lc.hit("l_leg", "front", "bleed", 20.0)
	lc.hit("r_arm", "front", "bleed", 20.0)
	lc.state("flux")["on"] = true
	lc.state("flux")["recover"] = 0.0
	check(lc.restless() and lc.reload_mult() > 1.0 and lc.health_cap() < p.max_health and lc.food_mult() < 1.0,
			"wounds in the chest, a leg and an arm, and the flux: their costs")
	var skill0 := b.skill_mult()
	var inv := InventoryState.from_player(p)
	var line := v.use_item("laudanum", inv)
	p.inventory_pack = inv.pack.duplicate(true)
	check(v.laudanum_on() and not lc.restless() and lc.reload_mult() == 1.0 and absf(lc.health_cap() - p.max_health) < 0.01
			and lc.food_mult() == 1.0, "laudanum: every wound's cost gone, the flux stayed (%s)" % line)
	check(absf(lc.recovery("flux") - 0.25) < 0.01, "the flux half a day nearer mended (%.2f)" % lc.recovery("flux"))
	check(absf(v.rest_mult() - Vices.CALM_REST_MULT) < 0.001 and b.skill_mult() < skill0 * 0.8, "a deep sleep, but learning slower")
	check(absf(v.dependence("laudanum") - 12.0) < 0.01, "the strongest habit (%.0f a dose)" % v.dependence("laudanum"))
	p.health = 80.0
	b.core.state.needs["health"] = 80.0
	b._health = b.core.health()
	inv = InventoryState.from_player(p)
	line = v.use_item("laudanum", inv)
	p.inventory_pack = inv.pack.duplicate(true)
	await settle(3)
	check(line.contains("Too much") and p.health <= 60.5 and b.sleeper.passed_out, "a second dose within six hours: out cold and hurt (%.0f)" % p.health)
	await _wake()
	lc.wounds().clear()
	lc.state("flux")["on"] = false
	_aim_ok("laudanum")


func _wake() -> void:
	var t0 := Time.get_ticks_msec()
	while b.sleeper.passed_out and Time.get_ticks_msec() - t0 < 30000:
		b.core.advance(10.0)
		await settle(1)
	b.sleeper.stop_now()
	await settle(3)


func _test_snuff_chew() -> void:
	_sober()
	_give("snuff", 1)
	_give("chew", 1)
	var inv := InventoryState.from_player(p)
	v.use_item("snuff", inv)
	p.inventory_pack = inv.pack.duplicate(true)
	check(v.tobacco_stage() == "steady" and v.dependence("tobacco") > 0.0, "a pinch of snuff: steady at once")
	await _soak(70.0)
	check(v.tobacco_stage() == "", "about an hour of it (%.1f on the meter)" % v.pipe_meter())
	_sober()
	inv = InventoryState.from_player(p)
	v.use_item("chew", inv)
	p.inventory_pack = inv.pack.duplicate(true)
	check(v.chewing() and absf(v.food_mult() - Vices.CHEW_FOOD_MULT) < 0.001, "a quid: food nourishes less while chewing")
	await _soak(3.0 * 60.0)
	check(v.tobacco_stage() == "steady", "three hours on: still steady")
	await _soak(1.5 * 60.0)
	check(not v.chewing() and v.food_mult() == 1.0, "four and a half: the quid spent")
	_aim_ok("snuff and chew")


func _test_jimsonweed() -> void:
	_sober()
	_give("jimsonweed", 4)
	lc.state("ague")["on"] = true
	lc.state("ague")["recover"] = 0.0
	v.choose("jimsonweed")
	v.take("tobacco", 1.0)
	await _soak(15.0)
	check(absf(lc.recovery("ague") - 0.5) < 0.01 and not v.delirious(), "a leaf smoked: the ague half mended (%.2f), wits kept" % lc.recovery("ague"))
	check(v.dependence("tobacco") == 0.0, "no habit")
	v.take("tobacco", 1.0)
	await _soak(15.0)
	var mods := b.core.get_modifiers()
	check(v.delirious() and float(mods.get("check_mod", 0.0)) < -0.3 and v.blocks_rest(),
			"another: madness, skill checks fail (%.2f), no well-rested boost" % float(mods.get("check_mod", 0.0)))
	_aim_ok("jimsonweed madness")
	var said := {}
	for i in 12:
		await _soak(5.0)
		if String(p.interactor._notice.text) in Vices.DELIRIUM_LINES:
			said[String(p.interactor._notice.text)] = true
	check(not said.is_empty(), "the madness speaks in words now and then (%s)" % [said.keys()])
	p.health = 90.0
	b.core.state.needs["health"] = 90.0
	b._health = b.core.health()
	v.take("tobacco", 2.0)
	await _soak(15.0)
	await settle(3)
	check(b.sleeper.passed_out and p.health <= 66.0, "two more: a collapse, hurt (%.0f)" % p.health)
	await _wake()
	lc.state("ague")["on"] = false
	_sober()
	await _soak(10.0)
	check(not v.delirious(), "sober again")


func _test_withdrawal() -> void:
	_sober()
	var st := v._st()
	(st.dep as Dictionary)["drink"] = 90.0
	(st.addicted as Dictionary)["drink"] = true
	(st.crave_at as Dictionary)["drink"] = b.core.state.minutes + 1.0
	var seen := {}
	var times := 0
	var last := ""
	for i in 30:
		await _soak(5.0)
		var t := String(p.interactor._notice.text)
		if t in Vices.crave_lines("drink") and t != last:
			seen[t] = true
			times += 1
			last = t
	check(times >= 3 and seen.size() >= 3, "addicted and sober: the inner voice keeps at it (%d times in two and a half hours: %s)" % [times, seen.keys()])
	var tob := Vices.crave_lines("tobacco")
	check(tob.any(func(l: String) -> bool: return l.contains("reload 8% faster")) and Vices.crave_lines("laudanum").any(func(l: String) -> bool: return l.contains("no wound would hold you back")),
			"and it argues for the good it would do: %s" % str(tob.filter(func(l: String) -> bool: return l.contains("%"))))
	_sober()


## None of it touches the aim (the drink's drunkenness alone does) or the speed.
func _aim_ok(what: String) -> void:
	b.core.invalidate_modifiers()
	v._apply_player()
	b._to_player()
	check(p.aim_sway < 0.001 and absf(p.aim_spread_mult - 1.0) < 0.001 and p.survival_speed_mult > 0.99 and p.sprint_allowed,
			"%s: the aim steady, the shot true, the speed as ever" % what)


func _end() -> void:
	if fails.is_empty():
		print("VICES MORE TEST OK (%d checks)" % checks)
	else:
		print("VICES MORE TEST FAILED (%d of %d): %s" % [fails.size(), checks, fails])
	quit(0 if fails.is_empty() else 1)
