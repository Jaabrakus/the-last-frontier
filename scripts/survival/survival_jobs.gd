class_name SurvivalJobs
extends RefCounted
## The job runner (the GDD's JobRunner): survival actions as timed, interruptible jobs with skill checks.
##
## An action row (actions.json) is data: requirements, difficulty, the modifiers that apply, working time, outcomes per
## tier and the anim hook. start() validates the requirements, works out the check (p = clamp(0.55 + (S - D) / 60 +
## modifiers, 0.05, 0.97)), rolls the outcome up front (so time_mult outcomes set the working time and a cancel cannot
## re-roll), and runs the job on the survival clock. The job completes inside SurvivalCore.advance(); its effects are
## applied from the outcome row's effect vocabulary (give, give_from_node, spawn, set, cond, need, wet, wear, yield_mult,
## time_mult, next, reveal, pelt_grade, ...). Unknown effect keys are listed in the result, never fatal.
##
## Interrupts (actions.json interrupt, needs.json time_safety): movement cancels (cancel_job) and keeps progress unless
## the action says move_cancels_lose; a threat within 25 m (60 m asleep), a worsening need, the fire dying, a condition
## gaining a stage or a storm stop jobs and wake sleepers. The hurry toggle (job_runner.hurry) takes x0.6 time, -0.05 on
## the check and doubles mishaps on jobs with a check and 10 game minutes or more.
##
## v4 (survival_gdd.md sections 7-8): knowledge gates recipes and technique actions by state (unknown blocks; heard of
## and seen are tried at D +15 / +5 with mod.untried; practised and mastered are easier), a recipe may override its
## action's D, time and base experience, the check records its task modifiers so impairments never add learning, and a
## finished check promotes the recipe's knowledge. Tiers never lock an action. Gathering draws on the node's season stock
## (SurvivalNodes); the half-faced camp is built in resumable stages; lessons, watching, examining and the trade window
## run as jobs too.

const JOB_THREAT_M := 25.0
const SLEEP_THREAT_M := 60.0
## Rows whose `near` list means "all of these" (a snare needs a trail and a sapling); every other list is any-of
## [D reading of the data: wood.split_firewood and fur.stretch list alternatives].
const NEAR_ALL_OF := ["fire.lay_long", "trap.snare_set", "preserve.jerk_scaffold", "shelter.half_faced_camp"]
## The body's activity while a job runs, by the action's own anim hook (needs.json activity keys) [D].
const ACTIVITY_BY_ANIM := {"anim.chop": "heavy_work", "anim.kneel_ground_work": "crouch", "anim.gather_low": "walk",
		"anim.crafting_pack": "rest", "anim.work_waist": "walk", "anim.sit_rest": "rest", "anim.sleep": "sleep",
		"anim.eat": "rest", "anim.drink_flask": "rest", "anim.bandage": "rest", "anim.look_examine": "walk",
		"anim.talk_gesture": "rest", "anim.wade": "wading", "anim.gather_high": "walk", "anim.none": ""}
## Spark tinders by ease (the strike's difficulty_by), and the flame tinders a coal is nursed with.
const SPARK_TINDERS := ["item.tinder.charcloth", "item.tinder.punk", "item.tinder.fungus", "item.tinder.grass"]
const FLAME_TINDERS := ["item.tinder.birchbark", "item.tinder.cedarbark", "item.tinder.grass"]
## What "tinder" from deadwood turns out to be (fire.gather give_from_node) [D weights]; grass is buried in snow.
const GATHER_TINDER_WEIGHTS := {"item.tinder.birchbark": 3.0, "item.tinder.punk": 2.5, "item.tinder.fungus": 1.5,
		"item.tinder.cedarbark": 1.5, "item.tinder.grass": 1.5}
const GRASS_BURIED_SNOW_CM := 15.0
## A partial gather gives damp tinder: -0.15 when lighting (fire.gather outcomes.partial note).
const DAMP_TINDER_ADD := -0.15
## Usable (not good) stakes set a slightly touchier fall [D].
const USABLE_STAKES_SET_MULT := 0.9
## Roasting cooks a game day's food at most (three meals) unless params.qty says otherwise [D].
const COOK_MAX_GAME_KCAL := 2400.0
## Working time falls from time_min's max at S = D - 20 to its min at S = D + 40 [D].
const SKILL_TIME_LOW := -20.0
const SKILL_TIME_SPAN := 60.0
## Kept progress on a cancelled job is dropped after this many game minutes [D].
const PROGRESS_KEEP_MIN := 1440.0
## Light below this level counts as night for mod.night_no_light [D].
const DARK_LIGHT := 0.25
## A lit fire within this distance lights fine work [D].
const FIRELIGHT_M := 4.0
## Sleep defaults: until half an hour after sunrise at night, else this long [D].
const DEFAULT_SLEEP_H := 8.0
## Conditions whose check penalties the prompt names with the matching skills.json modifier's hint.
const COND_HINT_MOD := {"cond.cold": "mod.cold_hands", "cond.fatigue": "mod.exhausted", "cond.hunger": "mod.starving",
		"cond.injury.cut": "mod.hand_injury", "cond.injury.crushed_fingers": "mod.hand_injury", "cond.drunk": "mod.drunk",
		"cond.queasy": "mod.ill"}
const OUTCOME_FALLBACK := {"excellent": "success", "partial": "success", "mishap": "failure", "failure": "", "success": ""}
## What a job resolved at its start and keeps to the end (params keys the requirement check honours).
const PINNED_AT_COMPLETION := ["item", "tinder", "flame_tinder", "fuel", "trap_id", "carcass_id", "recipe"]
## Snow deep enough to bank against a shelter (shelter.chink_bank without moss) [D; the data row says the same].
const BANK_SNOW_CM := 10.0


# ---------------------------------------------------------------- state helpers
static func _jobs(core: SurvivalCore) -> Dictionary:
	if not core.state.jobs.has("current"):
		core.state.jobs["current"] = {}
	if not core.state.jobs.has("progress"):
		core.state.jobs["progress"] = {}
	return core.state.jobs


static func current(core: SurvivalCore) -> Dictionary:
	return SurvivalUtil.dict(_jobs(core).get("current"))


static func is_running(core: SurvivalCore) -> bool:
	return not current(core).is_empty()


static func minutes_left(core: SurvivalCore) -> float:
	var j := current(core)
	if j.is_empty():
		return 0.0
	return maxf(0.0, SurvivalUtil.num(j.get("duration_min"), 0.0) - SurvivalUtil.num(j.get("elapsed_min"), 0.0))


## How fast the survival clock runs while this job plays: its game minutes pass in its screen seconds.
static func speed_game_min_per_real_s(core: SurvivalCore) -> float:
	var j := current(core)
	if j.is_empty():
		return 0.0
	return SurvivalUtil.num(j.get("duration_min"), 0.0) / maxf(1.0, SurvivalUtil.num(j.get("screen_s"), 1.0))


static func action(core: SurvivalCore, id: String) -> Dictionary:
	return core.data.action(id)


# ---------------------------------------------------------------- requirements
## {ok, reasons: [text], resolved: {tinder, flame_tinder, fuel, item, trap_id, carcass_id, stack, recipe, forage}}.
## when_done: the check a finishing job makes. It asks only whether what the job works on is still there (materials,
## tools, the fire, the trap or carcass); the gates of when and where it may start (tier, knowledge, season, night,
## ice, snow, frozen ground, what is in season to forage, node regrowth) were met at the start and are not asked
## again, so spearing fish by torchlight that runs past dawn, or a cache pit dug as the air drops below freezing, is not
## thrown away at the last minute.
static func requirements(core: SurvivalCore, id: String, params: Dictionary = {}, when_done: bool = false) -> Dictionary:
	var a := action(core, id)
	var reasons := []
	var res := {}
	if a.is_empty():
		return {"ok": false, "reasons": ["unknown action %s" % id], "resolved": res}
	if str(a.get("interrupt", "")) == "passive":
		return {"ok": false, "reasons": ["this happens by itself"], "resolved": res}
	if core.is_dead():
		return {"ok": false, "reasons": ["dead"], "resolved": res}
	if core.is_passed_out():
		return {"ok": false, "reasons": ["senseless"], "resolved": res}
	var rq := SurvivalUtil.dict(a.get("requires"))
	# Knowledge (skills.json knowledge_model): an unknown technique cannot be tried; recipes are gated one by one below.
	if not when_done and not a.has("recipes") and SurvivalLearning.gates_action(core, a):
		var kid := core.data.action_knowledge_id(id)
		if SurvivalLearning.state_of(core, kid) == "unknown":
			reasons.append("you do not know how to %s" % str(a.get("name", id)).to_lower())
		res["kid"] = kid
	# Items carried.
	for it in SurvivalUtil.dict(rq.get("items")).keys():
		var need := SurvivalUtil.num(rq.items[it], 1.0)
		if SurvivalInventory.count(core, str(it)) < need - 0.0001:
			reasons.append("needs %s" % core.data.item_name(str(it)))
	# Any-of items: the strike's spark tinder, the nurse's flame tinder, the fuel for tending.
	var or_near_ok := false
	for tag in SurvivalUtil.arr(rq.get("or_near")):
		if _near_ok(core, str(tag), params):
			or_near_ok = true
	for group in SurvivalUtil.arr(rq.get("any_item")):
		var g: Array = group
		var pick := _pick_from_group(core, g, params)
		if pick == "":
			if not or_near_ok:
				reasons.append("needs one of: %s" % _names(core, g) + (" (or to be near %s)" % _names(core, SurvivalUtil.arr(rq.get("or_near"))) if rq.has("or_near") else ""))
			continue
		if _same_set(g, SPARK_TINDERS):
			res["tinder"] = pick
		elif _same_set(g, FLAME_TINDERS):
			res["flame_tinder"] = pick
		elif core.data.item_cat(pick) == "fuel":
			res["fuel"] = pick
		else:
			res["any_" + str(g[0])] = pick
	for miss in SurvivalInventory.missing_tools(core, rq.get("tools")):
		reasons.append("needs %s" % _names(core, miss))
	# Where.
	var near := SurvivalUtil.arr(rq.get("near"))
	if not near.is_empty():
		var oks := []
		for tag in near:
			oks.append(_near_ok(core, str(tag), params))
		var all_of := NEAR_ALL_OF.has(id) or bool(rq.get("near_all", false))
		var ok := (not oks.has(false)) if all_of else oks.has(true)
		if not ok:
			reasons.append("needs to be near %s" % _names(core, near, " and " if all_of else " or "))
	if not when_done:
		_start_gates(core, rq, reasons)
	if rq.has("distance_to_fire_m_min") and SurvivalUtil.num(core.state.context.get("fire_distance_m"), 99.0) < SurvivalUtil.num(rq.distance_to_fire_m_min):
		reasons.append("too close to the flame (step back to %.1f m)" % SurvivalUtil.num(rq.distance_to_fire_m_min))
	if rq.has("shelter_quality_min"):
		var sh := SurvivalCamp.current_shelter(core)
		if SurvivalUtil.num(sh.get("quality"), 0.0) < SurvivalUtil.num(rq.shelter_quality_min):
			reasons.append("needs a better shelter")
	if rq.has("forage_table") and not when_done:
		var row := _forage_row(core, params)
		if row.is_empty():
			reasons.append("nothing in season to gather here")
		else:
			res["forage"] = row
	if rq.has("moss_or_snow"):
		var ms := SurvivalUtil.dict(rq.moss_or_snow)
		var moss := false
		for tag in SurvivalUtil.arr(ms.get("near")):
			if _near_ok(core, str(tag), params):
				moss = true
		if not moss and SurvivalWeather.snow_depth_cm(core) < SurvivalUtil.num(ms.get("snow_depth_cm_min"), BANK_SNOW_CM):
			reasons.append("needs moss (conifers near) or snow to bank")
	# A node's season stock (SurvivalNodes): a picked-out grove or fish water is empty until it refills.
	if not when_done:
		for o in SurvivalUtil.dict(a.get("outcomes")).values():
			for it in SurvivalUtil.dict(SurvivalUtil.dict(o).get("give_from_stock")).keys():
				var nt := _node_type_for(a)
				if nt != "" and SurvivalNodes.available(core, nt, str(it), str(params.get("node_id", core.state.context.get("node_id", "")))) < 1.0:
					reasons.append("picked over here this season")
					break
			if not reasons.is_empty() and reasons[reasons.size() - 1] == "picked over here this season":
				break
	# Resource node regrowth (a node instance the game names in params or context.node_id).
	var node_inst := str(params.get("node_id", core.state.context.get("node_id", "")))
	if node_inst != "" and _uses_node(a) and not when_done:
		var left := node_regrow_days_left(core, node_inst, _node_type_for(a))
		if left > 0.0:
			reasons.append("picked over here (regrows in %.1f game days)" % left)
	# Targets and states each action works on.
	_target_requirements(core, id, a, params, res, reasons, when_done)
	return {"ok": reasons.is_empty(), "reasons": reasons, "resolved": res}


