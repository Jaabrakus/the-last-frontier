extends RefCounted
## Deterministic vegetation layout (package C): where every tree, stump, log, rock, sapling, shrub
## and fern goes. Pure data (packed arrays), no nodes, so vegetation.gd can build colliders only
## (headless) or colliders + MultiMeshes, and tools/environment/vegetation/check_vegetation.gd can
## inspect the same layout.
##
## Rules (look-dev spec, sections 6 and 7):
##   - Everything is a function of the level seed (1776) and FrontierTerrain's statics
##     (height_at, normal_at, flat_distance, forest_density). Placement uses per-cell integer
##     hashes, not a running RNG, so a rejected candidate never shifts the rest of the layout, and
##     the collider layout is identical on every preset and in headless runs.
##   - Canopy trees where forest_density > ~0.5 (noisy threshold), slope < 32 deg, at least 3 m
##     outside the flat zones; ~1 per 55 m2 inside +-220 m, ~1 per 90 m2 beyond.
##   - Species by terrain: hemlock in low ground and on north slopes, white pine on high ground,
##     oak / maple in patches, birch at the forest edge; the pine / hemlock "edge" variants (low
##     crowns) along the forest edge. A hardwood forest with the conifers in it (user 2026-09-28,
##     "more hardwoods": the hills colour in autumn and stand bare in winter): about 58 % oak,
##     maple and birch, 42 % pine and hemlock (was 39 / 61).
##   - Sun corridors (spec 7.4): every tree whose crown would cut the ray from a protected point
##     toward EnvironmentRig.sun_direction() within 200 m is shortened (down to half size), or
##     replaced by a sapling, or dropped.
##   - Protected zones: nothing in the flat zones (fort clearing, range lane) except below-0.5 m
##     ground cover; no colliders within 1 m of them.
##   - Colliders (and their placement) never depend on the quality preset; clutter without
##     colliders (saplings, shrubs, ferns, brush) scales with settings.clutter_density and is only
##     generated when meshes are built.

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")

const WORLD := 396.0                 ## Half extent of the placement area (terrain is +-400).
const NEAR := 220.0                  ## Denser forest inside +-NEAR.
const TREE_CELL := 7.4               ## Jittered grid: ~1 tree per 55 m2 near the fort.
const FAR_KEEP := 0.61               ## 55 / 90: ~1 per 90 m2 beyond NEAR.
const MAX_SLOPE_Y := 0.848           ## cos 32 deg
const CORRIDOR_LENGTH := 200.0
const CLUTTER_RADIUS := WORLD       ## Saplings, shrubs, ferns everywhere on the land (user 2026-10-01: "all the vegetation to show up", not only round the fort; was 230 m).
const CELL := 50.0                   ## Render cell of vegetation.gd (variant choice per cell).
const CLUTTER_CELL := 25.0

## Protected points whose ray toward the sun must stay clear (spec 7.4).
const PROTECTED := [
	Vector3(0, 1.2, 6), Vector3(0, 1.2, -20),
	Vector3(-2.5, 1.2, -30), Vector3(0, 1.2, -45), Vector3(2.5, 1.2, -70),
	Vector3(-2.5, 1.2, -95), Vector3(0, 1.2, -120), Vector3(2.5, 1.2, -140),
]
const MOVER_Z := -60.0
## Animation-test corridors (tests/anim/lib/foot_slip.gd) run north from these points: they are
## inside the flat zones, which stay clear anyway; listed for the checker.
const ANIM_CORRIDORS := [Vector2(7, -22), Vector2(-7, -22), Vector2(11, -22), Vector2(-11, -22),
		Vector2(7, -60), Vector2(-7, -60), Vector2(0, 6)]

var seed_value := 1776
var sun_dir := Vector3(-0.6384, 0.3272, 0.6967)

# Trees (canopy + corridor-shortened + saplings that replaced trees): packed per instance.
var tree_pos := PackedVector3Array()         ## base on the ground (x, height_at, z)
var tree_yaw := PackedFloat32Array()
var tree_scale := PackedFloat32Array()
var tree_kind := PackedInt32Array()          ## Assets.SPECIES index
var tree_variant := PackedInt32Array()
var tree_custom := PackedColorArray()        ## x variation, y dryness, z random
var tree_collider := PackedByteArray()       ## 1 = has a trunk collider

# Props with colliders (stumps, logs, rocks) and without (roots, brush, ferns).
var prop_pos := PackedVector3Array()
var prop_yaw := PackedFloat32Array()
var prop_scale := PackedFloat32Array()
var prop_kind := PackedInt32Array()          ## Assets.PROPS index
var prop_tilt := PackedVector3Array()        ## small random tilt (rad) about x / z

# Small plants without colliders (saplings, shrubs): same fields as trees.
var plant_pos := PackedVector3Array()
var plant_yaw := PackedFloat32Array()
var plant_scale := PackedFloat32Array()
var plant_kind := PackedInt32Array()
var plant_variant := PackedInt32Array()
var plant_custom := PackedColorArray()

var stats := {}
## Clipping clean-up pass (2026-09-25, _fix_clipping()): false builds the layout as before it
## (tools/environment/check_clipping.gd raw=1).
var fix_clipping := true
var _rays: Array = []                        ## [origin, dir] per protected ray
var _occupied := {}                          ## Vector2i(3 m cell) -> true, for collider spacing
var _crowns := {}                            ## species -> crown model (from trees.json)
var _crown_cache := {}                       ## species * 4 + variant -> _crown_params()


func _init(level_seed := 1776, sun := Vector3.ZERO) -> void:
	seed_value = level_seed
	if sun != Vector3.ZERO:
		sun_dir = sun.normalized()
	for p: Vector3 in PROTECTED:
		_rays.append([p, sun_dir])
	for i in 11:
		_rays.append([Vector3(-5.0 + i, 1.2, MOVER_Z), sun_dir])


## All protected ray origins (spawn, firing line, dummies, the mover's path).
func protected_points() -> Array:
	var out := []
	for r: Array in _rays:
		out.append(r[0])
	return out


# --- Hashing ------------------------------------------------------------------------------------

## Uniform 0..1 from integer cell coordinates, a stream id and the level seed.
func _h(ix: int, iz: int, k: int) -> float:
	var h := (ix * 73856093) ^ (iz * 19349663) ^ (k * 83492791) ^ (seed_value * 2654435761)
	h = (h ^ (h >> 15)) * 2246822519
	h = (h ^ (h >> 13)) * 3266489917
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0


## Per render cell choice (same value for every instance in the cell).
func _hc(cx: int, cz: int, k: int) -> float:
	return _h(cx + 7919, cz - 7907, 5000 + k)


# --- Build ----------------------------------------------------------------------------------------

## Places everything. with_clutter = false (headless / collider-only builds) skips the plants and
## props that have no collider; clutter_density thins them (never the colliders).
func build(with_clutter: bool, clutter_density := 1.0) -> void:
	var t0 := Time.get_ticks_usec()
	_prepare_crowns()
	_trees()
	var t1 := Time.get_ticks_usec()
	_collider_props()
	var t2 := Time.get_ticks_usec()
	if fix_clipping:
		_run_fix("colliders", _fix_colliders)
	var t3 := Time.get_ticks_usec()
	if with_clutter:
		_clutter(clutter_density)
		if fix_clipping:
			_run_fix("clutter:%.2f" % clutter_density, _fix_clutter)
	if fix_clipping:
		_compact()
	var t4 := Time.get_ticks_usec()
	stats["ms_trees"] = (t1 - t0) / 1000.0
	stats["ms_props"] = (t2 - t1) / 1000.0
	stats["ms_fix_colliders"] = (t3 - t2) / 1000.0
	stats["ms_clutter"] = (t4 - t3) / 1000.0
	if fix_clipping:
		stats["clip_fix"] = _fix
	stats["trees"] = tree_pos.size()
	stats["props"] = prop_pos.size()
	stats["plants"] = plant_pos.size()


func _prepare_crowns() -> void:
	for k in Assets.SPECIES.size():
		var per_variant := []
		for v in 3:
			var t := Assets.tree(k, v)
			if t.is_empty():
				t = {"height": 18.0, "crown_radius": 4.0, "crown_bottom": 5.0, "trunk_radius": 0.3, "collider_height": 6.0}
			per_variant.append(t)
		_crowns[k] = per_variant


