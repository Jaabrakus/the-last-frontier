class_name HuntKit
extends RefCounted
## The hunter's kit out of the household's own things: the weapon she is best at that has shot for it, the shot for the trip,
## a knife, a meal. The hunt job's `tools` in data/companion/jobs.json say what it takes (need: the weapons, any of them;
## optional: the knives; use_by: the whole units of shot a trip takes for each weapon; food: the meals, first there first);
## hunt.json "weapons" say what each weapon is (its pool kinds, its skill, its shot per firing).
##
## Where things come from is the household's TOOL POOL (scripts/companion/tool_pool.gd, ToolPool.of(worker)): its racks and
## chests, its claims (two workers never count on the same gun) and its ledger of who holds what. The hunt uses its API only:
##   planned(w, o)   the plan is the hunt: her weapon and knife claimed (her body walks to the rack and chest for them:
##                   ToolCarry, before she goes out)
##   arm(w, o)       begin(): the weapon and knife in her hands (collected now if her body did not fetch them)
##   check_out(w)    the hunt starts: the shot for the trip and a meal (ToolPool.take); the shot goes into her survival core,
##                   where HuntJob.fire spends it, and each shot fired, arrow lost or spear lost is ToolPool.spend-ed (used())
##   check_in(w)     the hunt over: the unfired shot, the weapon and the knife are due back (her body walks them to the rack;
##                   without a body they go at once), the uneaten meal back to the store
## Without a pool (a worker with no household, the old tests) she hunts with her own kit (the survival core's musket and
## shot) and borrows from the store (StoreSource) as before.

const JOB := "hunt"


# ---------------------------------------------------------------- the job's tools (jobs.json)
static func tools() -> Dictionary:
	var t: Variant = JobBook.job(JOB).get("tools", {}) if JobBook.has(JOB) else {}
	return t if t is Dictionary else {}


## The knife kinds (as the pool names them), best first.
static func knives() -> Array:
	var out := []
	for g: Variant in tools().get("optional", [(HuntJob.cfg().get("kit", {}) as Dictionary).get("knife", [])]):
		for k: Variant in (g if g is Array else [g]):
			var r := ToolPool.resolve(String(k))
			if not out.has(r):
				out.append(r)
	return out


static func food_kinds() -> Array:
	return tools().get("food", (HuntJob.cfg().get("kit", {}) as Dictionary).get("trip_food", []))


## The whole units of each shot kind a trip with pool weapon `kind` takes ({} for spears; carry_shots' worth when not said).
static func trip_units(kind: String, wp: Dictionary) -> Dictionary:
	var ub: Dictionary = tools().get("use_by", {})
	if ub.has(kind):
		return (ub[kind] as Dictionary).duplicate()
	var out := {}
	var want := int(HuntJob.cfg().get("carry_shots", 4))
	for item: String in wp.get("ammo", {}):
		var sk: Array = HuntJob.store_kind_of(item)
		if String(sk[0]) != "":
			out[String(sk[0])] = ceili(float(wp.ammo[item]) * want / maxf(float(sk[1]), 0.0001) - 0.0001)
	return out


# ---------------------------------------------------------------- where things come from
static func pool(w: SpouseCore) -> ToolPool:
	return ToolPool.of(w)


## The source of the household's things (count / take / put_back): the pool, else the plain store.
static func source(w: SpouseCore) -> Object:
	var p := pool(w)
	return p if p != null else StoreSource.new(w.stock)


## Units of `kind` she can have: what she holds of it already and the free ones.
static func count(w: SpouseCore, kind: String) -> int:
	var n := int(source(w).call("count", kind, w.worker_id))
	var p := pool(w)
	if p != null and ToolPool.is_pool(kind):
		n += int(p.held_by(w).get(ToolPool.resolve(kind), 0))
	return n


## Takes `n` of `kind` into the hunt's kit; how many came.
static func take(w: SpouseCore, kind: String, n: int) -> int:
	var got := int(source(w).call("take", kind, n, w.worker_id))
	if got > 0:
		_kit_add(w, kind, got)
	return got


static func put_back(w: SpouseCore, kind: String, n: int) -> void:
	if n <= 0:
		return
	source(w).call("put_back", kind, n, w.worker_id)
	_kit_add(w, kind, -n)


static func _kit_add(w: SpouseCore, kind: String, n: int) -> void:
	var kit: Dictionary = w.hunt.get("kit", {})
	kit[kind] = maxi(int(kit.get(kind, 0)) + n, 0)
	if int(kit[kind]) == 0:
		kit.erase(kind)
	w.hunt["kit"] = kit


