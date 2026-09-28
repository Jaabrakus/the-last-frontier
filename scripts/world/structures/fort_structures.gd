class_name FrontierStructures
extends Node3D
## The fort and the shooting range (look-dev spec, section 8; package D): the same gameplay
## layout and colliders as the original placeholder code in frontier_level.gd (_fort, _range),
## dressed with generated meshes and PBR materials.
##
## Integration (wired into frontier_level.gd on 2026-09-25 with
## tools/environment/structures/frontier_level_integration.diff; it replaced `_fort(); _range()`
## at the same place in the build order):
##
##   structures = FrontierStructures.new()
##   structures.name = "Structures"
##   add_child(structures)
##   structures.build(settings, rng)          # uses the level rng exactly like _fort + _range
##
## Guarantees:
##   * Every original collider is recreated with the same shape, size, global transform and
##     meta (tools/environment/dump_colliders.gd compare= -> COLLIDERS MATCH with
##     extra_colliders = false). The level rng is consumed in the same order (log heights, crate
##     and hay rotations), so the vegetation that follows sees the same sequence.
##   * Visual randomness uses its own RandomNumberGenerator (seed 1777).
##   * Headless (the tests): colliders, dummies and signs only, no meshes (fast level load).
##   * extra_colliders = true adds the documented colliders for the new solid details: walkway
##     posts, the chimney firebox and stack, the cabin's protruding log ends, and the props
##     (woodpile, chopping block, fire pit; only with props = true), and the cabin's gable roof
##     (one convex prism, added at integration). See EXTRA_COLLIDERS, WOODPILE,
##     _cabin_log_end_colliders(), _cabin_roof_collider(). The shared dump_colliders baseline
##     tools/environment/baselines/colliders_baseline.json has all 81 (the original 59 are in
##     colliders_baseline_59_placeholder.json next to it, the 80 of package D in
##     tools/environment/structures/colliders_with_structures.json).
##   * Grass blockers (2026-09-25 clipping pass): GrassBlockers/ holds plain Node3D boxes (meta
##     half_extents) where a visual part near the ground reaches past its collider -- the
##     blockhouses' corner log ends, the straw trusses' bulging straw, the moving dummy's track --
##     so scripts/world/terrain/grass.gd keeps grass out of them. No physics, no rendering.
##   * Traversal: the cabin box and the cabin roof carry meta trav = {no_traverse: true} on their
##     CollisionShape3D (traversal review 9.6: the free-run climbed the 3.0 m walls into the roof).
##   * Gate leaves (2026-09-26): FortGate, two plank leaves on the posts' pintles (AnimatableBody3D colliders, open
##     at the start; E opens and closes them), and WallCuts: firing windows chopped through the palisade and the
##     leaves with the felling axe (the colliders are rebuilt around the holes).
##   * Ladders (2026-09-26): two up to the firing step by the gate (LADDER_X), each a TravLadder marker and two
##     rail colliders (no_traverse), built with the colliders (headless too); rails and rungs are dressed with
##     the walkway.
##   * Occluders (OccluderInstance3D + BoxOccluder3D) inside the palisade, the blockhouses, the
##     cabin and the storehouse; they need rendering/occlusion_culling/use_occlusion_culling.
##   * settings.structure_detail = false (low preset): flat shingle-textured roofs instead of
##     shingle courses, no walkway joists or ramp cleats. Colliders never change with quality.
##
## Groups and meta for the audio code (scripts/audio/sfx.gd): wood needs nothing (rule 6), the
## chimney keeps its 0.9 x 1.6 x 0.9 box (stone) and the trusses their 1.6 x 0.9 x 0.9 boxes
## (straw); new stone colliders carry meta surface = "stone".

const FORT_HALF := 16.0
const GATE_HALF := 3.0
const FIRING_LINE_Z := -FORT_HALF - 4.0
const RANGE_DISTANCES := [10, 25, 50, 75, 100, 120]
const WALL_HEIGHT := 4.2
const LOG_R := 0.19
## Walkway posts: clear of both ramp footprints and x in +-[11.3, 12.7] (look-dev spec 8.3).
const WALKWAY_POSTS := [3.6, 6.6, 9.6, 15.3, -3.6, -6.6, -9.6]
const POST_Z := -14.29
const RIM_BOTTOM := 1.93

## Extra colliders (documented additions, spec 8.3): [name, shape, centre, size, meta surface].
## Shapes are boxes unless noted; the cabin log ends are built in _cabin_log_end_colliders().
const EXTRA_COLLIDERS := [
	["chimney_firebox", Vector3(-3.96, 0.95, 8.0), Vector3(1.08, 1.9, 1.5), "stone"],
	["chimney_neck", Vector3(-4.43, 2.25, 8.0), Vector3(0.9, 0.7, 0.9), "stone"],
	["chimney_top", Vector3(-4.43, 4.875, 8.0), Vector3(0.9, 1.35, 0.9), "stone"],
]
## Prop colliders (only with props = true): the woodpile box; the chopping block and the fire
## pit are cylinders (see _extra_colliders).
const WOODPILE := [Vector3(-9.0, 0.52, 4.12), Vector3(3.2, 1.04, 0.66)]
const CHOPPING_BLOCK := Vector3(-6.3, 0.0, 3.35)
const FIRE_PIT := Vector3(3.8, 0.0, 10.6)
## Cabin roof collider (extra, 2026-09-25): one solid convex prism over the gable roof that
## _cabin() draws (StructureGeometry.gable_roof at (-8, 3.0, 7), 5 x 7 m footprint + 0.3 m
## overhang, 35 deg, ridge along x). Eaves at z = 7 +- 2.84 from y 2.95 to 3.05, ridge apex at
## y 5.034 (the shingle surface), gable overhangs to x = -8 +- 3.83. It fills the attic, so the
## roof is solid to the player, the camera and projectiles (no meta: wood). Tagged no_traverse
## like the walls under it. Points are relative to the body at ROOF_ORIGIN.
const ROOF_ORIGIN := Vector3(-8.0, 3.0, 7.0)
const ROOF_HALF_X := 3.83
const ROOF_EAVE_Z := 2.84
const ROOF_EAVE_Y := 0.05
const ROOF_APEX_Y := 2.034
## Traversal meta (scripts/traversal/shape_registry.gd, gate "excluded").
const NO_TRAVERSE := {"no_traverse": true}
## Ladders up to the firing step by the gate (user 2026-09-26: "add the climbing and ladders in the game"): the x of
## each ladder between the walkway posts. The rungs stand LADDER_OFF in front of the walkway's edge (the climbing
## clips' toes reach ~0.22 m past the rung line; scenes/traversal_course.gd), with TravLaneClimb's pitch and rung
## radius (the rungs the ladder clips' fists and feet fit) and the first rung where the mount leaves the feet; the
## walkway's top is one hub step of the top dismount (TravLaneClimb.top_height(1) 2.30 m, 2.8 cm over it).
const LADDER_X := [5.1, -5.1]
const LADDER_OFF := 0.25
const LADDER_HALF_W := 0.25
const LADDER_RAIL := Vector3(0.06, 0.3, 0.3)     ## rail cross-section (x, z) and how far it stands over the boards (y)
const WALK_TOP := 2.275
const WALK_EDGE_Z := -FORT_HALF + 1.8

