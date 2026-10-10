extends SceneTree
## Preview renders of the colonial militia garments (assets/character/garments/militia) on
## the customizer body, both fits, with a preview cloth shader (the fabric kits' luminance
## detail tinted to the palette colour, zones from UV2, hide masks, COLOR shading). Needs a
## window (not --headless); run it under a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/character/garments/militia/militia_preview.gd -- out=DIR [only=presets,items,poses,close]
##
## Hiding follows the design (§4.3): region r of part p is hidden when an equipped garment q
## lists r in hides_regions with a higher layer than p's at r (skin 0, hair 70); hats hide
## their hair zones. Outfits come from assets/character/garments/militia/catalog.json
## (presets). Contact sheets <out>/sheet_<group>*.png are composed at the end.
## Prints MILITIA PREVIEW DONE (or FAILED with the reasons).

const CAT := "res://assets/character/garments/militia/catalog.json"
const IDLE := "actor_b-p-stealth-idle"
const KITS := {"LIN": "rough_linen", "WOOL": "caban", "TWILL": "poly_wool_herringbone", "KNIT": "knitted_fleece",
		"SUEDE": "scuba_suede", "LEA": "brown_leather", "FUR": "curly_teddy_natural", "HES": "hessian_230"}
const KIT_DIR := "res://assets/polyhaven/textures/clothing/"
const LAYER_GROUPS := {"head": "head", "neck": "neck", "chest": "torso_upper", "abdomen": "torso_lower",
		"pelvis": "hips", "upper_arm": "arms_upper", "forearm": "arms_lower", "wrist": "arms_lower",
		"hand": "hands", "thigh": "thighs", "shin": "shins", "ankle": "shins", "foot": "feet"}

