extends AnimTestSuite
## WP2 clip-metrics suite (plan section 5.4, section 10 `test_metrics.gd`, WP2 acceptance).
##
## Checks animations/actor_b_clip_metrics.json (written by tools/anim_graph/measure_clips.gd) and the
## day-1 fixture tests/anim/fixtures/mini_metrics.json:
##   - both validate against tools/anim_graph/schema/actor_b_clip_metrics.schema.json (GDScript
##     validator below: the subset listed in the schema's description); provenance fields present;
##     library_sha256 matches animations/Actor_B.res; rest == null-add when measured
##   - speeds within +-3 % of the corrected values (plan D8 / section 2): walk-fw 1.263, run-fw 3.344,
##     run-bw 2.474, sprint-fw 4.244, crouch-walk-fw 1.637, walk-bw 1.475; aim-walk-fw 0.545 +- 0.03
##     (rifle, bow, pistol)
##   - headings of every graph bank clip (roles fw/fw_lt/fw_rt/bw/bw_lt/bw_rt and aim_move banks):
##     lt +90, rt -90, fw 0, bw 180, each +-5 deg, on the contract field travel.heading_deg whatever
##     estimator filled it; the pinned speeds must come from method A itself (estimator method_a); a
##     fallback-estimated bank clip (the sprint strafes: method_a_run2) must be within 10 % of the
##     speed of its native lt/rt mirror clip
##   - travel.kind is "cyclic" exactly for cyclic clips, and travel.cyclic is the loop flag the graph
##     export gives the clip wherever an entry plays it (cyclic_source graph_loop); every bank clip
##     (roles and aim_move) is cyclic
##   - every WP10 start / stop / reversal role clip has a body_profile (one sample per clip sample,
##     starting at 0) in which no step moves more than 2 cm against the clip's net direction (method B
##     failed this on 42 of 66; a doctored reversal is the negative control) and the peak speed stays
##     within 1.3x the role's bank clip speed (or the Blender dump's own profile peaks past it too: an
##     authored overshoot; or the clip has a fidelity_warning; both reported); starts speed up and stops
##     slow down; at least one foot has a contact interval or onset
##   - clips.*.fidelity_warning is set exactly for the dumped clips whose travel, worst heel/ball sample
##     or body_profile diverge from the Blender dump past the thresholds (recomputed here; reported)
##   - every bank clip has >= 1 plant onset per foot, and every one alternates left/right
##   - bone sets: upper has spinea..spined, neck, heada, clavicles, arm chain, upper_base and every
##     *_offset root child, and none of root, lower_base, pelvis, legs, holsters; hands has both prop
##     bones; stabilized = upper_base + the *_offset root children; lower has pelvis and the legs
##   - pitch tables: strictly monotonic within [-max_valid_down, max_valid_up] and within the solve
##     range [-solve_down, solve_up]; 7 table points re-evaluated with an independently built
##     AnimationTree (RigFixture) within 0.05 deg; inverse error <= 1.5 deg for every target in
##     -60..+60 step 5 that the solve range reaches; the solve range is the data (monotonic) range, so
##     no yaw-drift rule narrows today's aim range; data_limits names exactly the sides where the data
##     stops inside +-60 deg (reported)
##   - gt_check median <= 0.1 mm, p95 <= 1.5 mm (worst clips reported)
##   - heel_z samples equal an AnimationTree single-clip pose (RigFixture.pose_of) within 0.1 mm
##   - determinism / currency: measure_clips run in process reproduces both committed files (compare():
##     byte for byte apart from the meta.rig_sha256 / meta.godot_version stamps; if not, a second run
##     tells a stale file from a non-deterministic tool); without the Blender dump the gt-derived
##     fields are skipped and reported as such, never as "stale"
##   - measure() with a missing Blender dump returns without errors, gt_check.skipped set, and the CLI
##     summary line formats (the path that used to crash)

const METRICS := "res://animations/actor_b_clip_metrics.json"
const FIXTURE := "res://tests/anim/fixtures/mini_metrics.json"
const SCHEMA := "res://tools/anim_graph/schema/actor_b_clip_metrics.schema.json"
const TOOL := "res://tools/anim_graph/measure_clips.gd"
const GRAPH := "res://animations/actor_b_graph.json"
const MINI_GRAPH := "res://tools/anim_graph/fixtures/mini_graph.json"
const LIBRARY_RES := "res://animations/Actor_B.res"

## Corrected clip speeds (plan D8, section 2), GA/vmm/bl/dump3.jsonl + an.py method A.
const SPEEDS := {"actor_b-p-walk-fw": 1.263, "actor_b-p-run-fw": 3.344, "actor_b-p-run-bw": 2.474,
		"actor_b-p-sprint-fw": 4.244, "actor_b-p-crouch-walk-fw": 1.637, "actor_b-p-walk-bw": 1.475}
const SPEED_TOL := 0.03
const AIM_WALK := ["actor_b-p-rifle-aim-walk-fw", "actor_b-p-bow-aim-walk-fw", "actor_b-p-pistol-aim-walk-fw"]
const AIM_WALK_INFO := ["actor_b-p-rifle-aim-crouch-walk-fw", "actor_b-p-bow-aim-crouch-walk-fw", "actor_b-p-pistol-aim-crouch-walk-fw"]
const AIM_WALK_SPEED := 0.545
const AIM_WALK_TOL := 0.03
const HEADING_TOL := 5.0
const BANK_ROLES := {"fw": 0.0, "fw_lt": 90.0, "fw_rt": -90.0, "bw": 180.0, "bw_lt": 90.0, "bw_rt": -90.0}
## Fallback-estimated bank clip vs its native lt/rt mirror (native mirror pairs differ by up to ~5 %).
const MIRROR_SPEED_TOL := 0.10
## WP10 roles whose clips are one-shot (plan WP10; graph roles start_* / stop_* / rev_*).
const WP10_ROLE_PREFIXES := ["start_", "stop_", "rev_"]
## body_profile on start_ / stop_ clips: largest step against the clip's net direction (m), and peak
## speed vs the role's bank clip speed.
const PROFILE_BACK_M := 0.02
const PROFILE_PEAK_RATIO := 1.3
## fidelity_warning thresholds, restated from meta.method.fidelity (the test recomputes the flags).
const FIDELITY_REL := 0.05
const FIDELITY_HEADING_DEG := 10.0
const FIDELITY_MIN_SPEED := 0.1
const FIDELITY_GT_MM := 20.0
const FIDELITY_PROFILE_M := 0.05
const MISSING_PAP := "/nonexistent/test_metrics_missing_pap"
const UPPER_MUST := ["upper_base", "spinea", "spineb", "spinec", "spined", "neck", "heada", "l_clavicle", "r_clavicle",
		"l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist"]
const UPPER_NOT := ["root", "lower_base", "pelvis", "l_upper_leg", "l_knee", "l_ankle", "l_heel", "l_ball",
		"r_upper_leg", "r_knee", "r_ankle", "r_heel", "r_ball", "holster_pistol", "holster_melee", "holster_long"]
