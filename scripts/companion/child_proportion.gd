class_name ChildProportion
extends SkeletonModifier3D
## A bigger head on a smaller body (child proportions), on any Actor_B skeleton: after the animation has posed the skeleton this sets the
## head bone's scale (`head_scale`, growth.json stage "head"). Used by ChildBody and by a junior worker's Spouse body
## (Spouse.set_proportions); the body's overall scale is the model node's.
##   var p := ChildProportion.attach(skeleton); p.head_scale = 1.3

const HEAD_BONE := "heada"

var head_scale := 1.0
var _bone := -2


static func attach(sk: Skeleton3D) -> ChildProportion:
	if sk == null:
		return null
	for c in sk.get_children():
		if c is ChildProportion:
			return c
	var p := ChildProportion.new()
	p.name = "ChildProportion"
	sk.add_child(p)
	return p


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bone == -2:
		_bone = sk.find_bone(HEAD_BONE)
	if _bone < 0:
		return
	sk.set_bone_pose_scale(_bone, Vector3.ONE * head_scale)
