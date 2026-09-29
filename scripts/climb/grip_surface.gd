class_name GripSurface
## What the player can grip (PlayerGrip, press G): a collider tagged with the meta "grip" (its kind: "rock" for a climbable
## rock face, "fur" for a giant's fur), or in the group "grip". Everything else is not grippable (a plain wall, a fence,
## the ground). A body that moves its gripped parts on a skeleton can offer `grip_parent(point) -> Node3D` (the node the
## grip's anchor goes under, e.g. a BoneAttachment3D); otherwise the anchor goes under the collider itself, so anything
## that moves the collider (an AnimatableBody3D, a bone-attached body) carries the climber with it.

const META := &"grip"


static func tag(body: CollisionObject3D, kind := "rock") -> void:
	body.set_meta(META, kind)


## The grip kind of a collider ("" when it cannot be gripped).
static func kind_of(o: Object) -> String:
	var n := o as Node
	if n == null or not is_instance_valid(n):
		return ""
	if n.has_meta(META):
		return str(n.get_meta(META))
	return "rock" if n.is_in_group(&"grip") else ""


static func is_grip(o: Object) -> bool:
	return kind_of(o) != ""


## The node a grip at `point` on `col` hangs from.
static func parent_for(col: Node, point: Vector3) -> Node3D:
	if col.has_method(&"grip_parent"):
		var p = col.call(&"grip_parent", point)
		if p is Node3D:
			return p
	return col as Node3D
