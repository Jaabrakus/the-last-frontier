class_name SurvivalSim
extends RefCounted
## Headless simulation harness: runs one character through N game days with scripted choices and records what happened,
## so balance can be checked without the game (survival_gdd.md section 18: telemetry for playtests).
##
## It drives the survival core only through its public API (go_to, set_activity, advance, run_job, report_kill, the
## economy, the trade window, lessons), the way the game will. Policies (survival GDD v4 section 18.2):
##   "self_sufficient"  lives entirely from the woods: never buys, sells, barters, borrows or takes a lesson. Gathers nuts,
##                groundnuts and Indian hemp in the fall, hunts for meat and hides, dresses hides and sews, twists
##                cordage, builds the half-faced camp in stages and hangs a cache, runs deadfalls and snares, makes
##                snowshoes and fishes through the ice (the M2a gate's T1-T4, T9, T10, T12)
##   "barterer"   the same work, and trades surplus with every partner on every visit and market day (T5, T6)
##   "apprentice" the barterer, plus lessons from the old hunter (labour asks), watching him work, and haggling (M2b)
##   "trapper"    the old money path, now the credit variant: the "Outfitted on credit" start (the hunter) or "On the
##                sutler's tally" (the provincial) and the fall outfit, fall hunting, the trap line November to March,
##                the trader's visits, firewood when idle, the spring settlement (T8; regression against v3)
##   "hunter"     market hunting for skins and meat October to January, firewood otherwise (the provincial's spike)
##   "woodcutter" the garrison's firewood contract, lodging in the sutler's loft, food bought at the store
##   "careless"   never makes a fire or shelter and eats only when starving: shows that conditions bite
##   "idle"       eats, keeps a fire and sleeps: the baseline cost of living
## Choices the game leaves to the player (the stalk and the shot, where to walk) use the harness's own random stream and
## the [D] assumptions below, so the core's stream stays the game's.
## Fix round 1 (redesign_balance_report.md section 8): one game day of food in the pack with the cache as the larder; the
## trap line walked all year; balls cast from bar lead; open-water fishing April to August (ice fishing first when short
## in the deep winter) and smoked fish; summer berries; acorns; each heard-of recipe tried once its materials are in hand;
## made and traded garments put on; the cache's cordage first and six cords kept back; snowshoes from October; the
## barterer trades surplus only and buys a spare pair and mitts; the apprentice asks first for what it does not know.
##
##   var report := SurvivalSim.run({"background": "bg.backcountry_hunter", "policy": "trapper", "days": 36, "seed": 1})
##   Godot --headless --path . -s tests/survival/run_survival_sim.gd -- --policy trapper --days 36

const CAMP := "poi.fort.woods_camp"
const STORE := "poi.fort.sutler_store"
const WOODPILE := "poi.fort.woodpile"
## Walking between the fort and the line camp, one way [D].
const FORT_CAMP_WALK_MIN := 40.0
## Line cells' nodes [D: trail country with saplings, conifers and deadwood].
const LINE_NODES := ["node.trail", "node.sapling_stand", "node.conifer", "node.deadwood"]
const LINE_CAMP_DISTANCE_M := 500.0
## The working day: from half an hour before sunrise to an hour after sunset, at most this long [D; 10-11 h in the GDD].
const MAX_WORK_H := 11.0
## Meals to keep in the pack before going for supplies [D].
const MIN_MEALS := 6.0
const BUY_MEALS := 12.0
## Hunting: tracking finds a trail by the deer stock; the stalk takes this long and the shot succeeds with
## p = 0.3 + 0.5 x Hunting/100 [D harness assumptions standing in for the player].
const STALK_MIN := 150.0
const KILL_P_BASE := 0.3
const KILL_P_SKILL := 0.5
const POWDER_LB_PER_SHOT := 0.05
const MEAT_KEEP_LB := 40.0
## Split wood kept for a night's fire (armloads of 120 fuel minutes) [D].
const NIGHT_FUEL_ARMLOADS := 6
const SLEEP_BY_H := 21.0
## v4 places (map_regions.json) and the self-sufficient round's targets [D harness assumptions].
const BOTTOMLAND := "poi.fort.bottomland"
const OLD_FIELD := "poi.fort.old_field"
const BROOK := "poi.fort.brook"
const HUT := "poi.woods.hunters_hut"
const V4_POLICIES := ["self_sufficient", "barterer", "apprentice"]
const CORDAGE_TARGET := 10.0
const MOCCASINS_TARGET := 3.0
const TRAPS_V4 := 12
## Food in store (pack and cache, meals) the round aims to keep; hunting starts below the first [D].
const HUNT_BELOW_MEALS := 18.0
const GATHER_BELOW_MEALS := 45.0
## One game day of food in the pack; the cache is the larder (fix round 1: was 8, which alone could weigh 26 kg of
## fresh venison and made T12 unreachable, redesign_balance_report.md F9).
const PACK_MEALS := 3.0
## Musket balls kept in the pouch: below this the hunter casts more from his bar lead (craft.cast_balls, live from fix
## round 1).
const BALLS_KEEP := 10.0
## The credit variant each background plays on the old money path (backgrounds.json start_variants).
const CREDIT_VARIANT := {"bg.backcountry_hunter": "start.outfitted_on_credit", "bg.provincial_ranger": "start.sutler_tally"}

var core: SurvivalCore
var policy := "trapper"
var rng := RandomNumberGenerator.new()
var opts := {}
var line_size := 16
var day_rows := []
var events := []
var start_abs_day := 0
var _day := {}
## v4 telemetry: real seconds by kind, the day winter-ready came, the day snowshoes came.
var real_s := {"jobs": 0.0, "walk": 0.0, "wait": 0.0, "sleep": 0.0}
var ready_day := -1
var snowshoe_day := -1
var v4 := {"trades": 0, "lessons": 0, "watched": 0, "haggles": 0, "labour_h": 0.0, "walked_line_day": -1}


## Run a simulation. opts: background, policy, days, seed, start_day, start_year, start_hour, preset, line_size,
## backlog_milestones, verbose. Returns the report (see report()).
static func run(o: Dictionary) -> Dictionary:
	var sim := SurvivalSim.new()
	sim.setup(o)
	sim.simulate(int(o.get("days", 36)))
	return sim.report()


func setup(o: Dictionary) -> void:
	opts = o.duplicate(true)
	policy = str(o.get("policy", "trapper"))
	var seed_v := int(o.get("seed", 1))
	rng.seed = seed_v * 7919 + 17
	var copts := {"seed": seed_v, "start_day": str(o.get("start_day", "sep_early")), "start_hour": float(o.get("start_hour", 7.0)),
			"preset": str(o.get("preset", "woodsman")), "backlog_milestones": SurvivalUtil.arr(o.get("backlog_milestones", []))}
	if o.has("start_year"):
		copts["start_year"] = int(o.start_year)
	if o.has("settings"):
		copts["settings"] = o.settings
	var bg_id := str(o.get("background", "bg.backcountry_hunter"))
	if o.has("start_variant"):
		copts["start_variant"] = str(o.start_variant)
	elif policy == "trapper":
		copts["start_variant"] = str(CREDIT_VARIANT.get(bg_id, "start.clear"))
	_attach(SurvivalCore.new_game(bg_id, copts))
	line_size = int(o.get("line_size", 16))
	start_abs_day = SurvivalClock.abs_day(core)
	if policy == "woodcutter":
		core.go_to(STORE)
	else:
		core.go_to(CAMP)


## This run carried on with another core, such as a save of this one loaded back: the harness's own random stream,
## choices and day rows continue from where this run is. Used to check that a loaded game plays on the same way.
## The fork is of the same script, so a harness that extends this one (survival_sim_balance.gd) keeps its habits.
func fork(other: SurvivalCore) -> SurvivalSim:
	var b: SurvivalSim = get_script().new()
	b.opts = opts.duplicate(true)
	b.policy = policy
	b.rng.seed = rng.seed
	b.rng.state = rng.state
	b.line_size = line_size
	b.day_rows = day_rows.duplicate(true)
	b.events = events.duplicate(true)
	b.start_abs_day = start_abs_day
	b.real_s = real_s.duplicate()
	b.ready_day = ready_day
	b.snowshoe_day = snowshoe_day
	b.v4 = v4.duplicate(true)
	b._attach(other)
	return b


func _attach(c: SurvivalCore) -> void:
	core = c
	core.settlement.connect(_on_settlement)
	core.died.connect(_on_died)
	core.calendar_event.connect(_on_calendar_event)
	core.job_started.connect(_on_job_started)


## Real seconds a job takes on screen (sleep is about 10 real seconds a night: survival_gdd.md section 4).
func _on_job_started(job: Dictionary) -> void:
	if str(job.get("action", "")) == "rest.sleep":
		real_s["sleep"] = float(real_s.sleep) + 10.0
	else:
		real_s["jobs"] = float(real_s.jobs) + SurvivalUtil.num(job.get("screen_s"), 0.0)


func _on_settlement(cred: String, grade: String, _res: Dictionary) -> void:
	events.append({"day": SurvivalClock.day_id(core), "kind": "settlement", "creditor": cred, "grade": grade})


func _on_died(cause: String) -> void:
	events.append({"day": SurvivalClock.day_id(core), "kind": "death", "cause": cause})


func _on_calendar_event(id: String, started: bool) -> void:
	if started:
		events.append({"day": SurvivalClock.day_id(core), "kind": "event", "id": id})


# ---------------------------------------------------------------- the day loop
func simulate(n_days: int) -> void:
	var end_day := start_abs_day + n_days
	var guard := 0
	while SurvivalClock.abs_day(core) < end_day and not core.is_dead() and guard < n_days * 4 + 10:
		guard += 1
		_begin_day()
		_ensure()
		match policy:
			"trapper":
				_day_trapper()
			"hunter":
				_day_hunter()
			"woodcutter":
				_day_woodcutter()
			"careless":
				_day_careless()
			"self_sufficient", "barterer", "apprentice":
				_day_v4()
			_:
				_day_idle()
		if core.is_dead():
			break
		_evening()
		_record_day()
		_night()
	if core.is_dead() and (day_rows.is_empty() or not bool(day_rows[day_rows.size() - 1].get("dead", false))):
		_record_day()


func _begin_day() -> void:
	_day = {"stats0": core.state.stats.duplicate(true), "income0": _income_ce(), "money0": SurvivalEconomy.money(core),
			"warmth_min": 100.0, "abs_day": SurvivalClock.abs_day(core)}


func _hour() -> float:
	return SurvivalClock.hour(core)


func _work_end_h() -> float:
	var wake := SurvivalClock.sunrise_h(core) - 0.5
	return minf(SurvivalClock.sunset_h(core) + 1.0, wake + MAX_WORK_H)


func _time_left_min() -> float:
	return (_work_end_h() - _hour()) * 60.0


func _log(text: String) -> void:
	if bool(opts.get("verbose", false)):
		print("%s %s  %s" % [SurvivalClock.date_string(core), SurvivalClock.time_string(core), text])


# ---------------------------------------------------------------- movement and time
## Walk for `minutes` of flat-ground time: deep snow, mud, load and injuries stretch it (move_speed_mult).
func _walk(minutes: float, act: String = "walk") -> void:
	if minutes <= 0.0 or core.is_dead():
		return
	var speed := clampf(SurvivalUtil.num(core.get_modifiers().get("move_speed_mult"), 1.0), 0.3, 1.1)
	core.set_activity(act if not SurvivalClock.gate_active(core, "deep_snow") or not SurvivalInventory.has(core, "item.tool.snowshoes") else "snowshoe")
	real_s["walk"] = float(real_s.walk) + minutes / speed / maxf(0.001, SurvivalClock.game_minutes_per_real_second(core))
	core.advance(minutes / speed)
	core.set_activity("rest")
	_track_warmth()


func _go(poi: String) -> void:
	var here := str(core.state.context.get("location", ""))
	if here == poi:
		return
	var here_fort := here.begins_with("poi.fort.") and here != CAMP
	var to_fort := poi.begins_with("poi.fort.") and poi != CAMP
	var mins := 10.0
	if here_fort != to_fort:
		mins = FORT_CAMP_WALK_MIN
	elif here.begins_with("line.") or poi.begins_with("line."):
		mins = 15.0
	_walk(mins)
	core.go_to(poi)


func _go_cell(cell: int) -> void:
	var loc := "line.cell.%d" % cell
	if str(core.state.context.get("location", "")) != loc:
		var per := SurvivalUtil.num(SurvivalUtil.dict(core.data.trap_model().get("season_sim")).get("walk_min_per_trap"), 5.0)
		_walk(per * SurvivalUtil.num(core.perk_effect("trap_walk_time_mult", 1.0), 1.0))
	core.set_context({"location": loc, "near": LINE_NODES.duplicate(), "cell": cell, "indoors": false, "in_shelter": false,
			"fire_distance_m": 99.0, "camp_distance_m": LINE_CAMP_DISTANCE_M, "sign_near": false}, true)


