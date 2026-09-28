class_name SurvivalNeeds
extends RefCounted
## Needs (needs.json): food (stomach and body reserve, in game kcal), warmth 0-100, wetness 0-1, rest (fatigue 0-100),
## optional light thirst (backlog need.thirst, off unless enabled and loaded), plus the drink meter and a survival-side
## health pool that condition drains act on. Rates are per game hour on the SurvivalClock and scale by the difficulty
## preset (needs.json difficulty_scaling: food burn, warmth loss and fatigue gain).
##
## Warmth follows needs.json need.warmth exactly:
##   dW/dh = clamp((T_eff - T_comfort) * k, -max_loss, +max_gain), losses x warmth_loss_mult
##   T_eff = air + ins_eff * c_per_ins + shelter_c + fire_c + activity_c + food_c - wind_c - wet_c + bedding_c
## env() returns every term, so the HUD or a debug readout can say why the player is cold.

## Indoor air (the sutler's store, barracks) when the context says indoors [D].
const INDOOR_AIR_C := 14.0
## A banked fire gives this share of a lit fire's heat [D].
const BANKED_HEAT := 0.35
## Health regained per game hour when nothing drains it, before health_regen_mult [D].
const HEALTH_REGEN_PER_H := 1.0
const LONG_ACTIVITY_DEFAULT := "rest"


static func need_row(core: SurvivalCore, id: String) -> Dictionary:
	return core.data.need(id)


static func init(core: SurvivalCore) -> void:
	var food := need_row(core, "need.food")
	var st := SurvivalUtil.dict(food.get("start"))
	var n := core.state.needs
	n["stomach"] = SurvivalUtil.num(st.get("stomach"), 2400.0)
	n["reserve"] = SurvivalUtil.num(st.get("reserve"), 2500.0)
	n["warmth"] = SurvivalUtil.num(need_row(core, "need.warmth").get("start"), 100.0)
	n["wetness"] = 0.0
	n["fatigue"] = SurvivalUtil.num(need_row(core, "need.rest").get("start"), 10.0)
	n["hydration"] = 100.0
	n["drunk"] = 0.0
	n["drunk_peak"] = 0.0
	n["health"] = 100.0


## The preset's multiplier for one need ("food", "warmth" or "fatigue"; needs.json difficulty_scaling, split per need in
## v4 as the balance report's R2 recommends: Hard Winter is about cold, not starving careful players). A preset given as
## one number applies to all three.
static func difficulty_mult(core: SurvivalCore, which: String = "warmth") -> float:
	# settings.rest_need false (the game, SurvivalBridge; user 2026-09-27 "sleep is an added benefit like boost"):
	# tiredness never builds; sleep earns a boost instead. The sims and tests keep the need (the default).
	if which == "fatigue" and not bool(core.setting("rest_need", true)):
		return 0.0
	var ds := core.data.section("needs", "difficulty_scaling")
	var v = ds.get(core.state.preset, 1.0)
	if typeof(v) == TYPE_DICTIONARY:
		return SurvivalUtil.num(v.get(which), 1.0)
	return SurvivalUtil.num(v, 1.0)


static func thirst_enabled(core: SurvivalCore) -> bool:
	return bool(core.setting("thirst_enabled", false)) and core.data.needs.has("need.thirst")


# ---------------------------------------------------------------- stages
static func food_stage(core: SurvivalCore) -> String:
	var food := need_row(core, "need.food")
	var cap := SurvivalUtil.num(food.get("stomach_capacity_kcal"), 3000.0)
	var stomach := SurvivalUtil.num(core.state.needs.get("stomach"), 0.0)
	var reserve := SurvivalUtil.num(core.state.needs.get("reserve"), 0.0)
	if stomach <= 0.0:
		return "starving" if reserve > 0.0 else "wasting"
	var frac := stomach / cap
	for s in SurvivalUtil.arr(food.get("stages")):
		if s.has("stomach_frac_min") and frac >= SurvivalUtil.num(s.stomach_frac_min):
			return str(s.stage)
	return "very_hungry"


static func warmth_stage(core: SurvivalCore, warmth: float = -1.0) -> String:
	var w := SurvivalUtil.num(core.state.needs.get("warmth"), 100.0) if warmth < 0.0 else warmth
	if w <= 0.0:
		return "freezing"
	for s in SurvivalUtil.arr(need_row(core, "need.warmth").get("stages")):
		if s.has("min") and w >= SurvivalUtil.num(s.min):
			return str(s.stage)
	return "hypothermic"


