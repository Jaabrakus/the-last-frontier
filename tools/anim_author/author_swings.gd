extends SceneTree
## This project's own felling-axe attacks (user 2026-09-27: "we have to make our own swings thats is close to theres"),
## from the key poses in data/anim_author/axe_swings.json, posed by tools/anim_author/pose_solver.gd (the rest pose, IK,
## no clip's data).
##   preview: Godot --path . -s tools/anim_author/author_swings.gd -- clip=axe_d out=<dir> [ref=atk-pipe-1-side-swing-intro,atk-pipe-1-side-swing-miss]
##            [at=0,0.2,...]  frames of ours (and of the reference, if given) at the same moments (seconds), three views
##            each, for a side-by-side sheet (the moments listed in <dir>/moments.txt)
##   mirror:  Godot --headless --path . -s tools/anim_author/author_swings.gd -- mirror=axe_d as=axe_a [desc=...]
##            a clip mirrored left for right (pose_solver.gd mirror) written into the data as another
##   bake:    Godot --headless --path . -s tools/anim_author/author_swings.gd -- bake
##            every clip into animations_extra/Frontier_Own.res (library frontier_own, clips "own-<name>"; a clip with
##            "split" as two, "own-<name>-intro" up to it and "own-<name>" after, the way the melee data plays the
##            reference's intro and hit), 30 fps
##   bake data=res://data/anim_author/fishing.json
##            another data file's clips baked into the same library beside the ones there (the fishing rod's poses:
##            tools/anim_author/author_fishing.gd)
## A clip's "hold" says how the tool sits on the right hand (pose_solver.gd: "blade" or "pipe"); fit_ref.gd writes the
## keys of a clip measured off a reference.

const Solver := preload("res://tools/anim_author/pose_solver.gd")
const FitRef := preload("res://tools/anim_author/fit_ref.gd")
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const DATA := "res://data/anim_author/axe_swings.json"
const OUT_LIB := "res://animations_extra/Frontier_Own.res"
const FPS := 30.0
const MOMENTS := [0.0, 0.2, 0.3, 0.38, 0.45, 0.55, 0.8, 1.2]

var data := {}
var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	data = JSON.parse_string(FileAccess.get_file_as_string(str(args.get("data", DATA))))
	if args.has("mirror"):
		_mirror(str(args.mirror), str(args.get("as", str(args.mirror) + "_mirror")), str(args.get("desc", "")))
		quit()
		return
	if args.has("bake"):
		await _bake()
	else:
		await _preview()
	quit()


# --- key poses over time -----------------------------------------------------------------------------------------

static func _flat(d: Dictionary, pre := "", out := {}) -> Dictionary:
	for k in d:
		var v = d[k]
		var key := pre + str(k)
		if v is Dictionary:
			_flat(v, key + ".", out)
		elif v is Array:
			for i in (v as Array).size():
				out[key + "." + str(i)] = float(v[i])
		elif v is float or v is int:
			out[key] = float(v)
	return out


static func _unflat(f: Dictionary) -> Dictionary:
	var out := {}
	for key: String in f:
		var parts := key.split(".")
		var node := out
		for i in parts.size() - 1:
			if not node.has(parts[i]):
				node[parts[i]] = {}          # (numbered ones become arrays after, _arrays)
			node = node[parts[i]]
		node[parts[parts.size() - 1]] = f[key]
	return _arrays(out)


## {"0": a, "1": b} -> [a, b]
static func _arrays(d):
	if d is Dictionary:
		var keys := (d as Dictionary).keys()
		if not keys.is_empty() and keys.all(func(k) -> bool: return str(k).is_valid_int()):
			var arr := []
			arr.resize(keys.size())
			for k in keys:
				arr[int(k)] = d[k]
			return arr
		var o := {}
		for k in d:
			o[k] = _arrays(d[k])
		return o
	return d


static func _ease(u: float, kind: String) -> float:
	match kind:
		"in":
			return u * u
		"out":
			return 1.0 - (1.0 - u) * (1.0 - u)
		"fast":
			return u * u * u
		"linear":
			return u
	return smoothstep(0.0, 1.0, u)


