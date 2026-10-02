extends SceneTree
## Runs the mocap downgrader (mocap_downgrade.gd) over the graph's looping body cycles and wires the results
## (user 2026-09-30: "that looks good apply it to all of them"): the walks, the sprints and the crouch walks, forward, backward and to
## the sides. The jogs get it in author_locomotion.gd (their starts and stops are built from them). Left alone: the weapon aim and hold
## cycles (they carry the aim), the idles and turns, and every one-shot (vaults, swings, climbs: a stiffened action lands its hands
## elsewhere). The legs, hips and timing are the graph's own, so its metrics (plant phases, travel) stand.
##   Godot --headless --path . -s tools/anim_author/mocap_downgrade_all.gd
## writes animations_extra/Frontier_Downgraded.res and data/anim_author/downgraded_clips.json (read by AnimGraphData.apply_downgraded_clips).

const Downgrade := preload("res://tools/anim_author/mocap_downgrade.gd")
const LEVEL := "stiff"
const NATIVE := "res://animations/Actor_B.res"
const GRAPH := "res://animations/actor_b_graph.json"
const METRICS := "res://animations/actor_b_clip_metrics.json"
const OUT_LIB := "res://animations_extra/Frontier_Downgraded.res"
const WIRED := "res://data/anim_author/downgraded_clips.json"
const LOCO := "res://data/anim_author/locomotion_clips.json"
## Cycles the metrics flag as no loop for a foot's seam only (the upper body closes): the walk to the right, r_ball 0.12 rad.
const FORCE_LOOP := ["actor_b-p-walk-fw-rt"]
const PATTERN := "^actor_b-p-(walk|sprint|crouch-walk)-(fw|bw)(-lt|-rt)?$"
## The long gun's clips whose hands squeeze it while holding it (user 2026-10-01: "a quick double check squeeze of the rifle with the
## hands after a reload or an equip ... look for other parts with rifle that may be mocap references and stiffen them or edit them
## out"; found by the scan of every rifle clip's finger curl): each hand's grip made one steady close or open on the clip's own
## timing (steady_grip()), the arms de-jittered. The traversal's rifle parts keep theirs (a hand there really lets go to plant).
const STEADY := ["actor_b-lg-stealth-draw^idle--arm-r", "actor_b-lg-stealth-idle^grab--arm-r", "actor_b-lg-stealth-stow^idle--arm-r",
		"actor_b-p-crouch-hr-fw--rifle",
		# (the graph's reload steps still play in the tree under our own reload's pose, MusketReload; as it fades out at the end their
		# squeezes showed through: the right hand let go and gripped again)
		"actor_b-p-rifle-idle-aim-reload-begin--part", "actor_b-p-rifle-idle-aim-reload-mid--part",
		"actor_b-p-rifle-idle-aim-reload-over--part", "actor_b-p-rifle-idle-crouch-aim-reload-begin--part",
		"actor_b-p-rifle-idle-crouch-aim-reload-mid--part", "actor_b-p-rifle-idle-crouch-aim-reload-over--part",
		# (then "look at each weapon equip": the scan of every weapon's equip, grab and holster clips; the tomahawk's and the
		# pistol's draw are clean)
		"actor_b-p-stealth-stow-p^idle--arm-r", "actor_b-p-bow-draw-grab^idle--part", "actor_b-p-bow-stow-grab^idle--part",
		"actor_b-p-crouch-idle^p-grab--arm-r"]
