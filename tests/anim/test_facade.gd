extends AnimTestSuite
## WP6 (plan sections 6.12, 9 and 10 test_facade): the PlayerAnim facade.
##   - public API: setup(player, ap, sk, weapons) / set_weapon(key) unchanged, plus the plan's
##     manual_step, sample_inputs, debug_snapshot, play_hit / play_death / revive, set_option,
##     start / stop_recording, set_input_source, the anim_transition signal, `inputs` and
##     `auto_process`; the "Gameplay overrides" exports, all off by default (graph-faithful);
##   - setup on the rig: BindRest verified, the TreeBuilder tree installed, the tree sees every
##     library of the AnimationPlayer (frontier_bank: the direction banks' difference clips), no
##     AnimationNodeStateMachine / AnimationNodeTransition anywhere, the old hand-built nodes
##     (stance, upper_mix, fire_add, relax_layer, ...) gone; setup refuses a rig whose rest is not
##     null-add;
##   - weapon signals (fired, action_started, action_cancelled) connected exactly once each, and
##     their events applied in order at the next frame;
##   - graph-faithful defaults (G1 start / stop clips on, 0.75 s hemisphere fade, holster on, ...)
##     and each override flag switching its graph value at the next frame (and back);
##   - debug_snapshot() keys (plan section 9), provenance with native_asset_id and record offsets,
##     --anim-trace line format with graph records;
##   - tree resources unchanged after a 60 s soak (hash of every node's stored properties,
##     including filters, and of the clips' loop modes and lengths);
##   - in the real level: the player's PlayerAnim is set up, its weapon signals are connected once,
##     it trims the aim (player.gd then keeps the body facing the camera), walking takes the
##     lower body out of idle, and raising / lowering the musket while strafing left keeps the
##     visible torso, head, wrists and prop bone within 25 rad/s.

const FacadeRig := preload("res://tests/anim/facade_rig.gd")
const OLD_NODES := ["stance", "upper_mix", "fire_add", "fire_shot", "fire_clip", "relax_layer", "relax_weapon", "weapon",
		"action", "action_clip", "action_speed", "air", "stand", "crouch"]
const API := {"setup": 4, "set_weapon": 1, "manual_step": 1, "sample_inputs": 1, "debug_snapshot": 0, "play_hit": 2,
		"play_death": 1, "revive": 0, "set_option": 2, "start_recording": 1, "stop_recording": 0, "set_input_source": 1,
		"play_holster": 2, "holster_enabled": 0, "trims_aim": 0, "is_ready": 0, "trace_lines": 0}
const DERIVED := ["moving", "move_dir_deg", "blend_deg", "hemi", "anim_mode", "ratio", "rate_fw", "rate_bw", "gait_phase",
		"upper_aim_w", "aim_stance", "up_w", "down_w", "blocked_w", "suppress", "stabilizer_deg", "loco_enabled"]
const TRACE_KEYS := ["frame", "t", "from", "to", "reason", "key", "record", "fade_graph", "fade_used", "status"]


func describe() -> String:
	return "PlayerAnim facade: API, setup, signals once, graph defaults + override flags, snapshot, 60 s soak hash, level"


func timeout_s() -> float:
	return 300.0


func run(ctx: AnimTestContext) -> void:
	_api(ctx)
	var h = FacadeRig.new()
	if not h.setup(ctx, {"weapon": "musket"}):
		return
	var a: PlayerAnim = h.anim
	_setup_checks(ctx, h)
	_signals(ctx, h.weapons, a, "rig")
	_events(ctx, h)
	_defaults_and_overrides(ctx, h)
	_snapshot(ctx, h)
	_soak(ctx, h)
	await _refuse(ctx)
	await _level(ctx)


