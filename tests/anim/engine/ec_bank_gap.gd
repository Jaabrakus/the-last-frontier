extends AnimTestSuite
## Engine contract + fidelity report for the direction banks (plan 6.2 / 6.5; WP4's
## test_direction_weights) and the carry layers (plan 6.1; WP5's test_carry_layers), on the real
## Actor_B rig (rest = null-add):
##   - Checked: a BlendSpace1D laid out as the plan's move bank (points -90 / 0 / +90, each an
##     AnimationNodeAnimation with a custom timeline of length 1.0, stretch_time_scale, loop
##     LINEAR; sync = true; TimeSeek above it) equals PoseOracle's Godot semantics with every clip
##     at u * its length (<= 1e-4 rad).
##   - Reported (informational, never fails): per bank, the gap between that Godot bank and the
##     graph's slerp direction chain (PoseOracle.bank_chain / direction_fw / direction_bw), over
##     x = -90..90 step 5 and 8 normalized phases, on the bones the bank's clips key (core 53).
##     Godot accumulates rest-relative deltas, rest * slerp(I, rest^-1 a, 1 - w) *
##     slerp(I, rest^-1 b, w), which is not slerp(a, b, w) once a and b are far from rest. Banks
##     over WP4's 0.03 rad threshold print "GAP OVER WP4 THRESHOLD": the plan's BS1D bank cannot
##     meet test_direction_weights against the graph chain there; that needs a graph-faithful
##     arrangement or an explicit, reviewed change of threshold / reference (not a silent one).
##   - Checked: one graph-faithful arrangement exists. With difference poses baked at the same
##     phase, d = rest * center^-1 * side (rotation) and rest + side - center (position / scale),
##     Add2(Add2(center, d_neg, w_neg), d_pos, w_pos) with the lerp-scale weights reproduces the
##     graph chain (<= 1e-3 rad at each bank's worst sample): Add2 gives
##     center * (center^-1 side)^w = slerp(center, side, w), and only one side weight is non-zero
##     at a time. (Baked per phase here; a runtime bank would need baked difference clips.)
##   - Carry layers (plan 6.1 carry stack; WP5's test_carry_layers), from the real layer lists
##     and weights in animations/actor_b_graph.json (roles.<weapon>/<mode>/<role>.layers, hands
##     slot excluded as superseded): reported per weapon x mode (fw, bw, idle roles, and the worst
##     over every role of that weapon and mode), the gap between the plan's Godot carry stack
##     (partial = Blend2 filtered to the layer clip's keyed bones, additive = Add2, amounts = the
##     layer weights) and the graph's partial override + additive, at 4 normalized phases (base
##     and layer clip at the same phase), over all bones, over elbows and wrists, and in skeleton
##     space for the hand prop bones. The partials run all the time at 0.5-0.9, so this gap is
##     persistent (not only during a fade). Over WP5's 0.03 rad it prints "GAP OVER WP5
##     THRESHOLD". Additive layers are exact in both (they right-multiply the same rotation).
##   - Checked: the plan's carry stack built in Godot (unit stretched timelines, one TimeSeek)
##     equals the oracle's Godot semantics (<= 1e-4 rad) at each weapon's worst sample, so the
##     reported gap is what Godot really computes.

const WP4_THRESHOLD := 0.03
const WP5_CARRY_THRESHOLD := 0.03
const GRAPH_JSON := "res://animations/actor_b_graph.json"
const WEAPONS := ["musket", "bow", "pistol"]
const MODES := ["walk", "run", "sprint", "crouch"]
const CARRY_ROLES := ["fw", "bw", "idle"]
const CARRY_PHASES := [0.0, 0.25, 0.5, 0.75]
const ARM_BONES := ["l_elbow", "r_elbow", "l_wrist", "r_wrist"]
const PROP_BONES := ["l_hand_prop_attachment", "r_hand_prop_attachment"]
## bank -> [center, neg (-90), pos (+90)]. fw: -90 = rt, +90 = lt; bw (x = a'): -90 = lt, +90 = rt.
const BANKS := {
	"walk fw": ["actor_b-p-walk-fw", "actor_b-p-walk-fw-rt", "actor_b-p-walk-fw-lt"],
	"walk bw": ["actor_b-p-walk-bw", "actor_b-p-walk-bw-lt", "actor_b-p-walk-bw-rt"],
	"run fw": ["actor_b-p-run-fw", "actor_b-p-run-fw-rt", "actor_b-p-run-fw-lt"],
	"run bw": ["actor_b-p-run-bw", "actor_b-p-run-bw-lt", "actor_b-p-run-bw-rt"],
	"sprint fw": ["actor_b-p-sprint-fw", "actor_b-p-sprint-fw-rt", "actor_b-p-sprint-fw-lt"],
	"sprint bw": ["actor_b-p-sprint-bw", "actor_b-p-sprint-bw-lt", "actor_b-p-sprint-bw-rt"],
	"crouch-walk fw": ["actor_b-p-crouch-walk-fw", "actor_b-p-crouch-walk-fw-rt", "actor_b-p-crouch-walk-fw-lt"],
	"crouch-walk bw": ["actor_b-p-crouch-walk-bw", "actor_b-p-crouch-walk-bw-lt", "actor_b-p-crouch-walk-bw-rt"],
	"rifle-aim-walk fw": ["actor_b-p-rifle-aim-walk-fw", "actor_b-p-rifle-aim-walk-fw-rt", "actor_b-p-rifle-aim-walk-fw-lt"],
	"rifle-aim-walk bw": ["actor_b-p-rifle-aim-walk-bw", "actor_b-p-rifle-aim-walk-bw-lt", "actor_b-p-rifle-aim-walk-bw-rt"],
}


