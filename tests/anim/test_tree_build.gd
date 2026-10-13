extends AnimTestSuite
## WP3 (plan sections 6.1 and 10): TreeBuilder on the Actor_B rig.
##   - builds from the fixture (tools/anim_graph/fixtures/mini_graph.json) and from the real
##     animations/actor_b_graph.json with 0 errors in <= 300 ms (cold: difference clips baked);
##   - every parameter path the TreeIndex names (and so every section 6.1 node) exists on the
##     AnimationTree (get_property_list());
##   - no AnimationNodeStateMachine and no AnimationNodeTransition anywhere (recursive);
##   - an additive OneShot has no filter, except an action twin that shares bones with its
##     partial: its filter is its tracks minus the bones its partial(s) key (WP6 review);
##   - every filtered node (OneShots, carry partials, aim blk / rel / hands, weapon-out, U_aim,
##     grip H__) has exactly the filter it should: a clip filter equals that clip's track paths
##     (recomputed here from the Animation), except that an action partial (X) leaves out the
##     weapon prop bones (TreeBuilder.PROP_BONES, played by PropFlipGuard; its record lists the ones
##     its clip keys in prop_bones), U_aim equals the metrics upper set, a grip filter equals
##     bone_sets.hands AND the bones its grip clip keys;
##   - carry layers (default "input", plan D4) through crossfades: the tree equals the Godot
##     evaluation of crossfade(A + layers_A, B + layers_B) (PoseOracle g_*) and stays within
##     0.15 rad of the graph oracle (slerp crossfade of the composed poses) on the core bones,
##     for 7 input pairs x 3 weapons x f = 0.25 / 0.5 / 0.75; the opt-in "shared" stack is
##     exact only while one input is weighted (checked) and leaks mid-crossfade (reported);
##   - exact-grip override: grip_targets() gives every hands bone its target weights (nested
##     filters); with the override on, a hands bone the active grip does not key keeps the
##     override-off pose (the pistol's free left hand), a keyed bone takes the grip pose, and a
##     weapon fade does not pull the free hand toward the rest pose;
##   - a clip missing from the library plays frontier/none, with one warning; a bank leaf clip
##     that differs between weapons is warned about (doctored fixture);
##   - loop-seam data issues (graph loop, metrics loop = false) are recorded, e.g. actor_b-p-fall;
##   - the default "diff" direction bank reproduces the graph's slerp direction chain
##     (PoseOracle.bank_chain) on the real clips; the "blendspace" bank equals Godot's
##     BlendSpace1D semantics (the plan 6.1 layout, kept as an option);
##   - every lower and aim input evaluates without NaN;
##   - lint: no runtime filter / animation / loop edits in the runtime scripts (plan D5).

const BUILD_MS_LIMIT := 300.0
## Diff bank vs the graph chain: exact at the baked phases (30 Hz grid of both clips); in between
## the difference pose is interpolated, which leaves a second-order error on fast limbs.
const BANK_TOL_RAD := 0.01
const BANK_TOL_M := 1e-4
## Default carry layout vs the graph oracle mid-crossfade (core bones): the graph crossfades the
## composed poses (slerp), Godot accumulates rest-relative deltas; per-input stacks measured
## 0.03-0.13 rad (the opt-in shared stack up to 0.56).
const XFADE_TOL_RAD := 0.15
## Thrown weapons (THROW): the mid-crossfade error beyond Godot's own crossfade of the two input poses,
## i.e. the inputs' partial layers below weight 1, which Godot composes rest-relative and the oracle by
## slerp (the wiring itself is exact, XFADE_WIRING_TOL_RAD). THROW2 review: the spear's run -> sprint
## fade, from the raised javelin carry (0.9) into the graph's own lowered sprint arm (the pick-up base's
## p-1h-arm--part below weight 1, on its own 0.097 rad from the oracle at r_wrist, as in the atlatl's
## sprint), reaches 0.069 rad at f 0.75 (0.034 with the first THROW2 build's knife--arm sprint trail). With our own
## jog (the sprint's arms, data/anim_author/locomotion_clips.json) the atlatl's run -> land_soft_run reaches 0.0751.
const THROW_XFADE_EXCESS_RAD := 0.08
## Default carry layout vs the Godot evaluation of the plan D4 composition (wiring; float32).
const XFADE_WIRING_TOL_RAD := 1e-3
const XFADE_WIRING_TOL_M := 1e-4
const CORE_BONES := ["spinea", "spineb", "spinec", "spined", "neck", "heada", "l_clavicle", "r_clavicle", "l_shoulder",
		"r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist", "pelvis", "l_upper_leg", "r_upper_leg", "l_knee", "r_knee"]
const LINT_FILES_DIR := "res://scripts/player/anim"
const FACADE := "res://scripts/player/player_anim.gd"
const MUTATION_PATTERNS := ["set_filter_path(", "filter_enabled =", ".animation =", "loop_mode =",
		"use_custom_timeline =", "timeline_length =", "stretch_time_scale =", "remove_node(", "add_node(",
		"connect_node(", "add_blend_point("]


func describe() -> String:
	return "TreeBuilder: fixture + real JSON build, param paths, no SM/Transition, filters, frontier/none, bank fidelity, lint"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	var rig := ctx.rig()
	if rig == null:
		return
	var real := AnimGraphData.load_files()
	var fixture := AnimGraphData.load_fixture()
	ctx.check(real != null and fixture != null, "graph tables load (real + fixture)")
	if real == null or fixture == null:
		return

	# Build time: cold (difference clips baked, on a fresh rig) and warm, both kinds, both tables.
	TreeBuilder.clear_cache()
	var cold_rig := ctx.rig({"tree": false})
	var t0 := Time.get_ticks_usec()
	var cold := TreeBuilder.build(real, cold_rig.ap, cold_rig.sk)
	var cold_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var idx := TreeBuilder.build(real, rig.ap, rig.sk)
	ctx.check(idx.errors.is_empty() and cold.errors.is_empty(), "real JSON: 0 build errors %s" % [idx.errors])
	ctx.at_most(cold_ms, BUILD_MS_LIMIT, "real JSON, bank_kind diff, cold (bakes %d ms of difference clips): build ms" % roundi(cold.bake_ms))
	cold_rig.dispose()
	ctx.metric("build_ms_real_cold", cold_ms)
	t0 = Time.get_ticks_usec()
	var warm := TreeBuilder.build(real, rig.ap, rig.sk)
	var warm_ms := (Time.get_ticks_usec() - t0) / 1000.0
	ctx.at_most(warm_ms, BUILD_MS_LIMIT, "real JSON, bank_kind diff, warm: build ms")
	ctx.metric("build_ms_real_warm", warm_ms)
	t0 = Time.get_ticks_usec()
	var bs := TreeBuilder.build(real, rig.ap, rig.sk, {"bank_kind": "blendspace"})
	var bs_ms := (Time.get_ticks_usec() - t0) / 1000.0
	ctx.check(bs.errors.is_empty(), "real JSON, bank_kind blendspace: 0 build errors %s" % [bs.errors])
	ctx.at_most(bs_ms, BUILD_MS_LIMIT, "real JSON, bank_kind blendspace: build ms")
	TreeBuilder.clear_cache()
	var fx_rig := ctx.rig({"tree": false})
	t0 = Time.get_ticks_usec()
	var fx_cold := TreeBuilder.build(fixture, fx_rig.ap, fx_rig.sk)
	var fx_ms := (Time.get_ticks_usec() - t0) / 1000.0
	fx_rig.dispose()
	var fx := TreeBuilder.build(fixture, rig.ap, rig.sk)
	ctx.check(fx.errors.is_empty() and fx_cold.errors.is_empty(), "fixture: 0 build errors %s" % [fx.errors])
	ctx.at_most(fx_ms, BUILD_MS_LIMIT, "fixture, cold: build ms")
	ctx.check(idx.warnings.is_empty() and fx.warnings.is_empty(), "real and fixture builds have no warnings %s %s" % [idx.warnings, fx.warnings])
	ctx.info("real: %s" % [idx.summary()])
	ctx.info("fixture: %s" % [fx.summary()])
	ctx.info("lower inputs (real, chain order): %s" % [idx.L_inputs])

	var am := TreeBuilder.build(real, rig.ap, rig.sk, {"aim_move": true})
	ctx.check(am.errors.is_empty() and am.has_input(&"aimmove__musket__stand") and not idx.has_input(&"aimmove__musket__stand"),
			"aim-walk inputs (graph aim-run-*) build on request (aim_move), not by default (options.aim_walk off)")
	var sh := TreeBuilder.build(real, rig.ap, rig.sk, {"carry": "shared"})
	ctx.check(sh.errors.is_empty() and sh.carry_mode == "shared", "opt-in carry shared builds")
	ctx.info("carry shared (opt-in): %s" % [sh.summary()])
	for pair in [["real", idx], ["real blendspace", bs], ["real aim_move", am], ["real carry shared", sh], ["fixture", fx]]:
		_check_structure(ctx, rig, pair[0], pair[1], real if pair[0] != "fixture" else fixture)
	_check_contract(ctx, idx, sh, real)
	_check_shared_carry(ctx, rig, real, sh, idx)
	_check_crossfade_carry(ctx, rig, real, idx, sh)
	_check_grip(ctx, rig, real, idx)
	_check_missing_clip(ctx, rig, fixture)
	_check_bank_leaf_warning(ctx, rig, real)
	_check_loop_seams(ctx, real, idx)
	_check_bank_fidelity(ctx, rig, real, idx, bs)
	_check_evaluates(ctx, rig, idx)
	_check_lint(ctx)


