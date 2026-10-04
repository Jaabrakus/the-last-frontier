class_name DuelArena
extends Node3D
## The duel's ground (DuelMode; the user, 2026-10-04: "lets build a test game where it is 1v1 npc can find cover aim and etc"):
## an open, nearly flat stretch of the open land east of the fort and west of the river (CENTER x 520, z 0: the ground within
## 0.9 m over 56 x 46 m and no woods there, data/world/squares.json's open_land; 520 m from the fort, 100 m past the fort's
## forest, 360 m short of the river), SIZE 50 x 40 m, its corners staked. Two spawns SPAWN_X either side of the middle on the
## long axis (42 m apart), each 3.5 m behind a stack of crates that hides it from the other. Between them PIECES of cover laid
## the same for both sides (side B's are side A's turned half round the middle), so each has the same choices, and a cart in
## the middle: 15 pieces in all, the project's own props (the fort's kit: StructureMeshKit, StructureGeometry,
## StructureMaterials; the forest's boulder and trees: VegAssets, StoryLayerProps.grove):
##   crates     a stack of 0.58 m crates two high and three long, one more on the middle (1.16 m, 1.74 m over the middle)
##   wall       a low fieldstone wall, 3.2 m long, 1.15 m high
##   fence      a plank fence section on two posts, 3 m long, 1.4 m high (too high to shoot over: round its ends)
##   woodpile   split firewood stacked between stakes, 3.2 m long, 1.15 m high (the log pile)
##   boulder    the forest's mossy boulder, about 1.8 m high
##   tree       a lone oak (its trunk to hide behind; climbable as the forest's)
##   barrels    three barrels in a knot (low: a crouching man's head shows over them)
##   cart       a two-wheeled cart with two small crates in its bed (1.17 m; the gap under it open)
## A low thing (1.15 m: over a crouching man's head, under a standing man's musket) hides a crouching man and is shot over
## standing; a tall one hides a standing man and is shot past by a step out (NpcCover). Headless: the colliders only (the tests), as the fort's structures. rebuild() puts every piece back as it
## was (the duel's reset each round) and tells the walk grid (WalkGrid.dirty); clear_dropped() takes away what was left
## lying about in the fight (the fallen man's packs, balls and arrows, thrown weapons, a weapon put down, the Sway's earth
## walls, pillars, stones and their hollows).

const CENTER := Vector2(520.0, 0.0)
const SIZE := Vector2(50.0, 40.0)
const SPAWN_X := 21.0
## [kind, x, z, yaw deg] on side A (x < 0), about the middle; side B's: (-x, -z, yaw + 180).
const PIECES := [
	["crates", -17.5, 0.0, 0.0],
	["wall", -9.5, -6.0, 0.0],
	["fence", -12.5, 10.5, 0.0],
	["woodpile", -4.5, 9.0, 0.0],
	["boulder", -4.0, -13.0, 30.0],
	["tree", -15.0, -12.0, 0.0],
	["barrels", -6.5, 3.5, 0.0],
]
const MIDDLE := [["cart", 0.0, 0.0, 0.0]]
const CRATE := 0.58
const CART_CRATE := 0.45
## What clear_dropped takes away reaches this far past the arena's edge (m).
const CLEAR_MARGIN := 15.0
const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")

var visuals := true
## The pieces as built (rebuild() makes them again): one node each, its kind in meta "duel_piece".
var props: Node3D
var _mats := {}


static func make(parent: Node) -> DuelArena:
	var a := DuelArena.new()
	a.name = "DuelArena"
	parent.add_child(a)
	return a


func _ready() -> void:
	visuals = DisplayServer.get_name() != "headless"
	if visuals:
		_mats = StructureMaterials.all()
	rebuild()
	_stakes()


## The arena's middle on the ground.
func center() -> Vector3:
	return _ground(CENTER.x, CENTER.y)


## Spawn `i` (0: side A, x < 0; 1: side B): on the ground, facing the other.
func spawn(i: int) -> Transform3D:
	var sx := -SPAWN_X if i % 2 == 0 else SPAWN_X
	var p := _ground(CENTER.x + sx, CENTER.y)
	var face := Vector3(-signf(sx), 0.0, 0.0)
	return Transform3D(Basis.looking_at(face, Vector3.UP), p)


