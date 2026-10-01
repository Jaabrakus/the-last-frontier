class_name CarcassLoad
extends SkidLoad
## A dead animal dragged behind the horse on a rope (user 2026-09-26: "lets add the ability to haul animal carcasses
## as well"): a deer, a buck, a wolf or a fox that is down (WildAnimal, scripts/wildlife) is hauled out of the woods
## to be field-dressed at the fort instead of where it fell (whole, or skinned and still to be butchered). The rope goes round its neck, from the horse's singletree,
## and it is dragged head first, so the hair lies with the drag. HorseHaul offers it like a felled tree: E at the
## carcass's neck with the horse's hitch within reach (or a tap of E from the saddle), E at it again, or a tap in the
## saddle with the horse stopped, to let it go.
##
## It rides on SkidLoad's rod (see the notes there: the rope, the ground, friction, trunks and rocks, the pull): the
## rod runs from the neck (the rope's end) to the rump, measured on the animal as it lies after its death clip, and
## each tick the animal is placed so those two points sit on the rod's ends: the same death pose, slid along, swung
## round and tipped with the ground. Friction and weights are haul.json's "carcass" (hair on forest litter).
##
## On the rope it is not an interactable (no knife work on a load that is moving: E at it unhitches) and the
## wildlife spawner leaves it alone (meta on_chain; WildlifeSpawner._lod); one under the knife (FieldDressing) is not
## taken. Let go, it lies where it stopped, to be field-dressed or hitched again, and its clean-up clock (WildlifeSpawner.CARCASS_S) starts over (meta hauled_at). Every
## DROP_M of the drag it leaves a drop of blood (WildlifeSpawner.blood_drop).
## The animals are CC0 stand-in models (assets/wildlife/quaternius/SOURCE.md); the rope and the collar are drawn here.

## A carcass is taken once its death clip has played out (the longest is 1.08 s), or its ragdoll has come to rest (BoneRagdoll).
const SETTLE_S := 1.6
## A drop of blood every this far of the drag (m).
const DROP_M := 2.5
## The rope's end (the first bone the model has) and the rump.
const NECK_BONES: Array[String] = ["Neck2", "Neck1", "Head"]
const RUMP_BONES: Array[String] = ["Tail1", "Body", "Back"]

## The dead animal on the rope (null once it has been let go).
var animal: Node3D = null

var _lf := Vector3.ZERO           ## the neck in the animal's frame
var _lb := Vector3.ZERO           ## the rump in the animal's frame
var _was_interactable := false
var _drop_d := 0.0
var _last_mid := Vector3.INF
## The rope's loop round the neck: its frame in the animal's (+Y along the neck) and its radius (m).
var _collar_local := Transform3D.IDENTITY
var _collar_r := 0.1
var _collar: MeshInstance3D
static var _rope_mat: StandardMaterial3D


# --- Which carcasses ------------------------------------------------------------------------------------

## A dead animal (group wildlife, is_dead()).
static func is_carcass(n: Node) -> bool:
	return n is Node3D and is_instance_valid(n) and n.is_inside_tree() and not n.is_queued_for_deletion() \
			and n.is_in_group(&"wildlife") and n.has_method(&"is_dead") and n.is_dead()


## One a horse can take now: down, its death clip played out, something left to take from it, not under the knife,
## not on a rope already.
static func haulable(n: Node) -> bool:
	if not is_carcass(n) or n.get_meta(&"on_chain", false):
		return false
	# still falling or settling as a ragdoll (BoneRagdoll): it is taken once it lies still (frozen where it lay)
	var rag: Variant = n.get(&"_rag")
	if rag is BoneRagdoll and not (rag as BoneRagdoll).frozen:
		return false
	# the last step of field dressing takes it out of the interactables (WildAnimal.finish_dress)
	if not n.is_in_group(PlacedWeapon.GROUP):
		return false
	var sp: Variant = n.get(&"spawner")
	if sp is Node and is_instance_valid(sp):
		var fd: Variant = sp.get(&"dressing")
		if fd is Node and is_instance_valid(fd) and fd.get(&"working") == true and fd.get(&"carcass") == n:
			return false
		return float(sp.get(&"now")) - float(n.get_meta(&"died_at", 0.0)) >= SETTLE_S
	var ap := _anim_player(n)
	return ap == null or not ap.is_playing()


