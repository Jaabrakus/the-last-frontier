class_name SurvivalCrafting
extends RefCounted
## Recipes (recipes.json): inputs (and inputs_any: any one of a list), outputs, tools, a station and extra near tags,
## run by the recipe's action through the job runner (craft.cordage -> rcp.cordage_hemp). A recipe may override its
## action's difficulty, time and base experience, be one stage of a longer make (snowshoes: splints, then lacing), and
## leave its product to cure (buckskin a game day; jerky 1-2 game days on the drying rack). Outputs are the success
## amounts scaled by the outcome's yield (the action's outcome row, else recipes.json rules: excellent 1.25, success
## 1.0, partial 0.6, failure 0). A failed craft keeps about half its inputs; a failure that still yields a product
## (under-dried jerky) uses all of them; a mishap loses everything. Knowledge gates recipes in SurvivalJobs
## (SurvivalLearning states), never here.

const DEFAULT_YIELD := {"excellent": 1.25, "success": 1.0, "partial": 0.6, "failure": 0.0, "mishap": 0.0}


static func recipe(core: SurvivalCore, id: String) -> Dictionary:
	return core.data.recipes.get(id, {})


static func for_action(core: SurvivalCore, action_id: String) -> Array:
	return SurvivalUtil.arr(core.data.recipes_by_action.get(action_id, []))


static func _excluded(r: Dictionary, st: Dictionary) -> bool:
	var ex := SurvivalUtil.dict(r.get("input_meta_exclude"))
	var m := SurvivalUtil.dict(st.get("meta"))
	for k in ex.keys():
		if m.get(k) == ex[k]:
			return true
	return not SurvivalInventory.usable(st)


## Units of an item a recipe may use (its meta exclusions and curing stacks left out).
static func count_for(core: SurvivalCore, r: Dictionary, item: String) -> float:
	var n := 0.0
	for st in SurvivalInventory.stacks_of(core, item):
		if not _excluded(r, st):
			n += float(st.qty)
	return n


## The item an inputs_any group will use (the first carried in the group's order), or "".
static func pick_any(core: SurvivalCore, r: Dictionary, group: Array, qty: float = 1.0) -> String:
	for it in group:
		if count_for(core, r, str(it)) >= qty - 0.0001:
			return str(it)
	return ""


## What stops a recipe right now: {inputs: {item: short_by}, any: [groups], tools: [any-of lists], station, near};
## empty = ready.
static func missing(core: SurvivalCore, recipe_id: String) -> Dictionary:
	var r := recipe(core, recipe_id)
	var out := {}
	if r.is_empty():
		return {"recipe": "unknown recipe"}
	var inputs := {}
	for k in SurvivalUtil.dict(r.get("inputs")).keys():
		var need := SurvivalUtil.num(r.inputs[k], 0.0)
		var have := count_for(core, r, str(k))
		if have < need - 0.0001:
			inputs[k] = need - have
	if not inputs.is_empty():
		out["inputs"] = inputs
	var any_miss := []
	for g in SurvivalUtil.arr(r.get("inputs_any")):
		if pick_any(core, r, g, SurvivalUtil.num(r.get("inputs_any_qty"), 1.0)) == "":
			any_miss.append(g)
	if not any_miss.is_empty():
		out["any"] = any_miss
	var tools := SurvivalInventory.missing_tools(core, r.get("tools"))
	if not tools.is_empty():
		out["tools"] = tools
	var station = r.get("station")
	if station != null and not station_ok(core, str(station)):
		out["station"] = str(station)
	var near_miss := []
	for tag in SurvivalUtil.arr(r.get("near")):
		if not SurvivalJobs._near_ok(core, str(tag), {}):
			near_miss.append(str(tag))
	if not near_miss.is_empty():
		out["near"] = near_miss
	return out


static func can_craft(core: SurvivalCore, recipe_id: String) -> bool:
	return missing(core, recipe_id).is_empty()


## A station "world.campfire:lit" needs the fire here lit; any other world object must be listed in context.near.
static func station_ok(core: SurvivalCore, station: String) -> bool:
	if station.begins_with("world.campfire"):
		var f := SurvivalCamp.current_fire(core)
		if f.is_empty():
			return false
		var parts := station.split(":")
		return parts.size() < 2 or str(f.state) == parts[1]
	return SurvivalUtil.arr(core.state.context.get("near")).has(station)


## Recipes whose inputs, tools, station and near tags are all at hand (knowledge aside).
static func available(core: SurvivalCore) -> Array:
	var out := []
	for id in core.data.recipes.keys():
		if can_craft(core, str(id)):
			out.append(str(id))
	return out


