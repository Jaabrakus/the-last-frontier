class_name ChildSkin
extends RefCounted
## A child's skin: the game's skin (skin.gdshader, dressed by BodyMaterials.apply_look) made smooth and soft on the child's OWN
## material (apply_look makes a new one for each body; the shared adult materials are never touched), by the stage's smoothness
## (growth.json stage skin_smooth: a newborn 1, toddler 0.8, child 0.55, teen 0.25, adult 0). At 1 it is baby_body.json "skin": the
## photographed pores, lines and weathering almost gone, matte (high roughness, low specular, no oil), a gentle warm glow of light
## through it (ears, nose, fingers) and the soft grazing sheen of fine hair (`fuzz`: a copy of the skin shader with RIM, made once).
## The blush is the look's own flush (cheeks, nose tip, lips, knuckles) with a little more blood.
##   ChildSkin.apply(body, 0.8)

const FUZZ_CODE := "\tRIM = child_fuzz;\n\tRIM_TINT = child_fuzz_tint;\n"
const FUZZ_UNIFORMS := "uniform float child_fuzz : hint_range(0.0, 1.0) = 0.0;\nuniform float child_fuzz_tint : hint_range(0.0, 1.0) = 0.3;\nuniform int child_adult_pos = 0;\nuniform float child_flat = 0.0;\nuniform float child_lip = 0.0;\nuniform float child_soft_ao = 0.0;\n"
## The skin shader's neck and seam gradients are keyed to the adult's heights: on a child's baked mesh (ChildProportion writes each
## vertex's adult bind position into CUSTOM1) they read that instead of the child's own.
const ADULT_POS := [["v_h = VERTEX.y;", "vec3 cap = child_adult_pos == 1 ? CUSTOM1.xyz : VERTEX;\n\tv_h = cap.y;"],
		["float dsig = VERTEX.y - (1.367 - 0.35 * VERTEX.z);", "float dsig = cap.y - (1.367 - 0.35 * cap.z);"],
		["length(vec2(VERTEX.x, VERTEX.z - 0.009))", "length(vec2(cap.x, cap.z - 0.009))"],
		["areola = d.a;", "areola = d.a * (1.0 - child_flat);"],
		# a young mouth: the lips pinker and lighter, the baked seams (the mouth's line, the lids' pockets, the nostrils) softer
		["albedo = mix(albedo, lip, mucosa);", "lip = mix(lip, lip * vec3(1.1, 0.9, 0.95) + vec3(0.045, 0.012, 0.02), child_lip);\n\t\talbedo = mix(albedo, lip, mucosa);"],
		["AO = mix(0.35, 1.0, cavity);", "AO = mix(mix(0.35, 1.0, child_soft_ao), 1.0, cavity);"]]
const NUMS := ["head_detail_strength", "body_detail_strength", "detail_strength", "weathering", "roughness_base", "skin_specular",
		"oil_sheen", "sss_strength", "head_sss", "albedo_scale"]
## skin.gdshader's own defaults (when the material does not set one).
const ADULT := {"head_detail_strength": 1.8, "body_detail_strength": 1.2, "detail_strength": 1.0, "weathering": 0.3,
		"roughness_base": 0.58, "skin_specular": 0.24, "oil_sheen": 0.05, "sss_strength": 0.45, "head_sss": 1.8, "albedo_scale": 0.9}

static var _fuzz_shader: Shader


static func cfg() -> Dictionary:
	return (ChildProportion.cfg().get("skin", {}) as Dictionary)


## The skin materials of `body`'s meshes (each once).
static func materials(body: CharacterBodyMesh) -> Array:
	var out := []
	if body == null:
		return out
	for mi: MeshInstance3D in body.meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m != null and m.shader != null and (m.shader == BodyMaterials.SKIN_SHADER or m.shader == fuzz_shader()) and not m in out:
				out.append(m)
	return out


static func apply(body: CharacterBodyMesh, smooth: float, flat := true) -> void:
	# (the classic materials while they are changed: a soft look's copies are made again from them after; SoftLook)
	var soft := SoftLook.lift(body)
	_apply(body, smooth, flat)
	if soft or SoftLook.on():
		SoftLook.apply_body(body)


static func _apply(body: CharacterBodyMesh, smooth: float, flat := true) -> void:
	var c := cfg()
	var s := clampf(smooth, 0.0, 1.0)
	for m: ShaderMaterial in materials(body):
		var own: Dictionary = m.get_meta("adult_skin", {})
		if own.is_empty():
			for k: String in NUMS:
				var v: Variant = m.get_shader_parameter(k)
				own[k] = float(v) if v != null else float(ADULT[k])
			var hb: Variant = m.get_shader_parameter("haemoglobin")
			own["haemoglobin"] = float(hb) if hb != null else 0.5
			m.set_meta("adult_skin", own)
		for k: String in NUMS:
			m.set_shader_parameter(k, lerpf(float(own[k]), float(c.get(k, own[k])), s))
		m.set_shader_parameter("haemoglobin", maxf(float(own.haemoglobin), lerpf(float(own.haemoglobin), float(c.get("haemoglobin_min", 0.6)), s)))
		if s > 0.0 and m.shader == BodyMaterials.SKIN_SHADER:
			m.shader = fuzz_shader()
		elif s <= 0.0 and m.shader == fuzz_shader():
			m.shader = BodyMaterials.SKIN_SHADER
		if m.shader == fuzz_shader():
			m.set_shader_parameter("child_adult_pos", 1 if ChildProportion.of(body) != null else 0)
			# a child's chest: no areolae or nipples drawn (the flat child body; body_detail's A channel)
			m.set_shader_parameter("child_flat", 1.0 if flat else 0.0)
			m.set_shader_parameter("child_fuzz", float(c.get("fuzz", 0.2)) * s)
			m.set_shader_parameter("child_fuzz_tint", float(c.get("fuzz_tint", 0.35)))
			m.set_shader_parameter("child_lip", float(c.get("lip_pink", 0.0)) * s)
			m.set_shader_parameter("child_soft_ao", float(c.get("soft_ao", 0.0)) * s)
	_eyes(body, s, c)


