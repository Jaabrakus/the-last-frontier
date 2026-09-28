extends AnimTestSuite
## WP7 (plan section 10 test_locomotion_feet): planted-foot slip of the graph-driven player on the
## real level, 120 Hz physics, driven by Input.action_press: W / A / S / D / W+A for walk / run /
## crouch and W / W+A / W+D for sprint, for every weapon (FootSlip.measure(): a fresh level per
## repeat, 5 repeats with the fixed pre-rolls, median of the repeat medians; see
## tests/anim/README.md "Old-tree foot-slip baseline").
##
## Gate. The plan's absolute 0.15 m/s cannot be met by perfect, graph-faithful playback for
## several cases (FootSlip.ideal_floor(): run W / A / D / S 0.15-0.17 at bow and pistol speed,
## sprint W 0.22, crouch D 0.19-0.20, run and sprint diagonals 0.35-0.70), so every case is gated
## relative to its own ideal-playback floor, the README's recommended option:
##   median_mps <= ideal_mps + RELATIVE_MARGIN (0.05 m/s)
## and the absolute 0.15 m/s result is reported next to it, with the old tree's baseline
## (baselines/footslip_old.json: median and range) and the ideal. Cases where the ideal itself
## is above 0.15 are marked.
##
## Steady gait. With the graph's own behaviour (user requirement: start / stop states on by
## default; override_no_transition_anims is the opt-in G1 override) a start from standing plays
## the graph's start clip (idle^walk / idle^run / idle^sprint / crouch-idle^walk) first: about
## 0.2 s (walk bw) to 3.2 s (crouch) before the locomotion loop. The plan's 1 s settle assumed G1
## (no start clips), so the steady probe waits until the lower body has been in MOVE for STEADY_S
## (at most SETTLE_MAX_S after the 1 s settle; FootSlip settle_until) and then measures the steady
## gait the ideal floor describes. The time to steady gait is reported.
##
## Start window (WP7 review): the start itself is measured too, from the key press until the lower
## body leaves its start state (FootSlip start_window), and gated against its own data-derived
## reference, FootSlip.start_floor(): perfect playback of the case's graph start bank at the
## start's rate with the body at the start's root-motion speed (player.gd follows it through a
## start: PlayerAnim.body_speed_cap(); override_free_start_speed is the opt-in override that
## slides), over the idle clip phases the start can begin from:
##   start_median_mps <= start_floor_max_mps + START_MARGIN (0.05, as the steady gate)
## The reference is a model, not an absolute measure: the body speed comes from the metrics'
## foot-contact body_profile (INFERRED; coverage 0.39-0.73 on some starts) and the rate is the
## player's (override_start_rate_boost, on by default pending the owner's decision: the boosted
## rate). The floor at the graph's align rate (start_floor_graph_*) and the absolute 0.15 are
## reported next to it. Orchestrator / owner sign-off on this gate is pending
## (tests/anim/README.md "WP7 record").
## The reference includes the graph's idle -> start crossfade (idle_to_start, 0x0003f290, 0.2 s)
## from each of FootSlip.START_IDLE_PHASES of the idle clip (the phase the key finds it at is
## arbitrary); START_MARGIN covers phase and rate error as the steady gate's 0.05 does. The key is pressed from
## a settled stand (settled_stand: the teleport's yaw change first plays the graph's idle turn).
## Repeats whose pre-roll leaves the lower body moving (no start state after the press) are left
## out.
##
## Stop window (WP7 review, reported, not gated): from the key release after the steady window
## until the lower body reaches IDLE (FootSlip stop_window: the graph's stop state played to its
## end), with the body's travel. Its references, FootSlip.stop_floor(): perfect playback of the
## loop crossfading into the case's graph stop bank with the body as player.gd moves it today
## (ground_decel: the stop clip is not followed, unlike the start; stop_floor_*), and with the body
## following the stop clip's inferred body speed (stop_root_floor_*: what applying the start's
## root-motion rule to the stop would read). The start / stop asymmetry is an owner decision
## (tests/anim/README.md).
##
## Options: weapons=bow,musket,pistol (default all), cases=run/W,sprint/WA (default all),
## repeats=5. Run with --fixed-fps 120 (a few s per case; real time about 30-45 s per case).

