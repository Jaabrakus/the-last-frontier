extends SceneTree
## Isolated art-direction study on Tidebreak's existing characters. No source geometry,
## outfits, appearance saves, or shipping defaults are changed by this tool.
##
## Godot --path . --resolution 1440x900 -s tools/character/botw_style_preview.gd -- \
##     out=res://artifacts/character_style_preview [views=front,three_quarter,side,back,face] [modes=current,palette,soft_cel]
## Add check=1 with --headless for the construction and material-isolation checks.
## The palette and soft cel response are a new study; they are not Nintendo shaders.

const IDLE := &"actor_b/actor_b-p-stealth-idle"
const PALETTE := {
	"teal": "#4D9BA5", "cream": "#EDE3C6", "leather": "#735341",
	"slate": "#445962", "ochre": "#C8A75B", "sage": "#8C9F79",
}
const VIEWS := {
	"front": Vector3(0.0, 0.08, 1.0),
	"three_quarter": Vector3(0.65, 0.12, 1.0),
	"side": Vector3(1.0, 0.09, 0.0),
	"back": Vector3(0.0, 0.08, -1.0),
}
const SOFT_LIGHT := """
// Preview-only soft three-band lighting. Godot multiplies diffuse light by albedo.
void light() {
	float nl = dot(NORMAL, LIGHT);
	float shade = mix(0.32, 0.72, smoothstep(-0.08, 0.14, nl));
	shade = mix(shade, 1.0, smoothstep(0.43, 0.55, nl));
	vec3 tint = mix(vec3(0.78, 0.88, 1.0), vec3(1.0, 0.97, 0.90), smoothstep(0.0, 0.45, nl));
	DIFFUSE_LIGHT += shade * tint * ATTENUATION * LIGHT_COLOR / PI;
}
"""

var args: Dictionary = {}
var output := ""
var world: Node3D
var camera: Camera3D
var heading: Label
var description: Label
var characters: Array[Dictionary] = []
var failures := PackedStringArray()
var cloned_shaders: Dictionary = {}
var checks := 0
var current_mode := "current"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if "=" in arg:
			args[arg.get_slice("=", 0)] = arg.substr(arg.find("=") + 1)
	output = ProjectSettings.globalize_path(String(args.get("out", "res://artifacts/character_style_preview")))
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, OS.has_environment("TB_ON_TOP"))
	_stage()
	_build_character("vietnamese_m_a", "earth", -0.72)
	_build_character("vietnamese_f_a", "air", 0.72)
	await _frames(12)
	for character: Dictionary in characters:
		var player := character.player as AnimationPlayer
		player.seek(0.3, true)
		player.pause()
		_check((character.body as CharacterBodyMesh).report.get("max_bind_diff", 1.0) < 0.001, "skin bind agreement")
	if args.get("check", "0") == "1":
		_set_mode("soft_cel")
		_verify_isolation()
		if args.has("compare"):
			_make_comparison(String(args.compare))
		_finish()
		return
	for mode: String in String(args.get("modes", "current,palette,soft_cel")).split(","):
		print("preparing mode ", mode)
		_set_mode(mode)
		for view: String in String(args.get("views", "front,three_quarter,side,back,face")).split(","):
			if not _camera_view(view):
				continue
			await _capture(mode + "_" + view)
	_verify_isolation()
	_make_comparison()
	_finish()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _stage() -> void:
	world = Node3D.new()
	world.name = "CharacterStyleStudy"
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#87AEC2")
	sky_material.sky_horizon_color = Color("#E7E8D7")
	sky_material.ground_bottom_color = Color("#8F9979")
	sky_material.ground_horizon_color = Color("#E7E8D7")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#CDDCDD")
	environment.ambient_light_energy = 0.35
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.ssao_enabled = false
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.name = "WarmAfternoon"
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_color = Color("#FFF0D4")
	key.light_energy = 0.95
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 20.0
	world.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#A3AF8A")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	ground.position.y = -0.015
	world.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 28.0
	camera.near = 0.02
	world.add_child(camera)
	camera.current = true
	root.msaa_3d = Viewport.MSAA_4X
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(layout)
	heading = _label(layout, Vector2(40, 28), 29, Color("#283D43"))
	description = _label(layout, Vector2(40, 69), 17, Color("#42575A"))
	var footer := _label(layout, Vector2(40, 850), 15, Color("#344A4B"))
	footer.text = "TIDEBREAK / CHARACTER ART STUDY     Existing meshes + outfits / same pose + lighting / isolated preview"
	var swatch_x := 40.0
	for color_name: String in PALETTE:
		var swatch := ColorRect.new()
		swatch.color = Color(PALETTE[color_name])
		swatch.position = Vector2(swatch_x, 798)
		swatch.size = Vector2(44, 24)
		layout.add_child(swatch)
		var text := _label(layout, Vector2(swatch_x + 51, 800), 14, Color("#344A4B"))
		text.text = color_name.capitalize()
		swatch_x += 177.0


