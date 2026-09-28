class_name SurvivalExposure
extends RefCounted
## Exposure-driven conditions from the M3 backlog (backlog/conditions.json). Each runs only when its row is loaded
## (SurvivalCore.new_game backlog_milestones ["M3"]), so the slice is unchanged:
##   - frostbite: exposure per zone (hands, feet, face) builds while the Cold stage is very_cold or worse, or below
##     -10 C with the zone under-insulated; x(1 + wind/5), x2 for wet feet, x1.5 standing still. 30 frostnip, 60
##     superficial, 100 deep. Mitts come off for fine work (clothing remove_for_fine_work), which is the trade-off.
##     Frostnip clears when the zone rewarms; superficial and deep heal on their stage's timer (physick.rewarm helps).
##   - rheumatism: wading below 5 C (0.02 a game hour) or sleeping soaked (0.05 a night) starts a 2-4 day flare.
##   - snow blindness: bright snow under a clear sky by day, February to Early April, without eye shades: 0.08 a game
##     hour; a second exposure while sore makes it blind.

## Exposure a zone loses per game hour while warm (indoors, by a lit fire, or comfortable) [D].
const REWARM_PER_H := 20.0
## Clothing zones behind each frostbite zone.
const ZONE_OF := {"hands": "hands", "feet": "feet", "face": "head"}
const FROST_STAGES := ["frostnip", "superficial", "deep"]
## Hours of sleep a "night" stands for in the sleep-soaked chance [D].
const NIGHT_H := 8.0
## Snow on the ground that makes a bright crust [D].
const BRIGHT_SNOW_CM := 5.0


static func tick(core: SurvivalCore, hours: float) -> void:
	# Stuffed moccasins stay warm until soaked (clothing.stuff_moccasins "until": "soaked").
	if core.state.flags.has("feet_ins_add") and SurvivalNeeds.wet_stage(core) == "soaked":
		core.state.flags.erase("feet_ins_add")
	if not core.data.condition("cond.frostbite").is_empty():
		_frostbite(core, hours)
	if not core.data.condition("cond.rheumatism").is_empty():
		_rheumatism(core, hours)
	if not core.data.condition("cond.snow_blindness").is_empty():
		_snow_blindness(core, hours)


## Worn insulation on one clothing zone; mitts come off while a fine-work job runs.
static func zone_insulation(core: SurvivalCore, zone: String) -> float:
	var fine := false
	var j := SurvivalJobs.current(core)
	if not j.is_empty():
		fine = bool(core.data.action(str(j.get("action", ""))).get("fine_work", false))
	var ins := 0.0
	for cls in SurvivalInventory.worn_classes(core):
		if fine and bool(cls.get("remove_for_fine_work", false)):
			continue
		ins += SurvivalUtil.num(SurvivalUtil.dict(cls.get("ins")).get(zone), 0.0)
	if zone == "feet":
		ins += SurvivalUtil.num(core.state.flags.get("feet_ins_add"), 0.0)
	return ins


static func _warm_now(core: SurvivalCore) -> bool:
	if bool(core.state.context.get("indoors", false)):
		return true
	var f := SurvivalCamp.current_fire(core)
	if not f.is_empty() and str(f.state) == "lit" and SurvivalUtil.num(core.state.context.get("fire_distance_m"), 99.0) <= 2.0:
		return true
	return SurvivalNeeds.warmth_stage(core) == "comfortable"


## Frostbite exposure per zone (state.flags.frost_exposure) and the condition's stage from the worst zone.
static func _frostbite(core: SurvivalCore, hours: float) -> void:
	var row := core.data.condition("cond.frostbite")
	var ex := SurvivalUtil.dict(row.get("exposure"))
	var need := SurvivalUtil.dict(ex.get("zone_insulation_needed_below_minus10c"))
	var thr := SurvivalUtil.dict(ex.get("stage_thresholds"))
	var fe: Dictionary = core.state.flags.get("frost_exposure", {})
	var air := SurvivalClock.air_temp_c(core)
	var ws := SurvivalNeeds.warmth_stage(core)
	var very_cold := ws in ["very_cold", "hypothermic", "freezing"]
	var warm := _warm_now(core)
	var still := core.state.asleep or core.state.activity == "rest" or core.state.activity == "crouch"
	var worst_zone := ""
	var worst := 0.0
	for zone in SurvivalUtil.arr(row.get("zones")):
		var z := str(zone)
		var e := SurvivalUtil.num(fe.get(z), 0.0)
		var under := air < -10.0 and zone_insulation(core, str(ZONE_OF.get(z, z))) < SurvivalUtil.num(need.get(z), 0.0)
		if (very_cold or under) and not warm:
			var rate := SurvivalUtil.num(ex.get("per_game_h"), 10.0) * (1.0 + SurvivalWeather.wind_ms(core) / 5.0)
			if z == "feet" and bool(core.state.flags.get("feet_wet", false)):
				rate *= SurvivalUtil.num(ex.get("wet_feet_mult"), 2.0)
			if still:
				rate *= SurvivalUtil.num(ex.get("standing_still_mult"), 1.5)
			e = minf(100.0, e + rate * hours)
		else:
			e = maxf(0.0, e - REWARM_PER_H * hours)
		fe[z] = e
		if e > worst:
			worst = e
			worst_zone = z
	core.state.flags["frost_exposure"] = fe
	var stage := ""
	for s in FROST_STAGES:
		if worst >= SurvivalUtil.num(thr.get(s), 999.0):
			stage = s
	var have := SurvivalConditions.stage_of(core, "cond.frostbite")
	var hi := FROST_STAGES.find(have)
	var ni := FROST_STAGES.find(stage)
	if ni > hi:
		set_frostbite_stage(core, stage, worst_zone)
	elif have == "frostnip" and stage == "":
		SurvivalConditions.remove(core, "cond.frostbite")


