extends AnimTestSuite
## Loop seams (the animation quality pass of 2026-10-10: "make sure they are smooth"): every clip the player tree loops whose
## first and last poses differ (animations/actor_b_clip_metrics.json loop false: walk-fw-rt, sprint-bw-rt and -lt, 0.12-0.24
## rad at a foot, a pop at every wrap) has its seam closed in the loaded clip by TreeBuilder.close_seam, the file untouched:
##   - the build records each seam and closes it (closed_tracks > 0), with no "pops at every wrap" warning;
##   - its last frame is its first: every rotation within 1e-3 rad, every position that does not travel within 1e-4 m;
##   - before the last SEAM_S the clip is the file's (a fresh copy of the scene, the cache ignored; 2e-3 rad: angle_to's float floor);
##   - inside the window no key step on any bone is steeper than the clip's own steepest step (the file's, inside or outside
##     the window) by more than STEP_SPREAD_RAD: the seam is spread over the window, not moved into it;
##   - a second build changes nothing (already closed: 0 tracks);
##   - the web build leaves exactly these clips uncompressed, as tools/web/seam_clips.txt lists them (a compressed track cannot be
##     closed: in the browser the loop would pop at every wrap): every clip the tree closes, with the aim-walk inputs on as well, is in
##     the list, and every listed clip is one the player plays.

## How much steeper (rad) a key step inside the window may be than the clip's own steepest: the seam (at most 0.24 rad)
## spread by smoothstep over the window's keys adds at most a fraction of it to any one step.
const STEP_SPREAD_RAD := 0.1
const ENDS_TOL_RAD := 1e-3
const ENDS_TOL_M := 1e-4


func describe() -> String:
	return "looped clips' seams closed at build: ends meet, the rest untouched, no step steeper than the clip's own"


