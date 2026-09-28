class_name WeaponBody
extends Area3D
## A melee weapon's body, for weapons meeting (user 2026-09-27: "if two weapons collide they both bounce back"): a
## capsule along the haft and a box round the head, on the weapons' own physics layer (LAYER), for another weapon's
## sweep (MeleeSweep) to strike. Whoever holds it answers: holder.clash(point, dir, by) (AxeMelee, SparringPartner),
## and a swing it is in stops and bounces back. Only there while its weapon is shown in the hand and in the parry
## (holder.guarding(); user 2026-09-27: "we dont need collision detection beside only the parry and blocks"):
## otherwise another's blows pass it by.

const LAYER := 1 << 17
const HAFT_R := 0.03

## Has clash(point: Vector3, dir: Vector3, by: WeaponBody): `dir` the way the other weapon was moving.
var holder: Object


## The body for a tool model (its knob at the origin, the haft +Y, the edge -Z; `head_y` where the head sits up it).
static func attach(model: Node3D, who: Object, head_y := 0.8) -> WeaponBody:
	var old := model.get_node_or_null("WeaponBody") as WeaponBody
	if old:
		old.holder = who
		return old
	var w := WeaponBody.new()
	w.name = "WeaponBody"
	w.holder = who
	w.collision_layer = LAYER
	w.collision_mask = 0
	w.monitoring = false
	w.monitorable = true
	var haft := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = HAFT_R
	cap.height = head_y + 0.04
	haft.shape = cap
	haft.position = Vector3(0, (head_y + 0.04) * 0.5, 0)
	w.add_child(haft)
	var head := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.05, 0.13, 0.24)
	head.shape = box
	head.position = Vector3(0, head_y, -0.06)
	w.add_child(head)
	model.add_child(w)
	return w


func _physics_process(_delta: float) -> void:
	var p := get_parent() as Node3D
	var on := p != null and p.is_visible_in_tree()
	if on and holder != null and is_instance_valid(holder) and holder.has_method(&"guarding"):
		on = bool(holder.guarding())
	collision_layer = LAYER if on else 0
