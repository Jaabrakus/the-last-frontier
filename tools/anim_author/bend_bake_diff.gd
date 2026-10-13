extends SceneTree
## A bake of tools/anim_author/blender/bend_clips.py (its json) against the installed animations_extra/Frontier_Bend.res: per
## clip the largest bone-rotation difference over its frames (deg), the root's (m), its length and its metas, so a re-bake can be
## shown to change only what it means to (the same script baked again must come out as installed). Read-only: nothing is saved.
##   Godot --headless --path . -s tools/anim_author/bend_bake_diff.gd -- <bend.json> [deg=0.05]
## Prints a line a clip that differs, "SAME <n>" for the rest, and BAKE DIFF DONE.

const LIB := "res://animations_extra/Frontier_Bend.res"
const PREFIX_LIB := "res://animations_extra/Frontier_Form.res"
const PREFIX_CLIP := "own-form-release"
## detail=1: a differing clip's worst bone printed frame by frame.
var detail := false


func _initialize() -> void:
	var path := ""
	var tol_deg := 0.1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("deg="):
			tol_deg = float(a.substr(4))
		elif a == "detail=1":
			detail = true
		else:
			path = a.trim_prefix("in=")
	if path == "" or not FileAccess.file_exists(path):
		push_error("bend_bake_diff: no json (%s)" % path)
		quit(1)
		return
	var baked: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var lib := load(LIB) as AnimationLibrary
	var ref := (load(PREFIX_LIB) as AnimationLibrary).get_animation(PREFIX_CLIP)
	var prefix := String(ref.track_get_path(0)).get_slice(":", 0)
	var fps := float(baked.fps)
	var names: Dictionary = baked.get("names", {})
	var same := 0
	var missing := 0
	for key: String in baked.clips:
		var clip: Dictionary = baked.clips[key]
		var name := String(names.get(key, "own-bend-" + key.replace("_", "-")))
		if not lib.has_animation(StringName(name)):
			print("NEW %s (not installed)" % name)
			missing += 1
			continue
		var a := lib.get_animation(StringName(name))
		var frames: Array = clip.frames
		var cfps := float(clip.get("fps", fps))
		var notes: Array[String] = []
		var length := (frames.size() - 1) / cfps
		if absf(length - a.length) > 1e-4:
			notes.append("length %.3f -> %.3f s" % [a.length, length])
		var worst := 0.0
		var worst_at := ""
		for bone: String in (frames[0] as Dictionary):
			var tr := a.find_track(NodePath(prefix + ":" + bone), Animation.TYPE_ROTATION_3D)
			if tr < 0:
				notes.append("no track %s" % bone)
				continue
			for fi in frames.size():
				var q: Array = frames[fi][bone]
				var qq := Quaternion(q[0], q[1], q[2], q[3]).normalized()
				var have: Quaternion = a.rotation_track_interpolate(tr, fi / cfps)
				var d := rad_to_deg(2.0 * acos(clampf(absf(have.normalized().dot(qq)), 0.0, 1.0)))
				if d > worst:
					worst = d
					worst_at = "%s f%d" % [bone, fi]
		var roots: Array = clip.get("root", [])
		var root_worst := 0.0
		var tp := a.find_track(NodePath(prefix + ":root"), Animation.TYPE_POSITION_3D)
		if tp >= 0:
			for fi in roots.size():
				var p: Array = roots[fi]
				var have_p: Vector3 = a.position_track_interpolate(tp, fi / cfps)
				root_worst = maxf(root_worst, have_p.distance_to(Vector3(p[0], p[1], p[2])))
		var meta: Dictionary = clip.get("meta", {})
		for m: String in meta:
			if m in ["length_frames", "loop"] or not (meta[m] is float or meta[m] is int):
				continue
			if not a.has_meta(StringName(m)) or absf(float(a.get_meta(StringName(m))) - float(meta[m])) > 1e-4:
				notes.append("meta %s %s -> %s" % [m, str(a.get_meta(StringName(m), "-")), str(meta[m])])
		if worst > tol_deg:
			notes.append("bones up to %.2f deg (%s)" % [worst, worst_at])
			if detail:
				# (the worst bone frame by frame: each version's step from the frame before, and the gap between them)
				var bone := worst_at.get_slice(" ", 0)
				var tr := a.find_track(NodePath(prefix + ":" + bone), Animation.TYPE_ROTATION_3D)
				var pa := Quaternion.IDENTITY
				var pb := Quaternion.IDENTITY
				for fi in frames.size():
					var q: Array = frames[fi][bone]
					var qb := Quaternion(q[0], q[1], q[2], q[3]).normalized()
					var qa: Quaternion = a.rotation_track_interpolate(tr, fi / cfps).normalized()
					var sa := rad_to_deg(2.0 * acos(clampf(absf(qa.dot(pa)), 0.0, 1.0))) if fi > 0 else 0.0
					var sb := rad_to_deg(2.0 * acos(clampf(absf(qb.dot(pb)), 0.0, 1.0))) if fi > 0 else 0.0
					var gap := rad_to_deg(2.0 * acos(clampf(absf(qa.dot(qb)), 0.0, 1.0)))
					print("   %s %s f%02d  installed step %6.2f  bake step %6.2f  gap %6.2f" % [name, bone, fi, sa, sb, gap])
					pa = qa
					pb = qb
		if root_worst > 0.001:
			notes.append("root up to %.4f m" % root_worst)
		if notes.is_empty():
			same += 1
		else:
			print("DIFF %s: %s" % [name, "; ".join(notes)])
	print("SAME %d of %d (%d not installed; tolerance %.2f deg, 1 mm)" % [same, baked.clips.size(), missing, tol_deg])
	print("BAKE DIFF DONE")
	quit(0)
