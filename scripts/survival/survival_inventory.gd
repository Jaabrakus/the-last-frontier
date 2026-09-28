class_name SurvivalInventory
extends RefCounted
## Inventory, load and clothing (items.json, needs.json load), as functions over SurvivalCore.
##
## A stack is {id, qty, meta}. qty is a float because some units are shared out (a gill is 1/8 of a quart of rum).
## meta carries what makes two stacks of one item differ: a pelt's grade and prime factor, food's cooking state and
## spoilage, a green hide drying, a flint's wear. Stacks merge when their discrete meta matches; continuous values
## (spoilage, drying, wear) are averaged by quantity. Food shows to the player in meals only; weight shows as load.

## Meta keys that do not stop two stacks merging (averaged by quantity instead).
const CONTINUOUS_META := ["spoil", "dry_h", "wear"]
const GRADE_ORDER := ["poor", "fair", "good", "prime_well_handled"]
const EPS := 0.0001
## Activities that wear footwear and snowshoes (items.json durability_rule.walk).
const WALKING := ["walk", "run", "sprint", "snowshoe", "wading", "heavy_work", "crouch"]
## Jobs done in one place that the body counts as "walk" for energy but that wear footwear at half rate (tick_wear).
const STANDING_ANIMS := ["anim.work_waist", "anim.gather_low", "anim.gather_high"]


static func _stacks(core: SurvivalCore) -> Array:
	return core.state.inventory


static func _merge_key(id: String, meta: Dictionary) -> String:
	var m := {}
	for k in meta.keys():
		if not CONTINUOUS_META.has(str(k)):
			m[k] = meta[k]
	return id + "|" + SurvivalUtil.stable_key(m)


## A stable id for a new stack ("st.<n>", world-scoped: multiplayer_readiness.md P0-4). Trade lines name stacks by uid.
static func new_uid(core: SurvivalCore) -> String:
	var w := core.state.world
	if not w.has("ids"):
		w["ids"] = {}
	var n := int(SurvivalUtil.num(w.ids.get("st"), 1.0))
	w.ids["st"] = n + 1
	return "st.%d" % n


## Add qty of an item. Returns the stack it went into.
static func add(core: SurvivalCore, id: String, qty: float, meta: Dictionary = {}) -> Dictionary:
	return add_to(core, _stacks(core), id, qty, meta)


## Add qty of an item to any party's stacks (the local pack, or a guest player's in a trade). uid: keep a moved stack's
## uid when it does not merge. notify: emit inventory_changed (the local pack only).
static func add_to(core: SurvivalCore, stacks: Array, id: String, qty: float, meta: Dictionary = {}, uid: String = "", notify: bool = true) -> Dictionary:
	if qty <= EPS or id == "":
		return {}
	if core.data.item(id).is_empty():
		core.log_line("unknown item %s ignored" % id, "warn")
		return {}
	var key := _merge_key(id, meta)
	for st in stacks:
		if str(st.id) == id and _merge_key(id, st.get("meta", {})) == key:
			var old_q := float(st.qty)
			var m: Dictionary = st.meta
			for c in CONTINUOUS_META:
				if m.has(c) or meta.has(c):
					m[c] = (SurvivalUtil.num(m.get(c), 0.0) * old_q + SurvivalUtil.num(meta.get(c), 0.0) * qty) / (old_q + qty)
			st.qty = old_q + qty
			if notify and is_same(stacks, _stacks(core)):
				core._on_inventory_changed()
			return st
	var ns := {"id": id, "qty": qty, "meta": meta.duplicate(true), "uid": uid if uid != "" else new_uid(core)}
	stacks.append(ns)
	if notify and is_same(stacks, _stacks(core)):
		core._on_inventory_changed()
	return ns


static func find_uid(core: SurvivalCore, uid: String) -> Dictionary:
	return find_uid_in(_stacks(core), uid)


static func find_uid_in(stacks: Array, uid: String) -> Dictionary:
	for st in stacks:
		if str(st.get("uid", "")) == uid:
			return st
	return {}


## Is this stack usable now (not curing on the rack or the smoke)?
static func usable(st: Dictionary) -> bool:
	return not bool(SurvivalUtil.dict(st.get("meta")).get("curing", false))


## Units of an item that can be used, eaten, worn, crafted with or traded now (curing stacks excluded).
static func count_usable(core: SurvivalCore, id: String) -> float:
	return count_usable_in(core, _stacks(core), id)


