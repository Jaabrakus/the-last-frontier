class_name BoneRagdoll
extends Node
## A ragdoll for a skeleton that is scaled (the animals: their armature is 100x, the body 0.38x), made of plain RigidBody3Ds
## in the world and jointed, with the bones following them (PhysicalBone3D would want the skeleton at scale 1: the player's
## PlayerRagdoll has that). Added under the dead thing's node; the bodies are top level (the node may be moved after).
##   rows   [bone, to, size, share, swing_deg, twist_deg, parent]: a capsule from `bone` to the bone `to` ("" : the bone's
##          own direction from its parent, as long as that step), `size` its radius as a part of its length, `share` of
##          the whole's mass, jointed to the body on bone `parent` ("" : the root body)
##   driven each frame by a SkeletonModifier3D: the bones with a body take the body's place; the bones between follow
##   at rest  the pose is frozen where it lies (freeze(): the skeleton's places kept, the bodies freed: a carcass costs
##            nothing) and `rested` is emitted
## Launched with launch(velocity): all the bodies, and push(at, impulse) for a shot or an arrow into a lying one.

signal rested

const REST_MPS := 0.25
const REST_S := 0.5
const MAX_S := 6.0

var skeleton: Skeleton3D
var bodies := {}                    ## bone name -> RigidBody3D
var root_bone := ""
var frozen := false
var done := false
var age := 0.0

var _rows: Array
var _bone_in_body := {}             ## bone index -> the bone's place in its body's frame
var _held := {}                     ## bone index -> skeleton-space pose (frozen)
var _order: Array[int] = []         ## the bones with a body, parents first
var _holder: Node3D
var _mod: RagdollDriver  ## (public for tests)
var _still := 0.0


## `owner_body`: the node it is added under (whose own body the bodies do not collide with. `total_kg` the whole's mass.
static func build(sk: Skeleton3D, rows: Array, total_kg: float, owner_body: CollisionObject3D = null) -> BoneRagdoll:
	var r := BoneRagdoll.new()
	r.name = "BoneRagdoll"
	r.skeleton = sk
	r._rows = rows
	(owner_body if owner_body else sk).add_child(r)
	r._make(total_kg, owner_body)
	return r


func _make(total_kg: float, owner_body: CollisionObject3D) -> void:
	_holder = Node3D.new()
	_holder.name = "Bodies"
	_holder.top_level = true
	add_child(_holder)
	var sk_xf := skeleton.global_transform
	var scale_k := sk_xf.basis.get_scale().x
	for row: Array in _rows:
		var bn := String(row[0])
		var bi := skeleton.find_bone(bn)
		if bi < 0:
			continue
		var head := sk_xf * skeleton.get_bone_global_pose(bi).origin
		var tail: Vector3
		var to := String(row[1])
		var ti := skeleton.find_bone(to) if to != "" else -1
		if ti >= 0:
			tail = sk_xf * skeleton.get_bone_global_pose(ti).origin
		else:
			# a leaf: on from its parent's head along the same way, as far again
			var pi := skeleton.get_bone_parent(bi)
			var from := sk_xf * skeleton.get_bone_global_pose(pi).origin if pi >= 0 else head - Vector3.UP * 0.2
			var step := head - from
			tail = head + step * 0.9
		var axis := tail - head
		var length := maxf(axis.length(), 0.04)
		axis = axis / length if axis.length() > 1e-5 else Vector3.DOWN
		var radius := clampf(length * float(row[2]), 0.02, 0.5)
		var rb := RigidBody3D.new()
		rb.name = "B_" + bn
		rb.mass = maxf(total_kg * float(row[3]), 0.2)
		rb.collision_layer = 1
		rb.collision_mask = 1
		rb.linear_damp = 0.7
		rb.angular_damp = 3.0
		rb.continuous_cd = true
		var mat := PhysicsMaterial.new()
		mat.friction = 1.4
		mat.bounce = 0.02
		rb.physics_material_override = mat
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = radius
		cap.height = maxf(length, radius * 2.0 + 0.01)
		cs.shape = cap
		rb.add_child(cs)
		_holder.add_child(rb)
		var mid := (head + tail) * 0.5
		var up := axis
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var b := Basis(side, up, side.cross(up).normalized()).orthonormalized()
		rb.global_transform = Transform3D(b, mid)
		if owner_body:
			rb.add_collision_exception_with(owner_body)
		bodies[bn] = rb
		_order.append(bi)
		var world_bone := sk_xf * skeleton.get_bone_global_pose(bi)
		world_bone.basis = world_bone.basis.orthonormalized()
		_bone_in_body[bi] = rb.global_transform.affine_inverse() * world_bone
		if root_bone == "":
			root_bone = bn
		rb.set_meta("head", head)
	# no body against the ones it is jointed to, or any other of the rig
	for a: RigidBody3D in bodies.values():
		for c: RigidBody3D in bodies.values():
			if a != c:
				a.add_collision_exception_with(c)
	for row: Array in _rows:
		var bn := String(row[0])
		var pn := String(row[6])
		if not bodies.has(bn) or pn == "" or not bodies.has(pn):
			continue
		var child: RigidBody3D = bodies[bn]
		var at: Vector3 = child.get_meta("head")
		var j := ConeTwistJoint3D.new()
		j.name = "J_" + bn
		_holder.add_child(j)
		# the joint at the child's head, its twist axis (X) along the child
		var down := (child.global_basis.y).normalized()
		var x := down
		var z := x.cross(Vector3.UP if absf(x.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD).normalized()
		j.global_transform = Transform3D(Basis(x, z.cross(x).normalized(), z), at)
		j.node_a = j.get_path_to(bodies[pn])
		j.node_b = j.get_path_to(child)
		j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(float(row[4])))
		j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(float(row[5])))
		j.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.8)
		j.set_param(ConeTwistJoint3D.PARAM_RELAXATION, 1.0)
	_mod = RagdollDriver.new()
	_mod.name = "RagdollDriver"
	_mod.rag = self
	skeleton.add_child(_mod)
	# keep the scale out of the bone poses (the skeleton's own scale is what scale_k is)
	set_meta("scale_k", scale_k)


