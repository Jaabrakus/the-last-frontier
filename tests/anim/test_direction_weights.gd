extends AnimTestSuite
## WP4 (plan section 10): LocoBrain direction weights on the real move banks against the graph's
## direction chains.
##   - LocoBrain.dir_weights() equals the graph lerp-scale weights (PoseOracle.fw_weights /
##     bw_weights, with the graph's int() truncation of the backward angle) at -180..180 step 1;
##   - fw and bw banks of every move mode (walk, run, sprint, crouch), blend angles -180..180 step
##     5, two normalized phases: the evaluated tree (LocoBrain.apply_direction on the TreeBuilder
##     bank) vs the graph chain crossfade(crossfade(center, neg, w_neg), pos, w_pos) of the same
##     clips at the same phase (PoseOracle.direction_fw / direction_bw), on the bones the three
##     bank clips key (the 53 core bones): <= 0.03 rad;
##   - per-hemisphere chain positions (LocoBrain.hemi_position / position_weights) equal the graph
##     weights at every steady angle, and tick() writes them to both hemispheres of the bank;
##   - seams: the stick snapped D -> A, A -> D, W+D -> S+A, W+A -> S+D in the forward hemisphere:
##     the fw chain passes through its center clip (never full rt -> full lt in one frame, the
##     +-180 seam of the graph formula), at most blend_angle_max_dps (720 deg/s = 0.133 weight
##     per frame), and settles on the graph weights of the new angle.

const LocoRig := preload("res://tests/anim/loco_rig.gd")
const TOL_RAD := 0.03
const PHASES := [0.13, 0.62]
const MODES := ["walk", "run", "sprint", "crouch"]


func describe() -> String:
	return "LocoBrain direction weights vs the graph lerp-scale chains (fw / bw banks, -180..180 step 5, 4 modes)"


func timeout_s() -> float:
	return 300.0