## The pose at `t`: each number eased from the key before to the key after (a key missing a number holds the last).
## A key's "ease" shapes the way into it: in (slow start), out (slow end), fast (slow then very fast), linear, spline
## (a curve through the keys either side, flat at a turning point, as a curve editor's auto-clamped handles), or
## none (smooth: slow at both ends).
static func pose_at(clip: Dictionary, t: float) -> Dictionary:
	var keys: Array = clip.keys
	var flats := []
	var last := {}
	for k: Dictionary in keys:
		var f := _flat(k)
		var merged := last.duplicate()
		merged.merge(f, true)
		flats.append(merged)
		last = merged
	var times := keys.map(func(k: Dictionary) -> float: return float(k.t))
	var eases := keys.map(func(k: Dictionary) -> String: return str(k.get("ease", "")))
	return _unflat(pose_at_flat(times, flats, eases, t))


## pose_at over keys already flattened (times, the numbers at each, the ease into each).
static func pose_at_flat(times: Array, flats: Array, eases: Array, t: float) -> Dictionary:
	var n := times.size()
	var i := 0
	while i < n - 1 and float(times[i + 1]) < t:
		i += 1
	var f := {}
	if i >= n - 1:
		for key: String in flats[n - 1]:
			if key != "t":
				f[key] = flats[n - 1][key]
		return f
	var t0 := float(times[i])
	var t1 := float(times[i + 1])
	var dt := maxf(t1 - t0, 1e-4)
	var u := clampf((t - t0) / dt, 0.0, 1.0)
	var e := str(eases[i + 1])
	var a: Dictionary = flats[i]
	var b: Dictionary = flats[i + 1]
	for key: String in b:
		if key == "t":
			continue
		var p0 := float(a.get(key, b[key]))
		var p1 := float(b[key])
		if e == "spline":
			var m0 := _tangent(times, flats, i, key)
			var m1 := _tangent(times, flats, i + 1, key)
			var u2 := u * u
			var u3 := u2 * u
			f[key] = (2.0 * u3 - 3.0 * u2 + 1.0) * p0 + (u3 - 2.0 * u2 + u) * dt * m0 + (-2.0 * u3 + 3.0 * u2) * p1 \
					+ (u3 - u2) * dt * m1
		else:
			f[key] = lerpf(p0, p1, _ease(u, e))
	return f


## A number's slope at key i (per second): from the key before to the key after (at the first and the last key, toward
## its one neighbour); flat where the key is a peak or a dip (so the curve does not overshoot it).
static func _tangent(times: Array, flats: Array, i: int, key: String) -> float:
	var n := times.size()
	if n < 2:
		return 0.0
	if i <= 0 or i >= n - 1:
		var j := 1 if i <= 0 else n - 2
		var k := 0 if i <= 0 else n - 1
		var lo := mini(j, k)
		var hi := maxi(j, k)
		return (float(flats[hi].get(key, 0.0)) - float(flats[lo].get(key, 0.0))) / maxf(float(times[hi]) - float(times[lo]), 1e-4)
	var p := float(flats[i].get(key, 0.0))
	var pa := float(flats[i - 1].get(key, p))
	var pb := float(flats[i + 1].get(key, p))
	if (p - pa) * (pb - p) <= 0.0:
		return 0.0
	var m := (pb - pa) / maxf(float(times[i + 1]) - float(times[i - 1]), 1e-4)
	# (clamped so the curve stays between its neighbours)
	var lim := 3.0 * minf(absf(p - pa) / maxf(float(times[i]) - float(times[i - 1]), 1e-4),
			absf(pb - p) / maxf(float(times[i + 1]) - float(times[i]), 1e-4))
	return clampf(m, -lim, lim)


# --- mirror ---------------------------------------------------------------------------------------------------------

## A clip of `src` mirrored left for right (Solver.mirror on every key), written into the data as `dst`.
func _mirror(src: String, dst: String, desc: String) -> void:
	var c: Dictionary = data.clips[src]
	var out := {"desc": desc if desc != "" else "%s mirrored" % src}
	for k: String in c:
		if k in ["desc", "keys", "fit"]:
			continue
		out[k] = c[k]
	out["mirror_of"] = src
	out["keys"] = (c.keys as Array).map(func(k: Dictionary) -> Dictionary: return Solver.mirror(k))
	data.clips[dst] = out
	var fa := FileAccess.open(DATA, FileAccess.WRITE)
	fa.store_string(FitRef.write_json(data))
	fa.close()
	print("MIRRORED %s -> %s: %d keys" % [src, dst, (out["keys"] as Array).size()])


# --- preview -------------------------------------------------------------------------------------------------------

func _character() -> Array:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	CharacterBodyMesh.attach(sk, aps[0] if not aps.is_empty() else null, "res://assets/character/actor_b_body.glb")
	return [n, sk, aps[0] if not aps.is_empty() else null]


