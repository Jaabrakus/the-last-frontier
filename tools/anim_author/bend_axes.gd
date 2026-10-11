extends SceneTree
## Each bone's own axis on the game's character skeleton (assets/character/actor_b_body.glb: the rig every own-bend clip is
## keyed on): the way from the bone to its child at the rest, in the bone's own frame, for tools/anim_author/bend_smoothness.py
## --axes (a bone's turn split into its swing, the bone's way moving, and its twist about itself).
##   Godot --headless --path . -s tools/anim_author/bend_axes.gd -- out=<axes.json>
## A bone with several children takes the one along its chain (the most distant one); a bone without a child is left out.

const GLB := "res://assets/character/actor_b_body.glb"


func _initialize() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var root := (load(GLB) as PackedScene).instantiate()
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var axes := {}
	for b in sk.get_bone_count():
		var best := Vector3.ZERO
		for c in sk.get_bone_children(b):
			var o := sk.get_bone_rest(c).origin
			if o.length() > best.length():
				best = o
		if best.length() > 1e-5:
			var n := best.normalized()
			axes[sk.get_bone_name(b)] = [n.x, n.y, n.z]
	# (each bone's rest rotation in its parent's frame, under "_rest": the hinge a knee or an elbow bends about is read off it)
	var rest := {}
	for b in sk.get_bone_count():
		var q := sk.get_bone_rest(b).basis.get_rotation_quaternion()
		rest[sk.get_bone_name(b)] = [q.x, q.y, q.z, q.w]
	axes["_rest"] = rest
	FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify(axes, "\t"))
	print("BEND AXES %d bones -> %s" % [axes.size(), out])
	root.free()
	quit(0)