## When and in what conditions an action may start: season, night, a torch at night, knowledge, ice, snow, frozen ground.
static func _start_gates(core: SurvivalCore, rq: Dictionary, reasons: Array) -> void:
	if rq.has("season") and not SurvivalClock.in_window(core, rq.season):
		reasons.append("out of season (%s)" % _window_text(core, rq.season))
	if bool(rq.get("night", false)) and not SurvivalClock.is_night(core):
		reasons.append("only at night")
	if SurvivalClock.is_night(core):
		for it in SurvivalUtil.arr(rq.get("night_needs")):
			if not SurvivalInventory.has(core, str(it)):
				reasons.append("needs %s at night" % core.data.item_name(str(it)))
	if rq.has("knowledge") and SurvivalLearning.state_of(core, str(rq.knowledge)) == "unknown":
		reasons.append("needs to know %s" % str(rq.knowledge).trim_prefix("know.").replace("_", " "))
	if rq.has("ice_cm_min") and SurvivalClock.month_value(core, "river_ice_cm") < SurvivalUtil.num(rq.ice_cm_min):
		reasons.append("the ice is not thick enough")
	if rq.has("ice_cm_max") and SurvivalClock.month_value(core, "river_ice_cm") > SurvivalUtil.num(rq.ice_cm_max):
		reasons.append("the water is iced over")
	if rq.has("snow_depth_cm_min") and SurvivalWeather.snow_depth_cm(core) < SurvivalUtil.num(rq.snow_depth_cm_min):
		reasons.append("not enough snow")
	if bool(rq.get("ground_not_frozen", false)) and SurvivalClock.air_temp_c(core) < 0.0 and SurvivalClock.season(core) == "winter":
		reasons.append("the ground is frozen")


static func _target_requirements(core: SurvivalCore, id: String, a: Dictionary, params: Dictionary, res: Dictionary, reasons: Array, when_done: bool = false) -> void:
	var cat := str(a.get("cat", ""))
	match id:
		"fire.tend":
			var f := SurvivalCamp.current_fire(core)
			if f.is_empty() or str(f.state) == "out" or (str(f.state) == "smouldering" and bool(f.get("coal_only", false))):
				reasons.append("no fire to feed (a bare coal must be nursed first)")
			if params.has("fuel") and SurvivalInventory.has(core, str(params.fuel)):
				res["fuel"] = str(params.fuel)
		"fire.strike_flint_steel":
			var f2 := SurvivalCamp.current_fire(core)
			if not f2.is_empty() and str(f2.state) == "lit":
				reasons.append("a fire is already burning here")
		"eat":
			var it := str(params.get("item", ""))
			if it == "":
				it = SurvivalFood.choose_meal(core)
			if it == "":
				reasons.append("no food ready to eat")
			elif not SurvivalFood.edible(core, it):
				reasons.append("%s must be cooked first" % core.data.item_name(it))
			elif not SurvivalInventory.has(core, it, 0.0001):
				reasons.append("no %s carried" % core.data.item_name(it))
			else:
				res["item"] = it
		"cook.roast", "cook.boil":
			var ci := str(params.get("item", ""))
			if ci == "":
				ci = SurvivalFood.choose_to_cook(core)
			if ci == "" or str(core.data.item(ci).get("cook_to", "")) == "" or not SurvivalInventory.has(core, ci, 0.0001):
				if not a.has("recipes"):
					reasons.append("nothing to cook")
			else:
				res["item"] = ci
		"physick.bind_wound":
			if not SurvivalConditions.needs_binding(core):
				reasons.append("nothing to bind")
		"rest.sleep":
			if core.state.asleep:
				reasons.append("already asleep")
		"trade.take_credit":
			if not SurvivalEconomy.is_open(core, "mkt.visiting_trader"):
				reasons.append("the trader is not here")
			else:
				var ok := SurvivalEconomy.can_take_outfit(core)
				if not bool(ok.ok):
					reasons.append(str(ok.reason))
		"trap.check":
			var tid := _pick_trap(core, params)
			if tid == "":
				reasons.append("no trap here")
			else:
				res["trap_id"] = tid
		"fur.skin":
			var cid := _pick_carcass(core, params, "skin")
			if cid == "":
				reasons.append("no animal to skin here")
			else:
				res["carcass_id"] = cid
		"butcher.field_dress":
			var cid2 := _pick_carcass(core, params, "dress")
			if cid2 == "":
				reasons.append("no animal to dress here")
			else:
				res["carcass_id"] = cid2
		"fur.stretch":
			var st := _pick_green(core, params)
			if st.is_empty():
				reasons.append("no green pelt or hide to stretch")
			else:
				res["stack"] = st
		"trap.deadfall_set":
			res["stake_quality"] = "good" if SurvivalInventory.count(core, "item.trap.stake_set", {"quality": null}) >= 1.0 - 0.0001 else "usable"
		"clothing.repair_moccasins":
			if not SurvivalInventory.needs_mending(core, SurvivalUtil.arr(SurvivalUtil.dict(a.get("repairs")).get("items"))):
				reasons.append("nothing worn enough to mend")
		"clothing.stuff_moccasins":
			if not core.state.worn.has("item.cloth.moccasins"):
				reasons.append("no moccasins on")
		"shelter.half_faced_camp":
			var shq := SurvivalCamp.shelter_at(core, str(core.state.context.get("location", "")))
			if SurvivalUtil.num(shq.get("quality"), 0.0) >= SurvivalUtil.num(SurvivalUtil.dict(a.get("build")).get("quality"), 4.0):
				reasons.append("a half-faced camp already stands here")
		"preserve.cache_pit":
			if not SurvivalCamp.cache_at(core, str(core.state.context.get("location", ""))).is_empty():
				reasons.append("a cache already hangs here")
		"trade.barter":
			var s := SurvivalTrade.session(core, str(params.get("tr", "")))
			if s.is_empty() or str(s.get("state", "")) != "open":
				reasons.append("no open trade")
			elif params.has("version") and int(params.version) != int(s.version):
				# The job confirms the version the player saw when it started, never a later one.
				reasons.append("the offer changed: look again before confirming")
		"trade.haggle":
			var ha := SurvivalTrade.haggle_allowed(core, str(params.get("tr", "")))
			if not bool(ha.ok):
				reasons.append(str(ha.reason))
			elif params.has("version") and int(params.version) != int(SurvivalTrade.session(core, str(params.get("tr", ""))).get("version", -1)):
				reasons.append("the offer changed while you were talking")
		"social.ask_teach":
			var ob := SurvivalTrade.obligation(core, str(params.get("ob", "")))
			if ob.is_empty() or str(ob.get("kind", "")) != "lesson" or str(ob.get("status", "")) != "open":
				reasons.append("no lesson agreed (arrange one with the mentor first)")
			elif not SurvivalTrade.partner_present(core, str(ob.from)):
				reasons.append("%s is not here" % core.npc_title(str(ob.from)))
		"learn.watch":
			var ok_w := false
			for w in SurvivalLearning.watchable(core):
				if str(w.performer) == str(params.get("performer", "")) and str(w.action) == str(params.get("action", "")):
					ok_w = true
			if not ok_w:
				reasons.append("nobody is doing that here")
		"learn.examine":
			if not SurvivalLearning.can_examine(core, str(params.get("item", ""))):
				reasons.append("nothing to examine in reach")
	if a.has("recipes"):
		var rid := str(params.get("recipe", ""))
		var cands: Array = [rid] if rid != "" else SurvivalUtil.arr(a.recipes)
		var chosen := ""
		var why := ""
		for r in cands:
			# Knowledge gates each recipe: unknown recipes are neither shown nor tried (their inputs stay hidden).
			if not when_done and SurvivalLearning.state_of(core, core.data.recipe_knowledge_id(str(r))) == "unknown":
				if why == "":
					why = "you do not know how to make that"
				continue
			var miss := SurvivalCrafting.missing(core, str(r))
			miss.erase("station")
			if miss.is_empty():
				chosen = str(r)
				break
			why = _missing_text(core, miss)
		if chosen == "" and not res.has("item"):
			reasons.append(why if why != "" else "no recipe can be made")
		elif chosen != "":
			res["recipe"] = chosen
	var succ_spawn := SurvivalUtil.dict(SurvivalUtil.dict(SurvivalUtil.dict(a.get("outcomes")).get("success")).get("spawn"))
	if cat == "trap" and succ_spawn.has("world.trap"):
		var cell := int(params.get("cell", core.state.context.get("cell", 0)))
		if cell < 0 or cell >= SurvivalTrapLine.cell_count(core):
			reasons.append("not in the trapping woods")


static func _pick_from_group(core: SurvivalCore, g: Array, params: Dictionary) -> String:
	for key in ["tinder", "flame_tinder", "fuel", "item"]:
		var want := str(params.get(key, ""))
		if want != "" and g.has(want) and SurvivalInventory.has(core, want, 0.0001):
			return want
	# Dry before damp, in the group's order (the easiest spark tinder first).
	for it in g:
		if _count_dry(core, str(it)) >= 1.0 - 0.0001:
			return str(it)
	for it in g:
		if SurvivalInventory.has(core, str(it), 0.0001):
			return str(it)
	return ""


static func _count_dry(core: SurvivalCore, id: String) -> float:
	var n := 0.0
	for st in SurvivalInventory.stacks_of(core, id):
		if not bool(SurvivalUtil.dict(st.meta).get("damp", false)):
			n += float(st.qty)
	return n


static func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true


static func _names(core: SurvivalCore, ids: Array, sep: String = " or ") -> String:
	var out := PackedStringArray()
	for i in ids:
		var s := str(i)
		if s.begins_with("item."):
			out.append(core.data.item_name(s).to_lower())
		else:
			out.append(s.get_slice(".", s.get_slice_count(".") - 1).replace("_", " ").replace(":", " "))
	return sep.join(out)


static func _window_text(core: SurvivalCore, w) -> String:
	var arr := SurvivalUtil.arr(w)
	if arr.size() >= 2:
		return "%s to %s" % [str(arr[0]).replace("_", " "), str(arr[1]).replace("_", " ")]
	return str(w)


