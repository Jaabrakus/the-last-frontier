class_name DummyStyle
extends RefCounted
## Dresses a TargetDummy (scripts/world/target_dummy.gd) after it has built itself: straw
## fibre on the head and arms, a red wool coat with buff cross belts, a weathered post, crossbar
## and a cross-foot stand (look-dev spec, section 8.1 "Dummies"). Visual only:
##   * the dummy's colliders, its `hit_part` / `damage_mult` meta and its node layout are not
##     touched (only MeshInstance3D meshes / materials, plus two small belt meshes);
##   * its `_straw` material stays the same StandardMaterial3D object, so the hit flash
##     (`_straw.albedo_color` lerped toward white) keeps working: the straw texture is neutral
##     grey and the dummy's own `_base_color` still tints it.
##
##   DummyStyle.apply(dummy)       # after the dummy is in the tree (its _ready built it)
##
## FrontierStructures calls it for every range dummy. It could move into TargetDummy._build()
## later (target_dummy.gd is package D's file as well).

const COAT_RED := Color(0.78, 0.2, 0.15)      ## x the wool texture (mean ~0.72) ~ #A02C22 lit
const BELT := Color(0.8, 0.76, 0.64)
const STRAW_BASE := Color(1.0, 0.86, 0.52)

static var _coat: StandardMaterial3D
static var _belt: StandardMaterial3D
static var _meshes := {}


## Drops the cached coat / belt materials and meshes (FrontierStructures._exit_tree).
static func release() -> void:
	_coat = null
	_belt = null
	_meshes.clear()


static func apply(dummy: Node3D) -> void:
	if dummy == null or not is_instance_valid(dummy):
		return
	var tex := StructureMaterials.dummy_textures()
	var straw := dummy.get("_straw") as StandardMaterial3D
	if straw:
		# A brighter base colour under the darker fibre texture keeps the straw's overall tone;
		# the hit flash still lerps from _base_color to white.
		if "_base_color" in dummy:
			dummy.set("_base_color", STRAW_BASE)
		straw.albedo_color = STRAW_BASE
		straw.albedo_texture = tex["straw"]
		straw.normal_enabled = true
		straw.normal_texture = tex["straw_normal"]
		straw.normal_scale = 1.3
		straw.uv1_scale = Vector3(3.0, 3.0, 1.0)
		straw.roughness = 1.0
	_materials(tex)
	var wood := StructureMaterials.get_material(&"boards")
	for mi: MeshInstance3D in _mesh_instances(dummy):
		# Dummies move (the strafing one) and topple: they receive GI but stay out of SDFGI.
		mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		var m := mi.material_override
		var p := mi.position
		if straw and m == straw:
			if mi.mesh is BoxMesh:                  # arms: straw bundles along x
				mi.mesh = _mesh("arm")
				mi.rotation = Vector3(0, 0, PI * 0.5)
			continue
		if mi.mesh is CylinderMesh and (mi.mesh as CylinderMesh).top_radius > 0.15:
			mi.mesh = _mesh("coat")                  # torso -> coat
			mi.material_override = _coat
			var belts := MeshInstance3D.new()
			belts.name = "CrossBelts"
			belts.mesh = _mesh("belts")
			belts.material_override = _belt
			belts.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			belts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(belts)
			continue
		if mi.mesh is CylinderMesh:                   # post
			mi.mesh = _mesh("post")
			mi.material_override = wood
		elif mi.mesh is BoxMesh and absf(p.y - 1.35) < 0.01:   # crossbar
			mi.mesh = _mesh("crossbar")
			mi.material_override = wood
		elif mi.mesh is BoxMesh and p.y < 0.1:        # base -> cross-foot stand
			mi.mesh = _mesh("base")
			mi.material_override = wood


static func _mesh_instances(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_mesh_instances(c))
	return out


static func _materials(tex: Dictionary) -> void:
	if _coat:
		return
	_coat = StandardMaterial3D.new()
	_coat.albedo_color = COAT_RED
	_coat.albedo_texture = tex["wool"]
	_coat.normal_enabled = true
	_coat.normal_texture = tex["wool_normal"]
	_coat.normal_scale = 0.7
	_coat.uv1_scale = Vector3(5.0, 2.5, 1.0)
	_coat.roughness = 0.95
	_coat.metallic_specular = 0.3
	_belt = StandardMaterial3D.new()
	_belt.albedo_color = BELT
	_belt.roughness = 0.8
	_belt.metallic_specular = 0.35
	_belt.cull_mode = BaseMaterial3D.CULL_DISABLED


static func _mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match key:
		"arm":
			var c := CylinderMesh.new()
			c.top_radius = 0.045
			c.bottom_radius = 0.055
			c.height = 0.36
			c.radial_segments = 8
			c.rings = 1
			m = c
		"coat":
			m = _coat_mesh()
		"belts":
			m = _belts_mesh()
		"post", "crossbar", "base":
			m = _wood_mesh(key)
	_meshes[key] = m
	return m


## Coat profile (torso-local y -> radius): skirts flared at the hem, waist, chest, rounded
## shoulders closing to the neck. Same height as the original 0.65 m torso cylinder.
const COAT_PROFILE := [
	Vector2(-0.34, 0.24), Vector2(-0.26, 0.228), Vector2(-0.12, 0.2), Vector2(0.0, 0.198),
	Vector2(0.14, 0.206), Vector2(0.25, 0.202), Vector2(0.3, 0.185), Vector2(0.335, 0.14),
	Vector2(0.352, 0.08), Vector2(0.358, 0.0),
]