const LOWER_MUST := ["pelvis", "l_upper_leg", "l_knee", "l_ankle", "l_heel", "l_ball", "r_upper_leg", "r_knee",
		"r_ankle", "r_heel", "r_ball"]
const PITCH_RANGE_DEG := 60.0
const PITCH_TARGET_STEP := 5.0
const PITCH_INV_TOL := 1.5
const PITCH_TABLE_TOL := 0.05
const GT_MEDIAN_MM := 0.1
const GT_P95_MM := 1.5
const HEEL_TOL := 1e-4

var _re := {}


func describe() -> String:
	return "WP2: clip metrics (schema, speeds, headings, plants, cyclic, start/stop profiles, fidelity, masks, pitch inverse, gt_check, heel samples, determinism)"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	var schema := _load(ctx, SCHEMA)
	var m := _load(ctx, METRICS)
	var fx := _load(ctx, FIXTURE)
	if schema.is_empty() or m.is_empty():
		return
	var graph := _load(ctx, GRAPH) if FileAccess.file_exists(GRAPH) else {}

	# --- schema and provenance --------------------------------------------------------------------
	for pair in [["animations/actor_b_clip_metrics.json", m], ["tests/anim/fixtures/mini_metrics.json", fx]]:
		if (pair[1] as Dictionary).is_empty():
			continue
		var errs := validate(pair[1], schema, schema)
		ctx.check(errs.is_empty(), "%s validates against the schema (%d error(s)%s)" % [pair[0], errs.size(),
				(": " + "; ".join(errs.slice(0, 5))) if not errs.is_empty() else ""])
	ctx.check(not fx.is_empty() and fx.meta.has("fixture"), "mini_metrics.json is marked as a fixture (meta.fixture)")
	var neg := m.duplicate(true)
	neg.bone_sets.erase("hands")
	neg.clips["actor_b-p-run-fw"].travel.speed = -1.0
	ctx.check(validate(neg, schema, schema).size() >= 2, "validator rejects a broken document (negative control)")
	ctx.check(String(m.meta.library_sha256) == FileAccess.get_sha256(LIBRARY_RES),
			"metrics were measured on the current animations/Actor_B.res (library_sha256)")
	ctx.check(bool(m.meta.rest.ok) and float(m.meta.rest.max_rot) <= 1e-6 and float(m.meta.rest.max_pos) <= 1e-6,
			"measured with rest == null-add (BindRest: rot %s rad, pos %s m)" % [m.meta.rest.max_rot, m.meta.rest.max_pos])
	ctx.check(String(m.meta.authorization).begins_with("owner-stated"), "owner-stated authorization recorded in meta")
	ctx.check(String(m.meta.clip_source) == ("graph" if not graph.is_empty() else "builtin"),
			"clip list source is %s" % m.meta.clip_source)

	# --- clip coverage ---------------------------------------------------------------------------
	var clips: Dictionary = m.clips
	if not graph.is_empty():
		var missing := []
		for c: String in graph.get("clips", {}):
			if not clips.has(c):
				missing.append(c)
		ctx.check(missing.is_empty(), "every clip in actor_b_graph.json is measured (%d missing%s)" % [missing.size(),
				(": " + ", ".join(missing.slice(0, 5))) if not missing.is_empty() else ""])

	# --- speeds ----------------------------------------------------------------------------------
	for c: String in SPEEDS:
		var t: Variant = _travel(clips, c)
		if t == null:
			ctx.fail("%s has travel metrics" % c)
			continue
		var want: float = SPEEDS[c]
		ctx.check(absf(float(t.speed) - want) <= SPEED_TOL * want and t.estimator == "method_a",
				"%s speed %.3f m/s within 3 %% of %.3f (%+.1f %%), estimator %s" % [
				c, t.speed, want, 100.0 * (float(t.speed) - want) / want, t.estimator])
		ctx.metric("speed/" + c, t.speed)
	for c: String in AIM_WALK:
		var t: Variant = _travel(clips, c)
		if t == null:
			ctx.fail("%s has travel metrics" % c)
			continue
		ctx.near(float(t.speed), AIM_WALK_SPEED, AIM_WALK_TOL, "%s speed %.3f m/s ~ %.3f" % [c, t.speed, AIM_WALK_SPEED])
	for c: String in AIM_WALK_INFO:
		var t: Variant = _travel(clips, c)
		if t != null:
			ctx.info("%s speed %.3f m/s (crouch aim-walk; not pinned by the plan)" % [c, t.speed])

	# --- headings and plants of every bank clip --------------------------------------------------
	var bank := _bank_clips(graph)
	# The thrown weapons' aim-walk banks (THROW; played only with options.aim_walk, off): their plant
	# pattern is the clips' own and is reported, not gated.
	var throw_walk := {}
	for key: String in graph.get("aim_move", {}):
		if String(graph.get("profiles", {}).get(key.get_slice("/", 0), {}).get("clip_set", "")) == "throw":
			for role: String in graph.aim_move[key]:
				var r: Variant = graph.aim_move[key][role]
				if r is Dictionary and r.get("clip", null) is String:
					throw_walk[r.clip] = true
	ctx.check(bank.size() >= 24, "bank clip list has the 4 modes x 6 directions at least (%d clips)" % bank.size())
	var heading_bad := []
	var plant_bad := []
	var alt_bad := []
	var mirror_bad := []
	var fallback := []
	var bank_kind_bad := []
	for c: String in bank:
		var t: Variant = _travel(clips, c)
		if t == null:
			heading_bad.append("%s (no travel)" % c)
			continue
		if t.kind != "cyclic" or not bool(t.cyclic):
			bank_kind_bad.append("%s (kind %s, %s, seam %.3f m)" % [c, t.kind, t.cyclic_source, t.seam_m])
		var want: float = bank[c]
		var h := float(t.heading_deg)
		var err := absf(wrapf(h - want, -180.0, 180.0))
		if err > HEADING_TOL:
			heading_bad.append("%s %.1f vs %.0f (%s)" % [c, h, want, t.estimator])
		if t.quality != "native":
			var mirror := _mirror(c)
			var mt: Variant = _travel(clips, mirror)
			var line := "%s: %s %.3f m/s %.1f deg (%s Hz, runs >= %d); contact %.3f m/s %.1f deg" % [c, t.estimator, t.speed, h,
					t.method_rate, t.min_run, t.contact.speed, t.contact.heading_deg]
			if mt != null and mt.quality == "native":
				var rel := (float(t.speed) - float(mt.speed)) / float(mt.speed)
				line += "; native mirror %s %.3f m/s (%+.1f %%)" % [mirror.trim_prefix("actor_b-p-"), mt.speed, 100.0 * rel]
				if absf(rel) > MIRROR_SPEED_TOL:
					mirror_bad.append(line)
			else:
				mirror_bad.append(line + " (no native mirror clip)")
			var bl: Variant = clips[c].blender
			if bl is Dictionary and bl.rel_diff != null:
				line += "; Blender dump, same estimator, %+.3f %%" % (100.0 * float(bl.rel_diff))
			fallback.append(line)
		var p: Variant = clips[c].plant
		if not (p is Dictionary) or (p.l as Array).is_empty() or (p.r as Array).is_empty():
			plant_bad.append(c)
		elif not _alternates(p.l, p.r):
			if throw_walk.has(c):
				ctx.info("thrown weapons' aim-walk clip %s: plants L%s R%s do not alternate one pair per cycle (clip data; aim_walk option off)" % [c, p.l, p.r])
			else:
				alt_bad.append("%s L%s R%s" % [c, p.l, p.r])
	ctx.check(heading_bad.is_empty(), "%d bank clips: travel.heading_deg lt +90 / rt -90 / fw 0 / bw 180 within %.0f deg%s" % [bank.size(), HEADING_TOL,
			(" (off: " + "; ".join(heading_bad) + ")") if not heading_bad.is_empty() else ""])
	ctx.check(mirror_bad.is_empty(), "%d fallback-estimated bank clip(s) within %.0f %% of their native lt/rt mirror's speed%s" % [
			fallback.size(), 100.0 * MIRROR_SPEED_TOL, (" (" + "; ".join(mirror_bad) + ")") if not mirror_bad.is_empty() else ""])
	for f in fallback:
		ctx.info("fallback travel estimator (no method-A run of 3 at the clip rate): " + f)
	ctx.check(plant_bad.is_empty(), "every bank clip has >= 1 plant onset per foot%s" % [
			(" (none: " + ", ".join(plant_bad) + ")") if not plant_bad.is_empty() else ""])
	ctx.check(bank_kind_bad.is_empty(), "every bank clip (roles and aim_move) is cyclic, travel.kind cyclic (a playback-rate reference)%s" % [
			(" (" + "; ".join(bank_kind_bad) + ")") if not bank_kind_bad.is_empty() else ""])
	ctx.check(alt_bad.is_empty(), "every bank clip alternates left/right plants, one pair per cycle%s" % [
			(" (" + "; ".join(alt_bad) + ")") if not alt_bad.is_empty() else ""])
	var popped := []
	for c: String in bank:
		var t: Variant = _travel(clips, c)
		if t != null and float(t.seam_m) >= 0.02:
			popped.append("%s %.3f m" % [c.trim_prefix("actor_b-p-"), t.seam_m])
	if not popped.is_empty():
		ctx.info("looped bank clips whose heel/ball first and last samples do not meet (the loop pops there; measured cyclic from the graph flag): " + ", ".join(popped))

	# --- one-shot clips (WP10 starts, stops, reversals) ------------------------------------------
	var kind_bad := []
	for c: String in clips:
		var t: Variant = _travel(clips, c)
		if t != null and String(t.kind) != ("cyclic" if bool(t.cyclic) else "one_shot_mean"):
			kind_bad.append("%s (%s, cyclic %s)" % [c, t.kind, t.cyclic])
	ctx.check(kind_bad.is_empty(), "travel.kind is cyclic for cyclic clips and one_shot_mean (not a rate reference) otherwise%s" % [
			(" (" + ", ".join(kind_bad.slice(0, 5)) + ")") if not kind_bad.is_empty() else ""])
	if not graph.is_empty():
		var loops := {}
		_graph_loops(graph, loops)
		var loop_bad := []
		var n_loop := 0
		for c: String in clips:
			var t: Variant = _travel(clips, c)
			if t == null:
				continue
			if loops.has(c):
				n_loop += 1
				if bool(t.cyclic) != bool(loops[c]) or t.cyclic_source != "graph_loop":
					loop_bad.append("%s (cyclic %s from %s, graph loop %s)" % [c, t.cyclic, t.cyclic_source, loops[c]])
			elif t.cyclic_source != "feet_seam" or bool(t.cyclic) != (float(t.seam_m) < 0.02):
				loop_bad.append("%s (no graph entry plays it: cyclic %s from %s, seam %.3f)" % [c, t.cyclic, t.cyclic_source, t.seam_m])
		ctx.check(loop_bad.is_empty(), "travel.cyclic is the graph's loop flag for the %d measured clips a graph entry plays (feet seam otherwise)%s" % [
				n_loop, (" (" + "; ".join(loop_bad.slice(0, 5)) + ")") if not loop_bad.is_empty() else ""])
	var wp10 := _wp10_clips(graph)
	if not graph.is_empty():
		ctx.check(wp10.size() >= 60, "graph roles name the WP10 start / stop / reversal clips (%d distinct)" % wp10.size())
	var prof_bad := []
	var trend_bad := []
	var back_bad := []
	var peak_bad := []
	var peak_authored := []
	var foot_none := []
	var foot_one := []
	var no_rest := []
	var covs := PackedFloat64Array()
	var n_ss := 0
	var worst_back := 0.0
	var worst_back_clip := ""
	var worst_ratio := 0.0
	var worst_ratio_clip := ""
	for c: String in wp10:
		if not clips.has(c):
			prof_bad.append("%s (not measured)" % c)
			continue
		var cm: Dictionary = clips[c]
		var t: Variant = _travel(clips, c)
		if t != null and t.kind != "one_shot_mean":
			prof_bad.append("%s (travel.kind %s)" % [c, t.kind])
		var bp: Variant = cm.body_profile
		var n := int(cm.sample_count)
		if not (bp is Dictionary) or (bp.fwd as Array).size() != n or (bp.side as Array).size() != n \
				or (bp.speed as Array).size() != n or float(bp.fwd[0]) != 0.0 or float(bp.side[0]) != 0.0:
			prof_bad.append("%s (body_profile %s)" % [c, "missing" if not (bp is Dictionary) else "malformed"])
			continue
		covs.append(float(bp.coverage))
		var sp: Array = bp.speed
		var kinds: Dictionary = wp10[c].kinds
		# No step against the clip's net direction (method B's spurious reversals). The reversal clips
		# (quickstop^*) start from the turn and run one way, so they are held to it too.
		var bk := profile_back(bp)
		if float(bk.step) < worst_back:
			worst_back = bk.step
			worst_back_clip = c
		if float(bk.step) < -PROFILE_BACK_M:
			back_bad.append("%s k=%d %.3f m" % [c.trim_prefix("actor_b-p-"), bk.k, bk.step])
		if kinds.has("start") or kinds.has("stop"):
			n_ss += 1
		# Peak speed vs the role's bank clip.
		var bank_speed := 0.0
		for bc: String in wp10[c].bank:
			var bt: Variant = _travel(clips, bc)
			if bt != null:
				bank_speed = maxf(bank_speed, float(bt.speed))
		var peak := 0.0
		for x in sp:
			peak = maxf(peak, float(x))
		if bank_speed > 0.0:
			var ratio := peak / bank_speed
			if ratio > worst_ratio:
				worst_ratio = ratio
				worst_ratio_clip = c
			if ratio > PROFILE_PEAK_RATIO:
				var bl: Variant = cm.blender
				var line := "%s peak %.2f m/s = %.2fx its bank clip's %.2f" % [c.trim_prefix("actor_b-p-"), peak, ratio, bank_speed]
				if bl is Dictionary and bl.profile_peak_speed != null and float(bl.profile_peak_speed) > PROFILE_PEAK_RATIO * bank_speed:
					peak_authored.append(line + " (the Blender dump's profile peaks at %.2f = %.2fx: authored)" % [
							float(bl.profile_peak_speed), float(bl.profile_peak_speed) / bank_speed])
				elif cm.fidelity_warning != null:
					peak_authored.append(line + " (library divergence: the dump's profile peaks at %s; fidelity_warning)" % [
							("%.2f" % float(bl.profile_peak_speed)) if bl is Dictionary and bl.profile_peak_speed != null else "?"])
				else:
					peak_bad.append(line)
		if kinds.has("start") or kinds.has("stop"):
			var q := maxi(1, sp.size() / 4)
			var first := _mean(sp.slice(0, q))
			var last := _mean(sp.slice(sp.size() - q))
			if kinds.has("start") and "idle^" in c and not (last > first):
				trend_bad.append("%s (start) %.2f -> %.2f m/s" % [c, first, last])
			elif kinds.has("stop") and c.ends_with("^idle"):
				if not (last < first):
					trend_bad.append("%s (stop) %.2f -> %.2f m/s" % [c, first, last])
				elif float(sp[sp.size() - 1]) > 0.25:
					no_rest.append("%s ends at %.2f m/s" % [c.trim_prefix("actor_b-p-"), float(sp[sp.size() - 1])])
		var p: Dictionary = cm.plant
		var none := []
		for f in ["l", "r"]:
			if (p[f] as Array).is_empty() and (p[f + "_contact"] as Array).is_empty():
				none.append(f)
		if none.size() == 2:
			foot_none.append(c)
		elif none.size() == 1:
			foot_one.append("%s (%s)" % [c.trim_prefix("actor_b-p-"), none[0]])
	ctx.check(prof_bad.is_empty(), "%d WP10 one-shot clips have travel.kind one_shot_mean and a body_profile per clip sample from 0%s" % [
			wp10.size(), (" (" + "; ".join(prof_bad.slice(0, 5)) + ")") if not prof_bad.is_empty() else ""])
	ctx.check(n_ss >= 40 or graph.is_empty(), "the start_ / stop_ roles name %d clips with a body_profile" % n_ss)
	ctx.check(back_bad.is_empty(), "body_profile of the %d WP10 clips (%d start / stop): no step moves more than %.0f cm against the clip's net direction (worst %+.1f cm, %s)%s" % [
			covs.size(), n_ss, 100.0 * PROFILE_BACK_M, 100.0 * worst_back, worst_back_clip.trim_prefix("actor_b-p-"),
			(" (" + "; ".join(back_bad.slice(0, 8)) + ")") if not back_bad.is_empty() else ""])
	ctx.check(peak_bad.is_empty(), "body_profile of the WP10 clips: peak speed within %.1fx the role's bank clip speed or authored so (worst %.2fx, %s)%s" % [
			PROFILE_PEAK_RATIO, worst_ratio, worst_ratio_clip.trim_prefix("actor_b-p-"),
			(" (" + "; ".join(peak_bad) + ")") if not peak_bad.is_empty() else ""])
	for l in peak_authored:
		ctx.info("WP10 peak past %.1fx its bank speed, not an estimator artifact: %s" % [PROFILE_PEAK_RATIO, l])
	# Negative control: a method-B-style spurious reversal (one step -0.3 m) is caught.
	var ctl_clip := "actor_b-p-walk-fw^idle"
	if clips.has(ctl_clip) and clips[ctl_clip].body_profile is Dictionary:
		var ctl: Dictionary = (clips[ctl_clip].body_profile as Dictionary).duplicate(true)
		var fw: Array = ctl.fwd
		fw[2] = float(fw[2]) - 0.3
		ctx.check(float(profile_back(ctl).step) < -PROFILE_BACK_M, "the step check rejects a doctored profile with a 0.3 m spurious reversal (negative control, %.3f m)" % float(profile_back(ctl).step))
	ctx.check(trend_bad.is_empty(), "body_profile: starts (idle^*) speed up and stops (*^idle) slow down (first vs last quarter)%s" % [
			(" (" + "; ".join(trend_bad) + ")") if not trend_bad.is_empty() else ""])
	if not no_rest.is_empty():
		ctx.info("stop clips whose body_profile does not come to rest (> 0.25 m/s at the end; the source clip, the Blender dump agrees when dumped): " + ", ".join(no_rest))
	if not covs.is_empty():
		var sc := covs.duplicate()
		sc.sort()
		ctx.info("body_profile coverage (expected share of steps with a contact candidate) over the WP10 clips: min %.2f, median %.2f" % [sc[0], sc[sc.size() / 2]])
	ctx.check(foot_none.is_empty(), "every WP10 clip has a contact interval or plant onset for at least one foot%s" % [
			(" (none: " + ", ".join(foot_none) + ")") if not foot_none.is_empty() else ""])
	if not foot_one.is_empty():
		ctx.info("WP10 clips with one foot never in contact (short clips that begin with it lifting): " + ", ".join(foot_one))

	# --- fidelity vs the Blender dump ------------------------------------------------------------
	var fid_bad := []
	var flagged := []
	var n_dumped := 0
	for c: String in clips:
		var cm: Dictionary = clips[c]
		var want := _fidelity_reasons(cm)
		if cm.blender is Dictionary:
			n_dumped += 1
		var got: Variant = cm.fidelity_warning
		if (want.is_empty()) != (got == null) or (got != null and (got as Array).size() != want.size()):
			fid_bad.append("%s (expected %s, got %s)" % [c, want, got])
		if got != null:
			flagged.append("%s: %s" % [c.trim_prefix("actor_b-p-"), "; ".join(got)])
	ctx.check(fid_bad.is_empty(), "clips.*.fidelity_warning is set exactly where the library diverges from the Blender dump (%d dumped clips, %d flagged)%s" % [
			n_dumped, flagged.size(), (" (" + "; ".join(fid_bad.slice(0, 5)) + ")") if not fid_bad.is_empty() else ""])
	for f in flagged:
		ctx.info("fidelity (the key-reduced Actor_B.res; these values are not the authored ones): " + f)
	var tool_s: Script = load(TOOL)
	var clean := ""
	for c: String in clips:
		if clips[c].blender is Dictionary and clips[c].fidelity_warning == null and clips[c].travel is Dictionary:
			clean = c
			break
	if clean != "" and tool_s != null:
		var doc: Dictionary = (clips[clean] as Dictionary).duplicate(true)
		doc.blender.gt_max_mm = 50.0
		var tw: Variant = tool_s.fidelity_warning(doc)
		ctx.check(_fidelity_reasons(doc) == ["gt"] and tw != null and (tw as PackedStringArray).size() == 1,
				"the fidelity rule flags a doctored clip whose worst sample is 50 mm off (negative control, %s)" % clean.trim_prefix("actor_b-p-"))
	var wp10_flagged := []
	for c: String in wp10:
		if clips.has(c) and clips[c].fidelity_warning != null:
			wp10_flagged.append(c.trim_prefix("actor_b-p-"))
	if not wp10_flagged.is_empty():
		ctx.info("WP10 clips with a fidelity_warning (do not treat their travel / body_profile as authored until Actor_B.res is re-exported): " + ", ".join(wp10_flagged))

	# --- bone sets -------------------------------------------------------------------------------
	var rig := ctx.rig()
	if rig == null:
		return
	var sets: Dictionary = m.bone_sets
	var upper := PackedStringArray(sets.upper)
	var offsets := PackedStringArray()
	var root_b := rig.sk.find_bone("root")
	for b in rig.sk.get_bone_count():
		if rig.sk.get_bone_parent(b) == root_b and "_offset" in rig.sk.get_bone_name(b):
			offsets.append(rig.sk.get_bone_name(b))
	ctx.check(offsets.size() == 14, "rig has 14 *_offset root children (%d)" % offsets.size())
	var lacking := []
	for b in UPPER_MUST + Array(offsets):
		if not upper.has(b):
			lacking.append(b)
	ctx.check(lacking.is_empty(), "upper has spine, neck, head, clavicles, arm chain, upper_base and every *_offset root child%s" % [
			(" (missing " + ", ".join(lacking) + ")") if not lacking.is_empty() else ""])
	var wrong := []
	for b in upper:
		if b in UPPER_NOT or b.begins_with("holster") or (rig.sk.find_bone(b) >= 0 and _under(rig.sk, rig.sk.find_bone(b), "lower_base")):
			wrong.append(b)
	ctx.check(wrong.is_empty(), "upper excludes root, lower_base subtree, pelvis, legs and holsters%s" % [
			(" (has " + ", ".join(wrong) + ")") if not wrong.is_empty() else ""])
	var hands := PackedStringArray(sets.hands)
	ctx.check(hands.has("l_hand_prop_attachment") and hands.has("r_hand_prop_attachment"), "hands has both prop bones")
	var hand_re := RegEx.create_from_string("^[lr]_(thumb|index|middle|ring|pinky|palm)|_hand_prop_attachment$")
	var not_hand := []
	for b in hands:
		if hand_re.search(b) == null:
			not_hand.append(b)
	ctx.check(not_hand.is_empty() and hands.size() >= 20, "hands holds only finger/thumb/palm/prop bones (%d%s)" % [hands.size(),
			(", not: " + ", ".join(not_hand)) if not not_hand.is_empty() else ""])
	var stab := PackedStringArray(sets.stabilized)
	var stab_want := PackedStringArray(["upper_base"])
	for b in offsets:
		if upper.has(b):
			stab_want.append(b)
	stab_want.sort()
	ctx.check(stab == stab_want, "stabilized = upper_base + the *_offset root children in upper (%d bones)" % stab.size())
	var lower := PackedStringArray(sets.lower)
	var low_lack := []
	for b in LOWER_MUST:
		if not lower.has(b):
			low_lack.append(b)
	ctx.check(low_lack.is_empty(), "lower has pelvis and both legs%s" % [(" (missing " + ", ".join(low_lack) + ")") if not low_lack.is_empty() else ""])
	var overlap := []
	for b in lower:
		if upper.has(b) or hands.has(b):
			overlap.append(b)
	ctx.check(overlap.is_empty(), "lower shares no bone with upper or hands%s" % [(" (" + ", ".join(overlap) + ")") if not overlap.is_empty() else ""])

	# --- pitch -----------------------------------------------------------------------------------
	for key: String in m.pitch:
		_check_pitch(ctx, rig, key, m.pitch[key], hands)
	# THROW: the thrown weapons' aim trees have no barrel, hence no pitch table (measure_clips pitch_skip).
	var barrel_ctx := 0
	for key: String in graph.get("aim_trees", {}):
		if String(graph.get("profiles", {}).get(key.get_slice("/", 0), {}).get("clip_set", "")) != "throw":
			barrel_ctx += 1
	ctx.check(m.pitch.size() == barrel_ctx if not graph.is_empty() else m.pitch.size() == 6,
			"one pitch table per aim tree context with a barrel (%d of %d)" % [m.pitch.size(), barrel_ctx])
	ctx.check(float(m.chest_height.stand) > float(m.chest_height.crouch) + 0.05,
			"chest height stand %.3f m > crouch %.3f m" % [m.chest_height.stand, m.chest_height.crouch])

	# --- gt_check --------------------------------------------------------------------------------
	var gt: Dictionary = m.gt_check
	if gt.get("median_mm", null) == null:
		ctx.fail("gt_check ran (Blender foot dump missing when measured: %s)" % gt.get("skipped", "?"))
	else:
		ctx.at_most(float(gt.median_mm), GT_MEDIAN_MM, "gt_check median %.4f mm over %d clips / %d samples" % [gt.median_mm, gt.clips, gt.samples])
		ctx.at_most(float(gt.p95_mm), GT_P95_MM, "gt_check p95 %.3f mm" % gt.p95_mm)
		var worst := []
		for w: Array in gt.worst.slice(0, 5):
			worst.append("%s %.1f" % [w[0], w[1]])
		ctx.info("gt_check p99 %.2f mm, max %.1f mm; worst clips (mm): %s" % [gt.p99_mm, gt.max_mm, ", ".join(worst)])
		ctx.metric("gt_check", {"median_mm": gt.median_mm, "p95_mm": gt.p95_mm, "p99_mm": gt.p99_mm, "max_mm": gt.max_mm})

	# --- heel_z vs an AnimationTree single-clip pose ---------------------------------------------
	for c in ["actor_b-p-relax-idle", "actor_b-p-run-fw", "actor_b-p-crouch-walk-bw-lt"]:
		if not clips.has(c) or not (clips[c].heel_z is Dictionary):
			ctx.fail("%s has heel_z samples" % c)
			continue
		var hz: Dictionary = clips[c].heel_z
		var n: int = (hz.l as Array).size()
		var worst := 0.0
		for k in [0, n / 3, (2 * n) / 3, n - 1]:
			var t := minf(k / float(hz.rate), rig.anim(c).length)
			rig.pose_of(c, t)
			worst = maxf(worst, absf(rig.global_pose("l_heel").origin.z - float(hz.l[k])))
			worst = maxf(worst, absf(rig.global_pose("r_heel").origin.z - float(hz.r[k])))
		ctx.at_most(worst, HEEL_TOL, "%s heel_z equals the AnimationTree pose at 4 sample times (m)" % c)

	# --- determinism / currency ------------------------------------------------------------------
	var tool: Script = load(TOOL)
	if tool == null:
		ctx.fail("cannot load " + TOOL)
		return
	_regen(ctx, tool, METRICS, {"graph": GRAPH})
	_regen(ctx, tool, FIXTURE, {"graph": MINI_GRAPH, "fixture": "1"})
	_check_missing_dump(ctx, tool)