## false: gameplay nodes and colliders only. Defaults to false when running headless.
@export var visuals := true
@export var extra_colliders := true
@export var props := true
@export var occluders := true
## Build the meshes even when headless (tools that raycast the visual geometry).
@export var force_visuals := false

var settings: WorldSettings
var detail := true
var fort: Node3D
var range_root: Node3D
var stats := {}                   ## triangle counts per visual group, build time

var _vrng := RandomNumberGenerator.new()
var _kits := {}                   ## group -> [StructureMeshKit, parent Node3D]
var _mats := {}
var _logs: Array[Transform3D] = []
## Firing windows chopped through the palisade (WallCuts; its walls and logs registered by _fort / _palisade).
var wall_cuts: WallCuts
## The gate's two leaves (FortGate).
var gate_leaves: FortGate
var _dummies: Array[TargetDummy] = []


func build(world_settings: WorldSettings, rng: RandomNumberGenerator) -> void:
	var t0 := Time.get_ticks_usec()
	settings = world_settings if world_settings else WorldSettings.preset(WorldSettings.DEFAULT_QUALITY)
	detail = settings.structure_detail
	if DisplayServer.get_name() == "headless" and not force_visuals:
		visuals = false
	_vrng.seed = 1777
	if visuals:
		_mats = StructureMaterials.all()
		stats["materials_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	fort = Node3D.new()
	fort.name = "Fort"
	add_child(fort)
	range_root = Node3D.new()
	range_root.name = "Range"
	add_child(range_root)
	_fort(rng)
	_range(rng)
	if extra_colliders:
		_extra_colliders()
	_grass_blockers()
	if visuals:
		var t1 := Time.get_ticks_usec()
		_dress_fort()
		_dress_range()
		if props:
			_props()
		var t2 := Time.get_ticks_usec()
		_commit()
		var t3 := Time.get_ticks_usec()
		for d in _dummies:
			DummyStyle.apply(d)
		if occluders:
			_occluders()
		stats["geometry_ms"] = (t2 - t1) / 1000.0
		stats["commit_ms"] = (t3 - t2) / 1000.0
		stats["dummies_occluders_ms"] = (Time.get_ticks_usec() - t3) / 1000.0
	stats["build_ms"] = (Time.get_ticks_usec() - t0) / 1000.0


## The shared material / dummy caches are static: release them with the level so they do not
## outlive the RenderingServer at quit (they are rebuilt on the next build()).
func _exit_tree() -> void:
	if visuals:
		StructureMaterials.release()
		DummyStyle.release()


# --- Layout and colliders (the original _fort / _range, rng calls unchanged) ------------------

func _fort(rng: RandomNumberGenerator) -> void:
	var walls := [
		[Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, -FORT_HALF), true],   # North (gate)
		[Vector3(-FORT_HALF, 0, FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF), false],
		[Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(-FORT_HALF, 0, FORT_HALF), false],
		[Vector3(FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF), false],
	]
	var palisade := _group_node(fort, "Palisade")
	wall_cuts = WallCuts.new()
	wall_cuts.name = "WallCuts"
	add_child(wall_cuts)
	var log_from := _logs.size()
	for wall in walls:
		var a: Vector3 = wall[0]
		var b: Vector3 = wall[1]
		var n := int(a.distance_to(b) / (LOG_R * 2.0))
		var dir := (b - a).normalized()
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			if wall[2] and absf(p.x) < GATE_HALF:
				continue
			var h := WALL_HEIGHT + rng.randf_range(-0.25, 0.25)
			# Visual log: local X along the wall, y scaled to the log's height.
			_logs.append(Transform3D(Basis(dir, Vector3.UP * (h / WALL_HEIGHT), dir.cross(Vector3.UP)), p))
		var length := a.distance_to(b)
		var rot := atan2(-dir.z, dir.x)
		# Traversal: the palisade is not climbed (user 2026-09-26: "on the wall i can climb over thru the wall"):
		# its collider is a 0.38 m slab whose top read as a beam, 2 m above the firing step, while the logs end in
		# points; the path check skips the shape being climbed, so the climb went through the logs.
		# (Each collider is a wall of WallCuts: a window cut through it rebuilds it around the hole.)
		if wall[2]:
			var seg := FORT_HALF - GATE_HALF
			var wl := _no_traverse(_box_collider(palisade, Vector3(-FORT_HALF + seg * 0.5, WALL_HEIGHT * 0.5, a.z), Vector3(seg, WALL_HEIGHT, LOG_R * 2), rot_y_of(0.0)))
			wall_cuts.register_wall(wl, a, Vector3(-GATE_HALF, 0, a.z), WALL_HEIGHT, LOG_R * 2)
			var wr := _no_traverse(_box_collider(palisade, Vector3(FORT_HALF - seg * 0.5, WALL_HEIGHT * 0.5, a.z), Vector3(seg, WALL_HEIGHT, LOG_R * 2), rot_y_of(0.0)))
			wall_cuts.register_wall(wr, Vector3(GATE_HALF, 0, a.z), b, WALL_HEIGHT, LOG_R * 2)
		else:
			var wb := _no_traverse(_box_collider(palisade, (a + b) * 0.5 + Vector3(0, WALL_HEIGHT * 0.5, 0), Vector3(length, WALL_HEIGHT, LOG_R * 2), rot_y_of(rot)))
			wall_cuts.register_wall(wb, a, b, WALL_HEIGHT, LOG_R * 2)
	var seen_log := {}
	for li in range(log_from, _logs.size()):
		var lp: Vector3 = _logs[li].origin
		var key := Vector2i(roundi(lp.x * 100.0), roundi(lp.z * 100.0))
		if seen_log.has(key):
			continue
		seen_log[key] = true
		var wi := wall_cuts.wall_of(lp)
		if wi >= 0:
			wall_cuts.add_log(wi, lp)
	wall_cuts.finish_registration()

	# Gate posts and lintel.
	var gate := _group_node(fort, "Gate")
	for s: float in [-1.0, 1.0]:
		_no_traverse(_cyl_collider(gate, Vector3(s * (GATE_HALF + 0.1), 2.6, -FORT_HALF), 0.28, 5.2))
	_no_traverse(_box_collider(gate, Vector3(0, 5.0, -FORT_HALF), Vector3(GATE_HALF * 2 + 0.8, 0.4, 0.45)))
	# The gate's leaves on the posts' pintles (FortGate): open at the start, E opens and closes them, the axe cuts
	# firing windows through them (their colliders are WallCuts walls that swing with them).
	gate_leaves = FortGate.new()
	gate_leaves.name = "Leaves"
	gate_leaves.visuals = visuals
	gate_leaves.materials = _mats if visuals else {}
	gate_leaves.hinge_z = -FORT_HALF + 0.12
	gate.add_child(gate_leaves)
	gate_leaves.build(wall_cuts, NO_TRAVERSE)

	# Firing step (walkway) and ramps.
	var walk := _group_node(fort, "Walkway")
	for s: float in [-1.0, 1.0]:
		var cx := s * (GATE_HALF + (FORT_HALF - GATE_HALF) * 0.5)
		_box_collider(walk, Vector3(cx, 2.2, -FORT_HALF + 1.0), Vector3(FORT_HALF - GATE_HALF - 0.5, 0.15, 1.6))
		var ramp_x := FORT_HALF - 2.0 if s > 0.0 else -(FORT_HALF - 4.0)
		_ramp_collider(walk, ramp_x, -FORT_HALF + 6.9, -FORT_HALF + 1.9, 2.3)
	for x: float in LADDER_X:
		_ladder(walk, x)

	# Blockhouses on the north-west and south-east corners.
	for corner: Vector3 in [Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF)]:
		var bh := _group_node(fort, "Blockhouse_%s" % ("NW" if corner.x < 0.0 else "SE"))
		_box_collider(bh, corner + Vector3(0, 1.75, 0), Vector3(4.5, 3.5, 4.5))
		_box_collider(bh, corner + Vector3(0, 4.6, 0), Vector3(5.5, 2.2, 5.5))

	# Cabin (with its chimney) and storehouse.
	var cabin := _group_node(fort, "Cabin")
	var cabin_box := _box_collider(cabin, Vector3(-8, 1.5, 7), Vector3(7, 3, 5))
	# Traversal: the 3.0 m walls are not a climb. Without this the free-run planned a
	# climb_hang_3m up the walls into the roof (traversal review 9.6; see _cabin_roof_collider).
	cabin_box.get_child(0).set_meta(&"trav", NO_TRAVERSE.duplicate())
	_box_collider(cabin, Vector3(-4.43, 3.4, 8), Vector3(0.9, 1.6, 0.9))    # Chimney: stone by its size.
	var store := _group_node(fort, "Storehouse")
	_box_collider(store, Vector3(9, 1.2, 4), Vector3(5, 2.4, 4))

	# Supplies: crates (random turn from the level rng), barrels.
	var supplies := _group_node(fort, "Supplies")
	for p: Vector3 in [Vector3(5, 0.4, -6), Vector3(5.9, 0.4, -6.2), Vector3(5.4, 1.2, -6.1), Vector3(-10, 0.4, -4), Vector3(12, 0.4, -9)]:
		var body := _box_collider(supplies, p, Vector3(0.8, 0.8, 0.8), rot_y_of(rng.randf_range(-0.3, 0.3)))
		body.set_meta(&"structure", "crate")
	for p: Vector3 in [Vector3(7, 0.5, -3), Vector3(7.7, 0.5, -3.4), Vector3(-5, 0.5, -10), Vector3(-5.8, 0.5, -10.3), Vector3(11, 0.5, 8)]:
		var body := _cyl_collider(supplies, p, 0.32, 1.0)
		body.set_meta(&"structure", "barrel")

	# Flag pole in the parade ground.
	var flag := _group_node(fort, "Flag")
	_cyl_collider(flag, Vector3(-6, 5, -2), 0.07, 10.0)


