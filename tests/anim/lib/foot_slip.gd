class_name FootSlip
extends RefCounted
## Planted-foot slip on the real level (plan section 10: test_locomotion_feet, and the old-tree
## baseline tests/anim/baselines/footslip_old.json captured by WPT).
##
## Method
##   - The player is driven with Input.action_press (walk / run / crouch / sprint x directions),
##     on flat open ground, facing so that the motion runs along a corridor checked free of
##     colliders.
##   - After SETTLE_S the heel and ball of both feet (l_heel, l_ball, r_heel, r_ball) are sampled
##     at every pose update, inside Skeleton3D.skeleton_updated (the final, post-modifier pose;
##     P13), together with the body velocity and the frame's process delta (the time the tree
##     advanced; true for the old IDLE-mode tree and the plan's MANUAL tree advanced in _process).
##   - Foot world velocity between two updates = body velocity + (change of the foot's offset
##     from the body, in world axes) / process delta. This is the continuous-time slip: it does
##     not depend on how render frames interleave with the 120 Hz physics steps (with
##     --fixed-fps 120 it equals the plain world-space finite difference; in real time the
##     finite difference would add frame-timing jitter, because the body moves only on physics
##     steps).
##   - A point is planted while its world height is within PLANTED_TOL of its minimum over the
##     window (method of GA/vmm/bl/an.py, in world space); a slip sample is its horizontal
##     speed over an interval where it is planted at both ends.
##   - Result: median (the section 10 metric; the plan gates it at 0.15 m/s, which perfect
##     playback cannot meet for several cases: see "Ideal-playback floor"), p90, mean, sample
##     count, planted fraction, per-point medians, the body's mean horizontal speed, and how
##     many pose updates fell in each physics frame (stepping: "fixed" when always one).
##     Standing still it reads 0.006 m/s; that is the floor only while not moving.
##
## Protocol (use measure(), not run_case(), for anything that is compared or gated)
##   A tree's steady gait depends on its history: the old tree's sync=false blend spaces freeze
##   unweighted clips, so the relative phase of the blended clips (and with it the slip) is
##   whatever the previous motion left behind. Running cases back to back made every median
##   depend on the case before it (musket run/WA 0.27 or 1.31 m/s, sprint/WD 2.1-4.6 m/s).
##   measure() therefore starts every repeat from a freshly loaded level (fresh_player()):
##     repeat 0      straight into the case                       -> fresh_mps
##     repeat k > 0  a fixed pre-roll history prerolls(c)[k - 1] first: the case's mode in a
##                   neighbouring direction, the case itself then a stop, or the next mode;
##                   each advances some of the case's clips and not others, so the case
##                   starts with its clips at other relative phases
##   and reports the median of the repeat medians (median_mps, the gated value) with the spread
##   (min_mps / max_mps). Nothing depends on what ran before, so results are order-independent
##   and, with --fixed-fps 120, bit-reproducible.
##   run_case() is the single-run primitive; its result depends on the player's current state.
##   Inside a test suite pass opts.ctx = the AnimTestContext: every wait then goes through ctx,
##   so a suite the runner abandoned (TIMEOUT) stops driving input and reloading the level.
##
## Ideal-playback floor (ideal_floor(); what result() reads for PERFECT playback)
##   The authored clips' own planted-foot speed varies within a stride, so even perfect,
##   graph-faithful playback at constant body speed does not read 0 while moving. ideal_floor()
##   samples the case's direction bank with PoseOracle in graph semantics (slerp chain, section
##   6.5), at the section 6.6 rate (ratio = speed / sum w_i v_i, clamped to [0.55, 1.75]; every
##   clip at the same normalized phase), with the body moving at constant speed in the case's
##   direction, and feeds the samples through the same result() code, for IDEAL_PHASES start
##   phases of the MEASURE_S window. Single-clip cases read 0.04-0.22 m/s (run W / A / D / S
##   0.15-0.17 at bow and pistol speed, sprint W 0.22, crouch D 0.19-0.20), so the plan's
##   absolute 0.15 m/s gate cannot be met there by any tree. For those cases it is a true floor:
##   lib/selftest/st_footslip_ideal plays each one with a perfect one-clip tree in game and
##   FootSlip reads the same (within 0.02). Diagonal cases blend two clips; graph-faithful
##   playback reads 0.09 (walk) to 0.35-0.70 (run, sprint) there, and a tree that blends
##   differently (the old tree put the strafe clips at 45 deg) can read less, so for those
##   ideal_mps is the graph-faithful reference, not a floor. Compare with ideal_mps rather than
##   an absolute number (the gate itself is an orchestrator decision; see tests/anim/README.md).
##   Clip speeds v_i: animations/actor_b_clip_metrics.json (WP2) when present, else clip_travel()
##   (the same method: GA/vmm/bl/an.py method A).

const POINTS := ["l_heel", "l_ball", "r_heel", "r_ball"]
const PLANTED_TOL := 0.02
const IDLE_S := 0.5
const SETTLE_S := 1.0
const MEASURE_S := 2.0
## run_case start_idle: longest extra wait for a settled stand before the key press.
const START_IDLE_MAX_S := 3.0
## start_floor(): the graph's idle -> start fade (transitions idle_to_start, record 0x0003f290) and
## the idle clip phases it is sampled from (median, min and max over them; as many as the steady
## floor's IDEAL_PHASES: the phase the key press finds the idle at is arbitrary).
const START_FADE_S := 0.2
const START_IDLE_PHASES := [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]
## stop_floor(): the graph's move -> stop fade (transitions move_to_stop, records 0x0002a8b0 /
## 0x00025260, 0.5 s), the stop callback's ramp (real time by phase 0.2) and the loop's rate floor
## while fading out of MOVE (tuning rate_floor_decel, plan 6.6).
const STOP_FADE_S := 0.5
const STOP_RAMP_PHASE := 0.2
const RATE_FLOOR_DECEL := 0.6
## run_case stop_window: longest wait for the lower body to reach IDLE after the key release.
const STOP_MAX_S := 5.0
const MAIN_SCENE := "res://scenes/main.tscn"
## Physics frames after a (re)load before anything else, and after switch_weapon() (the equip
## and the old tree's 0.25 s weapon cross-fade are over by then).
const SPAWN_FRAMES := 60
const EQUIP_FRAMES := 150
## Repeats per measure(): 1 fresh + one per pre-roll (prerolls() has 4).
const REPEATS := 5
## Neighbouring direction keys (45 deg either side) and the mode used by the 4th pre-roll.
const NEIGHBOURS := {
	"W": ["WA", "WD"], "A": ["WA", "SA"], "S": ["SA", "SD"], "D": ["WD", "SD"],
	"WA": ["W", "A"], "WD": ["W", "D"], "SA": ["S", "A"], "SD": ["S", "D"], "none": ["W", "S"],
}
const OTHER_MODE := {"walk": "run", "run": "walk", "sprint": "run", "crouch": "walk"}
const DIRS := {
	"W": ["move_forward"], "A": ["move_left"], "S": ["move_back"], "D": ["move_right"],
	"WA": ["move_forward", "move_left"], "WD": ["move_forward", "move_right"],
	"SA": ["move_back", "move_left"], "SD": ["move_back", "move_right"], "none": [],
}
## Plan section 10: W / A / S / D / W+A for walk / run / crouch; W / W+A / W+D for sprint.
const MODES := {
	"walk": ["W", "A", "S", "D", "WA"],
	"run": ["W", "A", "S", "D", "WA"],
	"crouch": ["W", "A", "S", "D", "WA"],
	"sprint": ["W", "WA", "WD"],
}
## World direction of travel for every case (north, down the range lane).
const TRAVEL := Vector3(0, 0, -1)
## Candidate start points (x, z); the first with a clear corridor is used.
const STARTS := [Vector2(7, -22), Vector2(-7, -22), Vector2(7, -60), Vector2(-7, -60), Vector2(0, 6),
		Vector2(11, -22), Vector2(-11, -22)]

## Ideal-playback floor (see above).
const GRAPH_JSON := "res://animations/actor_b_graph.json"
const METRICS_JSON := "res://animations/actor_b_clip_metrics.json"
## Travel direction of each key in degrees, + = left (graph move_dir_deg, section 6.5).
const DIR_DEG := {"W": 0.0, "A": 90.0, "S": 180.0, "D": -90.0, "WA": 45.0, "WD": -45.0, "SA": 135.0,
		"SD": -135.0}
