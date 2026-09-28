extends SceneTree
## Headless check of the imported spear model (assets/weapons/spear.glb, made by
## tools/models/spear.py) against the conventions ThrowableModels and the Throwable
## scripts rely on:
##   * the loader turns Muzzle, Tip, COM and Butt into Marker3D children of the root;
##   * origin = grip = COM; Tip and Muzzle at the point on the -Z axis; Butt at +Z;
##   * 1.80 m long, the point is the most forward vertex, blade flats face +/-Y;
##   * 1-4k triangles over the two meshes (Spear and its child Trim), one shared PBR
##     material (albedo, normal, metallic/roughness maps);
##   * the iron reads as metal: the blade's base colour is bright (sRGB median >= 0.55)
##     at metallic >= 0.9, the socket is not black;
##   * the Trim (stroud tails, hair tuft) is pivoted at the knot on the +X side and hangs
##     at most ~5 cm below the axis; ThrownProjectile streams it back in flight and, when
##     the spear lies on the ground, lays the spear blade-flat with nothing below ground;
##   * held on a hand prop bone with a half turn about Y, the point is along prop +Z.
##
##   Godot --headless --path . -s tests/throwables/verify_spear_model.gd

var failures := PackedStringArray()


func _expect(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok:
		failures.append(msg)


## World-space bounds of the vertices of every mesh at or under `n`.
func _world_bounds(n: Node) -> AABB:
	var box := AABB()
	var first := true
	var list: Array[Node] = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		list.append(n)
	for c in list:
		var mi := c as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p := mi.global_transform * v
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box


## Median of one channel (0 R .. 2 B, 3 = mean of RGB) over a rect given in 1024 px
## atlas pixels (rows from the top).
func _median(tex: Texture2D, rect: Rect2i, channel: int) -> float:
	var img := tex.get_image()
	if img == null:
		return -1.0
	if img.is_compressed():
		img.decompress()
	var sx := float(img.get_width()) / 1024.0
	var vals := PackedFloat32Array()
	for y in range(rect.position.y, rect.end.y, 3):
		for x in range(rect.position.x, rect.end.x, 3):
			var c := img.get_pixel(int(x * sx), int(y * sx))
			vals.append((c.r + c.g + c.b) / 3.0 if channel == 3 else [c.r, c.g, c.b][channel])
	vals.sort()
	return vals[vals.size() / 2] if vals.size() > 0 else -1.0


func _initialize() -> void:
	await process_frame            # global transforms need the tree running
	_expect(ThrowableModels.has_glb("spear"), "spear.glb imported")
	var m := ThrowableModels.build("spear")
	root.add_child(m)
	_expect(m.name == "SpearModel", "root named SpearModel (%s)" % m.name)
	var pos := {}
	for n in ["Muzzle", "Tip", "COM", "Butt"]:
		var mk := m.get_node_or_null(n)
		_expect(mk is Marker3D and mk.get_parent() == m, "%s is a Marker3D child of the root" % n)
		pos[n] = (mk as Node3D).position if mk else Vector3.INF
	var tip: Vector3 = pos["Tip"]
	var butt: Vector3 = pos["Butt"]
	_expect(tip.is_equal_approx(pos["Muzzle"]), "Tip and Muzzle coincide %s" % tip)
	_expect((pos["COM"] as Vector3).length() < 1e-4, "COM at the origin (the grip)")
	_expect(absf(tip.x) < 1e-4 and absf(tip.y) < 1e-4 and absf(tip.z + ThrowableModels.SPEAR_TIP) < 0.003,
			"point on -Z at %.4f (SPEAR_TIP %.3f)" % [tip.z, ThrowableModels.SPEAR_TIP])
	_expect(absf(butt.z - ThrowableModels.SPEAR_BUTT) < 0.003, "butt on +Z at %.4f (SPEAR_BUTT %.3f)" % [butt.z, ThrowableModels.SPEAR_BUTT])

	var tris := 0
	var zmin := INF
	var zmax := -INF
	var blade_x := 0.0
	var blade_y := 0.0
	var mat_ok := true
	var mats := {}
	var mat: BaseMaterial3D
	for c in m.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := m.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tris += (idx.size() if idx.size() > 0 else verts.size()) / 3
			for v in verts:
				var p := xf * v
				zmin = minf(zmin, p.z)
				zmax = maxf(zmax, p.z)
				if absf(p.z - (tip.z + 0.096)) < 0.004 and absf(p.y) < 0.01 and absf(p.x) < 0.03:
					blade_x = maxf(blade_x, absf(p.x))
					blade_y = maxf(blade_y, absf(p.y))
			mat = mi.get_active_material(s) as BaseMaterial3D
			mat_ok = mat_ok and mat != null and mat.albedo_texture != null and mat.normal_enabled \
					and mat.normal_texture != null and mat.metallic_texture != null and mat.roughness_texture != null
			if mat:
				mats[mat] = true
	if mat:
		print("  material %s: albedo %s, normal %s, metallic %s (channel %d), roughness %s (channel %d)" % [
				mat.resource_name, mat.albedo_texture, mat.normal_texture, mat.metallic_texture,
				mat.metallic_texture_channel, mat.roughness_texture, mat.roughness_texture_channel])
	_expect(tris >= 1000 and tris <= 4000, "%d triangles (1-4k)" % tris)
	_expect(absf(zmax - zmin - 1.80) < 0.005, "length %.4f m" % (zmax - zmin))
	_expect(absf(zmin - tip.z) < 1e-3, "the point is the most forward vertex (%.4f)" % zmin)
	_expect(blade_x > 3.0 * blade_y, "blade edges along X (%.4f), flats face Y (%.4f)" % [blade_x, blade_y])
	_expect(mat_ok and mats.size() == 1, "one shared PBR material: albedo, normal, metallic and roughness maps (%d)" % mats.size())

	# Iron colour. Atlas rows count from the top in Godot: the iron region is x 0..512,
	# y 768..1024; the blade is its first 0.63 (tip end), the socket its last 0.3.
	if mat and mat.albedo_texture and mat.metallic_texture:
		var blade := Rect2i(4, 772, 270, 248)
		var sock := Rect2i(360, 772, 148, 248)
		var ch := mat.metallic_texture_channel if mat.metallic_texture_channel < 3 else 2
		var bc := _median(mat.albedo_texture, blade, 3)
		var sc := _median(mat.albedo_texture, sock, 3)
		var bm := _median(mat.metallic_texture, blade, ch)
		_expect(bc >= 0.55, "blade base colour reads as bright iron (sRGB median %.3f)" % bc)
		_expect(sc >= 0.45, "socket base colour is iron, not black (sRGB median %.3f)" % sc)
		_expect(bm >= 0.9, "blade metallic %.3f" % bm)

	# Trim: a child mesh pivoted at the knot, hanging a little, trailing back.
	var trim := m.find_child("Trim", true, false) as MeshInstance3D
	_expect(trim != null, "Trim mesh (stroud tails and hair tuft) present")
	if trim:
		var piv := m.global_transform.affine_inverse() * trim.global_position
		_expect(piv.x > 0.01 and piv.x < 0.02 and absf(piv.y) < 0.006 and piv.z < -0.45 and piv.z > -0.6,
				"Trim pivot at the knot on the +X side, behind the socket (%s)" % piv)
		var tb := _world_bounds(trim)
		_expect(tb.position.y >= -0.052 and tb.end.z > piv.z + 0.05,
				"at rest the trim hangs at most 5 cm (min y %.3f) and trails back (to z %.3f)" % [tb.position.y, tb.end.z])

	# Held like the other weapons: on a prop bone with a half turn about Y, prop +Z forward.
	var prop := Node3D.new()
	root.add_child(prop)
	var held := ThrowableModels.build("spear")
	prop.add_child(held)
	held.basis = Basis(Vector3.UP, PI)
	var t_prop := prop.global_transform.affine_inverse() * (held.get_node("Tip") as Node3D).global_position
	_expect(t_prop.z > 0.79 and absf(t_prop.x) < 1e-4 and absf(t_prop.y) < 1e-4,
			"on a prop bone the point is along prop +Z (%s)" % t_prop)

	# In flight (point first, model +Y up) the trim streams back, close under the shaft.
	var fly := ThrownProjectile.new()
	fly.model_kind = "spear"
	fly.whoosh = false
	root.add_child(fly)
	fly.set_physics_process(false)
	fly.global_transform = Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), Vector3(0, 5, 0))
	var ftrim := fly.find_child("Trim", true, false) as Node3D
	_expect(ftrim != null, "the thrown spear has its Trim")
	if ftrim:
		var fb := _world_bounds(ftrim)
		_expect(fb.position.y > 5.0 - 0.035, "in flight the trim streams back (lowest %.3f m below the axis)" % (5.0 - fb.position.y))
	fly.queue_free()

	# Lying on the ground: blade flat (+Y up), nothing below the ground, trim laid out.
	for dir: Vector3 in [Vector3.FORWARD, Vector3(1, 0, 1).normalized()]:
		var p := ThrownProjectile.new()
		p.model_kind = "spear"
		p.whoosh = false
		root.add_child(p)
		p.set_physics_process(false)
		p.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(0, 0.5, 0))
		p._lie(Vector3.ZERO, Vector3.UP)
		var b := _world_bounds(p)
		var ptrim := p.find_child("Trim", true, false)
		var tb2 := _world_bounds(ptrim) if ptrim else b
		var up := p.global_basis.y.dot(Vector3.UP)
		_expect(up > 0.99, "lying blade-flat: model +Y up (%.3f)" % up)
		_expect(b.position.y > -0.002 and b.position.y < 0.004,
				"lying: resting on the ground, nothing below it (lowest %.4f)" % b.position.y)
		_expect(tb2.position.y > -0.002 and tb2.end.y < 0.035,
				"lying: trim laid out just above the ground (%.3f..%.3f)" % [tb2.position.y, tb2.end.y])
		p.queue_free()
	print("SPEAR MODEL CHECK " + ("PASSED" if failures.is_empty() else "FAILED: " + "; ".join(failures)))
	quit(0 if failures.is_empty() else 1)
