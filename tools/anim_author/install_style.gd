extends SceneTree
## A fighting style's own clips into the game (Tidebreak's fighting-style layer, docs/fighting_styles_design.md; the owner,
## 2026-10-08: each element keeps its moves and a style makes variations of them, "we need to watch videos on martial art
## styles and create animations for them"). The clips keyed and IK-solved in Blender by a style generator
## (tools/anim_author/blender/style_<style>.py, the first one style_boxing.py) become own-style-<style>-<name> in that
## style's own library, animations_extra/Frontier_Style_<Style>.res (install_bend.gd's route, unchanged): every keyed bone's
## rotation and the root's position, and each clip's moments as metas: strike_s (the fist lands, the bolt leaves), hold_s
## (where the game may hold it: the lock's wind-up), back_s (the recovery to the guard begins), antic_s and follow_s (the
## anticipation's and the follow-through's frames the stills show); words (hand, mask, root, loop, style, element, move,
## mode, ...) are kept as words. A stance (meta loop "linear") is installed looping.
## Nothing is read from another library: the bone track paths' node prefix is taken from our own Frontier_Form.res (the same
## skeleton path every own clip uses, as install_bend.gd does), and no native_asset_id, source_attribution or original_name
## is written. The library is merged: the clips in the json are added (or replace their namesakes), the others kept.
##   zsh tools/loop/blender_run.sh -b --factory-startup --python tools/anim_author/blender/style_boxing.py -- --out <boxing.json>
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/anim_author/install_style.gd -- in=<boxing.json>
##       [lib=res://animations_extra/Frontier_Style_Boxing.res]   (default: the json's own "library")

const PREFIX_LIB := "res://animations_extra/Frontier_Form.res"
const PREFIX_CLIP := "own-form-release"
const AUTHORED := "Frontier: our own %s clip (%s), key poses keyed and IK-solved in Blender (%s) from the rig's rest pose"


func _initialize() -> void:
	var path := ""
	var out_lib := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lib="):
			out_lib = a.trim_prefix("lib=")
		else:
			path = a.trim_prefix("in=")
	if path == "" or not FileAccess.file_exists(path):
		push_error("install_style: no json (%s)" % path)
		quit(1)
		return
	var baked: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if out_lib == "":
		out_lib = String(baked.get("library", ""))
	if not out_lib.begins_with("res://animations_extra/Frontier_Style_"):
		push_error("install_style: a style library is res://animations_extra/Frontier_Style_<Style>.res (%s)" % out_lib)
		quit(1)
		return
	var style := String(baked.get("style", "style"))
	var generator := String(baked.get("generator", "tools/anim_author/blender/style_%s.py" % style))
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
		var cfps := float(clip.get("fps", fps))
		a.length = (frames.size() - 1) / cfps
		a.loop_mode = Animation.LOOP_NONE
		a.set_meta(&"authored", AUTHORED % [style, key, generator])
		var meta: Dictionary = clip.get("meta", {})
		for m: String in meta:
			if m == "length_frames":
				continue
			if m == "loop":
				a.loop_mode = Animation.LOOP_LINEAR          # (the style's stance: an idle loop, its last frame its first)
			if meta[m] is String:
				a.set_meta(StringName(m), String(meta[m]))
			else:
				a.set_meta(StringName(m), float(meta[m]))
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
				a.rotation_track_insert_key(tracks[bone], fi / cfps, qq)
		var roots: Array = clip.get("root", [])
		if not roots.is_empty():
			var tp := a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(tp, NodePath(prefix + ":root"))
			for fi in roots.size():
				var p: Array = roots[fi]
				a.position_track_insert_key(tp, fi / cfps, Vector3(p[0], p[1], p[2]))
		var name := String(names.get(key, "own-style-%s-%s" % [style, key.replace("_", "-")]))
		if lib.has_animation(StringName(name)):
			lib.remove_animation(StringName(name))
		lib.add_animation(StringName(name), a)
		print("  %s %.2f s, %d bones, metas %s" % [name, a.length, tracks.size(), str(meta)])
	print("STYLE library: ", lib.get_animation_list())
	var err := ResourceSaver.save(lib, out_lib, ResourceSaver.FLAG_COMPRESS)
	print("STYLE saved ", err, " -> ", out_lib)
	quit(0 if err == OK else 1)
