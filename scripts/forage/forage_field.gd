class_name ForageField
extends Node3D
## Wild food and herb plants in the woods round the fort (user 2026-09-26: "we need to add edible plants and herbs;
## plants and herbs will be the same things deer eat so we know where they will be"). The plants and their numbers:
## data/forage/forage.json. Every one is gathered by people and eaten by deer, so where they are in season is where
## the deer feed.
##
## Placement (build(), once, from the forest layout; its own seed, so the level's rng and layout are untouched):
## patches by habitat within WORLD of the fort: brambles at the woods' edges and clearings, strawberries and plantain
## in the open (plantain where people walk: round the fort and by the range lane), wintergreen under pines and
## hemlocks, ginseng in shaded maple woods, acorns under the oaks, hazelnuts on the vegetation's hazel shrubs. The herbs
## and plants for remedies and vices (user 2026-09-27: "we will need more plants and herbs for these new things"): yarrow
## in the open, hemp and jimsonweed on the disturbed ground round the fort, bearberry at the edges of the pines,
## crabapples at the woods' edges, and in the low ground (a hollow LOW_RING m across lying low_m or more below its rim,
## where the ground stays damp): willow, red-osier dogwood, elderberry and slippery elm. The woods' own materials (user
## 2026-09-28: "do we have sticks on ground for users to make bows and arrows", "we need to have most of items can be
## craftable"): dry sticks and fallen limbs under the trees (branches and firewood without an axe), arrowwood thickets at
## the edges (straight shoots for arrow shafts), pitch on the white pines' trunks, turkey feathers under the oaks; and
## for a start with nothing ("can the game start with the user bare and naked no tools"): loose fieldstones, chert
## nodules in the hollows and dead saplings lying whole (stone, flint and poles without the mattock or the axe). Never
## on the dirt, in the fort, in a trunk or a rock, on a steep slope, nor two patches on top of each other.
## Drawing: MultiMeshes per render cell and part (ForageModels), faded out past each part's range, no shadows; the
## fruit (berries, nuts, acorns) is drawn only in season and while a plant has some left.
##
## Seasons: the level's WorldClock (DayNight), else 25 August; the survival calendar's day ids (forage.json). Stock:
## each plant holds `stock` handfuls when full; picking takes them, and they fill again over regrow_days game days
## while the plant is in season (forage.json game_day_s).
##
## E (PlayerInteractor's "any other interactable" contract; this one node answers for every plant): at a plant in
## reach, "Pick blackberries" (ForagePick: an arm reaches out and grabs a handful into the pack, on the move; the bar fills
## as the patch is picked clean); out of season or picked clean the prompt names the plant and E says when it bears. A patch deer have fed at shows it ("deer have been
## feeding here").
##
## For the wildlife: deer_spots() / deer_feed_spot() (where there is food for deer now, weighted by what they eat in
## the season and what is left), deer_eat() (a deer feeding takes the ripe food first, then browse; so a patch deer
## feed on has less for the player), deer_food(). ForageField.find(tree) gets the level's field.

const VegAssets := preload("res://scripts/world/vegetation/veg_assets.gd")
const GROUP := &"forage_field"
const DATA_PATH := "res://data/forage/forage.json"
## Patches within this of the fort's middle (the deer's range).
const WORLD := 330.0
## Render cells (m); lookups use a finer grid.
const CELL := 32.0
const GRID := 8.0
## Nothing in the fort and its yard (m from the middle along x and z).
const FORT_KEEP := 22.0
## Patches keep this far apart (m, centre to centre).
const PATCH_GAP := 5.0
## E: a plant in this reach (m, from the chest, flat) and this far off the view (deg).
const REACH := 2.3
const MAX_ANGLE := 55.0
## A patch deer fed at within this many game days shows it.
const DEER_SIGN_DAYS := 1.5
## Per part: how far it is drawn (m).
const RANGE := {"blackberry": 95.0, "strawberry": 45.0, "plantain": 55.0, "wintergreen": 45.0, "ginseng": 60.0,
		"acorns": 28.0, "hazelnuts": 0.0, "willow": 140.0, "yarrow": 55.0, "slippery_elm": 150.0, "elderberry": 120.0,
		"hemp": 110.0, "bearberry": 40.0, "red_osier": 120.0, "jimsonweed": 80.0, "crabapple": 170.0, "arrowwood": 120.0,
		"pine_pitch": 45.0, "turkey_scratch": 35.0, "bog_ore": 40.0}
const FRUIT_RANGE := {"blackberry": 50.0, "strawberry": 30.0, "wintergreen": 30.0, "ginseng": 45.0, "acorns": 30.0,
		"hazelnuts": 55.0, "yarrow": 55.0, "elderberry": 70.0, "bearberry": 30.0, "red_osier": 55.0, "jimsonweed": 60.0,
		"crabapple": 90.0, "deadwood": 45.0, "windfall": 80.0, "pine_pitch": 45.0, "turkey_scratch": 35.0, "fieldstones": 55.0,
		"flint_nodules": 35.0, "dead_pole": 80.0, "bog_ore": 40.0, "clay_bank": 45.0}
## Low ground: the ring (m across, its half the radius) a spot is measured against.
const LOW_RING := 70.0

