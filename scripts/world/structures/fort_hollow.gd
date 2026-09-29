class_name FortHollow
extends RefCounted
## The fort's buildings with a way in (user 2026-09-28: "make the current buildings doors be openable"): the cabin and the
## storehouse (and the blockhouse piece, FortPieces.HOLLOW, which uses the same helpers) were solid boxes with a door
## painted on the wall. Each is now hollow: its log wall
## has a doorway (the logs stop at the opening, a casing frames it), a hung door (BuildDoor: E opens and shuts it, the leaf
## swings in) closes it, and inside there is a floor, a ceiling and inner faces to the walls. The colliders are four
## walls (one split round the doorway, a lintel over it), so a shut door stops the player and an open one lets them in.
## Only a blockhouse's lower storey is hollow: the upper storey stays a solid box (the way up is not built).

const WALL_T := 0.3
const LINTEL_MIN := 0.1                ## the wall over the door is at least this thick (m) over the opening
## name -> {c: the box's centre, size, out: the doorway's face normal, pos: the doorway's foot at the wall's outer face,
##  w, h: the opening, style ("round" logs or "hewn" faces), courses: hewn courses over the height, bounds: round courses}
const BUILDINGS := {
	"cabin": {"c": Vector3(-8, 1.5, 7), "size": Vector3(7, 3, 5), "out": Vector3.BACK, "pos": Vector3(-8, 0, 9.5), "w": 1.05, "h": 2.1,
			"style": "round"},
	"storehouse": {"c": Vector3(9, 1.2, 4), "size": Vector3(5, 2.4, 4), "out": Vector3.LEFT, "pos": Vector3(6.5, 0, 4.0), "w": 1.0, "h": 2.1,
			"style": "hewn", "courses": 8},
}


static func along_of(out: Vector3) -> Vector3:
	return Vector3.UP.cross(out)


## The doorway's place along its wall (m from the wall's middle, + toward `along`).
static func door_s(b: Dictionary) -> float:
	return ((b.pos as Vector3) - (b.c as Vector3)).dot(along_of(b.out))


## The frame of the hung door: at the middle of the doorway's foot, +Z out, +X along, the hinge on the -X side.
static func door_xf(b: Dictionary) -> Transform3D:
	var out: Vector3 = b.out
	return Transform3D(Basis(along_of(out), Vector3.UP, out), b.pos)


## The course bounds of a building's height (round: every 0.3 m; hewn: `courses` over the box).
static func bounds_of(b: Dictionary) -> PackedFloat32Array:
	var size: Vector3 = b.size
	var y0 := (b.c as Vector3).y - size.y * 0.5
	var out := PackedFloat32Array()
	if String(b.style) == "round":
		var n := int(round(size.y / 0.3))
		for k in n + 1:
			out.append(y0 + k * 0.3)
	else:
		var n := int(b.courses)
		for k in n + 1:
			out.append(lerpf(y0, y0 + size.y, float(k) / n))
	return out


## The bounds from the first course line over the doorway up (the logs above the opening).
static func lintel_bounds(b: Dictionary) -> PackedFloat32Array:
	var all := bounds_of(b)
	var top := PackedFloat32Array()
	for v in all:
		if v >= float(b.h) - 0.001 or not top.is_empty():
			top.append(v)
	return top


## The lintel's underside: the first course line at or over the opening's height.
static func lintel_y(b: Dictionary) -> float:
	var t := lintel_bounds(b)
	return t[0] if not t.is_empty() else float(b.h)


# --- Visuals ------------------------------------------------------------------------------------------------

## The doorway wall as logs with the opening cut: the two sides, and the courses over the door.
static func door_wall(kit, b: Dictionary, rng: RandomNumberGenerator) -> void:
	var c: Vector3 = b.c
	var size: Vector3 = b.size
	var out: Vector3 = b.out
	var along := along_of(out)
	var half := size.x * 0.5 if absf(out.x) > 0.5 else size.z * 0.5
	var span := size.z if absf(out.x) > 0.5 else size.x
	var face_c := c + out * half
	var s := door_s(b)
	var dw: float = b.w
	var s0 := -span * 0.5
	var s1 := s - dw * 0.5
	var s2 := s + dw * 0.5
	var s3 := span * 0.5
	var parity := 0 if absf(out.x) > 0.5 else 1
	var all := bounds_of(b)
	var lint := lintel_bounds(b)
	for seg: Array in [[s0, s1], [s2, s3]]:
		_face(kit, b, face_c + along * ((seg[0] + seg[1]) * 0.5), out, seg[1] - seg[0], all, rng, parity)
	if lint.size() >= 2:
		_face(kit, b, face_c + along * s, out, dw, lint, rng, parity)


static func _face(kit, b: Dictionary, fc: Vector3, out: Vector3, w: float, bounds: PackedFloat32Array, rng: RandomNumberGenerator, parity: int) -> void:
	if w <= 0.01:
		return
	if String(b.style) == "round":
		StructureGeometry.round_log_face(kit, fc, out, w, bounds, rng)
	else:
		StructureGeometry.hewn_face(kit, fc, out, w, bounds, rng, parity, 0.28, true)


