extends SceneTree
## Chosen Motifect moves into the game (the owner, 2026-10-12: "we can take some moves and then add it into our own"; animations/
## SOURCE.md "Motifect-derived clips"): the clips tools/anim_author/blender/motifect_clips.py retargeted from the Motifect martial
## arts pack onto Actor_B's rig and cut to the cast shape become motifect-<name> in their own library,
## animations_extra/Frontier_Motifect.res (BendPoses.MOTIFECT_LIBRARY: a pose plays one only as data/bending/poses.json lists it
## by name in "motifect"). install_bend.gd's route: every keyed bone's rotation and the root's place, the clip's moments and
## words as metas; its `authored` meta says what made it and its `source` meta what it was made from (the pack's clip and
## frames), so the library itself records the lineage. Nothing else is read but our own Frontier_Form.res for the track paths'
## node prefix. The library is merged: the json's clips added or replacing their namesakes, the rest kept.
##   blender -b --factory-startup -P tools/anim_author/blender/motifect_clips.py -- --out <motifect.json>
##   Godot --headless --path . -s tools/anim_author/install_motifect.gd -- <motifect.json> [out=res://...]

const OUT_LIB := "res://animations_extra/Frontier_Motifect.res"
const PREFIX_LIB := "res://animations_extra/Frontier_Form.res"
const PREFIX_CLIP := "own-form-release"
const AUTHORED := "Frontier: a Motifect move (%s) retargeted onto Actor_B's rig and cut to the cast shape by tools/anim_author/blender/motifect_clips.py (animations/SOURCE.md)"
const WORD_METAS := ["hand", "mask", "root", "loop", "travel", "source"]


func _initialize() -> void:
	var path := ""
	var out_lib := OUT_LIB
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_lib = a.substr(4)
		else:
			path = a.trim_prefix("in=")
	if path == "" or not FileAccess.file_exists(path):
		push_error("install_motifect: no json (%s)" % path)
		quit(1)
		return
	var baked: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var ref := (load(PREFIX_LIB) as AnimationLibrary).get_animation(PREFIX_CLIP)
	var prefix := String(ref.track_get_path(0)).get_slice(":", 0)
	var fps := float(baked.fps)
	var names: Dictionary = baked.get("names", {})
	var lib: AnimationLibrary = null
	if ResourceLoader.exists(out_lib):
		lib = (load(out_lib) as AnimationLibrary).duplicate(true) as AnimationLibrary
	if lib == null:
		lib = AnimationLibrary.new()
	for key: String in baked.clips:
		var clip: Dictionary = baked.clips[key]
		var frames: Array = clip.frames
		var a := Animation.new()
		a.length = (frames.size() - 1) / fps
		a.loop_mode = Animation.LOOP_NONE
		a.set_meta(&"authored", AUTHORED % key)
		var meta: Dictionary = clip.get("meta", {})
		for m: String in meta:
			if m == "length_frames":
				continue
			var v: Variant = meta[m]
			if m in WORD_METAS:
				if v is bool:
					a.set_meta(StringName(m), bool(v))
				else:
					a.set_meta(StringName(m), String(v))
			else:
				a.set_meta(StringName(m), float(v))
		var tracks := {}
		var prev := {}
		for fi in frames.size():
			var rots: Dictionary = frames[fi]
			for bone: String in rots:
				if not tracks.has(bone):
					var tr := a.add_track(Animation.TYPE_ROTATION_3D)
					a.track_set_path(tr, NodePath(prefix + ":" + bone))
					tracks[bone] = tr
				var q: Array = rots[bone]
				var qq := Quaternion(q[0], q[1], q[2], q[3]).normalized()
				if prev.has(bone) and (prev[bone] as Quaternion).dot(qq) < 0.0:
					qq = -qq
				prev[bone] = qq
				a.rotation_track_insert_key(tracks[bone], fi / fps, qq)
		var roots: Array = clip.get("root", [])
		if not roots.is_empty():
			var tp := a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(tp, NodePath(prefix + ":root"))
			for fi in roots.size():
				var p: Array = roots[fi]
				a.position_track_insert_key(tp, fi / fps, Vector3(p[0], p[1], p[2]))
		var name := String(names.get(key, "motifect-" + key.replace("_", "-")))
		if lib.has_animation(StringName(name)):
			lib.remove_animation(StringName(name))
		lib.add_animation(StringName(name), a)
		print("  %s %.2f s, %d bones, metas %s" % [name, a.length, tracks.size(), str(meta)])
	print("MOTIFECT library: ", lib.get_animation_list())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_lib.get_base_dir()))
	var err := ResourceSaver.save(lib, out_lib, ResourceSaver.FLAG_COMPRESS)
	print("MOTIFECT saved ", err, " -> ", out_lib)
	quit(0 if err == OK else 1)
