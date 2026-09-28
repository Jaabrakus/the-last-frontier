extends SceneTree
## Key poses for one of our clips measured off a reference swing (user 2026-09-27: "try to get as close to the reference
## as possible"): the reference is played on Actor_B and, every frame, the pose solver's numbers are read off it (the
## pelvis, the chest's and the head's turns, the collarbones, the tool in the right hand and the left hand on it, the
## elbows' and the knees' ways, the feet); then as few of those frames as will do are kept as keys: starting from the
## first and the last, the frame the eased in-betweens miss worst is added, each span taking the ease (smooth, linear,
## in, out, fast) that misses least, until nothing is out by more than `tol` metres beyond what the frame misses by when
## keyed itself (the wrists, the knuckles, the elbows, the head, the chest, the knees, the feet and the axe's head) or
## there are `max` keys. What comes out is written as the clip's
## keys in data/anim_author/axe_swings.json: a close copy of the reference's motion at those frames, the in-betweens
## the solver's own (see "fit" on the clip for what it was measured from).
##   Godot --headless --path . -s tools/anim_author/fit_ref.gd -- clip=axe_d ref=<intro>,<hit> hold=pipe [tol=0.025]
##         [max=18] [desc=...]

const Solver := preload("res://tools/anim_author/pose_solver.gd")
const Author := preload("res://tools/anim_author/author_swings.gd")
const DATA := "res://data/anim_author/axe_swings.json"
const FPS := 30.0
const JOINTS := ["r_wrist", "l_wrist", "r_elbow", "l_elbow", "headb", "spined", "r_knee", "l_knee", "r_ankle", "l_ankle",
		"r_ball", "l_ball", "r_indexa", "r_pinkya", "l_indexa", "l_pinkya"]
const EASES := ["spline", "", "linear", "in", "out", "fast"]
## The axe's head, in the model's frame (its knob at the origin, the haft +Y).
const AXE_HEAD := Vector3(0, 0.8, 0)