static func _missing_text(core: SurvivalCore, miss: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in SurvivalUtil.dict(miss.get("inputs")).keys():
		parts.append("%s x%s" % [core.data.item_name(str(k)).to_lower(), str(miss.inputs[k])])
	for g in SurvivalUtil.arr(miss.get("tools")):
		parts.append(_names(core, g))
	for g in SurvivalUtil.arr(miss.get("any")):
		parts.append("one of " + _names(core, g))
	for t in SurvivalUtil.arr(miss.get("near")):
		parts.append("to be near " + _names(core, [t]))
	return "needs " + ", ".join(parts) if not parts.is_empty() else ""


## Is a `near` tag satisfied here? node.* and other tags come from context.near; world objects from the camp records.
static func _near_ok(core: SurvivalCore, tag: String, params: Dictionary) -> bool:
	var near := SurvivalUtil.arr(core.state.context.get("near"))
	if near.has(tag):
		return true
	if tag.begins_with("poi."):
		return str(core.state.context.get("location", "")) == tag
	var parts := tag.split(":")
	var base := parts[0]
	match base:
		"world.campfire":
			var f := SurvivalCamp.current_fire(core)
			if f.is_empty():
				return false
			if parts.size() > 1:
				return str(f.state) == parts[1]
			return str(f.state) != "out"
		"world.shelter":
			return not SurvivalCamp.current_shelter(core).is_empty()
		"world.trap":
			return _pick_trap(core, params) != ""
		"world.carcass":
			return _pick_carcass(core, params, "any") != ""
	return false


static func _pick_trap(core: SurvivalCore, params: Dictionary) -> String:
	var tid := str(params.get("trap_id", ""))
	if tid != "":
		return tid if SurvivalTrapLine.traps(core).has(tid) else ""
	var loc := str(core.state.context.get("location", ""))
	var cell := int(core.state.context.get("cell", -1))
	for id in SurvivalTrapLine.trap_ids(core):
		var t: Dictionary = SurvivalTrapLine.trap(core, id)
		if (loc != "" and str(t.get("location", "")) == loc) or (cell >= 0 and int(t.cell) == cell and loc == ""):
			return str(t.id)
	return ""


## A carcass here for `need`: "skin" (a pelt not yet taken), "dress" (not yet dressed) or "any".
static func _pick_carcass(core: SurvivalCore, params: Dictionary, need: String) -> String:
	var cid := str(params.get("carcass_id", ""))
	var loc := str(core.state.context.get("location", ""))
	var cands := []
	if cid != "":
		if SurvivalCamp.carcasses(core).has(cid):
			cands.append(SurvivalCamp.carcasses(core)[cid])
	else:
		# Oldest first, by id (not by the dictionary's key order, which a save format may change).
		var all := SurvivalCamp.carcasses(core)
		for id in SurvivalUtil.sorted_ids(all):
			if str(all[id].get("location", "")) == loc:
				cands.append(all[id])
	for c in cands:
		match need:
			"skin":
				if SurvivalCamp.carcass_has_pelt(core, c) and not bool(c.skinned):
					return str(c.id)
			"dress":
				if not bool(c.dressed):
					return str(c.id)
			_:
				return str(c.id)
	return ""


## A green pelt or hide not yet stretched: params.item picks the kind.
static func _pick_green(core: SurvivalCore, params: Dictionary) -> Dictionary:
	var want := str(params.get("item", ""))
	for st in core.state.inventory:
		var m := SurvivalUtil.dict(st.meta)
		if not bool(m.get("green", false)) or bool(m.get("stretched", false)) or bool(m.get("slipped", false)):
			continue
		if want != "" and str(st.id) != want:
			continue
		return st
	return {}


static func _uses_node(a: Dictionary) -> bool:
	for o in SurvivalUtil.dict(a.get("outcomes")).values():
		if SurvivalUtil.dict(o).has("give_from_node"):
			return true
	return false


static func _node_type_for(a: Dictionary) -> String:
	for n in SurvivalUtil.arr(SurvivalUtil.dict(a.get("requires")).get("near")):
		if str(n).begins_with("node."):
			return str(n)
	return ""


## Game days until a harvested node instance regrows (map_regions.json resource_nodes regrow_game_days); 0 = ready.
static func node_regrow_days_left(core: SurvivalCore, node_instance: String, node_type: String) -> float:
	if not core.state.nodes_used.has(node_instance):
		return 0.0
	var regrow := 0.0
	for r in core.data.resource_nodes.values():
		if str(r.id) == node_type:
			regrow = SurvivalUtil.num(r.get("regrow_game_days"), 0.0)
	var used_min := SurvivalUtil.num(core.state.nodes_used[node_instance], -1e9)
	return maxf(0.0, regrow - (core.state.minutes - used_min) / SurvivalClock.MIN_PER_DAY)


static func _forage_row(core: SurvivalCore, params: Dictionary) -> Dictionary:
	var near := SurvivalUtil.arr(core.state.context.get("near"))
	var best := {}
	for row in core.data.forage:
		if typeof(row) != TYPE_DICTIONARY or core.data.item(str(row.get("item", ""))).is_empty():
			continue
		if params.has("item") and str(row.item) != str(params.item):
			continue
		if not SurvivalClock.in_window(core, row.get("window")):
			continue
		if not near.has(str(row.get("node", ""))):
			continue
		if SurvivalNodes.available(core, str(row.get("node", "")), str(row.item), str(params.get("node_id", core.state.context.get("node_id", "")))) < 1.0:
			continue
		if best.is_empty() or SurvivalUtil.num(row.get("d"), 0.0) < SurvivalUtil.num(best.get("d"), 0.0):
			best = row
	return best


# ---------------------------------------------------------------- the check
## The difficulty for this attempt (difficulty_by: the tinder or food used, wet weather, fresh snow, the carcass, ...).
static func difficulty(core: SurvivalCore, a: Dictionary, params: Dictionary, res: Dictionary) -> float:
	var D := _base_difficulty(core, a, params, res)
	if D <= 0.0:
		return D
	# v4: knowledge (heard of +15, seen +5, practised -5, mastered -10), a quality standard (M2b), tier flags.
	var kid := SurvivalLearning.job_kid(core, a, res)
	if kid != "":
		D += float(SurvivalLearning.attempt(core, kid).d_add)
	var stdr := standard_row(core, params)
	D += SurvivalUtil.num(stdr.get("d_add"), 0.0)
	D += SurvivalUtil.num(SurvivalSkills.flag(core, str(a.get("skill", "")), str(a.get("id", "")) + "_difficulty_add", 0.0), 0.0)
	return maxf(1.0, D)


## The chosen quality standard's row (recipes.json rules.standards; params.standard, M2b), {} for plain.
static func standard_row(core: SurvivalCore, params: Dictionary) -> Dictionary:
	var sid := str(params.get("standard", "plain"))
	if sid == "plain" or sid == "":
		return {}
	return SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("recipes", "rules").get("standards")).get(sid))


static func _base_difficulty(core: SurvivalCore, a: Dictionary, params: Dictionary, res: Dictionary) -> float:
	var D := SurvivalUtil.num(a.get("difficulty"), 0.0)
	var rid := str(res.get("recipe", ""))
	if rid != "" and core.data.recipe(rid).has("difficulty"):
		D = SurvivalUtil.num(core.data.recipe(rid).get("difficulty"), D)
	var db := SurvivalUtil.dict(a.get("difficulty_by"))
	if db.has("no_axe") and not SurvivalInventory.has(core, "item.tool.axe"):
		D = maxf(D, SurvivalUtil.num(db.no_axe, D))
	if db.has("per_press"):
		D += SurvivalUtil.num(db.per_press, 10.0) * float(SurvivalTrade.haggle_presses(core, str(params.get("tr", ""))))
	if db.is_empty():
		return D
	var tinder := str(res.get("tinder", ""))
	if tinder != "" and db.has(tinder):
		D = SurvivalUtil.num(db[tinder], D)
		if tinder == "item.tinder.punk" or tinder == "item.tinder.fungus":
			D += SurvivalUtil.num(SurvivalSkills.flag(core, "survival", "fire.punk_fungus_difficulty_add", 0.0), 0.0)
	var item := str(res.get("item", ""))
	if item != "" and db.has(item):
		D = SurvivalUtil.num(db[item], D)
	var outdoors := not bool(core.state.context.get("indoors", false))
	if outdoors and SurvivalWeather.is_wet(core) and db.has("weather.wet"):
		D = maxf(D, SurvivalUtil.num(db["weather.wet"], D))
		var opt := SurvivalUtil.arr(SurvivalUtil.dict(a.get("requires")).get("tools_optional"))
		if db.has("weather.wet_without_cutting_tool") and not opt.is_empty() and not SurvivalInventory.missing_tools(core, opt).is_empty():
			D = SurvivalUtil.num(db["weather.wet_without_cutting_tool"], D)
	if db.has("rain_after_tracks") and SurvivalWeather.precip(core) == "rain":
		D = SurvivalUtil.num(db.rain_after_tracks, D)
	elif db.has("fresh_snow") and SurvivalWeather.fresh_snow(core, 24.0):
		D = SurvivalUtil.num(db.fresh_snow, D)
	var cid := str(res.get("carcass_id", ""))
	if cid != "":
		var kind := str(SurvivalCamp.carcass(core, cid).get("kind", "small"))
		if db.has(kind):
			D = SurvivalUtil.num(db[kind], D)
		elif kind != "deer" and db.has("small"):
			D = SurvivalUtil.num(db.small, D)
		elif db.has("others"):
			D = SurvivalUtil.num(db.others, D)
	if db.has("night_with_light") and SurvivalClock.is_night(core):
		D = SurvivalUtil.num(db.night_with_light, D)
	elif db.has("daytime") and not SurvivalClock.is_night(core):
		D = SurvivalUtil.num(db.daytime, D)
	if db.has("no_bait") and SurvivalInventory.by_cat(core, "bait").is_empty():
		D = SurvivalUtil.num(db.no_bait, D)
	var fr := SurvivalUtil.dict(res.get("forage"))
	if db.has("per_item") and not fr.is_empty():
		D = SurvivalUtil.num(fr.get("d"), D)
	return D


static func _mod_row(core: SurvivalCore, id: String) -> Dictionary:
	return SurvivalUtil.dict(core.data.check_mods.get(id))


static func _mod_add(core: SurvivalCore, id: String, def: float) -> float:
	var v = _mod_row(core, id).get("add", def)
	if typeof(v) == TYPE_ARRAY:
		return SurvivalUtil.num(v[0], def) if not v.is_empty() else def
	return SurvivalUtil.num(v, def)


