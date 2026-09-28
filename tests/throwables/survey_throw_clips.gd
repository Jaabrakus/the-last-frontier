extends SceneTree
## Survey of Actor_B's throw clips for the throwables design (spear, tomahawk,
## atlatl). Read-only: loads characters/Actor_B.tscn and its `actor_b` library
## (Actor_B.res) and writes a JSON report. Nothing in the project is changed.
##
##   Godot --headless --path . -s tests/throwables/survey_throw_clips.gd -- --out=/abs/path.json
##
## Report:
##   clips[name]   length, track count, keyed bones and which body groups they key
##   motion[name]  full-body clips sampled at 30 Hz: right-hand prop bone path, speed,
##                 peak-speed time, prop axes (rig space: +Z = character forward, +Y = up)
##   release       release-start + release-end joined: where the hand is fastest and most
##                 forward (the frame the object should leave the hand)
##   grips         prop-bone axes in the aim / carry poses, and the prop offset that would
##                 point a long spear's shaft at the aim direction

const SCENE := "res://characters/Actor_B.tscn"
const LIB := "actor_b/"
const RATE := 30.0
const MATCH := ["throw", "molotov", "bomb", "brick", "bottle", "smoke", "nail", "move-object",
		"p-1h-", "switch-hands"]
## Full-body clips whose motion is sampled (stand, crouch, quick, blizzard, bomb lob).
const MOTION := [
	"actor_b-p-1h-aim-throw-idle", "actor_b-p-1h-aim-throw^aim",
	"actor_b-p-1h-aim-throw-release-start", "actor_b-p-1h-aim-throw-release-end",
	"actor_b-p-1h-aim-throw-release-end^idle",
	"actor_b-p-1h-aim-crouch-throw-idle", "actor_b-p-1h-aim-crouch-throw^aim",
	"actor_b-p-1h-aim-crouch-throw-release-start", "actor_b-p-1h-aim-crouch-throw-release-end",
	"actor_b-p-1h-aim-crouch-throw-release-end^idle",
	"actor_b-p-1h-aim-crouch-quick-throw-idle", "actor_b-p-1h-aim-crouch-quick-throw-release-start",
	"actor_b-p-1h-aim-crouch-quick-throw-release-end", "actor_b-p-1h-aim-crouch-quick-throw-release-end^idle",
	"actor_b-p-1h-bliz-aim-throw-release-start", "actor_b-p-1h-bliz-aim-throw-release-end",
	"actor_b-p-bomb-aim-crouch-throw-release-start", "actor_b-p-bomb-aim-crouch-throw-release-end",
	"actor_b-move-object-1h-throw", "actor_b-move-object-1h-cover-low-throw",
	"actor_b-p-1h-aim-walk-fw",
]
## [start clip, end clip] pairs joined for the release-frame analysis.
const RELEASES := [
	["stand", "actor_b-p-1h-aim-throw-release-start", "actor_b-p-1h-aim-throw-release-end"],
	["crouch", "actor_b-p-1h-aim-crouch-throw-release-start", "actor_b-p-1h-aim-crouch-throw-release-end"],
	["crouch_quick", "actor_b-p-1h-aim-crouch-quick-throw-release-start", "actor_b-p-1h-aim-crouch-quick-throw-release-end"],
	["blizzard", "actor_b-p-1h-bliz-aim-throw-release-start", "actor_b-p-1h-bliz-aim-throw-release-end"],
	["bomb_crouch_lob", "actor_b-p-bomb-aim-crouch-throw-release-start", "actor_b-p-bomb-aim-crouch-throw-release-end"],
]
## Poses for the grip table: [label, base clip, layer clip or ""].
const GRIPS := [
	["throw_aim_stand", "actor_b-p-1h-aim-throw-idle", ""],
	["throw_aim_crouch", "actor_b-p-1h-aim-crouch-throw-idle", ""],
	["throw_raise_end", "actor_b-p-1h-aim-throw^aim", ""],
	["carry_1h_stand", "actor_b-p-stealth-idle", "actor_b-p-1h-arm--part"],
	["carry_1h_crouch", "actor_b-p-crouch-idle", "actor_b-p-1h-arm-crouch--part"],
	["brick_fingers", "actor_b-p-1h-aim-throw-idle", "actor_b-p-fingers-brick"],
]