## Every body moving with `v` (m/s), all spinning a little by `spin`.
func launch(v: Vector3, spin := 1.0) -> void:
	for rb: RigidBody3D in bodies.values():
		rb.linear_velocity = v
		rb.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)) * spin


## The body nearest `at` knocked by `dv` (m/s: a shot or an arrow into it, a kick), at that point.
func push(at: Vector3, dv: Vector3) -> void:
	var best: RigidBody3D = null
	var best_d := INF
	for rb: RigidBody3D in bodies.values():
		var d := rb.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = rb
	if best:
		best.sleeping = false
		best.linear_velocity += dv
		# (a little turn from where it landed)
		best.angular_velocity += (at - best.global_position).cross(dv.normalized()).limit_length(0.3) * dv.length() * 0.3
		_still = 0.0


func root_body() -> RigidBody3D:
	return bodies.get(root_bone) as RigidBody3D


## The place of a bone with a body, in the world (the ragdoll's).
func bone_world(bone: int) -> Transform3D:
	var rb: RigidBody3D = bodies.get(skeleton.get_bone_name(bone))
	return rb.global_transform * (_bone_in_body[bone] as Transform3D)


func _physics_process(dt: float) -> void:
	if frozen or bodies.is_empty():
		return
	age += dt
	var fastest := 0.0
	for rb: RigidBody3D in bodies.values():
		fastest = maxf(fastest, rb.linear_velocity.length())
	_still = _still + dt if fastest < REST_MPS else 0.0
	if (_still >= REST_S and age > 0.5) or age >= MAX_S:
		done = true
		rested.emit()


## Called by the driver (a skeleton modifier): the bones with a body take its place, or the frozen pose.
func apply_poses() -> void:
	var inv := skeleton.global_transform.affine_inverse()
	if frozen:
		for bi: int in _held:
			skeleton.set_bone_global_pose(bi, _held[bi])
		return
	for bi in _order:
		var w := bone_world(bi)
		var l := inv * w
		skeleton.set_bone_global_pose(bi, Transform3D(l.basis.orthonormalized(), l.origin))


## The bones kept where they lie, in the skeleton's frame as it is NOW (call after moving the owner), the bodies freed.
## `world` (bone index -> the bone's place in the world, taken before the owner moved) gives the places to keep.
func freeze(world: Dictionary) -> void:
	var inv := skeleton.global_transform.affine_inverse()
	for bi: int in world:
		var l := inv * (world[bi] as Transform3D)
		_held[bi] = Transform3D(l.basis.orthonormalized(), l.origin)
	frozen = true
	if _holder:
		_holder.queue_free()
		_holder = null
	bodies.clear()


## Every bone's place now, in the world (what freeze() keeps).
func worlds() -> Dictionary:
	var out := {}
	for bi in _order:
		out[bi] = bone_world(bi)
	return out


func _exit_tree() -> void:
	if is_instance_valid(_mod):
		_mod.queue_free()


## The modifier that puts the bones where the bodies are.
class RagdollDriver extends SkeletonModifier3D:
	var rag: BoneRagdoll
	var calls := 0

	func _process_modification_with_delta(_delta: float) -> void:
		calls += 1
		if rag and is_instance_valid(rag):
			rag.apply_poses()
