extends SceneTree
## Tattoos (the owner, 2026-10-03: "also we need tattoos"): the look's list of tattoos {design, place, x, y, scale,
## rotation, ink, fade} (Tattoos, data/customizer/tattoos.json), drawn on the skin by skin.gdshader (tattoo.gdshaderinc)
## from our own line-art atlas (assets/character/tattoos), and the creator's Tattoos row with its editor (TattooPanel).
##
##   Godot --headless --path . -s tests/customizer/test_tattoos.gd
##   Godot --path . --resolution 1280x720 -s tests/customizer/test_tattoos.gd -- shots=DIR
##
## Exit code 0 and "TATTOOS TEST OK" when every check passes (about half a minute headless; run it under a hard time
## limit like every Godot run). With shots= (a window) it renders the pictures instead (forearm_anchor, chest_compass,
## sailor_hand, creator_row, the lineups designs, places, inks_fade, sleeve) and checks the rendered pixels: ink at the
## place on bare skin, the same picture with and without the tattoo under a shirt; "TATTOOS SHOTS OK".
##
## Checks:
##   - data: every design has its SVG and its own atlas cell with ink in it, a label and a period note; no deny-listed
##     or tradition-specific word; every place has its frame measured on body.glb and known regions; the three inks;
##     SOURCE.md logs every design
##   - the shader's twin (tattoo.gdshaderinc's arithmetic on the body's bind pose, triangle by triangle): at every place
##     the design lands on the place's skin at its centre, reads the right way round (not mirrored), its top up (the
##     world's up, toward the shoulder, toward the wrist); the palm and the inner mouth stay bare; a move is that many
##     metres right or up as seen, a turn turns it anticlockwise, a size step grows it; a band goes all round the limb
##   - the look: add two (an anchor on the left forearm, a compass rose on the chest), edit and clamp them, the list's
##     limit, remove; a ring-only design moves to a limb
##   - the shader: the dressed body's skin material carries both (count, cells, regions, ink, the atlas, the arc map)
##   - save / load: both survive AppearanceStore with every field; broken entries are dropped or clamped
##   - clothes: under a man's shirt the forearm anchor and the chest compass draw nothing that shows (their skin
##     collapsed, or under the sleeve's own cloth); a woman's elbow-length shift leaves the forearm's anchor showing;
##     bare, both are drawn
##   - kept: a change of people, of body type and the dice keep them
##   - the creator: the Tattoos row (label, summary, count), stepping it adds, changes and removes; its editor (add,
##     design, place, ink, fade, move, size, turn, remove, done) edits the creator's look and dresses the stage

var _fails: Array[String] = []
var _checks := 0
var _shots := ""
var _inst: Node3D
var _body: CharacterBodyMesh

## Words no design may carry (the creator's deny-list, tests/customizer/test_jewellery.gd) and the traditions left for
## consultation (docs/research/peoples_dress_1750s.md 1.3: no Polynesian or Maori, no Indigenous North American designs).
const DENY := ["war", "clan", "feather", "wampum", "bonnet", "chief", "pipe", "tribal", "eagle", "negro", "mulatto", "coolie",
		"oriental", "harem", "savage", "moko", "tatau", "tattow", "maori", "polynesia", "polynesian", "hawaiian", "samoan",
		"tongan", "marquesan", "tahitian", "tapa", "kapa", "iroquois", "haudenosaunee", "lenape", "shawnee", "wabanaki",
		"native", "indigenous", "sacred", "totem", "henna", "irezumi", "yantra"]
