extends AnimTestSuite
## WP5 (plan sections 6.9 and 10, decision D4): carry layers driven by UpperBody (lowered weapon,
## upper_aim_w = 0).
##   - every carry-layer amount of the active input = graph layer weight x weapon weight;
##   - musket sprint: elbows vs the graph oracle sprint-fw (+) rifle-run-arms @0.9 (+)
##     rifle-run-arms--add @0.6 (and the role's other layers, in order) <= 0.03 rad (plan); the bow
##     sprint uses bow-sprint--arms @0.75; more roles (walk, run idle spine add, crouch walk,
##     pistol run) are checked the same way;
##   - wiring: the tree equals the Godot-semantics evaluation of the same stack (PoseOracle g_*,
##     the weapon-out finger partial on top) within 1e-3 rad on every bone;
##   - weapon switch (musket -> bow, 0.25 s): every carry amount changes by <= dt / 0.25 x its
##     layer weight per frame and ends at the new weapon's weights;
##   - lowered musket, left palm vs the barrel line over the gait cycle (walk / run / crouch walk /
##     sprint, forward): the tree equals the graph oracle within 0.02 m. A visible change from
##     today's game, recorded: the graph's walk and crouch-walk carry layers hold the left palm
##     0.22-0.24 m off the barrel line (today's relaxed carry 0.09-0.14 m, measured in the level;
##     check_weapon_axes gates rifle-run-arms at weight 1 only, < 0.06 m); documented bounds
##     PALM_MAX_M per gait.

const UpperRig := preload("res://tests/anim/upper_rig.gd")
const TOL_GRAPH := 0.03
const TOL_WIRING := 1e-3
const CASES := [["musket", "sprint", "fw"], ["bow", "sprint", "fw"], ["musket", "walk", "fw"], ["musket", "run", "idle"],
		["musket", "crouch", "fw"], ["pistol", "run", "fw"], ["bow", "crouch", "idle"]]
const ARM_BONES := ["l_clavicle", "r_clavicle", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist",
		"spinea", "spineb", "spinec", "spined", "neck", "heada"]
## Musket carry, left palm off the barrel line: tree vs graph oracle (Godot's rest-relative blend of
## the partial layers; TOL_GRAPH's 0.03 rad over the arm is ~0.02 m at the palm), and documented
## upper bounds per gait (graph data: walk 0.22, crouch walk 0.24, run 0.08, sprint 0.04 m worst
## over the cycle).
const PALM_TOL_M := 0.02
## (run 0.11: our own jog leans further forward than the graph's; the left palm measured 0.1075 m off the line with it)
const PALM_MAX_M := {"walk": 0.25, "crouch": 0.26, "run": 0.11, "sprint": 0.06}


