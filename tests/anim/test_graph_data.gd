extends AnimTestSuite
## WP3 (plan section 10): AnimGraphData against the Actor_B library, for the real tables
## (animations/actor_b_graph.json + actor_b_clip_metrics.json) and the day-1 fixtures:
##   - every clip in the JSON exists in `actor_b`, length +-1e-3 s, additive flag == the library's
##     additive_source meta, native_asset_id == the library meta (provenance kept);
##   - every clip the runtime can play (roles, layers, aim trees, actions, runtime clips, grips,
##     weapon-out) is in the clips table; every layer weight / curve sample in [0, 1];
##   - aliases (original, source and graph names) resolve to their action;
##   - metrics clips exist with the library lengths;
##   - gameplay overrides: all off by default (graph-faithful, user requirement 1); turning one on
##     changes exactly its transitions / options;
##   - negative control: validate() reports doctored lengths, flags, weights and clip names.


func describe() -> String:
	return "AnimGraphData: clips in actor_b, lengths, additive flags, weights, aliases, overrides (real + fixture)"


func run(ctx: AnimTestContext) -> void:
	var rig := ctx.rig({"tree": false})
	if rig == null:
		return
	var real := AnimGraphData.load_files()
	var fixture := AnimGraphData.load_fixture()
	ctx.check(real != null and fixture != null, "tables load (real + fixture)")
	if real == null or fixture == null:
		return
	for pair in [["real", real], ["fixture", fixture]]:
		_check_table(ctx, rig, pair[0], pair[1])
	_check_overrides(ctx, real)
	_check_accessors(ctx, real, fixture)
	_check_negative(ctx, rig, fixture)


func _check_table(ctx: AnimTestContext, rig: RigFixture, label: String, d: AnimGraphData) -> void:
	var clips: Dictionary = d.graph.clips
	var missing := []
	var len_bad := []
	var add_bad := []
	var id_bad := []
	for name in clips:
		var path := StringName("actor_b/" + name)
		if not rig.ap.has_animation(path):
			missing.append(name)
			continue
		var a := rig.ap.get_animation(path)
		if absf(a.length - float(clips[name].length)) > 1e-3:
			len_bad.append("%s %.4f vs %.4f" % [name, clips[name].length, a.length])
		if not a.has_meta(&"additive_source") or bool(a.get_meta(&"additive_source")) != bool(clips[name].additive):
			add_bad.append(name)
		if String(a.get_meta(&"native_asset_id", "")) != String(clips[name].native_asset_id):
			id_bad.append(name)
	ctx.check(missing.is_empty(), "%s: all %d JSON clips exist in actor_b %s" % [label, clips.size(), missing.slice(0, 5)])
	ctx.check(len_bad.is_empty(), "%s: clip lengths match the library +-1e-3 s %s" % [label, len_bad.slice(0, 5)])
	ctx.check(add_bad.is_empty(), "%s: additive flags match the library additive_source meta %s" % [label, add_bad.slice(0, 5)])
	ctx.check(id_bad.is_empty(), "%s: native_asset_id matches the library meta %s" % [label, id_bad.slice(0, 5)])
	var refd := d.referenced_clips()
	var not_in := []
	for c in refd:
		if not clips.has(c):
			not_in.append(c)
	ctx.check(not_in.is_empty() and refd.size() > 50, "%s: all %d referenced clips are in the clips table %s" % [label, refd.size(), not_in])
	var n_layers := 0
	var w_bad := []
	for k in d.graph.roles:
		for l in d.graph.roles[k].get("layers", []):
			n_layers += 1
			var w := float(l.weight)
			if w < 0.0 or w > 1.0:
				w_bad.append("%s %s %s" % [k, l.clip, w])
			if l.get("weight_curve") is Array:
				for x in l.weight_curve:
					if float(x) < 0.0 or float(x) > 1.0:
						w_bad.append("%s %s curve %s" % [k, l.clip, x])
	ctx.check(w_bad.is_empty(), "%s: %d role layer weights (and curves) in [0, 1] %s" % [label, n_layers, w_bad.slice(0, 5)])
	var alias_bad := []
	var n_alias := 0
	for name in clips:
		var c: Dictionary = clips[name]
		var names: Array = [c.original_name]
		names.append_array(c.source_names)
		names.append_array(c.graph_names)
		for o in names:
			n_alias += 1
			var r := d.resolve_alias(String(o))
			var amb: Array = d.ambiguous_aliases().get(String(o), [])
			if r != name and not amb.has(name) and not clips.has(String(o)):
				alias_bad.append("%s -> %s (want %s)" % [o, r, name])
		if d.godot_anim(name) != StringName("actor_b/" + name):
			alias_bad.append("%s godot path %s" % [name, d.godot_anim(name)])
	ctx.check(alias_bad.is_empty(), "%s: %d aliases resolve to their action %s" % [label, n_alias, alias_bad.slice(0, 5)])
	ctx.info("%s: %d ambiguous aliases (listed with every action) %s" % [label, d.ambiguous_aliases().size(), d.ambiguous_aliases().keys().slice(0, 5)])
	var m_bad := []
	for c in d.metrics.get("clips", {}):
		var p := StringName("actor_b/" + c)
		if not rig.ap.has_animation(p) or absf(rig.ap.get_animation(p).length - float(d.metrics.clips[c].length)) > 1e-3:
			m_bad.append(c)
	ctx.check(d.has_metrics() and m_bad.is_empty(), "%s: %d metrics clips exist with the library lengths %s" % [label, d.metrics.get("clips", {}).size(), m_bad.slice(0, 5)])
	var errs := d.validate(rig.ap)
	ctx.check(errs.is_empty(), "%s: validate() reports 0 errors %s" % [label, errs.slice(0, 5)])