## The check's modifiers: {sum, factors: [{src, label, add, hint}], hint}. Condition penalties come from the modifier
## contract (check_mod, and fine_work_mod on fine work); the situation's from the action's skills.json modifier list.
static func check_factors(core: SurvivalCore, a: Dictionary, params: Dictionary, res: Dictionary, hurry: bool) -> Dictionary:
	var factors := []
	var fine := bool(a.get("fine_work", false))
	var mods := core.get_modifiers()
	var cond_sum := SurvivalUtil.num(mods.get("check_mod"), 0.0) + (SurvivalUtil.num(mods.get("fine_work_mod"), 0.0) if fine else 0.0)
	var cold_fine := false
	for s in SurvivalConditions.sources(core):
		var e: Dictionary = s.effects
		var add := SurvivalUtil.num(e.get("check_mod"), 0.0) + (SurvivalUtil.num(e.get("fine_work_mod"), 0.0) if fine else 0.0)
		if absf(add) > 0.0001:
			var src := str(s.src)
			var label := str(s.label)
			if src == "cond.cold" and fine:
				cold_fine = SurvivalUtil.num(e.get("fine_work_mod"), 0.0) < 0.0
				label = "cold hands"
			var hint := str(_mod_row(core, str(COND_HINT_MOD.get(src, ""))).get("hint", ""))
			factors.append({"src": src, "label": label, "add": add, "hint": hint})
	var sum := cond_sum
	# v4: the task's own challenge counts the environment and cold hands, never impairments or hurrying.
	var task_sum := 0.0
	for f0 in factors:
		if str(f0.src) == "cond.cold":
			task_sum += float(f0.add)
	var mlist := SurvivalUtil.arr(a.get("modifiers"))
	var ctx := core.state.context
	var indoors := bool(ctx.get("indoors", false))
	var sh := SurvivalCamp.current_shelter(core)
	var in_sh := bool(ctx.get("in_shelter", false)) and not sh.is_empty()
	var sh_q := SurvivalUtil.num(sh.get("quality"), 0.0) if in_sh else 0.0
	var is_fire := str(a.get("cat", "")) == "fire"
	var env := []
	var pr := SurvivalWeather.precip(core)
	if mlist.has("mod.rain") and pr == "rain" and not indoors and (is_fire or fine):
		var row := _mod_row(core, "mod.rain")
		env.append(["mod.rain", "rain", SurvivalUtil.num(row.get("sheltered_add"), -0.05) if sh_q >= 3.0 else _mod_add(core, "mod.rain", -0.2)])
	if mlist.has("mod.snow_falling") and pr == "snow" and not indoors and sh_q < 3.0 and (is_fire or fine):
		env.append(["mod.snow_falling", "snow", _mod_add(core, "mod.snow_falling", -0.1)])
	if mlist.has("mod.strong_wind") and not indoors and sh_q < 2.0:
		var thr := SurvivalUtil.num(_mod_row(core, "mod.strong_wind").get("threshold_ms"), 8.0)
		if SurvivalWeather.wind_ms(core) >= thr:
			env.append(["mod.strong_wind", "strong wind", _mod_add(core, "mod.strong_wind", -0.1)])
	if mlist.has("mod.night_no_light") and not is_fire and not indoors and SurvivalClock.light_level(core) < DARK_LIGHT and not _has_light(core, params):
		env.append(["mod.night_no_light", "dark", _mod_add(core, "mod.night_no_light", -0.1)])
	if mlist.has("mod.cold_hands") and fine and not cold_fine and not indoors and SurvivalClock.air_temp_c(core) < -10.0 \
			and not _warming_at_fire(core):
		env.append(["mod.cold_hands", "cold hands", _mod_add(core, "mod.cold_hands", -0.1)])
	if mlist.has("mod.flame_tinder") and (SurvivalInventory.has(core, "item.tinder.birchbark") or SurvivalInventory.has(core, "item.tinder.cedarbark")):
		env.append(["mod.flame_tinder", "birch bark in the nest", _mod_add(core, "mod.flame_tinder", 0.05)])
	var tinder := str(res.get("tinder", ""))
	if tinder != "" and _count_dry(core, tinder) < 1.0 - 0.0001:
		env.append(["mod.damp_tinder", "damp tinder", DAMP_TINDER_ADD])
	# v4 knowledge and learning modifiers: untried (heard of or only seen), a second try after a failure, recently taught.
	var kid := SurvivalLearning.job_kid(core, a, res)
	if kid != "":
		var at := SurvivalLearning.attempt(core, kid)
		if float(at.untried_add) != 0.0:
			env.append(["mod.untried", "untried", float(at.untried_add)])
		if SurvivalLearning.recently_taught(core, kid):
			env.append(["mod.recently_taught", "recently taught", _mod_add(core, "mod.recently_taught", 0.05)])
	if SurvivalLearning.second_try_active(core, str(a.get("id", ""))):
		env.append(["mod.second_try", "second try", _mod_add(core, "mod.second_try", 0.05)])
	if hurry:
		var hc := SurvivalUtil.num(SurvivalUtil.dict(core.data.section("actions", "job_runner").get("hurry")).get("check_add"), -0.05)
		env.append(["mod.hurry", "hurrying", hc])
	for e2 in env:
		sum += float(e2[2])
		if str(e2[0]) != "mod.hurry":
			task_sum += float(e2[2])
		factors.append({"src": str(e2[0]), "label": str(e2[1]), "add": float(e2[2]), "hint": str(_mod_row(core, str(e2[0])).get("hint", ""))})
	factors.sort_custom(func(x, y): return absf(float(x.add)) > absf(float(y.add)))
	var hint := ""
	for f in factors:
		if float(f.add) < 0.0 and str(f.hint) != "":
			hint = str(f.hint)
			break
	return {"sum": sum, "task_sum": task_sum, "factors": factors, "hint": hint}


static func _has_light(core: SurvivalCore, params: Dictionary) -> bool:
	if bool(params.get("light", false)) or bool(core.state.context.get("light", false)):
		return true
	if SurvivalInventory.has(core, "item.tool.torch") or SurvivalInventory.has(core, "item.tool.lantern"):
		return true
	var f := SurvivalCamp.current_fire(core)
	return not f.is_empty() and str(f.state) == "lit" and SurvivalUtil.num(core.state.context.get("fire_distance_m"), 99.0) <= FIRELIGHT_M


static func _warming_at_fire(core: SurvivalCore) -> bool:
	var f := SurvivalCamp.current_fire(core)
	return not f.is_empty() and str(f.state) == "lit" and SurvivalUtil.num(core.state.context.get("fire_distance_m"), 99.0) <= 2.0


static func _can_hurry(core: SurvivalCore, a: Dictionary) -> bool:
	var tm := SurvivalUtil.pair(a.get("time_min"), 0.0)
	return SurvivalUtil.num(a.get("difficulty"), 0.0) > 0.0 and tm.y >= 10.0


## Game minutes of work: faster with skill, the perk's time multiplier, hurry and the outcome's time_mult.
static func work_minutes(core: SurvivalCore, a: Dictionary, S: float, D: float, hurry: bool, outcome_row: Dictionary, params: Dictionary, res: Dictionary = {}) -> float:
	var id := str(a.get("id", ""))
	if id == "rest.sleep" or id == "rest.wait":
		return _rest_minutes(core, a, params)
	if id == "learn.watch":
		return SurvivalLearning.watch_minutes(core, str(params.get("action", "")))
	var tm := SurvivalUtil.pair(a.get("time_min"), 1.0)
	var rid := str(res.get("recipe", ""))
	var rrow := core.data.recipe(rid) if rid != "" else {}
	if rrow.has("time_min"):
		tm = SurvivalUtil.pair(rrow.get("time_min"), tm.x)
	var f := clampf((S - D - SKILL_TIME_LOW) / SKILL_TIME_SPAN, 0.0, 1.0)
	var t := lerpf(tm.y, tm.x, f)
	if id == "butcher.field_dress":
		t = _dress_minutes(core, a, params, t)
	t *= SurvivalUtil.num(core.perk_effect("time_mult." + id, 1.0), 1.0)
	for tool in SurvivalUtil.dict(rrow.get("time_mult_with")).keys():
		if SurvivalInventory.has(core, str(tool)):
			t *= SurvivalUtil.num(rrow.time_mult_with[tool], 1.0)
	var kid := SurvivalLearning.job_kid(core, a, res)
	if kid != "":
		t *= float(SurvivalLearning.attempt(core, kid).time_mult)
	t *= SurvivalUtil.num(standard_row(core, params).get("time_mult"), 1.0)
	var build := SurvivalUtil.dict(a.get("build"))
	if not build.is_empty() and not SurvivalInventory.has(core, "item.tool.axe"):
		t *= SurvivalUtil.num(build.get("time_mult_without_axe"), 1.0)
	if hurry:
		t *= SurvivalUtil.num(SurvivalUtil.dict(core.data.section("actions", "job_runner").get("hurry")).get("time_mult"), 0.6)
	# No job stage is longer than the production rule's stage cap (seasons.json time.production_rule: 120 game minutes);
	# longer work is made in resumable stages.
	t = minf(t, stage_cap(core))
	t *= SurvivalUtil.num(outcome_row.get("time_mult"), 1.0)
	if params.has("time_min"):
		t = float(params.time_min)
	return maxf(0.5, t)


static func stage_cap(core: SurvivalCore) -> float:
	return SurvivalUtil.num(SurvivalUtil.dict(core.data.section("seasons", "time").get("production_rule")).get("stage_cap_game_min"), 1.0e9)


static func _dress_minutes(core: SurvivalCore, a: Dictionary, params: Dictionary, t: float) -> float:
	var cid := _pick_carcass(core, params, "dress")
	if cid == "":
		return t
	var kind := str(SurvivalCamp.carcass(core, cid).get("kind", "small"))
	var cy := SurvivalUtil.dict(core.data.section("actions", "carcass_yields").get(kind))
	return SurvivalUtil.num(cy.get("field_dress_min"), t)


static func _rest_minutes(core: SurvivalCore, a: Dictionary, params: Dictionary) -> float:
	var tm := SurvivalUtil.pair(a.get("time_min"), 60.0)
	var h := SurvivalUtil.num(params.get("hours"), -1.0)
	if h <= 0.0:
		var now := SurvivalClock.hour(core)
		var sr := SurvivalClock.sunrise_h(core) + 0.5
		if SurvivalClock.is_night(core) or now >= SurvivalClock.sunset_h(core) - 1.0:
			h = fposmod(sr - now, 24.0)
		else:
			h = DEFAULT_SLEEP_H
	return clampf(h * 60.0, tm.x, tm.y)


static func _screen_seconds(a: Dictionary, S: float, D: float) -> float:
	var ss := SurvivalUtil.pair(a.get("screen_s"), 2.0)
	var f := clampf((S - D - SKILL_TIME_LOW) / SKILL_TIME_SPAN, 0.0, 1.0)
	return maxf(0.5, lerpf(ss.y, ss.x, f))


# ---------------------------------------------------------------- preview (the prompt)
## Everything the prompt shows (skills.json check_model.prompt):
##   {ok, reasons, action, name, chance, pct, D, S, factors (top 3), hint, materials_at_risk, time_min, anim, prompt,
##    risk_line, can_hurry, resumes}
## resumes: start() would pick up a cancelled job's kept progress; time_min is then the time left, and chance and pct
## are the check it already rolled (a resumed job never rolls again).
static func preview(core: SurvivalCore, id: String, params: Dictionary = {}) -> Dictionary:
	return _preview(core, id, params, requirements(core, id, params))


