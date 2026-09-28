class_name SurvivalFood
extends RefCounted
## Eating, drinking and cooking (needs.json food, items.json food rows, conditions.json cond.queasy and cond.drunk).
##
## A meal is up to 800 game kcal from one food. Energy is the item's game kcal (historical kcal / flow factor 5) per
## unit, halved when burnt and x0.7 when spoiled. Plain fare: when one food group (grain, meat, fish, plant; needs.json
## food.groups) gives more than 70% of the energy eaten over the last three game days, meals give 85% of their energy
## (and sleep is a little worse, see SurvivalNeeds). Nuts and groundnuts break a diet of venison alone.
## Risks come from the data: raw_risk on raw or undercooked meat, spoiled food, a rich meal after starving, and the
## queasy stage's vomit chance.


static func food_cfg(core: SurvivalCore) -> Dictionary:
	return core.data.section("needs", "food")


static func meal_kcal(core: SurvivalCore) -> float:
	return SurvivalUtil.num(food_cfg(core).get("meal_game_kcal"), 800.0)


static func group_of(core: SurvivalCore, item_id: String) -> String:
	var g = core.data.item(item_id).get("food_group", null)
	return "other" if g == null else str(g)


static func _today(core: SurvivalCore) -> int:
	return SurvivalClock.abs_day(core)


## The food groups the plain-fare rule compares (needs.json food.groups), plus "other" for anything ungrouped.
static func groups(core: SurvivalCore) -> Array:
	var out := []
	for g in SurvivalUtil.dict(food_cfg(core).get("groups")).keys():
		out.append(str(g))
	if not out.has("other"):
		out.append("other")
	return out


static func _log_kcal(core: SurvivalCore, group: String, kcal: float) -> void:
	var d := _today(core)
	var dl := core.state.diet_log
	if dl.is_empty() or int(SurvivalUtil.num(dl[dl.size() - 1].get("day"), -1.0)) != d:
		var e0 := {"day": d}
		for g in groups(core):
			e0[g] = 0.0
		dl.append(e0)
	var e: Dictionary = dl[dl.size() - 1]
	e[group] = SurvivalUtil.num(e.get(group), 0.0) + kcal
	var window := int(SurvivalUtil.num(SurvivalUtil.dict(food_cfg(core).get("plain_fare")).get("window_game_days"), 3.0))
	while dl.size() > window + 1:
		dl.remove_at(0)


## Group shares of energy eaten over the plain-fare window: {grain, meat, fish, plant, other, total}.
static func diet_shares(core: SurvivalCore) -> Dictionary:
	var pf := SurvivalUtil.dict(food_cfg(core).get("plain_fare"))
	var window := int(SurvivalUtil.num(pf.get("window_game_days"), 3.0))
	var today := _today(core)
	var tot := {}
	for g in groups(core):
		tot[g] = 0.0
	for e in core.state.diet_log:
		if today - int(SurvivalUtil.num(e.get("day"), -99.0)) < window:
			for g in tot.keys():
				tot[g] = float(tot[g]) + SurvivalUtil.num(e.get(g), 0.0)
	var total := 0.0
	for g in tot.keys():
		total += float(tot[g])
	tot["total"] = total
	return tot


static func plain_fare(core: SurvivalCore) -> bool:
	var pf := SurvivalUtil.dict(food_cfg(core).get("plain_fare"))
	var sh := diet_shares(core)
	var total := float(sh.total)
	if total < meal_kcal(core) * 2.0:
		return false
	var lim := SurvivalUtil.num(pf.get("max_share_one_group"), 0.7)
	for g in groups(core):
		if g != "other" and SurvivalUtil.num(sh.get(g), 0.0) / total > lim:
			return true
	return false


## Can this item be eaten as it is? (cornmeal must be cooked first: items.json needs_cooking)
static func edible(core: SurvivalCore, item_id: String) -> bool:
	var it := core.data.item(item_id)
	if SurvivalUtil.num(it.get("kcal"), 0.0) <= 0.0:
		return false
	var cat := str(it.get("cat", ""))
	if cat == "material" or cat == "bait":
		return false
	if it.has("edible") and not bool(it.edible):
		return false
	return not bool(it.get("needs_cooking", false))


