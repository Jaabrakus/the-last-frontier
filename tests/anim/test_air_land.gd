extends AnimTestSuite
## WP4 (plan sections 6.4, 6.8 and 10): air and landing, graph-faithful by default.
##   - flat jump (4.4 m/s): TAKEOFF on the jump frame (run-jump-long), JUMP when the take-off clip
##     ends (graph record 0x00026ab0, fade 0), LAND on the frame of the landed event (+1) into
##     jump-long-land-idle (landing table, jump / soft / idle: the flat jump's touchdown at phase
##     0.87-0.89 is within LocoBrain.jump_land_gate_tolerance_s of jump-long's 0.9 gate);
##   - a landed and a jumped event consumed in the same frame: LAND, then TAKEOFF;
##   - a 4 m drop: FALL after the coyote time (ground_to_fall: the graph's pre-fall fade 0.5 s,
##     0.3 s with override_fall_fade), then fall-land-hard-idle / -run (hard band);
##   - a 2.5 m drop lands in the medium band (fall-land-medium-idle);
##   - soft idle landing: exits to IDLE at phase 0.6 +- 1 frame (0x00039910, 0.2 s);
##   - walking off a ledge: FALL after the coyote time (+- 1 frame);
##   - holding W at touchdown: graph default leaves an idle landing only after its 10-frame gate
##     (land_move_gate, 0.333 s +- 1 frame, into the start state) and a jump run landing at its
##     phase 0.9 (0x0003f730); with the gameplay override G6 (override_immediate_land_move) the
##     landing is left within 1 frame (plan acceptance "MOVE within 1 frame (G6)");
##   - backpedalling at touchdown picks the backward landing and exits into run-bkwd.

const LocoRig := preload("res://tests/anim/loco_rig.gd")


func describe() -> String:
	return "LocoBrain air / land: jump chain, landing kinds (jump, soft, medium, hard, backward), exit phases and gates, coyote, G6 override"


func timeout_s() -> float:
	return 300.0


func run(ctx: AnimTestContext) -> void:
	var h = LocoRig.new()
	if not h.setup(ctx):
		return
	_flat_jump(ctx, h)
	_land_and_jump_same_frame(ctx, h)
	_jump_run(ctx, h, false)
	_drop(ctx, h, 4.0, false, "fall-land-hard-idle", "hard", 0.5)
	_drop(ctx, h, 4.0, true, "fall-land-hard-run", "hard", 0.5)
	_drop(ctx, h, 2.5, false, "fall-land-medium-idle", "medium", 0.5)
	_soft_idle_exit(ctx, h)
	_ledge(ctx, h)
	_land_move_gate(ctx, h, false)
	_backward(ctx, h)
	var g6 = LocoRig.new()
	if not g6.setup(ctx, {"overrides": ["override_immediate_land_move", "override_fall_fade"]}):
		return
	_jump_run(ctx, g6, true)
	_land_move_gate(ctx, g6, true)
	_drop(ctx, g6, 4.0, false, "fall-land-hard-idle", "hard", 0.3)


func _reset(h) -> void:
	h.reset()


func _event_frame(h, t: String) -> int:
	for e in h.events_seen:
		if String(e.event.t) == t:
			return int(e.frame)
	return -1


func _first(h, key: String) -> Dictionary:
	var t: Array = h.transitions(key)
	return t[0] if not t.is_empty() else {}


