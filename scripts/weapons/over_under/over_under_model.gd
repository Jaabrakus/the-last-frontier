class_name OverUnderModel
## The over-under's model. build() instances res://assets/weapons/over_under.glb (made by
## tools/weapons/build_over_under.py in Blender) once Godot has imported it, and falls back to
## a primitive stand-in with the same nodes otherwise. It does not go through WeaponModels, so
## weapon_models.gd stays untouched (the optional hook H8 adds `"over_under"` there for tools
## that build models by key).
##
## Axes are the musket's: origin at the grip, -Z toward the muzzle, +Y up, +X the lock side,
## top bore axis at y = 0.035. Nodes (the contract, weapons_balance_design.md 2.7):
##
##   OverUnder      stock-fixed body mesh
##   Cock           stock-fixed, origin on the tumbler axis; mesh at full cock
##   Catch          barrel release at the front of the trigger guard, origin on its pivot
##   Barrels        origin on the swivel axis (0, 0.0215, -0.128); the turnover turns it 180 deg
##                  about its local Z. Children: BarrelPair (mesh), FrizzenA, FrizzenB (origins on
##                  their screws; B is A turned half round), Ramrod, and the markers MuzzleA,
##                  MuzzleB, PanA, PanB of the two physical barrels
##   Muzzle, Pan    top-slot markers (never move): where the barrel on top fires and flashes
##   Muzzle_top, Muzzle_bottom, Pan_top, Pan_bottom   both slots
##   LeftGrip       where the left palm bone sits on the fore-end in the musket's clips
##
## glTF empties import as Node3D; build() turns every marker into a Marker3D in place.

const GLB_PATH := "res://assets/weapons/over_under.glb"
const ROOT_NAME := "OverUnderModel"
const ROOT_MARKERS: Array[String] = ["Muzzle", "Pan", "Muzzle_top", "Muzzle_bottom", "Pan_top", "Pan_bottom", "LeftGrip"]
const BARREL_MARKERS: Array[String] = ["MuzzleA", "MuzzleB", "PanA", "PanB"]
const MOVING: Array[String] = ["Barrels", "Cock", "Catch", "FrizzenA", "FrizzenB"]

## Model-space layout (metres), shared with the Blender builder.
const AXIS_Y := 0.035
const SPACING := 0.027
const SWIVEL := Vector3(0.0, 0.0215, -0.128)
const Z_MUZZLE := -1.042
const PAN := Vector3(0.029, 0.0372, -0.1445)
const COCK_PIVOT := Vector3(0.030, 0.016, -0.098)
const FRIZZEN_PIVOT := Vector3(0.030, 0.0335, -0.168)
const CATCH_PIVOT := Vector3(0.0, -0.0205, -0.1005)
const LEFT_PALM := Vector3(-0.012, -0.002, -0.270)

static var _scene: PackedScene
static var _scene_checked := false
static var _mats := {}


## True when build() will use the imported Blender model.
static func has_glb() -> bool:
	if not _scene_checked:
		_scene_checked = true
		if ResourceLoader.exists(GLB_PATH):
			_scene = load(GLB_PATH) as PackedScene
	return _scene != null


## The model (the GLB, or the primitive fallback when it is missing or `fallback` is true).
static func build(fallback := false) -> Node3D:
	if not fallback and has_glb():
		var inst := _scene.instantiate()
		if inst is Node3D:
			var model := inst as Node3D
			model.name = ROOT_NAME
			_markers(model)
			var bad := check(model)
			if bad.is_empty():
				return model
			push_warning("over_under.glb breaks the node contract (%s); using the placeholder" % ", ".join(bad))
			model.free()
		elif inst:
			inst.free()
	return _fallback()


## Problems with a model's node contract ([] = fine).
static func check(model: Node3D) -> PackedStringArray:
	var bad := PackedStringArray()
	for n in ROOT_MARKERS:
		if not (model.get_node_or_null(n) is Marker3D):
			bad.append("no root marker " + n)
	var barrels := model.get_node_or_null("Barrels") as Node3D
	if barrels == null:
		bad.append("no Barrels")
		return bad
	for n in BARREL_MARKERS:
		if not (barrels.get_node_or_null(n) is Marker3D):
			bad.append("no Barrels/" + n)
	for n in ["FrizzenA", "FrizzenB"]:
		if not (barrels.get_node_or_null(n) is Node3D):
			bad.append("no Barrels/" + n)
	for n in ["Cock", "Catch"]:
		if not (model.get_node_or_null(n) is Node3D):
			bad.append("no " + n)
	return bad


## Makes the marker empties Marker3D nodes (same parent, transform and children).
static func _markers(model: Node3D) -> void:
	for n in ROOT_MARKERS:
		_to_marker(model, n)
	var barrels := model.find_child("Barrels", true, false) as Node3D
	if barrels:
		for n in BARREL_MARKERS:
			_to_marker(barrels, n)


static func _to_marker(parent: Node3D, node_name: String) -> void:
	var src := parent.get_node_or_null(NodePath(node_name)) as Node3D
	if src == null:
		src = parent.find_child(node_name, true, false) as Node3D
	if src == null or src is Marker3D:
		return
	var mk := Marker3D.new()
	var host := src.get_parent()
	mk.transform = src.transform
	for c in src.get_children():
		src.remove_child(c)
		mk.add_child(c)
	var idx := src.get_index()
	host.remove_child(src)
	src.free()
	mk.name = node_name
	host.add_child(mk)
	host.move_child(mk, idx)
	mk.owner = parent.owner if parent.owner else parent