func _preview() -> void:
	var out := str(args.get("out", "user://author"))
	var clip: Dictionary = data.clips[str(args.get("clip", "axe_d"))]
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.62, 0.56, 0.45)
	floor.material_override = fm
	world.add_child(floor)
	var ours := _character()
	var solver = Solver.new(ours[1])
	var hold := str(clip.get("hold", "blade"))
	solver.hold = hold
	solver.carry = str(clip.get("carry", ""))
	solver.space = str(clip.get("space", "body"))
	solver.wrist_bend = float(clip.get("wrist_bend", 0.0))
	solver.wrist_twist = float(clip.get("wrist_twist", 0.0))
	var moments: Array = Array(str(args.get("at", "")).split(",", false)).map(func(x: String) -> float: return float(x))
	if moments.is_empty():
		moments = MOMENTS
	var mf := FileAccess.open(out + "/moments.txt", FileAccess.WRITE)
	mf.store_string(",".join(moments.map(func(x: float) -> String: return "%.2f" % x)))
	mf.close()
	var axe_o := GatherModels.build("felling_axe")
	world.add_child(axe_o)
	var ref_clips: PackedStringArray = str(args.get("ref", "")).split(",", false)
	var theirs := []
	var axe_r: Node3D = null
	var lib: AnimationLibrary = null
	if not ref_clips.is_empty():
		theirs = _character()
		(theirs[0] as Node3D).position = Vector3(8.0, 0, 0)
		lib = load("res://animations_extra/Actor_B_from_A.res")
		(theirs[2] as AnimationPlayer).add_animation_library("a", lib)
		(theirs[2] as AnimationPlayer).speed_scale = 0.0     # (held at the moment sought while its views render)
		axe_r = GatherModels.build("felling_axe")
		world.add_child(axe_r)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(300, 360))
	var cam: Camera3D = view.camera
	cam.fov = 40.0
	await process_frame
	await process_frame
	for k in moments.size():
		var t: float = minf(float(moments[k]), float(clip.length))
		solver.pose(pose_at(clip, t))
		var sk: Skeleton3D = ours[1]
		sk.force_update_all_bone_transforms()
		var prop := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("r_hand_prop_attachment"))
		axe_o.global_transform = prop * Solver.hold_xf(hold)
		if not theirs.is_empty():
			var ap := theirs[2] as AnimationPlayer
			var intro := lib.get_animation(ref_clips[0])
			var tt := t
			var nm := ref_clips[0]
			if ref_clips.size() > 1 and t > intro.length:
				nm = ref_clips[1]
				tt = t - intro.length
			ap.play("a/" + nm)
			ap.seek(tt, true)
			var sr: Skeleton3D = theirs[1]
			sr.force_update_all_bone_transforms()
			var pr := sr.global_transform * sr.get_bone_global_pose(sr.find_bone("r_hand_prop_attachment"))
			axe_r.global_transform = pr * Solver.hold_xf(hold)
		for who in (["ours", "theirs"] if not theirs.is_empty() else ["ours"]):
			# (one at a time: the other and its axe out of the picture)
			(ours[0] as Node3D).visible = who == "ours"
			axe_o.visible = who == "ours"
			if not theirs.is_empty():
				(theirs[0] as Node3D).visible = who == "theirs"
				axe_r.visible = who == "theirs"
			var base := Vector3(0, 1.0, 0.1) + (Vector3(8.0, 0, 0) if who == "theirs" else Vector3.ZERO)
			for side in ["front", "side", "left"]:
				var off := Vector3(-1.4, 0.35, 2.6)
				if side == "side":
					off = Vector3(-2.9, 0.4, -0.2)
				elif side == "left":
					off = Vector3(2.2, 0.45, 2.0)
				cam.global_position = base + off
				cam.look_at(base)
				for i in 3:
					await process_frame
				view.get_texture().get_image().save_png(out + "/%s_%s_%d.png" % [who, side, k])
	print("AUTHOR PREVIEW ", clip.get("desc", ""), " -> ", out)


# --- bake ------------------------------------------------------------------------------------------------------------