var args := {}
var sk: Skeleton3D
var solver
var hold := "pipe"
var ref_j: Array = []            ## per frame: {joint: Vector3, "axe": Vector3}
var flats: Array = []            ## per frame: the measured numbers, flattened


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	var clip_name := str(args.get("clip", "axe_d"))
	var refs: PackedStringArray = str(args.get("ref", "")).split(",", false)
	hold = str(args.get("hold", "pipe"))
	var tol := float(args.get("tol", 0.025))
	var max_keys := int(args.get("max", 18))
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	sk = n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := n.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	solver = Solver.new(sk)
	solver.hold = hold
	solver.space = "chest"
	var lib := load("res://animations_extra/Actor_B_from_A.res") as AnimationLibrary
	ap.add_animation_library("a", lib)
	var parts: Array = []
	var length := 0.0
	for r in refs:
		parts.append([r, length])
		length += lib.get_animation(r).length
	await process_frame
	# every frame of the reference, measured
	var frames := int(round(length * FPS))
	for f in frames + 1:
		var t := minf(float(f) / FPS, length)
		var nm: String = parts[0][0]
		var tt := t
		for pt: Array in parts:
			if t >= float(pt[1]) - 1e-4:
				nm = pt[0]
				tt = minf(t - float(pt[1]), lib.get_animation(nm).length)
		ap.play("a/" + nm)
		ap.seek(tt, true)
		sk.force_update_all_bone_transforms()
		var jj := {}
		for j: String in JOINTS:
			jj[j] = _gp(j).origin
		jj["axe"] = (_gp("r_hand_prop_attachment") * Solver.hold_xf(hold)) * AXE_HEAD
		ref_j.append(jj)
		flats.append(Author._flat(_measure()))
	ap.stop()
	_unwrap()
	if args.has("debug"):
		for f in range(1, ref_j.size()):
			var mv := []
			for j: String in ["r_wrist", "headb", "l_ankle", "r_ankle", "axe"]:
				mv.append("%s %.3f" % [j, (ref_j[f][j] as Vector3).distance_to(ref_j[f - 1][j])])
			print("ref move f %d: %s" % [f, ", ".join(mv)])
	# how near each frame comes when keyed exactly (the solver's floor)
	var floor_e := []
	for f in flats.size():
		floor_e.append(_err(Author._unflat(flats[f]), f))
		if args.has("debug") and f % 4 == 0:
			var jj: Dictionary = ref_j[f]
			var parts_e := []
			for j: String in JOINTS:
				parts_e.append("%s %.2f" % [j, _gp(j).origin.distance_to(jj[j])])
			print("frame %d floor %.3f: %s" % [f, floor_e[f], ", ".join(parts_e)])
	# keep frames until the in-betweens are close enough
	var keys: Array = [0, flats.size() - 1]
	var eases := {}                  ## key frame -> the ease into it
	var worst_f := -1
	var worst := 0.0
	while true:
		# each span's ease (a spline's shape also hangs on the keys either side: every span again each time)
		var errs := {}
		for i in keys.size() - 1:
			var best_e := INF
			for e: String in EASES:
				eases[keys[i + 1]] = e
				var m := 0.0
				var es := {}
				for f in range(int(keys[i]) + 1, int(keys[i + 1])):
					es[f] = _err(_interp(keys, eases, f), f) - float(floor_e[f])
					m = maxf(m, es[f])
				if m < best_e:
					best_e = m
					errs[i] = [e, es]
			eases[keys[i + 1]] = errs[i][0]
		worst = 0.0
		worst_f = -1
		for i: int in errs:
			var es: Dictionary = errs[i][1]
			for f: int in es:
				if float(es[f]) > worst:
					worst = es[f]
					worst_f = f
		if worst_f < 0 or worst <= tol or keys.size() >= max_keys:
			break
		keys.append(worst_f)
		keys.sort()
	if args.has("debug"):
		for f in flats.size():
			if keys.has(f):
				continue
			var p := _interp(keys, eases, f)
			var e := _err(p, f)
			var jj: Dictionary = ref_j[f]
			var parts_e := []
			for j: String in JOINTS:
				var d := _gp(j).origin.distance_to(jj[j])
				if d > 0.05:
					parts_e.append("%s %.2f" % [j, d])
			parts_e.append("axe %.2f" % (solver.tool_world * AXE_HEAD).distance_to(jj.axe))
			print("f %d (%s) err %.3f: %s" % [f, eases.get(_next_key(keys, f), ""), e, ", ".join(parts_e)])
	var floor_max := 0.0
	for e: float in floor_e:
		floor_max = maxf(floor_max, e)
	# the clip
	var out_keys: Array = []
	for i in keys.size():
		var f: int = keys[i]
		var k := {"t": snappedf(float(f) / FPS, 0.0001)}
		if i > 0 and str(eases.get(f, "")) != "":
			k["ease"] = eases[f]
		k.merge(Author._unflat(_rounded(flats[f])))
		out_keys.append(k)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var old: Dictionary = (data.clips as Dictionary).get(clip_name, {})
	var clip := {"desc": str(args.get("desc", old.get("desc", ""))), "length": snappedf(length, 0.0001), "hold": hold,
			"space": "chest"}
	if refs.size() > 1:
		clip["split"] = snappedf(float(parts[1][1]), 0.0001)
	clip["fit"] = {"ref": Array(refs), "fps": FPS, "keys": keys.size(), "tol_m": tol, "past_floor_m": snappedf(worst, 0.001),
			"floor_m": snappedf(floor_max, 0.001)}
	clip["keys"] = out_keys
	data.clips[clip_name] = clip
	var fa := FileAccess.open(DATA, FileAccess.WRITE)
	fa.store_string(write_json(data))
	fa.close()
	print("FIT %s: %d keys at %s, worst %.3f m past the floor (frame %d), exact-key floor %.3f m" % [clip_name, keys.size(),
			str(keys.map(func(f: int) -> String: return "%.2f" % (float(f) / FPS))), worst, worst_f, floor_max])
	quit()


