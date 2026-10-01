class_name ChestStock
extends HouseholdStock
## The household store as the level's storage chests (StorageChest, and the smokehouse's larder for food): counts sum over
## them, takes come from the nearest to `home` first, puts go to the nearest that accepts the kind. The raw venison hung in
## a smokehouse is being smoked, not stored: it is neither counted nor taken (so she does not cook it), and a smokehouse
## takes a put only when no chest does.

var tree: SceneTree
var home := Vector3.ZERO


var _chests_cache := []
var _chests_frame := -1


func _chests(smokehouses_last := false) -> Array:
	var out := []
	if tree == null:
		return out
	# (the nearest-first list, made once a frame: the planner asks for it hundreds of times)
	if not smokehouses_last and _chests_frame == Engine.get_process_frames():
		return _chests_cache.filter(func(c: Variant) -> bool: return is_instance_valid(c))
	for n in tree.get_nodes_in_group(StorageChest.GROUP):
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			out.append(n)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		if smokehouses_last and (a is Smokehouse) != (b is Smokehouse):
			return b is Smokehouse
		return a.global_position.distance_squared_to(home) < b.global_position.distance_squared_to(home))
	if not smokehouses_last:
		_chests_cache = out.duplicate()
		_chests_frame = Engine.get_process_frames()
	return out


## The chests' totals for this frame ({kind: n}; venison hung in a smokehouse not counted): the planner asks hundreds of counts a
## frame (a job's shortages, each kind), each had walked and sorted every chest (user 2026-10-01: "the game is burning hot"; the
## profiler: ChestStock.count 300 calls a frame). Made again each frame, or after a take or a put.
var _snap := {}
var _snap_frame := -1


func _totals() -> Dictionary:
	var f := Engine.get_process_frames()
	if f != _snap_frame:
		_snap_frame = f
		_snap = {}
		if tree != null:
			for n in tree.get_nodes_in_group(StorageChest.GROUP):
				if not is_instance_valid(n) or (n as Node).is_queued_for_deletion():
					continue
				var smoke := n is Smokehouse
				var seen := {}
				for e: Dictionary in (n as StorageChest).items:
					var k := String(e.kind)
					if (smoke and k == "venison") or seen.has(k):
						continue        # (a chest's first stack of a kind, as count_of reads it)
					seen[k] = true
					_snap[k] = int(_snap.get(k, 0)) + int(e.count)
	return _snap


func count(kind: String) -> int:
	if ToolPool.is_rack(kind):   # TOOLS: the weapons stand in the racks and barrels
		return ToolRacks.count(tree, kind)
	return int(_totals().get(kind, 0))


func all() -> Dictionary:
	var d := {}
	for c: StorageChest in _chests():
		for e: Dictionary in c.items:
			d[String(e.kind)] = int(d.get(String(e.kind), 0)) + int(e.count)
	return d


func take(kind: String, n: int, who := "", why := "") -> int:
	_snap_frame = -1
	if ToolPool.is_rack(kind):   # TOOLS
		return ToolRacks.take(tree, home, kind, n).size()
	var got := 0
	var inv := InventoryState.new()
	for c: StorageChest in _chests():
		if got >= n:
			break
		if kind == "venison" and c is Smokehouse:
			continue
		got += c.take(inv, kind, n - got, who, why)   # LEDGER: each chest notes its own
	return got


func put(kind: String, n: int, who := "", why := "") -> int:
	_snap_frame = -1
	if n <= 0:
		return 0
	if ToolPool.is_rack(kind):   # TOOLS
		return ToolRacks.put(tree, home, kind, ToolRacks.plain_units(n))
	for c: StorageChest in _chests(true):
		if not c.accepts(kind):
			continue
		var inv := InventoryState.new()
		inv.add(kind, n)
		return c.put(inv, kind, n, who, why)
	return 0


## LEDGER: the last `n` goings in and out of the household's chests together, newest first.
func recent(n: int) -> Array:
	var ls := []
	for c: StorageChest in _chests():
		ls.append(c.ledger)
	return StoreLedger.recent(ls, n)


# ---------------------------------------------------------------- TOOLS: the pool's things in the chests and racks
## Rack weapons come out with their state, chest kinds as plain units.
func take_units(kind: String, n: int, who := "", why := "") -> Array:
	if ToolPool.is_rack(kind):
		return ToolRacks.take(tree, home, kind, n)
	return super.take_units(kind, n, who, why)


func put_units(kind: String, units: Array, who := "", why := "") -> int:
	if ToolPool.is_rack(kind):
		return ToolRacks.put(tree, home, kind, units)
	return put(kind, units.size(), who, why)


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
