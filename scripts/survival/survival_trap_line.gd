class_name SurvivalTrapLine
extends RefCounted
## The trap line (actions.json trap_model, map_regions.json fauna and trapping_cells).
##
## Each game night (rolled at dawn) a set trap holds a catch with probability 1 - e^(-lambda), one catch per trap:
##   lambda = F * sum over species(nightly_rate * fit * activity(month) * cell stock / starting stock
##                                  * placement / 3 * bait * set_quality)
## F is the flow factor (5): a game night on the line stands for five calendar nights. Placement comes from what the
## player reads (the site, fresh sign, a camp or a shot nearby), never from the die; the set check decides build quality.
## Stock is per trapping cell and recovers 30% of its deficit a season. Unvisited traps lose held catches to scavengers
## (35% a night) and are sprung empty (20% a night); a night of fresh snow buries a share of the sets.

const SITE_LIMITS := {"good": "good", "fair": "fair"}


static func _tl(core: SurvivalCore) -> Dictionary:
	return core.state.trapline


static func cell_count(core: SurvivalCore) -> int:
	return int(SurvivalUtil.num(core.data.section("map_regions", "trapping_cells").get("count"), 16.0))


static func species_table(core: SurvivalCore) -> Dictionary:
	return SurvivalUtil.dict(core.data.section("map_regions", "fauna").get("trap_species"))


static func init(core: SurvivalCore) -> void:
	var tl := _tl(core)
	tl["traps"] = {}
	tl["next_id"] = 1
	tl["signs"] = {}
	tl["gunfire"] = {}
	var stock := []
	var sp := species_table(core)
	for c in cell_count(core):
		var cell := {}
		for s in sp.keys():
			cell[s] = SurvivalUtil.num(sp[s].get("stock_per_cell"), 0.0)
		stock.append(cell)
	tl["stock"] = stock
	var deer := SurvivalUtil.dict(core.data.section("map_regions", "fauna").get("deer"))
	tl["deer_stock"] = SurvivalUtil.num(deer.get("stock"), 24.0)


static func traps(core: SurvivalCore) -> Dictionary:
	var tl := _tl(core)
	if not tl.has("traps"):
		tl["traps"] = {}
	return tl.traps


static func trap(core: SurvivalCore, id: String) -> Dictionary:
	return traps(core).get(id, {})


## Trap ids in the order they were set ("trap.2" before "trap.10"); walk the line in this order.
static func trap_ids(core: SurvivalCore) -> Array:
	return SurvivalUtil.sorted_ids(traps(core))


## Sites in use in a cell (map_regions.json trapping_cells.sites_per_cell: one good, two fair; poor sites unlimited).
static func sites_used(core: SurvivalCore, cell: int, site: String) -> int:
	var n := 0
	for t in traps(core).values():
		if int(t.cell) == cell and str(t.site) == site:
			n += 1
	return n


static func site_free(core: SurvivalCore, cell: int, site: String) -> bool:
	var spc := SurvivalUtil.dict(core.data.section("map_regions", "trapping_cells").get("sites_per_cell"))
	if not spc.has(site):
		return true
	return sites_used(core, cell, site) < int(SurvivalUtil.num(spc[site], 0.0))


## The best free site in a cell: good, then fair, then poor.
static func best_free_site(core: SurvivalCore, cell: int) -> String:
	for s in ["good", "fair"]:
		if site_free(core, cell, s):
			return s
	return "poor"


## Placement (actions.json trap_model.placement): site quality + 0.5 for fresh sign of a target species within 2 game
## days, minus a camp nearby (-1 within 100 m, -0.5 within 200 m); clamped 0.5..3.5. Gunfire is applied nightly.
static func placement_for(core: SurvivalCore, cell: int, site: String, trap_type: String, opts: Dictionary = {}) -> float:
	var tm := core.data.trap_model()
	var pl := SurvivalUtil.dict(tm.get("placement"))
	var q := SurvivalUtil.num(SurvivalUtil.dict(pl.get("from_site")).get(site), 1.0)
	if has_fresh_sign(core, cell, trap_type) or bool(opts.get("sign_near", false)):
		q += SurvivalUtil.num(pl.get("sign_bonus"), 0.5)
	var camp_m := SurvivalUtil.num(opts.get("camp_distance_m"), 9999.0)
	for pair in SurvivalUtil.arr(pl.get("camp_penalty")):
		if camp_m <= SurvivalUtil.num(pair[0]):
			q += SurvivalUtil.num(pair[1])
			break
	return clampf(q, SurvivalUtil.num(pl.get("min"), 0.5), SurvivalUtil.num(pl.get("max"), 3.5))


