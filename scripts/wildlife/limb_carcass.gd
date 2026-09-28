class_name LimbCarcass
extends AnimatableBody3D
## A piece chopped off a big carcass, lying on the ground as a carcass of its own (user 2026-09-27: "chopped up limbs count
## as a carcass right like a smaller animal carcass"): a mammoth's leg or trunk (MammothButchery). It is the carcass's
## own mesh cut out where it was (the triangles on the piece's bones, as they lay: cut_mesh), a raw red cap on the cut,
## and it falls to lie along the ground.
## As a small animal's carcass it is:
##   hauled     a carcass to the rope on foot (FootDrag), the wheelbarrow and the horse (CarcassLoad: in the group
##              "wildlife", is_dead(); the rope round its far end, the foot of a leg; `data.body` its size; its weight
##              haul.json's carcass kg for its `species`)
##   butchered  with the felling axe (user 2026-09-27: "use the axe to butcher"): a GatherTools "carcass" target
##              (group "axe_work"), `strokes` strokes, and what it yields goes into the pack; then it is gone
##   scavenged a carcass to the scavengers too (user 2026-09-27: "it should go for left animals"; WildlifeSpawner:
##              the group "carcasses", meat_left, eat()): wolves, foxes and ravens eat it down (it thins as it goes;
##              picked clean, bones, and the axe gets nothing more from it); what they ate is gone from the axe's meat
##              too. Left alone 10 minutes, it is gone (WildlifeSpawner.UNTOUCHED_S).
## Not kept in the save (nor is the carcass it came off).

const FALL_S := 0.5
const AIM_BONUS := 0.9
const REACH := 2.4

var species := "mammoth_leg"
## Its meat, in deer (WildAnimal.meat_left: 1 a whole deer): MEAT for its kind when whole, less what was eaten off it
## on the carcass (make()); scavengers take it (eat()). Where they eat: eat_radius from its middle.
const MEAT := {"mammoth_leg": 3.0, "mammoth_trunk": 1.5}
var meat_full := 1.0
var meat_left := 1.0
var eat_radius := 0.6
## For CarcassLoad and the wheelbarrow: {name, body: [radius, length, height]}.
var data := {}
var yields := {}
var strokes := 6.0
var progress := 0.0
var radius := 0.4
var length := 1.0
var model: MeshInstance3D


func _ready() -> void:
	add_to_group(&"wildlife")
	add_to_group(PlacedWeapon.GROUP)
	add_to_group(&"axe_work")
	add_to_group(&"carcasses")
	sync_to_physics = false


func is_dead() -> bool:
	return true


## A piece of `kind` ("mammoth_leg", "mammoth_trunk") named `nm`: `mesh` its geometry in a frame whose origin is the
## middle of its axis and whose -Z runs along it (from the cut to its far end), `r` and `l` its size. It is placed there
## (`from`: that frame in the world) and falls to lie along the ground, `away` off (clear of the carcass it came off).
## `meat`: what is left on it (in deer; -1 whole: MEAT).
static func make(kind: String, nm: String, mesh: ArrayMesh, r: float, l: float, give: Dictionary, n_strokes: float,
		from: Transform3D, parent: Node, away := Vector3.ZERO, meat := -1.0) -> LimbCarcass:
	var c := LimbCarcass.new()
	c.name = "Limb_" + kind
	c.species = kind
	c.meat_full = float(MEAT.get(kind, 1.0))
	c.meat_left = clampf(meat, 0.0, c.meat_full) if meat >= 0.0 else c.meat_full
	c.eat_radius = maxf(r, l * 0.4)
	c.radius = r
	c.length = l
	c.yields = give
	c.strokes = n_strokes
	c.data = {"name": nm, "body": [r, l, r * 2.0]}
	c.model = MeshInstance3D.new()
	c.model.name = "Model"
	c.model.mesh = mesh
	c.model.position = Vector3.UP * r
	c.add_child(c.model)
	# the cut: a raw red cap at the near end
	var cap := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.85
	cyl.bottom_radius = r * 0.85
	cyl.height = 0.04
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.07, 0.06)
	m.roughness = 0.4
	cyl.material = m
	cap.mesh = cyl
	cap.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, l * 0.5))
	c.model.add_child(cap)
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = r
	shape.height = maxf(l, r * 2.0 + 0.05)
	cs.shape = shape
	cs.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.UP * r)
	c.add_child(cs)
	# where it was (the mesh frame there, the node's origin r under its axis), then down along the ground. Placed before it
	# is in the world: made at the world's middle and moved there after, its first physics step was that jump, and it
	# flung whatever stood there (a player in the middle of the fort, at some 26 km/s) as a moving body does
	var start := from * Transform3D(Basis(), Vector3.DOWN * r)
	c.transform = (parent as Node3D).global_transform.affine_inverse() * start if parent is Node3D else start
	parent.add_child(c)
	c.global_transform = start
	var fwd := -from.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	var at := from.origin + away
	at.y = FrontierTerrain.height_at(at.x, at.z)
	var lie := Transform3D(Basis.looking_at(fwd, Vector3.UP), at)
	var q0 := start.basis.get_rotation_quaternion()
	var q1 := lie.basis.get_rotation_quaternion()
	var fall := func(k: float) -> void:
		if is_instance_valid(c):
			c.global_transform = Transform3D(Basis(q0.slerp(q1, k)), start.origin.lerp(lie.origin, k * k))
	c.create_tween().tween_method(fall, 0.0, 1.0, FALL_S)
	c._show_eaten()
	return c


