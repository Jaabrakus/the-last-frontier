extends SceneTree
## Review round 2 probe (read-only): memory the runtime holds for the imported effects: every spec parsed (SpellFx.spec keeps each
## for the session), materials.json, and the nodes of one prewarmed effect.
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/fx/review_r2_mem.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var m0 := OS.get_static_memory_usage()
	var json_bytes := 0
	var ids := Array(SpellFx.effect_ids())
	for id: String in ids:
		SpellFx.spec(id)
		json_bytes += FileAccess.get_file_as_bytes(SpellFx.SPECS + id + ".json").size()
	var m1 := OS.get_static_memory_usage()
	print("REVIEW mem: %d specs, %.1f MB of JSON -> %.1f MB held after SpellFx.spec() of each" % [ids.size(), json_bytes / 1e6, (m1 - m0) / 1e6])
	var lib := CascadeMaterials.shared()
	var m2 := OS.get_static_memory_usage()
	print("  CascadeMaterials.shared(): %.1f MB (materials.json, families, the uber source)" % [(m2 - m1) / 1e6])
	var wired := SbFx.ids()
	print("  (the bridge's own table read: %d effects listed with every element off)" % wired.size())
	# a parked (pooled) effect's draw nodes are hidden with it (top_level children keep the parent's visibility)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.current = true
	await process_frame
	var h := SpellFx.spawn("g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP", Vector3(0, 1, -3), {"scene": stage})
	for i in 5:
		await process_frame
	var fx := h.fx
	var drawn := 0
	for e in fx.emitters:
		for n in [e.mm_inst, e.ribbon_inst]:
			if n != null and (n as Node3D).is_visible_in_tree():
				drawn += 1
	h.kill()
	var after := 0
	var lights := 0
	for e in fx.emitters:
		for n in [e.mm_inst, e.ribbon_inst]:
			if n != null and (n as Node3D).is_visible_in_tree():
				after += 1
		for l in e.lights:
			if (l as Node3D).is_visible_in_tree():
				lights += 1
	print("  playing: %d draw nodes visible in the tree; parked: %d (and %d lights)" % [drawn, after, lights])
	quit(0)
