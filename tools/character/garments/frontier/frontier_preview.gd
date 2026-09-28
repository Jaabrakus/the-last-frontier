extends SceneTree
## Preview renders of the Frontiersman / trapper garments (assets/character/garments/frontier)
## on the customizer body, both fits, with the fur and fringe shaders. Needs a window (not
## --headless); run it under a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/character/garments/frontier/frontier_preview.gd -- \
##       out=DIR [only=looks,items,poses,furs,close] [items=id,id]
##
## Cloth zones use preview_cloth.gdshader (next to this script): a stand-in for the fabric
## workstream's cloth shader (tinted luminance of the approved Poly Haven kits). Fur uses
## assets/character/shaders/fur_shell.gdshader with the catalog fur presets, fringe
## assets/character/shaders/fringe.gdshader. Hide masks follow the catalog: body regions in
## any worn item's hides_regions, garment regions hidden by a higher layer, hat hair zones.
## Prints FRONTIER PREVIEW DONE (or FAILED with the reasons).

const GDIR := "res://assets/character/garments/frontier/"
const TEX := "res://assets/polyhaven/textures/clothing/"
const FABRICS := {"LIN": ["rough_linen", 0.271], "WOOL": ["caban", 0.274], "TWILL": ["poly_wool_herringbone", 0.27],
		"KNIT": ["knitted_fleece", 0.266], "SUEDE": ["scuba_suede", 0.285], "LEA": ["brown_leather", 0.4],
		"FUR": ["curly_teddy_natural", 0.336], "HES": ["hessian_230", 0.269]}
const CLOTH := preload("res://tools/character/garments/frontier/preview_cloth.gdshader")
const FUR := preload("res://assets/character/shaders/fur_shell.gdshader")
const FRINGE := preload("res://assets/character/shaders/fringe.gdshader")
const IDLE := "actor_b-p-stealth-idle"
const TOKENS := {"linen_unbleached": "#C8BA9A", "linen_white": "#E8E3D3", "tow": "#A99570", "stroud_blue": "#1E2B4A",
		"stroud_red": "#8A1C1F", "madder_red": "#8E2B21", "walnut_brown": "#5A3F2C", "drab": "#8B7A5C",
		"ranger_green": "#3B4A2E", "indigo_mid": "#34507A", "leather_brown": "#5B3D26", "buckskin_smoked": "#A07E55",
		"buckskin_pale": "#C8AA7C", "logwood_black": "#1C1B20", "slate_grey": "#6B6A66", "butternut": "#957549"}

var args := {}
var out := ""
var failures := PackedStringArray()
var world: Node3D
var cam: Camera3D
var chars: Array = []
var _tex_cache := {}
var _entries := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = args.get("out", "user://frontier_preview")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	await _studio()
	for g in ["items", "looks", "furs", "poses", "close"]:
		if not _wanted(g):
			continue
		print("group ", g)
		match g:
			"items": await _items()
			"looks": await _looks()
			"furs": await _furs()
			"poses": await _poses()
			"close": await _close()
	print("FRONTIER PREVIEW DONE" if failures.is_empty() else "FRONTIER PREVIEW FAILED: " + "; ".join(failures))
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
	env.background_color = Color(0.36, 0.38, 0.40)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.53, 0.58)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	for l in [[Vector3(-35, 30, 0), 1.1, true], [Vector3(-15, -60, 0), 0.3, false], [Vector3(-25, 160, 0), 0.6, false]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = l[1]
		d.shadow_enabled = l[2]
		world.add_child(d)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.30, 0.29, 0.27)
	ground.material_override = gm
	world.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 28.0
	cam.near = 0.02
	world.add_child(cam)
	cam.current = true
	root.use_taa = true          # the game's default anti-aliasing (world_settings.gd)


func entry(id: String) -> Dictionary:
	if not _entries.has(id):
		var p := GDIR + id + ".json"
		var d = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
		if not d is Dictionary:
			failures.append("no catalog fragment " + p)
			d = {}
		_entries[id] = d
	return _entries[id]


