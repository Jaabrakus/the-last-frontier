extends SceneTree
## Animals step over what lies low in their way (WildAnimal step_m, BodyStep): a deer driven along a meadow into a log lying
## across its path goes over it when the log is lower than its step (0.6 m) and does not climb one taller; without the step
## assist the same log stops it. Headless.
##   Godot --headless --path . -s tests/wildlife/test_animal_step.gd -- survival=on fort_plan=on wildlife=on
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _log(at: Vector3, h: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.add_to_group(FrontierVegetation.LOW_GROUP)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, h, 6.0)
	cs.shape = box
	cs.position.y = h * 0.5
	b.add_child(cs)
	current_scene.add_child(b)
	b.global_position = at
	return b


## Drives the deer from `from` along +x for `secs` s; its furthest x and highest y.
func _drive(a: WildAnimal, from: Vector3, secs: float) -> Dictionary:
	a.set_physics_process(false)
	a.global_position = from
	a.velocity = Vector3.ZERO
	a._speed = 0.0
	a._yaw = -PI * 0.5
	a.rotation.y = a._yaw
	a._avoid_yaw = 0.0
	var best_x := from.x
	var top_y := 0.0
	for i in int(secs * 60.0):
		await physics_frame
		a._move(Vector3(1, 0, 0), 2.0, 1.0 / 60.0, false)
		best_x = maxf(best_x, a.global_position.x)
		top_y = maxf(top_y, a.global_position.y - FrontierTerrain.height_at(a.global_position.x, a.global_position.z))
	return {"x": best_x, "y": top_y}


func _run() -> void:
	for i in 200:
		await physics_frame
	var sp := WildlifeSpawner.find(self)
	if sp == null:
		print("NO SPAWNER")
		quit(1)
		return
	var deer: WildAnimal = null
	for a in sp.animals():
		if a.species == "deer" and not a.is_dead():
			deer = a
			break
	_expect(deer != null, "a deer to drive")
	var base := Vector3(-30.0, 0.0, 34.0)
	base.y = FrontierTerrain.height_at(base.x, base.z)
	var start := base + Vector3(-5.0, 0.3, 0.0)
	var low := _log(base, 0.4)
	low.global_position.y = FrontierTerrain.height_at(base.x, base.z)
	await physics_frame
	var r1: Dictionary = await _drive(deer, start, 9.0)
	_expect(r1.x > base.x + 2.0, "a deer goes over a 0.4 m log (got to x %.1f, the log at %.1f; up %.2f m)" % [r1.x, base.x, r1.y])
	var stepped := deer._step
	deer._step = null
	var r2: Dictionary = await _drive(deer, start, 9.0)
	_expect(r2.x < base.x, "without the step assist the same log stops it (x %.1f)" % r2.x)
	deer._step = stepped
	low.queue_free()
	await physics_frame
	var tall := _log(base, 1.0)
	tall.global_position.y = FrontierTerrain.height_at(base.x, base.z)
	await physics_frame
	var r3: Dictionary = await _drive(deer, start, 9.0)
	_expect(r3.y < 0.5, "a 1.0 m log is not climbed (up at most %.2f m)" % r3.y)
	print("ANIMAL STEP DONE: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
