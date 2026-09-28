extends AnimTestSuite
## Runner self-test: the level fixture and FootSlip. Loads scenes/main.tscn through ctx.level(),
## then uses FootSlip.measure() (fresh level per repeat): a standing-still control case (planted
## feet must not slip), and walk/W measured before and after a different case, which must give
## the same numbers (identical with --fixed-fps 120); measure() with {"ideal": true} also gives
## the ideal-playback floor. Waits go through ctx ({"ctx": ctx}). The runner unloads the level.
## Must be reported PASS. Faster with --fixed-fps 120.


func timeout_s() -> float:
	return 240.0


func describe() -> String:
	return "ctx.level() + FootSlip.measure(): control case and order independence"


func run(ctx: AnimTestContext) -> void:
	var player = await ctx.level()
	if player == null:
		return
	ctx.check(player.has_method("switch_weapon") and player.get("skeleton") is Skeleton3D, "player node with a skeleton")
	var opts := {"repeats": 2, "settle_s": 0.5, "measure_s": 1.0, "ctx": ctx}
	var idle := await FootSlip.measure(ctx.tree, {"key": "control/idle", "mode": "run", "dir": "none", "actions": []}, opts)
	ctx.check(not idle.has("error"), "control case ran (%s)" % idle.get("error", "ok"))
	ctx.at_most(float(idle.get("max_mps", INF)), 0.05, "standing still (also after a pre-roll): planted-foot median slip (m/s)")
	ctx.at_least(float(idle.get("planted_frac", 0.0)), 0.9, "standing still: feet planted")
	var walk := {"key": "walk/W", "mode": "walk", "dir": "W", "actions": ["move_forward"]}
	var first := await FootSlip.measure(ctx.tree, walk, opts.merged({"ideal": true}))
	var other := await FootSlip.measure(ctx.tree, {"key": "sprint/WA", "mode": "sprint", "dir": "WA",
			"actions": ["move_forward", "move_left"]}, {"repeats": 1, "settle_s": 0.5, "measure_s": 0.5, "ctx": ctx})
	var again := await FootSlip.measure(ctx.tree, walk, opts)
	ctx.check(not first.has("error") and not other.has("error") and not again.has("error"), "walk / sprint cases ran")
	ctx.check(bool(first.get("walking", false)), "walk case ran with walk held")
	var p: Node = ctx.tree.current_scene.get_node_or_null("Player") if ctx.tree.current_scene else null
	if p:
		ctx.near(float(first.get("body_speed_mps", 0.0)), float(p.walk_speed) * float(p.weapon.speed_mult()), 0.05,
				"walk case moves at walk speed x weapon speed_mult (m/s)")
	var a := [first.get("median_mps"), first.get("min_mps"), first.get("max_mps")]
	var b := [again.get("median_mps"), again.get("min_mps"), again.get("max_mps")]
	if first.get("stepping", "") == "fixed":
		ctx.check(a == b, "walk/W identical before and after another case (order-independent): %s vs %s" % [a, b])
	else:
		ctx.near(float(a[0]), float(b[0]), 0.05, "walk/W before vs after another case, real time (m/s)")
	ctx.check(float(first.get("ideal_mps", -1.0)) > 0.0 and float(first.get("ideal_mps", 1.0)) < 0.15,
			"measure({ideal: true}) adds the walk/W ideal-playback floor (%s m/s, expected 0..0.15)" % first.get("ideal_mps", first.get("ideal_error", "missing")))
	ctx.info("walk/W median %.3f m/s, repeats %s (%s stepping); ideal-playback floor %.3f m/s" % [first.get("median_mps", NAN),
			first.get("repeats", []).map(func(x): return x.median_mps), first.get("stepping", "?"), first.get("ideal_mps", NAN)])