func describe() -> String:
	return "carry layers: amounts = weight x W, elbows vs graph oracle (<= 0.03 rad), Godot wiring, weapon-switch continuity"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	var h = UpperRig.new()
	if not h.setup(ctx):
		return
	var o: PoseOracle = ctx.oracle(h.rig)
	var d: AnimGraphData = h.data
	for c in CASES:
		var w: String = c[0]
		var m: String = c[1]
		var role: String = c[2]
		var st := d.stance_of(m)
		var id: StringName = h.idx.input_for("%s/%s/%s" % [w, m, role])
		if id == &"":
			ctx.fail("%s/%s/%s has a lower input" % c)
			continue
		h.snap(StringName(w), st, 0.0, 0.0)
		h.inp.weapon_aim = 0.0
		h.set_lower(id, 0.3, &"MOVE" if role != "idle" else &"IDLE")
		var rec: Dictionary = h.idx.lower[id]
		if rec.kind == "bank":
			h.set_bank(id, "fw", 0.0, 0.0)
		h.step(1, 0.0)
		h.step(1, 0.0)
		# Amounts.
		var bad := []
		var n := 0
		for lr: Dictionary in rec.layers:
			if lr.hemi == "bw":
				continue
			var lw := float(lr.weight)
			if lr.has("leaf_weights"):
				lw = float(lr.leaf_weights[0])
			var want := lw * (1.0 if lr.weapon == w else 0.0) if lr.scale_by_weapon else lw
			var got := float(h.tree.get(lr.param))
			n += 1
			if absf(got - want) > 1e-6:
				bad.append("%s %s %.3f != %.3f" % [lr.weapon, lr.clip, got, want])
		ctx.check(bad.is_empty() and n > 0, "%s/%s/%s: %d carry amounts = layer weight x weapon weight %s" % [w, m, role, n, bad.slice(0, 3)])
		if w == "bow" and m == "sprint":
			var found := false
			for lr: Dictionary in rec.layers:
				if lr.weapon == "bow" and lr.clip == "actor_b-p-bow-sprint--arms" and lr.hemi != "bw":
					found = absf(float(h.tree.get(lr.param)) - 0.75) < 1e-6
			ctx.check(found, "bow sprint: bow-sprint--arms carried at 0.75")
		# Poses.
		var u: float = h.idx.phase(h.tree, id, "fw")
		var actual := PoseOracle.capture(h.rig.sk)
		var graph := _graph_pose(o, d, h, w, m, role, rec, u)
		var godot := _godot_pose(o, h, rec, u)
		var eg := o.compare(graph, actual, ["l_elbow", "r_elbow"], "r")
		var ea := o.compare(graph, actual, ARM_BONES, "r")
		var ew := o.compare(godot, actual, null, "r")
		ctx.at_most(eg.max_rot, TOL_GRAPH, "%s/%s/%s: elbows vs graph oracle (role clip + layers in order) (rad)" % [w, m, role])
		ctx.info("%s/%s/%s: arms + spine vs graph oracle worst %.4f rad at %s (Godot's rest-relative blend of partial layers)" % [w, m, role, ea.max_rot, ea.max_rot_bone])
		ctx.at_most(ew.max_rot, TOL_WIRING, "%s/%s/%s: every bone vs the Godot evaluation of the same stack (rad; worst %s)" % [w, m, role, ew.max_rot_bone])
		ctx.metric("%s_%s_%s_elbow_rad" % [w, m, role], eg.max_rot)

	# Weapon switch: carry amounts are continuous.
	var id2: StringName = h.idx.input_for("musket/run/fw")
	h.snap(&"musket", "stand", 0.0, 0.0)
	h.set_lower(id2, 0.0, &"MOVE")
	h.set_bank(id2, "fw", 0.0, 0.0)
	h.step(2)
	var rec2: Dictionary = h.idx.lower[id2]
	var last := {}
	for lr: Dictionary in rec2.layers:
		last[lr.param] = float(h.tree.get(lr.param))
	h.set_weapon(&"bow")
	var worst := 0.0
	var fade := float(d.tuning("weapon_fade_s", 0.25))
	for f in 30:
		h.step(1)
		for lr: Dictionary in rec2.layers:
			var v := float(h.tree.get(lr.param))
			var lw := maxf(float(lr.weight), 1e-6)
			worst = maxf(worst, absf(v - float(last[lr.param])) / lw)
			last[lr.param] = v
	ctx.at_most(worst, UpperRig.DT / fade + 1e-5, "weapon switch musket -> bow: per-frame carry amount change / layer weight <= dt / %.2f s" % fade)
	var end_bad := []
	for lr: Dictionary in rec2.layers:
		if lr.hemi == "bw" or not lr.scale_by_weapon:
			continue
		var lw := float(lr.leaf_weights[0]) if lr.has("leaf_weights") else float(lr.weight)
		var want := lw if lr.weapon == "bow" else 0.0
		if absf(float(h.tree.get(lr.param)) - want) > 1e-6:
			end_bad.append("%s %s" % [lr.weapon, lr.clip])
	ctx.check(end_bad.is_empty(), "after the switch: bow layers at their weights, musket / pistol layers at 0 %s" % [end_bad])
	_palm(ctx, h, o)