var sk: Skeleton3D
var ap: AnimationPlayer
var tree: AnimationTree
var out_path := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	var inst: Node3D = load(SCENE).instantiate()
	root.add_child(inst)
	sk = inst.get_node("Skeleton3D")
	ap = inst.get_node("AnimationPlayer")
	tree = AnimationTree.new()
	inst.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(inst)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await process_frame

	var report := {
		"source": "res://animations/Actor_B.res (library actor_b)",
		"axes": "rig space: +Z = character forward, +Y = up, -X = character right",
		"clips": {}, "motion": {}, "release": {}, "grips": {}, "missing": [],
	}
	var lib := ap.get_animation_library("actor_b")
	var names: Array = []
	for n in lib.get_animation_list():
		var s := String(n)
		for m in MATCH:
			if s.contains(m):
				names.append(s)
				break
	names.sort()
	for n in names:
		report.clips[n] = _clip_info(lib.get_animation(n))
	for n in MOTION:
		if not lib.has_animation(n):
			report.missing.append(n)
			continue
		report.motion[n] = _motion(n)
	for r in RELEASES:
		if lib.has_animation(r[1]) and lib.has_animation(r[2]):
			report.release[r[0]] = _release(r[1], r[2])
	for g in GRIPS:
		if not lib.has_animation(g[1]) or (g[2] != "" and not lib.has_animation(g[2])):
			report.missing.append(g[1] + " / " + g[2])
			continue
		report.grips[g[0]] = _grip(g[1], g[2])

	_print_summary(report)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(report, " ", false))
			f.close()
			print("WROTE ", out_path)
		else:
			printerr("cannot write ", out_path)
	print("SURVEY DONE: %d clips, %d sampled" % [report.clips.size(), report.motion.size()])
	quit(0)


# --- Clip table ------------------------------------------------------------------

func _clip_info(anim: Animation) -> Dictionary:
	var bones := {}
	var kinds := {}
	for t in anim.get_track_count():
		var p := anim.track_get_path(t)
		if p.get_subname_count() == 0:
			continue
		var b := String(p.get_subname(0))
		bones[b] = true
		var k := anim.track_get_type(t)
		kinds[k] = int(kinds.get(k, 0)) + 1
	var groups := {}
	for b in bones:
		var g := _group(b)
		groups[g] = int(groups.get(g, 0)) + 1
	var list := bones.keys()
	list.sort()
	return {
		"length": snappedf(anim.length, 0.0001), "tracks": anim.get_track_count(),
		"loop": anim.loop_mode, "bones": list.size(), "groups": groups,
		"keys_root": bones.has("root"), "keys_pelvis": bones.has("pelvis"),
		"keys_r_prop": bones.has("r_hand_prop_attachment"), "keys_l_prop": bones.has("l_hand_prop_attachment"),
		"position_tracks": int(kinds.get(Animation.TYPE_POSITION_3D, 0)),
		"rotation_tracks": int(kinds.get(Animation.TYPE_ROTATION_3D, 0)),
		"bone_list": list,
	}


func _group(b: String) -> String:
	if b == "root":
		return "root"
	if b.ends_with("prop_attachment"):
		return "r_prop" if b.begins_with("r_") else "l_prop"
	if b in ["pelvis", "pelvis_helper_grp"] or b.contains("leg") or b.contains("knee") or b.contains("ankle") \
			or b.contains("toe") or b.contains("ball") or b.contains("hip") or b.contains("thigh") \
			or b.contains("foot") or b.contains("calf") or b.contains("buttock"):
		return "pelvis_legs"
	if b.begins_with("spine") or b == "neck" or b.begins_with("head") or b.contains("neck"):
		return "spine_neck_head"
	var side := b.substr(0, 2)
	if side == "r_" or side == "l_":
		for f in ["index", "middle", "ring", "pinky", "thumb"]:
			if b.contains(f):
				return side + "fingers"
		for a in ["clav", "shoulder", "elbow", "forarm", "wrist", "palm", "arm", "bicep", "deltoid", "tricep", "scap"]:
			if b.contains(a):
				return side + "arm"
		if b.ends_with("_offset"):
			return side + "arm"
	if b.ends_with("_offset") or b.contains("holster"):
		return "root_children"
	return "face_other"


# --- Pose sampling ---------------------------------------------------------------

## Installs `clip` (optionally with `layer` over it, filtered to the layer's own tracks)
## behind a TimeSeek; _pose_at(t) then poses the rig at time t.
func _install(clip: String, layer := "") -> void:
	var bt := AnimationNodeBlendTree.new()
	var a := AnimationNodeAnimation.new()
	a.animation = LIB + clip
	bt.add_node("a", a)
	var seek := AnimationNodeTimeSeek.new()
	bt.add_node("seek", seek)
	bt.connect_node("seek", 0, "a")
	var out := "seek"
	if layer != "":
		var o := AnimationNodeAnimation.new()
		o.animation = LIB + layer
		bt.add_node("o", o)
		var b2 := AnimationNodeBlend2.new()
		b2.filter_enabled = true
		var anim := ap.get_animation(LIB + layer)
		for t in anim.get_track_count():
			b2.set_filter_path(anim.track_get_path(t), true)
		bt.add_node("mix", b2)
		bt.connect_node("mix", 0, "seek")
		bt.connect_node("mix", 1, "o")
		out = "mix"
	bt.connect_node("output", 0, out)
	tree.tree_root = bt
	tree.active = true
	if layer != "":
		tree.set("parameters/mix/blend_amount", 1.0)
	tree.advance(0.0)


