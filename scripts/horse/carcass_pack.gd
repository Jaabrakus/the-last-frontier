class_name CarcassPack
extends Node
## A kill across the saddle (user 2026-09-29: "saddle the carcass and head home"): a dead deer or buck laid belly down over
## the horse's back, its head and forelegs hanging down the horse's left side and its haunches and hind legs its right, and
## the horse led home (HuntHaul); or, behind the saddle across its hindquarters (the horse's passenger seat, meta sockets
## "passenger"), for a hunter who rides home in the saddle (user 2026-09-30: "they cannot ride the horse back?"). A child
## of the horse.
##
## The animal's own bones are posed for it once, from its rest pose (the death clip's pose kept, to be put back when it is
## laid down): the body bent over the saddle at the middle of its back (Torso), the rear half hanging REAR_DEG below level and the front
## FRONT_DEG, the neck NECK_DEG more, each leg hanging straight down. Each tick after the horse has moved the animal is put on
## the seat (Horse.get_saddle_transform, SEAT_DROP below it), its spine across the horse, so it sways and bobs with the
## horse's back. Its collider is off and the wildlife spawner leaves it alone while it rides (meta on_chain, as on the rope).
##   var p := CarcassPack.pack(carcass, horse, behind)   # null: not a carcass the horse can take (CarcassLoad.haulable)
##   p.release()                                # laid on the ground at the horse's left; returns the animal

## The seat below the saddle attach point (tools/horse/anatomy.py SEAT_DROP).
const SEAT_DROP := 0.125
const REAR_DEG := 62.0
const FRONT_DEG := 58.0
const NECK_DEG := 25.0
## The bend's bone, the neck, and each leg's top and next bone (the leg hangs along top -> next).
const BEND := ["Torso", "Torso2"]
const NECK := "Neck1"
const LEGS := [["FrontUpperLeg.L", "FrontLowerLeg.L"], ["FrontUpperLeg.R", "FrontLowerLeg.R"],
		["BackLeg.L", "BackLowerLeg.L"], ["BackLeg.R", "BackLowerLeg.R"]]
## Laid down this far out from the horse's middle on its left (m).
const LAY_M := 1.3

var horse: Horse
var animal: Node3D
## Behind the saddle (the rider in it), not across it.
var behind := false
## The animal's frame on the saddle frame.
var local := Transform3D()
var _sk: Skeleton3D
var _ap: AnimationPlayer
var _ap_active := true
var _saved := []                    ## per bone [position, rotation, scale] as it lay (its death pose)
var _layers := [0, 0]
var _was_interactable := false


## Lays dead animal `a` across `h`'s saddle. Null when it cannot be taken.
static func pack(a: Node3D, h: Horse, behind_saddle := false) -> CarcassPack:
	if a == null or h == null or not CarcassLoad.haulable(a):
		return null
	var p := CarcassPack.new()
	p.name = "CarcassPack"
	p.horse = h
	p.animal = a
	p.behind = behind_saddle
	h.add_child(p)
	p._take()
	return p


func _ready() -> void:
	process_physics_priority = 12       # after the horse has moved


func _take() -> void:
	var a := animal
	a.set_meta(&"on_chain", true)
	a.set_meta(&"packed", true)
	_was_interactable = a.is_in_group(PlacedWeapon.GROUP)
	a.remove_from_group(PlacedWeapon.GROUP)
	if a is CollisionObject3D:
		var co := a as CollisionObject3D
		_layers = [co.collision_layer, co.collision_mask]
		co.collision_layer = 0
		co.collision_mask = 0
	_ap = CarcassLoad._anim_player(a)
	if _ap:
		_ap_active = _ap.active
		_ap.active = false
	_sk = a.get(&"_skel") as Skeleton3D
	if _sk == null:
		var found := a.find_children("*", "Skeleton3D", true, false)
		_sk = found[0] as Skeleton3D if not found.is_empty() else null
	var pivot_r := Vector3.ZERO
	var fwd_r := Vector3.FORWARD
	if _sk:
		_saved = []
		for i in _sk.get_bone_count():
			_saved.append([_sk.get_bone_pose_position(i), _sk.get_bone_pose_rotation(i), _sk.get_bone_pose_scale(i)])
		var m := a.global_transform.affine_inverse() * _sk.global_transform   # the skeleton in the animal's frame
		_drape(m)
		var bend := _bone(BEND)
		var head := _bone(["Head", "Neck3", "Neck2"])
		var root := 0
		if bend >= 0:
			pivot_r = m * _sk.get_bone_global_pose(bend).origin
		# (the way the head points as it stands, from its rest)
		if head >= 0:
			var hd := m.basis * (_sk.get_bone_global_rest(head).origin - _sk.get_bone_global_rest(root).origin)
			hd.y = 0.0
			if hd.length() > 1e-4:
				fwd_r = hd.normalized()
	# its head to the horse's left (the saddle frame's +x), its back up
	var src := Basis(fwd_r, Vector3.UP, fwd_r.cross(Vector3.UP))
	var dst := Basis(Vector3.RIGHT, Vector3.UP, Vector3.RIGHT.cross(Vector3.UP))
	var b := dst * src.inverse()
	var r := 0.18
	var d: Variant = a.get(&"data")
	if d is Dictionary and (d as Dictionary).has("body"):
		r = float(d.body[0])
	var at := Vector3(0.0, -SEAT_DROP + r * 0.9, -0.05)
	if behind:
		# (the passenger seat: behind the saddle and a little lower, over the croup; saddle-relative from the sockets)
		var socks: Dictionary = horse.meta.get("sockets", {})
		var ps: Array = socks.get("passenger", [0.0, 1.4831, -0.39])
		var sd: Array = socks.get("saddle", [0.0, 1.4961, 0.0])
		at += Vector3(float(ps[0]) - float(sd[0]), float(ps[1]) - float(sd[1]), float(ps[2]) - float(sd[2]) - 0.08)
	local = Transform3D(b, at - b * pivot_r)
	_place()