## Fallback clip stems when the graph JSON is missing (actor_b-p-<stem>-<fw|fw-lt|...>).
const MODE_STEM := {"walk": "walk", "run": "run", "sprint": "sprint", "crouch": "crouch-walk"}
## Section 6.6: the effective ratio speed / sum w_i v_i is clamped to this range.
const RATIO_MIN := 0.55
const RATIO_MAX := 1.75
## Start phases of the ideal MEASURE_S window (evenly over one cycle); ideal_mps is their median.
const IDEAL_PHASES := 8
## clip_travel(): sample rate and minimum planted-run length of GA/vmm/bl/an.py method A on the
## 15 Hz dumps the plan's clip speeds (section 2, D8) come from.
const TRAVEL_HZ := 15.0
const TRAVEL_MIN_RUN := 3

static var _roles: Variant = null
static var _chain_tracks := {}    ## animation instance id -> its foot-chain tracks (_chain_clip())
static var _metrics: Variant = null
static var _travel := {}


## Pre-roll histories of measure() repeats 1..4 for case c: [{mode, dir, s}], s = seconds of
## held input after the usual IDLE_S. The durations are not multiples of each other, so the
## clips stop at unrelated phases.
static func prerolls(c: Dictionary) -> Array:
	var d: String = c.get("dir", "none")
	var nb: Array = NEIGHBOURS.get(d, NEIGHBOURS.none)
	var m: String = c.get("mode", "run")
	return [
		{"mode": m, "dir": nb[0], "s": 0.7},
		{"mode": m, "dir": nb[1], "s": 1.3},
		{"mode": m, "dir": d if d != "none" else "W", "s": 1.1},
		{"mode": OTHER_MODE.get(m, "walk"), "dir": d if d != "none" else "S", "s": 0.9},
	]


## [{key: "run/WA", mode, dir, actions}] in the §10 order.
static func cases() -> Array:
	var out := []
	for m in MODES:
		for d in MODES[m]:
			out.append({"key": "%s/%s" % [m, d], "mode": m, "dir": d, "actions": DIRS[d]})
	return out


var sk: Skeleton3D
var player: Node
## One entry per pose update: {f: physics frame, dt: process delta, rel: [Vector3 x 4] foot offset
## from the skeleton origin in world axes, y: [float x 4] world heights, v: body velocity}.
var samples: Array = []
var _idx := PackedInt32Array()


## p_sk may be null for a probe that is only fed samples (ideal_floor()).
func _init(p_player: Node, p_sk: Skeleton3D) -> void:
	player = p_player
	sk = p_sk
	if sk:
		for n in POINTS:
			_idx.append(sk.find_bone(n))


func start() -> void:
	samples.clear()
	if not sk.skeleton_updated.is_connected(_on_updated):
		sk.skeleton_updated.connect(_on_updated)


func stop() -> void:
	if sk.skeleton_updated.is_connected(_on_updated):
		sk.skeleton_updated.disconnect(_on_updated)


func _on_updated() -> void:
	var xf := sk.global_transform
	var rel := []
	var y := PackedFloat32Array()
	for i in _idx:
		var o := sk.get_bone_global_pose(i).origin
		rel.append(xf.basis * o)
		y.append((xf * o).y)
	samples.append({"f": Engine.get_physics_frames(), "dt": sk.get_process_delta_time(), "rel": rel, "y": y,
			"v": player.velocity})


## Slip statistics of the collected samples.
func result() -> Dictionary:
	var out := {"n": 0, "median_mps": NAN, "p90_mps": NAN, "mean_mps": NAN, "planted_frac": 0.0,
			"points": {}, "updates": samples.size(), "body_speed_mps": 0.0, "stepping": ""}
	if samples.size() < 3:
		return out
	var per_frame := {}
	var body := 0.0
	for smp in samples:
		per_frame[smp.f] = per_frame.get(smp.f, 0) + 1
		body += Vector2(smp.v.x, smp.v.z).length()
	out.body_speed_mps = _round(body / samples.size())
	var multi := 0
	for f in per_frame:
		if per_frame[f] != 1:
			multi += 1
	out.stepping = "fixed" if multi == 0 and per_frame.size() == samples.size() else "realtime"
	out.frames_with_multiple_updates = multi
	var all := PackedFloat32Array()
	var planted_count := 0
	for pt in POINTS.size():
		var ymin := INF
		for smp in samples:
			ymin = minf(ymin, smp.y[pt])
		var sp := PackedFloat32Array()
		for k in samples.size():
			var cur: Dictionary = samples[k]
			var planted: bool = cur.y[pt] < ymin + PLANTED_TOL
			if planted:
				planted_count += 1
			if k == 0 or not planted:
				continue
			var prev: Dictionary = samples[k - 1]
			if prev.y[pt] >= ymin + PLANTED_TOL or cur.dt <= 0.0:
				continue
			var vel: Vector3 = cur.v + (cur.rel[pt] - prev.rel[pt]) / cur.dt
			sp.append(Vector2(vel.x, vel.z).length())
		out.points[POINTS[pt]] = {"n": sp.size(), "median_mps": _round(_percentile(sp, 0.5))}
		all.append_array(sp)
	out.n = all.size()
	out.median_mps = _round(_percentile(all, 0.5))
	out.p90_mps = _round(_percentile(all, 0.9))
	var s := 0.0
	for x in all:
		s += x
	out.mean_mps = _round(s / maxi(1, all.size()))
	out.planted_frac = _round(float(planted_count) / (samples.size() * POINTS.size()))
	return out


## Order-independent measurement of case c (see "Protocol" above). Every repeat reloads the
## level (so the current scene is replaced; nothing else may hold on to the old Player).
## opts: weapon ("" = the level's default), repeats (REPEATS), settle_s, measure_s, scene,
## ctx (the suite's AnimTestContext; waits go through it), ideal (true: also compute
## ideal_floor() for the case and merge it as ideal_*; see ideal_fields()).
## Returns {key, weapon, median_mps (median of the repeat medians), fresh_mps (repeat 0),
## min_mps, max_mps, spread_mps, p90_mps (median of the repeat p90s), mean_mps, n (all
## samples), planted_frac, body_speed_mps, stepping, crouched, sprinting, walking, speed_mult,
## repeats: [{preroll, median_mps, p90_mps, n}]} or {key, error}.
static func measure(tree: SceneTree, c: Dictionary, opts := {}) -> Dictionary:
	var count := maxi(1, int(opts.get("repeats", REPEATS)))
	var weapon: String = opts.get("weapon", "")
	var ctx: Object = opts.get("ctx", null)
	var runs: Array = []
	var p: Node = null
	for k in count:
		p = await fresh_player(tree, weapon, opts.get("scene", MAIN_SCENE), ctx)
		if p == null:
			return {"key": c.key, "error": "level or player failed to load"}
		if weapon != "" and String(p.get("weapon_key")) != weapon:
			return {"key": c.key, "error": "switch_weapon(%s) did not take" % weapon}
		var label := "none"
		if k > 0:
			var pres := prerolls(c)
			var pre: Dictionary = pres[(k - 1) % pres.size()]
			label = "%s/%s %.1fs" % [pre.mode, pre.dir, pre.s]
			var pc := {"key": "preroll " + label, "mode": pre.mode, "dir": pre.dir, "actions": DIRS[pre.dir]}
			var pr := await run_case(tree, p, pc, {"settle_s": pre.s, "measure_s": 0.0, "probe": false, "ctx": ctx})
			if pr.has("error"):
				return {"key": c.key, "error": "pre-roll %s: %s" % [label, pr.error]}
		var r := await run_case(tree, p, c, opts)
		if r.has("error"):
			return r
		r["preroll"] = label
		runs.append(r)
	var out := _aggregate(c, runs, p)
	if opts.get("ideal", false):
		out.merge(ideal_fields(ideal_floor(oracle_for(p), c, case_speed(p, c), {"weapon": out.get("weapon", weapon),
				"measure_s": opts.get("measure_s", MEASURE_S)})))
		if Callable(opts.get("start_window", Callable())).is_valid():
			# The gate's reference follows the player's start rate (PlayerAnim override_start_rate_boost,
			# on by default pending the owner's decision); the graph-rate floor is reported next to it.
			var boost := start_rate_boost(p)
			var sf := start_floor(oracle_for(p), c, case_speed(p, c), {"weapon": out.get("weapon", weapon), "rate_boost": boost})
			out["start_floor_basis"] = "inferred body_profile body speed, %s" % ("boosted start rate (override_start_rate_boost)" if boost else "graph align rate")
			if sf.has("start_floor_mps"):
				out["start_floor_mps"] = sf.start_floor_mps
				out["start_floor_min_mps"] = sf.min_mps
				out["start_floor_max_mps"] = sf.max_mps
				out["start_floor"] = sf
			else:
				out["start_floor_error"] = sf.get("error", sf.get("skipped", "?"))
			var sg := sf
			if boost:
				sg = start_floor(oracle_for(p), c, case_speed(p, c), {"weapon": out.get("weapon", weapon), "rate_boost": false})
			if sg.has("start_floor_mps"):
				out["start_floor_graph_mps"] = sg.start_floor_mps
				out["start_floor_graph_min_mps"] = sg.min_mps
				out["start_floor_graph_max_mps"] = sg.max_mps
		if Callable(opts.get("stop_window", Callable())).is_valid():
			var decel := float(p.get("ground_decel")) if p.get("ground_decel") != null else 18.0
			for body: String in ["decel", "root"]:
				var tf := stop_floor(oracle_for(p), c, case_speed(p, c), {"weapon": out.get("weapon", weapon), "body": body, "decel": decel})
				var pre := "stop_floor" if body == "decel" else "stop_root_floor"
				if tf.has("stop_floor_mps"):
					out[pre + "_mps"] = tf.stop_floor_mps
					out[pre + "_min_mps"] = tf.min_mps
					out[pre + "_max_mps"] = tf.max_mps
					out[pre + "_p90_mps"] = tf.p90_mps
					out[pre] = tf
				else:
					out[pre + "_error"] = tf.get("error", tf.get("skipped", "?"))
	return out


