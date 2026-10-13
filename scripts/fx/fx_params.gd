class_name FxParams
## The effects' values per object (their shaders' instance uniforms: t, tint, seed, fade, own_fade ...), on every renderer.
## Forward+ and Mobile: set_instance_shader_parameter, as before. The Compatibility renderer (the web build, WebGL 2) keeps
## instance uniforms in one uniform buffer of 16 KB in Safari: 1024 values, 16 an object, so 64 objects in all, and the
## arena's pooled effects are hundreds (2026-10-13: the web build showed none, and an error for each). There the effects'
## shaders declare them as plain uniforms (#if CURRENT_RENDERER == RENDERER_COMPATIBILITY) and each object gets its own copy
## of its material the first time a value is set on it (made again when its material is changed for another).
##   FxParams.put(node, &"t", 0.4)

static var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"

const OWN := &"fx_params_own"


static func put(gi: GeometryInstance3D, param: StringName, value: Variant) -> void:
	if gi == null:
		return
	if not compat:
		gi.set_instance_shader_parameter(param, value)
		return
	for m in _own(gi):
		m.set_shader_parameter(param, value)


## The node's own materials (made the first time, and again when its material was changed since).
static func _own(gi: GeometryInstance3D) -> Array:
	var was: Array = gi.get_meta(OWN, [])
	if gi.material_override != null:
		if was.size() == 1 and gi.material_override == was[0]:
			return was
		var m := gi.material_override.duplicate() as Material
		gi.material_override = m
		gi.set_meta(OWN, [m])
		return [m]
	var mi := gi as MeshInstance3D
	if mi == null or mi.mesh == null:
		var mm := gi as MultiMeshInstance3D
		if mm != null and mm.multimesh != null and mm.multimesh.mesh != null and mm.multimesh.mesh.get_surface_count() > 0:
			var m := mm.multimesh.mesh.surface_get_material(0)
			if m != null:
				m = m.duplicate() as Material
				gi.material_override = m
				gi.set_meta(OWN, [m])
				return [m]
		return []
	var out := []
	var same := was.size() == mi.mesh.get_surface_count()
	for s in mi.mesh.get_surface_count():
		var cur := mi.get_surface_override_material(s)
		if same and cur != was[s]:
			same = false
	if same:
		return was
	for s in mi.mesh.get_surface_count():
		var src := mi.get_surface_override_material(s)
		if src == null:
			src = mi.mesh.surface_get_material(s)
		var m: Material = src.duplicate() as Material if src != null else null
		mi.set_surface_override_material(s, m)
		out.append(m)
	gi.set_meta(OWN, out)
	return out.filter(func(m: Variant) -> bool: return m != null)
