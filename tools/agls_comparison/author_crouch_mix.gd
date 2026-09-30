extends SceneTree
## Crouch walks: Frontier Updated's legs, hips and timing under the Grounded blend's upper body (user 2026-09-30: "the blended
## grounded upper and the frontiers updated lower"). The Grounded crouch legs are Frontier's retimed unevenly (they match within
## 1 deg at the right moments), so each Frontier frame is matched to its Grounded moment by the legs (a monotonic time warp) and
## the upper body is read there: the arms stay in step with Frontier's feet. Bones the Frontier clip does not key (the fingers)
## are left out, so the grip keeps the hands. bw-lt and bw-rt take the backward upper body (Grounded has four directions).
##   bake:  Godot --headless --path . -s tools/agls_comparison/author_crouch_mix.gd -- bake [parts=all|torso]
##          writes animations_extra/Frontier_Legacy/Frontier_Legacy_Crouch.res (library frontier_legacy_crouch) and wires
##          data/anim_author/locomotion_clips.json
##   sheet: Godot --path . -s tools/agls_comparison/author_crouch_mix.gd -- sheet out=<dir> [dir=fw]
##          side-view frames of Frontier Updated and the mix at the same moments

const NATIVE := "res://animations/Actor_B.res"
const GROUNDED := "res://animations_extra/Frontier_Legacy/Grounded/Frontier_Legacy_Grounded.res"
const OUT_LIB := "res://animations_extra/Frontier_Legacy/Frontier_Legacy_Crouch.res"
const LIB_NAME := "frontier_legacy_crouch"
const WIRED := "res://data/anim_author/locomotion_clips.json"
const SOURCE := {"fw": "forward", "fw-lt": "left", "fw-rt": "right", "bw": "backward", "bw-lt": "backward", "bw-rt": "backward"}
## Which Frontier clip's legs the warp is found on (bw-lt/bw-rt borrow the backward one's).
const WARP_FROM := {"bw-lt": "bw", "bw-rt": "bw"}
const LEGS := ["l_upper_leg", "r_upper_leg", "l_knee", "r_knee", "l_ankle", "r_ankle"]
const RATE := 60.0
const G_SAMPLES := 600
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var args := {}
var nat: AnimationLibrary
var grounded: AnimationLibrary
var upper: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	nat = load(NATIVE)
	grounded = load(GROUNDED)
	var ch := _character()
	var sk := ch[1] as Skeleton3D
	# the upper body: upper_base and everything under it
	var top := sk.find_bone("upper_base")
	for i in sk.get_bone_count():
		var b := i
		while b >= 0 and b != top:
			b = sk.get_bone_parent(b)
		if b == top:
			upper[sk.get_bone_name(i)] = true
	if args.has("bake"):
		_bake()
	elif args.has("sheet"):
		await _sheet(ch)
	quit()


static func _clip(dir: String) -> String:
	return "frontier_legacy_crouch_walk_" + dir.replace("-", "_")


func _q(a: Animation, bone: String, t: float) -> Quaternion:
	var i := a.find_track(NodePath("Skeleton3D:" + bone), Animation.TYPE_ROTATION_3D)
	return a.rotation_track_interpolate(i, t).normalized() if i >= 0 else Quaternion.IDENTITY


func _leg_err(a: Animation, ta: float, b: Animation, tb: float) -> float:
	var e := 0.0
	for bone in LEGS:
		e += _q(a, bone, ta).angle_to(_q(b, bone, tb))
	return e


## Frontier time -> Grounded time for each of the Frontier clip's frames: the monotonic path through the leg-pose distances
## (dynamic time warping) from both clips' start to both clips' end.
func _warp(n: Animation, g: Animation) -> PackedFloat32Array:
	var nf := int(round(n.length * RATE)) + 1
	var cost := []
	for i in nf:
		var row := PackedFloat32Array()
		row.resize(G_SAMPLES + 1)
		for j in G_SAMPLES + 1:
			row[j] = _leg_err(n, minf(i / RATE, n.length), g, float(j) / G_SAMPLES * g.length)
		cost.append(row)
	var acc := []
	var from := []
	for i in nf:
		var r := PackedFloat32Array()
		r.resize(G_SAMPLES + 1)
		var f := PackedInt32Array()
		f.resize(G_SAMPLES + 1)
		for j in G_SAMPLES + 1:
			var c: float = cost[i][j]
			if i == 0 and j == 0:
				r[j] = c
				f[j] = -1
				continue
			var best := INF
			var pick := 0
			# steps: next Frontier frame at the same or a later Grounded sample, or a later Grounded sample at the same frame
			if i > 0 and (acc[i - 1] as PackedFloat32Array)[j] < best:
				best = (acc[i - 1] as PackedFloat32Array)[j]
				pick = 0
			if i > 0 and j > 0 and (acc[i - 1] as PackedFloat32Array)[j - 1] < best:
				best = (acc[i - 1] as PackedFloat32Array)[j - 1]
				pick = 1
			if j > 0 and r[j - 1] < best:
				best = r[j - 1]
				pick = 2
			r[j] = best + c
			f[j] = pick
		acc.append(r)
		from.append(f)
	var out := PackedFloat32Array()
	out.resize(nf)
	var i := nf - 1
	var j := G_SAMPLES
	while i >= 0:
		out[i] = float(j) / G_SAMPLES * g.length   # the last (latest) Grounded sample the path holds at this frame
		var p: int = (from[i] as PackedInt32Array)[j]
		if p == -1:
			break
		if p == 0:
			i -= 1
		elif p == 1:
			i -= 1
			j -= 1
		else:
			j -= 1
	return out


