class_name SurvivalAlmanac
extends RefCounted
## The almanac and the livelihoods: what the season makes possible and valuable, logic only (seasons.json almanac,
## livelihoods.json, economy.json markets). The journal page and the HUD's debt icon read this.
##
## In the slice the year's round (v4) is: the first deer, nuts, groundnuts and Indian hemp in the fall; hides into rawhide
## and buckskin; the half-faced camp and a hung cache before the cold; the trap line and snares from November to March;
## snowshoes before the deep snow and ice fishing in January and February; barter at the trader's visits, the farm
## family's four market days, the soldiers' evenings and the old hunter's hut; the fall outfit and the spring settlement
## only for a player who opens a book. With backlog rows merged (SurvivalCore.new_game backlog_milestones), the
## same functions list the other livelihoods of the 1760s frontier: fishing the runs, maple sugaring, gathering ginseng
## and nuts, supplying the army, homesteading, trading, carrying and guiding.

## Winter-ready thresholds (seasons.json almanac.winter_ready_checklist; the M2a gate's T4) [D where not in the text].
const PREP_FUEL_GAME_H := 12.0
const PREP_INSULATION := 15.0
## The food store by Late November: 20 meals, about seven game days (fix round 1, F5: 30 meals was about 100 kg of fresh
## venison, four deer, by Late November).
const READY_MEALS := 20.0
const READY_SHELTER_Q := 4.0
const READY_CORDAGE := 6.0
const LINE_CAMP := "poi.fort.woods_camp"


## The one-page almanac: {date, time, season, light, weather, gates, next_events, trader, settlement, debt_warning,
## ledger, livelihoods, winter_prep}.
static func page(core: SurvivalCore) -> Dictionary:
	var out := {"date": SurvivalClock.date_string(core), "time": SurvivalClock.time_string(core),
			"season": SurvivalClock.season(core), "light": SurvivalClock.light_level(core)}
	var outlook_h := SurvivalUtil.num(SurvivalSkills.flag(core, "survival", "weather_outlook_h", 0.0), 0.0)
	out["weather"] = {"state": SurvivalWeather.state_id(core), "air_c": snappedf(SurvivalClock.air_temp_c(core), 0.1),
			"night_low_c": snappedf(SurvivalClock.night_low_c(core), 0.1), "wind_ms": snappedf(SurvivalWeather.wind_ms(core), 0.1),
			"snow_cm": snappedf(SurvivalWeather.snow_depth_cm(core), 0.1), "outlook": SurvivalWeather.outlook(core, outlook_h)}
	out["gates"] = SurvivalClock.active_gates(core)
	out["next_events"] = next_events(core, 6)
	out["trader"] = trader_status(core)
	var warn_from := str(SurvivalUtil.dict(core.data.section("seasons", "almanac")).get("settlement_warning_from", "mar_mid"))
	out["settlement"] = {"event": "event.spring_trade", "opens_in_days": SurvivalClock.days_until(core, SurvivalClock.event_first_day(core, "event.spring_trade")),
			"open": SurvivalClock.event_active(core, "event.spring_trade"), "warning_from": warn_from}
	out["debt_warning"] = SurvivalEconomy.debt_warning(core)
	out["ledger"] = SurvivalEconomy.ledger(core)
	out["livelihoods"] = livelihoods(core)
	out["winter_prep"] = winter_prep(core)
	out["market_days"] = market_days(core)
	out["obligations"] = SurvivalTrade.obligations_of(core, core.state.player_id, true)
	return out


## The partners' days: the farm family's market days, the trader's visits, the old hunter's away weeks (next first).
static func market_days(core: SurvivalCore) -> Array:
	var out := []
	for mid in ["mkt.farm_visit", "mkt.visiting_trader"]:
		for ev in SurvivalUtil.arr(core.data.market(mid).get("open")):
			var first := SurvivalClock.event_first_day(core, str(ev))
			if first != "":
				out.append({"market": mid, "event": str(ev), "in_days": SurvivalClock.days_until(core, first),
						"open": SurvivalClock.event_active(core, str(ev))})
	out.sort_custom(func(a, b): return int(a.in_days) < int(b.in_days))
	return out


## The next calendar events: [{id, name, in_days, active}], soonest first.
static func next_events(core: SurvivalCore, n: int = 6) -> Array:
	var out := []
	for ev in core.data.events.values():
		var first := SurvivalClock.event_first_day(core, str(ev.id))
		if first == "":
			continue
		out.append({"id": str(ev.id), "name": str(ev.get("name", ev.id)), "in_days": SurvivalClock.days_until(core, first),
				"active": SurvivalClock.event_active(core, str(ev.id))})
	out.sort_custom(func(a, b): return (0 if a.active else 1) * 1000 + int(a.in_days) < (0 if b.active else 1) * 1000 + int(b.in_days))
	return out.slice(0, n)


## The visiting trader: {present, next_visit, in_days}.
static func trader_status(core: SurvivalCore) -> Dictionary:
	var present := SurvivalEconomy.is_open(core, "mkt.visiting_trader")
	var best := {}
	for ev in SurvivalUtil.arr(core.data.market("mkt.visiting_trader").get("open")):
		var d := SurvivalClock.days_until(core, SurvivalClock.event_first_day(core, str(ev)))
		if d >= 0 and (best.is_empty() or d < int(best.in_days)):
			best = {"event": str(ev), "name": str(SurvivalUtil.dict(core.data.events.get(str(ev))).get("name", ev)), "in_days": d}
	return {"present": present, "next_visit": best}