func _trees() -> void:
	var n := int(ceil(WORLD / TREE_CELL))
	var noise_a := FastNoiseLite.new()
	noise_a.seed = seed_value + 11
	noise_a.frequency = 1.0 / 90.0
	var noise_b := FastNoiseLite.new()
	noise_b.seed = seed_value + 23
	noise_b.frequency = 1.0 / 120.0
	var shortened := 0
	var replaced := 0
	var dropped := 0
	for iz in range(-n, n):
		for ix in range(-n, n):
			var x := (ix + 0.1 + 0.8 * _h(ix, iz, 1)) * TREE_CELL
			var z := (iz + 0.1 + 0.8 * _h(ix, iz, 2)) * TREE_CELL
			if absf(x) > WORLD or absf(z) > WORLD:
				continue
			var far := absf(x) > NEAR or absf(z) > NEAR
			if far and _h(ix, iz, 3) > FAR_KEEP:
				continue
			var d := FrontierTerrain.flat_distance(x, z)
			if d < 3.0:
				continue
			var fd := FrontierTerrain.forest_density(x, z)
			# Noisy edge: the threshold wanders between 0.4 and 0.65.
			if fd < 0.4 + 0.25 * _h(ix, iz, 4):
				continue
			var nrm := FrontierTerrain.normal_at(x, z)
			if nrm.y < MAX_SLOPE_Y:
				continue
			var y := FrontierTerrain.height_at(x, z)
			var edge := maxf(1.0 - smoothstep(0.55, 0.95, fd), 1.0 - smoothstep(12.0, 32.0, d))
			# Species.
			var va := noise_a.get_noise_2d(x, z)          # hardwood vs conifer patches
			var vb := noise_b.get_noise_2d(x, z)          # pine vs hemlock
			var north := maxf(-nrm.z, 0.0)
			var w := [
				0.13 * (1.0 + 1.5 * smoothstep(4.0, 14.0, y)) * (1.0 + 0.9 * vb) * (1.0 - 0.6 * va),
				0.11 * (1.0 + 2.0 * smoothstep(0.0, -4.0, y) + 4.0 * north) * (1.0 - 0.9 * vb) * (1.0 - 0.6 * va),
				0.15 * (1.0 + 1.2 * va),
				0.20 * (1.0 + 1.2 * va),
				0.10 * (1.0 + 3.5 * edge),
			]
			var total := 0.0
			for v: float in w:
				total += maxf(v, 0.0)
			var roll := _h(ix, iz, 5) * total
			var kind := 0
			for k in 5:
				roll -= maxf(w[k], 0.0)
				if roll <= 0.0:
					kind = k
					break
			# One geometric variant per species and 50 m render cell (fewer MultiMeshes; the
			# yaw / scale / tint per tree hide the repeats), plus the low-crowned edge variant of
			# the conifers along the forest edge.
			var cx := floori((x + CELL * 0.5) / CELL)      # vegetation.gd tree_cell()
			var cz := floori((z + CELL * 0.5) / CELL)
			var variant := 0
			if kind == Assets.WHITE_PINE or kind == Assets.HEMLOCK:
				variant = 2 if edge > 0.55 else (0 if _hc(cx, cz, 6 + kind) < 0.5 else 1)
			else:
				variant = int(_hc(cx, cz, 6 + kind) * 2.999)
			var s := lerpf(0.82, 1.18, _h(ix, iz, 7)) * lerpf(1.0, 0.88, edge)
			var yaw := _h(ix, iz, 8) * TAU
			var base := Vector3(x, y, z)
			# Sun corridors: shorten, replace by a sapling, or drop.
			var clear := _crown_clear(kind, variant, base, s)
			if not clear:
				var s2 := s
				while s2 > 0.5 and not clear:
					s2 -= 0.06
					clear = _crown_clear(kind, variant, base, s2)
				if clear:
					s = s2
					shortened += 1
				else:
					var sap: int = [Assets.SAPLING_PINE, Assets.SAPLING_HEMLOCK, Assets.SAPLING_MAPLE,
							Assets.SAPLING_MAPLE, Assets.SAPLING_BIRCH][kind]
					if _crown_clear(sap, 0, base, 1.0):
						_add_plant(base, yaw, lerpf(0.9, 1.25, _h(ix, iz, 9)), sap,
								int(_hc(floori(x / CLUTTER_CELL), floori(z / CLUTTER_CELL), 407 + sap) * 2.999),
								Color(_h(ix, iz, 11), 0.0, 0.5))
						replaced += 1
					else:
						dropped += 1
					continue
			var dry := pow(_h(ix, iz, 12), 3.0) * 0.7 + 0.25 * edge * _h(ix, iz, 13)
			tree_pos.append(base)
			tree_yaw.append(yaw)
			tree_scale.append(s)
			tree_kind.append(kind)
			tree_variant.append(variant)
			tree_custom.append(Color(_h(ix, iz, 14), dry, _h(ix, iz, 15), 0.0))
			tree_collider.append(1)
			_occupy(x, z, 1)
	stats["corridor_shortened"] = shortened
	stats["corridor_replaced"] = replaced
	stats["corridor_dropped"] = dropped


## Crown model of a species variant at scale s: spheres along the axis (conifers taper to the
## top, broadleaf crowns are rounder). Returns [centres, radii].
func crown_spheres(kind: int, variant: int, base: Vector3, s: float) -> Array:
	var t: Dictionary = _crowns[kind][variant]
	var h: float = float(t.height) * s
	var r: float = float(t.crown_radius) * s
	var b: float = maxf(float(t.crown_bottom), 0.0) * s
	var conifer := kind == Assets.WHITE_PINE or kind == Assets.HEMLOCK or kind == Assets.SAPLING_PINE \
			or kind == Assets.SAPLING_HEMLOCK
	var prof := [1.0, 0.85, 0.6, 0.3] if conifer else [0.75, 1.0, 1.0, 0.7]
	var cs := PackedVector3Array()
	var rs := PackedFloat32Array()
	for i in 4:
		var f := (i + 0.5) / 4.0
		cs.append(base + Vector3(0, lerpf(b, h, f), 0))
		rs.append(r * prof[i])
	return [cs, rs]


## True when no protected ray passes through the crown within CORRIDOR_LENGTH (0.6 m margin).
func _crown_clear(kind: int, variant: int, base: Vector3, s: float) -> bool:
	# Broad phase: the rays head south-west from x in [-5, 2.5]; nothing east of them matters.
	var t: Dictionary = _crowns[kind][variant]
	var reach: float = float(t.crown_radius) * s + 1.0
	if base.x > 2.5 + reach:
		return true
	var top: float = base.y + float(t.height) * s
	var dh := Vector2(sun_dir.x, sun_dir.z)
	var dh_len := dh.length()
	var rise := sun_dir.y / dh_len
	var u := dh / dh_len
	var crown: Array = []
	for ray: Array in _rays:
		var o: Vector3 = ray[0]
		var rel := Vector2(base.x - o.x, base.z - o.z)
		var along := rel.dot(u)
		if along < -reach or along > CORRIDOR_LENGTH * dh_len + reach:
			continue
		var across := absf(rel.x * u.y - rel.y * u.x)
		if across > reach:
			continue
		if o.y + maxf(along - reach, 0.0) * rise > top + 0.6:
			continue
		if crown.is_empty():
			crown = crown_spheres(kind, variant, base, s)
		var cs: PackedVector3Array = crown[0]
		var rs: PackedFloat32Array = crown[1]
		for i in cs.size():
			var c := cs[i]
			var tt := clampf((c - o).dot(sun_dir), 0.0, CORRIDOR_LENGTH)
			if c.distance_to(o + sun_dir * tt) < rs[i] + 0.6:
				return false
	return true


# --- Props with colliders -------------------------------------------------------------------------

func _collider_props() -> void:
	# Stumps: the clearing cut for the stockade (1 per ~80 m2 in the blend band), a few in the forest.
	_scatter_grid(9.0, 100, _pick_stump, 0.45, 1.05, 1.2)
	# Logs: fallen trunks in the forest, cut logs at the clearing edge (user 2026-09-28: "more ... downed logs and
	# trees"): about one per 330 m2 of forest (was one per 900).
	_scatter_grid(17.0, 200, _pick_log, 1.0, 2.1, 2.5)
	# Fallen trees: the big old trunks of windthrown trees (8 m and more; the clutter pass stands their root plates up at
	# their butt ends), about one per 2500 m2 of deep forest.
	_scatter_grid(40.0, 250, _pick_fallen, 2.4, 3.0, 3.5)
	# Rocks and boulders: scattered, more on slopes and high ground (the ridge).
	_scatter_grid(22.0, 300, _pick_rock, 0.5, 1.3, 2.0)


func _pick_stump(x: float, z: float, ix: int, iz: int) -> int:
	var d := FrontierTerrain.flat_distance(x, z)
	if d < 1.5:
		return -1
	var fd := FrontierTerrain.forest_density(x, z)
	var p := 0.95 if d < 24.0 and fd < 0.6 else 0.05
	if _h(ix, iz, 101) > p:
		return -1
	return Assets.STUMP_A if _hc(floori(x / CELL), floori(z / CELL), 102) < 0.5 else Assets.STUMP_B


func _pick_log(x: float, z: float, ix: int, iz: int) -> int:
	var d := FrontierTerrain.flat_distance(x, z)
	if d < 2.0:
		return -1
	var fd := FrontierTerrain.forest_density(x, z)
	var p := 0.75 if fd > 0.6 else (0.35 if d < 24.0 else 0.1)
	return Assets.LOG if _h(ix, iz, 201) < p else -1


func _pick_fallen(x: float, z: float, ix: int, iz: int) -> int:
	if FrontierTerrain.flat_distance(x, z) < 12.0 or FrontierTerrain.forest_density(x, z) < 0.65:
		return -1
	return Assets.LOG if _h(ix, iz, 251) < 0.6 else -1


func _pick_rock(x: float, z: float, ix: int, iz: int) -> int:
	var d := FrontierTerrain.flat_distance(x, z)
	if d < 2.0:
		return -1
	var nrm := FrontierTerrain.normal_at(x, z)
	var y := FrontierTerrain.height_at(x, z)
	var p := 0.18 + 0.6 * (1.0 - smoothstep(0.86, 0.96, nrm.y)) + 0.35 * smoothstep(10.0, 20.0, y)
	if _h(ix, iz, 301) > p:
		return -1
	# Two rock shapes per render cell.
	var cx := floori(x / CELL)
	var cz := floori(z / CELL)
	var pick := 303 if _h(ix, iz, 302) < 0.5 else 304
	return Assets.ROCK_FIRST + int(_hc(cx, cz, pick) * (Assets.ROCK_LAST - Assets.ROCK_FIRST + 0.999))


## Jittered-grid scatter of collider props. pick(x, z, ix, iz) returns a prop kind or -1.
func _scatter_grid(cell: float, stream: int, pick: Callable, s_min: float, s_max: float, clearance: float) -> void:
	var n := int(ceil(WORLD / cell))
	for iz in range(-n, n):
		for ix in range(-n, n):
			var x := (ix + 0.15 + 0.7 * _h(ix, iz, stream + 1)) * cell
			var z := (iz + 0.15 + 0.7 * _h(ix, iz, stream + 2)) * cell
			if absf(x) > WORLD or absf(z) > WORLD:
				continue
			var kind: int = pick.call(x, z, ix, iz)
			if kind < 0:
				continue
			if _is_occupied(x, z, clearance):
				continue
			var s := lerpf(s_min, s_max, _h(ix, iz, stream + 3))
			var yaw := _h(ix, iz, stream + 4) * TAU
			var y := FrontierTerrain.height_at(x, z)
			var info := Assets.prop(kind)
			var size: Array = info.get("size", [1.0, 1.0, 1.0])
			var sink := 0.0
			if kind >= Assets.ROCK_FIRST and kind <= Assets.ROCK_LAST:
				sink = float(size[1]) * s * lerpf(0.15, 0.4, _h(ix, iz, stream + 5))
			elif kind == Assets.LOG:
				sink = float(size[1]) * s * 0.25
			else:
				sink = 0.05
			prop_pos.append(Vector3(x, y - sink, z))
			prop_yaw.append(yaw)
			prop_scale.append(s)
			prop_kind.append(kind)
			prop_tilt.append(Vector3((_h(ix, iz, stream + 6) - 0.5) * 0.12, 0, (_h(ix, iz, stream + 7) - 0.5) * 0.12))
			_occupy(x, z, int(ceil(clearance / 3.0)))


