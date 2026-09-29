class_name FortPieces
extends RefCounted
## The fort's own parts as build-menu pieces (user 2026-09-28: "we should be able to build the ramp, the palisade walls,
## the flag and etc in the builder menu"): the firing step (walkway), the ramp up to it, the ladder, the blockhouse and
## the flag pole, drawn with the same kit and the same shapes as the fort's (FrontierStructures), in a piece's own
## frame like every build piece (BuildGeometry).
##
## Frames (metres):
##   walkway       origin at the middle of a 3 m section of the firing step, on the ground under it; +X along it, -Z
##                 the wall side (the palisade's inside), +Z the open edge, the deck's top at WALK_TOP.
##   walkway_ramp  origin at the middle of the ramp's footprint on the ground; the ramp rises toward -Z to the deck's
##                 front edge (a walkway's +Z edge), 1.2 m wide.
##   ladder        origin at the foot of the ladder's middle, standing up; the rungs face +Z (climbed from +Z).
##   blockhouse    origin at the middle of its 5.5 m square on the ground; the door in the +Z face, 1.2 m right of
##                 the middle (its lower storey is hollow with a hung door, BuildDoor, and a dim light inside;
##                 the upper storey is a solid box: the way up is not built).
##   flagpole      origin at the foot of the pole; the flag flies toward +X.
## Sockets: a palisade's inside offers "pal_inside" to a walkway; a walkway offers "walk_end" (the next section in line)
## and "walk_front" (a ramp or a ladder at its open edge).

const K := preload("res://scripts/world/structures/structure_mesh_kit.gd")
const TYPES := ["walkway", "walkway_ramp", "ladder", "blockhouse", "flagpole"]

const WALK_L := 3.0
const WALK_D := 1.6
const WALK_TOP := 2.275
const RIM_BOTTOM := 1.93
const RAMP_W := 1.2
const RAMP_RUN := 5.0
const LADDER_HALF_W := 0.25
## The ladder stands this far in front of the firing step's open edge (the classic fort's LADDER_OFF).
const LADDER_OFF := 0.25
const LADDER_RAIL := Vector3(0.06, 0.3, 0.3)
const HOUSE := 5.5
const POLE_H := 10.0
const NO_TRAVERSE := {"no_traverse": true}
## The blockhouse's lower storey as a FortHollow building in the piece's frame (the cabin's and the storehouse's kind).
const HOLLOW := {"c": Vector3(0, 1.75, 0), "size": Vector3(4.5, 3.5, 4.5), "out": Vector3.BACK, "pos": Vector3(1.2, 0, 2.25),
		"w": 0.9, "h": 2.05, "style": "hewn", "courses": 12}


static func is_fort_piece(type: String) -> bool:
	return TYPES.has(type)


## The piece's mesh into `kit`.
static func mesh(kit: K, type: String, rng: RandomNumberGenerator, detail: bool) -> void:
	match type:
		"walkway":
			_walkway(kit, rng, detail)
		"walkway_ramp":
			_ramp(kit, rng, detail)
		"ladder":
			_ladder(kit, rng)
		"blockhouse":
			_blockhouse(kit, rng, detail)
		"flagpole":
			StructureGeometry.pole(kit, Vector3.ZERO, -0.1, POLE_H, 0.085, 0.055, rng)
			kit.box(&"boards", Transform3D(Basis(), Vector3(0.08, 1.3, 0)), Vector3(0.04, 0.16, 0.05), K.GRAIN_Y, 1, 0.0)


static func _walkway(kit: K, rng: RandomNumberGenerator, detail: bool) -> void:
	var hz := WALK_D * 0.5
	# Deck: five boards across, each in two lengths with a staggered joint.
	for j in 5:
		var zc := -hz + 0.15 + j * 0.325
		var joint := rng.randf_range(1.0, 2.0)
		for seg: Array in [[0.0, joint], [joint, WALK_L]]:
			var x0: float = seg[0] - WALK_L * 0.5
			var x1: float = seg[1] - WALK_L * 0.5
			var t := rng.randf_range(0.86, 1.06)
			kit.box(&"boards", Transform3D(Basis(), Vector3((x0 + x1) * 0.5, 2.25 - rng.randf_range(0.0, 0.004), zc)),
					Vector3(x1 - x0 - 0.006, 0.05, 0.3), K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), Color(t, t, t * 0.98, 1.0),
					K.KIND_ENDGRAIN, 0, 0.0, 0.8)
	if detail:
		for jx: float in [-1.2, 0.0, 1.2]:
			kit.box(&"boards", Transform3D(Basis(), Vector3(jx, 2.175, 0)), Vector3(0.12, 0.1, WALK_D), K.GRAIN_Z,
					rng.randi_range(0, 3), rng.randf(), Color(0.85, 0.83, 0.8, 0.7))
	# Rim beam on the post, ledger against the wall.
	var pz := hz - 0.09
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, (RIM_BOTTOM + 2.125) * 0.5, pz)), Vector3(WALK_L, 2.125 - RIM_BOTTOM, 0.16),
			K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), Color(0.9, 0.88, 0.85, 0.85))
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 2.04, -hz + 0.07)), Vector3(WALK_L, 0.17, 0.14), K.GRAIN_X,
			rng.randi_range(0, 3), rng.randf(), Color(0.8, 0.78, 0.75, 0.6))
	# The post under the rim beam, set a little into the ground.
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, (RIM_BOTTOM - 0.4) * 0.5, pz)), Vector3(0.16, RIM_BOTTOM + 0.4, 0.16),
			K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(0.95, 0.93, 0.9, 1.0), K.KIND_ENDGRAIN, 8, 0.0, 0.6)