func _gp(nm: String) -> Transform3D:
	return sk.get_bone_global_pose(sk.find_bone(nm))


## The solver's numbers for the pose the skeleton has now.
func _measure() -> Dictionary:
	var R: Dictionary = solver.rest
	var rt := _gp("root")
	var hb := rt.basis.orthonormalized() * (R.root as Transform3D).basis.orthonormalized().inverse()
	var ra: Array = Solver.angles(hb)
	var off := rt.origin - (R.root as Transform3D).origin
	var pl := hb.inverse() * _gp("pelvis").basis.orthonormalized() * (R.pelvis as Transform3D).basis.orthonormalized().inverse()
	var pa: Array = Solver.angles(pl)
	var pb := hb * pl
	var chest := hb.inverse() * _gp("spined").basis.orthonormalized() * (R.spined as Transform3D).basis.orthonormalized().inverse()
	var waist := hb.inverse() * _gp("spineb").basis.orthonormalized() * (R.spineb as Transform3D).basis.orthonormalized().inverse()
	var body := hb * chest
	var chest_xf := Transform3D(body, _gp("spined").origin)
	var wa: Array = Solver.angles(waist)
	var head := body.inverse() * _gp("headb").basis.orthonormalized() * (R.headb as Transform3D).basis.orthonormalized().inverse()
	var ca: Array = Solver.angles(chest)
	var ha: Array = Solver.angles(head)
	var p := {"hips": {"pos": _a3(off), "yaw": ra[0], "pitch": ra[1], "roll": ra[2]},
			"pelvis": {"yaw": pa[0], "pitch": pa[1], "roll": pa[2]},
			"chest": {"yaw": ca[0], "pitch": ca[1], "roll": ca[2]}, "waist": {"yaw": wa[0], "pitch": wa[1], "roll": wa[2]},
			"head": {"yaw": ha[0], "pitch": ha[1], "roll": ha[2]}}
	var cl := {}
	var el := {}
	var kn := {}
	var ft := {}
	for side: String in ["r", "l"]:
		var c := _gp(side + "_clavicle")
		cl[side] = Solver.angles(body.inverse() * c.basis.orthonormalized() * (R[side + "_clavicle"] as Transform3D).basis.orthonormalized().inverse())
		# (the elbows' ways in the chest's frame, the knees' in the pelvis's: space "chest")
		el[side] = _a3(body.inverse() * (_gp(side + "_elbow").origin - _gp(side + "_shoulder").origin))
		kn[side] = _a3(pb.inverse() * (_gp(side + "_knee").origin - _gp(side + "_upper_leg").origin))
		var an := _gp(side + "_ankle")
		var ar: Transform3D = R[side + "_ankle"]
		var fa: Array = Solver.angles(an.basis.orthonormalized() * ar.basis.orthonormalized().inverse())
		ft[side] = [an.origin.x, an.origin.z, an.origin.y - ar.origin.y, fa[0], fa[1], fa[2]]
	p["clav"] = cl
	p["elbows"] = el
	p["knees"] = kn
	p["feet"] = ft
	# the tool where the reference's prop bone carries it; each hand's own prop frame (as its rest has it) in the tool's
	var tf := _gp("r_hand_prop_attachment") * Solver.hold_xf(hold)
	var tc := chest_xf.affine_inverse() * tf
	var tl := {"grip": _a3((chest_xf.affine_inverse() * _gp("r_hand_prop_attachment")).origin), "q": _q4(tc.basis)}
	for side: String in ["r", "l"]:
		var rel: Transform3D = (R[side + "_wrist"] as Transform3D).affine_inverse() * R[side + "_hand_prop_attachment"]
		var ht := tf.affine_inverse() * (_gp(side + "_wrist") * rel)
		tl["right" if side == "r" else "left"] = _a3(ht.origin)
		tl["rq" if side == "r" else "lq"] = _q4(ht.basis)
	p["tool"] = tl
	return p