func _pose_at(t: float) -> void:
	tree.set("parameters/seek/seek_request", t)
	tree.advance(0.0)


func _bone_xf(name: String) -> Transform3D:
	var i := sk.find_bone(name)
	return sk.get_bone_global_pose(i) if i >= 0 else Transform3D.IDENTITY


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _sample(clip: String, t: float) -> Dictionary:
	_pose_at(t)
	var prop := _bone_xf("r_hand_prop_attachment")
	var palm := _bone_xf("r_palm")
	var head := _bone_xf("heada")
	var lprop := _bone_xf("l_hand_prop_attachment")
	var b := prop.basis.orthonormalized()
	return {
		"t": snappedf(t, 0.0001), "r_prop": prop.origin, "r_palm": palm.origin, "head": head.origin,
		"l_prop": lprop.origin, "prop_z": b * Vector3.BACK, "prop_y": b * Vector3.UP,
	}


func _motion(clip: String) -> Dictionary:
	_install(clip)
	var anim := ap.get_animation(LIB + clip)
	var n := maxi(int(ceil(anim.length * RATE)), 1)
	var frames: Array = []
	for i in n + 1:
		frames.append(_sample(clip, minf(i / RATE, anim.length)))
	return _summarize(frames, anim.length)


func _summarize(frames: Array, length: float) -> Dictionary:
	var path: Array = []
	var best_speed := -1.0
	var best_t := 0.0
	var fwd_t := 0.0
	var fwd_z := -INF
	var top_t := 0.0
	var top_y := -INF
	for i in frames.size():
		var f: Dictionary = frames[i]
		var speed := 0.0
		if i > 0:
			var p: Dictionary = frames[i - 1]
			var dt: float = maxf(f.t - p.t, 1e-4)
			speed = (f.r_prop as Vector3).distance_to(p.r_prop) / dt
		if speed > best_speed:
			best_speed = speed
			best_t = f.t
		if (f.r_prop as Vector3).z > fwd_z:
			fwd_z = (f.r_prop as Vector3).z
			fwd_t = f.t
		if (f.r_prop as Vector3).y > top_y:
			top_y = (f.r_prop as Vector3).y
			top_t = f.t
		path.append({"t": f.t, "r_prop": _v(f.r_prop), "speed": snappedf(speed, 0.01),
				"above_head": snappedf((f.r_prop as Vector3).y - (f.head as Vector3).y, 0.001),
				"prop_z": _v(f.prop_z), "prop_y": _v(f.prop_y)})
	var first: Dictionary = frames[0]
	var last: Dictionary = frames[frames.size() - 1]
	return {
		"length": snappedf(length, 0.0001), "samples": frames.size(),
		"peak_speed_mps": snappedf(best_speed, 0.01), "peak_speed_t": snappedf(best_t, 0.0001),
		"most_forward_t": snappedf(fwd_t, 0.0001), "most_forward_z": snappedf(fwd_z, 0.001),
		"highest_t": snappedf(top_t, 0.0001), "highest_y": snappedf(top_y, 0.001),
		"hand_start": _v(first.r_prop), "hand_end": _v(last.r_prop),
		"hand_travel": _v((last.r_prop as Vector3) - (first.r_prop as Vector3)),
		"path": path,
	}