## True when the player's start plays the boosted rate (LocoBrain.start_rate_boost; PlayerAnim
## override_start_rate_boost), the default.
static func start_rate_boost(p: Node) -> bool:
	var a: Variant = p.get("anim") if p else null
	if a == null or not a.has_method("is_ready") or not a.is_ready() or a.get("loco") == null:
		return true
	return bool(a.loco.start_rate_boost)


## Loads (or reloads) the level and returns its Player after SPAWN_FRAMES, with the mouse left
## alone, input released and `weapon` equipped for EQUIP_FRAMES; null on failure.
## ctx: optional AnimTestContext (waits go through it).
static func fresh_player(tree: SceneTree, weapon := "", scene := MAIN_SCENE, ctx: Object = null) -> Node:
	_release_all()
	if tree.change_scene_to_file(scene) != OK:
		return null
	await _idle(tree, 2, ctx)
	var p: Node = tree.current_scene.get_node_or_null("Player") if tree.current_scene else null
	if p == null:
		return null
	if "ignore_mouse_capture" in p:
		p.ignore_mouse_capture = true
	await _frames(tree, SPAWN_FRAMES, ctx)
	if weapon != "" and p.has_method("switch_weapon"):
		p.switch_weapon(weapon)
	await _frames(tree, EQUIP_FRAMES, ctx)
	# WP7: the graph weapon switch (holster, finish, grab, then the draw) can outlast EQUIP_FRAMES.
	var w8 := 0
	while p.has_method("is_switching") and (bool(p.is_switching()) or (p.get("weapon") != null and p.weapon.is_equipping())) \
			and w8 < 480:
		await _frames(tree, 1, ctx)
		w8 += 1
	return p


static func _aggregate(c: Dictionary, runs: Array, p: Node) -> Dictionary:
	var med := PackedFloat64Array()
	var p90 := PackedFloat64Array()
	var reps := []
	var n := 0
	var mean := 0.0
	var planted := 0.0
	var body := 0.0
	var fixed := true
	var flags_differ := false
	for r: Dictionary in runs:
		med.append(r.median_mps)
		p90.append(r.p90_mps)
		n += int(r.n)
		mean += float(r.mean_mps) * int(r.n)
		planted += float(r.planted_frac)
		body += float(r.body_speed_mps)
		fixed = fixed and r.stepping == "fixed"
		for f in ["crouched", "sprinting", "walking"]:
			flags_differ = flags_differ or r[f] != runs[0][f]
		var rep := {"preroll": r.preroll, "median_mps": r.median_mps, "p90_mps": r.p90_mps, "n": int(r.n),
				"settled_s": r.get("settled_s", SETTLE_S)}
		if r.has("start_window"):
			var sw: Dictionary = r.start_window
			rep["start"] = {"seen": sw.get("seen", false), "median_mps": sw.get("median_mps", NAN), "p90_mps": sw.get("p90_mps", NAN),
					"n": int(sw.get("n", 0)), "start_s": sw.get("start_s", 0.0)}
		if r.has("stop_window"):
			var tw: Dictionary = r.stop_window
			rep["stop"] = {"done": tw.get("done", false), "median_mps": tw.get("median_mps", NAN), "p90_mps": tw.get("p90_mps", NAN),
					"n": int(tw.get("n", 0)), "stop_s": tw.get("stop_s", 0.0), "travel_m": tw.get("travel_m", 0.0)}
		reps.append(rep)
	var sorted := med.duplicate()
	sorted.sort()
	var out := {
		"key": c.key,
		"median_mps": _round(_percentile(med, 0.5)),
		"fresh_mps": runs[0].median_mps,
		"min_mps": sorted[0],
		"max_mps": sorted[-1],
		"spread_mps": _round(sorted[-1] - sorted[0]),
		"p90_mps": _round(_percentile(p90, 0.5)),
		"mean_mps": _round(mean / maxi(1, n)),
		"n": n,
		"planted_frac": _round(planted / runs.size()),
		"body_speed_mps": _round(body / runs.size()),
		"stepping": "fixed" if fixed else "realtime",
		"crouched": runs[0].crouched,
		"sprinting": runs[0].sprinting,
		"walking": runs[0].walking,
		"repeats": reps,
	}
	if flags_differ:
		out["warning"] = "crouched / sprinting / walking differed between repeats"
	# Start windows (run_case start_window): median over the repeats that played a start.
	var smed := PackedFloat64Array()
	var sdur := PackedFloat64Array()
	var sp90 := PackedFloat64Array()
	for rp: Dictionary in reps:
		var st: Dictionary = rp.get("start", {})
		if bool(st.get("seen", false)) and int(st.get("n", 0)) > 0 and not is_nan(float(st.get("median_mps", NAN))):
			smed.append(float(st.median_mps))
			sp90.append(float(st.p90_mps))
			sdur.append(float(st.start_s))
	if not smed.is_empty():
		var ss := smed.duplicate()
		ss.sort()
		out["start_median_mps"] = _round(_percentile(smed, 0.5))
		out["start_min_mps"] = ss[0]
		out["start_max_mps"] = ss[-1]
		out["start_p90_mps"] = _round(_percentile(sp90, 0.5))
		out["start_s"] = _round(_percentile(sdur, 0.5))
		out["start_repeats"] = smed.size()
	# Stop windows (run_case stop_window): median over the repeats whose stop reached IDLE.
	var tmed := PackedFloat64Array()
	var tp90 := PackedFloat64Array()
	var tdur := PackedFloat64Array()
	var ttrav := PackedFloat64Array()
	for rp: Dictionary in reps:
		var tw: Dictionary = rp.get("stop", {})
		if bool(tw.get("done", false)) and int(tw.get("n", 0)) > 0 and not is_nan(float(tw.get("median_mps", NAN))):
			tmed.append(float(tw.median_mps))
			tp90.append(float(tw.p90_mps))
			tdur.append(float(tw.stop_s))
			ttrav.append(float(tw.travel_m))
	if not tmed.is_empty():
		var ts := tmed.duplicate()
		ts.sort()
		out["stop_median_mps"] = _round(_percentile(tmed, 0.5))
		out["stop_min_mps"] = ts[0]
		out["stop_max_mps"] = ts[-1]
		out["stop_p90_mps"] = _round(_percentile(tp90, 0.5))
		out["stop_s"] = _round(_percentile(tdur, 0.5))
		out["stop_travel_m"] = _round(_percentile(ttrav, 0.5))
		out["stop_repeats"] = tmed.size()
	var w: Variant = p.get("weapon") if p else null
	if w != null and w.has_method("speed_mult"):
		out["weapon"] = String(p.get("weapon_key"))
		out["speed_mult"] = _round(w.speed_mult())
	return out


static func _release_all() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)