static func _discrete(core: SurvivalCore, item: String) -> bool:
	var units := SurvivalUtil.arr(SurvivalUtil.dict(core.data.section("recipes", "rules")).get("discrete_units"))
	if units.is_empty():
		return true
	return units.has(str(core.data.item(item).get("unit", "each")))


## Remove qty of a recipe input, skipping excluded stacks (spoiled meat, green pelts, curing buckskin).
static func _use(core: SurvivalCore, r: Dictionary, item: String, qty: float) -> float:
	var left := qty
	var sts := []
	for st in SurvivalInventory.stacks_of(core, item):
		if not _excluded(r, st):
			sts.append(st)
	sts.sort_custom(func(a, b): return SurvivalUtil.num(a.meta.get("spoil"), 0.0) > SurvivalUtil.num(b.meta.get("spoil"), 0.0))
	for st in sts:
		if left <= 0.0001:
			break
		var t := minf(left, float(st.qty))
		SurvivalInventory.remove_stack_qty(core, st, t)
		left -= t
	return qty - left


## Apply a recipe for an outcome tier. action_yield: the action outcome's yield_mult, or -1 for the default table.
## out_meta is added to every output stack (a stake set's quality, a standard's quality, value_mult); variant replaces the
## first output item (under-dried jerky). Returns {ok, recipe, consumed, made, cured_on, rack}.
static func apply(core: SurvivalCore, recipe_id: String, outcome: String, action_yield: float = -1.0,
		out_meta: Dictionary = {}, variant: String = "") -> Dictionary:
	var r := recipe(core, recipe_id)
	if r.is_empty():
		return {"ok": false, "reason": "unknown recipe"}
	var ym := action_yield if action_yield >= 0.0 else float(DEFAULT_YIELD.get(outcome, 0.0))
	if outcome == "mishap":
		ym = 0.0
	var consumed := {}
	var needs := SurvivalUtil.dict(r.get("inputs")).duplicate()
	for g in SurvivalUtil.arr(r.get("inputs_any")):
		var pick := pick_any(core, r, g, SurvivalUtil.num(r.get("inputs_any_qty"), 1.0))
		if pick != "":
			needs[pick] = SurvivalUtil.num(needs.get(pick), 0.0) + SurvivalUtil.num(r.get("inputs_any_qty"), 1.0)
	for k in needs.keys():
		var need := SurvivalUtil.num(needs[k], 0.0)
		var use := need
		if outcome == "failure" and ym <= 0.0:
			# About half the inputs are kept (a single input is kept on an even chance).
			use = floorf(need / 2.0) if need >= 2.0 else (need if SurvivalStreams.player(core, "craft").randf() < 0.5 else 0.0)
		consumed[k] = _use(core, r, str(k), use)
	var made := {}
	var res := {"ok": false, "recipe": recipe_id, "consumed": consumed, "made": made}
	if ym > 0.0:
		var first := true
		var cure := SurvivalUtil.pair(r.get("cure_game_days"), 0.0)
		var cure_days := 0.0
		if cure.y > 0.0:
			cure_days = cure.x if is_equal_approx(cure.x, cure.y) else SurvivalStreams.player(core, "craft").randf_range(cure.x, cure.y)
		for k in SurvivalUtil.dict(r.get("outputs")).keys():
			var q := SurvivalUtil.num(r.outputs[k], 0.0) * ym
			var out_id := str(k)
			if first and variant != "" and not core.data.item(variant).is_empty():
				out_id = variant
			if q >= 1.0 and _discrete(core, out_id):
				q = floorf(q + 0.0001)
			var is_product := first
			first = false
			if q <= 0.0:
				continue
			var meta := out_meta.duplicate(true)
			if is_product and cure_days > 0.0:
				if str(r.get("output_to", "")) == "world.drying_rack":
					res["rack"] = SurvivalCamp.rack_hang(core, out_id, q, meta, cure_days)
					res["cured_on"] = core.state.minutes + cure_days * SurvivalClock.MIN_PER_DAY
					made[out_id] = q
					continue
				meta["curing"] = true
				meta["cure_until"] = core.state.minutes + cure_days * SurvivalClock.MIN_PER_DAY
				res["cured_on"] = meta.cure_until
			SurvivalInventory.add(core, out_id, q, meta)
			made[out_id] = q
			# A garment made goes on at once when nothing of its kind is worn (a player puts new mitts on).
			if is_product and not bool(meta.get("curing", false)) and SurvivalInventory.wear_if_slot_empty(core, out_id):
				res["worn"] = out_id
	res.ok = not made.is_empty()
	return res
