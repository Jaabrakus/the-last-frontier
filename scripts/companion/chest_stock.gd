class_name ChestStock
extends HouseholdStock
## The household store as the level's storage chests (StorageChest, and the smokehouse's larder for food): counts sum over
## them, takes come from the nearest to `home` first, puts go to the nearest that accepts the kind.

var tree: SceneTree
var home := Vector3.ZERO


func _chests() -> Array:
	var out := []
	if tree == null:
		return out
	for n in tree.get_nodes_in_group(StorageChest.GROUP):
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			out.append(n)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(home) < b.global_position.distance_squared_to(home))
	return out


func count(kind: String) -> int:
	var n := 0
	for c: StorageChest in _chests():
		n += c.count_of(kind)
	return n


func all() -> Dictionary:
	var d := {}
	for c: StorageChest in _chests():
		for e: Dictionary in c.items:
			d[String(e.kind)] = int(d.get(String(e.kind), 0)) + int(e.count)
	return d


func take(kind: String, n: int) -> int:
	var got := 0
	var inv := InventoryState.new()
	for c: StorageChest in _chests():
		if got >= n:
			break
		got += c.take(inv, kind, n - got)
	return got


func put(kind: String, n: int) -> int:
	if n <= 0:
		return 0
	for c: StorageChest in _chests():
		if not c.accepts(kind):
			continue
		var inv := InventoryState.new()
		inv.add(kind, n)
		return c.put(inv, kind, n)
	return 0