# ---------------------------------------------------------------- the weapon
## The kind of weapon `wp` she can have now ("" none): with a pool, one she holds already, else a free one on the racks (the
## weapon's pool kinds in order); without, her own ("kit") and then the store's.
static func weapon_kind(w: SpouseCore, wp: Dictionary) -> String:
	var p := pool(w)
	if p == null and String(wp.get("kit", "")) != "" and SurvivalInventory.has(w.core, String(wp.kit), 1.0):
		return "kit"
	if p != null:
		var h := p.held_by(w)
		for k: String in wp.get("pool", []):
			if int(h.get(ToolPool.resolve(k), 0)) > 0:
				return ToolPool.resolve(k)
	for k: String in wp.get("pool", []):
		if int(source(w).call("count", k, w.worker_id)) > 0:
			return ToolPool.resolve(k) if p != null else k
	return ""


## Shots she could have with `wp`: throws for spears (a pair two), else the scarcest of its shot in her core and in the
## household (what she holds and the free units).
static func shots_for(w: SpouseCore, wp: Dictionary, kind: String) -> int:
	if bool(wp.get("throwable", false)):
		return int(wp.get("throws_per", 1)) * (1 if kind != "" else 0)
	return shots_available(w, wp)


static func shots_available(w: SpouseCore, wp: Dictionary) -> int:
	var n := 1 << 30
	for item: String in wp.get("ammo", {}):
		var per := maxf(float(wp.ammo[item]), 0.0001)
		var have := SurvivalInventory.count(w.core, item)
		var sk: Array = HuntJob.store_kind_of(item)
		if String(sk[0]) != "":
			have += count(w, String(sk[0])) * float(sk[1])
		n = mini(n, floori(have / per + 0.0001))
	return 0 if n == 1 << 30 else n


## Her pick among what she can have: {id, kind, skill} of the weapon with a shot that she is best at (its skill: marksmanship,
## archery or close combat, plus the weapon's `prefer`: a pistol or the spears only when nothing better), {} none.
static func best_weapon(w: SpouseCore) -> Dictionary:
	var best := {}
	var bs := -INF
	for wp: Dictionary in HuntJob.weapons():
		var kind := weapon_kind(w, wp)
		if kind == "" or shots_for(w, wp, kind) < 1:
			continue
		var s := SurvivalSkills.level(w.core, String(wp.get("skill", "marksmanship"))) + float(wp.get("prefer", 0.0))
		if s > bs:
			bs = s
			best = {"id": String(wp.id), "kind": kind, "skill": s}
	return best


## The pool's needs for her weapon and a knife (ToolPool.claim / checkout).
static func arm_needs(kind: String) -> Dictionary:
	var n := {"need": [], "optional": [], "use": {}}
	if kind != "" and kind != "kit":
		n.need = [[kind]]
	var kn := knives()
	if not kn.is_empty():
		n.optional = [kn]
	return n


## Why she cannot hunt for want of a weapon, for the Tasks tab (the pool's `blocked`, as the other jobs' tools).
static func blocked(w: SpouseCore, why: String) -> void:
	var p := pool(w)
	if p == null:
		return
	if why == "":
		if p.blocked.has(w.worker_id):
			(p.blocked[w.worker_id] as Dictionary).erase(JOB)
			if (p.blocked[w.worker_id] as Dictionary).is_empty():
				p.blocked.erase(w.worker_id)
		return
	if not p.blocked.has(w.worker_id):
		p.blocked[w.worker_id] = {}
	p.blocked[w.worker_id][JOB] = why


# ---------------------------------------------------------------- the plan and the start
## SpouseCore.plan (HUNT): the plan is the hunt: her weapon (not the pool's first free one) and a knife claimed, for her body
## to fetch from the rack and the chest before she goes out.
static func planned(w: SpouseCore, o: Dictionary) -> void:
	var p := pool(w)
	if p != null and String(o.get("weapon_from", "")) != "":
		p.claim(w, arm_needs(String(o.weapon_from)), JOB)


## SpouseCore.begin (HUNT, before the pool's own ready()): her weapon and knife in hand (taken now where her body did not
## fetch them). False: the weapon is gone from the rack.
static func arm(w: SpouseCore, o: Dictionary) -> bool:
	var p := pool(w)
	if p == null:
		return true
	p.drop_claims(w)
	return bool(p.checkout(w, arm_needs(String(o.get("weapon_from", "")))).get("ok", false))


