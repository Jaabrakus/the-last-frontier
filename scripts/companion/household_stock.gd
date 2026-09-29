class_name HouseholdStock
extends RefCounted
## What the household keeps at home, by pack kind (InventoryState kinds): the store the spouse cooks from, eats from and
## puts her work into. This base holds a plain dictionary (tests, and a home with no chest yet); ChestStock reads the
## level's storage chests.

var kinds := {}
## LEDGER: this store's own memory of what went in and out while it has no chests (StoreLedger); ChestStock's chests keep
## their own.
var ledger: Array = []


func count(kind: String) -> int:
	return int(kinds.get(kind, 0))


func all() -> Dictionary:
	return kinds.duplicate()


## Up to `n` of `kind` out of the store; how many came out. `who` took it, for `why` (the ledger: StoreLedger).
func take(kind: String, n: int, who := "", why := "") -> int:
	var got := mini(count(kind), maxi(n, 0))
	if got > 0:
		kinds[kind] = count(kind) - got
		if int(kinds[kind]) <= 0:
			kinds.erase(kind)
		ledger = StoreLedger.add(ledger, null, who, kind, -got, why)
	return got


## `n` of `kind` into the store; how many went in.
func put(kind: String, n: int, who := "", why := "") -> int:
	if n <= 0:
		return 0
	kinds[kind] = count(kind) + n
	ledger = StoreLedger.add(ledger, null, who, kind, n, why)
	return n


## LEDGER: a worker's name by her id (the crew's), for the ledger; "" when there is none.
func worker_name(owner: int) -> String:
	if crew != null:
		for w: SpouseCore in crew.workers:
			if w.worker_id == owner:
				return w.name
	return ""


## LEDGER: the last `n` goings in and out of the store, newest first (StoreLedger entries).
func recent(n: int) -> Array:
	return StoreLedger.recent([ledger], n)


# ---------------------------------------------------------------- TOOLS: the tool pool's things
## The household's tool pool (scripts/companion/tool_pool.gd; null: this household has no pool and its workers keep their own
## kits). It counts what the store holds of its kinds and lends them to the workers, on this store's reservations.
var pool: ToolPool = null


## Up to `n` units of `kind` out of the store as unit records ([{}]; a rack weapon carries {"state"}); the units taken.
func take_units(kind: String, n: int, who := "", why := "") -> Array:
	var out := []
	for i in take(kind, n, who, why):
		out.append({})
	return out


## Units of `kind` (as take_units gave them) back into the store; how many went in.
func put_units(kind: String, units: Array, who := "", why := "") -> int:
	return put(kind, units.size(), who, why)


## The place a worker walks to for `kind` (to take it: `fetch`, or to put it back): a Node3D, or null (no place to walk to).
func spot_for(_kind: String, _fetch := true) -> Node3D:
	return null


# ---------------------------------------------------------------- reservations
## What the workers who share this store have claimed for the work they are about to do or doing: units of a kind
## ("k:venison") and stations or carcasses ("s:carcass:1234"), by worker id. A worker plans and works around the
## others' claims (free_count, site_free) so two of them never take the same units or the same station.
var reserved := {}
## The workers of this household (HouseholdCrew), for the totals the targets and shared stations need.
var crew: HouseholdCrew = HouseholdCrew.new()


func reserve(owner: int, key: String, n := 1) -> void:
	if n <= 0:
		return
	var r: Dictionary = reserved.get(key, {})
	r[owner] = int(r.get(owner, 0)) + n
	reserved[key] = r


func reserve_kind(owner: int, kind: String, n: int) -> void:
	reserve(owner, "k:" + kind, n)


## Drops everything `owner` has claimed.
func release(owner: int) -> void:
	for key: String in reserved.keys():
		var r: Dictionary = reserved[key]
		r.erase(owner)
		if r.is_empty():
			reserved.erase(key)


func held_by_others(owner: int, key: String) -> int:
	var n := 0
	for o: Variant in (reserved.get(key, {}) as Dictionary):
		if int(o) != owner:
			n += int(reserved[key][o])
	return n


func held_by(owner: int, key: String) -> int:
	return int((reserved.get(key, {}) as Dictionary).get(owner, 0))


## The units of `kind` that `owner` may plan on: what is in the store less what the others have claimed.
func free_count(kind: String, owner: int) -> int:
	return maxi(count(kind) - held_by_others(owner, "k:" + kind), 0)


## Up to `n` of `kind` for `owner`, never units the others have claimed; how many came out.
func take_for(owner: int, kind: String, n: int, who := "", why := "") -> int:
	return take(kind, mini(n, free_count(kind, owner)), who, why)


func site_free(owner: int, key: String) -> bool:
	return held_by_others(owner, key) == 0
