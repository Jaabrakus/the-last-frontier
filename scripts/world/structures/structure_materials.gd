class_name StructureMaterials
extends RefCounted
## Shared materials for the fort (look-dev spec, section 8.1), built once per process from the
## processed textures in res://assets/environment/structures/textures (see
## tools/environment/structures/process_textures.py and SOURCES.md there).
##
##   StructureMaterials.get_material(&"boards")    -> ShaderMaterial (structure.gdshader)
##   StructureMaterials.all()                      -> {key: Material} for StructureMeshKit.commit()
##
## Keys:
##   bark       palisade-style bark: cabin log backs, flag pole, chopping block, firewood
##   bark_mm    the same for the palisade MultiMesh (per-log UV offset / tint / moss)
##   hewn_mm    hewn pale wood of the sharpened palisade tips (MultiMesh)
##   boards     weathered silvered timber: planks, hewn logs, crates, staves, doors (also clay
##              chinking, iron and end grain through the vertex kind)
##   shingles   riven shingle roofs
##   stone      fieldstone chimney
##   straw      straw trusses
##   flag       wool bunting (flag_cloth.gdshader)

const TEX := "res://assets/environment/structures/textures/"
const STRUCTURE_SHADER := "res://shaders/structures/structure.gdshader"
const FLAG_SHADER := "res://shaders/structures/flag_cloth.gdshader"

static var _cache := {}


static func all() -> Dictionary:
	for k: StringName in [&"bark", &"bark_mm", &"hewn_mm", &"boards", &"shingles", &"stone", &"straw", &"flag"]:
		get_material(k)
	return _cache


## Drops the cached materials (FrontierStructures._exit_tree). Without this the static cache
## outlives the RenderingServer at quit and Godot prints "RID allocations ... Shader ... leaked".
static func release() -> void:
	_cache.clear()


static func get_material(key: StringName) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material
	match key:
		&"bark", &"bark_mm":
			m = _structure("bark_palisade_albedo_2k.png", "bark_palisade_nor_gl_2k.jpg", "bark_palisade_arm_2k.jpg", {
				"normal_strength": 1.1, "specular_level": 0.35, "dirt_height": 0.45, "dirt_strength": 0.55,
				"streak_strength": 0.12, "moss_strength": 0.55, "lichen": 0.25, "bleach_strength": 0.22,
				"edge_wear": 0.0, "use_instance_custom": key == &"bark_mm", "instance_tint": 0.07,
			})
		&"hewn_mm":
			m = _structure("boards_weathered_albedo_2k.png", "boards_weathered_nor_gl_2k.png", "boards_weathered_arm_2k.png", {
				"tint": Color(0.86, 0.84, 0.81), "normal_strength": 1.0, "specular_level": 0.4, "dirt_strength": 0.0,
				"streak_strength": 0.18, "moss_strength": 0.0, "lichen": 0.3, "bleach_strength": 0.35,
				"edge_wear": 0.6, "use_instance_custom": true, "instance_tint": 0.06,
			})
		&"boards":
			m = _structure("boards_weathered_albedo_2k.png", "boards_weathered_nor_gl_2k.png", "boards_weathered_arm_2k.png", {
				"normal_strength": 1.0, "specular_level": 0.4, "dirt_height": 0.4, "dirt_strength": 0.5,
				"streak_strength": 0.22, "moss_strength": 0.3, "lichen": 0.35, "bleach_strength": 0.3,
				"edge_wear": 0.55,
			})
		&"shingles":
			m = _structure("shingles_riven_albedo_2k.png", "shingles_riven_nor_gl_2k.png", "shingles_riven_arm_2k.png", {
				"normal_strength": 1.0, "specular_level": 0.35, "dirt_strength": 0.0, "streak_strength": 0.0,
				"moss_strength": 0.0, "roof_moss": 0.55, "lichen": 0.5, "bleach_strength": 0.2, "edge_wear": 0.4,
				"texture_ao": 1.0,
			})
		&"stone":
			m = _structure("fieldstone_albedo_2k.png", "fieldstone_nor_gl_2k.jpg", "fieldstone_arm_2k.jpg", {
				"normal_strength": 1.2, "specular_level": 0.45, "dirt_height": 0.5, "dirt_strength": 0.45,
				"streak_strength": 0.25, "moss_strength": 0.45, "lichen": 0.5, "bleach_strength": 0.1,
				"edge_wear": 0.0, "roughness_offset": 0.05,
			})
		&"straw":
			m = _structure("straw_fibre_albedo_1k.png", "straw_fibre_nor_gl_1k.png", "straw_fibre_arm_1k.png", {
				"normal_strength": 1.2, "specular_level": 0.3, "dirt_height": 0.3, "dirt_strength": 0.45,
				"streak_strength": 0.15, "moss_strength": 0.0, "lichen": 0.0, "bleach_strength": 0.25,
				"edge_wear": 0.0,
			})
		&"flag":
			var f := ShaderMaterial.new()
			f.shader = load(FLAG_SHADER)
			f.set_shader_parameter(&"cloth_tex", load(TEX + "wool_twill_grey_512.png"))
			f.set_shader_parameter(&"cloth_normal", load(TEX + "wool_twill_nor_gl_512.png"))
			m = f
		_:
			push_warning("StructureMaterials: unknown key %s" % key)
			m = StandardMaterial3D.new()
	m.resource_name = "structure_" + String(key)
	_cache[key] = m
	return m


static func _structure(albedo: String, normal: String, arm: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(STRUCTURE_SHADER)
	m.set_shader_parameter(&"albedo_tex", load(TEX + albedo))
	m.set_shader_parameter(&"normal_tex", load(TEX + normal))
	m.set_shader_parameter(&"arm_tex", load(TEX + arm))
	m.set_shader_parameter(&"noise_tex", load(TEX + "structure_noise_512.png"))
	for k: String in params:
		m.set_shader_parameter(StringName(k), params[k])
	return m


## Standard materials for the dummies (their straw material must stay a StandardMaterial3D:
## TargetDummy flashes its albedo_color on hits).
static func dummy_textures() -> Dictionary:
	return {
		"straw": load(TEX + "straw_fibre_grey_1k.png"),
		"straw_normal": load(TEX + "straw_fibre_nor_gl_1k.png"),
		"wool": load(TEX + "wool_twill_grey_512.png"),
		"wool_normal": load(TEX + "wool_twill_nor_gl_512.png"),
		"boards": load(TEX + "boards_weathered_albedo_2k.png"),
		"boards_normal": load(TEX + "boards_weathered_nor_gl_2k.png"),
	}
