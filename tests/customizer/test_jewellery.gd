extends SceneTree
## Jewellery for everyone (the owner, 2026-10-03: "add in nose and jewellery and earrings unlock for everyone"):
## the creator's Earrings, Nose, Neck and Rings rows (CreatorOptions.JEWEL_ROWS), every piece offered to every people
## and both body types, several worn at once, and FaceExtras' pieces on the body.
##
##   Godot --headless --path . -s tests/customizer/test_jewellery.gd
##   Godot --path . --resolution 1280x720 -s tests/customizer/test_jewellery.gd -- shots=DIR
##
## Exit code 0 and "JEWELLERY TEST OK" when every check passes. Run it under a hard time limit like every Godot run
## (about a minute headless). With shots= (a window) it also renders the lineups (shots_*.png: the pieces of each row on
## several peoples and both body types, a lineup of characters wearing several at once, the neck pieces over clothes,
## and the same characters in the creator's own stage: creator_face.png, creator_bust.png).
##
## Checks:
##   - data: every jewellery id is "none", a piece at one place (ears, nose, neck, hands) or a set of pieces ("parts")
##     whose items are its parts' items; every kind, place and material is known; no deny-listed word
##   - for every people and both body types each row offers every piece of its place, "none" first, the people's
##     documented pieces next (marked own); the documented customs are still the people's own pieces
##   - the model: every piece on several peoples and both body types: the part is there, at its place (ear lobes, nose,
##     round the neck outside the skin and the clothes, on the finger), skinned to headb, the neck and chest, or its
##     finger bone; none on a gloved hand
##   - several at once: ears, nose, neck and hands together in one part
##   - the pieces follow the face shapes (nose width, ears), the bust gauge and the body type
##   - save / load: the four rows survive AppearanceStore and current() finds them
##   - old looks: a look saved with one "jewellery" id (every old id) dresses the same pieces, loads into the rows, and
##     its file loads; select / current("jewellery") still pick a whole set
##   - the dice choose only plain or the people's own pieces
##   - the creator: the four rows, stepping them dresses the stage figure, the rows scroll to the focused one

var _fails: Array[String] = []
var _checks := 0
var _shots := ""
var _inst: Node3D
var _body: CharacterBodyMesh

const PEOPLES := ["english", "haudenosaunee", "west_african", "japanese", "south_asian", "arab"]
const KINDS := ["bob", "hoop", "stud", "drop", "septum", "septum_ring", "septum_pin", "nostril_hoop", "beads", "chain", "cord",
		"ribbon", "ring", "signet"]
