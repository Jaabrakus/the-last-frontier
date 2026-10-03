class_name ClothMaterials
extends RefCounted
## Fabric materials (assets/character/shaders/cloth.gdshader) for the player's legacy outfit
## (actor_b_body.glb: Clothes, Gear, Hat) and for the customizer's garments (catalog.json
## zones), and fur materials (fur_shell.gdshader) for their fur surfaces.
##
##   ClothMaterials.dress_legacy(body)                         # PlayerAppearance.dress() calls it
##   var mats := ClothMaterials.garment_materials(entry, {"0": "fur_wolf"})   # surface -> material
##   ClothMaterials.set_legacy_hidden(body, [LEGACY_PIECES.coat, ...])
##   var spec := ClothMaterials.pattern_spec(zone, "check_blue", {"pattern": "check"})   # a zone's woven pattern
##
## Patterns (2026-10-03): a cloth zone can show a check, stripes, a plaid (a sett: SETTS_JSON or a catalog / look list of
## stripes), ticking, a small calico print or a herringbone, drawn by the cloth shader on the UVs (pattern_spec says
## which and in what colours: the catalog zone's "pattern" data, the look's "pattern" and colour keys).
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
## The sett library (SETTS_JSON: name -> sett) and its palette; every palette token the catalog's zones name (token_color).
static var _setts := {}
static var _setts_hex := {}
static var _catalog_hex := {}


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
		h = String(TOKEN_HEX.get(h, known_hex(h)))
	return Color.html(h)


## The "#hex" of a palette token that a zone's own palette does not list (a pattern's or a sett's colour): the sett
## library's palette, else any catalog zone's palette_hex (together they hold every cloth2 palette token); "#808080"
## when none knows it.
static func known_hex(token: String) -> String:
	if _catalog_hex.is_empty():
		for e: Variant in PlayerOutfit.catalog().values():
			for zd: Variant in (e as Dictionary).get("zones", []) if e is Dictionary else []:
				var ph: Variant = (zd as Dictionary).get("palette_hex") if zd is Dictionary else null
				if ph is Dictionary:
					_catalog_hex.merge(ph)
		_catalog_hex["\n"] = "#808080"            # (loaded, even when the catalog is empty)
	setts()
	return String(_setts_hex.get(token, _catalog_hex.get(token, "#808080")))


## The sRGB tint a zone renders in for token `tok` with the look's `colors`: the token's colour, or, for a zone in a
## pattern (pattern_spec: the catalog zone's "pattern" {options, default, <name>: {colors, scale_m ...}} and the look's
## "pattern" / "<name>" keys), the pattern's mean colour (its stripes by their widths), as the cloth reads from a few
## metres (2026-10-03: a check zone in its base token rendered solid navy). The cloth shader draws the pattern itself
## (set_patterns); the tint stays its mean. `pz`: the garment's pattern zone (pattern_zone; -1: zone 0).
static func zone_tint(zd: Dictionary, tok: String, colors := {}, pz := -1) -> Color:
	var spec := pattern_spec(zd, tok, colors, pz)
	if spec.is_empty():
		return token_color(zd, tok)
	var sum := Color(0, 0, 0, 0)
	var calico := int(spec.kind) == int(PATTERN_KIND.calico)
	for i in (spec.table as Array).size():
		var row: Array = spec.table[i]
		var c := token_color(zd, str(row[0]))
		var w: float = [0.905, 0.071, 0.024][i] if calico and i < 3 else float(row[1])
		sum += Color(c.r * w, c.g * w, c.b * w, w)
	if sum.a <= 0.0:
		return token_color(zd, tok)
	return Color(sum.r / sum.a, sum.g / sum.a, sum.b / sum.a, 1.0)


## The colours of the pattern a zone shows for `tok` and the look's `colors` ([] when it is plain): see pattern_spec.
static func pattern_colors(zd: Dictionary, tok: String, colors := {}, pz := -1) -> Array:
	var spec := pattern_spec(zd, tok, colors, pz)
	return (spec.colors as Array).duplicate() if not spec.is_empty() else []


