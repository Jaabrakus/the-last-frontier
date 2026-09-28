extends SceneTree
## Traversal clip survey (Godot, on the real Actor_B rig): measures every clip listed in
## data/traversal/traversal_catalog.json and writes data/traversal/clip_geometry.json.
##
##   Godot --headless --path . -s tools/traversal/measure_traversal_clips.gd -- [options]
##
## Options (after --):
##   catalog=<path>  clip catalogue (default res://data/traversal/traversal_catalog.json, made by
##                   tools/traversal/build_traversal_catalog.py)
##   out=<path>      output (default res://data/traversal/clip_geometry.json)
##   only=<a,b,..>   measure only these clips (debugging; implies no write unless out= is given)
##   check           measure, compare with the existing output, exit 1 if it differs (writes nothing)
## Exit code 0 on success ("TRAVERSAL CLIPS OK"), 1 on failure ("TRAVERSAL CLIPS FAILED").
##
## Why contact odometry: the clips carry no root motion. The skeleton's `root` bone is the hips
## (it sits at pelvis height and only sways), and the game's align / trajectory channel was not
## exported ("gameplay trajectory channels ... are not baked", Player_Animation_Project/README.md).
## Every clip is therefore in place relative to an unknown moving align. Contacts are static in the
## world, so while a heel, ball, palm or knee is planted its skeleton-space velocity is minus the align
## velocity. measure() rebuilds the align path from the contacts (see _odometry) and reports
## everything in a world frame = the align frame at the clip's first sample: +Z forward, +X left,
## +Y up, metres and seconds. Nothing is written to the rig or to any Animation; BindRest.ensure()
## runs first so bones a clip does not key sit at the null-add bind pose.
##
## Provenance: native_asset_id and the original names are copied from the library metadata unchanged.

const RIG := "res://characters/Actor_B.tscn"
const LIB := "actor_b"
const LIBRARY_RES := "res://animations/Actor_B.res"
const DEFAULT_CATALOG := "res://data/traversal/traversal_catalog.json"
const DEFAULT_OUT := "res://data/traversal/clip_geometry.json"
const GENERATOR := "tools/traversal/measure_traversal_clips.gd"
const SCHEMA := 1
const AUTHORIZATION := "owner-stated; see Player_Animation_Project/ASSET_AUTHORIZATION.md; granting party and terms not on file"

## Tracked points (skeleton-space positions per sample). Heels, balls, palms and knees feed the
## odometry anchors (a foot is one rolling-sole anchor made of its heel and ball).
const PTS := ["l_heel", "l_ball", "r_heel", "r_ball", "l_palm", "r_palm", "l_knee", "r_knee",
		"pelvis", "root", "heada", "headb", "spined", "l_upper_leg", "r_upper_leg",
		"l_wrist", "r_wrist", "l_middle_metacarpal", "r_middle_metacarpal", "l_middlea", "r_middlea",
		"l_middlec", "r_middlec", "l_hand_prop_attachment", "r_hand_prop_attachment", "l_elbow", "r_elbow"]
const ANCHORS := 6
const A_LABEL := ["l_foot", "r_foot", "l_hand", "r_hand", "l_knee", "r_knee"]
const A_KIND := ["foot", "foot", "hand", "hand", "knee", "knee"]
## Anchor -> tracked point(s): feet use [heel, ball], hands the palm, knees the knee joint.
const A_PTS := [[0, 1], [2, 3], [4], [5], [6], [7]]
## The ball bone origin sits this far above the sole (rest pose: heel 0.000, ball 0.018).
const BALL_SOLE := 0.018
enum {I_LH, I_LB, I_RH, I_RB, I_LP, I_RP, I_LK, I_RK, I_PELVIS, I_ROOT, I_HEADA, I_HEADB, I_SPINED,
		I_LUL, I_RUL, I_LW, I_RW, I_LMM, I_RMM, I_LMA, I_RMA, I_LMC, I_RMC, I_LPROP, I_RPROP, I_LE, I_RE}
## Bones whose local rotations define a pose (entry / exit pose matching); root is compared by
## tilt (yaw removed) and height.
const POSE_BONES := ["pelvis", "spinea", "spineb", "spinec", "spined", "neck", "heada",
		"l_clavicle", "r_clavicle", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist",
		"l_upper_leg", "r_upper_leg", "l_knee", "r_knee", "l_ankle", "r_ankle"]
## Keyed-bone groups for the variant report.
const GROUP_RX := {
	"legs": "^(lower_base|pelvis|[lr]_(upper_leg|knee|ankle|heel|ball))$",
	"spine": "^(upper_base|spine[a-d])$",
	"head": "^(neck|heada|headb|throat)$",
	"l_arm": "^l_(clavicle|scapula|shoulder|deltoid|elbow|wrist|trap)$",
	"r_arm": "^r_(clavicle|scapula|shoulder|deltoid|elbow|wrist|trap)$",
	"l_hand": "^l_(palm|thumb|index|middle|ring|pinky)",
	"r_hand": "^r_(palm|thumb|index|middle|ring|pinky)",
	"props": "(prop_attachment|^holster_)",
	"root": "^root$",
}

## Pose references (Godot clip names) for entry / exit matching. "frames": all = every key (cyclic),
## a number = that sample only; step = sample spacing for long idles.
const POSE_REFS := {
	"idle": {"clip": "actor_b-p-relax-idle", "every_s": 0.5},
	"idle_stealth": {"clip": "actor_b-p-stealth-idle", "every_s": 0.5},
	"idle_combat": {"clip": "actor_b-p-combat-idle", "every_s": 0.5},
	"crouch_idle": {"clip": "actor_b-p-crouch-idle", "every_s": 0.5},
	"walk": {"clip": "actor_b-p-walk-fw", "every_s": 0.0},
	"run": {"clip": "actor_b-p-run-fw", "every_s": 0.0},
	"sprint": {"clip": "actor_b-p-sprint-fw", "every_s": 0.0},
	"crouch_walk": {"clip": "actor_b-p-crouch-walk-fw", "every_s": 0.0},
	"fall": {"clip": "actor_b-p-fall", "every_s": 0.0},
	"ladder": {"clip": "actor_b-p-ladder-idle", "every_s": 0.5},
	"wall_shimmy": {"clip": "actor_b-p-ledge-idle", "every_s": 0.5},
	"beam": {"clip": "actor_b-balance-beam-loop", "every_s": 0.0},
	"crouch_under": {"clip": "actor_b-crouch-under-loop", "every_s": 0.0},
	"hang": {"clip": "actor_b-p-ledge-hang-climb-up^ledge-knee", "first": true},
	"knee_on_ledge": {"clip": "actor_b-p-ledge-knee-climb-up^idle", "first": true},
	"chest_on_ledge": {"clip": "actor_b-p-ledge-grab-chest^ledge-grab-knee", "first": true},
}
## Gait by horizontal speed (m/s): the bank speeds in animations/actor_b_clip_metrics.json are
## walk-fw 1.263, run-fw 3.343, sprint-fw 4.244; thresholds are the midpoints.
const GAIT := [[0.35, "idle"], [2.3, "walk"], [3.8, "run"], [1e9, "sprint"]]

# --- odometry (see _odometry) -------------------------------------------------------------------
const G := Vector3(0.0, -9.81, 0.0)
## Pelvis world acceleration scale while supported (m/s^2); per-step costs are (a / SIG_A)^2 * dt / 0.1.
const SIG_A := 15.0
## Residual acceleration scale over a flight gap (m/s^2), against gravity.
const SIG_F := 6.0
## Cost per 0.1 s of flight (no anchor) between anchors / at the ends of the sequence.
const GAP_PEN := 3.0
const END_PEN := 8.0
## Longest flight bridged between two anchors, and longest unanchored run at either end (s).
const GAP_MAX_S := 1.2
const END_MAX_S := 1.5
## Emission: hands / knees cost this much per 0.1 s as anchors (feet are preferred when equivalent);
## feet pay for being far from the align height: ((|y| - FOOT_Y_FREE) / FOOT_Y_SCALE)^2 per 0.1 s.
const HAND_COST := 1.0
const KNEE_COST := 1.2
const FOOT_Y_FREE := 0.1
const FOOT_Y_SCALE := 0.2
## Contact gates (see _contact_gates) and the emission cost of a gated-out anchor.
const GATE_WIN_S := 0.3
const GATE_TOL := 0.2
const KNEE_MAX_Y := 0.25
const GATED := 1e9
## Contact physics while supported: contacts push (or hang) upwards, so the centre of mass cannot
## fall faster than gravity (a_y >= -g - PHYS_TOL), and a foot / knee obeys friction
## (|a_horizontal| <= MU * (a_y + g) + PHYS_TOL); violations cost ((excess) / PHYS_SIG)^2.
const PHYS_TOL := 3.0
## Entry prior (clips without preceding context): the first anchored centre-of-mass horizontal velocity
## costs (|v - v_gait| / ENTRY_SIG)^2, v_gait = forward at the name's entry gait speed (_entry_gait_speed).
const ENTRY_SIG := 1.5
const PHYS_SIG := 2.0
const MU := 1.2
## Anchor switch cost.
const SWITCH_OTHER := 1.0
## Co-stationary limbs (see _co_stationary_bonus).
const CO_V := 0.15
const CO_MIN_S := 0.4
const CO_BONUS := 1.5
## Context padding from neighbour clips / locomotion loops (s), and the cross-fade used to join a
## neighbour whose boundary pose differs (s).
const PAD_S := 1.0
const BLEND_S := 0.2
## Neighbour acceptance (max point distance at the boundary after a rigid yaw + translation alignment
## of the neighbour onto the clip, m): graph successions (the graph fades between them) and
## locomotion-loop phase matches (legs, pelvis and head only).
const GRAPH_GAP_M := 0.15
const LOOP_GAP_M := 0.10
const LOOP_FULL_GAP_M := 0.25
## Locomotion loops used as context for clips entered from / leaving into locomotion (sampled at 30 Hz).
const LOOPS := {"run": "actor_b-p-run-fw", "sprint": "actor_b-p-sprint-fw", "walk": "actor_b-p-walk-fw",
		"crouch_walk": "actor_b-p-crouch-walk-fw", "idle": "actor_b-p-relax-idle",
		"crouch_idle": "actor_b-p-crouch-idle", "fall": "actor_b-p-fall"}
const LOOP_MATCH_PTS := [0, 1, 2, 3, 6, 7, 8, 10, 13, 14]
## Approximate centre of mass: weights over PTS indices (segment-mass shares, sum 1). The path's
## smoothness and ballistic checks use it; the pelvis is reported.
const COM_W := {8: 0.30, 12: 0.22, 11: 0.08, 13: 0.06, 14: 0.06, 6: 0.05, 7: 0.05, 0: 0.025, 2: 0.025,
		1: 0.015, 3: 0.015, 25: 0.025, 26: 0.025, 15: 0.015, 16: 0.015, 4: 0.01, 5: 0.01}
## Pose continuity: max point distance (m) for an authored chain (identical keys) / a compatible pose.
const CHAIN_EXACT_M := 0.003
const CHAIN_NEAR_M := 0.035

# --- contacts ------------------------------------------------------------------------------------
## A point is in contact while its world speed stays under CONTACT_V (m/s) for at least one step.
const CONTACT_V := 0.4
## Hand surface estimate: lowest of palm / middle metacarpal / middle knuckle origins minus this (m).
const HAND_SKIN := 0.02
## Head top above the headb bone origin (m), from the rest pose (brow_mid 1.489, headb 1.432).
const HEAD_TOP := 0.13
## Series output rate cap (Hz): long cinematic clips are written at this rate.
const SERIES_MAX_HZ := 15.0

