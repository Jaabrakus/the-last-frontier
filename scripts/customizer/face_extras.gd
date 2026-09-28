class_name FaceExtras
extends RefCounted
## The character creator's facial hair volume and jewellery on a CharacterBodyMesh that wears
## the body.glb head (BodyMaterials.apply_look calls apply() last). The short hair of a style,
## scars, pox and paint are painted by the skin shader (BodyMaterials.skin_material sets them);
## this adds the geometry:
##
##   facial_hair  shells over the style's regions (beard_shell.gdshader): copies of the head's
##                triangles there, with the same skin weights and face shapes, built once per
##                style and shell count and shared by every body (the part's blend shape values
##                follow the head's on every apply)
##   jewellery    small silver, gold or stone pieces (creator.json "jewellery" items), rigid on
##                headb like the face; placed at the ear lobes, the ear rims, the septum or the
##                left nostril of the head as its face shapes are now (rebuilt on every apply)
##
## Stylized face style (BodyMaterials.is_stylized): the shells draw fewer, chunkier painted strands
## (beard_shell.gdshader `stylized`), and the jewellery is made a third larger with simpler, bolder
## forms (fewer segments) and a painted metal (broad soft highlight), so it reads at the game
## camera's distance like the painted head.
##
## Both are parts of the body (CharacterBodyMesh.parts: "facial_hair", "jewellery"), so
## remove_part, FaceBlink and the region hiding treat them like the glb parts. Look keys:
## facial_hair (CreatorOptions.facial_hair_style), jewellery (CreatorOptions.jewellery_items).

const SHELL_SHADER := preload("res://assets/character/shaders/beard_shell.gdshader")
const PART_BEARD := "facial_hair"
const PART_JEWELLERY := "jewellery"
## Shells per style (a full beard covers about 5.1k head triangles: 6 shells = 30k triangles,
## halved beyond the shader's lod_far; the fur budget is 40k per character).
const SHELLS_SHORT := 4
const SHELLS_LONG := 6
const METALS := {"silver": Color("#c8cacc"), "gold": Color("#c9a54b"), "brass": Color("#b58f4a")}
const STONES := {"pearl": Color("#ede6d6"), "garnet": Color("#6e1422"), "jade": Color("#5e8c62")}
## Stylized: strands per metre of the shells, the jewellery's scale.
const STYLIZED_STRANDS := 820.0
const STYLIZED_JEWELLERY := 1.32

## Segment scale of the jewellery primitives (the stylized pieces are simpler).
static var _seg := 1.0
## Shell meshes: "<source mesh id>:<style>:<shells>" -> ArrayMesh.
static var _shells := {}
## Landmark vertex indices of a head mesh: source mesh id -> {name: index}.
static var _marks := {}


static func apply(body: CharacterBodyMesh, look: Dictionary) -> void:
	if body == null:
		return
	var head := head_mesh(body)
	if head == null:
		body.remove_part(PART_BEARD)
		body.remove_part(PART_JEWELLERY)
		return
	_apply_beard(body, head, look)
	_apply_jewellery(body, head, look)


## The body.glb head: the mesh with the skin surface and the face shapes.
static func head_mesh(body: CharacterBodyMesh) -> MeshInstance3D:
	for mi: MeshInstance3D in body.meshes:
		if not is_instance_valid(mi) or not mi.mesh is ArrayMesh or mi.is_queued_for_deletion():
			continue
		if mi.find_blend_shape_by_name(&"face_breadth") < 0:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat and mat.resource_name == "skin":
				return mi
	return null


## Style region weights (moustache, chin, jaw / cheeks, side whiskers) of the look.
static func style_regions(look: Dictionary) -> Vector4:
	var st := CreatorOptions.facial_hair_style(look)
	var r: Array = st.get("regions", [])
	return Vector4(r[0], r[1], r[2], r[3]) if r.size() == 4 else Vector4.ZERO


static func _add_runtime_part(body: CharacterBodyMesh, tag: String, mesh: Mesh, skin: Skin) -> MeshInstance3D:
	body.remove_part(tag)
	var mi := MeshInstance3D.new()
	mi.name = tag
	mi.mesh = mesh
	mi.skin = skin
	mi.skeleton = NodePath("../..")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	body.meshes.append(mi)
	body.parts[tag] = [mi]
	return mi


# --- facial hair ---------------------------------------------------------------------------------