func _api(ctx: AnimTestContext) -> void:
	var s: Script = load("res://scripts/player/player_anim.gd")
	ctx.check(s.get_instance_base_type() == &"AnimationTree", "PlayerAnim extends AnimationTree")
	var methods := {}
	for m in s.get_script_method_list():
		methods[m.name] = m
	var bad := []
	for name in API:
		if not methods.has(name) or methods[name].args.size() != API[name]:
			bad.append("%s/%s" % [name, methods[name].args.size() if methods.has(name) else "missing"])
	ctx.check(bad.is_empty(), "public methods and arities %s" % [bad])
	if methods.has("setup"):
		var names := []
		for arg in methods.setup.args:
			names.append(arg.name)
		ctx.check(names == ["p_player", "ap", "sk", "weapons"], "setup(player, ap, sk, weapons) unchanged %s" % [names])
	if methods.has("play_hit"):
		ctx.check(methods.play_hit.default_args.size() == 1, "play_hit(local_dir, heavy := false)")
	var sig := {}
	for g in s.get_script_signal_list():
		sig[g.name] = g.args.size()
	ctx.check(sig.get("anim_transition", -1) == 3, "signal anim_transition(from, to, info)")
	var props := {}
	for p in s.get_script_property_list():
		props[p.name] = p
	for n in ["inputs", "auto_process"]:
		ctx.check(props.has(n), "property %s" % n)
	var exports := []
	var off := []
	var inst := PlayerAnim.new()
	for f in PlayerAnim.OVERRIDE_FLAGS + PlayerAnim.FACADE_OPTIONS:
		if props.has(f) and (int(props[f].usage) & PROPERTY_USAGE_EDITOR) != 0:
			exports.append(f)
		# WP7: PlayerAnim.DEFAULT_ON lists the overrides on by default pending the owner's decision.
		if bool(inst.get(f)) != (f in PlayerAnim.DEFAULT_ON):
			off.append(f)
	inst.free()
	ctx.check(exports.size() == PlayerAnim.OVERRIDE_FLAGS.size() + PlayerAnim.FACADE_OPTIONS.size(),
			"every gameplay override is an @export (%d)" % exports.size())
	ctx.check(off.is_empty(), "every gameplay override is off by default, except PlayerAnim.DEFAULT_ON %s (on, pending the owner's decision) %s" % [
			PlayerAnim.DEFAULT_ON, off])


func _setup_checks(ctx: AnimTestContext, h) -> void:
	var a: PlayerAnim = h.anim
	ctx.check(a.is_ready() and a.active, "setup() succeeded; tree active")
	ctx.check(bool(a.setup_report.get("bind_rest", {}).get("ok", false)), "BindRest.verify ok at setup")
	ctx.check(a.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL and a.deterministic,
			"callback mode MANUAL, deterministic")
	ctx.check(a.tree_root == a.index.tree_root and a.index.errors.is_empty(), "the TreeBuilder tree is installed (%s)" % [a.index.summary()])
	var have := a.get_animation_library_list()
	var missing := []
	for lib in h.rig.ap.get_animation_library_list():
		if not have.has(lib):
			missing.append(lib)
	ctx.check(missing.is_empty() and have.has(&"frontier_bank"), "the tree sees every library of the player %s (missing %s)" % [have, missing])
	var bt: AnimationNodeBlendTree = a.tree_root
	var old := []
	for n in OLD_NODES:
		if bt.has_node(n):
			old.append(n)
	ctx.check(old.is_empty(), "the old hand-built nodes are gone %s" % [old])
	var sm := [0, 0]
	_walk(bt, sm)
	ctx.check(sm[0] == 0 and sm[1] == 0, "no AnimationNodeStateMachine (%d) or AnimationNodeTransition (%d) in the tree" % sm)
	ctx.check(a.stabilizer != null and a.stabilizer.get_parent() == h.rig.sk, "AimStabilizer added to the skeleton")
	ctx.check(a.trims_aim(), "the AimStabilizer trims the aim (the weapons' interim yaw / pitch offsets are not used)")


func _walk(n: AnimationNode, count: Array) -> void:
	if n is AnimationNodeStateMachine:
		count[0] += 1
	if n is AnimationNodeTransition:
		count[1] += 1
	if n is AnimationNodeBlendTree:
		for c in (n as AnimationNodeBlendTree).get_node_list():
			if c != &"output":
				_walk((n as AnimationNodeBlendTree).get_node(c), count)
	elif n is AnimationNodeBlendSpace1D:
		for i in (n as AnimationNodeBlendSpace1D).get_blend_point_count():
			_walk((n as AnimationNodeBlendSpace1D).get_blend_point_node(i), count)
	elif n is AnimationNodeBlendSpace2D:
		for i in (n as AnimationNodeBlendSpace2D).get_blend_point_count():
			_walk((n as AnimationNodeBlendSpace2D).get_blend_point_node(i), count)