## The arena on the ground (x, z).
func bounds() -> Rect2:
	return Rect2(CENTER - SIZE * 0.5, SIZE)


func has(p: Vector3, margin := 0.0) -> bool:
	return bounds().grow(margin).has_point(Vector2(p.x, p.z))


## How many pieces of cover stand now.
func piece_count() -> int:
	return props.get_child_count() if props != null else 0


## Every piece built again as it was (the round's reset: what broke stands again), the walk grid told.
func rebuild() -> void:
	if props != null:
		remove_child(props)
		props.queue_free()
	props = Node3D.new()
	props.name = "Pieces"
	add_child(props)
	var i := 0
	for e: Array in PIECES:
		for side in 2:
			var x := float(e[1]) if side == 0 else -float(e[1])
			var z := float(e[2]) if side == 0 else -float(e[2])
			var yaw := deg_to_rad(float(e[3]) + (180.0 if side == 1 else 0.0))
			_piece(String(e[0]), x, z, yaw, i)
			i += 1
	for e: Array in MIDDLE:
		_piece(String(e[0]), float(e[1]), float(e[2]), deg_to_rad(float(e[3])), i)
		i += 1
	var wg := WalkGrid.of(get_tree()) if is_inside_tree() else null
	if wg != null:
		wg.dirty(center(), SIZE.length() * 0.5 + 4.0)


## What the fight left lying about, taken away (see the header): the count.
func clear_dropped() -> int:
	var n := 0
	var tree := get_tree()
	for g: StringName in [FormRaised.GROUP, FormHollow.GROUP, FormCircle.GROUP, FormStone.GROUP, ThrownPickup.GROUP]:
		for x: Node in tree.get_nodes_in_group(g):
			if x is Node3D and has((x as Node3D).global_position, CLEAR_MARGIN) and not x.is_queued_for_deletion():
				x.queue_free()
				n += 1
	for x: Node in tree.current_scene.get_children():
		if x.is_queued_for_deletion() or not (x is Node3D) or not has((x as Node3D).global_position, CLEAR_MARGIN):
			continue
		if x is Projectile or x is NpcLoot or x is PlacedWeapon:
			x.queue_free()
			n += 1
	return n


# ---------------------------------------------------------------- the pieces
func _piece(kind: String, x: float, z: float, yaw: float, i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040 + i * 17
	var wx := CENTER.x + x
	var wz := CENTER.y + z
	var basis := Basis(Vector3.UP, yaw)
	# (on its lowest ground: a little sunk where the ground falls away under it)
	var y := INF
	for c: Vector2 in [Vector2(-1.2, -1.6), Vector2(1.2, -1.6), Vector2(-1.2, 1.6), Vector2(1.2, 1.6), Vector2.ZERO]:
		var o := basis * Vector3(c.x, 0.0, c.y)
		y = minf(y, FrontierTerrain.height_at(wx + o.x, wz + o.z))
	var xf := Transform3D(basis, Vector3(wx, y - 0.04, wz))
	var node: Node3D
	match kind:
		"crates":
			node = _crates(xf, rng)
		"wall":
			node = _wall(xf, rng)
		"fence":
			node = _fence(xf, rng)
		"woodpile":
			node = _woodpile(xf, rng)
		"boulder":
			node = _boulder(xf)
		"tree":
			node = _tree(Vector3(wx, FrontierTerrain.height_at(wx, wz), wz), yaw, i)
		"barrels":
			node = _barrels(xf, rng)
		"cart":
			node = _cart(xf, rng)
	if node == null:
		return
	node.name = "Duel_%s_%d" % [kind, i]
	node.set_meta(&"duel_piece", kind)
	props.add_child(node)


## A body at `xf` with box colliders [[centre, size], ...] in its own frame.
func _body(xf: Transform3D, boxes: Array, surface := "") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.transform = xf
	b.collision_layer = 1
	b.collision_mask = 0
	if surface != "":
		b.set_meta(&"surface", surface)
	for bx: Array in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bx[1]
		cs.shape = shape
		cs.position = bx[0]
		if bx.size() > 2:
			cs.basis = bx[2]
		b.add_child(cs)
	return b


## The kit's mesh under `b` (visuals only).
func _commit(b: Node3D, kit: StructureMeshKit) -> void:
	if not visuals or kit.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = kit.commit(_mats)
	b.add_child(mi)


func _crates(xf: Transform3D, rng: RandomNumberGenerator) -> Node3D:
	var c := CRATE
	var b := _body(xf, [[Vector3(0.0, c, 0.0), Vector3(c, c * 2.0, c * 3.0)], [Vector3(0.0, c * 2.5, 0.0), Vector3(c, c, c)]])
	if visuals:
		var kit := StructureMeshKit.new()
		for row in 2:
			for col in [-1, 0, 1]:
				var t := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.03, 0.03)), Vector3(0.0, c * (row + 0.5), float(col) * c))
				StructureGeometry.crate(kit, t, c - 0.01, rng)
		StructureGeometry.crate(kit, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.05, 0.05)), Vector3(0.0, c * 2.5, 0.0)), c - 0.01, rng)
		_commit(b, kit)
	return b


