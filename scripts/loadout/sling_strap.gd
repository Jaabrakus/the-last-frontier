class_name SlingStrap
extends MeshInstance3D
## A leather strap, sling or thong drawn as a thin band through an ordered list of anchor points
## (loadout_design.md 4): a centripetal Catmull-Rom curve through the anchors, the band lying flat on
## the body (its face normal interpolated from the anchor normals), pushed out along those normals by
## `lift` so it rides on the outfit. SlingRig updates the anchors every frame after the skeleton update
## (skinned body anchors, points on the stowed items) and calls rebuild().
##
## The node lives under the Skeleton3D with an identity transform, so points are skeleton space.
## One ImmediateMesh, rebuilt in place (at most a few straps x 24 segments per frame).

@export var width := 0.03
@export var thickness := 0.004
@export var segments_per_span := 4
@export var max_segments := 28
## Extra distance off the body along the anchor normals (strap stacking adds to it).
@export var lift := 0.004

var anchors := PackedVector3Array()
var normals := PackedVector3Array()
var _im: ImmediateMesh


func _init() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# the band moves every frame; keep it from being culled with a stale box
	extra_cull_margin = 2.0


func set_path(points: PackedVector3Array, nrm: PackedVector3Array) -> void:
	anchors = points
	normals = nrm


## Rebuilds the band from the current anchors.
func rebuild() -> void:
	_im.clear_surfaces()
	var n := anchors.size()
	if n < 2:
		return
	var pts: Array[Vector3] = []
	var nrs: Array[Vector3] = []
	var spans := n - 1
	var per := clampi(max_segments / maxi(spans, 1), 1, segments_per_span)
	for i in spans:
		var p0 := anchors[maxi(i - 1, 0)]
		var p1 := anchors[i]
		var p2 := anchors[i + 1]
		var p3 := anchors[mini(i + 2, n - 1)]
		var n1 := normals[i] if i < normals.size() else Vector3.UP
		var n2 := normals[i + 1] if i + 1 < normals.size() else n1
		for s in per:
			var t := float(s) / per
			pts.append(_catmull(p0, p1, p2, p3, t))
			nrs.append(n1.slerp(n2, t) if n1.dot(n2) > -0.99 else n1)
	pts.append(anchors[n - 1])
	nrs.append(normals[n - 1] if n - 1 < normals.size() else Vector3.UP)
	var m := pts.size()
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var up: Array[Vector3] = []
	for i in m:
		var tan := (pts[mini(i + 1, m - 1)] - pts[maxi(i - 1, 0)])
		if tan.length() < 1e-6:
			tan = Vector3.UP
		tan = tan.normalized()
		var nn := nrs[i] - tan * nrs[i].dot(tan)
		if nn.length() < 1e-4:
			nn = tan.cross(Vector3.RIGHT)
		nn = nn.normalized()
		var side := tan.cross(nn).normalized()
		var c := pts[i] + nn * (lift + thickness * 0.5)
		left.append(c - side * width * 0.5)
		right.append(c + side * width * 0.5)
		up.append(nn)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material_override)
	for i in m - 1:
		for face in [1.0, -1.0]:
			var off0: Vector3 = up[i] * thickness * 0.5 * face
			var off1: Vector3 = up[i + 1] * thickness * 0.5 * face
			var a := left[i] + off0
			var b := right[i] + off0
			var c := left[i + 1] + off1
			var d := right[i + 1] + off1
			var nr0: Vector3 = up[i] * face
			var nr1: Vector3 = up[i + 1] * face
			if face > 0.0:
				_tri(a, c, b, nr0, nr1, nr0)
				_tri(b, c, d, nr0, nr1, nr1)
			else:
				_tri(a, b, c, nr0, nr0, nr1)
				_tri(b, d, c, nr0, nr1, nr1)
		# edges
		var sd0 := (right[i] - left[i]).normalized()
		var sd1 := (right[i + 1] - left[i + 1]).normalized()
		for e in [[left, -1.0], [right, 1.0]]:
			var arr: Array = e[0]
			var sgn: float = e[1]
			var p0: Vector3 = arr[i] + up[i] * thickness * 0.5
			var p1: Vector3 = arr[i] - up[i] * thickness * 0.5
			var p2: Vector3 = arr[i + 1] + up[i + 1] * thickness * 0.5
			var p3: Vector3 = arr[i + 1] - up[i + 1] * thickness * 0.5
			var en0 := sd0 * sgn
			var en1 := sd1 * sgn
			_tri(p0, p1, p2, en0, en0, en1)
			_tri(p1, p3, p2, en0, en1, en1)
	_im.surface_end()


func _tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	_im.surface_set_normal(na)
	_im.surface_add_vertex(a)
	_im.surface_set_normal(nb)
	_im.surface_add_vertex(b)
	_im.surface_set_normal(nc)
	_im.surface_add_vertex(c)


## Total length of the curve through the anchors (m), for the length rule (a ribbon standing in for part
## of a rigid item must not be longer than that part + 2 cm; slings and straps may take any length).
func path_length() -> float:
	var L := 0.0
	for i in range(1, anchors.size()):
		L += anchors[i].distance_to(anchors[i - 1])
	return L


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	# centripetal parameterisation (alpha 0.5): no cusps or overshoot between close anchors
	var t0 := 0.0
	var t1 := t0 + pow(maxf(p0.distance_to(p1), 1e-4), 0.5)
	var t2 := t1 + pow(maxf(p1.distance_to(p2), 1e-4), 0.5)
	var t3 := t2 + pow(maxf(p2.distance_to(p3), 1e-4), 0.5)
	var tt := lerpf(t1, t2, t)
	var a1 := p0 * (t1 - tt) / (t1 - t0) + p1 * (tt - t0) / (t1 - t0)
	var a2 := p1 * (t2 - tt) / (t2 - t1) + p2 * (tt - t1) / (t2 - t1)
	var a3 := p2 * (t3 - tt) / (t3 - t2) + p3 * (tt - t2) / (t3 - t2)
	var b1 := a1 * (t2 - tt) / (t2 - t0) + a2 * (tt - t0) / (t2 - t0)
	var b2 := a2 * (t3 - tt) / (t3 - t1) + a3 * (tt - t1) / (t3 - t1)
	return b1 * (t2 - tt) / (t2 - t1) + b2 * (tt - t1) / (t2 - t1)
