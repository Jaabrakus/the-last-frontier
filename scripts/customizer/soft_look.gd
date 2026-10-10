class_name SoftLook
extends RefCounted
## The "Soft" character look (the owner, 2026-10-10: "Soft look on our fighters"): a softer palette and a gentle, warm light
## response on our OWN characters, from the earlier character colour-and-shading study the owner liked (a local preview tool, not in
## the repository; only its own code and our assets were used: its six-colour palette, its light() and its material numbers,
## taken as they are since 2026-10-10 — pass 1's retuned version read flat and chalky next to the study).
## Here: the character bodies, garments and hair. The world takes the study's light and colours under the same setting since
## 2026-10-10 (SoftWorld, scripts/world/env/soft_world.gd: the owner, "these colors ... this is the new default why come the world
## and everything looks like this"); the world's light stays standard, never this light().
## A setting, "Look": Classic (the look as it was, bit for bit) or Soft (the default), kept in GameSettings [look]
## character, shown in the Settings rows (GameSettings.rows: the main menu's, the Esc menus') and the ring Esc menu's Options.
## How it is put on: PlayerAppearance.dress() (the one way every body is dressed: the player, the ring's bots, the lobby fighter,
## open-world people, companions) ends with apply_body(body). In Soft each of the body's part materials (skin, eyes, hair, brows,
## garments) is swapped for a soft COPY: the same ShaderMaterial duplicated, its shader a copy of the original with the soft
## light() appended (made once per shader), a few of its numbers calmed (fabric grain, dirt, pores, oil). The classic material
## is kept on the copy (meta soft_look_classic) and given back as it was in Classic, the numbers the game changed on the copy
## meanwhile (a hide mask, a child's skin) carried back to it, so Classic is the classic material itself, unchanged.
## The palette: a garment that is a side's colour (the catalog's set "ring": the ring dress, home and away) keeps its hue, only a
## little of its saturation taken (the sides stay apart at 15-25 m: tests/customizer/test_soft_look.gd measures the home and the
## away dress); every other garment (the basic dress, open-world people) is drawn toward the six study colours below.
## Never on the character creator's own figure (its stage marks the body: META_OFF), so the creator stays as it is.
##   SoftLook.mode() / set_mode("soft")       the setting (the run's argument character_look=classic|soft overrides it)
##   SoftLook.apply_body(body)                the body's materials as the setting says (soft copies, or the classic ones back)
##   SoftLook.warm_up(cam)                    every soft shader drawn once (behind a loading screen: no first-use stall)