static func count_usable_in(_core: SurvivalCore, stacks: Array, id: String) -> float:
	var n := 0.0
	for st in stacks:
		if str(st.id) == id and usable(st):
			n += float(st.qty)
	return n


## The best usable stack of an item (highest quality first), or {}.
static func best_stack(core: SurvivalCore, id: String) -> Dictionary:
	var best := {}
	for st in _stacks(core):
		if str(st.id) != id or not usable(st):
			continue
		if best.is_empty() or stack_quality(st) > stack_quality(best):
			best = st
	return best


## Take qty of an item out of a party's stacks for a trade's escrow: by uid, or the best usable stacks first. Returns the
## parts [{id, qty, meta, uid}] (a whole stack keeps its uid; a split part gets a new one when it is added back).
static func take_for_trade(core: SurvivalCore, stacks: Array, id: String, qty: float, uid: String = "", notify: bool = true) -> Array:
	var cands := []
	if uid != "":
		var one := find_uid_in(stacks, uid)
		if not one.is_empty():
			cands.append(one)
	else:
		for st in stacks:
			if str(st.id) == id and usable(st):
				cands.append(st)
		cands.sort_custom(func(a, b): return stack_quality(a) > stack_quality(b))
	var out := []
	var left := qty
	for st in cands:
		if left <= EPS:
			break
		var take := minf(left, float(st.qty))
		st.qty = float(st.qty) - take
		left -= take
		out.append({"id": str(st.id), "qty": take, "meta": SurvivalUtil.dict(st.meta).duplicate(true),
				"uid": str(st.get("uid", "")) if float(st.qty) <= EPS else ""})
	for i in range(stacks.size() - 1, -1, -1):
		if float(stacks[i].qty) <= EPS:
			stacks.remove_at(i)
	if is_same(stacks, _stacks(core)):
		_compact(core)
		if notify and not out.is_empty():
			core._on_inventory_changed()
	return out


## Remove up to qty. `filter` matches meta values; `order` picks stacks first: "oldest" (most spoiled first),
## "best" (highest grade and value first), "worst". Returns the removed parts [{id, qty, meta}].
static func remove(core: SurvivalCore, id: String, qty: float, filter: Dictionary = {}, order: String = "oldest") -> Array:
	var out := []
	var left := qty
	var cands := stacks_of(core, id, filter)
	match order:
		"oldest":
			cands.sort_custom(func(a, b): return SurvivalUtil.num(a.meta.get("spoil"), 0.0) > SurvivalUtil.num(b.meta.get("spoil"), 0.0))
		"best":
			cands.sort_custom(func(a, b): return stack_quality(a) > stack_quality(b))
		"worst":
			cands.sort_custom(func(a, b): return stack_quality(a) < stack_quality(b))
	for st in cands:
		if left <= EPS:
			break
		var take := minf(left, float(st.qty))
		st.qty = float(st.qty) - take
		left -= take
		out.append({"id": id, "qty": take, "meta": SurvivalUtil.dict(st.meta).duplicate(true)})
	_compact(core)
	if not out.is_empty():
		core._on_inventory_changed()
	return out


static func remove_stack_qty(core: SurvivalCore, stack: Dictionary, qty: float) -> Dictionary:
	var take := minf(qty, float(stack.get("qty", 0.0)))
	stack.qty = float(stack.qty) - take
	var part := {"id": str(stack.id), "qty": take, "meta": SurvivalUtil.dict(stack.meta).duplicate(true)}
	_compact(core)
	core._on_inventory_changed()
	return part


static func _compact(core: SurvivalCore) -> void:
	var inv := _stacks(core)
	for i in range(inv.size() - 1, -1, -1):
		if float(inv[i].qty) <= EPS:
			inv.remove_at(i)
	# Worn items must still be carried.
	for i in range(core.state.worn.size() - 1, -1, -1):
		if count(core, str(core.state.worn[i])) < 1.0 - EPS:
			core.state.worn.remove_at(i)


static func stacks_of(core: SurvivalCore, id: String, filter: Dictionary = {}) -> Array:
	var out := []
	for st in _stacks(core):
		if str(st.id) != id:
			continue
		var ok := true
		for k in filter.keys():
			if SurvivalUtil.dict(st.meta).get(k) != filter[k]:
				ok = false
				break
		if ok:
			out.append(st)
	return out


