class_name HouseholdStock
extends RefCounted
## What the household keeps at home, by pack kind (InventoryState kinds): the store the spouse cooks from, eats from and
## puts her work into. This base holds a plain dictionary (tests, and a home with no chest yet); ChestStock reads the
## level's storage chests.

var kinds := {}


func count(kind: String) -> int:
	return int(kinds.get(kind, 0))


func all() -> Dictionary:
	return kinds.duplicate()


## Up to `n` of `kind` out of the store; how many came out.
func take(kind: String, n: int) -> int:
	var got := mini(count(kind), maxi(n, 0))
	if got > 0:
		kinds[kind] = count(kind) - got
		if int(kinds[kind]) <= 0:
			kinds.erase(kind)
	return got


## `n` of `kind` into the store; how many went in.
func put(kind: String, n: int) -> int:
	if n <= 0:
		return 0
	kinds[kind] = count(kind) + n
	return n


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
func take_for(owner: int, kind: String, n: int) -> int:
	return take(kind, mini(n, free_count(kind, owner)))


func site_free(owner: int, key: String) -> bool:
	return held_by_others(owner, key) == 0
