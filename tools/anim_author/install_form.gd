extends SceneTree
## Our own Form casts into the game (user 2026-10-02: "if we equip full metal alchemist type spells and animations that would be
## great"; the Sway's fifth art, Form: SwayCaster, FormCast): the clap and press to the ground, the release, and the press to an
## upright, keyed and IK-solved in Blender (tools/anim_author/blender/form_clips.py), become own-form-clap-press, own-form-release
## and own-form-press-wall in animations_extra/Frontier_Form.res: every keyed bone's rotation and the root's position (ToolPose
## "full" takes the root's place too: the squat; "upper" leaves the legs the game's), and each clip's moments as metas
## (clap_s, press_s, push_s, up_s, hold_s, back_s). SwayPose plays them over the game's pose (the Sway v2: every spell cast by
## its mastery: untrained the clap and press, practised own-sway-push-two, expert own-sway-push-one).
## The library is merged: the clips in the json are added (or replace their namesakes), the ones already there kept.
##   Blender -b --factory-startup --python tools/anim_author/blender/form_clips.py -- --out <form.json> [--clips a,b]
##   Godot --headless --path . -s tools/anim_author/install_form.gd -- <form.json>

const OUT_LIB := "res://animations_extra/Frontier_Form.res"
## A clip of the library the game's tracks are named like (their node path before the bone).
const REF_CLIP := "actor_b-p-relax-idle"
const NAMES := {"form_clap_press": "own-form-clap-press", "form_release": "own-form-release", "form_press_wall": "own-form-press-wall",
		"sway_push_two": "own-sway-push-two", "sway_push_one": "own-sway-push-one"}


func _initialize() -> void:
	var baked: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var ref := (load("res://animations/Actor_B.res") as AnimationLibrary).get_animation(REF_CLIP)
	var prefix := String(ref.track_get_path(0)).get_slice(":", 0)
	var fps := float(baked.fps)
	var lib: AnimationLibrary = null
	if ResourceLoader.exists(OUT_LIB):
		lib = (load(OUT_LIB) as AnimationLibrary).duplicate(true) as AnimationLibrary
	if lib == null:
		lib = AnimationLibrary.new()
	for key: String in baked.clips:
		var clip: Dictionary = baked.clips[key]
		var frames: Array = clip.frames
		var a := Animation.new()
		a.length = (frames.size() - 1) / fps
		a.loop_mode = Animation.LOOP_NONE
		a.set_meta(&"authored", "Frontier: our own Sway cast (%s), keyed and IK-solved in Blender (tools/anim_author/blender/form_clips.py)" % key)
		var meta: Dictionary = clip.get("meta", {})
		for m: String in meta:
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
				a.rotation_track_insert_key(tracks[bone], fi / fps, qq)
		var roots: Array = clip.get("root", [])
		if not roots.is_empty():
			var tp := a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(tp, NodePath(prefix + ":root"))
			for fi in roots.size():
				var p: Array = roots[fi]
				a.position_track_insert_key(tp, fi / fps, Vector3(p[0], p[1], p[2]))
		var name := String(NAMES.get(key, "own-" + key.replace("_", "-")))
		if lib.has_animation(StringName(name)):
			lib.remove_animation(StringName(name))
		lib.add_animation(StringName(name), a)
		print("  %s %.2f s, %d bones, metas %s" % [name, a.length, tracks.size(), str(meta)])
	print("FORM library: ", lib.get_animation_list())
	print("FORM saved ", ResourceSaver.save(lib, OUT_LIB, ResourceSaver.FLAG_COMPRESS), " -> ", OUT_LIB)
	quit()
