extends SceneTree
## Preview renders and a posed coverage test of the military garments (and any catalog
## garment) on the customizer body, both fits. Needs a window (not --headless); run it under
## a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/character/garments/military_preview.gd -- \
##       out=DIR [mode=sheets|coverage|closeups] [looks=id,id]
##
## Looks (LOOKS below) are lists of catalog ids from any set (the military items plus the
## militia's shirt and shoes) with zone colour overrides. Garments use a preview shader
## (PREVIEW_SHADER): the zone's approved Poly Haven fabric (luminance detail tinted in
## linear light, its nor_gl normal map, UVs in metres / the kit's tile size), the baked
## COLOR shading, regimental lace stripes on the lace tape, and the hide mask. The runtime's
## cloth shader belongs to the fabric workstream; this is only for review.
##
## Hiding follows the design (§4.3): a region is hidden in part p when a worn garment q lists
## it in hides_regions with layer_q(region group) > layer_p; the body is layer 0.
##
## mode=coverage: hidden skin and hidden inner-garment triangles are drawn magenta instead of
## collapsed, over the poses of COVER_CLIPS from four sides; the magenta pixel count per shot
## is printed (0 = every declared hide really stays covered in that pose). Prints
## MILITARY PREVIEW DONE (or FAILED with the reasons).

const PREVIEW_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform int show_hidden = 0;
uniform vec3 tint0 : source_color = vec3(0.5); uniform vec3 tint1 : source_color = vec3(0.5);
uniform vec3 tint2 : source_color = vec3(0.5); uniform vec3 tint3 : source_color = vec3(0.5);
uniform vec4 metal = vec4(0.0);
uniform vec4 rough = vec4(0.85);
uniform vec4 tile = vec4(0.27);
uniform vec4 detail = vec4(1.0);
uniform vec4 nstrength = vec4(0.6);
uniform vec4 lum_mean = vec4(0.25);
uniform sampler2D tex0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm0 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm1 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm2 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm3 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 stripe_c0 : source_color = vec3(0.0); uniform vec3 stripe_c1 : source_color = vec3(0.0);
uniform vec3 stripe_c2 : source_color = vec3(0.0);
uniform vec4 stripe_pw0 = vec4(-1.0); // pos, width of stripes 0, 1 (across the tape, 0..1)
uniform vec2 stripe_pw2 = vec2(-1.0);
uniform float tape_width = 0.0105;
uniform int lace_zone = 2;
varying flat uint v_zone;
varying flat uint v_hidden;

void vertex() {
	uint code = uint(UV2.x + 0.5);
	uint r = code & 63u;
	v_zone = min(code >> 6u, 3u);
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	v_hidden = bits & 1u;
	if (v_hidden == 1u && show_hidden == 0) {
		VERTEX = vec3(0.0);
	}
}

float sel(vec4 v, int z) { return z == 0 ? v.x : (z == 1 ? v.y : (z == 2 ? v.z : v.w)); }

