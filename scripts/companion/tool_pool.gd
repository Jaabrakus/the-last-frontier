class_name ToolPool
extends RefCounted
## The household's pool of tools, weapons and consumables that its workers borrow and bring back (user 2026-09-29: "for the
## supply chain we need to add a household pool of tools and items they can use and bring back"). data/companion/tools.json.
##
## What the pool owns stands in the real containers: its chest kinds (hatchets, knives, awls, traps, powder, ball ...) in the
## storage chests, its rack kinds (musket, pistol, bow, throwing spears, tomahawk) in the weapon racks and spear barrels (the
## store: HouseholdStock / ChestStock, ToolRacks), and what fits nowhere "in the house" (overflow). The pool keeps the rest:
## who holds what (held, with each unit's wear), who has claimed what for the job she is going to (claims: two workers never
## count on the same axe), what is due back, the wear of the units in the containers, broken tools, part units of consumables.
##
## A job names its tools (jobs.json `tools`, joined with the survival rules' requires.tools of its action and its recipes):
## `need` any-of groups (all required), `optional` groups (taken when free; a timed job goes faster), `use` consumables a run
## takes. The runner (SpouseCore hooks marked TOOLS) plans only jobs whose needs are free (offer_ok), claims them when it plans
## (planned), her body walks to the chest or rack for them (ToolCarry), begin() collects what is still claimed and puts the
## borrowed things into her survival core for the job's action (load_core), the end of a run takes them out again (consumables
## used are gone, the rest stays with her), wears the tools and now and then breaks one. She keeps them between runs of the
## same job and puts them back when she changes job, at the end of her day, when she leaves or dies.
##
## API for the other work (the hunt): a worker is a SpouseCore or its worker id.
##   checkout(worker, needs) -> {ok, items {kind: n}, reason}   takes what `needs` asks (at once, no walking)
##   return_all(worker)                                         everything she holds back where it belongs
##   available(kind, owner = -1) -> int                         free units (others' claims left out)
##   held_by(worker) -> {kind: n}                               what she holds
##   counts() -> {kind: {name, owned, store, out, claimed, worn, by {name: n}}}
##   count(kind, owner) / take(kind, n, owner) / put_back(kind, n, owner) / spend(worker, kind, n)   HuntKit's source shape
##     (any store kind: the pool's own kinds are lent, the others are the store's)
##   ToolPool.of(worker) -> the pool of her household (null: none: she keeps her own kit as before)

const PATH := "res://data/companion/tools.json"
const LINES_PATH := "res://data/companion/lines.json"

static var _cfg := {}
static var _item_kinds := {}   ## core item -> [pool kinds] (tools and weapons first, then consumables)
static var _needs := {}        ## job id -> needs (cached)
static var _acts := {}         ## action id -> requires
static var _rcps := {}         ## recipe id -> tools
static var _lines := {}

var _stock: WeakRef
## wid -> {kind: n} claimed in the containers for the job she is going to (not taken yet).
var claims := {}
## wid -> {kind: [unit {wear, state?}]} out of the containers, with her.
var held := {}
## wid -> the job the held and claimed things are for.
var job_of := {}
## wid -> [kind] she is to put back (her body walks them to the chest or rack; without a body they go at once).
var due := {}
## kind -> [wear] of the units standing in the containers (a unit without an entry is new).
var stored_wear := {}
## kind -> part units of a consumable left over from runs (a whole one goes back to the store).
var partial := {}
## [{kind, name, by, day}] broken tools (shown in the Tasks tab).
var broken: Array = []
## kind -> [unit] the pool owns that no container took (no chest yet, the racks full).
var overflow := {}
var seeded := {"chest": false, "rack": false}
## wid -> {job id: why it cannot be planned for want of a tool}.
var blocked := {}
## wid -> the body's ToolCarry (it walks her things to and from the containers).
var walkers := {}
## wid -> the worker's own kit state: "new" (just made: her background's kit is not hers), "" (from before the pool: her kit
## comes into the pool), "pooled" (done).
var kits := {}
var rng := RandomNumberGenerator.new()
var journal: Array = []
var _loaded := {}    ## wid -> {item: qty} tools put in her core for the run
var _cons := {}      ## wid -> {kind: [item, units, per, before]} consumables put in her core
var _running := {}   ## wid -> job id of the run in hand
var _tick := 0.0


# ================================================================ the data
static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = d if d is Dictionary else {}
		for k in ["kinds", "consumables", "aliases", "start", "worker_kit"]:
			if not (_cfg.get(k) is Dictionary):
				_cfg[k] = {}
		_item_kinds = {}
		for table in ["kinds", "consumables"]:
			var t: Dictionary = _cfg[table]
			for k: String in t:
				var it := String((t[k] as Dictionary).get("item", ""))
				if it == "":
					continue
				if not _item_kinds.has(it):
					_item_kinds[it] = []
				(_item_kinds[it] as Array).append(k)
	return _cfg


static func reload() -> void:
	_cfg = {}
	_needs = {}
	cfg()


## A kind as the pool knows it (the player's felling_axe is the pool's "axe" ...: tools.json aliases).
static func resolve(kind: String) -> String:
	return String((cfg().aliases as Dictionary).get(kind, kind))