## Lowered musket: left palm vs the barrel line (the prop bone's +Z through its origin) over the
## gait cycle, tree vs graph oracle.
func _palm(ctx: AnimTestContext, h, o: PoseOracle) -> void:
	var d: AnimGraphData = h.data
	var sk: Skeleton3D = h.rig.sk
	for m in ["walk", "run", "crouch", "sprint"]:
		var st := d.stance_of(m)
		var id: StringName = h.idx.input_for("musket/%s/fw" % m)
		if id == &"":
			ctx.fail("musket/%s/fw has a lower input" % m)
			continue
		var rec: Dictionary = h.idx.lower[id]
		var tree_worst := 0.0
		var graph_worst := 0.0
		var diff := 0.0
		for u in [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]:
			h.snap(&"musket", st, 0.0, 0.0)
			h.inp.weapon_aim = 0.0
			h.set_lower(id, u, &"MOVE")
			h.set_bank(id, "fw", 0.0, 0.0)
			h.step(1, 0.0)
			h.step(1, 0.0)
			var tp := _palm_off(sk, func(i: int) -> Transform3D: return sk.get_bone_global_pose(i))
			var uu: float = h.idx.phase(h.tree, id, "fw")
			var mt := o.model_transforms(_graph_pose(o, d, h, "musket", m, "fw", rec, uu))
			var gp := _palm_off(sk, func(i: int) -> Transform3D: return mt[i])
			tree_worst = maxf(tree_worst, tp)
			graph_worst = maxf(graph_worst, gp)
			diff = maxf(diff, absf(tp - gp))
		ctx.at_most(diff, PALM_TOL_M, "musket/%s/fw carry: left palm off the barrel line, tree vs graph oracle (m)" % m)
		ctx.at_most(tree_worst, float(PALM_MAX_M[m]), "musket/%s/fw carry: left palm off the barrel line, worst over the cycle (graph data %.3f m; documented bound, m)" % [m, graph_worst])


func _palm_off(sk: Skeleton3D, xf: Callable) -> float:
	var rt: Transform3D = xf.call(sk.find_bone("r_hand_prop_attachment"))
	var v: Vector3 = (xf.call(sk.find_bone("l_palm")) as Transform3D).origin - rt.origin
	var dir := (rt.basis.orthonormalized() * Vector3.BACK).normalized()
	return (v - dir * v.dot(dir)).length()


## Graph semantics: role clip at phase u, then the role's layers in order (partial = override of
## the keyed channels at the weight, additive = base (+) (rest^-1 add)^w), then the weapon-out
## finger partial at 1 where it applies.
func _graph_pose(o: PoseOracle, d: AnimGraphData, h, w: String, m: String, role: String, rec: Dictionary, u: float) -> PoseOracle.Pose:
	var clip: String = _own(h, rec.hemis.fw.clips[0] if rec.kind == "bank" else String(rec.clip))
	var pose := o.clip(clip, u * _len(h, clip))
	for l in d.role(w, m, role).get("layers", []):
		if String(l.get("status", "resolved")) != "resolved" or not l.get("clip") is String or l.has("excluded"):
			continue
		if String(l.get("slot", "")) == "full_body" or not String(l.get("kind", "")) in ["partial", "additive"]:
			continue
		var lp := o.clip(String(l.clip), u * _len(h, String(l.clip)))
		if l.kind == "additive":
			pose = o.additive(pose, lp, float(l.weight))
		else:
			pose = o.partial(pose, lp, float(l.weight))
	var wo := d.weapon_out(w, d.stance_of(m))
	if bool(d.option("weapon_out_fingers", true)) and bool(wo.get("applies", false)):
		pose = o.partial(pose, o.clip(String(wo.clip), 0.0), 1.0)
	return pose


## Godot semantics of the built stack: base clip, each fw / single LayerRecord at its written
## amount (Blend2 filtered to the layer clip's keyed bones, or Add2), the weapon-out Blend2s.
func _godot_pose(o: PoseOracle, h, rec: Dictionary, u: float) -> PoseOracle.Pose:
	var clip: String = _own(h, rec.hemis.fw.clips[0] if rec.kind == "bank" else String(rec.clip))
	var inst := o.g_clip(clip, u * _len(h, clip))
	for lr: Dictionary in rec.layers:
		if lr.hemi == "bw":
			continue
		var amount := float(h.tree.get(lr.param))
		var lc := o.g_clip(String(lr.clip), u * _len(h, String(lr.clip)))
		if lr.kind == "additive":
			inst = o.g_add2(inst, lc, amount)
		else:
			inst = o.g_blend2(inst, lc, amount, h.rig.keyed_bones(String(lr.clip)))
	for c in h.idx.weapon_out:
		var r: Dictionary = h.idx.weapon_out[c]
		inst = o.g_blend2(inst, o.g_clip(String(c), 0.0), float(h.tree.get(r.param)), h.rig.keyed_bones(String(c)))
	return o.g_eval(inst)


func _len(h, clip: String) -> float:
	var a: Animation = h.rig.anim(clip)
	return a.length if a else 1.0


## The clip the tree plays for a graph clip: one of our own in place of it (AnimGraphData.apply_clip_overrides), by library path.
func _own(h, clip: String) -> String:
	var q := String(h.data.godot_anim(clip))
	return q if h.data.override_libraries().has(q.get_slice("/", 0)) else clip
