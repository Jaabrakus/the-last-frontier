class_name AssetLabWorld
extends Node3D
## Isolated comparison stage. Source terrain heights are attributed references;
## preview normalization, arena and prop placement are authored for this lab.

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const SOURCE_PATH := "res://artifacts/world_reference/terrain_sample/5000000000.hght"
const SOURCE_SHA256 := "dd9d671ac1b6d1c75c3675d85d9e9c923bdc7fe0f20633af81aa759bd500514c"
const SOURCE_WIDTH := 256
const MAP_WIDTH := 65
const HEIGHT_SPAN := 6.0
const ARENA_CENTER := Vector3(80.0, 0.0, 0.0)
const ARENA_SIZE := 20.0
const TEXTURE_MANIFEST := "res://artifacts/world_reference/world_textures/manifest.json"

var map_width := MAP_WIDTH
var terrain_heights := PackedFloat32Array()
var terrain_shape: HeightMapShape3D
var terrain_body: StaticBody3D
var report: Dictionary = {}
var _reference_textures: Dictionary = {}
var _texture_rows: Dictionary = {}
var _built := false


func build() -> Dictionary:
	if _built:
		return report
	_built = true
	name = "AssetLabWorld"
	_load_heights()
	_load_reference_textures()
	_build_terrain()
	_build_arena()
	_build_lighting()
	_build_props()
	_build_meadow_grass()
	_build_surround()
	_build_training_water()
	report["layout"] = "Independently arranged reference lab; no source map placements or verified world coordinates"
	return report


func spawn_at(area: String) -> Vector3:
	if not _built:
		build()
	if area == "arena":
		return to_global(ARENA_CENTER + Vector3(0.0, 0.25, 0.0))
	var point := Vector2(0.0, 8.0)
	return to_global(Vector3(point.x, height_at(point) + 0.25, point.y))


## Height on the drawn grid triangles, with one-metre cells centered at the origin.
func height_at(point: Vector2) -> float:
	if terrain_heights.is_empty():
		return 0.0
	var half := float(MAP_WIDTH - 1) * 0.5
	var gx := clampf(point.x + half, 0.0, float(MAP_WIDTH - 1))
	var gz := clampf(point.y + half, 0.0, float(MAP_WIDTH - 1))
	var x := mini(int(floor(gx)), MAP_WIDTH - 2)
	var z := mini(int(floor(gz)), MAP_WIDTH - 2)
	var fx := gx - float(x)
	var fz := gz - float(z)
	var a := terrain_heights[z * MAP_WIDTH + x]
	var b := terrain_heights[z * MAP_WIDTH + x + 1]
	var c := terrain_heights[(z + 1) * MAP_WIDTH + x]
	var d := terrain_heights[(z + 1) * MAP_WIDTH + x + 1]
	if fx + fz <= 1.0:
		return a + (b - a) * fx + (c - a) * fz
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