static func kind_row(kind: String) -> Dictionary:
	var c := cfg()
	var k := resolve(kind)
	if (c.kinds as Dictionary).has(k):
		return c.kinds[k]
	return (c.consumables as Dictionary).get(k, {})


static func kinds() -> Array:
	return (cfg().kinds as Dictionary).keys()


static func consumable_kinds() -> Array:
	return (cfg().consumables as Dictionary).keys()


static func is_tool(kind: String) -> bool:
	return (cfg().kinds as Dictionary).has(resolve(kind))


static func is_consumable(kind: String) -> bool:
	return (cfg().consumables as Dictionary).has(resolve(kind))


static func is_pool(kind: String) -> bool:
	return is_tool(kind) or is_consumable(kind)


## Whether `kind` (as the store names it: no aliases) stands in the racks and barrels.
static func is_rack(kind: String) -> bool:
	var row: Variant = (cfg().kinds as Dictionary).get(kind)
	return row is Dictionary and String((row as Dictionary).get("store", "chest")) == "rack"


static func name_of(kind: String) -> String:
	return String(kind_row(kind).get("name", InventoryState.name_of(kind)))


static func item_of(kind: String) -> String:
	return String(kind_row(kind).get("item", ""))


## The pool kinds that are the survival item `item` (a musket and an over-and-under are both the rules' musket).
static func kinds_of_item(item: String) -> Array:
	cfg()
	return (_item_kinds.get(item, []) as Array).duplicate()


static func durability(kind: String) -> float:
	return maxf(float(kind_row(kind).get("durability", 100.0)), 1.0)


static func line(key: String) -> String:
	if _lines.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
		_lines = (d as Dictionary).get("tools", {"_": []}) if d is Dictionary else {"_": []}
	var v: Variant = _lines.get(key, [])
	if v is Array and not (v as Array).is_empty():
		return String((v as Array)[randi() % (v as Array).size()])
	return ""


# ---------------------------------------------------------------- what a job takes
## {need: [[kind ...]], optional: [[kind ...]], speed: {kind: minutes factor}, use: {kind: units}}: the job's jobs.json `tools`
## joined with what the survival rules ask of its action (requires.tools, tools_optional) and of its variants' recipes.
static func needs_of(job_id: String) -> Dictionary:
	if _needs.has(job_id):
		return _needs[job_id]
	var job := JobBook.job(job_id)
	var t: Dictionary = job.get("tools", {}) if job.get("tools") is Dictionary else {}
	var need := []
	var opt := []
	var speed := {}
	for g: Variant in t.get("need", []):
		_add_group(need, _kinds_group(g))
	var how: Dictionary = job.get("how", {})
	if String(how.get("type", "")) == "survival" and String(how.get("action", "")) != "":
		var rq := _action_requires(String(how.action))
		for g: Variant in rq.get("tools", []):
			_add_group(need, _item_group(g))
		for g: Variant in rq.get("tools_optional", []):
			_add_group(opt, _item_group(g))
		for v: Dictionary in job.get("variants", []):
			var rid := String((v.get("params", {}) as Dictionary).get("recipe", ""))
			for g: Variant in _recipe_tools(rid):
				_add_group(need, _item_group(g))
	for o: Variant in t.get("optional", []):
		var grp := _kinds_group((o as Dictionary).get("any", []) if o is Dictionary else o)
		_add_group(opt, grp)
		if o is Dictionary:
			for k: String in grp:
				speed[k] = float((o as Dictionary).get("speed", 1.0))
	var use := {}
	for k: String in (t.get("use", {}) as Dictionary):
		use[resolve(k)] = int(t.use[k])
	var out := {"need": need, "optional": opt, "speed": speed, "use": use}
	_needs[job_id] = out
	return out


static func _kinds_group(g: Variant) -> Array:
	var out := []
	for k: Variant in (g if g is Array else [g]):
		var r := resolve(String(k))
		if is_pool(r) and not out.has(r):
			out.append(r)
	return out


## The pool kinds for a rules group of items (in the group's order; the tools and weapons, not consumables).
static func _item_group(g: Variant) -> Array:
	var out := []
	for it: Variant in (g if g is Array else [g]):
		for k: String in kinds_of_item(String(it)):
			if is_tool(k) and not out.has(k):
				out.append(k)
	return out


## Adds a group unless it is empty or one with the same kinds is there already.
static func _add_group(list: Array, g: Array) -> void:
	if g.is_empty():
		return
	var s := g.duplicate()
	s.sort()
	for h: Array in list:
		var t := h.duplicate()
		t.sort()
		if t == s:
			return
	list.append(g)


static func _action_requires(id: String) -> Dictionary:
	if _acts.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/survival/actions.json"))
		var list: Variant = (d as Dictionary).get("actions", []) if d is Dictionary else []
		for a: Variant in (list as Array if list is Array else []):
			if a is Dictionary:
				_acts[String(a.get("id", ""))] = a.get("requires", {}) if a.get("requires") is Dictionary else {}
		_acts["_"] = {}
	return _acts.get(id, {})


static func _recipe_tools(id: String) -> Array:
	if id == "":
		return []
	if _rcps.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/survival/recipes.json"))
		var list: Variant = (d as Dictionary).get("recipes", []) if d is Dictionary else []
		for r: Variant in (list as Array if list is Array else []):
			if r is Dictionary:
				_rcps[String(r.get("id", ""))] = r.get("tools", []) if r.get("tools") is Array else []
		_rcps["_"] = []
	return _rcps.get(id, [])