func _rest(minutes: float) -> void:
	if minutes < 0.01:
		return
	core.set_activity("rest")
	real_s["wait"] = float(real_s.wait) + minutes / maxf(0.001, SurvivalClock.game_minutes_per_real_second(core))
	core.advance(minutes)
	_track_warmth()


func _track_warmth() -> void:
	_day["warmth_min"] = minf(float(_day.get("warmth_min", 100.0)), SurvivalUtil.num(core.state.needs.get("warmth"), 100.0))


## Run a job, dealing with interruptions (a worsening need, the fire) the way a player would, then resuming.
func _job(id: String, params: Dictionary = {}) -> Dictionary:
	var r := {}
	var wait_guard := 0
	while core.is_passed_out() and not core.is_dead() and wait_guard < 48:
		wait_guard += 1
		core.advance(30.0)
	for attempt in 4:
		if core.is_dead():
			return {"ok": false, "reason": "dead"}
		r = core.run_job(id, params)
		_track_warmth()
		if not r.has("interrupted"):
			return r
		if core.is_dead():
			return r
		_ensure(id)
	return r


# ---------------------------------------------------------------- needs first
## What any player does before carrying on: bind a bleeding cut, eat when hungry, warm up when cold.
func _ensure(during: String = "") -> void:
	if core.is_dead():
		return
	if SurvivalConditions.needs_binding(core) and SurvivalInventory.has(core, "item.remedy.bandage") and during != "physick.bind_wound":
		core.run_job("physick.bind_wound")
	var fs := SurvivalNeeds.food_stage(core)
	if policy == "careless":
		if fs == "starving" or fs == "wasting":
			_eat_something()
		return
	if fs in ["hungry", "very_hungry", "starving", "wasting"] and during != "eat":
		_eat_something()
	var ws := SurvivalNeeds.warmth_stage(core)
	if ws in ["cold", "very_cold", "hypothermic", "freezing"] and during != "rest.sleep":
		_warm_up()


func _eat_something() -> void:
	if SurvivalFood.choose_meal(core) == "" and SurvivalFood.choose_to_cook(core) == "":
		_eat_from_cache()
	if SurvivalFood.choose_meal(core) == "":
		if not _cook_something():
			if not _buy_food():
				return
	var r := core.run_job("eat")
	if not bool(r.get("ok", false)) and SurvivalFood.choose_meal(core) == "":
		_cook_something()
		core.run_job("eat")


func _cook_something() -> bool:
	var raw := SurvivalFood.choose_to_cook(core)
	if raw == "":
		return false
	if not _make_fire():
		return false
	var r := _job("cook.roast", {"item": raw})
	return bool(r.get("ok", false))


## Warm up: indoors if at the fort, else by a fire (made if need be) until comfortable or two hours pass.
func _warm_up() -> void:
	var loc := str(core.state.context.get("location", ""))
	if bool(core.state.context.get("indoors", false)):
		_rest(60.0)
		return
	if loc.begins_with("line."):
		_go(CAMP)
	if not _make_fire():
		if loc.begins_with("poi.fort."):
			_go(STORE)
			_rest(60.0)
		return
	var t := 0.0
	while t < 120.0 and SurvivalUtil.num(core.state.needs.get("warmth"), 0.0) < 70.0 and not core.is_dead():
		_feed_fire()
		_rest(20.0)
		t += 20.0


# ---------------------------------------------------------------- fire
## A lit fire here: relight a smouldering or banked one with fuel, else gather, strike and nurse. Returns success.
func _make_fire() -> bool:
	if policy == "careless":
		return false
	var f := SurvivalCamp.current_fire(core)
	if not f.is_empty() and str(f.state) == "lit":
		return true
	if not f.is_empty() and (str(f.state) == "banked" or (str(f.state) == "smouldering" and not bool(f.get("coal_only", false)))):
		if _feed_fire():
			return true
	for attempt in 6:
		if core.is_dead():
			return false
		f = SurvivalCamp.current_fire(core)
		if not f.is_empty() and str(f.state) == "lit":
			_feed_fire()
			return true
		if not f.is_empty() and str(f.state) == "smouldering" and bool(f.get("coal_only", false)):
			if _has_flame_tinder() or _gather_fire_materials():
				core.run_job("fire.nurse")
				continue
		if not SurvivalInventory.has(core, "item.fuel.kindling") or not _has_spark_tinder():
			if not _gather_fire_materials():
				return false
		var r := core.run_job("fire.strike_flint_steel")
		if r.has("reasons") and not r.has("outcome"):
			if not _gather_fire_materials():
				return false
	f = SurvivalCamp.current_fire(core)
	return not f.is_empty() and str(f.state) == "lit"


func _has_spark_tinder() -> bool:
	for t in SurvivalJobs.SPARK_TINDERS:
		if SurvivalInventory.has(core, t):
			return true
	return false


func _has_flame_tinder() -> bool:
	for t in SurvivalJobs.FLAME_TINDERS:
		if SurvivalInventory.has(core, t):
			return true
	return false


func _gather_fire_materials() -> bool:
	if not SurvivalUtil.arr(core.state.context.get("near")).has("node.deadwood"):
		return false
	var r := _job("fire.gather")
	return bool(r.get("ok", false)) and not SurvivalUtil.dict(r.get("gained")).is_empty()


## Feed the fire from carried fuel (split wood, then bundles, then kindling). Returns true if it burns afterwards.
func _feed_fire() -> bool:
	for fuel in SurvivalCamp.FUEL_ORDER:
		if SurvivalInventory.has(core, fuel):
			var r := core.run_job("fire.tend", {"fuel": fuel})
			return bool(r.get("ok", false))
	if _gather_fire_materials():
		return bool(core.run_job("fire.tend").get("ok", false))
	return false


func _feed_fire_if_low() -> void:
	var f := SurvivalCamp.current_fire(core)
	if f.is_empty():
		return
	if str(f.state) != "lit" or SurvivalCamp.fuel_hours(core, str(f.id)) < 1.0:
		_make_fire()


## Split enough wood for the night and stack it by the fire so it feeds itself while the camp sleeps.
func _lay_in_night_fuel() -> void:
	var need := NIGHT_FUEL_ARMLOADS
	if SurvivalClock.season(core) == "summer":
		need = 2
	var guard := 0
	while SurvivalInventory.count(core, "item.fuel.split_wood") < float(need) and guard < 10 and not core.is_dead():
		guard += 1
		var r := _job("wood.split_firewood")
		if r.has("reasons"):
			break
	var f := SurvivalCamp.current_fire(core)
	if not f.is_empty():
		SurvivalCamp.stack_fuel(core, str(f.id), "item.fuel.split_wood", SurvivalInventory.count(core, "item.fuel.split_wood"))


## At bedtime the stack is made up again to a night's wood: the evening's sitting has burnt from it (the stack feeds
## the fire from as soon as it is laid; once the core fed a fire from its stack when its wood ran out on one of its
## 10-minute steps, a stack laid at dusk no longer lasted till the morning). Only what is short is split.
func _top_up_night_fuel() -> void:
	if policy == "careless" or policy == "woodcutter" or str(core.state.context.get("location", "")) != CAMP:
		return
	var f := SurvivalCamp.current_fire(core)
	if f.is_empty():
		return
	var want := 2 if SurvivalClock.season(core) == "summer" else NIGHT_FUEL_ARMLOADS
	var stacked := SurvivalUtil.num(SurvivalUtil.dict(f.get("stack")).get("item.fuel.split_wood"), 0.0)
	var short := float(want) - stacked
	var guard := 0
	while SurvivalInventory.count(core, "item.fuel.split_wood") < short and guard < 6 and not core.is_dead():
		guard += 1
		if _job("wood.split_firewood").has("reasons"):
			break
	if SurvivalInventory.has(core, "item.fuel.split_wood"):
		SurvivalCamp.stack_fuel(core, str(f.id), "item.fuel.split_wood", SurvivalInventory.count(core, "item.fuel.split_wood"))


# ---------------------------------------------------------------- the evening and the night
func _evening() -> void:
	if core.is_dead():
		return
	if policy == "woodcutter":
		_go(STORE)
		# The provincial lodges by the store by the lieutenant's leave (backgrounds.json start); anyone else pays.
		if str(SurvivalUtil.dict(core.background().get("start")).get("poi", "")) != STORE and SurvivalEconomy.money(core) >= 15:
			SurvivalEconomy.buy_service(core, "service.lodging")
		_ensure_food_supply()
		_eat_until_fed()
		return
	if policy == "careless":
		_go(CAMP)
		return
	_go(CAMP)
	if V4_POLICIES.has(policy):
		_camp_chores()
	_make_fire()
	if SurvivalCamp.shelter_at(core, CAMP).is_empty() and SurvivalClock.season(core) != "summer":
		_job("shelter.brush_leanto")
	if SurvivalCamp.current_bedding(core) == "":
		_job("shelter.bough_bed")
	_make_fire()
	_cook_for_tomorrow()
	_eat_until_fed()
	_stretch_all()
	_lay_in_night_fuel()


func _cook_for_tomorrow() -> void:
	var ready := 0.0
	for st in core.state.inventory:
		if SurvivalFood.edible(core, str(st.id)) and core.data.item_cat(str(st.id)) != "meat_raw":
			ready += SurvivalInventory.stack_kcal(core, st)
	# A hair below the line: a loaded save's floats can differ from the live game's in the last bit (Godot's float text
	# round trip), and an exact boundary here would send the two down different evenings.
	if ready >= 800.0 * 4.0 - 0.01:
		return
	var raw := SurvivalFood.choose_to_cook(core)
	if raw != "" and _make_fire():
		_job("cook.roast", {"item": raw})


func _eat_until_fed() -> void:
	for i in 3:
		if SurvivalNeeds.food_stage(core) == "fed" and SurvivalUtil.num(core.state.needs.get("stomach"), 0.0) > 2000.0:
			return
		if SurvivalFood.choose_meal(core) == "" and not _cook_something():
			return
		var r := core.run_job("eat")
		if not bool(r.get("ok", false)):
			return


func _night() -> void:
	var guard := 0
	var target_day := int(_day.get("abs_day", SurvivalClock.abs_day(core))) + 1
	# Sit by the fire until bedtime.
	if SurvivalClock.abs_day(core) < target_day and _hour() < SLEEP_BY_H:
		var wait := (SLEEP_BY_H - _hour()) * 60.0
		var t0 := core.state.minutes
		while wait - (core.state.minutes - t0) > 1.0 and not core.is_dead():
			if policy != "careless" and policy != "woodcutter":
				_feed_fire_if_low()
			_rest(minf(60.0, wait - (core.state.minutes - t0)))
			_ensure()
	_top_up_night_fuel()
	while not core.is_dead() and guard < 16:
		guard += 1
		if SurvivalClock.abs_day(core) >= target_day and _hour() >= SurvivalClock.sunrise_h(core) - 0.5:
			break
		if core.is_passed_out():
			core.advance(30.0)
			continue
		var hours := -1.0
		if SurvivalClock.abs_day(core) < target_day:
			hours = clampf(24.0 - _hour() + SurvivalClock.sunrise_h(core) - 0.5, 1.0, 10.0)
		else:
			hours = clampf(SurvivalClock.sunrise_h(core) - 0.5 - _hour(), 1.0, 10.0)
		var r := core.run_job("rest.sleep", {"hours": hours})
		if core.is_dead():
			break
		if r.has("interrupted"):
			var why := str(r.interrupted)
			_log("woke: " + why)
			if policy == "careless":
				continue
			if why.begins_with("the fire"):
				_make_fire()
				var f := SurvivalCamp.current_fire(core)
				if not f.is_empty() and SurvivalInventory.has(core, "item.fuel.split_wood"):
					SurvivalCamp.stack_fuel(core, str(f.id), "item.fuel.split_wood", SurvivalInventory.count(core, "item.fuel.split_wood"))
				elif not f.is_empty():
					_lay_in_night_fuel()
			else:
				_ensure("rest.sleep")
				if SurvivalNeeds.warmth_stage(core) in ["cold", "very_cold", "hypothermic", "freezing"]:
					_warm_up()
		elif r.has("reasons"):
			core.advance(30.0)


# ---------------------------------------------------------------- supplies and trade
func _ensure_food_supply() -> void:
	if SurvivalInventory.meals(core) >= MIN_MEALS:
		return
	_buy_food()


