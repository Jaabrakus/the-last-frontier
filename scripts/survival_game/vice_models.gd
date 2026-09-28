class_name ViceModels
extends RefCounted
## The drink and the smoke, for the item icons (ItemIcons; the painter makes them sketches): rum, a squat bottle of dark
## green glass, corked; tobacco, a twist of dark cured leaf; the clay pipe, a long white stem with its bowl. Made of
## simple meshes, the models' Z the long way, +Y up, as the other item models. The rest of the time's vices: whiskey, a
## tall square case bottle of amber glass; cider, a salt-glazed stoneware jug, corked (sweet cider the same jug, a cloth
## tied over its mouth); laudanum, a small brown vial with its paper label; snuff, a flat round tin; a quid, a short dark
## plug of twist; kinnikinnick, a leather pouch of rubbed leaves and bark (with tobacco, darker).

const ITEMS := ["rum", "tobacco", "clay_pipe", "whiskey", "cider", "sweet_cider", "laudanum", "snuff", "chew",
		"kinnikinnick", "kinnikinnick_mix"]


static func has(kind: String) -> bool:
	return kind in ITEMS


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind
	match kind:
		"rum":
			var glass := _mat(Color(0.12, 0.26, 0.14), 0.25, 0.1)
			_cyl(root, 0.05, 0.05, 0.13, Vector3(0, 0.065, 0), Vector3.ZERO, glass)            # the body
			_cyl(root, 0.02, 0.05, 0.035, Vector3(0, 0.1475, 0), Vector3.ZERO, glass)           # the shoulder
			_cyl(root, 0.014, 0.014, 0.045, Vector3(0, 0.187, 0), Vector3.ZERO, glass)          # the neck
			_cyl(root, 0.017, 0.017, 0.008, Vector3(0, 0.21, 0), Vector3.ZERO, glass)           # the lip
			_cyl(root, 0.012, 0.013, 0.03, Vector3(0, 0.222, 0), Vector3.ZERO, _mat(Color(0.55, 0.4, 0.24), 0.9))   # the cork
		"tobacco":
			# three strands of cured leaf twisted round each other, the ends tapered
			var leaf := _mat(Color(0.33, 0.2, 0.1), 0.85)
			for i in 3:
				var a := TAU * i / 3.0
				for j in 7:
					var z := -0.075 + j * 0.025
					var t := a + z * 18.0
					var r := 0.012 * (1.0 - absf(z) / 0.1)
					var s := SphereMesh.new()
					s.radius = 0.014 * (1.0 - absf(z) * 4.0) + 0.006
					s.height = 0.04
					var mi := MeshInstance3D.new()
					mi.mesh = s
					mi.material_override = leaf
					mi.position = Vector3(cos(t) * r, sin(t) * r, z)
					mi.rotation = Vector3(0, 0, t)
					root.add_child(mi)
		"whiskey":
			var amber := _mat(Color(0.62, 0.38, 0.14), 0.2, 0.05)
			var box := BoxMesh.new()
			box.size = Vector3(0.07, 0.15, 0.07)
			var bm := MeshInstance3D.new()
			bm.mesh = box
			bm.material_override = amber
			bm.position = Vector3(0, 0.075, 0)
			root.add_child(bm)
			_cyl(root, 0.012, 0.035, 0.03, Vector3(0, 0.165, 0), Vector3.ZERO, amber)         # the shoulder
			_cyl(root, 0.012, 0.012, 0.03, Vector3(0, 0.195, 0), Vector3.ZERO, amber)          # the neck
			_cyl(root, 0.011, 0.012, 0.022, Vector3(0, 0.215, 0), Vector3.ZERO, _mat(Color(0.55, 0.4, 0.24), 0.9))
		"cider", "sweet_cider":
			var ware := _mat(Color(0.6, 0.47, 0.32) if kind == "cider" else Color(0.72, 0.62, 0.46), 0.45)
			_cyl(root, 0.045, 0.05, 0.06, Vector3(0, 0.03, 0), Vector3.ZERO, ware)             # the belly
			_cyl(root, 0.022, 0.045, 0.05, Vector3(0, 0.085, 0), Vector3.ZERO, ware)           # the shoulder
			_cyl(root, 0.016, 0.018, 0.025, Vector3(0, 0.122, 0), Vector3.ZERO, ware)          # the neck
			var handle := TorusMesh.new()
			handle.inner_radius = 0.018
			handle.outer_radius = 0.025
			var hm := MeshInstance3D.new()
			hm.mesh = handle
			hm.material_override = ware
			hm.position = Vector3(0, 0.09, 0.04)
			hm.rotation = Vector3(0, PI * 0.5, PI * 0.5)
			root.add_child(hm)
			if kind == "cider":
				_cyl(root, 0.013, 0.015, 0.022, Vector3(0, 0.14, 0), Vector3.ZERO, _mat(Color(0.55, 0.4, 0.24), 0.9))
			else:
				_cyl(root, 0.024, 0.02, 0.012, Vector3(0, 0.138, 0), Vector3.ZERO, _mat(Color(0.9, 0.87, 0.78), 0.95))
		"laudanum":
			var brown := _mat(Color(0.3, 0.16, 0.08), 0.2, 0.05)
			_cyl(root, 0.018, 0.018, 0.06, Vector3(0, 0.03, 0), Vector3.ZERO, brown)
			_cyl(root, 0.0185, 0.0185, 0.03, Vector3(0, 0.03, 0), Vector3.ZERO, _mat(Color(0.92, 0.88, 0.76), 0.9))   # the label
			_cyl(root, 0.008, 0.012, 0.012, Vector3(0, 0.066, 0), Vector3.ZERO, brown)
			_cyl(root, 0.008, 0.008, 0.014, Vector3(0, 0.078, 0), Vector3.ZERO, _mat(Color(0.55, 0.4, 0.24), 0.9))
		"snuff":
			var tin := _mat(Color(0.5, 0.47, 0.42), 0.35, 0.7)
			_cyl(root, 0.035, 0.035, 0.016, Vector3(0, 0.008, 0), Vector3.ZERO, tin)
			_cyl(root, 0.036, 0.036, 0.006, Vector3(0, 0.018, 0), Vector3.ZERO, _mat(Color(0.56, 0.52, 0.44), 0.3, 0.7))
		"chew":
			var dark := _mat(Color(0.22, 0.13, 0.07), 0.8)
			for i in 3:
				var a := TAU * i / 3.0
				for j in 4:
					var z := -0.03 + j * 0.02
					var t := a + z * 22.0
					var s := SphereMesh.new()
					s.radius = 0.012
					s.height = 0.03
					var mi := MeshInstance3D.new()
					mi.mesh = s
					mi.material_override = dark
					mi.position = Vector3(cos(t) * 0.008, sin(t) * 0.008, z)
					root.add_child(mi)
		"kinnikinnick", "kinnikinnick_mix":
			var leather := _mat(Color(0.5, 0.36, 0.22) if kind == "kinnikinnick" else Color(0.32, 0.22, 0.14), 0.85)
			var pouch := SphereMesh.new()
			pouch.radius = 0.045
			pouch.height = 0.075
			var pm := MeshInstance3D.new()
			pm.mesh = pouch
			pm.material_override = leather
			pm.position = Vector3(0, 0.035, 0)
			root.add_child(pm)
			_cyl(root, 0.022, 0.03, 0.02, Vector3(0, 0.075, 0), Vector3.ZERO, leather)          # the gathered mouth
			var fill := _mat(Color(0.36, 0.3, 0.16) if kind == "kinnikinnick" else Color(0.26, 0.17, 0.09), 0.9)
			_cyl(root, 0.02, 0.02, 0.006, Vector3(0, 0.086, 0), Vector3.ZERO, fill)            # the mix at the mouth
			_cyl(root, 0.004, 0.004, 0.05, Vector3(0.02, 0.08, 0), Vector3(0, 0, 1.2), _mat(Color(0.3, 0.2, 0.12), 0.9))   # the string
		"clay_pipe":
			var clay := _mat(Color(0.9, 0.87, 0.8), 0.7)
			_cyl(root, 0.0045, 0.0055, 0.3, Vector3(0, 0, -0.02), Vector3(PI * 0.5, 0, 0), clay)   # the stem along Z
			_cyl(root, 0.013, 0.009, 0.034, Vector3(0, 0.014, 0.135), Vector3(-0.35, 0, 0), clay)  # the bowl
	return root


static func _mat(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _cyl(parent: Node3D, top: float, bottom: float, h: float, at: Vector3, rot: Vector3, mat: Material) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