const FINGERS := ["index", "middle", "ring", "pinky", "thumb"]
## The carry's grip (its fingers): where the equip's hand closes to and stays, rather than closing hard on the grab and letting go
## to it through the draw (the left hand 8 -> 237 -> 132 deg of curl: a clamp then a loosen). Clip -> {side: which end becomes it}.
const CARRY_GRIP := "actor_b-p-rifle-run-arms"
## The left arm's reach for the gun smoothed over ARM_SMOOTH frames (30 fps) in the equip (user 2026-10-01: "the left hand on the
## rifle equip needs to not do that little mocap thing": it bobbed beside the gun, caught it low, slipped up the forestock and slid back
## down to the carry's place, a pat in a quarter of a second): one reach and one slide, its first and last frames the clip's own.
const ARM_SMOOTH := {"actor_b-lg-stealth-idle^grab--arm-r": 3.0}
## ... and in the draw itself, still a pat after smoothing (the hand caught the gun, slipped up it and slid back to the carry's place):
## the left arm goes straight from where the grab leaves it to the carry's hold in one eased move, there by this share of the clip.
const ARM_STRAIGHT := {"actor_b-lg-stealth-draw^idle--arm-r": 0.75}
## ... and the left hand on the forestock from this far into the draw (s) to its end, where the clip's last frame holds it (user
## 2026-10-01: "before the animation settles they take the hand off the rifle, or the rifle jitters up": the hand was off the gun
## 23-40 cm as it came round, 180 deg in 0.13 s, and kicked up 4 cm), the right arm (the gun) smoothed over 2 frames.
const HOLD_ON := {"actor_b-lg-stealth-draw^idle--arm-r": 0.45}
const RIGHT_ARM := ["r_clavicle", "r_shoulder", "r_elbow", "r_wrist"]
## The pistol's reload (the source graph's revolver reload: user 2026-10-01 "we should just keep that revolver one but make it
## less like a revolver"): the pistol flipped muzzle up to empty a cylinder and snapped back, rolled on its side to close it and
## flicked up: the right arm and the pistol's hold calmed (CALM_SIGMA frames of smoothing) and their swing shrunk to CALM_KEEP of
## its own about the line from the clip's first pose to its last (the clip still begins and ends where it did, on the aim).
## clip -> how much of its swing it keeps; the middle step, the rounds put into the cylinder (user 2026-10-01: "remove the
## revolver part of the reload putting bullets in the cylinder"), keeps none: a still hold eased from its first pose to its last.
const CALM := {"actor_b-p-pistol-rev-reload-begin--part": 0.4, "actor_b-p-pistol-rev-reload-mid--part": 0.0,
		"actor_b-p-pistol-rev-reload-over--part": 0.4}
## Both arms: the right holds the pistol, the left worked the cylinder (swung it out, fed it, shut it).
const CALM_BONES := ["r_clavicle", "r_shoulder", "r_elbow", "r_wrist", "r_hand_prop_attachment",
		"l_clavicle", "l_shoulder", "l_elbow", "l_wrist"]
const CALM_SIGMA := 4.0
## The aim stances (user 2026-10-01, from a lineup): the bow's aim with the spine rounded like the jog's, 2/3 of the way to the
## jog's hunch (its spine averaged over the cycle), the arms and the head kept where they point ("2/3 jog spine is nice"); the
## pistol's aim in the bow's stance mirrored (the body side-on, twisted as the bow's), its right arm the pistol aim's own arm
## (one-handed: the left hangs at the side in the game, PlayerAnim one_hand_aim). Both their graph clips' lengths.
const BOW_AIM := "actor_b-p-bow-aim-idle"
const PISTOL_AIM := "actor_b-p-pistol-aim-idle"
const JOG_LIB := "res://animations_extra/Frontier_Locomotion.res"
const JOG_CLIP := "own-jog-fw-k100"
const BOW_SPINE_K := 0.65
const PISTOL_BOW_ARM := "own-pistol-bow-arm"
const BOW_AIM_CROUCH := "actor_b-p-bow-aim-crouch-idle"
const SPINE := ["spinea", "spineb", "spinec", "spined"]
const LEFT_ARM := ["l_clavicle", "l_shoulder", "l_elbow", "l_wrist"]
const TO_CARRY := {"actor_b-lg-stealth-idle^grab--arm-r": {"l": "last"}, "actor_b-lg-stealth-draw^idle--arm-r": {"l": "both"},
		"actor_b-lg-stealth-stow^idle--arm-r": {"l": "first"}}


