extends SceneTree
## Builds the tattoos' assets (Tattoos, tattoo.gdshaderinc):
##   assets/character/tattoos/tattoo_atlas.png   the designs (tools/character/tattoos/designs/<id>.svg, rasterized by
##                                               Godot's SVG loader) in a 4 x 4 grid of 256 px cells: ink coverage (L8);
##                                               a figure that reaches into its box's MARGIN is drawn smaller to fit
##   assets/character/tattoos/tattoo_map.json    measured on body.glb's skin: the torso's arc map and each place's frame
##
##   python3 tools/character/tattoos/make_designs.py
##   Godot --headless --path . -s tools/character/tattoos/build_tattoos.gd [-- atlas | map]
##   Godot --headless --path . --import            # (a new atlas: the import settings are in its .import file)
##
## The arc map. The torso's metre UVs (lib/uv.py) are a cylinder (radius 0.13 m) about a vertical axis well in front of
## the spine: on the chest the surface lies about 5 cm from that axis, so u runs two to three times faster than the
## skin and a design drawn in u came out pinched at the sternum. The map holds, on a grid over (u, height), the true arc
## length along the body's horizontal ring at that height: R from the front centre, G from the back centre (each
## continuous across its own side; the back one across the UV seam). Chest and back tattoos use (arc, height).
##
## A place. Its centre (data/customizer/tattoos.json "anchor": metre UV, or "anchor_face": face coordinates, nearest
## skin vertex) in the place's coordinates, and the 2 x 2 matrix `a` that turns a step in those coordinates into the
## design's plane in metres: right and up as a viewer facing that skin sees them (up: the world's up, or along the
## limb toward the shoulder, or the hand toward the wrist). Measured by a least-squares fit of the bind-pose positions
## of the skin vertices about the centre. `side` (hands): the sign of the UV frame's handedness on the back of the hand;
## the palm, with the same planar UVs, has the other sign and draws nothing.

const DATA := "res://data/customizer/tattoos.json"
const DESIGNS := "res://tools/character/tattoos/designs/"
const OUT_DIR := "res://assets/character/tattoos/"
const ATLAS := OUT_DIR + "tattoo_atlas.png"
const MAP := OUT_DIR + "tattoo_map.json"
const GRID := 4
const CELL := 256
const SRC := 512
## The empty border kept round each figure in its source box (px of SRC): 22 px of a 256 px cell, of which the
## downsampling's filter spreads the ink 3 px: the outer 16 px (one texel of the 16 px mip level) stay empty.
const MARGIN := 44.0
## The torso's UV cylinder (lib/uv.py body_parts: radius 0.13): its circumference.
const TORSO_R := 0.13
const TORSO_REGIONS := [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
const ARC_NU := 96
const ARC_NV := 41
const ARC_V := [0.93, 1.26]

var _V: PackedVector3Array
var _N: PackedVector3Array
var _UV: PackedVector2Array
var _R: PackedInt32Array
var _I: PackedInt32Array
var _MH := PackedVector2Array()
var _arc := {}


func _initialize() -> void:
	var what := "all"
	for a in OS.get_cmdline_user_args():
		what = a
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not data is Dictionary:
		push_error("build_tattoos: %s does not parse" % DATA)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ok := true
	if what in ["all", "atlas"]:
		ok = _atlas(data) and ok
	if what in ["all", "map"]:
		ok = _map(data) and ok
	quit(0 if ok else 1)


# ---------------------------------------------------------------------------------------------
# Atlas
# ---------------------------------------------------------------------------------------------

func _atlas(data: Dictionary) -> bool:
	var atlas := Image.create(GRID * CELL, GRID * CELL, false, Image.FORMAT_L8)
	atlas.fill(Color(0, 0, 0))
	var n := 0
	for d: Dictionary in data.get("designs", []):
		var path := DESIGNS + String(d.id) + ".svg"
		if not FileAccess.file_exists(path):
			push_error("build_tattoos: no %s" % path)
			return false
		var svg := FileAccess.get_file_as_string(path)
		var img := Image.new()
		if img.load_svg_from_string(svg, 1.0) != OK:
			push_error("build_tattoos: %s does not rasterize" % path)
			return false
		img.convert(Image.FORMAT_RGBA8)
		# the margin: a figure whose ink reaches nearer the box's edge than MARGIN is drawn smaller about the box's centre
		# (the ink's spread samples the atlas down to a 16 px cell, one texel of which is the outer 16 px of a 256 px
		# cell: ink there would bleed into the next design; and the shader cuts the square's edge sharp). A repeating
		# design (a band) spans its width on purpose.
		if not d.has("repeat"):
			var ext := _extent(img)
			var room := SRC * 0.5 - MARGIN
			if ext > room:
				var k := room / ext
				var small := Image.new()
				small.load_svg_from_string(svg, k)
				small.convert(Image.FORMAT_RGBA8)
				img = Image.create(SRC, SRC, false, Image.FORMAT_RGBA8)
				img.fill(Color(0, 0, 0, 0))
				img.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), (Vector2i(SRC, SRC) - small.get_size()) / 2)
				print("  %-15s drawn at %.3f to keep its margin" % [d.id, k])
		# coverage: the ink's whiteness times its alpha (the designs cut black lines into white fills)
		var cov := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_L8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				cov.set_pixel(x, y, Color(c.r * c.a, 0, 0))
		cov.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
		var cell := int(d.cell)
		atlas.blit_rect(cov, Rect2i(0, 0, CELL, CELL), Vector2i((cell % GRID) * CELL, (cell / GRID) * CELL))
		n += 1
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	print("build_tattoos: %d designs -> %s (%s)" % [n, ATLAS, error_string(err)])
	return err == OK