func _wall(xf: Transform3D, _rng: RandomNumberGenerator) -> Node3D:
	var b := _body(xf, [[Vector3(0.0, 0.575, 0.0), Vector3(0.62, 1.15, 3.2)]], "stone")
	GripSurface.tag(b, "rock")
	if visuals:
		var kit := StructureMeshKit.new()
		var ts := 1.0 / StructureGeometry.STONE_TILE
		StructureGeometry._stone_box(kit, Vector3(0.0, 0.525, 0.0), Vector3(0.6, 1.05, 3.2), ts, 8)
		StructureGeometry._stone_box(kit, Vector3(0.0, 1.1, 0.0), Vector3(0.66, 0.1, 3.24), ts, 8)
		_commit(b, kit)
	return b


func _fence(xf: Transform3D, rng: RandomNumberGenerator) -> Node3D:
	var b := _body(xf, [[Vector3(0.0, 0.7, 0.0), Vector3(0.12, 1.4, 3.0)], [Vector3(0.0, 0.76, -1.5), Vector3(0.16, 1.52, 0.16)],
			[Vector3(0.0, 0.76, 1.5), Vector3(0.16, 1.52, 0.16)]])
	if visuals:
		var kit := StructureMeshKit.new()
		for pz: float in [-1.5, 1.5]:
			kit.box(&"bark", Transform3D(Basis(), Vector3(-0.02, 0.76, pz)), Vector3(0.15, 1.52, 0.15), StructureMeshKit.GRAIN_Y, 0,
					rng.randf(), Color(1, 1, 1, 1), StructureMeshKit.KIND_ENDGRAIN, 0, 0.0, 0.7)
		for ry: float in [0.32, 1.12]:
			kit.box(&"boards", Transform3D(Basis(), Vector3(-0.07, ry, 0.0)), Vector3(0.06, 0.11, 3.0), StructureMeshKit.GRAIN_Z,
					rng.randi_range(0, 3), rng.randf())
		var n := 14
		for k in n:
			var pz := -1.39 + 2.78 * (float(k) + 0.5) / float(n)
			var h := 1.36 + rng.randf_range(-0.03, 0.04)
			var tint := rng.randf_range(0.88, 1.06)
			kit.box(&"boards", Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.012, 0.012)), Vector3(0.0, h * 0.5 + 0.02, pz)),
					Vector3(0.035, h, 0.19), StructureMeshKit.GRAIN_Y, rng.randi_range(0, 3), rng.randf(), Color(tint, tint, tint * 0.97, 1.0),
					StructureMeshKit.KIND_ENDGRAIN, 0, 0.0, 0.75)
		_commit(b, kit)
	return b


func _woodpile(xf: Transform3D, rng: RandomNumberGenerator) -> Node3D:
	var b := _body(xf, [[Vector3(0.0, 0.575, 0.0), Vector3(3.2, 1.15, 0.72)]])
	if visuals:
		var kit := StructureMeshKit.new()
		StructureGeometry.woodpile(kit, Transform3D.IDENTITY, 3.2, 1.17, 0.7, rng)
		_commit(b, kit)
	return b


