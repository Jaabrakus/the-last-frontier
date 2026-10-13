class_name CascadeMaterials
extends RefCounted
## Builds Godot materials for Spellbreak particle emitters from materials.json
## (Spellbreak, Proletariat: ported from the Spellbreak FX browser's fx_materials.gd, artifacts/spellbreak_fx; the
## game reads the imported subset in res://assets/fx/spellbreak/, see SOURCE.md there; one shared library: shared())
## (tools/reference_animation/fx_materials.py): a hand-written family shader when the
## root material has one, otherwise the generic uber shader with features switched on
## from the material's real parameter names. All parameter VALUES come from the source;
## the shader math is authored (the cooked graphs were stripped).

const ROOT := "res://assets/fx/spellbreak/"
const ASSETS := ROOT + "assets/"
const SHADERS := "res://shaders/cascade/"
const FAMILIES_DIR := "res://data/fx/cascade_families/"

## root material -> family: shader + uniform sources.
## Sources: ["s", name, scale] scalar, ["v", name] vector rgb, ["v2", nameU, nameV] two scalars,
## ["t", [names...]] texture.
const FAMILIES := {
	"/Game/VFX/Character/Trails/M_f_FireBeam": {"shader": "fireball_head", "u": {
		"rgb_tex": ["t", ["RGB Texture", "MaskTextureUses Packed AlphaChannel"]], "noise_tex": ["t", ["Noise Texture 1", "Noise Texture 2"]],
		"core_color": ["v", "Core Color 1"], "edge_color": ["v", "Edge Color 1"], "emissive_intensity": ["s", "Emissive Intensity", 1.0],
		"fps": ["s", "FPS", 1.0], "speed": ["s", "speed", 1.0], "panner": ["v2", "U Panner", "V Panner"],
		"texture_rotation": ["s", "TextureRotation", 1.0], "distortion_factor": ["s", "Distortion factor", 1.0],
		"distortion_scale": ["s", "Distortion Scale", 1.0], "fresnel_mask": ["s", "Fresnel Mask", 1.0],
		"edge_mask_min": ["s", "Edge Mask Min", 1.0], "edge_mask_max": ["s", "Edge Mask Max", 1.0],
		"fade_distance": ["s", "Fade Distance", 0.01], "near_fade_offset": ["s", "Near Camera Fade Offset", 0.01],
		"near_fade_length": ["s", "Near Camera Fade Length", 0.01]}},
	"/Game/VFX/Character/PowerSurge/PowerSurge_Glow01_FxM": {"shader": "fireball_core_flames", "u": {
		"mask_tex": ["t", ["MaskTexture"]], "distortion_normal": ["t", ["DistortionNormalMap"]],
		"distortion_strength": ["s", "Distortion Strength", 1.0], "normal_pan": ["v2", "NormalMapPanU", "NormalMapPanV"],
		"normal_scale": ["v2", "NormalMapScaleU", "NormalMapScaleV"], "fps": ["s", "FPS", 1.0],
		"edge_softness": ["s", "EdgeSoftness", 1.0], "mask_contrast": ["s", "MaskContrast", 1.0],
		"camera_fade_offset": ["s", "CameraFadeOffset", 0.01], "camera_fade_length": ["s", "CameraFadeLength", 0.01],
		"pixel_depth_fade": ["s", "PixelDepthFade", 0.01]}},
	"/Game/VFX/Character/Trails/Fire_MaskedEmissive_RT_FxM": {"shader": "fireball_trail", "u": {
		"rgb_tex": ["t", ["RGB Texture", "MaskTextureUses Packed AlphaChannel"]], "erosion_tex": ["t", ["Erosion Texture"]],
		"noise_tex": ["t", ["Noise Texture"]], "core_color": ["v", "Core Color"], "edge_color": ["v", "Edge Color"],
		"fps": ["s", "FPS", 1.0], "distortion_scale": ["v2", "Distortion Scale U", "Distortion Scale V"],
		"noise1_pan": ["v2", "Noise1PanX", "Noise1PanY"], "noise2_pan": ["v2", "Noise2PanX", "Noise2PanY"],
		"panner": ["v2", "U Panner", "V Panner"], "speed": ["s", "speed", 1.0], "texture_rotation": ["s", "TextureRotation", 1.0],
		"distortion_factor": ["s", "Distortion factor", 1.0], "edge_softness": ["s", "Edge Softness", 1.0],
		"premultiply": ["s", "Premultiply final channel", 1.0], "erosion": ["s", "Erosion", 1.0],
		"camera_fade_start": ["s", "Camera Fade Start", 0.01], "camera_fade_length": ["s", "Camera Fade Length", 0.01],
		"depth_fade_m": ["s", "Depth Fade", 0.01]}},
	"/Game/VFX/Materials/M_f_ParticleBasicErodeDistort": {"shader": "fireball_wisp", "u": {
		"mask_tex": ["t", ["Opacity mask"]], "normal_tex": ["t", ["Normal"]], "brightness": ["s", "Brightness", 1.0],
		"opacity_control": ["s", "Opacity Control", 1.0], "distortion_strength": ["s", "Distortion Strength", 1.0],
		"mask_fps": ["s", "Mask FPS", 1.0], "normal_pan_speed": ["s", "NormalMapPannerSpeed", 1.0],
		"depth_fade_m": ["s", "DepthFade Distance", 0.01], "fade_offset": ["s", "Fade Distance Offset", 0.01],
		"fade_length": ["s", "Fade Length", 0.01]}},
	"/Game/VFX/Materials/M_SimpleGlow": {"shader": "impact_glow", "u": {
		"camera_fade_offset": ["s", "CameraFadeOffset", 0.01], "camera_fade_length": ["s", "CameraFadeLength", 0.01]}},
	"/Game/VFX/Materials/M_SimpleFresnelBall": {"shader": "impact_fresnel_ball", "u": {
		"fresnel_edge": ["s", "Fresnel Edge", 1.0], "depth_opacity": ["s", "Depth Opacity", 1.0], "fade_distance": ["s", "Fade Distance", 0.01]}},
	"/Game/VFX/Materials/M_FlowMapTest": {"shader": "impact_smoke", "u": {
		"opacity_tex": ["t", ["Opacity"]], "erosion_tex": ["t", ["Erosion"]], "flow_tex": ["t", ["Flow A"]],
		"speed": ["s", "Speed", 1.0], "offset_micro": ["s", "offset micro", 1.0], "erosion_test": ["s", "Erosion Test", 1.0],
		"opacity_premultiply": ["s", "Opacity PreMultiply", 1.0], "depth_opacity": ["s", "Depth Opacity", 1.0],
		"fade_distance": ["s", "Fade Distance", 0.01], "fade_offset": ["s", "Fade Distance Offset", 0.01],
		"fade_length": ["s", "Fade Length", 0.01]}},
	"/Game/VFX/Character/Skills/M_SphereErosion_SoftEdge": {"shader": "impact_sphere_shock", "u": {
		"edge_softness": ["s", "Edge Softness", 1.0], "soft_edge": ["s", "Soft Edge", 1.0], "erosion_scale": ["s", "Erosion Scale", 1.0],
		"camera_fade_offset": ["s", "Camera Fade Offset", 0.01], "camera_fade_length": ["s", "Camera Fade Length", 0.01],
		"depth_fade_m": ["s", "Depth Fade Distance", 0.01]}},
}

