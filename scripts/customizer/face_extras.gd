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
##   jewellery    our own simple procedural pieces in silver, gold, brass, bone, pearl, coral,
##                amber, glass, cord and ribbon (MATERIALS; creator.json "jewellery" items), the
##                pieces of every jewellery row worn together (CreatorOptions.jewellery_items:
##                Earrings, Nose, Neck, Rings), rebuilt on every apply:
##                  ears, nose  rigid on headb like the face, at the ear lobes, the ear rims, the
##                              septum or a nostril of the head as its face shapes are now
##                              (landmarks): studs, hoops, drops, ear bobs, nose studs and rings,
##                              septum rings, a septum pin
##                  neck        strands (beads, a chain, a cord, a ribbon) laid round the neck over
##                              the skin and whatever the body wears there (the shirt, a stock, the
##                              waistcoat, a coat's collar; not the hat): each of NECK_RAYS level rays
##                              from the neck's axis, at the strand's height in its direction (a U, or
##                              a V under a pendant), meets the first layers it leaves and the strand
##                              lies just outside the outermost (_strand_loop, cached per body state);
##                              each point skinned like the skin vertex under it, so the strand
##                              follows the neck, the chest and the bust gauge; a pendant at the
##                              front (a cross, a locket, a disc, a bone tooth) rests on the chest
##                              below it; a gorget's crescent hangs at the throat from its horns
##                  hands       rings on the finger bones (FINGERS), sized to the finger as the
##                              body's shapes are now; none on a gloved hand (hide_regions)
##
## Stylized face style (BodyMaterials.is_stylized): the shells draw fewer, chunkier painted strands
## (beard_shell.gdshader `stylized`), and the ear and nose pieces are made a third larger with
## simpler, bolder forms (fewer segments) and a painted metal (broad soft highlight), so they read
## at the game camera's distance like the painted head.
##
## The pieces are built as one mesh per material, every triangle wound to face its normal's side
## (the materials draw both sides: a back face is lit as seen from inside).
##
## Both are parts of the body (CharacterBodyMesh.parts: "facial_hair", "jewellery"), so
## remove_part, FaceBlink and the region hiding treat them like the glb parts. Look keys:
## facial_hair (CreatorOptions.facial_hair_style); jewel_ears, jewel_nose, jewel_neck, jewel_hands
## (or a saved look's single jewellery id; CreatorOptions.jewellery_items).

const SHELL_SHADER := preload("res://assets/character/shaders/beard_shell.gdshader")
const PART_BEARD := "facial_hair"
const PART_JEWELLERY := "jewellery"
## Shells per style (a full beard covers about 5.1k head triangles: 6 shells = 30k triangles,
## halved beyond the shader's lod_far; the fur budget is 40k per character).
const SHELLS_SHORT := 4
const SHELLS_LONG := 6
const METALS := {"silver": Color("#c8cacc"), "gold": Color("#c9a54b"), "brass": Color("#b58f4a")}
const STONES := {"pearl": Color("#ede6d6"), "garnet": Color("#6e1422"), "jade": Color("#5e8c62")}
## The jewellery's materials (an item's metal, stone, beads, cord or ribbon): colour, metal or not,
## roughness, clearcoat. The metals and stones above keep their colours.
const MATERIALS := {
	"silver": {"color": "#c8cacc", "metal": true},
	"gold": {"color": "#c9a54b", "metal": true},
	"brass": {"color": "#b58f4a", "metal": true},
	"pearl": {"color": "#ede6d6", "rough": 0.22, "coat": 0.6},
	"garnet": {"color": "#6e1422"},
	"jade": {"color": "#5e8c62"},
	"coral": {"color": "#c0503a", "rough": 0.42},
	"amber": {"color": "#b5651d", "rough": 0.22, "coat": 0.5},
	"bone": {"color": "#ded2b6", "rough": 0.62},
	"glass_blue": {"color": "#2a4a94", "rough": 0.12, "coat": 0.8},
	"glass_white": {"color": "#e4e0d2", "rough": 0.18, "coat": 0.6},
	"glass_red": {"color": "#8e1c1f", "rough": 0.12, "coat": 0.8},
	"glass_black": {"color": "#18161b", "rough": 0.1, "coat": 0.8},
	"cord": {"color": "#5b4630", "rough": 0.95},
	"ribbon": {"color": "#17151a", "rough": 0.6},
}
## Rings: an item's `at` -> [the finger's first bone, the next joint's bone, the back of the hand's
## side (+x left, -x right in the bind pose)].
const FINGERS := {
	"ring_l": ["l_ringa", "l_ringb", 1.0], "ring_r": ["r_ringa", "r_ringb", -1.0],
	"middle_l": ["l_middlea", "l_middleb", 1.0], "middle_r": ["r_middlea", "r_middleb", -1.0],
	"index_l": ["l_indexa", "l_indexb", 1.0], "index_r": ["r_indexa", "r_indexb", -1.0],
	"pinky_l": ["l_pinkyb", "l_pinkyc", 1.0], "pinky_r": ["r_pinkyb", "r_pinkyc", -1.0],
}
## The neck pieces: rays round the neck; the heights (bind space) and half width of the skin and
## garment vertices a strand may rest on; garment parts it never rests on; layers within LAYER_GAP
## of the first surface a ray leaves are worn over it; the rays start NECK_PIVOT above the neck bone.
const NECK_RAYS := 64
const NECK_BAND := Vector2(1.02, 1.47)
const NECK_HALF_X := 0.2
const NECK_SKIP := ["outfit:head"]
const LAYER_GAP := 0.035
const NECK_PIVOT := 0.045
## A gorget: width, depth at the middle, thickness, the radius it is bent to round the chest, the boss's half width.
const GORGET := {"w": 0.096, "h": 0.054, "th": 0.0016, "bend": 0.16, "boss": 0.0085}
## The ear lobe's piercing: its ray passes this far (side-mirrored x, y, z) from the lobe's lowest point (the lobe's
## middle 5 mm up), along (0.6 side, 0, 0.8) (the lobe's flap faces forward and out).
const LOBE_PIERCE := Vector3(0.0085, 0.005, 0.0012)
## The landmark data's key of the surface directions at the ray-found landmarks (landmark_dirs).
const DIRS := "_dirs"
## Stylized: strands per metre of the shells, the jewellery's scale.
const STYLIZED_STRANDS := 820.0
const STYLIZED_JEWELLERY := 1.32

## Segment scale of the jewellery primitives (the stylized pieces are simpler).
static var _seg := 1.0
## Shell meshes: "<source mesh id>:<style>:<shells>" -> ArrayMesh.
static var _shells := {}
## Landmarks of a head mesh: source mesh id -> {name: [position, offsets per shape]}.
static var _marks := {}
## The neck bands of mesh surfaces ("<mesh id>:<surface>"), the strands' loops (per body state and
## strand), the finger vertices of a head mesh (mesh id -> bind -> data), the jewellery materials.
static var _bands := {}
static var _loops := {}
static var _fingers := {}
static var _mats := {}


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

