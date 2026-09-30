class_name BuildGeometry
extends RefCounted
## Meshes and colliders of the buildable pieces (scripts/building/), in each piece's own frame, made with the
## fort's kit (StructureMeshKit, StructureGeometry) and materials (StructureMaterials: the processed CC0 Poly
## Haven bark, weathered boards, riven shingles and fieldstone), so what the player builds matches the fort.
##
## Frames (metres; every piece is a 3 m module):
##   floor          origin at the centre of the 3 x 3 m cell on the footing's level; the floor's top at FLOOR_H.
##   wall*          origin at the middle of the wall's foot; local +X along the wall (ends at x = +-1.5), +Z the
##                  outside face (a door opens toward -Z, a window's shutters hang on +Z); top at WALL_H.
##   post           origin at the foot of the post's centre.
##   gable          origin at the middle of the top of the wall it stands on; +X along that wall.
##   roof           origin at the centre of the bay on the wall tops; the ridge along +X, eaves toward +-Z.
##   hearth         origin at the middle of its back at floor level; the fire opening faces +Z.
##   palisade*      origin at the middle of the section on the ground; +X along it, -Z the inside (ribband,
##                  the gate leaves swing that way).
##
## Context (`ctx`, worked out from the neighbours by BuildWorld.ctx_for) picks the details that depend on what
## is next to a piece: a wall's two ends ("free" end grain, "corner" saddle-notched log ends past the crossing
## wall, "inline" continued by the next wall, "tee" into a crossing wall, "post" against a corner post), its
## log courses (parity by its direction, so crossing walls alternate like a notched corner) and whether it
## stands on the ground (a fieldstone footing); a floor's shared edges (one sill and no footing between two
## floors); a roof bay's ends (an overhang and barge boards only at the ends of the roof).
## Meshes are cached per type, variant and context (release() drops the cache).

const K := preload("res://scripts/world/structures/structure_mesh_kit.gd")
const VegAssets := preload("res://scripts/world/vegetation/veg_assets.gd")

const L := 3.0                 ## module: wall length, floor cell
const T := 0.3                 ## log wall thickness (the collider)
const COURSE := 0.3            ## log course height
const WALL_H := 2.7            ## nine courses
const FLOOR_H := 0.35          ## floor top over the foundation's origin
const FLOOR_FOOTING := 1.0     ## the floor's fieldstone footing reaches this far below its origin
const FOOTING := 0.7           ## a wall standing on the ground: its stone footing's depth
const POST_SINK := 0.7         ## a post on the ground is set this deep (as deep as a wall's footing)
const PITCH_DEG := 40.0        ## roof and gable pitch
const EAVE_OVER := 0.3         ## eave overhang past the wall's outer face (StructureGeometry.gable_roof's)
const GABLE_OVER := 0.3        ## roof overhang past a gable's face
const LOG_R := 0.155           ## notched log end radius
const CORNER_OUT := 0.25       ## notched log ends stick out this far past the crossing wall's face
const POST_W := 0.36
const DOOR_HALF := 0.5         ## rough opening
const DOOR_TOP := 2.1
const STEP_RISE := 0.18        ## door steps (down to the ground from a raised floor)
const STEP_TREAD := 0.3
const STEP_SLOPE_DEG := 30.0   ## the ramp collider under them
const WIN_HALF := 0.45
const WIN_Y := Vector2(1.05, 1.8)
const STAKES := 8
const STAKE_SINK := 0.4        ## a palisade stake's foot below the ground (its mesh foot is 0.15 below its origin)
const RAIL_Y := 2.7            ## the palisade ribband over the ground
const GATE_POST := 0.46
const GATE_POST_X := 1.27      ## gate post centres
const GATE_LEAF_H := 3.4
const GATE_TOP := 4.6
const HEARTH_W := 1.5
const HEARTH_D := 0.95
const HEARTH_H := 1.5
const HEARTH_TOP := 5.6        ## over the hearth's floor: clear of a roof ridge on a floor
const HEARTH_SINK := 1.0
## Campfire (Campfire): the stone ring's radius; the lean-to's width, the posts' height at the open front, the depth
## to the foot of its slope behind.
const FIRE_R := 0.5
const LEAN_W := 3.0
const LEAN_H := 1.85
const LEAN_D := 2.3
const NO_TRAVERSE := {"no_traverse": true}
## Beds, racks and crafting stations (the build menu's Camp, Furniture and Crafting groups; what they hold and do:
## CampStation, WeaponRack). Origins on the ground or a floor at the middle, the side one works from +Z.
const BED_L := 2.0
const BOUGH_W := 0.9
const POLE_BED_W := 1.0
const POLE_BED_H := 0.45
const RACK_SLOTS := 6
const BARREL_SLOTS := 5
const BARREL_R := 0.24
const BARREL_H := 0.62
const DRY_W := 2.2
const DRY_D := 1.0
const DRY_H := 1.45
const BOAT_L := 5.6
const BOAT_W := 1.4
const TAN_W := 1.8
const TAN_H := 1.9
const TABLE_W := 1.4
const TABLE_D := 0.7
const TABLE_H := 0.8
const BENCH_W := 1.7
const BENCH_D := 0.62
const BENCH_H := 0.78
const HOOP_R := 0.45
const HOOP_Y := 1.05
## The traps (_trap): the sprung snare pole's tip (the catch hangs under it: TrapCatch), the line mark's place by a
## steel trap and a deadfall, and its height.
const SNARE_TIP := Vector3(0.0, 1.95, -0.45)
const TRAP_MARK_STEEL := Vector3(0.32, 0.0, -0.46)
const TRAP_MARK_DEADFALL := Vector3(0.55, 0.0, -0.35)
const TRAP_MARK_H := 1.15
## The knapping stone's boulder (x wide, y high, z deep).
const WORK_STONE := Vector3(0.62, 0.3, 0.46)
## The charcoal mound (a dome of earth over the wood: radius, height) and the forge (the hearth: x wide, y high, z deep;
## the smelting shaft's height at its left end; the anvil stump's place).
const MOUND_R := 0.95
const MOUND_H := 0.85
const FORGE_HEARTH := Vector3(1.3, 0.72, 0.85)
const FORGE_SHAFT_H := 1.45
const FORGE_ANVIL := Vector3(1.25, 0.0, 0.25)
const WOOD_L := 1.8
const WOOD_D := 0.56
const SMOKE_W := 2.0
const SMOKE_D := 1.8
const SMOKE_EAVE := 1.75
const SMOKE_RIDGE := 2.35
const SMOKE_DOOR := Vector2(0.9, 1.55)
const CHEST_W := 0.9
const CHEST_D := 0.5
const CHEST_H := 0.46
const CRADLE_W := 0.5          ## the cradle: across, along (the head at -z) and to the rim
const CRADLE_L := 0.92
const CRADLE_H := 0.42
## The hearth's fire (Campfire in a hearth): where it burns, on the hearthstone in the firebox's mouth, and where its
## smoke comes out, the top of the stack.
const HEARTH_FIRE := Vector3(0, 0.07, HEARTH_D + 0.14)
const HEARTH_SMOKE := Vector3(0, HEARTH_TOP + 0.1, 0.47)

static var _cache := {}
static var _stake_meshes: Array[ArrayMesh] = []


## Drops the cached meshes (BuildWorld._exit_tree; the static cache would otherwise outlive the RenderingServer).
static func release() -> void:
	_cache.clear()
	_stake_meshes.clear()


static func pitch() -> float:
	return deg_to_rad(PITCH_DEG)


## Height of the roof's underside over the wall tops at `d` metres (horizontal) from the ridge line.
static func roof_underside(d: float) -> float:
	return -0.02 + (L * 0.5 + T * 0.5 - absf(d)) * tan(pitch())


## Log course bounds of a wall of parity `p` (0: whole courses from the foot, 1: half a course offset).
static func courses(p: int) -> PackedFloat32Array:
	var b := PackedFloat32Array([0.0])
	if p == 0:
		for k in range(1, 10):
			b.append(k * COURSE)
	else:
		for k in 9:
			b.append(COURSE * 0.5 + k * COURSE)
		b.append(WALL_H)
	return b


## Heights of the log ends a wall of parity `p` shows at a notched corner (its course centres).
static func log_end_heights(p: int) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	if p == 0:
		for k in 9:
			h.append(COURSE * 0.5 + k * COURSE)
	else:
		for k in 8:
			h.append(COURSE + k * COURSE)
	return h


