extends SceneTree
func _initialize():
	var bad := 0
	for dir in ["res://scripts/traversal", "res://scripts/traversal/markers", "res://tests/traversal", "res://tools/traversal", "res://scenes"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".gd"):
				var s = load(dir + "/" + f)
				if s == null or not (s as Script).can_instantiate():
					print("BAD ", dir, "/", f)
					bad += 1
	print("COMPILE CHECK ", "OK" if bad == 0 else "FAILED %d" % bad)
	quit(0)
