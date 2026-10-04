class_name BodyMeshes
extends RefCounted
## The shapes of a fitted body (BodyModel) as meshes, for the views of it (the user, 2026-10-03): Anatomy's map under the body
## (N) and InspectView. Each shape's surface in its own frame (metres; arrays_of, mesh_of), and a bone's shapes merged into one
## mesh in their colours (merged: the map draws a mesh a bone, not one a shape). Made only when a view is shown; working out a
## hit never touches them. Kept by shape (the same bone of every body of a kind shares its mesh).

static var _arrays := {}
static var _meshes := {}


static func _key(s: Dictionary) -> String:
	var sz := s.s as Vector3
	var top := s.get("top", Vector2.ZERO) as Vector2
	return "%s|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f" % [s.t, sz.x, sz.y, sz.z, top.x, top.y, float(s.get("th", 0.0))]


## Shape `s`'s surface in its own frame (metres): [vertices, normals, indices].
static func arrays_of(s: Dictionary) -> Array:
	var key := _key(s)
	if _arrays.has(key):
		return _arrays[key]
	var sz := s.s as Vector3
	var out: Array
	match String(s.t):
		"cap":
			var c := CapsuleMesh.new()
			c.radius = sz.x
			c.height = 2.0 * (sz.y + sz.x)
			c.radial_segments = 10
			c.rings = 2
			out = _scaled(c.get_mesh_arrays(), Vector3.ONE)
		"cyl":
			var cy := CylinderMesh.new()
			cy.top_radius = 1.0
			cy.bottom_radius = 1.0
			cy.height = 2.0
			cy.radial_segments = 14
			cy.rings = 1
			out = _scaled(cy.get_mesh_arrays(), sz)
		"box":
			var top := s.get("top", Vector2(sz.x, sz.z)) as Vector2
			out = _tbox(sz.x, sz.z, top.x, top.y, sz.y)
		_:
			var sp := SphereMesh.new()
			sp.radius = 1.0
			sp.height = 2.0
			sp.radial_segments = 16
			sp.rings = 8
			out = _scaled(sp.get_mesh_arrays(), sz)
	_arrays[key] = out
	return out


## Shape `s` as a mesh in its own frame (metres).
static func mesh_of(s: Dictionary) -> ArrayMesh:
	var key := _key(s)
	if _meshes.has(key):
		return _meshes[key]
	var a := arrays_of(s)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = a[0]
	arr[Mesh.ARRAY_NORMAL] = a[1]
	arr[Mesh.ARRAY_INDEX] = a[2]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_meshes[key] = m
	return m


## The shapes `list` (BodyModel shapes) in one mesh, each placed by `xfs[i]` and coloured `cols[i]` (vertex colours).
static func merged(list: Array, xfs: Array, cols: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for i in list.size():
		var a := arrays_of(list[i])
		var xf: Transform3D = xfs[i]
		var nb := xf.basis.inverse().transposed()
		var base := v.size()
		var av: PackedVector3Array = a[0]
		var an: PackedVector3Array = a[1]
		for j in av.size():
			v.append(xf * av[j])
			n.append((nb * an[j]).normalized())
			c.append(cols[i])
		for j: int in (a[2] as PackedInt32Array):
			idx.append(base + j)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	if not v.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _scaled(arrays: Array, k: Vector3) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inv := Vector3(1.0 / k.x, 1.0 / k.y, 1.0 / k.z)
	var v2 := PackedVector3Array()
	var n2 := PackedVector3Array()
	v2.resize(v.size())
	n2.resize(v.size())
	for i in v.size():
		v2[i] = v[i] * k
		n2[i] = (n[i] * inv).normalized() if i < n.size() else Vector3.UP
	return [v2, n2, arrays[Mesh.ARRAY_INDEX] as PackedInt32Array]


## A box tapered along Y: half widths x0, z0 at its foot (-h), x1, z1 at its head (+h).
static func _tbox(x0: float, z0: float, x1: float, z1: float, h: float) -> Array:
	var p := [Vector3(-x0, -h, -z0), Vector3(x0, -h, -z0), Vector3(x0, -h, z0), Vector3(-x0, -h, z0),
			Vector3(-x1, h, -z1), Vector3(x1, h, -z1), Vector3(x1, h, z1), Vector3(-x1, h, z1)]
	var faces := [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	for f: Array in faces:
		var a: Vector3 = p[f[0]]
		var b: Vector3 = p[f[1]]
		var c: Vector3 = p[f[2]]
		var nn := (b - a).cross(c - a).normalized()
		var base := v.size()
		for k: int in f:
			v.append(p[k])
			n.append(nn)
		idx.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	return [v, n, idx]