## Param paths, no SM / Transition, filters.
func _check_structure(ctx: AnimTestContext, rig: RigFixture, label: String, idx: TreeIndex, data: AnimGraphData) -> void:
	rig.play(AnimationNodeBlendTree.new())
	idx.install(rig.tree)
	rig.advance(0.0)
	var props := {}
	for p in rig.tree.get_property_list():
		props[p.name] = true
	var missing := []
	var paths := idx.all_param_paths()
	for p in paths:
		if not props.has(p):
			missing.append(p)
	ctx.check(missing.is_empty(), "%s: all %d TreeIndex parameter paths exist on the AnimationTree (missing %s)" % [label, paths.size(), missing.slice(0, 5)])
	var bad := []
	var counts := {"nodes": 0}
	_walk(idx.tree_root, "", bad, counts)
	ctx.check(bad.is_empty(), "%s: no AnimationNodeStateMachine / AnimationNodeTransition in %d nodes %s" % [label, counts.nodes, bad.slice(0, 5)])
	# Filters: recompute every clip filter from the Animation's tracks.
	var fbad := []
	var nfilters := 0
	for node_path: String in idx.filters:
		var n := _node_at(idx.tree_root, node_path)
		if n == null:
			fbad.append("%s: node not found" % node_path)
			continue
		nfilters += 1
		var actual := {}
		for fp in n.get("filters"):
			actual[String(fp)] = true
		var expected := {}
		for fp: NodePath in idx.filters[node_path]:
			expected[String(fp)] = true
		if not n.filter_enabled or not _same(actual, expected):
			fbad.append("%s: %d filter paths, recorded %d" % [node_path, actual.size(), expected.size()])
	ctx.check(fbad.is_empty(), "%s: %d filtered nodes carry exactly the recorded filter %s" % [label, nfilters, fbad.slice(0, 5)])
	var oneshot_bad := []
	var n_os := 0
	for on: String in idx.oneshots:
		var rec: Dictionary = idx.oneshots[on]
		var n: AnimationNodeOneShot = idx.tree_root.get_node(on)
		n_os += 1
		if rec.additive:
			if n.mix_mode != AnimationNodeOneShot.MIX_MODE_ADD:
				oneshot_bad.append("%s: additive OneShot must be ADD" % on)
			var ex: Array = rec.get("excluded_bones", [])
			if n.filter_enabled != (not ex.is_empty()) or (not ex.is_empty() and String(rec.chain) != "XA"):
				oneshot_bad.append("%s: an additive OneShot is filtered only as an action twin sharing bones with its partial" % on)
			elif not ex.is_empty():
				# Twin: its clip's tracks minus the bones its partial(s) key.
				var want := {}
				var keyed_a := _keyed_paths(rig, data, rec.clip)
				for fp in keyed_a:
					if not ex.has(String(fp).get_slice(":", 1)):
						want[fp] = true
				var got := {}
				for fp in n.get("filters"):
					got[String(fp)] = true
				var partner_bones := {}
				for k in idx.actions:
					var a: Dictionary = idx.actions[k]
					if a.twin == rec.clip and a.partial != "":
						for fp in _keyed_paths(rig, data, a.partial):
							partner_bones[String(fp).get_slice(":", 1)] = true
				var ex_ok := true
				for b in ex:
					ex_ok = ex_ok and partner_bones.has(b)
				if not _same(got, want) or not ex_ok:
					oneshot_bad.append("%s: twin filter %d paths, want %d (clip tracks minus its partials' bones)" % [on, got.size(), want.size()])
			continue
		var keyed := _keyed_paths(rig, data, rec.clip)
		var prop_bn := []
		if String(rec.chain) == "X":
			for fp in keyed.keys():
				var bn := String(fp).get_slice(":", 1)
				if bn in TreeBuilder.PROP_BONES:
					keyed.erase(fp)
					if not prop_bn.has(bn):
						prop_bn.append(bn)
		var actual := {}
		for fp in n.get("filters"):
			actual[String(fp)] = true
		if not _same(actual, keyed):
			oneshot_bad.append("%s: filter %d paths, clip keys %d (less the prop bones of a partial)" % [on, actual.size(), keyed.size()])
		var rp: Array = rec.get("prop_bones", [])
		prop_bn.sort()
		var rps := rp.duplicate()
		rps.sort()
		if rps != prop_bn:
			oneshot_bad.append("%s: record prop_bones %s, the clip keys %s" % [on, rp, prop_bn])
		if n.break_loop_at_end:
			oneshot_bad.append("%s: break_loop_at_end must be false" % on)
	ctx.check(oneshot_bad.is_empty(), "%s: every OneShot filter equals its clip's keyed bones, an action partial's less the weapon prop bones (%d OneShots) %s" % [label, n_os, oneshot_bad.slice(0, 5)])
	var clip_bad := []
	for node_path: String in idx.filters:
		var src := _filter_source(idx, node_path)
		if src == "":
			continue
		var keyed := _keyed_paths(rig, data, src)
		var rec := {}
		for fp: NodePath in idx.filters[node_path]:
			rec[String(fp)] = true
		if not _same(rec, keyed):
			clip_bad.append("%s (%s)" % [node_path, src])
	ctx.check(clip_bad.is_empty(), "%s: every clip-filtered Blend2 (carry partials, aim blk / rel / hands, weapon-out) equals its clip's tracks %s" % [label, clip_bad.slice(0, 5)])
	if idx.filters.has("U_aim"):
		var want := data.bone_set("upper")
		var got := {}
		for fp: NodePath in idx.filters["U_aim"]:
			got[String(fp.get_concatenated_subnames())] = true
		var wd := {}
		for b in want:
			wd[b] = true
		ctx.check(_same(got, wd) and want.size() > 0, "%s: U_aim filter = metrics bone_sets.upper (%d bones)" % [label, want.size()])
	# Grip sources: filter = bone_sets.hands AND the bones the grip clip keys (recomputed).
	var hands := {}
	for b in data.bone_set("hands"):
		hands[b] = true
	var gbad := []
	for gs: Dictionary in idx.grip_sources:
		var want := {}
		for tp in _keyed_paths(rig, data, gs.clip):
			var b := String(NodePath(tp).get_concatenated_subnames())
			if hands.has(b):
				want[b] = true
		var got := {}
		for fp: NodePath in idx.filters.get(gs.node, []):
			got[String(fp.get_concatenated_subnames())] = true
		if want.is_empty() or not _same(got, want):
			gbad.append("%s: %d bones, want %d" % [gs.node, got.size(), want.size()])
	ctx.check(gbad.is_empty() and not idx.grip_sources.is_empty(),
			"%s: %d grip filters = bone_sets.hands AND the grip clip's keyed bones %s" % [label, idx.grip_sources.size(), gbad])