# --- pieces ------------------------------------------------------------------------------------

func _check_pitch(ctx: AnimTestContext, rig: RigFixture, key: String, p: Dictionary, hands: PackedStringArray) -> void:
	var w: Array = p.weights
	var e: Array = p.elev_deg
	var z := w.find(0.0)
	var lo := z - roundi(float(p.max_valid_down) / 0.05)
	var hi := z + roundi(float(p.max_valid_up) / 0.05)
	var mono := z >= 0
	for i in range(maxi(lo, 0) + 1, mini(hi, e.size() - 1) + 1):
		if float(e[i]) <= float(e[i - 1]):
			mono = false
	ctx.check(mono and hi > z and lo < z, "%s elevation strictly monotonic over the plan's max_valid w in [-%.2f, %.2f] (%.1f..%.1f deg)" % [
			key, p.max_valid_down, p.max_valid_up, e[lo], e[hi]])
	# The solve range (meta.method.pitch_range) is what the runtime inverts over.
	var slo := z - roundi(float(p.solve_down) / 0.05)
	var shi := z + roundi(float(p.solve_up) / 0.05)
	var smono := z >= 0 and slo >= 0 and shi <= e.size() - 1
	for i in range(maxi(slo, 0) + 1, mini(shi, e.size() - 1) + 1):
		if float(e[i]) <= float(e[i - 1]):
			smono = false
	ctx.check(smono and shi > z and slo < z and is_equal_approx(float(e[slo]), float(p.elev_at_solve_down))
			and is_equal_approx(float(e[shi]), float(p.elev_at_solve_up)),
			"%s elevation strictly monotonic over the solve range w in [-%.2f, %.2f] (%.1f..%.1f deg)" % [
			key, p.solve_down, p.solve_up, e[slo], e[shi]])
	# Independent evaluation: RigFixture-built tree, same composition (base, Add2 up, Add2 down, H).
	var bi := rig.sk.find_bone(String(p.barrel_bone))
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("base", rig.node(p.base))
	bt.add_node("up", rig.node(p.up))
	bt.add_node("down", rig.node(p.down))
	bt.add_node("add_up", AnimationNodeAdd2.new())
	bt.add_node("add_dn", AnimationNodeAdd2.new())
	bt.connect_node("add_up", 0, "base")
	bt.connect_node("add_up", 1, "up")
	bt.connect_node("add_dn", 0, "add_up")
	bt.connect_node("add_dn", 1, "down")
	var params := {}
	if p.grip != null:
		bt.add_node("grip", rig.node(p.grip))
		var h := AnimationNodeBlend2.new()
		rig.filter_bones(h, Array(hands))
		bt.add_node("H", h)
		bt.connect_node("H", 0, "add_dn")
		bt.connect_node("H", 1, "grip")
		bt.connect_node("output", 0, "H")
		params["H/blend_amount"] = 1.0
	else:
		bt.connect_node("output", 0, "add_dn")
	rig.play(bt, params)
	var eval_at := func(ww: float) -> float:
		rig.set_param("add_up/add_amount", maxf(ww, 0.0))
		rig.set_param("add_dn/add_amount", maxf(-ww, 0.0))
		rig.advance(0.0)
		var d := (rig.sk.get_bone_global_pose(bi).basis.orthonormalized() * Vector3(0, 0, 1)).normalized()
		return rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))
	var table_err := 0.0
	for i in [0, 7, 14, z, 26, 33, 40]:
		table_err = maxf(table_err, absf(eval_at.call(float(w[i])) - float(e[i])))
	ctx.at_most(table_err, PITCH_TABLE_TOL, "%s table reproduced by an independent AnimationTree at 7 weights (deg)" % key)
	# Inverse error for every target in -60..60 that the solve range reaches.
	var e_lo := float(e[slo])
	var e_hi := float(e[shi])
	var worst := 0.0
	var n := 0
	var tgt := -PITCH_RANGE_DEG
	while tgt <= PITCH_RANGE_DEG + 1e-6:
		if tgt >= e_lo and tgt <= e_hi:
			var ww := _inverse(w, e, slo, shi, tgt)
			worst = maxf(worst, absf(eval_at.call(ww) - tgt))
			n += 1
		tgt += PITCH_TARGET_STEP
	ctx.check(n > 0 and worst <= PITCH_INV_TOL, "%s inverse error %.3f deg <= %.1f over the %d targets in -60..60 the solve range reaches (%.1f..%.1f deg)" % [
			key, worst, PITCH_INV_TOL, n, e_lo, e_hi])
	# Coverage: only the data may limit the range (no yaw-drift rule narrows today's aim range), and
	# data_limits must name exactly the sides where the data stops inside +-60 deg.
	var mlo := z - roundi(float(p.max_monotonic_down) / 0.05)
	var mhi := z + roundi(float(p.max_monotonic_up) / 0.05)
	var cov := func(x0: float, x1: float) -> float:
		return 100.0 * maxf(0.0, minf(x1, PITCH_RANGE_DEG) - maxf(x0, -PITCH_RANGE_DEG)) / (2.0 * PITCH_RANGE_DEG)
	var v_lo := float(e[lo])
	var v_hi := float(e[hi])
	ctx.check(slo == mlo and shi == mhi, "%s solve range is the data range: w [-%.2f, %.2f] = monotonic [-%.2f, %.2f]; covers %.0f %% of +-60 (the plan's yaw-limited max_valid would cover %.0f %%: %.1f..%.1f deg)" % [
			key, p.solve_down, p.solve_up, p.max_monotonic_down, p.max_monotonic_up, cov.call(e_lo, e_hi), cov.call(v_lo, v_hi), v_lo, v_hi])
	var want_limits := int(e_lo > -PITCH_RANGE_DEG) + int(e_hi < PITCH_RANGE_DEG)
	var lims: Array = p.data_limits
	ctx.check(lims.size() == want_limits, "%s data_limits names the %d side(s) where the authored data stops inside +-60 deg" % [key, want_limits])
	for l in lims:
		ctx.info("%s data limit: %s" % [key, l])
	ctx.info("%s solve range %.1f..%.1f deg, sideways barrel drift up to %.1f deg inside it (AimStabilizer); zero elev %.1f yaw %.1f" % [
			key, e_lo, e_hi, p.solve_lateral_drift_deg, p.zero_elev_deg, p.zero_yaw_deg])
	ctx.metric("pitch/" + key, {"inverse_max_err_deg": worst, "solve": [e_lo, e_hi], "valid": [v_lo, v_hi], "monotonic": [e[mlo], e[mhi]],
			"lateral_drift_deg": p.solve_lateral_drift_deg})


