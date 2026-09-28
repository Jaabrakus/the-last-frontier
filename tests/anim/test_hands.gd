extends AnimTestSuite
## WP5 (plan sections 6.9 and 10): hands. With no action playing, the finger, palm and prop bones
## a grip clip keys equal that clip's pose (<= 1e-3 rad, 1e-4 m) at upper_aim_w 0 and 1, for
## every weapon x stance x lower state (IDLE, MOVE) — so the weapon sits in the authored grip:
##   - graph default (override_exact_hands_grip off): aimed = the aim tree's own hands layer
##     (aim_trees.<w>/<s>.hands at weight 1); lowered = the code-entered weapon-out finger state
##     (weapon_layers.weapon_out: musket rifle-idle-hands, pistol r-hand-revolver) where it
##     applies, else the role's last full-weight hands layer (the bow's state-keyed bow-hands);
##   - with override_exact_hands_grip on: the grip clips (grips.<w>: carry, aim_stand,
##     aim_crouch) through the H__ nodes.

const UpperRig := preload("res://tests/anim/upper_rig.gd")
const TOL_RAD := 1e-3
const TOL_M := 1e-4


func describe() -> String:
	return "hands: grip clip pose on its bones at upper_aim_w 0 / 1, graph hands layers and exact-grip override"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	var h = UpperRig.new()
	if not h.setup(ctx):
		return
	var d: AnimGraphData = h.data
	var prop_worst := 0.0
	for override in [false, true]:
		d.set_override("override_exact_hands_grip", override)
		var label := "exact-grip override" if override else "graph hands"
		for w in d.weapons():
			for st in ["stand", "crouch"]:
				var mode := "run" if st == "stand" else "crouch"
				var e0 := float(d.pitch_table(w, st).get("zero_elev_deg", 0.0))
				for lower in ["idle", "fw"]:
					var id: StringName = h.idx.input_for("%s/%s/%s" % [w, mode, lower])
					if id == &"":
						ctx.fail("%s/%s/%s has a lower input" % [w, mode, lower])
						continue
					for aim in [0.0, 1.0]:
						h.snap(StringName(w), st, 0.0, e0)
						h.set_lower(id, 0.25, &"MOVE" if lower == "fw" else &"IDLE")
						if lower == "fw":
							h.set_bank(id, "fw", 0.0, 0.0)
						h.inp.weapon_aim = aim
						h.step(20)
						var exp := _expected(d, w, st, mode, lower, aim, override)
						var clip: String = exp[0]
						if clip == "":
							ctx.fail("%s %s/%s %s aim %.0f: no expected grip clip" % [label, w, st, lower, aim])
							continue
						var err := _compare(h, clip, exp[1], exp[2])
						prop_worst = maxf(prop_worst, err.prop)
						ctx.check(err.rot <= TOL_RAD and err.pos <= TOL_M and err.bones > 0,
								"%s %s/%s %s aim %.0f: %d bones of %s (rot %s rad, pos %s m, prop bone %s rad)" % [
								label, w, st, lower, aim, err.bones, clip, AnimTestContext.fmt(err.rot), AnimTestContext.fmt(err.pos),
								AnimTestContext.fmt(err.prop)])
	d.set_override("override_exact_hands_grip", false)
	ctx.metric("prop_bone_worst_rad", prop_worst)


## The clip that must hold the hands in this configuration: [clip, time, bone mask or []] (a grip
## pose sampled from a clip on a bone mask: graph carry_overrides / grips carry_sample_s, THROW2).
func _expected(d: AnimGraphData, w: String, st: String, mode: String, lower: String, aim: float, override: bool) -> Array:
	var g := d.grip(w)
	if aim >= 1.0:
		if override:
			return [String(g.get("aim_crouch" if st == "crouch" else "aim_stand", "")), 0.0, []]
		return [String(d.aim_tree(w, st).get("hands", {}).get("clip", "")), 0.0, []]
	if override:
		return [String(g.get("carry", "")), float(g.get("carry_sample_s", 0.0)), g.get("carry_bones", [])]
	var wo := d.weapon_out(w, st)
	if bool(d.option("weapon_out_fingers", true)) and bool(wo.get("applies", false)) and wo.get("clip") is String:
		return [String(wo.clip), 0.0, []]
	var last := ["", 0.0, []]
	for l in d.role(w, mode, lower).get("layers", []):
		if String(l.get("slot", "")) == "hands" and l.get("clip") is String and float(l.get("weight", 0.0)) >= 1.0 - 1e-6:
			last = [String(l.clip), float(l.get("sample_s", 0.0)) if l.get("sample_s") != null else 0.0, l.get("bones", []) if l.get("bones") != null else []]
	return last


## Local pose of every bone `clip` keys (only those in `mask` when it is not empty) vs the clip at
## `at` s (grip clips are single poses; a sampled grip pose is its clip at sample_s).
func _compare(h, clip: String, at := 0.0, mask: Array = []) -> Dictionary:
	var a: Animation = h.rig.anim(clip)
	var out := {"rot": 0.0, "pos": 0.0, "prop": 0.0, "bones": 0}
	if a == null:
		out.rot = INF
		return out
	var seen := {}
	for t in a.get_track_count():
		var bn := String(a.track_get_path(t).get_concatenated_subnames())
		var bi: int = h.rig.sk.find_bone(bn)
		if bi < 0 or (not mask.is_empty() and not bn in mask):
			continue
		seen[bn] = true
		match a.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				var e := PoseOracle.qdist(h.rig.sk.get_bone_pose_rotation(bi), a.rotation_track_interpolate(t, at))
				out.rot = maxf(out.rot, e)
				if bn.ends_with("_hand_prop_attachment"):
					out.prop = maxf(out.prop, e)
			Animation.TYPE_POSITION_3D:
				out.pos = maxf(out.pos, h.rig.sk.get_bone_pose_position(bi).distance_to(a.position_track_interpolate(t, at)))
	out.bones = seen.size()
	return out
