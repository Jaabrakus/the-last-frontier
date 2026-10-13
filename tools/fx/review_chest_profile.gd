extends SceneTree
## Review probe (read-only, headless): the body's chest z-profile (x from the midline, nearest-vertex z) along the apex's
## height under each blend shape, to see whether the "most forward point near the nominal place" that garment_chest.gd
## caps is a breast apex or the search circle's edge.
func _initialize() -> void:
	var GC := load("res://scripts/customizer/garment_chest.gd")
	var sc := load(BodyMaterials.BODY_GLB) as PackedScene
	var inst := sc.instantiate()
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi.mesh as ArrayMesh
		if m == null:
			continue
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			if mat == null or mat.resource_name != "skin":
				continue
			var shapes := {"": m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]}
			var bl := m.surface_get_blend_shape_arrays(s)
			for b in bl.size():
				shapes[String(m.get_blend_shape_name(b))] = bl[b][Mesh.ARRAY_VERTEX]
			for shp in shapes:
				var ap: Array = GC.apexes(shp)
				if ap.is_empty():
					continue
				var a: Vector3 = ap[0]
				var p: PackedVector3Array = shapes[shp]
				var line := "shape '%s' apex x=%.3f y=%.3f z=%.3f | z by x at |y-apex.y|<0.012: " % [shp, a.x, a.y, a.z]
				var best := {}
				for v in p:
					if v.z > 0.0 and absf(v.y - a.y) < 0.012 and v.x > 0.0 and v.x < 0.17:
						var kx := int(round(v.x * 100.0))
						if not best.has(kx) or v.z > best[kx]:
							best[kx] = v.z
				var ks := best.keys()
				ks.sort()
				for k in ks:
					line += "%d:%.3f " % [k, best[k]]
				print(line)
				print("   distance of the found apex from the nominal place: %.4f (search radius %.3f)" % [Vector2(a.x - GC.APEX_NOMINAL.x, a.y - GC.APEX_NOMINAL.y).length(), GC.APEX_SEARCH])
	inst.free()
	quit(0)