static func _apply_beard(body: CharacterBodyMesh, head: MeshInstance3D, look: Dictionary) -> void:
	var st := CreatorOptions.facial_hair_style(look)
	var reg := style_regions(look)
	var length := float(st.get("length", 0.0))
	if reg == Vector4.ZERO or length <= 0.0:
		body.remove_part(PART_BEARD)
		return
	var n := SHELLS_LONG if length > 0.009 else SHELLS_SHORT
	var mesh := shell_mesh(head.mesh as ArrayMesh, reg, n)
	var cur: Array = body.part_meshes(PART_BEARD)
	var mi: MeshInstance3D = cur[0] if not cur.is_empty() and is_instance_valid(cur[0]) else null
	if mi == null or mi.mesh != mesh:
		mi = _add_runtime_part(body, PART_BEARD, mesh, head.skin)
	var m := ShaderMaterial.new()
	m.shader = SHELL_SHADER
	var h: Dictionary = look.get("hair", {}) if look.get("hair") is Dictionary else {}
	var p := BodyMaterials.hair_preset(String(h.get("color", "dark_brown")))
	var eu := float(h.get("eumelanin", p.get("eumelanin", 4.0)))
	var ph := float(h.get("pheomelanin", p.get("pheomelanin", 0.4)))
	var grey := float(h.get("grey", p.get("grey", 0.0)))
	m.set_shader_parameter("style", reg)
	m.set_shader_parameter("length_m", length)
	m.set_shader_parameter("density", float(st.get("density", 1.0)))
	m.set_shader_parameter("hair_color", BodyMaterials.hair_color(eu * 0.95, ph * 1.1, 0.0))
	m.set_shader_parameter("grey", grey)
	m.set_shader_parameter("shells", n)
	m.set_shader_parameter("hide_mask", BodyMaterials.hide_mask(look.get("hide_regions", [])))
	BodyMaterials.set_face_warp(m)
	var sty := BodyMaterials.is_stylized(look)
	m.set_shader_parameter("stylized", 1 if sty else 0)
	if sty:
		m.set_shader_parameter("strands", STYLIZED_STRANDS)
	mi.material_override = m
	_copy_shapes(head, mi)


static func _copy_shapes(from: MeshInstance3D, to: MeshInstance3D) -> void:
	var n := mini(from.mesh.get_blend_shape_count(), to.mesh.get_blend_shape_count())
	for i in n:
		to.set_blend_shape_value(i, from.get_blend_shape_value(i))


## The CPU side of face_detail.gdshaderinc beard_regions() (without the mucosa and beard
## mask terms: it only picks the triangles the shader may draw on).
static func _band(x: float, a: float, b: float, f: float) -> float:
	return smoothstep(a - f, a + f, x) * (1.0 - smoothstep(b - f, b + f, x))


static func regions_at(u: float, h: float, beard_a: float) -> Vector4:
	var fc := BodyMaterials.warp_face_coords(u, h)
	h = fc.y
	var au := absf(fc.x)
	var lip_top := 1.4296 - 18.0 * au * au
	var mo := _band(au, -1.0, 0.0165, 0.0025) * _band(h, lip_top + 0.0012, 1.4412, 0.0011)
	mo = maxf(mo, _band(au, 0.0115, 0.0205, 0.0022) * _band(h, 1.4165, 1.437, 0.0022))
	var lip_bottom := 1.4113 + 25.0 * au * au
	var ch := _band(au, -1.0, 0.021, 0.004) * _band(h, 1.338, lip_bottom - 0.0016, 0.0018)
	var line := 1.438 + 0.32 * maxf(au - 0.03, 0.0)
	var cheek := _band(au, 0.03, 0.112, 0.006) * (1.0 - smoothstep(line - 0.003, line + 0.003, h)) * (1.0 if h >= 1.40 else 0.0)
	var jaw := maxf(beard_a, cheek)
	var sb := _band(au, 0.083, 0.109, 0.0035) * _band(h, 1.434, 1.506, 0.004)
	return Vector4(mo, ch, jaw, sb)


