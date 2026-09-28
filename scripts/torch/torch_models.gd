class_name TorchModels
## The hand torch, built in code (push n01b; a project-generated model): a split stave of pitch pine with a
## head of resin-soaked fat-pine ("lightwood", candlewood) splints bound on with two strips of birch bark, the
## torch of the 1750s-60s northeast frontier (settlers' pine-knot torches and the Eastern Woodlands' bark-bound
## splint and birch-bark torches). About 62 cm long, 0.5 kg.
##
##   var t := TorchModels.build()          # Node3D "TorchModel" with a Marker3D "Flame" at the top of the head
##   TorchModels.set_burn(t, 0.8, 0.3)     # ember glow of the head 0..1, how charred it is 0..1
##
## Conventions (as WeaponModels): origin = the grip (the middle of the fist), the head toward -Z (the model's
## forward), the butt toward +Z, up +Y. On the left hand prop bone (l_hand_prop_attachment, whose +Z runs out
## of the fist on the thumb side, the source's flashlight lens) HAND_OFFSET's half turn about Y puts the head
## out of the thumb side. Markers: Flame (the fire's base: the middle of the head's top), Head (the middle of
## the bound splints), Butt.
## One ShaderMaterial (shaders/torch/torch.gdshader: split pine, birch bark, charred splints with glowing
## embers); the part is in the vertex colour's red channel.

const LENGTH := 0.62          ## butt to the top of the head (m)
const GRIP_FROM_BUTT := 0.15  ## the fist's middle, from the butt
const HEAD_LEN := 0.2         ## the splint bundle
const SHAFT_R := 0.0165
const HEAD_R := 0.03
const MASS_KG := 0.5
## The model on l_hand_prop_attachment (see the header).
const HAND_OFFSET := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
const SHADER := "res://shaders/torch/torch.gdshader"


## A fresh torch model (its own material, so each torch burns on its own).
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "TorchModel"
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh()
	var mat := ShaderMaterial.new()
	mat.shader = shader()
	mi.material_override = mat
	# no shadow: the torch's own head sits right under its light, and its shadow blacked out the ground round the
	# player (the fire wraps the head; a real one does not shadow itself)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var z_top := -(LENGTH - GRIP_FROM_BUTT)
	for m in [["Flame", Vector3(0, 0, z_top + 0.03)], ["Head", Vector3(0, 0, z_top + HEAD_LEN * 0.5)],
			["Butt", Vector3(0, 0, GRIP_FROM_BUTT)]]:
		var mk := Marker3D.new()
		mk.name = m[0]
		mk.position = m[1]
		root.add_child(mk)
	return root


## The head's ember glow (0..1: out .. full fire) and char (0..1: fresh .. burnt down) on a model from build().
static func set_burn(model: Node3D, glow: float, char_amount: float) -> void:
	var mi := model.get_node_or_null("Mesh") as MeshInstance3D
	if mi == null or not (mi.material_override is ShaderMaterial):
		return
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter(&"glow", clampf(glow, 0.0, 1.0))
	m.set_shader_parameter(&"char_amount", clampf(char_amount, 0.0, 1.0))


static func shader() -> Shader:
	return load(SHADER) as Shader