## One run of case c from the player's CURRENT state (so the result depends on what ran
## before; measure() wraps it in the order-independent protocol). Returns result() plus
## {key, start: [x, z], yaw_deg, crouched, sprinting, walking} or {error: msg}.
## opts: settle_s, measure_s, probe (false = only drive the input, e.g. for a pre-roll), ctx;
## settle_until (optional Callable(player) -> bool, WP7): after settle_s the input stays held until
## it returns true, for at most settle_max_s (default 4 s) more (the graph's start clips play
## before the steady gait); the result's settled_s is the settle actually used;
## start_window (optional Callable(player) -> bool, WP7: true while the player is in its start
## phase): a second probe records from the key press until that phase has been seen and is over
## (or the settle ends), and the result gets start_window: result() of it plus {start_s, seen};
## start_idle (optional Callable(player) -> bool): before the key press, wait until it holds (a
## settled stand), at most START_IDLE_MAX_S after IDLE_S;
## stop_window (optional Callable(player) -> bool, WP7 review: true until the player's lower body
## has stopped, e.g. reached IDLE): after the measure window a third probe records from the key
## release until it turns false (at most STOP_MAX_S), and the result gets stop_window: result() of
## it plus {stop_s, done, travel_m (the body's travel from the release)}.
static func run_case(tree: SceneTree, p: Node, c: Dictionary, opts := {}) -> Dictionary:
	var ctx: Object = opts.get("ctx", null)
	var settle: float = opts.get("settle_s", SETTLE_S)
	var measure_s: float = opts.get("measure_s", MEASURE_S)
	var use_probe: bool = opts.get("probe", true)
	var until: Callable = opts.get("settle_until", Callable())
	var settle_max: float = float(opts.get("settle_max_s", 4.0)) if until.is_valid() else 0.0
	var hz := float(Engine.physics_ticks_per_second)
	var mode: String = c.mode
	_release_all()
	await _set_crouch(tree, p, mode == "crouch", ctx)
	if bool(p.is_crouching) != (mode == "crouch"):
		return {"key": c.key, "error": "could not set crouch=%s" % (mode == "crouch")}
	# Local input vector as Input.get_vector("move_left", "move_right", "move_forward", "move_back").
	var iv := Vector2.ZERO
	for a: String in c.actions:
		iv += {"move_forward": Vector2(0, -1), "move_back": Vector2(0, 1), "move_left": Vector2(-1, 0),
				"move_right": Vector2(1, 0)}[a]
	iv = iv.normalized()
	# yaw such that Basis(UP, yaw) * (iv.x, 0, iv.y) points along TRAVEL.
	var yaw := _heading(TRAVEL) - _heading(Vector3(iv.x, 0, iv.y))
	var dist := (IDLE_S + settle + measure_s) * 6.0 + 3.0
	if until.is_valid():
		dist = maxf(dist, (IDLE_S + settle + settle_max + measure_s) * maxf(case_speed(p, c), 1.0) * 1.1 + 3.0)
	var start = _clear_start(p, dist)
	if start == null:
		return {"key": c.key, "error": "no clear corridor of %.0f m found" % dist}
	p.global_position = Vector3(start.x, 0.05, start.y)
	p.velocity = Vector3.ZERO
	p.yaw = yaw
	p.pitch = 0.0
	await _frames(tree, int(IDLE_S * hz), ctx)
	# Start window: the start is measured from a settled stand (the teleport's yaw change plays an
	# idle turn first; start_idle: Callable(player) -> bool, at most START_IDLE_MAX_S more).
	var idle_ok: Callable = opts.get("start_idle", Callable())
	if idle_ok.is_valid():
		var w8 := 0
		while not bool(idle_ok.call(p)) and w8 < int(START_IDLE_MAX_S * hz):
			await _frames(tree, 1, ctx)
			w8 += 1
	if mode == "walk":
		Input.action_press("walk")
	elif mode == "sprint":
		Input.action_press("sprint")
	var in_start: Callable = opts.get("start_window", Callable())
	var sprobe: FootSlip = null
	if in_start.is_valid() and use_probe:
		sprobe = FootSlip.new(p, p.skeleton)
		sprobe.start()
	for a: String in c.actions:
		Input.action_press(a)
	var seen := false
	var start_f := -1
	var n_settle := int(settle * hz)
	if sprobe == null:
		await _frames(tree, n_settle, ctx)
	else:
		for i in n_settle:
			await _frames(tree, 1, ctx)
			if start_f < 0:
				var now := bool(in_start.call(p))
				seen = seen or now
				if seen and not now:
					start_f = i + 1
					sprobe.stop()
	var settled := settle
	if until.is_valid():
		var extra := 0
		while not bool(until.call(p)) and extra < int(settle_max * hz):
			await _frames(tree, 1, ctx)
			extra += 1
			if sprobe != null and start_f < 0:
				var now := bool(in_start.call(p))
				seen = seen or now
				if seen and not now:
					start_f = n_settle + extra
					sprobe.stop()
		settled += extra / hz
	var start_r := {}
	if sprobe != null:
		sprobe.stop()
		start_r = sprobe.result()
		start_r["seen"] = seen
		start_r["start_s"] = _round((start_f if start_f >= 0 else n_settle) / hz)
	var probe := FootSlip.new(p, p.skeleton)
	if use_probe:
		probe.start()
	await _frames(tree, int(measure_s * hz), ctx)
	probe.stop()
	var flags := {"crouched": bool(p.is_crouching), "sprinting": bool(p.is_sprinting), "walking": bool(p.is_walking)}
	var stopping: Callable = opts.get("stop_window", Callable())
	var stop_r := {}
	if stopping.is_valid() and use_probe:
		var tprobe := FootSlip.new(p, p.skeleton)
		tprobe.start()
		var at: Vector3 = p.global_position
		_release_all()
		var n_stop := 0
		while n_stop < int(STOP_MAX_S * hz):
			await _frames(tree, 1, ctx)
			n_stop += 1
			if not bool(stopping.call(p)):
				break
		tprobe.stop()
		stop_r = tprobe.result()
		stop_r["stop_s"] = _round(n_stop / hz)
		stop_r["done"] = not bool(stopping.call(p))
		stop_r["travel_m"] = _round(Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length())
	else:
		_release_all()
	var r := probe.result()
	r.merge({"key": c.key, "start": [start.x, start.y], "yaw_deg": _round(rad_to_deg(yaw)), "settled_s": _round(settled)}.merged(flags))
	if sprobe != null:
		r["start_window"] = start_r
	if not stop_r.is_empty():
		r["stop_window"] = stop_r
	await _frames(tree, 10, ctx)
	return r


static func _set_crouch(tree: SceneTree, p: Node, want: bool, ctx: Object = null) -> void:
	for i in 3:
		if bool(p.is_crouching) == want:
			return
		Input.action_press("crouch")
		await _frames(tree, 2, ctx)
		Input.action_release("crouch")
		await _frames(tree, 30, ctx)


## Player yaw convention: a vector at yaw y is (-sin y, 0, -cos y).
static func _heading(v: Vector3) -> float:
	return atan2(-v.x, -v.z)


## First STARTS entry whose corridor (1.4 m wide, 0.3-1.8 m high, `dist` long along TRAVEL)
## overlaps no collider other than the player; null if none.
static func _clear_start(p: Node, dist: float) -> Variant:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.5, dist)
	for s: Vector2 in STARTS:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		var center := Vector3(s.x, 1.05, s.y) + TRAVEL * (dist * 0.5 - 1.0)
		q.transform = Transform3D(Basis.looking_at(TRAVEL, Vector3.UP), center)
		q.exclude = [p.get_rid()]
		q.collide_with_areas = false
		if space.intersect_shape(q, 4).is_empty():
			return s
	return null


## n physics frames; through ctx.frames() when a suite's context is given (it parks the
## coroutine for good once the runner abandoned the suite).
static func _frames(tree: SceneTree, n: int, ctx: Object = null) -> void:
	if ctx:
		await ctx.frames(n)
		return
	for i in n:
		await tree.physics_frame


static func _idle(tree: SceneTree, n: int, ctx: Object = null) -> void:
	if ctx:
		await ctx.idle_frames(n)
		return
	for i in n:
		await tree.process_frame


# --- ideal-playback floor ------------------------------------------------------------------

## Target body speed of case c on player p, as player.gd computes it: the mode's speed times
## weapon.speed_mult() (sprint without it); not aiming, so aim_walk_speed does not apply. 0 for
## the standing-still control.
static func case_speed(p: Node, c: Dictionary) -> float:
	if DIRS.get(c.get("dir", "none"), []).is_empty():
		return 0.0
	var m: String = c.get("mode", "run")
	var s := float(p.get({"walk": "walk_speed", "run": "run_speed", "sprint": "sprint_speed",
			"crouch": "crouch_speed"}.get(m, "run_speed")))
	var w: Variant = p.get("weapon")
	if m != "sprint" and w != null and w.has_method("speed_mult"):
		s *= float(w.speed_mult())
	return s


## PoseOracle over the player's own skeleton and AnimationPlayer (rest = null-add in game too).
static func oracle_for(p: Node) -> PoseOracle:
	var s: Skeleton3D = p.get("skeleton")
	if s == null:
		return null
	var aps := s.get_parent().find_children("*", "AnimationPlayer", true, false)
	return PoseOracle.new(s, aps[0]) if not aps.is_empty() else null