const INKS := ["blue_black", "red", "green_faded"]
const PLACES := ["forearm_l", "forearm_r", "upper_arm_l", "upper_arm_r", "chest", "back", "hand_l", "hand_r", "neck", "cheek", "brow"]
const SOURCE_MD := "res://assets/character/tattoos/SOURCE.md"
## The man's basic shirt (PlayerOutfit.BASIC): long sleeves.
const SHIRT := "shirt_tucked"


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
	if not _load_skin():
		print("TATTOOS TEST FAILED (no skin in body.glb)")
		quit(1)
		return
	if not _shots.is_empty() and not _headless():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		await _pictures()
		print("TATTOOS SHOTS %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
				"" if _fails.is_empty() else ", %d failed" % _fails.size()])
		quit(0 if _fails.is_empty() else 1)
		return
	_test_data()
	_test_twin()
	_test_look()
	_test_store()
	_test_kept()
	_body = _stage_body()
	await _frames(2)
	_test_shader()
	_test_clothes()
	await _test_ui()
	print("TATTOOS TEST %s (%d checks%s)" % ["OK" if _fails.is_empty() else "FAILED", _checks,
			"" if _fails.is_empty() else ", %d failed" % _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _look(pid: String, bt: int) -> Dictionary:
	return CreatorOptions.with_body_type(CreatorOptions.with_people({"sex": 1.0 if bt == 1 else 0.0}, pid), bt)


## The two tattoos of the test: an anchor on the left forearm, a compass rose on the chest.
func _two(lk: Dictionary) -> Dictionary:
	lk["tattoos"] = []
	Tattoos.add(lk, "anchor", "forearm_l")
	Tattoos.add(lk, "compass_rose", "chest")
	return lk


func _ids(list: Array) -> Array:
	return list.map(func(e: Dictionary) -> String: return String(e.id))


func _stage_body() -> CharacterBodyMesh:
	_inst = (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_inst)
	var sk := _inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := _inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	return CharacterBodyMesh.attach(sk, ap)


## The skin material on a dressed body (the part "head": body.glb's skin surface).
func _skin_of(body: CharacterBodyMesh) -> ShaderMaterial:
	for mi: MeshInstance3D in body.part_meshes("head"):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src != null and src.resource_name == "skin":
				return mi.get_surface_override_material(s) as ShaderMaterial
	return null


# --- data -----------------------------------------------------------------------------------------

func _words(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("[a-z]+")
	for m in re.search_all(text.to_lower()):
		out.append(m.get_string())
	return out


func _test_data() -> void:
	var d := Tattoos.data()
	_check(d.get("format", "") == "frontier-tattoos", "tattoos.json loads")
	var designs := Tattoos.designs()
	var want := ["anchor", "compass_rose", "heart", "crossed_keys", "ship", "initials_date", "crucifix", "mermaid",
			"keelstone_star", "wind_spiral", "drift_waves", "band", "band_double", "dots"]
	_check(str(_ids(designs)) == str(want), "the designs: the sailors' marks, the sky crews' marks, bands and dots (%s)" % [_ids(designs)])
	var cells := {}
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(Tattoos.ATLAS))
	_check(atlas != null and atlas.get_width() == 1024 and atlas.get_height() == 1024, "the atlas is 1024 px square")
	var src := FileAccess.get_file_as_string(SOURCE_MD) if FileAccess.file_exists(SOURCE_MD) else ""
	_check(not src.is_empty(), "assets/character/tattoos/SOURCE.md exists")
	var bad := []
	for e: Dictionary in designs:
		var id := String(e.id)
		var cell := int(e.get("cell", -1))
		if cell < 0 or cell >= 16 or cells.has(cell):
			bad.append("%s: cell %d" % [id, cell])
		cells[cell] = id
		if not FileAccess.file_exists("res://tools/character/tattoos/designs/%s.svg" % id):
			bad.append("%s: no svg" % id)
		if String(e.get("label", "")).is_empty() or String(e.get("note", "")).length() < 20:
			bad.append("%s: label or note missing" % id)
		for w in _words(id.replace("_", " ") + " " + String(e.get("label", "")) + " " + String(e.get("note", ""))):
			if w in DENY:
				bad.append("%s: the word %s" % [id, w])
		if not src.contains("`%s`" % id):
			bad.append("%s: not in SOURCE.md" % id)
		if atlas != null and _cell_ink(atlas, cell) < 0.01:
			bad.append("%s: its atlas cell has no ink" % id)
		for p in e.get("places", []):
			if not String(p) in PLACES:
				bad.append("%s: unknown place %s" % [id, p])
	_check(bad.is_empty(), "every design: its own cell with ink, an SVG, a label, a note, logged %s" % [bad])
	if atlas != null:
		var empty := true
		for c in 16:
			if not cells.has(c) and _cell_ink(atlas, c) > 0.0:
				empty = false
		_check(empty, "the atlas's unused cells are empty")
		# a margin round each design: the mip levels used for the ink's spread (down to a 16 px cell) must not reach the
		# next cell; a band spans its width on purpose (its top and bottom keep the margin)
		var edge := true
		for c: int in cells:
			var e := _cell_edge_ink(atlas, c, Tattoos.is_repeat(String(cells[c])))
			if e > 0.02:
				edge = false
				print("    ink at the edge of cell %d (%s): %.3f" % [c, cells[c], e])
		_check(edge, "the designs keep their margins")
	_check(str(_ids(Tattoos.places())) == str(PLACES), "the places: forearms, upper arms, chest, back, hands, neck, cheek, brow")
	var mp: Dictionary = Tattoos.map().get("places", {})
	var ids := BodyMaterials.region_ids()
	bad = []
	for p: Dictionary in Tattoos.places():
		var pid := String(p.id)
		if not mp.has(pid):
			bad.append("%s: not measured" % pid)
		for r in p.get("regions", []):
			if not ids.has(String(r)):
				bad.append("%s: region %s" % [pid, r])
		if String(p.get("label", "")).is_empty() or not (p.get("reach") is Array) or not (p.get("view") is Dictionary):
			bad.append("%s: label, reach or view" % pid)
	_check(bad.is_empty(), "every place: measured on body.glb, known regions, a label, a reach, a view %s" % [bad])
	_check(str(_ids(Tattoos.inks())) == str(INKS), "the inks: blue-black, red, faded green")
	_check(Tattoos.max_count() == Tattoos.SHADER_MAX, "the list holds as many as the shader draws (%d)" % Tattoos.max_count())
	# everyone may wear every design (the owner, 2026-10-03): no people, sex or unlock fields
	var gated := designs.filter(func(e: Dictionary) -> bool: return e.has("peoples") or e.has("sex") or e.has("unlock") or e.has("review"))
	_check(gated.is_empty(), "no design is held back by people, sex or unlock %s" % [_ids(gated)])


func _cell_ink(img: Image, cell: int) -> float:
	var w := img.get_width() / 4
	var x0 := (cell % 4) * w
	var y0 := (cell / 4) * w
	var s := 0.0
	for y in range(y0, y0 + w, 4):
		for x in range(x0, x0 + w, 4):
			s += img.get_pixel(x, y).r
	return s / float((w / 4) * (w / 4))


## The most ink in a pixel of the cell's outer 16 px (one texel of its smallest mip level used: the designs keep 22 px
## at 256), along its top and bottom only with `rows_only`.
func _cell_edge_ink(img: Image, cell: int, rows_only := false) -> float:
	var w := img.get_width() / 4
	var x0 := (cell % 4) * w
	var y0 := (cell / 4) * w
	var s := 0.0
	for k in w:
		for m in 16:
			s = maxf(s, maxf(img.get_pixel(x0 + k, y0 + m).r, img.get_pixel(x0 + k, y0 + w - 1 - m).r))
			if not rows_only:
				s = maxf(s, maxf(img.get_pixel(x0 + m, y0 + k).r, img.get_pixel(x0 + w - 1 - m, y0 + k).r))
	return s


# --- the body's skin and the shader's twin ------------------------------------------------------------

var _V: PackedVector3Array
var _N: PackedVector3Array
var _raw := PackedVector2Array()
var _mh := PackedVector2Array()
var _reg := PackedInt32Array()
var _tri: PackedInt32Array
var _atlas: Image
var _arc := {}


## body.glb's skin in its bind pose: positions, normals, the metre UVs (u, height), MakeHuman's UVs, regions, triangles.
func _load_skin() -> bool:
	var sc := (load(BodyMaterials.BODY_GLB) as PackedScene).instantiate()
	for mi: MeshInstance3D in sc.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null or mat.resource_name != "skin":
				continue
			var a := mi.mesh.surface_get_arrays(s)
			_V = a[Mesh.ARRAY_VERTEX]
			_N = a[Mesh.ARRAY_NORMAL]
			_tri = a[Mesh.ARRAY_INDEX]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
			var c0 = a[Mesh.ARRAY_CUSTOM0]
			var fl: PackedFloat32Array = c0.to_float32_array() if c0 is PackedByteArray else c0
			var st := fl.size() / _V.size()
			_raw.resize(_V.size())
			_mh.resize(_V.size())
			_reg.resize(_V.size())
			for i in _V.size():
				_raw[i] = Vector2(uv[i].x, 1.0 - uv[i].y)
				_mh[i] = Vector2(fl[i * st], fl[i * st + 1])
				_reg[i] = int(uv2[i].x + 0.5) & 63
	sc.free()
	_atlas = Image.load_from_file(ProjectSettings.globalize_path(Tattoos.ATLAS))
	if _atlas != null:
		_atlas.convert(Image.FORMAT_L8)
	_arc = Tattoos.map().get("arc", {})
	return not _V.is_empty() and _atlas != null and not _arc.is_empty()


## The torso's arc map at (u, height), as the shader samples it (bilinear, round the body, clamped in height).
func _arc_at(raw: Vector2) -> Vector2:
	var span := float(_arc.u_span)
	var uu := raw.x - span * roundf(raw.x / span)
	var ty := clampf((raw.y - float(_arc.v0)) / (float(_arc.v1) - float(_arc.v0)), 0.0, 1.0)
	var nu := int(_arc.nu)
	var nv := int(_arc.nv)
	var fx := (uu - float(_arc.u0)) / span * nu - 0.5
	var fy := ty * (nv - 1)
	var x0 := int(floor(fx))
	var y0 := mini(int(floor(fy)), nv - 2)
	var kx := fx - x0
	var ky := fy - y0
	var out := Vector2.ZERO
	for ch in 2:
		var g: Array = _arc.front if ch == 0 else _arc.back
		out[ch] = lerpf(lerpf(float(g[y0][posmod(x0, nu)]), float(g[y0][posmod(x0 + 1, nu)]), kx),
				lerpf(float(g[y0 + 1][posmod(x0, nu)]), float(g[y0 + 1][posmod(x0 + 1, nu)]), kx), ky)
	return out


## A point's coordinates in the row's place's space (tattoo.gdshaderinc: uv, front, back, mh).
func _coord(row: Dictionary, raw: Vector2, mh: Vector2, region: int) -> Vector2:
	var space := int((row.p as Vector4).x + 0.5)
	if space == 1 or space == 2:
		var arc := _arc_at(raw) if region >= 2 and region <= 11 else Vector2.ZERO
		return Vector2(arc.x if space == 1 else arc.y, raw.y)
	return mh if space == 3 else raw


## The design's square coordinates q of a point (|q| < 0.5 inside).
func _q(row: Dictionary, c: Vector2) -> Vector2:
	var p: Vector4 = row.p
	var b: Vector4 = row.b
	var m: Vector4 = row.m
	var s: Vector4 = row.s
	var d := c - Vector2(b.z, b.w)
	if p.y > 0.0:
		d.x -= p.y * roundf(d.x / p.y)
	var q := Vector2(m.x * d.x + m.y * d.y, m.z * d.x + m.w * d.y) + Vector2(b.x, b.y)
	if s.z > 0.0 and p.y > 0.0:
		var k := s.z / p.y
		q.x = (fposmod(d.x * k + 0.5, 1.0) - 0.5) * s.w
	return q


## The atlas's ink coverage (0..1, bilinear at full size) of the row's design at q.
func _cov(row: Dictionary, q: Vector2) -> float:
	if absf(q.x) >= 0.5 or absf(q.y) >= 0.5:
		return 0.0
	var cell := int((row.s as Vector4).x + 0.5)
	var w := float(_atlas.get_width()) / 4.0
	var fx := (float(cell % 4) + q.x + 0.5) * w - 0.5
	var fy := (float(cell / 4) + 0.5 - q.y) * w - 0.5
	var x0 := clampi(int(floor(fx)), 0, _atlas.get_width() - 2)
	var y0 := clampi(int(floor(fy)), 0, _atlas.get_height() - 2)
	var kx := clampf(fx - x0, 0.0, 1.0)
	var ky := clampf(fy - y0, 0.0, 1.0)
	return lerpf(lerpf(_atlas.get_pixel(x0, y0).r, _atlas.get_pixel(x0 + 1, y0).r, kx),
			lerpf(_atlas.get_pixel(x0, y0 + 1).r, _atlas.get_pixel(x0 + 1, y0 + 1).r, kx), ky)


## Samples per triangle edge of the twin (SUB x SUB points in each triangle: the body's triangles are about a square
## centimetre, as large as a design's strokes).
const SUB := 6


## The shader's arithmetic over the bind pose, at SUB x SUB points in every triangle of the place (what a fragment
## there would compute): the points the row inks (coverage x density over 0.25), skipping the regions whose bits the
## row does not carry (a covered region's skin collapses). {count (points), area (m2), regions {name: points}, centre
## (area-weighted), right / up (dP/dq: the design's axes on the skin), normal, mirrored (the share read mirror-wise),
## normals (one per inked triangle), ink (the coverage's integral over the skin, m2)}.
func _footprint(row: Dictionary) -> Dictionary:
	var names := {}
	var ids := BodyMaterials.region_ids()
	for n: String in ids:
		names[int(ids[n])] = n
	var lo := int((row.p as Vector4).z)
	var hi := int((row.p as Vector4).w)
	var side := (row.s as Vector4).y
	var rep := (row.s as Vector4).z > 0.0
	var dens := (row.ink as Vector4).w
	var out := {"count": 0, "area": 0.0, "regions": {}, "centre": Vector3.ZERO, "right": Vector3.ZERO, "up": Vector3.ZERO,
			"normal": Vector3.ZERO, "mirrored": 0.0, "normals": [], "ink": 0.0}
	var mir := 0.0
	var bary := []
	for i in SUB:
		for j in SUB - i:
			bary.append(Vector2(i + 1.0 / 3.0, j + 1.0 / 3.0) / SUB)
			if i + j <= SUB - 2:
				bary.append(Vector2(i + 2.0 / 3.0, j + 2.0 / 3.0) / SUB)
	for t in range(0, _tri.size(), 3):
		var i0 := _tri[t]
		var i1 := _tri[t + 1]
		var i2 := _tri[t + 2]
		var r := _reg[i0]
		if r >= 32 or ((lo >> r) & 1 if r < 16 else (hi >> (r - 16)) & 1) == 0:
			continue
		var q0 := _q(row, _coord(row, _raw[i0], _mh[i0], r))
		var q1 := _q(row, _coord(row, _raw[i1], _mh[i1], r))
		var q2 := _q(row, _coord(row, _raw[i2], _mh[i2], r))
		# (the square's neighbourhood only: a triangle wholly beyond one of its edges inks nothing)
		var lo_q := Vector2(minf(q0.x, minf(q1.x, q2.x)), minf(q0.y, minf(q1.y, q2.y)))
		var hi_q := Vector2(maxf(q0.x, maxf(q1.x, q2.x)), maxf(q0.y, maxf(q1.y, q2.y)))
		if lo_q.y >= 0.5 or hi_q.y <= -0.5 or (not rep and hi_q.x - lo_q.x < 1.0 and (lo_q.x >= 0.5 or hi_q.x <= -0.5)):
			continue
		var e1 := _V[i1] - _V[i0]
		var e2 := _V[i2] - _V[i0]
		var n := (_N[i0] + _N[i1] + _N[i2]).normalized()
		var tn := e1.cross(e2)
		if side != 0.0:
			# the metre UVs' handedness on the surface (the shader's `hand`)
			var f1 := _raw[i1] - _raw[i0]
			var f2 := _raw[i2] - _raw[i0]
			if signf((f1.x * f2.y - f2.x * f1.y) * tn.dot(n)) != side:
				continue
		var da := 0.5 * tn.length() / float(SUB * SUB)
		var hit := 0
		for bc: Vector2 in bary:
			var w0 := 1.0 - bc.x - bc.y
			var raw := _raw[i0] * w0 + _raw[i1] * bc.x + _raw[i2] * bc.y
			var mh := _mh[i0] * w0 + _mh[i1] * bc.x + _mh[i2] * bc.y
			var q := _q(row, _coord(row, raw, mh, r))
			var cv := _cov(row, q)
			out.ink += cv * da
			if cv * dens < 0.25:
				continue
			hit += 1
			out.centre += (_V[i0] * w0 + _V[i1] * bc.x + _V[i2] * bc.y) * da
		if hit == 0:
			continue
		var area := da * hit
		out.count += hit
		out.area += area
		out.normal += n * area
		(out.normals as Array).append(n)
		var nm := String(names.get(r, str(r)))
		out.regions[nm] = int(out.regions.get(nm, 0)) + hit
		if rep:
			continue
		# the design's axes on the skin: dP/dq from the triangle's corners
		var d1 := q1 - q0
		var d2 := q2 - q0
		var det := d1.x * d2.y - d2.x * d1.y
		if absf(det) < 1e-9 or d1.length() > 0.5 or d2.length() > 0.5:
			continue
		var jx := (e1 * d2.y - e2 * d1.y) / det
		var jy := (e2 * d1.x - e1 * d2.x) / det
		out.right += jx.normalized() * area
		out.up += jy.normalized() * area
		if jx.cross(jy).dot(n) < 0.0:
			mir += area
	if out.count > 0:
		out.centre /= out.area
		out.normal = (out.normal as Vector3).normalized()
		out.right = (out.right as Vector3).normalized()
		out.up = (out.up as Vector3).normalized()
		out.mirrored = mir / out.area
	return out


## The footprint of the look's tattoo `i` as the shader would draw it (its row among the visible ones).
func _fp_of(lk: Dictionary, i: int) -> Dictionary:
	for row: Dictionary in Tattoos.shader_rows(lk):
		if int(row.index) == i:
			return _footprint(row)
	return {"count": 0, "area": 0.0, "regions": {}}


func _one(design: String, place: String) -> Dictionary:
	var lk := {"sex": 1.0, "tattoos": []}
	Tattoos.add(lk, design, place)
	return lk


func _test_twin() -> void:
	var mp: Dictionary = Tattoos.map().get("places", {})
	for pid: String in PLACES:
		var pl := Tattoos.place(pid)
		var lk := _one("anchor", pid)
		var fp := _fp_of(lk, 0)
		var pos: Array = (mp.get(pid, {}) as Dictionary).get("pos", [0, 0, 0])
		var at := Vector3(pos[0], pos[1], pos[2])
		var size := float(pl.get("size", 0.05))
		print("  %-12s %5d points %.1f cm2 at %s (%.1f cm off) up %s right %s regions %s" % [pid, fp.count, fp.area * 1e4,
				fp.get("centre", Vector3.ZERO), (fp.get("centre", Vector3.ZERO) as Vector3).distance_to(at) * 100.0,
				fp.get("up", Vector3.ZERO), fp.get("right", Vector3.ZERO), fp.regions])
		_check(int(fp.count) >= 60, "%s: the anchor inks the skin (%d points)" % [pid, fp.count])
		if int(fp.count) == 0:
			continue
		var regs: Array = pl.get("regions", [])
		_check((fp.regions as Dictionary).keys().all(func(r: String) -> bool: return r in regs), "%s: only on the place's regions %s" % [pid, fp.regions])
		_check((fp.centre as Vector3).distance_to(at) < 0.25 * size + 0.006, "%s: at the place's centre (%.1f cm off)" % [pid,
				(fp.centre as Vector3).distance_to(at) * 100.0])
		_check(float(fp.mirrored) < 0.02, "%s: reads the right way round (%.0f%% mirrored)" % [pid, float(fp.mirrored) * 100.0])
		_check((fp.up as Vector3).y > 0.55, "%s: its top up (%s)" % [pid, fp.up])
		_check((fp.right as Vector3).dot((fp.up as Vector3).cross(fp.normal)) > 0.8, "%s: its right to the viewer's right" % pid)
		if pid.ends_with("_l"):
			_check((fp.centre as Vector3).x > 0.0, "%s: on the left (+x)" % pid)
		elif pid.ends_with("_r"):
			_check((fp.centre as Vector3).x < 0.0, "%s: on the right (-x)" % pid)
		if pid.begins_with("hand"):
			var sn: Array = pl.get("side_normal", [0, 0, 0])
			var out_n := Vector3(sn[0], sn[1], sn[2]).normalized()
			var palm := (fp.normals as Array).filter(func(n: Vector3) -> bool: return n.dot(out_n) < 0.0).size()
			_check(palm == 0, "%s: on the back of the hand, the palm bare (%d palm triangles)" % [pid, palm])
		if pid in ["cheek", "brow"]:
			var inner := (fp.normals as Array).filter(func(n: Vector3) -> bool: return n.z < 0.1).size()
			_check(inner == 0, "%s: on the face's outer skin (%d triangles facing in or back)" % [pid, inner])
	# moves, a turn and a size step, as seen
	for pid: String in ["forearm_l", "chest", "back", "hand_r", "cheek"]:
		var lk := _one("anchor", pid)
		var base := _fp_of(lk, 0)
		var step := 0.006 if pid in ["hand_r", "cheek"] else 0.01
		Tattoos.move(lk, 0, step, 0.0)
		var fr := _fp_of(lk, 0)
		var dr := ((fr.centre as Vector3) - (base.centre as Vector3)).dot(base.right)
		_check(absf(dr - step) < 0.4 * step, "%s: a move right is %.1f cm to the viewer's right (%.2f cm)" % [pid, step * 100.0, dr * 100.0])
		Tattoos.move(lk, 0, -step, step)
		var fu := _fp_of(lk, 0)
		var du := ((fu.centre as Vector3) - (base.centre as Vector3)).dot(base.up)
		_check(absf(du - step) < 0.4 * step, "%s: a move up is %.1f cm up (%.2f cm)" % [pid, step * 100.0, du * 100.0])
		Tattoos.move(lk, 0, 0.0, -step)
		Tattoos.turn(lk, 0, 90.0)
		var ft := _fp_of(lk, 0)
		_check((ft.up as Vector3).dot(base.right) < -0.8, "%s: a quarter turn anticlockwise points its top to the viewer's left" % pid)
		Tattoos.turn(lk, 0, -90.0)
		Tattoos.resize(lk, 0, Tattoos.SCALE_STEP * Tattoos.SCALE_STEP)
		var fs := _fp_of(lk, 0)
		var k := float(fs.area) / maxf(float(base.area), 1e-9)
		var want := pow(Tattoos.SCALE_STEP, 4.0)
		_check(absf(k - want) < 0.3 * want, "%s: two size steps grow it %.2f times (%.2f)" % [pid, want, k])
	# every design whole at its own place: the ink drawn on the skin is the ink of its square (a design cut by the edge
	# of its place's skin, or by the palm, would lose some)
	var cut := []
	for d: Dictionary in Tattoos.designs():
		var id := String(d.id)
		if Tattoos.is_repeat(id):
			continue
		var place := Tattoos.default_place(id)
		var fp := _fp_of(_one(id, place), 0)
		var size := float(Tattoos.place(place).size) * float(d.get("size", 1.0))
		var want := _cell_ink(_atlas, int(d.cell)) * size * size
		var k := float(fp.ink) / maxf(want, 1e-9)
		print("  %-15s at %-12s %.0f%% of its ink drawn" % [id, place, k * 100.0])
		if k < 0.9 or k > 1.25:
			cut.append("%s at %s: %.0f%%" % [id, place, k * 100.0])
	_check(cut.is_empty(), "every design is drawn whole at its own place %s" % [cut])
	# a band goes all round the limb, a ring of dots too; at the neck as well
	for c: Array in [["band", "forearm_l"], ["dots", "upper_arm_r"], ["band_double", "neck"]]:
		var fp := _fp_of(_one(String(c[0]), String(c[1])), 0)
		var least := 1.0
		for n: Vector3 in fp.get("normals", []):
			least = minf(least, n.dot((fp.normals as Array)[0]))
		_check(int(fp.count) > 100 and least < -0.8, "%s at %s goes all round (%d points, normals down to %.2f)" % [c[0], c[1], fp.count, least])


# --- the look -------------------------------------------------------------------------------------

func _test_look() -> void:
	var lk := _look("english", 1)
	lk["tattoos"] = []
	_check(Tattoos.add(lk, "anchor", "forearm_l") == 0, "add an anchor on the left forearm")
	_check(Tattoos.add(lk, "compass_rose", "chest") == 1, "add a compass rose on the chest")
	var a := Tattoos.list(lk)
	_check(a.size() == 2 and a[0].design == "anchor" and a[0].place == "forearm_l" and a[1].design == "compass_rose" and a[1].place == "chest",
			"the look keeps both (%s)" % [a])
	_check(a[0].ink == "blue_black" and is_equal_approx(float(a[0].scale), 1.0) and float(a[0].fade) > 0.0, "new tattoos: blue-black ink, size 1, a little faded")
	_check(Tattoos.summary(lk) == "Compass rose, chest and 1 more", "the row's summary (%s)" % Tattoos.summary(lk))
	# edits
	Tattoos.set_ink(lk, 0, "red")
	Tattoos.set_fade(lk, 0, 0.8)
	Tattoos.move(lk, 0, 0.01, -0.02)
	Tattoos.resize(lk, 0, 1.3)
	Tattoos.turn(lk, 0, 30.0)
	_check(a[0].ink == "red" and is_equal_approx(float(a[0].fade), 0.8) and is_equal_approx(float(a[0].x), 0.01)
			and is_equal_approx(float(a[0].y), -0.02) and is_equal_approx(float(a[0].scale), 1.3) and is_equal_approx(float(a[0].rotation), 30.0),
			"ink, fade, move, size and turn edit it (%s)" % [a[0]])
	Tattoos.set_ink(lk, 0, "purple")
	Tattoos.set_fade(lk, 0, 3.0)
	Tattoos.move(lk, 0, 5.0, -5.0)
	Tattoos.resize(lk, 0, 100.0)
	var reach: Array = Tattoos.place("forearm_l").reach
	_check(a[0].ink == "red" and is_equal_approx(float(a[0].fade), 1.0) and is_equal_approx(float(a[0].x), float(reach[0]))
			and is_equal_approx(float(a[0].y), -float(reach[1])) and is_equal_approx(float(a[0].scale), float(Tattoos.SCALE_RANGE[1])),
			"an unknown ink is refused; fade, move and size are clamped to the place (%s)" % [a[0]])
	Tattoos.turn(lk, 0, 170.0)
	_check(float(a[0].rotation) >= -180.0 and float(a[0].rotation) <= 180.0, "the turn wraps (%s)" % a[0].rotation)
	# the steps the editor's rows use
	Tattoos.step_design(lk, 1, 1)
	_check(a[1].design == "heart" and a[1].place == "chest", "the next design keeps its place (%s at %s)" % [a[1].design, a[1].place])
	Tattoos.step_place(lk, 1, 1)
	_check(a[1].place == "back", "the next place (%s)" % a[1].place)
	Tattoos.step_ink(lk, 1, -1)
	_check(a[1].ink == "green_faded", "the ink steps back round (%s)" % a[1].ink)
	# a ring-only design goes round a limb
	Tattoos.set_design(lk, 1, "band")
	_check(a[1].place in Tattoos.design_places("band") and a[1].place != "back", "a band moves from the back to a limb (%s)" % a[1].place)
	_check(not "chest" in Tattoos.design_places("dots") and "forearm_r" in Tattoos.design_places("dots"), "dots only round a limb or the neck")
	Tattoos.turn(lk, 1, 45.0)
	_check(is_equal_approx(float(a[1].rotation), 0.0), "a band does not turn")
	_check(Tattoos.add(lk, "unicorn") == -1 and a.size() == 2, "an unknown design is refused")
	# the list's limit
	while Tattoos.add(lk, "dots", "forearm_r") >= 0:
		pass
	_check(a.size() == Tattoos.max_count(), "at most %d tattoos (%d)" % [Tattoos.max_count(), a.size()])
	_check(Tattoos.remove(lk, 1) and a.size() == Tattoos.max_count() - 1 and a[0].design == "anchor", "remove one")
	_check(not Tattoos.remove(lk, 99), "remove out of range does nothing")
	# everyone: every design offered to every people and body type
	var all := true
	for p: Dictionary in CharacterPeoples.peoples():
		for bt in [1, 2]:
			var opts := CreatorOptions.options(Tattoos.ROW, _look(String(p.id), bt))
			if opts.size() != Tattoos.designs().size() + 1:
				all = false
	_check(all, "every people and both body types are offered every design")


# --- save / load ----------------------------------------------------------------------------------

func _test_store() -> void:
	var lk := _two(_look("west_african", 2))
	Tattoos.set_ink(lk, 1, "red")
	Tattoos.set_fade(lk, 1, 0.6)
	Tattoos.move(lk, 1, -0.02, 0.015)
	Tattoos.resize(lk, 1, 0.8)
	Tattoos.turn(lk, 1, -15.0)
	var path := "user://appearance_test/tattoos.json"
	_check(AppearanceStore.save_file(path, AppearanceStore.validate(lk)), "save a look with two tattoos")
	var back := AppearanceStore.load_file(path)
	var a := Tattoos.list(lk)
	var b := Tattoos.list(back)
	var same := b.size() == 2
	if same:
		for i in 2:
			for k: String in ["design", "place", "ink"]:
				same = same and String(a[i][k]) == String(b[i][k])
			for k: String in ["x", "y", "scale", "rotation", "fade"]:
				same = same and absf(float(a[i][k]) - float(b[i][k])) < 1e-6
	_check(same, "both tattoos survive save and load with every field (%s)" % [b])
	_check(CreatorOptions.current(Tattoos.ROW, back) == CreatorOptions.current(Tattoos.ROW, lk), "the row finds them after loading")
	var ma := BodyMaterials.skin_material(lk)
	var mb := BodyMaterials.skin_material(back)
	_check(int(mb.get_shader_parameter("tat_count")) == 2 and str(mb.get_shader_parameter("tat_m")) == str(ma.get_shader_parameter("tat_m"))
			and str(mb.get_shader_parameter("tat_ink")) == str(ma.get_shader_parameter("tat_ink")), "the loaded look draws the same")
	# broken entries: dropped (not a dictionary, an unknown design, a ring at a place it may not go) or clamped
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": AppearanceStore.FORMAT, "version": 2, "look": {"tattoos": [
			"anchor", {"design": "dragon", "place": "back"}, {"design": "dots", "place": "chest"},
			{"design": "ship", "place": "nowhere", "x": 9, "y": "high", "scale": 40, "rotation": 400, "ink": "gold", "fade": -2},
			{"design": "heart", "place": "hand_r", "ink": "green_faded", "fade": 0.4}]}}))
	f.close()
	var v := Tattoos.list(AppearanceStore.load_file(path))
	_check(v.size() == 3 and v[0].design == "dots" and v[0].place in Tattoos.design_places("dots"), "a ring at the chest goes round a limb (%s)" % [v])
	if v.size() == 3:
		var r: Array = Tattoos.place(String(v[1].place)).reach
		_check(v[1].design == "ship" and v[1].place == Tattoos.default_place("ship") and is_equal_approx(float(v[1].x), float(r[0]))
				and is_equal_approx(float(v[1].y), 0.0) and is_equal_approx(float(v[1].scale), float(Tattoos.SCALE_RANGE[1]))
				and absf(float(v[1].rotation) - 40.0) < 1e-4 and v[1].ink == "blue_black" and is_equal_approx(float(v[1].fade), 0.0),
				"broken numbers and ids fall back or are clamped (%s)" % [v[1]])
		_check(v[2].design == "heart" and v[2].place == "hand_r" and v[2].ink == "green_faded", "a good entry is kept (%s)" % [v[2]])
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": AppearanceStore.FORMAT, "version": 2, "look": {"tattoos": "anchor"}}))
	f.close()
	_check(Tattoos.list(AppearanceStore.load_file(path)).is_empty(), "a broken list loads as none")
	var many := []
	for i in 20:
		many.append({"design": "dots", "place": "forearm_l"})
	_check(Tattoos.validate(many).size() == Tattoos.max_count(), "a long list is cut to %d" % Tattoos.max_count())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- kept across people, body type and the dice -----------------------------------------------------

