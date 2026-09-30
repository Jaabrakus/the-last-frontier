extends SceneTree
## Headless tests for the survival logic core (scripts/survival/*.gd): data loading, calendar and weather, needs and
## their real-time targets, conditions and the modifier contract, skills and growth, inventory and crafting, jobs and
## the wake rules, trapping and hunting, the economy and the credit year, save/load determinism, the almanac, NPC
## schedules, signals and the M3 backlog actions.
##
## v4 (the self-sufficiency, barter and learning redesign) rewrote these on purpose: test_data_loads (47 live actions),
## test_clock_real_rate and test_runtime_node (the fixed-quantum update driver, multiplayer_readiness.md P0-1),
## test_skill_growth_rules (growth v4: challenge, level curve, repeats, first success, caps, no background multiplier),
## test_backgrounds_differ (the Clear start owes no one; debts are start variants; habits replace perks),
## test_economy_credit_year (the unpaid book uses the "Outfitted on credit" variant) and the almanac's checklist (7
## winter-ready items). The v4 systems themselves are tested in test_survival_learning.gd and test_survival_selfsuff.gd.
##
##   Godot --headless --path . -s tests/survival/test_survival_core.gd
##
## Each test builds its own SurvivalCore with a fixed seed. Failures are listed and the exit code is 1.