func _occupy(x: float, z: float, r: int) -> void:
	var c := Vector2i(floori(x / 3.0), floori(z / 3.0))
	for dz in range(-r + 1, r):
		for dx in range(-r + 1, r):
			_occupied[c + Vector2i(dx, dz)] = true


func _is_occupied(x: float, z: float, clearance: float) -> bool:
	return _occupied.has(Vector2i(floori(x / 3.0), floori(z / 3.0)))


# --- Clutter without colliders (only when meshes are built) ---------------------------------------

func _clutter(density: float) -> void:
	var n := int(ceil(CLUTTER_RADIUS / 6.0))
	# Edge band: shrubs and saplings; birch / pine saplings regrowing in the cut clearing.
	for iz in range(-n, n):
		for ix in range(-n, n):
			var x := (ix + 0.1 + 0.8 * _h(ix, iz, 401)) * 6.0
			var z := (iz + 0.1 + 0.8 * _h(ix, iz, 402)) * 6.0
			var d := FrontierTerrain.flat_distance(x, z)
			if d < 2.5:
				continue
			var fd := FrontierTerrain.forest_density(x, z)
			var edge := maxf(1.0 - smoothstep(0.35, 0.9, fd), 0.0) * (1.0 - smoothstep(24.0, 60.0, d))
			edge = maxf(edge, (1.0 - absf(fd - 0.5) * 2.0))
			# (user 2026-09-28: "more bushes": an understory of hazel and young trees under the canopy too)
			var p := (0.2 + 0.5 * edge) * density
			if fd > 0.8:
				p = 0.4 * density
			if _h(ix, iz, 403) > p:
				continue
			var nrm := FrontierTerrain.normal_at(x, z)
			if nrm.y < 0.8:
				continue
			var y := FrontierTerrain.height_at(x, z)
			var roll := _h(ix, iz, 404)
			var kind: int
			if d < 24.0 and fd < 0.5:
				kind = [Assets.SAPLING_BIRCH, Assets.SAPLING_PINE, Assets.SHRUB_HAZEL, Assets.SAPLING_MAPLE][int(roll * 3.999)]
			else:
				kind = [Assets.SHRUB_HAZEL, Assets.SHRUB_HAZEL, Assets.SAPLING_HEMLOCK, Assets.SAPLING_MAPLE,
						Assets.SAPLING_PINE, Assets.SHRUB_HAZEL][int(roll * 5.999)]
			var base := Vector3(x, y, z)
			var s := lerpf(0.75, 1.25, _h(ix, iz, 405))
			if not _crown_clear(kind, 0, base, s):
				continue
			_add_plant(base, _h(ix, iz, 406) * TAU, s, kind, int(_hc(floori(x / CLUTTER_CELL), floori(z / CLUTTER_CELL), 407 + kind) * 2.999),
					Color(_h(ix, iz, 408), pow(_h(ix, iz, 409), 2.0) * 0.5, _h(ix, iz, 410)))
	# Brush piles and root clusters (no colliders).
	var m := int(ceil(CLUTTER_RADIUS / 30.0))
	for iz in range(-m, m):
		for ix in range(-m, m):
			var x := (ix + 0.2 + 0.6 * _h(ix, iz, 501)) * 30.0
			var z := (iz + 0.2 + 0.6 * _h(ix, iz, 502)) * 30.0
			var d := FrontierTerrain.flat_distance(x, z)
			if d < 3.0:
				continue
			var fd := FrontierTerrain.forest_density(x, z)
			var kind := -1
			if d < 26.0 and _h(ix, iz, 503) < 0.45 * density:
				kind = Assets.BRUSH
			elif fd > 0.6 and _h(ix, iz, 504) < 0.45 * density:
				kind = Assets.ROOTS
			if kind < 0 or _is_occupied(x, z, 2.0):
				continue
			var s := lerpf(0.55, 0.8, _h(ix, iz, 505)) if kind == Assets.ROOTS else lerpf(0.8, 1.2, _h(ix, iz, 505))
			prop_pos.append(Vector3(x, FrontierTerrain.height_at(x, z) - 0.08, z))
			prop_yaw.append(_h(ix, iz, 506) * TAU)
			prop_scale.append(s)
			prop_kind.append(kind)
			prop_tilt.append(Vector3.ZERO)
	# The fallen trees' root plates: stood up at the butt end of each big trunk (the colliders pass laid them).
	for i in prop_pos.size():
		if prop_kind[i] != Assets.LOG or prop_scale[i] < 2.35 or (i < _prop_keep.size() and _prop_keep[i] == 0):
			continue
		var along := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, prop_yaw[i])
		var half := float((Assets.prop(Assets.LOG).get("size", [3.0, 0.3, 0.3]) as Array)[0]) * prop_scale[i] * 0.5
		var end := prop_pos[i] + along * (half + 0.3)
		prop_pos.append(Vector3(end.x, FrontierTerrain.height_at(end.x, end.z) - 0.25, end.z))
		prop_yaw.append(prop_yaw[i] + PI * 0.5)
		prop_scale.append(0.62 + 0.1 * fposmod(prop_yaw[i] * 3.7, 1.0))
		prop_kind.append(Assets.ROOTS)
		prop_tilt.append(Vector3(0.0, 0.0, 0.35))
	# Ferns: patches of 5-25 in the shaded forest near the fort (the fern beds everywhere else, and more of them:
	# the grass's herbs, grass.gdshader pick_herb, drawn on the GPU with no objects).
	var f := int(ceil(CLUTTER_RADIUS / 14.0))
	for iz in range(-f, f):
		for ix in range(-f, f):
			if _h(ix, iz, 601) > 0.4 * density:
				continue
			var cx := (ix + 0.5) * 14.0 + (_h(ix, iz, 602) - 0.5) * 8.0
			var cz := (iz + 0.5) * 14.0 + (_h(ix, iz, 603) - 0.5) * 8.0
			if FrontierTerrain.forest_density(cx, cz) < 0.55 or FrontierTerrain.flat_distance(cx, cz) < 8.0:
				continue
			var count := 5 + int(_h(ix, iz, 604) * 20.0)
			var radius := lerpf(2.5, 6.0, _h(ix, iz, 605))
			for k in count:
				var a := _h(ix, iz, 700 + k) * TAU
				var rr := sqrt(_h(ix, iz, 800 + k)) * radius
				var x := cx + cos(a) * rr
				var z := cz + sin(a) * rr
				if FrontierTerrain.flat_distance(x, z) < 3.0:
					continue
				if FrontierTerrain.normal_at(x, z).y < 0.8:
					continue
				prop_pos.append(Vector3(x, FrontierTerrain.height_at(x, z) - 0.03, z))
				prop_yaw.append(_h(ix, iz, 900 + k) * TAU)
				prop_scale.append(lerpf(0.8, 1.5, _h(ix, iz, 1000 + k)))
				var fc := 1101 if _h(ix, iz, 1100 + k) < 0.5 else 1102
				prop_kind.append(Assets.FERN_FIRST + int(_hc(floori(x / CLUTTER_CELL), floori(z / CLUTTER_CELL), fc) * 3.999))
				prop_tilt.append(Vector3.ZERO)


func _add_plant(base: Vector3, yaw: float, s: float, kind: int, variant: int, custom: Color) -> void:
	plant_pos.append(base)
	plant_yaw.append(yaw)
	plant_scale.append(s)
	plant_kind.append(kind)
	plant_variant.append(variant)
	plant_custom.append(custom)


## True when a prop kind gets a collider.
static func prop_has_collider(kind: int) -> bool:
	return kind <= Assets.LOG


# --- Grounding helpers (shared with tools/environment/check_clipping.gd) --------------------------

## Largest gap (m) allowed between a prop's / trunk's bottom and the terrain under it.
const FLOAT_TOL := 0.06
static var _stem_base := {}


## Height (m) of a prop kind at scale s.
static func prop_height(kind: int, s: float) -> float:
	var size: Array = Assets.prop(kind).get("size", [1.0, 1.0, 1.0])
	return float(size[1]) * s


## Deepest a prop may sit in the ground, as a fraction of its height (rocks: any depth).
static func sink_limit(kind: int) -> float:
	if kind <= Assets.STUMP_B:
		return 0.45
	if kind == Assets.LOG:
		return 0.7
	if kind == Assets.ROOTS or kind == Assets.BRUSH:
		return 0.6
	return 99.0


## (float gap, buried depth) of a hull-shaped prop placed at pos (veg_geom.gd hull_gaps: the
## lowest 20 % of the hull are its bottom points).
static func prop_gaps(kind: int, pos: Vector3, yaw: float, tilt: Vector3, s: float) -> Vector2:
	var hull := prop_hull(kind)
	if hull.is_empty():
		return Vector2(-INF, 0.0)
	return Geom.hull_gaps(hull, Transform3D(prop_basis(yaw, tilt, s), pos), 0.2)


## [radius, bottom y] (mesh space, scale 1) of the part of a tree / sapling / shrub that stands on
## the ground: the lowest LOD0 bark vertex near the axis (within 2 x trees.json trunk_radius; a
## shrub: within its stem spread, 30 % of the crown radius) and the radius of the bark ring
## within 5 cm of that bottom.
static func stem_base(kind: int, variant: int) -> Vector2:
	var pr := _profile(kind, variant)
	if pr.has("base"):
		return pr.base
	return stem_base_from_mesh(kind, variant)