## The section 6.5 direction bank that plays case c in steady state: hemisphere fw iff
## |deg| <= 90; fw x = deg, bw x = wrap180(deg + 180), clamped to [-90, 90]; clips [center, neg
## (-90), pos (+90)] = fw: [fw, fw_rt, fw_lt], bw: [bw, bw_lt, bw_rt], from the graph roles of
## `weapon` (actor_b_graph.json; "" = musket) or the actor_b-p-<mode>-* names without it;
## weights = the lerp-scale / BlendSpace1D weights at x.
## {deg, hemi, x, clips, weights, source}.
static func case_bank(c: Dictionary, weapon := "") -> Dictionary:
	var deg: float = DIR_DEG.get(c.get("dir", "W"), 0.0)
	var fw := absf(deg) <= 90.0
	var x := clampf(deg if fw else PoseOracle.angle_mod(deg + 180.0), -90.0, 90.0)
	var roles := ["fw", "fw_rt", "fw_lt"] if fw else ["bw", "bw_lt", "bw_rt"]
	var m: String = c.get("mode", "run")
	var w := weapon if weapon != "" else "musket"
	var table := _graph_roles()
	var clips := []
	var source := "graph roles (%s)" % GRAPH_JSON.get_file()
	for r: String in roles:
		var key := "%s/%s/%s" % [w, m, r]
		var role: Dictionary = table.get(key, {})
		if role.get("clip", null) is String and role.get("status", "") != "missing":
			clips.append(role.clip)
		else:
			clips.append("actor_b-p-%s-%s" % [MODE_STEM.get(m, m), r.replace("_", "-")])
			source = "clip names (no graph role %s)" % key
	var wn := PoseOracle.lerp_scale(-90.0, 0.0, 1.0, 0.0, x)
	var wp := PoseOracle.lerp_scale(0.0, 90.0, 0.0, 1.0, x)
	return {"deg": deg, "hemi": "fw" if fw else "bw", "x": x, "clips": clips, "weights": [1.0 - wn - wp, wn, wp],
			"source": source}


## Travel speed of a clip (m/s): travel.speed from animations/actor_b_clip_metrics.json (WP2)
## when present, else clip_travel(o, clip).speed.
static func clip_speed(o: PoseOracle, clip: String) -> float:
	var m := _clip_metrics()
	var t: Variant = m.get(clip, {}).get("travel", null) if m.get(clip, null) is Dictionary else null
	if t is Dictionary and t.has("speed"):
		return float(t.speed)
	return float(clip_travel(o, clip).get("speed", 0.0))


## Body travel of one looping clip in skeleton space (forward +Z, left +X), the method of
## GA/vmm/bl/an.py method A (plan 5.4): heel and ball sampled at TRAVEL_HZ over one cycle; a
## point is planted within PLANTED_TOL of its lowest height; per planted run of at least
## TRAVEL_MIN_RUN samples (cyclic), the horizontal foot velocity is the least-squares slope;
## body velocity = -(run-length-weighted mean foot velocity). Reproduces the plan's speeds
## (walk-fw 1.263, run-fw 3.344, run-bw 2.474, sprint-fw 4.244, crouch-walk-fw 1.637). The
## method is sensitive to the sample rate for sprint clips (sprint-fw 3.92-4.24 between 15 and
## 120 Hz), so the rates, and ideal_floor(), follow WP2's metrics file once it exists.
## {speed (m/s), heading_deg (+ = left), fwd, side, runs, sample_rate} (cached per clip name).
static func clip_travel(o: PoseOracle, clip: String) -> Dictionary:
	if _travel.has(clip):
		return _travel[clip]
	var a := o.animation(clip)
	if a == null:
		return {"error": "unknown clip"}
	var out := {}
	# A clip with no planted run of TRAVEL_MIN_RUN samples at 15 Hz (sprint-fw-rt: short
	# stances) is measured at 30, then 60 Hz (still >= TRAVEL_MIN_RUN samples per run).
	for sr: float in [TRAVEL_HZ, TRAVEL_HZ * 2.0, TRAVEL_HZ * 4.0]:
		out = _travel_at(o, a, sr)
		if out.runs > 0:
			break
	_travel[clip] = out
	return out


static func _travel_at(o: PoseOracle, a: Animation, sr: float) -> Dictionary:
	var n := maxi(2, roundi(a.length * sr))
	var dt := a.length / n
	var chains := _chains(o)
	var pos := []
	for k in n:
		pos.append(_points(o, o.clip(a, k * dt), chains))
	var sum_n := 0
	var fv := Vector2.ZERO
	var runs := 0
	for pt in POINTS.size():
		var ymin := INF
		for s: Array in pos:
			ymin = minf(ymin, s[pt].y)
		var planted := []
		for s: Array in pos:
			planted.append(s[pt].y < ymin + PLANTED_TOL)
		if not planted.has(false):
			continue
		var first: int = planted.find(false)
		var cur := PackedInt32Array()
		for j in n + 1:
			var k := (first + j) % n
			if j < n and planted[k]:
				cur.append(j)
				continue
			if cur.size() >= TRAVEL_MIN_RUN:
				var slope := _slope(cur, pos, first, n, pt, dt)
				fv += slope * cur.size()
				sum_n += cur.size()
				runs += 1
			cur = PackedInt32Array()
	var out := {"speed": 0.0, "heading_deg": 0.0, "fwd": 0.0, "side": 0.0, "runs": runs, "sample_rate": sr}
	if sum_n > 0:
		var body := -fv / sum_n  # (x = left, y = forward)
		out.speed = _round(body.length())
		out.heading_deg = snappedf(rad_to_deg(atan2(body.x, body.y)), 0.1)
		out.fwd = _round(body.y)
		out.side = _round(body.x)
	return out


## Planted-foot slip that result() reads for ideal, graph-faithful playback of case c at body
## speed `speed` (m/s): the case_bank() clips at one normalized phase u, blended by the graph's
## slerp chain (opts.semantics = "godot": the Godot BlendSpace1D's rest-relative blend
## instead), u advancing at the section 6.6 rate, the body moving at `speed` along the case
## direction; the MEASURE_S window at IDEAL_PHASES start phases over one cycle.
## opts: weapon, semantics ("graph"), hz (physics ticks per second), measure_s.
## {key, ideal_mps (median over start phases), min_mps, max_mps, p90_mps, planted_frac,
##  speed_mps, ratio, ratio_unclamped, cps, hemi, x, clips, weights, clip_speeds, semantics,
##  source, phases} or {key, error}; {key, skipped} for the standing-still control.
static func ideal_floor(o: PoseOracle, c: Dictionary, speed: float, opts := {}) -> Dictionary:
	var key: String = c.get("key", "?")
	if o == null:
		return {"key": key, "error": "no PoseOracle"}
	if speed <= 0.0 or DIRS.get(c.get("dir", "none"), []).is_empty():
		return {"key": key, "skipped": "standing still: no locomotion bank plays"}
	var hz := float(opts.get("hz", Engine.physics_ticks_per_second))
	var semantics: String = opts.get("semantics", "graph")
	var bank := case_bank(c, opts.get("weapon", ""))
	var anims: Array[Animation] = []
	var v := PackedFloat64Array()
	var sv := 0.0
	var svt := 0.0
	for i in 3:
		var a := o.animation(bank.clips[i])
		if a == null:
			return {"key": key, "error": "clip missing from the library: %s" % bank.clips[i]}
		anims.append(a)
		v.append(clip_speed(o, bank.clips[i]))
		sv += bank.weights[i] * v[i]
		svt += bank.weights[i] * v[i] * a.length
	if sv <= 0.0 or svt <= 0.0:
		return {"key": key, "error": "bank clips have no travel speed"}
	var ratio := clampf(speed / sv, RATIO_MIN, RATIO_MAX)
	var cps := ratio * sv / svt
	var n_win := int(float(opts.get("measure_s", MEASURE_S)) * hz)
	var cycle := hz / cps
	var chains := _chains(o)
	var rad := deg_to_rad(float(bank.deg))
	var vel := Vector3(sin(rad), 0.0, cos(rad)) * speed
	var frames := []
	for k in n_win + ceili(cycle) + 1:
		var u := fposmod(k * cps / hz, 1.0)
		var pts := _points(o, _bank_pose(o, anims, bank.weights, bank.x, u, semantics), chains)
		var y := PackedFloat32Array()
		for q: Vector3 in pts:
			y.append(q.y)
		frames.append({"f": k, "dt": 1.0 / hz, "rel": pts, "y": y, "v": vel})
	var probe := FootSlip.new(null, null)
	var med := PackedFloat64Array()
	var p90 := PackedFloat64Array()
	var planted := 0.0
	for j in IDEAL_PHASES:
		var s0 := roundi(j * cycle / IDEAL_PHASES)
		probe.samples = frames.slice(s0, s0 + n_win)
		var r := probe.result()
		med.append(r.median_mps)
		p90.append(r.p90_mps)
		planted += float(r.planted_frac)
	var sorted := med.duplicate()
	sorted.sort()
	return {"key": key, "ideal_mps": _round(_percentile(med, 0.5)), "min_mps": sorted[0], "max_mps": sorted[-1],
			"p90_mps": _round(_percentile(p90, 0.5)), "planted_frac": _round(planted / IDEAL_PHASES),
			"speed_mps": _round(speed), "ratio": _round(ratio), "ratio_unclamped": _round(speed / sv),
			"cps": _round(cps), "hemi": bank.hemi, "x": bank.x, "clips": bank.clips,
			"weights": Array(bank.weights).map(func(x): return _round(x)), "clip_speeds": Array(v),
			"semantics": semantics, "source": bank.source, "phases": IDEAL_PHASES}


