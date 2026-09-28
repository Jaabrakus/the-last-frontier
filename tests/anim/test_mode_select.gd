extends AnimTestSuite
## WP4 (plan sections 6.6 and 10): movement mode selection and mode-change fades.
##   - the walk / run split is sqrt(v_walk-fw * v_run-fw) from the clip metrics (2.055 m/s);
##   - the plan 6.6 case table, exactly (from standstill: the nearest side of the split);
##   - hysteresis: inside [split - 0.1, split + 0.1] a moving player keeps its mode;
##   - in MOVE a mode change is the graph's change-move-mode self re-entry (0x0002a970, 0.5 s +- 1
##     frame into the new mode's bank); walk -> sprint the same; a crouch toggle while moving is the
##     same change-move-mode record into the crouch bank (0x0002a970, 0.5 s) by default: since
##     ch-crouchB (LocoBrain._edges) only a toggle while the lower body is not moving sets
##     crouch_change_pending, the gate of the full-body crouch change records; with
##     crouch_pending_while_moving (the earlier literal reading) it takes the graph's first match into
##     the full-body crouch change (0x0002a940, 0.2 s +- 1 frame), and with the gameplay override
##     override_crouch_crossfade on top a plain 0.25 s crossfade into the crouch bank. A stance
##     change's fade is inertialized since ch-crouchB (the selector switches at once and
##     StanceInertializer blends the shown pose over that fade, info inertialized), counted here as
##     that fade;
##   - through LocoBrain the hysteresis band holds (run at 2.0 m/s stays run; 1.9 goes to walk).

const LocoRig := preload("res://tests/anim/loco_rig.gd")

## Plan 6.6: [label, target m/s, crouched, sprinting, expected mode].
const CASES := [
	["walk key bow / pistol", 1.6, false, false, "walk"],
	["walk key musket", 1.47, false, false, "walk"],
	["run bow / pistol", 3.6, false, false, "run"],
	["run musket", 3.31, false, false, "run"],
	["run backward musket", 3.31, false, false, "run"],
	["sprint", 5.6, false, true, "sprint"],
	["crouch bow / pistol", 1.4, true, false, "crouch"],
	["crouch musket", 1.29, true, false, "crouch"],
	["aimed musket running (aim_move 0.6)", 1.99, false, false, "walk"],
	["aimed pistol running (0.8)", 2.88, false, false, "run"],
	["bow drawn running (busy 0.7)", 2.52, false, false, "run"],
	["musket steady aim (x0.5)", 0.99, false, false, "walk"],
	["musket reloading (busy 0.45)", 1.49, false, false, "walk"],
]


