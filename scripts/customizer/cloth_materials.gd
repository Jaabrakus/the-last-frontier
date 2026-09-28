class_name ClothMaterials
extends RefCounted
## Fabric materials (assets/character/shaders/cloth.gdshader) for the player's legacy outfit
## (actor_b_body.glb: Clothes, Gear, Hat) and for the customizer's garments (catalog.json
## zones), and fur materials (fur_shell.gdshader) for their fur surfaces.
##
##   ClothMaterials.dress_legacy(body)                         # PlayerAppearance.dress() calls it
##   var mats := ClothMaterials.garment_materials(entry, {"0": "fur_wolf"})   # surface -> material
##   ClothMaterials.set_legacy_hidden(body, [LEGACY_PIECES.coat, ...])
##
## Fabric kits: assets/character/fabrics (tools/character/make_fabrics.py, from the approved CC0
## Poly Haven scans). The legacy glb's UVs, piece codes and wear / dirt / sweat masks come from
## tools/character/cloth_bake.py; the tints are the glb's own colours, so the outfit keeps its
## look and value in the game's light and gains weave, wear, dirt and sweat.

const CLOTH_SHADER := preload("res://assets/character/shaders/cloth.gdshader")
const FUR_SHADER := preload("res://assets/character/shaders/fur_shell.gdshader")
const FABRICS_JSON := "res://assets/character/fabrics/fabrics.json"
const DETAIL := "res://assets/character/fabrics/fabric_detail.jpg"
const NORMAL := "res://assets/character/fabrics/fabric_normal.jpg"
const LEGACY_MESHES := ["Clothes", "Gear", "Hat"]
## Piece codes of the legacy outfit (UV2.x; tools/character/cloth_bake.py LEGACY_PIECES). Brass
## fittings are BRASS_BASE + the code of the piece they sit on (waistcoat buttons, shoe buckles).
const LEGACY_PIECES := {
	"coat": 1, "waistcoat": 2, "linen_stock": 3, "linen_cuffs": 4, "breeches": 5, "leggings": 6, "garter": 7,
	"shoe": 8, "belt": 40, "strap": 41, "pouch": 42, "horn": 43, "gear_brass": 44, "wood": 45, "horn_tip": 46,
	"felt": 50, "hat_tape": 51, "hat_brass": 52,
}
const BRASS_BASE := 16
## Legacy surfaces: material name -> [fabric code, wear mode, sheen, hem width (m), extra].
## Wear modes (cloth.gdshader): 0 cloth, 1 leather, 2 metal, 3 fur base, 4 horn / wood.
## extra: detail / normal / roughness overrides and mask strengths.
const LEGACY_SPEC := {
	"coat": ["WOOL", 0, 0.3, 0.02, {}],
	"waistcoat": ["WOOL", 0, 0.22, 0.012, {"normal": 0.4}],
	"linen": ["LIN", 0, 0.06, 0.008, {"sweat": 1.3}],
	"breeches": ["SUEDE", 1, 0.08, 0.0, {"detail": 0.6, "wear": 1.2}],
	"leggings": ["WOOL", 0, 0.28, 0.015, {}],
	"garter": ["TWILL", 0, 0.1, 0.0, {"tile": 0.12}],
	"shoe": ["LEA", 1, 0.0, 0.0, {"rough": 0.8, "dirt": 0.55}],
	"brass": ["FLAT", 2, 0.0, 0.0, {"metal": 1.0}],
	"belt": ["LEA", 1, 0.0, 0.0, {"tile": 0.3}],
	"strap": ["LEA", 1, 0.0, 0.0, {"tile": 0.3}],
	"pouch": ["LEA", 1, 0.0, 0.0, {"tile": 0.3, "detail": 0.55}],
	"horn": ["FLAT", 4, 0.0, 0.0, {"rough": 0.6}],
	"wood": ["FLAT", 4, 0.0, 0.0, {}],
	"horn_tip": ["FLAT", 4, 0.0, 0.0, {}],
	"felt": ["WOOL", 0, 0.2, 0.0, {"normal": 0.15, "detail": 0.45, "rough": 1.1, "sweat": 1.2}],
	"hat_tape": ["TWILL", 0, 0.1, 0.0, {"tile": 0.1}],
}
## Catalog zone roles -> wear mode and sheen.
const ROLE_MODE := {"leather": 1, "metal": 2, "button": 4, "fur": 3, "quill": 4, "bead": 4}
const ROLE_SHEEN := {"cloth": 0.28, "lining": 0.1, "fur": 0.3, "trim": 0.15, "band": 0.15, "ribbon": 0.05,
		"leather": 0.0, "metal": 0.0, "button": 0.0, "fringe": 0.05, "wrap": 0.1}