static func rest_stage(core: SurvivalCore) -> String:
	var f := SurvivalUtil.num(core.state.needs.get("fatigue"), 0.0)
	if f >= 100.0:
		return "collapse"
	for s in SurvivalUtil.arr(need_row(core, "need.rest").get("stages")):
		if s.has("max") and f <= SurvivalUtil.num(s.max):
			return str(s.stage)
	return "exhausted"


static func wet_stage(core: SurvivalCore) -> String:
	var w := SurvivalUtil.num(core.state.needs.get("wetness"), 0.0)
	var best := "dry"
	for s in SurvivalUtil.arr(core.data.condition("cond.wet").get("stages")):
		if w >= SurvivalUtil.num(s.get("min"), 99.0):
			best = str(s.stage)
	return best


static func thirst_stage(core: SurvivalCore) -> String:
	if not thirst_enabled(core):
		return "hydrated"
	var h := SurvivalUtil.num(core.state.needs.get("hydration"), 100.0)
	if h <= 0.0:
		return "dehydrated"
	for s in SurvivalUtil.arr(need_row(core, "need.thirst").get("stages")):
		if s.has("min") and h >= SurvivalUtil.num(s.min):
			return str(s.stage)
	return "parched"


## All need stages at once: {need.food: "hungry", need.warmth: "chilled", ...}.
static func stages(core: SurvivalCore) -> Dictionary:
	var out := {"need.food": food_stage(core), "need.warmth": warmth_stage(core), "need.rest": rest_stage(core),
			"need.wetness": wet_stage(core)}
	if thirst_enabled(core):
		out["need.thirst"] = thirst_stage(core)
	return out


## Severity index of a stage within its need's list (0 = fine); used by the wake rules.
static func stage_severity(core: SurvivalCore, need_id: String, stage: String) -> int:
	match need_id:
		"need.wetness":
			return ["dry", "damp", "soaked"].find(stage)
		"need.rest":
			return ["rested", "tired", "exhausted", "collapse"].find(stage)
	var row := need_row(core, need_id)
	var i := 0
	for s in SurvivalUtil.arr(row.get("stages")):
		if str(s.get("stage", "")) == stage:
			return i
		i += 1
	return 0


# ---------------------------------------------------------------- environment
## The warmth equation's terms for the player's current context (state.context set by the game or the harness).
static func env(core: SurvivalCore) -> Dictionary:
	var ctx := core.state.context
	var wr := need_row(core, "need.warmth")
	var indoors := bool(ctx.get("indoors", false))
	var e := {}
	e["indoors"] = indoors
	e["air_c"] = INDOOR_AIR_C if indoors else SurvivalClock.air_temp_c(core)
	var shelter := SurvivalCamp.current_shelter(core)
	var shelter_q := 0.0
	if not shelter.is_empty() and bool(ctx.get("in_shelter", false)):
		# Chinking and banked snow (shelter.chink_bank) add up to half a quality step of warmth and wind protection.
		shelter_q = SurvivalUtil.num(shelter.get("quality"), 0.0) + 0.5 * SurvivalUtil.num(shelter.get("wind_add"), 0.0)
	e["shelter_q"] = shelter_q
	e["shelter_c"] = shelter_q * SurvivalUtil.num(wr.get("shelter_c_per_quality"), 1.5)
	var fire := SurvivalCamp.current_fire(core)
	var fire_dist := SurvivalUtil.num(ctx.get("fire_distance_m"), 99.0)
	var fire_c := 0.0
	if not fire.is_empty() and not indoors:
		var heat := 0.0
		match str(fire.get("state", "out")):
			"lit":
				heat = 1.0
			"banked":
				heat = BANKED_HEAT
		fire_c = SurvivalUtil.table_lerp(SurvivalUtil.arr(wr.get("fire_c_by_distance_m")), fire_dist) * heat
		if shelter_q >= 5.0:
			fire_c *= SurvivalUtil.num(wr.get("fire_c_shelter_q5_mult"), 1.3)
	e["fire_state"] = str(fire.get("state", "none")) if not fire.is_empty() else "none"
	e["fire_distance_m"] = fire_dist
	e["fire_c"] = fire_c
	var act := current_activity(core)
	e["activity"] = act
	e["activity_c"] = SurvivalUtil.num(SurvivalUtil.dict(wr.get("activity_c")).get(act), 0.0)
	e["food_c"] = SurvivalUtil.num(SurvivalUtil.dict(wr.get("food_c")).get(food_stage(core)), 0.0)
	var wetness := SurvivalUtil.num(core.state.needs.get("wetness"), 0.0)
	var ins := 0.0
	var wind_sum := 0.0
	for cls in SurvivalInventory.worn_classes(core):
		var z := 0.0
		for v in SurvivalUtil.dict(cls.get("ins")).values():
			z += SurvivalUtil.num(v)
		ins += z * (1.0 - wetness * (1.0 - SurvivalUtil.num(cls.get("wet_keep"), 0.5)))
		wind_sum += SurvivalUtil.num(cls.get("wind"), 0.0)
	# Stuffed moccasins (clothing.stuff_moccasins) until soaked.
	ins += SurvivalUtil.num(core.state.flags.get("feet_ins_add"), 0.0)
	var bedding_ins := 0.0
	if core.state.asleep:
		bedding_ins = SurvivalCamp.bedding_insulation(core)
	e["ins_eff"] = ins + bedding_ins
	var wind_block := minf(0.9, wind_sum / 10.0 + (0.5 if shelter_q >= 2.0 else 0.0))
	var wind := 0.0 if indoors else SurvivalWeather.wind_ms(core)
	e["wind_ms"] = wind
	e["wind_c"] = wind * 0.8 * (1.0 - wind_block)
	e["wet_c"] = 6.0 * wetness
	var bed := SurvivalCamp.current_bedding(core) if (core.state.asleep or act == "rest") else ""
	e["bedding"] = bed
	e["bedding_c"] = SurvivalUtil.num(SurvivalUtil.dict(wr.get("bedding_c")).get(bed if bed != "" else "none"), 0.0)
	e["t_eff"] = float(e.air_c) + float(e.ins_eff) * SurvivalUtil.num(wr.get("c_per_ins"), 1.8) + float(e.shelter_c) \
			+ fire_c + float(e.activity_c) + float(e.food_c) - float(e.wind_c) - float(e.wet_c) + float(e.bedding_c)
	e["precip"] = "" if indoors else SurvivalWeather.precip(core)
	return e