func _load_heights() -> void:
	terrain_heights.resize(MAP_WIDTH * MAP_WIDTH)
	terrain_heights.fill(0.0)
	var source := FileAccess.get_file_as_bytes(SOURCE_PATH)
	var source_loaded := source.size() == SOURCE_WIDTH * SOURCE_WIDTH * 2 and FileAccess.get_sha256(SOURCE_PATH) == SOURCE_SHA256
	var source_min := 65535
	var source_max := 0
	var crop_min := 65535
	var crop_max := 0
	var crop_start: int = SOURCE_WIDTH / 2 - (MAP_WIDTH - 1) / 2
	var crop := PackedInt32Array()
	if source_loaded:
		for i in SOURCE_WIDTH * SOURCE_WIDTH:
			var sample := int(source[i * 2]) | (int(source[i * 2 + 1]) << 8)
			source_min = mini(source_min, sample)
			source_max = maxi(source_max, sample)
		for z in MAP_WIDTH:
			for x in MAP_WIDTH:
				var offset := ((crop_start + z) * SOURCE_WIDTH + crop_start + x) * 2
				var sample := int(source[offset]) | (int(source[offset + 1]) << 8)
				crop.append(sample)
				crop_min = mini(crop_min, sample)
				crop_max = maxi(crop_max, sample)
		var span := maxf(float(crop_max - crop_min), 1.0)
		for i in crop.size():
			terrain_heights[i] = (float(crop[i]) - float(crop_min)) / span * HEIGHT_SPAN
	else:
		push_warning("Asset lab: local reference height sample is missing or does not match its retained SHA-256; using labelled flat fallback.")
	report["terrain"] = {"source_path": ProjectSettings.globalize_path(SOURCE_PATH), "source_sha256": SOURCE_SHA256,
		"source_loaded": source_loaded, "source_attribution": "Nintendo BOTW Wii U height sample; not newly authored terrain data",
		"source_width": SOURCE_WIDTH, "source_raw_min": source_min if source_loaded else null,
		"source_raw_max": source_max if source_loaded else null, "crop_start": [crop_start, crop_start],
		"crop_raw_min": crop_min if source_loaded else null, "crop_raw_max": crop_max if source_loaded else null,
		"map_width": MAP_WIDTH, "map_depth": MAP_WIDTH, "spacing_m": 1.0, "width_m": float(MAP_WIDTH - 1),
		"min_height": 0.0, "max_height": HEIGHT_SPAN if source_loaded and crop_max > crop_min else 0.0,
		"world_scale_verified": false, "world_registration_verified": false,
		"normalization": "Centered crop, locally normalized to 0..6 metres for movement comparison"}


func _load_reference_textures() -> void:
	report["texture_sources"] = []
	report["texture_fallback_roles"] = ["grass", "dirt", "stone", "bark", "leaf", "grass_blade"]
	report["texture_manifest"] = ProjectSettings.globalize_path(TEXTURE_MANIFEST)
	if not FileAccess.file_exists(TEXTURE_MANIFEST):
		report["texture_status"] = "Source texture manifest missing; authored/project materials are labelled fallback"
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXTURE_MANIFEST))
	if not parsed is Dictionary or not parsed.get("textures", null) is Array:
		report["texture_status"] = "Source texture manifest malformed; using labelled fallback"
		push_warning("Asset lab: source world texture manifest is malformed.")
		return
	var rows: Array = parsed.textures
	for value: Variant in rows:
		if not value is Dictionary:
			continue
		var row: Dictionary = value.duplicate(true)
		var role := String(row.get("role", ""))
		if role not in ["grass", "dirt", "stone", "bark", "leaf", "grass_blade", "grass_card"]:
			continue
		var path := String(row.get("output_png", ""))
		if not path.is_absolute_path() and not path.begins_with("res://"):
			path = TEXTURE_MANIFEST.get_base_dir().path_join(path)
		var expected := String(row.get("png_sha256", ""))
		var valid := not expected.is_empty() and FileAccess.file_exists(path) and FileAccess.get_sha256(path) == expected
		row["output_png"] = ProjectSettings.globalize_path(path)
		row["loaded"] = false
		row["material_usage"] = []
		row["attribution"] = "Nintendo BOTW decoded world texture; retained source name and hashes"
		if valid:
			var image := Image.new()
			var error := image.load(ProjectSettings.globalize_path(path))
			if error == OK and not image.is_empty():
				image.generate_mipmaps()
				_reference_textures[role] = ImageTexture.create_from_image(image)
				row["loaded"] = true
				row["width"] = image.get_width()
				row["height"] = image.get_height()
				(report.texture_fallback_roles as Array).erase(role)
		if not bool(row.loaded):
			row["error"] = "PNG missing, hash mismatch or decode failure; using labelled material fallback"
			push_warning("Asset lab: source world texture unavailable for role " + role)
		_texture_rows[role] = row
		(report.texture_sources as Array).append(row)
	report["texture_status"] = "Loaded %d verified decoded PNG roles; stage tiling and UV remapping are authored" % _reference_textures.size()


func _texture_usage(role: String, usage: String) -> void:
	if not _texture_rows.has(role) or not _reference_textures.has(role):
		return
	var row: Dictionary = _texture_rows[role]
	var uses: Array = row.material_usage
	if usage not in uses:
		uses.append(usage)