# ================================================================ the pool
static func install(store: HouseholdStock) -> ToolPool:
	if store.pool == null:
		var p := ToolPool.new()
		p._stock = weakref(store)
		p.rng.randomize()
		store.pool = p
	return store.pool


## The pool of the household `w` (a SpouseCore) works for; null when it has none.
static func of(w: Object) -> ToolPool:
	if w == null:
		return null
	var s: Variant = w.get("stock")
	return (s as HouseholdStock).pool if s is HouseholdStock else null


static func wid(w: Variant) -> int:
	if w is int:
		return int(w)
	return int((w as Object).get("worker_id")) if w is Object else -1


func stock() -> HouseholdStock:
	return _stock.get_ref() as HouseholdStock if _stock != null else null


func worker(id: int) -> SpouseCore:
	var s := stock()
	return s.crew.by_id(id) if s != null else null


# ---------------------------------------------------------------- counting
func _held_n(id: int, kind: String) -> int:
	return ((held.get(id, {}) as Dictionary).get(kind, []) as Array).size()


func _claimed_by_others(id: int, kind: String) -> int:
	var n := 0
	for o: int in claims:
		if o != id:
			n += int((claims[o] as Dictionary).get(kind, 0))
	return n


## Units of `kind` in the containers and the house.
func in_store(kind: String) -> int:
	var k := resolve(kind)
	var s := stock()
	return (s.count(k) if s != null else 0) + (overflow.get(k, []) as Array).size()


## Free units of `kind` for worker `owner` (-1: anybody): in the containers, less what the others have claimed.
func available(kind: String, owner: Variant = -1) -> int:
	var k := resolve(kind)
	return maxi(in_store(k) - _claimed_by_others(wid(owner), k), 0)


## Everything the household owns of `kind`: in store and out with the workers.
func owned(kind: String) -> int:
	var k := resolve(kind)
	var n := in_store(k)
	for id: int in held:
		n += _held_n(id, k)
	return n


func held_by(w: Variant) -> Dictionary:
	var out := {}
	var h: Dictionary = held.get(wid(w), {})
	for k: String in h:
		if not (h[k] as Array).is_empty():
			out[k] = (h[k] as Array).size()
	return out


## {kind: {name, owned, store, out, claimed, worn, by {worker name: n}}} for every pool kind the household has or had.
func counts() -> Dictionary:
	var out := {}
	var all := kinds() + consumable_kinds()
	for k: String in all:
		var by := {}
		var worn := 0
		var out_n := 0
		for id: int in held:
			var units: Array = (held[id] as Dictionary).get(k, [])
			if units.is_empty():
				continue
			var w := worker(id)
			by[w.name if w != null else "#%d" % id] = units.size()
			out_n += units.size()
			for u: Dictionary in units:
				worn += 1 if _worn(k, u) else 0
		for wv: Variant in stored_wear.get(k, []):
			worn += 1 if float(wv) >= durability(k) * float(cfg().get("worn_at", 0.75)) and is_tool(k) else 0
		var cl := 0
		for id: int in claims:
			cl += int((claims[id] as Dictionary).get(k, 0))
		var st := in_store(k)
		if st + out_n == 0:
			continue
		out[k] = {"name": name_of(k), "owned": st + out_n, "store": st, "out": out_n, "claimed": cl, "worn": worn, "by": by}
	return out


func _worn(kind: String, u: Dictionary) -> bool:
	return is_tool(kind) and float(u.get("wear", 0.0)) >= durability(kind) * float(cfg().get("worn_at", 0.75))


# ---------------------------------------------------------------- into and out of the containers
## LEDGER: a worker's name for the store's ledger ("" none: the household).
func _who(id: int) -> String:
	var s := stock()
	return s.worker_name(id) if s != null else ""


## Up to `n` units of `kind` out of the house and the containers (the most worn first), with their wear.
func _take_units(kind: String, n: int, who := "", why := "") -> Array:
	var out := []
	var ov: Array = overflow.get(kind, [])
	while out.size() < n and not ov.is_empty():
		out.append(ov.pop_back())
	if ov.is_empty():
		overflow.erase(kind)
	var s := stock()
	if out.size() < n and s != null:
		_trim_wear(kind)
		var units := s.take_units(kind, n - out.size(), who, why)   # LEDGER
		var wl: Array = stored_wear.get(kind, [])
		wl.sort()
		for u: Variant in units:
			var unit: Dictionary = (u as Dictionary).duplicate(true) if u is Dictionary else {}
			unit["wear"] = float(wl.pop_back()) if not wl.is_empty() else 0.0
			out.append(unit)
		if wl.is_empty():
			stored_wear.erase(kind)
		else:
			stored_wear[kind] = wl
	return out


## Units back into the containers (the racks for rack kinds); what no container takes stays in the house.
func _put_units(kind: String, units: Array, who := "", why := "") -> void:
	if units.is_empty():
		return
	var s := stock()
	var n := s.put_units(kind, units, who, why) if s != null else 0   # LEDGER
	var wl: Array = stored_wear.get(kind, [])
	for i in units.size():
		var u: Dictionary = units[i]
		if i < n:
			if float(u.get("wear", 0.0)) > 0.0:
				wl.append(float(u.wear))
		else:
			if not overflow.has(kind):
				overflow[kind] = []
			(overflow[kind] as Array).append(u)
	if not wl.is_empty():
		stored_wear[kind] = wl