## Course bounds restricted to [y0, y1] (both included); a sliver under 6 cm joins its neighbour.
static func clip_bounds(b: PackedFloat32Array, y0: float, y1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array([y0])
	for v in b:
		if v > y0 + 0.06 and v < y1 - 0.06:
			out.append(v)
	out.append(y1)
	return out


## The parity of a wall turned `yaw` about Y (walls at right angles get different parities).
static func parity_of(yaw: float) -> int:
	return posmod(int(floor((rad_to_deg(yaw) + 45.0) / 90.0)), 2)


# --- Meshes -----------------------------------------------------------------------------------------------

## The piece's mesh (cached unless `cache` is off: a palisade ghost following uneven ground). Palisade stakes are
## separate: stake_mesh() and stake_transforms().
static func mesh(type: String, variant: int, ctx: Dictionary, detail := true, cache := true) -> ArrayMesh:
	var key := "%s|%d|%s|%s" % [type, variant, JSON.stringify(ctx), detail]
	if cache and _cache.has(key):
		return _cache[key]
	var kit := K.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1777 + variant * 7919 + absi(type.hash() % 100000)
	match type:
		"floor":
			_floor(kit, ctx, rng)
		"wall", "wall_window", "wall_door":
			_wall(kit, type, ctx, rng)
		"post":
			_post(kit, ctx, rng)
		"gable":
			_gable(kit, rng)
		"roof":
			_roof(kit, ctx, rng, detail)
		"hearth":
			_hearth(kit, rng)
		"campfire":
			_campfire(kit, rng)
		"lean_to":
			_lean_to(kit, rng)
		"bough_bed":
			_bough_bed(kit, rng)
		"pole_bed":
			_pole_bed(kit, rng)
		"musket_rack":
			_musket_rack(kit, rng)
		"spear_barrel":
			StructureGeometry.barrel(kit, Transform3D(Basis(), Vector3(0, BARREL_H * 0.5, 0)), BARREL_R, BARREL_H, rng, true)
		"drying_rack":
			_drying_rack(kit, rng)
		"tanning_frame":
			_tanning_frame(kit, rng)
		"boat_stand":
			_boat_stand(kit, rng)
		"alchemy_table":
			_alchemy_table(kit, rng)
		"workbench":
			_workbench(kit, rng)
		"stretching_hoop":
			_stretching_hoop(kit, rng)
		"storage_chest":
			_storage_chest(kit, rng, false)
		"cradle":
			_cradle(kit, rng)
		"woodpile":
			_woodpile(kit, rng)
		"smokehouse":
			_smokehouse(kit, rng)
		"palisade":
			_palisade_rail(kit, ctx, rng)
		"palisade_gate":
			_gate_frame(kit, ctx, rng)
		"trap_steel", "trap_snare", "trap_deadfall":
			_trap(kit, type, false, rng)
		"work_stone":
			_work_stone(kit, rng)
		"charcoal_mound":
			_charcoal_mound(kit, rng)
		"forge":
			_forge(kit, rng)
		"walkway", "walkway_ramp", "ladder", "blockhouse", "flagpole":
			FortPieces.mesh(kit, type, rng, detail)
	var m := kit.commit(StructureMaterials.all())
	if cache:
		_cache[key] = m
	return m


## A trap's look (user 2026-09-28, "trapping lines"; TrapStation): set (the piece and its ghost) or sprung (TrapStation
## shows it when the trap has gone off: empty, holding a catch, or buried in snow).
static func trap_mesh(type: String, sprung: bool) -> ArrayMesh:
	var key := "trap|%s|%s" % [type, sprung]
	if _cache.has(key):
		return _cache[key]
	var kit := K.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1777 + absi(type.hash() % 100000)
	_trap(kit, type, sprung, rng)
	var m := kit.commit(StructureMaterials.all())
	_cache[key] = m
	return m


## The mesh of a door or gate leaf: the plank door (`kind` "door") or a gate leaf ("gate_l", "gate_r"), from its
## hinge (the leaf runs along +X for "door" and "gate_l", -X for "gate_r").
static func leaf_mesh(kind: String) -> ArrayMesh:
	var key := "leaf|" + kind
	if _cache.has(key):
		return _cache[key]
	var kit := K.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + absi(kind.hash() % 1000)
	if kind == "door":
		_door_leaf(kit, rng)
	else:
		_gate_leaf(kit, -1.0 if kind == "gate_r" else 1.0, rng)
	var m := kit.commit(StructureMaterials.all())
	_cache[key] = m
	return m


## One of the three palisade log meshes (StructureGeometry.palisade_log, the fort's).
static func stake_mesh(v: int) -> ArrayMesh:
	if _stake_meshes.is_empty():
		for k in 3:
			_stake_meshes.append(StructureGeometry.palisade_log(k, StructureMaterials.all()))
	return _stake_meshes[posmod(v, 3)]


## The stakes of a palisade section: [[variant, Transform3D in the section's frame, custom Color]], each stake set
## STAKE_SINK into the ground under it (`ground`: the ground's height under each stake over the section's origin).
static func stake_transforms(ground: PackedFloat32Array, variant: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001 + variant * 131
	var out: Array = []
	var dx := L / STAKES
	for i in STAKES:
		var g := ground[i] if i < ground.size() else 0.0
		var s := rng.randf_range(0.99, 1.05)
		var b := Basis(Vector3.UP, rng.randf_range(-0.12, 0.12))
		b = Basis(b.x * s, b.y * rng.randf_range(0.97, 1.02), b.z * s)
		var o := Vector3(-L * 0.5 + dx * (i + 0.5), g - STAKE_SINK + 0.15, rng.randf_range(-0.012, 0.012))
		out.append([rng.randi_range(0, 2), Transform3D(b, o),
				Color(rng.randf(), rng.randf(), rng.randf_range(-1.0, 1.0), rng.randf_range(0.0, 0.7))])
	return out


# --- Floor ----------------------------------------------------------------------------------------------

## Sides in the order +X, -X, +Z, -Z; ctx: sill[4] (draw this side's sill), foot[4] (a footing: no floor
## beside it), and the footing's end extents follow from the neighbours.
static func _floor(kit: K, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var sill: Array = ctx.get("sill", [true, true, true, true])
	var foot: Array = ctx.get("foot", [true, true, true, true])
	var ts := 1.0 / StructureGeometry.STONE_TILE
	var h := L * 0.5
	var fy0 := -FLOOR_FOOTING
	var fy1 := 0.12
	# Fieldstone footing under the exterior edges; the X-running ones (+-Z sides) reach round the corners.
	for zi in [2, 3]:
		if not bool(foot[zi]):
			continue
		var sz := 1.0 if zi == 2 else -1.0
		var x0 := -h - (0.18 if bool(foot[1]) else 0.0)
		var x1 := h + (0.18 if bool(foot[0]) else 0.0)
		StructureGeometry._stone_box(kit, Vector3((x0 + x1) * 0.5, (fy0 + fy1) * 0.5, sz * h), Vector3(x1 - x0, fy1 - fy0, 0.36), ts, 8)
	for xi in [0, 1]:
		if not bool(foot[xi]):
			continue
		var sx := 1.0 if xi == 0 else -1.0
		var z0 := -h + (0.18 if bool(foot[3]) else 0.0)
		var z1 := h - (0.18 if bool(foot[2]) else 0.0)
		StructureGeometry._stone_box(kit, Vector3(sx * h, (fy0 + fy1) * 0.5, (z0 + z1) * 0.5), Vector3(0.36, fy1 - fy0, z1 - z0), ts, 8)
	# Hewn sills on the footing (a shared edge's sill belongs to the older floor).
	for i in 4:
		if not bool(sill[i]):
			continue
		var t := rng.randf_range(0.86, 1.04)
		var col := Color(t, t * 0.98, t * 0.95, 1.0)
		if i >= 2:
			var sz := 1.0 if i == 2 else -1.0
			kit.box(&"boards", Transform3D(Basis(), Vector3(0, (fy1 + FLOOR_H - 0.005) * 0.5, sz * h)),
					Vector3(L, FLOOR_H - 0.005 - fy1, T), K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), col, K.KIND_ENDGRAIN, 8, 0.6)
		else:
			var sx := 1.0 if i == 0 else -1.0
			kit.box(&"boards", Transform3D(Basis(), Vector3(sx * h, (fy1 + FLOOR_H - 0.01) * 0.5, 0)),
					Vector3(T, FLOOR_H - 0.01 - fy1, L), K.GRAIN_Z, rng.randi_range(0, 3), rng.randf(), col, K.KIND_ENDGRAIN, 8, 0.6)
	# Puncheon floor: split logs laid across, adzed flat on top, 25 cm wide.
	var n := 12
	var bw := L / n
	for k in n:
		var t := rng.randf_range(0.82, 1.06)
		var z := -h + bw * (k + 0.5)
		kit.box(&"boards", Transform3D(Basis(), Vector3(0, FLOOR_H - 0.03, z)), Vector3(L, 0.06, bw - 0.006), K.GRAIN_X,
				rng.randi_range(0, 3), rng.randf(), Color(t * 0.95, t * 0.92, t * 0.88, 1.0), K.KIND_ENDGRAIN, 8, 0.3)
	# Dark backing under the gaps between the puncheons.
	kit.quad(&"boards", Vector3(-h, FLOOR_H - 0.06, h), Vector3(h, FLOOR_H - 0.06, h), Vector3(h, FLOOR_H - 0.06, -h),
			Vector3(-h, FLOOR_H - 0.06, -h), Vector2(), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
			Color(0.12, 0.11, 0.1, 0.2), K.KIND_TEX, 0.0, PackedColorArray(), Vector3.UP)


# --- Log walls --------------------------------------------------------------------------------------------

static func _wall(kit: K, type: String, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var p := int(ctx.get("p", 0))
	var bounds := courses(p)
	var ends := [String(ctx.get("e0", "free")), String(ctx.get("e1", "free"))]
	var grounded := bool(ctx.get("g", false))
	var h := L * 0.5
	var segs: Array = []
	match type:
		"wall_door":
			segs = [[-h, -DOOR_HALF, 0.0, WALL_H], [DOOR_HALF, h, 0.0, WALL_H], [-DOOR_HALF, DOOR_HALF, DOOR_TOP, WALL_H]]
		"wall_window":
			segs = [[-h, -WIN_HALF, 0.0, WALL_H], [WIN_HALF, h, 0.0, WALL_H], [-WIN_HALF, WIN_HALF, 0.0, WIN_Y.x],
					[-WIN_HALF, WIN_HALF, WIN_Y.y, WALL_H]]
		_:
			segs = [[-h, h, 0.0, WALL_H]]
	for s: Array in segs:
		var b := clip_bounds(bounds, float(s[2]), float(s[3]))
		var xa: float = s[0]
		var xb: float = s[1]
		for side: float in [1.0, -1.0]:
			StructureGeometry.round_log_face(kit, Vector3((xa + xb) * 0.5, 0.0, side * T * 0.5), Vector3(0, 0, side), xb - xa, b, rng)
	# Top of the wall: the flattened top log.
	var tr := rng.randi_range(0, 3)
	kit.quad(&"boards", Vector3(-h, WALL_H, -T * 0.46), Vector3(h, WALL_H, -T * 0.46), Vector3(h, WALL_H, T * 0.46),
			Vector3(-h, WALL_H, T * 0.46), Vector2(0, K.row_v(tr, 0)), Vector2(L, K.row_v(tr, 0)), Vector2(L, K.row_v(tr, 1)),
			Vector2(0, K.row_v(tr, 1)), Color(0.95, 0.93, 0.9, 1.0), K.KIND_TEX, 0.4, PackedColorArray(), Vector3.UP)
	# The ends.
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var e: String = ends[i]
		if e == "corner":
			for y in log_end_heights(p):
				StructureGeometry.log_end(kit, Vector3(sx * (h - 0.2), y, 0.0), Vector3(sx, 0, 0), 0.2 + T * 0.5 + CORNER_OUT, LOG_R, rng)
			_end_cap(kit, sx * h, sx, Color(0.3, 0.28, 0.26, 0.4), K.KIND_TEX)
		elif e == "free":
			for y in log_end_heights(p):
				StructureGeometry.log_end(kit, Vector3(sx * (h - 0.03), y, 0.0), Vector3(sx, 0, 0), 0.09, LOG_R * 0.96, rng)
			_end_cap(kit, sx * h, sx, Color(1, 1, 1, 0.85), K.KIND_ENDGRAIN)
	if grounded:
		var x0 := -_footing_ext(String(ends[0]), p)
		var x1 := _footing_ext(String(ends[1]), p)
		StructureGeometry._stone_box(kit, Vector3((x0 + x1) * 0.5, (-FOOTING + 0.01) * 0.5, 0.0), Vector3(x1 - x0, FOOTING + 0.01, 0.36),
				1.0 / StructureGeometry.STONE_TILE, 8)
	if type == "wall_door":
		_door_frame(kit, rng)
		var st: Array = ctx.get("st", [0.0, 0.0])
		for i in 2:
			_door_steps(kit, float(st[i]), 1.0 if i == 0 else -1.0)
	elif type == "wall_window":
		_window_frame(kit, rng)


static func _footing_ext(e: String, p: int) -> float:
	match e:
		"free":
			return L * 0.5 + 0.02
		"corner":
			return L * 0.5 + (0.18 if p == 0 else -0.18)
	return L * 0.5


## The cross-section at the end x = `x` (outward `sx`): end grain of the cut logs, or a dark backing.
static func _end_cap(kit: K, x: float, sx: float, col: Color, kind: float) -> void:
	var z := T * 0.5 - 0.01
	kit.quad(&"boards", Vector3(x, 0, -z), Vector3(x, 0, z), Vector3(x, WALL_H, z), Vector3(x, WALL_H, -z),
			Vector2(-z, 0), Vector2(z, 0), Vector2(z, WALL_H), Vector2(-z, WALL_H), col, kind, 0.0, PackedColorArray(), Vector3(sx, 0, 0))


static func _door_frame(kit: K, rng: RandomNumberGenerator) -> void:
	var d := T + 0.05
	for sx: float in [-1.0, 1.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx * (DOOR_HALF - 0.03), DOOR_TOP * 0.5, 0)), Vector3(0.06, DOOR_TOP, d),
				K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(0.95, 0.93, 0.9, 1.0), K.KIND_ENDGRAIN)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, DOOR_TOP - 0.03, 0)), Vector3(DOOR_HALF * 2.0, 0.06, d), K.GRAIN_X,
			rng.randi_range(0, 3), rng.randf(), Color(0.95, 0.93, 0.9, 1.0), K.KIND_ENDGRAIN)
	# Threshold: a hewn sill across the opening.
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(DOOR_HALF * 2.0, 0.05, T + 0.06), K.GRAIN_X,
			rng.randi_range(0, 3), rng.randf(), Color(0.85, 0.83, 0.8, 1.0), K.KIND_ENDGRAIN, 8, 0.8)
	# Casing on both faces.
	for side: float in [1.0, -1.0]:
		var z := side * (T * 0.5 + 0.055)
		for sx: float in [-1.0, 1.0]:
			kit.box(&"boards", Transform3D(Basis(), Vector3(sx * (DOOR_HALF + 0.045), (DOOR_TOP + 0.06) * 0.5, z)),
					Vector3(0.1, DOOR_TOP + 0.06, 0.04), K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(1, 1, 1, 1),
					K.KIND_ENDGRAIN, 0, 0.5)
		kit.box(&"boards", Transform3D(Basis(), Vector3(0, DOOR_TOP + 0.08, z)), Vector3(DOOR_HALF * 2.0 + 0.26, 0.12, 0.045),
				K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), Color(1, 1, 1, 1), K.KIND_ENDGRAIN, 0, 0.5)


## Fieldstone steps down from the threshold on the `side` (+1 / -1) face to ground `h` below it (none under
## 8 cm), STEP_RISE high and STEP_TREAD deep, set 20 cm into the ground; the collider is a ramp (door_ramp()).
static func _door_steps(kit: K, h: float, side: float) -> void:
	if h < 0.08:
		return
	var n := maxi(1, int(round(h / STEP_RISE)))
	var rise := h / n
	var ts := 1.0 / StructureGeometry.STONE_TILE
	for k in range(1, n):
		var top := -h + k * rise
		var depth := (n - k) * STEP_TREAD
		var z0 := T * 0.5
		StructureGeometry._stone_box(kit, Vector3(0, (top - h - 0.2) * 0.5, side * (z0 + depth * 0.5)),
				Vector3(DOOR_HALF * 2.0 + 0.3, top + h + 0.2, depth), ts, 8)
	if n == 1:
		# a single sill stone in front
		StructureGeometry._stone_box(kit, Vector3(0, (-h * 0.5 - h - 0.2) * 0.5, side * (T * 0.5 + STEP_TREAD * 0.5)),
				Vector3(DOOR_HALF * 2.0 + 0.3, h * 0.5 + 0.2, STEP_TREAD), ts, 8)


## The walkable ramp under the door steps on the `side` face, `h` down (steps cannot be climbed by the capsule):
## [BoxShape3D, Transform3D] or [] under 8 cm.
static func door_ramp(h: float, side: float) -> Array:
	if h < 0.08:
		return []
	var run := h / tan(deg_to_rad(STEP_SLOPE_DEG))
	var a := atan2(h, run)
	var len := sqrt(run * run + h * h)
	var mid := Vector3(0, -h * 0.5, side * (T * 0.5 + run * 0.5))
	var b := Basis(Vector3.RIGHT, a * side)
	var n := b.y
	return [_box_shape(Vector3(DOOR_HALF * 2.0 + 0.2, 0.1, len + 0.02)), Transform3D(b, mid - n * 0.05)]