## Shell mesh of the head mesh `src` for the style regions `reg` (cached).
static func shell_mesh(src: ArrayMesh, reg: Vector4, n: int) -> ArrayMesh:
	var key := "%d:%s:%d" % [src.get_instance_id(), reg, n]
	if _shells.has(key):
		return _shells[key]
	var s := _skin_surface(src)
	var a := src.surface_get_arrays(s)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var col: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	# vertices the style may cover (head and upper neck only)
	var on := PackedByteArray()
	on.resize(v.size())
	for i in v.size():
		var r := int(uv2[i].x + 0.5) & 63
		if r > 1:
			continue
		var w := regions_at(uv[i].x, 1.0 - uv[i].y, col[i].a)
		if maxf(maxf(w.x * reg.x, w.y * reg.y), maxf(w.z * reg.z, w.w * reg.w)) > 0.0:
			on[i] = 1
	var remap := PackedInt32Array()
	remap.resize(v.size())
	remap.fill(-1)
	var used := PackedInt32Array()
	var tris := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		var i1 := idx[t + 1]
		var i2 := idx[t + 2]
		if on[i0] == 0 and on[i1] == 0 and on[i2] == 0:
			continue
		# a triangle across the head / neck border region is fine; one reaching the torso is not
		if (int(uv2[i0].x + 0.5) & 63) > 1 or (int(uv2[i1].x + 0.5) & 63) > 1 or (int(uv2[i2].x + 0.5) & 63) > 1:
			continue
		for vi in [i0, i1, i2]:
			if remap[vi] < 0:
				remap[vi] = used.size()
				used.append(vi)
			tris.append(remap[vi])
	var out := ArrayMesh.new()
	out.blend_shape_mode = src.blend_shape_mode
	if used.is_empty():
		_shells[key] = out
		return out
	var nb := src.get_blend_shape_count()
	for b in nb:
		out.add_blend_shape(src.get_blend_shape_name(b))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	# no tangents: the shell shader has no normal map
	var per_vertex := {Mesh.ARRAY_VERTEX: 1, Mesh.ARRAY_NORMAL: 1, Mesh.ARRAY_TEX_UV: 1, Mesh.ARRAY_COLOR: 1,
			Mesh.ARRAY_BONES: 4, Mesh.ARRAY_WEIGHTS: 4}
	for k: int in per_vertex:
		if a[k] == null:
			continue
		var sub = _gather(a[k], used, per_vertex[k])
		arrays[k] = _tile(sub, n)
	# UV2: region code kept, y = shell height k / n
	var u2 := PackedVector2Array()
	for k in range(1, n + 1):
		for vi in used:
			u2.append(Vector2(uv2[vi].x, float(k) / float(n)))
	arrays[Mesh.ARRAY_TEX_UV2] = u2
	var ind := PackedInt32Array()
	for k in n:
		var off := k * used.size()
		for t in tris:
			ind.append(t + off)
	arrays[Mesh.ARRAY_INDEX] = ind
	var blends := []
	var bs := src.surface_get_blend_shape_arrays(s)
	for b in bs.size():
		var ba := []
		ba.resize(Mesh.ARRAY_MAX)
		for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
			if bs[b][k] != null:
				ba[k] = _tile(_gather(bs[b][k], used, 1), n)
		blends.append(ba)
	var flags := src.surface_get_format(s) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blends, {}, flags)
	out.surface_set_name(0, "facial_hair")
	_shells[key] = out
	return out


static func _gather(src, used: PackedInt32Array, stride: int):
	var out = src.duplicate()
	out.resize(used.size() * stride)
	var j := 0
	for vi in used:
		for c in stride:
			out[j] = src[vi * stride + c]
			j += 1
	return out


static func _tile(sub, n: int):
	var out = sub.duplicate()
	for k in n - 1:
		out.append_array(sub)
	return out


# --- jewellery -----------------------------------------------------------------------------------