func timeout_s() -> float:
	return 300.0


func describe() -> String:
	return "plan-layout BS1D bank and carry stack == oracle Godot semantics; reports their gap to the graph (banks, carry layers)"


func run(ctx: AnimTestContext) -> void:
	var r := ctx.rig()
	if r == null:
		return
	var o := ctx.oracle(r)
	_banks(ctx, r, o)
	_carry(ctx, r, o)


func _banks(ctx: AnimTestContext, r: RigFixture, o: PoseOracle) -> void:
	var over := []
	for bank: String in BANKS:
		var c: Array = BANKS[bank]
		var missing := c.filter(func(n): return not r.has_clip(n))
		if not missing.is_empty():
			ctx.warn("%s: clip(s) missing from actor_b: %s" % [bank, missing])
			continue
		var gap := o.bank_gap(c[0], c[1], c[2])
		ctx.metric("bank_gap_max_rot/" + bank, gap.max_rot)
		ctx.metric("bank_gap_mean_rot/" + bank, gap.mean_rot)
		var tag := "GAP OVER WP4 THRESHOLD" if gap.max_rot > WP4_THRESHOLD else "within WP4 threshold"
		ctx.info("%-18s Godot BS1D vs graph slerp chain: max %.4f rad (%s, x %+.0f, u %.3f), mean %.4f, pos %.4f m, %d bones x %d samples -> %s" % [
				bank, gap.max_rot, gap.max_rot_bone, gap.x, gap.u, gap.mean_rot, gap.max_pos, gap.bones, gap.samples, tag])
		if gap.max_rot > WP4_THRESHOLD:
			over.append("%s %.3f" % [bank, gap.max_rot])
		# The contract: the plan's bank layout in Godot == the oracle's Godot semantics, at the
		# bank's worst sample and at two fixed ones.
		for s in [[gap.x, gap.u], [-45.0, 0.3], [60.0, 0.8]]:
			var got := _bank_pose(r, c, s[0], s[1])
			var pts := []
			for i in 3:
				pts.append([[0.0, -90.0, 90.0][i], o.g_clip(c[i], s[1] * r.anim(c[i]).length)])
			var want := o.g_eval(o.g_blend_space_1d(pts, s[0]))
			var d := o.compare(want, got)
			ctx.at_most(d.max_rot, 1e-4, "%s: plan-layout BS1D (sync, unit stretched timelines) at x %+.0f u %.3f == oracle Godot semantics (rad, %s)" % [
					bank, s[0], s[1], d.max_rot_bone])
		var dd := _difference_chain_error(r, o, c, gap.x, gap.u)
		ctx.metric("bank_difference_chain_max_rot/" + bank, dd)
		ctx.at_most(dd, 1e-3, "%s: baked difference poses + Add2 chain == graph slerp chain at the worst sample (rad)" % bank)
	if over.is_empty():
		ctx.info("every bank is within WP4's %.2f rad against the graph chain" % WP4_THRESHOLD)
	else:
		ctx.info("GRAPH-FIDELITY GAP: %d bank(s) over WP4's %.2f rad against the graph slerp chain: %s" % [
				over.size(), WP4_THRESHOLD, ", ".join(over)])
	ctx.metric("banks_over_wp4_threshold", over.size())


