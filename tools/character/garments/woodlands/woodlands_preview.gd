extends SceneTree
## Preview renders of the Eastern Woodlands garments (tools/character/garments/woodlands)
## on the customizer body, both fits, with the approved Poly Haven fabrics tinted to the
## catalog colours by a small preview shader (the game's cloth shader belongs to the
## fabric workstream; this one only reads what the garment glbs carry: UV in metres, zone
## and region codes in UV2, edge distances in CUSTOM0, the shading multiplier in COLOR).
## Needs a window; run it under a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/character/garments/woodlands/woodlands_preview.gd -- \
##       out=<dir> [only=presets,poses,items,close]
##
## Reads assets/character/garments/woodlands/catalog.json (items, presets). Hidden regions:
## the body skin under a garment that hides it, and a garment's own regions under a garment
## of a higher layer (design §4.3), as the runtime will do. Prints WOODLANDS PREVIEW DONE.

const SET_CATALOG := "res://assets/character/garments/woodlands/catalog.json"
const TEX := "res://assets/polyhaven/textures/clothing/%s/%s_%s_2k.jpg"
## bible fabric code -> (Poly Haven kit, tile metres, mean sRGB colour of the scan; design §2.4)
const FABRICS := {
	"LIN": ["rough_linen", 0.271, "#90adc9"], "WOOL": ["caban", 0.274, "#c76404"],
	"TWILL": ["poly_wool_herringbone", 0.270, "#797571"], "KNIT": ["knitted_fleece", 0.266, "#554b3f"],
	"SUEDE": ["scuba_suede", 0.285, "#125e6b"], "LEA": ["brown_leather", 0.400, "#512d10"],
	"FUR": ["curly_teddy_natural", 0.336, "#edcdb9"], "HES": ["hessian_230", 0.269, "#8c7859"],
}
const IDLE := "actor_b-p-stealth-idle"

const SHADER := """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;
uniform sampler2D alb0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D alb1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D alb2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D alb3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor0 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor1 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor2 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor3 : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint[4];
uniform float tile[4];
uniform float lum_mean[4];
uniform float detail[4];
uniform float metal[4];
uniform float nstrength[4];
uniform int band_axis[4];
uniform int band_rows[4];
uniform vec4 band_col[12];
uniform float band_w[4];
uniform float band_gap[4];
uniform float band_off[4];
uniform float list_w[4];
uniform vec4 list_col[4];
uniform int pattern[4];
uniform vec4 pat_col[4];
uniform float pat_scale[4];
uniform uvec2 hide_mask;
varying flat int zone;
varying vec2 edge;

void vertex() {
	uint code = uint(UV2.x + 0.5);
	uint r = code & 63u;
	zone = int(code >> 6u);
	bool hid = r < 32u ? ((hide_mask.x >> r) & 1u) != 0u : ((hide_mask.y >> (r - 32u)) & 1u) != 0u;
	if (hid) {
		VERTEX = vec3(0.0);
	}
	edge = CUSTOM0.xy;
}

vec3 kit(int z, vec2 uv, out vec3 n) {
	if (z == 0) { n = texture(nor0, uv).rgb; return texture(alb0, uv).rgb; }
	if (z == 1) { n = texture(nor1, uv).rgb; return texture(alb1, uv).rgb; }
	if (z == 2) { n = texture(nor2, uv).rgb; return texture(alb2, uv).rgb; }
	n = texture(nor3, uv).rgb; return texture(alb3, uv).rgb;
}

void fragment() {
	int z = clamp(zone, 0, 3);
	vec3 n;
	vec3 t = kit(z, UV / max(tile[z], 0.01), n);
	float lum = dot(t, vec3(0.2126, 0.7152, 0.0722));
	float d = clamp(lum / max(lum_mean[z], 1e-3), 0.25, 2.2);
	vec3 base = tint[z].rgb * mix(1.0, d, detail[z]);
	if (pattern[z] == 1) {      // window-pane check
		vec2 c = fract(UV / pat_scale[z]);
		float line = max(step(c.x, 0.28), step(c.y, 0.28));
		base = mix(base, pat_col[z].rgb * mix(1.0, d, detail[z]), line * 0.85);
	}
	float dist = band_axis[z] == 1 ? edge.x : (band_axis[z] == 2 ? edge.y : 9.0);
	if (dist < list_w[z]) {
		base = list_col[z].rgb * mix(1.0, d, detail[z] * 0.6);
	} else {
		for (int k = 0; k < 3; k++) {
			if (k >= band_rows[z]) break;
			float a = band_off[z] + float(k) * (band_w[z] + band_gap[z]);
			if (dist >= a && dist < a + band_w[z]) {
				base = band_col[z * 3 + k].rgb * mix(1.0, d, 0.35);
			}
		}
	}
	ALBEDO = base * COLOR.rgb;
	METALLIC = metal[z];
	ROUGHNESS = metal[z] > 0.5 ? 0.28 : 0.88;
	SPECULAR = metal[z] > 0.5 ? 0.5 : 0.25;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = nstrength[z];
}
"""