func _flat_jump(ctx: AnimTestContext, h) -> void:
	_reset(h)
	h.step(Vector2.ZERO, 0.0, {"jump": true})
	h.until(func() -> bool: return h.brain.state == LocoBrain.LAND, 200)
	var jf := _event_frame(h, "jumped")
	var lf := _event_frame(h, "landed")
	var tk := _first(h, "ground_to_takeoff")
	var tj := _first(h, "takeoff_to_jump")
	var tl := _first(h, "air_to_land")
	ctx.check(not tk.is_empty() and tk.frame == jf and String(tk.info.to_graph) == "run-jump-long",
			"flat jump: TAKEOFF (run-jump-long) on the jump frame %d: %s" % [jf, [tk.get("frame"), tk.get("info", {}).get("to_graph")]])
	var tko_len: float = h.data.clip_length("actor_b-p-run^jump-long")
	ctx.check(not tj.is_empty() and String(tj.info.record) == "0x00026ab0" and is_zero_approx(float(tj.info.fade_used))
			and absi(int(tj.frame) - jf - roundi(tko_len / h.dt)) <= 1,
			"JUMP when the %.2f s take-off clip ends (record 0x00026ab0, fade 0): after %s frames" % [tko_len, (int(tj.frame) - jf) if not tj.is_empty() else "-"])
	ctx.check(not tl.is_empty() and lf > 0 and int(tl.frame) - lf >= 0 and int(tl.frame) - lf <= 1
			and String(tl.info.to_graph) == "jump-long-land-idle",
			"LAND within 1 frame of the landed event (frame %d) into jump-long-land-idle, the target of jump-long's own landing record 0x000256a0: %s" % [lf,
			[tl.get("frame"), tl.get("info", {}).get("to_graph"), tl.get("info", {}).get("landing")] if not tl.is_empty() else "none"])
	var sel: Dictionary = tl.get("info", {}).get("landing", {})
	ctx.check(sel.get("kind") == "jump" and sel.get("band") == "soft" and sel.get("dir") == "idle",
			"flat jump lands in the jump table, soft band, idle (touchdown within %.3f s of the phase-0.9 gate counts as reaching it; impact %.2f m/s)" % [
			h.brain.jump_land_gate_tolerance_s, float(sel.get("impact", 0.0))])


## A landed and a jumped consumed in the same animation frame (physics 120 Hz, render 60 Hz):
## both apply in order (LAND, then TAKEOFF) and the jump is recorded for the landing table.
func _land_and_jump_same_frame(ctx: AnimTestContext, h) -> void:
	_reset(h)
	h.step(Vector2.ZERO, 0.0, {"jump": true})
	h.until(func() -> bool: return h.brain.state == LocoBrain.JUMP, 60)
	h.log.clear()
	var t_before: float = h.brain._last_jump_t
	var inp: AnimInputs = h._make_inputs([{"t": "landed", "impact": 4.4}, {"t": "jumped"}])
	inp.on_floor = false
	h.frame += 1
	h.brain.step(inp, inp.events, h.dt, h.weapon, false)
	h.tree.advance(h.dt)
	var keys: Array = h.log.map(func(e: Dictionary) -> String: return String(e.info.key))
	ctx.check(keys == ["air_to_land", "ground_to_takeoff"] and h.brain.state == LocoBrain.TAKEOFF and h.brain._last_jump_t > t_before,
			"landed + jumped in one frame: LAND then TAKEOFF in order (%s, state %s), the new jump recorded (%s)" % [
			keys, h.brain.state, h.brain._last_jump_t > t_before])
	h.until(func() -> bool: return h.on_floor and h.brain.state != LocoBrain.JUMP and h.brain.state != LocoBrain.TAKEOFF, 200)
	h.run(120)


func _jump_run(ctx: AnimTestContext, h, g6: bool) -> void:
	_reset(h)
	h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE and h.brain.time_in_state > 0.3, 400, Vector2(0.0, 1.0), 3.6)
	h.log.clear()
	h.events_seen.clear()
	h.step(Vector2(0.0, 1.0), 3.6, {"jump": true})
	h.until(func() -> bool: return h.brain.state == LocoBrain.LAND, 200, Vector2(0.0, 1.0), 3.6)
	var land := _first(h, "air_to_land")
	ctx.check(not land.is_empty() and String(land.info.to_graph) == "jump-long-land-run",
			"%s: running jump holding W lands in jump-long-land-run: %s" % ["G6" if g6 else "graph default",
			land.get("info", {}).get("to_graph", "none")])
	var r := _until_leave_land(h, Vector2(0.0, 1.0), 3.6)
	var n: int = r.n
	var ph_before: float = r.phase
	var ex: Dictionary = h.last()
	if g6:
		ctx.check(n == 1 and ex.to == LocoBrain.MOVE, "G6 override: holding W at touchdown -> MOVE within 1 frame (%d frames, %s via %s)" % [
				n, ex.get("to"), ex.get("info", {}).get("key")])
	else:
		# The exit fires on the first tick whose phase (read before the tick) is >= 0.9.
		ctx.check(ex.to == LocoBrain.MOVE and String(ex.info.record) == "0x0003f730" and String(ex.info.key) == "land_run_exit",
				"graph default: jump-long-land-run exits into MOVE by its phase record 0x0003f730 (land_run_exit): %s" % [
				[ex.get("to"), ex.get("info", {}).get("record"), ex.get("info", {}).get("key")]])
		var step_ph: float = h.dt / h.data.clip_length("actor_b-p-land-med^run")
		ctx.check(ph_before >= 0.9 - 1e-6 and ph_before < 0.9 + step_ph + 1e-6,
				"graph default: that exit happens at phase 0.9 +- 1 frame (phase %.4f, %d frames after touchdown, not at once)" % [ph_before, n])


