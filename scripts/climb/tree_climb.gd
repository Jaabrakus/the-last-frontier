class_name TreeClimb
extends Node
## E on a tree, branch to branch (user 2026-10-03: "its easy to go up and down the tree like that but they should have to press e to
## climb up to the next branch or something"): the player's PlayerInteractor interactable (group PlacedWeapon.GROUP, the "any other
## interactable" contract), PlayerGrip doing the climbing (tree_offer, climb_up, climb_down):
##   "Climb up"    on foot at a tree's trunk: onto its first branch when it is in reach, else a shinny up the trunk to it ("No branch
##                 in reach" at a trunk with none); perched on a branch: onto the one above. The tap's.
##   "Climb down"  perched: down onto the branch below, or off the first ones down the trunk to the ground. In the hold-E list (the
##                 tap's only where there is no branch above); C is its key on a branch.
## On foot the tree's felling (GatherTarget) is the tap's while the player looks level at the trunk, the climb once they look up the
## tree (PlayerGrip.tree_offer's bias); on a branch the climb always is. The branch to climb to glows.

var grip: PlayerGrip
## The reach the interactor allows (from the chest to the trunk, across).
var interact_reach := 1.7
var _offer := {}
var _frame := -1


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)


## This physics frame's offer (PlayerGrip.tree_offer, asked once a frame).
func _now() -> Dictionary:
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_offer = grip.tree_offer() if grip != null and is_instance_valid(grip) else {}
	return _offer


func _mine(p: Node) -> bool:
	return grip != null and is_instance_valid(grip) and p == grip.player


func interact_point() -> Vector3:
	return _now().get("point", Vector3.INF)


func distance_from(p: Vector3) -> float:
	var o := _now()
	if o.is_empty():
		return INF
	if o.has("perched"):
		return 0.0
	var q: Vector3 = o.point
	return Vector2(q.x - p.x, q.z - p.z).length()


func interact_prompt(p: Node) -> String:
	if not _mine(p):
		return ""
	var o := _now()
	if o.has("up"):
		return "Climb up"
	return "Climb down" if o.has("down") else ""


## Only "Climb down" (no branch above): the hold-E list's, not the tap's.
func interact_hold_only() -> bool:
	return not _now().has("up")


func interact_bias() -> float:
	return float(_now().get("bias", 0.0))


func interact(p: Node) -> void:
	if _mine(p):
		grip.climb_up()


func interact_actions(p: Node) -> Array:
	if not _mine(p):
		return []
	var o := _now()
	var out: Array = []
	if o.has("up"):
		out.append({"id": "up", "text": "Climb up"})
	if o.has("down"):
		out.append({"id": "down", "text": "Climb down"})
	return out


func interact_action(p: Node, id: String) -> void:
	if not _mine(p):
		return
	if id == "down":
		grip.climb_down()
	else:
		grip.climb_up()


## The branch to climb to (built near the player: PerchBranches), nothing for a trunk with none.
func highlight_targets() -> Array:
	var up: Dictionary = _now().get("up", {})
	if not up.has("pr") or grip.perch == null:
		return []
	var m := grip.perch.branch_mesh(up.pr)
	return [m] if m != null else []