# --- patterns -----------------------------------------------------------------------------------

## The patterns the cloth shader draws, in the creator's order, and their cloth.gdshader pat_kind (ticking is a stripe
## table); other names a catalog zone or a look uses for them (the cloth2 specs' "stripes", "calico_small"). A name not
## here ("chevron", "beads", "end_stripes", "lace_stripes") is drawn plain.
const PATTERNS := ["none", "check", "stripe", "plaid", "ticking", "calico", "herringbone"]
const PATTERN_KIND := {"none": 0, "check": 1, "plaid": 2, "stripe": 3, "ticking": 3, "calico": 4, "herringbone": 5}
const PATTERN_ALIAS := {"stripes": "stripe", "striped": "stripe", "tartan": "plaid", "sett": "plaid",
		"calico_small": "calico", "print": "calico", "gingham": "check", "checked": "check", "checks": "check"}
const PATTERN_LABELS := {"none": "Plain", "check": "Check", "stripe": "Stripes", "plaid": "Plaid", "ticking": "Ticking",
		"calico": "Calico", "herringbone": "Herringbone"}
## A pattern's repeat (m) and colours where the catalog zone does not give them (the zone's own colour takes the first
## place); a plaid's sett by name (SETTS_JSON).
const PATTERN_DEFAULTS := {
	"check": {"scale_m": 0.012, "colors": ["check_blue", "linen_white"]},
	"stripe": {"scale_m": 0.016, "colors": ["madder_red", "linen_unbleached"]},
	"plaid": {"scale_m": 0.16, "sett": "hill_green"},
	"ticking": {"scale_m": 0.03, "colors": ["linen_white", "indigo_mid"]},
	"calico": {"scale_m": 0.022, "colors": ["linen_white", "madder_red", "indigo_mid"]},
	"herringbone": {"scale_m": 0.012, "colors": ["slate_grey", "logwood_black"]},
}
const SETTS_JSON := "res://assets/character/fabrics/setts.json"
## Entries of the shader's stripe table (pat_sett) that a surface's zones share.
const PATTERN_TABLE_MAX := 32
## Zones the creator offers no pattern on (woven and printed patterns are cloth's: not leather, metal, fur, beads).
const UNPATTERNED_ROLES := ["leather", "metal", "button", "fur", "quill", "bead", "fringe"]
const UNPATTERNED_FABRICS := ["LEA", "SUEDE", "FUR", "FLAT", "MET"]


## The sett library: name -> {label, note, sett: [[token, width] ...], symmetric, scale_m}.
static func setts() -> Dictionary:
	if _setts.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTS_JSON)) if FileAccess.file_exists(SETTS_JSON) else null
		_setts = (d.get("setts", {}) if d is Dictionary and d.get("setts") is Dictionary else {}) as Dictionary
		_setts_hex = (d.get("palette_hex", {}) if d is Dictionary and d.get("palette_hex") is Dictionary else {}) as Dictionary
		if _setts.is_empty():
			_setts["\n"] = {}                     # (loaded: no library)
	return _setts


## A pattern's name as the shader knows it ("stripes" -> "stripe"; unknown -> "none").
static func pattern_name(n: Variant) -> String:
	var s := str(n).to_lower() if n != null else "none"
	s = str(PATTERN_ALIAS.get(s, s))
	return s if PATTERN_KIND.has(s) else "none"


## The patterns the catalog documents for a zone (its "pattern": {"options": [...]}, or the single {"type": ...}) by the
## shader's names, "none" first; [] when it documents none.
static func zone_patterns(zd: Dictionary) -> Array:
	var p: Variant = zd.get("pattern")
	if not p is Dictionary:
		return []
	var names: Array = [(p as Dictionary).type] if (p as Dictionary).has("type") else (p as Dictionary).get("options", [])
	var out := ["none"]
	for n: Variant in names:
		var k := pattern_name(n)
		if not k in out:
			out.append(k)
	return out if out.size() > 1 else []