## The ramp slab's frame: it rises toward -Z to WALK_TOP over RAMP_RUN, its top surface through the origin's line.
static func ramp_transform() -> Transform3D:
	var thickness := 0.15
	var angle := atan2(WALK_TOP, RAMP_RUN)
	var normal := Vector3(0, cos(angle), sin(angle))
	return Transform3D(Basis.from_euler(Vector3(angle, 0, 0)), Vector3(0, WALK_TOP * 0.5, 0) - normal * thickness * 0.5)


static func _ramp(kit: K, rng: RandomNumberGenerator, detail: bool) -> void:
	var length := Vector2(RAMP_RUN, WALK_TOP).length()
	var saved := kit.xform
	kit.xform = saved * ramp_transform()
	for sx: float in [-1.0, 1.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx * 0.5, -0.02, 0)), Vector3(0.1, 0.11, length), K.GRAIN_Z,
				rng.randi_range(0, 3), rng.randf(), Color(0.85, 0.83, 0.8, 0.8))
	var z := -length * 0.5
	while z < length * 0.5 - 0.05:
		var bw := minf(0.2, length * 0.5 - z)
		var tint := rng.randf_range(0.86, 1.06)
		kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.055, z + bw * 0.5)), Vector3(RAMP_W, 0.04, bw - 0.012), K.GRAIN_X,
				rng.randi_range(0, 3), rng.randf(), Color(tint, tint, tint * 0.98, 1.0))
		z += bw
	if detail:
		var cz := -length * 0.5 + 0.3
		while cz < length * 0.5 - 0.2:
			kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.092, cz)), Vector3(1.05, 0.035, 0.05), K.GRAIN_X,
					rng.randi_range(0, 3), rng.randf(), Color(1.0, 0.98, 0.95, 1.0), K.KIND_ENDGRAIN, 8, 0.8)
			cz += 0.42
	kit.xform = saved


static func ladder_height() -> float:
	return WALK_TOP + LADDER_RAIL.y


static func _ladder(kit: K, rng: RandomNumberGenerator) -> void:
	var h := ladder_height()
	for sx: float in [-LADDER_HALF_W, LADDER_HALF_W]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx, h * 0.5, -LADDER_RAIL.z * 0.4)), Vector3(LADDER_RAIL.x, h, LADDER_RAIL.z),
				K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(0.92, 0.9, 0.87, 1.0), K.KIND_ENDGRAIN, 0, 0.0, 0.6)
	var pitch := TravLaneClimb.PITCH
	var rr := TravLaneClimb.RUNG_R
	var off := TravLaneClimb.first_rung_top()
	var k := 0
	while off + k * pitch <= WALK_TOP + 0.01:
		var y := off + k * pitch - rr
		_rung(kit, Vector3(-LADDER_HALF_W, y, 0), Vector3(LADDER_HALF_W, y, 0), rr, rng)
		k += 1


## A round rung from a to b (radius rr): one grid of 8 sides.
static func _rung(kit: K, a: Vector3, b: Vector3, rr: float, r: RandomNumberGenerator) -> void:
	const SEG := 8
	var ax := (b - a).normalized()
	var u := ax.cross(Vector3.UP).normalized()
	if u.length() < 0.5:
		u = ax.cross(Vector3.FORWARD).normalized()
	var v := u.cross(ax).normalized()
	var row := r.randi_range(0, 3)
	var rows_p := []
	var rows_n := []
	var rows_u := []
	var rows_c := []
	for e: Vector3 in [a, b]:
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		var U := PackedVector2Array()
		var C := PackedColorArray()
		for j in SEG + 1:
			var ang := TAU * j / SEG
			var nrm := u * cos(ang) + v * sin(ang)
			P.append(e + nrm * rr)
			N.append(nrm)
			U.append(Vector2((e - a).length() * 0.5, K.row_v(row, float(j) / SEG)))
			C.append(Color(0.72, 0.66, 0.58, 1.0))
		rows_p.append(P)
		rows_n.append(N)
		rows_u.append(U)
		rows_c.append(C)
	kit.grid(&"boards", rows_p, rows_n, rows_u, rows_c)