static func _apply_jewellery(body: CharacterBodyMesh, head: MeshInstance3D, look: Dictionary) -> void:
	var items := CreatorOptions.jewellery_items(look)
	var bind := _bind_of(head.skin, body.skeleton, "headb")
	if items.is_empty() or bind < 0:
		body.remove_part(PART_JEWELLERY)
		return
	var lm := landmarks(head)
	var sty := BodyMaterials.is_stylized(look)
	_seg = 0.6 if sty else 1.0
	# colour -> {"v": positions, "n": normals, "metal": bool}
	var groups := {}
	for it: Dictionary in items:
		var mcol: Color = METALS.get(String(it.get("metal", "silver")), METALS.silver)
		var scol: Color = STONES.get(String(it.get("stone", "")), mcol)
		for p: Array in _anchors(lm, String(it.get("at", "ears"))):
			var g0 := {"v": [], "n": []}
			var g1 := {"v": [], "n": []}
			_piece(String(it.get("kind", "stud")), p[0], p[1], float(it.get("size", 1.0)), g0, g1)
			if sty:
				# bolder: a third larger about the pierced point
				for g: Dictionary in [g0, g1]:
					var vv: Array = g.v
					for i in vv.size():
						vv[i] = p[0] + ((vv[i] as Vector3) - p[0]) * STYLIZED_JEWELLERY
			for pair: Array in [[g0, _group(groups, mcol, true)], [g1, _group(groups, scol, scol == mcol)]]:
				(pair[1].v as Array).append_array(pair[0].v)
				(pair[1].n as Array).append_array(pair[0].n)
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	for c: Color in groups:
		var g: Dictionary = groups[c]
		var v: Array = g.v
		if v.is_empty():
			continue
		var nrm: Array = g.n
		st.clear()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in v.size():
			st.set_normal(nrm[i])
			st.set_bones(PackedInt32Array([bind, 0, 0, 0]))
			st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			st.add_vertex(v[i])
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.metallic = 1.0 if g.metal else 0.0
		m.roughness = 0.3 if g.metal else (0.22 if c == STONES.pearl else 0.35)
		if sty:
			# painted metal: less mirror, a broad soft highlight, a little of the colour in the shade
			m.metallic = 0.75 if g.metal else 0.0
			m.roughness = 0.42 if g.metal else 0.38
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.6
		if not g.metal and c == STONES.pearl:
			m.clearcoat_enabled = true
			m.clearcoat = 0.6
		st.set_material(m)
		st.commit(mesh)
	var cur: Array = body.part_meshes(PART_JEWELLERY)
	if not cur.is_empty() and is_instance_valid(cur[0]):
		(cur[0] as MeshInstance3D).mesh = mesh
	else:
		_add_runtime_part(body, PART_JEWELLERY, mesh, head.skin)


static func _group(groups: Dictionary, c: Color, metal: bool) -> Dictionary:
	if not groups.has(c):
		# Arrays, not packed arrays: a packed array read from a Dictionary is a copy
		groups[c] = {"v": [], "n": [], "metal": metal}
	return groups[c]


static func _bind_of(skin: Skin, sk: Skeleton3D, bone: String) -> int:
	if skin == null or sk == null:
		return -1
	var b := sk.find_bone(bone)
	for i in skin.get_bind_count():
		if skin.get_bind_bone(i) == b or String(skin.get_bind_name(i)) == bone:
			return i
	return -1


## Landmarks of the head mesh `src`, found once on the default head: name -> [bind position,
## PackedVector3Array of the offset per blend shape at weight 1]. ear_l / ear_r: the lowest
## point of the lobe; rim_l1, rim_l2 / rim_r1, rim_r2: the lobe and helix edge 9 and 18 mm
## higher; septum: the columella above the nose base; nostril_l: the outer face of the left ala.
static func landmark_data(src: ArrayMesh) -> Dictionary:
	var key := src.get_instance_id()
	if _marks.has(key):
		return _marks[key]
	var s := _skin_surface(src)
	var a := src.surface_get_arrays(s)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var ids := {}
	for side: float in [1.0, -1.0]:
		var sd := "l" if side > 0.0 else "r"
		var lobe := -1
		for i in v.size():
			if (int(uv2[i].x + 0.5) & 63) != 0:
				continue
			var p := v[i]
			if p.x * side > 0.066 and p.y < 1.45 and p.z > -0.03 and p.z < 0.04:
				if lobe < 0 or p.y < v[lobe].y:
					lobe = i
		if lobe < 0:
			continue
		ids["ear_" + sd] = lobe
		for k: int in [1, 2]:
			var y := v[lobe].y + 0.009 * k
			var best := -1
			var bd := -1.0
			for i in v.size():
				var p := v[i]
				if absf(p.y - y) < 0.0025 and p.x * side > 0.066 and p.z > -0.035 and p.z < 0.04:
					var d := p.x * side - 0.25 * absf(p.z - v[lobe].z)
					if d > bd:
						bd = d
						best = i
			if best >= 0:
				ids["rim_%s%d" % [sd, k]] = best
	ids["septum"] = _nearest(v, Vector3(0.0, 1.4445, 0.132))
	# the side of the left ala, above the alar crease (the ala ends at x 0.016-0.018)
	ids["nostril_l"] = _nearest(v, Vector3(0.015, 1.447, 0.128))
	# the v3 head (2026-09-27): its places measured at build time (body.json face.landmarks)
	var blm: Dictionary = (BodyMaterials.body_info().get("face", {}) as Dictionary).get("landmarks", {})
	for k: String in blm:
		if blm[k] is Array and (blm[k] as Array).size() == 3:
			ids[k] = _nearest(v, Vector3(blm[k][0], blm[k][1], blm[k][2]))
	var bs := src.surface_get_blend_shape_arrays(s)
	var relative := src.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE
	var out := {}
	for k: String in ids:
		var i := int(ids[k])
		var d := PackedVector3Array()
		for b in bs.size():
			var t: Vector3 = (bs[b][Mesh.ARRAY_VERTEX] as PackedVector3Array)[i]
			d.append(t if relative else t - v[i])
		out[k] = [v[i], d]
	_marks[key] = out
	return out