## Food first, the way a hungry hunter mixes livelihoods: buy with coin; sell a dried fur to the sutler; cut the
## garrison's firewood for coin (the safe wage, October to March); or go hunting.
func _food_security() -> void:
	var guard := 0
	while SurvivalInventory.meals(core) < MIN_MEALS and guard < 4 and _time_left_min() > 120.0 and not core.is_dead():
		guard += 1
		if SurvivalEconomy.money(core) >= 30 or _has_dried_furs():
			if _buy_food() and SurvivalInventory.meals(core) >= MIN_MEALS:
				return
		if policy == "trapper" and SurvivalClock.gate_active(core, "trapping_season") and not SurvivalTrapLine.traps(core).is_empty():
			return
		if SurvivalEconomy.contract_open(core):
			# In the trapping season the line comes first: a short shift at the woodpile for food money only.
			var cap := 150.0 if (policy == "trapper" and SurvivalClock.gate_active(core, "trapping_season")) else 240.0
			_go(WOODPILE)
			_firewood_hours(minf(cap, _time_left_min() - 60.0))
			_buy_food()
			if cap < 240.0:
				return
			continue
		_hunt_day(2)


func _has_dried_furs() -> bool:
	for st in core.state.inventory:
		var cat := core.data.item_cat(str(st.id))
		if (cat == "pelt" or cat == "skin") and not bool(SurvivalUtil.dict(st.meta).get("green", false)):
			return true
	return false


## Go to the sutler and buy food up to BUY_MEALS: 70% of the energy as cornmeal and 30% as salt pork, the cheapest
## diet that avoids plain fare (needs.json food.plain_fare; the GDD's 26.8 d a game day). Sells furs for coin if short.
func _buy_food() -> bool:
	if policy == "careless" and SurvivalInventory.meals(core) > 0.0:
		return false
	# The v4 round never buys food for coin: the self-sufficient player lives from the woods, the barterer and the
	# apprentice trade goods for it (_trade_rounds).
	if V4_POLICIES.has(policy):
		return false
	_go(STORE)
	var want_kcal := maxf(0.0, BUY_MEALS - SurvivalInventory.meals(core)) * 800.0
	var plan := [["item.food.cornmeal", want_kcal * 0.7 / 330.0], ["item.food.salt_pork", want_kcal * 0.3 / 440.0]]
	var cost := 0.0
	for pair in plan:
		cost += float(SurvivalEconomy.buy_unit(core, "mkt.fort_sutler", str(pair[0])).get("unit_d", 0.0)) * ceilf(float(pair[1]))
	if SurvivalEconomy.money(core) < int(cost) + 6:
		_raise_coin(int(cost) + 6)
	while SurvivalInventory.count(core, "item.remedy.bandage") < 2.0 and SurvivalEconomy.money(core) > int(cost) + 6:
		if not bool(SurvivalEconomy.buy(core, "mkt.fort_sutler", "item.remedy.bandage", 1.0, "coin").get("ok", false)):
			break
	var bought := false
	for pair in plan:
		for i in int(ceilf(float(pair[1]))):
			var r := SurvivalEconomy.buy(core, "mkt.fort_sutler", str(pair[0]), 1.0, "coin")
			if not bool(r.get("ok", false)):
				r = SurvivalEconomy.buy(core, "mkt.fort_sutler", str(pair[0]), 1.0, "book")
				if not bool(r.get("ok", false)):
					break
			bought = true
	return bought


## Sell dried furs to the sutler for coin, one at a time, until `need` pence are in hand.
func _raise_coin(need: int) -> void:
	var guard := 0
	while SurvivalEconomy.money(core) < need and guard < 60:
		guard += 1
		var sold := false
		for st in core.state.inventory:
			var cat := core.data.item_cat(str(st.id))
			if (cat == "pelt" or cat == "skin") and not bool(SurvivalUtil.dict(st.meta).get("green", false)):
				var r := SurvivalEconomy.sell(core, "mkt.fort_sutler", str(st.id), 1.0, "coin")
				sold = bool(r.get("ok", false))
				break
		if not sold:
			return


## Sell dried furs and skins at a market. take "book" at the trader pays the book first; "coin" takes coin.
func _sell_furs(mkt: String, take: String) -> void:
	if not SurvivalEconomy.is_open(core, mkt):
		return
	var ids := {}
	for st in core.state.inventory:
		var cat := core.data.item_cat(str(st.id))
		if (cat == "pelt" or cat == "skin") and not bool(SurvivalUtil.dict(st.meta).get("green", false)):
			ids[str(st.id)] = true
	for id in ids.keys():
		var r := SurvivalEconomy.sell(core, mkt, str(id), -1.0, take)
		if bool(r.get("ok", false)):
			_log("sold %s: %s" % [str(id), str(r.get("total_d"))])


## Sell raw meat beyond what we keep through the sutler's meat channel; the rest is shared out (meat is food and a gift
## first: livelihoods.json hunting_reference) [D].
func _sell_meat() -> void:
	var lb := SurvivalInventory.count(core, "item.food.venison_raw")
	if lb <= MEAT_KEEP_LB:
		return
	if SurvivalEconomy.is_open(core, "mkt.fort_sutler"):
		SurvivalEconomy.sell(core, "mkt.fort_sutler", "item.food.venison_raw", lb - MEAT_KEEP_LB, "coin")
	var left := SurvivalInventory.count(core, "item.food.venison_raw") - MEAT_KEEP_LB
	if left > 0.0:
		SurvivalInventory.remove(core, "item.food.venison_raw", left)
		core.state.stats["meat_given_lb"] = SurvivalUtil.num(core.state.stats.get("meat_given_lb"), 0.0) + left


## Trade days: the fall credit, the trader's visits and the spring settlement.
func _trade_day() -> bool:
	if not SurvivalEconomy.is_open(core, "mkt.visiting_trader"):
		return false
	_go(STORE)
	if SurvivalEconomy.can_take_outfit(core).ok and policy != "woodcutter":
		var r := core.run_job("trade.take_credit", {"basket": _outfit_basket()})
		_log("outfit: %s" % str(r.get("outfit", r)))
	# Some coin for the store when the purse is thin (coin at the coin rate), the rest onto the book.
	if SurvivalEconomy.money(core) < 60:
		var guard := 0
		while SurvivalEconomy.money(core) < 120 and _has_dried_furs() and guard < 40:
			guard += 1
			for st in core.state.inventory:
				var cat := core.data.item_cat(str(st.id))
				if (cat == "pelt" or cat == "skin") and not bool(SurvivalUtil.dict(st.meta).get("green", false)):
					SurvivalEconomy.sell(core, "mkt.visiting_trader", str(st.id), 1.0, "coin")
					break
	_sell_furs("mkt.visiting_trader", "book")
	# At the spring settlement, take book credit as coin for the summer (the trader will not be back until September).
	if SurvivalClock.event_active(core, "event.spring_trade"):
		var credit0 := -SurvivalEconomy.balance(core, SurvivalEconomy.TRADER_ID)
		if credit0 > 0.0 and SurvivalEconomy.money(core) < 300:
			SurvivalEconomy.draw_book_credit(core, minf(credit0, 700.0))
	# Pay the sutler's tally in coin when it falls due.
	if SurvivalEconomy.balance(core, SurvivalEconomy.SUTLER_ID) > 0.0 and SurvivalClock.event_active(core, "event.spring_trade"):
		if SurvivalEconomy.money(core) < int(SurvivalEconomy.balance(core, SurvivalEconomy.SUTLER_ID)):
			var credit := -SurvivalEconomy.balance(core, SurvivalEconomy.TRADER_ID)
			if credit > 0.0:
				SurvivalEconomy.draw_book_credit(core, credit)
		SurvivalEconomy.pay(core, SurvivalEconomy.SUTLER_ID, SurvivalEconomy.balance(core, SurvivalEconomy.SUTLER_ID))
	for c in [SurvivalEconomy.COUNTY_ID]:
		if SurvivalEconomy.balance(core, c) > 0.0:
			SurvivalEconomy.pay(core, c, SurvivalEconomy.balance(core, c))
	# Restock powder and lead from the book when low (the trader's tariff).
	if SurvivalInventory.count(core, "item.ammo.ball") < 6.0:
		SurvivalEconomy.buy(core, "mkt.visiting_trader", "item.ammo.ball", 10.0, "book")
	_ensure_food_supply()
	_rest(60.0)
	return true


## What each policy takes on the trader's book in the fall: the trapper the design's typical outfit, the hunter powder
## and lead only.
func _outfit_basket() -> Dictionary:
	if policy == "hunter":
		return {"item.ammo.powder": 2, "item.ammo.lead": 4, "item.ammo.ball": 20}
	return SurvivalUtil.dict(core.data.section("economy", "settlement").get("typical_basket")).duplicate()


func _muster_day() -> bool:
	if not SurvivalClock.event_active(core, "event.militia_muster"):
		return false
	var has_ob := false
	for ob in SurvivalUtil.arr(core.state.economy.get("obligations")):
		if str(ob.get("status", "")) == "pending":
			has_ob = true
	if not has_ob:
		return false
	_go("poi.fort.parade_ground")
	SurvivalEconomy.fulfil_obligation(core, "militia_muster")
	_rest(240.0)
	return true


# ---------------------------------------------------------------- policies
func _day_idle() -> void:
	_go(CAMP)
	_make_fire()
	_ensure_food_supply()
	_go(CAMP)
	while _time_left_min() > 60.0 and not core.is_dead():
		_feed_fire()
		_rest(60.0)
		_ensure()


func _day_careless() -> void:
	_go(CAMP)
	while _time_left_min() > 60.0 and not core.is_dead():
		core.set_activity("walk")
		core.advance(60.0)
		_track_warmth()
		_ensure()


func _day_woodcutter() -> void:
	_ensure_food_supply()
	if _trade_day():
		pass
	_muster_day()
	if SurvivalEconomy.contract_open(core):
		_go(WOODPILE)
		while _time_left_min() > 30.0 and not core.is_dead() and SurvivalEconomy.contract_open(core):
			var r := _job("wood.split_firewood")
			if r.has("reasons"):
				break
			if SurvivalInventory.count(core, "item.fuel.split_wood") >= SurvivalEconomy.ARMLOADS_PER_CORD:
				SurvivalEconomy.deliver_firewood(core, SurvivalInventory.count(core, "item.fuel.split_wood"))
			_ensure()
		SurvivalEconomy.deliver_firewood(core, SurvivalInventory.count(core, "item.fuel.split_wood"))
	else:
		_go(CAMP)
		_hunt_day(3)
		_go(STORE)


func _day_hunter() -> void:
	_trade_day()
	_muster_day()
	_food_security()
	var m := SurvivalClock.month_id(core)
	if ["oct", "nov", "dec", "jan"].has(m):
		_go(CAMP)
		_hunt_day()
	elif SurvivalEconomy.contract_open(core):
		_go(WOODPILE)
		_firewood_hours(_time_left_min() - 60.0)
	else:
		_go(CAMP)
		_hunt_day(2)
	_go(CAMP)
	if _time_left_min() > 60.0:
		_rest(_time_left_min() - 30.0)


func _day_trapper() -> void:
	_trade_day()
	_muster_day()
	_food_security()
	_go(CAMP)
	var in_season := SurvivalClock.gate_active(core, "trapping_season")
	var m := SurvivalClock.month_id(core)
	if in_season:
		_bank_before_leaving()
		_walk_line()
		if _time_left_min() > 90.0 and SurvivalTrapLine.traps(core).size() < line_size:
			_extend_line()
		if _time_left_min() > 180.0 and ["nov", "dec", "jan"].has(m):
			_hunt_day(1)
	elif m == "apr" and not SurvivalTrapLine.traps(core).is_empty():
		_pull_line()
	elif ["sep", "oct"].has(m):
		_prepare_line()
		if m == "oct" and _time_left_min() > 180.0:
			_hunt_day(2)
		if _time_left_min() > 180.0 and SurvivalEconomy.contract_open(core):
			_go(WOODPILE)
			_firewood_hours(_time_left_min() - 90.0)
	else:
		_hunt_day(1)
		if _time_left_min() > 180.0 and SurvivalEconomy.contract_open(core):
			_go(WOODPILE)
			_firewood_hours(_time_left_min() - 90.0)
	# Out of season, the rest of the day is camp work and rest.
	_go(CAMP)
	if not in_season and _time_left_min() > 60.0:
		_rest(_time_left_min() - 30.0)


func _firewood_hours(minutes: float) -> void:
	var t0 := core.state.minutes
	while minutes - (core.state.minutes - t0) > 5.0 and not core.is_dead() and SurvivalEconomy.contract_open(core):
		var r := _job("wood.split_firewood")
		if r.has("reasons"):
			break
		if SurvivalInventory.count(core, "item.fuel.split_wood") >= SurvivalEconomy.ARMLOADS_PER_CORD:
			SurvivalEconomy.deliver_firewood(core, SurvivalEconomy.ARMLOADS_PER_CORD)
		_ensure()