## Whether a zone takes a woven or printed pattern (cloth; not leather, metal, fur, beads).
static func patternable(zd: Dictionary) -> bool:
	return not str(zd.get("role", "cloth")) in UNPATTERNED_ROLES and not str(zd.get("fabric", "WOOL")) in UNPATTERNED_FABRICS


## The zone a garment's look-wide "pattern" goes on: the first zone whose catalog lists the look's pattern, else the
## first that documents a pattern, else zone 0.
static func pattern_zone(entry: Dictionary, colors := {}) -> int:
	var zones: Array = entry.get("zones", [])
	var want := pattern_name(colors.get("pattern")) if colors.has("pattern") else ""
	for zd: Variant in zones:
		if zd is Dictionary and want != "" and want in zone_patterns(zd):
			return int((zd as Dictionary).get("zone", 0))
	for zd: Variant in zones:
		if zd is Dictionary and not zone_patterns(zd).is_empty():
			return int((zd as Dictionary).get("zone", 0))
	return 0


## The catalog's definition of pattern `name` on a zone ({} when it has none): its "<name>" dictionary under any of the
## pattern's names, or the single-pattern form itself.
static func _pattern_def(zd: Dictionary, name: String) -> Dictionary:
	var p: Variant = zd.get("pattern")
	if not p is Dictionary:
		return {}
	if (p as Dictionary).has("type"):
		return p if pattern_name((p as Dictionary).type) == name else {}
	for k: Variant in p:
		if not str(k) in ["options", "default", "note"] and p[k] is Dictionary and pattern_name(k) == name:
			return p[k]
	return {}


## The look's own colour list for pattern `name` (its "<name><sfx>" under any of the pattern's names), [] if none.
static func _look_list(colors: Dictionary, name: String, sfx: String) -> Array:
	for k: Variant in colors:
		var ks := str(k)
		if not ks.ends_with(sfx) or not colors[k] is Array:
			continue
		var base := ks.substr(0, ks.length() - sfx.length())
		if base != "" and base != "pattern" and not "." in base and pattern_name(base) == name:
			return (colors[k] as Array).map(func(t: Variant) -> String: return str(t))
	return []


## A sett (a SETTS_JSON name, a list of [token, width], or {sett, symmetric, scale_m}) as {sett, symmetric, scale_m}
## ({} when there is none).
static func sett_of(v: Variant) -> Dictionary:
	if v is String:
		var d: Variant = setts().get(str(v))
		if d is Dictionary and (d as Dictionary).get("sett") is Array:
			return {"sett": d.sett, "symmetric": bool(d.get("symmetric", true)), "scale_m": float(d.get("scale_m", 0.16))}
		push_warning("ClothMaterials: no sett %s." % v)
		return {}
	if v is Array:
		return {"sett": v, "symmetric": true, "scale_m": float(PATTERN_DEFAULTS.plaid.scale_m)}
	if v is Dictionary:
		var b := sett_of((v as Dictionary).get("sett", PATTERN_DEFAULTS.plaid.sett))
		if not b.is_empty():
			b["symmetric"] = bool((v as Dictionary).get("symmetric", b.symmetric))
			b["scale_m"] = float((v as Dictionary).get("scale_m", b.scale_m))
		return b
	return {}


## The stripes of a sett over one full repeat: the list, mirrored about its pivots when symmetric (the first and the last
## stripe once, the others twice), as [[token, width]] with the widths summing to 1.
static func sett_table(sett: Array, symmetric := true) -> Array:
	var rows := []
	for r: Variant in sett:
		if r is Array and (r as Array).size() >= 2 and float(r[1]) > 0.0:
			rows.append([str(r[0]), float(r[1])])
	if symmetric and rows.size() > 2:
		for i in range(rows.size() - 2, 0, -1):
			rows.append((rows[i] as Array).duplicate())
	return _normalized(rows)