func _build_terrain() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var half := float(MAP_WIDTH - 1) * 0.5
	for z in MAP_WIDTH:
		for x in MAP_WIDTH:
			var index := z * MAP_WIDTH + x
			var dx := terrain_heights[z * MAP_WIDTH + mini(x + 1, MAP_WIDTH - 1)] - terrain_heights[z * MAP_WIDTH + maxi(x - 1, 0)]
			var dz := terrain_heights[mini(z + 1, MAP_WIDTH - 1) * MAP_WIDTH + x] - terrain_heights[maxi(z - 1, 0) * MAP_WIDTH + x]
			var normal := Vector3(-dx * 0.5, 1.0, -dz * 0.5).normalized()
			vertices.append(Vector3(float(x) - half, terrain_heights[index], float(z) - half))
			normals.append(normal)
			uv.append(Vector2(float(x), float(z)) / float(MAP_WIDTH - 1))
			# Mesh vertex RGB is linear; authored hex palettes are sRGB.
			var grass := Color("4e9136").srgb_to_linear().lerp(Color("88b545").srgb_to_linear(), terrain_heights[index] / HEIGHT_SPAN)
			colors.append(grass.lerp(Color("767765").srgb_to_linear(), clampf((0.82 - normal.y) * 2.0, 0.0, 1.0)))
	for z in MAP_WIDTH - 1:
		for x in MAP_WIDTH - 1:
			var a := z * MAP_WIDTH + x
			var b := a + 1
			var c := a + MAP_WIDTH
			var d := c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _terrain_material("Terrain map: authored slope/height blend and 2 m triplanar tiles")
	var visual := MeshInstance3D.new()
	visual.name = "ReferenceHeightTerrain"
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)
	terrain_shape = HeightMapShape3D.new()
	terrain_shape.map_width = MAP_WIDTH
	terrain_shape.map_depth = MAP_WIDTH
	terrain_shape.map_data = terrain_heights
	terrain_body = StaticBody3D.new()
	terrain_body.name = "ReferenceHeightCollision"
	terrain_body.collision_layer = 1
	var collision := CollisionShape3D.new()
	collision.shape = terrain_shape
	terrain_body.add_child(collision)
	add_child(terrain_body)


func _terrain_material(usage: String, only_stone := false) -> Material:
	if _reference_textures.is_empty():
		return _meadow_material()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/labs/reference_terrain.gdshader") as Shader
	material.set_shader_parameter("stone_only", only_stone)
	for role in ["grass", "dirt", "stone"]:
		if _reference_textures.has(role):
			material.set_shader_parameter(role + "_albedo", _reference_textures[role])
			material.set_shader_parameter("use_" + role, true)
			if role == "stone" or not only_stone:
				_texture_usage(role, usage)
	return material


func _meadow_material() -> Material:
	var shader_path := "res://shaders/labs/reference_toon.gdshader"
	if ResourceLoader.exists(shader_path):
		var material := ShaderMaterial.new()
		material.shader = load(shader_path) as Shader
		material.set_shader_parameter("use_vertex_color", true)
		material.set_shader_parameter("vertex_color_srgb", false)
		return material
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.roughness = 1.0
	return material


func _build_arena() -> void:
	_box("ArenaFloor", ARENA_CENTER + Vector3(0.0, -0.25, 0.0), Vector3(ARENA_SIZE, 0.5, ARENA_SIZE), Color("a9aaa3"), true)
	for i in range(-2, 3):
		_box("ArenaJointX%d" % i, ARENA_CENTER + Vector3(float(i) * 4.0, 0.005, 0.0), Vector3(0.035, 0.01, ARENA_SIZE), Color("777b78"), false)
		_box("ArenaJointZ%d" % i, ARENA_CENTER + Vector3(0.0, 0.005, float(i) * 4.0), Vector3(ARENA_SIZE, 0.01, 0.035), Color("777b78"), false)
	for side in [-1.0, 1.0]:
		_box("ArenaBoundaryX", ARENA_CENTER + Vector3(side * 10.0, 0.65, 0.0), Vector3(0.5, 1.3, 20.5), Color("757e78"), true)
		_box("ArenaBoundaryZ", ARENA_CENTER + Vector3(0.0, 0.65, side * 10.0), Vector3(20.5, 1.3, 0.5), Color("757e78"), true)
	report["arena"] = {"center": [80.0, 0.0, 0.0], "width_m": ARENA_SIZE, "depth_m": ARENA_SIZE,
		"floor_height": 0.0, "attribution": "Project-authored primitive lab floor and boundaries", "connection": "Teleport between areas"}