const PENDANTS := ["cross", "locket", "disc", "tooth", "gorget"]
## The deny-list (tests/customizer/deny_words.gd: catalog.py's DENY_TERMS, the research's and the creator's words, as whole
## words), and this test's own: jewellery copy names no tattoo.
const DenyWords := preload("res://tests/customizer/deny_words.gd")
const DENY_EXTRA := ["tattoo\\w*"]
## Bones a neck piece may follow (the dominant weight of each vertex: the skin under it; a ribbon at mid-neck follows the
## head as the skin there does).
const NECK_BONES := ["neck", "spine", "clavicle", "breast", "head"]


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			_shots = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_shots)
	if not _shots.is_empty() and not _headless():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		await _lineups()
		print("JEWELLERY SHOTS DONE")
		quit(0)
		return
	_test_data()
	_test_rows()
	_body = _stage_body()
	await _frames(2)
	_test_model()
	_test_several()
	_test_follow()
	_test_garments()
	_test_store()
	_test_legacy()
	_test_dice()
	await _test_ui()
	print("JEWELLERY TEST %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
			"" if _fails.is_empty() else ", %d failed" % _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _look(pid: String, bt: int) -> Dictionary:
	return CreatorOptions.with_body_type(CreatorOptions.with_people({"sex": 1.0 if bt == 1 else 0.0}, pid), bt)


func _ids(opts: Array) -> Array:
	return opts.map(func(o: Dictionary) -> String: return String(o.id))


## Wears `id` in `row` (the look in place); false when the row does not offer it.
func _wear(lk: Dictionary, row: String, id: String) -> bool:
	var opts := CreatorOptions.options(row, lk)
	return CreatorOptions.select(row, lk, _ids(opts).find(id), opts)


func _plain(lk: Dictionary) -> Dictionary:
	for r: String in CreatorOptions.JEWEL_ROWS:
		lk[r] = "none"
	return lk


func _table() -> Dictionary:
	return CreatorOptions.data().get("jewellery", {})


func _pieces(place: String) -> Array:
	var out := []
	for id: String in _table():
		if CreatorOptions.jewel_place(id) == place:
			out.append(id)
	return out


func _row_of(place: String) -> String:
	for r: String in CreatorOptions.JEWEL_ROWS:
		if CreatorOptions.JEWEL_ROWS[r] == place:
			return r
	return ""


# --- data -----------------------------------------------------------------------------------------

func _test_data() -> void:
	var t := _table()
	var places: Array = CreatorOptions.JEWEL_ROWS.values()
	var bad := []
	for id: String in t:
		var e: Dictionary = t[id]
		var items: Array = e.get("items", [])
		for it: Dictionary in items:
			if not String(it.get("kind", "stud")) in KINDS:
				bad.append("%s: kind %s" % [id, it.get("kind")])
			if not CreatorOptions.JEWEL_AT.has(String(it.get("at", "ears"))):
				bad.append("%s: at %s" % [id, it.get("at")])
			for k in ["metal", "stone", "pendant_of", "cord", "ribbon"]:
				if it.has(k) and not FaceExtras.MATERIALS.has(String(it[k])):
					bad.append("%s: %s %s" % [id, k, it[k]])
			for b in it.get("beads", []):
				if not FaceExtras.MATERIALS.has(String(b)):
					bad.append("%s: bead %s" % [id, b])
			if it.has("pendant") and not String(it.pendant) in PENDANTS:
				bad.append("%s: pendant %s" % [id, it.pendant])
		if id == "none":
			if not items.is_empty():
				bad.append("none has items")
			continue
		if e.has("parts"):
			# a set (a look saved before the rows): its items are its parts' items, in order
			var want := []
			for p: String in e.parts:
				var pid := String(e.parts[p])
				if CreatorOptions.jewel_place(pid) != p:
					bad.append("%s: part %s is not a piece at %s" % [id, pid, p])
				want.append_array((t.get(pid, {}) as Dictionary).get("items", []))
			if str(want) != str(items):
				bad.append("%s: items differ from its parts' (%s / %s)" % [id, want, items])
		elif not CreatorOptions.jewel_place(id) in places:
			bad.append("%s: no single place" % id)
		var words := id.replace("_", " ") + " " + String(e.get("label", "")) + " " + String(e.get("note", ""))
		for w: String in DenyWords.hits(words, DENY_EXTRA):
			bad.append("%s: the word %s" % [id, w])
		if String(e.get("label", "")).is_empty():
			bad.append("%s: no label" % id)
	_check(bad.is_empty(), "every jewellery id is a known piece or set %s" % [bad])
	var counts := {}
	for p: String in places:
		counts[p] = _pieces(p).size()
	_check(counts.ears >= 18 and counts.nose >= 9 and counts.neck >= 15 and counts.hands >= 5,
			"enough pieces at every place %s" % [counts])
	for want: String in ["small_hoops_gold", "small_hoops_silver", "pearl_drops", "silver_drops", "gold_studs", "silver_studs",
			"sailor_hoop_gold", "nose_stud_gold", "nose_ring_gold", "septum_ring_silver", "beads_trade", "cord_bone_pendant",
			"chain_cross_gold", "chain_locket_gold", "gorget_silver", "ring_gold", "signet_gold"]:
		_check(t.has(want), "the piece %s exists" % want)
	var mats := {}
	for id: String in t:
		for it: Dictionary in (t[id] as Dictionary).get("items", []):
			for k in ["metal", "stone", "pendant_of"]:
				if it.has(k):
					mats[String(it[k])] = true
	_check(mats.has("brass") and mats.has("silver") and mats.has("gold") and mats.has("bone"), "brass, silver, gold and bone pieces (%s)" % [mats.keys()])


# --- the rows ---------------------------------------------------------------------------------------

func _test_rows() -> void:
	var d := CreatorOptions.data()
	for p: Dictionary in CharacterPeoples.peoples():
		var pid := String(p.id)
		for bt in [1, 2]:
			var lk := _look(pid, bt)
			var rows := CreatorOptions.rows(lk)
			_check(not "jewellery" in rows, "%s %d: no single jewellery row" % [pid, bt])
			for r: String in CreatorOptions.JEWEL_ROWS:
				_check(r in rows, "%s %d: the %s row" % [pid, bt, r])
				var opts := CreatorOptions.options(r, lk)
				var ids := _ids(opts)
				var all := _pieces(String(CreatorOptions.JEWEL_ROWS[r]))
				var missing := all.filter(func(x: String) -> bool: return not x in ids)
				_check(missing.is_empty() and ids.size() == all.size() + 1 and ids[0] == "none",
						"%s %d: %s offers every piece (%d of %d, missing %s)" % [pid, bt, r, ids.size() - 1, all.size(), missing])
				var own := CreatorOptions.jewel_own(lk, String(CreatorOptions.JEWEL_ROWS[r]))
				_check(ids.slice(1, 1 + own.size()) == own, "%s %d: %s lists the people's own pieces first (%s)" % [pid, bt, r, own])
				var flagged := opts.filter(func(o: Dictionary) -> bool: return bool(o.get("own", false))).map(func(o: Dictionary) -> String: return String(o.id))
				_check(flagged == own, "%s %d: %s marks its own pieces (%s)" % [pid, bt, r, flagged])
				_check(CreatorOptions.current(r, lk) == 0, "%s %d: %s plain after with_people" % [pid, bt, r])
	# documented customs: still each people's own pieces, now first in a row that offers everything
	var own := func(pid: String, bt: int, place: String) -> Array: return CreatorOptions.jewel_own(_look(pid, bt), place)
	for pid in ["arab", "kurdish", "egyptian"]:
		_check("nose_ring_gold" in own.call(pid, 2, "nose"), "%s women: the gold nose ring is their own" % pid)
	for pid in ["ethiopian", "vietnamese", "malay"]:
		_check((own.call(pid, 1, "ears") as Array).is_empty(), "%s men: no earrings of their own" % pid)
		_check(_ids(CreatorOptions.options("jewel_ears", _look(pid, 1))).size() > 10, "%s men: every earring offered" % pid)
	_check(own.call("pacific_islander", 1, "ears") == ["pearl_drops"] and own.call("pacific_islander", 2, "ears") == ["pearl_drops"],
			"pacific_islander: pearl drops their own, both sexes")
	_check("ear_bobs_silver" in own.call("haudenosaunee", 1, "ears") and "nose_jewel_silver" in own.call("haudenosaunee", 1, "nose"),
			"Eastern Woodlands men: ear bobs and the nose jewel their own (the set ear_bobs_nose gives both)")
	_check((own.call("japanese", 2, "ears") as Array).is_empty() and String((d.peoples.japanese as Dictionary).get("note_jewellery", "")).contains("Edo"),
			"japanese: no earrings of their own, the note kept")
	_check("ring_gold" in own.call("english", 1, "hands") and "pearl_strand" in own.call("english", 2, "neck"),
			"english: rings for men, pearls for women")
	# the row's choices are stable for the creator: stepping cycles through all and back
	var lk := _look("korean", 2)
	for r: String in CreatorOptions.JEWEL_ROWS:
		var n := CreatorOptions.options(r, lk).size()
		var ok := true
		for k in n:
			if CreatorOptions.step(r, lk, 1) != (k + 1) % n:
				ok = false
		_check(ok and CreatorOptions.current(r, lk) == 0, "korean 2: %s cycles through its %d choices" % [r, n])


# --- the model -----------------------------------------------------------------------------------

func _stage_body() -> CharacterBodyMesh:
	_inst = (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_inst)
	var sk := _inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := _inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	return CharacterBodyMesh.attach(sk, ap)


## The jewellery part's vertices, their dominant bone names and the part (null when none).
func _jewel_mesh(body: CharacterBodyMesh) -> Dictionary:
	var parts: Array = body.part_meshes(FaceExtras.PART_JEWELLERY)
	if parts.is_empty() or not is_instance_valid(parts[0]):
		return {}
	var mi := parts[0] as MeshInstance3D
	var m := mi.mesh as ArrayMesh
	var v := PackedVector3Array()
	var bones := []
	var mats := []
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var sv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var sb: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var sw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		v.append_array(sv)
		for i in sv.size():
			var best := 0
			for c in 4:
				if sw[i * 4 + c] > sw[i * 4 + best]:
					best = c
			bones.append(_bind_name(mi.skin, body.skeleton, sb[i * 4 + best]))
		mats.append(m.surface_get_name(s))
	return {"mi": mi, "v": v, "bones": bones, "mats": mats}


func _bind_name(skin: Skin, sk: Skeleton3D, i: int) -> String:
	var n := String(skin.get_bind_name(i))
	return n if not n.is_empty() else sk.get_bone_name(skin.get_bind_bone(i))


func _bone_rest(name: String) -> Vector3:
	var head := FaceExtras.head_mesh(_body)
	var i := FaceExtras._bind_of(head.skin, _body.skeleton, name)
	return FaceExtras._bind_origin(head.skin, i) if i >= 0 else Vector3.INF


func _centroid(v: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in v:
		c += p
	return c / maxf(v.size(), 1)


## "" when the dressed body wears `id` (a piece at `place`) where it belongs, else why not.
func _placed(body: CharacterBodyMesh, lk: Dictionary, place: String, id: String) -> String:
	var jm := _jewel_mesh(body)
	if jm.is_empty() or (jm.v as PackedVector3Array).is_empty():
		return "no part"
	var v: PackedVector3Array = jm.v
	var head := FaceExtras.head_mesh(body)
	var lm := FaceExtras.landmarks(head)
	var names := {}
	for b: String in jm.bones:
		names[b] = true
	match place:
		"ears":
			if names.keys() != ["headb"]:
				return "bones %s" % [names.keys()]
			for p in v:
				if minf(p.distance_to(lm.ear_l), p.distance_to(lm.ear_r)) > 0.04:
					return "a vertex %s away from the ears" % p
		"nose":
			if names.keys() != ["headb"]:
				return "bones %s" % [names.keys()]
			for p in v:
				if minf(p.distance_to(lm.columella), minf(p.distance_to(lm.ala_l), p.distance_to(lm.ala_r))) > 0.024:
					return "a vertex %s away from the nose" % p
		"neck":
			for b: String in names:
				if not NECK_BONES.any(func(n: String) -> bool: return b.contains(n)):
					return "follows %s" % b
			for p in v:
				if p.y < 1.05 or p.y > 1.42 or absf(p.x) > 0.16 or p.z < -0.1 or p.z > 0.2:
					return "a vertex %s away from the neck" % p
			var err := _outside(body, lk, id)
			if not err.is_empty():
				return err
		"hands":
			var items: Array = (_table()[id] as Dictionary).items
			var want := {}
			for it: Dictionary in items:
				want[String(FaceExtras.FINGERS[String(it.at)][0])] = true
			if names.keys().size() != want.size() or names.keys().any(func(b: String) -> bool: return not want.has(b)):
				return "bones %s, want %s" % [names.keys(), want.keys()]
			for it: Dictionary in items:
				var f: Array = FaceExtras.FINGERS[String(it.at)]
				var a := _bone_rest(String(f[0]))
				var b := _bone_rest(String(f[1]))
				var near := false
				for p in v:
					if Geometry3D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.014:
						near = true
				if not near:
					return "no ring on %s" % f[0]
			for p in v:
				var ok := false
				for it: Dictionary in items:
					var f: Array = FaceExtras.FINGERS[String(it.at)]
					if Geometry3D.get_closest_point_to_segment(p, _bone_rest(String(f[0])), _bone_rest(String(f[1]))).distance_to(p) < 0.02:
						ok = true
				if not ok:
					return "a vertex %s off the fingers" % p
	return ""


## "" when every point of the neck piece's loop lies outside what the ray through it meets first (the skin and the
## clothes), else why not.
func _outside(body: CharacterBodyMesh, lk: Dictionary, id: String) -> String:
	var head := FaceExtras.head_mesh(body)
	for it: Dictionary in (_table()[id] as Dictionary).items:
		var ctx := {"body": body, "head": head, "groups": {}, "skins": [], "hidden": [], "neck": {}}
		var loop: Dictionary = FaceExtras._strand_loop(ctx, it, 0.002)
		if loop.is_empty():
			return "no loop"
		var ns: Dictionary = ctx.neck
		FaceExtras._neck_build(ns)
		for k in FaceExtras.NECK_RAYS:
			# (each point's ray: level from the neck's axis at its height)
			var o: Vector3 = (loop.os as PackedVector3Array)[k]
			var p: Vector3 = (loop.p as PackedVector3Array)[k]
			var d := (p - o).normalized()
			var h := FaceExtras._cast(ns, o, d, [k - 1, k, k + 1])
			if not h.is_empty() and (p - o).length() < float(h[0]) - 0.0005:
				return "loop point %d inside a surface (%.4f < %.4f)" % [k, (p - o).length(), float(h[0])]
	return ""


func _test_model() -> void:
	var t0 := Time.get_ticks_msec()
	var n := 0
	for pid: String in PEOPLES:
		for bt in [1, 2]:
			var lk := _plain(_look(pid, bt))
			for r: String in CreatorOptions.JEWEL_ROWS:
				var place := String(CreatorOptions.JEWEL_ROWS[r])
				var bad := []
				for id: String in _pieces(place):
					_plain(lk)
					if not _wear(lk, r, id):
						bad.append("%s: not offered" % id)
						continue
					PlayerAppearance.dress(_body, lk)
					n += 1
					var why := _placed(_body, lk, place, id)
					if not why.is_empty():
						bad.append("%s: %s" % [id, why])
				_check(bad.is_empty(), "%s %d: every %s piece on the body %s" % [pid, bt, r, bad])
			_plain(lk)
			PlayerAppearance.dress(_body, lk)
			_check(_body.part_meshes(FaceExtras.PART_JEWELLERY).is_empty(), "%s %d: no part without jewellery" % [pid, bt])
	print("  model: %d pieces dressed in %d ms" % [n, Time.get_ticks_msec() - t0])
	# a gloved hand wears no ring; the other hand keeps its own
	var lk := _plain(_look("english", 1))
	_wear(lk, "jewel_hands", "rings_both_gold")
	var gl := lk.duplicate(true)
	gl["hide_regions"] = ["hand_l"]
	BodyMaterials.apply_look(_body, gl, ["head"])
	var jm := _jewel_mesh(_body)
	_check(not jm.is_empty() and not "l_ringa" in jm.bones and "r_ringa" in jm.bones, "no ring on a gloved hand, the other keeps its ring")
	gl["hide_regions"] = ["hand_l", "hand_r"]
	BodyMaterials.apply_look(_body, gl, ["head"])
	_check(_body.part_meshes(FaceExtras.PART_JEWELLERY).is_empty(), "no rings on two gloved hands")


# --- several at once -----------------------------------------------------------------------------

func _test_several() -> void:
	var lk := _plain(_look("south_asian", 2))
	var want := {"jewel_ears": "gold_hoops", "jewel_nose": "septum_ring_gold", "jewel_neck": "chain_locket_gold", "jewel_hands": "rings_several"}
	var ok := true
	for r: String in want:
		ok = _wear(lk, r, String(want[r])) and ok
	_check(ok, "four pieces chosen at once")
	for r: String in want:
		_check(CreatorOptions.jewel_id(lk, r) == want[r] and CreatorOptions.options(r, lk)[CreatorOptions.current(r, lk)].id == want[r],
				"the %s row keeps its piece with the others" % r)
	var n := 0
	for r: String in want:
		n += ((_table()[want[r]] as Dictionary).items as Array).size()
	_check(CreatorOptions.jewellery_items(lk).size() == n, "the items of all four pieces (%d)" % n)
	var t0 := Time.get_ticks_usec()
	PlayerAppearance.dress(_body, lk)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var jm := _jewel_mesh(_body)
	var head := FaceExtras.head_mesh(_body)
	var lm := FaceExtras.landmarks(head)
	var at := {"ears": 0, "nose": 0, "neck": 0, "hands": 0}
	if not jm.is_empty():
		for p: Vector3 in jm.v:
			if minf(p.distance_to(lm.ear_l), p.distance_to(lm.ear_r)) < 0.03:
				at.ears += 1
			elif p.distance_to(lm.septum) < 0.02:
				at.nose += 1
			elif p.y > 1.05 and p.y < 1.42 and absf(p.x) < 0.16:
				at.neck += 1
			elif p.y < 0.95:
				at.hands += 1
	_check(at.values().all(func(c: int) -> bool: return c > 0), "one part wears the ears, nose, neck and hands pieces %s" % [at])
	var names := {}
	for b: String in jm.get("bones", []):
		names[b] = true
	_check(names.has("headb") and names.has("l_ringa") and names.has("r_indexa") and names.keys().any(func(b: String) -> bool: return b.contains("neck") or b.contains("spine")),
			"each follows its own bones %s" % [names.keys()])
	t0 = Time.get_ticks_usec()
	PlayerAppearance.dress(_body, lk)
	var again := (Time.get_ticks_usec() - t0) / 1000.0
	print("  several: dress %.1f ms, again (loops cached) %.1f ms" % [ms, again])
	_check(again < 250.0, "dressing four pieces stays quick (%.1f ms)" % again)
	# the dressed look in the game: the player's look keeps them (AppearanceStore.validate)
	var v := AppearanceStore.validate(lk)
	for r: String in want:
		_check(String(v.get(r, "")) == want[r], "validate keeps %s" % r)


# --- following the face and the body --------------------------------------------------------------

func _jewel_centroid(lk: Dictionary) -> Vector3:
	PlayerAppearance.dress(_body, lk)
	var jm := _jewel_mesh(_body)
	return _centroid(jm.v) if not jm.is_empty() else Vector3.INF


func _test_follow() -> void:
	var lk := _plain(_look("english", 2))
	_wear(lk, "jewel_nose", "nose_stud_gold")
	var wide := lk.duplicate(true)
	(wide.face as Dictionary)["face_nose_width"] = 1.0
	var narrow := lk.duplicate(true)
	(narrow.face as Dictionary)["face_nose_width"] = -1.0
	var cw := _jewel_centroid(wide)
	var cn := _jewel_centroid(narrow)
	_check(cw.x > cn.x + 0.001, "the nostril stud follows the nose width (%.4f vs %.4f)" % [cw.x, cn.x])
	_plain(lk)
	_wear(lk, "jewel_ears", "gold_studs")
	var big := lk.duplicate(true)
	(big.face as Dictionary)["face_ears"] = 1.0
	var small := lk.duplicate(true)
	(small.face as Dictionary)["face_ears"] = -1.0
	var cb := _jewel_centroid(big)
	var cs := _jewel_centroid(small)
	_check(cb.distance_to(cs) > 0.0005, "the studs follow the ears' shape (%s vs %s)" % [cb, cs])
	# the bust gauge and the body type move a long strand's front
	_plain(lk)
	_wear(lk, "jewel_neck", "chain_cross_gold")
	var full := lk.duplicate(true)
	full["bust"] = 1.0
	var flat := lk.duplicate(true)
	flat["bust"] = -1.0
	# (the cross lies on the breastbone between the breasts, where the gauge moves the chest little, either way: it
	# follows it and stays outside the shirt and the skin at both ends of the gauge)
	var zf := _front_z(full)
	var why_f := _outside(_body, full, "chain_cross_gold")
	var zs := _front_z(flat)
	var why_s := _outside(_body, flat, "chain_cross_gold")
	_check(absf(zf - zs) > 0.0001 and why_f.is_empty() and why_s.is_empty(),
			"the cross follows the bust gauge, outside at both ends (%.4f vs %.4f; %s %s)" % [zf, zs, why_f, why_s])
	var long := lk.duplicate(true)
	_plain(long)
	_wear(long, "jewel_neck", "beads_trade")
	var drop := float(((_table().beads_trade as Dictionary).items[0] as Dictionary).drop)
	PlayerAppearance.dress(_body, long)
	var jl := _jewel_mesh(_body)
	var low := INF
	for p: Vector3 in jl.get("v", PackedVector3Array()):
		low = minf(low, p.y)
	var root := _bone_rest("neck")
	_check(absf(low - (root.y - 0.02 - drop)) < 0.012, "the beads' front hangs `drop` below the neck's root (%.3f, want %.3f)" % [low, root.y - 0.02 - drop])
	var man := _plain(_look("english", 1))
	_wear(man, "jewel_neck", "chain_cross_gold")
	_check(absf(_front_z(man) - _front_z(lk)) > 0.002, "the male fit's chest moves the cross (%.4f vs %.4f)" % [_front_z(man), _front_z(lk)])


## The z of the most forward vertex of the jewellery part (the pendant on the chest).
func _front_z(lk: Dictionary) -> float:
	PlayerAppearance.dress(_body, lk)
	var jm := _jewel_mesh(_body)
	var z := -1.0
	for p: Vector3 in jm.get("v", PackedVector3Array()):
		if p.y < 1.3:
			z = maxf(z, p.z)
	return z


# --- over the clothes ------------------------------------------------------------------------------

func _test_garments() -> void:
	var lk := _plain(_look("english", 1))
	_wear(lk, "jewel_neck", "beads_trade")
	var bare := lk.duplicate(true)
	bare["outfit"] = {"shirt": {"id": "-"}, "legs.lower": {"id": "-"}}
	var zb := _front_z(bare)
	var zs := _front_z(lk)
	_check(zs > zb + 0.0015, "the beads lie over the shirt (front %.4f) not on the skin under it (%.4f)" % [zs, zb])
	var why := _outside(_body, lk, "beads_trade")
	_check(why.is_empty(), "every bead's loop point outside the shirt and the skin (%s)" % why)
	# a waistcoat, a coat, a stock, the women's jacket and kerchief (when the catalog has them): still outside every layer
	for slot_id: Array in [[1, "vest", "waistcoat_sb"], [1, "outer", "frock_coat"], [1, "accessories.neck", "stock_linen"],
			[2, "outer", "jacket_womens"], [2, "accessories.neck", "kerchief_womens"], [2, "vest", "stays_laced"]]:
		if not PlayerOutfit.entry(String(slot_id[2])).is_empty() and PlayerOutfit.usable(String(slot_id[2])):
			var lo := _plain(_look("english", int(slot_id[0])))
			_wear(lo, "jewel_neck", "beads_trade")
			lo["outfit"] = {String(slot_id[1]): {"id": String(slot_id[2]), "colors": {}}}
			PlayerAppearance.dress(_body, lo)
			why = _outside(_body, lo, "beads_trade")
			_check(why.is_empty(), "the beads outside the %s (%s)" % [slot_id[2], why])
			why = _outside(_body, lo, "gorget_silver")
			_check(why.is_empty(), "the gorget's ribbon outside the %s (%s)" % [slot_id[2], why])
			_wear(lo, "jewel_neck", "gorget_silver")
			PlayerAppearance.dress(_body, lo)
			why = _plate_outside(_body, "silver")
			_check(why.is_empty(), "the gorget's crescent clear of the %s (%s)" % [slot_id[2], why])


## "" when every vertex of the jewellery's `mat` surface (a gorget's crescent) lies outside what a level ray from the
## neck's axis toward it meets (the skin and the layers over it), else the worst.
func _plate_outside(body: CharacterBodyMesh, mat: String) -> String:
	var jm := _jewel_mesh(body)
	if jm.is_empty():
		return "no part"
	var mi: MeshInstance3D = jm.mi
	var head := FaceExtras.head_mesh(body)
	var ctx := {"body": body, "head": head, "groups": {}, "skins": [], "hidden": [], "neck": {}}
	var ns: Dictionary = FaceExtras._neck_state(ctx)
	FaceExtras._neck_build(ns)
	var cz := (ns.root as Vector3).z
	var worst := 0.0
	var at := Vector3.ZERO
	var n := 0
	for si in mi.mesh.get_surface_count():
		if mi.mesh.surface_get_name(si) != mat:
			continue
		for p: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			if p.y > 1.36 or p.z < 0.0:
				continue
			n += 1
			var d := Vector3(p.x, 0.0, p.z - cz)
			var dist := d.length()
			d = d.normalized()
			var k := roundi(atan2(d.x, d.z) / (TAU / FaceExtras.NECK_RAYS))
			var h := FaceExtras._cast(ns, Vector3(0.0, p.y, cz), d, [k - 1, k, k + 1])
			if not h.is_empty() and float(h[0]) - dist > worst:
				worst = float(h[0]) - dist
				at = p
	if n == 0:
		return "no %s vertices" % mat
	return "" if worst < 0.0006 else "a vertex %.1f mm inside at %s" % [worst * 1000.0, at]


# --- save / load ------------------------------------------------------------------------------------

func _test_store() -> void:
	var lk := _plain(_look("haudenosaunee", 1))
	var want := {"jewel_ears": "ear_bobs_several", "jewel_nose": "septum_ring_silver", "jewel_neck": "gorget_silver", "jewel_hands": "ring_silver"}
	for r: String in want:
		_wear(lk, r, String(want[r]))
	var cur := {}
	for r: String in CreatorOptions.rows(lk):
		cur[r] = CreatorOptions.current(r, lk)
	var path := "user://appearance_test/jewellery.json"
	_check(AppearanceStore.save_file(path, AppearanceStore.validate(lk)), "save a look with four pieces")
	var back := AppearanceStore.load_file(path)
	var same := true
	for r: String in cur:
		if CreatorOptions.current(r, back) != cur[r]:
			same = false
			print("    %s %d -> %d" % [r, cur[r], CreatorOptions.current(r, back)])
	_check(same, "every row restored")
	for r: String in want:
		_check(String(back.get(r, "")) == want[r], "%s saved and loaded (%s)" % [r, back.get(r)])
	_check(str(CreatorOptions.jewellery_items(back)) == str(CreatorOptions.jewellery_items(lk)), "the same items after loading")
	# broken values fall back: a piece in the wrong row, an unknown id, a number
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": AppearanceStore.FORMAT, "version": 2,
			"look": {"jewel_ears": "gorget_silver", "jewel_nose": "crown_jewels", "jewel_neck": 4, "jewel_hands": "ring_gold"}}))
	f.close()
	var v := AppearanceStore.load_file(path)
	_check(v.get("jewel_ears") == "none" and v.get("jewel_nose") == "none" and not v.has("jewel_neck") and v.get("jewel_hands") == "ring_gold",
			"broken jewellery values fall back (%s)" % [[v.get("jewel_ears"), v.get("jewel_nose"), v.get("jewel_neck"), v.get("jewel_hands")]])
	DirAccess.remove_absolute(path)


