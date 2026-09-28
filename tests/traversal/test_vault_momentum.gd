extends SceneTree
## A vault plays at its own speed and carries the body at a jog (user 2026-09-27, after the vaults were played up
## to 2.3 x to keep a sprint: "the animation speeds up it should just be normal speed", "the vault should be at the
## jog speed they lose speed back to jog not sprint and if they hold sprint again they rev back up"; before, on
## 2026-09-26: "when we vault the char model should not slow down" and "some things are fast somethings are slow").
## Runs the REAL player (VaultSpeedHarness: FrontierPlayer with PlayerAnim, PlayerTraversal and the weapon in the
## hands, Input.action_press) at the level's vaultable obstacles and checks the speed profile from 1 s before the
## vault to 1.5 s after it:
##
##   sprint (5.6 m/s) and run (3.6 x the musket's 0.92) into the sprint vault's 0.9 m wall, the range's straw truss
##   (0.9 m tall, 0.9 m deep: the sprint vault too) and the firing line's 0.6 m rail (the standing vault):
##     - the approach does not brake: the body's speed over the last second before the move >= APPROACH_KEEP x
##       its speed before it (no stop in front of the obstacle);
##     - the move plays at its clip's own tempo: rate 1 all through;
##     - the body eases down to the carried jog (CARRY, the vaults' momentum carry_max) on the run-in, never under
##       EASE_MIN x it there (no dead stop), then goes over at it: after EASE_S the rendered model and the body stay
##       within CARRY_BAND of it (no surge, no stall, never backwards);
##     - it is handed back at the jog and the locomotion speeds up again to the gait held: the body's speed
##       0.2-0.5 s after the hand-back >= BACK_UP x the speed before the vault (Shift held: the sprint again), the
##       lower body going on in MOVE (no start clip from rest);
##     - planted hands and feet (full-weight IK plants) move at most SLIDE_M while planted (no skating);
##   walk (1.6 m/s x 0.92) into the rail: the controlled vault it was made as (the clip's own timing).
##
##   Godot --headless --fixed-fps 120 --path . -s tests/traversal/test_vault_momentum.gd -- [verbose]
## (about 2 minutes; run it under a time limit). Exit 0 and "VAULT MOMENTUM OK" when every check passes.

const APPROACH_KEEP := 0.97
const CARRY := 2.5                ## m/s: the vaults' momentum carry_max (a jog)
const EASE_S := 0.3               ## the run-in the body eases down over (TravMomentum.EASE_MAX_S)
const EASE_MIN := 0.9             ## ... never under this x CARRY on the way down
const CARRY_BAND := [0.85, 1.15]  ## after the ease, the model and the body stay within this x CARRY
const BACK_UP := 0.95
const SLIDE_M := 0.04
## (truss90: the range's straw trusses, 0.9 m tall and deep, vaulted at speed since 2026-09-27; user: "when im going to a
## haybarell the char slows down to climb and is locked in the animation")
const CASES := [["wall90", "sprint"], ["wall90", "run"], ["fence", "sprint"], ["fence", "run"], ["fence", "walk"],
		["truss90", "sprint"], ["truss90", "run"]]

var _fails: Array[String] = []
var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	InputSetup.ensure()
	var h := VaultSpeedHarness.new(self)
	for c: Array in CASES:
		var r: Dictionary = await h.run(str(c[0]), str(c[1]))
		_check(h, r)
	if _fails.is_empty():
		print("VAULT MOMENTUM OK")
	else:
		for f in _fails:
			printerr("FAIL: ", f)
		print("VAULT MOMENTUM FAILED (%d)" % _fails.size())
	quit(0 if _fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _check(h: VaultSpeedHarness, r: Dictionary) -> void:
	var tag := "%s %s" % [r.obstacle, r.gait]
	print("%s: move %s" % [tag, r.get("move", "-")])
	if not bool(r.get("ok", false)):
		_expect(false, "%s: a vault plays" % tag)
		return
	var fr: Array = h.frames
	var began := float(r.began)
	var ended := float(r.ended)
	var entry := float(r.entry)
	var steady := float(r.steady)
	if _args.has("verbose"):
		for l in VaultSpeedHarness.profile_lines(fr, r, 6):
			print(l)
	if str(r.gait) == "walk":
		# The controlled vault: the clip's own timing.
		_expect(float(r.duration) > 1.2, "%s: plays at the clip's own timing (%.2f s)" % [tag, float(r.duration)])
		return
	# The approach: no brake over the last second.
	var lo := INF
	for f: Dictionary in fr:
		var t := float(f.t) - began
		if t >= -1.0 and t < 0.0:
			lo = minf(lo, float(f.v_cap))
	_expect(lo >= APPROACH_KEEP * steady, "%s: no brake on the approach (lowest %.2f of %.2f m/s)" % [tag, lo, steady])
	var r_lo := INF
	var r_hi := -INF
	for f: Dictionary in fr:
		if str(f.mode) == "MOVE" and float(f.t) >= began and float(f.t) < ended:
			r_lo = minf(r_lo, float(f.rate))
			r_hi = maxf(r_hi, float(f.rate))
	_expect(absf(r_lo - 1.0) < 0.01 and absf(r_hi - 1.0) < 0.01, "%s: the clip's own tempo (rate %.2f..%.2f, %.2f s)" % [tag, r_lo, r_hi, float(r.duration)])
	# Through the move: eased down to the jog on the run-in, then over at it.
	var e_min := INF
	var m_lo := INF
	var m_hi := -INF
	var c_lo := INF
	var c_hi := -INF
	for f: Dictionary in fr:
		var t := float(f.t)
		if t < began or t >= ended:
			continue
		if t < began + EASE_S:
			e_min = minf(e_min, minf(float(f.v_model_s), float(f.v_cap)))
			continue
		m_lo = minf(m_lo, float(f.v_model_s))
		m_hi = maxf(m_hi, float(f.v_model_s))
		c_lo = minf(c_lo, float(f.v_cap))
		c_hi = maxf(c_hi, float(f.v_cap))
	_expect(e_min >= EASE_MIN * CARRY, "%s: eases down to the jog, no dead stop (lowest %.2f m/s in the first %.1f s)" % [tag, e_min, EASE_S])
	_expect(m_lo >= CARRY_BAND[0] * CARRY and m_hi <= CARRY_BAND[1] * CARRY,
			"%s: the model goes over at a jog (%.2f..%.2f m/s)" % [tag, m_lo, m_hi])
	_expect(c_lo >= CARRY_BAND[0] * CARRY and c_hi <= CARRY_BAND[1] * CARRY,
			"%s: the body goes over at a jog (%.2f..%.2f m/s)" % [tag, c_lo, c_hi])
	# The exit and after: the gait held again.
	_expect(float(r.exit) >= BACK_UP * steady, "%s: back up to %.2f m/s after the hand-back (before the vault %.2f)" % [tag, float(r.exit), steady])
	var states := {}
	var capped := false
	for f: Dictionary in fr:
		var t := float(f.t)
		if t >= ended and t < ended + 1.0:
			states[str(f.loco)] = true
			capped = capped or float(f.cap_anim) < INF
	_expect(states.keys() == ["MOVE"] and not capped, "%s: the lower body runs on (states after the move %s)" % [tag, str(states.keys())])
	# (+0.1 mm: the IK's drag limit holds a hand exactly at 4 cm; float noise put it 0.0008 mm over)
	_expect(float(r.slide_max) <= SLIDE_M + 1e-4, "%s: planted hands and feet move %.1f cm at most (%s)" % [tag, float(r.slide_max) * 100.0, str(r.slides)])
