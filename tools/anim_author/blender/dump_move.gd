extends SceneTree
## Dumps a whole traversal move from data/traversal/traversal_runtime.json as one continuous native sequence for the Blender tools:
## at every `step` seconds of the move's time, the part playing, every bone's local rotation and the root's position in the clip,
## the joints' skeleton-space positions, and the move's world effector tracks (traversal_runtime 'track'); plus the align (the
## world pelvis less the clip's pelvis), which the clips do not carry.
##   Godot --headless --path . -s tools/anim_author/blender/dump_move.gd -- move=vault_sprint out=<dir> [step=0.03333]
## writes <dir>/move_seq.json: {move, duration, fps, parts, frames: [{t, part, rot, loc, fk, world{}, align}]}
const JOINTS := ["pelvis", "spined", "headb", "l_palm", "r_palm", "l_elbow", "r_elbow", "l_knee", "r_knee", "l_ankle", "r_ankle", "l_ball", "r_ball"]
const POINTS := ["pelvis", "head_top", "l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee", "l_elbow", "r_elbow", "l_heel", "r_heel", "l_ball", "r_ball"]
var args := {}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
	var rt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/traversal/traversal_runtime.json"))
	var mv: Dictionary = rt.moves[str(args.move)]
	var track: Dictionary = mv.track
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := n.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	await process_frame
	await process_frame
	ap.speed_scale = 0.0
	var step := float(args.get("step", 1.0 / 30.0))
	var dur := float(mv.duration)
	var parts: Array = mv.parts
	var frames := []
	var k := 0
	while true:
		var t := minf(float(k) * step, dur)
		var pi := 0
		for i in parts.size():
			if t + 1e-4 >= float(parts[i].t0):
				pi = i
		var clip := "actor_b/" + String(parts[pi].clip)
		var a := ap.get_animation(clip)
		ap.play(clip)
		ap.seek(clampf(t - float(parts[pi].t0), 0.0, a.length), true)
		await process_frame
		sk.force_update_all_bone_transforms()
		var rots := {}
		var locs := {}
		for i in sk.get_bone_count():
			var q := sk.get_bone_pose_rotation(i)
			rots[sk.get_bone_name(i)] = [q.x, q.y, q.z, q.w]
			if sk.get_bone_name(i) == "root":
				var p := sk.get_bone_pose_position(i)
				locs["root"] = [p.x, p.y, p.z]
		var fk := {}
		for j in JOINTS:
			var o := sk.get_bone_global_pose(sk.find_bone(j)).origin
			fk[j] = [o.x, o.y, o.z]
		var world := {}
		var ti := clampi(int(round(t * float(track.hz))), 0, int(track.n) - 1)
		for p in POINTS:
			world[p] = [track[p][3 * ti], track[p][3 * ti + 1], track[p][3 * ti + 2]]
		var al := [world.pelvis[0] - fk.pelvis[0], world.pelvis[1] - fk.pelvis[1], world.pelvis[2] - fk.pelvis[2]]
		frames.append({"t": t, "part": pi, "rot": rots, "loc": locs, "fk": fk, "world": world, "align": al})
		if t >= dur:
			break
		k += 1
	var f := FileAccess.open(str(args.out).path_join("move_seq.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"move": args.move, "duration": dur, "fps": 1.0 / step, "parts": parts.map(func(p): return {"clip": p.clip, "t0": p.t0}), "frames": frames}))
	f.close()
	print("DUMPED ", frames.size(), " frames of ", args.move)
	quit()