static func _skin_surface(src: ArrayMesh) -> int:
	for i in src.get_surface_count():
		var mat := src.surface_get_material(i)
		if mat and mat.resource_name == "skin":
			return i
	return 0


static func _nearest(v: PackedVector3Array, q: Vector3) -> int:
	var best := -1
	var bd := INF
	for i in v.size():
		var d := v[i].distance_squared_to(q)
		if d < bd:
			bd = d
			best = i
	return best


## Landmark positions of `head` as its face shapes are now (bind space): name -> Vector3.
static func landmarks(head: MeshInstance3D) -> Dictionary:
	var data := landmark_data(head.mesh as ArrayMesh)
	var out := {}
	for k: String in data:
		var p: Vector3 = data[k][0]
		var d: PackedVector3Array = data[k][1]
		for b in d.size():
			var w := head.get_blend_shape_value(b)
			if absf(w) > 1e-4:
				p += w * d[b]
		out[k] = p
	return out


## [position, outward direction] pairs of an item's place.
static func _anchors(lm: Dictionary, at: String) -> Array:
	var out := []
	match at:
		"ears", "ear_l", "ear_r":
			for sd in (["l", "r"] if at == "ears" else [at.substr(4)]):
				if lm.has("ear_" + sd):
					out.append([lm["ear_" + sd] + Vector3(0.0, 0.0035, 0.0), Vector3(1.0 if sd == "l" else -1.0, 0.0, 0.0)])
		"ear_rims":
			for sd in ["l", "r"]:
				var o := Vector3(1.0 if sd == "l" else -1.0, 0.0, 0.0)
				if lm.has("ear_" + sd):
					out.append([lm["ear_" + sd] + Vector3(0.0, 0.0035, 0.0), o])
				for k: int in [1, 2]:
					if lm.has("rim_%s%d" % [sd, k]):
						out.append([lm["rim_%s%d" % [sd, k]] - o * 0.002, o])
		"septum":
			if lm.has("septum"):
				out.append([lm.septum, Vector3(0.0, 0.0, 1.0)])
		"nostril_l":
			if lm.has("nostril_l"):
				out.append([lm.nostril_l, Vector3(0.85, 0.0, 0.5).normalized()])
	return out


## Adds the triangles of a piece at `p` (the pierced point, bind space) with the outward
## direction `o` to the metal and stone groups ({"v", "n"}).
static func _piece(kind: String, p: Vector3, o: Vector3, size: float, metal: Dictionary, stone: Dictionary) -> void:
	match kind:
		"bob":
			# ball-and-cone: a wire loop through the lobe, a ball, a cone point down
			_torus(metal, p + Vector3(0, -0.002, 0), o, 0.0032, 0.0006)
			_sphere(metal, p + Vector3(0, -0.0072, 0) + o * 0.0008, 0.0022)
			_cone(metal, p + Vector3(0, -0.009, 0) + o * 0.0008, Vector3.DOWN, 0.0026, 0.009)
		"hoop":
			var r := 0.0085 * size
			_torus(metal, p + Vector3(0, -r + 0.0025, 0), o, r, 0.0007 * maxf(size, 0.7))
		"stud":
			_sphere(metal, p + o * 0.0016, 0.0018 * size)
		"drop":
			_torus(metal, p + Vector3(0, -0.0015, 0), o, 0.0025, 0.0005)
			_cylinder(metal, p + Vector3(0, -0.004, 0) + o * 0.0008, p + Vector3(0, -0.008, 0) + o * 0.0008, 0.0004)
			_sphere(stone, p + Vector3(0, -0.0105, 0) + o * 0.0008, 0.0029 * size)
		"septum":
			_torus(metal, p + Vector3(0, -0.0025, 0.001), Vector3.RIGHT, 0.0028, 0.0005)
			_cone(metal, p + Vector3(0, -0.0052, 0.0025), Vector3.DOWN, 0.0022, 0.0065)