static func _normalized(rows: Array) -> Array:
	var total := 0.0
	for r: Array in rows:
		total += float(r[1])
	if total <= 0.0:
		return rows
	return rows.map(func(r: Array) -> Array: return [r[0], float(r[1]) / total])


## What a zone shows: {} when it is plain, else {"name", "kind" (cloth.gdshader pat_kind), "colors": [tokens], "table":
## [[token, width] ...] (one repeat, the widths summing to 1), "scale_m" (the repeat), "angle" (degrees on the UVs),
## "explicit"}. `zd`: the catalog zone (index `zi`; -1: its "zone"), `tok`: its colour token, `colors`: the look's
## colours of the garment, `pz`: the garment's pattern zone (pattern_zone; -1: zone 0).
##   Which: the look's "pattern.<zi>" for that zone; else the look's "pattern" on the zones whose catalog lists it and on
## the pattern zone (any garment takes any pattern: a plaid waistcoat); else the catalog's default ("default", or the
## single "type") when `tok` is one of its colours (a look that picks another colour wears the cloth plain); "check_blue"
## alone stands for the blue-and-white check unless the look says "pattern": "none".
##   Its colours: the look's "<name>" list ("<name>.<zi>" for a zone's own), else the catalog's, else PATTERN_DEFAULTS'
## with the zone's colour first; a colour the look picked for the zone that is not among the catalog's takes the first
## place when the look chose the pattern. A plaid's colours are its sett's in the order they first appear ("sett": a
## SETTS_JSON name or a list of [token, width], symmetric), recoloured by the look's list the same way.
##   Its size: the look's "pattern_scale" (m), "pattern_angle" (degrees) and "pattern_axis", else the catalog's scale_m,
## angle and axis ("h" turns stripes across the grain; "v", along it, is the default), else the defaults.
static func pattern_spec(zd: Dictionary, tok: String, colors := {}, pz := -1, zi := -1) -> Dictionary:
	if zi < 0:
		zi = int(zd.get("zone", 0))
	var sfx := ""
	var raw: Variant = null
	if colors.has("pattern.%d" % zi):
		raw = colors["pattern.%d" % zi]
		sfx = ".%d" % zi
	elif colors.has("pattern") and (pattern_name(colors.pattern) in zone_patterns(zd) or zi == maxi(pz, 0)):
		raw = colors.pattern
	var explicit := raw != null
	var name := pattern_name(raw)
	if not explicit:
		var p: Variant = zd.get("pattern")
		name = pattern_name((p as Dictionary).get("default", (p as Dictionary).get("type", "none"))) if p is Dictionary else "none"
	var def := _pattern_def(zd, name) if name != "none" else {}
	var cols := _base_colors(name, def, tok) if name != "none" else []
	if not explicit and name != "none" and not tok in cols:
		name = "none"
	if name == "none" and not explicit and tok == "check_blue" \
			and str(colors.get("pattern", "")) != "none" and str(colors.get("pattern.%d" % zi, "")) != "none":
		name = "check"
		def = _pattern_def(zd, "check")
		cols = ["check_blue", "linen_white"]
	if name == "none":
		return {}
	var sett := {}
	if name == "plaid":
		sett = sett_of(colors.get("sett" + sfx, def.get("sett", PATTERN_DEFAULTS.plaid.sett)))
		if sett.is_empty():
			return {}
		cols = _sett_colors(sett.sett)
	var own := _look_list(colors, name, sfx)
	if not own.is_empty():
		if name == "plaid":
			for i in mini(own.size(), cols.size()):
				cols[i] = own[i]
		else:
			cols = own.duplicate()
	elif explicit and (colors.has(str(zi)) or colors.has(zi)) and not tok in cols and not cols.is_empty():
		cols[0] = tok
	var dflt: Dictionary = PATTERN_DEFAULTS.get(name, {})
	var scale := float(colors.get("pattern_scale" + sfx, def.get("scale_m", sett.get("scale_m", dflt.get("scale_m", 0.012)))))
	var angle := float(colors.get("pattern_angle" + sfx, def.get("angle", 0.0)))
	if str(colors.get("pattern_axis" + sfx, def.get("axis", "v"))) == "h":
		angle += 90.0
	var table := _pattern_table(name, cols, def, sett)
	if table.is_empty():
		return {}
	return {"name": name, "kind": int(PATTERN_KIND[name]), "colors": cols, "table": table, "scale_m": maxf(scale, 0.001),
			"angle": angle, "explicit": explicit}


