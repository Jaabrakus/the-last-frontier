extends SceneTree
## Dumps a library clip sampled at given times: every bone's local rotation and the root's position, and the skeleton-space
## positions of some joints (forward kinematics on the real rig), as JSON for the Blender tools.
##   Godot --headless --path . -s tools/anim_author/blender/dump_pose.gd -- clip=<name> times=0,0.5,1 out=/path/x.json [lib=res://animations/Actor_B.res]
const JOINTS := ["pelvis", "spined", "headb", "l_palm", "r_palm", "l_elbow", "r_elbow", "l_knee", "r_knee", "l_ankle", "r_ankle", "l_ball", "r_ball"]
var args := {}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := n.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var libname := "actor_b"
	if args.has("lib"):
		ap.add_animation_library("dump", load(str(args.lib)) as AnimationLibrary)
		libname = "dump"
	await process_frame
	await process_frame
	ap.speed_scale = 0.0
	var clip := libname + "/" + str(args.clip)
	var frames := []
	for ts in str(args.times).split(",", false):
		var t := float(ts)
		ap.play(clip)
		ap.seek(t, true)
		await process_frame
		sk.force_update_all_bone_transforms()
		var rots := {}
		var locs := {}
		for i in sk.get_bone_count():
			var q := sk.get_bone_pose_rotation(i)
			rots[sk.get_bone_name(i)] = [q.x, q.y, q.z, q.w]
			var p := sk.get_bone_pose_position(i)
			locs[sk.get_bone_name(i)] = [p.x, p.y, p.z]
		var fk := {}
		for j in JOINTS:
			var o := sk.get_bone_global_pose(sk.find_bone(j)).origin
			fk[j] = [o.x, o.y, o.z]
		frames.append({"t": t, "rot": rots, "loc": locs, "fk": fk})
	var f := FileAccess.open(str(args.out), FileAccess.WRITE)
	f.store_string(JSON.stringify({"clip": args.clip, "frames": frames}))
	f.close()
	print("DUMPED ", frames.size(), " frames")
	quit()