func _box(node_name: String, center: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var root_node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root_node.name = node_name
	root_node.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	if _reference_textures.has("stone") and (node_name == "ArenaFloor" or node_name.begins_with("ArenaBoundary") or node_name.ends_with("Basin") or node_name.begins_with("WaterRim")):
		visual.material_override = _terrain_material("Authored arena floor/boundaries and water basins: 2 m triplanar stone tiles", true)
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.88
		visual.material_override = material
	root_node.add_child(visual)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		root_node.add_child(collision)
	add_child(root_node)
	return root_node


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6e9bc4")
	sky_material.sky_horizon_color = Color("cfdee5")
	sky_material.ground_bottom_color = Color("6d7967")
	sky_material.ground_horizon_color = Color("cfdee5")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e1eaf3")
	environment.ambient_light_energy = 0.28
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "LabSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("fff1d8")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	report["presentation"] = {"ambient_energy": 0.28, "sun_energy": 0.8, "tonemapper": "Filmic",
		"vertex_palette_space": "sRGB palette converted to linear mesh RGB", "look": "Authored green meadow palette and banded shading; not an extracted source shader"}


func _build_props() -> void:
	var rows: Array[Dictionary] = []
	var tree_points: Array[Vector2] = [Vector2(-17.0, -14.0), Vector2(14.0, -10.0), Vector2(-13.0, 19.0), Vector2(19.0, 16.0)]
	for i in tree_points.size():
		var point := tree_points[i]
		var mesh := Assets.tree_mesh(Assets.SAPLING_BIRCH, i % 3, 0)
		if mesh == null:
			continue
		var visual := MeshInstance3D.new()
		visual.name = "ProjectBirch%d" % i
		visual.mesh = mesh
		visual.material_override = _painted_tree_material(Assets.BIRCH)
		visual.position = Vector3(point.x, height_at(point), point.y)
		visual.rotation.y = float(i) * 1.2
		add_child(visual)
		rows.append({"kind": "tree", "source": "res://assets/environment/vegetation/trees/sapling_birch.glb",
			"attribution": "Existing project procedural vegetation; see assets/environment/vegetation/SOURCES.md", "variant": i % 3})
	var mature_points: Array[Vector2] = [Vector2(-25.0, -23.0), Vector2(-14.0, -25.0), Vector2(3.0, -27.0),
		Vector2(19.0, -24.0), Vector2(27.0, -13.0), Vector2(27.0, 4.0), Vector2(25.0, 22.0),
		Vector2(13.0, 27.0), Vector2(-3.0, 26.0), Vector2(-19.0, 25.0), Vector2(-27.0, 12.0),
		Vector2(-27.0, -5.0), Vector2(15.0, -15.0), Vector2(-17.0, -16.0)]
	var mature_kinds: Array[int] = [Assets.OAK, Assets.BIRCH, Assets.OAK, Assets.HEMLOCK]
	for i in mature_points.size():
		var point := mature_points[i]
		var kind := mature_kinds[i % mature_kinds.size()]
		var mesh := Assets.tree_mesh(kind, i % 3, 0)
		if mesh == null:
			continue
		var visual := MeshInstance3D.new()
		visual.name = "ProjectCanopy%d" % i
		visual.mesh = mesh
		visual.material_override = _painted_tree_material(kind)
		visual.position = Vector3(point.x, height_at(point), point.y)
		visual.rotation.y = float(i) * 1.7
		visual.scale = Vector3.ONE * (0.55 + float(i % 3) * 0.055)
		add_child(visual)
		rows.append({"kind": "tree", "source": "res://assets/environment/vegetation/trees/%s.glb" % Assets.SPECIES[kind],
			"attribution": "Existing project procedural vegetation; see assets/environment/vegetation/SOURCES.md", "variant": i % 3,
			"presentation": "Lab-only painted material and scale"})
	var rock_points: Array[Vector2] = [Vector2(-9.0, 11.0), Vector2(9.0, -8.0), Vector2(22.0, -16.0)]
	for i in rock_points.size():
		var point := rock_points[i]
		var kind: int = 2 + i
		var mesh := Assets.prop_mesh(kind, 0)
		if mesh == null:
			continue
		var body := StaticBody3D.new()
		body.name = "ProjectRock%d" % i
		body.position = Vector3(point.x, height_at(point) - 0.08, point.y)
		body.rotation.y = float(i) * 0.7
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = _terrain_material("Existing project rock shapes: 2 m triplanar source stone tiles", true) if _reference_textures.has("stone") else Assets.prop_material(kind)
		body.add_child(visual)
		var collision := CollisionShape3D.new()
		collision.shape = mesh.create_convex_shape()
		body.add_child(collision)
		add_child(body)
		rows.append({"kind": "rock", "source": "res://assets/environment/props/rock_moss_set_01/rock_moss_set_01.glb",
			"attribution": "Existing project processed Poly Haven prop; see assets/environment/props/SOURCES.md", "variant": kind})
	report["props"] = rows