const SECTION := "look"
const KEY := "character"
const CLASSIC := "classic"
const SOFT := "soft"
const MODES := [CLASSIC, SOFT]
const LABELS := {CLASSIC: "Classic", SOFT: "Soft"}
const GROUP := &"soft_look_bodies"
## On a soft copy: the classic material it stands in for, and {uniform: value} SoftLook itself set on the copy.
const META_CLASSIC := &"soft_look_classic"
const META_SET := &"soft_look_set"
## On a body: always Classic (the creator's stage figure).
const META_OFF := &"soft_look_off"
## The study's palette (sRGB): muted teal, warm cream, leather, slate, ochre, sage.
const PALETTE := {
	"teal": "#4D9BA5", "cream": "#EDE3C6", "leather": "#735341",
	"slate": "#445962", "ochre": "#C8A75B", "sage": "#8C9F79",
	# (not in the study: fire's trim, a muted rust in the study's key)
	"rust": "#A9573C",
}
## A garment of the everyday dress drawn toward its nearest study colour: this share of the way in hue/chroma (ab), this in
## lightness, then its chroma held under CHROMA_MAX.
const PULL_AB := 0.7
const PULL_L := 0.5
const CHROMA_MAX := 0.10
## A side's garment (the ring set): its hue kept, its chroma scaled by this; its lightness kept (the home and away dresses differ
## mostly in value: data/ring/sides.json min_value_diff).
const TEAM_CHROMA := 0.92
## The character shaders the soft look knows (warm_up compiles a soft copy of each). Not painted_skin.gdshader (the stylized faces):
## its own classic code does not compile today (its uniform `lines` and people_trait.gdshaderinc's local `lines`), so its copy
## would not either; a stylized face draws as it does in Classic.
const SHADERS := [
	"res://assets/character/shaders/skin.gdshader",
	"res://assets/character/shaders/eye.gdshader", "res://assets/character/shaders/hair.gdshader",
	"res://assets/character/shaders/hair_cards.gdshader", "res://assets/character/shaders/hair_tex.gdshader",
	"res://assets/character/shaders/face_hair.gdshader", "res://assets/character/shaders/fringe.gdshader",
	"res://assets/character/shaders/beard_shell.gdshader", "res://assets/character/shaders/fur_shell.gdshader",
	"res://assets/character/shaders/cloth.gdshader",
]
## The light response per kind of surface: the shade the turned-away side keeps (floor), the share of the sun a cast shadow
## keeps (shadow; directional lights only), a lit rim, the specular's strength, and the warm "blood" band along the terminator
## (skin only: a face reads warm, never grey, where the light turns), the warmth of the lit side, an overall gain, and where the
## wrap starts (the N.L at which the light begins: below 0 it wraps round the form; the skin wraps least, so a face keeps its
## modelling).
## The study's light() exactly (the owner, 2026-10-10, of its render: "how come u cant just get it to look like the right one?"
## — pass 1's own retuned light read flat and chalky): three soft bands, a cool shade warming toward the light. Every kind gets
## it; with it the copy's code drops the GGX specular (no plastic shine on hair or skin), Burley for Lambert, and the skin's
## subsurface mode (STUDY_SWAPS).
const STUDY_LIGHT := """
// SoftLook (scripts/customizer/soft_look.gd): the character study's soft three-band light.
void light() {
	float softlook_nl = dot(NORMAL, LIGHT);
	float softlook_shade = mix(0.32, 0.72, smoothstep(-0.08, 0.14, softlook_nl));
	softlook_shade = mix(softlook_shade, 1.0, smoothstep(0.43, 0.55, softlook_nl));
	vec3 softlook_tint = mix(vec3(0.78, 0.88, 1.0), vec3(1.0, 0.97, 0.90), smoothstep(0.0, 0.45, softlook_nl));
	// (the study had only its sun; a lamp or a brazier close by washed cream cloth into a glow at night: the lamps' share)
	float softlook_k = LIGHT_IS_DIRECTIONAL ? 1.0 : 0.4;
	DIFFUSE_LIGHT += softlook_k * softlook_shade * softlook_tint * ATTENUATION * LIGHT_COLOR / PI;
}
"""
const STUDY_SWAPS := [["specular_schlick_ggx", "specular_disabled"], ["diffuse_burley", "diffuse_lambert"], [", sss_mode_skin", ""]]
## The study's numbers on a soft copy, per kind; only the uniforms the shader has. Vector4 values for the cloth's per-zone vec4s.
const CALM := {
	"cloth": {"detail_strength": Vector4(0.12, 0.12, 0.12, 0.12), "normal_strength": Vector4(0.08, 0.08, 0.08, 0.08),
		"dirt_amount": 0.1, "wear_amount": 0.18, "sweat_amount": 0.1, "macro_var": 0.025, "character": 0.15,
		"fold_amount": 0.4, "cavity_amount": 0.3, "sheen": Vector4(0.025, 0.025, 0.025, 0.025)},
	"skin": {"detail_strength": 0.15, "head_detail_strength": 0.15, "body_detail_strength": 0.15, "weathering": 0.08,
		"skin_specular": 0.1, "oil_sheen": 0.0, "sss_strength": 0.06, "neck_bounce": 0.08},
}
## The share of the world's ambient light a soft character takes (its fragment's AO scaled by the global AMBIENT_GLOBAL). The
## study lit its figures with a flat ambient of 0.35 and a linear tonemap: under that light (SoftWorld) the whole of it
## (SoftWorld.CHARACTER_AMBIENT, 1.0); under the classic sky ambient (AgX, auto exposure: a place without SoftWorld) this
## share, which keeps the soft faces from washing pale (the owner, 2026-10-10: "why does it look so pale against the picture").
const AMBIENT_SHARE := 0.45
const AMBIENT_GLOBAL := &"softlook_ambient"
## Ring garments (the catalog's set "ring") in the study's colours, the two sides told apart by value (the owner chose "study
## colours, light vs dark"): the player's side dark (the study's teal), the other side light (the study's cream); the element
## in the trims, the sash and the band.
const SIDE_MAIN := {"dark": "teal", "light": "cream"}
const ELEMENT_TRIM := {"earth": "ochre", "water": "slate", "fire": "rust", "air": "sage"}
## The study's cloth colours per garment part (its four tint zones, then the band ochre): the part's mesh name decides.
const STUDY_ZONES := {
	"default": ["teal", "cream", "slate", "ochre"], "legs.lower": ["cream", "leather", "ochre", "slate"],
	"feet": ["leather", "slate", "cream", "ochre"], "accessories.arms": ["leather", "slate", "cream", "ochre"],
	"accessories.waist": ["leather", "ochre", "cream", "ochre"], "air": ["cream", "teal", "slate", "ochre"],
}

