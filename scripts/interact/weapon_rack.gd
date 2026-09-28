class_name WeaponRack
extends StaticBody3D
## A place to stand weapons (user 2026-09-25: set rifles "in bins" for quick equip without reloading).
## style "rack": a frame of two posts, a notched top rail and a butt trough, long guns and bows upright in
## a row of `slots`; style "barrel": an open barrel with spears / muskets standing in it in a ring.
## Placement target of PlayerInteractor (group "weapon_racks"): free_slot_near(), slot_pose(), place(),
## free_slot(). Weapons in it are PlacedWeapon nodes (E takes or swaps them).
## Built in build mode (the Furniture group's musket rack and spear barrel: BuiltPiece), it is `bare`: the piece's own
## model (BuildGeometry) shows it, this body only collides (a built piece's body: BuiltPiece.BODY_GROUP) and holds.

const GROUP := &"weapon_racks"
const LONG := ["musket", "over_under", "bow", "spear", "atlatl"]

@export_enum("rack", "barrel") var style := "rack"
@export var slots := 4
## No model of its own (a built piece shows it).
@export var bare := false

var _used: Array = []   ## slot -> PlacedWeapon or null


func _ready() -> void:
	add_to_group(GROUP)
	if bare:
		add_to_group(BuiltPiece.BODY_GROUP)
	_used.resize(slots)
	_build()


## The width of a "rack" style rack of `n` slots (its posts stand at the ends).
static func rack_span(n: int) -> float:
	return 0.28 * float(n - 1) + 0.4


## Taken down (a built rack): what stood in it is laid on the ground in front of it.
func _exit_tree() -> void:
	if not bare:
		return
	var fwd := global_basis.z.normalized()
	for i in _used.size():
		var pw: Variant = _used[i]
		if pw == null or not is_instance_valid(pw) or (pw as Node).is_queued_for_deletion():
			continue
		var w := pw as PlacedWeapon
		w.rack = null
		w.rack_slot = -1
		var at := global_transform * _slot_base(i) + fwd * (0.45 + 0.12 * float(i % 2))
		at.y = global_position.y + 0.04
		# lying flat, muzzle (-Z) sideways along the rack, its top (+Y) up
		w.global_transform = Transform3D(Basis(Vector3.UP, rotation.y + PI * 0.5), at)
		_used[i] = null


## The weapons standing in it.
func held() -> Array:
	var out: Array = []
	for w in _used:
		if w != null and is_instance_valid(w):
			out.append(w)
	return out


## Whether this rack takes the weapon kind `key` (long weapons; the barrel also spears and darts).
func accepts(key: String) -> bool:
	return key in LONG


## The free slot nearest `point` (world), or -1.
func free_slot_near(point: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in slots:
		if _used[i] != null and is_instance_valid(_used[i]):
			continue
		var d := (global_transform * _slot_base(i)).distance_to(point)
		if d < best_d:
			best_d = d
			best = i
	return best


## World transform for a weapon of z-extent `ext` (PlacedWeapon.z_extent: min = muzzle end, max = butt)
## standing in slot `i`: butt in the trough, muzzle up, leaning back a little against the rail.
func slot_pose(i: int, ext: Vector2) -> Transform3D:
	var base := global_transform * _slot_base(i)
	var up := global_transform.basis.y.normalized()
	var back := -global_transform.basis.z.normalized()
	var lean := 0.12 if style == "rack" else 0.06
	var along := (up + back * lean).normalized()      # butt -> muzzle
	# the model's -Z points to the muzzle, +Y is its top (lock outward: toward the rack's front)
	var z := -along
	var y := global_transform.basis.z.normalized()
	var x := y.cross(z).normalized()
	y = z.cross(x).normalized()
	var b := Basis(x, y, z)
	var butt_local := Vector3(0, 0, ext.y)
	return Transform3D(b, base - b * butt_local + up * 0.02)


func place(pw: PlacedWeapon, i: int) -> void:
	_used[i] = pw
	pw.rack = self
	pw.rack_slot = i
	pw.global_transform = slot_pose(i, PlacedWeapon.z_extent(pw.model))


func free_slot(i: int) -> void:
	if i >= 0 and i < _used.size():
		_used[i] = null


## Local position of slot i's butt rest.
func _slot_base(i: int) -> Vector3:
	if style == "barrel":
		var a := TAU * float(i) / float(slots)
		return Vector3(cos(a) * 0.14, 0.12, sin(a) * 0.14)
	var span := 0.28 * float(slots - 1)
	return Vector3(-span * 0.5 + 0.28 * float(i), 0.08, 0.0)


func _build() -> void:
	var mat: Material = StructureMaterials.get_material(&"boards")   # the fort's planks
	if mat == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.36, 0.25, 0.16)
		sm.roughness = 0.85
		mat = sm
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if bare:
		if style == "barrel":
			box.size = Vector3(0.5, 0.62, 0.5)
			shape.position.y = 0.31
		else:
			box.size = Vector3(rack_span(slots), 1.25, 0.3)
			shape.position = Vector3(0, 0.625, -0.06)
		shape.shape = box
		add_child(shape)
		return
	if style == "barrel":
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.24
		cyl.bottom_radius = 0.22
		cyl.height = 0.62
		mi.mesh = cyl
		mi.material_override = mat
		mi.position.y = 0.31
		add_child(mi)
		box.size = Vector3(0.5, 0.62, 0.5)
		shape.position.y = 0.31
	else:
		var span := 0.28 * float(slots - 1) + 0.4
		for side in [-1.0, 1.0]:
			_part(Vector3(0.07, 1.25, 0.07), Vector3(side * span * 0.5, 0.625, -0.12), mat)
		_part(Vector3(span, 0.06, 0.08), Vector3(0, 1.08, -0.12), mat)      # top rail (the barrels lean on it)
		_part(Vector3(span, 0.08, 0.22), Vector3(0, 0.04, 0.0), mat)        # butt trough
		_part(Vector3(span, 0.05, 0.05), Vector3(0, 0.55, -0.12), mat)      # middle brace
		box.size = Vector3(span, 1.25, 0.3)
		shape.position = Vector3(0, 0.625, -0.06)
	shape.shape = box
	add_child(shape)


func _part(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