var data := {}
## [{kind, pos, r, plants: [{pos, yaw, s, v, stock, fruit_mm, fruit_i, mm, i}], browse, deer_t, t}]
var patches: Array[Dictionary] = []
## A root dug up (ginseng) comes back from what was left in the ground this many game days after: nothing is gone for
## good (user 2026-09-27: "we should never extint a animal or a plant").
const ROOT_BACK_DAYS := 20.0
## Seconds since the level started (the regrowth clock).
var now := 0.0
## Tests: a day of the year to use instead of the clock's (-1: the clock's).
var day_override := -1.0
## The day id index (0..35) the fruit is drawn for.
var day_index := -1
## Microseconds build() took (tests).
var build_usec := 0
var interact_reach := REACH + 0.6

var _grid := {}                   ## Vector2i -> [patch index]
var _mm := {}                     ## "kind:v:fruit:cell" -> MultiMeshInstance3D
var _offer := {}
var _player: Node3D
var _season_t := 0.0
var _vis_t := 0.0
var _clock: WorldClock
var picker: ForagePick


static func find(tree: SceneTree) -> ForageField:
	return tree.get_first_node_in_group(GROUP) as ForageField if tree else null


static func load_data() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return d if d is Dictionary else {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)
	picker = ForagePick.new()
	picker.name = "Pick"
	picker.field = self
	add_child(picker)


# --- Placement -------------------------------------------------------------------------------------------

## Places every patch from the forest layout of `veg` and builds the drawing.
func build(veg: FrontierVegetation, seed_ := 1765) -> void:
	var t0 := Time.get_ticks_usec()
	data = load_data()
	var lay: Variant = veg.layout if veg else null
	if lay == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var trees := _tree_grid(lay)
	var props := _prop_grid(lay)
	var plants: Dictionary = data.get("plants", {})
	for kind: String in plants:
		var d: Dictionary = plants[kind]
		match String(d.get("habitat", "")):
			"oak":
				_place_under_oaks(kind, d, lay, trees, props, rng)
			"hazel":
				_place_on_hazels(kind, d, lay, rng)
			"pine_trunk":
				_place_on_pine_trunks(kind, d, lay, rng)
			_:
				_place_patches(kind, d, trees, props, rng)
	_build_draw()
	_update_season(true)
	build_usec = Time.get_ticks_usec() - t0
	if DisplayServer.get_name() != "headless":
		_clear_grass.call_deferred()      # after the grass has built its blocker map (FrontierGrass._apply_blockers)


## Trunks by grid cell: [x, z, kind, radius].
func _tree_grid(lay: Variant) -> Dictionary:
	var g := {}
	var tp: PackedVector3Array = lay.tree_pos
	var tk: PackedInt32Array = lay.tree_kind
	var ts: PackedFloat32Array = lay.tree_scale
	for i in tp.size():
		var k := tk[i]
		if k > VegAssets.BIRCH:
			continue
		var p := tp[i]
		if absf(p.x) > WORLD + 20.0 or absf(p.z) > WORLD + 20.0:
			continue
		var r := float(VegAssets.tree(k, int(lay.tree_variant[i])).get("trunk_radius", 0.3)) * ts[i]
		var c := Vector2i(floori(p.x / GRID), floori(p.z / GRID))
		if not g.has(c):
			g[c] = []
		(g[c] as Array).append(Vector4(p.x, p.z, float(k), r))
	return g


## Rocks, logs and stumps by grid cell: [x, z, radius].
func _prop_grid(lay: Variant) -> Dictionary:
	var g := {}
	var pp: PackedVector3Array = lay.prop_pos
	var ps: PackedFloat32Array = lay.prop_scale
	for i in pp.size():
		var p := pp[i]
		if absf(p.x) > WORLD + 20.0 or absf(p.z) > WORLD + 20.0:
			continue
		var c := Vector2i(floori(p.x / GRID), floori(p.z / GRID))
		if not g.has(c):
			g[c] = []
		(g[c] as Array).append(Vector3(p.x, p.z, 1.3 * ps[i]))
	return g


## Near trunks of `g` round (x, z) within r: [distance to the bark, kind] each.
static func _near(g: Dictionary, x: float, z: float, r: float) -> Array:
	var out := []
	var n := ceili(r / GRID)
	var c0 := Vector2i(floori(x / GRID), floori(z / GRID))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			for e in g.get(c0 + Vector2i(dx, dz), []):
				var d := Vector2(e.x - x, e.y - z).length()
				if e is Vector4:
					if d - e.w < r:
						out.append([d - e.w, int(e.z)])
				elif d - e.z < r:
					out.append([d - e.z, -1])
	return out


static func _nearest(g: Dictionary, x: float, z: float, r: float) -> float:
	var best := INF
	for e in _near(g, x, z, r):
		best = minf(best, float(e[0]))
	return best


## Ground fit for a plant: not on the dirt, outside the fort, on a gentle slope, on the terrain in the world.
func _ground_ok(x: float, z: float) -> bool:
	if absf(x) < FORT_KEEP and absf(z) < FORT_KEEP:
		return false
	if absf(x) > FrontierTerrain.WORLD_HALF - 12.0 or absf(z) > FrontierTerrain.WORLD_HALF - 12.0:
		return false
	if Sfx.is_dirt(Vector3(x, 0.0, z)):
		return false
	# the range lane and its targets and bales
	if absf(x) < 9.0 and z < -14.0 and z > -205.0:
		return false
	return FrontierTerrain.normal_at(x, z).y > 0.86


func _free_spot(x: float, z: float, gap: float) -> bool:
	var n := ceili(gap / GRID)
	var c0 := Vector2i(floori(x / GRID), floori(z / GRID))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			for i: int in _grid.get(c0 + Vector2i(dx, dz), []):
				var q: Vector3 = patches[i].pos
				if Vector2(q.x - x, q.z - z).length() < gap:
					return false
	return true