## stem_base() measured on the LOD0 mesh (tools/environment/vegetation/bake_low_foliage.gd bakes
## it into low_foliage.json).
static func stem_base_from_mesh(kind: int, variant: int) -> Vector2:
	var key := kind * 4 + variant
	if _stem_base.has(key):
		return _stem_base[key]
	var t := Assets.tree(kind, variant)
	var reach := float(t.get("crown_radius", 1.4)) * 0.3 if kind == Assets.SHRUB_HAZEL \
			else maxf(float(t.get("trunk_radius", 0.3)) * 2.0, 0.15)
	var bark := PackedVector3Array()
	var m := Assets.tree_mesh(kind, variant, 0)
	if m:
		for sidx in m.get_surface_count():
			var a := m.surface_get_arrays(sidx)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]
			for i in verts.size():
				var p := verts[i]
				if (cols.size() > i and cols[i].a > 0.5) or Vector2(p.x, p.z).length() > reach:
					continue
				bark.append(p)
	var bottom := INF
	for p in bark:
		bottom = minf(bottom, p.y)
	var r := 0.0
	for p in bark:
		if p.y <= bottom + 0.05:
			r = maxf(r, Vector2(p.x, p.z).length())
	_stem_base[key] = Vector2(r, bottom) if bottom != INF else Vector2(0.0, 0.0)
	return _stem_base[key]


## Largest height (m) of a trunk's / stem's bottom over the terrain around it (> 0: it floats
## on that side of a slope).
static func trunk_gap(kind: int, variant: int, pos: Vector3, s: float) -> float:
	var sb := stem_base(kind, variant)
	var r := sb.x * s
	var bottom := pos.y + sb.y * s
	var gap := bottom - FrontierTerrain.height_at(pos.x, pos.z)
	for k in 12:
		var a := k * TAU / 12.0
		gap = maxf(gap, bottom - FrontierTerrain.height_at(pos.x + cos(a) * r, pos.z + sin(a) * r))
	return gap


# --- Footprints and transforms (shared with tools/environment/check_clipping.gd) ------------------

const Geom := preload("res://scripts/world/vegetation/veg_geom.gd")
static var _hulls := {}
static var _low := {}
static var _dims := {}


## Convex hull points of a prop kind (props.json, local space of the mesh, scale 1).
static func prop_hull(kind: int) -> PackedVector3Array:
	if not _hulls.has(kind):
		var pts := PackedVector3Array()
		for h: Array in Assets.prop(kind).get("hull", []):
			pts.append(Vector3(float(h[0]), float(h[1]), float(h[2])))
		_hulls[kind] = pts
	return _hulls[kind]


static func prop_basis(yaw: float, tilt: Vector3, s: float) -> Basis:
	return Basis.from_euler(Vector3(tilt.x, yaw, tilt.z)).scaled(Vector3.ONE * s)


func prop_transform(i: int) -> Transform3D:
	return Transform3D(prop_basis(prop_yaw[i], prop_tilt[i], prop_scale[i]), prop_pos[i])


func tree_transform(i: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, tree_yaw[i]).scaled(Vector3.ONE * tree_scale[i]), tree_pos[i])


func plant_transform(i: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, plant_yaw[i]).scaled(Vector3.ONE * plant_scale[i]), plant_pos[i])


## Footprint of prop i: its hull's oriented box (ferns: a core circle of 30 % of their size, the
## part that reads as "the plant", when fern_core).
func prop_footprint(i: int, fern_core := false) -> PackedFloat32Array:
	return prop_footprint_at(prop_kind[i], prop_pos[i], prop_yaw[i], prop_tilt[i], prop_scale[i], fern_core)


static func prop_footprint_at(kind: int, pos: Vector3, yaw: float, tilt: Vector3, s: float, fern_core := false) -> PackedFloat32Array:
	var info := Assets.prop(kind)
	var size: Array = info.get("size", [1.0, 1.0, 1.0])
	var hull := prop_hull(kind)
	if kind >= Assets.FERN_FIRST or hull.is_empty():
		var r := 0.5 * maxf(float(size[0]), float(size[2])) * s * (0.3 if fern_core else 1.0)
		return Geom.circle(Vector2(pos.x, pos.z), r, pos.y, pos.y + float(size[1]) * s)
	var xf := Transform3D(prop_basis(yaw, tilt, s), pos)
	var pts := PackedVector3Array()
	for p in hull:
		pts.append(xf * p)
	return Geom.from_points(pts, Vector2(cos(yaw), -sin(yaw)))


## Trunk footprint of tree i: the visible trunk at the base (trees.json trunk_radius with 15 %
## root flare), from the ground to the top.
func trunk_footprint(i: int) -> PackedFloat32Array:
	return trunk_footprint_at(tree_kind[i], tree_variant[i], tree_pos[i], tree_scale[i])


static func trunk_footprint_at(kind: int, variant: int, pos: Vector3, s: float) -> PackedFloat32Array:
	var t := _tree_dims(kind, variant)
	var r := maxf(t.x * s * 1.15, 0.12)
	return Geom.circle(Vector2(pos.x, pos.z), r, pos.y - 0.5, pos.y + t.y * s)


## trees.json (trunk_radius, height, crown_radius) of a species variant (cached; the defaults of
## the footprints below when a variant has no entry).
static func _tree_dims(kind: int, variant: int) -> Vector3:
	var key := kind * 4 + variant
	if not _dims.has(key):
		var t := Assets.tree(kind, variant)
		_dims[key] = Vector3(float(t.get("trunk_radius", 0.3)), float(t.get("height", -1.0)), float(t.get("crown_radius", 1.4)))
	var d: Vector3 = _dims[key]
	return Vector3(d.x, d.y if d.y >= 0.0 else (18.0 if kind < Assets.CANOPY_COUNT else 3.0), d.z)


## Stem footprint of sapling / shrub i (a shrub's stems spread over ~30 % of its crown).
func plant_stem_footprint(i: int) -> PackedFloat32Array:
	return plant_stem_footprint_at(plant_kind[i], plant_variant[i], plant_pos[i], plant_scale[i])


static func plant_stem_footprint_at(kind: int, variant: int, pos: Vector3, s: float) -> PackedFloat32Array:
	var t := _tree_dims(kind, variant)
	var r := 0.12
	if kind == Assets.SHRUB_HAZEL:
		r = t.z * s * 0.3
	return Geom.circle(Vector2(pos.x, pos.z), r, pos.y, pos.y + t.y * s)


## True on a trampled dirt path / stream bed outside the flat zones (terrain dirt layer).
func on_path(x: float, z: float) -> bool:
	if FrontierTerrain.in_flat_zone(x, z):
		return false
	return FrontierTerrain.ground_layers(x, z)[FrontierTerrain.LAYER_DIRT] > 0.45


## Foliage (and low branch) vertices of a species variant's LOD0 mesh lower than 3 m, in mesh
## space: what can reach the ground or overhang a flat zone.
static func low_foliage(kind: int, variant: int) -> PackedVector3Array:
	var key := kind * 4 + variant
	if _low.has(key):
		return _low[key]
	var out := PackedVector3Array()
	var m := Assets.tree_mesh(kind, variant, 0)
	var t := Assets.tree(kind, variant)
	var trunk_r := float(t.get("trunk_radius", 0.3)) * 1.6
	if m:
		for sidx in m.get_surface_count():
			var a := m.surface_get_arrays(sidx)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]
			for i in verts.size():
				var p := verts[i]
				if p.y > 3.0:
					continue
				var leaf := cols.size() > i and cols[i].a > 0.5
				if leaf or Vector2(p.x, p.z).length() > trunk_r:
					out.append(p)
	_low[key] = out
	return out


## True when the bare trunk of tree o (below its own crown) passes through the dense core (55 %
## of the radius) of tree i's crown.
func crown_hits_trunk(i: int, o: int) -> bool:
	return crown_hits_trunk_at(tree_kind[i], tree_variant[i], tree_pos[i], tree_scale[i],
			tree_kind[o], tree_variant[o], tree_pos[o], tree_scale[o])


## crown_hits_trunk() for explicit poses: the crown of (ki, vi) at pi / si and the trunk of
## (ko, vo) at po / so.
## Same spheres as crown_spheres() (cached per species variant, no allocations).
func crown_hits_trunk_at(ki: int, vi: int, pi: Vector3, si: float, ko: int, vo: int, po: Vector3, so: float) -> bool:
	var ci := _crown_params(ki, vi)
	var co := _crown_params(ko, vo)
	var tr: float = co[4] * so
	var bare_top: float = po.y + co[3] * so
	var dxz := Vector2(pi.x - po.x, pi.z - po.z).length()
	var h: float = ci[0] * si
	var r: float = ci[1] * si
	var b: float = ci[2] * si
	var prof: Array = ci[5]
	for k in 4:
		var rk: float = r * prof[k]
		if dxz >= rk * 0.55 + tr:
			continue
		var cy := pi.y + lerpf(b, h, (k + 0.5) / 4.0)
		if cy - rk * 0.5 > bare_top or cy + rk * 0.5 < po.y:
			continue
		return true
	return false


## [height, crown radius, crown bottom (>= 0), bare trunk top (crown bottom, >= 1.5), trunk
## radius, sphere radius profile] of a species variant at scale 1 (crown_spheres(),
## crown_hits_trunk()).
func _crown_params(kind: int, variant: int) -> Array:
	var key := kind * 4 + variant
	if not _crown_cache.has(key):
		var t: Dictionary = _crowns[kind][variant]
		var to := Assets.tree(kind, variant)
		var conifer := kind == Assets.WHITE_PINE or kind == Assets.HEMLOCK or kind == Assets.SAPLING_PINE \
				or kind == Assets.SAPLING_HEMLOCK
		_crown_cache[key] = [float(t.height), float(t.crown_radius), maxf(float(t.crown_bottom), 0.0),
				maxf(float(to.get("crown_bottom", 3.0)), 1.5), float(to.get("trunk_radius", 0.3)),
				[1.0, 0.85, 0.6, 0.3] if conifer else [0.75, 1.0, 1.0, 0.7]]
	return _crown_cache[key]


