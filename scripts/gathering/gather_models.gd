class_name GatherModels
## Models of the gathering tools and what they gather, built in code (the project's own; no source asset):
##
##   "felling_axe"  an American felling axe of the 1750s-60s: a heavy squared poll behind the eye, a head
##                  about 22 cm from poll to bit with a bit that flares to about 11 cm at the edge, a bright
##                  steel edge welded into the iron bit, on a straight 86 cm oval hickory haft with a swelled knob
##                  (curved "fawn-foot" handles are 19th century)
##   "mattock"      a pick-mattock (grubbing hoe): a square pick curving slightly down on one side of the eye,
##                  a broad mattock blade across the haft on the other, on the same straight haft
##   "log", "firewood", "branches", "pole", "stone", "flint"   the gathered items (inventory icons)
##
## Tool axes (like ThrowableModels' tomahawk): origin at the haft's end (the knob), the haft up +Y into the
## head, the cutting edge (the axe's bit, the mattock's pick) facing -Z, the poll (the mattock's blade) +Z,
## the flats +/-X. Markers (Marker3D children): Butt (0), Grip (the one-hand carry grip, carry_grip_m up the
## haft), Head (the eye's centre), Edge (the middle of the cutting edge or the pick's point).

const HAFT_M := 0.86
const EYE_Y := 0.815            ## Butt -> centre of the eye.
const AXE_EDGE_Z := -0.172
const PICK_Z := -0.25

static var _mats := {}


static func build(kind: String) -> Node3D:
	match kind:
		"felling_axe":
			return _axe()
		"mattock":
			return _mattock()
		"log":
			return _log()
		"firewood":
			return _firewood()
		"branches":
			return _branches()
		"pole":
			return _pole()
		"stone":
			return _stone(0.13, 7, "stone")
		"flint":
			return _stone(0.055, 3, "flint")
		"stone_axe":
			return _stone_axe()
	return null


static func has(kind: String) -> bool:
	return kind in ["felling_axe", "mattock", "log", "firewood", "branches", "pole", "stone", "flint", "stone_axe"]


# --- Tools -----------------------------------------------------------------------------------------

static func _axe() -> Node3D:
	var root := Node3D.new()
	root.name = "FellingAxe"
	_haft(root)
	# head: stations from the poll face (+Z) to the edge (-Z): z, top y, bottom y (from the eye centre), half
	# thickness x. The poll is squared and heavy, the cheeks thin down and the bit flares.
	var st: Array = [
		[0.047, 0.027, -0.029, 0.018], [0.040, 0.030, -0.032, 0.022], [0.022, 0.031, -0.033, 0.023],
		[0.0, 0.031, -0.033, 0.022], [-0.022, 0.030, -0.032, 0.021], [-0.042, 0.026, -0.028, 0.016],
		[-0.068, 0.024, -0.027, 0.011], [-0.098, 0.029, -0.035, 0.0072], [-0.128, 0.039, -0.047, 0.0042],
		[-0.152, 0.047, -0.055, 0.0022], [-0.166, 0.050, -0.058, 0.0010], [AXE_EDGE_Z, 0.051, -0.059, 0.0003]]
	var head := _loft_z(st, EYE_Y, 14, 0.55)
	var mi := MeshInstance3D.new()
	mi.name = "HeadMesh"          # (the Head marker is the eye: _markers)
	mi.mesh = head
	mi.material_override = _iron()
	root.add_child(mi)
	# the bright steel edge: a thin strip over the last 1.2 cm of the bit
	var edge := _loft_z([[-0.160, 0.0485, -0.0565, 0.0016], [-0.166, 0.0502, -0.0582, 0.00105],
			[AXE_EDGE_Z + 0.0004, 0.0512, -0.0592, 0.0004]], EYE_Y, 10, 0.55)
	var em := MeshInstance3D.new()
	em.name = "EdgeMesh"          # (the Edge marker is the bit: _markers)
	em.mesh = edge
	em.material_override = _steel()
	root.add_child(em)
	_markers(root, Vector3(0, EYE_Y - 0.004, AXE_EDGE_Z))
	return root