func _place_patches(kind: String, d: Dictionary, trees: Dictionary, props: Dictionary, rng: RandomNumberGenerator) -> void:
	var want := int(d.get("patches", 20))
	var fr: Array = d.get("forest", [0.0, 1.0])
	var tm: Array = d.get("trunk_m", [0.0, 99.0])
	var hab := String(d.get("habitat", ""))
	var placed := 0
	# (a plant of a rarer ground looks harder: forage.json `tries` a patch)
	for attempt in want * int(d.get("tries", 60)):
		if placed >= want:
			break
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * WORLD
		if hab == "open" and d.has("near_fort_m") and rng.randf() < 0.75:
			# plantain: round the fort and by the lane, where people walk
			if rng.randf() < 0.5:
				r = rng.randf_range(FORT_KEEP + 2.0, float(d.near_fort_m))
			else:
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var p0 := Vector2(side * rng.randf_range(10.0, 20.0), rng.randf_range(-175.0, -24.0))
				a = atan2(p0.y, p0.x)
				r = p0.length()
		var x := cos(a) * r
		var z := sin(a) * r
		if not _ground_ok(x, z) or not _free_spot(x, z, PATCH_GAP + float(d.get("spread_m", [1.0, 2.0])[1])):
			continue
		var fd := FrontierTerrain.forest_density(x, z)
		if fd < float(fr[0]) or fd > float(fr[1]):
			continue
		if hab == "low" and lowness(x, z) > -float(d.get("low_m", 1.0)):
			continue
		var near := _near(trees, x, z, maxf(float(tm[1]), 10.0))
		var dmin := INF
		var conifers := 0
		var maples := 0
		for e in near:
			dmin = minf(dmin, float(e[0]))
			if float(e[0]) < 8.0 and int(e[1]) in [VegAssets.WHITE_PINE, VegAssets.HEMLOCK]:
				conifers += 1
			if float(e[0]) < 10.0 and int(e[1]) == VegAssets.MAPLE:
				maples += 1
		if dmin < float(tm[0]) or (dmin > float(tm[1]) and float(tm[1]) < 90.0):
			continue
		if hab == "conifer" and conifers < int(d.get("conifers_near", 2)):
			continue
		if hab == "maple" and maples < int(d.get("maples_near", 2)):
			continue
		if _nearest(props, x, z, 2.5) < 0.6:
			continue
		var pr: Array = d.get("per_patch", [3, 6])
		var sp: Array = d.get("spread_m", [1.0, 2.0])
		var spread := rng.randf_range(float(sp[0]), float(sp[1]))
		var pl := []
		for k in rng.randi_range(int(pr[0]), int(pr[1])):
			var off := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * spread
			var px := x + off.x
			var pz := z + off.y
			if not _ground_ok(px, pz) or _nearest(trees, px, pz, 1.0) < 0.35 or _nearest(props, px, pz, 2.5) < 0.25:
				continue
			pl.append(_plant(Vector3(px, FrontierTerrain.height_at(px, pz), pz), rng, d))
		if pl.size() < maxi(1, int(pr[0]) / 2):
			continue
		_add_patch(kind, Vector3(x, FrontierTerrain.height_at(x, z), z), spread, pl)
		placed += 1


## How far the ground at x, z lies below the ground round it (m, negative in a hollow): its height less the mean of eight
## points LOW_RING / 2 away.
static func lowness(x: float, z: float) -> float:
	var s := 0.0
	for k in 8:
		var b := TAU * k / 8.0
		s += FrontierTerrain.height_at(x + cos(b) * LOW_RING * 0.5, z + sin(b) * LOW_RING * 0.5)
	return FrontierTerrain.height_at(x, z) - s / 8.0


## Acorns under the oaks: an oak's crown drops them 1-5.5 m round its trunk.
func _place_under_oaks(kind: String, d: Dictionary, lay: Variant, trees: Dictionary, props: Dictionary, rng: RandomNumberGenerator) -> void:
	var oaks := []
	var tp: PackedVector3Array = lay.tree_pos
	for i in tp.size():
		if lay.tree_kind[i] == VegAssets.OAK and Vector2(tp[i].x, tp[i].z).length() < WORLD and not (absf(tp[i].x) < FORT_KEEP and absf(tp[i].z) < FORT_KEEP):
			oaks.append(i)
	# the nearer oaks first, then the rest shuffled (the player meets the near ones)
	oaks.sort_custom(func(a: int, b: int) -> bool: return Vector2(tp[a].x, tp[a].z).length() < Vector2(tp[b].x, tp[b].z).length())
	var near := oaks.slice(0, 40)
	var rest := oaks.slice(40)
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = rest[i]
		rest[i] = rest[j]
		rest[j] = t
	var want := int(d.get("patches", 100))
	var pr: Array = d.get("per_patch", [10, 20])
	var sp: Array = d.get("spread_m", [1.5, 5.5])
	for i: int in near + rest:
		if patches.filter(func(p: Dictionary) -> bool: return p.kind == kind).size() >= want:
			break
		var c := tp[i]
		var pl := []
		for k in rng.randi_range(int(pr[0]), int(pr[1])):
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(float(sp[0]), float(sp[1]))
			var px := c.x + off.x
			var pz := c.z + off.y
			if not _ground_ok(px, pz) or _nearest(trees, px, pz, 1.0) < 0.3 or _nearest(props, px, pz, 2.5) < 0.2:
				continue
			pl.append(_plant(Vector3(px, FrontierTerrain.height_at(px, pz), pz), rng, d))
		if pl.size() >= 4:
			_add_patch(kind, c, float(sp[1]), pl)