## The wear list is no longer than what the containers hold (the player took some out: the least worn went).
func _trim_wear(kind: String) -> void:
	var s := stock()
	var wl: Array = stored_wear.get(kind, [])
	if wl.is_empty() or s == null:
		return
	wl.sort()
	while wl.size() > s.count(kind):
		wl.pop_front()
	stored_wear[kind] = wl


## Things into the pool (a trader's, the start's, a worker's old kit): `n` new units of `kind`, or `units`.
func add(kind: String, n: int, units: Array = []) -> void:
	var k := resolve(kind)
	var list := units.duplicate(true)
	while list.size() < n:
		list.append({"wear": 0.0})
	_put_units(k, list, "", "the fort's stores")


# ---------------------------------------------------------------- lending
## What `needs` would take for the worker now: {ok, kit {kind: n}, fetch {kind: n not held yet}, reason}. What she holds
## already serves first; then the free units, the group's first kind first.
func resolve_needs(w: Variant, needs: Dictionary) -> Dictionary:
	var id := wid(w)
	var kit := {}
	var fetch := {}
	for g: Array in needs.get("need", []):
		var pick := _pick(id, g, kit, fetch)
		if pick == "":
			return {"ok": false, "kit": {}, "fetch": {}, "reason": "no %s free" % name_of(String(g[0])).to_lower()}
		_count_in(id, pick, 1, kit, fetch)
	for g: Array in needs.get("optional", []):
		var pick := _pick(id, g, kit, fetch)
		if pick != "":
			_count_in(id, pick, 1, kit, fetch)
	var use: Dictionary = needs.get("use", {})
	for k: String in use:
		var n := int(use[k])
		var have := _held_n(id, k) - int(kit.get(k, 0))
		if have + available(k, id) - int(fetch.get(k, 0)) < n:
			return {"ok": false, "kit": {}, "fetch": {}, "reason": "no %s left" % name_of(k).to_lower()}
		_count_in(id, k, n, kit, fetch)
	return {"ok": true, "kit": kit, "fetch": fetch, "reason": ""}


func _pick(id: int, g: Array, kit: Dictionary, fetch: Dictionary) -> String:
	for k: String in g:
		if _held_n(id, k) > int(kit.get(k, 0)):
			return k
	for k: String in g:
		if available(k, id) > int(fetch.get(k, 0)):
			return k
	return ""


func _count_in(id: int, k: String, n: int, kit: Dictionary, fetch: Dictionary) -> void:
	var before := int(kit.get(k, 0))
	kit[k] = before + n
	var from_held := clampi(_held_n(id, k) - before, 0, n)
	if n - from_held > 0:
		fetch[k] = int(fetch.get(k, 0)) + n - from_held


## Claims what `needs` takes for `job` (the containers keep it until she collects it); what she holds and the job does not
## take is due back. {ok, kit, fetch, reason}.
func claim(w: Variant, needs: Dictionary, job := "") -> Dictionary:
	var id := wid(w)
	var r := resolve_needs(id, needs)
	claims.erase(id)
	if not bool(r.ok):
		return r
	if not (r.fetch as Dictionary).is_empty():
		claims[id] = (r.fetch as Dictionary).duplicate()
	job_of[id] = job
	var back := []
	for k: String in held.get(id, {}):
		if _held_n(id, k) > int((r.kit as Dictionary).get(k, 0)):
			back.append(k)
	if back.is_empty():
		due.erase(id)
	else:
		due[id] = back
		if not walkers.has(id):
			_return_due(id)
	return r


## Takes what she has claimed out of the containers (her body is at them, or there is no body to walk). Kinds: only those.
func collect(w: Variant, only: Array = []) -> int:
	var id := wid(w)
	var c: Dictionary = claims.get(id, {})
	var got := 0
	for k: String in c.keys():
		if not only.is_empty() and not only.has(k):
			continue
		var jt := String(JobBook.job(String(job_of.get(id, ""))).get("text", ""))   # ("Hoeing the beds")
		var units := _take_units(k, int(c[k]), _who(id), "borrowed for %s" % jt.to_lower() if jt != "" else "borrowed")
		_hold_units(id, k, units)
		got += units.size()
		c.erase(k)
	if c.is_empty():
		claims.erase(id)
	return got


func _hold_units(id: int, k: String, units: Array) -> void:
	if units.is_empty():
		return
	if not held.has(id):
		held[id] = {}
	if not (held[id] as Dictionary).has(k):
		held[id][k] = []
	(held[id][k] as Array).append_array(units)


## Puts back what is due (the extra she held for another job), or only `kind`.
func _return_due(id: int, kind := "") -> void:
	var back: Array = due.get(id, [])
	var kit := _kit_for(id, String(job_of.get(id, "")))
	for k: String in back.duplicate():
		if kind != "" and k != kind:
			continue
		if not held.has(id):
			break
		var units: Array = (held[id] as Dictionary).get(k, [])
		var keep := mini(int(kit.get(k, 0)), units.size())
		var give := units.slice(keep)
		(held[id] as Dictionary)[k] = units.slice(0, keep)
		if ((held[id] as Dictionary)[k] as Array).is_empty():
			(held[id] as Dictionary).erase(k)
		_put_units(k, give, _who(id), "returned")
		back.erase(k)
	if back.is_empty():
		due.erase(id)
	else:
		due[id] = back
	if held.has(id) and (held[id] as Dictionary).is_empty():
		held.erase(id)


