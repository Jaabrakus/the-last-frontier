extends AnimTestSuite
## WP4 (plan G9 "nothing may pop"; plan section 10 test_continuity limit 25 rad/s): continuity of
## what LocoBrain decides, on the real tree: per-frame angular speed of the 53 core bones (the
## bones actor_b-p-run-fw keys) at dt 1/60, bare lower clips (as the review's probes).
##   - strafe reversals D <-> A, A <-> D, W+D <-> S+A, W+A <-> S+D at walk, run, crouch and
##     aimed walk (the direction chains' +-90 seams: each hemisphere keeps its own continuous
##     chain position);
##   - one-shot re-entries (instance stack): run forward, then S n frames, W m frames, S again
##     (reversal -> start -> reversal); release n / press m / release (stop -> start -> stop);
##     from idle press n / release m / press (start -> stop -> start); n, m on a grid;
##   - a re-entered reversal takes the other instance slot and starts at phase 0 (no early
##     fade-0 exit);
##   - a 30 s random input storm (directions, walk / run / sprint, crouch and aim toggles, jumps),
##     and a second one that also turns the camera at random rates, stands still longer and takes
##     random heavy hits;
##   - camera yaw while standing: a flick of -40 / +40 / -90 deg over 6 frames (idle-turn-r / -l,
##     0x0003f590 / 0x0003f560, 0.5 s), then nothing / W / S / D after n frames (the turn's move
##     records, e.g. 0x00033640 / 0x000336a0, 0.2 s), standing and crouched.
## Configurations: the graph default and the overrides G1+G2+G5+crouch crossfade: every frame
## <= 25 rad/s except the frame of an authored fade-0 join into another input from a fully
## weighted one (a one-shot's clip end into its successor). Those cut as the graph does; most
## match exactly, some Actor_B clips do not (crouch-quickstop-bw end -> crouch-walk-bw start 0.88
## rad): they are listed, not counted. With the opt-in LocoBrain.join_fade_s (0.1 s) every frame,
## joins included, is <= 25 rad/s.
## Listed, not counted, in every configuration: the frame of an inertialized stance switch (ch-crouchB:
## a transition into the other stance's input switches the selector at once, info inertialized, and
## PlayerAnim's StanceInertializer blends the shown pose over the record's fade; this rig has no
## modifiers, so the cut shows here: test_continuity and test_crouch_transitions measure the blended pose).
## Idle-turn frames (an idle-turn input weighted in the frame or the one before) are listed, not
## counted, in every configuration: actor_b-p-relax-idle-turn-90-r / -l (and the crouch turns)
## key r_upper_leg, r_ankle and l_ankle local rotations up to 179 deg from rest over phase
## 0.1-0.45, twists that cancel in model space. The clip alone moves them at 26-36 rad/s, and
## Godot blends each input from rest (slerp from identity), so at partial weight (the turn's 0.5 s
## entry and its 0.2 s exits into a start) those rotations flip sides: 80-145 rad/s. A clip data
## defect for the asset pipeline (WP0 / WP2: re-export twist-continuous), not a LocoBrain
## decision; override_no_idle_turns (G5) plays no turn, and there every yaw frame is counted.
## Listed, not counted: frames in which a heavy-hit input fades in (play_hit in the camera-yaw
## storm): the hit is code-entered, its any_to_hit fade is the table's proposed 0.1 s, and from a
## raised crouched aim pose that moves r_shoulder at about 26 rad/s (WP1's proposed value).
## Reported, not counted: frames while the take-off input is weighted (the 0.1 s take-off clip
## itself moves r_knee at 20 rad/s, entry fade the table's proposed 0.1 s); and a pass with the
## musket's carry layers (LocoBrain.drive_carry; UpperBody writes them in game), where the graph's
## fade-0 joins between inputs with different carry-layer sets (reversal -> run-bkwd, take-off ->
## jump) snap the arms (WP1 layer data; join_fade_s smooths them).

const LocoRig := preload("res://tests/anim/loco_rig.gd")
const LIMIT := 25.0
const FW := Vector2(0.0, 1.0)
const BW := Vector2(0.0, -1.0)
const D := Vector2(1.0, 0.0)
const A := Vector2(-1.0, 0.0)
const JOIN_FADE := 0.1
const CONFIGS := [
	{"label": "graph default", "overrides": [], "grid": "full"},
	{"label": "overrides G1+G2+G5+crouch", "overrides": ["override_no_transition_anims", "override_fast_hemisphere_fade",
			"override_no_idle_turns", "override_crouch_crossfade"], "grid": "small"},
	{"label": "graph default + join_fade_s 0.1", "overrides": [], "grid": "small", "join": JOIN_FADE},
]