## A sett's colours in the order they first appear.
static func _sett_colors(sett: Array) -> Array:
	var out := []
	for r: Variant in sett:
		if r is Array and not (r as Array).is_empty() and not str(r[0]) in out:
			out.append(str(r[0]))
	return out


## A pattern's colours before the look's: the catalog's, else the defaults' with the zone's colour first (a plaid: its
## sett's).
static func _base_colors(name: String, def: Dictionary, tok: String) -> Array:
	if name == "plaid":
		return _sett_colors(sett_of(def.get("sett", PATTERN_DEFAULTS.plaid.sett)).get("sett", []))
	var c: Variant = def.get("colors")
	if c is Array and not (c as Array).is_empty():
		return (c as Array).map(func(t: Variant) -> String: return str(t))
	var out: Array = ((PATTERN_DEFAULTS.get(name, {}) as Dictionary).get("colors", []) as Array).duplicate()
	if not out.is_empty() and tok != "" and not tok in out:
		out[0] = tok
	return out


## The stripe table of a pattern: [[token, width]] over one repeat (calico and herringbone: their colours in order).
static func _pattern_table(name: String, cols: Array, def: Dictionary, sett: Dictionary) -> Array:
	if cols.is_empty():
		return []
	var a := str(cols[0])
	var b := str(cols[1]) if cols.size() > 1 else a
	var c := str(cols[2]) if cols.size() > 2 else b
	match name:
		"check":
			return _normalized([[a, 0.5], [b, 0.5]] if cols.size() < 3 else [[a, 0.4], [b, 0.4], [c, 0.2]])
		"stripe":
			var d := clampf(float(def.get("duty", 0.5)), 0.05, 0.95)
			return _normalized([[a, 1.0 - d], [b, d]] if cols.size() < 3 else [[a, 0.5], [b, 0.25], [c, 0.25]])
		"ticking":
			var thin := c if cols.size() > 2 else b
			return _normalized([[a, 0.28], [thin, 0.04], [a, 0.05], [b, 0.16], [a, 0.05], [thin, 0.04], [a, 0.38]])
		"plaid":
			var src: Array = sett.get("sett", [])
			var base := _sett_colors(src)
			var rows := []
			for r: Variant in src:
				if r is Array and (r as Array).size() >= 2:
					var i := base.find(str(r[0]))
					rows.append([str(cols[i]) if i >= 0 and i < cols.size() else str(r[0]), float(r[1])])
			return sett_table(rows, bool(sett.get("symmetric", true)))
		"calico":
			return [[a, 1.0], [b, 0.0], [c, 0.0]]
		"herringbone":
			return [[a, 0.5], [b, 0.5]]
	return []