const CLOTH_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform vec4 zone_color[4];
uniform vec4 zone_color2[4];
uniform vec4 zone_params[4];      // x tile m, y detail strength, z roughness, w metallic
uniform vec4 zone_pattern[4];     // x kind (0 none, 1 check, 2 stripe), y scale m
uniform vec4 zone_mean;           // mean luminance of each zone's kit
uniform sampler2D kit0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D kit1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D kit2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D kit3 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm0 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm3 : hint_normal, filter_linear_mipmap, repeat_enable;
varying flat uint v_zone;
bool hidden_r(uint r) {
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	return (bits & 1u) != 0u;
}
void vertex() {
	uint code = uint(UV2.x + 0.5);
	v_zone = min(code >> 6u, 3u);
	if (hidden_r(code & 63u)) { VERTEX = vec3(0.0); }
}
void fragment() {
	int z = int(v_zone);
	vec4 p = zone_params[z];
	vec2 uv = UV / max(p.x, 0.01);
	vec3 d; vec3 n;
	if (z == 0) { d = texture(kit0, uv).rgb; n = texture(nrm0, uv).rgb; }
	else if (z == 1) { d = texture(kit1, uv).rgb; n = texture(nrm1, uv).rgb; }
	else if (z == 2) { d = texture(kit2, uv).rgb; n = texture(nrm2, uv).rgb; }
	else { d = texture(kit3, uv).rgb; n = texture(nrm3, uv).rgb; }
	float lum = dot(d, vec3(0.2126, 0.7152, 0.0722));
	float mean = z == 0 ? zone_mean.x : (z == 1 ? zone_mean.y : (z == 2 ? zone_mean.z : zone_mean.w));
	float detail = mix(1.0, lum / max(mean, 0.02), p.y);
	vec3 col = zone_color[z].rgb;
	vec4 pat = zone_pattern[z];
	if (pat.x > 0.5) {
		float s = max(pat.y, 0.002);
		float a = step(0.5, fract(UV.x / s));
		float b = step(0.5, fract(UV.y / s));
		float m = pat.x < 1.5 ? clamp(a + b, 0.0, 2.0) * 0.5 : b;
		col = mix(zone_color2[z].rgb, col, m);
	}
	ALBEDO = col * clamp(detail, 0.3, 1.8) * COLOR.rgb;
	ROUGHNESS = p.z;
	METALLIC = p.w;
	if (p.y > 0.0) { NORMAL_MAP = n; NORMAL_MAP_DEPTH = 0.6 * p.y; }
}
"""

var args := {}
var out := ""
var failures := PackedStringArray()
var world: Node3D
var cam: Camera3D
var label: Label
var chars: Array = []
var cat := {}
var tokens := {}
var shader: Shader
var kit_cache := {}
var shots := {}      # group -> [paths]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = args.get("out", "user://militia_preview")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, OS.has_environment("TB_ON_TOP"))
	var c = JSON.parse_string(FileAccess.get_file_as_string(CAT))
	if not c is Dictionary:
		print("MILITIA PREVIEW FAILED: no ", CAT)
		quit(1)
		return
	cat = c
	for id: String in cat.get("cross_set_items", {}):
		cat.items[id] = cat.cross_set_items[id]
	tokens = cat.get("tokens", {})
	for e: Dictionary in cat.items.values():
		for z: Dictionary in e.zones:
			for t in z.get("palette_hex", {}):
				tokens[t] = z.palette_hex[t]
	shader = Shader.new()
	shader.code = CLOTH_SHADER
	await _studio()
	for g in ["presets", "items", "poses", "close", "layers"]:
		if not _wanted(g):
			continue
		print("group ", g)
		match g:
			"presets": await _presets()
			"items": await _items()
			"poses": await _poses()
			"close": await _close()
			"layers": await _layers()
	_sheets()
	print("MILITIA PREVIEW DONE" if failures.is_empty() else "MILITIA PREVIEW FAILED: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _wanted(g: String) -> bool:
	return not args.has("only") or g in String(args.only).split(",")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _studio() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.40, 0.42, 0.44)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	for l in [[Vector3(-35, 30, 0), 1.1, true], [Vector3(-15, -60, 0), 0.35, false], [Vector3(-25, 160, 0), 0.55, false]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = l[1]
		d.shadow_enabled = l[2]
		world.add_child(d)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.33, 0.33, 0.32)
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	cam = Camera3D.new()
	cam.fov = 28.0
	cam.near = 0.02
	world.add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	root.add_child(cl)
	label = Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	cl.add_child(label)


# --- fabric kits (loaded from the source images; the assets/polyhaven imports are not touched)

func _kit(code: String) -> Array:
	if kit_cache.has(code):
		return kit_cache[code]
	var res := [null, null, 0.5]
	if KITS.has(code):
		var base: String = KIT_DIR + String(KITS[code]) + "/" + String(KITS[code])
		var d := Image.load_from_file(ProjectSettings.globalize_path(base + "_diffuse_2k.jpg"))
		var n := Image.load_from_file(ProjectSettings.globalize_path(base + "_nor_gl_2k.jpg"))
		if d and n:
			d.resize(1024, 1024, Image.INTERPOLATE_CUBIC)
			n.resize(1024, 1024, Image.INTERPOLATE_CUBIC)
			var s := 0.0
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 2000:
				var c := d.get_pixel(rng.randi_range(0, 1023), rng.randi_range(0, 1023))
				s += c.srgb_to_linear().get_luminance()
			d.generate_mipmaps()
			n.generate_mipmaps()
			res = [ImageTexture.create_from_image(d), ImageTexture.create_from_image(n), s / 2000.0]
		else:
			failures.append("fabric kit %s not readable" % code)
	kit_cache[code] = res
	return res


func _hex(tok: String) -> Color:
	if tok.begins_with("#"):
		return Color(tok)
	return Color(String(tokens.get(tok, "#808080")))


# --- looks ----------------------------------------------------------------------------

## A look: {sex, melanin, face, hair: {...}, outfit: {slot: use}, accessories: [use]}; use =
## {id, colors: {role: token}, fabric: {role: code}, pattern: {role: option}}.
func _character(pos: Vector3, yaw_deg: float, look: Dictionary) -> Array:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var body := CharacterBodyMesh.attach_parts(sk, ap, {"body": BodyMaterials.BODY_GLB})
	if body == null:
		failures.append("body.glb did not attach")
		return []
	var uses: Array = []
	for slot: String in look.get("outfit", {}):
		uses.append([slot, look.outfit[slot]])
	for u: Dictionary in look.get("accessories", []):
		uses.append([String(cat.items.get(u.id, {}).get("slot", "accessories")), u])
	var items := []
	for su: Array in uses:
		var use: Dictionary = su[1]
		var e: Dictionary = cat.items.get(use.id, {})
		if e.is_empty():
			failures.append("unknown item %s" % use.id)
			continue
		var glb := String(e.glb)
		if use.has("variant") and (e.get("variants", {}) as Dictionary).has(use.variant):
			glb = String(e.variants[use.variant])
		body.add_part(String(su[0]) + ":" + String(use.id), glb)
		items.append([e, use, String(su[0]) + ":" + String(use.id)])
	# hiding (design §4.3)
	var skin_hide := []
	var hair_hide := []
	for it: Array in items:
		var e: Dictionary = it[0]
		for r in e.get("hides_regions", []):
			if not r in skin_hide:
				skin_hide.append(r)
		for z in e.get("hides_hair_zones", []):
			if not z in hair_hide:
				hair_hide.append(z)
	var lk := look.duplicate(true)
	lk["hide_regions"] = skin_hide
	lk["hide_hair_zones"] = hair_hide
	BodyMaterials.apply_look(body, lk)
	for it: Array in items:
		var e: Dictionary = it[0]
		var hide := []
		for q: Array in items:
			if q == it:
				continue
			var eq: Dictionary = q[0]
			for r: String in eq.get("hides_regions", []):
				if _layer(eq, r) > _layer(e, r) and not r in hide:
					hide.append(r)
		var mat := _cloth_material(e, it[1], hide)
		for mi: MeshInstance3D in body.part_meshes(it[2]):
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, mat)
	body.set_blend_shape("sex", float(look.get("sex", 0.0)))
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.deterministic = true
	_pose(ap, IDLE, 0.0)
	var c := [inst, sk, ap, body]
	chars.append(c)
	return c


func _layer(e: Dictionary, region: String) -> int:
	var L: Dictionary = e.get("layer", {"default": 10})
	for pre: String in LAYER_GROUPS:
		if region.begins_with(pre):
			var g: String = LAYER_GROUPS[pre]
			if L.has(g):
				return int(L[g])
	return int(L.get("default", 10))


func _cloth_material(e: Dictionary, use: Dictionary, hide: Array) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	var cols := []
	var cols2 := []
	var params := []
	var pats := []
	var means := [0.5, 0.5, 0.5, 0.5]
	var colors: Dictionary = use.get("colors", {})
	var fabrics: Dictionary = use.get("fabric", {})
	var patterns: Dictionary = use.get("pattern", {})
	for zi in 4:
		cols.append(Color(0.5, 0.5, 0.5))
		cols2.append(Color(0.9, 0.9, 0.88))
		params.append(Vector4(0.27, 0.0, 0.85, 0.0))
		pats.append(Vector4(0, 0.01, 0, 0))
	for z: Dictionary in e.zones:
		var zi := int(z.zone)
		var role := String(z.role)
		var tok := String(colors.get(role, z.get("default", "#808080")))
		var code := String(fabrics.get(role, z.get("fabric", "FLAT")))
		var metal: bool = code == "MET" or tok in ["brass", "pewter", "silver", "gold_lace", "silver_lace", "false_gold"]
		cols[zi] = _hex(tok).srgb_to_linear()
		var kit := _kit(code)
		var tile: float = float(cat.fabrics.get(code, {}).get("tile_m", 0.27))
		var rough := 0.35 if metal else (0.62 if code == "LEA" else (0.7 if code == "SUEDE" else 0.88))
		params[zi] = Vector4(tile if tile > 0.0 else 0.27, 0.0 if kit[0] == null or metal else 0.85, rough, 0.9 if metal else 0.0)
		means[zi] = kit[2]
		m.set_shader_parameter("kit%d" % zi, kit[0])
		m.set_shader_parameter("nrm%d" % zi, kit[1])
		var popt := String(patterns.get(role, "none"))
		var pat = z.get("pattern")
		if popt != "none" and pat is Dictionary and (pat as Dictionary).has(popt):
			var pd: Dictionary = pat[popt]
			var pc: Array = pd.get("colors", ["check_blue", "linen_white"])
			cols[zi] = _hex(String(pc[0])).srgb_to_linear()
			cols2[zi] = _hex(String(pc[1])).srgb_to_linear()
			pats[zi] = Vector4(1.0 if popt == "check" else 2.0, float(pd.get("scale_m", 0.01)), 0, 0)
	m.set_shader_parameter("zone_color", cols)
	m.set_shader_parameter("zone_color2", cols2)
	m.set_shader_parameter("zone_params", params)
	m.set_shader_parameter("zone_pattern", pats)
	m.set_shader_parameter("zone_mean", Vector4(means[0], means[1], means[2], means[3]))
	m.set_shader_parameter("hide_mask", BodyMaterials.hide_mask(hide))
	return m


func _preset_look(p: Dictionary, sex: float) -> Dictionary:
	var hair := String(p.get("hair_hint", "hair_queue_ribbon"))
	if sex < 0.5 and hair in ["hair_cropped_1758", "hair_club_ribbon"]:
		hair = "hair_pinned_capped"
	return {"sex": sex, "face": "m_face_1" if sex > 0.5 else "f_face_1", "melanin": 0.35,
			"hair": {"style": hair, "color": "dark_brown"}, "outfit": p.get("outfit", {}),
			"accessories": p.get("accessories", [])}


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


func _bone(c: Array, bone: String) -> Vector3:
	var sk: Skeleton3D = c[1]
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


func _look_at(target: Vector3, offset: Vector3, fov := 28.0) -> void:
	cam.fov = fov
	cam.global_position = target + offset
	cam.look_at(target)


func _shot(group: String, name: String, caption: String) -> String:
	label.text = caption
	await _frames(4)
	await RenderingServer.frame_post_draw
	var p := "%s/%s_%s.png" % [out, group, name]
	root.get_viewport().get_texture().get_image().save_png(p)
	if not shots.has(group):
		shots[group] = []
	(shots[group] as Array).append(p)
	return p


# --- groups ---------------------------------------------------------------------------

func _presets() -> void:
	for p: Dictionary in cat.presets:
		var yaws := [0.0, 40.0, 180.0]
		for i in 2:
			for j in 3:
				_character(Vector3((i * 3 + j) * 0.95 - 2.4, 0, 0), yaws[j], _preset_look(p, float(i)))
		await _frames(2)
		_look_at(Vector3(0, 0.85, 0), Vector3(0, 0.35, 12.5), 27.0)
		await _shot("presets", p.id, "%s  (female | male fit: front, 3/4, back)" % p.name)
		_look_at(Vector3(-1.45, 0.95, 0), Vector3(0, 0.25, 4.2), 25.0)
		await _shot("presets", p.id + "_f", "%s, female fit" % p.name)
		_look_at(Vector3(1.4, 0.95, 0), Vector3(0, 0.25, 4.2), 25.0)
		await _shot("presets", p.id + "_m", "%s, male fit" % p.name)
		await _clear()


func _items() -> void:
	var ids: Array = []
	for id: String in cat.items:
		if String(cat.items[id].get("set", "")) == "militia":
			ids.append(id)
	ids.sort()
	for id: String in ids:
		var e: Dictionary = cat.items[id]
		for i in 2:
			var look := {"sex": float(i), "face": "m_face_1" if i == 1 else "f_face_1", "melanin": 0.3,
					"hair": {"style": "hair_queue_ribbon" if i == 1 else "hair_pinned_capped", "color": "mid_brown"},
					"outfit": {String(e.slot): {"id": id}}}
			if String(e.slot).begins_with("accessories"):
				look.outfit = {}
				look["accessories"] = [{"id": id}]
			_character(Vector3(i * 1.8 - 1.35, 0, 0), 25.0, look)
			_character(Vector3(i * 1.8 - 0.45, 0, 0), 180.0 + 25.0, look)
		await _frames(2)
		var head := String(e.slot) in ["head", "accessories.neck"]
		if head:
			var c0: Array = chars[0]
			var hb := _bone(c0, "headb")
			for k in 4:
				(chars[k][0] as Node3D).position = Vector3(k * 0.42 - 0.63, 0, 0)
			_look_at(Vector3(0, hb.y - 0.06, 0), Vector3(0, 0.12, 2.3), 26.0)
		else:
			_look_at(Vector3(0.0, 0.85, 0), Vector3(0, 0.25, 5.0), 27.0)
		await _shot("items", id, "%s  [%s]  female (front, back) | male (front, back)" % [e.name, id])
		await _clear()


func _poses() -> void:
	var clips := [["run", "actor_b-p-run-fw", 0.3], ["crouch walk", "actor_b-p-crouch-walk-fw", 0.5],
			["musket aim", "actor_b-p-rifle-idle-aim", 0.0], ["bow aim", "actor_b-p-bow-aim-idle", 0.0],
			["reload", "actor_b-p-rifle-idle-aim-reload-mid--part", 0.5], ["ledge hang", "actor_b-p-idle-jump-up-3m^ledge-hang-mid", 0.5]]
	var which := String(args.get("pose_presets", "militia_backcountry,militia_townsman,provincial_ma_1758,militia_fatigue")).split(",")
	for p: Dictionary in cat.presets:
		if not p.id in which:
			continue
		for i in 2:
			for half in 2:
				var names := []
				for jj in 3:
					var j := half * 3 + jj
					var c := _character(Vector3(jj * 1.0 - 1.0, 0, 0), 30.0, _preset_look(p, float(i)))
					_pose(c[2], clips[j][1], clips[j][2])
					names.append(clips[j][0])
				await _frames(2)
				_look_at(Vector3(0, 0.85, 0), Vector3(0, 0.45, 4.6), 30.0)
				await _shot("poses", "%s_%s_%d" % [p.id, ["f", "m"][i], half], "%s, %s fit: %s" % [p.name, ["female", "male"][i], ", ".join(names)])
				_look_at(Vector3(0, 0.85, 0), Vector3(-1.2, 0.8, -4.3), 30.0)
				await _shot("poses", "%s_%s_%d_back" % [p.id, ["f", "m"][i], half], "%s, %s fit, from behind: %s" % [p.name, ["female", "male"][i], ", ".join(names)])
				await _clear()


func _close() -> void:
	# neckwear and collars, armpits with the arms up, knees in a crouch, hats on the hair styles
	var p: Dictionary = cat.presets[0]
	for pr: Dictionary in cat.presets:
		if pr.id == "militia_townsman":
			p = pr
	for i in 2:
		var c := _character(Vector3.ZERO, 20.0, _preset_look(p, float(i)))
		await _frames(1)
		var hb := _bone(c, "headb")
		_look_at(hb + Vector3(0, -0.12, 0), Vector3(0.2, 0.02, 0.8), 26.0)
		await _shot("close", "neck_%d" % i, "%s: neck and collar (%s)" % [p.name, ["female", "male"][i]])
		_pose(c[2], "actor_b-p-bow-aim-idle", 0.0)
		await _frames(1)
		var sh := _bone(c, "l_shoulder")
		_look_at(sh + Vector3(0, -0.1, 0), Vector3(0.9, 0.1, 0.5), 30.0)
		await _shot("close", "armpit_%d" % i, "%s: bow aim, left shoulder and armpit (%s)" % [p.name, ["female", "male"][i]])
		_pose(c[2], "actor_b-p-crouch-idle", 0.0)
		await _frames(1)
		var kn := _bone(c, "l_knee")
		_look_at(kn + Vector3(0, 0.05, 0), Vector3(0.6, 0.2, 0.9), 32.0)
		await _shot("close", "knee_%d" % i, "%s: crouch, knees and skirt (%s)" % [p.name, ["female", "male"][i]])
		await _clear()
	var hats := ["tricorn", "round_hat_cut", "monmouth_cap"]
	var styles := ["hair_queue_ribbon", "hair_club_ribbon", "hair_loose_tied", "hair_cropped_1758", "hair_natural_short",
			"hair_pinned_capped", "hair_braid_f", "hair_club_wrapped_f"]
	for h: String in hats:
		if not cat.items.has(h):
			continue
		for half in 2:
			for kk in 4:
				var k := half * 4 + kk
				var look := {"sex": 1.0 if k < 5 else 0.0, "face": "m_face_1" if k < 5 else "f_face_2", "melanin": [0.25, 0.5, 0.8][k % 3],
						"hair": {"style": styles[k], "color": ["dark_brown", "black", "chestnut"][k % 3]},
						"outfit": {"head": {"id": h}}}
				_character(Vector3(kk * 0.42 - 0.63, 0, 0), [150.0, 210.0, 120.0, 250.0][kk], look)
			await _frames(2)
			_look_at(Vector3(0, 1.42, 0), Vector3(0, 0.16, 2.3), 28.0)
			await _shot("close", "hat_%s_%d" % [h, half], "%s on %s" % [cat.items[h].name, ", ".join(styles.slice(half * 4, half * 4 + 4))])
			await _clear()


func _layers() -> void:
	# an outfit put on one garment at a time (layer order, cut edges, hiding), torso close-up
	var order := ["shirt", "legs.lower", "legs.over", "feet", "vest", "accessories", "outer", "head"]
	for pid in ["militia_townsman", "provincial_ma_1758"]:
		var p: Dictionary = {}
		for pr: Dictionary in cat.presets:
			if pr.id == pid:
				p = pr
		if p.is_empty():
			continue
		var steps := []
		for k in range(1, order.size() + 1):
			var look := _preset_look(p, 1.0)
			var outfit := {}
			for slot: String in look.outfit:
				if slot in order.slice(0, k):
					outfit[slot] = look.outfit[slot]
			look.outfit = outfit
			if not "accessories" in order.slice(0, k):
				look.accessories = []
			steps.append(look)
		for k in steps.size():
			var c := _character(Vector3(k * 0.8 - 2.8, 0, 0), 15.0, steps[k])
		await _frames(2)
		for k in steps.size():
			var sp := _bone(chars[k], "spined")
			_look_at(sp + Vector3(0, 0.0, 0), Vector3(0.12, 0.05, 0.95), 30.0)
			await _shot("layers", "%s_%d" % [pid, k], "%s, male fit: + %s" % [p.name, order[k]])
		await _clear()


# --- contact sheets -------------------------------------------------------------------

func _sheets() -> void:
	for g: String in shots:
		var paths: Array = shots[g]
		var per := 6 if g != "presets" else 3
		var cols := 2 if g != "presets" else 1
		for k in range(0, paths.size(), per):
			var batch := paths.slice(k, k + per)
			var imgs := []
			for p: String in batch:
				var im := Image.load_from_file(p)
				if im:
					im.resize(im.get_width() / 2, im.get_height() / 2)
					imgs.append(im)
			if imgs.is_empty():
				continue
			var w: int = imgs[0].get_width()
			var h: int = imgs[0].get_height()
			var rows := (imgs.size() + cols - 1) / cols
			var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
			for n in imgs.size():
				var im: Image = imgs[n]
				im.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((n % cols) * w, (n / cols) * h))
			sheet.save_png("%s/sheet_%s_%02d.png" % [out, g, k / per])
