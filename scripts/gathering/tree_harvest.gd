class_name TreeHarvest
extends RefCounted
## The canoe's raw materials from standing trees (data/boats/parts.json "harvest"; user 2026-09-29: "gathering first so you can build a
## real boat from scratch"): hold E at a tree for the list (GatherTarget) and it adds what the tree gives besides its timber: a sheet of
## birch bark peeled, pine pitch tapped, the roots of a pine or a hemlock dug for wattap. Each takes a tool and a few seconds of
## kneeling work (SurvivalBridge.work) and puts its yield in the pack; a tree gives only so much (its limit), counted per tree for
## the session, as felled trees are (nothing here is saved: a new game grows the forest back).
##   TreeHarvest.actions(tools)      [{id, text}] for the target in front of the player
##   TreeHarvest.do(id, tools)       starts it (the work, then the yield)
## Also the tool test the boat stand's parts share (has_any).

## "tree:i:action" -> how many times it has been used.
static var used := {}


static func cfg() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/boats/parts.json"))
	return d if d is Dictionary else {}


## Does the player have any of `ids`: an "item." id in the survival kit, "gather:x" a gathering tool, else a pack kind.
static func has_any(player: Node, tools: GatherTools, ids: Array) -> bool:
	if ids.is_empty():
		return true
	var core: SurvivalCore = null
	var b := SurvivalBridge.find(player.get_tree()) if player != null and player.is_inside_tree() else null
	if b != null:
		core = b.core
	for id: String in ids:
		if id.begins_with("gather:"):
			if tools != null and tools.owns(id.substr(7)):
				return true
		elif id.begins_with("item."):
			if core != null and SurvivalInventory.count(core, id) > 0.0:
				return true
		elif pack_count(player, id) > 0:
			return true
	return false


static func pack_count(player: Node, kind: String) -> int:
	if player == null:
		return 0
	return InventoryState.from_player(player).pack_count(kind)


static func pack_add(player: Node, kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	inv.add(kind, n)
	player.set("inventory_pack", inv.pack.duplicate(true))


static func pack_take(player: Node, kind: String, n: int) -> int:
	var inv := InventoryState.from_player(player)
	var got := inv.take(kind, n)
	player.set("inventory_pack", inv.pack.duplicate(true))
	return got


static func _key(target: Dictionary, id: String) -> String:
	return "tree:%d:%s" % [int(target.get("i", -1)), id]


## What the tree in front of the player offers [{id, text}]: only the actions of its species (the tool is asked when it is tried).
static func actions(tools: GatherTools) -> Array:
	var out: Array = []
	if tools == null or tools.target.is_empty() or String(tools.target.get("type", "")) != "tree":
		return out
	var sp := String(tools.target.get("species", ""))
	var h: Dictionary = cfg().get("harvest", {})
	for id: String in h:
		var a: Dictionary = h[id]
		if sp in (a.get("species", []) as Array):
			var left := int(a.get("limit", 1)) - int(used.get(_key(tools.target, id), 0))
			out.append({"id": id, "text": String(a.text) + ("" if left > 0 else " (nothing more to take)")})
	return out


## Tries action `id` on the target: the tool, what the tree has left, then the work; the yield goes to the pack when it ends.
## Returns what to tell ("" when the work began).
static func begin(id: String, tools: GatherTools, instant := false) -> String:
	var h: Dictionary = cfg().get("harvest", {})
	if tools == null or not h.has(id) or tools.target.is_empty() or String(tools.target.get("type", "")) != "tree":
		return "Nothing there to take."
	var a: Dictionary = h[id]
	var player: Node = tools.player
	if not (String(tools.target.get("species", "")) in (a.get("species", []) as Array)):
		return "That tree gives none."
	if int(used.get(_key(tools.target, id), 0)) >= int(a.get("limit", 1)):
		return String(a.get("spent", "Nothing more from this tree."))
	if not has_any(player, tools, a.get("tool", [])):
		return "You need a knife, a hatchet or an axe for that."
	var key := _key(tools.target, id)
	var finish := func() -> String:
		used[key] = int(used.get(key, 0)) + 1
		var told: Array[String] = []
		var gives: Dictionary = a.get("gives", {})
		for k: String in gives:
			pack_add(player, k, int(gives[k]))
			told.append("%d %s" % [int(gives[k]), InventoryState.name_of(k).to_lower()])
		return "You get %s." % ", ".join(told)
	var b := SurvivalBridge.find(player.get_tree()) if player != null and player.is_inside_tree() else null
	if instant or b == null or b.work == null:
		return String(finish.call())
	var pt: Vector3 = tools.target_point()
	if not b.work.begin(pt, "table", String(a.get("verb", "Working")), float(a.get("seconds", 6.0)), "", func(done: bool) -> void:
			if done:
				tools.call("_note", String(finish.call()))
			else:
				tools.call("_note", "You stop before it is done.")):
		return "You cannot work at it now."
	return ""


static func do(id: String, tools: GatherTools) -> void:
	var told := begin(id, tools)
	if told != "":
		tools.call("_note", told)