## What job `jid` takes of each kind for her (its needs, resolved against what she holds first).
func _kit_for(id: int, jid: String) -> Dictionary:
	if jid == "" or not JobBook.has(jid):
		return {}
	var n := needs_of(jid)
	var kit := {}
	var fetch := {}
	for g: Array in n.need:
		var p := _pick(id, g, kit, fetch)
		if p != "":
			_count_in(id, p, 1, kit, fetch)
	for g: Array in n.optional:
		var p := _pick(id, g, kit, fetch)
		if p != "":
			_count_in(id, p, 1, kit, fetch)
	for k: String in n.use:
		kit[k] = int(kit.get(k, 0)) + int(n.use[k])
	return kit


## Takes what `needs` asks at once (claim and collect: no walking). {ok, items {kind: n she now has for it}, reason}.
func checkout(w: Variant, needs: Dictionary) -> Dictionary:
	var id := wid(w)
	var r := resolve_needs(id, needs)
	if not bool(r.ok):
		return {"ok": false, "items": {}, "reason": String(r.reason)}
	var c: Dictionary = claims.get(id, {})
	for k: String in r.fetch:
		c[k] = int(c.get(k, 0)) + int(r.fetch[k])
	claims[id] = c
	collect(id, (r.fetch as Dictionary).keys())
	return {"ok": true, "items": (r.kit as Dictionary).duplicate(), "reason": ""}


## Everything she holds back where it belongs (and her claims let go). How many units went back.
func return_all(w: Variant) -> int:
	var id := wid(w)
	unload_core(id)
	claims.erase(id)
	due.erase(id)
	job_of.erase(id)
	_running.erase(id)
	var n := 0
	var h: Dictionary = held.get(id, {})
	for k: String in h:
		_put_units(k, h[k], _who(id), "returned")
		n += (h[k] as Array).size()
	held.erase(id)
	return n


func drop_claims(w: Variant) -> void:
	claims.erase(wid(w))


## TOOLS hook, abandon_plan(): a plan given up lets go of what it claimed.
static func let_go(w: SpouseCore) -> void:
	var p := of(w)
	if p != null:
		p.drop_claims(w)


# ---------------------------------------------------------------- HuntKit's source shape
func count(kind: String, owner: Variant) -> int:
	var k := resolve(kind)
	if is_pool(k):
		return available(k, owner)
	var s := stock()
	return s.free_count(kind, wid(owner)) if s != null else 0


func take(kind: String, n: int, owner: Variant) -> int:
	var k := resolve(kind)
	if is_pool(k):
		var id := wid(owner)
		var c: Dictionary = claims.get(id, {})
		var got := _take_units(k, mini(n, available(k, id)), _who(id), "used at work")
		_hold_units(id, k, got)
		if c.has(k):
			c[k] = maxi(int(c[k]) - got.size(), 0)
			if int(c[k]) == 0:
				c.erase(k)
		return got.size()
	var s := stock()
	return s.take_for(wid(owner), kind, n) if s != null else 0


func put_back(kind: String, n: int, owner: Variant) -> int:
	var k := resolve(kind)
	if is_pool(k):
		var id := wid(owner)
		var units: Array = (held.get(id, {}) as Dictionary).get(k, [])
		var give := units.slice(maxi(units.size() - n, 0))
		if held.has(id):
			held[id][k] = units.slice(0, units.size() - give.size())
			if (held[id][k] as Array).is_empty():
				(held[id] as Dictionary).erase(k)
		_put_units(k, give, _who(id), "put back")
		return give.size()
	var s := stock()
	return s.put(kind, n) if s != null else 0


## `n` of a consumable she holds are used up (the shot fired, the bait taken).
func spend(w: Variant, kind: String, n: int) -> int:
	var id := wid(w)
	var k := resolve(kind)
	var units: Array = (held.get(id, {}) as Dictionary).get(k, [])
	var m := mini(n, units.size())
	if m > 0:
		held[id][k] = units.slice(0, units.size() - m)
		if (held[id][k] as Array).is_empty():
			(held[id] as Dictionary).erase(k)
	return m


# ================================================================ the job runner (SpouseCore hooks)
## TOOLS hook, offer(): false (and why, for the Tasks tab) when the job's required tools are not free for her.
static func offer_ok(w: SpouseCore, job_id: String, o: Dictionary) -> bool:
	var p := of(w)
	if p == null:
		return true
	var n := needs_of(job_id)
	if (n.need as Array).is_empty() and (n.use as Dictionary).is_empty() and (n.optional as Array).is_empty():
		p._unblock(w.worker_id, job_id)
		return true
	var r := p.resolve_needs(w, n)
	if not bool(r.ok):
		if not p.blocked.has(w.worker_id):
			p.blocked[w.worker_id] = {}
		p.blocked[w.worker_id][job_id] = String(r.reason)
		return false
	p._unblock(w.worker_id, job_id)
	o["tools"] = r.kit
	return true