## The ink's farthest reach from the box's centre (px, the larger of x and y) in a rasterized design.
func _extent(img: Image) -> float:
	var c := Vector2(img.get_width(), img.get_height()) * 0.5
	var ext := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.r * p.a > 0.02:
				ext = maxf(ext, maxf(absf(x + 0.5 - c.x), absf(y + 0.5 - c.y)))
	return ext


# ---------------------------------------------------------------------------------------------
# Map
# ---------------------------------------------------------------------------------------------

func _load_body() -> bool:
	var sc := (load(BodyMaterials.BODY_GLB) as PackedScene).instantiate()
	for mi: MeshInstance3D in sc.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null or mat.resource_name != "skin":
				continue
			var a := mi.mesh.surface_get_arrays(s)
			_V = a[Mesh.ARRAY_VERTEX]
			_N = a[Mesh.ARRAY_NORMAL]
			_UV = a[Mesh.ARRAY_TEX_UV]
			_I = a[Mesh.ARRAY_INDEX]
			var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
			_R.resize(_V.size())
			for i in _V.size():
				_R[i] = int(uv2[i].x + 0.5) & 63
			# MakeHuman's UVs (body v4: CUSTOM0, RG float)
			var c0 = a[Mesh.ARRAY_CUSTOM0]
			var fl: PackedFloat32Array = c0.to_float32_array() if c0 is PackedByteArray else c0
			var stride := fl.size() / _V.size()
			_MH.resize(_V.size())
			for i in _V.size():
				_MH[i] = Vector2(fl[i * stride], fl[i * stride + 1])
	sc.free()
	return not _V.is_empty()


## (u, height) of vertex i: the metre UVs (the exporter writes V as 1 - v).
func _raw(i: int) -> Vector2:
	return Vector2(_UV[i].x, 1.0 - _UV[i].y)


func _wrap(u: float, p: float) -> float:
	return u - p * roundf(u / p)


