extends AnimTestSuite
## WP4 (user requirement: graph-faithful by default; plan WP10's start / stop / reversal / turn
## states in scope): the graph's lower-body states as LocoBrain plays them.
##   - every gameplay override is off by default;
##   - start / stop: IDLE -> idle^run-fwd (0x0003f290, 0.2 s) -> run-fw at the start clip's end
##     (0x0003bd60, fade 0, the move bank entered at phase 0) -> run-fw^idle on release
##     (0x0002a8b0, 0.5 s) -> idle at the stop clip's end (0x0003fb40, 0.7 s); the same backward
##     (idle^run-bkwd, run-bk^idle); with G1 idle <-> run-fw directly (0x0003f2c0 / 0x0002a8e0);
##   - reversal: the stick snapped against the motion in run-fw takes the reversal request record
##     (0x0002a850, 0.3 s) into run-fw^run-bkwd-begin, its shim (0x000301d0 at phase 0.1, fade 0,
##     same clip, no seek), and run-bkwd at its end (0x00039ff0, fade 0); and bw -> fw
##     (0x000251d0, 0x0002fab0, 0x0002d530);
##   - idle turns: turning the camera 40 deg left / right while idle plays idle-turn-l / -r
##     (0x0003f560 / 0x0003f590, 0.5 s) until the legs catch up (0x00024c40 / 0x00033910);
##     override_no_idle_turns: none;
##   - crouch toggle while idle: the full-body crouch change (0x0003f3b0, 0.2 s) then crouch idle
##     at its end (0x0003d1b0, 0.7 s); override_crouch_crossfade: straight into crouch idle 0.25 s
##     (a stance change's fade is inertialized since ch-crouchB: fade_used 0, info inertialized);
##   - aim: IDLE -> aim-idle (0.2 s, proposed) -> aim-run-forward when moving (0x000380a0, graph
##     0.5 s; override_fast_aim_to_move 0.3 s) on the move bank -> aim-idle on release
##     (0x00030ab0, 0.5 s) -> idle when the aim ends (0x00037fe0, 0.6 s);
##   - heavy hit: play_hit -> hit clip of the sector, exits to idle at phase 0.9 (0x00040be0,
##     0.25 s); a second hit from the same sector restarts it on the other instance slot (phase 0,
##     0.1 s crossfade, full length again); moving during the hit leaves after its 20-frame gate into the start state
##     (0x00040af0, 0.5 s); death holds its last frame for 3 s; revive -> idle;
##   - crouch and aim toggled in one frame while running backward: no fade-0 cut to another bank
##     (the inertialized stance switch is not a cut);
##   - W, 2 released frames, S at a run: the stop and a backward start by default (move_speed
##     drops on the release frame), the reversal with the opt-in release_grace_s;
##   - every transition carries a transitions key (a graph table row, or a LocoBrain local
##     row), and every graph-status row its record; the pose stays finite;
##   - static: every non-loop record of every graph state LocoBrain plays maps to a key (its row,
##     or the explicit fallback graph_record with the record's own fade), never "".

const LocoRig := preload("res://tests/anim/loco_rig.gd")
const FW := Vector2(0.0, 1.0)
const BW := Vector2(0.0, -1.0)

var _all_logs: Array = []


func describe() -> String:
	return "LocoBrain graph states: start / stop, reversal, idle turns, crouch change, aim, hit, death; overrides off by default; transition keys"


func timeout_s() -> float:
	return 300.0