func _test_kept() -> void:
	var lk := _two(_look("english", 1))
	var want := str(Tattoos.list(lk))
	var p := CreatorOptions.with_people(lk, "japanese")
	_check(str(Tattoos.list(p)) == want, "a change of people keeps them")
	var b := CreatorOptions.with_body_type(p, 2)
	_check(str(Tattoos.list(b)) == want, "a change of body type keeps them")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var r := CreatorOptions.randomized(b, rng)
	_check(str(Tattoos.list(r)) == want, "the dice keep them")
	Tattoos.list(r)[0]["ink"] = "red"
	_check(str(Tattoos.list(lk)) == want, "the copies do not share the list")
	_check(Tattoos.list(_look("english", 1)).is_empty() and Tattoos.list(AppearanceStore.default_look()).is_empty(), "a new character has none")


# --- the shader -------------------------------------------------------------------------------------

func _test_shader() -> void:
	var sh := load("res://assets/character/shaders/skin.gdshader") as Shader
	var names := sh.get_shader_uniform_list().map(func(u: Dictionary) -> String: return String(u.name))
	var need := ["tat_count", "tat_m", "tat_b", "tat_p", "tat_s", "tat_ink", "tat_e", "tattoo_atlas", "tattoo_arc"]
	_check(need.all(func(n: String) -> bool: return n in names), "skin.gdshader has the tattoo uniforms")
	var lk := _two(_look("english", 1))
	lk["outfit"] = {"shirt": {"id": "-"}}
	PlayerAppearance.dress(_body, lk)
	var m := _skin_of(_body)
	_check(m != null and int(m.get_shader_parameter("tat_count")) == 2, "the dressed body's skin carries both tattoos (%s)" % [m.get_shader_parameter("tat_count") if m else null])
	if m == null:
		return
	var s: PackedVector4Array = m.get_shader_parameter("tat_s")
	var p: PackedVector4Array = m.get_shader_parameter("tat_p")
	var ink: PackedVector4Array = m.get_shader_parameter("tat_ink")
	var ids := BodyMaterials.region_ids()
	_check(s.size() == Tattoos.SHADER_MAX and int(s[0].x) == int(Tattoos.design("anchor").cell) and int(s[1].x) == int(Tattoos.design("compass_rose").cell),
			"the atlas cells: the anchor's, the compass rose's")
	_check(int(p[0].x) == 0 and ((int(p[0].z) >> int(ids.forearm_a_l)) & 1) == 1 and ((int(p[0].w) >> (int(ids.forearm_b_l) - 16)) & 1) == 1
			and ((int(p[0].w) >> (int(ids.forearm_b_r) - 16)) & 1) == 0, "the anchor on the left forearm's skin (metre UVs), not the right's")
	var ch := int(ids.chest_front)
	_check(int(p[1].x) == 1 and ((int(p[1].z) >> ch) & 1) == 1, "the compass rose on the chest (the torso's arc map)")
	var bb: Array = Tattoos.ink("blue_black").color
	_check(ink[0].x < 0.4 and ink[0].z > ink[0].x and ink[0].w > 0.6 and absf(ink[0].x - float(bb[0])) < 0.2, "blue-black ink, dense when fresh (%s)" % ink[0])
	_check(m.get_shader_parameter("tattoo_atlas") is Texture2D and m.get_shader_parameter("tattoo_arc") is Texture2D, "the atlas and the arc map are set")
	_check((m.get_shader_parameter("tattoo_atlas") as Texture2D).get_width() == 1024
			and FileAccess.get_file_as_string(Tattoos.ATLAS + ".import").contains("mipmaps/generate=true"), "the atlas has its mip levels (the ink's spread)")
	# red and old: a redder, paler, thinner ink
	Tattoos.set_ink(lk, 0, "red")
	Tattoos.set_fade(lk, 0, 1.0)
	PlayerAppearance.dress(_body, lk)
	var ink2: PackedVector4Array = _skin_of(_body).get_shader_parameter("tat_ink")
	var e2: PackedVector4Array = _skin_of(_body).get_shader_parameter("tat_e")
	_check(ink2[0].x > ink2[0].z and ink2[0].w < ink[0].w, "red ink, thinner when old (%s)" % ink2[0])
	_check(e2[0].x > 0.5, "an old tattoo's ink spreads (blur level %.2f)" % e2[0].x)
	lk["tattoos"] = []
	PlayerAppearance.dress(_body, lk)
	_check(int(_skin_of(_body).get_shader_parameter("tat_count")) == 0, "no tattoos: none drawn")