## Fabric code of a felt hat: WOOL with a soft nap (costume bible 7).
const FELT_WORDS := ["hat", "tricorn", "tricorne", "cap"]

static var _fabrics := {}
static var _detail: TextureLayered
static var _normal: TextureLayered


static func fabrics() -> Dictionary:
	if _fabrics.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(FABRICS_JSON)) if FileAccess.file_exists(FABRICS_JSON) else null
		_fabrics = (d.get("fabrics", {}) if d is Dictionary else {}) as Dictionary
	return _fabrics


static func fabric(code: String) -> Dictionary:
	var f: Dictionary = fabrics()
	return f.get(code, f.get("FLAT", {"layer": 8, "tile_m": 0.27, "detail_strength": 0.0, "normal_strength": 0.0, "roughness_mul": 1.0}))


static func _textures() -> void:
	if _detail == null and ResourceLoader.exists(DETAIL):
		_detail = load(DETAIL) as TextureLayered
		_normal = load(NORMAL) as TextureLayered


## A cloth material with the kit textures bound and every zone set to `code`.
static func new_cloth() -> ShaderMaterial:
	_textures()
	var m := ShaderMaterial.new()
	m.shader = CLOTH_SHADER
	if _detail:
		m.set_shader_parameter("fabric_detail", _detail)
		m.set_shader_parameter("fabric_normal", _normal)
	return m


## Sets zone `z` of a cloth material: fabric code, tint (sRGB Color), wear mode, sheen and
## overrides {detail, normal, rough, tile, metal}.
static func set_zone(m: ShaderMaterial, z: int, code: String, tint: Color, mode: int, sheen: float, extra := {}) -> void:
	var f := fabric(code)
	var packs := {"layer": float(f.get("layer", 8)), "tile_m": float(extra.get("tile", f.get("tile_m", 0.27))),
			"detail_strength": float(extra.get("detail", f.get("detail_strength", 0.5))),
			"normal_strength": float(extra.get("normal", f.get("normal_strength", 0.5))),
			"roughness_mul": float(extra.get("rough", f.get("roughness_mul", 1.0))),
			"metal": float(extra.get("metal", 0.0)), "sheen": sheen, "wear_mode": float(mode)}
	for k: String in packs:
		var v = m.get_shader_parameter(k)
		var p: Vector4 = v if v is Vector4 else _default_pack(k)
		p[z] = packs[k]
		m.set_shader_parameter(k, p)
	m.set_shader_parameter("tint%d" % z, lin4(tint))


## A colour for the shaders' linear colour uniforms, as a Vector4 (a Color set on a vec4 uniform
## may be converted by the engine; a Vector4 never is).
static func lin4(c: Color) -> Vector4:
	var l := c.srgb_to_linear()
	return Vector4(l.r, l.g, l.b, c.a)


static func _default_pack(k: String) -> Vector4:
	match k:
		"layer": return Vector4(1, 1, 1, 1)
		"tile_m": return Vector4(0.274, 0.274, 0.274, 0.274)
		"detail_strength": return Vector4(0.7, 0.7, 0.7, 0.7)
		"normal_strength": return Vector4(0.5, 0.5, 0.5, 0.5)
		"roughness_mul": return Vector4(1, 1, 1, 1)
		"sheen": return Vector4(0.2, 0.2, 0.2, 0.2)
	return Vector4.ZERO


static func _seed(s: String) -> float:
	return float(hash(s) % 1000) * 0.113


# --- legacy outfit ------------------------------------------------------------------------------

## A new cloth material for a legacy surface (by the glb material name), tinted by `base` (the
## glb colour).
static func legacy_material(surface: String, base: Color) -> ShaderMaterial:
	var spec: Array = LEGACY_SPEC.get(surface, ["WOOL", 0, 0.2, 0.0, {}])
	var m := new_cloth()
	var extra: Dictionary = spec[4]
	for z in 4:
		set_zone(m, z, String(spec[0]), base, int(spec[1]), float(spec[2]), extra)
	m.set_shader_parameter("hem_width", float(spec[3]))
	m.set_shader_parameter("seed", _seed(surface))
	# the shader's defaults scaled per surface
	m.set_shader_parameter("dirt_amount", 1.2 * float(extra.get("dirt", 1.0)))
	m.set_shader_parameter("wear_amount", 1.3 * float(extra.get("wear", 1.0)))
	m.set_shader_parameter("sweat_amount", float(extra.get("sweat", 1.0)))
	return m