func _unblock(id: int, job_id: String) -> void:
	if blocked.has(id):
		(blocked[id] as Dictionary).erase(job_id)
		if (blocked[id] as Dictionary).is_empty():
			blocked.erase(id)


## TOOLS hook, plan(): she will do `job_id`: claim its tools; what she holds for another job is due back.
static func planned(w: SpouseCore, job_id: String) -> void:
	var p := of(w)
	if p != null:
		p.claim(w, needs_of(job_id), job_id)


## TOOLS hook, begin(): she has what the job takes (the claimed things collected here when her body did not fetch them).
static func ready(w: SpouseCore, job_id: String) -> bool:
	var p := of(w)
	if p == null:
		return true
	var id := w.worker_id
	var r := p.claim(w, needs_of(job_id), job_id)
	if not bool(r.ok):
		p._last_why[id] = String(r.reason)
		return false
	p._return_due(id)
	p.collect(id)
	var check := p.resolve_needs(id, needs_of(job_id))
	if not bool(check.ok) or not (check.fetch as Dictionary).is_empty():
		var k: String = (check.fetch as Dictionary).keys()[0] if not (check.fetch as Dictionary).is_empty() else ""
		p._last_why[id] = String(check.reason) if not bool(check.ok) else "no %s free" % name_of(k).to_lower()
		return false
	return true


var _last_why := {}


## TOOLS hook, begin(): why a job cannot be offered: the tool it waits for, else `idle` (the job's own reason).
static func blocked_why(w: SpouseCore, job_id: String, idle: String) -> String:
	var p := of(w)
	if p == null:
		return idle
	return String((p.blocked.get(w.worker_id, {}) as Dictionary).get(job_id, idle))


static func why(w: SpouseCore) -> String:
	var p := of(w)
	return String(p._last_why.get(w.worker_id, "no tool free")) if p != null else "no tool free"


## TOOLS hook, _minutes(): a timed job goes faster with an optional tool she holds.
static func speed_of(w: SpouseCore, job_id: String) -> float:
	var p := of(w)
	if p == null:
		return 1.0
	var f := 1.0
	var sp: Dictionary = needs_of(job_id).speed
	for k: String in sp:
		if p._held_n(w.worker_id, k) > 0:
			f *= float(sp[k])
	return f


## TOOLS hook, begin() before the survival action starts: what she holds goes into her core (the rules see the tool; the
## consumables are hers to use).
static func load_core(w: SpouseCore) -> void:
	var p := of(w)
	if p == null:
		return
	p.unload_core(w.worker_id)
	var id := w.worker_id
	var h: Dictionary = p.held.get(id, {})
	var tl := {}
	var cons := {}
	for k: String in h:
		var n := (h[k] as Array).size()
		var item := item_of(k)
		if n <= 0 or item == "" or w.core.data.item(item).is_empty():
			continue
		if is_consumable(k):
			var per := float(kind_row(k).get("qty", 1.0))
			cons[k] = [item, n, per, SurvivalInventory.count(w.core, item)]
			SurvivalInventory.add(w.core, item, n * per)
		else:
			tl[item] = float(tl.get(item, 0.0)) + float(n)
	for item: String in tl:
		SurvivalInventory.add(w.core, item, float(tl[item]))
	p._loaded[id] = tl
	p._cons[id] = cons


## Takes the borrowed things out of her core again: the tools as they went in; of the consumables what is left (whole units
## stay with her, a part unit is kept by the pool), the rest was used.
func unload_core(w: Variant) -> void:
	var id := wid(w)
	var sc := worker(id) if not (w is SpouseCore) else w as SpouseCore
	var tl: Dictionary = _loaded.get(id, {})
	var cons: Dictionary = _cons.get(id, {})
	_loaded.erase(id)
	_cons.erase(id)
	if sc == null or sc.core == null:
		return
	for item: String in tl:
		var q := minf(float(tl[item]), SurvivalInventory.count(sc.core, item))
		if q > 0.0:
			SurvivalInventory.remove(sc.core, item, q)
	for k: String in cons:
		var c: Array = cons[k]
		var item := String(c[0])
		var per := maxf(float(c[2]), 0.0001)
		var left := clampf(SurvivalInventory.count(sc.core, item) - float(c[3]), 0.0, float(c[1]) * per)
		if left > 0.0:
			SurvivalInventory.remove(sc.core, item, left)
		var units := floori(left / per + 0.0001)
		var used := int(c[1]) - units
		if used > 0:
			spend(id, k, used)
		var frac := left / per - float(units)
		if frac > 0.0001:
			partial[k] = float(partial.get(k, 0.0)) + frac
			if float(partial[k]) >= 1.0 - 0.0001:
				partial[k] = float(partial[k]) - 1.0
				_hold_units(id, k, [{"wear": 0.0}])


## TOOLS hook, _start(): a run of `job_id` is under way (its tools wear when it ends).
static func started(w: SpouseCore, job_id: String) -> void:
	var p := of(w)
	if p != null:
		p._running[w.worker_id] = job_id


