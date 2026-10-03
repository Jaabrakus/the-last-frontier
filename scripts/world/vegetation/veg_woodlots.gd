class_name VegWoodlots
extends RefCounted
## Small woods outside the forest's own square (data/world/woodlots.json): FrontierVegetation's layout (veg_layout.gd) places
## the forest only round the fort (+-WORLD); a woodlot is a stand of trees with saplings round its rim, a few rocks and props,
## put into that same layout once it is built (appended after everything in it: every forest index before them stays what it
## was), so the felling, cutting and quarrying (VegHarvest, GatherTools), the trunk and rock colliders, the drawn LODs,
## impostors and shadows and the save (VegHarvest's indices) take them as the forest's own.
##   VegWoodlots.add(layout)        FrontierVegetation.build, right after layout.build(): the trees, saplings, rocks, props
## The same every run and in headless runs too (placement by integer hashes of the grid cell and the woodlot's seed, no
## running RNG; the saplings as well, which the forest's own clutter makes only when it is drawn: a lean-to's poles are cut
## from them). Free play has them too: they are part of the land.
## The homestead's wood (docs/main_story.md 10.1, missions 1-7; Open Land's outro, "a stand of oaks and pines for timber"):
## Clearing's three trees, the lean-to's poles, the fire's and the hearth's stone and the house's logs a short walk from where
## the house goes, on the open land across the ford, which has no forest of its own.

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const PATH := "res://data/world/woodlots.json"
const SPECIES := {"white_pine": Assets.WHITE_PINE, "hemlock": Assets.HEMLOCK, "oak": Assets.OAK, "maple": Assets.MAPLE,
		"birch": Assets.BIRCH}
const SAPLING_OF := {Assets.WHITE_PINE: Assets.SAPLING_PINE, Assets.HEMLOCK: Assets.SAPLING_HEMLOCK,
		Assets.OAK: Assets.SAPLING_MAPLE, Assets.MAPLE: Assets.SAPLING_MAPLE, Assets.BIRCH: Assets.SAPLING_BIRCH}
const PROP_KINDS := {"stump_a": Assets.STUMP_A, "stump_b": Assets.STUMP_B, "rock_a": 2, "rock_b": 3, "rock_c": 4, "rock_d": 5,
		"rock_e": 6, "boulder": 7, "log": Assets.LOG}
## No tree within this of a rock or a prop the woodlot puts down, nor a sapling this near a trunk.
const PROP_CLEAR_M := 3.2
const SAPLING_CLEAR_M := 2.2

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = d if d is Dictionary else {"woodlots": []}
	return _data


## Every woodlot put into `layout` (a veg_layout.gd Layout, built). Returns how many trees, saplings and rocks went in
## ({trees, saplings, rocks, props}; also in layout.stats["woodlots"]).
static func add(layout: Object) -> Dictionary:
	var n := {"trees": 0, "saplings": 0, "rocks": 0, "props": 0}
	if layout == null:
		return n
	for w: Variant in data().get("woodlots", []):
		if w is Dictionary:
			var got := add_one(layout, w)
			for k in n:
				n[k] = int(n[k]) + int(got.get(k, 0))
	var st: Variant = layout.get("stats")
	if st is Dictionary:
		(st as Dictionary)["woodlots"] = n
	return n