func run(ctx: AnimTestContext) -> void:
	var h = LocoRig.new()
	if not h.setup(ctx):
		return
	var off := []
	for f in h.data.override_flags():
		if h.data.override_enabled(f):
			off.append(f)
	ctx.check(off.is_empty() and h.data.override_flags().size() >= 8, "all %d gameplay overrides are off by default %s" % [h.data.override_flags().size(), off])
	ctx.check(bool(h.data.option("use_transition_anims", false)) and bool(h.data.option("idle_turns", false))
			and bool(h.data.option("crouch_change_full_body", false)), "graph options on by default: use_transition_anims, idle_turns, crouch_change_full_body")
	_start_stop(ctx, h, FW, ["idle^run-fwd", "run-fw", "run-fw^idle"], ["0x0003f290", "0x0003bd60", "0x0002a8b0", "0x0003fb40"])
	_start_stop(ctx, h, BW, ["idle^run-bkwd", "run-bkwd", "run-bk^idle"], ["0x0003f2f0", "0x00025b80", "0x00025260", "0x0003c2c0"])
	_reversal(ctx, h, FW, BW, ["run-fw^run-bkwd-begin", "run-fw^run-bkwd", "run-bkwd"], ["0x0002a850", "0x000301d0", "0x00039ff0"])
	_reversal(ctx, h, BW, FW, ["run-bw^run-fwd-begin", "run-bw^run-fwd", "run-fw"], ["0x000251d0", "0x0002fab0", "0x0002d530"])
	_turns(ctx, h, true)
	_crouch_idle(ctx, h, false)
	_aim(ctx, h, 0.5)
	_aim_relabel(ctx, h)
	_hit_death(ctx, h)
	_release_gap(ctx, h)
	_keys(ctx, h)
	_static_keys(ctx, h)

	var g1 = LocoRig.new()
	if not g1.setup(ctx, {"overrides": ["override_no_transition_anims", "override_no_idle_turns", "override_crouch_crossfade",
			"override_fast_aim_to_move"]}):
		return
	_g1(ctx, g1)
	_turns(ctx, g1, false)
	_crouch_idle(ctx, g1, true)
	_aim(ctx, g1, 0.3)
	_keys(ctx, g1)


func _reset(h) -> void:
	_all_logs.append_array(h.log)
	h.reset()


func _seq(h) -> Array:
	var out: Array = []
	for e in h.log:
		out.append([String(e.info.to_graph), String(e.info.get("record", ""))])
	return out


## The blend time a transition got: its fade, or, for a stance change (crouch <-> stand) that LocoBrain
## inertializes (ch-crouchB: the selector switches at once, fade_used 0, and StanceInertializer blends the
## shown pose over the record's fade), that fade (info inertialized).
static func _blend_s(info: Dictionary) -> float:
	return float(info.get("inertialized", info.get("fade_used", 0.0)))


func _start_stop(ctx: AnimTestContext, h, d: Vector2, gs: Array, recs: Array) -> void:
	_reset(h)
	h.step(d, 3.6)
	var t0: Dictionary = h.last()
	ctx.check(h.brain.state == LocoBrain.START and h.brain.graph_state == gs[0] and String(t0.info.record) == recs[0]
			and absf(float(t0.info.fade_used) - 0.2) < 1e-6, "%s: idle -> %s (%s, 0.2 s): %s" % [d, gs[0], recs[0], _seq(h)])
	var start_id: StringName = h.brain.input_id
	var n: int = h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE, 400, d, 3.6)
	var tm: Dictionary = h.last()
	var start_len: float = float(h.idx.lower_record(start_id).get("length", 1.0))
	ctx.check(n > 0 and h.brain.graph_state == gs[1] and String(tm.info.record) == recs[1] and is_zero_approx(float(tm.info.fade_used))
			and is_zero_approx(float(tm.info.entry_phase)),
			"%s: %s -> %s at the start clip's end (%s, fade 0, bank entered at phase 0; %d frames, clip %.2f s)" % [
			d, gs[0], gs[1], recs[1], n, start_len])
	h.run(30, d, 3.6)
	h.log.clear()
	h.until(func() -> bool: return h.brain.state == LocoBrain.STOP, 60)
	var ts: Dictionary = h.last()
	ctx.check(h.brain.graph_state == gs[2] and String(ts.info.record) == recs[2] and absf(float(ts.info.fade_used) - 0.5) < 1e-6,
			"%s: release -> %s (%s, 0.5 s): %s" % [d, gs[2], recs[2], _seq(h)])
	h.until(func() -> bool: return h.brain.state == LocoBrain.IDLE, 400)
	var ti: Dictionary = h.last()
	ctx.check(h.brain.graph_state == "idle" and String(ti.info.record) == recs[3] and absf(float(ti.info.fade_used) - 0.7) < 1e-6,
			"%s: %s -> idle at the stop clip's end (%s, 0.7 s): %s" % [d, gs[2], recs[3], _seq(h)])


