extends SceneTree
## Headless check of the imported atlatl and dart models (tools/models/atlatl.py).
##   Godot --headless --path . -s tests/throwables/check_atlatl_model.gd
## Loads both through ThrowableModels (the GLB path, not the primitive fallback) and
## checks the conventions the throwable scripts rely on:
##   atlatl       origin at the grip, board back along +Z, Hook (= Spur) where the dart's
##                butt seats, Muzzle = Hook - (0, 0, dart length), COM on the board
##   atlatl_dart  origin at the point's tip, shaft back along +Z to Nock, COM on the axis
## plus PBR materials (albedo, normal and roughness textures) and the triangle budget
## (atlatl 1-4k, dart 0.6-4k).
## Prints ATLATL MODEL CHECK PASSED or FAILED (exit code 1).

var fails := 0


func _initialize() -> void:
	var atlatl := _load("atlatl")
	var dart := _load("atlatl_dart")
	if atlatl and dart:
		_check_atlatl(atlatl, dart)
		_check_dart(dart)
	print("ATLATL MODEL CHECK %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(0 if fails == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		fails += 1


func _load(kind: String) -> Node3D:
	_expect(ThrowableModels.has_glb(kind), "%s.glb imported" % kind)
	if not ThrowableModels.has_glb(kind):
		return null
	var m := ThrowableModels.build(kind)
	root.add_child(m)
	return m


## Model-space position of a marker, also when it is still a nested glTF node.
func _marker(model: Node3D, marker_name: String) -> Variant:
	var n := model.get_node_or_null(marker_name) as Node3D
	if n == null:
		n = model.find_child(marker_name, true, false) as Node3D
	if n == null:
		return null
	return _model_xf(model, n).origin


## Transform of `node` in `model` space (works before the tree is ready).
func _model_xf(model: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != model:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _meshes(model: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in model.find_children("*", "MeshInstance3D", true, false):
		out.append(c as MeshInstance3D)
	return out


func _aabb(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in _meshes(model):
		var box := _model_xf(model, mi) * mi.get_aabb()
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


func _check_pbr(model: Node3D, label: String) -> void:
	var ok := true
	var count := 0
	for mi in _meshes(model):
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as StandardMaterial3D
			count += 1
			if mat == null or mat.albedo_texture == null or not mat.normal_enabled or mat.normal_texture == null \
					or mat.roughness_texture == null:
				ok = false
	_expect(ok and count > 0, "%s: %d surface(s) with albedo, normal and roughness textures" % [label, count])


func _check_atlatl(m: Node3D, dart: Node3D) -> void:
	print("atlatl")
	var box := _aabb(m)
	var hook: Variant = _marker(m, "Hook")
	var spur: Variant = _marker(m, "Spur")
	var muzzle: Variant = _marker(m, "Muzzle")
	var com: Variant = _marker(m, "COM")
	var nock: Variant = _marker(dart, "Nock")
	print("    aabb %s  hook %s  muzzle %s  com %s  tris %d" % [box, hook, muzzle, com, _tris(m)])
	_expect(hook != null and spur != null and muzzle != null and com != null, "Hook, Spur, Muzzle and COM markers")
	_expect(m.get_node_or_null("Spur") is Marker3D and m.get_node_or_null("Muzzle") is Marker3D \
			and m.get_node_or_null("COM") is Marker3D, "loader turned Spur, Muzzle and COM into root Marker3Ds")
	if hook == null or spur == null or muzzle == null or com == null or nock == null:
		return
	var h := hook as Vector3
	_expect(h.distance_to(spur as Vector3) < 1e-4, "Hook == Spur")
	_expect(h.distance_to(ThrowableModels.ATLATL_SPUR) < 1e-3, "Hook at ThrowableModels.ATLATL_SPUR %s" % ThrowableModels.ATLATL_SPUR)
	var dart_len := (nock as Vector3).z
	_expect((muzzle as Vector3).distance_to(h - Vector3(0, 0, dart_len)) < 1e-3,
			"Muzzle = Hook - (0, 0, %.3f): the tip of a seated dart" % dart_len)
	_expect((muzzle as Vector3).z < -1.0 and h.z > 0.4, "forward is -Z: Muzzle ahead of the grip, Hook behind it")
	_expect(box.position.z < 0.0 and box.end.z > 0.5, "origin (grip) at the front of the board")
	_expect(box.size.z >= 0.5 and box.size.z <= 0.65, "board %.3f m long" % box.size.z)
	_expect(box.has_point(com as Vector3), "COM inside the board's bounds")
	_expect(absf(box.position.x + box.end.x) < 1e-3, "symmetric about x = 0")
	var t := _tris(m)
	_expect(t >= 1000 and t <= 4000, "%d triangles (1-4k)" % t)
	_check_pbr(m, "atlatl")


func _check_dart(m: Node3D) -> void:
	print("atlatl_dart")
	var box := _aabb(m)
	var com: Variant = _marker(m, "COM")
	var nock: Variant = _marker(m, "Nock")
	print("    aabb %s  com %s  nock %s  tris %d" % [box, com, nock, _tris(m)])
	_expect(com != null and nock != null, "COM and Nock markers")
	if com == null or nock == null:
		return
	var n := nock as Vector3
	_expect(absf(box.position.z) < 1e-3, "tip at the origin (front of the AABB at z = %.4f)" % box.position.z)
	_expect(absf(box.end.z - n.z) < 1e-3 and absf(n.x) + absf(n.y) < 1e-5, "shaft back along +Z to the Nock at z = %.3f" % n.z)
	_expect(box.size.z >= 1.55 and box.size.z <= 1.75, "dart %.3f m long (~1.6 m)" % box.size.z)
	var c := com as Vector3
	_expect(absf(c.x) + absf(c.y) < 1e-4 and c.z > 0.3 * n.z and c.z < 0.5 * n.z,
			"COM on the axis, %.0f%% back from the tip" % (100.0 * c.z / n.z))
	var t := _tris(m)
	_expect(t >= 600 and t <= 4000, "%d triangles (0.6-4k; 8-sided cane)" % t)
	_check_pbr(m, "atlatl_dart")