# --- Clipping clean-up (2026-09-25) ----------------------------------------------------------------
# Runs on the finished placement (build()): every tree, prop and plant that clips, in the cases
# tools/environment/check_clipping.gd tests, is fixed on its own with the smallest change that
# works, in this order: re-seated on the ground (lowered, tilted onto the slope, or raised a
# little while its trunk stays in the ground), turned, nudged 0.4-3 m (trees stay in their 50 m
# render cell), and only when nothing fits, removed. Everything else keeps its exact place, so the
# forest's style and density stay as they were. The collider pass (trees, stumps, logs, rocks)
# sees only trees and collider props, so headless and windowed builds and every preset get the
# same colliders; the clutter pass (saplings, shrubs, roots, brush, ferns) runs after the
# clutter is placed. fix_clipping = false skips both (the layout before 2026-09-25).

const LOW_FOLIAGE_PATH := "res://assets/environment/vegetation/trees/low_foliage.json"
## What needs a fix: the check's limits (foliage 0.12 m under the ground, FLOAT_TOL, the sink
## limits, footprints touching); the baked foliage profile is binned, so 1 cm less.
const NEEDS_FOLIAGE := 0.11
## A fixed pose must clear these, a margin inside the check's.
const FIX_FOLIAGE := 0.07
const FIX_FLOAT := 0.035
const FIX_SINK := 0.85
## A trunk / stem keeps at least this much of its bottom in the ground when raised (m).
const FIX_ROOTED := 0.08
const NUDGE_STEPS := [0.4, 0.8, 1.2, 1.6, 2.0, 2.5, 3.0]
const NUDGE_DIRS := 12
const OCC_TRUNK := 0
const OCC_SOLID := 1
const OCC_PILE := 2
const OCC_STEM := 3
const OCC_FERN := 4
const OCC_DEAD := -1

static var _prof := {}            ## "<species>_v<k>" -> {floor, base, bound} (low_foliage.json)
static var _prof_k := {}          ## species * 4 + variant -> the same entry
var _occ: Geom.Grid               ## footprints of everything placed (spacing for the fixes)
var _occ_ref: Array = []          ## grid id -> [kind of object ("t", "p", "l"), index]
var _tree_gid := PackedInt32Array()
var _prop_gid := PackedInt32Array()
var _plant_gid := PackedInt32Array()
var _tree_keep := PackedByteArray()
var _prop_keep := PackedByteArray()
var _plant_keep := PackedByteArray()
var _max_reach := 0.0
var _fix := {}
## Every change of the clean-up pass: [what, kind name, old position, new position or null].
var fix_log: Array = []


## Baked ground profile of a tree / plant variant: floor points (x, lowest max(y, 0), z; mesh
## space), the stem base [r, y] and bound (lowest floor, reach). Empty when not baked.
static func _profile(kind: int, variant: int) -> Dictionary:
	var key := kind * 4 + variant
	if _prof_k.has(key):
		return _prof_k[key]
	if _prof.is_empty():
		_prof["_loaded"] = {}
		var f := FileAccess.open(LOW_FOLIAGE_PATH, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary:
			for name: String in d:
				var e: Dictionary = d[name]
				if not e.has("floor"):
					continue
				var pts := PackedVector3Array()
				var lo := INF
				var reach := 0.0
				for q: Array in e["floor"]:
					var p := Vector3(float(q[0]), float(q[1]), float(q[2]))
					pts.append(p)
					lo = minf(lo, p.y)
					reach = maxf(reach, Vector2(p.x, p.z).length())
				var b: Array = e.get("base", [0.0, 0.0])
				# Per 8 sectors (45 deg): the lowest floor and the farthest reach, for a cheap bound.
				var sect := PackedVector3Array()
				for k in 8:
					sect.append(Vector3(INF, 0.0, 0.0))
				for p in pts:
					var k := int(fposmod(atan2(p.z, p.x) / TAU, 1.0) * 8.0) % 8
					sect[k] = Vector3(minf(sect[k].x, p.y), maxf(sect[k].y, Vector2(p.x, p.z).length()), 0.0)
				_prof[name] = {"floor": pts, "base": Vector2(float(b[0]), float(b[1])), "bound": Vector2(lo, reach),
						"sectors": sect}
	_prof_k[key] = _prof.get("%s_v%d" % [Assets.SPECIES[kind], variant], {})
	return _prof_k[key]


## How far (m) the low foliage of a tree / plant at pos reaches into the ground, beyond what its
## model puts below its own base (-INF when it clears the ground). Baked floor points.
static func foliage_extra(kind: int, variant: int, pos: Vector3, yaw: float, s: float) -> float:
	var pr := _profile(kind, variant)
	if pr.is_empty() or (pr.floor as PackedVector3Array).is_empty():
		return -INF
	var bound: Vector2 = pr.bound
	# Quick reject: twice the local slope plus 0.5 m of relief cannot reach the lowest foliage.
	var n := FrontierTerrain.normal_at(pos.x, pos.z)
	var tan_slope := sqrt(maxf(1.0 - n.y * n.y, 0.0)) / maxf(n.y, 0.2)
	if (bound.x - bound.y * tan_slope * 2.0) * s - 0.5 > FIX_FOLIAGE:
		return -INF
	# Cheap bound per 45 deg sector: the ground at the sector's reach (its two edges and middle)
	# against the sector's lowest foliage.
	var rot := Basis(Vector3.UP, yaw)
	var sect: PackedVector3Array = pr.sectors
	var near := false
	for k in 8:
		var sk := sect[k]
		if sk.x == INF:
			continue
		for j in 3:
			var a := (k + 0.5 * j) * TAU / 8.0
			var q := pos + rot * Vector3(cos(a), 0.0, sin(a)) * sk.y * s
			if FrontierTerrain.height_at(q.x, q.z) - pos.y - sk.x * s > FIX_FOLIAGE - 0.35:
				near = true
				break
		if near:
			break
	if not near:
		return -INF
	var worst := -INF
	for p: Vector3 in pr.floor:
		var q := pos + rot * Vector3(p.x, 0.0, p.z) * s
		worst = maxf(worst, FrontierTerrain.height_at(q.x, q.z) - pos.y - p.y * s)
	return worst


## True when some low foliage (below 3 m) of a tree / plant at pos hangs over a flat zone.
static func foliage_over_flat(kind: int, variant: int, pos: Vector3, yaw: float, s: float) -> bool:
	if FrontierTerrain.flat_distance(pos.x, pos.z) > 8.0 * s:
		return false
	var pr := _profile(kind, variant)
	var rot := Basis(Vector3.UP, yaw)
	for p: Vector3 in pr.get("floor", PackedVector3Array()):
		var q := pos + rot * Vector3(p.x, 0.0, p.z) * s
		if FrontierTerrain.in_flat_zone(q.x, q.z):
			return true
	return false


func _occ_add(f: PackedFloat32Array, tag: int, what: String, i: int) -> int:
	_occ_ref.append([what, i])
	return _occ.add(f, tag)


func _occ_kill(gid: int) -> void:
	if gid < 0:
		return
	_occ.items[gid] = Geom.circle(Vector2(1e9, 1e9), 0.0, INF, -INF)
	_occ.tags[gid] = OCC_DEAD


## True when footprint f overlaps (grown by margin) a stored footprint whose tag is in `tags`
## (bit mask), other than `self_gid`.
func _occ_hits(f: PackedFloat32Array, margin: float, tags: int, self_gid: int) -> bool:
	for gid in _occ.candidates(f, margin):
		if gid == self_gid or _occ.tags[gid] < 0 or (tags & (1 << _occ.tags[gid])) == 0:
			continue
		if Geom.overlaps(_occ.items[gid], f, margin):
			return true
	return false


func _count(key: String) -> void:
	_fix[key] = int(_fix.get(key, 0)) + 1


## Deterministic start angle for the nudge search around (x, z).
func _nudge_start(x: float, z: float) -> float:
	return _h(roundi(x * 10.0), roundi(z * 10.0), 9001) * TAU


## Mean terrain normal over a disc of radius r (the plane a prop settles on).
static func _avg_normal(x: float, z: float, r: float) -> Vector3:
	var nrm := FrontierTerrain.normal_at(x, z)
	for k in 8:
		var a := k * TAU / 8.0
		nrm += FrontierTerrain.normal_at(x + cos(a) * r, z + sin(a) * r)
	return nrm.normalized()


# Trees and collider props ---------------------------------------------------------------------

func _fix_colliders() -> void:
	_build_occ(prop_pos.size())
	_fix_trees()
	for i in prop_pos.size():
		_fix_prop(i, OCC_SOLID)


## The spacing grid of the trees and the first n_props (collider) props (removed ones left out).
func _build_occ(n_props: int) -> void:
	_occ = Geom.Grid.new(4.0)
	_occ_ref = []
	_tree_keep = _keep_sized(_tree_keep, tree_pos.size())
	_prop_keep = _keep_sized(_prop_keep, n_props)
	_tree_gid.resize(tree_pos.size())
	for i in tree_pos.size():
		_tree_gid[i] = _occ_add(trunk_footprint(i), OCC_TRUNK, "t", i)
		if _tree_keep[i] == 0:
			_occ_kill(_tree_gid[i])
	_prop_gid.resize(n_props)
	for i in n_props:
		_prop_gid[i] = _occ_add(prop_footprint(i), OCC_SOLID, "p", i)
		if _prop_keep[i] == 0:
			_occ_kill(_prop_gid[i])
	# Farthest a crown core can reach a trunk (crown_hits_trunk_at: 55 % of the widest sphere plus
	# the trunk radius), at the largest scale.
	for k in Assets.CANOPY_COUNT:
		for v in 3:
			var c := _crown_params(k, v)
			_max_reach = maxf(_max_reach, (c[1] * 0.55 + c[4]) * 1.25)


## Trees whose crown core takes in a neighbour's bare trunk (the smaller of the pair moves),
## whose low foliage runs into a slope, or that stand on a path.
func _fix_trees() -> void:
	var movers := {}
	for i in tree_pos.size():
		var probe := Geom.circle(Vector2(tree_pos[i].x, tree_pos[i].z), _max_reach, -INF, INF)
		for gid in _occ.candidates(probe, 0.0):
			if _occ.tags[gid] != OCC_TRUNK:
				continue
			var o: int = _occ_ref[gid][1]
			if o <= i:
				continue
			if crown_hits_trunk(i, o) or crown_hits_trunk(o, i):
				var hi := float(_crowns[tree_kind[i]][tree_variant[i]].height) * tree_scale[i]
				var ho := float(_crowns[tree_kind[o]][tree_variant[o]].height) * tree_scale[o]
				movers[o if ho <= hi else i] = true
	# Movers first (crown pairs, paths), then the trees whose low foliage runs into a slope.
	for pass_movers in [true, false]:
		for i in tree_pos.size():
			if _tree_keep[i] == 1:
				_fix_tree(i, movers.has(i), pass_movers)


func _fix_tree(i: int, crown: bool, pass_movers: bool) -> void:
	var p := tree_pos[i]
	var path := on_path(p.x, p.z)
	if pass_movers != (crown or path):
		return
	if crown and not path and _tree_ok(i, p, tree_yaw[i]):
		return              # an earlier move already separated the pair
	var foliage := foliage_extra(tree_kind[i], tree_variant[i], p, tree_yaw[i], tree_scale[i]) > NEEDS_FOLIAGE
	if not (crown or foliage or path):
		return
	var pose := _tree_pose(i, not (crown or path))
	if pose.is_empty():
		_tree_keep[i] = 0
		_occ_kill(_tree_gid[i])
		_count("trees_removed")
		fix_log.append(["tree_removed", "%s_v%d" % [Assets.SPECIES[tree_kind[i]], tree_variant[i]], p, null])
		return
	_count("trees_moved" if (pose[0] as Vector3).distance_to(Vector3(p.x, pose[0].y, p.z)) > 0.01 else
			("trees_raised" if pose[0].y > p.y + 0.001 else "trees_turned"))
	fix_log.append(["tree", "%s_v%d" % [Assets.SPECIES[tree_kind[i]], tree_variant[i]], p, pose[0]])
	tree_pos[i] = pose[0]
	tree_yaw[i] = pose[1]
	_occ_kill(_tree_gid[i])
	_tree_gid[i] = _occ_add(trunk_footprint(i), OCC_TRUNK, "t", i)


## The first pose [position, yaw] of tree i that fits: in place (raised, then turned) when
## in_place is allowed, then nudged. [] when none does.
func _tree_pose(i: int, in_place: bool) -> Array:
	var pose := _tree_pose_variant(i, in_place)
	if not pose.is_empty() or not (tree_kind[i] == Assets.HEMLOCK and tree_variant[i] == 2):
		return pose
	# The edge hemlock (variant 2) models its skirt boughs down to 1.8 m below its base: where no
	# nearby spot is level enough for them, the cell's regular hemlock stands in (same species,
	# same place) rather than dropping the tree.
	var p := tree_pos[i]
	var v := 0 if _hc(floori((p.x + CELL * 0.5) / CELL), floori((p.z + CELL * 0.5) / CELL), 6 + Assets.HEMLOCK) < 0.5 else 1
	tree_variant[i] = v
	pose = _tree_pose_variant(i, true)
	if pose.is_empty():
		tree_variant[i] = 2
	else:
		_count("trees_edge_variant_swapped")
	return pose


func _tree_pose_variant(i: int, in_place: bool) -> Array:
	var p := tree_pos[i]
	var yaw := tree_yaw[i]
	if in_place:
		var raises := []
		for k in 8:
			raises.append(_tree_raise(i, p, yaw + k * TAU / 8.0))
		for pass_k in 2:
			for k in 8:
				var r: float = raises[k]
				if r < 0.0 or (pass_k == 0 and k > 0 and r > 0.0) or (pass_k == 1 and (k == 0 or r == 0.0)):
					continue
				var y2 := yaw + k * TAU / 8.0
				if _tree_ok(i, p + Vector3(0, r, 0), y2, false):
					return [p + Vector3(0, r, 0), y2]
	var cell := _tree_cell(p)
	var fd0 := minf(FrontierTerrain.flat_distance(p.x, p.z), 12.0) - 0.01
	var a0 := _nudge_start(p.x, p.z)
	for d: float in NUDGE_STEPS + [4.0, 5.0]:
		for k in NUDGE_DIRS:
			var a := a0 + k * TAU / NUDGE_DIRS
			var x := p.x + cos(a) * d
			var z := p.z + sin(a) * d
			if _tree_cell(Vector3(x, 0, z)) != cell:
				continue
			# Off steep ground, never closer to the fort clearing / range lane than before.
			if FrontierTerrain.normal_at(x, z).y < MAX_SLOPE_Y or FrontierTerrain.flat_distance(x, z) < maxf(3.0, fd0):
				continue
			var q := Vector3(x, FrontierTerrain.height_at(x, z), z)
			if not _tree_clear(i, q):
				continue
			var r := _tree_raise(i, q, yaw)
			if r >= 0.0 and _tree_ok(i, q + Vector3(0, r, 0), yaw, false):
				return [q + Vector3(0, r, 0), yaw]
	return []


## Render cell (vegetation.gd tree_cell(): 50 m, centred on the fort).
static func _tree_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x + CELL * 0.5) / CELL), floori((p.z + CELL * 0.5) / CELL))