static func has_fresh_sign(core: SurvivalCore, cell: int, trap_type: String) -> bool:
	var fit := SurvivalUtil.dict(SurvivalUtil.dict(core.data.trap_model().get("trap_fit")).get(trap_type))
	var win := int(SurvivalUtil.num(SurvivalUtil.dict(core.data.trap_model().get("placement")).get("sign_window_game_days"), 2.0))
	var signs := SurvivalUtil.dict(SurvivalUtil.dict(_tl(core).get("signs")).get(str(cell)))
	var today := SurvivalClock.abs_day(core)
	for s in signs.keys():
		if fit.has(s) and today - int(SurvivalUtil.num(signs[s], -99.0)) <= win:
			return true
	return false


## Fresh sign found by hunt.track: a species present in the cell, weighted by its stock and nightly rate.
static func record_sign(core: SurvivalCore, cell: int, species: String = "") -> String:
	var tl := _tl(core)
	if species == "":
		var w := {}
		var sp := species_table(core)
		var stock: Array = SurvivalUtil.arr(tl.get("stock"))
		if cell >= 0 and cell < stock.size():
			for s in sp.keys():
				if bool(sp[s].get("pelt", false)):
					w[s] = SurvivalUtil.num(stock[cell].get(s), 0.0) * SurvivalUtil.num(sp[s].get("nightly_rate"), 0.0)
		species = SurvivalUtil.weighted_pick(core.rng, w)
	if species == "":
		return ""
	if not tl.has("signs"):
		tl["signs"] = {}
	var key := str(cell)
	if not tl.signs.has(key):
		tl.signs[key] = {}
	tl.signs[key][species] = SurvivalClock.abs_day(core)
	return species


## A shot within 150 m in the last game day takes 0.5 from placement (actions.json trap_model.placement.gunfire_penalty).
static func record_shot(core: SurvivalCore, cell: int) -> void:
	var tl := _tl(core)
	if not tl.has("gunfire"):
		tl["gunfire"] = {}
	tl.gunfire[str(cell)] = core.state.minutes


static func add_trap(core: SurvivalCore, trap_type: String, cell: int, site: String, set_quality: float, opts: Dictionary = {}) -> String:
	var tl := _tl(core)
	var n := int(SurvivalUtil.num(tl.get("next_id"), 1.0))
	tl["next_id"] = n + 1
	var id := "trap.%d" % n
	var today := SurvivalClock.abs_day(core)
	var bait := str(opts.get("bait", "none"))
	if bait == "offal":
		if SurvivalInventory.count(core, "item.bait.offal") >= 1.0:
			SurvivalInventory.remove(core, "item.bait.offal", 1.0)
		else:
			bait = "none"
	traps(core)[id] = {"id": id, "type": trap_type, "cell": cell, "site": site,
			"placement": placement_for(core, cell, site, trap_type, opts), "set_quality": set_quality, "bait": bait,
			"state": "set", "catch": "", "catch_day": -1, "set_day": today, "last_visit_day": today,
			"location": str(opts.get("location", core.state.context.get("location", "")))}
	core._on_trap_changed(id, "set")
	return id


static func remove_trap(core: SurvivalCore, id: String, return_to_inventory: bool = true) -> void:
	var t := trap(core, id)
	if t.is_empty():
		return
	if return_to_inventory and str(t.type) == "steel_land":
		SurvivalInventory.add(core, "item.trap.steel", 1.0)
	traps(core).erase(id)
	core._on_trap_changed(id, "removed")


