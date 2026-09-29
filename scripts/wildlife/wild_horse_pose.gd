class_name WildHorsePose
extends SkeletonModifier3D
## The wild horse's head carriage over its clips (WildHorse; user 2026-09-28, the wild horses): the horse's clips carry
## the head as a ridden horse does, so grazing (the neck down to the grass, the head brought back up so the muzzle
## meets it), dozing (low, slack) and the alert (up) are this pose over the idle. `neck_deg` / `head_deg`: how far the
## neck (in NECK_SHARE over its three bones) and the head are turned down (+) or up (-), about the model's X (the
## horse's left: every neck and head bone's X, assets/horse horse.glb); WildHorse eases them to the pose it wants.

const NECK := ["neck_1", "neck_2", "neck_3"]
const NECK_SHARE := [0.45, 0.35, 0.2]
const HEAD := "head"
## [neck, head] (deg, + down): grazing (the bit ~0.25 m off the ground over the idle, the face near upright:
## tests/wildlife/test_wild_horses.gd), the alert, dozing.
const GRAZE := Vector2(115.0, -88.0)
const ALERT := Vector2(-14.0, 6.0)
const DOZE := Vector2(30.0, -8.0)

var neck_deg := 0.0
var head_deg := 0.0

var _neck: Array[int] = []
var _head := -1


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or (absf(neck_deg) < 0.05 and absf(head_deg) < 0.05):
		return
	if _neck.is_empty():
		for nm: String in NECK:
			_neck.append(sk.find_bone(nm))
		_head = sk.find_bone(HEAD)
	for i in _neck.size():
		_turn(sk, _neck[i], neck_deg * float(NECK_SHARE[i]))
	_turn(sk, _head, head_deg)


## Bone `b` turned `deg` about the model's X at its own joint (the axis taken into its parent's frame).
static func _turn(sk: Skeleton3D, b: int, deg: float) -> void:
	if b < 0 or absf(deg) < 0.01:
		return
	var parent := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var axis := (pg.inverse() * Vector3.RIGHT).normalized()
	sk.set_bone_pose_rotation(b, Quaternion(axis, deg_to_rad(deg)) * sk.get_bone_pose_rotation(b))
