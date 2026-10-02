extends SceneTree
## Our own foraging grab into the game (user 2026-10-02: "we need to blender and animate our own foraging animation", "i just want
## it to be arms"): the one-arm reach and grab keyed and IK-solved in Blender (tools/anim_author/blender/forage_grab.py) becomes
## own-forage-grab-r and own-forage-grab-l, on the spine's, the head's and the arm's bones, in animations_extra/Frontier_Forage.res (meta "grab_s": the
## moment the fingers close). ForagePick plays one over the game's pose (ToolPose "reach_r" / "reach_l").
##   Blender -b --factory-startup --python tools/anim_author/blender/forage_grab.py -- --out <forage.json>
##   Godot --headless --path . -s tools/anim_author/install_forage.gd -- <forage.json>

const OUT_LIB := "res://animations_extra/Frontier_Forage.res"
## A clip of the library the game's tracks are named like (their node path before the bone).
const REF_CLIP := "actor_b-p-relax-idle"


func _initialize() -> void:
	var baked: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var ref := (load("res://animations/Actor_B.res") as AnimationLibrary).get_animation(REF_CLIP)
	var prefix := String(ref.track_get_path(0)).get_slice(":", 0)
	var fps := float(baked.fps)
	var lib := AnimationLibrary.new()
	for side: String in baked.clips:
		var frames: Array = baked.clips[side]
		var a := Animation.new()
		a.length = (frames.size() - 1) / fps
		a.loop_mode = Animation.LOOP_NONE
		a.set_meta(&"authored", "Frontier: our own reach and grab to one side, keyed and IK-solved in Blender (tools/anim_author/blender/forage_grab.py)")
		a.set_meta(&"grab_s", float(baked.grab_s))
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
		var name := "own-forage-grab-" + side
		lib.add_animation(StringName(name), a)
		print("  %s %.2f s, %d bones" % [name, a.length, tracks.size()])
	print("FORAGE saved ", ResourceSaver.save(lib, OUT_LIB, ResourceSaver.FLAG_COMPRESS), " -> ", OUT_LIB)
	quit()
