class_name FortGate
extends RefCounted
## What is left of the classic fort's gate script: the fort's gate is a build-menu piece now (palisade_gate, stamped by
## FortPlan; its two leaves are BuildDoor's, E opens them) and the axe no longer chops through the leaves (user 2026-09-28:
## "it is fine to lose the old axe-chopping system"). This thin wrapper stays so the tools that ask for "the fort's gate"
## (tools/showcase) still find it: find() gives the first built palisade gate's door, open / set_open() / interact() act on it.

var door: BuildDoor
var open: bool:
	get:
		return door != null and is_instance_valid(door) and door.is_open


## The fort's gate (the first built palisade gate), null when there is none.
static func find(tree: SceneTree) -> FortGate:
	var world := BuildWorld.of(tree, false)
	if world == null:
		return null
	for p in world.pieces():
		if p.type == "palisade_gate" and p.door != null:
			var g := FortGate.new()
			g.door = p.door
			return g
	return null


func set_open(v: bool, now := false) -> void:
	if door != null and is_instance_valid(door):
		door.set_open(v, now)


func interact(player: Node) -> void:
	if door != null and is_instance_valid(door):
		door.interact(player)
