class_name BodyMaterials
extends RefCounted
## Materials and look helpers for the customizer's body, face and hair parts
## (assets/character/body/body.glb, assets/character/hair/*.glb, built by
## tools/character/build_character.sh).
##
##   var body := CharacterBodyMesh.attach_parts(sk, ap, {"body": BodyMaterials.BODY_GLB})
##   BodyMaterials.apply_look(body, {"sex": 1.0, "face": "m_face_2", "melanin": 0.55,
##           "undertone": "warm", "hair": {"style": "hair_queue_ribbon", "color": "dark_brown"}})
##
## Look keys (all optional): sex (0 female .. 1 male fit), face (a peoples.json preset id,
## see CharacterPeoples, or {face_*: weight}), melanin (0..1, "Tone 1-12"), undertone (cool /
## neutral / warm / olive or Vector2 Oklab a/b), haemoglobin (0..1, 0.5 average), freckles,
## weathering, stubble, iris (Color or "#rrggbb" or body.json "eyes" key), brows {thickness,
## arch, density}, hair {style, color (hair_colors.json preset) or eumelanin / pheomelanin /
## grey, powder, accent (Color / "#rrggbb"), accent_metal}, hide_regions (body regions
## hidden by clothing; "chest_front" holds the breasts stiff, "pelvis_center" holds the genitals
## still), bust (-1..1, the women's bust gauge), genital (-1..1, a man's size; his people's
## number, peoples.py GENITAL), hide_hair_zones (crown, sides, back, queue, lock: hidden by a hat),
## outfit_fit ("full": `sex` shapes the whole body; "head": only the head, via `sex_head`,
## for outfits built on the female body such as the legacy actor_b_body.glb), hat_fit (0..1:
## the hair pressed flat under a hat band, the hair glbs' `hat_fit` shape), debug_view
## (1 = region colours); from the character creator (CreatorOptions): facial_hair, marks
## {pox, scar, paint}, jewellery (FaceExtras adds the beard shells and the jewellery), face_style
## ("stylized", the default, or "realistic") and complexion (the stylized paint's lines).
##
## Face style. "stylized" (the default): the body.glb `style` shape (a shorter, leaner lower face,
## clear cheekbones and brow, a clean jaw line, larger eyes: tools/character/lib/stylize.py, one
## fixed delta for every face, the face features unchanged), `style_male` at the sex weight (the
## male fit's broad jaw and strong chin), and the painted materials: painted_skin.gdshader with the baked paint maps
## (paint_head.png, paint_lines.png), painted eyes, brows, lashes, hair and beard (`stylized` 1
## in their shaders). "realistic": n07's anatomical faces and materials, exactly as before.
## Skin tone never changes with the outfit (costume bible 3.6); stature is the Actor_B
## instance's scale and is set by the caller.

const BODY_GLB := "res://assets/character/body/body.glb"
const BODY_JSON := "res://assets/character/body/body.json"
const HAIR_DIR := "res://assets/character/hair/"
const HAIR_COLORS := "res://assets/character/hair/hair_colors.json"
const SKIN_SHADER := preload("res://assets/character/shaders/skin.gdshader")
const PAINTED_SKIN_SHADER := preload("res://assets/character/shaders/painted_skin.gdshader")
const PAINT_HEAD := "res://assets/character/body/paint_head.png"
const BODY_DETAIL := "res://assets/character/body/body_detail.png"
const PAINT_LINES := "res://assets/character/body/paint_lines.png"
## Pubic hair (tools/character/body/body_hair.py): the strips per body type, their surface, and the
## patterns over MakeHuman's UV atlas (R women, G men) that tint the skin under them.
const BODY_HAIR_GLB := "res://assets/character/body/body_hair_%s.glb"
const BODY_HAIR_SURFACE := "body_hair_tex"
const BODY_HAIR_MASK := "res://assets/character/body/body_hair_mask.png"
const HAIR_ATLAS := "res://assets/character/hair/tex/hair_atlas.png"
## Face styles of the creator (look.face_style); the first is the default. Realistic only since the
## v3 head (the user, 2026-09-27: "realistic only"): the painted maps and the style shapes belong to
## the v2 head; a saved "stylized" look reads as realistic.
const FACE_STYLES := ["realistic"]
const EYE_SHADER := preload("res://assets/character/shaders/eye.gdshader")
const HAIR_SHADER := preload("res://assets/character/shaders/hair.gdshader")
const HAIR_CARDS_SHADER := preload("res://assets/character/shaders/hair_cards.gdshader")
## Hair v2 (2026-09-27): textured strand strips (MakeHuman hair, surface "<style>_tex").
const HAIR_TEX_SHADER := preload("res://assets/character/shaders/hair_tex.gdshader")
const FACE_HAIR_SHADER := preload("res://assets/character/shaders/face_hair.gdshader")
const HAIR_TEXTURES := {"straight": 0, "cropped": 1, "coily": 2}