const RELATIVE_MARGIN := 0.05
const ABSOLUTE_GATE := 0.15
const BASELINE := "res://tests/anim/baselines/footslip_old.json"
## Steady gait: the lower body in MOVE for this long (the start -> move fade, start_to_move, is over).
const STEADY_S := 0.5
const SETTLE_MAX_S := 4.5
## A start is measured from a stand settled this long in IDLE (the idle turn after the teleport over).
const SETTLED_IDLE_S := 0.3
## Start window gate margin over FootSlip.start_floor()'s range (m/s; see the header).
const START_MARGIN := 0.05


## True once the player's lower body has played its locomotion loop (MOVE) for STEADY_S.
static func steady_gait(p: Node) -> bool:
	var a: PlayerAnim = p.get("anim")
	return a != null and a.is_ready() and a.loco.state == LocoBrain.MOVE and a.loco.time_in_state >= STEADY_S


## True once the lower body has stood in IDLE for SETTLED_IDLE_S (FootSlip start_idle: the
## teleport's yaw change first plays an idle turn; the start is measured from a settled stand).
static func settled_stand(p: Node) -> bool:
	var a: PlayerAnim = p.get("anim")
	return a != null and a.is_ready() and a.loco.state == LocoBrain.IDLE and a.loco.time_in_state >= SETTLED_IDLE_S \
			and a.L.weight(a.loco.input_id) >= 1.0


## True until the player's lower body stands in IDLE (FootSlip stop_window: from the key release
## through the graph's stop state).
static func stopping(p: Node) -> bool:
	var a: PlayerAnim = p.get("anim")
	return a != null and a.is_ready() and a.loco.state != LocoBrain.IDLE


## True while the player's lower body plays a graph start state (FootSlip start_window).
static func in_start(p: Node) -> bool:
	var a: PlayerAnim = p.get("anim")
	return a != null and a.is_ready() and a.loco.state == LocoBrain.START


func describe() -> String:
	return "WP7 planted-foot slip, 3 weapons x 18 cases on the real level: steady median <= ideal-playback floor + 0.05 m/s, start window <= start floor range + %.2f (absolute 0.15, the old-tree baseline, the graph-rate start floor and the stop window reported)" % START_MARGIN


func timeout_s() -> float:
	# About 540 s with --fixed-fps 120 (start floors included); in real time about 45 min.
	return 7200.0