## Replaces the materials of the legacy Clothes, Gear and Hat meshes of `body` with cloth
## materials (each body gets its own, so hiding pieces or moving the gear out on one body does
## not change another). Returns the number of surfaces dressed.
static func dress_legacy(body: CharacterBodyMesh) -> int:
	var n := 0
	for mi: MeshInstance3D in body.meshes:
		if not is_instance_valid(mi) or not String(mi.name) in LEGACY_MESHES or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var cur := mi.get_surface_override_material(s)
			if cur is ShaderMaterial and (cur as ShaderMaterial).shader == CLOTH_SHADER:
				n += 1
				continue
			var src := mi.mesh.surface_get_material(s)
			var base := Color(0.5, 0.45, 0.4)
			var sname: String = src.resource_name if src else ""
			if src is BaseMaterial3D:
				base = (src as BaseMaterial3D).albedo_color
			if sname.is_empty():
				sname = mi.mesh.surface_get_name(s)
			mi.set_surface_override_material(s, legacy_material(sname, base))
			n += 1
	return n


## Hide mask (Vector2i for the uvec2 uniform) of piece / region codes.
static func code_mask(codes: Array) -> Vector2i:
	var lo := 0
	var hi := 0
	for c in codes:
		var r := int(c)
		if r < 0 or r > 63:
			continue
		if r < 32:
			lo |= 1 << r
		else:
			hi |= 1 << (r - 32)
	if lo >= 0x80000000:
		lo -= 0x100000000
	if hi >= 0x80000000:
		hi -= 0x100000000
	return Vector2i(lo, hi)


## Hides the legacy pieces `codes` (LEGACY_PIECES values) on every legacy surface of `body`.
static func set_legacy_hidden(body: CharacterBodyMesh, codes: Array) -> void:
	var mask := code_mask(codes)
	for mat: ShaderMaterial in legacy_materials(body):
		mat.set_shader_parameter("hide_mask", mask)


## Moves the legacy gear out over a thicker coat: belt, straps (m along their normal) and the
## rigid pouch and horn (m outward).
static func set_gear_push(body: CharacterBodyMesh, belt: float, strap: float, rigid: float) -> void:
	for mat: ShaderMaterial in legacy_materials(body, ["Gear"]):
		mat.set_shader_parameter("push_m", Vector4(belt, strap, rigid, 0.0))


static func legacy_materials(body: CharacterBodyMesh, meshes := LEGACY_MESHES) -> Array:
	var out := []
	for mi: MeshInstance3D in body.meshes:
		if not is_instance_valid(mi) or not String(mi.name) in meshes or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m is ShaderMaterial and (m as ShaderMaterial).shader == CLOTH_SHADER:
				out.append(m)
	return out


# --- catalog garments ---------------------------------------------------------------------------

## A palette token ("stroud_blue", "fur_wolf") or "#hex" as an sRGB colour: the zone's
## palette_hex first, then TOKEN_HEX; unknown tokens are grey.
static func token_color(entry_zone: Dictionary, token: String) -> Color:
	var ph: Dictionary = entry_zone.get("palette_hex", {})
	var h := String(ph.get(token, token))
	if not h.begins_with("#"):
		h = String(TOKEN_HEX.get(h, "#808080"))
	return Color.html(h)


## Bible palette tokens that catalog entries reference outside their own palette_hex
## (tools/character/lib/materials.py TOKENS; band colours).
const TOKEN_HEX := {
	"stroud_blue": "#1E2B4A", "stroud_red": "#8A1C1F", "madder_red": "#8E2B21", "logwood_black": "#1C1B20",
	"ranger_green": "#3B4A2E", "linen_unbleached": "#C8BA9A", "walnut_brown": "#5A3F2C", "buckskin_smoked": "#A07E55",
	"ribbon_red": "#B2202C", "ribbon_blue": "#2D4F8C", "ribbon_black": "#151417", "ribbon_green": "#2E6B40",
	"brass": "#B58F4A", "pewter": "#9A9C9A", "silver": "#C8CACC", "leather_brown": "#5B3D26", "drab": "#8B7A5C",
	"slate_grey": "#6B6A66", "linen_white": "#E8E3D3", "grey_white": "#D4D0C3", "bead_white": "#EEEBE3",
}