## Carry layers: plan carry stack in Godot vs the graph's partial override (see the header).
func _carry(ctx: AnimTestContext, r: RigFixture, o: PoseOracle) -> void:
	if not FileAccess.file_exists(GRAPH_JSON):
		ctx.warn("carry layers: %s missing; carry gap not measured" % GRAPH_JSON)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GRAPH_JSON))
	var roles: Dictionary = data.get("roles", {}) if data is Dictionary else {}
	if roles.is_empty():
		ctx.warn("carry layers: %s has no roles" % GRAPH_JSON)
		return
	var cache := {}
	var over := []
	var n_sig := 0
	var n_sig_over := 0
	for w: String in WEAPONS:
		var worst_w := {"max_rot": -1.0}
		for m: String in MODES:
			var parts := []
			var worst_m := {"max_rot": 0.0, "role": "-"}
			var prefix := "%s/%s/" % [w, m]
			for key: String in roles:
				if not key.begins_with(prefix):
					continue
				var role_name := key.trim_prefix(prefix)
				var stack := _carry_stack(roles[key], r)
				if stack.is_empty():
					continue
				var sig := JSON.stringify([roles[key].clip, stack])
				if not cache.has(sig):
					cache[sig] = _carry_gap(o, roles[key].clip, stack)
					n_sig += 1
					if cache[sig].max_rot > WP5_CARRY_THRESHOLD:
						n_sig_over += 1
				var g: Dictionary = cache[sig]
				if role_name in CARRY_ROLES:
					parts.append("%s %.3f (%s; arms %.3f, prop %.1f cm %.3f rad)" % [role_name, g.max_rot, g.max_rot_bone,
							g.arm_rot, g.prop_pos * 100.0, g.prop_rot])
					ctx.metric("carry_gap_max_rot/%s/%s/%s" % [w, m, role_name], g.max_rot)
				if g.max_rot > worst_m.max_rot:
					worst_m = g.duplicate()
					worst_m["role"] = role_name
				if g.max_rot > worst_w.max_rot:
					worst_w = g.duplicate()
					worst_w["key"] = key
					worst_w["base"] = roles[key].clip
					worst_w["stack"] = stack
			var layers := _carry_stack(roles.get(prefix + "fw", {}), r).map(func(l): return "%s %s@%s" % [
					"partial" if l[0] == "partial" else "add", String(l[1]).trim_prefix("actor_b-"), l[2]])
			var tag := "GAP OVER WP5 THRESHOLD" if worst_m.max_rot > WP5_CARRY_THRESHOLD else "within WP5 threshold"
			ctx.info("carry %-6s %-6s [%s]: %s; worst of all %s roles: %s %.3f rad -> %s" % [w, m, ", ".join(layers),
					"; ".join(parts) if not parts.is_empty() else "no partial layers", m, worst_m.role, worst_m.max_rot, tag])
			ctx.metric("carry_gap_worst_rot/%s/%s" % [w, m], worst_m.max_rot)
			if worst_m.max_rot > WP5_CARRY_THRESHOLD:
				over.append("%s %s %.3f" % [w, m, worst_m.max_rot])
		if worst_w.max_rot < 0.0:
			continue
		# Contract: the plan's stack in Godot == the oracle's Godot semantics at the worst sample.
		var got := _carry_pose(r, worst_w.base, worst_w.stack, worst_w.u)
		var want := _carry_eval(o, worst_w.base, worst_w.stack, worst_w.u, true)
		var d := o.compare(want, got)
		ctx.at_most(d.max_rot, 1e-4, "%s carry stack %s at u %.2f built as the plan's Blend2 / Add2 chain == oracle Godot semantics (rad, %s)" % [
				w, worst_w.key, worst_w.u, d.max_rot_bone if d.max_rot_bone != "" else "exact"])
	ctx.metric("carry_signatures", n_sig)
	ctx.metric("carry_signatures_over_wp5_threshold", n_sig_over)
	if over.is_empty():
		ctx.info("every carry stack is within WP5's %.2f rad against the graph partial override" % WP5_CARRY_THRESHOLD)
	else:
		ctx.info("GRAPH-FIDELITY GAP (carry layers): %d weapon x mode stack(s) over WP5's %.2f rad; %d of %d distinct role stacks with a partial layer: %s" % [
				over.size(), WP5_CARRY_THRESHOLD, n_sig_over, n_sig, ", ".join(over)])