static func _frame(o: Vector3) -> Array:
	var n := o.normalized()
	var t := n.cross(Vector3.UP)
	if t.length() < 1e-3:
		t = n.cross(Vector3.RIGHT)
	t = t.normalized()
	return [n, t, n.cross(t).normalized()]


static func _quad(g: Dictionary, p: Array, n: Array) -> void:
	(g.v as Array).append_array([p[0], p[1], p[2], p[0], p[2], p[3]])
	(g.n as Array).append_array([n[0], n[1], n[2], n[0], n[2], n[3]])


static func _sphere(g: Dictionary, c: Vector3, r: float, seg0 := 10, rings0 := 7) -> void:
	var seg := maxi(int(round(seg0 * _seg)), 6)
	var rings := maxi(int(round(rings0 * _seg)), 4)
	var dir := func(j: int, i: int) -> Vector3:
		var a := PI * j / rings
		var b := TAU * i / seg
		return Vector3(sin(a) * cos(b), cos(a), sin(a) * sin(b))
	for j in rings:
		for i in seg:
			var d: Array = [dir.call(j, i), dir.call(j, i + 1), dir.call(j + 1, i + 1), dir.call(j + 1, i)]
			_quad(g, d.map(func(x: Vector3) -> Vector3: return c + x * r), d)


## Torus in the plane normal to `axis` (a ring through the ear lobe: axis = outward).
static func _torus(g: Dictionary, c: Vector3, axis: Vector3, r: float, tube: float, seg0 := 18, sides0 := 6) -> void:
	var seg := maxi(int(round(seg0 * _seg)), 8)
	var sides := maxi(int(round(sides0 * _seg)), 4)
	var f := _frame(axis)
	var n: Vector3 = f[0]
	var t: Vector3 = f[1]
	var b: Vector3 = f[2]
	var at := func(i: int, j: int) -> Array:
		var a := TAU * i / seg
		var s := TAU * j / sides
		var d := t * cos(a) + b * sin(a)
		var nn := d * cos(s) + n * sin(s)
		return [c + d * r + nn * tube, nn]
	for i in seg:
		for j in sides:
			var q: Array = [at.call(i, j), at.call(i + 1, j), at.call(i + 1, j + 1), at.call(i, j + 1)]
			_quad(g, q.map(func(x: Array) -> Vector3: return x[0]), q.map(func(x: Array) -> Vector3: return x[1]))


static func _cone(g: Dictionary, base: Vector3, dir: Vector3, r: float, h: float, seg := 10) -> void:
	var f := _frame(dir)
	var ax: Vector3 = f[0]
	var tip := base + ax * h
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := (f[1] as Vector3) * cos(a0) + (f[2] as Vector3) * sin(a0)
		var d1 := (f[1] as Vector3) * cos(a1) + (f[2] as Vector3) * sin(a1)
		var k := r / h
		var n0 := (d0 + ax * k).normalized()
		var n1 := (d1 + ax * k).normalized()
		(g.v as Array).append_array([base + d0 * r, base + d1 * r, tip, base + d1 * r, base + d0 * r, base])
		(g.n as Array).append_array([n0, n1, (n0 + n1).normalized(), -ax, -ax, -ax])


static func _cylinder(g: Dictionary, a: Vector3, b: Vector3, r: float, seg := 6) -> void:
	var f := _frame(b - a)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := (f[1] as Vector3) * cos(a0) + (f[2] as Vector3) * sin(a0)
		var d1 := (f[1] as Vector3) * cos(a1) + (f[2] as Vector3) * sin(a1)
		_quad(g, [a + d0 * r, b + d0 * r, b + d1 * r, a + d1 * r], [d0, d0, d1, d1])