# Fixed textures inside graphs that the families need (the cooked graph keeps the reference).
const FAMILY_FIXED := {
	"impact_smoke": {"flow_tex": "T_f_SphereNormalFlow"},
	"impact_sphere_shock": {"noise_tex": "T_f_DistortionNoise_Large"},
}

var data: Dictionary = {}
var _tex_cache: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _shader_cache: Dictionary = {}
var _uber_src := ""
var outer_band := 0.25
var stats: Dictionary = {"family": 0, "uber": 0, "missing": 0}
var families: Dictionary = {}     # root material path -> family record
## (Game, tests) When set (a folder mirroring ASSETS, e.g. the browser's res://artifacts/spellbreak_fx/assets/), texture()
## answers from that folder's files with placeholders tagged with their package: the materials built show which
## textures the browser would draw with, for tests/fx/test_cascade_runtime.gd to compare with the import.
var probe_root := ""

static var _shared: CascadeMaterials


## (Game) The one library every effect shares (its texture, mesh and shader caches).
static func shared() -> CascadeMaterials:
	if _shared == null:
		_shared = CascadeMaterials.new()
	return _shared


func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "materials.json"))
	data = parsed if parsed is Dictionary else {"materials": {}, "meshes": {}}
	_uber_src = FileAccess.get_file_as_string(SHADERS + "uber.gdshader.txt")
	reload_families()