## The soft copy of each original shader (made once: its code compiled once).
static var _shaders := {}
static var _global_ok := false
## The setting read (cached; read again when GameSettings wrote): "" until read.
static var _mode := ""
static var _mode_writes := -1
## Tests: CLASSIC / SOFT in place of the setting ("" reads it).
static var override := ""


## The look in force: the run's argument character_look=classic|soft, else `override`, else the setting: Soft by default in the
## game; Classic by default in a script run (a test or a tool, -s) that has not chosen it (its own settings file, or the argument),
## so the material tests keep checking the classic materials dress() makes and the review tools keep their stills comparable.
static func mode() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("character_look="):
			var v := a.get_slice("=", 1)
			if v in MODES:
				return v
	if override in MODES:
		return override
	if _mode == "" or _mode_writes != GameSettings.writes:
		var v := String(GameSettings.get_value(SECTION, KEY)) if GameSettings.is_set(SECTION, KEY) else default_mode(script_run())
		_mode = v if v in MODES else SOFT
		_mode_writes = GameSettings.writes
	return _mode


## The look before any is chosen: Soft (the owner's choice, 2026-10-10), Classic in a script run.
static func default_mode(in_script := false) -> String:
	return CLASSIC if in_script else String(GameSettings.DEFAULTS[SECTION][KEY])


static func script_run() -> bool:
	var args := OS.get_cmdline_args()
	return "-s" in args or "--script" in args


static func on() -> bool:
	return mode() == SOFT


## Keeps `m` (CLASSIC or SOFT) and puts it on every dressed body there is now.
static func set_mode(m: String, tree: SceneTree = null) -> void:
	if not m in MODES:
		return
	GameSettings.set_value(SECTION, KEY, m)
	_mode = m
	_mode_writes = GameSettings.writes
	refresh(tree)


## Every dressed body in the tree as the setting says now.
static func refresh(tree: SceneTree = null) -> void:
	var t := tree if tree != null else Engine.get_main_loop() as SceneTree
	if t == null:
		return
	for n in t.get_nodes_in_group(GROUP):
		if n is CharacterBodyMesh:
			apply_body(n as CharacterBodyMesh)
	SoftWorld.refresh(t)


## "Character look: Soft" (a menu row's words) and its line.
static func row_text() -> String:
	return "Look: %s" % String(LABELS.get(mode(), mode()))


static func row_line() -> String:
	return "Soft: the study's calm light and colours, characters and world; Classic: the look as it was"


static func next_mode() -> String:
	return String(MODES[(MODES.find(mode()) + 1) % MODES.size()])


# ================================================================ the body

## `body`'s part materials as the setting says: soft copies in Soft, the classic materials back in Classic (or on a body marked
## META_OFF). The body joins GROUP so that a change of the setting finds it.
static func apply_body(body: CharacterBodyMesh) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group(GROUP):
		body.add_to_group(GROUP)
	var soft := on() and not bool(body.get_meta(META_OFF, false))
	var made := {}
	# (light: the other side in a ring match; the player's own, and anyone outside a match — the lobby's fighter — dark)
	# (outside a ring match, the lobby's and the menus' figures, everyone wears the player's side: the study's teal)
	var in_match := RingSides.sides_override != null or RingSides.match_node() != null
	var side := "dark" if _is_player(body) or not in_match else "light"
	for tag: String in body.parts:
		for mi in body.parts[tag]:
			if not is_instance_valid(mi) or (mi as MeshInstance3D).mesh == null:
				continue
			var m3 := mi as MeshInstance3D
			var gid := String(m3.get_meta("garment", ""))
			var team := team_garment(gid)
			var part := "%s %s %s %s" % [m3.name, gid, tag, side]
			for s in m3.mesh.get_surface_count():
				var cur := m3.get_surface_override_material(s)
				if cur == null:
					continue
				if cur.has_meta(META_CLASSIC):
					if not soft:
						m3.set_surface_override_material(s, restored(cur as ShaderMaterial))
					continue
				if soft and softenable(cur):
					if not made.has(cur):
						made[cur] = soft_copy(cur as ShaderMaterial, team, part)
					m3.set_surface_override_material(s, made[cur])