func _initialize() -> void:
	var lib := load(NATIVE) as AnimationLibrary
	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GRAPH))
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(METRICS)).clips
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOCO)).clips
	var re := RegEx.create_from_string(PATTERN)
	var ch := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(ch)
	var sk := ch.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var out := AnimationLibrary.new()
	var wired := {}
	var names: Array = graph.clips.keys()
	names.sort()
	for name: String in names:
		if re.search(name) == null or own.has(name) or not lib.has_animation(name):
			continue
		var c: Dictionary = graph.clips[name]
		if bool(c.get("additive", false)) or not (bool(metrics.get(name, {}).get("loop", false)) or FORCE_LOOP.has(name)):
			continue
		var src := lib.get_animation(name)
		if src.length < 0.5:
			continue
		# (the sprints "clean": the head and shoulders held still, user 2026-10-01; the walks and crouch walks LEVEL)
		var a: Animation = Downgrade.downgrade(src, "clean" if name.contains("-sprint-") else LEVEL, true)
		if name.contains("-sprint-"):
			Downgrade.stabilize_head(a, sk)
		out.add_animation(StringName(name), a)
		wired[name] = {"lib": "frontier_downgraded", "clip": name, "length": snappedf(a.length, 0.000001)}
		print("  ", name, " ", snappedf(a.length, 0.001), " s")
	for name: String in STEADY:
		if not lib.has_animation(name) or not graph.clips.has(name):
			continue
		var src := lib.get_animation(name)
		var a: Animation = Downgrade.downgrade(steady_grip(src, lib.get_animation(CARRY_GRIP), TO_CARRY.get(name, {})), "dejitter", false)
		if ARM_SMOOTH.has(name):
			_smooth_bones(a, LEFT_ARM, float(ARM_SMOOTH[name]))
		if ARM_STRAIGHT.has(name):
			_straight_bones(a, LEFT_ARM, float(ARM_STRAIGHT[name]))
		if HOLD_ON.has(name):
			_smooth_bones(a, RIGHT_ARM, 2.0)
			_hold_on(a, sk, float(HOLD_ON[name]))
		out.add_animation(StringName(name), a)
		wired[name] = {"lib": "frontier_downgraded", "clip": name, "length": snappedf(a.length, 0.000001)}
		print("  steady grip ", name)
	for name: String in CALM:
		if not lib.has_animation(name) or not graph.clips.has(name):
			continue
		var a: Animation = Downgrade.downgrade(lib.get_animation(name), "dejitter", false)
		_smooth_bones(a, CALM_BONES, CALM_SIGMA)
		_shrink_bones(a, CALM_BONES, float(CALM[name]))
		out.add_animation(StringName(name), a)
		wired[name] = {"lib": "frontier_downgraded", "clip": name, "length": snappedf(a.length, 0.000001)}
		print("  calmed ", name)
	# the bow's aim with the head upright (Downgrade.untilt_head); its aim walks are author_locomotion.gd's, which do the same
	var bow_re := RegEx.create_from_string("^actor_b-p-bow-(aim|blocked-aim)")
	for name: String in names:
		if bow_re.search(name) == null or name.ends_with("--add") or own.has(name) or not lib.has_animation(name):
			continue
		if bool(graph.clips[name].get("additive", false)):
			continue
		var a: Animation = lib.get_animation(name).duplicate(true)
		Downgrade.untilt_head(a, sk)
		out.add_animation(StringName(name), a)
		wired[name] = {"lib": "frontier_downgraded", "clip": name, "length": snappedf(a.length, 0.000001)}
		print("  head upright ", name)
	# the aim stances (on the head-upright bow aim made above)
	var bow_up: Animation = out.get_animation(BOW_AIM) if out.has_animation(BOW_AIM) else lib.get_animation(BOW_AIM)
	var jog := (load(JOG_LIB) as AnimationLibrary).get_animation(JOG_CLIP)
	# (the spine rounded like the jog's, _jog_spine, BOW_SPINE_K, was liked first; then, user 2026-10-02: "for the bow standing i
	# like the upper body placement of the crouch": the crouched aim's upper body on the standing legs)
	# (the crouched aim's upper body, _crouch_upper, was tried and taken back the same day: "nevermind on the bow standing")
	var bow_round := _jog_spine(bow_up, jog, sk, BOW_SPINE_K)
	if out.has_animation(BOW_AIM):
		out.remove_animation(BOW_AIM)
	out.add_animation(BOW_AIM, bow_round)
	wired[BOW_AIM] = {"lib": "frontier_downgraded", "clip": BOW_AIM, "length": snappedf(bow_round.length, 0.000001)}
	print("  jog spine ", BOW_AIM)
	# (the pistol's aim in the bow's stance mirrored with the arm grafted on, _bow_stance, was taken back, user 2026-10-01: the
	# graph's aim layers, made for its own pose, bent the grafted arm off the aim. Now the body alone is twisted under the
	# pistol aim's own arm: "i want the stand aim similar to the mirror bow animation where the body twist")
	var pis := _twisted_stance(bow_up, lib.get_animation(PISTOL_AIM), sk)
	out.add_animation(PISTOL_AIM, pis)
	wired[PISTOL_AIM] = {"lib": "frontier_downgraded", "clip": PISTOL_AIM, "length": snappedf(pis.length, 0.000001)}
	print("  twisted stance ", PISTOL_AIM)
	# the bow's aim mirrored, whole, for the pistol's straight arm standing (PlayerAnim takes its right arm: the bow arm, held
	# out straight; user 2026-10-01 "i liked the bow because the arm was straight and pointed to cursor"); not wired in the graph
	out.add_animation(PISTOL_BOW_ARM, TravMoveMirror.mirror_clip(bow_up, sk))
	print("  mirrored bow arm ", PISTOL_BOW_ARM)
	print(ResourceSaver.save(out, OUT_LIB, ResourceSaver.FLAG_COMPRESS), " ", wired.size(), " clips")
	var f := FileAccess.open(WIRED, FileAccess.WRITE)
	f.store_string(JSON.stringify({"about": "Looping body cycles with the upper body stiffened and loosened (tools/anim_author/mocap_downgrade_all.gd, level " + LEVEL + "), the long gun's clips with steady grips (STEADY) and the pistol's reload calmed (CALM): graph clip name -> the library and clip played instead (AnimGraphData.apply_downgraded_clips). Same length and legs as the graph's own.", "clips": wired}, "\t") + "\n")
	f.close()
	quit()