## Weight w with elev(w) = target by linear interpolation of the table between indices lo..hi.
static func _inverse(w: Array, e: Array, lo: int, hi: int, target: float) -> float:
	for i in range(lo, hi):
		var a := float(e[i])
		var b := float(e[i + 1])
		if target >= a and target <= b:
			return float(w[i]) + (float(w[i + 1]) - float(w[i])) * ((target - a) / (b - a) if b != a else 0.0)
	return float(w[lo]) if target < float(e[lo]) else float(w[hi])


func _regen(ctx: AnimTestContext, tool: Script, path: String, opts: Dictionary) -> void:
	var committed := FileAccess.get_file_as_string(path)
	var rel := path.trim_prefix("res://")
	var t0 := Time.get_ticks_msec()
	var a: Dictionary = tool.measure(ctx.tree.root, opts)
	if not (a.errors as Array).is_empty():
		ctx.fail("measure_clips (%s) ran without errors: %s" % [rel, "; ".join(a.errors)])
		return
	var text_a: String = tool.to_json(a.data) + "\n"
	var cmp: Dictionary = tool.compare(text_a, committed)
	if cmp.same:
		ctx.check(true, "measure_clips reproduces %s (%s; %d ms)" % [rel,
				"byte for byte" if text_a == committed else "apart from the fields compare() skips", Time.get_ticks_msec() - t0])
		if cmp.note != "":
			ctx.info("%s: %s" % [rel, cmp.note])
		return
	var b: Dictionary = tool.measure(ctx.tree.root, opts)
	var text_b: String = tool.to_json(b.data) + "\n"
	ctx.check(text_a == text_b, "measure_clips output is deterministic (two in-process runs identical)")
	ctx.fail("%s %s: rerun Godot --headless --path . -s tools/anim_graph/measure_clips.gd%s" % [rel, cmp.reason,
			"" if not opts.has("fixture") else
			" -- graph=res://tools/anim_graph/fixtures/mini_graph.json out=res://tests/anim/fixtures/mini_metrics.json fixture=1"])