void fragment() {
	int z = int(v_zone);
	vec2 uv = UV / max(sel(tile, z), 1e-3);
	vec3 a0 = texture(tex0, uv).rgb; vec3 a1 = texture(tex1, uv).rgb;
	vec3 a2 = texture(tex2, uv).rgb; vec3 a3 = texture(tex3, uv).rgb;
	vec3 n0 = texture(nrm0, uv).rgb; vec3 n1 = texture(nrm1, uv).rgb;
	vec3 n2 = texture(nrm2, uv).rgb; vec3 n3 = texture(nrm3, uv).rgb;
	vec3 a = z == 0 ? a0 : (z == 1 ? a1 : (z == 2 ? a2 : a3));
	vec3 n = z == 0 ? n0 : (z == 1 ? n1 : (z == 2 ? n2 : n3));
	vec3 t = z == 0 ? tint0 : (z == 1 ? tint1 : (z == 2 ? tint2 : tint3));
	float l = dot(a, vec3(0.2126, 0.7152, 0.0722)) / max(sel(lum_mean, z), 1e-3);
	float det = mix(1.0, clamp(l, 0.3, 1.8), sel(detail, z));
	vec3 col = t * det;
	if (z == lace_zone && stripe_pw0.x >= 0.0) {
		float u = UV.x / tape_width;
		if (abs(u - stripe_pw0.x) < 0.5 * stripe_pw0.y) col = stripe_c0 * det;
		if (stripe_pw0.z >= 0.0 && abs(u - stripe_pw0.z) < 0.5 * stripe_pw0.w) col = stripe_c1 * det;
		if (stripe_pw2.x >= 0.0 && abs(u - stripe_pw2.x) < 0.5 * stripe_pw2.y) col = stripe_c2 * det;
	}
	ALBEDO = col * COLOR.rgb;
	METALLIC = sel(metal, z);
	ROUGHNESS = clamp(sel(rough, z) * (0.9 + 0.2 * (1.0 - det)), 0.05, 1.0);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = sel(nstrength, z);
	if (v_hidden == 1u && show_hidden == 1) {
		ALBEDO = vec3(0.0); EMISSION = vec3(1.0, 0.0, 1.0); ROUGHNESS = 1.0; METALLIC = 0.0;
	}
}
"""

## Skin for the coverage mode: flat, and magenta where the region is hidden.
const COVER_SKIN := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform uvec2 hide_mask = uvec2(0u, 0u);
varying flat uint v_hidden;
void vertex() {
	uint r = uint(UV2.x + 0.5) & 63u;
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	v_hidden = bits & 1u;
}
void fragment() {
	ALBEDO = v_hidden == 1u ? vec3(1.0, 0.0, 1.0) : vec3(0.55, 0.42, 0.36);
}
"""

## Approved kits (costume bible §0.3; design §2.4 tile sizes).
const FABRICS := {"LIN": ["rough_linen", 0.271], "WOOL": ["caban", 0.274], "TWILL": ["poly_wool_herringbone", 0.270],
		"KNIT": ["knitted_fleece", 0.266], "SUEDE": ["scuba_suede", 0.285], "LEA": ["brown_leather", 0.400],
		"FUR": ["curly_teddy_natural", 0.336], "HES": ["hessian_230", 0.269]}
const KIT_DIR := "res://assets/polyhaven/textures/clothing/"
const METALS := ["silver", "brass", "pewter", "gold_lace", "silver_lace", "false_gold"]
const IDLE := "actor_b-p-relax-idle"
const POSES := [["stealth", "actor_b-p-stealth-idle", 0.0], ["run", "actor_b-p-run-fw", 0.3],
		["crouch", "actor_b-p-crouch-walk-fw", 0.5], ["musket", "actor_b-p-rifle-idle-aim", 0.0],
		["reload", "actor_b-p-rifle-idle-aim-reload-mid--part", 0.5], ["sprint", "actor_b-p-sprint-fw", 0.4]]
const COVER_CLIPS := [["actor_b-p-stealth-idle", 0.0], ["actor_b-p-run-fw", 0.3], ["actor_b-p-sprint-fw", 0.6],
		["actor_b-p-crouch-walk-fw", 0.5], ["actor_b-p-crouch-idle", 0.0], ["actor_b-p-rifle-idle-aim", 0.0],
		["actor_b-p-rifle-idle-aim-reload-mid--part", 0.5], ["actor_b-p-bow-aim-idle", 0.0],
		["actor_b-p-idle-jump-up-3m^ledge-hang-mid", 0.9], ["actor_b-p-death-back", 0.9]]

