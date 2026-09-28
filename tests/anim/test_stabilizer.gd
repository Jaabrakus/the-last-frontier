extends AnimTestSuite
## WP5 (plan sections 6.11 and 10, decision D6): AimStabilizer.
##   - 20 random samples (seeded) of (lower-body input: locomotion banks at a random hemisphere
##     and direction, idle, air, landings, hits; phase; weapon; stance of the input; aim phase;
##     aim elevation) with upper_aim_w = 1 and the trim off: the skeleton-space rotation of
##     spined, heada, both prop bones and every stabilized (E) bone equals the full-body aim pose
##     (the aimidle input at the same aim phase and pitch) within 2.5 deg;
##   - the legs and the root are untouched (<= 1e-5 rad);
##   - regression guard: without the stabilizer the same samples are off by >= 30 deg (worst);
##   - partial upper_aim_w (0.05 / 0.25 / 0.5 / 1) while strafing left: the applied correction is
##     w x c (trim off, <= 1 deg) and at most w x (c + trim clamp) with the trim on;
##   - upper_aim_w = 0: the stabilizer is inactive and the pose seen in skeleton_updated is
##     bit-identical to the animated pose; with the trim on (table feed-forward + closed-loop
##     residual), the E bones still share one rotation (the correction is rigid) and the barrel
##     reaches the crosshair while strafing;
##   - LocoBrain (WP4) in the loop, PlayerAnim frame order: in AIM_IDLE the full-body aimidle
##     input and the aim tree play in step, so the orientation correction stays below 0.1 deg,
##     also after stance changes and weapon changes while aimed (UpperBody resumes the new A input
##     where it was frozen, the phase LocoBrain enters the aimidle input at).

const UpperRig := preload("res://tests/anim/upper_rig.gd")
const TOL_DEG := 2.5
const GUARD_DEG := 30.0
const SAMPLES := 20
const SEED := 20260924
const SKIP_GROUPS := ["aimidle", "aimmove", "death", "land_death"]