static func _preview(core: SurvivalCore, id: String, params: Dictionary, rq: Dictionary) -> Dictionary:
	var a := action(core, id)
	var out := {"ok": bool(rq.ok), "reasons": rq.reasons, "action": id, "name": str(a.get("name", id))}
	if a.is_empty():
		return out
	var res: Dictionary = rq.resolved
	var hurry := bool(params.get("hurry", false)) and _can_hurry(core, a)
	var D := difficulty(core, a, params, res)
	var sk := str(a.get("skill", ""))
	var S := SurvivalSkills.level(core, sk)
	var cf := check_factors(core, a, params, res, hurry)
	var has_check := D > 0.0
	var p := SurvivalSkills.chance(core, S, D, float(cf.sum)) if has_check else 1.0
	out["D"] = D
	out["S"] = S
	out["skill"] = sk
	out["chance"] = p
	out["pct"] = int(round(p * 100.0))
	out["has_check"] = has_check
	out["factors"] = SurvivalUtil.arr(cf.factors).slice(0, 3)
	out["hint"] = str(cf.hint)
	out["can_hurry"] = _can_hurry(core, a)
	out["time_min"] = work_minutes(core, a, S, D, hurry, {}, params, res)
	var kid0 := SurvivalLearning.job_kid(core, a, res)
	if kid0 != "":
		out["knowledge"] = {"id": kid0, "state": SurvivalLearning.state_of(core, kid0)}
	out["anim"] = core.data.anim_hook_for(id)
	out["materials_at_risk"] = _materials_at_risk(core, a, res)
	if id == "eat":
		# The eat prompt shows what the food in the pack weighs, and what the cache here holds (F9: meat belongs on the
		# meat pole, not in the pack).
		out["food_kg"] = snappedf(SurvivalCamp.food_kg_carried(core), 0.1)
		var c := SurvivalCamp.cache_at(core, str(core.state.context.get("location", "")))
		if not c.is_empty():
			out["cache_meals"] = snappedf(SurvivalCamp.cache_meals_of(core, c), 0.1)
	var kept := _kept_progress(core, _progress_key(core, id, params, res)) if bool(rq.ok) else {}
	out["resumes"] = not kept.is_empty()
	if not kept.is_empty():
		has_check = bool(kept.get("has_check", has_check))
		out["has_check"] = has_check
		out["chance"] = SurvivalUtil.num(kept.get("p"), p)
		out["pct"] = int(round(float(out.chance) * 100.0))
		out["factors"] = SurvivalUtil.arr(kept.get("factors"))
		out["time_min"] = maxf(0.0, SurvivalUtil.num(kept.get("duration_min"), 0.0) - SurvivalUtil.num(kept.get("elapsed_min"), 0.0))
	var parts := PackedStringArray()
	for f in out.factors:
		parts.append("%s %+d%%" % [str(f.label), int(round(float(f.add) * 100.0))])
	var line := "[E] %s" % str(a.get("name", id))
	if not kept.is_empty():
		line += " (resume, %d min left)" % ceili(float(out.time_min))
	if has_check:
		line += " · %d%%" % int(out.pct)
		if not parts.is_empty():
			line += " · " + ", ".join(parts)
		if str(cf.hint) != "":
			line += " · Hint: " + str(cf.hint)
	out["prompt"] = line
	out["risk_line"] = ("At risk on failure: " + ", ".join(PackedStringArray(out.materials_at_risk))) if not SurvivalUtil.arr(out.materials_at_risk).is_empty() else ""
	return out


static func _materials_at_risk(core: SurvivalCore, a: Dictionary, res: Dictionary) -> Array:
	var mar = a.get("materials_at_risk")
	if mar == null:
		return []
	var out := []
	for k in SurvivalUtil.dict(a.get("consumes")).keys():
		var item := _consume_item(core, str(k), res)
		if item != "":
			out.append("%s %s" % [SurvivalEconomy._qty_s(SurvivalUtil.num(a.consumes[k], 1.0)), core.data.item_name(item).to_lower()])
	if out.is_empty():
		if typeof(mar) == TYPE_ARRAY:
			for m in mar:
				out.append(str(m))
		else:
			out.append(str(mar))
	return out


# ---------------------------------------------------------------- start, progress, interrupt
## Start a job. Returns {ok, reason, reasons, job}. A cancelled job's progress (and its rolled outcome) is resumed.
static func start(core: SurvivalCore, id: String, params: Dictionary = {}) -> Dictionary:
	if is_running(core):
		return {"ok": false, "reason": "busy with %s" % str(current(core).get("action", ""))}
	var a := action(core, id)
	var rq := requirements(core, id, params)
	if not bool(rq.ok):
		return {"ok": false, "reason": "; ".join(PackedStringArray(rq.reasons)), "reasons": rq.reasons}
	# A timed trade job pins the session version it started on (the version on the player's screen).
	if (id == "trade.barter" or id == "trade.haggle") and not params.has("version"):
		params = params.duplicate()
		params["version"] = int(SurvivalTrade.session(core, str(params.get("tr", ""))).get("version", -1))
	var res: Dictionary = rq.resolved
	var hurry := bool(params.get("hurry", false)) and _can_hurry(core, a)
	var key := _progress_key(core, id, params, res)
	var prog := _kept_progress(core, key)
	var job := {}
	if not prog.is_empty():
		job = prog.duplicate(true)
		job["resumed"] = true
		job["params"] = params.duplicate(true)
		job["resolved"] = res
	else:
		var D := difficulty(core, a, params, res)
		var sk := str(a.get("skill", ""))
		var S := SurvivalSkills.level(core, sk)
		var cf := check_factors(core, a, params, res, hurry)
		var has_check := D > 0.0
		var p := SurvivalSkills.chance(core, S, D, float(cf.sum)) if has_check else 1.0
		var outcome := "success"
		if has_check:
			outcome = SurvivalSkills.roll(core, p, _hazard_now(core, a), hurry)
		var orow := _outcome_row(a, outcome, core.data.recipe(str(res.get("recipe", ""))))
		job = {"action": id, "key": key, "params": params.duplicate(true), "resolved": res, "D": D, "S": S, "p": p,
				"mods_sum": float(cf.sum), "task_mods": float(cf.get("task_sum", cf.sum)), "factors": SurvivalUtil.arr(cf.factors).slice(0, 3),
				"has_check": has_check, "outcome": outcome, "hurry": hurry, "elapsed_min": 0.0,
				"duration_min": work_minutes(core, a, S, D, hurry, orow, params, res), "screen_s": _screen_seconds(a, S, D),
				"started_min": core.state.minutes, "kid": SurvivalLearning.job_kid(core, a, res),
				"standard": str(params.get("standard", "plain"))}
	_jobs(core).progress.erase(key)
	job["anim"] = core.data.anim_hook_for(id)
	job["interrupt"] = str(a.get("interrupt", "move_cancels_keep_progress"))
	job["resume_activity"] = core.state.activity
	var act := str(ACTIVITY_BY_ANIM.get(str(a.get("anim", "")), ""))
	if act != "":
		core.state.activity = act
	if id == "rest.sleep":
		core.state.asleep = true
		core.state.activity = "sleep"
	# Conditions follow the needs at once, so the wake rules compare against the state the job really starts from.
	SurvivalConditions.update_driven(core)
	job["watch"] = core.watch_snapshot()
	_jobs(core)["current"] = job
	core.invalidate_modifiers()
	if not core._suppress_signals:
		core.job_started.emit(job)
	return {"ok": true, "job": job}


## Can this attempt end in a mishap? The action lists a hazard, and a hazard tied to thin ice needs thin ice.
static func _hazard_now(core: SurvivalCore, a: Dictionary) -> bool:
	if not a.has("hazard"):
		return false
	var hz := SurvivalUtil.dict(a.hazard)
	if hz.has("only_if_ice_cm_below"):
		return SurvivalClock.month_value(core, "river_ice_cm") < SurvivalUtil.num(hz.only_if_ice_cm_below, 15.0)
	return true


## Progress kept from a cancelled job under this key, or {} when there is none or it is older than PROGRESS_KEEP_MIN.
static func _kept_progress(core: SurvivalCore, key: String) -> Dictionary:
	var prog := SurvivalUtil.dict(SurvivalUtil.dict(_jobs(core).get("progress")).get(key))
	if prog.is_empty() or core.state.minutes - SurvivalUtil.num(prog.get("paused_at"), -1e9) > PROGRESS_KEEP_MIN:
		return {}
	return prog


static func _progress_key(core: SurvivalCore, id: String, params: Dictionary, res: Dictionary) -> String:
	var target := str(res.get("trap_id", res.get("carcass_id", "")))
	if target == "":
		target = str(core.state.context.get("location", ""))
	return id + "|" + target


## The outcome row for a tier: the action's (falling back excellent -> success, mishap -> failure), with a recipe's own
## outcome rows laid over it (rcp.dress_hide: a hide that goes hard in the working still makes rawhide).
static func _outcome_row(a: Dictionary, outcome: String, r: Dictionary = {}) -> Dictionary:
	var oc := SurvivalUtil.dict(a.get("outcomes"))
	var o := outcome
	var guard := 0
	while o != "" and not oc.has(o) and guard < 4:
		o = str(OUTCOME_FALLBACK.get(o, ""))
		guard += 1
	var row := SurvivalUtil.dict(oc.get(o, {}))
	var ro := SurvivalUtil.dict(SurvivalUtil.dict(r.get("outcomes")).get(outcome))
	if not ro.is_empty():
		row = row.duplicate(true)
		for k in ro.keys():
			row[k] = ro[k]
	return row


## Called by SurvivalCore.advance() after every step: progress, the wake rules, completion.
static func after_step(core: SurvivalCore, step_min: float) -> void:
	var j := current(core)
	if j.is_empty():
		return
	j["elapsed_min"] = SurvivalUtil.num(j.get("elapsed_min"), 0.0) + step_min
	if SurvivalUtil.num(j.elapsed_min) >= SurvivalUtil.num(j.get("duration_min"), 0.0) - 0.0001:
		_complete(core)
		return
	if str(j.get("interrupt", "")) == "instant":
		return
	var radius := SLEEP_THREAT_M if core.state.asleep else JOB_THREAT_M
	var why := core.watch_triggers(SurvivalUtil.dict(j.get("watch")), radius)
	if why != "":
		interrupt(core, why)


static func check_threat(core: SurvivalCore) -> void:
	var j := current(core)
	if j.is_empty() or str(j.get("interrupt", "")) == "instant":
		return
	var radius := SLEEP_THREAT_M if core.state.asleep else JOB_THREAT_M
	var t := SurvivalUtil.num(core.state.context.get("threat_m"), 9999.0)
	if t <= radius:
		interrupt(core, "a threat at %d m" % int(t))


## Stop the running job. Progress is kept (with its rolled outcome) unless the action loses it on a cancel.
static func interrupt(core: SurvivalCore, reason: String) -> void:
	var j := current(core)
	if j.is_empty():
		return
	var id := str(j.get("action", ""))
	var keep := str(j.get("interrupt", "")) == "move_cancels_keep_progress" and id != "rest.sleep"
	if keep and SurvivalUtil.num(j.get("elapsed_min"), 0.0) > 0.0:
		var saved := j.duplicate(true)
		saved.erase("watch")
		saved["paused_at"] = core.state.minutes
		var progress: Dictionary = _jobs(core).progress
		# Drop progress nobody came back for (it could no longer be resumed), so saves do not grow with it.
		for k in progress.keys():
			if core.state.minutes - SurvivalUtil.num(progress[k].get("paused_at"), -1e9) > PROGRESS_KEEP_MIN:
				progress.erase(k)
		progress[str(j.key)] = saved
	_jobs(core)["current"] = {}
	_end_activity(core, j)
	var slept := id == "rest.sleep"
	if slept:
		_after_sleep(core, j, reason)
	core.state.stats["interrupts"] = int(SurvivalUtil.num(core.state.stats.get("interrupts"), 0.0)) + 1
	var res := {"ok": false, "action": id, "interrupted": reason, "kept_progress": keep,
			"elapsed_min": SurvivalUtil.num(j.get("elapsed_min"), 0.0), "duration_min": SurvivalUtil.num(j.get("duration_min"), 0.0)}
	_push_result(core, res)
	core.invalidate_modifiers()
	if not core._suppress_signals:
		core.job_interrupted.emit(j, reason)


static func _end_activity(core: SurvivalCore, j: Dictionary) -> void:
	core.state.activity = str(j.get("resume_activity", "rest"))
	if core.state.activity == "sleep" or core.state.activity == "":
		core.state.activity = "rest"


static func _after_sleep(core: SurvivalCore, j: Dictionary, reason: String) -> void:
	core.state.asleep = false
	var h := SurvivalUtil.num(j.get("elapsed_min"), 0.0) / 60.0
	core.state.stats["sleep_h"] = SurvivalUtil.num(core.state.stats.get("sleep_h"), 0.0) + h
	core.note_sleep(h)
	if reason != "rested":
		core.state.stats["wakes"] = int(SurvivalUtil.num(core.state.stats.get("wakes"), 0.0)) + 1
		core.log_line("woke: %s" % reason, "sleep")
	if not core._suppress_signals:
		core.woke.emit(reason)
	# Deferred to the end of the step or call, and skipped on death (SurvivalCore.autosave_requested).
	core.request_autosave("sleep")