func _tex(code: String, kind: String) -> Texture2D:
	var key := code + kind
	if not _tex_cache.has(key):
		var t: Texture2D = null
		if FABRICS.has(code):
			var n: String = FABRICS[code][0]
			t = load("%s%s/%s_%s_2k.jpg" % [TEX, n, n, kind]) as Texture2D
		_tex_cache[key] = t
	return _tex_cache[key]


static func _hex(v) -> Color:
	var s := String(v)
	if s.begins_with("#"):
		return Color(s)
	return Color(TOKENS.get(s, "#808080"))


func _token_color(e: Dictionary, z: Dictionary, tok) -> Color:
	var ph: Dictionary = z.get("palette_hex", {})
	if tok != null and ph.has(tok):
		return Color(String(ph[tok]))
	return _hex(tok)


## Look item: {"id": .., "colors": {zone name or role: token}, "bands": n}
func _zone_token(it: Dictionary, z: Dictionary):
	var c: Dictionary = it.get("colors", {})
	for k in [String(z.get("name", "")), String(z.get("role", "")), str(int(z.get("zone", 0)))]:
		if c.has(k):
			return c[k]
	return z.get("default", null)


func _cloth_material(e: Dictionary, it: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLOTH
	var tile := Vector4(0.27, 0.27, 0.27, 0.27)
	var has := Vector4.ZERO
	var metal := Vector4.ZERO
	var rough := Vector4(0.85, 0.85, 0.85, 0.85)
	var ds := Vector4(0.7, 0.7, 0.7, 0.7)
	var ns := Vector4(0.6, 0.6, 0.6, 0.6)
	var fur_presets: Dictionary = e.get("fur", {}).get("presets", {})
	for z: Dictionary in e.get("zones", []):
		var zi := int(z.get("zone", 0))
		if zi > 3:
			continue
		var code := String(z.get("fabric", "FLAT"))
		var tok = _zone_token(it, z)
		var col := _token_color(e, z, tok)
		if String(z.get("role", "")) == "fur" and fur_presets.has(tok):
			col = Color(String(fur_presets[tok].root))
		m.set_shader_parameter("tint%d" % zi, col)
		var t := _tex(code, "diffuse")
		if t:
			m.set_shader_parameter("tex%d" % zi, t)
			m.set_shader_parameter("nrm%d" % zi, _tex(code, "nor_gl"))
			has[zi] = 1.0
			tile[zi] = float(FABRICS[code][1]) * (0.6 if code == "TWILL" else 1.0)
		if code in ["MET"] or String(z.get("role", "")) == "metal":
			metal[zi] = 1.0
			rough[zi] = 0.3
		if code == "LEA":
			rough[zi] = 0.6
		if code == "SUEDE":
			ds[zi] = 0.35
			ns[zi] = 0.3
			rough[zi] = 0.9
		if code == "FUR":
			ds[zi] = 0.5
	m.set_shader_parameter("tile", tile)
	m.set_shader_parameter("has_tex", has)
	m.set_shader_parameter("metal", metal)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("detail_strength", ds)
	m.set_shader_parameter("normal_strength", ns)
	var bands: Dictionary = {}
	for z: Dictionary in e.get("zones", []):
		if int(z.get("zone", 0)) == 0 and z.get("bands") is Dictionary:
			bands = z.bands
	if not bands.is_empty() and int(it.get("bands", bands.get("default_rows", 0))) > 0:
		var rows := int(it.get("bands", bands.get("default_rows", 0)))
		m.set_shader_parameter("band_rows", Vector4(rows, float(bands.get("offset_m", 0.05)), float(bands.get("width_m", 0.03)),
				float(bands.get("gap_m", 0.02))))
		m.set_shader_parameter("band_color", _hex(it.get("band_color", bands.get("default", "stroud_blue"))))
	return m


func _fur_material(e: Dictionary, it: Dictionary) -> ShaderMaterial:
	var f: Dictionary = e.get("fur", {})
	var tok = null
	for z: Dictionary in e.get("zones", []):
		if int(z.get("zone", 0)) == int(f.get("palette_zone", 0)):
			tok = _zone_token(it, z)
	var p: Dictionary = f.get("presets", {}).get(tok, {})
	var m := ShaderMaterial.new()
	m.shader = FUR
	var u: Dictionary = f.get("uniforms", {})
	for k: String in u:
		if not p.has(u[k]):
			continue
		var v = p[u[k]]
		m.set_shader_parameter(k, Color(String(v)) if v is String else float(v))
	if p.has("length"):
		m.set_shader_parameter("fur_length", float(p.length) * float(f.get("length_scale", 1.0)))
	m.set_shader_parameter("belt_flatten", float(it.get("belt_flatten", 0.0)))
	m.set_shader_parameter("strap_flatten", float(it.get("strap_flatten", 0.0)))
	return m


func _fringe_material(e: Dictionary, it: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FRINGE
	for z: Dictionary in e.get("zones", []):
		if String(z.get("role", "")) == "fringe":
			m.set_shader_parameter("fringe_color", _token_color(e, z, _zone_token(it, z)))
			var t := _tex(String(z.get("fabric", "")), "diffuse")
			if t:
				m.set_shader_parameter("detail", t)
				m.set_shader_parameter("use_detail", 1.0)
				m.set_shader_parameter("tile", float(FABRICS[String(z.fabric)][1]))
	return m


static func _layer(e: Dictionary) -> int:
	return int(e.get("layer", {}).get("default", 10))


## A fresh Actor_B at `pos` with the body, hair and the look's items.
func _character(pos: Vector3, yaw_deg: float, look: Dictionary, items: Array) -> Array:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	if float(look.get("sex", 0.0)) > 0.5:
		inst.scale = Vector3.ONE * float(look.get("stature", 1.07))
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var parts := {"body": BodyMaterials.BODY_GLB}
	var hide := []
	var hair_hide := []
	for it: Dictionary in items:
		var e := entry(it.id)
		if e.is_empty():
			continue
		parts[it.id] = String(e.glb)
		for r in e.get("hides_regions", []):
			if not r in hide:
				hide.append(r)
		for z in e.get("hides_hair_zones", []):
			if not z in hair_hide:
				hair_hide.append(z)
	var body := CharacterBodyMesh.attach_parts(sk, ap, parts)
	if body == null:
		failures.append("attach failed")
		return []
	var l := look.duplicate(true)
	l["hide_regions"] = hide
	l["hide_hair_zones"] = hair_hide
	BodyMaterials.apply_look(body, l)
	for it: Dictionary in items:
		var e := entry(it.id)
		if e.is_empty():
			continue
		# regions of this item hidden by items on a higher layer
		var hid := []
		for other: Dictionary in items:
			var oe := entry(other.id)
			if other.id != it.id and _layer(oe) > _layer(e):
				hid += oe.get("hides_regions", [])
		var mask := BodyMaterials.hide_mask(hid)
		var cloth := _cloth_material(e, it)
		var fur := _fur_material(e, it) if e.has("fur") else null
		var fringe := _fringe_material(e, it)
		for m in [cloth, fur, fringe]:
			if m:
				m.set_shader_parameter("hide_mask", mask)
		for mi: MeshInstance3D in body.part_meshes(it.id):
			for s in mi.mesh.get_surface_count():
				var sm := mi.mesh.surface_get_material(s)
				var n := sm.resource_name if sm else ""
				if n.ends_with("_fur") and fur:
					mi.set_surface_override_material(s, fur)
				elif n.ends_with("_fringe"):
					mi.set_surface_override_material(s, fringe)
				else:
					mi.set_surface_override_material(s, cloth)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.deterministic = true
	_pose(ap, String(look.get("clip", IDLE)), float(look.get("t", 0.0)))
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
	await _frames(14)
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	root.get_viewport().get_texture().get_image().save_png(p)
	return p


const F_LOOK := {"sex": 0.0, "face": "f_face_2", "melanin": 0.35, "hair": {"style": "hair_braid_f", "color": "dark_brown"}}
const M_LOOK := {"sex": 1.0, "face": "m_face_1", "melanin": 0.55, "stubble": 0.4, "hair": {"style": "hair_queue_ribbon", "color": "black"}}


func _item_list() -> Array:
	if args.has("items"):
		return Array(String(args.items).split(","))
	var ids := []
	for f in DirAccess.get_files_at(GDIR):
		if f.ends_with(".json") and not f.begins_with("_") and f != "catalog.json" and f != "presets.json":
			var e := entry(f.get_basename())
			if e.has("slot"):
				ids.append(f.get_basename())
	ids.sort()
	return ids


## Every item alone on both fits: front, three-quarter and back.
func _items() -> void:
	for id: String in _item_list():
		var e := entry(id)
		var head := String(e.get("slot", "")) == "head"
		var feet := String(e.get("slot", "")) == "feet"
		var yaws := [0.0, 35.0, 180.0]
		for i in 2:
			var look: Dictionary = (M_LOOK if i == 1 else F_LOOK).duplicate(true)
			for j in 3:
				_character(Vector3((i * 3 + j) * 0.9 - 2.25, 0, 0), yaws[j], look, [{"id": id}])
		await _frames(2)
		if head:
			for i in 2:
				_look_at(Vector3((i * 3 + 1) * 0.9 - 2.25, 1.5, 0), Vector3(0, 0.05, 3.2), 30.0)
				await _shot("item_%s_%s" % [id, ["f", "m"][i]])
		elif feet:
			for i in 2:
				_look_at(Vector3((i * 3 + 1) * 0.9 - 2.25, 0.12, 0), Vector3(0, 0.25, 3.0), 30.0)
				await _shot("item_%s_%s" % [id, ["f", "m"][i]])
		else:
			for i in 2:
				_look_at(Vector3((i * 3 + 1) * 0.9 - 2.25, 0.86, 0), Vector3(0, 0.3, 5.6), 26.0)
				await _shot("item_%s_%s" % [id, ["f", "m"][i]])
		await _clear()


## Outfit looks (args looks=...): presets of the set on both fits.
func _outfits() -> Array:
	return [
		["winter_trapper", [{"id": "capot_blanket", "colors": {"cloth": "#E3DED0"}, "bands": 2},
				{"id": "fur_cap", "colors": {"fur": "fur_beaver"}}, {"id": "leggings_buckskin"},
				{"id": "moccasins_puckered"}, {"id": "horn_and_pouch_env40"}]],
		["fur_coat_bear", [{"id": "fur_coat_tailored", "colors": {"fur": "fur_black_bear"}},
				{"id": "fur_cap", "colors": {"fur": "fur_raccoon"}}, {"id": "leggings_buckskin"}, {"id": "moccasins_puckered"}]],
		["fur_coat_wolf", [{"id": "fur_coat_tailored", "colors": {"fur": "fur_wolf"}}, {"id": "leggings_buckskin"},
				{"id": "moccasins_puckered"}]],
		["backcountry_hunter", [{"id": "hunting_shirt_tow", "colors": {"cloth": "tow", "fringe": "linen_unbleached"}},
				{"id": "leggings_buckskin"}, {"id": "moccasins_puckered"}, {"id": "powder_horn_env40"}]],
	]


func _looks() -> void:
	for o in _outfits():
		var items: Array = []
		for it: Dictionary in o[1]:
			if FileAccess.file_exists(GDIR + String(it.id).trim_suffix("_env40") + ".json"):
				var c := it.duplicate(true)
				c.id = String(it.id).trim_suffix("_env40")
				items.append(c)
		var yaws := [0.0, 35.0, 180.0]
		for i in 2:
			for j in 3:
				_character(Vector3((i * 3 + j) * 0.9 - 2.25, 0, 0), yaws[j], M_LOOK if i == 1 else F_LOOK, items)
		await _frames(2)
		for i in 2:
			_look_at(Vector3((i * 3 + 1) * 0.9 - 2.25, 0.86, 0), Vector3(0, 0.3, 5.6), 26.0)
			await _shot("look_%s_%s" % [o[0], ["f", "m"][i]])
		await _clear()


## The fur colourings side by side (coat), and close-ups of the pile.
func _furs() -> void:
	if not FileAccess.file_exists(GDIR + "fur_coat_tailored.json"):
		return
	var furs := ["fur_black_bear", "fur_brown_bear", "fur_beaver", "fur_wolf", "fur_raccoon"]
	for i in furs.size():
		_character(Vector3(i * 0.9 - 1.8, 0, 0), 25.0, M_LOOK if i % 2 == 1 else F_LOOK,
				[{"id": "fur_coat_tailored", "colors": {"fur": furs[i]}}])
	await _frames(2)
	_look_at(Vector3(0, 0.85, 0), Vector3(0, 0.3, 10.0), 27.0)
	await _shot("furs_coat")
	for i in furs.size():
		_look_at(Vector3(i * 0.9 - 1.8 + 0.02, 1.05, 0), Vector3(0.25, 0.05, 1.1), 26.0)
		await _shot("furs_close_%s" % furs[i])
	await _clear()


## Deformation: run, crouch walk, musket aim, bow aim, sprint for each outfit on both fits.
func _poses() -> void:
	var clips := [["run", "actor_b-p-run-fw", 0.3], ["crouch", "actor_b-p-crouch-walk-fw", 0.5],
			["musket", "actor_b-p-rifle-idle-aim", 0.0], ["bow", "actor_b-p-bow-aim-idle", 0.0],
			["sprint", "actor_b-p-sprint-fw", 0.6]]
	for o in _outfits():
		var items: Array = []
		for it: Dictionary in o[1]:
			if FileAccess.file_exists(GDIR + String(it.id).trim_suffix("_env40") + ".json"):
				var c := it.duplicate(true)
				c.id = String(it.id).trim_suffix("_env40")
				items.append(c)
		for i in 2:
			for j in clips.size():
				var look: Dictionary = (M_LOOK if i == 1 else F_LOOK).duplicate(true)
				look["clip"] = clips[j][1]
				look["t"] = clips[j][2]
				_character(Vector3(j * 1.15 - 2.3, 0, 0), 35.0, look, items)
			await _frames(2)
			_look_at(Vector3(0, 0.72, 0), Vector3(0, 0.6, 7.6), 31.0)
			await _shot("poses_%s_%s" % [o[0], ["f", "m"][i]])
			_look_at(Vector3(0, 0.72, 0), Vector3(-2.2, 1.0, -7.0), 31.0)
			await _shot("poses_%s_%s_back" % [o[0], ["f", "m"][i]])
			await _clear()


## Close-ups: fur coat collar and cuff, fringe, moccasins, fur cap.
func _close() -> void:
	var items := []
	for it in [{"id": "fur_coat_tailored", "colors": {"fur": "fur_wolf"}}, {"id": "fur_cap", "colors": {"fur": "fur_red_fox"}}]:
		if FileAccess.file_exists(GDIR + String(it.id) + ".json"):
			items.append(it)
	if items.is_empty():
		return
	var c := _character(Vector3.ZERO, 20.0, M_LOOK, items)
	await _frames(2)
	_look_at(Vector3(0, 1.35, 0), Vector3(0.3, 0.05, 1.0), 30.0)
	await _shot("close_collar")
	_look_at(Vector3(0.38, 0.95, 0), Vector3(0.5, 0.1, 0.7), 30.0)
	await _shot("close_cuff")
	_look_at(Vector3(0, 0.6, 0), Vector3(-0.3, 0.1, -1.2), 30.0)
	await _shot("close_back_hem")
	await _clear()
