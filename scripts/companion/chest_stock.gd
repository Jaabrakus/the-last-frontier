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
	if ToolPool.is_rack(kind):   # TOOLS: the weapons stand in the racks and barrels
		return ToolRacks.count(tree, kind)
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
	if ToolPool.is_rack(kind):   # TOOLS
		return ToolRacks.take(tree, home, kind, n).size()
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
	if ToolPool.is_rack(kind):   # TOOLS
		return ToolRacks.put(tree, home, kind, ToolRacks.plain_units(n))
	for c: StorageChest in _chests(true):
		if not c.accepts(kind):
			continue
		var inv := InventoryState.new()
		inv.add(kind, n)
		return c.put(inv, kind, n)
	return 0


# ---------------------------------------------------------------- TOOLS: the pool's things in the chests and racks
## Rack weapons come out with their state, chest kinds as plain units.
func take_units(kind: String, n: int) -> Array:
	if ToolPool.is_rack(kind):
		return ToolRacks.take(tree, home, kind, n)
	return super.take_units(kind, n)


func put_units(kind: String, units: Array) -> int:
	if ToolPool.is_rack(kind):
		return ToolRacks.put(tree, home, kind, units)
	return put(kind, units.size())


## The chest, rack or barrel a worker goes to: the nearest that holds `kind` (fetch) or takes it (putting back).
func spot_for(kind: String, fetch := true) -> Node3D:
	if ToolPool.is_rack(kind):
		return ToolRacks.spot(tree, home, kind, fetch)
	for c: StorageChest in _chests(true):
		if fetch and c.count_of(kind) > 0 or not fetch and c.accepts(kind):
			return c
	return null


## Whether the level has any storage chest (the fort is furnished) / weapon rack yet.
func chests_ready() -> bool:
	return not _chests().is_empty()


func racks_ready() -> bool:
	return not ToolRacks.racks(tree, home).is_empty()