func _mix(dir: String) -> Animation:
	var n := nat.get_animation("actor_b-p-crouch-walk-" + dir)
	var g := grounded.get_animation("frontier_legacy_crouch_walk_" + SOURCE[dir])
	var warp := _warp(nat.get_animation("actor_b-p-crouch-walk-" + WARP_FROM.get(dir, dir)), g)
	var out: Animation = n.duplicate(true)
	var err := 0.0
	for k in warp.size():
		err += rad_to_deg(_leg_err(n, minf(k / RATE, n.length), g, warp[k])) / LEGS.size()
	var swapped := 0
	for ti in range(out.get_track_count() - 1, -1, -1):
		if out.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(out.track_get_path(ti).get_concatenated_subnames())
		if not upper.has(bone):
			continue
		# parts=torso: the spine, neck and head only; the arms (clavicles down) stay Frontier's
		if str(args.get("parts", "all")) == "torso" and (bone.begins_with("l_") or bone.begins_with("r_")):
			continue
		var gi := g.find_track(out.track_get_path(ti), Animation.TYPE_ROTATION_3D)
		if gi < 0:
			continue
		var path := out.track_get_path(ti)
		out.remove_track(ti)
		var tr := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, path)
		var prev := Quaternion.IDENTITY
		for k in warp.size():
			var q := g.rotation_track_interpolate(gi, warp[k]).normalized()
			if k > 0 and prev.dot(q) < 0.0:
				q = -q
			prev = q
			out.rotation_track_insert_key(tr, minf(k / RATE, n.length), q)
		swapped += 1
	out.set_meta(&"frontier_legacy_clip", _clip(dir))
	out.set_meta(&"derivation", "Frontier crouch walk (%s): legs, hips, root and timing; upper body from %s time-warped onto it by the legs" % [n.resource_name if n.resource_name != "" else "actor_b-p-crouch-walk-" + dir, "frontier_legacy_crouch_walk_" + SOURCE[dir]])
	for m in [&"agls_original_name", &"agls_native_asset_id", &"agls_source_sha256", &"source_attribution"]:
		if g.has_meta(m):
			out.set_meta(StringName("upper_" + String(m)), g.get_meta(m))
	for m in [&"native_asset_id", &"source_attribution"]:
		if n.has_meta(m):
			out.set_meta(m, n.get_meta(m))
	print("crouch %s: %d upper tracks from Grounded %s, leg match %.2f deg" % [dir, swapped, SOURCE[dir], err / warp.size()])
	return out


func _bake() -> void:
	var lib := AnimationLibrary.new()
	var wired: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WIRED))
	for dir: String in SOURCE:
		var a := _mix(dir)
		lib.add_animation(StringName(_clip(dir)), a)
		wired.clips["actor_b-p-crouch-walk-" + dir] = {"lib": LIB_NAME, "clip": _clip(dir), "length": snappedf(a.length, 0.000001)}
	print(ResourceSaver.save(lib, OUT_LIB, ResourceSaver.FLAG_COMPRESS))
	var f := FileAccess.open(WIRED, FileAccess.WRITE)
	f.store_string(JSON.stringify(wired, "\t") + "\n")
	f.close()


func _character() -> Array:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	CharacterBodyMesh.attach(sk, aps[0] if not aps.is_empty() else null, "res://assets/character/actor_b_body.glb")
	return [n, sk, aps[0]]


func _sheet(ch: Array) -> void:
	var out := str(args.get("out", "user://crouch_mix"))
	var dir := str(args.get("dir", "fw"))
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var ap := ch[2] as AnimationPlayer
	var sk := ch[1] as Skeleton3D
	ap.speed_scale = 0.0
	ap.add_animation_library("mix", load(OUT_LIB))
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(300, 360))
	var cam: Camera3D = view.camera
	cam.fov = 38.0
	await process_frame
	await process_frame
	var frames := int(args.get("frames", 6))
	var length := nat.get_animation("actor_b-p-crouch-walk-" + dir).length
	for v in [["frontier", "actor_b/actor_b-p-crouch-walk-" + dir], ["mix", "mix/" + _clip(dir)]]:
		ap.play(v[1])
		for f in frames:
			ap.seek(float(f) / float(frames) * length, true)
			sk.force_update_all_bone_transforms()
			var base := Vector3(0, 0.7, 0)
			cam.global_position = base + Vector3(-3.0, 0.2, 0.0)
			cam.look_at(base)
			for i in 3:
				await process_frame
			view.get_texture().get_image().save_png("%s/%s_%d.png" % [out, v[0], f])
	print("SHEET ", out)