## The clip with each hand's fingers closing or opening once (no squeezes): the hand's curl (its finger joints' turn from rest)
## fitted to one steady rise or fall (pool-adjacent-violators: the curl as near as it can be while it only goes the one way, from
## the first frame's to the last's), and the fingers blended from the first frame's grip to the last's by how far along that the
## fitted curl is. The grab or the release happens when the clip has it; the back-and-forth on the way goes.
static func steady_grip(src: Animation, carry: Animation = null, to_carry := {}) -> Animation:
	var a: Animation = src.duplicate(true)
	var fps := 30.0
	var n := int(round(a.length * fps))
	if n < 2:
		return a
	for side in ["l", "r"]:
		var tracks: Array = []
		for ti in a.get_track_count():
			if a.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
				continue
			var b := String(a.track_get_path(ti).get_concatenated_subnames())
			if b.begins_with(side + "_") and FINGERS.any(func(f: String) -> bool: return b.contains(f)):
				tracks.append(ti)
		if tracks.is_empty():
			continue
		var first := {}
		var last := {}
		for ti: int in tracks:
			first[ti] = a.rotation_track_interpolate(ti, 0.0).normalized()
			last[ti] = a.rotation_track_interpolate(ti, a.length).normalized()
			# (an end that is the carry's grip: the carry clip's fingers there)
			var end := str(to_carry.get(side, ""))
			if end != "" and carry != null:
				var ci := carry.find_track(a.track_get_path(ti), Animation.TYPE_ROTATION_3D)
				if ci >= 0:
					var g := carry.rotation_track_interpolate(ci, 0.0).normalized()
					if end in ["first", "both"]:
						first[ti] = g
					if end in ["last", "both"]:
						last[ti] = g
		# the curl measured from the first frame's grip (how far the hand has moved from where it began)
		var curve: Array[float] = []
		for f in n + 1:
			var t := minf(f / fps, a.length)
			var c := 0.0
			for ti: int in tracks:
				c += a.rotation_track_interpolate(ti, t).normalized().angle_to(first[ti])
			curve.append(c)
		var total := 0.0
		for ti: int in tracks:
			total += (first[ti] as Quaternion).angle_to(last[ti])
		var fit := _isotonic(curve)
		for ti: int in tracks:
			var times: Array[float] = []
			for k in a.track_get_key_count(ti):
				times.append(a.track_get_key_time(ti, k))
			while a.track_get_key_count(ti) > 0:
				a.track_remove_key(ti, 0)
			for f in n + 1:
				var t := minf(f / fps, a.length)
				var w := clampf(fit[f] / total, 0.0, 1.0) if total > 1e-3 else 0.0
				var q := (first[ti] as Quaternion).slerp(last[ti], w)
				a.rotation_track_insert_key(ti, t, q)
	return a