static func _window_frame(kit: K, rng: RandomNumberGenerator) -> void:
	var d := T + 0.05
	var hh := WIN_Y.y - WIN_Y.x
	var cy := (WIN_Y.x + WIN_Y.y) * 0.5
	# Linings (the cut log ends inside the opening) and a sill that sheds the rain outward.
	for sx: float in [-1.0, 1.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx * (WIN_HALF - 0.025), cy, 0)), Vector3(0.05, hh, d), K.GRAIN_Y,
				rng.randi_range(0, 3), rng.randf(), Color(0.95, 0.93, 0.9, 1.0), K.KIND_ENDGRAIN)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, WIN_Y.y - 0.025, 0)), Vector3(WIN_HALF * 2.0, 0.05, d), K.GRAIN_X,
			rng.randi_range(0, 3), rng.randf(), Color(0.95, 0.93, 0.9, 1.0), K.KIND_ENDGRAIN)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, WIN_Y.x - 0.02, 0.04)), Vector3(WIN_HALF * 2.0 + 0.16, 0.05, T + 0.14),
			K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), Color(0.9, 0.88, 0.85, 1.0), K.KIND_ENDGRAIN, 0, 0.7)
	# Casing on both faces.
	for side: float in [1.0, -1.0]:
		var z := side * (T * 0.5 + 0.055)
		for sx: float in [-1.0, 1.0]:
			kit.box(&"boards", Transform3D(Basis(), Vector3(sx * (WIN_HALF + 0.04), cy + 0.02, z)), Vector3(0.08, hh + 0.08, 0.04),
					K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(1, 1, 1, 1), K.KIND_ENDGRAIN, 0, 0.5)
		kit.box(&"boards", Transform3D(Basis(), Vector3(0, WIN_Y.y + 0.05, z)), Vector3(WIN_HALF * 2.0 + 0.2, 0.1, 0.045),
				K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), Color(1, 1, 1, 1), K.KIND_ENDGRAIN, 0, 0.5)
	# Two board shutters swung open flat against the outside face, on strap hinges.
	var sw := WIN_HALF + 0.02
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (WIN_HALF + 0.1 + sw * 0.5)
		var z := T * 0.5 + 0.075
		var n := 3
		for i in n:
			var t := rng.randf_range(0.82, 1.0)
			kit.box(&"boards", Transform3D(Basis(), Vector3(cx - sw * 0.5 + sw / n * (i + 0.5), cy, z)), Vector3(sw / n - 0.006, hh + 0.04, 0.035),
					K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(t, t * 0.97, t * 0.93, 1.0), K.KIND_ENDGRAIN)
		for hy: float in [cy - hh * 0.3, cy + hh * 0.3]:
			kit.box(&"boards", Transform3D(Basis(), Vector3(cx, hy, z + 0.022)), Vector3(sw * 0.9, 0.06, 0.01), K.GRAIN_X, 2, 0.1,
					Color(0.9, 0.9, 0.9, 1.0), K.KIND_TEX)
			kit.box(&"boards", Transform3D(Basis(), Vector3(cx - sx * sw * 0.2, hy, z + 0.03)), Vector3(sw * 0.55, 0.035, 0.006),
					K.GRAIN_X, 0, 0.0, Color.WHITE, K.KIND_IRON)


## Plank door on its hinge line: vertical boards from x = 0 to 0.94, battens and a brace on the inside (-Z),
## strap hinges and a latch on the outside (+Z).
static func _door_leaf(kit: K, rng: RandomNumberGenerator) -> void:
	_door_leaf_sized(kit, rng, DOOR_HALF * 2.0 - 0.06, DOOR_TOP - 0.08)


## A plank door leaf `w` wide and `hgt` tall from its hinge (a door hung in the fort's buildings: BuildDoor.make_sized).
static func sized_leaf_mesh(w: float, hgt: float) -> ArrayMesh:
	var key := "leaf|sized|%.3f|%.3f" % [w, hgt]
	if _cache.has(key):
		return _cache[key]
	var kit := K.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + int(w * 100.0) + int(hgt * 10.0)
	_door_leaf_sized(kit, rng, w, hgt)
	var m := kit.commit(StructureMaterials.all())
	_cache[key] = m
	return m


static func _door_leaf_sized(kit: K, rng: RandomNumberGenerator, w: float, hgt: float) -> void:
	var n := maxi(3, int(round(w / 0.19)))
	var bw := w / n
	for i in n:
		var t := rng.randf_range(0.85, 1.05)
		kit.box(&"boards", Transform3D(Basis(), Vector3(bw * (i + 0.5), 0.03 + hgt * 0.5, 0.0)), Vector3(bw - 0.006, hgt, 0.045),
				K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(t * 0.92, t * 0.9, t * 0.88, 1.0), K.KIND_ENDGRAIN)
	for hy: float in [0.35, hgt - 0.3]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(w * 0.5, hy, -0.04)), Vector3(w - 0.08, 0.14, 0.035), K.GRAIN_X,
				rng.randi_range(0, 3), rng.randf(), Color(0.9, 0.88, 0.85, 1.0), K.KIND_ENDGRAIN)
	var a := Vector3(0.1, 0.42, -0.04)
	var b := Vector3(w - 0.1, hgt - 0.37, -0.04)
	var dir := (b - a).normalized()
	kit.box(&"boards", Transform3D(Basis(dir, Vector3.BACK.cross(dir).normalized(), Vector3.BACK), (a + b) * 0.5),
			Vector3(a.distance_to(b), 0.12, 0.03), K.GRAIN_X, 1, 0.3, Color(0.9, 0.88, 0.85, 1.0), K.KIND_ENDGRAIN)
	for hy: float in [0.35, hgt - 0.3]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(w * 0.3, hy, 0.027)), Vector3(w * 0.6, 0.05, 0.008), K.GRAIN_X, 0, 0.0,
				Color.WHITE, K.KIND_IRON)
	kit.box(&"boards", Transform3D(Basis(), Vector3(w - 0.12, hgt * 0.5, 0.03)), Vector3(0.18, 0.035, 0.02), K.GRAIN_X, 0, 0.0,
			Color.WHITE, K.KIND_IRON)


# --- Post, gable, roof ------------------------------------------------------------------------------------

static func _post(kit: K, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var y0 := -POST_SINK if bool(ctx.get("g", false)) else 0.0
	var hgt := WALL_H - y0
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, y0 + hgt * 0.5, 0)), Vector3(POST_W, hgt, POST_W), K.GRAIN_Y,
			rng.randi_range(0, 3), rng.randf(), Color(0.95, 0.93, 0.9, 1.0), K.KIND_ENDGRAIN, 8, 0.0, 0.75)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var t := Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(cx * (POST_W * 0.5 - 0.015), y0 + hgt * 0.5, cz * (POST_W * 0.5 - 0.015)))
			kit.box(&"boards", t, Vector3(0.04, hgt, 0.04), K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(1.05, 1.03, 1.0, 1.0),
					K.KIND_ENDGRAIN, 4 | 8, 1.0)


## Board-clad gable: lapped boards on both faces under the roof's underside line, closed along the rakes.
static func _gable(kit: K, rng: RandomNumberGenerator) -> void:
	var tp := tan(pitch())
	var half := L * 0.5 + T * 0.5
	var top := roof_underside(0.0)
	var bh := 0.24
	for zs: float in [1.0, -1.0]:
		var z := zs * T * 0.5
		var y := 0.0
		while y < top - 0.02:
			var y1 := minf(y + bh, top)
			var xa := half - (y + 0.02) / tp
			var xb := maxf(half - (y1 + 0.02) / tp, 0.0)
			var row := rng.randi_range(0, 3)
			var u0 := rng.randf()
			var tint := rng.randf_range(0.86, 1.06)
			var cl := Color(tint, tint, tint, 1.0)
			var chh := Color(tint, tint, tint, 0.72)
			var lap := 0.014 * zs
			kit.quad(&"boards", Vector3(-xa, y, z + lap), Vector3(xa, y, z + lap), Vector3(xb, y1, z), Vector3(-xb, y1, z),
					Vector2(-xa + u0, K.row_v(row, 0)), Vector2(xa + u0, K.row_v(row, 0)), Vector2(xb + u0, K.row_v(row, 1)),
					Vector2(-xb + u0, K.row_v(row, 1)), cl, K.KIND_TEX, 0.0, PackedColorArray([cl, cl, chh, chh]), Vector3(0, 0, zs))
			kit.quad(&"boards", Vector3(-xa, y, z), Vector3(xa, y, z), Vector3(xa, y, z + lap), Vector3(-xa, y, z + lap),
					Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.01), Vector2(0, 0.01), Color(tint, tint, tint, 0.6), K.KIND_TEX, 1.0,
					PackedColorArray(), Vector3.DOWN)
			y = y1
	# The rakes (under the roof) closed with boards.
	for sx: float in [-1.0, 1.0]:
		var a := Vector3(sx * half, -0.02, -T * 0.5)
		var b := Vector3(sx * half, -0.02, T * 0.5)
		var c := Vector3(0, top, T * 0.5)
		var d := Vector3(0, top, -T * 0.5)
		var r := rng.randi_range(0, 3)
		kit.quad(&"boards", a, b, c, d, Vector2(0, K.row_v(r, 0)), Vector2(0, K.row_v(r, 1)), Vector2(half, K.row_v(r, 1)),
				Vector2(half, K.row_v(r, 0)), Color(0.8, 0.78, 0.75, 0.7), K.KIND_TEX, 0.0, PackedColorArray(), Vector3(sx * tp, 1, 0))


## One bay of the gable roof (StructureGeometry.gable_roof, the fort cabin's roof): eaves resting on the outer
## faces of the two wall tops, 0.3 m eaves; ctx o0 / o1: the overhang past the -X / +X end (none where the next
## bay continues the roof). Frieze boards close the triangle between each wall top and the roof inside.
static func _roof(kit: K, ctx: Dictionary, rng: RandomNumberGenerator, detail: bool) -> void:
	var p := pitch()
	var s := (EAVE_OVER - 0.06 * sin(p)) / cos(p)
	var cy := -0.02 - s * sin(p) + 0.06 * cos(p)
	var over := Vector2(float(ctx.get("o0", T * 0.5 + GABLE_OVER)), float(ctx.get("o1", T * 0.5 + GABLE_OVER)))
	StructureGeometry.gable_roof(kit, Vector3(0, cy, 0), L + T, L, PITCH_DEG, PI * 0.5, rng, detail, false, over)
	var yu := roof_underside(L * 0.5 - T * 0.5)
	for sz: float in [1.0, -1.0]:
		var zf := sz * (L * 0.5 - T * 0.5)
		var r := rng.randi_range(0, 3)
		kit.quad(&"boards", Vector3(-L * 0.5, 0, zf), Vector3(L * 0.5, 0, zf), Vector3(L * 0.5, yu, zf), Vector3(-L * 0.5, yu, zf),
				Vector2(0, K.row_v(r, 0)), Vector2(L, K.row_v(r, 0)), Vector2(L, K.row_v(r, 1)), Vector2(0, K.row_v(r, 1)),
				Color(0.85, 0.83, 0.8, 0.75), K.KIND_TEX, 0.0, PackedColorArray(), Vector3(0, 0, -sz))


# --- Hearth and chimney -----------------------------------------------------------------------------------

## A campfire: a ring of fieldstones, an ash bed, split wood laid in a cone (lit by Campfire). Origin at the ring's
## centre on the ground.
static func _campfire(kit: K, rng: RandomNumberGenerator) -> void:
	var n := 11
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.12, 0.12)
		var r := FIRE_R + rng.randf_range(-0.04, 0.05)
		var sz := Vector3(rng.randf_range(0.18, 0.26), rng.randf_range(0.11, 0.17), rng.randf_range(0.14, 0.2))
		var b := Basis(Vector3.UP, -a + rng.randf_range(-0.3, 0.3)) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
		var t := rng.randf_range(0.72, 0.95)
		kit.box(&"stone", Transform3D(b, Vector3(cos(a) * r, sz.y * 0.4, sin(a) * r)), sz, K.GRAIN_X, rng.randi_range(0, 3),
				rng.randf(), Color(t, t * 0.98, t * 0.95, 1.0))
	# the ash bed, dark and a little charred on the stones' inner faces
	kit.box(&"stone", Transform3D(Basis(), Vector3(0, 0.012, 0)), Vector3(FIRE_R * 1.7, 0.024, FIRE_R * 1.7), K.GRAIN_X, 0,
			0.3, Color(0.16, 0.15, 0.14, 1.0))
	# split wood in a cone over a little kindling
	var sticks := 6
	for i in sticks:
		var a := TAU * i / sticks + rng.randf_range(-0.15, 0.15)
		var foot := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.26, 0.32)
		var top := Vector3(0, 0.46, 0) + Vector3(cos(a), 0, sin(a)) * 0.04
		var mid := (foot + top) * 0.5
		var dir := (top - foot).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var b := Basis(side, dir, side.cross(dir))
		var t := rng.randf_range(0.8, 1.0)
		kit.box(&"bark", Transform3D(b, mid + Vector3.UP * 0.02), Vector3(0.07, foot.distance_to(top) + 0.06, 0.06), K.GRAIN_X,
				rng.randi_range(0, 3), rng.randf(), Color(t, t, t, 1.0))
	for i in 5:
		var a := rng.randf() * TAU
		kit.box(&"boards", Transform3D(Basis(Vector3.UP, a), Vector3(0, 0.035, 0)), Vector3(0.3, 0.025, 0.03), K.GRAIN_X,
				0, rng.randf(), Color(0.7, 0.62, 0.5, 1.0))


# --- Beds, racks and stations ---------------------------------------------------------------------------------

## A round pole from `a` to `b` (a squared bark box along it: the lean-to's way), `r` thick.
static func _pole_between(kit: K, a: Vector3, b: Vector3, r: float, rng: RandomNumberGenerator, key := &"bark") -> void:
	var d := b - a
	var dir := d.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 1e-4:
		side = Vector3.RIGHT
	side = side.normalized()
	var bs := Basis(side, dir.cross(side).normalized(), dir)
	var t := rng.randf_range(0.82, 1.0)
	kit.box(key, Transform3D(bs, (a + b) * 0.5), Vector3(r * 2.0, r * 2.0, d.length()), K.GRAIN_Z, rng.randi_range(0, 3),
			rng.randf(), Color(t, t, t, 1.0))


