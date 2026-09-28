class_name TandemPoseMannequin
extends Node3D
## Stand-in body for the standalone demo and the tests: an instance of the clip scene (Actor_B
## skeleton + AnimationPlayer) drawn as rods and balls between the joints. In Frontier the actor is
## Actor_B.tscn with CharacterBodyMesh.attach instead; YogaMat only needs the AnimationPlayer.

## A scene with a Skeleton3D and an AnimationPlayer holding the clips (e.g. the yoga .glb).
@export var scene: PackedScene
@export var color := Color(0.85, 0.55, 0.35)

## [from bone, to bone, radius]
const RODS := [
	["pelvis", "spineb", 0.11], ["spineb", "spined", 0.12], ["spined", "neck", 0.1], ["neck", "heada", 0.045],
	["pelvis", "l_upper_leg", 0.08], ["pelvis", "r_upper_leg", 0.08],
	["l_upper_leg", "l_knee", 0.07], ["l_knee", "l_ankle", 0.05], ["l_ankle", "l_ball", 0.04],
	["r_upper_leg", "r_knee", 0.07], ["r_knee", "r_ankle", 0.05], ["r_ankle", "r_ball", 0.04],
	["spined", "l_clavicle", 0.06], ["l_clavicle", "l_shoulder", 0.05], ["l_shoulder", "l_elbow", 0.045],
	["l_elbow", "l_wrist", 0.037], ["l_wrist", "l_middleb", 0.03],
	["spined", "r_clavicle", 0.06], ["r_clavicle", "r_shoulder", 0.05], ["r_shoulder", "r_elbow", 0.045],
	["r_elbow", "r_wrist", 0.037], ["r_wrist", "r_middleb", 0.03],
]

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var _parts: Array = []                 # [bone a, bone b, rod, ball]
var _head: MeshInstance3D
var _head_bones := Vector2i(-1, -1)


func _ready() -> void:
	process_priority = 100             # after the session has advanced the animation
	if scene == null:
		return
	var inst := scene.instantiate()
	add_child(inst)
	skeleton = inst.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	animation_player = inst.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 1.0
	rod_mesh.bottom_radius = 1.0
	rod_mesh.height = 1.0
	rod_mesh.radial_segments = 12
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 1.0
	ball_mesh.height = 2.0
	for r: Array in RODS:
		var a := skeleton.find_bone(r[0])
		var b := skeleton.find_bone(r[1])
		if a < 0 or b < 0:
			continue
		_parts.append([a, b, _mesh(rod_mesh, mat), _mesh(ball_mesh, mat), float(r[2])])
	_head = _mesh(ball_mesh, mat)
	_head_bones = Vector2i(skeleton.find_bone("heada"), skeleton.find_bone("headb"))
	_update()


func _process(_delta: float) -> void:
	_update()


func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	add_child(m)
	return m


func _update() -> void:
	if skeleton == null:
		return
	var sk := skeleton.global_transform
	for p: Array in _parts:
		var a: Vector3 = sk * skeleton.get_bone_global_pose(p[0]).origin
		var b: Vector3 = sk * skeleton.get_bone_global_pose(p[1]).origin
		var r: float = p[4]
		var rod: MeshInstance3D = p[2]
		var d := b - a
		var span := d.length()
		if span < 1e-4:
			rod.visible = false
			continue
		rod.visible = true
		var y := d / span
		var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		rod.global_transform = Transform3D(Basis(x * r, y * span, x.cross(y).normalized() * r), (a + b) * 0.5)
		(p[3] as MeshInstance3D).global_transform = Transform3D(Basis.from_scale(Vector3.ONE * r), b)
	if _head_bones.x >= 0 and _head_bones.y >= 0:
		var h: Vector3 = sk * skeleton.get_bone_global_pose(_head_bones.x).origin
		var t: Vector3 = sk * skeleton.get_bone_global_pose(_head_bones.y).origin
		_head.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.1), h.lerp(t, 0.6))