## One woodlot (see data/world/woodlots.json's _doc) put into `layout`.
static func add_one(layout: Object, w: Dictionary) -> Dictionary:
	var sd := int(w.get("seed", 1757))
	var c := _xz(w.get("center", [0.0, 0.0]))
	var rad := _xz(w.get("radii", [30.0, 30.0]))
	rad = Vector2(maxf(rad.x, 1.0), maxf(rad.y, 1.0))
	var max_y := cos(deg_to_rad(float(w.get("max_slope_deg", 28.0))))
	var out := {}
	# the rocks and props first: the trees keep clear of them
	var placed: Array[Vector2] = []
	var rocks := 0
	var props := 0
	var k := 0
	for r: Variant in w.get("rocks", []):
		if r is Array and (r as Array).size() >= 3:
			var a: Array = r
			if _prop(out, String(a[2]), Vector2(float(a[0]), float(a[1])), _h(k, 0, 31, sd) * TAU,
					float(a[3]) if a.size() > 3 else 1.0, sd, k):
				placed.append(Vector2(float(a[0]), float(a[1])))
				rocks += 1
		k += 1
	for p: Variant in w.get("props", []):
		if p is Dictionary:
			var at := _xz((p as Dictionary).get("at", [0.0, 0.0]))
			if _prop(out, String((p as Dictionary).get("kind", "log")), at, deg_to_rad(float((p as Dictionary).get("yaw", 0.0))),
					float((p as Dictionary).get("scale", 1.0)), sd, k):
				placed.append(at)
				props += 1
		k += 1
	var clear: Array = []
	for cl: Variant in w.get("clear", []):
		if cl is Array and (cl as Array).size() >= 3:
			clear.append(Vector3(float(cl[0]), float(cl[1]), float(cl[2])))
	for q in placed:
		clear.append(Vector3(q.x, q.y, PROP_CLEAR_M))
	# the trees: a jittered grid in the ellipse, thinning toward its rim
	var weights := _weights(w.get("species", {"oak": 1.0}))
	var sp := maxf(float(w.get("spacing", 8.0)), 2.0)
	var keep := float(w.get("keep", 0.8))
	var trunks: Array[Vector2] = []
	var trees := 0
	for iz in range(floori((c.y - rad.y) / sp), ceili((c.y + rad.y) / sp) + 1):
		for ix in range(floori((c.x - rad.x) / sp), ceili((c.x + rad.x) / sp) + 1):
			var x := (ix + 0.15 + 0.7 * _h(ix, iz, 1, sd)) * sp
			var z := (iz + 0.15 + 0.7 * _h(ix, iz, 2, sd)) * sp
			var e := Vector2((x - c.x) / rad.x, (z - c.y) / rad.y).length()
			if e > 1.0 or _h(ix, iz, 3, sd) > keep * (1.0 - 0.75 * smoothstep(0.65, 1.0, e)):
				continue
			if not _ground_ok(x, z, max_y) or _in_clear(x, z, clear):
				continue
			var kind := _pick(weights, _h(ix, iz, 4, sd))
			var edge := smoothstep(0.7, 1.0, e)
			var variant := 0
			if kind == Assets.WHITE_PINE or kind == Assets.HEMLOCK:
				variant = 2 if edge > 0.55 else (0 if _h(ix, iz, 6, sd) < 0.5 else 1)
			else:
				variant = int(_h(ix, iz, 6, sd) * 2.999)
			var s := lerpf(0.86, 1.16, _h(ix, iz, 7, sd)) * lerpf(1.0, 0.9, edge)
			_push(out, "tree_pos", Vector3(x, FrontierTerrain.height_at(x, z), z))
			_push(out, "tree_yaw", _h(ix, iz, 8, sd) * TAU)
			_push(out, "tree_scale", s)
			_push(out, "tree_kind", kind)
			_push(out, "tree_variant", variant)
			_push(out, "tree_custom", Color(_h(ix, iz, 14, sd), pow(_h(ix, iz, 12, sd), 3.0) * 0.7 + 0.2 * edge * _h(ix, iz, 13, sd),
					_h(ix, iz, 15, sd), 0.0))
			_push(out, "tree_collider", 1)
			trunks.append(Vector2(x, z))
			trees += 1
	# the saplings round the wood's rim (in the plants: no collider, cut for poles)
	var saplings := 0
	var sap: Dictionary = w.get("saplings", {})
	var want := int(sap.get("count", 0))
	var ring := _xz(sap.get("ring", [0.8, 1.2]))
	var sw := _weights(sap.get("species", {"white_pine": 1.0}))
	var tries := 0
	while saplings < want and tries < want * 12:
		var ang := _h(tries, 0, 41, sd) * TAU
		var er := lerpf(ring.x, ring.y, _h(tries, 0, 42, sd))
		var x := c.x + cos(ang) * rad.x * er
		var z := c.y + sin(ang) * rad.y * er
		tries += 1
		if not _ground_ok(x, z, max_y) or _in_clear(x, z, clear) or _near_any(Vector2(x, z), trunks, SAPLING_CLEAR_M):
			continue
		var tree_kind := _pick(sw, _h(tries, 0, 43, sd))
		var kind: int = SAPLING_OF.get(tree_kind, Assets.SAPLING_PINE)
		_push(out, "plant_pos", Vector3(x, FrontierTerrain.height_at(x, z), z))
		_push(out, "plant_yaw", _h(tries, 0, 44, sd) * TAU)
		_push(out, "plant_scale", lerpf(0.9, 1.25, _h(tries, 0, 45, sd)))
		_push(out, "plant_kind", kind)
		_push(out, "plant_variant", int(_h(tries, 0, 46, sd) * 2.999))
		_push(out, "plant_custom", Color(_h(tries, 0, 47, sd), 0.0, 0.5))
		trunks.append(Vector2(x, z))
		saplings += 1
	_flush(layout, out)
	return {"trees": trees, "saplings": saplings, "rocks": rocks, "props": props}