var _core: Array = []
var _oracle: PoseOracle
var _takeoff := {}
var _turn := {}
var _hit := {}


func describe() -> String:
	return "LocoBrain continuity <= 25 rad/s: strafe reversals (4 stances), one-shot re-entry grids (instance stack), random storm; default, overrides, join fade"


func timeout_s() -> float:
	return 900.0


func run(ctx: AnimTestContext) -> void:
	for cfg: Dictionary in CONFIGS:
		var h = LocoRig.new()
		if not h.setup(ctx, {"overrides": cfg.overrides}):
			return
		h.brain.join_fade_s = float(cfg.get("join", 0.0))
		_setup_common(ctx, h)
		var strict: bool = cfg.has("join")
		var turns: bool = bool(h.data.option("idle_turns", true))
		if cfg.grid == "full":
			_turn_scan(ctx, h)
		_strafe(ctx, h, cfg.label, strict)
		_reentry(ctx, h, cfg.label, cfg.grid == "full", strict)
		if cfg.grid == "full":
			_instance(ctx, h)
		_yaw(ctx, h, cfg.label, cfg.grid == "full", strict, turns)
		_storm(ctx, h, cfg.label, strict, true)
		_storm(ctx, h, cfg.label, strict, true, true, turns)
	# Carry layers on (report): the arms through the graph's fade-0 joins.
	var hc = LocoRig.new()
	if not hc.setup(ctx):
		return
	hc.brain.drive_carry = true
	_setup_common(ctx, hc)
	_storm(ctx, hc, "graph default, musket carry layers", false, false)
	hc.brain.join_fade_s = JOIN_FADE
	_storm(ctx, hc, "musket carry layers + join_fade_s 0.1", false, false)


func _setup_common(ctx: AnimTestContext, h) -> void:
	_oracle = ctx.oracle(h.rig)
	_core = Array(h.rig.keyed_bones("actor_b-p-run-fw"))
	_takeoff.clear()
	_turn.clear()
	_hit.clear()
	for id in h.idx.L_inputs:
		var g := String(h.idx.lower_record(StringName(id)).get("group", ""))
		if g == "takeoff":
			_takeoff[StringName(id)] = true
		elif g.begins_with("turn") or g.begins_with("quick_turn"):
			_turn[StringName(id)] = true
		elif g.begins_with("hit_"):
			_hit[StringName(id)] = true


func _acc(h) -> Dictionary:
	return {"max": 0.0, "at": "", "over": 0, "frames": 0, "prev": h.rig.capture(), "joins": [], "tko": 0, "tko_max": 0.0,
			"turn": 0, "turn_over": 0, "turn_max": 0.0, "turn_at": "", "hit": 0, "hit_max": 0.0, "hit_at": "", "inert": 0,
			"inert_over": []}


## Largest L weight of an idle-turn input.
func _turn_w(h) -> float:
	var w := 0.0
	for id in _turn:
		w = maxf(w, h.L.weight(id))
	return w


