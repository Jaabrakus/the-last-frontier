class_name WorldRiver
extends RefCounted
## The river (data/world/squares.json "river"; user 2026-09-27: "add another square map thats open planes with a river to
## a lake"): north-south through the squares east of the fort. bake_terrain.py cuts its bed from the same numbers;
## RiverWater puts its water in.
##   x_at(z)           its centre line
##   level_at(z)       its surface, falling southward (most of its fall at its rapids)
##   rapid_at(z)       1 along a rapid (white water: shallow, stony, boulders breaking it; the fords), 0 elsewhere
##   rapids()          [{z, length, drop}] (squares.json "rapids")
##   flow_at(z)        the way it runs there (flat, downstream: southward along its bends)
##   surface_at(x, z)  the water's surface there, or -INF where there is none (its banks, the ground over it)
##   depth_at(pos)     how deep the water is over the ground at pos (0 where there is none)
##   z_range()         where it has ground under it (the squares with ground along it); has_water()
## Water lies where the ground is under its level within `bank` m of its centre.
## `off` (the Tidebreak ring, scenes/ring.tscn: a light scene with no open land under it): no river at all, and nothing here
## touches FrontierTerrain's baked data (its 19 MB never loads for it): has_water false, data {}, z_range ZERO, surface_at
## NO_WATER, depth_at and level_at 0. RingLevel sets it and puts it back as it leaves.

const NO_WATER := -INF

static var off := false


static func data() -> Dictionary:
	if off:
		return {}
	return WorldSquares.data().get("river", {})


static func x_at(z: float) -> float:
	var d := data()
	var x := float(d.get("x0", 832.0))
	for m: Array in d.get("meanders", []):
		x += float(m[0]) * sin(z / float(m[1]) + float(m[2]))
	return x


static func level_at(z: float) -> float:
	if off:
		return 0.0
	var d := data()
	var lv := float(d.get("level0", -4.0)) - float(d.get("fall", 0.004)) * (z + float(FrontierTerrain.GRID_HALF))
	for r: Array in d.get("rapids", []):
		lv -= float(r[2]) * smoothstep(float(r[0]) - float(r[1]) * 0.5, float(r[0]) + float(r[1]) * 0.5, z)
	return lv


## 1 along a rapid, falling to 0 over rapid_ramp m past its ends.
static func rapid_at(z: float) -> float:
	var d := data()
	var w := 0.0
	for r: Array in d.get("rapids", []):
		var half := float(r[1]) * 0.5
		w = maxf(w, smoothstep(half + float(d.get("rapid_ramp", 12.0)), half, absf(z - float(r[0]))))
	return w


static func rapids() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Array in data().get("rapids", []):
		out.append({"z": float(r[0]), "length": float(r[1]), "drop": float(r[2])})
	return out


## Downstream there (flat, unit): southward (+Z) along its bends.
static func flow_at(z: float) -> Vector3:
	var dxdz := 0.0
	for m: Array in data().get("meanders", []):
		dxdz += float(m[0]) / float(m[1]) * cos(z / float(m[1]) + float(m[2]))
	return Vector3(dxdz, 0.0, 1.0).normalized()


## How far from its centre its banks top out (past there, never water).
static func bank() -> float:
	return float(data().get("bank", 14.0))


## Where it has ground under it along z: the squares with ground in its column (Vector2.ZERO: none).
static func z_range() -> Vector2:
	if off:
		return Vector2.ZERO
	var col := roundi(float(data().get("x0", 832.0)) / FrontierTerrain.SQUARE_M)
	var lo := INF
	var hi := -INF
	for sq: Vector2i in FrontierTerrain.squares():
		if sq.x != col:
			continue
		var o := FrontierTerrain.square_origin(sq)
		lo = minf(lo, o.z - FrontierTerrain.GRID_HALF)
		hi = maxf(hi, o.z + FrontierTerrain.GRID_HALF)
	return Vector2(lo, hi) if lo < hi else Vector2.ZERO


static func has_water() -> bool:
	if off:
		return false
	return not data().is_empty() and z_range() != Vector2.ZERO


## The water's surface at (x, z): its level where the ground lies under it within its banks; NO_WATER elsewhere.
static func surface_at(x: float, z: float) -> float:
	if off:
		return NO_WATER
	var zr := z_range()
	if z < zr.x or z > zr.y or absf(x - x_at(z)) > bank():
		return NO_WATER
	var lv := level_at(z)
	return lv if FrontierTerrain.height_at(x, z) < lv else NO_WATER


## How deep the water is over the ground at pos (0 where there is none).
static func depth_at(pos: Vector3) -> float:
	if off:
		return 0.0
	var s := surface_at(pos.x, pos.z)
	return maxf(s - FrontierTerrain.height_at(pos.x, pos.z), 0.0) if s != NO_WATER else 0.0