## Preview looks: parts (catalog ids) and zone colours {id: {zone: token}}.
const LOOKS := {
	"br_44th_1755": {"name": "44th Foot, 1755 (1751 pattern)",
		"parts": ["shirt_linen", "br_stock", "br_waistcoat", "br_regimental_coat_1751", "br_breeches", "br_gaiters",
			"shoes_buckled", "br_cocked_hat", "br_belts_cartridge"],
		"colors": {"br_regimental_coat_1751": {1: "yellow"}}, "hair": "hair_queue_ribbon", "hair_color": "dark_brown",
		"regiment": "foot_44th"},
	"br_48th_1755": {"name": "48th Foot, 1755 (buff, lace green and yellow)",
		"parts": ["shirt_linen", "br_stock", "br_waistcoat", "br_regimental_coat_1751", "br_breeches", "br_gaiters",
			"shoes_buckled", "br_cocked_hat", "br_belts_cartridge"],
		"colors": {"br_regimental_coat_1751": {1: "buff"}}, "hair": "hair_club_ribbon", "hair_color": "mid_brown",
		"regiment": "foot_48th"},
	"br_light_1758": {"name": "Light infantry, 1758 (cropped coat)",
		"parts": ["shirt_linen", "br_stock", "br_waistcoat", "br_coat_cropped_1758", "br_breeches", "br_gaiters",
			"shoes_buckled", "br_cocked_hat", "br_belts_cartridge"],
		"colors": {"br_coat_cropped_1758": {1: "deep_green"}, "br_gaiters": {0: "logwood_black"}},
		"hair": "hair_cropped_1758", "hair_color": "black"},
	"fr_marine_garrison": {"name": "Troupes de la marine, garrison",
		"parts": ["shirt_linen", "fr_cravat", "fr_veste", "fr_marine_justaucorps", "fr_breeches", "fr_gaiters_white",
			"shoes_buckled", "fr_tricorne", "fr_belt_gargoussier"],
		"colors": {}, "hair": "hair_queue_ribbon", "hair_color": "black"},
	"fr_marine_stockings": {"name": "Troupes de la marine, blue stockings (no gaiters)",
		"parts": ["shirt_linen", "fr_cravat", "fr_veste", "fr_marine_justaucorps", "fr_breeches", "fr_stockings",
			"shoes_buckled", "fr_tricorne"],
		"colors": {}, "hair": "hair_club_ribbon", "hair_color": "auburn"},
	"fr_la_sarre": {"name": "La Sarre, 1758 (blue cuffs, red veste)",
		"parts": ["shirt_linen", "fr_cravat", "fr_veste", "fr_marine_justaucorps", "fr_breeches", "fr_gaiters_white",
			"shoes_buckled", "fr_tricorne", "fr_belt_gargoussier"],
		"colors": {"fr_veste": {0: "madder_red"}, "fr_breeches": {0: "grey_white"}},
		"hair": "hair_queue_ribbon", "hair_color": "dark_brown"},
}

var args := {}
var out := ""
var failures := PackedStringArray()
var world: Node3D
var cam: Camera3D
var chars: Array = []
var _entries := {}
var _kits := {}
var _shader: Shader
var _cover_skin: Shader


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = args.get("out", "user://military_preview")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_shader = Shader.new()
	_shader.code = PREVIEW_SHADER
	_cover_skin = Shader.new()
	_cover_skin.code = COVER_SKIN
	_load_entries()
	await _studio()
	var mode: String = args.get("mode", "sheets")
	var looks: Array = LOOKS.keys() if not args.has("looks") else Array(String(args.looks).split(","))
	match mode:
		"sheets": await _sheets(looks)
		"coverage": await _coverage(looks)
		"closeups": await _closeups()
	print("MILITARY PREVIEW DONE" if failures.is_empty() else "MILITARY PREVIEW FAILED: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _load_entries() -> void:
	var gd := DirAccess.open("res://assets/character/garments")
	for d in gd.get_directories():
		var dir := "res://assets/character/garments/" + d
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".json"):
				continue
			var e = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + f))
			if e is Dictionary and e.has("id") and e.has("glb") and e.has("slot"):
				_entries[e.id] = e