func _label(parent: Node, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _build_character(preset: String, element: String, x: float) -> void:
	var actor := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	actor.position.x = x
	world.add_child(actor)
	var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var body := CharacterBodyMesh.attach(skeleton, player)
	BindRest.ensure_character(actor)
	var look := AppearanceStore.validate(CharacterPeoples.preset_look(preset))
	look["outfit"] = PlayerAppearance.arena_outfit(element, float(look.get("sex", 0.0)))
	PlayerAppearance.dress(body, look)
	player.play(IDLE)
	player.seek(0.3, true)
	player.pause()
	var part_of: Dictionary = {}
	for part: String in body.parts:
		for mesh: MeshInstance3D in body.part_meshes(part):
			part_of[mesh] = part
	var original: Array[Dictionary] = []
	for mesh: MeshInstance3D in body.meshes:
		if not is_instance_valid(mesh) or not mesh.visible or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is ShaderMaterial:
				original.append({"mesh": mesh, "surface": surface, "material": material,
					"shader_code": (material as ShaderMaterial).shader.code,
					"part": String(part_of.get(mesh, "")), "name": String(mesh.name)})
	_check(not original.is_empty(), preset + " visible materials")
	characters.append({"actor": actor, "body": body, "player": player, "element": element, "look": look, "materials": original})


func _set_mode(mode: String) -> void:
	current_mode = mode
	heading.text = {
		"current": "01 / CURRENT MATERIALS", "palette": "02 / SOFTER PALETTE",
		"soft_cel": "03 / SOFTER PALETTE + CEL LIGHTING",
	}.get(mode, mode)
	description.text = "Our current character geometry and arena outfits. Warm cream, muted teal, earth accents and calm lighting."
	for character: Dictionary in characters:
		for entry: Dictionary in character.materials:
			var mesh := entry.mesh as MeshInstance3D
			if mode == "current":
				mesh.set_surface_override_material(int(entry.surface), entry.material as Material)
				continue
			var original := entry.material as ShaderMaterial
			var material := original.duplicate() as ShaderMaterial
			var shader_path := original.shader.resource_path
			if original.shader == ClothMaterials.CLOTH_SHADER:
				_palette_cloth(material, String(entry.part), String(character.element))
				if mode == "soft_cel":
					material.set_shader_parameter("detail_strength", Vector4.ONE * 0.12)
					material.set_shader_parameter("normal_strength", Vector4.ONE * 0.08)
					material.set_shader_parameter("dirt_amount", 0.1)
					material.set_shader_parameter("wear_amount", 0.18)
					material.set_shader_parameter("sweat_amount", 0.1)
					material.set_shader_parameter("macro_var", 0.025)
					material.set_shader_parameter("character", 0.15)
					material.set_shader_parameter("fold_amount", 0.4)
					material.set_shader_parameter("cavity_amount", 0.3)
					material.set_shader_parameter("sheen", Vector4.ONE * 0.025)
			elif shader_path.ends_with("skin.gdshader"):
				if mode == "soft_cel":
					for parameter: String in ["detail_strength", "head_detail_strength", "body_detail_strength"]:
						material.set_shader_parameter(parameter, 0.15)
					material.set_shader_parameter("weathering", 0.08)
					material.set_shader_parameter("skin_specular", 0.1)
					material.set_shader_parameter("oil_sheen", 0.0)
					material.set_shader_parameter("sss_strength", 0.06)
					material.set_shader_parameter("neck_bounce", 0.08)
			if mode == "soft_cel" and not original.shader.code.contains("void light()"):
				material.shader = _soft_shader(original.shader)
			mesh.set_surface_override_material(int(entry.surface), material)


func _palette_cloth(material: ShaderMaterial, mesh_name: String, element: String) -> void:
	var colors := ["teal", "cream", "slate", "ochre"]
	if "legs.lower" in mesh_name:
		colors = ["cream", "leather", "ochre", "slate"]
	elif "feet" in mesh_name or "accessories.arms" in mesh_name:
		colors = ["leather", "slate", "cream", "ochre"]
	elif "accessories.waist" in mesh_name:
		colors = ["leather", "ochre", "cream", "ochre"]
	elif element == "air":
		colors = ["cream", "teal", "slate", "ochre"]
	for zone in 4:
		material.set_shader_parameter("tint%d" % zone, ClothMaterials.lin4(Color(PALETTE[colors[zone]])))
	material.set_shader_parameter("band_color", ClothMaterials.lin4(Color(PALETTE.ochre)))


func _soft_shader(original: Shader) -> Shader:
	if cloned_shaders.has(original):
		return cloned_shaders[original] as Shader
	var shader := Shader.new()
	# Retain every attribute, region hide mask, vertex motion, alpha and texture binding.
	# Only direct lighting and specular render modes are altered for this isolated study.
	var code := original.code.replace("specular_schlick_ggx", "specular_disabled")
	code = code.replace("diffuse_burley", "diffuse_lambert")
	code = code.replace(", sss_mode_skin", "")
	shader.code = code + "\n" + SOFT_LIGHT
	cloned_shaders[original] = shader
	return shader


func _camera_view(view: String) -> bool:
	for character: Dictionary in characters:
		(character.actor as Node3D).rotation.y = 0.0
	if view == "face":
		var skeleton := (characters[0].body as CharacterBodyMesh).skeleton
		var focus := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("headb"))).origin
		camera.global_position = focus + Vector3(0.14, 0.025, 1.05)
		camera.look_at(focus)
		return true
	if not VIEWS.has(view):
		failures.append("unknown view " + view)
		return false
	# Turn both characters in place, so the side view does not put one behind the other.
	var direction: Vector3 = VIEWS[view]
	for character: Dictionary in characters:
		(character.actor as Node3D).rotation.y = -atan2(direction.x, direction.z)
	var focus := Vector3(0, 0.9, 0)
	camera.global_position = focus + Vector3(0, 0.08, 1).normalized() * 5.15
	camera.look_at(focus)
	return true