## A stone axe (the start with nothing: made at the knapping stone): a chert head knapped to a thick wedge and ground
## at the bit, set through a split in the haft and lashed above and below with sinew or bark cord. The same frame and
## markers as the felling axe, so it is carried and swung the same way (a slower, blunter axe).
static func _stone_axe() -> Node3D:
	var root := Node3D.new()
	root.name = "StoneAxe"
	_haft(root)
	var st: Array = [
		[0.055, 0.020, -0.022, 0.016], [0.045, 0.030, -0.030, 0.024], [0.02, 0.034, -0.034, 0.028],
		[-0.01, 0.036, -0.036, 0.027], [-0.045, 0.037, -0.037, 0.022], [-0.08, 0.037, -0.036, 0.014],
		[-0.105, 0.035, -0.034, 0.007], [-0.118, 0.032, -0.031, 0.0025]]
	var mi := MeshInstance3D.new()
	mi.name = "HeadMesh"
	mi.mesh = _loft_z(st, EYE_Y, 12, 0.35)
	mi.material_override = _mat("chert", Color(0.3, 0.3, 0.31), 0.0, 0.62)
	root.add_child(mi)
	# the lashing, wound round the haft above and below the head
	var cord := _mat("lashing", Color(0.62, 0.52, 0.36), 0.0, 0.9)
	for y: float in [EYE_Y - 0.055, EYE_Y - 0.043, EYE_Y + 0.043, EYE_Y + 0.055]:
		var t := TorusMesh.new()
		t.inner_radius = 0.0135
		t.outer_radius = 0.0185
		t.rings = 12
		t.ring_segments = 5
		var tm := MeshInstance3D.new()
		tm.mesh = t
		tm.material_override = cord
		tm.position = Vector3(0, y, 0)
		root.add_child(tm)
	_markers(root, Vector3(0, EYE_Y, -0.118))
	return root


static func _mattock() -> Node3D:
	var root := Node3D.new()
	root.name = "Mattock"
	_haft(root)
	var iron := _iron()
	# eye boss
	var eye := _loft_z([[0.028, 0.034, -0.036, 0.021], [0.020, 0.036, -0.038, 0.024], [-0.020, 0.036, -0.038, 0.024],
			[-0.028, 0.034, -0.036, 0.021]], EYE_Y, 12, 0.5)
	var em := MeshInstance3D.new()
	em.name = "Eye"
	em.mesh = eye
	em.material_override = iron
	root.add_child(em)
	# pick: square, tapering to a point, curving a little down toward -Z
	var pick: Array = []
	for i in 9:
		var f := i / 8.0
		var z := lerpf(-0.024, PICK_Z, f)
		var drop := -0.035 * f * f
		var h := lerpf(0.017, 0.0015, pow(f, 0.8))
		pick.append([z, drop + h, drop - h, lerpf(0.016, 0.0012, pow(f, 0.8))])
	var pm := MeshInstance3D.new()
	pm.name = "Pick"
	pm.mesh = _loft_z(pick, EYE_Y, 8, 0.8)
	pm.material_override = iron
	root.add_child(pm)
	# mattock blade: across the haft (wide in X), thin in Y, curving down toward +Z
	var blade: Array = []
	for i in 8:
		var f := i / 7.0
		var z := lerpf(0.024, 0.205, f)
		var drop := -0.05 * f * f
		var th := lerpf(0.016, 0.0018, pow(f, 0.9))
		blade.append([z, drop + th, drop - th, lerpf(0.022, 0.038, pow(f, 0.7))])
	var bm := MeshInstance3D.new()
	bm.name = "Blade"
	bm.mesh = _loft_z(blade, EYE_Y, 10, 0.35)
	bm.material_override = iron
	root.add_child(bm)
	_markers(root, Vector3(0, EYE_Y - 0.035, PICK_Z))
	return root


