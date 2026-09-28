extends AnimTestSuite
## Engine contract (plan 3.1 / 6.11, probe P13): a SkeletonModifier3D child of the Skeleton3D runs
## after the AnimationTree has applied its pose (in the skeleton update after advance()), code in
## Skeleton3D.skeleton_updated and BoneAttachment3D see the modified pose, influence 0 leaves the
## animated pose within 1e-6 rad (not bit-exact on 4.7.2: ~1.5e-8 float rounding; active = false
## is bit-exact), and the error to the modifier's target falls monotonically as influence rises.
## AimStabilizer, the weapon BoneAttachments and BoneMannequin rely on this order.

const DT := 1.0 / 60.0
## Adds add_deg of yaw to bone `bone` after the animation (the stabilizer pattern).
const MOD_SRC := """extends SkeletonModifier3D
var bone := 0
var add_deg := 30.0
var calls := 0
func _process_modification() -> void:
	calls += 1
	var sk := get_skeleton()
	sk.set_bone_pose_rotation(bone, Quaternion(Vector3.UP, deg_to_rad(add_deg)) * sk.get_bone_pose_rotation(bone))
"""


func describe() -> String:
	return "SkeletonModifier3D after advance; BoneAttachment sees it; influence 0 within 1e-6, active=false bit-exact"


func run(ctx: AnimTestContext) -> void:
	var r := ctx.synthetic_rig([["b", ""], ["c", "b", Transform3D(Basis.IDENTITY, Vector3(1, 0, 0))]], {
		"A": {"len": 1.0, "yaw": {"b": [[0.0, 10.0], [1.0, 10.0]], "c": [[0.0, 0.0], [1.0, 0.0]]}},
	})
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("clip", r.node("A"))
	bt.connect_node("output", 0, "clip")
	r.play(bt)
	var scr := GDScript.new()
	scr.source_code = MOD_SRC
	scr.reload()
	var mod: SkeletonModifier3D = scr.new()
	mod.name = "TestModifier"
	r.sk.add_child(mod)
	var att := BoneAttachment3D.new()
	att.bone_name = "c"
	r.sk.add_child(att)
	var seen := {"n": 0}
	r.sk.skeleton_updated.connect(func() -> void:
		seen.n += 1
		seen.b = r.sk.get_bone_pose_rotation(0)
		seen.c = r.sk.get_bone_global_pose(1))
	await ctx.idle_frames(2)

	var calls0: int = mod.calls
	r.advance(DT)
	var pre := r.bone_rot("b")
	var q10 := Quaternion(Vector3.UP, deg_to_rad(10.0))
	var q40 := Quaternion(Vector3.UP, deg_to_rad(40.0))
	ctx.near(pre, q10, 1e-5, "right after advance() the skeleton holds the animated pose (yaw 10)")
	ctx.check(mod.calls == calls0, "the modifier has not run inside advance() (%d calls)" % (mod.calls - calls0))
	await ctx.idle_frames(1)
	ctx.check(mod.calls > calls0, "the modifier ran in the skeleton update after advance()")
	ctx.near(seen.get("b", Quaternion()), q40, 1e-5, "skeleton_updated sees animation then modifier (10 + 30 = 40)")
	var c_mod: Transform3D = r.sk.global_transform * seen.get("c", Transform3D())
	ctx.near(att.global_transform.origin, c_mod.origin, 1e-5, "BoneAttachment3D follows the modified pose")
	var c_pre := r.sk.global_transform * (Transform3D(Basis(q10)) * Transform3D(Basis.IDENTITY, Vector3(1, 0, 0)))
	ctx.at_least(att.global_transform.origin.distance_to(c_pre.origin), 0.3,
			"BoneAttachment3D is not at the pre-modifier position (distance, m)")
	var outside := rad_to_deg(PoseOracle.qdist(Quaternion.IDENTITY, r.bone_rot("b")))
	ctx.info("after the frame, get_bone_pose_rotation(b) outside skeleton_updated = %.2f deg (%s)" % [
			outside, "pre-modifier, as P13" if absf(outside - 10.0) < 0.01 else "CHANGED from P13 (pre-modifier 10)"])

	var errs := []
	for inf in [0.0, 0.25, 0.5, 0.75, 1.0]:
		mod.influence = inf
		r.advance(0.0)
		var anim_q := r.bone_rot("b")
		await ctx.idle_frames(1)
		var q: Quaternion = seen.b
		if inf == 0.0:
			var d0 := PoseOracle.qdist(q, anim_q)
			ctx.at_most(d0, 1e-6, "influence 0: pose seen in skeleton_updated equals the animated pose (rad)")
			ctx.info("influence 0 is %s (quaternion %s vs %s)" % ["bit-identical" if q == anim_q else "NOT bit-identical (float rounding %s rad)" % AnimTestContext.fmt(d0), q, anim_q])
			ctx.metric("influence0_bit_identical", q == anim_q)
		errs.append(PoseOracle.qdist(q, q40))
	var mono := true
	for i in range(1, errs.size()):
		mono = mono and errs[i] < errs[i - 1]
	ctx.check(mono, "error to the modifier target falls monotonically with influence 0..1: %s deg" % [errs.map(func(e): return snappedf(rad_to_deg(e), 0.01))])
	ctx.near(errs[-1], 0.0, 1e-5, "influence 1 reaches the target")
	mod.influence = 1.0
	mod.active = false
	r.advance(0.0)
	var anim_off := r.bone_rot("b")
	await ctx.idle_frames(1)
	var q_off: Quaternion = seen.b
	ctx.check(q_off == anim_off, "active = false: pose in skeleton_updated is bit-identical to the animated pose (%s)" % q_off)
	ctx.metric("inactive_bit_identical", q_off == anim_off)