static func current_activity(core: SurvivalCore) -> String:
	if core.state.asleep:
		return "sleep"
	var a := core.state.activity
	return a if a != "" else LONG_ACTIVITY_DEFAULT


## Warmth change per game hour for an environment (before the drink and condition multipliers are known, pass mods).
static func warmth_rate(core: SurvivalCore, e: Dictionary, mods: Dictionary) -> float:
	var wr := need_row(core, "need.warmth")
	var rate := (float(e.t_eff) - SurvivalUtil.num(wr.get("T_comfort_c"), 8.0)) * SurvivalUtil.num(wr.get("k"), 1.2)
	rate = clampf(rate, -SurvivalUtil.num(wr.get("max_loss_per_game_h"), 40.0), SurvivalUtil.num(wr.get("max_gain_per_game_h"), 30.0))
	if rate < 0.0:
		rate *= SurvivalUtil.num(mods.get("warmth_loss_mult"), 1.0) * difficulty_mult(core, "warmth")
		# habit.cold_camp: sleeps without a fire at 80% of the usual heat loss.
		if core.state.asleep and str(e.get("fire_state", "none")) != "lit":
			rate *= SurvivalUtil.num(core.perk_effect("sleep_no_fire_warmth_loss_mult", 1.0), 1.0)
	return rate


