extends SkeletonModifier3D
## Test probe (not a game modifier): records the skeleton-space rotations of `bones` at its place in the
## modifier stack, i.e. the pose after every SkeletonModifier3D before it. StageProbe.insert() puts one
## before the first modifier and one after each, so a test can tell which modifier moved a bone
## (test_continuity `stages=1`: the per-stage speed of each counted frame's bone).
##
##   var probes := StageProbe.insert(sk, bone_indices)   # [{name, probe}], the tree's pose first
##   ...                                                  # after the skeleton update:
##   probes[k].probe.rots[i]                              # bone i after stage k
##   StageProbe.remove(probes)

## Bone indices to record.
var bones := PackedInt32Array()
## Skeleton-space rotations of `bones` at the last run (same order).
var rots: Array[Quaternion] = []


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	rots.resize(bones.size())
	for i in bones.size():
		rots[i] = sk.get_bone_global_pose(bones[i]).basis.get_rotation_quaternion()


## Adds a probe before the first modifier of `sk` and one after each modifier. Returns [{name, probe}] in
## stack order: "tree" (no modifier yet), then each modifier's node name (the pose after it).
static func insert(sk: Skeleton3D, p_bones: PackedInt32Array) -> Array:
	var mods: Array[Node] = []
	for c in sk.get_children():
		if c is SkeletonModifier3D:
			mods.append(c)
	var out := []
	var script: Script = load("res://tests/anim/lib/stage_probe.gd")
	var first: SkeletonModifier3D = script.new()
	first.name = "StageProbe_tree"
	first.bones = p_bones
	sk.add_child(first)
	sk.move_child(first, mods[0].get_index() if not mods.is_empty() else 0)
	out.append({"name": "tree", "probe": first})
	for m in mods:
		var p: SkeletonModifier3D = script.new()
		p.name = "StageProbe_" + String(m.name)
		p.bones = p_bones
		sk.add_child(p)
		sk.move_child(p, m.get_index() + 1)
		out.append({"name": String(m.name), "probe": p})
	return out


static func remove(probes: Array) -> void:
	for d: Dictionary in probes:
		var p: Node = d.probe
		if is_instance_valid(p):
			p.get_parent().remove_child(p)
			p.free()
