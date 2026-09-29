class_name ChestStock
extends HouseholdStock
## The household store as the level's storage chests (StorageChest, and the smokehouse's larder for food): counts sum over
## them, takes come from the nearest to `home` first, puts go to the nearest that accepts the kind. The raw venison hung in
## a smokehouse is being smoked, not stored: it is neither counted nor taken (so she does not cook it), and a smokehouse
## takes a put only when no chest does.

var tree: SceneTree
var home := Vector3.ZERO


func _chests(smokehouses_last := false) -> Array:
	var out := []
	if tree == null:
		return out
	for n in tree.get_nodes_in_group(StorageChest.GROUP):
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			out.append(n)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		if smokehouses_last and (a is Smokehouse) != (b is Smokehouse):
			return b is Smokehouse
		return a.global_position.distance_squared_to(home) < b.global_position.distance_squared_to(home))
	return out


func count(kind: String) -> int:
	var n := 0
	for c: StorageChest in _chests():
		if kind == "venison" and c is Smokehouse:
			continue
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
		if kind == "venison" and c is Smokehouse:
			continue
		got += c.take(inv, kind, n - got)
	return got


func put(kind: String, n: int) -> int:
	if n <= 0:
		return 0
	for c: StorageChest in _chests(true):
		if not c.accepts(kind):
			continue
		var inv := InventoryState.new()
		inv.add(kind, n)
		return c.put(inv, kind, n)
	return 0