## At the start of the hunt: the weapon (her own, the pool's in hand, or the store's), the trip's shot into her core, a knife,
## a meal. Returns the kit {kind: n}.
static func check_out(w: SpouseCore, weapon_id: String, weapon_kind_: String) -> Dictionary:
	var wp := HuntJob.weapon_cfg(weapon_id)
	w.hunt["kit"] = {}
	w.hunt["kit_items"] = {}
	w.hunt["used"] = {}
	w.hunt["spent"] = {}
	w.hunt["weapon_kind"] = weapon_kind_
	var p := pool(w)
	if p != null:
		# (the runner put what she holds into her core for the rules; the hunt keeps its own account of it)
		p.unload_core(w)
		var r := p.checkout(w, arm_needs(weapon_kind_))
		for k: String in (r.get("items", {}) as Dictionary):
			_kit_add(w, k, int(r.items[k]))
	else:
		if weapon_kind_ != "kit" and weapon_kind_ != "":
			take(w, weapon_kind_, 1)
		for k: String in knives():
			if count(w, k) > 0 and take(w, k, 1) > 0:
				break
	if bool(wp.get("throwable", false)):
		w.hunt["throws"] = int(wp.get("throws_per", 1))
		w.hunt["lost"] = 0
	else:
		_top_up(w, wp, weapon_kind_)
	for k: String in food_kinds():
		if int(w.stock.free_count(k, w.worker_id)) > 0 and take(w, k, 1) > 0:
			w.hunt["food"] = k
			break
	return (w.hunt.kit as Dictionary).duplicate()


## The trip's shot (trip_units) out of the household into her core, where it is spent; less what her core has of it already
## (her own, without a pool).
static func _top_up(w: SpouseCore, wp: Dictionary, kind: String) -> void:
	var items: Dictionary = w.hunt.get("kit_items", {})
	var units := trip_units(kind, wp)
	for item: String in wp.get("ammo", {}):
		var sk: Array = HuntJob.store_kind_of(item)
		var k := String(sk[0])
		if k == "":
			continue
		var qty := maxf(float(sk[1]), 0.0001)
		var want := float(units.get(k, 1)) * qty
		var need := want - SurvivalInventory.count(w.core, item)
		if need <= 0.0001:
			continue
		var got := take(w, k, ceili(need / qty - 0.0001))
		if got > 0:
			SurvivalInventory.add(w.core, item, got * qty)
			items[k] = [item, qty, got]
	w.hunt["kit_items"] = items


# ---------------------------------------------------------------- spending
## `amount` of core item `item` was used (a shot fired, an arrow lost): its whole units are spent from what she holds of the
## pool (ToolPool.spend), a part unit counted until it makes a whole one (a pound of powder is forty charges).
static func used(w: SpouseCore, item: String, amount: float) -> int:
	var p := pool(w)
	var sk: Array = HuntJob.store_kind_of(item)
	var k := String(sk[0])
	var items: Dictionary = w.hunt.get("kit_items", {})
	if p == null or k == "" or not items.has(k):
		return 0
	var u: Dictionary = w.hunt.get("used", {})
	var s: Dictionary = w.hunt.get("spent", {})
	u[k] = float(u.get(k, 0.0)) + amount / maxf(float(sk[1]), 0.0001)
	var whole := mini(floori(float(u[k]) + 0.0001), int(items[k][2]))
	var n := whole - int(s.get(k, 0))
	var m := 0
	if n > 0:
		m = p.spend(w, k, n)
		s[k] = whole
		_kit_add(w, k, -n)
	w.hunt["used"] = u
	w.hunt["spent"] = s
	return m


## A spear of the pair not found again: the pair is spent when both are gone.
static func spear_lost(w: SpouseCore) -> void:
	w.hunt["lost"] = int(w.hunt.get("lost", 0)) + 1
	var wp := HuntJob.weapon_cfg(String(w.hunt.get("weapon", "")))
	var kind := String(w.hunt.get("weapon_kind", ""))
	var p := pool(w)
	if int(w.hunt.lost) >= int(wp.get("throws_per", 1)) and p != null and kind != "" and kind != "kit":
		if p.spend(w, kind, 1) > 0:
			_kit_add(w, kind, -1)
			w._note("%s loses both %s." % [w.name, String(wp.get("name", "spears"))])


# ---------------------------------------------------------------- her things
## Whether she carries a knife for the dressing (the pool's, or her own).
static func has_knife(w: SpouseCore) -> bool:
	for k: String in knives():
		if int((w.hunt.get("kit", {}) as Dictionary).get(k, 0)) > 0:
			return true
	return SurvivalInventory.has_any(w.core, ["item.tool.knife", "item.tool.flint_knife"]) != ""