## Same key set (Dictionary.hash() depends on insertion order).
func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
	return true


func _walk(n: AnimationNode, path: String, bad: Array, counts: Dictionary) -> void:
	counts.nodes += 1
	if n is AnimationNodeStateMachine or n is AnimationNodeTransition:
		bad.append("%s (%s)" % [path, n.get_class()])
	if n is AnimationNodeBlendTree:
		var bt := n as AnimationNodeBlendTree
		for name in bt.get_node_list():
			if name == &"output":
				continue
			_walk(bt.get_node(name), path + "/" + String(name), bad, counts)
	elif n is AnimationNodeBlendSpace1D:
		var b1 := n as AnimationNodeBlendSpace1D
		for i in b1.get_blend_point_count():
			_walk(b1.get_blend_point_node(i), "%s/%d" % [path, i], bad, counts)
	elif n is AnimationNodeBlendSpace2D:
		var b2 := n as AnimationNodeBlendSpace2D
		for i in b2.get_blend_point_count():
			_walk(b2.get_blend_point_node(i), "%s/%d" % [path, i], bad, counts)


func _node_at(root: AnimationNodeBlendTree, node_path: String) -> AnimationNode:
	var n: AnimationNode = root
	for part in node_path.split("/"):
		if not n is AnimationNodeBlendTree or not (n as AnimationNodeBlendTree).has_node(part):
			return null
		n = (n as AnimationNodeBlendTree).get_node(part)
	return n


## The clip a clip-filtered node was built from ("" for bone-set filters and OneShots).
func _filter_source(idx: TreeIndex, node_path: String) -> String:
	if node_path == "U_aim" or node_path.begins_with("H__") or idx.oneshots.has(node_path):
		return ""
	var parts := node_path.split("/")
	var node := parts[parts.size() - 1]
	if node.begins_with("K__"):
		for w in idx.carry:
			for slot in idx.carry[w]:
				if slot.node == node_path:
					return slot.clip
		return ""
	if node.begins_with("WO__"):
		for c in idx.weapon_out:
			if idx.weapon_out[c].node == node_path:
				return c
		return ""
	var owner := parts[0]
	if owner.begins_with("L__"):
		var rec: Dictionary = idx.lower.get(owner.trim_prefix("L__"), {})
		for l in rec.get("layers", []):
			if l.node == node_path:
				return l.clip
		for h in rec.get("hemis", {}):
			var aim: Dictionary = rec.hemis[h].get("aim", {})
			var clips: Dictionary = aim.get("clips", {})
			if node == h + "_blk":
				return clips.get("blocked", "")
			if node == h + "_rel":
				return clips.get("arms_relaxed", "")
	if owner.begins_with("A__"):
		for k in idx.aim:
			if idx.aim[k].node == owner:
				var clips: Dictionary = idx.aim[k].clips
				return {"hl": clips.get("hands", ""), "blk": clips.get("blocked", ""), "rel": clips.get("arms_relaxed", "")}.get(node, "")
	return ""


## Track paths of a clip, recomputed from the library Animation.
func _keyed_paths(rig: RigFixture, data: AnimGraphData, clip: String) -> Dictionary:
	var out := {}
	var a := rig.ap.get_animation(data.godot_anim(clip))
	if a:
		for t in a.get_track_count():
			out[String(a.track_get_path(t))] = true
	return out