## Sets the pattern uniforms of a cloth material from its zones' pattern_spec results (`specs[z]`; {}: plain); `zds[z]`:
## the zone dictionaries their tokens resolve in. A zone whose table does not fit the shader's is drawn plain.
static func set_patterns(m: ShaderMaterial, specs: Array, zds: Array) -> void:
	var kind := Vector4.ZERO
	var scale := Vector4(0.012, 0.012, 0.012, 0.012)
	var angle := Vector4.ZERO
	var start := Vector4.ZERO
	var count := Vector4.ZERO
	var table := PackedVector4Array()
	for z in mini(specs.size(), 4):
		var sp: Dictionary = specs[z] if specs[z] is Dictionary else {}
		if sp.is_empty():
			continue
		var rows: Array = sp.table
		if table.size() + rows.size() > PATTERN_TABLE_MAX:
			push_warning("ClothMaterials: the %s of zone %d does not fit the stripe table (%d + %d > %d); drawn plain." \
					% [sp.name, z, table.size(), rows.size(), PATTERN_TABLE_MAX])
			continue
		kind[z] = float(sp.kind)
		scale[z] = float(sp.scale_m)
		angle[z] = deg_to_rad(float(sp.angle))
		start[z] = float(table.size())
		count[z] = float(rows.size())
		var zd: Dictionary = zds[z] if z < zds.size() and zds[z] is Dictionary else {}
		for r: Array in rows:
			var l := lin4(token_color(zd, str(r[0])))
			table.append(Vector4(l.x, l.y, l.z, float(r[1])))
	while table.size() < PATTERN_TABLE_MAX:
		table.append(Vector4.ZERO)
	m.set_shader_parameter("pat_kind", kind)
	m.set_shader_parameter("pat_scale", scale)
	m.set_shader_parameter("pat_angle", angle)
	m.set_shader_parameter("pat_start", start)
	m.set_shader_parameter("pat_count", count)
	m.set_shader_parameter("pat_sett", table)


## Bible palette tokens that catalog entries reference outside their own palette_hex
## (tools/character/lib/materials.py TOKENS; band colours).
const TOKEN_HEX := {
	"stroud_blue": "#1E2B4A", "stroud_red": "#8A1C1F", "madder_red": "#8E2B21", "logwood_black": "#1C1B20",
	"ranger_green": "#3B4A2E", "linen_unbleached": "#C8BA9A", "walnut_brown": "#5A3F2C", "buckskin_smoked": "#A07E55",
	"ribbon_red": "#B2202C", "ribbon_blue": "#2D4F8C", "ribbon_black": "#151417", "ribbon_green": "#2E6B40",
	"brass": "#B58F4A", "pewter": "#9A9C9A", "silver": "#C8CACC", "leather_brown": "#5B3D26", "drab": "#8B7A5C",
	"slate_grey": "#6B6A66", "linen_white": "#E8E3D3", "grey_white": "#D4D0C3", "bead_white": "#EEEBE3",
	# a pattern's colours (zone_tint) that a zone's own palette may not list
	"check_blue": "#2F4166", "tow": "#A99570",
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
	var by_zone := {}
	for i in zones.size():
		if zones[i] is Dictionary:
			by_zone[int((zones[i] as Dictionary).get("zone", i))] = zones[i]
	var pz := pattern_zone(entry, colors)
	for s: Dictionary in entry.get("surfaces", []):
		var sname := String(s.get("name", ""))
		if not fur.is_empty() and sname == String(fur.get("surface", "")):
			out[sname] = fur_material(entry, colors)
			continue
		var m := new_cloth()
		var specs := [{}, {}, {}, {}]
		var zds := [{}, {}, {}, {}]
		for zi in 4:
			# the zone's own entry by its index (an entry's zones may skip one: the mote belt's 0, 2, 3), else the last
			var zd: Dictionary = by_zone.get(zi, zones[mini(zi, zones.size() - 1)]) if not zones.is_empty() else {}
			var role := String(zd.get("role", "cloth"))
			var code := String(zd.get("fabric", "WOOL"))
			var tok := String(colors.get(str(zi), colors.get(zi, zd.get("default", "#808080"))))
			var tint := zone_tint(zd, tok, colors, pz)
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
			if role != "fur":
				specs[zi] = pattern_spec(zd, tok, colors, pz, zi)
				zds[zi] = zd
			var b := hem_bands(zd)
			if zi == 0 and not b.is_empty():
				var rows := int(colors.get("bands_rows", b.get("default_rows", 0)))
				var btok := String(colors.get("bands", b.get("default", "stroud_blue")))
				m.set_shader_parameter("band_rows", Vector4(rows, float(b.get("offset_m", 0.05)),
						float(b.get("width_m", 0.035)), float(b.get("gap_m", 0.025))))
				m.set_shader_parameter("band_color", lin4(token_color(zd, btok)))
		set_patterns(m, specs, zds)
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
