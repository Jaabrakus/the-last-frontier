class_name SurvivalCamp
extends RefCounted
## Logical camp objects: campfires, shelters, bedding and carcasses (actions.json world_objects).
##
## These are records, not scene nodes. Each has a stable id ("fire.3") and a logical `location` (a POI id such as
## poi.fort.woods_camp, or any tag the game uses). The world layer, when it is built, spawns and positions a node per
## record and passes the ids it is near back in state.context (fire_id, fire_distance_m, shelter_id, in_shelter).
## Without explicit ids the record at the player's context.location is used, which is what the sim harness does.

## A coal from a burnt-down fire stays hot this long; adding fuel within it relights the fire [D].
const EMBER_MIN := 30.0
## A partial strike's coal must be nursed within this many game minutes or it dies [D].
const STRIKE_COAL_MIN := 10.0
## Fuel order for tending and auto-feeding: longest-burning first.
const FUEL_ORDER := ["item.fuel.split_wood", "item.fuel.bundle", "item.fuel.kindling"]
const FIRE_ORDER := {"lit": 3, "banked": 2, "smouldering": 1, "out": 0}
## A dead fire's record is dropped this many game days after it went out (its fuel stack gone) [D].
const OUT_FIRE_KEEP_DAYS := 3.0


static func _c(core: SurvivalCore, key: String) -> Dictionary:
	if not core.state.camp.has(key):
		core.state.camp[key] = {}
	return core.state.camp[key]


static func _new_id(core: SurvivalCore, prefix: String) -> String:
	var n := int(SurvivalUtil.num(core.state.camp.get("next_id"), 1.0))
	core.state.camp["next_id"] = n + 1
	return "%s.%d" % [prefix, n]


static func location(core: SurvivalCore) -> String:
	return str(core.state.context.get("location", ""))


# ---------------------------------------------------------------- fires
static func fires(core: SurvivalCore) -> Dictionary:
	return _c(core, "fires")


static func create_fire(core: SurvivalCore, loc: String, fire_state: String, fuel_min: float) -> String:
	var id := _new_id(core, "fire")
	fires(core)[id] = {"id": id, "state": fire_state, "fuel_min": fuel_min, "coal_h": 0.0,
			"ember_min": STRIKE_COAL_MIN if fire_state == "smouldering" else 0.0,
			"coal_only": fire_state == "smouldering", "location": loc, "stack": {}, "created": core.state.minutes}
	core._on_fire_changed(id, fire_state)
	return id


static func fire(core: SurvivalCore, id: String) -> Dictionary:
	return fires(core).get(id, {})


## A building's hearth (the sutler's store, the barracks): always lit, never needs fuel, used for cooking. Indoors the
## warmth model uses indoor air instead of the fire's heat, so a hearth adds no warmth of its own [D].
static func ensure_hearth(core: SurvivalCore, loc: String) -> String:
	var id := "hearth." + loc
	if not fires(core).has(id):
		fires(core)[id] = {"id": id, "state": "lit", "fuel_min": 0.0, "coal_h": 0.0, "ember_min": 0.0, "coal_only": false,
				"location": loc, "stack": {}, "created": core.state.minutes, "hearth": true}
	return id


## The fire the player is at: context.fire_id if set, else the best fire at context.location.
static func current_fire(core: SurvivalCore) -> Dictionary:
	var ctx := core.state.context
	var fid := str(ctx.get("fire_id", ""))
	if fid != "" and fires(core).has(fid):
		return fires(core)[fid]
	return fire_at(core, location(core))


## The best fire at a location: lit, then banked, smouldering, out; the oldest on a tie (by id, not key order).
static func fire_at(core: SurvivalCore, loc: String) -> Dictionary:
	var best := {}
	if loc == "":
		return best
	for f in fires(core).values():
		if str(f.location) != loc:
			continue
		var o := int(FIRE_ORDER.get(str(f.state), 0))
		var ob := int(FIRE_ORDER.get(str(best.get("state", "")), -1))
		if best.is_empty() or o > ob or (o == ob and SurvivalUtil.id_less(str(f.id), str(best.id))):
			best = f
	return best