func _capture(filename: String) -> void:
	print("drawing ", filename)
	await _frames(8)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output.path_join(filename + ".png")
	_check(image != null and image.save_png(path) == OK, "save " + filename)
	print("saved ", path)


func _verify_isolation() -> void:
	for character: Dictionary in characters:
		for entry: Dictionary in character.materials:
			var source := entry.material as ShaderMaterial
			_check(source.shader.code == String(entry.shader_code), "original shader preserved")
			var applied := (entry.mesh as MeshInstance3D).get_surface_override_material(int(entry.surface)) as ShaderMaterial
			_check(applied != source if current_mode != "current" else applied == source, "expected material isolation")
			if source.shader.code.contains("uniform uvec2 hide_mask"):
				_check(applied.get_shader_parameter("hide_mask") == source.get_shader_parameter("hide_mask"), "region hide mask preserved")


func _make_comparison(style := "soft_cel") -> void:
	var left := Image.load_from_file(output.path_join("current_three_quarter.png"))
	var right := Image.load_from_file(output.path_join(style + "_three_quarter.png"))
	if left == null or right == null:
		return
	var comparison := Image.create(left.get_width() * 2, left.get_height(), false, Image.FORMAT_RGBA8)
	left.convert(Image.FORMAT_RGBA8)
	right.convert(Image.FORMAT_RGBA8)
	comparison.blit_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i.ZERO)
	comparison.blit_rect(right, Rect2i(Vector2i.ZERO, right.get_size()), Vector2i(left.get_width(), 0))
	var name := "comparison.png" if style == "soft_cel" else "comparison_" + style + ".png"
	_check(comparison.save_png(output.path_join(name)) == OK, "comparison image")


func _finish() -> void:
	var report := {
		"study": "Tidebreak existing-character palette and soft cel preview",
		"inputs": ["characters/Actor_B.tscn", "assets/character/body/body.glb", "PlayerAppearance.arena_outfit"],
		"source_geometry_replaced": false, "shipping_defaults_changed": false,
		"palette": PALETTE, "checks": checks, "failures": Array(failures),
		"engine": Engine.get_version_info(),
		"limitations": "Existing character proportions and faces retained. This is an art-direction study, not exact BOTW parity or a retargeted rig.",
		"godot_docs": ["https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html", "https://docs.godotengine.org/en/4.7/classes/class_meshinstance3d.html"],
	}
	var file := FileAccess.open(output.path_join("preview_report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("CHARACTER STYLE PREVIEW DONE: %d checks" % checks if failures.is_empty() else "CHARACTER STYLE PREVIEW FAILED: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)