## Start a job and advance time until it ends. Returns the job's result ({ok, outcome, ...} or {interrupted}); when a
## job chains into another by itself (a partial strike nursed with birch bark), the chained result is in result.then.
static func run(core: SurvivalCore, id: String, params: Dictionary = {}) -> Dictionary:
	var seq0 := int(SurvivalUtil.num(_jobs(core).get("seq"), 0.0))
	var r := start(core, id, params)
	if not bool(r.ok):
		return r
	var guard := 0
	while is_running(core) and not core.is_dead() and guard < 10000:
		core.advance(maxf(0.01, minf(240.0, minutes_left(core))), true)
		guard += 1
	var got := []
	for x in SurvivalUtil.arr(_jobs(core).get("recent")):
		if int(SurvivalUtil.num(x.get("seq"), 0.0)) > seq0:
			got.append(x)
	if got.is_empty():
		return SurvivalUtil.dict(_jobs(core).get("last_result"))
	var first: Dictionary = got[0].duplicate(true)
	if got.size() > 1:
		first["then"] = got[got.size() - 1]
	return first


## Record a finished or interrupted job's result (last_result, and the few most recent with a sequence number).
static func _push_result(core: SurvivalCore, res: Dictionary) -> void:
	var jb := _jobs(core)
	var seq := int(SurvivalUtil.num(jb.get("seq"), 0.0)) + 1
	jb["seq"] = seq
	res["seq"] = seq
	jb["last_result"] = res
	var recent: Array = SurvivalUtil.arr(jb.get("recent"))
	recent.append(res)
	while recent.size() > 6:
		recent.remove_at(0)
	jb["recent"] = recent


# ---------------------------------------------------------------- completion
static func _complete(core: SurvivalCore) -> void:
	var j := current(core)
	var id := str(j.get("action", ""))
	var a := action(core, id)
	_jobs(core)["current"] = {}
	_end_activity(core, j)
	var params := SurvivalUtil.dict(j.get("params"))
	# The world may have changed while working (a pelt sold, the fire out): the targets must still be there. The check
	# asks about what the job started with (the meal, the tinder, the trap), not a fresh pick.
	var pinned := params.duplicate()
	var started := SurvivalUtil.dict(j.get("resolved"))
	for k in PINNED_AT_COMPLETION:
		if not pinned.has(k) and started.has(k):
			pinned[k] = started[k]
	var rq := requirements(core, id, pinned, true)
	if not bool(rq.ok) and id != "rest.sleep" and id != "rest.wait":
		var res0 := {"ok": false, "action": id, "interrupted": "; ".join(PackedStringArray(rq.reasons)), "kept_progress": false}
		_push_result(core, res0)
		if not core._suppress_signals:
			core.job_interrupted.emit(j, str(res0.interrupted))
		return
	var resolved: Dictionary = rq.resolved
	for k in SurvivalUtil.dict(j.get("resolved")).keys():
		if not resolved.has(k):
			resolved[k] = j.resolved[k]
	var outcome := str(j.get("outcome", "success"))
	var orow := _outcome_row(a, outcome, core.data.recipe(str(resolved.get("recipe", ""))))
	var res := {"ok": true, "action": id, "outcome": outcome, "chance": SurvivalUtil.num(j.get("p"), 1.0),
			"D": SurvivalUtil.num(j.get("D"), 0.0), "minutes": SurvivalUtil.num(j.get("elapsed_min"), 0.0),
			"hurry": bool(j.get("hurry", false)), "gained": {}, "notes": [], "unhandled": []}
	_consume(core, a, outcome, resolved)
	_apply_effects(core, a, outcome, orow, params, resolved, res)
	# Growth from the check (growth model v4: the task's own modifiers set the challenge).
	if bool(j.get("has_check", false)):
		res["xp"] = SurvivalSkills.gain_from_check(core, a, float(j.D), outcome, float(j.mods_sum), float(j.p), float(j.get("task_mods", j.mods_sum)))
		_tally_check(core, id, outcome)
		# Knowledge: trial promotion and counted successes toward practised and mastered.
		var kid := str(j.get("kid", ""))
		if kid != "":
			SurvivalLearning.record_result(core, kid, outcome, str(j.get("standard", "plain")))
			res["knowledge"] = {"id": kid, "state": SurvivalLearning.state_of(core, kid)}
		if outcome == "failure" or outcome == "mishap":
			SurvivalLearning.note_failure(core, id)
		else:
			SurvivalLearning.clear_second_try(core, id)
	else:
		SurvivalSkills.gain_from_check(core, a, 0.0, outcome, 0.0, 1.0)
	_habit_counters(core, id)
	SurvivalLearning.check_notices(core)
	if id == "rest.sleep":
		_after_sleep(core, j, "rested")
	SurvivalConditions.update_driven(core)
	core._update_stages()
	_push_result(core, res)
	core.invalidate_modifiers()
	if not core._suppress_signals:
		core.job_finished.emit(res)
	# A job that chains by itself (a partial strike nursed when a flame tinder is carried).
	if str(res.get("auto_next", "")) != "":
		start(core, str(res.auto_next), {"hurry": bool(j.get("hurry", false))})


## Habits anyone earns by doing (backgrounds.json habits earned_by): 150 line checks make a line hand.
static func _habit_counters(core: SurvivalCore, id: String) -> void:
	if id == "trap.check":
		core.count_habit("line_checks")


static func _tally_check(core: SurvivalCore, id: String, outcome: String) -> void:
	var cs: Dictionary = core.state.stats.get("checks", {})
	var row: Dictionary = cs.get(id, {})
	row["n"] = int(SurvivalUtil.num(row.get("n"), 0.0)) + 1
	row[outcome] = int(SurvivalUtil.num(row.get(outcome), 0.0)) + 1
	cs[id] = row
	core.state.stats["checks"] = cs


static func _consume_item(core: SurvivalCore, key: String, res: Dictionary) -> String:
	match key:
		"tinder":
			return str(res.get("tinder", ""))
		"flame_tinder":
			return str(res.get("flame_tinder", ""))
		"fuel":
			var f := str(res.get("fuel", ""))
			if f == "":
				for it in SurvivalCamp.FUEL_ORDER:
					if SurvivalInventory.has(core, it):
						return it
			return f
	return key if not core.data.item(key).is_empty() else ""


## Materials go on a good result; on a failure only where they are really at risk and the failure rule does not keep
## them (a failed deadfall keeps its stakes); on a mishap wherever they are at risk (actions.json failure_rule). A trap
## item is used up only when the trap is set.
static func _consume(core: SurvivalCore, a: Dictionary, outcome: String, res: Dictionary) -> void:
	var cons := SurvivalUtil.dict(a.get("consumes"))
	if cons.is_empty():
		return
	var at_risk := a.get("materials_at_risk") != null
	var kept_on_failure := SurvivalUtil.arr(core.data.section("actions", "failure_rule").get("actions")).has(str(a.id))
	for k in cons.keys():
		var item := _consume_item(core, str(k), res)
		if item == "":
			continue
		var go := true
		match outcome:
			"failure":
				go = at_risk and not kept_on_failure and core.data.item_cat(item) != "trap"
			"mishap":
				go = at_risk
		if not go:
			continue
		var qty := SurvivalUtil.num(cons[k], 1.0)
		var filt := {}
		if str(k) == "tinder":
			filt = {"damp": null}
		elif item == "item.trap.stake_set":
			filt = {"quality": null} if str(res.get("stake_quality", "good")) == "good" else {"quality": "usable"}
		var got := 0.0
		if not filt.is_empty():
			for p in SurvivalInventory.remove(core, item, qty, filt):
				got += float(p.qty)
		if got < qty - 0.0001:
			SurvivalInventory.remove(core, item, qty - got)
		res["consumed_" + str(k)] = item