func _studio() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.38, 0.40)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.54, 0.58)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	for l in [[Vector3(-35, 30, 0), 1.1, true], [Vector3(-15, -60, 0), 0.32, false], [Vector3(-25, 160, 0), 0.55, false]]:
		var dl := DirectionalLight3D.new()
		dl.rotation_degrees = l[0]
		dl.light_energy = l[1]
		dl.shadow_enabled = l[2]
		world.add_child(dl)
	cam = Camera3D.new()
	cam.fov = 28.0
	cam.near = 0.02
	world.add_child(cam)
	cam.current = true
	await _frames(1)


# --- materials ------------------------------------------------------------------

func _kit(code: String) -> Dictionary:
	if _kits.has(code):
		return _kits[code]
	var k := {}
	if FABRICS.has(code):
		var name: String = FABRICS[code][0]
		var base := KIT_DIR + name + "/" + name
		k.tex = load(base + "_diffuse_2k.jpg")
		k.nrm = load(base + "_nor_gl_2k.jpg")
		k.tile = float(FABRICS[code][1])
		var img: Image = (k.tex as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(8, 8, Image.INTERPOLATE_BILINEAR)
		var lum := 0.0
		for y in 8:
			for x in 8:
				var c := img.get_pixel(x, y).srgb_to_linear()
				lum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		k.mean = lum / 64.0
	_kits[code] = k
	return k


func _token_hex(e: Dictionary, zone: Dictionary, tok) -> Color:
	var s := String(tok)
	if s.begins_with("#"):
		return Color(s)
	var ph: Dictionary = zone.get("palette_hex", {})
	if ph.has(s):
		return Color(String(ph[s]))
	var toks: Dictionary = _tokens()
	return Color(String(toks.get(s, "#808080")))


var _tok_cache := {}


func _tokens() -> Dictionary:
	if _tok_cache.is_empty():
		for id in _entries:
			for z: Dictionary in _entries[id].get("zones", []):
				for t in z.get("palette_hex", {}):
					_tok_cache[t] = z.palette_hex[t]
		for t in ["ribbon_black", "ribbon_yellow", "ribbon_green", "ribbon_red", "ribbon_blue", "orange", "yellow",
				"buff", "white_facing", "royal_blue", "deep_green", "full_green", "logwood_black"]:
			if not _tok_cache.has(t):
				_tok_cache[t] = {"ribbon_black": "#151417", "ribbon_yellow": "#D8B23A", "ribbon_green": "#2E6B40",
					"ribbon_red": "#B2202C", "ribbon_blue": "#2D4F8C", "orange": "#C0632A", "yellow": "#D0A93A",
					"buff": "#D2B98A", "white_facing": "#E4DECC", "royal_blue": "#233C78", "deep_green": "#213A2A",
					"full_green": "#2E5134", "logwood_black": "#1C1B20"}[t]
	return _tok_cache


func _garment_material(id: String, overrides: Dictionary, hide: Vector2i, show_hidden: bool, regiment := "") -> ShaderMaterial:
	var e: Dictionary = _entries[id]
	var m := ShaderMaterial.new()
	m.shader = _shader
	var metal := Vector4.ZERO
	var rough := Vector4(0.85, 0.85, 0.85, 0.85)
	var tile := Vector4(0.27, 0.27, 0.27, 0.27)
	var detail := Vector4(1, 1, 1, 1)
	var ns := Vector4(0.6, 0.6, 0.6, 0.6)
	var lm := Vector4(0.25, 0.25, 0.25, 0.25)
	var blank := _kit("LIN")
	for zi in 4:
		m.set_shader_parameter("tex%d" % zi, blank.tex)
		m.set_shader_parameter("nrm%d" % zi, blank.nrm)
		m.set_shader_parameter("tint%d" % zi, Color(0.5, 0.5, 0.5))
	for z: Dictionary in e.get("zones", []):
		var zi := int(z.zone)
		var tok = overrides.get(zi, z.get("default", "#808080"))
		var col := _token_hex(e, z, tok)
		var fab := String(z.get("fabric", "FLAT"))
		var is_metal: bool = fab == "MET" or String(tok) in METALS
		m.set_shader_parameter("tint%d" % zi, col)
		var k := _kit(fab if FABRICS.has(fab) else "LIN")
		m.set_shader_parameter("tex%d" % zi, k.tex)
		m.set_shader_parameter("nrm%d" % zi, k.nrm)
		tile[zi] = k.tile
		lm[zi] = k.mean
		if is_metal:
			metal[zi] = 0.95
			rough[zi] = 0.32
			detail[zi] = 0.0
			ns[zi] = 0.0
		elif not FABRICS.has(fab):
			detail[zi] = 0.15
			ns[zi] = 0.1
			rough[zi] = 0.7
		else:
			detail[zi] = {"WOOL": 1.0, "LIN": 0.9, "LEA": 0.7, "KNIT": 1.0, "SUEDE": 0.8}.get(fab, 0.9)
			ns[zi] = {"WOOL": 0.5, "LIN": 0.55, "LEA": 0.45, "KNIT": 0.8, "SUEDE": 0.5}.get(fab, 0.5)
			rough[zi] = {"LEA": 0.55}.get(fab, 0.88)
		if String(e.get("slot", "")) == "head" and zi == 0:
			ns[zi] = 0.2           # felt: the WOOL kit with a low normal strength (bible §7)
	# regimental lace stripes (zone 2 of the coats)
	var pw0 := Vector4(-1, 0, -1, 0)
	var pw2 := Vector2(-1, 0)
	var stripes: Array = []
	if regiment != "":
		for r: Dictionary in e.get("regiments", []):
			if r.id == regiment and r.get("lace") is Dictionary:
				stripes = r.lace.stripes
	else:
		for z: Dictionary in e.get("zones", []):
			if int(z.zone) == 2 and z.get("pattern") is Dictionary:
				stripes = z.pattern.get("stripes", [])
	for i in mini(stripes.size(), 3):
		var st: Array = stripes[i]
		var c := Color(String(_tokens().get(st[0], "#151417")))
		m.set_shader_parameter("stripe_c%d" % i, c)
		if i == 0:
			pw0.x = float(st[1]); pw0.y = float(st[2])
		elif i == 1:
			pw0.z = float(st[1]); pw0.w = float(st[2])
		else:
			pw2 = Vector2(float(st[1]), float(st[2]))
	m.set_shader_parameter("stripe_pw0", pw0)
	m.set_shader_parameter("stripe_pw2", pw2)
	m.set_shader_parameter("metal", metal)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("tile", tile)
	m.set_shader_parameter("detail", detail)
	m.set_shader_parameter("nstrength", ns)
	m.set_shader_parameter("lum_mean", lm)
	m.set_shader_parameter("hide_mask", hide)
	m.set_shader_parameter("show_hidden", 1 if show_hidden else 0)
	return m


# --- hiding (design §4.3) -----------------------------------------------------

func _layer_of(e: Dictionary, region: String, groups: Dictionary) -> int:
	var l: Dictionary = e.get("layer", {"default": 10})
	var g := String(groups.get(region, ""))
	return int(l.get(g, l.get("default", 10)))


func _hides(parts: Array) -> Dictionary:
	var info := BodyMaterials.body_info()
	var groups: Dictionary = info.get("regions", {}).get("groups", {})
	var res := {"body": [], "hair": []}
	for id: String in parts:
		res[id] = []
	for q: String in parts:
		var eq: Dictionary = _entries[q]
		for r: String in eq.get("hides_regions", []):
			if not r in res.body:
				res.body.append(r)
			for p: String in parts:
				if p != q and _layer_of(eq, r, groups) > _layer_of(_entries[p], r, groups) and not r in res[p]:
					res[p].append(r)
		for z in eq.get("hides_hair_zones", []):
			res.hair.append(z)
	return res


# --- characters ---------------------------------------------------------------

func _character(pos: Vector3, yaw_deg: float, look_id: String, sex: float, show_hidden := false) -> Array:
	var lk: Dictionary = LOOKS[look_id]
	var parts: Array = []
	for id: String in lk.parts:
		if _entries.has(id):
			parts.append(id)
		else:
			failures.append("look %s: no catalog entry %s" % [look_id, id])
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	inst.scale = Vector3.ONE * (1.07 if sex > 0.5 else 1.0)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var paths := {"body": BodyMaterials.BODY_GLB}
	for id: String in parts:
		paths[id] = String(_entries[id].glb)
	var body := CharacterBodyMesh.attach_parts(sk, ap, paths)
	if body == null:
		failures.append("attach failed")
		return []
	var hides := _hides(parts)
	var male := sex > 0.5
	BodyMaterials.apply_look(body, {"sex": sex, "face": "m_face_1" if male else "f_face_2",
			"melanin": 0.28 if male else 0.42, "stubble": 0.35 if male else 0.0, "weathering": 0.4,
			"hide_regions": hides.body, "hide_hair_zones": hides.hair,
			"hair": {"style": String(lk.get("hair", "hair_queue_ribbon")), "color": String(lk.get("hair_color", "dark_brown"))}})
	if show_hidden:
		var cs := ShaderMaterial.new()
		cs.shader = _cover_skin
		cs.set_shader_parameter("hide_mask", BodyMaterials.hide_mask(hides.body))
		for mi in body.part_meshes("body"):
			for s in mi.mesh.get_surface_count():
				var sm: Material = mi.mesh.surface_get_material(s)
				if sm and sm.resource_name == "skin":
					mi.set_surface_override_material(s, cs)
	var over: Dictionary = lk.get("colors", {})
	for id: String in parts:
		var gm: ShaderMaterial = _garment_material(id, over.get(id, {}), BodyMaterials.hide_mask(hides[id]), show_hidden,
				String(lk.get("regiment", "")))
		for mi in body.part_meshes(id):
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, gm)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.deterministic = true
	_pose(ap, IDLE, 0.0)
	var c := [inst, sk, ap, body]
	chars.append(c)
	return c