## Hazelnuts in clusters on the vegetation's hazel shrubs, on the surface of the crown.
func _place_on_hazels(kind: String, d: Dictionary, lay: Variant, rng: RandomNumberGenerator) -> void:
	var pp: PackedVector3Array = lay.plant_pos
	var pr: Array = d.get("per_patch", [4, 7])
	for i in pp.size():
		if lay.plant_kind[i] != VegAssets.SHRUB_HAZEL:
			continue
		var c := pp[i]
		if Vector2(c.x, c.z).length() > WORLD or (absf(c.x) < FORT_KEEP and absf(c.z) < FORT_KEEP):
			continue
		var s: float = lay.plant_scale[i]
		var t := VegAssets.tree(VegAssets.SHRUB_HAZEL, int(lay.plant_variant[i]))
		var mid := c.y + (float(t.get("crown_bottom", 0.45)) + float(t.get("crown_top", 2.4))) * 0.5 * s
		var hr := float(t.get("crown_radius", 1.4)) * s * 0.92
		var vr := float(t.get("crown_half_height", 0.8)) * s * 0.9
		var pl := []
		for k in rng.randi_range(int(pr[0]), int(pr[1])):
			var yaw := rng.randf() * TAU
			var el := deg_to_rad(rng.randf_range(-25.0, 35.0))
			var at := Vector3(c.x + cos(yaw) * cos(el) * hr, mid + sin(el) * vr, c.z + sin(yaw) * cos(el) * hr)
			var e := _plant(at, rng, d)
			e["yaw"] = yaw
			pl.append(e)
		_add_patch(kind, c, hr, pl)


## Pine pitch on the white pines' trunks: a resin run at chest height on the bark (the model's +Z out of the bark), the
## nearer pines first, then the rest shuffled.
func _place_on_pine_trunks(kind: String, d: Dictionary, lay: Variant, rng: RandomNumberGenerator) -> void:
	var tp: PackedVector3Array = lay.tree_pos
	var pines := []
	for i in tp.size():
		if lay.tree_kind[i] == VegAssets.WHITE_PINE and Vector2(tp[i].x, tp[i].z).length() < WORLD and not (absf(tp[i].x) < FORT_KEEP and absf(tp[i].z) < FORT_KEEP):
			pines.append(i)
	pines.sort_custom(func(a: int, b: int) -> bool: return Vector2(tp[a].x, tp[a].z).length() < Vector2(tp[b].x, tp[b].z).length())
	var near := pines.slice(0, 30)
	var rest := pines.slice(30)
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = rest[i]
		rest[i] = rest[j]
		rest[j] = t
	var want := int(d.get("patches", 60))
	var n := 0
	for i: int in near + rest:
		if n >= want:
			break
		var c := tp[i]
		var r := float(VegAssets.tree(VegAssets.WHITE_PINE, int(lay.tree_variant[i])).get("trunk_radius", 0.3)) * float(lay.tree_scale[i])
		var yaw := rng.randf() * TAU
		var out := Vector3(sin(yaw), 0.0, cos(yaw))
		if not _ground_ok(c.x + out.x * (r + 0.8), c.z + out.z * (r + 0.8)):
			continue
		var gy := FrontierTerrain.height_at(c.x + out.x * r, c.z + out.z * r)
		var e := _plant(Vector3(c.x, gy + rng.randf_range(0.95, 1.35), c.z) + out * (r * 0.97), rng, d)
		e["yaw"] = yaw
		e["s"] = 1.0
		_add_patch(kind, Vector3(c.x, gy, c.z) + out * r, 1.0, [e])
		n += 1


func _plant(at: Vector3, rng: RandomNumberGenerator, d: Dictionary) -> Dictionary:
	return {"pos": at, "yaw": rng.randf() * TAU, "s": rng.randf_range(0.8, 1.2), "v": rng.randi() % ForageModels.VARIANTS,
			"stock": float(d.get("stock", 1.0)), "gone": false, "r": rng.randf()}


## What plant `pl` of `kind` holds when full now: its stock, if it bears this early (an early window's share of the
## plants bear, each a whole crop: the first few acorns down), else nothing.
func _full_of(kind: String, pl: Dictionary) -> float:
	return float(data.plants[kind].get("stock", 1.0)) if float(pl.get("r", 0.0)) < crop_share(kind) else 0.0


func _add_patch(kind: String, c: Vector3, r: float, pl: Array) -> void:
	var i := patches.size()
	patches.append({"kind": kind, "pos": c, "r": r, "plants": pl, "browse": 1.0, "deer_t": -1e9, "t": 0.0})
	var g := Vector2i(floori(c.x / GRID), floori(c.z / GRID))
	if not _grid.has(g):
		_grid[g] = []
	(_grid[g] as Array).append(i)


## Patches whose centre is within r (flat) of `p`.
func patches_near(p: Vector3, r: float) -> Array[int]:
	var out: Array[int] = []
	var n := ceili((r + 6.0) / GRID)
	var c0 := Vector2i(floori(p.x / GRID), floori(p.z / GRID))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			for i: int in _grid.get(c0 + Vector2i(dx, dz), []):
				var q: Vector3 = patches[i].pos
				if Vector2(q.x - p.x, q.z - p.z).length() <= r + float(patches[i].r):
					out.append(i)
	return out


# --- Drawing ---------------------------------------------------------------------------------------------

