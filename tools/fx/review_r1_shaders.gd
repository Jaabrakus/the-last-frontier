extends SceneTree
## Review round 1 probe (read-only): do the Cascade shaders (every imported effect through SpellFx.prewarm, i.e. the game's
## own materials, plus the lightning bolt shader on a real SbBolt) compile and draw without a shader or script error?
## Headless cannot answer this (the dummy renderer never compiles a shader). Windowed:
##   zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 -s tools/fx/review_r1_shaders.gd
## then grep the log for "ERROR|SHADER|Parse Error|WARNING".

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0, 1.5, 4)
	cam.current = true
	await process_frame
	var t0 := Time.get_ticks_msec()
	var ids := Array(SpellFx.effect_ids())
	print("REVIEW shaders: prewarm %d effects" % ids.size())
	await SpellFx.prewarm(ids, cam, Callable(), 4)
	print("  prewarm done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var lib := CascadeMaterials.shared()
	print("  materials built: family %d, uber %d, no record %d; shaders cached %d" % [lib.stats.family, lib.stats.uber, lib.stats.missing, lib._shader_cache.size()])

	# the lightning bolt shader on a real bolt (instance uniforms set the way BendLooks.SbBolt does)
	var bolt := BendLooks.SbBolt.new()
	root.add_child(bolt)
	bolt.strike(Vector3(-2, 1.5, 0), Vector3(2, 1.8, -1), 0.5, 3)
	for f in 40:
		await process_frame
	print("  SbBolt drawn: builds %d, on %s" % [bolt.builds, bolt.on])
	# every cascade shader file compiled on its own (family shaders that no emitter above uses)
	var seen := 0
	var dir := DirAccess.open("res://shaders/cascade/")
	var quad := QuadMesh.new()
	var holder := Node3D.new()
	root.add_child(holder)
	for f in dir.get_files():
		if not f.ends_with(".gdshader"):
			continue
		var sh := load("res://shaders/cascade/" + f) as Shader
		if sh == null:
			print("  FAIL could not load ", f)
			continue
		var m := ShaderMaterial.new()
		m.shader = sh
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = m
		mi.position = Vector3(0, 1.5, 0)
		holder.add_child(mi)
		seen += 1
	for f in 6:
		await process_frame
	print("  %d shader files drawn once" % seen)
	print("REVIEW shaders done")
	quit(0)