## The animal's bones hung over the saddle, from its rest pose. `m`: the skeleton in the animal's frame.
func _drape(m: Transform3D) -> void:
	_sk.reset_bone_poses()
	var bend := _bone(BEND)
	if bend < 0:
		return
	# its lateral axis and its down, in the skeleton's space
	var inv := m.basis.inverse()
	var down := (inv * Vector3.DOWN).normalized()
	var head := _bone(["Head", "Neck3", "Neck2"])
	var fwd := Vector3.FORWARD
	if head >= 0:
		fwd = _sk.get_bone_global_pose(head).origin - _sk.get_bone_global_pose(0).origin
		fwd = (fwd - down * fwd.dot(down)).normalized()
	var side := fwd.cross(-down).normalized()          # its right (a turn about it by + lifts the nose)
	var pivot := _sk.get_bone_global_pose(bend).origin
	# the whole of it tipped nose up about the bend: the rear hangs
	_turn(0, Basis(side, deg_to_rad(REAR_DEG)), pivot)
	# the front bent down over the bend
	_turn(bend, Basis(side, -deg_to_rad(REAR_DEG + FRONT_DEG)), pivot)
	var nk := _bone([NECK])
	if nk >= 0:
		_turn(nk, Basis(side, -deg_to_rad(NECK_DEG)), _sk.get_bone_global_pose(nk).origin)
	# each leg straight down
	for leg: Array in LEGS:
		var top := _sk.find_bone(String(leg[0]))
		var nxt := _sk.find_bone(String(leg[1]))
		if top < 0 or nxt < 0:
			continue
		var a := _sk.get_bone_global_pose(top).origin
		var v := _sk.get_bone_global_pose(nxt).origin - a
		if v.length() < 1e-5:
			continue
		var q := Quaternion(v.normalized(), down)
		_turn(top, Basis(q), a)


## Turns bone `b` (and all below it) by `r` about `pivot` (skeleton space).
func _turn(b: int, r: Basis, pivot: Vector3) -> void:
	var g := _sk.get_bone_global_pose(b)
	var ng := Transform3D(r * g.basis, pivot + r * (g.origin - pivot))
	_sk.set_bone_global_pose(b, ng)


func _bone(names: Array) -> int:
	for n: String in names:
		var i := _sk.find_bone(n)
		if i >= 0:
			return i
	return -1


func _physics_process(_dt: float) -> void:
	if animal == null or not is_instance_valid(animal) or horse == null or not is_instance_valid(horse):
		queue_free()
		return
	_place()


func _place() -> void:
	animal.global_transform = horse.get_saddle_transform() * local


## Off the saddle onto the ground at the horse's left, as it lay when it died; returns the animal (null when it is gone).
func release() -> Node3D:
	var a := animal
	animal = null
	set_physics_process(false)
	queue_free()
	if a == null or not is_instance_valid(a):
		return null
	if _sk and is_instance_valid(_sk):
		for i in mini(_saved.size(), _sk.get_bone_count()):
			_sk.set_bone_pose_position(i, _saved[i][0])
			_sk.set_bone_pose_rotation(i, _saved[i][1])
			_sk.set_bone_pose_scale(i, _saved[i][2])
	if _ap and is_instance_valid(_ap):
		_ap.active = _ap_active
	var left := horse.global_basis.x if horse and is_instance_valid(horse) else Vector3.RIGHT
	left.y = 0.0
	left = -left.normalized()            # (the horse faces -z: its left is -x)
	var at := (horse.global_position if horse and is_instance_valid(horse) else a.global_position) + left * LAY_M
	at.y = FrontierTerrain.height_at(at.x, at.z)
	var fwd := -horse.global_basis.z if horse and is_instance_valid(horse) else Vector3.FORWARD
	fwd.y = 0.0
	a.global_transform = Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), at)
	if a is CollisionObject3D:
		(a as CollisionObject3D).collision_layer = int(_layers[0])
		(a as CollisionObject3D).collision_mask = int(_layers[1])
	a.remove_meta(&"on_chain")
	a.remove_meta(&"packed")
	var sp: Variant = a.get(&"spawner")
	a.set_meta(&"hauled_at", float(sp.get(&"now")) if sp is Node and is_instance_valid(sp) else 0.0)
	if _was_interactable and not a.is_in_group(PlacedWeapon.GROUP):
		a.add_to_group(PlacedWeapon.GROUP)
	return a