var args := {}
var out := ""
var failures := PackedStringArray()
var world: Node3D
var cam: Camera3D
var chars: Array = []
var cat := {}
var shader: Shader
var tex_cache := {}
var region_group := {}
var region_ids := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = args.get("out", "user://woodlands_preview")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	cat = JSON.parse_string(FileAccess.get_file_as_string(SET_CATALOG))
	shader = Shader.new()
	shader.code = SHADER
	var r: Dictionary = BodyMaterials.body_info().get("regions", {})
	for n: String in r.get("ids", {}):
		region_ids[n] = int(r.ids[n])
		region_group[n] = String(r.groups[n])
	await _studio()
	for g in ["presets", "poses", "items", "close"]:
		if args.has("only") and not g in String(args.only).split(","):
			continue
		print("group ", g)
		match g:
			"presets": await _presets()
			"poses": await _poses()
			"items": await _items()
			"close": await _close()
	print("WOODLANDS PREVIEW DONE" if failures.is_empty() else "WOODLANDS PREVIEW FAILED: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _studio() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.38, 0.40)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.53, 0.58)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	for l in [[Vector3(-35, 30, 0), 1.1, true], [Vector3(-15, -60, 0), 0.35, false], [Vector3(-25, 160, 0), 0.6, false]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = l[1]
		d.shadow_enabled = l[2]
		world.add_child(d)
	cam = Camera3D.new()
	cam.fov = 28.0
	cam.near = 0.02
	world.add_child(cam)
	cam.current = true


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


func _pose(ap: AnimationPlayer, clip: String, frac: float) -> void:
	var anim := "actor_b/" + clip
	if not ap.has_animation(anim):
		failures.append("missing clip " + clip)
		return
	ap.play(anim)
	ap.seek(frac * ap.get_animation(anim).length, true)
	ap.advance(0.0)


func _clear() -> void:
	for c in chars:
		(c[0] as Node).queue_free()
	chars.clear()
	await _frames(2)


# --- materials ------------------------------------------------------------------

func _tex(kit: String, kind: String) -> Texture2D:
	var key := kit + "/" + kind
	if not tex_cache.has(key):
		tex_cache[key] = load(TEX % [kit, kit, kind])
	return tex_cache[key]


static func _lin(c: Color) -> Color:
	return c.srgb_to_linear()


func _hex(entry_zone: Dictionary, tok: String) -> Color:
	if tok.begins_with("#"):
		return Color(tok)
	var ph: Dictionary = entry_zone.get("palette_hex", {})
	if ph.has(tok):
		return Color(String(ph[tok]))
	return Color("#808080")


## Band colours: palette tokens resolve through the zone's band palette (bible §0.4 hexes
## live in lib/materials.py; the catalog carries palette_hex for the zone palette only).
const BAND_HEX := {"ribbon_red": "#B2202C", "ribbon_green": "#2E6B40", "ribbon_yellow": "#D8B23A",
		"ribbon_blue": "#2D4F8C", "ribbon_white": "#ECE8DE", "ribbon_black": "#151417", "bead_white": "#EEEBE3",
		"quill_red": "#A8262A", "quill_orange": "#C8672A", "quill_yellow": "#D2AE3C", "quill_black": "#1A1918",
		"quill_white": "#E7E2D2", "linen_white": "#E8E3D3", "linen_unbleached": "#C8BA9A", "check_blue": "#2F4166"}


func garment_material(entry: Dictionary, sel: Dictionary, hide: Vector2i) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	var tints := []
	var tiles := []
	var means := []
	var details := []
	var metals := []
	var nstr := []
	var baxis := []
	var brows := []
	var bcols := []
	var bw := []
	var bgap := []
	var boff := []
	var lw := []
	var lcol := []
	var pats := []
	var pcol := []
	var pscale := []
	var zones: Array = entry.get("zones", [])
	for zi in 4:
		var z: Dictionary = {}
		for zz: Dictionary in zones:
			if int(zz.zone) == zi:
				z = zz
		var fabric := String(z.get("fabric", "FLAT"))
		var metal := bool(z.get("metal", false)) or fabric == "MET"
		var tok := String((sel.get("colors", {}) as Dictionary).get(String(z.get("name", "")), z.get("default", "#808080")))
		var col := _hex(z, tok)
		tints.append(_lin(col))
		var fk: Array = FABRICS.get(fabric, ["", 0.3, "#808080"])
		if fk[0] != "":
			m.set_shader_parameter("alb%d" % zi, _tex(fk[0], "diffuse"))
			m.set_shader_parameter("nor%d" % zi, _tex(fk[0], "nor_gl"))
		tiles.append(float(fk[1]))
		var mc := _lin(Color(String(fk[2])))
		means.append(mc.r * 0.2126 + mc.g * 0.7152 + mc.b * 0.0722)
		details.append(0.0 if fk[0] == "" else 0.85)
		metals.append(1.0 if metal else 0.0)
		nstr.append(0.0 if fk[0] == "" else (0.5 if fabric in ["LIN", "WOOL"] else 0.8))
		var bands = z.get("bands", null)
		var rows_sel: Array = (sel.get("bands", {}) as Dictionary).get(String(z.get("name", "")), [])
		if bands is Dictionary:
			var ax := String((bands as Dictionary).get("axis", ""))
			baxis.append(1 if ax == "x" else (2 if ax == "y" else 0))
			if rows_sel.is_empty():
				rows_sel = (bands as Dictionary).get("default", [])
			var lst = (bands as Dictionary).get("list", null)
			if lst is Dictionary:
				lw.append(float(lst.width))
				lcol.append(_lin(Color(BAND_HEX.get(String(lst.color), "#E8E3D3"))))
			elif String((bands as Dictionary).get("name", "")).contains("list"):
				lw.append(float(bands.get("row_width", 0.015)))
				lcol.append(_lin(Color(BAND_HEX.get(String((bands.get("default", ["linen_white"]) as Array)[0]), "#E8E3D3"))))
				rows_sel = []
			else:
				lw.append(0.0)
				lcol.append(Color(1, 1, 1))
			brows.append(mini(rows_sel.size(), 3))
			bw.append(float(bands.get("row_width", 0.006)))
			bgap.append(float(bands.get("gap", 0.003)))
			boff.append(float(bands.get("offset", 0.0)) + (float(lw[-1]) + 0.004 if float(lw[-1]) > 0.0 else 0.004))
		else:
			baxis.append(0)
			brows.append(0)
			bw.append(0.0)
			bgap.append(0.0)
			boff.append(0.0)
			lw.append(0.0)
			lcol.append(Color(1, 1, 1))
		for k in 3:
			bcols.append(_lin(Color(BAND_HEX.get(String(rows_sel[k]) if k < rows_sel.size() else "", "#ffffff"))))
		var pat := String((sel.get("pattern", {}) as Dictionary).get(String(z.get("name", "")), "none"))
		pats.append(1 if pat == "check" else 0)
		pcol.append(_lin(Color("#2F4166")))
		pscale.append(0.012)
	m.set_shader_parameter("tint", PackedColorArray(tints))
	m.set_shader_parameter("tile", PackedFloat32Array(tiles))
	m.set_shader_parameter("lum_mean", PackedFloat32Array(means))
	m.set_shader_parameter("detail", PackedFloat32Array(details))
	m.set_shader_parameter("metal", PackedFloat32Array(metals))
	m.set_shader_parameter("nstrength", PackedFloat32Array(nstr))
	m.set_shader_parameter("band_axis", PackedInt32Array(baxis))
	m.set_shader_parameter("band_rows", PackedInt32Array(brows))
	m.set_shader_parameter("band_col", PackedColorArray(bcols))
	m.set_shader_parameter("band_w", PackedFloat32Array(bw))
	m.set_shader_parameter("band_gap", PackedFloat32Array(bgap))
	m.set_shader_parameter("band_off", PackedFloat32Array(boff))
	m.set_shader_parameter("list_w", PackedFloat32Array(lw))
	m.set_shader_parameter("list_col", PackedColorArray(lcol))
	m.set_shader_parameter("pattern", PackedInt32Array(pats))
	m.set_shader_parameter("pat_col", PackedColorArray(pcol))
	m.set_shader_parameter("pat_scale", PackedFloat32Array(pscale))
	m.set_shader_parameter("hide_mask", hide)
	return m


static func _layer(entry: Dictionary, group: String) -> int:
	var l: Dictionary = entry.get("layer", {})
	return int(l.get(group, l.get("default", 10)))


## Regions each part hides (design §4.3): region r of part p is hidden when an equipped q
## (not p) hides r at a higher layer. The skin is layer 0.
func _hidden_for(p_entry, equipped: Array) -> Array:
	var outl := []
	for r: String in region_ids:
		var g := String(region_group[r])
		var lp := 0 if p_entry == null else _layer(p_entry, g)
		for q: Dictionary in equipped:
			if q == p_entry:
				continue
			if r in q.get("hides_regions", []) and _layer(q, g) > lp:
				outl.append(r)
				break
	return outl


# --- characters -------------------------------------------------------------------

## A fresh Actor_B with the body, a look (skin, face, hair) and a list of garment
## selections [{"id", "colors", "bands", "pattern"}].
func _character(pos: Vector3, yaw_deg: float, look: Dictionary, wear: Array) -> Array:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	var sex := float(look.get("sex", 0.0))
	inst.scale = Vector3.ONE * (1.07 if sex > 0.5 else 1.0)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var body := CharacterBodyMesh.attach_parts(sk, ap, {"body": BodyMaterials.BODY_GLB})
	if body == null:
		failures.append("body.glb did not attach")
		return []
	var items: Dictionary = cat.get("items", {})
	var equipped := []
	for w: Dictionary in wear:
		var e: Dictionary = items.get(String(w.id), {})
		if e.is_empty():
			failures.append("unknown item " + String(w.id))
			continue
		body.add_part(String(w.id), String(e.glb))
		equipped.append(e)
	var lk := look.duplicate(true)
	lk["hide_regions"] = _hidden_for(null, equipped)
	var hz := []
	for e: Dictionary in equipped:
		hz += e.get("hides_hair_zones", [])
	lk["hide_hair_zones"] = hz
	BodyMaterials.apply_look(body, lk)
	for i in wear.size():
		var w: Dictionary = wear[i]
		var e: Dictionary = items.get(String(w.id), {})
		if e.is_empty():
			continue
		var hide := BodyMaterials.hide_mask(_hidden_for(e, equipped))
		var mat := garment_material(e, w, hide)
		for mi: MeshInstance3D in body.part_meshes(String(w.id)):
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, mat)
	body.set_blend_shape("sex", sex)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.deterministic = true
	_pose(ap, IDLE, 0.0)
	var c := [inst, sk, ap, body]
	chars.append(c)
	return c