## The non-decreasing sequence nearest `v` (least squares; pool-adjacent-violators).
static func _isotonic(v: Array[float]) -> Array[float]:
	var vals: Array[float] = []
	var cnt: Array[int] = []
	for x in v:
		vals.append(x)
		cnt.append(1)
		while vals.size() > 1 and vals[vals.size() - 2] > vals[vals.size() - 1]:
			var c1 := cnt[cnt.size() - 2]
			var c2 := cnt[cnt.size() - 1]
			var m := (vals[vals.size() - 2] * c1 + vals[vals.size() - 1] * c2) / float(c1 + c2)
			vals.pop_back()
			cnt.pop_back()
			vals[vals.size() - 1] = m
			cnt[cnt.size() - 1] = c1 + c2
	var out: Array[float] = []
	for i in vals.size():
		for k in cnt[i]:
			out.append(vals[i])
	return out


## The bones' tracks smoothed (Gaussian, `sigma` frames at 30 fps) with the first and last frames kept: the smoothed path is turned
## back onto the clip's own at its two ends, the correction eased across the clip (a one-shot's ends are where it meets the next).
static func _smooth_bones(a: Animation, bones: Array, sigma: float) -> void:
	var fps := 30.0
	var n := int(round(a.length * fps))
	if n < 3:
		return
	for b: String in bones:
		var ti := a.find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
		if ti < 0:
			continue
		var q: Array[Quaternion] = []
		for f in n + 1:
			var s := a.rotation_track_interpolate(ti, minf(f / fps, a.length)).normalized()
			if f > 0 and q[f - 1].dot(s) < 0.0:
				s = -s
			q.append(s)
		var kk := int(ceil(2.5 * sigma))
		var sm: Array[Quaternion] = []
		for i in n + 1:
			var acc := Vector4.ZERO
			for d in range(-kk, kk + 1):
				var j := clampi(i + d, 0, n)
				var s2 := q[j] if q[j].dot(q[i]) >= 0.0 else -q[j]
				acc += Vector4(s2.x, s2.y, s2.z, s2.w) * exp(-float(d * d) / (2.0 * sigma * sigma))
			acc = acc.normalized()
			sm.append(Quaternion(acc.x, acc.y, acc.z, acc.w))
		var e0 := sm[0].inverse() * q[0]
		var e1 := sm[n].inverse() * q[n]
		while a.track_get_key_count(ti) > 0:
			a.track_remove_key(ti, 0)
		for i in n + 1:
			var u := float(i) / float(n)
			var corr := e0.slerp(e1, u)
			a.rotation_track_insert_key(ti, minf(i / fps, a.length), (sm[i] * corr).normalized())


## The bones' swing shrunk to `keep` of its own: each frame's turn taken that far from the eased line between the first frame's
## and the last's (smoothstep) toward its own (0: the line alone, 1: unchanged); the ends stay.
static func _shrink_bones(a: Animation, bones: Array, keep: float) -> void:
	var fps := 30.0
	var n := int(round(a.length * fps))
	if n < 2:
		return
	for b: String in bones:
		var ti := a.find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
		if ti < 0:
			continue
		var q: Array[Quaternion] = []
		for f in n + 1:
			var s := a.rotation_track_interpolate(ti, minf(f / fps, a.length)).normalized()
			if f > 0 and q[f - 1].dot(s) < 0.0:
				s = -s
			q.append(s)
		while a.track_get_key_count(ti) > 0:
			a.track_remove_key(ti, 0)
		for i in n + 1:
			var u := float(i) / float(n)
			var line := q[0].slerp(q[n], u * u * (3.0 - 2.0 * u))
			a.rotation_track_insert_key(ti, minf(i / fps, a.length), line.slerp(q[i], keep).normalized())