# ---------------------------------------------------------------- effects
static func _apply_effects(core: SurvivalCore, a: Dictionary, outcome: String, o: Dictionary, params: Dictionary, rs: Dictionary, res: Dictionary) -> void:
	var id := str(a.id)
	var ym := SurvivalUtil.num(o.get("yield_mult"), 1.0) * SurvivalUtil.num(o.get("yield_cut"), 1.0)
	var loc := str(core.state.context.get("location", ""))
	var handled := ["time_mult", "yield_mult", "yield_cut", "note", "shelter_quality", "set_quality", "placement",
			"auto_next_if_carried", "auto_feed", "sign_marker", "track_age", "autosave", "reset", "grade_hint",
			"stake_quality", "coal_game_h", "infection_mult", "output_variant", "ground_ins", "taint_chance", "taint",
			"flag", "consume", "sleep", "wait", "kcal_mult", "price_mult", "grade", "refund_inputs", "until",
			"build_quality_add", "cache_quality", "durability_mult", "quality"]
	if o.has("note"):
		res.notes.append(str(o.note))
	# Recipes (craft.stakes -> rcp.stake_set) run through SurvivalCrafting with this outcome's yield.
	if a.has("recipes") and str(rs.get("recipe", "")) != "":
		var meta := {}
		if o.has("stake_quality") and str(o.stake_quality) != "good":
			meta["quality"] = str(o.stake_quality)
		if o.has("grade"):
			meta["grade"] = str(o.grade)
		if o.has("price_mult"):
			meta["value_mult"] = SurvivalUtil.num(o.price_mult, 1.0)
		var stdq := SurvivalUtil.num(standard_row(core, params).get("quality"), 1.0)
		if stdq != 1.0:
			# A partial above plain gives the product one standard lower (recipes.json rules.standards.partial_rule).
			meta["quality"] = _standard_quality(core, params, outcome)
			meta["standard"] = str(params.get("standard", "plain"))
		var ay := ym if (o.has("yield_mult") or o.has("yield_cut")) else -1.0
		if outcome == "mishap":
			ay = 0.0
		var cr := SurvivalCrafting.apply(core, str(rs.recipe), outcome, ay, meta, str(o.get("output_variant", "")))
		res["recipe"] = cr
		for k in SurvivalUtil.dict(cr.get("made")).keys():
			_gained(res, str(k), float(cr.made[k]))
			core.state.stats["made_" + str(k)] = SurvivalUtil.num(core.state.stats.get("made_" + str(k)), 0.0) + float(cr.made[k])
	for key in o.keys():
		var v = o[key]
		match str(key):
			"give":
				for it in SurvivalUtil.dict(v).keys():
					var q := SurvivalUtil.num(v[it], 0.0) * ym
					if q > 0.0 and not core.data.item(str(it)).is_empty():
						SurvivalInventory.add(core, str(it), q)
						_gained(res, str(it), q)
			"give_from_node":
				var damp := str(o.get("flag", "")) == "damp_tinder"
				for it in SurvivalUtil.dict(v).keys():
					var q2 := SurvivalUtil.num(v[it], 0.0) * ym
					for i in int(round(q2)):
						var item := _gather_tinder(core) if str(it) == "tinder" else str(it)
						if item == "" or core.data.item(item).is_empty():
							continue
						SurvivalInventory.add(core, item, 1.0, {"damp": true} if damp and core.data.item_cat(item) == "tinder" else {})
						_gained(res, item, 1.0)
				_mark_node(core, params)
			"spawn":
				_spawn(core, a, o, v, params, rs, res)
			"set":
				var f := SurvivalCamp.current_fire(core)
				var fs := str(SurvivalUtil.dict(v).get("world.campfire", ""))
				if not f.is_empty() and fs != "":
					if fs == "banked":
						SurvivalCamp.bank(core, str(f.id), SurvivalUtil.num(o.get("coal_game_h"), 8.0))
					else:
						SurvivalCamp.set_fire_state(core, str(f.id), fs)
						if fs == "smouldering":
							f["coal_only"] = true
							f["ember_min"] = SurvivalCamp.STRIKE_COAL_MIN
					res["fire_id"] = str(f.id)
			"cond":
				var c := SurvivalUtil.dict(v)
				var cid := str(c.get("cond", ""))
				if cid != "" and cid != "cond.drunk":
					SurvivalConditions.add(core, cid, {"zone": str(c.get("zone", "")), "cause": id})
					res.notes.append("mishap: %s" % str(core.data.condition(cid).get("name", cid)).to_lower())
			"cond_chance":
				for cid2 in SurvivalUtil.dict(v).keys():
					if core.rng.randf() < SurvivalUtil.num(v[cid2], 0.0) and not core.data.condition(str(cid2)).is_empty():
						SurvivalConditions.add(core, str(cid2), {"cause": id})
			"need":
				_need_effect(core, SurvivalUtil.dict(v))
			"wet":
				core.state.needs["wetness"] = clampf(SurvivalUtil.num(core.state.needs.get("wetness"), 0.0) + SurvivalUtil.num(v, 0.0), 0.0, 1.0)
				core.state.flags["feet_wet"] = true
			"wetness":
				core.state.needs["wetness"] = clampf(SurvivalUtil.num(v, 0.0), 0.0, 1.0)
				if SurvivalUtil.num(v, 0.0) <= 0.0:
					core.state.flags.erase("feet_wet")
			"wetness_mult":
				core.state.needs["wetness"] = clampf(SurvivalUtil.num(core.state.needs.get("wetness"), 0.0) * SurvivalUtil.num(v, 1.0), 0.0, 1.0)
			"feet_ins_add":
				core.state.flags["feet_ins_add"] = SurvivalUtil.num(v, 0.0)
				res.notes.append("moccasins stuffed: warmer feet until they are soaked")
			"wear":
				for it2 in SurvivalUtil.dict(v).keys():
					SurvivalInventory.wear_tool(core, str(it2), SurvivalUtil.num(v[it2], 1.0))
			"next":
				res["next"] = str(v)
				for it3 in SurvivalUtil.arr(o.get("auto_next_if_carried")):
					if SurvivalInventory.has(core, str(it3)):
						res["auto_next"] = str(v)
						break
			"bedding":
				SurvivalCamp.set_bedding(core, loc, str(v), SurvivalUtil.num(o.get("ground_ins"), 1.0))
				res["bedding"] = str(v)
			"state":
				_cook(core, id, str(v), params, rs, res)
			"stop_bleeding":
				res["bound"] = SurvivalConditions.bind(core)
			"collect":
				var tr := SurvivalTrapLine.check(core, str(rs.get("trap_id", "")), outcome)
				res["trap_id"] = str(rs.get("trap_id", ""))
				res["caught"] = str(tr.get("caught", ""))
				res["carcass_id"] = str(tr.get("carcass", ""))
				res["reset"] = bool(tr.get("reset", false))
				core.state.flags["last_trap_work_min"] = core.state.minutes
			"reveal":
				_reveal(core, str(v), o, params, res)
			"pelt_grade":
				_skin(core, str(v), rs, res)
			"pelt_grade_shift":
				_stretch(core, int(SurvivalUtil.num(v, 0.0)), rs, res)
			"consume_serving":
				var dr := SurvivalFood.drink(core, str(v))
				res["drink"] = dr
				_merry_company(core)
			"credit_line":
				res["outfit"] = SurvivalEconomy.take_outfit(core, SurvivalUtil.dict(params.get("basket")))
			"fuel_add":
				var fire := SurvivalCamp.current_fire(core)
				var fuel := str(rs.get("consumed_fuel", rs.get("fuel", "")))
				if not fire.is_empty() and fuel != "":
					SurvivalCamp.add_fuel(core, str(fire.id), fuel, 1.0)
					res["fire_id"] = str(fire.id)
			"hydration":
				SurvivalFood.drink_water(core, "source_sip")
			"event":
				res.notes.append(str(v).replace("_", " "))
			"cure":
				for cid3 in SurvivalUtil.dict(v).keys():
					if core.state.conditions.has(str(cid3)) and core.rng.randf() < SurvivalUtil.num(v[cid3], 0.0):
						SurvivalConditions.remove(core, str(cid3))
						res.notes.append("cured: %s" % str(core.data.condition(str(cid3)).get("name", cid3)).to_lower())
			"cure_inflamed":
				if SurvivalConditions.stage_of(core, "cond.infection") == "inflamed" and core.rng.randf() < SurvivalUtil.num(v, 0.0):
					SurvivalConditions.remove(core, "cond.infection")
			"frostbite_stage_add":
				SurvivalExposure.shift_frostbite(core, int(SurvivalUtil.num(v, 0.0)))
			"heal_mult":
				for cid4 in core.state.conditions.keys():
					if str(core.data.condition(str(cid4)).get("family", "")) == "injury" and core.state.conditions[cid4].has("heal_h"):
						core.state.conditions[cid4]["heal_mult"] = maxf(SurvivalUtil.num(core.state.conditions[cid4].get("heal_mult"), 1.0), SurvivalUtil.num(v, 1.0))
			"duration_mult":
				for cid5 in SurvivalUtil.dict(v).keys():
					var rec5: Dictionary = core.state.conditions.get(str(cid5), {})
					if rec5.has("dur_h"):
						rec5["dur_h"] = SurvivalUtil.num(rec5.dur_h, 0.0) * SurvivalUtil.num(v[cid5], 1.0)
			"give_from_stock":
				var nt := _node_type_for(a)
				var ninst := str(params.get("node_id", core.state.context.get("node_id", "")))
				for it6 in SurvivalUtil.dict(v).keys():
					var got6 := SurvivalNodes.take(core, nt, str(it6), SurvivalUtil.num(v[it6], 0.0) * ym, ninst)
					if got6 > 0.0 and not core.data.item(str(it6)).is_empty():
						SurvivalInventory.add(core, str(it6), got6)
						_gained(res, str(it6), got6)
			"build_stage":
				var bs := SurvivalCamp.build_stage(core, SurvivalUtil.dict(a.get("build")), SurvivalUtil.num(o.get("build_quality_add"), 0.0))
				res["build"] = bs
				if bs.has("shelter_id"):
					res["shelter_id"] = str(bs.shelter_id)
			"shelter_wind_add":
				SurvivalCamp.add_wind(core, SurvivalUtil.num(v, 0.0))
			"durability_add":
				var mended := SurvivalInventory.mend(core, SurvivalUtil.arr(SurvivalUtil.dict(a.get("repairs")).get("items")), SurvivalUtil.num(v, 0.0))
				res["mended"] = mended
			"commit_trade":
				var tr := str(params.get("tr", ""))
				var s7 := SurvivalTrade.session(core, tr)
				if not s7.is_empty():
					res["trade"] = SurvivalTrade.confirm(core, tr, core.state.player_id, int(params.get("version", -1)))
			"lesson":
				var ob8 := SurvivalTrade.obligation(core, str(params.get("ob", "")))
				if not ob8.is_empty():
					res["lesson"] = SurvivalLearning.give_lesson(core, str(ob8.from), str(SurvivalUtil.dict(ob8.what).get("what", "")))
					SurvivalTrade.lesson_given(core, str(ob8.id))
			"watched":
				res["watched"] = SurvivalLearning.finish_watch(core, str(params.get("performer", "")), str(params.get("action", "")))
			"examine":
				res["examined"] = SurvivalLearning.examine(core, str(params.get("item", "")))
			"haggle_step", "patience":
				if str(key) == "haggle_step" or not o.has("haggle_step"):
					res["haggle"] = SurvivalTrade.haggle(core, str(params.get("tr", "")), outcome)
			_:
				if not handled.has(str(key)):
					res.unhandled.append(str(key))
	# Actions whose effect is the verb itself.
	match id:
		"eat":
			var er := SurvivalFood.eat(core, str(rs.get("item", params.get("item", ""))))
			res["eat"] = er
			res["ok"] = bool(er.get("ok", false))
		"butcher.field_dress":
			_dress(core, outcome, o, ym, rs, res)
	if SurvivalUtil.dict(a.get("requires")).has("forage_table"):
		_forage(core, ym, rs, res)


## The product's quality for the chosen standard: a partial above plain drops one standard.
static func _standard_quality(core: SurvivalCore, params: Dictionary, outcome: String) -> float:
	var stds := SurvivalUtil.dict(core.data.section("recipes", "rules").get("standards"))
	var order := ["plain", "good", "fine", "masterwork"]
	var i := maxi(0, order.find(str(params.get("standard", "plain"))))
	if outcome == "partial":
		i = maxi(0, i - 1)
	return SurvivalUtil.num(SurvivalUtil.dict(stds.get(order[i])).get("quality"), 1.0)


static func _gained(res: Dictionary, item: String, q: float) -> void:
	var g: Dictionary = res.gained
	g[item] = SurvivalUtil.num(g.get(item), 0.0) + q


static func _mark_node(core: SurvivalCore, params: Dictionary) -> void:
	var inst := str(params.get("node_id", core.state.context.get("node_id", "")))
	if inst != "":
		core.state.nodes_used[inst] = core.state.minutes


## What "tinder" from deadwood turns out to be: bark, punk, fungus or grass (grass not under deep snow).
static func _gather_tinder(core: SurvivalCore) -> String:
	var w := {}
	for k in GATHER_TINDER_WEIGHTS.keys():
		if core.data.item(k).is_empty():
			continue
		if k == "item.tinder.grass" and SurvivalWeather.snow_depth_cm(core) >= GRASS_BURIED_SNOW_CM:
			continue
		w[k] = GATHER_TINDER_WEIGHTS[k]
	return SurvivalUtil.weighted_pick(core.rng, w)


static func _need_effect(core: SurvivalCore, v: Dictionary) -> void:
	var n := core.state.needs
	for k in v.keys():
		var amt := SurvivalUtil.num(v[k], 0.0)
		match str(k):
			"need.rest":
				n["fatigue"] = clampf(SurvivalUtil.num(n.get("fatigue"), 0.0) + amt, 0.0, 100.0)
			"need.warmth":
				n["warmth"] = clampf(SurvivalUtil.num(n.get("warmth"), 100.0) + amt, 0.0, 100.0)
			"need.food":
				n["stomach"] = maxf(0.0, SurvivalUtil.num(n.get("stomach"), 0.0) + amt)
			"need.thirst":
				n["hydration"] = clampf(SurvivalUtil.num(n.get("hydration"), 100.0) + amt, 0.0, 100.0)