static func count(core: SurvivalCore, id: String, filter: Dictionary = {}) -> float:
	var n := 0.0
	for st in stacks_of(core, id, filter):
		n += float(st.qty)
	return n


static func has(core: SurvivalCore, id: String, qty: float = 1.0) -> bool:
	return count(core, id) >= qty - EPS


## The first carried item from an any-of list (tool aliases count: a throwing tomahawk serves as a hatchet).
static func has_any(core: SurvivalCore, any_of: Array, qty: float = 1.0) -> String:
	for want in any_of:
		if has(core, str(want), qty):
			return str(want)
	for st in _stacks(core):
		if float(st.qty) < qty - EPS:
			continue
		for alias in core.data.tool_aliases(str(st.id)):
			if any_of.has(alias):
				return str(st.id)
	return ""


## Every inner list must be satisfied (recipes.json rules.tools). Returns the missing any-of lists.
static func missing_tools(core: SurvivalCore, tools) -> Array:
	var miss := []
	for group in SurvivalUtil.arr(tools):
		var g: Array = group if typeof(group) == TYPE_ARRAY else [group]
		if has_any(core, g) == "":
			miss.append(g)
	return miss


static func by_cat(core: SurvivalCore, cat: String) -> Array:
	var out := []
	for st in _stacks(core):
		if core.data.item_cat(str(st.id)) == cat:
			out.append(st)
	return out


## Value factor of a pelt or skin stack: grade by handling x prime x animal condition x any value multiplier.
static func stack_quality(st: Dictionary) -> float:
	var m := SurvivalUtil.dict(st.get("meta"))
	var g := 1.0
	match str(m.get("grade", "good")):
		"poor": g = 0.5
		"fair": g = 0.8
		"prime_well_handled": g = 1.15
	if bool(m.get("slipped", false)):
		g *= 0.3
	return g * SurvivalUtil.num(m.get("prime"), 1.0) * SurvivalUtil.num(m.get("condition"), 1.0) \
			* SurvivalUtil.num(m.get("value_mult"), 1.0) * (0.7 if bool(m.get("spoiled", false)) else 1.0)


## Grade factor from items.json pelt_rules.grade_by_handling.
static func grade_factor(core: SurvivalCore, grade: String) -> float:
	var g := SurvivalUtil.dict(core.data.section("items", "pelt_rules").get("grade_by_handling"))
	return SurvivalUtil.num(g.get(grade), 1.0)


static func shift_grade(grade: String, steps: int) -> String:
	var i := GRADE_ORDER.find(grade)
	if i < 0:
		i = 2
	return GRADE_ORDER[clampi(i + steps, 0, GRADE_ORDER.size() - 1)]


# ---------------------------------------------------------------- load
static func weight_kg(core: SurvivalCore) -> float:
	var kg := 0.0
	var perk := SurvivalUtil.num(core.perk_effect("carry_capacity_mult.pelts_meat", 1.0), 1.0)
	for st in _stacks(core):
		var it := core.data.item(str(st.id))
		var w := SurvivalUtil.num(it.get("kg"), 0.0) * float(st.qty)
		var cat := str(it.get("cat", ""))
		if perk > 0.0 and (cat == "pelt" or cat == "skin" or cat.begins_with("meat") or str(st.id) == "item.material.green_hide"):
			w /= perk
		kg += w
	return kg


## "normal", "heavy" or "overloaded" (needs.json load: comfortable 30 kg, heavy 45, max 60).
static func load_stage(core: SurvivalCore) -> String:
	var ld := core.data.section("needs", "load")
	var kg := weight_kg(core)
	if kg <= SurvivalUtil.num(ld.get("comfortable_kg"), 30.0):
		return "normal"
	if kg <= SurvivalUtil.num(ld.get("heavy_kg"), 45.0):
		return "heavy"
	return "overloaded"


static func can_carry(core: SurvivalCore, extra_kg: float) -> bool:
	return weight_kg(core) + extra_kg <= SurvivalUtil.num(core.data.section("needs", "load").get("max_kg"), 60.0)


# ---------------------------------------------------------------- food
static func is_food(core: SurvivalCore, id: String) -> bool:
	var it := core.data.item(id)
	return SurvivalUtil.num(it.get("kcal"), 0.0) > 0.0 and str(it.get("cat", "")) != "material"


