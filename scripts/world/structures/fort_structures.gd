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
##     straw trusses' bulging straw, the moving dummy's track --
##     so scripts/world/terrain/grass.gd keeps grass out of them. No physics, no rendering.
##   * Traversal: the cabin box and the cabin roof carry meta trav = {no_traverse: true} on their
##     CollisionShape3D (traversal review 9.6: the free-run climbed the 3.0 m walls into the roof).
##   * The palisade, the gate, the firing step, the ramps, the ladders, the blockhouses and the flag pole are NOT here any
##     more (user 2026-09-28: "the fort should be recreated from builder pieces"): they are build-menu pieces stamped
##     by FortPlan.stamp_structure (data/building/fort_structure.json; FortPieces, BuildGeometry, PalisadeCuts for the
##     windows). What is left is the cabin, the storehouse, the supplies, the range, the dummies and the props. The
##     level rng is still burned as the classic palisade's log heights burned it (_burn_palisade_rng), so the
##     vegetation that follows is where it always was.
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
const WALL_HEIGHT := 4.2             ## (the classic palisade's log height: only _burn_palisade_rng counts logs with it)
const LOG_R := 0.19

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
## The hung doors of the cabin and the storehouse (FortHollow; E opens them): name -> BuildDoor. (The blockhouse pieces
## hang their own: BuiltPiece.door.)
var doors := {}
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
	_burn_palisade_rng(rng)

	# Cabin (with its chimney) and storehouse.
	var cabin := _group_node(fort, "Cabin")
	# Traversal: the 3.0 m walls are not a climb. Without this the free-run planned a
	# climb_hang_3m up the walls into the roof (traversal review 9.6; see _cabin_roof_collider).
	_hollow_colliders(cabin, "cabin")
	_box_collider(cabin, Vector3(-4.43, 3.4, 8), Vector3(0.9, 1.6, 0.9))    # Chimney: stone by its size.
	var store := _group_node(fort, "Storehouse")
	_hollow_colliders(store, "storehouse")

	# Supplies: crates (random turn from the level rng), barrels.
	var supplies := _group_node(fort, "Supplies")
	for p: Vector3 in [Vector3(5, 0.4, -6), Vector3(5.9, 0.4, -6.2), Vector3(5.4, 1.2, -6.1), Vector3(-10, 0.4, -4), Vector3(13.6, 0.4, -9)]:      # (the last one moved from x 12 off the east ramp's foot)
		var body := _box_collider(supplies, p, Vector3(0.8, 0.8, 0.8), rot_y_of(rng.randf_range(-0.3, 0.3)))
		body.set_meta(&"structure", "crate")
	for p: Vector3 in [Vector3(7, 0.5, -3), Vector3(7.7, 0.5, -3.4), Vector3(-5, 0.5, -10), Vector3(-5.8, 0.5, -10.3), Vector3(11, 0.5, 8)]:
		var body := _cyl_collider(supplies, p, 0.32, 1.0)
		body.set_meta(&"structure", "barrel")


## The classic palisade drew a height for each of its logs from the level's rng (WALL_HEIGHT +- 0.25 m: 4 walls of 32 m in
## logs of 0.38 m, the gate's gap left out). It is a build-menu piece now, but the vegetation that follows takes its
## random numbers from the same generator: the same draws are made and thrown away, so the trees stand where they did.
func _burn_palisade_rng(rng: RandomNumberGenerator) -> void:
	for wall: Array in [[Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, -FORT_HALF), true],
			[Vector3(-FORT_HALF, 0, FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF), false],
			[Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(-FORT_HALF, 0, FORT_HALF), false],
			[Vector3(FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF), false]]:
		var a: Vector3 = wall[0]
		var b: Vector3 = wall[1]
		var n := int(a.distance_to(b) / (LOG_R * 2.0))
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			if wall[2] and absf(p.x) < GATE_HALF:
				continue
			rng.randf_range(-0.25, 0.25)


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
	# (The blockhouses are build pieces now: BuildGrass keeps grass off their footprints.)
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
	_cabin()
	_storehouse()
	_supplies()


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
	var hb: Dictionary = FortHollow.BUILDINGS["cabin"]
	FortHollow.door_wall(kit, hb, r)                  # the south face, the doorway cut through its logs
	StructureGeometry.round_log_face(kit, Vector3(c.x - 3.5, 0, c.z), Vector3.LEFT, 5.0, ew, r)
	StructureGeometry.round_log_face(kit, Vector3(c.x + 3.5, 0, c.z), Vector3.RIGHT, 5.0, ew, r)
	FortHollow.interior(kit, hb, r)
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
	StructureGeometry.door(kit, Vector3(-8, 0.0, 9.5), Vector3.BACK, 1.05, FortHollow.lintel_y(hb), r, 0.04, false)
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
	var hb: Dictionary = FortHollow.BUILDINGS["storehouse"]
	StructureGeometry.hewn_box(kit, Vector3(9, 1.2, 4), Vector3(5, 2.4, 4), 8, r, PackedStringArray(["-x"]), true, false)
	FortHollow.door_wall(kit, hb, r)
	FortHollow.interior(kit, hb, r)
	StructureGeometry.door(kit, Vector3(6.5, 0.0, 4.0), Vector3.LEFT, 1.0, FortHollow.lintel_y(hb), r, 0.035, false)
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
	stats["meshes_total"] = total


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


## The hollow colliders of a fort building (FortHollow) and its hung door, under `parent`.
func _hollow_colliders(parent: Node3D, name: String) -> void:
	var b: Dictionary = FortHollow.BUILDINGS[name]
	for bx: Array in FortHollow.collider_boxes(b):
		_no_traverse(_box_collider(parent, bx[0], bx[1]))
	doors[name] = FortHollow.hang_door(parent, b)
	if visuals:
		FortHollow.light(parent, b)


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
