extends AnimTestSuite
## WP5 (plan sections 6.10 and 10): hits and death, upper-body side (LocoBrain, WP4, owns the
## full-body hit / death inputs and their exits; here the lower input is set by hand).
##   - light hit (G8): the hit_add_by_stance additive of the 90 deg sector the hit came from
##     plays; it changes only the bones that clip keys (the 10 hr-bliz spine / neck bones), every
##     other bone stays within 1e-4 rad / 1e-4 m of an identical run without the hit, stand and
##     crouch; it is gone by the graph's exit at phase 0.9 (hit_add_exit 0x000323b0) + 1 frame;
##   - heavy hit: the aimed upper body is suppressed (U_aim and the stabilizer weight reach 0
##     within 0.1 s + 1 frame) while the lower body is in HIT, and comes back within 0.2 s + 1
##     frame after it leaves;
##   - death: every OneShot fades out (a reload in progress, the fire additive), U_aim goes to 0,
##     actions are ignored, and once the death clip has ended the pose holds for 5 s (no bone
##     moves more than 1e-4);
##   - revive: suppression lifts and actions play again (LocoBrain.revive sets IDLE);
##   - with LocoBrain (WP4) in the loop, PlayerAnim frame order (plan section 10's lower-body rows
##     of this suite): a heavy hit while aimed and standing still leaves HIT at the graph's exit
##     phase 0.9 (hit_exit 0x00040be0, +- 1 frame) and the upper body is suppressed until then
##     and follows the weapon again within 0.2 s after; moving during the hit leaves it for the
##     movement start before phase 0.9 (hit_to_move 0x00040af0 once hit_mode_change's gate has
##     passed); death holds, and revive returns to IDLE.

const UpperRig := preload("res://tests/anim/upper_rig.gd")
const DT := 1.0 / 60.0
const TOL := 1e-4


func describe() -> String:
	return "hits / death: light-hit additive bones only, exit at 0.9, heavy-hit and death suppression, death hold, revive"


func timeout_s() -> float:
	return 300.0


func run(ctx: AnimTestContext) -> void:
	await _light(ctx)
	await _heavy_and_death(ctx)
	await _with_loco(ctx)


## LocoBrain and UpperBody together: heavy-hit exits (phase 0.9, or on move), suppression, death,
## revive -> IDLE.
func _with_loco(ctx: AnimTestContext) -> void:
	var h = UpperRig.new()
	if not h.setup(ctx):
		return
	var ua: StringName = h.idx.params.U_aim
	h.inp.weapon_aim = 1.0
	h.inp.wants_aim = true
	h.attach_loco()
	h.step(40)
	ctx.check(h.loco.state == LocoBrain.AIM_IDLE and float(h.tree.get(ua)) >= 1.0 - 1e-6, "loco: aimed standing -> AIM_IDLE, U_aim 1 (%s)" % h.loco.state)
	var gate := float(h.data.threshold("hit_full_exit_phase", 0.9))

	# Heavy hit, standing still: exit at phase 0.9.
	h.loco.play_hit(Vector2(0, 1))
	h.upper.on_hurt(Vector2(0, 1), 60.0, true)
	var r := _run_hit(h, ua, 300)
	var hit_len := float(h.idx.lower_record(r.input).get("length", 1.3))
	var dphase := UpperRig.DT / maxf(hit_len, 1e-3)
	ctx.check(r.entered, "loco: heavy hit -> HIT (%s)" % r.input)
	ctx.check(r.exit_to in [LocoBrain.IDLE, LocoBrain.AIM_IDLE], "loco: heavy hit standing still leaves HIT for idle / aim idle (%s)" % r.exit_to)
	ctx.near(r.exit_phase, gate + 0.5 * dphase, 0.5 * dphase + 1e-4, "loco: heavy hit exits at phase %.1f (+ 1 frame; phase read when it left)" % gate)
	ctx.check(r.suppressed_in_hit, "loco: the aimed upper body is suppressed while in HIT (U_aim 0)")
	h.step(roundi(0.2 / UpperRig.DT) + 1)
	ctx.near(float(h.tree.get(ua)), 1.0, 1e-6, "loco: 0.2 s + 1 frame after HIT the upper body follows the weapon again (U_aim)")

	# Heavy hit, then moving: leaves HIT for the movement start before phase 0.9. (From behind: a
	# second hit on the same hit input leaves HIT at once, LocoBrain reading the input's frozen
	# end phase before its entry seek applies; WP4 issue, reported.)
	h.step(30)
	h.loco.play_hit(Vector2(0, -1))
	h.upper.on_hurt(Vector2(0, -1), 60.0, true)
	h.step(6)
	h.move(Vector2(0, 1), 3.6)
	var m := _run_hit(h, ua, 300)
	ctx.check(m.exit_to in [LocoBrain.START, LocoBrain.MOVE] and m.exit_phase < gate,
			"loco: moving during a heavy hit leaves HIT for %s at phase %.3f (< %.1f), %.3f s after the hit" % [m.exit_to, m.exit_phase, gate, m.exit_t + 6 * UpperRig.DT])
	h.move()
	h.step(90)

	# Death, then revive -> IDLE.
	h.loco.play_death(Vector2(0, 1))
	h.upper.on_died(Vector2(0, 1))
	h.inp.alive = false
	h.step(roundi(3.0 / UpperRig.DT))
	ctx.check(h.loco.state == LocoBrain.DEATH and float(h.tree.get(ua)) <= 1e-6, "loco: death holds (state %s, U_aim %.3f)" % [h.loco.state, float(h.tree.get(ua))])
	h.inp.alive = true
	h.loco.revive()
	h.upper.on_revive()
	ctx.check(h.loco.state == LocoBrain.IDLE, "loco: revive -> IDLE (%s)" % h.loco.state)
	h.step(30)
	ctx.near(float(h.tree.get(ua)), 1.0, 1e-6, "loco: after revive the upper body follows the weapon again (U_aim)")