func _boulder(xf: Transform3D) -> Node3D:
	var kind := Assets.ROCK_LAST                      # (the boulder)
	var s := 1.8
	var info := Assets.prop(kind)
	var b := StaticBody3D.new()
	b.transform = xf
	b.collision_layer = 1
	b.collision_mask = 0
	b.set_meta(&"surface", "stone")
	GripSurface.tag(b, "rock")
	var cs := CollisionShape3D.new()
	var hull: Array = info.get("hull", [])
	if hull.is_empty():
		var bx := BoxShape3D.new()
		var size: Array = info.get("size", [1.3, 1.0, 1.8])
		bx.size = Vector3(float(size[0]), float(size[1]), float(size[2])) * s * 0.8
		cs.shape = bx
		cs.position.y = float(size[1]) * s * 0.4
	else:
		var pts := PackedVector3Array()
		for h: Array in hull:
			pts.append(Vector3(float(h[0]), float(h[1]), float(h[2])) * s)
		var cv := ConvexPolygonShape3D.new()
		cv.points = pts
		cs.shape = cv
	b.add_child(cs)
	if visuals:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = Assets.prop_mesh(kind, 0)
		mi.material_override = Assets.prop_material(kind)
		mi.scale = Vector3.ONE * s
		b.add_child(mi)
	return b


func _tree(at: Vector3, yaw: float, i: int) -> Node3D:
	var trees := [{"pos": at, "yaw": yaw, "kind": Assets.OAK, "variant": 1, "scale": 1.15,
			"custom": Color(0.35 + 0.1 * float(i % 3), 0.05, 0.5, 0.0)}]
	var settings := WorldSettings.preset(WorldSettings.DEFAULT_QUALITY)
	var g := StoryLayerProps.grove(trees, settings, visuals)
	return g


func _barrels(xf: Transform3D, rng: RandomNumberGenerator) -> Node3D:
	var b := StaticBody3D.new()
	b.transform = xf
	b.collision_layer = 1
	b.collision_mask = 0
	var kit := StructureMeshKit.new() if visuals else null
	for p: Vector2 in [Vector2(0.0, -0.36), Vector2(0.0, 0.36), Vector2(0.6, 0.0)]:
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.31
		cy.height = 0.95
		cs.shape = cy
		cs.position = Vector3(p.x, 0.475, p.y)
		b.add_child(cs)
		if kit != null:
			StructureGeometry.barrel(kit, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, 0.475, p.y)), 0.3, 0.95, rng)
	if kit != null:
		_commit(b, kit)
	return b