func _clear() -> void:
	for c in chars:
		(c[0] as Node).queue_free()
	chars.clear()
	await _frames(2)


func _pose(ap: AnimationPlayer, clip: String, frac: float) -> void:
	var anim := "actor_b/" + clip
	if not ap.has_animation(anim):
		failures.append("missing clip " + clip)
		return
	ap.play(anim)
	ap.seek(frac * ap.get_animation(anim).length, true)
	ap.advance(0.0)


func _look_at(target: Vector3, offset: Vector3, fov := 28.0) -> void:
	cam.fov = fov
	cam.global_position = target + offset
	cam.look_at(target)


func _shot(name: String) -> String:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	root.get_viewport().get_texture().get_image().save_png(p)
	return p


# --- modes --------------------------------------------------------------------

func _sheets(looks: Array) -> void:
	for lid: String in looks:
		print("look ", lid)
		for sx in [0.0, 1.0]:
			var tag := "%s_%s" % [lid, "m" if sx > 0.5 else "f"]
			var k := 1.07 if sx > 0.5 else 1.0
			var yaws := [0.0, 35.0, 180.0, 90.0]
			for j in 4:
				_character(Vector3(j * 1.2 - 1.8, 0, 0), yaws[j], lid, sx)
			await _frames(2)
			_look_at(Vector3(0, 0.86 * k, 0), Vector3(0, 0.2, 7.9 * k), 26.0)
			await _shot(tag + "_views")
			await _clear()
			for half in 2:
				for j in 3:
					var pz: Array = POSES[half * 3 + j]
					var c := _character(Vector3(j * 1.3 - 1.3, 0, 0), 30.0, lid, sx)
					_pose(c[2], pz[1], pz[2])
				await _frames(2)
				_look_at(Vector3(0, 0.78 * k, 0), Vector3(0, 0.45, 6.4 * k), 30.0)
				await _shot("%s_poses%d" % [tag, half])
				_look_at(Vector3(0, 0.78 * k, 0), Vector3(-2.0, 0.8, -6.0 * k), 30.0)
				await _shot("%s_poses%d_back" % [tag, half])
				await _clear()


