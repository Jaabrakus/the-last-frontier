extends SceneTree
## Mocap downgrader (user 2026-09-30: "a mocap downgrader into the animations, to make it look less mocap like": "more stiff on
## upper body", "loosen the perfect sync"). Takes a clip and gives its UPPER body two things, the legs, hips and every position
## track staying exactly as they are (so the feet, the plant phases and the IK are untouched):
##  - STIFFER: each upper-body bone's rotation keeps only a share (`amp`) of its swing about the cycle's mean rotation: the spine,
##    neck and head wobble less, the collarbones and shoulders calmer, the arms least changed (they carry the gait's rhythm).
##  - LOOSER SYNC: each bone follows the body a little late (`lag` seconds, growing up the spine and down the arm, the left arm a
##    touch later than the right), so the body no longer moves as one perfectly coordinated whole: the chest trails the hips,
##    the head trails the chest, the hands trail the arms.
## A clip that loops (a gait cycle) wraps its lag round the cycle; one that does not holds its first and last pose.
##   lineup:  Godot --path . -s tools/anim_author/mocap_downgrade.gd -- sheet out=<dir> [clip=own-jog-fw-k100] [frames=8]
##            frames of the original and the mild / medium / strong versions at the same moments of the cycle, two views
##   library: Godot --headless --path . -s tools/anim_author/mocap_downgrade.gd -- bake level=medium [clip=...]
##            writes user://mocap_downgrade.res (clip "<clip>--<level>"), nothing wired into the game

const FPS := 30.0
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
## Per bone group: swing kept (1 = untouched) and lag (s) at strength 1. Groups are matched on the bone's name (without l_ / r_).
const GROUPS := {
	"spinea": [0.80, 0.020], "spineb": [0.75, 0.030], "spinec": [0.70, 0.045], "spined": [0.65, 0.060],
	"neck": [0.55, 0.070], "heada": [0.50, 0.090], "headb": [0.50, 0.100],
	"clavicle": [0.70, 0.050], "scapula": [0.70, 0.050], "trap": [0.70, 0.050],
	"shoulder": [0.85, 0.060], "deltoid": [0.85, 0.060], "elbow": [0.90, 0.080], "wrist": [0.90, 0.100], "palm": [0.90, 0.100],
}
## Extra lag (s) of the left side over the right: the two arms are not quite in step.
const LEFT_EXTRA_S := 0.015
## Levels: how much of the groups' effect is applied, and how much of the swing reduction (amp towards 1 - (1 - amp) * k).
const LEVELS := {"mild": [0.6, 0.6], "medium": [1.0, 1.0], "mediumstrong": [1.25, 1.2], "strong": [1.5, 1.4],
	# (user 2026-09-30: "do away with some loosen, make the torso more stiff, remove the little mocap jitters"): a third of the lag, the
	# torso's swing reduced the most, and a light smoothing that takes the frame-to-frame shake out
	"stiff": {"lag": 0.35, "amp": 1.2, "torso_amp": 1.75, "sigma": 1.5},
	# jitter only, for the one-shot moves (vaults, climbs): no lag, no swing change, the ends of each clip exactly kept
	"dejitter": {"lag": 0.0, "amp": 0.0, "torso_amp": 0.0, "sigma": 1.5}}
## The torso: the bones whose swing "stiff" reduces the most.
const TORSO := ["spinea", "spineb", "spinec", "spined", "neck", "heada", "headb"]

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	var clip_name := str(args.get("clip", "own-jog-fw-k100"))
	var src := _load_clip(clip_name)
	if src == null:
		push_error("no clip " + clip_name)
		quit(1)
		return
	if args.has("bake"):
		var out := AnimationLibrary.new()
		var level := str(args.get("level", "medium"))
		out.add_animation(StringName(clip_name + "--" + level), downgrade(src, level, bool(args.get("loop", true))))
		print(ResourceSaver.save(out, "user://mocap_downgrade.res"))
		quit()
	elif args.has("sheet"):
		_sheet.call_deferred(src, clip_name)


func _load_clip(name: String) -> Animation:
	for path in ["res://animations_extra/Frontier_Locomotion.res", "res://animations/Actor_B.res"]:
		var lib := load(path) as AnimationLibrary
		if lib != null and lib.has_animation(name):
			return lib.get_animation(name)
	return null


## Gaussian smoothing of a rotation's samples (sigma in frames): each sample the weighted average of its neighbours (aligned to it). A loop
## wraps; a one-shot keeps its first and last samples exactly and eases the smoothing in over the first and last 2 sigma frames, so the
## clip still meets its neighbours where it did.
static func smooth_samples(q: Array[Quaternion], sigma: float, loops: bool) -> Array[Quaternion]:
	var n := q.size()
	var kk := int(ceil(2.5 * sigma))
	var w: Array[float] = []
	for d in range(-kk, kk + 1):
		w.append(exp(-float(d * d) / (2.0 * sigma * sigma)))
	var out: Array[Quaternion] = []
	var m := n - 1 if loops else n      # (a loop's last sample is its first)
	for i in n:
		var c := q[i]
		var acc := Vector4.ZERO
		for d in range(-kk, kk + 1):
			var j := i + d
			if loops:
				j = posmod(j, m)
			else:
				j = clampi(j, 0, n - 1)
			var s := q[j] if q[j].dot(c) >= 0.0 else -q[j]
			acc += Vector4(s.x, s.y, s.z, s.w) * w[d + kk]
		acc = acc.normalized()
		var sm := Quaternion(acc.x, acc.y, acc.z, acc.w)
		if not loops:
			var edge := clampf(float(mini(i, n - 1 - i)) / float(2 * kk), 0.0, 1.0)
			sm = c.slerp(sm if sm.dot(c) >= 0.0 else -sm, edge)
		out.append(sm.normalized())
	if loops:
		out[n - 1] = out[0]
	return out