func _painted_tree_material(kind: int) -> ShaderMaterial:
	# Duplicate shared materials so this comparison cannot alter production foliage.
	if _reference_textures.has("bark") and _reference_textures.has("leaf"):
		var material := Assets.tree_material(kind).duplicate() as ShaderMaterial
		material.shader = load("res://shaders/labs/reference_tree.gdshader") as Shader
		material.set_shader_parameter("bark_albedo", _reference_textures.bark)
		material.set_shader_parameter("leaf_albedo", _reference_textures.leaf)
		material.set_shader_parameter("project_leaf_mask", Assets.tex(Assets.VEG_DIR + "foliage/foliage_albedo.png"))
		_texture_usage("bark", "Existing project tree shapes: source bark on retained tiling trunk UVs")
		_texture_usage("leaf", "Existing project tree shapes: source RGB remapped to two upper atlas islands; current project alpha mask retained")
		return material
	var material := Assets.painted_tree_material(kind).duplicate() as ShaderMaterial
	material.set_shader_parameter("leaf_fall", 0.0)
	material.set_shader_parameter("tone_saturation", 1.0)
	material.set_shader_parameter("texture_keep", 0.06)
	material.set_shader_parameter("top_warm_amount", 0.10)
	return material


func _build_meadow_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 940065
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var clusters := 0
	for i in 2600:
		var point := Vector2(rng.randf_range(-30.5, 30.5), rng.randf_range(-30.5, 30.5))
		# Keep the immediate player spawn visually readable; grass is non-colliding.
		if point.distance_to(Vector2(0.0, 8.0)) < 1.3 or point.distance_to(Vector2(-6.0, 6.0)) < 1.9:
			continue
		var center := Vector3(point.x, height_at(point) + 0.005, point.y)
		var tint := Color("36772a").srgb_to_linear().lerp(Color("77aa39").srgb_to_linear(), rng.randf())
		for blade in 3:
			var angle := rng.randf_range(0.0, TAU)
			var across := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.025, 0.045)
			var height := rng.randf_range(0.16, 0.32)
			var lean := Vector3(sin(angle), 0.0, cos(angle)) * height * 0.25
			var base := vertices.size()
			vertices.append_array(PackedVector3Array([center - across, center + across,
				center - across * 0.22 + Vector3.UP * height + lean,
				center + across * 0.22 + Vector3.UP * height + lean]))
			uv.append_array(PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0)]))
			for vertex in 4:
				normals.append(Vector3.UP)
				colors.append(tint * (0.75 if vertex < 2 else 1.0))
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2,
				base + 2, base + 1, base, base + 2, base + 3, base + 1]))
		clusters += 1
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.name = "AuthoredMeadowTufts"
	visual.mesh = mesh
	if _reference_textures.has("grass_blade"):
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/labs/reference_toon.gdshader") as Shader
		material.set_shader_parameter("use_texture", true)
		material.set_shader_parameter("albedo_texture", _reference_textures.grass_blade)
		visual.material_override = material
		_texture_usage("grass_blade", "Project-authored grass blades: explicit per-blade UVs map the complete source GrassAlb image")
	else:
		visual.material_override = _meadow_material()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	report["grass"] = {"clusters": clusters, "blades_per_cluster": 3, "collision": false,
		"attribution": "Project-authored procedural lab grass geometry and placement"}


