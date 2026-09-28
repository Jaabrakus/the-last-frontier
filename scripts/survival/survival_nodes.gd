class_name SurvivalNodes
extends RefCounted
## Resource node stocks (map_regions.json resource_nodes: stock, count_in_region, refill, recover_per_season), world
## state in SurvivalState.world.nodes. A nut grove holds a season's mast: each search takes from it, and a picked-out grove
## is empty until its refill day; fish water recovers part of its deficit each season, like a trapping cell.
##
## Node instances: the world names them (context.node_id or params.node_id, "grove.3"); without one, the core uses the
## region's count_in_region instances of the type in order ("node.nut_grove#1" .. "#5"), so the whole region's stock is
## what a player can take, which is what the sim harness plays against. Every value is deterministic: no draws.
## The M1 nodes (deadwood, tinder, saplings, conifers) have no stock row and stay unlimited (nodes_used regrowth only).


static func _w(core: SurvivalCore) -> Dictionary:
	var w := core.state.world
	if not w.has("nodes"):
		w["nodes"] = {}
	return w.nodes


static func row(core: SurvivalCore, node_type: String) -> Dictionary:
	return SurvivalUtil.dict(core.data.resource_nodes.get(node_type))


## Does this node type keep a season stock?
static func stocked(core: SurvivalCore, node_type: String) -> bool:
	return not SurvivalUtil.dict(row(core, node_type).get("stock")).is_empty()


static func instances(core: SurvivalCore, node_type: String, node_id: String = "") -> Array:
	if node_id != "":
		return [node_id]
	var n := int(SurvivalUtil.num(row(core, node_type).get("count_in_region"), 1.0))
	var out := []
	for k in maxi(1, n):
		out.append("%s#%d" % [node_type, k + 1])
	return out


## The instance record, created on first use with the stock its latest refill left it (never touched before).
static func _rec(core: SurvivalCore, inst: String, node_type: String) -> Dictionary:
	var nodes := _w(core)
	if nodes.has(inst):
		return nodes[inst]
	var r := row(core, node_type)
	var full := SurvivalUtil.dict(r.get("stock"))
	var stock := {}
	var refills := SurvivalUtil.arr(r.get("refill"))
	if refills.is_empty():
		stock = full.duplicate()
	else:
		for it in full.keys():
			stock[it] = _latest_refill(core, refills, str(it), SurvivalUtil.num(full[it], 0.0))
	var rec := {"type": node_type, "stock": stock}
	nodes[inst] = rec
	return rec


## What the most recent refill of an item (on or before today, going back through the year) set it to.
static func _latest_refill(core: SurvivalCore, refills: Array, item: String, full: float) -> float:
	var today := SurvivalClock.day_of_year(core)
	var days := SurvivalClock.days_per_year(core)
	var best_back := 9999
	var val := full
	var any := false
	for rf in refills:
		var to := SurvivalUtil.dict(rf.get("to"))
		if not to.has(item):
			continue
		any = true
		var d := SurvivalClock.day_index_of(core, str(rf.get("day", "")))
		if d < 0:
			continue
		var back := posmod(today - d, days)
		if back < best_back:
			best_back = back
			val = SurvivalUtil.num(to[item], full)
	return val if any else full


## Stock of an item left across the instances in reach.
static func available(core: SurvivalCore, node_type: String, item: String, node_id: String = "") -> float:
	if not stocked(core, node_type):
		return 1.0e9
	var n := 0.0
	for inst in instances(core, node_type, node_id):
		n += SurvivalUtil.num(SurvivalUtil.dict(_rec(core, str(inst), node_type).get("stock")).get(item), 0.0)
	return n


## Take up to qty of an item from the instances in order. Returns what was taken (all of qty from an unstocked node).
static func take(core: SurvivalCore, node_type: String, item: String, qty: float, node_id: String = "") -> float:
	if qty <= 0.0:
		return 0.0
	if not stocked(core, node_type):
		return qty
	var left := qty
	for inst in instances(core, node_type, node_id):
		if left <= 0.0001:
			break
		var st: Dictionary = _rec(core, str(inst), node_type).stock
		var have := SurvivalUtil.num(st.get(item), 0.0)
		var got := minf(have, left)
		if got > 0.0:
			st[item] = have - got
			left -= got
	return qty - left


## A new game day: refills on their day, and the slow recovery of fish water (recover_per_season of the deficit a season).
static func on_day_started(core: SurvivalCore) -> void:
	var day_id := SurvivalClock.day_id(core)
	var season_len := float(SurvivalClock.days_per_year(core)) / 4.0
	for inst in SurvivalUtil.sorted_ids(_w(core)):
		var rec: Dictionary = _w(core)[inst]
		var r := row(core, str(rec.get("type", "")))
		var st: Dictionary = rec.stock
		for rf in SurvivalUtil.arr(r.get("refill")):
			if str(rf.get("day", "")) != day_id:
				continue
			var to := SurvivalUtil.dict(rf.get("to"))
			for it in to.keys():
				st[it] = maxf(SurvivalUtil.num(st.get(it), 0.0), SurvivalUtil.num(to[it], 0.0))
		var rec_frac := SurvivalUtil.num(r.get("recover_per_season"), 0.0)
		if rec_frac > 0.0:
			var daily := 1.0 - pow(1.0 - rec_frac, 1.0 / season_len)
			var full := SurvivalUtil.dict(r.get("stock"))
			for it in full.keys():
				var cur := SurvivalUtil.num(st.get(it), 0.0)
				st[it] = cur + daily * (SurvivalUtil.num(full[it], 0.0) - cur)


## A readable view for the almanac, UI and tests: [{instance, type, stock}].
static func listing(core: SurvivalCore) -> Array:
	var out := []
	for inst in SurvivalUtil.sorted_ids(_w(core)):
		out.append({"instance": inst, "type": str(_w(core)[inst].get("type", "")), "stock": SurvivalUtil.dict(_w(core)[inst].get("stock")).duplicate()})
	return out
