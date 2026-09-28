class_name FishMesh
extends RefCounted
## A fish's body and skin, from its species' look (data/world/fish.json "look"): our own, made here (no fish model in
## the project). tools/wildlife/fish_bake.gd bakes them to assets/wildlife/fish/ (<id>.res, <id>_skin.png); the game
## loads those (mesh(), material()), and builds them itself when they are missing.
##
## The body is one metre long, snout at z -0.5 (facing -Z, Godot's forward) to tail tip at +0.5; scaled to each fish's
## length. Its cross-sections are rounded ellipses of the look's half-heights `h` and half-widths `w` (fractions of its
## length, by u: 0 the snout .. 1 the tail tip), lifted by `c`; the tail (`tail`: from `base`, its lobes' half-spans
## `hi` and `lo`, `fork` its fork's depth, below 0 rounded; `upper_long` a sturgeon's longer upper lobe) and the fins
## (`fins`: dorsal, dorsal_spiny, adipose, anal along the back or belly between u's; pectoral and pelvic in pairs;
## barbels) are flat and two-sided. The skin: the body wrapped on the top three quarters of the texture (u along, round
## from the back: 0 the back, 0.5 the belly), the fins in bands along its bottom quarter (FIN_BAND).
## Swimming is the shader's (shaders/wildlife/fish.gdshader): the body waved side to side, more toward the tail.

const DIR := "res://assets/wildlife/fish/"
const SHADER_PATH := "res://shaders/wildlife/fish.gdshader"
const NU := 40
const NV := 18
## How square its cross-sections are (2: an ellipse).
const ROUND := 2.4
const SKIN_PX := 256
## Each fin kind's band along the bottom quarter of the skin (x from, to).
const FIN_BAND := {"dorsal": [0.0, 0.2], "dorsal_spiny": [0.0, 0.2], "caudal": [0.2, 0.4], "pectoral": [0.4, 0.6],
		"pelvic": [0.6, 0.8], "anal": [0.6, 0.8], "adipose": [0.8, 1.0], "barbel": [0.8, 1.0]}
const BODY_V := 0.75

static var _meshes := {}
static var _materials := {}


## The species' mesh (baked, or built now).
static func mesh(id: String) -> Mesh:
	if not _meshes.has(id):
		var path := DIR + id + ".res"
		var m: Mesh = load(path) if ResourceLoader.exists(path) else null
		if m == null:
			m = build(FishSpecies.spec(id).get("look", {}))
		_meshes[id] = m
	return _meshes[id]


## The species' material: its skin, its shine, its way of swimming.
static func material(id: String) -> ShaderMaterial:
	if not _materials.has(id):
		var look: Dictionary = FishSpecies.spec(id).get("look", {})
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER_PATH)
		var path := DIR + id + "_skin.png"
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else ImageTexture.create_from_image(paint(look))
		mat.set_shader_parameter("albedo_tex", tex)
		mat.set_shader_parameter("roughness_v", float(look.get("rough", 0.4)))
		mat.set_shader_parameter("specular_v", float(look.get("shine", 0.5)))
		var sw: Dictionary = look.get("swim", {})
		mat.set_shader_parameter("wave_k", float(sw.get("k", 0.85)))
		mat.set_shader_parameter("amp_head", float(sw.get("head", 0.012)))
		mat.set_shader_parameter("amp_tail", float(sw.get("tail", 0.1)))
		_materials[id] = mat
	return _materials[id]


# --- The body -----------------------------------------------------------------------------------------------------

