class_name StructureMeshKit
extends RefCounted
## Accumulates quads, boxes and smooth grids per material key and builds one ArrayMesh with one
## surface per key, in the vertex layout of res://shaders/structures/structure.gdshader:
##   UV      texture coordinates in tiles (callers do the physical scaling)
##   UV2     (kind, edge): kind KIND_* below, edge 0..1 for edge wear
##   COLOR   rgb tint, a baked ambient occlusion
##   TANGENT generated (MikkTSpace) in commit()
## Everything added goes through `xform` (rotations and translations only).
##
##   var kit := StructureMeshKit.new()
##   kit.xform = Transform3D(Basis(), Vector3(0, 1, 0))
##   kit.box(&"boards", Transform3D.IDENTITY, Vector3(2, 0.2, 0.3), StructureMeshKit.GRAIN_X, 1)
##   var mesh := kit.commit(materials)     # {key: Material}

const KIND_TEX := 0.0
const KIND_CLAY := 1.0
const KIND_IRON := 2.0
const KIND_ENDGRAIN := 3.0
const KIND_VOID := 4.0

## Box UV modes: the axis the wood grain (texture u) runs along. Faces across the grain show
## end grain (kind 3) unless end_kind says otherwise.
enum { GRAIN_X, GRAIN_Y, GRAIN_Z }

## Board rows in boards_weathered (4 rows of the texture height) and their usable v span.
const ROWS := 4
const ROW_MARGIN := 0.02

var xform := Transform3D.IDENTITY
var _surf := {}
var _keys: Array[StringName] = []


## One surface's arrays. Packed arrays are values in GDScript, so they are only ever appended
## to from inside this class (in place).
class Surf:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	func push(pv: PackedVector3Array, pn: PackedVector3Array, puv: PackedVector2Array, puv2: PackedVector2Array,
			pc: PackedColorArray, pi: PackedInt32Array) -> void:
		var base := v.size()
		v.append_array(pv)
		n.append_array(pn)
		uv.append_array(puv)
		uv2.append_array(puv2)
		c.append_array(pc)
		for k in pi.size():
			pi[k] += base
		i.append_array(pi)


func _s(key: StringName) -> Surf:
	if not _surf.has(key):
		_surf[key] = Surf.new()
		_keys.append(key)
	return _surf[key]


func is_empty() -> bool:
	return _keys.is_empty()


func triangle_count() -> int:
	var n := 0
	for k in _keys:
		n += (_surf[k] as Surf).i.size() / 3
	return n


## v range of board row `row` (0..3) for a fraction f in [0, 1] across the board.
static func row_v(row: int, f: float) -> float:
	var r := posmod(row, ROWS)
	return (r + ROW_MARGIN + f * (1.0 - 2.0 * ROW_MARGIN)) / float(ROWS)


## Planar quad a-b-c-d, counter-clockwise seen from the front (the side the normal faces), or
## any order with a `facing` hint (the winding is flipped to face it).
func quad(key: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2,
		col := Color(1, 1, 1, 1), kind := KIND_TEX, edge := 0.0, cols: PackedColorArray = PackedColorArray(),
		facing := Vector3.ZERO) -> void:
	var s := _s(key)
	var pa := xform * a
	var pb := xform * b
	var pc := xform * c
	var pd := xform * d
	var n := (pb - pa).cross(pc - pa)
	if n.length_squared() < 1e-12:
		n = (pc - pa).cross(pd - pa)
	n = n.normalized()
	# Optional facing hint: flip the winding (b <-> d) when the quad faces the other way.
	if facing != Vector3.ZERO and n.dot(xform.basis * facing) < 0.0:
		var tp := pb
		pb = pd
		pd = tp
		var tu := ub
		ub = ud
		ud = tu
		if cols.size() == 4:
			cols = PackedColorArray([cols[0], cols[3], cols[2], cols[1]])
		n = -n
	var k := Vector2(kind, edge)
	# Godot's front faces are clockwise.
	s.push(PackedVector3Array([pa, pb, pc, pd]), PackedVector3Array([n, n, n, n]), PackedVector2Array([ua, ub, uc, ud]),
			PackedVector2Array([k, k, k, k]), cols if cols.size() == 4 else PackedColorArray([col, col, col, col]),
			PackedInt32Array([0, 2, 1, 0, 3, 2]))


## Triangle a-b-c, counter-clockwise seen from the front. `nrm` (optional) is the shading
## normal and also picks the front side (the winding is fixed to match it).
func tri(key: StringName, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2,
		col := Color(1, 1, 1, 1), kind := KIND_TEX, edge := 0.0, nrm := Vector3.ZERO) -> void:
	var s := _s(key)
	var pa := xform * a
	var pb := xform * b
	var pc := xform * c
	var geo := (pb - pa).cross(pc - pa)
	var n := geo.normalized()
	if nrm != Vector3.ZERO:
		n = (xform.basis * nrm).normalized()
		if geo.dot(n) < 0.0:    # the normal decides the front side: fix the winding
			var tp := pb
			pb = pc
			pc = tp
			var tu := ub
			ub = uc
			uc = tu
	var k := Vector2(kind, edge)
	s.push(PackedVector3Array([pa, pb, pc]), PackedVector3Array([n, n, n]), PackedVector2Array([ua, ub, uc]),
			PackedVector2Array([k, k, k]), PackedColorArray([col, col, col]), PackedInt32Array([0, 2, 1]))