var failures := PackedStringArray()
var passes := 0
var current := ""


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and str(args[0]) == "--only":
		only = str(args[1])
	for name in _tests():
		if only != "" and not str(name).contains(only):
			continue
		current = name
		var n0 := failures.size()
		call(name)
		if failures.size() > n0:
			print("  %s: %d failed" % [name, failures.size() - n0])
	print("")
	print("survival core: %d checks passed, %d failed (%d ms)" % [passes, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	quit(1 if not failures.is_empty() else 0)


func _tests() -> Array:
	var out := []
	for m in get_script().get_script_method_list():
		var n := str(m.name)
		if n.begins_with("test_"):
			out.append(n)
	out.sort()
	return out


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures.append("%s: %s" % [current, what])


func near(a: float, b: float, tol: float, what: String) -> void:
	ok(absf(a - b) <= tol, "%s (got %.4f, want %.4f +- %.4f)" % [what, a, b, tol])


func between(v: float, lo: float, hi: float, what: String) -> void:
	ok(v >= lo and v <= hi, "%s (got %.4f, want %.4f..%.4f)" % [what, v, lo, hi])


func mk(bg: String = "bg.backcountry_hunter", opts: Dictionary = {}) -> SurvivalCore:
	var o := {"seed": 12345}
	for k in opts.keys():
		o[k] = opts[k]
	return SurvivalCore.new_game(bg, o)


## Calm, clear weather with the air at `air_c` right now (weather noise adjusted), for repeatable needs tests.
func set_air(core: SurvivalCore, air_c: float) -> void:
	core.state.weather["state"] = "clear"
	core.state.weather["wind_ms"] = 0.0
	core.state.weather["noise_c"] = 0.0
	core.state.weather["hours_to_tick"] = 1000.0
	core.state.weather["noise_c"] = air_c - SurvivalClock.air_temp_c(core)
	core.invalidate_modifiers()


## Worn clothing replaced by these items (added to the pack if missing).
func dress(core: SurvivalCore, items: Array) -> void:
	core.state.worn.clear()
	for it in items:
		if not SurvivalInventory.has(core, str(it)):
			SurvivalInventory.add(core, str(it), 1.0)
		core.state.worn.append(str(it))
	core.invalidate_modifiers()


## Keep the character fed, warm and rested while time passes (for calendar and economy tests).
func sustain(core: SurvivalCore) -> void:
	core.state.needs["stomach"] = 2400.0
	core.state.needs["reserve"] = 2500.0
	core.state.needs["warmth"] = 100.0
	core.state.needs["fatigue"] = 10.0
	core.state.needs["health"] = 100.0
	core.state.needs["wetness"] = 0.0
	core.state.conditions.erase("cond.injury.cut")


func live(core: SurvivalCore, minutes: float) -> void:
	var left := minutes
	while left > 0.0 and not core.is_dead():
		sustain(core)
		var step := minf(360.0, left)
		core.advance(step)
		left -= step


func json_norm(d: Dictionary) -> String:
	return SurvivalUtil.stable_key(JSON.parse_string(JSON.stringify(d)))


# ---------------------------------------------------------------- data
func test_00_smoke() -> void:
	var core := mk()
	ok(core.is_ok(), "core loads the data: %s" % ", ".join(core.data.errors))
	ok(SurvivalClock.date_string(core) == "Early September 1765", "starts Early September 1765 (%s)" % SurvivalClock.date_string(core))
	ok(SurvivalInventory.has(core, "item.weapon.musket"), "starting kit carried")
	core.advance(60.0 * 24.0)
	ok(SurvivalClock.day_id(core) == "sep_mid", "a day later it is Mid September (%s)" % SurvivalClock.day_id(core))


func test_data_loads() -> void:
	var d := SurvivalCore.load_data()
	ok(d.is_ok(), "live data loads without errors")
	ok(d.actions.size() == 47, "47 live actions in M1, M2a and M2b (%d; fix round 1 added casting balls and hook and line, the climbing gear one more)" % d.actions.size())
	ok(d.month_ids.size() == 12 and d.day_ids.size() == 36, "12 months, 36 game days")
	ok(d.backgrounds.has("bg.backcountry_hunter") and d.backgrounds.has("bg.provincial_ranger"), "both slice backgrounds")
	ok(d.modifier_keys.has("aim_sway_mult") and d.modifier_keys.has("move_speed_mult"), "modifier contract keys indexed")
	ok(d.anim_hook_for("shelter.brush_leanto") == "anim.gather_low", "a hook that is not ready falls back (chop -> gather_low)")
	ok(not d.actions.has("frog.catch_hand"), "backlog rows are not live by default")


func test_backlog_merge_m3() -> void:
	var d := SurvivalCore.load_data({"backlog_milestones": ["M3"]})
	ok(d.is_ok(), "live + M3 loads: %s" % ", ".join(d.errors))
	for id in ["frog.catch_hand", "fish.hook_line", "forage.search", "fire.friction_bowdrill", "trap.snare_set"]:
		ok(d.actions.has(id), "M3 action %s merged" % id)
	ok(d.items.has("item.food.fish_raw") and d.items.has("item.tool.hooks_line"), "M3 items merged")
	ok(not d.actions.has("travel.run_rapids") or str(d.actions["travel.run_rapids"].get("milestone")) == "M3", "only M3 rows merged")
	ok(d.merged_rows > 50, "rows merged (%d)" % d.merged_rows)
	ok(str(d.action("fire.strike_flint_steel").get("milestone")) == "M1", "live rows keep their definition")
	var live := SurvivalCore.load_data()
	ok(not live.actions.has("frog.catch_hand"), "the cached live data is not polluted by the merge")


# ---------------------------------------------------------------- calendar, clock and weather
func test_clock_calendar() -> void:
	var core := mk()
	ok(SurvivalClock.days_per_year(core) == 36, "36-day year")
	ok(SurvivalClock.season(core) == "autumn", "September is autumn")
	live(core, 36.0 * 1440.0)
	ok(SurvivalClock.date_string(core) == "Early September 1766", "a game year later (%s)" % SurvivalClock.date_string(core))
	var jan := SurvivalClock.day_index_of(core, "jan_mid")
	var jun := SurvivalClock.day_index_of(core, "jun_mid")
	ok(SurvivalClock.in_window(core, ["nov_early", "mar_late"], jan), "a window can wrap the year end")
	ok(not SurvivalClock.in_window(core, ["nov_early", "mar_late"], jun), "June is outside the trapping season")
	near(SurvivalClock.sunrise_h(core) + SurvivalClock.sunset_h(core), 24.0, 0.001, "sunrise and sunset symmetric about noon")
	var c2 := mk("", {"start_day": "dec_mid", "start_hour": 12.0})
	c2.state.weather["state"] = "clear"
	near(SurvivalClock.light_level(c2), 1.0, 0.001, "full light at noon")
	c2.advance(12.0 * 60.0)
	near(SurvivalClock.light_level(c2), 0.0, 0.001, "dark at midnight")
	ok(SurvivalClock.daylight_h(c2) < 10.0, "short December days")
	ok(SurvivalClock.gate_active(c2, "trapping_season") and SurvivalClock.gate_active(c2, "firewood_contract"), "December gates")
	ok(SurvivalClock.events_on(mk(), SurvivalClock.day_index_of(core, "sep_mid")).has("event.fall_credit"), "the fall credit is Mid September")


func test_clock_real_rate() -> void:
	var core := mk("", {"start_hour": 12.0})
	near(SurvivalClock.real_min_per_game_h(core), 2.4, 0.001, "2.4 real minutes a game hour by day")
	var m0 := core.state.minutes
	# P0-1: update() advances whole 10-minute quanta and carries the rest; no game time is lost or invented.
	var done := core.update(60.0)
	near(done, 20.0, 0.001, "a real minute by day: two whole quanta now")
	near(float(core.state.world.clock_acc), 5.0, 0.01, "the other 5 game minutes wait in the accumulator")
	core.update(60.0)
	near(core.state.minutes - m0, 2.0 * 60.0 / 2.4, 0.01, "two real minutes by day are 50 game minutes")
	var night := mk("", {"start_hour": 23.0})
	near(SurvivalClock.real_min_per_game_h(night), 1.2, 0.001, "1.2 real minutes a game hour at night")
	core.paused = true
	ok(core.update(60.0) == 0.0, "paused in menus")
func test_weather_deterministic() -> void:
	var a := mk("", {"seed": 99, "start_day": "dec_early"})
	var b := mk("", {"seed": 99, "start_day": "dec_early"})
	var c := mk("", {"seed": 100, "start_day": "dec_early"})
	var sa := PackedStringArray()
	var sb := PackedStringArray()
	var sc := PackedStringArray()
	for i in 40:
		a.advance(360.0)
		b.advance(360.0)
		c.advance(360.0)
		sa.append(SurvivalWeather.state_id(a))
		sb.append(SurvivalWeather.state_id(b))
		sc.append(SurvivalWeather.state_id(c))
	ok(sa == sb, "same seed, same weather")
	ok(sa != sc, "another seed, other weather")
	var valid := true
	for s in sa:
		if not a.data.weather_states.has(s):
			valid = false
	ok(valid, "every state is a data state")
	ok(SurvivalWeather.snow_depth_cm(a) > 5.0, "snow on the ground in winter (%.1f cm)" % SurvivalWeather.snow_depth_cm(a))
	var summer := mk("", {"start_day": "jul_mid"})
	summer.advance(2880.0)
	ok(SurvivalWeather.snow_depth_cm(summer) < 0.01, "no snow in July")


# ---------------------------------------------------------------- needs
func test_needs_food_rate() -> void:
	var core := mk("", {"start_hour": 8.0})
	core.state.needs["stomach"] = 3000.0
	core.state.needs["reserve"] = 2500.0
	core.set_activity("walk")
	set_air(core, 15.0)
	var h := 0.0
	while SurvivalNeeds.food_stage(core) != "hungry" and h < 40.0:
		core.advance(15.0)
		h += 0.25
	near(h, 19.5, 0.5, "full to Hungry in 19.5 game hours at 100 game kcal an hour")
	var clock := SurvivalUtil.dict(core.data.section("seasons", "clock").get("real_min_per_game_h"))
	var real := h * (float(clock.day) * 16.0 + float(clock.night) * 8.0) / 24.0
	var t := SurvivalUtil.dict(core.data.section("needs", "real_time_targets_woodsman"))
	between(real, float(t.food_full_to_hungry_real_min[0]), float(t.food_full_to_hungry_real_min[1]), "full to Hungry in real minutes")


func test_needs_warmth_winter_night() -> void:
	var core := mk("", {"start_day": "jan_mid", "start_hour": 22.0})
	dress(core, ["item.cloth.hunting_shirt", "item.cloth.matchcoat", "item.cloth.moccasins"])
	core.state.needs["stomach"] = 1500.0  # peckish: the GDD's example has no food term
	core.state.inventory = core.state.inventory.filter(func(st): return str(st.id) != "item.trade.blanket")
	core.set_context({"location": "open.ground", "near": [], "indoors": false, "in_shelter": false, "fire_distance_m": 99.0}, true)
	set_air(core, -15.0)
	var e := SurvivalNeeds.env(core)
	near(float(e.ins_eff), 6.0, 0.001, "poor kit: insulation 6")
	near(float(e.t_eff), -4.2, 0.05, "the GDD's worked example: T_eff -4.2 C")
	var hrs := 0.0
	while SurvivalNeeds.warmth_stage(core) in ["comfortable", "chilled"] and hrs < 10.0:
		set_air(core, -15.0)
		core.state.needs["stomach"] = 1500.0
		core.advance(5.0)
		hrs += 5.0 / 60.0
	between(hrs, 3.2, 3.6, "Cold after about 3.4 game hours")
	var t := SurvivalUtil.dict(core.data.section("needs", "real_time_targets_woodsman"))
	between(hrs * 1.2, float(t.warmth_winter_night_poor_kit_to_cold_real_min[0]), float(t.warmth_winter_night_poor_kit_to_cold_real_min[1]),
			"Cold in 3-5 real minutes at night")
	ok(core.state.conditions.has("cond.cold"), "the Cold condition follows the need")
	# user 2026-09-27: the cold takes nothing from the aim (adrenaline); it only slows the body when very cold
	ok(float(core.get_modifiers().get("aim_tremor", 0.0)) == 0.0, "the cold leaves the aim alone")


func test_needs_fire_and_shelter_warm() -> void:
	var core := mk("", {"start_day": "jan_mid", "start_hour": 20.0})
	core.state.needs["warmth"] = 40.0
	set_air(core, -12.0)
	var fid := SurvivalCamp.create_fire(core, "poi.fort.woods_camp", "lit", 600.0)
	core.set_context({"fire_id": fid, "fire_distance_m": 1.5})
	var e := SurvivalNeeds.env(core)
	ok(float(e.fire_c) > 15.0, "a fire 1.5 m away adds its heat (%.1f C)" % float(e.fire_c))
	core.advance(60.0)
	ok(float(core.state.needs.warmth) > 60.0, "warming by the fire (%.1f)" % float(core.state.needs.warmth))
	var sid := SurvivalCamp.create_shelter(core, "poi.fort.woods_camp", "brush_leanto", 2.0)
	core.set_context({"shelter_id": sid, "in_shelter": true})
	ok(float(SurvivalNeeds.env(core).shelter_c) > 2.9, "a lean-to of quality 2 adds 3 C")


func test_fatigue_and_sleep() -> void:
	var core := mk("", {"start_hour": 7.0})
	core.state.needs["fatigue"] = 0.0
	core.set_activity("walk")
	core.advance(18.5 * 60.0)
	ok(SurvivalNeeds.rest_stage(core) == "tired", "18 waking hours make you Tired (%s, %.1f)" % [SurvivalNeeds.rest_stage(core), float(core.state.needs.fatigue)])
	var f0 := float(core.state.needs.fatigue)
	core.state.needs["stomach"] = 2600.0
	core.go_to("poi.fort.sutler_store")
	var r := core.run_job("rest.sleep", {"hours": 4.0})
	ok(bool(r.get("ok", false)), "slept indoors: %s" % str(r))
	ok(float(core.state.needs.fatigue) < f0 - 30.0, "sleep recovers fatigue (%.1f -> %.1f)" % [f0, float(core.state.needs.fatigue)])
	ok(not core.state.asleep, "awake after the sleep job")


# ---------------------------------------------------------------- conditions and modifiers
func test_modifier_contract() -> void:
	var core := mk()
	var m := core.get_modifiers()
	for k in core.data.modifier_keys.keys():
		ok(m.has(k), "contract key %s present" % k)
	near(float(m.aim_sway_mult), 1.0, 0.0001, "healthy: aim sway x1")
	near(float(m.move_speed_mult), 1.0, 0.0001, "healthy: full speed")
	ok(bool(m.sprint_allowed), "healthy: sprint allowed")
	# Stacking: only the three strongest penalties on a key apply.
	var srcs := [{"src": "a", "effects": {"warmth_loss_mult": 1.1}}, {"src": "b", "effects": {"warmth_loss_mult": 1.3}},
			{"src": "c", "effects": {"warmth_loss_mult": 1.2}}, {"src": "d", "effects": {"warmth_loss_mult": 1.25}}]
	near(float(SurvivalConditions.combine(core, srcs).warmth_loss_mult), 1.3 * 1.25 * 1.2, 0.0001, "the weakest fourth penalty is dropped")
	var big := [{"src": "a", "effects": {"aim_sway_mult": 2.0}}, {"src": "b", "effects": {"aim_sway_mult": 2.0}}]
	near(float(SurvivalConditions.combine(core, big).aim_sway_mult), 2.5, 0.0001, "clamped to the contract's bounds")


func test_drink_no_buff() -> void:
	var core := mk("", {"start_hour": 20.0})
	core.state.needs["fatigue"] = 95.0
	core.advance(10.0)
	var sway_tired := float(core.get_modifiers().aim_sway_mult)
	var r := core.run_job("drink.item")
	ok(bool(r.get("ok", false)), "a dram")
	ok(SurvivalConditions.stage_of(core, "cond.drunk") == "merry", "one gill: merry (%s)" % SurvivalConditions.stage_of(core, "cond.drunk"))
	var m := core.get_modifiers()
	ok(float(m.warmth_loss_mult) > 1.0, "drink costs warmth")
	ok(float(m.check_mod) < 0.0, "drink costs steadiness at work")
	ok(SurvivalUtil.arr(m.tell_mask).has("cond.fatigue"), "the fatigue icon is masked")
	ok(float(m.aim_sway_mult) >= sway_tired - 0.0001, "but fatigue's penalty stays (%.2f >= %.2f)" % [float(m.aim_sway_mult), sway_tired])
	ok(SurvivalUtil.arr(m.hud_tags).has("feels_warm"), "the HUD shows a 'you feel warm' tag")
	var shown := false
	for ic in core.icons():
		if str(ic.id) == "cond.fatigue":
			shown = true
	ok(not shown, "the masked icon is hidden")
	ok(SurvivalNeeds.warmth_stage(core) != "", "the true warmth stage is always available")


func test_drink_senseless_pass_out_and_hangover() -> void:
	var core := mk("", {"start_day": "oct_mid", "start_hour": 19.0})
	core.go_to("poi.fort.sutler_store")
	SurvivalInventory.add(core, "item.drink.rum", 1.0)
	for i in 5:
		SurvivalFood.drink(core)
	ok(core.is_passed_out(), "four or five gills: senseless, passed out")
	ok(core.state.asleep, "asleep while senseless")
	core.advance(8.0 * 60.0)
	ok(not core.is_passed_out(), "came to")
	# the drink wears off at 6 an hour now (a gill 25: user 2026-09-27, Vices), so the morning after comes later
	core.advance(10.0 * 60.0)
	ok(core.state.conditions.has("cond.queasy") or int(SurvivalUtil.num(core.state.stats.get("cond_cond.queasy"), 0.0)) > 0, "the morning after: queasy")
	var c2 := mk("", {"start_day": "oct_mid", "start_hour": 19.0})
	c2.go_to("poi.fort.sutler_store")
	SurvivalInventory.add(c2, "item.drink.rum", 1.0)
	for i in 5:
		SurvivalFood.drink(c2)
	c2.report_threat(40.0)
	c2.advance(10.0)
	ok(not c2.is_passed_out() and c2.state.flags.has("groggy_until"), "a threat wakes the senseless player, groggy")
	ok(float(c2.get_modifiers().check_mod) <= -0.2, "groggy: checks -0.2")


func test_cut_bleeding_and_bind() -> void:
	var core := mk()
	SurvivalConditions.add(core, "cond.injury.cut", {"zone": "hand"})
	ok(SurvivalConditions.stage_of(core, "cond.injury.cut") == "bleeding", "a fresh cut bleeds")
	near(float(core.get_modifiers().health_drain_per_hour), 3.0, 0.001, "bleeding drains 3 health an hour")
	ok(float(core.get_modifiers().fine_work_mod) <= -0.2, "a hand cut: fine work -0.2")
	var h0 := core.health()
	core.advance(60.0)
	ok(core.health() < h0 - 2.0, "health falls while bleeding")
	var n0 := SurvivalInventory.count(core, "item.remedy.bandage")
	var pv := core.preview("physick.bind_wound")
	ok(bool(pv.ok) and str(pv.risk_line).contains("bandage"), "the prompt lists the bandage at risk: %s" % str(pv.risk_line))
	var tries := 0
	while SurvivalConditions.stage_of(core, "cond.injury.cut") == "bleeding" and tries < 3:
		core.run_job("physick.bind_wound")
		tries += 1
		if SurvivalInventory.count(core, "item.remedy.bandage") < 1.0:
			SurvivalInventory.add(core, "item.remedy.bandage", 1.0)
	ok(SurvivalConditions.stage_of(core, "cond.injury.cut") == "bound", "bound")
	ok(SurvivalInventory.count(core, "item.remedy.bandage") < n0 + tries, "bandages used")
	SurvivalConditions.add(core, "cond.injury.crushed_fingers")
	SurvivalConditions.bind(core)
	near(float(core.state.conditions["cond.injury.crushed_fingers"].heal_mult), 1.5, 0.001, "bound fingers heal x1.5 off the line")


func test_death_by_cold() -> void:
	var core := mk("", {"start_day": "jan_mid", "start_hour": 20.0})
	dress(core, ["item.cloth.linen_shirt"])
	core.state.inventory = core.state.inventory.filter(func(st): return core.data.item_cat(str(st.id)) != "clothing" or str(st.id) == "item.cloth.linen_shirt")
	core.state.inventory = core.state.inventory.filter(func(st): return str(st.id) != "item.trade.blanket")
	core.set_context({"location": "open.ground", "near": [], "indoors": false, "in_shelter": false}, true)
	var died := []
	core.died.connect(func(c): died.append(c))
	for i in 96:
		set_air(core, -20.0)
		core.advance(30.0)
		if core.is_dead():
			break
	ok(core.is_dead(), "freezing drains health until death")
	ok(died.size() == 1 and str(died[0]) == "cold", "died of cold (%s)" % str(died))
	ok(core.advance(60.0) == 0.0, "time stops for the dead")


# ---------------------------------------------------------------- skills
func test_skill_check_and_roll() -> void:
	var core := mk()
	near(SurvivalSkills.chance(core, 40.0, 40.0, 0.0), 0.55, 0.0001, "S = D: 55%")
	near(SurvivalSkills.chance(core, 0.0, 100.0, 0.0), 0.05, 0.0001, "floor 5%")
	near(SurvivalSkills.chance(core, 100.0, 0.0, 0.0), 0.97, 0.0001, "cap 97%")
	near(SurvivalSkills.chance(core, 32.0, 20.0, -0.1), 0.65, 0.0001, "the GDD's worked example with -0.1")
	var counts := {"excellent": 0, "success": 0, "partial": 0, "failure": 0, "mishap": 0}
	for i in 20000:
		counts[SurvivalSkills.roll(core, 0.6, true)] += 1
	near(float(counts.excellent) / 20000.0, 0.06, 0.01, "excellent = 0.1 p")
	near(float(counts.excellent + counts.success) / 20000.0, 0.6, 0.015, "success at p")
	near(float(counts.partial) / 20000.0, 0.2, 0.015, "partial band 0.2")
	near(float(counts.mishap) / 20000.0, 0.03, 0.006, "mishap above 0.97 on hazards")


func test_skill_growth_rules() -> void:
	var core := mk()
	# Growth v4 (skills.json growth_model, redesign_skills.md 4): gain = k * base_xp * C(p) * O * L(S) * R(n).
	near(SurvivalSkills.repeat_factor(core, 1), 1.0, 0.0001, "R(1) = 1")
	near(SurvivalSkills.repeat_factor(core, 4) / SurvivalSkills.repeat_factor(core, 3), 0.8333, 0.001, "R(4)/R(3) = 0.5/0.6")
	ok(SurvivalSkills.repeat_factor(core, 10) > 0.0, "a repeated action keeps teaching a little (no hard stop)")
	near(SurvivalSkills.challenge(core, 0.55), 1.0, 0.0001, "C = 1 at a 55% task")
	near(SurvivalSkills.challenge(core, 0.97), 0.15, 0.0001, "easy work: C at its 0.15 floor")
	near(SurvivalSkills.challenge(core, 0.05), 0.3, 0.0001, "hopeless work teaches less (1.5 x 0.05/0.25)")
	near(SurvivalSkills.level_factor(core, 0.0), 1.0, 0.0001, "L(0) = 1")
	near(SurvivalSkills.level_factor(core, 45.0, "provisions"), 0.5, 0.0001, "L(45) = 0.5 for a skill that is not a calling")
	var a := core.data.action("trap.deadfall_set")
	var f1 := mk()
	var g1 := SurvivalSkills.gain_from_check(f1, a, 30.0, "success", 0.0, 0.5)
	var g2 := SurvivalSkills.gain_from_check(f1, a, 30.0, "success", 0.0, 0.5)
	ok(g1 > g2 * 1.2, "the first success teaches the most, once (%.3f then %.3f)" % [g1, g2])
	# Impairments (drink, hunger, hurry) never add challenge: only the task's own modifiers count.
	var i1 := mk()
	var i2 := mk()
	var gi := SurvivalSkills.gain_from_check(i1, a, 30.0, "failure", -0.3, 0.3, 0.0)
	var gt := SurvivalSkills.gain_from_check(i2, a, 30.0, "failure", 0.0, 0.6, 0.0)
	near(gi, gt, 0.0001, "a drunk failure teaches what a sober one does")
	var none := mk()
	ok(SurvivalSkills.gain_from_check(none, none.data.action("eat"), 0.0, "success", 0.0, 1.0) == 0.0, "no experience from eating")
	var triv := mk()
	SurvivalSkills.set_level(triv, "survival", 60.0)
	ok(SurvivalSkills.gain_from_check(triv, triv.data.action("fire.bank"), 10.0, "success", 0.0, 0.97) == 0.0, "no gain 35 or more below the level")
	# The daily caps: 5 a skill, 10 across the working skills.
	var capc := mk()
	for id in ["trap.deadfall_set", "craft.stakes", "fire.strike_flint_steel", "shelter.brush_leanto", "trap.check", "fire.nurse",
			"fire.bank", "physick.bind_wound", "hunt.track", "butcher.field_dress", "wood.split_firewood", "cook.roast", "fur.stretch"]:
		for i in 8:
			SurvivalSkills.gain_from_check(capc, capc.data.action(id), 50.0, "success", 0.0, 0.3)
	ok(SurvivalSkills.xp_today(capc, "survival") <= 5.0001, "at most 5 points a skill a day (%.2f)" % SurvivalSkills.xp_today(capc, "survival"))
	near(SurvivalSkills.total_today(capc), 10.0, 0.0001, "at most 10 points a day across the working skills")
	# Weapon skills grow from use only.
	var w := mk()
	var m0 := SurvivalSkills.level(w, "marksmanship")
	w.report_weapon_event("marksmanship", "hit_beyond_30m")
	near(SurvivalSkills.level(w, "marksmanship") - m0, 0.05, 0.0001, "a hit beyond 30 m: +0.05 Marksmanship")
	var hand := w.get_weapon_modifiers("musket")
	ok(float(hand.reload_speed_mult) > 1.0 and float(hand.reload_speed_mult) < 1.03, "Marksmanship 15 reloads a little faster (%.3f)" % float(hand.reload_speed_mult))
	SurvivalSkills.set_level(w, "marksmanship", 100.0)
	near(float(w.get_weapon_modifiers("musket").reload_speed_mult), 1.15, 0.0001, "handling capped at the skill's at_100")
	var zero := mk()
	SurvivalSkills.set_level(zero, "archery", 0.0)
	near(float(zero.get_weapon_modifiers("bow").draw_speed_mult), 1.0, 0.0001, "level 0 is today's feel")
	# No background multiplier: at the same level, the hunter and the ranger learn Hunting at the same rate.
	var hb := mk("bg.backcountry_hunter")
	var pb := mk("bg.provincial_ranger")
	SurvivalSkills.set_level(hb, "hunting", 30.0)
	SurvivalSkills.set_level(pb, "hunting", 30.0)
	var gh := SurvivalSkills.gain_from_check(hb, hb.data.action("hunt.track"), 30.0, "success", -0.1, 0.5)
	var gp := SurvivalSkills.gain_from_check(pb, pb.data.action("hunt.track"), 30.0, "success", -0.1, 0.5)
	near(gh, gp, 0.0001, "a background is a head start, never a faster rate")
func test_backgrounds_differ() -> void:
	var h := mk("bg.backcountry_hunter")
	var p := mk("bg.provincial_ranger")
	ok(SurvivalSkills.level(h, "survival") == 32.0 and SurvivalSkills.level(p, "survival") == 25.0, "starting Survival 32 vs 25")
	ok(SurvivalSkills.level(p, "marksmanship") > SurvivalSkills.level(h, "marksmanship"), "the veteran shoots better")
	# v4: the Clear start (the default) owes no one; the old debts are start variants.
	ok(str(h.state.settings.start_variant) == "start.clear" and str(p.state.settings.start_variant) == "start.clear", "Clear is the default start")
	ok(SurvivalEconomy.balance(h, SurvivalEconomy.TRADER_ID) == 0.0 and SurvivalEconomy.balance(p, SurvivalEconomy.SUTLER_ID) == 0.0, "the Clear start owes no one")
	var hc := mk("bg.backcountry_hunter", {"start_variant": "start.outfitted_on_credit"})
	ok(SurvivalEconomy.balance(hc, SurvivalEconomy.TRADER_ID) == 715.0, "Outfitted on credit: 715 barter d on the trader's book (%.0f)" % SurvivalEconomy.balance(hc, SurvivalEconomy.TRADER_ID))
	ok(SurvivalInventory.count(hc, "item.trap.steel") == SurvivalInventory.count(h, "item.trap.steel") + 2.0, "and two more steel traps")
	var pc := mk("bg.provincial_ranger", {"start_variant": "start.sutler_tally"})
	ok(SurvivalEconomy.balance(pc, SurvivalEconomy.SUTLER_ID) == 288.0, "On the sutler's tally: 288 d")
	var wrong := mk("bg.provincial_ranger", {"start_variant": "start.outfitted_on_credit"})
	ok(str(wrong.state.settings.start_variant) == "start.clear", "a variant not offered to the background falls back to Clear")
	ok(SurvivalUtil.arr(p.state.economy.obligations).size() == 1, "the provincial answers the militia muster")
	ok(SurvivalInventory.has(h, "item.trap.steel", 2.0) and not SurvivalInventory.has(p, "item.trap.steel"), "different kit")
	ok(bool(p.state.context.indoors), "the provincial starts at the sutler's store")
	# Head starts: knowledge and people, never locks.
	ok(SurvivalLearning.state_of(h, "know.hide_dressing") == "known" and SurvivalLearning.state_of(p, "know.hide_dressing") == "seen", "the hunter knows hide dressing; the ranger has seen it done")
	ok(SurvivalLearning.state_of(p, "shelter.half_faced_camp") == "known" and SurvivalLearning.state_of(h, "shelter.half_faced_camp") == "heard_of", "the ranger knows the half-faced camp")
	ok(SurvivalTrade.trust(h, "npc.woods.old_hunter") > 0.0, "the hunter knows the old hunter")
	# Habits (the old perks, earned by anyone by doing): the provincial raises a lean-to 25% faster; the hunter walks
	# the line 20% faster.
	ok(h.has_habit("habit.line_hand") and p.has_habit("habit.cold_camp"), "each background starts with its habit")
	var a := h.data.action("shelter.brush_leanto")
	var th := SurvivalJobs.work_minutes(h, a, 25.0, 15.0, false, {}, {})
	var tp := SurvivalJobs.work_minutes(p, a, 25.0, 15.0, false, {}, {})
	near(tp, th * 0.75, 0.001, "habit.cold_camp: lean-to x0.75")
	near(float(h.perk_effect("trap_walk_time_mult", 1.0)), 0.8, 0.0001, "habit.line_hand: line walking x0.8")
	for i in 150:
		p.count_habit("line_checks")
	ok(p.has_habit("habit.line_hand"), "150 line checks earn the line hand's habit for anyone")


# ---------------------------------------------------------------- inventory and crafting
func test_inventory() -> void:
	var core := mk()
	var n0 := core.state.inventory.size()
	SurvivalInventory.add(core, "item.pelt.marten", 1.0, {"grade": "good", "prime": 1.0})
	SurvivalInventory.add(core, "item.pelt.marten", 1.0, {"grade": "good", "prime": 1.0})
	SurvivalInventory.add(core, "item.pelt.marten", 1.0, {"grade": "poor", "prime": 1.0})
	ok(core.state.inventory.size() == n0 + 2, "stacks merge by grade")
	SurvivalInventory.add(core, "item.food.venison_raw", 10.0, {"spoil": 0.2})
	SurvivalInventory.add(core, "item.food.venison_raw", 10.0, {"spoil": 0.6})
	near(float(SurvivalInventory.stacks_of(core, "item.food.venison_raw")[0].meta.spoil), 0.4, 0.0001, "spoilage averages by quantity")
	var kit := SurvivalInventory.weight_kg(mk())
	ok(kit > 10.0 and kit < 30.0, "the starting kit's load (%.1f kg)" % kit)
	near(SurvivalInventory.meals(core) - SurvivalInventory.meals(mk()), 20.0 * 110.0 / 800.0, 0.01, "food shows in meals")
	SurvivalInventory.remove(core, "item.food.venison_raw", 20.0)
	SurvivalInventory.add(core, "item.fuel.split_wood", 2.0)
	ok(SurvivalInventory.load_stage(core) == "heavy", "20 kg of wood makes a heavy load (%s, %.1f kg)" % [SurvivalInventory.load_stage(core), SurvivalInventory.weight_kg(core)])
	ok(float(core.get_modifiers().move_speed_mult) < 1.0, "a heavy load slows you")
	ok(SurvivalInventory.has_any(core, ["item.tool.hatchet"]) != "", "tools found")
	SurvivalInventory.add(core, "item.weapon.tomahawk", 1.0)
	SurvivalInventory.remove(core, "item.tool.hatchet", 1.0)
	ok(SurvivalInventory.has_any(core, ["item.tool.hatchet"]) == "item.weapon.tomahawk", "a tomahawk serves as a hatchet")


func test_spoilage_and_drying() -> void:
	var core := mk("", {"start_day": "jul_mid"})
	core.set_context({"indoors": true})
	SurvivalInventory.add(core, "item.food.venison_raw", 5.0)
	core.advance(30.0 * 60.0)
	ok(bool(SurvivalInventory.stacks_of(core, "item.food.venison_raw")[0].meta.get("spoiled", false)), "fresh meat spoils in a warm day")
	var w := mk("", {"start_day": "jan_mid"})
	set_air(w, -12.0)
	SurvivalInventory.add(w, "item.food.venison_raw", 5.0)
	w.advance(48.0 * 60.0)
	ok(not bool(SurvivalInventory.stacks_of(w, "item.food.venison_raw")[0].meta.get("spoiled", false)), "frozen meat keeps")
	var d := mk("", {"start_day": "dec_mid"})
	d.go_to("poi.fort.sutler_store")
	SurvivalInventory.add(d, "item.pelt.marten", 1.0, {"grade": "good", "green": true, "stretched": true, "dry_h": 0.0, "dry_need_h": 60.0})
	d.advance(61.0 * 60.0)
	var st: Dictionary = SurvivalInventory.stacks_of(d, "item.pelt.marten")[0]
	ok(bool(st.meta.get("dried", false)) and not st.meta.has("green"), "a stretched pelt dries in 2-3 game days")


func test_crafting_stakes() -> void:
	var core := mk()
	var got := 0.0
	for i in 6:
		var r := core.run_job("craft.stakes")
		ok(r.has("outcome"), "craft.stakes runs: %s" % str(r.get("reason", "")))
		got = SurvivalInventory.count(core, "item.trap.stake_set")
	ok(got >= 3.0, "stake sets made (%.0f)" % got)
	var cp := SurvivalInventory.count(core, "item.trap.stake_set", {"quality": "usable"})
	ok(cp <= got, "usable stakes are tracked apart from good ones")
	ok(SurvivalCrafting.available(core).has("rcp.stake_set"), "the recipe is available with a knife")


# ---------------------------------------------------------------- jobs
func test_job_fire_chain() -> void:
	var core := mk("", {"start_day": "oct_mid", "start_hour": 16.0})
	set_air(core, 5.0)
	ok(not bool(core.preview("fire.strike_flint_steel").ok), "no kindling yet: cannot strike")
	var g := core.run_job("fire.gather")
	ok(bool(g.ok) and not SurvivalUtil.dict(g.gained).is_empty(), "gathering gives tinder, kindling and a bundle: %s" % str(g.gained))
	var cloth0 := SurvivalInventory.count(core, "item.tinder.charcloth")
	var kind0 := SurvivalInventory.count(core, "item.fuel.kindling")
	var lit := false
	for i in 6:
		if SurvivalInventory.count(core, "item.fuel.kindling") < 1.0:
			core.run_job("fire.gather")
		var r := core.run_job("fire.strike_flint_steel")
		var f := SurvivalCamp.current_fire(core)
		if not f.is_empty() and str(f.state) == "lit":
			lit = true
			break
		if not f.is_empty() and str(f.state) == "smouldering" and bool(f.coal_only):
			core.run_job("fire.nurse")
	ok(lit, "a fire is lit")
	ok(SurvivalInventory.count(core, "item.tinder.charcloth") < cloth0, "char cloth used")
	var fuel0 := SurvivalCamp.fuel_hours(core, str(SurvivalCamp.current_fire(core).id))
	var t := core.run_job("fire.tend", {"fuel": "item.fuel.bundle"})
	ok(bool(t.ok), "tended")
	near(SurvivalCamp.fuel_hours(core, str(SurvivalCamp.current_fire(core).id)) - fuel0, 1.0, 0.1, "a bundle adds an hour")
	core.set_context({"fire_distance_m": 1.5})
	var b := core.run_job("fire.bank")
	var f2 := SurvivalCamp.current_fire(core)
	ok(str(f2.state) == "banked" or str(b.outcome) == "failure", "banked (%s, %s)" % [str(f2.state), str(b.outcome)])


func test_job_prompt_preview() -> void:
	var core := mk("", {"start_day": "jan_mid", "start_hour": 7.0})
	SurvivalInventory.add(core, "item.fuel.kindling", 2.0)
	core.state.weather["state"] = "snow"
	core.state.needs["warmth"] = 35.0
	core.invalidate_modifiers()
	var pv := core.preview("fire.strike_flint_steel")
	ok(bool(pv.ok), "can strike: %s" % str(pv.reasons))
	ok(float(pv.D) == 20.0, "char cloth: D 20")
	var labels := PackedStringArray()
	for f in pv.factors:
		labels.append(str(f.label))
	ok(labels.has("snow") and labels.has("cold hands"), "snow and cold hands shown: %s" % str(labels))
	near(float(pv.chance), 0.55 + 12.0 / 60.0 - 0.1 - 0.1, 0.0001, "0.75 - snow - cold hands = 0.55 (the GDD's example)")
	ok(str(pv.prompt).begins_with("[E] Strike a fire (flint and steel) · 55%"), "prompt text: %s" % str(pv.prompt))
	ok(str(pv.prompt).contains("Hint:"), "a hint the player can act on")
	ok(str(pv.risk_line).contains("char cloth") and str(pv.risk_line).contains("kindling"), "materials at risk: %s" % str(pv.risk_line))
	var hp := core.preview("shelter.brush_leanto", {"hurry": true})
	var np := core.preview("shelter.brush_leanto")
	near(float(np.chance) - float(hp.chance), 0.05, 0.0001, "hurry: -0.05 on the check")
	near(float(hp.time_min) / float(np.time_min), 0.6, 0.001, "hurry: x0.6 time")


func test_job_interrupt_keeps_progress() -> void:
	var core := mk("", {"start_hour": 9.0})
	var r := core.start_job("shelter.brush_leanto")
	ok(bool(r.ok), "lean-to started")
	var dur := float(r.job.duration_min)
	var outcome := str(r.job.outcome)
	core.advance(15.0)
	core.cancel_job("moved")
	ok(not SurvivalJobs.is_running(core), "moving cancels")
	var kept := SurvivalUtil.dict(core.state.jobs.progress)
	ok(kept.size() == 1, "progress kept")
	var r2 := core.start_job("shelter.brush_leanto")
	ok(bool(r2.get("job", {}).get("resumed", false)), "resumed")
	near(SurvivalJobs.minutes_left(core), dur - 15.0, 0.01, "only the rest of the work remains")
	ok(str(r2.job.outcome) == outcome, "a cancel cannot re-roll the outcome")
	core.advance(dur)
	ok(not SurvivalJobs.is_running(core), "finished")
	# Eating loses progress when you move.
	var e := core.start_job("eat")
	ok(bool(e.ok), "eating started")
	core.advance(1.0)
	core.cancel_job("moved")
	ok(not SurvivalUtil.dict(core.state.jobs.progress).has(str(e.job.key)), "a cancelled meal is not kept")


## A job that would resume says so in its prompt; progress nobody comes back for is dropped from the save.
func test_job_preview_resume_and_stale_progress() -> void:
	var core := mk("", {"start_hour": 9.0})
	var r := core.start_job("shelter.brush_leanto")
	var dur := float(r.job.duration_min)
	core.advance(15.0)
	core.cancel_job("moved")
	var pv := core.preview("shelter.brush_leanto")
	ok(bool(pv.resumes), "the prompt says the lean-to resumes")
	near(float(pv.time_min), dur - 15.0, 0.01, "with the time left")
	near(float(pv.chance), float(r.job.p), 0.0001, "and the chance it already rolled")
	ok(str(pv.prompt).contains("resume"), "prompt: %s" % str(pv.prompt))
	live(core, 1500.0)
	var pv2 := core.preview("shelter.brush_leanto")
	ok(bool(pv2.ok) and not bool(pv2.resumes), "a day later it would start afresh: %s" % str(pv2.reasons))
	core.start_job("craft.stakes")
	core.advance(3.0)
	core.cancel_job("moved")
	var keys := SurvivalUtil.dict(core.state.jobs.progress).keys()
	ok(keys.size() == 1 and str(keys[0]).begins_with("craft.stakes"), "stale progress is pruned: %s" % str(keys))


## A finishing job checks that its materials and targets are still there, not the gates it started under: spearing
## fish by torchlight that runs past sunrise still lands its fish.
func test_job_completion_keeps_start_gates() -> void:
	var core := SurvivalCore.new_game("", {"seed": 14, "start_day": "jul_mid", "start_hour": 2.0, "backlog_milestones": ["M3"]})
	core.set_context({"location": "river", "near": ["node.fish_water"], "indoors": false, "in_shelter": false}, true)
	SurvivalInventory.add(core, "item.tool.torch", 1.0)
	SurvivalInventory.add(core, "item.tool.gig", 1.0)
	core.state.minutes += (SurvivalClock.sunrise_h(core) - 0.3 - SurvivalClock.hour(core)) * 60.0
	set_air(core, 16.0)
	sustain(core)
	core.state.needs["stomach"] = 2900.0
	var pv := core.preview("fish.spear_torch")
	ok(bool(pv.ok), "spearing by torchlight is open before dawn: %s" % str(pv.reasons))
	var r := core.run_job("fish.spear_torch")
	ok(r.has("outcome") and not r.has("interrupted"), "a night job that runs past sunrise still finishes: %s" % str(r))
	ok(not SurvivalClock.is_night(core), "it ended after sunrise (%s)" % SurvivalClock.time_string(core))
	ok(not bool(core.preview("fish.spear_torch").ok), "a new one cannot start by day")


## The sleep autosave comes once the waking step is whole, and never for a character who died in the night.
func test_autosave_after_sleep_not_on_death() -> void:
	var core := mk("", {"start_hour": 21.0})
	var fid := SurvivalCamp.create_fire(core, "poi.fort.woods_camp", "lit", 900.0)
	core.set_context({"fire_id": fid, "fire_distance_m": 1.5})
	var seen := []
	# The listener reads the core, so it is disconnected afterwards (a lambda holding the core it listens to would keep
	# the core alive: a reference cycle).
	var on_save := func(why): seen.append([why,
			str(SurvivalUtil.dict(core.state.jobs.get("last_result")).get("action", "")), SurvivalJobs.is_running(core)])
	core.autosave_requested.connect(on_save)
	core.run_job("rest.sleep", {"hours": 2.0})
	core.autosave_requested.disconnect(on_save)
	ok(seen.size() == 1 and seen[0][1] == "rest.sleep" and not bool(seen[0][2]),
			"one autosave after sleep, with the sleep's result already recorded: %s" % str(seen))
	var c := mk("", {"start_day": "jan_mid", "start_hour": 22.0})
	c.set_context({"location": "open.ground", "near": [], "indoors": false, "in_shelter": false}, true)
	set_air(c, -25.0)
	dress(c, [])
	c.state.needs["warmth"] = 0.0
	c.state.needs["health"] = 0.5
	SurvivalConditions.update_driven(c)
	var saves := []
	var died := []
	c.autosave_requested.connect(func(why): saves.append(why))
	c.died.connect(func(cause): died.append(cause))
	c.start_job("rest.sleep", {"hours": 8.0})
	c.advance(60.0)
	ok(c.is_dead() and died.size() == 1, "froze to death asleep (%s)" % str(died))
	ok(saves.is_empty(), "no autosave of a dead character: %s" % str(saves))


## A dead fire's record (the cold hearth the world shows) stays three game days after it went out.
func test_fire_record_after_going_out() -> void:
	var core := mk("", {"start_hour": 9.0})
	var fid := SurvivalCamp.create_fire(core, "poi.fort.woods_camp", "lit", 5.0)
	SurvivalCamp.fire(core, fid)["created"] = core.state.minutes - 10.0 * 1440.0
	live(core, 120.0)
	ok(str(SurvivalCamp.fire(core, fid).get("state", "")) == "out", "burnt out and cold")
	live(core, 1440.0)
	ok(not SurvivalCamp.fire(core, fid).is_empty(), "the record stays a day after (lit ten days ago)")
	live(core, 3.0 * 1440.0)
	ok(SurvivalCamp.fire(core, fid).is_empty(), "and is gone after three")


func test_job_threat_and_wake_rules() -> void:
	var core := mk("", {"start_hour": 10.0})
	core.start_job("shelter.brush_leanto")
	core.advance(5.0)
	core.report_threat(40.0)
	ok(SurvivalJobs.is_running(core), "a threat at 40 m does not stop work")
	core.report_threat(20.0)
	ok(not SurvivalJobs.is_running(core), "a threat within 25 m stops the job")
	core.clear_threat()
	var woke := []
	core.woke.connect(func(why): woke.append(why))
	core.start_job("rest.sleep", {"hours": 6.0})
	core.advance(30.0)
	core.report_threat(55.0)
	ok(not core.state.asleep and woke.size() == 1, "a threat within 60 m wakes a sleeper: %s" % str(woke))
	core.clear_threat()
	# A winter night with no fire: the sleeper wakes as the cold worsens instead of dying in his sleep.
	var c := mk("", {"start_day": "jan_mid", "start_hour": 21.0})
	dress(c, ["item.cloth.linen_shirt", "item.cloth.moccasins"])
	c.state.inventory = c.state.inventory.filter(func(st): return str(st.id) != "item.cloth.matchcoat")
	c.set_context({"location": "open.ground", "near": [], "indoors": false, "in_shelter": false}, true)
	set_air(c, -18.0)
	var r := c.run_job("rest.sleep", {"hours": 10.0})
	ok(r.has("interrupted") and str(r.interrupted).begins_with("warmth"), "woke because the cold worsened: %s" % str(r))
	ok(c.health() > 90.0 and not c.is_dead(), "time safety: no death without a decision")


func test_job_sleep_with_fire_watch() -> void:
	var core := mk("", {"start_day": "dec_mid", "start_hour": 21.0})
	var fid := SurvivalCamp.create_fire(core, "poi.fort.woods_camp", "lit", 30.0)
	core.set_context({"fire_id": fid, "fire_distance_m": 1.5})
	var r := core.run_job("rest.sleep", {"hours": 8.0})
	ok(r.has("interrupted") and str(r.interrupted).begins_with("the fire"), "woke as the fire burned down: %s" % str(r.get("interrupted", r)))
	var c2 := mk("", {"start_day": "dec_mid", "start_hour": 21.0})
	var fid2 := SurvivalCamp.create_fire(c2, "poi.fort.woods_camp", "lit", 30.0)
	c2.set_context({"fire_id": fid2, "fire_distance_m": 1.5})
	SurvivalInventory.add(c2, "item.fuel.split_wood", 5.0)
	SurvivalCamp.stack_fuel(c2, fid2, "item.fuel.split_wood", 5.0)
	ok(SurvivalCamp.fuel_hours(c2, fid2) >= 10.0, "a stack of split wood feeds the fire for the night (%.1f h)" % SurvivalCamp.fuel_hours(c2, fid2))
	# and does: its wood ends on a 10-minute step (30 minutes) and the next stick catches (it smouldered, and woke the
	# sleeper, before)
	var r2 := c2.run_job("rest.sleep", {"hours": 8.0})
	ok(not str(r2.get("interrupted", "")).begins_with("the fire") and str(SurvivalCamp.fire(c2, fid2).get("state", "")) == "lit",
			"the sleeper is not woken by the fire, which burns on from its stack (%s, %s)" % [str(r2.get("interrupted", "slept")), SurvivalCamp.fire(c2, fid2).get("state", "")])
	var fc := SurvivalNeeds.forecast_sleep(c2, 8.0)
	ok(fc.has("stage_end") and fc.has("fuel_hours") and fc.has("meals"), "the sleep dialog's forecast")


func test_job_hurry_mishaps() -> void:
	var core := mk()
	var n := 0
	var mishaps := {"hurry": 0, "calm": 0}
	for i in 4000:
		if SurvivalSkills.roll(core, 0.5, true, true) == "mishap":
			mishaps.hurry += 1
		if SurvivalSkills.roll(core, 0.5, true, false) == "mishap":
			mishaps.calm += 1
	near(float(mishaps.hurry) / float(maxi(1, mishaps.calm)), 2.0, 0.45, "hurry doubles mishaps (%d vs %d)" % [mishaps.hurry, mishaps.calm])


func test_cook_eat_and_plain_fare() -> void:
	var core := mk("", {"start_day": "nov_mid", "start_hour": 12.0})
	var fid := SurvivalCamp.create_fire(core, "poi.fort.woods_camp", "lit", 600.0)
	core.set_context({"fire_id": fid})
	SurvivalInventory.add(core, "item.food.venison_raw", 10.0)
	var r := core.run_job("cook.roast", {"item": "item.food.venison_raw", "qty": 5.0})
	ok(r.has("cooked"), "roasting: %s" % str(r))
	if str(r.outcome) != "failure":
		ok(SurvivalInventory.has(core, "item.food.venison_cooked"), "roast venison made")
	var k_in := 5.0 * 110.0
	var k_out := 0.0
	for st in SurvivalInventory.stacks_of(core, "item.food.venison_cooked"):
		k_out += SurvivalInventory.stack_kcal(core, st)
	if str(r.outcome) == "excellent" or str(r.outcome) == "success":
		near(k_out, k_in, 1.0, "cooking conserves the energy")
	core.state.needs["stomach"] = 500.0
	var e := core.run_job("eat", {"item": "item.food.venison_cooked"})
	ok(bool(e.ok) and float(e.eat.kcal) > 0.0, "ate: %s" % str(e.get("eat")))
	ok(float(core.state.needs.stomach) > 500.0 or bool(e.eat.vomited), "stomach filled")
	var pf := mk()
	pf.state.diet_log = [{"day": SurvivalClock.abs_day(pf), "grain": 4000.0, "meat": 0.0, "other": 0.0}]
	ok(SurvivalFood.plain_fare(pf), "cornmeal alone is plain fare")
	pf.state.diet_log = [{"day": SurvivalClock.abs_day(pf), "grain": 2400.0, "meat": 1600.0, "other": 0.0}]
	ok(not SurvivalFood.plain_fare(pf), "a mixed diet is not")
	ok(not SurvivalFood.edible(pf, "item.food.cornmeal"), "cornmeal must be cooked first")


# ---------------------------------------------------------------- trapping and hunting
func test_trap_line() -> void:
	var core := mk("", {"start_day": "dec_early", "start_hour": 9.0})
	core.set_context({"location": "line.cell.3", "near": ["node.trail", "node.sapling_stand"], "cell": 3, "indoors": false, "in_shelter": false}, true)
	for i in 4:
		core.run_job("craft.stakes")
	var set := 0
	for i in 6:
		var kind := "trap.steel_land_set" if SurvivalInventory.has(core, "item.trap.steel") else "trap.deadfall_set"
		if kind == "trap.deadfall_set" and not SurvivalInventory.has(core, "item.trap.stake_set"):
			break
		var r := core.run_job(kind, {"cell": 3})
		if r.has("trap_id"):
			set += 1
	ok(set >= 3, "traps set (%d)" % set)
	var goods := 0
	for t in SurvivalTrapLine.traps(core).values():
		if str(t.site) == "good":
			goods += 1
	ok(goods <= 1, "one good site per cell")
	var s0 := SurvivalUtil.num(core.state.trapline.stock[3].get("marten"), 0.0) + SurvivalUtil.num(core.state.trapline.stock[3].get("raccoon"), 0.0)
	var lam := SurvivalTrapLine.lambda_for(core, SurvivalTrapLine.traps(core).values()[0], "dec")
	ok(float(lam.total) > 0.0, "a set trap has a nightly catch rate (%.3f)" % float(lam.total))
	var caught := 0
	for n in 6:
		live(core, 24.0 * 60.0)
		sustain(core)
		for tid in SurvivalTrapLine.traps(core).keys():
			var r := core.run_job("trap.check", {"trap_id": tid})
			if str(r.get("caught", "")) != "":
				caught += 1
				var cid := str(r.carcass_id)
				var rec := SurvivalCamp.carcass(core, cid)
				if SurvivalCamp.carcass_has_pelt(core, rec):
					var sk := core.run_job("fur.skin", {"carcass_id": cid})
					ok(sk.has("pelt") or str(sk.get("outcome", "")) == "mishap", "skinned: %s" % str(sk.get("pelt", sk)))
				core.run_job("butcher.field_dress", {"carcass_id": cid})
	ok(caught >= 2, "catches over six December nights (%d)" % caught)
	var s1 := SurvivalUtil.num(core.state.trapline.stock[3].get("marten"), 0.0) + SurvivalUtil.num(core.state.trapline.stock[3].get("raccoon"), 0.0)
	ok(s1 < s0 + 0.5, "the cell's stock is drawn down (%.2f -> %.2f)" % [s0, s1])
	var pelts := SurvivalInventory.by_cat(core, "pelt")
	if not pelts.is_empty():
		var st: Dictionary = pelts[0]
		ok(bool(st.meta.get("green", false)) or bool(st.meta.get("dried", false)), "pelts come off green")
		ok(SurvivalUtil.num(st.meta.get("prime"), 0.0) >= 0.9, "December pelts are prime")
		var sr := core.run_job("fur.stretch")
		ok(sr.has("stretched") or sr.has("interrupted") or str(sr.get("outcome", "")) != "", "stretched: %s" % str(sr.get("grade", sr)))


func test_trap_unchecked_losses() -> void:
	var core := mk("", {"start_day": "jan_early"})
	var id := SurvivalTrapLine.add_trap(core, "deadfall", 2, "good", 1.0)
	var t := SurvivalTrapLine.trap(core, id)
	t["state"] = "holding"
	t["catch"] = "marten"
	t["catch_day"] = SurvivalClock.abs_day(core) - 1
	var lost := 0
	for i in 200:
		t["state"] = "holding"
		t["catch"] = "marten"
		SurvivalTrapLine.dawn_roll(core)
		if str(t.state) == "sprung":
			lost += 1
	near(float(lost) / 200.0, 0.35, 0.09, "a held catch is scavenged 35% a night")


func test_hunting_kill_and_dress() -> void:
	var core := mk("", {"start_day": "oct_mid", "start_hour": 9.0})
	var deer0 := SurvivalTrapLine.deer_stock(core)
	var h0 := SurvivalSkills.level(core, "hunting")
	var cid := core.report_kill("deer", {"clean": true, "unaware": true, "shot_quality": 1.0, "cell": 4})
	ok(SurvivalTrapLine.deer_stock(core) == deer0 - 1.0, "the woods have one deer fewer")
	ok(SurvivalSkills.level(core, "hunting") > h0, "a clean kill on an unaware animal teaches Hunting")
	var r := core.run_job("butcher.field_dress", {"carcass_id": cid})
	ok(r.has("outcome"), "dressed: %s" % str(r.get("reason", "")))
	var lb := SurvivalInventory.count(core, "item.food.venison_raw")
	var ym := {"excellent": 1.0, "success": 1.0, "partial": 0.8, "failure": 0.6, "mishap": 0.6}
	near(lb, 60.0 * float(ym.get(str(r.outcome), 1.0)), 0.01, "a deer gives 60 lb of venison x the outcome's yield")
	ok(SurvivalInventory.has(core, "item.material.green_hide"), "and a green hide")
	between(lb * 110.0 / 800.0, 4.0, 8.5, "about eight meals")
	ok(not SurvivalCamp.carcasses(core).has(cid), "the carcass is done")
	var t := core.run_job("hunt.track", {"cell": 4})
	ok(t.has("outcome"), "tracking runs")


# ---------------------------------------------------------------- economy
func test_economy_prices() -> void:
	var core := mk("", {"start_day": "oct_mid"})
	var oct_meal := float(SurvivalEconomy.buy_unit(core, "mkt.fort_sutler", "item.food.cornmeal").unit_d)
	var mar := mk("", {"start_day": "mar_mid"})
	var mar_meal := float(SurvivalEconomy.buy_unit(mar, "mkt.fort_sutler", "item.food.cornmeal").unit_d)
	ok(mar_meal > oct_meal * 2.0, "cornmeal costs more in March than after the harvest (%.2f vs %.2f)" % [mar_meal, oct_meal])
	ok(oct_meal > 1.0, "the sutler adds carriage to the valley price")
	var trap := float(SurvivalEconomy.buy_unit(core, "mkt.visiting_trader", "item.trap.steel").unit_d)
	near(trap, 144.0, 0.01, "a steel trap is one beaver at the trader's tariff")
	var sp0 := SurvivalEconomy.spread_eff(core, "mkt.fort_sutler")
	SurvivalSkills.set_level(core, "trade", 100.0)
	ok(SurvivalEconomy.spread_eff(core, "mkt.fort_sutler") < sp0, "Trade narrows the spread")
	near(float(SurvivalEconomy.buy_unit(core, "mkt.visiting_trader", "item.trap.steel").unit_d), 144.0 * 0.95, 0.01, "an Adept argues the tariff down 5%")
	# Drink makes a worse bargain.
	var sober := mk("", {"start_day": "oct_mid"})
	var p0 := float(SurvivalEconomy.buy_unit(sober, "mkt.fort_sutler", "item.food.salt_pork").unit_d)
	SurvivalInventory.add(sober, "item.drink.rum", 1.0)
	SurvivalFood.drink(sober)
	SurvivalFood.drink(sober)
	ok(float(SurvivalEconomy.buy_unit(sober, "mkt.fort_sutler", "item.food.salt_pork").unit_d) > p0, "tipsy: worse prices")


func test_economy_sell_pelts() -> void:
	var core := mk("", {"start_day": "dec_early"})
	SurvivalInventory.add(core, "item.pelt.marten", 2.0, {"grade": "good", "prime": 1.0, "condition": 1.0, "dried": true})
	var q := SurvivalEconomy.quote_sell(core, "mkt.fort_sutler", "item.pelt.marten", 1.0)
	near(float(q.total_d), 60.0 * 0.6, 0.01, "the sutler pays coin at 0.6 of a marten's cash value")
	var tq := SurvivalEconomy.quote_sell(core, "mkt.visiting_trader", "item.pelt.marten", 1.0)
	ok(bool(tq.ok) and str(tq.layer) == "barter", "the trader is here in Early December and pays at his tariff")
	near(float(tq.coin_if_taken_d), float(tq.total_d) * 0.6, 0.01, "coin at the coin rate")
	var b0 := SurvivalEconomy.balance(core, SurvivalEconomy.TRADER_ID)
	var r := SurvivalEconomy.sell(core, "mkt.visiting_trader", "item.pelt.marten", 1.0, "book")
	ok(bool(r.ok) and SurvivalEconomy.balance(core, SurvivalEconomy.TRADER_ID) < b0, "furs pay the book")
	SurvivalInventory.add(core, "item.pelt.fox", 1.0, {"grade": "good", "prime": 1.0, "green": true})
	ok(not bool(SurvivalEconomy.quote_sell(core, "mkt.fort_sutler", "item.pelt.fox", 1.0).ok), "a green pelt must be dried first")
	# A sale takes the stack it priced: the dried pelt goes and the green one on the hoop stays, even when the green one
	# (a prime January pelt) would rank higher.
	var mix := mk("", {"start_day": "jan_mid"})
	for st in SurvivalInventory.stacks_of(mix, "item.pelt.marten"):
		SurvivalInventory.remove_stack_qty(mix, st, float(st.qty))
	SurvivalInventory.add(mix, "item.pelt.marten", 1.0, {"grade": "good", "prime": 0.8, "condition": 1.0, "dried": true})
	SurvivalInventory.add(mix, "item.pelt.marten", 1.0, {"grade": "good", "prime": 1.0, "condition": 1.0, "green": true, "stretched": true})
	var sr := SurvivalEconomy.sell(mix, "mkt.fort_sutler", "item.pelt.marten", 1.0, "coin")
	var left := SurvivalInventory.stacks_of(mix, "item.pelt.marten")
	ok(bool(sr.ok) and left.size() == 1 and bool(SurvivalUtil.dict(left[0].meta).get("green", false)),
			"selling the dried pelt keeps the green one: %s" % str(left))
	ok(not bool(SurvivalEconomy.sell(mix, "mkt.fort_sutler", "item.pelt.marten", 1.0, "coin").ok), "and the green one cannot be sold")
	var summer := mk("", {"start_day": "jul_mid"})
	ok(not SurvivalEconomy.is_open(summer, "mkt.visiting_trader"), "the trader does not come in July")


func test_economy_credit_year() -> void:
	var core := mk("", {"start_day": "sep_mid", "start_hour": 9.0})
	core.go_to("poi.fort.sutler_store")
	var r := core.run_job("trade.take_credit")
	ok(r.has("outfit") and bool(r.outfit.ok), "the fall outfit on the book: %s" % str(r.get("outfit", r)))
	var owed := SurvivalEconomy.balance(core, SurvivalEconomy.TRADER_ID)
	ok(owed > 0.0 and owed <= 1100.0 + 1.0, "the outfit is within the limit (%.0f)" % owed)
	ok(SurvivalInventory.count(core, "item.trap.steel") >= 4.0, "steel traps in the outfit")
	ok(not bool(core.preview("trade.take_credit").ok), "only one outfit a year")
	# Pay it all and reach the settlement window: paid in full.
	SurvivalEconomy._change_balance(core, SurvivalEconomy.TRADER_ID, -owed, "test: paid")
	var grades := []
	core.settlement.connect(func(c, g, res): grades.append([c, g]))
	var to_may := (SurvivalClock.day_index_of(core, "may_mid") - SurvivalClock.day_of_year(core) + 36) % 36
	live(core, float(to_may) * 1440.0)
	var trader_grade := ""
	for g in grades:
		if str(g[0]) == SurvivalEconomy.TRADER_ID:
			trader_grade = str(g[1])
	ok(trader_grade == "paid_in_full", "graded at the close of the spring window (%s)" % str(grades))
	ok(float(SurvivalEconomy.account(core, SurvivalEconomy.TRADER_ID).outfit_limit_d) >= 800.0, "next autumn's outfit limit")
	# An unpaid book (the "Outfitted on credit" start, v4): no outfit next autumn and collection.
	var u := mk("", {"start_day": "mar_mid", "start_variant": "start.outfitted_on_credit"})
	live(u, float((SurvivalClock.day_index_of(u, "may_mid") - SurvivalClock.day_of_year(u) + 36) % 36) * 1440.0)
	ok(str(SurvivalEconomy.account(u, SurvivalEconomy.TRADER_ID).get("last_grade", "")) == "unpaid", "715 d unpaid: graded unpaid")
	var clear := mk("", {"start_day": "mar_mid"})
	live(clear, float((SurvivalClock.day_index_of(clear, "may_mid") - SurvivalClock.day_of_year(clear) + 36) % 36) * 1440.0)
	ok(str(SurvivalEconomy.account(clear, SurvivalEconomy.TRADER_ID).get("last_grade", "")) == "", "a book never opened is never graded")
	ok(not SurvivalEconomy.debt_warning(clear), "no debt icon without a debt")
	ok(bool(SurvivalEconomy.account(u, SurvivalEconomy.TRADER_ID).get("no_credit", false)), "no outfit next autumn")
	ok(SurvivalUtil.dict(u.state.economy.collection).has(SurvivalEconomy.TRADER_ID), "collection starts")
	ok(SurvivalEconomy.debt_warning(u), "the debt icon shows")


func test_economy_firewood_and_muster() -> void:
	var core := mk("bg.provincial_ranger", {"start_day": "oct_mid"})
	ok(SurvivalEconomy.contract_open(core), "the firewood contract is open in October")
	SurvivalInventory.add(core, "item.fuel.split_wood", 16.0)
	var m0 := SurvivalEconomy.money(core)
	var r := SurvivalEconomy.deliver_firewood(core, 16.0)
	ok(int(r.cords) == 2 and SurvivalEconomy.money(core) == m0 + 36, "two cords, 18 d each: %s" % str(r))
	var jul := mk("", {"start_day": "jul_mid"})
	ok(not SurvivalEconomy.contract_open(jul), "no firewood contract in July")
	# The provincial's muster: attend it, or miss it and pay.
	var p := mk("bg.provincial_ranger", {"start_day": "may_early", "start_hour": 9.0})
	var f := SurvivalEconomy.fulfil_obligation(p, "militia_muster")
	ok(bool(f.ok), "answered the muster")
	var miss := mk("bg.provincial_ranger", {"start_day": "apr_late", "start_hour": 9.0})
	var s0 := SurvivalEconomy.standing(miss, "faction.garrison")
	live(miss, 2.0 * 1440.0)
	ok(SurvivalEconomy.balance(miss, SurvivalEconomy.COUNTY_ID) >= 48.0, "a missed muster: a 48 d fine")
	ok(SurvivalEconomy.standing(miss, "faction.garrison") < s0, "and standing lost")


# ---------------------------------------------------------------- saving
func test_save_load_determinism() -> void:
	var a := mk("", {"seed": 777, "start_day": "nov_mid", "start_hour": 9.0})
	a.run_job("fire.gather")
	a.run_job("craft.stakes")
	a.run_job("trap.deadfall_set", {"cell": 1})
	a.advance(300.0)
	var text := SurvivalSave.to_json(a)
	var b := SurvivalSave.from_json(text)
	ok(b != null, "loaded from JSON")
	ok(json_norm(a.to_dict()) == json_norm(b.to_dict()), "the loaded state equals the saved one")
	for c in [a, b]:
		c.advance(2.0 * 1440.0)
		c.run_job("fire.gather")
		for tid in SurvivalTrapLine.traps(c).keys():
			c.run_job("trap.check", {"trap_id": tid})
		c.advance(600.0)
	ok(json_norm(a.to_dict()) == json_norm(b.to_dict()), "the loaded game continues exactly as the saved one would")


## A full line of traps: the dawn roll draws per trap, so the traps must be walked in the same order after a load.
## Godot's .tres writer sorts dictionary keys (trap.10 before trap.2) and JSON used to as well.
func test_save_load_full_line() -> void:
	var a := mk("", {"seed": 4242, "start_day": "dec_early", "start_hour": 9.0})
	for i in 14:
		SurvivalTrapLine.add_trap(a, "deadfall" if i % 3 != 0 else "steel_land", i % 16, "fair", 1.0,
				{"location": "line.cell.%d" % (i % 16)})
	a.advance(2.0 * 1440.0)
	var ids := SurvivalTrapLine.trap_ids(a)
	ok(ids[1] == "trap.2" and ids[9] == "trap.10", "trap ids in the order they were set: %s" % str(ids.slice(0, 11)))
	var path := "user://survival_test_line.tres"
	ok(SurvivalSave.save_resource(a, path) == OK, "saved the state as .tres")
	var from_tres := SurvivalSave.load_resource(path)
	DirAccess.remove_absolute(path)
	var from_json := SurvivalSave.from_json(SurvivalSave.to_json(a))
	var from_dict := SurvivalCore.from_state(SurvivalState.from_dict(a.to_dict()))
	for c in [a, from_tres, from_json, from_dict]:
		for d in 3:
			live(c, 1440.0)
			for tid in SurvivalTrapLine.trap_ids(c):
				c.run_job("trap.check", {"trap_id": tid})
	var ra := str(a.to_dict().rng_state)
	ok(str(from_json.to_dict().rng_state) == ra, "a JSON load makes the same rolls")
	ok(str(from_tres.to_dict().rng_state) == ra, "a .tres load makes the same rolls, though its keys come back sorted")
	ok(str(from_dict.to_dict().rng_state) == ra, "a copied state makes the same rolls")
	ok(int(SurvivalUtil.num(a.state.stats.get("catches"), 0.0)) > 0, "the line caught something (%s)" % str(a.state.stats.get("catches")))
	for c in [from_json, from_tres]:
		ok(json_norm(a.to_dict()) == json_norm(c.to_dict()), "and the whole state matches after three days on the line")


## JSON keeps floats to the last digit Godot can read back (full precision) and keys in their order.
func test_save_json_precision() -> void:
	var a := mk("", {"seed": 99, "start_hour": 10.0})
	a.advance(777.7)
	a.state.needs["warmth"] = 1.0 / 3.0
	var text := SurvivalSave.to_json(a)
	ok(text.contains("0.33333333333333"), "floats written at full precision")
	var b := SurvivalSave.from_json(text)
	near(float(b.state.needs.warmth), 1.0 / 3.0, 1e-15, "and read back to within a last bit")
	near(b.state.minutes, a.state.minutes, 1e-9, "the clock too")
	ok(b.state.flags.keys() == a.state.flags.keys(), "keys keep their order: %s" % str(b.state.flags.keys()))


func test_save_mid_job() -> void:
	var a := mk("", {"seed": 31, "start_hour": 10.0})
	a.start_job("shelter.brush_leanto")
	a.advance(12.0)
	var b := SurvivalSave.from_json(SurvivalSave.to_json(a))
	ok(SurvivalJobs.is_running(b), "a running job is saved")
	a.advance(120.0)
	b.advance(120.0)
	ok(json_norm(a.to_dict()) == json_norm(b.to_dict()), "and finishes the same after loading")


func test_save_files() -> void:
	var core := mk("", {"seed": 5})
	var slot := "survival_test_slot"
	ok(SurvivalSave.save(core, slot, "manual") == OK, "saved to user://saves/")
	var l := SurvivalSave.load_slot(slot, "manual")
	ok(l != null and l.state.background_id == core.state.background_id, "loaded the slot")
	var names := []
	for i in 4:
		core.advance(60.0)
		names.append(SurvivalSave.autosave(core, slot))
	ok(names[0] == "autosave_0" and names[2] == "autosave_2" and names[3] == "autosave_0", "three rotating autosaves: %s" % str(names))
	var latest := SurvivalSave.load_latest_autosave(slot)
	ok(latest != null, "the latest autosave loads")
	var path := "user://saves/%s/state.tres" % slot
	ok(SurvivalSave.save_resource(core, path) == OK, "saved as a .tres resource")
	var r := SurvivalSave.load_resource(path)
	ok(r != null and json_norm(r.to_dict()) == json_norm(core.to_dict()), "the resource round-trips")
	var found := false
	for s in SurvivalSave.list_saves():
		if str(s.slot) == slot:
			found = true
	ok(found, "listed")
	var d := DirAccess.open("user://saves/" + slot)
	if d != null:
		for fn in d.get_files():
			d.remove(fn)
		DirAccess.remove_absolute("user://saves/" + slot)
	DirAccess.remove_absolute("user://saves")  # only if empty: leave no trace of the test


# ---------------------------------------------------------------- almanac, NPCs, signals
func test_almanac_and_livelihoods() -> void:
	var core := mk("", {"start_day": "oct_mid"})
	var p := SurvivalAlmanac.page(core)
	ok(str(p.date) == "Mid October 1765", "the date")
	ok(SurvivalUtil.arr(p.winter_prep).size() == 7, "the winter-ready checklist from October (7 items, T4)")
	ok(SurvivalUtil.arr(p.gates).has("firewood_contract"), "the firewood gate is open")
	var ids := {}
	for l in p.livelihoods:
		ids[str(l.id)] = l
	ok(ids.has("liv.trapping") and ids.has("liv.market_hunting") and ids.has("job.garrison_firewood"), "the slice's livelihoods")
	ok(not bool(ids["liv.trapping"].in_season) and bool(ids["liv.market_hunting"].in_season), "October: hunting, not yet trapping")
	ok(bool(ids["job.garrison_firewood"].in_season), "the firewood wage is open")
	ok(int(p.trader.next_visit.in_days) > 0, "the trader's next visit is known")
	var full := SurvivalCore.new_game("", {"seed": 3, "start_day": "mar_mid", "backlog_milestones": ["M3", "M4", "M5"]})
	var ids2 := {}
	for l in SurvivalAlmanac.livelihoods(full):
		ids2[str(l.id)] = l
	for want in ["liv.fishing", "liv.sugaring", "liv.gathering", "liv.homesteading", "liv.trading", "liv.army_supply"]:
		ok(ids2.has(want), "with the backlog merged: %s" % want)
	ok(bool(SurvivalUtil.dict(ids2.get("liv.sugaring")).get("peak", false)), "March is the sugaring peak")


func test_npc_schedules() -> void:
	var core := mk("", {"start_day": "oct_mid", "start_hour": 10.0})
	var s := SurvivalNpcs.where(core, "npc.fort.sutler")
	ok(bool(s.present) and str(s.location) == "poi.fort.sutler_store" and str(s.activity) == "keep_store", "the sutler keeps store at 10:00: %s" % str(s))
	ok(str(s.title) == "the sutler", "role titles in the slice")
	var t := SurvivalNpcs.where(core, "npc.post.trader")
	ok(not bool(t.present), "the trader is away in October")
	var fc := mk("", {"start_day": "sep_mid", "start_hour": 10.0})
	var t2 := SurvivalNpcs.where(fc, "npc.post.trader")
	ok(bool(t2.present) and bool(t2.market_open), "the trader is at the store for the fall credit")
	var night := mk("", {"start_day": "oct_mid", "start_hour": 23.5})
	ok(str(SurvivalNpcs.where(night, "npc.fort.sutler").activity) == "sleep", "the sutler sleeps at night")
	var topics := SurvivalNpcs.topics(core, "npc.fort.commandant")
	var fw := false
	for tp in topics:
		if str(tp.id) == "request.firewood":
			fw = bool(tp.available)
	ok(fw, "the lieutenant offers the firewood contract in October")


func test_signals() -> void:
	var core := mk("", {"start_hour": 8.0})
	var got := {"stage": 0, "day": 0, "job": 0, "mods": 0}
	core.need_stage_changed.connect(func(n, o, s): got.stage += 1)
	core.day_started.connect(func(d, id): got.day += 1)
	core.job_finished.connect(func(r): got.job += 1)
	core.modifiers_changed.connect(func(m): got.mods += 1)
	core.run_job("fire.gather")
	core.advance(30.0 * 60.0)
	ok(got.job >= 1, "job_finished")
	ok(got.day >= 1, "day_started")
	ok(got.stage >= 1, "need_stage_changed")
	ok(got.mods >= 1, "modifiers_changed")
	var anim := []
	core.job_started.connect(func(j): anim.append(str(j.anim)))
	core.start_job("craft.stakes")
	ok(anim.size() == 1 and anim[0] == "anim.crafting_pack", "a job names its anim hook (%s)" % str(anim))


# ---------------------------------------------------------------- the M3 backlog actions
func test_m3_actions() -> void:
	var core := SurvivalCore.new_game("", {"seed": 8, "start_day": "jul_mid", "start_hour": 22.0, "backlog_milestones": ["M3"]})
	core.set_context({"location": "pond", "near": ["node.frog_pond", "node.fish_water", "node.forage_clearing", "node.berry_patch"],
			"indoors": false, "in_shelter": false}, true)
	ok(not bool(core.preview("frog.catch_hand").ok), "frogs at night need a torch")
	SurvivalInventory.add(core, "item.tool.torch", 1.0)
	var fr := core.run_job("frog.catch_hand")
	ok(fr.has("outcome"), "caught frogs by hand: %s" % str(fr.get("reason", fr.get("gained"))))
	ok(float(core.state.needs.wetness) > 0.2, "wet from the pond")
	SurvivalInventory.add(core, "item.tool.hooks_line", 1.0)
	var fi := core.run_job("fish.hook_line")
	ok(fi.has("outcome"), "fished: %s" % str(fi))
	core.advance(10.0 * 60.0)
	var fo := core.run_job("forage.search")
	ok(fo.has("outcome"), "foraged: %s" % str(fo.get("reason", fo.get("gained"))))
	if str(fo.get("outcome", "")) in ["success", "excellent"]:
		ok(not SurvivalUtil.dict(fo.gained).is_empty(), "berries or greens gathered: %s" % str(fo.gained))
	var dec := SurvivalCore.new_game("", {"seed": 8, "start_day": "dec_mid", "start_hour": 22.0, "backlog_milestones": ["M3"]})
	dec.set_context({"location": "pond", "near": ["node.frog_pond"], "indoors": false}, true)
	SurvivalInventory.add(dec, "item.tool.torch", 1.0)
	var why := str(dec.preview("frog.catch_hand").reasons)
	ok(why.contains("season"), "no frogs in December: %s" % why)


func test_available_actions_and_verbs() -> void:
	var core := mk("", {"start_hour": 10.0})
	var ids := []
	for a in core.available_actions():
		ids.append(str(a.id))
	ok(ids.has("fire.gather") and ids.has("craft.stakes") and ids.has("shelter.brush_leanto"), "camp actions available at the line camp: %s" % str(ids))
	ok(not ids.has("fire.nurse"), "no coal to nurse")
	var mk_fire := SurvivalJobs.verb_actions(core, "Make fire")
	ok(mk_fire.size() == 2, "the Make fire verb opens strike and nurse")


# ---------------------------------------------------------------- M3 conditions and the optional thirst
func test_m3_frostbite_and_rewarm() -> void:
	var core := SurvivalCore.new_game("", {"seed": 21, "start_day": "jan_mid", "start_hour": 9.0, "backlog_milestones": ["M3"]})
	core.set_context({"location": "open.ground", "near": ["node.deadwood"], "indoors": false, "in_shelter": false, "fire_distance_m": 99.0}, true)
	core.state.worn.erase("item.cloth.mitts")
	var hours := 0.0
	while SurvivalConditions.stage_of(core, "cond.frostbite") != "superficial" and hours < 12.0:
		set_air(core, -22.0)
		sustain(core)
		core.state.needs["warmth"] = 60.0
		core.set_activity("walk")
		core.advance(15.0)
		hours += 0.25
	ok(SurvivalConditions.stage_of(core, "cond.frostbite") == "superficial", "bare hands at -22 C: superficial frostbite in %.1f game hours" % hours)
	ok(str(core.state.conditions["cond.frostbite"].zone) == "hands", "on the hands (the mitts were off)")
	ok(float(core.get_modifiers().reload_speed_mult) < 0.85, "frostbitten hands reload slowly")
	var fid := SurvivalCamp.create_fire(core, "open.ground", "lit", 600.0)
	core.set_context({"fire_id": fid, "fire_distance_m": 1.8})
	var r := core.run_job("physick.rewarm")
	ok(r.has("outcome"), "rewarmed away from the flame: %s" % str(r.get("reason", "")))
	if str(r.get("outcome", "")) in ["success", "excellent"]:
		ok(SurvivalConditions.stage_of(core, "cond.frostbite") == "frostnip", "rewarming eases it one stage")
	core.set_context({"fire_distance_m": 0.8})
	ok(not bool(core.preview("physick.rewarm").ok), "not at the flame itself")
	var bare := SurvivalCore.new_game("", {"seed": 21, "start_day": "jan_mid", "start_hour": 9.0, "backlog_milestones": ["M3"]})
	bare.set_context({"location": "open.ground", "near": ["node.dry_leaves"], "indoors": false, "in_shelter": false}, true)
	for i in 24:
		set_air(bare, -22.0)
		sustain(bare)
		bare.state.needs["warmth"] = 60.0
		bare.advance(15.0)
	ok(str(SurvivalUtil.dict(bare.state.conditions.get("cond.frostbite")).get("zone", "")) == "feet", "unstuffed moccasins at -22 C: the feet freeze")
	var stuffed := SurvivalCore.new_game("", {"seed": 21, "start_day": "jan_mid", "start_hour": 9.0, "backlog_milestones": ["M3"]})
	stuffed.set_context({"location": "open.ground", "near": ["node.dry_leaves"], "indoors": false, "in_shelter": false}, true)
	var st := stuffed.run_job("clothing.stuff_moccasins")
	ok(bool(st.get("ok", false)) and stuffed.state.flags.has("feet_ins_add"), "moccasins stuffed with dry leaves: %s" % str(st.get("reason", "")))
	for i in 24:
		set_air(stuffed, -22.0)
		sustain(stuffed)
		stuffed.state.needs["warmth"] = 60.0
		stuffed.advance(15.0)
	ok(SurvivalConditions.stage_of(stuffed, "cond.frostbite") == "", "mitts, a fur cap and stuffed moccasins keep it off for hours")
	stuffed.report_wetting("wade_waist")
	stuffed.advance(10.0)
	ok(not stuffed.state.flags.has("feet_ins_add"), "the stuffing is lost when soaked")


func test_m3_worms_from_raw_fish() -> void:
	var core := SurvivalCore.new_game("", {"seed": 4, "start_day": "aug_mid", "backlog_milestones": ["M3"]})
	var got := false
	for i in 120:
		core.state.needs["stomach"] = 200.0
		SurvivalInventory.add(core, "item.food.fish_raw", 1.0)
		SurvivalFood.eat(core, "item.food.fish_raw")
		if core.state.conditions.has("cond.worms"):
			got = true
			break
	ok(got, "raw fish can give worms (4% a meal)")
	if got:
		ok(bool(core.state.conditions["cond.worms"].get("incubating", false)), "worms incubate before they show")
		ok(float(core.get_modifiers().hunger_burn_mult) == 1.0, "no effect while incubating")
		core.state.conditions["cond.worms"]["inc_h"] = 0.1
		live(core, 60.0)
		ok(float(core.get_modifiers().hunger_burn_mult) > 1.2, "then food burns faster (x1.25)")
	var cooked := SurvivalCore.new_game("", {"seed": 4, "start_day": "aug_mid", "backlog_milestones": ["M3"]})
	for i in 60:
		cooked.state.needs["stomach"] = 200.0
		SurvivalInventory.add(cooked, "item.food.fish_cooked", 1.0)
		SurvivalFood.eat(cooked, "item.food.fish_cooked")
	ok(not cooked.state.conditions.has("cond.worms"), "properly cooked fish is safe")


func test_optional_thirst() -> void:
	var off := mk()
	ok(not SurvivalNeeds.thirst_enabled(off), "thirst is off in the slice")
	var on := SurvivalCore.new_game("", {"seed": 2, "backlog_milestones": ["post"], "settings": {"thirst_enabled": true}})
	ok(SurvivalNeeds.thirst_enabled(on), "thirst on with the 'post' rows and the setting")
	live(on, 0.0)
	on.state.needs["stomach"] = 2400.0
	on.advance(26.0 * 60.0)
	ok(SurvivalNeeds.thirst_stage(on) != "hydrated", "a day without water: %s" % SurvivalNeeds.thirst_stage(on))
	SurvivalFood.drink_water(on, "source_sip")
	SurvivalFood.drink_water(on, "source_sip")
	ok(float(on.state.needs.hydration) > 60.0, "drinking at a spring")


func test_runtime_node() -> void:
	var rt := SurvivalRuntime.new()
	rt.run_seed = 17
	rt.save_slot = "survival_runtime_test"
	var got := []
	rt.core_ready.connect(func(c): got.append(c))
	var c := rt.new_game("bg.provincial_ranger")
	ok(c != null and got.size() == 1, "the runtime node makes a core and says so")
	var m0 := c.state.minutes
	rt._process(6.0)
	ok(float(c.state.world.clock_acc) > 0.0, "a short frame is carried in the accumulator (P0-1)")
	rt._process(30.0)
	ok(c.state.minutes > m0, "real time drives the survival clock")
	rt.set_paused(true)
	var m1 := c.state.minutes
	rt._process(6.0)
	ok(c.state.minutes == m1, "paused in menus")
	ok(rt.save_game("manual") == OK and rt.load_game("survival_runtime_test", "manual"), "saves and loads its slot")
	var d := DirAccess.open("user://saves/survival_runtime_test")
	if d != null:
		for fn in d.get_files():
			d.remove(fn)
		DirAccess.remove_absolute("user://saves/survival_runtime_test")
	DirAccess.remove_absolute("user://saves")  # only if empty
	rt.free()