# --- old looks ---------------------------------------------------------------------------------------

## The legacy ids: every jewellery id of the creator before the rows (2026-10-03).
const OLD_IDS := ["none", "ear_bobs_silver", "ear_bobs_several", "nose_jewel_silver", "ear_bobs_nose", "pearl_drops", "garnet_drops",
		"jade_drops", "small_hoops_gold", "gold_hoops", "silver_hoops", "ring_one_ear", "gold_studs", "nose_stud_gold", "nose_ring_gold",
		"studs_nose_stud"]


func _test_legacy() -> void:
	var t := _table()
	var bad := []
	for id: String in OLD_IDS:
		if not t.has(id):
			bad.append("%s missing" % id)
			continue
		var old := _look("west_african", 2)
		for r: String in CreatorOptions.JEWEL_ROWS:
			old.erase(r)
		old["jewellery"] = id
		var items_old := CreatorOptions.jewellery_items(old)
		var items_then: Array = (t[id] as Dictionary).get("items", [])
		if str(_sorted(items_old)) != str(_sorted(items_then)):
			bad.append("%s: items %s, then %s" % [id, items_old, items_then])
		PlayerAppearance.dress(_body, old)
		var m_old := _jewel_mesh(_body)
		var v := AppearanceStore.validate(old)
		if v.has("jewellery"):
			bad.append("%s: the old key kept" % id)
		var parts := CreatorOptions.jewel_parts(id)
		for r: String in CreatorOptions.JEWEL_ROWS:
			if String(v.get(r, "")) != String(parts.get(CreatorOptions.JEWEL_ROWS[r], "none")):
				bad.append("%s: %s = %s" % [id, r, v.get(r)])
		if str(_sorted(CreatorOptions.jewellery_items(v))) != str(_sorted(items_then)):
			bad.append("%s: loaded items differ" % id)
		PlayerAppearance.dress(_body, v)
		var m_new := _jewel_mesh(_body)
		if m_old.is_empty() != m_new.is_empty() or (not m_old.is_empty() and (m_old.v as PackedVector3Array).size() != (m_new.v as PackedVector3Array).size()):
			bad.append("%s: dressed differently" % id)
		elif not m_old.is_empty() and _centroid(m_old.v).distance_to(_centroid(m_new.v)) > 1e-5:
			bad.append("%s: pieces moved" % id)
		# the creator shows the set's pieces in the rows
		if id != "none" and CreatorOptions.current("jewellery", v) != _ids(CreatorOptions.options("jewellery", v)).find(id):
			bad.append("%s: current(jewellery) does not find the set" % id)
	_check(bad.is_empty(), "every old jewellery id loads into the rows and dresses the same %s" % [bad])
	# an old file on disk
	var path := "user://appearance_test/jewellery_old.json"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": AppearanceStore.FORMAT, "version": 2,
			"look": {"people": "shawnee", "sex": 1.0, "jewellery": "ear_bobs_nose", "name": "Old look"}}))
	f.close()
	var back := AppearanceStore.load_file(path)
	_check(back.get("jewel_ears") == "ear_bobs_silver" and back.get("jewel_nose") == "nose_jewel_silver" and back.get("jewel_neck") == "none"
			and not back.has("jewellery"), "an old file's jewellery loads into the rows (%s)" % [[back.get("jewel_ears"), back.get("jewel_nose")]])
	_check(CreatorOptions.current("jewel_ears", back) >= 0 and CreatorOptions.current("jewel_nose", back) >= 0, "the rows show the old pieces")
	DirAccess.remove_absolute(path)
	# a broken old id
	var bro := {"jewellery": "crown_jewels"}
	var vb := AppearanceStore.validate(bro)
	_check(not vb.has("jewellery") and vb.get("jewel_ears") == "none", "an unknown old id wears nothing")
	# the old API still picks a whole set
	var lk := _plain(_look("south_asian", 2))
	var opts := CreatorOptions.options("jewellery", lk)
	_check(CreatorOptions.select("jewellery", lk, _ids(opts).find("studs_nose_stud"), opts)
			and lk.jewel_ears == "gold_studs" and lk.jewel_nose == "nose_stud_gold" and lk.jewel_neck == "none",
			"select(jewellery) wears a set's pieces in the rows")
	_check(CreatorOptions.current("jewellery", lk) == _ids(opts).find("studs_nose_stud"), "current(jewellery) finds the set again")
	# old code writing the single key over a look with rows: the single id is what it wears
	lk["jewellery"] = "pearl_drops"
	_check(str(CreatorOptions.jewellery_items(lk)) == str((t.pearl_drops as Dictionary).items), "a single jewellery id written later wins")