static func set_fire_state(core: SurvivalCore, id: String, fire_state: String) -> void:
	var f := fire(core, id)
	if f.is_empty() or str(f.state) == fire_state:
		return
	f["state"] = fire_state
	if fire_state == "lit":
		f["coal_only"] = false
	if fire_state == "smouldering" and SurvivalUtil.num(f.get("ember_min"), 0.0) <= 0.0:
		f["ember_min"] = EMBER_MIN
	if fire_state == "out":
		f["out_at"] = core.state.minutes
	else:
		f.erase("out_at")
	core._on_fire_changed(id, fire_state)


static func fuel_min_of(core: SurvivalCore, item_id: String) -> float:
	return SurvivalUtil.num(core.data.item(item_id).get("fuel_min"), 0.0)


## Burn rate multiplier outdoors in wet weather (seasons.json weather fire_mod: rain -0.2 burns 20% faster) [D reading].
static func burn_mult(core: SurvivalCore, f: Dictionary) -> float:
	var sh := shelter_at(core, str(f.get("location", "")))
	if not sh.is_empty() and SurvivalUtil.num(sh.get("quality"), 0.0) >= 3.0:
		return 1.0
	return 1.0 + absf(SurvivalUtil.num(SurvivalWeather.row(core).get("fire_mod"), 0.0))


## Hours of burning left from the fire's fuel and its stack.
static func fuel_hours(core: SurvivalCore, id: String) -> float:
	var f := fire(core, id)
	if f.is_empty():
		return 0.0
	if bool(f.get("hearth", false)):
		return 24.0
	var m := SurvivalUtil.num(f.get("fuel_min"), 0.0)
	for k in SurvivalUtil.dict(f.get("stack")).keys():
		m += fuel_min_of(core, str(k)) * SurvivalUtil.num(f.stack[k])
	return m / 60.0 / burn_mult(core, f)


## Add fuel to a fire (fire.tend's effect). Returns true when the fire burns afterwards.
static func add_fuel(core: SurvivalCore, id: String, item_id: String, qty: float = 1.0) -> bool:
	var f := fire(core, id)
	if f.is_empty():
		return false
	var st := str(f.state)
	if st == "out" or (st == "smouldering" and bool(f.get("coal_only", false))):
		return false
	f["fuel_min"] = SurvivalUtil.num(f.get("fuel_min"), 0.0) + fuel_min_of(core, item_id) * qty
	if st != "lit":
		set_fire_state(core, id, "lit")
	return true


## Drop carried fuel within 2 m of a fire: the stack feeds it by itself as it burns down (world.campfire.fuel_stack).
static func stack_fuel(core: SurvivalCore, id: String, item_id: String, qty: float) -> float:
	var f := fire(core, id)
	if f.is_empty():
		return 0.0
	var moved := 0.0
	for part in SurvivalInventory.remove(core, item_id, qty):
		moved += float(part.qty)
	if moved > 0.0:
		var stck: Dictionary = f.stack
		stck[item_id] = SurvivalUtil.num(stck.get(item_id), 0.0) + moved
	return moved


static func _feed_from_stack(core: SurvivalCore, f: Dictionary) -> bool:
	var stck: Dictionary = f.stack
	for fuel in FUEL_ORDER:
		if SurvivalUtil.num(stck.get(fuel), 0.0) >= 1.0:
			stck[fuel] = SurvivalUtil.num(stck[fuel]) - 1.0
			if float(stck[fuel]) <= 0.0001:
				stck.erase(fuel)
			f["fuel_min"] = SurvivalUtil.num(f.get("fuel_min"), 0.0) + fuel_min_of(core, fuel)
			return true
	return false


static func bank(core: SurvivalCore, id: String, coal_h: float) -> void:
	var f := fire(core, id)
	if f.is_empty():
		return
	f["coal_h"] = coal_h
	set_fire_state(core, id, "banked")


