extends SceneTree
## Meaningful cosmetic boundaries: deterministic RNG, bounded pooling and cleanup.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	BendLooks.build_headless = true
	var body := Node3D.new()
	world.add_child(body)
	seed(472)
	var expected := randf()
	seed(472)
	for el: String in Bending.ELEMENTS:
		for i in 30:
			MonsoonIdentity.release(body, el, true)
	assert(is_equal_approx(randf(), expected), "cosmetics must not consume gameplay RNG")
	var pool := ToonFxPool.of(world)
	assert(pool.get_child_count() == 48, "release marks must cap at twelve per element")
	assert(world.get_child_count() == 2, "effects must not create colliders or gameplay owners")
	pool._process(0.4)
	for child: Node in pool.get_children():
		assert(not (child as MeshInstance3D).visible, "release marks must expire")
	for el: String in Bending.ELEMENTS:
		MonsoonIdentity.release(body, el, false)
	assert(pool.get_child_count() == 48, "subsequent casts must reuse the pool")
	print("MONSOON IDENTITY PASSED (RNG, cap, no colliders, expiry, reuse)")
	quit()