var _args := {}
static var _group_rx := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if "=" in s:
			_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
		else:
			_args[s] = true
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	var res := measure(root, _args)
	for w in res.warnings:
		print("  warn " + w)
	if not res.errors.is_empty():
		for e in res.errors:
			printerr("measure_traversal_clips: " + e)
		print("TRAVERSAL CLIPS FAILED (%d error(s))" % res.errors.size())
		quit(1)
		return
	var text := to_json(res.data) + "\n"
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var out: String = _args.get("out", DEFAULT_OUT)
	if _args.has("check"):
		var old := FileAccess.get_file_as_string(out) if FileAccess.file_exists(out) else ""
		var same := _strip_stamp(text) == _strip_stamp(old)
		if not same:
			print("measure_traversal_clips: %s is %s (rerun without `check`)" % [out, "missing" if old == "" else "stale"])
			print("TRAVERSAL CLIPS FAILED (stale)")
			quit(1)
			return
		print("measure_traversal_clips: %s is current; %d clips, %.1f s" % [out, res.data.clips.size(), secs])
		print("TRAVERSAL CLIPS OK")
		quit(0)
		return
	if _args.has("only") and not _args.has("out"):
		print(text.substr(0, 200000))
		print("TRAVERSAL CLIPS OK (only=, not written)")
		quit(0)
		return
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		printerr("measure_traversal_clips: cannot write %s" % out)
		print("TRAVERSAL CLIPS FAILED")
		quit(1)
		return
	f.store_string(text)
	f.close()
	print("measure_traversal_clips: wrote %s (%d clips, %d bytes); %.1f s" % [out, res.data.clips.size(),
			text.to_utf8_buffer().size(), secs])
	print("TRAVERSAL CLIPS OK")
	quit(0)


