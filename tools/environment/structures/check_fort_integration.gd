extends SceneTree
## Checks the textured fort (FrontierStructures) as wired into frontier_level.gd on 2026-09-25.
## Headless is fine (the visual line-of-sight part builds the meshes itself); wrap it in a time
## limit, a script error leaves Godot running:
##
##   Godot --headless --path . -s tools/environment/structures/check_fort_integration.gd -- --no-capture
##
## Prints one ok / FAIL line per check and ends with FORT INTEGRATION OK / FAILED (exit 0 / 1):
##   rng        the level rng leaves the structures in the same state as the original placeholder
##              _fort() + _range() left it (so the forest that follows is unchanged)
##   surface    Sfx.surface_of on every new collider and on the fort's walkable tops: wood (posts,
##              log ends, woodpile, chopping block, roof, walkway, ramps), stone (the three chimney
##              boxes, the fire pit), straw (the four trusses); footstep mapping for the tops
##   roof       the cabin roof prism is solid (rays land on its slopes and ridge, a capsule in
##              the attic overlaps it) and it and the cabin box are traversal-excluded
##   ramps      the player walks up and back down both ramps (the ramp pieces) at three lateral offsets
##   los_mesh   the line of sight from the spawn eye, the gameplay camera and the firing line to
##              the dummies is clear of the fort's VISUAL meshes too (trimesh of every structure
##              triangle, dummies excluded), not only of its colliders (check_layout.gd does those)

const OLD_FORT_HALF := 16.0
const OLD_GATE_HALF := 3.0

var player: FrontierPlayer
var space: PhysicsDirectSpaceState3D
var failures := PackedStringArray()
var _headless_palisade := false        ## (set by _collect when a palisade MultiMesh is met; the palisade is no part of FrontierStructures any more)