## ideal_floor() result as flat fields for a measure() result / baseline entry:
## {ideal_mps, ideal_min_mps, ideal_max_mps, ideal: {details}} ({} when skipped; {ideal_error}).
static func ideal_fields(r: Dictionary) -> Dictionary:
	if r.has("skipped"):
		return {}
	if r.has("error"):
		return {"ideal_error": r.error}
	var detail := r.duplicate()
	for k in ["key", "ideal_mps", "min_mps", "max_mps"]:
		detail.erase(k)
	return {"ideal_mps": r.ideal_mps, "ideal_min_mps": r.min_mps, "ideal_max_mps": r.max_mps, "ideal": detail}


## Start-window reference (WP7): what result() reads for PERFECT playback of case c's graph start
## state (roles start_fw / start_fw_rt / start_fw_lt or start_bw / _lt / _rt of the weapon and
## mode, the section 6.5 direction bank, graph slerp chain, every clip at one normalized phase),
## played once from phase 0 to 1 at the start's rate (phase callback 0x0001466c: desired speed /
## the bank's final body speed, at least 0.5; raised where the clips' own speed is below the
## desired speed, up to opts.rate_max (RATIO_MAX) unless opts.rate_boost is false:
## LocoBrain._align_rate with start_rate_boost) while the body moves
## along the case direction at the start's root-motion speed (LocoBrain root_motion_speed(): the
## clips' metrics body_profile displacement rate, blended as vectors, x the rate), entered from
## the stance's idle clip over the graph's idle -> start fade (START_FADE_S, the body at start
## weight x that speed; median over START_IDLE_PHASES of the idle clip; min_mps / max_mps over them). It is the start
## clips' own foot slip against their own authored body motion, with the graph's crossfade into
## them; the start -> move join is the graph's fade-0 cut at phase 1 (start_to_move), outside it.
## {start_floor_mps, min_mps, max_mps, p90_mps, planted_frac, rate, duration_s, clips, weights,
## idle} or {error} / {skipped}.
static func start_floor(o: PoseOracle, c: Dictionary, speed: float, opts := {}) -> Dictionary:
	var key: String = c.get("key", "?")
	if o == null:
		return {"key": key, "error": "no PoseOracle"}
	if speed <= 0.0 or DIRS.get(c.get("dir", "none"), []).is_empty():
		return {"key": key, "skipped": "standing still"}
	var hz := float(opts.get("hz", Engine.physics_ticks_per_second))
	var deg: float = DIR_DEG.get(c.get("dir", "W"), 0.0)
	var fw := absf(deg) <= 90.0
	var x := clampf(deg if fw else PoseOracle.angle_mod(deg + 180.0), -90.0, 90.0)
	var roles := ["start_fw", "start_fw_rt", "start_fw_lt"] if fw else ["start_bw", "start_bw_lt", "start_bw_rt"]
	var w: String = opts.get("weapon", "")
	if w == "":
		w = "musket"
	var table := _graph_roles()
	var clips := []
	for r: String in roles:
		var role: Dictionary = table.get("%s/%s/%s" % [w, c.get("mode", "run"), r], {})
		clips.append(String(role.get("clip", "")) if role.get("clip") is String else "")
	if clips[0] == "":
		return {"key": key, "error": "no start role %s/%s/%s" % [w, c.get("mode", "run"), roles[0]]}
	var wn := PoseOracle.lerp_scale(-90.0, 0.0, 1.0, 0.0, x)
	var wp := PoseOracle.lerp_scale(0.0, 90.0, 0.0, 1.0, x)
	var w3 := [maxf(0.0, 1.0 - wn - wp), wn, wp]
	for i in [1, 2]:
		if clips[i] == "":
			w3[0] += w3[i]
			w3[i] = 0.0
			clips[i] = clips[0]
	var anims: Array[Animation] = []
	var tl := 0.0
	var align := 0.0
	var m := _clip_metrics()
	for i in 3:
		var a := o.animation(clips[i])
		if a == null:
			return {"key": key, "error": "clip missing from the library: %s" % clips[i]}
		anims.append(a)
		tl += w3[i] * a.length
		var sp: Array = m.get(clips[i], {}).get("body_profile", {}).get("speed", [])
		align += w3[i] * (float(sp[sp.size() - 1]) if not sp.is_empty() else 0.0)
	if tl <= 1e-6:
		return {"key": key, "error": "empty bank"}
	var rate := 1.0 if align <= 0.0 else maxf(speed / align, 0.5)
	var boost_max := float(opts.get("rate_max", RATIO_MAX)) if bool(opts.get("rate_boost", true)) else 0.0
	# Phase over time (LocoBrain._align_rate with start_rate_boost): the graph rate, raised where
	# the clips' own speed is below the desired speed, up to boost_max.
	var us := PackedFloat32Array()
	var rates := PackedFloat32Array()
	var u0 := 0.0
	while u0 < 1.0 and us.size() < int(20.0 * hz):
		var v1 := 0.0
		var bv0 := Vector2.ZERO
		for i in 3:
			if float(w3[i]) > 0.0:
				bv0 += float(w3[i]) * _profile_velocity(m, clips[i], anims[i].length, u0) * anims[i].length / tl
		v1 = bv0.length()
		var r := rate
		if boost_max > 0.0 and v1 > 1e-3:
			r = maxf(r, minf(speed / v1, boost_max))
		us.append(u0)
		rates.append(r)
		u0 += r / tl / hz
	us.append(1.0)
	rates.append(rates[-1] if not rates.is_empty() else rate)
	var n := us.size() - 1
	var dur := float(n) / hz
	var chains := _chains(o)
	var rad := deg_to_rad(deg)
	var dir := Vector3(sin(rad), 0.0, cos(rad))
	# The idle -> start crossfade (the idle clip of the stance, at a few of its phases): the start
	# input fades in over START_FADE_S from its phase 0 while the idle's feet move with the body, so
	# the body moves at (start weight) x the start's root-motion speed (LocoBrain.root_motion_speed()).
	var idle_role: Dictionary = table.get("%s/%s/idle" % [w, c.get("mode", "run")], {})
	var idle_anim: Animation = o.animation(String(idle_role.clip)) if idle_role.get("clip") is String else null
	var meds := PackedFloat64Array()
	var p90s := PackedFloat64Array()
	var planted := 0.0
	var phases: Array = START_IDLE_PHASES if idle_anim != null else [0.0]
	for ip: float in phases:
		var frames := []
		for k in n + 1:
			var u := float(us[k])
			var fade_w := clampf(float(k) / hz / START_FADE_S, 0.0, 1.0) if idle_anim != null else 1.0
			var pose := _bank_pose(o, anims, w3, x, u, "graph")
			if fade_w < 1.0:
				var t_idle := fposmod(ip * idle_anim.length + float(k) / hz, idle_anim.length)
				pose = o.crossfade(o.clip(idle_anim, t_idle), pose, fade_w)
			var pts := _points(o, pose, chains)
			var y := PackedFloat32Array()
			for q: Vector3 in pts:
				y.append(q.y)
			# The body's speed over the step into frame k: the clips' speed and the fade weight in the
			# middle of it (LocoBrain.root_motion_speed() looks half an advance ahead).
			var um := 0.5 * (float(us[k - 1]) + u) if k > 0 else u
			var wm := clampf((float(k) - 0.5) / hz / START_FADE_S, 0.0, 1.0) if idle_anim != null else 1.0
			var bv := Vector2.ZERO
			for i in 3:
				if float(w3[i]) > 0.0:
					bv += float(w3[i]) * _profile_velocity(m, clips[i], anims[i].length, um) * anims[i].length / tl
			frames.append({"f": k, "dt": 1.0 / hz, "rel": pts, "y": y, "v": dir * bv.length() * float(rates[maxi(k - 1, 0)]) * wm})
		var probe := FootSlip.new(null, null)
		probe.samples = frames
		var r := probe.result()
		meds.append(float(r.median_mps))
		p90s.append(float(r.p90_mps))
		planted += float(r.planted_frac)
	var sm := meds.duplicate()
	sm.sort()
	return {"key": key, "start_floor_mps": _round(_percentile(meds, 0.5)), "min_mps": _round(sm[0]), "max_mps": _round(sm[-1]),
			"p90_mps": _round(_percentile(p90s, 0.5)),
			"planted_frac": _round(planted / phases.size()), "rate": _round(rate), "duration_s": _round(dur), "clips": clips,
			"weights": w3.map(func(v): return _round(v)), "x": x, "hemi": "fw" if fw else "bw",
			"idle": String(idle_role.get("clip", "")), "fade_s": START_FADE_S}


