extends SceneTree
## Clip metrics tool (plan WP2, section 5.4): measures the Actor_B clips the graph-driven player
## animation uses and writes animations/actor_b_clip_metrics.json.
##
##   Godot --headless --path . -s tools/anim_graph/measure_clips.gd -- [options]
##
## Options (after --):
##   graph=<path>   graph export to take the clip list, aim trees and grips from
##                  (default res://animations/actor_b_graph.json; `graph=none` or a missing file
##                  uses the built-in list below)
##   out=<path>     output (default res://animations/actor_b_clip_metrics.json)
##   pap=<dir>      Player_Animation_Project (default $ANIM_GRAPH_PAP, else
##                  /Users/kiwimango/Downloads/Player_Animation_Project); only its Blender foot
##                  dump GA/vmm/bl/dump3.jsonl is read, for gt_check and clips.*.blender
##   check          measure, compare with the existing output and exit 1 if it differs (writes nothing).
##                  meta.rig_sha256 / meta.godot_version (STAMP_FIELDS) are ignored by the comparison, and
##                  without the Blender dump everything but the gt-derived fields is compared (see compare())
##   fixture=<note> mark the output as a fixture (meta.fixture); used for tests/anim/fixtures/mini_metrics.json:
##                  graph=res://tools/anim_graph/fixtures/mini_graph.json out=res://tests/anim/fixtures/mini_metrics.json fixture=1
## Exit code 0 on success ("CLIP METRICS OK"), 1 on failure ("CLIP METRICS FAILED").
##
## What is measured (skeleton space: rig forward +Z, left +X, up +Y; nothing is written to the rig or
## to any Animation; BindRest.ensure() runs first so the rest is the null-add bind pose):
##   clips.<name>        length, sample_rate / sample_count (clip metadata), native_asset_id, additive,
##                       keyed_bones, loop, travel, plant, heel_z, body_profile, blender, fidelity_warning
##     loop              first and last sample of the clip's core bones (root, lower_base, pelvis, legs,
##                       upper_base, spine, neck, head, clavicles, arms; all keyed bones when it keys
##                       none of them) within 2 cm (skeleton-space position) and 0.05 rad (local rotation);
##                       a 1-sample pose clip counts as a loop. Measured only; see "cyclic" below
##     cyclic            whether the clip plays looped: the graph export's loop flag of the entries that
##                       play it (any dict with `clip` + `loop`: roles, aim_move, aim_trees, actions, ...;
##                       looped if any is); the feet seam test (every heel/ball's first and last samples
##                       within 2 cm horizontally) only for clips no graph entry plays (and the built-in
##                       list). travel.cyclic_source says which; travel.seam_m keeps the seam mismatch
##     travel            GA/vmm/bl/an.py method A on heel and ball (non-additive clips that key a leg
##                       bone): samples at the clip's own sample rate (the key times); a point is planted
##                       within 2 cm of its lowest height; per planted run of >= 3 samples (runs of a cyclic
##                       clip wrap the seam when that point's first and last samples meet within 2 cm) the
##                       least-squares horizontal foot velocity; body velocity = -(run-length-weighted mean).
##                       One documented fallback chain when there is no such run (travel.estimator; quality
##                       "fallback"): runs of >= 2 samples at the clip's own rate (method_a_run2: the sprint
##                       strafes, 2-sample stances at 15 Hz), else runs of >= 3 at 2x, then 4x the rate
##                       (method_a_2x / _4x). speed, heading_deg (+ = left), fwd, side, stride_m = speed *
##                       length, cycles, runs, cyclic, kind ("cyclic": a playback-rate reference;
##                       "one_shot_mean": mean over the stance runs of a start / stop / landing, NOT a rate
##                       reference; use body_profile); travel.contact = secondary estimate from every 60 Hz
##                       contact sample (see _contact_velocity; informational)
##     plant             normalized phases of every plant onset per foot, from 60 Hz samples: in contact =
##                       heel or ball within 5 cm of its lowest height and moving over the ground (skeleton
##                       velocity + body velocity) slower than max(0.3 m/s, 0.25 * body speed); contact runs
##                       closer than 0.1 s merge, runs under 0.05 s drop; onset = first sample of a run;
##                       cyclic clips wrap. l_contact / r_contact: the contact intervals [start, end] (phases;
##                       end > 1 for a run that wraps a cyclic clip's seam), including a one-shot clip's
##                       stance that is already planted at t = 0 (which has no onset)
##     heel_z            forward (+Z) position of each heel at the clip's sample times, for the IDLE/AIM_IDLE
##                       -> MOVE entry phase choice (plan 6.7)
##     body_profile      non-cyclic clips (starts, stops, reversals, landings, hits): time-resolved body
##                       travel at the clip's sample times from the contact path (see _body_profile; the
##                       posterior mean over heel/ball contact paths with a smooth body velocity):
##                       cumulative displacement fwd / side from t = 0, speed per sample, coverage
##     blender           the same travel estimator chain (native rate only) on the Blender dump of the clip
##                       (Blender (x, y, z) -> Godot (x, z, -y)); rel_diff = (speed - blender speed) / blender
##                       speed when both used the same estimator; gt_max_mm / gt_max_t = worst heel/ball
##                       sample vs the dump; profile_diff_m / profile_peak_speed = the contact path run on
##                       the dump's frames vs body_profile
##     fidelity_warning  null, or why the library's values of this clip are not the authored ones: travel
##                       speed > 5 % or heading > 10 deg off the dump (both >= 0.1 m/s), a heel/ball sample
##                       > 20 mm off, body_profile displacement > 5 cm off (the key-reduced library)
##   bone_sets           upper, hands, stabilized, pitch_add_union, lower (section 5.4; see schema)
##   pitch.<w>/<stance>  aim tree base + Add2 up (w > 0) / Add2 down (w < 0) + H (Blend2 filtered to
##                       bone_sets.hands, amount 1, the aim grip), in a real AnimationTree (the runtime's
##                       composition); barrel = prop bone basis * +Z; w in [-1, 1] step 0.05.
##                       max_valid_* = the plan's yaw-limited range (reference); solve_* = the range the
##                       runtime solves over: the authored additives' full monotonic range (the data limit,
##                       which is also today's gameplay range), with the yaw drift inside it in yaw_deg for
##                       the AimStabilizer; data_limits names where the data stops short of +-60 deg
##   chest_height        skeleton-space height of `spined` in the aim-idle base at t = 0 (mean over weapons)
##   gt_check            every Blender-dumped clip: Godot heel/ball positions vs the dump at the same times;
##                       skipped (null values, `skipped` set, a warning) when the dump is not found

const RIG := "res://characters/Actor_B.tscn"
const LIB := "actor_b"
const LIBRARY_RES := "res://animations/Actor_B.res"
const DEFAULT_GRAPH := "res://animations/actor_b_graph.json"
const DEFAULT_OUT := "res://animations/actor_b_clip_metrics.json"
const DEFAULT_PAP := "/Users/kiwimango/Downloads/Player_Animation_Project"
const DUMP_REL := "graph_analysis/graph/vmm/bl/dump3.jsonl"
const GENERATOR := "tools/anim_graph/measure_clips.gd"
const SCHEMA := 1

const AUTHORIZATION := "owner-stated; see Player_Animation_Project/ASSET_AUTHORIZATION.md; granting party and terms not on file"

const POINTS := ["l_heel", "l_ball", "r_heel", "r_ball"]
const LEG_BONES := ["l_upper_leg", "l_knee", "l_ankle", "l_heel", "l_ball",
		"r_upper_leg", "r_knee", "r_ankle", "r_heel", "r_ball"]
## Chain ends whose root chains make up the "core bones" of the loop check.
const CORE_ENDS := ["l_ball", "r_ball", "heada", "l_wrist", "r_wrist"]
const PLANTED_TOL := 0.02
## Plant detection (see _plants).
const PLANT_H_TOL := 0.05
const PLANT_V_ABS := 0.3
const PLANT_V_REL := 0.25
const PLANT_MIN_AIR_S := 0.1
const PLANT_MIN_STANCE_S := 0.05
## One-shot clips: half-window of the local body-velocity median used by plant detection.
const PLANT_VB_WINDOW_S := 0.1
## Passes of the secondary contact-velocity estimate (travel.contact).
const CONTACT_ITERS := 6
## Method A: shortest planted run (samples at the clip's own rate), as GA/vmm/bl/an.py.
const MIN_RUN := 3
## Fallback when no run of MIN_RUN exists at the clip's own rate (2-sample stances: the 15 Hz sprint
## strafes). On the 4 sprint bank clips that do have method-A runs it reproduces method A within
## 1-5 % (mean 2.3 %) and 0.5-2.3 deg, closer than 2x / 4x-rate method A (mean 5.3 % / 3.7 %) or
## travel.contact (6.0 %).
const MIN_RUN_FALLBACK := 2
const PLANT_HZ := 60.0
## body_profile contact path (see _body_profile). Candidate: heel/ball within PROFILE_H_MAX of its lowest
## height at both ends of a step; cost (height / SIGMA_H)^2 + (vertical speed / SIGMA_VY)^2; PROFILE_GAP
## per step without a contact point; body acceleration in units of SIGMA_A; gaps up to GAP_MAX_S.
## Chosen from sweeps over the 42 start / stop clips: SIGMA_A 5-7, GAP 8-24, SIGMA_H 1.5-3 cm and
## SIGMA_VY 0.2-0.5 m/s all keep every step within 2 cm of the travel direction and every start ending
## near its bank speed (median 1.0x); SIGMA_A >= 10 starts to let a skimming swing foot back in.
const PROFILE_H_MAX := 0.06
const PROFILE_SIGMA_H := 0.02
const PROFILE_SIGMA_VY := 0.3
const PROFILE_SIGMA_A := 6.0
const PROFILE_GAP := 12.0
const PROFILE_GAP_MAX_S := 0.5
## Path weights exp(-cost / PROFILE_TEMP): the costs are Gaussian chi^2 terms, so 2 is the likelihood.
const PROFILE_TEMP := 2.0
## fidelity_warning thresholds (library vs Blender dump).
const FIDELITY_REL := 0.05
const FIDELITY_HEADING_DEG := 10.0
const FIDELITY_MIN_SPEED := 0.1
const FIDELITY_GT_MM := 20.0
const FIDELITY_PROFILE_M := 0.05
const LOOP_POS_TOL := 0.02
const LOOP_ROT_TOL := 0.05
const PITCH_STEP := 0.05
const PITCH_YAW_DRIFT_DEG := 8.0
## Aim-elevation span the pitch tables are judged over (plan section 10: inverse error over +-60 deg).
const PITCH_TARGET_DEG := 60.0
## meta fields that stamp the environment rather than the measured data; compare() ignores them.
const STAMP_FIELDS := ["rig_sha256", "godot_version"]
## Barrel bone per weapon (Frontier: Weapon.hand; bow in the left hand), barrel = basis * +Z.
const BARREL_BONE := {"bow": "l_hand_prop_attachment", "musket": "r_hand_prop_attachment",
		"pistol": "r_hand_prop_attachment"}
const HANDS_RE := "^[lr]_(thumb|index|middle|ring|pinky|palm)|_hand_prop_attachment$"
## Reference / null clips never measured.
const SKIP_CLIPS := ["null", "null-add", "null-add-base", "bindpose-anim", "RESET"]