## Materials for a catalog entry's surfaces: {surface (glb material name): Material}. `colors`
## maps a zone index (String or int) to a palette token or "#hex" (defaults: the zone's default);
## "bands" = [rows, token] for striped zones; "fur" = a fur preset token for fur surfaces.
static func garment_materials(entry: Dictionary, colors := {}) -> Dictionary:
	var out := {}
	var zones: Array = entry.get("zones", [])
	var fur: Dictionary = entry.get("fur", {})
	var id := String(entry.get("id", ""))
	var felt := false
	for w: String in FELT_WORDS:
		if id.contains(w):
			felt = true
	for s: Dictionary in entry.get("surfaces", []):
		var sname := String(s.get("name", ""))
		if not fur.is_empty() and sname == String(fur.get("surface", "")):
			out[sname] = fur_material(entry, colors)
			continue
		var m := new_cloth()
		for zi in 4:
			var zd: Dictionary = zones[mini(zi, zones.size() - 1)] if not zones.is_empty() else {}
			var role := String(zd.get("role", "cloth"))
			var code := String(zd.get("fabric", "WOOL"))
			var tok := String(colors.get(str(zi), colors.get(zi, zd.get("default", "#808080"))))
			var tint := token_color(zd, tok)
			var extra := {}
			if role == "metal" or (code == "FLAT" and tok in ["brass", "pewter", "silver", "gold_lace", "silver_lace", "false_gold"]):
				extra["metal"] = 1.0
			if role == "fur":
				# the base under the shells takes the pile's root colour
				var preset: Dictionary = fur.get("presets", {}).get(tok, {})
				if preset.has("root"):
					tint = Color.html(String(preset.root))
			if felt and code == "WOOL":
				extra.merge({"normal": 0.15, "detail": 0.45, "rough": 1.1})
			var mode := int(ROLE_MODE.get(role, 0))
			if code in ["LEA", "SUEDE"] and mode == 0:
				mode = 1
			if extra.get("metal", 0.0) > 0.5:
				mode = 2
			set_zone(m, zi, code, tint, mode, float(ROLE_SHEEN.get(role, 0.2)) * (1.4 if felt else 1.0), extra)
			var b := hem_bands(zd)
			if zi == 0 and not b.is_empty():
				var rows := int(colors.get("bands_rows", b.get("default_rows", 0)))
				var btok := String(colors.get("bands", b.get("default", "stroud_blue")))
				m.set_shader_parameter("band_rows", Vector4(rows, float(b.get("offset_m", 0.05)),
						float(b.get("width_m", 0.035)), float(b.get("gap_m", 0.025))))
				m.set_shader_parameter("band_color", lin4(token_color(zd, btok)))
		m.set_shader_parameter("seed", _seed(id + sname))
		m.set_shader_parameter("hem_width", 0.0 if felt else 0.018)
		out[sname] = m
	return out


## The zone's hem stripes when the cloth shader draws them: rows of one colour by the distance to
## the hem (CUSTOM0.x) in the capots' schema {default_rows, offset_m, width_m, gap_m, palette,
## default}. The woodlands items' ribbon and quill rows (row_width, a list of colours) are not
## drawn yet: {}.
static func hem_bands(zd: Dictionary) -> Dictionary:
	var b = zd.get("bands")
	return b if b is Dictionary and (b as Dictionary).has("width_m") else {}


## The fur material of an entry's fur surface: the preset of the fur zone's colour token.
static func fur_material(entry: Dictionary, colors := {}) -> ShaderMaterial:
	var fur: Dictionary = entry.get("fur", {})
	var zones: Array = entry.get("zones", [])
	var zi := int(fur.get("palette_zone", 0))
	var zd: Dictionary = zones[zi] if zi < zones.size() else {}
	var tok := String(colors.get("fur", colors.get(str(zi), colors.get(zi, zd.get("default", "")))))
	var presets: Dictionary = fur.get("presets", {})
	var p: Dictionary = presets.get(tok, presets.values()[0] if not presets.is_empty() else {})
	var m := ShaderMaterial.new()
	m.shader = FUR_SHADER
	var names: Dictionary = fur.get("uniforms", {})
	for u: String in names:
		var key := String(names[u])
		if not p.has(key):
			continue
		var v = p[key]
		if v is String and String(v).begins_with("#"):
			var l := Color.html(v).srgb_to_linear()
			m.set_shader_parameter(u, Vector3(l.r, l.g, l.b))
		elif u == "fur_length":
			m.set_shader_parameter(u, float(v) * float(fur.get("length_scale", 1.0)))
		else:
			m.set_shader_parameter(u, v)
	# the shell LOD keeps every n-th shell by its index: the shader needs the surface's shell count
	# (10 on the trim, mittens and moccasins, 12 elsewhere)
	var stats: Dictionary = fur.get("stats", {})
	m.set_shader_parameter("shell_count", int(stats.get("shells", 12)))
	return m