## Before the season: a lean-to and bough bed at the line camp, and stake sets for the deadfalls.
func _prepare_line() -> void:
	_go(CAMP)
	if SurvivalCamp.shelter_at(core, CAMP).is_empty():
		_job("shelter.brush_leanto")
	var steel := int(SurvivalInventory.count(core, "item.trap.steel"))
	var want := maxi(0, line_size - steel)
	var guard := 0
	while SurvivalInventory.count(core, "item.trap.stake_set") < float(want) and _time_left_min() > 60.0 and guard < 20:
		guard += 1
		var r := _job("craft.stakes")
		if r.has("reasons"):
			break


## Check every trap: walk the line cell by cell, collect and re-set, skin and dress what was caught.
func _walk_line() -> void:
	var by_cell := {}
	for tid0 in SurvivalTrapLine.trap_ids(core):
		var t := SurvivalTrapLine.trap(core, tid0)
		var c := int(t.cell)
		if not by_cell.has(c):
			by_cell[c] = []
		by_cell[c].append(str(t.id))
	var cells := by_cell.keys()
	cells.sort()
	for c in cells:
		if core.is_dead() or _time_left_min() < 20.0:
			break
		for tid in by_cell[c]:
			if not SurvivalTrapLine.traps(core).has(tid):
				continue
			_go_cell(int(c))
			var r := _job("trap.check", {"trap_id": tid})
			var cid := str(r.get("carcass_id", ""))
			if cid != "":
				_process_carcass(cid)
			if str(SurvivalTrapLine.trap(core, tid).get("state", "")) == "sprung" and _time_left_min() > 20.0:
				_job("trap.check", {"trap_id": tid})
			_ensure()
	_go(CAMP)


## Out for the day in the cold months: the camp's fire banked first (fire.bank: coals for 10-12 game hours), so the
## trapper comes back to coals to feed, not ashes to strike a fire on with numb hands. (The stack no longer outlasts
## the night since the core feeds a fire from it as it should; the fire is out by mid-morning without this.)
func _bank_before_leaving() -> void:
	if policy == "careless" or SurvivalClock.season(core) == "summer" or str(core.state.context.get("location", "")) != CAMP:
		return
	var f := SurvivalCamp.current_fire(core)
	if not f.is_empty() and str(f.state) == "lit":
		core.run_job("fire.bank")


func _process_carcass(cid: String) -> void:
	var rec := SurvivalCamp.carcass(core, cid)
	if rec.is_empty():
		return
	if SurvivalCamp.carcass_has_pelt(core, rec) and not bool(rec.skinned):
		_job("fur.skin", {"carcass_id": cid})
	if SurvivalCamp.carcasses(core).has(cid) and not bool(SurvivalCamp.carcass(core, cid).get("dressed", false)):
		_job("butcher.field_dress", {"carcass_id": cid})


func _stretch_all() -> void:
	var guard := 0
	while guard < 30 and not core.is_dead():
		guard += 1
		var st := SurvivalJobs._pick_green(core, {})
		if st.is_empty():
			return
		var r := _job("fur.stretch")
		if r.has("reasons"):
			return


## Set new traps: steel traps first, then deadfalls with stake sets, spread over the cells' good and fair sites. A
## skilled trapper reads sign first (hunt.track: +0.5 placement for two game days).
func _extend_line() -> void:
	var skilled := SurvivalSkills.level(core, "hunting") >= 45.0
	var cells := SurvivalTrapLine.cell_count(core)
	var guard := 0
	while SurvivalTrapLine.traps(core).size() < line_size and _time_left_min() > 45.0 and guard < 30 and not core.is_dead():
		guard += 1
		var n := SurvivalTrapLine.traps(core).size()
		var cell := n % cells
		var site := SurvivalTrapLine.best_free_site(core, cell)
		var kind := ""
		if SurvivalInventory.has(core, "item.trap.steel"):
			kind = "trap.steel_land_set"
		elif SurvivalInventory.has(core, "item.trap.stake_set"):
			kind = "trap.deadfall_set"
		else:
			_go(CAMP)
			var cr := _job("craft.stakes")
			if cr.has("reasons"):
				return
			continue
		_go_cell(cell)
		if skilled and not SurvivalTrapLine.has_fresh_sign(core, cell, "deadfall" if kind == "trap.deadfall_set" else "steel_land"):
			_job("hunt.track", {"cell": cell})
		var bait := "offal" if SurvivalInventory.has(core, "item.bait.offal") else "none"
		_job(kind, {"cell": cell, "site": site, "bait": bait})
		_ensure()
	_go(CAMP)


## End of the season: take up the steel traps; deadfalls are left to fall.
func _pull_line() -> void:
	for tid in SurvivalTrapLine.traps(core).keys().duplicate():
		SurvivalTrapLine.remove_trap(core, str(tid), true)
	_log("pulled the line")


## Hunt deer: read sign for a trail, stalk, shoot (the harness stands in for the player), dress, carry the meat and
## hide home, sell what the mess will take.
func _hunt_day(max_attempts: int = 4) -> void:
	var attempts := 0
	while attempts < max_attempts and _time_left_min() > STALK_MIN + 60.0 and not core.is_dead():
		attempts += 1
		if SurvivalInventory.count(core, "item.ammo.ball") < 1.0 or SurvivalInventory.count(core, "item.ammo.powder") < POWDER_LB_PER_SHOT:
			return
		var cell := rng.randi_range(0, SurvivalTrapLine.cell_count(core) - 1)
		_go_cell(cell)
		var r := _job("hunt.track", {"cell": cell})
		if not bool(r.get("deer_trail", false)):
			continue
		_walk(STALK_MIN, "crouch")
		var p := KILL_P_BASE + KILL_P_SKILL * SurvivalSkills.level(core, "hunting") / 100.0
		SurvivalInventory.remove(core, "item.ammo.ball", 1.0)
		SurvivalInventory.remove(core, "item.ammo.powder", POWDER_LB_PER_SHOT)
		core.report_weapon_event("marksmanship", "reload_complete_no_threat")
		if rng.randf() >= p:
			continue
		var clean := rng.randf() < 0.7
		var cid := core.report_kill("deer", {"clean": clean, "unaware": true, "shot_quality": 1.0 if clean else 0.85,
				"weapon": "musket", "cell": cell, "location": str(core.state.context.get("location", ""))})
		core.report_weapon_event("marksmanship", "hit_beyond_30m")
		_job("butcher.field_dress", {"carcass_id": cid})
		_go(STORE)
		_sell_meat()
		_ensure_food_supply()
		_go(CAMP)
	_go(CAMP)


# ---------------------------------------------------------------- v4 policies: living from the woods, barter, lessons
## One game day of the v4 round: camp chores, trade and lessons (the barterer and the apprentice), then the working day
## by priority until the light goes: food when short, the line in its season, green hides before they slip, the
## half-faced camp before the cold, meat and hides, fibre and cordage, the cache, moccasins and mitts, snowshoes, jerky,
## nuts and groundnuts, ice fishing, chinking.
func _day_v4() -> void:
	_go(CAMP)
	_camp_chores()
	if policy != "self_sufficient":
		_trade_rounds()
	if policy == "apprentice":
		_work_off_labour()
	var guard := 0
	while _time_left_min() > 40.0 and not core.is_dead() and guard < 30:
		guard += 1
		_ensure()
		if not _v4_task():
			break
	if policy == "apprentice":
		_learn_rounds()
	_go(CAMP)
	if _time_left_min() > 60.0:
		_rest(_time_left_min() - 30.0)


func _month() -> String:
	return SurvivalClock.month_id(core)


func _today() -> int:
	return SurvivalClock.abs_day(core)


func _food_store() -> float:
	return SurvivalAlmanac.food_meals(core)


func _knows(kid: String) -> bool:
	return SurvivalLearning.state_of(core, kid) != "unknown"


func _state(kid: String) -> String:
	return SurvivalLearning.state_of(core, kid)


func _usable(item: String) -> float:
	return SurvivalInventory.count_usable(core, item)


func _ok(action: String, params: Dictionary = {}) -> bool:
	return bool(core.preview(action, params).get("ok", false))


## A job the harness runs only when it can start; true when time was spent.
func _try(action: String, params: Dictionary = {}) -> bool:
	if not _ok(action, params):
		return false
	var r := _job(action, params)
	return r.has("outcome") or r.has("interrupted")


func _shelter_q() -> float:
	return SurvivalUtil.num(SurvivalCamp.shelter_at(core, CAMP).get("quality"), 0.0)


## Camp chores morning and evening: take the cured jerky down, keep the pack light and the store in the cache, mend worn
## moccasins and mitts, stuff moccasins in the cold.
func _camp_chores() -> void:
	if str(core.state.context.get("location", "")) != CAMP or core.is_dead():
		return
	SurvivalCamp.rack_take_ready(core)
	# Wood carried in goes on the stack by the fire (a bundle kept for a fire elsewhere).
	var f := SurvivalCamp.fire_at(core, CAMP)
	if not f.is_empty():
		for pair in [["item.fuel.bundle", 0.0], ["item.fuel.split_wood", 0.0]]:
			var extra_f := SurvivalInventory.count(core, str(pair[0])) - float(pair[1])
			if extra_f >= 1.0:
				SurvivalCamp.stack_fuel(core, str(f.id), str(pair[0]), floorf(extra_f))
	var c := SurvivalCamp.cache_at(core, CAMP)
	if not c.is_empty():
		for pair in [["item.food.venison_raw", 6.0], ["item.food.smallgame_raw", 4.0], ["item.food.nuts", 20.0], ["item.food.jerky", 4.0],
				["item.food.venison_cooked", 4.0], ["item.food.smallgame_cooked", 2.0], ["item.food.fish_cooked", 2.0],
				["item.food.fish_raw", 4.0], ["item.food.groundnut", 16.0], ["item.food.acorns", 0.0], ["item.food.acorn_meal", 2.0],
				["item.food.cornmeal", 6.0], ["item.food.salt_pork", 3.0], ["item.food.flour", 4.0], ["item.food.sauerkraut", 2.0],
				["item.food.dried_apples", 2.0], ["item.bait.offal", 1.0]]:
			var extra := _usable(str(pair[0])) - float(pair[1])
			if extra > 0.5:
				SurvivalCamp.cache_store(core, str(c.id), str(pair[0]), extra)
		# Materials not needed on the trail: splints and spare rawhide once the snowshoes are made, spare cordage.
		if SurvivalInventory.has(core, "item.tool.snowshoes"):
			for pair2 in [["item.material.ash_splints", 0.0], ["item.material.rawhide", 1.0]]:
				var extra2 := _usable(str(pair2[0])) - float(pair2[1])
				if extra2 > 0.5:
					SurvivalCamp.cache_store(core, str(c.id), str(pair2[0]), extra2)
		# Furs and dried skins wait in the cache for the trader, out of the pack; one stays in the pack for mitts while
		# fewer than two pairs are carried (a dried deerskin or a pelt, F4).
		var mitt_keep := 0.0 if SurvivalInventory.has(core, "item.cloth.mitts", 2.0) else 1.0
		for st in core.state.inventory.duplicate():
			var cat := core.data.item_cat(str(st.id))
			if (cat == "pelt" or cat == "skin") and SurvivalInventory.usable(st) and not bool(SurvivalUtil.dict(st.meta).get("green", false)) \
					and str(st.id) != "item.skin.dressed_buckskin":
				var keep := minf(mitt_keep, float(st.qty))
				mitt_keep -= keep
				if float(st.qty) - keep > 0.5:
					SurvivalCamp.cache_store(core, str(c.id), str(st.id), float(st.qty) - keep)
		_refill_pack_from_cache(c)
	_dress_up()
	if SurvivalInventory.needs_mending(core, ["item.cloth.moccasins", "item.cloth.mitts", "item.tool.snowshoes"]) and SurvivalInventory.wear_of(core, "item.cloth.moccasins") > 0.5:
		_try("clothing.repair_moccasins")
	if SurvivalClock.air_temp_c(core) < -5.0 and not core.state.flags.has("feet_ins_add"):
		_try("clothing.stuff_moccasins")


## Take food from the camp's cache into the pack until it holds PACK_MEALS: what spoils first leads (fresh and cooked
## meat, fish), then the rest; any food the cache holds counts.
func _refill_pack_from_cache(c: Dictionary) -> void:
	var guard := 0
	while SurvivalInventory.meals(core) < PACK_MEALS and guard < 12 and not c.is_empty():
		guard += 1
		var order := []
		for st in SurvivalUtil.arr(c.get("items")):
			if SurvivalInventory.is_food(core, str(st.id)) and not order.has(str(st.id)):
				order.append(str(st.id))
		if order.is_empty():
			return
		order.sort_custom(func(a, b): return _spoil_rank(str(a)) < _spoil_rank(str(b)) or (_spoil_rank(str(a)) == _spoil_rank(str(b)) and str(a) < str(b)))
		var got := 0.0
		for it in order:
			var kcal := maxf(1.0, SurvivalUtil.num(core.data.item(str(it)).get("kcal"), 100.0))
			got += SurvivalCamp.cache_take(core, str(c.id), str(it), ceilf(800.0 * 2.0 / kcal))
			if SurvivalInventory.meals(core) >= PACK_MEALS:
				break
		if got <= 0.0:
			return