# --- Primitive fallback (same nodes) -------------------------------------------------------

static func _mat(key: String, color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, node_name := "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	if node_name != "":
		m.name = node_name
	parent.add_child(m)
	return m


## Cylinder along Z from z0 to z1 at (x, y).
static func _tube(parent: Node3D, r0: float, r1: float, z0: float, z1: float, x: float, y: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r1
	c.bottom_radius = r0
	c.height = absf(z1 - z0)
	c.radial_segments = 10
	m.mesh = c
	m.material_override = mat
	m.rotation.x = PI / 2 if z1 > z0 else -PI / 2
	m.position = Vector3(x, y, (z0 + z1) * 0.5)
	parent.add_child(m)


static func _marker(parent: Node3D, node_name: String, pos: Vector3) -> Marker3D:
	var mk := Marker3D.new()
	mk.name = node_name
	mk.position = pos
	parent.add_child(mk)
	return mk


static func _fallback() -> Node3D:
	var walnut := _mat("walnut", Color(0.3, 0.17, 0.09), 0.0, 0.55)
	var brown := _mat("browned", Color(0.2, 0.13, 0.09), 0.7, 0.5)
	var iron := _mat("iron", Color(0.42, 0.42, 0.43), 0.9, 0.4)
	var brass := _mat("brass", Color(0.78, 0.6, 0.3), 0.9, 0.35)
	var root := Node3D.new()
	root.name = ROOT_NAME
	var body := Node3D.new()
	body.name = "OverUnder"
	root.add_child(body)
	_box(body, Vector3(0.04, 0.05, 0.12), Vector3(0, 0.02, -0.07), walnut)                        # Lock area.
	_box(body, Vector3(0.04, 0.05, 0.22), Vector3(0, -0.005, 0.04), walnut)                       # Wrist.
	_box(body, Vector3(0.05, 0.13, 0.30), Vector3(0, -0.06, 0.2), walnut).rotation.x = 0.18       # Butt.
	_box(body, Vector3(0.012, 0.035, 0.09), Vector3(0.026, 0.017, -0.075), iron)                  # Lock plate.
	_box(body, Vector3(0.012, 0.02, 0.07), Vector3(0, -0.035, -0.055), brass)                     # Guard.
	var cock := Node3D.new()
	cock.name = "Cock"
	cock.position = COCK_PIVOT
	root.add_child(cock)
	_box(cock, Vector3(0.008, 0.06, 0.012), Vector3(0, 0.03, -0.005), iron).rotation.x = -0.35
	var catch_node := Node3D.new()
	catch_node.name = "Catch"
	catch_node.position = CATCH_PIVOT
	root.add_child(catch_node)
	_box(catch_node, Vector3(0.004, 0.022, 0.005), Vector3(0, -0.011, -0.003), iron)
	var barrels := Node3D.new()
	barrels.name = "Barrels"
	barrels.position = SWIVEL
	root.add_child(barrels)
	var pair := Node3D.new()
	pair.name = "BarrelPair"
	barrels.add_child(pair)
	var dy_top := AXIS_Y - SWIVEL.y
	for s: float in [1.0, -1.0]:
		_tube(pair, 0.0133, 0.0108, 0.0, Z_MUZZLE - SWIVEL.z, 0.0, s * dy_top, brown)
		_box(pair, Vector3(0.012, 0.03, 0.074), Vector3(s * 0.019, s * 0.0, -0.037), iron)        # Pan plates.
		_box(pair, Vector3(0.008, 0.034, 0.42), Vector3(s * 0.016, 0.0, -0.28), walnut)           # Panels.
	for tag: String in ["A", "B"]:
		var f := Node3D.new()
		f.name = "Frizzen" + tag
		var p := FRIZZEN_PIVOT - SWIVEL
		if tag == "B":
			f.basis = Basis(Vector3.BACK, PI)
			p = Vector3(-p.x, -p.y, p.z)
		f.position = p
		barrels.add_child(f)
		_box(f, Vector3(0.02, 0.045, 0.006), Vector3(0, 0.025, 0.028), iron)
	var rod := Node3D.new()
	rod.name = "Ramrod"
	rod.position = Vector3(-0.012, 0.0, Z_MUZZLE + 0.014 - SWIVEL.z)
	barrels.add_child(rod)
	_tube(rod, 0.0045, 0.0045, 0.0, 0.668, 0.0, 0.0, _mat("hickory", Color(0.55, 0.4, 0.25)))
	_marker(barrels, "MuzzleA", Vector3(0, dy_top, Z_MUZZLE - SWIVEL.z))
	_marker(barrels, "MuzzleB", Vector3(0, -dy_top, Z_MUZZLE - SWIVEL.z))
	_marker(barrels, "PanA", PAN - SWIVEL)
	_marker(barrels, "PanB", Vector3(-(PAN.x - SWIVEL.x), -(PAN.y - SWIVEL.y), PAN.z - SWIVEL.z))
	var top := Vector3(0, AXIS_Y, Z_MUZZLE)
	var bot := Vector3(0, AXIS_Y - SPACING, Z_MUZZLE)
	var pan_b := Vector3(-PAN.x, 2.0 * SWIVEL.y - PAN.y, PAN.z)
	_marker(root, "Muzzle", top)
	_marker(root, "Pan", PAN)
	_marker(root, "Muzzle_top", top)
	_marker(root, "Muzzle_bottom", bot)
	_marker(root, "Pan_top", PAN)
	_marker(root, "Pan_bottom", pan_b)
	_marker(root, "LeftGrip", LEFT_PALM)
	return root
