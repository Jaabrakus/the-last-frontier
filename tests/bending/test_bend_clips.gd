extends SceneTree
## Our own ring-sport clips (animations_extra/Frontier_Bend.res, keyed and IK-solved in Blender by
## tools/anim_author/blender/bend_clips.py and installed by tools/anim_author/install_bend.gd; the owner, 2026-10-04: the
## throw-style moves on new own throw clips only, every clip our own: docs/animation_provenance.md, animations/SOURCE.md). No
## level: the library, Actor_B's own rig (assets/character/actor_b_body.glb) posed from the clips' tracks, and SOURCE.md.
##   Godot --headless --path . -s tests/bending/test_bend_clips.gd
##   first set   the library loads and holds the first set (earth stomp, push, rise; the throws overhand, sidearm, underhand,
##               the overhand's and the sidearm's left twins; the knocks slide and air)
##   own         every clip is own-bend-*, has the authored meta naming bend_clips.py, and carries no native_asset_id,
##               source_attribution or original_name (nor does the library); every track is a bone of the rig
##   moments     strike_s, hold_s, back_s within the clip's length, hand and mask set; a cast holds before it strikes; a throw's
##               hold_s <= 0.2 s and its strike 0.06..0.2 s after the hold (the release never laggy); a knock's strike at the
##               hit, its hold after it; knock_air's landing (up_s) between the hold and the recovery
##   place       the root comes back within 3 cm of where it started on every clip but the stomp's (a moved stance), and
##               every clip starts and ends on the same stand (the palms and the ankles within 2 cm of the first clip's start)
##   twins       a -l twin is its clip mirrored in the world: at the hold, the strike and the end, the palms and the ankles of
##               the twin are the original's mirrored across the body's middle (within 1 cm)
##   record      animations/SOURCE.md's Frontier_Bend.res table has a row naming every clip in the library
## Ends with "BEND_CLIPS PASSED" or "BEND_CLIPS FAILED" (exit 0 only on a pass; a watchdog quits 2 at LIMIT s).

const LIB := "res://animations_extra/Frontier_Bend.res"
const GLB := "res://assets/character/actor_b_body.glb"
const SOURCE_MD := "res://animations/SOURCE.md"
const LIMIT := 60.0
const FIRST_SET := ["own-bend-earth-stomp", "own-bend-earth-push", "own-bend-earth-rise", "own-bend-throw-overhand",
		"own-bend-throw-overhand-l", "own-bend-throw-sidearm", "own-bend-throw-sidearm-l", "own-bend-throw-underhand",
		"own-bend-knock-slide", "own-bend-knock-air"]
const BANNED_METAS := ["native_asset_id", "source_attribution", "original_name"]
## Clips whose stance moves for good (the root may end elsewhere).
const MOVED_STANCE := ["own-bend-earth-stomp"]
const JOINTS := ["l_palm", "r_palm", "l_ankle", "r_ankle"]

var checks := 0
var fails: Array[String] = []
var sk: Skeleton3D


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT, true, false, true).timeout.connect(func() -> void:
		print("BEND_CLIPS FAILED (watchdog)")
		quit(2))
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func _run() -> void:
	var lib := load(LIB) as AnimationLibrary
	_check(lib != null, "the library loads (%s)" % LIB)
	if lib == null:
		_end()
		return
	var body := (load(GLB) as PackedScene).instantiate() as Node3D
	root.add_child(body)
	sk = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for ap: AnimationPlayer in body.find_children("*", "AnimationPlayer", true, false):
		ap.active = false
	await process_frame
	var names: Array[String] = []
	for n: StringName in lib.get_animation_list():
		names.append(String(n))
	names.sort()
	print("BEND_CLIPS library: ", names)
	# first set
	for want: String in FIRST_SET:
		_check(want in names, "first set: %s in the library" % want)
	# own
	for m: String in BANNED_METAS:
		_check(not lib.has_meta(StringName(m)), "the library carries no %s" % m)
	for nm in names:
		var a := lib.get_animation(StringName(nm))
		_check(nm.begins_with("own-bend-"), "%s: an own-bend- name" % nm)
		_check(String(a.get_meta(&"authored", "")).contains("bend_clips.py"), "%s: authored names bend_clips.py" % nm)
		for m: String in BANNED_METAS:
			_check(not a.has_meta(StringName(m)), "%s: no %s meta" % [nm, m])
		var unknown := []
		for i in a.get_track_count():
			if sk.find_bone(String(a.track_get_path(i).get_concatenated_subnames())) < 0:
				unknown.append(String(a.track_get_path(i)))
		_check(unknown.is_empty(), "%s: every track a bone of the rig %s" % [nm, str(unknown)])
		_moments(nm, a)
		_place(nm, a)
	# a common stand at both ends
	if not names.is_empty():
		var ref := _joints(lib.get_animation(StringName(names[0])), 0.0)
		for nm in names:
			var a := lib.get_animation(StringName(nm))
			for t in [0.0, a.length]:
				var j := _joints(a, t)
				var worst := 0.0
				for k: String in JOINTS:
					worst = maxf(worst, (j[k] as Vector3).distance_to(ref[k]))
				_check(worst < 0.02, "%s: on the stand at %.2f s (the palms and ankles off by %.3f m)" % [nm, t, worst])
	# twins
	for nm in names:
		if not nm.ends_with("-l"):
			continue
		var orig := nm.trim_suffix("-l")
		_check(orig in names, "%s: its original %s is there" % [nm, orig])
		if not orig in names:
			continue
		var a := lib.get_animation(StringName(orig))
		var b := lib.get_animation(StringName(nm))
		_check(is_equal_approx(a.length, b.length), "%s: the original's length" % nm)
		for key in ["hold_s", "strike_s", "back_s"]:
			_check(is_equal_approx(float(a.get_meta(key, -1.0)), float(b.get_meta(key, -1.0))), "%s: the original's %s" % [nm, key])
		_check(String(b.get_meta(&"hand", "")) == {"r": "l", "l": "r"}.get(String(a.get_meta(&"hand", "")), String(a.get_meta(&"hand", ""))),
				"%s: the other hand (%s)" % [nm, b.get_meta(&"hand", "")])
		for t in [float(a.get_meta(&"hold_s", 0.0)), float(a.get_meta(&"strike_s", 0.0)), a.length * 0.6, a.length]:
			var ja := _joints(a, t)
			var jb := _joints(b, t)
			var worst := 0.0
			for k: String in JOINTS:
				var other := ("r_" if k.begins_with("l_") else "l_") + k.substr(2)
				var mirrored := ja[other] as Vector3
				mirrored.x = -mirrored.x
				worst = maxf(worst, mirrored.distance_to(jb[k]))
			_check(worst < 0.01, "%s: the mirror of %s at %.2f s (off by %.4f m)" % [nm, orig, t, worst])
	# record
	var md := FileAccess.get_file_as_string(SOURCE_MD)
	var rows := _table_names(md)
	_check(not rows.is_empty(), "SOURCE.md has the Frontier_Bend.res table")
	for nm in names:
		_check(nm in rows, "SOURCE.md records %s" % nm)
	body.queue_free()
	_end()