## Eat one meal of item_id (or the best meal carried when empty). Returns
## {ok, reason, item, qty, kcal, vomited, queasy, plain_fare}.
static func eat(core: SurvivalCore, item_id: String = "", opts: Dictionary = {}) -> Dictionary:
	if item_id == "":
		item_id = choose_meal(core)
	if item_id == "":
		return {"ok": false, "reason": "no food ready to eat"}
	if not edible(core, item_id):
		return {"ok": false, "reason": "%s must be cooked first" % core.data.item_name(item_id), "item": item_id}
	var food := SurvivalNeeds.need_row(core, "need.food")
	var cap := SurvivalUtil.num(food.get("stomach_capacity_kcal"), 3000.0)
	var stomach := SurvivalUtil.num(core.state.needs.get("stomach"), 0.0)
	var room := cap - stomach
	if room < 50.0 and not bool(opts.get("force", false)):
		return {"ok": false, "reason": "too full to eat", "item": item_id}
	var stacks := []
	for st0 in SurvivalInventory.stacks_of(core, item_id):
		if SurvivalInventory.usable(st0):
			stacks.append(st0)
	if stacks.is_empty():
		return {"ok": false, "reason": "none carried", "item": item_id}
	stacks.sort_custom(func(a, b): return SurvivalUtil.num(a.meta.get("spoil"), 0.0) > SurvivalUtil.num(b.meta.get("spoil"), 0.0))
	var st: Dictionary = stacks[0]
	var per_unit := SurvivalInventory.stack_kcal(core, {"id": item_id, "qty": 1.0, "meta": st.meta})
	if per_unit <= 0.0:
		return {"ok": false, "reason": "no nourishment in it", "item": item_id}
	var want := minf(meal_kcal(core), maxf(room, 50.0) if not bool(opts.get("force", false)) else meal_kcal(core))
	var qty := minf(float(st.qty), want / per_unit)
	var meta: Dictionary = SurvivalUtil.dict(st.meta).duplicate(true)
	var hunger_stage := SurvivalNeeds.food_stage(core)
	SurvivalInventory.remove_stack_qty(core, st, qty)
	var kcal := per_unit * qty
	var was_plain := plain_fare(core)
	var pf := SurvivalUtil.dict(food_cfg(core).get("plain_fare"))
	if was_plain:
		kcal *= SurvivalUtil.num(SurvivalUtil.dict(pf.get("effect")).get("meal_energy_mult"), 0.85)
	var group := group_of(core, item_id)
	_log_kcal(core, group, per_unit * qty)
	var res := {"ok": true, "item": item_id, "qty": qty, "kcal": kcal, "vomited": false, "queasy": false, "plain_fare": was_plain}
	# Risks.
	var it := core.data.item(item_id)
	var q_chance := 0.0
	var cook_state := str(meta.get("cook", "raw" if str(it.get("cat", "")) == "meat_raw" else ""))
	if (cook_state == "raw" or cook_state == "undercooked") and it.has("raw_risk"):
		q_chance = maxf(q_chance, SurvivalUtil.num(SurvivalUtil.dict(it.raw_risk).get("cond.queasy"), 0.0))
	if bool(meta.get("spoiled", false)) or bool(meta.get("tainted", false)):
		q_chance = maxf(q_chance, SurvivalUtil.num(SurvivalUtil.dict(core.data.section("items", "spoiled_food")).get("cond.queasy"), 0.6))
	var refeed := SurvivalUtil.dict(food.get("refeeding"))
	if SurvivalUtil.arr(refeed.get("when_stage_in")).has(hunger_stage) and not SurvivalUtil.arr(refeed.get("exempt_groups")).has(group):
		var recent := _recent_kcal(core, kcal)
		if recent > SurvivalUtil.num(refeed.get("kcal_within_game_h"), 1200.0):
			q_chance = maxf(q_chance, SurvivalUtil.num(refeed.get("chance"), 0.6))
	else:
		_recent_kcal(core, kcal)
	_maybe_worms(core, it, cook_state)
	var mods := core.get_modifiers()
	var vomit := SurvivalUtil.num(mods.get("vomit_on_eat_chance"), 0.0)
	if vomit > 0.0 and core.rng.randf() < vomit:
		res["vomited"] = true
		core.state.stats["vomits"] = int(SurvivalUtil.num(core.state.stats.get("vomits"), 0.0)) + 1
		core.log_line("the food came back up", "cond")
	else:
		core.state.needs["stomach"] = minf(cap, stomach + kcal)
	if q_chance > 0.0 and core.rng.randf() < q_chance:
		res["queasy"] = true
		SurvivalConditions.add(core, "cond.queasy", {"cause": "food"})
	core.state.stats["meals_eaten"] = SurvivalUtil.num(core.state.stats.get("meals_eaten"), 0.0) + kcal / meal_kcal(core)
	core.state.stats["eaten_" + group] = SurvivalUtil.num(core.state.stats.get("eaten_" + group), 0.0) + kcal
	if item_id == "item.food.acorn_meal":
		core.state.stats["eaten_acorn_meal"] = SurvivalUtil.num(core.state.stats.get("eaten_acorn_meal"), 0.0) + kcal
	if was_plain:
		core.state.stats["plain_meals"] = int(SurvivalUtil.num(core.state.stats.get("plain_meals"), 0.0)) + 1
	return res


