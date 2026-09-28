class_name GatherTarget
extends Node
## The gatherable in front of the player (GatherTools.target: a standing tree, a sapling, a felled trunk, a
## rock) as one E interactable for PlayerInteractor (group PlacedWeapon.GROUP, the "any other interactable"
## contract: interact_point(), interact_prompt(), interact(), highlight_targets(), interact_reach,
## distance_from()): the prompt says what E does ("E  Fell the white pine  4/12"), a tap of E draws the right
## tool if it is not in the hand and swings it once (holding LMB with the tool in the hand keeps swinging).

var tools: GatherTools
## The reach the interactor allows (the target's own reach plus the chest's height over the ground).
var interact_reach := 2.4


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)


func interact_point() -> Vector3:
	return tools.target_point() if tools else Vector3.INF


func distance_from(p: Vector3) -> float:
	if tools == null or tools.target.is_empty():
		return INF
	var q := tools.target_point()
	return Vector2(q.x - p.x, q.z - p.z).length()


func interact_prompt(_player: Node) -> String:
	return tools.prompt() if tools else ""


func interact(_player: Node) -> void:
	if tools:
		tools.use_target()


## Nothing glows: trees and rocks are instances in shared MultiMeshes, and a felled tree lit whole (crown and
## all) drowned the forest in the highlight.
func highlight_targets() -> Array:
	return []
