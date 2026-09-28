extends SceneTree
## The carry-gear GLBs (assets/loadout, tools/loadout/build_loadout_assets.py) import and load through
## LoadoutModels: every MANIFEST.json marker becomes a Marker3D at its position, display parts start
## hidden, the quiver's 24 arrow ends are one MultiMesh driven by set_arrow_count(), the slot markers
## give the spears / darts, the weapon-frame items sit on their weapon, every surface is textured, and
## the horn's reference placement starts on the measured horn capsule.
##
##   Godot --headless --path . -s tests/loadout/test_loadout_models.gd      (run under a hard time limit)

var _fails: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var man := LoadoutModels.manifest()
	_check(not man.is_empty(), "MANIFEST.json loads")
	_check(man.get("assets", []).size() == LoadoutModels.KINDS.size(), "MANIFEST lists %d assets" % LoadoutModels.KINDS.size())
	for kind in LoadoutModels.KINDS:
		_check_kind(kind)
	_check_quiver()
	_check_slots()
	_check_hosts()
	_check_horn_reference()
	if _fails.is_empty():
		print("LOADOUT MODELS TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL ", f)
		print("LOADOUT MODELS TEST FAILED (%d of %d checks)" % [_fails.size(), _checks])
		quit(1)


func _check_kind(kind: String) -> void:
	_check(LoadoutModels.has_glb(kind), "%s.glb imported" % kind)
	var model := LoadoutModels.build(kind)
	if model == null:
		_check(false, "%s builds" % kind)
		return
	var entry := LoadoutModels.manifest_entry(kind)
	_check(not entry.is_empty(), "%s in MANIFEST" % kind)
	var marks: Dictionary = entry.get("markers", {})
	_check(marks.size() >= 2, "%s has markers (%d)" % [kind, marks.size()])
	for mname: String in marks:
		var mk := model.get_node_or_null(NodePath(mname))
		_check(mk is Marker3D, "%s: marker %s is a Marker3D child" % [kind, mname])
		if mk is Marker3D:
			var p: Array = marks[mname]["pos"]
			var d := (mk as Marker3D).position.distance_to(Vector3(p[0], p[1], p[2]))
			_check(d < 0.001, "%s: %s at the MANIFEST position (%.4f m off)" % [kind, mname, d])
			if marks[mname].has("xform"):
				var xf: Variant = str_to_var(marks[mname]["xform"])
				_check(xf is Transform3D and (xf as Transform3D).basis.is_equal_approx((mk as Marker3D).basis), "%s: %s basis matches" % [kind, mname])
	for n: String in entry.get("nodes", {}):
		var node := model.find_child(n, true, false)
		_check(node != null, "%s: node %s present" % [kind, n])
	for n: String in LoadoutModels.DISPLAY_NODES.get(kind, []):
		var d := model.find_child(n, true, false) as Node3D
		_check(d != null and not d.visible, "%s: display part %s hidden" % [kind, n])
	var tris := 0
	var untextured: Array[String] = []
	for mi: MeshInstance3D in _meshes(model):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null or mat.albedo_texture == null or mat.normal_texture == null:
				untextured.append("%s/%d" % [mi.name, s])
	_check(tris > 100, "%s has geometry (%d tris without the arrow ends)" % [kind, tris])
	_check(untextured.is_empty(), "%s: every surface has colour and normal maps %s" % [kind, untextured])
	model.free()


func _check_quiver() -> void:
	var q := LoadoutModels.build("quiver")
	if q == null:
		return
	var a := q.get_node_or_null("Arrows")
	_check(a is MultiMeshInstance3D, "quiver arrows are one MultiMeshInstance3D")
	_check(LoadoutModels.arrow_capacity(q) == 24, "quiver holds 24 arrow ends")
	_check(LoadoutModels.arrow_count(q) == 24, "quiver starts full")
	LoadoutModels.set_arrow_count(q, 7)
	_check(LoadoutModels.arrow_count(q) == 7, "set_arrow_count(7) shows 7")
	LoadoutModels.set_arrow_count(q, 99)
	_check(LoadoutModels.arrow_count(q) == 24, "set_arrow_count clamps to 24")
	LoadoutModels.set_arrow_count(q, 0)
	_check(LoadoutModels.arrow_count(q) == 0, "set_arrow_count(0) empties it")
	if a is MultiMeshInstance3D:
		_check((a as MultiMeshInstance3D).multimesh.mesh != null, "the arrow MultiMesh has the arrow-end mesh")
	var nocks := LoadoutModels.marker_transform(q, "Nocks").origin
	_check(LoadoutModels.quiver_nocks_offset(q).origin.is_equal_approx(-nocks), "quiver_nocks_offset = -Nocks")
	q.free()
	var q2 := LoadoutModels.build("quiver", false)
	var holder := q2.get_node_or_null("Arrows") as Node3D
	_check(holder != null and holder.get_child_count() == 24, "multimesh=false keeps 24 arrow nodes")
	# (Instance transforms are not readable back from a MultiMesh under the headless dummy renderer,
	# so the arrow placement is checked on the per-node build.)
	var top := -INF
	var low := INF
	for c in holder.get_children():
		var xf := holder.transform * (c as Node3D).transform
		low = minf(low, xf.origin.y)
		top = maxf(top, (xf * Vector3(0, 0, 0.72)).y)
	_check(top > 0.15 and top < 0.22, "arrow nocks stand %.3f m above the mouth" % top)
	_check(low < -0.5, "arrow tips rest in the quiver (%.3f m)" % low)
	LoadoutModels.set_arrow_count(q2, 5)
	_check(LoadoutModels.arrow_count(q2) == 5, "per-node arrow count 5")
	q2.free()