static func _recent_kcal(core: SurvivalCore, add_kcal: float) -> float:
	var f := core.state.flags
	var t := SurvivalUtil.num(f.get("refeed_t"), -9999.0)
	var k := SurvivalUtil.num(f.get("refeed_kcal"), 0.0)
	if core.state.minutes - t > 60.0:
		k = 0.0
		f["refeed_t"] = core.state.minutes
	k += add_kcal
	f["refeed_kcal"] = k
	return k


## Worms from raw fish or undercooked game when the (backlog M3) condition is loaded (cond.worms acquire).
static func _maybe_worms(core: SurvivalCore, it: Dictionary, cook_state: String) -> void:
	var w := core.data.condition("cond.worms")
	if w.is_empty() or core.state.conditions.has("cond.worms"):
		return
	var acq := SurvivalUtil.dict(w.get("acquire"))
	var ch := 0.0
	if cook_state == "raw" or cook_state == "undercooked":
		if str(it.get("spoil", "")) == "fresh_fish":
			ch = SurvivalUtil.num(acq.get("raw_or_undercooked_fish"), 0.0)
		elif str(it.get("cat", "")).begins_with("meat"):
			ch = SurvivalUtil.num(acq.get("undercooked_game"), 0.0)
	if ch > 0.0 and core.rng.randf() < ch:
		SurvivalConditions.add(core, "cond.worms", {"cause": "food", "incubating": true})


## The best meal carried: cooked and ready food first, the least plain group, the most spoiled of a kind first.
static func choose_meal(core: SurvivalCore) -> String:
	var sh := diet_shares(core)
	var total := maxf(1.0, float(sh.total))
	var queasy := core.state.conditions.has("cond.queasy")
	var best := ""
	var best_score := -1e9
	for st in core.state.inventory:
		var id := str(st.id)
		if not edible(core, id) or float(st.qty) <= 0.0 or not SurvivalInventory.usable(st):
			continue
		var it := core.data.item(id)
		var cat := str(it.get("cat", ""))
		var score := 0.0
		if cat == "meat_raw":
			score -= 50.0
		if bool(st.meta.get("spoiled", false)) or bool(st.meta.get("tainted", false)):
			score -= 40.0
		if str(st.meta.get("cook", "")) == "undercooked":
			score -= 20.0
		var g := group_of(core, id)
		score -= 30.0 * SurvivalUtil.num(sh.get(g), 0.0) / total
		if queasy and g != "grain":
			score -= 25.0
		# Eat perishables before preserved food.
		if cat == "meat_cooked" or (cat == "forage" and str(it.get("spoil", "")) != "dry_store"):
			score += 10.0
		score += 5.0 * SurvivalUtil.num(st.meta.get("spoil"), 0.0)
		if score > best_score:
			best_score = score
			best = id
	return best