func run(ctx: AnimTestContext) -> void:
	var packed := ResourceLoader.load(RigFixture.SCENE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var fresh := packed.instantiate() if packed != null else null
	var fap: AnimationPlayer = fresh.find_children("*", "AnimationPlayer", true, false)[0] if fresh != null else null
	if not ctx.check(fap != null, "a fresh copy of the rig's clips (the file's, the cache ignored)"):
		return
	var rig := ctx.rig()
	if rig == null:
		fresh.free()
		return
	var data := AnimGraphData.load_files()
	var idx := TreeBuilder.build(data, rig.ap, rig.sk, {})
	ctx.check(idx.errors.is_empty(), "the player tree builds (%s)" % [idx.errors])
	var seams: Dictionary = idx.loop_seams
	ctx.check(not seams.is_empty(), "the build finds the looped clips whose ends differ (%s)" % [seams.keys()])
	for clip: String in seams:
		var rec: Dictionary = seams[clip]
		var an := StringName(String(rec.get("anim", rig.qualified(clip))))     # (the clip the tree plays: an alias resolved)
		var a: Animation = rig.ap.get_animation(an) if rig.ap.has_animation(an) else null
		var o := _file_copy(fap, an)
		if not ctx.check(a != null and o != null, "%s: the clip and its file copy (%s: %s, %s)" % [clip, an, a != null, o != null]):
			continue
		var r := _measure(a, o)
		# (closed by this build, or by an earlier one in the same run: the loaded clip is shared)
		ctx.check(int(rec.get("closed_tracks", 0)) > 0 or (r.ends_rad <= ENDS_TOL_RAD and r.file_ends_rad > ENDS_TOL_RAD),
				"%s: its seam closed (%d tracks now; it was %.2f rad at %s)" % [clip, int(rec.get("closed_tracks", 0)),
				float(rec.get("rot_rad", 0.0)), rec.get("bone")])
		ctx.check(r.ends_rad <= ENDS_TOL_RAD and r.ends_m <= ENDS_TOL_M, "%s: its last frame is its first (%.5f rad, %.6f m; the file's %.3f rad)"
				% [clip, r.ends_rad, r.ends_m, r.file_ends_rad])
		ctx.check(r.before_diff <= 2e-3, "%s: before the last %.2f s it is the file's clip (%.7f)" % [clip, r.window, r.before_diff])
		var own := maxf(r.file_in_step, r.out_step)
		ctx.check(r.in_step <= own + STEP_SPREAD_RAD, "%s: no step in the window steeper than the clip's own (%.3f rad; its own %.3f, the file's there %.3f)"
				% [clip, r.in_step, own, r.file_in_step])
		ctx.info("%s (%s): wrap %.3f rad -> %.5f; steepest step in the window %.3f rad (the file's there %.3f, elsewhere %.3f)" % [clip,
				an, r.file_ends_rad, r.ends_rad, r.in_step, r.file_in_step, r.out_step])
	var idx2 := TreeBuilder.build(data, rig.ap, rig.sk, {})
	var again := 0
	for clip: String in idx2.loop_seams:
		again += int((idx2.loop_seams[clip] as Dictionary).get("closed_tracks", 0))
	ctx.check(again == 0, "a second build changes nothing (%d tracks)" % again)
	# (options.aim_walk is off in the game; with it on the tree loops three more)
	var aim := TreeBuilder.build(data, rig.ap, rig.sk, {"aim_move": true})
	var listed := _web_seam_list()
	var unlisted := []
	for found: Dictionary in [seams, aim.loop_seams]:
		for clip: String in found:
			var an := String((found[clip] as Dictionary).get("anim", ""))
			if not listed.has(an) and not unlisted.has(an):
				unlisted.append(an)
	ctx.check(not listed.is_empty() and unlisted.is_empty(), "tools/web/seam_clips.txt lists every clip the tree closes (the web build keeps them uncompressed): missing %s" % [unlisted])
	var unknown := []
	for an: String in listed:
		if not rig.ap.has_animation(StringName(an)):
			unknown.append(an)
	ctx.check(unknown.is_empty(), "every clip in tools/web/seam_clips.txt is one the player plays (%d listed): unknown %s" % [listed.size(), unknown])
	fresh.free()


## The clips tools/web/seam_clips.txt names ("<library>/<clip>" a line, # starts a comment): {name: true}.
func _web_seam_list() -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string("res://tools/web/seam_clips.txt").split("\n", false):
		var s := line.strip_edges()
		if s != "" and not s.begins_with("#"):
			out[s] = true
	return out


## The file's own copy of clip `an` ("lib/clip"): the fresh scene's, else its override library (AnimGraphData.OVERRIDE_LIBS:
## the downgraded walks) loaded with the cache ignored. Null none.
func _file_copy(fap: AnimationPlayer, an: StringName) -> Animation:
	if fap.has_animation(an):
		return fap.get_animation(an)
	var path := String(AnimGraphData.OVERRIDE_LIBS.get(String(an).get_slice("/", 0), ""))
	if path == "":
		return null
	var al := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as AnimationLibrary
	var nm := StringName(String(an).get_slice("/", 1))
	return al.get_animation(nm) if al != null and al.has_animation(nm) else null


## {ends_rad, ends_m (closed: last vs first), file_ends_rad (the file's), before_diff (largest key difference before the
## window), in_step / out_step (the steepest rotation step between keys inside / outside the window), window}.
func _measure(a: Animation, o: Animation) -> Dictionary:
	var length := a.length
	var w := minf(TreeBuilder.SEAM_S, length * 0.25)
	var out := {"ends_rad": 0.0, "ends_m": 0.0, "file_ends_rad": 0.0, "before_diff": 0.0, "in_step": 0.0, "out_step": 0.0,
			"file_in_step": 0.0, "window": w}
	for t in a.get_track_count():
		var ty := a.track_get_type(t)
		var ot := o.find_track(a.track_get_path(t), ty)
		if ot < 0 or a.track_get_key_count(t) < 2:
			continue
		if ty == Animation.TYPE_ROTATION_3D:
			var q0: Quaternion = a.track_get_key_value(t, 0)
			out.ends_rad = maxf(out.ends_rad, q0.angle_to(a.rotation_track_interpolate(t, length)))
			var f0: Quaternion = o.track_get_key_value(ot, 0)
			out.file_ends_rad = maxf(out.file_ends_rad, f0.angle_to(o.rotation_track_interpolate(ot, length)))
			for k in a.track_get_key_count(t):
				var kt := a.track_get_key_time(t, k)
				var q: Quaternion = a.track_get_key_value(t, k)
				if kt < length - w - 1e-4:
					out.before_diff = maxf(out.before_diff, q.angle_to(o.rotation_track_interpolate(ot, kt)))
				if k > 0:
					var step := q.angle_to(a.track_get_key_value(t, k - 1))
					if kt > length - w + 1e-4:
						out.in_step = maxf(out.in_step, step)
						var ok := o.track_find_key(ot, kt, Animation.FIND_MODE_APPROX)
						if ok > 0:
							out.file_in_step = maxf(out.file_in_step, (o.track_get_key_value(ot, ok) as Quaternion).angle_to(o.track_get_key_value(ot, ok - 1)))
					else:
						out.out_step = maxf(out.out_step, step)
		elif ty == Animation.TYPE_POSITION_3D:
			var p0: Vector3 = a.track_get_key_value(t, 0)
			var gap := p0.distance_to(a.position_track_interpolate(t, length))
			if gap <= TreeBuilder.SEAM_TRAVEL_M:
				out.ends_m = maxf(out.ends_m, gap)
			for k in a.track_get_key_count(t):
				var kt := a.track_get_key_time(t, k)
				if kt < length - w - 1e-4:
					out.before_diff = maxf(out.before_diff, (a.track_get_key_value(t, k) as Vector3).distance_to(o.position_track_interpolate(ot, kt)))
	return out
