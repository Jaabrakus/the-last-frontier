class_name ThrowableModels
## Meshes for the thrown weapons, kept apart from WeaponModels (which the
## firearms and the bow use). build(kind) instances res://assets/weapons/<kind>.glb
## (made by tools/models/spear.py, tomahawk.py, atlatl.py in Blender) once Godot
## has imported it, and falls back to the primitive stand-ins below otherwise.
##
## Kinds and conventions (Godot axes; up +Y):
##   "spear"        throwing spear. Origin at the hand grip, which is also the
##                  balance point (COM, computed by spear.py from the part masses:
##                  55% of the length from the butt); point toward -Z, blade flats
##                  facing +/-Y. Markers: Muzzle and Tip (both at the point, written
##                  from one value), COM, Butt. The stroud tails and hair tuft are a
##                  separate child mesh "Trim" pivoted at the tie's knot (+X side),
##                  hanging back and at most 5 cm down at rest; ThrownProjectile
##                  re-hangs it (streamed back in flight, laid out when lying).
##   "tomahawk"     trade tomahawk (spike on the poll). Origin at the throwing grip,
##                  6.2 cm above the haft end; the haft runs up +Y into the head, the
##                  cutting edge faces -Z (the way it is swung and thrown, blade leading),
##                  the poll points to +Z. Markers: Muzzle, Blade and Edge (all the middle
##                  of the cutting edge), Head (eye centre), COM, Butt (haft end).
##   "tomahawk_pipe" pipe tomahawk variant from the same tomahawk.glb (VARIANT_KINDS):
##                  same axes and markers, pipe bowl on the poll, plus Mouthpiece.
##   "atlatl"       spear-thrower board. Origin at the grip (front end); the board runs
##                  back along +Z to the carved hook. Markers: Spur (where the dart's
##                  butt sits), Muzzle (tip of a loaded dart), COM.
##   "atlatl_dart"  dart. Origin at the tip of the stone point (like the arrow), shaft
##                  back along +Z to the nock cup at z = DART_LENGTH. Markers: COM, Nock.
##
## glTF empties import as plain Node3D; like WeaponModels, the loader turns every
## marker into a Marker3D that is a direct child of the model root, at the same
## model-space transform, so scripts can read them with get_node("Muzzle").

const GLB_DIR := "res://assets/weapons/"
const MARKERS: Array[String] = ["Muzzle", "Tip", "COM", "Butt", "Edge", "Blade", "Head", "Mouthpiece", "Spur", "Nock"]
const KINDS: Array[String] = ["spear", "tomahawk", "atlatl", "atlatl_dart"]
## GLBs that hold several mesh variants as top-level nodes. The first is the default;
## the others are exported hidden (KHR_node_visibility). build() keeps one, frees the rest.
const VARIANTS := {"tomahawk": ["Tomahawk", "TomahawkPipe"]}
## Extra kinds that build a variant: kind -> [glb file, node to keep].
const VARIANT_KINDS := {"tomahawk_pipe": ["tomahawk", "TomahawkPipe"]}

## Dimensions shared with the Blender generators (metres). The primitive
## stand-ins and the projectile code use the same numbers.
const SPEAR_TIP := 0.807         ## Grip/COM -> point (spear.py prints TIP).
const SPEAR_BUTT := 0.993        ## Grip/COM -> butt end (spear.py prints BUTT).
const TOMAHAWK_HEAD_Y := 0.401   ## Grip -> centre of the eye (tomahawk.py HEAD_Y).
const TOMAHAWK_COM := Vector3(0.0, 0.3192, -0.0134)   ## tomahawk.py prints "COM marker".
const TOMAHAWK_EDGE := Vector3(0.0, 0.3875, -0.124)   ## Middle of the cutting edge.
const ATLATL_SPUR := Vector3(0.0, 0.02, 0.526)
const DART_LENGTH := 1.65        ## Tip -> nock (atlatl.py DART_LEN).
const DART_COM_Z := 0.693       ## Tip -> dart balance point (atlatl.py prints COM).
const ATLATL_COM := Vector3(0.0, -0.0005, 0.2536)   ## atlatl.py prints COM (board + bannerstone + cap).

static var _mats := {}
static var _scenes := {}