static func _coat_r(y: float) -> float:
	for i in COAT_PROFILE.size() - 1:
		var a: Vector2 = COAT_PROFILE[i]
		var b: Vector2 = COAT_PROFILE[i + 1]
		if y <= b.x:
			return lerpf(a.y, b.y, clampf((y - a.x) / (b.x - a.x), 0.0, 1.0))
	return 0.0


## Lathed coat with a closed hem (seen from below it is not hollow).
static func _coat_mesh() -> ArrayMesh:
	const SEG := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := COAT_PROFILE.size()
	for i in n - 1:
		var a: Vector2 = COAT_PROFILE[i]
		var b: Vector2 = COAT_PROFILE[i + 1]
		var slope := Vector2(b.x - a.x, b.y - a.y)
		# Outward profile normal (radial, vertical) for this band.
		var pn := Vector2(slope.x, -slope.y).normalized()     # (radial, y)
		for j in SEG:
			var t0 := TAU * j / SEG
			var t1 := TAU * (j + 1) / SEG
			var d0 := Vector3(cos(t0), 0, sin(t0))
			var d1 := Vector3(cos(t1), 0, sin(t1))
			var p00 := d0 * a.y + Vector3(0, a.x, 0)
			var p01 := d1 * a.y + Vector3(0, a.x, 0)
			var p10 := d0 * b.y + Vector3(0, b.x, 0)
			var p11 := d1 * b.y + Vector3(0, b.x, 0)
			var n0 := (d0 * pn.x + Vector3(0, pn.y, 0)).normalized()
			var n1 := (d1 * pn.x + Vector3(0, pn.y, 0)).normalized()
			var u0 := float(j) / SEG
			var u1 := float(j + 1) / SEG
			var va := (0.36 - a.x) / 0.72
			var vb := (0.36 - b.x) / 0.72
			# Clockwise seen from outside (Godot front faces).
			for q: Array in [[p00, n0, Vector2(u0, va)], [p01, n1, Vector2(u1, va)], [p11, n1, Vector2(u1, vb)],
					[p00, n0, Vector2(u0, va)], [p11, n1, Vector2(u1, vb)], [p10, n0, Vector2(u0, vb)]]:
				st.set_normal(q[1])
				st.set_uv(q[2])
				st.add_vertex(q[0])
	var hem: Vector2 = COAT_PROFILE[0]
	for j in SEG:
		var t0 := TAU * j / SEG
		var t1 := TAU * (j + 1) / SEG
		for q: Vector3 in [Vector3(0, hem.x, 0), Vector3(cos(t1) * hem.y, hem.x, sin(t1) * hem.y), Vector3(cos(t0) * hem.y, hem.x, sin(t0) * hem.y)]:
			st.set_normal(Vector3.DOWN)
			st.set_uv(Vector2(q.x, q.z))
			st.add_vertex(q)
	st.generate_tangents()
	return st.commit()


## Two buff cross belts over the front and back of the coat (in the torso's local frame).
static func _belts_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		for face: float in [-1.0, 1.0]:
			# Belt from one shoulder to the opposite hip, on the coat surface.
			var n := 12
			var prev_a := Vector3.ZERO
			var prev_b := Vector3.ZERO
			for i in n + 1:
				var t := float(i) / n
				var y := lerpf(0.29, -0.24, t)
				var x := lerpf(side * 0.13, -side * 0.17, t)
				var r := _coat_r(y) + 0.006
				var z := face * sqrt(maxf(r * r - x * x, 0.0))
				var p := Vector3(x, y, z)
				var nrm := Vector3(x, 0.0, z).normalized()
				var off := Vector3(0.026, 0.018 * side, 0.0)
				var a := p - off
				var b := p + off
				if i > 0:
					for v: Vector3 in [prev_a, prev_b, b, prev_a, b, a]:
						st.set_normal(nrm)
						st.add_vertex(v)
				prev_a = a
				prev_b = b
	return st.commit()


static func _wood_mesh(key: String) -> ArrayMesh:
	var kit := StructureMeshKit.new()
	var r := RandomNumberGenerator.new()
	r.seed = 1777 + key.length()
	match key:
		"post":        # centred like the original 1.9 m cylinder at y = 0.95
			StructureGeometry.pole(kit, Vector3.ZERO, -0.95, 0.95, 0.055, 0.048, r, false)
		"crossbar":
			kit.box(&"boards", Transform3D.IDENTITY, Vector3(0.9, 0.07, 0.07), StructureMeshKit.GRAIN_X, 1, 0.3)
		"base":        # two crossed feet and a block, centred at the old base (y = 0.04)
			kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.62, 0.08, 0.1), StructureMeshKit.GRAIN_X, 2, 0.1,
					Color(1, 1, 1, 1), StructureMeshKit.KIND_ENDGRAIN, 0, 0.0, 0.6)
			kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(0.1, 0.079, 0.62), StructureMeshKit.GRAIN_Z, 3, 0.5,
					Color(1, 1, 1, 1), StructureMeshKit.KIND_ENDGRAIN, 0, 0.0, 0.6)
			kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.07, 0)), Vector3(0.16, 0.08, 0.16), StructureMeshKit.GRAIN_Y, 0, 0.2)
	var mats := {&"boards": StructureMaterials.get_material(&"boards")}
	return kit.commit(mats)