func _initialize() -> void:
	_block_user_input()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") if current_scene else null
	if player == null:
		printerr("FAIL: level or player failed to load")
		print("FORT INTEGRATION FAILED")
		quit(1)
		return
	player.ignore_mouse_capture = true
	await _physics(10)
	space = player.get_world_3d().direct_space_state
	_check_rng()
	_check_surfaces()
	await _check_roof()
	for r: Array in [[Vector3(12.0, 0.1, -8.0), "east"], [Vector3(-12.0, 0.1, -8.0), "west"]]:
		for off: float in [-0.3, 0.0, 0.3]:
			await _check_ramp((r[0] as Vector3) + Vector3(off, 0, 0), "%s %+.1f" % [r[1], off])
	await _check_visual_los()
	if failures.is_empty():
		print("FORT INTEGRATION OK")
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("FORT INTEGRATION FAILED (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


# --- rng ---------------------------------------------------------------------------------------

## Replays the rng calls of the original placeholder _fort() + _range() (frontier_level.gd before
## the integration: one randf_range per palisade log outside the gate, five crate turns, four hay
## turns) and compares with a fresh FrontierStructures build.
func _check_rng() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 1776
	var r := 0.19
	var walls := [
		[Vector3(-OLD_FORT_HALF, 0, -OLD_FORT_HALF), Vector3(OLD_FORT_HALF, 0, -OLD_FORT_HALF), true],
		[Vector3(-OLD_FORT_HALF, 0, OLD_FORT_HALF), Vector3(OLD_FORT_HALF, 0, OLD_FORT_HALF), false],
		[Vector3(-OLD_FORT_HALF, 0, -OLD_FORT_HALF), Vector3(-OLD_FORT_HALF, 0, OLD_FORT_HALF), false],
		[Vector3(OLD_FORT_HALF, 0, -OLD_FORT_HALF), Vector3(OLD_FORT_HALF, 0, OLD_FORT_HALF), false],
	]
	for wall in walls:
		var p0: Vector3 = wall[0]
		var p1: Vector3 = wall[1]
		var n := int(p0.distance_to(p1) / (r * 2.0))
		for i in n + 1:
			var p := p0.lerp(p1, float(i) / n)
			if wall[2] and absf(p.x) < OLD_GATE_HALF:
				continue
			a.randf_range(-0.25, 0.25)
	for i in 5:
		a.randf_range(-0.3, 0.3)
	for i in 4:
		a.randf_range(-0.4, 0.4)
	var b := RandomNumberGenerator.new()
	b.seed = 1776
	var s := FrontierStructures.new()
	s.visuals = false
	root.add_child(s)
	s.build(WorldSettings.preset("high"), b)
	s.free()
	_expect(a.state == b.state, "rng: level rng state after the structures %d, placeholder fort %d" % [b.state, a.state])


# --- surfaces ----------------------------------------------------------------------------------

func _check_surfaces() -> void:
	var side := [
		["cabin log end NW-x", Vector3(-13.0, 1.5, 4.625), Vector3(-10.0, 1.5, 4.625), "wood", -11.75],
		["cabin log end NW-z", Vector3(-11.375, 1.5, 2.5), Vector3(-11.375, 1.5, 6.0), "wood", 4.25],
		["cabin log end SW-x", Vector3(-13.0, 1.5, 9.375), Vector3(-10.0, 1.5, 9.375), "wood", -11.75],
		["cabin log end SW-z", Vector3(-11.375, 1.5, 12.0), Vector3(-11.375, 1.5, 8.0), "wood", 9.75],
		["cabin log end NE-x", Vector3(-3.0, 1.5, 4.625), Vector3(-6.0, 1.5, 4.625), "wood", -4.25],
		["cabin log end NE-z", Vector3(-4.625, 1.5, 2.5), Vector3(-4.625, 1.5, 6.0), "wood", 4.25],
		["cabin log end SE-x", Vector3(-3.0, 1.5, 9.375), Vector3(-6.0, 1.5, 9.375), "wood", -4.25],
		["cabin log end SE-z", Vector3(-4.625, 1.5, 12.0), Vector3(-4.625, 1.5, 8.0), "wood", 9.75],
		["chimney firebox", Vector3(-2.0, 0.9, 8.0), Vector3(-6.0, 0.9, 8.0), "stone", -3.42],
		["chimney neck", Vector3(-2.0, 2.25, 8.0), Vector3(-6.0, 2.25, 8.0), "stone", -3.98],
		["chimney (original box)", Vector3(-2.0, 3.4, 8.0), Vector3(-6.0, 3.4, 8.0), "stone", -3.98],
		["chimney top", Vector3(-2.0, 4.9, 8.0), Vector3(-6.0, 4.9, 8.0), "stone", -3.98],
		["woodpile", Vector3(-9.0, 0.5, 1.5), Vector3(-9.0, 0.5, 6.0), "wood", 3.79],
		["cabin roof south slope", Vector3(-8.0, 3.6, 13.0), Vector3(-8.0, 3.6, 5.0), "wood", 9.05],
		["cabin roof north slope", Vector3(-8.0, 3.6, 1.0), Vector3(-8.0, 3.6, 9.0), "wood", 4.95],
		["cabin wall", Vector3(-8.0, 1.5, 12.0), Vector3(-8.0, 1.5, 5.0), "wood", 9.5],
		["palisade", Vector3(8, 1, -10), Vector3(8, 1, -25), "wood", -15.81],
		["storehouse", Vector3(9, 1, 9), Vector3(9, 1, 0), "wood", 6.0],
		["flag pole", Vector3(-6, 3, 0), Vector3(-6, 3, -4), "wood", -1.93],
	]
	for x: float in [3.0, 6.0, 9.0, -3.0, -6.0, -9.0]:        # (a firing step piece's post stands at each section's middle)
		side.append(["walkway post x=%.1f" % x, Vector3(x, 1.0, -12.0), Vector3(x, 1.0, -16.0), "wood", -14.21])
	for c: Array in side:
		var from: Vector3 = c[1]
		var to: Vector3 = c[2]
		var hit := _ray(from, to)
		var s := _surface(hit)
		var axis := 0 if absf(to.x - from.x) > absf(to.z - from.z) else 2
		var at := float((hit.position as Vector3)[axis]) if hit else NAN
		_expect(s == c[3] and absf(at - float(c[4])) < 0.06,
				"surface: %s = %s (got %s at %s %.2f, expected %.2f)" % [c[0], c[3], s, "xz"[axis / 2], at, c[4]])
	# Walkable tops: [label, x, z, expected surface, expected top y, footstep sound]
	var down := [
		["chopping block", -6.3, 3.35, "wood", 0.55, "wood"],
		["fire pit", 3.8, 10.6, "stone", 0.34, "dirt"],
		["chimney firebox top", -3.7, 8.0, "stone", 1.9, "dirt"],
		["cabin roof ridge", -8.0, 7.0, "wood", 5.034, "wood"],
		["cabin roof over the south eave", -8.0, 9.7, "wood", 3.148, "wood"],
		["cabin roof over the west gable", -11.7, 7.0, "wood", 5.034, "wood"],
		["woodpile", -9.0, 4.12, "wood", 1.04, "wood"],
		["walkway deck east", 8.0, -15.0, "wood", 2.275, "wood"],
		["walkway deck west", -8.0, -15.0, "wood", 2.275, "wood"],
		["east ramp", 12.0, -11.7, "wood", 1.1375, "wood"],
		["west ramp", -12.0, -11.7, "wood", 1.1375, "wood"],
		["crate", 4.75, -6.0, "wood", 0.8, "wood"],
		["barrel", 7.0, -3.0, "wood", 1.0, "wood"],
		["under the walkway", 5.1, -15.0, "wood", 2.125, "wood"],
	]
	var z0 := FrontierStructures.FIRING_LINE_Z
	var trusses := [Vector3(-5, 0, z0 - 15), Vector3(5, 0, z0 - 30), Vector3(-4.5, 0, z0 - 60), Vector3(4.5, 0, z0 - 85)]
	for i in trusses.size():
		down.append(["straw truss %d" % i, trusses[i].x, trusses[i].z, "straw", 0.9, "grass"])
	for c: Array in down:
		var top := Vector3(c[1], 12.0, c[2])
		if String(c[0]) == "under the walkway":
			top.y = 1.8        # from under the deck, upward
			var hup := _ray(top, top + Vector3.UP * 3.0)
			var su := _surface(hup)
			var yu := float((hup.position as Vector3).y) if hup else NAN
			_expect(su == c[3] and absf(yu - float(c[4])) < 0.06, "surface: %s = %s (got %s at y %.3f)" % [c[0], c[3], su, yu])
			continue
		var hit := _ray(top, top + Vector3.DOWN * 14.0)
		var s := _surface(hit)
		var y := float((hit.position as Vector3).y) if hit else NAN
		var step := _footstep(hit)
		_expect(s == c[3] and absf(y - float(c[4])) < 0.06 and step == c[5],
				"surface: %s = %s at y %.3f (got %s at y %.3f; footsteps %s, expected %s)" % [c[0], c[3], c[4], s, y, step, c[5]])


## Footsteps.surface(): wood stays wood, dirt and stone sound as dirt, the rest as grass.
func _footstep(hit: Dictionary) -> String:
	if hit.is_empty():
		return "none"
	match Sfx.surface_of(hit.collider, hit.position, hit.normal):
		"wood":
			return "wood"
		"dirt", "stone":
			return "dirt"
	return "grass"


# --- cabin roof ---------------------------------------------------------------------------------

func _check_roof() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	for p: Vector3 in [Vector3(-8.0, 3.8, 7.0), Vector3(-10.5, 3.6, 7.0), Vector3(-5.5, 3.6, 7.0)]:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis.IDENTITY, p)
		q.exclude = [player.get_rid()]
		var names := []
		for r: Dictionary in space.intersect_shape(q, 8):
			names.append(str((r.collider as Node).name))
		_expect("cabin_roof" in names, "roof: a capsule in the attic at %s overlaps the roof (%s)" % [p, ", ".join(names)])
	var reg := TravShapeRegistry.new()
	var roof := current_scene.find_child("cabin_roof", true, false) as StaticBody3D
	_expect(roof != null, "roof: the cabin_roof body exists")
	if roof:
		var cs := roof.get_child(0) as CollisionShape3D
		_expect(TravShapeRegistry.gate(reg.describe_node(cs, roof)) == "excluded", "roof: traversal gate of the roof = excluded")
	var hit := _ray(Vector3(-8.0, 1.5, 12.0), Vector3(-8.0, 1.5, 5.0))
	if hit:
		var body := hit.collider as CollisionObject3D
		var node := TravShapeRegistry.resolve(body, int(hit.shape))
		_expect(TravShapeRegistry.gate(reg.describe_node(node, body)) == "excluded", "roof: traversal gate of the cabin box = excluded")
	else:
		_expect(false, "roof: the cabin box is hit from the south")