static func _group(bone: String) -> String:
	if not (bone.begins_with("l_") or bone.begins_with("r_")):
		return bone if GROUPS.has(bone) else ""
	var part := bone.substr(2)
	for g: String in GROUPS:
		if part == g:
			return g
	return ""


## The clip with its upper body stiffened and loosened at `level` (mild / medium / strong).
static func downgrade(src: Animation, level: String, loops: bool) -> Animation:
	var lv: Variant = LEVELS[level]
	var lag_k: float = float(lv.lag) if lv is Dictionary else float(lv[0])
	var amp_k: float = float(lv.amp) if lv is Dictionary else float(lv[1])
	var torso_k: float = float(lv.torso_amp) if lv is Dictionary else amp_k
	var sigma: float = float(lv.sigma) if lv is Dictionary else 0.0
	var out: Animation = src.duplicate(true)
	var n := int(round(src.length * FPS))
	for ti in range(out.get_track_count()):
		if out.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
			continue
		var path := out.track_get_path(ti)
		var bone := String(path.get_concatenated_subnames())
		var g := _group(bone)
		if g == "":
			continue
		var k := torso_k if TORSO.has(g) else amp_k
		var amp: float = clampf(1.0 - (1.0 - float((GROUPS[g] as Array)[0])) * k, 0.05, 1.0)
		var lag: float = float((GROUPS[g] as Array)[1]) * lag_k
		if bone.begins_with("l_"):
			lag += LEFT_EXTRA_S * lag_k
		# the lagged samples, the shake taken out, then the swing about the mean
		var samples: Array[Quaternion] = []
		var prev := Quaternion.IDENTITY
		for i in n + 1:
			var t := float(i) / FPS
			var tl := fposmod(t - lag, src.length) if loops else clampf(t - lag, 0.0, src.length)
			var q := src.rotation_track_interpolate(ti, tl).normalized()
			if i > 0 and prev.dot(q) < 0.0:
				q = -q
			prev = q
			samples.append(q)
		if sigma > 0.0:
			samples = smooth_samples(samples, sigma, loops)
		var acc := Vector4.ZERO
		for i in n:
			var q := samples[i] if samples[i].dot(samples[0]) >= 0.0 else -samples[i]
			acc += Vector4(q.x, q.y, q.z, q.w)
		acc = acc.normalized()
		var mean := Quaternion(acc.x, acc.y, acc.z, acc.w)
		while out.track_get_key_count(ti) > 0:
			out.track_remove_key(ti, 0)
		prev = Quaternion.IDENTITY
		for i in n + 1:
			var q := samples[i]
			if amp < 0.999:
				q = mean.slerp(q if q.dot(mean) >= 0.0 else -q, amp).normalized()
			if i > 0 and prev.dot(q) < 0.0:
				q = -q
			prev = q
			out.rotation_track_insert_key(ti, minf(float(i) / FPS, src.length), q)
	out.set_meta(&"authored", "Frontier: the upper body stiffened and loosened (%s; tools/anim_author/mocap_downgrade.gd)" % level)
	return out


func _sheet(src: Animation, clip_name: String) -> void:
	var out := str(args.get("out", "user://mocap_sheet"))
	DirAccess.make_dir_recursive_absolute(out)
	var loops := bool(args.get("loop", true))
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
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	CharacterBodyMesh.attach(sk, aps[0] if not aps.is_empty() else null, "res://assets/character/actor_b_body.glb")
	var ap := aps[0] as AnimationPlayer
	ap.speed_scale = 0.0
	var lib := AnimationLibrary.new()
	lib.add_animation(&"original", src)
	for level: String in LEVELS:
		lib.add_animation(StringName(level), downgrade(src, level, loops))
	ap.add_animation_library("v", lib)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(260, 360))
	var cam: Camera3D = view.camera
	cam.fov = 38.0
	await process_frame
	await process_frame
	var frames := int(args.get("frames", 8))
	var views := {"side": Vector3(-3.3, 0.25, 0.0), "front": Vector3(-1.6, 0.35, 2.9)}
	for vname: String in views:
		for v in ["original", "mild", "medium", "strong"]:
			ap.play("v/" + v)
			for f in frames:
				ap.seek(float(f) / float(frames) * src.length, true)
				sk.force_update_all_bone_transforms()
				var base := Vector3(0, 0.95, 0)
				cam.global_position = base + views[vname]
				cam.look_at(base)
				for i in 3:
					await process_frame
				view.get_texture().get_image().save_png("%s/%s_%s_%d.png" % [out, vname, v, f])
	print("SHEET ", out)
	quit()