## "deer", "buck", "wolf", "fox" (the species table's name).
static func name_of(n: Node) -> String:
	var d: Variant = n.get(&"data")
	if d is Dictionary and (d as Dictionary).has("name"):
		return String(d.name)
	return String(n.get(&"species")) if n.get(&"species") != null else "carcass"


## Weight (kg) of the animal: haul.json carcass.kg by species.
static func mass_of_animal(n: Node, c: Dictionary) -> float:
	var t: Dictionary = (c.get("carcass", {}) as Dictionary).get("kg", {})
	var sp := String(n.get(&"species")) if n.get(&"species") != null else ""
	return float(t.get(sp, t.get("default", 50.0)))


## Where the rope goes on (the neck, global).
static func neck_point(n: Node3D) -> Vector3:
	return _ends_global(n)[0]


## The neck and the rump (global), from the model's bones as it lies; without bones, along its body.
static func _ends_global(n: Node3D) -> Array[Vector3]:
	var sk := n.get(&"_skel") as Skeleton3D
	if sk == null:
		var found := n.find_children("*", "Skeleton3D", true, false)
		sk = found[0] as Skeleton3D if not found.is_empty() else null
	if sk:
		var f := _bone_pos(sk, NECK_BONES)
		var b := _bone_pos(sk, RUMP_BONES)
		if f != Vector3.INF and b != Vector3.INF and f.distance_to(b) > 0.1:
			return [f, b]
	var body: Array = [0.2, 1.0, 0.6]
	var d: Variant = n.get(&"data")
	if d is Dictionary and (d as Dictionary).has("body"):
		body = d.body
	var half := float(body[1]) * 0.5
	var up := Vector3.UP * float(body[0])
	return [n.global_transform * (Vector3.FORWARD * half + up), n.global_transform * (Vector3.BACK * half + up)]


## The neck's cross-section through `at` square to `ax` (global), from the model's skinned meshes baked in the pose
## it lies in: {centre, r} (the middle of the section's points and the distance that takes in 60% of them: the
## section is an oval, and a loop drawn tight sits on its narrow sides), or {}.
static func _neck_section(a: Node3D, at: Vector3, ax: Vector3) -> Dictionary:
	var pts := PackedVector3Array()
	for n in a.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin == null or mi.mesh == null:
			continue
		var baked := mi.bake_mesh_from_current_skeleton_pose()
		if baked == null:
			continue
		var xf := mi.global_transform
		for si in baked.get_surface_count():
			var verts: PackedVector3Array = baked.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var d := xf * v - at
				var along := d.dot(ax)
				if absf(along) > 0.035:
					continue
				var perp := d - ax * along
				if perp.length() < 0.3:
					pts.append(at + perp)
	if pts.size() < 8:
		return {}
	var c := Vector3.ZERO
	for q in pts:
		c += q
	c /= float(pts.size())
	# once more without the far points (a jaw, an antler, a leg lying by the neck)
	var ds: Array[float] = []
	for q in pts:
		ds.append(q.distance_to(c))
	var sorted := ds.duplicate()
	sorted.sort()
	var cut: float = sorted[sorted.size() / 2] * 1.6
	var c2 := Vector3.ZERO
	var k := 0
	for i in pts.size():
		if ds[i] <= cut:
			c2 += pts[i]
			k += 1
	c2 /= float(maxi(k, 1))
	var rs: Array[float] = []
	for i in pts.size():
		if ds[i] <= cut:
			rs.append(pts[i].distance_to(c2))
	rs.sort()
	return {"centre": c2, "r": rs[int(rs.size() * 0.6)], "points": k}


static func _bone_pos(sk: Skeleton3D, names: Array[String]) -> Vector3:
	for nm in names:
		var i := sk.find_bone(nm)
		if i >= 0:
			return sk.global_transform * sk.get_bone_global_pose(i).origin
	return Vector3.INF


static func _anim_player(n: Node) -> AnimationPlayer:
	var ap := n.get(&"_ap") as AnimationPlayer
	if ap == null:
		var found := n.find_children("*", "AnimationPlayer", true, false)
		ap = found[0] as AnimationPlayer if not found.is_empty() else null
	return ap


# --- The load --------------------------------------------------------------------------------------------

