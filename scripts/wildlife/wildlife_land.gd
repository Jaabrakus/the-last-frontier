class_name WildlifeLand
extends RefCounted
## Every square's own numbers (user 2026-09-27: "apply the settlers of catan functions so each tile has these power
## meters", "this one is dense with woods and these types of animals the next tile over could have more mammoths and
## open land and etc or one could be filled with clif walls where we can mine for stones and water"): for each of the
## world's squares (WorldSquares) a WildlifeEcology with its type's caps (the most of each animal), and its meters: its
## trees and stone (its type's, 0..1: the fort's read from what has been felled and quarried, WildlifeSpawner) and its
## water. The squares run together (advance()):
##   refill   a square short of a species (under its floor) gets wanderers from the squares beside it: at WANDER of the
##            rate with none to spare there, up to WANDER + 1 with them full (never none: nothing is gone for good)
##   spill    a square holding more than its food carries sends SPILL of the surplus a day to the squares beside it
##            with room, by their room (a herd moving on from a stripped square, not all starving there)
## Fish: each square's water (its type's `water`) has its own numbers (FishStock: the fish power level, by species, with
## the runs of the month), run with the rest (advance(d, month)); FishLife puts the ones near the player in the water.
## Only the fort's square has ground and bodies today (WildlifeSpawner keeps its animals to its numbers); the rest run as
## numbers till theirs are built. Kept in a save (to_dict / from_dict: the wildlife part).

const WANDER := 0.25
const SPILL := 0.3

## Square -> WildlifeEcology.
var squares := {}
## Square -> {trees, stone: 0..1, water: String}.
var meters := {}
## Square -> FishStock (the squares whose water holds fish).
var fish := {}


func _init() -> void:
	for sq in WorldSquares.squares():
		var t := WorldSquares.type_of(sq)
		# (a story's year layer has its own numbers: StoryLayer.animals_of, the 1757 valley no mammoths or bison)
		squares[sq] = WildlifeEcology.new(StoryLayer.animals_of(WorldSquares.type_id(sq), t.get("animals", {})))
		meters[sq] = {"trees": float(t.get("trees", 1.0)), "stone": float(t.get("stone", 0.0)), "water": String(t.get("water", ""))}
		var fs := FishStock.new(String(t.get("water", "")))
		if fs.has_fish():
			fish[sq] = fs
	if squares.is_empty():
		squares[Vector2i.ZERO] = WildlifeEcology.new()
		meters[Vector2i.ZERO] = {"trees": 1.0, "stone": 0.3, "water": "brook"}
		fish[Vector2i.ZERO] = FishStock.new("brook")


## Square `sq`'s numbers (the fort's when it is off the grid).
func ecology(sq: Vector2i) -> WildlifeEcology:
	return squares.get(sq, squares.get(Vector2i.ZERO))


## The numbers of the square at world position `pos`.
func at(pos: Vector3) -> WildlifeEcology:
	return ecology(WorldSquares.square_at(pos))


## The fish numbers of the square at world position `pos` (null: no fish water there).
func fish_at(pos: Vector3) -> FishStock:
	return fish.get(WorldSquares.square_at(pos))


## `d` game days pass over every square, a day at a time: each runs its own numbers with its neighbours' refill, then
## the overfull spill over; the fish run theirs, `month` (1-12) setting the runs.
func advance(d: float, month := 9) -> void:
	while d > 0.0:
		var step := minf(d, 1.0)
		d -= step
		var refills := {}
		for sq: Vector2i in squares:
			refills[sq] = _refill(sq)
		for sq: Vector2i in squares:
			(squares[sq] as WildlifeEcology).advance(step, refills[sq])
		_spill(step)
		for sq: Vector2i in fish:
			(fish[sq] as FishStock).advance(step, month)