## TOOLS hook, the end of a run (finished, stopped, cancelled): her core gives the borrowed things back; a run that worked
## (`worked`) wears the tools of its kit and may break one.
static func run_ended(w: SpouseCore, worked := true) -> void:
	var p := of(w)
	if p == null:
		return
	p.unload_core(w)
	if not p._running.has(w.worker_id):
		return
	var jid := String(p._running[w.worker_id])
	p._running.erase(w.worker_id)
	if worked:
		p.wear(w, jid)


## TOOLS hook, _cannot(): the job did not start: her core gives back, her claims go.
static func cannot(w: SpouseCore) -> void:
	var p := of(w)
	if p == null:
		return
	p.unload_core(w)
	p._running.erase(w.worker_id)
	p.claims.erase(w.worker_id)


## A run of `job_id` wore the tools of its kit she holds (one unit of each kind): a worn-out tool, or an unlucky one, breaks.
## The broken kinds.
func wear(w: Variant, job_id: String) -> Array:
	var id := wid(w)
	var out := []
	var kit := _kit_for(id, job_id)
	for k: String in kit:
		if not is_tool(k) or _held_n(id, k) <= 0:
			continue
		var units: Array = held[id][k]
		var u: Dictionary = units[0]
		var per := float(kind_row(k).get("wear_per_run", cfg().get("wear_per_run", 1.0)))
		u["wear"] = float(u.get("wear", 0.0)) + per
		if float(u.wear) >= durability(k) or rng.randf() < float(kind_row(k).get("break_chance", 0.0)):
			units.remove_at(0)
			if units.is_empty():
				(held[id] as Dictionary).erase(k)
			var sc := worker(id)
			var who := sc.name if sc != null else "#%d" % id
			var day := int(sc.core.state.minutes / 1440.0) if sc != null and sc.core != null else 0
			broken.append({"kind": k, "name": name_of(k), "by": who, "day": day})
			if broken.size() > 30:
				broken.pop_front()
			var t := line("broke")
			var text := t % [who, name_of(k).to_lower()] if t.count("%s") == 2 else "%s's %s breaks." % [who, name_of(k).to_lower()]
			journal.append(text)
			if sc != null:
				sc._note(text)
			out.append(k)
	return out


## TOOLS hook, sync(): her kit comes into the pool once; a dead worker's things go back; at the end of her day (and when she
## follows or waits) she puts back what she holds.
static func tick(w: SpouseCore) -> void:
	var p := of(w)
	if p == null:
		return
	var id := w.worker_id
	if String(p.kits.get(id, "")) != "pooled":
		p.adopt(w)
	if not p.held.has(id):
		return
	if w.core.is_dead():
		p.return_all(id)
		return
	if w.busy() or p.claims.has(id):
		return
	# her day goes on: an outside worker's by daylight, a home worker's while she is up
	if (w.role == "outside" and w.daylight()) or (w.role == "home" and w.awake()):
		return
	if p.walkers.has(id):
		var back: Array = []
		for k: String in p.held[id]:
			back.append(k)
		p.due[id] = back
		p.job_of.erase(id)
	else:
		p.return_all(id)


## A worker who leaves the household: what she holds goes back.
static func leave(w: SpouseCore) -> void:
	var p := of(w)
	if p != null:
		p.return_all(w)
		p.blocked.erase(w.worker_id)
		p.kits.erase(w.worker_id)


# ---------------------------------------------------------------- her own kit
## Her survival background's kit is not hers: only her clothes (and the personal items tools.json names) stay with her. A worker
## from before the pool (an old save) or a recruit brings the tools, weapons and consumables of it into the pool, once; the
## others' kits are simply not there.
func adopt(w: SpouseCore) -> void:
	var id := w.worker_id
	var state := String(kits.get(id, "new" if w.get("tool_kit_new") == true else ""))
	if state == "pooled":
		return
	var c := cfg()
	var wk: Dictionary = c.worker_kit
	var keep_cats: Array = wk.get("keep_cats", ["clothing"])
	var personal: Array = wk.get("personal", [])
	var bring := (state == "" and bool(c.get("legacy_bring", true))) or (state == "new" and not w.recruit.is_empty() and bool(c.get("recruits_bring", true)))
	var kept_personal := {}
	for st: Dictionary in w.core.state.inventory.duplicate():
		var item := String(st.id)
		var qty := float(st.qty)
		if keep_cats.has(w.core.data.item_cat(item)):
			continue
		if personal.has(item) and not kept_personal.has(item):
			kept_personal[item] = true
			if qty > 1.0:
				SurvivalInventory.remove(w.core, item, qty - 1.0)
				_bring_item(w, item, qty - 1.0, bring)
			continue
		SurvivalInventory.remove(w.core, item, qty)
		_bring_item(w, item, qty, bring)
	kits[id] = "pooled"


func _bring_item(w: SpouseCore, item: String, qty: float, bring: bool) -> void:
	if not bring or qty <= 0.0:
		return
	var ks := kinds_of_item(item)
	if not ks.is_empty():
		var k := String(ks[0])
		var per := float(kind_row(k).get("qty", 1.0)) if is_consumable(k) else 1.0
		var n := floori(qty / maxf(per, 0.0001) + 0.0001)
		if n > 0:
			if is_rack(k):
				var units := []
				for i in n:
					units.append({"wear": 0.0, "state": (kind_row(k).get("state", {}) as Dictionary).duplicate(true)})
				add(k, 0, units)
			else:
				add(k, n)
		return
	var pk := w.pack_kind_of(item)
	var s := stock()
	if pk != "" and s != null:
		var per2 := maxf(float(w.pack_item(pk).get("qty", 1.0)), 0.0001)
		var m := floori(qty / per2 + 0.0001)
		if m > 0:
			s.put(pk, m)