# --- ramps ---------------------------------------------------------------------------------------

func _check_ramp(start: Vector3, label: String) -> void:
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = 0.0
	await _physics(20)
	Input.action_press("move_forward")
	var top := false
	var frames := 0
	for i in 600:
		await physics_frame
		_hold_view(0.0)
		frames = i
		if player.global_position.y > 2.2 and player.global_position.z < -14.5:
			top = true
			break
	Input.action_release("move_forward")
	await _physics(20)
	var up_at := player.global_position
	# Back down: turn round and walk south until the feet are on the ground past the ramp foot.
	player.yaw = PI
	await _physics(5)
	Input.action_press("move_forward")
	var down := false
	for i in 600:
		await physics_frame
		_hold_view(PI)
		if player.global_position.y < 0.2 and player.global_position.z > -8.5:
			down = true
			break
	Input.action_release("move_forward")
	await _physics(10)
	player.yaw = 0.0
	_expect(top and down, "ramp %s: up in %d frames to %s, back down to %s" % [label, frames, up_at.snapped(Vector3.ONE * 0.01),
			player.global_position.snapped(Vector3.ONE * 0.01)])


# --- line of sight against the visual meshes ----------------------------------------------------

func _check_visual_los() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1776
	var s := FrontierStructures.new()
	s.force_visuals = true
	s.occluders = false
	s.extra_colliders = false
	root.add_child(s)
	s.build(WorldSettings.preset("high"), rng)
	await process_frame
	var faces := PackedVector3Array()
	_collect(s, faces)
	# (the palisade, the gate, the firing step and the blockhouses are build-menu pieces since 2026-09-28, not part of
	# FrontierStructures: FortPlan.stamp_structure, tests/building/test_fort_structure.gd checks them)
	s.queue_free()
	await process_frame
	# A separate physics world: only the triangles, nothing of the level.
	var holder := SubViewport.new()
	holder.world_3d = World3D.new()
	root.add_child(holder)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	holder.add_child(body)
	await physics_frame
	await physics_frame
	var vspace := body.get_world_3d().direct_space_state
	print("  los_mesh: %d structure triangles" % (faces.size() / 3))
	var lines := [
		["spawn eye -> 25 m dummy", Vector3(0, 1.6, 6), Vector3(0, 1.2, -45)],
		["gameplay camera -> 25 m dummy", Vector3(0.0, 2.3, 9.6), Vector3(0, 1.2, -45)],
	]
	var lanes := [-2.5, 0.0, 2.5]
	for i in FrontierStructures.RANGE_DISTANCES.size():
		var d: int = FrontierStructures.RANGE_DISTANCES[i]
		lines.append(["firing line -> %d m dummy" % d, Vector3(0, 1.6, -20.6), Vector3(lanes[i % 3], 1.2, FrontierStructures.FIRING_LINE_Z - d)])
	for l: Array in lines:
		var q := PhysicsRayQueryParameters3D.create(l[1], l[2])
		var hit := vspace.intersect_ray(q)
		_expect(hit.is_empty(), "los_mesh: %s clear of the fort meshes%s" % [l[0], "" if hit.is_empty() else " (blocked at %s)" % (hit.position as Vector3).snapped(Vector3.ONE * 0.01)])
	holder.queue_free()