# --- clothes --------------------------------------------------------------------------------------

func _test_clothes() -> void:
	var lk := _two(_look("english", 1))
	# bare above the waist: both drawn
	lk["outfit"] = {"shirt": {"id": "-"}}
	var fit := PlayerAppearance.dress(_body, lk)
	var dl := PlayerAppearance.dressed_look(lk, fit)
	_check(int(_skin_of(_body).get_shader_parameter("tat_count")) == 2, "bare: both drawn")
	_check(int(_fp_of(dl, 0).count) > 60 and int(_fp_of(dl, 1).count) > 60, "bare: both ink the skin")
	# the man's shirt: its sleeves over the forearms, its body over the chest
	lk["outfit"] = {"shirt": {"id": SHIRT}}
	fit = PlayerAppearance.dress(_body, lk)
	dl = PlayerAppearance.dressed_look(lk, fit)
	var cloth: Array = PlayerOutfit.entry(SHIRT).get("occupies_regions", [])
	var hidden: Array = fit.get("hide_regions", [])
	var m := _skin_of(_body)
	for i in 2:
		var t: Dictionary = Tattoos.list(lk)[i]
		var fp := _fp_of(dl, i)
		var showing := (fp.regions as Dictionary).keys().filter(func(r: String) -> bool: return not r in cloth)
		print("  under %s: %s at %s inks %d points on skin that is drawn %s" % [SHIRT, t.design, t.place, fp.count, fp.regions])
		_check(showing.is_empty(), "under a shirt the %s at %s draws nothing that shows (%s)" % [t.design, t.place, fp.regions])
		_check((fp.regions as Dictionary).keys().all(func(r: String) -> bool: return not r in hidden), "the %s's bits skip the hidden skin" % t.design)
	# the shader is told only the place's regions that show
	var rows := Tattoos.shader_rows(dl)
	_check(int(m.get_shader_parameter("tat_count")) == rows.size(), "the material draws the visible rows (%d)" % rows.size())
	# a woman's shift, its sleeves to the elbow: the forearm's anchor shows below it
	var w := _two(_look("english", 2))
	w["outfit"] = {}
	fit = PlayerAppearance.dress(_body, w)
	var wd := PlayerAppearance.dressed_look(w, fit)
	var wcloth: Array = PlayerOutfit.entry("shift_linen").get("occupies_regions", [])
	var fp := _fp_of(wd, 0)
	var bare := (fp.regions as Dictionary).keys().filter(func(r: String) -> bool: return not r in wcloth)
	_check(not bare.is_empty() and int(fp.count) > 60, "a woman's shift to the elbow leaves the forearm's anchor showing (%s)" % [fp.regions])
	var fc := _fp_of(wd, 1)
	_check((fc.regions as Dictionary).keys().all(func(r: String) -> bool: return r in wcloth), "her chest's compass is under the shift (%s)" % [fc.regions])
	# gloves over the hands: a hand tattoo is not sent at all
	var g := {"sex": 1.0, "tattoos": [], "hide_regions": ["hand_l"]}
	Tattoos.add(g, "heart", "hand_l")
	Tattoos.add(g, "heart", "hand_r")
	var gr := Tattoos.shader_rows(g)
	_check(gr.size() == 1 and int(gr[0].index) == 1, "a gloved hand's tattoo is not sent, the bare hand's is")


