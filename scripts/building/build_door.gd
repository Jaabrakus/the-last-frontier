class_name BuildDoor
extends Node3D
## The hung door of a log wall with a door, or the two leaves of a palisade gate (scripts/building/): a tap of E
## opens or shuts it. An interactable of PlayerInteractor (group PlacedWeapon.GROUP, the "any other interactable"
## contract: interact_point(), interact_prompt(), interact(), highlight_targets(), interact_reach,
## distance_from()). Each leaf is an AnimatableBody3D on a hinge node, so a shut door stops the player and an open
## one lets them through; it swings in (toward the piece's -Z: into the cabin, into the fort).

## Fraction of the swing per second.
const SWING_RATE := 1.6
## Leaves swing this far open (rad).
const OPEN_ANGLE := 1.75

var kind := "door"
var is_open := false
var interact_reach := 2.4
var _hinges: Array[Node3D] = []
var _open_yaw: Array[float] = []
var _meshes: Array[GeometryInstance3D] = []
var _bodies: Array[AnimatableBody3D] = []
var _t := 0.0
var _center := Vector3.ZERO


## The door of a "wall_door" or the gate of a "palisade_gate" in the piece's frame.
static func make(piece_type: String) -> BuildDoor:
	var d := BuildDoor.new()
	d.name = "Door"
	const G := preload("res://scripts/building/build_geometry.gd")
	if piece_type == "palisade_gate":
		d.kind = "gate"
		d.interact_reach = 3.0
		d._center = Vector3(0, 1.2, 0)
		var w := G.GATE_POST_X - G.GATE_POST * 0.5 - 0.015
		for s: float in [-1.0, 1.0]:
			d._add_leaf("gate_l" if s < 0.0 else "gate_r", Vector3(s * (w + 0.005), 0.0, -0.1), -s * OPEN_ANGLE,
					Vector3(-s * w * 0.5, 0.05 + G.GATE_LEAF_H * 0.5, 0.0), Vector3(w, G.GATE_LEAF_H, 0.12))
	else:
		d._center = Vector3(0, 1.0, 0)
		var w := G.DOOR_HALF * 2.0 - 0.06
		var hgt := G.DOOR_TOP - 0.08
		d._add_leaf("door", Vector3(-w * 0.5, 0.0, -0.06), OPEN_ANGLE, Vector3(w * 0.5, 0.03 + hgt * 0.5, 0.0), Vector3(w, hgt, 0.05))
	return d


## A leaf turning about its hinge line at `hinge_at`: the AnimatableBody3D is the hinge itself (it only follows
## changes of its own transform, not of a parent's).
func _add_leaf(mesh_kind: String, hinge_at: Vector3, open_yaw: float, box_center: Vector3, box_size: Vector3) -> void:
	var body := AnimatableBody3D.new()
	body.name = "Leaf%d" % _hinges.size()
	body.position = hinge_at
	body.sync_to_physics = true
	body.add_to_group(BuiltPiece.BODY_GROUP)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	cs.shape = box
	cs.position = box_center
	cs.set_meta(&"trav", {"no_traverse": true})
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "LeafMesh"
	mi.mesh = BuildGeometry.leaf_mesh(mesh_kind)
	body.add_child(mi)
	add_child(body)
	_hinges.append(body)
	_open_yaw.append(open_yaw)
	_meshes.append(mi)
	_bodies.append(body)


## The leaves' meshes where they hang shut, for a ghost: [[Mesh, Transform3D in the piece's frame]].
static func ghost_leaves(piece_type: String) -> Array:
	var d := make(piece_type)
	var out: Array = []
	for i in d._hinges.size():
		out.append([d._meshes[i].mesh, d._hinges[i].transform])
	d.free()
	return out


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)


func _physics_process(delta: float) -> void:
	var goal := 1.0 if is_open else 0.0
	if _t == goal:
		return
	_t = move_toward(_t, goal, delta * SWING_RATE)
	var e := smoothstep(0.0, 1.0, _t)
	for i in _hinges.size():
		_hinges[i].rotation.y = _open_yaw[i] * e


func set_open(v: bool, now := false) -> void:
	is_open = v
	if now:
		_t = 1.0 if v else 0.0
		for i in _hinges.size():
			_hinges[i].rotation.y = _open_yaw[i] * _t


func swing() -> float:
	return _t


func body_rids() -> Array[RID]:
	var out: Array[RID] = []
	for b in _bodies:
		out.append(b.get_rid())
	return out


# --- Interactable ------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_transform * _center


func distance_from(p: Vector3) -> float:
	var q := interact_point()
	return Vector2(q.x - p.x, q.z - p.z).length()


func interact_prompt(_player: Node) -> String:
	return "%s the %s" % ["Shut" if is_open else "Open", kind]


func interact(_player: Node) -> void:
	is_open = not is_open


func highlight_targets() -> Array:
	return _meshes.duplicate()