## lambda and its per-species parts for a trap tonight.
static func lambda_for(core: SurvivalCore, t: Dictionary, month: String) -> Dictionary:
	var tm := core.data.trap_model()
	var F := core.data.flow_factor()
	var fit := SurvivalUtil.dict(SurvivalUtil.dict(tm.get("trap_fit")).get(str(t.type)))
	var sp := species_table(core)
	var stock: Array = SurvivalUtil.arr(_tl(core).get("stock"))
	var cell := int(t.cell)
	var bait := SurvivalUtil.num(SurvivalUtil.dict(tm.get("bait")).get(str(t.get("bait", "none"))), 1.0)
	var pl := SurvivalUtil.num(t.get("placement"), 2.0)
	var gf := SurvivalUtil.dict(SurvivalUtil.dict(tm.get("placement")).get("gunfire_penalty"))
	var shot_t := SurvivalUtil.num(SurvivalUtil.dict(_tl(core).get("gunfire")).get(str(cell)), -1e9)
	if core.state.minutes - shot_t <= SurvivalUtil.num(gf.get("within_game_days"), 1.0) * SurvivalClock.MIN_PER_DAY:
		pl = maxf(SurvivalUtil.num(SurvivalUtil.dict(tm.get("placement")).get("min"), 0.5), pl + SurvivalUtil.num(gf.get("add"), -0.5))
	var parts := {}
	var total := 0.0
	for s in fit.keys():
		if not sp.has(s) or cell < 0 or cell >= stock.size():
			continue
		var row: Dictionary = sp[s]
		var am := SurvivalUtil.dict(row.get("activity"))
		var act := SurvivalUtil.num(am.get(month, am.get("default", 1.0)), 1.0)
		var s0 := maxf(0.0001, SurvivalUtil.num(row.get("stock_per_cell"), 1.0))
		var sv := F * SurvivalUtil.num(row.get("nightly_rate"), 0.0) * SurvivalUtil.num(fit[s], 0.0) * act \
				* maxf(0.0, SurvivalUtil.num(stock[cell].get(s), 0.0)) / s0 * pl / 3.0 * bait * SurvivalUtil.num(t.get("set_quality"), 1.0)
		parts[s] = sv
		total += sv
	return {"total": total, "parts": parts}


## The dawn roll for last night (called by the core as the clock passes 06:00).
static func dawn_roll(core: SurvivalCore) -> void:
	var tm := core.data.trap_model()
	var un := SurvivalUtil.dict(tm.get("unchecked"))
	var snow_cfg := SurvivalUtil.dict(tm.get("snow_reset"))
	var snowed := SurvivalWeather.take_snowed_tonight(core)
	var today := SurvivalClock.abs_day(core)
	var month := SurvivalClock.month_id(core)
	var stock: Array = SurvivalUtil.arr(_tl(core).get("stock"))
	var lost := []
	# Traps in creation order, so the dice fall the same way after a save and load.
	for id in trap_ids(core):
		var t: Dictionary = traps(core)[id]
		match str(t.state):
			"holding":
				if int(t.catch_day) < today and core.rng.randf() < SurvivalUtil.num(un.get("held_catch_loss_per_night"), 0.35):
					t["state"] = "sprung"
					t["catch"] = ""
					core.state.stats["catches_scavenged"] = int(SurvivalUtil.num(core.state.stats.get("catches_scavenged"), 0.0)) + 1
					core._on_trap_changed(id, "sprung")
			"set":
				if int(t.last_visit_day) < today - 1 and core.rng.randf() < SurvivalUtil.num(un.get("empty_sprung_per_night"), 0.2):
					t["state"] = "sprung"
					core._on_trap_changed(id, "sprung")
				else:
					var buried := snowed and core.rng.randf() < SurvivalUtil.num(SurvivalUtil.dict(snow_cfg.get(str(t.type))).get("frac"), 0.5)
					var lam := lambda_for(core, t, month)
					var p := 1.0 - exp(-float(lam.total))
					if buried:
						p *= 0.5
					if float(lam.total) > 0.0 and core.rng.randf() < p:
						var sp := SurvivalUtil.weighted_pick(core.rng, lam.parts)
						if sp != "":
							t["state"] = "holding"
							t["catch"] = sp
							t["catch_day"] = today
							var cell := int(t.cell)
							if cell >= 0 and cell < stock.size():
								stock[cell][sp] = maxf(0.0, SurvivalUtil.num(stock[cell].get(sp), 0.0) - 1.0)
							core.state.stats["catches"] = int(SurvivalUtil.num(core.state.stats.get("catches"), 0.0)) + 1
							core._on_trap_caught(id, sp)
					if buried and str(t.state) == "set":
						t["state"] = "buried"
						core._on_trap_changed(id, "buried")
		if str(t.type) == "steel_land" and core.rng.randf() < SurvivalUtil.num(tm.get("steel_trap_loss_per_game_day"), 0.004):
			lost.append(id)
	for id in lost:
		traps(core).erase(id)
		core.state.stats["steel_traps_lost"] = int(SurvivalUtil.num(core.state.stats.get("steel_traps_lost"), 0.0)) + 1
		core.log_line("a steel trap is gone from the line (stolen or dragged off)", "loss")
		core._on_trap_changed(str(id), "lost")


