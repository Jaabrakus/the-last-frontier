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

## THE STILL REACHES (Thủy Vân; the river block's "reaches", data/world/maps/r1_grey/squares.json): a stretch whose flow is
## scaled by the world's state, {id, z_from, z_to, ease_m, scale_by_state: {state: scale}}: its state's scale from ease_m
## inside its ends, eased back to 1 at z_from and z_to, unchanged past them. `reach_state` "" (the frontier and its tests):
## no reach applies and the river is as it always was. ThuyVanLevel sets it ("S0" running, "S1" still).
##   flow_scale(z)     the flow there x this (flow_at, so WaterSurface.current_at: a boat drifts to a stop where it is 0)
##   still_amount(z)   1 - flow_scale, 0..1: how still it lies (RiverWater's look and voice, FishLife's fish)
##   still_band()      the first reach the state stills: {z_from, z_to, ease_m, amount} ({} none)
##   dir_at(z)         downstream there, unit, whatever the state (the water's ribbon, a site facing the river)
static var reach_state := ""

## A REGION'S CHANNEL (Thủy Vân's R1, data/world/maps/r1/region.json "river": WaterNetwork.as_world_river_block of its
## z-monotonic main channel, written by tools/thuyvan_art/terrain/write_r1_region.py): "nodes" [[z, x, level,
## half_width], ...] north to south replace x0/meanders/level0/fall: x_at, level_at and dir_at read the nodes (linear in
## z), the banks are the block's "bank", and there are no rapids. Without "nodes" (the frontier, r1_grey) nothing here
## changes.
static var _nodes_src: Variant = null
static var _nz := PackedFloat64Array()
static var _nx := PackedFloat64Array()
static var _nl := PackedFloat64Array()


static func data() -> Dictionary:
	if off:
		return {}
	return WorldSquares.data().get("river", {})


## The block's nodes as arrays (z ascending); false when it has none.
static func _has_nodes(d: Dictionary) -> bool:
	if not d.has("nodes"):
		return false
	if not is_same(d, _nodes_src):
		_nodes_src = d
		_nz = PackedFloat64Array()
		_nx = PackedFloat64Array()
		_nl = PackedFloat64Array()
		for r: Array in d.nodes:
			_nz.append(float(r[0]))
			_nx.append(float(r[1]))
			_nl.append(float(r[2]))
	return _nz.size() > 1


## Node array `v` at z (linear; held past the ends).
static func _node_lerp(v: PackedFloat64Array, z: float) -> float:
	var i := clampi(_nz.bsearch(z) - 1, 0, _nz.size() - 2)
	var t := clampf((z - _nz[i]) / maxf(_nz[i + 1] - _nz[i], 1e-6), 0.0, 1.0)
	return lerpf(v[i], v[i + 1], t)


static func x_at(z: float) -> float:
	var d := data()
	if _has_nodes(d):
		return _node_lerp(_nx, z)
	var x := float(d.get("x0", 832.0))
	for m: Array in d.get("meanders", []):
		x += float(m[0]) * sin(z / float(m[1]) + float(m[2]))
	return x


static func level_at(z: float) -> float:
	if off:
		return 0.0
	var d := data()
	if _has_nodes(d):
		return _node_lerp(_nl, z)
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


## Downstream there (flat, unit): southward (+Z) along its bends; x flow_scale(z) (in a still reach shorter, or nothing).
static func flow_at(z: float) -> Vector3:
	if reach_state == "":
		return dir_at(z)
	return dir_at(z) * flow_scale(z)


## Downstream there (flat, unit), whatever the state.
static func dir_at(z: float) -> Vector3:
	if _has_nodes(data()):
		return Vector3(_node_lerp(_nx, z + 4.0) - _node_lerp(_nx, z - 4.0), 0.0, 8.0).normalized()
	var dxdz := 0.0
	for m: Array in data().get("meanders", []):
		dxdz += float(m[0]) / float(m[1]) * cos(z / float(m[1]) + float(m[2]))
	return Vector3(dxdz, 0.0, 1.0).normalized()


static func reaches() -> Array:
	return data().get("reaches", [])


## How far into reach `r` z lies, 0..1: 1 from ease_m inside its ends, eased to 0 at them, 0 past them.
static func _in_reach(r: Dictionary, z: float) -> float:
	var z0 := float(r.get("z_from", 0.0))
	var z1 := float(r.get("z_to", 0.0))
	if z <= z0 or z >= z1:
		return 0.0
	var e := maxf(float(r.get("ease_m", 0.0)), 0.001)
	return smoothstep(z0, z0 + e, z) * smoothstep(z1, z1 - e, z)


## The flow there x this: 1 outside every reach and with no state; inside one, its scale for the state.
static func flow_scale(z: float) -> float:
	if reach_state == "" or off:
		return 1.0
	var s := 1.0
	for r: Dictionary in reaches():
		var by: Dictionary = r.get("scale_by_state", {})
		if by.has(reach_state):
			s *= lerpf(1.0, float(by[reach_state]), _in_reach(r, z))
	return s


## How still it lies there, 0 (running) .. 1 (still).
static func still_amount(z: float) -> float:
	return clampf(1.0 - flow_scale(z), 0.0, 1.0)


## The first reach the state slows: {z_from, z_to, ease_m, amount (1 - its scale)}; {} none.
static func still_band() -> Dictionary:
	if reach_state == "" or off:
		return {}
	for r: Dictionary in reaches():
		var by: Dictionary = r.get("scale_by_state", {})
		if by.has(reach_state) and float(by[reach_state]) < 1.0:
			return {"z_from": float(r.get("z_from", 0.0)), "z_to": float(r.get("z_to", 0.0)),
					"ease_m": float(r.get("ease_m", 0.0)), "amount": 1.0 - clampf(float(by[reach_state]), 0.0, 1.0)}
	return {}


## How far from its centre its banks top out (past there, never water).
static func bank() -> float:
	return float(data().get("bank", 14.0))


## Where it has ground under it along z: the squares with ground in its column (Vector2.ZERO: none).
static func z_range() -> Vector2:
	if off:
		return Vector2.ZERO
	var d := data()
	var x0 := float(d.get("x0", 832.0))
	if _has_nodes(d):
		x0 = _node_lerp(_nx, (_nz[0] + _nz[_nz.size() - 1]) * 0.5)
	var squares := FrontierTerrain.squares()          # (loads the ground first: its origin)
	var col := roundi((x0 - FrontierTerrain.origin.x) / FrontierTerrain.SQUARE_M)
	var lo := INF
	var hi := -INF
	for sq: Vector2i in squares:
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