## Section 6.1 contract rows: named nodes / parameters the controllers rely on.
func _check_contract(ctx: AnimTestContext, idx: TreeIndex, sh: TreeIndex, data: AnimGraphData) -> void:
	var root := idx.tree_root
	var need := ["U_aim", "C_add", "C_st", "C_seek_stand", "C_seek_crouch", "C_ts_stand", "C_ts_crouch", "L_x1", "A_x1"]
	for w in data.weapons():
		# A clip-set member (THROW: the thrown weapons) shares its leader's nodes.
		var lw: String = idx.clip_set_leader.get(w, w)
		if not need.has("H__%s__carry" % lw):
			need.append("H__%s__carry" % lw)
	var miss := []
	for n in need:
		if not root.has_node(n):
			miss.append(n)
	ctx.check(miss.is_empty(), "section 6.1 top-level nodes exist %s" % [miss])
	ctx.check(idx.L_inputs.size() >= 20 and root.has_node("L_x%d" % (idx.L_inputs.size() - 1)),
			"L chain: %d inputs, L_x1 .. L_x%d" % [idx.L_inputs.size(), idx.L_inputs.size() - 1])
	var groups := ["idle__stand", "idle__crouch", "move__walk", "move__run", "move__sprint", "move__crouch", "fall"]
	for w in data.weapons():
		for st in ["stand", "crouch"]:
			var lw: String = idx.clip_set_leader.get(w, w)
			if not groups.has("aimidle__%s__%s" % [lw, st]):
				groups.append("aimidle__%s__%s" % [lw, st])
			ctx.check(idx.input_for("%s/%s/aimidle" % [w, st]) == StringName("aimidle__%s__%s" % [lw, st]),
					"%s/%s/aimidle plays aimidle__%s__%s" % [w, st, lw, st])
	var gm := []
	for g in groups:
		if not idx.has_input(g):
			gm.append(g)
	ctx.check(gm.is_empty(), "plan lower inputs idle__<stance>, move__<mode>, aimidle__<w>__<s>, fall exist %s" % [gm])
	# Graph-faithful default (user requirement 1): start / stop / reversal banks, idle turns, crouch
	# change and every exported landing are built as lower inputs.
	var faithful := []
	for m in data.modes():
		for g in ["start", "stop", "rev"]:
			if idx.input_for("musket/%s/%s" % [m, g]) == &"":
				faithful.append("%s/%s" % [m, g])
	for key in ["musket/run/turn_l", "musket/run/turn_r", "musket/crouch/turn_l", "musket/run/quick_turn_180",
			"musket/stand_to_crouch/cchange", "musket/crouch_to_stand/cchange"]:
		if idx.input_for(key) == &"":
			faithful.append(key)
	for r in data.role_names():
		if r.begins_with("land_") and data.role_clip("musket", "run", r) != "" and idx.input_for("musket/run/" + r) == &"":
			faithful.append("musket/run/" + r)
	ctx.check(faithful.is_empty(), "graph-faithful lower inputs exist: start / stop / reversal banks per mode, idle turns, quick turn, crouch change, every landing %s" % [faithful])
	# Every resolved lower role maps to an input whose clip is the role's clip (or a bank leaf).
	var unmapped := []
	for key in data.graph.roles:
		var parts: PackedStringArray = String(key).split("/")
		var clip := data.role_clip(parts[0], parts[1], parts[2])
		if clip == "" or parts[2] in ["death"]:
			continue
		var id := idx.input_for(key)
		if id == &"":
			unmapped.append(key)
			continue
		var rec := idx.lower_record(id)
		var clips := [rec.get("clip", "")]
		for h in rec.get("hemis", {}):
			clips.append_array(rec.hemis[h].clips)
		if not clips.has(clip):
			unmapped.append("%s -> %s" % [key, id])
	ctx.check(unmapped.is_empty(), "every resolved lower role maps to an input playing its clip %s" % [unmapped.slice(0, 8)])
	# Every action partial / twin, fire, hit-add, charge and crouch-change additive has its OneShot.
	var os_miss := []
	for k in idx.actions:
		var a: Dictionary = idx.actions[k]
		if a.partial != "" and idx.oneshot("X", a.partial).is_empty():
			os_miss.append("X " + a.partial)
		if a.twin != "" and idx.oneshot("XA", a.twin).is_empty():
			os_miss.append("XA " + a.twin)
	for k in idx.fire:
		if idx.oneshot("F", idx.fire[k]).is_empty():
			os_miss.append("F " + k)
	for k in idx.hit_add:
		if idx.oneshot("HA", idx.hit_add[k]).is_empty():
			os_miss.append("HA " + k)
	for k in idx.crouch_add:
		if idx.oneshot("CC", idx.crouch_add[k]).is_empty():
			os_miss.append("CC " + k)
	ctx.check(os_miss.is_empty() and idx.actions.size() >= 30 and idx.fire.size() == 6 and idx.hit_add.size() >= 8,
			"OneShots: %d actions, %d fire, %d hit-add, %d crouch-change keys all built %s" % [idx.actions.size(),
			idx.fire.size(), idx.hit_add.size(), idx.crouch_add.size(), os_miss.slice(0, 5)])
	ctx.check(idx.charge.has("add") and idx.charge.seek.size() == 2, "bow charge C_add with stand and crouch seeks")
	# Defaults: exact grip override off (graph hands layers), rates play in real time.
	var gdef := 0.0
	for gs: Dictionary in idx.grip_sources:
		gdef = maxf(gdef, float(idx.defaults.get(gs.param, 1.0)))
	ctx.check(gdef == 0.0 and idx.grip_override_default == 0.0 and idx.grips.size() == data.weapons().size(),
			"exact-grip amounts default to 0 (override_exact_hands_grip off: graph hands layers); %d sources for %d weapons" % [
			idx.grip_sources.size(), idx.grips.size()])
	var rec := idx.lower_record(&"move__run")
	ctx.near(float(idx.defaults[rec.hemis.fw.ts]), 1.0 / rec.hemis.fw.lengths[0], 1e-6, "move__run fw_ts defaults to 1 / run-fw length")
	ctx.check(rec.hemis.fw.clips == ["actor_b-p-run-fw", "actor_b-p-run-fw-rt", "actor_b-p-run-fw-lt"]
			and rec.hemis.bw.clips == ["actor_b-p-run-bw", "actor_b-p-run-bw-lt", "actor_b-p-run-bw-rt"],
			"move__run banks: fw [fw, -90 rt, +90 lt], bw [bw, -90 lt, +90 rt] (graph run-fw / run-bkwd chains)")
	var mus := 0
	var shared := 0
	for l in rec.layers:
		if l.weapon == "musket" and l.hemi == "fw":
			mus += 1
			shared += 1 if l.shared else 0
			if l.param == &"" or not idx.all_param_paths().has(String(l.param)):
				mus = -100
	ctx.check(mus == data.role("musket", "run", "fw").layers.size(),
			"move__run fw has a driven node for every musket run-fw layer (%d, hands slot included; %d in the shared stack)" % [mus, shared])
	var k_nodes := 0
	for w in sh.carry:
		k_nodes += sh.carry[w].size()
	ctx.check(idx.carry_mode == "input" and idx.carry.is_empty() and not root.has_node("K__musket__0"),
			"default carry layout is per input (plan D4; graph-exact through crossfades): no shared K stack")
	ctx.check(k_nodes > 0 and k_nodes < 60, "opt-in shared carry stack: %d K nodes for %d weapons" % [k_nodes, sh.carry.size()])


## The shared carry stack gives the same pose as per-input stacks while one input is weighted
## (TreeIndex.carry_targets drives both).
func _check_shared_carry(ctx: AnimTestContext, rig: RigFixture, data: AnimGraphData, shared: TreeIndex, per_input: TreeIndex) -> void:
	var cases := [["idle__stand", ""], ["idle__crouch", ""], ["move__run", "fw"], ["move__crouch", "bw"], ["start__walk", "bw"],
			["move__sprint", "fw"], ["move__sprint", "bw"], ["hit_fw__stand", ""],
			["rev__crouch", "fw"], ["land_soft_run__run", ""], ["fall", ""], ["hit_fw__crouch", ""], ["aimidle__musket__stand", ""],
			["aimidle__bow__crouch", ""], ["takeoff__sprint", ""], ["turn_l__crouch", ""]]
	var worst := 0.0
	var where := ""
	var n := 0
	var moved := 0
	for c in cases:
		for w in data.weapons():
			var poses := []
			var bare: PoseOracle.Pose = null
			for ix: TreeIndex in [shared, per_input]:
				rig.play(AnimationNodeBlendTree.new())
				ix.install(rig.tree)
				var id := StringName(c[0])
				if not ix.has_input(id):
					break
				var L := XFadeSelector.new(rig.tree, "L", ix.L_inputs, ix.L_seek)
				L.set_immediate(id)
				L.write()
				var rec := ix.lower_record(id)
				var hw := {}
				var dw := {}
				if c[1] != "":
					rig.tree.set(rec.hemi_param, 0.0 if c[1] == "fw" else 1.0)
					hw = {id: {"fw": 1.0 if c[1] == "fw" else 0.0, "bw": 1.0 if c[1] == "bw" else 0.0}}
					dw = {id: {c[1]: [0.0, 0.6]}}
					ix.set_bank_weights(rig.tree, id, c[1], 0.0, 0.6)
					rig.tree.set(rec.hemis[c[1]].seek, 0.4)
				else:
					rig.tree.set(rec.seek, 0.4)
				if ix == shared:
					rig.advance(0.0)
					bare = rig.capture()
				ix.write_carry(rig.tree, ix.carry_targets({id: 1.0}, {w: 1.0}, hw, dw, {id: 0.4}))
				rig.advance(0.0)
				poses.append(rig.capture())
			if poses.size() < 2:
				continue
			var o := ctx.oracle(rig)
			var d := o.compare(poses[0], poses[1])
			n += 1
			if o.compare(bare, poses[0]).max_rot > 0.01:
				moved += 1
			if d.max_rot > worst:
				worst = d.max_rot
				where = "%s %s %s %s" % [c[0], c[1], w, d.max_rot_bone]
	ctx.at_most(worst, 1e-4, "shared carry stack == per-input stacks with one input weighted, %d input x weapon cases (rad; worst %s)" % [n, where])
	ctx.at_least(moved, n / 2, "control: the carry layers change the pose (> 0.01 rad) in %d of those %d cases (the rest have no graph layer, e.g. pistol idle)" % [moved, n])