func _collect(n: Node, faces: PackedVector3Array) -> void:
	if n is TargetDummy:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var t := mi.global_transform
		for v in mi.mesh.get_faces():
			faces.append(t * v)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm.instance_count > 1 and mm.get_instance_transform(0) == Transform3D() and mm.get_instance_transform(1) == Transform3D():
			_headless_palisade = true
			return
		var f := mm.mesh.get_faces()
		var base := (n as Node3D).global_transform
		for i in mm.instance_count:
			var t := base * mm.get_instance_transform(i)
			for v in f:
				faces.append(t * v)
	for c in n.get_children():
		_collect(c, faces)


# --- helpers -------------------------------------------------------------------------------------

## Windowed runs open on the user's screen: a click there would capture the mouse and turn the
## player. The walk direction is held every frame, and every game action is unbound (as in
## scenic_shots.gd) so stray key presses cannot move the player; Input.action_press still works.
func _hold_view(yaw: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.yaw = yaw
	player.pitch = 0.0


func _block_user_input() -> void:
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	return space.intersect_ray(q)


func _surface(hit: Dictionary) -> String:
	if hit.is_empty():
		return "none"
	return Sfx.surface_of(hit.collider, hit.position, hit.normal)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
	print(("  ok   " if cond else "  FAIL ") + msg)