func _range(rng: RandomNumberGenerator) -> void:
	var z0 := FIRING_LINE_Z
	var rail := _group_node(range_root, "FiringLine")
	_box_collider(rail, Vector3(0, 0.55, z0), Vector3(8, 0.1, 0.12))
	for x: float in [-4.0, 0.0, 4.0]:
		_box_collider(rail, Vector3(x, 0.3, z0), Vector3(0.12, 0.6, 0.12))

	var lanes := [-2.5, 0.0, 2.5]
	for i in RANGE_DISTANCES.size():
		var d: int = RANGE_DISTANCES[i]
		var x: float = lanes[i % lanes.size()]
		var dummy := TargetDummy.new()
		dummy.position = Vector3(x, 0, z0 - d)
		range_root.add_child(dummy)
		_dummies.append(dummy)
		var label := Label3D.new()
		label.text = "%d m" % d
		label.font_size = 96
		label.pixel_size = 0.006
		label.outline_size = 12
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.position = Vector3(x, 2.3, z0 - d)
		range_root.add_child(label)

	# A dummy that strafes across the lane at 40 m.
	var mover := TargetDummy.new()
	mover.position = Vector3(-5, 0, z0 - 40)
	mover.move_offset = Vector3(10, 0, 0)
	mover.move_period = 5.0
	range_root.add_child(mover)
	_dummies.append(mover)

	# Cover along the lane: bound straw trusses (were hay bales; same boxes, still straw).
	var cover := _group_node(range_root, "Cover")
	for p: Vector3 in [Vector3(-5, 0.45, z0 - 15), Vector3(5, 0.45, z0 - 30), Vector3(-4.5, 0.45, z0 - 60), Vector3(4.5, 0.45, z0 - 85)]:
		var body := _box_collider(cover, p, Vector3(1.6, 0.9, 0.9), rot_y_of(rng.randf_range(-0.4, 0.4)))
		body.set_meta(&"structure", "truss")


func _extra_colliders() -> void:
	var extra := _group_node(self, "ExtraColliders")
	# Walkway posts under the inner rim beam.
	for x: float in WALKWAY_POSTS:
		_box_collider(extra, Vector3(x, RIM_BOTTOM * 0.5, POST_Z), Vector3(0.16, RIM_BOTTOM, 0.16))
	for e: Array in EXTRA_COLLIDERS:
		var body := _box_collider(extra, e[1], e[2])
		body.name = String(e[0])
		if String(e[3]) != "":
			body.set_meta(&"surface", String(e[3]))
	_cabin_log_end_colliders(extra)
	_cabin_roof_collider(extra)
	if props:
		var pile := _box_collider(extra, WOODPILE[0], WOODPILE[1])
		pile.name = "woodpile"
		var block := _cyl_collider(extra, CHOPPING_BLOCK + Vector3(0, 0.275, 0), 0.3, 0.55)
		block.name = "chopping_block"
		var pit := _cyl_collider(extra, FIRE_PIT + Vector3(0, 0.17, 0), 0.72, 0.34)
		pit.name = "fire_pit"
		pit.set_meta(&"surface", "stone")