## The bones' tracks replaced by one eased turn from their first frame to their last (smoothstep, done by `by` of the clip).
static func _straight_bones(a: Animation, bones: Array, by: float) -> void:
	var fps := 30.0
	var n := int(round(a.length * fps))
	if n < 2:
		return
	for b: String in bones:
		var ti := a.find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
		if ti < 0:
			continue
		var q0 := a.rotation_track_interpolate(ti, 0.0).normalized()
		var q1 := a.rotation_track_interpolate(ti, a.length).normalized()
		if q0.dot(q1) < 0.0:
			q1 = -q1
		while a.track_get_key_count(ti) > 0:
			a.track_remove_key(ti, 0)
		for i in n + 1:
			var u := smoothstep(0.0, by, float(i) / float(n))
			a.rotation_track_insert_key(ti, minf(i / fps, a.length), q0.slerp(q1, u).normalized())


## The left hand held where the clip's last frame has it on the gun (the right hand's prop bone's frame) from `from_s` on, eased in
## over 0.1 s: each frame the arm solved (two bones, the elbow keeping its side) to the wrist's place and turned to its turn there.
static func _hold_on(a: Animation, sk: Skeleton3D, from_s: float) -> void:
	var fps := 30.0
	var n := int(round(a.length * fps))
	var prop := sk.find_bone("r_hand_prop_attachment")
	var sh := sk.find_bone("l_shoulder")
	var el := sk.find_bone("l_elbow")
	var wr := sk.find_bone("l_wrist")
	if prop < 0 or sh < 0 or el < 0 or wr < 0:
		return
	_pose(a, sk, a.length)
	var rel := sk.get_bone_global_pose(prop).affine_inverse() * sk.get_bone_global_pose(wr)
	var keys := {sh: [], el: [], wr: []}
	for i in n + 1:
		var t := minf(i / fps, a.length)
		_pose(a, sk, t)
		var w := smoothstep(from_s, from_s + 0.1, t)
		if w > 0.0:
			var tgt := sk.get_bone_global_pose(prop) * rel
			TraversalIK.solve_live(sk, sh, el, wr, sk.get_bone_global_pose(wr).origin, tgt.origin, w)
			var eg := sk.get_bone_global_pose(el)
			var cur := sk.get_bone_global_pose(wr).basis.get_rotation_quaternion()
			var g := cur.slerp(tgt.basis.get_rotation_quaternion(), w)
			sk.set_bone_pose_rotation(wr, (eg.basis.get_rotation_quaternion().inverse() * g).normalized())
		for b: int in keys:
			(keys[b] as Array).append([t, sk.get_bone_pose_rotation(b)])
	for b: int in keys:
		var ti := a.find_track(NodePath("Skeleton3D:" + sk.get_bone_name(b)), Animation.TYPE_ROTATION_3D)
		if ti < 0:
			continue
		while a.track_get_key_count(ti) > 0:
			a.track_remove_key(ti, 0)
		var prev := Quaternion()
		for k: Array in keys[b]:
			var q: Quaternion = k[1]
			if prev.dot(q) < 0.0:
				q = -q
			prev = q
			a.rotation_track_insert_key(ti, float(k[0]), q)


## The skeleton set to the clip's pose at `t` (its tracks; the rest elsewhere).
static func _pose(a: Animation, sk: Skeleton3D, t: float) -> void:
	sk.reset_bone_poses()
	for ti in a.get_track_count():
		var b := sk.find_bone(String(a.track_get_path(ti).get_concatenated_subnames()))
		if b < 0:
			continue
		match a.track_get_type(ti):
			Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(b, a.rotation_track_interpolate(ti, t))
			Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(b, a.position_track_interpolate(ti, t))