## The classic materials back on `body` (what the game's own material code expects), true when it wore soft ones: a caller that
## works on the classic materials (ChildSkin) calls apply_body again after.
static func lift(body: CharacterBodyMesh) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	var any := false
	for tag: String in body.parts:
		for mi in body.parts[tag]:
			if not is_instance_valid(mi) or (mi as MeshInstance3D).mesh == null:
				continue
			var m3 := mi as MeshInstance3D
			for s in m3.mesh.get_surface_count():
				var cur := m3.get_surface_override_material(s)
				if cur != null and cur.has_meta(META_CLASSIC):
					m3.set_surface_override_material(s, restored(cur as ShaderMaterial))
					any = true
	return any


## Whether `body` is the player's own (the dark side in the ring).
static func _is_player(body: Node) -> bool:
	var n := body
	while n != null:
		if n.is_in_group("player"):
			return true
		n = n.get_parent()
	return false


## A ring garment (the catalog's set "ring"): a side's colour, its hue kept.
static func team_garment(id: String) -> bool:
	return id != "" and String(PlayerOutfit.entry(id).get("set", "")) == "ring"


## A material the soft look takes: a lit ShaderMaterial with no light() of its own.
static func softenable(m: Material) -> bool:
	if not (m is ShaderMaterial) or (m as ShaderMaterial).shader == null or m.has_meta(META_CLASSIC):
		return false
	var code := (m as ShaderMaterial).shader.code
	return code.contains("shader_type spatial") and not code.contains("void light()") and not code.contains("unshaded")


## The kind of surface a shader draws (KINDS).
static func kind_of(shader: Shader) -> String:
	var f := shader.resource_path.get_file()
	if f.contains("skin") or shader.code.contains("child_fuzz"):
		return "skin"
	if f == "eye.gdshader":
		return "eye"
	if f.contains("hair") or f.contains("fringe") or f.contains("beard") or f.contains("fur"):
		return "hair"
	return "cloth"


## A ring garment's four colour names: the study's part colours for the legs, feet and wraps; the side's main colour (dark or
## light) on the tunic, the top and the parka, the element's on their trims; the element's on a sash or a belt.
static func ring_zones(part: String) -> Array:
	var el := "earth"
	for e: String in ELEMENT_TRIM:
		if e in part:
			el = e
	var trim := String(ELEMENT_TRIM[el])
	var main := String(SIDE_MAIN.light if "light" in part.split(" ") else SIDE_MAIN.dark)
	if "sash" in part or "belt" in part:
		return [trim, "leather", main, trim]
	if "tunic" in part or "top" in part or "parka" in part:
		return [main, "cream" if main != "cream" else "teal", trim, "leather"]
	return study_zones(part)


## The study's four colour names for a garment part (STUDY_ZONES; `part` holds the mesh's name, its garment id and its tag).
static func study_zones(part: String) -> Array:
	for k: String in ["legs.lower", "feet", "accessories.arms", "accessories.waist"]:
		if k in part:
			return STUDY_ZONES[k]
	if "air" in part:
		return STUDY_ZONES.air
	return STUDY_ZONES.default