## Grass blocker boxes (see the header): Node3D children of GrassBlockers with meta half_extents,
## centred on the box. Built headless too (grass.gd's blocker map and
## tools/environment/check_clipping.gd read them).
func _grass_blockers() -> void:
	var gb := _group_node(self, "GrassBlockers")
	var boxes := []
	# Blockhouse lower storeys: the dovetailed log ends reach 2.27 m from the centre (collider
	# 2.25); the grown square's corners are chamfered, so the box is 0.2 m wider.
	for corner: Vector3 in [Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF)]:
		boxes.append([Transform3D(Basis(), corner + Vector3(0, 0.35, 0)), Vector3(2.45, 0.35, 2.45)])
	# Straw trusses: the bound straw bulges up to ~0.2 m past the 1.6 x 0.9 x 0.9 box.
	var cover := range_root.get_node_or_null("Cover")
	if cover:
		for body in cover.get_children():
			if body is StaticBody3D and String(body.get_meta(&"structure", "")) == "truss":
				boxes.append([(body as Node3D).transform, Vector3(1.0, 0.45, 0.65)])
	# The moving dummy's cross-foot stand (0.62 m) sweeps x = -5 .. 5 at 40 m.
	boxes.append([Transform3D(Basis(), Vector3(0, 0.04, FIRING_LINE_Z - 40.0)), Vector3(5.36, 0.05, 0.36)])
	for b: Array in boxes:
		var n := Node3D.new()
		n.transform = b[0]
		n.set_meta(&"half_extents", b[1])
		gb.add_child(n)


## The cabin's saddle-notched log ends stick out 0.25 m past each corner, in both directions.
func _cabin_log_end_colliders(parent: Node3D) -> void:
	var mn := Vector2(-11.5, 4.5)
	var mx := Vector2(-4.5, 9.5)
	for cx: float in [mn.x, mx.x]:
		for cz: float in [mn.y, mx.y]:
			var sx := -1.0 if cx == mn.x else 1.0        # outward along x
			var sz := -1.0 if cz == mn.y else 1.0        # outward along z
			# Logs of the north / south faces run along x: they poke out along x.
			_box_collider(parent, Vector3(cx + sx * 0.125, 1.5, cz - sz * 0.125), Vector3(0.25, 3.0, 0.33))
			# Logs of the east / west faces run along z.
			_box_collider(parent, Vector3(cx - sx * 0.125, 1.5, cz + sz * 0.125), Vector3(0.33, 3.0, 0.25))


## The cabin's gable roof as one convex prism (see ROOF_ORIGIN): a flat underside at the eave
## bottom, 10 cm eave faces, both slopes up to the ridge apex, gable overhangs at both ends.
func _cabin_roof_collider(parent: Node3D) -> void:
	var pts := PackedVector3Array()
	for x: float in [-ROOF_HALF_X, ROOF_HALF_X]:
		for z: float in [-ROOF_EAVE_Z, ROOF_EAVE_Z]:
			pts.append(Vector3(x, -ROOF_EAVE_Y, z))
			pts.append(Vector3(x, ROOF_EAVE_Y, z))
		pts.append(Vector3(x, ROOF_APEX_Y, 0.0))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var body := StaticBody3D.new()
	body.name = "cabin_roof"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.set_meta(&"trav", NO_TRAVERSE.duplicate())
	body.add_child(cs)
	body.position = ROOF_ORIGIN
	parent.add_child(body)


# --- Visuals ---------------------------------------------------------------------------------

func _kit(group: String, parent: Node3D) -> StructureMeshKit:
	if not _kits.has(group):
		_kits[group] = [StructureMeshKit.new(), parent]
	return _kits[group][0]


func _dress_fort() -> void:
	_palisade()
	_ribbands()
	_gate()
	_walkways()
	for corner: Vector3 in [Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF)]:
		_blockhouse(corner)
	_cabin()
	_storehouse()
	_supplies()
	_flag()


## Palisade: three log variants, one MultiMesh each (bark + hewn tip surfaces). Duplicate logs at
## the corners and logs buried inside the blockhouses are skipped (visual only).
func _palisade() -> void:
	if wall_cuts:
		wall_cuts.materials = _mats
	var meshes: Array[ArrayMesh] = []
	for v in 3:
		meshes.append(StructureGeometry.palisade_log(v, _mats))
	var per: Array = [[], [], []]
	var seen := {}
	for t in _logs:
		var key := Vector2i(roundi(t.origin.x * 100.0), roundi(t.origin.z * 100.0))
		if seen.has(key):
			continue
		seen[key] = true
		var inside := false
		for c: Vector3 in [Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF)]:
			if absf(t.origin.x - c.x) < 2.1 and absf(t.origin.z - c.z) < 2.1:
				inside = true
		if inside:
			continue
		per[_vrng.randi_range(0, 2)].append(t)
	var parent := fort.get_node("Palisade") as Node3D
	var tris := 0
	for v in 3:
		var list: Array = per[v]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[v]
		mm.instance_count = list.size()
		for i in list.size():
			var t: Transform3D = list[i]
			var s := _vrng.randf_range(0.99, 1.05)
			var yaw := Basis(Vector3.UP, _vrng.randf_range(-0.12, 0.12))
			var b := t.basis * yaw
			b = Basis(b.x * s, b.y, b.z * s)
			mm.set_instance_transform(i, Transform3D(b, t.origin))
			mm.set_instance_custom_data(i, Color(_vrng.randf(), _vrng.randf(), _vrng.randf_range(-1.0, 1.0), _vrng.randf_range(0.0, 0.7)))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Logs%d" % v
		mmi.multimesh = mm
		parent.add_child(mmi)
		if wall_cuts:
			for i in list.size():
				wall_cuts.set_log_visual((list[i] as Transform3D).origin, v, mm, i)
		var n := 0
		for si in meshes[v].get_surface_count():
			n += meshes[v].surface_get_array_index_len(si) / 3
		tris += n * list.size()
	stats["palisade"] = tris


## Ribband: a hewn rail pinned across the inside of the logs, 2.95 m up (it ties the stockade
## together). It stands 9 cm off the logs, inside the player capsule's clearance from the wall
## collider, so it needs no collider of its own.
func _ribbands() -> void:
	var kit := _kit("PalisadeTrim", fort.get_node("Palisade"))
	var y := 2.95
	var d := FORT_HALF - 0.245
	var runs := [
		[Vector3(-FORT_HALF + 2.3, y, -d), Vector3(-GATE_HALF - 0.35, y, -d)],
		[Vector3(GATE_HALF + 0.35, y, -d), Vector3(FORT_HALF - 0.25, y, -d)],
		[Vector3(-FORT_HALF + 0.25, y, d), Vector3(FORT_HALF - 2.3, y, d)],
		[Vector3(-d, y, -FORT_HALF + 2.3), Vector3(-d, y, FORT_HALF - 0.25)],
		[Vector3(d, y, -FORT_HALF + 0.25), Vector3(d, y, FORT_HALF - 2.3)],
	]
	for r: Array in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var dir := (b - a).normalized()
		var frame := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		kit.box(&"boards", Transform3D(frame, (a + b) * 0.5), Vector3(a.distance_to(b), 0.16, 0.09), StructureMeshKit.GRAIN_X,
				_vrng.randi_range(0, 3), _vrng.randf(), Color(0.92, 0.9, 0.86, 0.9))