## measure() without the Blender dump (pap=<missing dir>): no errors, gt_check skipped, the CLI summary
## line formats (it used to call float(null) and hang the tool), and compare() against the committed
## fixture reports the missing dump rather than "stale".
func _check_missing_dump(ctx: AnimTestContext, tool: Script) -> void:
	var r: Dictionary = tool.measure(ctx.tree.root, {"graph": MINI_GRAPH, "fixture": "1", "pap": MISSING_PAP})
	ctx.check((r.errors as Array).is_empty(), "measure() with a missing Blender dump returns without errors%s" % [
			(": " + "; ".join(r.errors)) if not (r.errors as Array).is_empty() else ""])
	if not (r.errors as Array).is_empty():
		return
	var gt: Dictionary = r.data.gt_check
	var warned := false
	for w: String in r.warnings:
		if w.begins_with("Blender foot dump not found"):
			warned = true
	ctx.check(gt.get("skipped") is String and gt.median_mm == null and r.data.meta.gt_source == null and warned,
			"missing dump: gt_check.skipped set, values null, meta.gt_source null, a warning printed")
	var line: String = tool.summary_line(r, 0.0)
	ctx.check("gt_check skipped" in line, "missing dump: the CLI summary line formats (%s)" % line)
	var text: String = tool.to_json(r.data) + "\n"
	var schema := _load(ctx, SCHEMA)
	var doc: Variant = JSON.parse_string(text)
	var errs: Array = validate(doc, schema, schema) if doc is Dictionary else ["does not parse"]
	ctx.check(errs.is_empty(), "missing dump: the written document still validates (%d error(s)%s)" % [errs.size(),
			(": " + "; ".join(errs.slice(0, 5))) if not errs.is_empty() else ""])
	var cmp: Dictionary = tool.compare(text, FileAccess.get_file_as_string(FIXTURE))
	ctx.check(cmp.same and cmp.status == "no_dump" and "not found" in String(cmp.note),
			"missing dump: compare() with the committed fixture says the dump is missing, not stale (%s: %s)" % [cmp.status,
			cmp.note if cmp.same else cmp.reason])