func _sorted(items: Array) -> Array:
	var out := items.map(func(x) -> String: return str(x))
	out.sort()
	return out


# --- the dice ------------------------------------------------------------------------------------------

func _test_dice() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bad := []
	var worn := 0
	for pid: String in ["japanese", "arab", "english", "haudenosaunee", "ethiopian", "west_african"]:
		for bt in [1, 2]:
			var base := _look(pid, bt)
			for i in 12:
				var r := CreatorOptions.randomized(base, rng)
				for row: String in CreatorOptions.JEWEL_ROWS:
					var id := CreatorOptions.jewel_id(r, row)
					if id == "none":
						continue
					worn += 1
					if not id in CreatorOptions.jewel_own(r, String(CreatorOptions.JEWEL_ROWS[row])):
						bad.append("%s %d %s: %s" % [pid, bt, row, id])
					if CreatorOptions.current(row, r) < 0:
						bad.append("%s %d %s: custom" % [pid, bt, row])
	_check(bad.is_empty() and worn > 20, "the dice wear only the people's own pieces (%d worn) %s" % [worn, bad])


# --- the creator --------------------------------------------------------------------------------------------

func _test_ui() -> void:
	# the creator's layout at the game's 1280 x 720 (a headless run's window is tiny)
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var c := CharacterCreator.open(null)
	await _frames(8)
	if not is_instance_valid(c):
		_check(false, "the creator opens")
		return
	c.look = _plain(_look("persian", 2))
	c._refresh_all()
	await _frames(3)
	for r: String in CreatorOptions.JEWEL_ROWS:
		var ui: Dictionary = c._row_ui.get(r, {})
		_check(not ui.is_empty() and (ui.title as Label).text == CreatorOptions.ROW_LABELS[r], "the creator's %s row" % CreatorOptions.ROW_LABELS.get(r, r))
	c._set_focus("jewel_hands")
	await _frames(4)
	c._step("jewel_hands", 1)
	c._step("jewel_neck", 1)
	c._step("jewel_nose", 1)
	await _frames(3)
	_check(CreatorOptions.current("jewel_hands", c.look) == 1 and CreatorOptions.current("jewel_neck", c.look) == 1
			and CreatorOptions.current("jewel_nose", c.look) == 1, "stepping the rows wears the next pieces")
	var sb := c.stage.body if "body" in c.stage else null
	if sb is CharacterBodyMesh:
		_check(not (sb as CharacterBodyMesh).part_meshes(FaceExtras.PART_JEWELLERY).is_empty(), "the stage figure wears them")
	# the focused row scrolls into view
	var scroll: ScrollContainer = c._rows_scroll
	var last := String(CreatorOptions.rows(c.look)[-1])
	c._set_focus(last)
	await _frames(4)
	var pr := (c._row_ui[last].panel as Control).get_global_rect()
	var sr := scroll.get_global_rect()
	var bar := scroll.get_v_scroll_bar()
	_check(sr.grow(1.0).encloses(pr), "the last row (%s) scrolled into view (%s in %s; scroll %d of %d, page %d)"
			% [last, pr, sr, scroll.scroll_vertical, bar.max_value, bar.page])
	c._set_focus("face")
	await _frames(4)
	pr = (c._row_ui["face"].panel as Control).get_global_rect()
	sr = scroll.get_global_rect()
	_check(sr.grow(1.0).encloses(pr), "the Face row back in view")
	c._set_focus("jewel_neck")
	_check(c.stage.frame_name == "bust", "the Neck row frames the bust (%s)" % c.stage.frame_name)
	c._set_focus("jewel_ears")
	_check(c.stage.frame_name == "face", "the Earrings row frames the face")
	c.close(false)
	await _frames(3)


