extends SceneTree
## Measures the Actor_C grip / hang clips on the Actor_B rig (animations_extra/Actor_B_from_C.res) for PlayerGrip, into
## data/climb/climb_clips.json. The clips turn the bones only (the source game moved the body itself), so the grip
## system needs, per clip:
##   frame     "S" when the clip is authored lying on the surface (the surface is the clip's floor, the head along +Z),
##             "H" when it hangs upright facing the surface (the surface ahead at +Z), from where the hands are, at the
##             clip's start and end
##   standoff  the pelvis's distance from the surface (S: pelvis height over the contacts, H: the reach of the hand on
##             the surface ahead, the further forward of the two: in the one-hand clips, hang_atk_*, the other is free),
##             SAMPLES points over the clip
##   travel    how far the body goes (rig space, cumulative): the contacts that move least in a step are taken as
##             planted and the body moves the other way (the crawl speed, foot-locked)
##   hands / feet   the hands' and the feet's mean position at the start and the end (rig space)
##
##   Godot --headless --path . -s tools/climb/measure_clips.gd

const LIB := "res://animations_extra/Actor_B_from_C.res"
const OUT := "res://data/climb/climb_clips.json"
const SAMPLES := 17
const ENDS := ["l_middlec", "r_middlec", "l_ball", "r_ball"]
## Hands higher than this over the pelvis's floor: the clip hangs upright (H).
const HANG_HANDS_Y := 1.3


func _initialize() -> void:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(n)
	await process_frame
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := n.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := load(LIB) as AnimationLibrary
	ap.add_animation_library("c", lib)
	var clips := {}
	for a in lib.get_animation_list():
		var nm := "c/" + String(a)
		var an := ap.get_animation(nm)
		var standoff := []
		var travel := []
		var frames := []
		var hands := []
		var feet := []
		var prev := {}
		var cum := Vector3.ZERO
		for i in SAMPLES:
			ap.play(nm)
			ap.seek(an.length * float(i) / float(SAMPLES - 1), true)
			sk.force_update_all_bone_transforms()
			var cur := {}
			for e: String in ENDS:
				cur[e] = sk.get_bone_global_pose(sk.find_bone(e)).origin
			var h: Vector3 = (cur["l_middlec"] + cur["r_middlec"]) * 0.5
			var f: Vector3 = (cur["l_ball"] + cur["r_ball"]) * 0.5
			var kind := "H" if h.y > HANG_HANDS_Y else "S"
			frames.append(kind)
			if kind == "S":
				var ys := [cur["l_middlec"].y, cur["r_middlec"].y, cur["l_ball"].y, cur["r_ball"].y]
				ys.sort()
				standoff.append(snappedf(0.90 - (ys[0] + ys[1]) * 0.5, 0.001))
			else:
				standoff.append(snappedf(maxf(cur["l_middlec"].z, cur["r_middlec"].z) - 0.02, 0.001))
			if i > 0:
				var vs := []
				for e: String in ENDS:
					vs.append((cur[e] - prev[e]) as Vector3)
				vs.sort_custom(func(x: Vector3, y: Vector3) -> bool: return x.length() < y.length())
				cum -= (vs[0] + vs[1]) * 0.5
			travel.append([snappedf(cum.x, 0.001), snappedf(cum.y, 0.001), snappedf(cum.z, 0.001)])
			if i == 0 or i == SAMPLES - 1:
				hands.append([snappedf(h.x, 0.001), snappedf(h.y, 0.001), snappedf(h.z, 0.001)])
				feet.append([snappedf(f.x, 0.001), snappedf(f.y, 0.001), snappedf(f.z, 0.001)])
			prev = cur
		clips[String(a).trim_prefix("actor_c-")] = {
			"length": snappedf(an.length, 0.0001), "loop": an.loop_mode != Animation.LOOP_NONE,
			"frame": [frames[0], frames[SAMPLES - 1]], "frames": "".join(PackedStringArray(frames)),
			"standoff": standoff, "travel": travel, "hands": hands, "feet": feet}
	var out := {"library": "actor_b_from_c", "clip_prefix": "actor_c-", "samples": SAMPLES,
			"note": "Measured by tools/climb/measure_clips.gd on the Actor_B rig (skeleton space: +Y up, the body faces +Z).",
			"clips": clips}
	var fa := FileAccess.open(OUT, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, " ", true) + "\n")
	fa.close()
	print("measured %d clips -> %s" % [clips.size(), OUT])
	quit()