## Built-in list, used when no graph export is available (plan 5.4): the section 5.3 locomotion banks,
## idles, aim-walk banks, the aim trees and grips as exported on 2026-09-23.
const BUILTIN_AIM := {
	"bow/stand": {"base": "actor_b-p-bow-aim-idle", "up": "actor_b-p-bow-aim-up--add", "down": "actor_b-p-bow-aim-down--add",
			"blocked": "actor_b-p-bow-blocked-aim", "arms_relaxed": "actor_b-p-arms-relaxed--part", "hands": "actor_b-p-bow-aim-hands-idle"},
	"bow/crouch": {"base": "actor_b-p-bow-aim-crouch-idle", "up": "actor_b-p-bow-crouch-aim-up--add", "down": "actor_b-p-bow-crouch-aim-down--add",
			"blocked": "actor_b-p-bow-blocked-aim", "arms_relaxed": "actor_b-p-arms-relaxed--part", "hands": "actor_b-p-bow-aim-crouch-hands-idle"},
	"musket/stand": {"base": "actor_b-p-rifle-idle-aim", "up": "actor_b-p-rifle-idle-aim-up--add", "down": "actor_b-p-rifle-idle-aim-down--add",
			"blocked": "actor_b-p-rifle-blocked-aim", "arms_relaxed": "actor_b-p-arms-relaxed--part", "hands": "actor_b-p-rifle-idle-aim--hands"},
	"musket/crouch": {"base": "actor_b-p-rifle-aim-crouch-idle", "up": "actor_b-p-rifle-idle-crouch-aim-up--add", "down": "actor_b-p-rifle-idle-crouch-aim-down--add",
			"blocked": "actor_b-p-rifle-blocked-aim", "arms_relaxed": "actor_b-p-arms-relaxed--part", "hands": "actor_b-p-rifle-aim-crouch-idle--hands"},
	"pistol/stand": {"base": "actor_b-p-pistol-aim-idle", "up": "actor_b-p-pistol-aim-up", "down": "actor_b-p-pistol-aim-down",
			"blocked": "actor_b-p-pistol-aim-blocked", "arms_relaxed": "actor_b-p-arms-relaxed--part", "hands": "actor_b-r-hand-revolver-aim"},
	"pistol/crouch": {"base": "actor_b-p-pistol-aim-idle-crouch", "up": "actor_b-p-pistol-aim-up", "down": "actor_b-p-pistol-aim-down",
			"blocked": "actor_b-p-pistol-aim-crouch-blocked", "arms_relaxed": "actor_b-p-arms-relaxed--part", "hands": "actor_b-r-hand-revolver-aim"},
}
const BUILTIN_GRIPS := {
	"bow": ["actor_b-p-bow-hands", "actor_b-p-bow-aim-hands-idle", "actor_b-p-bow-aim-crouch-hands-idle"],
	"musket": ["actor_b-p-rifle-crouch-idle--hands", "actor_b-p-rifle-idle-aim--hands", "actor_b-p-rifle-aim-crouch-idle--hands"],
	"pistol": ["actor_b-r-hand-revolver", "actor_b-r-hand-revolver-aim"],
}
const BUILTIN_BANK_STEMS := ["walk", "run", "sprint", "crouch-walk"]
const BUILTIN_AIM_WALK := ["bow-aim-walk", "rifle-aim-walk", "pistol-aim-walk", "bow-aim-crouch-walk",
		"rifle-aim-crouch-walk", "pistol-aim-crouch-walk"]
const BUILTIN_OTHER := ["actor_b-p-relax-idle", "actor_b-p-crouch-idle", "actor_b-p-stealth-idle"]
const DIR_SUFFIX := ["fw", "fw-lt", "fw-rt", "bw", "bw-lt", "bw-rt"]


var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if "=" in s:
			_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
		else:
			_args[s] = true
	# Fixtures need the root window inside the tree (it enters after _initialize starts).
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	var res := measure(root, _args)
	if not res.errors.is_empty():
		for e in res.errors:
			printerr("measure_clips: " + e)
		print("CLIP METRICS FAILED (%d error(s))" % res.errors.size())
		quit(1)
		return
	for w in res.warnings:
		print("  warn " + w)
	var text := to_json(res.data) + "\n"
	var out: String = _args.get("out", DEFAULT_OUT)
	var summary := summary_line(res, (Time.get_ticks_msec() - t0) / 1000.0)
	if _args.has("check"):
		var old := FileAccess.get_file_as_string(out) if FileAccess.file_exists(out) else ""
		var cmp := compare(text, old)
		if not cmp.same:
			print("measure_clips: %s %s (rerun without `check`)" % [out, cmp.reason])
			print("CLIP METRICS FAILED (%s)" % cmp.status)
			quit(1)
			return
		print("measure_clips: %s is current%s; %s" % [out, (" (" + cmp.note + ")") if cmp.note != "" else "", summary])
		print("CLIP METRICS OK")
		quit(0)
		return
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		printerr("measure_clips: cannot write %s: %s" % [out, error_string(FileAccess.get_open_error())])
		print("CLIP METRICS FAILED")
		quit(1)
		return
	f.store_string(text)
	f.close()
	print("measure_clips: wrote %s (%d bytes, sha256 %s); %s" % [out, text.to_utf8_buffer().size(),
			text.sha256_text(), summary])
	print("CLIP METRICS OK")
	quit(0)


## One-line summary of a successful measure() result (gt_check values are null when it was skipped).
static func summary_line(res: Dictionary, secs: float) -> String:
	var d: Dictionary = res.data
	var gt: Dictionary = d.get("gt_check", {})
	var gts := ""
	if gt.get("median_mm") == null or gt.get("p95_mm") == null or gt.get("max_mm") == null:
		gts = "gt_check skipped (%s)" % gt.get("skipped", "no values")
	else:
		gts = "gt_check median %.3f mm p95 %.3f mm max %.1f mm" % [float(gt.median_mm), float(gt.p95_mm), float(gt.max_mm)]
	return "%d clips (%d with travel), %d pitch tables, %s, %.1f s" % [(d.get("clips", {}) as Dictionary).size(),
			int(res.get("travel_count", 0)), (d.get("pitch", {}) as Dictionary).size(), gts, secs]


## Compares a freshly generated metrics text with the committed one.
## {same: bool, status: "current" | "missing" | "stale" | "no_dump", reason: String, note: String}.
##   - meta.rig_sha256 and meta.godot_version (STAMP_FIELDS) are ignored: a rig restamp or an engine patch
##     release that leaves every measured value unchanged is not "stale" (note says so; rerun to restamp).
##   - When the new run had no Blender dump (meta.gt_source null) but the committed file has one, the
##     gt-derived fields (gt_check, meta.gt_source, clips.*.blender, clips.*.fidelity_warning) cannot be
##     re-measured: the rest is compared, and the status is "no_dump" instead of "stale".
static func compare(new_text: String, old_text: String) -> Dictionary:
	var out := {"same": false, "status": "stale", "reason": "", "note": ""}
	if old_text == "":
		out.status = "missing"
		out.reason = "is missing"
		return out
	if new_text == old_text:
		out.same = true
		out.status = "current"
		return out
	var a: Variant = JSON.parse_string(new_text)
	var b: Variant = JSON.parse_string(old_text)
	if not (a is Dictionary and b is Dictionary and a.get("meta") is Dictionary and b.get("meta") is Dictionary):
		out.reason = "is stale (not a metrics document)"
		return out
	var no_dump: bool = a.meta.get("gt_source") == null and b.meta.get("gt_source") != null
	var stamps := PackedStringArray()
	for f: String in STAMP_FIELDS:
		if str(a.meta.get(f, "")) != str(b.meta.get(f, "")):
			stamps.append(f)
	if to_json(_strip(a, no_dump)) == to_json(_strip(b, no_dump)):
		out.same = true
		out.status = "no_dump" if no_dump else "current"
		var notes := PackedStringArray()
		if no_dump:
			notes.append("gt_check, clips.*.blender and clips.*.fidelity_warning not re-measured: the Blender foot dump was not found (pass pap=<Player_Animation_Project> or set ANIM_GRAPH_PAP); every other field is current")
		if not stamps.is_empty():
			notes.append("only %s differ; rerun without `check` to restamp" % ", ".join(stamps))
		out.note = "; ".join(notes)
		return out
	out.status = "stale"
	var why := PackedStringArray()
	for pair in [["graph", "its graph input changed"], ["library_sha256", "animations/Actor_B.res changed"]]:
		var x: Variant = a.meta.get(pair[0])
		var y: Variant = b.meta.get(pair[0])
		if x is Dictionary and y is Dictionary:
			x = x.get("sha256")
			y = y.get("sha256")
		if str(x) != str(y):
			why.append(pair[1])
	if no_dump:
		why.append("and the Blender foot dump was not found, so gt_check could not be re-measured (pap=<dir> or ANIM_GRAPH_PAP)")
	out.reason = "is stale" + ((" (" + "; ".join(why) + ")") if not why.is_empty() else "")
	return out


## Copy of a parsed metrics document without the stamp fields (and without the gt-derived fields when
## no_gt), for compare().
static func _strip(doc: Dictionary, no_gt: bool) -> Dictionary:
	var d := doc.duplicate(true)
	for f: String in STAMP_FIELDS:
		d.meta.erase(f)
	if no_gt:
		d.meta.erase("gt_source")
		d.erase("gt_check")
		for name: String in d.get("clips", {}):
			if d.clips[name] is Dictionary:
				d.clips[name].erase("blender")
				d.clips[name].erase("fidelity_warning")
	return d


# =============================================================================================
# Measurement (static, so tests can run it in process: load(<this script>).measure(root, opts))
# =============================================================================================