func _spoil_rank(item: String) -> int:
	var sp := str(core.data.item(item).get("spoil", ""))
	if sp.contains("fresh") or sp.contains("cooked") or sp.contains("fish"):
		return 0
	return 1


## Hungry with an empty pack at the camp: the cache is the larder.
func _eat_from_cache() -> bool:
	if str(core.state.context.get("location", "")) != CAMP:
		return false
	var c := SurvivalCamp.cache_at(core, CAMP)
	if c.is_empty():
		return false
	var before := SurvivalInventory.meals(core)
	_refill_pack_from_cache(c)
	return SurvivalInventory.meals(core) > before


## How often a task ran today (the round spreads the day over its work).
## What the camp's cache holds of an item.
func _cached(item: String) -> float:
	var c := SurvivalCamp.cache_at(core, CAMP)
	var n := 0.0
	if not c.is_empty():
		for st in SurvivalUtil.arr(c.get("items")):
			if str(st.id) == item:
				n += float(st.qty)
	return n


## The pack's weight: what is carried less the clothes worn and the long arm in hand (T12's "pack").
func pack_kg() -> float:
	var kg := SurvivalInventory.weight_kg(core)
	var worn_done := {}
	for st in core.state.inventory:
		var it := core.data.item(str(st.id))
		var w := SurvivalUtil.num(it.get("kg"), 0.0)
		if str(it.get("cat", "")) == "weapon":
			kg -= w * float(st.qty)
		elif core.state.worn.has(str(st.id)) and not worn_done.has(str(st.id)):
			worn_done[str(st.id)] = true
			kg -= w
	return maxf(0.0, kg)


func _did(task: String) -> int:
	var d: Dictionary = _day.get("did", {})
	return int(d.get(task, 0))


func _count(task: String) -> void:
	if not _day.has("did"):
		_day["did"] = {}
	_day.did[task] = _did(task) + 1


func _v4_task() -> bool:
	var m := _month()
	var food := _food_store()
	var in_line := SurvivalClock.gate_active(core, "trapping_season")
	if food < 4.0:
		# Short of food: in the deep winter the surest pot first (a line through the ice), then the hunt; in the open
		# months the hunt first (a deer is a week's food), then a line in open water and the woods.
		if ["dec", "jan", "feb", "mar"].has(m):
			if _cast_balls() or _ice_fish() or _hunt_v4(1) or _gather_food(true):
				return true
		elif _cast_balls() or _hunt_v4(1) or _open_fish() or _gather_food(true):
			return true
	# The winter camp first: up to two stages (or trial attempts, while it is only heard of) a day until it stands.
	if ["sep", "oct", "nov", "dec"].has(m) and _shelter_q() < 4.0 and _knows("shelter.half_faced_camp") and _did("camp") < 2:
		_count("camp")
		_go(CAMP)
		if _try("shelter.half_faced_camp"):
			return true
	if SurvivalUtil.num(SurvivalCamp.shelter_at(core, CAMP).get("gaps"), 0.0) > 0.0 and _did("chink") < 2:
		_count("chink")
		_go(CAMP)
		if _try("shelter.chink_bank"):
			return true
	# A hung cache as soon as there is cordage for it: the store lives there, not in the pack (T12). Fibre or sinew in
	# hand is twisted into the two cords it needs first (fix round 1: the fall hunt used to crowd the cordage out).
	if SurvivalCamp.cache_at(core, CAMP).is_empty() and _did("cache") < 2:
		if _usable("item.material.cordage") < 2.0 and _did("cache_cord") < 3:
			_count("cache_cord")
			if _try("craft.cordage"):
				return true
		if _usable("item.material.cordage") >= 2.0:
			_count("cache")
			_go(CAMP)
			if _try("preserve.cache_pit"):
				_camp_chores()
				return true
	# Six cords in hand before the fur season (T4): twisted from fibre or sinew already carried.
	if _usable("item.material.cordage") < SurvivalAlmanac.READY_CORDAGE and _did("cord6") < 2 \
			and (_usable("item.material.hemp_fibre") >= 1.0 or _usable("item.material.sinew") >= 3.0):
		_count("cord6")
		if _try("craft.cordage"):
			return true
	# The fall's plant food: nuts while they last, a couple of hours a day (redesign_economy.md 5.4).
	if ["sep", "oct", "nov"].has(m) and food < 70.0 and _did("nuts") < 3:
		_count("nuts")
		_go(CAMP)
		if _try("forage.search", {"item": "item.food.nuts"}):
			return true
	# Snowshoes before the deep snow (T4: by Early January): a stage a day from October while the store is not short.
	if ["oct", "nov", "dec", "jan"].has(m) and not SurvivalInventory.has(core, "item.tool.snowshoes") and _knows("know.snowshoes") \
			and _did("snowshoes") < 1 and food >= 12.0:
		_count("snowshoes")
		if _usable("item.material.ash_splints") < 2.0:
			if _try("craft.snowshoes", {"recipe": "rcp.ash_splints"}):
				return true
		elif _try("craft.snowshoes", {"recipe": "rcp.snowshoes"}):
			return true
	# The line is walked every day it stands, in the fur season and out of it: the snares and deadfalls take hares and
	# other small game for the pot all year (fix round 1: the harness stopped at the end of March, F2). Out of the fur
	# season it is extended only when food is short.
	if (in_line or not SurvivalTrapLine.traps(core).is_empty()) and int(v4.get("walked_line_day", -1)) != _today():
		v4["walked_line_day"] = _today()
		_walk_line()
		if _time_left_min() > 60.0 and (in_line or food < HUNT_BELOW_MEALS):
			_extend_line_v4()
		return true
	if _usable("item.material.green_hide") >= 1.0 and _process_hide():
		return true
	# Footwear before anything else: a pair on and a spare, from the first buckskin; in October and November a third
	# pair, since a pair lasts about 8 game days of walking (F5).
	var moc_want := 3.0 if ["oct", "nov"].has(m) else 2.0
	if _usable("item.cloth.moccasins") < moc_want and _usable("item.skin.dressed_buckskin") >= 0.33 and _usable("item.material.sinew") >= 1.0 \
			and _try("craft.moccasins"):
		return true
	# Mitts before the cold (T4): sewn from a dried deerskin, a pelt or buckskin as soon as one is at hand (F4).
	if not SurvivalInventory.has(core, "item.cloth.mitts") and _did("mitts") < 2 and not _ok("clothing.sew_mitts", {"recipe": "rcp.mitts_fur"}):
		_mitt_material_from_cache()
	if not SurvivalInventory.has(core, "item.cloth.mitts") and _did("mitts") < 2 and _ok("clothing.sew_mitts", {"recipe": "rcp.mitts_fur"}):
		_count("mitts")
		if _try("clothing.sew_mitts", {"recipe": "rcp.mitts_fur"}):
			return true
	# The fall builds the winter store (T4: 20 meals in store by Late November); after that, hunt when it runs low.
	if food < (HUNT_BELOW_MEALS + 16.0 if ["oct", "nov"].has(m) else HUNT_BELOW_MEALS) and _cast_balls():
		return true
	if food < (HUNT_BELOW_MEALS + 16.0 if ["oct", "nov"].has(m) else HUNT_BELOW_MEALS) and _did("hunt") < (2 if ["oct", "nov"].has(m) else 1):
		_count("hunt")
		if _hunt_v4(1):
			return true
	if food < (30.0 if ["apr", "may", "jun", "jul", "aug"].has(m) else HUNT_BELOW_MEALS) and _open_fish():
		return true
	if ["sep", "oct", "nov"].has(m) and _usable("item.material.cordage") + 3.0 * _usable("item.material.hemp_fibre") < CORDAGE_TARGET and _did("bottomland") < 1:
		_count("bottomland")
		if _bottomland_trip(true):
			return true
	if _usable("item.material.cordage") < CORDAGE_TARGET and (_usable("item.material.hemp_fibre") >= 1.0 or _usable("item.material.sinew") >= 4.0):
		if _try("craft.cordage"):
			return true
	if _usable("item.skin.dressed_buckskin") >= 0.33 and _usable("item.material.sinew") >= 1.0 and _usable("item.cloth.moccasins") < MOCCASINS_TARGET:
		if _try("craft.moccasins"):
			return true
	if (not SurvivalInventory.has(core, "item.cloth.mitts") or (SurvivalInventory.wear_of(core, "item.cloth.mitts") > 0.7 \
			and _usable("item.cloth.mitts") < 2.0)) and _did("mitts") < 1:
		_count("mitts")
		if _try("clothing.sew_mitts") or _try("clothing.sew_mitts", {"recipe": "rcp.mitts_fur"}):
			return true
	if _usable("item.food.venison_raw") + _cached("item.food.venison_raw") >= 10.0 and not ["dec", "jan", "feb"].has(m) and _knows("rcp.jerky") and _did("jerky") < 2:
		_count("jerky")
		var cc := SurvivalCamp.cache_at(core, CAMP)
		if not cc.is_empty() and _usable("item.food.venison_raw") < 10.0:
			SurvivalCamp.cache_take(core, str(cc.id), "item.food.venison_raw", 10.0 - _usable("item.food.venison_raw"))
		if _make_fire() and _try("preserve.jerk_scaffold", {"recipe": "rcp.jerky"}):
			return true
	# Fish beyond a day's eating is split and smoked on the same rack (rcp.smoked_fish, fix round 1): a store for the
	# spring and summer, and Provisions practice.
	if _usable("item.food.fish_raw") + _cached("item.food.fish_raw") >= 6.0 and _did("smoke_fish") < 1:
		_count("smoke_fish")
		_go(CAMP)
		var cf := SurvivalCamp.cache_at(core, CAMP)
		if not cf.is_empty() and _usable("item.food.fish_raw") < 6.0:
			SurvivalCamp.cache_take(core, str(cf.id), "item.food.fish_raw", 6.0 - _usable("item.food.fish_raw"))
		if _make_fire() and _try("preserve.jerk_scaffold", {"recipe": "rcp.smoked_fish"}):
			return true
	if food < GATHER_BELOW_MEALS and _did("gather") < 3:
		_count("gather")
		if _gather_food(false):
			return true
	if ["mar", "apr", "may"].has(m) and food < 12.0 and _did("spring_hunt") < 1:
		_count("spring_hunt")
		if _hunt_v4(1):
			return true
	if ["jan", "feb", "mar"].has(m) and food < 25.0 and _ice_fish():
		return true
	if _acorns():
		return true
	if _try_heard_of():
		return true
	if ["nov", "dec", "jan", "feb"].has(m) and not SurvivalCamp.shelter_at(core, CAMP).is_empty() \
			and SurvivalUtil.num(SurvivalCamp.shelter_at(core, CAMP).get("wind_add"), 0.0) < 1.0 and _try("shelter.chink_bank"):
		return true
	return false


## Hunt deer for meat and hides without selling: read sign, stalk, shoot, dress, and carry it all to camp.
func _hunt_v4(max_attempts: int) -> bool:
	var spent := false
	var attempts := 0
	while attempts < max_attempts and _time_left_min() > STALK_MIN + 60.0 and not core.is_dead():
		attempts += 1
		if SurvivalInventory.count(core, "item.ammo.ball") < 1.0 or SurvivalInventory.count(core, "item.ammo.powder") < POWDER_LB_PER_SHOT:
			return spent
		spent = true
		var cell := rng.randi_range(0, SurvivalTrapLine.cell_count(core) - 1)
		_go_cell(cell)
		var r := _job("hunt.track", {"cell": cell})
		if not bool(r.get("deer_trail", false)):
			continue
		_walk(STALK_MIN, "crouch")
		var p := KILL_P_BASE + KILL_P_SKILL * SurvivalSkills.level(core, "hunting") / 100.0
		SurvivalInventory.remove(core, "item.ammo.ball", 1.0)
		SurvivalInventory.remove(core, "item.ammo.powder", POWDER_LB_PER_SHOT)
		core.report_weapon_event("marksmanship", "reload_complete_no_threat")
		if rng.randf() >= p:
			continue
		var clean := rng.randf() < 0.7
		var cid := core.report_kill("deer", {"clean": clean, "unaware": true, "shot_quality": 1.0 if clean else 0.85,
				"weapon": "musket", "cell": cell, "location": str(core.state.context.get("location", ""))})
		core.report_weapon_event("marksmanship", "hit_beyond_30m")
		_job("butcher.field_dress", {"carcass_id": cid})
		break
	_go(CAMP)
	_camp_chores()
	return spent