## Inside: a floor and a ceiling, the four walls' inner faces (the doorway's wall in three pieces round the opening).
static func interior(kit, b: Dictionary, rng: RandomNumberGenerator) -> void:
	var c: Vector3 = b.c
	var size: Vector3 = b.size
	var base := c.y - size.y * 0.5
	var inner := Vector3(size.x - WALL_T * 2.0, size.y, size.z - WALL_T * 2.0)
	var t := 0.04
	var col := Color(0.62, 0.58, 0.52, 1.0)
	kit.box(&"boards", Transform3D(Basis(), Vector3(c.x, base + 0.03, c.z)), Vector3(inner.x + 0.02, 0.06, inner.z + 0.02), StructureMeshKit.GRAIN_X,
			rng.randi_range(0, 3), rng.randf(), col)
	kit.box(&"boards", Transform3D(Basis(), Vector3(c.x, base + size.y - 0.03, c.z)), Vector3(inner.x + 0.02, 0.06, inner.z + 0.02),
			StructureMeshKit.GRAIN_X, rng.randi_range(0, 3), rng.randf(), col)
	var out: Vector3 = b.out
	var s := door_s(b)
	var dw: float = b.w
	var dh := lintel_y(b)
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var ex := inner.x * 0.5 if absf(n.x) > 0.5 else inner.z * 0.5
		var span := inner.z if absf(n.x) > 0.5 else inner.x
		var along := along_of(n)
		var ctr := c + n * (ex + t * 0.5)
		var sz := Vector3(t, size.y, span) if absf(n.x) > 0.5 else Vector3(span, size.y, t)
		if n.dot(out) < 0.99:
			kit.box(&"boards", Transform3D(Basis(), ctr), sz, StructureMeshKit.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), col)
			continue
		# the doorway's wall: left and right of the opening, and over it
		var lo := -span * 0.5
		var hi := span * 0.5
		for seg: Array in [[lo, s - dw * 0.5], [s + dw * 0.5, hi]]:
			var len: float = seg[1] - seg[0]
			if len <= 0.02:
				continue
			var mid: Vector3 = ctr + along * ((float(seg[0]) + float(seg[1])) * 0.5)
			var ssz := Vector3(t, size.y, len) if absf(n.x) > 0.5 else Vector3(len, size.y, t)
			kit.box(&"boards", Transform3D(Basis(), mid), ssz, StructureMeshKit.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), col)
		var over := size.y - dh
		if over > 0.02:
			var mid2 := ctr + along * s + Vector3(0, (dh + size.y) * 0.5 - c.y, 0)
			var osz := Vector3(t, over, dw) if absf(n.x) > 0.5 else Vector3(dw, over, t)
			kit.box(&"boards", Transform3D(Basis(), mid2), osz, StructureMeshKit.GRAIN_X, rng.randi_range(0, 3), rng.randf(), col)


# --- Colliders and the door -----------------------------------------------------------------------------------

## The hollow's collider boxes: [[centre, size]] (four walls, the doorway's split round the opening with a lintel, a ceiling).
static func collider_boxes(b: Dictionary) -> Array:
	var c: Vector3 = b.c
	var size: Vector3 = b.size
	var out: Vector3 = b.out
	var s := door_s(b)
	var dw: float = b.w
	var dh := lintel_y(b)
	var boxes: Array = []
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var half := size.x * 0.5 if absf(n.x) > 0.5 else size.z * 0.5
		var span := size.z if absf(n.x) > 0.5 else size.x
		var along := along_of(n)
		var ctr := c + n * (half - WALL_T * 0.5)
		if n.dot(out) < 0.99:
			boxes.append([ctr, Vector3(WALL_T, size.y, span) if absf(n.x) > 0.5 else Vector3(span, size.y, WALL_T)])
			continue
		for seg: Array in [[-span * 0.5, s - dw * 0.5], [s + dw * 0.5, span * 0.5]]:
			var len: float = seg[1] - seg[0]
			if len <= 0.02:
				continue
			boxes.append([ctr + along * ((seg[0] + seg[1]) * 0.5),
					Vector3(WALL_T, size.y, len) if absf(n.x) > 0.5 else Vector3(len, size.y, WALL_T)])
		var over := size.y - dh
		if over > 0.02:
			boxes.append([ctr + along * s + Vector3(0, (dh + size.y) * 0.5 - c.y, 0),
					Vector3(WALL_T, over, dw) if absf(n.x) > 0.5 else Vector3(dw, over, WALL_T)])
	boxes.append([c + Vector3(0, size.y * 0.5 - 0.1, 0), Vector3(size.x, 0.2, size.z)])
	return boxes


## A hung door for the building `b` under `parent`.
static func hang_door(parent: Node3D, b: Dictionary) -> BuildDoor:
	var d := BuildDoor.make_sized(float(b.w), lintel_y(b))
	d.name = "Door"
	d.transform = door_xf(b)          # before it is in the tree: a leaf's physics body does not follow its parent's move
	parent.add_child(d)
	return d


## A dim warm light inside (daylight does not reach a shut room): what comes through the chinks.
static func light(parent: Node3D, b: Dictionary) -> OmniLight3D:
	var c: Vector3 = b.c
	var size: Vector3 = b.size
	var l := OmniLight3D.new()
	l.name = "InsideLight"
	l.light_color = Color(1.0, 0.84, 0.62)
	l.light_energy = 1.3
	l.omni_range = maxf(size.x, size.z) * 1.05
	l.omni_attenuation = 0.9
	l.shadow_enabled = false
	l.position = Vector3(c.x, c.y - size.y * 0.5 + size.y - 0.55, c.z)
	parent.add_child(l)
	return l
