extends SceneTree
## Headless check of the imported tomahawk model (tools/models/tomahawk.py).
##   Godot --headless --path . -s tests/throwables/check_tomahawk_model.gd
## Loads both variants through ThrowableModels (the GLB path, not the primitive
## fallback) and checks the conventions the throwable scripts rely on:
##   origin at the throwing grip near the haft end, haft up +Y, cutting edge toward -Z
##   (the throw direction, blade leading), poll toward +Z; Muzzle = Blade = Edge at the
##   middle of the edge, Head at the eye, COM, Butt; Mouthpiece on the pipe variant only;
##   the pipe variant is imported hidden when the whole GLB is instanced;
## plus PBR materials (albedo, normal, roughness and metallic textures) and the 1-4k
## triangle budget. Prints TOMAHAWK MODEL CHECK PASSED or FAILED (exit code 1).

var fails := 0


func _initialize() -> void:
	_check_raw_scene()
	var spike := _load("tomahawk")
	var pipe := _load("tomahawk_pipe")
	if spike:
		_check_variant(spike, "tomahawk", "Tomahawk", false)
	if pipe:
		_check_variant(pipe, "tomahawk_pipe", "TomahawkPipe", true)
	print("TOMAHAWK MODEL CHECK %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(0 if fails == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		fails += 1


func _load(kind: String) -> Node3D:
	_expect(ThrowableModels.has_glb(kind), "%s: tomahawk.glb imported" % kind)
	if not ThrowableModels.has_glb(kind):
		return null
	var m := ThrowableModels.build(kind)
	root.add_child(m)
	return m


func _meshes(model: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in model.find_children("*", "MeshInstance3D", true, false):
		out.append(c as MeshInstance3D)
	return out


func _aabb(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in _meshes(model):
		var box := mi.transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _tris(model: Node3D) -> int:
	var n := 0
	for mi in _meshes(model):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


## The GLB instanced as a whole (not through ThrowableModels): only the default shows.
func _check_raw_scene() -> void:
	print("tomahawk.glb as imported")
	var scene := load("res://assets/weapons/tomahawk.glb") as PackedScene
	_expect(scene != null, "tomahawk.glb loads as a PackedScene")
	if scene == null:
		return
	var inst := scene.instantiate() as Node3D
	var names: Array[String] = []
	for c in inst.get_children():
		names.append("%s:%s%s" % [c.name, c.get_class(), "" if (c as Node3D).visible else " (hidden)"])
	print("    children: ", names)
	var t := inst.get_node_or_null("Tomahawk") as MeshInstance3D
	var p := inst.get_node_or_null("TomahawkPipe") as MeshInstance3D
	_expect(t != null and p != null, "top-level meshes Tomahawk and TomahawkPipe")
	if t and p:
		_expect(t.visible and not p.visible, "Tomahawk visible, TomahawkPipe imported hidden (KHR_node_visibility)")
		_expect(t.transform.is_equal_approx(Transform3D.IDENTITY) and p.transform.is_equal_approx(Transform3D.IDENTITY),
				"both meshes at the model origin")
		_expect(p.get_node_or_null("Mouthpiece") != null, "Mouthpiece is a child of TomahawkPipe")
	inst.free()


func _check_variant(m: Node3D, kind: String, mesh_name: String, pipe: bool) -> void:
	print(kind)
	var meshes := _meshes(m)
	_expect(meshes.size() == 1 and meshes[0].name == mesh_name and meshes[0].visible,
			"only the %s mesh, visible (%s)" % [mesh_name, meshes.map(func(x: MeshInstance3D) -> String: return "%s%s" % [x.name, "" if x.visible else " hidden"])])
	for mk in ["Muzzle", "Blade", "Edge", "Head", "COM", "Butt"]:
		_expect(m.get_node_or_null(mk) is Marker3D, "%s is a root Marker3D" % mk)
	_expect((m.get_node_or_null("Mouthpiece") is Marker3D) == pipe, "Mouthpiece marker %s" % ("present" if pipe else "absent"))
	if not (m.get_node_or_null("Blade") is Marker3D and m.get_node_or_null("COM") is Marker3D):
		return
	var box := _aabb(m)
	var blade := ThrowableModels.marker_pos(m, "Blade")
	var com := ThrowableModels.marker_pos(m, "COM")
	var head := ThrowableModels.marker_pos(m, "Head")
	var butt := ThrowableModels.marker_pos(m, "Butt")
	print("    aabb %s  blade %s  head %s  com %s  butt %s  tris %d" % [box, blade, head, com, butt, _tris(m)])
	_expect(ThrowableModels.marker_pos(m, "Muzzle").distance_to(blade) < 1e-4 and ThrowableModels.marker_pos(m, "Edge").distance_to(blade) < 1e-4,
			"Muzzle = Blade = Edge")
	_expect(blade.distance_to(ThrowableModels.TOMAHAWK_EDGE) < 1e-3, "Blade at ThrowableModels.TOMAHAWK_EDGE %s" % ThrowableModels.TOMAHAWK_EDGE)
	_expect(com.distance_to(ThrowableModels.TOMAHAWK_COM) < 1e-3, "COM at ThrowableModels.TOMAHAWK_COM %s" % ThrowableModels.TOMAHAWK_COM)
	_expect(head.distance_to(Vector3(0, ThrowableModels.TOMAHAWK_HEAD_Y, 0)) < 1e-3, "Head at the eye, y = %.3f" % ThrowableModels.TOMAHAWK_HEAD_Y)
	_expect(m.get_node("Blade").transform.basis.is_equal_approx(Basis.IDENTITY), "markers unrotated (-Z = throw direction)")
	_expect(absf(box.position.z - blade.z) < 2e-3, "forward is -Z: the cutting edge is the front of the model (z %.3f)" % box.position.z)
	_expect(box.end.z > 0.04, "the poll points to +Z (%.3f)" % box.end.z)
	_expect(box.size.y >= 0.45 and box.size.y <= 0.6 and box.size.y > box.size.z, "haft along +Y, %.3f m" % box.size.y)
	_expect(butt.y < 0.0 and butt.y > -0.1 and absf(box.position.y - butt.y) < (0.009 if pipe else 1e-3),
			"origin at the grip, %.3f m above the haft end" % -butt.y)
	_expect(com.y > head.y * 0.6 and com.y < head.y and com.z < 0.0, "COM up the haft toward the head, on the blade side")
	_expect(absf(box.position.x + box.end.x) < 1e-3, "symmetric about x = 0")
	if pipe:
		_expect(ThrowableModels.marker_pos(m, "Mouthpiece").y < butt.y, "Mouthpiece below the haft end")
	var t := _tris(m)
	_expect(t >= 1000 and t <= 4000, "%d triangles (1-4k)" % t)
	var ok := true
	var count := 0
	for mi in meshes:
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as StandardMaterial3D
			count += 1
			if mat == null or mat.albedo_texture == null or not mat.normal_enabled or mat.normal_texture == null \
					or mat.roughness_texture == null or mat.metallic_texture == null:
				ok = false
	_expect(ok and count > 0, "%d surface(s) with albedo, normal, roughness and metallic textures" % count)