## A green deer hide: dressed into buckskin (brains or cornmeal, a lit fire) when it is known and buckskin is short,
## else scraped into rawhide; a hide nobody can work is stretched to dry as a skin for trade.
func _process_hide() -> bool:
	_go(CAMP)
	# No mitts and nothing to make them from: a hide dried with the hair on makes mittens (rcp.mitts_fur, F4).
	if not SurvivalInventory.has(core, "item.cloth.mitts") and not _has_mitt_material() and _knows("rcp.mitts_fur") \
			and _try("fur.stretch", {"item": "item.material.green_hide"}):
		return true
	var buck := SurvivalInventory.count(core, "item.skin.dressed_buckskin")
	var raw := _usable("item.material.rawhide")
	var need_raw := not SurvivalInventory.has(core, "item.tool.snowshoes") and raw < 2.0
	var want_buck := buck < 1.0 and (not need_raw or _usable("item.cloth.moccasins") < 2.0)
	if want_buck and _knows("know.hide_dressing") and (_usable("item.material.brains") >= 1.0 or _usable("item.food.cornmeal") >= 1.0):
		if _make_fire() and _try("craft.dress_hide", {"recipe": "rcp.dress_hide"}):
			return true
	if _knows("rcp.rawhide") and raw < 4.0 and _try("craft.dress_hide", {"recipe": "rcp.rawhide"}):
		return true
	if _knows("know.hide_dressing") and (_usable("item.material.brains") >= 1.0 or _usable("item.food.cornmeal") >= 1.0):
		if _make_fire() and _try("craft.dress_hide", {"recipe": "rcp.dress_hide"}):
			return true
	return _try("fur.stretch", {"item": "item.material.green_hide"})


## A dried deerskin or pelt out of the camp's cache for a pair of mitts (at the camp only).
func _mitt_material_from_cache() -> void:
	if str(core.state.context.get("location", "")) != CAMP:
		return
	var c := SurvivalCamp.cache_at(core, CAMP)
	if c.is_empty():
		return
	for it in SurvivalUtil.arr(SurvivalUtil.arr(core.data.recipe("rcp.mitts_fur").get("inputs_any"))[0]):
		if _cached(str(it)) >= 1.0 and SurvivalCamp.cache_take(core, str(c.id), str(it), 1.0) >= 1.0:
			return


func _has_mitt_material() -> bool:
	for it in SurvivalUtil.arr(SurvivalUtil.arr(core.data.recipe("rcp.mitts_fur").get("inputs_any"))[0]):
		if SurvivalCrafting.count_for(core, core.data.recipe("rcp.mitts_fur"), str(it)) >= 1.0 - 0.0001:
			return true
	# A green hide already stretched and drying counts: it will be a skin in a couple of game days.
	for st in core.state.inventory:
		if str(st.id) == "item.material.green_hide" and bool(SurvivalUtil.dict(st.meta).get("stretched", false)):
			return true
	return false


## Plant food: nuts under the groves near camp in the fall (dug from under the snow in winter when short), groundnuts,
## grapes and Indian hemp on the bottomland, ramps and groundnuts in April. urgent: any food will do.
func _gather_food(urgent: bool) -> bool:
	var m := _month()
	if ["sep", "oct", "nov"].has(m) or (urgent and ["dec", "jan", "feb"].has(m)):
		_go(CAMP)
		if _try("forage.search", {"item": "item.food.nuts"}):
			return true
	if ["sep", "oct", "nov", "apr"].has(m) and not SurvivalClock.season(core) == "winter":
		if _bottomland_trip(false):
			return true
	if m == "apr" or m == "may":
		_go(CAMP)
		if _try("forage.search", {"item": "item.food.ramps"}):
			return true
	if ["jun", "jul", "aug"].has(m):
		_go(CAMP)
		if _try("forage.search", {"item": "item.food.strawberries" if m == "jun" else "item.food.berries"}):
			return true
	if urgent and _open_fish():
		return true
	return false


## A trip to the bottomland: groundnuts, Indian hemp (fibre_first: the cordage is short), grapes.
func _bottomland_trip(fibre_first: bool) -> bool:
	var fib_ok := SurvivalClock.in_window(core, ["sep_mid", "nov_late"])
	var nut_ok := SurvivalClock.in_window(core, ["sep_early", "apr_late"])
	if not fib_ok and not nut_ok:
		return false
	_go(BOTTOMLAND)
	var did := false
	var reps := 0
	while reps < 3 and _time_left_min() > 50.0 and not core.is_dead():
		reps += 1
		var any := false
		if fib_ok and (fibre_first or _usable("item.material.cordage") + 3.0 * _usable("item.material.hemp_fibre") < CORDAGE_TARGET):
			if _try("forage.search", {"item": "item.material.hemp_fibre"}):
				any = true
		if nut_ok and not fibre_first and _try("forage.dig_groundnut"):
			any = true
		if not any:
			break
		did = true
	return did


func _ice_fish() -> bool:
	if not ["jan", "feb", "mar"].has(_month()) or SurvivalInventory.count(core, "item.tool.hooks_line") < 1.0 or _did("ice_fish") >= 3:
		return false
	_count("ice_fish")
	_go(BROOK)
	return _try("fish.ice_hole")


## Extend the line to TRAPS_V4: steel traps first, then snares (cordage to spare) and deadfalls (stakes cut on the spot).
func _extend_line_v4() -> void:
	var cells := SurvivalTrapLine.cell_count(core)
	var guard := 0
	while SurvivalTrapLine.traps(core).size() < TRAPS_V4 and _time_left_min() > 45.0 and guard < 20 and not core.is_dead():
		guard += 1
		var n := SurvivalTrapLine.traps(core).size()
		var cell := n % cells
		var kind := ""
		if SurvivalInventory.has(core, "item.trap.steel"):
			kind = "trap.steel_land_set"
		elif _knows("trap.snare_set") and _usable("item.material.cordage") >= SurvivalAlmanac.READY_CORDAGE + 3.0 and n % 2 == 1:
			kind = "trap.snare_set"
		elif SurvivalInventory.has(core, "item.trap.stake_set"):
			kind = "trap.deadfall_set"
		else:
			_go(CAMP)
			var cr := _job("craft.stakes")
			if cr.has("reasons"):
				return
			continue
		_go_cell(cell)
		var bait := "offal" if SurvivalInventory.has(core, "item.bait.offal") else "none"
		var r := _job(kind, {"cell": cell, "site": SurvivalTrapLine.best_free_site(core, cell), "bait": bait})
		if r.has("reasons"):
			break
		_ensure()
	_go(CAMP)


## Put on any carried garment whose slot is empty (mitts or a cap got by trade; what the player makes goes on by itself).
func _dress_up() -> void:
	for st in core.state.inventory.duplicate():
		SurvivalInventory.wear_if_slot_empty(core, str(st.id))


## Cast balls from bar lead at the camp fire when the pouch runs low (the hunter's mould and lead).
func _cast_balls() -> bool:
	if SurvivalInventory.count(core, "item.ammo.ball") >= BALLS_KEEP or _usable("item.ammo.lead") < 1.0 \
			or not SurvivalInventory.has(core, "item.tool.bullet_mould") or _did("cast") >= 1:
		return false
	_count("cast")
	_go(CAMP)
	if not _make_fire():
		return false
	return _try("craft.cast_balls", {"recipe": "rcp.cast_balls"})


## Hook and line in open water at the brook or the bottomland's ford: the spring runs and the summer (April to
## August); in the fall only when the musket cannot hunt (the fall's days go to the deer, a week's food each).
func _open_fish() -> bool:
	if SurvivalInventory.count(core, "item.tool.hooks_line") < 1.0 or _did("open_fish") >= 2:
		return false
	var can_shoot := SurvivalInventory.count(core, "item.ammo.ball") >= 1.0 and SurvivalInventory.count(core, "item.ammo.powder") >= POWDER_LB_PER_SHOT
	if ["sep", "oct", "nov"].has(_month()) and can_shoot:
		return false
	for poi in [BROOK, BOTTOMLAND]:
		_go(poi)
		if _ok("fish.hook_line"):
			_count("open_fish")
			return _try("fish.hook_line")
	return false


## Acorns in the fall (the oaks by the camp), leached at the brook once there are 30 handfuls (F10: the harness never
## gathered them, so nobody learned acorn meal). A little of it, never most of the plant food (T2).
func _acorns() -> bool:
	if not ["sep", "oct", "nov"].has(_month()) or _did("acorns") >= 1:
		return false
	_count("acorns")
	if _usable("item.food.acorns") < 30.0:
		_go(CAMP)
		return _try("forage.search", {"item": "item.food.acorns"})
	if _state("rcp.acorn_meal") == "unknown":
		_go(BROOK)
		SurvivalLearning.check_notices(core)
	if _knows("rcp.acorn_meal"):
		_go(BROOK)
		return _try("forage.leach_acorns", {"recipe": "rcp.acorn_meal"})
	return false


## Try each recipe heard of or seen once its materials are in hand, once a game day (F10: learning by trying).
func _try_heard_of() -> bool:
	if _did("try_recipe") >= 1:
		return false
	for rid in SurvivalUtil.sorted_ids(core.data.recipes):
		var st := _state(core.data.recipe_knowledge_id(str(rid)))
		if st != "heard_of" and st != "seen":
			continue
		var miss := SurvivalCrafting.missing(core, str(rid))
		miss.erase("station")
		if not miss.is_empty():
			continue
		var aid := str(core.data.recipe(str(rid)).get("action", ""))
		_count("try_recipe")
		_go(CAMP)
		if str(core.data.recipe(str(rid)).get("station", "")).begins_with("world.campfire") and not _make_fire():
			return false
		return _try(aid, {"recipe": str(rid)})
	return false


# ---------------------------------------------------------------- barter rounds (the barterer and the apprentice)
## Trade surplus with whoever is here today: the farm family on its market days (meat and skins for their stores), the
## trader on his visits (furs and skins for powder, balls, an axe, a kettle), the sutler (split wood for meal in the
## cold months), and the old hunter in the evening (meal for his cordage and rawhide).
func _trade_rounds() -> void:
	var farm := SurvivalEconomy.is_open(core, "mkt.farm_visit")
	var trader := SurvivalEconomy.is_open(core, "mkt.visiting_trader")
	if trader:
		_furs_from_cache()
	_trade_meat_from_cache()
	if farm or trader:
		_go(STORE)
		if _hour() < 8.0:
			_rest((8.0 - _hour()) * 60.0)
		if farm:
			_barter_farm()
		if trader:
			_barter_trader()
		_barter_kit()
		_barter_sutler()
		_go(CAMP)
	# Between market days the sutler is worth the walk only in the months she wants split wood (October to March), or
	# for a spare pair and mitts while she still stocks them (fix round 1: the barterer used to walk there every third
	# day in spring and summer for nothing).
	elif (SurvivalClock.day_of_year(core) % 3 == 0 and _food_store() < 30.0 and ["oct", "nov", "dec", "jan", "feb", "mar"].has(_month())) \
			or (_kit_short() and _did("kit_visit") < 1 and ["sep", "oct"].has(_month())):
		_count("kit_visit")
		_go(STORE)
		_barter_kit()
		_barter_sutler()
		_go(CAMP)


## Fresh venison beyond the store's needs goes to the store as a trade good while the kit is short (the cache is the
## larder; a barterer trades its surplus, F6).
func _trade_meat_from_cache() -> void:
	if not _kit_short() or not ["sep", "oct"].has(_month()) or _food_store() < SurvivalAlmanac.READY_MEALS:
		return
	var c := SurvivalCamp.cache_at(core, CAMP)
	if c.is_empty():
		return
	# Only what lies above the winter store's 20 meals is surplus (about 7 lb of fresh venison a meal).
	var above := (_food_store() - SurvivalAlmanac.READY_MEALS) * 800.0 / maxf(1.0, SurvivalUtil.num(core.data.item("item.food.venison_raw").get("kcal"), 110.0))
	var spare := minf(minf(40.0, _cached("item.food.venison_raw") - 15.0), above)
	if spare >= 10.0:
		_go(CAMP)
		SurvivalCamp.cache_take(core, str(c.id), "item.food.venison_raw", spare)


## The winter kit a barterer buys with surplus rather than makes (T5: trade speeds things up): a spare pair of
## moccasins and a pair of mitts while the sutler still stocks them (March to October).
func _kit_short() -> bool:
	return _usable("item.cloth.moccasins") < MOCCASINS_TARGET or not SurvivalInventory.has(core, "item.cloth.mitts")