## The load for dead animal `a` (haulable()), its rod on the neck and the rump as it lies. Not in the tree yet.
static func from_carcass(a: Node3D, c: Dictionary, visuals: bool) -> CarcassLoad:
	var s := CarcassLoad.new()
	s.name = "Carcass_%s" % a.name
	s.animal = a
	if a.has_method(&"settle_for_haul"):
		a.call(&"settle_for_haul")          # (its ragdoll's sprawl gives way to the lying pose the rope is built for)
	var cc: Dictionary = c.get("carcass", {})
	var cf := c.duplicate()
	cf["mu_axial"] = float(cc.get("mu_axial", 0.5))
	cf["mu_lateral"] = float(cc.get("mu_lateral", 0.7))
	s.cfg = cf
	s._visuals = visuals
	var torso := 0.2
	var d: Variant = a.get(&"data")
	if d is Dictionary and (d as Dictionary).has("body"):
		torso = float(d.body[0])
	s.info = {"species": String(a.get(&"species")) if a.get(&"species") != null else "", "name": name_of(a), "radius": torso}
	s.state = State.DOWN
	var ends := _ends_global(a)
	s.front = ends[0]
	s.back = ends[1]
	var inv := a.global_transform.affine_inverse()
	s._lf = inv * s.front
	s._lb = inv * s.back
	# the rod's ends ride as high over the ground as the neck and the rump lie over it now
	var ground := a.global_position.y
	s.r_front = clampf(s.front.y - ground, 0.06, 0.5)
	s.r_back = clampf(s.back.y - ground, 0.06, 0.5)
	s.mass_kg = mass_of_animal(a, c)
	s.process_physics_priority = 10
	s.length = maxf(s.front.distance_to(s.back), 0.2)
	s.info["crown_bottom"] = s.length
	s._prev = [s.front, s.back]
	s.chain_len = float(c.get("chain_m", 2.4))
	s._fit_collar(a, torso)
	if visuals:
		s._build_collar()
	s._apply_skid_pose()
	return s


## The loop round the neck: up the neck behind the jaw (from the middle neck bone most of the way to the last),
## square to the neck (its first bone to its last), fitted to the neck's cross-section there as the model lies
## (_neck_section); without that about half as thick as the body (the torso capsule's radius), and without the
## bones round the rod's front end.
func _fit_collar(a: Node3D, torso: float) -> void:
	_collar_r = clampf(torso * 0.5, 0.035, 0.16)
	var at := front
	var ax := (front - back).normalized()
	var sk := a.get(&"_skel") as Skeleton3D
	if sk:
		var n1 := _bone_pos(sk, ["Neck1"])
		var n3 := _bone_pos(sk, ["Neck3", "Head"])
		if n1 != Vector3.INF and n3 != Vector3.INF and n1.distance_to(n3) > 0.02:
			ax = (n3 - n1).normalized()
			var n2 := _bone_pos(sk, ["Neck2"])
			at = (n2 if n2 != Vector3.INF else (n1 + n3) * 0.5).lerp(n3, 0.6)
			var sec := _neck_section(a, at, ax)
			if not sec.is_empty():
				at = sec.centre
				_collar_r = clampf(float(sec.r) + 0.008, 0.03, 0.3)
	var x := ax.cross(Vector3.UP)
	if x.length() < 1e-3:
		x = Vector3.RIGHT
	x = x.normalized()
	var xf := Transform3D(Basis(x, ax, x.cross(ax).normalized()), at)
	_collar_local = a.global_transform.affine_inverse() * xf


func hitch(h: Node, len_m: float) -> void:
	super.hitch(h, len_m)
	if animal and is_instance_valid(animal):
		animal.set_meta(&"on_chain", true)
		_was_interactable = animal.is_in_group(PlacedWeapon.GROUP)
		animal.remove_from_group(PlacedWeapon.GROUP)


## Off the rope: the carcass lies where it stopped, an interactable again (skin it, or hitch it again).
## Returns it (null when it is gone).
func release() -> Node3D:
	unhitch()
	var a := animal
	animal = null
	if a == null or not is_instance_valid(a):
		return null
	a.remove_meta(&"on_chain")
	var sp: Variant = a.get(&"spawner")
	a.set_meta(&"hauled_at", float(sp.get(&"now")) if sp is Node and is_instance_valid(sp) else 0.0)
	if _was_interactable and not a.is_in_group(PlacedWeapon.GROUP):
		a.add_to_group(PlacedWeapon.GROUP)
	return a


