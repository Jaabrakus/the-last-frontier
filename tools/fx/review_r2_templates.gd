extends SceneTree
## Review round 2 probe (read-only): every shader TEMPLATE (shaders/cascade/*.gdshader.txt, compiled at run time through
## CascadeMaterials._uber_shader with the render mode and alpha code of each blend mode) drawn once in every blend mode the
## importer's materials use, with default uniforms. Round 1 drew the 17 plain .gdshader files and the families the 81 imported
## effects use; the templates of families no imported material uses (texture_erode_base, toon_mesh_toonfx, translucent_soft,
## fire_simple_velocity's) and the blend modes no imported material uses were never drawn. Windowed (headless never compiles):
##   zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 -s tools/fx/review_r2_templates.gd
## then grep the log for "ERROR|SHADER|Parse Error|WARNING".

const BLENDS := ["BLEND_Translucent", "BLEND_Additive", "BLEND_AlphaComposite", "BLEND_Masked", "BLEND_Opaque"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0, 0, 4)
	cam.current = true
	await process_frame
	var lib := CascadeMaterials.shared()
	var quad := QuadMesh.new()
	var holder := Node3D.new()
	root.add_child(holder)
	var files: Array = []
	for f in DirAccess.get_files_at("res://shaders/cascade/"):
		if f.ends_with(".gdshader.txt"):
			files.append("res://shaders/cascade/" + f)
	files.append("")                                      # the uber shader itself
	var n := 0
	var seen := {}
	for path: String in files:
		for blend: String in BLENDS:
			for lit in ["MSM_Unlit", "MSM_DefaultLit"]:
				var rec := {"blend_mode": blend, "shading_model": lit, "two_sided": true}
				var sh: Shader = lib._uber_shader(rec, path)
				seen[sh] = true
				var m := ShaderMaterial.new()
				m.shader = sh
				var mi := MeshInstance3D.new()
				mi.mesh = quad
				mi.material_override = m
				mi.position = Vector3(float(n % 12) * 0.1 - 0.6, float(n / 12) * 0.1 - 0.5, 0.0)
				mi.scale = Vector3.ONE * 0.08
				holder.add_child(mi)
				n += 1
		print("  template %s: %d materials so far" % [path.get_file() if path != "" else "uber.gdshader.txt", n])
	for i in 8:
		await process_frame
	print("REVIEW templates: %d materials, %d distinct shaders drawn" % [n, seen.size()])
	quit(0)
