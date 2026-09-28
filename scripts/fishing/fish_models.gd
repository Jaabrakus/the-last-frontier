class_name FishModels
extends RefCounted
## The fishing things as models (the pack's pictures, ItemIcons; and in the hand): each species of fish (FishMesh, our
## own), a roast fish (a trout browned over the coals), a charred one; the fishing rod (a tapering ash rod, the line
## tied at its tip: along +Z from its butt), the quill float, the fish spear (a leister: a pole with a centre point
## between two springy side prongs, bound on with sinew: along +Z from its butt).

const ROD_M := 3.8
const SPEAR_M := 2.4
const ROD_SHADER := "res://shaders/fishing/rod.gdshader"


static func has(kind: String) -> bool:
	return FishCatch.is_fish(kind) or kind in ["roast_fish", "charred_fish", "fishing_rod", "quill_float", "fish_spear"]


static func build(kind: String) -> Node3D:
	match kind:
		"fishing_rod":
			return _rod()
		"quill_float":
			return _float()
		"fish_spear":
			return _spear()
	var root := Node3D.new()
	root.name = kind
	var mi := MeshInstance3D.new()
	var sp := kind if FishCatch.is_fish(kind) else "brook_trout"
	mi.mesh = FishMesh.mesh(sp)
	var mat := FishMesh.material(sp)
	if kind == "roast_fish" or kind == "charred_fish":
		# the skin browned (or blackened) over the coals: its colours kept faintly under the roast's
		var m2 := mat.duplicate() as ShaderMaterial
		m2.set_shader_parameter("tint", Color(0.62, 0.42, 0.24) if kind == "roast_fish" else Color(0.16, 0.12, 0.1))
		m2.set_shader_parameter("tint_amount", 0.75 if kind == "roast_fish" else 0.92)
		m2.set_shader_parameter("roughness_v", 0.7)
		m2.set_shader_parameter("specular_v", 0.25)
		mat = m2
	mi.material_override = mat
	# a fish of its species' size (a pound or so for the small ones: the picture's scale is framed anyway)
	var ln: Array = FishSpecies.spec(sp).get("len", [0.3, 0.3])
	var l := lerpf(float(ln[0]), float(ln[1]), 0.5)
	mi.scale = Vector3.ONE * l
	root.add_child(mi)
	return root


## A tapering pole along +Z from 0 to `length`, radius r0 at the butt to r1 at the tip.
static func _pole(length: float, r0: float, r1: float, sides := 8, rings := 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings:
		var z0 := length * float(i) / rings
		var z1 := length * float(i + 1) / rings
		var a0 := lerpf(r0, r1, float(i) / rings)
		var a1 := lerpf(r0, r1, float(i + 1) / rings)
		for j in sides:
			var t0 := TAU * float(j) / sides
			var t1 := TAU * float(j + 1) / sides
			var n0 := Vector3(cos(t0), sin(t0), 0.0)
			var n1 := Vector3(cos(t1), sin(t1), 0.0)
			var p := [n0 * a0 + Vector3(0, 0, z0), n1 * a0 + Vector3(0, 0, z0), n1 * a1 + Vector3(0, 0, z1), n0 * a1 + Vector3(0, 0, z1)]
			var n := [n0, n1, n1, n0]
			var uv := [Vector2(float(j) / sides, z0), Vector2(float(j + 1) / sides, z0), Vector2(float(j + 1) / sides, z1), Vector2(float(j) / sides, z1)]
			# (a front face's (B-A)x(C-A) points away from the viewer: wound so the outside faces out)
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(n[k])
				st.set_uv(uv[k])
				st.add_vertex(p[k])
	return st.commit()


static func _rod() -> Node3D:
	var root := Node3D.new()
	root.name = "fishing_rod"
	var mi := MeshInstance3D.new()
	mi.name = "Rod"
	mi.mesh = _pole(ROD_M, 0.014, 0.0028)
	var m := ShaderMaterial.new()
	m.shader = load(ROD_SHADER)
	m.set_shader_parameter("length_m", ROD_M)
	mi.material_override = m
	root.add_child(mi)
	return root


static func _float() -> Node3D:
	var root := Node3D.new()
	root.name = "quill_float"
	var body := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0025
	c.bottom_radius = 0.0055
	c.height = 0.09
	c.radial_segments = 8
	c.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.93, 0.9, 0.82)
	m.roughness = 0.5
	c.material = m
	body.mesh = c
	body.position = Vector3(0.0, 0.03, 0.0)
	root.add_child(body)
	var cap := MeshInstance3D.new()
	var s := CylinderMesh.new()
	s.top_radius = 0.001
	s.bottom_radius = 0.0028
	s.height = 0.025
	s.radial_segments = 8
	s.rings = 1
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.72, 0.12, 0.08)
	s.material = m2
	cap.mesh = s
	cap.position = Vector3(0.0, 0.087, 0.0)
	root.add_child(cap)
	return root


static func _spear() -> Node3D:
	var root := Node3D.new()
	root.name = "fish_spear"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.4, 0.27)
	wood.roughness = 0.75
	var pole := MeshInstance3D.new()
	pole.mesh = _pole(SPEAR_M, 0.016, 0.013)
	pole.material_override = wood
	root.add_child(pole)
	# the centre point (bone or iron) and the two springy side prongs, splayed a little, bound on
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.86, 0.82, 0.72)
	bone.roughness = 0.5
	for i in 3:
		var pr := MeshInstance3D.new()
		var side := float(i - 1)
		pr.mesh = _pole(0.26 if i == 1 else 0.3, 0.006, 0.0012, 6, 4)
		pr.material_override = bone if i == 1 else wood
		pr.position = Vector3(side * 0.012, 0.0, SPEAR_M - 0.05)
		pr.rotation = Vector3(0.0, side * 0.09, 0.0)
		root.add_child(pr)
	var bind := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.02
	bc.bottom_radius = 0.02
	bc.height = 0.08
	bc.radial_segments = 8
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.62, 0.55, 0.42)
	bc.material = sm
	bind.mesh = bc
	bind.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	bind.position = Vector3(0.0, 0.0, SPEAR_M - 0.02)
	root.add_child(bind)
	return root
