extends RefCounted
## Isolated reference-viewer overrides. Original materials, textures and mesh
## resources stay intact; the authored shading is not the source game's shader.
## Godot 4.7 spatial light() and MeshInstance3D surface overrides:
## https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html
## https://docs.godotengine.org/en/4.7/classes/class_meshinstance3d.html

const SHADER := preload("res://shaders/labs/reference_toon.gdshader")
const SOURCE_META := &"reference_toon_source_material"
static var _variants: Dictionary = {}


static func apply(body: CharacterBodyMesh) -> Dictionary:
	if body == null:
		return _empty_report("No reference body was supplied")
	return _apply_meshes(body.meshes)


## Also supports the actual source garment/arrow display stands.
static func apply_node(node: Node) -> Dictionary:
	if node == null:
		return _empty_report("No reference node was supplied")
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	return _apply_meshes(meshes)


static func _empty_report(error := "") -> Dictionary:
	return {"ok": error.is_empty(), "meshes": 0, "surfaces": 0, "skipped": 0,
		"source_files_modified": false, "source_materials_retained": true,
		"shading": "Authored lab-only three-band lighting; converted source albedo and UVs preserved",
		"surface_sources": [], "errors": [] if error.is_empty() else [error]}


static func _apply_meshes(meshes: Array) -> Dictionary:
	var report := _empty_report()
	for instance: MeshInstance3D in meshes:
		if not is_instance_valid(instance) or instance.mesh == null:
			continue
		var converted := 0
		for surface in instance.mesh.get_surface_count():
			var material := instance.get_active_material(surface)
			# Idempotent: recover the original rather than wrapping our own shader.
			if material != null and material.has_meta(SOURCE_META):
				material = material.get_meta(SOURCE_META) as Material
			var source := material as StandardMaterial3D
			if source == null:
				report.skipped += 1
				continue
			var replacement := _convert(source)
			# Keep each active material's exact source object; never mutate its mesh
			# surface or an imported resource shared with another character.
			instance.set_surface_override_material(surface, replacement)
			converted += 1
			report.surfaces += 1
			var texture := source.albedo_texture
			(report.surface_sources as Array).append({"mesh": String(instance.name),
				"mesh_resource": instance.mesh.resource_path, "surface": surface,
				"surface_name": instance.mesh.surface_get_name(surface),
				"material_name": source.resource_name, "material_resource": source.resource_path,
				"albedo_texture": texture.resource_path if texture != null else "",
				"albedo_texture_name": texture.resource_name if texture != null else "",
				"albedo_size": [texture.get_width(), texture.get_height()] if texture != null else [],
				"albedo_color": [source.albedo_color.r, source.albedo_color.g, source.albedo_color.b, source.albedo_color.a],
				"transparency": source.transparency, "cull_mode": source.cull_mode,
				"original_material_retained": true})
		if converted > 0:
			# Material override supersedes surface overrides; copying it per surface
			# above before clearing it preserves its effective original appearance.
			instance.material_override = null
			report.meshes += 1
	return report


static func _convert(source: StandardMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader_for(source)
	material.resource_name = source.resource_name + " · lab toon"
	material.render_priority = source.render_priority
	material.set_meta(SOURCE_META, source)
	material.set_shader_parameter("tint", source.albedo_color)
	material.set_shader_parameter("use_texture", source.albedo_texture != null)
	if source.albedo_texture != null:
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
	material.set_shader_parameter("use_vertex_color", source.vertex_color_use_as_albedo)
	material.set_shader_parameter("vertex_color_srgb", source.vertex_color_is_srgb)
	material.set_shader_parameter("use_uv2", false)
	material.set_shader_parameter("uv_scale", source.uv1_scale)
	material.set_shader_parameter("uv_offset", source.uv1_offset)
	material.set_shader_parameter("alpha_cutoff", source.alpha_scissor_threshold)
	material.set_shader_parameter("alpha_hash_scale", source.alpha_hash_scale)
	return material


static func _shader_for(source: StandardMaterial3D) -> Shader:
	var key := "%d/%d/%d/%s" % [source.cull_mode, source.transparency, source.texture_filter, source.texture_repeat]
	if _variants.has(key):
		return _variants[key] as Shader
	var code := SHADER.code
	var cull := "cull_back"
	if source.cull_mode == BaseMaterial3D.CULL_DISABLED:
		cull = "cull_disabled"
	elif source.cull_mode == BaseMaterial3D.CULL_FRONT:
		cull = "cull_front"
	code = code.replace("cull_back", cull)
	var alpha := ""
	match source.transparency:
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			# Cutouts remain in the opaque pipeline and cast their masked shadow.
			alpha = "if (sampled_albedo.a < alpha_cutoff) { discard; }"
		BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
			alpha = "ALPHA = sampled_albedo.a; ALPHA_HASH_SCALE = alpha_hash_scale;"
		BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			code = code.replace("specular_disabled;", "specular_disabled, depth_prepass_alpha;")
			alpha = "ALPHA = sampled_albedo.a;"
		BaseMaterial3D.TRANSPARENCY_ALPHA:
			alpha = "ALPHA = sampled_albedo.a;"
	code = code.replace("// REFERENCE_ALPHA_MODE", alpha)
	var filters := ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap", "filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
	code = code.replace("filter_linear_mipmap", String(filters[clampi(source.texture_filter, 0, filters.size() - 1)]))
	if not source.texture_repeat:
		code = code.replace("repeat_enable", "repeat_disable")
	var shader := Shader.new()
	shader.code = code
	_variants[key] = shader
	return shader