# ---------------------------------------------------------------- the start and the house
## A new game's pool into the fort's chests and racks (tools.json start), once each, when there are chests / racks.
## `force`: now, whatever the store is (tests, a store with no chests).
func seed_start(force := false) -> void:
	var s := stock()
	if s == null:
		return
	var st: Dictionary = cfg().start
	# only into the fort's own furnishing (FortPlan stamped it): never into a chest or rack the player built themselves
	# (a game or a test run without the furnished fort gets no start pool)
	var tree: Variant = s.get("tree")
	var bw := BuildWorld.of(tree, false) if tree is SceneTree else null
	if not force and (bw == null or not bw.stamped):
		return
	var chests_ok := force or not s.has_method("chests_ready") or bool(s.call("chests_ready"))
	var racks_ok := force or not s.has_method("racks_ready") or bool(s.call("racks_ready"))
	if not bool(seeded.get("chest", false)) and chests_ok:
		seeded["chest"] = true
		var ch: Dictionary = st.get("chest", {})
		for k: String in ch:
			add(k, int(ch[k]))
	if not bool(seeded.get("farm", false)) and chests_ok:
		# FARM: the fields' tools (the hoe job), once on their own: a game saved before them gets them too
		seeded["farm"] = true
		var fm: Dictionary = st.get("farm", {})
		for k: String in fm:
			add(k, int(fm[k]))
	if not bool(seeded.get("climb", false)) and chests_ok:
		# CLIMB: the workers' climbing stakes, once on their own: a game saved before them gets them too
		seeded["climb"] = true
		var cl: Dictionary = st.get("climb", {})
		for k: String in cl:
			add(k, int(cl[k]))
	if not bool(seeded.get("rack", false)) and racks_ok:
		seeded["rack"] = true
		var rk: Dictionary = st.get("rack", {})
		for k: String in rk:
			var units := []
			for sv: Variant in rk[k]:
				units.append({"wear": 0.0, "state": (sv as Dictionary).duplicate(true) if sv is Dictionary else {}})
			add(k, 0, units)


## Every couple of seconds (Household): the start pool once the fort is furnished; the house's things into a container.
func tick_house(dt: float) -> void:
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 2.0
	seed_start()
	var s := stock()
	if s != null:
		for w: SpouseCore in s.crew.workers:
			if w.core != null and w.core.is_dead() and held.has(w.worker_id):
				return_all(w)          # a dead worker's things come home
	for k: String in overflow.keys():
		var units: Array = overflow[k]
		overflow.erase(k)
		_put_units(k, units, "", "put away")


# ================================================================ saving
func save_data() -> Dictionary:
	var h := {}
	for id: int in held:
		h[str(id)] = (held[id] as Dictionary).duplicate(true)
	var ks := {}
	for id: int in kits:
		ks[str(id)] = kits[id]
	return {"v": 1, "held": h, "job_of": _str_keys(job_of), "stored_wear": stored_wear.duplicate(true), "partial": partial.duplicate(),
			"broken": broken.duplicate(true), "overflow": overflow.duplicate(true), "seeded": seeded.duplicate(), "kits": ks}


static func _str_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		out[str(k)] = d[k]
	return out


## `d` null or not a dictionary: a save from before the pool: the fort's things are the player's (nothing is put in), and the
## workers' kits come into the pool as they are next seen (adopt).
func load_data(d: Variant) -> void:
	claims = {}
	held = {}
	job_of = {}
	due = {}
	stored_wear = {}
	partial = {}
	broken = []
	overflow = {}
	blocked = {}
	kits = {}
	_loaded = {}
	_cons = {}
	_running = {}
	if not (d is Dictionary):
		seeded = {"chest": true, "rack": true}
		return
	var dd: Dictionary = d
	for key: String in (dd.get("held", {}) as Dictionary):
		var per: Dictionary = {}
		for k: String in (dd.held[key] as Dictionary):
			var units := []
			for u: Variant in (dd.held[key][k] as Array):
				units.append((u as Dictionary).duplicate(true) if u is Dictionary else {"wear": 0.0})
			per[k] = units
		held[int(key)] = per
	for key: String in (dd.get("job_of", {}) as Dictionary):
		job_of[int(key)] = String(dd.job_of[key])
	for k: String in (dd.get("stored_wear", {}) as Dictionary):
		stored_wear[k] = (dd.stored_wear[k] as Array).duplicate()
	for k: String in (dd.get("partial", {}) as Dictionary):
		partial[k] = float(dd.partial[k])
	broken = (dd.get("broken", []) as Array).duplicate(true)
	for k: String in (dd.get("overflow", {}) as Dictionary):
		overflow[k] = (dd.overflow[k] as Array).duplicate(true)
	var sd: Dictionary = dd.get("seeded", {})
	seeded = {"chest": bool(sd.get("chest", true)), "rack": bool(sd.get("rack", true))}
	for key: String in (dd.get("kits", {}) as Dictionary):
		kits[int(key)] = String(dd.kits[key])
