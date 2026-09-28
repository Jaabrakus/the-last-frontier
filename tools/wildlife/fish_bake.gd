extends SceneTree
## Bakes each fish species' body and skin (FishMesh, from data/world/fish.json "look") to assets/wildlife/fish/:
## <id>.res (the mesh) and <id>_skin.png. Headless:
##   Godot --headless --path . -s tools/wildlife/fish_bake.gd [-- only=<id>]
## Then --import (the skins).


func _initialize() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FishMesh.DIR))
	for id in FishSpecies.ids():
		if only != "" and id != only:
			continue
		var look: Dictionary = FishSpecies.spec(id).get("look", {})
		var t0 := Time.get_ticks_msec()
		var m := FishMesh.build(look)
		var err := ResourceSaver.save(m, FishMesh.DIR + id + ".res", ResourceSaver.FLAG_COMPRESS)
		var img := FishMesh.paint(look)
		img.clear_mipmaps()
		var err2 := img.save_png(ProjectSettings.globalize_path(FishMesh.DIR + id + "_skin.png"))
		print("%-12s %5d verts  mesh %s  skin %s  (%d ms)" % [id, m.surface_get_array_len(0), error_string(err), error_string(err2), Time.get_ticks_msec() - t0])
	print("FISH BAKE DONE")
	quit()