## The soft copy of `classic`: duplicated, the study's shader and numbers, a garment in the study's colours (`team`: a side's
## garment keeps its own colour in its main zone, so the two sides stay apart; its other zones and band take the study's).
static func soft_copy(classic: ShaderMaterial, team := false, part := "") -> ShaderMaterial:
	var kind := kind_of(classic.shader)
	var m := classic.duplicate() as ShaderMaterial
	m.shader = soft_shader(classic.shader)
	var names := {}
	for u: Dictionary in classic.shader.get_shader_uniform_list():
		names[String(u.name)] = true
	var own := {}
	var calm: Dictionary = CALM.get(kind, {})
	for k: String in calm:
		if names.has(k):
			own[k] = calm[k]
	if kind == "cloth" and names.has("tint0"):
		var metal: Variant = classic.get_shader_parameter("metal")
		var zones := ring_zones(part) if team else study_zones(part)
		for z in 4:
			var key := "tint%d" % z
			var t: Variant = classic.get_shader_parameter(key)
			if not (t is Vector4) or (metal is Vector4 and (metal as Vector4)[z] > 0.5):
				continue
			own[key] = ClothMaterials.lin4(Color(PALETTE[zones[z]]))
		if names.has("band_color"):
			own["band_color"] = ClothMaterials.lin4(Color(PALETTE[zones[2] if team else "ochre"]))
		var sett: Variant = classic.get_shader_parameter("pat_sett")
		if sett is PackedVector4Array and not (sett as PackedVector4Array).is_empty():
			var out := PackedVector4Array()
			for v: Vector4 in sett:
				var c := soften_lin(Vector4(v.x, v.y, v.z, 1.0), team) if v.w > 0.0 else v
				out.append(Vector4(c.x, c.y, c.z, v.w))
			own["pat_sett"] = out
	for k: String in own:
		m.set_shader_parameter(k, own[k])
	m.set_meta(META_CLASSIC, classic)
	m.set_meta(META_SET, own)
	return m


## The classic material of soft copy `copy`, with every number the game changed on the copy since (not one SoftLook set, or one
## the game set again) carried back to it.
static func restored(copy: ShaderMaterial) -> Material:
	var classic := copy.get_meta(META_CLASSIC) as ShaderMaterial
	if classic == null:
		return copy
	var own: Dictionary = copy.get_meta(META_SET, {})
	for u: Dictionary in classic.shader.get_shader_uniform_list():
		var n := String(u.name)
		var v: Variant = copy.get_shader_parameter(n)
		if own.has(n) and _same(v, own[n]):
			continue
		if not _same(v, classic.get_shader_parameter(n)):
			classic.set_shader_parameter(n, v)
	return classic


static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


# ================================================================ the shader

## The soft copy of `original` (made once): its code with the study's swaps (STUDY_SWAPS: no GGX specular, Lambert, no skin
## subsurface mode) and the study's light() added.
static func soft_shader(original: Shader) -> Shader:
	if _shaders.has(original):
		return _shaders[original] as Shader
	_ensure_global()
	var sh := Shader.new()
	var code := original.code
	for swap: Array in STUDY_SWAPS:
		code = code.replace(String(swap[0]), String(swap[1]))
	sh.code = with_ambient_share(code) + "\n" + STUDY_LIGHT
	_shaders[original] = sh
	return sh


## `code` with "AO *= softlook_ambient;" as the last line of its fragment() (the soft character takes its share of the world's
## ambient light: AMBIENT_GLOBAL, declared after its render_mode); the code as it was when it has no fragment().
static func with_ambient_share(code: String) -> String:
	var rm := code.find("render_mode")
	if rm < 0:
		rm = code.find("shader_type")
	var semi := code.find(";", rm) if rm >= 0 else -1
	if semi < 0:
		return code
	code = code.substr(0, semi + 1) + "\nglobal uniform float %s;  // SoftLook: the share of the ambient (SoftWorld sets it)" % AMBIENT_GLOBAL \
			+ code.substr(semi + 1)
	var at := code.find("void fragment()")
	if at < 0:
		return code
	var open := code.find("{", at)
	if open < 0:
		return code
	var depth := 0
	for i in range(open, code.length()):
		var ch := code[i]
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				return code.substr(0, i) + "\tAO *= %s;  // SoftLook: its share of the ambient\n" % AMBIENT_GLOBAL + code.substr(i)
	return code


## The soft characters' share of the ambient (AMBIENT_GLOBAL): SoftWorld's light takes the whole (1.0), the classic sky AMBIENT_SHARE.
static func set_ambient_share(v: float) -> void:
	_ensure_global()
	RenderingServer.global_shader_parameter_set(AMBIENT_GLOBAL, v)