# ---------------------------------------------------------------- tick
static func tick(core: SurvivalCore, hours: float, mods: Dictionary) -> void:
	var n := core.state.needs
	var e := env(core)
	var act := str(e.activity)
	var diff := difficulty_mult(core, "food")
	var food := need_row(core, "need.food")
	# Food: burn from the stomach, then from the reserve; refill the reserve while the stomach is over half full.
	var burn := SurvivalUtil.num(food.get("burn_kcal_per_game_h"), 100.0) * hours
	burn *= SurvivalUtil.num(SurvivalUtil.dict(food.get("activity_mult")).get(act), 1.0)
	burn *= SurvivalUtil.num(SurvivalUtil.dict(food.get("cold_mult")).get(warmth_stage(core)), 1.0)
	burn *= SurvivalUtil.num(mods.get("hunger_burn_mult"), 1.0) * diff
	var stomach := SurvivalUtil.num(n.get("stomach"), 0.0)
	var reserve := SurvivalUtil.num(n.get("reserve"), 0.0)
	var from_stomach := minf(stomach, burn)
	stomach -= from_stomach
	reserve = maxf(0.0, reserve - (burn - from_stomach))
	var rr := SurvivalUtil.dict(food.get("reserve_rules"))
	var cap := SurvivalUtil.num(food.get("stomach_capacity_kcal"), 3000.0)
	var rcap := SurvivalUtil.num(food.get("reserve_capacity_kcal"), 2500.0)
	if stomach > cap * SurvivalUtil.num(rr.get("refill_when_stomach_above_frac"), 0.5) and reserve < rcap:
		var move := minf(minf(SurvivalUtil.num(rr.get("refill_kcal_per_game_h"), 60.0) * hours, rcap - reserve), stomach)
		stomach -= move
		reserve += move
	n["stomach"] = stomach
	n["reserve"] = reserve
	# Warmth.
	var rate := warmth_rate(core, e, mods)
	n["warmth"] = clampf(SurvivalUtil.num(n.get("warmth"), 100.0) + rate * hours, 0.0, 100.0)
	# Wetness: rain unsheltered soaks; a fire, shelter, sun or cold air dries.
	var wn := need_row(core, "need.wetness")
	var wet := SurvivalUtil.num(n.get("wetness"), 0.0)
	var gain := 0.0
	var sheltered_from_rain := bool(e.indoors) or float(e.shelter_q) >= 3.0
	if str(e.precip) != "" and not sheltered_from_rain:
		gain += SurvivalUtil.num(SurvivalWeather.row(core).get("wetness_per_h"), 0.0)
	var gph := SurvivalUtil.dict(wn.get("gain_per_game_h"))
	if act == "heavy_work" and float(e.air_c) < 0.0:
		gain += SurvivalUtil.num(gph.get("sweat_heavy_work_below_0c"), 0.05)
	var dry := 0.0
	var dph := SurvivalUtil.dict(wn.get("dry_per_game_h"))
	if str(e.fire_state) == "lit" and float(e.fire_distance_m) <= 2.0:
		dry = SurvivalUtil.num(dph.get("by_fire_2m"), 0.5)
	elif bool(e.indoors) or float(e.shelter_q) >= 1.0:
		dry = SurvivalUtil.num(dph.get("in_shelter"), 0.1)
	elif str(e.precip) == "" and float(e.air_c) > 10.0:
		dry = SurvivalUtil.num(dph.get("sun_warm_wind"), 0.2)
	elif str(e.precip) == "":
		dry = SurvivalUtil.num(dph.get("cold_air"), 0.03)
	if gain > 0.0 and dry > 0.0 and not (str(e.fire_state) == "lit" and float(e.fire_distance_m) <= 2.0):
		dry = 0.0
	n["wetness"] = clampf(wet + (gain - dry) * hours, 0.0, 1.0)
	if SurvivalUtil.num(n.wetness) <= 0.0:
		core.state.flags.erase("feet_wet")
	# Rest.
	var rest := need_row(core, "need.rest")
	var fat := SurvivalUtil.num(n.get("fatigue"), 0.0)
	if core.state.asleep:
		fat -= SurvivalUtil.num(rest.get("sleep_recovery_per_game_h"), 12.5) * sleep_quality(core, e) * hours
	else:
		var g := SurvivalUtil.num(rest.get("gain_per_game_h_awake"), 2.5)
		g *= SurvivalUtil.num(SurvivalUtil.dict(rest.get("activity_mult")).get(act), 1.0)
		g *= SurvivalUtil.num(mods.get("fatigue_rate_mult"), 1.0) * difficulty_mult(core, "fatigue")
		fat += g * hours
	n["fatigue"] = clampf(fat, 0.0, 100.0)
	# Light thirst (backlog need.thirst; off by default).
	if thirst_enabled(core):
		var th := need_row(core, "need.thirst")
		var d := SurvivalUtil.num(th.get("drain_per_game_h"), 2.8)
		var tm := SurvivalUtil.dict(th.get("mult"))
		if float(e.air_c) > 25.0:
			d *= SurvivalUtil.num(tm.get("summer_heat"), 1.5)
		if act == "heavy_work":
			d *= SurvivalUtil.num(tm.get("heavy_work"), 1.5)
		d *= SurvivalUtil.num(mods.get("thirst_mult"), 1.0)
		n["hydration"] = clampf(SurvivalUtil.num(n.get("hydration"), 100.0) - d * hours, 0.0, 100.0)
	# The drink meter decays (conditions.json cond.drunk meter).
	var dm := SurvivalUtil.dict(core.data.condition("cond.drunk").get("meter"))
	n["drunk"] = maxf(0.0, SurvivalUtil.num(n.get("drunk"), 0.0) - SurvivalUtil.num(dm.get("decay_per_game_h"), 10.0) * hours)
	# Wet powder dries within 2 m of a lit fire in 60 game minutes (conditions.json cond.wet extra.powder_dunked).
	if bool(core.state.flags.get("powder_wet", false)) and str(e.fire_state) == "lit" and float(e.fire_distance_m) <= 2.0:
		var pm := SurvivalUtil.num(core.state.flags.get("powder_dry_min"), 0.0) + hours * 60.0
		core.state.flags["powder_dry_min"] = pm
		if pm >= 60.0:
			core.state.flags.erase("powder_wet")
			core.state.flags.erase("powder_dry_min")
			core.log_line("the powder is dry again", "info")
	# Health: condition drains, else a slow mend.
	var drain := SurvivalUtil.num(mods.get("health_drain_per_hour"), 0.0)
	var hp := SurvivalUtil.num(n.get("health"), 100.0)
	if drain > 0.0:
		hp -= drain * hours
	else:
		hp += HEALTH_REGEN_PER_H * SurvivalUtil.num(mods.get("health_regen_mult"), 1.0) * hours
	n["health"] = clampf(hp, 0.0, 100.0)


