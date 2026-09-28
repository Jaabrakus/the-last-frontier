extends SceneTree
## Writes the Actor_B rig's bones (name, parent, global rest position, local rest rotation) as JSON, for the
## Python retargets (tools/retarget/climb_from_c.py).
##   Godot --headless --path . -s tools/retarget/dump_rig_rest.gd -- <out.json>


func _initialize() -> void:
	var sc := load("res://characters/Actor_B.tscn") as PackedScene
	var n := sc.instantiate()
	root.add_child(n)
	await process_frame
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var out := []
	for b in sk.get_bone_count():
		var g := sk.get_bone_global_rest(b)
		var q := sk.get_bone_rest(b).basis.get_rotation_quaternion()
		out.append({"i": b, "name": sk.get_bone_name(b), "parent": sk.get_bone_parent(b),
				"pos": [g.origin.x, g.origin.y, g.origin.z], "rest_q": [q.x, q.y, q.z, q.w]})
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify({"skeleton": str(n.get_path_to(sk)), "bones": out}))
	f.close()
	print("dump_rig_rest: %d bones" % sk.get_bone_count())
	quit()