## Stop-window reference (WP7 review): what result() reads for PERFECT playback of case c from the
## key release until the lower body's graph stop state ends (phase 1, stop_to_idle's gate): the
## case's steady loop bank (case_bank(), every clip at one normalized phase, at the section 6.6
## rate from the body speed, floor RATE_FLOOR_DECEL once not moving) crossfading over the graph's
## move -> stop fade (STOP_FADE_S, from the release frame: LocoBrain drops `moving` on the stick
## release) into the case's stop bank (roles stop_fw / _rt / _lt or stop_bw / _lt / _rt, the
## section 6.5 direction chain, entered at phase 0; the stop callback's rate min(1, lerp-scale(0,
## STOP_RAMP_PHASE, entry speed / the bank's first body speed, 1, phase)) with the entry speed =
## `speed`, as LocoBrain._align_rate), the body moving along the case direction as opts.body says:
##   "decel" (default; player.gd today): from `speed` down to 0 at opts.decel (ground_decel) m/s^2;
##   "root": the stop clips' body speed (metrics body_profile, INFERRED from the feet, as for the
##           start's root motion) x their rate, faded in over the move -> stop fade from the loop's
##           speed: what a body that followed the stop clip would read (not what runs today).
## Median over IDEAL_PHASES loop phases (min_mps / max_mps over them). Only the foot chains are
## evaluated (_chain_clip()). {stop_floor_mps, min_mps, max_mps, p90_mps, planted_frac, duration_s,
## travel_m (the body's travel), rate0 (the stop's rate at entry), clips, weights, body} or
## {error} / {skipped}.
static func stop_floor(o: PoseOracle, c: Dictionary, speed: float, opts := {}) -> Dictionary:
	var key: String = c.get("key", "?")
	if o == null:
		return {"key": key, "error": "no PoseOracle"}
	if speed <= 0.0 or DIRS.get(c.get("dir", "none"), []).is_empty():
		return {"key": key, "skipped": "standing still"}
	var hz := float(opts.get("hz", Engine.physics_ticks_per_second))
	var body: String = opts.get("body", "decel")
	var decel := float(opts.get("decel", 18.0))
	var deg: float = DIR_DEG.get(c.get("dir", "W"), 0.0)
	var fw := absf(deg) <= 90.0
	var x := clampf(deg if fw else PoseOracle.angle_mod(deg + 180.0), -90.0, 90.0)
	var roles := ["stop_fw", "stop_fw_rt", "stop_fw_lt"] if fw else ["stop_bw", "stop_bw_lt", "stop_bw_rt"]
	var w: String = opts.get("weapon", "")
	if w == "":
		w = "musket"
	var table := _graph_roles()
	var clips := []
	for r: String in roles:
		var role: Dictionary = table.get("%s/%s/%s" % [w, c.get("mode", "run"), r], {})
		clips.append(String(role.get("clip", "")) if role.get("clip") is String else "")
	if clips[0] == "":
		return {"key": key, "error": "no stop role %s/%s/%s" % [w, c.get("mode", "run"), roles[0]]}
	var wn := PoseOracle.lerp_scale(-90.0, 0.0, 1.0, 0.0, x)
	var wp := PoseOracle.lerp_scale(0.0, 90.0, 0.0, 1.0, x)
	var w3 := [maxf(0.0, 1.0 - wn - wp), wn, wp]
	for i in [1, 2]:
		if clips[i] == "":
			w3[0] += w3[i]
			w3[i] = 0.0
			clips[i] = clips[0]
	var m := _clip_metrics()
	var anims: Array[Animation] = []
	var tl := 0.0
	var align0 := 0.0
	for i in 3:
		var a := o.animation(clips[i])
		if a == null:
			return {"key": key, "error": "clip missing from the library: %s" % clips[i]}
		anims.append(a)
		tl += w3[i] * a.length
		var sp: Array = m.get(clips[i], {}).get("body_profile", {}).get("speed", [])
		align0 += w3[i] * (float(sp[0]) if not sp.is_empty() else 0.0)
	if tl <= 1e-6:
		return {"key": key, "error": "empty stop bank"}
	var k0 := 1.0 if align0 <= 0.0 else maxf(speed / align0, 0.01)
	# The loop that plays at the release (the steady bank).
	var bank := case_bank(c, w)
	var lanims: Array[Animation] = []
	var sv := 0.0
	var svt := 0.0
	for i in 3:
		var a := o.animation(bank.clips[i])
		if a == null:
			return {"key": key, "error": "clip missing from the library: %s" % bank.clips[i]}
		lanims.append(a)
		var v := clip_speed(o, bank.clips[i])
		sv += bank.weights[i] * v
		svt += bank.weights[i] * v * a.length
	if sv <= 0.0 or svt <= 0.0:
		return {"key": key, "error": "loop bank clips have no travel speed"}
	# The stop's phase per frame after the release (it depends on the entry speed only).
	var us := PackedFloat32Array([0.0])
	var ms := PackedFloat32Array([k0 if k0 < 1.0 else 1.0])
	var u := 0.0
	while u < 1.0 and us.size() < int(20.0 * hz):
		var mm := minf(1.0, PoseOracle.lerp_scale(0.0, STOP_RAMP_PHASE, k0, 1.0, u))
		u = minf(u + mm / tl / hz, 1.0)
		us.append(u)
		ms.append(mm)
	var n := us.size() - 1
	var rad := deg_to_rad(deg)
	var dir := Vector3(sin(rad), 0.0, cos(rad))
	var chains := _chains(o)
	var want := _chain_set(chains)
	var meds := PackedFloat64Array()
	var p90s := PackedFloat64Array()
	var planted := 0.0
	var travel := 0.0
	var loop_ratio0 := clampf(speed / sv, RATIO_MIN, RATIO_MAX)
	for j in IDEAL_PHASES:
		var ul := float(j) / IDEAL_PHASES
		var frames := []
		var trav := 0.0
		for f in n + 1:
			var t := float(f) / hz
			var wstop := clampf(t / STOP_FADE_S, 0.0, 1.0)
			# The body's speed after physics tick f (the pose update of frame f follows it).
			var vb := speed
			if body == "root":
				var um := 0.5 * (float(us[f - 1]) + float(us[f])) if f > 0 else 0.0
				var bv := Vector2.ZERO
				for i in 3:
					if float(w3[i]) > 0.0:
						bv += float(w3[i]) * _profile_velocity(m, clips[i], anims[i].length, um) * anims[i].length / tl
				var wm := clampf((float(f) - 0.5) / hz / STOP_FADE_S, 0.0, 1.0)
				vb = wm * bv.length() * float(ms[f]) + (1.0 - wm) * loop_ratio0 * sv
			else:
				vb = maxf(0.0, speed - decel * t)
			trav += vb / hz if f > 0 else 0.0
			# The loop advances at the rate of this tick's body speed (floor while not moving).
			if f > 0:
				var ratio := maxf(clampf(vb / sv, RATIO_MIN, RATIO_MAX), RATE_FLOOR_DECEL) if body != "root" else loop_ratio0
				ul = fposmod(ul + ratio * sv / svt / hz, 1.0)
			var pose := _chain_bank(o, lanims, bank.weights, ul, want)
			if wstop > 0.0:
				pose = _chain_xfade(pose, _chain_bank(o, anims, w3, float(us[f]), want), wstop, want)
			var pts := _points(o, pose, chains)
			var y := PackedFloat32Array()
			for q: Vector3 in pts:
				y.append(q.y)
			frames.append({"f": f, "dt": 1.0 / hz, "rel": pts, "y": y, "v": dir * vb})
		# As run_case's stop probe: its first sample is the pose update after the first tick.
		var probe := FootSlip.new(null, null)
		probe.samples = frames.slice(1)
		var r := probe.result()
		meds.append(float(r.median_mps))
		p90s.append(float(r.p90_mps))
		planted += float(r.planted_frac)
		travel = trav
	var sm := meds.duplicate()
	sm.sort()
	return {"key": key, "stop_floor_mps": _round(_percentile(meds, 0.5)), "min_mps": _round(sm[0]), "max_mps": _round(sm[-1]),
			"p90_mps": _round(_percentile(p90s, 0.5)), "planted_frac": _round(planted / IDEAL_PHASES),
			"duration_s": _round(float(n) / hz), "travel_m": _round(travel), "rate0": _round(k0), "clips": clips,
			"weights": w3.map(func(v): return _round(v)), "x": x, "hemi": "fw" if fw else "bw", "body": body,
			"loop": bank.clips, "fade_s": STOP_FADE_S, "decel": decel}


