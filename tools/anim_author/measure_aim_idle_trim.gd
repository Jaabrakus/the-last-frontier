extends SceneTree
## The aim pitch tables (barrel elevation and yaw over the up / down weight) of the crouched aim idle's frozen pose
## (AimIdlePose; AnimGraphData.AIM_IDLE_POSES) for the aim trim's feed-forward, written to
## data/anim_author/aim_idle_pitch.json (AnimGraphData.apply_aim_idle_poses puts them over the metrics' own, which
## were measured on the old base clips).
##
##   Godot --headless --path . -s tools/anim_author/measure_aim_idle_trim.gd

const MC := preload("res://tools/anim_graph/measure_clips.gd")
const AimIdlePose := preload("res://scripts/player/anim/aim_idle_pose.gd")
const OUT := "res://data/anim_author/aim_idle_pitch.json"


func _initialize() -> void:
	await process_frame
	await process_frame
	var inst := (load(MC.RIG) as PackedScene).instantiate() as Node3D
	root.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	ap.stop()
	var rest: Dictionary = MC._ensure_rest(sk, ap)
	if not bool(rest.get("ok", false)):
		printerr("rest: ", rest.get("reason", "?"))
		quit(1)
		return
	var lib := ap.get_animation_library(MC.LIB)
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MC.DEFAULT_OUT))
	var hands := PackedStringArray(metrics.bone_sets.hands)
	var lower := PackedStringArray(metrics.bone_sets.lower)
	var out := {}
	for key: String in AnimGraphData.AIM_IDLE_POSES:
		var t: Dictionary = (MC.BUILTIN_AIM[key] as Dictionary).duplicate()
		var base := {"sample_clip": AnimGraphData.AIM_IDLE_POSES[key], "sample_s": AnimGraphData.AIM_IDLE_S,
				"legs_clip": AnimGraphData.AIM_IDLE_LEGS, "legs_s": AnimGraphData.AIM_IDLE_LEGS_S, "lift": AnimGraphData.AIM_IDLE_LIFT}
		base["upper_base_rest"] = sk.get_bone_rest(sk.find_bone("upper_base"))
		var pose: Animation = AimIdlePose.from_base(base, func(c: String) -> Animation: return lib.get_animation(c), lower)
		var name := "aimidle_" + key.replace("/", "_")
		lib.add_animation(name, pose)
		var old := MC._pitch_table(inst, ap, sk, lib, t, MC.BARREL_BONE.get(key.get_slice("/", 0), "r_hand_prop_attachment"), hands)
		t["base"] = name
		var p: Dictionary = MC._pitch_table(inst, ap, sk, lib, t, MC.BARREL_BONE.get(key.get_slice("/", 0), "r_hand_prop_attachment"), hands)
		if p.has("error"):
			printerr(key, ": ", p.error)
			quit(1)
			return
		p["base"] = base.sample_clip
		out[key] = p
		print("%s: zero elev %.1f -> %.1f, zero yaw %.1f -> %.1f" % [key, old.zero_elev_deg, p.zero_elev_deg, old.zero_yaw_deg, p.zero_yaw_deg])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"about": "Barrel pitch tables of the crouched aim idle's frozen pose (tools/anim_author/measure_aim_idle_trim.gd).",
			"tables": out}, "\t") + "\n")
	f.close()
	print("AIM IDLE TRIM OK")
	quit(0)
