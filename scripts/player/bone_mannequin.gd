class_name BoneMannequin
extends Node3D
## Stand-in body for an unskinned skeleton: a capsule between every main bone
## and its child, plus a head sphere and joint balls. Helper, twist, cloth and
## prop bones are skipped. Replace this with a real skinned mesh bound to the
## same skeleton when you have one.
##
## The capsules follow the live joint positions every frame. (The extracted
## animations use different bone-local axes than the rest pose, so offsets
## taken from the rest pose would not line up with the animated joints.)
## They update in Skeleton3D.skeleton_updated, i.e. on the final pose after the
## skeleton's modifiers (the AimStabilizer turns the upper body there; bone poses
## read in _process would be the pre-modifier pose; plan 6.11 / 8.2).

const SKIP := ["helper", "grp", "offset", "twist", "muscle", "shirt", "lift", "collider",
		"holster", "wrinkle", "prop", "breast", "chest", "trap", "scapula", "deltoid",
		"throat", "_end", "jacket", "backpack", "hair", "eye", "lid", "brow", "jaw",
		"cheek", "lip", "nose", "tongue", "teeth", "ear", "sneer", "squint", "mouth"]

@export var color := Color(0.62, 0.52, 0.42)
@export var joint_color := Color(0.35, 0.28, 0.22)
@export var thickness := {
	"spine": 0.085, "pelvis": 0.09, "neck": 0.045, "upper_leg": 0.07, "knee": 0.055,
	"ankle": 0.04, "shoulder": 0.05, "elbow": 0.04, "wrist": 0.022,
}
@export var default_radius := 0.012

var _sk: Skeleton3D
## [from_bone, to_bone, MeshInstance3D, length]
var _segments: Array = []
## [bone, MeshInstance3D]
var _joints: Array = []
var _head: MeshInstance3D
var _head_bone := -1
var _neck_bone := -1


func build(sk: Skeleton3D) -> void:
	_sk = sk
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	var joint_mat := StandardMaterial3D.new()
	joint_mat.albedo_color = joint_color
	for b in sk.get_bone_count():
		var name := sk.get_bone_name(b)
		if _skipped(name):
			continue
		var r := _radius(name)
		for c in sk.get_bone_children(b):
			if _skipped(sk.get_bone_name(c)):
				continue
			var length := sk.get_bone_rest(c).origin.length()
			if length < 0.01:
				continue
			var m := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			var cr := minf(r, length * 0.45)
			cap.radius = cr
			cap.height = length + cr * 2.0
			cap.radial_segments = 8
			cap.rings = 2
			m.mesh = cap
			m.material_override = mat
			sk.add_child(m)
			_segments.append([b, c, m, length])
		if r >= 0.04:
			var j := MeshInstance3D.new()
			var js := SphereMesh.new()
			js.radius = r * 0.9
			js.height = r * 1.8
			j.mesh = js
			j.material_override = joint_mat
			sk.add_child(j)
			_joints.append([b, j])
	_head_bone = sk.find_bone("heada")
	_neck_bone = sk.find_bone("neck")
	if _head_bone != -1:
		_head = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.095
		s.height = 0.23
		_head.mesh = s
		_head.material_override = mat
		sk.add_child(_head)
	if not sk.skeleton_updated.is_connected(_update):
		sk.skeleton_updated.connect(_update)
	_update()


## Meshes are children of the skeleton, so everything is in skeleton space.
func _update() -> void:
	if _sk == null:
		return
	for s in _segments:
		var a := _sk.get_bone_global_pose(s[0]).origin
		var b := _sk.get_bone_global_pose(s[1]).origin
		var m: MeshInstance3D = s[2]
		var d := b - a
		var len := d.length()
		if len < 0.001:
			m.visible = false
			continue
		m.visible = true
		m.transform = Transform3D(_align_y(d / len).scaled(Vector3(1, len / s[3], 1)), (a + b) * 0.5)
	for j in _joints:
		(j[1] as MeshInstance3D).position = _sk.get_bone_global_pose(j[0]).origin
	if _head:
		var h := _sk.get_bone_global_pose(_head_bone).origin
		var up := Vector3.UP
		if _neck_bone != -1:
			up = (h - _sk.get_bone_global_pose(_neck_bone).origin).normalized()
		_head.transform = Transform3D(_align_y(up), h + up * 0.08)


## Basis whose +Y points along `dir` (capsules are symmetric, so a bone
## pointing straight down just flips).
static func _align_y(dir: Vector3) -> Basis:
	if dir.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, dir))


func _skipped(bone: String) -> bool:
	var n := bone.to_lower()
	for s in SKIP:
		if s in n:
			return true
	return false


func _radius(bone: String) -> float:
	for key in thickness:
		if key in bone:
			return thickness[key]
	return default_radius
