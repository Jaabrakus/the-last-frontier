extends AnimTestSuite
## WP3 (plan sections 6.2 and 10): XFadeSelector.
##   - weights: sum w = 1 +- 1e-6 always; a fade of f reaches 1 at f +- 1 frame; retargeting in
##     the middle of a fade is continuous; a no-op request on the target only shortens the fade;
##   - storm: 1000 requests with random fades in [0, 0.75] s at random intervals: every frame
##     |dw| <= dt / fade (of the request being faded to) + 1e-6, and sum w stays 1;
##   - on the real tree (TreeBuilder, real JSON): the chain amounts give each input exactly its
##     selector weight (checked against the Blend2 chain algebra); a 1000-request storm over the
##     locomotion and aim inputs with fades in [0.2, 0.75] s (the graph's fades between those
##     states) keeps every spine / arm bone's local angular speed <= 20 rad/s, the clips' own motion
##     included (0 s fades are the graph's cuts into continuing clips and 0.1 s the proposed air /
##     hit entries: covered by the weight contract above, not by this bound); a seek on re-entry
##     places the input exactly (<= 1e-4 of the normalized phase).

const DT := 1.0 / 60.0
const STORM := 1000
const ANG_LIMIT := 20.0
const SPINE_ARM := ["spinea", "spineb", "spinec", "spined", "neck", "heada", "l_clavicle", "r_clavicle",
		"l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist"]


func describe() -> String:
	return "XFadeSelector: sum w = 1, fade timing, 1000-request storms (weights + real tree), re-entry seek"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	_logic(ctx)
	_storm_logic(ctx)
	await _tree(ctx)


func _logic(ctx: AnimTestContext) -> void:
	var s := XFadeSelector.new(null, "", PackedStringArray(["a", "b", "c", "d"]))
	ctx.check(s.target() == &"a" and s.weight(&"a") == 1.0, "starts on the first input at weight 1")
	for f in [0.1, 0.25, 0.5, 0.75]:
		s.set_immediate(&"a")
		s.request(&"b", f)
		var frames := 0
		while s.weight(&"b") < 1.0 and frames < 1000:
			s.update(DT)
			frames += 1
		ctx.check(absi(frames - ceili(f / DT - 1e-9)) <= 1, "fade %.2f s reaches 1 in %d frames (%d expected, +-1)" % [f, frames, ceili(f / DT - 1e-9)])
	# Retarget mid-fade: continuous, sum 1.
	s.set_immediate(&"a")
	s.request(&"b", 0.5)
	for i in 10:
		s.update(DT)
	var before := s.weights()
	s.request(&"c", 0.3)
	s.update(DT)
	var after := s.weights()
	var maxd := 0.0
	for k in before:
		maxd = maxf(maxd, absf(after[k] - before[k]))
	ctx.at_most(maxd, DT / 0.3 + 1e-6, "retarget mid-fade: largest weight step <= dt / 0.3")
	ctx.near(_sum(after), 1.0, 1e-6, "retarget mid-fade: sum w = 1")
	# Request on the current target: no restart, a shorter fade speeds it up.
	var wc := s.weight(&"c")
	s.request(&"c", 1.0)
	s.update(DT)
	ctx.near(s.weight(&"c") - wc, DT / 0.3, 1e-6, "re-request of the target with a longer fade keeps the faster rate")
	s.request(&"c", 0.05)
	wc = s.weight(&"c")
	s.update(DT)
	ctx.near(s.weight(&"c") - wc, minf(DT / 0.05, 1.0 - wc), 1e-6, "re-request with a shorter fade speeds it up")
	# Zero fade = cut at the next update.
	s.request(&"d", 0.0)
	s.update(DT)
	ctx.check(s.weight(&"d") == 1.0 and s.dominant() == &"d", "fade 0: full weight at the next update")
	s.update(0.0)
	ctx.near(_sum(s.weights()), 1.0, 1e-9, "dt 0 keeps the weights")
	var snap := s.snapshot()
	ctx.check(snap.target == "d" and snap.weights.has("d") and snap.has("since_s"), "snapshot has target, weights, since_s")