func _gate() -> void:
	var kit := _kit("Gate", fort.get_node("Gate"))
	var r := _vrng
	for s: float in [-1.0, 1.0]:
		var x := s * (GATE_HALF + 0.1)
		kit.box(&"boards", Transform3D(Basis(), Vector3(x, 2.6, -FORT_HALF)), Vector3(0.46, 5.2, 0.46), StructureMeshKit.GRAIN_Y,
				r.randi_range(0, 3), r.randf(), Color(0.95, 0.93, 0.9, 1.0), StructureMeshKit.KIND_ENDGRAIN, 8, 0.0, 0.7)
		# Chamfer strips on the four vertical edges (edge wear catches them).
		for cx: float in [-1.0, 1.0]:
			for cz: float in [-1.0, 1.0]:
				var t := Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(x + cx * 0.215, 2.6, -FORT_HALF + cz * 0.215))
				kit.box(&"boards", t, Vector3(0.05, 5.2, 0.05), StructureMeshKit.GRAIN_Y, r.randi_range(0, 3), r.randf(),
						Color(1.05, 1.03, 1.0, 1.0), StructureMeshKit.KIND_ENDGRAIN, 4 | 8, 1.0)
		# Iron pintles on the inner faces (the gate's leaves hang on them, FortGate).
		for hy: float in [0.7, 3.4]:
			kit.box(&"boards", Transform3D(Basis(), Vector3(x - s * 0.25, hy, -FORT_HALF + 0.12)), Vector3(0.06, 0.1, 0.08),
					StructureMeshKit.GRAIN_X, 0, 0.0, Color.WHITE, StructureMeshKit.KIND_IRON)
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 5.0, -FORT_HALF)), Vector3(GATE_HALF * 2 + 0.8, 0.4, 0.45),
			StructureMeshKit.GRAIN_X, r.randi_range(0, 3), r.randf(), Color(0.95, 0.93, 0.9, 1.0))
	# A small shingled hood over the lintel.
	StructureGeometry.gable_roof(kit, Vector3(0, 5.2, -FORT_HALF), 0.3, GATE_HALF * 2 + 1.1, 35.0, PI * 0.5, r, detail, false)


func _walkways() -> void:
	var kit := _kit("Walkway", fort.get_node("Walkway"))
	var r := _vrng
	for s: float in [-1.0, 1.0]:
		var x0 := GATE_HALF + 0.25
		var x1 := FORT_HALF - 0.25
		if s < 0.0:
			x1 = FORT_HALF - 2.3          # the NW blockhouse covers the rest
		var xa := s * x0
		var xb := s * x1
		var lo := minf(xa, xb)
		var hi := maxf(xa, xb)
		# Deck: five boards across, each in 2-3 lengths with staggered joints.
		for j in 5:
			var zc := -FORT_HALF + 0.2 + 0.15 + j * 0.325
			var x := lo
			while x < hi - 0.05:
				var L := minf(r.randf_range(3.0, 5.0), hi - x)
				if hi - (x + L) < 0.8:
					L = hi - x
				var t := r.randf_range(0.86, 1.06)
				kit.box(&"boards", Transform3D(Basis(), Vector3(x + L * 0.5, 2.25 - r.randf_range(0.0, 0.004), zc)),
						Vector3(L - 0.006, 0.05, 0.3), StructureMeshKit.GRAIN_X, r.randi_range(0, 3), r.randf(), Color(t, t, t * 0.98, 1.0),
						StructureMeshKit.KIND_ENDGRAIN, 0, 0.0, 0.8)
				x += L
		if detail:
			# Joists under the deck.
			var jx := lo + 0.3
			while jx < hi - 0.1:
				kit.box(&"boards", Transform3D(Basis(), Vector3(jx, 2.175, -FORT_HALF + 1.0)), Vector3(0.12, 0.1, 1.6),
						StructureMeshKit.GRAIN_Z, r.randi_range(0, 3), r.randf(), Color(0.85, 0.83, 0.8, 0.7))
				jx += 1.55
		# Rim beam on the posts, ledger against the wall.
		kit.box(&"boards", Transform3D(Basis(), Vector3((lo + hi) * 0.5, (RIM_BOTTOM + 2.125) * 0.5, POST_Z)),
				Vector3(hi - lo, 2.125 - RIM_BOTTOM, 0.16), StructureMeshKit.GRAIN_X, r.randi_range(0, 3), r.randf(), Color(0.9, 0.88, 0.85, 0.85))
		kit.box(&"boards", Transform3D(Basis(), Vector3((lo + hi) * 0.5, 2.04, -FORT_HALF + 0.27)),
				Vector3(hi - lo, 0.17, 0.14), StructureMeshKit.GRAIN_X, r.randi_range(0, 3), r.randf(), Color(0.8, 0.78, 0.75, 0.6))
	for x: float in WALKWAY_POSTS:
		kit.box(&"boards", Transform3D(Basis(), Vector3(x, RIM_BOTTOM * 0.5, POST_Z)), Vector3(0.16, RIM_BOTTOM, 0.16),
				StructureMeshKit.GRAIN_Y, r.randi_range(0, 3), r.randf(), Color(0.95, 0.93, 0.9, 1.0), StructureMeshKit.KIND_ENDGRAIN, 8, 0.0, 0.6)
	# Ramps (same frame as their colliders).
	for s: float in [-1.0, 1.0]:
		var ramp_x := FORT_HALF - 2.0 if s > 0.0 else -(FORT_HALF - 4.0)
		_ramp_visual(kit, ramp_x, -FORT_HALF + 6.9, -FORT_HALF + 1.9, 2.3)
	# Ladders (same frame as their markers and rail colliders).
	for x: float in LADDER_X:
		_ladder_visual(kit, x)


## A ladder's rails (hewn, the size of their colliders) and round rungs (TravLaneClimb's pitch and radius: the rungs
## the climbing clips' fists close on), the top rung under the boards' edge.
func _ladder_visual(kit: StructureMeshKit, x: float) -> void:
	var r := _vrng
	var z := WALK_EDGE_Z + LADDER_OFF
	var h := WALK_TOP + LADDER_RAIL.y
	for sx: float in [-LADDER_HALF_W, LADDER_HALF_W]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(x + sx, h * 0.5, z - LADDER_RAIL.z * 0.4)), Vector3(LADDER_RAIL.x, h, LADDER_RAIL.z),
				StructureMeshKit.GRAIN_Y, r.randi_range(0, 3), r.randf(), Color(0.92, 0.9, 0.87, 1.0), StructureMeshKit.KIND_ENDGRAIN, 0, 0.0, 0.6)
	var pitch := TravLaneClimb.PITCH
	var rr := TravLaneClimb.RUNG_R
	var off := TravLaneClimb.first_rung_top()
	var k := 0
	while off + k * pitch <= WALK_TOP + 0.01:
		var y := off + k * pitch - rr
		_rung(kit, Vector3(x - LADDER_HALF_W, y, z), Vector3(x + LADDER_HALF_W, y, z), rr, r)
		k += 1