## Runs every measurement. opts: graph, pap, fixture (see the header).
## Returns {data: Dictionary (the metrics document), errors: [str], warnings: [str], travel_count: int}.
static func measure(parent: Node, opts := {}) -> Dictionary:
	var out := {"data": {}, "errors": [], "warnings": [], "travel_count": 0}
	var scene := load(RIG) as PackedScene
	if scene == null:
		out.errors.append("cannot load " + RIG)
		return out
	var inst := scene.instantiate() as Node3D
	inst.name = "MeasureClipsRig"
	parent.add_child(inst)
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		out.errors.append("%s has no Skeleton3D / AnimationPlayer" % RIG)
		inst.queue_free()
		return out
	var sk: Skeleton3D = sks[0]
	var ap: AnimationPlayer = aps[0]
	ap.stop()
	if not ap.has_animation_library(LIB):
		out.errors.append("rig has no animation library '%s'" % LIB)
		inst.queue_free()
		return out
	# The clips as the file has them: in a process that ran the level (the anim tests), the cached
	# library is not the file, because the player's traversal smooths the key interpolation of the clips
	# its moves play, in memory (TravInertializer.smooth_clip_tracks / resample_hermite); measure a
	# fresh copy then (test_metrics called the metrics stale whenever a level suite ran before it).
	if _changed_in_memory(ap.get_animation_library(LIB)):
		var fresh := ResourceLoader.load(LIBRARY_RES, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as AnimationLibrary
		if fresh:
			ap.remove_animation_library(LIB)
			ap.add_animation_library(LIB, fresh)
	var rest := _ensure_rest(sk, ap)
	if not bool(rest.get("ok", false)):
		out.errors.append("rest is not the null-add bind pose: %s" % rest.get("reason", "?"))
		inst.queue_free()
		return out
	var lib := ap.get_animation_library(LIB)

	# --- inputs --------------------------------------------------------------------------------
	var graph_path: String = str(opts.get("graph", DEFAULT_GRAPH))
	var graph := {}
	if graph_path != "none" and FileAccess.file_exists(graph_path):
		var g: Variant = JSON.parse_string(FileAccess.get_file_as_string(graph_path))
		if not (g is Dictionary):
			out.errors.append("cannot parse " + graph_path)
			inst.queue_free()
			return out
		graph = g
	elif graph_path != "none" and graph_path != DEFAULT_GRAPH:
		out.errors.append("graph file not found: " + graph_path)
		inst.queue_free()
		return out
	var src := _sources(graph, lib)
	for w in src.warnings:
		out.warnings.append(w)
	var pap: String = str(opts.get("pap", OS.get_environment("ANIM_GRAPH_PAP")))
	if pap == "":
		pap = DEFAULT_PAP
	var dump_path := pap.path_join(DUMP_REL)
	var dump := _load_dump(dump_path)
	if dump.is_empty():
		out.warnings.append("Blender foot dump not found or empty: %s (gt_check and clips.*.blender skipped)" % dump_path)

	var ctx := _Rig.new(sk)

	# --- per-clip metrics ----------------------------------------------------------------------
	var clips := {}
	for name: String in src.clips:
		if not lib.has_animation(name):
			out.errors.append("clip referenced by the graph is missing from the library: " + name)
			continue
		var a := lib.get_animation(name)
		var c := _clip_metrics(ctx, name, a, src.loop.get(name, null))
		if dump.has(name):
			# Always recorded for a dumped clip (gt_max_mm / gt_max_t are added after gt_check); speed
			# fields are null when the estimator chain finds no planted run in the dump either. The dump
			# has only its own rate, so the chain stops at method_a_run2 there. The clip's cyclic flag
			# (graph loop, else feet seam) is used on both sides.
			var bsr := float(dump[name].sr)
			var bdt := 1.0 / bsr
			var cyc: Variant = c.get("_cyclic", null)
			var bl := _travel_from_frames(dump[name].frames, bdt, MIN_RUN, cyc)
			var bl_est: Variant = "method_a"
			if bl.runs == 0:
				bl = _travel_from_frames(dump[name].frames, bdt, MIN_RUN_FALLBACK, cyc)
				bl_est = "method_a_run2" if bl.runs > 0 else null
			var rel: Variant = null
			if bl.runs > 0 and c.travel is Dictionary and bl.speed > 0.0 and c.travel.estimator == bl_est:
				rel = (float(c.travel.speed) - bl.speed) / bl.speed
			var pdiff: Variant = null
			var ppeak: Variant = null
			if c.body_profile is Dictionary and dump[name].frames.size() == int(c.sample_count) \
					and is_equal_approx(bsr, float(c.sample_rate)):
				var bp := _body_profile(dump[name].frames, _key_times(a, bsr, dump[name].frames.size()), bsr)
				var worst := 0.0
				for k in (bp.fwd as PackedFloat64Array).size():
					worst = maxf(worst, Vector2(float(c.body_profile.side[k]) - bp.side[k],
							float(c.body_profile.fwd[k]) - bp.fwd[k]).length())
				pdiff = worst
				ppeak = _max(bp.speed)
			c["blender"] = {"speed": bl.speed if bl.runs > 0 else null, "heading_deg": bl.heading_deg if bl.runs > 0 else null,
					"estimator": bl_est, "rel_diff": rel, "sample_rate": bsr, "profile_diff_m": pdiff,
					"profile_peak_speed": ppeak}
		c.erase("_cyclic")
		if c.travel is Dictionary:
			out.travel_count += 1
		clips[name] = c

	# --- bone sets -----------------------------------------------------------------------------
	var sets := _bone_sets(ctx, lib, src)

	# --- pitch calibration ---------------------------------------------------------------------
	var pitch := {}
	var chest_ctx := {}
	for key: String in src.aim:
		var t: Dictionary = src.aim[key]
		var w_key := key.get_slice("/", 0)
		if no_barrel(graph, w_key):
			continue   # thrown weapon: no barrel to calibrate, and its aim pose stays out of the chest mean
		var p := _pitch_table(inst, ap, sk, lib, t, BARREL_BONE.get(w_key, "r_hand_prop_attachment"), sets.hands)
		if p.has("error"):
			out.errors.append("pitch %s: %s" % [key, p.error])
			continue
		pitch[key] = p
		var base := lib.get_animation(t.base)
		var sp := sk.find_bone("spined")
		if base and sp >= 0:
			chest_ctx[key] = ctx.eval(base).global_of(sp, 0.0).origin.y
	var chest := {}
	for stance in ["stand", "crouch"]:
		var sum := 0.0
		var n := 0
		for key: String in chest_ctx:
			if key.ends_with("/" + stance):
				sum += chest_ctx[key]
				n += 1
		if n > 0:
			chest[stance] = sum / n

	# --- gt_check ------------------------------------------------------------------------------
	var gt := _gt_check(ctx, lib, dump)
	var per_clip: Dictionary = gt.get("per_clip_max_mm", {})
	var per_clip_t: Dictionary = gt.get("per_clip_max_t", {})
	gt.erase("per_clip_max_mm")
	gt.erase("per_clip_max_t")
	var flagged := PackedStringArray()
	for name: String in clips:
		if clips[name].blender is Dictionary and per_clip.has(name):
			clips[name].blender["gt_max_mm"] = per_clip[name]
			clips[name].blender["gt_max_t"] = per_clip_t[name]
		clips[name]["fidelity_warning"] = fidelity_warning(clips[name])
		if clips[name].fidelity_warning != null:
			flagged.append(name)
	if not flagged.is_empty():
		var lines := PackedStringArray()
		for name in flagged:
			lines.append("%s (%s)" % [name, "; ".join(clips[name].fidelity_warning)])
		out.warnings.append("fidelity: %d clip(s) whose library values are not the authored ones (clips.*.fidelity_warning; the key-reduced Actor_B.res needs a re-export): %s" % [
				flagged.size(), " | ".join(lines)])

	var meta := {
		"schema": SCHEMA,
		"generator": GENERATOR,
		"godot_version": Engine.get_version_info().string,
		"library_sha256": FileAccess.get_sha256(LIBRARY_RES),
		"rig_sha256": FileAccess.get_sha256(RIG),
		"graph": {"path": _rel(graph_path), "sha256": FileAccess.get_sha256(graph_path)} if not graph.is_empty() else null,
		"clip_source": src.source,
		"gt_source": {"path": "PAP/" + DUMP_REL, "sha256": FileAccess.get_sha256(dump_path)} if not dump.is_empty() else null,
		"rest": rest,
		"authorization": AUTHORIZATION,
		"units": {"length": "m", "time": "s", "speed": "m/s", "angle": "deg unless named *_rad",
				"space": "skeleton space: forward +Z, left +X, up +Y; heading_deg and yaw_deg + = left"},
		"method": {
			"travel": "GA/vmm/bl/an.py method A: heel+ball at the clip's sample rate (key times); planted = within %.2f m of the point's lowest height; least-squares slope per planted run of >= %d samples (a cyclic clip's runs wrap the seam for points whose first/last samples meet within %.2f m); body velocity = -(run-length-weighted mean foot velocity) (estimator method_a, quality native). Fallback chain when there is no such run (quality fallback): runs of >= %d samples at the clip's own rate (method_a_run2), else runs of >= %d at 2x then 4x the rate (method_a_2x / method_a_4x; travel.method_rate). kind: cyclic = the clip loops (see cyclic), speed / stride_m are its playback-rate reference; one_shot_mean = mean over the stance runs of a non-looping clip, not a rate reference (use body_profile)" % [PLANTED_TOL, MIN_RUN, PLANTED_TOL, MIN_RUN_FALLBACK, MIN_RUN],
			"cyclic": "travel.cyclic (and the wrap of travel / plant / contact estimates) = the loop flag the graph export gives the clip: any dict in actor_b_graph.json with a string `clip` and a boolean `loop` (roles, aim_move, aim_trees, actions, runtime_roles, ...), looped if any entry loops (cyclic_source graph_loop); clips no entry plays and the built-in list use the feet seam test, every heel/ball's first and last samples within %.2f m horizontally (cyclic_source feet_seam). travel.seam_m = that largest horizontal mismatch; loop / loop_err stay the measured core-bone seam" % PLANTED_TOL,
			"body_profile": "non-cyclic leg clips, at the clip's sample times t_k (the contact path): per step t_k -> t_k+1 every heel/ball point whose height stays within %.2f m of its lowest height in the clip is a contact candidate with body velocity u = -(its horizontal displacement) / step and cost (height / %.2f m)^2 + (vertical speed / %.1f m/s)^2; a path takes at most one candidate per step and costs the candidate costs + %.0f per step without one + the summed squared body acceleration in units of %.1f m/s^2 (a linear velocity ramp between candidates up to %.1f s apart, held before the first / after the last); each step's velocity is its mean over all paths weighted exp(-cost / %.0f) (forward-backward). Body displacement fwd (+Z) / side (+X = left) is the cumulative sum from 0 at t = 0; speed[k] = |displacement| central difference (one-sided at the ends); coverage = expected fraction of steps whose velocity comes from a candidate. The continuity term rejects a swing foot that skims the ground or a heel still descending (which an.py method B, the lowest point per step, integrates as body travel) and keeps a push-off foot on its toes" % [PROFILE_H_MAX, PROFILE_SIGMA_H, PROFILE_SIGMA_VY, PROFILE_GAP, PROFILE_SIGMA_A, PROFILE_GAP_MAX_S, PROFILE_TEMP],
			"fidelity": "clips.*.fidelity_warning lists why a dumped clip's library values are not the authored ones: |blender.rel_diff| > %.2f or travel heading > %.0f deg off blender.heading_deg (both speeds >= %.1f m/s), blender.gt_max_mm > %.0f (at gt_max_t), blender.profile_diff_m > %.2f m; null otherwise and without the dump. The library (Actor_B.res) is key-reduced; a dropped key shows up here" % [FIDELITY_REL, FIDELITY_HEADING_DEG, FIDELITY_MIN_SPEED, FIDELITY_GT_MM, FIDELITY_PROFILE_M],
			"plant": "normalized phase of each plant onset at %d Hz: a foot is in contact when heel or ball is within %.2f m of that point's lowest height and its ground speed |skeleton-space velocity (central difference) + body velocity| < max(%.2f m/s, %.2f x body speed); body velocity = travel velocity for cyclic clips, and for one-shot clips -(velocity of the lowest point) median-filtered over +-%.2f s; contact runs closer than %.2f s merge, runs shorter than %.2f s drop; onset = first sample of a run (not at 0 for one-shot clips); cyclic clips wrap; l_contact / r_contact = [first, last contact sample] phase of every kept run (end > 1 when a cyclic run wraps the seam; a one-shot run from t = 0 included). Bank clips (cyclic) are the contract; one-shot onsets (starts, stops, landings) are best effort" % [int(PLANT_HZ), PLANT_H_TOL, PLANT_V_ABS, PLANT_V_REL, PLANT_VB_WINDOW_S, PLANT_MIN_AIR_S, PLANT_MIN_STANCE_S],
			"loop": "first vs last sample of the core bones (chains root..%s; all keyed bones when none is keyed): skeleton-space position <= %.2f m and local rotation <= %.2f rad; 1-sample pose clips are loops; loop_err holds the worst values. Measured only: whether a role loops at runtime comes from actor_b_graph.json" % ["/".join(CORE_ENDS), LOOP_POS_TOL, LOOP_ROT_TOL],
			"pitch": "AnimationTree: base -> Add2(up, max(w,0)) -> Add2(down, max(-w,0)) -> Blend2 filtered to bone_sets.hands (amount 1, the aim grip); barrel = prop bone global basis * +Z; elev = asin(barrel.y); yaw = atan2(barrel.x, barrel.z); max_valid_* = largest |w| reached with strictly monotonic elevation and |yaw - yaw(0)| <= %.0f deg (plan 5.4 rule, reference); max_monotonic_* = largest |w| with strictly monotonic elevation" % PITCH_YAW_DRIFT_DEG,
			"pitch_range": "solve_up / solve_down = max_monotonic_up / max_monotonic_down: the runtime inverts elev(w) over the authored additives' full monotonic range (the data limit). Today's player_anim.gd maps aim elevation onto the whole additive range (w in [-1, 1] at +-83 deg), and the owner's requirement keeps today's aim range, so the plan's yaw-drift limit (max_valid_*) does not cut it; the barrel yaw drift inside the range is in yaw_deg (solve_lateral_drift_deg = the largest sideways barrel deviation asin(sin(yaw - yaw(0)) * cos(elev)) inside it) for the AimStabilizer / per-pitch yaw correction (WP5). data_limits lists each side whose elevation at the end of the range stays inside +-%.0f deg (targets beyond it clamp)" % PITCH_TARGET_DEG,
			"chest_height": "skeleton-space y of spined in the aim-idle base clip at t = 0; stand/crouch = mean over weapons",
			"pitch_skip": "no pitch table and no chest height for the thrown-weapon profiles (actor_b_graph.json profiles.<w>.clip_set \"throw\"): the throw grip's prop bone is no barrel (tests/throwables/survey_throw_clips.gd; Throwable places the held object on the throw line itself), so UpperBody maps the aim elevation linearly onto the throw aim additives (UpperBody.PITCH_FALLBACK_DEG), and the chest mean stays the firearms' and the bow's",
			"gt_check": "every dump3.jsonl clip in the library: Godot heel/ball skeleton-space positions vs Blender (x, y, z) -> (x, z, -y) at t = k / sample_rate",
			"blender": "the travel estimator chain on the Blender dump of the clip at the dump's sample rate (method_a, else method_a_run2; blender.estimator) with the clip's cyclic flag; rel_diff only when both sides used the same estimator; gt_max_mm / gt_max_t = worst heel/ball distance to the dump over its samples and its time; profile_diff_m = largest distance between body_profile's displacement and the contact path run on the dump's frames (same sample times), profile_peak_speed = that dump profile's peak speed (null without a body_profile)",
			"travel_contact": "secondary, informational: body velocity = -(mean skeleton-space velocity of heel/ball over every %d Hz sample in contact as defined for plant), %d passes starting from method A; steadier heading when method A has only 2-3-sample stances, speeds up to ~10 %% off method A (it includes touchdown / toe-off)" % [int(PLANT_HZ), CONTACT_ITERS],
		},
	}
	if opts.has("fixture"):
		meta["fixture"] = {"note": "day-1 contract fixture generated by %s from %s; same schema as animations/actor_b_clip_metrics.json" % [GENERATOR, _rel(graph_path)],
				"of": "animations/actor_b_clip_metrics.json"}
	out.data = {"meta": meta, "clips": clips, "bone_sets": sets, "pitch": pitch, "chest_height": chest,
			"chest_height_by_context": chest_ctx, "gt_check": gt}
	parent.remove_child(inst)
	inst.free()
	return out


## Clip list and aim/grip contexts: from the graph export, else the built-in list.
## True for a graph profile with no barrel (clip_set "throw": the thrown weapons).
static func no_barrel(graph: Dictionary, w: String) -> bool:
	return String(graph.get("profiles", {}).get(w, {}).get("clip_set", "")) == "throw"


static func _sources(graph: Dictionary, lib: AnimationLibrary) -> Dictionary:
	var src := {"clips": [], "aim": {}, "grips": {}, "aim_move_adds": [], "lower_clips": [], "source": "",
			"warnings": [], "loop": {}}
	var names := {}
	if not graph.is_empty():
		src.source = "graph"
		for n: String in graph.get("clips", {}):
			names[n] = true
		# Any other string in the export that names a library clip (grip chains, crouch change, ...).
		_collect_names(graph, lib, names)
		# Playback loop flag per clip (meta.method.cyclic): looped if any entry that plays it loops.
		_collect_loops(graph, src.loop)
		for key: String in graph.get("aim_trees", {}):
			var t: Dictionary = graph.aim_trees[key]
			var ctx := {}
			for slot in ["base", "up", "down", "blocked", "arms_relaxed", "hands"]:
				var r: Variant = t.get(slot, null)
				ctx[slot] = str(r.get("clip", "")) if r is Dictionary and r.get("clip", null) != null else ""
			src.aim[key] = ctx
		for w: String in graph.get("grips", {}):
			var g: Dictionary = graph.grips[w]
			var arr := PackedStringArray()
			for k in ["carry", "aim_stand", "aim_crouch"]:
				if g.get(k, null) is String and g[k] != "":
					arr.append(g[k])
			src.grips[w] = arr
		for key: String in graph.get("aim_move", {}):
			for slot: String in graph.aim_move[key]:
				var r: Variant = graph.aim_move[key][slot]
				if (slot.begins_with("up") or slot.begins_with("down")) and r is Dictionary and r.get("clip", null) is String:
					if not src.aim_move_adds.has(r.clip):
						src.aim_move_adds.append(r.clip)
		for key: String in graph.get("roles", {}):
			var r: Variant = graph.roles[key]
			if r is Dictionary and r.get("clip", null) is String and not src.lower_clips.has(r.clip):
				src.lower_clips.append(r.clip)
	else:
		src.source = "builtin"
		for key: String in BUILTIN_AIM:
			src.aim[key] = BUILTIN_AIM[key].duplicate()
			for slot: String in BUILTIN_AIM[key]:
				names[BUILTIN_AIM[key][slot]] = true
		for w: String in BUILTIN_GRIPS:
			src.grips[w] = PackedStringArray(BUILTIN_GRIPS[w])
			for c: String in BUILTIN_GRIPS[w]:
				names[c] = true
		for stem: String in BUILTIN_BANK_STEMS:
			for d: String in DIR_SUFFIX:
				names["actor_b-p-%s-%s" % [stem, d]] = true
				src.lower_clips.append("actor_b-p-%s-%s" % [stem, d])
		for stem: String in BUILTIN_AIM_WALK:
			for d: String in DIR_SUFFIX:
				names["actor_b-p-%s-%s" % [stem, d]] = true
		for c: String in BUILTIN_OTHER:
			names[c] = true
			src.lower_clips.append(c)
	var sorted := names.keys()
	sorted.sort()
	for n: String in sorted:
		if n in SKIP_CLIPS:
			continue
		if not lib.has_animation(n):
			if src.source == "builtin":
				src.warnings.append("built-in clip not in the library: " + n)
				continue
		src.clips.append(n)
	return src


static func _collect_names(v: Variant, lib: AnimationLibrary, names: Dictionary) -> void:
	if v is Dictionary:
		for k in v:
			_collect_names(v[k], lib, names)
	elif v is Array:
		for x in v:
			_collect_names(x, lib, names)
	elif v is String and v.begins_with("actor_b") and lib.has_animation(v):
		names[v] = true


## clip -> bool: the `loop` flag of every dict in the graph export that has a string `clip` and a
## boolean `loop` (roles, aim_move, aim_trees, actions, runtime_roles, crouch_change, hand_states);
## true when any of them loops.
static func _collect_loops(v: Variant, loops: Dictionary) -> void:
	if v is Dictionary:
		if v.get("clip", null) is String and v.get("loop", null) is bool:
			loops[v.clip] = bool(loops.get(v.clip, false)) or bool(v.loop)
		for k in v:
			_collect_loops(v[k], loops)
	elif v is Array:
		for x in v:
			_collect_loops(x, loops)


## Whether a clip of the (cached) library was changed in memory by the traversal's key smoothing: a clip
## resampled by TravInertializer.resample_hermite (meta trav_hermite), or a rotation / position track
## turned CUBIC by smooth_clip_tracks (Actor_B.res stores every such track LINEAR).
static func _changed_in_memory(lib: AnimationLibrary) -> bool:
	for nm in lib.get_animation_list():
		var a := lib.get_animation(nm)
		if a.has_meta("trav_hermite"):
			return true
		for t in a.get_track_count():
			var ty := a.track_get_type(t)
			if (ty == Animation.TYPE_ROTATION_3D or ty == Animation.TYPE_POSITION_3D) \
					and a.track_get_interpolation_type(t) == Animation.INTERPOLATION_CUBIC:
				return true
	return false


static func _ensure_rest(sk: Skeleton3D, ap: AnimationPlayer) -> Dictionary:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == &"BindRest":
			var s: Script = load(c["path"])
			if s:
				var d: Dictionary = s.call("ensure", sk, ap, StringName(LIB))
				var r := {}
				for k in ["ok", "max_rot", "max_pos", "max_scl", "channels", "stamped", "changed", "reason"]:
					if d.has(k):
						r[k] = d[k]
				return r
	return {"ok": false, "reason": "BindRest (scripts/player/anim/bind_rest.gd) not found; run Godot --import"}


# --- per-clip ----------------------------------------------------------------------------------

## graph_loop: the graph export's loop flag for the clip (bool), or null when no graph entry plays it.
## The returned dict carries a transient "_cyclic" (bool, or null for clips without travel analysis)
## that measure() uses for the Blender side and then erases.
static func _clip_metrics(ctx: _Rig, name: String, a: Animation, graph_loop: Variant = null) -> Dictionary:
	var ev := ctx.eval(a)
	var sr := float(a.get_meta("sample_rate", 30.0)) if a.has_meta("sample_rate") else 30.0
	var n := int(a.get_meta("sample_count", 0)) if a.has_meta("sample_count") else 0
	if n <= 0:
		n = maxi(1, roundi(a.length * sr) + 1)
	var additive := bool(a.get_meta("additive_source", false)) if a.has_meta("additive_source") else false
	var keyed := PackedStringArray()
	for b: int in ev.keyed:
		keyed.append(ctx.names[b])
	keyed.sort()
	var c := {
		"length": a.length,
		"sample_rate": sr,
		"sample_count": n,
		"native_asset_id": str(a.get_meta("native_asset_id", "")) if a.has_meta("native_asset_id") else null,
		"additive": additive,
		"keyed_bones": keyed,
		"loop": false,
		"loop_err": {},
		"travel": null,
		"plant": null,
		"heel_z": null,
		"body_profile": null,
		"blender": null,
		"fidelity_warning": null,
		"_cyclic": null,
	}
	var lc := _loop_check(ctx, ev, a, n)
	c.loop = lc.loop
	lc.erase("loop")
	c.loop_err = lc
	var legs := false
	for b in LEG_BONES:
		if ev.keyed.has(ctx.bone(b)):
			legs = true
	if additive or not legs or n < MIN_RUN_FALLBACK:
		return c
	var times := _key_times(a, sr, n)
	var frames := []
	for t in times:
		frames.append(_points(ctx, ev, t))
	# Cyclic (meta.method.cyclic): the graph's loop flag when an entry plays the clip, else the feet seam.
	var seam := _feet_seam(frames)
	var cyclic: bool = bool(graph_loop) if graph_loop is bool else seam < PLANTED_TOL
	c._cyclic = cyclic
	# Estimator chain (meta.method.travel): method A at the clip's own rate, then 2-sample runs at that
	# rate, then method A at 2x / 4x the rate.
	var tr := _travel_from_frames(frames, 1.0 / sr, MIN_RUN, cyclic)
	var rate := sr
	var min_run := MIN_RUN
	var estimator := "method_a"
	if tr.runs == 0:
		tr = _travel_from_frames(frames, 1.0 / sr, MIN_RUN_FALLBACK, cyclic)
		min_run = MIN_RUN_FALLBACK
		estimator = "method_a_run2"
	for mult in [2, 4]:
		if tr.runs > 0:
			break
		rate = sr * mult
		min_run = MIN_RUN
		estimator = "method_a_%dx" % mult
		var fr2 := []
		for t in _key_times(a, rate, roundi(a.length * rate) + 1):
			fr2.append(_points(ctx, ev, t))
		tr = _travel_from_frames(fr2, 1.0 / rate, MIN_RUN, cyclic)
	var plant := _plants(ctx, ev, a, cyclic, Vector2(tr.side, tr.fwd))
	var travel: Variant = null
	if tr.runs > 0:
		travel = {"speed": tr.speed, "heading_deg": tr.heading_deg, "fwd": tr.fwd, "side": tr.side,
				"stride_m": tr.speed * a.length, "cycles": roundi((plant.l.size() + plant.r.size()) / 2.0),
				"runs": tr.runs, "cyclic": cyclic, "kind": "cyclic" if cyclic else "one_shot_mean",
				"cyclic_source": "graph_loop" if graph_loop is bool else "feet_seam", "seam_m": seam,
				"estimator": estimator, "quality": "native" if estimator == "method_a" else "fallback",
				"min_run": min_run, "method_rate": rate,
				"contact": _contact_velocity(ctx, ev, a, cyclic, Vector2(tr.side, tr.fwd))}
	c.travel = travel
	c.plant = plant
	if not cyclic:
		c.body_profile = _body_profile(frames, times, sr)
	var hl := PackedFloat64Array()
	var hr := PackedFloat64Array()
	for f: Array in frames:
		hl.append(f[0].z)
		hr.append(f[2].z)
	c.heel_z = {"rate": sr, "l": hl, "r": hr}
	return c


## Why a clip's library values are not the authored ones (meta.method.fidelity), from its blender
## record: null when there is no dump record or nothing diverges, else the reasons.
static func fidelity_warning(c: Dictionary) -> Variant:
	var bl: Variant = c.get("blender", null)
	if not (bl is Dictionary):
		return null
	var why := PackedStringArray()
	var t: Variant = c.get("travel", null)
	if t is Dictionary and bl.speed != null and float(bl.speed) >= FIDELITY_MIN_SPEED and float(t.speed) >= FIDELITY_MIN_SPEED:
		if bl.rel_diff != null and absf(float(bl.rel_diff)) > FIDELITY_REL:
			why.append("travel.speed %.3f m/s is %+.0f %% off the Blender dump's %.3f" % [t.speed, 100.0 * float(bl.rel_diff), bl.speed])
		if bl.heading_deg != null:
			var dh := wrapf(float(t.heading_deg) - float(bl.heading_deg), -180.0, 180.0)
			if absf(dh) > FIDELITY_HEADING_DEG:
				why.append("travel.heading_deg %.1f is %+.1f deg off the dump's %.1f" % [t.heading_deg, dh, bl.heading_deg])
	if bl.get("gt_max_mm", null) != null and float(bl.gt_max_mm) > FIDELITY_GT_MM:
		why.append("a heel/ball sample is %.1f mm off the dump (t = %.3f s)" % [bl.gt_max_mm, float(bl.get("gt_max_t", 0.0))])
	if bl.get("profile_diff_m", null) != null and float(bl.profile_diff_m) > FIDELITY_PROFILE_M:
		why.append("body_profile displacement is up to %.3f m off the dump's" % bl.profile_diff_m)
	return why if not why.is_empty() else null


static func _max(xs: PackedFloat64Array) -> float:
	var m := 0.0
	for x in xs:
		m = maxf(m, x)
	return m


## Largest horizontal distance between a heel/ball point's first and last sample.
static func _feet_seam(frames: Array) -> float:
	var n := frames.size()
	var mism := 0.0
	if n < 2:
		return mism
	for p in POINTS.size():
		var a: Vector3 = frames[0][p]
		var b: Vector3 = frames[n - 1][p]
		mism = maxf(mism, Vector2(a.x - b.x, a.z - b.z).length())
	return mism


## Sample times t_k = k / rate, k = 0 .. n-1, clamped to the clip length.
static func _key_times(a: Animation, rate: float, n: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for k in n:
		out.append(minf(k / rate, a.length))
	return out


static func _points(ctx: _Rig, ev: _Eval, t: float) -> Array:
	var g := ev.globals(ctx.feet_closure, t)
	var out := []
	for p: String in POINTS:
		out.append((g[ctx.bone(p)] as Transform3D).origin)
	return out


## GA/vmm/bl/an.py method A on frames = [[l_heel, l_ball, r_heel, r_ball] (Vector3, skeleton space)]
## sampled every dt, over planted runs of >= min_run samples. cyclic: whether the clip loops (null =
## the feet seam test, every point's first/last samples within PLANTED_TOL horizontally); in a cyclic
## clip a point's runs wrap the seam when that point's own first/last samples meet within PLANTED_TOL
## (a point that pops at the seam has its runs split there instead). {speed, heading_deg, fwd, side,
## runs, cyclic}.
static func _travel_from_frames(frames: Array, dt: float, min_run := MIN_RUN, cyclic: Variant = null) -> Dictionary:
	var n := frames.size()
	var out := {"speed": 0.0, "heading_deg": 0.0, "fwd": 0.0, "side": 0.0, "runs": 0, "cyclic": false}
	if n < 2:
		return out
	var cyc: bool = bool(cyclic) if cyclic is bool else _feet_seam(frames) < PLANTED_TOL
	out.cyclic = cyc
	var sum_v := Vector2.ZERO
	var sum_n := 0
	for p in POINTS.size():
		var a0: Vector3 = frames[0][p]
		var a1: Vector3 = frames[n - 1][p]
		var wrap := cyc and Vector2(a0.x - a1.x, a0.z - a1.z).length() < PLANTED_TOL
		var c := n - 1 if wrap else n
		var ymin := INF
		for k in c:
			ymin = minf(ymin, (frames[k][p] as Vector3).y)
		var pl := []
		for k in c:
			pl.append((frames[k][p] as Vector3).y < ymin + PLANTED_TOL)
		if not pl.has(false):
			continue
		var start: int = pl.find(false) if wrap else 0
		var cur := PackedInt32Array()
		for j in c + 1:
			var k := (start + j) % c if wrap else j
			if j < c and pl[k]:
				cur.append(j)
				continue
			if cur.size() >= min_run:
				var v := _slope(frames, cur, start, c, wrap, p, dt)
				sum_v += v * cur.size()
				sum_n += cur.size()
				out.runs += 1
			cur = PackedInt32Array()
	if sum_n > 0:
		var body := -sum_v / sum_n   # x = left (+X), y = forward (+Z)
		out.speed = body.length()
		out.heading_deg = rad_to_deg(atan2(body.x, body.y))
		out.fwd = body.y
		out.side = body.x
	return out


## Time-resolved body travel of a non-cyclic clip (meta.method.body_profile, "the contact path") from
## frames = [[l_heel, l_ball, r_heel, r_ball] (Vector3, skeleton space)] at the clip's sample times
## `times` (nominal rate `rate`).
##   Candidates: per step s (times[s] -> times[s+1]) each point whose height stays within PROFILE_H_MAX
##   of its lowest height in the clip; body velocity u = -(its horizontal displacement) / step; cost
##   (height / PROFILE_SIGMA_H)^2 + (vertical speed / PROFILE_SIGMA_VY)^2.
##   Paths: at most one candidate per step, in step order. Cost = the candidate costs + PROFILE_GAP per
##   step without one + the summed squared body acceleration in units of PROFILE_SIGMA_A (between picks
##   m = s - j steps apart the velocity is a linear ramp: |u_s - u_j|^2 / (PROFILE_SIGMA_A / rate)^2 / m,
##   m <= PROFILE_GAP_MAX_S * rate; before the first / after the last pick it is held).
##   Estimate: each step's velocity is its mean over all paths weighted exp(-cost / PROFILE_TEMP)
##   (forward-backward in log space; the costs are Gaussian chi^2 terms, so PROFILE_TEMP = 2 is the
##   likelihood). The posterior mean, unlike the single cheapest path, moves smoothly when the data
##   move a little (a hard pick flipped the displacement of a sprint start by 15 cm on 10 mm of
##   difference between the library and the Blender dump).
## The continuity term is what an.py method B (the lowest point per step) lacks: a swing foot skimming
## the ground, or a heel still descending at touchdown, is lower than the stance foot but implies a jump
## in body velocity, so paths through it carry little weight; a push-off foot on its toes (ball a few cm
## up) keeps its weight because the body velocity stays continuous through it.
## {rate, fwd: [m], side: [m] (cumulative from 0 at t = 0; fwd = +Z, side = +X = left), speed: [m/s]
## (|displacement| central difference, one-sided at the ends), coverage: expected fraction of steps whose
## velocity comes from a contact candidate}.
static func _body_profile(frames: Array, times: PackedFloat64Array, rate: float) -> Dictionary:
	var n := frames.size()
	var steps := n - 1
	var ymin := [INF, INF, INF, INF]
	for k in n:
		for p in 4:
			ymin[p] = minf(ymin[p], (frames[k][p] as Vector3).y)
	var dur := PackedFloat64Array()
	for s in steps:
		dur.append(times[s + 1] - times[s])
	# Candidate nodes in step order: step, cost, body velocity (ux = side, uz = fwd).
	var ns := PackedInt32Array()
	var nc := PackedFloat64Array()
	var ux := PackedFloat64Array()
	var uz := PackedFloat64Array()
	for s in steps:
		for p in 4:
			var a: Vector3 = frames[s][p]
			var b: Vector3 = frames[s + 1][p]
			var e := maxf(a.y, b.y) - float(ymin[p])
			if dur[s] <= 1e-6 or e >= PROFILE_H_MAX:
				continue
			var vy := (b.y - a.y) / dur[s]
			ns.append(s)
			nc.append(pow(e / PROFILE_SIGMA_H, 2.0) + pow(vy / PROFILE_SIGMA_VY, 2.0))
			ux.append(-(b.x - a.x) / dur[s])
			uz.append(-(b.z - a.z) / dur[s])
	var nn := ns.size()
	var gmax := maxi(1, roundi(PROFILE_GAP_MAX_S * rate))
	var s2 := pow(PROFILE_SIGMA_A / rate, 2.0)
	var tt := PROFILE_TEMP
	# Forward: la[i] = log of the weight of every path prefix ending at node i (its cost included).
	var la := PackedFloat64Array()
	la.resize(nn)
	for i in nn:
		var acc := -PROFILE_GAP * ns[i] / tt
		for j in range(i - 1, -1, -1):
			if ns[j] >= ns[i]:
				continue
			if ns[i] - ns[j] > gmax:
				break
			acc = _lse2(acc, la[j] - _edge_cost(ns, ux, uz, j, i, s2) / tt)
		la[i] = acc - nc[i] / tt
	# Backward: lb[i] = log of the weight of every path suffix after node i (its cost excluded).
	var lb := PackedFloat64Array()
	lb.resize(nn)
	for i in range(nn - 1, -1, -1):
		var acc := -PROFILE_GAP * (steps - 1 - ns[i]) / tt
		for k in range(i + 1, nn):
			if ns[k] <= ns[i]:
				continue
			if ns[k] - ns[i] > gmax:
				break
			acc = _lse2(acc, lb[k] - _edge_cost(ns, ux, uz, i, k, s2) / tt - nc[k] / tt)
		lb[i] = acc
	var log_z := -PROFILE_GAP * steps / tt   # the empty path (velocity 0)
	for i in nn:
		log_z = _lse2(log_z, la[i] - PROFILE_GAP * (steps - 1 - ns[i]) / tt)
	# Posterior-mean velocity per step: picked nodes, ramps across gaps, held ends.
	var vx := PackedFloat64Array()
	var vz := PackedFloat64Array()
	vx.resize(steps)
	vz.resize(steps)
	vx.fill(0.0)
	vz.fill(0.0)
	var picked := 0.0
	for i in nn:
		var w := exp(la[i] + lb[i] - log_z)
		vx[ns[i]] += w * ux[i]
		vz[ns[i]] += w * uz[i]
		picked += w
		if ns[i] > 0:   # paths that start at node i hold u_i before it
			var ws := exp(-PROFILE_GAP * ns[i] / tt - nc[i] / tt + lb[i] - log_z)
			for t in ns[i]:
				vx[t] += ws * ux[i]
				vz[t] += ws * uz[i]
		if ns[i] < steps - 1:   # paths that end at node i hold u_i after it
			var we := exp(la[i] - PROFILE_GAP * (steps - 1 - ns[i]) / tt - log_z)
			for t in range(ns[i] + 1, steps):
				vx[t] += we * ux[i]
				vz[t] += we * uz[i]
		for j in range(i - 1, -1, -1):   # gap edges j -> i (at least one step between)
			if ns[i] - ns[j] < 2:
				continue
			if ns[i] - ns[j] > gmax:
				break
			var wg := exp(la[j] - _edge_cost(ns, ux, uz, j, i, s2) / tt - nc[i] / tt + lb[i] - log_z)
			if wg < 1e-12:
				continue
			var m := float(ns[i] - ns[j])
			for t in range(ns[j] + 1, ns[i]):
				var f := (t - ns[j]) / m
				vx[t] += wg * (ux[j] + (ux[i] - ux[j]) * f)
				vz[t] += wg * (uz[j] + (uz[i] - uz[j]) * f)
	var fwd := PackedFloat64Array([0.0])
	var side := PackedFloat64Array([0.0])
	var acc_x := 0.0
	var acc_z := 0.0
	for s in steps:
		acc_x += vx[s] * dur[s]
		acc_z += vz[s] * dur[s]
		side.append(acc_x)
		fwd.append(acc_z)
	var speed := PackedFloat64Array()
	for k in n:
		var ka := maxi(k - 1, 0)
		var kb := mini(k + 1, n - 1)
		var span := times[kb] - times[ka] if kb > ka else 0.0
		speed.append(sqrt(pow(side[kb] - side[ka], 2.0) + pow(fwd[kb] - fwd[ka], 2.0)) / span if span > 1e-6 else 0.0)
	return {"rate": rate, "fwd": fwd, "side": side, "speed": speed,
			"coverage": clampf(picked / steps, 0.0, 1.0) if steps > 0 else 0.0}


## Transition cost of the contact path between nodes j and i (steps ns[j] < ns[i]): PROFILE_GAP per
## skipped step + the summed squared acceleration of the linear velocity ramp between them.
static func _edge_cost(ns: PackedInt32Array, ux: PackedFloat64Array, uz: PackedFloat64Array, j: int, i: int, s2: float) -> float:
	var m := ns[i] - ns[j]
	var du2 := (ux[i] - ux[j]) * (ux[i] - ux[j]) + (uz[i] - uz[j]) * (uz[i] - uz[j])
	return PROFILE_GAP * (m - 1) + du2 / s2 / m


## log(exp(a) + exp(b)), -INF-safe.
static func _lse2(a: float, b: float) -> float:
	if a == -INF:
		return b
	if b == -INF:
		return a
	var m := maxf(a, b)
	return m + log(exp(a - m) + exp(b - m))


static func _slope(frames: Array, js: PackedInt32Array, start: int, c: int, cyclic: bool, p: int, dt: float) -> Vector2:
	var mt := 0.0
	var m := Vector2.ZERO
	for j in js:
		var q: Vector3 = frames[(start + j) % c if cyclic else j][p]
		mt += j * dt
		m += Vector2(q.x, q.z)
	mt /= js.size()
	m /= js.size()
	var num := Vector2.ZERO
	var den := 0.0
	for j in js:
		var q: Vector3 = frames[(start + j) % c if cyclic else j][p]
		var d := j * dt - mt
		num += d * (Vector2(q.x, q.z) - m)
		den += d * d
	return num / den if den > 0.0 else Vector2.ZERO


## Plant onsets per foot as normalized phases, from PLANT_HZ samples. A foot is in contact at a
## sample when its heel or ball is within PLANT_H_TOL of that point's lowest height in the clip AND
## moves over the ground slower than max(PLANT_V_ABS, PLANT_V_REL * body speed) (ground velocity =
## skeleton-space point velocity (central difference) + the body velocity, so a planted foot reads
## ~0; the body velocity is the clip's travel velocity vb for cyclic clips, and for one-shot clips,
## which accelerate or brake, a local estimate: -(velocity of the lowest point), component-wise
## median over +-PLANT_VB_WINDOW_S). Contact runs separated by less than PLANT_MIN_AIR_S merge; runs shorter than
## PLANT_MIN_STANCE_S are dropped; an onset is the first sample of a remaining run (a one-shot clip
## that starts planted has no onset at 0). Cyclic clips wrap. The velocity term separates a real
## touchdown from the post-swing hover (feet 4-7 cm up, still moving) and still finds stances planted
## a few cm higher than the clip's lowest (multi-stride sprint / crouch clips); every locomotion and
## aim-walk bank clip gets alternating left/right onsets, one pair per gait cycle.
## {l, r: onset phases; l_contact, r_contact: [first, last contact sample] phases of every kept run,
## including a one-shot run from t = 0; end > 1 when a cyclic run wraps the seam; [[0, 1]] when the
## foot never leaves contact}.
static func _plants(ctx: _Rig, ev: _Eval, a: Animation, cyclic: bool, vb: Vector2) -> Dictionary:
	var m := maxi(2, roundi(a.length * PLANT_HZ))
	var dt := a.length / m
	var pts := []   # per sample: [l_heel, l_ball, r_heel, r_ball] (Vector3)
	for k in m + 1:
		pts.append(_points(ctx, ev, k * dt))
	var n := m if cyclic else m + 1
	var min_air := maxi(1, roundi(PLANT_MIN_AIR_S / dt))
	var min_st := maxi(1, roundi(PLANT_MIN_STANCE_S / dt))
	var ymin_all := [INF, INF, INF, INF]
	for k in n:
		for p in 4:
			ymin_all[p] = minf(ymin_all[p], (pts[k][p] as Vector3).y)
	var seam_ok := _seam_ok(pts, m)
	# Body velocity per sample: the clip's constant travel velocity for cyclic clips; one-shot clips
	# (starts, stops, landings) accelerate or brake, so they use a local estimate: -(horizontal
	# velocity of the lowest point) with a component-wise median over +-PLANT_VB_WINDOW_S.
	var vbs := []
	if cyclic:
		for k in n:
			vbs.append(vb)
	else:
		var raw := []
		for k in n:
			var low := 0
			for p in range(1, 4):
				if (pts[k][p] as Vector3).y - ymin_all[p] < (pts[k][low] as Vector3).y - ymin_all[low]:
					low = p
			raw.append(-_hvel(pts, k, low, n, dt, false))
		var win := maxi(1, roundi(PLANT_VB_WINDOW_S / dt))
		for k in n:
			var xs := PackedFloat64Array()
			var zs := PackedFloat64Array()
			for j in range(-win, win + 1):
				var v: Vector2 = raw[clampi(k + j, 0, n - 1)]
				xs.append(v.x)
				zs.append(v.y)
			xs.sort()
			zs.sort()
			vbs.append(Vector2(xs[xs.size() / 2], zs[zs.size() / 2]))
	var out := {"l": PackedFloat64Array(), "r": PackedFloat64Array(), "l_contact": [], "r_contact": []}
	for foot in 2:
		var contact := []
		for k in n:
			var vbk: Vector2 = vbs[k]
			var vtol := maxf(PLANT_V_ABS, PLANT_V_REL * vbk.length())
			var ok := false
			for i in 2:
				var p := foot * 2 + i
				var g := _hvel(pts, k, p, n, dt, cyclic, seam_ok[p]) + vbk
				if (pts[k][p] as Vector3).y - ymin_all[p] < PLANT_H_TOL and g.length() < vtol:
					ok = true
			contact.append(ok)
		var onsets := PackedFloat64Array()
		var intervals := []
		if not contact.has(false):
			intervals.append([0.0, 1.0])
		if contact.has(true) and contact.has(false):
			var start: int = contact.find(false) if cyclic else 0
			var runs := []
			var j := 0
			while j < n:
				if contact[(start + j) % n]:
					var s0 := j
					while j < n and contact[(start + j) % n]:
						j += 1
					if not runs.is_empty() and s0 - runs[-1][1] < min_air:
						runs[-1][1] = j
					else:
						runs.append([s0, j])
				else:
					j += 1
			if cyclic and runs.size() > 1 and runs[0][0] + n - runs[-1][1] < min_air:
				var first: Array = runs.pop_front()
				runs[-1][1] = first[1] + n
			for r: Array in runs:
				if r[1] - r[0] < min_st:
					continue
				var t: float = ((start + int(r[0])) % n) * dt
				intervals.append([t / a.length, (t + (int(r[1]) - 1 - int(r[0])) * dt) / a.length])
				if not cyclic and r[0] == 0:
					continue
				onsets.append(t / a.length)
		onsets.sort()
		intervals.sort_custom(func(x, y): return x[0] < y[0])
		out["l" if foot == 0 else "r"] = onsets
		out["l_contact" if foot == 0 else "r_contact"] = intervals
	return out


## Horizontal (x = left, y = forward) velocity of point p at sample k: central difference, cyclic
## wrap, one-sided at the ends of a one-shot clip. In a cyclic clip (n = the PLANT_HZ sample count, pts
## also holds the t = length sample pts[n]) a point that pops at the seam (seam_ok false) is not
## differenced across it: forward difference at k = 0, and pts[n] instead of pts[0] after k = n - 1.
static func _hvel(pts: Array, k: int, p: int, n: int, dt: float, cyclic: bool, seam_ok := true) -> Vector2:
	var ka := (k - 1 + n) % n if cyclic else maxi(k - 1, 0)
	var kb := (k + 1) % n if cyclic else mini(k + 1, n - 1)
	var span := 2 if cyclic else kb - ka
	if cyclic and not seam_ok:
		if k == 0:
			ka = 0
			span = 1
		elif k == n - 1:
			kb = n
	if span <= 0:
		return Vector2.ZERO
	var d: Vector3 = (pts[kb][p] as Vector3) - (pts[ka][p] as Vector3)
	return Vector2(d.x, d.z) / (span * dt)


## Per heel/ball point: whether its first (pts[0]) and t = length (pts[m]) samples meet within
## PLANTED_TOL horizontally, i.e. whether a cyclic clip may difference it across the seam.
static func _seam_ok(pts: Array, m: int) -> Array:
	var ok := []
	for p in 4:
		var a: Vector3 = pts[0][p]
		var b: Vector3 = pts[m][p]
		ok.append(Vector2(a.x - b.x, a.z - b.z).length() < PLANTED_TOL)
	return ok


## Secondary travel estimate (not the plan's method; informational): body velocity = -(mean
## skeleton-space velocity of heel/ball over every PLANT_HZ sample where that point is in contact,
## as defined in _plants), iterated CONTACT_ITERS times from method A's vb. Less sensitive to the
## sample rate than method A when stances are only 2-3 key samples long (sprint strafes), but it
## includes touchdown / toe-off samples, so its speeds run up to ~10 % off method A.
## {speed, heading_deg, fwd, side, samples} (samples = contact point-samples of the last pass).
static func _contact_velocity(ctx: _Rig, ev: _Eval, a: Animation, cyclic: bool, vb0: Vector2) -> Dictionary:
	var m := maxi(2, roundi(a.length * PLANT_HZ))
	var dt := a.length / m
	var pts := []
	for k in m + 1:
		pts.append(_points(ctx, ev, k * dt))
	var n := m if cyclic else m + 1
	var ymin := [INF, INF, INF, INF]
	for k in n:
		for p in 4:
			ymin[p] = minf(ymin[p], (pts[k][p] as Vector3).y)
	var seam_ok := _seam_ok(pts, m)
	var vb := vb0
	var cnt := 0
	for it in CONTACT_ITERS:
		var vtol := maxf(PLANT_V_ABS, PLANT_V_REL * vb.length())
		var sum := Vector2.ZERO
		cnt = 0
		for k in n:
			for p in 4:
				var v := _hvel(pts, k, p, n, dt, cyclic, seam_ok[p])
				if (pts[k][p] as Vector3).y - ymin[p] < PLANT_H_TOL and (v + vb).length() < vtol:
					sum += v
					cnt += 1
		if cnt == 0:
			break
		vb = -sum / cnt
	return {"speed": vb.length(), "heading_deg": rad_to_deg(atan2(vb.x, vb.y)), "fwd": vb.y, "side": vb.x, "samples": cnt}


## First vs last sample of the clip's core bones (all keyed bones when it keys no core bone):
## {loop: bool, pos_m, rot_rad (worst over the bones), bone (worst, by tolerance ratio)}.
static func _loop_check(ctx: _Rig, ev: _Eval, a: Animation, n: int) -> Dictionary:
	var out := {"loop": true, "pos_m": 0.0, "rot_rad": 0.0, "bone": null}
	if n <= 1 or a.length <= 0.0011:
		return out
	var bones := PackedInt32Array()
	for b: int in ctx.core:
		if ev.keyed.has(b):
			bones.append(b)
	if bones.is_empty():
		bones = PackedInt32Array(ev.keyed.keys())
		bones.sort()
	if bones.is_empty():
		return out
	var clo := ctx.closure(bones)
	var g0 := ev.globals(clo, 0.0)
	var g1 := ev.globals(clo, a.length)
	var worst := 0.0
	for b in bones:
		var dp := (g0[b] as Transform3D).origin.distance_to((g1[b] as Transform3D).origin)
		var dr := _qangle(ev.local(b, 0.0).basis.get_rotation_quaternion(), ev.local(b, a.length).basis.get_rotation_quaternion())
		out.pos_m = maxf(out.pos_m, dp)
		out.rot_rad = maxf(out.rot_rad, dr)
		var ratio := maxf(dp / LOOP_POS_TOL, dr / LOOP_ROT_TOL)
		if ratio > worst:
			worst = ratio
			out.bone = ctx.names[b]
	out.loop = out.pos_m <= LOOP_POS_TOL and out.rot_rad <= LOOP_ROT_TOL
	return out


# --- bone sets ---------------------------------------------------------------------------------

static func _bone_sets(ctx: _Rig, lib: AnimationLibrary, src: Dictionary) -> Dictionary:
	var sk := ctx.sk
	var root := sk.find_bone("root")
	var upper_base := sk.find_bone("upper_base")
	var lower_base := sk.find_bone("lower_base")
	var aim_clips := {}
	var add_clips := {}
	for key: String in src.aim:
		for slot: String in src.aim[key]:
			var c: String = src.aim[key][slot]
			if c != "":
				aim_clips[c] = true
				if slot in ["up", "down"]:
					add_clips[c] = true
	for c: String in src.aim_move_adds:
		add_clips[c] = true
	var grip_clips := {}
	for w: String in src.grips:
		for c: String in src.grips[w]:
			grip_clips[c] = true
	for key: String in src.aim:
		if src.aim[key].get("hands", "") != "":
			grip_clips[src.aim[key].hands] = true
	var upper := {}
	for c: String in aim_clips:
		for b: int in _keyed(lib, c, sk):
			if b == root or (lower_base >= 0 and ctx.is_under(b, lower_base)) or ctx.names[b].begins_with("holster"):
				continue
			if (upper_base >= 0 and ctx.is_under(b, upper_base)) or (ctx.parents[b] == root and "_offset" in ctx.names[b]):
				upper[ctx.names[b]] = true
	if upper_base >= 0:
		upper["upper_base"] = true
	var re := RegEx.create_from_string(HANDS_RE)
	var hands := {}
	for c: String in grip_clips:
		for b: int in _keyed(lib, c, sk):
			if re.search(ctx.names[b]) != null:
				hands[ctx.names[b]] = true
	var stabilized := {}
	if upper_base >= 0:
		stabilized["upper_base"] = true
	for n: String in upper:
		if ctx.parents[sk.find_bone(n)] == root:
			stabilized[n] = true
	var pitch_add := {}
	for c: String in add_clips:
		for b: int in _keyed(lib, c, sk):
			pitch_add[ctx.names[b]] = true
	var lower := {}
	for c: String in src.lower_clips:
		for b: int in _keyed(lib, c, sk):
			var n: String = ctx.names[b]
			if not upper.has(n) and not hands.has(n) and (b == root or (lower_base >= 0 and ctx.is_under(b, lower_base))):
				lower[n] = true
	if lower_base >= 0:
		lower["lower_base"] = true
	return {"upper": _sorted_keys(upper), "hands": _sorted_keys(hands), "stabilized": _sorted_keys(stabilized),
			"pitch_add_union": _sorted_keys(pitch_add), "lower": _sorted_keys(lower)}


static func _keyed(lib: AnimationLibrary, clip: String, sk: Skeleton3D) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not lib.has_animation(clip):
		return out
	var a := lib.get_animation(clip)
	for t in a.get_track_count():
		if a.track_get_type(t) not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var b := sk.find_bone(str(a.track_get_path(t).get_concatenated_subnames()))
		if b >= 0 and not out.has(b):
			out.append(b)
	return out


static func _sorted_keys(d: Dictionary) -> PackedStringArray:
	var k := PackedStringArray(d.keys())
	k.sort()
	return k


# --- pitch calibration -------------------------------------------------------------------------

## Pitch table of one aim context t = {base, up, down, hands, ...} (clip names).
static func _pitch_table(inst: Node3D, ap: AnimationPlayer, sk: Skeleton3D, lib: AnimationLibrary, t: Dictionary,
		barrel: String, hands: PackedStringArray) -> Dictionary:
	for slot in ["base", "up", "down"]:
		if str(t.get(slot, "")) == "" or not lib.has_animation(t[slot]):
			return {"error": "%s clip missing (%s)" % [slot, t.get(slot, "")]}
	var bi := sk.find_bone(barrel)
	if bi < 0:
		return {"error": "no bone " + barrel}
	var grip: String = str(t.get("hands", ""))
	var tree := pitch_tree(inst, ap, t.base, t.up, t.down, grip if grip != "" and lib.has_animation(grip) else "", hands)
	var weights := PackedFloat64Array()
	var elev := PackedFloat64Array()
	var yaw := PackedFloat64Array()
	var steps := roundi(1.0 / PITCH_STEP)
	for i in range(-steps, steps + 1):
		var w := i * PITCH_STEP
		var d := pitch_eval(tree, sk, bi, w)
		weights.append(w)
		elev.append(d.x)
		yaw.append(d.y)
	tree.get_parent().remove_child(tree)
	tree.free()
	var z := steps   # index of w = 0
	var up := 0.0
	for i in range(z + 1, elev.size()):
		if elev[i] > elev[i - 1] and absf(wrapf(yaw[i] - yaw[z], -180.0, 180.0)) <= PITCH_YAW_DRIFT_DEG:
			up = weights[i]
		else:
			break
	var down := 0.0
	for i in range(z - 1, -1, -1):
		if elev[i] < elev[i + 1] and absf(wrapf(yaw[i] - yaw[z], -180.0, 180.0)) <= PITCH_YAW_DRIFT_DEG:
			down = -weights[i]
		else:
			break
	# Elevation-only monotonic range (the authored adds' full usable range, ignoring yaw drift).
	var mono_up := 0.0
	for i in range(z + 1, elev.size()):
		if elev[i] > elev[i - 1]:
			mono_up = weights[i]
		else:
			break
	var mono_down := 0.0
	for i in range(z - 1, -1, -1):
		if elev[i] < elev[i + 1]:
			mono_down = -weights[i]
		else:
			break
	# Solve range (meta.method.pitch_range): the full monotonic range, i.e. the data limit.
	var i_up := z + roundi(mono_up / PITCH_STEP)
	var i_dn := z - roundi(mono_down / PITCH_STEP)
	# Sideways angular deviation of the barrel from the w = 0 aim plane: asin(sin(dyaw) * cos(elev)).
	# (Raw yaw differences blow up near vertical, where yaw is ill-defined.)
	var drift := 0.0
	for i in range(i_dn, i_up + 1):
		var dy := deg_to_rad(wrapf(yaw[i] - yaw[z], -180.0, 180.0))
		drift = maxf(drift, absf(rad_to_deg(asin(clampf(sin(dy) * cos(deg_to_rad(elev[i])), -1.0, 1.0)))))
	var limits := PackedStringArray()
	if elev[i_dn] > -PITCH_TARGET_DEG:
		limits.append("down: the authored data reaches only %.1f deg (w = %.2f, %s); lower aim targets clamp there" % [
				elev[i_dn], -mono_down, "the full down additive" if mono_down >= 1.0 else "where elevation stops decreasing"])
	if elev[i_up] < PITCH_TARGET_DEG:
		limits.append("up: the authored data reaches only %.1f deg (w = %.2f, %s); higher aim targets clamp there" % [
				elev[i_up], mono_up, "the full up additive" if mono_up >= 1.0 else "where elevation stops increasing"])
	return {"weights": weights, "elev_deg": elev, "yaw_deg": yaw, "zero_elev_deg": elev[z], "zero_yaw_deg": yaw[z],
			"max_valid_up": up, "max_valid_down": down, "elev_at_max_up": elev[z + roundi(up / PITCH_STEP)],
			"elev_at_max_down": elev[z - roundi(down / PITCH_STEP)], "max_monotonic_up": mono_up,
			"max_monotonic_down": mono_down, "solve_up": mono_up, "solve_down": mono_down, "elev_at_solve_up": elev[i_up],
			"elev_at_solve_down": elev[i_dn], "solve_lateral_drift_deg": drift, "data_limits": limits,
			"yaw_drift_limit_deg": PITCH_YAW_DRIFT_DEG, "barrel_bone": barrel, "barrel_axis": "+Z",
			"base": t.base, "up": t.up, "down": t.down, "grip": grip if grip != "" else null,
			"grip_filter": "bone_sets.hands"}


## The aim-tree composition the runtime uses (plan 6.1 A__<w>__<s> + H), as a scratch AnimationTree
## under inst (callback MANUAL, deterministic). Nodes: base, up, down, add_up, add_dn, grip, H.
## Also used by tests/anim/test_metrics.gd.
static func pitch_tree(inst: Node, ap: AnimationPlayer, base: String, up: String, down: String, grip: String,
		hands: PackedStringArray) -> AnimationTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("base", _anim_node(base))
	bt.add_node("up", _anim_node(up))
	bt.add_node("down", _anim_node(down))
	bt.add_node("add_up", AnimationNodeAdd2.new())
	bt.add_node("add_dn", AnimationNodeAdd2.new())
	bt.connect_node("add_up", 0, "base")
	bt.connect_node("add_up", 1, "up")
	bt.connect_node("add_dn", 0, "add_up")
	bt.connect_node("add_dn", 1, "down")
	var out := "add_dn"
	if grip != "":
		bt.add_node("grip", _anim_node(grip))
		var h := AnimationNodeBlend2.new()
		h.filter_enabled = true
		for b in hands:
			h.set_filter_path(NodePath("Skeleton3D:" + b), true)
		bt.add_node("H", h)
		bt.connect_node("H", 0, "add_dn")
		bt.connect_node("H", 1, "grip")
		out = "H"
	bt.connect_node("output", 0, out)
	var tree := AnimationTree.new()
	tree.name = "PitchTree"
	inst.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(inst)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.deterministic = true
	tree.tree_root = bt
	tree.active = true
	if grip != "":
		tree.set("parameters/H/blend_amount", 1.0)
	tree.advance(0.0)
	tree.advance(0.0)
	return tree


## Barrel (elev_deg, yaw_deg) of pitch_tree() at aim weight w (> 0 up, < 0 down).
static func pitch_eval(tree: AnimationTree, sk: Skeleton3D, barrel_bone: int, w: float) -> Vector2:
	tree.set("parameters/add_up/add_amount", maxf(w, 0.0))
	tree.set("parameters/add_dn/add_amount", maxf(-w, 0.0))
	tree.advance(0.0)
	var d := (sk.get_bone_global_pose(barrel_bone).basis.orthonormalized() * Vector3(0, 0, 1)).normalized()
	return Vector2(rad_to_deg(asin(clampf(d.y, -1.0, 1.0))), rad_to_deg(atan2(d.x, d.z)))


static func _anim_node(clip: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = StringName(LIB + "/" + clip)
	return n


# --- ground truth ------------------------------------------------------------------------------

## {clip: {sr, frames: [[l_heel, l_ball, r_heel, r_ball] as Godot Vector3]}} from the Blender dump.
static func _load_dump(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var r: Variant = JSON.parse_string(line)
		if not (r is Dictionary) or not r.has("action"):
			continue
		var frames := []
		for fr: Dictionary in r.frames:
			var pts := []
			for p: String in POINTS:
				var v: Array = fr[p]
				pts.append(Vector3(v[0], v[2], -v[1]))
			frames.append(pts)
		out[str(r.action)] = {"sr": float(r.sr), "frames": frames}
	return out


static func _gt_check(ctx: _Rig, lib: AnimationLibrary, dump: Dictionary) -> Dictionary:
	if dump.is_empty():
		return {"clips": 0, "samples": 0, "median_mm": null, "p95_mm": null, "p99_mm": null, "max_mm": null,
				"worst": [], "missing": [], "skipped": "no Blender dump"}
	var errs := PackedFloat64Array()
	var per_clip := []
	var missing := PackedStringArray()
	var per_max := {}
	var per_t := {}
	var names := dump.keys()
	names.sort()
	var n_clips := 0
	for name: String in names:
		if not lib.has_animation(name):
			missing.append(name)
			continue
		n_clips += 1
		var a := lib.get_animation(name)
		var ev := ctx.eval(a)
		var d: Dictionary = dump[name]
		var worst := 0.0
		var worst_t := 0.0
		for k in d.frames.size():
			var t := minf(k / float(d.sr), a.length)
			var got := _points(ctx, ev, t)
			for p in POINTS.size():
				var e := (got[p] as Vector3).distance_to(d.frames[k][p]) * 1000.0
				errs.append(e)
				if e > worst:
					worst = e
					worst_t = t
		per_clip.append([worst, name])
		per_max[name] = worst
		per_t[name] = worst_t
	errs.sort()
	per_clip.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	var worst_list := []
	for i in mini(10, per_clip.size()):
		worst_list.append([per_clip[i][1], per_clip[i][0]])
	return {"clips": n_clips, "samples": errs.size(), "median_mm": _pct(errs, 0.5), "p95_mm": _pct(errs, 0.95),
			"p99_mm": _pct(errs, 0.99), "max_mm": errs[-1] if not errs.is_empty() else null, "worst": worst_list,
			"missing": missing, "per_clip_max_mm": per_max, "per_clip_max_t": per_t}


static func _pct(sorted: PackedFloat64Array, q: float) -> float:
	if sorted.is_empty():
		return NAN
	var x := q * (sorted.size() - 1)
	var i := floori(x)
	var j := mini(i + 1, sorted.size() - 1)
	return lerpf(sorted[i], sorted[j], x - i)


# --- helpers -----------------------------------------------------------------------------------

## Numerically stable rotation angle between two unit quaternions (rad).
static func _qangle(a: Quaternion, b: Quaternion) -> float:
	var s := 1.0 if a.dot(b) >= 0.0 else -1.0
	var d := Vector4(a.x - s * b.x, a.y - s * b.y, a.z - s * b.z, a.w - s * b.w).length()
	var e := Vector4(a.x + s * b.x, a.y + s * b.y, a.z + s * b.z, a.w + s * b.w).length()
	return 4.0 * atan2(d, e)


static func _rel(path: String) -> String:
	return path.trim_prefix("res://")


## Deterministic JSON: sorted keys, one-space indent, floats with at most 6 decimals, arrays of
## scalars on one line. NaN / INF are written as null.
static func to_json(v: Variant, indent := "") -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return _num(v)
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return JSON.stringify(str(v))
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.is_empty():
				return "{}"
			var keys := d.keys().map(func(k): return str(k))
			keys.sort()
			var inner := indent + " "
			var parts := PackedStringArray()
			for k: String in keys:
				parts.append(inner + JSON.stringify(k) + ": " + to_json(d[k] if d.has(k) else d[StringName(k)], inner))
			return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
	if v is Array or (typeof(v) >= TYPE_PACKED_BYTE_ARRAY and typeof(v) <= TYPE_PACKED_VECTOR4_ARRAY):
		if v.is_empty():
			return "[]"
		var scalar := true
		for x in v:
			if typeof(x) in [TYPE_DICTIONARY, TYPE_ARRAY] or (typeof(x) >= TYPE_PACKED_BYTE_ARRAY and typeof(x) <= TYPE_PACKED_VECTOR4_ARRAY):
				scalar = false
				break
		var parts := PackedStringArray()
		if scalar:
			for x in v:
				parts.append(to_json(x, indent))
			return "[" + ", ".join(parts) + "]"
		var inner := indent + " "
		for x in v:
			parts.append(inner + to_json(x, inner))
		return "[\n" + ",\n".join(parts) + "\n" + indent + "]"
	return JSON.stringify(str(v))


static func _num(x: float) -> String:
	if is_nan(x) or is_inf(x):
		return "null"
	var s := "%.6f" % x
	if "." in s:
		s = s.rstrip("0").rstrip(".")
	if s == "-0":
		s = "0"
	return s


# =============================================================================================
# Rig evaluation: skeleton-space bone poses straight from the clip's tracks (rest where a channel
# is not keyed), the same values Godot's AnimationMixer produces for one clip at weight 1 with
# deterministic blending. Nothing is written to the Skeleton3D.
# =============================================================================================

class _Rig:
	var sk: Skeleton3D
	var names := PackedStringArray()
	var parents := PackedInt32Array()
	var rest: Array[Transform3D] = []
	var depth := PackedInt32Array()
	var _index := {}
	## Bones on the root chains of POINTS / CORE_ENDS, parents first.
	var feet_closure := PackedInt32Array()
	var core := PackedInt32Array()

	func _init(p_sk: Skeleton3D) -> void:
		sk = p_sk
		for b in sk.get_bone_count():
			names.append(sk.get_bone_name(b))
			parents.append(sk.get_bone_parent(b))
			rest.append(sk.get_bone_rest(b))
			_index[sk.get_bone_name(b)] = b
		for b in sk.get_bone_count():
			var d := 0
			var p := parents[b]
			while p >= 0:
				d += 1
				p = parents[p]
			depth.append(d)
		var feet := PackedInt32Array()
		for n in ["l_heel", "l_ball", "r_heel", "r_ball"]:
			if bone(n) >= 0:
				feet.append(bone(n))
		feet_closure = closure(feet)
		var ends := PackedInt32Array()
		for n in ["l_ball", "r_ball", "heada", "l_wrist", "r_wrist"]:
			if bone(n) >= 0:
				ends.append(bone(n))
		core = closure(ends)

	func bone(n: String) -> int:
		return _index.get(n, -1)

	func is_under(b: int, ancestor: int) -> bool:
		var p := b
		while p >= 0:
			if p == ancestor:
				return true
			p = parents[p]
		return false

	## The bones and all their ancestors, parents before children.
	func closure(bones: PackedInt32Array) -> PackedInt32Array:
		var seen := {}
		for b in bones:
			var p := b
			while p >= 0 and not seen.has(p):
				seen[p] = true
				p = parents[p]
		var arr := seen.keys()
		arr.sort_custom(func(x, y): return depth[x] < depth[y] or (depth[x] == depth[y] and x < y))
		return PackedInt32Array(arr)

	func eval(a: Animation) -> _Eval:
		return _Eval.new(self, a)


class _Eval:
	var rig: _Rig
	var a: Animation
	## bone -> PackedInt32Array [position track, rotation track, scale track] (-1 = not keyed)
	var keyed := {}

	func _init(p_rig: _Rig, p_a: Animation) -> void:
		rig = p_rig
		a = p_a
		for t in a.get_track_count():
			var ty := a.track_get_type(t)
			var slot := -1
			match ty:
				Animation.TYPE_POSITION_3D:
					slot = 0
				Animation.TYPE_ROTATION_3D:
					slot = 1
				Animation.TYPE_SCALE_3D:
					slot = 2
			if slot < 0:
				continue
			var b := rig.bone(str(a.track_get_path(t).get_concatenated_subnames()))
			if b < 0:
				continue
			if not keyed.has(b):
				keyed[b] = PackedInt32Array([-1, -1, -1])
			var m: PackedInt32Array = keyed[b]
			m[slot] = t
			keyed[b] = m

	func local(b: int, t: float) -> Transform3D:
		var r: Transform3D = rig.rest[b]
		if not keyed.has(b):
			return r
		var m: PackedInt32Array = keyed[b]
		var pos := a.position_track_interpolate(m[0], t) if m[0] >= 0 else r.origin
		var rot := a.rotation_track_interpolate(m[1], t).normalized() if m[1] >= 0 else r.basis.get_rotation_quaternion()
		var scl := a.scale_track_interpolate(m[2], t) if m[2] >= 0 else r.basis.get_scale()
		return Transform3D(Basis(rot) * Basis.from_scale(scl), pos)

	## Skeleton-space transforms of an ancestor-closed, parents-first bone list.
	func globals(bones: PackedInt32Array, t: float) -> Dictionary:
		var g := {}
		for b in bones:
			var p := rig.parents[b]
			g[b] = (g[p] as Transform3D) * local(b, t) if p >= 0 else local(b, t)
		return g

	func global_of(b: int, t: float) -> Transform3D:
		return globals(rig.closure(PackedInt32Array([b])), t)[b]