## Steps until LocoBrain leaves HIT: {entered, input, exit_to, exit_phase (the last phase read in
## HIT), exit_t, suppressed_in_hit}.
func _run_hit(h, ua: StringName, max_frames: int) -> Dictionary:
	var out := {"entered": h.loco.state == LocoBrain.HIT, "input": h.loco.input_id, "exit_to": &"", "exit_phase": -1.0,
			"exit_t": 0.0, "suppressed_in_hit": false}
	var last := 0.0
	var t := 0.0
	for f in max_frames:
		if h.loco.state == LocoBrain.HIT:
			last = h.loco.phase()
		h.step(1)
		t += UpperRig.DT
		if h.loco.state == LocoBrain.HIT:
			out.entered = true
			out.input = h.loco.input_id
			if float(h.tree.get(ua)) <= 1e-6:
				out.suppressed_in_hit = true
		elif out.entered:
			out.exit_to = h.loco.state
			out.exit_phase = last
			out.exit_t = t
			break
	return out


func _light(ctx: AnimTestContext) -> void:
	var a = UpperRig.new()
	var b = UpperRig.new()
	if not a.setup(ctx) or not b.setup(ctx):
		return
	for st in ["stand", "crouch"]:
		for pair in [[Vector2(0, 1), "fw"], [Vector2(-1, 0.2), "lt"], [Vector2(0.9, -0.1), "rt"], [Vector2(0.1, -1), "bw"]]:
			var dir: Vector2 = pair[0]
			ctx.check(UpperBody.hit_dir(dir) == pair[1], "hit from %s -> sector %s" % [dir, pair[1]])
		for h in [a, b]:
			h.snap(&"musket", st, 0.0, 0.0)
			h.inp.weapon_aim = 0.0
			h.set_lower(h.idx.input_for("musket/%s/idle" % ("crouch" if st == "crouch" else "run")), 0.3, &"IDLE")
			h.step(10)
		var clip := String(b.idx.hit_add.get("%s/fw" % st, b.idx.hit_add.get("fw", "")))
		var rec: Dictionary = b.idx.oneshot("HA", clip)
		var keyed: PackedStringArray = b.rig.keyed_bones(clip)
		ctx.check(not rec.is_empty() and keyed.size() == 10, "%s light hit from the front plays %s (%d keyed bones)" % [st, clip, keyed.size()])
		b.upper.on_hurt(Vector2(0, 1), 10.0, false)
		var other := 0.0
		var other_pos := 0.0
		var other_bone := ""
		var hit_max := 0.0
		var t := 0.0
		var off_at := INF
		var exit_t := float(rec.get("length", 1.0)) * float(b.data.transition_use("hit_add_exit").get("gate_phase", 0.9))
		for f in roundi((exit_t + 0.3) / DT):
			a.step(1)
			b.step(1)
			t += DT
			for i in a.rig.sk.get_bone_count():
				var n: String = a.rig.sk.get_bone_name(i)
				var dq := PoseOracle.qdist(a.rig.sk.get_bone_pose_rotation(i), b.rig.sk.get_bone_pose_rotation(i))
				var dp: float = a.rig.sk.get_bone_pose_position(i).distance_to(b.rig.sk.get_bone_pose_position(i))
				if keyed.has(n):
					hit_max = maxf(hit_max, dq)
				elif dq > other or dp > other_pos:
					other = maxf(other, dq)
					other_pos = maxf(other_pos, dp)
					other_bone = n
			if off_at == INF and not b.oneshot_active(rec.node):
				off_at = t
		ctx.at_most(other, TOL, "%s light hit: bones the additive does not key unchanged (rad; worst %s)" % [st, other_bone])
		ctx.at_most(other_pos, TOL, "%s light hit: bone positions outside the additive unchanged (m)" % st)
		ctx.at_least(hit_max, 0.02, "%s light hit: the 10 hr-bliz bones react (rad)" % st)
		ctx.at_most(off_at, exit_t + 1.5 * DT, "%s light hit: additive gone by the graph exit at phase 0.9 (%.3f s) (s)" % [st, exit_t])