static func _spawn(core: SurvivalCore, a: Dictionary, o: Dictionary, v, params: Dictionary, rs: Dictionary, res: Dictionary) -> void:
	var loc := str(core.state.context.get("location", ""))
	var sp := SurvivalUtil.dict(v)
	if sp.has("world.campfire"):
		var fs := str(sp["world.campfire"])
		var fuel := SurvivalCamp.fuel_min_of(core, "item.fuel.kindling") if str(rs.get("consumed_item.fuel.kindling", "")) != "" else 0.0
		var f := SurvivalCamp.fire_at(core, loc)
		if not f.is_empty() and str(f.state) != "lit":
			f["fuel_min"] = SurvivalUtil.num(f.get("fuel_min"), 0.0) + fuel
			f["coal_only"] = fs == "smouldering"
			f["ember_min"] = SurvivalCamp.STRIKE_COAL_MIN if fs == "smouldering" else 0.0
			f["created"] = core.state.minutes
			SurvivalCamp.set_fire_state(core, str(f.id), fs)
			res["fire_id"] = str(f.id)
		else:
			res["fire_id"] = SurvivalCamp.create_fire(core, loc, fs, fuel)
		core.state.stats["fires_lit" if fs == "lit" else "coals_struck"] = int(SurvivalUtil.num(core.state.stats.get("fires_lit" if fs == "lit" else "coals_struck"), 0.0)) + 1
	if sp.has("world.shelter"):
		var q := SurvivalUtil.num(o.get("shelter_quality"), 1.0)
		var sh := SurvivalCamp.shelter_at(core, loc)
		if not sh.is_empty():
			sh["quality"] = maxf(SurvivalUtil.num(sh.get("quality"), 0.0), q)
			res["shelter_id"] = str(sh.id)
		else:
			res["shelter_id"] = SurvivalCamp.create_shelter(core, loc, str(sp["world.shelter"]), q)
		_mark_node(core, params)
	if sp.has("world.cache_pit"):
		res["cache_id"] = SurvivalCamp.create_cache(core, loc, str(sp["world.cache_pit"]), str(o.get("cache_quality", "good")))
	if sp.has("world.trap"):
		var ttype := str(sp["world.trap"])
		var cell := int(params.get("cell", core.state.context.get("cell", 0)))
		var site := str(params.get("site", core.state.context.get("site", "")))
		if site == "" or not SurvivalTrapLine.site_free(core, cell, site):
			site = SurvivalTrapLine.best_free_site(core, cell)
		var sq := SurvivalUtil.num(o.get("set_quality"), SurvivalUtil.num(SurvivalUtil.dict(core.data.trap_model().get("set_quality_by_outcome")).get("success"), 1.0))
		if str(rs.get("stake_quality", "")) == "usable":
			sq *= USABLE_STAKES_SET_MULT
		var opts := {"bait": str(params.get("bait", "none")), "sign_near": bool(params.get("sign_near", core.state.context.get("sign_near", false))),
				"camp_distance_m": SurvivalUtil.num(params.get("camp_distance_m", core.state.context.get("camp_distance_m")), 9999.0),
				"location": loc}
		var tid := SurvivalTrapLine.add_trap(core, ttype, cell, site, sq, opts)
		if o.has("placement"):
			SurvivalTrapLine.trap(core, tid)["placement"] = SurvivalUtil.num(o.placement, 2.0)
		res["trap_id"] = tid
		res["site"] = site
		core.state.flags["last_trap_work_min"] = core.state.minutes


static func _cook(core: SurvivalCore, id: String, cook_state: String, params: Dictionary, rs: Dictionary, res: Dictionary) -> void:
	var item := str(rs.get("item", ""))
	if item == "":
		return
	var per := maxf(1.0, SurvivalUtil.num(core.data.item(item).get("kcal"), 1.0))
	var qty := SurvivalUtil.num(params.get("qty"), COOK_MAX_GAME_KCAL / per)
	qty = minf(qty, SurvivalInventory.count(core, item))
	if qty <= 0.0:
		return
	var cr := SurvivalFood.cook(core, item, qty, cook_state)
	res["cooked"] = cr
	if bool(cr.get("ok", false)):
		_gained(res, str(cr.item), float(cr.qty_out))


## hunt.track: sign of what uses this cell (a fresh sign marker helps a trap set there within 2 game days), and whether a
## deer trail is there to follow (by the region's deer stock). The stalk and the shot are the player's.
static func _reveal(core: SurvivalCore, what: String, o: Dictionary, params: Dictionary, res: Dictionary) -> void:
	var cell := int(params.get("cell", core.state.context.get("cell", 0)))
	var target := str(params.get("species", ""))
	if bool(o.get("sign_marker", false)):
		res["sign"] = SurvivalTrapLine.record_sign(core, cell, target)
	else:
		res["sign_area"] = true
	var deer := SurvivalUtil.dict(core.data.section("map_regions", "fauna").get("deer"))
	var frac := SurvivalTrapLine.deer_stock(core) / maxf(1.0, SurvivalUtil.num(deer.get("stock"), 24.0))
	res["deer_trail"] = what == "animal" and core.rng.randf() < clampf(frac, 0.0, 1.0)
	res["track_age"] = bool(o.get("track_age", false)) or bool(SurvivalSkills.flag(core, "hunting", "track_age", false))


static func _skin(core: SurvivalCore, grade: String, rs: Dictionary, res: Dictionary) -> void:
	var cid := str(rs.get("carcass_id", ""))
	var rec := SurvivalCamp.carcass(core, cid)
	if rec.is_empty():
		return
	var pelt := SurvivalCamp.pelt_item_for(core, str(rec.species))
	if pelt == "":
		return
	var cond := SurvivalUtil.num(rec.get("condition_mult"), 1.0) * SurvivalUtil.num(rec.get("weapon_fit"), 1.0) * SurvivalUtil.num(rec.get("shot_quality"), 1.0)
	var meta := {"grade": grade, "prime": SurvivalUtil.num(rec.get("prime"), 1.0), "condition": snappedf(cond, 0.01), "green": true,
			"species": str(rec.species)}
	if bool(rec.get("tainted", false)) or SurvivalUtil.num(rec.get("spoil"), 0.0) >= 1.0:
		meta["slipped"] = true
		meta["grade"] = "poor"
	SurvivalInventory.add(core, pelt, 1.0, meta)
	_gained(res, pelt, 1.0)
	rec["skinned"] = true
	res["carcass_id"] = cid
	res["pelt"] = pelt
	SurvivalCamp.finish_carcass_if_done(core, cid)


static func _stretch(core: SurvivalCore, shift: int, rs: Dictionary, res: Dictionary) -> void:
	var st: Dictionary = SurvivalUtil.dict(rs.get("stack"))
	if st.is_empty() or float(st.get("qty", 0.0)) <= 0.0:
		return
	var part := SurvivalInventory.remove_stack_qty(core, st, 1.0)
	var meta: Dictionary = SurvivalUtil.dict(part.get("meta")).duplicate(true)
	meta["grade"] = SurvivalInventory.shift_grade(str(meta.get("grade", "good")), shift)
	meta["stretched"] = true
	meta["dry_h"] = 0.0
	var pas := SurvivalUtil.dict(core.data.action("fur.dry").get("passive"))
	meta["dry_need_h"] = snappedf(SurvivalUtil.rand_in(core.rng, pas.get("game_days"), 2.5) * 24.0, 0.1)
	SurvivalInventory.add(core, str(part.id), 1.0, meta)
	res["stretched"] = str(part.id)
	res["grade"] = str(meta.grade)


## Field dressing: the species' carcass yields (actions.json carcass_yields) times the outcome's yield; a deer's hide
## comes off green and dries as a fall skin (0.8 of its value outside October-January).
static func _dress(core: SurvivalCore, outcome: String, o: Dictionary, ym: float, rs: Dictionary, res: Dictionary) -> void:
	var cid := str(rs.get("carcass_id", ""))
	var rec := SurvivalCamp.carcass(core, cid)
	if rec.is_empty():
		return
	var kind := str(rec.get("kind", "small"))
	var cy := SurvivalUtil.dict(core.data.section("actions", "carcass_yields").get(kind))
	var mult := ym * SurvivalUtil.num(SurvivalSkills.flag(core, "hunting", "field_dress_yield_mult", 1.0), 1.0)
	var taint := bool(o.get("taint", false)) or core.rng.randf() < SurvivalUtil.num(o.get("taint_chance"), 0.0)
	var spoil := SurvivalUtil.num(rec.get("spoil"), 0.0)
	for it in SurvivalUtil.dict(cy.get("items")).keys():
		var item := str(it)
		if item == "pelt_of_species" or core.data.item_cat(item) == "pelt":
			continue
		var q := SurvivalUtil.num(cy.items[it], 0.0)
		var meta := {}
		if item == "item.material.green_hide":
			var sk := SurvivalUtil.dict(cy.get("skin_item_by_season"))
			var gmap := SurvivalUtil.dict(core.data.section("items", "pelt_rules").get("skin_outcome_to_grade"))
			var cond := SurvivalUtil.num(rec.get("condition_mult"), 1.0) * SurvivalUtil.num(rec.get("weapon_fit"), 1.0) * SurvivalUtil.num(rec.get("shot_quality"), 1.0)
			meta = {"grade": str(gmap.get(outcome if outcome != "mishap" else "failure", "good")), "green": true, "species": str(rec.species),
					"condition": snappedf(cond, 0.01)}
			if not SurvivalUtil.arr(sk.get("fall_skin_months")).has(str(rec.get("month", ""))):
				meta["value_mult"] = 0.8
		else:
			q *= mult
			# Parts counted whole (brains, sinew bundles) are taken or not: a partial dressing still keeps the brains.
			if SurvivalCrafting._discrete(core, item):
				q = roundf(q)
			if core.data.item_cat(item).begins_with("meat") or item == "item.bait.offal":
				if taint:
					meta["tainted"] = true
				if spoil > 0.0:
					meta["spoil"] = minf(0.99, spoil)
		if q > 0.0:
			SurvivalInventory.add(core, item, q, meta)
			_gained(res, item, q)
	rec["dressed"] = true
	res["carcass_id"] = cid
	SurvivalCamp.finish_carcass_if_done(core, cid)
	if SurvivalInventory.load_stage(core) == "overloaded":
		res.notes.append("overloaded: carry it home slowly or leave some")


static func _forage(core: SurvivalCore, ym: float, rs: Dictionary, res: Dictionary) -> void:
	var row := SurvivalUtil.dict(rs.get("forage"))
	if row.is_empty() or ym <= 0.0:
		return
	var q := SurvivalUtil.num(row.get("yield"), 1.0) * ym
	var inst := str(core.state.context.get("node_id", ""))
	q = SurvivalNodes.take(core, str(row.get("node", "")), str(row.item), q, inst)
	if q <= 0.0:
		return
	SurvivalInventory.add(core, str(row.item), q)
	_gained(res, str(row.item), q)


## Merry company at the sutler's or the trader's settlement: +1 standing a visit, at most 3 a game month.
static func _merry_company(core: SurvivalCore) -> void:
	if SurvivalConditions.stage_of(core, "cond.drunk") != "merry":
		return
	var loc := str(core.state.context.get("location", ""))
	for m in core.data.markets.values():
		if str(m.get("poi", "")) == loc and SurvivalEconomy.is_open(core, str(m.id)):
			var src := SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("npcs", "standing").get("sources")).get("merry_company"))
			SurvivalEconomy.add_standing(core, str(m.get("faction", "")), SurvivalUtil.num(src.get("value"), 1.0), "merry_company")
			return


# ---------------------------------------------------------------- menus
## Actions whose requirements are met here and now, with their chance: [{id, name, pct, time_min, has_check, resumes}].
## It checks every action row (about 2 ms with the slice's data): call it when a menu opens, not every frame.
static func available(core: SurvivalCore) -> Array:
	var out := []
	for id in core.data.actions.keys():
		var rq := requirements(core, str(id))
		if not bool(rq.ok):
			continue
		var pv := _preview(core, str(id), {}, rq)
		out.append({"id": str(id), "name": str(pv.get("name", id)), "pct": int(pv.get("pct", 100)),
				"time_min": float(pv.get("time_min", 0.0)), "has_check": bool(pv.get("has_check", false)),
				"resumes": bool(pv.get("resumes", false))})
	return out


## The actions behind a player-facing verb (actions.json verbs), with what stops each one: [{id, ok, reasons}].
static func verb_actions(core: SurvivalCore, verb: String) -> Array:
	var out := []
	var verbs := core.data.section("actions", "verbs")
	for ms in verbs.keys():
		if typeof(verbs[ms]) != TYPE_ARRAY:
			continue
		for v in verbs[ms]:
			if str(SurvivalUtil.dict(v).get("verb", "")).to_lower() != verb.to_lower():
				continue
			for aid in SurvivalUtil.arr(v.get("actions")):
				if core.data.actions.has(str(aid)):
					var rq := requirements(core, str(aid))
					out.append({"id": str(aid), "ok": bool(rq.ok), "reasons": rq.reasons})
	return out