func run(ctx: AnimTestContext) -> void:
	var fast: bool = await AnimTestContext.faster_than_realtime(ctx.tree)
	if not fast:
		ctx.info("running in real time: about 30 s per case (use --fixed-fps 120)")
	var base := {}
	var raw := FileAccess.get_file_as_string(BASELINE)
	var parsed: Variant = JSON.parse_string(raw) if raw != "" else null
	if parsed is Dictionary:
		base = (parsed as Dictionary).get("cases", {})
	else:
		ctx.warn("old-tree baseline %s missing or unreadable" % BASELINE)
	var weapons: Array = String(ctx.arg("weapons", "bow,musket,pistol")).split(",")
	var only: Array = String(ctx.arg("cases", "")).split(",", false)
	var repeats := int(ctx.arg("repeats", FootSlip.REPEATS))
	var rows := []
	var over_rel := []
	var over_abs := []
	var ideal_over_abs := 0
	var n := 0
	var n_start := 0
	var start_rows := []
	var over_start := []
	var start_over_abs := []
	var start_over_graph := []
	var stop_rows := []
	var n_stop := 0
	var basis := ""
	for w: String in weapons:
		for c: Dictionary in FootSlip.cases():
			if not only.is_empty() and not String(c.key) in only:
				continue
			var r: Dictionary = await FootSlip.measure(ctx.tree, c, {"weapon": w, "ctx": ctx, "ideal": true, "repeats": repeats,
					"settle_until": steady_gait, "settle_max_s": SETTLE_MAX_S, "start_window": in_start, "start_idle": settled_stand,
				"stop_window": stopping})
			var key := "%s/%s" % [w, c.key]
			if r.has("error"):
				ctx.fail("%s: %s" % [key, r.error])
				continue
			n += 1
			var med := float(r.get("median_mps", NAN))
			var ideal := float(r.get("ideal_mps", NAN))
			var b: Dictionary = base.get(key, {})
			var flags := []
			var settled := 0.0
			for rp: Dictionary in r.get("repeats", []):
				settled = maxf(settled, float(rp.get("settled_s", 0.0)))
			if settled >= FootSlip.SETTLE_S + SETTLE_MAX_S - 0.01:
				ctx.fail("%s: the lower body did not reach a steady MOVE within %.1f s of input" % [key, settled])
			if bool(r.get("crouched")) != (c.mode == "crouch") or bool(r.get("sprinting")) != (c.mode == "sprint") \
					or bool(r.get("walking")) != (c.mode == "walk"):
				ctx.fail("%s: ran with crouched %s sprinting %s walking %s" % [key, r.get("crouched"), r.get("sprinting"), r.get("walking")])
			if is_nan(ideal):
				ctx.fail("%s: no ideal-playback floor (%s)" % [key, r.get("ideal_error", "?")])
				continue
			var rel_ok := med <= ideal + RELATIVE_MARGIN
			if not rel_ok:
				over_rel.append("%s %.3f > %.3f" % [key, med, ideal + RELATIVE_MARGIN])
			if med > ABSOLUTE_GATE:
				over_abs.append(key)
				flags.append("over 0.15")
			if ideal > ABSOLUTE_GATE:
				ideal_over_abs += 1
				flags.append("ideal over 0.15")
			rows.append("%-22s median %.3f (%.3f-%.3f)  ideal %.3f [%.3f-%.3f]  old %s  steady after %.2f s  %s%s" % [key, med, float(r.get("min_mps", NAN)),
					float(r.get("max_mps", NAN)), ideal, float(r.get("ideal_min_mps", NAN)), float(r.get("ideal_max_mps", NAN)),
					("%.3f (%.3f-%.3f)" % [float(b.median_mps), float(b.min_mps), float(b.max_mps)]) if not b.is_empty() else "-",
					settled, "ok" if rel_ok else "OVER", (" [%s]" % ", ".join(flags)) if not flags.is_empty() else ""])
			ctx.metric(key, {"median_mps": med, "ideal_mps": ideal, "old_median_mps": b.get("median_mps", null),
					"min_mps": r.get("min_mps"), "max_mps": r.get("max_mps"), "body_speed_mps": r.get("body_speed_mps"),
					"steady_after_s": settled})
			ctx.at_most(med, ideal + RELATIVE_MARGIN, "%s: planted-foot median slip <= ideal-playback floor %.3f + %.2f (m/s)" % [key, ideal, RELATIVE_MARGIN])
			# Start window.
			var smed := float(r.get("start_median_mps", NAN))
			var sfl := float(r.get("start_floor_mps", NAN))
			var sfx := float(r.get("start_floor_max_mps", sfl))
			if not r.has("start_median_mps"):
				ctx.fail("%s: no repeat played a start state after the key press" % key)
			elif is_nan(sfl):
				ctx.fail("%s: no start floor (%s)" % [key, r.get("start_floor_error", "?")])
			else:
				n_start += 1
				var s_ok := smed <= sfx + START_MARGIN
				basis = String(r.get("start_floor_basis", ""))
				if not s_ok:
					over_start.append("%s %.3f > %.3f" % [key, smed, sfx + START_MARGIN])
				if smed > ABSOLUTE_GATE:
					start_over_abs.append(key)
				var sgx := float(r.get("start_floor_graph_max_mps", NAN))
				if not is_nan(sgx) and smed > sgx + START_MARGIN:
					start_over_graph.append("%s %.3f > %.3f" % [key, smed, sgx + START_MARGIN])
				start_rows.append("%-22s start %.3f (%.3f-%.3f, %d repeats)  floor %.3f [%.3f-%.3f]  graph-rate floor %.3f [%.3f-%.3f]  %.2f s  %s%s" % [key, smed,
						float(r.get("start_min_mps", NAN)), float(r.get("start_max_mps", NAN)), int(r.get("start_repeats", 0)), sfl,
						float(r.get("start_floor_min_mps", NAN)), sfx, float(r.get("start_floor_graph_mps", NAN)),
						float(r.get("start_floor_graph_min_mps", NAN)), sgx, float(r.get("start_s", 0.0)), "ok" if s_ok else "OVER",
						" [over 0.15]" if smed > ABSOLUTE_GATE else ""])
				ctx.metric(key + "/start", {"start_median_mps": smed, "start_floor_mps": sfl, "start_floor_graph_mps": r.get("start_floor_graph_mps"),
						"start_s": r.get("start_s"), "start_repeats": r.get("start_repeats")})
				ctx.at_most(smed, sfx + START_MARGIN, "%s: start window planted-foot median slip <= start floor (max over the idle phases; inferred body_profile, the player's start rate) %.3f + %.2f (m/s)" % [key, sfx, START_MARGIN])
			# Stop window (reported, not gated).
			if r.has("stop_median_mps"):
				n_stop += 1
				stop_rows.append("%-22s stop %.3f p90 %.3f (%.3f-%.3f, %d repeats)  floor %.3f [%.3f-%.3f] p90 %.3f  root-motion floor %.3f [%.3f-%.3f] p90 %.3f  %.2f s  travel %.2f m (root %.2f m)" % [
						key, float(r.stop_median_mps), float(r.get("stop_p90_mps", NAN)), float(r.get("stop_min_mps", NAN)), float(r.get("stop_max_mps", NAN)),
						int(r.get("stop_repeats", 0)), float(r.get("stop_floor_mps", NAN)), float(r.get("stop_floor_min_mps", NAN)),
						float(r.get("stop_floor_max_mps", NAN)), float(r.get("stop_floor_p90_mps", NAN)), float(r.get("stop_root_floor_mps", NAN)),
						float(r.get("stop_root_floor_min_mps", NAN)), float(r.get("stop_root_floor_max_mps", NAN)), float(r.get("stop_root_floor_p90_mps", NAN)),
						float(r.get("stop_s", NAN)), float(r.get("stop_travel_m", NAN)),
						float((r.get("stop_root_floor", {}) as Dictionary).get("travel_m", NAN))])
				ctx.metric(key + "/stop", {"stop_median_mps": r.stop_median_mps, "stop_p90_mps": r.get("stop_p90_mps"),
						"stop_floor_mps": r.get("stop_floor_mps"), "stop_root_floor_mps": r.get("stop_root_floor_mps"), "stop_s": r.get("stop_s"),
						"stop_travel_m": r.get("stop_travel_m")})
			else:
				ctx.warn("%s: no repeat's stop reached IDLE within %.1f s of the key release" % [key, FootSlip.STOP_MAX_S])
	ctx.info("case                   median (range over repeats)  ideal [range]  old tree median (range)  time to steady gait (max over repeats)")
	for r in rows:
		ctx.info(r)
	ctx.info("%d cases; relative gate (ideal + %.2f): %d over %s" % [n, RELATIVE_MARGIN, over_rel.size(), over_rel])
	ctx.info("absolute 0.15 m/s (plan, for information): %d of %d over (%s); the ideal-playback floor itself is over 0.15 in %d" % [
			over_abs.size(), n, ", ".join(over_abs), ideal_over_abs])
	ctx.info("start window (key press -> the lower body leaves its start state): median (range over repeats)  start floor  start duration")
	for r in start_rows:
		ctx.info(r)
	ctx.info("%d start windows; gate (start floor + %.2f; the floor's basis: %s): %d over %s; against the graph-rate floor + %.2f (for information): %d over %s; absolute 0.15 m/s (for information): %d over (%s)" % [
			n_start, START_MARGIN, basis, over_start.size(), over_start, START_MARGIN, start_over_graph.size(), start_over_graph,
			start_over_abs.size(), ", ".join(start_over_abs)])
	ctx.info("stop window (key release -> the lower body in IDLE; reported, not gated): median p90 (range over repeats)  floor with the body as today (ground_decel)  floor with the body on the stop clip (root motion, inferred)  duration  body travel")
	for r in stop_rows:
		ctx.info(r)
	ctx.info("%d stop windows measured" % n_stop)
	ctx.check(n > 0, "foot-slip cases measured (%d)" % n)