## Carry layers through crossfades (plan D4, user requirement 1). For each input pair A -> B,
## weapon w and fade f, the default tree (carry "input") is compared with
##   (a) the Godot evaluation (PoseOracle g_*) of crossfade(A + layers_A, B + layers_B), built
##       from the TreeIndex layer records: the wiring is exact;
##   (b) the graph oracle, the slerp crossfade of the composed graph poses, on the core bones.
## The opt-in shared stack is measured against (b) too: it applies one input's layers to the
## other input mid-fade (reported; a control that the check sees the difference).
func _check_crossfade_carry(ctx: AnimTestContext, rig: RigFixture, data: AnimGraphData, idx: TreeIndex, sh: TreeIndex) -> void:
	var o := ctx.oracle(rig)
	var core := PackedStringArray()
	for b in CORE_BONES:
		if rig.sk.find_bone(b) >= 0:
			core.append(b)
	var u := 0.3
	var worst := {"wiring": 0.0, "wiring_m": 0.0, "wiring_at": "", "graph": 0.0, "graph_at": "", "shared": 0.0, "shared_at": "",
			"mixer": 0.0, "mixer_at": "", "excess": 0.0, "excess_at": "", "throw_graph": 0.0, "throw_graph_at": "",
			"throw_excess": 0.0, "throw_excess_at": ""}
	var n := 0
	var missing := []
	for w in data.weapons():
		var pairs := [["idle__stand", "move__run"], ["idle__stand", "aimidle__%s__stand" % idx.clip_set_leader.get(w, w)], ["move__walk", "move__run"],
				["idle__stand", "idle__crouch"], ["move__run", "move__sprint"], ["move__run", "fall"], ["move__run", "land_soft_run__run"]]
		for pr in pairs:
			if not idx.has_input(StringName(pr[0])) or not idx.has_input(StringName(pr[1])):
				missing.append("%s -> %s" % pr)
				continue
			var ga := _graph_input(o, rig, data, idx, pr[0], w, u)
			var gb := _graph_input(o, rig, data, idx, pr[1], w, u)
			var ia := _godot_input(o, rig, data, idx, pr[0], w, u)
			var ib := _godot_input(o, rig, data, idx, pr[1], w, u)
			var a_first := idx.L_inputs.find(pr[0]) < idx.L_inputs.find(pr[1])
			var ea := o.g_eval(ia)
			var eb := o.g_eval(ib)
			for f in [0.25, 0.5, 0.75]:
				var want_g := o.g_eval(o.g_blend2(ia, ib, f) if a_first else o.g_blend2(ib, ia, 1.0 - f))
				var want := o.crossfade(ga, gb, f)
				var got := _crossfade_pose(rig, idx, pr[0], pr[1], w, f, u)
				var at := "%s -> %s %s f %.2f" % [pr[0], pr[1], w, f]
				var dg := o.compare(want_g, got)
				if dg.max_rot > worst.wiring:
					worst.wiring = dg.max_rot
					worst.wiring_at = "%s %s" % [at, dg.max_rot_bone]
				worst.wiring_m = maxf(worst.wiring_m, dg.max_pos)
				var d := o.compare(want, got, core)
				# Godot's own crossfade (rest-relative accumulation) vs a slerp of the same two poses.
				var dm := o.compare(o.crossfade(ea, eb, f), want_g, core)
				if String(data.graph.get("profiles", {}).get(w, {}).get("clip_set", "")) == "throw":
					# THROW: the thrown weapons' cocked aim and 1h carry arm are far apart, and Godot's
					# own crossfade of the two input poses is most of the difference: gate the part
					# beyond it (the carry layout), report the total.
					if d.max_rot > worst.throw_graph:
						worst.throw_graph = d.max_rot
						worst.throw_graph_at = "%s %s (Godot's own crossfade of the two poses %.3f)" % [at, d.max_rot_bone, dm.max_rot]
					if d.max_rot - dm.max_rot > worst.throw_excess:
						worst.throw_excess = d.max_rot - dm.max_rot
						worst.throw_excess_at = "%s; each input's own layer composition vs the oracle %.3f / %.3f" % [at,
								o.compare(ga, ea, core).max_rot, o.compare(gb, eb, core).max_rot]
				elif d.max_rot > worst.graph:
					worst.graph = d.max_rot
					worst.graph_at = "%s %s" % [at, d.max_rot_bone]
				if dm.max_rot > worst.mixer:
					worst.mixer = dm.max_rot
					worst.mixer_at = "%s %s" % [at, dm.max_rot_bone]
				if d.max_rot - dm.max_rot > worst.excess:
					worst.excess = d.max_rot - dm.max_rot
					worst.excess_at = at
				var ds := o.compare(want, _crossfade_pose(rig, sh, pr[0], pr[1], w, f, u), core)
				if ds.max_rot > worst.shared:
					worst.shared = ds.max_rot
					worst.shared_at = "%s %s" % [at, ds.max_rot_bone]
				n += 1
	ctx.check(missing.is_empty(), "crossfade pairs: every input exists %s" % [missing])
	ctx.at_most(worst.wiring, XFADE_WIRING_TOL_RAD, "carry input (default), mid-crossfade == Godot evaluation of crossfade(A + layers_A, B + layers_B), %d cases, rad (worst %s)" % [n, worst.wiring_at])
	ctx.at_most(worst.wiring_m, XFADE_WIRING_TOL_M, "same, positions m")
	ctx.at_most(worst.graph, XFADE_TOL_RAD, "carry input (default), mid-crossfade vs the graph oracle (slerp of the composed poses), core bones, rad (worst %s)" % worst.graph_at)
	ctx.at_most(worst.throw_excess, THROW_XFADE_EXCESS_RAD, "thrown weapons: the same beyond Godot's own crossfade of the two input poses, rad (worst %s)" % worst.throw_excess_at)
	ctx.info("thrown weapons: mid-crossfade vs the graph oracle in total up to %.3f rad (%s)" % [worst.throw_graph, worst.throw_graph_at])
	ctx.info("of that, Godot's crossfade itself (rest-relative accumulation vs slerp of the same two input poses): up to %.3f rad (%s); per case the graph error exceeds it by at most %.3f rad (%s: partial layers below weight 1 compose slightly differently)" % [
			worst.mixer, worst.mixer_at, worst.excess, worst.excess_at])
	ctx.info("carry shared (opt-in approximation) vs the graph oracle on the same cases: %.3f rad (worst %s)" % [worst.shared, worst.shared_at])
	ctx.at_least(worst.shared, 2.0 * worst.graph, "control: the check tells the layouts apart (shared %.3f vs input %.3f rad)" % [worst.shared, worst.graph])
	ctx.metric("xfade_input_vs_graph_rot", worst.graph)
	ctx.metric("xfade_shared_vs_graph_rot", worst.shared)
	ctx.metric("xfade_input_wiring_rot", worst.wiring)


