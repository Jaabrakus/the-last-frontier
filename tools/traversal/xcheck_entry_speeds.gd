extends SceneTree
## Cross-check of the traversal clip speeds (design: source/graph_analysis/traversal/traversal_design.md, 8.3).
##
## Runs the traversal survey's own contact-path odometry (measure_traversal_clips.gd `_odometry`, same
## constants) on:
##   1. the locomotion loops (sprint-fw, run-fw, walk-fw) at 10, 15 and 30 Hz, to compare with the
##      locomotion estimator's bank speeds (animations/actor_b_clip_metrics.json: sprint 4.24, run 3.34,
##      walk 1.26) and with the entry prior the survey uses (odometry.context.entry_prior_speed);
##   2. traversal chains entered from locomotion, alone (as the survey measured them) and preceded by
##      1.0 s of their locomotion loop at the best-matching phase (translation-aligned at the seam), at
##      10 and 30 Hz.
## Read-only: prints a table (and writes JSON with out=<path>). Nothing in the project changes.
##
##   Godot --headless --path <Frontier> -s res://tools/traversal/xcheck_entry_speeds.gd [-- out=<json>]

const M := preload("res://tools/traversal/measure_traversal_clips.gd")
const METRICS := "res://animations/actor_b_clip_metrics.json"
const LOOPS := {"sprint": "actor_b-p-sprint-fw", "run": "actor_b-p-run-fw", "walk": "actor_b-p-walk-fw"}
## [label, parts, entry gait (loop used as context)]
const CHAINS := [
	["sprint vault", ["actor_b-p-sprint-vault-1", "actor_b-p-sprint-vault-2", "actor_b-p-sprint-vault-3", "actor_b-p-sprint-vault-4"], "sprint"],
	["run vault (1 m)", ["actor_b-p-run^vault-over-1m", "actor_b-p-vault-1m", "actor_b-p-vault-over-1m^vault-end-run", "actor_b-p-vault-end^run"], "run"],
	["run knee mantle", ["actor_b-p-run-jump-up-1m^ledge", "actor_b-p-ledge-knee-climb-up^run"], "run"],
	["run hurdle 0.5 m", ["actor_b-p-run-jump-up-0-5m"], "run"],
	["run gap jump 1.5 m", ["actor_b-p-run^jump-rfoot-1-5m", "actor_b-p-jump-rfoot-1-5m", "actor_b-p-jump-rfoot-1-5m^run"], "run"],
	["run long jump", ["actor_b-p-run^jump-long", "actor_b-p-jump-long"], "run"],
]
const CONTEXT_S := 1.0

var _rig
var _lib: AnimationLibrary
var _need := PackedInt32Array()
var _clos := PackedInt32Array()


func _initialize() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if "=" in s:
			args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
	var inst: Node3D = (load(M.RIG) as PackedScene).instantiate()
	root.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	BindRest.ensure(sk, ap, StringName(M.LIB))
	_lib = ap.get_animation_library(M.LIB)
	_rig = M._Rig.new(sk)
	for p: String in M.PTS:
		_need.append(_rig.bone(p))
	_clos = _rig.closure(_need)
	var bank := _bank_speeds()
	var out := {"bank_speeds_locomotion_estimator": bank, "loops": {}, "chains": {}}
	print("XCHECK loops (contact-path odometry of the traversal survey; bank = locomotion estimator)")
	for g: String in LOOPS:
		var L := _lib.get_animation(LOOPS[g]).length
		var row := {}
		for rate: float in [10.0, 15.0, 30.0]:
			var seq := _loop_seq(LOOPS[g], 0.0, 3.0 * L, rate)
			var r := _speeds(seq, null, L, 2.0 * L)
			row["%d_hz" % rate] = r.mean
		out.loops[g] = row
		print("  %-7s bank %.2f   10 Hz %.2f   15 Hz %.2f   30 Hz %.2f   ratio(15 Hz / bank) %.2f" % [g, bank.get(g, 0.0),
				row["10_hz"], row["15_hz"], row["30_hz"], row["15_hz"] / maxf(bank.get(g, 1.0), 1e-3)])
	print("XCHECK chains: mean / first 0.2 s / last 0.2 s horizontal pelvis speed (m/s)")
	for c: Array in CHAINS:
		var label: String = c[0]
		var parts: Array = c[1]
		var gait: String = c[2]
		var total := 0.0
		for n: String in parts:
			total += _lib.get_animation(n).length
		var row := {}
		for rate: float in [10.0, 30.0]:
			var alone := _chain_seq([], parts, rate)
			var prior := Vector3(0, 0, float(bank.get(gait, 0.0)))
			var a := _speeds(alone, prior, 0.0, total)
			var ctx := _with_context(LOOPS[gait], parts, rate)
			var b := _speeds(ctx.seq, null, ctx.t0, ctx.t0 + total)
			row["%d_hz" % rate] = {"alone": a, "with_loop": b, "seam_gap_m": ctx.gap}
			print("  %-20s @%2d Hz  alone %.2f / %.2f / %.2f   after %s loop %.2f / %.2f / %.2f  (seam gap %.3f m)" % [label, rate,
					a.mean, a.first, a.last, gait, b.mean, b.first, b.last, ctx.gap])
		out.chains[label] = row
	if args.has("out"):
		var f := FileAccess.open(String(args.out), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(out, " ") + "\n")
	print("XCHECK OK")
	quit(0)