func _storm_logic(ctx: AnimTestContext) -> void:
	var names := PackedStringArray()
	for i in 12:
		names.append("in%d" % i)
	var s := XFadeSelector.new(null, "", names)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var worst_sum := 0.0
	var worst_rate := 0.0
	var fade := 0.0
	var next := 0
	var req := 0
	var frame := 0
	var prev := s.weights()
	var neg := 0
	while req < STORM:
		if frame >= next:
			var f := rng.randf_range(0.0, 0.75) if rng.randf() > 0.1 else 0.0
			var tgt := StringName(names[rng.randi_range(0, names.size() - 1)])
			# A request on the current target keeps the faster of the two rates.
			fade = f if tgt != s.target() else minf(fade, f)
			s.request(tgt, f)
			req += 1
			next = frame + rng.randi_range(1, 30)
		s.update(DT)
		var w := s.weights()
		worst_sum = maxf(worst_sum, absf(_sum(w) - 1.0))
		var bound := INF if fade <= 0.0 else DT / fade
		for k in w:
			if w[k] < 0.0:
				neg += 1
			var d := absf(w[k] - prev[k])
			if not is_inf(bound):
				worst_rate = maxf(worst_rate, d - bound)
		prev = w
		frame += 1
	ctx.at_most(worst_sum, 1e-6, "storm (%d requests, fades 0-0.75 s, %d frames): max |sum w - 1|" % [STORM, frame])
	ctx.at_most(worst_rate, 1e-6, "storm: every per-frame |dw| <= dt / fade of the current request (+1e-6); excess")
	ctx.check(neg == 0, "storm: no negative weight")


