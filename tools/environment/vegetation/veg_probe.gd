extends SceneTree
## Package C development probe: loads the level, then replaces its "Vegetation" node with a
## freshly built one from `script=` (default res://scripts/world/vegetation/vegetation.gd) and
## prints the build statistics. Headless: colliders only (the headless build path).
##
##   Godot --headless --path . -s tools/environment/vegetation/veg_probe.gd -- [script=res://...] [repeat=3]

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var t_load := Time.get_ticks_usec()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	print("VEGPROBE level load %.0f ms" % ((Time.get_ticks_usec() - t_load) / 1000.0))
	var lvl := current_scene
	var old := lvl.get_node_or_null("Vegetation")
	if old and args.has("script"):
		old.name = "VegetationOld"
		lvl.remove_child(old)
		old.queue_free()
	var script: Script = load(String(args.get("script", "res://scripts/world/vegetation/vegetation.gd")))
	for k in int(args.get("repeat", "1")):
		var v: Node3D = script.new()
		v.name = "Vegetation" if k == 0 else "VegetationRepeat"
		var rng := RandomNumberGenerator.new()
		rng.seed = 1776
		var t0 := Time.get_ticks_usec()
		lvl.add_child(v)
		v.build(lvl.settings, rng)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("VEGPROBE build %.1f ms stats=%s" % [ms, JSON.stringify(v.get("stats"))])
		if k > 0:
			lvl.remove_child(v)
			v.free()
	await process_frame
	var shapes := 0
	var trunks := 0
	for n in lvl.get_node("Vegetation").find_children("*", "CollisionShape3D", true, false):
		shapes += 1
		if (n as CollisionShape3D).shape is CylinderShape3D and (n as CollisionShape3D).shape.height >= 3.0:
			trunks += 1
	print("VEGPROBE collision shapes=%d trunks>=3m=%d" % [shapes, trunks])
	print("VEGPROBE DONE")
	quit()