## A profile (`pts`: [[u, value], ...]) at u: rounded at the snout (a square root up to its first point), smooth
## between (Catmull-Rom), held past its last.
static func curve(pts: Array, u: float) -> float:
	if pts.is_empty():
		return 0.0
	var n := pts.size()
	if u <= float(pts[0][0]):
		return float(pts[0][1])
	if u >= float(pts[n - 1][0]):
		return float(pts[n - 1][1])
	for i in n - 1:
		var u0 := float(pts[i][0])
		var u1 := float(pts[i + 1][0])
		if u > u1:
			continue
		var t := (u - u0) / maxf(u1 - u0, 1e-6)
		var v0 := float(pts[i][1])
		var v1 := float(pts[i + 1][1])
		if i == 0 and v0 == 0.0:
			return v1 * sqrt(t)
		var vm := float(pts[i - 1][1]) if i > 0 else v0 - (v1 - v0)
		var vp := float(pts[i + 2][1]) if i + 2 < n else v1 + (v1 - v0)
		var t2 := t * t
		var t3 := t2 * t
		return maxf(0.5 * (2.0 * v0 + (-vm + v1) * t + (2.0 * vm - 5.0 * v0 + 4.0 * v1 - vp) * t2
				+ (-vm + 3.0 * v0 - 3.0 * v1 + vp) * t3), 0.0) if v0 > 0.0 or v1 > 0.0 else 0.0
	return float(pts[n - 1][1])


## The body's surface at (u, round: 0 the back, PI the belly).
static func body_point(look: Dictionary, u: float, th: float) -> Vector3:
	var h := curve(look.get("h", []), u)
	var w := curve(look.get("w", []), u)
	var c := curve(look.get("c", []), u) if look.has("c") else 0.0
	var s := sin(th)
	var co := cos(th)
	var e := 2.0 / ROUND
	return Vector3(w * signf(s) * pow(absf(s), e), c + h * signf(co) * pow(absf(co), e), u - 0.5)


## The body's top (up 1) or bottom (-1) line at u.
static func line_y(look: Dictionary, u: float, up: float) -> float:
	var c := curve(look.get("c", []), u) if look.has("c") else 0.0
	return c + up * curve(look.get("h", []), u)


## Round the body at u (its cross-section's perimeter, fractions of its length).
static func girth(look: Dictionary, u: float) -> float:
	var h := curve(look.get("h", []), u)
	var w := curve(look.get("w", []), u)
	return TAU * sqrt((h * h + w * w) * 0.5)


