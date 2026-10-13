extends SceneTree
## Every material the ring's world draws with (not the fighters'), for the world's look work: each unique material once, with the
## system that made it (the nearest ancestor with a class), its kind (StandardMaterial3D or the shader's path), its colours and
## textures, and how many surfaces use it; then every light and the environment. Windowed (the ring builds its visuals only when
## it draws); a normal window.
##   Godot --path . --resolution 1280x720 -s tools/ring/world_materials_inventory.gd -- out=<file.json> [light=noon]
## Ends with WORLD MATERIALS INVENTORY DONE.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")

var a := {}
var mats := {}
var lights: Array = []


func _initialize() -> void:
	a = CaptureKit.args({"out": "", "light": "noon"})
	if not CaptureKit.begin(self, "world_materials_inventory"):
		return
	GameSettings.path = "user://world_materials_inventory.cfg"
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.difficulty = "easy"
	MatchSetup.light = String(a.light)
	RingRules.rule_set_override = "stock"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	await CaptureKit.frames(self, 20)
	var lvl := current_scene
	await CaptureKit.wait_loaded(self, lvl)
	await CaptureKit.frames(self, 60)
	_walk(lvl)
	var env: Environment = null
	var we := _find_env(root)
	if we != null:
		env = we.environment
	var out := {"materials": mats.values(), "lights": lights, "environment": _env_dict(env)}
	var f := FileAccess.open(String(a.out), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("materials %d, lights %d" % [mats.size(), lights.size()])
	print("WORLD MATERIALS INVENTORY DONE")
	quit(0)


func _find_env(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n
	for c in n.get_children():
		var w := _find_env(c)
		if w != null:
			return w
	return null


func _maker(n: Node) -> String:
	var at := n
	while at != null:
		var s: Script = at.get_script()
		if s != null and s.get_global_name() != &"":
			return String(s.get_global_name())
		at = at.get_parent()
	return "?"


func _is_fighter(n: Node) -> bool:
	var at := n
	while at != null:
		if at is CharacterBodyMesh or at is CharacterBody3D:
			return true
		at = at.get_parent()
	return false


func _walk(n: Node) -> void:
	if n is Light3D and (n as Light3D).visible:
		var l := n as Light3D
		lights.append({"path": str(l.get_path()), "class": l.get_class(), "maker": _maker(l), "color": l.light_color.to_html(false),
				"energy": l.light_energy, "range": l.get("omni_range") if l is OmniLight3D else l.get("spot_range"),
				"shadow": l.shadow_enabled})
	if n is GeometryInstance3D and not _is_fighter(n):
		var g := n as GeometryInstance3D
		var found: Array = []
		if g.material_override != null:
			found.append(g.material_override)
		if g.material_overlay != null:
			found.append(g.material_overlay)
		if g is MeshInstance3D:
			var mi := g as MeshInstance3D
			if mi.mesh != null:
				for s in mi.mesh.get_surface_count():
					var m := mi.get_active_material(s)
					if m != null:
						found.append(m)
		elif g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null:
				for s in mm.mesh.get_surface_count():
					var m := mm.mesh.surface_get_material(s)
					if m != null:
						found.append(m)
		elif g is CPUParticles3D or g is GPUParticles3D:
			pass
		for m: Material in found:
			_note(m, g)
	for c in n.get_children():
		_walk(c)


func _note(m: Material, g: GeometryInstance3D) -> void:
	var k := m.get_instance_id()
	if mats.has(k):
		mats[k].uses += 1
		return
	var d := {"uses": 1, "maker": _maker(g), "node": str(g.name), "path": str(g.get_path()).trim_prefix("/root/"),
			"res": m.resource_path, "visible": g.is_visible_in_tree()}
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		d.kind = m.get_class()
		d.albedo = b.albedo_color.to_html(true)
		d.albedo_tex = b.albedo_texture.resource_path if b.albedo_texture != null else ""
		d.normal = b.normal_enabled
		d.emission = b.emission.to_html(false) if b.emission_enabled else ""
		d.unshaded = b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		d.transparent = b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		d.vertex_color = b.vertex_color_use_as_albedo
		d.uv1_scale = str(b.uv1_scale)
		d.triplanar = b.uv1_triplanar
	elif m is ShaderMaterial:
		var sm := m as ShaderMaterial
		d.kind = "shader"
		d.shader = sm.shader.resource_path if sm.shader != null else ""
		var params := {}
		if sm.shader != null:
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				var v: Variant = sm.get_shader_parameter(u.name)
				if v is Color:
					params[u.name] = "Color " + (v as Color).to_html(true)
				elif v is Vector3 or v is Vector4 or v is float or v is int or v is bool:
					params[u.name] = str(v)
				elif v is Texture2D:
					params[u.name] = "tex " + (v as Texture2D).resource_path
				elif v == null and String(u.get("hint_string", "")) != "":
					params[u.name] = "-"
		d.params = params
	else:
		d.kind = m.get_class()
	mats[k] = d


func _env_dict(env: Environment) -> Dictionary:
	if env == null:
		return {}
	return {"background": env.background_mode, "sky_material": env.sky.sky_material.get_class() if env.sky != null and env.sky.sky_material != null else "",
			"ambient_source": env.ambient_light_source, "ambient_color": env.ambient_light_color.to_html(false),
			"ambient_energy": env.ambient_light_energy, "sky_contribution": env.ambient_light_sky_contribution,
			"tonemap": env.tonemap_mode, "exposure": env.tonemap_exposure, "glow": env.glow_enabled, "ssao": env.ssao_enabled,
			"fog": env.fog_enabled, "fog_density": env.fog_density, "saturation": env.adjustment_saturation,
			"color_correction": env.adjustment_color_correction != null}