## The trip's meal eaten (she is hungry out there): out of the kit into her.
static func eat_trip_food(w: SpouseCore) -> bool:
	var k := String(w.hunt.get("food", ""))
	if k == "" or int((w.hunt.get("kit", {}) as Dictionary).get(k, 0)) <= 0:
		return false
	var stage := SurvivalNeeds.food_stage(w.core)
	if stage in ["fed", "full", "satisfied", "peckish"]:
		return false
	var e: Dictionary = w.items.get(k, {})
	if e.is_empty():
		return false
	var id := String(e.item)
	SurvivalInventory.add(w.core, id, float(e.get("qty", 1.0)))
	SurvivalFood.eat(w.core, id, {"force": true})
	var left := SurvivalInventory.count(w.core, id)
	if left > 0.0001:
		SurvivalInventory.remove(w.core, id, left)
	_kit_add(w, k, -1)
	w.hunt["food"] = ""
	w._note("%s eats the %s she took along." % [w.name, InventoryState.name_of(k).to_lower()])
	return true


## The pool kind of weapon she carries ("" none, "kit" her own).
static func weapon_held(w: SpouseCore) -> String:
	return String(w.hunt.get("weapon_kind", ""))


# ---------------------------------------------------------------- back
## The hunt over: the unfired shot out of her core (the part unit used is spent, its rest kept by the pool as its own part
## units are), the uneaten meal to the store, and the weapon, the knife and the shot due back to the rack and chest (her body
## walks them there: ToolCarry; without a body they go at once). Without a pool: what is left goes back to the store.
static func check_in(w: SpouseCore) -> Dictionary:
	var back := {}
	var p := pool(w)
	var items: Dictionary = w.hunt.get("kit_items", {})
	var kit: Dictionary = (w.hunt.get("kit", {}) as Dictionary).duplicate()
	for k: String in items:
		var it := String(items[k][0])
		var qty := maxf(float(items[k][1]), 0.0001)
		var left := SurvivalInventory.count(w.core, it)
		if p == null:
			# (her own shot stays in her core; the store's whole units left go back)
			var n := mini(floori(left / qty + 0.0001), int(kit.get(k, 0)))
			if n > 0:
				SurvivalInventory.remove(w.core, it, n * qty)
				put_back(w, k, n)
				back[k] = n
			kit.erase(k)
			continue
		var taken := int(items[k][2])
		left = minf(left, taken * qty)
		if left > 0.0:
			SurvivalInventory.remove(w.core, it, left)
		var whole := floori(left / qty + 0.0001)
		var frac := left / qty - float(whole)
		var holds := int(kit.get(k, 0))
		if holds > whole:
			p.spend(w, k, holds - whole)             # the unit she broke into is used; its rest is the pool's part unit
			_kit_add(w, k, whole - holds)
		if frac > 0.0001 and holds > whole:
			p.partial[k] = float(p.partial.get(k, 0.0)) + frac
			if float(p.partial[k]) >= 1.0 - 0.0001:
				p.partial[k] = float(p.partial[k]) - 1.0
				p.add(k, 1)
		if whole > 0:
			back[k] = whole
	# the meal and anything else of the store's
	kit = (w.hunt.get("kit", {}) as Dictionary).duplicate()
	for k: String in kit:
		if items.has(k):
			continue                                 # (shot: dealt with above; what is not left was used)
		if p == null or not ToolPool.is_pool(k):
			put_back(w, k, int(kit[k]))
			back[k] = int(back.get(k, 0)) + int(kit[k])
	if p != null:
		var h := p.held_by(w)
		for k: String in h:
			back[k] = int(h[k])
		if not h.is_empty():
			if p.walkers.has(w.worker_id):
				p.due[w.worker_id] = h.keys()     # her body walks them back (ToolCarry), the weapon to its rack
				p.job_of.erase(w.worker_id)
			else:
				if int(w.hunt.get("shots", 0)) > 0:
					p.wear(w, JOB)
				p.return_all(w)
	w.hunt["kit"] = {}
	return back


# ---------------------------------------------------------------- the plain store
## The household store as the pool (a household with no pool, and the tests): the chests' free units, the claims kept.
class StoreSource extends RefCounted:
	var stock: HouseholdStock

	func _init(s: HouseholdStock) -> void:
		stock = s

	func count(kind: String, owner: int) -> int:
		return stock.free_count(kind, owner)

	func take(kind: String, n: int, owner: int) -> int:
		return stock.take_for(owner, kind, n, stock.worker_name(owner), "the hunt")   # LEDGER

	func put_back(kind: String, n: int, owner: int) -> int:
		return stock.put(kind, n, stock.worker_name(owner), "back from the hunt")
