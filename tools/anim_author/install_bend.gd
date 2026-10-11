extends SceneTree
## Our own ring-sport casts and knocks into the game (Tidebreak; the owner, 2026-10-04: "switch to a elemental avatar the last
## airbender type of game", the throw-style moves on new own throw clips only, every clip our own): the clips keyed and
## IK-solved in Blender by tools/anim_author/blender/bend_clips.py from the rig's own rest pose become own-bend-<element | throw
## | knock>-<name> in animations_extra/Frontier_Bend.res (a copy of install_form.gd's route): every keyed bone's rotation and the
## root's position (ToolPose "full" takes the root's place too: the stomp's drop, the bow stance), and each clip's moments as
## metas: strike_s (SwayPose's `struck`: the cast lets go, the foot or the fist lands, the hit), hold_s (where the game may hold
## it: the lock's wind-up, a knock while it lasts), back_s, up_s, and the strings hand (the striking limb), mask and root; a
## stance (meta loop "linear") is installed looping (LOOP_LINEAR), its meta loop kept.
## Nothing is read from another library: the bone track paths' node prefix is taken from our own Frontier_Form.res (the same
## skeleton path every own clip uses), and no native_asset_id, source_attribution or original_name is written.
## The library is merged: the clips in the json are added (or replace their namesakes), the ones already there kept.
##   zsh <scratchpad>/blender_run.sh -b --factory-startup --python tools/anim_author/blender/bend_clips.py -- --out <bend.json>
##       --blend <bend.blend>
##   Godot --headless --path . -s tools/anim_author/install_bend.gd -- <bend.json>      (or in=<bend.json>)
##       [out=res://artifacts/x/Frontier_Bend_try.res]   another library to install into (a bake to look at side by side with
##       the game's, tools/anim_author/bend_preview.gd lib=; it starts empty when it does not exist yet)

const OUT_LIB := "res://animations_extra/Frontier_Bend.res"
## Our own library whose tracks are named as the game's skeleton has them (the node path before the bone).
const PREFIX_LIB := "res://animations_extra/Frontier_Form.res"
const PREFIX_CLIP := "own-form-release"
const AUTHORED := "Frontier: our own ring-sport clip (%s), key poses keyed and IK-solved in Blender (tools/anim_author/blender/bend_clips.py) from the rig's rest pose"
## Metas that are words, not seconds (travel: the way a side roll rolls, "right" or "left"; stone_hand: the hand the Pop's
## stone ends in, "r"; from: the side a struck contact pose's hit comes from, "front", "back", "left" or "right").
const WORD_METAS := ["hand", "mask", "root", "loop", "travel", "stone_hand", "from"]


func _initialize() -> void:
	var path := ""
	var out_lib := OUT_LIB
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_lib = a.substr(4)
		else:
			path = a.trim_prefix("in=")
	if path == "" or not FileAccess.file_exists(path):
		push_error("install_bend: no json (%s)" % path)
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
		# (a clip baked several times a frame carries its own rate: bend_clips.py's substeps)
		var cfps := float(clip.get("fps", fps))
		a.length = (frames.size() - 1) / cfps
		a.loop_mode = Animation.LOOP_NONE
		a.set_meta(&"authored", AUTHORED % key)
		var meta: Dictionary = clip.get("meta", {})
		for m: String in meta:
			if m == "length_frames":
				continue
			if m == "loop":
				a.loop_mode = Animation.LOOP_LINEAR          # (an element's stance: an idle loop, its last frame its first)
			if m in WORD_METAS:
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
		var name := String(names.get(key, "own-bend-" + key.replace("_", "-")))
		if lib.has_animation(StringName(name)):
			lib.remove_animation(StringName(name))
		lib.add_animation(StringName(name), a)
		print("  %s %.2f s, %d bones, metas %s" % [name, a.length, tracks.size(), str(meta)])
	print("BEND library: ", lib.get_animation_list())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_lib.get_base_dir()))
	var err := ResourceSaver.save(lib, out_lib, ResourceSaver.FLAG_COMPRESS)
	print("BEND saved ", err, " -> ", out_lib)
	quit(0 if err == OK else 1)
