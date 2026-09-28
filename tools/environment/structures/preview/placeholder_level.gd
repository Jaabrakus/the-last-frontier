extends Node3D
## TOOL COPY, not game code: frontier_level.gd as it was before the textured fort was wired in
## (2026-09-24 10:56, placeholder _fort() / _range()). Used only for before/after renders:
##   Godot --path . -s tools/environment/structures/preview/run_scenic_shots.gd -- \
##       level_script=res://tools/environment/structures/preview/placeholder_level.gd ...
## Test level: a small colonial stockade fort in a forest clearing, with a
## shooting range outside the north gate. The fort and range are built in code here;
## sky/light, ground and forest come from the environment builders below.
##
##   Fort: 32 m square palisade, gate in the north wall, two blockhouses,
##         a cabin, a storehouse, crates, barrels and a flag.
##   Range: firing line just outside the gate, straw dummies at 10-120 m,
##          one moving dummy, hay bales for cover.
##   Forest: trees all around, leaving the range lane clear.
##
## Environment build order (look-dev spec, graph_analysis/visual/lookdev_spec.md, section 11):
##   WorldSettings.from_args()        quality preset (quality=low|medium|high, default high)
##   EnvironmentRig.build()           sky, sun, fog, post, viewport settings     (package A)
##   FrontierTerrain.build()          ground, grass, ground colliders            (package B)
##   _fort(), _range()                structures (this file)                     (package D)
##   FrontierVegetation.build()       trees, undergrowth, logs, rocks            (package C)
## The level's rng (seed 1776) is shared by _fort, _range and the vegetation, in that order.

const FORT_HALF := 16.0
const GATE_HALF := 3.0
const FIRING_LINE_Z := -FORT_HALF - 4.0
const RANGE_DISTANCES := [10, 25, 50, 75, 100, 120]

var rng := RandomNumberGenerator.new()
var settings: WorldSettings
var environment_rig: EnvironmentRig
var terrain: FrontierTerrain
var vegetation: FrontierVegetation
var _mats := {}


func _ready() -> void:
	rng.seed = 1776
	settings = WorldSettings.from_args()
	environment_rig = EnvironmentRig.new()
	environment_rig.name = "EnvironmentRig"
	add_child(environment_rig)
	environment_rig.build(settings)
	terrain = FrontierTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(settings)
	_fort()
	_range()
	vegetation = FrontierVegetation.new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	vegetation.build(settings, rng)
	var player := FrontierPlayer.new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 0.1, 6)
	environment_rig.track(player)
	_audio(player)


## Sound (scripts/audio/): buses and voice pool, the forest ambience, and the listeners that
## voice the player's footsteps and weapons. Missing sound files are skipped.
func _audio(player: FrontierPlayer) -> void:
	Sfx.setup(self)
	var bed := AmbienceBed.new()
	bed.name = "AmbienceBed"
	bed.player = player
	add_child(bed)
	var steps := Footsteps.new()
	steps.name = "Footsteps"
	steps.player = player
	player.add_child(steps)
	var weapons := WeaponAudio.new()
	weapons.name = "WeaponAudio"
	weapons.player = player
	player.add_child(weapons)


func _mat(key: String, color: Color, roughness := 0.9) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


# --- Static geometry helpers -------------------------------------------------------

func _box(pos: Vector3, size: Vector3, mat: Material, rot_y := 0.0, collide := true) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	root.add_child(m)
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	return root