## Hemlock and balsam boughs laid thick between two side logs and a head log, shingled butt-down from the foot.
static func _bough_bed(kit: K, rng: RandomNumberGenerator) -> void:
	var hw := BOUGH_W * 0.5
	for sx: float in [-1.0, 1.0]:
		_pole_between(kit, Vector3(sx * (hw + 0.05), 0.07, -BED_L * 0.5), Vector3(sx * (hw + 0.05), 0.07, BED_L * 0.5), 0.07, rng)
	_pole_between(kit, Vector3(-hw - 0.1, 0.09, -BED_L * 0.5 - 0.05), Vector3(hw + 0.1, 0.09, -BED_L * 0.5 - 0.05), 0.09, rng)
	var rows := 9
	for r in rows:
		var z := BED_L * 0.5 - 0.12 - (BED_L - 0.2) * r / (rows - 1)
		for c in 3:
			var x := (c - 1) * 0.28 + rng.randf_range(-0.04, 0.04)
			var g := rng.randf_range(0.8, 1.05)
			var col := Color(0.26 * g, 0.4 * g, 0.22 * g, 1.0)
			var b := Basis(Vector3.UP, rng.randf_range(-0.35, 0.35)) * Basis(Vector3.RIGHT, -0.18)
			kit.box(&"straw", Transform3D(b, Vector3(x, 0.1 + 0.012 * (r % 2), z)), Vector3(0.36, 0.05, 0.42), K.GRAIN_Z,
					rng.randi_range(0, 3), rng.randf(), col)


## A frame of poles on four short legs, two side rails and two end rails, a straw tick on it (the hide over it:
## CampStation), a head pole raised at the head.
static func _pole_bed(kit: K, rng: RandomNumberGenerator) -> void:
	var hw := POLE_BED_W * 0.5 - 0.04
	var hl := BED_L * 0.5 - 0.04
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			StructureGeometry.pole(kit, Vector3(sx * hw, 0, sz * hl), 0.0, POLE_BED_H - 0.02 + (0.3 if sz < 0.0 else 0.0), 0.05, 0.045, rng)
		_pole_between(kit, Vector3(sx * hw, POLE_BED_H - 0.08, -hl - 0.06), Vector3(sx * hw, POLE_BED_H - 0.08, hl + 0.06), 0.05, rng)
	for sz: float in [-1.0, 1.0]:
		_pole_between(kit, Vector3(-hw - 0.06, POLE_BED_H - 0.13, sz * hl), Vector3(hw + 0.06, POLE_BED_H - 0.13, sz * hl), 0.045, rng)
	_pole_between(kit, Vector3(-hw - 0.06, POLE_BED_H + 0.22, -hl), Vector3(hw + 0.06, POLE_BED_H + 0.22, -hl), 0.045, rng)
	kit.box(&"straw", Transform3D(Basis(), Vector3(0, POLE_BED_H - 0.02, 0)), Vector3(POLE_BED_W - 0.1, 0.1, BED_L - 0.1), K.GRAIN_Z,
			rng.randi_range(0, 3), rng.randf(), Color(0.86, 0.8, 0.64, 1.0))


## A musket rack for RACK_SLOTS long guns, on WeaponRack's own layout ("rack": butts in a trough at the front, the
## barrels against a notched rail behind): two posts on feet, the rail, a brace, the trough.
static func _musket_rack(kit: K, rng: RandomNumberGenerator) -> void:
	var span := WeaponRack.rack_span(RACK_SLOTS)
	for sx: float in [-1.0, 1.0]:
		StructureGeometry.pole(kit, Vector3(sx * span * 0.5, 0, -0.12), 0.0, 1.25, 0.045, 0.04, rng)
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx * span * 0.5, 0.04, -0.06)), Vector3(0.08, 0.08, 0.5), K.GRAIN_Z,
				rng.randi_range(0, 3), rng.randf())
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 1.08, -0.12)), Vector3(span, 0.06, 0.08), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
	for i in RACK_SLOTS + 1:
		var x := -span * 0.5 + 0.2 - 0.14 + 0.28 * i
		kit.box(&"boards", Transform3D(Basis(), Vector3(x, 1.13, -0.1)), Vector3(0.04, 0.05, 0.1), K.GRAIN_Y, 0, rng.randf())
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.55, -0.12)), Vector3(span, 0.05, 0.05), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.05, 0.0)), Vector3(span, 0.06, 0.22), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
	for sz: float in [-1.0, 1.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.1, sz * 0.1)), Vector3(span, 0.08, 0.025), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())


## A drying rack: four forked posts, two rails along it, thin cross sticks the meat strips hang from (CampStation).
static func _drying_rack(kit: K, rng: RandomNumberGenerator) -> void:
	var hx := DRY_W * 0.5 - 0.05
	var hz := DRY_D * 0.5 - 0.05
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			StructureGeometry.pole(kit, Vector3(sx * hx, 0, sz * hz), 0.0, DRY_H - 0.04, 0.045, 0.035, rng)
	for sz: float in [-1.0, 1.0]:
		_pole_between(kit, Vector3(-hx - 0.06, DRY_H - 0.02, sz * hz), Vector3(hx + 0.06, DRY_H - 0.02, sz * hz), 0.035, rng)
	for i in 7:
		var x := -hx + 0.15 + (2.0 * hx - 0.3) * i / 6.0 + rng.randf_range(-0.03, 0.03)
		_pole_between(kit, Vector3(x, DRY_H + 0.0, -hz - 0.08), Vector3(x, DRY_H + 0.0, hz + 0.08), 0.015, rng)


## A tanning frame: two uprights, a top and a bottom bar the hide is laced between (CampStation lays the hide in),
## two props behind; beside it the fleshing beam, a hewn log slanting from the ground onto two short legs.
## A boat stand: two barked skids the length of the hull on a low bed of gravel logs, crossed by chocks the keel rests on.
static func _boat_stand(kit: K, rng: RandomNumberGenerator) -> void:
	var hz := BOAT_L * 0.5
	for sx: float in [-1.0, 1.0]:
		_pole_between(kit, Vector3(sx * 0.42, 0.1, -hz), Vector3(sx * 0.42, 0.1, hz), 0.08, rng)
	for k in 6:
		var z := -hz + 0.5 + (BOAT_L - 1.0) * float(k) / 5.0
		_pole_between(kit, Vector3(-0.62, 0.05, z), Vector3(0.62, 0.05, z), 0.05, rng)


static func _tanning_frame(kit: K, rng: RandomNumberGenerator) -> void:
	var hx := TAN_W * 0.5
	for sx: float in [-1.0, 1.0]:
		StructureGeometry.pole(kit, Vector3(sx * hx * 0.9, 0, 0), 0.0, TAN_H - 0.1, 0.055, 0.045, rng)
		_pole_between(kit, Vector3(sx * hx * 0.9, TAN_H * 0.75, -0.02), Vector3(sx * hx * 0.9, 0.0, -0.75), 0.035, rng)
	_pole_between(kit, Vector3(-hx * 0.9 - 0.06, TAN_H - 0.12, 0.0), Vector3(hx * 0.9 + 0.06, TAN_H - 0.12, 0.0), 0.045, rng)
	_pole_between(kit, Vector3(-hx * 0.9 - 0.06, 0.28, 0.0), Vector3(hx * 0.9 + 0.06, 0.28, 0.0), 0.045, rng)
	# the fleshing beam, front right: a barked log from the ground up onto two short crossed legs
	var bx := hx + 0.45
	_pole_between(kit, Vector3(bx, 0.06, 1.0), Vector3(bx, 0.92, -0.45), 0.09, rng)
	for sx: float in [-1.0, 1.0]:
		_pole_between(kit, Vector3(bx + sx * 0.22, 0.0, -0.3), Vector3(bx - sx * 0.04, 0.84, -0.32), 0.03, rng)


## An herbalist's bench: a plank top on four legs with a stretcher, a shelf under it, a crossbar on two posts at the
## back for the herbs to hang from (the crocks, the mortar and the herbs: CampStation).
static func _alchemy_table(kit: K, rng: RandomNumberGenerator) -> void:
	var hx := TABLE_W * 0.5 - 0.06
	var hz := TABLE_D * 0.5 - 0.06
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, TABLE_H - 0.03, 0)), Vector3(TABLE_W, 0.06, TABLE_D), K.GRAIN_X,
			rng.randi_range(0, 3), rng.randf())
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kit.box(&"hewn_mm", Transform3D(Basis(), Vector3(sx * hx, (TABLE_H - 0.06) * 0.5, sz * hz)), Vector3(0.07, TABLE_H - 0.06, 0.07),
					K.GRAIN_Y, rng.randi_range(0, 3), rng.randf())
		kit.box(&"hewn_mm", Transform3D(Basis(), Vector3(sx * hx, 0.18, 0)), Vector3(0.05, 0.05, TABLE_D - 0.12), K.GRAIN_Z, 0, rng.randf())
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(TABLE_W - 0.12, 0.03, TABLE_D - 0.16), K.GRAIN_X,
			rng.randi_range(0, 3), rng.randf())
	for sx: float in [-1.0, 1.0]:
		StructureGeometry.pole(kit, Vector3(sx * hx, TABLE_H, -hz - 0.02), 0.0, 0.7, 0.03, 0.025, rng)
	_pole_between(kit, Vector3(-hx - 0.03, TABLE_H + 0.71, -hz - 0.02), Vector3(hx + 0.03, TABLE_H + 0.71, -hz - 0.02), 0.022, rng)


## A workbench: a thick plank top on four splayed legs, a stretcher, a shelf of a board under it (the tools and the
## work on it: CampStation).
static func _workbench(kit: K, rng: RandomNumberGenerator) -> void:
	var hx := BENCH_W * 0.5 - 0.1
	var hz := BENCH_D * 0.5 - 0.08
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, BENCH_H - 0.045, 0)), Vector3(BENCH_W, 0.09, BENCH_D), K.GRAIN_X,
			rng.randi_range(0, 3), rng.randf())
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var foot := Vector3(sx * (hx + 0.06), 0.0, sz * (hz + 0.05))
			var top := Vector3(sx * hx, BENCH_H - 0.09, sz * hz)
			_pole_between(kit, foot, top, 0.045, rng, &"hewn_mm")
		kit.box(&"hewn_mm", Transform3D(Basis(), Vector3(sx * hx, 0.22, 0)), Vector3(0.06, 0.06, BENCH_D - 0.1), K.GRAIN_Z, 0, rng.randf())
	kit.box(&"hewn_mm", Transform3D(Basis(), Vector3(0, 0.22, 0)), Vector3(BENCH_W - 0.26, 0.06, 0.06), K.GRAIN_X, 0, rng.randf())
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.27, 0)), Vector3(BENCH_W - 0.3, 0.03, BENCH_D - 0.2), K.GRAIN_X,
			rng.randi_range(0, 3), rng.randf())
	# a bench vice: a jaw and its screw at the front left
	kit.box(&"hewn_mm", Transform3D(Basis(), Vector3(-hx + 0.12, BENCH_H - 0.16, BENCH_D * 0.5 + 0.03)), Vector3(0.22, 0.26, 0.06), K.GRAIN_Y, 0, rng.randf())
	kit.box(&"boards", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-hx + 0.12, BENCH_H - 0.12, BENCH_D * 0.5 + 0.12)),
			Vector3(0.035, 0.035, 0.2), K.GRAIN_Y, 0, 0.0, Color(0.3, 0.3, 0.3, 1.0), K.KIND_IRON)


## A woodpile's frame: two poles on the ground to keep the wood off it, a pair of stakes at each end to hold the stack
## (the split wood on it: Woodpile).
static func _woodpile(kit: K, rng: RandomNumberGenerator) -> void:
	var hx := WOOD_L * 0.5
	for sz: float in [-1.0, 1.0]:
		_pole_between(kit, Vector3(-hx - 0.05, 0.05, sz * WOOD_D * 0.3), Vector3(hx + 0.05, 0.05, sz * WOOD_D * 0.3), 0.045, rng)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			StructureGeometry.pole(kit, Vector3(sx * (hx + 0.06), 0, sz * WOOD_D * 0.5), 0.0, 1.0, 0.035, 0.028, rng)


## A smokehouse: bark slab walls on a pole frame, a doorway in the front, a bark roof with a smoke gap along the ridge,
## a ring of stones for the smudge fire in the floor (its fire, the meat hung in it and the larder: Smokehouse).
static func _smokehouse(kit: K, rng: RandomNumberGenerator) -> void:
	var hx := SMOKE_W * 0.5
	var hz := SMOKE_D * 0.5
	var t := 0.06
	# the corner posts
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			StructureGeometry.pole(kit, Vector3(sx * (hx - 0.04), 0, sz * (hz - 0.04)), 0.0, SMOKE_EAVE, 0.05, 0.045, rng)
	var col := func() -> Color:
		var k := rng.randf_range(0.8, 1.02)
		return Color(k, k, k, 1.0)
	# back and sides: bark slabs standing
	for i in 6:
		var w := SMOKE_W / 6.0
		kit.box(&"bark", Transform3D(Basis(), Vector3(-hx + w * (i + 0.5), SMOKE_EAVE * 0.5, -hz)), Vector3(w + 0.02, SMOKE_EAVE, t), K.GRAIN_Y,
				rng.randi_range(0, 3), rng.randf(), col.call())
	for sx: float in [-1.0, 1.0]:
		for i in 5:
			var d := SMOKE_D / 5.0
			kit.box(&"bark", Transform3D(Basis(), Vector3(sx * hx, SMOKE_EAVE * 0.5, -hz + d * (i + 0.5))), Vector3(t, SMOKE_EAVE, d + 0.02), K.GRAIN_Y,
					rng.randi_range(0, 3), rng.randf(), col.call())
	# the front, the doorway in its middle
	var dw := SMOKE_DOOR.x * 0.5
	for sx: float in [-1.0, 1.0]:
		var w := hx - dw
		kit.box(&"bark", Transform3D(Basis(), Vector3(sx * (dw + w * 0.5), SMOKE_EAVE * 0.5, hz)), Vector3(w, SMOKE_EAVE, t), K.GRAIN_Y,
				rng.randi_range(0, 3), rng.randf(), col.call())
	kit.box(&"bark", Transform3D(Basis(), Vector3(0, (SMOKE_DOOR.y + SMOKE_EAVE) * 0.5, hz)), Vector3(SMOKE_DOOR.x, SMOKE_EAVE - SMOKE_DOOR.y, t),
			K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), col.call())
	# the gables and the roof: two slopes of bark, a gap along the ridge for the smoke
	for sz: float in [-1.0, 1.0]:
		for i in 3:
			var y0 := SMOKE_EAVE + (SMOKE_RIDGE - SMOKE_EAVE) * i / 3.0
			var wd := SMOKE_W * (1.0 - float(i) / 3.0)
			kit.box(&"bark", Transform3D(Basis(), Vector3(0, y0 + (SMOKE_RIDGE - SMOKE_EAVE) / 6.0, sz * hz)), Vector3(wd, (SMOKE_RIDGE - SMOKE_EAVE) / 3.0, t),
					K.GRAIN_X, rng.randi_range(0, 3), rng.randf(), col.call())
	var slope := Vector2(hx + 0.15, SMOKE_RIDGE - SMOKE_EAVE)
	var ang := atan2(slope.y, slope.x)
	for sx: float in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, sx * -ang)
		var c := Vector3(sx * (hx + 0.15) * 0.5 + sx * 0.06, (SMOKE_EAVE + SMOKE_RIDGE) * 0.5 - 0.03, 0)
		kit.box(&"bark", Transform3D(b, c), Vector3(slope.length() - 0.12, 0.05, SMOKE_D + 0.3), K.GRAIN_Z, rng.randi_range(0, 3), rng.randf(), col.call())
	_pole_between(kit, Vector3(0, SMOKE_RIDGE + 0.08, -hz - 0.15), Vector3(0, SMOKE_RIDGE + 0.08, hz + 0.15), 0.04, rng)
	# the smudge pit's stones
	for i in 8:
		var a := TAU * i / 8.0
		kit.box(&"stone", Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.3, 0.05, sin(a) * 0.3)), Vector3(0.14, 0.1, 0.12), K.GRAIN_X,
				rng.randi_range(0, 3), rng.randf())


