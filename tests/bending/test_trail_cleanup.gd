extends SceneTree
## A disappearing fighter ends its guard while the scene is removing children. The fallback particle trail must detach
## after that notification completes, remain at its world position, then expire. No rendered particle effect is needed.

var failures := 0

func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + message)
	if not ok:
		failures += 1


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var fighter := Node3D.new()
	scene.add_child(fighter)
	# Guard zones are siblings of fighters in the real ring, with their particles beneath the zone.
	var guard := Node3D.new()
	scene.add_child(guard)
	var trail := GPUParticles3D.new()
	trail.emitting = false
	trail.lifetime = 0.05
	guard.add_child(trail)
	trail.global_position = Vector3(3.0, 2.0, 1.0)
	var trail_ref: WeakRef = weakref(trail)
	fighter.tree_exiting.connect(func() -> void:
		BendLooks.stop_trail(trail)
		guard.queue_free())
	scene.remove_child(fighter)
	fighter.queue_free()
	await process_frame
	await process_frame
	var alive := trail_ref.get_ref() as GPUParticles3D
	_check(alive != null and alive.get_parent() == scene and alive.is_inside_tree(),
			"trail survives fighter removal without reparenting during the exit notification")
	if alive != null and alive.is_inside_tree():
		_check(alive.global_position.is_equal_approx(Vector3(3.0, 2.0, 1.0)) and not alive.emitting,
				"detached trail keeps its world position and stops emitting")
	await create_timer(0.35).timeout
	await process_frame
	_check(trail_ref.get_ref() == null, "detached trail expires after its particles fade")
	# Scene removal before a deferred release must safely discard the trail too.
	var ending := GPUParticles3D.new()
	ending.emitting = false
	scene.add_child(ending)
	var ending_ref: WeakRef = weakref(ending)
	BendLooks.stop_trail(ending)
	scene.queue_free()
	await process_frame
	await process_frame
	_check(ending_ref.get_ref() == null, "scene teardown leaves no orphan trail")
	print("TRAIL CLEANUP %s" % ("PASSED" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)