func _g1(ctx: AnimTestContext, h) -> void:
	_reset(h)
	h.step(FW, 3.6)
	ctx.check(h.brain.graph_state == "run-fw" and String(h.last().info.record) == "0x0003f2c0",
			"G1: idle -> run-fw directly (0x0003f2c0): %s" % [_seq(h)])
	h.run(60, FW, 3.6)
	h.log.clear()
	h.until(func() -> bool: return h.brain.state != LocoBrain.MOVE, 60)
	ctx.check(h.brain.graph_state == "idle" and String(h.last().info.record) == "0x0002a8e0",
			"G1: release -> idle directly (0x0002a8e0, 0.5 s): %s" % [_seq(h)])


func _reversal(ctx: AnimTestContext, h, d0: Vector2, d1: Vector2, gs: Array, recs: Array) -> void:
	_reset(h)
	h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE and h.brain.time_in_state > 0.4, 400, d0, 3.6)
	h.log.clear()
	h.step(d1, 3.6)
	var t0: Dictionary = h.last()
	var rev_id: StringName = h.brain.input_id
	ctx.check(h.brain.state == LocoBrain.REVERSAL and h.brain.graph_state == gs[0] and String(t0.info.record) == recs[0]
			and String(t0.info.key) == "move_reversal" and absf(float(t0.info.fade_used) - 0.3) < 1e-6,
			"snap %s -> %s: reversal request record %s into %s (0.3 s): %s" % [d0, d1, recs[0], gs[0], _seq(h)])
	h.until(func() -> bool: return h.brain.graph_state != gs[0], 60, d1, 3.6)
	var t1: Dictionary = h.last()
	ctx.check(h.brain.graph_state == gs[1] and String(t1.info.record) == recs[1] and is_zero_approx(float(t1.info.fade_used))
			and h.brain.input_id == rev_id and h.brain.phase() >= 0.1 - 1e-6,
			"-begin shim -> %s at phase 0.1 (%s, fade 0, same input, phase %.3f)" % [gs[1], recs[1], h.brain.phase()])
	h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE, 400, d1, 3.6)
	var t2: Dictionary = h.last()
	ctx.check(h.brain.graph_state == gs[2] and String(t2.info.record) == recs[2] and is_zero_approx(float(t2.info.fade_used))
			and is_zero_approx(float(t2.info.entry_phase)),
			"%s -> %s at the reversal clip's end (%s, fade 0, phase 0): %s" % [gs[1], gs[2], recs[2], _seq(h)])


func _turns(ctx: AnimTestContext, h, on: bool) -> void:
	for side in [1.0, -1.0]:
		_reset(h)
		h.yaw = deg_to_rad(40.0 * side)
		h.run(150)
		var s: Array = _seq(h)
		if on:
			var want := [["idle-turn-l", "0x0003f560"], ["idle", "0x00024c40"]] if side > 0.0 else [["idle-turn-r", "0x0003f590"], ["idle", "0x00033910"]]
			ctx.check(s == want and h.brain.state == LocoBrain.IDLE and absf(h.brain.idle_turn_deg) < 5.0,
					"camera turned %+.0f deg while idle: %s then idle once the legs catch up (idle_turn_deg %.2f): %s" % [
					40.0 * side, want[0][0], h.brain.idle_turn_deg, s])
		else:
			ctx.check(s.is_empty(), "override_no_idle_turns: turning the camera %+.0f deg while idle plays no turn: %s" % [40.0 * side, s])
	h.yaw = 0.0