## A fresh model for `kind` (one of KINDS or VARIANT_KINDS). Never null.
static func build(kind: String) -> Node3D:
	var file := _file_of(kind)
	var keep: String = VARIANT_KINDS[kind][1] if VARIANT_KINDS.has(kind) else ""
	var model := _from_glb(file, kind.to_pascal_case() + "Model", keep)
	if model:
		return model
	match file:
		"spear": return _spear()
		"tomahawk": return _tomahawk()
		"atlatl": return _atlatl()
		"atlatl_dart": return _atlatl_dart()
	push_error("Unknown throwable model " + kind)
	return Node3D.new()


## True when build(kind) will use the imported Blender model.
static func has_glb(kind: String) -> bool:
	return _scene(_file_of(kind)) != null


static func _file_of(kind: String) -> String:
	return VARIANT_KINDS[kind][0] if VARIANT_KINDS.has(kind) else kind


## Model-space position of a marker (Vector3.ZERO when the model lacks it).
static func marker_pos(model: Node3D, marker: String) -> Vector3:
	var m := model.get_node_or_null(marker) as Node3D
	return m.position if m else Vector3.ZERO


static func _scene(file: String) -> PackedScene:
	if not _scenes.has(file):
		var path := GLB_DIR + file + ".glb"
		var scene: PackedScene = null
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
		_scenes[file] = scene
	return _scenes[file]


static func _from_glb(file: String, root_name: String, keep := "") -> Node3D:
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
	_pick_variant(model, file, keep)
	for marker in MARKERS:
		_to_marker(model, marker)
	# Every thrown weapon needs its COM; the held weapons need a Muzzle.
	if model.get_node_or_null("COM") == null or (file != "atlatl_dart" and model.get_node_or_null("Muzzle") == null):
		push_warning("%s.glb lacks the COM/Muzzle markers; using the placeholder" % file)
		model.free()
		return null
	return model


## Keeps one mesh variant of a VARIANTS GLB (`keep`, or the first) and frees the others,
## before the markers are collected (so a variant's own markers go with it).
static func _pick_variant(model: Node3D, file: String, keep: String) -> void:
	if not VARIANTS.has(file):
		return
	var names: Array = VARIANTS[file]
	var chosen: String = keep if keep != "" else names[0]
	for n: String in names:
		var v := model.get_node_or_null(NodePath(n)) as Node3D
		if v == null:
			continue
		if n == chosen:
			v.visible = true
		else:
			model.remove_child(v)
			v.free()


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


# --- Primitive stand-ins ------------------------------------------------------------