func _build_draw() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var groups := {}
	for pi in patches.size():
		var pa: Dictionary = patches[pi]
		var kind := String(pa.kind)
		for li in (pa.plants as Array).size():
			var pl: Dictionary = pa.plants[li]
			var p: Vector3 = pl.pos
			var cell := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
			for fruit in [false, true]:
				var mesh := ForageModels.fruit_mesh(kind, int(pl.v)) if fruit else ForageModels.plant_mesh(kind, int(pl.v))
				if mesh == null:
					continue
				var key := "%s:%d:%s:%d:%d" % [kind, int(pl.v), fruit, cell.x, cell.y]
				if not groups.has(key):
					groups[key] = {"kind": kind, "v": int(pl.v), "fruit": fruit, "cell": cell, "items": []}
				(groups[key].items as Array).append([pi, li])
	for key: String in groups:
		var g: Dictionary = groups[key]
		var items: Array = g.items
		var kind := String(g.kind)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = ForageModels.fruit_mesh(kind, int(g.v)) if g.fruit else ForageModels.plant_mesh(kind, int(g.v))
		mm.instance_count = items.size()
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Forage_" + key.replace(":", "_")
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var rng_end: float = (FRUIT_RANGE if g.fruit else RANGE).get(kind, 50.0)
		mmi.visibility_range_end = rng_end + CELL * 0.5         # the cell's far plants too
		mmi.visibility_range_end_margin = rng_end * 0.15
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
		var cc := Vector3((int(g.cell.x) + 0.5) * CELL, 0.0, (int(g.cell.y) + 0.5) * CELL)
		mmi.position = Vector3(cc.x, 0.0, cc.z)
		for n in items.size():
			var pi: int = items[n][0]
			var li: int = items[n][1]
			var pl: Dictionary = patches[pi].plants[li]
			pl["fruit_mm" if g.fruit else "mm"] = mm
			pl["fruit_i" if g.fruit else "i"] = n
			pl["origin"] = mmi.position
			var tint := Color.WHITE
			if not g.fruit:
				var k := 0.88 + 0.24 * fposmod(float(pl.yaw) * 7.13, 1.0)
				tint = Color(k, k * lerpf(0.97, 1.05, fposmod(float(pl.yaw) * 3.7, 1.0)), k * 0.95)
			mm.set_instance_color(n, tint)
			mm.set_instance_transform(n, _xf(pl, mmi.position, true))


func _xf(pl: Dictionary, origin: Vector3, shown: bool) -> Transform3D:
	var s := float(pl.s) if shown else 0.0001
	return Transform3D(Basis(Vector3.UP, float(pl.yaw)).scaled(Vector3.ONE * s), (pl.pos as Vector3) - origin)


## Fruit on or off for every plant of patch `pi` by the season and what each has left; a dug plant goes.
func _refresh_patch(pi: int) -> void:
	var pa: Dictionary = patches[pi]
	var d: Dictionary = data.plants[pa.kind]
	var bears := fruit_shown(String(pa.kind))
	var full := float(d.get("stock", 1.0))
	for pl: Dictionary in pa.plants:
		if pl.has("fruit_mm"):
			var on: bool = bears and not pl.gone and float(pl.stock) >= full * 0.5
			(pl.fruit_mm as MultiMesh).set_instance_transform(int(pl.fruit_i), _xf(pl, pl.origin, on))
		if pl.has("mm"):
			(pl.mm as MultiMesh).set_instance_transform(int(pl.i), _xf(pl, pl.origin, not pl.gone))


# --- Seasons and stock -----------------------------------------------------------------------------------

## The survival calendar's day index (0 jan_early .. 35 dec_late) of day-of-year `doy`.
static func day_index_of(doy: float) -> int:
	var m := WorldClock.month_of(doy)
	var dom := doy - float(WorldClock.MONTH_START_DOY[m]) + 1.0
	return m * 3 + (0 if dom < 11.0 else (1 if dom < 21.0 else 2))


## The index of a day id ("aug_late" -> 23), -1 when unknown.
static func day_id_index(id: String) -> int:
	var months := ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
	var parts := id.split("_")
	if parts.size() != 2 or not (parts[0] in months):
		return -1
	return months.find(parts[0]) * 3 + ["early", "mid", "late"].find(parts[1])


static func in_window(i: int, w: Array) -> bool:
	if w.size() != 2:
		return false
	var a := day_id_index(String(w[0]))
	var b := day_id_index(String(w[1]))
	return (i >= a and i <= b) if a <= b else (i >= a or i <= b)


func doy() -> float:
	if day_override > 0.0:
		return day_override
	if _clock == null and is_inside_tree() and get_tree().current_scene:
		var rig: Variant = get_tree().current_scene.get("environment_rig")
		if rig is EnvironmentRig and (rig as EnvironmentRig).clock_driver:
			_clock = (rig as EnvironmentRig).clock_driver.clock
	return _clock.day_of_year if _clock else WorldClock.DEFAULT_DAY_OF_YEAR


## Can people take `kind` now (its ripe window)?
func in_season(kind: String) -> bool:
	var d: Dictionary = data.plants.get(kind, {})
	return in_window(day_index, d.get("ripe", []))


## Is the fruit on `kind` now (the ripe window; wintergreen's berries have their own)?
func fruit_shown(kind: String) -> bool:
	var d: Dictionary = data.plants.get(kind, {})
	return in_window(day_index, d.get("berries", d.get("ripe", [])))