## A scavenger takes up to `amount` of its meat; returns what it got. Picked clean: bones (WildlifeSpawner clears
## them), nothing more for the axe.
func eat(amount: float) -> float:
	var took := minf(amount, meat_left)
	meat_left -= took
	WildlifeSpawner.touch(self)
	if meat_left <= 0.02 and not get_meta("bones", false):
		meat_left = 0.0
		set_meta("bones", true)
		remove_from_group(&"axe_work")
	_show_eaten()
	return took


## Eaten down, it thins (the flesh gone from round the bone); picked clean, bone white.
func _show_eaten() -> void:
	if model == null:
		return
	var k := lerpf(0.45, 1.0, clampf(meat_left / maxf(meat_full, 0.01), 0.0, 1.0))
	model.scale = Vector3(k, k, 1.0)
	model.position = Vector3.UP * radius * k
	if get_meta("bones", false) and model.material_override == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.78, 0.74, 0.64)
		m.roughness = 0.8
		model.material_override = m


## The triangles of `mi`'s mesh on bones `bones` (skeleton indices), as the skeleton is posed now, in the frame `frame`
## (world): an ArrayMesh with the surfaces' own materials (the MeshInstance's overrides first). A triangle is taken when
## two of its corners' heaviest bone is one of `bones`. The posed corners are skinned here from the bones' poses and the
## skin's binds (the engine's baking needs the skin registered with a renderer, which a headless run has not).
static func cut_mesh(mi: MeshInstance3D, bones: Array, frame: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	if mi == null or mi.mesh == null or mi.skin == null:
		return out
	var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if sk == null:
		return out
	var bind_bone: Array[int] = []
	var bind_xf: Array[Transform3D] = []
	for b in mi.skin.get_bind_count():
		var bb := mi.skin.get_bind_bone(b)
		if bb < 0:
			bb = sk.find_bone(mi.skin.get_bind_name(b))
		bind_bone.append(bb)
		bind_xf.append(sk.get_bone_global_pose(bb) * mi.skin.get_bind_pose(b) if bb >= 0 else Transform3D())
	var to_frame := frame.affine_inverse() * sk.global_transform
	for si in mi.mesh.get_surface_count():
		var src: Array = mi.mesh.surface_get_arrays(si)
		var bw: PackedInt32Array = src[Mesh.ARRAY_BONES]
		var ww: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
		var rest_v: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
		var rest_n: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = src[Mesh.ARRAY_INDEX]
		if bw.is_empty() or rest_v.is_empty():
			continue
		var per := bw.size() / rest_v.size()
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		verts.resize(rest_v.size())
		norms.resize(rest_v.size())
		for v in rest_v.size():
			var pv := Vector3.ZERO
			var pn := Vector3.ZERO
			for k in per:
				var w := ww[v * per + k]
				if w <= 0.0:
					continue
				var xf: Transform3D = bind_xf[bw[v * per + k]]
				pv += (xf * rest_v[v]) * w
				if not rest_n.is_empty():
					pn += (xf.basis * rest_n[v]) * w
			verts[v] = pv
			norms[v] = pn
		var on := PackedByteArray()
		on.resize(verts.size())
		for v in verts.size():
			var best := -1.0
			var bi := -1
			for k in per:
				if ww[v * per + k] > best:
					best = ww[v * per + k]
					bi = bw[v * per + k]
			on[v] = 1 if bi >= 0 and bi < bind_bone.size() and bind_bone[bi] in bones else 0
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 0
		var tri_count := (idx.size() / 3) if not idx.is_empty() else verts.size() / 3
		for t in tri_count:
			var a := idx[t * 3] if not idx.is_empty() else t * 3
			var b := idx[t * 3 + 1] if not idx.is_empty() else t * 3 + 1
			var c := idx[t * 3 + 2] if not idx.is_empty() else t * 3 + 2
			if int(on[a]) + int(on[b]) + int(on[c]) < 2:
				continue
			for v in [a, b, c]:
				if not norms.is_empty():
					st.set_normal((to_frame.basis * norms[v]).normalized())
				st.add_vertex(to_frame * verts[v])
			n += 1
		if n == 0:
			continue
		var mat := mi.get_surface_override_material(si)
		if mat == null:
			mat = mi.mesh.surface_get_material(si)
		st.set_material(mat)
		st.commit(out)
	return out


# --- The axe: butchering it (GatherTools "carcass" target) -----------------------------------------------

func _blocked() -> bool:
	return has_meta(&"on_chain") or is_queued_for_deletion()


func _axis() -> Array:
	var a := global_transform * Vector3(0.0, radius, length * 0.5)
	var b := global_transform * Vector3(0.0, radius, -length * 0.5)
	return [a, b]


func axe_candidates(chest: Vector3, eye: Vector3, look: Vector3, exclude: Array = []) -> Array:
	if _blocked():
		return []
	var c := axe_describe("limb", chest)
	if c.is_empty() or float(c.dist) > REACH:
		return []
	var q := PhysicsRayQueryParameters3D.create(eye, eye + look.normalized() * 12.0)
	q.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider == self:
		c["aim"] = AIM_BONUS
	return [c]


func axe_describe(_key: String, chest: Vector3) -> Dictionary:
	if _blocked():
		return {}
	var ax := _axis()
	var near := Geometry3D.get_closest_point_to_segment(chest, ax[0], ax[1])
	return {"type": "carcass", "key": "limb", "work": self, "pos": near, "radius": 0.0, "name": String(data.name),
			"dist": Vector2(near.x - chest.x, near.z - chest.z).length(), "aim": 0.0}


## One axe stroke: its work so far; at 1 its meat into the pack and it is gone.
func axe_strike(_c: Dictionary, power: float) -> float:
	if _blocked() or get_meta("bones", false):
		return 0.0
	WildlifeSpawner.touch(self)
	progress += power / strokes
	if progress < 1.0:
		return progress
	var p := get_tree().get_first_node_in_group(&"player") as FrontierPlayer
	if p:
		var inv := InventoryState.from_player(p)
		var got: Array = []
		# what the scavengers ate is gone from the meat (WildAnimal.finish_dress does the same)
		var share := clampf(meat_left / maxf(meat_full, 0.01), 0.0, 1.0)
		for k: String in yields:
			var n := int(yields[k])
			if k == "venison":
				n = maxi(int(round(n * share)), 1 if share > 0.15 else 0)
			if n <= 0:
				continue
			inv.add(k, n)
			got.append("+%d %s" % [n, InventoryState.name_of(k)])
		p.inventory_pack = inv.pack.duplicate(true)
		if p.interactor:
			p.interactor.notice(", ".join(got), 3.0)
	remove_from_group(&"wildlife")
	remove_from_group(&"axe_work")
	remove_from_group(&"carcasses")
	remove_from_group(PlacedWeapon.GROUP)
	queue_free()
	return 1.0


func axe_prompt(_key: String) -> String:
	return "Butcher the %s%s" % [String(data.name), "" if progress <= 0.0 else "  %d%%" % int(clampf(progress, 0.0, 0.99) * 100.0)]


# --- The interactor (it is one of the interactables, as a carcass is; the axe and the rope offer what to do) -------

func interact_point() -> Vector3:
	return global_transform * Vector3(0.0, radius, 0.0)


func interact_prompt(_player: Node) -> String:
	return ""


func interact(_player: Node) -> bool:
	return false


func highlight_targets() -> Array:
	return []