static func tick(core: SurvivalCore, hours: float) -> void:
	var minutes := hours * 60.0
	var dead := []
	for f in fires(core).values():
		if bool(f.get("hearth", false)):
			continue
		match str(f.state):
			"lit":
				var need := minutes * burn_mult(core, f)
				var fuel := SurvivalUtil.num(f.get("fuel_min"), 0.0)
				while need > 0.0:
					if fuel >= need:
						fuel -= need
						need = 0.0
					else:
						need -= fuel
						fuel = 0.0
						f["fuel_min"] = 0.0
						if not _feed_from_stack(core, f):
							break
						fuel = SurvivalUtil.num(f.get("fuel_min"), 0.0)
				f["fuel_min"] = fuel
				# burnt down right at the step's end: the next stick of its stack catches before it smoulders (the loop
				# above feeds only when a step needs more than is left, and 120-minute sticks end on the 10-minute steps)
				if fuel <= 0.0 and _feed_from_stack(core, f):
					fuel = SurvivalUtil.num(f.get("fuel_min"), 0.0)
				if fuel <= 0.0:
					f["ember_min"] = EMBER_MIN
					set_fire_state(core, str(f.id), "smouldering")
			"banked":
				f["coal_h"] = SurvivalUtil.num(f.get("coal_h"), 0.0) - hours
				if float(f.coal_h) <= 0.0:
					f["ember_min"] = EMBER_MIN
					set_fire_state(core, str(f.id), "smouldering")
			"smouldering":
				f["ember_min"] = SurvivalUtil.num(f.get("ember_min"), 0.0) - minutes
				if float(f.ember_min) <= 0.0:
					set_fire_state(core, str(f.id), "out")
			"out":
				# The cold hearth stays three game days after it went out (not after it was first lit).
				var since := SurvivalUtil.num(f.get("out_at", f.get("created")), 0.0)
				if core.state.minutes - since > OUT_FIRE_KEEP_DAYS * SurvivalClock.MIN_PER_DAY \
						and SurvivalUtil.dict(f.get("stack")).is_empty():
					dead.append(str(f.id))
	for id in dead:
		fires(core).erase(id)


# ---------------------------------------------------------------- shelters and bedding
static func shelters(core: SurvivalCore) -> Dictionary:
	return _c(core, "shelters")


static func create_shelter(core: SurvivalCore, loc: String, kind: String, quality: float) -> String:
	var id := _new_id(core, "shelter")
	shelters(core)[id] = {"id": id, "type": kind, "quality": quality, "location": loc, "created": core.state.minutes}
	core.log_line("%s raised (quality %d)" % [kind.replace("_", " "), int(quality)], "camp")
	return id


## The best shelter at a location; the oldest on a tie (by id, not key order).
static func shelter_at(core: SurvivalCore, loc: String) -> Dictionary:
	var best := {}
	if loc == "":
		return best
	for s in shelters(core).values():
		if str(s.location) != loc:
			continue
		if best.is_empty() or float(s.quality) > float(best.quality) \
				or (float(s.quality) == float(best.quality) and SurvivalUtil.id_less(str(s.id), str(best.id))):
			best = s
	return best


static func current_shelter(core: SurvivalCore) -> Dictionary:
	var sid := str(core.state.context.get("shelter_id", ""))
	if sid != "" and shelters(core).has(sid):
		return shelters(core)[sid]
	return shelter_at(core, location(core))


static func beds(core: SurvivalCore) -> Dictionary:
	return _c(core, "beds")


static func set_bedding(core: SurvivalCore, loc: String, kind: String, ground_ins: float) -> void:
	beds(core)[loc] = {"type": kind, "ground_ins": ground_ins, "location": loc, "created": core.state.minutes}