## How much of a full crop `kind` bears now (early windows bear less).
func crop_share(kind: String) -> float:
	var d: Dictionary = data.plants.get(kind, {})
	var early: Dictionary = d.get("early", {})
	var ids := ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
	var id := "%s_%s" % [ids[day_index / 3], ["early", "mid", "late"][day_index % 3]]
	return float(early.get(id, 1.0))


func _update_season(force := false) -> void:
	var i := day_index_of(doy())
	if i == day_index and not force:
		return
	var first := day_index < 0
	var prev := day_index
	day_index = i
	for pi in patches.size():
		var pa: Dictionary = patches[pi]
		var d: Dictionary = data.plants[pa.kind]
		if first:
			# the crop the season has put on the plants (an early window: fewer of them bear)
			var ripe := in_season(String(pa.kind))
			for pl: Dictionary in pa.plants:
				pl.stock = _full_of(String(pa.kind), pl) if ripe else 0.0
			pa.t = now
		elif float(d.get("regrow_days", 0.0)) <= 0.0 and in_season(String(pa.kind)) and not in_window(prev, d.get("ripe", [])):
			# the season's one crop on a plant that does not bear again within it (crabapples, hazelnuts): on as the season
			# comes (a root dug stays gone)
			for pl: Dictionary in pa.plants:
				if not pl.gone:
					pl.stock = _full_of(String(pa.kind), pl)
			pa.t = now
		_refresh_patch(pi)


## Brings patch `pi`'s stock up to now (regrowth in season), and its browse.
func _grow(pi: int) -> void:
	var pa: Dictionary = patches[pi]
	var dt := now - float(pa.t)
	pa.t = now
	if dt <= 0.0:
		return
	var d: Dictionary = data.plants[pa.kind]
	var days := dt / float(data.get("game_day_s", 3456.0))
	pa.browse = minf(float(pa.browse) + days * 0.5, 1.0)
	# a root dug comes back, a sprout, ROOT_BACK_DAYS after (one dug before its clock was kept: from now)
	var back := false
	for pl: Dictionary in pa.plants:
		if not pl.gone:
			continue
		if not pl.has("dug_t"):
			pl.dug_t = now
		elif now - float(pl.dug_t) >= ROOT_BACK_DAYS * float(data.get("game_day_s", 3456.0)):
			pl.gone = false
			pl.stock = 0.0
			pl.erase("dug_t")
			back = true
	if back:
		_refresh_patch(pi)
	var rd := float(d.get("regrow_days", 0.0))
	if rd <= 0.0 or not in_season(String(pa.kind)):
		return
	var changed := false
	for pl: Dictionary in pa.plants:
		var full := _full_of(String(pa.kind), pl)
		if pl.gone or float(pl.stock) >= full:
			continue
		pl.stock = minf(float(pl.stock) + full * days / rd, full)
		changed = true
	if changed:
		_refresh_patch(pi)


## Handfuls left in patch `pi`.
## How much of patch `pi`'s crop has been picked (0: full, 1: picked clean): ForagePick's bar.
func picked_share(pi: int) -> float:
	var left := stock_of(pi)
	var full := 0.0
	var kind := String(patches[pi].kind)
	for pl: Dictionary in patches[pi].plants:
		if not pl.gone:
			full += _full_of(kind, pl)
	return clampf(1.0 - left / full, 0.0, 1.0) if full > 0.0 else 1.0


func stock_of(pi: int) -> float:
	_grow(pi)
	var s := 0.0
	for pl: Dictionary in patches[pi].plants:
		if not pl.gone:
			s += float(pl.stock)
	return s


## Takes one handful from patch `pi`, from plant `li` first and then the nearest others; the plant dug up when the
## kind is a root (ginseng: regrow_days 0 and a stock of a whole root). Returns the handfuls taken (0..1).
func take(pi: int, li: int) -> float:
	_grow(pi)
	var pa: Dictionary = patches[pi]
	var d: Dictionary = data.plants[pa.kind]
	var pl0: Dictionary = pa.plants[li]
	var order := range((pa.plants as Array).size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return (pa.plants[a].pos as Vector3).distance_to(pl0.pos) < (pa.plants[b].pos as Vector3).distance_to(pl0.pos))
	var need := 1.0
	var root := String(d.get("clip", "")) == "ground" and float(d.get("stock", 1.0)) >= 1.0
	for k: int in order:
		var pl: Dictionary = pa.plants[k]
		if pl.gone or float(pl.stock) <= 0.001:
			continue
		var t := minf(float(pl.stock), need)
		pl.stock = float(pl.stock) - t
		need -= t
		if root:
			pl.gone = true
			pl.dug_t = now
		if need <= 0.001:
			break
	_refresh_patch(pi)
	return 1.0 - need


# --- E -----------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	now += delta
	_season_t -= delta
	if _season_t <= 0.0:
		_season_t = 5.0
		_update_season()
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_offer = _find_offer()
	# the fruit near the player catches up with its regrowth (the far patches when someone comes)
	_vis_t -= delta
	if _vis_t <= 0.0 and _player:
		_vis_t = 2.0
		for pi in patches_near(_player.global_position, 60.0):
			_grow(pi)