## [[kind, clip, weight]] of a role's carry layers in order (hands slot excluded: superseded by
## the H node), only when it has a partial layer (additives alone are exact); clips missing
## from the library are skipped.
func _carry_stack(role: Dictionary, r: RigFixture) -> Array:
	var out := []
	var has_partial := false
	for l: Dictionary in role.get("layers", []):
		if l.get("superseded_by", null) != null or not r.has_clip(String(l.get("clip", ""))):
			continue
		out.append([l.kind, l.clip, float(l.weight)])
		has_partial = has_partial or l.kind == "partial"
	return out if has_partial else []


## Graph (godot = false) or Godot-semantics (godot = true) pose of base + stack at phase u.
func _carry_eval(o: PoseOracle, base: String, stack: Array, u: float, godot: bool) -> PoseOracle.Pose:
	var ab := o.animation(base)
	if godot:
		var inst := o.g_clip(ab, u * ab.length)
		for l: Array in stack:
			var al := o.animation(l[1])
			var li := o.g_clip(al, u * al.length)
			inst = o.g_blend2(inst, li, l[2], o.keyed(al)) if l[0] == "partial" else o.g_add2(inst, li, l[2])
		return o.g_eval(inst)
	var pose := o.clip(ab, u * ab.length)
	for l: Array in stack:
		var al := o.animation(l[1])
		var lp := o.clip(al, u * al.length)
		pose = o.partial(pose, lp, l[2]) if l[0] == "partial" else o.additive(pose, lp, l[2])
	return pose


## Worst gap over CARRY_PHASES: {max_rot, max_rot_bone, u, max_pos, arm_rot, prop_pos (m, skeleton
## space), prop_rot (rad, skeleton space)}.
func _carry_gap(o: PoseOracle, base: String, stack: Array) -> Dictionary:
	var res := {"max_rot": 0.0, "max_rot_bone": "", "u": 0.0, "max_pos": 0.0, "arm_rot": 0.0, "prop_pos": 0.0, "prop_rot": 0.0}
	var arms := ARM_BONES.filter(func(b): return o.bone_index.has(b))
	var props := PROP_BONES.filter(func(b): return o.bone_index.has(b))
	for u: float in CARRY_PHASES:
		var gr := _carry_eval(o, base, stack, u, false)
		var gd := _carry_eval(o, base, stack, u, true)
		var d := o.compare(gr, gd)
		if d.max_rot > res.max_rot:
			res.max_rot = d.max_rot
			res.max_rot_bone = d.max_rot_bone
			res.u = u
		res.max_pos = maxf(res.max_pos, d.max_pos)
		res.arm_rot = maxf(res.arm_rot, o.compare(gr, gd, arms).max_rot)
		var mg := o.model_transforms(gr)
		var md := o.model_transforms(gd)
		for b: String in props:
			var i: int = o.bone_index[b]
			res.prop_pos = maxf(res.prop_pos, mg[i].origin.distance_to(md[i].origin))
			res.prop_rot = maxf(res.prop_rot, PoseOracle.qdist(mg[i].basis.get_rotation_quaternion(),
					md[i].basis.get_rotation_quaternion()))
	return res


## The plan's carry stack in a real AnimationTree: every clip on a unit stretched timeline, one
## TimeSeek on top (every clip at u * its length); partial = Blend2 filtered to the layer
## clip's tracks, additive = Add2.
func _carry_pose(r: RigFixture, base: String, stack: Array, u: float) -> PoseOracle.Pose:
	var bt := AnimationNodeBlendTree.new()
	var unit := {"length": 1.0, "stretch": true, "loop": Animation.LOOP_LINEAR}
	bt.add_node("base", r.node(base, unit))
	var prev := "base"
	var params := {}
	for i in stack.size():
		var l: Array = stack[i]
		var clip_node := "layer_%d" % i
		var mix := ("cw_%d" if l[0] == "partial" else "ca_%d") % i
		bt.add_node(clip_node, r.node(l[1], unit))
		if l[0] == "partial":
			var b2 := AnimationNodeBlend2.new()
			r.filter_from_clips(b2, [l[1]])
			bt.add_node(mix, b2)
			params[mix + "/blend_amount"] = l[2]
		else:
			bt.add_node(mix, AnimationNodeAdd2.new())
			params[mix + "/add_amount"] = l[2]
		bt.connect_node(mix, 0, prev)
		bt.connect_node(mix, 1, clip_node)
		prev = mix
	bt.add_node("seek", AnimationNodeTimeSeek.new())
	bt.connect_node("seek", 0, prev)
	bt.connect_node("output", 0, "seek")
	r.play(bt, params)
	r.set_param("seek/seek_request", u)
	r.advance(0.0)
	return r.capture()