## The torch's mesh (built per torch: about 1100 triangles; a static cache outlived the renderer at exit).
static func mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1758
	var z_butt := GRIP_FROM_BUTT
	var z_top := -(LENGTH - GRIP_FROM_BUTT)
	var z_head := z_top + HEAD_LEN
	# the stave: a split pitch-pine stick, an irregular eight-sided section (split faces), a slight bow, the
	# butt end trimmed at a slant; it runs up inside the head
	var rings: Array = []
	var n_rings := 12
	for i in n_rings + 1:
		var u := float(i) / n_rings
		var z := lerpf(z_butt, z_top + 0.02, u)
		var r := SHAFT_R * lerpf(1.08, 0.9, u) * (1.0 + 0.05 * sin(u * 23.0))
		var bow := Vector2(0.004 * sin(u * PI), 0.002 * sin(u * PI * 2.0))
		var ring: Array = []
		for k in 8:
			var a := TAU * (float(k) + 0.5) / 8.0
			var rr := r * (0.9 + 0.2 * _hash(float(k) * 7.1 + 3.0)) * (1.0 + 0.04 * sin(float(i) * 1.7 + float(k)))
			ring.append(Vector3(cos(a) * rr + bow.x, sin(a) * rr * 0.92 + bow.y, z))
		rings.append(ring)
	_tube(st, rings, 0.0, 0.0, 1.0)
	_cap(st, rings[0], Vector3(0, 0, 1), 0.0)
	# the head: fat-pine splints round the top of the stave, flared a little, uneven tops
	var n_spl := 9
	for s in n_spl:
		var a := TAU * (float(s) + rng.randf_range(-0.2, 0.2)) / n_spl
		var dir := Vector3(cos(a), sin(a), 0)
		var side := Vector3(-dir.y, dir.x, 0)
		var r0 := HEAD_R * rng.randf_range(0.7, 0.85)
		var r1 := HEAD_R * rng.randf_range(0.95, 1.15)
		var top := z_top + rng.randf_range(-0.012, 0.018)
		var w := rng.randf_range(0.009, 0.013)
		var t := rng.randf_range(0.006, 0.009)
		_splint(st, dir, side, r0, r1, z_head + 0.01, top, w, t)
	# a core of shorter splints inside the bundle
	for s in 4:
		var a := TAU * (float(s) + 0.5) / 4.0 + 0.3
		var dir := Vector3(cos(a), sin(a), 0)
		_splint(st, dir, Vector3(-dir.y, dir.x, 0), HEAD_R * 0.3, HEAD_R * 0.45, z_head, z_top - 0.01, 0.012, 0.008)
	# two bindings of birch bark
	for b in [z_head - 0.012, z_head - 0.075]:
		var band: Array = []
		for j in 2:
			var ring: Array = []
			for k in 14:
				var a := TAU * float(k) / 14.0
				var rr := HEAD_R * (0.98 if b < z_head - 0.05 else 0.92) + 0.004
				ring.append(Vector3(cos(a) * rr, sin(a) * rr, b - 0.009 + 0.018 * j))
			band.append(ring)
		_tube(st, band, 0.5, 0.0, 1.0)
	st.generate_normals()
	return st.commit()


## Quads between successive rings (each an array of points round the axis), vertex colour r = part.
static func _tube(st: SurfaceTool, rings: Array, part: float, v0: float, v1: float) -> void:
	var n: int = (rings[0] as Array).size()
	for i in rings.size() - 1:
		var ra: Array = rings[i]
		var rb: Array = rings[i + 1]
		var va := lerpf(v0, v1, float(i) / (rings.size() - 1))
		var vb := lerpf(v0, v1, float(i + 1) / (rings.size() - 1))
		for k in n:
			var k2 := (k + 1) % n
			var ua := float(k) / n
			var ub := float(k + 1) / n
			_tri(st, part, [ra[k], rb[k], rb[k2]], [Vector2(ua, va), Vector2(ua, vb), Vector2(ub, vb)])
			_tri(st, part, [ra[k], rb[k2], ra[k2]], [Vector2(ua, va), Vector2(ub, vb), Vector2(ub, va)])


static func _cap(st: SurfaceTool, ring: Array, _n: Vector3, part: float) -> void:
	var c := Vector3.ZERO
	for p: Vector3 in ring:
		c += p
	c /= ring.size()
	for k in ring.size():
		_tri(st, part, [c, ring[(k + 1) % ring.size()], ring[k]], [Vector2(0.5, 0), Vector2(0, 0), Vector2(1, 0)])


## One splint: a thin flat stick from z0 (bottom, radius r0 from the axis) to z1 (top, radius r1), `w` wide
## across `side`, `t` thick along `dir`; vertex colour r = 1 (head), the along-coordinate in UV.y.
static func _splint(st: SurfaceTool, dir: Vector3, side: Vector3, r0: float, r1: float, z0: float, z1: float,
		w: float, t: float) -> void:
	var rings: Array = []
	for j in 4:
		var u := float(j) / 3.0
		var z := lerpf(z0, z1, u)
		var r := lerpf(r0, r1, u * u)
		var c := dir * r + Vector3(0, 0, z)
		var ww := w * (1.0 - 0.25 * u)
		rings.append([c - side * ww * 0.5 - dir * t * 0.5, c + side * ww * 0.5 - dir * t * 0.5,
				c + side * ww * 0.5 + dir * t * 0.5, c - side * ww * 0.5 + dir * t * 0.5])
	_tube(st, rings, 1.0, 0.0, 1.0)
	_cap(st, rings[rings.size() - 1], Vector3(0, 0, -1), 1.0)


static func _tri(st: SurfaceTool, part: float, p: Array, uv: Array) -> void:
	for i in 3:
		var v: Vector3 = p[i]
		st.set_color(Color(part, clampf((GRIP_FROM_BUTT - v.z) / LENGTH, 0.0, 1.0), 0.0))
		st.set_uv(uv[i])
		st.add_vertex(v)


static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)
