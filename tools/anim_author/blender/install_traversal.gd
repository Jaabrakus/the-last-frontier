extends SceneTree
## Turns the authored traversal moves (tools/anim_author/blender/run.py ... bake) into game clips: each source part the authored span
## covers becomes a clip of ours on the same bones, its root in the clip's own space (the authored world root less the move's align,
## which the game adds back from traversal_runtime.json), and data/anim_author/traversal_clips.json maps the source clip to it
## (TravPreviewActor._anim_name, on by default; --source-traversal turns them off).
##   Godot --headless --path . -s tools/anim_author/blender/install_traversal.gd -- <baked.json>=<move_seq.json> [...]
## writes animations_extra/Frontier_Traversal.res (library frontier_traversal).

const OUT_LIB := "res://animations_extra/Frontier_Traversal.res"
const LIB_NAME := "frontier_traversal"
const MAP := "res://data/anim_author/traversal_clips.json"


func _initialize() -> void:
	var lib := load("res://animations/Actor_B.res") as AnimationLibrary
	# (merged into what is there: other moves' clips of ours stay)
	var out: AnimationLibrary = (load(OUT_LIB) as AnimationLibrary).duplicate(true) if ResourceLoader.exists(OUT_LIB) else AnimationLibrary.new()
	var old_map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP)) if FileAccess.file_exists(MAP) else {}
	var clips: Dictionary = (old_map.get("clips", {}) as Dictionary).duplicate()
	for arg in OS.get_cmdline_user_args():
		var baked_path := arg.get_slice("=", 0)
		var seq_path := arg.get_slice("=", 1)
		var baked: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(baked_path))
		var seq: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(seq_path))
		var t_a := float(baked.t_a)
		var t_b := t_a + float(baked.length)
		var parts: Array = seq.parts
		for pi in parts.size():
			var t0 := float(parts[pi].t0)
			var src := lib.get_animation(String(parts[pi].clip))
			var t1 := t0 + src.length
			if t0 < t_a - 1e-4 or t1 > t_b + 1e-4:
				continue
			var a := _part(baked, seq, src, t0, t1, t_a)
			var name := "own-" + String(parts[pi].clip).trim_prefix("actor_b-p-")
			if out.has_animation(StringName(name)):
				out.remove_animation(StringName(name))
			out.add_animation(StringName(name), a)
			clips[String(parts[pi].clip)] = LIB_NAME + "/" + name
			print("  ", parts[pi].clip, " -> ", name, " (%.2f s, %d tracks)" % [a.length, a.get_track_count()])
	print(ResourceSaver.save(out, OUT_LIB, ResourceSaver.FLAG_COMPRESS), " ", clips.size(), " clips")
	var f := FileAccess.open(MAP, FileAccess.WRITE)
	f.store_string(JSON.stringify({"about": "Our own traversal clips in place of the source's (tools/anim_author/blender/install_traversal.gd); played by default (--source-traversal for the source clips).",
			"libraries": {LIB_NAME: OUT_LIB}, "clips": clips}, "\t") + "\n")
	f.close()
	quit()


## The align (move time -> Vector3) from the native sequence's frames.
static func _align(seq: Dictionary, t: float) -> Vector3:
	var fr: Array = seq.frames
	var i := 0
	while i < fr.size() - 2 and float(fr[i + 1].t) <= t:
		i += 1
	var a: Array = fr[i].align
	var b: Array = fr[i + 1].align
	var d := float(fr[i + 1].t) - float(fr[i].t)
	var u := clampf((t - float(fr[i].t)) / d, 0.0, 1.0) if d > 1e-9 else 0.0
	return Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), u)


static func _part(baked: Dictionary, seq: Dictionary, src: Animation, t0: float, t1: float, t_a: float) -> Animation:
	var a := Animation.new()
	a.length = src.length
	a.loop_mode = Animation.LOOP_NONE
	for m in [&"native_asset_id", &"source_attribution", &"original_name"]:
		if src.has_meta(m):
			a.set_meta(m, src.get_meta(m))
	a.set_meta(&"authored", "Frontier: our own keyed move (tools/anim_author/blender/), on the source part's timing and bones")
	var frames: Array = baked.frames
	var prefix := String(src.track_get_path(0)).get_slice(":", 0)
	var root_t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(root_t, NodePath(prefix + ":root"))
	var rot_tracks := {}
	for ti in src.get_track_count():
		if src.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
			var b := String(src.track_get_path(ti).get_concatenated_subnames())
			var nt := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(nt, src.track_get_path(ti))
			rot_tracks[b] = nt
	var prev := {}
	for f in frames:
		var tm := t_a + float(f.t)                  # the move's time
		if tm < t0 - 1e-4 or tm > t1 + 1e-4:
			continue
		var lt := clampf(tm - t0, 0.0, a.length)
		var r: Array = f.root
		a.position_track_insert_key(root_t, lt, Vector3(r[0], r[1], r[2]) - _align(seq, tm))
		for b: String in rot_tracks:
			if not (f.rot as Dictionary).has(b):
				continue
			var q: Array = f.rot[b]
			var qq := Quaternion(q[0], q[1], q[2], q[3]).normalized()
			if prev.has(b) and (prev[b] as Quaternion).dot(qq) < 0.0:
				qq = -qq
			prev[b] = qq
			a.rotation_track_insert_key(rot_tracks[b], lt, qq)
	return a