## Angles kept continuous from frame to frame (no jump of 360 degrees between them), the quaternions on the same side
## as the frame before's (q and -q are the one turn).
func _unwrap() -> void:
	for f in range(1, flats.size()):
		var a: Dictionary = flats[f - 1]
		var b: Dictionary = flats[f]
		for qk: String in ["tool.q", "tool.rq", "tool.lq"]:
			if not b.has(qk + ".0"):
				continue
			var dot := 0.0
			for i in 4:
				dot += float(a[qk + ".%d" % i]) * float(b[qk + ".%d" % i])
			if dot < 0.0:
				for i in 4:
					b[qk + ".%d" % i] = -float(b[qk + ".%d" % i])
		for k: String in b:
			if k.begins_with("tool.") and "q." in k:
				continue
			var d := float(b[k]) - float(a.get(k, b[k]))
			if absf(d) > 180.0:
				b[k] = float(b[k]) - 360.0 * round(d / 360.0)


## The pose at frame f with only `keys` kept (the frames), each eased in as `eases` says.
func _interp(keys: Array, eases: Dictionary, f: int) -> Dictionary:
	var times := keys.map(func(k: int) -> float: return float(k) / FPS)
	var fl := keys.map(func(k: int) -> Dictionary: return flats[k])
	var es := keys.map(func(k: int) -> String: return str(eases.get(k, "")))
	return Author._unflat(Author.pose_at_flat(times, fl, es, float(f) / FPS))


static func _next_key(keys: Array, f: int) -> int:
	for k: int in keys:
		if k > f:
			return k
	return keys.back()


## How far our pose `p` is from the reference's frame f: the worst of the joints and the axe's head (metres).
func _err(p: Dictionary, f: int) -> float:
	solver.pose(p)
	var jj: Dictionary = ref_j[f]
	var e := 0.0
	for j: String in JOINTS:
		e = maxf(e, _gp(j).origin.distance_to(jj[j]))
	return maxf(e, (solver.tool_world * AXE_HEAD).distance_to(jj.axe))


static func _q4(b: Basis) -> Array:
	var q := b.orthonormalized().get_rotation_quaternion()
	return [q.x, q.y, q.z, q.w]


static func _a3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## Metres to the millimetre, degrees to a tenth.
static func _rounded(f: Dictionary) -> Dictionary:
	var o := {}
	for k: String in f:
		var angle := k.ends_with("yaw") or k.ends_with("pitch") or k.ends_with("roll") or k.begins_with("clav.") \
				or k.begins_with("tool.lturn") or k.begins_with("tool.rturn") or (k.begins_with("feet.") and int(k.get_slice(".", 2)) >= 3)
		var quat := k.begins_with("tool.q.") or k.begins_with("tool.rq.") or k.begins_with("tool.lq.")
		o[k] = snappedf(float(f[k]), 0.1 if angle else (0.0001 if quat else 0.001))
	return o


## The data file, a key to a line.
static func write_json(data: Dictionary) -> String:
	var s := "{\n"
	var top: Array = []
	for k: String in data:
		if k == "clips":
			continue
		top.append(" %s: %s" % [JSON.stringify(k), JSON.stringify(data[k], "", false)])
	var clips: Array = []
	for nm: String in data.clips:
		var c: Dictionary = data.clips[nm]
		var lines: Array = []
		for k: String in c:
			if k == "keys":
				continue
			lines.append("   %s: %s" % [JSON.stringify(k), JSON.stringify(c[k], "", false)])
		var ks: Array = (c.keys as Array).map(func(k) -> String: return "    " + JSON.stringify(k, "", false))
		lines.append("   \"keys\": [\n%s\n   ]" % ",\n".join(ks))
		clips.append("  %s: {\n%s\n  }" % [JSON.stringify(nm), ",\n".join(lines)])
	top.append(" \"clips\": {\n%s\n }" % ",\n".join(clips))
	return s + ",\n".join(top) + "\n}\n"