# --- the lineups (shots=DIR, a window) --------------------------------------------------------------------

var _world: Node3D
var _cam: Camera3D
var _label: Label


func _studio() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.33, 0.35, 0.37)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.55, 0.6)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# a sky for the metals to reflect (as the creator's stage has)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.6, 0.68)
	sky_mat.sky_horizon_color = Color(0.8, 0.78, 0.74)
	sky_mat.ground_horizon_color = Color(0.42, 0.4, 0.37)
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.1)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	for l in [[Vector3(-30, 25, 0), 1.1, true], [Vector3(-15, -60, 0), 0.35, false], [Vector3(-25, 160, 0), 0.55, false]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = l[1]
		d.shadow_enabled = l[2]
		_world.add_child(d)
	_cam = Camera3D.new()
	_cam.near = 0.01
	_world.add_child(_cam)
	_cam.current = true
	var cl := CanvasLayer.new()
	_world.add_child(cl)
	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 8)
	cl.add_child(_label)


## A figure at `x` (an Actor_B with the game's body, idle pose): [inst, skeleton, body].
func _figure(x: float, yaw := 0.0) -> Array:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	_world.add_child(inst)
	inst.position = Vector3(x, 0, 0)
	inst.rotation_degrees.y = yaw
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var body := CharacterBodyMesh.attach(sk, ap)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clip := "actor_b/actor_b-p-stealth-idle"
	if ap.has_animation(clip):
		ap.play(clip)
		ap.seek(0.3, true)
		ap.advance(0.0)
	return [inst, sk, body]