## A round rung from a to b (radius rr): one grid of 8 sides.
func _rung(kit: StructureMeshKit, a: Vector3, b: Vector3, rr: float, r: RandomNumberGenerator) -> void:
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
			U.append(Vector2((e - a).length() * 0.5, StructureMeshKit.row_v(row, float(j) / SEG)))
			C.append(Color(0.72, 0.66, 0.58, 1.0))
		rows_p.append(P)
		rows_n.append(N)
		rows_u.append(U)
		rows_c.append(C)
	kit.grid(&"boards", rows_p, rows_n, rows_u, rows_c)


func _ramp_visual(kit: StructureMeshKit, x: float, z_bottom: float, z_top: float, top_y: float) -> void:
	var t := _ramp_transform(x, z_bottom, z_top, top_y)
	var length := Vector2(z_bottom - z_top, top_y).length()
	var saved := kit.xform
	kit.xform = saved * t
	var r := _vrng
	# Stringers inside the slab thickness, planks across, cleats for footing.
	for sx: float in [-1.0, 1.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(sx * 0.5, -0.02, 0)), Vector3(0.1, 0.11, length),
				StructureMeshKit.GRAIN_Z, r.randi_range(0, 3), r.randf(), Color(0.85, 0.83, 0.8, 0.8))
	var z := -length * 0.5
	while z < length * 0.5 - 0.05:
		var bw := minf(0.2, length * 0.5 - z)
		var tint := r.randf_range(0.86, 1.06)
		kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.055, z + bw * 0.5)), Vector3(1.2, 0.04, bw - 0.012),
				StructureMeshKit.GRAIN_X, r.randi_range(0, 3), r.randf(), Color(tint, tint, tint * 0.98, 1.0))
		z += bw
	if detail:
		var cz := -length * 0.5 + 0.3
		while cz < length * 0.5 - 0.2:
			kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.092, cz)), Vector3(1.05, 0.035, 0.05),
					StructureMeshKit.GRAIN_X, r.randi_range(0, 3), r.randf(), Color(1.0, 0.98, 0.95, 1.0), StructureMeshKit.KIND_ENDGRAIN, 8, 0.8)
			cz += 0.42
	kit.xform = saved


func _blockhouse(corner: Vector3) -> void:
	var tag := "NW" if corner.x < 0.0 else "SE"
	var kit := _kit("Blockhouse_" + tag, fort.get_node("Blockhouse_" + tag))
	var r := _vrng
	StructureGeometry.hewn_box(kit, corner + Vector3(0, 1.75, 0), Vector3(4.5, 3.5, 4.5), 12, r)
	StructureGeometry.hewn_box(kit, corner + Vector3(0, 4.6, 0), Vector3(5.5, 2.2, 5.5), 8, r, PackedStringArray(), false)
	# Soffit of the jettied upper floor and the cantilevered joist ends.
	for i in 4:
		var out := [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][i] as Vector3
		var along := Vector3.UP.cross(out)
		var c := corner + Vector3(0, 3.5, 0)
		var a := c + out * 2.25 - along * 2.25
		var b := c + out * 2.25 + along * 2.25
		var e := c + out * 2.75 + along * 2.75
		var f := c + out * 2.75 - along * 2.75
		kit.quad(&"boards", a, b, e, f, Vector2(-2.25, StructureMeshKit.row_v(i, 0)), Vector2(2.25, StructureMeshKit.row_v(i, 0)),
				Vector2(2.75, StructureMeshKit.row_v(i, 1)), Vector2(-2.75, StructureMeshKit.row_v(i, 1)), Color(0.8, 0.78, 0.75, 0.55),
				StructureMeshKit.KIND_TEX, 0.0, PackedColorArray(), Vector3.DOWN)
		for k in 5:
			var s := -1.8 + k * 0.9
			var p := c + out * 2.5 + along * s + Vector3(0, -0.1, 0)
			kit.box(&"boards", Transform3D(Basis(along, Vector3.UP, out), p), Vector3(0.15, 0.2, 0.5), StructureMeshKit.GRAIN_Z,
					r.randi_range(0, 3), r.randf(), Color(0.9, 0.88, 0.85, 0.75))
		# Loopholes: two in the upper storey on every face, one below on the outer faces.
		for s: float in [-1.2, 1.2]:
			StructureGeometry.loophole(kit, c + out * 2.75 + along * s + Vector3(0, 1.05, 0), out, 0.1, 0.32, 0.03)
		var outer := out.dot((corner - Vector3.ZERO).normalized()) > 0.1
		if outer:
			StructureGeometry.loophole(kit, c + out * 2.25 + along * 0.0 + Vector3(0, -1.9, 0), out, 0.1, 0.3, 0.03)
	# Door on the parade side.
	var door_out := Vector3.BACK if corner.z < 0.0 else Vector3.FORWARD
	var door_x := corner.x + (1.2 if corner.x < 0.0 else -1.2)
	StructureGeometry.door(kit, Vector3(door_x, 0.0, corner.z + door_out.z * 2.25), door_out, 0.9, 1.85, r)
	StructureGeometry.gable_roof(kit, corner + Vector3(0, 5.7, 0), 5.5, 5.5, 32.0, 0.0, r, detail)


func _cabin() -> void:
	var kit := _kit("Cabin", fort.get_node("Cabin"))
	var r := _vrng
	var c := Vector3(-8, 1.5, 7)
	var size := Vector3(7, 3, 5)
	var ns := PackedFloat32Array()     # north / south faces (logs along x)
	for k in 11:
		ns.append(k * 0.3)
	var ew := PackedFloat32Array([0.0])  # east / west faces, half a course offset
	for k in 10:
		ew.append(0.15 + k * 0.3)
	ew.append(3.0)
	StructureGeometry.round_log_face(kit, Vector3(c.x, 0, c.z - 2.5), Vector3.FORWARD, 7.0, ns, r)
	StructureGeometry.round_log_face(kit, Vector3(c.x, 0, c.z + 2.5), Vector3.BACK, 7.0, ns, r)
	StructureGeometry.round_log_face(kit, Vector3(c.x - 3.5, 0, c.z), Vector3.LEFT, 5.0, ew, r)
	StructureGeometry.round_log_face(kit, Vector3(c.x + 3.5, 0, c.z), Vector3.RIGHT, 5.0, ew, r)
	kit.box(&"boards", Transform3D(Basis(), c), size - Vector3(0.05, 0.0, 0.05), StructureMeshKit.GRAIN_X, 0, 0.0,
			Color(0.3, 0.28, 0.26, 0.4), StructureMeshKit.KIND_TEX, 8)
	# Saddle-notched log ends at the four corners (0.25 m out; colliders in _cabin_log_end_colliders).
	var rr := 0.155
	for cx: float in [-11.5, -4.5]:
		for cz: float in [4.5, 9.5]:
			var sx := -1.0 if cx < -8.0 else 1.0
			var sz := -1.0 if cz < 7.0 else 1.0
			for k in 10:
				var y := 0.15 + k * 0.3
				StructureGeometry.log_end(kit, Vector3(cx - sx * 0.05, y, cz - sz * (rr - 0.035)), Vector3(sx, 0, 0), 0.3, rr, r)
			for k in range(1, 10):
				var y := k * 0.3
				StructureGeometry.log_end(kit, Vector3(cx - sx * (rr - 0.035), y, cz - sz * 0.05), Vector3(0, 0, sz), 0.3, rr, r)
	# Door, shuttered window, roof, chimney.
	StructureGeometry.door(kit, Vector3(-8, 0.0, 9.5), Vector3.BACK, 1.05, 2.02, r, 0.04)
	StructureGeometry.shutter(kit, Vector3(-10.25, 0, 9.5), Vector3.BACK, 0.62, 0.62, 1.12, r)
	StructureGeometry.gable_roof(kit, Vector3(-8, 3.0, 7), 5.0, 7.0, 35.0, PI / 2, r, detail)
	StructureGeometry.chimney(kit, Vector3(-4.5, 0.0, 7.25), Vector3(-3.42, 1.9, 8.75), Vector2(-4.88, 7.55), Vector2(-3.98, 8.45), 2.6, 5.55)
	if detail:
		_chimney_smoke()
	# Doorstep: a flat stone.
	StructureGeometry._stone_box(kit, Vector3(-8, 0.05, 9.8), Vector3(1.25, 0.1, 0.4), 1.0 / StructureGeometry.STONE_TILE, 8)