## Every weapon signal of every weapon has exactly one connection to `a`.
func _signals(ctx: AnimTestContext, weapons: Dictionary, a: PlayerAnim, label: String) -> void:
	var bad := []
	for k in weapons:
		var w: Object = weapons[k]
		for sname in ["fired", "action_started", "action_cancelled"]:
			var n := 0
			for c in w.get_signal_connection_list(sname):
				var cb: Callable = c.callable
				if cb.get_object() == a:
					n += 1
			if n != 1:
				bad.append("%s.%s x%d" % [k, sname, n])
	ctx.check(bad.is_empty(), "%s: weapon signals fired / action_started / action_cancelled connected once each %s" % [label, bad])


## Signal handlers queue; the next frame applies the events in order.
func _events(ctx: AnimTestContext, h) -> void:
	var a: PlayerAnim = h.anim
	h.run(20)
	ctx.check(a.upper.weapon == &"musket", "set_weapon at setup applied at the first frame (%s)" % a.upper.weapon)
	h.switch("pistol")
	ctx.check(a.upper.weapon == &"musket", "set_weapon is queued: nothing changes before the next frame")
	var fires: Dictionary = a.upper.fire_counts()
	h.step()
	ctx.check(a.upper.weapon == &"pistol", "set_weapon applied at the next frame")
	var draw := false
	for o in a.upper.snapshot().active_oneshots:
		draw = draw or String(o.clip).contains("draw")
	ctx.check(draw, "the new weapon's equip action (draw) plays after the switch")
	h.run(40)
	h.fire()
	h.step()
	var fired := false
	for o in a.upper.snapshot().active_oneshots:
		fired = fired or String(o.clip).contains("fire")
	ctx.check(fired, "Weapon.fired -> fire additive within 1 frame")
	h.action("reload_begin", 0.8)
	h.step()
	var acts := {}
	for o in a.upper.snapshot().active_oneshots:
		acts[String(o.clip)] = true
	ctx.check(acts.has("actor_b-p-pistol-rev-reload-begin--part"), "action_started(reload_begin) -> the pistol reload begin clip %s" % [acts.keys()])
	h.cancel()
	h.run(30)
	var left := 0
	for o in a.upper.snapshot().active_oneshots:
		if String(o.clip).contains("reload"):
			left += 1
	ctx.check(left == 0, "action_cancelled -> the reload fades out (%d left after 0.5 s)" % left)
	h.switch("musket")
	h.run(60)


