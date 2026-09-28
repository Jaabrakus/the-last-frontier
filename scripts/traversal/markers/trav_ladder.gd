@tool
class_name TravLadder
extends TravMarker
## A ladder, notched log or pole climb (design 7.8 / 14.3). bottom / top are local points on the
## climbing line (the rung plane's centre); `outward` points from the ladder toward the climber.

@export var bottom := Vector3.ZERO
@export var top := Vector3(0, 4, 0)
@export var outward := Vector3(0, 0, 1)
@export var width := 0.5
@export var rung_pitch := 0.24
## Height of the first rung's top above `bottom` (the rungs are at rung_offset + k * rung_pitch).
@export var rung_offset := 0.24
@export var rung_radius := 0.02
@export var rail := false
@export_enum("none", "vault", "rail", "to-left", "to-right") var entry_exit := "none"


func marker_info() -> Dictionary:
	var n := global_basis * outward
	return {"type": "ladder", "kind": "ladder", "bottom": global_transform * bottom, "top": global_transform * top,
			"normal": Vector3(n.x, 0, n.z).normalized(), "width": width, "rung_pitch": rung_pitch, "rung_offset": rung_offset, "rung_radius": rung_radius, "rail": rail,
			"entry_exit": entry_exit, "source": str(get_path())}


func gizmo_lines() -> Array:
	var side := Vector3.UP.cross(outward).normalized() * width * 0.5
	var out := [[bottom + side, top + side], [bottom - side, top - side]]
	var h := top.y - bottom.y
	var k := int(h / maxf(rung_pitch, 0.1))
	for i in k + 1:
		var y := bottom.lerp(top, i / float(maxi(k, 1)))
		out.append([y + side, y - side])
	return out


func _area_shape() -> Array:
	var box := BoxShape3D.new()
	box.size = Vector3(width, maxf(top.distance_to(bottom), 0.1), 0.4)
	var y := (top - bottom).normalized()
	var z := outward.normalized()
	var x := y.cross(z).normalized()
	return [box, Transform3D(Basis(x, y, x.cross(y)), (top + bottom) * 0.5 + z * 0.2)]