func _heavy_and_death(ctx: AnimTestContext) -> void:
	var h = UpperRig.new()
	if not h.setup(ctx):
		return
	var u: UpperBody = h.upper
	var ua: StringName = h.idx.params.U_aim
	h.snap(&"musket", "stand", 0.0, 0.0)
	h.inp.weapon_aim = 1.0
	h.set_lower(&"aimidle__musket__stand", 0.0, &"AIM_IDLE")
	h.step(10)
	ctx.near(float(h.tree.get(ua)), 1.0, 1e-6, "aimed before the hit: U_aim 1")
	# Heavy hit: LocoBrain plays the full-body hit (lower state HIT).
	u.on_hurt(Vector2(0, 1), 60.0, true)
	h.set_lower(h.idx.input_for("musket/run/hit_full/fw"), 0.0, &"HIT")
	var t := 0.0
	var zero_at := INF
	for f in 48:
		h.step(1)
		t += DT
		if zero_at == INF and float(h.tree.get(ua)) <= 1e-6 and h.stab.weight <= 1e-6:
			zero_at = t
	ctx.at_most(zero_at, 0.1 + DT + 1e-6, "heavy hit: U_aim and stabilizer weight reach 0 within 0.1 s + 1 frame (s)")
	h.set_lower(&"aimidle__musket__stand", 0.0, &"AIM_IDLE")
	t = 0.0
	var back_at := INF
	for f in 30:
		h.step(1)
		t += DT
		if back_at == INF and float(h.tree.get(ua)) >= 1.0 - 1e-6:
			back_at = t
	ctx.at_most(back_at, 0.2 + DT + 1e-6, "heavy hit over (lower left HIT): U_aim back to 1 within 0.2 s + 1 frame (s)")

	# Death during a reload, just after a shot.
	h.inp.weapon_aim = 0.0
	h.set_lower(h.idx.input_for("musket/run/idle"), 0.0, &"IDLE")
	h.step(20)
	u.on_fired(&"musket")
	u.on_action("reload_begin", 1.3, &"musket")
	h.step(20)
	var playing := []
	for n in h.idx.oneshots:
		if h.oneshot_active(n):
			playing.append(n)
	ctx.check(playing.size() >= 3, "before death: fire additive and reload (partial + twin) playing %s" % [playing])
	var death_id: StringName = h.idx.input_for("musket/run/death")
	ctx.check(death_id != &"", "death input for musket/run (%s)" % death_id)
	u.on_died(Vector2(0, 1))
	h.inp.alive = false
	h.set_lower(death_id, 0.0, &"DEATH")
	t = 0.0
	var off_at := INF
	var max_fade := 0.0
	for n in playing:
		max_fade = maxf(max_fade, float(h.idx.oneshots[n].fade[1]))
	for f in 30:
		h.step(1)
		t += DT
		var any := false
		for n in playing:
			any = any or h.oneshot_active(n)
		if not any and off_at == INF:
			off_at = t
	ctx.at_most(off_at, max_fade + DT + 1e-6, "death: every OneShot faded out within its fade-out (%.2f s) + 1 frame (s)" % max_fade)
	u.on_action("reload_mid", 1.6, &"musket")
	u.on_fired(&"musket")
	h.step(2)
	var started := []
	for n in h.idx.oneshots:
		if h.oneshot_active(n):
			started.append(n)
	ctx.check(started.is_empty(), "dead: actions and fire are ignored %s" % [started])
	ctx.near(float(h.tree.get(ua)), 0.0, 1e-6, "dead: U_aim 0")
	var death_len := float(h.idx.lower_record(death_id).get("length", 2.3))
	h.step(roundi((death_len + 0.2) / DT))
	var held := PoseOracle.capture(h.rig.sk)
	h.step(roundi(5.0 / DT))
	var o := PoseOracle.new(h.rig.sk, h.rig.clip_resolver())
	var cmp := o.compare(held, PoseOracle.capture(h.rig.sk), null, "rp")
	ctx.at_most(maxf(cmp.max_rot, cmp.max_pos), TOL, "death: the pose holds for 5 s after the clip ends (worst %s / %s)" % [cmp.max_rot_bone, cmp.max_pos_bone])

	# Revive.
	u.on_revive()
	h.inp.alive = true
	h.inp.weapon_aim = 1.0
	h.set_lower(&"aimidle__musket__stand", 0.0, &"AIM_IDLE")
	h.step(20)
	ctx.near(float(h.tree.get(ua)), 1.0, 1e-6, "revive: U_aim follows the weapon again")
	h.inp.weapon_aim = 0.0
	u.on_action("reload_begin", 1.3, &"musket")
	h.step(2)
	var x: Dictionary = h.idx.oneshot("X", String(u.resolve_action("musket", "stand", "reload_begin").get("partial", "")))
	ctx.check(not x.is_empty() and h.oneshot_active(x.node), "revive: actions play again")