func _defaults_and_overrides(ctx: AnimTestContext, h) -> void:
	var a: PlayerAnim = h.anim
	var d: AnimGraphData = a.data
	var on := []
	for f in d.override_flags():
		if d.override_enabled(f):
			on.append(f)
	ctx.check(on.is_empty(), "graph-faithful default: no gameplay override of the table is on %s" % [on])
	ctx.check(bool(d.option("use_transition_anims")) and bool(d.option("holster")) and bool(d.option("idle_turns"))
			and bool(d.option("crouch_change_add")), "graph options on: start / stop clips, holster, idle turns, crouch-change additive")
	ctx.near(float(d.transition_use("hemi_fw_to_bw").fade_s), 0.75, 1e-6, "hemisphere fade: the graph's 0.75 s (G2 off)")
	ctx.near(float(d.transition_use("aimidle_to_move").fade_s), 0.5, 1e-6, "aim idle -> aimed movement: the graph's 0.5 s")
	ctx.check(a.holster_enabled(), "holster on (graph default)")
	ctx.near(a.loco.join_fade_s, 0.0, 0.0, "join_fade_s 0 (the graph's fade-0 joins cut)")
	ctx.near(a.loco.release_grace_s, 0.0, 0.0, "stick release grace 0 (graph literal)")
	ctx.check(not a.upper.strict_graph_cuts and float(d.tuning("carry_join_s", 0.0)) > 0.0
			and String(d.graph.get("tuning_notes", {}).get("carry_join_s", {}).get("status", "")) == "approximation",
			"carry layers ramp over carry_join_s at fade-0 joins (status approximation); strict_graph_cuts off")
	# Each flag reaches the table at the next frame, and back.
	var bad := []
	for f in PlayerAnim.OVERRIDE_FLAGS:
		a.set(f, true)
		if d.override_enabled(f):
			bad.append(f + " before the frame")
		h.step()
		if not d.override_enabled(f):
			bad.append(f + " not applied")
		a.set(f, false)
		h.step()
		if d.override_enabled(f):
			bad.append(f + " not cleared")
	ctx.check(bad.is_empty(), "every override export switches its table flag at the next frame and back %s" % [bad])
	a.override_fast_hemisphere_fade = true
	h.step()
	ctx.near(float(d.transition_use("hemi_fw_to_bw").fade_s), 0.3, 1e-6, "override_fast_hemisphere_fade: 0.3 s hemisphere fade")
	a.override_fast_hemisphere_fade = false
	a.override_no_transition_anims = true
	h.step()
	ctx.check(not bool(d.option("use_transition_anims")), "override_no_transition_anims: use_transition_anims off")
	a.override_no_transition_anims = false
	a.instant_weapon_switch = true
	a.join_fade_s = 0.1
	a.set_option(&"release_grace_s", 0.05)
	a.set_option(&"strict_graph_cuts", true)
	h.step()
	ctx.check(not a.holster_enabled(), "instant_weapon_switch: holster off")
	ctx.check(a.upper.strict_graph_cuts and a.strict_graph_cuts, "set_option(strict_graph_cuts) reaches UpperBody and the export")
	ctx.near(a.loco.join_fade_s, 0.1, 1e-9, "join_fade_s reaches LocoBrain")
	ctx.near(a.loco.release_grace_s, 0.05, 1e-9, "set_option(release_grace_s) reaches LocoBrain and the export")
	ctx.near(a.stick_release_grace_s, 0.05, 1e-9, "set_option updates the export")
	a.instant_weapon_switch = false
	a.join_fade_s = 0.0
	a.stick_release_grace_s = 0.0
	a.strict_graph_cuts = false
	h.step()
	ctx.check(a.holster_enabled() and bool(d.option("use_transition_anims")) and a.loco.join_fade_s == 0.0 and a.loco.release_grace_s == 0.0
			and not a.upper.strict_graph_cuts, "all back to the defaults")


func _snapshot(ctx: AnimTestContext, h) -> void:
	var a: PlayerAnim = h.anim
	h.run(90, Vector2(0, 1), 3.6)
	var s := a.debug_snapshot()
	var miss := []
	for k in ["inputs", "derived", "lower", "upper", "slots", "provenance", "trace", "options", "warnings"]:
		if not s.has(k):
			miss.append(k)
	for k in DERIVED:
		if not s.get("derived", {}).has(k):
			miss.append("derived." + k)
	for k in ["state", "time_in_state", "phase", "input_id", "selector"]:
		if not s.get("lower", {}).has(k):
			miss.append("lower." + k)
	for k in ["A", "G", "W", "active_oneshots"]:
		if not s.get("upper", {}).has(k):
			miss.append("upper." + k)
	ctx.check(miss.is_empty(), "debug_snapshot() has the plan section 9 keys (missing %s)" % [miss])
	var slot_ok: bool = not s.slots.is_empty()
	for sl: Dictionary in s.slots:
		for k in ["node", "clip", "position", "length", "rate", "weight", "role_key"]:
			slot_ok = slot_ok and sl.has(k)
	ctx.check(slot_ok, "slots: node, clip, position, length, rate, weight, role_key (%d slots)" % s.slots.size())
	var prov_ok: bool = not s.provenance.is_empty()
	var prov_keys := []
	for k in s.provenance:
		var p: Dictionary = s.provenance[k]
		prov_keys.append(k)
		prov_ok = prov_ok and String(p.get("native_asset_id", "")).length() == 64 and String(p.get("state_offset", "")).begins_with("0x") \
				and String(p.get("leaf_id", "")).length() == 8 and p.get("chain") is Array and not (p.chain as Array).is_empty() \
				and String(p.chain[0].get("record_offset", "")).begins_with("0x")
	ctx.check(prov_ok, "provenance of the dominant lower clip and the aim base: native_asset_id, state offset, leaf id, overlay chain %s" % [prov_keys])
	var tr: Array = s.trace
	var tr_ok := not tr.is_empty()
	for e: Dictionary in tr:
		for k in TRACE_KEYS:
			tr_ok = tr_ok and e.has(k)
	ctx.check(tr_ok, "trace entries: %s (%d)" % [TRACE_KEYS, tr.size()])
	var lines := a.trace_lines()
	var re := RegEx.create_from_string("^\\[f \\d+\\] \\w+\\(\\w*,\\w*\\) \\S+ -> \\w+ \\S+  moving=(true|false) \\(wish [\\d.]+ v [\\d.]+\\) key=\\w+ graph (0x[0-9a-f]{8}|-) [\\d.]+/[\\d.]+ \\w+")
	var matched := 0
	var graph_rec := 0
	for l in lines:
		if re.search(l) != null:
			matched += 1
		if RegEx.create_from_string("graph 0x[0-9a-f]{8}").search(l) != null:
			graph_rec += 1
	ctx.check(not lines.is_empty() and matched == lines.size(), "--anim-trace lines have the plan format (%d of %d), e.g. %s" % [matched, lines.size(),
			lines[lines.size() - 1] if not lines.is_empty() else "-"])
	ctx.check(graph_rec > 0, "trace lines name graph record offsets (%d)" % graph_rec)
	h.run(60)