func _wear_of(preset: Dictionary) -> Array:
	var w := []
	for slot: String in preset.get("outfit", {}):
		w.append(preset.outfit[slot])
	for a in preset.get("accessories", []):
		w.append(a)
	return w


const LOOKS_M := [
	{"sex": 1.0, "face": "m_face_2", "melanin": 0.62, "undertone": "warm", "stubble": 0.0,
		"hair": {"style": "hair_crown_lock_braided", "color": "black"}},
	{"sex": 1.0, "face": "m_face_1", "melanin": 0.30, "undertone": "neutral",
		"hair": {"style": "hair_loose_tied", "color": "dark_brown"}},
	{"sex": 1.0, "face": "m_face_3", "melanin": 0.85, "undertone": "neutral",
		"hair": {"style": "hair_natural_short", "color": "black"}},
]
const LOOKS_F := [
	{"sex": 0.0, "face": "f_face_2", "melanin": 0.58, "undertone": "warm",
		"hair": {"style": "hair_club_wrapped_f", "color": "blue_black"}},
	{"sex": 0.0, "face": "f_face_1", "melanin": 0.35, "undertone": "olive",
		"hair": {"style": "hair_braid_f", "color": "chestnut"}},
	{"sex": 0.0, "face": "f_face_3", "melanin": 0.80, "undertone": "neutral",
		"hair": {"style": "hair_braid_f", "color": "black"}},
]