## release-start then release-end on one timeline.
func _release(start: String, end: String) -> Dictionary:
	var frames: Array = []
	var a := ap.get_animation(LIB + start)
	var b := ap.get_animation(LIB + end)
	_install(start)
	var n := maxi(int(round(a.length * RATE)), 1)
	for i in n:
		frames.append(_sample(start, i / RATE))
	_install(end)
	var m := maxi(int(ceil(b.length * RATE)), 1)
	for i in m + 1:
		var f := _sample(end, minf(i / RATE, b.length))
		f.t = a.length + f.t
		frames.append(f)
	var s := _summarize(frames, a.length + b.length)
	s["start_clip"] = start
	s["end_clip"] = end
	s["start_len"] = snappedf(a.length, 0.0001)
	s["end_len"] = snappedf(b.length, 0.0001)
	s["peak_phase_of_total"] = snappedf(float(s.peak_speed_t) / maxf(a.length + b.length, 1e-4), 0.001)
	s["peak_in"] = "start" if float(s.peak_speed_t) <= a.length + 1e-4 else "end"
	s["peak_phase_in_end"] = snappedf((float(s.peak_speed_t) - a.length) / maxf(b.length, 1e-4), 0.001)
	# Release direction: hand velocity at the peak (normalised), and its elevation.
	var k := 0
	for i in frames.size():
		if absf(float(frames[i].t) - float(s.peak_speed_t)) < 1e-4:
			k = i
	if k > 0:
		var v: Vector3 = (frames[k].r_prop as Vector3) - (frames[k - 1].r_prop as Vector3)
		s["release_dir"] = _v(v.normalized())
		s["release_elev_deg"] = snappedf(rad_to_deg(atan2(v.y, Vector2(v.x, v.z).length())), 0.1)
		s["release_hand_pos"] = _v(frames[k].r_prop)
		s["release_prop_z"] = _v(frames[k].prop_z)
	return s


func _grip(base: String, layer: String) -> Dictionary:
	_install(base, layer)
	_pose_at(0.0)
	var prop := _bone_xf("r_hand_prop_attachment")
	var b := prop.basis.orthonormalized()
	var z := b * Vector3.BACK
	var y := b * Vector3.UP
	var x := b * Vector3.RIGHT
	var head := _bone_xf("heada").origin
	var aim := Vector3.BACK
	# Model offset (child of the prop bone) that points a model built along -Z at the
	# character's aim (rig +Z) with its +Y up: world = prop * offset = looking_at(aim).
	# The firearms use the fixed half turn Basis(UP, PI); the angle between the two says how
	# far this pose's prop axes are from "prop +Z = forward".
	var desired := Basis.looking_at(aim, Vector3.UP)
	var off := (b.inverse() * desired).orthonormalized()
	var half := Basis(Vector3.UP, PI)
	var diff := rad_to_deg((half.inverse() * off).get_rotation_quaternion().get_angle())
	return {
		"base": base, "layer": layer,
		"hand": _v(prop.origin), "hand_minus_head": _v(prop.origin - head),
		"prop_z": _v(z), "prop_y": _v(y), "prop_x": _v(x),
		"prop_z_to_forward_deg": snappedf(rad_to_deg(z.angle_to(aim)), 0.1),
		"prop_z_to_up_deg": snappedf(rad_to_deg(z.angle_to(Vector3.UP)), 0.1),
		"prop_y_to_up_deg": snappedf(rad_to_deg(y.angle_to(Vector3.UP)), 0.1),
		"prop_y_to_back_deg": snappedf(rad_to_deg(y.angle_to(Vector3.FORWARD)), 0.1),
		"spear_offset_euler_deg": _v(off.get_euler() * (180.0 / PI)),
		"spear_offset_basis": [_v(off.x), _v(off.y), _v(off.z)],
		"offset_vs_half_turn_deg": snappedf(diff, 0.1),
	}


func _print_summary(r: Dictionary) -> void:
	print("--- throw-related clips (%d) ---" % r.clips.size())
	for n in r.clips:
		var c: Dictionary = r.clips[n]
		print("  %-58s %6.3fs  bones %3d  %s" % [n, c.length, c.bones, JSON.stringify(c.groups)])
	print("--- sampled motion ---")
	for n in r.motion:
		var m: Dictionary = r.motion[n]
		print("  %-58s len %.3f  peak %.2f m/s @ %.3f  fwd@%.3f  top@%.3f  travel %s" % [n, m.length,
				m.peak_speed_mps, m.peak_speed_t, m.most_forward_t, m.highest_t, str(m.hand_travel)])
	print("--- release (start + end) ---")
	for k in r.release:
		var s: Dictionary = r.release[k]
		print("  %-14s start %.3f + end %.3f  peak %.2f m/s @ %.3f (%s, phase-in-end %.3f)  elev %s deg  prop_z %s" % [k,
				s.start_len, s.end_len, s.peak_speed_mps, s.peak_speed_t, s.peak_in, s.peak_phase_in_end,
				str(s.get("release_elev_deg", "?")), str(s.get("release_prop_z", "?"))])
	print("--- grips ---")
	for k in r.grips:
		var g: Dictionary = r.grips[k]
		print("  %-18s hand-head %s  prop+Z->fwd %.0f deg, ->up %.0f  prop+Y->up %.0f  offset %s" % [k,
				str(g.hand_minus_head), g.prop_z_to_forward_deg, g.prop_z_to_up_deg, g.prop_y_to_up_deg,
				str(g.spear_offset_euler_deg)])
	if not r.missing.is_empty():
		print("missing: ", r.missing)