## The look's pieces (CreatorOptions.jewellery_items: the Earrings, Nose, Neck and Rings rows together) as one part,
## one surface per material: the ear and nose pieces rigid on headb at the face's landmarks, the neck pieces laid over
## the skin and the clothes round the neck (skinned like the skin under them), the rings on their finger bones.
static func _apply_jewellery(body: CharacterBodyMesh, head: MeshInstance3D, look: Dictionary) -> void:
	var items := CreatorOptions.jewellery_items(look)
	var bind := _bind_of(head.skin, body.skeleton, "headb")
	if items.is_empty() or bind < 0:
		body.remove_part(PART_JEWELLERY)
		return
	_skin_data(head.mesh as ArrayMesh, head.skin, body.skeleton)
	var sty := BodyMaterials.is_stylized(look)
	_seg = 0.6 if sty else 1.0
	var hidden: Array = look.get("hide_regions", []) if look.get("hide_regions") is Array else []
	var ctx := {"body": body, "head": head, "groups": {}, "skins": [], "hidden": hidden, "neck": {}}
	var head_sid := _skin_id(ctx, PackedInt32Array([bind, 0, 0, 0]), PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	var lm := {}
	var dirs := {}
	for it: Dictionary in items:
		var at := String(it.get("at", "ears"))
		match String(CreatorOptions.JEWEL_AT.get(at, "ears")):
			"neck":
				_neck_piece(ctx, it)
				continue
			"hands":
				_ring_piece(ctx, it)
				continue
		if lm.is_empty():
			lm = landmarks(head)
			dirs = landmark_dirs(head)
		var metal := String(it.get("metal", "silver"))
		var g0 := _group_of(ctx, metal)
		var g1 := _group_of(ctx, String(it.get("stone", metal)))
		for an: Dictionary in _anchors(lm, dirs, at):
			var n0 := (g0.v as Array).size()
			var n1 := (g1.v as Array).size()
			var c := _piece(String(it.get("kind", "stud")), an, float(it.get("size", 1.0)), g0, g1, it)
			if sty:
				# bolder: a third larger about the pierced point (a stud's place on the skin)
				# (a piece without a stone: one group, scaled once)
				for pair: Array in ([[g0, n0]] if is_same(g0, g1) else [[g0, n0], [g1, n1]]):
					var vv: Array = pair[0].v
					for i in range(int(pair[1]), vv.size()):
						vv[i] = c + ((vv[i] as Vector3) - c) * STYLIZED_JEWELLERY
			_mark(g0, head_sid)
			_mark(g1, head_sid)
	var mesh := _build_mesh(ctx, sty)
	if mesh.get_surface_count() == 0:
		body.remove_part(PART_JEWELLERY)
		return
	var cur: Array = body.part_meshes(PART_JEWELLERY)
	if not cur.is_empty() and is_instance_valid(cur[0]) and not (cur[0] as Node).is_queued_for_deletion():
		(cur[0] as MeshInstance3D).mesh = mesh
	else:
		_add_runtime_part(body, PART_JEWELLERY, mesh, head.skin)


## The material group (vertices, normals, skin ids per vertex) of `mat` (a MATERIALS name).
static func _group_of(ctx: Dictionary, mat: String) -> Dictionary:
	var groups: Dictionary = ctx.groups
	if not groups.has(mat):
		# Arrays, not packed arrays: a packed array read from a Dictionary is a copy
		groups[mat] = {"v": [], "n": [], "s": []}
	return groups[mat]


## The vertices added to `g` since its last mark take the skin `sid`.
static func _mark(g: Dictionary, sid: int) -> void:
	var s: Array = g.s
	var n := (g.v as Array).size()
	var old := s.size()
	if n > old:
		s.resize(n)
		for i in range(old, n):
			s[i] = sid


static func _skin_id(ctx: Dictionary, bones: PackedInt32Array, weights: PackedFloat32Array) -> int:
	var skins: Array = ctx.skins
	skins.append([bones, weights])
	return skins.size() - 1


static func _build_mesh(ctx: Dictionary, sty: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var skins: Array = ctx.skins
	for mat: String in ctx.groups:
		var g: Dictionary = ctx.groups[mat]
		var n := (g.v as Array).size()
		if n == 0:
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var pv := PackedVector3Array(g.v)
		var pn := PackedVector3Array(g.n)
		var s: Array = g.s
		# every triangle wound front-facing (Godot: clockwise seen from its normal's side): the material draws both
		# sides and turns the normal of a back face, so a triangle wound the other way is lit from inside (dark)
		for t in range(0, n - 2, 3):
			if (pv[t + 1] - pv[t]).cross(pv[t + 2] - pv[t]).dot(pn[t] + pn[t + 1] + pn[t + 2]) > 0.0:
				var q := pv[t + 1]
				pv[t + 1] = pv[t + 2]
				pv[t + 2] = q
				q = pn[t + 1]
				pn[t + 1] = pn[t + 2]
				pn[t + 2] = q
				var k = s[t + 1]
				s[t + 1] = s[t + 2]
				s[t + 2] = k
		arrays[Mesh.ARRAY_VERTEX] = pv
		arrays[Mesh.ARRAY_NORMAL] = pn
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		for i in n:
			var sk: Array = skins[s[i]]
			bones.append_array(sk[0])
			weights.append_array(sk[1])
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var si := mesh.get_surface_count() - 1
		mesh.surface_set_material(si, _material(mat, sty))
		mesh.surface_set_name(si, mat)
	return mesh


## The StandardMaterial3D of a MATERIALS name (shared by every body).
static func _material(name: String, sty: bool) -> StandardMaterial3D:
	var key := "%s:%d" % [name, int(sty)]
	if _mats.has(key):
		return _mats[key]
	var d: Dictionary = MATERIALS.get(name, MATERIALS.silver)
	var metal := bool(d.get("metal", false))
	var m := StandardMaterial3D.new()
	m.resource_name = "jewellery_" + name
	m.albedo_color = Color(String(d.color))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 1.0 if metal else 0.0
	m.roughness = 0.3 if metal else float(d.get("rough", 0.35))
	if sty:
		# painted metal: less mirror, a broad soft highlight, a little of the colour in the shade
		m.metallic = 0.75 if metal else 0.0
		m.roughness = 0.42 if metal else maxf(float(d.get("rough", 0.38)), 0.38)
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.6
	if d.has("coat"):
		m.clearcoat_enabled = true
		m.clearcoat = float(d.coat)
	_mats[key] = m
	return m


static func _bind_of(skin: Skin, sk: Skeleton3D, bone: String) -> int:
	if skin == null or sk == null:
		return -1
	var b := sk.find_bone(bone)
	for i in skin.get_bind_count():
		if skin.get_bind_bone(i) == b or String(skin.get_bind_name(i)) == bone:
			return i
	return -1


## The bind-space position of a bind's bone (the skin's rest).
static func _bind_origin(skin: Skin, bind: int) -> Vector3:
	return skin.get_bind_pose(bind).affine_inverse().origin


## Landmarks of the head mesh `src`, found once on the default head: name -> [bind position,
## PackedVector3Array of the offset per blend shape at weight 1]. ear_l / ear_r: the lowest
## point of the lobe; rim_l1, rim_l2 / rim_r1, rim_r2: the lobe and helix edge 9 and 18 mm
## higher; septum, nostril_l (body.json face.landmarks), nostril_r (mirrored); found by rays on the surface (the
## pieces' places): lobe_l / lobe_r, the middle of the lobe's flesh where it is pierced, lobe_front_l / _r its front
## face there (a stud); columella, the underside of the septum between the nostrils; ala_l / ala_r, the outer face of
## each ala. DIRS: {name: the surface's outward normal there (lobe_*: the piercing's direction)}.
static func landmark_data(src: ArrayMesh) -> Dictionary:
	var key := src.get_instance_id()
	if not _marks.has(key):
		_skin_data(src, null, null)
	return _marks.get(key, {})


## One pass over the skin surface of the head mesh `src` (its arrays and blend shapes are large: they are read once):
## the landmarks (landmark_data), the neck band the strands rest on (_band_of) and, with the skin and skeleton, the
## vertices of the finger bones the rings sit on (_fingers).
static func _skin_data(src: ArrayMesh, skin: Skin, sk: Skeleton3D) -> void:
	var key := src.get_instance_id()
	var s := _skin_surface(src)
	var bkey := "%d:%d" % [key, s]
	var need_marks := not _marks.has(key)
	var need_band: bool = not _bands.has(bkey) or (_bands[bkey].ref as WeakRef).get_ref() != src
	var need_fingers := skin != null and sk != null and not _fingers.has(key)
	if not need_marks and not need_band and not need_fingers:
		return
	var a := src.surface_get_arrays(s)
	var bs := src.surface_get_blend_shape_arrays(s)
	var relative := src.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE
	if need_marks:
		_marks[key] = _landmarks_from(a, bs, relative)
	if need_band:
		_bands[bkey] = _band_from(src, a, bs, relative, true)
	if need_fingers:
		var binds := []
		for f: Array in FINGERS.values():
			var bi := _bind_of(skin, sk, String(f[0]))
			if bi >= 0:
				binds.append(bi)
		_fingers[key] = _fingers_from(a, bs, relative, binds)


static func _landmarks_from(a: Array, bs: Array, relative: bool) -> Dictionary:
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
	# the right ala: the left one mirrored (the head is symmetric)
	if not blm.has("nostril_r"):
		var q := v[int(ids.nostril_l)]
		ids["nostril_r"] = _nearest(v, Vector3(-q.x, q.y, q.z))
	# the piercings found on the surface itself by rays (body.json's septum is the nose's tip, its nostril_l lies on the
	# cheek beside the ala, and its lobe point is the lobe's root on the cheek, inside the flesh: a stud there is hidden):
	#   lobe_l / lobe_r         the middle of the lobe's flesh 5 mm above its lowest point, half way between its front
	#                           and back faces along the piercing (LOBE_PIERCE); lobe_front_*: the front face there
	#   columella               the underside of the septum between the nostrils, a little behind the tip
	#   ala_l / ala_r           the outer face of each ala 30 degrees in front of the side, at the tip's height
	# each a point of a triangle of the surface (its three vertices' weights), so the face shapes carry it
	var dirs := {}
	var tris := _face_tris(a)
	var tip := -1
	for i in v.size():
		var p := v[i]
		if (int(uv2[i].x + 0.5) & 63) == 0 and absf(p.x) < 0.002 and p.y > 1.42 and p.y < 1.47 and p.z > 0.09 and (tip < 0 or p.z > v[tip].z):
			tip = i
	for side: float in [1.0, -1.0]:
		var sd := "l" if side > 0.0 else "r"
		if not ids.has("ear_" + sd):
			continue
		var c := v[int(ids["ear_" + sd])] + Vector3(side * LOBE_PIERCE.x, LOBE_PIERCE.y, LOBE_PIERCE.z)
		var pd := Vector3(side * 0.6, 0.0, 0.8)
		var hs := _ray_hits(v, tris, c + pd * 0.04, -pd)
		if hs.size() >= 2 and float(hs[1][0]) - float(hs[0][0]) < 0.02:
			ids["lobe_front_" + sd] = hs[0][1]
			ids["lobe_" + sd] = _mix(hs[0][1], hs[1][1], 0.5)
			dirs["lobe_front_" + sd] = hs[0][2]
			dirs["lobe_" + sd] = pd
	if tip >= 0:
		var tp := v[tip]
		var hs := _ray_hits(v, tris, Vector3(0.0, tp.y - 0.016, tp.z - 0.0055), Vector3.UP)
		if not hs.is_empty() and float(hs[0][0]) < 0.02:
			ids["columella"] = hs[0][1]
			dirs["columella"] = hs[0][2]
		for side: float in [1.0, -1.0]:
			var d := -Vector3(side * cos(PI / 6.0), 0.0, sin(PI / 6.0))
			var c := Vector3(0.0, tp.y - 0.001, tp.z - 0.02)
			hs = _ray_hits(v, tris, c - d * 0.06, d)
			if not hs.is_empty():
				var k := "ala_l" if side > 0.0 else "ala_r"
				ids[k] = hs[0][1]
				dirs[k] = hs[0][2]
	var out := {}
	for k: String in ids:
		# a vertex, [vertex a, vertex b, f] (the point f of the way from a to b) or [[vertex, weight], ...]
		var e: Array = _weights(ids[k])
		var p := Vector3.ZERO
		for vw: Array in e:
			p += v[int(vw[0])] * float(vw[1])
		var d := PackedVector3Array()
		for b in bs.size():
			var t: PackedVector3Array = bs[b][Mesh.ARRAY_VERTEX]
			var dv := Vector3.ZERO
			for vw: Array in e:
				var i := int(vw[0])
				dv += (t[i] if relative else t[i] - v[i]) * float(vw[1])
			d.append(dv)
		out[k] = [p, d]
	out[DIRS] = dirs
	return out


## A landmark entry as [[vertex, weight], ...] (a vertex, [vertex a, vertex b, f], or already weights).
static func _weights(e) -> Array:
	if not e is Array:
		return [[int(e), 1.0]]
	var a: Array = e
	if a.size() == 3 and not a[0] is Array:
		return [[int(a[0]), 1.0 - float(a[2])], [int(a[1]), float(a[2])]]
	return a


## The point `f` of the way from landmark entry `a` to `b` (as weights).
static func _mix(a, b, f: float) -> Array:
	var out := []
	for vw: Array in _weights(a):
		out.append([int(vw[0]), float(vw[1]) * (1.0 - f)])
	for vw: Array in _weights(b):
		out.append([int(vw[0]), float(vw[1]) * f])
	return out


## The triangles of the face's skin (the head's region, tag 0) about the ears and the nose (flat vertex indices), for
## the landmark rays.
static func _face_tris(a: Array) -> PackedInt32Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var idx = a[Mesh.ARRAY_INDEX]
	var ind: PackedInt32Array = idx if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty() else PackedInt32Array(range(v.size()))
	var out := PackedInt32Array()
	for t in range(0, ind.size() - 2, 3):
		var i0 := ind[t]
		var p := v[i0]
		if p.y < 1.40 or p.y > 1.50 or p.z < -0.03 or (int(uv2[i0].x + 0.5) & 63) != 0:
			continue
		if (int(uv2[ind[t + 1]].x + 0.5) & 63) != 0 or (int(uv2[ind[t + 2]].x + 0.5) & 63) != 0:
			continue
		out.append_array([i0, ind[t + 1], ind[t + 2]])
	return out


## The ray o + t d (d unit) through the triangles `tris` of `v`, nearest first: [t, [[vertex, weight] x 3], the
## surface's normal facing the ray].
static func _ray_hits(v: PackedVector3Array, tris: PackedInt32Array, o: Vector3, d: Vector3) -> Array:
	var out := []
	for j in range(0, tris.size() - 2, 3):
		var a := v[tris[j]]
		var e1 := v[tris[j + 1]] - a
		var e2 := v[tris[j + 2]] - a
		var pv := d.cross(e2)
		var det := e1.dot(pv)
		if absf(det) < 1e-14:
			continue
		var inv := 1.0 / det
		var tv := o - a
		var u := tv.dot(pv) * inv
		if u < 0.0 or u > 1.0:
			continue
		var qv := tv.cross(e1)
		var w := d.dot(qv) * inv
		if w < 0.0 or u + w > 1.0:
			continue
		var t := e2.dot(qv) * inv
		if t <= 0.0:
			continue
		var n := e1.cross(e2).normalized()
		out.append([t, [[tris[j], 1.0 - u - w], [tris[j + 1], u], [tris[j + 2], w]], -n if n.dot(d) > 0.0 else n])
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	# (a ray along a shared edge meets both triangles: one hit)
	var uniq := []
	for h: Array in out:
		if uniq.is_empty() or float(h[0]) - float(uniq[-1][0]) > 1e-5:
			uniq.append(h)
	return uniq


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
		if k == DIRS:
			continue
		var p: Vector3 = data[k][0]
		var d: PackedVector3Array = data[k][1]
		for b in d.size():
			var w := head.get_blend_shape_value(b)
			if absf(w) > 1e-4:
				p += w * d[b]
		out[k] = p
	return out


## The places of an item's `at` on the face as its shapes are now (`lm`: landmarks; `dirs`: landmark_dirs), each
## {p: the pierced point (bind space), o: out from the head, ax: the axis of a ring through it (its plane holds the
## piercing and the down direction), s, sn: where a stud sits on the surface and its normal}.
static func _anchors(lm: Dictionary, dirs: Dictionary, at: String) -> Array:
	var out := []
	match at:
		"ears", "ear_l", "ear_r", "ear_rims":
			for sd in (["l", "r"] if at in ["ears", "ear_rims"] else [at.substr(4)]):
				var o := Vector3(1.0 if sd == "l" else -1.0, 0.0, 0.0)
				if lm.has("lobe_" + sd) and lm.has("lobe_front_" + sd):
					var pd: Vector3 = dirs.get("lobe_" + sd, o)
					out.append({"p": lm["lobe_" + sd], "o": o, "ax": pd.cross(Vector3.DOWN).normalized(),
							"s": lm["lobe_front_" + sd], "sn": dirs.get("lobe_front_" + sd, o)})
				elif lm.has("ear_" + sd):
					var q: Vector3 = lm["ear_" + sd] + Vector3(0.0, 0.0035, 0.0)
					out.append({"p": q, "o": o, "ax": o, "s": q + o * 0.0004, "sn": o})
				if at == "ear_rims":
					for k: int in [1, 2]:
						if lm.has("rim_%s%d" % [sd, k]):
							var q: Vector3 = lm["rim_%s%d" % [sd, k]] - o * 0.002
							out.append({"p": q, "o": o, "ax": o, "s": q + o * 0.002, "sn": o})
		"septum":
			if lm.has("columella") or lm.has("septum"):
				var q: Vector3 = lm.get("columella", lm.get("septum"))
				out.append({"p": q, "o": Vector3.BACK, "ax": Vector3(0.0, 0.3, 1.0).normalized(), "s": q,
						"sn": dirs.get("columella", Vector3.DOWN)})
		"nostril_l", "nostril_r":
			var sd := at.substr(8)
			var k := "ala_" + sd
			if lm.has(k) or lm.has(at):
				var q: Vector3 = lm.get(k, lm.get(at))
				var o: Vector3 = dirs.get(k, Vector3(0.85 if sd == "l" else -0.85, 0.0, 0.5).normalized())
				out.append({"p": q, "o": o, "ax": o.cross(Vector3.DOWN).normalized(), "s": q, "sn": o})
	return out


## The surface directions at the ray-found landmarks of `head` (landmark_data's DIRS; fixed, the shapes move them little).
static func landmark_dirs(head: MeshInstance3D) -> Dictionary:
	return landmark_data(head.mesh as ArrayMesh).get(DIRS, {})


## Adds the triangles of a piece at the place `a` (_anchors) to the metal and stone groups ({"v", "n"}); `it` the item
## (its "wire" thickens a ring's wire). Returns the point the stylized scale is about (the pierced point; a stud's own).
static func _piece(kind: String, a: Dictionary, size: float, metal: Dictionary, stone: Dictionary, it := {}) -> Vector3:
	var wire := float(it.get("wire", 1.0))
	var p: Vector3 = a.p
	var o: Vector3 = a.o
	var ax: Vector3 = a.ax
	match kind:
		"bob":
			# ball-and-cone: a wire loop through the lobe, a ball, a cone point down
			_torus(metal, p + Vector3(0, -0.002, 0), ax, 0.0032, 0.0006)
			_sphere(metal, p + Vector3(0, -0.0072, 0) + o * 0.0008, 0.0022)
			_cone(metal, p + Vector3(0, -0.009, 0) + o * 0.0008, Vector3.DOWN, 0.0026, 0.009)
		"hoop":
			var r := 0.0085 * size
			_torus(metal, p + Vector3(0, -r + 0.0025, 0), ax, r, 0.0007 * maxf(size, 0.7) * wire)
		"stud":
			# on the surface: a bead pressed to the skin
			var s: Vector3 = a.s
			_sphere(metal, s + (a.sn as Vector3) * 0.0011 * size, 0.0018 * size)
			return s
		"drop":
			_torus(metal, p + Vector3(0, -0.0015, 0), ax, 0.0025, 0.0005)
			_cylinder(metal, p + Vector3(0, -0.004, 0) + o * 0.0008, p + Vector3(0, -0.008, 0) + o * 0.0008, 0.0004)
			_sphere(stone, p + Vector3(0, -0.0105, 0) + o * 0.0008, 0.0029 * size)
		"septum":
			# a small loop through the septum (its plane faces forward), a cone hanging from it
			_torus(metal, p + Vector3(0, -0.0024, 0.0008), ax, 0.0027, 0.0005)
			_cone(metal, p + Vector3(0, -0.0052, 0.0012), Vector3.DOWN, 0.0022, 0.0065)
		"septum_ring":
			# a ring through the septum, hanging over the upper lip (its plane faces forward, leaning with the lip)
			var r := 0.0046 * size
			_torus(metal, p + Vector3(0.0, -r + 0.0016, 0.0009), ax, r, 0.00055 * maxf(size, 0.8) * wire)
		"septum_pin":
			# a bar through the septum just above its underside, its ends tapered, out under the alae
			var h := 0.021 * size
			var c := p + Vector3(0.0, 0.0011, -0.0004)
			_cylinder(stone, c + Vector3(-h + 0.004, 0, 0), c + Vector3(h - 0.004, 0, 0), 0.0012, 8)
			_cone(stone, c + Vector3(h - 0.004, 0, 0), Vector3.RIGHT, 0.0012, 0.004, 8)
			_cone(stone, c + Vector3(-h + 0.004, 0, 0), Vector3.LEFT, 0.0012, 0.004, 8)
		"nostril_hoop":
			# a ring through the ala round the nostril's rim: its plane holds the piercing and the down direction
			var r := 0.0042 * size
			_torus(metal, p + Vector3.DOWN * r * 0.8 - o * 0.0008, ax, r, 0.0005 * maxf(size, 0.8) * wire)
	return p


# --- the neck: strands over the skin and the clothes ---------------------------------------------

## The band of a mesh surface the strands rest on: its vertices near the neck and the upper chest (bind space), their
## offsets per blend shape that moves them, the triangles among them and, on the skin, their bones and weights. Cached
## per mesh surface.
static func _band_of(mesh: ArrayMesh, s: int, skin: bool) -> Dictionary:
	var key := "%d:%d" % [mesh.get_instance_id(), s]
	var c: Dictionary = _bands.get(key, {})
	if not c.is_empty() and (c.ref as WeakRef).get_ref() == mesh:
		return c
	var a := mesh.surface_get_arrays(s)
	var bs := mesh.surface_get_blend_shape_arrays(s) if mesh.get_blend_shape_count() > 0 else []
	c = _band_from(mesh, a, bs, mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE, skin)
	_bands[key] = c
	return c


static func _band_from(mesh: ArrayMesh, a: Array, bs: Array, relative: bool, skin: bool) -> Dictionary:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv2 = a[Mesh.ARRAY_TEX_UV2]
	var ok := PackedByteArray()
	ok.resize(v.size())
	for i in v.size():
		var p := v[i]
		if p.y < NECK_BAND.x or p.y > NECK_BAND.y or absf(p.x) > NECK_HALF_X or p.z < -0.2 or p.z > 0.25:
			continue
		if skin and uv2 is PackedVector2Array:
			var r := int((uv2 as PackedVector2Array)[i].x + 0.5) & 63
			if r < 1 or r > 8:
				continue
		ok[i] = 1
	var idx = a[Mesh.ARRAY_INDEX]
	var ind: PackedInt32Array = idx if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty() else PackedInt32Array(range(v.size()))
	var remap := PackedInt32Array()
	remap.resize(v.size())
	remap.fill(-1)
	var used := PackedInt32Array()
	var tris := PackedInt32Array()
	for t in range(0, ind.size() - 2, 3):
		var n := ok[ind[t]] + ok[ind[t + 1]] + ok[ind[t + 2]]
		# the skin's triangles inside the band; a garment's with a corner in it (its vertices are sparse)
		if n == 0 or (skin and n < 3):
			continue
		for vi: int in [ind[t], ind[t + 1], ind[t + 2]]:
			if remap[vi] < 0:
				remap[vi] = used.size()
				used.append(vi)
			tris.append(remap[vi])
	var lv := PackedVector3Array()
	lv.resize(used.size())
	for j in used.size():
		lv[j] = v[used[j]]
	var shapes := []
	for b in bs.size():
		var t: PackedVector3Array = bs[b][Mesh.ARRAY_VERTEX]
		var d := PackedVector3Array()
		d.resize(used.size())
		var mx := 0.0
		for j in used.size():
			var dv: Vector3 = t[used[j]] if relative else t[used[j]] - v[used[j]]
			d[j] = dv
			mx = maxf(mx, dv.length_squared())
		if mx > 1e-10:
			shapes.append([b, d])
	var out := {"ref": weakref(mesh), "v": lv, "t": tris, "d": shapes}
	if skin:
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var st := bones.size() / maxi(v.size(), 1)
		var lb := PackedInt32Array()
		var lw := PackedFloat32Array()
		for j in used.size():
			var w4 := PackedFloat32Array()
			var b4 := PackedInt32Array()
			for c in 4:
				b4.append(bones[used[j] * st + c] if c < st else 0)
				w4.append(wts[used[j] * st + c] if c < st else 0.0)
			var sum := w4[0] + w4[1] + w4[2] + w4[3]
			for c in 4:
				w4[c] = w4[c] / sum if sum > 1e-6 else (1.0 if c == 0 else 0.0)
			lb.append_array(b4)
			lw.append_array(w4)
		out["b"] = lb
		out["w"] = lw
	return out


## What the strands of `ctx`'s body rest on: the skin and the garments (not the hat), each surface's band, and a key of
## their meshes and shape values (the loops are cached by it).
static func _neck_state(ctx: Dictionary) -> Dictionary:
	if not (ctx.neck as Dictionary).is_empty():
		return ctx.neck
	var body: CharacterBodyMesh = ctx.body
	var head: MeshInstance3D = ctx.head
	var nb := _bind_of(head.skin, body.skeleton, "neck")
	var root := _bind_origin(head.skin, nb) if nb >= 0 else Vector3(0.0, 1.314, -0.005)
	var srcs := [[head, _skin_surface(head.mesh as ArrayMesh), true]]
	for tag: String in body.parts:
		if not tag.begins_with("outfit:") or tag in NECK_SKIP:
			continue
		for mi in body.parts[tag]:
			if not is_instance_valid(mi) or (mi as Node).is_queued_for_deletion() or not (mi as MeshInstance3D).visible \
					or not (mi as MeshInstance3D).mesh is ArrayMesh:
				continue
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				srcs.append([mi, s, false])
	var bands := []
	var key := "%.4f,%.4f" % [root.y, root.z]
	for e: Array in srcs:
		var mi: MeshInstance3D = e[0]
		var bd := _band_of(mi.mesh as ArrayMesh, int(e[1]), bool(e[2]))
		if (bd.t as PackedInt32Array).is_empty():
			continue
		bands.append([mi, bd, bool(e[2])])
		key += ";%d:%d" % [mi.mesh.get_instance_id(), int(e[1])]
		for sh: Array in bd.d:
			key += ",%.3f" % mi.get_blend_shape_value(int(sh[0]))
	ctx.neck = {"root": root, "bands": bands, "key": key, "built": false}
	return ctx.neck


## The current positions of the bands and their triangles binned by azimuth round the neck (one bin per ray), the skin's
## vertices too (for the strands' weights). Built only when a loop is not cached.
static func _neck_build(ns: Dictionary) -> void:
	if ns.built:
		return
	ns.built = true
	var cz := (ns.root as Vector3).z
	var step := TAU / NECK_RAYS
	var surfs := []
	var tris := []
	var bins := []
	var vbins := []
	for k in NECK_RAYS:
		bins.append([])
		vbins.append([])
	ns["skin"] = -1
	for si in (ns.bands as Array).size():
		var e: Array = ns.bands[si]
		var mi: MeshInstance3D = e[0]
		var bd: Dictionary = e[1]
		var p: PackedVector3Array = (bd.v as PackedVector3Array).duplicate()
		for sh: Array in bd.d:
			var w := mi.get_blend_shape_value(int(sh[0]))
			if absf(w) < 1e-4:
				continue
			var d: PackedVector3Array = sh[1]
			for i in p.size():
				p[i] += d[i] * w
		surfs.append(p)
		var t: PackedInt32Array = bd.t
		tris.append(t)
		var az := PackedFloat32Array()
		az.resize(p.size())
		for i in p.size():
			az[i] = atan2(p[i].x, p[i].z - cz)
		for j in range(0, t.size(), 3):
			var a0 := az[t[j]]
			var d1 := wrapf(az[t[j + 1]] - a0, -PI, PI)
			var d2 := wrapf(az[t[j + 2]] - a0, -PI, PI)
			var k0 := floori((a0 + minf(0.0, minf(d1, d2))) / step + 0.5)
			var k1 := floori((a0 + maxf(0.0, maxf(d1, d2))) / step + 0.5)
			if k1 - k0 > NECK_RAYS / 4:
				continue
			for k in range(k0, k1 + 1):
				(bins[posmod(k, NECK_RAYS)] as Array).append((si << 24) | j)
		if bool(e[2]):
			ns["skin"] = si
			for i in p.size():
				(vbins[posmod(floori(az[i] / step + 0.5), NECK_RAYS)] as Array).append(i)
	ns["surfs"] = surfs
	ns["tris"] = tris
	ns["bins"] = bins
	ns["vbins"] = vbins


## The ray from `o` along `dir` (unit) through the bins `ks`: [t, outward normal] of the outermost surface of the
## first layers it leaves (every surface within LAYER_GAP of the first: the skin, then the shirt, the waistcoat, a
## collar), or [] when it meets nothing.
static func _cast(ns: Dictionary, o: Vector3, dir: Vector3, ks: Array) -> Array:
	var ts := []
	var nm := []
	var t0 := INF
	for k: int in ks:
		for code: int in ns.bins[posmod(k, NECK_RAYS)]:
			var si := code >> 24
			var j := code & 0xFFFFFF
			var p: PackedVector3Array = ns.surfs[si]
			var t: PackedInt32Array = ns.tris[si]
			var a := p[t[j]]
			var e1 := p[t[j + 1]] - a
			var e2 := p[t[j + 2]] - a
			var pv := dir.cross(e2)
			var det := e1.dot(pv)
			if absf(det) < 1e-12:
				continue
			var inv := 1.0 / det
			var tv := o - a
			var u := tv.dot(pv) * inv
			if u < 0.0 or u > 1.0:
				continue
			var qv := tv.cross(e1)
			var vv := dir.dot(qv) * inv
			if vv < 0.0 or u + vv > 1.0:
				continue
			var h := e2.dot(qv) * inv
			if h > 0.012:
				ts.append(h)
				nm.append(e1.cross(e2))
				t0 = minf(t0, h)
	if ts.is_empty():
		return []
	var best := -1.0
	var bn := Vector3.ZERO
	for i in ts.size():
		if float(ts[i]) <= t0 + LAYER_GAP and float(ts[i]) > best:
			best = ts[i]
			bn = nm[i]
	bn = bn.normalized()
	if bn.dot(dir) < 0.0:
		bn = -bn
	return [best, bn]


## A strand's loop round the neck: NECK_RAYS points (bind space), `clear` outside the surface each meets, with the
## outward normals and the skin (bones, weights) of each point. Point k lies in the half-plane at azimuth k round the
## neck's axis (k 0 the front, round by the left), at the strand's height there: a level ray from the axis at that
## height meets the skin and the layers over it, and the point rests on the outermost (a ray from one pivot in the neck
## meets the hollow at the throat's foot at a glancing angle and jumps between the throat and the chest). `it` "drop":
## how far below the neck's root the front hangs (m; 0 at the root); "choker": a band this far above the root instead,
## level round the neck (a little lower in front); "hang": the front's shape (the height rises as |sin| of the angle to
## this power: 1 a V, the weight of a pendant pulling it; 1.6 a rounder U, a plain strand). Cached per body state.
static func _strand_loop(ctx: Dictionary, it: Dictionary, clear: float) -> Dictionary:
	var ns := _neck_state(ctx)
	var choker := float(it.get("choker", -1.0))
	var drop := float(it.get("drop", 0.04))
	var hang := float(it.get("hang", 1.0 if it.has("pendant") else 1.6))
	var key := "%s|%.3f|%.3f|%.4f|%.2f" % [ns.key, choker, drop, clear, hang]
	if _loops.has(key):
		return _loops[key]
	_neck_build(ns)
	var root: Vector3 = ns.root
	var o := Vector3(0.0, root.y + (choker if choker >= 0.0 else NECK_PIVOT), root.z)
	var n := NECK_RAYS
	var ts := PackedFloat32Array()
	ts.resize(n)
	var dirs := PackedVector3Array()
	dirs.resize(n)
	var orgs := PackedVector3Array()
	orgs.resize(n)
	var nrm := PackedVector3Array()
	nrm.resize(n)
	var hit := 0
	# a necklace's heights: the back of the neck's base, the sides in the corner of the neck and the shoulders, the
	# front `drop` below the root, between them a soft V
	var y_side := o.y - 0.003
	var y_back := o.y + 0.013
	var y_front := root.y - 0.02 - drop
	for k in n:
		var th := TAU * k / n
		var c := cos(th)
		var yt := 0.0
		if choker >= 0.0:
			yt = o.y + lerpf(0.004, -0.012, (1.0 + c) * 0.5)
		else:
			yt = y_side + (y_back - y_side) * -c if c < 0.0 else y_front + (y_side - y_front) * pow(absf(sin(th)), hang)
		var d := Vector3(sin(th), 0.0, c)
		var org := Vector3(0.0, yt, root.z)
		var h := _cast(ns, org, d, [k])
		dirs[k] = d
		orgs[k] = org
		ts[k] = float(h[0]) if not h.is_empty() else -1.0
		nrm[k] = h[1] if not h.is_empty() else d
		if not h.is_empty():
			hit += 1
	if hit < n / 2:
		_loops[key] = {}
		return {}
	# gaps (no surface met): between the neighbours that met one
	for k in n:
		if ts[k] >= 0.0:
			continue
		var a := 1
		while ts[posmod(k - a, n)] < 0.0:
			a += 1
		var b := 1
		while ts[posmod(k + b, n)] < 0.0:
			b += 1
		ts[k] = lerpf(ts[posmod(k - a, n)], ts[posmod(k + b, n)], float(a) / float(a + b))
		nrm[k] = (nrm[posmod(k - a, n)] + nrm[posmod(k + b, n)]).normalized()
	# over the hollows between bumps (a coat's collar, a kerchief's folds): a point raised to the lower of the highest on
	# each side (two rays either way), not to its neighbour on a slope; then averaged twice over three, and never
	# inside its own ray's surface
	var t1 := PackedFloat32Array()
	t1.resize(n)
	for k in n:
		var lo := maxf(ts[posmod(k - 1, n)], ts[posmod(k - 2, n)])
		var hi := maxf(ts[posmod(k + 1, n)], ts[posmod(k + 2, n)])
		t1[k] = maxf(ts[k], minf(lo, hi))
	var t2 := PackedFloat32Array()
	t2.resize(n)
	for k in n:
		t2[k] = (t1[posmod(k - 1, n)] + t1[k] + t1[posmod(k + 1, n)]) / 3.0
	var pts := PackedVector3Array()
	pts.resize(n)
	var bones := []
	var weights := []
	var sp: PackedVector3Array = ns.surfs[ns.skin] if int(ns.skin) >= 0 else PackedVector3Array()
	var sb: Dictionary = (ns.bands[ns.skin] as Array)[1] if int(ns.skin) >= 0 else {}
	var nb := _bind_of((ctx.head as MeshInstance3D).skin, (ctx.body as CharacterBodyMesh).skeleton, "neck")
	for k in n:
		var t := maxf((t2[posmod(k - 1, n)] + t2[k] + t2[posmod(k + 1, n)]) / 3.0, ts[k])
		pts[k] = orgs[k] + dirs[k] * (t + clear / maxf(dirs[k].dot(nrm[k]), 0.35))
		# the skin of the nearest skin vertex
		var best := -1
		var bd := INF
		if not sp.is_empty():
			for kk in [k - 1, k, k + 1]:
				for i: int in ns.vbins[posmod(kk, n)]:
					var dd := sp[i].distance_squared_to(pts[k])
					if dd < bd:
						bd = dd
						best = i
		if best >= 0:
			bones.append((sb.b as PackedInt32Array).slice(best * 4, best * 4 + 4))
			weights.append((sb.w as PackedFloat32Array).slice(best * 4, best * 4 + 4))
		else:
			bones.append(PackedInt32Array([maxi(nb, 0), 0, 0, 0]))
			weights.append(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	var loop := {"p": pts, "n": nrm, "b": bones, "w": weights, "o": o, "os": orgs, "key": key}
	if _loops.size() > 96:
		_loops.clear()
	_loops[key] = loop
	return loop


## Where a pendant `length` long hangs from the front of `loop`: [top, down along the chest, outward], resting on what
## is under it (cached with the loop).
static func _pendant_frame(ctx: Dictionary, loop: Dictionary, length: float, clear: float) -> Array:
	var key := "pend:%.4f:%.4f" % [length, clear]
	if loop.has(key):
		return loop[key]
	var top: Vector3 = (loop.p as PackedVector3Array)[0]
	var n0: Vector3 = (loop.n as PackedVector3Array)[0]
	var down := Vector3.DOWN - n0 * Vector3.DOWN.dot(n0)
	down = down.normalized() if down.length() > 0.1 else Vector3.DOWN
	var q := top + down * length
	var nn := n0
	var ns := _neck_state(ctx)
	_neck_build(ns)
	# a level ray from the neck's axis at the pendant's foot (as the loop's points)
	var o := Vector3(0.0, q.y, (ns.root as Vector3).z)
	var dir := Vector3(q.x, 0.0, q.z - o.z).normalized()
	var k := roundi(atan2(dir.x, dir.z) / (TAU / NECK_RAYS))
	var h := _cast(ns, o, dir, [k - 1, k, k + 1])
	if not h.is_empty():
		q = o + dir * (float(h[0]) + clear / maxf(dir.dot(h[1]), 0.35))
		nn = (n0 + (h[1] as Vector3)).normalized()
	var ax := (q - top).normalized()
	nn = (nn - ax * ax.dot(nn)).normalized()
	var fr := [top, ax, nn]
	loop[key] = fr
	return fr


## A loop's points resampled smooth (Catmull-Rom, `sub` per span): [points, normals, the loop point each is nearest].
static func _smooth_loop(loop: Dictionary, sub: int) -> Array:
	var p: PackedVector3Array = loop.p
	var nr: PackedVector3Array = loop.n
	var n := p.size()
	var pts := PackedVector3Array()
	var nrm := PackedVector3Array()
	var ks := PackedInt32Array()
	for k in n:
		var p0 := p[posmod(k - 1, n)]
		var p1 := p[k]
		var p2 := p[(k + 1) % n]
		var p3 := p[(k + 2) % n]
		for s in sub:
			var t := float(s) / float(sub)
			var t2 := t * t
			var t3 := t2 * t
			pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
			nrm.append(nr[k].lerp(nr[(k + 1) % n], t).normalized())
			ks.append(k if t < 0.5 else (k + 1) % n)
	return [pts, nrm, ks]


static func _neck_piece(ctx: Dictionary, it: Dictionary) -> void:
	var kind := String(it.get("kind", "chain"))
	var metal := String(it.get("metal", "silver"))
	var size := float(it.get("size", 1.0))
	var r := 0.001 * size
	match kind:
		"beads":
			r = float(it.get("bead", 0.003)) * size
		"cord":
			r = 0.0013 * size
		"ribbon":
			r = 0.0008
	var loop := _strand_loop(ctx, it, r + 0.0012)
	if loop.is_empty():
		return
	var sids := []
	for k in NECK_RAYS:
		sids.append(_skin_id(ctx, loop.b[k], loop.w[k]))
	var path := _smooth_loop(loop, 3)
	var pend := String(it.get("pendant", ""))
	if pend == "gorget":
		# the strand runs from one horn of the gorget round the back of the neck to the other
		path = _gorget(ctx, loop, path, int(sids[0]), String(it.get("pendant_of", metal)), size)
		pend = ""
	match kind:
		"beads":
			_beads(ctx, path, sids, it.get("beads", ["glass_white"]) as Array, r)
		"ribbon":
			_ribbon(ctx, path, sids, String(it.get("ribbon", "ribbon")), float(it.get("width", 0.009)) * size, 0.0008)
		"cord":
			_tube(ctx, path, sids, String(it.get("cord", "cord")), r, 5)
		_:
			_tube(ctx, path, sids, metal, r, 5)
	if not pend.is_empty():
		_pendant(ctx, loop, int(sids[0]), pend, String(it.get("pendant_of", metal)), size)


## The tangent of `path` (_smooth_loop's [points, ...], closed; or with a fourth entry false, open) at point i.
static func _tangent(path: Array, i: int) -> Vector3:
	var pts: PackedVector3Array = path[0]
	var n := pts.size()
	if path.size() > 3 and not bool(path[3]):
		return (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
	return (pts[(i + 1) % n] - pts[posmod(i - 1, n)]).normalized()


## The spans of `path`: n for a closed one, n - 1 for an open one.
static func _spans(path: Array) -> int:
	var n := (path[0] as PackedVector3Array).size()
	return n - 1 if path.size() > 3 and not bool(path[3]) else n


## A tube of radius `r` along `path` (closed, or open: _tangent).
static func _tube(ctx: Dictionary, path: Array, sids: Array, mat: String, r: float, sides: int) -> void:
	var pts: PackedVector3Array = path[0]
	var nrm: PackedVector3Array = path[1]
	var ks: PackedInt32Array = path[2]
	var n := pts.size()
	var rings := []
	for i in n:
		var tg := _tangent(path, i)
		var nn := (nrm[i] - tg * tg.dot(nrm[i])).normalized()
		var bb := tg.cross(nn)
		var ring := []
		for j in sides:
			var a := TAU * j / sides
			ring.append(nn * cos(a) + bb * sin(a))
		rings.append(ring)
	var g := _group_of(ctx, mat)
	var v: Array = g.v
	var nv: Array = g.n
	var s: Array = g.s
	for i in _spans(path):
		var i2 := (i + 1) % n
		var s1: int = sids[ks[i]]
		var s2: int = sids[ks[i2]]
		for j in sides:
			var j2 := (j + 1) % sides
			var a1: Vector3 = rings[i][j]
			var b1: Vector3 = rings[i][j2]
			var a2: Vector3 = rings[i2][j]
			var b2: Vector3 = rings[i2][j2]
			v.append_array([pts[i] + a1 * r, pts[i2] + a2 * r, pts[i2] + b2 * r, pts[i] + a1 * r, pts[i2] + b2 * r, pts[i] + b1 * r])
			nv.append_array([a1, a2, b2, a1, b2, b1])
			s.append_array([s1, s2, s2, s1, s2, s1])


## A flat ribbon `width` wide and `th` thick along `path` (closed, or open: _tangent), lying on what is under it.
static func _ribbon(ctx: Dictionary, path: Array, sids: Array, mat: String, width: float, th: float) -> void:
	var pts: PackedVector3Array = path[0]
	var nrm: PackedVector3Array = path[1]
	var ks: PackedInt32Array = path[2]
	var n := pts.size()
	var g := _group_of(ctx, mat)
	var v: Array = g.v
	var nv: Array = g.n
	var s: Array = g.s
	var fr := []
	for i in n:
		var tg := _tangent(path, i)
		var nn := (nrm[i] - tg * tg.dot(nrm[i])).normalized()
		fr.append([nn, tg.cross(nn)])
	for i in _spans(path):
		var i2 := (i + 1) % n
		var s1: int = sids[ks[i]]
		var s2: int = sids[ks[i2]]
		# the faces: outer (+n), the two edges (+b, -b), inner (-n); each a quad of the profile's corners
		for f: Array in [[1.0, 0.0], [0.0, 1.0], [0.0, -1.0], [-1.0, 0.0]]:
			var c := []
			for e: Array in [[i, 0], [i2, 0], [i2, 1], [i, 1]]:
				var fn: Vector3 = fr[e[0]][0]
				var fb: Vector3 = fr[e[0]][1]
				var sgn := 1.0 if int(e[1]) == 0 else -1.0
				var off: Vector3
				if float(f[0]) != 0.0:
					off = fn * float(f[0]) * th * 0.5 + fb * sgn * width * 0.5
				else:
					off = fb * float(f[1]) * width * 0.5 + fn * sgn * th * 0.5
				c.append(pts[e[0]] + off)
			var fnorm: Vector3 = (fr[i][0] as Vector3) * float(f[0]) + (fr[i][1] as Vector3) * float(f[1])
			v.append_array([c[0], c[1], c[2], c[0], c[2], c[3]])
			nv.append_array([fnorm, fnorm, fnorm, fnorm, fnorm, fnorm])
			s.append_array([s1, s2, s2, s1, s2, s1])


## Beads of radius `r` touching along the closed `path`, their materials in the order of `pattern`.
static func _beads(ctx: Dictionary, path: Array, sids: Array, pattern: Array, r: float) -> void:
	var pts: PackedVector3Array = path[0]
	var ks: PackedInt32Array = path[2]
	var n := pts.size()
	var cum := PackedFloat32Array([0.0])
	for i in n:
		cum.append(cum[i] + pts[i].distance_to(pts[(i + 1) % n]))
	var total := cum[n]
	var count := maxi(int(total / (2.0 * r * 1.06)), 8)
	var gap := total / count
	var j := 0
	for b in count:
		var at := b * gap
		while j < n - 1 and cum[j + 1] < at:
			j += 1
		var f := (at - cum[j]) / maxf(cum[j + 1] - cum[j], 1e-6)
		var c := pts[j].lerp(pts[(j + 1) % n], f)
		var mat := String(pattern[b % pattern.size()]) if not pattern.is_empty() else "glass_white"
		var g := _group_of(ctx, mat)
		_sphere(g, c, r, 8, 5)
		_mark(g, int(sids[ks[j if f < 0.5 else (j + 1) % n]]))


## A pendant at the front of the loop: a cross, a locket, a disc (a medal), a tooth or claw of bone (a gorget hangs
## from its horns instead: _gorget).
static func _pendant(ctx: Dictionary, loop: Dictionary, sid: int, kind: String, mat: String, size: float) -> void:
	var length := float({"cross": 0.036, "locket": 0.032, "disc": 0.03, "tooth": 0.04}.get(kind, 0.03)) * size
	var th := 0.003
	var fr := _pendant_frame(ctx, loop, length, th * 0.5 + 0.0012)
	var top: Vector3 = fr[0]
	var dn: Vector3 = fr[1]
	var out: Vector3 = fr[2]
	var side := dn.cross(out).normalized()
	var g := _group_of(ctx, mat)
	match kind:
		"cross":
			var t0 := top + out * 0.0014
			_torus(g, t0 + dn * 0.002, side, 0.002, 0.0006)
			_box(g, t0 + dn * (0.004 + 0.016 * size), side * 0.0029 * size, dn * 0.016 * size, out * 0.0014)
			_box(g, t0 + dn * (0.004 + 0.0105 * size), side * 0.0105 * size, dn * 0.0029 * size, out * 0.0014)
		"locket":
			var t0 := top + out * 0.0016
			_torus(g, t0 + dn * 0.002, side, 0.002, 0.0006)
			var c := t0 + dn * (0.004 + 0.014 * size) + out * 0.0012
			_ellipsoid(g, c, side * 0.0105 * size, dn * 0.014 * size, out * 0.003)
			_torus(g, c, out, 0.0105 * size, 0.0007, 22, 5)
		"disc":
			var t0 := top + out * 0.0012
			_torus(g, t0 + dn * 0.002, side, 0.002, 0.0006)
			var c := t0 + dn * (0.004 + 0.0125 * size) + out * 0.0008
			_disc(g, c, out, 0.0125 * size, 0.0018)
			_ellipsoid(g, c + out * 0.001, side * 0.004, dn * 0.004, out * 0.0013)
		"tooth":
			var t0 := top + out * 0.0014
			_cylinder(g, t0 - dn * 0.001, t0 + dn * 0.0045, 0.0032, 8)
			_cone(g, t0 + dn * 0.0045, dn, 0.0039 * size, 0.035 * size, 8)
	_mark(g, sid)


## A gorget at the throat, hung from holes near its horns: its crescent (GORGET: width, depth, thickness, bend, boss)
## level with the strand where the strand crosses the holes, standing just clear of the throat and the clothes there and
## lying down along the chest below it (level rays from the neck's axis, as the loop). Adds the crescent and its boss to
## the `mat` group (the skin `sid`: the loop's front) and returns the strand's open path from the left hole round the
## back to the right one (the loop's front between the holes cut away).
static func _gorget(ctx: Dictionary, loop: Dictionary, path: Array, sid: int, mat: String, size: float) -> Array:
	var w := float(GORGET.w) * size
	var h := float(GORGET.h) * size
	var th := float(GORGET.th)
	var bend := float(GORGET.bend)
	var xh := w * 0.5 - 0.007
	var pts: PackedVector3Array = path[0]
	var nrm: PackedVector3Array = path[1]
	var ks: PackedInt32Array = path[2]
	var n := pts.size()
	# where the strand crosses the holes' x on each side of the front (point 0; the left side first)
	var il := 1
	while il < n / 2 and pts[il].x < xh:
		il += 1
	var ir := n - 1
	while ir > n / 2 and pts[ir].x > -xh:
		ir -= 1
	if il >= n / 2 or ir <= n / 2:
		return path
	var pl := pts[il - 1].lerp(pts[il], clampf((xh - pts[il - 1].x) / maxf(pts[il].x - pts[il - 1].x, 1e-6), 0.0, 1.0))
	var nx := (ir + 1) % n
	var pr := pts[nx].lerp(pts[ir], clampf((-xh - pts[nx].x) / minf(pts[ir].x - pts[nx].x, -1e-6), 0.0, 1.0))
	var ns := _neck_state(ctx)
	_neck_build(ns)
	var cz := (ns.root as Vector3).z
	var y0 := (pl.y + pr.y) * 0.5
	var clear := th * 0.5 + 0.0015
	# the front of the throat (and what is worn there) at the horns' height, and of the chest at the foot
	var front := func(y: float) -> Vector3:
		var hh := _cast(ns, Vector3(0.0, y, cz), Vector3.BACK, [0])
		var z := cz + (float(hh[0]) if not hh.is_empty() else 0.06)
		var nn: Vector3 = hh[1] if not hh.is_empty() else Vector3.BACK
		return Vector3(0.0, y, z) + nn * clear / maxf(nn.z, 0.35)
	var top: Vector3 = front.call(y0)
	var foot: Vector3 = front.call(y0 - h * 0.85)
	var dn := (foot - top).normalized()
	# clear of what bulges across its width too (a kerchief's folds, the collarbones): level rays toward points of the
	# crescent, which bends back by x^2 / 2 bend and leans with dn; it moves out by the most any of them asks
	var push := 0.0
	for fx: float in [-1.0, -0.9, -0.7, -0.45, -0.2, 0.2, 0.45, 0.7, 0.9, 1.0]:
		for fy: float in [0.4, 0.7, 1.0]:
			var x := fx * w * 0.5
			var y := y0 - fy * h * sqrt(1.0 - fx * fx)
			var zc := top.z + dn.z * (top.y - y) / maxf(-dn.y, 0.2) - x * x / (2.0 * bend)
			var d := Vector3(x, 0.0, zc - cz).normalized()
			var hh := _cast(ns, Vector3(0.0, y, cz), d, [roundi(atan2(d.x, d.z) / (TAU / NECK_RAYS))])
			if not hh.is_empty():
				# the crescent's point there must lie `clear` beyond the hit along the ray
				var t := float(hh[0]) + clear
				push = maxf(push, sqrt(maxf(t * t - x * x, 0.0)) - (zc - cz))
	top.z += push
	var side := Vector3.LEFT
	var out := side.cross(dn).normalized()
	if out.z < 0.0:
		out = -out
	side = dn.cross(out).normalized()
	var g := _group_of(ctx, mat)
	_crescent(g, top, side, dn, out, w, h, th, bend)
	_ellipsoid(g, top + dn * h * 0.68 + out * (th * 0.5 + 0.0008), side * float(GORGET.boss) * size, dn * float(GORGET.boss) * 0.76 * size,
			out * 0.002)
	# the holes, a third of the way down the crescent near each horn
	var holes := []
	for sgn: float in [1.0, -1.0]:
		var x := sgn * xh
		var u := x / (w * 0.5)
		var sq := sqrt(maxf(1.0 - u * u, 0.0))
		var hp := top + side * x + dn * (h * 0.3 * sq) + out * (-x * x / (2.0 * bend))
		holes.append(hp)
	_mark(g, sid)
	# the strand: left hole, the crossing, round the back, the crossing, right hole (the holes follow the gorget's skin)
	var op := PackedVector3Array([holes[0] if (holes[0] as Vector3).x > 0.0 else holes[1], pl])
	var on := PackedVector3Array([out, nrm[il]])
	var ok := PackedInt32Array([0, ks[il]])
	for i in range(il, ir + 1):
		op.append(pts[i])
		on.append(nrm[i])
		ok.append(ks[i])
	op.append_array([pr, holes[1] if (holes[1] as Vector3).x < 0.0 else holes[0]])
	on.append_array([nrm[ir], out])
	ok.append_array([ks[ir], 0])
	return [op, on, ok, false]


## A gorget's crescent: `w` wide, `h` deep at the middle, its horns at `top` level, bent round the chest (radius `bend`).
static func _crescent(g: Dictionary, top: Vector3, side: Vector3, dn: Vector3, out: Vector3, w: float, h: float, th: float, bend: float) -> void:
	var m := 18
	var fr := []
	var bk := []
	var nf := []
	for i in m + 1:
		var u := -cos(PI * i / m)
		var x := u * w * 0.5
		var sq := sqrt(maxf(1.0 - u * u, 0.0))
		var bz := -x * x / (2.0 * bend)
		var n := (out + side * (x / bend)).normalized()
		for y: float in [h * 0.4 * sq, h * sq]:
			var p := top + side * x + dn * y + out * bz
			fr.append(p + n * th * 0.5)
			bk.append(p - n * th * 0.5)
		nf.append(n)
	for i in m:
		var a := i * 2
		var b := a + 2
		# front, back
		_quad(g, [fr[a], fr[b], fr[b + 1], fr[a + 1]], [nf[i], nf[i + 1], nf[i + 1], nf[i]])
		_quad(g, [bk[a], bk[a + 1], bk[b + 1], bk[b]], [-nf[i], -nf[i], -nf[i + 1], -nf[i + 1]])
		# the inner (upper) and outer (lower) edges
		var ei := ((fr[b] as Vector3) - (fr[a] as Vector3)).cross(nf[i]).normalized()
		_quad(g, [fr[a], bk[a], bk[b], fr[b]], [-ei, -ei, -ei, -ei])
		_quad(g, [fr[a + 1], fr[b + 1], bk[b + 1], bk[a + 1]], [ei, ei, ei, ei])


# --- rings ---------------------------------------------------------------------------------------

## The vertices of the skin on each ring's finger bone (weight 0.45 or more): bind index -> [positions, [[shape, offsets]]].
static func _fingers_from(a: Array, bs: Array, relative: bool, binds: Array) -> Dictionary:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var st := bones.size() / maxi(v.size(), 1)
	var sel := {}
	for bi: int in binds:
		sel[bi] = PackedInt32Array()
	for i in v.size():
		for c in st:
			var b := bones[i * st + c]
			if sel.has(b) and wts[i * st + c] >= 0.45:
				var l: PackedInt32Array = sel[b]
				l.append(i)
				sel[b] = l
	var out := {}
	for bi: int in sel:
		var ids: PackedInt32Array = sel[bi]
		var lv := PackedVector3Array()
		for i in ids:
			lv.append(v[i])
		var shapes := []
		for b in bs.size():
			var t: PackedVector3Array = bs[b][Mesh.ARRAY_VERTEX]
			var d := PackedVector3Array()
			var mx := 0.0
			for i in ids:
				var dv: Vector3 = t[i] if relative else t[i] - v[i]
				d.append(dv)
				mx = maxf(mx, dv.length_squared())
			if mx > 1e-10:
				shapes.append([b, d])
		out[bi] = [lv, shapes]
	return out


## The finger's radius about the bone from `a` along `ax` (`length` to the next joint) between a quarter and two thirds
## of the way, as the body's shapes are now.
static func _finger_radius(head: MeshInstance3D, bi: int, a: Vector3, ax: Vector3, length: float) -> float:
	var f: Dictionary = _fingers.get(head.mesh.get_instance_id(), {})
	if not f.has(bi):
		return 0.0085
	var lv: PackedVector3Array = f[bi][0]
	var r := 0.0
	for i in lv.size():
		var p := lv[i]
		for sh: Array in f[bi][1]:
			var w := head.get_blend_shape_value(int(sh[0]))
			if absf(w) > 1e-4:
				p += (sh[1] as PackedVector3Array)[i] * w
		var q := p - a
		var t := q.dot(ax)
		if t < length * 0.25 or t > length * 0.66:
			continue
		r = maxf(r, (q - ax * t).length())
	return r if r > 0.003 else 0.0085


## A ring (a band; a signet with its bezel on the back of the finger) on the finger bone of its place, unless a glove
## covers the hand.
static func _ring_piece(ctx: Dictionary, it: Dictionary) -> void:
	var at := String(it.get("at", "ring_l"))
	var f: Array = FINGERS.get(at, [])
	if f.is_empty() or ("hand_l" if at.ends_with("_l") else "hand_r") in (ctx.hidden as Array):
		return
	var head: MeshInstance3D = ctx.head
	var sk := (ctx.body as CharacterBodyMesh).skeleton
	var bi := _bind_of(head.skin, sk, String(f[0]))
	var bj := _bind_of(head.skin, sk, String(f[1]))
	if bi < 0 or bj < 0:
		return
	var a := _bind_origin(head.skin, bi)
	var b := _bind_origin(head.skin, bj)
	var length := a.distance_to(b)
	if length < 0.005:
		return
	var ax := (b - a) / length
	var size := float(it.get("size", 1.0))
	var tube := 0.00105 * size
	var fr := _finger_radius(head, bi, a, ax, length)
	var c := a + ax * length * 0.42
	var g := _group_of(ctx, String(it.get("metal", "gold")))
	_torus(g, c, ax, fr + tube * 0.9, tube, 18, 6)
	if String(it.get("kind", "ring")) == "signet":
		# the back of the hand faces out from the body in the bind pose
		var dorsal := Vector3(float(f[2]), 0.0, 0.0)
		dorsal = (dorsal - ax * ax.dot(dorsal)).normalized()
		_ellipsoid(g, c + dorsal * (fr + tube * 1.7), ax * 0.0036 * size, dorsal.cross(ax) * 0.0042 * size, dorsal * 0.0017)
	_mark(g, _skin_id(ctx, PackedInt32Array([bi, 0, 0, 0]), PackedFloat32Array([1.0, 0.0, 0.0, 0.0])))


# --- primitives ----------------------------------------------------------------------------------

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
	_ellipsoid(g, c, Vector3(r, 0, 0), Vector3(0, r, 0), Vector3(0, 0, r), seg0, rings0)


## An ellipsoid with the (orthogonal) semi-axes `ex`, `ey` (its poles), `ez`.
static func _ellipsoid(g: Dictionary, c: Vector3, ex: Vector3, ey: Vector3, ez: Vector3, seg0 := 10, rings0 := 7) -> void:
	var seg := maxi(int(round(seg0 * _seg)), 6)
	var rings := maxi(int(round(rings0 * _seg)), 4)
	var ix := ex / maxf(ex.length_squared(), 1e-12)
	var iy := ey / maxf(ey.length_squared(), 1e-12)
	var iz := ez / maxf(ez.length_squared(), 1e-12)
	var pos := []
	var nrm := []
	for j in rings + 1:
		var a := PI * j / rings
		for i in seg + 1:
			var b := TAU * i / seg
			var d := Vector3(sin(a) * cos(b), cos(a), sin(a) * sin(b))
			pos.append(c + ex * d.x + ey * d.y + ez * d.z)
			var nn := ix * d.x + iy * d.y + iz * d.z
			nrm.append(nn.normalized() if nn.length_squared() > 0.0 else ey.normalized())
	var w := seg + 1
	for j in rings:
		for i in seg:
			var q := [j * w + i, j * w + i + 1, (j + 1) * w + i + 1, (j + 1) * w + i]
			_quad(g, [pos[q[0]], pos[q[1]], pos[q[2]], pos[q[3]]], [nrm[q[0]], nrm[q[1]], nrm[q[2]], nrm[q[3]]])


## A box with the half-extent axes `ex`, `ey`, `ez` (orthogonal).
static func _box(g: Dictionary, c: Vector3, ex: Vector3, ey: Vector3, ez: Vector3) -> void:
	for ax: Array in [[ex, ey, ez], [ey, ez, ex], [ez, ex, ey]]:
		for sgn: float in [1.0, -1.0]:
			var n: Vector3 = (ax[0] as Vector3).normalized() * sgn
			var f: Vector3 = c + (ax[0] as Vector3) * sgn
			var u: Vector3 = ax[1]
			var v: Vector3 = (ax[2] as Vector3) * sgn
			_quad(g, [f - u - v, f + u - v, f + u + v, f - u + v], [n, n, n, n])


## A flat disc of radius `r` and thickness `th`, its faces normal to `axis`.
static func _disc(g: Dictionary, c: Vector3, axis: Vector3, r: float, th: float, seg0 := 20) -> void:
	var seg := maxi(int(round(seg0 * _seg)), 10)
	var f := _frame(axis)
	var n: Vector3 = f[0]
	var top := c + n * th * 0.5
	var bot := c - n * th * 0.5
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := (f[1] as Vector3) * cos(a0) + (f[2] as Vector3) * sin(a0)
		var d1 := (f[1] as Vector3) * cos(a1) + (f[2] as Vector3) * sin(a1)
		(g.v as Array).append_array([top, top + d0 * r, top + d1 * r, bot, bot + d1 * r, bot + d0 * r])
		(g.n as Array).append_array([n, n, n, -n, -n, -n])
		_quad(g, [bot + d0 * r, bot + d1 * r, top + d1 * r, top + d0 * r], [d0, d1, d1, d0])


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
