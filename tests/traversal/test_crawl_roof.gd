extends SceneTree
## A crawl only under the world's fixed things (user 2026-10-02: "i can crawl under a horse"): TraversalProbe.probe_ceiling
## on flat ground finds a crawl under a fixed roof 1.2 m up and none under a body that moves at the same height (the
## horse's, a wild animal's: a CharacterBody3D) or a physics body, nor beside a practice dummy (user 2026-10-02: "when
## we are at a dummy we get placed in this crawl under animation": its arms, a bar 1.35 m up on its moving body).
##   Godot --headless --path . -s tests/traversal/test_crawl_roof.gd

var fails := 0
var checks := 0


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_box(world, StaticBody3D.new(), Vector3(0, -0.5, 0), Vector3(40, 1, 40))          # the ground
	await physics_frame
	await physics_frame
	var probe := TraversalProbe.new(world.get_world_3d().direct_space_state)
	var feet := Vector3(0, 0, 0)
	var ahead := Vector3(0, 0, -1)
	_expect(probe.probe_ceiling(feet, ahead).kind != "crawl", "open ground: no crawl")
	for kind in ["static", "character", "rigid"]:
		var b: PhysicsBody3D = {"static": StaticBody3D.new(), "character": CharacterBody3D.new(),
				"rigid": RigidBody3D.new()}[kind]
		if b is RigidBody3D:
			(b as RigidBody3D).freeze = true
		var n := _box(world, b, Vector3(0, 1.2 + 0.25, -0.7), Vector3(1.0, 0.5, 1.0))   # its underside 1.2 m up
		await physics_frame
		await physics_frame
		var info := probe.probe_ceiling(feet, ahead)
		if kind == "static":
			_expect(info.kind == "crawl", "a fixed roof 1.2 m up: crawl (%s, %.2f m)" % [info.kind, info.clearance_h])
		else:
			_expect(info.kind != "crawl", "a %s body 1.2 m up (a horse's belly): no crawl (%s, %s)" % [kind, info.kind, info.reason])
		n.queue_free()
		await physics_frame
	# a practice dummy 0.7 m ahead, the probe's ray passing under its arm
	var dummy := TargetDummy.new()
	dummy.position = Vector3(-0.35, 0.0, -0.7)        # (placed before it enters the tree, as the level does)
	world.add_child(dummy)
	for i in 4:                     # (its moving body takes a few physics frames to stand where it was put)
		await physics_frame
	var di := probe.probe_ceiling(feet, ahead)
	_expect(di.kind != "crawl", "beside a practice dummy, under its arm: no crawl (%s, %s, %.2f m)" % [di.kind, di.reason, di.clearance_h])
	print("CRAWL ROOF TEST %s (%d of %d)" % ["PASSED" if fails == 0 else "FAILED", checks - fails, checks])
	quit(1 if fails else 0)


func _box(parent: Node, b: PhysicsBody3D, at: Vector3, size: Vector3) -> PhysicsBody3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.collision_layer = 1
	b.position = at
	parent.add_child(b)
	return b


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
