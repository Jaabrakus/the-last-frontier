extends SceneTree
## Takes the mocap shake out of the traversal moves' clips (user 2026-09-30: "remove the little mocap jitters"): every part of the moves
## named, ours where data/anim_author/traversal_clips.json already has one (the hop), the source's otherwise, run through
## mocap_downgrade.gd's "dejitter" level (a light smoothing; each clip's first and last frames exactly kept, so the parts still meet).
## Written into animations_extra/Frontier_Traversal.res and mapped in traversal_clips.json (played by default; --source-traversal plays the source clips).
##   Godot --headless --path . -s tools/anim_author/polish_traversal.gd -- climb_hang_3m,climb_hang_3m_idle,vault_sprint
const MD := preload("res://tools/anim_author/mocap_downgrade.gd")
const LIB_PATH := "res://animations_extra/Frontier_Traversal.res"
const LIB_NAME := "frontier_traversal"
const MAP := "res://data/anim_author/traversal_clips.json"


func _initialize() -> void:
	var src_lib := load("res://animations/Actor_B.res") as AnimationLibrary
	var own: AnimationLibrary = (load(LIB_PATH) as AnimationLibrary) if ResourceLoader.exists(LIB_PATH) else AnimationLibrary.new()
	own = own.duplicate(true)
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP)) if FileAccess.file_exists(MAP) else {"clips": {}, "libraries": {}}
	var rt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/traversal/traversal_runtime.json"))
	var done := {}
	for move in str(OS.get_cmdline_user_args()[0]).split(","):
		for p: Dictionary in rt.moves[move].parts:
			var clip := String(p.clip)
			if done.has(clip):
				continue
			done[clip] = true
			var base: Animation
			var own_name := "own-" + clip.trim_prefix("actor_b-p-")
			var mapped := String((map.clips as Dictionary).get(clip, ""))
			if mapped != "" and own.has_animation(StringName(mapped.get_slice("/", 1))):
				base = own.get_animation(StringName(mapped.get_slice("/", 1)))
			else:
				base = src_lib.get_animation(clip)
			var a: Animation = MD.downgrade(base, "dejitter", false)
			if own.has_animation(StringName(own_name)):
				own.remove_animation(StringName(own_name))
			own.add_animation(StringName(own_name), a)
			map.clips[clip] = LIB_NAME + "/" + own_name
			print("  ", clip, " -> ", own_name, " (from ", "ours" if mapped != "" else "source", ")")
	map.libraries = {LIB_NAME: LIB_PATH}
	print(ResourceSaver.save(own, LIB_PATH, ResourceSaver.FLAG_COMPRESS))
	var f := FileAccess.open(MAP, FileAccess.WRITE)
	f.store_string(JSON.stringify(map, "\t") + "\n")
	f.close()
	quit()