func _closeups() -> void:
	var shots := [["br_44th_1755", 1.0, 20.0, Vector3(0, 1.12, 0), Vector3(0.18, 0.05, 1.05), "chest"],
			["br_44th_1755", 1.0, 200.0, Vector3(0, 0.95, 0), Vector3(-0.3, 0.05, 1.6), "back"],
			["br_44th_1755", 0.0, -50.0, Vector3(0.0, 0.62, 0), Vector3(0.9, 0.1, 1.1), "legs"],
			["br_44th_1755", 1.0, 30.0, Vector3(0, 1.62, 0), Vector3(0.1, 0.06, 0.75), "hat"],
			["fr_marine_garrison", 1.0, 20.0, Vector3(0, 1.1, 0), Vector3(0.2, 0.05, 1.1), "chest"],
			["fr_marine_garrison", 0.0, 60.0, Vector3(0, 0.95, 0), Vector3(1.2, 0.1, 0.7), "side"],
			["fr_marine_stockings", 1.0, -30.0, Vector3(0, 0.45, 0), Vector3(0.6, 0.1, 1.2), "legs"],
			["br_48th_1755", 1.0, 25.0, Vector3(0.22, 1.02, 0), Vector3(0.35, 0.05, 0.65), "cuff"]]
	for s: Array in shots:
		var c := _character(Vector3.ZERO, s[2], s[0], s[1])
		await _frames(2)
		var sk: Skeleton3D = c[1]
		var tgt: Vector3 = s[3] * (1.07 if s[1] > 0.5 else 1.0)
		_look_at(tgt, s[4], 26.0)
		await _shot("close_%s_%s_%s" % [s[0], "m" if s[1] > 0.5 else "f", s[5]])
		await _clear()


