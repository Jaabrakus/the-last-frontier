extends SceneTree
## Seam continuity report (user complaint 2026-09-24 "snapping / teleporting"): runs the course
## routes of TravTestUtil with the live preview (the same setup as tests/traversal/
## test_traversal_moves.gd) and measures, at every content switch (entry from locomotion, part
## join inside a move, chained segment, exit to locomotion, air / landing), the position and
## velocity continuity of the rendered pelvis, both palms and both feet (ball of the foot), and
## of the rig root and the capsule:
##   d2   the largest one-frame second difference in the seam window (a pop / teleport shows as
##        a d2 far above the move's own motion), cm
##   dv   the velocity jump straddling the seam frame (3-frame means before / after), m/s
## The pelvis is also split into the root's part and the pose's part (pelvis in the rig frame),
## which tells whether a jump comes from the root path or from the clip pose.
##
##   Godot --headless --fixed-fps 120 --path . -s tools/traversal/seam_continuity.gd -- [route=name] [out=res://...json] [label=before]

const POINTS := {"pelvis": "pelvis", "l_palm": "l_palm", "r_palm": "r_palm", "l_foot": "l_ball", "r_foot": "r_ball"}
const OUT := "res://data/traversal/reports/seam_continuity.json"

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	change_scene_to_file("res://scenes/traversal_course.tscn")
	while current_scene == null or not current_scene.has_method("run_route"):
		await process_frame
	var course: Node = current_scene
	while not course.ready_done:
		await physics_frame
	var util := TravTestUtil.new(course)
	util.attach()
	var sk: Skeleton3D = course.actor.skeleton
	var idx := {}
	for k: String in POINTS:
		idx[k] = sk.find_bone(POINTS[k])
	var only := str(_args.get("route", ""))
	var report := {"meta": {"generator": "tools/traversal/seam_continuity.gd", "fps": 120, "label": str(_args.get("label", "")),
			"units": {"d2": "cm per frame^2 at 120 fps (one-frame jump)", "dv": "m/s (3-frame mean velocity after - before)"},
			"note": "rendered pose after TraversalIK; root = the rig (skeleton) origin; pose = pelvis in the rig frame"}, "routes": {}}
	for r: Dictionary in TravTestUtil.routes():
		if only != "" and not str(r.name).begins_with(only):
			continue
		var res: Dictionary = await util.run(r)
		var fr: Array = util.frames
		var rr := _route(fr, idx)
		rr["moves"] = res.started
		report.routes[r.name] = rr
		print("\n== %s  (%d seams)" % [r.name, (rr.seams as Array).size()])
		for s: Dictionary in rr.seams:
			print("   %-6s %-26s -> %-26s pel d2 %5.1f dv %4.2f (root %4.2f pose %4.2f) | palm d2 %5.1f dv %4.2f | foot d2 %5.1f dv %4.2f | cap d2 %4.1f dv %4.2f" % [
					s.kind, str(s.from).left(26), str(s.to).left(26), float(s.pelvis.d2), float(s.pelvis.dv), float(s.root.dv), float(s.pose.dv),
					maxf(float(s.l_palm.d2), float(s.r_palm.d2)), maxf(float(s.l_palm.dv), float(s.r_palm.dv)),
					maxf(float(s.l_foot.d2), float(s.r_foot.d2)), maxf(float(s.l_foot.dv), float(s.r_foot.dv)),
					float(s.capsule.d2), float(s.capsule.dv)])
		print("   worst: %s" % str(rr.worst))
	var out := str(_args.get("out", OUT))
	if only == "" or _args.has("out"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, " ", false) + "\n")
		f.close()
		print("\nwrote " + out)
	quit(0)