static func _blockhouse(kit: K, r: RandomNumberGenerator, detail: bool) -> void:
	# the lower storey: hewn logs with the doorway cut through the +Z face, a casing round it, the inside faces
	StructureGeometry.hewn_box(kit, Vector3(0, 1.75, 0), Vector3(4.5, 3.5, 4.5), 12, r, PackedStringArray(["+z"]), true, false)
	FortHollow.door_wall(kit, HOLLOW, r)
	FortHollow.interior(kit, HOLLOW, r)
	StructureGeometry.hewn_box(kit, Vector3(0, 4.6, 0), Vector3(5.5, 2.2, 5.5), 8, r, PackedStringArray(), false)
	# Soffit of the jettied upper floor and the cantilevered joist ends.
	for i in 4:
		var out := [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][i] as Vector3
		var along := Vector3.UP.cross(out)
		var c := Vector3(0, 3.5, 0)
		var a := c + out * 2.25 - along * 2.25
		var b := c + out * 2.25 + along * 2.25
		var e := c + out * 2.75 + along * 2.75
		var f := c + out * 2.75 - along * 2.75
		kit.quad(&"boards", a, b, e, f, Vector2(-2.25, K.row_v(i, 0)), Vector2(2.25, K.row_v(i, 0)),
				Vector2(2.75, K.row_v(i, 1)), Vector2(-2.75, K.row_v(i, 1)), Color(0.8, 0.78, 0.75, 0.55),
				K.KIND_TEX, 0.0, PackedColorArray(), Vector3.DOWN)
		for k in 5:
			var s := -1.8 + k * 0.9
			var p := c + out * 2.5 + along * s + Vector3(0, -0.1, 0)
			kit.box(&"boards", Transform3D(Basis(along, Vector3.UP, out), p), Vector3(0.15, 0.2, 0.5), K.GRAIN_Z,
					r.randi_range(0, 3), r.randf(), Color(0.9, 0.88, 0.85, 0.75))
		# Loopholes: two in the upper storey on every face, one below on the three faces away from the door.
		for s: float in [-1.2, 1.2]:
			StructureGeometry.loophole(kit, c + out * 2.75 + along * s + Vector3(0, 1.05, 0), out, 0.1, 0.32, 0.03)
		if out != Vector3.BACK:
			StructureGeometry.loophole(kit, c + out * 2.25 + Vector3(0, -1.9, 0), out, 0.1, 0.3, 0.03)
	# The door's casing on the +Z face (the leaf is hung by the piece: BuildDoor).
	StructureGeometry.door(kit, Vector3(1.2, 0.0, 2.25), Vector3.BACK, 0.9, FortHollow.lintel_y(HOLLOW), r, 0.04, false)
	StructureGeometry.gable_roof(kit, Vector3(0, 5.7, 0), 5.5, 5.5, 32.0, 0.0, r, detail)


## The parts not drawn with the kit: the flag's cloth.
static func parts(type: String) -> Array:
	if type != "flagpole":
		return []
	var mats := StructureMaterials.all()
	var cloth := StructureGeometry.flag_mesh(1.8, 1.1, mats[&"flag"])
	return [[cloth, Transform3D(Basis(), Vector3(0.08, 9.3, 0)), null]]


# --- Colliders, boxes, sockets, footprints -----------------------------------------------------------------