## {clip: expected heading} for every bank clip in the graph (roles and aim_move), else the built-in stems.
static func _bank_clips(graph: Dictionary) -> Dictionary:
	var out := {}
	if graph.is_empty():
		for stem in ["walk", "run", "sprint", "crouch-walk"]:
			for r: String in BANK_ROLES:
				out["actor_b-p-%s-%s" % [stem, r.replace("_", "-")]] = BANK_ROLES[r]
		return out
	for key: String in graph.get("roles", {}):
		var role := key.get_slice("/", 2)
		var r: Variant = graph.roles[key]
		if BANK_ROLES.has(role) and r is Dictionary and r.get("clip", null) is String:
			out[r.clip] = BANK_ROLES[role]
	for key: String in graph.get("aim_move", {}):
		for role: String in graph.aim_move[key]:
			var r: Variant = graph.aim_move[key][role]
			if BANK_ROLES.has(role) and r is Dictionary and r.get("clip", null) is String:
				out[r.clip] = BANK_ROLES[role]
	return out


## Largest step of a body_profile against its net direction: {step: m (negative = against), k}.
static func profile_back(bp: Dictionary) -> Dictionary:
	var n: int = (bp.fwd as Array).size()
	var out := {"step": 0.0, "k": -1}
	var net := Vector2(float(bp.side[n - 1]), float(bp.fwd[n - 1]))
	if net.length() <= 1e-3:
		return out
	var u := net.normalized()
	for k in n - 1:
		var step := Vector2(float(bp.side[k + 1]) - float(bp.side[k]), float(bp.fwd[k + 1]) - float(bp.fwd[k])).dot(u)
		if step < float(out.step):
			out.step = step
			out.k = k
	return out


