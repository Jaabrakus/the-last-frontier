class_name NpcLoot
extends PackDrop
## What a fallen fighter leaves (NpcFighter.die): a PackDrop of his things where he lies (his musket or axe, powder horn, lead,
## a little food: the faction's loot, data/npc/factions.json). E: "Search the <faction> (N things)" takes it all into the
## player's pack, as the dropped pack does. Not one of the player's own dropped packs: it keeps out of PackDrop.GROUP (the
## death rule's saves and marks of the player's pack), and food left in it is scavenged as in any pack (looked at every
## SCAVENGE_LOOK_S, not every frame: a raid leaves many). NpcSenses clears it long after when it lies untouched far from anyone.

signal taken(loot: NpcLoot)

const SCAVENGE_LOOK_S := 2.0

## Who it was ("French marine"); the prompt names him.
var label := "fallen"
var _look_acc := 0.0


func _ready() -> void:
	super()
	remove_from_group(PackDrop.GROUP)


func _exit_tree() -> void:
	NpcSenses.forget(self)


func _process(delta: float) -> void:
	_look_acc += delta
	if _look_acc >= SCAVENGE_LOOK_S:
		super(_look_acc)
		_look_acc = 0.0


func interact_prompt(_p: Node) -> String:
	if count() <= 0:
		return ""
	return "Search the %s (%d thing%s)" % [label.to_lower(), count(), "" if count() == 1 else "s"]


func interact(p: Node) -> bool:
	var n := count()
	var inv := InventoryState.from_player(p)
	for e in items:
		var d: Dictionary = e
		inv.add(String(d.get("kind", "")), int(d.get("count", 1)))
	p.set("inventory_pack", inv.pack.duplicate(true))
	items.clear()
	torches.clear()
	var it: Node = p.get("interactor")
	if it and it.has_method(&"notice"):
		it.call(&"notice", "You take what the %s carried (%d thing%s)" % [label.to_lower(), n, "" if n == 1 else "s"])
	taken.emit(self)
	remove_from_group(PlacedWeapon.GROUP)
	queue_free()
	return true