## Smooth grid: rows of equal length (positions, normals, uvs, colours per vertex). Each cell
## becomes two triangles, wound so they face along the given vertex normals. kinds/edges per row
## (optional).
func grid(key: StringName, pos: Array, nrm: Array, uvs: Array, cols: Array, kind := KIND_TEX, edge := 0.0,
		row_edges := PackedFloat32Array()) -> void:
	var s := _s(key)
	var rows := pos.size()
	var colsn := (pos[0] as PackedVector3Array).size()
	var basis_n := xform.basis
	var V := PackedVector3Array()
	var NN := PackedVector3Array()
	var UU := PackedVector2Array()
	var U2 := PackedVector2Array()
	var CC := PackedColorArray()
	for r in rows:
		var P: PackedVector3Array = pos[r]
		var N: PackedVector3Array = nrm[r]
		var U: PackedVector2Array = uvs[r]
		var C: PackedColorArray = cols[r]
		var e := row_edges[r] if row_edges.size() == rows else edge
		for j in colsn:
			V.append(xform * P[j])
			NN.append((basis_n * N[j]).normalized())
			UU.append(U[j])
			U2.append(Vector2(kind, e))
			CC.append(C[j])
	var I := PackedInt32Array()
	for r in rows - 1:
		for j in colsn - 1:
			var a := r * colsn + j
			var b := a + 1
			var c := a + colsn + 1
			var d := a + colsn
			var geo := (V[b] - V[a]).cross(V[c] - V[a])
			if geo.dot(NN[a] + NN[c]) >= 0.0:
				I.append_array(PackedInt32Array([a, c, b, a, d, c]))
			else:
				I.append_array(PackedInt32Array([a, b, c, a, c, d]))
	s.push(V, NN, UU, U2, CC, I)


## Axis-aligned box in the frame `t` (then `xform`), size `size`, centred on t.origin.
## grain: GRAIN_X/Y/Z (texture u runs along that axis, 1 tile per metre); row: board row;
## u0: u offset; faces across the grain get end_kind (end grain by default, UV = offset from
## the centre in metres). skip: bitmask of faces to leave out (1 +X, 2 -X, 4 +Y, 8 -Y, 16 +Z,
## 32 -Z). ao_bottom: vertex AO on the lowest vertices (ground contact).
func box(key: StringName, t: Transform3D, size: Vector3, grain := GRAIN_X, row := 0, u0 := 0.0,
		col := Color(1, 1, 1, 1), end_kind := KIND_ENDGRAIN, skip := 0, edge := 0.0, ao_bottom := 1.0) -> void:
	var h := size * 0.5
	var saved := xform
	xform = saved * t
	# Faces: [normal axis, sign, bit]
	var faces := [[0, 1.0, 1], [0, -1.0, 2], [1, 1.0, 4], [1, -1.0, 8], [2, 1.0, 16], [2, -1.0, 32]]
	for f: Array in faces:
		if skip & int(f[2]):
			continue
		var ax: int = f[0]
		var sg: float = f[1]
		# Two in-plane axes (u_ax, v_ax) so that u x v = normal direction.
		var u_ax := (ax + 1) % 3
		var v_ax := (ax + 2) % 3
		var nvec := Vector3.ZERO
		nvec[ax] = sg
		var corners: Array[Vector3] = []
		for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p := Vector3.ZERO
			p[ax] = sg * h[ax]
			p[u_ax] = q.x * h[u_ax]
			p[v_ax] = q.y * h[v_ax]
			corners.append(p)
		if sg < 0.0:
			corners = [corners[0], corners[3], corners[2], corners[1]]
		var uvs: Array[Vector2] = []
		var kind := KIND_TEX
		if ax == grain:
			kind = end_kind
			for p in corners:
				var a1 := (ax + 1) % 3
				var a2 := (ax + 2) % 3
				if end_kind == KIND_ENDGRAIN:
					uvs.append(Vector2(p[a1], p[a2]))
				else:
					uvs.append(Vector2(p[a1] + u0, row_v(row, (p[a2] + h[a2]) / maxf(size[a2], 1e-4))))
		else:
			# Across-grain axis on this face: the in-plane axis that is not the grain.
			var across := u_ax if u_ax != grain else v_ax
			for p in corners:
				var u := (p[grain] + h[grain]) + u0
				var fv := (p[across] + h[across]) / maxf(size[across], 1e-4)
				uvs.append(Vector2(u, row_v(row, fv)))
		var cols := PackedColorArray()
		if ao_bottom < 1.0:
			for p in corners:
				var c2 := col
				if p.y < -h.y + 1e-4:
					c2.a = col.a * ao_bottom
				cols.append(c2)
		quad(key, corners[0], corners[1], corners[2], corners[3], uvs[0], uvs[1], uvs[2], uvs[3], col, kind, edge, cols)
	xform = saved


## Build the ArrayMesh: one surface per key in insertion order, material from `materials`.
func commit(materials: Dictionary, mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	for key in _keys:
		var s: Surf = _surf[key]
		if s.i.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.v
		arrays[Mesh.ARRAY_NORMAL] = s.n
		arrays[Mesh.ARRAY_TEX_UV] = s.uv
		arrays[Mesh.ARRAY_TEX_UV2] = s.uv2
		arrays[Mesh.ARRAY_COLOR] = s.c
		arrays[Mesh.ARRAY_INDEX] = s.i
		var st := SurfaceTool.new()
		st.create_from_arrays(arrays)
		st.generate_tangents()
		var out := st.commit_to_arrays()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		var m: Material = materials.get(key)
		if m:
			mesh.surface_set_material(mesh.get_surface_count() - 1, m)
		mesh.surface_set_name(mesh.get_surface_count() - 1, String(key))
	return mesh