func run(ctx: AnimTestContext) -> void:
	# Weight formula.
	var worst_w := 0.0
	for a in range(-180, 181):
		var fw := LocoBrain.dir_weights("fw", float(a))
		var ofw := PoseOracle.fw_weights(float(a))
		var bw := LocoBrain.dir_weights("bw", float(a))
		var obw := PoseOracle.bw_weights(float(a))
		worst_w = maxf(worst_w, maxf(absf(fw.x - ofw.right), absf(fw.y - ofw.left)))
		worst_w = maxf(worst_w, maxf(absf(bw.x - obw.left), absf(bw.y - obw.right)))
	ctx.at_most(worst_w, 1e-6, "dir_weights() = graph lerp-scale weights (fw: rt / lt, bw: lt / rt of angle-mod(int(a) + 180)) at -180..180 step 1 (Vector2 is float32)")

	var h = LocoRig.new()
	if not h.setup(ctx):
		return
	var oracle := ctx.oracle(h.rig)
	var brain: LocoBrain = h.brain
	brain.frozen = true
	var summary := []
	for m in MODES:
		var id: StringName = h.idx.input_for("musket/%s/move" % m)
		var rec: Dictionary = h.idx.lower_record(id)
		if not ctx.check(id != &"" and rec.get("hemis", {}).size() == 2, "musket/%s move bank has fw and bw hemispheres (%s)" % [m, id]):
			continue
		for hem in ["fw", "bw"]:
			var hr: Dictionary = rec.hemis[hem]
			var clips: Array = hr.clips
			var bones := {}
			for c in clips:
				for b in h.rig.keyed_bones(String(c)):
					bones[b] = true
			var gs := "run-fw" if hem == "fw" else "run-bkwd"
			ctx.check(brain.debug_enter(gs, StringName(m)), "debug_enter %s (%s)" % [gs, m])
			h.L.write()
			var hs: XFadeSelector = brain._hemi_sel(id)
			hs.set_immediate(StringName(hem))
			hs.write()
			var worst := 0.0
			var worst_at := ""
			var n := 0
			for a in range(-180, 181, 5):
				brain.apply_direction(id, float(a))
				for u: float in PHASES:
					h.tree.set(hr.seek, u)
					h.tree.advance(0.0)
					var got: PoseOracle.Pose = h.rig.capture()
					var p0 := oracle.clip(clips[0], u * float(hr.lengths[0]))
					var p1 := oracle.clip(clips[1], u * float(hr.lengths[1]))
					var p2 := oracle.clip(clips[2], u * float(hr.lengths[2]))
					var expect: PoseOracle.Pose
					if hem == "fw":
						expect = oracle.direction_fw(p0, p1, p2, float(a))
					else:
						expect = oracle.direction_bw(p0, p1, p2, float(a))
					var d := oracle.compare(expect, got, bones.keys(), "r")
					n += 1
					if d.max_rot > worst:
						worst = d.max_rot
						worst_at = "a %d, u %.2f, %s" % [a, u, d.max_rot_bone]
			ctx.at_most(worst, TOL_RAD, "%s %s bank (%s) vs graph chain, %d samples on %d keyed bones (worst at %s): max rad" % [
					m, hem, clips[0], n, bones.size(), worst_at])
			ctx.metric("dir_%s_%s_max_rad" % [m, hem], worst)
			summary.append("%s/%s %.4f" % [m, hem, worst])
	ctx.info("worst rotation error per bank: %s" % [summary])

	# Per-hemisphere chain positions: at a steady angle they are exactly the graph formulas.
	var worst_p := 0.0
	for a in range(-180, 181):
		for hem in ["fw", "bw"]:
			var pw := LocoBrain.position_weights(LocoBrain.hemi_position(hem, float(a)))
			var dw := LocoBrain.dir_weights(hem, float(a))
			worst_p = maxf(worst_p, maxf(absf(pw.x - dw.x), absf(pw.y - dw.y)))
	ctx.at_most(worst_p, 1e-6, "position_weights(hemi_position(h, a)) = dir_weights(h, a) at -180..180 step 1 (both hemispheres)")

	# tick() drives the graph weights of the steady angle to both hemispheres of the bank.
	brain.debug_enter("run-fw", &"run")
	var id2: StringName = h.idx.input_for("musket/run/move")
	var rec2: Dictionary = h.idx.lower_record(id2)
	var bad := 0
	for a in [-170.0, -95.0, -30.0, 0.0, 44.0, 90.0, 135.0]:
		brain.set_blend_deg(a)
		brain.tick(_inp_at(a), [], 1.0 / 60.0, &"musket", false)
		for hem in ["fw", "bw"]:
			# The brain's own travel angle (the graph's int() truncation of the backward angle
			# turns a float hair below -170 into -169).
			var w2 := LocoBrain.dir_weights(hem, brain.move_dir_deg)
			var hr: Dictionary = rec2.hemis[hem]
			if hr.neg != &"" and absf(float(h.tree.get(hr.neg)) - w2.x) > 1e-6:
				bad += 1
			if hr.pos != &"" and absf(float(h.tree.get(hr.pos)) - w2.y) > 1e-6:
				bad += 1
	ctx.check(bad == 0, "tick() at a steady angle writes the graph's dir_weights to both hemispheres of the current bank (%d mismatches)" % bad)

	# Seams: the stick snapped D (-90) -> A (+90) and W+D (-45) -> S+A (135) in the forward
	# hemisphere. The fw chain position must pass through its center (never jump across +-180
	# from full rt to full lt), at most blend_angle_max_dps per second.
	var cap: float = brain.blend_angle_max_dps / 60.0 / 90.0
	for c in [[-90.0, 90.0], [90.0, -90.0], [-45.0, 135.0], [45.0, -135.0]]:
		brain.debug_enter("run-fw", &"run")
		brain.set_blend_deg(c[0])
		brain.tick(_inp_at(c[0]), [], 1.0 / 60.0, &"musket", false)
		var hr: Dictionary = rec2.hemis["fw"]
		var prev := Vector2(float(h.tree.get(hr.neg)), float(h.tree.get(hr.pos)))
		var max_step := 0.0
		var through_center := false
		for i in 60:
			brain.tick(_inp_at(c[1]), [], 1.0 / 60.0, &"musket", false)
			var w := Vector2(float(h.tree.get(hr.neg)), float(h.tree.get(hr.pos)))
			max_step = maxf(max_step, maxf(absf(w.x - prev.x), absf(w.y - prev.y)))
			if maxf(w.x, w.y) <= cap + 1e-5:
				through_center = true
			prev = w
		var want := LocoBrain.dir_weights("fw", c[1])
		ctx.check(through_center and max_step <= cap + 1e-5 and prev.distance_to(want) < 1e-3,
				"stick %+.0f -> %+.0f deg: fw chain weights pass through the center clip, max step %.4f per frame (<= %.4f), settle at the graph weights %s (%s)" % [
				c[0], c[1], max_step, cap, want, prev])
	brain.frozen = false


static func _inp_at(a: float) -> AnimInputs:
	var inp := AnimInputs.new()
	inp.velocity_local = LocoRig.dir(a) * 3.6
	inp.wish_local = LocoRig.dir(a) * 3.6
	inp.speed = 3.6
	inp.target_speed = 3.6
	return inp