# --- the creator ----------------------------------------------------------------------------------

func _find(n: Node, name_part: String) -> Node:
	for c in n.find_children("*", "", true, false):
		if String(c.name) == name_part:
			return c
	return null


func _press(panel: Node, path: String) -> bool:
	var b := panel.get_node_or_null(path)
	if b == null:
		b = _find(panel, path)
	if b is Button:
		(b as Button).pressed.emit()
		return true
	print("    no button ", path)
	return false


func _test_ui() -> void:
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var c := CharacterCreator.open(null)
	await _frames(8)
	if not is_instance_valid(c):
		_check(false, "the creator opens")
		return
	var lk := _look("english", 1)
	lk["tattoos"] = []
	c.look = lk
	c._refresh_all()
	await _frames(3)
	var ui: Dictionary = c._row_ui.get(Tattoos.ROW, {})
	_check(not ui.is_empty() and (ui.title as Label).text == "Tattoos", "the creator's Tattoos row")
	if ui.is_empty():
		c.close(false)
		return
	_check((ui.value as Label).text == "None" and (ui.count as Label).text == "0/%d" % Tattoos.max_count(), "the row: None, 0/%d" % Tattoos.max_count())
	c._set_focus(Tattoos.ROW)
	await _frames(3)
	_check(c.stage.frame_name == "bust", "the row frames the bust")
	c._step(Tattoos.ROW, 1)
	await _frames(2)
	_check(Tattoos.list(c.look).size() == 1 and Tattoos.list(c.look)[0].design == "anchor" and (ui.value as Label).text == "Anchor, left forearm",
			"stepping the row adds an anchor on the left forearm (%s)" % (ui.value as Label).text)
	_check("forearm_b_l" in c.stage.reveal, "the stage shows the forearm's skin through the sleeve")
	var sm := _skin_of(c.stage.body)
	_check(sm != null and int(sm.get_shader_parameter("tat_count")) == 1, "the stage figure's skin draws it")
	c._step(Tattoos.ROW, 1)
	_check(Tattoos.list(c.look).size() == 1 and Tattoos.list(c.look)[0].design == "compass_rose", "the next step changes its design")
	c._step(Tattoos.ROW, -1)
	c._step(Tattoos.ROW, -1)
	_check(Tattoos.list(c.look).is_empty() and (ui.value as Label).text == "None", "stepping back to None takes it off")
	# the editor: a click on the row's value
	c._open_picker(Tattoos.ROW)
	await _frames(3)
	var p: TattooPanel = c._tattoos
	_check(is_instance_valid(p) and p.is_inside_tree() and p.visible, "a click on the row opens the tattoo editor")
	if not is_instance_valid(p):
		c.close(false)
		return
	_check(not c._left_panel.visible, "the editor stands where the people panel was")
	_press(p, "Add")
	await _frames(2)
	# the close view: the camera on the chosen tattoo's skin (the left forearm), the figure turned to show it
	var sk := c.stage.skeleton
	var elbow := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("l_elbow")).origin
	var wrist := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("l_wrist")).origin
	var fpt: Vector3 = c.stage.focus_point()
	_check(fpt.distance_to(elbow.lerp(wrist, 0.5)) < 0.1, "the editor's camera looks at the left forearm (%.2f m off)" % fpt.distance_to(elbow.lerp(wrist, 0.5)))
	_check(is_equal_approx(float(c.stage._goal()[1]), float(Tattoos.place("forearm_l").view.dist)), "from close by")
	_press(p, "Add")
	await _frames(2)
	var a := Tattoos.list(c.look)
	_check(a.size() == 2 and p.selected == 1 and a[0].design == "anchor" and a[1].design == "compass_rose", "Add, Add: two tattoos (%s)" % [a])
	_check((_find(p, "Editor") as Control).visible, "the chosen tattoo's rows show")
	_check(c.stage.bare_top, "a chest tattoo takes the stage's shirt off")
	_press(_find(p, "Row_Design"), "Next")
	_check(a[1].design == "heart", "Design > : the next design (%s)" % a[1].design)
	_press(_find(p, "Row_Place"), "Next")
	_check(a[1].place == "back", "Place > : the next place (%s)" % a[1].place)
	_check(cos(float(c.stage._yaw_target) - PI) > 0.95 and not c.stage._focus.is_empty(), "the stage turns the figure's back to the camera (yaw %.2f)" % c.stage._yaw_target)
	_press(_find(p, "Row_Ink"), "Next")
	_check(a[1].ink == "red", "Ink > : red (%s)" % a[1].ink)
	(_find(p, "Fade") as HSlider).value = 0.7
	_check(is_equal_approx(float(a[1].fade), 0.7), "the Fade slider ages it (%s)" % a[1].fade)
	_press(p, "Move_Up")
	_press(p, "Move_Right")
	_check(is_equal_approx(float(a[1].y), Tattoos.MOVE_STEP) and is_equal_approx(float(a[1].x), Tattoos.MOVE_STEP), "Move up, right")
	_press(p, "Move_Centre")
	_check(is_zero_approx(float(a[1].x)) and is_zero_approx(float(a[1].y)), "Move: back to the centre")
	_press(p, "Size_Larger")
	_check(is_equal_approx(float(a[1].scale), Tattoos.SCALE_STEP), "Size: larger")
	_press(p, "Turn_Left")
	_check(is_equal_approx(float(a[1].rotation), Tattoos.TURN_STEP), "Turn: left (anticlockwise)")
	_check((ui.value as Label).text == "Heart, back and 1 more" and (ui.count as Label).text == "2/%d" % Tattoos.max_count(),
			"the row follows the editor (%s)" % (ui.value as Label).text)
	sm = _skin_of(c.stage.body)
	_check(sm != null and int(sm.get_shader_parameter("tat_count")) == 2, "the stage draws both")
	_press(p, "Tattoo_0")
	_check(p.selected == 0 and p.selected_place() == "forearm_l", "a tattoo's button chooses it")
	_press(p, "Remove")
	a = Tattoos.list(c.look)
	_check(a.size() == 1 and a[0].design == "heart", "Remove takes the chosen one off")
	_press(p, "Done")
	await _frames(3)
	_check(not is_instance_valid(c._tattoos) and c._left_panel.visible, "Done closes the editor")
	c._set_focus("face")
	await _frames(2)
	_check(c.stage.reveal.is_empty() and not c.stage.bare_top, "off the row the stage is dressed as worn")
	c.close(false)
	await _frames(3)