## One ring of the torso at height h: its points (u wrapped, position) sorted by u.
func _ring(h: float) -> Array:
	var p := TAU * TORSO_R
	var out := []
	for t in range(0, _I.size(), 3):
		var ids := [_I[t], _I[t + 1], _I[t + 2]]
		if not _R[ids[0]] in TORSO_REGIONS:
			continue
		for e in 3:
			var i0: int = ids[e]
			var i1: int = ids[(e + 1) % 3]
			var y0 := _raw(i0).y
			var y1 := _raw(i1).y
			if (y0 - h) * (y1 - h) < 0.0:
				var k: float = (h - y0) / (y1 - y0)
				out.append([_wrap(lerpf(_UV[i0].x, _UV[i1].x, k), p), _V[i0].lerp(_V[i1], k)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out


## Arc length along a sorted ring from u = 0 (front centre), signed with u: [[u, s], ...].
func _arc_of(ring: Array) -> Array:
	var i0 := 0
	for i in ring.size():
		if absf(float(ring[i][0])) < absf(float(ring[i0][0])):
			i0 = i
	var s := []
	s.resize(ring.size())
	s[i0] = float(ring[i0][0]) * 0.6        # (the nearest point is a few mm off the centre line)
	for i in range(i0 + 1, ring.size()):
		s[i] = float(s[i - 1]) + (ring[i][1] as Vector3).distance_to(ring[i - 1][1])
	for i in range(i0 - 1, -1, -1):
		s[i] = float(s[i + 1]) - (ring[i][1] as Vector3).distance_to(ring[i + 1][1])
	var out := []
	for i in ring.size():
		out.append([float(ring[i][0]), float(s[i])])
	return out


func _interp(arc: Array, u: float) -> float:
	if arc.is_empty():
		return u
	if u <= float(arc[0][0]):
		return float(arc[0][1]) + (u - float(arc[0][0]))
	for i in range(1, arc.size()):
		if u <= float(arc[i][0]):
			var a: Array = arc[i - 1]
			var b: Array = arc[i]
			var k := (u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-9)
			return lerpf(float(a[1]), float(b[1]), k)
	return float(arc[-1][1]) + (u - float(arc[-1][0]))


func _build_arc() -> void:
	var p := TAU * TORSO_R
	var front := []
	var back := []
	for j in ARC_NV:
		var h := lerpf(ARC_V[0], ARC_V[1], float(j) / float(ARC_NV - 1))
		var arc := _arc_of(_ring(h))
		var s_left := _interp(arc, p * 0.5)        # front centre to back centre round the left side
		var s_right := -_interp(arc, -p * 0.5)     # ... round the right side
		var rf := []
		var rb := []
		for i in ARC_NU:
			var u := -p * 0.5 + (float(i) + 0.5) * p / float(ARC_NU)
			var s := _interp(arc, u)
			rf.append(snappedf(s, 0.0001))
			# from the back centre, growing with u through the seam: left side s - s_left (negative), right s + s_right
			rb.append(snappedf(s - s_left if u >= 0.0 else s + s_right, 0.0001))
		front.append(rf)
		back.append(rb)
	_arc = {"u0": -p * 0.5, "u_span": p, "v0": ARC_V[0], "v1": ARC_V[1], "nu": ARC_NU, "nv": ARC_NV, "front": front, "back": back}


## The arc map at (u, height), bilinear as the shader samples it: [front, back].
func _arc_at(c: Vector2) -> Vector2:
	var p := float(_arc.u_span)
	var fx := (_wrap(c.x, p) - float(_arc.u0)) / p * ARC_NU - 0.5
	var fy := clampf((c.y - float(_arc.v0)) / (float(_arc.v1) - float(_arc.v0)), 0.0, 1.0) * (ARC_NV - 1)
	var x0 := int(floor(fx))
	var y0 := mini(int(floor(fy)), ARC_NV - 2)
	var kx := fx - x0
	var ky := fy - y0
	var out := Vector2.ZERO
	for ch in 2:
		var g: Array = _arc.front if ch == 0 else _arc.back
		var a := float(g[y0][posmod(x0, ARC_NU)])
		var b := float(g[y0][posmod(x0 + 1, ARC_NU)])
		var cc := float(g[y0 + 1][posmod(x0, ARC_NU)])
		var d := float(g[y0 + 1][posmod(x0 + 1, ARC_NU)])
		out[ch] = lerpf(lerpf(a, b, kx), lerpf(cc, d, kx), ky)
	return out


## Vertex i in a place's coordinates.
func _coord(i: int, space: String) -> Vector2:
	var c := _raw(i)
	match space:
		"front":
			return Vector2(_arc_at(c).x, c.y)
		"back":
			return Vector2(_arc_at(c).y, c.y)
		"mh":
			return _MH[i]
	return c


func _map(data: Dictionary) -> bool:
	if not _load_body():
		push_error("build_tattoos: no skin surface in %s" % BodyMaterials.BODY_GLB)
		return false
	_build_arc()
	var ids := BodyMaterials.region_ids()
	var places := {}
	var ok := true
	for pl: Dictionary in data.get("places", []):
		var regs := []
		for r: String in pl.regions:
			regs.append(int(ids[r]))
		var space := String(pl.get("space", "uv"))
		var side_n: Vector3 = Vector3.ZERO
		var has_side := pl.get("side_normal") is Array
		for k in ["side_normal", "fit_normal"]:
			if pl.get(k) is Array:
				side_n = Vector3(pl[k][0], pl[k][1], pl[k][2]).normalized()
		# the centre: the anchor in metre UVs, or the skin vertex nearest the face-coordinate anchor
		var raw_c := Vector2.ZERO
		var near := -1
		if pl.get("anchor_face") is Array:
			var fa := Vector2(pl.anchor_face[0], pl.anchor_face[1])
			var best := 1e9
			for i in _V.size():
				if _R[i] in regs and (side_n == Vector3.ZERO or _N[i].dot(side_n) > 0.3):
					var fc := BodyMaterials.warp_face_coords(_raw(i).x, _raw(i).y)
					if fc.distance_to(fa) < best:
						best = fc.distance_to(fa)
						raw_c = _raw(i)
						near = i
		else:
			raw_c = Vector2(pl.anchor[0], pl.anchor[1])
			var best := 1e9
			for i in _V.size():
				if _R[i] in regs and (side_n == Vector3.ZERO or _N[i].dot(side_n) > 0.3) and _raw(i).distance_to(raw_c) < best:
					best = _raw(i).distance_to(raw_c)
					near = i
		var c := raw_c
		if space == "mh":
			c = _MH[near]
		elif space == "front":
			c = Vector2(_arc_at(raw_c).x, raw_c.y)
		elif space == "back":
			c = Vector2(_arc_at(raw_c).y, raw_c.y)
		var fit := _fit(regs, space, c, side_n)
		if fit.is_empty():
			push_error("build_tattoos: place %s: too few skin vertices" % pl.id)
			ok = false
			continue
		var tu: Vector3 = fit.tu
		var tv: Vector3 = fit.tv
		var n: Vector3 = fit.n
		var up := Vector3.UP
		match String(pl.get("up", "world")):
			"-v":
				up = -tv
			"-u":
				up = -tu
		up = (up - n * up.dot(n)).normalized()
		var right := up.cross(n).normalized()
		var a := [right.dot(tu), right.dot(tv), up.dot(tu), up.dot(tv)]
		var e := {"space": space, "centre": [snappedf(c.x, 0.00001), snappedf(c.y, 0.00001)],
				"a": a.map(func(x: float) -> float: return snappedf(x, 0.0001)),
				"side": int(fit.h) if has_side else 0,
				"pos": [snappedf(fit.p.x, 0.0001), snappedf(fit.p.y, 0.0001), snappedf(fit.p.z, 0.0001)],
				"normal": [snappedf(n.x, 0.001), snappedf(n.y, 0.001), snappedf(n.z, 0.001)],
				"samples": int(fit.count)}
		places[String(pl.id)] = e
		print("  %-12s %-5s centre %s a %s side %d at %s (%d vertices, rms %.2f mm over %.3f)" % [pl.id, space, e.centre, e.a, e.side,
				e.pos, fit.count, fit.rms * 1000.0, fit.radius])
	var out := {"format": "frontier-tattoo-map", "version": 1, "body": BodyMaterials.BODY_GLB,
			"note": "Generated by tools/character/tattoos/build_tattoos.gd from body.glb: rebuild after the body changes.",
			"arc": _arc, "places": places}
	var f := FileAccess.open(MAP, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("build_tattoos: %d places, arc map %d x %d -> %s" % [places.size(), ARC_NU, ARC_NV, MAP])
	return ok


## Least-squares P = P0 + Tu du + Tv dv over the skin vertices about centre c (place coordinates).
func _fit(regs: Array, space: String, c: Vector2, side_n: Vector3) -> Dictionary:
	var rad := 0.008
	var ids := []
	while ids.size() < 60 and rad < 0.08:
		ids.clear()
		for i in _V.size():
			if not _R[i] in regs or (side_n != Vector3.ZERO and _N[i].dot(side_n) < 0.3):
				continue
			if _coord(i, space).distance_to(c) < rad:
				ids.append(i)
		rad *= 1.25
	if ids.size() < 8:
		return {}
	var n := float(ids.size())
	var md := Vector2.ZERO
	var mp := [0.0, 0.0, 0.0]
	var nn := Vector3.ZERO
	var co := {}
	for i in ids:
		co[i] = _coord(i, space) - c
		md += co[i]
		for ax in 3:
			mp[ax] += float(_V[i][ax])
		nn += _N[i]
	md /= n
	for ax in 3:
		mp[ax] /= n
	var suu := 0.0
	var svv := 0.0
	var suv := 0.0
	var spu := [0.0, 0.0, 0.0]
	var spv := [0.0, 0.0, 0.0]
	for i in ids:
		var d: Vector2 = co[i] - md
		var du := float(d.x)
		var dv := float(d.y)
		suu += du * du
		svv += dv * dv
		suv += du * dv
		for ax in 3:
			var q := float(_V[i][ax]) - float(mp[ax])
			spu[ax] += q * du
			spv[ax] += q * dv
	var det := suu * svv - suv * suv
	var tu := Vector3.ZERO
	var tv := Vector3.ZERO
	for ax in 3:
		tu[ax] = (svv * spu[ax] - suv * spv[ax]) / det
		tv[ax] = (suu * spv[ax] - suv * spu[ax]) / det
	nn = nn.normalized()
	var p0 := Vector3(mp[0], mp[1], mp[2]) - tu * md.x - tv * md.y
	# the fit's RMS miss (m): how far the place's coordinates are from a plane map over the sampled patch
	var res := 0.0
	for i in ids:
		var d: Vector2 = co[i]
		res += (p0 + tu * d.x + tv * d.y).distance_squared_to(_V[i])
	return {"tu": tu, "tv": tv, "n": nn, "p": p0, "h": signf(tu.cross(tv).dot(nn)), "count": ids.size(),
			"rms": sqrt(res / n), "radius": rad / 1.25}