## Set the frostbite stage (a worse stage or physick.rewarm); superficial and deep heal on their stage's timer.
static func set_frostbite_stage(core: SurvivalCore, stage: String, zone: String = "") -> void:
	if stage == "":
		SurvivalConditions.remove(core, "cond.frostbite")
		return
	var rec: Dictionary = core.state.conditions.get("cond.frostbite", {})
	if rec.is_empty():
		SurvivalConditions.add(core, "cond.frostbite", {"stage": stage, "zone": zone if zone != "" else "hands"})
		rec = core.state.conditions.get("cond.frostbite", {})
	var old := str(rec.get("stage", ""))
	rec["stage"] = stage
	if zone != "":
		rec["zone"] = zone
	rec.erase("heal_h")
	for s in SurvivalUtil.arr(core.data.condition("cond.frostbite").get("stages")):
		if str(s.get("stage", "")) == stage and s.has("heal_game_days"):
			rec["heal_h"] = SurvivalUtil.num(s.heal_game_days, 3.0) * 24.0
	if old != stage:
		core._on_condition_stage("cond.frostbite", old, stage)


## physick.rewarm: shift the stage by `delta` (-1 better, +1 worse) and let the zones' exposure follow.
static func shift_frostbite(core: SurvivalCore, delta: int) -> void:
	var have := SurvivalConditions.stage_of(core, "cond.frostbite")
	if have == "" or delta == 0:
		return
	var i := clampi(FROST_STAGES.find(have) + delta, -1, FROST_STAGES.size() - 1)
	var fe: Dictionary = core.state.flags.get("frost_exposure", {})
	var thr := SurvivalUtil.dict(SurvivalUtil.dict(core.data.condition("cond.frostbite").get("exposure")).get("stage_thresholds"))
	var cap := SurvivalUtil.num(thr.get(FROST_STAGES[i + 1] if i + 1 < FROST_STAGES.size() else "deep"), 100.0) - 0.1 if i >= 0 else 0.0
	for z in fe.keys():
		fe[z] = minf(SurvivalUtil.num(fe[z], 0.0), maxf(0.0, cap if i >= 0 else 0.0))
	set_frostbite_stage(core, FROST_STAGES[i] if i >= 0 else "")


static func _rheumatism(core: SurvivalCore, hours: float) -> void:
	if core.state.conditions.has("cond.rheumatism"):
		return
	var row := core.data.condition("cond.rheumatism")
	var acq := SurvivalUtil.dict(row.get("acquire"))
	var p := 0.0
	if core.state.activity == "wading" and SurvivalClock.air_temp_c(core) < 5.0:
		p += SurvivalUtil.num(acq.get("per_game_h_wading_below_5c"), 0.0) * hours
	if core.state.asleep and SurvivalNeeds.wet_stage(core) == "soaked":
		p += SurvivalUtil.num(acq.get("sleep_soaked"), 0.0) * hours / NIGHT_H
	if p > 0.0 and core.rng.randf() < p:
		SurvivalConditions.add(core, "cond.rheumatism", {"cause": "cold water"})
		var rec: Dictionary = core.state.conditions.get("cond.rheumatism", {})
		rec["dur_h"] = SurvivalUtil.rand_in(core.rng, SurvivalUtil.dict(row.get("course")).get("flare_game_days"), 3.0) * 24.0


static func _snow_blindness(core: SurvivalCore, hours: float) -> void:
	var row := core.data.condition("cond.snow_blindness")
	var acq := SurvivalUtil.dict(row.get("acquire"))
	if not SurvivalClock.in_window(core, acq.get("window", ["feb_early", "apr_early"])):
		return
	if bool(core.state.context.get("indoors", false)) or core.state.asleep:
		return
	if SurvivalWeather.state_id(core) != "clear" or SurvivalClock.light_level(core) < 0.9 or SurvivalWeather.snow_depth_cm(core) < BRIGHT_SNOW_CM:
		return
	for it in SurvivalUtil.arr(acq.get("prevented_by")):
		if SurvivalInventory.has(core, str(it)):
			return
	if core.rng.randf() < SurvivalUtil.num(acq.get("per_game_h_bright_snow_clear_sky"), 0.0) * hours:
		if SurvivalConditions.stage_of(core, "cond.snow_blindness") == "sore_eyes":
			var rec: Dictionary = core.state.conditions["cond.snow_blindness"]
			rec["stage"] = "blind"
			core._on_condition_stage("cond.snow_blindness", "sore_eyes", "blind")
		elif not core.state.conditions.has("cond.snow_blindness"):
			SurvivalConditions.add(core, "cond.snow_blindness", {"cause": "bright snow"})