## The bedding the player lies on here: context.bedding, else a bed laid at this location.
static func current_bedding(core: SurvivalCore) -> String:
	var b := str(core.state.context.get("bedding", ""))
	if b != "":
		return b
	var bed := SurvivalUtil.dict(beds(core).get(location(core)))
	return str(bed.get("type", ""))


## Extra insulation while sleeping: a carried blanket or matchcoat not worn (items.json clothing bedding_ins).
static func bedding_insulation(core: SurvivalCore) -> float:
	var ins := 0.0
	for st in core.state.inventory:
		var it := core.data.item(str(st.id))
		var cls := SurvivalUtil.dict(core.data.clothing.get(str(it.get("clothing", ""))))
		var bi := SurvivalUtil.num(cls.get("bedding_ins"), 0.0)
		if bi <= 0.0:
			continue
		var spare := float(st.qty) - float(core.state.worn.count(str(st.id)))
		if spare >= 1.0:
			ins += bi * floorf(spare)
	return minf(ins, 6.0)


static func has_blanket_bedding(core: SurvivalCore) -> bool:
	for st in core.state.inventory:
		var it := core.data.item(str(st.id))
		var cls := SurvivalUtil.dict(core.data.clothing.get(str(it.get("clothing", ""))))
		if SurvivalUtil.num(cls.get("bedding_ins"), 0.0) > 0.0:
			return true
	return false


# ---------------------------------------------------------------- carcasses
static func carcasses(core: SurvivalCore) -> Dictionary:
	return _c(core, "carcasses")


## The carcass_yields kind for a species: deer, small, raccoon or furbearer (actions.json carcass_yields).
static func carcass_kind(core: SurvivalCore, species: String) -> String:
	var cy := core.data.section("actions", "carcass_yields")
	if cy.has(species) and typeof(cy[species]) == TYPE_DICTIONARY:
		return species
	for k in cy.keys():
		var row = cy[k]
		if typeof(row) == TYPE_DICTIONARY and SurvivalUtil.arr(row.get("species")).has(species):
			return str(k)
	return "small"


## A dead animal: from a trap (kill "trap") or the player's shot (report_kill). Pelt value factors are fixed here, at the
## moment of the kill (items.json pelt_rules.prime_factor).
static func add_carcass(core: SurvivalCore, species: String, opts: Dictionary = {}) -> String:
	var id := _new_id(core, "carcass")
	var cond := int(SurvivalUtil.num(opts.get("condition"), float(core.rng.randi_range(1, 3))))
	var pr := SurvivalUtil.dict(core.data.section("items", "pelt_rules"))
	var cond_mult := SurvivalUtil.num(SurvivalUtil.dict(pr.get("animal_condition")).get(str(cond)), 1.0)
	var month := SurvivalClock.month_id(core)
	var kind := carcass_kind(core, species)
	var rec := {"id": id, "species": species, "kind": kind, "condition": cond, "condition_mult": cond_mult,
			"prime": SurvivalEconomy.prime_factor(core, species, month), "month": month,
			"weapon_fit": SurvivalUtil.num(opts.get("weapon_fit"), 1.0), "shot_quality": SurvivalUtil.num(opts.get("shot_quality"), 1.0),
			"skinned": false, "dressed": false, "location": str(opts.get("location", location(core))),
			"source": str(opts.get("source", "trap")), "spoil": 0.0, "created": core.state.minutes}
	carcasses(core)[id] = rec
	return id


static func carcass(core: SurvivalCore, id: String) -> Dictionary:
	return carcasses(core).get(id, {})


static func carcass_has_pelt(core: SurvivalCore, rec: Dictionary) -> bool:
	return pelt_item_for(core, str(rec.get("species", ""))) != ""


## The fur pelt item for a species (items with cat pelt and that species); deer give a green hide instead.
static func pelt_item_for(core: SurvivalCore, species: String) -> String:
	for it in core.data.items.values():
		if str(it.get("cat", "")) == "pelt" and str(it.get("species", "")) == species:
			return str(it.id)
	return ""