## The raise (m) that lifts tree i's low foliage out of the slope at pos / yaw (0 when it clears
## it), or -1 when that would lift its trunk out of the ground.
func _tree_raise(i: int, pos: Vector3, yaw: float) -> float:
	var e := foliage_extra(tree_kind[i], tree_variant[i], pos, yaw, tree_scale[i])
	if e <= FIX_FOLIAGE:
		return 0.0
	var r := e - FIX_FOLIAGE + 0.01
	if trunk_gap(tree_kind[i], tree_variant[i], pos + Vector3(0, r, 0), tree_scale[i]) > -FIX_ROOTED:
		return -1.0
	return r


## True when tree i fits at pos / yaw: clear of other trunks and props, no crown core through a
## neighbour's trunk either way, foliage out of the ground and the flat zones, not on a path, its
## trunk in the ground, and no protected sun ray through its crown.
func _tree_ok(i: int, pos: Vector3, yaw: float, foliage := true) -> bool:
	var k := tree_kind[i]
	var v := tree_variant[i]
	var s := tree_scale[i]
	if not _tree_clear(i, pos):
		return false
	if (foliage and foliage_extra(k, v, pos, yaw, s) > FIX_FOLIAGE) or foliage_over_flat(k, v, pos, yaw, s):
		return false
	if trunk_gap(k, v, pos, s) > -FIX_ROOTED:
		return false
	return _crown_clear(k, v, pos, s)


## The yaw-independent part of _tree_ok(): off paths, clear of trunks and props, no crown core
## through a neighbour's trunk either way.
func _tree_clear(i: int, pos: Vector3) -> bool:
	var k := tree_kind[i]
	var v := tree_variant[i]
	var s := tree_scale[i]
	if on_path(pos.x, pos.z):
		return false
	if _occ_hits(trunk_footprint_at(k, v, pos, s), 0.3, 1 << OCC_TRUNK, _tree_gid[i]):
		return false
	if _occ_hits(trunk_footprint_at(k, v, pos, s), 0.05, 1 << OCC_SOLID, _tree_gid[i]):
		return false
	var probe := Geom.circle(Vector2(pos.x, pos.z), _max_reach, -INF, INF)
	for gid in _occ.candidates(probe, 0.0):
		if gid == _tree_gid[i] or _occ.tags[gid] != OCC_TRUNK:
			continue
		var o: int = _occ_ref[gid][1]
		if crown_hits_trunk_at(k, v, pos, s, tree_kind[o], tree_variant[o], tree_pos[o], tree_scale[o]) \
				or crown_hits_trunk_at(tree_kind[o], tree_variant[o], tree_pos[o], tree_scale[o], k, v, pos, s):
			return false
	return true


## Props: re-seats (lowers, then tilts onto the slope), turns, nudges or removes prop i when it
## floats, is buried too deep, runs through a trunk or another solid, or lies on a path.
func _fix_prop(i: int, tag: int) -> void:
	var k := prop_kind[i]
	var p := prop_pos[i]
	if not _prop_needs_fix(i, tag):
		return
	var pose := _prop_pose(i, tag)
	if pose.is_empty():
		_prop_keep[i] = 0
		_occ_kill(_prop_gid[i])
		_count("%s_removed" % Assets.PROPS[k].name)
		fix_log.append(["prop_removed", Assets.PROPS[k].name, p, null])
		return
	var moved := Vector2(pose[0].x - p.x, pose[0].z - p.z).length() > 0.01
	_count("%s_%s" % [Assets.PROPS[k].name, "moved" if moved else "reseated"])
	fix_log.append(["prop", Assets.PROPS[k].name, p, pose[0]])
	prop_pos[i] = pose[0]
	prop_yaw[i] = pose[1]
	prop_tilt[i] = pose[2]
	_occ_kill(_prop_gid[i])
	_prop_gid[i] = _occ_add(prop_footprint(i), tag, "p", i)


func _prop_pose(i: int, tag: int) -> Array:
	var k := prop_kind[i]
	var p := prop_pos[i]
	var yaw := prop_yaw[i]
	var tilt := prop_tilt[i]
	# 1. Lowered in place until no bottom point hangs over the ground.
	var hull := prop_hull(k)
	var s := prop_scale[i]
	var g := Geom.ground_hull(hull, prop_basis(yaw, tilt, s), Vector2(p.x, p.z), 0.2)
	var low := Vector3(p.x, minf(p.y, g[0] - 0.005), p.z)
	if _prop_ok(i, low, yaw, tilt, tag):
		return [low, yaw, tilt]
	# 2. Tilted onto the slope and seated, 3. turned, 4. nudged.
	var yaws := [0.0, PI / 8.0, -PI / 8.0, PI / 4.0, -PI / 4.0, 3.0 * PI / 8.0, -3.0 * PI / 8.0, PI / 2.0]
	for dy: float in yaws:
		var pose := _seat(i, p.x, p.z, yaw + dy)
		if _prop_ok(i, pose[0], pose[1], pose[2], tag):
			return pose
	var a0 := _nudge_start(p.x, p.z)
	for d: float in NUDGE_STEPS + [3.5, 4.0, 5.0]:
		for n in NUDGE_DIRS:
			var a := a0 + n * TAU / NUDGE_DIRS
			var x := p.x + cos(a) * d
			var z := p.z + sin(a) * d
			if FrontierTerrain.flat_distance(x, z) < _prop_flat_min(k):
				continue
			for dy: float in [0.0, PI / 2.0]:
				var pose := _seat(i, x, z, yaw + dy)
				if _prop_ok(i, pose[0], pose[1], pose[2], tag):
					return pose
	return []