## Built-in fireball families + every res://data/fx/cascade_families/*.json:
## {"roots": [root paths], "shader": "fam_x", "template": false, "u": {uniform: source}, "notes": "..."}
## Source kinds: ["s", name, scale, default?] scalar | ["s_any", [names], scale, default?]
## ["v", name] vec3 | ["v4", name] Color | ["v2", nameU, nameV] | ["vxy", vectorName] Vector2 from r,g
## ["t", [param names]] texture | ["t_fixed", [file names]] graph texture | ["has", [param names]] bool
## ["sw", name, default] static switch | ["dyn", [substrings]] dynamic-param index or -1
## ["c", value] constant | ["spec", "is_mesh"|"is_sprite"|"is_ribbon"] bool
## "template": true -> shader file has /*RENDER_MODE*/ and /*ALPHA_OUT*/ filled per blend mode.
func reload_families() -> void:
	families.clear()
	for root: String in FAMILIES:
		families[root] = FAMILIES[root]
	var d := DirAccess.open(FAMILIES_DIR)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var j = JSON.parse_string(FileAccess.get_file_as_string(FAMILIES_DIR + f))
		if not (j is Dictionary):
			push_error("bad family file " + f)
			continue
		j["file"] = f.get_basename()
		for r in j.get("roots", []):
			families[String(r)] = j


static func res_path(pkg: String, ext: String) -> String:
	var rel := pkg
	if rel.begins_with("/Game/"):
		rel = rel.substr(6)
	elif rel.begins_with("/Engine/"):
		rel = rel.substr(8)
	return ASSETS + rel + ext


func texture(pkg) -> Texture2D:
	if pkg == null or String(pkg) == "":
		return null
	var key := String(pkg)
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path := res_path(key, ".png")
	var t: Texture2D = null
	if probe_root != "":
		if FileAccess.file_exists(path.replace(ASSETS, probe_root)):
			t = PlaceholderTexture2D.new()
	elif ResourceLoader.exists(path):
		t = load(path)
	_tex_cache[key] = t
	if t:
		t.set_meta(&"cascade_pkg", key)
	return t


func mesh(name: String) -> Mesh:
	if _mesh_cache.has(name):
		return _mesh_cache[name]
	var rec: Dictionary = data.meshes.get(name, {})
	var m: Mesh = null
	if rec.has("package"):
		var path := res_path(rec.package, ".gltf")
		if ResourceLoader.exists(path):
			var root := (load(path) as PackedScene).instantiate()
			for n in root.find_children("*", "MeshInstance3D", true, false):
				m = (n as MeshInstance3D).mesh
				break
			root.free()
	_mesh_cache[name] = m
	return m


