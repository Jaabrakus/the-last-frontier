class_name WeaponModels
## Weapon meshes. build(kind) instances res://assets/weapons/<kind>.glb (made
## by tools/models/<kind>.py in Blender) once Godot has imported it, and falls
## back to the primitive placeholders below otherwise.
##
## Every model's origin is the grip (musket: wrist of the stock behind the
## trigger guard; pistol: the grip; bow: centre of the handle), forward is -Z,
## up is +Y, and it has a "Muzzle" Marker3D as a direct child where
## projectiles leave. glTF empties import as plain Node3D, so the loader swaps
## "Muzzle" (and, when present, "Pan" - the flintlock priming pan) for
## Marker3D nodes at the same transform.
##
## GLB extras: musket.glb has separate Cock / Frizzen (origins on their
## pivots), Ramrod (origin at its head) and a Pan marker; pistol.glb has a Pan
## marker; bow.glb has a separate String mesh and NockPoint / StringTop /
## StringBottom markers.

const GLB_DIR := "res://assets/weapons/"
## Empties that are turned into Marker3D children of the model root.
const MARKERS: Array[String] = ["Muzzle", "Pan"]

static var _mats := {}
static var _scenes := {}


static func build(kind: String) -> Node3D:
	var model := _from_glb(kind, kind.capitalize() + "Model", true)
	if model:
		return model
	match kind:
		"bow": return _bow()
		"musket": return _musket()
		"pistol": return _pistol()
	push_error("Unknown weapon model " + kind)
	return Node3D.new()


## Arrow for projectiles and quivers: origin at the tip of the point, flight
## direction -Z, shaft back along +Z to the nock at z = 0.72, up +Y (nock slot
## vertical, cock feather to -X). No Muzzle. Uses assets/weapons/arrow.glb
## (tools/models/arrow.py) when imported, else a primitive stand-in.
static func build_arrow() -> Node3D:
	var model := _from_glb("arrow", "ArrowModel", false)
	return model if model else _arrow()


## True when build(kind) will use the imported Blender model.
static func has_glb(kind: String) -> bool:
	return _scene(kind) != null


static func _scene(file: String) -> PackedScene:
	if not _scenes.has(file):
		var path := GLB_DIR + file + ".glb"
		var scene: PackedScene = null
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
		_scenes[file] = scene
	return _scenes[file]


## Instances <file>.glb, renames its root and makes the MARKERS empties
## Marker3D children of the root. Returns null (caller falls back to the
## primitive model) if the GLB is missing, not imported or lacks a Muzzle.
static func _from_glb(file: String, root_name: String, need_muzzle: bool) -> Node3D:
	var scene := _scene(file)
	if scene == null:
		return null
	var inst := scene.instantiate()
	if not (inst is Node3D):
		if inst:
			inst.free()
		push_warning("%s.glb did not import as a Node3D scene" % file)
		return null
	var model := inst as Node3D
	model.name = root_name
	for marker in MARKERS:
		if not _to_marker(model, marker) and marker == "Muzzle" and need_muzzle:
			push_warning("%s.glb has no Muzzle node; using the placeholder" % file)
			model.free()
			return null
	return model


## Replaces the node called `node_name` (anywhere under `model`) with a
## Marker3D child of `model` at the same model-space transform. Returns false
## if there is no such node.
static func _to_marker(model: Node3D, node_name: String) -> bool:
	var src := model.get_node_or_null(NodePath(node_name)) as Node3D
	if src == null:
		src = model.find_child(node_name, true, false) as Node3D
	if src == null:
		return false
	if src is Marker3D and src.get_parent() == model:
		return true
	var xf := Transform3D.IDENTITY
	var n: Node = src
	while n != model:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var mk := Marker3D.new()
	mk.transform = xf
	for c in src.get_children():
		src.remove_child(c)
		mk.add_child(c)
	src.get_parent().remove_child(src)
	src.free()
	mk.name = node_name
	model.add_child(mk)
	mk.owner = model
	return true


