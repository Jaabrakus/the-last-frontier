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