## Game kcal of a stack (burnt food x0.5, spoiled x0.7: items.json cooking_states and spoiled_food).
static func stack_kcal(core: SurvivalCore, st: Dictionary) -> float:
	var k := SurvivalUtil.num(core.data.item(str(st.id)).get("kcal"), 0.0) * float(st.qty)
	var m := SurvivalUtil.dict(st.get("meta"))
	if str(m.get("cook", "")) == "burnt":
		k *= 0.5
	if bool(m.get("spoiled", false)):
		k *= SurvivalUtil.num(SurvivalUtil.dict(core.data.section("items", "spoiled_food")).get("kcal_mult"), 0.7)
	return k


## Meals carried (food shows in meals only: needs.json food.display). include_uncooked counts cornmeal and raw meat.
static func meals(core: SurvivalCore, include_uncooked: bool = true) -> float:
	var meal := SurvivalUtil.num(core.data.section("needs", "food").get("meal_game_kcal"), 800.0)
	var total := 0.0
	for st in _stacks(core):
		if not is_food(core, str(st.id)):
			continue
		if not include_uncooked and (bool(core.data.item(str(st.id)).get("needs_cooking", false))):
			continue
		total += stack_kcal(core, st)
	return total / meal


# ---------------------------------------------------------------- clothing
static func wear(core: SurvivalCore, id: String) -> bool:
	if not has(core, id) or core.data.item(id).get("clothing", null) == null:
		return false
	var worn_n := core.state.worn.count(id)
	if count(core, id) < float(worn_n + 1) - EPS:
		return false
	core.state.worn.append(id)
	core._on_inventory_changed()
	return true


## Put a garment on when its slot (its clothing class) is empty: a garment just made, or received, goes on as a player
## would put it on (fix round 1: made mitts were never worn). Returns true when it went on.
static func wear_if_slot_empty(core: SurvivalCore, id: String) -> bool:
	var it := core.data.item(id)
	var cls = it.get("clothing", null)
	if cls == null or str(it.get("cat", "")) != "clothing" or count_usable(core, id) < 1.0 - EPS:
		return false
	for w in core.state.worn:
		if str(core.data.item(str(w)).get("clothing", "")) == str(cls):
			return false
	return wear(core, id)


static func take_off(core: SurvivalCore, id: String) -> bool:
	var i := core.state.worn.find(id)
	if i < 0:
		return false
	core.state.worn.remove_at(i)
	core._on_inventory_changed()
	return true


## Wear one of each clothing item carried, first come first served, one garment class per zone set (starting kits).
static func wear_all_clothing(core: SurvivalCore) -> void:
	var classes_worn := {}
	for st in _stacks(core):
		var it := core.data.item(str(st.id))
		var cls = it.get("clothing", null)
		if cls == null or str(it.get("cat", "")) != "clothing":
			continue
		if classes_worn.has(str(cls)):
			continue
		classes_worn[str(cls)] = true
		core.state.worn.append(str(st.id))
	core._on_inventory_changed()


static func worn_classes(core: SurvivalCore) -> Array:
	var out := []
	for id in core.state.worn:
		var cls := str(core.data.item(str(id)).get("clothing", ""))
		if core.data.clothing.has(cls):
			out.append(core.data.clothing[cls])
	return out


static func is_wearing_class(core: SurvivalCore, cls_id: String) -> bool:
	for c in worn_classes(core):
		if str(c.id) == cls_id:
			return true
	return false


# ---------------------------------------------------------------- spoilage and drying
## Spoilage band from the air temperature (items.json spoilage_classes: warm > 15 C, cool 0-15 C, frozen < 0 C).
static func temp_band(air_c: float) -> String:
	if air_c > 15.0:
		return "warm"
	if air_c >= 0.0:
		return "cool"
	return "frozen"