func material_record(spec: Dictionary) -> Dictionary:
	var name := String(spec.get("material", ""))
	if spec.get("type", "") == "mesh" and not spec.get("override_material", true):
		var mr: Dictionary = data.meshes.get(String(spec.get("mesh", "")), {})
		for p in mr.get("materials", []):
			if p:
				name = String(p).get_file()
				break
	for m in spec.get("modules", []):
		if m["class"] == "MeshMaterial" and m.enabled and m.get("MeshMaterials") is Array and not m.MeshMaterials.is_empty():
			var first = m.MeshMaterials[0]
			if first is Dictionary and first.has("import"):
				name = String(first["import"])
	return data.materials.get(name, {})


func material_for_emitter(spec: Dictionary) -> ShaderMaterial:
	var rec := material_record(spec)
	var m: ShaderMaterial
	var fam: Dictionary = families.get(String(rec.get("root", "")), {})
	if rec.is_empty():
		stats.missing += 1
		m = _uber({}, spec)
	elif not fam.is_empty():
		stats.family += 1
		m = _family(fam, rec, spec)
	else:
		stats.uber += 1
		m = _uber(rec, spec)
	m.set_shader_parameter("is_trail", spec.type in ["ribbon", "beam", "anim_trail"])
	m.set_shader_parameter("grid", Vector2(float(spec.subuv[0]), float(spec.subuv[1])))
	m.set_shader_parameter("subuv_blend", String(spec.subuv_method).ends_with("_Blend"))
	for mod in spec.modules:
		if mod["class"] == "PivotOffset" and mod.enabled:
			var po: Array = mod.get("PivotOffset", [0.0, 0.0])
			m.set_shader_parameter("pivot", Vector2(float(po[0]), -float(po[1])))
	m.set_meta("family", fam.get("file", fam.get("shader", "uber")) if not fam.is_empty() else "uber")
	m.set_meta("source_material", rec.get("package", "(none)"))
	m.set_meta("root_material", rec.get("root", "(none)"))
	return m


func _scalar(rec: Dictionary, name: String, fallback = null):
	var s: Dictionary = rec.get("scalars", {})
	return float(s[name]) if s.has(name) and s[name] != null else fallback


func _vec(rec: Dictionary, name: String):
	var v = rec.get("vectors", {}).get(name)
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return null


func _tex_named(rec: Dictionary, names: Array) -> Texture2D:
	var t: Dictionary = rec.get("textures", {})
	for n in names:
		if t.has(n) and t[n]:
			var tx := texture(t[n])
			if tx:
				return tx
	return null