func _crouch_idle(ctx: AnimTestContext, h, override: bool) -> void:
	_reset(h)
	h.crouched = true
	h.run(150)
	var s: Array = _seq(h)
	if override:
		var e: Dictionary = h.log[0] if not h.log.is_empty() else {}
		ctx.check(s.size() == 1 and s[0][0] == "idle" and h.brain.input_id == &"idle__crouch" and absf(_blend_s(e.get("info", {})) - 0.25) < 1e-6,
				"override_crouch_crossfade: crouch toggle while idle -> crouch idle directly, 0.25 s (fade or inertialized): %s %s" % [s,
				e.get("info", {})])
	else:
		ctx.check(s == [["crouch-change-idle^idle", "0x0003f3b0"], ["idle", "0x0003d1b0"]] and h.brain.input_id == &"idle__crouch",
				"crouch toggle while idle -> full-body crouch change (0x0003f3b0) -> crouch idle at its end (0x0003d1b0): %s" % [s])
		var e0: Dictionary = h.log[0] if not h.log.is_empty() else {}
		ctx.check(String(e0.get("info", {}).get("input_id", "")) == "cchange_stand_to_crouch" and absf(_blend_s(e0.get("info", {})) - 0.2) < 1e-6,
				"crouch change plays the stand -> crouch full-body clip (substitute) with 0.2 s (fade or inertialized): %s" % [e0.get("info", {})])
	h.crouched = false
	h.run(150)


func _aim(ctx: AnimTestContext, h, move_fade: float) -> void:
	_reset(h)
	h.aim_stance = true
	h.step()
	ctx.check(h.brain.state == LocoBrain.AIM_IDLE and String(h.last().info.key) == "idle_to_aimidle" and h.brain.input_id == &"aimidle__musket__stand",
			"aim_stance while idle -> aim-idle (idle_to_aimidle 0.2 s, aimidle__musket__stand): %s" % [_seq(h)])
	h.run(10)
	h.log.clear()
	h.step(FW, 1.3)
	var t: Dictionary = h.last()
	ctx.check(h.brain.graph_state == "aim-run-forward" and h.brain.aimed and h.brain.input_id == &"move__walk"
			and String(t.info.record) == "0x000380a0" and absf(float(t.info.fade_used) - move_fade) < 1e-6,
			"aimed and moving -> aim-run-forward on the move bank (0x000380a0, %.2f s): %s" % [move_fade, [_seq(h), h.brain.input_id, t.info.get("fade_used")]])
	h.run(60, FW, 1.3)
	h.log.clear()
	h.until(func() -> bool: return h.brain.state == LocoBrain.AIM_IDLE, 60)
	ctx.check(String(h.last().info.record) == "0x00030ab0", "release while aimed -> aim-idle (0x00030ab0, 0.5 s): %s" % [_seq(h)])
	h.aim_stance = false
	h.log.clear()
	h.step()
	var ti: Dictionary = h.last()
	ctx.check(h.brain.state == LocoBrain.IDLE and String(ti.get("info", {}).get("record", "")) == "0x00037fe0"
			and absf(float(ti.get("info", {}).get("fade_used", 0.0)) - 0.6) < 1e-6,
			"aim ends -> idle (request idle 0x00037fe0, 0.6 s): %s" % [_seq(h)])