static func finish_carcass_if_done(core: SurvivalCore, id: String) -> void:
	var rec := carcass(core, id)
	if rec.is_empty():
		return
	var need_skin := carcass_has_pelt(core, rec) and not bool(rec.skinned)
	if bool(rec.dressed) and not need_skin:
		carcasses(core).erase(id)


static func tick_carcasses(core: SurvivalCore, hours: float, air_c: float) -> void:
	var classes := SurvivalUtil.dict(core.data.section("items", "spoilage_classes").get("classes"))
	var life = SurvivalUtil.dict(classes.get("fresh_meat")).get(SurvivalInventory.temp_band(air_c))
	if life == null or SurvivalUtil.num(life, 0.0) <= 0.0:
		return
	for rec in carcasses(core).values():
		rec["spoil"] = SurvivalUtil.num(rec.get("spoil"), 0.0) + hours / 24.0 / SurvivalUtil.num(life)


# ---------------------------------------------------------------- v4 world records: caches, drying racks, staged builds
## These are WORLD records (SurvivalState.world: caches, racks, builds), each with an owner and a location, so a camp is
## the same place for every player later (multiplayer_readiness.md P0-3). Items in a cache do not count toward load.
static func _wrec(core: SurvivalCore, key: String) -> Dictionary:
	var w := core.state.world
	if not w.has(key):
		w[key] = {}
	return w[key]


static func _wid(core: SurvivalCore, prefix: String) -> String:
	var w := core.state.world
	if not w.has("ids"):
		w["ids"] = {}
	var n := int(SurvivalUtil.num(w.ids.get(prefix), 1.0))
	w.ids[prefix] = n + 1
	return "%s.%d" % [prefix, n]


static func caches(core: SurvivalCore) -> Dictionary:
	return _wrec(core, "caches")


## A cache at a location (preserve.cache_pit): kind "hung" (a meat pole, M2a) or "pit" (M3).
static func create_cache(core: SurvivalCore, loc: String, kind: String, quality: String) -> String:
	var ex := cache_at(core, loc)
	if not ex.is_empty():
		ex["quality"] = quality if quality == "good" else str(ex.get("quality", quality))
		return str(ex.id)
	var id := _wid(core, "cache")
	var cfg := SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("actions", "world_objects").get("world.cache_pit")).get("kinds"))
	caches(core)[id] = {"id": id, "kind": kind, "quality": quality, "location": loc, "owner": core.state.player_id,
			"items": [], "capacity_kg": SurvivalUtil.num(SurvivalUtil.dict(cfg.get(kind)).get("capacity_kg"), 150.0),
			"created": core.state.minutes}
	core.log_line("a %s cache made at %s" % [kind, loc], "camp")
	return id


static func cache_at(core: SurvivalCore, loc: String) -> Dictionary:
	for id in SurvivalUtil.sorted_ids(caches(core)):
		if str(caches(core)[id].get("location", "")) == loc:
			return caches(core)[id]
	return {}


static func cache_kg(core: SurvivalCore, c: Dictionary) -> float:
	var kg := 0.0
	for st in SurvivalUtil.arr(c.get("items")):
		kg += SurvivalUtil.num(core.data.item(str(st.id)).get("kg"), 0.0) * float(st.qty)
	return kg


## Move qty of an item from the pack into the cache here (best-kept first). Only usable stacks go in: a buckskin still
## curing stays in the pack until its cure is done (curing is ticked on the pack, never in a cache). A garment being
## worn stays on. Returns the qty stored.
static func cache_store(core: SurvivalCore, cache_id: String, item: String, qty: float) -> float:
	var c := SurvivalUtil.dict(caches(core).get(cache_id))
	if c.is_empty() or str(c.location) != location(core):
		return 0.0
	var room_kg := SurvivalUtil.num(c.get("capacity_kg"), 150.0) - cache_kg(core, c)
	var kg := maxf(0.0001, SurvivalUtil.num(core.data.item(item).get("kg"), 0.1))
	var free := SurvivalInventory.count_usable(core, item) - float(core.state.worn.count(item))
	var n := minf(minf(qty, free), floorf(room_kg / kg * 1000.0) / 1000.0)
	if n <= 0.0:
		return 0.0
	var moved := 0.0
	for part in SurvivalInventory.remove(core, item, n, {"curing": null}):
		SurvivalInventory.add_to(core, c.items, str(part.id), float(part.qty), SurvivalUtil.dict(part.meta), "", false)
		moved += float(part.qty)
	return moved