## A stretching hoop: a sapling bent into a ring (bark segments) lashed to a stake driven in the ground, a prop behind.
static func _stretching_hoop(kit: K, rng: RandomNumberGenerator) -> void:
	StructureGeometry.pole(kit, Vector3(0, 0, -0.04), 0.0, HOOP_Y + HOOP_R + 0.12, 0.04, 0.03, rng)
	var n := 16
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * HOOP_R, HOOP_Y + sin(a0) * HOOP_R, 0.0)
		var p1 := Vector3(cos(a1) * HOOP_R, HOOP_Y + sin(a1) * HOOP_R, 0.0)
		_pole_between(kit, p0, p1 + (p1 - p0) * 0.08, 0.02, rng)
	_pole_between(kit, Vector3(0, HOOP_Y + 0.3, -0.03), Vector3(0, 0.0, -0.7), 0.025, rng)


## The traps (+Z toward the run's far side; the ground at y 0):
##   trap_steel     a long-spring steel trap: the jaws open flat round the pan, the spring out to one side, the chain to a
##                  stake driven in; sprung, the jaws stand shut
##   trap_snare     a spring-pole snare: a sapling bent over and held by the trigger peg, the noose hanging over the run;
##                  sprung, the pole springs up, still leaning over the run, the noose hanging from its tip
##   trap_deadfall  a Smith-type deadfall: a log propped over the bait between two stakes on a figure-four trigger;
##                  sprung, the log lies down flat between the stakes
## The steel trap and the deadfall have the trapper's line mark by them (a stick with a strip of red cloth: TRAP_MARK),
## to find them again in the grass; the ground under each is cleared (its colliders: the trap's bed).
static func _trap(kit: K, type: String, sprung: bool, rng: RandomNumberGenerator) -> void:
	var iron := Color(0.2, 0.19, 0.18, 1.0)
	var cord := Color(0.72, 0.62, 0.45, 1.0)
	match type:
		"trap_steel":
			StructureGeometry.pole(kit, Vector3(0.0, 0.0, -0.42), -0.25, 0.14, 0.025, 0.02, rng, false)
			_trap_mark(kit, TRAP_MARK_STEEL, rng)
			for i in 5:
				var z := -0.38 + i * 0.07
				kit.box(&"boards", Transform3D(Basis(Vector3.FORWARD, PI * 0.5 * (i % 2)), Vector3(0.0, 0.012, z)),
						Vector3(0.012, 0.012, 0.05), K.GRAIN_Z, 0, 0.0, iron, K.KIND_IRON)
			var n := 14
			var r := 0.075
			for i in n:
				var a0 := TAU * i / n
				var a1 := TAU * (i + 1) / n
				var p0: Vector3
				var p1: Vector3
				if sprung:
					# shut: the two jaws standing up, meeting over the pan
					p0 = Vector3(cos(a0) * r, 0.012 + r + sin(a0) * r, 0.0)
					p1 = Vector3(cos(a1) * r, 0.012 + r + sin(a1) * r, 0.0)
				else:
					p0 = Vector3(cos(a0) * r, 0.012, sin(a0) * r * 0.85)
					p1 = Vector3(cos(a1) * r, 0.012, sin(a1) * r * 0.85)
				var mid := (p0 + p1) * 0.5
				var d := p1 - p0
				var bs := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
				kit.box(&"boards", Transform3D(bs, mid), Vector3(0.011, 0.011, d.length() + 0.004), K.GRAIN_Z, 0, 0.0, iron, K.KIND_IRON)
			kit.box(&"boards", Transform3D(Basis(), Vector3(0.0, 0.005, 0.0)), Vector3(0.2, 0.008, 0.02), K.GRAIN_X, 0, 0.0, iron, K.KIND_IRON)
			if not sprung:
				kit.box(&"boards", Transform3D(Basis(), Vector3(0.0, 0.014, 0.0)), Vector3(0.05, 0.005, 0.05), K.GRAIN_X, 0, 0.0, iron, K.KIND_IRON)
			kit.box(&"boards", Transform3D(Basis(), Vector3(0.0, 0.012, 0.16)), Vector3(0.016, 0.014, 0.17), K.GRAIN_Z, 0, 0.0, iron, K.KIND_IRON)
		"trap_snare":
			# the peg the pole's cord is hooked under, over the run
			StructureGeometry.pole(kit, Vector3(0.0, 0.0, 0.0), -0.15, 0.14, 0.018, 0.014, rng, false)
			var base := Vector3(0.0, 0.0, -1.3)
			if sprung:
				# up in two lengths, still leaning over the run; the cord from the tip, the noose shut at its end
				var knee := base + Vector3(0.0, 1.1, 0.3)
				_pole_between(kit, base, knee, 0.024, rng)
				_pole_between(kit, knee, SNARE_TIP, 0.016, rng)
				kit.box(&"boards", Transform3D(Basis(), SNARE_TIP - Vector3(0.0, 0.25, 0.0)), Vector3(0.006, 0.5, 0.006), K.GRAIN_Y, 0, 0.0, cord, K.KIND_CLAY)
			else:
				# bent over in an arc to the peg
				var prev := base
				for i in range(1, 9):
					var k := float(i) / 8.0
					var p := base.lerp(Vector3(0.0, 0.0, -0.05), k) + Vector3.UP * sin(k * PI * 0.62) * 0.9 * (1.0 - k * 0.55)
					_pole_between(kit, prev, p, 0.024 - k * 0.012, rng)
					prev = p
				kit.box(&"boards", Transform3D(Basis(), Vector3(0.0, 0.08, -0.03)), Vector3(0.006, 0.16, 0.006), K.GRAIN_Y, 0, 0.0, cord, K.KIND_CLAY)
				_noose(kit, Vector3(0.0, 0.14, 0.12), cord)
		"trap_deadfall":
			for sx: float in [-0.28, 0.28]:
				StructureGeometry.pole(kit, Vector3(sx, 0.0, 0.0), -0.2, 0.42, 0.025, 0.02, rng, false)
			_trap_mark(kit, TRAP_MARK_DEADFALL, rng)
			if sprung:
				_pole_between(kit, Vector3(-0.75, 0.07, 0.08), Vector3(0.75, 0.07, 0.08), 0.075, rng)
			else:
				# the log propped: its near end on the ground, its far end up on the figure-four
				_pole_between(kit, Vector3(-0.75, 0.07, 0.08), Vector3(0.75, 0.4, 0.08), 0.075, rng)
				_pole_between(kit, Vector3(0.45, 0.0, 0.1), Vector3(0.45, 0.3, 0.1), 0.012, rng)
				_pole_between(kit, Vector3(0.3, 0.18, 0.1), Vector3(0.62, 0.34, 0.1), 0.01, rng)
				_pole_between(kit, Vector3(0.1, 0.06, 0.1), Vector3(0.5, 0.2, 0.1), 0.01, rng)


## A knapping stone (the start with nothing): the flakes littered round its foot (the boulder, the hammerstone and the
## chert being worked are work_stone_parts(), the level's own rock and ForageModels' stones).
static func _work_stone(kit: K, rng: RandomNumberGenerator) -> void:
	for i in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(WORK_STONE.x * 0.55, WORK_STONE.x * 0.95)
		kit.box(&"stone", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)),
				Vector3(cos(a) * r, 0.006, sin(a) * r * 0.8)), Vector3(rng.randf_range(0.02, 0.04), 0.005, rng.randf_range(0.015, 0.03)),
				K.GRAIN_X, 0, rng.randf(), Color(0.28, 0.28, 0.3, 1.0))