## Crouch and aim toggled in the same frame while running backward: the aim relabel (fade 0) must
## not cut to another move bank; the mode change takes its record's fade first. A switch into the
## other stance's input with its record's fade inertialized (ch-crouchB, info inertialized) is that
## fade, not a cut: the selector switches at once and StanceInertializer blends the shown pose.
func _aim_relabel(ctx: AnimTestContext, h) -> void:
	_reset(h)
	h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE and h.brain.hemi == &"bw" and h.brain.time_in_state > 0.3, 400, BW, 3.6)
	var prev: StringName = h.brain.input_id
	h.log.clear()
	h.crouched = true
	h.aim_stance = true
	h.step(FW, 1.4)
	var cuts := []
	var inert := []
	for e in h.log:
		if is_zero_approx(float(e.info.get("fade_used", 1.0))) and String(e.info.get("input_id", "")) != String(prev):
			if float(e.info.get("inertialized", 0.0)) > 0.0:
				inert.append([e.info.get("key"), e.info.get("input_id"), e.info.get("inertialized")])
			else:
				cuts.append([e.info.get("key"), e.info.get("to_graph"), e.info.get("input_id")])
	ctx.check(cuts.is_empty() and (h.L.weight(prev) > 0.5 or not inert.is_empty()),
			"crouch + aim toggled in one frame while running backward: no fade-0 cut to another input (%s), %s keeps L weight %.2f or the switch is inertialized (%s): %s" % [
			cuts, prev, h.L.weight(prev), inert, _seq(h)])
	h.aim_stance = false
	h.crouched = false
	h.run(120)


## Every non-loop record of every graph state LocoBrain plays, into a state LocoBrain knows,
## maps to a transitions key: its table row, or the explicit fallback "graph_record" (the record's
## own fade), never "".
func _static_keys(ctx: AnimTestContext, h) -> void:
	var gsd: Dictionary = h.data.graph.get("graph_states", {})
	var n := 0
	var states := 0
	var empty := []
	var unknown := []
	var fallback := []
	var bad_fade := []
	for st in h.brain._gs:
		if not gsd.has(st):
			continue
		states += 1
		for r: Dictionary in gsd[st].get("transitions", []):
			var tgt := String(r.get("target", ""))
			if String(r.get("request", "auto")) == "auto" and tgt == st:
				continue
			if not (h.brain._gs.has(tgt) or LocoBrain.AIM_REMAP.has(tgt)):
				continue
			n += 1
			var k: String = h.brain.key_for_record(String(r.get("record", "")))
			if k == "":
				empty.append("%s %s -> %s" % [r.get("record"), st, tgt])
			elif k == "graph_record":
				fallback.append("%s %s -> %s (%s)" % [r.get("record"), st, tgt, r.get("request")])
				var u := LocoBrain.record_use(r)
				if absf(float(u.fade_s) - float(r.get("fade_s", 0.0))) > 1e-6 or String(u.record) != String(r.get("record", "")):
					bad_fade.append(r.get("record"))
			elif not (h.data.transition(k).size() > 0 or LocoBrain.LOCAL_ROWS.has(k)):
				unknown.append([r.get("record"), k])
	ctx.check(n > 100 and empty.is_empty() and unknown.is_empty(),
			"static: all %d non-loop records of the %d graph states LocoBrain plays (into states it knows) map to a transitions key: empty %s, unknown %s" % [
			n, states, empty.slice(0, 5), unknown.slice(0, 5)])
	ctx.check(bad_fade.is_empty(), "static: the %d records under the fallback key graph_record keep their own record offset and fade %s" % [fallback.size(), bad_fade])
	ctx.info("records with no WP1 transitions row (fire as graph_record, status graph; for WP1's bindings): %s" % [fallback])


