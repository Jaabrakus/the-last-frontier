class_name DroppedItem
extends Node3D
## Something of the pack's lying on the ground (user 2026-09-27: "tools can be losable"): a tool knocked out of the hands
## (PlayerRagdoll), say, or a stack dragged out of the bags onto the world (BagUI.drop_ground; the owner 2026-10-03,
## "WoW-style bags": "Drop 12 Venison?"). Its model (GatherModels: the felling axe, the mattock...; the bags' drops the
## model its icon is made from), and E (PlayerInteractor) puts it back in the pack: "Pick up the felling axe", with its
## `state` (a made thing's standard). A lost tool is the player's again then (GatherTools.found).
## Not kept in the save: a tool lost when the game is saved is the player's again on loading (GatherTools gives every
## tool it finds neither worn nor in the pack).

var kind := ""
var count := 1
var display_name := ""
var model: Node3D
## The pack stack's state it goes back with (StationPractice's standard; {} none).
var state := {}
var interact_reach := 2.3


## `n` of `k` lying at the model's place (the model built for its kind; a plain bundle when it has none).
static func make(k: String, n := 1, name_ := "") -> DroppedItem:
	var d := DroppedItem.new()
	d.name = "Dropped_" + k
	d.kind = k
	d.count = n
	d.display_name = name_ if name_ != "" else k.replace("_", " ")
	var m := GatherModels.build(k)
	if m == null:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, 0.12, 0.25)
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		m = mi
	d.model = m
	d.add_child(m)
	return d


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)


# --- E ---------------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_position + Vector3.UP * 0.1


func interact_prompt(_player: Node) -> String:
	return "Pick up the %s" % display_name if count == 1 else "Pick up %d %s" % [count, display_name]


func highlight_targets() -> Array:
	return model.find_children("*", "GeometryInstance3D", true, false) + ([model] if model is GeometryInstance3D else [])


func interact(player: Node) -> bool:
	var inv := InventoryState.from_player(player)
	if state.is_empty():
		inv.add(kind, count)
	else:
		inv._to_pack(kind, count, state)
	player.set("inventory_pack", inv.pack.duplicate(true))
	var g = player.get("gather")
	if g and g.has_method(&"found"):
		g.found(kind)
	queue_free()
	return true