static func _months_of(v) -> Array:
	if typeof(v) == TYPE_STRING and str(v) == "all":
		return ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
	return SurvivalUtil.arr(v)


## Every livelihood with its season now: [{id, name, in_season, peak, months, outputs: [{item, buyer, unit_d,
## coin_equiv_d}], jobs}]. A buyer is the best open market now for one ordinary unit (cash-equivalent pence).
static func livelihoods(core: SurvivalCore) -> Array:
	var m := SurvivalClock.month_id(core)
	var out := []
	for l in core.data.livelihoods.values():
		var months := _months_of(l.get("months"))
		var peak := _months_of(l.get("peak"))
		var outputs := []
		for it in SurvivalUtil.arr(l.get("outputs")):
			if core.data.item(str(it)).is_empty():
				continue
			var bo := SurvivalEconomy.best_offer(core, str(it))
			outputs.append({"item": str(it), "name": core.data.item_name(str(it)), "buyer": str(bo.get("market", "")),
					"unit_d": SurvivalUtil.num(bo.get("unit_d"), 0.0), "coin_equiv_d": SurvivalUtil.num(bo.get("coin_equiv_d"), 0.0)})
		var jobs := []
		for j in core.data.jobs.values():
			if str(j.get("livelihood", "")) == str(l.id):
				jobs.append(str(j.id))
		out.append({"id": str(l.id), "name": str(l.get("name", l.id)), "in_season": months.has(m), "peak": peak.has(m),
				"months": months, "outputs": outputs, "jobs": jobs, "skills": SurvivalUtil.arr(l.get("skills")),
				"milestone": str(l.get("milestone", ""))})
	# Wage jobs open now (the garrison's firewood).
	for j in core.data.jobs.values():
		var jm := _months_of(j.get("months"))
		var open := jm.has(m)
		if str(j.id) == "job.garrison_firewood":
			open = SurvivalEconomy.contract_open(core)
		out.append({"id": str(j.id), "name": str(j.get("name", j.id)), "in_season": open, "peak": false, "months": jm,
				"outputs": [], "jobs": [str(j.id)], "skills": [], "wage": str(j.get("wage", j.get("pay_wage", ""))),
				"milestone": str(j.get("milestone", ""))})
	return out


## The winter-ready checklist from its start day (seasons.json almanac.winter_ready_checklist; goal.winter_ready):
## [{text, done}]. Food counts the pack and the caches, in meals.
static func winter_prep(core: SurvivalCore) -> Array:
	var cl := SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("seasons", "almanac")).get("winter_ready_checklist"))
	var items := SurvivalUtil.arr(cl.get("items"))
	if items.is_empty() or not SurvivalClock.in_window(core, [str(cl.get("from", "oct_early")), "mar_late"]):
		return []
	var checks := winter_ready_checks(core)
	var out := []
	for i in items.size():
		out.append({"text": str(items[i]), "done": bool(checks[i]) if i < checks.size() else false})
	return out


## The seven checks behind the list, in its order: shelter 4, a spare pair of moccasins (two usable pairs, made,
## carried or traded: fix round 1, F4), mitts and a cap worn, the food store (READY_MEALS in the pack and caches), a
## hung cache, 6 cordage, snowshoes.
static func winter_ready_checks(core: SurvivalCore) -> Array:
	var worn := core.state.worn
	return [SurvivalUtil.num(SurvivalCamp.shelter_at(core, LINE_CAMP).get("quality"), 0.0) >= READY_SHELTER_Q,
			SurvivalInventory.count_usable(core, "item.cloth.moccasins") >= 2.0,
			worn.has("item.cloth.mitts") and worn.has("item.cloth.fur_cap"),
			food_meals(core) >= READY_MEALS,
			not SurvivalCamp.cache_at(core, LINE_CAMP).is_empty(),
			SurvivalInventory.count_usable(core, "item.material.cordage") >= READY_CORDAGE,
			SurvivalInventory.has(core, "item.tool.snowshoes")]


## Winter-ready without the snowshoes (T4 wants those by Early January, the rest by Late November).
static func winter_ready(core: SurvivalCore) -> bool:
	var c := winter_ready_checks(core)
	for i in 6:
		if not bool(c[i]):
			return false
	return true


## Meals in the pack and the caches (the jerky still on the rack counts once it is down).
static func food_meals(core: SurvivalCore) -> float:
	return SurvivalInventory.meals(core) + SurvivalCamp.cache_meals(core)


## Game hours of fuel carried plus stacked at the line camp's fire.
static func _prep_fuel(core: SurvivalCore) -> bool:
	var m := 0.0
	for it in SurvivalCamp.FUEL_ORDER:
		m += SurvivalCamp.fuel_min_of(core, it) * SurvivalInventory.count(core, it)
	var f := SurvivalCamp.fire_at(core, LINE_CAMP)
	if not f.is_empty():
		m += SurvivalCamp.fuel_hours(core, str(f.id)) * 60.0
	return m / 60.0 >= PREP_FUEL_GAME_H


## Insulation of the worn clothing (dry), summed over zones.
static func _prep_clothing(core: SurvivalCore) -> float:
	var ins := 0.0
	for cls in SurvivalInventory.worn_classes(core):
		for v in SurvivalUtil.dict(cls.get("ins")).values():
			ins += SurvivalUtil.num(v)
	return ins


## The fall whose outfit covers this winter (the year the credit year began).
static func _credit_year(core: SurvivalCore) -> int:
	var y := SurvivalClock.year(core)
	return y if SurvivalClock.month_index(core) >= 8 else y - 1