func _hit_death(ctx: AnimTestContext, h) -> void:
	_reset(h)
	h.brain.play_hit(Vector2(0.0, 1.0))
	ctx.check(h.brain.state == LocoBrain.HIT and h.brain.input_id == &"hit_fw__stand" and String(h.last().info.key) == "any_to_hit",
			"play_hit from the front -> HIT hit_fw__stand (any_to_hit): %s" % [h.brain.input_id])
	var n: int = h.until(func() -> bool: return h.brain.state != LocoBrain.HIT, 400)
	var ex: Dictionary = h.last()
	ctx.check(h.brain.state == LocoBrain.IDLE and String(ex.info.record) == "0x00040be0" and absf(float(ex.info.fade_used) - 0.25) < 1e-6,
			"heavy hit exits to idle at phase 0.9 (0x00040be0, 0.25 s) after %d frames" % n)
	_hit_reentry(ctx, h)
	_reset(h)
	h.brain.play_hit(Vector2(1.0, 0.0))
	ctx.check(h.brain.input_id == &"hit_rt__stand", "play_hit from the right -> hit_rt__stand (%s)" % h.brain.input_id)
	h.log.clear()
	n = h.until(func() -> bool: return h.brain.state != LocoBrain.HIT, 400, FW, 3.6)
	var gate: float = float(h.data.transition_use("hit_mode_change").get("gate_s", 0.667))
	ctx.check(h.brain.state == LocoBrain.START and String(h.last().info.record) == "0x00040af0" and absi(n - ceili(gate / h.dt - 1e-6)) <= 1,
			"moving during a heavy hit leaves after its 20-frame gate (%.3f s) into the start state (0x00040af0): %d frames, %s" % [gate, n, _seq(h)])
	_reset(h)
	h.brain.play_death(Vector2(0.0, -1.0))
	ctx.check(h.brain.state == LocoBrain.DEATH and h.brain.input_id == &"death_back", "play_death from behind -> DEATH death_back (%s)" % h.brain.input_id)
	var dn: int = h.until(func() -> bool: return h.brain.phase() >= 1.0 and h.L.weight(h.brain.input_id) >= 1.0, 600)
	ctx.check(dn > 0, "the death clip plays to its end (%d frames)" % dn)
	h.run(2)
	var before: PoseOracle.Pose = h.rig.capture()
	h.log.clear()
	h.run(180, FW, 3.6)
	var after: PoseOracle.Pose = h.rig.capture()
	var oracle := ctx.oracle(h.rig)
	var d := oracle.compare(before, after)
	ctx.check(h.log.is_empty() and h.brain.state == LocoBrain.DEATH, "death holds for 3 s (moving input ignored): %d transitions" % h.log.size())
	ctx.at_most(maxf(d.max_rot, d.max_pos), 1e-4, "death pose holds its last frame for 3 s (max bone change)")
	h.brain.revive()
	ctx.check(h.brain.state == LocoBrain.IDLE and String(h.last().info.key) == "revive", "revive -> IDLE")
	h.run(10)


## The stick released for 2 frames between W and S at a run: move_speed drops on the release frame
## (graph default), so the stop record fires (0x0002a8b0) and S then starts backward from the stop
## (0x0003fc00); with the opt-in release_grace_s (0.05 s) the release is bridged and S takes the
## reversal request record (0x0002a850).
func _release_gap(ctx: AnimTestContext, h) -> void:
	for grace in [0.0, 0.05]:
		_reset(h)
		h.brain.release_grace_s = grace
		h.run(120, FW, 3.6)
		h.log.clear()
		h.run(2)
		h.run(60, BW, 3.6)
		var s: Array = _seq(h)
		var want: Array = [["run-fw^idle", "0x0002a8b0"], ["idle^run-bkwd", "0x0003fc00"]] if grace == 0.0 else [["run-fw^run-bkwd-begin", "0x0002a850"]]
		ctx.check(s.size() >= want.size() and s.slice(0, want.size()) == want,
				"W, 2 frames released, S at a run with release_grace_s %.2f: %s first (%s)" % [grace, want, s.slice(0, 4)])
	h.brain.release_grace_s = 0.0