## Hash of every stored property of every node of the tree (filters, animations, timelines,
## connections) and of the loop mode / length of every clip the tree's libraries hold.
func _tree_hash(a: PlayerAnim) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA1)
	_hash_node(a.tree_root, hc, {})
	for lib_name in a.get_animation_library_list():
		var lib := a.get_animation_library(lib_name)
		var names := lib.get_animation_list()
		for n in names:
			var an := lib.get_animation(n)
			hc.update(("%s/%s %d %.6f %d" % [lib_name, n, an.loop_mode, an.length, an.get_track_count()]).to_utf8_buffer())
	return hc.finish().hex_encode()


func _hash_node(n: Object, hc: HashingContext, seen: Dictionary) -> void:
	if n == null or seen.has(n.get_instance_id()):
		return
	seen[n.get_instance_id()] = true
	hc.update(n.get_class().to_utf8_buffer())
	for p in n.get_property_list():
		if (int(p.usage) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var v: Variant = n.get(p.name)
		if v is AnimationNode:
			hc.update(String(p.name).to_utf8_buffer())
			_hash_node(v, hc, seen)
		elif v is Object:
			continue
		else:
			hc.update(("%s=%s" % [p.name, var_to_str(v)]).to_utf8_buffer())


func _soak(ctx: AnimTestContext, h) -> void:
	var a: PlayerAnim = h.anim
	var before := _tree_hash(a)
	var g = FacadeRig.GameSim.new(h, 60606)
	var t0 := Time.get_ticks_msec()
	for i in 3600:
		var ex: Dictionary = g.tick()
		h.step(g.wish(), g.speed(), ex)
	var after := _tree_hash(a)
	ctx.check(before == after, "tree resources and clip loop modes unchanged after a 60 s soak (%s)" % after.substr(0, 12))
	ctx.info("soak: 3600 frames in %d ms (rig, headless)" % (Time.get_ticks_msec() - t0))
	_signals(ctx, h.weapons, a, "after the soak")


## A rig whose rest is not null-add: setup refuses, the tree stays inactive.
func _refuse(ctx: AnimTestContext) -> void:
	ctx.allow_error("PlayerAnim.setup")
	var rig := ctx.rig({"tree": false})
	if rig == null:
		return
	var b := rig.sk.find_bone("spinea")
	var r := rig.sk.get_bone_rest(b)
	rig.sk.set_bone_rest(b, Transform3D(r.basis.rotated(Vector3.UP, 0.3), r.origin))
	var a := PlayerAnim.new()
	a.auto_process = false
	rig.root.add_child(a)
	a.setup(null, rig.ap, rig.sk, {})
	ctx.check(not a.is_ready() and not a.active and String(a.setup_report.get("refused", "")).contains("null-add"),
			"setup refuses a rig whose rest is not null-add (%s)" % a.setup_report.get("refused", ""))
	a.manual_step(1.0 / 60.0)
	ctx.check(a.frame == 0, "a refused facade does nothing")
	await ctx.idle_frames(1)


func _level(ctx: AnimTestContext) -> void:
	var player = await ctx.level()
	if player == null:
		return
	var a: PlayerAnim = player.get("anim")
	ctx.check(a != null and a.is_ready() and a.active, "level: the player's PlayerAnim is set up and active")
	if a == null:
		return
	_signals(ctx, player.weapons, a, "level")
	ctx.check(a.tree_root.has_node("U_aim") and a.tree_root.has_node("L_x1"), "level: the graph tree (U_aim, L chain) is installed")
	ctx.check(a.trims_aim(), "level: the aim trim is on")
	ctx.check(a.upper.weapon == StringName(player.weapon_key), "level: the current weapon reached the facade (%s)" % a.upper.weapon)
	await ctx.frames(150)
	Input.action_press("aim")
	await ctx.frames(120)
	var yaw_abs := absf(float(player.visual.rotation.y))
	var aim_w := a.upper.upper_aim_w()
	Input.action_release("aim")
	ctx.check(aim_w > 0.9 and yaw_abs < 1e-6, "level: RMB raises the musket (upper aim %.2f) and the body keeps facing the camera (visual yaw %.4f rad)" % [aim_w, yaw_abs])
	await ctx.frames(60)
	var f0: int = a.frame
	Input.action_press("move_forward")
	await ctx.frames(60)
	var st := String(a.loco.state)
	Input.action_release("move_forward")
	ctx.check(st in ["START", "MOVE"], "level: holding W takes the lower body out of idle (%s)" % st)
	ctx.check(a.frame > f0, "level: the facade advances by itself (%d frames)" % (a.frame - f0))
	await ctx.frames(60)
	await _level_raise(ctx, player, a)


## Raise and lower the musket while strafing left in the level (WP6 review: the AimStabilizer's
## whole correction appeared on the first raise frame, 88 deg on the neck): the visible
## (post-modifier) skeleton-space speed of the torso, head, wrists and the musket's prop bone stays
## within 25 rad/s per animation frame.
func _level_raise(ctx: AnimTestContext, player, a: PlayerAnim) -> void:
	var sk: Skeleton3D = player.skeleton
	var watch := PackedInt32Array()
	for n in ["spined", "neck", "heada", "l_wrist", "r_wrist", "r_hand_prop_attachment"]:
		watch.append(sk.find_bone(n))
	var cap := {"q": [], "t": -1.0}
	var worst := [0.0, ""]
	var on_upd := func() -> void:
		var t := float(a.get("_time"))
		var q: Array = []
		for b in watch:
			q.append(sk.get_bone_global_pose(b).basis.get_rotation_quaternion())
		var prev: Array = cap.q
		if not prev.is_empty() and t > float(cap.t) + 1e-6:
			for i in watch.size():
				var v := PoseOracle.qdist(prev[i], q[i]) / (t - float(cap.t))
				if v > float(worst[0]):
					worst[0] = v
					worst[1] = "%s aim %.2f %s/%s" % [sk.get_bone_name(watch[i]), a.upper.upper_aim_w(), a.loco.state, a.loco.graph_state]
		cap.q = q
		cap.t = t
	Input.action_press("move_left")
	await ctx.frames(120)
	sk.skeleton_updated.connect(on_upd)
	Input.action_press("aim")
	await ctx.frames(90)
	Input.action_release("aim")
	await ctx.frames(90)
	sk.skeleton_updated.disconnect(on_upd)
	Input.action_release("move_left")
	ctx.at_most(float(worst[0]), 25.0, "level: raise and lower the musket while strafing left, worst visible torso / head / wrist / prop speed (rad/s) [%s]" % worst[1])
	await ctx.frames(30)