## Straight oval hickory haft from the knob (y 0) up through the eye; the long axis of the oval in line with
## the bit (Z).
static func _haft(root: Node3D) -> void:
	var rings: Array = [   # y, half width x, half depth z
		[0.0, 0.0125, 0.0165], [0.012, 0.0158, 0.0200], [0.030, 0.0150, 0.0190], [0.055, 0.0128, 0.0165],
		[0.20, 0.0120, 0.0156], [0.45, 0.0114, 0.0148], [0.66, 0.0117, 0.0152], [0.76, 0.0124, 0.0162],
		[EYE_Y + 0.030, 0.0128, 0.0168], [EYE_Y + 0.044, 0.0122, 0.0160]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 12
	for r in rings.size() - 1:
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		for k in seg:
			var t0 := TAU * k / seg
			var t1 := TAU * (k + 1) / seg
			var p00 := Vector3(cos(t0) * a[1], a[0], sin(t0) * a[2])
			var p01 := Vector3(cos(t1) * a[1], a[0], sin(t1) * a[2])
			var p10 := Vector3(cos(t0) * b[1], b[0], sin(t0) * b[2])
			var p11 := Vector3(cos(t1) * b[1], b[0], sin(t1) * b[2])
			var n0 := Vector3(cos(t0) / a[1], 0, sin(t0) / a[2]).normalized()
			var n1 := Vector3(cos(t1) / a[1], 0, sin(t1) / a[2]).normalized()
			var u0 := float(k) / seg
			var u1 := float(k + 1) / seg
			_quad(st, [p00, p10, p11, p01], [n0, n0, n1, n1], [Vector2(u0, a[0]), Vector2(u0, b[0]), Vector2(u1, b[0]), Vector2(u1, a[0])])
	# end caps
	for end in [0, rings.size() - 1]:
		var e: Array = rings[end]
		var n := Vector3.DOWN if end == 0 else Vector3.UP
		for k in seg:
			var t0 := TAU * k / seg
			var t1 := TAU * (k + 1) / seg
			var c := Vector3(0, e[0], 0)
			var p0 := Vector3(cos(t0) * e[1], e[0], sin(t0) * e[2])
			var p1 := Vector3(cos(t1) * e[1], e[0], sin(t1) * e[2])
			st.set_normal(n)
			st.set_uv(Vector2(0.5, 0.5))
			if end == 0:
				st.add_vertex(c)
				st.add_vertex(p1)
				st.add_vertex(p0)
			else:
				st.add_vertex(c)
				st.add_vertex(p0)
				st.add_vertex(p1)
	var mi := MeshInstance3D.new()
	mi.name = "Haft"
	mi.mesh = st.commit()
	mi.material_override = _hickory()
	root.add_child(mi)


## A closed loft along Z through stations [z, top y, bottom y, half thickness x] (y from `y0`): each section a
## rounded box (`squareness` 0 = an ellipse, 1 = a box), capped at both ends.
static func _loft_z(st_list: Array, y0: float, seg: int, squareness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var secs: Array = []
	for s: Array in st_list:
		var ring: Array = []
		var mid := (float(s[1]) + float(s[2])) * 0.5
		var hh := (float(s[1]) - float(s[2])) * 0.5
		for k in seg:
			var a := TAU * k / seg
			var c := cos(a)
			var sn := sin(a)
			var ex := 1.0 - squareness * 0.6
			var x := signf(c) * pow(absf(c), ex) * float(s[3])
			var y := mid + signf(sn) * pow(absf(sn), ex) * hh
			ring.append(Vector3(x, y0 + y, float(s[0])))
		secs.append(ring)
	for i in secs.size() - 1:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		for k in seg:
			var k1 := (k + 1) % seg
			var p0: Vector3 = a[k]
			var p1: Vector3 = b[k]
			var p2: Vector3 = b[k1]
			var p3: Vector3 = a[k1]
			var n := ((p1 - p0).cross(p3 - p0)).normalized()
			if n.length() < 0.5:
				n = ((p2 - p1).cross(p0 - p1)).normalized()
			_quad_flat(st, [p0, p1, p2, p3], n)
	for end in [0, secs.size() - 1]:
		var ring: Array = secs[end]
		var c := Vector3.ZERO
		for v: Vector3 in ring:
			c += v
		c /= ring.size()
		for k in seg:
			var k1 := (k + 1) % seg
			var r0: Vector3 = ring[k]
			var r1: Vector3 = ring[k1]
			if end == 0:
				var sw := r0
				r0 = r1
				r1 = sw
			var tri: Array = [c, r0, r1]
			var n := -((r0 - c).cross(r1 - c)).normalized()
			for v: Vector3 in tri:
				st.set_normal(n)
				st.set_uv(Vector2(v.z * 4.0, v.y * 4.0))
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	return st.commit()


## Godot's front faces wind clockwise: p[0..3] go round the quad counter-clockwise seen from its front, so the
## triangles are (0, 2, 1) and (0, 3, 2).
static func _quad(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	for idx in [0, 2, 1, 0, 3, 2]:
		st.set_normal(n[idx])
		st.set_uv(uv[idx])
		st.add_vertex(p[idx])


static func _quad_flat(st: SurfaceTool, p: Array, n: Vector3) -> void:
	for idx in [0, 2, 1, 0, 3, 2]:
		st.set_normal(n)
		st.set_uv(Vector2(p[idx].z * 4.0, p[idx].y * 4.0))
		st.add_vertex(p[idx])


static func _markers(root: Node3D, edge: Vector3) -> void:
	var data := GatherData.get_default()
	var grip := float(data.tool("felling_axe").get("carry_grip_m", 0.46))
	for pair in [["Butt", Vector3.ZERO], ["Grip", Vector3(0, grip, 0)], ["Head", Vector3(0, EYE_Y, 0)], ["Edge", edge]]:
		var m := Marker3D.new()
		m.name = pair[0]
		m.position = pair[1]
		root.add_child(m)


# --- Items -----------------------------------------------------------------------------------------

## A bucked log (shortened for the icon): bark round, sawn-looking end grain.
static func _log() -> Node3D:
	var root := Node3D.new()
	root.name = "Log"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.16
	cyl.height = 0.9
	cyl.radial_segments = 14
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = _bark()
	mi.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(mi)
	for z: float in [-0.45, 0.45]:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.148 if z > 0 else 0.158
		cap.bottom_radius = cap.top_radius
		cap.height = 0.004
		cap.radial_segments = 14
		var ci := MeshInstance3D.new()
		ci.mesh = cap
		ci.material_override = _end_grain()
		ci.rotation = Vector3(PI * 0.5, 0, 0)
		ci.position = Vector3(0, 0, z)
		root.add_child(ci)
	return root


## A bundle of split firewood: quartered billets tied with a withe.
static func _firewood() -> Node3D:
	var root := Node3D.new()
	root.name = "Firewood"
	var bark := _bark()
	var wood := _end_grain()
	var offs := [Vector2(-0.05, 0.0), Vector2(0.05, 0.0), Vector2(0.0, 0.075), Vector2(-0.06, 0.1), Vector2(0.06, 0.1)]
	for i in offs.size():
		var bil := _billet(0.07, 0.55 + 0.03 * (i % 2))
		bil.position = Vector3(offs[i].x, offs[i].y, 0.02 * (i % 3))
		bil.rotation = Vector3(0, 0, 0.6 * i)
		for c in bil.get_children():
			(c as MeshInstance3D).material_override = bark if c.name == "Bark" else wood
		root.add_child(bil)
	var tie := TorusMesh.new()
	tie.inner_radius = 0.105
	tie.outer_radius = 0.118
	var ti := MeshInstance3D.new()
	ti.mesh = tie
	ti.material_override = _mat("withe", Color(0.33, 0.25, 0.15), 0.0, 0.85)
	ti.rotation = Vector3(PI * 0.5, 0, 0)
	ti.position = Vector3(0, 0.05, 0)
	root.add_child(ti)
	return root


## One quartered billet along Z: a quarter round (bark on the curve, split faces flat).
static func _billet(r: float, length: float) -> Node3D:
	var n := Node3D.new()
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var split := SurfaceTool.new()
	split.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 5
	var z0 := -length * 0.5
	var z1 := length * 0.5
	for k in seg:
		var a0 := PI * 0.5 * k / seg
		var a1 := PI * 0.5 * (k + 1) / seg
		var p0 := Vector3(cos(a0) * r, sin(a0) * r, 0)
		var p1 := Vector3(cos(a1) * r, sin(a1) * r, 0)
		_quad(bark, [p0 + Vector3(0, 0, z0), p0 + Vector3(0, 0, z1), p1 + Vector3(0, 0, z1), p1 + Vector3(0, 0, z0)],
				[p0.normalized(), p0.normalized(), p1.normalized(), p1.normalized()],
				[Vector2(0, 0), Vector2(0, 1), Vector2(0.2, 1), Vector2(0.2, 0)])
		for z in [z0, z1]:
			var nn := Vector3(0, 0, -1 if z == z0 else 1)
			var tri := [Vector3(0, 0, z), p0 + Vector3(0, 0, z), p1 + Vector3(0, 0, z)]
			if z == z0:
				tri = [tri[0], tri[2], tri[1]]
			for v: Vector3 in tri:
				split.set_normal(nn)
				split.set_uv(Vector2(v.x, v.y) * 5.0)
				split.add_vertex(v)
	# the two split faces
	_quad(split, [Vector3(0, 0, z0), Vector3(r, 0, z0), Vector3(r, 0, z1), Vector3(0, 0, z1)],
			[Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 3), Vector2(0, 3)])
	_quad(split, [Vector3(0, 0, z0), Vector3(0, 0, z1), Vector3(0, r, z1), Vector3(0, r, z0)],
			[Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT], [Vector2(0, 0), Vector2(0, 3), Vector2(1, 3), Vector2(1, 0)])
	var bm := MeshInstance3D.new()
	bm.name = "Bark"
	bm.mesh = bark.commit()
	n.add_child(bm)
	var sm := MeshInstance3D.new()
	sm.name = "Split"
	sm.mesh = split.commit()
	n.add_child(sm)
	return n


## A handful of limbs and twigs.
static func _branches() -> Node3D:
	var root := Node3D.new()
	root.name = "Branches"
	var mat := _mat("twig", Color(0.30, 0.24, 0.18), 0.0, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1765
	for i in 7:
		var c := CylinderMesh.new()
		c.top_radius = 0.006
		c.bottom_radius = rng.randf_range(0.011, 0.018)
		c.height = rng.randf_range(0.5, 0.75)
		c.radial_segments = 6
		c.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = mat
		mi.rotation = Vector3(PI * 0.5 + rng.randf_range(-0.12, 0.12), rng.randf_range(-0.35, 0.35), 0)
		mi.position = Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.03, 0.03), rng.randf_range(-0.04, 0.04))
		root.add_child(mi)
		# a side twig
		var t := CylinderMesh.new()
		t.top_radius = 0.003
		t.bottom_radius = 0.006
		t.height = 0.16
		t.radial_segments = 5
		t.rings = 1
		var ti := MeshInstance3D.new()
		ti.mesh = t
		ti.material_override = mat
		ti.position = Vector3(0, c.height * 0.15, 0.05)
		ti.rotation = Vector3(0.7, 0, 0)
		mi.add_child(ti)
	return root


## A trimmed sapling pole.
static func _pole() -> Node3D:
	var root := Node3D.new()
	root.name = "Pole"
	var c := CylinderMesh.new()
	c.top_radius = 0.022
	c.bottom_radius = 0.035
	c.height = 2.2
	c.radial_segments = 8
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = _bark()
	mi.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(mi)
	return root


## A rough piece of stone (a block broken from the outcrop) or a flint nodule.
static func _stone(r: float, seed_v: int, look: String) -> Node3D:
	var root := Node3D.new()
	root.name = look.capitalize()
	var sph := SphereMesh.new()
	sph.radius = r
	sph.height = r * 2.0
	sph.radial_segments = 10
	sph.rings = 6
	var arrays := sph.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# flatten into facets: pull each vertex toward one of a few random planes
	var planes: Array = []
	for i in 7:
		planes.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6), rng.randf_range(-1, 1)).normalized())
	var squash := Vector3(1.0, 0.7, 0.85) if look == "stone" else Vector3(1.0, 0.8, 0.75)
	for i in verts.size():
		var v := verts[i]
		var dn := v.normalized()
		var best := 1.0
		for pl: Vector3 in planes:
			var c := dn.dot(pl)
			if c > 0.2:
				best = minf(best, 0.78 / c)
		verts[i] = (dn * r * clampf(best, 0.72, 1.0)) * squash
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _stone_mat() if look == "stone" else _mat("flint", Color(0.23, 0.21, 0.2), 0.0, 0.32)
	root.add_child(mi)
	return root


