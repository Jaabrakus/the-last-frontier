@tool
class_name TravVolume
extends TravMarker
## A box volume: crouch_under (tunnels), squeeze, no_traverse (exclusions), climb_lane
## (an arbitrary climbable surface) (design 14.3).

@export var size := Vector3(1, 1.2, 3)
@export_enum("crouch_under", "squeeze", "no_traverse", "climb_lane") var kind := "crouch_under"
## Axis of travel for crouch_under / squeeze (local).
@export var axis := Vector3(0, 0, 1)


func marker_info() -> Dictionary:
	var ax := global_basis * axis
	return {"type": "volume", "kind": kind, "center": global_position, "size": size, "basis": global_basis,
			"axis": Vector3(ax.x, 0, ax.z).normalized(), "source": str(get_path())}


func gizmo_lines() -> Array:
	var h := size * 0.5
	var c := []
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				c.append(Vector3(x * h.x, y * h.y, z * h.z))
	var e := [[0, 1], [0, 2], [0, 4], [3, 1], [3, 2], [3, 7], [5, 1], [5, 4], [5, 7], [6, 2], [6, 4], [6, 7]]
	var out := []
	for p in e:
		out.append([c[p[0]], c[p[1]]])
	return out


func _area_shape() -> Array:
	var box := BoxShape3D.new()
	box.size = size
	return [box, Transform3D.IDENTITY]


func contains(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) <= size.x * 0.5 and absf(l.y) <= size.y * 0.5 and absf(l.z) <= size.z * 0.5