## The global the soft shaders read (project.godot [shader_globals], at AMBIENT_SHARE: a place without SoftWorld), set once to
## AMBIENT_SHARE (a run that changed it before is not carried over).
static func _ensure_global() -> void:
	if _global_ok:
		return
	_global_ok = true
	RenderingServer.global_shader_parameter_set(AMBIENT_GLOBAL, AMBIENT_SHARE)


## Whether `shader` is one of the soft copies.
static func is_soft(shader: Shader) -> bool:
	return shader != null and shader in _shaders.values()


## Every soft shader drawn once in front of `cam` (a tiny quad each, for a few frames), so that none is compiled at its first
## real draw: the ring's loading screen calls it (RingLevel._warm_looks). Nothing in Classic or headless.
static func warm_up(cam: Camera3D, frames := 2) -> void:
	if cam == null or not cam.is_inside_tree() or not on() or DisplayServer.get_name() == "headless":
		return
	var tree := cam.get_tree()
	var holder := Node3D.new()
	holder.name = "SoftLookWarm"
	cam.add_child(holder)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.002, 0.002)
	var i := 0
	# (one shader a frame: each compiles on a frame of its own, the loading screen's bar moving between them)
	for p: String in SHADERS:
		var src := load(p) as Shader
		if src == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = soft_shader(src)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(-0.004 * i, 0.0, -0.3)
		holder.add_child(mi)
		i += 1
		await tree.process_frame
	# (frames, never frame_post_draw: a window behind another app may not be drawn, and the loading must not wait on it)
	for f in frames:
		await tree.process_frame
	holder.queue_free()


# ================================================================ colour

## A linear tint (ClothMaterials.lin4) softened: a side's (`team`) keeps its hue and lightness, a little chroma taken; any other
## drawn toward its nearest study colour.
static func soften_lin(t: Vector4, team: bool) -> Vector4:
	var lab := lin_to_oklab(Vector3(t.x, t.y, t.z))
	if team:
		lab = Vector3(lab.x, lab.y * TEAM_CHROMA, lab.z * TEAM_CHROMA)
	else:
		var near := nearest_swatch(lab)
		lab = Vector3(lerpf(lab.x, near.x, PULL_L), lerpf(lab.y, near.y, PULL_AB), lerpf(lab.z, near.z, PULL_AB))
		var c := Vector2(lab.y, lab.z)
		if c.length() > CHROMA_MAX:
			c = c.normalized() * CHROMA_MAX
			lab = Vector3(lab.x, c.x, c.y)
	var rgb := oklab_to_lin(lab)
	return Vector4(maxf(rgb.x, 0.0), maxf(rgb.y, 0.0), maxf(rgb.z, 0.0), t.w)


## The study colour nearest `lab` (OKLab; lightness counts a little less than hue).
static func nearest_swatch(lab: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for k: String in PALETTE:
		var c := Color(PALETTE[k]).srgb_to_linear()
		var s := lin_to_oklab(Vector3(c.r, c.g, c.b))
		var d := pow((lab.x - s.x) * 0.8, 2.0) + pow(lab.y - s.y, 2.0) + pow(lab.z - s.z, 2.0)
		if d < bd:
			bd = d
			best = s
	return best


static func lin_to_oklab(c: Vector3) -> Vector3:
	var l := 0.4122214708 * c.x + 0.5363325363 * c.y + 0.0514459929 * c.z
	var m := 0.2119034982 * c.x + 0.6806995451 * c.y + 0.1073969566 * c.z
	var s := 0.0883024619 * c.x + 0.2817188376 * c.y + 0.6299787005 * c.z
	l = signf(l) * pow(absf(l), 1.0 / 3.0)
	m = signf(m) * pow(absf(m), 1.0 / 3.0)
	s = signf(s) * pow(absf(s), 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
			1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
			0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


static func oklab_to_lin(c: Vector3) -> Vector3:
	var l := c.x + 0.3963377774 * c.y + 0.2158037573 * c.z
	var m := c.x - 0.1055613458 * c.y - 0.0638541728 * c.z
	var s := c.x - 0.0894841775 * c.y - 1.2914855480 * c.z
	l = l * l * l
	m = m * m * m
	s = s * s * s
	return Vector3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
			-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
			-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