func _presets() -> void:
	var presets: Array = cat.get("presets", [])
	var n := 0
	for p: Dictionary in presets:
		var wear := _wear_of(p)
		var lf: Dictionary = LOOKS_F[n % 3].duplicate(true)
		var lm: Dictionary = LOOKS_M[n % 3].duplicate(true)
		for w: Dictionary in wear:
			if String(w.id) == "ew_head_wrap":
				lm.hair = {"style": "hair_loose_tied", "color": "black"}
		var xs := [-1.35, -0.45, 0.45, 1.35]
		_character(Vector3(xs[0], 0, 0), 25.0, lf, wear)
		_character(Vector3(xs[1], 0, 0), 205.0, lf, wear)
		_character(Vector3(xs[2], 0, 0), 25.0, lm, wear)
		_character(Vector3(xs[3], 0, 0), 205.0, lm, wear)
		await _frames(2)
		_look_at(Vector3(0, 0.88, 0), Vector3(0, 0.35, 8.8), 26.0)
		await _shot("preset_%s" % p.id)
		await _clear()
		n += 1


func _poses() -> void:
	var clips := [["run", "actor_b-p-run-fw", 0.3], ["crouch", "actor_b-p-crouch-walk-fw", 0.5],
			["musket", "actor_b-p-rifle-idle-aim", 0.0], ["bow", "actor_b-p-bow-aim-idle", 0.0],
			["ledge", "actor_b-p-idle-jump-up-2m^ledge-chest-end", 0.75]]
	var presets: Array = cat.get("presets", [])
	for pid in ["ew_formal_m", "ew_everyday_f", "ew_everyday_winter_m"]:
		var p: Dictionary = {}
		for q: Dictionary in presets:
			if q.id == pid:
				p = q
		if p.is_empty():
			continue
		for fit in [0, 1]:
			var look: Dictionary = (LOOKS_F[0] if fit == 0 else LOOKS_M[0]).duplicate(true)
			for j in clips.size():
				var c := _character(Vector3(j * 1.15 - 2.3, 0, 0), 35.0, look, _wear_of(p))
				_pose(c[2], clips[j][1], clips[j][2])
			await _frames(2)
			_look_at(Vector3(0, 0.75, 0), Vector3(0, 0.5, 8.4), 31.0)
			await _shot("poses_%s_%s" % [pid, ["f", "m"][fit]])
			_look_at(Vector3(0, 0.75, 0), Vector3(-2.6, 1.0, -7.8), 31.0)
			await _shot("poses_%s_%s_back" % [pid, ["f", "m"][fit]])
			await _clear()