func _bake() -> void:
	var ch := _character()
	var sk: Skeleton3D = ch[1]
	# (a skeleton not yet through a frame reads its bones' global poses back as the rest: the IK would solve from there)
	await process_frame
	await process_frame
	var solver = Solver.new(sk)
	# the other clips' track path to the skeleton (the same AnimationPlayer root)
	var ref_lib := load("res://animations_extra/Actor_B_from_A.res") as AnimationLibrary
	var ref := ref_lib.get_animation(ref_lib.get_animation_list()[0])
	var path_pre := str(ref.track_get_path(0)).get_slice(":", 0)
	var lib := AnimationLibrary.new()
	lib.resource_name = "frontier_own"
	if args.has("data"):
		# (another data file's clips beside the library's own)
		var was := load(OUT_LIB) as AnimationLibrary
		if was:
			for a: StringName in was.get_animation_list():
				lib.add_animation(a, was.get_animation(a))
	for name: String in data.clips:
		var clip: Dictionary = data.clips[name]
		solver.carry = str(clip.get("carry", ""))
		solver.hold = str(clip.get("hold", "blade"))
		solver.space = str(clip.get("space", "body"))
		solver.wrist_bend = float(clip.get("wrist_bend", 0.0))
		solver.wrist_twist = float(clip.get("wrist_twist", 0.0))
		var length := float(clip.length)
		var own := "own-" + name.replace("_", "-")
		for nm: String in [own, own + "-intro"]:
			if lib.has_animation(nm):
				lib.remove_animation(nm)
		if clip.has("split"):
			var sp := float(clip.split)
			lib.add_animation(StringName(own + "-intro"), _bake_span(solver, sk, clip, 0.0, sp, path_pre))
			lib.add_animation(StringName(own), _bake_span(solver, sk, clip, sp, length, path_pre))
		else:
			lib.add_animation(StringName(own), _bake_span(solver, sk, clip, 0.0, length, path_pre))
		print("baked %s: %.2f s" % [own, length])
	print(ResourceSaver.save(lib, OUT_LIB, ResourceSaver.FLAG_COMPRESS))


## The bones from the root out to the head, the hands' prop bones, the fingers and the feet.
static func _chain_bones(sk: Skeleton3D) -> Dictionary:
	var out := {}
	for b in sk.get_bone_count():
		var nm := sk.get_bone_name(b)
		var end := nm in ["headb", "r_hand_prop_attachment", "l_hand_prop_attachment", "r_ball", "l_ball"]
		for f: String in ["index", "middle", "ring", "pinky", "thumb"]:
			if nm.begins_with("r_" + f) or nm.begins_with("l_" + f):
				end = true
		if not end:
			continue
		var c := b
		while c >= 0:
			out[sk.get_bone_name(c)] = true
			c = sk.get_bone_parent(c)
	return out


## The clip's poses from t0 to t1 as an animation (its time from 0), a track for each bone they move.
func _bake_span(solver, sk: Skeleton3D, clip: Dictionary, t0: float, t1: float, path_pre: String) -> Animation:
	var length := t1 - t0
	var n := int(round(length * FPS))
	var anim := Animation.new()
	anim.length = length
	anim.set_meta(&"authored", "Frontier: this project's own key poses (%s, tools/anim_author/)" % str(args.get("data", DATA)).trim_prefix("res://"))
	var fit: Dictionary = clip.get("fit", {})
	if fit.is_empty():
		anim.set_meta(&"source", "none: not extracted from any game")
	else:
		anim.set_meta(&"source", "key poses measured off %s (tools/anim_author/fit_ref.gd); the in-betweens our own" % ", ".join(fit.ref))
	var rot := {}
	var posi := {}
	for f in n + 1:
		var t := minf(float(f) / FPS, length)
		solver.pose(pose_at(clip, t0 + t))
		for b in sk.get_bone_count():
			var nm := sk.get_bone_name(b)
			var q := sk.get_bone_pose_rotation(b)
			if f == 0 and not rot.has(nm):
				rot[nm] = []
			(rot[nm] as Array).append([t, q])
			if nm in ["root", "r_hand_prop_attachment"]:
				if not posi.has(nm):
					posi[nm] = []
				(posi[nm] as Array).append([t, sk.get_bone_pose_position(b)])
	var chain := _chain_bones(sk)
	for nm: String in rot:
		# every bone from the root out to the head, the hands, the fingers and the feet (the ones the pose leaves at rest
		# too: in the game a bone the clip does not key keeps the pose under it, the idle's palm say, and the tool on the
		# prop bone would go with it)
		if not chain.has(nm):
			continue
		var keys: Array = rot[nm]
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(path_pre + ":" + nm))
		for k: Array in keys:
			anim.rotation_track_insert_key(tr, float(k[0]), k[1])
	for nm: String in posi:
		var tr := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(tr, NodePath(path_pre + ":" + nm))
		for k: Array in posi[nm]:
			anim.position_track_insert_key(tr, float(k[0]), k[1])
	return anim