func _drop(ctx: AnimTestContext, h, height: float, moving: bool, want_gs: String, band: String, fall_fade: float) -> void:
	_reset(h)
	var wd := Vector2(0.0, 1.0) if moving else Vector2.ZERO
	var spd := 1.6 if moving else 0.0
	if moving:
		h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE, 400, wd, spd)
	h.log.clear()
	h.events_seen.clear()
	h.floor_y = -height
	h.until(func() -> bool: return h.brain.state == LocoBrain.LAND, 400, wd, spd)
	var ff := _event_frame(h, "fell")
	var tf := _first(h, "ground_to_fall")
	var tl := _first(h, "air_to_land")
	var lf := _event_frame(h, "landed")
	var coyote: float = float(h.data.tuning("coyote_s", 0.15))
	var want_f := ff + _coyote_frames(h.dt, coyote)
	ctx.check(not tf.is_empty() and absi(int(tf.frame) - want_f) <= 1 and absf(float(tf.info.fade_used) - fall_fade) < 1e-6,
			"%.1f m drop%s: FALL after the %.2f s coyote time (frame %s, fell at %d) with fade %.2f" % [height,
			" moving" if moving else "", coyote, tf.get("frame", "-"), ff, fall_fade])
	var sel: Dictionary = tl.get("info", {}).get("landing", {})
	ctx.check(not tl.is_empty() and int(tl.frame) - lf <= 1 and String(tl.info.to_graph) == want_gs and sel.get("band") == band,
			"%.1f m drop%s lands (impact %.2f m/s, band %s) in %s within 1 frame: %s" % [height, " moving" if moving else "",
			float(sel.get("impact", 0.0)), band, want_gs, tl.get("info", {}).get("to_graph", "none")])
	h.floor_y = 0.0
	h.y = 0.0


func _soft_idle_exit(ctx: AnimTestContext, h) -> void:
	_reset(h)
	h.floor_y = -0.5
	h.until(func() -> bool: return h.brain.state == LocoBrain.LAND, 400)
	var tl := _first(h, "air_to_land")
	ctx.check(not tl.is_empty() and String(tl.info.to_graph) == "fall-land-soft-idle",
			"0.5 m drop standing lands in fall-land-soft-idle: %s" % tl.get("info", {}).get("to_graph", "none"))
	var r := _until_leave_land(h, Vector2.ZERO, 0.0)
	var ex: Dictionary = h.last()
	var ph_before: float = r.phase
	var step_ph: float = h.dt / h.data.clip_length("actor_b-p-land-soft^stealth-idle")
	ctx.check(ex.to == LocoBrain.IDLE and String(ex.info.record) == "0x00039910" and absf(float(ex.info.fade_used) - 0.2) < 1e-6,
			"soft idle landing exits to IDLE by 0x00039910 with 0.2 s: %s" % [[ex.get("to"), ex.get("info", {}).get("record"), ex.get("info", {}).get("fade_used")]])
	ctx.check(ph_before >= 0.6 - 1e-6 and ph_before < 0.6 + step_ph + 1e-6, "soft idle exit at phase 0.6 +- 1 frame (phase %.4f)" % ph_before)
	h.floor_y = 0.0
	h.y = 0.0