## [position, yaw, tilt] of prop i seated at (x, z): tilted onto the mean slope (stumps at most
## 0.3 rad, they stood upright) plus its own small random tilt, lowered until no bottom point
## floats, then settled in (rocks by their own share of their height, logs 12 %, the rest 4 cm).
func _seat(i: int, x: float, z: float, yaw: float) -> Array:
	var k := prop_kind[i]
	var s := prop_scale[i]
	var size: Array = Assets.prop(k).get("size", [1.0, 1.0, 1.0])
	var nrm := _avg_normal(x, z, 0.45 * maxf(float(size[0]), float(size[2])) * s)
	var t2 := Geom.tilt_for_normal(nrm, yaw)
	if k <= Assets.STUMP_B and t2.length() > 0.3:
		t2 = t2.normalized() * 0.3
	var tilt := Vector3(t2.x + prop_tilt[i].x * 0.5, 0.0, t2.y + prop_tilt[i].z * 0.5)
	var g := Geom.ground_hull(prop_hull(k), prop_basis(yaw, tilt, s), Vector2(x, z), 0.2)
	var h := float(size[1]) * s
	var settle := 0.04
	if k >= Assets.ROCK_FIRST and k <= Assets.ROCK_LAST:
		settle = h * lerpf(0.15, 0.4, _h(roundi(x * 10.0), roundi(z * 10.0), 9002))
	elif k == Assets.LOG:
		settle = h * 0.12
	return [Vector3(x, g[0] - settle, z), yaw, tilt]


## The check's criteria (tools/environment/check_clipping.gd): floating, sunk, through a trunk or a
## solid (roots / brush may touch each other), on a path.
func _prop_needs_fix(i: int, tag: int) -> bool:
	var k := prop_kind[i]
	var s := prop_scale[i]
	var g := prop_gaps(k, prop_pos[i], prop_yaw[i], prop_tilt[i], s)
	if g.x > FLOAT_TOL or g.y > sink_limit(k) * prop_height(k, s):
		return true
	var f := prop_footprint(i)
	if on_path(f[1], f[2]):
		return true
	var mask := (1 << OCC_TRUNK) | (1 << OCC_SOLID) | ((1 << OCC_PILE) if tag == OCC_SOLID else 0)
	return _occ_hits(f, 0.0, mask, _prop_gid[i])


## Nearest a prop's centre may come to the flat zones (the placement rules).
static func _prop_flat_min(kind: int) -> float:
	if kind <= Assets.STUMP_B:
		return 1.5
	if kind == Assets.ROOTS or kind == Assets.BRUSH:
		return 3.0
	return 2.0


## True when prop i fits at this pose: grounded (no gap, not too deep), clear of trunks and
## solids (roots / brush may overlap each other), not on a path, off the flat zones.
func _prop_ok(i: int, pos: Vector3, yaw: float, tilt: Vector3, tag: int) -> bool:
	var k := prop_kind[i]
	var s := prop_scale[i]
	var g := prop_gaps(k, pos, yaw, tilt, s)
	if g.x > FIX_FLOAT or g.y > FIX_SINK * sink_limit(k) * prop_height(k, s):
		return false
	var f := prop_footprint_at(k, pos, yaw, tilt, s)
	if on_path(f[1], f[2]):
		return false
	var mask := (1 << OCC_TRUNK) | (1 << OCC_SOLID) | ((1 << OCC_PILE) if tag == OCC_SOLID else 0)
	if _occ_hits(f, 0.05, mask, _prop_gid[i]):
		return false
	if FrontierTerrain.flat_distance(f[1], f[2]) < Geom.radius(f) + 1.5:
		for q in Geom.samples(f, 0.5):
			if FrontierTerrain.flat_distance(q.x, q.y) < 1.0:
				return false
	return true


# Clutter: roots, brush, saplings, shrubs, ferns ---------------------------------------------------

## keep grown to n entries (new ones kept), existing flags unchanged.
static func _keep_sized(keep: PackedByteArray, n: int) -> PackedByteArray:
	var old := keep.size()
	if old < n:
		keep.resize(n)
		for i in range(old, n):
			keep[i] = 1
	return keep


func _fix_clutter() -> void:
	var n0 := _prop_keep.size()      # the collider props (both passes size it to them)
	if _occ == null:
		_build_occ(n0)               # the collider pass came from the cache
	_prop_gid.resize(prop_pos.size())
	_prop_keep.resize(prop_pos.size())
	for i in range(n0, prop_pos.size()):
		_prop_keep[i] = 1
		var k := prop_kind[i]
		var fern := k >= Assets.FERN_FIRST
		_prop_gid[i] = _occ_add(prop_footprint(i, fern), OCC_FERN if fern else OCC_PILE, "p", i)
	_plant_gid.resize(plant_pos.size())
	_plant_keep.resize(plant_pos.size())
	_plant_keep.fill(1)
	for i in plant_pos.size():
		_plant_gid[i] = _occ_add(plant_stem_footprint(i), OCC_STEM, "l", i)
	for i in range(n0, prop_pos.size()):
		if prop_kind[i] < Assets.FERN_FIRST:
			_fix_prop(i, OCC_PILE)
	for i in plant_pos.size():
		_fix_plant(i)
	for i in range(n0, prop_pos.size()):
		if prop_kind[i] >= Assets.FERN_FIRST:
			_fix_fern(i)


func _fix_plant(i: int) -> void:
	var p := plant_pos[i]
	if not _plant_needs_fix(i):
		return
	var pose := _plant_pose(i)
	if pose.is_empty():
		_plant_keep[i] = 0
		_occ_kill(_plant_gid[i])
		_count("plants_removed")
		fix_log.append(["plant_removed", "%s_v%d" % [Assets.SPECIES[plant_kind[i]], plant_variant[i]], p, null])
		return
	var moved := Vector2(pose[0].x - p.x, pose[0].z - p.z).length() > 0.01
	_count("plants_moved" if moved else ("plants_raised" if pose[0].y > p.y + 0.001 else "plants_turned"))
	fix_log.append(["plant", "%s_v%d" % [Assets.SPECIES[plant_kind[i]], plant_variant[i]], p, pose[0]])
	plant_pos[i] = pose[0]
	plant_yaw[i] = pose[1]
	_occ_kill(_plant_gid[i])
	_plant_gid[i] = _occ_add(plant_stem_footprint(i), OCC_STEM, "l", i)


## The check's criteria: stems in a trunk, solid, pile or another stem, on a path, foliage in
## the ground, stem base over the ground.
func _plant_needs_fix(i: int) -> bool:
	var k := plant_kind[i]
	var v := plant_variant[i]
	var p := plant_pos[i]
	var s := plant_scale[i]
	if on_path(p.x, p.z):
		return true
	var mask := (1 << OCC_TRUNK) | (1 << OCC_SOLID) | (1 << OCC_PILE) | (1 << OCC_STEM)
	if _occ_hits(plant_stem_footprint(i), 0.0, mask, _plant_gid[i]):
		return true
	return foliage_extra(k, v, p, plant_yaw[i], s) > NEEDS_FOLIAGE or trunk_gap(k, v, p, s) > FLOAT_TOL


func _plant_pose(i: int) -> Array:
	var p := plant_pos[i]
	var yaw := plant_yaw[i]
	for k in 8:
		var y2 := yaw + k * TAU / 8.0
		var r := _plant_raise(i, p, y2)
		if r >= 0.0 and _plant_ok(i, p + Vector3(0, r, 0), y2):
			return [p + Vector3(0, r, 0), y2]
	var a0 := _nudge_start(p.x, p.z)
	for d: float in NUDGE_STEPS:
		for n in NUDGE_DIRS:
			var a := a0 + n * TAU / NUDGE_DIRS
			var x := p.x + cos(a) * d
			var z := p.z + sin(a) * d
			if FrontierTerrain.normal_at(x, z).y < 0.8 or FrontierTerrain.flat_distance(x, z) < 2.5:
				continue
			var q := Vector3(x, FrontierTerrain.height_at(x, z), z)
			var r := _plant_raise(i, q, yaw)
			if r >= 0.0 and _plant_ok(i, q + Vector3(0, r, 0), yaw):
				return [q + Vector3(0, r, 0), yaw]
	return []


func _plant_raise(i: int, pos: Vector3, yaw: float) -> float:
	var e := foliage_extra(plant_kind[i], plant_variant[i], pos, yaw, plant_scale[i])
	if e <= FIX_FOLIAGE:
		return 0.0
	var r := e - FIX_FOLIAGE + 0.01
	if trunk_gap(plant_kind[i], plant_variant[i], pos + Vector3(0, r, 0), plant_scale[i]) > -0.02:
		return -1.0
	return r


## True when sapling / shrub i fits: stems clear of trunks, solids, piles and other stems, not on
## a path, foliage out of the ground and the flat zones, its stem base in the ground, and no
## protected sun ray through its crown.
func _plant_ok(i: int, pos: Vector3, yaw: float) -> bool:
	var k := plant_kind[i]
	var v := plant_variant[i]
	var s := plant_scale[i]
	if on_path(pos.x, pos.z):
		return false
	var f := plant_stem_footprint_at(k, v, pos, s)
	if _occ_hits(f, 0.02, (1 << OCC_TRUNK) | (1 << OCC_SOLID) | (1 << OCC_PILE) | (1 << OCC_STEM), _plant_gid[i]):
		return false
	for q in Geom.samples(f, 0.5):
		if FrontierTerrain.in_flat_zone(q.x, q.y):
			return false
	if foliage_extra(k, v, pos, yaw, s) > FIX_FOLIAGE or foliage_over_flat(k, v, pos, yaw, s):
		return false
	if trunk_gap(k, v, pos, s) > FIX_FLOAT:
		return false
	return _crown_clear(k, 0, pos, s) and _crown_clear(k, v, pos, s)