## Distinct clips of the WP10 one-shot roles (start_* / stop_* / rev_*) in the graph export:
## {clip: {kinds: {"start" | "stop" | "rev": true}, bank: [the bank clip of each role's direction in its
## weapon / mode (start_fw_lt -> <w>/<m>/fw_lt; rev_fw_bw -> <w>/<m>/bw)]}}.
static func _wp10_clips(graph: Dictionary) -> Dictionary:
	var out := {}
	var roles: Dictionary = graph.get("roles", {})
	for key: String in roles:
		var role := key.get_slice("/", 2)
		var r: Variant = roles[key]
		if not (r is Dictionary and r.get("clip", null) is String):
			continue
		for pre: String in WP10_ROLE_PREFIXES:
			if not role.begins_with(pre):
				continue
			var dir := role.trim_prefix(pre)
			if pre == "rev_":
				dir = dir.substr(dir.find("_") + 1)   # rev_fw_bw_lt -> bw_lt (the direction it ends in)
			if not out.has(r.clip):
				out[r.clip] = {"kinds": {}, "bank": []}
			out[r.clip].kinds[pre.trim_suffix("_")] = true
			var bk := "%s/%s/%s" % [key.get_slice("/", 0), key.get_slice("/", 1), dir]
			var b: Variant = roles.get(bk, null)
			if b is Dictionary and b.get("clip", null) is String and not (out[r.clip].bank as Array).has(b.clip):
				out[r.clip].bank.append(b.clip)
	return out