static var _json_cache := {}


static func load_json(path: String) -> Dictionary:
	if not _json_cache.has(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_json_cache[path] = d if d is Dictionary else {}
	return _json_cache[path]


static func body_info() -> Dictionary:
	return load_json(BODY_JSON)


## Eye colours by name: the body's (body.json "eyes") and the world's own (the world peoples' silver, ice, keel gold ...:
## CharacterPeoples.world_eye_colors).
static func eye_colors() -> Dictionary:
	var out: Dictionary = (body_info().get("eyes", {}) as Dictionary).duplicate()
	out.merge(CharacterPeoples.world_eye_colors())
	return out


static func hair_info(style: String) -> Dictionary:
	return load_json(HAIR_DIR + style + ".json")


## "stylized" (default) or "realistic".
static func face_style(look: Dictionary) -> String:
	var s := String(look.get("face_style", FACE_STYLES[0])) if look.get("face_style") is String else FACE_STYLES[0]
	return s if s in FACE_STYLES else FACE_STYLES[0]


static func is_stylized(look: Dictionary) -> bool:
	return face_style(look) == "stylized"


## The stylized paint's settings of the look's complexion (creator.json "complexion"):
## {lines, contrast, zones}.
static func complexion(look: Dictionary) -> Dictionary:
	var t: Dictionary = CreatorOptions.data().get("complexion", {})
	var c: Dictionary = t.get(String(look.get("complexion", "smooth")), t.get("smooth", {}))
	return {"lines": float(c.get("lines", 0.0)), "contrast": float(c.get("contrast", 1.35)), "zones": float(c.get("zones", 1.0))}


static func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func region_ids() -> Dictionary:
	var r: Dictionary = body_info().get("regions", {})
	var ids: Dictionary = (r.get("ids", {}) as Dictionary).duplicate()
	for z: String in r.get("hair_zones", {}):
		ids["hair_" + z] = int(r.hair_zones[z])
	return ids


## Hide mask (uvec2 uniform) of region names ("chest_front", "hair_crown", ...).
static func hide_mask(names: Array) -> Vector2i:
	var ids := region_ids()
	var lo := 0
	var hi := 0
	for n in names:
		if not ids.has(n):
			push_warning("BodyMaterials: unknown region %s" % n)
			continue
		var r := int(ids[n])
		if r < 32:
			lo |= 1 << r
		else:
			hi |= 1 << (r - 32)
	# uvec2 halves travel as int32: wrap bit 31
	if lo >= 0x80000000:
		lo -= 0x100000000
	if hi >= 0x80000000:
		hi -= 0x100000000
	return Vector2i(lo, hi)


static func _srgb_to_lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _lin_to_srgb(c: float) -> float:
	return c * 12.92 if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055


static func undertone_ab(u) -> Vector2:
	if u is Vector2:
		return u
	var t: Dictionary = body_info().get("skin", {}).get("undertones", {})
	var ab: Array = t.get(String(u), [0.0, 0.0])
	return Vector2(ab[0], ab[1])


## sRGB colour of a skin tone (for UI swatches; the shader computes the same in linear).
static func tone_color(melanin: float, undertone = "neutral") -> Color:
	var tones: Array = body_info().get("skin", {}).get("tones", [])
	if tones.size() < 2:
		return Color(0.8, 0.6, 0.5)
	var m := clampf(melanin, 0.0, 1.0) * (tones.size() - 1)
	var i := mini(int(floor(m)), tones.size() - 2)
	var a := Color(String(tones[i]))
	var b := Color(String(tones[i + 1]))
	var f := m - i
	var lin := Vector3(lerpf(_srgb_to_lin(a.r), _srgb_to_lin(b.r), f), lerpf(_srgb_to_lin(a.g), _srgb_to_lin(b.g), f),
			lerpf(_srgb_to_lin(a.b), _srgb_to_lin(b.b), f))
	var ab := undertone_ab(undertone)
	if ab != Vector2.ZERO:
		# the shift in proportion to the tone's lightness, as skin_common.gdshaderinc tone_at
		var lab := _lin_to_oklab(lin)
		var k := clampf(lab.x / 0.87, 0.25, 1.0)
		lin = _oklab_to_lin(lab + Vector3(0.0, ab.x * k * k, ab.y * k))
	return Color(_lin_to_srgb(lin.x), _lin_to_srgb(lin.y), _lin_to_srgb(lin.z))


static func _lin_to_oklab(c: Vector3) -> Vector3:
	var l := pow(maxf(0.4122214708 * c.x + 0.5363325363 * c.y + 0.0514459929 * c.z, 0.0), 1.0 / 3.0)
	var m := pow(maxf(0.2119034982 * c.x + 0.6806995451 * c.y + 0.1073969566 * c.z, 0.0), 1.0 / 3.0)
	var s := pow(maxf(0.0883024619 * c.x + 0.2817188376 * c.y + 0.6299787005 * c.z, 0.0), 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
			1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
			0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


static func _oklab_to_lin(c: Vector3) -> Vector3:
	var l := pow(c.x + 0.3963377774 * c.y + 0.2158037573 * c.z, 3.0)
	var m := pow(c.x - 0.1055613458 * c.y - 0.0638541728 * c.z, 3.0)
	var s := pow(c.x - 0.0894841775 * c.y - 1.2914855480 * c.z, 3.0)
	return Vector3(maxf(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, 0.0),
			maxf(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, 0.0),
			maxf(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s, 0.0))


## Hair colour preset (hair_colors.json) -> {eumelanin, pheomelanin, grey}.
static func hair_preset(id: String) -> Dictionary:
	for p: Dictionary in load_json(HAIR_COLORS).get("presets", []):
		if p.get("id", "") == id:
			return p
	return {"eumelanin": 4.0, "pheomelanin": 0.4, "grey": 0.0}


## Hair colour anchors along eumelanin (linear light), as in hair_common.gdshaderinc.
const EU_AT := [0.0, 1.0, 2.5, 4.0, 5.5, 7.0, 8.0]
const EU_COL := [Vector3(0.8481, 0.6921, 0.4200), Vector3(0.4770, 0.2957, 0.1329), Vector3(0.1706, 0.0890, 0.0397),
		Vector3(0.0550, 0.0272, 0.0134), Vector3(0.0196, 0.0116, 0.0072), Vector3(0.0072, 0.0060, 0.0054),
		Vector3(0.0035, 0.0035, 0.0044)]


## sRGB mean colour of hair (brows, stubble, UI swatches); same model as the shader.
static func hair_color(eu: float, ph: float, grey := 0.0, powder := 0.0) -> Color:
	var e := clampf(eu, 0.0, 8.0)
	var lin: Vector3 = EU_COL[6]
	for i in 6:
		if e <= EU_AT[i + 1]:
			lin = (EU_COL[i] as Vector3).lerp(EU_COL[i + 1], (e - EU_AT[i]) / (EU_AT[i + 1] - EU_AT[i]))
			break
	var t := Vector3(0.12, 0.45, 0.85) * -maxf(ph, 0.0)
	lin *= Vector3(exp(t.x), exp(t.y), exp(t.z))
	lin = lin.lerp(Vector3(0.58, 0.58, 0.56), grey).lerp(Vector3(0.86, 0.85, 0.83), powder)
	return Color(_lin_to_srgb(lin.x), _lin_to_srgb(lin.y), _lin_to_srgb(lin.z))


static func _color(v, fallback: Color) -> Color:
	if v is Color:
		return v
	if v is String and String(v).begins_with("#"):
		return Color(String(v))
	return fallback


static func _hair_params(look: Dictionary) -> Dictionary:
	var h: Dictionary = look.get("hair", {})
	var p := hair_preset(String(h.get("color", "dark_brown"))) if h.has("color") or not h.has("eumelanin") else {}
	return {"eumelanin": float(h.get("eumelanin", p.get("eumelanin", 4.0))),
			"pheomelanin": float(h.get("pheomelanin", p.get("pheomelanin", 0.4))),
			"grey": float(h.get("grey", p.get("grey", 0.0))), "powder": float(h.get("powder", _style_powder(h)))}


## A style's own powder (hair json "powder": the bag wig is powdered unless the look says otherwise).
static func _style_powder(h: Dictionary) -> float:
	var st := String(h.get("style", ""))
	return float((hair_info(st).get("hair", {}) as Dictionary).get("powder", 0.0)) if not st.is_empty() else 0.0


static func skin_material(look: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINTED_SKIN_SHADER if is_stylized(look) else SKIN_SHADER
	if is_stylized(look):
		var c := complexion(look)
		m.set_shader_parameter("paint_head", _texture(PAINT_HEAD))
		m.set_shader_parameter("paint_lines", _texture(PAINT_LINES))
		var pr: Dictionary = body_info().get("paint", {})
		var u: Array = pr.get("u", [-0.251327, 0.251327])
		var hh: Array = pr.get("h", [1.335, 1.605])
		m.set_shader_parameter("paint_rect", Vector4(u[0], u[1], hh[0], hh[1]))
		m.set_shader_parameter("lines", c.lines)
		m.set_shader_parameter("value_contrast", c.contrast)
		m.set_shader_parameter("zone_strength", c.zones)
		m.set_shader_parameter("cool_male", clampf(float(look.get("sex", 0.0)), 0.0, 1.0))
	var hp := _hair_params(look)
	m.set_shader_parameter("melanin", float(look.get("melanin", 0.3)))
	m.set_shader_parameter("undertone", undertone_ab(look.get("undertone", "neutral")))
	m.set_shader_parameter("haemoglobin", float(look.get("haemoglobin", 0.5)))
	m.set_shader_parameter("freckles", float(look.get("freckles", 0.0)))
	m.set_shader_parameter("weathering", float(look.get("weathering", 0.3)))
	m.set_shader_parameter("stubble", float(look.get("stubble", 0.0)))
	m.set_shader_parameter("hair_color", hair_color(hp.eumelanin, hp.pheomelanin, hp.grey, hp.powder))
	m.set_shader_parameter("hide_mask", hide_mask(look.get("hide_regions", [])))
	m.set_shader_parameter("debug_view", int(look.get("debug_view", 0)))
	# character creator: the facial hair style's short hair, scars, pox, paint (FaceExtras adds
	# the style's volume)
	var st := CreatorOptions.facial_hair_style(look)
	m.set_shader_parameter("beard_style", FaceExtras.style_regions(look))
	m.set_shader_parameter("beard_density", float(st.get("density", 1.0)))
	var mk: Dictionary = look.get("marks", {}) if look.get("marks") is Dictionary else {}
	m.set_shader_parameter("mark_scar", int(mk.get("scar", 0)))
	m.set_shader_parameter("mark_pox", float(mk.get("pox", 0.0)))
	m.set_shader_parameter("mark_paint", float(mk.get("paint", 0.0)))
	# the creator's Tattoos row: the look's tattoos where their skin shows (Tattoos, tattoo.gdshaderinc)
	Tattoos.apply(m, look)
	# a world people's mark in the skin (the Keelfolk's keelstone flecks, the Etched's Form veins: people_trait.gdshaderinc)
	set_trait(m, look)
	set_face_warp(m)
	set_head_detail(m)
	var style := String((look.get("hair", {}) as Dictionary).get("style", "")) if look.get("hair") is Dictionary else ""
	m.set_shader_parameter("parting", 1.0 if not style.is_empty() and hair_info(style).get("hair", {}).get("part", "") == "centre" else 0.0)
	# hair v3 strand styles: the scalp under them in the hair's root colour (the style's baked
	# domain, hair json "scalp_mask")
	var hi: Dictionary = hair_info(style).get("hair", {}) if not style.is_empty() else {}
	var mask_path := String(hi.get("scalp_mask", ""))
	var mask: Texture2D = load(mask_path) if not mask_path.is_empty() and ResourceLoader.exists(mask_path) else null
	# (a shaved head's stubble: a lighter tint, hair json "scalp_strength")
	m.set_shader_parameter("scalp_tint", float(hi.get("scalp_strength", 1.0)) if mask != null else 0.0)
	m.set_shader_parameter("scalp_mask", mask)
	if mask != null:
		# the strand styles part their own hair over the tinted scalp (the v1 caps' painted parting
		# groove sat on the forehead below the new hairline)
		m.set_shader_parameter("parting", 0.0)
	# pubic hair: the skin under its strips in the hair's (unpowdered) colour, the body type's pattern
	var bh := not body_hair_glb(look).is_empty()
	m.set_shader_parameter("body_hair", 1.0 if bh else 0.0)
	m.set_shader_parameter("body_hair_male", 1.0 if float(look.get("sex", 0.0)) >= 0.5 else 0.0)
	m.set_shader_parameter("body_hair_color", hair_color(hp.eumelanin, hp.pheomelanin, float(hp.grey) * 0.6, 0.0) * 0.85)
	m.set_shader_parameter("body_hair_mask", _texture(BODY_HAIR_MASK) if bh else null)
	return m


## A world people's mark in the skin (CharacterPeoples.trait_of; the look's `trait` its strength 0..1, the people's
## default when the look has none): people_trait.gdshaderinc's trait_kind (1 keelstone flecks, 2 Form veins; the Thủy
## Vân peoples' 3 scales, 4 plates, 5 river: tv_traits.gdshaderinc), amount, colour and glow. A Thủy Vân trait's colour
## is the look's `trait_tone` (an id of the trait's `tones`, or a hex), its default the first tone. Their order maps
## and the river's gills come from assets/thuyvan/character/traits (tools/thuyvan_art/traits/trait_maps.py).
const TRAIT_KINDS := {"flecks": 1, "veins": 2, "scales": 3, "plates": 4, "river": 5}
const TV_TRAIT_ORDER := "res://assets/thuyvan/character/traits/trait_order_tv.png"
const TV_TRAIT_DETAIL := "res://assets/thuyvan/character/traits/trait_detail_tv.png"
const TV_ASH_MARKS := "res://assets/thuyvan/character/traits/ash_marks_tv.png"


static func set_trait(m: ShaderMaterial, look: Dictionary) -> void:
	var tr := CharacterPeoples.trait_of(look)
	var kind := int(TRAIT_KINDS.get(String(tr.get("kind", "")), 0))
	var amount := clampf(float(look.get("trait", tr.get("default", 0.0))), 0.0, 1.0) if kind > 0 else 0.0
	# the river kind draws its gills and sheen from 0.1 up; the creator's row may sit at 0 for an unmarked Riverborn
	m.set_shader_parameter("trait_kind", kind if amount > 0.001 else 0)
	m.set_shader_parameter("trait_amount", amount)
	var col = tr.get("color", "#8fd6ff")
	var tones = tr.get("tones", {})
	if tones is Dictionary and not (tones as Dictionary).is_empty():
		var tone := String(look.get("trait_tone", ""))
		col = tones.get(tone, tone if tone.begins_with("#") else tones.values()[0])
	m.set_shader_parameter("trait_color", _color(col, Color("#8fd6ff")))
	m.set_shader_parameter("trait_glow", float(tr.get("glow", 1.0)))
	if kind >= 3 or look.has("ash"):
		m.set_shader_parameter("tv_trait_order", _texture(TV_TRAIT_ORDER))
		m.set_shader_parameter("tv_trait_detail", _texture(TV_TRAIT_DETAIL))
		m.set_shader_parameter("tv_ash_marks", _texture(TV_ASH_MARKS))
	# the Riverborn's water tint (skin_common.gdshaderinc tone_at): the look's `tint`, the people's default otherwise
	var tint = CharacterPeoples.people(String(look.get("people", ""))).get("tint")
	var t := 0.0
	if tint is Dictionary:
		t = clampf(float(look.get("tint", (tint as Dictionary).get("default", 0.0))), 0.0, 1.0)
		m.set_shader_parameter("water_tint_hue", float((tint as Dictionary).get("hue", 230.0)))
		m.set_shader_parameter("water_tint_chroma", float((tint as Dictionary).get("chroma", 0.062)))
	m.set_shader_parameter("water_tint", t)
	# the rite's ash marks (a marking anyone may wear: creator.json markings with an `ash` list)
	var ash: Array = look.get("ash", []) if look.get("ash") is Array else []
	m.set_shader_parameter("tv_ash", Vector3(1.0 if ash.has("thumbprint") else 0.0, 1.0 if ash.has("cheeks") else 0.0,
			1.0 if ash.has("hands") else 0.0))


## The v3 head's photographed skin detail (body.json face.detail_rect; skin.gdshader head_detail).
const HEAD_DETAIL := "res://assets/character/body/head_detail.png"


static func set_head_detail(m: ShaderMaterial) -> void:
	var r = (body_info().get("face", {}) as Dictionary).get("detail_rect", null)
	if r is Array and (r as Array).size() == 4 and ResourceLoader.exists(HEAD_DETAIL):
		m.set_shader_parameter("head_detail", _texture(HEAD_DETAIL))
		m.set_shader_parameter("head_detail_rect", Vector4(r[0], r[1], r[2], r[3]))
		m.set_shader_parameter("has_head_detail", 1)
		# 1.8: at game distance the photographed lid shading and skin variation read; stronger
		# draws the lash line like paint
		m.set_shader_parameter("head_detail_strength", 1.8)
	# body v4: the whole body's detail (MakeHuman's atlas) with the areolae
	if ResourceLoader.exists(BODY_DETAIL):
		m.set_shader_parameter("body_detail", _texture(BODY_DETAIL))
		m.set_shader_parameter("has_body_detail", 1)


## The v3 head's face-coordinate warp onto the v2 regions (body.json face.warp; face_detail.gdshaderinc).
static func set_face_warp(m: ShaderMaterial) -> void:
	var w: Dictionary = (body_info().get("face", {}) as Dictionary).get("warp", {})
	var h: Array = w.get("h", [])
	var u: Array = w.get("u", [])
	if h.size() == 8 and u.size() == 4:
		m.set_shader_parameter("fd_h0", Vector4(h[0], h[1], h[2], h[3]))
		m.set_shader_parameter("fd_h1", Vector4(h[4], h[5], h[6], h[7]))
		m.set_shader_parameter("fd_u", Vector4(u[0], u[1], u[2], u[3]))


## (u, h) face coordinates of the v3 head warped onto the v2 regions: the CPU twin of
## face_detail.gdshaderinc face_coords().
static func warp_face_coords(u: float, h: float) -> Vector2:
	var w: Dictionary = (body_info().get("face", {}) as Dictionary).get("warp", {})
	var kh: Array = w.get("h", [])
	var th: Array = w.get("h_v2", [])
	var ku: Array = [0.0] + w.get("u", [])
	var tu: Array = [0.0] + w.get("u_v2", [])
	if kh.size() != 8 or th.size() != 8 or ku.size() != 5 or tu.size() != 5:
		return Vector2(u, h)
	return Vector2(signf(u) * _pwl(absf(u), ku, tu), _pwl(h, kh, th))


static func _pwl(x: float, k: Array, t: Array) -> float:
	if x <= float(k[0]):
		return float(t[0]) + x - float(k[0])
	for i in range(1, k.size()):
		if x <= float(k[i]):
			return lerpf(float(t[i - 1]), float(t[i]), (x - float(k[i - 1])) / maxf(float(k[i]) - float(k[i - 1]), 1e-6))
	return float(t[-1]) + x - float(k[-1])


static func eye_material(look: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = EYE_SHADER
	var iris = look.get("iris", "brown")
	var eyes := eye_colors()
	if iris is String and eyes.has(iris):
		iris = eyes[iris]
	m.set_shader_parameter("iris_color", _color(iris, Color("#4a2e1a")))
	m.set_shader_parameter("stylized", 1 if is_stylized(look) else 0)
	# reflective eyes (Thủy Vân: the people's `reflect_eye` {tapetum, levels}; the look's `reflect_eye` Off/Faint/Strong
	# as 0/0.5/1); the environment sets `tv_night`
	var re = CharacterPeoples.people(String(look.get("people", ""))).get("reflect_eye")
	if re is Dictionary:
		m.set_shader_parameter("reflect_eye", clampf(float(look.get("reflect_eye", (re as Dictionary).get("default", 0.0))), 0.0, 1.0))
		m.set_shader_parameter("tapetum_color", _color((re as Dictionary).get("tapetum", "#9fd08a"), Color("#9fd08a")))
	return m


## Brows and lashes: the brows take the hair colour (a little lighter for very dark hair,
## greyer with age), the lashes are darker.
static func face_hair_material(look: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FACE_HAIR_SHADER
	var hp := _hair_params(look)
	var brow := hair_color(hp.eumelanin * 0.95, hp.pheomelanin, hp.grey * 0.6, 0.0)
	m.set_shader_parameter("brow_color", brow)
	m.set_shader_parameter("lash_color", hair_color(maxf(hp.eumelanin, 5.5), hp.pheomelanin * 0.5, 0.0, 0.0))
	var b: Dictionary = look.get("brows", {})
	m.set_shader_parameter("brow_thickness", float(b.get("thickness", 0.7)))
	m.set_shader_parameter("brow_arch", float(b.get("arch", 0.5)))
	m.set_shader_parameter("brow_density", float(b.get("density", 0.8)))
	m.set_shader_parameter("lash_length", 1.0 if float(look.get("sex", 0.0)) < 0.5 else 0.85)
	m.set_shader_parameter("stylized", 1 if is_stylized(look) else 0)
	return m


## Face feature weights {face_*: w} of a look: a peoples.json preset id, a legacy body.json
## face preset, or a dictionary (missing features are 0).
static func face_weights(look: Dictionary) -> Dictionary:
	var face = look.get("face", {})
	if face is String:
		var pr := CharacterPeoples.preset(face)
		face = pr.get("face", (body_info().get("face_presets", {}) as Dictionary).get(face, {}))
	var out := {}
	for n: String in body_info().get("shapes", {}).get("names", []):
		if n.begins_with("face_"):
			out[n] = float((face as Dictionary).get(n, 0.0))
	return out


static func hair_material(look: Dictionary, style: String, cards := false, textured := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HAIR_TEX_SHADER if textured else (HAIR_CARDS_SHADER if cards else HAIR_SHADER)
	if textured:
		var tp := String((hair_info(style).get("hair", {}) as Dictionary).get("strand_map", ""))
		if not tp.is_empty() and ResourceLoader.exists(tp):
			m.set_shader_parameter("strands", load(tp))
		m.set_shader_parameter("edge_feather", float((hair_info(style).get("hair", {}) as Dictionary).get("edge_feather", 0.0)))
	var hp := _hair_params(look)
	var h: Dictionary = look.get("hair", {})
	for k in hp:
		m.set_shader_parameter(k, hp[k])
	var info := hair_info(style)
	var tex := String(info.get("hair", {}).get("texture", "straight"))
	m.set_shader_parameter("hair_texture", HAIR_TEXTURES.get(tex, 0))
	var accent = h.get("accent", null)
	if accent == null:
		for z: Dictionary in info.get("zones", []):
			if int(z.get("zone", 0)) == 1 and z.get("default") != null:
				accent = (z.get("palette_hex", {}) as Dictionary).get(z.default, "#1c1b20")
	m.set_shader_parameter("accent_color", _color(accent, Color("#1c1b20")))
	m.set_shader_parameter("accent_metal", float(h.get("accent_metal", 0.0)))
	var hz := []
	for z in look.get("hide_hair_zones", []):
		hz.append("hair_" + String(z))
	m.set_shader_parameter("hide_mask", hide_mask(hz))
	m.set_shader_parameter("debug_view", int(look.get("debug_view", 0)))
	m.set_shader_parameter("stylized", 1 if is_stylized(look) else 0)
	return m


## Applies a look to a CharacterBodyMesh made with attach_parts() (part "body" = body.glb;
## the hair part is added or replaced from look.hair.style, "" for none). `parts` limits the
## material and shape changes to those part tags (default: every mesh of the body).
static func apply_look(body: CharacterBodyMesh, look: Dictionary, parts := []) -> void:
	var h: Dictionary = look.get("hair", {})
	if h.has("style"):
		var style := String(h.style)
		if style.is_empty():
			body.remove_part("hair")
		elif String(body.get_meta("hair_style", "")) != style or body.part_meshes("hair").is_empty():
			body.add_part("hair", HAIR_DIR + style + ".glb")
			body.set_meta("hair_style", style)
	# pubic hair (body_hair_f / _m.glb): on the bare body only (the full fit, nothing over the pelvis); with
	# `parts`, only when they name it (PlayerAppearance.dress: ["head", "body_hair"])
	if parts.is_empty() or "body_hair" in parts:
		var bh_path := body_hair_glb(look)
		if not bh_path.is_empty() and (String(body.get_meta("body_hair", "")) != bh_path or body.part_meshes("body_hair").is_empty()):
			body.add_part("body_hair", bh_path)
			body.set_meta("body_hair", bh_path)
		elif bh_path.is_empty() and not body.part_meshes("body_hair").is_empty():
			body.remove_part("body_hair")
			body.set_meta("body_hair", "")
	var meshes: Array = []
	if parts.is_empty():
		meshes = body.meshes
	else:
		for t in parts + ["hair"]:
			meshes += body.part_meshes(String(t))
	var sex := float(look.get("sex", 0.0))
	var head_only := String(look.get("outfit_fit", "full")) == "head"
	var shapes := face_weights(look)
	shapes["sex"] = 0.0 if head_only else sex
	shapes["sex_head"] = sex if head_only else 0.0
	shapes["hat_fit"] = float(look.get("hat_fit", 0.0))
	# the stylized head: one fixed shape for every face (FaceBlink drives blink_style with it), and
	# the male fit's heroic jaw, chin and brow on top at the look's sex weight
	shapes["style"] = 1.0 if is_stylized(look) else 0.0
	shapes["style_male"] = clampf(sex, 0.0, 1.0) if is_stylized(look) else 0.0
	# the bust gauge (women) and each man's size: body v4's breast_* / genital_* shapes
	var body_sex := 0.0 if head_only else clampf(sex, 0.0, 1.0)
	var bust := clampf(float(look.get("bust", 0.0)), -1.0, 1.0)
	var gen := clampf(float(look.get("genital", 0.0)), -1.0, 1.0)
	shapes["breast_large"] = maxf(bust, 0.0) * (1.0 - body_sex) * (0.0 if head_only else 1.0)
	shapes["breast_small"] = maxf(-bust, 0.0) * (1.0 - body_sex) * (0.0 if head_only else 1.0)
	shapes["genital_large"] = maxf(gen, 0.0) * body_sex
	shapes["genital_small"] = maxf(-gen, 0.0) * body_sex
	# soft tissue (CharacterBodyMesh): a woman's bare chest moves the most (a fuller bust more), a man's
	# hardly; a garment over the chest holds it stiff (soft_support; hide_regions "chest_front"); a
	# man's genitals move only bare (nothing over "pelvis_center")
	var hidden: Array = look.get("hide_regions", [])
	body.soft_tissue = 0.0 if head_only else (1.0 - 0.85 * body_sex) * (1.0 + 0.3 * bust * (1.0 - body_sex))
	body.soft_support = 1.0 if "chest_front" in hidden else 0.0
	body.genital_swing = 0.0 if head_only or "pelvis_center" in hidden else body_sex
	for mi: MeshInstance3D in meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		for n in shapes:
			var i := mi.find_blend_shape_by_name(n)
			if i >= 0:
				mi.set_blend_shape_value(i, shapes[n])
	var skin := skin_material(look)
	var eye := eye_material(look)
	var fh := face_hair_material(look)
	var style := String(body.get_meta("hair_style", ""))
	var hair := hair_material(look, style) if not style.is_empty() else null
	var cards := hair_material(look, style, true) if not style.is_empty() else null
	var tex := hair_material(look, style, false, true) if not style.is_empty() else null
	var bh := body_hair_material(look) if not body.part_meshes("body_hair").is_empty() else null
	for mi: MeshInstance3D in meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var surf := mat.resource_name if mat else ""
			if surf == "skin" or surf == "face_skin":
				mi.set_surface_override_material(s, skin)
			elif surf == "eye":
				mi.set_surface_override_material(s, eye)
			elif surf == "face_hair":
				mi.set_surface_override_material(s, fh)
			elif hair and surf == style:
				mi.set_surface_override_material(s, hair)
			elif cards and surf == style + "_cards":
				mi.set_surface_override_material(s, cards)
			elif tex and surf == style + "_tex":
				mi.set_surface_override_material(s, tex)
			elif bh and surf == BODY_HAIR_SURFACE:
				mi.set_surface_override_material(s, bh)
	FaceExtras.apply(body, look)


## The pubic hair part for the look ("" when none shows: the head-only fit, clothes over the pelvis,
## look body_hair 0).
static func body_hair_glb(look: Dictionary) -> String:
	if String(look.get("outfit_fit", "full")) == "head" or "pelvis_center" in (look.get("hide_regions", []) as Array) \
			or float(look.get("body_hair", 1.0)) <= 0.0:
		return ""
	var p := BODY_HAIR_GLB % ("m" if float(look.get("sex", 0.0)) >= 0.5 else "f")
	return p if ResourceLoader.exists(p) else ""


## The pubic hair's strips: the head hair's colour (never powdered; it greys later than the head's), the
## atlas's coily strands, a little darker.
static func body_hair_material(look: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HAIR_TEX_SHADER
	m.set_shader_parameter("strands", load(HAIR_ATLAS))
	m.set_shader_parameter("edge_feather", 0.3)
	var hp := _hair_params(look)
	hp["powder"] = 0.0
	hp["grey"] = float(hp.grey) * 0.6
	for k in hp:
		m.set_shader_parameter(k, hp[k])
	m.set_shader_parameter("hair_texture", HAIR_TEXTURES.coily)
	m.set_shader_parameter("brightness", 0.85)
	m.set_shader_parameter("hide_mask", hide_mask([]))
	return m