static func _kind(a: Dictionary, b: Dictionary) -> String:
	var ka := str(a.key)
	var kb := str(b.key)
	if str(a.mode) == "AIR" and str(b.mode) != "AIR":
		return "land"
	if str(b.mode) == "AIR" or kb.begins_with("air:"):
		return "air"
	if kb.begins_with("exit:") or (str(b.mode) == "OFF" and not ka.begins_with("exit:") and not ka.begins_with("loco:")):
		return "exit"
	if ka.begins_with("exit:") and kb.begins_with("loco:"):
		return "exit"
	if ka.begins_with("loco:") or ka.begins_with("exit:"):
		return "entry"
	# Same move and serial, next part: a part join.
	if ka.count(":") >= 2 and kb.count(":") >= 2 and ka.substr(0, ka.rfind(":")) == kb.substr(0, kb.rfind(":")):
		return "part"
	return "chain"


func _route(fr: Array, idx: Dictionary) -> Dictionary:
	var n := fr.size()
	# Arrays (reference type): a PackedVector3Array held in a Dictionary is copied on access.
	var tracks := {}
	for k: String in POINTS:
		tracks[k] = []
	tracks["root"] = []
	tracks["pose"] = []
	tracks["capsule"] = []
	for f: Dictionary in fr:
		var skx: Transform3D = f.sk
		for k: String in POINTS:
			(tracks[k] as Array).append(skx * (f.globals[int(idx[k])] as Transform3D).origin)
		(tracks.root as Array).append(skx.origin)
		(tracks.pose as Array).append(skx.basis * (f.globals[int(idx.pelvis)] as Transform3D).origin)
		(tracks.capsule as Array).append(f.capsule)
	for k: String in tracks.keys():
		tracks[k] = PackedVector3Array(tracks[k])
	var seams := []
	var worst := {}
	var switch_frames := []
	for i in range(3, n):
		var a0: Dictionary = fr[i - 1]
		var b0: Dictionary = fr[i]
		if a0.key != b0.key or a0.mode != b0.mode:
			switch_frames.append(i)
	for si in switch_frames.size():
		var i := int(switch_frames[si])
		var a: Dictionary = fr[i - 1]
		var b: Dictionary = fr[i]
		var kind := _kind(a, b)
		if kind == "chain" and str(a.key).begins_with("loco:") and str(b.key).begins_with("loco:"):
			continue
		# A route's first frames are its placement at the station (a teleport), not a seam.
		if i < 12:
			continue
		var fade := float(b.fade)
		var i1 := mini(n - 1, i + maxi(int(ceil(fade * 120.0)), 4) + 2)
		# The window ends before the next switch (measured on its own).
		if si + 1 < switch_frames.size():
			i1 = mini(i1, maxi(i, int(switch_frames[si + 1]) - 1))
		var s := {"frame": i, "kind": kind, "from": str(a.key), "to": str(b.key), "fade": fade, "mode": "%s>%s" % [a.mode, b.mode]}
		for k: String in tracks:
			var arr: PackedVector3Array = tracks[k]
			var d2 := 0.0
			for j in range(maxi(2, i - 1), i1 + 1):
				d2 = maxf(d2, (arr[j] - 2.0 * arr[j - 1] + arr[j - 2]).length())
			var dv := (_vel(arr, i, i + 3) - _vel(arr, i - 4, i - 1)).length()
			s[k] = {"d2": snappedf(d2 * 100.0, 0.01), "dv": snappedf(dv, 0.01)}
			var wk := "%s_%s" % [kind, k]
			if not worst.has(wk):
				worst[wk] = {"d2": 0.0, "dv": 0.0}
			worst[wk].d2 = maxf(float(worst[wk].d2), snappedf(d2 * 100.0, 0.01))
			worst[wk].dv = maxf(float(worst[wk].dv), snappedf(dv, 0.01))
		seams.append(s)
	return {"seams": seams, "worst": worst}


static func _vel(arr: PackedVector3Array, a: int, b: int) -> Vector3:
	a = clampi(a, 0, arr.size() - 1)
	b = clampi(b, 0, arr.size() - 1)
	return (arr[b] - arr[a]) * (120.0 / maxf(b - a, 1))