func _tree(ctx: AnimTestContext) -> void:
	var rig := ctx.rig()
	if rig == null:
		return
	var data := AnimGraphData.load_files()
	var idx := TreeBuilder.build(data, rig.ap, rig.sk)
	ctx.check(idx.errors.is_empty(), "real tree builds")
	rig.play(AnimationNodeBlendTree.new())
	idx.install(rig.tree)
	var L := XFadeSelector.new(rig.tree, "L", idx.L_inputs, idx.L_seek)
	# Chain algebra: effective weight of input k = amount_k * prod_{m>k} (1 - amount_m).
	L.set_immediate(&"idle__stand")
	L.request(&"move__run", 0.4)
	for i in 7:
		L.update(DT)
	L.request(&"land_soft_idle", 0.3)
	for i in 5:
		L.update(DT)
	L.write()
	var eff := _effective(rig.tree, L)
	var werr := 0.0
	for k in eff:
		werr = maxf(werr, absf(eff[k] - L.weight(StringName(k))))
	ctx.at_most(werr, 2e-5, "chain amounts give every input its selector weight (3 inputs mid-fade, %d in chain)" % idx.L_inputs.size())
	# Storm on the real tree: angular speed of spine / arm bones.
	var pool: Array[StringName] = [&"idle__stand", &"idle__crouch", &"move__walk", &"move__run", &"move__crouch",
			&"aimidle__musket__stand", &"aimidle__bow__crouch", &"start__run", &"stop__run", &"start__crouch"]
	var pool_ok: Array[StringName] = []
	for p in pool:
		if L.has_input(p):
			pool_ok.append(p)
	var bones := PackedInt32Array()
	for b in SPINE_ARM:
		var bi := rig.sk.find_bone(b)
		if bi >= 0:
			bones.append(bi)
	# The clips' own peak angular speed (each input alone), for reference.
	var own := 0.0
	for p in pool_ok:
		L.set_immediate(p, 0.0)
		L.write()
		rig.advance(DT)
		var prevq := _rots(rig.sk, bones)
		for f in 60:
			rig.advance(DT)
			var q := _rots(rig.sk, bones)
			own = maxf(own, _max_ang(prevq, q) / DT)
			prevq = q
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	L.set_immediate(pool_ok[0], 0.0)
	L.write()
	rig.advance(DT)
	var prevq := _rots(rig.sk, bones)
	var worst_w := 0.0
	var worst_ang := 0.0
	var worst_at := ""
	var min_fade := 0.2
	var fade := 0.3
	var next := 0
	var frame := 0
	var req := 0
	var prevw := L.weights()
	while req < STORM:
		if frame >= next:
			fade = rng.randf_range(min_fade, 0.75)
			var tgt: StringName = pool_ok[rng.randi_range(0, pool_ok.size() - 1)]
			L.request(tgt, fade, 0.0 if L.weight(tgt) == 0.0 else -1.0)
			req += 1
			next = frame + rng.randi_range(1, 20)
		L.update(DT)
		L.write()
		rig.advance(DT)
		var w := L.weights()
		for k in w:
			worst_w = maxf(worst_w, absf(w[k] - prevw[k]))
		prevw = w
		var q := _rots(rig.sk, bones)
		var ang := _max_ang(prevq, q) / DT
		if ang > worst_ang:
			worst_ang = ang
			worst_at = "frame %d target %s" % [frame, L.target()]
		prevq = q
		frame += 1
		if frame % 300 == 0:
			await ctx.idle_frames(1)
	ctx.at_most(worst_w, DT / min_fade + 1e-6, "tree storm (%d requests, fades %.1f-0.75 s): per-frame |dw| <= dt / min_fade" % [STORM, min_fade])
	ctx.at_most(worst_ang, ANG_LIMIT, "tree storm: spine / arm local angular speed rad/s (worst %s; the clips alone peak at %.1f)" % [worst_at, own])
	ctx.metric("storm_max_ang_rad_s", worst_ang)
	ctx.metric("clips_own_max_ang_rad_s", own)
	# Re-entry seek: a zero-weight input requested with seek_to lands on that phase.
	var err := 0.0
	for c in [[&"move__run", 0.25], [&"land_soft_idle", 0.6], [&"idle__crouch", 0.1], [&"fall", 0.9]]:
		var id: StringName = c[0]
		L.set_immediate(&"idle__stand", 0.0)
		L.write()
		rig.advance(DT, 3)
		L.request(id, 0.2, c[1])
		L.update(DT)
		L.write()
		rig.advance(0.0)
		err = maxf(err, absf(idx.phase(rig.tree, id) - float(c[1])))
		var rate := float(rig.tree.get(_rate_param(idx, id)))
		rig.advance(DT)
		err = maxf(err, absf(idx.phase(rig.tree, id) - (float(c[1]) + DT * rate)))
	ctx.at_most(err, 1e-4, "seek on re-entry: normalized phase exact after the seek frame and one frame later")
	# Hemisphere selector inside a bank input seeks its own hemisphere.
	var rec := idx.lower_record(&"move__run")
	var H := XFadeSelector.new(rig.tree, rec.hemi_prefix, rec.hemi_inputs, rec.hemi_seek)
	L.set_immediate(&"move__run", 0.0)
	L.write()
	H.set_immediate(&"fw")
	H.write()
	rig.advance(DT, 5)
	H.request(&"bw", 0.3, 0.42)
	H.update(DT)
	H.write()
	rig.advance(0.0)
	ctx.near(idx.phase(rig.tree, &"move__run", "bw"), 0.42, 1e-4, "hemisphere selector: bw re-entry seek (prefix %s)" % rec.hemi_prefix)
	ctx.near(float(rig.tree.get(rec.hemi_param)), H.weight(&"bw"), 1e-5, "hemisphere selector writes hemi_x1")


func _rate_param(idx: TreeIndex, id: StringName) -> StringName:
	var rec := idx.lower_record(id)
	if rec.has("ts"):
		return rec.ts
	return rec.hemis.fw.ts


## Effective weight of every chain input from the written amounts:
## w_k = (k == 0 ? 1 : a_k) * prod_{m > k} (1 - a_m), a_m = amount of chain node x<m>.
func _effective(tree: AnimationTree, sel: XFadeSelector) -> Dictionary:
	var a: Array[float] = [0.0]
	for p in sel.chain_params():
		a.append(float(tree.get(p)))
	var out := {}
	var n := sel.inputs.size()
	for k in n:
		var w := 1.0 if k == 0 else a[k]
		for m in range(k + 1, n):
			w *= 1.0 - a[m]
		out[sel.inputs[k]] = w
	return out


func _rots(sk: Skeleton3D, bones: PackedInt32Array) -> Array[Quaternion]:
	var out: Array[Quaternion] = []
	for b in bones:
		out.append(sk.get_bone_pose_rotation(b))
	return out


func _max_ang(a: Array[Quaternion], b: Array[Quaternion]) -> float:
	var m := 0.0
	for i in a.size():
		m = maxf(m, PoseOracle.qdist(a[i], b[i]))
	return m


func _sum(w: Dictionary) -> float:
	var s := 0.0
	for k in w:
		s += w[k]
	return s