## The knapping stone's boulder and what lies on it: [[mesh, transform, material (null: the mesh's own)]]. The boulder
## is the level's mossy rock (VegAssets rock_a) scaled to WORK_STONE, sunk a little; beside it on the ground a round
## hammerstone, a chert core half knapped and the flakes (ForageModels' stone shapes).
static func work_stone_parts() -> Array:
	var out := []
	var rock := VegAssets.prop_mesh(VegAssets.ROCK_FIRST, 0)
	if rock:
		var bb := rock.get_aabb()
		var sc := Vector3(WORK_STONE.x / maxf(bb.size.x, 0.01), (WORK_STONE.y + 0.06) / maxf(bb.size.y, 0.01), WORK_STONE.z / maxf(bb.size.z, 0.01))
		var xf := Transform3D(Basis().scaled(sc), Vector3(-bb.get_center().x * sc.x, -bb.position.y * sc.y - 0.06, -bb.get_center().z * sc.z))
		out.append([rock, xf, VegAssets.prop_material(VegAssets.ROCK_FIRST)])
	if not _cache.has("work_stone_top"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1768
		# beside the boulder, on the ground where the knapper sits: the hammerstone, a chert core half worked, the flakes
		var x0 := WORK_STONE.x * 0.5 + 0.12
		ForageModels._stone(st, Vector3(x0, 0.03, 0.12), 0.05, Vector3(1.1, 0.75, 0.95), Color(0.26, 0.23, 0.19), rng)
		ForageModels._stone(st, Vector3(x0 + 0.05, 0.022, -0.06), 0.045, Vector3(1.3, 0.6, 0.9), Color(0.27, 0.24, 0.2), rng)
		ForageModels._stone(st, Vector3(x0 + 0.05, 0.042, -0.06), 0.028, Vector3(1.0, 0.5, 0.9), Color(0.1, 0.09, 0.085), rng)
		for k in 7:
			ForageModels._stone(st, Vector3(x0 + rng.randf_range(-0.08, 0.16), 0.004, rng.randf_range(-0.2, 0.2)), 0.014,
					Vector3(1.4, 0.25, 1.0), Color(0.12, 0.11, 0.1), rng)
		var m := st.commit()
		m.surface_set_material(0, ForageModels.matte_material())
		_cache["work_stone_top"] = m
	out.append([_cache["work_stone_top"], Transform3D(), null])
	return out


## A charcoal mound (the collier's pit, built on the ground): the earth dome is charcoal_parts(); here a few ends of the
## stacked wood at its foot where the earth has slipped.
static func _charcoal_mound(kit: K, rng: RandomNumberGenerator) -> void:
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf_range(-0.3, 0.3)
		var r := MOUND_R * 0.96
		StructureGeometry.log_end(kit, Vector3(cos(a) * r, 0.06, sin(a) * r), Vector3(cos(a), -0.1, sin(a)).normalized(), 0.12, 0.04, rng)


## A bloomery forge (the start with nothing's metal): a waist-high hearth of fieldstone with its firepot, a clay-lined
## smelting shaft at its left end, bag bellows of hide at the back, and a stump with a flat stone anvil, the hammer on it.
static func _forge(kit: K, rng: RandomNumberGenerator) -> void:
	var hx := FORGE_HEARTH.x * 0.5
	var hz := FORGE_HEARTH.z * 0.5
	var ts := 1.0 / StructureGeometry.STONE_TILE
	StructureGeometry._stone_box(kit, Vector3(0, FORGE_HEARTH.y * 0.5, 0), FORGE_HEARTH, ts, 0)
	# the firepot: charcoal and ash sunk in the top
	kit.box(&"stone", Transform3D(Basis(), Vector3(0.18, FORGE_HEARTH.y + 0.005, 0.02)), Vector3(0.5, 0.02, 0.42), K.GRAIN_X, 0, 0.3,
			Color(0.1, 0.09, 0.08, 1.0))
	# the great bellows' frame at the back: two posts, the lever's pivot bar (the bellows is forge_parts())
	for sx: float in [-0.35, 0.35]:
		StructureGeometry.pole(kit, Vector3(0.15 + sx, 0.0, -hz - 0.7), 0.0, 1.05, 0.035, 0.03, rng, false)
	_pole_between(kit, Vector3(-0.2, 1.05, -hz - 0.7), Vector3(0.5, 1.05, -hz - 0.7), 0.03, rng)
	_pole_between(kit, Vector3(0.15, 1.07, -hz - 1.25), Vector3(0.15, 1.07, -hz + 0.05), 0.025, rng)
	for sx: float in [-0.25, 0.25]:
		_pole_between(kit, Vector3(0.15 + sx, 0.36, -hz - 1.15), Vector3(0.15 + sx, 0.36, -hz - 0.05), 0.03, rng)
	# the stump and its stone anvil, the hammer and tongs
	StructureGeometry.pole(kit, FORGE_ANVIL, -0.1, 0.52, 0.24, 0.22, rng, false)
	kit.box(&"stone", Transform3D(Basis(Vector3.UP, 0.3), FORGE_ANVIL + Vector3(0, 0.6, 0)), Vector3(0.36, 0.16, 0.26), K.GRAIN_X, 2, 0.5,
			Color(0.55, 0.53, 0.5, 1.0))
	kit.box(&"stone", Transform3D(Basis(Vector3.UP, -0.5), FORGE_ANVIL + Vector3(0.06, 0.7, 0.07)), Vector3(0.09, 0.05, 0.06), K.GRAIN_X, 3, 0.1,
			Color(0.4, 0.38, 0.35, 1.0))
	_pole_between(kit, FORGE_ANVIL + Vector3(0.06, 0.7, 0.07), FORGE_ANVIL + Vector3(0.22, 0.69, 0.3), 0.012, rng)


## A piece's parts drawn beside its kit mesh (BuiltPiece.build_visuals): [[mesh, transform, material or null]].
static func piece_parts(type: String) -> Array:
	if FortPieces.is_fort_piece(type):
		return FortPieces.parts(type)
	match type:
		"work_stone":
			return work_stone_parts()
		"charcoal_mound":
			return charcoal_parts()
		"forge":
			return forge_parts()
	return []


## The charcoal mound's earth dome: soil and turf packed over the stacked wood, smooth, scorched darker toward the top,
## the chimney hole at the crown and a ring of small vent holes.
static func charcoal_parts() -> Array:
	if not _cache.has("charcoal_dome"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1769
		var prof: Array = []
		var rings := 10
		for i in rings + 1:
			var t := float(i) / rings
			var ang := t * PI * 0.5
			prof.append([MOUND_R * cos(ang) * (1.0 - 0.1 * t), MOUND_H * sin(ang)])
		var m := _turned(prof, 28, func(t: float, u: float) -> Color:
			var n := 0.5 + 0.5 * sin(u * 7.0 + t * 5.0) * cos(u * 3.0 - t * 4.0)
			var soil := Color(0.25, 0.2, 0.14).lerp(Color(0.2, 0.22, 0.12), n * (1.0 - t))
			return soil.lerp(Color(0.1, 0.09, 0.08), smoothstep(0.55, 1.0, t)), rng, 0.04, 0.035)
		_cache["charcoal_dome"] = m
		# the chimney and the vents: dark discs a hair off the surface
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_disc(st, Vector3(0, MOUND_H + 0.005, 0), Vector3.UP, 0.09, Color(0.03, 0.03, 0.03))
		for i in 7:
			var a := TAU * i / 7.0
			var t := 0.4
			var p := Vector3(cos(a) * MOUND_R * cos(t * PI * 0.5) * 0.97, MOUND_H * sin(t * PI * 0.5), sin(a) * MOUND_R * cos(t * PI * 0.5) * 0.97)
			_disc(st, p, Vector3(cos(a) * 0.8, 0.6, sin(a) * 0.8).normalized(), 0.035, Color(0.04, 0.035, 0.03))
		var vm := st.commit()
		vm.surface_set_material(0, ForageModels.matte_material())
		_cache["charcoal_vents"] = vm
	return [[_cache["charcoal_dome"], Transform3D(), null], [_cache["charcoal_vents"], Transform3D(), null]]


## The forge's clay smelting shaft (a turned shape on the hearth's left end, its dark mouth) and the great bellows behind
## the hearth: two wedge boards and the leather between, the nozzle to the firepot.
static func forge_parts() -> Array:
	if not _cache.has("forge_shaft"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1770
		var h := FORGE_SHAFT_H - FORGE_HEARTH.y + 0.04
		var prof: Array = [[0.27, 0.0], [0.26, h * 0.3], [0.22, h * 0.7], [0.18, h], [0.13, h + 0.01]]
		_cache["forge_shaft"] = _turned(prof, 20, func(t: float, u: float) -> Color:
			return Color(0.58, 0.42, 0.3).lerp(Color(0.2, 0.15, 0.12), smoothstep(0.75, 1.0, t)).lerp(Color(0.5, 0.36, 0.26), 0.3 * sin(u * 5.0 + t * 9.0)), rng, 0.012, 0.0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_disc(st, Vector3(0, h + 0.012, 0), Vector3.UP, 0.12, Color(0.03, 0.025, 0.02))
		var sm := st.commit()
		sm.surface_set_material(0, ForageModels.matte_material())
		_cache["forge_mouth"] = sm
		_cache["forge_bellows"] = _bellows_mesh()
	var hz := FORGE_HEARTH.z * 0.5
	var shaft_at := Vector3(-FORGE_HEARTH.x * 0.5 + 0.24, FORGE_HEARTH.y - 0.02, 0)
	return [[_cache["forge_shaft"], Transform3D(Basis(), shaft_at), null], [_cache["forge_mouth"], Transform3D(Basis(), shaft_at), null],
			[_cache["forge_bellows"], Transform3D(Basis(), Vector3(0.15, 0.4, -hz - 0.6)), null]]


## A turned shape: `prof` [radius, y] rings round +Y, `segs` round, coloured by col(t along, u round), each vertex pushed
## out by up to `bump` (and `wave` over the rings) so it is not machine-round.
static func _turned(prof: Array, segs: int, col: Callable, rng: RandomNumberGenerator, bump: float, wave: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for i in prof.size():
		var row: Array = []
		for k in segs + 1:
			var u := TAU * float(k % segs) / segs
			var r := float(prof[i][0]) * (1.0 + (rng.randf_range(-1.0, 1.0) * bump + sin(u * 3.0 + i) * wave) * (1.0 if k < segs else 0.0))
			row.append(Vector3(cos(u) * r, float(prof[i][1]), sin(u) * r))
		row[segs] = row[0]
		rows.append(row)
	for i in prof.size() - 1:
		var t0 := float(i) / (prof.size() - 1)
		var t1 := float(i + 1) / (prof.size() - 1)
		for k in segs:
			var u0 := TAU * float(k) / segs
			var u1 := TAU * float(k + 1) / segs
			var p00: Vector3 = rows[i][k]
			var p01: Vector3 = rows[i][k + 1]
			var p10: Vector3 = rows[i + 1][k]
			var p11: Vector3 = rows[i + 1][k + 1]
			var n := (p01 - p00).cross(p10 - p00).normalized()
			if n.dot(Vector3(p00.x, 0.0, p00.z)) < 0.0:
				n = -n
			ForageModels._tri(st, p00, col.call(t0, u0), p01, col.call(t0, u1), p11, col.call(t1, u1), n)
			ForageModels._tri(st, p00, col.call(t0, u0), p11, col.call(t1, u1), p10, col.call(t1, u0), n)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, ForageModels.matte_material())
	return m


static func _disc(st: SurfaceTool, c: Vector3, n: Vector3, r: float, col: Color) -> void:
	var x := n.cross(Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT).normalized()
	var y := n.cross(x).normalized()
	for k in 10:
		var a0 := TAU * k / 10.0
		var a1 := TAU * (k + 1) / 10.0
		ForageModels._tri(st, c, col, c + (x * cos(a0) + y * sin(a0)) * r, col, c + (x * cos(a1) + y * sin(a1)) * r, col, n)


## The great bellows (the forge's): a pear-shaped bottom board flat, the top board rising toward the back, the leather
## sides between, the iron-shod nozzle forward (+Z) at the narrow end. Origin at the nozzle end's bottom middle.
static func _bellows_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var outline: Array = []
	for k in n:
		var a := TAU * k / n
		var z := -cos(a) * 0.45 - 0.45        # 0 at the nozzle end, -0.9 at the back
		var w := sin(a) * (0.1 + 0.2 * sqrt(clampf(-z / 0.9, 0.0, 1.0)))
		outline.append(Vector2(w, z))
	var board := Color(0.36, 0.26, 0.17)
	var leather := Color(0.24, 0.16, 0.1)
	var bot: Array[Vector3] = []
	var top: Array[Vector3] = []
	for p: Vector2 in outline:
		bot.append(Vector3(p.x, 0.0, p.y))
		top.append(Vector3(p.x, 0.04 + 0.32 * (-p.y / 0.9), p.y))
	var cb := Vector3(0, 0, -0.45)
	var ct := Vector3(0, 0.04 + 0.32 * 0.5, -0.45)
	for k in n:
		var k1 := (k + 1) % n
		ForageModels._tri(st, cb, board, bot[k], board, bot[k1], board, Vector3.DOWN)
		ForageModels._tri(st, ct, board.lightened(0.05), top[k], board.lightened(0.05), top[k1], board.lightened(0.05), Vector3(0, 1, -0.35).normalized())
		var side: Vector3 = (bot[k] + bot[k1]) * 0.5 - cb
		side.y = 0.0
		side = side.normalized()
		# the leather, drawn in a little at the middle (a fold)
		var m0: Vector3 = (bot[k] + top[k]) * 0.5 - side * 0.03
		var m1: Vector3 = (bot[k1] + top[k1]) * 0.5 - side * 0.03
		ForageModels._tri(st, bot[k], leather, bot[k1], leather, m1, leather.darkened(0.2), side)
		ForageModels._tri(st, bot[k], leather, m1, leather.darkened(0.2), m0, leather.darkened(0.2), side)
		ForageModels._tri(st, m0, leather.darkened(0.2), m1, leather.darkened(0.2), top[k1], leather, side)
		ForageModels._tri(st, m0, leather.darkened(0.2), top[k1], leather, top[k], leather, side)
	# the nozzle: an iron tube forward into the hearth's back
	ForageModels._stem(st, Vector3(0, 0.03, 0.0), Vector3(0, 0.05, 0.42), 0.035, 0.02, Color(0.16, 0.15, 0.14), 8)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, ForageModels.matte_material())
	return m


## The trapper's line mark: a stick driven in beside the trap, a strip of red cloth tied at its top.
static func _trap_mark(kit: K, at: Vector3, rng: RandomNumberGenerator) -> void:
	StructureGeometry.pole(kit, at, -0.2, TRAP_MARK_H, 0.014, 0.01, rng, false)
	var cloth := Color(0.72, 0.08, 0.05, 1.0)
	kit.box(&"boards", Transform3D(Basis(Vector3.RIGHT, 0.14), at + Vector3(0.0, TRAP_MARK_H - 0.19, 0.03)), Vector3(0.005, 0.34, 0.075),
			K.GRAIN_Y, 0, 0.0, cloth, K.KIND_CLAY)
	kit.box(&"boards", Transform3D(Basis(), at + Vector3(0.0, TRAP_MARK_H - 0.02, 0.0)), Vector3(0.03, 0.02, 0.03), K.GRAIN_Y, 0, 0.0,
			cloth, K.KIND_CLAY)


## A noose of cord hanging in a ring (the run goes through it along Z).
static func _noose(kit: K, c: Vector3, cord: Color) -> void:
	var n := 10
	var r := 0.08
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := c + Vector3(cos(a0) * r, sin(a0) * r, 0.0)
		var p1 := c + Vector3(cos(a1) * r, sin(a1) * r, 0.0)
		var d := p1 - p0
		var bs := Basis.looking_at(d.normalized(), Vector3.FORWARD if absf(d.normalized().z) < 0.95 else Vector3.UP)
		kit.box(&"boards", Transform3D(bs, (p0 + p1) * 0.5), Vector3(0.005, 0.005, d.length() + 0.003), K.GRAIN_Z, 0, 0.0, cord, K.KIND_CLAY)


## A cradle: a plank box on two curved rockers (three boards a side, the ends turned up), a taller headboard with a hood over
## the head end (-z), a straw tick in it (the baby lies on it: BabyLink / Cradle).
static func _cradle(kit: K, rng: RandomNumberGenerator) -> void:
	var hw := CRADLE_W * 0.5
	var hl := CRADLE_L * 0.5
	for sx: float in [-1.0, 1.0]:
		# the rocker: a flat middle and the two ends turned up
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx * (hw - 0.02), 0.03, 0.0)), Vector3(0.04, 0.06, 0.5), K.GRAIN_Z, rng.randi_range(0, 3), rng.randf())
		for sz: float in [-1.0, 1.0]:
			kit.box(&"boards", Transform3D(Basis(Vector3.RIGHT, sz * 0.4), Vector3(sx * (hw - 0.02), 0.075, sz * (hl - 0.2))),
					Vector3(0.04, 0.06, 0.3), K.GRAIN_Z, rng.randi_range(0, 3), rng.randf())
		# the side board, a little flared
		kit.box(&"boards", Transform3D(Basis(Vector3.FORWARD, sx * 0.12), Vector3(sx * (hw - 0.03), 0.22, 0.0)),
				Vector3(0.03, 0.22, CRADLE_L - 0.04), K.GRAIN_Z, rng.randi_range(0, 3), rng.randf())
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(CRADLE_W - 0.06, 0.03, CRADLE_L - 0.06), K.GRAIN_Z, rng.randi_range(0, 3), rng.randf())
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.25, -hl + 0.015)), Vector3(CRADLE_W - 0.02, 0.32, 0.03), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.2, hl - 0.015)), Vector3(CRADLE_W - 0.02, 0.22, 0.03), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
	# the hood: a board over the head end, tilted, on two side pieces
	kit.box(&"boards", Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.4, -hl + 0.16)), Vector3(CRADLE_W - 0.04, 0.025, 0.34), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
	for sx: float in [-1.0, 1.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx * (hw - 0.03), 0.34, -hl + 0.16)), Vector3(0.03, 0.14, 0.32), K.GRAIN_Z, rng.randi_range(0, 3), rng.randf())
	kit.box(&"straw", Transform3D(Basis(), Vector3(0, 0.15, 0.03)), Vector3(CRADLE_W - 0.1, 0.07, CRADLE_L - 0.16), K.GRAIN_Z, rng.randi_range(0, 3),
			rng.randf(), Color(0.86, 0.8, 0.64, 1.0))


