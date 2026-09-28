class_name WorldSquares
extends RefCounted
## The world's squares (data/world/squares.json; user 2026-09-27: "add another square map", "so we need a 3 by 3 map
## right?", each square its own kind: "this one is dense with woods and these types of animals the next tile over could
## have more mammoths and open land and etc or one could be filled with clif walls where we can mine for stones and
## water"). A grid of size_m squares along the world's axes; the middle one, square (0, 0), is the fort's (the level
## built today); x counts along +X, y along +Z. Each square is a type (dense woods, open land, cliffs, a lake...) that
## sets what it holds: the most of each animal (WildlifeLand), its trees, stone and water.

const PATH := "res://data/world/squares.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
	return _data


static func size_m() -> float:
	return float(data().get("size_m", 832.0))


static func _grid() -> Array:
	return data().get("grid", [["fort_woods"]])


## The square at world position `pos` ((0, 0) the fort's), whether or not the grid has it.
static func square_at(pos: Vector3) -> Vector2i:
	var s := size_m()
	return Vector2i(floori((pos.x + s * 0.5) / s), floori((pos.z + s * 0.5) / s))


## The world position of square `sq`'s middle (on y 0).
static func center_of(sq: Vector2i) -> Vector3:
	return Vector3(float(sq.x) * size_m(), 0.0, float(sq.y) * size_m())


## Every square of the grid.
static func squares() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var g := _grid()
	var r0 := (g.size() - 1) / 2
	for r in g.size():
		var row: Array = g[r]
		var c0 := (row.size() - 1) / 2
		for c in row.size():
			out.append(Vector2i(c - c0, r - r0))
	return out


static func has_square(sq: Vector2i) -> bool:
	return type_id(sq) != ""


## Square `sq`'s type ("" off the grid).
static func type_id(sq: Vector2i) -> String:
	var g := _grid()
	var r := sq.y + (g.size() - 1) / 2
	if r < 0 or r >= g.size():
		return ""
	var row: Array = g[r]
	var c := sq.x + (row.size() - 1) / 2
	if c < 0 or c >= row.size():
		return ""
	return String(row[c])


## Square `sq`'s type data ({} off the grid): name, animals (the most of each), trees, stone, water, built.
static func type_of(sq: Vector2i) -> Dictionary:
	return (data().get("types", {}) as Dictionary).get(type_id(sq), {})


## The squares beside `sq` (not the corners) on the grid.
static func neighbours(sq: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if has_square(sq + d):
			out.append(sq + d)
	return out