## Pose of the tree ix at weight f of B in a 1 s fade A -> B, both inputs at phase u, weapon w
## carried (weight 1); carry amounts from TreeIndex.carry_targets.
func _crossfade_pose(rig: RigFixture, ix: TreeIndex, a: String, b: String, w: String, f: float, u: float) -> PoseOracle.Pose:
	rig.play(AnimationNodeBlendTree.new())
	ix.install(rig.tree)
	var L := XFadeSelector.new(rig.tree, "L", ix.L_inputs, ix.L_seek)
	L.set_immediate(StringName(a), u)
	L.request(StringName(b), 1.0, u)
	L.update(f)
	L.write()
	var tw := {}
	var ws := L.weights()
	for k in ws:
		if ws[k] > 0.0:
			tw[k] = ws[k]
	ix.write_carry(rig.tree, ix.carry_targets(tw, {w: 1.0}, {}, {}, {StringName(a): u, StringName(b): u}))
	rig.advance(0.0)
	return rig.capture()


## Weapon w's layers of an input (the fw hemisphere of a bank, direction weights 0) with the
## amounts carry_targets gives them at phase u.
func _input_layers(ix: TreeIndex, id: String, w: String, u: float) -> Array:
	var amt := ix.carry_targets({StringName(id): 1.0}, {w: 1.0}, {}, {}, {StringName(id): u})
	var out := []
	for l: Dictionary in ix.lower[id].layers:
		# A clip-set member's layers are its leader's records (LayerRecord.group).
		var mine: bool = l.weapon == w or (l.has("group") and (l.group as Array).has(w))
		if not mine or (l.hemi != "" and l.hemi != "fw"):
			continue
		out.append([l, float(amt.get(l.param, 0.0))])
	return out


## Graph semantics: base clip (bank: fw center) at phase u with w's layers (partial / additive).
func _graph_input(o: PoseOracle, rig: RigFixture, data: AnimGraphData, ix: TreeIndex, id: String, w: String, u: float) -> PoseOracle.Pose:
	var a := rig.ap.get_animation(data.godot_anim(ix.lower[id].clip))
	var p := o.clip(a, u * a.length)
	for e in _input_layers(ix, id, w, u):
		var l: Dictionary = e[0]
		var la := rig.ap.get_animation(data.godot_anim(l.clip))
		var lp := o.clip(la, u * la.length)
		p = o.additive(p, lp, e[1]) if l.kind == "additive" else o.partial(p, lp, e[1], o.keyed(la))
	return p


## Godot semantics of the same composition (plan D4 stack: Blend2 filtered to the layer clip /
## Add2), as instances for g_eval.
func _godot_input(o: PoseOracle, rig: RigFixture, data: AnimGraphData, ix: TreeIndex, id: String, w: String, u: float) -> Array:
	var a := rig.ap.get_animation(data.godot_anim(ix.lower[id].clip))
	var insts := o.g_clip(a, u * a.length)
	for e in _input_layers(ix, id, w, u):
		var l: Dictionary = e[0]
		var la := rig.ap.get_animation(data.godot_anim(l.clip))
		var li := o.g_clip(la, u * la.length)
		insts = o.g_add2(insts, li, e[1]) if l.kind == "additive" else o.g_blend2(insts, li, e[1], o.keyed(la))
	return insts