func _cart(xf: Transform3D, rng: RandomNumberGenerator) -> Node3D:
	var axle := 0.62
	var floor_y := axle + 0.05
	var side_h := 0.5
	var bed_z := 2.2
	var bed_x := 1.3
	var wheel_x := 0.78
	var roll := Basis(Vector3.BACK, PI * 0.5)        # (a wheel's axis across the cart)
	var b := _body(xf, [[Vector3(0.0, floor_y + side_h * 0.5, 0.0), Vector3(bed_x, side_h, bed_z)]], "wood")
	for sx: float in [-1.0, 1.0]:
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = axle
		cy.height = 0.09
		cs.shape = cy
		cs.transform = Transform3D(roll, Vector3(sx * wheel_x, axle, 0.0))
		b.add_child(cs)
	if visuals:
		var kit := StructureMeshKit.new()
		kit.box(&"boards", Transform3D(Basis(), Vector3(0.0, floor_y, 0.0)), Vector3(bed_x, 0.06, bed_z), StructureMeshKit.GRAIN_Z, 1, 0.0)
		for sx: float in [-1.0, 1.0]:
			kit.box(&"boards", Transform3D(Basis(), Vector3(sx * (bed_x * 0.5 - 0.025), floor_y + side_h * 0.5, 0.0)),
					Vector3(0.05, side_h, bed_z), StructureMeshKit.GRAIN_Z, rng.randi_range(0, 3), rng.randf())
		for sz: float in [-1.0, 1.0]:
			kit.box(&"boards", Transform3D(Basis(), Vector3(0.0, floor_y + side_h * 0.5, sz * (bed_z * 0.5 - 0.025))),
					Vector3(bed_x - 0.1, side_h, 0.05), StructureMeshKit.GRAIN_X, rng.randi_range(0, 3), rng.randf())
		# the axle, the two wheels (a rim of stout boards round a hub, spokes), the shafts down to the ground
		kit.box(&"boards", Transform3D(Basis(), Vector3(0.0, axle, 0.0)), Vector3(wheel_x * 2.0 + 0.2, 0.09, 0.09), StructureMeshKit.GRAIN_X, 2, 0.0)
		for sx: float in [-1.0, 1.0]:
			var saved := kit.xform
			kit.xform = saved * Transform3D(Basis(), Vector3(sx * wheel_x, axle, 0.0))
			for k in 12:
				var a := TAU * float(k) / 12.0
				var rim := Basis(Vector3.RIGHT, a)
				kit.box(&"boards", Transform3D(rim, rim * Vector3(0.0, axle - 0.05, 0.0)), Vector3(0.08, 0.1, 0.36), StructureMeshKit.GRAIN_Z,
						rng.randi_range(0, 3), rng.randf(), Color(0.82, 0.8, 0.78, 1.0))
			for k in 6:
				var a := TAU * float(k) / 6.0 + 0.2
				var sp := Basis(Vector3.RIGHT, a)
				kit.box(&"boards", Transform3D(sp, sp * Vector3(0.0, axle * 0.5, 0.0)), Vector3(0.05, axle - 0.1, 0.05), StructureMeshKit.GRAIN_Y,
						rng.randi_range(0, 3), rng.randf())
			kit.box(&"boards", Transform3D(Basis(), Vector3.ZERO), Vector3(0.16, 0.16, 0.16), StructureMeshKit.GRAIN_X, 1, 0.0,
					Color(0.7, 0.68, 0.66, 1.0))
			kit.xform = saved
		for sx: float in [-1.0, 1.0]:
			var tip := Vector3(sx * 0.42, 0.06, bed_z * 0.5 + 2.6)
			var root := Vector3(sx * 0.42, floor_y, bed_z * 0.5 - 0.1)
			var mid := (tip + root) * 0.5
			var dir := (tip - root).normalized()
			var bz := dir
			var bx := Vector3.UP.cross(bz).normalized()
			var by := bz.cross(bx)
			kit.box(&"boards", Transform3D(Basis(bx, by, bz), mid), Vector3(0.07, 0.07, tip.distance_to(root)), StructureMeshKit.GRAIN_Z,
					rng.randi_range(0, 3), rng.randf())
		for sz: float in [-0.5, 0.5]:
			StructureGeometry.crate(kit, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)),
					Vector3(0.0, floor_y + 0.03 + CART_CRATE * 0.5, sz * CART_CRATE * 1.1)), CART_CRATE - 0.02, rng)
		_commit(b, kit)
	return b


## The arena's four corners staked (a post with a strip of red cloth; nothing to stop a man or a ball).
func _stakes() -> void:
	if not visuals:
		return
	var kit := StructureMeshKit.new()
	var root := Node3D.new()
	root.name = "Stakes"
	add_child(root)
	var r := bounds()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4001
	for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var g := _ground(c.x, c.y)
		kit.box(&"bark", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), g + Vector3(0.0, 0.6, 0.0)), Vector3(0.09, 1.3, 0.09),
				StructureMeshKit.GRAIN_Y, 0, rng.randf(), Color(1, 1, 1, 1), StructureMeshKit.KIND_ENDGRAIN, 0, 0.0, 0.7)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(_mats)
	root.add_child(mi)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.62, 0.12, 0.08)
	cloth.roughness = 0.95
	for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var g := _ground(c.x, c.y)
		var rag := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.32, 0.22)
		rag.mesh = bm
		rag.material_override = cloth
		rag.position = g + Vector3(0.0, 1.1, 0.12)
		root.add_child(rag)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)
