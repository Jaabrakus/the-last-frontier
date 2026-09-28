extends AnimTestSuite
## Runner self-test for FootSlip's reference: what the in-game measurement reads for PERFECT
## playback. On the real level the player's own animation tree is switched off and a one-clip
## AnimationTree plays the case's clip at the plan's section 6.6 rate (ratio = speed / clip
## speed, the only thing a perfect tree can do for a single-clip case); FootSlip.run_case()
## then measures it exactly as test_locomotion_feet measures the real tree. The result must
## match FootSlip.ideal_floor() (PoseOracle samples through the same result() code), which is
## the floor no tree can beat for these single-clip cases: run W / S / A / D and sprint W read
## over the plan's 0.15 m/s here (bow speed).
## Must be reported PASS. Faster with --fixed-fps 120.

## Single-clip cases (the bank plays one clip: straight ahead, straight back, pure strafe).
const CASES := [["walk", "W"], ["walk", "S"], ["run", "W"], ["run", "S"], ["run", "A"], ["run", "D"], ["sprint", "W"],
		["crouch", "W"]]
## |in-game - ideal range| (m/s): the in-game window starts at one phase, ideal_floor() spans
## IDEAL_PHASES start phases; outside the range by more than this is a failure.
const TOL := 0.02
const WEAPON := "bow"


func timeout_s() -> float:
	return 300.0


func describe() -> String:
	return "FootSlip in game with a perfect one-clip tree == FootSlip.ideal_floor() (the floor of the method)"


func run(ctx: AnimTestContext) -> void:
	var over := []
	for mc: Array in CASES:
		var c := {"key": "%s/%s" % mc, "mode": mc[0], "dir": mc[1], "actions": FootSlip.DIRS[mc[1]]}
		var p := await FootSlip.fresh_player(ctx.tree, WEAPON, FootSlip.MAIN_SCENE, ctx)
		if p == null:
			ctx.fail("level or player failed to load")
			return
		var o := FootSlip.oracle_for(p)
		var speed := FootSlip.case_speed(p, c)
		var ideal := FootSlip.ideal_floor(o, c, speed, {"weapon": WEAPON})
		if ideal.has("error"):
			ctx.fail("%s: ideal_floor: %s" % [c.key, ideal.error])
			continue
		var only: int = ideal.weights.find(1.0)
		if only < 0:
			ctx.fail("%s: not a single-clip case (weights %s)" % [c.key, ideal.weights])
			continue
		var clip: String = ideal.clips[only]
		var rate := float(ideal.cps) * o.animation(clip).length
		var err := _perfect_playback(p, clip, rate)
		if err != "":
			ctx.fail("%s: %s" % [c.key, err])
			continue
		var r := await FootSlip.run_case(ctx.tree, p, c, {"ctx": ctx})
		if r.has("error"):
			ctx.fail("%s: %s" % [c.key, r.error])
			continue
		ctx.near(float(r.body_speed_mps), speed, 0.02, "%s: body moves at the case speed (m/s)" % c.key)
		var got := float(r.median_mps)
		var lo := float(ideal.min_mps) - TOL
		var hi := float(ideal.max_mps) + TOL
		ctx.check(got >= lo and got <= hi, "%s: perfect one-clip playback (%s x %.3f) in game %.4f m/s within ideal_floor %.4f [%.4f..%.4f] +- %.2f" % [
				c.key, clip, rate, got, ideal.ideal_mps, ideal.min_mps, ideal.max_mps, TOL])
		ctx.metric("perfect_in_game_mps/" + c.key, got)
		ctx.metric("ideal_mps/" + c.key, ideal.ideal_mps)
		if float(ideal.ideal_mps) > 0.15:
			over.append("%s %.3f" % [c.key, ideal.ideal_mps])
	ctx.info("ideal-playback floor over the plan's 0.15 m/s: %s" % (", ".join(over) if not over.is_empty() else "none"))


## Switches the player's animation trees off and plays `clip` looped at `rate` with a fresh
## AnimationTree on the same AnimationPlayer (removed with the level). "" or an error message.
func _perfect_playback(p: Node, clip: String, rate: float) -> String:
	var sk: Skeleton3D = p.get("skeleton")
	var char_root := sk.get_parent()
	var aps := char_root.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		return "no AnimationPlayer under the character"
	var ap: AnimationPlayer = aps[0]
	var name := clip if ap.has_animation(clip) else "actor_b/" + clip
	if not ap.has_animation(name):
		return "clip %s not in the AnimationPlayer" % clip
	for t: Node in p.find_children("*", "AnimationTree", true, false):
		(t as AnimationTree).active = false
		t.process_mode = Node.PROCESS_MODE_DISABLED
	ap.stop()
	var an := AnimationNodeAnimation.new()
	an.animation = name
	an.use_custom_timeline = true
	an.timeline_length = ap.get_animation(name).length
	an.stretch_time_scale = false
	an.loop_mode = Animation.LOOP_LINEAR
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("clip", an)
	bt.add_node("ts", AnimationNodeTimeScale.new())
	bt.connect_node("ts", 0, "clip")
	bt.connect_node("output", 0, "ts")
	var tree := AnimationTree.new()
	tree.name = "PerfectPlayback"
	tree.deterministic = true
	char_root.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.tree_root = bt
	tree.set("parameters/ts/scale", rate)
	tree.active = true
	return ""