static func build(look: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tail: Dictionary = look.get("tail", {})
	var base := float(tail.get("base", 0.85))
	# the body: rings from the snout to the tail's base, closer at the snout
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in NU + 1:
		var u := base * pow(float(i) / NU, 1.35)
		for j in NV + 1:
			var th := TAU * float(j) / NV
			var p := body_point(look, u, th)
			verts.append(p)
			norms.append(_body_normal(look, u, th, p))
			uvs.append(Vector2(u / base, float(j) / NV * BODY_V))
	var idx := PackedInt32Array()
	for i in NU:
		for j in NV:
			var a := i * (NV + 1) + j
			var b := a + NV + 1
			idx.append_array([a, b, b + 1, a, b + 1, a + 1])
	# the tail's stump closed
	var cap := verts.size()
	verts.append(Vector3(0.0, line_y(look, base, 0.0), base - 0.5))
	norms.append(Vector3.BACK)
	uvs.append(Vector2(1.0, BODY_V * 0.5))
	for j in NV:
		var a := NU * (NV + 1) + j
		idx.append_array([a, a + 1, cap])
	_emit(st, verts, norms, uvs, idx)
	# the tail and fins
	_caudal(st, look)
	for f: Dictionary in look.get("fins", []):
		match String(f.get("k", "")):
			"dorsal", "dorsal_spiny", "adipose":
				_fin_line(st, look, f, 1.0)
			"anal":
				_fin_line(st, look, f, -1.0)
			"pectoral":
				_fin_pair(st, look, f, 0.66 * PI, Vector3(0.55, -0.3, 1.0))
			"pelvic":
				_fin_pair(st, look, f, 0.86 * PI, Vector3(0.35, -0.55, 1.0))
			"barbel":
				_barbels(st, f)
	return st.commit()


static func _body_normal(look: Dictionary, u: float, th: float, p: Vector3) -> Vector3:
	var du := 0.004
	var dt := 0.02
	var pu := body_point(look, minf(u + du, 1.0), th) - body_point(look, maxf(u - du, 0.0), th)
	var pt := body_point(look, u, th + dt) - body_point(look, u, th - dt)
	var n := pt.cross(pu)
	if n.length() < 1e-7:
		return Vector3.FORWARD
	n = n.normalized()
	var out := p - Vector3(0.0, line_y(look, u, 0.0), p.z)
	if out.length() < 1e-6:
		out = Vector3.FORWARD
	return n if n.dot(out) >= 0.0 else -n


## Triangles into the surface tool, each wound so its face points along its vertices' normals (Godot: a front face's
## (B-A)x(C-A) points away from the viewer).
static func _emit(st: SurfaceTool, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> void:
	for t in idx.size() / 3:
		var a := idx[t * 3]
		var b := idx[t * 3 + 1]
		var c := idx[t * 3 + 2]
		var fn := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if fn.length() < 1e-10:
			continue
		if fn.dot(norms[a] + norms[b] + norms[c]) > 0.0:
			var tmp := b
			b = c
			c = tmp
		for k in [a, b, c]:
			st.set_normal(norms[k])
			st.set_uv(uvs[k])
			st.add_vertex(verts[k])


## A flat fin from a grid of points (rows[s][t]) and their skin coordinates, both sides.
static func _flat(st: SurfaceTool, rows: Array, uv_rows: Array) -> void:
	var ns := rows.size()
	var nt := (rows[0] as PackedVector3Array).size()
	for side in [1.0, -1.0]:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		for s in ns:
			for t in nt:
				verts.append(rows[s][t])
				uvs.append(uv_rows[s][t])
		# its plane's normal from the grid's middle
		var s0 := 0
		var s1 := ns - 1
		var n := ((rows[s1][0] as Vector3) - (rows[s0][0] as Vector3)).cross((rows[s0][nt - 1] as Vector3) - (rows[s0][0] as Vector3))
		if n.length() < 1e-9:
			n = ((rows[s1][nt - 1] as Vector3) - (rows[s0][0] as Vector3)).cross(Vector3.UP)
		n = n.normalized() * side
		for k in verts.size():
			norms.append(n)
		var idx := PackedInt32Array()
		for s in ns - 1:
			for t in nt - 1:
				var a := s * nt + t
				idx.append_array([a, a + nt, a + nt + 1, a, a + nt + 1, a + 1])
		_emit(st, verts, norms, uvs, idx)


static func _band_uv(kind: String, s: float, t: float) -> Vector2:
	var b: Array = FIN_BAND.get(kind, [0.8, 1.0])
	return Vector2(lerpf(float(b[0]), float(b[1]), clampf(s, 0.0, 1.0)) , BODY_V + (1.0 - BODY_V) * clampf(t, 0.0, 1.0))


## The tail fin: from the stump at `base` to its lobes' tips, forked (or rounded) between them.
static func _caudal(st: SurfaceTool, look: Dictionary) -> void:
	var tl: Dictionary = look.get("tail", {})
	var base := float(tl.get("base", 0.85))
	var hi := float(tl.get("hi", 0.1))
	var lo := float(tl.get("lo", 0.1))
	var fork := float(tl.get("fork", 0.02))
	var up_long := float(tl.get("upper_long", 0.0))
	var hp := curve(look.get("h", []), base)
	var cy := line_y(look, base, 0.0)
	var rows := []
	var uv_rows := []
	var ns := 7
	var nt := 11
	for s in ns:
		var sf := float(s) / (ns - 1)
		var row := PackedVector3Array()
		var uvr := PackedVector2Array()
		for t in nt:
			var tf := lerpf(-1.0, 1.0, float(t) / (nt - 1))
			# the trailing edge: forked (in at the middle), or rounded (out at the middle)
			var end_u := 1.0 - fork * (1.0 - absf(tf)) if fork >= 0.0 else 1.0 + fork * tf * tf
			if tf > 0.0:
				end_u += up_long * tf * tf
			var u0 := base - 0.01
			var u := lerpf(u0, end_u, sf)
			var span := lerpf(hp * 0.95, hi if tf > 0.0 else lo, pow(sf, 0.8))
			var y := cy + tf * span + (up_long * 0.6 * sf * maxf(tf, 0.0))
			row.append(Vector3(0.0, y, u - 0.5))
			uvr.append(_band_uv("caudal", sf, absf(tf)))
		rows.append(row)
		uv_rows.append(uvr)
	_flat(st, rows, uv_rows)


## A fin along the back (up 1: dorsal, spiny dorsal, adipose) or belly (-1: anal) between its u's, its height `h`.
static func _fin_line(st: SurfaceTool, look: Dictionary, f: Dictionary, up: float) -> void:
	var kind := String(f.k)
	var ua := float(f.u[0])
	var ub := float(f.u[1])
	var h := absf(float(f.get("h", 0.06)))
	var low := bool(f.get("low", false))
	var ns := 16 if kind == "dorsal_spiny" else 9
	var rows := []
	var uv_rows := []
	for s in ns:
		var sf := float(s) / (ns - 1)
		var u := lerpf(ua, ub, sf)
		var ht: float
		var sweep := 0.35
		match kind:
			"dorsal_spiny":
				ht = h * smoothstep(0.0, 0.12, sf) * lerpf(1.0, 0.5, sf) * (0.84 + 0.16 * cos(TAU * 5.0 * sf))
				sweep = 0.2
			"adipose":
				ht = h * pow(sin(PI * sf), 0.7)
				sweep = 0.4
			_:
				if low:
					ht = h * smoothstep(0.0, 0.12, sf) * lerpf(1.0, 0.75, sf)
					sweep = 0.1
				else:
					ht = h * (smoothstep(0.0, 0.25, sf) if sf < 0.25 else lerpf(1.0, 0.38, (sf - 0.25) / 0.75))
		var y0 := line_y(look, u, up) - up * 0.004
		var row := PackedVector3Array()
		var uvr := PackedVector2Array()
		for t in 2:
			var tf := float(t)
			row.append(Vector3(0.0, y0 + up * ht * tf, u - 0.5 + sweep * ht * tf))
			uvr.append(_band_uv(kind, sf, tf))
		rows.append(row)
		uv_rows.append(uvr)
	_flat(st, rows, uv_rows)


## A pair of fins (pectoral, pelvic) on the body's sides at round `th`, reaching back and out along `dir`.
static func _fin_pair(st: SurfaceTool, look: Dictionary, f: Dictionary, th: float, dir: Vector3) -> void:
	var kind := String(f.k)
	var ua := float(f.u[0])
	var ub := float(f.u[1])
	var h := float(f.get("h", 0.05))
	for side in [1.0, -1.0]:
		var d := Vector3(dir.x * side, dir.y, dir.z).normalized()
		var rows := []
		var uv_rows := []
		var ns := 6
		for s in ns:
			var sf := float(s) / (ns - 1)
			var u := lerpf(ua, ub, sf)
			var p := body_point(look, u, th if side > 0.0 else TAU - th)
			p.x *= 0.92
			var reach := h * (0.55 + 0.45 * sin(PI * lerpf(0.2, 1.0, sf)))
			var row := PackedVector3Array([p, p + d * reach])
			rows.append(row)
			uv_rows.append(PackedVector2Array([_band_uv(kind, sf, 0.0), _band_uv(kind, sf, 1.0)]))
		_flat(st, rows, uv_rows)


## Barbels: thin feelers from `from` to `to` ([along, side, up]), on both sides, as two crossed ribbons each.
static func _barbels(st: SurfaceTool, f: Dictionary) -> void:
	var fr: Array = f.get("from", [0.0, 0.0, 0.0])
	var to: Array = f.get("to", [0.1, 0.0, 0.0])
	for side in [1.0, -1.0]:
		var a := Vector3(float(fr[1]) * side, float(fr[2]), float(fr[0]) - 0.5)
		var b := Vector3(float(to[1]) * side, float(to[2]), float(to[0]) - 0.5)
		var along := (b - a).normalized()
		for across: Vector3 in [along.cross(Vector3.UP).normalized(), along.cross(Vector3.RIGHT).normalized()]:
			if across.length() < 0.5:
				continue
			var rows := []
			var uv_rows := []
			var ns := 5
			for s in ns:
				var sf := float(s) / (ns - 1)
				var p := a.lerp(b, sf) + Vector3(0.0, -0.01 * sin(PI * sf) * (b - a).length() * 4.0, 0.0)
				var wd := lerpf(0.006, 0.0015, sf)
				rows.append(PackedVector3Array([p - across * wd, p + across * wd]))
				uv_rows.append(PackedVector2Array([_band_uv("barbel", sf, 0.0), _band_uv("barbel", sf, 1.0)]))
			_flat(st, rows, uv_rows)


# --- The skin -----------------------------------------------------------------------------------------------------

static func _c(hex: Variant, fallback := Color(0.4, 0.4, 0.35)) -> Color:
	return Color.html(String(hex)) if hex is String and Color.html_is_valid(String(hex)) else fallback


## The skin: the body's colours from back to belly, its markings (look.paint.patterns), its eyes and gill covers, and
## the fins in their bands.
static func paint(look: Dictionary, px := SKIN_PX) -> Image:
	var pt: Dictionary = look.get("paint", {})
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var bh := int(px * BODY_V)
	var base := float((look.get("tail", {}) as Dictionary).get("base", 0.85))
	var back := _c(pt.get("back"))
	var sidec := _c(pt.get("side"))
	var belly := _c(pt.get("belly"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(JSON.stringify(pt))
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var cell := FastNoiseLite.new()
	cell.seed = rng.randi()
	cell.noise_type = FastNoiseLite.TYPE_CELLULAR
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var girths := PackedFloat32Array()
	for x in px:
		girths.append(maxf(girth(look, (float(x) + 0.5) / px * base), 0.01))
	# the body's colours, back to belly, and the markings that are everywhere at once
	for y in bh:
		var a := (float(y) + 0.5) / bh
		var d := absf(a - 0.5) * 2.0
		var col := belly.lerp(sidec, smoothstep(0.22, 0.42, d)).lerp(back, smoothstep(0.58, 0.82, d))
		for x in px:
			var u := (float(x) + 0.5) / px * base
			var gx := u
			var gy := a * girths[x]
			var c := col
			for p: Dictionary in pt.get("patterns", []):
				var dr: Array = p.get("d", [0.0, 1.0])
				var inside := d >= float(dr[0]) and d <= float(dr[1])
				var pc := _c(p.get("c"))
				var al := float(p.get("a", 1.0))
				match String(p.get("k", "")):
					"vermiculate":
						if inside:
							var n := noise.get_noise_2d(gx * 1400.0, gy * 1400.0)
							if absf(n) < 0.09:
								c = c.lerp(pc, 0.85 * smoothstep(float(dr[0]), float(dr[0]) + 0.08, d))
					"blush", "stripe":
						if inside:
							var mid := (float(dr[0]) + float(dr[1])) * 0.5
							var half := (float(dr[1]) - float(dr[0])) * 0.5
							c = c.lerp(pc, al * smoothstep(half, half * 0.3, absf(d - mid)))
					"scales":
						if inside:
							var k := 90.0
							var s1 := absf(fposmod(gx * k + gy * k, 1.0) - 0.5)
							var s2 := absf(fposmod(gx * k - gy * k, 1.0) - 0.5)
							if minf(s1, s2) > 0.42:
								c = c.lerp(pc, al)
					"bars":
						var ur: Array = p.get("u", [0.2, 0.8])
						var n_b := int(p.get("n", 6))
						var wd := float(p.get("w", 0.03)) * smoothstep(float(dr[0]), float(dr[0]) + 0.35, d)
						for bi in n_b:
							var bu := lerpf(float(ur[0]), float(ur[1]), (float(bi) + 0.5) / n_b) + 0.01 * sin(d * 9.0 + bi)
							if inside and absf(u - bu) < wd:
								c = c.lerp(pc, 0.85 * smoothstep(wd, wd * 0.5, absf(u - bu)))
					"mottle":
						if inside:
							var n2 := noise.get_noise_2d(gx * 520.0, gy * 520.0) + 0.5 * noise.get_noise_2d(gx * 1500.0 + 40.0, gy * 1500.0)
							if n2 > 0.08:
								c = c.lerp(pc, al * smoothstep(0.08, 0.3, n2))
					"chain":
						if inside:
							var e := cell.get_noise_2d(gx * 900.0, gy * 900.0)
							if e < -0.82:
								c = c.lerp(pc, 0.9)
			img.set_pixel(x, y, c)
	# markings put down one at a time
	for p: Dictionary in pt.get("patterns", []):
		var pc := _c(p.get("c"))
		var dr: Array = p.get("d", [0.0, 1.0])
		match String(p.get("k", "")):
			"spots", "xspots", "ovals", "speckle":
				for i in int(p.get("n", 20)):
					var u := rng.randf_range(0.1, 0.97) * base
					var d := rng.randf_range(float(dr[0]), float(dr[1]))
					var a := 0.5 - d * 0.5 if rng.randf() < 0.5 else 0.5 + d * 0.5
					var r := float(p.get("r", 0.01)) * rng.randf_range(0.7, 1.2)
					var kind := String(p.k)
					var ru := r * (1.8 if kind == "ovals" else 1.0)
					if p.has("halo"):
						_dot(img, look, base, bh, u, a, r * 1.7, r * 1.7, _c(p.halo), kind)
					_dot(img, look, base, bh, u, a, ru, r, pc, kind)
			"scutes":
				for row in p.get("rows", [1.0]):
					for i in int(p.get("n", 12)):
						var u := lerpf(0.14, 0.8, (float(i) + 0.5) / float(p.get("n", 12))) * base
						for a in ([0.0, 1.0] if float(row) >= 0.99 else [0.5 - float(row) * 0.5, 0.5 + float(row) * 0.5]):
							_dot(img, look, base, bh, u, a, 0.011, 0.011, pc, "diamond")
	# the eyes, and the gill covers behind them
	var er := float(look.get("eye", 0.018))
	var eu := 0.03 + 2.3 * er
	var ed := 0.7
	var gu := eu + 3.2 * er + 0.03
	for y in bh:
		var a := (float(y) + 0.5) / bh
		var d := absf(a - 0.5) * 2.0
		if d < 0.2 or d > 0.9:
			continue
		for x in px:
			var u := (float(x) + 0.5) / px * base
			var gc := gu + 0.025 * sin(PI * (d - 0.2) / 0.7)
			if absf(u - gc) < 0.0025:
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.18))
	for a in [0.5 - ed * 0.5, 0.5 + ed * 0.5]:
		_dot(img, look, base, bh, eu, a, er, er, Color(0.78, 0.66, 0.32), "spots")
		_dot(img, look, base, bh, eu, a, er * 0.62, er * 0.62, Color(0.03, 0.03, 0.03), "spots")
		_dot(img, look, base, bh, eu - er * 0.25, a - 0.006 * signf(a - 0.5), er * 0.18, er * 0.18, Color(0.95, 0.95, 0.9), "spots")
	# the fins
	_paint_fins(img, pt, rng, noise, px, bh)
	img.generate_mipmaps()
	return img


## A round mark (or a diamond, an x) at (u, round a) of radii ru along and r round, in body pixels.
static func _dot(img: Image, look: Dictionary, base: float, bh: int, u: float, a: float, ru: float, r: float, col: Color, kind: String) -> void:
	var px := img.get_width()
	var g := maxf(girth(look, u), 0.01)
	var rx := ru / base * px
	var ry := r / g * bh
	var cx := u / base * px
	var cy := a * bh
	for y in range(floori(cy - ry - 1.0), ceili(cy + ry + 1.0)):
		var yy := posmod(y, bh)
		for x in range(maxi(floori(cx - rx - 1.0), 0), mini(ceili(cx + rx + 1.0), px)):
			var dx := (float(x) + 0.5 - cx) / maxf(rx, 0.5)
			var dy := (float(y) + 0.5 - cy) / maxf(ry, 0.5)
			var hit := 0.0
			match kind:
				"xspots":
					hit = 1.0 if (absf(absf(dx) - absf(dy)) < 0.35 and absf(dx) < 1.0) else 0.0
				"diamond":
					hit = smoothstep(1.0, 0.7, absf(dx) + absf(dy))
				_:
					hit = smoothstep(1.0, 0.75, sqrt(dx * dx + dy * dy))
			if hit > 0.0:
				img.set_pixel(x, yy, img.get_pixel(x, yy).lerp(col, hit))


## Each fin band: its colour (fin_top for the dorsal and tail, fin_low for the paired and anal fins, else fin), darker
## rays, the leading edge (fin_edge) and a bar behind it (fin_bar) on the paired and anal fins, and marbling or a dark
## membrane where the patterns say.
static func _paint_fins(img: Image, pt: Dictionary, rng: RandomNumberGenerator, noise: FastNoiseLite, px: int, bh: int) -> void:
	var fin := _c(pt.get("fin"))
	var top := _c(pt.get("fin_top"), fin) if pt.has("fin_top") else fin
	var low := _c(pt.get("fin_low"), fin) if pt.has("fin_low") else fin
	var edge := _c(pt.get("fin_edge"), fin) if pt.has("fin_edge") else fin
	var bar := _c(pt.get("fin_bar"), low) if pt.has("fin_bar") else low
	var marbled := {}
	var membrane := {}
	for p: Dictionary in pt.get("patterns", []):
		if String(p.get("k", "")) == "fin_marble":
			for f in p.get("fins", []):
				marbled[String(f)] = _c(p.get("c"))
		elif String(p.get("k", "")) == "fin_membrane":
			for f in p.get("fins", []):
				membrane[String(f)] = _c(p.get("c"))
	for y in range(bh, px):
		var t := (float(y) - bh + 0.5) / (px - bh)
		for x in px:
			var fx := (float(x) + 0.5) / px
			var band := floori(fx * 5.0)
			var s := fx * 5.0 - band
			var c: Color
			var names: Array
			match band:
				0:
					c = top
					names = ["dorsal", "dorsal_spiny"]
				1:
					c = top
					names = ["caudal"]
				2:
					c = low
					names = ["pectoral"]
				3:
					c = low
					names = ["pelvic", "anal"]
				_:
					c = fin
					names = ["adipose", "barbel"]
			# rays out from the base
			if absf(fposmod(s * 14.0, 1.0) - 0.5) > 0.4:
				c = c.darkened(0.12)
			c = c.lightened(0.12 * t)
			if band == 2 or band == 3:
				if s < 0.1:
					c = edge
				elif s < 0.17 and pt.has("fin_bar"):
					c = bar
			for nm in names:
				if marbled.has(nm):
					var n := noise.get_noise_2d(fx * 900.0, t * 180.0)
					if n > 0.15:
						c = c.lerp(marbled[nm], 0.8)
				if membrane.has(nm) and s > 0.6 and t > 0.25:
					c = c.lerp(membrane[nm], 0.75)
			img.set_pixel(x, y, c)