func _bank_speeds() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(METRICS))
	var out := {}
	if d is Dictionary:
		for g: String in LOOPS:
			var c: Dictionary = d.clips.get(LOOPS[g], {})
			out[g] = float(c.get("travel", {}).get("speed", 0.0))
	return out


func _pose(a: Animation, t: float) -> PackedVector3Array:
	var ev = _rig.eval(a)
	var g: Dictionary = ev.globals(_clos, clampf(t, 0.0, a.length))
	var pv := PackedVector3Array()
	for p: String in M.PTS:
		pv.append((g[_rig.bone(p)] as Transform3D).origin)
	return pv


## A loop played from phase time t_start for `dur` seconds (wrapping), sampled at `rate`.
func _loop_seq(loop: String, t_start: float, dur: float, rate: float) -> Array:
	var a := _lib.get_animation(loop)
	var times := PackedFloat64Array()
	var pts := []
	var k := 0
	while k / rate <= dur + 1e-6:
		times.append(k / rate)
		pts.append(_pose(a, fposmod(t_start + k / rate, a.length)))
		k += 1
	return [times, pts]


## Parts back to back; `head` is an already sampled [times, pts] prefix (the loop context).
func _chain_seq(head: Array, parts: Array, rate: float) -> Array:
	var times := PackedFloat64Array()
	var pts := []
	var t0 := 0.0
	if not head.is_empty():
		times = (head[0] as PackedFloat64Array).duplicate()
		pts = (head[1] as Array).duplicate()
		t0 = times[times.size() - 1] + 1.0 / rate
	var total := 0.0
	for n: String in parts:
		total += _lib.get_animation(n).length
	var k := 0
	while k / rate <= total + 1e-6:
		var t := k / rate
		var acc := 0.0
		for n: String in parts:
			var a := _lib.get_animation(n)
			if t <= acc + a.length + 1e-6:
				times.append(t0 + t)
				pts.append(_pose(a, t - acc))
				break
			acc += a.length
		k += 1
	return [times, pts]


## CONTEXT_S of the loop ending at the phase whose pose best matches the chain's first pose
## (legs, pelvis and head points; horizontal translation removed), shifted so the seam has no
## horizontal jump.
func _with_context(loop: String, parts: Array, rate: float) -> Dictionary:
	var a := _lib.get_animation(loop)
	var first := _pose(_lib.get_animation(parts[0]), 0.0)
	var best_t := 0.0
	var best_gap := INF
	var n := int(a.length * 60.0)
	for i in n:
		var t := a.length * i / n
		var p := _pose(a, t)
		var d := _gap(p, first)
		if d < best_gap:
			best_gap = d
			best_t = t
	var start := best_t - CONTEXT_S
	var head := _loop_seq(loop, start, CONTEXT_S - 1.0 / rate, rate)
	var end_pose := _pose(a, best_t)
	var shift := Vector3(first[M.I_PELVIS].x - end_pose[M.I_PELVIS].x, 0.0, first[M.I_PELVIS].z - end_pose[M.I_PELVIS].z)
	var hp: Array = head[1]
	for i in hp.size():
		var q: PackedVector3Array = hp[i]
		for j in q.size():
			q[j] += shift
		hp[i] = q
	var seq := _chain_seq(head, parts, rate)
	var t0: float = (head[0] as PackedFloat64Array)[(head[0] as PackedFloat64Array).size() - 1] + 1.0 / rate
	return {"seq": seq, "t0": t0, "gap": best_gap}


func _gap(p: PackedVector3Array, q: PackedVector3Array) -> float:
	var dp := Vector3(q[M.I_PELVIS].x - p[M.I_PELVIS].x, 0.0, q[M.I_PELVIS].z - p[M.I_PELVIS].z)
	var m := 0.0
	for i: int in M.LOOP_MATCH_PTS:
		m = maxf(m, (p[i] + dp).distance_to(q[i]))
	return m


func _speeds(seq: Array, prior: Variant, t_lo: float, t_hi: float) -> Dictionary:
	var t: PackedFloat64Array = seq[0]
	var od: Dictionary = M._odometry(t, seq[1], prior)
	var w: Array = od.w
	var s := 0.0
	var ws := 0.0
	var f := Vector2.ZERO
	var fw := 0.0
	var l := Vector2.ZERO
	var lw := 0.0
	for k in w.size():
		var tm := 0.5 * (t[k] + t[k + 1])
		var d := t[k + 1] - t[k]
		var v := Vector2((w[k] as Vector3).x, (w[k] as Vector3).z)
		if tm < t_lo - 1e-6 or tm > t_hi + 1e-6:
			continue
		s += v.length() * d
		ws += d
		if tm - t_lo <= 0.2 + 1e-6:
			f += v * d
			fw += d
		if t_hi - tm <= 0.2 + 1e-6:
			l += v * d
			lw += d
	return {"mean": snappedf(s / maxf(ws, 1e-6), 0.01), "first": snappedf((f / maxf(fw, 1e-6)).length(), 0.01),
			"last": snappedf((l / maxf(lw, 1e-6)).length(), 0.01)}