## Drink one serving (a gill: 1/8 quart of rum) and raise the drink meter (conditions.json cond.drunk meter).
static func drink(core: SurvivalCore, item_id: String = "item.drink.rum") -> Dictionary:
	var it := core.data.item(item_id)
	var servings := SurvivalUtil.num(it.get("servings"), 1.0)
	var per := 1.0 / maxf(1.0, servings)
	if SurvivalInventory.count(core, item_id) < per - 0.0001:
		return {"ok": false, "reason": "nothing to drink"}
	SurvivalInventory.remove(core, item_id, per)
	var dm := SurvivalUtil.dict(core.data.condition("cond.drunk").get("meter"))
	var add := SurvivalUtil.num(SurvivalUtil.dict(dm.get("per_serving")).get(item_id), 0.0)
	var n := core.state.needs
	if add > 0.0:
		n["drunk"] = minf(100.0, SurvivalUtil.num(n.get("drunk"), 0.0) + add)
		n["drunk_peak"] = maxf(SurvivalUtil.num(n.get("drunk_peak"), 0.0), float(n.drunk))
	if SurvivalNeeds.thirst_enabled(core):
		var dr := SurvivalUtil.dict(SurvivalNeeds.need_row(core, "need.thirst").get("drink"))
		var key := "canteen_serving"
		if item_id.contains("broth") or item_id.contains("tea"):
			key = "tea_or_broth"
		if item_id != "item.drink.rum":
			n["hydration"] = minf(100.0, SurvivalUtil.num(n.get("hydration"), 100.0) + SurvivalUtil.num(dr.get(key), 25.0))
	core.state.stats["drams"] = int(SurvivalUtil.num(core.state.stats.get("drams"), 0.0)) + (1 if add > 0.0 else 0)
	SurvivalConditions.update_driven(core)
	return {"ok": true, "item": item_id, "meter": SurvivalUtil.num(n.get("drunk"), 0.0)}


## Drink water from a source (thirst only; the backlog action drink.source is 'post').
static func drink_water(core: SurvivalCore, kind: String = "source_sip") -> void:
	if not SurvivalNeeds.thirst_enabled(core):
		return
	var dr := SurvivalUtil.dict(SurvivalNeeds.need_row(core, "need.thirst").get("drink"))
	core.state.needs["hydration"] = minf(100.0, SurvivalUtil.num(core.state.needs.get("hydration"), 100.0) + SurvivalUtil.num(dr.get(kind), 30.0))


## Cook qty units of a raw food into its cook_to item, conserving energy (1 lb of cornmeal bakes to 1.5 lb of
## johnnycake; 1 lb of raw venison roasts to 0.85 lb). outcome_state: "cooked" | "undercooked" | "burnt".
static func cook(core: SurvivalCore, item_id: String, qty: float, outcome_state: String) -> Dictionary:
	var it := core.data.item(item_id)
	var to := str(it.get("cook_to", ""))
	if to == "" or core.data.item(to).is_empty():
		return {"ok": false, "reason": "%s cannot be cooked" % core.data.item_name(item_id)}
	var parts := SurvivalInventory.remove(core, item_id, qty)
	var got := 0.0
	var k_in := SurvivalUtil.num(it.get("kcal"), 0.0)
	var k_out := maxf(1.0, SurvivalUtil.num(core.data.item(to).get("kcal"), 1.0))
	var out_qty := 0.0
	for p in parts:
		got += float(p.qty)
		var meta := {}
		if outcome_state != "cooked":
			meta["cook"] = outcome_state
		if bool(p.meta.get("spoiled", false)):
			meta["spoiled"] = true
		if bool(p.meta.get("tainted", false)):
			meta["tainted"] = true
		var q := float(p.qty) * k_in / k_out
		out_qty += q
		SurvivalInventory.add(core, to, q, meta)
	return {"ok": got > 0.0, "item": to, "qty_in": got, "qty_out": out_qty, "state": outcome_state}


## A raw food worth cooking: the item carried with the most energy that has a cook_to.
static func choose_to_cook(core: SurvivalCore) -> String:
	var best := ""
	var best_k := 0.0
	for st in core.state.inventory:
		var it := core.data.item(str(st.id))
		if str(it.get("cook_to", "")) == "" or bool(st.meta.get("spoiled", false)):
			continue
		var k := SurvivalUtil.num(it.get("kcal"), 0.0) * float(st.qty)
		if k > best_k:
			best_k = k
			best = str(st.id)
	return best