## Food and green hides spoil; stretched pelts and hides dry (actions.json fur.dry, a passive 2-3 game days).
static func tick(core: SurvivalCore, hours: float, air_c: float, exposed_to_rain: bool) -> void:
	var classes := SurvivalUtil.dict(core.data.section("items", "spoilage_classes").get("classes"))
	var band := temp_band(air_c)
	var changed := false
	var converted := []
	for st in _stacks(core):
		var it := core.data.item(str(st.id))
		var m: Dictionary = st.meta
		if bool(m.get("curing", false)) and core.state.minutes >= SurvivalUtil.num(m.get("cure_until"), 0.0):
			m.erase("curing")
			m.erase("cure_until")
			changed = true
			core.log_line("%s has cured and is ready" % core.data.item_name(str(st.id)), "camp")
		var cls := str(it.get("spoil", ""))
		if bool(m.get("green", false)):
			cls = "green_pelt"
		if cls != "" and classes.has(cls) and not bool(m.get("spoiled", false)) and not bool(m.get("slipped", false)):
			var life = SurvivalUtil.dict(classes[cls]).get(band)
			if life != null and SurvivalUtil.num(life, 0.0) > 0.0:
				# A fleshed pelt laced in a hoop dries before it slips unless the weather is against it: while it is
				# stretched its green clock runs at stretched_mult (fix round 1: a deer hide stretched in September
				# always slipped, since it spoiled in a warm game day and dried in two or three).
				var rate := 1.0
				if cls == "green_pelt" and bool(m.get("stretched", false)):
					rate = SurvivalUtil.num(SurvivalUtil.dict(classes[cls]).get("stretched_mult"), 1.0)
				m["spoil"] = SurvivalUtil.num(m.get("spoil"), 0.0) + hours / 24.0 / SurvivalUtil.num(life) * rate
				if float(m.spoil) >= 1.0:
					if cls == "green_pelt":
						m["slipped"] = true
						m["grade"] = "poor"
						core.log_line("%s: the hair slipped (spoiled before drying)" % core.data.item_name(str(st.id)), "loss")
					else:
						m["spoiled"] = true
					changed = true
		if bool(m.get("green", false)) and bool(m.get("stretched", false)) and not bool(m.get("slipped", false)):
			m["dry_h"] = SurvivalUtil.num(m.get("dry_h"), 0.0) + hours
			if exposed_to_rain:
				var pas := SurvivalUtil.dict(SurvivalUtil.dict(core.data.action("fur.dry").get("passive")).get("rain_or_thaw_unsheltered"))
				if core.rng.randf() < SurvivalUtil.num(pas.get("hair_slip_chance"), 0.25) * hours / 24.0:
					m["grade"] = shift_grade(str(m.get("grade", "good")), int(SurvivalUtil.num(pas.get("pelt_grade_shift"), -2.0)))
					core.log_line("rain on the drying %s: the grade drops" % core.data.item_name(str(st.id)), "loss")
			if float(m.dry_h) >= SurvivalUtil.num(m.get("dry_need_h"), 60.0):
				m.erase("green")
				m.erase("stretched")
				m.erase("dry_h")
				m.erase("dry_need_h")
				m.erase("spoil")
				m["dried"] = true
				changed = true
				if str(st.id) == "item.material.green_hide":
					converted.append(st)
	for st in converted:
		# A dried deer hide trades as a fall skin, at 0.8 of its value outside October-January (actions.json carcass_yields.deer).
		var meta := {"grade": str(st.meta.get("grade", "good")), "value_mult": SurvivalUtil.num(st.meta.get("value_mult"), 1.0),
				"condition": SurvivalUtil.num(st.meta.get("condition"), 1.0), "dried": true}
		var q := float(st.qty)
		st.qty = 0.0
		add(core, "item.skin.deer_fall", q, meta)
	if not converted.is_empty():
		_compact(core)
	if changed:
		core._on_inventory_changed()


## Wear a use-limited tool (items.json uses): a flint strikes about 40 fires.
static func wear_tool(core: SurvivalCore, id: String, amount: float = 1.0) -> void:
	var uses := SurvivalUtil.num(core.data.item(id).get("uses"), 0.0)
	if uses <= 0.0:
		return
	var sts := stacks_of(core, id)
	if sts.is_empty():
		return
	var st: Dictionary = sts[0]
	var w := SurvivalUtil.num(st.meta.get("wear"), 0.0) + amount
	if w >= uses:
		st.meta["wear"] = 0.0
		remove_stack_qty(core, st, 1.0)
		core.log_line("a %s wore out" % core.data.item_name(id), "loss")
	else:
		st.meta["wear"] = w