func _family(fam: Dictionary, rec: Dictionary, spec: Dictionary = {}) -> ShaderMaterial:
	var key: String = fam.shader
	var m := ShaderMaterial.new()
	if fam.get("template", false):
		m.shader = _uber_shader(rec, SHADERS + key + ".gdshader.txt")
	else:
		if not _shader_cache.has(key):
			_shader_cache[key] = load(SHADERS + key + ".gdshader")
		m.shader = _shader_cache[key]
	for u: String in fam.u:
		var src: Array = fam.u[u]
		var kind := String(src[0])
		match kind:
			"s", "s_any":
				var names: Array = src[1] if src[1] is Array else [src[1]]
				var v = _first_scalar(rec, names)
				if v == null and src.size() > 3:
					v = src[3]
				if v != null:
					m.set_shader_parameter(u, float(v) * (float(src[2]) if src.size() > 2 else 1.0))
			"v":
				var v = _vec(rec, src[1])
				if v != null:
					m.set_shader_parameter(u, v)
			"v4":
				var v = rec.get("vectors", {}).get(src[1])
				if v is Array and v.size() >= 4:
					m.set_shader_parameter(u, Color(float(v[0]), float(v[1]), float(v[2]), float(v[3])))
			"v2":
				var a = _scalar(rec, src[1])
				var b = _scalar(rec, src[2])
				if a != null or b != null:
					m.set_shader_parameter(u, Vector2(a if a != null else 0.0, b if b != null else 0.0))
			"vxy":
				var v = rec.get("vectors", {}).get(src[1])
				if v is Array and v.size() >= 2:
					m.set_shader_parameter(u, Vector2(float(v[0]), float(v[1])))
			"t":
				var tx := _tex_named(rec, src[1])
				if tx:
					m.set_shader_parameter(u, tx)
			"t_fixed":
				for p in rec.get("fixed_textures", []):
					if String(p).get_file() in src[1]:
						var tx := texture(p)
						if tx:
							m.set_shader_parameter(u, tx)
							break
			"has":
				m.set_shader_parameter(u, _tex_named(rec, src[1]) != null)
			"sw":
				m.set_shader_parameter(u, bool(rec.get("switches", {}).get(src[1], src[2] if src.size() > 2 else false)))
			"dyn":
				var idx := -1
				for mod in spec.get("modules", []):
					if String(mod["class"]).begins_with("ParameterDynamic") and mod.enabled:
						var dp: Array = mod.get("DynamicParams", [])
						for i in mini(dp.size(), 4):
							var n := String(dp[i].get("name", "")).to_lower()
							for sub in src[1]:
								if idx < 0 and n.contains(String(sub).to_lower()):
									idx = i
				m.set_shader_parameter(u, idx)
			"c":
				m.set_shader_parameter(u, src[1])
			"spec":
				var t := String(spec.get("type", ""))
				var val := false
				match String(src[1]):
					"is_mesh": val = t == "mesh"
					"is_sprite": val = t == "sprite"
					"is_ribbon": val = t in ["ribbon", "beam", "anim_trail"]
				m.set_shader_parameter(u, val)
	for u: String in FAMILY_FIXED.get(key, {}):
		for p in rec.get("fixed_textures", []):
			if String(p).get_file() == FAMILY_FIXED[key][u]:
				m.set_shader_parameter(u, texture(p))
	if key in ["fireball_head", "fireball_trail"]:
		m.set_shader_parameter("outer_band", outer_band)
	return m


func _uber_shader(rec: Dictionary, template_path := "") -> Shader:
	var blend := String(rec.get("blend_mode", "BLEND_Translucent"))
	var shading := String(rec.get("shading_model", "MSM_Unlit"))
	var two_sided := bool(rec.get("two_sided", true))
	var key := template_path + "|" + blend + "|" + shading + "|" + str(two_sided)
	if _shader_cache.has(key):
		return _shader_cache[key]
	var modes: Array[String] = ["depth_draw_never", "shadows_disabled"]
	var alpha_out := "ALPHA = clamp(op, 0.0, 1.0);"
	match blend:
		"BLEND_Additive":
			modes.append("blend_add")
		"BLEND_AlphaComposite":
			modes.append("blend_premul_alpha")
		"BLEND_Masked":
			modes = ["depth_draw_opaque", "blend_mix"]
			alpha_out = "ALPHA = clamp(op, 0.0, 1.0);\n\tALPHA_SCISSOR_THRESHOLD = alpha_clip;"
		"BLEND_Opaque":
			modes = ["depth_draw_opaque", "blend_mix"]
			alpha_out = "if (op < 0.01) { discard; }"
		_:
			modes.append("blend_mix")
	if shading == "MSM_Unlit":
		modes.append("unshaded")
	modes.append("cull_disabled" if two_sided else "cull_back")
	modes.append("fog_disabled")
	var src_code := _uber_src if template_path == "" else FileAccess.get_file_as_string(template_path)
	var code := src_code.replace("/*RENDER_MODE*/", ", ".join(modes)).replace("/*ALPHA_OUT*/", alpha_out)
	var sh := Shader.new()
	sh.code = code
	_shader_cache[key] = sh
	return sh


var _alpha_cache: Dictionary = {}


