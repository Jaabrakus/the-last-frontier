class_name SoftLook
extends RefCounted
## The "Soft" character look (the owner, 2026-10-10: "Soft look on our fighters"): a softer palette and a gentle, warm light
## response on our OWN characters, from the earlier character colour-and-shading study the owner liked (a local preview tool, not in
## the repository; only its own code and our assets were used: its six-colour palette and its soft light() idea, retuned here).
## The world and the ring are NOT touched (the owner: "no cel shading" for the world): only character bodies, garments and hair.
## A setting, "Character look": Classic (the look as it was, bit for bit) or Soft (the default), kept in GameSettings [look]
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
const KINDS := {
	"skin": {"floor": 0.28, "shadow": 0.28, "rim": 0.06, "spec": 0.08, "blood": 1.4, "warm": 1.0, "gain": 0.9, "wrap": -0.2},
	"eye": {"floor": 0.55, "shadow": 0.50, "rim": 0.0, "spec": 0.8, "blood": 0.0, "warm": 0.5, "gain": 1.0, "wrap": -0.35},
	"hair": {"floor": 0.30, "shadow": 0.30, "rim": 0.0, "spec": 0.04, "blood": 0.0, "warm": 0.3, "gain": 0.7, "wrap": -0.3},
	"cloth": {"floor": 0.34, "shadow": 0.38, "rim": 0.06, "spec": 0.05, "blood": 0.0, "warm": 0.5, "gain": 0.9, "wrap": -0.35},
}
## The numbers calmed on a soft copy (the study's: the fabric scans, dirt and pores quieter, the oil gone), per kind; only the
## uniforms the shader has. Vector4 values for the cloth's per-zone vec4s.
const CALM := {
	"cloth": {"detail_strength": Vector4(0.3, 0.3, 0.3, 0.3), "normal_strength": Vector4(0.2, 0.2, 0.2, 0.2),
		"dirt_amount": 0.12, "wear_amount": 0.2, "sweat_amount": 0.1, "macro_var": 0.03, "character": 0.18,
		"fold_amount": 0.45, "cavity_amount": 0.35, "sheen": Vector4(0.03, 0.03, 0.03, 0.03)},
	"skin": {"detail_strength": 0.55, "body_detail_strength": 0.6, "weathering": 0.15, "skin_specular": 0.16,
		"oil_sheen": 0.0, "sss_strength": 0.3, "neck_bounce": 0.12},
}

## The soft copy of each original shader (made once: its code compiled once).
static var _shaders := {}
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


## "Character look: Soft" (a menu row's words) and its line.
static func row_text() -> String:
	return "Character look: %s" % String(LABELS.get(mode(), mode()))


static func row_line() -> String:
	return "Soft: gentle light, calmer colours; Classic: the look as it was"


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
	for tag: String in body.parts:
		for mi in body.parts[tag]:
			if not is_instance_valid(mi) or (mi as MeshInstance3D).mesh == null:
				continue
			var m3 := mi as MeshInstance3D
			var team := team_garment(String(m3.get_meta("garment", "")))
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
						made[cur] = soft_copy(cur as ShaderMaterial, team)
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


## The soft copy of `classic`: duplicated, the soft shader, its numbers calmed, a garment's colours softened (`team`: a side's
## colours, hue kept).
static func soft_copy(classic: ShaderMaterial, team := false) -> ShaderMaterial:
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
		for z in 4:
			var key := "tint%d" % z
			var t: Variant = classic.get_shader_parameter(key)
			if t is Vector4 and not (metal is Vector4 and (metal as Vector4)[z] > 0.5):
				own[key] = soften_lin(t as Vector4, team)
		var band: Variant = classic.get_shader_parameter("band_color")
		if band is Vector4:
			own["band_color"] = soften_lin(band as Vector4, team)
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

## The soft copy of `original` (made once): its code whole (the skin's own scattering kept: it warms the face), the soft light()
## added.
static func soft_shader(original: Shader) -> Shader:
	if _shaders.has(original):
		return _shaders[original] as Shader
	var sh := Shader.new()
	sh.code = original.code + "\n" + light_code(kind_of(original))
	_shaders[original] = sh
	return sh


## Whether `shader` is one of the soft copies.
static func is_soft(shader: Shader) -> bool:
	return shader != null and shader in _shaders.values()


## The soft light() for a kind of surface: a wide, gentle terminator (no hard bands), the turned-away side kept at the kind's
## floor (under the sun or the moon; under a lamp or a brazier less of it, so the sides keep their contrast at night), cast shadows of the sun lifted (directional lights only: a lamp's own fall-off is kept), cool in the shade and warm in
## the light, a warm band where a face turns from the light, a faint lit rim, and a broad, low specular.
static func light_code(kind: String) -> String:
	var k: Dictionary = KINDS.get(kind, KINDS.cloth)
	return """
// SoftLook (scripts/customizer/soft_look.gd): Tidebreak's own "Soft" character look, kind "%s".
const float SOFTLOOK_FLOOR = %.3f;
const float SOFTLOOK_SHADOW = %.3f;
const float SOFTLOOK_RIM = %.3f;
const float SOFTLOOK_SPEC = %.3f;
const float SOFTLOOK_BLOOD = %.3f;
const float SOFTLOOK_WARM = %.3f;
const float SOFTLOOK_GAIN = %.3f;
const float SOFTLOOK_WRAP = %.3f;
void light() {
	float softlook_nl = dot(NORMAL, LIGHT);
	float softlook_lit = smoothstep(SOFTLOOK_WRAP, 1.0, softlook_nl);
	float softlook_floor = LIGHT_IS_DIRECTIONAL ? SOFTLOOK_FLOOR : SOFTLOOK_FLOOR * 0.4;
	float softlook_shade = mix(softlook_floor * 0.6, 1.0, softlook_lit);
	float softlook_att = LIGHT_IS_DIRECTIONAL ? mix(SOFTLOOK_SHADOW, 1.0, ATTENUATION) : ATTENUATION;
	vec3 softlook_warm = mix(vec3(1.0, 0.97, 0.92), vec3(1.0, 0.91, 0.80), SOFTLOOK_WARM);
	vec3 softlook_tint = mix(vec3(0.84, 0.89, 1.0), softlook_warm, softlook_lit);
	softlook_tint += SOFTLOOK_BLOOD * vec3(0.22, 0.05, 0.0) * softlook_lit * (1.0 - softlook_lit) * 4.0;
	vec3 softlook_l = LIGHT_COLOR * softlook_att / PI;
	DIFFUSE_LIGHT += SOFTLOOK_GAIN * softlook_shade * softlook_tint * softlook_l;
	float softlook_rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * smoothstep(0.0, 0.6, softlook_nl);
	DIFFUSE_LIGHT += SOFTLOOK_RIM * softlook_rim * softlook_l;
	vec3 softlook_hv = normalize(VIEW + LIGHT);
	float softlook_gloss = exp2(mix(3.0, 7.0, 1.0 - ROUGHNESS));
	float softlook_sp = pow(clamp(dot(NORMAL, softlook_hv), 0.0, 1.0), softlook_gloss) * smoothstep(0.0, 0.3, softlook_nl);
	SPECULAR_LIGHT += SOFTLOOK_SPEC * SPECULAR_AMOUNT * softlook_sp * LIGHT_COLOR * softlook_att;
}
""" % [kind, float(k.floor), float(k.shadow), float(k.rim), float(k.spec), float(k.blood), float(k.warm), float(k.gain), float(k.wrap)]


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