static func _mat(key: String, color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


static func _walnut() -> StandardMaterial3D:
	return _mat("walnut", Color(0.33, 0.19, 0.1), 0.0, 0.55)


static func _iron() -> StandardMaterial3D:
	return _mat("iron", Color(0.28, 0.28, 0.3), 0.85, 0.4)


static func _brass() -> StandardMaterial3D:
	return _mat("brass", Color(0.78, 0.6, 0.3), 0.9, 0.35)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	parent.add_child(m)
	return m


## Cylinder along Z from z0 to z1.
static func _tube(parent: Node3D, r0: float, r1: float, z0: float, z1: float, y: float, mat: Material, x := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r1
	c.bottom_radius = r0
	c.height = absf(z1 - z0)
	c.radial_segments = 10
	m.mesh = c
	m.material_override = mat
	m.rotation.x = -PI / 2      # Cylinder +Y -> -Z.
	m.position = Vector3(x, y, (z0 + z1) * 0.5)
	if z1 > z0:
		m.rotation.x = PI / 2
	parent.add_child(m)
	return m


static func _muzzle(parent: Node3D, pos: Vector3) -> void:
	var mk := Marker3D.new()
	mk.name = "Muzzle"
	mk.position = pos
	parent.add_child(mk)


## Longbow held at the grip; the limbs run along Y, arrows leave along -Z.
static func _bow() -> Node3D:
	var root := Node3D.new()
	root.name = "BowModel"
	var wood := _mat("yew", Color(0.55, 0.36, 0.18), 0.0, 0.5)
	var string_mat := _mat("string", Color(0.9, 0.87, 0.78))
	# Limbs: short segments bent back toward the archer (+Z).
	var segs := 7
	var half := 0.72
	for side: float in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for i in segs:
			var t := float(i + 1) / segs
			var p := Vector3(0, side * half * t, 0.16 * t * t)
			var mid := (prev + p) * 0.5
			var seg := MeshInstance3D.new()
			var c := CylinderMesh.new()
			var r_far := lerpf(0.016, 0.007, t)
			var r_near := lerpf(0.016, 0.007, t - 1.0 / segs)
			# Orient every segment with +Y pointing up so the arc is stable; on
			# the lower limb the far (thin) end is the bottom.
			c.top_radius = r_far if side > 0.0 else r_near
			c.bottom_radius = r_near if side > 0.0 else r_far
			c.height = prev.distance_to(p)
			c.radial_segments = 6
			seg.mesh = c
			seg.material_override = wood
			seg.position = mid
			var dir := (p - prev).normalized() * side
			seg.basis = Basis(Quaternion(Vector3.UP, dir))
			root.add_child(seg)
			prev = p
	# Leather grip.
	_tube(root, 0.021, 0.021, -0.06, 0.06, 0.0, _mat("leather", Color(0.25, 0.15, 0.08)))
	(root.get_child(root.get_child_count() - 1) as Node3D).rotation = Vector3.ZERO
	# String from tip to tip.
	var s := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.0015
	sc.bottom_radius = 0.0015
	sc.height = half * 2.0
	sc.radial_segments = 4
	s.mesh = sc
	s.material_override = string_mat
	s.position = Vector3(0, 0, 0.16)
	root.add_child(s)
	_muzzle(root, Vector3(0, 0.02, -0.05))
	return root


## Brown Bess (Long Land Pattern) placeholder; build("musket") prefers
## assets/weapons/musket.glb.
static func _musket() -> Node3D:
	var root := Node3D.new()
	root.name = "MusketModel"
	# Origin at the wrist of the stock (trigger hand). Barrel runs to -Z.
	_tube(root, 0.011, 0.009, -0.15, -1.2, 0.035, _iron())          # Barrel.
	_box(root, Vector3(0.045, 0.05, 1.0), Vector3(0, 0.01, -0.62), _walnut())   # Forestock.
	_box(root, Vector3(0.04, 0.05, 0.22), Vector3(0, -0.005, 0.02), _walnut())  # Wrist.
	_box(root, Vector3(0.05, 0.13, 0.36), Vector3(0, -0.06, 0.28), _walnut(), Vector3(0.18, 0, 0))  # Butt.
	_box(root, Vector3(0.052, 0.135, 0.02), Vector3(0, -0.085, 0.46), _brass(), Vector3(0.18, 0, 0))  # Butt plate.
	_box(root, Vector3(0.012, 0.045, 0.1), Vector3(0.028, 0.03, -0.1), _iron())   # Lock plate.
	_box(root, Vector3(0.01, 0.03, 0.012), Vector3(0.03, 0.065, -0.07), _iron(), Vector3(-0.4, 0, 0))  # Cock.
	_box(root, Vector3(0.012, 0.02, 0.07), Vector3(0, -0.035, -0.03), _brass())   # Trigger guard.
	_tube(root, 0.004, 0.004, -0.2, -1.15, -0.01, _mat("rod", Color(0.2, 0.2, 0.2), 0.7))   # Ramrod.
	_box(root, Vector3(0.005, 0.012, 0.01), Vector3(0, 0.05, -1.16), _iron())     # Front sight / bayonet lug.
	_muzzle(root, Vector3(0, 0.035, -1.21))
	return root


static func _pistol() -> Node3D:
	var root := Node3D.new()
	root.name = "PistolModel"
	# Origin at the grip. Barrel runs to -Z.
	_tube(root, 0.01, 0.009, -0.04, -0.3, 0.05, _iron())
	_box(root, Vector3(0.035, 0.035, 0.26), Vector3(0, 0.035, -0.15), _walnut())
	_box(root, Vector3(0.035, 0.11, 0.05), Vector3(0, -0.02, 0.04), _walnut(), Vector3(-0.35, 0, 0))
	_box(root, Vector3(0.04, 0.03, 0.035), Vector3(0, -0.075, 0.065), _brass(), Vector3(-0.35, 0, 0))   # Butt cap.
	_box(root, Vector3(0.01, 0.035, 0.07), Vector3(0.022, 0.05, -0.02), _iron())  # Lock.
	_box(root, Vector3(0.008, 0.025, 0.01), Vector3(0.024, 0.08, 0.0), _iron(), Vector3(-0.4, 0, 0))  # Cock.
	_box(root, Vector3(0.01, 0.018, 0.045), Vector3(0, 0.005, -0.01), _brass())   # Trigger guard.
	_muzzle(root, Vector3(0, 0.05, -0.31))
	return root


## Primitive arrow (same layout as the GLB): tip at the origin, shaft to +Z.
static func _arrow() -> Node3D:
	var root := Node3D.new()
	root.name = "ArrowModel"
	_tube(root, 0.0045, 0.0045, 0.04, 0.72, 0.0, _mat("shaft", Color(0.62, 0.48, 0.3)))
	_tube(root, 0.0, 0.01, 0.0, 0.045, 0.0, _mat("point", Color(0.2, 0.2, 0.22), 0.6, 0.5))
	_box(root, Vector3(0.028, 0.028, 0.13), Vector3(0, 0, 0.62), _mat("fletch", Color(0.9, 0.88, 0.82)))
	return root