func _items() -> void:
	var items: Dictionary = cat.get("items", {})
	var ids := items.keys()
	ids.sort()
	var per := 4
	var k := 0
	while k < ids.size():
		var group := ids.slice(k, k + per)
		for j in group.size():
			var e: Dictionary = items[group[j]]
			var wear := [{"id": group[j]}]
			if e.get("requires", []).size() > 0:
				wear.push_front({"id": "ew_shirt_linen"})
			_character(Vector3(j * 1.2 - 2.3, 0, 0), 25.0, LOOKS_F[1], wear)
			_character(Vector3(j * 1.2 - 1.75, 0, -0.2), 25.0, LOOKS_M[1], wear)
		await _frames(2)
		_look_at(Vector3(-0.2, 0.85, 0), Vector3(0, 0.35, 9.4), 27.0)
		await _shot("items_%02d" % (k / per))
		await _clear()
		k += per


func _close() -> void:
	var presets: Array = cat.get("presets", [])
	var formal_m: Dictionary = {}
	var formal_f: Dictionary = {}
	for q: Dictionary in presets:
		if q.id == "ew_formal_m":
			formal_m = q
		if q.id == "ew_formal_f":
			formal_f = q
	var cf := _character(Vector3(-0.35, 0, 0), 20.0, LOOKS_F[0], _wear_of(formal_f))
	var cm := _character(Vector3(0.35, 0, 0), -20.0, LOOKS_M[0], _wear_of(formal_m))
	await _frames(2)
	_look_at(Vector3(0, 0.22, 0.1), Vector3(0.0, 0.25, 2.6), 24.0)
	await _shot("close_feet_legs")
	_look_at(Vector3(0, 1.30, 0.05), Vector3(0.0, 0.05, 2.5), 22.0)
	await _shot("close_torso")
	_look_at(Vector3(0, 1.47, 0.0), Vector3(0.0, 0.05, 1.5), 22.0)
	await _shot("close_heads")
	_look_at(Vector3(0, 0.80, 0.0), Vector3(0.0, 0.3, 3.4), 26.0)
	await _shot("close_hips")
	(cf[0] as Node3D).rotation_degrees.y = 200.0
	(cm[0] as Node3D).rotation_degrees.y = 160.0
	await _frames(2)
	_look_at(Vector3(0, 1.0, 0.0), Vector3(0.0, 0.3, 4.4), 26.0)
	await _shot("close_backs")
	await _clear()