func describe() -> String:
	return "AimStabilizer: masked aim upper body over 20 random lower poses vs the full-body aim pose (<= 2.5 deg)"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	var h = UpperRig.new()
	if not h.setup(ctx):
		return
	var e_bones: PackedStringArray = h.data.bone_set("stabilized")
	ctx.check(e_bones.size() == 15 and e_bones.has("upper_base"), "stabilized set: upper_base + 14 *_offset root children (%d)" % e_bones.size())
	var check_bones := PackedStringArray(["spined", "heada", "l_hand_prop_attachment", "r_hand_prop_attachment"])
	check_bones.append_array(e_bones)
	var leg_bones: PackedStringArray = h.data.bone_set("lower")
	var all := check_bones.duplicate()
	all.append_array(leg_bones)
	h.capture_bones = all
	h.inp.weapon_aim = 1.0
	h.inp.wants_aim = true

	var pool: Array = []
	for id in h.idx.L_inputs:
		var rec: Dictionary = h.idx.lower[id]
		var skip := false
		for g in SKIP_GROUPS:
			if String(rec.group) == g or String(rec.group).begins_with(g + "_") or String(id).begins_with(g):
				skip = true
		if not skip:
			pool.append(id)
	ctx.info("sample pool: %d lower inputs" % pool.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var worst := 0.0
	var worst_what := ""
	var worst_off := 0.0
	var worst_leg := 0.0
	var errs: Array = []
	# The weapons with their own aim trees and a barrel (THROW: the thrown weapons' clip set is
	# covered by tests/anim/test_throw_anim.gd; keeping this list keeps the seeded samples).
	var weapons := PackedStringArray()
	for pw in h.data.weapons():
		if String(h.data.graph.get("profiles", {}).get(pw, {}).get("clip_set", "")) != "throw":
			weapons.append(pw)
	# Always include a moving bank, a strafe and the crouch walk.
	var forced := ["move__run", "move__walk", "move__crouch"]
	for i in SAMPLES:
		var id: String = forced[i] if i < forced.size() and h.idx.has_input(StringName(forced[i])) else pool[rng.randi() % pool.size()]
		var rec: Dictionary = h.idx.lower[id]
		var st: String = h.data.stance_of(String(rec.modes[0]))
		var w: String = weapons[rng.randi() % weapons.size()]
		var u := rng.randf()
		var v := rng.randf()
		var e := rng.randf_range(-30.0, 30.0)
		h.snap(StringName(w), st, v, e)
		h.stab.aim_trim = false
		h.set_lower(StringName(id), u, &"MOVE")
		var what := "%s u=%.2f %s/%s v=%.2f e=%.0f" % [id, u, w, st, v, e]
		if rec.kind == "bank":
			var hemi := "fw" if rng.randf() < 0.6 or not rec.hemis.has("bw") else "bw"
			var side := rng.randf_range(-1.0, 1.0)
			h.set_bank(StringName(id), hemi, maxf(-side, 0.0), maxf(side, 0.0))
			what += " %s dir %.2f" % [hemi, side]
		h.step(1, 0.0)
		await h.frame()
		var got: Dictionary = h.captured.duplicate()
		var corr: float = h.stab.last_correction_deg()
		# Without the stabilizer.
		h.stab.active = false
		h.tree.advance(0.0)
		await h.frame()
		var raw: Dictionary = h.captured.duplicate()
		# Reference: the full-body aim pose at the same aim phase and pitch.
		h.set_lower(StringName("aimidle__%s__%s" % [w, st]), v, &"AIM_IDLE")
		h.upper.A.seek(StringName("A__%s__%s" % [w, st]), v)
		h.step(1, 0.0)
		await h.frame()
		var ref: Dictionary = h.captured.duplicate()
		var err := _max_err(check_bones, got, ref)
		var off := _max_err(check_bones, raw, ref)
		var leg := _max_err(leg_bones, got, raw)
		errs.append(snappedf(err.deg, 0.001))
		if err.deg > worst:
			worst = err.deg
			worst_what = "%s (%s, correction %.1f deg)" % [what, err.bone, corr]
		worst_off = maxf(worst_off, off.deg)
		worst_leg = maxf(worst_leg, leg.deg)
	ctx.at_most(worst, TOL_DEG, "stabilized upper body vs full-body aim pose over %d samples, worst bone (deg) [%s]" % [SAMPLES, worst_what])
	ctx.info("per-sample worst error (deg): %s" % [errs])
	ctx.at_least(worst_off, GUARD_DEG, "regression guard: without the stabilizer the worst sample is off by (deg)")
	ctx.at_most(worst_leg, rad_to_deg(1e-5), "legs and root untouched by the stabilizer (deg)")
	ctx.metric("stabilizer_worst_deg", worst)
	ctx.metric("unstabilized_worst_deg", worst_off)

	# Trim on: one rigid correction on every E bone; the barrel reaches the crosshair.
	h.snap(&"bow", "stand", 0.3, 15.0)
	h.set_lower(&"move__run", 0.4, &"MOVE")
	h.set_bank(&"move__run", "fw", 0.0, 0.7)
	h.stab.aim_trim = true
	# The closed-loop residual learns over a few frames at full aim (trim_rate_deg_s).
	for f in 20:
		h.step(1)
		await h.frame()
	h.step(1, 0.0)
	await h.frame()
	var trimmed: Dictionary = h.captured.duplicate()
	var trim_deg: Vector2 = h.stab.last_trim_deg()
	h.stab.aim_trim = false
	h.tree.advance(0.0)
	await h.frame()
	var untrimmed: Dictionary = h.captured.duplicate()
	var rots: Array = []
	for b in e_bones:
		var q1: Quaternion = (trimmed[b] as Transform3D).basis.get_rotation_quaternion()
		var q0: Quaternion = (untrimmed[b] as Transform3D).basis.get_rotation_quaternion()
		rots.append(q1 * q0.inverse())
	var spread := 0.0
	for q in rots:
		spread = maxf(spread, PoseOracle.qdist(q, rots[0]))
	ctx.at_most(rad_to_deg(spread), 1e-3, "trim: the same rigid rotation on every E bone (spread, deg)")
	var b1: Transform3D = trimmed["l_hand_prop_attachment"]
	var tgt: Vector3 = h.rig.sk.global_transform.affine_inverse() * h.inp.aim_point
	var miss := rad_to_deg((b1.basis * Vector3.BACK).angle_to(tgt - b1.origin))
	ctx.at_most(miss, TOL_DEG, "trim: bow barrel on the crosshair while strafing left at run speed (deg)")
	ctx.info("trim while strafing: %s deg (yaw, pitch); orientation correction %.1f deg" % [trim_deg, h.stab.last_correction_deg()])

	# Partial aim weight (the raise / lower ramp) while strafing left: the applied correction is
	# c^w (trim off: within 1 deg of w x c), and with the trim on it stays within w x (c + the trim
	# clamp) (WP6 review: Godot's influence blend was skipped once the trim ran, so the whole
	# correction appeared on the first raise frame).
	var ub: int = h.rig.sk.find_bone("upper_base")
	var partial_worst := 0.0
	var partial_rows := []
	var trim_max: float = Vector2(h.stab.trim_max_yaw_deg, h.stab.trim_max_pitch_deg).length()
	for trim_on in [false, true]:
		for wv in [0.05, 0.25, 0.5, 1.0]:
			h.snap(&"musket", "stand", 0.3, 10.0)
			h.set_lower(&"move__run", 0.4, &"MOVE")
			h.set_bank(&"move__run", "fw", 0.0, 1.0)
			h.stab.aim_trim = trim_on
			h.inp.weapon_aim = wv
			h.step(1)
			var pre_q: Quaternion = h.rig.sk.get_bone_global_pose(ub).basis.get_rotation_quaternion()
			await h.frame()
			var post_q: Quaternion = (h.captured["upper_base"] as Transform3D).basis.get_rotation_quaternion()
			var applied := rad_to_deg(PoseOracle.qdist(pre_q, post_q))
			var c_deg: float = h.stab.last_correction_deg()
			if not trim_on:
				var e := absf(applied - wv * c_deg)
				partial_worst = maxf(partial_worst, e)
				partial_rows.append("trim off w %.2f: applied %.2f deg, w x c = %.2f" % [wv, applied, wv * c_deg])
			else:
				ctx.at_most(applied, wv * (c_deg + trim_max) + 1.0, "trim on, aim weight %.2f: applied correction (deg) <= w x (c %.1f + trim clamp %.1f) + 1" % [wv, c_deg, trim_max])
				partial_rows.append("trim on w %.2f: applied %.2f deg (c %.1f, trim %s)" % [wv, applied, c_deg, h.stab.last_trim_deg()])
	ctx.at_most(partial_worst, 1.0, "partial aim weight, trim off: applied correction = w x c (worst error, deg)")
	for r in partial_rows:
		ctx.info(r)
	h.inp.weapon_aim = 1.0

	# Aim weight 0: inactive, bit-identical.
	h.stab.aim_trim = true
	h.inp.weapon_aim = 0.0
	h.set_lower(&"move__run", 0.2, &"MOVE")
	h.step(3)
	var pre: Array = []
	for b in all:
		pre.append(h.rig.sk.get_bone_global_pose(h.rig.sk.find_bone(b)))
	await h.frame()
	ctx.check(not h.stab.active and h.stab.weight == 0.0, "upper_aim_w = 0: stabilizer inactive, weight 0")
	var same := true
	for i in all.size():
		if (h.captured[all[i]] as Transform3D) != pre[i]:
			same = false
	ctx.check(same, "upper_aim_w = 0: skeleton_updated pose bit-identical to the animated pose (%d bones)" % all.size())
	await _loco_sync(ctx)


## AIM_IDLE with LocoBrain driving the lower body: the aimidle input and the A input stay in step
## (correction c = root_L^-1 root_A ~ identity) through stance and weapon changes while aimed.
func _loco_sync(ctx: AnimTestContext) -> void:
	var h = UpperRig.new()
	if not h.setup(ctx):
		return
	h.capture_bones = PackedStringArray(["spined"])
	h.inp.weapon_aim = 1.0
	h.inp.wants_aim = true
	h.attach_loco()
	var seq := [["musket", "stand"], ["musket", "crouch"], ["musket", "stand"], ["bow", "stand"], ["bow", "crouch"],
			["pistol", "crouch"], ["pistol", "stand"], ["musket", "stand"], ["musket", "crouch"], ["bow", "crouch"]]
	var worst := 0.0
	var worst_at := ""
	var rows := []
	for s: Array in seq:
		var w := String(s[0])
		var st := String(s[1])
		var what := "first aim" if rows.is_empty() else ("weapon change" if StringName(w) != h.inp.weapon_key else "stance change")
		if StringName(w) != h.inp.weapon_key:
			h.set_weapon(StringName(w))
		h.inp.crouched = st == "crouch"
		h.aim_at(0.0)
		var aid := StringName("A__%s__%s" % [w, st])
		var settled := false
		# The stance crossfade, the crouch-change additive (1 s) and the full-body crouch change
		# play out first.
		for f in 360:
			h.step(1)
			if f >= 75 and h.loco.state == LocoBrain.AIM_IDLE and h.L.weight(h.L.target()) >= 1.0 and h.upper.A.weight(aid) >= 1.0:
				settled = true
				break
		ctx.check(settled, "%s -> %s/%s: LocoBrain settles in AIM_IDLE with the aim input at full weight (state %s)" % [what, w, st, h.loco.state])
		h.step(5)
		await h.frame()
		var c: float = h.stab.last_correction_deg()
		var lp: float = h.idx.phase(h.tree, h.L.target())
		var ap: float = h.upper.aim_phase(w, st)
		rows.append("%s -> %s/%s: lower %s phase %.3f, aim tree phase %.3f, correction %.4f deg" % [what, w, st, h.L.target(), lp, ap, c])
		if c > worst:
			worst = c
			worst_at = rows[rows.size() - 1]
	for r in rows:
		ctx.info(r)
	ctx.at_most(worst, 0.1, "AIM_IDLE with LocoBrain through stance and weapon changes while aimed: orientation correction (deg) [%s]" % worst_at)


## Worst skeleton-space rotation difference over `bones`: {deg, bone}.
func _max_err(bones: PackedStringArray, a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {"deg": 0.0, "bone": ""}
	for n in bones:
		if not a.has(n) or not b.has(n):
			continue
		var qa: Quaternion = (a[n] as Transform3D).basis.get_rotation_quaternion()
		var qb: Quaternion = (b[n] as Transform3D).basis.get_rotation_quaternion()
		var d := rad_to_deg(PoseOracle.qdist(qa, qb))
		if d > out.deg:
			out.deg = d
			out.bone = n
	return out