# --- the pictures (shots=DIR, a window) -------------------------------------------------------------

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
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	for l in [[Vector3(-30, 25, 0), 1.1, true], [Vector3(-15, -60, 0), 0.4, false], [Vector3(-25, 160, 0), 0.55, false]]:
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
	_label.add_theme_font_size_override("font_size", 30)
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


## The bone's frame in the world (its basis's axes).
func _bone_basis(f: Array, bone: String) -> Basis:
	var sk: Skeleton3D = f[1]
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone))).basis.orthonormalized()


func _aim(target: Vector3, offset: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.global_position = target + offset
	_cam.look_at(target, Vector3.UP if absf(offset.normalized().y) < 0.95 else Vector3.FORWARD)


func _grab() -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


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


## The mean absolute difference of two pictures (0..1) and the share of pixels that differ by more than `tol`.
func _diff(a: Image, b: Image, tol := 0.04) -> Vector2:
	var s := 0.0
	var n := 0
	var big := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
			s += d
			n += 1
			if d > tol:
				big += 1
	return Vector2(s / maxf(n, 1), float(big) / maxf(n, 1))


## Waits until the creator's camera and the figure's turn have eased in (at most 3 s).
func _settle(st: CreatorStage) -> void:
	for i in 180:
		await process_frame
		if st.settled() and absf(st._yaw - st._yaw_target) < 0.01:
			break
	await _frames(4)


## A man of `pid` with tattoos `list` ([design, place, {edits}]), dressed in `outfit`.
func _sailor(pid: String, bt: int, list: Array, outfit := {"shirt": {"id": "-"}}) -> Dictionary:
	var lk := _look(pid, bt)
	lk["tattoos"] = []
	lk["outfit"] = outfit.duplicate(true)
	for e: Array in list:
		var i := Tattoos.add(lk, String(e[0]), String(e[1]))
		var ed: Dictionary = e[2] if e.size() > 2 else {}
		if ed.has("ink"):
			Tattoos.set_ink(lk, i, String(ed.ink))
		if ed.has("fade"):
			Tattoos.set_fade(lk, i, float(ed.fade))
		if ed.has("move"):
			Tattoos.move(lk, i, float(ed.move[0]), float(ed.move[1]))
		if ed.has("scale"):
			Tattoos.resize(lk, i, float(ed.scale))
		if ed.has("turn"):
			Tattoos.turn(lk, i, float(ed.turn))
	return lk


## The posed position and normal of figure f's skin vertex nearest `at` (the bind pose) as drawn: taken when the
## skeleton's final pose is ready (skeleton_updated: after the helper bones' driver, which moves the forearms' twist
## bones), the part's bone weights times that pose and the skin's binds. [position, normal]
func _posed(f: Array, at: Vector3, nrm: Vector3) -> Array:
	var sk: Skeleton3D = f[1]
	var res := []
	var cb := func() -> void:
		if res.is_empty():
			res.append_array(_skinned(f, at, nrm))
	sk.skeleton_updated.connect(cb)
	for i in 6:
		await process_frame
		if not res.is_empty():
			break
	sk.skeleton_updated.disconnect(cb)
	return res if not res.is_empty() else _skinned(f, at, nrm)


func _skinned(f: Array, at: Vector3, nrm: Vector3) -> Array:
	var sk: Skeleton3D = f[1]
	var body: CharacterBodyMesh = f[2]
	for mi: MeshInstance3D in body.part_meshes("head"):
		var skin := mi.skin
		if skin == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src == null or src.resource_name != "skin":
				continue
			var arr := mi.mesh.surface_get_arrays(s)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var B: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var W: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nb := B.size() / V.size()
			var best := 0
			for i in V.size():
				if V[i].distance_squared_to(at) < V[best].distance_squared_to(at):
					best = i
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			for k in nb:
				var w := W[best * nb + k]
				if w <= 0.0:
					continue
				var bind := B[best * nb + k]
				var bone := skin.get_bind_bone(bind)
				if bone < 0:
					bone = sk.find_bone(skin.get_bind_name(bind))
				var xf := sk.global_transform * sk.get_bone_global_pose(bone) * skin.get_bind_pose(bind)
				p += xf * V[best] * w
				n += xf.basis * nrm * w
			return [p, n.normalized()]
	return [at, nrm]


## The camera on a place of figure `f`: in front of the place's skin (its bind-pose centre and normal, tattoo_map.json,
## as the figure stands), `lift` tilting the view down onto it.
func _aim_place(f: Array, place: String, dist: float, fov: float, lift := 0.0) -> void:
	var mp: Dictionary = (Tattoos.map().places as Dictionary).get(place, {})
	var pos: Array = mp.get("pos", [0, 1, 0])
	var nrm: Array = mp.get("normal", [0, 0, 1])
	var pn: Array = await _posed(f, Vector3(pos[0], pos[1], pos[2]), Vector3(nrm[0], nrm[1], nrm[2]))
	var n := ((pn[1] as Vector3) + Vector3(0, lift, 0)).normalized()
	_aim(pn[0], n * dist, fov)


func _pictures() -> void:
	_studio()
	var f := _figure(0.0)
	var body: CharacterBodyMesh = f[2]
	await _frames(4)
	# 1. the forearm's anchor (a sailor's commonest mark), with and without
	var lk := _sailor("english", 1, [["anchor", "forearm_l"]])
	PlayerAppearance.dress(body, lk)
	await _aim_place(f, "forearm_l", 0.42, 30.0, 0.15)
	_label.text = "Anchor, left forearm (blue-black)"
	var with := await _grab()
	with.save_png("%s/forearm_anchor.png" % _shots)
	lk["tattoos"] = []
	PlayerAppearance.dress(body, lk)
	_label.text = "Anchor, left forearm (blue-black)"
	var without := await _grab()
	var df := _diff(with, without)
	print("  forearm: %.4f mean difference, %.2f%% of pixels" % [df.x, df.y * 100.0])
	_check(df.y > 0.004, "rendered: the anchor shows on the bare forearm (%.2f%% of pixels)" % (df.y * 100.0))
	# 2. under a shirt's sleeve: the same picture with and without the anchor
	lk = _sailor("english", 1, [["anchor", "forearm_l"]], {"shirt": {"id": SHIRT}})
	PlayerAppearance.dress(body, lk)
	var sleeve := await _grab()
	lk["tattoos"] = []
	PlayerAppearance.dress(body, lk)
	var sleeve0 := await _grab()
	var ds := _diff(sleeve, sleeve0, 0.02)
	print("  sleeve: %.5f mean difference, %.3f%% of pixels" % [ds.x, ds.y * 100.0])
	_check(ds.y < 0.0005, "rendered: under the shirt's sleeve the anchor does not show (%.3f%% of pixels)" % (ds.y * 100.0))
	_label.text = "Bare  /  under a shirt sleeve (hidden)"
	await _sheet("sleeve", [with, sleeve], 2, 640)
	# 3. the chest's compass rose
	lk = _sailor("english", 1, [["compass_rose", "chest"]])
	PlayerAppearance.dress(body, lk)
	await _aim_place(f, "chest", 0.62, 30.0, 0.05)
	_label.text = "Compass rose, chest"
	var chest := await _grab()
	chest.save_png("%s/chest_compass.png" % _shots)
	lk["tattoos"] = []
	PlayerAppearance.dress(body, lk)
	_check(_diff(chest, await _grab()).y > 0.004, "rendered: the compass rose shows on the bare chest")
	# 4. a sailor's hand: initials on the back of the hand, a ring of dots at the wrist, an anchor up the forearm
	lk = _sailor("english", 1, [["heart", "hand_l"], ["dots", "forearm_l", {"move": [0.0, -0.1]}],
			["anchor", "forearm_l", {"move": [0.0, 0.02], "fade": 0.5}], ["initials_date", "upper_arm_l"]])
	PlayerAppearance.dress(body, lk)
	await _aim_place(f, "hand_l", 0.4, 30.0, 0.25)
	_label.text = "A sailor's hand: heart, dots at the wrist, anchor"
	(await _grab()).save_png("%s/sailor_hand.png" % _shots)
	# 5. every design (on the forearm, the chest or round the arm), a lineup
	var shots := []
	for d: Dictionary in Tattoos.designs():
		var id := String(d.id)
		var place := "chest" if id in ["compass_rose", "ship", "mermaid", "drift_waves", "keelstone_star"] else Tattoos.default_place(id)
		lk = _sailor("english", 1, [[id, place]])
		PlayerAppearance.dress(body, lk)
		await _aim_place(f, place, 0.5 if place == "chest" else 0.36, 30.0, 0.1)
		_label.text = "%s (%s)" % [d.label, Tattoos.place(place).label]
		shots.append(await _grab())
	await _sheet("designs", shots, 4, 400)
	# 6. every place
	shots = []
	var at := {"forearm_l": "anchor", "forearm_r": "crossed_keys", "upper_arm_l": "heart", "upper_arm_r": "mermaid", "chest": "ship",
			"back": "keelstone_star", "hand_l": "crucifix", "hand_r": "initials_date", "neck": "band", "cheek": "wind_spiral",
			"brow": "dots"}
	for place: String in PLACES:
		var id := String(at.get(place, "anchor"))
		if not place in Tattoos.design_places(id):
			id = "anchor"
		lk = _sailor("english", 1, [[id, place]])
		PlayerAppearance.dress(body, lk)
		var dist: float = {"chest": 0.62, "back": 0.7, "neck": 0.38, "cheek": 0.32, "brow": 0.34, "hand_l": 0.36, "hand_r": 0.36}.get(place, 0.42)
		await _aim_place(f, place, float(dist), 30.0, 0.1)
		_label.text = "%s: %s" % [Tattoos.place(place).label, Tattoos.design(id).label]
		shots.append(await _grab())
	await _sheet("places", shots, 4, 400)
	# 7. the inks, fresh and old, on three skins
	shots = []
	for pid: String in ["english", "south_asian", "west_african"]:
		for e: Array in [["blue_black", 0.0], ["blue_black", 1.0], ["red", 0.2], ["green_faded", 0.6]]:
			lk = _sailor(pid, 1, [["anchor", "forearm_l", {"ink": e[0], "fade": e[1]}]])
			PlayerAppearance.dress(body, lk)
			await _aim_place(f, "forearm_l", 0.36, 30.0, 0.15)
			_label.text = "%s, fade %.1f (%s)" % [Tattoos.ink(String(e[0])).label, e[1], pid]
			shots.append(await _grab())
	await _sheet("inks_fade", shots, 4, 400)
	(f[0] as Node).queue_free()
	_world.queue_free()
	await _frames(3)
	# 8. the creator's row and its editor
	var c := CharacterCreator.open(null)
	await _frames(8)
	c.look = _sailor("english", 1, [["anchor", "forearm_l"], ["compass_rose", "chest"]], {})
	c._refresh_all()
	c._set_focus(Tattoos.ROW)
	await _frames(6)
	(await _grab()).save_png("%s/creator_row.png" % _shots)
	c._open_picker(Tattoos.ROW)
	await _frames(4)
	c._tattoos.select(0)
	await _settle(c.stage)
	(await _grab()).save_png("%s/creator_editor.png" % _shots)
	c._tattoos.select(1)
	await _settle(c.stage)
	(await _grab()).save_png("%s/creator_editor_chest.png" % _shots)
	print("shot creator_row, creator_editor")
	c.close(false)
	await _frames(3)