func _check_slots() -> void:
	var t := LoadoutModels.build("spear_pair_tie")
	var s := LoadoutModels.slot_transforms(t, "Spear_")
	_check(s.size() == 2 and absf(s[0].origin.distance_to(s[1].origin) - 0.036) < 0.001, "two spear slots 3.6 cm apart")
	t.free()
	var b := LoadoutModels.build("dart_bundle")
	var d := LoadoutModels.slot_transforms(b, "Dart_")
	_check(d.size() == 5, "five dart slots")
	var ok := true
	for x in d:
		ok = ok and absf(Vector2(x.origin.x, x.origin.y).length() - 0.015) < 0.001 and x.basis.z.dot(Vector3.BACK) > 0.99
	_check(ok, "darts on a 1.5 cm ring, pointing +Z to the nocks")
	b.free()


func _check_hosts() -> void:
	# Weapon-frame items sit on their weapon: markers inside the weapon's bounds (+ a few cm).
	for kind: String in LoadoutModels.HOST:
		var host_kind: String = LoadoutModels.HOST[kind]
		var host: Node3D = ThrowableModels.build(host_kind) if host_kind == "tomahawk" else WeaponModels.build(host_kind)
		var box := _aabb(host).grow(0.03)
		var item := LoadoutModels.build(kind)
		var ok := true
		var worst := ""
		for m in LoadoutModels.markers(item):
			if m in ["StrapLoop", "Knot"]:
				continue      # the bow cord's loop hangs off the stave by design
			if not box.has_point(LoadoutModels.marker_transform(item, m).origin):
				ok = false
				worst = m
		_check(ok, "%s markers lie on the %s model (%s)" % [kind, host_kind, worst])
		item.free()
		host.free()
	var hook := LoadoutModels.build("pistol_belt_hook")
	_check(LoadoutModels.marker_transform(hook, "Hook").origin.x < -0.019, "belt hook seat on the pistol's left flat (-X)")
	hook.free()
	var frog := LoadoutModels.build("tomahawk_frog")
	var seat := LoadoutModels.marker_transform(frog, "BeltSeat").origin
	_check(seat.x > 0.015 and seat.y > 0.33 and seat.y < 0.38, "frog belt seat on the body (+X) side under the head")
	frog.free()


func _check_horn_reference() -> void:
	var ref: Dictionary = LoadoutModels.manifest_entry("powder_horn").get("reference_bind_placement", {})
	_check(ref.get("bone", "") == "spinec", "horn reference placement on spinec")
	var xf: Variant = str_to_var(String(ref.get("bind", "")))
	_check(xf is Transform3D, "horn reference placement parses")
	var carry: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/loadout/carry_gear.json"))
	if xf is Transform3D and carry is Dictionary:
		var caps: Array = carry["points"]["horn.powder_horn"]["capsules_bind"]
		var plug := Vector3(caps[0]["from"][0], caps[0]["from"][1], caps[0]["from"][2])
		var spout := Vector3(caps[1]["to"][0], caps[1]["to"][1], caps[1]["to"][2])
		var t := xf as Transform3D
		_check(t.origin.distance_to(plug) < 0.001, "horn origin on the measured plug point")
		var chord := (t.basis * Vector3(0, 0, 1)).normalized()
		_check(chord.dot((spout - plug).normalized()) > 0.999, "horn chord along plug -> spout")
		_check(t.basis.is_equal_approx(t.basis.orthonormalized()), "horn placement is a rotation")


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(n):
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		while p != n and p != null:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