func _barter_kit() -> void:
	var npc := "npc.fort.sutler"
	if not SurvivalTrade.partner_present(core, npc) or not _kit_short():
		return
	var gives := ["item.food.venison_raw", "item.food.jerky", "item.skin.deer_fall", "item.pelt.raccoon", "item.pelt.fox", "item.fuel.split_wood"]
	for want in [["item.cloth.mitts", 1.0 if not SurvivalInventory.has(core, "item.cloth.mitts") else 0.0],
			["item.cloth.moccasins", maxf(0.0, MOCCASINS_TARGET - _usable("item.cloth.moccasins"))]]:
		if float(want[1]) < 1.0:
			continue
		var got := false
		for give in gives:
			var keep := 10.0 if give == "item.food.venison_raw" else (4.0 if give == "item.food.jerky" else 0.0)
			if _barter_for(npc, give, _usable(give) - keep, str(want[0]), float(want[1])):
				got = true
				break
		# No goods to spare: a few hours' work in her stores, worked off at once (labour is a good she accepts; a pair of
		# moccasins is most of a day's work by October, when her winter prices rise).
		var h := 3.0
		while not got and h <= 9.0 and _time_left_min() > h * 60.0 + 30.0 and _food_store() >= 10.0:
			var r := SurvivalTrade.barter(core, npc, [["labour", h, "job.sutler_stores"]], [[str(want[0]), 1.0]])
			if bool(r.get("ok", false)):
				got = true
				v4["trades"] = int(v4.trades) + 1
				for ob in SurvivalTrade.obligations_of(core, core.state.player_id, true):
					if str(ob.kind) == "labour" and str(ob.to) == npc:
						var w := SurvivalTrade.work_off(core, str(ob.id), h * 60.0)
						v4["labour_h"] = float(v4.labour_h) + float(w.get("worked_min", 0.0)) / 60.0
				_ensure()
			h += 1.0
		if got:
			_dress_up()


## The trader is here: bring the dried furs and skins out of the camp's cache (the surplus; a pelt stays for mitts while
## fewer than two pairs are carried).
func _furs_from_cache() -> void:
	var c := SurvivalCamp.cache_at(core, CAMP)
	if c.is_empty():
		return
	_go(CAMP)
	var keep := 0.0 if SurvivalInventory.has(core, "item.cloth.mitts", 2.0) else 1.0
	for st in SurvivalUtil.arr(c.get("items")).duplicate():
		var cat := core.data.item_cat(str(st.id))
		if cat == "pelt" or (cat == "skin" and str(st.id) != "item.skin.dressed_buckskin"):
			var q := float(st.qty) - (keep if cat == "pelt" else 0.0)
			if cat == "pelt" and q < float(st.qty):
				keep = 0.0
			if q > 0.5:
				SurvivalCamp.cache_take(core, str(c.id), str(st.id), floorf(q))


func _barter(npc: String, give: Array, take: Array) -> bool:
	var r := SurvivalTrade.barter(core, npc, give, take)
	if bool(r.get("ok", false)):
		v4["trades"] = int(v4.trades) + 1
		_rest(10.0)
		return true
	return false


## Give as few units of `give_item` as buy `take_qty` of `take_item` (at most `max_give`), if the partner will deal.
func _barter_for(npc: String, give_item: String, max_give: float, take_item: String, take_qty: float) -> bool:
	var have := minf(max_give, _usable(give_item))
	if have < 1.0:
		return false
	var got := SurvivalTrade.quote_units(core, npc, give_item, have, take_item)
	if got < 1.0:
		return false
	var q := minf(got, take_qty)
	var give := ceilf(have * q / got)
	return _barter(npc, [[give_item, give]], [[take_item, q]])


func _barter_farm() -> void:
	var npc := "npc.valley.farm_family"
	if not SurvivalTrade.partner_present(core, npc):
		return
	# Surplus only (F6): fresh meat beyond a few days' eating and deerskins; the pelts go to the trader for time-savers.
	for take in [["item.food.cornmeal", 25.0], ["item.food.salt_pork", 6.0], ["item.food.sauerkraut", 6.0], ["item.food.dried_apples", 4.0]]:
		for give in ["item.food.venison_raw", "item.skin.deer_fall", "item.material.salt"]:
			var keep := 10.0 if give == "item.food.venison_raw" else 0.0
			if _barter_for(npc, give, _usable(give) - keep, str(take[0]), float(take[1])):
				break


func _barter_trader() -> void:
	var npc := "npc.post.trader"
	if not SurvivalTrade.partner_present(core, npc):
		return
	# Time-savers first (F6: an axe halves the camp's building time, steel traps work the line with fewer visits, a
	# kettle halves leaching), then powder and ball; furs beyond a pelt kept for mitts are the surplus.
	var wants := []
	if not SurvivalInventory.has(core, "item.tool.axe"):
		wants.append(["item.tool.axe", 1.0])
	if SurvivalInventory.count(core, "item.trap.steel") + float(SurvivalTrapLine.summary(core).steel) < 6.0:
		wants.append(["item.trap.steel", 2.0])
	if not SurvivalInventory.has(core, "item.tool.kettle_brass"):
		wants.append(["item.tool.kettle_brass", 1.0])
	wants.append(["item.ammo.ball", 20.0])
	wants.append(["item.ammo.powder", 1.0])
	var goods := []
	for st in core.state.inventory:
		var cat := core.data.item_cat(str(st.id))
		if (cat == "pelt" or cat == "skin") and SurvivalInventory.usable(st) and not bool(SurvivalUtil.dict(st.meta).get("green", false)):
			if str(st.id) == "item.skin.dressed_buckskin" and _usable("item.skin.dressed_buckskin") <= 1.0:
				continue
			if not goods.has(str(st.id)):
				goods.append(str(st.id))
	for w in wants:
		for g in goods:
			if _barter_for(npc, str(g), _usable(str(g)), str(w[0]), float(w[1])):
				break


func _barter_sutler() -> void:
	var npc := "npc.fort.sutler"
	if not SurvivalTrade.partner_present(core, npc) or not ["oct", "nov", "dec", "jan", "feb", "mar"].has(_month()):
		return
	# Split wood she wants in the cold months: a couple of hours at the woodpile first.
	_go(WOODPILE)
	var guard := 0
	while _usable("item.fuel.split_wood") < 8.0 and guard < 6 and _time_left_min() > 90.0:
		guard += 1
		if _job("wood.split_firewood").has("reasons"):
			break
	_go(STORE)
	_barter_for(npc, "item.fuel.split_wood", _usable("item.fuel.split_wood"), "item.food.cornmeal", 12.0)
	_barter_for(npc, "item.fuel.split_wood", _usable("item.fuel.split_wood"), "item.food.salt_pork", 4.0)


# ---------------------------------------------------------------- lessons, watching and haggling (the apprentice)
## Labour owed for a lesson is worked off first thing (at the mentor's place), so a promise is kept.
func _work_off_labour() -> void:
	for ob in SurvivalTrade.obligations_of(core, core.state.player_id, true):
		if str(ob.kind) == "labour" and str(ob.from) == core.state.player_id and _time_left_min() > 120.0:
			_go(HUT)
			var w := SurvivalTrade.work_off(core, str(ob.id), minf(240.0, _time_left_min() - 90.0))
			v4["labour_h"] = float(v4.labour_h) + float(w.get("worked_min", 0.0)) / 60.0
			_ensure()


## The old hunter's evenings at his hut: a lesson when one is on offer and its ask can be met (labour first: worked off
## the next morning), and watching his crafts.
func _learn_rounds() -> void:
	var npc := "npc.woods.old_hunter"
	if core.data.action("social.ask_teach").is_empty():
		return
	if _hour() > 20.5:
		return
	_go(HUT)
	if _hour() < 18.2:
		_rest((18.2 - _hour()) * 60.0)
	if not SurvivalTrade.partner_present(core, npc):
		_go(CAMP)
		return
	var lessons_open := 0
	for ob in SurvivalTrade.obligations_of(core, core.state.player_id, true):
		if str(ob.kind) == "labour":
			lessons_open += 1
	# A careful learner takes on no labour debt while the store is short (it would cost the next morning's hunt).
	if lessons_open == 0 and _food_store() >= HUNT_BELOW_MEALS:
		# What the learner does not know yet comes first (fix round 1, F10: skill lessons crowded out the hide work the
		# ranger never learned); then skill lessons.
		var offers := SurvivalLearning.lesson_offers(core, npc)
		var first := []
		var rest := []
		for offer in offers:
			if str(offer.kind) == "recipe" and SurvivalLearning.rank(_state(str(offer.what))) < SurvivalLearning.rank("known"):
				first.append(offer)
			else:
				rest.append(offer)
		for offer in first + rest:
			if not bool(offer.ok):
				continue
			var idx := -1
			for i in SurvivalUtil.arr(offer.asks).size():
				var a: Dictionary = offer.asks[i]
				if bool(a.ok) and (SurvivalUtil.dict(a.ask).has("labour") or SurvivalUtil.dict(a.ask).has("friendship")):
					idx = i
					break
			if idx < 0:
				continue
			var r := core.arrange_lesson(npc, str(offer.what), idx)
			if bool(r.get("ok", false)):
				_job_running_to_end()
				v4["lessons"] = int(v4.lessons) + 1
				break
	for w in SurvivalLearning.watchable(core):
		var kid := SurvivalLearning.watch_kid(core, str(w.action))
		if kid != "" and SurvivalLearning.rank(_state(kid)) < SurvivalLearning.rank("seen"):
			var r2 := _job("learn.watch", {"performer": str(w.performer), "action": str(w.action)})
			if r2.has("outcome"):
				v4["watched"] = int(v4.watched) + 1
			break
	_go(CAMP)


func _job_running_to_end() -> void:
	var guard := 0
	while SurvivalJobs.is_running(core) and not core.is_dead() and guard < 200:
		guard += 1
		core.advance(maxf(0.01, minf(240.0, SurvivalJobs.minutes_left(core))), true)


## The rv of the kit and stores the character keeps (the M2a gate's T5 and T8): tools, clothing, weapons and ammunition,
## food and materials in the pack, the caches and on the drying rack, plus coin, less debt. Furs and skins held for trade
## are counted apart (rv_furs): they are trade goods, not kit.
func rv_kit(furs: bool = false) -> float:
	var t := 0.0
	var all := []
	all.append_array(core.state.inventory)
	for c in SurvivalCamp.caches(core).values():
		all.append_array(SurvivalUtil.arr(c.get("items")))
	for r in SurvivalCamp.racks(core).values():
		all.append_array(SurvivalUtil.arr(r.get("hanging")))
	for st in all:
		var cat := core.data.item_cat(str(st.id))
		var is_fur := cat == "pelt" or (cat == "skin" and str(st.id) != "item.skin.dressed_buckskin")
		if is_fur == furs:
			t += SurvivalTrade.rv(core, str(st.id)) * float(st.qty)
	if furs:
		return t
	return t + float(SurvivalEconomy.money(core)) - maxf(0.0, SurvivalEconomy.total_debt(core))


func _made() -> Dictionary:
	var out := {}
	for k in core.state.stats.keys():
		if str(k).begins_with("made_"):
			out[str(k).trim_prefix("made_")] = snappedf(SurvivalUtil.num(core.state.stats[k], 0.0), 0.01)
	return out


func _knowledge_summary() -> Dictionary:
	var out := {}
	for kid in SurvivalUtil.sorted_ids(core.data.knowledge_ids):
		out[kid] = SurvivalLearning.state_of(core, str(kid))
	return out


func _eaten() -> Dictionary:
	var out := {}
	for k in core.state.stats.keys():
		if str(k).begins_with("eaten_"):
			out[str(k).trim_prefix("eaten_")] = snappedf(SurvivalUtil.num(core.state.stats[k], 0.0), 0.1)
	out["plain_meals"] = int(SurvivalUtil.num(core.state.stats.get("plain_meals"), 0.0))
	return out


func _worn_out() -> Dictionary:
	var out := {}
	for k in core.state.stats.keys():
		if str(k).begins_with("worn_out_"):
			out[str(k).trim_prefix("worn_out_")] = int(SurvivalUtil.num(core.state.stats[k], 0.0))
	return out


# ---------------------------------------------------------------- telemetry
func _income_ce() -> float:
	return SurvivalUtil.num(SurvivalUtil.dict(core.state.economy.get("income")).get("ce_d"), 0.0)


func _pelts_carried() -> Dictionary:
	var out := {"pelts": 0.0, "skins": 0.0, "green": 0.0}
	for st in core.state.inventory:
		var cat := core.data.item_cat(str(st.id))
		if cat == "pelt" or cat == "skin" or str(st.id) == "item.material.green_hide":
			if bool(SurvivalUtil.dict(st.meta).get("green", false)):
				out.green = float(out.green) + float(st.qty)
			elif cat == "pelt":
				out.pelts = float(out.pelts) + float(st.qty)
			else:
				out.skins = float(out.skins) + float(st.qty)
	return out