## Godot pose of the plan's bank at blend position x and normalized phase u.
func _bank_pose(r: RigFixture, c: Array, x: float, u: float) -> PoseOracle.Pose:
	var bs := AnimationNodeBlendSpace1D.new()
	bs.sync = true
	bs.min_space = -90.0
	bs.max_space = 90.0
	var names := [&"center", &"neg", &"pos"]
	var at := [0.0, -90.0, 90.0]
	for i in 3:
		bs.add_blend_point(r.node(c[i], {"length": 1.0, "stretch": true, "loop": Animation.LOOP_LINEAR}), at[i], -1, names[i])
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("bs", bs)
	bt.add_node("seek", AnimationNodeTimeSeek.new())
	bt.connect_node("seek", 0, "bs")
	bt.connect_node("output", 0, "seek")
	r.play(bt, {"bs/blend_position": x})
	r.set_param("seek/seek_request", u)
	r.advance(0.0)
	return r.capture()


## Max rotation error (bank bones) of Add2(Add2(center, d_neg, w_neg), d_pos, w_pos) in Godot vs
## PoseOracle.bank_chain at bank position x, phase u (difference poses baked at that phase into
## a scratch library of the fixture's AnimationPlayer; the actor_b library is not touched).
func _difference_chain_error(r: RigFixture, o: PoseOracle, c: Array, x: float, u: float) -> float:
	var t: Array[float] = []
	var poses: Array[PoseOracle.Pose] = []
	for i in 3:
		t.append(u * r.anim(c[i]).length)
		poses.append(o.clip(c[i], t[i]))
	var prefix := String(r.anim(c[0]).track_get_path(0)).get_slice(":", 0)
	var lib := AnimationLibrary.new()
	lib.add_animation("d_neg", _difference(o, poses[0], poses[1], prefix))
	lib.add_animation("d_pos", _difference(o, poses[0], poses[2], prefix))
	if r.ap.has_animation_library(&"wpt_bank"):
		r.ap.remove_animation_library(&"wpt_bank")
	r.ap.add_animation_library(&"wpt_bank", lib)
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("center", r.node(c[0]))
	bt.add_node("seek", AnimationNodeTimeSeek.new())
	bt.connect_node("seek", 0, "center")
	bt.add_node("d_neg", r.node("wpt_bank/d_neg"))
	bt.add_node("d_pos", r.node("wpt_bank/d_pos"))
	bt.add_node("add_neg", AnimationNodeAdd2.new())
	bt.add_node("add_pos", AnimationNodeAdd2.new())
	bt.connect_node("add_neg", 0, "seek")
	bt.connect_node("add_neg", 1, "d_neg")
	bt.connect_node("add_pos", 0, "add_neg")
	bt.connect_node("add_pos", 1, "d_pos")
	bt.connect_node("output", 0, "add_pos")
	r.play(bt, {"add_neg/add_amount": PoseOracle.lerp_scale(-90.0, 0.0, 1.0, 0.0, x),
			"add_pos/add_amount": PoseOracle.lerp_scale(0.0, 90.0, 0.0, 1.0, x)})
	r.set_param("seek/seek_request", t[0])
	r.advance(0.0)
	var got := r.capture()
	r.ap.remove_animation_library(&"wpt_bank")
	var keyed_all := {}
	for n in c:
		for b in o.keyed(n):
			keyed_all[b] = true
	return o.compare(o.bank_chain(poses[0], poses[1], poses[2], x), got, keyed_all.keys()).max_rot


## A one-key additive Animation: rest * a^-1 * b (rotation), rest + b - a (position, scale), on
## the channels a or b keys.
func _difference(o: PoseOracle, a: PoseOracle.Pose, b: PoseOracle.Pose, prefix: String) -> Animation:
	var anim := Animation.new()
	anim.length = 1.0
	for i in a.size():
		var path := NodePath("%s:%s" % [prefix, o.bone_names[i]])
		if a.kr[i] or b.kr[i]:
			var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(tr, path)
			anim.rotation_track_insert_key(tr, 0.0, (o.rest_r[i] * a.r[i].inverse() * b.r[i]).normalized())
		if a.kp[i] or b.kp[i]:
			var tp := anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(tp, path)
			anim.position_track_insert_key(tp, 0.0, o.rest_p[i] + b.p[i] - a.p[i])
		if a.ks[i] or b.ks[i]:
			var ts := anim.add_track(Animation.TYPE_SCALE_3D)
			anim.track_set_path(ts, path)
			anim.scale_track_insert_key(ts, 0.0, o.rest_s[i] + b.s[i] - a.s[i])
	return anim
