class_name StorageChest
extends Node3D
## A storage chest (the build piece "storage_chest"; user 2026-09-27: "a storage chest"): what is put in it stays in it,
## kept in the save (SaveParts building). E opens it (ChestScreen: the pack beside the chest, a click moves one, a right-
## click all of a kind); its lid swings open while it is open. It takes what the pack carries loose (materials, food,
## herbs, remedies, torches); not the worn gear and weapons (the loadout's kinds, with their state) nor the tools the
## player always has (the knife, flint and steel, the felling axe and the mattock).

const GROUP := &"storage_chests"
const KEEP_OUT := ["skinning_knife", "fire_steel", "felling_axe", "mattock"]
const LID_OPEN := deg_to_rad(-105.0)

## [{kind, count}] in the order they went in.
var items: Array = []
var interact_reach := 2.4
var open := false
var _lid: MeshInstance3D
var _lid_pivot: Node3D
static var _gear := {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS          # the lid swings while the game is paused behind the screen
	_lid_pivot = Node3D.new()
	_lid_pivot.name = "Lid"
	_lid_pivot.position = Vector3(0, BuildGeometry.CHEST_H - 0.07, -BuildGeometry.CHEST_D * 0.5)
	add_child(_lid_pivot)
	_lid = MeshInstance3D.new()
	_lid.mesh = BuildGeometry.chest_lid_mesh()
	_lid_pivot.add_child(_lid)


func _process(dt: float) -> void:
	var want := LID_OPEN if open else 0.0
	_lid_pivot.rotation.x = move_toward(_lid_pivot.rotation.x, want, dt * 4.0)


## Whether `kind` can go in a chest.
static func can_store(kind: String) -> bool:
	if kind == "" or kind in KEEP_OUT:
		return false
	if _gear.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/loadout/loadout_items.json"))
		var kinds: Variant = (d as Dictionary).get("kinds", {}) if d is Dictionary else {}
		for k in (kinds as Dictionary if kinds is Dictionary else {}):
			_gear[String(k)] = true
		_gear["_loaded"] = true
	return not _gear.has(kind)


## Whether this store takes `kind` (a chest: can_store; the smokehouse's larder: food only).
func accepts(kind: String) -> bool:
	return can_store(kind)


## The screen's heading.
func title() -> String:
	return "SMOKEHOUSE LARDER" if self is Smokehouse else "STORAGE CHEST"


func count_of(kind: String) -> int:
	for e: Dictionary in items:
		if String(e.kind) == kind:
			return int(e.count)
	return 0


func total() -> int:
	var n := 0
	for e: Dictionary in items:
		n += int(e.count)
	return n


## Up to `n` of `kind` from `inv` (a pack) into the chest. How many went in.
func put(inv: InventoryState, kind: String, n: int) -> int:
	if not accepts(kind):
		return 0
	var got := inv.take(kind, n)
	if got <= 0:
		return 0
	for e: Dictionary in items:
		if String(e.kind) == kind:
			e.count = int(e.count) + got
			return got
	items.append({"kind": kind, "count": got})
	return got


## Up to `n` of `kind` out of the chest into `inv`. How many came out.
func take(inv: InventoryState, kind: String, n: int) -> int:
	for i in items.size():
		var e: Dictionary = items[i]
		if String(e.kind) != kind:
			continue
		var got := mini(int(e.count), maxi(n, 0))
		e.count = int(e.count) - got
		if int(e.count) <= 0:
			items.remove_at(i)
		inv.add(kind, got)
		return got
	return 0


# --- E ---------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_position + global_basis * Vector3(0, BuildGeometry.CHEST_H, 0.1)


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func highlight_targets() -> Array:
	var p := get_parent() as BuiltPiece
	return p.highlight_targets() if p else []


func interact_prompt(_player: Node) -> String:
	if is_instance_valid(BuildMode.current) and BuildMode.current.active:
		return ""
	var n := total()
	return "Open the chest (%s)" % ("empty" if n == 0 else "%d thing%s in it" % [n, "" if n == 1 else "s"])


func interact(player: Node) -> void:
	if is_instance_valid(BuildMode.current) and BuildMode.current.active:
		return
	ChestScreen.open_for(player, self)


# --- The save --------------------------------------------------------------------------------------

func to_save() -> Array:
	return items.duplicate(true)


func from_save(a: Array) -> void:
	items.clear()
	for e in a:
		if e is Dictionary and int((e as Dictionary).get("count", 0)) > 0:
			items.append({"kind": String(e.kind), "count": int(e.count)})