## Take qty of an item out of the cache here into the pack. Returns the qty taken.
static func cache_take(core: SurvivalCore, cache_id: String, item: String, qty: float) -> float:
	var c := SurvivalUtil.dict(caches(core).get(cache_id))
	if c.is_empty() or str(c.location) != location(core):
		return 0.0
	var got := 0.0
	for part in SurvivalInventory.take_for_trade(core, c.items, item, qty, "", false):
		SurvivalInventory.add(core, str(part.id), float(part.qty), SurvivalUtil.dict(part.meta))
		got += float(part.qty)
	return got


## Food carried in the pack, in kg (the eat and cache prompts show it).
static func food_kg_carried(core: SurvivalCore) -> float:
	var kg := 0.0
	for st in core.state.inventory:
		if SurvivalInventory.is_food(core, str(st.id)):
			kg += SurvivalUtil.num(core.data.item(str(st.id)).get("kg"), 0.0) * float(st.qty)
	return kg


## One cache's meals.
static func cache_meals_of(core: SurvivalCore, c: Dictionary) -> float:
	var meal := SurvivalUtil.num(core.data.section("needs", "food").get("meal_game_kcal"), 800.0)
	var k := 0.0
	for st in SurvivalUtil.arr(c.get("items")):
		if SurvivalInventory.is_food(core, str(st.id)):
			k += SurvivalInventory.stack_kcal(core, st)
	return k / meal


## The cache panel here (a UI hook): {id, kind, quality, items: [{id, name, qty, meals, kg}], meals, kg, capacity_kg,
## pack_food_kg}, or {} when no cache stands here.
static func cache_panel(core: SurvivalCore) -> Dictionary:
	var c := cache_at(core, location(core))
	if c.is_empty():
		return {}
	var meal := SurvivalUtil.num(core.data.section("needs", "food").get("meal_game_kcal"), 800.0)
	var items := []
	for st in SurvivalUtil.arr(c.get("items")):
		items.append({"id": str(st.id), "name": core.data.item_name(str(st.id)), "qty": float(st.qty),
				"meals": SurvivalInventory.stack_kcal(core, st) / meal if SurvivalInventory.is_food(core, str(st.id)) else 0.0,
				"kg": SurvivalUtil.num(core.data.item(str(st.id)).get("kg"), 0.0) * float(st.qty)})
	return {"id": str(c.id), "kind": str(c.get("kind", "")), "quality": str(c.get("quality", "")), "items": items,
			"meals": cache_meals_of(core, c), "kg": cache_kg(core, c), "capacity_kg": SurvivalUtil.num(c.get("capacity_kg"), 150.0),
			"pack_food_kg": food_kg_carried(core)}


## Meals kept in caches (for the almanac and the food-security measure).
static func cache_meals(core: SurvivalCore) -> float:
	var meal := SurvivalUtil.num(core.data.section("needs", "food").get("meal_game_kcal"), 800.0)
	var k := 0.0
	for c in caches(core).values():
		for st in SurvivalUtil.arr(c.get("items")):
			if SurvivalInventory.is_food(core, str(st.id)):
				k += SurvivalInventory.stack_kcal(core, st)
	return k / meal


