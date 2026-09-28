extends RefCounted
## Makes res://scenes/main.tscn resolve to a scene whose root runs preview_level.gd (the level
## with FrontierStructures), for this process only: a PackedScene takes over the path in the
## resource cache, so tools that call change_scene_to_file("res://scenes/main.tscn") load it.
## Nothing on disk changes. Used by the run_*.gd wrappers in this folder.

static var _scene: PackedScene


static func install() -> void:
	if _scene:
		return
	var script_path := "res://tools/environment/structures/preview/preview_level.gd"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level_script="):
			script_path = a.get_slice("=", 1)      # e.g. a patched copy of frontier_level.gd
	var root := Node3D.new()
	root.name = "Main"
	root.set_script(load(script_path))
	_scene = PackedScene.new()
	_scene.pack(root)
	root.free()
	_scene.take_over_path("res://scenes/main.tscn")
	print("PREVIEW main.tscn -> %s" % script_path)
