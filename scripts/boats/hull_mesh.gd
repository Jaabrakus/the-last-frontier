class_name HullMesh
extends Node3D
## The hull of a boat under construction, made from the plan's numbers (data/boats/plans.json "hull"; user 2026-09-29: "they can see it
## grow into something real"). Its parts appear as the stages are done and GROW as a stage is worked (set_part(id, fraction)):
##   stakes    the building bed's stakes round the outline, driven in one by one
##   skin      the bark, laid from the stern to the bow
##   gunwales  the inner and outer rails, the bark between them
##   ribs      the cedar ribs, set one after another along it
##   pitch     the dark seam along the keel and the two sides
## Local frame: +Z forward, +X right, +Y up, the origin on the ground under the middle of the keel. The surfaces are the project's
## Poly Haven textures (assets/polyhaven) with the birch made in code (cream, the dark lenticel dashes of the bark).

const TEX := "res://assets/polyhaven/textures/structures/"
const T_STEPS := 30
const A_STEPS := 8
const RIB_COUNT := 17
const STAKE_PAIRS := 7

var hull: Dictionary = {}
var parts := {}
var frac := {}
var _mats := {}


static func half_beam(h: Dictionary, t: float) -> float:
	return float(h.beam) * 0.5 * pow(maxf(1.0 - pow(absf(t), float(h.end_taper)), 0.0), 0.55)


static func top_y(h: Dictionary, t: float) -> float:
	return float(h.depth) + float(h.sheer_rise) * t * t + 0.06 * t * t


static func bottom_y(h: Dictionary, t: float) -> float:
	return 0.06 * t * t


## The hull's surface at length t (-1 stern .. 1 bow) and angle a (0 the keel .. PI/2 the gunwale), on the right side.
static func section(h: Dictionary, t: float, a: float) -> Vector3:
	var w := half_beam(h, t)
	var by := bottom_y(h, t)
	var ty := top_y(h, t)
	return Vector3(w * pow(sin(a), float(h.bottom_round)), by + (ty - by) * (1.0 - cos(a)), t * float(h.length) * 0.5)


func setup(p_hull: Dictionary) -> void:
	hull = p_hull
	for id in ["stakes", "skin", "gunwales", "ribs", "pitch"]:
		var n := Node3D.new()
		n.name = id
		n.visible = false
		add_child(n)
		parts[id] = n
		frac[id] = -1.0


## Shows a part grown to `f` (0 hidden .. 1 whole); rebuilt only when it changed enough to see.
func set_part(id: String, f: float) -> void:
	if not parts.has(id):
		return
	f = clampf(f, 0.0, 1.0)
	if is_equal_approx(float(frac[id]), f):
		return
	var n := parts[id] as Node3D
	for c in n.get_children():
		c.queue_free()
		n.remove_child(c)
	frac[id] = f
	n.visible = f > 0.001
	if f <= 0.001 or DisplayServer.get_name() == "headless":
		return
	match id:
		"stakes": _stakes(n, f)
		"skin": _skin(n, f)
		"gunwales": _gunwales(n, f)
		"ribs": _ribs(n, f)
		"pitch": _pitch(n, f)