## A rock or a prop (stump, log) at `at`, sunk into the ground as the forest's are. False when the ground there will not have it.
static func _prop(out: Dictionary, kind_name: String, at: Vector2, yaw: float, s: float, sd: int, k: int) -> bool:
	if not PROP_KINDS.has(kind_name) or not FrontierTerrain.in_world(at.x, at.y) or _wet(at.x, at.y):
		return false
	var kind: int = PROP_KINDS[kind_name]
	var size: Array = Assets.prop(kind).get("size", [1.0, 1.0, 1.0])
	var sink := 0.05
	if kind >= Assets.ROCK_FIRST and kind <= Assets.ROCK_LAST:
		sink = float(size[1]) * s * lerpf(0.15, 0.35, _h(k, 0, 32, sd))
	elif kind == Assets.LOG:
		sink = float(size[1]) * s * 0.25
	_push(out, "prop_pos", Vector3(at.x, FrontierTerrain.height_at(at.x, at.y) - sink, at.y))
	_push(out, "prop_yaw", yaw)
	_push(out, "prop_scale", s)
	_push(out, "prop_kind", kind)
	var tilt := Vector3((_h(k, 0, 33, sd) - 0.5) * 0.1, 0.0, (_h(k, 0, 34, sd) - 0.5) * 0.1)
	_push(out, "prop_tilt", tilt)
	return true


## One value for the layout's packed array `field`, kept in `out` until _flush puts them all in at once.
static func _push(out: Dictionary, field: String, v: Variant) -> void:
	if not out.has(field):
		out[field] = []
	(out[field] as Array).append(v)


## What _push kept, onto the end of the layout's arrays (each array taken, grown once and put back: they are values).
static func _flush(layout: Object, out: Dictionary) -> void:
	for field: String in out:
		var a: Variant = layout.get(field)
		if a == null:
			push_error("VegWoodlots: the layout has no %s" % field)
			continue
		for v: Variant in out[field]:
			a.append(v)
		layout.set(field, a)


static func _ground_ok(x: float, z: float, max_y: float) -> bool:
	if not FrontierTerrain.in_world(x, z) or not FrontierTerrain.in_world(x + 3.0, z) or not FrontierTerrain.in_world(x, z - 3.0):
		return false
	return FrontierTerrain.normal_at(x, z).y >= max_y and not _wet(x, z)


static func _wet(x: float, z: float) -> bool:
	return WorldRiver.has_water() and WorldRiver.surface_at(x, z) > FrontierTerrain.height_at(x, z) - 0.3


static func _in_clear(x: float, z: float, clear: Array) -> bool:
	for cl: Vector3 in clear:
		if Vector2(x - cl.x, z - cl.y).length() < cl.z:
			return true
	return false


static func _near_any(p: Vector2, pts: Array[Vector2], r: float) -> bool:
	for q in pts:
		if p.distance_to(q) < r:
			return true
	return false


## [[kind, weight], ...] from {species id: weight}, the unknown ids left out.
static func _weights(sp: Variant) -> Array:
	var out: Array = []
	if sp is Dictionary:
		for id: Variant in sp:
			if SPECIES.has(String(id)) and float(sp[id]) > 0.0:
				out.append([int(SPECIES[String(id)]), float(sp[id])])
	if out.is_empty():
		out.append([Assets.OAK, 1.0])
	return out


static func _pick(weights: Array, u: float) -> int:
	var total := 0.0
	for wk: Array in weights:
		total += float(wk[1])
	var roll := u * total
	for wk: Array in weights:
		roll -= float(wk[1])
		if roll <= 0.0:
			return int(wk[0])
	return int((weights.back() as Array)[0])


static func _xz(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


## Uniform 0..1 from integer coordinates, a stream and the woodlot's seed (StoryLayerProps._h's hash).
static func _h(ix: int, iz: int, k: int, sd: int) -> float:
	var n := (ix * 73856093) ^ (iz * 19349663) ^ (k * 83492791) ^ (sd * 2654435761)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / float(0x1000000)