## Bone indices of the foot chains (a set: bone -> true).
static func _chain_set(chains: Array) -> Dictionary:
	var out := {}
	for ch: PackedInt32Array in chains:
		for b in ch:
			out[b] = true
	return out


## PoseOracle.clip() on the `want` bones only (rest elsewhere): the same interpolation, a fraction
## of the cost (stop_floor() samples two banks per frame).
static func _chain_clip(o: PoseOracle, a: Animation, t: float, want: Dictionary) -> PoseOracle.Pose:
	var out := o.rest()
	var id := a.get_instance_id()
	var tm: Array = _chain_tracks.get(id, [])
	if not _chain_tracks.has(id):
		for e: Array in o._track_map(a):
			if want.has(int(e[0])):
				tm.append(e)
		_chain_tracks[id] = tm
	for e: Array in tm:
		var b: int = e[0]
		match int(e[1]):
			Animation.TYPE_ROTATION_3D:
				out.r[b] = a.rotation_track_interpolate(e[2], t)
				out.kr[b] = 1
			Animation.TYPE_POSITION_3D:
				out.p[b] = a.position_track_interpolate(e[2], t)
				out.kp[b] = 1
			Animation.TYPE_SCALE_3D:
				out.s[b] = a.scale_track_interpolate(e[2], t)
				out.ks[b] = 1
	return out


## PoseOracle.crossfade() on the `want` bones only.
static func _chain_xfade(a: PoseOracle.Pose, b: PoseOracle.Pose, w: float, want: Dictionary) -> PoseOracle.Pose:
	var o := a.copy()
	for i: int in want:
		o.r[i] = a.r[i].slerp(b.r[i], w)
		o.p[i] = a.p[i].lerp(b.p[i], w)
		o.s[i] = a.s[i].lerp(b.s[i], w)
	return o


## _bank_pose() (graph semantics) on the `want` bones only.
static func _chain_bank(o: PoseOracle, anims: Array[Animation], w: Array, u: float, want: Dictionary) -> PoseOracle.Pose:
	var pose := _chain_clip(o, anims[0], u * anims[0].length, want)
	if float(w[1]) > 0.0:
		pose = _chain_xfade(pose, _chain_clip(o, anims[1], u * anims[1].length, want), float(w[1]), want)
	if float(w[2]) > 0.0:
		pose = _chain_xfade(pose, _chain_clip(o, anims[2], u * anims[2].length, want), float(w[2]), want)
	return pose


## A clip's authored body velocity (m per clip second; x = side, left +, y = forward) at phase u:
## the derivative of metrics body_profile's cumulative fwd / side displacement (the same as
## LocoBrain._profile_velocity()).
static func _profile_velocity(m: Dictionary, clip: String, length: float, u: float) -> Vector2:
	var bp: Dictionary = m.get(clip, {}).get("body_profile", {}) if m.get(clip) is Dictionary else {}
	var fw: Array = bp.get("fwd", [])
	var sd: Array = bp.get("side", [])
	if fw.size() >= 2 and sd.size() == fw.size() and length > 0.0:
		var n := fw.size() - 1
		var dt := length / float(n)
		var xx := clampf(clampf(u, 0.0, 1.0) * float(n) - 0.5, 0.0, float(n - 1))
		var i := mini(int(xx), maxi(n - 2, 0))
		var j := mini(i + 1, n - 1)
		var a := Vector2(float(sd[i + 1]) - float(sd[i]), float(fw[i + 1]) - float(fw[i])) / dt
		var b := Vector2(float(sd[j + 1]) - float(sd[j]), float(fw[j + 1]) - float(fw[j])) / dt
		return a.lerp(b, clampf(xx - float(i), 0.0, 1.0))
	var sp: Array = bp.get("speed", [])
	if sp.is_empty():
		return Vector2.ZERO
	var xs := clampf(u, 0.0, 1.0) * float(sp.size() - 1)
	var k := mini(int(xs), maxi(sp.size() - 2, 0))
	return Vector2(0.0, lerpf(float(sp[k]), float(sp[mini(k + 1, sp.size() - 1)]), xs - float(k)))


## Local pose of the bank at bank position x, every clip at phase u (u * its length).
static func _bank_pose(o: PoseOracle, anims: Array[Animation], w: Array, x: float, u: float,
		semantics: String) -> PoseOracle.Pose:
	if semantics == "godot":
		var pts := []
		for i in 3:
			pts.append([[0.0, -90.0, 90.0][i], o.g_clip(anims[i], u * anims[i].length)])
		return o.g_eval(o.g_blend_space_1d(pts, x))
	var pose := o.clip(anims[0], u * anims[0].length)
	if w[1] > 0.0:
		pose = o.crossfade(pose, o.clip(anims[1], u * anims[1].length), w[1])
	if w[2] > 0.0:
		pose = o.crossfade(pose, o.clip(anims[2], u * anims[2].length), w[2])
	return pose


## Root-to-point bone chains of POINTS.
static func _chains(o: PoseOracle) -> Array:
	var out := []
	for n: String in POINTS:
		var ch := PackedInt32Array()
		var b: int = o.bone_index.get(n, -1)
		while b >= 0:
			ch.insert(0, b)
			b = o.parents[b]
		out.append(ch)
	return out


## Skeleton-space positions of POINTS for a local pose.
static func _points(o: PoseOracle, pose: PoseOracle.Pose, chains: Array) -> Array:
	var out := []
	for ch: PackedInt32Array in chains:
		var t := Transform3D.IDENTITY
		for b in ch:
			t = t * pose.xform(b)
		out.append(t.origin)
	return out


## Least-squares horizontal velocity (x, z) of point pt over planted run `js` (unwrapped
## indices from `first`, cyclic over n samples).
static func _slope(js: PackedInt32Array, pos: Array, first: int, n: int, pt: int, dt: float) -> Vector2:
	var mt := 0.0
	var mx := Vector2.ZERO
	for j in js:
		var q: Vector3 = pos[(first + j) % n][pt]
		mt += j * dt
		mx += Vector2(q.x, q.z)
	mt /= js.size()
	mx /= js.size()
	var num := Vector2.ZERO
	var den := 0.0
	for j in js:
		var q: Vector3 = pos[(first + j) % n][pt]
		var d := j * dt - mt
		num += d * (Vector2(q.x, q.z) - mx)
		den += d * d
	return num / den if den > 0.0 else Vector2.ZERO


static func _graph_roles() -> Dictionary:
	if _roles == null:
		_roles = {}
		if FileAccess.file_exists(GRAPH_JSON):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(GRAPH_JSON))
			if d is Dictionary and d.get("roles", null) is Dictionary:
				_roles = d.roles
	return _roles


static func _clip_metrics() -> Dictionary:
	if _metrics == null:
		_metrics = {}
		if FileAccess.file_exists(METRICS_JSON):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(METRICS_JSON))
			if d is Dictionary and d.get("clips", null) is Dictionary:
				_metrics = d.clips
	return _metrics


## v: PackedFloat32Array or PackedFloat64Array.
static func _percentile(v: Variant, q: float) -> float:
	if v.is_empty():
		return NAN
	var s: Variant = v.duplicate()
	s.sort()
	var size: int = s.size()
	var x: float = q * (size - 1)
	var i := int(floor(x))
	var j := mini(i + 1, size - 1)
	return lerpf(float(s[i]), float(s[j]), x - i)


static func _round(x: float) -> float:
	return snappedf(x, 0.0001) if not is_nan(x) else x