# --- The stump -------------------------------------------------------------------------------------

## The stump a felled tree leaves: a short bark-covered frustum of the trunk (flaring toward the ground and
## sunk a little into it) with the fresh cut on top, sloping slightly toward the side the tree fell.
static func stump(r: float, h: float, species: String) -> Node3D:
	var root := Node3D.new()
	root.name = "StumpMesh"
	var seg := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = [[-0.25, 1.32], [0.0, 1.22], [0.08, 1.1], [h * 0.5, 1.02], [h, 1.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r * 1000.0) + h * 100
	var wob: Array = []
	for k in seg:
		wob.append(1.0 + rng.randf_range(-0.05, 0.05))
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in seg:
			var k1 := (k + 1) % seg
			var t0 := TAU * k / seg
			var t1 := TAU * (k + 1) / seg
			var ra0 := r * float(a[1]) * float(wob[k])
			var ra1 := r * float(a[1]) * float(wob[k1])
			var rb0 := r * float(b[1]) * float(wob[k])
			var rb1 := r * float(b[1]) * float(wob[k1])
			var p00 := Vector3(cos(t0) * ra0, a[0], sin(t0) * ra0)
			var p01 := Vector3(cos(t1) * ra1, a[0], sin(t1) * ra1)
			var p10 := Vector3(cos(t0) * rb0, b[0], sin(t0) * rb0)
			var p11 := Vector3(cos(t1) * rb1, b[0], sin(t1) * rb1)
			var n0 := Vector3(cos(t0), 0.15, sin(t0)).normalized()
			var n1 := Vector3(cos(t1), 0.15, sin(t1)).normalized()
			var u0 := float(k) / seg * 2.0
			var u1 := float(k + 1) / seg * 2.0
			_quad(st, [p00, p10, p11, p01], [n0, n0, n1, n1],
					[Vector2(u0, -float(a[0])), Vector2(u0, -float(b[0])), Vector2(u1, -float(b[0])), Vector2(u1, -float(a[0]))])
	var mi := MeshInstance3D.new()
	mi.name = "Bark"
	mi.mesh = st.commit()
	mi.material_override = bark_material(species)
	root.add_child(mi)
	# the cut: a disc at the top, with its own end grain
	var cut := SurfaceTool.new()
	cut.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in seg:
		var k1 := (k + 1) % seg
		var t0 := TAU * k / seg
		var t1 := TAU * (k + 1) / seg
		var q0 := Vector3(cos(t0) * r * float(wob[k]), h, sin(t0) * r * float(wob[k]))
		var q1 := Vector3(cos(t1) * r * float(wob[k1]), h, sin(t1) * r * float(wob[k1]))
		for v: Vector3 in [Vector3(0, h, 0), q0, q1]:
			cut.set_normal(Vector3.UP)
			cut.set_uv(Vector2(v.x / (2.0 * r) + 0.5, v.z / (2.0 * r) + 0.5))
			cut.add_vertex(v)
	var ci := MeshInstance3D.new()
	ci.name = "Cut"
	ci.mesh = cut.commit()
	ci.material_override = _cut_face()
	root.add_child(ci)
	return root


## The bark of a species (the vegetation's own bark textures: conifer, hardwood, birch).
static func bark_material(species: String) -> StandardMaterial3D:
	var key := "bark_" + species
	if not _mats.has(key):
		var m := _mat(key, Color(0.9, 0.86, 0.82), 0.0, 0.95)
		var file := "bark_hardwood_albedo_2k.png"
		if species in ["white_pine", "hemlock"]:
			file = "bark_conifer_albedo_2k.png"
		elif species == "birch":
			file = "birch_albedo_1k.png"
		var path := "res://assets/environment/vegetation/bark/" + file
		if ResourceLoader.exists(path):
			m.albedo_texture = load(path)
		var np := "res://assets/environment/vegetation/bark/bark_normal_2k.png"
		if species != "birch" and ResourceLoader.exists(np):
			m.normal_enabled = true
			m.normal_texture = load(np)
	return _mats[key]


## A fresh saw-less axe cut: pale sapwood round darker heartwood, growth rings, the axe's facets.
static func _cut_face() -> StandardMaterial3D:
	if not _mats.has("cut_face"):
		var m := _mat("cut_face", Color(1, 1, 1), 0.0, 0.85)
		var n := 96
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		for y in n:
			for x in n:
				var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
				var ring := 0.5 + 0.5 * sin(d * 38.0 + sin(x * 0.21) * 0.6)
				var c := Color(0.60, 0.51, 0.38).lerp(Color(0.46, 0.37, 0.26), ring * 0.4)
				c = c.lerp(Color(0.40, 0.31, 0.21), smoothstep(0.55, 0.2, d) * 0.45)   # heartwood
				var facet := 0.06 * sin(float(x) * 0.35 + float(y) * 0.12)
				c = Color(c.r + facet, c.g + facet, c.b + facet)
				if d > 0.93:
					c = Color(0.25, 0.2, 0.15)   # the bark's rim
				img.set_pixel(x, y, c)
		m.albedo_texture = ImageTexture.create_from_image(img)
	return _mats["cut_face"]


# --- Materials -------------------------------------------------------------------------------------

static func _mat(key: String, color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


static func _iron() -> StandardMaterial3D:
	return _mat("iron", Color(0.33, 0.32, 0.30), 0.6, 0.55)


static func _steel() -> StandardMaterial3D:
	return _mat("steel", Color(0.62, 0.61, 0.58), 0.9, 0.3)


static func _hickory() -> StandardMaterial3D:
	if not _mats.has("hickory"):
		var m := _mat("hickory", Color(0.56, 0.42, 0.27), 0.0, 0.58)
		var tex := _grain_texture()
		if tex:
			m.albedo_texture = tex
			m.uv1_scale = Vector3(1.0, 1.2, 1.0)
	return _mats["hickory"]


static func _bark() -> StandardMaterial3D:
	if not _mats.has("bark"):
		var m := _mat("bark", Color(0.85, 0.8, 0.76), 0.0, 0.95)
		var path := "res://assets/environment/vegetation/bark/bark_hardwood_albedo_2k.png"
		if ResourceLoader.exists(path):
			m.albedo_texture = load(path)
			m.uv1_scale = Vector3(2.0, 1.0, 1.0)
		else:
			m.albedo_color = Color(0.34, 0.27, 0.2)
	return _mats["bark"]


## The end grain of cut wood (log ends, the stump's fresh cut).
static func end_grain_material() -> StandardMaterial3D:
	return _end_grain()


static func _end_grain() -> StandardMaterial3D:
	if not _mats.has("end_grain"):
		var m := _mat("end_grain", Color(0.78, 0.63, 0.45), 0.0, 0.8)
		var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length()
				var ring := 0.5 + 0.5 * sin(d * 1.3 + sin(x * 0.3) * 0.4)
				var c := Color(0.60, 0.50, 0.37).lerp(Color(0.47, 0.37, 0.25), ring * 0.55)
				img.set_pixel(x, y, c)
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	return _mats["end_grain"]


static func _stone_mat() -> StandardMaterial3D:
	if not _mats.has("stone"):
		var m := _mat("stone", Color(0.72, 0.7, 0.66), 0.0, 0.9)
		var path := "res://assets/polyhaven/textures/structures/stacked_stone_wall/stacked_stone_wall_diffuse_2k.jpg"
		if ResourceLoader.exists(path):
			m.albedo_texture = load(path)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(2.5, 2.5, 2.5)
	return _mats["stone"]


## Straight hickory grain along the haft (V), made once.
static func _grain_texture() -> Texture2D:
	var img := Image.create(32, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1757
	var cols: Array = []
	for x in 32:
		cols.append(rng.randf_range(-1.0, 1.0))
	for y in 128:
		for x in 32:
			var g := 0.5 + 0.5 * sin(x * 0.9 + float(cols[x]) * 1.5 + y * 0.02)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0).lerp(Color(0.8, 0.74, 0.66), g * 0.6))
	return ImageTexture.create_from_image(img)
