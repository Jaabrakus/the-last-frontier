extends RefCounted
## Prototype (package A performance pass): re-partitions the built tree LOD MultiMeshes of
## FrontierVegetation (Vegetation/Visuals/TreeLod{0,1,2}_<cx>_<cz>_<key>, 50 m cells) into
## sub-cells, so the LOD of a tree follows its own distance instead of its 50 m cell's. The
## 50 m impostor MultiMesh of each cell becomes the visibility parent of the cell's LOD2
## sub-cells (HLOD), so LOD2 and the impostors still switch at the same place.
## Used by forest_probe.gd (variant relod*) to measure the gain before the builder adopts it.
##
##   var undo := VegRelod.apply(level, 12.5, 30.0, 60.0)   # returns Callable that restores

static func apply(level: Node, sub: float, d0: float, d1: float) -> Callable:
	var visuals := level.get_node_or_null("Vegetation/Visuals")
	if visuals == null:
		return Callable()
	var scale := 1.0
	var s = level.get("settings")
	if s:
		scale = float(s.vegetation_distance_scale)
	var impostors := {}
	for c in visuals.get_children():
		var n := String(c.name)
		if n.begins_with("TreeImpostors_"):
			var parts := n.split("_")
			impostors[Vector2i(int(parts[1]), int(parts[2]))] = c
	var hidden: Array[Node3D] = []
	var added: Array[Node] = []
	for c in visuals.get_children():
		var n := String(c.name)
		if not n.begins_with("TreeLod") or not c is MultiMeshInstance3D:
			continue
		var mmi := c as MultiMeshInstance3D
		if not mmi.visible:
			continue
		var lod := int(n.substr(7, 1))
		var parts := n.split("_")
		var cell := Vector2i(int(parts[1]), int(parts[2]))
		var mm := mmi.multimesh
		var buf := mm.buffer
		var stride := 16
		var groups := {}
		for i in mm.instance_count:
			var o := i * stride
			var key := Vector2i(floori(buf[o + 3] / sub), floori(buf[o + 11] / sub))
			if not groups.has(key):
				groups[key] = PackedInt32Array()
			groups[key].append(i)
		for key: Vector2i in groups:
			var idx: PackedInt32Array = groups[key]
			var nb := PackedFloat32Array()
			nb.resize(idx.size() * stride)
			var ymin := INF
			var ymax := -INF
			for j in idx.size():
				var o := idx[j] * stride
				for k in stride:
					nb[j * stride + k] = buf[o + k]
				ymin = minf(ymin, buf[o + 7])
				ymax = maxf(ymax, buf[o + 7])
			var nmm := MultiMesh.new()
			nmm.transform_format = MultiMesh.TRANSFORM_3D
			nmm.use_custom_data = true
			nmm.mesh = mm.mesh
			nmm.instance_count = idx.size()
			nmm.buffer = nb
			var nm := MultiMeshInstance3D.new()
			nm.multimesh = nmm
			nm.material_override = mmi.material_override
			var margin := 12.0
			nm.custom_aabb = AABB(Vector3(key.x * sub - margin, ymin - 3.0, key.y * sub - margin),
					Vector3(sub + 2.0 * margin, ymax - ymin + 36.0, sub + 2.0 * margin))
			nm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			nm.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			nm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			match lod:
				0:
					nm.visibility_range_begin = 0.0
					nm.visibility_range_end = d0 * scale
					nm.visibility_range_end_margin = 5.0
				1:
					nm.visibility_range_begin = d0 * scale
					nm.visibility_range_begin_margin = 5.0
					nm.visibility_range_end = d1 * scale
					nm.visibility_range_end_margin = 5.0
				_:
					nm.visibility_range_begin = d1 * scale
					nm.visibility_range_begin_margin = 5.0
					nm.visibility_range_end = 0.0
			nm.name = "Relod%d_%d_%d" % [lod, key.x, key.y]
			visuals.add_child(nm)
			if lod == 2 and impostors.has(cell):
				nm.visibility_parent = nm.get_path_to(impostors[cell])
			added.append(nm)
		mmi.visible = false
		hidden.append(mmi)
	print("VEG_RELOD sub=%.1f d0=%.0f d1=%.0f new_mmis=%d replaced=%d" % [sub, d0, d1, added.size(), hidden.size()])
	return func() -> void:
		for a in added:
			a.queue_free()
		for h in hidden:
			h.visible = true