## A thin wisp of wood smoke from the cabin chimney (spec 8.1, optional): 64 lit billboard
## particles drifting with the wind (the wind_direction / wind_strength shader globals' project
## defaults). Off on low (structure_detail = false).
func _chimney_smoke() -> void:
	var wind := Vector2(0.866, -0.5)
	var strength := 0.3
	if ProjectSettings.has_setting("shader_globals/wind_direction"):
		var v: Variant = (ProjectSettings.get_setting("shader_globals/wind_direction") as Dictionary).get("value")
		if v is Vector2:
			wind = (v as Vector2).normalized()
	if ProjectSettings.has_setting("shader_globals/wind_strength"):
		strength = float((ProjectSettings.get_setting("shader_globals/wind_strength") as Dictionary).get("value", 0.3))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(wind.x, 0.0, wind.y) * (0.5 + 1.5 * strength) + Vector3(0, 0.08, 0)
	pm.damping_min = 0.05
	pm.damping_max = 0.15
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.3))
	sc.add_point(Vector2(1.0, 3.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.77, 0.75, 0.0))
	ramp.set_color(1, Color(0.92, 0.91, 0.89, 0.0))
	ramp.add_point(0.1, Color(0.76, 0.75, 0.73, 0.2))
	ramp.add_point(0.5, Color(0.86, 0.85, 0.83, 0.09))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(0.5, 0.0)
	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 1))
	pg.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = pg
	puff.width = 64
	puff.height = 64
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = puff
	mat.roughness = 1.0
	mat.disable_receive_shadows = false
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = mat
	var p := GPUParticles3D.new()
	p.name = "ChimneySmoke"
	p.amount = 64
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.process_material = pm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 10, 12))
	p.position = Vector3(-4.43, 5.8, 8.0)
	fort.get_node("Cabin").add_child(p)


func _storehouse() -> void:
	var kit := _kit("Storehouse", fort.get_node("Storehouse"))
	var r := _vrng
	StructureGeometry.hewn_box(kit, Vector3(9, 1.2, 4), Vector3(5, 2.4, 4), 8, r)
	StructureGeometry.door(kit, Vector3(6.5, 0.0, 4.0), Vector3.LEFT, 1.0, 1.85, r, 0.035)
	StructureGeometry.gable_roof(kit, Vector3(9, 2.4, 4), 4.0, 5.0, 30.0, 0.0, r, detail)


func _supplies() -> void:
	var kit := _kit("Supplies", fort.get_node("Supplies"))
	var r := _vrng
	for body in fort.get_node("Supplies").get_children():
		var sb := body as StaticBody3D
		if sb == null:
			continue
		match String(sb.get_meta(&"structure", "")):
			"crate":
				StructureGeometry.crate(kit, sb.transform, 0.8, r)
			"barrel":
				var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU), sb.position)
				StructureGeometry.barrel(kit, t, 0.32, 1.0, r)


func _flag() -> void:
	var node := fort.get_node("Flag") as Node3D
	var kit := _kit("Flag", node)
	StructureGeometry.pole(kit, Vector3(-6, 0, -2), -0.1, 10.0, 0.085, 0.055, _vrng)
	# Cleat and a trodden base.
	kit.box(&"boards", Transform3D(Basis(), Vector3(-5.92, 1.3, -2)), Vector3(0.04, 0.16, 0.05), StructureMeshKit.GRAIN_Y, 1, 0.0)
	var flag := MeshInstance3D.new()
	flag.name = "FlagCloth"
	flag.mesh = StructureGeometry.flag_mesh(1.8, 1.1, _mats[&"flag"])
	flag.position = Vector3(-6.0 + 0.08, 9.3, -2)
	flag.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	node.add_child(flag)


func _dress_range() -> void:
	var r := _vrng
	var rail := range_root.get_node("FiringLine") as Node3D
	var kit := _kit("FiringLine", rail)
	var z0 := FIRING_LINE_Z
	kit.box(&"boards", Transform3D(Basis(), Vector3(0, 0.55, z0)), Vector3(8, 0.1, 0.12), StructureMeshKit.GRAIN_X, 2, r.randf())
	for x: float in [-4.0, 0.0, 4.0]:
		kit.box(&"boards", Transform3D(Basis(), Vector3(x, 0.25, z0)), Vector3(0.12, 0.62, 0.12), StructureMeshKit.GRAIN_Y,
				r.randi_range(0, 3), r.randf(), Color(1, 1, 1, 1), StructureMeshKit.KIND_ENDGRAIN, 0, 0.0, 0.6)
	var cover := range_root.get_node("Cover") as Node3D
	var ck := _kit("Cover", cover)
	for body in cover.get_children():
		var sb := body as StaticBody3D
		if sb and String(sb.get_meta(&"structure", "")) == "truss":
			StructureGeometry.straw_truss(ck, sb.transform, Vector3(1.6, 0.9, 0.9), r)


