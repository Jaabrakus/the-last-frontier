class_name ProvisionModels
extends RefCounted
## Small models of the kit's provisions for their pack icons (ItemIcons; project-made): jerky, a few dark strips of dried
## meat; cornmeal, a tied linen bag; and what a campfire makes of them (CampCooking): johnnycake, two flat cakes baked in
## the ashes; roast venison, a browned joint on its spit stick; burnt, the same gone black. The icon camera looks at a
## model's side from +X, so they stand up to it.

const ITEMS := ["jerky", "cornmeal", "johnnycake", "burnt_johnnycake", "roast_venison", "charred_venison",
		"brains", "buckskin", "rawhide", "plantain_salve", "wintergreen_tea", "ginseng_tonic", "sinew",
		"willow_bark_tea", "slippery_elm_gruel", "elderberry_syrup"]

static var _mats := {}


static func has(item: String) -> bool:
	return item in ITEMS


static func build(item: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Provision_" + item
	match item:
		"jerky":
			# four strips of dried meat, fanned, uneven
			for i in 4:
				var b := BoxMesh.new()
				b.size = Vector3(0.006, 0.13 - 0.012 * i, 0.028 + 0.004 * (i % 2))
				var mi := MeshInstance3D.new()
				mi.mesh = b
				mi.material_override = _mat("jerky%d" % (i % 2), Color(0.32, 0.14, 0.08) if i % 2 == 0 else Color(0.26, 0.11, 0.07), 0.55)
				mi.position = Vector3(0.004 * i, 0.0, (i - 1.5) * 0.02)
				mi.rotation = Vector3(deg_to_rad(-18.0 + 12.0 * i), 0.0, 0.0)
				root.add_child(mi)
		"cornmeal":
			# a linen bag, full at the bottom, gathered and tied at the neck
			var body := SphereMesh.new()
			body.radius = 0.06
			body.height = 0.11
			body.radial_segments = 14
			body.rings = 8
			var bag := MeshInstance3D.new()
			bag.mesh = body
			bag.material_override = _mat("linen", Color(0.78, 0.72, 0.58), 0.95)
			root.add_child(bag)
			var neck := CylinderMesh.new()
			neck.top_radius = 0.028
			neck.bottom_radius = 0.018
			neck.height = 0.05
			neck.radial_segments = 10
			var n := MeshInstance3D.new()
			n.mesh = neck
			n.material_override = bag.material_override
			n.position = Vector3(0.0, 0.07, 0.0)
			root.add_child(n)
			var tie := TorusMesh.new()
			tie.inner_radius = 0.017
			tie.outer_radius = 0.022
			var t := MeshInstance3D.new()
			t.mesh = tie
			t.material_override = _mat("cord", Color(0.4, 0.3, 0.18), 0.9)
			t.position = Vector3(0.0, 0.058, 0.0)
			root.add_child(t)
		"johnnycake", "burnt_johnnycake":
			# two flat cakes, one leaning on the other, their faces to the camera
			var burnt := item == "burnt_johnnycake"
			for i in 2:
				var cake := CylinderMesh.new()
				cake.top_radius = 0.055 - 0.006 * i
				cake.bottom_radius = 0.058 - 0.006 * i
				cake.height = 0.016
				cake.radial_segments = 18
				var c := MeshInstance3D.new()
				c.mesh = cake
				var col := Color(0.2, 0.13, 0.08) if burnt else (Color(0.74, 0.52, 0.24) if i == 0 else Color(0.66, 0.44, 0.19))
				c.material_override = _mat("cake%d%s" % [i, "b" if burnt else ""], col, 0.9)
				c.rotation = Vector3(0.0, 0.0, deg_to_rad(90.0 - 14.0 * i))
				c.position = Vector3(-0.012 * i, 0.012 * i, 0.03 * i - 0.015)
				root.add_child(c)
		"roast_venison", "charred_venison":
			# a browned joint of meat on its spit stick
			var black := item == "charred_venison"
			var joint := SphereMesh.new()
			joint.radius = 0.05
			joint.height = 0.1
			joint.radial_segments = 14
			joint.rings = 8
			var j := MeshInstance3D.new()
			j.mesh = joint
			j.scale = Vector3(0.8, 0.85, 1.3)
			j.material_override = _mat("roast%s" % ("c" if black else ""), Color(0.13, 0.08, 0.06) if black else Color(0.46, 0.22, 0.1), 0.6)
			j.rotation = Vector3(deg_to_rad(-25.0), 0.0, 0.0)
			root.add_child(j)
			var stick := CylinderMesh.new()
			stick.top_radius = 0.005
			stick.bottom_radius = 0.006
			stick.height = 0.2
			stick.radial_segments = 6
			var st := MeshInstance3D.new()
			st.mesh = stick
			st.material_override = _mat("spit", Color(0.36, 0.27, 0.17), 0.95)
			st.rotation = Vector3(deg_to_rad(65.0), 0.0, 0.0)
			root.add_child(st)
		"brains":
			# two pale lobes
			for i in 2:
				var lobe := SphereMesh.new()
				lobe.radius = 0.035
				lobe.height = 0.06
				var l := MeshInstance3D.new()
				l.mesh = lobe
				l.scale = Vector3(1.0, 0.8, 1.3)
				l.material_override = _mat("brains", Color(0.78, 0.6, 0.58), 0.5)
				l.position = Vector3(0.0, 0.0, (i - 0.5) * 0.05)
				root.add_child(l)
		"buckskin":
			# a soft hide folded over, its edge ragged
			for i in 2:
				var b := BoxMesh.new()
				b.size = Vector3(0.012, 0.1 - 0.02 * i, 0.13)
				var mi := MeshInstance3D.new()
				mi.mesh = b
				mi.material_override = _mat("buck%d" % i, Color(0.8, 0.66, 0.46) if i == 0 else Color(0.72, 0.58, 0.4), 0.95)
				mi.position = Vector3(0.008 * i, -0.01 * i, 0.01 * i)
				mi.rotation = Vector3(deg_to_rad(-8.0 + 16.0 * i), 0.0, 0.0)
				root.add_child(mi)
		"rawhide":
			# a coil of lacing
			for i in 3:
				var t := TorusMesh.new()
				t.inner_radius = 0.04 - 0.006 * i
				t.outer_radius = 0.047 - 0.006 * i
				var mi := MeshInstance3D.new()
				mi.mesh = t
				mi.material_override = _mat("rawhide", Color(0.84, 0.74, 0.54), 0.7)
				mi.rotation = Vector3(0.0, 0.0, deg_to_rad(90.0))
				mi.position = Vector3(0.004 * i, 0.0, 0.0)
				root.add_child(mi)
		"plantain_salve":
			# a small crock, the green salve showing at its mouth
			_part(root, 0.045, 0.05, 0.07, Vector3.ZERO, _mat("crock", Color(0.62, 0.5, 0.34), 0.6))
			_part(root, 0.04, 0.04, 0.006, Vector3(0.0, 0.037, 0.0), _mat("salve", Color(0.3, 0.44, 0.2), 0.4))
		"wintergreen_tea":
			# a tin cup of dark tea, a sprig of leaves
			_part(root, 0.042, 0.038, 0.08, Vector3.ZERO, _mat("tin", Color(0.62, 0.62, 0.6), 0.35))
			_part(root, 0.038, 0.038, 0.004, Vector3(0.0, 0.035, 0.0), _mat("tea", Color(0.36, 0.16, 0.08), 0.2))
			var leaf := SphereMesh.new()
			leaf.radius = 0.018
			leaf.height = 0.012
			var lf := MeshInstance3D.new()
			lf.mesh = leaf
			lf.scale = Vector3(1.0, 1.0, 1.8)
			lf.material_override = _mat("wintergreen", Color(0.14, 0.34, 0.16), 0.5)
			lf.position = Vector3(0.0, 0.045, 0.02)
			root.add_child(lf)
		"sinew":
			# a hank of pale fibres, tied in the middle
			for i in 5:
				var f := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.004
				c.bottom_radius = 0.004
				c.height = 0.15
				f.mesh = c
				f.material_override = _mat("sinew", Color(0.86, 0.8, 0.64), 0.6)
				f.position = Vector3(0.0, 0.0, (i - 2) * 0.008)
				f.rotation = Vector3(deg_to_rad(-10.0 + 5.0 * i), 0.0, 0.0)
				root.add_child(f)
			_part(root, 0.022, 0.022, 0.018, Vector3.ZERO, _mat("cord", Color(0.4, 0.3, 0.18), 0.9))
		"willow_bark_tea":
			# a tin cup of bitter amber tea, a curl of bark in it
			_part(root, 0.042, 0.038, 0.08, Vector3.ZERO, _mat("tin", Color(0.62, 0.62, 0.6), 0.35))
			_part(root, 0.038, 0.038, 0.004, Vector3(0.0, 0.035, 0.0), _mat("willow_tea", Color(0.55, 0.36, 0.12), 0.2))
			var curl := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.005
			cm.bottom_radius = 0.006
			cm.height = 0.07
			curl.mesh = cm
			curl.material_override = _mat("willow_bark", Color(0.4, 0.32, 0.2), 0.9)
			curl.position = Vector3(0.0, 0.05, 0.015)
			curl.rotation = Vector3(deg_to_rad(25.0), 0.0, 0.0)
			root.add_child(curl)
		"slippery_elm_gruel":
			# a wooden bowl of pale slick gruel
			_part(root, 0.06, 0.035, 0.04, Vector3.ZERO, _mat("bowl", Color(0.5, 0.36, 0.22), 0.7))
			_part(root, 0.054, 0.054, 0.004, Vector3(0.0, 0.017, 0.0), _mat("gruel", Color(0.78, 0.68, 0.5), 0.25))
		"elderberry_syrup":
			# a small brown bottle of dark syrup, corked, a drip on its shoulder
			_part(root, 0.032, 0.034, 0.075, Vector3.ZERO, _mat("syrup_bottle", Color(0.3, 0.14, 0.2), 0.12))
			_part(root, 0.012, 0.014, 0.03, Vector3(0.0, 0.05, 0.0), _mat("syrup_bottle", Color(0.3, 0.14, 0.2), 0.12))
			_part(root, 0.013, 0.013, 0.014, Vector3(0.0, 0.07, 0.0), _mat("cork", Color(0.6, 0.45, 0.3), 0.9))
		"ginseng_tonic":
			# a small green bottle, corked
			_part(root, 0.03, 0.034, 0.08, Vector3.ZERO, _mat("bottle", Color(0.22, 0.4, 0.24), 0.15))
			_part(root, 0.011, 0.013, 0.035, Vector3(0.0, 0.055, 0.0), _mat("bottle", Color(0.22, 0.4, 0.24), 0.15))
			_part(root, 0.012, 0.012, 0.014, Vector3(0.0, 0.078, 0.0), _mat("cork", Color(0.6, 0.45, 0.3), 0.9))
	return root


static func _part(root: Node3D, rt: float, rb: float, h: float, pos: Vector3, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)


static func _mat(key: String, c: Color, rough: float) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]
