@tool
class_name TravLedge
extends TravMarker
## A hand-placed ledge: rock lips, cornices, narrow sidle ledges (design 14.3). Points are
## local; the outward normal is local too (horizontal).

@export var points := PackedVector3Array([Vector3(-1, 0, 0), Vector3(1, 0, 0)])
@export var outward := Vector3(0, 0, 1)
@export_enum("braced", "hang") var grip := "braced"
@export_enum("ledge", "narrow", "limb") var kind := "ledge"
@export_enum("none", "crouch", "stand") var top_class := "none"
@export var lip_m := 0.3
@export var two_sided := false
@export var surface := "stone"


func marker_info() -> Dictionary:
	var pts := PackedVector3Array()
	for p in points:
		pts.append(global_transform * p)
	var n := global_basis * outward
	return {"type": "ledge", "points": pts, "normal": Vector3(n.x, 0, n.z).normalized(), "grip": grip, "kind": kind,
			"top_class": top_class, "lip_m": lip_m, "two_sided": two_sided, "surface": surface, "source": str(get_path())}


func gizmo_lines() -> Array:
	var out := []
	for i in range(1, points.size()):
		out.append([points[i - 1], points[i]])
		var m := (points[i - 1] + points[i]) * 0.5
		out.append([m, m + outward.normalized() * 0.25])
	return out


func _area_shape() -> Array:
	if points.size() < 2:
		return []
	var a := points[0]
	var b := points[points.size() - 1]
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(a.distance_to(b), 0.1), 0.3, 0.3)
	var x := (b - a).normalized()
	var basis := Basis(x, Vector3.UP, x.cross(Vector3.UP)).orthonormalized() if absf(x.dot(Vector3.UP)) < 0.99 else Basis.IDENTITY
	return [box, Transform3D(basis, (a + b) * 0.5)]
