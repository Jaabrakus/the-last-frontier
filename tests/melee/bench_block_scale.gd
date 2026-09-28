extends SceneTree
## How the block check (MeleeSweep.near_defender) scales with the fighters on the map (user 2026-09-27: "big servers",
## 1000-2000 players): N stand-in fighters (a body each, in the melee_defender group) on a 3 m grid, one swing's path
## by one of them, the check timed. Prints "BLOCK SCALE N=<n> <us> us/check".
##   Godot --headless --path . -s tests/melee/bench_block_scale.gd

class Stand extends StaticBody3D:
	func block_power(_d: String, _p: Vector3, _w: Vector3) -> float:
		return 0.0


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var pts := {"head": Vector3(0, 0.8, 0), "edge": Vector3(0, 0.8, -0.17), "grip": Vector3(0, 0.46, 0), "butt": Vector3.ZERO}
	for n: int in [10, 100, 1000, 2000]:
		for c in world.get_children():
			c.free()
		var side := int(ceil(sqrt(float(n))))
		var first: Node3D = null
		for i in n:
			var s := Stand.new()
			var cs := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.3
			cap.height = 1.8
			cs.shape = cap
			cs.position = Vector3(0, 0.9, 0)
			s.add_child(cs)
			world.add_child(s)
			s.add_to_group(&"melee_defender")
			s.global_position = Vector3(float(i % side) * 3.0, 0.0, float(i / side) * 3.0)
			if first == null:
				first = s
		await physics_frame
		await physics_frame
		# (a swing by the first, its head sweeping across in front of it toward its neighbour 3 m off)
		var frames: Array = []
		for k in 4:
			frames.append(Transform3D(Basis(), first.global_position + Vector3(0.9 + 0.1 * k, 0.4, -0.3 + 0.2 * k)))
		var t0 := Time.get_ticks_usec()
		var reps := 200
		for r in reps:
			MeleeSweep.near_defender(first.get_world_3d().direct_space_state, frames, pts, first)
		var us := float(Time.get_ticks_usec() - t0) / reps
		# (and it still finds the one a swing comes at: the head crossing in to its neighbour's block line)
		var at: Vector3 = first.global_position
		var toward: Array = []
		for k in 4:
			toward.append(Transform3D(Basis(), at + Vector3(2.2 + 0.2 * k, 0.4, 0.0)))
		var near := MeleeSweep.near_defender(first.get_world_3d().direct_space_state, toward, pts, first)
		var found: Node = near.get("foe") as Node
		print("BLOCK SCALE N=%d %.1f us/check, finds the one coming at: %s" % [n, us,
				"yes" if found != null and found != first and (found as Node3D).global_position.distance_to(at + Vector3(3, 0, 0)) < 0.01 else "NO"])
	quit()