func _record_day() -> void:
	var s0: Dictionary = _day.get("stats0", {})
	var s1 := core.state.stats
	var cold := 0.0
	var cs0 := SurvivalUtil.dict(s0.get("cold_stage_h"))
	var cs1 := SurvivalUtil.dict(s1.get("cold_stage_h"))
	for k in ["cold", "very_cold", "hypothermic", "freezing"]:
		cold += SurvivalUtil.num(cs1.get(k), 0.0) - SurvivalUtil.num(cs0.get(k), 0.0)
	var conds := []
	for c in core.state.conditions.keys():
		conds.append("%s:%s" % [str(c).trim_prefix("cond."), str(core.state.conditions[c].stage)])
	var tl := SurvivalTrapLine.summary(core)
	var d0 := int(_day.get("abs_day", SurvivalClock.abs_day(core)))
	var doy := posmod(d0, SurvivalClock.days_per_year(core))
	day_rows.append({"day": d0 - start_abs_day, "date": "%s %s %d" % [SurvivalClock.PHASE_NAMES[doy % 3],
			SurvivalClock.MONTH_NAMES.get(SurvivalClock.month_id(core, doy), ""), core.state.base_year + floori(float(d0) / float(SurvivalClock.days_per_year(core)))],
			"month": SurvivalClock.month_id(core, doy), "weather": SurvivalWeather.state_id(core),
			"air_c": snappedf(SurvivalClock.air_temp_c(core), 0.1), "money": SurvivalEconomy.money(core),
			"trader_book": snappedf(SurvivalEconomy.balance(core, SurvivalEconomy.TRADER_ID), 0.1),
			"sutler_tally": snappedf(SurvivalEconomy.balance(core, SurvivalEconomy.SUTLER_ID), 0.1),
			"meals": snappedf(SurvivalInventory.meals(core), 0.1), "health": snappedf(core.health(), 0.1),
			"warmth_min": snappedf(float(_day.get("warmth_min", 100.0)), 0.1), "cold_h": snappedf(cold, 0.1),
			"food_stage": SurvivalNeeds.food_stage(core), "fatigue": snappedf(SurvivalUtil.num(core.state.needs.get("fatigue"), 0.0), 0.1),
			"conditions": conds, "traps": int(tl.total), "catches": int(SurvivalUtil.num(s1.get("catches_collected"), 0.0)) - int(SurvivalUtil.num(s0.get("catches_collected"), 0.0)),
			"carried": _pelts_carried(), "income_ce": snappedf(_income_ce() - float(_day.get("income0", 0.0)), 0.1),
			"wakes": int(SurvivalUtil.num(s1.get("wakes"), 0.0)) - int(SurvivalUtil.num(s0.get("wakes"), 0.0)),
			"survival": snappedf(SurvivalSkills.level(core, "survival"), 0.01), "hunting": snappedf(SurvivalSkills.level(core, "hunting"), 0.01),
			"woodcraft": snappedf(SurvivalSkills.level(core, "woodcraft"), 0.01), "trade": snappedf(SurvivalSkills.level(core, "trade"), 0.01),
			"trapping": snappedf(SurvivalSkills.level(core, "trapping"), 0.01), "provisions": snappedf(SurvivalSkills.level(core, "provisions"), 0.01),
			"hidecraft": snappedf(SurvivalSkills.level(core, "hidecraft"), 0.01), "xp_total": snappedf(SurvivalSkills.total_today(core), 0.01),
			"food_meals": snappedf(SurvivalAlmanac.food_meals(core), 0.1), "kg": snappedf(SurvivalInventory.weight_kg(core), 0.1), "pack_kg": snappedf(pack_kg(), 0.1),
			"plain_fare": SurvivalFood.plain_fare(core), "shelter_q": SurvivalUtil.num(SurvivalCamp.shelter_at(core, CAMP).get("quality"), 0.0),
			"rv_kit": snappedf(rv_kit(), 0.1), "coin_spent": snappedf(SurvivalUtil.num(core.state.stats.get("coin_spent"), 0.0), 0.1),
			"starving": SurvivalNeeds.food_stage(core) in ["starving", "wasting"],
			"ready_checks": SurvivalAlmanac.winter_ready_checks(core), "dead": core.is_dead()})
	if ready_day < 0 and SurvivalAlmanac.winter_ready(core):
		ready_day = d0 - start_abs_day
	if snowshoe_day < 0 and SurvivalInventory.has(core, "item.tool.snowshoes"):
		snowshoe_day = d0 - start_abs_day


## The run's summary and its day rows.
func report() -> Dictionary:
	if core.settlement.is_connected(_on_settlement):
		core.settlement.disconnect(_on_settlement)
		core.died.disconnect(_on_died)
		core.calendar_event.disconnect(_on_calendar_event)
	var bg := core.background()
	var start_sk := SurvivalUtil.dict(bg.get("skills"))
	var end_sk := {}
	for sk in core.data.skills.keys():
		end_sk[sk] = snappedf(SurvivalSkills.level(core, str(sk)), 0.01)
	var trap_days := 0
	var income_by_month := {}
	for r in day_rows:
		var m := str(r.month)
		income_by_month[m] = snappedf(SurvivalUtil.num(income_by_month.get(m), 0.0) + float(r.income_ce), 0.1)
		if ["nov", "dec", "jan", "feb", "mar"].has(m):
			trap_days += 1
	var by_cat := SurvivalUtil.dict(SurvivalUtil.dict(core.state.economy.get("income")).get("by_cat"))
	var trap_income := SurvivalUtil.num(by_cat.get("pelt"), 0.0)
	var checks := {}
	for a in SurvivalUtil.dict(core.state.stats.get("checks")).keys():
		var row: Dictionary = core.state.stats.checks[a]
		var n := int(SurvivalUtil.num(row.get("n"), 0.0))
		var good := int(SurvivalUtil.num(row.get("excellent"), 0.0)) + int(SurvivalUtil.num(row.get("success"), 0.0))
		checks[a] = {"n": n, "success_rate": snappedf(float(good) / maxf(1.0, float(n)), 0.01),
				"mishaps": int(SurvivalUtil.num(row.get("mishap"), 0.0))}
	var grades := []
	for e in events:
		if str(e.kind) == "settlement":
			grades.append("%s:%s" % [str(e.creditor), str(e.grade)])
	var st := core.state.stats
	return {"background": core.state.background_id, "policy": policy, "seed": int(opts.get("seed", 1)),
			"start": str(opts.get("start_day", "sep_early")), "days": day_rows.size(), "end_date": SurvivalClock.date_string(core),
			"died": core.is_dead(), "death_cause": str(core.state.flags.get("death_cause", "")),
			"skills_start": start_sk, "skills_end": end_sk, "money_end": SurvivalEconomy.money(core),
			"trader_book_end": snappedf(SurvivalEconomy.balance(core, SurvivalEconomy.TRADER_ID), 0.1),
			"sutler_tally_end": snappedf(SurvivalEconomy.balance(core, SurvivalEconomy.SUTLER_ID), 0.1),
			"income_ce_total": snappedf(_income_ce(), 0.1), "income_by_month": income_by_month,
			"income_ce_per_trapping_day": snappedf(trap_income / maxf(1.0, float(trap_days)), 0.1),
			"income_ce_by_cat": by_cat.duplicate(), "trapping_days": trap_days,
			"wages_d": snappedf(SurvivalUtil.num(SurvivalUtil.dict(core.state.economy.get("income")).get("wages_d"), 0.0), 0.1),
			"cords": int(SurvivalUtil.num(SurvivalUtil.dict(core.state.economy.get("contract")).get("cords"), 0.0)),
			"catches": int(SurvivalUtil.num(st.get("catches_collected"), 0.0)), "scavenged": int(SurvivalUtil.num(st.get("catches_scavenged"), 0.0)),
			"sold_pelts": snappedf(SurvivalUtil.num(st.get("sold_pelt"), 0.0), 0.1), "sold_skins": snappedf(SurvivalUtil.num(st.get("sold_skin"), 0.0), 0.1),
			"deer": int(SurvivalUtil.num(st.get("kills_deer"), 0.0)), "meat_given_lb": snappedf(SurvivalUtil.num(st.get("meat_given_lb"), 0.0), 0.1),
			"cold_stage_h": SurvivalUtil.dict(st.get("cold_stage_h")).duplicate(), "food_stage_h": SurvivalUtil.dict(st.get("food_stage_h")).duplicate(),
			"health_min": snappedf(SurvivalUtil.num(st.get("health_min"), 100.0), 0.1), "wakes": int(SurvivalUtil.num(st.get("wakes"), 0.0)),
			"interrupts": int(SurvivalUtil.num(st.get("interrupts"), 0.0)), "passed_out": int(SurvivalUtil.num(st.get("passed_out"), 0.0)),
			"meals_eaten": snappedf(SurvivalUtil.num(st.get("meals_eaten"), 0.0), 0.1), "checks": checks, "settlements": grades,
			"standing": SurvivalUtil.dict(core.state.economy.get("standing")).duplicate(), "events": events,
			"start_variant": str(core.setting("start_variant", "start.clear")),
			"coin_spent": snappedf(SurvivalUtil.num(st.get("coin_spent"), 0.0), 0.1), "rv_kit_end": snappedf(rv_kit(), 0.1),
			"rv_furs_end": snappedf(rv_kit(true), 0.1),
			"ready_day": ready_day, "snowshoe_day": snowshoe_day, "real_s": real_s.duplicate(),
			"real_min_per_game_day": snappedf((float(real_s.jobs) + float(real_s.walk) + float(real_s.wait) + float(real_s.sleep)) / 60.0 / maxf(1.0, float(day_rows.size())), 0.01),
			"made": _made(), "knowledge": _knowledge_summary(), "habits": SurvivalUtil.arr(core.player().get("habits")).duplicate(),
			"trust": SurvivalUtil.dict(core.player().get("trust")).duplicate(), "trades": int(SurvivalUtil.num(st.get("trades"), 0.0)),
			"lessons": int(SurvivalUtil.num(st.get("lessons"), 0.0)), "watched": int(SurvivalUtil.num(st.get("watched"), 0.0)),
			"obligations_kept": int(SurvivalUtil.num(st.get("obligations_kept"), 0.0)), "obligations_broken": int(SurvivalUtil.num(st.get("obligations_broken"), 0.0)),
			"eaten": _eaten(), "worn_out": _worn_out(), "v4": v4.duplicate(true), "day_rows": day_rows}


## A compact text table of a report for the console.
static func format_report(rep: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("%s / %s, seed %d: %d days from %s to %s%s" % [str(rep.background), str(rep.policy), int(rep.seed),
			int(rep.days), str(rep.start), str(rep.end_date), ("  DIED (%s)" % str(rep.death_cause)) if bool(rep.died) else ""])
	lines.append("  day  date                    money  book    tally  meals  hp    wmin  cold_h  traps catch  ce_d   surv   hunt  conditions")
	for r in SurvivalUtil.arr(rep.get("day_rows")):
		lines.append("  %3d  %-22s %6d %7.0f %6.0f %6.1f %5.0f %5.0f %6.1f %6d %5d %6.0f %6.1f %6.1f  %s" % [int(r.day), str(r.date),
				int(r.money), float(r.trader_book), float(r.sutler_tally), float(r.meals), float(r.health), float(r.warmth_min),
				float(r.cold_h), int(r.traps), int(r.catches), float(r.income_ce), float(r.survival), float(r.hunting),
				", ".join(PackedStringArray(r.conditions))])
	lines.append("  skills %s -> %s" % [str(rep.skills_start), str(rep.skills_end)])
	lines.append("  income ce %.0f d total; furs %.1f d per trapping-season day (%d days); wages %.0f d (%d cords); by kind %s" % [
			float(rep.income_ce_total), float(rep.income_ce_per_trapping_day), int(rep.trapping_days), float(rep.wages_d), int(rep.cords),
			str(rep.income_ce_by_cat)])
	lines.append("  by month %s" % str(rep.income_by_month))
	lines.append("  catches %d (scavenged %d), pelts sold %.0f, skins sold %.0f, deer %d; money %d d, trader book %.0f d, sutler tally %.0f d" % [
			int(rep.catches), int(rep.scavenged), float(rep.sold_pelts), float(rep.sold_skins), int(rep.deer), int(rep.money_end),
			float(rep.trader_book_end), float(rep.sutler_tally_end)])
	lines.append("  settlements %s; standing %s" % [str(rep.settlements), str(rep.standing)])
	lines.append("  cold stages (h) %s; food stages (h) %s; health min %.0f; wakes %d; interrupts %d" % [str(rep.cold_stage_h),
			str(rep.food_stage_h), float(rep.health_min), int(rep.wakes), int(rep.interrupts)])
	lines.append("  checks %s" % str(rep.checks))
	return "\n".join(lines)