func describe() -> String:
	return "LocoBrain mode: split 2.055 m/s, plan 6.6 case table, hysteresis, graph mode-change fades (0.5 / 0.2; crouch override 0.25)"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	var h = LocoRig.new()
	if not h.setup(ctx):
		return
	var brain: LocoBrain = h.brain
	var split: float = brain._split
	var vw: float = h.data.clip_speed("actor_b-p-walk-fw")
	var vr: float = h.data.clip_speed("actor_b-p-run-fw")
	ctx.near(split, sqrt(vw * vr), 1e-9, "split = sqrt(v walk-fw %.3f * v run-fw %.3f)" % [vw, vr])
	ctx.near(split, 2.055, 0.01, "split = 2.055 m/s (plan 6.6)")
	var hyst: float = float(h.data.tuning("mode_split_hysteresis_mps", 0.1))
	var modes: PackedStringArray = h.data.modes()
	var bad := []
	for c in CASES:
		var got := LocoBrain.select_mode(float(c[1]), bool(c[2]), bool(c[3]), &"", split, hyst, modes)
		if String(got) != String(c[4]):
			bad.append("%s: %s (want %s)" % [c[0], got, c[4]])
	ctx.check(bad.is_empty(), "plan 6.6 case table from standstill: %d cases, mismatches %s" % [CASES.size(), bad])
	# Hysteresis while moving.
	var hc := [[&"walk", 2.1, &"walk"], [&"walk", split + hyst + 0.01, &"run"], [&"run", 2.0, &"run"],
			[&"run", split - hyst - 0.01, &"walk"], [&"run", 1.99, &"run"], [&"walk", 2.15, &"walk"]]
	bad = []
	for c in hc:
		var got := LocoBrain.select_mode(float(c[1]), false, false, c[0], split, hyst, modes)
		if got != c[2]:
			bad.append("%s @ %.3f -> %s (want %s)" % [c[0], c[1], got, c[2]])
	ctx.check(bad.is_empty(), "hysteresis band [%.3f, %.3f] keeps the moving mode: %s" % [split - hyst, split + hyst, bad])
	ctx.check(LocoBrain.select_mode(0.0, false, false, &"sprint", split, hyst, modes) == &"sprint"
			and LocoBrain.select_mode(0.0, false, false, &"crouch", split, hyst, modes) == &"run",
			"no move input keeps the mode (leaving crouch while standing takes run)")

	# Through the brain: run -> walk, walk -> sprint, run -> 2.0 m/s (band), -> 1.9 m/s.
	_to_move(ctx, h, 3.6)
	ctx.check(brain.mode == &"run", "running at 3.6 m/s: mode run")
	_mode_fade(ctx, h, "run -> walk (1.6 m/s)", 1.6, false, &"walk", "move_mode_change", "0x0002a970", 0.5)
	_mode_fade(ctx, h, "walk -> sprint (5.6 m/s)", 5.6, true, &"sprint", "move_mode_change", "0x0002a970", 0.5)
	_mode_fade(ctx, h, "sprint -> run (3.6 m/s)", 3.6, false, &"run", "move_mode_change", "0x0002a970", 0.5)
	h.log.clear()
	h.run(60, Vector2(0.0, 1.0), 2.0)
	ctx.check(brain.mode == &"run" and h.log.is_empty(), "run at 2.0 m/s (inside the band) stays run for 1 s: %s, %d transitions" % [brain.mode, h.log.size()])
	h.run(3, Vector2(0.0, 1.0), 1.9)
	ctx.check(brain.mode == &"walk", "1.9 m/s (below the band) goes to walk: %s" % brain.mode)

	# Crouch toggle while moving (ch-crouchB): the graph's change-move-mode record into the crouch bank by
	# default (crouch_change_pending, the full-body crouch change's gate, is set by a toggle while not
	# moving); with crouch_pending_while_moving (the earlier literal reading) the full-body crouch change;
	# with the gameplay override on top of that, a plain crossfade into the crouch bank.
	_to_move(ctx, h, 3.6)
	h.log.clear()
	h.crouched = true
	var n := _fade_frames(h, Vector2(0.0, 1.0), 1.4)
	var t: Array = h.transitions()
	var info: Dictionary = t[0].info if not t.is_empty() else {}
	ctx.check(not t.is_empty() and t[0].to == LocoBrain.MOVE and String(info.key) == "move_mode_change"
			and String(info.record) == "0x0002a970" and String(info.get("input_id", "")) == "move__crouch",
			"crouch toggle while running -> change-move-mode into the crouch bank (0x0002a970): %s" % [
			[t[0].to, info.get("key"), info.get("record"), info.get("input_id")] if not t.is_empty() else "none"])
	var bn := _blend_frames(n, info, h.dt)
	ctx.check(absi(bn - roundi(0.5 / h.dt)) <= 1, "... blends over the record's 0.5 s +- 1 frame (%d frames%s)" % [bn, _how(n, info)])
	h.crouched = false
	h.run(120)

	h.brain.crouch_pending_while_moving = true
	_to_move(ctx, h, 3.6)
	h.log.clear()
	h.crouched = true
	n = _fade_frames(h, Vector2(0.0, 1.0), 1.4)
	t = h.transitions()
	info = t[0].info if not t.is_empty() else {}
	ctx.check(not t.is_empty() and t[0].to == LocoBrain.CCHANGE and String(info.key) == "move_mode_change_crouch"
			and String(info.record) == "0x0002a940" and String(info.to_graph) == "crouch-change-idle^idle",
			"crouch_pending_while_moving: crouch toggle while running -> full-body crouch change (graph first match 0x0002a940): %s" % [
			[t[0].to, info.get("key"), info.get("record"), info.get("to_graph")] if not t.is_empty() else "none"])
	bn = _blend_frames(n, info, h.dt)
	ctx.check(absi(bn - roundi(0.2 / h.dt)) <= 1, "crouch_pending_while_moving: crouch change blends in over 0.2 s +- 1 frame (%d frames%s)" % [
			bn, _how(n, info)])
	h.crouched = false
	h.run(120)
	h.brain.crouch_pending_while_moving = false

	var ho = LocoRig.new()
	if not ho.setup(ctx, {"overrides": ["override_crouch_crossfade"]}):
		return
	ho.brain.crouch_pending_while_moving = true
	_to_move(ctx, ho, 3.6)
	ho.log.clear()
	ho.crouched = true
	n = _fade_frames(ho, Vector2(0.0, 1.0), 1.4)
	t = ho.transitions()
	info = t[0].info if not t.is_empty() else {}
	ctx.check(not t.is_empty() and t[0].to == LocoBrain.MOVE and String(info.input_id) == "move__crouch"
			and String(info.override) == "override_crouch_crossfade",
			"override_crouch_crossfade (crouch_pending_while_moving): crouch toggle while running -> MOVE crouch bank directly: %s" % [
			[t[0].to, info.get("key"), info.get("record"), info.get("input_id"), info.get("override")] if not t.is_empty() else "none"])
	bn = _blend_frames(n, info, ho.dt)
	ctx.check(absi(bn - roundi(0.25 / ho.dt)) <= 1, "override crouch crossfade takes 0.25 s +- 1 frame (%d frames%s)" % [bn, _how(n, info)])


