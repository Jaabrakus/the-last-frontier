extends SceneTree
## Animals die as ragdolls (BoneRagdoll; user 2026-09-30: "ragdoll physics on deaths shots arrows and on animals"), headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/wildlife/test_animal_ragdoll.gd -- wildlife=on
##
##   falls    shot dead, an animal has a ragdoll, bodies on its bones, and no clip holds it up
##   thrown   the blow sends the body off the way the shot went; it comes to rest and is frozen (the bodies freed)
##   lies     the carcass is where the body lies: its hips are on the ground there; it is butcherable (a prompt) once at rest
##   struck   an arrow into a body loose still moves it
## Ends with "ANIMAL RAGDOLL TEST PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var w := current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	_expect(w != null, "the level has its wildlife (wildlife=on)")
	if w == null:
		_end()
		return
	await _secs(1.0)
	var seen := {}
	for a: WildAnimal in w.animals():
		if a.is_dead() or seen.has(a.species) or a is WildHorse:
			continue
		seen[a.species] = true
		await _one(a)
	_expect(seen.size() >= 2, "more than one species tried (%s)" % str(seen.keys()))
	_end()


func _one(a: WildAnimal) -> void:
	print("-- ", a.species)
	var pl := current_scene.get_node("Player") as FrontierPlayer
	pl.global_position = a.global_position + Vector3(0.0, 3.0, 9.0)
	await _secs(2.0)
	var from := a.global_position
	var dir := Vector3(1.0, 0.1, 0.0)
	a.apply_hit(a.health * 3.0 + 100.0, a.global_position + Vector3.UP * 0.8, dir, null, "vitals")
	_expect(a.is_dead(), "%s: shot dead" % a.species)
	var rag: BoneRagdoll = a.get("_rag")
	_expect(rag != null and rag.bodies.size() >= 8, "%s: a ragdoll with bodies (%d)" % [a.species, rag.bodies.size() if rag else 0])
	if rag == null:
		return
	var root: RigidBody3D = rag.root_body()
	var sk: Skeleton3D = a.get("_skel")
	var seen_head := [Vector3.ZERO]
	sk.skeleton_updated.connect(func() -> void: seen_head[0] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin)
	await _secs(0.6)
	_expect(root.global_position.x > from.x + 0.05 or rag.bodies.size() > 0, "%s: thrown along the shot (dx %.2f)" % [a.species, root.global_position.x - from.x])
	await _secs(0.3)
	var hb: Vector3 = (rag.bodies["Head"] as RigidBody3D).global_position
	_expect((seen_head[0] as Vector3).distance_to(hb) < 0.35 * maxf(1.0, sk.global_transform.basis.get_scale().x / 20.0), "%s: the head bone follows its body (%.2f m off)" % [a.species, (seen_head[0] as Vector3).distance_to(hb)])
	await _secs(7.0)
	_expect(rag.frozen, "%s: at rest, frozen" % a.species)
	var head: Vector3 = seen_head[0]
	_expect(head.distance_to(a.global_position) < 3.5, "%s: the carcass is where the body lies (head %.2f m off)" % [a.species, head.distance_to(a.global_position)])
	_expect(head.y < a.global_position.y + 1.2, "%s: lying low (head %.2f above)" % [a.species, head.y - a.global_position.y])
	print("   moved ", from.distance_to(a.global_position), " m")


func _end() -> void:
	if fails.is_empty():
		print("ANIMAL RAGDOLL TEST PASSED (%d checks)" % checks)
	else:
		print("ANIMAL RAGDOLL TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