func _has_alpha(t: Texture2D) -> bool:
	if _alpha_cache.has(t):
		return _alpha_cache[t]
	# (Game) the importer's table: what the browser read from the lossless image (the game's textures are VRAM
	# compressed, and a compressed image cannot answer)
	var table: Dictionary = data.get("texture_alpha", {})
	var pkg := String(t.get_meta(&"cascade_pkg", ""))
	if table.has(pkg):
		_alpha_cache[t] = bool(table[pkg])
		return _alpha_cache[t]
	var img := t.get_image()
	var a := img != null and img.detect_alpha() != Image.ALPHA_NONE
	_alpha_cache[t] = a
	return a


## Materials with no texture parameters: use the graph's fixed textures, else a procedural
## shape (most such materials build radial / ring / diamond gradients from math nodes).
func _no_param_textures(m: ShaderMaterial, rec: Dictionary, spec: Dictionary) -> void:
	var fixed: Array = rec.get("fixed_textures", [])
	var colour: Texture2D = null
	var mask: Texture2D = null
	for p in fixed:
		var n := String(p).get_file().to_lower()
		if n.contains("normal") or n.contains("raom") or n.ends_with("_n"):
			continue
		var tx := texture(p)
		if tx == null:
			continue
		if colour == null and (n.contains("albedo") or n.contains("diffuse") or n.contains("color") or n.contains("_d")):
			colour = tx
		elif mask == null and not n.contains("noise"):
			mask = tx
	if colour:
		m.set_shader_parameter("main_mode", 1)
		m.set_shader_parameter("main_tex", colour)
		m.set_shader_parameter("shape_from_rgb", not _has_alpha(colour) and spec.get("type", "") != "mesh")
	elif mask:
		m.set_shader_parameter("main_mode", 2)
		m.set_shader_parameter("main_tex", mask)
	elif spec.get("type", "") == "mesh":
		m.set_shader_parameter("main_mode", 0)
	else:
		var funcs: Array = rec.get("functions", [])
		var name := String(rec.get("package", "")).get_file().to_lower()
		var shape := 0
		if name.contains("ring"):
			shape = 1
		elif "DiamondGradient" in funcs:
			shape = 2
		elif funcs == ["LinearGradient"]:
			shape = 3
		m.set_shader_parameter("main_mode", 5)
		m.set_shader_parameter("proc_shape", shape)
	m.set_meta("shape_source", "fixed" if (colour or mask) else "procedural")


func _first_scalar(rec: Dictionary, names: Array, fallback = null):
	for n in names:
		var v = _scalar(rec, n)
		if v != null:
			return v
	return fallback


func _first_vec(rec: Dictionary, names: Array):
	for n in names:
		var v = _vec(rec, n)
		if v != null:
			return v
	return null