## A second heavy hit from the same sector while the first plays: the graph starts a new instance
## of the hit state on every entry, so the reaction restarts at phase 0 on the other instance slot,
## crossfading over the first (any_to_hit's fade), and HIT lasts its full 0.9 of the clip again.
## A third hit takes the first slot again.
func _hit_reentry(ctx: AnimTestContext, h) -> void:
	_reset(h)
	var oracle := ctx.oracle(h.rig)
	var core := Array(h.rig.keyed_bones("actor_b-p-run-fw"))
	h.brain.play_hit(Vector2(0.0, 1.0))
	h.run(40)
	var first: StringName = h.brain.input_id
	var slots: Array = h.idx.lower_record(first).get("instances", [])
	var ph0: float = h.brain.phase()
	var prev: PoseOracle.Pose = h.rig.capture()
	h.log.clear()
	h.brain.play_hit(Vector2(0.0, 1.0))
	var second: StringName = h.brain.input_id
	var tr: Dictionary = h.last()
	var worst := 0.0
	var ph1 := -1.0
	var frames := 0
	while h.brain.state == LocoBrain.HIT and frames < 400:
		h.step()
		frames += 1
		if frames == 1:
			ph1 = h.brain.phase()
		if frames <= 30:
			var p: PoseOracle.Pose = h.rig.capture()
			worst = maxf(worst, oracle.compare(prev, p, core, "r").max_rot / h.dt)
			prev = p
	var clip_len := float(h.idx.lower_record(first).get("length", 1.0))
	var want := int(floor(0.9 * clip_len / h.dt)) - 1
	ctx.check(slots.size() == 2 and second != first and second in slots and String(tr.get("info", {}).get("key", "")) == "any_to_hit"
			and absf(float(tr.get("info", {}).get("fade_used", 0.0)) - 0.1) < 1e-6 and ph1 >= 0.0 and ph1 < 0.05,
			"second heavy hit from the front at hit phase %.3f (%s): new instance %s (slots %s), any_to_hit 0.1 s, phase %.3f one frame later" % [
			ph0, first, second, slots, ph1])
	ctx.check(frames >= want, "the re-entered hit plays its clip again: HIT left %d frames after the second hit (>= %d, 0.9 of %.2f s)" % [
			frames, want, clip_len])
	ctx.at_most(worst, 25.0, "second-hit crossfade: max core angular speed over 30 frames (rad/s)")
	_reset(h)
	h.brain.play_hit(Vector2(0.0, 1.0))
	h.run(20)
	h.brain.play_hit(Vector2(0.0, 1.0))
	var b: StringName = h.brain.input_id
	h.run(20)
	h.brain.play_hit(Vector2(0.0, 1.0))
	var c: StringName = h.brain.input_id
	h.step()
	ctx.check(b != c and c == slots[0] and h.brain.phase() < 0.05, "third hit takes the first slot again at phase 0: %s -> %s (phase %.3f)" % [b, c, h.brain.phase()])
	h.run(120)


func _keys(ctx: AnimTestContext, h) -> void:
	_all_logs.append_array(h.log)
	h.log.clear()
	var bad := []
	var no_rec := []
	var used := {}
	for e in _all_logs:
		var k := String(e.info.get("key", ""))
		used[k] = true
		if k == "" or not (h.data.transition(k).size() > 0 or LocoBrain.LOCAL_ROWS.has(k)):
			bad.append([k, e.info.get("to_graph")])
		elif String(e.info.get("status", "")) == "graph" and String(e.info.get("record", "")) == "":
			no_rec.append(k)
	ctx.check(bad.is_empty(), "every transition (%d) carries a transitions key (table row or LocoBrain.LOCAL_ROWS): bad %s" % [_all_logs.size(), bad.slice(0, 5)])
	ctx.check(no_rec.is_empty(), "every graph-status transition carries its record offset: missing %s" % [no_rec])
	var keys := used.keys()
	keys.sort()
	ctx.info("transition keys exercised: %s" % [keys])
	var p: PoseOracle.Pose = h.rig.capture()
	var finite := true
	for i in p.size():
		if not (p.r[i].is_finite() and p.p[i].is_finite()):
			finite = false
	ctx.check(finite, "pose is finite")
	_all_logs.clear()
