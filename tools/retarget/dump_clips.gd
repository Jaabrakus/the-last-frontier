extends SceneTree
## Dumps skeleton rests, bind-pose candidate clips and selected clips of an actor's
## AnimationLibrary to JSON for tools/retarget/retarget.py. Read-only: nothing in the
## library or the game is changed.
##
##   Godot --headless --path <Player_Animation_Project>/godot_export \
##       -s <Frontier>/tools/retarget/dump_clips.gd -- \
##       actor=Actor_A clips=<a,b,c | @file> out=<json> [fps=30] [rig_only=1]
##       actor=Actor_A every=6 out=<json>      (bind-pose probe sample: every 6th clip,
##                                              frames at t = 0 and t = length / 2 only)
##
## Output: {actor, fps, skeleton:{bones:[{name,parent,pos,rot,scl}]}, gltf_skeleton:{...},
##          bind_rest_stamp, poses:{<1-frame pose clip>: {bone:{pos,rot,scl}}},
##          clips:{<name>: {length, loop_mode, frames, meta:{...}, tracks:{bone:{pos:[[x,y,z]..],
##          rot:[[x,y,z,w]..], scl:[..]}}}}}
## Tracks exist only for the channels the clip keys (partial-body masks are kept).
## Every frame i is sampled at t = i / fps (the export's 30 fps timeline).
## Metadata (native_asset_id, original_name, source_attribution, ...) is copied verbatim.

const POSE_PREFIXES := ["bindpose", "null", "retarget-pose"]


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 1e-7), snappedf(v.y, 1e-7), snappedf(v.z, 1e-7)]


func _q(q: Quaternion) -> Array:
	return [snappedf(q.x, 1e-8), snappedf(q.y, 1e-8), snappedf(q.z, 1e-8), snappedf(q.w, 1e-8)]


func _skel(sk: Skeleton3D) -> Dictionary:
	var bones := []
	for b in sk.get_bone_count():
		var r := sk.get_bone_rest(b)
		bones.append({"name": sk.get_bone_name(b), "parent": sk.get_bone_parent(b),
			"pos": _v(r.origin), "rot": _q(r.basis.get_rotation_quaternion()), "scl": _v(r.basis.get_scale())})
	return {"bones": bones}


func _sample(anim: Animation, t: float) -> Dictionary:
	var d := {}
	for i in anim.get_track_count():
		var bone := str(anim.track_get_path(i).get_concatenated_subnames())
		if bone.is_empty():
			continue
		if not d.has(bone):
			d[bone] = {}
		match anim.track_get_type(i):
			Animation.TYPE_POSITION_3D: d[bone]["pos"] = _v(anim.position_track_interpolate(i, t))
			Animation.TYPE_ROTATION_3D: d[bone]["rot"] = _q(anim.rotation_track_interpolate(i, t).normalized())
			Animation.TYPE_SCALE_3D: d[bone]["scl"] = _v(anim.scale_track_interpolate(i, t))
	return d


func _meta(anim: Animation) -> Dictionary:
	var m := {}
	for k in anim.get_meta_list():
		m[String(k)] = anim.get_meta(k)
	return m


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var actor: String = args.get("actor", "Actor_A")
	var fps := float(args.get("fps", "30"))
	var inst: Node = load("res://characters/%s.tscn" % actor).instantiate()
	var sk: Skeleton3D = inst.get_node("Skeleton3D")
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	var lib := ap.get_animation_library(actor.to_lower())
	var out := {"actor": actor, "fps": fps, "skeleton": _skel(sk), "bind_rest_stamp": sk.get_meta("bind_rest", {}),
		"poses": {}, "clips": {}}
	var glb_path := "res://glb/%s_001.glb" % actor
	if ResourceLoader.exists(glb_path):
		var glb: Node = load(glb_path).instantiate()
		out["gltf_skeleton"] = _skel(glb.find_children("*", "Skeleton3D", true, false)[0])
		glb.free()
	for n in lib.get_animation_list():
		var s := String(n)
		for p in POSE_PREFIXES:
			if s.begins_with(p):
				var a := lib.get_animation(n)
				out["poses"][s] = {"pose": _sample(a, 0.0), "meta": _meta(a)}
				break
	if args.get("rig_only", "0") != "1":
		var names: PackedStringArray
		var spec: String = args.get("clips", "")
		var every := int(args.get("every", "0"))
		if every > 0:
			var i := 0
			for n in lib.get_animation_list():
				i += 1
				if i % every == 0:
					names.append(String(n))
		elif spec.begins_with("@"):
			names = FileAccess.get_file_as_string(spec.substr(1)).strip_edges().split("\n")
		else:
			names = spec.split(",", false)
		for n in names:
			n = n.strip_edges()
			if n.is_empty():
				continue
			if not lib.has_animation(n):
				push_error("no clip '%s' in %s" % [n, actor])
				continue
			var a := lib.get_animation(n)
			var frames := int(round(a.length * fps))
			var times := []
			if every > 0:
				times = [0.0, a.length * 0.5]
				frames = 1
			else:
				for i in frames + 1:
					times.append(minf(i / fps, a.length))
			var tracks := {}
			for tt: float in times:
				var s := _sample(a, tt)
				for bone in s:
					if not tracks.has(bone):
						tracks[bone] = {}
					for ch in s[bone]:
						if not tracks[bone].has(ch):
							tracks[bone][ch] = []
						tracks[bone][ch].append(s[bone][ch])
			out["clips"][n] = {"length": a.length, "loop_mode": a.loop_mode, "frames": frames + 1,
				"meta": _meta(a), "tracks": tracks}
	var f := FileAccess.open(args["out"], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("dump_clips: %s poses=%d clips=%d -> %s" % [actor, out["poses"].size(), out["clips"].size(), args["out"]])
	inst.free()
	quit(0)