func _build_surround() -> void:
	# Presentation only: these independent silhouettes are not source map heights.
	var ground := MeshInstance3D.new()
	ground.name = "AuthoredBackdropGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(650.0, 650.0)
	ground.mesh = plane
	ground.position.y = -0.6
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("56843b")
	ground_material.roughness = 1.0
	ground.material_override = _terrain_material("Authored backdrop ground/hills: slope/height blend and 2 m triplanar tiles") if _reference_textures.has("grass") else ground_material
	add_child(ground)
	var hills: Array[Dictionary] = [
		{"center": Vector3(-90.0, -10.0, -85.0), "scale": Vector3(70.0, 21.0, 50.0)},
		{"center": Vector3(30.0, -9.0, -125.0), "scale": Vector3(90.0, 24.0, 65.0)},
		{"center": Vector3(150.0, -12.0, 25.0), "scale": Vector3(65.0, 23.0, 80.0)},
		{"center": Vector3(-120.0, -11.0, 65.0), "scale": Vector3(80.0, 22.0, 60.0)},
	]
	for i in hills.size():
		var hill := MeshInstance3D.new()
		hill.name = "AuthoredBackdropHill%d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 32
		sphere.rings = 16
		hill.mesh = sphere
		hill.position = hills[i].center
		hill.scale = hills[i].scale
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("568052").lerp(Color("75906a"), float(i) * 0.15)
		material.roughness = 1.0
		hill.material_override = _terrain_material("Authored backdrop ground/hills: slope/height blend and 2 m triplanar tiles") if _reference_textures.has("grass") else material
		add_child(hill)
	report["surround"] = {"collision": false, "ground_width_m": 650.0, "hills": 4,
		"attribution": "Project-authored primitive backdrop; not extracted terrain or a playable continuation"}


func _build_training_water() -> void:
	var map_point := Vector2(-6.0, 6.0)
	var definitions: Array[Dictionary] = [
		{"name": "MapTrainingWater", "position": Vector3(map_point.x, height_at(map_point), map_point.y), "reach_m": 50.0},
		{"name": "ArenaTrainingWater", "position": Vector3(88.0, 0.0, -6.0), "reach_m": 25.0},
	]
	for definition in definitions:
		var center: Vector3 = definition.position
		_box(String(definition.name) + "Basin", center + Vector3(0.0, 0.04, 0.0), Vector3(2.0, 0.08, 2.4), Color("778b8f"), true)
		for side in [-1.0, 1.0]:
			_box("WaterRimX", center + Vector3(side * 0.9, 0.16, 0.0), Vector3(0.2, 0.24, 2.4), Color("8a989a"), true)
			_box("WaterRimZ", center + Vector3(0.0, 0.16, side * 1.1), Vector3(1.6, 0.24, 0.2), Color("8a989a"), true)
		var pool := Node3D.new()
		pool.name = String(definition.name)
		pool.position = center + Vector3(0.0, 0.14, 0.0)
		pool.set_meta(&"reach_m", float(definition.reach_m))
		pool.add_to_group(Bending.POOLS)
		var visual := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(1.6, 2.0)
		visual.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("4098bb")
		material.metallic = 0.15
		material.roughness = 0.22
		visual.material_override = material
		pool.add_child(visual)
		add_child(pool)
	report["training_water"] = {"map_reach_m": 50.0, "arena_reach_m": 25.0,
		"group": String(Bending.POOLS), "attribution": "Project-authored visible training basins; extended reach supports lab water casts"}