## Exact-grip override (override_exact_hands_grip, the H__<w>__<k> sources).
func _check_grip(ctx: AnimTestContext, rig: RigFixture, data: AnimGraphData, idx: TreeIndex) -> void:
	var o := ctx.oracle(rig)
	var ws := data.weapons()
	ctx.check(idx.grip_nested, "grip filters are nested (each a subset of every later one): %s" % [idx.grip_sources.map(
			func(g: Dictionary) -> String: return "%s %d" % [g.node, g.bones])])
	# (1) Weights: the chain amounts give every hands bone exactly the target weights (sources
	#     whose filter holds it: t_k; the graph pose below: 1 - sum t_k), for random weights.
	var filt: Array = []
	for gs: Dictionary in idx.grip_sources:
		var d := {}
		for fp: NodePath in idx.filters[gs.node]:
			d[String(fp.get_concatenated_subnames())] = true
		filt.append(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260924
	var worst := 0.0
	for trial in 300:
		var ww := {}
		var tot := 0.0
		for w in ws:
			ww[w] = rng.randf() if rng.randf() < 0.7 else 0.0
			tot += ww[w]
		for w in ws:
			ww[w] = ww[w] / tot if tot > 0.0 else 0.0
		var ov: float = [0.0, 1.0, rng.randf()][trial % 3]
		var aw := {}
		var cw := {}
		for w in ws:
			aw[w] = [0.0, 1.0, rng.randf()][rng.randi() % 3]
			cw[w] = [0.0, 1.0, rng.randf()][rng.randi() % 3]
		var amt := idx.grip_targets(ov, ww, aw, cw)
		var t := []
		for gs: Dictionary in idx.grip_sources:
			var a: float = aw[gs.weapon]
			var c: float = cw[gs.weapon]
			var kw := 0.0
			for k in gs.kinds:
				kw += {"carry": 1.0 - a, "aim_s": a * (1.0 - c), "aim_c": a * c}[k]
			var gw := 0.0
			for g in gs.get("group", [gs.weapon]):
				gw += float(ww[g])
			t.append(ov * gw * kw)
		for b in idx.bone_sets.hands:
			var rem := 1.0
			var want_rem := 1.0
			for k in range(idx.grip_sources.size() - 1, -1, -1):
				if not filt[k].has(b):
					continue
				var a := float(amt[idx.grip_sources[k].param])
				worst = maxf(worst, absf(rem * a - t[k]))
				rem *= 1.0 - a
				want_rem -= t[k]
			worst = maxf(worst, absf(rem - want_rem))
	ctx.at_most(worst, 1e-9, "grip_targets: every hands bone gets exactly its target weights (300 random weapon / aim / crouch / override weights)")
	# (2) Poses: override on vs off, per weapon, carry and aim grip.
	var free_worst := 0.0
	var free_at := ""
	var key_worst := 0.0
	var key_at := ""
	var pistol_free := 0
	for w in ws:
		for ca in [0.0, 1.0]:
			var off := _grip_pose(rig, idx, w, {w: 1.0}, 0.0, ca)
			var on := _grip_pose(rig, idx, w, {w: 1.0}, 1.0, ca)
			var si: int = idx.grips[w].source["carry" if ca == 0.0 else "aim_s"]
			var gs: Dictionary = idx.grip_sources[si]
			var keyed := PackedStringArray(filt[si].keys())
			var free := PackedStringArray()
			for b in idx.bone_sets.hands:
				if not filt[si].has(b):
					free.append(b)
			if w == "pistol" and ca == 0.0:
				pistol_free = free.size()
			if not free.is_empty():
				var d := o.compare(off, on, free)
				if d.max_rot > free_worst:
					free_worst = d.max_rot
					free_at = "%s ca %.0f %s" % [w, ca, d.max_rot_bone]
			var gp := o.clip(rig.ap.get_animation(data.godot_anim(gs.clip)), float(rig.tree.get(gs.position_node)))
			var dk := o.compare(gp, on, keyed)
			if dk.max_rot > key_worst:
				key_worst = dk.max_rot
				key_at = "%s ca %.0f %s" % [w, ca, dk.max_rot_bone]
	ctx.check(pistol_free > 0, "the pistol carry grip leaves %d hands bones free (the left hand)" % pistol_free)
	ctx.at_most(free_worst, 1e-4, "override on: hands bones the active grip does not key keep the override-off pose, rad (worst %s)" % free_at)
	ctx.at_most(key_worst, 1e-3, "override on: hands bones the active grip keys take the grip clip pose, rad (worst %s)" % key_at)
	# (3) Weapon fade pistol <-> bow with the override on: the pistol does not key the left hand,
	#     so the left hand is the graph pose at 1 - W_bow and the bow grip at W_bow, exactly as the
	#     override at W_bow with the bow alone (no pull toward the rest pose). The pose below the
	#     grips (carry layers) is held the same in both.
	if ws.has("pistol") and ws.has("bow"):
		var left := PackedStringArray()
		for b in idx.bone_sets.hands:
			if b.begins_with("l_"):
				left.append(b)
		var worst_f := 0.0
		for wb in [0.25, 0.5, 0.75]:
			var fade := _grip_pose(rig, idx, "pistol", {"pistol": 1.0 - wb, "bow": wb}, 1.0, 0.0)
			var alone := _grip_pose(rig, idx, "pistol", {"bow": 1.0}, wb, 0.0)
			worst_f = maxf(worst_f, o.compare(alone, fade, left).max_rot)
		ctx.at_most(worst_f, 1e-4, "override on, pistol -> bow fade: left hand == graph pose (1 - W) + bow grip (W), no rest pull, rad")


## Pose with move__run (phase 0.3), carry layers for `carry_w`, exact-grip override `ov` over the
## weapon weights `ww` with aim grip weight `ca`, after two 1/60 s steps.
func _grip_pose(rig: RigFixture, ix: TreeIndex, carry_w: String, ww: Dictionary, ov: float, ca: float) -> PoseOracle.Pose:
	rig.play(AnimationNodeBlendTree.new())
	ix.install(rig.tree)
	var L := XFadeSelector.new(rig.tree, "L", ix.L_inputs, ix.L_seek)
	L.set_immediate(&"move__run", 0.3)
	L.write()
	ix.write_carry(rig.tree, ix.carry_targets({&"move__run": 1.0}, {carry_w: 1.0}))
	var aw := {}
	for w in ww:
		aw[w] = ca
	ix.write_grip(rig.tree, ix.grip_targets(ov, ww, aw))
	rig.advance(1.0 / 60.0, 2)
	return rig.capture()


## A bank leaf clip that differs between weapons is warned about (one bank serves every weapon).
func _check_bank_leaf_warning(ctx: AnimTestContext, rig: RigFixture, real: AnimGraphData) -> void:
	var ws := real.weapons()
	var rs := real.bank_roles(AnimGraphData.BANK_GROUPS["move"]["fw"])
	if ws.size() < 2 or rs.size() < 3:
		ctx.fail("bank leaf warning: needs two weapons and the move_fw bank")
		return
	var g: Dictionary = real.graph.duplicate(true)
	var key := "%s/run/%s" % [ws[ws.size() - 1], rs[1]]
	var other := real.role_clip(ws[0], "run", rs[0])
	g.roles[key].clip = other
	var d := AnimGraphData.from_dicts(g, real.metrics)
	var ix := TreeBuilder.build(d, rig.ap, rig.sk)
	var hits := 0
	for msg in ix.warnings:
		if msg.contains("bank leaf") and msg.contains(key):
			hits += 1
	ctx.check(ix.errors.is_empty() and hits == 1, "doctored %s = %s: exactly one 'bank leaf ... differs' warning (%d) %s" % [key, other, hits, ix.warnings])


## Loop-seam data issues (graph loop, clip not seamless per metrics) are recorded, not warned, and closed in the loaded clip
## (TreeBuilder.close_seam since 2026-10-10; tests/anim/test_loop_seams.gd measures the closing). The graph no longer loops
## actor_b-p-fall; the seams today are walk-fw-rt and sprint-bw-rt / -lt.
func _check_loop_seams(ctx: AnimTestContext, data: AnimGraphData, idx: TreeIndex) -> void:
	var bad := []
	for c in idx.loop_seams:
		if data.clip_metrics(c).get("loop", true) != false or String((idx.loop_seams[c] as Dictionary).get("anim", "")) == "":
			bad.append(c)
	ctx.check(not idx.loop_seams.is_empty() and bad.is_empty(),
			"loop-seam data issues recorded (graph loops, metrics loop = false) with the clip they close: %s %s" % [idx.loop_seams.keys(), bad])
	for c in idx.loop_seams:
		ctx.info("data issue: %s loops but its ends differ by %.3f rad / %.3f m (%s): pops at each wrap (WP1 / WP4 to decide)" % [
				c, idx.loop_seams[c].rot_rad, idx.loop_seams[c].pos_m, idx.loop_seams[c].bone])


## A role clip the library lacks plays frontier/none; one warning per clip.
func _check_missing_clip(ctx: AnimTestContext, rig: RigFixture, fixture: AnimGraphData) -> void:
	var g: Dictionary = fixture.graph.duplicate(true)
	var fake := "actor_b-p-no-such-clip"
	g.roles["musket/run/turn_l"].clip = fake
	g.roles["musket/run/idle"].clip = fake
	var d := AnimGraphData.from_dicts(g, fixture.metrics)
	ctx.allow_error("missing clip 'actor_b-p-no-such-clip'")
	var idx := TreeBuilder.build(d, rig.ap, rig.sk)
	ctx.check(idx.errors.is_empty(), "doctored fixture still builds")
	var hits := 0
	for w in idx.warnings:
		if fake in w:
			hits += 1
	ctx.check(hits == 1, "missing clip: exactly one warning (%d) %s" % [hits, idx.warnings])
	for key in ["musket/run/turn_l", "musket/run/idle"]:
		var id := idx.input_for(key)
		var bt: AnimationNodeBlendTree = idx.tree_root.get_node("L__" + String(id))
		var leaf: AnimationNodeAnimation = bt.get_node("clip")
		ctx.check(leaf.animation == TreeBuilder.NONE, "%s: leaf plays %s (got %s)" % [key, TreeBuilder.NONE, leaf.animation])


## Diff bank == graph slerp chain; blendspace bank == Godot BlendSpace1D semantics.
func _check_bank_fidelity(ctx: AnimTestContext, rig: RigFixture, data: AnimGraphData, idx: TreeIndex, bs: TreeIndex) -> void:
	var o := ctx.oracle(rig)
	var cases: Array = []
	for m in data.modes():
		for h in ["fw", "bw"]:
			cases.append(["move__" + m, h])
	for g in ["start__run", "stop__run", "rev__run", "start__crouch", "rev__sprint"]:
		for h in ["fw", "bw"]:
			cases.append([g, h])
	var worst := {"rot": 0.0, "pos": 0.0, "where": ""}
	var worst_bs := {"rot": 0.0, "where": ""}
	var gap_bs := 0.0
	for c in cases:
		for kind in ["diff", "blendspace"]:
			var ix: TreeIndex = idx if kind == "diff" else bs
			rig.play(AnimationNodeBlendTree.new())
			ix.install(rig.tree)
			var L := XFadeSelector.new(rig.tree, "L", ix.L_inputs, ix.L_seek)
			L.set_immediate(StringName(c[0]))
			L.write()
			var rec := ix.lower_record(StringName(c[0]))
			if rec.is_empty() or not rec.hemis.has(c[1]):
				ctx.fail("%s has no %s hemisphere" % [c[0], c[1]])
				continue
			var hr: Dictionary = rec.hemis[c[1]]
			if rec.has("hemi_param"):
				rig.tree.set(rec.hemi_param, 0.0 if c[1] == "fw" else 1.0)
			var clips: Array = hr.clips
			var bones := {}
			for cl in clips:
				for b in o.keyed(data.godot_anim(cl)):
					bones[b] = true
			for u in [0.0, 0.37, 0.5, 0.81]:
				for x in [-90.0, -45.0, -10.0, 0.0, 30.0, 75.0]:
					var wn := PoseOracle.lerp_scale(-90.0, 0.0, 1.0, 0.0, x)
					var wp := PoseOracle.lerp_scale(0.0, 90.0, 0.0, 1.0, x)
					ix.set_bank_weights(rig.tree, StringName(c[0]), c[1], wn, wp)
					rig.tree.set(hr.seek, u)
					rig.advance(0.0)
					var got := rig.capture()
					var poses := []
					for i in 3:
						var a := rig.ap.get_animation(data.godot_anim(clips[i]))
						poses.append(o.clip(a, u * a.length))
					var chain := o.bank_chain(poses[0], poses[1], poses[2], x)
					if kind == "diff":
						var d := o.compare(chain, got, bones.keys())
						if d.max_rot > worst.rot:
							worst = {"rot": d.max_rot, "pos": worst.pos, "where": "%s %s u %.2f x %.0f %s" % [c[0], c[1], u, x, d.max_rot_bone]}
						worst.pos = maxf(worst.pos, d.max_pos)
					else:
						var pts := []
						for i in 3:
							var a := rig.ap.get_animation(data.godot_anim(clips[i]))
							pts.append([[0.0, -90.0, 90.0][i], o.g_clip(a, u * a.length)])
						var g_bs := o.g_eval(o.g_blend_space_1d(pts, x))
						var d2 := o.compare(g_bs, got, bones.keys())
						if d2.max_rot > worst_bs.rot:
							worst_bs = {"rot": d2.max_rot, "where": "%s %s u %.2f x %.0f %s" % [c[0], c[1], u, x, d2.max_rot_bone]}
						gap_bs = maxf(gap_bs, o.compare(chain, got, bones.keys()).max_rot)
	ctx.at_most(worst.rot, BANK_TOL_RAD, "diff bank (default) == graph slerp direction chain over %d banks x 4 phases x 6 angles, rotation rad (worst %s)" % [cases.size(), worst.where])
	ctx.at_most(worst.pos, BANK_TOL_M, "diff bank == graph chain, position m")
	ctx.at_most(worst_bs.rot, 1e-4, "blendspace bank (option) == Godot BlendSpace1D semantics, rad (worst %s)" % worst_bs.where)
	ctx.info("blendspace bank vs graph chain on the same samples: %.4f rad (the gap the diff bank removes)" % gap_bs)
	ctx.metric("bank_diff_max_rot", worst.rot)
	ctx.metric("bank_blendspace_gap_rot", gap_bs)
	# Derived difference clips keep their sources' native_asset_ids (and the sampled carry poses of
	# THROW2, p__*, their one source clip's).
	var lib := rig.ap.get_animation_library(TreeBuilder.BANK_LIB)
	var n_ok := 0
	var n_pose := 0
	var names := lib.get_animation_list()
	for name in names:
		var a := lib.get_animation(name)
		var pose := String(name).begins_with("p__")
		n_pose += 1 if pose else 0
		var ids := a.get_meta(&"native_asset_ids", []) as Array
		if ids.size() == (1 if pose else 2) and not ids.has("") and (not pose or ids[0] == a.get_meta(&"native_asset_id", "")):
			n_ok += 1
	ctx.check(names.size() > 0 and n_ok == names.size(), "%d baked clips (%d difference clips, %d sampled poses) carry their sources' native_asset_ids" % [
			names.size(), names.size() - n_pose, n_pose])


## Every lower input and aim input evaluates (two advances) without NaN.
func _check_evaluates(ctx: AnimTestContext, rig: RigFixture, idx: TreeIndex) -> void:
	rig.play(AnimationNodeBlendTree.new())
	idx.install(rig.tree)
	var L := XFadeSelector.new(rig.tree, "L", idx.L_inputs, idx.L_seek)
	var A := XFadeSelector.new(rig.tree, "A", idx.A_inputs, idx.A_seek)
	var bad := []
	var t0 := Time.get_ticks_usec()
	var steps := 0
	for id in idx.L_inputs:
		L.set_immediate(StringName(id), 0.3)
		L.write()
		rig.advance(1.0 / 60.0, 2)
		steps += 2
		if not _finite(rig):
			bad.append(id)
	rig.tree.set(idx.params.U_aim, 1.0)
	for id in idx.A_inputs:
		A.set_immediate(StringName(id), 0.0)
		A.write()
		rig.advance(1.0 / 60.0, 2)
		steps += 2
		if not _finite(rig):
			bad.append(id)
	var us := float(Time.get_ticks_usec() - t0) / steps
	ctx.check(bad.is_empty(), "%d lower + %d aim inputs evaluate without NaN %s" % [idx.L_inputs.size(), idx.A_inputs.size(), bad])
	ctx.info("advance cost with one input active: %.0f us per frame (rig + full tree, headless)" % us)
	ctx.metric("advance_us", us)


func _finite(rig: RigFixture) -> bool:
	for i in rig.sk.get_bone_count():
		var q := rig.sk.get_bone_pose_rotation(i)
		var p := rig.sk.get_bone_pose_position(i)
		if is_nan(q.x + q.y + q.z + q.w) or is_nan(p.x + p.y + p.z) or is_inf(p.x + p.y + p.z):
			return false
	return true


## Plan D5: the runtime never edits filters, animations, loop modes or the tree layout after the
## build. Only tree_builder.gd may; the rewritten player_anim.gd is linted once it uses TreeBuilder.
func _check_lint(ctx: AnimTestContext) -> void:
	var files: Array[String] = []
	for f in DirAccess.get_files_at(LINT_FILES_DIR):
		if f.ends_with(".gd") and f != "tree_builder.gd":
			files.append(LINT_FILES_DIR + "/" + f)
	var facade := FileAccess.get_file_as_string(FACADE)
	if facade.contains("TreeBuilder"):
		files.append(FACADE)
	else:
		ctx.info("lint: %s is still the pre-WP6 tree (no TreeBuilder); linted once rewritten" % FACADE)
	var hits := []
	for f in files:
		var n := 0
		for line in FileAccess.get_file_as_string(f).split("\n"):
			n += 1
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for pat in MUTATION_PATTERNS:
				if code.contains(pat):
					hits.append("%s:%d %s" % [f.get_file(), n, code.substr(0, 80)])
	ctx.check(hits.is_empty(), "lint: no filter / animation / loop / layout edits outside tree_builder.gd in %d runtime scripts %s" % [files.size(), hits.slice(0, 5)])