func _moments(nm: String, a: Animation) -> void:
	for key in ["hold_s", "strike_s", "back_s", "hand", "mask"]:
		_check(a.has_meta(StringName(key)), "%s: has %s" % [nm, key])
	if not (a.has_meta(&"hold_s") and a.has_meta(&"strike_s") and a.has_meta(&"back_s")):
		return
	var hold := float(a.get_meta(&"hold_s"))
	var strike := float(a.get_meta(&"strike_s"))
	var back := float(a.get_meta(&"back_s"))
	for v in [hold, strike, back]:
		_check(v >= 0.0 and v <= a.length + 1e-4, "%s: %.3f s within the length %.3f" % [nm, v, a.length])
	_check(String(a.get_meta(&"mask", "")) == "full", "%s: mask full" % nm)
	_check(String(a.get_meta(&"hand", "")) in ["r", "l", "both", "foot_r", "foot_l"], "%s: hand %s" % [nm, a.get_meta(&"hand", "")])
	if nm.contains("-knock-"):
		_check(strike < hold and hold < back, "%s: the hit, then the hold, then the recovery (%.2f %.2f %.2f)" % [nm, strike, hold, back])
		if a.has_meta(&"up_s"):
			var up := float(a.get_meta(&"up_s"))
			_check(up > hold and up <= back, "%s: the landing between the hold and the recovery (%.2f)" % [nm, up])
	else:
		_check(hold <= strike and strike < back, "%s: the hold, the strike, the recovery (%.2f %.2f %.2f)" % [nm, hold, strike, back])
	if nm.contains("-throw-"):
		_check(hold <= 0.2 + 1e-4, "%s: the throw's hold %.3f <= 0.2 s" % [nm, hold])
		var gap := strike - hold
		_check(gap >= 0.06 - 1e-4 and gap <= 0.2 + 1e-4, "%s: the release %.3f s after the hold (0.06..0.2)" % [nm, gap])


func _place(nm: String, a: Animation) -> void:
	var tr := -1
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i).get_concatenated_subnames()) == "root":
			tr = i
	_check(tr >= 0, "%s: keys the root's place" % nm)
	if tr < 0 or nm in MOVED_STANCE:
		return
	var d := a.position_track_interpolate(tr, 0.0).distance_to(a.position_track_interpolate(tr, a.length))
	_check(d < 0.03, "%s: the root back within 3 cm (%.3f m)" % [nm, d])


## The joints' skeleton-space places with the clip's keyed bones set at t (the rest elsewhere).
func _joints(a: Animation, t: float) -> Dictionary:
	sk.reset_bone_poses()
	for i in a.get_track_count():
		var b := sk.find_bone(String(a.track_get_path(i).get_concatenated_subnames()))
		if b < 0:
			continue
		match a.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(b, a.rotation_track_interpolate(i, t))
			Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(b, a.position_track_interpolate(i, t))
	var out := {}
	for k: String in JOINTS:
		out[k] = sk.get_bone_global_pose(sk.find_bone(k)).origin
	return out


## The own-bend-* names in SOURCE.md's Frontier_Bend.res section (its table's rows).
func _table_names(md: String) -> Array[String]:
	var out: Array[String] = []
	var inside := false
	var re := RegEx.create_from_string("`(own-bend-[a-z0-9-]+)`")
	for line in md.split("\n"):
		if line.begins_with("## "):
			inside = line.contains("Frontier_Bend.res")
			continue
		if inside and line.begins_with("|"):
			for m in re.search_all(line):
				out.append(m.get_string(1))
	return out


func _end() -> void:
	if fails.is_empty():
		print("BEND_CLIPS: %d checks" % checks)
		print("BEND_CLIPS PASSED")
		quit(0)
	else:
		print("BEND_CLIPS: %d of %d checks failed" % [fails.size(), checks])
		print("BEND_CLIPS FAILED")
		quit(1)