func _mi(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	parent.add_child(m)
	return m


# ---------------------------------------------------------------- materials
func _birch(outer := false) -> Material:
	var key := "birch_out" if outer else "birch"
	if _mats.has(key):
		return _mats[key]
	var img := Image.create(512, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1751
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.seed = 9
	for y in 256:
		for x in 512:
			var n := noise.get_noise_2d(float(x) * 0.6, float(y) * 2.2) * 0.5 + 0.5
			var c := Color(0.93, 0.89, 0.8).lerp(Color(0.8, 0.66, 0.5), n * 0.45)
			if outer:
				c = Color(0.72, 0.42, 0.2).lerp(Color(0.55, 0.3, 0.14), n * 0.7)   # the inner bark, faced out on a canoe
			img.set_pixel(x, y, c)
	# the lenticels: short dark horizontal dashes
	for i in 520:
		var x0 := rng.randi_range(0, 511)
		var y0 := rng.randi_range(0, 255)
		var len := rng.randi_range(6, 30)
		var dark := rng.randf_range(0.45, 0.75)
		for dx in len:
			var px := (x0 + dx) % 512
			var c: Color = img.get_pixel(px, y0)
			img.set_pixel(px, y0, Color(c.r * dark, c.g * dark, c.b * dark))
			if rng.randf() < 0.5:
				var c2: Color = img.get_pixel(px, (y0 + 1) % 256)
				img.set_pixel(px, (y0 + 1) % 256, Color(c2.r * (dark + 0.15), c2.g * (dark + 0.15), c2.b * (dark + 0.15)))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.62
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.uv1_scale = Vector3(2.0, 1.2, 1.0)
	var nrm := load(TEX + "bark_brown_02/bark_brown_02_nor_gl_2k.jpg") as Texture2D
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 0.35
	_mats[key] = m
	return m


func _wood(tint: Color, tex := "brown_planks_07") -> Material:
	var key := "wood%s%s" % [tex, tint.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var d := load(TEX + "%s/%s_diffuse_2k.jpg" % [tex, tex]) as Texture2D
	if d:
		m.albedo_texture = d
	m.albedo_color = tint
	m.roughness = 0.82
	m.uv1_scale = Vector3(1.5, 3.0, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


func _pitch_mat() -> Material:
	if _mats.has("pitch"):
		return _mats["pitch"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.06, 0.04)
	m.roughness = 0.35
	m.metallic_specular = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["pitch"] = m
	return m


# ---------------------------------------------------------------- the parts
func _ts(f: float) -> Array[float]:
	var out: Array[float] = []
	var n := maxi(int(ceil(f * T_STEPS)), 1)
	for i in n + 1:
		out.append(-1.0 + 2.0 * f * float(i) / float(n))
	return out


func _skin(parent: Node3D, f: float) -> void:
	_mi(parent, _skin_mesh(f, false), _birch(true))   # the outside: the tan inner bark
	_mi(parent, _skin_mesh(f, true), _birch(false))   # the inside: the white


func _skin_mesh(f: float, inside: bool) -> Mesh:
	var ts := _ts(f)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [1.0, -1.0]:
		for i in ts.size() - 1:
			for j in A_STEPS:
				var a0 := PI * 0.5 * float(j) / float(A_STEPS)
				var a1 := PI * 0.5 * float(j + 1) / float(A_STEPS)
				var p00 := _side(section(hull, ts[i], a0), side)
				var p10 := _side(section(hull, ts[i + 1], a0), side)
				var p01 := _side(section(hull, ts[i], a1), side)
				var p11 := _side(section(hull, ts[i + 1], a1), side)
				var u0 := (ts[i] + 1.0) * 0.5
				var u1 := (ts[i + 1] + 1.0) * 0.5
				var v0 := (0.5 + side * float(j) / float(A_STEPS) * 0.5)
				var v1 := (0.5 + side * float(j + 1) / float(A_STEPS) * 0.5)
				var quad := [[p00, Vector2(u0, v0)], [p10, Vector2(u1, v0)], [p11, Vector2(u1, v1)], [p00, Vector2(u0, v0)], [p11, Vector2(u1, v1)], [p01, Vector2(u0, v1)]]
				if (side < 0.0) != inside:
					quad.reverse()
				for q: Array in quad:
					st.set_uv(q[1])
					st.add_vertex(q[0])
	st.generate_normals()
	return st.commit()


static func _side(p: Vector3, side: float) -> Vector3:
	return Vector3(p.x * side, p.y, p.z)


## A rectangle swept along `pts`: at each point `ua` and `ub` are the profile's two axes (unit), half-sizes `ha` and `hb`.
func _sweep(parent: Node3D, pts: Array[Vector3], ua: Array[Vector3], ub: Array[Vector3], ha: float, hb: float, mat: Material) -> void:
	if pts.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [[1.0, 1.0], [-1.0, 1.0], [-1.0, -1.0], [1.0, -1.0]]
	for i in pts.size() - 1:
		for c in 4:
			var c0: Array = corners[c]
			var c1: Array = corners[(c + 1) % 4]
			var a0 := pts[i] + ua[i] * ha * float(c0[0]) + ub[i] * hb * float(c0[1])
			var a1 := pts[i] + ua[i] * ha * float(c1[0]) + ub[i] * hb * float(c1[1])
			var b0 := pts[i + 1] + ua[i + 1] * ha * float(c0[0]) + ub[i + 1] * hb * float(c0[1])
			var b1 := pts[i + 1] + ua[i + 1] * ha * float(c1[0]) + ub[i + 1] * hb * float(c1[1])
			for v in [a0, b0, b1, a0, b1, a1]:
				st.set_uv(Vector2(v.x + v.z, v.y * 3.0))
				st.add_vertex(v)
	st.generate_normals()
	_mi(parent, st.commit(), mat)


func _gunwales(parent: Node3D, f: float) -> void:
	var ts := _ts(f)
	for side: float in [1.0, -1.0]:
		for off: float in [-0.03, 0.03]:   # the inner rail and the outer, the bark between
			var pts: Array[Vector3] = []
			var ua: Array[Vector3] = []
			var ub: Array[Vector3] = []
			for i in ts.size():
				var t := ts[i]
				var p := _side(section(hull, t, PI * 0.5), side)
				p.x += side * off * (1.0 if absf(t) < 0.985 else 0.0)
				p.y += 0.012
				pts.append(p)
				ua.append(Vector3.RIGHT)
				ub.append(Vector3.UP)
			_sweep(parent, pts, ua, ub, 0.018, 0.022, _wood(Color(0.84, 0.72, 0.56)))


func _ribs(parent: Node3D, f: float) -> void:
	var n := clampi(int(ceil(f * RIB_COUNT)), 1, RIB_COUNT)
	for k in n:
		var t := -0.88 + 1.76 * float(k) / float(RIB_COUNT - 1)
		var pts: Array[Vector3] = []
		var ua: Array[Vector3] = []
		var ub: Array[Vector3] = []
		var steps := 16
		for k2 in steps + 1:
			var sv := -1.0 + 2.0 * float(k2) / float(steps)   # the left gunwale, over the keel, to the right gunwale
			var side := 1.0 if sv >= 0.0 else -1.0
			var p := _side(section(hull, t, absf(sv) * PI * 0.5), side)
			var inward := Vector3(-p.x, (top_y(hull, t) * 0.55) - p.y, 0.0).normalized()
			pts.append(p + inward * 0.012)
			ua.append(Vector3.FORWARD)
			ub.append(inward)
		_sweep(parent, pts, ua, ub, 0.024, 0.008, _wood(Color(0.86, 0.76, 0.62), "roof_planks"))


func _pitch(parent: Node3D, f: float) -> void:
	var ts := _ts(f)
	for a: float in [0.0, 0.55]:
		for side: float in ([1.0] if a == 0.0 else [1.0, -1.0]):
			var pts: Array[Vector3] = []
			var ua: Array[Vector3] = []
			var ub: Array[Vector3] = []
			for i in ts.size():
				var t := ts[i] * 0.97
				var p := _side(section(hull, t, a), side)
				var out := Vector3(side * 0.6 if a > 0.0 else 0.0, -0.8 if a == 0.0 else 0.4, 0.0).normalized()
				pts.append(p + out * 0.006)
				ua.append(Vector3.RIGHT if a == 0.0 else Vector3.UP)
				ub.append(out if a == 0.0 else Vector3(side, 0.0, 0.0))
			_sweep(parent, pts, ua, ub, 0.022, 0.004, _pitch_mat())


func _stakes(parent: Node3D, f: float) -> void:
	var n := clampi(int(ceil(f * STAKE_PAIRS * 2)), 1, STAKE_PAIRS * 2)
	var idx := 0
	for k in STAKE_PAIRS:
		var t := -0.82 + 1.64 * float(k) / float(STAKE_PAIRS - 1)
		for side: float in [1.0, -1.0]:
			if idx >= n:
				return
			idx += 1
			var w := half_beam(hull, t) + 0.14
			var c := CylinderMesh.new()
			c.top_radius = 0.02
			c.bottom_radius = 0.028
			c.height = 0.62
			var m := _mi(parent, c, _wood(Color(0.78, 0.62, 0.45), "roof_planks"))
			m.position = Vector3(side * w, 0.26, t * float(hull.length) * 0.5)
			m.rotation = Vector3(0.0, 0.0, -side * 0.05)