## Woodpile against the cabin's north wall, a chopping block with the axe, the stone fire pit.
func _props() -> void:
	var node := _group_node(fort, "Props")
	var kit := _kit("Props", node)
	var r := _vrng
	StructureGeometry.woodpile(kit, Transform3D(Basis(), Vector3(-9.0, 0.0, 4.12)), 3.2, 1.0, 0.6, r)
	StructureGeometry.log_round(kit, CHOPPING_BLOCK, 0.3, 0.55, r)
	var scenes := {
		"fire_pit": "res://assets/environment/structures/props/stone_fire_pit_lod0.glb",
		"axe": "res://assets/environment/structures/props/wooden_axe_lod0.glb",
		"hatchet": "res://assets/environment/structures/props/hatchet_lod0.glb",
	}
	var place := {
		"fire_pit": Transform3D(Basis(Vector3.UP, 0.4), FIRE_PIT + Vector3(0, 0.19, 0)),
		# Axe: head down in the block's top, handle up at 35 deg. Hatchet lying by the block.
		"axe": Transform3D(Basis(Vector3.UP, 0.9) * Basis(Vector3.RIGHT, PI - 0.6), CHOPPING_BLOCK + Vector3(0.02, 0.93, 0.0)),
		"hatchet": Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.BACK, PI * 0.5), CHOPPING_BLOCK + Vector3(-0.1, 0.03, -0.55)),
	}
	for k: String in scenes:
		var ps := load(scenes[k]) as PackedScene
		if ps == null:
			push_warning("FrontierStructures: missing prop %s" % scenes[k])
			continue
		var inst := ps.instantiate() as Node3D
		inst.name = k
		inst.transform = place[k]
		node.add_child(inst)


func _commit() -> void:
	var total := 0
	for group: String in _kits:
		var kit: StructureMeshKit = _kits[group][0]
		var parent: Node3D = _kits[group][1]
		if kit.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.name = group + "Mesh"
		mi.mesh = kit.commit(_mats)
		parent.add_child(mi)
		var n := kit.triangle_count()
		stats[group] = n
		total += n
	stats["meshes_total"] = total + int(stats.get("palisade", 0))


## Conservative box occluders strictly inside opaque geometry (spec 8.5): a thin slab in the
## palisade's centre plane (logs overlap there) up to 3.3 m, below the lowest hewn point; the
## blockhouse, cabin and storehouse boxes inset by 5 cm.
func _occluders() -> void:
	var node := _group_node(self, "Occluders")
	var top := 3.3
	var segs := [
		[Vector3(-FORT_HALF + 2.3, 0, -FORT_HALF), Vector3(-GATE_HALF - 0.1, 0, -FORT_HALF)],
		[Vector3(GATE_HALF + 0.1, 0, -FORT_HALF), Vector3(FORT_HALF - 0.1, 0, -FORT_HALF)],
		[Vector3(-FORT_HALF + 0.1, 0, FORT_HALF), Vector3(FORT_HALF - 2.3, 0, FORT_HALF)],
		[Vector3(-FORT_HALF, 0, -FORT_HALF + 2.3), Vector3(-FORT_HALF, 0, FORT_HALF - 0.1)],
		[Vector3(FORT_HALF, 0, -FORT_HALF + 0.1), Vector3(FORT_HALF, 0, FORT_HALF - 2.3)],
	]
	for s: Array in segs:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var dir := (b - a).normalized()
		var occ := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = Vector3(a.distance_to(b), top, 0.04)
		occ.occluder = box
		occ.transform = Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)), (a + b) * 0.5 + Vector3(0, top * 0.5, 0))
		node.add_child(occ)
	var boxes := [
		[Vector3(-FORT_HALF, 1.75, -FORT_HALF), Vector3(4.5, 3.5, 4.5)],
		[Vector3(-FORT_HALF, 4.6, -FORT_HALF), Vector3(5.5, 2.2, 5.5)],
		[Vector3(FORT_HALF, 1.75, FORT_HALF), Vector3(4.5, 3.5, 4.5)],
		[Vector3(FORT_HALF, 4.6, FORT_HALF), Vector3(5.5, 2.2, 5.5)],
		[Vector3(-8, 1.5, 7), Vector3(7, 3, 5)],
		[Vector3(9, 1.2, 4), Vector3(5, 2.4, 4)],
	]
	for bx: Array in boxes:
		var occ := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = (bx[1] as Vector3) - Vector3(0.1, 0.1, 0.1)
		occ.occluder = box
		occ.position = bx[0]
		node.add_child(occ)


# --- Collider helpers --------------------------------------------------------------------------

static func rot_y_of(a: float) -> Vector3:
	return Vector3(0.0, a, 0.0)


func _group_node(parent: Node3D, n: String) -> Node3D:
	var existing := parent.get_node_or_null(n) as Node3D
	if existing:
		return existing
	var g := Node3D.new()
	g.name = n
	parent.add_child(g)
	return g


func _box_collider(parent: Node3D, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	body.rotation = rot
	parent.add_child(body)
	return body


## A ladder up to the firing step (LADDER_X): its TravLadder marker (the climb) and its two rails' colliders (no
## traversal geometry: nothing vaults them, and no hang climb starts beside them, TraversalProbe.room_below).
func _ladder(parent: Node3D, x: float) -> void:
	var z := WALK_EDGE_Z + LADDER_OFF
	var m := TravLadder.new()
	m.name = "Ladder_" + ("E" if x > 0.0 else "W")
	m.debug_draw = false
	m.position = Vector3(x, 0.0, z)
	m.bottom = Vector3.ZERO
	m.top = Vector3(0.0, WALK_TOP, 0.0)
	m.outward = Vector3(0, 0, 1)
	m.width = LADDER_HALF_W * 2.0
	m.rung_pitch = TravLaneClimb.PITCH
	m.rung_offset = TravLaneClimb.first_rung_top()
	m.rung_radius = TravLaneClimb.RUNG_R
	parent.add_child(m)
	var h := WALK_TOP + LADDER_RAIL.y
	for sx: float in [-LADDER_HALF_W, LADDER_HALF_W]:
		_no_traverse(_box_collider(parent, Vector3(x + sx, h * 0.5, z - LADDER_RAIL.z * 0.4), Vector3(LADDER_RAIL.x, h, LADDER_RAIL.z)))


## Tags a collider body's shapes as not traversal geometry (TravShapeRegistry.gate: "excluded").
static func _no_traverse(body: StaticBody3D) -> StaticBody3D:
	for c in body.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_meta(&"trav", NO_TRAVERSE.duplicate())
	return body


func _cyl_collider(parent: Node3D, pos: Vector3, radius: float, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)
	return body


## The original _ramp(): a plank ramp rising north (toward -Z) whose top surface runs from the
## ground at z_bottom to top_y at z_top.
static func _ramp_transform(x: float, z_bottom: float, z_top: float, top_y: float) -> Transform3D:
	var thickness := 0.15
	var run := z_bottom - z_top
	var angle := atan2(top_y, run)
	var normal := Vector3(0, cos(angle), sin(angle))
	var mid := Vector3(x, top_y * 0.5, (z_bottom + z_top) * 0.5)
	return Transform3D(Basis.from_euler(Vector3(angle, 0, 0)), mid - normal * thickness * 0.5)


func _ramp_collider(parent: Node3D, x: float, z_bottom: float, z_top: float, top_y: float) -> void:
	var run := z_bottom - z_top
	var length := Vector2(run, top_y).length()
	var t := _ramp_transform(x, z_bottom, z_top, top_y)
	var body := _box_collider(parent, t.origin, Vector3(1.2, 0.15, length))
	body.rotation.x = atan2(top_y, run)