func _check_overrides(ctx: AnimTestContext, d: AnimGraphData) -> void:
	var flags := d.override_flags()
	var on := []
	for f in flags:
		if d.override_enabled(f):
			on.append(f)
	ctx.check(flags.size() >= 8 and on.is_empty(), "%d gameplay overrides, all off by default (graph-faithful) %s" % [flags.size(), on])
	ctx.near(float(d.transition_use("hemi_fw_to_bw").fade_s), 0.75, 1e-6, "hemi_fw_to_bw uses the graph's 0.75 s by default")
	ctx.near(float(d.transition_use("aimidle_to_move").fade_s), 0.5, 1e-6, "aimidle_to_move uses the graph's 0.5 s by default")
	ctx.check(bool(d.option("use_transition_anims")) and bool(d.option("idle_turns")) and bool(d.option("crouch_change_full_body")),
			"graph-faithful options on by default: use_transition_anims, idle_turns, crouch_change_full_body")
	d.set_override("override_fast_hemisphere_fade", true)
	var u := d.transition_use("hemi_fw_to_bw")
	ctx.check(is_equal_approx(float(u.fade_s), 0.3) and u.override == "override_fast_hemisphere_fade" and is_equal_approx(float(u.fade_graph), 0.75),
			"G2 override on: hemi_fw_to_bw 0.3 s, graph value 0.75 kept in fade_graph (%s)" % [u])
	ctx.near(float(d.transition_use("aimidle_to_move").fade_s), 0.5, 1e-6, "G2 override leaves aimidle_to_move alone")
	d.set_override("override_fast_hemisphere_fade", false)
	d.set_override("override_no_transition_anims", true)
	ctx.check(not bool(d.option("use_transition_anims")), "G1 override on: use_transition_anims false")
	d.set_override("override_no_transition_anims", false)
	ctx.check(bool(d.option("use_transition_anims")), "G1 override off again: use_transition_anims true")
	d.set_override("override_immediate_land_move", true)
	ctx.near(float(d.transition_use("land_to_move").get("gate_s", -1.0)), 0.0, 1e-9, "G6 override on: land_to_move gate 0 s")
	d.set_override("override_immediate_land_move", false)
	ctx.near(float(d.transition_use("land_to_move").get("gate_s", -1.0)), 1.0 / 3.0, 1e-5, "G6 override off: land_to_move gate 10 frames at 30 Hz (0.333 s)")
	var rec := String(d.transition("hemi_fw_to_bw").graph.record)
	ctx.check(d.transition_use("hemi_fw_to_bw", rec).record == rec and rec.begins_with("0x"), "transition_use keeps the graph record offset %s" % rec)


func _check_accessors(ctx: AnimTestContext, real: AnimGraphData, fixture: AnimGraphData) -> void:
	# THROW: the thrown weapons' profiles (pick-up weapon base) follow the firearms and the bow.
	ctx.check(Array(real.weapons()) == ["bow", "musket", "pistol", "spear", "tomahawk", "atlatl"] and Array(real.modes()) == ["walk", "run", "sprint", "crouch"],
			"real: weapons %s, modes %s" % [real.weapons(), real.modes()])
	ctx.check(Array(fixture.weapons()) == ["musket"] and Array(fixture.modes()) == ["run", "crouch"] and fixture.is_fixture(),
			"fixture: weapons %s, modes %s" % [fixture.weapons(), fixture.modes()])
	ctx.check(real.role_clip("musket", "run", "fw") == "actor_b-p-run-fw" and real.role_clip("bow", "crouch", "idle") == "actor_b-p-crouch-idle",
			"role_clip: musket/run/fw run-fw, bow/crouch/idle crouch-idle")
	ctx.check(real.role_clip("musket", "run", "pre_fall") == "", "a missing role has no clip (pre_fall)")
	ctx.check(real.stance_of("crouch") == "crouch" and real.stance_of("sprint") == "stand", "stance_of")
	ctx.near(real.clip_speed("actor_b-p-run-fw"), 3.344, 0.1, "metrics: run-fw speed")
	ctx.check(real.bone_set("upper").has("spined") and real.bone_set("hands").has("r_hand_prop_attachment"), "metrics bone sets upper / hands")
	ctx.near(real.chest_height("stand"), float(real.metrics.chest_height.stand), 1e-9, "chest height from metrics")


func _check_negative(ctx: AnimTestContext, rig: RigFixture, fixture: AnimGraphData) -> void:
	var g: Dictionary = fixture.graph.duplicate(true)
	g.clips["actor_b-p-run-fw"].length = 9.0
	g.clips["actor_b-p-crouch-idle"].additive = true
	var first_layer: Dictionary = g.roles["musket/run/fw"].layers[0]
	first_layer.weight = 1.5
	g.roles["musket/run/bw"].clip = "actor_b-p-not-a-clip"
	var d := AnimGraphData.from_dicts(g, fixture.metrics)
	var errs := d.validate(rig.ap)
	var want := {"length": false, "additive": false, "weight": false, "not-a-clip": false}
	for e in errs:
		if e.contains("actor_b-p-run-fw") and e.contains("length"):
			want.length = true
		if e.contains("actor_b-p-crouch-idle") and e.contains("additive"):
			want.additive = true
		if e.contains("1.5") and e.contains("outside"):
			want.weight = true
		if e.contains("actor_b-p-not-a-clip"):
			want["not-a-clip"] = true
	ctx.check(not want.values().has(false), "negative control: validate() reports the doctored length, additive flag, weight and clip %s (%d errors)" % [want, errs.size()])