## A plain list for UI and tests: [{id, name, qty, meals, kg, meta}].
static func listing(core: SurvivalCore) -> Array:
	var meal := SurvivalUtil.num(core.data.section("needs", "food").get("meal_game_kcal"), 800.0)
	var out := []
	for st in _stacks(core):
		var it := core.data.item(str(st.id))
		out.append({"id": str(st.id), "name": str(it.get("name", st.id)), "qty": float(st.qty),
				"meals": stack_kcal(core, st) / meal if is_food(core, str(st.id)) else 0.0,
				"kg": SurvivalUtil.num(it.get("kg"), 0.0) * float(st.qty), "worn": core.state.worn.has(str(st.id)),
				"meta": SurvivalUtil.dict(st.meta).duplicate(true)})
	return out


# ---------------------------------------------------------------- clothing wear (items.json durability_rule)
## Footwear and snowshoes wear by walking hours, mitts and caps by hours worn outdoors. A worn-out pair is gone and a
## spare of the same item goes on. Wear is kept per worn item on the player's record (players[pid].wear).
static func tick_wear(core: SurvivalCore, hours: float) -> void:
	if hours <= 0.0 or core.state.asleep:
		return
	var wear := _wear(core)
	var act := core.state.activity
	var outdoors := not bool(core.state.context.get("indoors", false))
	var ids := {}
	for id in core.state.worn:
		ids[str(id)] = true
	if act == "snowshoe" and has(core, "item.tool.snowshoes"):
		ids["item.tool.snowshoes"] = true
	for id in ids.keys():
		var it := core.data.item(str(id))
		var walk_h := SurvivalUtil.num(it.get("durability_walk_h"), 0.0)
		var days := SurvivalUtil.num(it.get("durability_game_days"), 0.0)
		var add := 0.0
		if walk_h > 0.0 and WALKING.has(act):
			if str(id) != "item.tool.snowshoes" or act == "snowshoe":
				# Standing work (splitting, building), work at the waist or stooped low (dressing a hide on its frame,
				# foraging, chinking) and kneeling work (setting traps, skinning, digging) wear the soles at half the
				# rate of walking [D; fix round 1: such work counted as walking].
				add = hours / walk_h * (0.5 if act == "heavy_work" or act == "crouch" or _standing_job(core) else 1.0)
		elif days > 0.0 and outdoors:
			add = hours / (days * 24.0)
		if add <= 0.0:
			continue
		var w := SurvivalUtil.num(wear.get(id), 0.0) + add
		if w >= 1.0:
			wear[id] = 0.0
			remove(core, str(id), 1.0, {}, "worst")
			core.log_line("worn out: %s" % core.data.item_name(str(id)).to_lower(), "loss")
			core.state.stats["worn_out_" + str(id).get_slice(".", 2)] = int(SurvivalUtil.num(core.state.stats.get("worn_out_" + str(id).get_slice(".", 2)), 0.0)) + 1
			if not core.state.worn.has(id) and core.data.item(str(id)).get("clothing", null) != null and has(core, str(id)):
				core.state.worn.append(str(id))
			core._on_inventory_changed()
		else:
			wear[id] = w


## A job worked in one place, at the waist or stooped low (its anim hook), rather than walking about.
static func _standing_job(core: SurvivalCore) -> bool:
	var j := SurvivalJobs.current(core)
	return not j.is_empty() and STANDING_ANIMS.has(str(j.get("anim", "")))


static func _wear(core: SurvivalCore) -> Dictionary:
	var p := core.player()
	if not p.has("wear"):
		p["wear"] = {}
	return p.wear


## How worn an item is (0 new, 1 worn out), for the durability pips.
static func wear_of(core: SurvivalCore, id: String) -> float:
	return SurvivalUtil.num(_wear(core).get(id), 0.0)


## Mending (clothing.repair_moccasins): takes `add` of a new pair's durability off the most worn item it can mend.
## Returns the item mended, or "".
static func mend(core: SurvivalCore, items: Array, add: float) -> String:
	var wear := _wear(core)
	var best := ""
	var best_w := 0.0
	for id in items:
		var w := SurvivalUtil.num(wear.get(str(id)), 0.0)
		if has(core, str(id)) and w > best_w:
			best_w = w
			best = str(id)
	if best != "":
		wear[best] = maxf(0.0, best_w - add)
	return best


## Anything worn that mending would help (more than a tenth worn)?
static func needs_mending(core: SurvivalCore, items: Array) -> bool:
	for id in items:
		if has(core, str(id)) and SurvivalUtil.num(_wear(core).get(str(id)), 0.0) > 0.1:
			return true
	return false