## A storage chest: plank sides and ends, iron straps and corners, a hasp; its lid is StorageChest's (it opens) unless
## `lid` (the ghost's whole chest).
static func _storage_chest(kit: K, rng: RandomNumberGenerator, lid: bool) -> void:
	var hx := CHEST_W * 0.5
	var hz := CHEST_D * 0.5
	var h := CHEST_H - 0.07
	for sz: float in [-1.0, 1.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(0, h * 0.5, sz * (hz - 0.015))), Vector3(CHEST_W, h, 0.03), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
	for sx: float in [-1.0, 1.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx * (hx - 0.015), h * 0.5, 0)), Vector3(0.03, h, CHEST_D - 0.06), K.GRAIN_Z, rng.randi_range(0, 3), rng.randf())
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.04, 0)), Vector3(CHEST_W - 0.06, 0.03, CHEST_D - 0.06), K.GRAIN_X, 0, rng.randf())
	var iron := Color(0.22, 0.21, 0.2, 1.0)
	for sx: float in [-0.3, 0.3]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx, h * 0.5, hz + 0.004)), Vector3(0.05, h, 0.012), K.GRAIN_Y, 0, 0.0, iron, K.KIND_IRON)
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx, h * 0.5, -hz - 0.004)), Vector3(0.05, h, 0.012), K.GRAIN_Y, 0, 0.0, iron, K.KIND_IRON)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, h - 0.06, hz + 0.01)), Vector3(0.06, 0.1, 0.014), K.GRAIN_Y, 0, 0.0, iron, K.KIND_IRON)
	if lid:
		chest_lid(kit, rng, Transform3D(Basis(), Vector3(0, h, -hz)))


## The chest's lid from its hinge line at the back (`t`): boards, two straps, the hasp's staple at the front.
static func chest_lid(kit: K, rng: RandomNumberGenerator, t: Transform3D) -> void:
	var saved := kit.xform
	kit.xform = saved * t
	var iron := Color(0.22, 0.21, 0.2, 1.0)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.035, CHEST_D * 0.5)), Vector3(CHEST_W + 0.02, 0.07, CHEST_D + 0.02), K.GRAIN_X,
			rng.randi_range(0, 3), rng.randf())
	for sx: float in [-0.3, 0.3]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx, 0.074, CHEST_D * 0.5)), Vector3(0.05, 0.01, CHEST_D + 0.03), K.GRAIN_Z, 0, 0.0, iron, K.KIND_IRON)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.0, CHEST_D + 0.015)), Vector3(0.05, 0.08, 0.012), K.GRAIN_Y, 0, 0.0, iron, K.KIND_IRON)
	kit.xform = saved


## The chest's lid as a mesh of its own (StorageChest turns it open).
static func chest_lid_mesh() -> ArrayMesh:
	var key := "chest_lid"
	if _cache.has(key):
		return _cache[key]
	var kit := K.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	chest_lid(kit, rng, Transform3D.IDENTITY)
	var m := kit.commit(StructureMaterials.all())
	_cache[key] = m
	return m


## Whether `local` (a point in a lean-to's space, at the feet) is in its shelter: under the slope from the ridge back to
## where it meets the ground, or in the strip in front of the posts under the ridge (further back the roof is too low
## to stand under; a sleeper sits at its mouth, facing the fire). CampLink tells the survival core.
static func under_lean_to(local: Vector3) -> bool:
	return absf(local.x) <= LEAN_W * 0.5 and local.z >= -LEAN_D + 0.2 and local.z <= 0.6 \
			and local.y > -1.0 and local.y < LEAN_H + 0.3


## A brush lean-to: two forked posts at the open front (+Z), a ridge pole across them, poles sloping back to the
## ground, thatched with bark slabs and brush. Origin at the middle of the front, on the ground.
static func _lean_to(kit: K, rng: RandomNumberGenerator) -> void:
	var hw := LEAN_W * 0.5 - 0.1
	for sx: float in [-1.0, 1.0]:
		kit.box(&"bark", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(sx * hw, LEAN_H * 0.5 - 0.1, 0)),
				Vector3(0.12, LEAN_H + 0.1, 0.12), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
		# the fork
		for fs: float in [-1.0, 1.0]:
			kit.box(&"bark", Transform3D(Basis(Vector3.BACK, fs * 0.45), Vector3(sx * hw + fs * 0.06, LEAN_H + 0.05, 0)),
					Vector3(0.06, 0.24, 0.06), K.GRAIN_X, 0, rng.randf())
	# the ridge pole in the forks
	kit.box(&"bark", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, LEAN_H - 0.02, 0)), Vector3(0.1, LEAN_W + 0.3, 0.1),
			K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
	# poles from the ridge back to the ground, and the thatch over them
	var slope := Vector2(LEAN_D, LEAN_H).length()
	var ang := atan2(LEAN_H, LEAN_D)
	var down := Basis(Vector3.RIGHT, -ang)
	var n_poles := 7
	for i in n_poles:
		var x := -hw + (2.0 * hw) * i / (n_poles - 1) + rng.randf_range(-0.05, 0.05)
		kit.box(&"bark", Transform3D(down, Vector3(x, LEAN_H * 0.5, -LEAN_D * 0.5) + down.y * 0.06),
				Vector3(0.07, 0.07, slope + 0.25), K.GRAIN_X, rng.randi_range(0, 3), rng.randf())
	var rows := 5
	var cols := 5
	for r in rows:
		for c in cols:
			var u := (c + 0.5) / cols - 0.5
			var v := (r + 0.5) / rows
			var p := Vector3(u * LEAN_W * 0.98, LEAN_H * (1.0 - v), -LEAN_D * v) + down.y * 0.12
			var jitter := Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)) * Basis(Vector3.BACK, rng.randf_range(-0.06, 0.06))
			var t := rng.randf_range(0.75, 1.05)
			var key := &"bark" if (r + c) % 3 != 0 else &"straw"
			kit.box(key, Transform3D(down * jitter, p), Vector3(LEAN_W / cols + 0.12, 0.035, slope / rows + 0.14), K.GRAIN_X,
					rng.randi_range(0, 3), rng.randf(), Color(t, t * 0.97, t * 0.9, 1.0))


static func _hearth(kit: K, rng: RandomNumberGenerator) -> void:
	var hw := HEARTH_W * 0.5
	StructureGeometry.chimney(kit, Vector3(-hw, -HEARTH_SINK, 0.0), Vector3(hw, HEARTH_H, HEARTH_D), Vector2(-0.4, 0.12),
			Vector2(0.4, 0.82), 2.1, HEARTH_TOP)
	var ts := 1.0 / StructureGeometry.STONE_TILE
	# The fire opening (dark), its lintel stone and the hearthstone in front.
	var z := HEARTH_D + 0.003
	kit.quad(&"stone", Vector3(-0.4, 0.1, z), Vector3(0.4, 0.1, z), Vector3(0.4, 0.88, z), Vector3(-0.4, 0.88, z),
			Vector2(), Vector2(), Vector2(), Vector2(), Color(1, 1, 1, 0), K.KIND_VOID, 0.0, PackedColorArray(), Vector3.BACK)
	StructureGeometry._stone_box(kit, Vector3(0, 0.96, HEARTH_D + 0.03), Vector3(1.0, 0.16, 0.08), ts, 0)
	StructureGeometry._stone_box(kit, Vector3(0, 0.02, HEARTH_D + 0.26), Vector3(1.4, 0.1, 0.5), ts, 8)
	# A few charred ends of firewood inside the opening.
	for i in 3:
		var y := 0.14 + 0.05 * (i % 2)
		StructureGeometry.log_end(kit, Vector3(-0.3 + 0.05 * i, y, HEARTH_D - 0.25 + 0.06 * i), Vector3(1, 0, 0.25 * (i - 1)).normalized(),
				0.45, 0.045, rng)


# --- Palisade --------------------------------------------------------------------------------------------

## The ribband pinned across the inside of the stakes (-Z), following the ground under the section's ends.
static func _palisade_rail(kit: K, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var g: Array = ctx.get("gy", [0.0, 0.0])
	var a := Vector3(-L * 0.5, float(g[0]) + RAIL_Y, -0.255)
	var b := Vector3(L * 0.5, float(g[1]) + RAIL_Y, -0.255)
	var dir := (b - a).normalized()
	var frame := Basis(dir, Vector3.BACK.cross(dir).normalized(), Vector3.BACK)
	kit.box(&"boards", Transform3D(frame, (a + b) * 0.5), Vector3(a.distance_to(b), 0.16, 0.09), K.GRAIN_X, rng.randi_range(0, 3),
			rng.randf(), Color(0.92, 0.9, 0.86, 0.9))


static func _gate_frame(kit: K, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var g: Array = ctx.get("gy", [0.0, 0.0])
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var y0 := float(g[i]) - STAKE_SINK
		var x := s * GATE_POST_X
		kit.box(&"boards", Transform3D(Basis(), Vector3(x, (y0 + GATE_TOP) * 0.5, 0)), Vector3(GATE_POST, GATE_TOP - y0, GATE_POST),
				K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(0.95, 0.93, 0.9, 1.0), K.KIND_ENDGRAIN, 8, 0.0, 0.7)
		for cx: float in [-1.0, 1.0]:
			for cz: float in [-1.0, 1.0]:
				var t := Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(x + cx * (GATE_POST * 0.5 - 0.015), (y0 + GATE_TOP) * 0.5,
						cz * (GATE_POST * 0.5 - 0.015)))
				kit.box(&"boards", t, Vector3(0.05, GATE_TOP - y0, 0.05), K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(),
						Color(1.05, 1.03, 1.0, 1.0), K.KIND_ENDGRAIN, 4 | 8, 1.0)
		for hy: float in [0.6, GATE_LEAF_H - 0.5]:
			kit.box(&"boards", Transform3D(Basis(), Vector3(x - s * 0.25, hy, -0.12)), Vector3(0.06, 0.1, 0.08), K.GRAIN_X, 0, 0.0,
					Color.WHITE, K.KIND_IRON)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, GATE_TOP - 0.2, 0)), Vector3(L, 0.4, 0.45), K.GRAIN_X, rng.randi_range(0, 3),
			rng.randf(), Color(0.95, 0.93, 0.9, 1.0))
	StructureGeometry.gable_roof(kit, Vector3(0, GATE_TOP, 0), 0.3, L + 0.2, 35.0, PI * 0.5, rng, true, false)


## A gate leaf from its hinge along `dir` (+1 / -1 X): split planks, three battens and a brace on the inside
## (-Z), iron straps outside.
static func _gate_leaf(kit: K, dir: float, rng: RandomNumberGenerator) -> void:
	var w := GATE_POST_X - GATE_POST * 0.5 - 0.015
	var n := 6
	var bw := w / n
	for i in n:
		var t := rng.randf_range(0.84, 1.04)
		var hgt := GATE_LEAF_H - 0.05 * (i % 2)
		kit.box(&"boards", Transform3D(Basis(), Vector3(dir * bw * (i + 0.5), 0.05 + hgt * 0.5, 0.0)), Vector3(bw - 0.008, hgt, 0.1),
				K.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(t * 0.93, t * 0.9, t * 0.87, 1.0), K.KIND_ENDGRAIN)
	for hy: float in [0.5, GATE_LEAF_H * 0.5, GATE_LEAF_H - 0.45]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(dir * w * 0.5, hy, -0.08)), Vector3(w - 0.06, 0.2, 0.06), K.GRAIN_X,
				rng.randi_range(0, 3), rng.randf(), Color(0.9, 0.88, 0.85, 1.0), K.KIND_ENDGRAIN)
		kit.box(&"boards", Transform3D(Basis(), Vector3(dir * w * 0.3, hy, 0.056)), Vector3(w * 0.6, 0.06, 0.012), K.GRAIN_X, 0, 0.0,
				Color.WHITE, K.KIND_IRON)
	for k in 2:
		var ya := 0.5 if k == 0 else GATE_LEAF_H * 0.5
		var yb := GATE_LEAF_H * 0.5 if k == 0 else GATE_LEAF_H - 0.45
		var a := Vector3(dir * 0.1, ya + 0.1, -0.08)
		var b := Vector3(dir * (w - 0.1), yb - 0.1, -0.08)
		var d := (b - a).normalized()
		kit.box(&"boards", Transform3D(Basis(d, Vector3.BACK.cross(d).normalized(), Vector3.BACK), (a + b) * 0.5),
				Vector3(a.distance_to(b), 0.16, 0.05), K.GRAIN_X, 1, rng.randf(), Color(0.9, 0.88, 0.85, 1.0), K.KIND_ENDGRAIN)


# --- Colliders ---------------------------------------------------------------------------------------------