## Stock recovers 30% of its deficit a season (9 game days), a little every day. Deer drift in from the manor lands.
static func daily_recovery(core: SurvivalCore) -> void:
	var sp := species_table(core)
	var season_len := SurvivalClock.days_per_year(core) / 4.0
	var stock: Array = SurvivalUtil.arr(_tl(core).get("stock"))
	for c in stock:
		for s in sp.keys():
			var s0 := SurvivalUtil.num(sp[s].get("stock_per_cell"), 0.0)
			var r := 1.0 - pow(1.0 - SurvivalUtil.num(sp[s].get("recovery_per_season"), 0.3), 1.0 / season_len)
			c[s] = SurvivalUtil.num(c.get(s), s0) + r * (s0 - SurvivalUtil.num(c.get(s), s0))
	var deer := SurvivalUtil.dict(core.data.section("map_regions", "fauna").get("deer"))
	var tl := _tl(core)
	tl["deer_stock"] = minf(SurvivalUtil.num(deer.get("stock"), 24.0),
			SurvivalUtil.num(tl.get("deer_stock"), 24.0) + SurvivalUtil.num(deer.get("immigration_per_game_day"), 1.0))


## Extra game minutes a check will take: re-setting a buried set, re-setting after a catch.
static func check_extra_minutes(core: SurvivalCore, t: Dictionary) -> float:
	var tm := core.data.trap_model()
	var extra := 0.0
	match str(t.get("state", "")):
		"buried":
			extra += SurvivalUtil.num(SurvivalUtil.dict(SurvivalUtil.dict(tm.get("snow_reset")).get(str(t.type))).get("min"), 8.0)
		"holding":
			extra += SurvivalUtil.num(SurvivalUtil.dict(tm.get("season_sim")).get("reset_after_catch_min"), 8.0)
	return extra


## trap.check's effect on one trap. Returns {trap, caught, carcass, reset}.
static func check(core: SurvivalCore, id: String, outcome: String) -> Dictionary:
	var t := trap(core, id)
	if t.is_empty():
		return {"trap": id, "caught": "", "reset": false}
	var res := {"trap": id, "caught": "", "carcass": "", "reset": false}
	if str(t.state) == "holding" and str(t.catch) != "":
		res["caught"] = str(t.catch)
		res["carcass"] = SurvivalCamp.add_carcass(core, str(t.catch), {"source": "trap", "location": str(t.get("location", "")),
				"weapon_fit": 1.0})
		t["catch"] = ""
		core.state.stats["catches_collected"] = int(SurvivalUtil.num(core.state.stats.get("catches_collected"), 0.0)) + 1
	t["last_visit_day"] = SurvivalClock.abs_day(core)
	if outcome == "failure" or outcome == "mishap":
		t["state"] = "sprung"
	else:
		t["state"] = "set"
		res["reset"] = true
	core._on_trap_changed(id, str(t.state))
	return res


static func summary(core: SurvivalCore) -> Dictionary:
	var out := {"total": 0, "set": 0, "holding": 0, "sprung": 0, "buried": 0, "steel": 0, "deadfall": 0}
	for t in traps(core).values():
		out.total = int(out.total) + 1
		out[str(t.state)] = int(out.get(str(t.state), 0)) + 1
		if str(t.type) == "steel_land":
			out.steel = int(out.steel) + 1
		else:
			out.deadfall = int(out.deadfall) + 1
	return out


## Deer in the region's woods (map_regions.json fauna.deer): hunting takes from it.
static func deer_stock(core: SurvivalCore) -> float:
	return SurvivalUtil.num(_tl(core).get("deer_stock"), 24.0)


static func take_deer(core: SurvivalCore) -> void:
	_tl(core)["deer_stock"] = maxf(0.0, deer_stock(core) - 1.0)