## One frame: steps, then folds the per-frame core-bone rotation into acc. The frame of an
## authored fade-0 join (a transition this frame with fade_used 0 into another input) goes to
## acc.joins (when over the limit) unless `strict`; take-off frames go to acc.tko; idle-turn
## frames (a turn input weighted now or in the frame before) to acc.turn (see the header).
func _frame(h, acc: Dictionary, dir: Vector2, speed: float, label: String, strict: bool, extra := {}) -> void:
	var li: int = h.log.size()
	var prev_in: StringName = h.brain.input_id
	var tw0 := _turn_w(h)
	var hw0 := {}
	for id in _hit:
		hw0[id] = h.L.weight(id)
	h.step(dir, speed, extra)
	var join := ""
	var inert := ""
	for j in range(li, h.log.size()):
		var e: Dictionary = h.log[j]
		if float(e.info.get("inertialized", 0.0)) > 0.0:
			inert = "%s %s -> %s, %.2f s" % [e.info.get("record", ""), e.info.get("from_graph", ""), e.info.get("to_graph", ""),
					float(e.info.inertialized)]
		elif float(e.info.get("fade_used", 1.0)) <= 1e-6 and StringName(e.info.get("input_id", "")) != prev_in:
			join = "%s %s -> %s" % [e.info.get("record", ""), e.info.get("from_graph", ""), e.info.get("to_graph", "")]
	var p: PoseOracle.Pose = h.rig.capture()
	var d := _oracle.compare(acc.prev, p, _core, "r")
	acc.prev = p
	acc.frames += 1
	var rate: float = d.max_rot / h.dt
	for id in _takeoff:
		if h.L.weight(id) > 0.0:
			acc.tko += 1
			acc.tko_max = maxf(acc.tko_max, rate)
			return
	for id in _hit:
		if h.L.weight(id) > float(hw0[id]) + 1e-6:
			acc.hit += 1
			if rate > acc.hit_max:
				acc.hit_max = rate
				acc.hit_at = "%s f%d %.1f rad/s %s %s -> %s (w %.2f)" % [label, acc.frames, rate, d.max_rot_bone, h.brain.state,
						id, h.L.weight(id)]
			return
	var tw1 := _turn_w(h)
	if tw0 > 0.0 or tw1 > 0.0:
		acc.turn += 1
		if rate > LIMIT:
			acc.turn_over += 1
		if rate > acc.turn_max:
			acc.turn_max = rate
			acc.turn_at = "%s f%d %.1f rad/s %s %s/%s turn w %.2f -> %.2f" % [label, acc.frames, rate, d.max_rot_bone, h.brain.state,
					h.brain.graph_state, tw0, tw1]
		return
	if inert != "":
		# an inertialized stance switch: the selector cuts, PlayerAnim's StanceInertializer (not on this rig)
		# blends the shown pose over the record's fade (see the header)
		acc.inert += 1
		if rate > LIMIT:
			acc.inert_over.append("%.1f rad/s %s (%s, %s)" % [rate, d.max_rot_bone, inert, h.brain.mode])
		return
	if join != "" and not strict:
		if rate > LIMIT:
			acc.joins.append("%.1f rad/s %s (%s, %s)" % [rate, d.max_rot_bone, join, h.brain.mode])
		return
	if rate > LIMIT:
		acc.over += 1
	if rate > acc.max:
		acc.max = rate
		acc.at = "%s f%d %s %s/%s%s" % [label, acc.frames, d.max_rot_bone, h.brain.state, h.brain.graph_state, (" join " + join) if join != "" else ""]


func _measure(h, acc: Dictionary, n: int, dir: Vector2, speed: float, label: String, strict: bool) -> void:
	for i in n:
		_frame(h, acc, dir, speed, label, strict)


func _strafe(ctx: AnimTestContext, h, label: String, strict: bool) -> void:
	var dirs := [["D<->A", D, A], ["A<->D", A, D], ["W+D<->S+A", Vector2(1, 1), Vector2(-1, -1)],
			["W+A<->S+D", Vector2(-1, 1), Vector2(1, -1)]]
	var stances := [["walk", 1.6, false, false], ["run", 3.6, false, false], ["crouch", 1.4, true, false],
			["aimed walk", 1.99, false, true]]
	var worst := 0.0
	var rows := []
	var joins := []
	for st in stances:
		for dd in dirs:
			h.reset()
			h.crouched = st[2]
			h.aim_stance = st[3]
			h.run(150, dd[1], st[1])
			var acc := _acc(h)
			_measure(h, acc, 70, dd[2], st[1], "there", strict)
			_measure(h, acc, 70, dd[1], st[1], "back", strict)
			worst = maxf(worst, acc.max)
			rows.append("%s %s %.1f" % [st[0], dd[0], acc.max])
			for j in acc.joins:
				joins.append("%s %s: %s" % [st[0], dd[0], j])
			ctx.check(acc.over == 0, "%s: %s %s: max core angular speed %.1f rad/s <= %.0f outside authored joins (%s)" % [
					label, st[0], dd[0], acc.max, LIMIT, acc.at])
	h.crouched = false
	h.aim_stance = false
	ctx.metric("strafe_max_rad_s_%s" % label.get_slice(" ", 0), worst)
	ctx.info("%s: strafe reversal maxima (rad/s): %s" % [label, rows])
	if not joins.is_empty():
		ctx.info("%s: authored fade-0 joins over %.0f rad/s (Actor_B clip data; cut as the graph does, not counted): %s" % [label, LIMIT, joins])