# --- the aim stances ------------------------------------------------------------------------------------------

## Bone `b` and every bone under it (parents first).
static func _below(sk: Skeleton3D, b: String) -> Array:
	var out_b := []
	var i := sk.find_bone(b)
	if i < 0:
		return out_b
	var stack := [i]
	while not stack.is_empty():
		var j: int = stack.pop_front()
		out_b.append(sk.get_bone_name(j))
		for c in sk.get_bone_children(j):
			stack.append(c)
	return out_b


static func _g(sk: Skeleton3D, bones: Array) -> Dictionary:
	sk.force_update_all_bone_transforms()
	var d := {}
	for bn: String in bones:
		var b := sk.find_bone(bn)
		if b >= 0:
			d[bn] = sk.get_bone_global_pose(b).basis.get_rotation_quaternion()
	return d


## The bones turned in the world as `g` has them, parents first (their places follow their parents).
static func _set_g(sk: Skeleton3D, g: Dictionary, order: Array) -> void:
	for bn: String in order:
		if not g.has(bn):
			continue
		sk.force_update_all_bone_transforms()
		var b := sk.find_bone(bn)
		var p := sk.get_bone_parent(b)
		var pg := sk.get_bone_global_pose(p).basis.get_rotation_quaternion() if p >= 0 else Quaternion()
		sk.set_bone_pose_rotation(b, (pg.inverse() * (g[bn] as Quaternion)).normalized())


## A clip of the skeleton's poses: `sample(t)` poses it at each frame of `length`; the bones in `bones` keyed (rotations), the
## root's place too.
static func _bake_frames(sk: Skeleton3D, length: float, bones: Array, sample: Callable) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	var fps := 30.0
	var n := int(round(length * fps))
	var tr := {}
	for bn: String in bones:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:" + bn))
		tr[bn] = t
	var rp := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(rp, NodePath("Skeleton3D:root"))
	var root := sk.find_bone("root")
	var last := {}
	for f in n + 1:
		var t := minf(f / fps, length)
		sample.call(t)
		for bn: String in bones:
			var q := sk.get_bone_pose_rotation(sk.find_bone(bn)).normalized()
			if last.has(bn) and (last[bn] as Quaternion).dot(q) < 0.0:
				q = -q
			last[bn] = q
			a.rotation_track_insert_key(tr[bn], t, q)
		a.position_track_insert_key(rp, t, sk.get_bone_pose_position(root))
	a.set_meta(&"authored", "Frontier: tools/anim_author/mocap_downgrade_all.gd (aim stance from the graph's own clips)")
	return a


static func _keyed(a: Animation) -> Array:
	var out_b := []
	for ti in a.get_track_count():
		if a.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
			out_b.append(String(a.track_get_path(ti).get_concatenated_subnames()))
	return out_b


## The aim with its spine turned `k` of the way to the jog's (averaged over its cycle), the arms and the head kept.
static func _jog_spine(src: Animation, jog: Animation, sk: Skeleton3D, k: float) -> Animation:
	var avg := {}
	for bn: String in SPINE:
		var ti := jog.find_track(NodePath("Skeleton3D:" + bn), Animation.TYPE_ROTATION_3D)
		if ti < 0:
			continue
		var ref := jog.rotation_track_interpolate(ti, 0.0)
		var acc := Vector4.ZERO
		for i in 12:
			var q := jog.rotation_track_interpolate(ti, jog.length * i / 12.0)
			if q.dot(ref) < 0.0:
				q = -q
			acc += Vector4(q.x, q.y, q.z, q.w)
		acc = acc.normalized()
		avg[bn] = Quaternion(acc.x, acc.y, acc.z, acc.w)
	var kept_roots := ["r_clavicle", "l_clavicle", "neck"]
	var bones := _keyed(src)
	for bn: String in SPINE + kept_roots:
		if not bones.has(bn):
			bones.append(bn)
	return _bake_frames(sk, src.length, bones, func(t: float) -> void:
		_pose(src, sk, t)
		var keep := _g(sk, kept_roots)
		for bn: String in avg:
			var b := sk.find_bone(bn)
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(avg[bn], k).normalized())
		_set_g(sk, keep, kept_roots))