## A young eye (baby_body.json skin "eye", by the smoothness): a touch larger iris, a cleaner, bluer white, less of the lid's shadow on
## it (the eye material is the body's own: BodyMaterials.apply_look makes one per look).
static func _eyes(body: CharacterBodyMesh, s: float, c: Dictionary) -> void:
	var ec: Dictionary = c.get("eye", {})
	for mi: MeshInstance3D in body.meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m != null and m.shader == BodyMaterials.FACE_HAIR_SHADER:
				# fine, short, softer lashes
				var ol: Dictionary = m.get_meta("adult_lash", {})
				if ol.is_empty():
					var ll: Variant = m.get_shader_parameter("lash_length")
					var lc: Variant = m.get_shader_parameter("lash_color")
					ol = {"len": float(ll) if ll != null else 0.85, "col": lc if lc is Color else Color(0.04, 0.03, 0.025)}
					m.set_meta("adult_lash", ol)
				m.set_shader_parameter("lash_length", lerpf(float(ol.len), float(ec.get("lash_length", ol.len)), s))
				m.set_shader_parameter("lash_color", (ol.col as Color).lerp(Color(0.5, 0.4, 0.35), float(ec.get("lash_light", 0.0)) * s))
				continue
			if m == null or m.shader != BodyMaterials.EYE_SHADER:
				continue
			var own: Dictionary = m.get_meta("adult_eye", {})
			if own.is_empty():
				for k: String in ["iris_radius", "pupil_radius", "lid_shadow", "sclera_color"]:
					own[k] = m.get_shader_parameter(k)
				own["iris_radius"] = float(own.iris_radius) if own.iris_radius != null else 0.0058
				own["pupil_radius"] = float(own.pupil_radius) if own.pupil_radius != null else 0.0021
				own["lid_shadow"] = float(own.lid_shadow) if own.lid_shadow != null else 0.6
				own["sclera_color"] = own.sclera_color if own.sclera_color is Color else Color(0.66, 0.62, 0.57)
				m.set_meta("adult_eye", own)
			var ir := lerpf(float(own.iris_radius), float(ec.get("iris_radius", own.iris_radius)), s)
			m.set_shader_parameter("iris_radius", ir)
			m.set_shader_parameter("pupil_radius", float(own.pupil_radius) * ir / float(own.iris_radius))
			m.set_shader_parameter("lid_shadow", lerpf(float(own.lid_shadow), float(ec.get("lid_shadow", own.lid_shadow)), s))
			var sc: Array = ec.get("sclera", [])
			if sc.size() >= 3:
				m.set_shader_parameter("sclera_color", (own.sclera_color as Color).lerp(Color(float(sc[0]), float(sc[1]), float(sc[2])), s))


## The smoothness a skin material has now (0 adult .. 1 newborn; tests).
static func smoothness(m: ShaderMaterial) -> float:
	var own: Dictionary = m.get_meta("adult_skin", {})
	if own.is_empty():
		return 0.0
	var a := float(own.head_detail_strength)
	var b := float(cfg().get("head_detail_strength", 0.12))
	return clampf((a - float(m.get_shader_parameter("head_detail_strength"))) / maxf(a - b, 0.001), 0.0, 1.0)


## skin.gdshader with the soft grazing sheen (RIM) at the end of its fragment(), for children only.
static func fuzz_shader() -> Shader:
	if _fuzz_shader != null:
		return _fuzz_shader
	var code: String = BodyMaterials.SKIN_SHADER.code
	var at := code.find("void fragment()")
	var end := code.rfind("}")
	if at < 0 or end < at:
		_fuzz_shader = BodyMaterials.SKIN_SHADER
		return _fuzz_shader
	var u := code.find("void vertex()")
	code = code.substr(0, u) + FUZZ_UNIFORMS + "\n" + code.substr(u, end - u) + FUZZ_CODE + code.substr(end)
	for r: Array in ADULT_POS:
		if code.find(String(r[0])) < 0:
			push_warning("ChildSkin: the skin shader changed (%s): the neck gradients use the child's own heights" % r[0])
		code = code.replace(String(r[0]), String(r[1]))
	_fuzz_shader = Shader.new()
	_fuzz_shader.code = code
	return _fuzz_shader