func _reentry(ctx: AnimTestContext, h, label: String, full: bool, strict: bool) -> void:
	var ns: Array = [4, 6, 8, 10, 14, 20] if full else [4, 8, 14]
	var ms: Array = [4, 6, 8, 10, 14, 20, 30] if full else [4, 10, 30]
	var grids := [
		["reversal (S n, W m, S)", true, FW, [BW, FW, BW, BW]],
		["stop -> start -> stop (release n, W m, release)", true, FW, [Vector2.ZERO, FW, Vector2.ZERO, Vector2.ZERO]],
		["start -> stop -> start (W n, release m, W)", false, Vector2.ZERO, [FW, Vector2.ZERO, FW, FW]],
	]
	for g in grids:
		var worst := 0.0
		var worst_at := ""
		var over := 0
		var cases := 0
		var joins := []
		for n in ns:
			for m in ms:
				h.reset()
				if g[1]:
					h.run(120, g[2], 3.6)
				var acc := _acc(h)
				var seq: Array = g[3]
				var lens := [n, m, n, 90]
				for k in 4:
					var dv: Vector2 = seq[k]
					_measure(h, acc, lens[k], dv, 3.6 if dv != Vector2.ZERO else 0.0, "abcd"[k], strict)
				cases += 1
				if acc.over > 0:
					over += 1
				for j in acc.joins:
					joins.append("n %d m %d: %s" % [n, m, j])
				if acc.max > worst:
					worst = acc.max
					worst_at = "n %d m %d %s" % [n, m, acc.at]
		ctx.check(over == 0, "%s: %s grid: %d of %d timings exceed %.0f rad/s outside authored joins (worst %.1f at %s)" % [
				label, g[0], over, cases, LIMIT, worst, worst_at])
		if not joins.is_empty():
			ctx.info("%s: %s: authored fade-0 joins over the limit (not counted): %s" % [label, g[0], joins.slice(0, 6)])


## The reversal re-entered while its first instance still fades out: the other slot, phase 0.
func _instance(ctx: AnimTestContext, h) -> void:
	var rev: StringName = h.idx.input_for("musket/run/rev")
	var slots: Array = h.idx.lower_record(rev).get("instances", [])
	ctx.check(slots.size() == 2, "rev__run has two instance slots: %s" % [slots])
	h.reset()
	h.run(120, FW, 3.6)
	h.log.clear()
	h.run(4, BW, 3.6)
	var first: StringName = h.brain.input_id
	h.run(20, FW, 3.6)
	var i0: int = h.log.size()
	var entered := -1
	for i in 60:
		h.step(BW, 3.6)
		if h.brain.state == LocoBrain.REVERSAL:
			entered = h.frame
			break
	var second: StringName = h.brain.input_id
	var ph: float = h.brain.phase()
	ctx.check(entered > 0 and h.L.weight(first) > 0.0 and second != first and second in slots and ph < 0.05,
			"reversal re-entered while its first instance (%s, L weight %.2f) fades out: slot %s, entry phase %.3f (< 0.05)" % [
			first, h.L.weight(first), second, ph])
	var exit_frame := -1
	for i in 200:
		h.step(BW, 3.6)
		if h.brain.state == LocoBrain.MOVE:
			exit_frame = h.frame
			break
	var tr: Array = h.transitions("", i0)
	var e: Dictionary = tr[tr.size() - 1] if not tr.is_empty() else {}
	ctx.check(exit_frame - entered >= 15 and String(e.get("info", {}).get("record", "")) == "0x00039ff0",
			"the re-entered reversal plays its clip before run-bkwd (0x00039ff0): %d frames after entry (>= 15)" % (exit_frame - entered))