## How fast wanderers come into `sq`, by species: WANDER, plus how full the squares beside it are of them.
func _refill(sq: Vector2i) -> Dictionary:
	var out := {}
	var nb := WorldSquares.neighbours(sq)
	for s: String in WildlifeEcology.SPEC:
		var full := 0.0
		var n := 0
		for o: Vector2i in nb:
			var e: WildlifeEcology = squares.get(o)
			if e == null or e.cap_of(s) <= 0.0:
				continue
			full += clampf(float(e.pop[s]) / e.cap_of(s), 0.0, 1.0)
			n += 1
		out[s] = WANDER + (full / float(n) if n > 0 else 0.0)
	return out


## The overfull send part of their surplus on to the squares beside them with room.
func _spill(step: float) -> void:
	var moves := []
	for sq: Vector2i in squares:
		var e: WildlifeEcology = squares[sq]
		for s: String in WildlifeEcology.SPEC:
			var surplus := float(e.pop[s]) - e.capacity(s)
			if surplus <= 0.5:
				continue
			var rooms := {}
			var total := 0.0
			for o: Vector2i in WorldSquares.neighbours(sq):
				var oe: WildlifeEcology = squares.get(o)
				if oe == null:
					continue
				var room := oe.capacity(s) - float(oe.pop[s])
				if room > 0.0:
					rooms[o] = room
					total += room
			if total <= 0.0:
				continue
			var go := minf(surplus * SPILL * step, total)
			moves.append([sq, s, go, rooms, total])
	for m: Array in moves:
		var e: WildlifeEcology = squares[m[0]]
		var s: String = m[1]
		var go: float = m[2]
		e.pop[s] = float(e.pop[s]) - go
		for o: Vector2i in m[3]:
			var oe: WildlifeEcology = squares[o]
			oe.pop[s] = minf(float(oe.pop[s]) + go * float(m[3][o]) / float(m[4]), oe.cap_of(s))


## Every square in a line (tests, the debug log).
func summary() -> String:
	var lines: Array[String] = []
	for sq: Vector2i in squares:
		var e: WildlifeEcology = squares[sq]
		var parts: Array[String] = []
		for s: String in WildlifeEcology.SPEC:
			if e.cap_of(s) > 0.0:
				parts.append("%s %.1f" % [s, float(e.pop[s])])
		lines.append("%s %s: %s  trees %.2f stone %.2f %s" % [str(sq), WorldSquares.type_id(sq), " ".join(parts),
				float(meters[sq].trees), float(meters[sq].stone), String(meters[sq].water)])
		if fish.has(sq):
			lines.append("    fish " + (fish[sq] as FishStock).summary())
	return "\n".join(lines)


func to_dict() -> Dictionary:
	var sd := {}
	var md := {}
	var fd := {}
	for sq: Vector2i in squares:
		var key := "%d,%d" % [sq.x, sq.y]
		sd[key] = (squares[sq] as WildlifeEcology).to_dict()
		md[key] = (meters[sq] as Dictionary).duplicate()
		if fish.has(sq):
			fd[key] = (fish[sq] as FishStock).to_dict()
	return {"squares": sd, "meters": md, "fish": fd}


## Back from a save; a save from before the squares (one set of numbers): the fort's.
func from_dict(d: Dictionary) -> void:
	if not d.has("squares"):
		if d.has("pop"):
			ecology(Vector2i.ZERO).from_dict(d)
		return
	var sd: Dictionary = d.squares
	var md: Dictionary = d.get("meters", {})
	var fd: Dictionary = d.get("fish", {})
	for key: String in sd:
		var xy := key.split(",")
		if xy.size() != 2:
			continue
		var sq := Vector2i(int(xy[0]), int(xy[1]))
		if squares.has(sq):
			(squares[sq] as WildlifeEcology).from_dict(sd[key])
		if md.has(key) and meters.has(sq):
			for k: String in md[key]:
				meters[sq][k] = md[key][k]
		if fd.has(key) and fish.has(sq):
			(fish[sq] as FishStock).from_dict(fd[key])