## [[shape, Transform3D, meta]]
static func colliders(type: String) -> Array:
	var out: Array = []
	match type:
		"walkway":
			out.append([_box_shape(Vector3(WALK_L, 0.15, WALK_D)), Transform3D(Basis(), Vector3(0, WALK_TOP - 0.075, 0)), {"surface": "wood"}])
			# the post under the rim beam (the classic fort had it as a collider too: nothing hangs or climbs where a post stands)
			out.append([_box_shape(Vector3(0.16, RIM_BOTTOM, 0.16)), Transform3D(Basis(), Vector3(0, RIM_BOTTOM * 0.5, WALK_D * 0.5 - 0.09)),
					{"surface": "wood"}])
		"walkway_ramp":
			var length := Vector2(RAMP_RUN, WALK_TOP).length()
			out.append([_box_shape(Vector3(RAMP_W, 0.15, length)), ramp_transform(), {"surface": "wood"}])
		"ladder":
			var h := ladder_height()
			for sx: float in [-LADDER_HALF_W, LADDER_HALF_W]:
				out.append([_box_shape(Vector3(LADDER_RAIL.x, h, LADDER_RAIL.z)),
						Transform3D(Basis(), Vector3(sx, h * 0.5, -LADDER_RAIL.z * 0.4)), {"surface": "wood", "no_traverse": true}])
		"blockhouse":
			# the lower storey is hollow: four walls (one split round the doorway), a lintel and a ceiling
			for bx: Array in FortHollow.collider_boxes(HOLLOW):
				out.append([_box_shape(bx[1]), Transform3D(Basis(), bx[0]), {"surface": "wood", "no_traverse": true}])
			out.append([_box_shape(Vector3(HOUSE, 2.2, HOUSE)), Transform3D(Basis(), Vector3(0, 4.6, 0)), {"surface": "wood", "no_traverse": true}])
		"flagpole":
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.07
			cyl.height = POLE_H
			out.append([cyl, Transform3D(Basis(), Vector3(0, POLE_H * 0.5, 0)), {"surface": "wood", "no_traverse": true}])
	return out


static func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


## Boxes well inside the piece: [[Transform3D, half extents]].
static func inner(type: String) -> Array:
	match type:
		"walkway":
			return [[Transform3D(Basis(), Vector3(0, WALK_TOP - 0.1, 0)), Vector3(WALK_L * 0.5 - 0.1, 0.06, WALK_D * 0.5 - 0.1)]]
		"walkway_ramp":
			var t := ramp_transform()
			return [[t, Vector3(RAMP_W * 0.5 - 0.1, 0.06, Vector2(RAMP_RUN, WALK_TOP).length() * 0.5 - 0.25)]]
		"ladder":
			return [[Transform3D(Basis(), Vector3(0, ladder_height() * 0.5, -0.1)), Vector3(LADDER_HALF_W, ladder_height() * 0.5 - 0.1, 0.08)]]
		"blockhouse":
			return [[Transform3D(Basis(), Vector3(0, 1.75, 0)), Vector3(2.15, 1.65, 2.15)],
					[Transform3D(Basis(), Vector3(0, 4.6, 0)), Vector3(2.65, 1.0, 2.65)]]
		"flagpole":
			return [[Transform3D(Basis(), Vector3(0, 3.0, 0)), Vector3(0.1, 2.9, 0.1)]]
	return []


static func center(type: String) -> Vector3:
	match type:
		"walkway":
			return Vector3(0, WALK_TOP, 0)
		"walkway_ramp":
			return Vector3(0, 1.0, 0)
		"ladder":
			return Vector3(0, 1.2, 0)
		"blockhouse":
			return Vector3(0, 2.5, 0)
		"flagpole":
			return Vector3(0, 3.0, 0)
	return Vector3(0, 1.3, 0)


## Footprint half extents (x, z) and the most the ground may fall away under it.
static func foot(type: String) -> Array:
	match type:
		"walkway":
			return [Vector2(WALK_L * 0.5, WALK_D * 0.5), 0.6]
		"walkway_ramp":
			return [Vector2(RAMP_W * 0.5, RAMP_RUN * 0.5), 0.7]
		"ladder":
			return [Vector2(0.35, 0.2), 0.3]
		"blockhouse":
			return [Vector2(HOUSE * 0.5, HOUSE * 0.5), 0.7]
		"flagpole":
			return [Vector2(0.15, 0.15), 0.4]
	return [Vector2(0.5, 0.5), 0.3]


## Sockets the fort pieces offer: [[kind, Transform3D]] (a socket frame's +Z points away from the piece).
static func sockets(type: String) -> Array:
	var out: Array = []
	match type:
		"palisade", "palisade_gate":
			# the inside face (-Z): a walkway's back edge against it
			out.append(["pal_inside", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.2))])
		"walkway":
			var h := WALK_L * 0.5
			out.append(["walk_end", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(h, 0, 0))])
			out.append(["walk_end", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-h, 0, 0))])
			out.append(["walk_front", Transform3D(Basis(), Vector3(0, 0, WALK_D * 0.5))])
	return out


## The socket kinds the fort pieces take: {kind: [frames of the piece in the socket's frame]}.
static func attach(type: String) -> Dictionary:
	var h := WALK_L * 0.5
	match type:
		"walkway":
			return {"pal_inside": [Transform3D(Basis(), Vector3(0, 0, WALK_D * 0.5))],
					"walk_end": [Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0, h))]}
		"walkway_ramp":
			return {"walk_front": [Transform3D(Basis(), Vector3(0, 0, RAMP_RUN * 0.5))]}
		"ladder":
			return {"walk_front": [Transform3D(Basis(), Vector3(0, 0, LADDER_OFF))]}
	return {}