func _uber(rec: Dictionary, spec: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _uber_shader(rec)
	var sw: Dictionary = rec.get("switches", {})
	var funcs: Array = rec.get("functions", [])
	m.set_shader_parameter("outer_band", outer_band)
	# main texture role
	var packed := _tex_named(rec, ["MaskTextureUses Packed AlphaChannel", "RGB Texture"])
	if packed:
		m.set_shader_parameter("main_mode", 3)
		m.set_shader_parameter("mask_tex", packed)
	else:
		var colour := _tex_named(rec, ["Albedo", "DIffuseTexture", "Base Texture", "BaseTex", "Color Texture", "Main_Texture", "Texture", "Texture 1", "Texture Parameter"])
		var mask := _tex_named(rec, ["MaskTexture", "Opacity mask", "Opacity Mask", "Masks", "Mask Tex", "Mask Texture", "Mask_Texture", "Particle Mask",
			"SubUV texture", "SuBUVTexture", "Lightning Bolt", "Main Shape", "Opacity", "Base Alpha", "BubblesTexture"])
		if colour:
			m.set_shader_parameter("main_mode", 1)
			m.set_shader_parameter("main_tex", colour)
			if mask:
				m.set_shader_parameter("mask_tex", mask)
				m.set_shader_parameter("has_mask", true)
		elif mask:
			m.set_shader_parameter("main_mode", 2)
			m.set_shader_parameter("main_tex", mask)
		else:
			_no_param_textures(m, rec, spec)
		if colour and spec.get("type", "") != "mesh" and not _has_alpha(colour):
			m.set_shader_parameter("shape_from_rgb", true)
	var ero := _tex_named(rec, ["Erosion Texture", "AlphaErosion", "Erosion Mask", "ErosionTexture", "Erosion", "Gradient Erode", "Detail Erosion"])
	if ero:
		m.set_shader_parameter("erosion_tex", ero)
		m.set_shader_parameter("has_erosion_tex", true)
	var normal_noise := _tex_named(rec, ["DistortionNormalMap", "Normal", "NormalMap", "2D_NormalMap", "Normal Map"])
	var noise := _tex_named(rec, ["NoiseTexture", "Noise Texture 1", "Noise Texture", "Noise 1", "Distort_Texture", "DisplacementNoiseTexture"])
	if noise or normal_noise:
		m.set_shader_parameter("noise_tex", noise if noise else normal_noise)
		m.set_shader_parameter("noise_is_normal", noise == null)
		m.set_shader_parameter("has_noise", true)
	var em_tex := _tex_named(rec, ["EmissiveTexture", "Emissive Texture"])
	if em_tex:
		m.set_shader_parameter("emissive_tex", em_tex)
		m.set_shader_parameter("has_emissive_tex", true)
	var core = _first_vec(rec, ["Core Color 1", "Core Color", "InnerColor", "color_core", "Center Color", "Center Glow", "Color", "EmissiveColor",
		"Emissive Color", "EmissiveTint", "Tint", "Color 1", "Base Color", "Albedo Tint", "Light Color", "HighColor"])
	var edge = _first_vec(rec, ["Edge Color 1", "Edge Color", "OuterColor", "color_eddge", "Color Edge", "Dark Color", "second color"])
	if core != null:
		m.set_shader_parameter("core_color", core)
	if edge != null:
		m.set_shader_parameter("edge_color", edge)
	elif core != null:
		m.set_shader_parameter("edge_color", core)
	m.set_shader_parameter("emissive", _first_scalar(rec, ["Emissive Intensity", "Brightness", "EmissiveIntensity", "Emissive", "Glow", "EmissiveMultiplier", "Emissive Power"], 1.0))
	m.set_shader_parameter("fps", _first_scalar(rec, ["FPS", "Mask FPS"], 0.0))
	var speed = _first_scalar(rec, ["speed", "Speed"], 1.0)
	var up = _first_scalar(rec, ["U Panner", "MaskPanU", "PanU", "Pan U"])
	var vp = _first_scalar(rec, ["V Panner", "MaskPanV", "PanV", "Pan V"])
	if up != null or vp != null:
		m.set_shader_parameter("main_pan", Vector2(up if up != null else 0.0, vp if vp != null else 0.0) * speed)
	var tu = _first_scalar(rec, ["MaskTextureTileU", "Texture Scale"])
	var tv = _first_scalar(rec, ["MaskTextureTileV", "Texture Scale"])
	if tu != null or tv != null:
		m.set_shader_parameter("main_tile", Vector2(tu if tu != null else 1.0, tv if tv != null else 1.0))
	if sw.get("Has TextureRotation", false) or rec.get("scalars", {}).has("TextureRotation"):
		m.set_shader_parameter("main_rotation", _first_scalar(rec, ["TextureRotation"], 0.0))
	if sw.get("Has Rotator Speed", false) or sw.get("Has MaskRotatorSpeed", false):
		m.set_shader_parameter("rotator_speed", _first_scalar(rec, ["MaskRotatorSpeed", "Rotator Speed"], 0.0))
	var npu = _first_scalar(rec, ["NoisePanSpeedU", "NoisePanU", "NormalMapPanU", "Noise1PanX"])
	var npv = _first_scalar(rec, ["NoisePanSpeedV", "NoisePanV", "NormalMapPanV", "Noise1PanY"])
	if npu != null or npv != null:
		m.set_shader_parameter("noise_pan", Vector2(npu if npu != null else 0.0, npv if npv != null else 0.0))
	var ntu = _first_scalar(rec, ["NoiseTextureScaleU", "NoiseTextureTileU", "NormalMapScaleU"])
	var ntv = _first_scalar(rec, ["NoiseTextureScaleV", "NoiseTextureTileV", "NormalMapScaleV"])
	if ntu != null or ntv != null:
		m.set_shader_parameter("noise_tile", Vector2(ntu if ntu != null else 1.0, ntv if ntv != null else 1.0))
	var dist = _first_scalar(rec, ["Distortion Strength", "DistortionStrength"])
	if dist == null:
		var df = _first_scalar(rec, ["Distortion factor"])
		dist = df * 0.1 if df != null else 0.0
	m.set_shader_parameter("distortion", dist)
	var erosion_on: bool = "MF_TransluscentToonErosion" in funcs or "Luos_alphaErosion" in funcs or "MF_BR_Dissolver_Partikel" in funcs \
		or sw.get("Alpha Erosion", false) or sw.get("Toon Erosion", false) or sw.get("Has Alpha Erosion", false)
	m.set_shader_parameter("erosion", erosion_on)
	m.set_shader_parameter("edge_softness", _first_scalar(rec, ["Edge Softness", "EdgeSoftness"], 0.1))
	m.set_shader_parameter("mask_contrast", _first_scalar(rec, ["MaskContrast"], 0.0))
	m.set_shader_parameter("invert_erosion", sw.get("Invert Erocion Pattern", false))
	if spec.get("type", "") == "mesh" and (sw.get("Use Fresnel", false) or sw.get("Has Rim Light?", false)):
		m.set_shader_parameter("fresnel_mode", 1)
		m.set_shader_parameter("fresnel_power", _first_scalar(rec, ["Fresnel Exponent", "FresnelExponent", "Fresnel Power", "Fresnel Edge", "Fresnel"], 2.0))
	var cfo = _first_scalar(rec, ["CameraFadeOffset", "Camera Fade Start", "Camera Fade Offset", "Fade Distance Offset"])
	var cfl = _first_scalar(rec, ["CameraFadeLength", "Camera Fade Length", "Fade Length"])
	if cfl != null:
		m.set_shader_parameter("camera_fade_offset", (cfo if cfo != null else 0.0) * 0.01)
		m.set_shader_parameter("camera_fade_length", cfl * 0.01)
	var df_ = _first_scalar(rec, ["PixelDepthFade", "Depth Fade", "DepthFade Distance", "Fade Distance", "Depth Fade Distance"])
	if df_ != null:
		m.set_shader_parameter("depth_fade_m", df_ * 0.01)
	m.set_shader_parameter("alpha_clip", 0.333)
	# dynamic parameter names from the emitter
	for mod in spec.get("modules", []):
		if String(mod["class"]).begins_with("ParameterDynamic") and mod.enabled:
			var dp: Array = mod.get("DynamicParams", [])
			for i in mini(dp.size(), 4):
				var n := String(dp[i].get("name", "")).to_lower()
				if n.contains("emiss") or n.contains("bright") or n.contains("glow") or n.contains("intensity"):
					m.set_shader_parameter("dyn_emissive", i)
				elif n.contains("opac") or n.contains("alpha") or n.contains("fade"):
					m.set_shader_parameter("dyn_opacity", i)
				elif n.contains("eros") or n.contains("erod") or n.contains("dissol"):
					m.set_shader_parameter("dyn_erosion", i)
				elif n.contains("distort"):
					m.set_shader_parameter("dyn_distortion", i)
	return m