## The stamp line (godot_version) is ignored by `check`.
static func _strip_stamp(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		if line.strip_edges().begins_with("\"godot_version\""):
			continue
		out.append(line)
	return "\n".join(out)


# =================================================================================================
# measure()
# =================================================================================================

static func measure(parent: Node, opts := {}) -> Dictionary:
	var out := {"data": {}, "errors": [], "warnings": []}
	var scene := load(RIG) as PackedScene
	if scene == null:
		out.errors.append("cannot load " + RIG)
		return out
	var inst := scene.instantiate() as Node3D
	inst.name = "TraversalSurveyRig"
	parent.add_child(inst)
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		out.errors.append("%s has no Skeleton3D / AnimationPlayer" % RIG)
		inst.free()
		return out
	var sk: Skeleton3D = sks[0]
	var ap: AnimationPlayer = aps[0]
	ap.stop()
	if not ap.has_animation_library(LIB):
		out.errors.append("rig has no animation library '%s'" % LIB)
		inst.free()
		return out
	var rest := _ensure_rest(sk, ap)
	if not bool(rest.get("ok", false)):
		out.errors.append("rest is not the null-add bind pose: %s" % rest.get("reason", "?"))
		inst.free()
		return out
	var lib := ap.get_animation_library(LIB)
	var cat_path: String = str(opts.get("catalog", DEFAULT_CATALOG))
	var cat: Variant = JSON.parse_string(FileAccess.get_file_as_string(cat_path)) if FileAccess.file_exists(cat_path) else null
	if not (cat is Dictionary) or not (cat.get("clips") is Dictionary):
		out.errors.append("cannot read the clip catalogue %s (run tools/traversal/build_traversal_catalog.py)" % cat_path)
		inst.free()
		return out
	var rig := _Rig.new(sk)
	for n in PTS:
		if rig.bone(n) < 0:
			out.errors.append("rig has no bone " + n)
	if not out.errors.is_empty():
		inst.free()
		return out

	var names: Array = cat.clips.keys()
	names.sort()
	if opts.has("only"):
		var keep: PackedStringArray = str(opts.only).split(",")
		names = names.filter(func(n): return n in keep)
	# Library clips the catalogue does not list but whose names look like traversal (catalogue stale?).
	var cat_keys: Dictionary = cat.clips
	var rx := RegEx.create_from_string("vault|ledge|ladder|climb-on|jump-up|balance-beam|crouch-under|drop-down")
	for n in lib.get_animation_list():
		if rx.search(str(n)) and not cat_keys.has(str(n)) and not str(n).contains("horse") and not str(n).contains("pickup-shimmy"):
			out.warnings.append("library clip %s looks like traversal but is not in the catalogue" % n)

	# --- sample every clip ------------------------------------------------------------------
	var samples := {}   # name -> _Samples
	for n: String in cat.clips:
		if not lib.has_animation(n):
			out.errors.append("catalogue clip missing from the library: " + n)
			continue
		samples[n] = _sample(rig, lib.get_animation(n))
	if not out.errors.is_empty():
		inst.free()
		return out
	var refs := _pose_refs(rig, lib, out.warnings)
	var loops := {}
	for lname: String in LOOPS:
		if lib.has_animation(LOOPS[lname]):
			loops[lname] = _sample(rig, lib.get_animation(LOOPS[lname]), 30.0)
		else:
			out.warnings.append("context loop %s (%s) missing from the library" % [lname, LOOPS[lname]])

	# --- pose continuity between clips (authored chains) -------------------------------------
	var full := []
	for n: String in samples:
		if (samples[n] as _Samples).full_body:
			full.append(n)
	full.sort()
	var cont := _continuity(samples, full)

	# --- odometry: authored chains (exact pose links) as one sequence, other clips alone ----------
	var chains := _chains(cont, full)
	var odo_cache := {}
	var chain_info := []
	for ch: Array in chains:
		var res := _chain_odometry(ch, samples, cont, cat.clips, loops)
		for n: String in ch:
			odo_cache[n] = res[n]
		chain_info.append(_chain_summary(ch, res, samples))

	# --- per-clip measurement ------------------------------------------------------------------
	var clips := {}
	for n: String in names:
		var c: Dictionary = (cat.clips[n] as Dictionary).duplicate(true)
		var s: _Samples = samples[n]
		var a := lib.get_animation(n)
		c.merge(_basics(rig, a, s), true)
		c["chain"] = cont.get(n, {"prev_exact": [], "next_exact": [], "prev_near": [], "next_near": []})
		if s.full_body and s.n >= 2:
			if not odo_cache.has(n):
				odo_cache[n] = _chain_odometry([n], samples, cont, cat.clips, loops)[n]
			var od: Dictionary = odo_cache[n]
			c.merge(_geometry(rig, n, s, od, refs, c), true)
			if od.has("chain"):
				c.chain["authored"] = od.chain
		clips[n] = c
	# Variants (weapon parts, --hands, --add): composite over the base clip with the base's align.
	for n: String in names:
		var c: Dictionary = clips[n]
		var base: Variant = c.variant.get("base_clip")
		if c.variant.kind in ["part", "hands", "add"] and base is String and samples.has(base):
			if not odo_cache.has(base):
				odo_cache[base] = _chain_odometry([base], samples, cont, cat.clips, loops)[base]
			c["part"] = _part_report(rig, lib, n, base, samples, odo_cache[base], clips.get(base, {}))
		elif c.variant.kind in ["part", "hands", "add"]:
			c["part"] = {"base_clip": null, "base_missing": c.variant.get("base_missing"),
					"note": "no base clip of that name in the library; keyed bones only"}
	var fam := {}
	for n: String in clips:
		var f: String = clips[n].family
		if not fam.has(f):
			fam[f] = []
		fam[f].append(n)
	for f in fam:
		fam[f].sort()
	out.data = {
		"meta": {
			"schema": SCHEMA,
			"generator": GENERATOR,
			"godot_version": Engine.get_version_info().string,
			"library_sha256": FileAccess.get_sha256(LIBRARY_RES),
			"catalog": {"path": _rel(cat_path), "sha256": FileAccess.get_sha256(cat_path)},
			"rest": rest,
			"authorization": AUTHORIZATION,
			"units": {"length": "m", "time": "s", "speed": "m/s", "angle": "deg",
					"frame": "world = the clip's align frame at its first sample (the character's start position): fwd = +Z, side = +X (left), up = +Y; skel = skeleton space (the moving, unexported align)"},
			"method": _method_notes(),
		},
		"families": fam,
		"chains": chain_info,
		"pose_refs": _ref_summary(refs),
		"clips": clips,
	}
	parent.remove_child(inst)
	inst.free()
	return out


static func _method_notes() -> Dictionary:
	return {
		"root_motion": "The rig has no ground-level root bone (ground_root_bone false): its `root` bone is the hips (pelvis height), and the game's align / trajectory channel was not exported. root_motion.root_* = that bone's horizontal travel in skeleton space (start -> end, and the largest excursion); in_skeleton = the hips themselves travel >= 0.5 m and at least half the contact-derived world travel (the clip carries its travel in the skeleton instead of the align). World travel always comes from the contacts (odometry), which covers both cases",
		"odometry": "contact path: per step k -> k+1 at the clip's key times, each anchor a (foot = rolling sole of heel + ball: vertical from the lowest sole height, horizontal from the lower of the two; palm; knee) implies align velocity -u_a (u_a its skeleton-space velocity) and pelvis world velocity w_a = u_pelvis - u_a. A Viterbi path picks one anchor or none per step minimising sum (|w_a(k) - w_b(k-1)| / dt / %.0f m/s^2)^2 * dt/0.1 while supported, (|dw - g T_air| / T / %.0f)^2 * T/0.1 + %.1f per 0.1 s over a flight gap (<= %.1f s), %.1f per 0.1 s unanchored at either end (<= %.1f s), anchor costs (hand %.1f, knee %.1f per 0.1 s; foot ((|y| - %.2f) / %.2f)^2 per 0.1 s; a foot or knee may anchor only while its sole / joint height is within %.2f m of its lowest height over +-%.1f s, knees only below %.2f m: swinging or tucked limbs cannot anchor), a co-stationarity bonus (-%.1f per 0.1 s for an anchor whose skeleton velocity matches another limb's within %.2f m/s for >= %.1f s: both planted), a switch cost of %.1f and contact physics (supported: centre-of-mass a_y >= -g - %.1f, feet / knees |a_h| <= %.1f (a_y + g) + %.1f; excess costs (excess / %.1f)^2); smoothness and ballistic checks use an approximate centre of mass (COM_W). Flight gaps cost only the part of the landing velocity change that no upward, friction-bounded impact impulse explains, and fly ballistically from the takeoff step; an unanchored start holds the first anchored velocity, an unanchored end extrapolates ballistically. The sequence is padded with up to %.1f s of context on each side (odometry.context): the clip itself when it loops, an exact pose chain, an ambient enter / loop / exit name set (boundary poses within %.2f m after a yaw + translation alignment), a graph succession (end-of-clip transition records, boundary poses within %.2f m), a near pose chain, or a locomotion loop (LOOPS) at the phase whose legs / pelvis / head are within %.2f m; neighbours are joined with a %.1f s cross-fade of the boundary offset. A clip without preceding context gets a soft entry prior: its first anchored centre-of-mass horizontal velocity costs (|v - v_gait| / %.1f m/s)^2 with v_gait forward at the entry gait's bank speed implied by the name (odometry.context.entry_prior_speed; sprint 4.24, run 3.34, walk 1.26, idle / ladder / ledge / hang 0). The world origin is still the clip's own first sample. No align rotation is modelled: travel.yaw_change_deg is the skeleton-space facing change and odometry.planted_yaw_drift_deg flags planted feet that rotate (an align turn)" % [SIG_A, SIG_F, GAP_PEN, GAP_MAX_S, END_PEN, END_MAX_S, HAND_COST, KNEE_COST, FOOT_Y_FREE, FOOT_Y_SCALE, GATE_TOL, GATE_WIN_S, KNEE_MAX_Y, CO_BONUS, CO_V, CO_MIN_S, SWITCH_OTHER, PHYS_TOL, MU, PHYS_TOL, PHYS_SIG, PAD_S, GRAPH_GAP_M, GRAPH_GAP_M, LOOP_GAP_M, BLEND_S, ENTRY_SIG],
		"contacts": "a heel / ball (foot), palm (hand) or knee is in contact while its world speed stays below %.2f m/s (step velocities at the key rate); runs of the same limb merge; t0/t1 and f0/f1 = first/last sample of the run. Positions are world fwd/side/up at the run's first sample. hands[].surface_up = lowest of palm, middle metacarpal, middle knuckle origins - %.2f m (bone origins sit inside the hand); supporting = the hand was the path's anchor in the run or the pelvis moved > 5 cm in the world during it" % [CONTACT_V, HAND_SKIN],
		"entry_exit": "speed / vel = mean pelvis world velocity over the first / last 0.2 s; gait by horizontal speed (idle < 0.35, walk < 2.3, run < 3.8, else sprint; bank speeds walk 1.26, run 3.34, sprint 4.24); pose = nearest reference pose (pose_refs) by mean local rotation difference of POSE_BONES + root tilt (yaw removed) + 100 x |root height difference| (1 cm = 1 deg); anchors = the path's anchor on the first / last step",
		"implied": "family-specific geometry the clip was authored for, from the contacts: obstacle / ledge top = supporting hand surface heights (and feet / knees landing above 0.3 m), relative to the start support (feet at t = 0); depth = fwd spread of the top contacts (lower bound); landing = end support height; ladder rung pitch = median vertical step between successive same-hand grips; gap = landing contact fwd - takeoff contact fwd around the longest flight. Values are estimates from the contact path, not authored metadata",
		"chains": "pose continuity: last sample of A vs first sample of B, max distance over the tracked points in skeleton space; exact <= %.3f m (identical keys: authored chain parts), near <= %.3f m (pose-compatible)" % [CHAIN_EXACT_M, CHAIN_NEAR_M],
		"part": "variant clips (weapon parts, --hands, --add): keyed bones, length vs base, and the hand contacts of the composite pose (base with the part's keyed bones replaced; additive clips are not composed) using the base clip's align path",
		"head_top": "head_top = headb + %.2f m (rest pose: headb 1.432, brow_mid 1.489)" % HEAD_TOP,
		"confidence": "odometry.confidence: high = coverage >= 0.8, accel_rms < 15 m/s^2, not starting airborne, and context or a grounded start; low = coverage < 0.5 (mostly flight or motion carried by the unexported align that no contact reveals); medium otherwise. Heights and travel of low-confidence clips are not authored values",
		"limits": "The align (trajectory) channel was not exported, so travel is reconstructed. It is unobservable while no limb touches anything (flights: ballistic assumption) and where the align itself carries the motion with the body posed in place (e.g. a fall loop: a static foot then reads as standing). The contact estimates are sampled at the clip's key rate (10 Hz for most traversal clips), so contact times are +-1 key and heights within ~0.1-0.2 m",
	}


static func _ensure_rest(sk: Skeleton3D, ap: AnimationPlayer) -> Dictionary:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == &"BindRest":
			var s: Script = load(c["path"])
			if s:
				var d: Dictionary = s.call("ensure", sk, ap, StringName(LIB))
				var r := {}
				for k in ["ok", "max_rot", "max_pos", "channels", "stamped", "changed", "reason"]:
					if d.has(k):
						r[k] = d[k]
				return r
	return {"ok": false, "reason": "BindRest (scripts/player/anim/bind_rest.gd) not found; run Godot --import"}


# =================================================================================================
# Sampling
# =================================================================================================

class _Samples:
	var name := ""
	var n := 0
	var sr := 10.0
	var times := PackedFloat64Array()
	var pts: Array = []        ## per sample PackedVector3Array (PTS order)
	var rots: Array = []       ## per sample Array[Quaternion] (POSE_BONES local)
	var root_q: Array = []     ## per sample root global rotation
	var full_body := false
	var keyed := PackedInt32Array()
	var additive := false


static func _sample(rig: _Rig, a: Animation, rate := 0.0) -> _Samples:
	var s := _Samples.new()
	var ev := rig.eval(a)
	s.sr = float(a.get_meta("sample_rate", 30.0)) if a.has_meta("sample_rate") else 30.0
	var n := int(a.get_meta("sample_count", 0)) if a.has_meta("sample_count") else 0
	if n <= 0:
		n = maxi(1, roundi(a.length * s.sr) + 1)
	if rate > 0.0:
		s.sr = rate
		n = maxi(1, roundi(a.length * rate) + 1)
	s.n = n
	s.additive = bool(a.get_meta("additive_source", false)) if a.has_meta("additive_source") else false
	for b: int in ev.keyed:
		s.keyed.append(b)
	var legs := 0
	for nm in ["l_upper_leg", "l_knee", "l_ankle", "r_upper_leg", "r_knee", "r_ankle", "pelvis"]:
		if ev.keyed.has(rig.bone(nm)):
			legs += 1
	s.full_body = legs >= 5 and not s.additive
	var need := PackedInt32Array()
	for p: String in PTS:
		need.append(rig.bone(p))
	var clos := rig.closure(need)
	for k in n:
		var t := minf(k / s.sr, a.length)
		s.times.append(t)
		var g := ev.globals(clos, t)
		var pv := PackedVector3Array()
		for p: String in PTS:
			pv.append((g[rig.bone(p)] as Transform3D).origin)
		s.pts.append(pv)
		var rq := []
		for bn: String in POSE_BONES:
			rq.append(ev.local(rig.bone(bn), t).basis.get_rotation_quaternion())
		s.rots.append(rq)
		s.root_q.append((g[rig.bone("root")] as Transform3D).basis.get_rotation_quaternion())
	return s


# =================================================================================================
# Pose continuity (chains)
# =================================================================================================

static func _pose_gap(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var m := 0.0
	for i in a.size():
		m = maxf(m, a[i].distance_to(b[i]))
	return m


static func _continuity(samples: Dictionary, full: Array) -> Dictionary:
	var cont := {}
	for n: String in full:
		cont[n] = {"prev_exact": [], "next_exact": [], "prev_near": [], "next_near": []}
	for a: String in full:
		var sa: _Samples = samples[a]
		var last: PackedVector3Array = sa.pts[sa.n - 1]
		for b: String in full:
			var sb: _Samples = samples[b]
			var d := _pose_gap(last, sb.pts[0])
			if d <= CHAIN_EXACT_M:
				cont[a].next_exact.append(b)
				cont[b].prev_exact.append(a)
			elif d <= CHAIN_NEAR_M:
				cont[a].next_near.append(b)
				cont[b].prev_near.append(a)
	for n in cont:
		for k in cont[n]:
			cont[n][k].sort()
	return cont


## Authored chains: maximal paths over exact continuity where each link is unique (one successor,
## one predecessor), listed from their heads.
static func _chains(cont: Dictionary, full: Array) -> Array:
	var out := []
	for n: String in full:
		var c: Dictionary = cont[n]
		var p: Array = c.prev_exact.filter(func(x): return x != n)
		if p.size() == 1 and (cont[p[0]].next_exact as Array).filter(func(x): return x != p[0]).size() == 1:
			continue   # not a head: part of a unique chain
		var path := [n]
		var cur := n
		var seen := {n: true}
		while true:
			var nx: Array = (cont[cur].next_exact as Array).filter(func(x): return x != cur)
			if nx.size() != 1 or seen.has(nx[0]):
				break
			var back: Array = (cont[nx[0]].prev_exact as Array).filter(func(x): return x != nx[0])
			if back.size() != 1:
				break
			cur = nx[0]
			seen[cur] = true
			path.append(cur)
		if path.size() > 1:
			out.append(path)
	return out


# =================================================================================================
# Odometry
# =================================================================================================

## A context segment: frames (Array of PackedVector3Array) and times (relative, from 0) of a neighbour
## clip or a locomotion-loop slice, joined to the clip at one end.
class _Seg:
	var kind := ""        ## exact | graph | near | loop | self
	var clip := ""
	var gap := 0.0        ## boundary max point distance before blending (m)
	var fade := -1.0      ## graph fade (s) when kind == graph
	var times := PackedFloat64Array()
	var pts: Array = []


## Builds the padded sequence for a chain of clips (one clip, or an authored chain of exact pose
## links) and runs the contact path once. Returns {clip: od} where od holds the clip's own window:
## anchor (per step), va (align velocity per step), w (pelvis world velocity per step), A (align
## position per sample, world origin at that clip's first sample), context, stats and, for chains,
## chain = {head, index, parts, offset (this clip's origin in the head's frame: fwd, up, side)}.
static func _chain_odometry(parts: Array, samples: Dictionary, cont: Dictionary, cat: Dictionary, loops: Dictionary) -> Dictionary:
	var head: String = parts[0]
	var tail: String = parts[parts.size() - 1]
	var before: Array = []   # nearest first
	var after: Array = []
	var in_chain := {}
	for p: String in parts:
		in_chain[p] = true
	for dir in ["prev", "next"]:
		var acc := 0.0
		var cur: String = head if dir == "prev" else tail
		var seen := in_chain.duplicate()
		while acc < PAD_S:
			var sg := _pick_neighbor(cur, dir, samples, cont, cat, loops, head if parts.size() == 1 else "")
			if sg == null or (sg.kind != "self" and sg.kind != "loop" and seen.has(sg.clip)):
				break
			seen[sg.clip] = true
			if dir == "prev":
				before.append(sg)
			else:
				after.append(sg)
			acc += sg.times[sg.times.size() - 1]
			if sg.kind == "loop" or sg.kind == "self":
				break
			cur = sg.clip
	# Assemble: previous segments are blended towards the frame that follows them, next segments
	# from the frame that precedes them (a BLEND_S cross-fade that removes the boundary offset).
	var seq_p: Array = []
	var seq_t := PackedFloat64Array()
	var hs: _Samples = samples[head]
	var head_frame: PackedVector3Array = hs.pts[0]
	var pre_blocks: Array = []
	for sg: _Seg in before:
		var fr: Array = []
		var n := sg.pts.size()
		var tend := sg.times[n - 1]
		var off := PackedVector3Array()
		for i in PTS.size():
			off.append(head_frame[i] - (sg.pts[n - 1] as PackedVector3Array)[i])
		for k in range(0, n - 1):
			var wgt := maxf(0.0, 1.0 - (tend - sg.times[k]) / BLEND_S)
			var pk: PackedVector3Array = (sg.pts[k] as PackedVector3Array).duplicate()
			for i in PTS.size():
				pk[i] += off[i] * wgt
			fr.append(pk)
		pre_blocks.append({"pts": fr, "times": sg.times.slice(0, n - 1), "dur": tend})
		head_frame = fr[0] if not fr.is_empty() else head_frame
	pre_blocks.reverse()
	var t_off := 0.0
	for b: Dictionary in pre_blocks:
		for k in (b.pts as Array).size():
			seq_p.append(b.pts[k])
			seq_t.append(t_off + float(b.times[k]))
		t_off += float(b.dur)
	var win := {}   # clip -> [start index, end index]
	for pi in parts.size():
		var ps: _Samples = samples[parts[pi]]
		var k0 := 0 if pi == 0 else 1   # exact links share their boundary sample
		var start := seq_t.size() - (0 if pi == 0 else 1)
		for k in range(k0, ps.n):
			seq_p.append(ps.pts[k])
			seq_t.append(t_off + ps.times[k])
		win[parts[pi]] = [start, seq_t.size() - 1]
		t_off += ps.times[ps.n - 1]
	var ts: _Samples = samples[tail]
	var tail_frame: PackedVector3Array = ts.pts[ts.n - 1]
	for sg: _Seg in after:
		var n2 := sg.pts.size()
		var off2 := PackedVector3Array()
		for i in PTS.size():
			off2.append(tail_frame[i] - (sg.pts[0] as PackedVector3Array)[i])
		var last: PackedVector3Array = tail_frame
		for k in range(1, n2):
			var wgt2 := maxf(0.0, 1.0 - sg.times[k] / BLEND_S)
			var pk2: PackedVector3Array = (sg.pts[k] as PackedVector3Array).duplicate()
			for i in PTS.size():
				pk2[i] += off2[i] * wgt2
			seq_p.append(pk2)
			seq_t.append(t_off + sg.times[k])
			last = pk2
		t_off += sg.times[n2 - 1]
		tail_frame = last
	var prior: Variant = null
	if before.is_empty():
		var gs := _entry_gait_speed(head)
		if gs >= 0.0:
			prior = Vector3(0.0, 0.0, gs)
	var r := _odometry(seq_t, seq_p, prior)
	var ctx := {"before": [], "after": [], "entry_prior_speed": (prior as Vector3).z if prior is Vector3 else null, "before_s": seq_t[win[head][0]],
			"after_s": seq_t[seq_t.size() - 1] - seq_t[win[tail][1]]}
	for pair in [["before", before], ["after", after]]:
		for sg: _Seg in pair[1]:
			var e := {"kind": sg.kind, "clip": sg.clip, "gap_m": sg.gap, "s": sg.times[sg.times.size() - 1]}
			if sg.fade >= 0.0:
				e["graph_fade_s"] = sg.fade
			ctx[pair[0]].append(e)
	var out := {}
	var a_head: Vector3 = r.A[win[head][0]]
	for pi in parts.size():
		var name: String = parts[pi]
		var s: _Samples = samples[name]
		var c0: int = win[name][0]
		var c1: int = win[name][1]
		var anchor := PackedInt32Array()
		var va: Array = []
		var w: Array = []
		var A: Array = []
		var a0: Vector3 = r.A[c0]
		for k in range(c0, c1 + 1):
			A.append((r.A[k] as Vector3) - a0)
		for k in range(c0, c1):
			anchor.append(r.anchor[k])
			va.append(r.va[k])
			w.append(r.w[k])
		var own := 0
		for x in anchor:
			if x >= 0:
				own += 1
		var od := {"anchor": anchor, "va": va, "w": w, "A": A, "context": ctx,
				"coverage": (float(own) / anchor.size()) if anchor.size() > 0 else 0.0,
				"accel_rms": _accel_rms(w, s.times, anchor), "flight_s": _flight_s(anchor, s.times),
				"switches": _switches(anchor)}
		if parts.size() > 1:
			var off: Vector3 = a0 - a_head
			var pelvis_head: Vector3 = (samples[head] as _Samples).pts[0][I_PELVIS]
			var pelvis_here: Vector3 = s.pts[0][I_PELVIS]
			od["chain"] = {"head": head, "index": pi, "parts": parts,
					"align_offset": {"fwd": off.z, "up": off.y, "side": off.x},
					"pelvis_offset": {"fwd": off.z + pelvis_here.z - pelvis_head.z, "up": off.y + pelvis_here.y - pelvis_head.y,
							"side": off.x + pelvis_here.x - pelvis_head.x}}
		out[name] = od
	return out


## Entry gait speed implied by the clip name (the move it is entered from), for the entry prior of a
## clip without preceding context: sprint 4.24, run 3.34, walk 1.26, crouch(-walk) 1.64 m/s (bank
## speeds in animations/actor_b_clip_metrics.json), idle / stand / hang / ladder / ledge / beam 0;
## -1 = no hint (the prior is not used).
static func _entry_gait_speed(name: String) -> float:
	var s := name.trim_prefix("actor_b-").trim_prefix("p-")
	var first := s.split("^")[0] if "^" in s else s
	for pair in [["sprint", 4.24], ["crouch-run", 3.0], ["run", 3.34], ["walk", 1.26], ["crouch", 0.0], ["idle", 0.0],
			["ladder", 0.0], ["ledge", 0.0], ["hang", 0.0], ["balance-beam", 0.0]]:
		if first.contains(pair[0]):
			return float(pair[1])
	return -1.0


## Chain-level totals: each part's align origin in the head's frame, the whole chain's pelvis travel.
static func _chain_summary(parts: Array, res: Dictionary, samples: Dictionary) -> Dictionary:
	var offs := []
	var dur := 0.0
	for n: String in parts:
		var od: Dictionary = res[n]
		offs.append(od.chain.align_offset if od.has("chain") else {"fwd": 0.0, "up": 0.0, "side": 0.0})
		dur += (samples[n] as _Samples).times[-1]
	var tail: String = parts[parts.size() - 1]
	var ta: Dictionary = res[tail]
	var last_a: Vector3 = ta.A[ta.A.size() - 1]
	var toff: Dictionary = offs[offs.size() - 1]
	var head_p: Vector3 = (samples[parts[0]] as _Samples).pts[0][I_PELVIS]
	var tail_s: _Samples = samples[tail]
	var tail_p: Vector3 = tail_s.pts[tail_s.n - 1][I_PELVIS]
	var end := Vector3(float(toff.side) + last_a.x, float(toff.up) + last_a.y, float(toff.fwd) + last_a.z)
	return {"parts": parts, "duration": dur, "align_offsets": offs,
			"align_end": {"fwd": end.z, "up": end.y, "side": end.x},
			"pelvis_travel": {"fwd": end.z + tail_p.z - head_p.z, "up": end.y + tail_p.y - head_p.y,
					"side": end.x + tail_p.x - head_p.x},
			"context": (res[parts[0]] as Dictionary).context}


## The neighbour to pad with, in this order: the clip itself when it loops (exact seam), an exact
## pose chain, an ambient name set (enter / loop / exit), a graph succession whose boundary poses are within GRAPH_GAP_M (end-of-clip transitions
## only), a near pose chain, a locomotion-loop phase within LOOP_GAP_M. null when none.
static func _pick_neighbor(cur: String, dir: String, samples: Dictionary, cont: Dictionary, cat: Dictionary,
		loops: Dictionary, origin: String) -> _Seg:
	var c: Dictionary = cont.get(cur, {})
	var sc: _Samples = samples[cur]
	var edge: PackedVector3Array = sc.pts[0] if dir == "prev" else sc.pts[sc.n - 1]
	if cur == origin and (c.get(dir + "_exact", []) as Array).has(cur):
		return _clip_seg("self", cur, samples[cur], 0.0, -1.0)
	var ex: Array = (c.get(dir + "_exact", []) as Array).filter(func(x): return x != cur)
	if not ex.is_empty():
		var best := ""
		var best_l := -1
		for x: String in ex:
			var l := _common_prefix(cur, x)
			if l > best_l:
				best_l = l
				best = x
		return _clip_seg("exact", best, samples[best], 0.0, -1.0)
	# Name sets (ambient enter / loop / exit clips of one move, e.g. climb-on-2m-up^run-enter ->
	# ^run-loop -> ^run-exit / ^idle-exit), boundary poses within GRAPH_GAP_M after alignment.
	var ns := _name_set_neighbors(cur, dir, samples)
	var nsbest: _Seg = null
	for other: String in ns:
		var so2: _Samples = samples[other]
		var oe2: PackedVector3Array = so2.pts[so2.n - 1] if dir == "prev" else so2.pts[0]
		var xf2 := _rigid(oe2, edge)
		var gap2 := _pose_gap(_xf_frame(xf2, oe2), edge)
		if gap2 <= GRAPH_GAP_M and (nsbest == null or gap2 < nsbest.gap):
			nsbest = _clip_seg("name_set", other, so2, gap2, -1.0)
			_xf_seg(nsbest, xf2)
	if nsbest != null:
		return nsbest
	# Graph successions (catalog graph_prev / graph_next of the clip at the chain's current end).
	var links: Array = (cat.get(cur, {}) as Dictionary).get("graph_prev" if dir == "prev" else "graph_next", [])
	var gbest: _Seg = null
	for L: Dictionary in links:
		var other: String = L.clip
		if not samples.has(other) or not (samples[other] as _Samples).full_body:
			continue
		var end_type := false
		for v: Dictionary in L.get("via", []):
			var m := RegEx.create_from_string("^>=([0-9.]+)").search(str(v.get("cond", "")))
			if m and float(m.get_string(1)) >= 0.7:
				end_type = true
		if not end_type:
			continue
		var so: _Samples = samples[other]
		var oe: PackedVector3Array = so.pts[so.n - 1] if dir == "prev" else so.pts[0]
		var xf := _rigid(oe, edge)
		var gap := _pose_gap(_xf_frame(xf, oe), edge)
		if gap <= GRAPH_GAP_M and (gbest == null or gap < gbest.gap):
			gbest = _clip_seg("graph", other, so, gap, float(L.get("fade_s", -1.0)))
			_xf_seg(gbest, xf)
	if gbest != null:
		return gbest
	var nr: Array = (c.get(dir + "_near", []) as Array).filter(func(x): return x != cur)
	if not nr.is_empty():
		var nb := ""
		var ng := 1e9
		for x: String in nr:
			var sx: _Samples = samples[x]
			var g := _pose_gap(sx.pts[sx.n - 1] if dir == "prev" else sx.pts[0], edge)
			if g < ng:
				ng = g
				nb = x
		var sn: _Samples = samples[nb]
		var ne: PackedVector3Array = sn.pts[sn.n - 1] if dir == "prev" else sn.pts[0]
		var nxf := _rigid(ne, edge)
		var nseg := _clip_seg("near", nb, sn, _pose_gap(_xf_frame(nxf, ne), edge), -1.0)
		_xf_seg(nseg, nxf)
		return nseg
	# Locomotion loop phase match (legs, pelvis, head).
	var lbest := ""
	var lk := -1
	var lg := 1e9
	for lname: String in loops:
		var ls: _Samples = loops[lname]
		for k in ls.n:
			var g2 := 0.0
			var lp: PackedVector3Array = ls.pts[k]
			var lx := _rigid(lp, edge)
			for i: int in LOOP_MATCH_PTS:
				g2 = maxf(g2, _xf_point(lx, lp[i]).distance_to(edge[i]))
			if g2 < lg:
				lg = g2
				lbest = lname
				lk = k
	if lbest != "" and lg <= LOOP_GAP_M and _pose_gap(_xf_frame(_rigid((loops[lbest] as _Samples).pts[lk], edge), (loops[lbest] as _Samples).pts[lk]), edge) <= LOOP_FULL_GAP_M:
		var ls2: _Samples = loops[lbest]
		var sg := _Seg.new()
		sg.kind = "loop"
		sg.clip = str(LOOPS[lbest])
		var lxf := _rigid(ls2.pts[lk], edge)
		sg.gap = _pose_gap(_xf_frame(lxf, ls2.pts[lk]), edge)
		var steps := int(round(PAD_S * ls2.sr))
		var dt := 1.0 / ls2.sr
		var m := ls2.n - 1   # frames per cycle (last sample == first)
		for j in steps + 1:
			var idx := 0
			if dir == "prev":
				idx = posmod(lk - steps + j, m)
			else:
				idx = posmod(lk + j, m)
			sg.pts.append(_xf_frame(lxf, ls2.pts[idx]))
			sg.times.append(j * dt)
		return sg
	return null


## Rigid transform (yaw about +Y, then translation) that maps frame a's pelvis and facing onto b's.
static func _rigid(a: PackedVector3Array, b: PackedVector3Array) -> Transform3D:
	var yaw := wrapf(_facing(b) - _facing(a), -PI, PI)
	var basis := Basis(Vector3.UP, yaw)
	var t := b[I_PELVIS] - basis * a[I_PELVIS]
	return Transform3D(basis, t)


static func _xf_point(xf: Transform3D, p: Vector3) -> Vector3:
	return xf * p


static func _xf_frame(xf: Transform3D, f: PackedVector3Array) -> PackedVector3Array:
	var o := PackedVector3Array()
	o.resize(f.size())
	for i in f.size():
		o[i] = xf * f[i]
	return o


static func _xf_seg(sg: _Seg, xf: Transform3D) -> void:
	for k in sg.pts.size():
		sg.pts[k] = _xf_frame(xf, sg.pts[k])


## Clips of the same ambient move whose segment comes before (dir prev) / after (dir next) this one:
## the name split at its enter / loop / exit token; the stem is the text before it without a trailing
## run / idle / crouch / walk mode word; order enter -> loop -> exit (enter -> exit when no loop).
static func _name_set_neighbors(name: String, dir: String, samples: Dictionary) -> Array:
	var me := _name_seg(name)
	if me.is_empty():
		return []
	var out := []
	var has_loop := false
	for other: String in samples:
		var o := _name_seg(other)
		if o.is_empty() or o.stem != me.stem or other == name or not (samples[other] as _Samples).full_body:
			continue
		if o.seg == "loop":
			has_loop = true
	for other: String in samples:
		var o := _name_seg(other)
		if o.is_empty() or o.stem != me.stem or other == name or not (samples[other] as _Samples).full_body:
			continue
		var ok := false
		if dir == "next":
			ok = (me.seg == "enter" and (o.seg == "loop" or (o.seg == "exit" and not has_loop))) or (me.seg == "loop" and o.seg == "exit")
		else:
			ok = (me.seg == "exit" and (o.seg == "loop" or (o.seg == "enter" and not has_loop))) or (me.seg == "loop" and o.seg == "enter")
		if ok:
			out.append(other)
	out.sort()
	return out


static func _name_seg(name: String) -> Dictionary:
	var m := RegEx.create_from_string("^(.*?)[-^](?:(?:run|idle|crouch|walk)-)?(enter|loop|exit)([-^].*)?$").search(name)
	if m == null:
		return {}
	var stem := m.get_string(1)
	stem = RegEx.create_from_string("[-^](run|idle|crouch|walk)$").sub(stem, "")
	return {"stem": stem, "seg": m.get_string(2)}


static func _clip_seg(kind: String, clip: String, s: _Samples, gap: float, fade: float) -> _Seg:
	var sg := _Seg.new()
	sg.kind = kind
	sg.clip = clip
	sg.gap = gap
	sg.fade = fade
	sg.times = s.times.duplicate()
	sg.pts = s.pts.duplicate()
	return sg


static func _common_prefix(a: String, b: String) -> int:
	var i := 0
	while i < mini(a.length(), b.length()) and a[i] == b[i]:
		i += 1
	return i


static func _accel_rms(w: Array, times: PackedFloat64Array, anchor: PackedInt32Array) -> float:
	var sum := 0.0
	var n := 0
	for k in range(1, w.size()):
		if anchor[k] < 0 or anchor[k - 1] < 0:
			continue
		var dt := 0.5 * (times[k + 1] - times[k - 1])
		if dt <= 0.0:
			continue
		sum += ((w[k] as Vector3) - (w[k - 1] as Vector3)).length_squared() / (dt * dt)
		n += 1
	return sqrt(sum / n) if n > 0 else 0.0


static func _flight_s(anchor: PackedInt32Array, times: PackedFloat64Array) -> float:
	var f := 0.0
	for k in anchor.size():
		if anchor[k] < 0:
			f += times[k + 1] - times[k]
	return f


static func _switches(anchor: PackedInt32Array) -> int:
	var n := 0
	for k in range(1, anchor.size()):
		if anchor[k] != anchor[k - 1]:
			n += 1
	return n


## Contact path over a sequence (times t[0..N-1], points p[k] = PackedVector3Array in PTS order).
## Returns {anchor: PackedInt32Array (per step, -1 = none), va: [Vector3] align velocity per step,
## w: [Vector3] centre-of-mass world velocity per step, A: [Vector3] align position per sample (A[0] = 0)}.
static func _odometry(t: PackedFloat64Array, p: Array, v0_prior: Variant = null) -> Dictionary:
	var N := t.size()
	var K := N - 1
	var res := {"anchor": PackedInt32Array(), "va": [], "w": [], "A": [Vector3.ZERO]}
	if K <= 0:
		return res
	var dt := PackedFloat64Array()
	var u: Array = []    # u[k][a] Vector3
	var up := []         # pelvis skeleton velocity per step
	var em: Array = []   # emission cost per step per anchor
	# Contact gates: a foot (knee) can anchor only while its sole (joint) height is within GATE_TOL of
	# its lowest height over +-GATE_WIN_S, i.e. it is down on something rather than swinging or tucked.
	var gate := _contact_gates(t, p)
	var com := PackedVector3Array()
	for k in N:
		var c := Vector3.ZERO
		var pk0: PackedVector3Array = p[k]
		for i: int in COM_W:
			c += pk0[i] * float(COM_W[i])
		com.append(c)
	for k in K:
		var d := maxf(t[k + 1] - t[k], 1e-4)
		dt.append(d)
		var pk: PackedVector3Array = p[k]
		var pk1: PackedVector3Array = p[k + 1]
		var uk := []
		var ek := PackedFloat64Array()
		for a in ANCHORS:
			var e := 0.0
			var ap: Array = A_PTS[a]
			match A_KIND[a]:
				"foot":
					# Rolling sole: vertical from the lowest sole height (heel, ball - BALL_SOLE),
					# horizontal from whichever of heel / ball is lower over the step.
					var h: int = ap[0]
					var bl: int = ap[1]
					var s0 := minf(pk[h].y, pk[bl].y - BALL_SOLE)
					var s1 := minf(pk1[h].y, pk1[bl].y - BALL_SOLE)
					var q := bl if (pk[bl].y + pk1[bl].y - 2.0 * BALL_SOLE) < (pk[h].y + pk1[h].y) else h
					uk.append(Vector3((pk1[q].x - pk[q].x) / d, (s1 - s0) / d, (pk1[q].z - pk[q].z) / d))
					var y := absf(0.5 * (s0 + s1))
					var ex := maxf(0.0, y - FOOT_Y_FREE) / FOOT_Y_SCALE
					e = ex * ex
					if not (gate[a][k] and gate[a][k + 1]):
						e = GATED
				"hand":
					uk.append((pk1[ap[0]] - pk[ap[0]]) / d)
					e = HAND_COST
				"knee":
					uk.append((pk1[ap[0]] - pk[ap[0]]) / d)
					e = KNEE_COST
					if not (gate[a][k] and gate[a][k + 1]):
						e = GATED
			ek.append(e * d / 0.1)
		u.append(uk)
		up.append((com[k + 1] - com[k]) / d)
		em.append(ek)
	_co_stationary_bonus(em, u, dt, t)
	var dt_min := dt[0]
	for d in dt:
		dt_min = minf(dt_min, d)
	var gmax := maxi(1, int(ceil(GAP_MAX_S / dt_min)))
	var emax := maxi(1, int(ceil(END_MAX_S / dt_min)))
	# prefix sums of dt for gap durations
	var cum := PackedFloat64Array([0.0])
	for k in K:
		cum.append(cum[k] + dt[k])
	var INF := 1e18
	var cost: Array = []
	var back: Array = []   # [prev_k, prev_a] or [-1, -1] for a start
	for k in K:
		var ck := PackedFloat64Array()
		var bk := []
		for a in ANCHORS:
			var w_ka: Vector3 = up[k] - u[k][a]
			var best := INF
			var bb := [-1, -1]
			# start: unanchored steps 0..k-1 (+ the entry-speed prior on the first anchored velocity)
			if cum[k] <= END_MAX_S + 1e-6:
				var c0 := END_PEN * cum[k] / 0.1
				if v0_prior is Vector3:
					var dv0 := Vector2(w_ka.x - (v0_prior as Vector3).x, w_ka.z - (v0_prior as Vector3).z)
					c0 += dv0.length_squared() / (ENTRY_SIG * ENTRY_SIG)
				if c0 < best:
					best = c0
					bb = [-1, -1]
			if k >= 1:
				var dtm := 0.5 * (dt[k - 1] + dt[k])
				for b in ANCHORS:
					var cb: float = cost[k - 1][b]
					if cb >= INF:
						continue
					var w_kb: Vector3 = up[k - 1] - u[k - 1][b]
					var acc := (w_ka - w_kb) / dtm
					var c := cb + acc.length_squared() / (SIG_A * SIG_A) * dt[k] / 0.1 + _switch_cost(b, a) + _phys_cost(acc, a)
					if c < best:
						best = c
						bb = [k - 1, b]
				for j in range(maxi(0, k - 1 - gmax), k - 1):
					var tair := cum[k] - cum[j + 1]
					if tair > GAP_MAX_S + 1e-6:
						continue
					var T := 0.5 * dt[j] + tair + 0.5 * dt[k]
					for b in ANCHORS:
						var cb2: float = cost[j][b]
						if cb2 >= INF:
							continue
						var w_jb: Vector3 = up[j] - u[j][b]
						var c2 := cb2 + _flight_cost(w_jb, w_ka, tair, T) + GAP_PEN * tair / 0.1 + _switch_cost(b, a)
						if c2 < best:
							best = c2
							bb = [j, b]
			ck.append(best + em[k][a])
			bk.append(bb)
		cost.append(ck)
		back.append(bk)
	# end: last anchored step j, then unanchored to the end (or nothing anchored at all)
	var best_end := END_PEN * cum[K] / 0.1 if cum[K] <= 2.0 * END_MAX_S else INF * 0.5
	var end_k := -1
	var end_a := -1
	for j in range(maxi(0, K - 1 - emax), K):
		var tail := cum[K] - cum[j + 1]
		if tail > END_MAX_S + 1e-6:
			continue
		for a in ANCHORS:
			var c: float = cost[j][a] + END_PEN * tail / 0.1
			if c < best_end:
				best_end = c
				end_k = j
				end_a = a
	var anchor := PackedInt32Array()
	anchor.resize(K)
	anchor.fill(-1)
	var k2 := end_k
	var a2 := end_a
	while k2 >= 0:
		anchor[k2] = a2
		var bb: Array = back[k2][a2]
		k2 = bb[0]
		a2 = bb[1]
	# Pelvis world velocity: anchored steps from their anchor; gaps interpolated; ends ballistic.
	var w: Array = []
	w.resize(K)
	var anch_idx := []
	for k in K:
		if anchor[k] >= 0:
			w[k] = up[k] - u[k][anchor[k]]
			anch_idx.append(k)
	if anch_idx.is_empty():
		for k in K:
			w[k] = G * (0.5 * dt[k] + cum[k])
	else:
		for i in range(anch_idx.size() - 1):
			var j: int = anch_idx[i]
			var m: int = anch_idx[i + 1]
			for k in range(j + 1, m):
				# ballistic from the takeoff step; the landing step absorbs the impact
				w[k] = (w[j] as Vector3) + G * ((cum[k] + 0.5 * dt[k]) - (cum[j] + 0.5 * dt[j]))
		var f0: int = anch_idx[0]
		for k in range(0, f0):
			w[k] = w[f0]
		var l0: int = anch_idx[-1]
		for k in range(l0 + 1, K):
			w[k] = (w[l0] as Vector3) + G * ((cum[k] + 0.5 * dt[k]) - (cum[l0] + 0.5 * dt[l0]))
	var va: Array = []
	var A: Array = [Vector3.ZERO]
	for k in K:
		var v: Vector3 = (w[k] as Vector3) - (up[k] as Vector3)
		va.append(v)
		A.append((A[k] as Vector3) + v * dt[k])
	res.anchor = anchor
	res.va = va
	res.w = w
	res.A = A
	return res


## Two different limbs whose skeleton-space velocities agree within CO_V for at least CO_MIN_S are
## both planted (a hold with both hands, a two-footed stance): their anchor cost drops by CO_BONUS
## per 0.1 s over that run. Brief agreement (both hands reaching together) earns nothing.
static func _co_stationary_bonus(em: Array, u: Array, dt: PackedFloat64Array, t: PackedFloat64Array) -> void:
	var K := dt.size()
	for a in ANCHORS:
		if A_KIND[a] == "knee":
			continue
		var co := []
		for k in K:
			var hit := false
			for b in ANCHORS:
				if b == a or A_KIND[b] == "knee":
					continue
				if ((u[k][a] as Vector3) - (u[k][b] as Vector3)).length() < CO_V:
					hit = true
					break
			co.append(hit)
		var k := 0
		while k < K:
			if not co[k]:
				k += 1
				continue
			var k0 := k
			while k < K and co[k]:
				k += 1
			if t[k] - t[k0] >= CO_MIN_S - 1e-6:
				for kk in range(k0, k):
					if em[kk][a] < GATED:
						em[kk][a] -= CO_BONUS * dt[kk] / 0.1


## gate[a][k]: whether anchor a may be in contact at sample k (hands: always).
static func _contact_gates(t: PackedFloat64Array, p: Array) -> Array:
	var N := t.size()
	var h := []   # per anchor per sample height
	for a in ANCHORS:
		var arr := PackedFloat64Array()
		var ap: Array = A_PTS[a]
		for k in N:
			var pk: PackedVector3Array = p[k]
			match A_KIND[a]:
				"foot":
					arr.append(minf(pk[ap[0]].y, pk[ap[1]].y - BALL_SOLE))
				_:
					arr.append(pk[ap[0]].y)
		h.append(arr)
	var out := []
	for a in ANCHORS:
		var g := []
		var arr: PackedFloat64Array = h[a]
		for k in N:
			if A_KIND[a] == "hand":
				g.append(true)
				continue
			var lo := arr[k]
			var j := k
			while j > 0 and t[k] - t[j - 1] <= GATE_WIN_S + 1e-6:
				j -= 1
				lo = minf(lo, arr[j])
			j = k
			while j < N - 1 and t[j + 1] - t[k] <= GATE_WIN_S + 1e-6:
				j += 1
				lo = minf(lo, arr[j])
			var ok := arr[k] <= lo + GATE_TOL
			if A_KIND[a] == "knee":
				ok = ok and arr[k] <= KNEE_MAX_Y
			g.append(ok)
		out.append(g)
	return out


## Flight between a takeoff step (centre-of-mass world velocity w0) and a landing step (w1) with tair
## seconds unanchored in between (T from step centre to step centre): the centre of mass flies
## ballistically, and the landing may add an impact impulse that points up and stays inside the
## friction cone (|dv_horizontal| <= MU dv_y). Only the part of the residual dv = w1 - (w0 + g tair)
## that no landing impulse explains costs ((dv_bad / T) / SIG_F)^2 * T / 0.1.
static func _flight_cost(w0: Vector3, w1: Vector3, tair: float, T: float) -> float:
	var dv := w1 - (w0 + G * tair)
	var bad_y := minf(0.0, dv.y + PHYS_TOL * T)
	var dh := Vector2(dv.x, dv.z).length()
	var bad_h := maxf(0.0, dh - MU * maxf(0.0, dv.y) - PHYS_TOL * T)
	var r2 := (bad_y * bad_y + bad_h * bad_h) / (T * T)
	return r2 / (SIG_F * SIG_F) * T / 0.1


## Physics penalty of a supported centre-of-mass acceleration with anchor a (see PHYS_TOL).
static func _phys_cost(acc: Vector3, a: int) -> float:
	var c := 0.0
	var lo := G.y - PHYS_TOL
	if acc.y < lo:
		var e := (lo - acc.y) / PHYS_SIG
		c += e * e
	if A_KIND[a] != "hand":
		var ah := Vector2(acc.x, acc.z).length()
		var lim := MU * maxf(0.0, acc.y - G.y) + PHYS_TOL
		if ah > lim:
			var e2 := (ah - lim) / PHYS_SIG
			c += e2 * e2
	return c


static func _switch_cost(b: int, a: int) -> float:
	return 0.0 if a == b else SWITCH_OTHER


# =================================================================================================
# Per-clip geometry
# =================================================================================================

static func _basics(rig: _Rig, a: Animation, s: _Samples) -> Dictionary:
	var keyed := PackedStringArray()
	for b in s.keyed:
		keyed.append(rig.names[b])
	keyed.sort()
	var groups := {}
	var other := 0
	var props := PackedStringArray()
	if _group_rx.is_empty():
		for gname: String in GROUP_RX:
			_group_rx[gname] = RegEx.create_from_string(GROUP_RX[gname])
	for bn in keyed:
		var hit := false
		for gname: String in GROUP_RX:
			if (_group_rx[gname] as RegEx).search(bn):
				groups[gname] = int(groups.get(gname, 0)) + 1
				if gname == "props":
					props.append(bn)
				hit = true
				break
		if not hit:
			other += 1
	groups["other"] = other
	var slot := "pose"
	if s.additive:
		slot = "additive"
	elif s.full_body:
		slot = "full_body"
	elif int(groups.get("l_arm", 0)) + int(groups.get("r_arm", 0)) > 0:
		slot = "upper_body" if int(groups.get("spine", 0)) > 0 else "arms"
	elif int(groups.get("l_hand", 0)) + int(groups.get("r_hand", 0)) > 0:
		slot = "hands"
	var root_tr := {"pos": false, "rot": false}
	var rb := rig.bone("root")
	for ti in a.get_track_count():
		if str(a.track_get_path(ti).get_concatenated_subnames()) == "root":
			match a.track_get_type(ti):
				Animation.TYPE_POSITION_3D:
					root_tr.pos = true
				Animation.TYPE_ROTATION_3D:
					root_tr.rot = true
	var d := {
		"native_asset_id": str(a.get_meta("native_asset_id", "")) if a.has_meta("native_asset_id") else null,
		"original_name": str(a.get_meta("original_name", "")) if a.has_meta("original_name") else null,
		"source_names": a.get_meta("source_names", []) if a.has_meta("source_names") else [],
		"length": a.length,
		"sample_rate": s.sr,
		"sample_count": s.n,
		"keyed": {"count": keyed.size(), "groups": groups, "slot": slot, "additive": s.additive,
				"props": props, "bones": keyed if not s.full_body else []},
		"root_keyed": root_tr,
	}
	return d


static func _geometry(rig: _Rig, name: String, s: _Samples, od: Dictionary, refs: Dictionary, cat: Dictionary) -> Dictionary:
	var n := s.n
	var A: Array = od.A
	var anchor: PackedInt32Array = od.anchor
	var wp := []   # world points per sample
	for k in n:
		var pk: PackedVector3Array = s.pts[k]
		var wk := PackedVector3Array()
		for i in PTS.size():
			wk.append(pk[i] + (A[k] as Vector3))
		wp.append(wk)
	var t := s.times
	# --- contacts --------------------------------------------------------------------------------
	var contacts := _contacts(s, wp, anchor)
	# --- start / end support ---------------------------------------------------------------------
	var sup0: Variant = _support_h(contacts.feet, t[0], true)
	var sup1: Variant = _support_h(contacts.feet, t[n - 1], false)
	var base_h: float = sup0 if sup0 != null else 0.0
	# --- travel ---------------------------------------------------------------------------------
	var p0: Vector3 = wp[0][I_PELVIS]
	var p1: Vector3 = wp[n - 1][I_PELVIS]
	var ymax := -1e9
	var ymin := 1e9
	var head_max := -1e9
	var head_min := 1e9
	var path := 0.0
	for k in n:
		var pk: Vector3 = wp[k][I_PELVIS]
		ymax = maxf(ymax, pk.y)
		ymin = minf(ymin, pk.y)
		var ht: float = (wp[k][I_HEADB] as Vector3).y + HEAD_TOP
		head_max = maxf(head_max, ht)
		head_min = minf(head_min, ht)
		if k > 0:
			var pp: Vector3 = wp[k - 1][I_PELVIS]
			path += Vector2(pk.x - pp.x, pk.z - pp.z).length()
	var yaw0 := _facing(s.pts[0])
	var yaw1 := _facing(s.pts[n - 1])
	var root0: Vector3 = s.pts[0][I_ROOT]
	var root1: Vector3 = s.pts[n - 1][I_ROOT]
	var rmax := 0.0
	for k in n:
		var r: Vector3 = s.pts[k][I_ROOT]
		rmax = maxf(rmax, Vector2(r.x - root0.x, r.z - root0.z).length())
	var world_h := Vector2(p1.x - p0.x, p1.z - p0.z).length()
	var root_h := Vector2(root1.x - root0.x, root1.z - root0.z).length()
	var travel := {
		"fwd": p1.z - p0.z, "side": p1.x - p0.x, "up_net": p1.y - p0.y,
		"up_max": ymax - p0.y, "down_max": ymin - p0.y,
		"path_h": path,
		"align_fwd": (A[n - 1] as Vector3).z, "align_side": (A[n - 1] as Vector3).x, "align_up": (A[n - 1] as Vector3).y,
		"support_start_h": sup0, "support_end_h": sup1,
		"height_change": (sup1 - sup0) if (sup0 != null and sup1 != null) else null,
		"head_top_max": head_max - base_h, "head_top_min": head_min - base_h,
		"pelvis_start_h": p0.y - base_h, "pelvis_end_h": p1.y - (sup1 if sup1 != null else base_h),
		"yaw_change_deg": rad_to_deg(wrapf(yaw1 - yaw0, -PI, PI)),
	}
	var root_motion := {
		"root_horizontal_travel_m": root_h, "root_max_excursion_m": rmax, "world_travel_m": world_h,
		"ground_root_bone": false,
		"in_skeleton": root_h >= 0.5 and root_h >= 0.5 * world_h,
		"align_channel": "not exported",
	}
	# --- entry / exit -----------------------------------------------------------------------------
	var entry := _endpoint(s, od, refs, true, wp)
	var exit := _endpoint(s, od, refs, false, wp)
	# --- series -----------------------------------------------------------------------------------
	var stride := maxi(1, int(round(s.sr / SERIES_MAX_HZ)))
	var ser := {"t": [], "anchor": [], "align_fwd": [], "align_up": [], "align_side": [],
			"pelvis_fwd": [], "pelvis_up": [], "pelvis_side": [], "pelvis_skel_fwd": [], "pelvis_skel_up": [],
			"head_top_up": [], "speed_h": []}
	for k in range(0, n, stride):
		ser.t.append(t[k])
		var ak: Vector3 = A[k]
		ser.align_fwd.append(ak.z)
		ser.align_up.append(ak.y)
		ser.align_side.append(ak.x)
		var pk: Vector3 = wp[k][I_PELVIS]
		ser.pelvis_fwd.append(pk.z)
		ser.pelvis_up.append(pk.y)
		ser.pelvis_side.append(pk.x)
		var sk: Vector3 = s.pts[k][I_PELVIS]
		ser.pelvis_skel_fwd.append(sk.z)
		ser.pelvis_skel_up.append(sk.y)
		ser.head_top_up.append((wp[k][I_HEADB] as Vector3).y + HEAD_TOP)
		if k < n - 1:
			ser.anchor.append(A_LABEL[anchor[k]] if anchor[k] >= 0 else "air")
			var wv: Vector3 = od.w[k]
			ser.speed_h.append(Vector2(wv.x, wv.z).length())
	var odo := {"method": "contact_path", "context": od.context, "coverage": od.coverage,
			"accel_rms": od.accel_rms, "flight_s": od.flight_s, "anchor_switches": od.switches,
			"anchors_used": _anchor_hist(anchor, t), "planted_yaw_drift_deg": _planted_yaw_drift(s, wp, anchor),
			"flags": []}
	if od.coverage < 0.5:
		odo.flags.append("low_coverage")
	if absf(float(odo.planted_yaw_drift_deg)) > 10.0:
		odo.flags.append("planted_foot_rotates (align turn not modelled)")
	if absf(travel.yaw_change_deg) > 30.0:
		odo.flags.append("facing_turns_in_skeleton_space")
	if anchor.size() > 0 and anchor[0] < 0:
		odo.flags.append("starts_airborne")
	if anchor.size() > 0 and anchor[anchor.size() - 1] < 0:
		odo.flags.append("ends_airborne")
	# Confidence of the align path (travel, contact heights): high = mostly anchored with context or
	# a grounded start; low = mostly unanchored (flight or unobservable in-place motion).
	var conf := "medium"
	var has_ctx: bool = not (od.context.before as Array).is_empty() or not (od.context.after as Array).is_empty()
	if od.coverage >= 0.8 and od.accel_rms < 15.0 and not odo.flags.has("starts_airborne") and (has_ctx or travel.support_start_h != null):
		conf = "high"
	elif od.coverage < 0.5:
		conf = "low"
	odo["confidence"] = conf
	var implied := _implied(cat.family, name, s, wp, contacts, travel, base_h, od, t)
	return {"root_motion": root_motion, "odometry": odo, "travel": travel, "entry": entry, "exit": exit,
			"contacts": contacts, "implied": implied, "series": ser}


static func _anchor_hist(anchor: PackedInt32Array, t: PackedFloat64Array) -> Dictionary:
	var h := {}
	for k in anchor.size():
		var lab: String = A_LABEL[anchor[k]] if anchor[k] >= 0 else "air"
		h[lab] = float(h.get(lab, 0.0)) + (t[k + 1] - t[k])
	return h


## Skeleton-space facing yaw (rad, 0 = +Z, + = towards +X) from the hip axis.
static func _facing(pk: PackedVector3Array) -> float:
	var hip: Vector3 = pk[I_RUL] - pk[I_LUL]
	var fwd := Vector3.UP.cross(hip)
	return atan2(fwd.x, fwd.z)


## Largest yaw change of the heel -> ball vector over a planted (heel and ball both anchored-static)
## foot run, in degrees: an align rotation would show up here.
static func _planted_yaw_drift(s: _Samples, wp: Array, anchor: PackedInt32Array) -> float:
	var worst := 0.0
	for foot in [[I_LH, I_LB], [I_RH, I_RB]]:
		var run_start := -1
		for k in range(0, s.n):
			var planted := false
			if k < s.n - 1:
				var dh: Vector3 = (wp[k + 1][foot[0]] as Vector3) - (wp[k][foot[0]] as Vector3)
				var db: Vector3 = (wp[k + 1][foot[1]] as Vector3) - (wp[k][foot[1]] as Vector3)
				var dt := s.times[k + 1] - s.times[k]
				planted = dh.length() / dt < CONTACT_V and db.length() / dt < CONTACT_V
			if planted and run_start < 0:
				run_start = k
			elif not planted and run_start >= 0:
				var v0: Vector3 = (s.pts[run_start][foot[1]] as Vector3) - (s.pts[run_start][foot[0]] as Vector3)
				var v1: Vector3 = (s.pts[k][foot[1]] as Vector3) - (s.pts[k][foot[0]] as Vector3)
				if Vector2(v0.x, v0.z).length() > 0.05 and Vector2(v1.x, v1.z).length() > 0.05:
					var d := rad_to_deg(wrapf(atan2(v1.x, v1.z) - atan2(v0.x, v0.z), -PI, PI))
					if absf(d) > absf(worst):
						worst = d
				run_start = -1
	return worst


## Contact runs per limb from world speeds.
static func _contacts(s: _Samples, wp: Array, anchor: PackedInt32Array) -> Dictionary:
	var out := {"hands": [], "feet": [], "knees": []}
	var limbs := [
		["feet", "l", [I_LH, I_LB]], ["feet", "r", [I_RH, I_RB]],
		["hands", "l", [I_LP]], ["hands", "r", [I_RP]],
		["knees", "l", [I_LK]], ["knees", "r", [I_RK]],
	]
	for L in limbs:
		var kind: String = L[0]
		var side: String = L[1]
		var idx: Array = L[2]
		var on := []
		for k in range(0, s.n - 1):
			var dt := s.times[k + 1] - s.times[k]
			var hit := -1
			for i: int in idx:
				var v := ((wp[k + 1][i] as Vector3) - (wp[k][i] as Vector3)).length() / dt
				if v < CONTACT_V:
					hit = i
					break
			on.append(hit)
		var k := 0
		while k < on.size():
			if on[k] < 0:
				k += 1
				continue
			var k0 := k
			var pts_used := {}
			while k < on.size() and on[k] >= 0:
				pts_used[on[k]] = true
				k += 1
			var k1 := k   # sample index of the run's last sample
			var i0: int = on[k0]
			var pw: Vector3 = wp[k0][i0]
			var rec := {kind.substr(0, kind.length() - 1) if kind != "feet" else "foot": side, "limb": side,
					"t0": s.times[k0], "t1": s.times[k1], "f0": k0, "f1": k1,
					"fwd": pw.z, "side": pw.x, "up": pw.y}
			if kind == "feet":
				var names := []
				for i in pts_used:
					names.append("heel" if i in [I_LH, I_RH] else "ball")
				names.sort()
				rec["point"] = "both" if names.size() > 1 else names[0]
				rec["up"] = minf((wp[k0][idx[0]] as Vector3).y, (wp[k0][idx[1]] as Vector3).y)
			elif kind == "hands":
				var hp: PackedVector3Array = wp[k0]
				var lo := minf(hp[I_LP if side == "l" else I_RP].y, minf(hp[I_LMM if side == "l" else I_RMM].y, hp[I_LMA if side == "l" else I_RMA].y))
				rec["surface_up"] = lo - HAND_SKIN
				rec["rel_pelvis_up"] = pw.y - (wp[k0][I_PELVIS] as Vector3).y
				rec["rel_head_up"] = pw.y - (wp[k0][I_HEADB] as Vector3).y
				var anch := false
				var ai := 2 if side == "l" else 3
				for kk in range(k0, k1):
					if kk < anchor.size() and anchor[kk] == ai:
						anch = true
				var pm: float = ((wp[k1][I_PELVIS] as Vector3) - (wp[k0][I_PELVIS] as Vector3)).length()
				rec["supporting"] = anch or pm > 0.05
				rec["anchor"] = anch
			elif kind == "knees":
				rec["rel_pelvis_up"] = pw.y - (wp[k0][I_PELVIS] as Vector3).y
			out[kind].append(rec)
	for kind in out:
		(out[kind] as Array).sort_custom(func(x, y): return x.t0 < y.t0 or (x.t0 == y.t0 and str(x.limb) < str(y.limb)))
	return out


## World height of the support at the start (feet in contact at t = first sample) or at the end.
static func _support_h(feet: Array, t: float, start: bool) -> Variant:
	var hs := []
	for c: Dictionary in feet:
		if (start and absf(float(c.t0) - t) < 1e-6) or (not start and absf(float(c.t1) - t) < 1e-6):
			hs.append(float(c.up))
	if hs.is_empty():
		return null
	hs.sort()
	return hs[0]


static func _endpoint(s: _Samples, od: Dictionary, refs: Dictionary, start: bool, wp: Array) -> Dictionary:
	var w: Array = od.w
	var n := s.n
	var v := Vector3.ZERO
	var wsum := 0.0
	var t0 := s.times[0] if start else s.times[n - 1]
	for k in w.size():
		var tm := 0.5 * (s.times[k] + s.times[k + 1])
		if absf(tm - t0) <= 0.2 + 1e-6:
			var d := s.times[k + 1] - s.times[k]
			v += (w[k] as Vector3) * d
			wsum += d
	if wsum > 0.0:
		v /= wsum
	var sp := Vector2(v.x, v.z).length()
	var gait := "idle"
	for g in GAIT:
		if sp < float(g[0]):
			gait = g[1]
			break
	var k := 0 if start else n - 1
	var pm := _match_pose(s, k, refs)
	var anc: PackedInt32Array = od.anchor
	var a: int = (anc[0] if start else anc[anc.size() - 1]) if anc.size() > 0 else -1
	return {"speed_h": sp, "vel_fwd": v.z, "vel_up": v.y, "vel_side": v.x, "gait": gait,
			"pose": pm.best, "pose_dist": pm.dist, "pose_alt": pm.alt, "pose_alt_dist": pm.alt_dist,
			"pelvis_skel_h": (s.pts[k][I_PELVIS] as Vector3).y,
			"anchor": A_LABEL[a] if a >= 0 else "air"}


# --- pose references -------------------------------------------------------------------------------

class _PoseRef:
	var label := ""
	var clip := ""
	var rots: Array = []     ## per frame Array[Quaternion] (POSE_BONES)
	var tilt: Array = []     ## per frame root swing quaternion
	var root_h := PackedFloat64Array()


static func _pose_refs(rig: _Rig, lib: AnimationLibrary, warnings: Array) -> Dictionary:
	var out := {}
	for label: String in POSE_REFS:
		var spec: Dictionary = POSE_REFS[label]
		if not lib.has_animation(spec.clip):
			warnings.append("pose reference %s (%s) missing from the library" % [label, spec.clip])
			continue
		var s := _sample(rig, lib.get_animation(spec.clip))
		var r := _PoseRef.new()
		r.label = label
		r.clip = spec.clip
		var ks := []
		if spec.get("first", false):
			ks = [0]
		elif float(spec.get("every_s", 0.0)) > 0.0:
			var step := maxi(1, roundi(float(spec.every_s) * s.sr))
			ks = range(0, s.n, step)
		else:
			ks = range(0, s.n)
		for k: int in ks:
			r.rots.append(s.rots[k])
			r.tilt.append(_swing(s.root_q[k]))
			r.root_h.append((s.pts[k][I_ROOT] as Vector3).y)
		out[label] = r
	return out


static func _ref_summary(refs: Dictionary) -> Dictionary:
	var d := {}
	for l: String in refs:
		d[l] = {"clip": (refs[l] as _PoseRef).clip, "frames": (refs[l] as _PoseRef).rots.size()}
	return d


static func _swing(q: Quaternion) -> Quaternion:
	var tw := Quaternion(0.0, q.y, 0.0, q.w)
	if tw.length() < 1e-6:
		return q
	tw = tw.normalized()
	return (q * tw.inverse()).normalized()


static func _match_pose(s: _Samples, k: int, refs: Dictionary) -> Dictionary:
	var best := ""
	var bd := 1e9
	var alt := ""
	var ad := 1e9
	var rq: Array = s.rots[k]
	var sw := _swing(s.root_q[k])
	var rh: float = (s.pts[k][I_ROOT] as Vector3).y
	for l: String in refs:
		var r: _PoseRef = refs[l]
		var dmin := 1e9
		for f in r.rots.size():
			var sum := 0.0
			for i in rq.size():
				sum += _qangle(rq[i], r.rots[f][i])
			sum += _qangle(sw, r.tilt[f])
			var d := rad_to_deg(sum / (rq.size() + 1)) + 100.0 * absf(rh - r.root_h[f])
			dmin = minf(dmin, d)
		if dmin < bd:
			alt = best
			ad = bd
			best = l
			bd = dmin
		elif dmin < ad:
			alt = l
			ad = dmin
	return {"best": best, "dist": bd, "alt": alt, "alt_dist": ad}


static func _qangle(a: Quaternion, b: Quaternion) -> float:
	var s := 1.0 if a.dot(b) >= 0.0 else -1.0
	var d := Vector4(a.x - s * b.x, a.y - s * b.y, a.z - s * b.z, a.w - s * b.w).length()
	var e := Vector4(a.x + s * b.x, a.y + s * b.y, a.z + s * b.z, a.w + s * b.w).length()
	return 4.0 * atan2(d, e)


# --- implied geometry --------------------------------------------------------------------------

static func _implied(family: String, name: String, s: _Samples, wp: Array, contacts: Dictionary,
		travel: Dictionary, base_h: float, od: Dictionary, t: PackedFloat64Array) -> Dictionary:
	var imp := {"reference_ground": "start support (feet in contact at the first sample); 0 when none",
			"start_support_known": travel.support_start_h != null}
	# Top contacts: supporting hands, and feet / knees that land >= 0.3 m above the start support.
	var tops := []
	for c: Dictionary in contacts.hands:
		if c.supporting and float(c.surface_up) - base_h > 0.3:
			tops.append({"kind": "hand", "side": c.hand, "t0": c.t0, "f0": c.f0, "fwd": c.fwd, "side_m": c.side,
					"h": float(c.surface_up) - base_h})
	for c: Dictionary in contacts.feet:
		if float(c.up) - base_h > 0.3:
			tops.append({"kind": "foot", "side": c.foot, "t0": c.t0, "f0": c.f0, "fwd": c.fwd, "side_m": c.side,
					"h": float(c.up) - base_h})
	for c: Dictionary in contacts.knees:
		if float(c.up) - base_h > 0.3:
			tops.append({"kind": "knee", "side": c.knee, "t0": c.t0, "f0": c.f0, "fwd": c.fwd, "side_m": c.side,
					"h": float(c.up) - base_h - 0.05})
	imp["top_contacts"] = tops
	var hand_tops := tops.filter(func(x): return x.kind == "hand")
	if not hand_tops.is_empty():
		var hs := hand_tops.map(func(x): return float(x.h))
		hs.sort()
		imp["hand_top_h_median"] = hs[hs.size() / 2]
		imp["hand_top_h_min"] = hs[0]
		imp["hand_top_h_max"] = hs[-1]
		imp["first_hand_contact"] = {"t": hand_tops[0].t0, "frame": hand_tops[0].f0, "fwd": hand_tops[0].fwd,
				"h": hand_tops[0].h, "side": hand_tops[0].side}
	if not tops.is_empty():
		var fw := tops.map(func(x): return float(x.fwd))
		fw.sort()
		imp["top_fwd_min"] = fw[0]
		imp["top_fwd_max"] = fw[-1]
		imp["top_depth_min"] = fw[-1] - fw[0]
	imp["landing_h"] = travel.height_change
	imp["flight_s"] = od.flight_s
	# Longest flight: takeoff / landing contacts around it.
	var anchor: PackedInt32Array = od.anchor
	var best_len := 0.0
	var bj := -1
	var bm := -1
	var k := 0
	while k < anchor.size():
		if anchor[k] >= 0:
			k += 1
			continue
		var k0 := k
		while k < anchor.size() and anchor[k] < 0:
			k += 1
		var L := t[k] - t[k0]
		if L > best_len:
			best_len = L
			bj = k0
			bm = k
	if bj >= 0:
		var pre: Variant = (wp[bj][I_PELVIS] as Vector3)
		var post: Variant = (wp[bm][I_PELVIS] as Vector3)
		var apex := -1e9
		for kk in range(bj, bm + 1):
			apex = maxf(apex, (wp[kk][I_PELVIS] as Vector3).y)
		imp["longest_flight"] = {"t0": t[bj], "t1": t[bm], "s": best_len, "takeoff_anchor": A_LABEL[anchor[bj - 1]] if bj > 0 else "start",
				"landing_anchor": A_LABEL[anchor[bm]] if bm < anchor.size() else "end",
				"pelvis_fwd": (post as Vector3).z - (pre as Vector3).z, "pelvis_up": (post as Vector3).y - (pre as Vector3).y,
				"apex_above_takeoff": apex - (pre as Vector3).y}
	match family:
		"ladder":
			imp["rung_pitch"] = _rung_pitch(contacts)
			var dur := t[s.n - 1] - t[0]
			imp["climb_speed"] = (float(travel.up_net) / dur) if dur > 0.0 else 0.0
		"beam":
			var sides: Array = contacts.feet.map(func(c): return float(c.side))
			imp["foot_side_spread"] = (sides.max() - sides.min()) if sides.size() > 1 else 0.0
			imp["step_fwd"] = _step_fwd(contacts.feet)
		"crouch_under":
			imp["head_top_max"] = travel.head_top_max
			imp["head_top_min"] = travel.head_top_min
		"wall_shimmy", "edge_warn":
			var dur2 := t[s.n - 1] - t[0]
			imp["side_speed"] = (float(travel.side) / dur2) if dur2 > 0.0 else 0.0
		"gap_jump":
			if imp.has("longest_flight"):
				imp["gap_pelvis_fwd"] = imp.longest_flight.pelvis_fwd
		"drop":
			imp["drop_h"] = -float(travel.height_change) if travel.height_change != null else null
	return imp


static func _rung_pitch(contacts: Dictionary) -> Variant:
	var steps := []
	for side in ["l", "r"]:
		var hs: Array = contacts.hands.filter(func(c): return c.hand == side).map(func(c): return float(c.up))
		for i in range(1, hs.size()):
			var d: float = absf(hs[i] - hs[i - 1])
			if d > 0.08:
				steps.append(d)
		var fs: Array = contacts.feet.filter(func(c): return c.foot == side).map(func(c): return float(c.up))
		for i in range(1, fs.size()):
			var d2: float = absf(fs[i] - fs[i - 1])
			if d2 > 0.08:
				steps.append(d2)
	if steps.is_empty():
		return null
	steps.sort()
	return steps[steps.size() / 2]


static func _step_fwd(feet: Array) -> Variant:
	if feet.size() < 2:
		return null
	var d := []
	for i in range(1, feet.size()):
		d.append(absf(float(feet[i].fwd) - float(feet[i - 1].fwd)))
	d.sort()
	return d[d.size() / 2]


# --- variants ---------------------------------------------------------------------------------------

static func _part_report(rig: _Rig, lib: AnimationLibrary, name: String, base: String, samples: Dictionary,
		od: Dictionary, base_rec: Dictionary) -> Dictionary:
	var pa := lib.get_animation(name)
	var ba := lib.get_animation(base)
	var ps: _Samples = samples[name]
	var bs: _Samples = samples[base]
	var rep := {"base_clip": base, "length": pa.length, "base_length": ba.length,
			"length_match": absf(pa.length - ba.length) < 1e-3, "sample_rate": ps.sr, "base_sample_rate": bs.sr}
	if ps.additive:
		rep["note"] = "additive clip: not composed"
		return rep
	# Composite pose (base with the part's keyed bones) at the base's sample times, using the base's align.
	var comp := _Composite.new(rig, ba, pa)
	var need := PackedInt32Array()
	for p: String in PTS:
		need.append(rig.bone(p))
	var clos := rig.closure(need)
	var wp := []
	var A: Array = od.A
	for k in bs.n:
		var tt := minf(bs.times[k], pa.length)
		var g := comp.globals(clos, bs.times[k], tt)
		var pv := PackedVector3Array()
		for p: String in PTS:
			pv.append((g[rig.bone(p)] as Transform3D).origin + (A[k] as Vector3))
		wp.append(pv)
	var fake := _Samples.new()
	fake.n = bs.n
	fake.times = bs.times
	var cont := _contacts(fake, wp, od.anchor)
	rep["composite_hand_contacts"] = cont.hands
	var lost := []
	var base_hands: Array = (base_rec.get("contacts", {}) as Dictionary).get("hands", [])
	for side in ["l", "r"]:
		var had := base_hands.filter(func(c): return c.hand == side and c.supporting).size()
		var has := (cont.hands as Array).filter(func(c): return c.hand == side and c.supporting).size()
		if had > 0 and has == 0:
			lost.append(side)
	rep["supporting_hands_lost"] = lost
	var dmax := {"l": 0.0, "r": 0.0}
	for k in bs.n:
		var bp: PackedVector3Array = bs.pts[k]
		dmax.l = maxf(dmax.l, ((wp[k][I_LP] as Vector3) - (bp[I_LP] + (A[k] as Vector3))).length())
		dmax.r = maxf(dmax.r, ((wp[k][I_RP] as Vector3) - (bp[I_RP] + (A[k] as Vector3))).length())
	rep["palm_offset_max"] = dmax
	return rep


# =================================================================================================
# Rig evaluation (adapted from tools/anim_graph/measure_clips.gd): skeleton-space bone poses straight
# from the clip's tracks (rest where a channel is not keyed). Nothing is written to the Skeleton3D.
# =================================================================================================

class _Rig:
	var sk: Skeleton3D
	var names := PackedStringArray()
	var parents := PackedInt32Array()
	var rest: Array[Transform3D] = []
	var depth := PackedInt32Array()
	var _index := {}

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

	func bone(n: String) -> int:
		return _index.get(n, -1)

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
	var keyed := {}

	func _init(p_rig: _Rig, p_a: Animation) -> void:
		rig = p_rig
		a = p_a
		for t in a.get_track_count():
			var slot := -1
			match a.track_get_type(t):
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

	func globals(bones: PackedInt32Array, t: float) -> Dictionary:
		var g := {}
		for b in bones:
			var p := rig.parents[b]
			g[b] = (g[p] as Transform3D) * local(b, t) if p >= 0 else local(b, t)
		return g


## Base clip with a partial clip's keyed bones replaced (a full-weight partial layer).
class _Composite:
	var base: _Eval
	var part: _Eval

	func _init(rig: _Rig, ba: Animation, pa: Animation) -> void:
		base = _Eval.new(rig, ba)
		part = _Eval.new(rig, pa)

	func globals(bones: PackedInt32Array, tb: float, tp: float) -> Dictionary:
		var g := {}
		for b in bones:
			var p := base.rig.parents[b]
			var l: Transform3D = part.local(b, tp) if part.keyed.has(b) else base.local(b, tb)
			g[b] = (g[p] as Transform3D) * l if p >= 0 else l
		return g


# =================================================================================================
# JSON
# =================================================================================================

static func _rel(path: String) -> String:
	return path.trim_prefix("res://")


## Deterministic JSON: sorted keys, one-space indent, floats with at most 4 decimals, arrays of
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
	var s := "%.4f" % x
	if "." in s:
		s = s.rstrip("0").rstrip(".")
	if s == "-0":
		s = "0"
	return s