## Frames a transition blends over: its crossfade's (n, see _fade_frames()), or for a stance change that
## LocoBrain inertializes (ch-crouchB: the selector switches at once, n = 1, and StanceInertializer blends the
## shown pose over the record's fade, info inertialized) that fade's.
static func _blend_frames(n: int, info: Dictionary, dt: float) -> int:
	if float(info.get("inertialized", 0.0)) > 0.0 and n == 1:
		return roundi(float(info.inertialized) / dt)
	return n


static func _how(n: int, info: Dictionary) -> String:
	if float(info.get("inertialized", 0.0)) > 0.0:
		return "; inertialized %.2f s, selector switched in %d frame(s)" % [float(info.inertialized), n]
	return "; crossfade"


## Runs forward until MOVE (start clip done).
func _to_move(ctx: AnimTestContext, h, speed: float) -> void:
	var n: int = h.until(func() -> bool: return h.brain.state == LocoBrain.MOVE and h.brain.time_in_state > 0.5, 600,
			Vector2(0.0, 1.0), speed)
	ctx.check(n > 0, "reaches MOVE at %.1f m/s (%d frames)" % [speed, n])


## Frames from the first transition until the L target has full weight (the transition frame
## counts as 1); steps with the given input.
func _fade_frames(h, dir: Vector2, speed: float) -> int:
	var start := -1
	for i in 240:
		h.step(dir, speed)
		if start < 0 and not h.log.is_empty():
			start = i
		if start >= 0 and h.L.weight(h.L.target()) >= 1.0:
			return i - start + 1
	return -1


func _mode_fade(ctx: AnimTestContext, h, label: String, speed: float, sprint: bool, want_mode: StringName,
		key: String, record: String, fade: float) -> void:
	h.log.clear()
	h.sprinting = sprint
	var n := _fade_frames(h, Vector2(0.0, 1.0), speed)
	var t: Array = h.transitions()
	var info: Dictionary = t[0].info if not t.is_empty() else {}
	ctx.check(h.brain.mode == want_mode and not t.is_empty() and t[0].to == LocoBrain.MOVE and String(info.key) == key
			and String(info.record) == record and absf(float(info.fade_used) - fade) < 1e-6,
			"%s: mode %s, %s (record %s, fade %.2f): %s" % [label, want_mode, key, record, fade,
			[h.brain.mode, t[0].to, info.get("key"), info.get("record"), info.get("fade_used"), info.get("input_id")] if not t.is_empty() else "no transition"])
	ctx.check(absi(n - roundi(fade / h.dt)) <= 1, "%s: fade %.2f s +- 1 frame (%d frames)" % [label, fade, n])
	h.run(60, Vector2(0.0, 1.0), speed)