func _bone(f: Array, bone: String) -> Vector3:
	var sk: Skeleton3D = f[1]
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


func _aim(target: Vector3, offset: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.global_position = target + offset
	_cam.look_at(target)


func _grab() -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Contact sheets of `shots` ([Image]): `cols` columns, each shot scaled to `w` wide.
func _sheet(name: String, shots: Array, cols: int, w: int) -> void:
	if shots.is_empty():
		return
	var src: Image = shots[0]
	var h := int(float(w) * src.get_height() / src.get_width())
	var rows := int(ceil(float(shots.size()) / cols))
	var out := Image.create(cols * w, rows * h, false, Image.FORMAT_RGB8)
	out.fill(Color(0.1, 0.1, 0.1))
	for i in shots.size():
		var im := (shots[i] as Image).duplicate() as Image
		im.convert(Image.FORMAT_RGB8)
		im.resize(w, h, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	out.save_png("%s/%s.png" % [_shots, name])
	print("shot ", name)


func _lineups() -> void:
	_studio()
	var f := _figure(0.0)
	var body: CharacterBodyMesh = f[2]
	await _frames(4)
	var cases := [["english", 2], ["west_african", 1], ["south_asian", 2], ["haudenosaunee", 1], ["japanese", 2], ["arab", 1],
			["english", 1]]
	# every piece of each row, a people and body type in turn
	for r: String in CreatorOptions.JEWEL_ROWS:
		var place := String(CreatorOptions.JEWEL_ROWS[r])
		var shots := []
		var i := 0
		for id: String in _pieces(place):
			var c: Array = cases[i % cases.size()]
			i += 1
			var lk := _plain(_look(String(c[0]), int(c[1])))
			_wear(lk, r, id)
			PlayerAppearance.dress(body, lk)
			await _frames(2)
			var head := _bone(f, "headb")
			match place:
				"ears":
					_aim(head + Vector3(0.055, -0.012, 0.03), Vector3(0.2, 0.0, 0.13), 22.0)
				"nose":
					_aim(head + Vector3(0.0, -0.005, 0.12), Vector3(0.1, -0.01, 0.24), 18.0)
				"neck":
					_aim(_bone(f, "neck") + Vector3(0.0, -0.06, 0.04), Vector3(0.18, 0.04, 0.62), 26.0)
				"hands":
					var hand := _bone(f, "l_ringa")
					_aim(hand, Vector3(0.22, 0.05, 0.12), 24.0)
			_label.text = "%s  (%s %d)" % [CreatorOptions.label(r, lk, CreatorOptions.current(r, lk)), c[0], c[1]]
			shots.append(await _grab())
		await _sheet("shots_%s" % r, shots, 4, 400)
	# several at once: a lineup of seven characters, each wearing ears, nose, neck and hands pieces
	(f[0] as Node).queue_free()
	await _frames(2)
	var combos := [["gold_hoops", "nose_stud_gold", "chain_cross_gold", "ring_gold"], ["sailor_hoop_gold", "none", "beads_trade", "signet_gold"],
			["pearl_drops", "nostril_hoop_gold", "pearl_strand", "rings_both_gold"], ["ear_bobs_several", "nose_jewel_silver", "beads_trade", "ring_silver"],
			["coral_drops", "septum_ring_gold", "coral_beads", "rings_several"], ["silver_hoops", "septum_pin_bone", "cord_bone_pendant", "ring_brass"],
			["ring_one_ear", "none", "gorget_silver", "signet_gold"]]
	var figs := []
	for i in cases.size():
		var fi := _figure((i - (cases.size() - 1) * 0.5) * 0.58)
		var lk := _plain(_look(String(cases[i][0]), int(cases[i][1])))
		var j := 0
		for r: String in CreatorOptions.JEWEL_ROWS:
			_wear(lk, r, String(combos[i][j]))
			j += 1
		PlayerAppearance.dress(fi[2], lk)
		figs.append(fi)
	await _frames(4)
	_label.text = "Several at once: earrings, nose, neck, rings"
	_aim(Vector3(0.0, 1.22, 0.0), Vector3(0.0, 0.05, 4.4), 34.0)
	(await _grab()).save_png("%s/lineup_front.png" % _shots)
	var shots := []
	for i in figs.size():
		_label.text = "%s %d: %s" % [cases[i][0], cases[i][1], ", ".join(combos[i].filter(func(x: String) -> bool: return x != "none"))]
		_aim(_bone(figs[i], "neck") + Vector3(0.0, 0.03, 0.03), Vector3(0.22, 0.03, 0.72), 30.0)
		shots.append(await _grab())
	await _sheet("lineup_bust", shots, 4, 480)
	for fi: Array in figs:
		(fi[0] as Node).queue_free()
	await _frames(2)
	# the neck pieces over clothes: a shirt, a waistcoat, a coat, a stock
	var g := _figure(0.0)
	var outfits := [["bare", {"shirt": {"id": "-"}, "legs.lower": {"id": "-"}}, {"shirt": {"id": "-"}, "legs.lower": {"id": "-"}}],
			["shirt", {}, {}],
			["waistcoat / stays", {"vest": {"id": "waistcoat_sb", "colors": {}}}, {"vest": {"id": "stays_laced", "colors": {}}}],
			["coat / jacket", {"outer": {"id": "frock_coat", "colors": {}}, "vest": {"id": "waistcoat_sb", "colors": {}}},
				{"outer": {"id": "jacket_womens", "colors": {}}}],
			["stock / kerchief", {"accessories.neck": {"id": "stock_linen", "colors": {}}}, {"accessories.neck": {"id": "kerchief_womens", "colors": {}}}]]
	shots = []
	for o: Array in outfits:
		for id: String in ["beads_trade", "chain_cross_gold", "gorget_silver"]:
			for bt in [1, 2]:
				var lk := _plain(_look("english", bt))
				lk["outfit"] = o[bt]
				_wear(lk, "jewel_neck", id)
				PlayerAppearance.dress(g[2], lk)
				await _frames(2)
				_label.text = "%s over the %s (%d)" % [id, o[0], bt]
				_aim(_bone(g, "neck") + Vector3(0.0, -0.05, 0.04), Vector3(0.16, 0.05, 0.66), 28.0)
				shots.append(await _grab())
	await _sheet("shots_over_clothes", shots, 6, 320)
	(g[0] as Node).queue_free()
	await _creator_lineup(cases, combos)


## The creator's own stage (its lights and dim sky: what the player sees) with the same six characters and pieces,
## framed at the face and at the bust (creator_face.png, creator_bust.png: the middle of the screen).
func _creator_lineup(cases: Array, combos: Array) -> void:
	_world.queue_free()
	await _frames(3)
	var c := CharacterCreator.open(null)
	await _frames(10)
	var faces := []
	var busts := []
	for i in cases.size():
		var lk := _plain(_look(String(cases[i][0]), int(cases[i][1])))
		var j := 0
		for r: String in CreatorOptions.JEWEL_ROWS:
			_wear(lk, r, String(combos[i][j]))
			j += 1
		c.look = lk
		c._refresh_all()
		c.stage.show_look(lk, true)
		for fr: String in ["face", "bust"]:
			c.stage.frame(fr)
			await _frames(30)
			var im := await _grab()
			var w := im.get_width()
			var crop := im.get_region(Rect2i(int(w * 0.3), 0, int(w * 0.4), im.get_height()))
			(faces if fr == "face" else busts).append(crop)
	await _sheet("creator_face", faces, 7, 300)
	await _sheet("creator_bust", busts, 7, 300)
	c.close(false)
	await _frames(3)