## 30 s of random input. check: fail over the limit (else report only). yaw: the camera also
## turns (random rates up to 230 deg/s for half the holds), with longer standing holds (so the
## idle turns play) and random heavy hits; turns: idle turns are on, so idle-turn frames are
## listed; off (G5): there must be none.
func _storm(ctx: AnimTestContext, h, label: String, strict: bool, check: bool, yaw := false, turns := true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242 if not yaw else 777
	var dirs := [Vector2.ZERO, FW, Vector2(-1, 1), A, Vector2(-1, -1), BW, Vector2(1, -1), D, Vector2(1, 1)]
	h.reset()
	var acc := _acc(h)
	var hold := 0
	var dir := Vector2.ZERO
	var spd := 3.6
	var yaw_rate := 0.0
	for i in 60 * 30:
		if hold <= 0:
			hold = rng.randi_range(3, 60)
			dir = dirs[rng.randi() % dirs.size()]
			if yaw and rng.randf() < 0.35:
				dir = Vector2.ZERO
				hold = rng.randi_range(30, 180)
			var r := rng.randf()
			spd = 1.6 if r < 0.3 else (3.6 if r < 0.85 else 5.6)
			h.sprinting = spd > 5.0 and dir == FW
			if rng.randf() < 0.05:
				h.crouched = not h.crouched
			if rng.randf() < 0.05:
				h.aim_stance = not h.aim_stance
			if yaw:
				yaw_rate = rng.randf_range(-4.0, 4.0) if rng.randf() < 0.5 else 0.0
		hold -= 1
		h.yaw += yaw_rate * h.dt
		var ex := {}
		if rng.randf() < 0.004:
			ex = {"jump": true}
		if yaw and rng.randf() < 0.003:
			h.brain.play_hit(Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
		_frame(h, acc, dir, spd if not h.crouched else 1.4, "storm", strict, ex)
	h.crouched = false
	h.aim_stance = false
	h.sprinting = false
	h.yaw = 0.0
	var what := "30 s random storm%s" % (" with camera yaw" if yaw else "")
	var msg := "%s: %s: %d of %d frames exceed %.0f rad/s%s (worst %.1f at %s)" % [label, what, acc.over,
			acc.frames - acc.tko - acc.turn, LIMIT, "" if strict else " outside authored joins", acc.max, acc.at]
	if check:
		ctx.check(acc.over == 0, msg)
	else:
		ctx.info("REPORT " + msg)
	ctx.info("%s: %s: frames with the take-off input weighted (not counted; clip-intrinsic 20 rad/s + proposed 0.1 s fade): %d, max %.1f rad/s; authored joins over the limit: %s" % [
			label, what, acc.tko, acc.tko_max, acc.joins.slice(0, 6)])
	ctx.info("%s: %s: inertialized stance switches (not counted; StanceInertializer blends them in game): %d, over the limit on this rig: %s" % [
			label, what, acc.inert, acc.inert_over.slice(0, 6)])
	if yaw:
		_turn_report(ctx, label, what, acc, turns)
		ctx.info("%s: %s: heavy-hit entry frames (a hit input fading in over the table's proposed any_to_hit 0.1 s; listed, not counted): %d, max %s" % [
				label, what, acc.hit, acc.hit_at if acc.hit_at != "" else "-"])


## Idle-turn frames: listed with idle turns on (see the header); none may exist without them.
func _turn_report(ctx: AnimTestContext, label: String, what: String, acc: Dictionary, turns: bool) -> void:
	if turns:
		ctx.info("%s: %s: idle-turn frames (listed, not counted; turn-clip data, see the header): %d, %d over %.0f rad/s, max %s" % [
				label, what, acc.turn, acc.turn_over, LIMIT, acc.turn_at if acc.turn_at != "" else "-"])
	else:
		ctx.check(acc.turn == 0, "%s: %s: no idle-turn input is ever weighted with idle turns off (%d frames)" % [label, what, acc.turn])


## Camera yaw while standing (the idle turns): a flick over 6 frames, then after n frames nothing,
## W, S or D (3.6 m/s; crouched 1.4). Frames outside the idle-turn frames and authored joins must
## stay <= 25 rad/s; the idle-turn frames are listed.
func _yaw(ctx: AnimTestContext, h, label: String, full: bool, strict: bool, turns: bool) -> void:
	var flicks: Array = [-40.0, 40.0, -90.0] if full else [-40.0]
	var delays: Array = [0, 10, 25, 40] if full else [10, 40]
	var afters := [["stop", Vector2.ZERO], ["W", FW], ["S", BW], ["D", D]]
	var stances: Array = [false, true] if full else [false]
	var tot := _acc(h)
	var over_cases := 0
	var cases := 0
	var turn_cases := 0
	var rows := []
	for crouch in stances:
		for fl in flicks:
			if crouch and fl != -40.0:
				continue
			for af in afters:
				for n in delays:
					h.reset()
					h.crouched = crouch
					h.run(30 if not crouch else 150)
					var acc := _acc(h)
					for i in 6:
						h.yaw += deg_to_rad(float(fl)) / 6.0
						_frame(h, acc, Vector2.ZERO, 0.0, "flick", strict)
					_measure(h, acc, n, Vector2.ZERO, 0.0, "wait", strict)
					_measure(h, acc, 90, af[1], 3.6 if not crouch else 1.4, af[0], strict)
					cases += 1
					if acc.turn > 0:
						turn_cases += 1
					if acc.over > 0:
						over_cases += 1
						rows.append("%s flick %+.0f %s after %d: %.1f at %s" % ["crouch" if crouch else "stand", fl, af[0], n, acc.max, acc.at])
					if acc.max > tot.max:
						tot.max = acc.max
						tot.at = "%s flick %+.0f %s after %d: %s" % ["crouch" if crouch else "stand", fl, af[0], n, acc.at]
					tot.turn += acc.turn
					tot.turn_over += acc.turn_over
					if acc.turn_max > tot.turn_max:
						tot.turn_max = acc.turn_max
						tot.turn_at = "%s flick %+.0f %s after %d: %s" % ["crouch" if crouch else "stand", fl, af[0], n, acc.turn_at]
					tot.joins.append_array(acc.joins)
	h.crouched = false
	h.yaw = 0.0
	ctx.check(over_cases == 0, "%s: camera-yaw grid (%d cases: flick, then nothing / W / S / D after n frames): %d cases exceed %.0f rad/s outside idle-turn frames%s (worst %.1f at %s) %s" % [
			label, cases, over_cases, LIMIT, "" if strict else " and authored joins", tot.max, tot.at, rows.slice(0, 4)])
	if turns:
		ctx.check(turn_cases > 0, "%s: the camera flicks enter the idle turns (%d of %d cases)" % [label, turn_cases, cases])
	_turn_report(ctx, label, "camera-yaw grid", tot, turns)
	if not tot.joins.is_empty():
		ctx.info("%s: camera-yaw grid: authored fade-0 joins over the limit (not counted): %s" % [label, tot.joins.slice(0, 6)])


## Evidence for the idle-turn listing: per turn clip, the largest local rotation from rest over
## the core bones (Godot blends each input from rest) and the clip's own per-frame rate at 60 Hz.
func _turn_scan(ctx: AnimTestContext, h) -> void:
	var clips := {}
	for id in _turn:
		var c := String(h.idx.lower_record(id).get("clip", ""))
		if c != "":
			clips[c] = true
	var rows := []
	var core := {}
	for b in _core:
		core[String(b)] = true
	for c in clips:
		var a: Animation = h.rig.anim(c)
		if a == null:
			continue
		var worst_rest := 0.0
		var rest_at := ""
		var worst_rate := 0.0
		var rate_at := ""
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var b := String(a.track_get_path(t)).get_slice(":", 1)
			if not core.has(b):
				continue
			var bi: int = h.rig.bone(b)
			if bi < 0:
				continue
			var rest: Quaternion = h.rig.sk.get_bone_rest(bi).basis.get_rotation_quaternion()
			var n := int(ceil(a.length * 60.0))
			var prev: Quaternion = a.rotation_track_interpolate(t, 0.0)
			for i in n + 1:
				var tt := minf(a.length, i / 60.0)
				var q: Quaternion = a.rotation_track_interpolate(t, tt)
				var ang := rad_to_deg(2.0 * acos(clampf(absf((rest.inverse() * q).normalized().w), 0.0, 1.0)))
				if ang > worst_rest:
					worst_rest = ang
					rest_at = "%s u %.2f" % [b, tt / a.length]
				if i > 0:
					var r := prev.angle_to(q) * 60.0
					if r > worst_rate:
						worst_rate = r
						rate_at = "%s u %.2f" % [b, tt / a.length]
				prev = q
		rows.append("%s: max local rotation from rest %.0f deg (%s), clip alone %.1f rad/s (%s)" % [c, worst_rest, rest_at, worst_rate, rate_at])
	rows.sort()
	ctx.info("idle-turn clips (rest-relative blending; for WP0 / WP2): %s" % [rows])