func _ledge(ctx: AnimTestContext, h) -> void:
	_reset(h)
	h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE, 400, Vector2(0.0, 1.0), 1.6)
	h.log.clear()
	h.events_seen.clear()
	h.floor_y = -3.0
	h.until(func() -> bool: return h.brain.state == LocoBrain.FALL, 60, Vector2(0.0, 1.0), 1.6)
	var ff := _event_frame(h, "fell")
	var tf := _first(h, "ground_to_fall")
	var want_f := ff + _coyote_frames(h.dt, float(h.data.tuning("coyote_s", 0.15)))
	ctx.check(not tf.is_empty() and absi(int(tf.frame) - want_f) <= 1 and String(tf.info.from_graph) == "run-fw",
			"walking off a ledge: MOVE -> FALL after the coyote time (frame %s, want %d +- 1)" % [tf.get("frame", "-"), want_f])
	h.until(func() -> bool: return h.brain.state == LocoBrain.LAND, 400, Vector2(0.0, 1.0), 1.6)
	h.floor_y = 0.0
	h.y = 0.0


func _land_move_gate(ctx: AnimTestContext, h, g6: bool) -> void:
	_reset(h)
	h.floor_y = -0.5
	h.until(func() -> bool: return h.brain.state == LocoBrain.LAND, 400)
	var land := _first(h, "air_to_land")
	ctx.check(not land.is_empty() and String(land.info.to_graph) == "fall-land-soft-idle", "standing drop lands in fall-land-soft-idle")
	h.log.clear()
	var n: int = h.until(func() -> bool: return h.brain.state != LocoBrain.LAND, 200, Vector2(0.0, 1.0), 3.6)
	var ex: Dictionary = h.last()
	var gate: float = float(h.data.graph.get("gates", {}).get("land_move_gate", {}).get("use_s", 0.333333))
	if g6:
		ctx.check(n == 1 and ex.to in [LocoBrain.START, LocoBrain.MOVE] and String(ex.info.override) == "override_immediate_land_move",
				"G6 override: W pressed after touchdown leaves the idle landing within 1 frame (%d frames, %s, %s)" % [n, ex.get("to"), ex.get("info", {}).get("key")])
	else:
		# Entered on the landing tick; time_in_state reaches the gate after gate / dt ticks.
		var want := ceili(gate / h.dt - 1e-6)
		ctx.check(ex.to == LocoBrain.START and String(ex.info.key) == "land_to_move" and absi(n - want) <= 1,
				"graph default: W pressed after touchdown leaves fall-land-soft-idle into START after the 10-frame gate (%.3f s): %d frames (%d +- 1), %s %s" % [
				gate, n, want, ex.get("to"), ex.get("info", {}).get("record")])
	h.floor_y = 0.0
	h.y = 0.0


func _backward(ctx: AnimTestContext, h) -> void:
	_reset(h)
	h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE and h.brain.hemi == &"bw", 400, Vector2(0.0, -1.0), 3.6)
	h.log.clear()
	h.floor_y = -0.8
	h.until(func() -> bool: return h.brain.state == LocoBrain.LAND, 400, Vector2(0.0, -1.0), 3.6)
	var tl := _first(h, "air_to_land")
	ctx.check(not tl.is_empty() and String(tl.info.to_graph) == "fall-land-soft-run-bw",
			"backpedalling off a 0.8 m ledge lands in fall-land-soft-run-bw: %s" % tl.get("info", {}).get("to_graph", "none"))
	h.until(func() -> bool: return h.brain.state != LocoBrain.LAND, 400, Vector2(0.0, -1.0), 3.6)
	var ex: Dictionary = h.last()
	ctx.check(ex.to == LocoBrain.MOVE and h.brain.hemi == &"bw" and String(ex.info.to_graph) == "run-bkwd",
			"the backward landing exits into run-bkwd: %s" % [[ex.get("to"), ex.get("info", {}).get("to_graph"), ex.get("info", {}).get("record"), ex.get("info", {}).get("key")]])
	h.floor_y = 0.0
	h.y = 0.0


## Steps until the brain leaves LAND; {n: frames, phase: the phase read before the last tick}.
func _until_leave_land(h, dir: Vector2, speed: float) -> Dictionary:
	var ph := -1.0
	for i in 400:
		ph = h.brain.phase()
		h.step(dir, speed)
		if h.brain.state != LocoBrain.LAND:
			return {"n": i + 1, "phase": ph}
	return {"n": -1, "phase": ph}


## Frames after the "fell" frame until air_time (accumulated per frame from dt on the fell frame)
## exceeds the coyote time.
static func _coyote_frames(dt: float, coyote: float) -> int:
	var t := dt
	var j := 0
	while not t > coyote:
		t += dt
		j += 1
	return j