## The plant E offers now: {patch, plant, point, text, can}, or {}.
func _find_offer() -> Dictionary:
	var p := _player
	if p == null or p.get("is_dead") == true or p.get("riding") != null:
		return {}
	var chest := p.global_position + Vector3.UP * 1.2
	var yaw := float(p.get("yaw")) if p.get("yaw") != null else p.rotation.y
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var best := {}
	var best_s := INF
	for pi in patches_near(p.global_position, REACH + 0.5):
		var pa: Dictionary = patches[pi]
		for li in (pa.plants as Array).size():
			var pl: Dictionary = pa.plants[li]
			if pl.gone:
				continue
			var pt := _point_of(String(pa.kind), pl)
			var to := pt - chest
			var dist := Vector2(to.x, to.z).length()
			if dist > REACH:
				continue
			var ang := 0.0
			if dist > 0.35:
				ang = rad_to_deg(fwd.angle_to(Vector3(to.x, 0.0, to.z).normalized()))
				if ang > MAX_ANGLE:
					continue
			var s := ang / MAX_ANGLE + dist / REACH
			if s < best_s:
				best_s = s
				best = {"patch": pi, "plant": li, "point": pt}
	if best.is_empty():
		return {}
	var pa: Dictionary = patches[best.patch]
	var kind := String(pa.kind)
	var d: Dictionary = data.plants[kind]
	var left := stock_of(best.patch)
	var sign := " (deer have been feeding here)" if now - float(pa.deer_t) < DEER_SIGN_DAYS * float(data.get("game_day_s", 3456.0)) else ""
	if in_season(kind) and left >= 0.5:
		best["can"] = true
		best["text"] = "%s  (%d left)%s" % [String(d.get("take", "Pick")), int(left), sign]
	else:
		best["can"] = false
		best["text"] = String(d.get("name", kind)).capitalize() + sign
	return best


## Where E points at a plant (its middle at a hand's height for the plant).
func _point_of(kind: String, pl: Dictionary) -> Vector3:
	var p: Vector3 = pl.pos
	match kind:
		"blackberry":
			return p + Vector3.UP * 0.55 * float(pl.s)
		"ginseng":
			return p + Vector3.UP * 0.25
		"hazelnuts":
			return p
		# the bark at chest height on the stems and trunks; the tops, the leaves, the fruit where the hands go
		"willow", "slippery_elm", "red_osier":
			return p + Vector3.UP * 1.1
		"elderberry", "crabapple":
			return p + Vector3.UP * 1.3 * float(pl.s)
		"hemp":
			return p + Vector3.UP * 1.2 * float(pl.s)
		"jimsonweed":
			return p + Vector3.UP * 0.55 * float(pl.s)
		"yarrow":
			return p + Vector3.UP * 0.3
	return p + Vector3.UP * 0.06


func interact_point() -> Vector3:
	return _offer.get("point", Vector3.INF)


func distance_from(pt: Vector3) -> float:
	if _offer.is_empty():
		return INF
	var q: Vector3 = _offer.point
	return Vector2(q.x - pt.x, q.z - pt.z).length()


func interact_prompt(_p: Node) -> String:
	return String(_offer.get("text", ""))


## No glow: one plant among many drawn in a MultiMesh; the prompt names it.
func highlight_targets() -> Array:
	return []


func interact(p: Node) -> bool:
	if _offer.is_empty():
		return false
	var pa: Dictionary = patches[_offer.patch]
	var kind := String(pa.kind)
	if not bool(_offer.get("can", false)):
		_notice(_when_text(kind, pa))
		return false
	return picker.start(p as FrontierPlayer, int(_offer.patch), int(_offer.plant), _offer.point)


## Why there is nothing to take: out of season (when it bears) or picked clean.
func _when_text(kind: String, pa: Dictionary) -> String:
	var d: Dictionary = data.plants[kind]
	var nm := String(d.get("name", kind))
	if not in_season(kind):
		var w: Array = d.get("ripe", [])
		return "The %s bears from %s to %s" % [nm, _day_words(String(w[0])), _day_words(String(w[1]))] if w.size() == 2 else "Nothing to take"
	if float(d.get("regrow_days", 0.0)) <= 0.0:
		return "Nothing left on this %s this season" % nm
	return "Picked clean: the %s bears again in a few days" % nm


static func _day_words(id: String) -> String:
	var months := {"jan": "January", "feb": "February", "mar": "March", "apr": "April", "may": "May", "jun": "June",
			"jul": "July", "aug": "August", "sep": "September", "oct": "October", "nov": "November", "dec": "December"}
	var parts := id.split("_")
	return "%s %s" % [parts[1], months.get(parts[0], parts[0])] if parts.size() == 2 else id


func _notice(text: String) -> void:
	var it: Node = _player.get("interactor") if _player else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text)


# --- For the wildlife --------------------------------------------------------------------------------------

## What there is for deer to eat at patch `pi` now: browse (leaves and twigs, all year) plus the ripe food (fruit,
## nuts, acorns) by the plant's deer weights (forage.json deer), times how much is left.
func deer_food(pi: int) -> float:
	var pa: Dictionary = patches[pi]
	var d: Dictionary = data.plants[pa.kind]
	var dw: Dictionary = d.get("deer", {})
	var n := 0.0
	for pl: Dictionary in pa.plants:
		if not pl.gone:
			n += 1.0
	var food := float(dw.get("browse", 0.3)) * float(pa.browse) * sqrt(n)
	if fruit_shown(String(pa.kind)):
		food += float(dw.get("ripe", 0.5)) * stock_of(pi)
	return food