## A game day in a cache: food spoils at the air's temperature like the pack's, and animals and passers-by take a little
## (the world stream "w.caches"; less from a hung cache of frozen meat).
static func tick_caches(core: SurvivalCore) -> void:
	var cfg := SurvivalUtil.dict(SurvivalUtil.dict(core.data.section("actions", "world_objects").get("world.cache_pit")).get("pilferage_per_game_day"))
	var air := SurvivalClock.air_temp_c(core)
	var classes := SurvivalUtil.dict(core.data.section("items", "spoilage_classes").get("classes"))
	var band := SurvivalInventory.temp_band(air)
	var rng := SurvivalStreams.world(core, "caches")
	for id in SurvivalUtil.sorted_ids(caches(core)):
		var c: Dictionary = caches(core)[id]
		for st in SurvivalUtil.arr(c.get("items")):
			var it := core.data.item(str(st.id))
			var m: Dictionary = st.meta
			var cls := str(it.get("spoil", ""))
			if cls != "" and classes.has(cls) and not bool(m.get("spoiled", false)):
				var life = SurvivalUtil.dict(classes[cls]).get(band)
				if life != null and SurvivalUtil.num(life, 0.0) > 0.0:
					m["spoil"] = SurvivalUtil.num(m.get("spoil"), 0.0) + 1.0 / SurvivalUtil.num(life)
					if float(m.spoil) >= 1.0:
						m["spoiled"] = true
			var p := SurvivalUtil.num(cfg.get(str(c.get("quality", "good"))), 0.01)
			if str(it.get("cat", "")).begins_with("meat"):
				p *= SurvivalUtil.num(cfg.get("meat_mult"), 2.0)
				if str(c.get("kind", "")) == "hung" and air < 0.0:
					p *= SurvivalUtil.num(cfg.get("hung_frozen_meat_mult"), 0.5)
			var lost := float(st.qty) * p * (0.5 + rng.randf())
			# Whole things go whole (a pelt, a pair of mitts): the loss rounds to units by the same stream.
			if SurvivalCrafting._discrete(core, str(st.id)):
				var whole := floorf(lost)
				lost = whole + (1.0 if rng.randf() < lost - whole else 0.0)
			st.qty = maxf(0.0, float(st.qty) - lost)
		var items: Array = c.items
		for i in range(items.size() - 1, -1, -1):
			if float(items[i].qty) <= 0.0001:
				items.remove_at(i)


static func racks(core: SurvivalCore) -> Dictionary:
	return _wrec(core, "racks")


static func rack_at(core: SurvivalCore, loc: String, create: bool = false) -> Dictionary:
	for id in SurvivalUtil.sorted_ids(racks(core)):
		if str(racks(core)[id].get("location", "")) == loc:
			return racks(core)[id]
	if not create:
		return {}
	var id := _wid(core, "rack")
	racks(core)[id] = {"id": id, "location": loc, "owner": core.state.player_id, "hanging": [], "created": core.state.minutes}
	return racks(core)[id]


## Hang a product on the drying rack here until it has cured (the jerky: 1-2 game days).
static func rack_hang(core: SurvivalCore, item: String, qty: float, meta: Dictionary, cure_days: float) -> String:
	var r := rack_at(core, location(core), true)
	r.hanging.append({"id": item, "qty": qty, "meta": meta.duplicate(true), "ready_at": core.state.minutes + cure_days * SurvivalClock.MIN_PER_DAY})
	return str(r.id)


## Take down everything on the rack here that has cured. Returns {item: qty}.
static func rack_take_ready(core: SurvivalCore) -> Dictionary:
	var r := rack_at(core, location(core))
	var got := {}
	if r.is_empty():
		return got
	var keep := []
	for h in r.hanging:
		if core.state.minutes >= SurvivalUtil.num(h.get("ready_at"), 0.0):
			SurvivalInventory.add(core, str(h.id), float(h.qty), SurvivalUtil.dict(h.get("meta")))
			got[str(h.id)] = SurvivalUtil.num(got.get(str(h.id)), 0.0) + float(h.qty)
		else:
			keep.append(h)
	r["hanging"] = keep
	return got


static func rack_pending(core: SurvivalCore) -> float:
	var n := 0.0
	for r in racks(core).values():
		for h in SurvivalUtil.arr(r.get("hanging")):
			n += float(h.qty)
	return n