## Sleep quality (needs.json need.rest sleep_quality_formula):
##   q = clamp(0.4 + 0.08 * shelter_q + bedding + warmth_term - insects - cold_camp + plain_fare, 0.2, 1.1)
## A shelter of quality 3 or better with bedding gives full recovery (actions.json world.shelter quality_rules).
static func sleep_quality(core: SurvivalCore, e: Dictionary = {}) -> float:
	if e.is_empty():
		e = env(core)
	var rest := need_row(core, "need.rest")
	var terms := SurvivalUtil.dict(rest.get("sleep_quality_terms"))
	var bed_terms := SurvivalUtil.dict(terms.get("bedding"))
	var q := 0.4 + 0.08 * float(e.get("shelter_q", 0.0))
	var bedding := 0.0
	var bed := str(e.get("bedding", ""))
	if bed != "":
		bedding += SurvivalUtil.num(bed_terms.get(bed), 0.0)
	if SurvivalCamp.has_blanket_bedding(core):
		bedding += SurvivalUtil.num(bed_terms.get("blanket"), 0.1)
	q += bedding
	var wt := SurvivalUtil.dict(terms.get("warmth_term"))
	var ws := warmth_stage(core)
	q += SurvivalUtil.num(wt.get(ws), -0.5 if ws == "hypothermic" or ws == "freezing" else 0.0)
	if SurvivalClock.season(core) == "winter" and str(e.get("fire_state", "none")) != "lit" and str(e.get("fire_state", "none")) != "banked" \
			and not bool(e.get("indoors", false)):
		q -= SurvivalUtil.num(terms.get("cold_camp_no_fire_winter"), 0.1)
	if SurvivalFood.plain_fare(core):
		q += SurvivalUtil.num(terms.get("plain_fare"), -0.05)
	q = clampf(q, 0.2, 1.1)
	if float(e.get("shelter_q", 0.0)) >= 3.0 and bedding > 0.0:
		q = maxf(q, 1.0)
	if bool(e.get("indoors", false)):
		q = maxf(q, 0.9)
	return q


## Expected warmth at the end of a sleep of `hours` (for the sleep dialog: needs.json time_safety.sleep_dialog_shows).
static func forecast_sleep(core: SurvivalCore, hours: float) -> Dictionary:
	var fire := SurvivalCamp.current_fire(core)
	var fuel_h := SurvivalCamp.fuel_hours(core, str(fire.get("id", ""))) if not fire.is_empty() else 0.0
	var was_asleep := core.state.asleep
	core.state.asleep = true
	var e := env(core)
	core.state.asleep = was_asleep
	var wr := need_row(core, "need.warmth")
	var air_now := float(e.air_c)
	var low := INDOOR_AIR_C if bool(e.indoors) else SurvivalClock.night_low_c(core)
	var w := SurvivalUtil.num(core.state.needs.get("warmth"), 100.0)
	var mods := core.get_modifiers()
	var steps := maxi(1, ceili(hours))
	for i in steps:
		var e2 := e.duplicate()
		e2["air_c"] = lerpf(air_now, low, clampf(float(i + 1) / 6.0, 0.0, 1.0))
		if float(i) >= fuel_h and str(e.fire_state) == "lit":
			e2["fire_c"] = 0.0
			e2["fire_state"] = "out"
		e2["t_eff"] = float(e.t_eff) - float(e.air_c) + float(e2.air_c) - float(e.fire_c) + float(e2.fire_c)
		w = clampf(w + warmth_rate(core, e2, mods) * minf(1.0, hours - float(i)), 0.0, 100.0)
	return {"warmth_end": w, "stage_end": warmth_stage(core, w), "fuel_hours": fuel_h,
			"meals": SurvivalInventory.meals(core), "night_low_c": low, "quality": sleep_quality(core, e)}