func _coverage(looks: Array) -> void:
	var worst := 0
	for lid: String in looks:
		for sx in [0.0, 1.0]:
			var tag := "%s_%s" % [lid, "m" if sx > 0.5 else "f"]
			var total := 0
			var per := []
			for k in COVER_CLIPS.size():
				var yaws := [0.0, 90.0, 180.0, 270.0]
				for j in 4:
					var c := _character(Vector3(j * 1.0 - 1.5, 0, 0), yaws[j], lid, sx, true)
					_pose(c[2], COVER_CLIPS[k][0], COVER_CLIPS[k][1])
				await _frames(2)
				_look_at(Vector3(0, 0.8, 0), Vector3(0, 0.6, 9.4), 28.0)
				var p := await _shot("cover_%s_%02d" % [tag, k])
				var n := _magenta(p)
				total += n
				per.append("%s %d" % [String(COVER_CLIPS[k][0]).trim_prefix("actor_b-p-"), n])
				await _clear()
			worst = maxi(worst, total)
			print("COVERAGE %s: %d magenta px over %d poses x 4 sides (%s)" % [tag, total, COVER_CLIPS.size(), ", ".join(per)])


func _magenta(path: String) -> int:
	var img := Image.load_from_file(path)
	var n := 0
	for y in range(0, img.get_height()):
		for x in range(0, img.get_width()):
			var c := img.get_pixel(x, y)
			if c.r > 0.6 and c.b > 0.6 and c.g < 0.3:
				n += 1
	return n
