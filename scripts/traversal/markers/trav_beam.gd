@tool
class_name TravBeam
extends TravMarker
## A walkable line: beams, logs, lintels, thick branches, walked with the balance clips (design 9.5 / 14.3).

@export var a := Vector3(-1, 0, 0)
@export var b := Vector3(1, 0, 0)
@export var width := 0.3


func marker_info() -> Dictionary:
	return {"type": "beam", "a": global_transform * a, "b": global_transform * b, "width": width,
			"source": str(get_path())}


func gizmo_lines() -> Array:
	var side := Vector3.UP.cross(b - a).normalized() * width * 0.5
	return [[a, b], [a + side, b + side], [a - side, b - side]]


func _area_shape() -> Array:
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(a.distance_to(b), 0.1), 0.3, maxf(width, 0.1))
	var x := (b - a).normalized()
	var basis := Basis(x, Vector3.UP, x.cross(Vector3.UP)).orthonormalized() if absf(x.dot(Vector3.UP)) < 0.99 else Basis.IDENTITY
	return [box, Transform3D(basis, (a + b) * 0.5)]