## The pistol's aim in the bow's stance mirrored, at the pistol aim's length: the body the mirrored bow aim's, the right arm
## (the clavicle down, the prop bone with it) turned in the world as the pistol aim has it.
static func _bow_stance(bow: Animation, pistol: Animation, sk: Skeleton3D) -> Animation:
	var mir := TravMoveMirror.mirror_clip(bow, sk)
	var arm := _below(sk, "r_clavicle")
	var bones := _keyed(mir)
	for bn: String in arm:
		if not bones.has(bn):
			bones.append(bn)
	var scale := mir.length / maxf(pistol.length, 1e-3)
	return _bake_frames(sk, pistol.length, bones, func(t: float) -> void:
		_pose(pistol, sk, t)
		var g := _g(sk, arm)
		_pose(mir, sk, fposmod(t * scale, mir.length))
		_set_g(sk, g, arm))


## The pistol's aim with the body twisted as the bow's stance mirrored: the hips, the legs, the spine and the left arm the mirrored
## bow aim's (time-fitted to the pistol aim's length); the right arm the pistol aim's own, untouched below its clavicle (only the
## clavicle turned so it stays where the pistol aim has it: the arm's own bones keep their turns, so the graph's aim layers on
## them, the pitch additives and the hand, still fit); the head and the arm's driver bones (root children) kept as they were.
static func _twisted_stance(bow: Animation, pistol: Animation, sk: Skeleton3D) -> Animation:
	var mir := TravMoveMirror.mirror_clip(bow, sk)
	var kept := ["r_clavicle", "neck"]
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		if n.begins_with("r_") and n.ends_with("_offset"):
			kept.append(n)
	var from_bow := []
	for bn: String in _keyed(mir):
		if bn == "root" or bn == "upper_base" or SPINE.has(bn) or bn.begins_with("l_") \
				or bn.contains("upper_leg") or bn.contains("knee") or bn.contains("ankle") or bn.contains("heel") or bn.contains("ball"):
			from_bow.append(bn)
	var bones := _keyed(pistol)
	for bn: String in from_bow + kept:
		if not bones.has(bn):
			bones.append(bn)
	var scale := mir.length / maxf(pistol.length, 1e-3)
	var root_i := sk.find_bone("root")
	return _bake_frames(sk, pistol.length, bones, func(t: float) -> void:
		_pose(pistol, sk, t)
		var g := _g(sk, kept)
		# the mirrored bow's body, its bones only
		var bt := fposmod(t * scale, mir.length)
		for ti in mir.get_track_count():
			var bn := String(mir.track_get_path(ti).get_concatenated_subnames())
			if not from_bow.has(bn):
				continue
			var b := sk.find_bone(bn)
			if mir.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(b, mir.rotation_track_interpolate(ti, bt))
			elif mir.track_get_type(ti) == Animation.TYPE_POSITION_3D and b == root_i:
				sk.set_bone_pose_position(b, mir.position_track_interpolate(ti, bt))
		_set_g(sk, g, kept))


## The standing aim with the crouched aim's upper body: every bone from upper_base up (the spine, the neck and head, the arms) and
## the arms' driver bones turned in the world as the crouched aim has them (time-fitted to the standing clip), on the standing
## clip's hips and legs.
static func _crouch_upper(stand: Animation, crouch: Animation, sk: Skeleton3D) -> Animation:
	var upper := _below(sk, "upper_base")
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		if n.ends_with("_offset") and not upper.has(n):
			upper.append(n)
	var bones := _keyed(stand)
	for bn: String in upper:
		if not bones.has(bn):
			bones.append(bn)
	var scale := crouch.length / maxf(stand.length, 1e-3)
	return _bake_frames(sk, stand.length, bones, func(t: float) -> void:
		_pose(crouch, sk, fposmod(t * scale, crouch.length))
		var g := _g(sk, upper)
		_pose(stand, sk, t)
		_set_g(sk, g, upper))
