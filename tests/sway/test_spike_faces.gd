extends SceneTree
## Every face of Stone Form's spike drawn from outside (FormModels.spike_mesh; the user, 2026-10-04: "the spike form doesnt
## have a texture its see thru"): closed all round, its foot capped (it is thrown now), and each triangle wound to face away from the spike's leaning middle at its height (Godot's
## front faces wind clockwise, seen from outside; a face wound the other way is culled and the spike is seen through).
##   Godot --headless --path . -s tests/sway/test_spike_faces.gd

func _initialize() -> void:
	var bad := 0
	var total := 0
	var open_edges := 0
	for seed in range(0, 200):
		for dims: Vector2 in [Vector2(0.09, 0.8), Vector2(0.3, 1.6), Vector2(0.2, 1.25)]:
			var m := FormModels.spike_mesh(dims.x, dims.y, seed)
			var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var iv: Variant = m.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
			var idx: PackedInt32Array = iv if iv != null else PackedInt32Array()
			var n := idx.size() if idx.size() > 0 else v.size()
			# the leaning middle: the tip's flat offset over its height
			var tip := Vector3.ZERO
			for p in v:
				if p.y > tip.y:
					tip = p
			# closed all round (Stone Form throws it: its foot is seen too): every edge shared by exactly two faces
			var edges := {}
			for t in range(0, n, 3):
				for e in 3:
					var p0 := v[idx[t + e] if idx.size() > 0 else t + e]
					var p1 := v[idx[t + (e + 1) % 3] if idx.size() > 0 else t + (e + 1) % 3]
					var k0 := Vector3i((p0 * 10000.0).round())
					var k1 := Vector3i((p1 * 10000.0).round())
					var key := str(k0) + str(k1) if str(k0) < str(k1) else str(k1) + str(k0)
					edges[key] = int(edges.get(key, 0)) + 1
			for key in edges:
				if int(edges[key]) != 2:
					open_edges += 1
			for t in range(0, n, 3):
				var a := v[idx[t] if idx.size() > 0 else t]
				var b := v[idx[t + 1] if idx.size() > 0 else t + 1]
				var c := v[idx[t + 2] if idx.size() > 0 else t + 2]
				var mid := (a + b + c) / 3.0
				var k := clampf(mid.y / dims.y, 0.0, 1.0)
				var out := Vector3(mid.x - tip.x * k, 0.0, mid.z - tip.z * k)
				if out.length() < 1e-5:
					continue
				total += 1
				# (front faces wind clockwise: their cross product points in, against `out`)
				if (b - a).cross(c - a).dot(out) > 0.0:
					bad += 1
	print("spike faces wound inward: %d of %d; open edges: %d" % [bad, total, open_edges])
	print("SPIKE FACES " + ("PASSED" if bad == 0 and open_edges == 0 else "FAILED"))
	quit(0 if bad == 0 and open_edges == 0 else 1)
