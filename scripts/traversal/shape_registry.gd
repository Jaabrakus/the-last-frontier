class_name TravShapeRegistry
extends RefCounted
## Traversal metadata per collision SHAPE, never per body (design 14.2, T13/T14).
##
## Sources, in priority order:
##   1. registered descriptors (code-built content: TraversalWorld registers vegetation trunks,
##      rocks, logs, terrain chunks, fort colliders ...), keyed by the CollisionShape3D node;
##   2. authored meta `trav` (Dictionary) on the CollisionShape3D;
##   3. meta `trav` or the traversal groups on a StaticBody3D that owns exactly ONE shape (the
##      fort's pattern). A tagged body with several shapes is ignored with a warning.
## Groups: trav_climb, trav_hang, trav_beam, trav_ladder, trav_perch, trav_no_climb. The existing
## `trees` group is not a tag source, but a body in it with no descriptor of its own is a
## tree_trunk (gate "tree"): the vegetation's trunk colliders (FrontierVegetation, group "trees")
## end in a flat cap 2.7-3.2 m up inside the crown, and nothing registers them, so the free-run
## read every trunk top at 2.85-3.15 m as a 3 m ledge and climbed onto it (review 2026-09-24,
## tools/traversal/level_detection_sweep.gd: 363 of 4272 trunk approaches). Trees are climbed only by ladders.
##
## Physics query results carry (collider, shape index); resolve() maps them to the owning
## CollisionShape3D with shape_find_owner / shape_owner_get_owner (measured on Godot 4.7.2).

const GROUP_TAGS := ["trav_climb", "trav_hang", "trav_beam", "trav_ladder", "trav_perch", "trav_no_climb"]

var _desc := {}          ## CollisionShape3D instance id -> descriptor
var warnings: Array[String] = []


func register(shape_node: Node, descriptor: Dictionary) -> void:
	if shape_node == null:
		return
	_desc[shape_node.get_instance_id()] = descriptor


func unregister(shape_node: Node) -> void:
	if shape_node:
		_desc.erase(shape_node.get_instance_id())


func size() -> int:
	return _desc.size()


## The CollisionShape3D (or CollisionPolygon3D) owning shape index `shape_idx` of `collider`.
static func resolve(collider: Object, shape_idx: int) -> Node:
	if collider == null or not (collider is CollisionObject3D) or shape_idx < 0:
		return null
	var co := collider as CollisionObject3D
	var owner_id := co.shape_find_owner(shape_idx)
	if owner_id < 0:
		return null
	return co.shape_owner_get_owner(owner_id) as Node


## Descriptor for a query hit: {} when nothing applies. Always contains "tags" (Array).
func describe(collider: Object, shape_idx: int) -> Dictionary:
	var node := resolve(collider, shape_idx)
	return describe_node(node, collider)


func describe_node(node: Node, collider: Object = null) -> Dictionary:
	var d := {}
	if node != null and _desc.has(node.get_instance_id()):
		d = (_desc[node.get_instance_id()] as Dictionary).duplicate()
	elif node != null and node.has_meta("trav") and node.get_meta("trav") is Dictionary:
		d = (node.get_meta("trav") as Dictionary).duplicate()
	var body := collider as CollisionObject3D
	if body == null and node != null:
		body = node.get_parent() as CollisionObject3D
	if body != null:
		var single := body.get_shape_owners().size() == 1
		if d.is_empty() and body.has_meta("trav") and body.get_meta("trav") is Dictionary:
			if single:
				d = (body.get_meta("trav") as Dictionary).duplicate()
			else:
				_warn("body %s has `trav` meta but %d shapes; put the meta on the CollisionShape3D" % [body.name, body.get_shape_owners().size()])
		if d.is_empty() and body.is_in_group("trees"):
			d = {"kind": "tree_trunk"}
		var tags: Array = d.get("tags", []).duplicate()
		for g in GROUP_TAGS:
			if body.is_in_group(g):
				if single:
					if not tags.has(g):
						tags.append(g)
				else:
					_warn("body %s is in group %s but has several shapes" % [body.name, g])
		if node != null:
			for g in GROUP_TAGS:
				if node.is_in_group(g) and not tags.has(g):
					tags.append(g)
		d["tags"] = tags
	elif not d.has("tags"):
		d["tags"] = []
	return d


func _warn(msg: String) -> void:
	if not warnings.has(msg):
		warnings.append(msg)
		push_warning("TravShapeRegistry: " + msg)


## Shape gate (design 6.4): "" when geometric moves are allowed, else a `none` reason.
static func gate(d: Dictionary) -> String:
	var kind := str(d.get("kind", ""))
	var tags: Array = d.get("tags", [])
	if bool(d.get("no_traverse", false)) or tags.has("trav_no_climb") or kind == "no_traverse":
		return "excluded"
	if kind == "tree_trunk":
		return "tree"
	if bool(d.get("collider_truncated", false)):
		return "truncated"
	return ""


static func is_terrain(d: Dictionary) -> bool:
	return str(d.get("kind", "")) == "terrain" or str(d.get("overlap", "")) == "never"