static func _mat(key: String, color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


static func _marker(parent: Node3D, marker_name: String, pos: Vector3) -> void:
	var mk := Marker3D.new()
	mk.name = marker_name
	mk.position = pos
	parent.add_child(mk)


## Cylinder from a to b (radius r0 at a, r1 at b).
static func _rod(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material, sides := 8) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = a.distance_to(b)
	c.radial_segments = sides
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	var d := (b - a).normalized()
	m.basis = Basis(Quaternion(Vector3.UP, d)) if d.dot(Vector3.UP) > -0.999 else Basis(Vector3.RIGHT, PI)
	m.position = (a + b) * 0.5
	parent.add_child(m)
	return m


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


static func _ash() -> StandardMaterial3D:
	return _mat("ash", Color(0.62, 0.47, 0.3), 0.0, 0.6)


static func _iron() -> StandardMaterial3D:
	return _mat("forged_iron", Color(0.2, 0.19, 0.18), 0.75, 0.45)


static func _leather() -> StandardMaterial3D:
	return _mat("leather", Color(0.32, 0.2, 0.11), 0.0, 0.8)


static func _spear() -> Node3D:
	var root := Node3D.new()
	root.name = "SpearModel"
	var tip := Vector3(0, 0, -SPEAR_TIP)
	_rod(root, Vector3(0, 0, SPEAR_BUTT), Vector3(0, 0, -SPEAR_TIP + 0.24), 0.0105, 0.012, _ash())
	_rod(root, Vector3(0, 0, -SPEAR_TIP + 0.25), Vector3(0, 0, -SPEAR_TIP + 0.17), 0.013, 0.011, _iron())
	_box(root, Vector3(0.036, 0.006, 0.17), Vector3(0, 0, -SPEAR_TIP + 0.09), _iron())
	_rod(root, Vector3(0, 0, -SPEAR_TIP + 0.02), tip, 0.008, 0.0005, _iron(), 4)
	_rod(root, Vector3(0, 0, -0.08), Vector3(0, 0, 0.08), 0.0135, 0.0135, _leather())
	_marker(root, "Muzzle", tip)
	_marker(root, "Tip", tip)
	_marker(root, "COM", Vector3.ZERO)
	_marker(root, "Butt", Vector3(0, 0, SPEAR_BUTT))
	return root


static func _tomahawk() -> Node3D:
	var root := Node3D.new()
	root.name = "TomahawkModel"
	_rod(root, Vector3(0, -0.07, 0), Vector3(0, TOMAHAWK_HEAD_Y + 0.02, 0), 0.0135, 0.0125, _mat("hickory", Color(0.48, 0.32, 0.18), 0.0, 0.55))
	_rod(root, Vector3(0, -0.04, 0), Vector3(0, 0.07, 0), 0.0155, 0.0155, _leather())
	_box(root, Vector3(0.03, 0.04, 0.05), Vector3(0, TOMAHAWK_HEAD_Y, 0.0), _iron())          # Eye.
	_box(root, Vector3(0.008, 0.07, 0.1), Vector3(0, TOMAHAWK_HEAD_Y - 0.01, -0.07), _iron())  # Blade.
	_rod(root, Vector3(0, TOMAHAWK_HEAD_Y - 0.01, 0.03), Vector3(0, TOMAHAWK_HEAD_Y + 0.04, 0.045), 0.012, 0.015, _mat("brass", Color(0.72, 0.55, 0.28), 0.85, 0.35))
	_marker(root, "Muzzle", TOMAHAWK_EDGE)
	_marker(root, "Blade", TOMAHAWK_EDGE)
	_marker(root, "Edge", TOMAHAWK_EDGE)
	_marker(root, "Head", Vector3(0, TOMAHAWK_HEAD_Y, 0))
	_marker(root, "COM", TOMAHAWK_COM)
	_marker(root, "Butt", Vector3(0, -0.062, 0))
	_marker(root, "Mouthpiece", Vector3(0, -0.07, 0))
	return root


static func _atlatl() -> Node3D:
	var root := Node3D.new()
	root.name = "AtlatlModel"
	_box(root, Vector3(0.034, 0.012, ATLATL_SPUR.z + 0.05), Vector3(0, 0, ATLATL_SPUR.z * 0.5 - 0.01), _mat("maple", Color(0.66, 0.5, 0.32), 0.0, 0.55))
	_rod(root, Vector3(0, 0.006, ATLATL_SPUR.z + 0.01), Vector3(0, 0.033, ATLATL_SPUR.z - 0.007), 0.006, 0.002, _mat("antler", Color(0.85, 0.8, 0.7), 0.0, 0.5))
	_box(root, Vector3(0.09, 0.022, 0.035), Vector3(0, -0.012, 0.24), _mat("slate", Color(0.22, 0.25, 0.26), 0.0, 0.3))   # Bannerstone.
	_rod(root, Vector3(0, 0, -0.03), Vector3(0, 0, 0.07), 0.02, 0.02, _leather())
	_marker(root, "Spur", ATLATL_SPUR)
	_marker(root, "Muzzle", ATLATL_SPUR - Vector3(0, 0, DART_LENGTH))
	_marker(root, "COM", ATLATL_COM)
	return root


static func _atlatl_dart() -> Node3D:
	var root := Node3D.new()
	root.name = "AtlatlDartModel"
	_rod(root, Vector3(0, 0, 0.05), Vector3(0, 0, DART_LENGTH), 0.0055, 0.0065, _mat("cane", Color(0.7, 0.6, 0.38), 0.0, 0.6))
	_rod(root, Vector3(0, 0, 0.055), Vector3(0, 0, 0.0), 0.012, 0.0005, _mat("chert", Color(0.55, 0.52, 0.47), 0.0, 0.45), 4)
	_box(root, Vector3(0.03, 0.03, 0.16), Vector3(0, 0, DART_LENGTH - 0.12), _mat("fletch", Color(0.35, 0.28, 0.22)))
	_marker(root, "COM", Vector3(0, 0, DART_COM_Z))
	_marker(root, "Nock", Vector3(0, 0, DART_LENGTH))
	return root
