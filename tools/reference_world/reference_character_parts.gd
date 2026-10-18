extends RefCounted
## Offline/reference-lab mesh parts only. No source resources or saves are changed.
## Fitted GLBs already use the current rig's bind space and named joint list.


static func apply_hands(body: CharacterBodyMesh, scene: PackedScene) -> Dictionary:
	var report := {"ok": false, "source_meshes": 0, "native_meshes_copied": 0,
		"native_triangles_removed": 0, "errors": []}
	if body == null or scene == null:
		(report.errors as Array).append("A current body and fitted hand PackedScene are required")
		return report
	var source_meshes := body.add_part("fitted_hands", scene)
	report.source_meshes = source_meshes.size()
	if source_meshes.is_empty() or not (body.report.missing as Array).is_empty():
		(report.errors as Array).append("The fitted hand scene has no meshes or unresolved target bones")
		return report
	var filtered := remove_native_hand_triangles(body)
	report.native_meshes_copied = filtered.native_meshes_copied
	report.native_triangles_removed = filtered.native_triangles_removed
	(report.errors as Array).append_array(filtered.errors)
	report.ok = (report.errors as Array).is_empty() and int(report.native_triangles_removed) > 0
	return report


## Keep vertices, skin influences, UVs, custom channels, normals, tangents and morph
## arrays. Only the copied index buffers lose triangles touching hand regions 19/25.
## That avoids stretching boundary triangles when a shader collapses hidden vertices.
static func remove_native_hand_triangles(body: CharacterBodyMesh) -> Dictionary:
	var report := {"native_meshes_copied": 0, "native_triangles_removed": 0, "errors": []}
	for instance: MeshInstance3D in body.part_meshes("head"):
		var original := instance.mesh as ArrayMesh
		if original == null:
			continue
		var replacement := ArrayMesh.new()
		replacement.blend_shape_mode = original.blend_shape_mode
		for shape in original.get_blend_shape_count():
			replacement.add_blend_shape(original.get_blend_shape_name(shape))
		var removed := 0
		for surface in original.get_surface_count():
			if original.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				(report.errors as Array).append("Unsupported native primitive type: " + String(instance.name))
				break
			var arrays := original.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for index in vertices.size():
					indices.append(index)
			var kept := PackedInt32Array()
			for triangle in range(0, indices.size() - 2, 3):
				var hand := false
				for corner in 3:
					var index := indices[triangle + corner]
					if index < uv2.size():
						var region := int(round(uv2[index].x)) & 63
						hand = hand or region == 19 or region == 25
				if hand:
					removed += 1
				else:
					kept.append_array(indices.slice(triangle, triangle + 3))
			# Retain surface slots and material overrides when an entire surface is removed.
			if kept.is_empty():
				kept = PackedInt32Array([0, 0, 0])
			arrays[Mesh.ARRAY_INDEX] = kept
			replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays,
				original.surface_get_blend_shape_arrays(surface), {}, original.surface_get_format(surface))
			replacement.surface_set_material(surface, original.surface_get_material(surface))
			replacement.surface_set_name(surface, original.surface_get_name(surface))
		if replacement.get_surface_count() != original.get_surface_count():
			continue
		if removed > 0:
			instance.mesh = replacement
			report.native_meshes_copied += 1
			report.native_triangles_removed += removed
	return report