## Ferns: the core (30 % of the fern) clear of trunks, solids and piles; else nudged, else removed.
func _fix_fern(i: int) -> void:
	var k := prop_kind[i]
	var p := prop_pos[i]
	var mask := (1 << OCC_TRUNK) | (1 << OCC_SOLID) | (1 << OCC_PILE)
	if not _occ_hits(prop_footprint(i, true), 0.0, mask, _prop_gid[i]):
		return
	var a0 := _nudge_start(p.x, p.z)
	for d: float in [0.3, 0.6, 0.9, 1.2, 1.6, 2.0]:
		for n in 8:
			var a := a0 + n * TAU / 8.0
			var x := p.x + cos(a) * d
			var z := p.z + sin(a) * d
			if FrontierTerrain.flat_distance(x, z) < 3.0 or FrontierTerrain.normal_at(x, z).y < 0.8:
				continue
			var q := Vector3(x, FrontierTerrain.height_at(x, z) - 0.03, z)
			if _occ_hits(prop_footprint_at(k, q, prop_yaw[i], prop_tilt[i], prop_scale[i], true), 0.02, mask, _prop_gid[i]):
				continue
			fix_log.append(["fern", Assets.PROPS[k].name, p, q])
			prop_pos[i] = q
			_occ_kill(_prop_gid[i])
			_prop_gid[i] = _occ_add(prop_footprint(i, true), OCC_FERN, "p", i)
			_count("ferns_moved")
			return
	_prop_keep[i] = 0
	_occ_kill(_prop_gid[i])
	_count("ferns_removed")
	fix_log.append(["fern_removed", Assets.PROPS[k].name, p, null])


## Drops the removed trees, props and plants from the packed arrays.
func _compact() -> void:
	if _tree_keep.size() == tree_pos.size() and _tree_keep.count(0) > 0:
		var keep := _tree_keep
		tree_pos = _pick_v3(tree_pos, keep)
		tree_yaw = _pick_f(tree_yaw, keep)
		tree_scale = _pick_f(tree_scale, keep)
		tree_kind = _pick_i(tree_kind, keep)
		tree_variant = _pick_i(tree_variant, keep)
		tree_custom = _pick_c(tree_custom, keep)
		var tc := PackedByteArray()
		for j in keep.size():
			if keep[j] == 1:
				tc.append(tree_collider[j])
		tree_collider = tc
	if _prop_keep.size() == prop_pos.size() and _prop_keep.count(0) > 0:
		var keep := _prop_keep
		prop_pos = _pick_v3(prop_pos, keep)
		prop_yaw = _pick_f(prop_yaw, keep)
		prop_scale = _pick_f(prop_scale, keep)
		prop_kind = _pick_i(prop_kind, keep)
		prop_tilt = _pick_v3(prop_tilt, keep)
	if _plant_keep.size() == plant_pos.size() and _plant_keep.count(0) > 0:
		var keep := _plant_keep
		plant_pos = _pick_v3(plant_pos, keep)
		plant_yaw = _pick_f(plant_yaw, keep)
		plant_scale = _pick_f(plant_scale, keep)
		plant_kind = _pick_i(plant_kind, keep)
		plant_variant = _pick_i(plant_variant, keep)
		plant_custom = _pick_c(plant_custom, keep)
	_occ = null
	_occ_ref = []


static func _pick_v3(a: PackedVector3Array, keep: PackedByteArray) -> PackedVector3Array:
	var out := PackedVector3Array()
	for j in a.size():
		if keep[j] == 1:
			out.append(a[j])
	return out


static func _pick_f(a: PackedFloat32Array, keep: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for j in a.size():
		if keep[j] == 1:
			out.append(a[j])
	return out


static func _pick_i(a: PackedInt32Array, keep: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for j in a.size():
		if keep[j] == 1:
			out.append(a[j])
	return out


static func _pick_c(a: PackedColorArray, keep: PackedByteArray) -> PackedColorArray:
	var out := PackedColorArray()
	for j in a.size():
		if keep[j] == 1:
			out.append(a[j])
	return out


# Baked results of the clean-up pass ---------------------------------------------------------------
# The pass costs ~0.5 s per level load; applying its baked changes costs a few ms. Each part
# (colliders; clutter per clutter_density) is keyed by an MD5 of everything the pass reads: the
# placed layout (positions carry the terrain heights), trees.json / props.json / low_foliage.json
# and FIX_VERSION. On a mismatch the pass runs live (same result, slower) and says so once;
# tools/environment/vegetation/bake_layout_fixes.gd rebakes, tools/environment/check_clipping.gd
# fails when the baked result differs from the live pass (bump FIX_VERSION when the pass changes).

const FIX_CACHE_PATH := "res://assets/environment/vegetation/layout_fixes.json"
const FIX_VERSION := 1
## false: always run the pass live (the bake tool, the check's comparison).
var use_fix_cache := true
## Per part: "cache" or "live".
var fix_source := {}
## Per part, the change set of a live run (what bake_layout_fixes.gd writes).
var fix_entries := {}
static var _fix_file := {}
static var _fix_warned := {}


func _run_fix(part: String, pass_fn: Callable) -> void:
	var key := _fix_key(part)
	if use_fix_cache:
		if _fix_file.is_empty():
			var f := FileAccess.open(FIX_CACHE_PATH, FileAccess.READ)
			var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
			_fix_file = d if d is Dictionary else {"_none": true}
		var entry: Dictionary = _fix_file.get(part, {})
		if String(entry.get("key", "")) == key:
			_apply_fix_entry(entry, part)
			fix_source[part] = "cache"
			return
		if not _fix_warned.has(part):
			_fix_warned[part] = true
			print("VEG layout clean-up: %s not baked for this layout, running it live (rebake: tools/environment/vegetation/bake_layout_fixes.gd)" % part)
	var before := _fix_snapshot()
	pass_fn.call()
	fix_source[part] = "live"
	fix_entries[part] = _fix_diff(before, key, part)


## MD5 of the placed layout and the data the pass reads.
func _fix_key(part: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(("v%d %s %d %s" % [FIX_VERSION, part, seed_value, var_to_str(sun_dir)]).to_utf8_buffer())
	for a: Variant in [tree_pos, tree_yaw, tree_scale, tree_kind, tree_variant, prop_pos, prop_yaw, prop_scale,
			prop_kind, prop_tilt, plant_pos, plant_yaw, plant_scale, plant_kind, plant_variant, _tree_keep, _prop_keep]:
		h.update(var_to_bytes(a))
	for path: String in [LOW_FOLIAGE_PATH, Assets.VEG_DIR + "trees/trees.json", Assets.PROPS_DIR + "props.json"]:
		h.update(FileAccess.get_file_as_bytes(path))
	return h.finish().hex_encode()


func _fix_snapshot() -> Array:
	return [tree_pos.duplicate(), tree_yaw.duplicate(), tree_variant.duplicate(), prop_pos.duplicate(),
			prop_yaw.duplicate(), prop_tilt.duplicate(), plant_pos.duplicate(), plant_yaw.duplicate()]


## The changes of a live pass: [index, values...] per changed tree / prop / plant, removed indices.
func _fix_diff(before: Array, key: String, part: String) -> Dictionary:
	var trees := []
	var props := []
	var plants := []
	var bt: PackedVector3Array = before[0]
	for i in bt.size():
		if tree_pos[i] != bt[i] or tree_yaw[i] != before[1][i] or tree_variant[i] != before[2][i]:
			trees.append([i, tree_pos[i].x, tree_pos[i].y, tree_pos[i].z, tree_yaw[i], tree_variant[i]])
	var bp: PackedVector3Array = before[3]
	for i in bp.size():
		if prop_pos[i] != bp[i] or prop_yaw[i] != before[4][i] or prop_tilt[i] != before[5][i]:
			var t := prop_tilt[i]
			props.append([i, prop_pos[i].x, prop_pos[i].y, prop_pos[i].z, prop_yaw[i], t.x, t.y, t.z])
	var bl: PackedVector3Array = before[6]
	for i in bl.size():
		if plant_pos[i] != bl[i] or plant_yaw[i] != before[7][i]:
			plants.append([i, plant_pos[i].x, plant_pos[i].y, plant_pos[i].z, plant_yaw[i]])
	var gone := func(keep: PackedByteArray) -> Array:
		var out := []
		for i in keep.size():
			if keep[i] == 0:
				out.append(i)
		return out
	var stats_part := {}
	for k: String in _fix:
		stats_part[k] = _fix[k] - int(_fix_before_part.get(k, 0))
	_fix_before_part = _fix.duplicate()
	return {"key": key, "trees": trees, "props": props, "plants": plants, "trees_removed": gone.call(_tree_keep),
			"props_removed": gone.call(_prop_keep), "plants_removed": gone.call(_plant_keep), "stats": stats_part}


var _fix_before_part := {}


func _apply_fix_entry(e: Dictionary, part: String) -> void:
	for t: Array in e.get("trees", []):
		var i := int(t[0])
		tree_pos[i] = Vector3(t[1], t[2], t[3])
		tree_yaw[i] = t[4]
		tree_variant[i] = int(t[5])
	for t: Array in e.get("props", []):
		var i := int(t[0])
		prop_pos[i] = Vector3(t[1], t[2], t[3])
		prop_yaw[i] = t[4]
		prop_tilt[i] = Vector3(t[5], t[6], t[7])
	for t: Array in e.get("plants", []):
		var i := int(t[0])
		plant_pos[i] = Vector3(t[1], t[2], t[3])
		plant_yaw[i] = t[4]
	_tree_keep = _keep_sized(_tree_keep, tree_pos.size())
	_prop_keep = _keep_sized(_prop_keep, prop_pos.size())
	_plant_keep = _keep_sized(_plant_keep, plant_pos.size())
	for i: Variant in e.get("trees_removed", []):
		_tree_keep[int(i)] = 0
	for i: Variant in e.get("props_removed", []):
		_prop_keep[int(i)] = 0
	for i: Variant in e.get("plants_removed", []):
		_plant_keep[int(i)] = 0
	for k: String in e.get("stats", {}):
		_fix[k] = int(_fix.get(k, 0)) + int(e.stats[k])
