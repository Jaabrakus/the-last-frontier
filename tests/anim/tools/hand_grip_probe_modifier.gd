extends SkeletonModifier3D
## Test-only probe (tests/anim/tools/hand_grip_probe.gd): records, inside the skeleton's modifier
## pass, how far the weapon node's global transform is from the current prop bone pose, i.e.
## whether BoneAttachment3D has already moved the weapon for this frame when a modifier at this
## position runs. Changes no bone.

var player: Node
var samples := []     ## [lag_m, frame]
var calls := 0
var bone_target: Node3D     ## optional ModifierBoneTarget3D on the prop bone, checked the same way


func _process_modification() -> void:
	calls += 1
	var sk := get_skeleton()
	if sk == null or player == null or player.weapon == null or player.weapon.model == null:
		return
	var b := sk.find_bone("r_hand_prop_attachment")
	var off: Transform3D = player.musket_offset if String(player.weapon_key) == "musket" else Transform3D.IDENTITY
	var cur := sk.global_transform * sk.get_bone_global_pose(b) * off
	var tg := -1.0
	if bone_target:
		tg = (bone_target.global_transform * off).origin.distance_to(cur.origin)
	samples.append([player.weapon.model.global_transform.origin.distance_to(cur.origin), Engine.get_process_frames(), tg])
