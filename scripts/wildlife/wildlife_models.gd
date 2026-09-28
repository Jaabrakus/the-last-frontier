class_name WildlifeModels
extends RefCounted
## Procedural models of the wildlife items for the inventory icons (ItemIcons: the camera looks at a model's side from
## +X, up +Y): the skinning knife, venison, a deer hide, wolf and fox pelts, an antler, the bison's robe, its tallow and
## its tongue. The project's own (no assets).

const KINDS := ["skinning_knife", "venison", "deer_hide", "wolf_pelt", "fox_pelt", "antler", "fire_steel", "bison_robe",
		"tallow", "tongue"]


static func has(kind: String) -> bool:
	return kind in KINDS


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind
	match kind:
		"skinning_knife":
			# a trade knife: a broad, slightly drooping blade, brass bolster, a hardwood handle; laid diagonally
			var k := Node3D.new()
			k.rotation.x = deg_to_rad(-40.0)
			root.add_child(k)
			_box(k, Vector3(0.012, 0.028, 0.15), Vector3(0, 0.0, -0.09), _mat(Color(0.72, 0.73, 0.74), 0.35, 0.8))
			_box(k, Vector3(0.012, 0.012, 0.04), Vector3(0, -0.012, -0.17), _mat(Color(0.72, 0.73, 0.74), 0.35, 0.8))
			_box(k, Vector3(0.02, 0.036, 0.012), Vector3(0, 0.0, -0.01), _mat(Color(0.76, 0.6, 0.28), 0.4, 0.9))
			_box(k, Vector3(0.022, 0.03, 0.11), Vector3(0, 0.0, 0.05), _mat(Color(0.33, 0.2, 0.11), 0.8, 0.0))
		"venison":
			var m := _sphere(root, Vector3(0.05, 0.08, 0.11), Vector3.ZERO, _mat(Color(0.55, 0.13, 0.11), 0.6, 0.0))
			m.rotation.x = deg_to_rad(20.0)
			_sphere(root, Vector3(0.045, 0.02, 0.1), Vector3(0.012, 0.065, -0.01), _mat(Color(0.92, 0.86, 0.76), 0.7, 0.0))
		"deer_hide":
			_hide(root, Color(0.52, 0.36, 0.22), Color(0.82, 0.74, 0.6), 1.0, false)
		"wolf_pelt":
			_hide(root, Color(0.46, 0.44, 0.4), Color(0.78, 0.76, 0.72), 0.95, true)
		"fox_pelt":
			_hide(root, Color(0.78, 0.36, 0.12), Color(0.95, 0.92, 0.88), 0.6, true)
		"bison_robe":
			# the winter robe: dark woolly brown, the hump's hair longer and near black, the flesh side pale
			_hide(root, Color(0.2, 0.13, 0.08), Color(0.36, 0.25, 0.16), 1.25, false)
			_sphere(root, Vector3(0.1, 0.02, 0.14), Vector3(0.0, 0.02, -0.03), _mat(Color(0.1, 0.07, 0.05), 1.0, 0.0))
		"tallow":
			# rendered fat in a cake, a little yellow, a knife's cut across it
			var cake := _box(root, Vector3(0.1, 0.05, 0.13), Vector3.ZERO, _mat(Color(0.93, 0.89, 0.74), 0.55, 0.0))
			cake.rotation.y = 0.3
			_box(root, Vector3(0.102, 0.004, 0.02), Vector3(0.0, 0.026, 0.02), _mat(Color(0.8, 0.74, 0.58), 0.6, 0.0))
		"tongue":
			# a buffalo tongue, the plains' delicacy: long, rounded, dark on top
			var t := _sphere(root, Vector3(0.04, 0.03, 0.12), Vector3.ZERO, _mat(Color(0.62, 0.3, 0.3), 0.55, 0.0))
			t.rotation.x = deg_to_rad(8.0)
			_sphere(root, Vector3(0.035, 0.012, 0.1), Vector3(0.0, 0.022, -0.01), _mat(Color(0.36, 0.2, 0.2), 0.7, 0.0))
		"fire_steel":
			# a C-shaped steel striker and a chip of flint (the campfire's lighter, Campfire)
			var steel := _mat(Color(0.3, 0.3, 0.32), 0.45, 0.85)
			_box(root, Vector3(0.012, 0.022, 0.13), Vector3(0, -0.03, 0), steel)
			for sz: float in [-1.0, 1.0]:
				var hook := _box(root, Vector3(0.012, 0.05, 0.018), Vector3(0, 0.0, 0.065 * sz), steel)
				hook.rotation.x = 0.35 * sz
			var chip := _sphere(root, Vector3(0.03, 0.022, 0.035), Vector3(0.004, 0.035, 0.0), _mat(Color(0.42, 0.4, 0.38), 0.3, 0.0))
			chip.rotation = Vector3(0.4, 0.2, 0.1)
		"antler":
			var bone := _mat(Color(0.82, 0.74, 0.6), 0.7, 0.0)
			var beam := [Vector3(0, -0.12, 0.02), Vector3(0, 0.0, -0.02), Vector3(0, 0.1, 0.05), Vector3(0, 0.16, 0.14)]
			for i in beam.size() - 1:
				_limb(root, beam[i], beam[i + 1], 0.012 - i * 0.002, bone)
			for tine: Array in [[1, Vector3(0, 0.09, -0.07)], [2, Vector3(0, 0.2, 0.0)], [2, Vector3(0, 0.21, 0.09)]]:
				_limb(root, beam[int(tine[0])], tine[1], 0.007, bone)
	return root


static func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, radii: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.scale = radii
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _limb(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r * 0.8
	c.bottom_radius = r
	c.height = a.distance_to(b)
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	var up := (b - a).normalized()
	var side := up.cross(Vector3.RIGHT)
	if side.length_squared() < 1e-6:
		side = up.cross(Vector3.FORWARD)
	side = side.normalized()
	mi.basis = Basis(side, up, side.cross(up))


## A stretched hide seen flat (in the YZ plane, facing +X): body, four leg tabs, a neck, the paler belly in the middle,
## a tail for the pelts.
static func _hide(parent: Node3D, back: Color, belly: Color, size: float, tail: bool) -> void:
	var s := size
	var m_back := _mat(back, 0.95, 0.0)
	var m_belly := _mat(belly, 0.95, 0.0)
	_box(parent, Vector3(0.01, 0.2 * s, 0.3 * s), Vector3.ZERO, m_back)
	_box(parent, Vector3(0.012, 0.09 * s, 0.22 * s), Vector3.ZERO, m_belly)
	for leg: Vector3 in [Vector3(0, 0.12, 0.13), Vector3(0, -0.12, 0.13), Vector3(0, 0.12, -0.12), Vector3(0, -0.12, -0.12)]:
		var t := _box(parent, Vector3(0.01, 0.1 * s, 0.035 * s), leg * s, m_back)
		t.rotation.x = deg_to_rad(25.0 if leg.y > 0.0 else -25.0) * (1.0 if leg.z > 0.0 else -1.0)
	_box(parent, Vector3(0.01, 0.06 * s, 0.08 * s), Vector3(0, 0, -0.19) * s, m_back)
	if tail:
		_box(parent, Vector3(0.01, 0.045 * s, 0.14 * s), Vector3(0, 0, 0.21) * s, m_back)
		_box(parent, Vector3(0.012, 0.04 * s, 0.04 * s), Vector3(0, 0, 0.28) * s, m_belly)