func load_name() -> String:
	return String(info.get("name", "carcass"))


func species_name() -> String:
	return load_name()


## Not wood: the axe has nothing to buck here.
func is_down() -> bool:
	return false


func buck(_power: float) -> Dictionary:
	return {"logs": 0, "limbed": false}


## The rope's end: the side of the loop round the neck that faces the horse.
func chain_point() -> Vector3:
	if animal == null or not is_instance_valid(animal):
		return front
	var xf := animal.global_transform * _collar_local
	var ax := xf.basis.y.normalized()
	var toward: Vector3 = front * 2.0 - back
	if hitched and haul != null and is_instance_valid(haul):
		toward = haul.call(&"hitch_point")
	var to := toward - xf.origin
	var perp := to - ax * to.dot(ax)
	if perp.length() < 1e-4:
		return xf.origin
	return xf.origin + perp.normalized() * (_collar_r + 0.012)


## The nearest point of the carcass's line to `p` (neck to rump).
func bole_point(p: Vector3) -> Vector3:
	var a := back - front
	var t := clampf((p - front).dot(a) / maxf(a.length_squared(), 1e-6), 0.0, 1.0)
	return front + a * t


func highlight_targets() -> Array:
	if animal and is_instance_valid(animal) and animal.has_method(&"highlight_targets"):
		return animal.highlight_targets()
	return []


func _physics_process(delta: float) -> void:
	if animal == null or not is_instance_valid(animal) or animal.is_queued_for_deletion():
		# gone from under the rope (cleaned up off the map): nothing left to drag
		animal = null
		if hitched and haul != null and is_instance_valid(haul) and haul.get(&"load") == self:
			haul.call(&"unhitch")
		elif not is_queued_for_deletion():
			queue_free()
		return
	super._physics_process(delta)
	_trail()


## The animal placed on the rod: its neck on the front end, its rump on the back, upright as it lay.
func _apply_skid_pose() -> void:
	super._apply_skid_pose()
	if animal == null or not is_instance_valid(animal):
		return
	var uw := back - front
	var ul := _lb - _lf
	if uw.length() < 1e-4 or ul.length() < 1e-4:
		return
	var rot := _frame(uw / uw.length()) * _frame(ul / ul.length()).inverse()
	animal.global_transform = Transform3D(rot, front - rot * _lf)
	if _collar:
		_collar.global_transform = animal.global_transform * _collar_local


## A frame with +Z along `d` and +Y as near the up as it can be.
static func _frame(d: Vector3) -> Basis:
	var x := Vector3.UP.cross(d)
	if x.length() < 1e-3:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, d.cross(x).normalized(), d)


## A fresh drag leaves a drop of blood now and then.
func _trail() -> void:
	var mid := front.lerp(back, 0.35)
	if _last_mid != Vector3.INF:
		_drop_d += Vector2(mid.x - _last_mid.x, mid.z - _last_mid.z).length()
	_last_mid = mid
	if _drop_d < DROP_M:
		return
	_drop_d = 0.0
	var sp: Variant = animal.get(&"spawner")
	if sp is Node and is_instance_valid(sp) and sp.has_method(&"blood_drop"):
		sp.call(&"blood_drop", mid, 0.7)


## The rope's loop round the neck (a ring about its +Y; placed with the animal: _apply_skid_pose).
func _build_collar() -> void:
	var t := TorusMesh.new()
	t.inner_radius = _collar_r
	t.outer_radius = _collar_r + 0.024
	t.rings = 18
	t.ring_segments = 6
	_collar = MeshInstance3D.new()
	_collar.name = "Collar"
	_collar.mesh = t
	_collar.material_override = rope_material()
	_collar.visibility_range_end = 60.0
	_collar.top_level = true
	add_child(_collar)


static func rope_material() -> StandardMaterial3D:
	if _rope_mat == null:
		_rope_mat = StandardMaterial3D.new()
		_rope_mat.albedo_color = Color(0.5, 0.41, 0.28)
		_rope_mat.roughness = 0.95
		_rope_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _rope_mat