func _cylinder(pos: Vector3, radius: float, height: float, mat: Material, collide := true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collide else Node3D.new()
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	m.mesh = c
	m.material_override = mat
	root.add_child(m)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		root.add_child(cs)
	root.position = pos
	add_child(root)
	return root


## Gable roof: two sloped boards over a w × d footprint whose eaves are at y.
func _roof(center: Vector3, w: float, d: float, pitch_deg: float, mat: Material, rot_y := 0.0) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = rot_y
	add_child(root)
	var half := w * 0.5 + 0.3
	var slope := half / cos(deg_to_rad(pitch_deg))
	var rise := half * tan(deg_to_rad(pitch_deg))
	for side: float in [-1.0, 1.0]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(slope, 0.12, d + 0.6)
		m.mesh = b
		m.material_override = mat
		m.position = Vector3(side * half * 0.5, rise * 0.5, 0)
		m.rotation.z = -side * deg_to_rad(pitch_deg)
		root.add_child(m)


# --- Fort ----------------------------------------------------------------------------

func _fort() -> void:
	var log_mat := _mat("log", Color(0.42, 0.31, 0.2))
	var height := 4.2
	var r := 0.19
	var logs: Array[Transform3D] = []
	var walls := [
		[Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, -FORT_HALF), true],   # North (gate)
		[Vector3(-FORT_HALF, 0, FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF), false],
		[Vector3(-FORT_HALF, 0, -FORT_HALF), Vector3(-FORT_HALF, 0, FORT_HALF), false],
		[Vector3(FORT_HALF, 0, -FORT_HALF), Vector3(FORT_HALF, 0, FORT_HALF), false],
	]
	for wall in walls:
		var a: Vector3 = wall[0]
		var b: Vector3 = wall[1]
		var n := int(a.distance_to(b) / (r * 2.0))
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			if wall[2] and absf(p.x) < GATE_HALF:
				continue
			var h := height + rng.randf_range(-0.25, 0.25)
			var t := Transform3D(Basis().scaled(Vector3(1, h / height, 1)), p + Vector3(0, h * 0.5, 0))
			logs.append(t)
		# Collision: one box per wall segment (two for the gate wall).
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var rot := atan2(-dir.z, dir.x)
		if wall[2]:
			var seg := FORT_HALF - GATE_HALF
			_wall_collider(Vector3(-FORT_HALF + seg * 0.5, height * 0.5, a.z), Vector3(seg, height, r * 2), 0.0)
			_wall_collider(Vector3(FORT_HALF - seg * 0.5, height * 0.5, a.z), Vector3(seg, height, r * 2), 0.0)
		else:
			_wall_collider((a + b) * 0.5 + Vector3(0, height * 0.5, 0), Vector3(length, height, r * 2), rot)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.55   # Sharpened tops read as a stockade.
	cyl.bottom_radius = r
	cyl.height = height
	cyl.radial_segments = 7
	cyl.material = log_mat
	mm.mesh = cyl
	mm.instance_count = logs.size()
	for i in logs.size():
		mm.set_instance_transform(i, logs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

	# Gate posts and lintel.
	for s: float in [-1.0, 1.0]:
		_cylinder(Vector3(s * (GATE_HALF + 0.1), 2.6, -FORT_HALF), 0.28, 5.2, log_mat)
	_box(Vector3(0, 5.0, -FORT_HALF), Vector3(GATE_HALF * 2 + 0.8, 0.4, 0.45), log_mat)

	# Firing step (walkway) along the inside of the north wall.
	var plank := _mat("plank", Color(0.52, 0.4, 0.27))
	for s: float in [-1.0, 1.0]:
		var cx := s * (GATE_HALF + (FORT_HALF - GATE_HALF) * 0.5)
		_box(Vector3(cx, 2.2, -FORT_HALF + 1.0), Vector3(FORT_HALF - GATE_HALF - 0.5, 0.15, 1.6), plank)
		# The ramp reaches 2.5 cm above the walkway top (2.275 m) just before its
		# front edge (z = -14.2), so the player steps down onto it instead of
		# catching on the edge.
		# West ramp sits clear of the north-west blockhouse (x < -13.75).
		var ramp_x := FORT_HALF - 2.0 if s > 0.0 else -(FORT_HALF - 4.0)
		_ramp(ramp_x, -FORT_HALF + 6.9, -FORT_HALF + 1.9, 2.3, plank)

	# Blockhouses on the north-west and south-east corners.
	_blockhouse(Vector3(-FORT_HALF, 0, -FORT_HALF))
	_blockhouse(Vector3(FORT_HALF, 0, FORT_HALF))

	# Cabin and storehouse.
	var wall_mat := _mat("cabin", Color(0.48, 0.35, 0.22))
	var roof_mat := _mat("shingle", Color(0.3, 0.24, 0.19))
	_box(Vector3(-8, 1.5, 7), Vector3(7, 3, 5), wall_mat)
	_roof(Vector3(-8, 3.0, 7), 5.0, 7.0, 35.0, roof_mat, PI / 2)
	_box(Vector3(-8, 1.1, 9.55), Vector3(1.1, 2.1, 0.1), _mat("door", Color(0.25, 0.17, 0.1)), 0.0, false)
	_box(Vector3(-4.43, 3.4, 8), Vector3(0.9, 1.6, 0.9), _mat("stone", Color(0.5, 0.49, 0.46)))  # Chimney.
	_box(Vector3(9, 1.2, 4), Vector3(5, 2.4, 4), wall_mat)
	_roof(Vector3(9, 2.4, 4), 4.0, 5.0, 30.0, roof_mat)

	# Supplies: crates, barrels, powder kegs.
	var crate := _mat("crate", Color(0.6, 0.47, 0.3))
	var barrel := _mat("barrel", Color(0.4, 0.28, 0.17))
	for p: Vector3 in [Vector3(5, 0.4, -6), Vector3(5.9, 0.4, -6.2), Vector3(5.4, 1.2, -6.1), Vector3(-10, 0.4, -4), Vector3(12, 0.4, -9)]:
		_box(p, Vector3(0.8, 0.8, 0.8), crate, rng.randf_range(-0.3, 0.3))
	for p: Vector3 in [Vector3(7, 0.5, -3), Vector3(7.7, 0.5, -3.4), Vector3(-5, 0.5, -10), Vector3(-5.8, 0.5, -10.3), Vector3(11, 0.5, 8)]:
		_cylinder(p, 0.32, 1.0, barrel)

	# Flag pole in the parade ground.
	_cylinder(Vector3(-6, 5, -2), 0.07, 10.0, _mat("pole", Color(0.55, 0.45, 0.33)), true)
	var flag := _box(Vector3(-5.1, 9.3, -2), Vector3(1.8, 1.1, 0.03), _mat("flag", Color(0.62, 0.14, 0.12)), 0.0, false)
	flag.rotation.z = 0.03


func _wall_collider(pos: Vector3, size: Vector3, rot_y: float) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	body.rotation.y = rot_y
	add_child(body)


## A plank ramp rising north (toward -Z) whose top surface runs from the
## ground at z_bottom to height top_y at z_top.
func _ramp(x: float, z_bottom: float, z_top: float, top_y: float, mat: Material) -> void:
	var thickness := 0.15
	var run := z_bottom - z_top
	var angle := atan2(top_y, run)
	var length := Vector2(run, top_y).length()
	var normal := Vector3(0, cos(angle), sin(angle))      # Box +Y after rotating about X by angle.
	var mid := Vector3(x, top_y * 0.5, (z_bottom + z_top) * 0.5)
	var b := _box(mid - normal * thickness * 0.5, Vector3(1.2, thickness, length), mat)
	b.rotation.x = angle


func _blockhouse(corner: Vector3) -> void:
	var wall := _mat("blockhouse", Color(0.4, 0.3, 0.2))
	_box(corner + Vector3(0, 1.75, 0), Vector3(4.5, 3.5, 4.5), wall)
	_box(corner + Vector3(0, 4.6, 0), Vector3(5.5, 2.2, 5.5), wall)       # Overhanging upper floor.
	_roof(corner + Vector3(0, 5.7, 0), 5.5, 5.5, 32.0, _mat("shingle", Color(0.3, 0.24, 0.19)))


# --- Shooting range ------------------------------------------------------------------

func _range() -> void:
	var z0 := FIRING_LINE_Z
	# Firing line rail.
	var rail := _mat("rail", Color(0.5, 0.38, 0.25))
	_box(Vector3(0, 0.55, z0), Vector3(8, 0.1, 0.12), rail, 0.0, true)
	for x: float in [-4.0, 0.0, 4.0]:
		_box(Vector3(x, 0.3, z0), Vector3(0.12, 0.6, 0.12), rail)

	var lanes := [-2.5, 0.0, 2.5]
	for i in RANGE_DISTANCES.size():
		var d: int = RANGE_DISTANCES[i]
		var x: float = lanes[i % lanes.size()]
		var dummy := TargetDummy.new()
		dummy.position = Vector3(x, 0, z0 - d)
		add_child(dummy)
		var sign := Label3D.new()
		sign.text = "%d m" % d
		sign.font_size = 96
		sign.pixel_size = 0.006
		sign.outline_size = 12
		sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sign.position = Vector3(x, 2.3, z0 - d)
		add_child(sign)

	# A dummy that strafes across the lane at 40 m.
	var mover := TargetDummy.new()
	mover.position = Vector3(-5, 0, z0 - 40)
	mover.move_offset = Vector3(10, 0, 0)
	mover.move_period = 5.0
	add_child(mover)

	# Hay bales for cover along the lane.
	var hay := _mat("hay", Color(0.76, 0.65, 0.36), 1.0)
	for p: Vector3 in [Vector3(-5, 0.45, z0 - 15), Vector3(5, 0.45, z0 - 30), Vector3(-4.5, 0.45, z0 - 60), Vector3(4.5, 0.45, z0 - 85)]:
		_box(p, Vector3(1.6, 0.9, 0.9), hay, rng.randf_range(-0.4, 0.4))