## The land's plants for the wildlife (WildlifeEcology.plants), 0 stripped .. 1 all standing and full: each patch,
## the share of its plants still standing times its browse and (in season) the crop left on them against a full one,
## averaged over the land (user 2026-09-27: too much taken "without replant or letting the plants powermeter come back
## then the deer becamse scares"). People picking and digging lower it, as the deer's feeding does; it comes back as they
## regrow.
func plant_level() -> float:
	if patches.is_empty():
		return 1.0
	var s := 0.0
	for pi in patches.size():
		_grow(pi)
		var pa: Dictionary = patches[pi]
		var kind := String(pa.kind)
		var n := 0
		var up := 0
		var stock := 0.0
		var full := 0.0
		for pl: Dictionary in pa.plants:
			n += 1
			if not pl.gone:
				up += 1
				stock += float(pl.stock)
				full += _full_of(kind, pl)
		var crop := clampf(stock / full, 0.0, 1.0) if in_season(kind) and full > 0.0 else 1.0
		s += float(up) / float(maxi(n, 1)) * (0.5 * float(pa.browse) + 0.5 * crop)
	return s / float(patches.size())


## Feeding places for deer within r of `pos`, most food first: [{pos, food, kind, patch}] (at most n).
func deer_spots(pos: Vector3, r: float, n := 6) -> Array:
	var out := []
	for pi in patches_near(pos, r):
		var f := deer_food(pi)
		if f > 0.05:
			out.append({"pos": patches[pi].pos, "food": f, "kind": patches[pi].kind, "patch": pi})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.food) > float(b.food))
	return out.slice(0, n)


## One place to feed within r of `pos`, drawn by its food over its distance (nearer and richer likelier), or
## Vector3.INF when there is none.
func deer_feed_spot(pos: Vector3, r: float, rng: RandomNumberGenerator = null) -> Vector3:
	var spots := deer_spots(pos, r, 12)
	if spots.is_empty():
		return Vector3.INF
	var total := 0.0
	var w := []
	for s: Dictionary in spots:
		var k := float(s.food) / (1.0 + (s.pos as Vector3).distance_to(pos) / 40.0)
		w.append(k)
		total += k
	var x := (rng.randf() if rng else randf()) * total
	for i in spots.size():
		x -= float(w[i])
		if x <= 0.0:
			return spots[i].pos
	return spots[0].pos


## A deer feeding at `pos` for `dt` seconds eats from the nearest patch within 3 m: the ripe food first (a handful
## in about 30 s: what people would pick), then browse. Marks the patch as fed at (the player's sign). Returns what
## it ate (handfuls of ripe food plus browse).
func deer_eat(pos: Vector3, dt: float) -> float:
	var best := -1
	var bd := 3.0
	for pi in patches_near(pos, 3.0):
		var q: Vector3 = patches[pi].pos
		var d := Vector2(q.x - pos.x, q.z - pos.z).length() - float(patches[pi].r)
		if d < bd:
			bd = d
			best = pi
	if best < 0:
		return 0.0
	var pa: Dictionary = patches[best]
	pa.deer_t = now
	_grow(best)
	var ate := 0.0
	var want := dt / 30.0
	if fruit_shown(String(pa.kind)):
		for pl: Dictionary in pa.plants:
			if want <= 0.0:
				break
			if pl.gone or float(pl.stock) <= 0.0:
				continue
			var t := minf(float(pl.stock), want)
			pl.stock = float(pl.stock) - t
			want -= t
			ate += t
		_refresh_patch(best)
	var b := minf(float(pa.browse), dt / 600.0)
	pa.browse = float(pa.browse) - b
	return ate + b


# --- Grass -------------------------------------------------------------------------------------------------

## Radius (m) round each low plant where no grass tuft grows (the plant crowds it out), so the grass does not bury
## it: the grass's blocker map (FrontierGrass: 255 = no tuft), as the buildings clear it (BuildGrass).
const GRASS_CLEAR := {"strawberry": 0.17, "plantain": 0.24, "ginseng": 0.22, "wintergreen": 0.14, "acorns": 0.1,
		"bearberry": 0.3, "yarrow": 0.12, "deadwood": 0.4, "windfall": 1.0, "turkey_scratch": 0.45, "fieldstones": 0.4,
		"flint_nodules": 0.3, "dead_pole": 1.2, "bog_ore": 0.5, "clay_bank": 0.4}
## Texels cleared (tests).
var grass_cleared := 0


func _clear_grass() -> void:
	var terrain := get_parent().get_node_or_null("Terrain") if get_parent() else null
	var g: Variant = terrain.get("grass") if terrain else null
	if not (g is FrontierGrass) or (g as FrontierGrass).material == null:
		return
	var tex: Variant = (g as FrontierGrass).material.get_shader_parameter("blocker_map")
	if not (tex is ImageTexture):
		return
	var img := (tex as ImageTexture).get_image()
	if img == null or img.get_format() != Image.FORMAT_R8:
		return
	var n := img.get_width()
	var buf := img.get_data()
	var res := FrontierGrass.BLOCK_RES
	var half := FrontierGrass.BLOCK_HALF
	grass_cleared = 0
	for pa in patches:
		var r := float(GRASS_CLEAR.get(pa.kind, 0.0))
		if r <= 0.0:
			continue
		for pl in pa.plants:
			var p: Vector3 = pl.pos
			var i0 := clampi(int(floor((p.x - r + half) / res)), 0, n - 1)
			var i1 := clampi(int(floor((p.x + r + half) / res)), 0, n - 1)
			var j0 := clampi(int(floor((p.z - r + half) / res)), 0, n - 1)
			var j1 := clampi(int(floor((p.z + r + half) / res)), 0, n - 1)
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var k := j * n + i
					if buf[k] != 255:
						buf[k] = 255
						grass_cleared += 1
	(tex as ImageTexture).update(Image.create_from_data(n, n, false, Image.FORMAT_R8, buf))