static func builds(core: SurvivalCore) -> Dictionary:
	return _wrec(core, "builds")


static func build_at(core: SurvivalCore, loc: String, kind: String) -> Dictionary:
	for id in SurvivalUtil.sorted_ids(builds(core)):
		var b: Dictionary = builds(core)[id]
		if str(b.get("location", "")) == loc and str(b.get("kind", "")) == kind:
			return b
	return {}


## One stage of a staged build done (the half-faced camp's three). When the last stage stands, the shelter is raised at
## quality + the stages' quality adds. Returns {stage, stages, done, shelter_id}.
static func build_stage(core: SurvivalCore, spec: Dictionary, quality_add: float) -> Dictionary:
	var loc := location(core)
	var kind := str(spec.get("id", "build"))
	var b := build_at(core, loc, kind)
	if b.is_empty():
		var id := _wid(core, "build")
		builds(core)[id] = {"id": id, "kind": kind, "stage": 0, "stages": int(SurvivalUtil.num(spec.get("stages"), 3.0)),
				"quality_add": 0.0, "location": loc, "owner": core.state.player_id, "created": core.state.minutes}
		b = builds(core)[id]
	b["stage"] = int(b.stage) + 1
	b["quality_add"] = SurvivalUtil.num(b.get("quality_add"), 0.0) + quality_add
	var names := SurvivalUtil.arr(spec.get("stage_names"))
	if int(b.stage) - 1 < names.size():
		core.log_line("%s: %s done (%d of %d)" % [kind.replace("_", " "), str(names[int(b.stage) - 1]), int(b.stage), int(b.stages)], "camp")
	var out := {"stage": int(b.stage), "stages": int(b.stages), "done": false}
	if int(b.stage) >= int(b.stages):
		var full_q := SurvivalUtil.num(spec.get("quality"), 4.0)
		var q := roundf((full_q + SurvivalUtil.num(b.get("quality_add"), 0.0)) * 2.0) / 2.0
		var sh := shelter_at(core, loc)
		if not sh.is_empty() and float(sh.get("quality", 0.0)) < q:
			sh["quality"] = q
			sh["type"] = str(spec.get("shelter", kind))
			out["shelter_id"] = str(sh.id)
		elif sh.is_empty():
			out["shelter_id"] = create_shelter(core, loc, str(spec.get("shelter", kind)), q)
			sh = shelter_at(core, loc)
		else:
			out["shelter_id"] = str(sh.id)
		# A stage done partially leaves gaps: chinking (add_wind) closes them before it adds wind protection.
		if not sh.is_empty() and q < full_q and float(sh.get("quality", 0.0)) <= q:
			sh["gaps"] = full_q - q
		builds(core).erase(str(b.id))
		out.done = true
		core.state.stats["built_" + kind] = int(SurvivalUtil.num(core.state.stats.get("built_" + kind), 0.0)) + 1
	return out


## Chinking and banked snow add up to 1 to a shelter's wind protection (shelter.chink_bank).
## A shelter left with gaps by a partial build stage has them closed first, one quality point a success (the gaps are
## what the partial stage took off); what is left of the work goes to wind protection.
static func add_wind(core: SurvivalCore, amount: float) -> void:
	var sh := current_shelter(core)
	if sh.is_empty():
		return
	var gaps := SurvivalUtil.num(sh.get("gaps"), 0.0)
	if gaps > 0.0:
		var fill := minf(gaps, amount)
		sh["gaps"] = gaps - fill
		sh["quality"] = float(sh.get("quality", 0.0)) + fill
		amount -= fill
		if float(sh.gaps) <= 0.0:
			sh.erase("gaps")
			core.log_line("the gaps in the %s are chinked" % str(sh.get("type", "shelter")).replace("_", " "), "camp")
	if amount > 0.0:
		sh["wind_add"] = minf(1.0, SurvivalUtil.num(sh.get("wind_add"), 0.0) + amount)