## The piece's colliders in its frame: [[Shape3D, Transform3D, meta {name: value}]] (doors and gate leaves are
## their own bodies: BuildDoor). `ctx` as for mesh().
static func colliders(type: String, ctx: Dictionary) -> Array:
	if FortPieces.is_fort_piece(type):
		return FortPieces.colliders(type)
	var out: Array = []
	var h := L * 0.5
	var nt := {"trav": NO_TRAVERSE}
	match type:
		"floor":
			out.append(_box(Vector3(0, (FLOOR_H - FLOOR_FOOTING) * 0.5, 0), Vector3(L + T, FLOOR_H + FLOOR_FOOTING, L + T)))
		"wall", "wall_window", "wall_door":
			var yb := -FOOTING if bool(ctx.get("g", false)) else 0.0
			var spans: Array = []
			match type:
				"wall_door":
					spans = [[-h, -DOOR_HALF, yb, WALL_H], [DOOR_HALF, h, yb, WALL_H], [-DOOR_HALF, DOOR_HALF, DOOR_TOP - 0.06, WALL_H]]
					if yb < 0.0:
						spans.append([-DOOR_HALF, DOOR_HALF, yb, -0.03])
					var st: Array = ctx.get("st", [0.0, 0.0])
					for i in 2:
						var ramp := door_ramp(float(st[i]), 1.0 if i == 0 else -1.0)
						if not ramp.is_empty():
							out.append([ramp[0], ramp[1], {}])
				"wall_window":
					spans = [[-h, -WIN_HALF, yb, WALL_H], [WIN_HALF, h, yb, WALL_H], [-WIN_HALF, WIN_HALF, yb, WIN_Y.x],
							[-WIN_HALF, WIN_HALF, WIN_Y.y, WALL_H]]
				_:
					spans = [[-h, h, yb, WALL_H]]
			for s: Array in spans:
				var x0: float = s[0]
				var x1: float = s[1]
				var y0: float = s[2]
				var y1: float = s[3]
				out.append(_box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0), Vector3(x1 - x0, y1 - y0, T), nt))
			for i in 2:
				if String(ctx.get("e0" if i == 0 else "e1", "free")) == "corner":
					var sx := -1.0 if i == 0 else 1.0
					var len := T * 0.5 + CORNER_OUT
					out.append(_box(Vector3(sx * (h + len * 0.5), WALL_H * 0.5, 0), Vector3(len, WALL_H, LOG_R * 2.0), nt))
		"post":
			var y0 := -POST_SINK if bool(ctx.get("g", false)) else 0.0
			out.append(_box(Vector3(0, (y0 + WALL_H) * 0.5, 0), Vector3(POST_W, WALL_H - y0, POST_W)))
		"gable":
			var half := h + T * 0.5
			var top := roof_underside(0.0)
			var shape := ConvexPolygonShape3D.new()
			shape.points = PackedVector3Array([Vector3(-half, 0, -T * 0.5), Vector3(half, 0, -T * 0.5), Vector3(0, top, -T * 0.5),
					Vector3(-half, 0, T * 0.5), Vector3(half, 0, T * 0.5), Vector3(0, top, T * 0.5)])
			out.append([shape, Transform3D.IDENTITY, nt])
		"roof":
			var p := pitch()
			var over := Vector2(float(ctx.get("o0", T * 0.5 + GABLE_OVER)), float(ctx.get("o1", T * 0.5 + GABLE_OVER)))
			var s := (EAVE_OVER - 0.06 * sin(p)) / cos(p)
			var cy := -0.02 - s * sin(p) + 0.06 * cos(p)
			var half := (L + T) * 0.5 + EAVE_OVER
			var slope := half / cos(p)
			var xl := L + over.x + over.y
			var xc := (over.y - over.x) * 0.5
			for sg: float in [1.0, -1.0]:
				# the deck from the eave (z = sg * half) up to the ridge, 18 cm thick about 2 cm over its underside line
				var c := Vector3(xc, cy + slope * 0.5 * sin(p) + 0.03 * cos(p), sg * (half - slope * 0.5 * cos(p) + 0.03 * sin(p)))
				out.append([_box_shape(Vector3(xl, 0.18, slope + 0.08)), Transform3D(Basis(Vector3.RIGHT, sg * p), c), nt])
		"campfire":
			# the ring: low, stepped over at a walk (no vault or climb)
			out.append(_box(Vector3(0, 0.08, 0), Vector3(FIRE_R * 2.2, 0.2, FIRE_R * 2.2), {"surface": "stone", "no_traverse": true}))
		"lean_to":
			var wood := {"surface": "wood", "no_traverse": true}
			for sx: float in [-1.0, 1.0]:
				out.append(_box(Vector3(sx * (LEAN_W * 0.5 - 0.1), LEAN_H * 0.5, 0), Vector3(0.14, LEAN_H, 0.14), wood))
			var slope := Vector2(LEAN_D, LEAN_H).length()
			var ang := atan2(LEAN_H, LEAN_D)
			out.append([_box_shape(Vector3(LEAN_W, 0.14, slope)), Transform3D(Basis(Vector3.RIGHT, -ang),
					Vector3(0, LEAN_H * 0.5 + 0.05, -LEAN_D * 0.5)), wood])
		"bough_bed":
			out.append(_box(Vector3(0, 0.07, 0), Vector3(BOUGH_W + 0.2, 0.14, BED_L), {"surface": "grass"}))
		"pole_bed":
			out.append(_box(Vector3(0, POLE_BED_H * 0.5, 0), Vector3(POLE_BED_W, POLE_BED_H, BED_L), {"surface": "wood", "no_traverse": true}))
		"drying_rack":
			var wood := {"surface": "wood", "no_traverse": true}
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					out.append(_box(Vector3(sx * (DRY_W * 0.5 - 0.05), DRY_H * 0.5, sz * (DRY_D * 0.5 - 0.05)), Vector3(0.1, DRY_H, 0.1), wood))
		"boat_stand":
			out.append(_box(Vector3(0, 0.1, 0), Vector3(1.3, 0.2, BOAT_L), {"surface": "wood"}))
		"tanning_frame":
			var wood := {"surface": "wood", "no_traverse": true}
			for sx: float in [-1.0, 1.0]:
				out.append(_box(Vector3(sx * TAN_W * 0.45, TAN_H * 0.5, 0), Vector3(0.12, TAN_H, 0.12), wood))
			out.append(_box(Vector3(0, TAN_H * 0.5, 0), Vector3(TAN_W, TAN_H - 0.3, 0.06), wood))
			out.append(_box(Vector3(TAN_W * 0.5 + 0.45, 0.5, 0.25), Vector3(0.24, 0.9, 1.2), wood))
		"alchemy_table":
			out.append(_box(Vector3(0, TABLE_H * 0.5, 0), Vector3(TABLE_W, TABLE_H, TABLE_D), {"surface": "wood", "no_traverse": true}))
		"workbench":
			out.append(_box(Vector3(0, BENCH_H * 0.5, 0), Vector3(BENCH_W, BENCH_H, BENCH_D), {"surface": "wood", "no_traverse": true}))
		"stretching_hoop":
			out.append(_box(Vector3(0, (HOOP_Y + HOOP_R) * 0.5, -0.02), Vector3(HOOP_R * 2.0, HOOP_Y + HOOP_R, 0.08), {"surface": "wood", "no_traverse": true}))
		"storage_chest":
			out.append(_box(Vector3(0, CHEST_H * 0.5, 0), Vector3(CHEST_W, CHEST_H, CHEST_D), {"surface": "wood", "no_traverse": true}))
		"cradle":
			out.append(_box(Vector3(0, CRADLE_H * 0.5, 0), Vector3(CRADLE_W, CRADLE_H, CRADLE_L), {"surface": "wood", "no_traverse": true}))
		"charcoal_mound":
			out.append(_box(Vector3(0, MOUND_H * 0.4, 0), Vector3(MOUND_R * 1.6, MOUND_H * 0.8, MOUND_R * 1.6), {"surface": "dirt", "no_traverse": true}))
			out.append(_box(Vector3(0, 0.005, 0), Vector3(MOUND_R * 2.6, 0.01, MOUND_R * 2.6)))
		"forge":
			out.append(_box(Vector3(0, FORGE_HEARTH.y * 0.5, 0), FORGE_HEARTH, {"surface": "stone", "no_traverse": true}))
			out.append(_box(Vector3(-FORGE_HEARTH.x * 0.5 + 0.22, FORGE_SHAFT_H * 0.5, 0), Vector3(0.44, FORGE_SHAFT_H, 0.5), {"surface": "stone", "no_traverse": true}))
			out.append(_box(FORGE_ANVIL + Vector3(0, 0.33, 0), Vector3(0.5, 0.66, 0.5), {"surface": "wood", "no_traverse": true}))
			out.append(_box(Vector3(0.2, 0.005, 0.3), Vector3(3.2, 0.01, 2.2)))
		"work_stone":
			out.append(_box(Vector3(0, WORK_STONE.y * 0.5, 0), WORK_STONE, {"surface": "stone", "no_traverse": true}))
			# the worked spot round it, trodden bare (BuildGrass clears the grass off it)
			out.append(_box(Vector3(0.2, 0.005, 0.0), Vector3(1.5, 0.01, 1.1)))
		"trap_steel":
			# low on the ground: to aim at (build mode's take-down), stepped over; the bed it is set in, cleared of
			# grass (BuildGrass), and the line mark
			out.append(_box(Vector3(0, 0.03, -0.1), Vector3(0.22, 0.06, 0.62)))
			out.append(_box(Vector3(0, 0.005, -0.1), Vector3(0.8, 0.01, 0.9)))
			out.append(_box(TRAP_MARK_STEEL + Vector3(0, TRAP_MARK_H * 0.5, 0), Vector3(0.04, TRAP_MARK_H, 0.04), {"surface": "wood"}))
		"trap_snare":
			out.append(_box(Vector3(0, 0.08, 0), Vector3(0.08, 0.16, 0.08)))
			out.append(_box(Vector3(0, 0.005, -0.1), Vector3(0.5, 0.01, 0.6)))
			out.append(_box(Vector3(0, 0.45, -1.3), Vector3(0.1, 0.9, 0.1), {"surface": "wood"}))
		"trap_deadfall":
			out.append(_box(Vector3(0, 0.2, 0.08), Vector3(1.5, 0.4, 0.3), {"surface": "wood"}))
			out.append(_box(Vector3(0, 0.005, 0.0), Vector3(1.7, 0.01, 0.8)))
			out.append(_box(TRAP_MARK_DEADFALL + Vector3(0, TRAP_MARK_H * 0.5, 0), Vector3(0.04, TRAP_MARK_H, 0.04), {"surface": "wood"}))
		"woodpile":
			out.append(_box(Vector3(0, 0.45, 0), Vector3(WOOD_L + 0.2, 0.9, WOOD_D), {"surface": "wood", "no_traverse": true}))
		"smokehouse":
			var wood := {"surface": "wood", "no_traverse": true}
			var hx := SMOKE_W * 0.5
			var hz := SMOKE_D * 0.5
			out.append(_box(Vector3(0, SMOKE_EAVE * 0.5, -hz), Vector3(SMOKE_W, SMOKE_EAVE, 0.1), wood))
			for sx: float in [-1.0, 1.0]:
				out.append(_box(Vector3(sx * hx, SMOKE_EAVE * 0.5, 0), Vector3(0.1, SMOKE_EAVE, SMOKE_D), wood))
				var w := hx - SMOKE_DOOR.x * 0.5
				out.append(_box(Vector3(sx * (SMOKE_DOOR.x * 0.5 + w * 0.5), SMOKE_EAVE * 0.5, hz), Vector3(w, SMOKE_EAVE, 0.1), wood))
			out.append(_box(Vector3(0, (SMOKE_EAVE + SMOKE_RIDGE) * 0.5, 0), Vector3(SMOKE_W + 0.3, SMOKE_RIDGE - SMOKE_EAVE, SMOKE_D + 0.3), wood))
		"hearth":
			var st := {"surface": "stone"}
			out.append(_box(Vector3(0, (HEARTH_H - HEARTH_SINK) * 0.5, HEARTH_D * 0.5), Vector3(HEARTH_W, HEARTH_H + HEARTH_SINK, HEARTH_D), st))
			out.append(_box(Vector3(0, (HEARTH_H + HEARTH_TOP) * 0.5, 0.47), Vector3(0.8, HEARTH_TOP - HEARTH_H, 0.7), st))
			out.append(_box(Vector3(0, 0.02, HEARTH_D + 0.26), Vector3(1.4, 0.1, 0.5), st))
		"palisade":
			var g: Array = ctx.get("gy", [0.0, 0.0])
			var lo := minf(float(g[0]), float(g[1]))
			var gmin := float(ctx.get("gmin", lo))
			# not climbed (user 2026-09-26: "on the wall i can climb over thru the wall"), like the classic fort's; with cuts
			# in it the collider is PalisadeCuts.colliders (the same box round the holes)
			out.append(_box(Vector3(0, (gmin - STAKE_SINK + gmin + PalisadeCuts.BOX_TOP) * 0.5, 0), Vector3(L, PalisadeCuts.BOX_TOP + STAKE_SINK, PalisadeCuts.THICK), nt))
		"palisade_gate":
			var g: Array = ctx.get("gy", [0.0, 0.0])
			for i in 2:
				var s := -1.0 if i == 0 else 1.0
				var y0 := float(g[i]) - STAKE_SINK
				out.append(_box(Vector3(s * GATE_POST_X, (y0 + GATE_TOP) * 0.5, 0), Vector3(GATE_POST, GATE_TOP - y0, GATE_POST)))
			out.append(_box(Vector3(0, GATE_TOP - 0.2, 0), Vector3(L, 0.4, 0.45)))
	return out


static func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


static func _box(center: Vector3, size: Vector3, meta := {}) -> Array:
	return [_box_shape(size), Transform3D(Basis(), center), meta]