## clip -> the graph export's loop flag, as measure_clips derives it: every dict with a string `clip`
## and a boolean `loop`, looped if any of them loops.
static func _graph_loops(v: Variant, loops: Dictionary) -> void:
	if v is Dictionary:
		if v.get("clip", null) is String and v.get("loop", null) is bool:
			loops[v.clip] = bool(loops.get(v.clip, false)) or bool(v.loop)
		for k in v:
			_graph_loops(v[k], loops)
	elif v is Array:
		for x in v:
			_graph_loops(x, loops)


## The fidelity reasons a clip should carry (meta.method.fidelity), recomputed from its fields.
static func _fidelity_reasons(cm: Dictionary) -> Array:
	var why := []
	var bl: Variant = cm.get("blender", null)
	if not (bl is Dictionary):
		return why
	var t: Variant = cm.get("travel", null)
	if t is Dictionary and bl.speed != null and float(bl.speed) >= FIDELITY_MIN_SPEED and float(t.speed) >= FIDELITY_MIN_SPEED:
		if bl.rel_diff != null and absf(float(bl.rel_diff)) > FIDELITY_REL:
			why.append("speed")
		if bl.heading_deg != null and absf(wrapf(float(t.heading_deg) - float(bl.heading_deg), -180.0, 180.0)) > FIDELITY_HEADING_DEG:
			why.append("heading")
	if float(bl.gt_max_mm) > FIDELITY_GT_MM:
		why.append("gt")
	if bl.profile_diff_m != null and float(bl.profile_diff_m) > FIDELITY_PROFILE_M:
		why.append("profile")
	return why


## The lt/rt mirror of a bank clip name ("...-fw-rt" <-> "...-fw-lt"); "" when it has no side suffix.
static func _mirror(c: String) -> String:
	if c.ends_with("-rt"):
		return c.trim_suffix("-rt") + "-lt"
	if c.ends_with("-lt"):
		return c.trim_suffix("-lt") + "-rt"
	return ""


static func _mean(xs: Array) -> float:
	var s := 0.0
	for x in xs:
		s += float(x)
	return s / xs.size() if not xs.is_empty() else 0.0


## Left and right onsets strictly alternate around the cycle and have equal counts.
static func _alternates(l: Array, r: Array) -> bool:
	if l.size() != r.size() or l.is_empty():
		return false
	var ev := []
	for x in l:
		ev.append([float(x), 0])
	for x in r:
		ev.append([float(x), 1])
	ev.sort_custom(func(a, b): return a[0] < b[0])
	for i in ev.size():
		if ev[i][1] == ev[(i + 1) % ev.size()][1]:
			return false
	return true


static func _travel(clips: Dictionary, c: String) -> Variant:
	if not clips.has(c) or not (clips[c] is Dictionary):
		return null
	var t: Variant = clips[c].travel
	return t if t is Dictionary else null


static func _under(sk: Skeleton3D, b: int, ancestor: String) -> bool:
	var a := sk.find_bone(ancestor)
	var p := b
	while p >= 0:
		if p == a:
			return true
		p = sk.get_bone_parent(p)
	return false


func _load(ctx: AnimTestContext, path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		ctx.fail("%s exists" % path)
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		ctx.fail("%s parses as a JSON object" % path)
		return {}
	return d


# --- minimal JSON-schema validator (the subset the schema's description lists) ------------------

func validate(v: Variant, s: Dictionary, root: Dictionary, path := "$", errors: Array = [], limit := 50) -> Array:
	if errors.size() >= limit:
		return errors
	if s.has("$ref"):
		var ref: String = s["$ref"]
		return validate(v, root.definitions[ref.get_slice("/", 2)], root, path, errors, limit)
	if s.has("const") and not _eq(v, s.const):
		errors.append("%s: %s != const %s" % [path, v, s.const])
	if s.has("enum"):
		var found := false
		for x in s.enum:
			if _eq(v, x):
				found = true
		if not found:
			errors.append("%s: %s not in %s" % [path, v, s.enum])
	if s.has("type"):
		var ts: Array = s.type if s.type is Array else [s.type]
		var ok := false
		for t: String in ts:
			if _is_type(v, t):
				ok = true
		if not ok:
			errors.append("%s: type %s not in %s" % [path, type_string(typeof(v)), ts])
			return errors
	if v is String and s.has("pattern"):
		if not _re.has(s.pattern):
			_re[s.pattern] = RegEx.create_from_string(s.pattern)
		if (_re[s.pattern] as RegEx).search(v) == null:
			errors.append("%s: '%s' !~ /%s/" % [path, v, s.pattern])
	if v is float or v is int:
		if s.has("minimum") and float(v) < float(s.minimum):
			errors.append("%s: %s < %s" % [path, v, s.minimum])
		if s.has("maximum") and float(v) > float(s.maximum):
			errors.append("%s: %s > %s" % [path, v, s.maximum])
	if v is Array:
		if s.has("minItems") and v.size() < int(s.minItems):
			errors.append("%s: fewer than %d items" % [path, s.minItems])
		if s.has("maxItems") and v.size() > int(s.maxItems):
			errors.append("%s: more than %d items" % [path, s.maxItems])
		if s.has("items"):
			for i in v.size():
				validate(v[i], s.items, root, "%s[%d]" % [path, i], errors, limit)
	if v is Dictionary:
		for k in s.get("required", []):
			if not v.has(k):
				errors.append("%s: missing required '%s'" % [path, k])
		var props: Dictionary = s.get("properties", {})
		var pats: Dictionary = s.get("patternProperties", {})
		for k: String in v:
			var matched := false
			if props.has(k):
				matched = true
				validate(v[k], props[k], root, "%s.%s" % [path, k], errors, limit)
			for pat: String in pats:
				if not _re.has(pat):
					_re[pat] = RegEx.create_from_string(pat)
				if (_re[pat] as RegEx).search(k) != null:
					matched = true
					validate(v[k], pats[pat], root, "%s.%s" % [path, k], errors, limit)
			if not matched:
				var ap: Variant = s.get("additionalProperties", true)
				if ap is bool and not ap:
					errors.append("%s: unexpected key '%s'" % [path, k])
				elif ap is Dictionary:
					validate(v[k], ap, root, "%s.%s" % [path, k], errors, limit)
	return errors


static func _is_type(v: Variant, t: String) -> bool:
	match t:
		"object":
			return v is Dictionary
		"array":
			return v is Array
		"string":
			return v is String
		"boolean":
			return v is bool
		"null":
			return typeof(v) == TYPE_NIL
		"number":
			return v is float or v is int
		"integer":
			return (v is int) or (v is float and is_finite(v) and float(v) == floorf(v))
	return false


static func _eq(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return float(a) == float(b)
	if typeof(a) != typeof(b):
		return false
	return a == b
